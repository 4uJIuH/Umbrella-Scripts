local farm = {}
local awareness = require("self_play.awareness")
local navigation = require("self_play.navigation")
local laneRules = require("self_play.lane_rules")
local taskPolicy = require("self_play.task_policy")

local function live(unit)
	return unit and Entity.IsEntity(unit) and Entity.IsNPC(unit) and Entity.IsAlive(unit)
		and not Entity.IsDormant(unit) and NPC.IsVisible(unit) and not NPC.IsWaitingToSpawn(unit)
end

local function safe(ctx, point)
	if ctx.unsafePosition(point) or not awareness.farmSafe(ctx, point, 2) then return false end
	for _, enemy in ipairs(ctx.enemies) do
		if live(enemy) and ctx.distance(point, Entity.GetAbsOrigin(enemy)) < 1500 then return false end
	end
	for _, memory in pairs(ctx.memory) do
		if ctx.now - memory.time < 5 and ctx.distance(point, memory.position) < 1400 then return false end
	end
	return awareness.forecast(ctx, point) < Entity.GetHealth(ctx.hero) * 0.12
end

local function goal(ctx, point)
	local range = NPC.GetAttackRange(ctx.hero) + NPC.GetAttackRangeBonus(ctx.hero)
	return ctx.distance(ctx.position, point) <= range and ctx.position or ctx.toward(point, ctx.position, math.max(60, range - 45))
end

function farm.plan(ctx)
	local groups = {}
	for _, unit in ipairs(ctx.worldNPCs) do
		if live(unit) and NPC.IsLaneCreep(unit) and not Entity.IsSameTeam(ctx.hero, unit)
			and not NPC.HasState(unit, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE)
			and not NPC.HasState(unit, Enum.ModifierState.MODIFIER_STATE_ATTACK_IMMUNE) then
			local point, group = Entity.GetAbsOrigin(unit), nil
			for _, candidate in ipairs(groups) do
				if ctx.distance(candidate.point, point) < 650 then group = candidate; break end
			end
			if not group then group = {point = point, units = {}, gold = 0, health = 0}; groups[#groups + 1] = group end
			group.units[#group.units + 1] = unit
			group.gold = group.gold + NPC.GetGoldBountyMin(unit)
			group.health = group.health + Entity.GetHealth(unit)
		end
	end
	local candidates = {}
	for _, group in ipairs(groups) do
		local blocked = false
		for _, area in ipairs(ctx.mapFarmBlocked or {}) do
			if ctx.now < area.expires and ctx.distance(group.point, area.point) < 750 then blocked = true; break end
		end
		local distance = ctx.distance(ctx.position, group.point)
		local firing = goal(ctx, group.point)
		if not blocked and distance < 7500 and laneRules.canLastHit(ctx, group.units[1]) and safe(ctx, firing) then
			local seconds = group.health / math.max(1, NPC.GetTrueDamage(ctx.hero)) * NPC.GetSecondsPerAttack(ctx.hero, false)
			local value = group.gold / math.max(1, seconds + distance / math.max(100, NPC.GetMoveSpeed(ctx.hero)))
			for _, ally in ipairs(ctx.allies) do
				if ally ~= ctx.hero and live(ally) and not NPC.IsIllusion(ally)
					and ctx.distance(Entity.GetAbsOrigin(ally), group.point) < 1100 then value = value * 0.25 end
			end
			group.score, group.goal = value, firing
			candidates[#candidates + 1] = group
		end
	end
	table.sort(candidates, function(a, b) return a.score > b.score end)
	local best, bestScore
	for i = 1, math.min(3, #candidates) do
		local candidate = candidates[i]
		local length = navigation.safePath(ctx, candidate.goal, 40)
		if length then
			local direct = ctx.distance(ctx.position, candidate.goal)
			local score = candidate.score * math.max(0.25, direct / math.max(1, length))
			if not bestScore or score > bestScore then best, bestScore = candidate, score end
		end
	end
	return best
end

function farm.run(ctx, retainOnly)
	if ctx.clock < (ctx.laneEnd or 600) or ctx.health < 0.55 or ctx.retreating or ctx.hardRetreat or ctx.nearEnemies > 0 or taskPolicy.farmBlocked(ctx) then
		ctx.mapFarm = nil
		return false
	end
	ctx.mapFarmBlocked = ctx.mapFarmBlocked or {}
	for i = #ctx.mapFarmBlocked, 1, -1 do
		if ctx.mapFarmBlocked[i].expires <= ctx.now then table.remove(ctx.mapFarmBlocked, i) end
	end
	local task = ctx.mapFarm
	if not task then
		if retainOnly or ctx.now < (ctx.nextMapFarm or 0) then return false end
		ctx.nextMapFarm = ctx.now + 0.75
		task = farm.plan(ctx)
		if not task then return false end
		task.expires, task.progressAt = ctx.now + 35, ctx.now
		ctx.mapFarm = task
	end
	local units, target, nearest, health = {}, nil, math.huge, 0
	for _, unit in ipairs(task.units) do
		if live(unit) then
			units[#units + 1], health = unit, health + Entity.GetHealth(unit)
			local distance = ctx.distance(ctx.position, Entity.GetAbsOrigin(unit))
			if distance < nearest then target, nearest = unit, distance end
		end
	end
	if not target then ctx.mapFarm, ctx.nextMapFarm = nil, 0; return false end
	local point = Entity.GetAbsOrigin(target)
	if not safe(ctx, goal(ctx, point)) or not laneRules.canLastHit(ctx, target) then ctx.mapFarm = nil; return false end
	local previousHealth = task.health
	task.units, task.point, task.health, task.goal = units, point, health, goal(ctx, point)
	taskPolicy.progress(ctx, task, task.goal)
	local range = NPC.GetAttackRange(ctx.hero) + NPC.GetAttackRangeBonus(ctx.hero)
	if nearest < range + 150 and health < previousHealth - 5 then task.progressAt = ctx.now end
	if ctx.now > task.expires or ctx.now - task.progressAt > 5 then
		ctx.mapFarmBlocked[#ctx.mapFarmBlocked + 1] = {point = point, expires = ctx.now + 10}
		ctx.mapFarm, ctx.nextMapFarm = nil, ctx.now + 0.5
		return false
	end
	ctx.farmCandidate, ctx.spacingTask, ctx.regroupTask, ctx.aggroTask = nil, nil, nil, nil
	if nearest > range + 250 then
		if nearest > 3000 and ctx.teleport(task.goal, "farm") then return true end
		return ctx.move(task.goal, "Travel to available lane farm", 35)
	end
	if ctx.clearAbilities(units, false) then return true end
	return ctx.attack(target, "Clear available lane wave")
end

return farm
