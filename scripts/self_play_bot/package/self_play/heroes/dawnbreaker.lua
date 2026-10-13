local dawn = {reserved = {dawnbreaker_solar_guardian = true, dawnbreaker_land = true,
	dawnbreaker_celestial_hammer = true, dawnbreaker_converge = true}}
local common = require("self_play.heroes.common")
local tactics = require("self_play.heroes.tactics")

function dawn.duringCast(ctx, api)
	local task = ctx.heroState.guardian
	if not task then return false end
	if ctx.now > task.expires then ctx.heroState.guardian = nil; return false end
	local land = common.ability(ctx, api, "dawnbreaker_land")
	if not land and not NPC.IsChannellingAbility(ctx.hero) and ctx.now > task.started + 1
		and ctx.distance(ctx.position, task.position) < 650 then
		ctx.heroState.guardian = nil
		return false
	end
	if land and (ctx.now > task.started + 2.2 or tactics.count(ctx, task.position, 500) >= 2) then
		local used, cast = tactics.cast(ctx, api, "dawnbreaker_land", "none")
		if cast then ctx.heroState.guardian = nil end
		return used
	end
	return true
end

function dawn.update(ctx, api, retreat)
	if dawn.duringCast(ctx, api) then return true end
	local ult = common.ability(ctx, api, "dawnbreaker_solar_guardian")
	if ult and not retreat and ctx.health > 0.5 then
		local best, score
		for _, ally in ipairs(ctx.allies) do
			if ally ~= ctx.hero and common.visible(ally) and not NPC.IsIllusion(ally) and Hero.GetRecentDamage(ally) > 0 then
				local position = Entity.GetAbsOrigin(ally)
				local enemies, allies = tactics.count(ctx, position, 850), tactics.count(ctx, position, 1000, true)
				if enemies > 0 and enemies <= allies + 1 and ctx.distance(ctx.position, position) > 800 and tactics.safe(ctx, position, 2) then
					local value = enemies * 100 + (1 - Entity.GetHealth(ally) / Entity.GetMaxHealth(ally)) * 150
					if not score or value > score then best, score = ally, value end
				end
			end
		end
		if best then
			local point = Entity.GetAbsOrigin(best)
			local used, cast = tactics.cast(ctx, api, "dawnbreaker_solar_guardian", "point", nil, point, math.huge)
			if cast then ctx.heroState.guardian = {position = point, started = ctx.now, expires = ctx.now + 4.5} end
			if used then return true end
		end
	end
	local task = ctx.heroState.hammer
	if task then
		if ctx.now > task.expires then ctx.heroState.hammer = nil
		elseif tactics.safe(ctx, ctx.toward(ctx.position, task.position, ctx.distance(ctx.position, task.position) * 0.5), 1.5)
			and (retreat or common.visible(task.target) and ctx.distance(ctx.position, Entity.GetAbsOrigin(task.target)) > 400) then
			local used, cast = tactics.cast(ctx, api, "dawnbreaker_converge", "none")
			if cast then ctx.heroState.hammer = nil end
			if used then return true end
		end
	end
	local hammer, enemy = NPC.GetAbility(ctx.hero, "dawnbreaker_celestial_hammer"), tactics.enemy(ctx, 1300)
	if not hammer or not enemy or not retreat and not tactics.committed(ctx, enemy) then return false end
	local range = common.value(hammer, "range", 700)
	local point = retreat and ctx.toward(ctx.position, ctx.home, range) or tactics.point(ctx, hammer, enemy, common.value(hammer, "projectile_speed", 1600))
	local used, cast = tactics.cast(ctx, api, "dawnbreaker_celestial_hammer", "point", nil, point, range)
	if cast then ctx.heroState.hammer = {position = point, target = enemy, expires = ctx.now + 3} end
	return used
end

function dawn.opportunity(ctx, api)
	return dawn.update(ctx, api, false)
end

return dawn
