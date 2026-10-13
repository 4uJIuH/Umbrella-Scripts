local spacing = {}
local navigation = require("self_play.navigation")
local awareness = require("self_play.awareness")
local geometry = require("self_play.lane_geometry")

local function live(unit)
	return unit and Entity.IsEntity(unit) and Entity.IsAlive(unit) and not Entity.IsDormant(unit) and NPC.IsVisible(unit)
end

local function path(ctx, point)
	if ctx.distance(ctx.position, point) < 30 then return 0, point end
	local points = GridNav.BuildPath(ctx.position, point, navigation.treeWalking(ctx))
	if #points == 0 then return nil end
	if ctx.distance(points[#points], point) > 5 then points[#points + 1] = point end
	local length, previous, nextPoint = 0, ctx.position, nil
	local initialRisk = awareness.risk(ctx, ctx.position)
	for _, waypoint in ipairs(points) do
		local segment = ctx.distance(previous, waypoint)
		for step = 1, math.max(1, math.ceil(segment / 120)) do
			local sample = ctx.toward(previous, waypoint, math.min(segment, step * 120))
			if ctx.unsafePosition(sample) or awareness.risk(ctx, sample) > initialRisk + 35 then return nil end
		end
		length, previous = length + ctx.distance(previous, waypoint), waypoint
		if ctx.unsafePosition(waypoint) then return nil end
		if not nextPoint and ctx.distance(ctx.position, waypoint) > 80 then nextPoint = waypoint end
	end
	return length + ctx.distance(previous, point), nextPoint or point
end

local function exposure(ctx, point)
	local risk = awareness.risk(ctx, point)
	for _, enemy in ipairs(ctx.enemies) do
		if live(enemy) and not NPC.IsStunned(enemy) then
			local position = ctx.predict(enemy, 0.4)
			local reach = NPC.GetAttackRange(enemy) + NPC.GetAttackRangeBonus(enemy) + 100
			local distance = ctx.distance(point, position)
			local attack = NPC.GetTrueDamage(enemy) * NPC.GetArmorDamageMultiplier(ctx.hero)
			local recovery = ctx.hits.cycles and ctx.hits.cycles[Entity.GetIndex(enemy)]
			local occupied = recovery and recovery.nextStart > ctx.now + 0.45
			risk = risk + math.max(0, reach - distance) * (occupied and 0.25 or 0.8)
			if distance < reach then risk = risk + attack * (occupied and 0.25 or 1) end
			if position.z - point.z > 80 and distance < reach + 250 then risk = risk + 120 end
		end
	end
	for _, creep in ipairs(ctx.creeps) do
		if live(creep) and not Entity.IsSameTeam(ctx.hero, creep) then
			local distance = ctx.distance(point, ctx.predict(creep, 0.25))
			local body = NPC.GetHullRadius(ctx.hero) + NPC.GetHullRadius(creep) + 20
			risk = risk + math.max(0, body - distance) * 5
			if (ctx.creepAggro[Entity.GetIndex(creep)] or 0) > ctx.now then
				risk = risk + math.max(0, NPC.GetAttackRange(creep) + 90 - distance) * 0.45
			end
		end
	end
	return risk
end

function spacing.choose(ctx, focus, plan)
	if not live(focus) then return nil end
	local untilHit = plan and math.max(0, plan.start - ctx.now) or nil
	if untilHit and untilHit < 0.32 then return nil end
	local range = NPC.GetAttackRange(ctx.hero) + NPC.GetAttackRangeBonus(ctx.hero)
	local speed = math.max(100, NPC.GetMoveSpeed(ctx.hero))
	local leadTime = math.max(0.22, NPC.GetTimeToFace(ctx.hero, focus) + 0.12)
	local entering = untilHit and untilHit <= 0.85 + leadTime
	local idle = ctx.spacingIdle and ctx.now - ctx.spacingIdle.since > 1.6 and not entering
	local pressMelee = ctx.health > 0.6 and #ctx.enemies > 0
	if pressMelee then
		for _, enemy in ipairs(ctx.enemies) do
			if live(enemy) and NPC.IsRanged(enemy) then pressMelee = false; break end
		end
	end
	local currentExposure = exposure(ctx, ctx.position)
	local center = ctx.predict(focus, math.min(0.4, untilHit or 0.4))
	local cover = geometry.back(ctx, center)
	local dx, dy = center.x - cover.x, center.y - cover.y
	local axisLength = math.max(1, math.sqrt(dx * dx + dy * dy))
	dx, dy = dx / axisLength, dy / axisLength
	local candidates, seen = {}, {}
	local function add(position)
		local key = math.floor(position.x / 35) .. ":" .. math.floor(position.y / 35)
		if seen[key] then return end
		seen[key] = true
		local point = Vector(position.x, position.y, World.GetGroundZ(position.x, position.y))
		local distance, travel = ctx.distance(point, center), ctx.distance(ctx.position, point)
		local forward = (point.x - center.x) * dx + (point.y - center.y) * dy
		if forward > (entering and 35 or pressMelee and 60 or 10) then return end
		if distance > math.max(1000, range + 380) or entering and distance > range - 15
			or not GridNav.IsTraversable(point) or ctx.unsafePosition(point) then return end
		local access = math.max(0, distance - range + 25) / speed
		if untilHit and (travel / speed + access + leadTime >= untilHit) then return end
		local exposureScore = exposure(ctx, point)
		local score = exposureScore * 3 + travel * 0.13 + access * (entering and 320 or NPC.IsRanged(ctx.hero) and 240 or 90)
		if not entering then
			local preferred = NPC.IsRanged(ctx.hero) and math.max(160, range - 60) or 210
			score = score + math.abs(distance - preferred) * 0.18
		end
		local behind = ctx.distance(point, cover)
		score = score + behind * 0.07
		for _, creep in ipairs(ctx.creeps) do
			if live(creep) and creep ~= focus and not Entity.IsSameTeam(ctx.hero, creep) and Entity.GetHealth(creep) < NPC.GetTrueDamage(ctx.hero) * 3 then
				score = score + math.max(0, ctx.distance(point, Entity.GetAbsOrigin(creep)) - range) * 0.08
			end
		end
		local exit = ctx.toward(point, cover, 200)
		if not GridNav.IsTraversable(exit) or ctx.unsafePosition(exit) then score = score + 200 end
		if travel < 30 then score = score - 20 end
		if idle and exposureScore <= currentExposure + 2 then
			if travel < 45 then score = score + 45
			elseif travel < 150 and distance <= range + 30 then score = score - 25 end
		end
		candidates[#candidates + 1] = {position = point, score = score, exposure = exposureScore, access = access}
	end
	add(ctx.position)
	if idle then
		for _, side in ipairs({-1, 1}) do add(Vector(ctx.position.x - dy * 90 * side, ctx.position.y + dx * 90 * side, ctx.position.z)) end
	end
	local future = ctx.predict(focus, math.min(0.8, untilHit or 0.8))
	add(ctx.toward(future, cover, math.max(90, range - 30)))
	for _, ally in ipairs(ctx.creeps) do
		if live(ally) and Entity.IsSameTeam(ctx.hero, ally) and NPC.IsRanged(ally) then
			local anchor = ctx.predict(ally, 0.4)
			if ctx.distance(anchor, center) < range + 500 then
				local dx, dy = center.x - anchor.x, center.y - anchor.y
				local length = math.max(1, math.sqrt(dx * dx + dy * dy))
				for _, side in ipairs({-1, 1}) do add(Vector(anchor.x - dy / length * 130 * side, anchor.y + dx / length * 130 * side, anchor.z)) end
			end
		end
	end
	for _, radius in ipairs({120, 240, 400}) do
		for index = 0, 11 do
			local angle = index * math.pi / 6
			add(Vector(ctx.position.x + math.cos(angle) * radius, ctx.position.y + math.sin(angle) * radius, ctx.position.z))
		end
	end
	local radii = entering and {math.max(65, range - 35)} or {math.max(160, range - 60), math.max(240, range + 60)}
	for _, radius in ipairs(radii) do
		for index = 0, 11 do
			local angle = index * math.pi / 6
			add(Vector(center.x + math.cos(angle) * radius, center.y + math.sin(angle) * radius, center.z))
		end
	end
	table.sort(candidates, function(a, b) return a.score < b.score end)
	for index = 1, math.min(5, #candidates) do
		local candidate = candidates[index]
		local length, waypoint = path(ctx, candidate.position)
		local travel = length and length / math.max(100, NPC.GetMoveSpeed(ctx.hero))
		if travel and (not untilHit or travel + candidate.access + leadTime < untilHit)
			and awareness.farmSafe(ctx, candidate.position, travel) then
			candidate.waypoint, candidate.center, candidate.focus = waypoint, center, focus
			candidate.leadTime = leadTime
			return candidate
		end
	end
	return nil
end

function spacing.run(ctx, focus, plan)
	if ctx.now < ctx.busyUntil or NPC.IsChannellingAbility(ctx.hero) or ctx.intent or not live(focus) then return false end
	if not ctx.spacingIdle or ctx.distance(ctx.position, ctx.spacingIdle.position) > 55 then
		ctx.spacingIdle = {position = ctx.position, since = ctx.now}
	end
	local untilHit = plan and plan.start - ctx.now
	if untilHit and untilHit < 0.32 then return false end
	local goal = ctx.laneGoal
	if goal and goal.focus == focus and goal.planned == (plan ~= nil) and ctx.now < goal.expires
		and not ctx.unsafePosition(goal.position) and awareness.farmSafe(ctx, goal.position, 0.3)
		and exposure(ctx, goal.position) <= goal.exposure + 15
		and ctx.distance(goal.center, ctx.predict(focus, 0.25)) < 50
		and (not untilHit or ctx.distance(ctx.position, goal.position) / math.max(100, NPC.GetMoveSpeed(ctx.hero))
			+ goal.access + math.max(goal.leadTime, NPC.GetTimeToFace(ctx.hero, focus) + 0.12) < untilHit) then
		if ctx.distance(ctx.position, goal.position) < 35 then ctx.mode = "Lane spacing: hold covered attack access"; return ctx.stop() end
		return ctx.move(goal.waypoint, "Lane spacing: approach covered attack access", 25)
	end
	goal = spacing.choose(ctx, focus, plan)
	if not goal then ctx.laneGoal = nil; return false end
	goal.expires, goal.planned = ctx.now + 0.4, plan ~= nil
	ctx.laneGoal = goal
	if ctx.distance(ctx.position, goal.position) < 35 then ctx.mode = "Lane spacing: hold covered attack access"; return ctx.stop() end
	return ctx.move(goal.waypoint, plan and "Lane spacing: enter last-hit window" or "Lane spacing: improve cover and creep access", 25)
end

return spacing
