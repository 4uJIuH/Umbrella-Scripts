local geometry = {}

function geometry.frontHit(origin, forward, target, offset, radius)
	local dx = target.x - origin.x - forward.x * offset
	local dy = target.y - origin.y - forward.y * offset
	return dx * dx + dy * dy <= math.max(0, radius - 35) ^ 2
end

function geometry.lineHit(origin, aim, target, length, width)
	local dx, dy = aim.x - origin.x, aim.y - origin.y
	local magnitude = math.sqrt(dx * dx + dy * dy)
	if magnitude < 1 then return false end
	dx, dy = dx / magnitude, dy / magnitude
	local x, y = target.x - origin.x, target.y - origin.y
	local projection = x * dx + y * dy
	return projection >= 0 and projection <= length and math.abs(x * dy - y * dx) <= math.max(1, width - 25)
end

return geometry
