local awareness = {}
local spellPolicy = require("self_play.spell_policy")
local abilityKV = XHelpers.xkv:GetKV("npc_abilities").DOTAAbilities
local itemKV = XHelpers.xkv:GetKV("items").DOTAAbilities

local function number(raw, level)
	if type(raw) == "table" then raw = raw.value end
	if type(raw) == "number" then return raw end
	if type(raw) ~= "string" then return 0 end
	local result, index = 0, 0
	for part in raw:gmatch("%-?%d+%.?%d*") do result, index = tonumber(part), index + 1; if index >= math.max(1, level) then break end end
	return result
end

local function visible(unit)
	return unit and Entity.IsEntity(unit) and Entity.IsAlive(unit) and not Entity.IsDormant(unit) and NPC.IsVisible(unit)
end

local function memoKey(position, horizon)
	return math.floor(position.x / 25) .. ":" .. math.floor(position.y / 25) .. ":" .. math.floor((horizon or 0) * 100)
end

local function memoized(ctx, kind, position, horizon, compute)
	if not ctx.awareMemo or ctx.awareMemo.time ~= ctx.now then ctx.awareMemo = {time = ctx.now, data = {}} end
	local key = kind .. ":" .. memoKey(position, horizon)
	local hit = ctx.awareMemo.data[key]
	if hit then return table.unpack(hit, 1, hit.n) end
	local out = table.pack(compute())
	ctx.awareMemo.data[key] = out
	return table.unpack(out, 1, out.n)
end

function awareness.control(ctx, unit)
	if not ctx.controlEstimates or ctx.controlEstimates.time ~= ctx.now then ctx.controlEstimates = {time = ctx.now, units = {}} end
	local id = Entity.GetIndex(unit)
	local state = ctx.controlEstimates.units[id]
	if not state then
		state = NPC.GetStatesDuration(unit, {[Enum.ModifierState.MODIFIER_STATE_STUNNED] = true,
			[Enum.ModifierState.MODIFIER_STATE_DISARMED] = true, [Enum.ModifierState.MODIFIER_STATE_SILENCED] = true,
			[Enum.ModifierState.MODIFIER_STATE_ROOTED] = true}, true)
		ctx.controlEstimates.units[id] = state
	end
	return state
end

function awareness.burst(ctx, source, target, distance, horizon)
	if source == ctx.hero and ctx.settings.spells == false then return 0, 0, 0 end
	if not ctx.spellEstimates or ctx.spellEstimates.time ~= ctx.now then ctx.spellEstimates = {time = ctx.now, sources = {}} end
	local key = Entity.GetIndex(source) .. ":" .. Entity.GetIndex(target)
	local candidates = ctx.spellEstimates.sources[key]
	local cached = candidates ~= nil
	candidates = candidates or {}
	local control = awareness.control(ctx, source)
	local stun = math.max(0, control[Enum.ModifierState.MODIFIER_STATE_STUNNED] or 0)
	local silence = math.max(0, control[Enum.ModifierState.MODIFIER_STATE_SILENCED] or 0)
	local function consider(ability, item)
		if ability and Ability.GetLevel(ability) > 0 and not Ability.IsHidden(ability) and not Ability.IsPassive(ability)
			and Ability.IsActivated(ability) and Ability.IsReady(ability)
			and (item and Item.IsItemEnabled(ability) and not NPC.HasState(source, Enum.ModifierState.MODIFIER_STATE_MUTED)
				or not item and not spellPolicy.excluded(Ability.GetName(ability)) and (not NPC.IsSilenced(source) or silence > 0)
					and (source ~= ctx.hero or spellPolicy.allow(ctx, ability, target))) then
			local name, level = Ability.GetName(ability), Ability.GetLevel(ability)
			local record = item and ctx.catalog.items[name:gsub("^item_", "")]
			local effect = item and record and record.effects or ctx.catalog.abilities[name] or {}
			local kv = (item and itemKV or abilityKV)[name] or {}
			local amount = math.max(Ability.GetDamage(ability), ctx.planner.levelValue(effect.damage, level))
			local healthCost = number(kv.AbilityHealthCost, level)
			if ctx.heroModule and ctx.heroModule.spellDamage and source == ctx.hero then
				local customDamage, customCost = ctx.heroModule.spellDamage(ctx, ability, target)
				if customDamage then amount, healthCost = customDamage, customCost end
			end
			local damageType = Ability.GetDamageType(ability)
			if damageType == Enum.DamageTypes.DAMAGE_TYPE_MAGICAL then
				amount = amount * NPC.GetMagicalArmorDamageMultiplier(target)
			elseif damageType == Enum.DamageTypes.DAMAGE_TYPE_PHYSICAL then amount = amount * NPC.GetArmorDamageMultiplier(target) end
			local radius = ctx.planner.levelValue(effect.radius, level)
			local reach = math.max(radius, Ability.GetCastRange(ability), 250)
			if amount > 0 and not effect.heal and not effect.save and not effect.unsafe then
				local speed = ctx.planner.levelValue(effect.speed, level)
				local point = Ability.GetCastPoint(ability)
				local channel = number(kv.AbilityChannelTime, level)
				candidates[#candidates + 1] = {damage = amount * (source == ctx.hero and 0.7 or 0.85), cost = Ability.GetManaCost(ability),
					healthCost = healthCost, cooldown = Ability.GetCooldown(ability), duration = point + channel,
					speed = speed, reach = reach, item = item}
			end
		end
	end
	if not cached then
		for index = 0, 31 do consider(NPC.GetAbilityByIndex(source, index), false) end
		for index = 0, 5 do consider(NPC.GetItemByIndex(source, index), true) end
		table.sort(candidates, function(a, b) return a.damage / math.max(0.3, a.duration) > b.damage / math.max(0.3, b.duration) end)
		ctx.spellEstimates.sources[key] = candidates
	end
	local damage, mana, elapsed, healthCost, casting = 0, NPC.GetMana(source), 0, 0, 0
	local reserve = source == ctx.hero and NPC.GetMaxMana(source) * (ctx.settings.manaReserve or 22) / 100 or 0
	for _, spell in ipairs(candidates) do
		local start = math.max(elapsed, spell.cooldown, stun, spell.item and 0 or silence)
		local flight = spell.speed > 0 and distance / spell.speed or 0
		if spell.cost <= mana - reserve and distance < spell.reach + 60 and start + spell.duration + flight < horizon
			and Entity.GetHealth(source) - healthCost - spell.healthCost > Entity.GetMaxHealth(source) * 0.2 then
			damage, mana, elapsed = damage + spell.damage, mana - spell.cost, start + math.max(0.1, spell.duration)
			healthCost, casting = healthCost + spell.healthCost, casting + spell.duration
		end
	end
	return damage, casting, healthCost
end

function awareness.observe(ctx, heroes)
	ctx.fogObservations = ctx.fogObservations or {}
	for _, enemy in ipairs(heroes) do
		if Entity.IsEntity(enemy) and not Entity.IsSameTeam(ctx.hero, enemy) and not NPC.IsIllusion(enemy) then
			local id = Entity.GetIndex(enemy)
			if not Entity.IsAlive(enemy) then ctx.memory[id], ctx.fogObservations[id] = nil, nil
			else
				local seen = visible(enemy)
				local position = seen and Entity.GetAbsOrigin(enemy) or Hero.GetLastMaphackPos(enemy)
				local old = ctx.fogObservations[id]
				local stamp = Hero.GetLastVisibleTime(enemy)
				local changed = position and old and ctx.distance(position, old.position) > 5
				local fresh = seen or changed and not old.visible and ctx.now - old.time < 1
				local time = fresh and ctx.now or stamp
				if position and time and time <= ctx.now and ctx.now - time < 6 then
					local entry = ctx.memory[id]
					if not entry or time > entry.time then
						local speed, vx, vy = NPC.GetMoveSpeed(enemy), 0, 0
						local elapsed = entry and time - entry.time or 0
						if entry and elapsed > 0 and elapsed < 1 then
							local dx, dy = position.x - entry.position.x, position.y - entry.position.y
							if dx * dx + dy * dy <= (speed * elapsed * 1.5 + 24) ^ 2 then
								vx, vy = dx / elapsed, dy / elapsed
								local measured = math.sqrt(vx * vx + vy * vy)
								if measured > speed then vx, vy = vx * speed / measured, vy * speed / measured end
							end
						end
						ctx.memory[id] = {source = enemy, position = position, time = time, vx = vx, vy = vy,
							invisible = NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_INVISIBLE),
							range = NPC.GetAttackRange(enemy) + NPC.GetAttackRangeBonus(enemy), speed = NPC.GetMoveSpeed(enemy),
							dps = NPC.GetTrueDamage(enemy) * NPC.GetArmorDamageMultiplier(ctx.hero) / math.max(0.3, NPC.GetSecondsPerAttack(enemy, false)),
							burst = awareness.burst(ctx, enemy, ctx.hero, 500, 2)}
					end
				end
				if position then ctx.fogObservations[id] = {position = position, time = ctx.now, visible = seen} end
			end
		end
	end
end

function awareness.fogPosition(ctx, enemy)
	if visible(enemy) then return Entity.GetAbsOrigin(enemy), 1 end
	if not enemy or not Entity.IsEntity(enemy) or not Entity.IsAlive(enemy) then return nil, 0 end
	local entry = ctx.memory[Entity.GetIndex(enemy)]
	if not entry then return nil, 0 end
	local age = ctx.now - entry.time
	if age < 0 or age > 2.5 then return nil, 0 end
	if entry.predictedAt and ctx.now - entry.predictedAt < 0.15 then return entry.predicted, entry.confidence end
	local vx, vy = entry.vx or 0, entry.vy or 0
	local speed = math.sqrt(vx * vx + vy * vy)
	local travel = speed * age
	local best, bestScore, bestPath = nil, 0, nil
	local useVision = age > 0.3 and Entity.IsDormant(enemy) and not entry.invisible
		and not NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_INVISIBLE)
	if travel < 24 then
		if not useVision or not FogOfWar.IsPointVisible(entry.position) then best, bestScore = entry.position, 1 end
	else
		for _, angle in ipairs({0, 0.55, -0.55, 1.1, -1.1}) do
			local dx, dy = vx * math.cos(angle) - vy * math.sin(angle), vx * math.sin(angle) + vy * math.cos(angle)
			local endpoint = Vector(entry.position.x + dx * age, entry.position.y + dy * age, entry.position.z)
			if GridNav.IsTraversable(endpoint) then
				local path = GridNav.BuildPath(entry.position, endpoint, false)
				local previous, length, point = entry.position, 0, nil
				for _, node in ipairs(path) do
					local segment = ctx.distance(previous, node)
					if not point and length + segment >= travel then point = ctx.toward(previous, node, travel - length) end
					length, previous = length + segment, node
				end
				point = point or (#path > 0 and previous)
				if point and ctx.distance(point, entry.position) > 20 and (not useVision or not FogOfWar.IsPointVisible(point)) then
					local score = (1 - math.abs(angle) * 0.35) / math.max(1, length / math.max(1, travel))
					if score > bestScore then best, bestScore, bestPath = point, score, path end
				end
			end
		end
	end
	entry.predictedAt, entry.predicted = ctx.now, best
	entry.confidence, entry.predictedPath = math.max(0, 0.9 - age * 0.2) * bestScore, bestPath
	entry.uncertainty = 56 + age * 95
	return best, entry.confidence
end

local function forecastCalc(ctx, position)
	local damage, count, nearest, point, distance = 0, 0, nil, nil, math.huge
	local seen = {}
	for _, arrival in ipairs(ctx.teleportArrivals or {}) do
		local enemy = arrival.source
		local current = ctx.distance(position, arrival.position)
		local alreadyHere = visible(enemy) and ctx.distance(position, Entity.GetAbsOrigin(enemy)) < 1400
		if not alreadyHere and current < 1400 and (arrival.remaining or 0) < 4 then
			seen[Entity.GetIndex(enemy)] = true
			local approach = math.max(0, current - NPC.GetAttackRange(enemy) - NPC.GetAttackRangeBonus(enemy) - 60) / math.max(100, NPC.GetMoveSpeed(enemy))
			local window = math.max(0, 4 - (arrival.remaining or 0) - approach)
			damage = damage + NPC.GetTrueDamage(enemy) * NPC.GetArmorDamageMultiplier(ctx.hero) * window / math.max(0.3, NPC.GetSecondsPerAttack(enemy, false))
				+ awareness.burst(ctx, enemy, ctx.hero, math.max(0, current - 300), math.max(0.1, window))
			count = count + 1
			if current < distance then nearest, point, distance = enemy, arrival.position, current end
		end
	end
	for id, entry in pairs(ctx.memory) do
		local age = ctx.now - entry.time
		if entry.source and Entity.IsEntity(entry.source) and Entity.IsAlive(entry.source) and not visible(entry.source) and not seen[id] and age < 4 then
			local estimate = awareness.fogPosition(ctx, entry.source) or entry.position
			local current = math.max(0, ctx.distance(position, estimate) - math.min(220, age * 95))
			if current < 1200 then
				local approach = math.max(0, current - entry.range - 60) / math.max(100, entry.speed)
				damage = damage + (entry.dps * math.max(0, 2.5 - approach) + entry.burst) * math.max(0.4, 1 - age * 0.15)
				count = count + 1
				if current < distance then nearest, point, distance = entry.source, estimate, current end
			end
		end
	end
	return damage, count, nearest, point, distance
end

function awareness.forecast(ctx, position)
	return memoized(ctx, "f", position, 0, function() return forecastCalc(ctx, position) end)
end

local function damageCalc(ctx, position, horizon)
	local incoming, nearest, nearestDistance = 0, nil, math.huge
	for _, enemy in ipairs(ctx.enemies) do
		if visible(enemy) then
			local distance = ctx.distance(position, Entity.GetAbsOrigin(enemy))
			if distance < nearestDistance then nearest, nearestDistance = enemy, distance end
			local range = NPC.GetAttackRange(enemy) + NPC.GetAttackRangeBonus(enemy)
			local control = awareness.control(ctx, enemy)
			local stun = math.max(0, control[Enum.ModifierState.MODIFIER_STATE_STUNNED] or 0)
			local disarm = math.max(0, control[Enum.ModifierState.MODIFIER_STATE_DISARMED] or 0)
			local root = math.max(0, control[Enum.ModifierState.MODIFIER_STATE_ROOTED] or 0)
			local approach = math.max(0, distance - range - 60) / math.max(100, NPC.GetMoveSpeed(enemy))
			if approach > 0 then approach = approach + root end
			local unavailable = math.max(stun, disarm)
			local cycle = ctx.hits and ctx.hits.cycles and ctx.hits.cycles[Entity.GetIndex(enemy)]
			local attackReady = cycle and math.max(0, cycle.nextStart - ctx.now) or 0
			local active = (not NPC.IsStunned(enemy) or stun > 0) and (not NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_DISARMED) or disarm > 0)
			local spellDamage, casting = 0, 0
			if distance < 1800 and (not NPC.IsStunned(enemy) or stun > 0) then spellDamage, casting = awareness.burst(ctx, enemy, ctx.hero, distance, horizon) end
			if active and approach < horizon then
				local attacks = math.max(0, horizon - math.max(approach, unavailable, attackReady) - casting) / math.max(0.3, NPC.GetSecondsPerAttack(enemy, false))
				if NPC.HasModifier(enemy, "modifier_tinker_laser_blind") then attacks = attacks * 0.15 end
				incoming = incoming + NPC.GetTrueDamage(enemy) * NPC.GetArmorDamageMultiplier(ctx.hero) * attacks
			end
			incoming = incoming + spellDamage
		end
	end
	for _, creep in ipairs(ctx.creeps) do
		if visible(creep) and not Entity.IsSameTeam(ctx.hero, creep) then
			local distance = ctx.distance(position, Entity.GetAbsOrigin(creep))
			if distance < NPC.GetAttackRange(creep) + NPC.GetHullRadius(ctx.hero) + 40 then
				local cycle = ctx.hits and ctx.hits.cycles and ctx.hits.cycles[Entity.GetIndex(creep)]
				local attackReady = cycle and math.max(0, cycle.nextStart - ctx.now) or 0
				local attacks = math.max(0, horizon - attackReady) / math.max(0.3, NPC.GetSecondsPerAttack(creep, false))
				incoming = incoming + NPC.GetTrueDamage(creep) * NPC.GetArmorDamageMultiplier(ctx.hero) * attacks
			end
		end
	end
	return incoming, nearest, nearestDistance
end

function awareness.damage(ctx, position, horizon)
	return memoized(ctx, "d", position, horizon, function() return damageCalc(ctx, position, horizon) end)
end

function awareness.disengageRisk(ctx, position)
	local state = ctx.disengage
	if not state then return 0 end
	local score = 0
	for _, zone in pairs(state.zones) do
		if ctx.now < zone.expires then score = math.max(score, math.max(0, 1 - ctx.distance(position, zone.position) / zone.radius) * 900) end
	end
	return score
end

local function riskCalc(ctx, position)
	local score = awareness.disengageRisk(ctx, position)
	for _, arrival in ipairs(ctx.teleportArrivals or {}) do
		local reach = NPC.GetAttackRange(arrival.source) + NPC.GetAttackRangeBonus(arrival.source) + 350
		score = score + math.max(0, reach - ctx.distance(position, arrival.position)) * 1.2
	end
	for _, enemy in ipairs(ctx.enemies) do
		if visible(enemy) and not NPC.IsStunned(enemy) then
			local reach = NPC.GetAttackRange(enemy) + NPC.GetAttackRangeBonus(enemy) + 160
			local distance = ctx.distance(position, Entity.GetAbsOrigin(enemy))
			local dps = NPC.GetTrueDamage(enemy) * NPC.GetArmorDamageMultiplier(ctx.hero) / math.max(0.3, NPC.GetSecondsPerAttack(enemy, false))
			score = score + math.max(0, reach - distance) * (0.5 + dps / 100)
		end
	end
	for _, entry in pairs(ctx.memory) do
		if entry.source and not visible(entry.source) and ctx.now - entry.time < 4 then
			local reach = entry.range + 220
			local estimate = awareness.fogPosition(ctx, entry.source) or entry.position
			score = score + math.max(0, reach - ctx.distance(position, estimate)) * math.max(0.4, 1 - (ctx.now - entry.time) * 0.15)
		end
	end
	return score
end

function awareness.risk(ctx, position)
	return memoized(ctx, "r", position, 0, function() return riskCalc(ctx, position) end)
end

function awareness.farmSafe(ctx, position, approach)
	if awareness.disengageRisk(ctx, position) > 0 then return false end
	if not ctx.laneThreat then return true end
	if ctx.laneThreat.ambush then return false end
	local risk = awareness.risk(ctx, position)
	if risk < 30 then return true end
	local damage = awareness.damage(ctx, position, math.min(2.5, (approach or 0) + 0.7))
	local budget = math.min(Entity.GetHealth(ctx.hero) * 0.16, Entity.GetMaxHealth(ctx.hero) * 0.09)
	return damage < budget and not ctx.laneThreat.lethal
end

function awareness.moveGoal(ctx, destination)
	local current = awareness.risk(ctx, ctx.position)
	local decision = ctx.combatDecision
	local losing = decision and not decision.safe and not decision.returnFire and not decision.trade and not decision.assist
	local currentDamage = losing and awareness.damage(ctx, ctx.position, 3) or 0
	local length = math.min(900, ctx.distance(ctx.position, destination))
	for step = 90, length, 90 do
		local point = ctx.toward(ctx.position, destination, step)
		local risk = awareness.risk(ctx, point)
		local damage = losing and awareness.damage(ctx, point, 3) or 0
		local closer = losing and visible(decision.target) and ctx.distance(point, Entity.GetAbsOrigin(decision.target))
			< ctx.distance(ctx.position, Entity.GetAbsOrigin(decision.target)) - 30
		if losing and damage > Entity.GetHealth(ctx.hero) * 0.2 and (damage > currentDamage + 15 or closer) then
			return ctx.toward(ctx.position, destination, math.max(0, step - 120)), true
		end
		if risk > 110 and risk > current + 10 and (not ctx.farmCandidate
			or not awareness.farmSafe(ctx, point, step / math.max(100, NPC.GetMoveSpeed(ctx.hero)))) then
			return ctx.toward(ctx.position, destination, math.max(0, step - 120)), true
		end
	end
	return destination, false
end

function awareness.update(ctx)
	local incoming, nearest, distance = awareness.damage(ctx, ctx.position, 3)
	local health = Entity.GetHealth(ctx.hero)
	local futureDamage, futureCount, futureEnemy, futurePosition, futureDistance = awareness.forecast(ctx, ctx.position)
	local visibleCount = 0
	for _, enemy in ipairs(ctx.enemies) do
		if visible(enemy) and ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy)) < 1400 then visibleCount = visibleCount + 1 end
	end
	local ambush = futureCount > 0 and (futureDamage + incoming > health * 0.35 or visibleCount + futureCount > ctx.nearAllies)
	local recent = ctx.heroHarass and ctx.now - ctx.heroHarass.time < 1.8
	local attacker, attackerDistance
	for _, enemy in ipairs(ctx.enemies) do
		if visible(enemy) then
			local current = ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy))
			local attacking = NPC.IsAttacking(enemy) and NPC.FindFacingNPC(enemy, nil, Enum.TeamType.TEAM_ENEMY, 35,
				NPC.GetAttackRange(enemy) + NPC.GetAttackRangeBonus(enemy) + 180) == ctx.hero
			if (attacking or recent and ctx.heroHarass.source == enemy) and (not attackerDistance or current < attackerDistance) then
				attacker, attackerDistance = enemy, current
			end
		end
	end
	if attacker then nearest, distance = attacker, attackerDistance end
	local landing
	for _, arrival in ipairs(ctx.teleportArrivals or {}) do
		local current = ctx.distance(ctx.position, arrival.position)
		if current < 1100 and (not landing or current < landing.distance) then
			landing = {enemy = arrival.source, position = arrival.position, distance = current}
		end
	end
	local reinforcement = landing and (ctx.nearEnemies >= ctx.nearAllies or ctx.health < 0.7 or ambush)
	if reinforcement then nearest, distance = landing.enemy, landing.distance end
	if ambush and not reinforcement then nearest, distance = futureEnemy, futureDistance end
	local range = nearest and NPC.GetAttackRange(nearest) + NPC.GetAttackRangeBonus(nearest) or 0
	local exposed = nearest and distance < range + 160
	ctx.laneThreat = {enemy = nearest, position = reinforcement and landing.position or ambush and futurePosition or nearest and Entity.GetAbsOrigin(nearest),
		distance = distance, incoming = incoming + futureDamage, ambush = ambush, futureCount = futureCount,
		attacked = recent or attacker ~= nil, exposed = exposed,
		lethal = incoming >= health * 0.65 and distance < 1100,
		avoid = exposed and (recent or attacker ~= nil or ctx.health < 0.65 or incoming > health * 0.2)
			or recent and distance < 1100 or reinforcement or ambush}
end

return awareness
