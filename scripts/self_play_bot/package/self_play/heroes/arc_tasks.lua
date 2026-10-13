local tasks = {}
local common = require("self_play.heroes.common")

local function safe(ctx, position)
	if ctx.unsafePosition(position) then return false end
	for _, enemy in ipairs(ctx.enemies) do
		if common.visible(enemy) and ctx.distance(position, Entity.GetAbsOrigin(enemy)) < 1500 then return false end
	end
	for _, entry in pairs(ctx.memory) do
		if ctx.now - entry.time < 6 and ctx.distance(position, entry.position) < 1400 then return false end
	end
	for _, arrival in ipairs(ctx.teleportArrivals or {}) do
		if ctx.distance(position, arrival.position) < 1400 then return false end
	end
	return true
end

function tasks.landing(ctx, destination)
	local best, distance, target = nil, math.huge, nil
	for _, tower in ipairs(ctx.structures) do
		if common.visible(tower) and NPC.IsTower(tower) and Entity.IsSameTeam(ctx.hero, tower) then
			local position = Entity.GetAbsOrigin(tower)
			local current = ctx.distance(position, destination)
			if current < distance and safe(ctx, position) then best, distance = position, current end
		end
	end
	local boots = NPC.GetItem(ctx.hero, "item_travel_boots_2", false) or NPC.GetItem(ctx.hero, "item_travel_boots", false)
	if boots and Item.IsItemEnabled(boots) then
		for _, wave in ipairs(ctx.waves) do
			for _, creep in ipairs(wave) do
				if common.visible(creep) and Entity.GetHealth(creep) > 350 then
					local point = ctx.predict(creep, 3)
					local current = ctx.distance(point, destination)
					if current < distance and safe(ctx, point) then best, distance, target = point, current, creep end
				end
			end
		end
	end
	return best, distance, target
end

function tasks.fronts(ctx)
	local fronts = {}
	for lane, wave in ipairs(ctx.waves) do
		local front, nearest
		for _, creep in ipairs(wave) do
			if common.visible(creep) and not NPC.IsWaitingToSpawn(creep) then
				local point = Entity.GetAbsOrigin(creep)
				local distance = ctx.distance(point, ctx.enemyHome)
				if ctx.distance(point, ctx.home) > 2600 and safe(ctx, point) and (not nearest or distance < nearest) then front, nearest = creep, distance end
			end
		end
		if front then fronts[#fronts + 1] = {target = front, lane = lane} end
	end
	return fronts
end

function tasks.choose(ctx, api, remaining)
	local scroll = NPC.GetItem(ctx.hero, "item_tpscroll", false)
	local canTeleport = scroll and api.ready(ctx, scroll, true) and ctx.now >= (ctx.heroState.nextTeleport or 0)
	ctx.heroState.travelReason = canTeleport and "Compare forward teleport destinations" or "Teleport scroll unavailable; compare reachable fronts"
	local best, bestScore
	for _, creep in ipairs(ctx.worldNPCs) do
		if common.visible(creep) and NPC.IsLaneCreep(creep) and not Entity.IsSameTeam(ctx.hero, creep) then
			local position = Entity.GetAbsOrigin(creep)
			local distance = ctx.distance(ctx.position, position)
			if distance > 1200 and safe(ctx, position) then
				local landing, after, landingTarget = tasks.landing(ctx, position)
				local walking = distance / math.max(100, NPC.GetMoveSpeed(ctx.hero))
				local travel = canTeleport and landing and math.min(walking, 3 + after / math.max(100, NPC.GetMoveSpeed(ctx.hero))) or walking
				if travel + 5 < remaining then
					local teleport = canTeleport and landing and walking - travel > 4
					local score = 1200 - travel * 35 + ctx.distance(position, ctx.home) * 0.06 + (teleport and 350 or 0)
					for _, ally in ipairs(ctx.allies) do
						if ally ~= ctx.hero and common.visible(ally) and ctx.distance(Entity.GetAbsOrigin(ally), position) < 1400 then score = score - 1000 end
					end
					if score > 0 and (not bestScore or score > bestScore) then
						best, bestScore = {target = creep, position = position, expires = ctx.now + math.min(remaining - 1, travel + 8),
							landing = teleport and landing or nil, landingTarget = teleport and landingTarget or nil}, score
					end
				end
			end
		end
	end
	for _, front in ipairs(tasks.fronts(ctx)) do
		local creep = front.target
		local position = ctx.toward(Entity.GetAbsOrigin(creep), ctx.home, 180)
		local distance = ctx.distance(ctx.position, position)
		local landing, after, landingTarget = tasks.landing(ctx, position)
		local walking = distance / math.max(100, NPC.GetMoveSpeed(ctx.hero))
		local travel = canTeleport and landing and math.min(walking, 3 + after / math.max(100, NPC.GetMoveSpeed(ctx.hero))) or walking
		if distance > 700 and travel + 5 < remaining and safe(ctx, position)
			and ctx.distance(position, ctx.home) >= ctx.distance(ctx.position, ctx.home) - 1200 then
			local teleport = canTeleport and landing and walking - travel > 4
			local score = 500 - travel * 35 + ctx.distance(position, ctx.home) * 0.12 + (teleport and 350 or 0)
			if score > 0 and (not bestScore or score > bestScore) then
				best, bestScore = {target = creep, position = position, expires = ctx.now + math.min(remaining - 1, travel + 8),
					landing = teleport and landing or nil, landingTarget = teleport and landingTarget or nil, lane = front.lane}, score
			end
		end
	end
	return best
end

function tasks.travel(ctx, api, remaining)
	local state, task = ctx.heroState, ctx.heroState.farmTask
	if task and ctx.distance(ctx.position, task.position) < 500 then state.farmTask = nil; return false end
	if task and (ctx.now > task.expires or not safe(ctx, task.position)
		or not common.visible(task.target)) then state.farmTask, task = nil, nil end
	if not task and ctx.now >= (state.nextFarmPlan or 0) then
		state.nextFarmPlan = ctx.now + 1
		task = tasks.choose(ctx, api, remaining)
		state.farmTask = task
	end
	if not task then return false end
	if task.landing and ctx.nearEnemies == 0 and Hero.GetRecentDamage(ctx.hero) == 0
		and ctx.now >= (state.nextTeleport or 0) then
		local scroll = NPC.GetItem(ctx.hero, "item_tpscroll", false)
		if scroll and api.ready(ctx, scroll, true) then
			state.nextTeleport, task.landing = ctx.now + 8, nil
			local landing, _, target = tasks.landing(ctx, task.position)
			if landing then
				ctx.busyUntil, state.travelReason = ctx.now + 0.6, "Teleport to forward lane group"
				return api.cast(ctx, scroll, target and "target" or "point", target, landing)
			end
		end
	end
	return ctx.move(task.position)
end

return tasks
