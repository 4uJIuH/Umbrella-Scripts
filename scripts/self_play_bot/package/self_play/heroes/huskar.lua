local huskar = {}
local kv = XHelpers.xkv:GetKV("npc_abilities").DOTAAbilities

local function value(ability, key)
	local record = kv[Ability.GetName(ability)]
	local raw = record and record.AbilityValues and record.AbilityValues[key]
	if type(raw) == "table" then raw = raw.value end
	if type(raw) == "number" then return raw end
	if type(raw) ~= "string" then return 0 end
	local result, level = 0, 0
	for part in raw:gmatch("%-?%d+%.?%d*") do
		result, level = tonumber(part), level + 1
		if level >= Ability.GetLevel(ability) then break end
	end
	return result
end

function huskar.spellDamage(ctx, ability, target)
	local name = Ability.GetName(ability)
	if name == "huskar_life_break" then return Entity.GetHealth(target) * value(ability, "health_damage"), Entity.GetHealth(ctx.hero) * value(ability, "health_cost_percent") end
	if name == "huskar_inner_fire" then return value(ability, "damage"), value(ability, "health_cost") end
	if name == "huskar_burning_spear" then return 0, 0 end
end

function huskar.attackDamage(ctx, target, seconds)
	local spear = NPC.GetAbility(ctx.hero, "huskar_burning_spear")
	if not spear or Ability.GetLevel(spear) < 1 or not Ability.GetAutoCastState(spear)
		or NPC.HasState(ctx.hero, Enum.ModifierState.MODIFIER_STATE_DISARMED) then return 0, 0 end
	local attacks = math.max(0, seconds) / math.max(0.3, NPC.GetSecondsPerAttack(ctx.hero, false))
	local damage = value(spear, "burn_damage") + Entity.GetMaxHealth(target) * value(spear, "burn_damage_max_pct") / 100
	return damage * attacks * seconds * 0.35 * NPC.GetMagicalArmorDamageMultiplier(target),
		attacks * Entity.GetMaxHealth(ctx.hero) * value(spear, "max_health_cost") / 100
end

function huskar.recovery(ctx)
	local blood = NPC.GetAbility(ctx.hero, "huskar_berserkers_blood")
	if not blood or Ability.GetLevel(blood) < 1 or NPC.HasState(ctx.hero, Enum.ModifierState.MODIFIER_STATE_PASSIVES_DISABLED)
		or NPC.GetModifierProperty(ctx.hero, Enum.ModifierFunction.MODIFIER_PROPERTY_DISABLE_HEALING) > 0
		or NPC.HasModifier(ctx.hero, "modifier_ice_blast") then return nil end
	if NPC.HasModifier(ctx.hero, "modifier_item_spirit_vessel_damage") then return 0.4, 0.5 end
	local armlet = NPC.GetItem(ctx.hero, "item_armlet", true)
	if armlet and Item.IsItemEnabled(armlet) and Ability.GetToggleState(armlet) then return 0.25, 0.38 end
	return 0.32, 0.48
end

return huskar
