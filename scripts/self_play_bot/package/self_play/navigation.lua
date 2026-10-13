local navigation = {}
local towerSafety = require("self_play.tower_safety")
local awareness = require("self_play.awareness")

function navigation.treeWalking(ctx)
	return NPC.GetUnitName(ctx.hero) == "npc_dota_hero_treant"
		and NPC.HasState(ctx.hero, Enum.ModifierState.MODIFIER_STATE_ALLOW_PATHING_THROUGH_TREES)
end

function navigation.walkable(ctx, destination)
	if GridNav.IsTraversable(destination) then return destination end
	for _, radius in ipairs({96, 192, 320, 480}) do
		local best, score
		for index = 0, 15 do
			local angle = index * math.pi / 8
			local x, y = destination.x + math.cos(angle) * radius, destination.y + math.sin(angle) * radius
			local point = Vector(x, y, World.GetGroundZ(x, y))
			if GridNav.IsTraversable(point) and not ctx.unsafePosition(point) then
				local value = ctx.distance(ctx.position, point) + awareness.risk(ctx, point) * 3
					+ (4 - ctx.clearance(point)) * 250
				if not score or value < score then best, score = point, value end
			end
		end
		if best then return best end
	end
	return nil
end

function navigation.coverAnchor(ctx)
	local best, score = ctx.home, ctx.distance(ctx.position, ctx.home) * 0.35
	local current = awareness.risk(ctx, ctx.position)
	local function consider(unit, tower)
		if unit == ctx.hero or not Entity.IsEntity(unit) or not Entity.IsAlive(unit) or Entity.IsDormant(unit)
			or not Entity.IsSameTeam(ctx.hero, unit) or not tower and (NPC.IsIllusion(unit) or Entity.GetHealth(unit) < Entity.GetMaxHealth(unit) * 0.55) then return end
		local position = ctx.toward(Entity.GetAbsOrigin(unit), ctx.home, 180)
		local distance = ctx.distance(ctx.position, position)
		if distance > 6000 or ctx.unsafePosition(position) or not GridNav.IsTraversable(position) then return end
		local risk = awareness.risk(ctx, position)
		if ctx.retreating and awareness.damage(ctx, position, 2) + awareness.forecast(ctx, position) > Entity.GetHealth(ctx.hero) * 0.08 then return end
		if risk > math.max(40, current * 0.6) then return end
		local value = distance * 0.35 + risk * 4 + (tower and -180 or 120)
		if value < score then best, score = position, value end
	end
	for _, tower in ipairs(ctx.towers) do consider(tower, true) end
	for _, ally in ipairs(ctx.allies) do consider(ally, false) end
	return best
end

function navigation.safePath(ctx, destination, riskAllowance)
	local path = GridNav.BuildPath(ctx.position, destination, navigation.treeWalking(ctx))
	if #path == 0 then return nil end
	if ctx.distance(path[#path], destination) > 5 then path[#path + 1] = destination end
	local initial = awareness.risk(ctx, ctx.position)
	local length, previous, waypoint, last = 0, ctx.position, nil, ctx.position
	for _, point in ipairs(path) do
		local segment = ctx.distance(previous, point)
		for step = 1, math.max(1, math.ceil(segment / 100)) do
			local sample = ctx.toward(previous, point, math.min(segment, step * 100))
			if ctx.unsafePosition(sample) or riskAllowance and awareness.risk(ctx, sample) > initial + riskAllowance then return nil, nil, last end
			last = sample
		end
		length = length + segment
		if not waypoint and ctx.distance(ctx.position, point) > 100 then waypoint = point end
		previous = point
	end
	return length, waypoint or destination, last
end

local function towerExposure(ctx, point)
	local exposure = 0
	for _, tower in ipairs(ctx.towers) do
		if Entity.IsEntity(tower) and Entity.IsAlive(tower) and not Entity.IsSameTeam(ctx.hero, tower) then
			exposure = exposure + math.max(0, NPC.GetAttackRange(tower) + 160 - ctx.distance(point, Entity.GetAbsOrigin(tower)))
		end
	end
	return exposure
end

function navigation.escape(ctx, desired)
	desired = desired or navigation.coverAnchor(ctx)
	local initial = towerExposure(ctx, ctx.position)
	local initialRisk = awareness.risk(ctx, ctx.position)
	local treeWalking = navigation.treeWalking(ctx)
	local cached = ctx.escapeRoute
	if cached and cached.treeWalking == treeWalking and ctx.now < cached.expires and ctx.distance(ctx.position, cached.position) > 60
		and (initial > 0 and towerExposure(ctx, cached.position) <= math.max(0, initial - 40) or initial == 0 and not ctx.unsafePosition(cached.position))
		and GridNav.IsTraversable(cached.position) and awareness.risk(ctx, cached.position) <= initialRisk + 40
		and awareness.damage(ctx, cached.position, 1.5) + awareness.forecast(ctx, cached.position)
			<= awareness.damage(ctx, ctx.position, 1.5) + awareness.forecast(ctx, ctx.position)
				+ math.max(40, Entity.GetHealth(ctx.hero) * 0.05) then return cached.position end
	local candidates = {}
	for _, radius in ipairs({160, 400, 800, 1200}) do
		for index = 0, 15 do
			local angle = index * math.pi / 8
			local x, y = ctx.position.x + math.cos(angle) * radius, ctx.position.y + math.sin(angle) * radius
			local point = Vector(x, y, World.GetGroundZ(x, y))
			local exposure = towerExposure(ctx, point)
			if GridNav.IsTraversable(point) and (initial > 0 and exposure <= math.max(0, initial - 40) or initial == 0 and not ctx.unsafePosition(point)) then
				candidates[#candidates + 1] = {position = point, score = exposure * 8 + awareness.risk(ctx, point)
					+ awareness.damage(ctx, point, 1.5) * 2 + radius * 0.7 + ctx.distance(point, desired) * 0.6}
			end
		end
	end
	table.sort(candidates, function(a, b) return a.score < b.score end)
	for index = 1, math.min(12, #candidates) do
		local candidate = candidates[index]
		local path = GridNav.BuildPath(ctx.position, candidate.position, treeWalking)
		local previous, valid, length = ctx.position, #path > 0, 0
		for _, waypoint in ipairs(path) do
			local segment = ctx.distance(previous, waypoint)
			length = length + segment
			for step = 1, math.max(1, math.ceil(segment / 80)) do
				local point = ctx.toward(previous, waypoint, math.min(segment, step * 80))
				if towerExposure(ctx, point) > initial + 20 or awareness.risk(ctx, point) > initialRisk + 40 then valid = false; break end
			end
			if not valid then break end
			previous = waypoint
		end
		if valid and length < 1800 then
			ctx.escapeRoute = {position = candidate.position, expires = ctx.now + 0.35, treeWalking = treeWalking}
			return candidate.position
		end
	end
	local best, bestScore
	for _, radius in ipairs({120, 240, 400}) do
		for index = 0, 23 do
			local angle = index * math.pi / 12
			local x, y = ctx.position.x + math.cos(angle) * radius, ctx.position.y + math.sin(angle) * radius
			local point = Vector(x, y, World.GetGroundZ(x, y))
			local exposure, risk = towerExposure(ctx, point), awareness.risk(ctx, point)
			if GridNav.IsTraversable(point) and (initial > 0 and exposure <= math.max(0, initial - 30)
				or initial == 0 and not ctx.unsafePosition(point) and risk < initialRisk - 15) then
				local path = GridNav.BuildPath(ctx.position, point, treeWalking)
				local previous, length, peak, valid = ctx.position, 0, initial, #path > 0
				for _, waypoint in ipairs(path) do
					local segment = ctx.distance(previous, waypoint)
					length = length + segment
					for step = 1, math.max(1, math.ceil(segment / 40)) do
						peak = math.max(peak, towerExposure(ctx, ctx.toward(previous, waypoint, math.min(segment, step * 40))))
					end
					previous = waypoint
				end
				valid = valid and ctx.distance(previous, point) < 60 and length < radius * 1.8 and peak <= initial + 20
				local score = exposure * 8 + risk + awareness.damage(ctx, point, 1) * 2 + length + ctx.distance(point, desired) * 0.6
				if valid and (not bestScore or score < bestScore) then best, bestScore = point, score end
			end
		end
	end
	if best then ctx.escapeRoute = {position = best, expires = ctx.now + 0.2, treeWalking = treeWalking}; return best end
	ctx.escapeRoute = nil
	return nil
end

function navigation.regroup(ctx, front, fallback)
	for _, structure in ipairs(ctx.structures) do
		if Entity.IsEntity(structure) and Entity.IsAlive(structure) and not Entity.IsSameTeam(ctx.hero, structure)
			and ctx.distance(ctx.position, Entity.GetAbsOrigin(structure)) < 1400
			and ctx.pushSafe(structure) and towerSafety.attackers(ctx, structure) + towerSafety.siege(ctx, structure) > 0 then
			ctx.regroupTask = nil
			return nil
		end
	end
	if front and ctx.distance(front, ctx.home) >= ctx.distance(ctx.position, ctx.home) - 250 then
		ctx.regroupTask = nil
		return nil
	end
	local task = ctx.regroupTask
	if task and ctx.now - task.progressAt > 3 and ctx.distance(ctx.position, task.progressPosition) < 80 then
		ctx.regroupTask, ctx.nextRegroup = nil, ctx.now + 6
		return nil
	end
	if not task and ctx.now < (ctx.nextRegroup or 0) then return nil end
	if task and task.lane ~= ctx.lane then task = nil; ctx.regroupTask = nil end
	if front and ctx.distance(ctx.position, front) < 1000 then ctx.regroupTask = nil; return nil end
	local unsupported = false
	for _, tower in ipairs(ctx.towers) do
		if Entity.IsEntity(tower) and Entity.IsAlive(tower) and not Entity.IsSameTeam(ctx.hero, tower)
			and ctx.distance(ctx.position, Entity.GetAbsOrigin(tower)) < NPC.GetAttackRange(tower) + 850 then
			unsupported = true
			break
		end
	end
	if not task and not unsupported then return nil end
	local destination
	if front and ctx.distance(front, ctx.home) < ctx.distance(ctx.position, ctx.home) - 500 then
		destination = ctx.toward(front, ctx.enemyHome, 300)
		if ctx.unsafePosition(destination) then destination = ctx.toward(front, ctx.home, 250) end
	elseif task then destination = task.goal
	else destination = ctx.toward(ctx.position, fallback, math.min(1400, ctx.distance(ctx.position, fallback))) end
	if ctx.distance(ctx.position, destination) < 140 then ctx.regroupTask = nil; return nil end
	local progressed = not task or ctx.distance(ctx.position, task.progressPosition) > 80
	ctx.regroupTask = {lane = ctx.lane, goal = destination,
		progressAt = progressed and ctx.now or task.progressAt, progressPosition = progressed and ctx.position or task.progressPosition}
	ctx.waveAnchor, ctx.waveSeen, ctx.waveLane = nil, nil, nil
	return destination
end

function navigation.teleportWorth(ctx, destination, arrival, purpose)
	if ctx.regroupTask and purpose ~= "fight" and purpose ~= "defend" then return false end
	local fromBase = ctx.distance(ctx.position, ctx.home) < 2000
	local routine = purpose == "lane" or purpose == "rotate"
	if routine and not fromBase then
		if ctx.intent and ctx.intent.kind == "structure" or ctx.distance(ctx.position, ctx.enemyHome) < 4500 then return false end
		local progress = ctx.distance(ctx.position, ctx.home)
		if ctx.distance(destination, ctx.home) < progress - 1200 or ctx.distance(arrival, ctx.home) < progress - 1800 then return false end
	end
	local currentLane = math.abs(ctx.position.x - ctx.position.y) < 2000 and 2 or ctx.position.y > ctx.position.x and 1 or 3
	if purpose == "lane" and not fromBase and currentLane == ctx.lane then return false end
	local walking = ctx.distance(ctx.position, destination)
	if walking < (routine and not fromBase and 4000 or 3000) then return false end
	local remaining = ctx.distance(arrival, destination)
	local saved = (walking - remaining) / math.max(100, NPC.GetMoveSpeed(ctx.hero)) - 3
	return walking - remaining >= 2200 and saved >= ((purpose == "defend" or purpose == "fight") and 4 or 8)
end

function navigation.detour(ctx, destination, allowance)
	local cached = ctx.navigationDetour
	if cached and ctx.now < cached.expires and ctx.distance(cached.destination, destination) < 150
		and ctx.distance(ctx.position, cached.point) > 80 and navigation.safePath(ctx, cached.point, allowance) then return cached.point end
	if ctx.now < (ctx.nextDetour or 0) then return nil end
	ctx.nextDetour = ctx.now + 0.6
	local candidates = {}
	for _, radius in ipairs({500, 1000}) do
		for index = 0, 11 do
			local angle = index * math.pi / 6
			local x, y = ctx.position.x + math.cos(angle) * radius, ctx.position.y + math.sin(angle) * radius
			local point = Vector(x, y, World.GetGroundZ(x, y))
			if GridNav.IsTraversable(point) and not ctx.unsafePosition(point) then
				candidates[#candidates + 1] = {point = point, score = ctx.distance(point, destination) + radius}
			end
		end
	end
	table.sort(candidates, function(a, b) return a.score < b.score end)
	for _, candidate in ipairs(candidates) do
		local length = navigation.safePath(ctx, candidate.point, allowance)
		if length then
			local nextContext = setmetatable({position = candidate.point}, {__index = ctx})
			local remaining = navigation.safePath(nextContext, destination, allowance)
			if remaining and length + remaining < ctx.distance(ctx.position, destination) + 2400 then
				ctx.navigationDetour = {point = candidate.point, destination = destination, expires = ctx.now + 2}
				return candidate.point
			end
		end
	end
	ctx.navigationDetour = nil
	return nil
end

local function resolveGoal(ctx, desired)
	if ctx.unsafePosition(ctx.position) then
		return navigation.escape(ctx, navigation.coverAnchor(ctx)) or navigation.coverAnchor(ctx)
	end
	desired = navigation.walkable(ctx, desired)
	if not desired then
		local anchor = navigation.coverAnchor(ctx)
		return GridNav.IsTraversable(anchor) and anchor or ctx.home
	end
	local cautious = ctx.retreating or not ctx.intent and not (ctx.teamTask and ctx.teamTask.fighting)
	local calm = (ctx.nearEnemies or 0) == 0 and #(ctx.teleportArrivals or {}) == 0
		and ctx.now - (ctx.edgeWaitSince or ctx.now) > 2
	local allowance = cautious and not calm and 40 or nil
	local length, _, last = navigation.safePath(ctx, desired, allowance)
	if length then return desired end
	local safeDesired = desired and not ctx.unsafePosition(desired) and desired or nil
	if cautious and ctx.laneThreat and (ctx.laneThreat.avoid or ctx.laneThreat.attacked) then
		return navigation.escape(ctx, navigation.coverAnchor(ctx)) or last or safeDesired or navigation.coverAnchor(ctx)
	end
	return navigation.detour(ctx, desired, allowance) or last or safeDesired or navigation.coverAnchor(ctx)
end

function navigation.goal(ctx, desired)
	local cached = ctx.navigationGoal
	local walking = navigation.treeWalking(ctx)
	local fighting = ctx.intent ~= nil and ctx.intent ~= false or ctx.teamTask and ctx.teamTask.fighting or ctx.fightSession ~= nil
	if cached and ctx.now < cached.expires and cached.scan == ctx.nextScan and cached.walking == walking
		and cached.retreating == ctx.retreating and cached.fighting == fighting and cached.unsafe == ctx.unsafePosition
		and ctx.distance(ctx.position, cached.origin) < 45 and ctx.distance(desired, cached.desired) < 35
		and not ctx.unsafePosition(ctx.position) and (not cached.goal or not ctx.unsafePosition(cached.goal)) then return cached.goal end
	local goal = resolveGoal(ctx, desired)
	ctx.navigationGoal = {goal = goal, desired = desired, origin = ctx.position, expires = ctx.now + 0.12,
		scan = ctx.nextScan, walking = walking, retreating = ctx.retreating, fighting = fighting, unsafe = ctx.unsafePosition}
	return goal
end

return navigation
