local phoenix = {reserved = {phoenix_icarus_dive = true, phoenix_icarus_dive_stop = true,
	phoenix_fire_spirits = true, phoenix_launch_fire_spirit = true, phoenix_sun_ray = true,
	phoenix_sun_ray_stop = true, phoenix_sun_ray_toggle_move = true, phoenix_supernova = true}}
local common = require("self_play.heroes.common")
local tactics = require("self_play.heroes.tactics")

function phoenix.duringCast(ctx, api)
	local dive = ctx.heroState.dive
	if dive then
		if ctx.now > dive.expires then ctx.heroState.dive = nil
		elseif ctx.distance(ctx.position, dive.goal) < 200 then
			local used, cast = tactics.cast(ctx, api, "phoenix_icarus_dive_stop", "none")
			if cast then ctx.heroState.dive = nil end
			return used
		else return true end
	end
	local ray = ctx.heroState.ray
	if not ray then return false end
	local stop = common.ability(ctx, api, "phoenix_sun_ray_stop")
	if ctx.now > ray.expires or ctx.now > ray.started + 0.7 and not stop then ctx.heroState.ray = nil; return false end
	local target = common.visible(ray.target) and ray.target or tactics.enemy(ctx, 1200)
	if not target or ctx.health < 0.28 or ctx.hardRetreat or ctx.distance(ctx.position, Entity.GetAbsOrigin(target)) > 1250
		or Entity.IsSameTeam(ctx.hero, target) and Entity.GetHealth(target) > Entity.GetMaxHealth(target) * 0.92 then
		local used, cast = tactics.cast(ctx, api, "phoenix_sun_ray_stop", "none")
		if cast then ctx.heroState.ray = nil end
		return used
	end
	return tactics.steer(ctx, ctx.predict(target, 0.15), "Phoenix: track Sun Ray")
end

function phoenix.update(ctx, api, retreat)
	if phoenix.duringCast(ctx, api) then return true end
	local enemy = tactics.enemy(ctx, 1400)
	local egg = NPC.GetAbility(ctx.hero, "phoenix_supernova")
	if egg and enemy and (ctx.health < 0.4 or tactics.count(ctx, ctx.position, 800) >= 2) then
		local hits = 0
		for _, unit in ipairs(ctx.enemies) do
			if common.visible(unit) and ctx.distance(ctx.position, Entity.GetAbsOrigin(unit)) < NPC.GetAttackRange(unit) + 500 then
				hits = hits + 6 / math.max(0.3, NPC.GetSecondsPerAttack(unit, false)) * (NPC.IsStunned(unit) and 0.35 or 1)
			end
		end
		if hits < common.value(egg, "max_hero_attacks", 6) or ctx.health < 0.2 then
			if tactics.cast(ctx, api, "phoenix_supernova", "none") then return true end
		end
	end
	if retreat and ctx.health > 0.18 then
		local dive = NPC.GetAbility(ctx.hero, "phoenix_icarus_dive")
		if dive then
			local goal = ctx.toward(ctx.position, ctx.home, common.value(dive, "dash_length", 1100) * 0.85)
			if not ctx.unsafePosition(goal) and GridNav.IsTraversable(goal) then
				local used, cast = tactics.cast(ctx, api, "phoenix_icarus_dive", "point", nil, goal, common.value(dive, "dash_length", 1100))
				if cast then ctx.heroState.dive = {goal = goal, expires = ctx.now + common.value(dive, "dive_duration", 2) + 0.3} end
				if used then return true end
			end
		end
	end
	if not enemy then
		local ally = tactics.injured(ctx, 1200, 0.55, true)
		if ally and ctx.health > 0.7 and not retreat and tactics.safe(ctx, ctx.position, 2) then
			local used, cast = tactics.cast(ctx, api, "phoenix_sun_ray", "point", nil, Entity.GetAbsOrigin(ally))
			if cast then ctx.heroState.ray = {target = ally, started = ctx.now, expires = ctx.now + 6.5} end
			return used
		end
		return false
	end
	if not tactics.committed(ctx, enemy) then return false end
	local launch = NPC.GetAbility(ctx.hero, "phoenix_launch_fire_spirit")
	if launch and ctx.now >= (ctx.heroState.nextSpirit or 0) then
		local point = tactics.point(ctx, launch, enemy, common.value(launch, "spirit_speed", 1000))
		local used, cast = tactics.cast(ctx, api, "phoenix_launch_fire_spirit", "point", nil, point)
		if cast then ctx.heroState.nextSpirit = ctx.now + 2.7 end
		if used then return true end
	end
	if ctx.health > 0.55 and not retreat and tactics.cast(ctx, api, "phoenix_fire_spirits", "none") then return true end
	local ray = NPC.GetAbility(ctx.hero, "phoenix_sun_ray")
	if ray and ctx.health > 0.6 and not retreat and tactics.safe(ctx, ctx.position, 2) then
		local used, cast = tactics.cast(ctx, api, "phoenix_sun_ray", "point", nil, ctx.predict(enemy, 0.2))
		if cast then ctx.heroState.ray = {target = enemy, started = ctx.now, expires = ctx.now + 6.5} end
		return used
	end
	return false
end

return phoenix
