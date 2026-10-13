local doctor = {reserved = {witch_doctor_death_ward = true, witch_doctor_voodoo_switcheroo = true,
	witch_doctor_voodoo_restoration = true, witch_doctor_maledict = true}}
local common = require("self_play.heroes.common")
local tactics = require("self_play.heroes.tactics")

function doctor.emergency(ctx, api)
	local enemy = tactics.enemy(ctx, 1100)
	if enemy and ctx.health < 0.45 and Hero.GetRecentDamage(ctx.hero) > 0
		and ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy)) < 650
		and tactics.cast(ctx, api, "witch_doctor_voodoo_switcheroo", "none") then return true end
	local heal = NPC.GetAbility(ctx.hero, "witch_doctor_voodoo_restoration")
	if heal then
		local ally = tactics.injured(ctx, common.value(heal, "radius", 500), 0.8)
		local wanted = ally ~= nil and NPC.GetMana(ctx.hero) > 100
		if Ability.GetToggleState(heal) ~= wanted then
			if tactics.cast(ctx, api, "witch_doctor_voodoo_restoration", "toggle") then return true end
		end
	end
	return false
end

function doctor.update(ctx, api, retreat)
	if doctor.emergency(ctx, api) then return true end
	local enemy = tactics.enemy(ctx, 1100)
	if not enemy or retreat or not tactics.committed(ctx, enemy) then return false end
	local maledict = NPC.GetAbility(ctx.hero, "witch_doctor_maledict")
	if maledict and not NPC.HasModifier(enemy, "modifier_maledict")
		and tactics.cast(ctx, api, "witch_doctor_maledict", "point", nil, ctx.predict(enemy, Ability.GetCastPoint(maledict))) then return true end
	local ward = NPC.GetAbility(ctx.hero, "witch_doctor_death_ward")
	if ward and tactics.safe(ctx, ctx.position, 2) then
		local point = ctx.toward(ctx.position, Entity.GetAbsOrigin(enemy), math.max(0, Ability.GetCastRange(ward) - 30))
		if ctx.distance(point, ctx.predict(enemy, 0.5)) < common.value(ward, "attack_range_tooltip", 600) - 60 then
			return tactics.cast(ctx, api, "witch_doctor_death_ward", "point", nil, point)
		end
	end
	return false
end

function doctor.unit(ctx, api, unit)
	if NPC.GetUnitName(unit) ~= "npc_dota_witch_doctor_death_ward" then return false end
	local target = tactics.enemy(ctx, 1700)
	if target and ctx.distance(Entity.GetAbsOrigin(unit), Entity.GetAbsOrigin(target)) <= NPC.GetAttackRange(unit) + NPC.GetAttackRangeBonus(unit) then
		return common.unitAttack(ctx, unit, target)
	end
	return true
end

return doctor
