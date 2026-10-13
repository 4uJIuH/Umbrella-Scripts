local snapfire = {reserved = {snapfire_mortimer_kisses = true, snapfire_firesnap_cookie = true,
	snapfire_gobble_up = true, snapfire_spit_creep = true}}
local common = require("self_play.heroes.common")
local tactics = require("self_play.heroes.tactics")

function snapfire.duringCast(ctx, api)
	local task = ctx.heroState.kisses
	if not task then return false end
	if ctx.now > task.expires then ctx.heroState.kisses = nil; return false end
	local ability = NPC.GetAbility(ctx.hero, "snapfire_mortimer_kisses")
	if ctx.now > task.started + 0.8 and not NPC.HasModifier(ctx.hero, "modifier_snapfire_mortimer_kisses") then ctx.heroState.kisses = nil; return false end
	if ctx.hardRetreat then ctx.heroState.kisses = nil; return ctx.stop() end
	local enemy = common.visible(task.target) and task.target or tactics.enemy(ctx, Ability.GetCastRange(ability))
	if not enemy then return true end
	local distance = ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy))
	if distance < common.value(ability, "min_range", 600) then ctx.heroState.kisses = nil; return ctx.stop() end
	local delay = math.max(common.value(ability, "min_lob_travel_time", 0.8), math.min(common.value(ability, "max_lob_travel_time", 2), distance / common.value(ability, "projectile_speed", 1300)))
	local point = ctx.predict(enemy, delay)
	if ctx.distance(ctx.position, point) > Ability.GetCastRange(ability) then return true end
	task.target = enemy
	return tactics.steer(ctx, point, "Snapfire: direct Mortimer Kisses")
end

function snapfire.update(ctx, api, retreat)
	if snapfire.duringCast(ctx, api) then return true end
	local enemy = tactics.enemy(ctx, 3000)
	if not enemy then return false end
	local cookie = NPC.GetAbility(ctx.hero, "snapfire_firesnap_cookie")
	if cookie and ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy)) < 950 then
		for _, ally in ipairs(ctx.allies) do
			if common.visible(ally) and not NPC.IsChannellingAbility(ally) then
				local origin, forward = Entity.GetAbsOrigin(ally), Entity.GetRotation(ally):GetForward()
				local length = common.value(cookie, "jump_horizontal_distance", 425)
				local landing = Vector(origin.x + forward.x * length, origin.y + forward.y * length, origin.z)
				if tactics.safe(ctx, landing, 1.5) and (not retreat and ctx.distance(landing, ctx.predict(enemy, 0.6)) < 240
					or retreat and ally == ctx.hero and ctx.distance(landing, ctx.home) + 250 < ctx.distance(origin, ctx.home)) then
					if tactics.cast(ctx, api, "snapfire_firesnap_cookie", "target", ally) then return true end
				end
			end
		end
	end
	if retreat or not tactics.committed(ctx, enemy) or not tactics.safe(ctx, ctx.position, 2) then return false end
	local kisses = NPC.GetAbility(ctx.hero, "snapfire_mortimer_kisses")
	if not kisses or ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy)) < common.value(kisses, "min_range", 600) + 100 then return false end
	local point = tactics.point(ctx, kisses, enemy, common.value(kisses, "projectile_speed", 1300), 0.3)
	local used, cast = tactics.cast(ctx, api, "snapfire_mortimer_kisses", "point", nil, point)
	if cast then ctx.heroState.kisses = {target = enemy, started = ctx.now, expires = ctx.now + common.value(kisses, "duration_tooltip", 5.5) + 0.5} end
	return used
end

return snapfire
