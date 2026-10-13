local demon = {reserved = {shadow_demon_disruption = true, shadow_demon_shadow_poison_release = true,
	shadow_demon_demonic_cleanse = true}}
local common = require("self_play.heroes.common")
local tactics = require("self_play.heroes.tactics")

function demon.update(ctx, api, retreat)
	local disruption = NPC.GetAbility(ctx.hero, "shadow_demon_disruption")
	local ally = disruption and tactics.injured(ctx, Ability.GetCastRange(disruption), 0.3, true)
	if ally and not NPC.IsChannellingAbility(ally) and not NPC.HasModifier(ally, "modifier_dazzle_shallow_grave")
		and tactics.cast(ctx, api, "shadow_demon_disruption", "target", ally) then return true end
	local cleanse = NPC.GetAbility(ctx.hero, "shadow_demon_demonic_cleanse")
	if cleanse then
		for _, unit in ipairs(ctx.allies) do
			if common.visible(unit) and (NPC.IsSilenced(unit) or NPC.HasState(unit, Enum.ModifierState.MODIFIER_STATE_ROOTED)
				or Entity.GetHealth(unit) < Entity.GetMaxHealth(unit) * 0.6 and Hero.GetRecentDamage(unit) > 0) then
				if tactics.cast(ctx, api, "shadow_demon_demonic_cleanse", "target", unit) then return true end
			end
		end
	end
	local poison = NPC.GetAbility(ctx.hero, "shadow_demon_shadow_poison")
	if poison then
		for _, enemy in ipairs(ctx.enemies) do
			local modifier = common.visible(enemy) and NPC.GetModifier(enemy, "modifier_shadow_demon_shadow_poison")
			if modifier then
				local stacks = Modifier.GetStackCount(modifier)
				local damage = common.value(poison, "stack_damage", 24) * 2 ^ math.max(0, math.min(5, stacks) - 1)
				local lethal = Entity.GetHealth(enemy) < damage * NPC.GetMagicalArmorDamageMultiplier(enemy)
				if stacks >= 5 or lethal or stacks >= 3 and Modifier.GetDieTime(modifier) - ctx.now < 1 then
					if tactics.cast(ctx, api, "shadow_demon_shadow_poison_release", "none") then return true end
				end
			end
		end
	end
	local enemy = tactics.enemy(ctx, 675)
	if enemy and (NPC.IsChannellingAbility(enemy) or retreat and ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy)) < 400)
		and not NPC.IsStunned(enemy) then return tactics.cast(ctx, api, "shadow_demon_disruption", "target", enemy) end
	return false
end

return demon
