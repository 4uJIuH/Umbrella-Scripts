local tinker = {reserved = {tinker_rearm = true, tinker_keen_teleport = true, tinker_laser = true,
	tinker_deploy_turrets = true, tinker_march_of_the_machines = true,
	item_blink = true, item_overwhelming_blink = true, item_arcane_blink = true, item_swift_blink = true}}
local common = require("self_play.heroes.common")
local awareness = require("self_play.awareness")
local spellPolicy = require("self_play.spell_policy")
local farming = require("self_play.heroes.tinker_farming")
local farmMarch = require("self_play.heroes.tinker_march")

local function ready(ctx, api, name)
	local ability = NPC.GetAbility(ctx.hero, name)
	if ability and api.ready(ctx, ability, false) and (ctx.abilityAttempts[name] or 0) <= ctx.now then return ability end
	return nil
end

local function blinkItem(ctx, api)
	for _, name in ipairs({"item_blink", "item_arcane_blink", "item_overwhelming_blink", "item_swift_blink"}) do
		local item = common.ability(ctx, api, name)
		if item then return item end
	end
	return nil
end

local function cover(ctx, target, blink, range)
	local center = Entity.GetAbsOrigin(target)
	local best, bestScore
	for radius = math.max(280, range - 150), range - 40, 110 do
		for index = 0, 11 do
			local angle = index * math.pi / 6
			local x, y = center.x + math.cos(angle) * radius, center.y + math.sin(angle) * radius
			local point = Vector(x, y, World.GetGroundZ(x, y))
			local travel = ctx.distance(ctx.position, point)
			if travel > 220 and travel < Ability.GetCastRange(blink) - 40 and GridNav.IsTraversable(point)
				and not ctx.unsafePosition(point) then
				local incoming = awareness.damage(ctx, point, 1.5)
				local risk = awareness.risk(ctx, point)
				if incoming < Entity.GetHealth(ctx.hero) * 0.27 then
					local trees = #Trees.InRadius(point, 220, true)
					local score = risk * 2 + travel * 0.1 + ctx.distance(point, ctx.home) * 0.04 - math.min(5, trees) * 18
					if not bestScore or score < bestScore then best, bestScore = point, score end
				end
			end
		end
	end
	return best
end

local function channelSafe(ctx, seconds, escaping)
	if not escaping and (ctx.hardRetreat or ctx.health < 0.38) or (ctx.creepPressure or 0) >= 3 then return false end
	local damage = awareness.damage(ctx, ctx.position, seconds)
	if damage > Entity.GetHealth(ctx.hero) * 0.35 then return false end
	for _, enemy in ipairs(ctx.enemies) do
		if common.visible(enemy) and not NPC.IsStunned(enemy) and not NPC.IsSilenced(enemy) then
			local distance = ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy))
			for index = 0, 7 do
				local ability = NPC.GetAbilityByIndex(enemy, index)
				local effect = ability and ctx.catalog.abilities[Ability.GetName(ability)]
				if effect and effect.disable and Ability.GetLevel(ability) > 0 and not Ability.IsHidden(ability)
					and Ability.GetCooldown(ability) < seconds and NPC.GetMana(enemy) >= Ability.GetManaCost(ability)
					and distance < math.max(350, Ability.GetCastRange(ability)) + 100 and NPC.IsVisibleToEnemies(ctx.hero) then return false end
			end
		end
	end
	return true
end

function tinker.duringCast(ctx)
	local state = ctx.heroState.rearm
	if not state then
		local ability = NPC.GetAbility(ctx.hero, "tinker_rearm")
		if not ability or not Ability.IsChannelling(ability) then return false end
		local started = Ability.GetChannelStartTime(ability)
		state = {ability = ability, started = started, ends = started + common.value(ability, "AbilityChannelTime", 2.75)}
		ctx.heroState.rearm = state
	end
	if Ability.IsChannelling(state.ability) then
		if not state.seen then
			local started = Ability.GetChannelStartTime(state.ability)
			if started > 0 then state.ends = started + common.value(state.ability, "AbilityChannelTime", 2.75) end
		end
		state.seen, state.lastActive = true, ctx.now
		local remaining = math.max(0.1, state.ends - ctx.now)
		local damage = awareness.damage(ctx, ctx.position, remaining)
		if damage >= Entity.GetHealth(ctx.hero) * 0.85 or ctx.hardRetreat and remaining > 0.45 then
			ctx.heroState.rearm = nil
			ctx.stop()
			ctx.mode = "Tinker: cancel Rearm to escape lethal danger"
			return true
		end
		ctx.mode = "Tinker: completing rearm cycle"
		return true
	end
	if state.seen and ctx.now - state.lastActive < 0.15 or not state.seen
		and ctx.now < state.started + math.max(0.45, NetChannel.GetAvgLatency(Enum.Flow.FLOW_OUTGOING) * 2 + 0.2) then return true end
	ctx.heroState.rearm = nil
	return false
end

local function farmUnits(ctx)
	local units, seen = {}, {}
	local task = ctx.jungleState and ctx.jungleState.task
	local cycle = ctx.heroState.farmCycle
	local assigned = cycle and cycle.target and cycle.target.units
	local function add(unit)
		if not common.visible(unit) or not NPC.IsCreep(unit) or Entity.IsSameTeam(ctx.hero, unit)
			or NPC.IsRoshan(unit) or NPC.IsTormentor(unit) or NPC.IsWaitingToSpawn(unit)
			or NPC.HasState(unit, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE)
			or NPC.HasState(unit, Enum.ModifierState.MODIFIER_STATE_OUT_OF_GAME) then return end
		local id, point = Entity.GetIndex(unit), Entity.GetAbsOrigin(unit)
		if seen[id] or ctx.distance(ctx.position, point) > 1300 then return end
		if NPC.IsNeutral(unit) and not (assigned and table.find(assigned, unit) or task and (task.members[id] or ctx.distance(point, task.origin) < 500)) then return end
		if ctx.unsafePosition(point) then return end
		seen[id], units[#units + 1] = true, unit
	end
	for _, unit in ipairs(ctx.creeps) do add(unit) end
	if task then for _, unit in ipairs(ctx.neutrals) do add(unit) end end
	if assigned then for _, unit in ipairs(assigned) do add(unit) end end
	return units
end

local function farmPack(ctx, units)
	local cycle = ctx.heroState.farmCycle
	local target = cycle and cycle.target
	if target and target.paired and #units >= 4 then
		if farming.coverage(ctx, ctx.position, target.point, units) < #units - 1 then return nil end
		local health = 0
		for _, unit in ipairs(units) do health = health + Entity.GetHealth(unit) end
		return {units = units, point = target.point, health = health, paired = true}
	end
	local best, bestScore
	for _, anchor in ipairs(units) do
		local center, group, health, x, y = Entity.GetAbsOrigin(anchor), {}, 0, 0, 0
		for _, unit in ipairs(units) do
			local point = Entity.GetAbsOrigin(unit)
			if ctx.distance(center, point) <= 350 then
				group[#group + 1], health = unit, health + Entity.GetHealth(unit)
				x, y = x + point.x, y + point.y
			end
		end
		local point = Vector(x / #group, y / #group, center.z)
		local score = #group * 180 + math.min(1800, health) * 0.15 - ctx.distance(ctx.position, point) * 0.25
		if not bestScore or score > bestScore then best, bestScore = {units = group, point = point, health = health}, score end
	end
	return best
end

local function pruneZones(ctx)
	local zones = ctx.heroState.farmZones or {}
	for index = #zones, 1, -1 do
		local zone = zones[index]
		if zone.expires <= ctx.now then table.remove(zones, index) end
	end
	ctx.heroState.farmZones = zones
end

local function farmReserve(ctx)
	local teleport = NPC.GetAbility(ctx.hero, "tinker_keen_teleport")
	return math.max(NPC.GetMaxMana(ctx.hero) * 0.2, teleport and Ability.GetManaCost(teleport) + 50 or 100)
end

function tinker.farmReady(ctx)
	local march = NPC.GetAbility(ctx.hero, "tinker_march_of_the_machines")
	local rearm = NPC.GetAbility(ctx.hero, "tinker_rearm")
	return ctx.settings.spells and ctx.role <= 3 and NPC.GetCurrentLevel(ctx.hero) >= 6 and march and Ability.GetLevel(march) >= 2
		and rearm and Ability.GetLevel(rearm) > 0 and NPC.GetMana(ctx.hero) >= Ability.GetManaCost(march) + farmReserve(ctx)
end

function tinker.travelAbility(ctx)
	local ability = NPC.GetAbility(ctx.hero, "tinker_keen_teleport")
	if ctx.settings.spells and ability and Ability.GetLevel(ability) > 0 and Ability.CanBeExecuted(ability) == -1
		and Ability.IsReady(ability) and Ability.IsCastable(ability, NPC.GetMana(ctx.hero)) then return ability end
	return nil
end

function tinker.jungleDamage(ctx, units)
	if not tinker.farmReady(ctx) then return nil end
	local march = NPC.GetAbility(ctx.hero, "tinker_march_of_the_machines")
	if Ability.GetCooldown(march) > 0 or #units < 3 then return nil end
	local damage, total = {}, 0
	local duration = common.value(march, "duration", 6)
	local rate = common.value(march, "machines_per_sec", 24) * common.value(march, "collision_radius", 50)
		/ math.max(1, common.value(march, "radius", 900)) * 0.7
	local pulse = common.value(march, "damage", 0) * rate * duration
	for _, unit in ipairs(units) do
		if NPC.IsAncient(unit) then return nil end
		damage[Entity.GetIndex(unit)] = math.min(Entity.GetHealth(unit) * 0.65, pulse * NPC.GetMagicalArmorDamageMultiplier(unit))
		total = total + damage[Entity.GetIndex(unit)]
	end
	if total < Ability.GetManaCost(march) * 1.5 then return nil end
	return damage, duration + Ability.GetCastPoint(march)
end

function tinker.farm(ctx, api)
	if ctx.role > 3 or ctx.retreating or ctx.hardRetreat or ctx.nearEnemies > 0 or ctx.intent or ctx.fightSession
		or ctx.baseDefense or ctx.runeTask or ctx.riverTask or ctx.objectiveTask or ctx.campTask
		or ctx.teamTask and (ctx.teamTask.fighting or ctx.teamTask.kind == "push" or ctx.teamTask.kind == "roshan") then return false end
	if NPC.GetCurrentLevel(ctx.hero) < 5 then return false end
	local candidate = ctx.farmCandidate
	if candidate and candidate.start <= ctx.now + 0.75 then return false end
	if ctx.heroState.farmThink == ctx.now then return false end
	ctx.heroState.farmThink = ctx.now
	local pack = farmPack(ctx, farmUnits(ctx))
	if not pack then return false end
	local mana, reserve, damage = NPC.GetMana(ctx.hero), farmReserve(ctx), NPC.GetTrueDamage(ctx.hero)
	local distance = ctx.distance(ctx.position, pack.point)
	local march = ready(ctx, api, "tinker_march_of_the_machines")
	pruneZones(ctx)
	local learnedMarch = NPC.GetAbility(ctx.hero, "tinker_march_of_the_machines")
	local remaining, attackSeconds, durable = 0, 0, 0
	for _, unit in ipairs(pack.units) do
		local health = math.max(0, Entity.GetHealth(unit) - farmMarch.pending(ctx, learnedMarch, unit))
		remaining = remaining + health
		attackSeconds = attackSeconds + health / math.max(1, damage * NPC.GetArmorDamageMultiplier(unit)) * NPC.GetSecondsPerAttack(ctx.hero, false)
		if health > damage * NPC.GetArmorDamageMultiplier(unit) * 1.5 then durable = durable + 1 end
	end
	local marchUseful = (#pack.units >= 2 and durable >= 2 or #pack.units == 1 and remaining > math.max(500, damage * 6))
		and remaining > damage * #pack.units * 2
	if march and marchUseful
		and distance < 850 and mana - Ability.GetManaCost(march) >= reserve then
		local plan = farmMarch.plan(ctx, march, pack.units, pack.point)
		if plan and plan.hits >= math.max(1, #pack.units - 1) and api.cast(ctx, march, "point", nil, plan.point) then
			farmMarch.record(ctx, plan)
			ctx.mode = pack.paired and "Tinker: March across two camps" or "Tinker: March through creep pack"
			return true
		end
	end
	local laser = ready(ctx, api, "tinker_laser")
	if laser and mana - Ability.GetManaCost(laser) >= reserve then
		local target, score
		local burst = common.value(laser, "laser_damage", 0)
		for _, unit in ipairs(pack.units) do
			local health = math.max(0, Entity.GetHealth(unit) - farmMarch.pending(ctx, learnedMarch, unit))
			local attacks = health / math.max(1, damage * NPC.GetArmorDamageMultiplier(unit))
			if ctx.distance(ctx.position, Entity.GetAbsOrigin(unit)) <= Ability.GetCastRange(laser) and api.allowed(ctx, laser, unit)
				and (attacks >= 2 or health <= burst and attacks > 1.25) then
				local value = math.min(burst, health) + (NPC.IsAttacking(unit) and NPC.FindFacingNPC(unit) == ctx.hero and 100 or 0)
				if not score or value > score then target, score = unit, value end
			end
		end
		if target then ctx.mode = "Tinker: Laser the durable creep"; return api.cast(ctx, laser, "target", target) end
	end
	local turret = ready(ctx, api, "tinker_deploy_turrets")
	local learnedTurret = NPC.GetAbility(ctx.hero, "tinker_deploy_turrets")
	local impact = 0
	if learnedTurret then
		for _, unit in ipairs(pack.units) do
			if ctx.distance(Entity.GetAbsOrigin(unit), pack.point) < common.value(learnedTurret, "drop_aoe_radius", 250) then
				impact = impact + math.min(math.max(0, Entity.GetHealth(unit) - farmMarch.pending(ctx, learnedMarch, unit)),
					common.value(learnedTurret, "drop_damage", 0) * NPC.GetMagicalArmorDamageMultiplier(unit))
			end
		end
	end
	local turretUseful = learnedTurret and impact >= Ability.GetManaCost(learnedTurret) * 1.2 and attackSeconds > 2
	if turret and turretUseful and distance < Ability.GetCastRange(turret)
		and mana - Ability.GetManaCost(turret) >= reserve then
		if api.cast(ctx, turret, "point", nil, pack.point) then
			ctx.mode = "Tinker: turret impact clears creeps"
			return true
		end
	end
	local rearm = ready(ctx, api, "tinker_rearm")
	if rearm and durable > 0 then
		local channel = common.value(rearm, "AbilityChannelTime", 2.75)
		local nextCost = math.huge
		for _, name in ipairs({"tinker_march_of_the_machines", "tinker_laser", "tinker_deploy_turrets"}) do
			local ability = NPC.GetAbility(ctx.hero, name)
			local useful = name == "tinker_march_of_the_machines" and marchUseful and distance < 850
				or name == "tinker_laser" and distance < 600 and remaining > damage * 2
				or name == "tinker_deploy_turrets" and turretUseful and distance < 600
			if useful and ability and Ability.GetLevel(ability) > 0 and Ability.GetCooldown(ability) > channel + 0.7 then
				nextCost = math.min(nextCost, Ability.GetManaCost(ability))
			end
		end
		if attackSeconds > channel + 1 and mana - Ability.GetManaCost(rearm) - nextCost >= reserve and channelSafe(ctx, channel) then
			if api.cast(ctx, rearm, "none") then
				ctx.heroState.rearm = {ability = rearm, started = ctx.now, ends = ctx.now + channel}
				ctx.mode = "Tinker: Rearm to finish farming"
				return true
			end
		end
	end
	if distance > 850 and #pack.units >= 3 then return farming.blink(ctx, api, pack.point, pack) end
	return false
end

function tinker.canChannel(ctx, seconds)
	return channelSafe(ctx, seconds)
end

function tinker.farmTerritory(ctx, point)
	return farming.territory(ctx, point)
end

function tinker.canTeleport(ctx, seconds)
	return channelSafe(ctx, seconds, true)
end

function tinker.strategy(ctx, api)
	return farming.run(ctx, api, tinker)
end

function tinker.opportunity(ctx, api)
	return tinker.farm(ctx, api)
end

function tinker.update(ctx, api, retreat)
	local state, target = ctx.heroState, common.enemy(ctx, 1600)
	local teleport = ready(ctx, api, "tinker_keen_teleport")
	if retreat and teleport and ctx.recovering and ctx.nearEnemies == 0 and Hero.GetRecentDamage(ctx.hero) == 0
		and ctx.distance(ctx.position, ctx.home) > 3500 then
		ctx.mode = "Tinker: teleport to recover"
		return api.cast(ctx, teleport, "point", nil, ctx.home)
	end
	if common.items(ctx, api, target, retreat) then return true end
	local laser = common.ability(ctx, api, "tinker_laser")
	local blink = blinkItem(ctx, api)
	if retreat then
		if blink and ctx.nearEnemies > 0 then
			local point = ctx.toward(ctx.position, ctx.home, math.min(1100, Ability.GetCastRange(blink) - 40))
			if GridNav.IsTraversable(point) and not ctx.unsafePosition(point) then return api.cast(ctx, blink, "point", nil, point) end
		end
		if laser and target and common.cast(ctx, api, laser, "target", target) then return true end
		return false
	end
	if not target and tinker.farm(ctx, api) then return true end
	local distance = target and ctx.distance(ctx.position, Entity.GetAbsOrigin(target)) or math.huge
	if blink and laser and target and ctx.health >= 0.6 and ctx.nearEnemies <= ctx.nearAllies
		and ctx.now >= (state.nextBlink or 0) and distance > Ability.GetCastRange(laser) - 50
		and (ctx.intent and ctx.intent.target == target or Entity.GetHealth(target) < common.value(laser, "laser_damage", 0)) then
		local point = cover(ctx, target, blink, Ability.GetCastRange(laser))
		if point then
			state.nextBlink = ctx.now + 2
			ctx.mode = "Tinker: blink to casting cover"
			return api.cast(ctx, blink, "point", nil, point)
		end
	end
	if laser and target and common.cast(ctx, api, laser, "target", target) then
		ctx.mode = "Tinker: laser pressure"
		return true
	end
	local turret = common.ability(ctx, api, "tinker_deploy_turrets")
	if turret and target and distance < Ability.GetCastRange(turret) + 100 then
		local point = ctx.predict(target, Ability.GetCastPoint(turret) + common.value(turret, "drop_delay", 0.5))
		point = ctx.toward(ctx.position, point, Ability.GetCastRange(turret) - 15)
		if ctx.distance(point, ctx.predict(target, 1.2)) < common.value(turret, "missile_target_range", 650) - 100 then
			ctx.mode = "Tinker: turrets cover enemy path"
			return api.cast(ctx, turret, "point", nil, point)
		end
	end
	local march = common.ability(ctx, api, "tinker_march_of_the_machines")
	local fighting = target and distance < 800 and (NPC.IsStunned(target) or NPC.IsAttacking(target)
		or ctx.intent and ctx.intent.target == target)
	if march and ctx.now >= (state.marchUntil or 0) and fighting then
		local aim = ctx.predict(target, 0.6)
		local point = ctx.toward(ctx.position, aim, math.max(0, Ability.GetCastRange(march) - 20))
		if not ctx.unsafePosition(point) and NPC.GetMana(ctx.hero) - Ability.GetManaCost(march) >= NPC.GetMaxMana(ctx.hero) * 0.25 then
			state.marchUntil = ctx.now + common.value(march, "duration", 6) * 0.8
			ctx.mode = "Tinker: march across active fight or wave"
			return api.cast(ctx, march, "point", nil, point)
		end
	end
	local rearm = ready(ctx, api, "tinker_rearm")
	if not rearm then return false end
	local channel = common.value(rearm, "AbilityChannelTime", 2.75)
	local cooling, nextCost = 0, math.huge
	for _, name in ipairs({"tinker_laser", "tinker_deploy_turrets", "tinker_march_of_the_machines"}) do
		local ability = NPC.GetAbility(ctx.hero, name)
		local useful = name == "tinker_laser" and target and distance < 1200
			or name == "tinker_deploy_turrets" and target and distance < 1000
			or name == "tinker_march_of_the_machines" and fighting and ctx.now >= (state.marchUntil or 0)
		if useful and ability and Ability.GetLevel(ability) > 0 and Ability.GetCooldown(ability) > channel + 0.7
			and spellPolicy.allow(ctx, ability, target) then
			cooling, nextCost = cooling + 1, math.min(nextCost, Ability.GetManaCost(ability))
		end
	end
	if cooling > 0 and NPC.GetMana(ctx.hero) - Ability.GetManaCost(rearm) >= nextCost + 75 then
		if channelSafe(ctx, channel) then
			if api.cast(ctx, rearm, "none") then
				state.rearm = {ability = rearm, started = ctx.now, ends = ctx.now + channel}
				ctx.mode = "Tinker: rearm for next useful spell"
				return true
			end
		elseif blink and target then
			local point = cover(ctx, target, blink, 1000)
			if point then ctx.mode = "Tinker: reposition before rearm"; return api.cast(ctx, blink, "point", nil, point) end
		end
	end
	return false
end

return tinker
