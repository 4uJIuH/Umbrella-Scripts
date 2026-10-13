local defense = {}
local awareness = require("self_play.awareness")
local navigation = require("self_play.navigation")
local engagement = require("self_play.engagement")
local intent = require("self_play.intent")

local function visible(unit)
	return unit and Entity.IsEntity(unit) and Entity.IsAlive(unit) and not Entity.IsDormant(unit) and NPC.IsVisible(unit)
end

local function baseBuilding(ctx, unit)
	if not visible(unit) or not Entity.IsSameTeam(ctx.hero, unit) then return false end
	local name = NPC.GetUnitName(unit)
	return NPC.IsFort(unit) or NPC.IsBarracks(unit) or NPC.IsTower(unit)
		and (name:find("tower3", 1, true) or name:find("tower4", 1, true) or ctx.distance(Entity.GetAbsOrigin(unit), ctx.home) < 3000)
end

function defense.hurt(ctx, data)
	if data.damage <= 0 or not visible(data.target) or not NPC.IsTower(data.target)
		or not Entity.IsSameTeam(ctx.hero, data.target) or not visible(data.source)
		or Entity.IsSameTeam(ctx.hero, data.source) then return end
	ctx.towerPressure = ctx.towerPressure or {}
	ctx.towerPressure[Entity.GetIndex(data.target)] = {source = data.source, time = GameRules.GetGameTime()}
	ctx.nextTowerPlan = 0
end

function defense.outer(ctx)
	if ctx.baseDefense or ctx.retreating or ctx.hardRetreat then ctx.towerDefense = nil; return nil end
	if ctx.now < (ctx.nextTowerPlan or 0) then return ctx.towerDefense end
	ctx.nextTowerPlan = ctx.now + 0.3
	for id, hit in pairs(ctx.towerPressure or {}) do
		if ctx.now - hit.time > 3 then ctx.towerPressure[id] = nil end
	end
	local previous, best, bestScore = ctx.towerDefense, nil, -math.huge
	local scroll = NPC.GetItem(ctx.hero, "item_tpscroll", false)
	local canTeleport = ctx.settings.teleport ~= false and ctx.nearEnemies == 0 and ctx.now >= (ctx.nextTeleport or 0)
		and Hero.GetRecentDamage(ctx.hero) == 0 and scroll and Item.IsItemEnabled(scroll)
		and Ability.CanBeExecuted(scroll) == -1 and Ability.IsReady(scroll) and Ability.IsCastable(scroll, NPC.GetMana(ctx.hero))
	for _, tower in ipairs(ctx.towers) do
		if visible(tower) and Entity.IsSameTeam(ctx.hero, tower) and not baseBuilding(ctx, tower)
			and not NPC.HasState(tower, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE) then
			local position = Entity.GetAbsOrigin(tower)
			local distance = ctx.distance(ctx.position, position)
			if distance < 6000 then
				local enemies, allies, attackers, creeps, waveLifetime = 0, 0, 0, 0, 0
				for _, enemy in ipairs(ctx.enemies) do
					if visible(enemy) and not NPC.IsIllusion(enemy) and ctx.distance(Entity.GetAbsOrigin(enemy), position) < 1200 then
						enemies = enemies + 1
						if NPC.IsAttacking(enemy) and NPC.FindFacingNPC(enemy, nil, Enum.TeamType.TEAM_ENEMY, 30,
							NPC.GetAttackRange(enemy) + NPC.GetAttackRangeBonus(enemy) + 150) == tower then attackers = attackers + 1 end
					end
				end
				for _, unit in ipairs(ctx.worldNPCs) do
					if visible(unit) and NPC.IsLaneCreep(unit) and not Entity.IsSameTeam(ctx.hero, unit)
						and ctx.distance(Entity.GetAbsOrigin(unit), position) < 850 then
						creeps = creeps + 1
						local damage = math.max(1, NPC.GetTrueMaximumDamage(tower) * NPC.GetArmorDamageMultiplier(unit))
						waveLifetime = waveLifetime + math.ceil(Entity.GetHealth(unit) / damage) * NPC.GetSecondsPerAttack(tower, false)
					end
				end
				for _, ally in ipairs(ctx.allies) do
					if ally ~= ctx.hero and visible(ally) and not NPC.IsIllusion(ally)
						and Entity.GetHealth(ally) > Entity.GetMaxHealth(ally) * 0.35
						and ctx.distance(Entity.GetAbsOrigin(ally), position) < 1400 then allies = allies + 1 end
				end
				local hit = ctx.towerPressure and ctx.towerPressure[Entity.GetIndex(tower)]
				local damaged = hit and visible(hit.source) and ctx.distance(Entity.GetAbsOrigin(hit.source), position) < 1200
				local pressured = attackers > 0 or damaged or creeps >= 3
				local covered = allies >= math.max(1, enemies) and creeps < 5
				local arrival = distance / math.max(100, NPC.GetMoveSpeed(ctx.hero))
				if canTeleport and distance > 3350 and enemies == 0 then arrival = math.min(arrival, 4.5) end
				local useful = enemies > 0 or distance < 1800 or arrival + 1 < waveLifetime
				if pressured and useful and enemies <= allies + 2 and (not covered or distance < 1800) then
					local goal = ctx.toward(position, ctx.home, 350)
					local incoming = awareness.damage(ctx, goal, 2) + awareness.forecast(ctx, goal) * 0.5
					if incoming < Entity.GetHealth(ctx.hero) * 0.35 and GridNav.IsTraversable(goal) and not ctx.unsafePosition(goal) then
						local score = attackers * 180 + creeps * 45 + (damaged and 140 or 0)
							+ (1 - Entity.GetHealth(tower) / Entity.GetMaxHealth(tower)) * 150
							- distance * 0.12 + (previous and previous.structure == tower and 220 or 0)
						if score > bestScore then
							best, bestScore = {structure = tower, goal = goal, position = position, enemies = enemies,
								allies = allies, creeps = creeps, attackers = attackers, expires = ctx.now + 0.35}, score
						end
					end
				end
			end
		end
	end
	ctx.towerDefense = best
	return best
end

function defense.update(ctx)
	if ctx.now < (ctx.nextBaseScan or 0) then return ctx.baseDefense end
	ctx.nextBaseScan = ctx.now + 0.25
	local previous, best, score = ctx.baseDefense, nil, -math.huge
	for _, structure in ipairs(ctx.structures) do
		if baseBuilding(ctx, structure) then
			local point, heroes, creeps = Entity.GetAbsOrigin(structure), 0, 0
			for _, enemy in ipairs(ctx.enemies) do
				if visible(enemy) and not NPC.IsIllusion(enemy) and ctx.distance(Entity.GetAbsOrigin(enemy), point) < 1200 then heroes = heroes + 1 end
			end
			for _, unit in ipairs(ctx.worldNPCs) do
				if visible(unit) and NPC.IsLaneCreep(unit) and not Entity.IsSameTeam(ctx.hero, unit)
					and ctx.distance(Entity.GetAbsOrigin(unit), point) < 900 then creeps = creeps + 1 end
			end
			if heroes > 0 or creeps >= 3 then
				local value = (NPC.IsFort(structure) and 2000 or NPC.IsBarracks(structure) and 700 or 400)
					+ heroes * 180 + creeps * 35 + (1 - Entity.GetHealth(structure) / Entity.GetMaxHealth(structure)) * 400
					+ (previous and previous.structure == structure and 250 or 0)
				if value > score then
					best, score = {structure = structure, name = NPC.GetUnitName(structure), position = point, heroes = heroes, creeps = creeps, expires = ctx.now + 8}, value
				end
			end
		end
	end
	if not best and previous and ctx.now < previous.expires then best = previous end
	if not best then
		ctx.baseDefense, ctx.baseCounterattack = nil, nil
		if previous then ctx.nextRotation, ctx.waveAnchor, ctx.waveLane = ctx.now + 4, nil, nil end
		return nil
	end
	if previous and previous.structure == best.structure then
		best.goal, best.nextGoal = previous.goal, previous.nextGoal
	end
	ctx.baseDefense = best
	ctx.regroupTask, ctx.waveFallback, ctx.waveBlocked, ctx.campTask, ctx.runeTask, ctx.riverTask = nil, nil, nil, nil, nil, nil
	ctx.objectiveTask, ctx.wardTask, ctx.clearTask, ctx.farmCandidate, ctx.aggroTask, ctx.spacingTask = nil, nil, nil, nil, nil, nil
	ctx.helpRotation, ctx.helpLaneUntil, ctx.laneGoal = nil, nil, nil
	ctx.nextRotation = ctx.now + 10
	if ctx.intent and (ctx.intent.kind ~= "hero" or not visible(ctx.intent.target)
		or ctx.distance(Entity.GetAbsOrigin(ctx.intent.target), best.position) > 1600) then ctx.intent = nil end
	if ctx.fightSession and ctx.distance(ctx.fightSession.goal, best.position) > 1800 then ctx.fightSession = nil end
	return best
end

local function fightingAllies(ctx, target)
	local count, point = 0, Entity.GetAbsOrigin(target)
	local id = Entity.GetIndex(target)
	local record = ctx.fightEvidence and ctx.fightEvidence[id]
	local recent = ctx.allyFights and ctx.allyFights[id]
	for _, ally in ipairs(ctx.allies) do
		if ally ~= ctx.hero and visible(ally) and not NPC.IsIllusion(ally) and Entity.IsSameTeam(ctx.hero, ally)
			and ctx.distance(Entity.GetAbsOrigin(ally), point) < 1300 then
			local hit = record and record.allies[Entity.GetIndex(ally)]
			if hit and ctx.now - hit.time < 3 or recent and recent.ally == ally and ctx.now - recent.time < 3
				or NPC.IsAttacking(ally) and NPC.FindFacingNPC(ally, nil, Enum.TeamType.TEAM_ENEMY, 30,
					NPC.GetAttackRange(ally) + NPC.GetAttackRangeBonus(ally) + 200) == target
				or NPC.IsAttacking(target) and NPC.FindFacingNPC(target, nil, Enum.TeamType.TEAM_ENEMY, 30,
					NPC.GetAttackRange(target) + NPC.GetAttackRangeBonus(target) + 200) == ally then count = count + 1 end
		end
	end
	return count
end

function defense.prepare(ctx)
	local previous, task = ctx.baseCounterattack, ctx.baseDefense
	ctx.baseCounterattack = nil
	if not task or not visible(task.structure) or not Entity.IsAlive(ctx.hero) then return nil end
	local hp, maximum = Entity.GetHealth(ctx.hero), Entity.GetMaxHealth(ctx.hero)
	local critical = NPC.IsFort(task.structure) or Entity.GetHealth(task.structure) < Entity.GetMaxHealth(task.structure) * 0.3
	local barriers = NPC.GetBarriers(ctx.hero)
	local available = hp + (barriers and barriers.all.current or 0)
	local projectiles = 0
	for _, shot in pairs(ctx.projectiles or {}) do
		if shot.target == ctx.hero and shot.impact >= ctx.now and shot.impact < ctx.now + 1 then projectiles = projectiles + shot.damage end
	end
	local immediate = awareness.damage(ctx, ctx.position, 0.75) + awareness.forecast(ctx, ctx.position) * 0.2 + projectiles
	if immediate >= available * (critical and 0.95 or 0.8) or ctx.unsafePosition(ctx.position) then return nil end
	local best, bestScore
	for _, enemy in ipairs(ctx.enemies) do
		if visible(enemy) and not NPC.IsIllusion(enemy) and not Entity.IsSameTeam(ctx.hero, enemy)
			and not NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE)
			and not NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_OUT_OF_GAME)
			and ctx.distance(Entity.GetAbsOrigin(enemy), task.position) < 1600
			and ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy)) < 2400 then
			local allies = fightingAllies(ctx, enemy)
			local point = engagement.attackPosition(ctx, enemy)
			local approach = ctx.distance(ctx.position, point) / math.max(100, NPC.GetMoveSpeed(ctx.hero))
			local incoming = awareness.damage(ctx, point, 0.75 + math.min(0.75, approach))
				+ awareness.forecast(ctx, point) * 0.2 + projectiles
			local allowance = critical and 0.95 or allies > 0 and 0.8 or 0.5
			if hp > maximum * (critical and 0.08 or allies > 0 and 0.18 or 0.35)
				and incoming < available * allowance and GridNav.IsTraversable(point) and not ctx.unsafePosition(point)
				and navigation.safePath(ctx, point) then
				local score = allies * 350 + (previous and previous.target == enemy and 450 or 0)
					+ (NPC.IsChannellingAbility(enemy) and 250 or 0)
					+ (1 - Entity.GetHealth(enemy) / math.max(1, Entity.GetMaxHealth(enemy))) * 400
					- ctx.distance(ctx.position, point) * 0.2 - incoming * 0.1
				if not bestScore or score > bestScore then
					best, bestScore = {target = enemy, point = point, allies = allies, critical = critical, incoming = incoming, time = ctx.now}, score
				end
			end
		end
	end
	ctx.baseCounterattack = best
	return best
end

function defense.interrupt(ctx, target)
	local task = ctx.baseDefense
	if not task then return false end
	if ctx.baseCounterattack then return true end
	return not visible(target) or not NPC.IsLaneCreep(target) or Entity.IsSameTeam(ctx.hero, target)
		or ctx.distance(Entity.GetAbsOrigin(target), task.position) > 1400
end

function defense.position(ctx)
	local task = ctx.baseDefense
	if not task then return nil end
	if task.goal and ctx.now < (task.nextGoal or 0) then return task.goal end
	task.nextGoal = ctx.now + 0.4
	local best, score
	local function consider(point)
		if not GridNav.IsTraversable(point) or ctx.unsafePosition(point) then return end
		local damage = awareness.damage(ctx, point, 2.5) + awareness.forecast(ctx, point)
		if damage > Entity.GetHealth(ctx.hero) * 0.22 then return end
		local value = ctx.distance(point, task.position) + damage * 3 + ctx.distance(ctx.position, point) * 0.08
		if not score or value < score then best, score = point, value end
	end
	for _, offset in ipairs({350, 650, 950, 1350, 1800}) do consider(ctx.toward(task.position, ctx.home, offset)) end
	consider(ctx.home)
	task.goal = best
	return best
end

function defense.run(ctx)
	local task = ctx.baseDefense
	if not task then return false end
	local counter = ctx.baseCounterattack
	if not counter or counter.time ~= ctx.now then counter = defense.prepare(ctx) end
	if counter then
		ctx.target = counter.target
		ctx.recoveryTask, ctx.disengage, ctx.retreatUntil = nil, nil, nil
		ctx.retreating, ctx.hardRetreat, ctx.recovering = false, false, false
		intent.begin(ctx, counter.target, "hero", false)
		ctx.mode = counter.critical and "Base defense: contest critical siege" or "Base defense: join counterattack"
		if ctx.fightAbilities() then return true end
		if ctx.attack(counter.target, ctx.mode) then return true end
	end
	if ctx.retreating or ctx.hardRetreat then return false end
	local goal = defense.position(ctx)
	if not goal then
		local exit = navigation.escape(ctx, ctx.home)
		ctx.mode = "Base defense: seek safer approach"
		return exit and ctx.move(exit, ctx.mode) or ctx.stop()
	end
	if ctx.distance(ctx.position, goal) > 1800 then
		if ctx.teleport(goal, "defend") or ctx.distance(ctx.position, ctx.home) > 4000 and ctx.teleport(ctx.home, "defend") then
			ctx.mode = "Base defense: teleport behind siege"
			return true
		end
		return ctx.move(goal, "Base defense: return to high ground")
	end
	if awareness.damage(ctx, ctx.position, 2) + awareness.forecast(ctx, ctx.position) > Entity.GetHealth(ctx.hero) * 0.3 then
		return ctx.move(goal, "Base defense: reposition behind allies")
	end
	local creep, value
	local range = NPC.GetAttackRange(ctx.hero) + NPC.GetAttackRangeBonus(ctx.hero)
	for _, unit in ipairs(ctx.creeps) do
		if visible(unit) and not Entity.IsSameTeam(ctx.hero, unit) and NPC.IsLaneCreep(unit)
			and ctx.distance(Entity.GetAbsOrigin(unit), task.position) < 1400 then
			local point = engagement.attackPosition(ctx, unit)
			local distance = ctx.distance(ctx.position, Entity.GetAbsOrigin(unit))
			if distance < range + 300 and not ctx.unsafePosition(point)
				and awareness.damage(ctx, point, 2) + awareness.forecast(ctx, point) < Entity.GetHealth(ctx.hero) * 0.25 then
				local score = distance + Entity.GetHealth(unit) * 0.2
				if not value or score < value then creep, value = unit, score end
			end
		end
	end
	if creep then
		if ctx.clearAbilities(ctx.creeps, true) then return true end
		return ctx.attack(creep, "Base defense: clear siege wave")
	end
	if ctx.distance(ctx.position, goal) > 100 then return ctx.move(goal, "Base defense: hold behind threatened building") end
	ctx.mode = "Base defense: cover siege approach"
	return ctx.stop()
end

return defense
