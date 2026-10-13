local units = {}
local common = require("self_play.heroes.common")
local navigation = require("self_play.navigation")
local awareness = require("self_play.awareness")
local policy = require("self_play.spell_policy")

local controls = {centaur_khan_war_stomp = true, dark_troll_warlord_ensnare = true,
	polar_furbolg_ursa_warrior_thunder_clap = true, satyr_trickster_purge = true,
	visage_summon_familiars_stone_form = true, mud_golem_hurl_boulder = true,
	big_thunder_lizard_slam = true, ice_shaman_incendiary_bomb = true}
local buffs = {ogre_magi_frost_armor = "modifier_ogre_magi_frost_armor", big_thunder_lizard_frenzy = "modifier_big_thunder_lizard_frenzy"}
local heals = {forest_troll_high_priest_heal = true}
units.summons = {
	enigma_demonic_conversion = {pattern = "^npc_dota_enigma_eidolon", count = 1},
	terrorblade_conjure_image = {illusion = true, count = 2},
	lycan_summon_wolves = {pattern = "^npc_dota_lycan_wolf", count = 1},
	visage_summon_familiars = {pattern = "^npc_dota_visage_familiar", count = 1},
}

function units.summon(ctx, api)
	if not ctx.settings.spells or ctx.retreating or api.busy(ctx) or ctx.parent then return false end
	if ctx.farmCandidate and ctx.farmCandidate.start < ctx.now + 0.8 then return false end
	local working = ctx.intent and (ctx.intent.kind == "hero" or ctx.intent.kind == "structure")
		or common.visible(ctx.attackTarget) and NPC.IsAttacking(ctx.hero) and not Entity.IsSameTeam(ctx.hero, ctx.attackTarget)
	if not working then return false end
	for name, rule in pairs(units.summons) do
		local spell = NPC.GetAbility(ctx.hero, name)
		if spell and api.ready(ctx, spell, false) and (ctx.abilityAttempts[name] or 0) <= ctx.now
			and NPC.GetMana(ctx.hero) - Ability.GetManaCost(spell) >= NPC.GetMaxMana(ctx.hero) * 0.15 then
			local count = 0
			for _, unit in ipairs(rule.illusion and ctx.worldNPCs or ctx.summons) do
				if common.visible(unit) and Entity.IsSameTeam(ctx.hero, unit) and NPC.IsControllableByPlayer(unit, ctx.playerId) and (rule.illusion and NPC.IsIllusion(unit) and NPC.GetUnitName(unit) == NPC.GetUnitName(ctx.hero)
					or rule.pattern and NPC.GetUnitName(unit):find(rule.pattern)) then count = count + 1 end
			end
			if count < rule.count then
				local flags = Ability.GetBehavior(spell)
				if ctx.planner.hasFlag(flags, Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_NO_TARGET) then return api.cast(ctx, spell, "none") end
				if ctx.planner.hasFlag(flags, Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_POINT) then
					local target = ctx.intent and ctx.intent.target or ctx.attackTarget
					if common.visible(target) then
						local point = ctx.toward(ctx.position, Entity.GetAbsOrigin(target), math.min(250, Ability.GetCastRange(spell)))
						point = navigation.walkable(ctx, point)
						if point and ctx.distance(ctx.position, point) <= Ability.GetCastRange(spell) and not ctx.unsafePosition(point) then return api.cast(ctx, spell, "point", nil, point) end
					end
				end
				local target = ctx.attackTarget
				if common.visible(target) and NPC.IsCreep(target) and not Entity.IsSameTeam(ctx.hero, target)
					and ctx.distance(ctx.position, Entity.GetAbsOrigin(target)) <= Ability.GetCastRange(spell) and api.allowed(ctx, spell, target) then
					return api.cast(ctx, spell, "target", target)
				end
			end
		end
	end
	return false
end

function units.eligible(ctx, unit)
	if unit == ctx.hero or not Entity.IsSameTeam(ctx.hero, unit) or NPC.IsCourier(unit) or NPC.IsWaitingToSpawn(unit) then return false end
	local replica = NPC.IsHero(unit) and Hero.GetReplicatingOtherHeroModel(unit) == ctx.hero
	local double = NPC.GetUnitName(ctx.hero) == "npc_dota_hero_arc_warden" and NPC.GetUnitName(unit) == "npc_dota_hero_arc_warden"
		and NPC.HasModifier(unit, "modifier_arc_warden_tempest_double") and NPC.IsControllableByPlayer(unit, ctx.playerId)
	local manta = NPC.IsIllusion(unit) and NPC.GetUnitName(unit) == NPC.GetUnitName(ctx.hero)
		and NPC.IsControllableByPlayer(unit, ctx.playerId)
	local projection = NPC.HasModifier(unit, "modifier_dazzle_nothl_projection_soul_clone")
	if NPC.IsIllusion(unit) and not manta and not double and not projection and not NPC.IsMeepoClone(unit) then return false end
	if not NPC.IsControllableByPlayer(unit, ctx.playerId) and not replica then return false end
	if NPC.IsHero(unit) and not NPC.IsIllusion(unit) and not NPC.IsMeepoClone(unit) and not replica and not double and not projection then return false end
	if NPC.IsStructure(unit) or NPC.IsWard(unit) then return NPC.GetMoveSpeed(unit) > 0 or NPC.GetTrueDamage(unit) > 0 and NPC.GetAttackRange(unit) > 0 end
	return true
end

local function attackable(ctx, target)
	return common.visible(target) and not Entity.IsSameTeam(ctx.hero, target)
		and not NPC.HasState(target, Enum.ModifierState.MODIFIER_STATE_ATTACK_IMMUNE)
		and not NPC.HasState(target, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE)
		and not NPC.HasState(target, Enum.ModifierState.MODIFIER_STATE_OUT_OF_GAME)
end

local function safe(root, actor, point)
	for _, tower in ipairs(root.towers) do
		if common.visible(tower) and not Entity.IsSameTeam(actor.hero, tower) and root.distance(point, Entity.GetAbsOrigin(tower)) < NPC.GetAttackRange(tower) + 100 then
			local tank = Tower.GetAttackTarget(tower)
			if not common.visible(tank) or tank == actor.hero or Entity.GetHealth(tank) < NPC.GetTrueDamage(tower) * 2 then return false end
		end
	end
	return awareness.damage(actor, point, 1.5) < Entity.GetHealth(actor.hero) * 0.55
end

function units.move(root, actor, destination, label)
	local id = Entity.GetIndex(actor.hero)
	if actor.now < (root.heroState.unitBusy[id] or 0) or actor.now < actor.busyUntil or NPC.IsChannellingAbility(actor.hero) then return true end
	if NPC.GetMoveSpeed(actor.hero) <= 0 then return false end
	local goal = navigation.goal(actor, destination)
	if not goal then return false end
	if actor.distance(actor.position, goal) < 65 then
		if actor.lastOrder ~= "hold" then
			Player.HoldPosition(root.player, actor.hero, false, false, true)
			actor.lastOrder, actor.attackTarget = "hold", false
			root.heroState.unitOrders[id] = nil
		end
		return true
	end
	local old = actor.heroState.moveOrder
	if old and actor.now - old.time < 0.5 and actor.distance(old.goal, goal) < 90 and NPC.IsRunning(actor.hero) then return true end
	NPC.MoveTo(actor.hero, goal, false, false, false, true)
	actor.heroState.moveOrder = {goal = goal, time = actor.now}
	actor.heroState.taskLabel = label
	actor.lastOrder, actor.attackTarget = "move", false
	root.heroState.unitOrders[id] = nil
	return true
end

local function spells(root, actor, api, target, fighting)
	if not root.settings.spells or NPC.IsIllusion(actor.hero) then return false end
	local has = root.planner.hasFlag
	local flags = Enum.AbilityBehavior
	root.unitControl = root.unitControl or {}
	for id, expiry in pairs(root.unitControl) do if expiry <= root.now then root.unitControl[id] = nil end end
	for index = 0, 15 do
		local ability = NPC.GetAbilityByIndex(actor.hero, index)
		if ability and api.ready(actor, ability, false) and not policy.excluded(Ability.GetName(ability))
			and (actor.abilityAttempts[Ability.GetName(ability)] or 0) <= actor.now then
			local name, behavior = Ability.GetName(ability), Ability.GetBehavior(ability)
			local effect = root.catalog.abilities[name] or {}
			local stone = name == "visage_summon_familiars_stone_form"
			local range = Ability.GetCastRange(ability)
			local radius = common.value(ability, stone and "stun_radius" or "radius", root.planner.levelValue(effect.radius, Ability.GetLevel(ability)))
			local damage = math.max(Ability.GetDamage(ability), root.planner.levelValue(effect.damage, Ability.GetLevel(ability)), common.value(ability, "initial_damage", 0), common.value(ability, "damage", 0), common.value(ability, "stun_damage", 0))
			local summons = effect.summon or name == "dark_troll_warlord_raise_dead"
			local control = controls[name] or effect.disable
			local recipient
			if heals[name] or buffs[name] then
				local score = 0
				for _, group in ipairs({root.allies, root.summons}) do
					for _, ally in ipairs(group) do
						if common.visible(ally) and root.distance(actor.position, Entity.GetAbsOrigin(ally)) <= range and api.allowed(actor, ability, ally) then
							local missing = Entity.GetMaxHealth(ally) - Entity.GetHealth(ally)
							local value = heals[name] and missing or NPC.IsAttacking(ally) and 100 or 0
							if buffs[name] and NPC.HasModifier(ally, buffs[name]) then value = 0 end
							if value > score and (not heals[name] or missing > 100) then recipient, score = ally, value end
						end
					end
				end
			end
			if recipient and api.cast(actor, ability, "target", recipient) then return true end
			if stone and actor.health < 0.4 and api.cast(actor, ability, "none") then return true end
			if target and not effect.unsafe and not has(behavior, flags.DOTA_ABILITY_BEHAVIOR_VECTOR_TARGETING)
				and (damage > 0 or control or summons) then
				local id = Entity.GetIndex(target)
				local distance = root.distance(actor.position, Entity.GetAbsOrigin(target))
				local castDelay = Ability.GetCastPoint(ability) + (stone and common.value(ability, "stun_delay", 0.55) or 0)
				local speed = common.value(ability, "speed", common.value(ability, "net_speed", 0))
				if speed > 0 then castDelay = castDelay + distance / speed end
				local point = root.predict(target, castDelay)
				local useful = fighting or not NPC.IsHero(target) and (Entity.GetHealth(target) > damage * 0.7 or summons)
				if control and NPC.IsHero(target) then
					local state = NPC.GetStatesDuration(target, {[Enum.ModifierState.MODIFIER_STATE_STUNNED] = true, [Enum.ModifierState.MODIFIER_STATE_ROOTED] = true}, true)
					useful = useful and math.max(state[Enum.ModifierState.MODIFIER_STATE_STUNNED] or 0, state[Enum.ModifierState.MODIFIER_STATE_ROOTED] or 0) <= castDelay + 0.15
						and (root.unitControl[id] or 0) <= root.now
				end
				local kind = has(behavior, flags.DOTA_ABILITY_BEHAVIOR_UNIT_TARGET) and "target"
					or has(behavior, flags.DOTA_ABILITY_BEHAVIOR_POINT) and "point"
					or has(behavior, flags.DOTA_ABILITY_BEHAVIOR_NO_TARGET) and "none"
				local legal = kind == "target" and distance <= range and api.allowed(actor, ability, target)
					or kind == "point" and root.distance(actor.position, point) <= range
					or kind == "none" and (radius > 0 and root.distance(actor.position, point) < radius - 25 or summons and distance < 750)
				if useful and legal and api.cast(actor, ability, kind, kind == "target" and target or nil, kind == "point" and point or nil) then
					if control then root.unitControl[id] = root.now + castDelay + 0.3 end
					return true
				end
			end
		end
	end
	return false
end

local function farm(root, actor)
	local old = actor.heroState.unitFarmTask
	if old and old.expires > root.now and attackable(actor, old.target) and safe(root, actor, Entity.GetAbsOrigin(old.target)) then return old.target end
	local lifetime = NPC.GetModifier(actor.hero, "modifier_kill")
	local remaining = lifetime and math.max(0, Modifier.GetDieTime(lifetime) - root.now) or 30
	local reach = math.min(4500, math.max(700, (remaining - 5) * NPC.GetMoveSpeed(actor.hero)))
	local best, score
	for _, creep in ipairs(root.worldNPCs) do
		if attackable(actor, creep) and (NPC.IsLaneCreep(creep) or NPC.IsNeutral(creep) and NPC.IsCreep(creep)
			and not NPC.IsRoshan(creep) and not NPC.IsTormentor(creep) and not NPC.IsAncient(creep)) then
			local point = Entity.GetAbsOrigin(creep)
			local distance = root.distance(actor.position, point)
			if distance < reach and safe(root, actor, point) then
				local value = distance + (NPC.IsNeutral(creep) and 500 or 0)
				for _, unit in ipairs(root.summons) do
					local other = root.heroState.actors and root.heroState.actors[Entity.GetIndex(unit)]
					local task = other and other.heroState.unitFarmTask
					if unit ~= actor.hero and task and common.visible(task.target) and root.distance(Entity.GetAbsOrigin(task.target), point) < 650 then value = value + 400 end
				end
				if not score or value < score then best, score = creep, value end
			end
		end
	end
	actor.heroState.unitFarmTask = best and {target = best, expires = root.now + 5} or nil
	return best
end

local function forge(root, actor)
	local state, unit = actor.heroState, actor.hero
	local range = NPC.GetAttackRange(unit) + NPC.GetAttackRangeBonus(unit)
	local function firing(target)
		local point = Entity.GetAbsOrigin(target)
		return root.distance(actor.position, point) <= range and actor.position
			or root.toward(point, actor.position, math.max(60, range - 35))
	end
	local function reachable(target)
		return attackable(actor, target) and root.distance(actor.position, Entity.GetAbsOrigin(target)) < 1600
			and (not Entity.IsAlive(root.hero) or root.distance(root.position, Entity.GetAbsOrigin(target)) < 1500)
			and safe(root, actor, firing(target))
	end
	local endangered = not safe(root, actor, actor.position)
	local target = root.intent and (root.intent.kind == "hero" or root.intent.kind == "structure") and root.intent.target
		or root.fightSession and root.fightSession.target
		or root.lastOrder == "attack" and root.attackTarget or nil
	if not reachable(target) then target = nil end
	if root.retreating or endangered then target, state.forgeTarget = nil, nil end
	if target then state.forgeTarget = {target = target, expires = root.now + 2.5} end
	if not target and state.forgeTarget and root.now < state.forgeTarget.expires and reachable(state.forgeTarget.target) then
		target = state.forgeTarget.target
	end
	if not target and not root.retreating and not endangered then
		local best
		for _, creep in ipairs(root.worldNPCs) do
			if (NPC.IsLaneCreep(creep) or NPC.IsNeutral(creep) and NPC.IsCreep(creep) and not NPC.IsAncient(creep)
				and not NPC.IsRoshan(creep) and not NPC.IsTormentor(creep)) and reachable(creep) then
				local distance = root.distance(actor.position, Entity.GetAbsOrigin(creep))
				local nearHero = not Entity.IsAlive(root.hero) or root.distance(root.position, Entity.GetAbsOrigin(creep)) < 900
				if distance < 1100 and nearHero and (root.clock >= 600 or not Entity.IsAlive(root.hero)) then
					local score = distance + (NPC.IsNeutral(creep) and 450 or 0)
					if not best or score < best then target, best = creep, score end
				end
			end
		end
		if target then state.forgeTarget = {target = target, expires = root.now + 2.5} end
	end
	actor.target = target or false
	state.unitFarmTask = nil
	if target then
		state.taskLabel = NPC.IsHero(target) and "Forge Spirit: focus Invoker opponent"
			or NPC.IsStructure(target) and "Forge Spirit: assist structure push" or "Forge Spirit: assist nearby farm"
		state.travelReason = state.taskLabel
		local point = firing(target)
		if root.distance(actor.position, point) > 40 then return units.move(root, actor, point, state.taskLabel) end
		return common.unitAttack(root, unit, target)
	end
	state.forgeTarget = nil
	actor.retreating = root.retreating or endangered
	local anchor = Entity.IsAlive(root.hero) and root.position or navigation.coverAnchor(actor)
	if actor.retreating or not safe(root, actor, anchor) then anchor = navigation.coverAnchor(actor) end
	local point = root.toward(anchor, root.home, 160)
	state.taskLabel, state.travelReason = "Forge Spirit: stay with Invoker", "Forge Spirit: stay with Invoker"
	if root.distance(actor.position, point) > 100 then return units.move(root, actor, point, state.taskLabel) end
	if actor.lastOrder ~= "hold" then
		Player.HoldPosition(root.player, unit, false, false, true)
		actor.lastOrder, actor.attackTarget = "hold", false
		root.heroState.unitOrders[Entity.GetIndex(unit)] = nil
	end
	return true
end

function units.run(root, api, unit)
	if not units.eligible(root, unit) then return false end
	local actor = common.actor(root, unit)
	local id = Entity.GetIndex(unit)
	if api.busy(actor) or root.now < (root.heroState.unitBusy[id] or 0) or NPC.IsStunned(unit) then return true end
	actor.temporaryUnit, actor.farmCandidate, actor.intent, actor.teamTask, actor.runeTask = true, false, false, false, false
	actor.retreating = false
	actor.unsafePosition = function(point) return not safe(root, actor, point) end
	if NPC.GetUnitName(unit) == "npc_dota_invoker_forged_spirit" then return forge(root, actor) end
	local stationary = NPC.GetMoveSpeed(unit) <= 0 or NPC.IsStructure(unit)
	local target = root.intent and root.intent.kind == "hero" and root.intent.target or nil
	if not attackable(actor, target) or root.distance(actor.position, Entity.GetAbsOrigin(target)) > 1600 then target = nil end
	if not target then
		for _, enemy in ipairs(root.enemies) do
			if attackable(actor, enemy) and root.distance(actor.position, Entity.GetAbsOrigin(enemy)) < 850
				and (NPC.IsAttacking(enemy) or root.intent or root.laneThreat and root.laneThreat.attacked) then target = enemy; break end
		end
	end
	local fighting = target ~= nil
	if target and not safe(root, actor, Entity.GetAbsOrigin(target)) then target = nil; fighting = false end
	local endangered = not safe(root, actor, actor.position)
	if endangered and not stationary then
		actor.retreating = true
		if spells(root, actor, api, target, fighting) then return true end
		return units.move(root, actor, navigation.coverAnchor(actor), "Summon: escape toward allied cover")
	end
	if not target and root.intent and root.intent.kind == "structure" and attackable(actor, root.intent.target)
		and root.distance(actor.position, Entity.GetAbsOrigin(root.intent.target)) < 2000 and safe(root, actor, Entity.GetAbsOrigin(root.intent.target)) then target = root.intent.target end
	if not target and not root.retreating then
		if root.clock < 600 and attackable(actor, root.attackTarget) and not NPC.IsHero(root.attackTarget) and root.lastOrder == "attack" then
			target = root.attackTarget
		elseif root.clock >= 600 or not Entity.IsAlive(root.hero) then target = farm(root, actor) end
	end
	actor.target = target or false
	if target and NPC.IsStructure(target) and NPC.GetTrueDamage(unit) > 0 then
		if common.unitAttack(root, unit, target) then return true end
	end
	if spells(root, actor, api, target, fighting) then return true end
	if NPC.GetTrueDamage(unit) <= 0 then target = nil end
	if target then
		if stationary and root.distance(actor.position, Entity.GetAbsOrigin(target)) > NPC.GetAttackRange(unit) + NPC.GetAttackRangeBonus(unit) then return true end
		if not stationary and root.distance(actor.position, Entity.GetAbsOrigin(target)) > NPC.GetAttackRange(unit) + NPC.GetAttackRangeBonus(unit) + 80 then
			return units.move(root, actor, root.toward(Entity.GetAbsOrigin(target), actor.position, math.max(60, NPC.GetAttackRange(unit) - 30)), "Summon: approach assigned target")
		end
		return common.unitAttack(root, unit, target)
	end
	if stationary then return true end
	local anchor = Entity.IsAlive(root.hero) and root.position or navigation.coverAnchor(actor)
	local angle = id * 2.399963
	local point = Vector(anchor.x + math.cos(angle) * 180, anchor.y + math.sin(angle) * 180, anchor.z)
	return units.move(root, actor, point, "Summon: regroup with space for other units")
end

return units
