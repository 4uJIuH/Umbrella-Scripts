local ember = {reserved = {ember_spirit_searing_chains = true, ember_spirit_sleight_of_fist = true,
	ember_spirit_flame_guard = true, ember_spirit_fire_remnant = true, ember_spirit_activate_fire_remnant = true}}
local common = require("self_play.heroes.common")

function ember.duringCast(ctx, api)
	if not NPC.HasModifier(ctx.hero, "modifier_ember_spirit_sleight_of_fist_caster") then return false end
	local chains = common.ability(ctx, api, "ember_spirit_searing_chains")
	local enemy = common.enemy(ctx, 375)
	if chains and enemy and not NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_ROOTED) then return api.cast(ctx, chains, "none") end
	return false
end

function ember.locked(ctx)
	return ctx.heroState.remnant ~= nil
end

function ember.update(ctx, api, retreat)
	local state, enemy = ctx.heroState, common.enemy(ctx, 1100)
	local activate = common.ability(ctx, api, "ember_spirit_activate_fire_remnant")
	if state.remnant then
		if ctx.now > state.remnant.expires then state.remnant = nil; return false end
		for _, unit in ipairs(ctx.worldNPCs) do
			if common.visible(unit) and NPC.GetUnitName(unit) == "npc_dota_ember_spirit_remnant" and Entity.GetOwner(unit) == ctx.hero
				and ctx.distance(Entity.GetAbsOrigin(unit), state.remnant.position) < 200 and activate then
				local point = state.remnant.position
				state.remnant = nil
				return api.cast(ctx, activate, "point", nil, point)
			end
		end
		return true
	end
	if common.items(ctx, api, enemy, retreat) then return true end
	local remnant = common.ability(ctx, api, "ember_spirit_fire_remnant")
	if retreat then
		if activate then
			for _, unit in ipairs(ctx.worldNPCs) do
				if common.visible(unit) and NPC.GetUnitName(unit) == "npc_dota_ember_spirit_remnant" and Entity.GetOwner(unit) == ctx.hero then
					local point = Entity.GetAbsOrigin(unit)
					if ctx.distance(point, ctx.home) + 600 < ctx.distance(ctx.position, ctx.home) and not ctx.unsafePosition(point) then return api.cast(ctx, activate, "point", nil, point) end
				end
			end
		end
		if remnant and NPC.GetMana(ctx.hero) > 200 then
			local point = ctx.toward(ctx.position, ctx.home, math.min(1000, Ability.GetCastRange(remnant)))
			if GridNav.IsTraversable(point) and not ctx.unsafePosition(point) then
				state.remnant = {position = point, expires = ctx.now + 2.5}
				return api.cast(ctx, remnant, "point", nil, point)
			end
		end
		return false
	end
	if not enemy then return false end
	local chains = common.ability(ctx, api, "ember_spirit_searing_chains")
	if chains and ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy)) < 375 and not NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_ROOTED) then return api.cast(ctx, chains, "none") end
	local sleight = common.ability(ctx, api, "ember_spirit_sleight_of_fist")
	if sleight then
		local point = ctx.predict(enemy, 0.15)
		if ctx.distance(ctx.position, point) <= Ability.GetCastRange(sleight) then return api.cast(ctx, sleight, "point", nil, point) end
	end
	local guard = common.ability(ctx, api, "ember_spirit_flame_guard")
	if guard and ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy)) < 450 then return api.cast(ctx, guard, "none") end
	if remnant and Ability.GetCurrentCharges(remnant) >= 2 and ctx.health > 0.65 and ctx.nearEnemies <= ctx.nearAllies
		and NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_ROOTED) and NPC.GetMana(ctx.hero) > 300 then
		local point = Entity.GetAbsOrigin(enemy)
		if ctx.distance(ctx.position, point) <= Ability.GetCastRange(remnant) and not ctx.unsafePosition(point) then
			state.remnant = {position = point, expires = ctx.now + 2.5}
			return api.cast(ctx, remnant, "point", nil, point)
		end
	end
	return false
end

return ember
