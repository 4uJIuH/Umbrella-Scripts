local march = {}
local common = require("self_play.heroes.common")

function march.geometry(ctx, ability, point)
	local distance = ctx.distance(ctx.position, point)
	if distance < 1 then return nil end
	return {point = point, dx = (point.x - ctx.position.x) / distance, dy = (point.y - ctx.position.y) / distance,
		half = common.value(ability, "distance", 1800) / 2, width = common.value(ability, "radius", 900),
		speed = common.value(ability, "speed", 400), duration = common.value(ability, "duration", 6),
		castPoint = Ability.GetCastPoint(ability), started = ctx.now}
end

function march.arrival(zone, point)
	local x, y = point.x - zone.point.x, point.y - zone.point.y
	local forward, lateral = x * zone.dx + y * zone.dy, math.abs(x * zone.dy - y * zone.dx)
	if math.abs(forward) > zone.half * 0.9 or lateral > zone.width * 0.9 then return nil end
	return zone.castPoint + (forward + zone.half) / math.max(1, zone.speed)
end

function march.plan(ctx, ability, units, center)
	local distance = ctx.distance(ctx.position, center)
	local dx, dy = 1, 0
	if distance > 1 then dx, dy = (center.x - ctx.position.x) / distance, (center.y - ctx.position.y) / distance end
	local reach = math.max(1, Ability.GetCastRange(ability) - 15)
	local previous = ctx.heroState.lastFarmMarch
	local best, bestScore
	for _, radius in ipairs({math.min(reach, math.max(60, distance)), 60}) do
		for index = 0, 7 do
			local cosine, sine = math.cos(index * math.pi / 4), math.sin(index * math.pi / 4)
			local point = Vector(ctx.position.x + (dx * cosine - dy * sine) * radius, ctx.position.y + (dx * sine + dy * cosine) * radius, ctx.position.z)
			local zone = march.geometry(ctx, ability, point)
			local hits, value, delay = 0, 0, 0
			for _, unit in ipairs(units) do
				local arrival = march.arrival(zone, Entity.GetAbsOrigin(unit))
				if arrival then hits, value, delay = hits + 1, value + math.min(600, Entity.GetHealth(unit)), delay + arrival end
			end
			local score = hits * 1000 + value * 0.1 - delay * 20
			if previous and ctx.now - previous.started < 12 and zone.dx * previous.dx + zone.dy * previous.dy < 0.8 then score = score + 70 end
			if hits > 0 and (not bestScore or score > bestScore) then best, bestScore = {point = point, zone = zone, hits = hits}, score end
		end
	end
	return best
end

function march.rate(ability)
	return common.value(ability, "damage", 0) * common.value(ability, "machines_per_sec", 24)
		* common.value(ability, "collision_radius", 50) * 2 / math.max(1, common.value(ability, "radius", 900) * 2)
end

function march.pending(ctx, ability, unit)
	if not ability then return 0 end
	local damage = 0
	for _, zone in ipairs(ctx.heroState.farmZones or {}) do
		if zone.name == "march" and zone.dx then
			local arrival = march.arrival(zone, Entity.GetAbsOrigin(unit))
			if arrival then
				local remaining = math.min(zone.duration, math.max(0, zone.started + arrival + zone.duration - ctx.now))
				damage = damage + remaining * march.rate(ability) * NPC.GetMagicalArmorDamageMultiplier(unit)
			end
		end
	end
	return damage
end

function march.record(ctx, plan)
	local zone = plan.zone
	zone.name, zone.expires = "march", zone.started + zone.castPoint + zone.duration + zone.half * 2 / math.max(1, zone.speed)
	local zones = ctx.heroState.farmZones or {}
	zones[#zones + 1] = zone
	ctx.heroState.farmZones, ctx.heroState.lastFarmMarch = zones, zone
end

return march
