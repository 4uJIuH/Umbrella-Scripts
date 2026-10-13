local recovery = {}
local awareness = require("self_play.awareness")
local consumables = require("self_play.consumables")
local navigation = require("self_play.navigation")
local itemKV = XHelpers.xkv:GetKV("items").DOTAAbilities

local function value(name, key)
	local record = itemKV[name]
	local raw = record and record.AbilityValues and record.AbilityValues[key]
	if type(raw) == "table" then raw = raw.value end
	return tonumber(raw) or 0
end

function recovery.resources(ctx, seconds)
	local health = math.max(0, NPC.GetHealthRegen(ctx.hero)) * seconds
	local mana = math.max(0, NPC.GetManaRegen(ctx.hero)) * seconds
	for _, buff in ipairs({{"modifier_flask_healing", "item_flask", "health_regen"},
		{"modifier_tango_heal", "item_tango", "health_regen"}, {"modifier_clarity_potion", "item_clarity", "mana_regen"},
		{"modifier_bottle_regeneration", "item_bottle", "health_restore"}}) do
		local modifier = NPC.GetModifier(ctx.hero, buff[1])
		if modifier then
			local unused = math.max(0, seconds - math.max(0, Modifier.GetDieTime(modifier) - ctx.now))
			if buff[2] == "item_bottle" then
				local duration = math.max(0.1, value(buff[2], "restore_time"))
				health = math.max(0, health - value(buff[2], "health_restore") / duration * unused)
				mana = math.max(0, mana - value(buff[2], "mana_restore") / duration * unused)
			elseif buff[3] == "mana_regen" then mana = math.max(0, mana - value(buff[2], buff[3]) * unused)
			else health = math.max(0, health - value(buff[2], buff[3]) * unused) end
		end
	end
	for _, name in ipairs({"item_flask", "item_tango", "item_tango_single", "item_bottle", "item_clarity"}) do
		local item = NPC.GetItem(ctx.hero, name, true)
		if item and Item.IsItemEnabled(item) and Item.GetCurrentCharges(item) > 0 and Ability.GetCooldown(item) < 4 then
			if name == "item_bottle" then
				if not NPC.HasModifier(ctx.hero, "modifier_bottle_regeneration") then
					health = health + value(name, "health_restore") * math.min(3, Item.GetCurrentCharges(item))
					mana = mana + value(name, "mana_restore") * math.min(3, Item.GetCurrentCharges(item))
				end
			elseif name == "item_flask" and not NPC.HasModifier(ctx.hero, "modifier_flask_healing") then
				health = health + value(name, "health_regen") * math.min(seconds, value(name, "buff_duration"))
			elseif (name == "item_tango" or name == "item_tango_single") and not NPC.HasModifier(ctx.hero, "modifier_tango_heal") then
				if #Entity.GetTreesInRadius(ctx.hero, 600, true) > 0 then
					health = health + value(name, "health_regen") * math.min(seconds, value(name, "buff_duration"))
				end
			elseif name == "item_clarity" and not NPC.HasModifier(ctx.hero, "modifier_clarity_potion") then
				mana = mana + value(name, "mana_regen") * math.min(seconds, value(name, "buff_duration"))
			end
		end
	end
	local armlet = NPC.GetItem(ctx.hero, "item_armlet", true)
	if armlet and Item.IsItemEnabled(armlet) and Ability.GetToggleState(armlet) then
		health = health - value("item_armlet", "unholy_health_drain_per_second") * seconds
	end
	return health, mana
end

function recovery.thresholds(ctx)
	if ctx.heroModule and ctx.heroModule.recovery then
		local enter, resume = ctx.heroModule.recovery(ctx)
		if enter then return enter, resume, true end
	end
	local settings = ctx.settings or {}
	return settings.fountainEnter or 0.5, 0.68, false
end

local function jungleCamps()
	if JungleCampsManager and JungleCampsManager.camps then return JungleCampsManager.camps end
	return {}
end

function recovery.timedHeal(ctx)
	for _, name in ipairs({"modifier_flask_healing", "modifier_tango_heal",
		"modifier_clarity_potion", "modifier_bottle_regeneration"}) do
		if NPC.GetModifier(ctx.hero, name) then return true end
	end
	return false
end

function recovery.fountainNeeded(ctx)
	local _, resume, custom = recovery.thresholds(ctx)
	local settings = ctx.settings or {}
	local healthGate = custom and resume or settings.fountainHealth or 0.68
	local manaGate = settings.fountainMana or 0.45
	if ctx.health == nil then return false end
	return ctx.health < healthGate or NPC.GetMana(ctx.hero) < NPC.GetMaxMana(ctx.hero) * manaGate
end

function recovery.contact(ctx)
	local state = ctx.disengage
	local group, closing, friendly = {}, 0, 1
	for _, ally in ipairs(ctx.allies) do
		if ally ~= ctx.hero and Entity.IsEntity(ally) and Entity.IsAlive(ally) and not Entity.IsDormant(ally)
			and not NPC.IsIllusion(ally) and Entity.GetHealth(ally) > Entity.GetMaxHealth(ally) * 0.4
			and ctx.distance(ctx.position, Entity.GetAbsOrigin(ally)) < 1400 then friendly = friendly + 1 end
	end
	for _, enemy in ipairs(ctx.enemies) do
		if Entity.IsEntity(enemy) and Entity.IsAlive(enemy) and not Entity.IsDormant(enemy) and NPC.IsVisible(enemy) and not NPC.IsIllusion(enemy) then
			local point = Entity.GetAbsOrigin(enemy)
			local distance = ctx.distance(ctx.position, point)
			if distance < 1700 then
				group[#group + 1] = enemy
				local forward = Entity.GetRotation(enemy):GetForward()
				local approaching = NPC.IsRunning(enemy) and ((ctx.position.x - point.x) * forward.x + (ctx.position.y - point.y) * forward.y) > distance * 0.4
				if approaching or distance < 850 then closing = closing + 1 end
			end
		end
	end
	local decision = ctx.combatDecision
	local quickFinish = ctx.spellFinish or decision and decision.safe and decision.killTime < 2.5 and decision.incoming < Entity.GetHealth(ctx.hero) * 0.2
	local collapse = #group >= 3 and #group >= friendly + 2 and closing >= 2 and not quickFinish
	if collapse then
		if not state then state = {zones = {}}; ctx.disengage = state end
		if not state.escaping then state.started, state.origin, state.goal = ctx.now, ctx.position, nil end
		state.escaping, state.safeSince = true, nil
		for _, enemy in ipairs(group) do
			local point = Entity.GetAbsOrigin(enemy)
			state.zones[Entity.GetIndex(enemy)] = {source = enemy, position = Vector(point.x, point.y, point.z),
				radius = math.max(1350, NPC.GetAttackRange(enemy) + NPC.GetAttackRangeBonus(enemy) + 750), expires = ctx.now + 10}
		end
	end
	if not state then return false end
	local count = 0
	for id, zone in pairs(state.zones) do
		if ctx.now >= zone.expires or not Entity.IsEntity(zone.source) or not Entity.IsAlive(zone.source) then state.zones[id] = nil
		else
			count = count + 1
			if not Entity.IsDormant(zone.source) and NPC.IsVisible(zone.source) then
				local point = Entity.GetAbsOrigin(zone.source)
				zone.position = Vector(point.x, point.y, point.z)
			end
		end
	end
	if count == 0 then ctx.disengage = nil; return false end
	if not state.escaping or quickFinish then return false end
	local separated = not collapse and awareness.disengageRisk(ctx, ctx.position) == 0
		and awareness.damage(ctx, ctx.position, 3) + awareness.forecast(ctx, ctx.position) < Entity.GetHealth(ctx.hero) * 0.12
	if separated then state.safeSince = state.safeSince or ctx.now else state.safeSince = nil end
	if state.safeSince and ctx.now - state.safeSince >= 2 and ctx.now - state.started >= 3.5
		and ctx.distance(ctx.position, state.origin) >= 900 then
		state.escaping = false
		if ctx.recoveryTask then ctx.recoveryTask.safeAfter = ctx.now end
		if state.lane then ctx.lane, ctx.waveAnchor, ctx.waveLane = state.lane, nil, nil end
		ctx.nextRotation, ctx.regroupTask = ctx.now + 10, nil
		return false
	end
	return true
end

function recovery.relocate(ctx)
	local state = ctx.disengage
	if not state or not state.escaping then return nil end
	if ctx.baseDefense then state.goal, state.lane = nil, nil; return ctx.home end
	if state.goal and ctx.now < (state.nextGoal or 0) and awareness.disengageRisk(ctx, state.goal) == 0 then return state.goal end
	state.nextGoal = ctx.now + 1
	local best, score, lane
	local function add(point, value, candidateLane)
		local distance = ctx.distance(ctx.position, point)
		if distance < 350 or distance > 6000 or ctx.distance(state.origin, point) < 900
			or ctx.unsafePosition(point) or not GridNav.IsTraversable(point) or awareness.disengageRisk(ctx, point) > 0
			or awareness.damage(ctx, point, 3) + awareness.forecast(ctx, point) > Entity.GetHealth(ctx.hero) * 0.12 then return end
		local path = distance < 2200 and navigation.safePath(ctx, point, 60)
		local canTeleport = distance >= 3000 and ctx.nearEnemies == 0 and Hero.GetRecentDamage(ctx.hero) == 0
		if not path and not canTeleport then return end
		local rank = distance - value
		if not score or rank < score then best, score, lane = point, rank, candidateLane end
	end
	for index, wave in ipairs(ctx.waves) do
		for _, creep in ipairs(wave) do
			if Entity.IsEntity(creep) and Entity.IsAlive(creep) then add(ctx.toward(Entity.GetAbsOrigin(creep), ctx.home, 400), 500, index); break end
		end
	end
	for _, camp in pairs(jungleCamps()) do
		if camp.team_ == ctx.team and camp.camp_type <= 1 and not camp.is_farmed_ then
			add(ctx.toward(camp.position_, ctx.position, 500), 250)
		end
	end
	add(navigation.coverAnchor(ctx), 0)
	state.goal, state.lane = best, lane
	return best
end

function recovery.update(ctx, danger, losing)
	local task = ctx.recoveryTask
	local hp, maxHP = Entity.GetHealth(ctx.hero), Entity.GetMaxHealth(ctx.hero)
	local mana, maxMana = NPC.GetMana(ctx.hero), NPC.GetMaxMana(ctx.hero)
	local enterHealth, resumeHealth = recovery.thresholds(ctx)
	local holdHealth = task and math.min(resumeHealth, enterHealth + 0.08) or enterHealth
	local needsHealth = hp < maxHP * ((danger or losing) and resumeHealth or holdHealth)
	local needsMana = mana < maxMana * (task and 0.3 or 0.12)
		and (needsHealth or ctx.distance(ctx.position, ctx.home) < 1400)
	local separating = recovery.contact(ctx)
	local pressured = danger or losing or separating
	if not pressured and (ctx.spellFinish or ctx.combatDecision and ctx.combatDecision.safe and hp > maxHP * 0.2
		or ctx.fightSession and ctx.fightSession.distance < 1400 and ctx.fightSession.incoming < hp * 0.25 and hp > maxHP * 0.3) then
		needsHealth, needsMana, task = false, false, nil
	end
	if not pressured and not task and hp > maxHP * 0.3 and ctx.heroModule and ctx.heroModule.locked and ctx.heroModule.locked(ctx) then
		needsHealth, needsMana = false, false
	end
	if pressured then
		task = task or {started = ctx.now, health = hp}
		task.phase, task.safeAfter = "escape", ctx.now + (separating and 2.5 or 1.2)
	elseif task and ctx.now < task.safeAfter then
		task.phase = "escape"
	elseif needsHealth or needsMana then
		task = task or {started = ctx.now, health = hp, safeAfter = ctx.now}
		local previous = task.phase
		local seconds = math.min(24, math.max(12, ctx.distance(ctx.position, ctx.home) / math.max(100, NPC.GetMoveSpeed(ctx.hero)) + 8))
		local heal, restore = recovery.resources(ctx, seconds)
		local localHeal = (not needsHealth or hp + heal >= maxHP * resumeHealth) and (not needsMana or mana + restore >= maxMana * 0.3)
		local stalled = task.phase == "regen" and ctx.now - (task.progressAt or ctx.now) > 8
			and hp <= (task.progressHP or hp) + 5 and mana <= (task.progressMana or mana) + 5
		if stalled then task.localBlockedUntil = ctx.now + 15 end
		local timed = recovery.timedHeal(ctx) and hp > maxHP * enterHealth
		if (localHeal or timed) and ctx.now >= (task.localBlockedUntil or 0) and ctx.distance(ctx.position, ctx.home) > 1100 then task.phase = "regen"
		else task.phase = "base" end
		if task.phase == "regen" and previous ~= "regen" then task.progressAt, task.progressHP, task.progressMana = ctx.now, hp, mana end
	else task = nil end
	if task and (not task.progressAt or hp > task.progressHP + 15 or mana > task.progressMana + 15) then
		task.progressAt, task.progressHP, task.progressMana = ctx.now, hp, mana
	end
	if task and task.phase == "regen" and ctx.baseDefense and ctx.distance(ctx.position, ctx.home) > 1800 then task.phase = "base" end
	ctx.recoveryTask, ctx.retreating, ctx.hardRetreat = task, task ~= nil, danger == true
	ctx.recovering = task ~= nil and (needsHealth or needsMana)
	ctx.retreatUntil = nil
	if task then ctx.intent = nil end
end

function recovery.shelter(ctx)
	local anchor = navigation.coverAnchor(ctx)
	local escaping = ctx.recoveryTask and ctx.recoveryTask.phase == "escape"
	local initialDamage = awareness.damage(ctx, ctx.position, 2) + awareness.forecast(ctx, ctx.position)
	if ctx.unsafePosition(ctx.position) then return navigation.escape(ctx, anchor) end
	local best, bestScore
	local function add(point)
		if escaping and ctx.distance(ctx.position, point) < 180 then return end
		if not GridNav.IsTraversable(point) or ctx.unsafePosition(point) then return end
		local path = GridNav.BuildPath(ctx.position, point, navigation.treeWalking(ctx))
		if #path == 0 then return end
		if ctx.distance(path[#path], point) > 5 then path[#path + 1] = point end
		local previous, length, worst = ctx.position, 0, 0
		local initial = awareness.risk(ctx, ctx.position)
		for _, waypoint in ipairs(path) do
			local segment = ctx.distance(previous, waypoint)
			for step = 1, math.max(1, math.ceil(segment / 160)) do
				local sample = ctx.toward(previous, waypoint, math.min(segment, step * 160))
				if ctx.unsafePosition(sample) then return end
				worst = math.max(worst, awareness.risk(ctx, sample))
			end
			length, previous = length + segment, waypoint
		end
		if length > 1400 or worst > initial + 60 then return end
		local damage = awareness.damage(ctx, point, 2) + awareness.forecast(ctx, point)
		if escaping and initialDamage > Entity.GetHealth(ctx.hero) * 0.08 and damage >= initialDamage * 0.9
			and awareness.risk(ctx, point) >= initial - 30 then return end
		local score = damage * (escaping and 6 or 3) + awareness.risk(ctx, point) * 2 + length * 0.09 + ctx.distance(point, anchor) * (escaping and 0.2 or 0.8)
		if not bestScore or score < bestScore then best, bestScore = point, score end
		return score
	end
	local retained = ctx.recoveryTask and ctx.recoveryTask.goal
	local retainedScore = retained and ctx.distance(ctx.position, retained) > 70 and add(retained)
	add(ctx.toward(ctx.position, anchor, math.min(1000, ctx.distance(ctx.position, anchor))))
	for _, radius in ipairs({300, 650, 1000}) do
		for index = 0, 7 do
			local angle = index * math.pi / 4
			local x, y = ctx.position.x + math.cos(angle) * radius, ctx.position.y + math.sin(angle) * radius
			add(Vector(x, y, World.GetGroundZ(x, y)))
		end
	end
	if retainedScore and retainedScore <= bestScore + math.max(40, math.abs(bestScore) * 0.08) then return retained end
	return best
end

function recovery.run(ctx)
	local task = ctx.recoveryTask
	if not task then return false end
	if NPC.HasModifier(ctx.hero, "modifier_fountain_aura_buff") and not recovery.fountainNeeded(ctx) then
		ctx.recoveryTask, ctx.retreating, ctx.hardRetreat, ctx.recovering = nil, false, false, false
		return false
	end
	if ctx.unsafePosition(ctx.position) then
		local exit = navigation.escape(ctx, navigation.coverAnchor(ctx))
		if exit then task.goal = exit; return ctx.move(exit, "Escape enemy tower range", 35) end
	end
	if consumables.run(ctx) then return true end
	if task.phase == "base" then
		if ctx.teleport(ctx.home, "recover") then return true end
		return ctx.move(ctx.home, "Recover at fountain: local regeneration insufficient")
	end
	local quiet = awareness.risk(ctx, ctx.position) < 35 and awareness.damage(ctx, ctx.position, 2) < Entity.GetHealth(ctx.hero) * 0.08
		and awareness.forecast(ctx, ctx.position) < Entity.GetHealth(ctx.hero) * 0.08 and not ctx.unsafePosition(ctx.position)
		and (ctx.creepPressure or 0) == 0 and ctx.now - (ctx.lastDamaged or -10) > 2
	if task.phase == "escape" and ctx.disengage and ctx.disengage.escaping then
		local destination = recovery.relocate(ctx)
		if destination then
			if quiet and ctx.teleport(destination, "escape") then ctx.mode = "Teleport from safety away from enemy group"; return true end
			if ctx.distance(ctx.position, destination) < 2200 then return ctx.move(destination, "Disengage toward safer farm or cover", 70) end
		end
	end
	if task.phase == "regen" and quiet then ctx.mode = "Regenerate near lane in safety"; return ctx.stop() end
	local threatened = task.goal and (ctx.unsafePosition(task.goal)
		or awareness.damage(ctx, task.goal, 2) + awareness.forecast(ctx, task.goal)
			> awareness.damage(ctx, ctx.position, 2) + awareness.forecast(ctx, ctx.position)
				+ math.max(40, Entity.GetHealth(ctx.hero) * 0.05))
	if threatened then task.goal, ctx.escapeRoute, ctx.navigationGoal = nil, nil, nil end
	if not task.goal or ctx.now >= (task.nextGoal or 0) or ctx.distance(ctx.position, task.goal) < 70 then
		task.goal, task.nextGoal = recovery.shelter(ctx), ctx.now + 0.5
	end
	if task.goal then return ctx.move(task.goal, task.phase == "escape" and "Break enemy contact" or "Find nearby regeneration cover", 45) end
	local exit = navigation.escape(ctx, navigation.coverAnchor(ctx))
	if exit then task.goal = exit; return ctx.move(exit, "Recovery: move toward lower danger", 35) end
	ctx.mode = "Recovery: no safe local route"
	return ctx.stop()
end

function recovery.buyback(ctx)
	if Entity.IsAlive(ctx.hero) or Hero.GetRespawnTime(ctx.hero) - ctx.now < 25 then return false end
	local info = Player.GetTeamPlayer(ctx.player)
	if info.buyback_cooldown_time > ctx.now then return false end
	local baseThreat, fightAllies = ctx.baseDefense ~= nil, 0
	for _, structure in ipairs(ctx.structures) do
		if Entity.IsAlive(structure) and Entity.IsSameTeam(ctx.hero, structure)
			and ctx.distance(Entity.GetAbsOrigin(structure), ctx.home) < 3000 then
			for _, enemy in ipairs(ctx.enemies) do
				if Entity.IsAlive(enemy) and not Entity.IsDormant(enemy)
					and ctx.distance(Entity.GetAbsOrigin(enemy), Entity.GetAbsOrigin(structure)) < 1100 then baseThreat = true end
			end
		end
	end
	if ctx.clock >= 1200 and Hero.GetRespawnTime(ctx.hero) - ctx.now >= 50 then
		for _, ally in ipairs(ctx.allies) do
			if ally ~= ctx.hero and Entity.IsAlive(ally) and Hero.GetRecentDamage(ally) > 0 then
				for _, structure in ipairs(ctx.structures) do
					if Entity.IsAlive(structure) and Entity.IsSameTeam(ctx.hero, structure)
						and ctx.distance(Entity.GetAbsOrigin(ally), Entity.GetAbsOrigin(structure)) < 1800 then
						fightAllies = fightAllies + 1; break
					end
				end
			end
		end
	end
	local tp = NPC.GetItem(ctx.hero, "item_tpscroll", false)
	if not baseThreat and not (fightAllies >= 2 and tp and Ability.IsReady(tp)) then return false end

	ctx.mode = baseThreat and "Buyback: base under attack" or "Buyback: rejoin allied defense"
	if ctx.now < (ctx.nextBuyback or 0) then return true end
	ctx.nextBuyback = ctx.now + 5
	Player.PrepareUnitOrders(ctx.player, Enum.UnitOrder.DOTA_UNIT_ORDER_BUYBACK, nil, Vector(0, 0, 0), nil,
		Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, ctx.hero, false, false, false, true, "self_play_buyback", false)
	return true
end

return recovery
