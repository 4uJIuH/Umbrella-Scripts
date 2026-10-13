local brew = {reserved = {brewmaster_cinder_brew = true, brewmaster_thunder_clap = true, brewmaster_primal_split = true,
	brewmaster_primal_split_cancel = true, brewmaster_drunken_brawler = true, brewmaster_primal_companion = true}}
local common = require("self_play.heroes.common")

function brew.update(ctx, api, retreat)
	local count = 0
	for _, unit in ipairs(ctx.summons) do if common.visible(unit) and NPC.GetUnitName(unit):find("^npc_dota_brewmaster_") then count = count + 1 end end
	if count >= 2 then ctx.mode = "Brewmaster: control Primal Split"; return true end
	local enemy = common.enemy(ctx, 1100)
	local split = common.ability(ctx, api, "brewmaster_primal_split")
	if split and enemy and (ctx.health < 0.45 or ctx.nearEnemies >= 2) then return api.cast(ctx, split, "none") end
	if common.items(ctx, api, enemy, retreat) then return true end
	if not enemy then return false end
	local cinder = common.ability(ctx, api, "brewmaster_cinder_brew")
	if cinder and not NPC.HasModifier(enemy, "modifier_brewmaster_cinder_brew") then
		local point = ctx.predict(enemy, 0.2 + ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy)) / 950)
		if ctx.distance(ctx.position, point) <= Ability.GetCastRange(cinder) then return api.cast(ctx, cinder, "point", nil, point) end
	end
	local clap = common.ability(ctx, api, "brewmaster_thunder_clap")
	if clap and ctx.distance(ctx.position, ctx.predict(enemy, Ability.GetCastPoint(clap))) < common.value(clap, "radius", 400) - 40 then
		return api.cast(ctx, clap, "none")
	end
	return false
end

function brew.unit(ctx, api, unit)
	local name = NPC.GetUnitName(unit)
	if not name:find("^npc_dota_brewmaster_") then return false end
	local actor = common.actor(ctx, unit)
	if api.busy(actor) then return true end
	local target = common.enemy(actor, 1300)
	local fleeing = ctx.retreating or actor.health < 0.2
	if name:find("storm", 1, true) then
		local wind = common.ability(actor, api, "brewmaster_storm_wind_walk")
		if fleeing and wind then return api.cast(actor, wind, "none") end
		local cyclone = common.ability(actor, api, "brewmaster_storm_cyclone")
		if cyclone then
			for _, enemy in ipairs(ctx.enemies) do
				if common.visible(enemy) and (enemy ~= ctx.target or NPC.IsChannellingAbility(enemy)) and not NPC.IsStunned(enemy)
					and common.cast(actor, api, cyclone, "target", enemy) then return true end
			end
		end
	elseif name:find("earth", 1, true) and target then
		local boulder = common.ability(actor, api, "brewmaster_earth_hurl_boulder")
		if boulder and not NPC.IsStunned(target) and common.cast(actor, api, boulder, "target", target) then return true end
	elseif name:find("void", 1, true) and target then
		local pulse = common.ability(actor, api, "brewmaster_void_astral_pulse")
		if pulse and ctx.distance(actor.position, Entity.GetAbsOrigin(target)) < 450 then return api.cast(actor, pulse, "none") end
	end
	if fleeing then return actor.move(ctx.toward(actor.position, ctx.home, 700)) end
	if actor.target then return common.unitAttack(ctx, unit, actor.target) end
	return true
end

return brew
