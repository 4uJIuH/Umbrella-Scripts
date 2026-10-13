local common = {}
local spellPolicy = require("self_play.spell_policy")
local activeItems = require("self_play.active_items")
local navigation = require("self_play.navigation")

local abilityKV = XHelpers.xkv:GetKV("npc_abilities").DOTAAbilities
local itemKV = XHelpers.xkv:GetKV("items").DOTAAbilities

function common.visible(unit)
	return unit and Entity.IsEntity(unit) and Entity.IsAlive(unit) and not Entity.IsDormant(unit) and NPC.IsVisible(unit)
end

function common.enemy(ctx, range)
	local target = ctx.target
	if not common.visible(target) or Entity.IsSameTeam(ctx.hero, target)
		or NPC.HasState(target, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE)
		or NPC.HasState(target, Enum.ModifierState.MODIFIER_STATE_OUT_OF_GAME)
		or ctx.distance(ctx.position, Entity.GetAbsOrigin(target)) > range then return nil end
	return target
end

function common.ability(ctx, api, name)
	local item = name:find("^item_") ~= nil
	local ability = item and NPC.GetItem(ctx.hero, name, true) or NPC.GetAbility(ctx.hero, name)
	if ability and (ctx.abilityAttempts[name] or 0) <= ctx.now and api.ready(ctx, ability, item)
		and spellPolicy.allow(ctx, ability, ctx.target) then return ability end
	return nil
end

function common.cast(ctx, api, ability, kind, target, position)
	if kind == "target" and (not common.visible(target) or not api.allowed(ctx, ability, target)
		or ctx.distance(ctx.position, Entity.GetAbsOrigin(target)) > Ability.GetCastRange(ability)) then return false end
	return api.cast(ctx, ability, kind, target, position)
end

function common.value(ability, key, fallback, valueLevel)
	local name = Ability.GetName(ability)
	local kv = (name:find("^item_") and itemKV or abilityKV)[name]
	local value = kv and kv.AbilityValues and kv.AbilityValues[key]
	if type(value) == "table" then value = value.value end
	if type(value) == "number" then return value end
	if type(value) ~= "string" then return fallback end
	local result, index = fallback, 0
	for number in value:gmatch("%-?%d+%.?%d*") do
		result, index = tonumber(number), index + 1
		if index >= math.max(1, valueLevel or Ability.GetLevel(ability)) then break end
	end
	return result
end

function common.remaining(modifier, now)
	return math.max(0, Modifier.GetDieTime(modifier) - now)
end

function common.face(ctx, target, label)
	local destination = ctx.predict(target, 0.15)
	if ctx.unsafePosition(ctx.toward(ctx.position, destination, 35)) then return false end
	if ctx.now >= (ctx.heroState.nextFace or 0) then
		NPC.MoveTo(ctx.hero, ctx.toward(ctx.position, destination, 35), false, false, false, true)
		ctx.heroState.nextFace = ctx.now + 0.1
	end
	ctx.mode, ctx.lastOrder = label, "face"
	return true
end

function common.unitTarget(ctx, unit)
	local origin = Entity.GetAbsOrigin(unit)
	local heroTarget, score = nil, math.huge
	for _, enemy in ipairs(ctx.enemies) do
		if common.visible(enemy) and not NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE)
			and not ctx.unsafePosition(Entity.GetAbsOrigin(enemy)) then
			local distance = ctx.distance(origin, Entity.GetAbsOrigin(enemy))
			local value = distance + Entity.GetHealth(enemy) * 0.1 - (enemy == ctx.target and 150 or 0)
			if distance < 1400 and value < score then heroTarget, score = enemy, value end
		end
	end
	if heroTarget then return heroTarget end
	if ctx.intent and ctx.intent.kind == "structure" and common.visible(ctx.intent.target) and ctx.pushSafe(ctx.intent.target) then return ctx.intent.target end
	local best, distance = nil, 1000
	for _, creep in ipairs(ctx.worldNPCs or ctx.creeps) do
		if common.visible(creep) and not Entity.IsSameTeam(ctx.hero, creep)
			and (NPC.IsLaneCreep(creep) or NPC.IsNeutral(creep) and NPC.IsCreep(creep) and not NPC.IsAncient(creep)
				and not NPC.IsRoshan(creep) and not NPC.IsTormentor(creep))
			and not ctx.unsafePosition(Entity.GetAbsOrigin(creep)) then
			local current = ctx.distance(Entity.GetAbsOrigin(unit), Entity.GetAbsOrigin(creep))
			if current < distance then best, distance = creep, current end
		end
	end
	return best
end

function common.unitCast(ctx, api, unit, name, kind, target, position)
	local id = Entity.GetIndex(unit)
	if ctx.now < (ctx.heroState.unitBusy[id] or 0) or NPC.IsChannellingAbility(unit) then return true end
	local isItem = name:find("^item_") ~= nil
	local ability = isItem and NPC.GetItem(unit, name, true) or NPC.GetAbility(unit, name)
	if not ability or not api.ready({hero = unit}, ability, isItem) then return false end
	if kind == "target" then
		if not common.visible(target) or ctx.distance(Entity.GetAbsOrigin(unit), Entity.GetAbsOrigin(target)) > Ability.GetCastRange(ability) then return false end
		if not api.allowed({hero = unit, planner = ctx.planner, catalog = ctx.catalog}, ability, target) then return false end
	elseif kind == "point" then
		if ctx.distance(Entity.GetAbsOrigin(unit), position) > Ability.GetCastRange(ability) then return false end
	end
	local order = kind == "target" and Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TARGET
		or kind == "point" and Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION or Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET
	Player.PrepareUnitOrders(ctx.player, order, target, position or Vector(0, 0, 0), ability,
		Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, unit, false, false, false, true, "self_play_unit_cast", false)
	ctx.heroState.unitBusy[id] = ctx.now + Ability.GetCastPoint(ability) + 0.2
	ctx.heroState.unitOrders[id] = nil
	return true
end

function common.actor(ctx, unit)
	local id = Entity.GetIndex(unit)
	ctx.heroState.actors = ctx.heroState.actors or {}
	local actor = ctx.heroState.actors[id]
	if not actor then
		actor = setmetatable({hero = unit, parent = ctx, busyUntil = 0, attackNext = 0, abilityAttempts = {},
			heroState = {unitOrders = {}, unitBusy = {}}, hits = {blocked = {}}, intent = false,
			spellSpending = {}, lastOrder = false, lastAbility = "none", attackTarget = false}, {__index = ctx})
		ctx.heroState.actors[id] = actor
		actor.attack = function(target) return common.unitAttack(ctx, unit, target) end
		actor.move = function(position)
			if actor.now < actor.busyUntil or actor.now < (ctx.heroState.unitBusy[id] or 0) or NPC.IsChannellingAbility(unit) then return true end
			local goal = navigation.goal(actor, position)
			if not goal then return false end
			local previous = actor.heroState.moveOrder
			if previous and actor.now - previous.time < 0.4 and actor.distance(previous.goal, goal) < 80 and NPC.IsRunning(unit) then return true end
			NPC.MoveTo(unit, goal, false, false, false, true)
			actor.heroState.moveOrder = {goal = goal, time = actor.now}
			ctx.heroState.unitOrders[id] = nil
			return true
		end
		actor.stop = function() Player.HoldPosition(ctx.player, unit, false, false, true); return true end
	end
	actor.now, actor.position = ctx.now, Entity.GetAbsOrigin(unit)
	actor.health = Entity.GetHealth(unit) / math.max(1, Entity.GetMaxHealth(unit))
	actor.target = common.unitTarget(ctx, unit) or false
	return actor
end

function common.vector(ctx, api, ability, origin, direction)
	Player.PrepareUnitOrders(ctx.player, Enum.UnitOrder.DOTA_UNIT_ORDER_VECTOR_TARGET_POSITION, nil, direction, ability,
		Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, ctx.hero, false, false, false, true, "self_play_vector", false)
	return api.cast(ctx, ability, "point", nil, origin)
end

function common.items(ctx, api, enemy, retreat)
	if activeItems.run(ctx, api, false) then return true end
	if not common.visible(enemy) or not NPC.IsHero(enemy) then return false end
	for _, name in ipairs({"item_sheepstick", "item_abyssal_blade", "item_bloodthorn", "item_orchid", "item_gungir", "item_rod_of_atos"}) do
		local item = common.ability(ctx, api, name)
		local silence = name == "item_bloodthorn" or name == "item_orchid"
		if item and not NPC.IsStunned(enemy) and not NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_ROOTED)
			and not (silence and NPC.IsSilenced(enemy)) then
			if name == "item_gungir" then
				local point = ctx.predict(enemy, 0.25)
				if ctx.distance(ctx.position, point) <= Ability.GetCastRange(item) then return api.cast(ctx, item, "point", nil, point) end
			elseif common.cast(ctx, api, item, "target", enemy) then return true end
		end
	end
	local mjollnir = common.ability(ctx, api, "item_mjollnir")
	if mjollnir and NPC.IsAttacking(ctx.hero) and Hero.GetRecentDamage(ctx.hero) > 0 then return common.cast(ctx, api, mjollnir, "target", ctx.hero) end
	return false
end

function common.unitAttack(ctx, unit, target)
	local id = Entity.GetIndex(unit)
	if ctx.now < (ctx.heroState.unitBusy[id] or 0) or NPC.IsChannellingAbility(unit) then return true end
	if not common.visible(target) or NPC.HasState(target, Enum.ModifierState.MODIFIER_STATE_ATTACK_IMMUNE)
		or NPC.HasState(target, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE) then return false end
	local order = ctx.heroState.unitOrders[id]
	if order and order.target == target then
		local acknowledged = NPC.IsAttacking(unit) and NPC.FindFacingNPC(unit, nil, Enum.TeamType.TEAM_ENEMY, 25,
			NPC.GetAttackRange(unit) + NPC.GetHullRadius(target) + 100) == target
		local advancing = NPC.IsRunning(unit) and order.position and ctx.distance(order.position, Entity.GetAbsOrigin(unit)) > 40
		if acknowledged or ctx.now - order.time < 0.45 or advancing and ctx.now - order.time < 1.2 then return true end
	end
	Player.AttackTarget(ctx.player, unit, target, false, false, true, "self_play_hero_unit", false)
	ctx.heroState.unitOrders[id] = {target = target, time = ctx.now, position = Entity.GetAbsOrigin(unit)}
	local actor = ctx.heroState.actors and ctx.heroState.actors[id]
	if actor then actor.attackTarget, actor.lastOrder = target, "attack" end
	if NPC.IsEntityInRange(unit, target, NPC.GetAttackRange(unit) + NPC.GetAttackRangeBonus(unit)) then
		local point = NPC.GetAttackAnimPoint(unit)
		if point then ctx.heroState.unitBusy[id] = ctx.now + point / math.max(0.1, NPC.GetAttackSpeed(unit)) + 0.05 end
	end
	return true
end

return common
