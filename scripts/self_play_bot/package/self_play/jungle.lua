local jungle = {}
local awareness = require("self_play.awareness")
local taskPolicy = require("self_play.task_policy")

local function targetable(unit)
	return unit and Entity.IsEntity(unit) and Entity.IsNPC(unit) and Entity.IsAlive(unit) and not Entity.IsDormant(unit)
		and NPC.IsVisible(unit) and not NPC.IsWaitingToSpawn(unit) and NPC.IsNeutral(unit) and NPC.IsCreep(unit)
		and not NPC.IsRoshan(unit) and not NPC.IsTormentor(unit)
		and not NPC.HasState(unit, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE)
		and not NPC.HasState(unit, Enum.ModifierState.MODIFIER_STATE_ATTACK_IMMUNE)
		and not NPC.HasState(unit, Enum.ModifierState.MODIFIER_STATE_OUT_OF_GAME)
		and not NPC.HasState(unit, Enum.ModifierState.MODIFIER_STATE_UNTARGETABLE)
end

local function jungleCamps()
	if JungleCampsManager and JungleCampsManager.camps then return JungleCampsManager.camps end
	return {}
end

local function campAt(ctx, position)
	local best, nearest = nil, 700
	for _, camp in pairs(jungleCamps()) do
		local distance = ctx.distance(position, camp.position_)
		if distance < nearest then best, nearest = camp, distance end
	end
	return best
end

local function safeRoute(ctx, position)
	if not GridNav.IsTraversable(position) then return false end
	local path = GridNav.BuildPath(ctx.position, position)
	if #path == 0 then return false end
	if ctx.distance(path[#path], position) > 5 then path[#path + 1] = position end
	local previous, initial = ctx.position, awareness.disengageRisk(ctx, ctx.position)
	for _, waypoint in ipairs(path) do
		local distance = ctx.distance(previous, waypoint)
		for step = 0, math.max(1, math.ceil(distance / 250)) do
			local point = ctx.toward(previous, waypoint, math.min(distance, step * 250))
			if ctx.unsafePosition(point) or awareness.disengageRisk(ctx, point) > initial + 5 then return false end
			for _, entry in pairs(ctx.memory) do
				if ctx.now - entry.time < 5 and ctx.distance(point, entry.position) < 1000 then return false end
			end
		end
		previous = waypoint
	end
	return true
end

local function members(ctx, camp, origin, known)
	local units = {}
	for _, unit in ipairs(ctx.neutrals) do
		if targetable(unit) then
			local position = Entity.GetAbsOrigin(unit)
			if known and known[Entity.GetIndex(unit)] and ctx.distance(position, origin) < 1400
				or (camp and campAt(ctx, position) == camp or not camp and ctx.distance(position, origin) < 500) then
				units[#units + 1] = unit
			end
		end
	end
	return units
end

function jungle.assess(ctx, units, current, continuing)
	local result = {safe = false, seconds = 0, loss = 0, remaining = Entity.GetHealth(ctx.hero), units = {}}
	if ctx.heroModule and ctx.heroModule.farmTerritory then
		for _, unit in ipairs(units) do
			if not ctx.heroModule.farmTerritory(ctx, Entity.GetAbsOrigin(unit)) then return result end
		end
	end
	local damage = NPC.GetTrueDamage(ctx.hero)
	local period = math.max(0.25, NPC.GetSecondsPerAttack(ctx.hero, false))
	local armor = NPC.GetArmorDamageMultiplier(ctx.hero)
	local health, maximum = Entity.GetHealth(ctx.hero), Entity.GetMaxHealth(ctx.hero)
	local incoming, regeneration = 0, math.max(0, NPC.GetHealthRegen(ctx.hero))
	local spellDamage, spellTime
	if ctx.settings.spells and ctx.heroModule and ctx.heroModule.jungleDamage then spellDamage, spellTime = ctx.heroModule.jungleDamage(ctx, units) end
	for _, unit in ipairs(units) do
		local dps = damage * NPC.GetArmorDamageMultiplier(unit) / period - math.max(0, NPC.GetHealthRegen(unit))
		if dps <= 0 then return result end
		local seconds = math.max(0, Entity.GetHealth(unit) - (spellDamage and spellDamage[Entity.GetIndex(unit)] or 0)) / dps + period * 0.25
		local threat = NPC.GetTrueMaximumDamage(unit) * armor / math.max(0.3, NPC.GetSecondsPerAttack(unit, false)) * 1.15
		result.units[#result.units + 1] = {unit = unit, seconds = seconds, threat = threat, priority = threat / math.max(0.1, seconds)}
		incoming = incoming + threat
		if NPC.IsAncient(unit) then result.ancient = true end
	end
	if #result.units == 0 then return result end
	table.sort(result.units, function(a, b)
		if a.unit == b.unit then return false end
		if a.unit == current then return true end
		if b.unit == current then return false end
		if a.priority == b.priority then return Entity.GetIndex(a.unit) < Entity.GetIndex(b.unit) end
		return a.priority > b.priority
	end)
	local lowest = health
	if spellTime then
		local delay = math.min(3, spellTime)
		result.seconds = delay
		health = math.min(maximum, health - math.max(0, incoming - regeneration) * delay)
		lowest = math.min(lowest, health)
	end
	for _, entry in ipairs(result.units) do
		result.seconds = result.seconds + entry.seconds
		health = math.min(maximum, health - (incoming - regeneration) * entry.seconds)
		lowest, incoming = math.min(lowest, health), math.max(0, incoming - entry.threat)
	end
	if spellTime and result.seconds < spellTime then
		result.seconds = spellTime
	end
	result.loss, result.remaining = math.max(0, Entity.GetHealth(ctx.hero) - lowest), lowest
	result.target = result.units[1].unit
	continuing = continuing or current ~= nil
	result.safe = result.seconds <= (continuing and 45 or 35)
		and result.remaining >= maximum * (continuing and 0.35 or 0.5)
		and result.loss <= Entity.GetHealth(ctx.hero) * (continuing and 0.45 or 0.3)
		and (not result.ancient or result.seconds < 22 and result.loss < Entity.GetHealth(ctx.hero) * 0.2)
	return result
end

local function approach(ctx, position)
	local range = NPC.GetAttackRange(ctx.hero) + NPC.GetAttackRangeBonus(ctx.hero)
	local offset = math.max(80, math.min(550, range - 55))
	local preferred = ctx.toward(position, ctx.position, offset)
	if safeRoute(ctx, preferred) then return preferred end
	for _, radius in ipairs({offset}) do
		local best, score
		for index = 0, 15 do
			local angle = index * math.pi / 8
			local x, y = position.x + math.cos(angle) * radius, position.y + math.sin(angle) * radius
			local point = Vector(x, y, World.GetGroundZ(x, y))
			if safeRoute(ctx, point) then
				local distance = ctx.distance(ctx.position, point)
				if not score or distance < score then best, score = point, distance end
			end
		end
		if best then return best end
	end
	return preferred
end

local function clear(ctx, reason, cooldown, escape)
	local state = ctx.jungleState
	if not state then return end
	local task, travel = state.task, state.travel
	local camp = task and task.camp or travel and travel.camp
	local origin = task and task.origin or camp and camp.position_
	if cooldown then
		if camp then state.camps[camp.index_] = ctx.now + cooldown end
		for id in pairs(task and task.members or {}) do state.excluded[id] = ctx.now + cooldown end
		state.nextSearch = ctx.now + 3
	end
	local target = ctx.attackTarget
	if task and target then
		if not Entity.IsEntity(target) or not Entity.IsNPC(target) then
			ctx.attackTarget = nil
			if ctx.hits.ordered and ctx.hits.ordered.target == target then ctx.hits.ordered = nil end
		elseif NPC.IsNeutral(target) then
			ctx.stop()
			ctx.attackTarget, ctx.hits.ordered = nil, nil
		end
	end
	state.task, state.travel, state.status = nil, nil, reason
	if escape and origin then
		local goal = ctx.toward(origin, ctx.home, 1050)
		if safeRoute(ctx, goal) then state.exit = {goal = goal, expires = ctx.now + 4} end
	end
end

local function urgent(ctx)
	return taskPolicy.farmBlocked(ctx)
end

function jungle.active(ctx)
	local state = ctx.jungleState
	return state and (state.task ~= nil or state.travel ~= nil or state.exit ~= nil) or false
end

function jungle.update(ctx)
	if not jungle.active(ctx) then return end
	if ctx.retreating or ctx.hardRetreat or ctx.nearEnemies > 0 then
		clear(ctx, "Jungle interrupted by danger", 35)
		ctx.jungleState.exit = nil
	elseif urgent(ctx) then
		clear(ctx, "Team combat or objective takes priority")
		ctx.jungleState.exit = nil
	end
end

local function attack(ctx, task, estimate)
	local target = task.target
	local position = Entity.GetAbsOrigin(target)
	local range = NPC.GetAttackRange(ctx.hero) + NPC.GetAttackRangeBonus(ctx.hero)
	local distance = ctx.distance(ctx.position, position)
	local order = ctx.hits.ordered
	local released = not order or order.confirmed and order.release <= ctx.now
	if range >= 400 and NPC.GetAttackRange(target) < 250 and distance < math.min(330, range * 0.6)
		and NPC.IsAttacking(target) and released and ctx.attackNext - ctx.now > 0.3 and ctx.now >= (task.nextKite or 0) then
		local step = math.min(140, NPC.GetMoveSpeed(ctx.hero) * (ctx.attackNext - ctx.now - 0.15))
		local dx, dy = ctx.position.x - position.x, ctx.position.y - position.y
		local length = math.max(1, math.sqrt(dx * dx + dy * dy))
		local away = Vector(ctx.position.x + dx / length * step, ctx.position.y + dy / length * step, ctx.position.z)
		if ctx.distance(away, task.origin) < 850 and safeRoute(ctx, away) then
			task.nextKite = ctx.now + 0.7
			return ctx.move(away, "Farm jungle: create room between attacks", 20)
		end
	end
	if distance > range then
		local goal = approach(ctx, position)
		if not safeRoute(ctx, goal) then clear(ctx, "Camp firing position is unsafe", 30, true); return false end
		return ctx.move(goal, "Farm jungle: approach attack range", 20)
	end
	ctx.jungleState.status = string.format("Clear camp: %d creeps, %.1fs, projected HP %.0f", #estimate.units, estimate.seconds, estimate.remaining)
	return ctx.attack(target, "Farm jungle: finish committed camp")
end

function jungle.run(ctx, retainOnly)
	ctx.jungleState = ctx.jungleState or {excluded = {}, camps = {}}
	local state = ctx.jungleState
	jungle.update(ctx)
	local earlyFarm = ctx.heroModule and ctx.heroModule.farmReady and ctx.heroModule.farmReady(ctx)
	local laneEnd = ctx.laneEnd or 600
	if ctx.role > 3 or ctx.clock < laneEnd and not earlyFarm or ctx.retreating or ctx.hardRetreat or urgent(ctx) or ctx.nearEnemies > 0 then return false end
	for id, expiry in pairs(state.excluded) do if expiry <= ctx.now then state.excluded[id] = nil end end
	for id, expiry in pairs(state.camps) do if expiry <= ctx.now then state.camps[id] = nil end end
	if state.exit then
		if ctx.now > state.exit.expires or ctx.distance(ctx.position, state.exit.goal) < 100 then state.exit = nil
		else return ctx.move(state.exit.goal, "Leave expensive jungle camp", 90) end
	end
	local task = state.task
	if task then
		local units = members(ctx, task.camp, task.origin, task.members)
		if #units == 0 or task.camp and task.camp.is_farmed_ then
			clear(ctx, "Camp cleared or no longer visible", 60 - ctx.clock % 60 + 1)
			return false
		end
		for _, unit in ipairs(units) do task.members[Entity.GetIndex(unit)] = true end
		local current = targetable(task.target) and task.target or nil
		local estimate = jungle.assess(ctx, units, current, true)
		state.assessment = estimate
		if not estimate.safe or ctx.health < 0.4 then clear(ctx, "Camp costs too much health to finish", 45, true); return state.exit and jungle.run(ctx, true) or false end
		if not current then
			task.target, task.progressAt, task.health = estimate.target, ctx.now, Entity.GetHealth(estimate.target)
			task.distance = ctx.distance(ctx.position, Entity.GetAbsOrigin(estimate.target))
		end
		local health, distance = Entity.GetHealth(task.target), ctx.distance(ctx.position, Entity.GetAbsOrigin(task.target))
		if health < task.health - 1 or distance < task.distance - 35 then task.progressAt, task.health, task.distance = ctx.now, health, distance end
		if ctx.now > task.expires or ctx.now - task.progressAt > math.max(4, NPC.GetSecondsPerAttack(ctx.hero, false) * 3)
			or ctx.distance(ctx.position, task.origin) > 1400 then clear(ctx, "Camp made no attack or movement progress", 30); return false end
		return attack(ctx, task, estimate)
	end
	if ctx.health < 0.65 then clear(ctx, "Recover before starting another camp", 20); return false end
	state.travel = nil
	if retainOnly then return false end
	if ctx.now < (state.nextSearch or 0) then return false end
	local chosen, chosenUnits, chosenEstimate, score
	local considered = {}
	for _, unit in ipairs(ctx.neutrals) do
		if targetable(unit) and not state.excluded[Entity.GetIndex(unit)] and not ctx.hits.blocked[Entity.GetIndex(unit)] then
			local position = Entity.GetAbsOrigin(unit)
			local camp = campAt(ctx, position)
			local key = camp or unit
			if not considered[key] and ctx.distance(ctx.position, position) < 1300
				and (not camp or not camp.is_farmed_ and not state.camps[camp.index_]) then
				considered[key] = true
				local units = members(ctx, camp, camp and camp.position_ or position)
				local estimate = jungle.assess(ctx, units)
					local goal = estimate.safe and approach(ctx, Entity.GetAbsOrigin(estimate.target))
					if goal and safeRoute(ctx, goal) then
					local value = estimate.seconds + ctx.distance(ctx.position, goal) / math.max(100, NPC.GetMoveSpeed(ctx.hero)) + estimate.loss / Entity.GetMaxHealth(ctx.hero) * 30
					if not score or value < score then chosen, chosenUnits, chosenEstimate, score = {camp = camp, origin = camp and camp.position_ or position}, units, estimate, value end
				else
					if camp then state.camps[camp.index_] = ctx.now + 30 end
					for _, creep in ipairs(units) do state.excluded[Entity.GetIndex(creep)] = ctx.now + 30 end
					state.status = estimate.ancient and "Ancient pack exceeds safe clearing budget" or "Pack exceeds safe clearing budget"
				end
			end
		end
	end
	if chosen then
		state.travel = nil
		local target = chosenEstimate.target
		local taskMembers = {}
		for _, unit in ipairs(chosenUnits) do taskMembers[Entity.GetIndex(unit)] = true end
		state.task = {camp = chosen.camp, origin = chosen.origin, target = target, members = taskMembers,
			expires = ctx.now + 60, progressAt = ctx.now, health = Entity.GetHealth(target), distance = ctx.distance(ctx.position, Entity.GetAbsOrigin(target))}
		state.assessment = chosenEstimate
		ctx.farmCandidate, ctx.regroupTask, ctx.spacingTask = nil, nil, nil
		return attack(ctx, state.task, chosenEstimate)
	end
	state.status = "No visible camp worth clearing"
	return false
end

return jungle
