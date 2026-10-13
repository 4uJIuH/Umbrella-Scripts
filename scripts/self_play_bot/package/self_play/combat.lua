local combat = {}
local spellPolicy = require("self_play.spell_policy")
local intent = require("self_play.intent")
local geometry = require("self_play.cast_geometry")
local heroModules = require("self_play.heroes.registry")
local activeItems = require("self_play.active_items")
local unitControl = require("self_play.units")
local talents = require("self_play.talents")
local laneRules = require("self_play.lane_rules")

local behavior = Enum.AbilityBehavior
local targetTeam = Enum.TargetTeam
local targetType = Enum.TargetType
local modifier = Enum.ModifierState
local abilityKV = XHelpers.xkv:GetKV("npc_abilities").DOTAAbilities
local itemKV = XHelpers.xkv:GetKV("items").DOTAAbilities

local function kvNumber(value, level)
	if type(value) == "table" then value = value.value end
	if type(value) == "number" then return value end
	if type(value) ~= "string" then return 0 end
	local result, index = 0, 0
	for number in value:gmatch("%-?%d+%.?%d*") do
		index, result = index + 1, tonumber(number)
		if index >= math.max(1, level) then break end
	end
	return result
end
local managedItems = {
	item_power_treads = true,
	item_tango = true, item_tango_single = true, item_flask = true, item_clarity = true,
	item_bottle = true, item_enchanted_mango = true, item_faerie_fire = true, item_magic_stick = true,
	item_magic_wand = true, item_holy_locket = true, item_arcane_boots = true, item_mekansm = true,
	item_guardian_greaves = true, item_blood_grenade = true, item_ward_observer = true,
	item_ward_sentry = true, item_ward_dispenser = true, item_tpscroll = true, item_travel_boots = true,
	item_travel_boots_2 = true, item_smoke_of_deceit = true, item_dust = true,
	item_healing_lotus = true, item_greater_healing_lotus = true, item_greatest_healing_lotus = true,
}

local function ready(ctx, ability, item)
	if not ability or Ability.IsHidden(ability) or not Ability.IsActivated(ability)
		or Ability.IsPassive(ability) or not Ability.IsReady(ability) then return false end
	if not item and spellPolicy.excluded(Ability.GetName(ability)) then return false end
	if item then
		if NPC.HasState(ctx.hero, modifier.MODIFIER_STATE_MUTED) or not Item.IsItemEnabled(ability) then return false end
		if Ability.GetName(ability) == "item_bottle" and Item.GetCurrentCharges(ability) <= 0 then
			local rune = Bottle.GetRuneType(ability)
			if rune < 0 or rune >= Enum.RuneType.DOTA_RUNE_COUNT then return false end
		end
		if Item.RequiresCharges(ability) and Item.GetCurrentCharges(ability) <= 0 then return false end
	elseif Ability.GetLevel(ability) < 1 or NPC.IsSilenced(ctx.hero) then
		return false
	end
	return Ability.IsCastable(ability, NPC.GetMana(ctx.hero))
		and Ability.CanBeExecuted(ability) == -1
end

local function allowed(ctx, ability, target)
	local flags = Ability.GetTargetFlags(ability)
	local types = Ability.GetTargetType(ability)
	local teams = Ability.GetTargetTeam(ability)
	local allied = Entity.IsSameTeam(ctx.hero, target)
	local has = ctx.planner.hasFlag
	local effect = ctx.catalog.abilities[Ability.GetName(ability)]
	local customMobility = effect and effect.unitMobility and effect.targetsBoth
	if not (teams == targetTeam.DOTA_UNIT_TARGET_TEAM_CUSTOM and customMobility)
		and not has(teams, allied and targetTeam.DOTA_UNIT_TARGET_TEAM_FRIENDLY or targetTeam.DOTA_UNIT_TARGET_TEAM_ENEMY) then return false end
	local unitType = NPC.IsHero(target) and targetType.DOTA_UNIT_TARGET_HERO or NPC.IsStructure(target) and targetType.DOTA_UNIT_TARGET_BUILDING or targetType.DOTA_UNIT_TARGET_BASIC
	if not (types == targetType.DOTA_UNIT_TARGET_CUSTOM and customMobility) and not has(types, unitType)
		and not (target == ctx.hero and has(types, targetType.DOTA_UNIT_TARGET_SELF)) then return false end
	if NPC.HasState(target, modifier.MODIFIER_STATE_INVULNERABLE) or NPC.HasState(target, modifier.MODIFIER_STATE_OUT_OF_GAME) then return false end
	if has(flags, Enum.TargetFlags.DOTA_UNIT_TARGET_FLAG_MELEE_ONLY) and NPC.IsRanged(target) then return false end
	if has(flags, Enum.TargetFlags.DOTA_UNIT_TARGET_FLAG_RANGED_ONLY) and not NPC.IsRanged(target) then return false end
	if not allied then
		if NPC.IsLinkensProtected(target) or NPC.IsMirrorProtected(target) then return false end
		if NPC.HasState(target, modifier.MODIFIER_STATE_MAGIC_IMMUNE)
			and not has(flags, Enum.TargetFlags.DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES) then return false end
	end
	return true
end

function combat.busy(ctx)
	if NPC.IsChannellingAbility(ctx.hero) or ctx.now < ctx.busyUntil then return true end
	local order = ctx.hits.ordered
	if order and not order.confirmed and ctx.lastOrder == "attack" and ctx.now < order.expires then return true end
	for index = 0, 31 do
		local ability = NPC.GetAbilityByIndex(ctx.hero, index)
		if ability and Ability.IsInAbilityPhase(ability) then return true end
	end
	return false
end

local function cast(ctx, ability, kind, target, position)
	if kind == "toggle" then Ability.Toggle(ability, false, false, true)
	elseif kind == "autocast" then Ability.ToggleMod(ability, false, false, true)
	else
		local order = kind == "target" and Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TARGET
			or kind == "point" and Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION or Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET
		Player.PrepareUnitOrders(ctx.player, order, target, position or Vector(0, 0, 0), ability,
			Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, ctx.hero, false, false, false, true, "self_play_cast", false)
	end
	ctx.busyUntil = ctx.now + math.max(0.2, Ability.GetCastPoint(ability) + 0.12)
	ctx.countOrder()
	ctx.lastAbility = Ability.GetName(ability)
	ctx.abilityAttempts[ctx.lastAbility] = ctx.now + 1
	ctx.lastOrder = "cast"
	spellPolicy.record(ctx, ability)
	if ctx.parent then
		ctx.parent.heroState.unitOrders[Entity.GetIndex(ctx.hero)] = nil
		ctx.unitFollowAttack = true
	end
	local effect = ctx.catalog.abilities[ctx.lastAbility]
	if not ctx.retreating and not ctx.defensiveCast and kind == "target" and target and effect and effect.unitMobility and NPC.IsHero(target)
		and not Entity.IsSameTeam(ctx.hero, target) then
		intent.begin(ctx, target, "hero", true)
	end
	local enemy = target and NPC.IsHero(target) and not Entity.IsSameTeam(ctx.hero, target) and target or ctx.target
	if not ctx.retreating and not ctx.defensiveCast and enemy and Entity.IsEntity(enemy) and Entity.IsAlive(enemy)
		and not Entity.IsDormant(enemy) and NPC.IsVisible(enemy) and spellPolicy.offensive(ctx, ability)
		and not ctx.unsafePosition(Entity.GetAbsOrigin(enemy)) and ctx.health >= 0.45
		and (ctx.intent and ctx.intent.target == enemy or ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy)) < NPC.GetAttackRange(ctx.hero) + 350) then
		intent.follow(ctx, enemy)
	end
	return true
end

combat.ready = ready
combat.cast = cast
combat.allowed = allowed
combat.items = function(ctx, defensiveOnly) return activeItems.run(ctx, combat, defensiveOnly) end

function combat.talentEligibility(hero)
	local talents, result, siblings, learned = {}, {}, {}, {}
	for index = 0, 31 do
		local ability = NPC.GetAbilityByIndex(hero, index)
		local name = ability and Ability.GetName(ability)
		if name and name:find("^special_bonus_") and name ~= "special_bonus_attributes" then talents[#talents + 1] = ability end
	end
	local level = NPC.GetCurrentLevel(hero)
	for index, ability in ipairs(talents) do
		learned[Ability.GetName(ability)] = Ability.GetLevel(ability) > 0
			or index <= 8 and Hero.TalentIsLearned(hero, Enum.TalentTypes["TALENT_" .. index])
	end
	for index, ability in ipairs(talents) do
		local tier = math.floor((index - 1) / 2)
		local sibling = talents[index % 2 == 1 and index + 1 or index - 1]
		siblings[Ability.GetName(ability)] = sibling and Ability.GetName(sibling) or nil
		result[Ability.GetName(ability)] = tier < 4 and not learned[Ability.GetName(ability)] and level >= 10 + tier * 5
			and (not sibling or not learned[Ability.GetName(sibling)] or level >= 27 + tier)
	end
	return result, siblings, learned
end

function combat.level(ctx)
	if not ctx.settings.level or ctx.now < ctx.nextLevel then return end
	ctx.nextLevel = ctx.now + 0.35
	if ctx.settings.online and ctx.now < (ctx.shop.buildWaitUntil or 0)
		and not ctx.shop.protrackerRole and (ctx.shop.requesting or ctx.shop.attempts < 2) then return end
	ctx.levelBlocked = ctx.levelBlocked or {}
	local talentEligibility, talentSiblings, learnedTalents = combat.talentEligibility(ctx.hero)
	local pending = ctx.levelPending
	if pending then
		if Ability.GetLevel(pending.ability) > pending.level or learnedTalents[Ability.GetName(pending.ability)] then
			ctx.levelPending = nil
		elseif ctx.now - pending.time < (pending.talent and 0.25 or 1) then return
		else
			ctx.levelBlocked[Ability.GetName(pending.ability)] = ctx.now + (pending.talent and 0.1 or 4)
			ctx.levelPending = nil
		end
	end
	local best, bestScore = nil, -math.huge
	local abilityPoints = Hero.GetAbilityPoints(ctx.hero)
	local desired, planned = {}, {}
	local preferredTalents = {}
	local guide = ctx.shop.guide
	if guide then
		for _, name in pairs(guide.talents or {}) do preferredTalents[name] = true end
		for _, name in pairs(guide.skills) do if name:find("^special_bonus_") then preferredTalents[name] = true end end
		for level = 1, math.min(30, NPC.GetCurrentLevel(ctx.hero)) do
			local name = guide.skills[level]
			if name then
				desired[name] = (desired[name] or 0) + 1
				local ability = NPC.GetAbility(ctx.hero, name)
				if ability and Ability.GetLevel(ability) < desired[name] and not planned[name] then planned[name] = level end
			end
		end
	end
	for index = 0, 31 do
		local ability = NPC.GetAbilityByIndex(ctx.hero, index)
		local kv = ability and abilityKV[Ability.GetName(ability)]
		if ability and not Ability.GetName(ability):find("^seasonal_") and Ability.CanBeUpgraded(ability) and not (kv and kv.OnLearnbar == "0")
			and not (ctx.settings.talents == false and Ability.GetName(ability):find("^special_bonus_"))
			and talentEligibility[Ability.GetName(ability)] ~= false
			and (abilityPoints > 0 or talentEligibility[Ability.GetName(ability)] == true)
			and not (not preferredTalents[Ability.GetName(ability)] and preferredTalents[talentSiblings[Ability.GetName(ability)]]
				and talentEligibility[talentSiblings[Ability.GetName(ability)]])
			and (ctx.levelBlocked[Ability.GetName(ability)] or 0) <= ctx.now then
			local name, level = Ability.GetName(ability), Ability.GetLevel(ability)
			local score = -index * 0.01
			if (desired[name] or 0) > level then score = score + 100 end
			if Ability.IsUltimate(ability) then score = score + 30 end
			local talent = name:find("^special_bonus_") and name ~= "special_bonus_attributes"
			if name == "special_bonus_attributes" then score = score - 100 end
			local effect = ctx.catalog.abilities[name]
			if effect and effect.disable then score = score + (ctx.role >= 4 and 12 or 5) end
			if effect and effect.heal and ctx.role >= 4 then score = score + 6 end
			if level == 0 and not Ability.IsHidden(ability) and not name:find("^special_bonus_") then score = score + 8 end
			score = score + heroModules.skills(ctx, name)
			if planned[name] then score = 5000 - planned[name] * 50 end
			if talent then score = 10000 + (preferredTalents[name] and 200 or 0) - index * 0.01 end
			if score > bestScore then best, bestScore = ability, score end
		end
	end
	if ctx.settings.talents ~= false and NPC.GetCurrentLevel(ctx.hero) >= 10 and ctx.now >= (ctx.nextTalentDiagnose or 0) then
		ctx.nextTalentDiagnose = ctx.now + 15
		local states = {}
		for index = 0, 31 do
			local entry = NPC.GetAbilityByIndex(ctx.hero, index)
			local entryName = entry and Ability.GetName(entry)
			if entryName and entryName:find("^special_bonus_") and entryName ~= "special_bonus_attributes"
				and talentEligibility[entryName] then
				states[#states + 1] = entryName:gsub("^special_bonus_", "")
					.. (learnedTalents[entryName] and "=picked" or Ability.CanBeUpgraded(entry) and "=open" or "=locked")
			end
		end
		if #states > 0 then
			Log.Write(string.format("[SelfPlay talents] level=%d points=%d best=%s states=%s",
				NPC.GetCurrentLevel(ctx.hero), abilityPoints, best and Ability.GetName(best) or "none",
				table.concat(states, ",")))
		end
	end
	if best then
		local name = Ability.GetName(best)
		if name:find("^special_bonus_") and name ~= "special_bonus_attributes" then
			if not talents.learn(ctx, best) then ctx.levelBlocked[name] = ctx.now + 1; return end
		else
			Player.PrepareUnitOrders(ctx.player, Enum.UnitOrder.DOTA_UNIT_ORDER_TRAIN_ABILITY, nil, Vector(0, 0, 0), best,
				Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, ctx.hero, false, false, false, true, "self_play_level", false)
		end
		ctx.levelPending = {ability = best, level = Ability.GetLevel(best), time = ctx.now,
			talent = name:find("^special_bonus_") and name ~= "special_bonus_attributes"}
	end
end

function combat.farm(ctx, units, defending)
	if not ctx.settings.spells or combat.busy(ctx) or ctx.retreating or ctx.hardRetreat
		or not defending and ctx.clock < (ctx.laneEnd or 600) then return false end
	if ctx.target and Entity.IsEntity(ctx.target) and Entity.IsAlive(ctx.target) and NPC.IsHero(ctx.target)
		and not Entity.IsDormant(ctx.target) and NPC.IsVisible(ctx.target)
		and ctx.distance(ctx.position, Entity.GetAbsOrigin(ctx.target)) < 1200 then return false end
	local targets = {}
	for _, unit in ipairs(units) do
		if Entity.IsEntity(unit) and Entity.IsNPC(unit) and Entity.IsAlive(unit) and not Entity.IsDormant(unit)
			and NPC.IsVisible(unit) and not Entity.IsSameTeam(ctx.hero, unit) and not NPC.IsWaitingToSpawn(unit)
			and (NPC.IsLaneCreep(unit) or NPC.IsNeutral(unit) and NPC.IsCreep(unit))
			and not NPC.IsRoshan(unit) and not NPC.IsTormentor(unit)
			and not NPC.HasState(unit, modifier.MODIFIER_STATE_INVULNERABLE)
			and not NPC.HasState(unit, modifier.MODIFIER_STATE_OUT_OF_GAME)
			and ctx.distance(ctx.position, Entity.GetAbsOrigin(unit)) < 1500 then
			if not defending and NPC.IsLaneCreep(unit) and not laneRules.canLastHit(ctx, unit) then return false end
			targets[#targets + 1] = unit
		end
	end
	if #targets == 0 then return false end
	local mana, maximum = NPC.GetMana(ctx.hero), NPC.GetMaxMana(ctx.hero)
	local has, best, bestScore = ctx.planner.hasFlag, nil, 0
	for index = 0, 31 do
		local ability = NPC.GetAbilityByIndex(ctx.hero, index)
		local name = ability and Ability.GetName(ability)
		local effect = name and ctx.catalog.abilities[name]
		if effect and ready(ctx, ability, false) and not Ability.IsUltimate(ability)
			and not heroModules.reserved(ctx, name) and not unitControl.summons[name]
			and (ctx.abilityAttempts[name] or 0) <= ctx.now
			and not effect.unsafe and not effect.heal and not effect.save and not effect.mobility
			and not effect.unitMobility and not effect.buff and not effect.summon then
			local flags, level = Ability.GetBehavior(ability), Ability.GetLevel(ability)
			local cost, point = Ability.GetManaCost(ability), Ability.GetCastPoint(ability)
			local kv = abilityKV[name] or {}
			local healthCost = kvNumber(kv.AbilityHealthCost, level)
			local damage = math.max(Ability.GetDamage(ability), ctx.planner.levelValue(effect.damage, level))
			local radius, range = ctx.planner.levelValue(effect.radius, level), Ability.GetCastRange(ability)
			local values = kv.AbilityValues or {}
			local radiusKey = XHelpers.XAbility.aoe_radiuses[name] or XHelpers.XAbility.radiuses[name]
			if type(radiusKey) == "string" then radius = math.max(radius, kvNumber(values[radiusKey], level)) end
			local widthKey = XHelpers.XAbility.start_widths[name]
			local width = type(widthKey) == "string" and kvNumber(values[widthKey], level) or 0
			local endKey = XHelpers.XAbility.end_widths[name]
			local endWidth = type(endKey) == "string" and kvNumber(values[endKey], level) or 0
			if endWidth > 0 then width = math.min(width, endWidth) end
			local kind = has(flags, behavior.DOTA_ABILITY_BEHAVIOR_UNIT_TARGET) and "target"
				or has(flags, behavior.DOTA_ABILITY_BEHAVIOR_POINT) and "point"
				or has(flags, behavior.DOTA_ABILITY_BEHAVIOR_NO_TARGET) and "none"
			local legal = kind and damage > 0 and point <= 0.8 and kvNumber(kv.AbilityChannelTime, level) == 0
				and ctx.planner.levelValue(effect.frontOffset, level) == 0
				and not has(flags, behavior.DOTA_ABILITY_BEHAVIOR_CHANNELLED)
				and not has(flags, behavior.DOTA_ABILITY_BEHAVIOR_TOGGLE)
				and not has(flags, behavior.DOTA_ABILITY_BEHAVIOR_AUTOCAST)
				and not has(flags, behavior.DOTA_ABILITY_BEHAVIOR_VECTOR_TARGETING)
				and not has(flags, behavior.DOTA_ABILITY_BEHAVIOR_RUNE_TARGET)
				and not has(flags, behavior.DOTA_ABILITY_BEHAVIOR_FREE_DRAW_TARGETING)
				and mana - cost >= maximum * (defending and 0.12 or ctx.settings.manaReserve / 100)
				and Entity.GetHealth(ctx.hero) - healthCost >= Entity.GetMaxHealth(ctx.hero) * 0.5
			if legal then
				for _, anchor in ipairs(targets) do
					local center = kind == "none" and ctx.position or Entity.GetAbsOrigin(anchor)
					if (kind == "none" or ctx.distance(ctx.position, center) <= range) and allowed(ctx, ability, anchor) then
						local hits, useful, saved = 0, 0, 0
						for _, unit in ipairs(targets) do
							local inside = width > 0 and kind ~= "none" and geometry.lineHit(ctx.position, center, Entity.GetAbsOrigin(unit), range, width)
								or width == 0 and (kind == "target" and unit == anchor or kind ~= "target" and radius > 0
									and ctx.distance(center, Entity.GetAbsOrigin(unit)) <= math.max(1, radius - 30))
							if inside and allowed(ctx, ability, unit) then
								local multiplier = Ability.GetDamageType(ability) == Enum.DamageTypes.DAMAGE_TYPE_MAGICAL and NPC.GetMagicalArmorDamageMultiplier(unit)
									or Ability.GetDamageType(ability) == Enum.DamageTypes.DAMAGE_TYPE_PHYSICAL and NPC.GetArmorDamageMultiplier(unit) or 1
								local dealt = math.min(Entity.GetHealth(unit), damage * multiplier)
								if dealt >= 60 then hits, useful = hits + 1, useful + dealt end
								saved = saved + dealt / math.max(1, NPC.GetTrueDamage(ctx.hero) * NPC.GetArmorDamageMultiplier(unit))
							end
						end
						local score = useful / math.max(30, cost) + saved - point * 2
						if hits >= (kind == "target" and 1 or 2) and saved >= (defending and 1.5 or 2.5)
							and useful >= math.max(100, cost * 1.4) and score > bestScore then
							best, bestScore = {ability = ability, kind = kind, target = anchor, position = center}, score
						end
					end
				end
			end
		end
	end
	if not best then return false end
	ctx.mode = defending and "Use spell to clear siege wave" or "Use spell to clear creeps"
	return cast(ctx, best.ability, best.kind, best.target, best.position)
end

function combat.run(ctx, retreat)
	if not ctx.settings.spells or combat.busy(ctx) or NPC.IsStunned(ctx.hero) then return false end
	if combat.items(ctx, false) then return true end
	if not retreat and unitControl.summon(ctx, combat) then return true end
	local aim = ctx.aimTask
	if aim then
		if retreat or ctx.now > aim.expires or not Entity.IsEntity(aim.target) or not Entity.IsAlive(aim.target)
			or Entity.IsDormant(aim.target) or not NPC.IsVisible(aim.target) or not ready(ctx, aim.ability, false) then
			ctx.aimTask = nil
		else
			local predicted = ctx.predict(aim.target, Ability.GetCastPoint(aim.ability))
			if geometry.frontHit(ctx.position, Entity.GetRotation(ctx.hero):GetForward(), predicted, aim.offset, aim.radius) then
				ctx.aimTask = nil
				return cast(ctx, aim.ability, "none", aim.target)
			end
			if math.abs(ctx.distance(ctx.position, predicted) - aim.offset) > aim.radius - 35 then ctx.aimTask = nil
			else
				if ctx.now >= aim.nextTurn then
					NPC.MoveTo(ctx.hero, ctx.toward(ctx.position, predicted, 35), false, false, false, true)
					aim.nextTurn = ctx.now + 0.1
				end
				ctx.lastOrder, ctx.mode = "face", "Aim directional spell"
				return true
			end
		end
	end
	local best, bestScore = nil, 0
	local mana, maxMana = NPC.GetMana(ctx.hero), NPC.GetMaxMana(ctx.hero)
	local has = ctx.planner.hasFlag
	local function consider(ability, isItem)
		if ability and not isItem and unitControl.summons[Ability.GetName(ability)] then return end
		if ability and not isItem and spellPolicy.excluded(Ability.GetName(ability)) then return end
		if ability and isItem and (managedItems[Ability.GetName(ability)] or activeItems.managed[Ability.GetName(ability)]) then return end
		if ability and heroModules.reserved(ctx, Ability.GetName(ability)) then return end
		if ability and Ability.IsActivated(ability) and not Ability.IsHidden(ability)
			and has(Ability.GetBehavior(ability), behavior.DOTA_ABILITY_BEHAVIOR_TOGGLE)
			and Ability.GetToggleState(ability) and mana < maxMana * 0.2 then
			if bestScore < 50 then best, bestScore = {ability = ability, kind = "toggle"}, 50 end
			return
		end
		if not ready(ctx, ability, isItem) then return end
		local name = Ability.GetName(ability)
		if isItem and managedItems[name] then return end
		if (ctx.abilityAttempts[name] or 0) > ctx.now then return end
		local record = isItem and ctx.catalog.items[name:gsub("^item_", "")] or nil
		local effect = isItem and record and record.effects or ctx.catalog.abilities[name] or {}
		local flags = Ability.GetBehavior(ability)
		if effect.unsafe or has(flags, behavior.DOTA_ABILITY_BEHAVIOR_VECTOR_TARGETING)
			or has(flags, behavior.DOTA_ABILITY_BEHAVIOR_RUNE_TARGET)
			or has(flags, behavior.DOTA_ABILITY_BEHAVIOR_FREE_DRAW_TARGETING) then return end
		local level = Ability.GetLevel(ability)
		local radius = ctx.planner.levelValue(effect.radius, level)
		local frontOffset = ctx.planner.levelValue(effect.frontOffset, level)
		local damage = math.max(Ability.GetDamage(ability), ctx.planner.levelValue(effect.damage, level))
		local range = Ability.GetCastRange(ability)
		local cost = Ability.GetManaCost(ability)

		local kv = (isItem and itemKV or abilityKV)[name]
		local values = kv and kv.AbilityValues
		local healthCost = kv and kvNumber(kv.AbilityHealthCost or type(values) == "table" and values.AbilityHealthCost, level) or 0
		if not isItem and ctx.heroModule and ctx.heroModule.spellDamage and ctx.target
			and Entity.IsEntity(ctx.target) and Entity.IsAlive(ctx.target) then
			local customDamage, customCost = ctx.heroModule.spellDamage(ctx, ability, ctx.target)
			if customDamage then damage, healthCost = customDamage, customCost end
		end
		if healthCost > 0 and Entity.GetHealth(ctx.hero) - healthCost < Entity.GetMaxHealth(ctx.hero) * 0.3 then return end
		local urgent = retreat or ctx.target and NPC.IsChannellingAbility(ctx.target)
		if not urgent and mana - cost < maxMana * ctx.settings.manaReserve / 100 then return end
		local kind = has(flags, behavior.DOTA_ABILITY_BEHAVIOR_UNIT_TARGET) and "target"
			or has(flags, behavior.DOTA_ABILITY_BEHAVIOR_POINT) and "point"
			or has(flags, behavior.DOTA_ABILITY_BEHAVIOR_NO_TARGET) and "none" or nil
		if not kind then return end
		if has(flags, behavior.DOTA_ABILITY_BEHAVIOR_AUTOCAST)
			and Ability.GetTargetTeam(ability) == targetTeam.DOTA_UNIT_TARGET_TEAM_ENEMY then
			local desired = ctx.target ~= nil and not retreat
			if desired ~= Ability.GetAutoCastState(ability) and bestScore < 8 then
				best, bestScore = {ability = ability, kind = "autocast"}, 8
			end
			return
		end
		local target, position, score = nil, nil, 0
		if effect.unitMobility and retreat and kind == "target" and not NPC.HasState(ctx.hero, modifier.MODIFIER_STATE_ROOTED) then
			for _, list in ipairs({ctx.allies, ctx.creeps}) do
				for _, ally in ipairs(list) do
					if ally ~= ctx.hero and Entity.IsEntity(ally) and Entity.IsAlive(ally) and Entity.IsSameTeam(ally, ctx.hero) then
						local destination = Entity.GetAbsOrigin(ally)
						if ctx.distance(ctx.position, destination) <= range and allowed(ctx, ability, ally)
							and ctx.distance(destination, ctx.home) < ctx.distance(ctx.position, ctx.home) - 450
							and not ctx.unsafePosition(destination) then target, score = ally, 95; break end
					end
				end
			end
		elseif effect.mobility and retreat and kind == "point" and not NPC.HasState(ctx.hero, modifier.MODIFIER_STATE_ROOTED) then
			position = ctx.toward(ctx.position, ctx.home, math.min(range * 0.85, 1000))
			if GridNav.IsTraversable(position) and not ctx.unsafePosition(position) then score = 95 end
		elseif effect.heal or effect.save then
			for _, ally in ipairs(ctx.allies) do
				if Entity.IsEntity(ally) and Entity.IsAlive(ally) then
					local health = Entity.GetHealth(ally) / math.max(1, Entity.GetMaxHealth(ally))
					local distance = ctx.distance(ctx.position, Entity.GetAbsOrigin(ally))
					local legal = kind == "target" and distance <= range and allowed(ctx, ability, ally)
						or kind ~= "target" and (ally == ctx.hero or radius > 0 and distance < radius)
					if legal and health < (effect.heal and 0.68 or 0.45) then
						local value = (1 - health) * 100 + (ally == ctx.hero and retreat and 30 or 0)
						if value > score then target, position, score = ally, Entity.GetAbsOrigin(ally), value end
					end
				end
			end
		end
		if isItem and effect.heal and NPC.GetHealthRegen(ctx.hero) > 12 then score = 0 end
		local reactive = retreat and effect.disable and not effect.mobility and not effect.unitMobility
		if score == 0 and ctx.target and (not retreat or reactive) and spellPolicy.allow(ctx, ability, ctx.target)
			and Entity.IsEntity(ctx.target) and Entity.IsAlive(ctx.target) and not Entity.IsDormant(ctx.target) and NPC.IsVisible(ctx.target) then
			local enemy = ctx.target
			local distance = ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy))
			local offensive = damage > 0 or effect.disable or effect.summon or effect.buff or effect.steal
			local legal = kind == "target" and distance <= range and allowed(ctx, ability, enemy) and (offensive or not isItem)
				or kind == "point" and distance <= range and offensive
				or kind == "none" and offensive and (frontOffset > 0 and math.abs(distance - frontOffset) < radius - 35
					or frontOffset == 0 and distance < math.max(radius, effect.buff and NPC.GetAttackRange(ctx.hero) + 100 or 250))
			if legal and not NPC.HasState(enemy, modifier.MODIFIER_STATE_INVULNERABLE)
				and (effect.pierces or not NPC.HasState(enemy, modifier.MODIFIER_STATE_MAGIC_IMMUNE)) then
				score = reactive and 80 or 15 + (effect.disable and 15 or 0) + math.min(25, damage / 20)
				if effect.unitMobility and (ctx.health < 0.6 or ctx.nearEnemies > ctx.nearAllies or ctx.unsafePosition(Entity.GetAbsOrigin(enemy))) then score = 0 end
				if effect.disable and NPC.IsChannellingAbility(enemy) then score = score + 60 end
				if effect.disable and NPC.IsStunned(enemy) then score = 0 end
				if Ability.IsUltimate(ability) and not effect.steal and cost > maxMana * 0.25 and ctx.nearEnemies < 2 and Entity.GetHealth(enemy) > math.max(damage * 2, 500)
					and not reactive and not NPC.IsChannellingAbility(enemy) then score = 0 end
				target = enemy
				local delay = Ability.GetCastPoint(ability)
				local speed = ctx.planner.levelValue(effect.speed, level)
				if speed > 0 then delay = delay + distance / speed end
				position = ctx.predict(enemy, math.min(delay, 0.8))
				if kind == "none" and frontOffset > 0 then
					if math.abs(ctx.distance(ctx.position, position) - frontOffset) > radius - 35 then score = 0
					elseif not geometry.frontHit(ctx.position, Entity.GetRotation(ctx.hero):GetForward(), position, frontOffset, radius) then
						if retreat then score = 0 else kind = "face" end
					end
				end
				if kind == "none" and frontOffset == 0 and Ability.IsUltimate(ability) and delay > 1
					and ctx.distance(ctx.position, position) > radius * 0.55 then score = 0 end
				if kind == "point" and ctx.distance(ctx.position, position) > range then score = 0 end
			end
		end
		if ctx.role >= 4 and not ctx.target and damage > 0 and (kind == "point" or kind == "none") then
			local center = kind == "point" and position or ctx.position
			if center then
				for _, creep in ipairs(ctx.creeps) do
					if Entity.IsEntity(creep) and Entity.IsAlive(creep) and not Entity.IsSameTeam(creep, ctx.hero)
						and ctx.distance(center, Entity.GetAbsOrigin(creep)) < math.max(radius, 400) then
						score = 0
						break
					end
				end
			end
		end
		if has(flags, behavior.DOTA_ABILITY_BEHAVIOR_TOGGLE) then
			local enabled = Ability.GetToggleState(ability)
			if enabled and (score == 0 or mana < maxMana * 0.2) then
				kind, score = "toggle", 45
			elseif not enabled and score > 0 then kind = "toggle"
			else score = 0 end
		end
		if score > bestScore then
			best, bestScore = {ability = ability, kind = kind, target = target, position = position, offset = frontOffset, radius = radius}, score
		end
	end
	for index = 0, 31 do consider(NPC.GetAbilityByIndex(ctx.hero, index), false) end
	for index = 0, 5 do consider(NPC.GetItemByIndex(ctx.hero, index), true) end
	if best and best.kind == "face" then
		ctx.aimTask = {ability = best.ability, target = best.target, offset = best.offset, radius = best.radius, expires = ctx.now + 0.8, nextTurn = ctx.now}
		return true
	end
	if best then return cast(ctx, best.ability, best.kind, best.target, best.position) end
	return false
end

return combat
