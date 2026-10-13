local objectives = {}

local combat = require("self_play.combat")
local vision = require("self_play.vision")
local awareness = require("self_play.awareness")

local function live(unit)
	return unit and Entity.IsEntity(unit) and Entity.IsAlive(unit) and not Entity.IsDormant(unit)
end

local function safe(ctx, position)
	if ctx.unsafePosition(position) then return false end
	for _, entry in pairs(ctx.memory) do
		if ctx.now - entry.time < 6 and ctx.distance(position, entry.position) < 1500 then return false end
	end
	return true
end

local function covered(ctx, position)
	for _, unit in ipairs(NPCs.InRadius(position, 1300, ctx.team, Enum.TeamType.TEAM_FRIEND)) do
		if live(unit) and NPC.GetUnitName(unit) == "npc_dota_observer_wards" then return true end
	end
	for _, entry in ipairs(ctx.placedWards or {}) do
		if ctx.now - entry.time < 330 and ctx.distance(position, entry.position) < 1300 then return true end
	end
	return false
end

local function wardSafe(ctx, position, range)
	if ctx.role ~= 2 or ctx.clock >= 1200 then return safe(ctx, position) end
	local approach = ctx.distance(ctx.position, position) > range - 25
		and ctx.toward(position, ctx.position, math.max(100, range - 80)) or ctx.position
	if ctx.unsafePosition(approach) or awareness.risk(ctx, approach) > 90 then return false end
	for _, entry in pairs(ctx.memory) do
		if ctx.now - entry.time < 4 and ctx.distance(approach, entry.position) < 550 then return false end
	end
	return true
end

local function nearEnemyTower(ctx, position, margin)
	for _, tower in ipairs(ctx.towers) do
		if live(tower) and not Entity.IsSameTeam(ctx.hero, tower)
			and ctx.distance(position, Entity.GetAbsOrigin(tower)) < NPC.GetAttackRange(tower) + margin then return true end
	end
	return false
end

local function wardLog(ctx, reason)
	if ctx.now < (ctx.nextWardLog or 0) then return end
	ctx.nextWardLog = ctx.now + 15
	Log.Write(string.format("[SelfPlay ward] %s (role=%d lane=%d hp=%.2f nearEnemies=%d hasObserver=%s)",
		reason, ctx.role, ctx.lane, ctx.health or 0, ctx.nearEnemies or 0,
		tostring(NPC.GetItem(ctx.hero, "item_ward_observer", true) ~= nil
			or NPC.GetItem(ctx.hero, "item_ward_dispenser", true) ~= nil)))
end

local function wardSpot(ctx, anchor, range)
	local positions = {}
	local ok, helper = pcall(XHelpers.GetScript, "WardHelper")
	if ok and helper and type(helper.positions) == "table" and type(helper.positions.observer) == "table" then
		for _, entry in pairs(helper.positions.observer) do
			if type(entry) == "table" and not entry.tree_cut
				and (not entry.team or entry.team == 0 or entry.team == ctx.team) then
				local p = entry.position
				if p then positions[#positions + 1] = Vector(p.x or p[1], p.y or p[2], p.z or p[3]) end
			end
		end
	elseif helper ~= nil then
		wardLog(ctx, "WardHelper has unexpected format, using fallback spots")
	end


	if #positions == 0 then
		for radius = 400, 1000, 300 do
			for angle = 0, 11 do
				local theta = angle * math.pi / 6
				local x, y = anchor.x + math.cos(theta) * radius, anchor.y + math.sin(theta) * radius
				positions[#positions + 1] = Vector(x, y, World.GetGroundZ(x, y))
			end
		end
	end
	local best, score
	for _, position in ipairs(positions) do
		local distance = ctx.distance(ctx.position, position)
		if distance < 2400 and ctx.distance(position, anchor) < 1800 and ctx.distance(position, ctx.home) > 3000
			and not nearEnemyTower(ctx, position, 400) and wardSafe(ctx, position, range) and not covered(ctx, position) then
			local value = position.z * 2 - distance * 0.3 - ctx.distance(position, Vector(0, 0, 0)) * 0.08
			if not score or value > score then best, score = position, value end
		end
	end
	return best
end

function objectives.ward(ctx, anchor)
	local contested = ctx.nearEnemies > 0 and (ctx.role ~= 2 or ctx.nearEnemies > ctx.nearAllies
		or ctx.health < 0.7 or ctx.laneThreat and ctx.laneThreat.attacked)
	if not vision.responsible(ctx) then return false end
	if ctx.role == 2 and ctx.clock < (ctx.laneEnd or 600) then
		ctx.wardTask = nil
		return false
	end
	if ctx.clock < 30 or contested or ctx.health < 0.55
		or ctx.farmCandidate and ctx.farmCandidate.start < ctx.now + 1 then
		if contested then wardLog(ctx, "skip: contested lane") end
		ctx.wardTask = nil
		return false
	end
	ctx.placedWards = ctx.placedWards or {}
	for index = #ctx.placedWards, 1, -1 do if ctx.now - ctx.placedWards[index].time > 360 then table.remove(ctx.placedWards, index) end end
	local pending = ctx.wardPending
	if pending then
		if covered(ctx, pending.position) then
			ctx.placedWards[#ctx.placedWards + 1] = {position = pending.position, time = ctx.now}
			ctx.wardPending, ctx.nextWard = nil, ctx.now + 25
		elseif ctx.now > pending.expires then ctx.wardPending, ctx.nextWard = nil, ctx.now + 10 end
		return false
	end
	if ctx.now < ctx.nextWard then return false end
	local ward = NPC.GetItem(ctx.hero, "item_ward_observer", true) or NPC.GetItem(ctx.hero, "item_ward_dispenser", true)
	if not ward then wardLog(ctx, "no observer/dispenser in inventory"); return false end
	if not combat.ready(ctx, ward, true) then wardLog(ctx, "ward item not ready"); return false end
	if Ability.GetName(ward) == "item_ward_dispenser" then
		local observers = Ability.GetToggleState(ward) and Item.GetCurrentCharges(ward) or Item.GetSecondaryCharges(ward)
		if observers <= 0 then return false end
		if not Ability.GetToggleState(ward) then Ability.Toggle(ward, false, false, true); ctx.nextWard = ctx.now + 0.3; return true end
	end
	if not ctx.wardTask then
		if ctx.role == 2 and ctx.clock < 1200 then
			if vision.midCovered(ctx) or ctx.distance(ctx.position, Vector(0, 0, 0)) > 3200 then return false end
			anchor = Vector(0, 0, 0)
		end
		local position = wardSpot(ctx, anchor, Ability.GetCastRange(ward))
		if not position then ctx.nextWard = ctx.now + 10; wardLog(ctx, "no ward spot found"); return false end
		ctx.wardTask = {position = position, expires = ctx.now + 20, progressAt = ctx.now, distance = ctx.distance(ctx.position, position)}
	end
	local task = ctx.wardTask
	if ctx.now > task.expires or not wardSafe(ctx, task.position, Ability.GetCastRange(ward)) or covered(ctx, task.position) then
		ctx.wardTask, ctx.nextWard = nil, ctx.now + 10
		return false
	end
	local range = Ability.GetCastRange(ward)
	if ctx.distance(ctx.position, task.position) > range - 25 then
		local distance = ctx.distance(ctx.position, task.position)
		if distance < task.distance - 45 then
			task.distance, task.progressAt = distance, ctx.now
		elseif ctx.now - task.progressAt > 2.5 then
			ctx.wardTask, ctx.nextWard = nil, ctx.now + 12
			wardLog(ctx, "ward travel made no progress")
			return false
		end
		return ctx.move(ctx.toward(task.position, ctx.position, math.max(100, range - 80)), "Travel to ward position")
	end
	combat.cast(ctx, ward, "point", nil, task.position)
	ctx.wardPending = {position = task.position, expires = ctx.now + 3}
	ctx.wardTask, ctx.mode = nil, "Place observer vision"
	return true
end

function objectives.collect(ctx, wisdomOnly)
	if ctx.intent and ctx.intent.kind == "hero" or ctx.teamTask and (ctx.teamTask.kind == "push" or ctx.teamTask.fighting) then
		ctx.objectiveTask = nil
		return false
	end
	if not ctx.settings.objectives or ctx.clock < 0 or ctx.nearEnemies > 0 or ctx.health < 0.55 or ctx.retreating then
		ctx.objectiveTask = nil
		return false
	end
	ctx.objectiveVisits = ctx.objectiveVisits or {}
	local task = ctx.objectiveTask
	if wisdomOnly and task and task.kind ~= "wisdom" then return false end
	if task then
		if not live(task.unit) or ctx.now > task.expires or not safe(ctx, task.position) then
			ctx.objectiveVisits[task.key], ctx.objectiveTask = ctx.now + (task.kind == "wisdom" and 12 or 40), nil
			return false
		end
		if task.kind == "wisdom" then
			if not Entity.GetField(task.unit, "m_bActive") then
				ctx.objectiveVisits[task.key], ctx.objectiveTask = ctx.now + 5, nil
				ctx.mode = "Wisdom collection complete"
				return false
			end
			local distance = ctx.distance(ctx.position, task.position)
			if distance > 240 then
				task.arrived = nil
				return ctx.move(ctx.toward(task.position, ctx.position, 160), "Travel to wisdom")
			end
			if not task.arrived then
				task.arrived, task.expires = ctx.now, math.max(task.expires, ctx.now + 8.5)
				ctx.stop()
			end
			if ctx.now - task.arrived > 8 then
				ctx.objectiveVisits[task.key], ctx.objectiveTask = ctx.now + 12, nil
				return false
			end
			ctx.mode = Entity.GetField(task.unit, "m_bIsBeingGranted") and "Collect wisdom: countdown" or "Hold wisdom radius"
			return true
		end
		local distance = ctx.distance(ctx.position, task.position)
		if distance > 220 then return ctx.move(ctx.toward(task.position, ctx.position, 140), "Travel to " .. task.kind) end
		if not task.arrived then
			task.arrived = ctx.now
			Player.PrepareUnitOrders(ctx.player, Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_TARGET, task.unit, task.position, nil,
				Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, ctx.hero, false, false, false, true)
			ctx.lastOrder = "objective"
		end
		ctx.mode = "Collect " .. task.kind

		if ctx.now - task.arrived < 4 then return true end
		local period = task.kind == "wisdom" and 420 or 180
		ctx.objectiveVisits[task.key], ctx.objectiveTask = ctx.now + period - ctx.clock % period, nil
		return false
	end
	if ctx.now < (ctx.nextObjective or 0) then return false end
	ctx.nextObjective = ctx.now + 2
	local best, bestScore
	for _, unit in ipairs(ctx.mapObjectives) do
		if live(unit) then
			local position = Entity.GetAbsOrigin(unit)
			local wisdom = NPC.GetUnitName(unit) == "npc_dota_xp_fountain"
			local period = wisdom and 420 or 180
			local epoch = math.floor(ctx.clock / period)
			local key = Entity.GetIndex(unit)
			local distance = ctx.distance(ctx.position, position)
			local ownSide = ctx.distance(position, ctx.home) < ctx.distance(position, ctx.enemyHome)
			local available = not wisdom or Entity.GetField(unit, "m_bActive")
			local limit = ownSide and ctx.role >= 4 and 4200 or 2400
			local relevant = wisdom and distance < limit or not wisdom and not wisdomOnly and distance < 1400
			for _, ally in ipairs(ctx.allies) do
				if wisdom and ally ~= ctx.hero and live(ally) and not NPC.IsIllusion(ally)
					and ctx.distance(Entity.GetAbsOrigin(ally), position) < 450 and distance > 500 then relevant = false end
			end
			if epoch > 0 and relevant and available and ctx.now >= (ctx.objectiveVisits[key] or 0) and safe(ctx, position) then
				local score = (wisdom and 3000 or 1000) - distance * 0.5
				if not bestScore or score > bestScore then
					best, bestScore = {unit = unit, position = position, kind = wisdom and "wisdom" or "lotus",
						key = key, expires = ctx.now + distance / math.max(100, NPC.GetMoveSpeed(ctx.hero)) + 8}, score
				end
			end
		end
	end
	if best then ctx.objectiveTask = best; return ctx.move(ctx.toward(best.position, ctx.position, 140), "Travel to " .. best.kind) end
	return false
end

return objectives
