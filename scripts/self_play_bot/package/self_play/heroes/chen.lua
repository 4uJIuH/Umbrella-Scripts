local chen = {reserved = {chen_holy_persuasion = true, chen_hand_of_god = true, chen_divine_favor = true,
	chen_zealot = true, chen_martyrdom = true, chen_test_of_faith_teleport = true}}
local common = require("self_play.heroes.common")
local tactics = require("self_play.heroes.tactics")

function chen.emergency(ctx, api)
	local god = NPC.GetAbility(ctx.hero, "chen_hand_of_god")
	local wounded, critical = 0, false
	if god then
		local heal = common.value(god, "heal_amount", 200)
		for _, ally in ipairs(ctx.allies) do
			if common.visible(ally) and not NPC.IsIllusion(ally) then
				local hp, max = Entity.GetHealth(ally), Entity.GetMaxHealth(ally)
				if max - hp >= heal and hp < max * 0.7 then wounded = wounded + 1 end
				if hp < max * 0.35 and Hero.GetRecentDamage(ally) > 0 then critical = true end
			end
		end
		if (wounded >= 2 or critical) and tactics.cast(ctx, api, "chen_hand_of_god", "none") then return true end
	end
	local favor = NPC.GetAbility(ctx.hero, "chen_divine_favor")
	local ally = favor and tactics.injured(ctx, Ability.GetCastRange(favor), 0.8, true)
	if ally and not NPC.HasModifier(ally, "modifier_chen_divine_favor")
		and tactics.cast(ctx, api, "chen_divine_favor", "target", ally) then return true end
	return false
end

function chen.update(ctx, api, retreat)
	if chen.emergency(ctx, api) then return true end
	if retreat then return false end
	local persuade = common.ability(ctx, api, "chen_holy_persuasion")
	if not persuade then return false end
	local count = 0
	for _, unit in ipairs(ctx.summons) do if common.visible(unit) and NPC.HasModifier(unit, "modifier_chen_holy_persuasion") then count = count + 1 end end
	if count >= common.value(persuade, "max_units", Ability.GetLevel(persuade)) then return false end
	local best, score
	for _, unit in ipairs(ctx.neutrals) do
		if common.visible(unit) and NPC.IsCreep(unit) and not NPC.IsRoshan(unit) and not NPC.IsTormentor(unit)
			and NPC.GetCurrentLevel(unit) <= common.value(persuade, "level_req", 3)
			and ctx.distance(ctx.position, Entity.GetAbsOrigin(unit)) <= Ability.GetCastRange(persuade) and api.allowed(ctx, persuade, unit) then
			local value = NPC.GetTrueDamage(unit) + Entity.GetMaxHealth(unit) * 0.05
			for i = 0, 7 do
				local ability = NPC.GetAbilityByIndex(unit, i)
				if ability and not Ability.IsPassive(ability) then value = value + 35 end
			end
			if not score or value > score then best, score = unit, value end
		end
	end
	return best and tactics.cast(ctx, api, "chen_holy_persuasion", "target", best) or false
end

return chen
