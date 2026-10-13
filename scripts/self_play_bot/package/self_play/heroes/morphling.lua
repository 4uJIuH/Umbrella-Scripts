local morph = {reserved = {morphling_morph_agi = true, morphling_morph_str = true, morphling_waveform = true,
	morphling_replicate = true, morphling_morph_replicate = true, morphling_hybrid = true}}
local common = require("self_play.heroes.common")
local tactics = require("self_play.heroes.tactics")
local awareness = require("self_play.awareness")

local function shift(ctx, api)
	local str, agi = NPC.GetAbility(ctx.hero, "morphling_morph_str"), NPC.GetAbility(ctx.hero, "morphling_morph_agi")
	local danger = ctx.retreating or ctx.hardRetreat or awareness.damage(ctx, ctx.position, 2) > Entity.GetHealth(ctx.hero) * 0.3
	local strength = ctx.health < 0.55 or danger and ctx.health < 0.8
	local agility = not danger and ctx.health > 0.92 and Hero.GetStrength(ctx.hero) > 35 and ctx.nearEnemies == 0
	if agi and Ability.GetToggleState(agi) and not agility then return tactics.cast(ctx, api, "morphling_morph_agi", "toggle") end
	if str and Ability.GetToggleState(str) and not strength and ctx.health > 0.8 then return tactics.cast(ctx, api, "morphling_morph_str", "toggle") end
	if str and strength and not Ability.GetToggleState(str) then return tactics.cast(ctx, api, "morphling_morph_str", "toggle") end
	if agi and agility and not Ability.GetToggleState(agi) then return tactics.cast(ctx, api, "morphling_morph_agi", "toggle") end
	return false
end

function morph.emergency(ctx, api)
	return shift(ctx, api)
end

function morph.update(ctx, api, retreat)
	if shift(ctx, api) then return true end
	local task = ctx.heroState.morph
	if task and (retreat or ctx.health < 0.5 or ctx.now > task.expires or not tactics.enemy(ctx, 1100)) then
		local used, cast = tactics.cast(ctx, api, "morphling_morph_replicate", "none")
		if cast or ctx.now > task.expires + 2 then ctx.heroState.morph = nil end
		if used then return true end
	end
	local enemy, wave = tactics.enemy(ctx, 1200), NPC.GetAbility(ctx.hero, "morphling_waveform")
	if wave and (retreat or enemy and tactics.committed(ctx, enemy) and ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy)) > 450) then
		local range = Ability.GetCastRange(wave)
		local point = retreat and ctx.toward(ctx.position, ctx.home, range - 30) or tactics.point(ctx, wave, enemy, common.value(wave, "speed", 1250))
		if GridNav.IsTraversable(point) and not ctx.unsafePosition(point) and (retreat or tactics.safe(ctx, point, 2)) then
			if tactics.cast(ctx, api, "morphling_waveform", "point", nil, point) then return true end
		end
	end
	if retreat or task or not enemy or not tactics.committed(ctx, enemy) or ctx.health < 0.65 then return false end
	local useful = 0
	for i = 0, 7 do
		local ability = NPC.GetAbilityByIndex(enemy, i)
		if ability and Ability.GetLevel(ability) > 0 and not Ability.IsPassive(ability) and not Ability.IsUltimate(ability)
			and not Ability.IsHidden(ability) and Ability.GetManaCost(ability) <= NPC.GetMana(ctx.hero) * 0.4 then useful = useful + 1 end
	end
	if useful < 2 then return false end
	local used, cast = tactics.cast(ctx, api, "morphling_replicate", "target", enemy)
	if cast then ctx.heroState.morph = {expires = ctx.now + 20} end
	return used
end

return morph
