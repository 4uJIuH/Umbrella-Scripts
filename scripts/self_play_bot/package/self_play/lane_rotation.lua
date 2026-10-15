local rotation = {}
local jungle = require("self_play.jungle")
local taskPolicy = require("self_play.task_policy")

local function debug(ctx, message)
	if ctx.ui and ctx.ui.debug and ctx.ui.debug:Get() then Log.Write("[SelfPlay lane rotation] " .. message) end
end

local crowdRadius = 1500
local crowdTime = 60
local taskTimeout = 90
local stallTimeout = 30
local arrivalDistance = 500
local reevalInterval = 2
local cooldownTime = 45
local dangerRadius = 1500
local minCreeps = 2

local function liveAlly(ctx, unit)
	if unit == ctx.hero or not Entity.IsEntity(unit) or not Entity.IsAlive(unit) or Entity.IsDormant(unit) then return false end
	if not Entity.IsSameTeam(ctx.hero, unit) or not NPC.IsHero(unit) or NPC.IsIllusion(unit) or NPC.IsMeepoClone(unit) then return false end
	if Hero.GetReplicatingOtherHeroModel(unit) ~= nil then return false end
	return true
end

local function seenEnemy(unit)
	return Entity.IsEntity(unit) and Entity.IsAlive(unit) and not Entity.IsDormant(unit) and NPC.IsVisible(unit)
end

local function laneOf(position)
	if math.abs(position.x - position.y) < 2000 then return 2 end
	if position.y > position.x then return 1 end
	return 3
end

local function scanLanes(ctx)
	local lanes = {}
	for lane = 1, 3 do lanes[lane] = {creeps = 0, x = 0, y = 0} end
	for _, unit in ipairs(ctx.worldNPCs or {}) do
		if Entity.IsEntity(unit) and Entity.IsAlive(unit) and not Entity.IsDormant(unit) and not NPC.IsWaitingToSpawn(unit)
			and NPC.IsLaneCreep(unit) and not Entity.IsSameTeam(ctx.hero, unit) then
			local position = Entity.GetAbsOrigin(unit)
			local entry = lanes[laneOf(position)]
			entry.creeps = entry.creeps + 1
			entry.x, entry.y = entry.x + position.x, entry.y + position.y
		end
	end
	return lanes
end

local function wavePoint(entry)
	local x, y = entry.x / entry.creeps, entry.y / entry.creeps
	return Vector(x, y, World.GetGroundZ(x, y))
end

local function destOk(ctx, entry)
	if entry.creeps < 1 then return nil, "no wave" end
	local point = wavePoint(entry)
	if ctx.unsafePosition(point) then return nil, "unsafe" end
	for _, ally in ipairs(ctx.allies or {}) do
		if liveAlly(ctx, ally) and ctx.distance(Entity.GetAbsOrigin(ally), point) < dangerRadius then return nil, "ally present" end
	end
	for _, enemy in ipairs(ctx.enemies or {}) do
		if seenEnemy(enemy) and ctx.distance(Entity.GetAbsOrigin(enemy), point) < dangerRadius then return nil, "enemy near" end
	end
	return point
end

local function pickDest(ctx, lanes)
	local best, bestScore, bestPoint, bestCreeps, bestDist
	local blockers = {}
	for lane = 1, 3 do
		if lane ~= ctx.lane then
			local entry = lanes[lane]
			if entry.creeps >= minCreeps then
				local point, blocker = destOk(ctx, entry)
				if point then
					local dist = ctx.distance(ctx.position, point)
					local score = entry.creeps * 500 - dist * 0.2
					if not bestScore or score > bestScore then best, bestScore, bestPoint, bestCreeps, bestDist = lane, score, point, entry.creeps, dist end
				else
					blockers[#blockers + 1] = "lane " .. lane .. " " .. blocker
				end
			else
				blockers[#blockers + 1] = "lane " .. lane .. " only " .. entry.creeps .. " creeps"
			end
		end
	end
	if not best then return nil, table.concat(blockers, "; ") end
	return {lane = best, point = bestPoint, creeps = bestCreeps, dist = bestDist, expires = ctx.now + taskTimeout, nextReeval = ctx.now + reevalInterval, nextTp = 0}
end

local function busy(ctx)
	return ctx.intent or ctx.teamTask or ctx.campTask or ctx.objectiveTask or ctx.runeTask or ctx.riverTask or ctx.mapFarm or jungle.active(ctx)
end

local function release(ctx)
	ctx.laneRotTask, ctx.crowdSince = nil, nil
	ctx.laneRotCooldown = ctx.now + cooldownTime
end

function rotation.run(ctx)
	if ctx.settings.laneRotation == false then
		if ctx.laneRotTask or ctx.crowdSince then debug(ctx, "cleared: disabled in settings") end
		ctx.laneRotTask, ctx.crowdSince = nil, nil
		return false
	end
	if ctx.clock < 0 or ctx.clock >= (ctx.laneEnd or 600) or ctx.role == 2 or ctx.retreating or ctx.hardRetreat then
		if ctx.laneRotTask or ctx.crowdSince then debug(ctx, "cleared: inactive phase, role, retreat") end
		ctx.laneRotTask, ctx.crowdSince = nil, nil
		return false
	end
	local task = ctx.laneRotTask
	if not task then
		if busy(ctx) then
			if ctx.crowdSince then debug(ctx, "crowd timer reset: busy with higher priority task") end
			ctx.crowdSince = nil
			return false
		end
		local crowded = 0
		for _, ally in ipairs(ctx.allies or {}) do
			if liveAlly(ctx, ally) and ctx.distance(ctx.position, Entity.GetAbsOrigin(ally)) < crowdRadius then crowded = crowded + 1 end
		end
		if crowded < 2 then
			if ctx.crowdSince then debug(ctx, string.format("crowd dispersed after %.0fs on lane %d", ctx.now - ctx.crowdSince, ctx.lane)) end
			ctx.crowdSince = nil
			return false
		end
		if not ctx.crowdSince then
			ctx.crowdSince = ctx.now
			ctx.nextLaneRotLog = 0
			debug(ctx, string.format("crowded=%d on lane %d, waiting %ds", crowded, ctx.lane, crowdTime))
		elseif ctx.now >= (ctx.nextLaneRotLog or 0) and ctx.now - ctx.crowdSince < crowdTime then
			ctx.nextLaneRotLog = ctx.now + 15
			debug(ctx, string.format("still crowded=%d on lane %d (%.0fs/%ds)", crowded, ctx.lane, ctx.now - ctx.crowdSince, crowdTime))
		end
		if ctx.now - ctx.crowdSince < crowdTime or ctx.now < (ctx.laneRotCooldown or 0) then return false end
		if ctx.now < (ctx.nextLaneRotEval or 0) then return false end
		ctx.nextLaneRotEval = ctx.now + reevalInterval
		local refuse
		task, refuse = pickDest(ctx, scanLanes(ctx))
		if not task then
			local memory = ctx.laneRotRefuse
			if not memory or memory.reason ~= refuse or ctx.now - memory.at > 30 then
				ctx.laneRotRefuse = {reason = refuse, at = ctx.now}
				debug(ctx, "no free lane: " .. refuse)
			end
			return false
		end
		ctx.laneRotRefuse = nil
		ctx.laneRotTask = task
		debug(ctx, string.format("from lane %d crowded=%d for %.0fs -> lane %d creeps=%d dist=%.0f", ctx.lane, crowded, ctx.now - ctx.crowdSince, task.lane, task.creeps, task.dist))
	end
	if busy(ctx) then return false end
	if ctx.now >= task.expires then
		debug(ctx, string.format("task expired after %ds", taskTimeout))
		release(ctx)
		return false
	end
	if ctx.now >= task.nextReeval then
		task.nextReeval = ctx.now + reevalInterval
		local point, blocker = destOk(ctx, scanLanes(ctx)[task.lane])
		if not point then
			debug(ctx, string.format("lane %d lost: %s", task.lane, blocker))
			release(ctx)
			return false
		end
		task.point = point
	end
	if ctx.distance(ctx.position, task.point) < arrivalDistance then
		debug(ctx, string.format("arrived lane %d, lane switched", task.lane))
		ctx.lane = task.lane
		release(ctx)
		return false
	end
	taskPolicy.progress(ctx, task, task.point)
	if ctx.now - (task.progressAt or ctx.now) > stallTimeout then
		debug(ctx, string.format("stalled %ds without progress", stallTimeout))
		release(ctx)
		return false
	end
	if ctx.now >= task.nextTp then
		task.nextTp = ctx.now + 3
		if ctx.teleport(task.point, "rotate") then
			debug(ctx, string.format("teleport to lane %d dist=%.0f", task.lane, ctx.distance(ctx.position, task.point)))
			return true
		end
	end
	if not task.departLogged then
		task.departLogged = true
		debug(ctx, string.format("walk to lane %d dist=%.0f", task.lane, ctx.distance(ctx.position, task.point)))
	end
	ctx.mode = "Rotate to free lane"
	return ctx.move(task.point, "Rotate to free lane")
end

return rotation
