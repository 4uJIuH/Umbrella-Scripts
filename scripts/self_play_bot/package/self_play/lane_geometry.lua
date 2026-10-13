local geometry = {}
local navigation = require("self_play.navigation")
local names = {"top", "mid", "bot"}

function geometry.route(ctx, lane)
	ctx.laneRoutes = ctx.laneRoutes or {}
	local cached = ctx.laneRoutes[lane]
	if cached and Entity.IsEntity(cached.front) and Entity.IsAlive(cached.front)
		and Entity.IsEntity(cached.rear) and Entity.IsAlive(cached.rear) then return cached end
	local front, rear
	for _, unit in ipairs(ctx.structures) do
		if Entity.IsEntity(unit) and Entity.IsAlive(unit) and Entity.IsSameTeam(ctx.hero, unit) then
			local name = NPC.GetUnitName(unit)
			if name:find("tower1_" .. names[lane], 1, true) then front = unit end
			if name:find("tower2_" .. names[lane], 1, true) then rear = unit end
		end
	end
	if not front or not rear then return nil end
	local origin = navigation.walkable(ctx, Entity.GetAbsOrigin(rear))
	local destination = navigation.walkable(ctx, Entity.GetAbsOrigin(front))
	if not origin or not destination then return nil end
	local route = {front = front, rear = rear, points = {origin}, length = 0}
	local path = GridNav.BuildPath(origin, destination)
	if #path == 0 then return nil end
	for _, point in ipairs(path) do
		local distance = ctx.distance(route.points[#route.points], point)
		if distance > 5 then route.points[#route.points + 1], route.length = point, route.length + distance end
	end
	local distance = ctx.distance(route.points[#route.points], destination)
	if distance > 5 then route.points[#route.points + 1], route.length = destination, route.length + distance end
	if route.length < 100 then return nil end
	ctx.laneRoutes[lane] = route
	return route
end

function geometry.point(ctx, route, progress)
	local remaining = math.max(0, progress)
	for index = 2, #route.points do
		local a, b = route.points[index - 1], route.points[index]
		local length = ctx.distance(a, b)
		if remaining <= length then return ctx.toward(a, b, remaining) end
		remaining = remaining - length
	end
	return route.points[#route.points]
end

function geometry.project(ctx, route, position)
	local best, distance, progress, offset = nil, math.huge, 0, 0
	for index = 2, #route.points do
		local a, b = route.points[index - 1], route.points[index]
		local dx, dy = b.x - a.x, b.y - a.y
		local length = math.sqrt(dx * dx + dy * dy)
		local fraction = math.max(0, math.min(1, ((position.x - a.x) * dx + (position.y - a.y) * dy) / math.max(1, length * length)))
		local point = ctx.toward(a, b, fraction * length)
		local current = ctx.distance(position, point)
		if current < distance then best, distance, progress = point, current, offset + fraction * length end
		offset = offset + length
	end
	return best, progress, distance
end

function geometry.back(ctx, position)
	local route = geometry.route(ctx, ctx.lane)
	if route then
		local _, progress = geometry.project(ctx, route, position)
		return geometry.point(ctx, route, math.max(0, progress - 600))
	end
	return ctx.home
end

return geometry
