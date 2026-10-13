local dazzle = {reserved = {dazzle_nothl_projection = true, dazzle_nothl_projection_end = true,
	dazzle_shallow_grave = true, dazzle_shadow_wave = true}}
local common = require("self_play.heroes.common")
local tactics = require("self_play.heroes.tactics")

local function support(ctx, api, defensiveOnly)
	local grave = NPC.GetAbility(ctx.hero, "dazzle_shallow_grave")
	local ally = grave and tactics.injured(ctx, Ability.GetCastRange(grave), 0.32, true)
	if ally and not NPC.HasModifier(ally, "modifier_dazzle_shallow_grave")
		and tactics.cast(ctx, api, "dazzle_shallow_grave", "target", ally) then return true end
	local wave = NPC.GetAbility(ctx.hero, "dazzle_shadow_wave")
	ally = wave and tactics.injured(ctx, Ability.GetCastRange(wave), 0.8)
	if ally and tactics.cast(ctx, api, "dazzle_shadow_wave", "target", ally) then return true end
	if defensiveOnly then return false end
	local enemy = tactics.enemy(ctx, 800)
	return enemy and tactics.committed(ctx, enemy) and tactics.cast(ctx, api, "dazzle_poison_touch", "target", enemy) or false
end

function dazzle.emergency(ctx, api)
	return support(ctx, api, true)
end

function dazzle.duringCast(ctx, api)
	local task = ctx.heroState.projection
	if not task then return false end
	if ctx.now > task.expires then ctx.heroState.projection = nil; return false end
	local ending = NPC.GetAbility(ctx.hero, "dazzle_nothl_projection_end")
	local active = ending and not Ability.IsHidden(ending) and Ability.IsActivated(ending)
	if active and (ctx.hardRetreat or not tactics.safe(ctx, ctx.position, 2)
		or ctx.now > task.started + 5 and not tactics.enemy(ctx, 2200)) then
		local used, done = tactics.cast(ctx, api, "dazzle_nothl_projection_end", "none")
		if done then ctx.heroState.projection = nil end
		return used
	end
	if ctx.now > task.started + 0.7 and not active then ctx.heroState.projection = nil end
	return ctx.now < task.started + 0.5 or active == true
end

function dazzle.update(ctx, api, retreat)
	if dazzle.duringCast(ctx, api) then return true end
	if support(ctx, api) then return true end
	local enemy = tactics.enemy(ctx, 1500)
	if retreat or not enemy or not tactics.committed(ctx, enemy) or not tactics.safe(ctx, ctx.position, 3) then return false end
	local projection = NPC.GetAbility(ctx.hero, "dazzle_nothl_projection")
	if not projection then return false end
	local point = ctx.toward(ctx.position, Entity.GetAbsOrigin(enemy), Ability.GetCastRange(projection) - 20)
	local used, cast = tactics.cast(ctx, api, "dazzle_nothl_projection", "point", nil, point)
	if cast then ctx.heroState.projection = {started = ctx.now, expires = ctx.now + common.value(projection, "max_duration", 12) + 1} end
	return used
end

function dazzle.unit(ctx, api, unit)
	if not NPC.HasModifier(unit, "modifier_dazzle_nothl_projection_soul_clone") then return false end
	local actor = common.actor(ctx, unit)
	actor.temporaryUnit = true
	actor.intent = actor.target and {kind = "hero", target = actor.target} or false
	if api.busy(actor) then return true end
	if support(actor, api) or common.items(actor, api, actor.target, false) then return true end
	if common.visible(actor.target) then return common.unitAttack(ctx, unit, actor.target) end
	return true
end

return dazzle
