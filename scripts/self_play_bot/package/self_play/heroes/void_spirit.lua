local void = {reserved = {void_spirit_aether_remnant = true, void_spirit_dissimilate = true,
	void_spirit_resonant_pulse = true, void_spirit_astral_step = true}}
local common = require("self_play.heroes.common")
local intent = require("self_play.intent")
local aim = require("self_play.heroes.aim")

function void.duringCast(ctx)
	if not NPC.HasModifier(ctx.hero, "modifier_void_spirit_dissimilate_phase") then return false end
	if not ctx.heroState.exitSelected then
		local destination = ctx.retreating and ctx.home or common.enemy(ctx, 800) and Entity.GetAbsOrigin(ctx.target) or ctx.home
		local point = ctx.toward(ctx.position, destination, 500)
		if ctx.unsafePosition(point) then point = ctx.toward(ctx.position, ctx.home, 500) end
		NPC.MoveTo(ctx.hero, point, false, false, false, true)
		ctx.heroState.exitSelected = true
	end
	return true
end

function void.update(ctx, api, retreat)
	ctx.heroState.exitSelected = nil
	local enemy = common.enemy(ctx, 1300)
	if common.items(ctx, api, enemy, retreat) then return true end
	local step = common.ability(ctx, api, "void_spirit_astral_step")
	if retreat and step then
		local point = ctx.toward(ctx.position, ctx.home, common.value(step, "max_travel_distance", 800))
		if GridNav.IsTraversable(point) and not ctx.unsafePosition(point) then return api.cast(ctx, step, "point", nil, point) end
	end
	local dissimilate = common.ability(ctx, api, "void_spirit_dissimilate")
	if dissimilate and enemy and (retreat or ctx.health < 0.55) and ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy)) < 500 then return api.cast(ctx, dissimilate, "none") end
	if not enemy then return false end
	local pulse = common.ability(ctx, api, "void_spirit_resonant_pulse")
	if pulse and ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy)) < 450 then return api.cast(ctx, pulse, "none") end
	if retreat then return false end
	local remnant = common.ability(ctx, api, "void_spirit_aether_remnant")
	if remnant and not NPC.IsStunned(enemy) and ctx.now >= (ctx.heroState.nextRemnantAim or 0) then
		ctx.heroState.nextRemnantAim = ctx.now + 0.15
		local solution = aim.remnant(ctx, remnant, enemy)
		if solution then return common.vector(ctx, api, remnant, solution.origin, solution.direction) end
	end
	if step and Ability.GetCurrentCharges(step) >= 2 and ctx.health > 0.6 and ctx.nearEnemies <= ctx.nearAllies
		and ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy)) > 350 then
		local point = ctx.predict(enemy, 0.2)
		if ctx.distance(ctx.position, point) < common.value(step, "max_travel_distance", 800) and not ctx.unsafePosition(point) then
			api.cast(ctx, step, "point", nil, point)
			intent.begin(ctx, enemy, "hero", true)
			return true
		end
	end
	return false
end

return void
