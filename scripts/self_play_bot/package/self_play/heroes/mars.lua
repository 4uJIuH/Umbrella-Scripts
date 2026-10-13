local mars = {reserved = {mars_spear = true, mars_arena_of_blood = true, mars_gods_rebuke = true, mars_bulwark = true}}
local common = require("self_play.heroes.common")
local tactics = require("self_play.heroes.tactics")
local aim = require("self_play.heroes.aim")

function mars.locked(ctx)
	return ctx.heroState.initiation and ctx.now < ctx.heroState.initiation.expires or false
end

function mars.update(ctx, api, retreat)
	local enemy = tactics.enemy(ctx, 1400)
	if not enemy or not retreat and not tactics.committed(ctx, enemy) then return false end
	local point = ctx.predict(enemy, 0.3)
	local arena = NPC.GetAbility(ctx.hero, "mars_arena_of_blood")
	if arena and not retreat and not NPC.HasModifier(enemy, "modifier_mars_arena_of_blood_leash") then
		if ctx.distance(ctx.position, point) > Ability.GetCastRange(arena) and tactics.safe(ctx, point, 2) then
			ctx.target = enemy
			if tactics.blink(ctx, api, point, "mars_arena_of_blood", Ability.GetCastRange(arena)) then return true end
		end
		local center = ctx.toward(ctx.position, point, math.max(0, Ability.GetCastRange(arena) - 20))
		if ctx.distance(center, point) < common.value(arena, "radius", 550) - 150 then
			local used, cast = tactics.cast(ctx, api, "mars_arena_of_blood", "point", nil, center)
			if cast then ctx.heroState.arena = {position = center, expires = ctx.now + common.value(arena, "duration", 5.5)} end
			if used then return true end
		end
	end
	local spear = NPC.GetAbility(ctx.hero, "mars_spear")
	if spear then
		point = tactics.point(ctx, spear, enemy, common.value(spear, "spear_speed", 1400))
		local range = common.value(spear, "spear_range", 900)
		local arenaActive = ctx.heroState.arena and ctx.now < ctx.heroState.arena.expires and ctx.distance(point, ctx.heroState.arena.position) < 550
		local pin = arenaActive or NPC.IsChannellingAbility(enemy) or retreat
		local length = ctx.distance(ctx.position, point)
		if length > 0 and length < range then
			local finish = Vector(ctx.position.x + (point.x - ctx.position.x) / length * range, ctx.position.y + (point.y - ctx.position.y) / length * range, point.z)
			for _, tree in ipairs(Trees.InRadius(point, range - length, true)) do
				local along, miss = aim.segment(ctx.position, finish, Entity.GetAbsOrigin(tree))
				if Tree.IsActive(tree) and along * range > length and along < 1 and miss < 100 then pin = true; break end
			end
			if pin and tactics.cast(ctx, api, "mars_spear", "point", nil, point, range) then return true end
		end
	end
	local rebuke = NPC.GetAbility(ctx.hero, "mars_gods_rebuke")
	if rebuke and ctx.distance(ctx.position, point) < common.value(rebuke, "radius", 500) - 40 then
		return tactics.cast(ctx, api, "mars_gods_rebuke", "point", nil, point, common.value(rebuke, "radius", 500))
	end
	return false
end

return mars
