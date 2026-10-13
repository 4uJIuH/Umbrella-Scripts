local farming = {}
local common = require("self_play.heroes.common")
local awareness = require("self_play.awareness")
local navigation = require("self_play.navigation")
local farmMarch = require("self_play.heroes.tinker_march")
local taskPolicy = require("self_play.task_policy")

local function creep(ctx, unit)
	return common.visible(unit) and Entity.IsNPC(unit) and NPC.IsCreep(unit) and not Entity.IsSameTeam(ctx.hero, unit)
		and not NPC.IsAncient(unit) and not NPC.IsRoshan(unit) and not NPC.IsTormentor(unit) and not NPC.IsWaitingToSpawn(unit)
		and not NPC.HasState(unit, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE)
		and not NPC.HasState(unit, Enum.ModifierState.MODIFIER_STATE_OUT_OF_GAME)
end

function farming.safe(ctx, point)
	if ctx.unsafePosition(point) then return false end
	for _, enemy in ipairs(ctx.enemies) do
		if common.visible(enemy) and ctx.distance(point, Entity.GetAbsOrigin(enemy)) < 1250 then return false end
	end
	for _, memory in pairs(ctx.memory) do
		if ctx.now - memory.time < 6 and ctx.distance(point, memory.position) < 1350 then return false end
	end
	for _, arrival in ipairs(ctx.teleportArrivals or {}) do
		if ctx.distance(point, arrival.position) < 1500 then return false end
	end
	return awareness.damage(ctx, point, 3) + awareness.forecast(ctx, point) < Entity.GetHealth(ctx.hero) * 0.18
end

function farming.territory(ctx, point, camp)
	if NPC.GetCurrentLevel(ctx.hero) >= 12 and ctx.clock >= 900 then return true end
	if not camp then
		local distance = 800
		local camps = JungleCampsManager and JungleCampsManager.camps or {}
		for _, candidate in pairs(camps) do
			local current = ctx.distance(point, candidate.position_)
			if current < distance then camp, distance = candidate, current end
		end
	end
	if camp and (camp.team_ == 2 or camp.team_ == 3) then return camp.team_ == Entity.GetTeamNum(ctx.hero) end
	return ctx.distance(point, ctx.home) <= ctx.distance(point, ctx.enemyHome) + 600
end

function farming.coverage(ctx, origin, center, units)
	local march = NPC.GetAbility(ctx.hero, "tinker_march_of_the_machines")
	if not march or ctx.distance(origin, center) < 50 then return 0 end
	local position = ctx.toward(origin, center, math.max(1, Ability.GetCastRange(march) - 15))
	local zone = farmMarch.geometry(setmetatable({position = origin}, {__index = ctx}), march, position)
	local count = 0
	for _, unit in ipairs(units) do
		if farmMarch.arrival(zone, Entity.GetAbsOrigin(unit)) then count = count + 1 end
	end
	return count
end

function farming.castPosition(ctx, target, range)
	local best, bestScore
	for _, radius in ipairs({500, 700}) do
		for index = 0, 11 do
			local angle = index * math.pi / 6
			local x, y = target.point.x + math.cos(angle) * radius, target.point.y + math.sin(angle) * radius
			local point = Vector(x, y, World.GetGroundZ(x, y))
			local distance = ctx.distance(ctx.position, point)
			if distance <= range and GridNav.IsTraversable(point) then
				local coverage = farming.coverage(ctx, point, target.point, target.units)
				local clearance = math.huge
				for _, unit in ipairs(target.units) do clearance = math.min(clearance, ctx.distance(point, Entity.GetAbsOrigin(unit))) end
				if clearance >= 350 and coverage >= math.max(3, #target.units - 1) and farming.safe(ctx, point) then
					local score = coverage * 300 - distance * 0.15 - ctx.distance(point, ctx.home) * 0.025
					if not bestScore or score > bestScore then best, bestScore = point, score end
				end
			end
		end
	end
	return best
end

function farming.blink(ctx, api, destination, target)
	if ctx.settings.items == false or ctx.now < (ctx.heroState.nextFarmBlink or 0) then return false end
	local blink
	for _, name in ipairs({"item_blink", "item_arcane_blink", "item_overwhelming_blink", "item_swift_blink"}) do
		blink = common.ability(ctx, api, name)
		if blink then break end
	end
	if not blink then return false end
	ctx.heroState.nextFarmBlink = ctx.now + 0.4
	local range = Ability.GetCastRange(blink) - 40
	local distance = ctx.distance(ctx.position, destination)
	local currentCoverage = target and farming.coverage(ctx, ctx.position, target.point, target.units) or 0
	local point = target and distance < range + 700 and farming.castPosition(ctx, target, range) or nil
	if point and distance < 850 and farming.coverage(ctx, point, target.point, target.units) <= currentCoverage + 1 then return false end
	if not point then
		if distance < 1000 then return false end
		for _, fraction in ipairs({1, 0.8, 0.6}) do
			local candidate = ctx.toward(ctx.position, destination, math.min(range * fraction, distance - 500))
			if GridNav.IsTraversable(candidate) and farming.safe(ctx, candidate) then point = candidate; break end
		end
	end
	if not point or ctx.distance(ctx.position, point) < 350 then return false end
	if distance - ctx.distance(point, destination) < 250 and (not target
		or farming.coverage(ctx, point, target.point, target.units) < currentCoverage + 2) then return false end
	if not api.cast(ctx, blink, "point", nil, point) then return false end
	ctx.heroState.nextFarmBlink = ctx.now + 1
	ctx.attackTarget, ctx.hits.ordered = nil, nil
	ctx.mode = target and target.paired and "Tinker: blink to cover two camps" or "Tinker: blink along farming route"
	return true
end

function farming.budget(ctx, group)
	local march = NPC.GetAbility(ctx.hero, "tinker_march_of_the_machines")
	local ultimate = NPC.GetAbility(ctx.hero, "tinker_rearm")
	local health, gold = 0, 0
	for _, unit in ipairs(group.units) do
		health = math.max(health, Entity.GetHealth(unit) / math.max(0.1, NPC.GetMagicalArmorDamageMultiplier(unit)))
		gold = gold + NPC.GetGoldBountyMax(unit)
	end
	local duration = march and common.value(march, "duration", 6) or 6
	local damage = march and math.max(1, farmMarch.rate(march) * duration * 2) or 1
	local casts = math.min(3, math.max(1, math.ceil(health / damage)))
	local channel = ultimate and common.value(ultimate, "AbilityChannelTime", 2.75) or 2.75
	local cost = casts * (march and Ability.GetManaCost(march) or 0) + (casts - 1) * (ultimate and Ability.GetManaCost(ultimate) or 0)
	return {casts = casts, mana = cost + 100, seconds = casts * 0.65 + (casts - 1) * channel + 4, gold = gold}
end

function farming.destination(ctx, state)
	local groups = {}
	for _, unit in ipairs(ctx.worldNPCs) do
		if creep(ctx, unit) then
			local point = Entity.GetAbsOrigin(unit)
			local neutral = NPC.IsNeutral(unit)
			local group
			for _, existing in ipairs(groups) do
				if existing.neutral == neutral and ctx.distance(existing.point, point) < 550 then group = existing; break end
			end
			if not group then group = {point = point, neutral = neutral, units = {}, health = 0}; groups[#groups + 1] = group end
			group.units[#group.units + 1], group.health = unit, group.health + Entity.GetHealth(unit)
		end
	end
	local camps = JungleCampsManager and JungleCampsManager.camps or {}
	for _, camp in pairs(camps) do
		local represented = false
		for _, group in ipairs(groups) do
			if group.neutral and ctx.distance(group.point, camp.position_) < 650 then represented = true; break end
		end
		if not represented and not camp.is_farmed_ and farming.territory(ctx, camp.position_, camp) and farming.safe(ctx, camp.position_) then
			local group = {point = camp.position_, neutral = true, camp = camp, units = {}, health = 0}
			for _, record in pairs(camp.creeps_alive) do
				local unit = Entity.Get(record.index_)
				if unit and Entity.IsNPC(unit) and Entity.IsAlive(unit) and NPC.IsNeutral(unit) and not NPC.IsAncient(unit)
					and not Entity.IsSameTeam(ctx.hero, unit) then
					group.units[#group.units + 1], group.health = unit, group.health + Entity.GetHealth(unit)
				end
			end
			if #group.units > 0 then groups[#groups + 1] = group end
		end
	end
	local march = NPC.GetAbility(ctx.hero, "tinker_march_of_the_machines")
	if march and Ability.GetLevel(march) >= 2 and NPC.GetMana(ctx.hero) >= Ability.GetManaCost(march) + 250 then
		local singles = #groups
		for i = 1, singles do
			local a = groups[i]
			if a.neutral and #a.units >= 2 and farming.territory(ctx, a.point, a.camp) then
				for j = i + 1, singles do
					local b = groups[j]
					local separation = ctx.distance(a.point, b.point)
					if b.neutral and #b.units >= 2 and #a.units + #b.units <= 10 and separation >= 550 and separation <= 1100
						and farming.territory(ctx, b.point, b.camp) and farming.safe(ctx, a.point) and farming.safe(ctx, b.point) then
						local units = {}
						for _, unit in ipairs(a.units) do units[#units + 1] = unit end
						for _, unit in ipairs(b.units) do units[#units + 1] = unit end
						local point = Vector((a.point.x + b.point.x) / 2, (a.point.y + b.point.y) / 2, a.point.z)
						groups[#groups + 1] = {point = point, neutral = true, paired = true, units = units,
							health = a.health + b.health, centers = {a.point, b.point}}
					end
				end
			end
		end
	end
	local candidates = {}
	for _, group in ipairs(groups) do
		local blocked = false
		for _, area in ipairs(state.excluded) do
			if area.expires > ctx.now then
				for _, point in ipairs(group.centers or {group.point}) do
					if ctx.distance(point, area.point) < area.radius then blocked = true; break end
				end
			end
			if blocked then break end
		end
		local distance = ctx.distance(ctx.position, group.point)
		local finishing = state.target and ctx.distance(ctx.position, group.point) < 900
			and ctx.distance(state.target.point, group.point) < 600
		if not blocked and (not group.neutral or farming.territory(ctx, group.point, group.camp))
			and #group.units >= (group.neutral and not finishing and 2 or 1) and farming.safe(ctx, group.point) then
			local pressure = 0
			if group.neutral then
				for _, unit in ipairs(group.units) do pressure = pressure + NPC.GetTrueDamage(unit) / math.max(0.3, NPC.GetSecondsPerAttack(unit, false)) end
			end
			if not group.neutral or pressure * NPC.GetArmorDamageMultiplier(ctx.hero) * 4 < Entity.GetHealth(ctx.hero) * 0.55 then
				group.budget = farming.budget(ctx, group)
				local baseScore = group.budget.gold / (group.budget.seconds + distance / math.max(100, NPC.GetMoveSpeed(ctx.hero)))
				local score = baseScore
				if state.target and ctx.distance(state.target.point, group.point) < 550 then score = score * (finishing and 1.5 or 1.15) end
				for _, ally in ipairs(ctx.allies) do
					if ally ~= ctx.hero and common.visible(ally) and NPC.IsAttacking(ally)
						and ctx.distance(Entity.GetAbsOrigin(ally), group.point) < 700 then score = score * 0.35 end
				end
				group.score, group.preference = score, score / math.max(0.001, baseScore)
				candidates[#candidates + 1] = group
			end
		end
	end
	table.sort(candidates, function(a, b) return a.score > b.score end)
	local ability = NPC.GetAbility(ctx.hero, "tinker_keen_teleport")
	local best, bestScore
	for index = 1, math.min(4, #candidates) do
		local group = candidates[index]
		local goal
		if group.paired then goal = farming.castPosition(ctx, group, math.huge)
		else goal = group.camp and group.point or ctx.toward(group.point, ctx.position, 450) end
		group.castPoint = group.paired and goal or nil
		local length = goal and navigation.safePath(ctx, goal, 40)
		local travel = length and length / math.max(100, NPC.GetMoveSpeed(ctx.hero)) or math.huge
		if goal and ctx.settings.teleport ~= false and ability and Ability.GetLevel(ability) > 0 then
			local landing, remainder = farming.landing(ctx, goal, ability)
			if landing then
				local ultimate = NPC.GetAbility(ctx.hero, "tinker_rearm")
				local wait = Ability.GetCooldown(ability)
				if ultimate and Ability.GetLevel(ultimate) > 0 then
					wait = math.min(wait, Ability.GetCooldown(ultimate) + common.value(ultimate, "AbilityChannelTime", 2.75))
				end
				travel = math.min(travel, wait + common.value(ability, "AbilityChannelTime", 3) + (remainder or 0) / math.max(100, NPC.GetMoveSpeed(ctx.hero)))
			end
		end
		if travel < 20 then
			local score = group.budget.gold / (group.budget.seconds + travel) * group.preference
			if group.budget.mana > NPC.GetMana(ctx.hero) then score = score * 0.65 end
			if not bestScore or score > bestScore then best, bestScore, group.travelSeconds = group, score, travel end
		else state.excluded[#state.excluded + 1] = {point = group.point, radius = 600, expires = ctx.now + 12} end
	end
	return best
end

function farming.landing(ctx, destination, ability)
	local candidates = {}
	local level = Ability.GetLevel(ability)
	local function consider(unit)
		if unit == ctx.hero or not common.visible(unit) or not Entity.IsNPC(unit) or not Entity.IsSameTeam(ctx.hero, unit) then return end
		if not (NPC.IsStructure(unit) or level >= 2 and NPC.IsLaneCreep(unit) or level >= 3 and NPC.IsHero(unit)) then return end
		if not NPC.IsStructure(unit) and Entity.GetHealth(unit) < Entity.GetMaxHealth(unit) * 0.6 then return end
		local point = Entity.GetAbsOrigin(unit)
		local distance = ctx.distance(point, destination)
		if distance < 5000 and farming.safe(ctx, point) then candidates[#candidates + 1] = {point = point, distance = distance} end
	end
	if ctx.distance(destination, ctx.home) < 400 then return ctx.home end
	for _, unit in ipairs(ctx.structures) do consider(unit) end
	if level >= 2 then for _, unit in ipairs(ctx.worldNPCs) do if Entity.IsNPC(unit) and NPC.IsLaneCreep(unit) then consider(unit) end end end
	if level >= 3 then for _, unit in ipairs(ctx.allies) do consider(unit) end end
	table.sort(candidates, function(a, b) return a.distance < b.distance end)
	local best, bestLength
	for index = 1, math.min(4, #candidates) do
		local candidate = candidates[index]
		local arrival = setmetatable({position = candidate.point}, {__index = ctx})
		local length = navigation.safePath(arrival, destination, 35)
		if length and (not bestLength or length < bestLength) then best, bestLength = candidate.point, length end
	end
	return best, bestLength
end

local function rearm(ctx, api, profile)
	local ability = NPC.GetAbility(ctx.hero, "tinker_rearm")
	local teleport = NPC.GetAbility(ctx.hero, "tinker_keen_teleport")
	if not ability or not teleport or not api.ready(ctx, ability, false) or (ctx.abilityAttempts.tinker_rearm or 0) > ctx.now then return false end
	local duration = common.value(ability, "AbilityChannelTime", 2.75)
	if Ability.GetCooldown(teleport) <= duration + 0.7 or NPC.GetMana(ctx.hero) < Ability.GetManaCost(ability) + Ability.GetManaCost(teleport)
		or not profile.canChannel(ctx, duration) then return false end
	if not api.cast(ctx, ability, "none") then return false end
	ctx.heroState.rearm = {ability = ability, started = ctx.now, ends = ctx.now + duration}
	ctx.mode = "Tinker: Rearm for next teleport"
	return true
end

function farming.travel(ctx, api, profile, destination, recovering)
	if ctx.settings.teleport == false then return false end
	local ability = profile.travelAbility(ctx)
	if not ability or ctx.now < (ctx.heroState.nextKeen or 0) then return false end
	if not recovering then
		local march = NPC.GetAbility(ctx.hero, "tinker_march_of_the_machines")
		local ultimate = NPC.GetAbility(ctx.hero, "tinker_rearm")
		local budget = Ability.GetManaCost(ability) + (march and Ability.GetManaCost(march) or 0)
			+ (ultimate and Ability.GetManaCost(ultimate) or 0) + 75
		if NPC.GetMana(ctx.hero) < budget then return false end
	end
	local previous = ctx.heroState.farmTravelCheck
	if previous and ctx.now < previous.expires and ctx.distance(previous.goal, destination) < 200 then return false end
	ctx.heroState.farmTravelCheck = {goal = destination, expires = ctx.now + 0.5}
	local landing, remainder = farming.landing(ctx, destination, ability)
	if not landing then return false end
	local length = navigation.safePath(ctx, destination, 40)
	local distance = length or ctx.distance(ctx.position, destination) * 1.5
	local gain = distance - (remainder or ctx.distance(landing, destination))
	local channel = common.value(ability, "AbilityChannelTime", 3)
	if ctx.distance(ctx.position, landing) < 1000 or gain / math.max(100, NPC.GetMoveSpeed(ctx.hero)) < channel + 1.5 then return false end
	if not profile.canTeleport(ctx, 3) or ctx.unsafePosition(ctx.position) then return false end
	if not api.cast(ctx, ability, "point", nil, landing) then return false end
	ctx.teleportOrder = {started = ctx.now, ability = ability}
	ctx.heroState.nextKeen = ctx.now + 1
	ctx.attackTarget, ctx.hits.ordered = nil, nil
	ctx.mode = recovering and "Tinker: teleport to fountain" or "Tinker: teleport to farm"
	return true
end

local function reachFarm(ctx, api, profile, target)
	if farming.travel(ctx, api, profile, target.point, false) then return true end
	local teleport = NPC.GetAbility(ctx.hero, "tinker_keen_teleport")
	if ctx.settings.teleport ~= false and teleport and Ability.GetLevel(teleport) > 0 and Ability.GetCooldown(teleport) > 3.5
		and ctx.now >= (ctx.heroState.nextFarmRearmCheck or 0)
		and ctx.distance(ctx.position, target.point) > 2400 then
		ctx.heroState.nextFarmRearmCheck = ctx.now + 0.5
		local landing = farming.landing(ctx, target.point, teleport)
		if landing and ctx.distance(ctx.position, target.point) - ctx.distance(landing, target.point) > 1800
			and rearm(ctx, api, profile) then return true end
	end
	return farming.blink(ctx, api, target.point, target)
end

local function clearLane(ctx)
	ctx.farmCandidate, ctx.aggroTask, ctx.spacingTask, ctx.regroupTask = nil, nil, nil, nil
	ctx.waveFallback, ctx.waveBlocked, ctx.jungleState = nil, nil, nil
	ctx.campTask, ctx.runeTask, ctx.riverTask = nil, nil, nil
end

function farming.run(ctx, api, profile)
	local ultimate = NPC.GetAbility(ctx.hero, "tinker_rearm")
	if ctx.role > 3 or NPC.GetCurrentLevel(ctx.hero) < 6 or not ultimate or Ability.GetLevel(ultimate) == 0 then return false end
	local state = ctx.heroState.farmCycle
	local fountain = ctx.distance(ctx.position, ctx.home) < 1000 and NPC.HasModifier(ctx.hero, "modifier_fountain_aura_buff")
	if taskPolicy.farmBlocked(ctx) then return false end
	if not state then state = {phase = "farm", excluded = {}, nextPlan = 0}; ctx.heroState.farmCycle = state end
	for i = #state.excluded, 1, -1 do if state.excluded[i].expires <= ctx.now then table.remove(state.excluded, i) end end
	local mana, maximum = NPC.GetMana(ctx.hero), NPC.GetMaxMana(ctx.hero)
	local march = NPC.GetAbility(ctx.hero, "tinker_march_of_the_machines")
	local cycleCost = Ability.GetManaCost(ultimate) + (march and Ability.GetManaCost(march) or 150) + 100
	local poorMana = mana < math.min(maximum * 0.6, cycleCost) and mana + math.max(0, NPC.GetManaRegen(ctx.hero)) * 15 < cycleCost
	local poorHealth = ctx.health < 0.72 and Entity.GetHealth(ctx.hero) + math.max(0, NPC.GetHealthRegen(ctx.hero)) * 15 < Entity.GetMaxHealth(ctx.hero) * 0.82
	local contested = ctx.hardRetreat or ctx.laneThreat and (ctx.laneThreat.avoid or ctx.laneThreat.ambush)
		or state.target and (not farming.safe(ctx, state.target.point)
			or state.target.neutral and not farming.territory(ctx, state.target.point, state.target.camp))
	if contested then
		if ctx.now >= (state.nextExclude or 0) then
			state.excluded[#state.excluded + 1] = {point = state.target and state.target.point or ctx.position, radius = 1500, expires = ctx.now + 25}
			state.nextExclude = ctx.now + 5
		end
		state.target, state.nextPlan = nil, 0
		if poorHealth or poorMana then state.phase = "recover" end
	end
	if poorMana or poorHealth or fountain and (mana < maximum * 0.9 or ctx.health < 0.9) then state.phase = "recover" end
	if state.phase == "recover" then
		clearLane(ctx)
		ctx.intent = nil
		if fountain then
			ctx.retreating, ctx.recovering, ctx.recoveryTask, ctx.disengage = false, false, nil, nil
			if rearm(ctx, api, profile) then return true end
			if mana < maximum * 0.9 or ctx.health < 0.9 then ctx.mode = "Tinker: refill health and mana"; ctx.stop(); return true end
			state.phase, state.target, state.nextPlan = "farm", nil, 0
		elseif farming.travel(ctx, api, profile, ctx.home, true) or rearm(ctx, api, profile) then return true
		else
			local point = navigation.escape(ctx, ctx.home)
			if farming.blink(ctx, api, ctx.home) then ctx.mode = "Tinker: blink toward fountain cover"; return true end
			return ctx.move(point or ctx.home, "Tinker: reach cover for fountain teleport", 60)
		end
	end
	if ctx.retreating or ctx.hardRetreat then return false end
	if state.target then
		local alive = false
		for _, unit in ipairs(state.target.units) do
			if Entity.IsEntity(unit) and Entity.IsAlive(unit) then alive = true; break end
		end
		if not alive or state.target.camp and state.target.camp.is_farmed_ then state.target, state.nextPlan = nil, 0 end
	end
	if ctx.now >= state.nextPlan and (not state.target or state.target.expires and ctx.now >= state.target.expires) then
		local selected = farming.destination(ctx, state)
		if selected then
			state.progressPosition = nil
			selected.expires = ctx.now + math.min(45, (selected.travelSeconds or 10) + selected.budget.seconds + 10)
		end
		state.target, state.nextPlan = selected, ctx.now + 0.7
	end
	local target = state.target
	if not target then
		if poorMana or poorHealth then state.phase = "recover"; return farming.run(ctx, api, profile) end
		return false
	end
	if target.budget and (target.travelSeconds or 0) > 2 and mana < maximum * 0.85
		and mana + math.max(0, NPC.GetManaRegen(ctx.hero)) * (target.travelSeconds or 0) < target.budget.mana then
		state.phase = "recover"
		return farming.run(ctx, api, profile)
	end
	clearLane(ctx)
	ctx.intent = nil
	local live, health, nearest, nearestDistance = {}, 0, nil, math.huge
	for _, unit in ipairs(target.units) do
		if creep(ctx, unit) then
			live[#live + 1], health = unit, health + Entity.GetHealth(unit)
			local distance = ctx.distance(ctx.position, Entity.GetAbsOrigin(unit))
			if distance < nearestDistance then nearest, nearestDistance = unit, distance end
		end
	end
	local remainingDistance = ctx.distance(ctx.position, target.point)
	if not state.progressPosition or remainingDistance < (state.progressDistance or math.huge) - 100 or health < (state.progressHealth or math.huge) - 5
		or state.progressHealth == 0 and health > 0 then
		state.progressPosition, state.progressHealth, state.progressAt, state.progressDistance = ctx.position, health, ctx.now, remainingDistance
	end
	if ctx.now - state.progressAt > 5 then
		state.excluded[#state.excluded + 1] = {point = target.point, radius = 650, expires = ctx.now + 15}
		state.target, state.nextPlan, state.progressPosition = nil, 0, nil
		return true
	end
	if not nearest and (target.camp and not target.camp.is_farmed_ or target.paired) and ctx.distance(ctx.position, target.point) > 350 then
		if reachFarm(ctx, api, profile, target) then return true end
		return ctx.move(target.point, "Tinker: approach occupied jungle camp", 100)
	end
	if not nearest then
		state.excluded[#state.excluded + 1] = {point = target.point, radius = 650, expires = ctx.now + 20}
		state.target, state.nextPlan = nil, 0
		return false
	end
	if not target.paired then target.units, target.point = live, Entity.GetAbsOrigin(nearest) end
	if reachFarm(ctx, api, profile, target) then return true end
	if nearestDistance < 1300 and profile.farm(ctx, api) then return true end
	if target.paired and target.castPoint and farming.coverage(ctx, ctx.position, target.point, live) < math.max(3, #live - 1)
		and ctx.distance(ctx.position, target.castPoint) > 100 then
		return ctx.move(target.castPoint, "Tinker: line up March across camps", 60)
	end
	local range = NPC.GetAttackRange(ctx.hero) + NPC.GetAttackRangeBonus(ctx.hero)
	if nearestDistance <= range then return ctx.attack(nearest, "Tinker: finish farming pack") end
	local point = ctx.toward(target.point, ctx.position, math.min(500, range - 30))
	return ctx.move(point, target.neutral and "Tinker: move to jungle pack" or "Tinker: move to free wave", 40)
end

return farming
