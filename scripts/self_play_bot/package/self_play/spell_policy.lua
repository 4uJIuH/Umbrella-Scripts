local policy = {}

local combatSpells = {
	tinker_laser = true, tinker_deploy_turrets = true, tinker_march_of_the_machines = true,
	arc_warden_flux = true, arc_warden_spark_wraith = true, arc_warden_magnetic_field = true,
	invoker_cold_snap = true, invoker_tornado = true, invoker_emp = true, invoker_chaos_meteor = true,
	invoker_sun_strike = true, invoker_deafening_blast = true, invoker_alacrity = true,
	invoker_forge_spirit = true, invoker_ice_wall = true,
}

function policy.excluded(name)
	return name:find("^seasonal_") ~= nil or name:find("^ability_") ~= nil or name:find("^special_bonus_") ~= nil
		or name:find("^twin_gate_") ~= nil or name == "abyssal_underlord_portal_warp"
end

function policy.offensive(ctx, ability)
	local name = Ability.GetName(ability)
	if policy.excluded(name) then return false end
	if name:find("^item_") then return false end
	if combatSpells[name] then return true end
	local effect = ctx.catalog.abilities[name] or {}
	if effect.heal or effect.save then return false end
	return effect.disable or effect.buff or effect.steal or effect.summon or Ability.GetDamage(ability) > 0
		or ctx.planner.levelValue(effect.damage, Ability.GetLevel(ability)) > 0
end

function policy.allow(ctx, ability, target)
	if policy.excluded(Ability.GetName(ability)) then return false end
	if not policy.offensive(ctx, ability) or Ability.GetManaCost(ability) <= 0 then return true end
	if ctx.retreating then return true end
	if not target or not Entity.IsEntity(target) or not Entity.IsAlive(target) or Entity.IsSameTeam(ctx.hero, target) then return true end
	if Entity.IsDormant(target) or not NPC.IsVisible(target) then return false end
	local mana, maximum, cost = NPC.GetMana(ctx.hero), NPC.GetMaxMana(ctx.hero), Ability.GetManaCost(ability)
	if NPC.HasModifier(ctx.hero, "modifier_item_soul_ring_buff") and ctx.intent and ctx.intent.kind == "hero" then return mana >= cost end
	if ctx.defensiveCast and NPC.IsHero(target) and ctx.laneThreat and ctx.laneThreat.attacked then return mana >= cost end
	local damage = math.max(Ability.GetDamage(ability), ctx.planner.levelValue((ctx.catalog.abilities[Ability.GetName(ability)] or {}).damage, Ability.GetLevel(ability)))
	local kill = damage > 0 and Entity.GetHealth(target) <= damage * 0.65
	if kill or NPC.IsChannellingAbility(target) then return mana >= cost end
	if ctx.temporaryUnit and NPC.IsHero(target) then return mana >= cost end
	local state = ctx.heroState or {}
	if state.combo and state.combo.executing or state.cyclone then return mana >= cost end
	local farm = ctx.farmCandidate
	if farm and not ctx.intent and farm.start <= ctx.now + Ability.GetCastPoint(ability) + 0.6 then return false end
	local early = ctx.clock < 600 and not ctx.temporaryUnit
	local reserve = math.max(maximum * (ctx.settings.manaReserve or 22) / 100, cost * (early and 1.25 or 0.5))
	if mana - cost < reserve then return false end
	if not early or not NPC.IsHero(target) then return true end
	local spent = 0
	for _, cast in ipairs(ctx.spellSpending or {}) do
		if ctx.now - cast.time < 20 then spent = spent + cast.cost end
	end
	if spent > 0 and spent + cost > maximum * 0.32 then return false end
	local attacking = ctx.attackTarget == target and NPC.IsAttacking(ctx.hero)
	local trading = Hero.GetRecentDamage(ctx.hero) > 0 and NPC.IsAttacking(target)
	local distance = ctx.distance(ctx.position, Entity.GetAbsOrigin(target))
	if ctx.clock < 15 and not trading then return false end
	if distance > NPC.GetAttackRange(ctx.hero) + NPC.GetAttackRangeBonus(ctx.hero) + 180 then return false end
	return attacking or trading or ctx.intent and ctx.intent.target == target and (ctx.intent.opportunity or 0) >= 60
		or NPC.IsStunned(target) and ctx.nearAllies > ctx.nearEnemies
		or Entity.GetHealth(target) < Entity.GetMaxHealth(target) * 0.65 and ctx.health > 0.65
end

function policy.record(ctx, ability)
	if not policy.offensive(ctx, ability) or Ability.GetManaCost(ability) <= 0 then return end
	local recent = {}
	for _, cast in ipairs(ctx.spellSpending or {}) do
		if ctx.now - cast.time < 20 then recent[#recent + 1] = cast end
	end
	recent[#recent + 1] = {time = ctx.now, cost = Ability.GetManaCost(ability)}
	ctx.spellSpending = recent
end

return policy
