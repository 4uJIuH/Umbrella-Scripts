local aim = {}
local common = require("self_play.heroes.common")

function aim.segment(origin, finish, point)
	local dx, dy = finish.x - origin.x, finish.y - origin.y
	local fraction = ((point.x - origin.x) * dx + (point.y - origin.y) * dy) / math.max(1, dx * dx + dy * dy)
	local closest = Vector(origin.x + dx * fraction, origin.y + dy * fraction, origin.z)
	return fraction, math.sqrt((point.x - closest.x) ^ 2 + (point.y - closest.y) ^ 2)
end

function aim.remnant(ctx, ability, enemy)
	local range = Ability.GetCastRange(ability)
	local speed = common.value(ability, "projectile_speed", 900)
	local activate = common.value(ability, "activation_delay", 0.4) + NetChannel.GetAvgLatency(Enum.Flow.FLOW_OUTGOING)
	local watch = common.value(ability, "remnant_watch_distance", 450)
	local radius = common.value(ability, "remnant_watch_radius", 130)
	local blockers = {}
	for _, unit in ipairs(ctx.worldNPCs) do
		if unit ~= enemy and common.visible(unit) and not Entity.IsSameTeam(ctx.hero, unit)
			and (NPC.IsHero(unit) or NPC.IsCreep(unit) and not NPC.HasShard(ctx.hero))
			and ctx.distance(ctx.position, Entity.GetAbsOrigin(unit)) < range + watch + 200 then blockers[#blockers + 1] = unit end
	end
	local best, bestScore
	for _, offset in ipairs({160, 300}) do
		for step = 0, 7 do
			local angle = step * math.pi / 4
			local predicted, origin, delay = Entity.GetAbsOrigin(enemy), nil, activate
			for _ = 1, 4 do
				local x, y = predicted.x + math.cos(angle) * offset, predicted.y + math.sin(angle) * offset
				origin = Vector(x, y, World.GetGroundZ(x, y))
				delay = activate + ctx.distance(ctx.position, origin) / math.max(1, speed)
				predicted = ctx.predict(enemy, delay)
			end
			if ctx.distance(ctx.position, origin) <= range - 15 and GridNav.IsTraversable(origin) then
				local length = ctx.distance(origin, predicted)
				if length > 30 and length < watch - 30 then
					local endPoint = Vector(origin.x + (predicted.x - origin.x) / length * watch,
						origin.y + (predicted.y - origin.y) / length * watch, origin.z)
					local blocked = false
					for _, unit in ipairs(blockers) do
						local fraction, miss = aim.segment(origin, endPoint, ctx.predict(unit, delay))
						if fraction >= 0 and fraction <= (length + NPC.GetHullRadius(unit)) / watch and miss < radius + NPC.GetHullRadius(unit) then blocked = true; break end
					end
					local fraction, miss = aim.segment(origin, endPoint, ctx.predict(enemy, delay + 0.18))
					if not blocked and fraction > 0 and fraction < 1 and miss < radius - 25 then
						local score = delay * 120 + miss * 2 + ctx.distance(origin, ctx.position) * 0.04
						if not bestScore or score < bestScore then best, bestScore = {origin = origin, direction = endPoint, delay = delay}, score end
					end
				end
			end
		end
	end
	return best
end

function aim.roll(ctx, ability, enemy, boosted)
	local speed = common.value(ability, boosted and "rock_speed" or "speed", boosted and 1600 or 1000)
	local reach = Ability.GetLevelSpecialValueFor(ability, "distance")
	if boosted then reach = reach * common.value(ability, "rock_distance_multiplier", 2) end
	local delay = common.value(ability, "delay", 0.6) + NetChannel.GetAvgLatency(Enum.Flow.FLOW_OUTGOING) + (boosted and 0.04 or 0)
	local time, predicted = delay, Entity.GetAbsOrigin(enemy)
	for _ = 1, 5 do
		time = delay + ctx.distance(ctx.position, predicted) / math.max(1, speed)
		predicted = ctx.predict(enemy, time)
	end
	local distance = ctx.distance(ctx.position, predicted)
	if distance < 40 or distance > reach + NPC.GetHullRadius(enemy) - 30 then return nil end
	local finish = Vector(ctx.position.x + (predicted.x - ctx.position.x) / distance * reach,
		ctx.position.y + (predicted.y - ctx.position.y) / distance * reach, predicted.z)
	if not GridNav.IsTraversable(finish) or ctx.unsafePosition(finish) or ctx.unsafePosition(predicted) then return nil end
	for step = 120, reach, 120 do if ctx.unsafePosition(ctx.toward(ctx.position, finish, step)) then return nil end end
	local radius = common.value(ability, "radius", 160)
	local stone
	for _, unit in ipairs(ctx.worldNPCs) do
		if unit ~= ctx.hero and unit ~= enemy and common.visible(unit) then
			local position = Entity.GetAbsOrigin(unit)
			local fraction = aim.segment(ctx.position, finish, position)
			local predictedUnit = ctx.predict(unit, delay + math.max(0, fraction) * reach / speed)
			local along, miss = aim.segment(ctx.position, finish, predictedUnit)
			if along > 0 and along * reach < distance - NPC.GetHullRadius(enemy) and miss < radius + NPC.GetHullRadius(unit) then
				if NPC.GetUnitName(unit) == "npc_dota_earth_spirit_stone" then stone = unit
				elseif NPC.IsHero(unit) then return nil end
			end
		end
	end
	return {position = finish, hit = predicted, time = time, ends = delay + reach / speed, stone = stone, boosted = boosted}
end

return aim
