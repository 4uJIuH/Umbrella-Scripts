local roshan = {}
local abilityKV = XHelpers.xkv:GetKV("npc_abilities").DOTAAbilities
local itemKV = XHelpers.xkv:GetKV("items").DOTAAbilities

local function live(unit)
	return unit and Entity.IsEntity(unit) and Entity.IsAlive(unit) and not Entity.IsDormant(unit) and NPC.IsVisible(unit)
end

local function value(kv, key, fallback)
	local result = kv and kv.AbilityValues and kv.AbilityValues[key]
	if type(result) == "table" then result = result.value end
	if type(result) == "number" then return result end
	return type(result) == "string" and tonumber(result:match("%-?%d+%.?%d*")) or fallback
end

local function clear(ctx, position)
	if ctx.unsafePosition(position) then return false end
	for _, enemy in ipairs(ctx.enemies) do
		if live(enemy) and ctx.distance(position, Entity.GetAbsOrigin(enemy)) < 2200 then return false end
	end
	for _, sighting in pairs(ctx.memory) do
		if ctx.now - sighting.time < 6 and ctx.distance(position, sighting.position) < 2400 then return false end
	end
	for _, arrival in ipairs(ctx.teleportArrivals or {}) do
		if ctx.distance(position, arrival.position) < 2600 then return false end
	end
	return true
end

function roshan.hurt(ctx, data)
	local state = ctx.roshanState
	if not state or data.damage <= 0 then return end
	local outgoing = data.source == ctx.hero and data.target == state.target
	local incoming = data.source == state.target and data.target == ctx.hero
	if not outgoing and not incoming then return end
	state.samples = state.samples or {}
	state.samples[#state.samples + 1] = {time = GameRules.GetGameTime(), outgoing = outgoing and data.damage or 0, incoming = incoming and data.damage or 0}
end

function roshan.attack(ctx, target, reason)
	if not live(target) or not NPC.IsRoshan(target) or NPC.IsRunning(target) or NPC.IsChannellingAbility(target) then return false end
	local position = Entity.GetAbsOrigin(target)
	if ctx.distance(ctx.position, position) > 220 then
		local goal = ctx.toward(position, ctx.position, 140)
		return ctx.move(goal, "Enter Roshan pit before attacking", 35)
	end
	return ctx.attack(target, reason)
end

function roshan.assess(ctx, target)
	local result = {safe = false, reason = "Roshan unavailable", timeToKill = 0, remainingHealth = 0}
	if not live(target) or not NPC.IsRoshan(target) or NPC.IsWaitingToSpawn(target)
		or NPC.HasState(target, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE)
		or NPC.HasState(target, Enum.ModifierState.MODIFIER_STATE_ATTACK_IMMUNE)
		or NPC.HasState(target, Enum.ModifierState.MODIFIER_STATE_OUT_OF_GAME) then return result end
	result.reason = "Recover before Roshan"
	if ctx.retreating or ctx.health < 0.55 or not Entity.IsAlive(ctx.hero)
		or NPC.HasState(ctx.hero, Enum.ModifierState.MODIFIER_STATE_DISARMED) then return result end
	local position = Entity.GetAbsOrigin(target)
	result.reason = "Roshan is moving or contested"
	if NPC.IsRunning(target) or NPC.IsChannellingAbility(target) or not clear(ctx, position) or not clear(ctx, ctx.position) then return result end
	for _, fight in pairs(ctx.allyFights or {}) do
		if ctx.now - fight.time < 3 then result.reason = "Allied fight takes priority"; return result end
	end
	local distance = ctx.distance(ctx.position, position)
	result.reason = "Roshan too far away"
	if distance > 3800 then return result end
	local goal = ctx.toward(position, ctx.position, 140)
	local exit, exitScore, exitDistance
	result.reason = "No safe Roshan approach or exit"
	for step = 0, 7 do
		local angle = step * math.pi / 4
		local x, y = position.x + math.cos(angle) * 1050, position.y + math.sin(angle) * 1050
		local point = Vector(x, y, World.GetGroundZ(x, y))
		local score = ctx.distance(point, ctx.home)
		if GridNav.IsTraversable(point) and clear(ctx, point) and (not exitScore or score < exitScore) then
			local escapePath = GridNav.BuildPath(goal, point, false)
			local length, previous, safePath = 0, goal, true
			for _, waypoint in ipairs(escapePath) do
				length, previous = length + ctx.distance(previous, waypoint), waypoint
				if not clear(ctx, waypoint) then safePath = false end
			end
			if safePath and length < 1800 and #escapePath > 0 and ctx.distance(escapePath[#escapePath], point) < 150 then
				exit, exitScore, exitDistance = point, score, length
			end
		end
	end
	if not exit then return result end
	local path = ctx.distance(ctx.position, goal) < 100 and {ctx.position} or GridNav.BuildPath(ctx.position, goal, false)
	if #path == 0 or ctx.distance(path[#path], goal) > 150 then return result end
	local travelDistance, previous = 0, ctx.position
	for _, point in ipairs(path) do
		if not clear(ctx, point) then return result end
		travelDistance, previous = travelDistance + ctx.distance(previous, point), point
	end
	local speed = math.max(100, NPC.GetMoveSpeed(ctx.hero))
	local travel = travelDistance / speed
	local period = math.max(0.25, NPC.GetSecondsPerAttack(target, false))
	local chance = value(abilityKV.roshan_bash, "bash_chance", 15) / 100
	local downtime = math.max(0.55, 1 - chance * value(abilityKV.roshan_bash, "stun_duration", 1.65) / period)
	local damage = NPC.GetTrueDamage(ctx.hero) * NPC.GetArmorDamageMultiplier(target)
	local dps = damage / math.max(0.2, NPC.GetSecondsPerAttack(ctx.hero, true)) * downtime * 0.85
	local hit = NPC.GetTrueMaximumDamage(target) * NPC.GetArmorDamageMultiplier(ctx.hero)
	local magic = NPC.GetMagicalArmorDamageMultiplier(ctx.hero)
	local minutes = math.floor(math.max(0, ctx.clock) / 60)
	local slam = (value(abilityKV.roshan_slam, "damage", 70) + minutes * value(abilityKV.roshan_slam, "damage_growth", 10)) * magic
	local incoming = hit / period * 1.25 + chance * value(abilityKV.roshan_bash, "bonus_damage", 50) * magic / period + slam / 10
	local state = ctx.roshanState
	if state and state.target == target then
		local outgoing, taken = 0, 0
		for i = #(state.samples or {}), 1, -1 do
			local sample = state.samples[i]
			if ctx.now - sample.time > 4 then table.remove(state.samples, i)
			else outgoing, taken = outgoing + sample.outgoing, taken + sample.incoming end
		end
		local window = math.min(4, ctx.now - (state.contact or ctx.now))
		if window >= 2.5 then
			dps = math.max(dps, math.min(dps * 2, outgoing / window * 0.8))
			incoming = math.max(incoming, taken / window * 1.15)
		end
	end
	local lifesteal = 0
	for slot = 0, 5 do
		local item = NPC.GetItemByIndex(ctx.hero, slot)
		if item and Item.IsItemEnabled(item) then lifesteal = math.max(lifesteal, value(itemKV[Ability.GetName(item)], "lifesteal_percent", 0) / 100) end
	end
	local sustain = NPC.GetHealthRegen(ctx.hero) + dps * math.min(0.35, lifesteal) * 0.5
	local regen = math.max(0, NPC.GetHealthRegen(target))
	result.reason, result.damageDps, result.incomingDps = "Cannot overcome Roshan regeneration", dps, incoming
	if dps <= regen + 5 then return result end
	local kill = (Entity.GetHealth(target) + regen * travel) / (dps - regen) + 0.8
	local health, maximum = Entity.GetHealth(ctx.hero), Entity.GetMaxHealth(ctx.hero)
	local burst = slam + hit * 2 + 80 * magic
	local loss = math.max(0, incoming - sustain) * kill + burst
	local escapeReserve = incoming * (exitDistance / speed + 1)
	result.timeToKill, result.remainingHealth = kill, health - loss
	result.goal, result.exit, result.travel = goal, exit, travel
	result.reason = "Roshan would take too long"
	local known = 0
	for _, enemy in ipairs(ctx.enemies) do if live(enemy) and not NPC.IsIllusion(enemy) then known = known + 1 end end
	if kill > (known >= 3 and 40 or 20) or travel + kill > (known >= 3 and 48 or 28) then return result end
	result.reason = "Insufficient health to finish and escape"
	if health - loss < math.max(maximum * 0.3, escapeReserve) then return result end
	result.safe, result.reason = true, Entity.GetHealth(target) <= Entity.GetMaxHealth(target) * 0.3 and "Finish weakened Roshan" or "Solo Roshan within survival budget"
	return result
end

function roshan.cancel(ctx)
	local state = ctx.roshanState
	if not state then return end
	ctx.roshanState, ctx.nextSoloRoshan = nil, ctx.now + 20
	if live(state.target) and ctx.distance(ctx.position, Entity.GetAbsOrigin(state.target)) < 1100 then
		ctx.roshanExit = {goal = state.exit, expires = ctx.now + 5}
		ctx.stop()
		ctx.hits.ordered, ctx.busyUntil = nil, ctx.now
	end
end

function roshan.plan(ctx, target)
	if ctx.now < (ctx.nextSoloRoshan or 0) then return nil end
	local result = roshan.assess(ctx, target)
	ctx.roshanAssessment = result
	if not result.safe then
		if ctx.roshanState and ctx.roshanState.target == target then roshan.cancel(ctx) end
		return nil
	end
	local state = ctx.roshanState
	if not state or state.target ~= target then
		state = {target = target, started = ctx.now, progress = ctx.now, health = Entity.GetHealth(target), distance = ctx.distance(ctx.position, Entity.GetAbsOrigin(target))}
		ctx.roshanState = state
	end
	local distance, health = ctx.distance(ctx.position, Entity.GetAbsOrigin(target)), Entity.GetHealth(target)
	if distance < 600 then state.contact = state.contact or ctx.now end
	if distance < state.distance - 60 or distance < 600 and health < state.health - 1 then
		state.progress, state.distance, state.health = ctx.now, distance, health
	end
	state.exit = result.exit
	if ctx.now - state.progress > 4 or ctx.now - state.started > 55 then
		result.safe, result.reason = false, "Roshan attempt made no reliable progress"
		roshan.cancel(ctx)
		return nil
	end
	return {kind = "roshan", solo = true, target = target, goal = result.goal, expires = ctx.now + 0.8}
end

function roshan.escape(ctx)
	local task = ctx.roshanExit
	if not task then return false end
	if ctx.now > task.expires or ctx.distance(ctx.position, task.goal) < 120 then ctx.roshanExit = nil; return false end
	return ctx.move(task.goal, "Leave unsafe Roshan attempt", 100)
end

function roshan.run(ctx, task)
	if not live(task.target) then
		if Entity.IsEntity(task.target) and not Entity.IsAlive(task.target) then ctx.roshanLoot = {position = Entity.GetAbsOrigin(task.target), expires = ctx.now + 12} end
		ctx.roshanState, ctx.teamTask = nil, nil
		return false
	end
	local result = ctx.roshanAssessment
	if not result then ctx.teamTask = nil; return false end
	if not result.safe then roshan.cancel(ctx); ctx.teamTask = nil; return roshan.escape(ctx) end
	return roshan.attack(ctx, task.target, result.reason)
end

function roshan.loot(ctx)
	local task = ctx.roshanLoot
	if not task then return false end
	if ctx.now > task.expires or ctx.retreating or not clear(ctx, task.position) then ctx.roshanLoot = nil; return false end
	if NPC.GetItem(ctx.hero, "item_aegis", true) then ctx.roshanLoot = nil; return false end
	local room = false
	for slot = 0, 5 do if not NPC.GetItemByIndex(ctx.hero, slot) then room = true; break end end
	if not room then return false end
	if ctx.now < (task.nextOrder or 0) then return true end
	for _, physical in ipairs(PhysicalItems.GetAll()) do
		if Entity.IsEntity(physical) and not Entity.IsDormant(physical) and ctx.distance(Entity.GetAbsOrigin(physical), task.position) < 500 then
			local item = PhysicalItem.GetItem(physical)
			if item and Ability.GetName(item) == "item_aegis" then
				Player.PrepareUnitOrders(ctx.player, Enum.UnitOrder.DOTA_UNIT_ORDER_PICKUP_ITEM, physical, Entity.GetAbsOrigin(physical), nil,
					Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, ctx.hero, false, false, false, true, "self_play_aegis", false)
				task.nextOrder, ctx.mode = ctx.now + 1, "Collect Roshan Aegis"
				return true
			end
		end
	end
	return false
end

return roshan
