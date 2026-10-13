local runes = {}
local mobility = require("self_play.mobility")
local consumables = require("self_play.consumables")
local combat = require("self_play.combat")
local planner = require("self_play.planner")

function runes.yieldCore(ctx, position)
	if ctx.role < 4 then return false end
	if not ctx.runeRoles or ctx.now >= (ctx.nextRuneRoles or 0) then
		local entries = {}
		for _, ally in ipairs(ctx.allies) do
			if Entity.IsEntity(ally) and not NPC.IsIllusion(ally) and not NPC.IsMeepoClone(ally) then
				entries[#entries + 1] = {id = Entity.GetIndex(ally), scores = planner.roleScores(ctx.catalog.heroes[NPC.GetUnitName(ally)])}
			end
		end
		ctx.runeRoles, ctx.nextRuneRoles = planner.assignRoles(entries), ctx.now + 5
	end
	for _, ally in ipairs(ctx.allies) do
		local role = ctx.runeRoles[Entity.GetIndex(ally)]
		if ally ~= ctx.hero and role and role <= 3 and Entity.IsAlive(ally) and not Entity.IsDormant(ally)
			and ctx.distance(Entity.GetAbsOrigin(ally), position) < 1100 then return true end
	end
	return false
end

local function valid(rune)
	return rune and Entity.IsEntity(rune) and not Entity.IsDormant(rune)
end

function runes.contest(ctx, position)
	local best = math.huge
	for _, enemy in ipairs(ctx.enemies) do
		if Entity.IsAlive(enemy) and not Entity.IsDormant(enemy) and NPC.IsVisible(enemy) then
			local distance = ctx.distance(Entity.GetAbsOrigin(enemy), position)
			local history = ctx.history[Entity.GetIndex(enemy)]
			local closing = history and ((position.x - history.position.x) * history.vx + (position.y - history.position.y) * history.vy) > distance * 80
			if distance < 220 or distance < 2200 and NPC.IsRunning(enemy) and closing then
				best = math.min(best, math.max(0, distance - 100) / math.max(100, NPC.GetMoveSpeed(enemy)))
			end
		end
	end
	return best
end

local function safe(ctx, position)
	if ctx.unsafePosition(position) then return false end
	for _, enemy in ipairs(ctx.enemies) do
		if Entity.IsAlive(enemy) and not Entity.IsDormant(enemy) and NPC.IsVisible(enemy)
			and ctx.distance(Entity.GetAbsOrigin(enemy), position) < 650
			and (ctx.health < 0.65 or ctx.nearEnemies > ctx.nearAllies) then return false end
	end
	return true
end

function runes.waterDecision(ctx, position, farm)
	local distance = ctx.distance(ctx.position, position)
	local speed = math.max(100, NPC.GetMoveSpeed(ctx.hero))
	local travel = math.max(0, distance - 120) / speed
	local bottle = NPC.GetItem(ctx.hero, "item_bottle", true)
	local charges = bottle and Item.GetCurrentCharges(bottle) or 3
	local refill = bottle and charges < 2 and Bottle.GetRuneType(bottle) == -1
	local healthMissing = Entity.GetMaxHealth(ctx.hero) - Entity.GetHealth(ctx.hero)
	local manaMissing = NPC.GetMaxMana(ctx.hero) - NPC.GetMana(ctx.hero)
	local own = healthMissing >= 70 or manaMissing >= 55 or refill
	local enemyValue, enemyETA = false, math.huge
	for _, enemy in ipairs(ctx.enemies) do
		if Entity.IsAlive(enemy) and not Entity.IsDormant(enemy) and NPC.IsVisible(enemy) then
			local current = ctx.distance(Entity.GetAbsOrigin(enemy), position)
			local enemyBottle = NPC.GetItem(enemy, "item_bottle", true)
			local needs = enemyBottle and Item.GetCurrentCharges(enemyBottle) < 2 and Bottle.GetRuneType(enemyBottle) == -1
				or Entity.GetHealth(enemy) < Entity.GetMaxHealth(enemy) - 80 or NPC.GetMana(enemy) < NPC.GetMaxMana(enemy) - 70
			if needs and current < 1700 then
				enemyValue = true
				enemyETA = math.min(enemyETA, math.max(0, current - 100) / math.max(100, NPC.GetMoveSpeed(enemy)))
			end
		end
	end
	if not own and not enemyValue then return nil end
	local range = NPC.GetAttackRange(ctx.hero) + NPC.GetAttackRangeBonus(ctx.hero)
	local denyTravel = math.max(0, distance - range + 30) / speed
	local action = not own and distance > 160 and denyTravel + 0.4 < travel and "deny" or "pickup"
	local cost = action == "deny" and denyTravel + 0.4 or travel
	local remote = ctx.heroModule and ctx.heroModule.runeReach and distance < ctx.heroModule.runeReach(ctx)
	if remote then cost = math.min(cost, 0.4) end
	if farm and farm.start <= ctx.now + cost + 0.6 and not (own and healthMissing > Entity.GetMaxHealth(ctx.hero) * 0.3)
		and not (enemyValue and cost < 0.5) then return nil end
	if not own and cost > math.min(2.5, enemyETA + 0.25) then return nil end
	return {action = action, own = own, enemy = enemyValue, eta = enemyETA, cost = cost}
end

local function spotKey(position)
	return math.floor(position.x / 100) .. ":" .. math.floor(position.y / 100)
end

local runeBuffs = {
	modifier_rune_doubledamage = true, modifier_rune_haste = true, modifier_rune_regen = true,
	modifier_rune_invis = true, modifier_rune_arcane = true, modifier_rune_shield = true,
}

local function closeSpot(ctx, cycle, key, reason, power)
	local state = ctx.runeObservation
	if state.cycle ~= cycle then return end
	state.spots[key] = {status = "empty", reason = reason}
	if power then
		state.taken = true
		ctx.riverDone, ctx.riverCollected = cycle, cycle
		if ctx.riverTask and ctx.riverTask.cycle == cycle then ctx.riverTask = nil end
	end
end

function runes.observe(ctx)
	ctx.runeSpots, ctx.runeFailed = ctx.runeSpots or {}, ctx.runeFailed or {}
	if ctx.now >= (ctx.nextRuneSpawners or 0) then
		ctx.nextRuneSpawners = ctx.now + 5
		for _, entity in ipairs(Entities.GetAll()) do
			if Entity.GetClassName(entity) == "C_DOTA_Item_RuneSpawner_Powerup" then
				local position = Entity.GetAbsOrigin(entity)
				ctx.runeSpots[spotKey(position)], ctx.haveRuneSpawners = position, true
			end
		end
	end
	local cycle = math.floor(ctx.clock / 120) * 120
	local state = ctx.runeObservation or {seen = {}, holders = {}, spots = {}}
	ctx.runeObservation = state
	if state.cycle ~= cycle then state.cycle, state.spots, state.taken = cycle, {}, false end
	if ctx.now < (state.nextObserve or 0) then return end
	state.nextObserve = ctx.now + 0.1
	local present = {}
	for _, rune in ipairs(Runes.GetAll()) do
		if valid(rune) then
			local kind = Rune.GetRuneType(rune)
			if kind >= 0 and kind < Enum.RuneType.DOTA_RUNE_COUNT and kind ~= Enum.RuneType.DOTA_RUNE_BOUNTY and kind ~= Enum.RuneType.DOTA_RUNE_XP then
				local position, id = Entity.GetAbsOrigin(rune), Entity.GetIndex(rune)
				local key = spotKey(position)
				if not ctx.haveRuneSpawners then ctx.runeSpots[key] = position end
				state.seen[id] = state.seen[id] or {rune = rune, position = position, key = key, cycle = cycle, water = kind == Enum.RuneType.DOTA_RUNE_WATER}
				present[key], state.spots[key] = true, {status = "present", rune = rune}
			end
		end
	end
	for id, entry in pairs(state.seen) do
		if not Entity.IsEntity(entry.rune) or not Runes.Contains(entry.rune) then
			closeSpot(ctx, entry.cycle, entry.key, "Observed rune was collected or denied", not entry.water)
			state.seen[id] = nil
		end
	end
	if cycle >= 120 and ctx.clock >= cycle + 0.6 then
		for key, position in pairs(ctx.runeSpots) do
			if not present[key] and FogOfWar.IsPointVisible(position) then closeSpot(ctx, cycle, key, "Spawn is visible and empty", false) end
		end
	end
	local checked = {}
	for _, list in ipairs({ctx.allies, ctx.enemies}) do
		for _, unit in ipairs(list) do
			if Entity.IsAlive(unit) and not Entity.IsDormant(unit) and NPC.IsVisible(unit) and not checked[unit] then
				checked[unit] = true
				local id = Entity.GetIndex(unit)
				local old, buffs = state.holders[id], {}
				local bottle = NPC.GetItem(unit, "item_bottle", true)
				local stored = bottle and Bottle.GetRuneType(bottle) or -1
				local fresh = old and ctx.now - old.seen < 1 and old.stored < 0 and stored >= 0
					and stored ~= Enum.RuneType.DOTA_RUNE_WATER and stored ~= Enum.RuneType.DOTA_RUNE_BOUNTY and stored ~= Enum.RuneType.DOTA_RUNE_XP
				for name in pairs(runeBuffs) do
					local modifier = NPC.GetModifier(unit, name)
					if modifier then
						local created = Modifier.GetCreationTime(modifier)
						buffs[name] = created
						if old and old.stored < 0 and old.buffs[name] ~= created and created >= ctx.now - ctx.clock + cycle
							and ctx.now - created < 1 and ctx.now - old.seen < 1 then fresh = true end
					end
				end
				if fresh and cycle >= 360 then
					for key, position in pairs(ctx.runeSpots) do
						if not present[key] and ctx.distance(Entity.GetAbsOrigin(unit), position) < 550 then
							closeSpot(ctx, cycle, key, "Fresh rune acquisition at this spawn", true)
						end
					end
				end
				state.holders[id] = {stored = stored, buffs = buffs, seen = ctx.now}
			end
		end
	end
	for id, holder in pairs(state.holders) do if ctx.now - holder.seen > 8 then state.holders[id] = nil end end
end

local function river(ctx, farm)
	if ctx.role ~= 2 or ctx.clock < 105 then return false end
	local task = ctx.riverTask
	if task and (ctx.now > task.expires or not safe(ctx, task.position) or ctx.riverCollected == task.cycle) then
		ctx.riverDone, ctx.riverTask, task = task.cycle, nil, nil
	end
	if not task then
		local elapsed = ctx.clock % 120
		local remaining = 120 - elapsed
		local cycle = remaining < 9 and ctx.clock + remaining or math.floor(ctx.clock / 120) * 120
		if remaining >= 9 and elapsed > 18 or cycle < 120 or farm or ctx.riverDone == cycle or ctx.laneThreat and ctx.laneThreat.avoid then return false end
		local best, distance = nil, 2400
		for key, position in pairs(ctx.runeSpots) do
			local observed = ctx.runeObservation.cycle == cycle and ctx.runeObservation.spots[key]
			local current = ctx.distance(ctx.position, position)
			if not (observed and observed.status == "empty") and current < distance and safe(ctx, position)
				and (cycle >= 360 or runes.waterDecision(ctx, position, farm)) then best, distance = position, current end
		end
		if not best then return false end
		task = {position = best, cycle = cycle, checked = {}, expires = ctx.now + math.max(0, cycle - ctx.clock) + 22}
		ctx.riverTask = task
	end
	local distance = ctx.distance(ctx.position, task.position)
	if task.cycle < 360 and not runes.waterDecision(ctx, task.position, farm) then ctx.riverTask = nil; return false end
	if ctx.clock >= task.cycle + 0.6 then
		local state = ctx.runeObservation
		for key, observed in pairs(state.cycle == task.cycle and state.spots or {}) do
			if observed.status == "empty" then task.checked[key] = true end
		end
		if task.checked[spotKey(task.position)] then
			if task.cycle < 360 then ctx.riverDone, ctx.riverTask = task.cycle, nil; return false end
			local best, nearest = nil, 4500
			for key, position in pairs(ctx.runeSpots) do
				local current = ctx.distance(ctx.position, position)
				local travel = current / math.max(100, NPC.GetMoveSpeed(ctx.hero))
				if not task.checked[key] and current < nearest and ctx.now + travel + 1 < task.expires
					and safe(ctx, position) and runes.contest(ctx, position) > travel - 1 then best, nearest = position, current end
			end
			if not best then ctx.riverDone, ctx.riverTask = task.cycle, nil; return false end
			task.position, distance = best, nearest
			task.progress = nil
		end
	end
	if ctx.heroModule and ctx.heroModule.rune and ctx.heroModule.rune(ctx, combat, task, runes.contest(ctx, task.position), math.max(0, task.cycle - ctx.clock)) then return true end
	if task.remoteUntil then
		if ctx.now < task.remoteUntil then return false end
		ctx.riverDone, ctx.riverTask = task.cycle, nil
		return false
	end
	local choice = task.cycle < 360 and runes.waterDecision(ctx, task.position, farm)
	if choice and choice.action == "deny" and ctx.clock < task.cycle then
		local range = NPC.GetAttackRange(ctx.hero) + NPC.GetAttackRangeBonus(ctx.hero)
		if distance < range - 20 then ctx.mode = "Hold attack range for water deny"; return ctx.stop() end
		return ctx.move(ctx.toward(task.position, ctx.position, math.max(100, range - 35)), "Prepare water denial from lane edge", 25)
	end
	if ctx.clock >= task.cycle then
		local progress = task.progress
		if not progress or distance < progress.distance - 70 then
			task.progress = {distance = distance, time = ctx.now}
		elseif ctx.now - progress.time > 2.5 then
			ctx.riverDone, ctx.riverTask = task.cycle, nil
			ctx.mode = "Leave river scout without movement progress"
			return false
		end
		if distance < 120 then
			task.arrived = task.arrived or ctx.now
			if ctx.clock > task.cycle + 0.8 and ctx.now - task.arrived > 0.6 then
				ctx.riverDone, ctx.riverTask = task.cycle, nil
				return false
			end
			ctx.mode = "Wait for rune visibility update"
			return ctx.stop()
		end
		local goal = ctx.toward(ctx.position, task.position, math.min(400, distance - 100))
		if ctx.move(goal, "Scout unseen river spawn until visible", 35) then return true end
		ctx.riverDone, ctx.riverTask = task.cycle, nil
		return false
	end
	if distance < 250 then ctx.mode = "Wait near river spawn"; return ctx.stop() end
	return ctx.move(ctx.toward(task.position, ctx.position, 220), "Prepare next river rune", 35)
end

function runes.waveDuty(ctx)
	if (ctx.nearEnemies or 0) > 0 then return false end
	local count = 0
	for _, creep in ipairs(ctx.creeps or {}) do
		if Entity.IsEntity(creep) and Entity.IsAlive(creep) and NPC.IsLaneCreep(creep)
			and not Entity.IsSameTeam(ctx.hero, creep)
			and ctx.distance(ctx.position, Entity.GetAbsOrigin(creep)) < 900 then
			count = count + 1
			if count >= 2 then return true end
		end
	end
	return false
end

function runes.run(ctx, farm)
	if ctx.clock < 0 or ctx.retreating then ctx.runeTask, ctx.riverTask = nil, nil; return false end
	runes.observe(ctx)
	for id, expiry in pairs(ctx.runeFailed) do if expiry < ctx.now then ctx.runeFailed[id] = nil end end
	local task = ctx.runeTask
	if task and valid(task.rune) then task.position = Entity.GetAbsOrigin(task.rune) end
	if task and runes.yieldCore(ctx, task.position) then
		if task.travelUntil and ctx.now < task.travelUntil then ctx.mode = "Finish rune travel; yield pickup to core"; return true end
		ctx.runeTask = nil
		ctx.mode = "Leave rune for nearby core"
		ctx.stop()
		return false
	end
	if task and task.remoteUntil and (not valid(task.rune) or not Runes.Contains(task.rune)) then
		ctx.riverDone, ctx.riverCollected, ctx.riverTask = task.cycle, task.cycle, nil
	end
	if task and (ctx.now >= task.expires or not valid(task.rune) or not Runes.Contains(task.rune) or not safe(ctx, task.position)) then
		if ctx.now >= task.expires then ctx.runeFailed[task.id] = ctx.now + 10 end
		ctx.runeTask, task = nil, nil
	end
	if runes.waveDuty(ctx) then
		ctx.riverTask = nil
		if task and ctx.distance(ctx.position, task.position) > 600 then ctx.runeTask, task = nil, nil end
		if not task then return false end
	end
	if not task then
		local best, bestScore
		for _, rune in ipairs(Runes.GetAll()) do
			if valid(rune) and (ctx.runeFailed[Entity.GetIndex(rune)] or 0) <= ctx.now then
				local kind, position = Rune.GetRuneType(rune), Entity.GetAbsOrigin(rune)
				local river = kind ~= Enum.RuneType.DOTA_RUNE_BOUNTY and kind ~= Enum.RuneType.DOTA_RUNE_XP
				local water = kind == Enum.RuneType.DOTA_RUNE_WATER
				if river and not ctx.haveRuneSpawners then
					local key = spotKey(position)
					ctx.runeSpots[key] = position
				end
				local distance = ctx.distance(ctx.position, position)
				local waterChoice = water and runes.waterDecision(ctx, position, farm)
				local waterTrip = not water or waterChoice and ctx.riverDone ~= math.floor(ctx.clock / 120) * 120
					and (distance < 1600 or ctx.heroModule and ctx.heroModule.runeReach and distance < ctx.heroModule.runeReach(ctx) or ctx.riverTask and ctx.distance(position, ctx.riverTask.position) < 400)
				local collectedCycle = river and ctx.riverCollected == math.floor(ctx.clock / 120) * 120
				if not collectedCycle and waterTrip and kind >= 0 and kind < Enum.RuneType.DOTA_RUNE_COUNT
					and distance < (ctx.role == 2 and river and (ctx.riverTask and 4500 or 3200) or 800) and safe(ctx, position)
					and not runes.yieldCore(ctx, position) then
					local score = distance - (river and ctx.role == 2 and 1000 or 0)
					if not bestScore or score < bestScore then best, bestScore = rune, score end
				end
			end
		end
		if best then

			if farm and farm.inRange and farm.impact - ctx.now < 0.35 then return false end
			local travel = ctx.distance(ctx.position, Entity.GetAbsOrigin(best)) / math.max(100, NPC.GetMoveSpeed(ctx.hero))
			local kind = Rune.GetRuneType(best)
			task = {rune = best, id = Entity.GetIndex(best), position = Entity.GetAbsOrigin(best), expires = ctx.now + math.min(18, travel + 4),
				river = kind ~= Enum.RuneType.DOTA_RUNE_BOUNTY and kind ~= Enum.RuneType.DOTA_RUNE_XP,
				cycle = math.floor(ctx.clock / 120) * 120, water = kind == Enum.RuneType.DOTA_RUNE_WATER}
			ctx.runeTask = task
		end
	end
	if task then
		local choice = task.water and runes.waterDecision(ctx, task.position, farm)
		if task.water and not choice then ctx.runeTask = nil; return false end
		task.action = choice and choice.action or "pickup"
		local eta = runes.contest(ctx, task.position)
		if ctx.heroModule and ctx.heroModule.rune and ctx.heroModule.rune(ctx, combat, task, eta, 0) then return true end
		if task.remoteUntil and ctx.now < task.remoteUntil then return false end
		if task.action == "deny" then
			local range = NPC.GetAttackRange(ctx.hero) + NPC.GetAttackRangeBonus(ctx.hero)
			if ctx.distance(ctx.position, task.position) > range - 20 then
				local point = ctx.toward(task.position, ctx.position, math.max(100, range - 35))
				if not safe(ctx, point) then ctx.runeTask = nil; return false end
				return ctx.move(point, "Deny enemy water refill from attack range", 20)
			end
			if ctx.now >= (task.nextOrder or 0) then
				Player.PrepareUnitOrders(ctx.player, Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET, task.rune, task.position, nil,
					Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, ctx.hero, false, false, false, true, "self_play_rune_deny", false)
				task.nextOrder, ctx.lastOrder = ctx.now + 0.7, "rune_deny"
				ctx.riverDone, ctx.riverCollected, ctx.riverTask = task.cycle, task.cycle, nil
			end
			ctx.mode = "Deny enemy water refill"
			return true
		end
		if ctx.distance(ctx.position, task.position) > 140 then
			local bottle = NPC.GetItem(ctx.hero, "item_bottle", true)
			if eta == math.huge and bottle and combat.ready(ctx, bottle, true) and (ctx.abilityAttempts.item_bottle or 0) <= ctx.now
				and consumables.bottle(ctx, bottle, ctx.now - (ctx.lastDamaged or -10) > 3, ctx.laneThreat and ctx.laneThreat.distance or math.huge) then return true end
			if mobility.rune(ctx, task, eta) then return true end
			if eta < 0.5 then ctx.runeFailed[task.id], ctx.runeTask = ctx.now + 2, nil; return false end
			return ctx.move(task.position, eta < math.huge and "Contest approaching enemy for rune" or "Mid rune control", 60)
		end
		if ctx.now >= (task.nextOrder or 0) then
			Player.PrepareUnitOrders(ctx.player, Enum.UnitOrder.DOTA_UNIT_ORDER_PICKUP_RUNE, task.rune, task.position, nil,
				Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, ctx.hero, false, false, false, true, "self_play_rune", false)
			task.nextOrder, ctx.lastOrder = ctx.now + 0.4, "rune"
			if task.river then
				ctx.riverDone, ctx.riverCollected, ctx.riverTask = task.cycle, task.cycle, nil
			end
		end
		ctx.mode = "Collect rune"
		return true
	end
	return river(ctx, farm)
end

return runes
