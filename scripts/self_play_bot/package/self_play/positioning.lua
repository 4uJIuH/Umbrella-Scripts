local positioning = {}
local laneRules = require("self_play.lane_rules")
local awareness = require("self_play.awareness")
local creepBlock = require("self_play.creep_block")
local laneSpacing = require("self_play.lane_spacing")
local navigation = require("self_play.navigation")

local function live(unit)
	return unit and Entity.IsEntity(unit) and Entity.IsAlive(unit) and not Entity.IsDormant(unit)
end

function positioning.observe(ctx)
	ctx.creepAggro = ctx.creepAggro or {}
	for id, swing in pairs(ctx.creepSwings or {}) do
		if ctx.now > swing.impact + 0.25 or not live(swing.source) then
			ctx.creepSwings[id] = nil
		elseif ctx.healthLost > 0 and ctx.now >= swing.impact - 0.1 then

			ctx.creepAggro[id] = ctx.now + 0.55
			ctx.creepSwings[id] = nil
		end
	end
	local aggro, enemyCount, friendlyCount, melee, ranged = 0, 0, 0, 0, 0
	for _, creep in ipairs(ctx.creeps) do
		if live(creep) then
			local distance = ctx.distance(ctx.position, Entity.GetAbsOrigin(creep))
			if Entity.IsSameTeam(ctx.hero, creep) then
				if distance < 750 then friendlyCount = friendlyCount + 1 end
			elseif distance < 850 then
				enemyCount = enemyCount + 1
				local record = ctx.creepAggro and ctx.creepAggro[Entity.GetIndex(creep)]
				if record and record > ctx.now then
					aggro = aggro + 1
					if NPC.IsRanged(creep) then ranged = ranged + 1 else melee = melee + 1 end
				end
			end
		end
	end
	ctx.creepPressure, ctx.enemyCreepCount, ctx.friendlyCreepCount = aggro, enemyCount, friendlyCount
	ctx.meleePressure, ctx.rangedPressure = melee, ranged
	ctx.tradeSafe = aggro == 0 and enemyCount <= friendlyCount + 1 and ctx.health > 0.6
	for id, expiry in pairs(ctx.creepAggro or {}) do if expiry < ctx.now then ctx.creepAggro[id] = nil end end
end

function positioning.animation(ctx, data)
	if not live(data.unit) or not NPC.IsLaneCreep(data.unit) or Entity.IsSameTeam(ctx.hero, data.unit)
		or NPC.IsRanged(data.unit) or not NPC.IsAttacking(data.unit)
		or ctx.distance(ctx.position, Entity.GetAbsOrigin(data.unit)) > 350 then return end
	local target = NPC.FindFacingNPC(data.unit, nil, Enum.TeamType.TEAM_ENEMY, 20, NPC.GetAttackRange(data.unit) + 75)
	if target == ctx.hero then
		ctx.creepSwings = ctx.creepSwings or {}
		ctx.creepSwings[Entity.GetIndex(data.unit)] = {source = data.unit,
			impact = GameRules.GetGameTime() + math.max(0, data.castpoint - data.lag_compensation_time)}
	end
end

function positioning.hurt(ctx, data)
	if data.target == ctx.hero and data.damage > 0 and live(data.source) and NPC.IsHero(data.source)
		and not Entity.IsSameTeam(ctx.hero, data.source) then
		ctx.heroHarass = {source = data.source, time = GameRules.GetGameTime()}
	end
	if data.target ~= ctx.hero or data.damage <= 0 or not live(data.source)
		or not NPC.IsLaneCreep(data.source) or Entity.IsSameTeam(ctx.hero, data.source) then return end
	ctx.creepAggro = ctx.creepAggro or {}
	ctx.creepAggro[Entity.GetIndex(data.source)] = GameRules.GetGameTime() + 0.55
end

function positioning.reserve(ctx)
	local threat = ctx.laneThreat
	local farm = ctx.farmCandidate
	if not farm or ctx.hardRetreat or threat and (threat.lethal or threat.ambush) then return false end
	local committed = ctx.farmCommitment and ctx.farmCommitment.expires > ctx.now and farm and ctx.farmCommitment.target == farm.target
	return (committed or farm.start <= ctx.now + math.min(1.25, (farm.approach or 0) + 0.45))
		and (not threat or (threat.incoming or 0) < math.min(Entity.GetHealth(ctx.hero) * 0.16, Entity.GetMaxHealth(ctx.hero) * 0.09))
		and awareness.farmSafe(ctx, farm.goal or ctx.position, farm.approach or 0)
end

function positioning.respond(ctx)
	local threat = ctx.laneThreat
	if not threat or ctx.hardRetreat or ctx.intent and ctx.intent.kind == "hero" then ctx.spacingTask, ctx.spacingContact = nil, nil; return false end
	if positioning.reserve(ctx) then
		ctx.spacingTask, ctx.spacingContact = nil, nil
		return false
	end
	local task = ctx.spacingTask
	if task and (ctx.now > task.expires or not threat.enemy or threat.distance > 1100) then task = nil; ctx.spacingTask = nil end
	if task and not threat.avoid and threat.enemy
		and threat.distance > NPC.GetAttackRange(threat.enemy) + NPC.GetAttackRangeBonus(threat.enemy) + 140 then ctx.spacingTask = nil; return false end
	if task and ctx.distance(ctx.position, task.position) < 50 then task = nil; ctx.spacingTask = nil end
	if not task and not threat.avoid then ctx.spacingContact = nil; return false end
	if not task then
		local contact = ctx.spacingContact
		if not contact or contact.enemy ~= threat.enemy then
			contact = {enemy = threat.enemy, started = ctx.now}
			ctx.spacingContact = contact
		end
		local shelter = navigation.coverAnchor(ctx)
		local best, bestScore
		local reach = threat.enemy and NPC.GetAttackRange(threat.enemy) + NPC.GetAttackRangeBonus(threat.enemy) or 150
		local step = math.min(360, math.max(140, reach + 140 - threat.distance))
		for index = 0, 11 do
			local angle = index * math.pi / 6
			local x, y = ctx.position.x + math.cos(angle) * step, ctx.position.y + math.sin(angle) * step
			local point = Vector(x, y, World.GetGroundZ(x, y))
			if GridNav.IsTraversable(point) and not ctx.unsafePosition(point) and navigation.safePath(ctx, point, 30) then
				local score = awareness.risk(ctx, point) * 3 + awareness.damage(ctx, point, 1) * 2
					+ ctx.distance(point, shelter) * 1.5
				if not bestScore or score < bestScore then best, bestScore = point, score end
			end
		end
		if not best then return false end
		task = {position = best, expires = ctx.now + 1.1}
		ctx.spacingTask = task
	end
	return ctx.move(task.position, "Step out of enemy attack reach", 35)
end

function positioning.lane(ctx, focus, plan)
	return laneSpacing.run(ctx, focus, plan)
end

local function imminentFarm(ctx)
	local farm = ctx.farmCandidate
	return farm and farm.start <= ctx.now + 0.6
end

function positioning.creepWaveFallback(ctx)
	if ctx.settings.creepFallback == false then return false end
	if ctx.retreating or ctx.hardRetreat or ctx.intent and ctx.intent.kind == "hero" then return false end
	if (ctx.nearEnemies or 0) > 0 or imminentFarm(ctx) then return false end
	local enemies, allied = {}, {}
	for _, creep in ipairs(ctx.creeps or {}) do
		if live(creep) and NPC.IsVisible(creep) and NPC.IsLaneCreep(creep) then
			if Entity.IsSameTeam(ctx.hero, creep) then allied[#allied + 1] = creep
			elseif ctx.distance(ctx.position, Entity.GetAbsOrigin(creep)) < 850 then enemies[#enemies + 1] = creep end
		end
	end
	if #enemies < 2 then return false end
	local anchor, anchorScore
	for _, creep in ipairs(allied) do
		local position = Entity.GetAbsOrigin(creep)
		if ctx.distance(ctx.position, position) < 1400 then
			local score = ctx.distance(ctx.position, position) - (NPC.IsRanged(creep) and 200 or 0)
			if not anchorScore or score < anchorScore then anchor, anchorScore = creep, score end
		end
	end
	for _, wave in ipairs(ctx.waves or {}) do
		for _, creep in ipairs(wave) do
			if live(creep) and ctx.distance(ctx.position, Entity.GetAbsOrigin(creep)) < 1400 then
				local score = ctx.distance(ctx.position, Entity.GetAbsOrigin(creep)) - 100
				if not anchorScore or score < anchorScore then anchor, anchorScore = creep, score end
			end
		end
	end
	local aggroed = (ctx.creepPressure or 0) > 0 or (ctx.meleePressure or 0) + (ctx.rangedPressure or 0) > 0
	if not aggroed then
		for _, creep in ipairs(enemies) do
			if (ctx.creepAggro or {})[Entity.GetIndex(creep)] and ctx.creepAggro[Entity.GetIndex(creep)] > ctx.now then aggroed = true; break end
		end
	end
	if anchor then
		local goal = ctx.toward(Entity.GetAbsOrigin(anchor), ctx.home, 120)
		if #allied == 0 or aggroed and ctx.distance(ctx.position, goal) > 90 then
			if ctx.unsafePosition(goal) or not GridNav.IsTraversable(goal) then return false end
			ctx.farmCandidate = nil
			return ctx.move(goal, "Creep wave fallback: regroup with allied wave", 45)
		end
		return false
	end
	if aggroed then
		for _, tower in ipairs(ctx.towers or {}) do
			if live(tower) and Entity.IsSameTeam(ctx.hero, tower) then
				local goal = ctx.toward(Entity.GetAbsOrigin(tower), ctx.home, 300)
				local distance = ctx.distance(ctx.position, Entity.GetAbsOrigin(tower))
				if distance < 1400 and not ctx.unsafePosition(goal) and GridNav.IsTraversable(goal) then
					ctx.farmCandidate = nil
					return ctx.move(goal, "Creep wave fallback: shed creep aggro at tower", 45)
				end
			end
		end
	end
	return false
end

function positioning.soakAlone(ctx)
	if ctx.settings.loneSoak == false then return false end
	if ctx.retreating or ctx.hardRetreat or ctx.intent then return false end
	if (ctx.nearEnemies or 0) > 0 or imminentFarm(ctx) then return false end
	if ctx.clock >= (ctx.laneEnd or 600) * 2 then return false end
	if ctx.afterDeath and ctx.now - (ctx.respawnedAt or 0) > 60 then ctx.afterDeath = nil end
	local mateDead = ctx.afterDeath == true
	if not mateDead then
		for _, ally in ipairs(Heroes.GetAll()) do
			if ally ~= ctx.hero and Entity.GetTeamNum(ally) == ctx.team
				and not NPC.IsIllusion(ally) and not NPC.IsMeepoClone(ally) and not Entity.IsAlive(ally) then
				mateDead = true
				break
			end
		end
	end
	if not mateDead then return false end
	for _, ally in ipairs(ctx.allies or {}) do
		if ally ~= ctx.hero and live(ally) and ctx.distance(ctx.position, Entity.GetAbsOrigin(ally)) < 1700 then return false end
	end
	local front, frontDistance
	for _, creep in ipairs(ctx.creeps or {}) do
		if live(creep) and NPC.IsLaneCreep(creep) and not Entity.IsSameTeam(ctx.hero, creep) then
			local distance = ctx.distance(ctx.position, Entity.GetAbsOrigin(creep))
			if distance < 1100 and (not frontDistance or distance < frontDistance) then
				front, frontDistance = creep, distance
			end
		end
	end
	if not front then return false end
	local frontPos = Entity.GetAbsOrigin(front)
	local best, bestScore
	local function consider(point)
		if not GridNav.IsTraversable(point) or ctx.unsafePosition(point) then return end
		if ctx.distance(point, frontPos) > 1400 then return end
		local score = awareness.risk(ctx, point) * 3 + awareness.damage(ctx, point, 1.5) * 2
			+ ctx.distance(point, ctx.home) * 0.05
		if not bestScore or score < bestScore then best, bestScore = point, score end
	end
	for _, creep in ipairs(ctx.creeps or {}) do
		if live(creep) and NPC.IsLaneCreep(creep) and Entity.IsSameTeam(ctx.hero, creep) then
			consider(ctx.toward(Entity.GetAbsOrigin(creep), ctx.home, 300))
		end
	end
	for _, tower in ipairs(ctx.towers or {}) do
		if live(tower) and Entity.IsSameTeam(ctx.hero, tower)
			and ctx.distance(ctx.position, Entity.GetAbsOrigin(tower)) < 1500 then
			consider(ctx.toward(Entity.GetAbsOrigin(tower), frontPos, 500))
		end
	end
	consider(ctx.position)
	if not best then return false end
	if ctx.distance(ctx.position, best) < 80 then return false end
	ctx.farmCandidate = nil
	return ctx.move(best, "Soak XP alone: hold safe creep range", 40)
end

function positioning.aggro(ctx)
	local farm, task = ctx.farmCandidate, ctx.aggroTask
	local threat = ctx.laneThreat
	if threat and (threat.attacked or threat.avoid or threat.lethal)
		or ctx.heroHarass and ctx.now - ctx.heroHarass.time < 1.8 then
		ctx.aggroTask, ctx.aggroStatus = nil, "Hero threat interrupted creep repositioning"
		ctx.nextAggro = math.max(ctx.nextAggro or 0, ctx.now + 3.1)
		return false
	end
	local imminent = farm and farm.start <= ctx.now + (farm.approach or 0) + NPC.GetTimeToFace(ctx.hero, farm.target) + 0.45
	if ctx.intent or ctx.retreating or ctx.runeTask or ctx.campTask or ctx.objectiveTask
		or ctx.teamTask and (ctx.teamTask.fighting or ctx.teamTask.kind ~= "protect")
		or ctx.clock < 35 or ctx.clock > 1200 or imminent or ctx.health < 0.4 then
		ctx.aggroTask = nil
		return false
	end
	if task then
		if ctx.now > task.expires or ctx.unsafePosition(task.goal) then ctx.aggroTask = nil; return false end
		if not task.progressPosition or ctx.distance(ctx.position, task.progressPosition) > 24 then
			task.progressPosition, task.progressAt = ctx.position, ctx.now
		elseif ctx.now - task.progressAt > 1 and ctx.distance(ctx.position, task.goal) > 90 then
			ctx.aggroTask, ctx.aggroStatus, ctx.nextAggro = nil, "Creep repositioning made no progress", ctx.now + 3.1
			return false
		end
		if not task.pull then
			if ctx.distance(ctx.position, task.goal) < 65 or ctx.creepPressure == 0 then ctx.aggroTask = nil; return false end
			return ctx.move(task.goal, "Bring pursuing creeps into allied tower cover", 40)
		end
		if not live(task.anchor) or not live(task.target) or not NPC.IsVisible(task.target) and task.stage == "approach"
			or awareness.damage(ctx, ctx.position, 1.2) > Entity.GetHealth(ctx.hero) * 0.17 then
			ctx.aggroTask = nil
			return false
		end
		if task.stage == "approach" then
			local eligible = 0
			for _, creep in ipairs(task.members) do
				if live(creep) and ctx.distance(ctx.position, Entity.GetAbsOrigin(creep)) < 480 then eligible = eligible + 1 end
			end
			if eligible == 0 then
				if not navigation.safePath(ctx, task.entry, 25) then ctx.aggroTask = nil; return false end
				return ctx.move(task.entry, "Enter melee creep aggro range", 20)
			end
			Player.AttackTarget(ctx.player, ctx.hero, task.target, false, false, true, "self_play_creep_aggro", false)
			task.stage, task.started, task.moveAt = "draw", ctx.now, ctx.now + 0.06
			ctx.lastOrder, ctx.attackTarget, ctx.nextAggro = "aggro", nil, ctx.now + 3.1
			ctx.nextDraw = ctx.now + 6
			return true
		end
		if ctx.now < task.moveAt then return true end
		local following, transferred = 0, 0
		for _, creep in ipairs(task.members) do
			if live(creep) then
				local position, id = Entity.GetAbsOrigin(creep), Entity.GetIndex(creep)
				local target = NPC.IsAttacking(creep) and NPC.FindFacingNPC(creep, nil, Enum.TeamType.TEAM_ENEMY, 20, NPC.GetAttackRange(creep) + 100)
				local remaining = ctx.distance(position, task.goal)
				local moved = NPC.IsRunning(creep) and remaining + 35 < task.distances[id]
				if moved then task.distances[id] = remaining end
				if target == ctx.hero or (ctx.creepAggro[id] or 0) > ctx.now or moved then following = following + 1 end
				if live(task.anchor) then
					local anchorDistance = ctx.distance(position, Entity.GetAbsOrigin(task.anchor))
					if target == task.anchor or anchorDistance < 260 and ctx.distance(position, ctx.position) > anchorDistance + 60 then transferred = transferred + 1 end
				end
			end
		end
		if following > 0 then task.confirmed, task.lastFollowing = true, ctx.now end
		if task.confirmed and following == 0 and ctx.now - task.lastFollowing > 0.6 then
			ctx.aggroTask, ctx.aggroStatus = nil, "Creeps stopped following; resume lane"
			return false
		end
		if ctx.now > task.started + 1.1 and not task.confirmed then
			ctx.aggroTask, ctx.aggroStatus = nil, "Aggro unconfirmed; wait for cooldown"
			return false
		end
		if ctx.now >= task.started + 2.35 and (transferred > 0 or ctx.distance(ctx.position, task.goal) < 70) then
			ctx.aggroTask, ctx.aggroStatus = nil, "Aggro released beside allied wave"
			return ctx.stop()
		end
		return ctx.move(task.goal, "Draw melee creeps toward allied ranged creep", 30)
	end
	if ctx.now < (ctx.nextAggro or 0) then return false end
	if ctx.creepPressure >= 2 and (ctx.health < 0.68 or ctx.nearEnemies > 0) then
		for _, tower in ipairs(ctx.towers) do
			if live(tower) and Entity.IsSameTeam(ctx.hero, tower) then
				local distance = ctx.distance(ctx.position, Entity.GetAbsOrigin(tower))
				local goal = ctx.toward(Entity.GetAbsOrigin(tower), ctx.position, 220)
				if distance > 300 and distance < 1100 and not ctx.unsafePosition(goal)
					and awareness.risk(ctx, goal) <= awareness.risk(ctx, ctx.position) + 20 then
					ctx.aggroTask = {goal = goal, expires = ctx.now + 3.2}
					return ctx.move(goal, "Bring pursuing creeps into allied tower cover", 40)
				end
			end
		end
	end
	if ctx.clock >= (ctx.laneEnd or 600) or ctx.mapFarm or ctx.health < 0.5 or ctx.creepPressure > 0 or ctx.now < (ctx.nextDraw or 0) then return false end
	local target, anchor, members, nearest, nearestDistance = nil, nil, {}, nil, 720
	local anchorScore = math.huge
	for _, creep in ipairs(ctx.creeps) do
		if live(creep) and NPC.IsVisible(creep) then
			local position = Entity.GetAbsOrigin(creep)
			local distance = ctx.distance(ctx.position, position)
			if Entity.IsSameTeam(ctx.hero, creep) and distance < 850 then
				local score = distance - (NPC.IsRanged(creep) and 400 or 0)
				if score < anchorScore then anchor, anchorScore = creep, score end
			elseif not Entity.IsSameTeam(ctx.hero, creep) and not NPC.IsRanged(creep) and distance < 720 then
				members[#members + 1] = creep
				if distance < nearestDistance then nearest, nearestDistance = creep, distance end
			end
		end
	end
	local targetDistance = -1
	for _, enemy in ipairs(ctx.enemies) do
		if live(enemy) and NPC.IsVisible(enemy) then
			local distance = ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy))
			if distance > targetDistance then target, targetDistance = enemy, distance end
		end
	end
	if not target or not nearest or not anchor then return false end
	local shelter = navigation.coverAnchor(ctx)
	local anchorPosition = Entity.GetAbsOrigin(anchor)
	local goal = ctx.toward(anchorPosition, shelter, 180)
	local nearestPosition = Entity.GetAbsOrigin(nearest)
	if ctx.distance(nearestPosition, anchorPosition) < 230 or ctx.distance(goal, shelter) >= ctx.distance(nearestPosition, shelter) - 100 then return false end
	local entry = ctx.toward(ctx.position, nearestPosition, math.max(0, nearestDistance - 450))
	local approach = ctx.distance(ctx.position, entry) / math.max(100, NPC.GetMoveSpeed(ctx.hero))
	if farm then
		local speed = math.max(100, NPC.GetMoveSpeed(ctx.hero))
		local draw = math.max(2.35, ctx.distance(entry, goal) / speed)
		local returnTime = ctx.distance(goal, farm.goal or ctx.position) / speed
		local turn = NPC.GetTimeToFace(ctx.hero, farm.target)
		if farm.start <= ctx.now + approach + draw + returnTime + turn + 0.15 then return false end
	end
	if ctx.distance(ctx.position, goal) > 650 or not navigation.safePath(ctx, entry, 25) or not navigation.safePath(ctx, goal, 25)
		or ctx.unsafePosition(entry) or ctx.unsafePosition(goal) or not GridNav.IsTraversable(goal)
		or awareness.damage(ctx, entry, 1.2) > Entity.GetHealth(ctx.hero) * 0.12 then return false end
	local distances, nearby = {}, {}
	for _, creep in ipairs(members) do
		if ctx.distance(entry, Entity.GetAbsOrigin(creep)) < 490 then
			nearby[#nearby + 1] = creep
			distances[Entity.GetIndex(creep)] = ctx.distance(Entity.GetAbsOrigin(creep), goal)
		end
	end
	if #nearby == 0 then return false end
	ctx.aggroTask = {stage = "approach", anchor = anchor, target = target, entry = entry, goal = goal, members = nearby,
		distances = distances, expires = ctx.now + approach + 3.2, pull = true}
	ctx.aggroStatus = "Reposition wave for safer last hits"
	return positioning.aggro(ctx)
end

function positioning.evade(ctx)
	if ctx.retreating or ctx.intent or ctx.creepPressure == 0 then ctx.evadeGoal = nil; return false end
	if positioning.fightCreeps(ctx) then ctx.evadeGoal = nil; return true end
	if laneRules.keepFarm(ctx.health, ctx.meleePressure, ctx.rangedPressure, ctx.farmCandidate ~= nil and ctx.farmCandidate ~= false) then
		ctx.evadeGoal = nil
		return false
	end
	if ctx.evadeUntil and ctx.now >= ctx.evadeUntil then ctx.evadeGoal = nil end
	if not ctx.evadeGoal and ctx.now < (ctx.nextEvade or 0) then return false end
	if not ctx.evadeGoal then
		local homeward = ctx.toward(ctx.position, ctx.home, ctx.creepPressure >= 3 and 220 or 160)
		local dx, dy = homeward.x - ctx.position.x, homeward.y - ctx.position.y
		local best, bestScore
		for _, angle in ipairs({0, -0.65, 0.65, -1.2, 1.2}) do
			local x = ctx.position.x + dx * math.cos(angle) - dy * math.sin(angle)
			local y = ctx.position.y + dx * math.sin(angle) + dy * math.cos(angle)
			local candidate = Vector(x, y, World.GetGroundZ(x, y))
			if GridNav.IsTraversable(candidate) and not ctx.unsafePosition(candidate) then
				local score = -ctx.distance(candidate, ctx.home) * 0.05
				for _, enemy in ipairs(ctx.enemies) do
					if live(enemy) then score = score - math.max(0, 1200 - ctx.distance(candidate, Entity.GetAbsOrigin(enemy))) end
				end
				for _, creep in ipairs(ctx.creeps) do
					if live(creep) and not Entity.IsSameTeam(ctx.hero, creep) then
						score = score - math.max(0, NPC.GetAttackRange(creep) + 180 - ctx.distance(candidate, Entity.GetAbsOrigin(creep)))
					end
				end
				if not bestScore or score > bestScore then best, bestScore = candidate, score end
			end
		end
		ctx.evadeGoal, ctx.evadeUntil, ctx.nextEvade = best or homeward, ctx.now + 0.7, ctx.now + 1.3
	end
	return ctx.move(ctx.evadeGoal, "Disengage from creep attacks", 30)
end

function positioning.fightCreeps(ctx)
	local task = ctx.clearTask
	local early = ctx.clock < math.min(1200, math.max(600, (ctx.laneEnd or 600) * 2))
	if ctx.retreating or ctx.intent or ctx.health < 0.55 or early and ctx.friendlyCreepCount == 0
		or task and (ctx.now > task.expires or ctx.distance(ctx.position, task.origin) > 900) then
		ctx.clearTask = nil
		return false
	end
	if ctx.role >= 4 and not ctx.baseDefense then
		local cover = false
		for _, ally in ipairs(ctx.allies or {}) do
			if ally ~= ctx.hero and live(ally) and not NPC.IsIllusion(ally)
				and Entity.GetHealth(ally) > Entity.GetMaxHealth(ally) * 0.4
				and ctx.distance(ctx.position, Entity.GetAbsOrigin(ally)) < 1300 then
				cover = true
				break
			end
		end
		if not cover then ctx.clearTask = nil; return false end
	end
	if not task and (ctx.creepPressure == 0 or ctx.farmCandidate and ctx.farmCandidate.start <= ctx.now + 0.5) then return false end
	for _, enemy in ipairs(ctx.enemies) do
		if live(enemy) and NPC.IsVisible(enemy) and ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy)) < 1100 then
			ctx.clearTask = nil
			return false
		end
	end
	local best, score, incoming, members = nil, math.huge, 0, {}
	local range = NPC.GetAttackRange(ctx.hero) + NPC.GetAttackRangeBonus(ctx.hero)
	for _, creep in ipairs(ctx.creeps) do
		if live(creep) and NPC.IsVisible(creep) and not Entity.IsSameTeam(ctx.hero, creep)
			and ctx.distance(ctx.position, Entity.GetAbsOrigin(creep)) < 650 then
			local id = Entity.GetIndex(creep)
			local chasing = (ctx.creepAggro[id] or 0) > ctx.now
			local retained = task and task.members[id] == creep
			if chasing or retained then
				incoming = incoming + NPC.GetTrueDamage(creep) * NPC.GetArmorDamageMultiplier(ctx.hero) * 3 / math.max(0.3, NPC.GetSecondsPerAttack(creep, false))
				members[id] = creep
			end
			local distance = ctx.distance(ctx.position, Entity.GetAbsOrigin(creep))
			if (chasing or retained) and distance <= range + 150 and not ctx.unsafePosition(Entity.GetAbsOrigin(creep))
				and (ctx.role <= 3 or laneRules.canLastHit(ctx, creep)) then
				local value = Entity.GetHealth(creep) / math.max(1, NPC.GetTrueDamage(ctx.hero) * NPC.GetArmorDamageMultiplier(creep)) + distance / 300
				if task and task.target == creep then value = value - 2 end
				if value < score then best, score = creep, value end
			end
		end
	end
	if not best or incoming > Entity.GetHealth(ctx.hero) * 0.23 then ctx.clearTask = nil; return false end
	ctx.clearTask = task or {members = members, origin = ctx.position, expires = ctx.now + 12}
	ctx.clearTask.target = best
	return ctx.attack(best, "Fight pursuing creeps")
end

function positioning.block(ctx, endTime)
	return creepBlock.run(ctx, endTime)
end

return positioning
