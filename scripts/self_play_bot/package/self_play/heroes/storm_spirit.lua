local storm = {reserved = {storm_spirit_ball_lightning = true, storm_spirit_electric_vortex = true,
	storm_spirit_static_remnant = true, storm_spirit_electric_rave = true}}
local common = require("self_play.heroes.common")
local intent = require("self_play.intent")

function storm.zipCost(ability, maximum, distance)
	return common.value(ability, "ball_lightning_initial_mana_base", 25) + maximum * common.value(ability, "ball_lightning_initial_mana_percentage", 7.5) / 100
		+ distance / 100 * (common.value(ability, "ball_lightning_travel_cost_base", 10) + maximum * common.value(ability, "ball_lightning_travel_cost_percent", 0.65) / 100)
end

function storm.update(ctx, api, retreat)
	if NPC.HasModifier(ctx.hero, "modifier_storm_spirit_ball_lightning") then return true end
	local enemy = common.enemy(ctx, 1400)
	if common.items(ctx, api, enemy, retreat) then return true end
	local zip = common.ability(ctx, api, "storm_spirit_ball_lightning")
	local maximum, mana = NPC.GetMaxMana(ctx.hero), NPC.GetMana(ctx.hero)
	if zip and retreat and ctx.now >= (ctx.heroState.nextZip or 0) then
		for _, distance in ipairs({900, 600, 350}) do
			local point = ctx.toward(ctx.position, ctx.home, distance)
			if mana > storm.zipCost(zip, maximum, distance) + 100 and GridNav.IsTraversable(point) and not ctx.unsafePosition(point) then
				ctx.heroState.nextZip = ctx.now + 2
				return api.cast(ctx, zip, "point", nil, point)
			end
		end
	end
	if retreat or not enemy then return false end
	local distance = ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy))
	local vortex = common.ability(ctx, api, "storm_spirit_electric_vortex")
	if vortex and not NPC.IsStunned(enemy) then
		if ctx.planner.hasFlag(Ability.GetBehavior(vortex), Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_NO_TARGET) then
			if distance < 430 then return api.cast(ctx, vortex, "none") end
		elseif common.cast(ctx, api, vortex, "target", enemy) then return true end
	end
	if NPC.HasModifier(ctx.hero, "modifier_storm_spirit_overload") and distance < NPC.GetAttackRange(ctx.hero) + 100 then
		intent.begin(ctx, enemy, "hero", true)
		return ctx.attack(enemy, "Storm: discharge Overload")
	end
	local remnant = common.ability(ctx, api, "storm_spirit_static_remnant")
	if remnant then
		if ctx.planner.hasFlag(Ability.GetBehavior(remnant), Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_POINT) then
			local point = ctx.predict(enemy, 0.75 + distance / 300)
			if ctx.distance(ctx.position, point) <= Ability.GetCastRange(remnant) and (NPC.IsStunned(enemy) or distance < 350) then return api.cast(ctx, remnant, "point", nil, point) end
		elseif distance < 225 then return api.cast(ctx, remnant, "none") end
	end
	if zip and distance > 400 and distance < 1000 and ctx.health > 0.65 and ctx.nearEnemies <= ctx.nearAllies
		and ctx.now >= (ctx.heroState.nextZip or 0) then
		local point = ctx.toward(ctx.predict(enemy, 0.4), ctx.position, 170)
		local cost = storm.zipCost(zip, maximum, ctx.distance(ctx.position, point))
		if mana > cost + storm.zipCost(zip, maximum, 700) + 150 and not ctx.unsafePosition(point) then
			ctx.heroState.nextZip = ctx.now + 2
			api.cast(ctx, zip, "point", nil, point)
			intent.begin(ctx, enemy, "hero", true)
			return true
		end
	end
	return false
end

return storm
