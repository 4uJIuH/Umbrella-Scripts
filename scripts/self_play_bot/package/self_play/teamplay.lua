local teamplay = {}
local awareness = require("self_play.awareness")
local towerSafety = require("self_play.tower_safety")
local intent = require("self_play.intent")
local engagement = require("self_play.engagement")
local roshan = require("self_play.roshan")
local helpRotation = require("self_play.help_rotation")
local fights = require("self_play.fights")
local baseDefense = require("self_play.base_defense")
local taskPolicy = require("self_play.task_policy")

teamplay.escape, teamplay.loot = roshan.escape, roshan.loot

function teamplay.dying(ctx, npc)
	if ctx.roshanState and ctx.roshanState.target == npc or ctx.teamTask and ctx.teamTask.kind == "roshan" and ctx.teamTask.target == npc then
		ctx.roshanLoot = {position = Entity.GetAbsOrigin(npc), expires = GameRules.GetGameTime() + 12}
		ctx.roshanState, ctx.teamTask = nil, nil
	end
end

local function visible(unit)
	return unit and Entity.IsEntity(unit) and Entity.IsAlive(unit) and not Entity.IsDormant(unit) and NPC.IsVisible(unit)
end

local function ally(ctx, unit)
	return unit ~= ctx.hero and visible(unit) and not NPC.IsIllusion(unit)
		and Hero.GetReplicatingOtherHeroModel(unit) == nil
		and Entity.GetHealth(unit) > Entity.GetMaxHealth(unit) * 0.4
		and ctx.distance(Entity.GetAbsOrigin(unit), ctx.home) > 2000
end

function teamplay.hurt(ctx, data)
	baseDefense.hurt(ctx, data)
	fights.hurt(ctx, data)
	roshan.hurt(ctx, data)
	if data.damage > 0 and visible(data.target) and NPC.IsStructure(data.target) and not Entity.IsSameTeam(ctx.hero, data.target)
		and visible(data.source) and NPC.IsHero(data.source) and ally(ctx, data.source) and Entity.IsSameTeam(ctx.hero, data.source) then
		ctx.siegeDamage = ctx.siegeDamage or {}
		ctx.siegeDamage[Entity.GetIndex(data.target)] = {source = data.source, time = GameRules.GetGameTime()}
	end
	if data.damage > 0 and visible(data.target) and NPC.IsRoshan(data.target)
		and visible(data.source) and data.source ~= ctx.hero and Entity.IsSameTeam(ctx.hero, data.source) then
		ctx.roshanDamage = {target = data.target, time = GameRules.GetGameTime()}
	end
	if data.damage <= 0 or not visible(data.source) or not visible(data.target) or not NPC.IsHero(data.source) or not NPC.IsHero(data.target)
		or Entity.IsSameTeam(data.source, data.target) then return end
	local friendly = Entity.IsSameTeam(ctx.hero, data.source) and data.source or data.target
	local enemy = friendly == data.source and data.target or data.source
	if ally(ctx, friendly) then
		ctx.allyFights = ctx.allyFights or {}
		ctx.allyFights[Entity.GetIndex(enemy)] = {target = enemy, ally = friendly, time = GameRules.GetGameTime(), outgoing = friendly == data.source}
	end
end

local function pushPlan(ctx)
	local previous = ctx.teamTask and ctx.teamTask.kind == "push" and ctx.teamTask
	local best, bestScore
	ctx.pushBlocked = ctx.pushBlocked or {}
	for id, expiry in pairs(ctx.pushBlocked) do if expiry <= ctx.now then ctx.pushBlocked[id] = nil end end
	for id, hit in pairs(ctx.siegeDamage or {}) do if ctx.now - hit.time > 4 then ctx.siegeDamage[id] = nil end end
	for _, structure in ipairs(ctx.structures) do
		if visible(structure) and not Entity.IsSameTeam(ctx.hero, structure) and not ctx.pushBlocked[Entity.GetIndex(structure)] then
			local position = Entity.GetAbsOrigin(structure)
			local distance = ctx.distance(ctx.position, position)
			local attackers = towerSafety.attackers(ctx, structure)
			local hit = ctx.siegeDamage and ctx.siegeDamage[Entity.GetIndex(structure)]
			if hit and ally(ctx, hit.source) and ctx.distance(Entity.GetAbsOrigin(hit.source), position) < 1200 then attackers = math.max(1, attackers) end
			if attackers == 0 and towerSafety.siege(ctx, structure) > 0 then attackers = 1 end
			local present = 0
			for _, hero in ipairs(ctx.allies) do
				if ally(ctx, hero) and ctx.distance(Entity.GetAbsOrigin(hero), position) < 1200 then present = present + 1 end
			end
			local retained = previous and previous.target == structure and present > 0 and ctx.now < previous.expires
			local homeLane = ctx.homeLane or ctx.lane
			local structLane = math.abs(position.x - position.y) < 2000 and 2 or position.y > position.x and 1 or 3
			if ctx.settings.laneDiscipline ~= false and not ctx.isTurbo and structLane ~= homeLane
				and ctx.role <= 3 and ctx.clock < (ctx.laneEnd or 600) and not retained then
			elseif distance < 6500 and (attackers >= 2 or attackers == 1 and distance < 2500 or retained) then
				local score = attackers * 500 - distance * 0.2 + (retained and 900 or 0)
				if not bestScore or score > bestScore then
					best = {kind = "push", target = structure, goal = position,
						expires = attackers > 0 and ctx.now + 4 or previous.expires,
						progressAt = retained and previous.progressAt or ctx.now,
						progressPosition = retained and previous.progressPosition or ctx.position,
						waitSince = retained and previous.waitSince or nil}
					bestScore = score
				end
			end
		end
	end
	if not best then return false end
	ctx.teamTask, ctx.regroupTask, ctx.campTask = best, nil, nil
	ctx.objectiveTask, ctx.runeTask = nil, nil
	return true
end

local function rotation(ctx, members, center, vx, vy, moving)
	if ctx.clock < (ctx.laneEnd or 600) or moving < 2 or ctx.now < (ctx.nextGroupRotation or 0) then return nil end
	if ctx.role == 1 and not fights.carryReady(ctx) then return nil end
	if ctx.role <= 3 and not ctx.isTurbo and ctx.settings.carryHoldLane ~= false and not ctx.fullBuild
		and ctx.nearAllies == 0 then return nil end
	local motion = math.sqrt(vx * vx + vy * vy)
	if motion / moving < 160 then return nil end
	local ids, alignment = {}, 0
	for _, hero in ipairs(members) do
		ids[#ids + 1] = Entity.GetIndex(hero)
		local velocity = ctx.history[Entity.GetIndex(hero)]
		if velocity and NPC.IsRunning(hero) then
			local speed = math.sqrt(velocity.vx * velocity.vx + velocity.vy * velocity.vy)
			if speed > 100 and (velocity.vx * vx + velocity.vy * vy) / (speed * motion) > 0.85 then alignment = alignment + 1 end
		end
	end
	if alignment < 2 or alignment < #members * 0.65 then return nil end
	local objective, closest = nil, 2600
	local function consider(unit)
		if not visible(unit) or Entity.IsSameTeam(ctx.hero, unit) then return end
		if not NPC.IsHero(unit) and not NPC.IsTower(unit) and not NPC.IsBarracks(unit) and not NPC.IsFort(unit) then return end
		local p = Entity.GetAbsOrigin(unit)
		local distance = ctx.distance(center, p)
		if distance > 450 and distance < closest and ((p.x - center.x) * vx + (p.y - center.y) * vy) / math.max(1, distance * motion) > 0.75 then
			objective, closest = unit, distance
		end
	end
	for _, enemy in ipairs(ctx.enemies) do consider(enemy) end
	if #members >= 3 then for _, structure in ipairs(ctx.structures) do consider(structure) end end
	if not objective then return nil end
	table.sort(ids)
	local key = table.concat(ids, ":") .. ":" .. Entity.GetIndex(objective)
	ctx.groupTracks = ctx.groupTracks or {}
	for id, track in pairs(ctx.groupTracks) do if ctx.now - track.seen > 4 then ctx.groupTracks[id] = nil end end
	local track = ctx.groupTracks[key]
	if not track or ctx.now - track.seen > 1 or (track.vx * vx + track.vy * vy) / math.max(1, track.motion * motion) < 0.7 then
		track = {since = ctx.now, origin = center, vx = vx, vy = vy, motion = motion}
		ctx.groupTracks[key] = track
	end
	track.seen = ctx.now
	if ctx.now - track.since < 1.2 or ctx.distance(track.origin, center) < 160 then return nil end
	return objective, key
end

function teamplay.plan(ctx)
	if baseDefense.update(ctx) then
		roshan.cancel(ctx)
		ctx.teamTask = {kind = "defend", goal = ctx.baseDefense.position, expires = ctx.baseDefense.expires}
		return
	end
	if helpRotation.update(ctx) then return end
	if fights.plan(ctx) and not ctx.retreating and not ctx.hardRetreat then ctx.teamTask = fights.task(ctx); return end
	if ctx.roshanState and not visible(ctx.roshanState.target) then roshan.cancel(ctx) end
	if ctx.clock < 120 or ctx.retreating or ctx.health < 0.55 then roshan.cancel(ctx); ctx.teamTask = nil; return end
	if ctx.now < (ctx.nextTeamPlan or 0) then return end
	ctx.nextTeamPlan = ctx.now + 0.4
	if ctx.roshanDamage and ctx.now - ctx.roshanDamage.time > 3 then ctx.roshanDamage = nil end
	for id, fight in pairs(ctx.allyFights or {}) do if ctx.now - fight.time > 3 then ctx.allyFights[id] = nil end end
	for _, unit in ipairs(ctx.worldNPCs) do
		if visible(unit) and NPC.IsRoshan(unit) and ctx.distance(ctx.position, Entity.GetAbsOrigin(unit)) < 6500 then
			local position, count, attackers, enemies = Entity.GetAbsOrigin(unit), 0, 0, 0
			for _, hero in ipairs(ctx.allies) do
				if ally(ctx, hero) and ctx.distance(Entity.GetAbsOrigin(hero), position) < 1200 then
					count = count + 1
					if NPC.IsAttacking(hero) and NPC.FindFacingNPC(hero, nil, Enum.TeamType.TEAM_ENEMY, 25, NPC.GetAttackRange(hero) + 200) == unit then attackers = attackers + 1 end
				end
			end
			for _, enemy in ipairs(ctx.enemies) do
				if visible(enemy) and ctx.distance(Entity.GetAbsOrigin(enemy), position) < 1600 then enemies = enemies + 1 end
			end
			if ctx.roshanDamage and ctx.roshanDamage.target == unit then attackers = math.max(1, attackers) end
			if count >= 2 and attackers > 0 and enemies == 0 and ctx.health >= 0.65 then
				ctx.roshanState = nil
				ctx.teamTask = {kind = "roshan", target = unit, goal = position, expires = ctx.now + 0.6}
				return
			end
			local solo = roshan.plan(ctx, unit)
			if solo then ctx.teamTask = solo; return end
		end
	end
	if ctx.roshanState then roshan.cancel(ctx) end
	if pushPlan(ctx) then return end
	local best, bestScore
	for _, leader in ipairs(ctx.allies) do
		if ally(ctx, leader) then
			local origin, members, x, y, vx, vy, moving = Entity.GetAbsOrigin(leader), {}, 0, 0, 0, 0, 0
			for _, hero in ipairs(ctx.allies) do
				if ally(ctx, hero) and ctx.distance(Entity.GetAbsOrigin(hero), origin) < 950 then
					local position = Entity.GetAbsOrigin(hero)
					members[#members + 1], x, y = hero, x + position.x, y + position.y
					local motion = ctx.history[Entity.GetIndex(hero)]
					if NPC.IsRunning(hero) and motion and motion.vx * motion.vx + motion.vy * motion.vy > 6400 then
						vx, vy, moving = vx + motion.vx, vy + motion.vy, moving + 1
					end
				end
			end
			if #members >= 2 then
				local center = Vector(x / #members, y / #members, origin.z)
				local distance, motion = ctx.distance(ctx.position, center), math.sqrt(vx * vx + vy * vy)
				local objective, key = rotation(ctx, members, center, vx, vy, moving)
				if objective and distance < (#members >= 3 and 6500 or 4500) and not ctx.unsafePosition(center) then
					local goal = motion > 100 and Vector(center.x - vx / motion * 350, center.y - vy / motion * 350, center.z)
						or ctx.toward(center, ctx.home, 350)
					local score = #members * 500 - distance * 0.25
					if not bestScore or score > bestScore then
						best, bestScore = {kind = "group", members = members, goal = goal, fighting = false,
							objective = objective, key = key, expires = ctx.now + 1.5}, score
					end
				end
			end
		end
	end
	if best then
		if ctx.role == 1 and not fights.carryReady(ctx) then
			ctx.nextGroupRotation = ctx.now + 4
		elseif ctx.role <= 3 and not ctx.isTurbo and ctx.settings.carryHoldLane ~= false and not ctx.fullBuild and ctx.nearAllies == 0 then
			ctx.nextGroupRotation = ctx.now + 4
		else
			local previous = ctx.teamTask
			if previous and best.key and best.key == previous.key then
				best.progressAt, best.distance, best.progressPosition = previous.progressAt, previous.distance, previous.progressPosition
			end
			ctx.teamTask = best
		end
	elseif ctx.teamTask and (ctx.teamTask.kind ~= "group" or ctx.now >= ctx.teamTask.expires) then
		if ctx.teamTask.kind == "group" and not ctx.teamTask.fighting then ctx.nextGroupRotation = ctx.now + 4 end
		ctx.teamTask = nil
	end
end

function teamplay.run(ctx)
	if ctx.helpRotation and ctx.helpRotation.phase == "channel" then
		ctx.mode = "Teleport to allied fight: awaiting landing"
		return true
	end
	local task = ctx.teamTask
	if task and task.kind == "defend" then return false end
	if task and task.combat then return fights.run(ctx) end
	if not task or ctx.retreating or ctx.now > task.expires then ctx.teamTask = nil; return false end
	if task.kind == "roshan" then
		if task.solo then return roshan.run(ctx, task) end
		if not visible(task.target) or ctx.health < 0.65 then ctx.teamTask = nil; return false end
		return roshan.attack(ctx, task.target, "Help allies take Roshan")
	end
	if task.kind == "push" then
		if not visible(task.target) then
			ctx.teamTask = nil
			return false
		end
		local position = Entity.GetAbsOrigin(task.target)
		local covered = ctx.pushSafe(task.target)
		if not covered or ctx.distance(ctx.position, position) > 1300 then
			if ctx.intent and ctx.intent.kind == "structure" then ctx.intent = nil end
			local defender, bestScore
			local range = NPC.GetAttackRange(ctx.hero) + NPC.GetAttackRangeBonus(ctx.hero)
			for _, creep in ipairs(ctx.creeps) do
				if visible(creep) and NPC.IsLaneCreep(creep) and not Entity.IsSameTeam(ctx.hero, creep) then
					local point = Entity.GetAbsOrigin(creep)
					local distance = ctx.distance(ctx.position, point)
					local firing = distance <= range and ctx.position or ctx.toward(point, ctx.position, math.max(50, range - 35))
					if distance < range + 250 and ctx.distance(point, position) < 1400 and not ctx.unsafePosition(firing) then
						local score = Entity.GetHealth(creep) + distance * 0.3
						if not bestScore or score < bestScore then defender, bestScore = creep, score end
					end
				end
			end
			if defender and ctx.attack(defender, "Clear defending creeps for allied push") then return true end
			local goal = covered and engagement.attackPosition(ctx, task.target)
				or ctx.toward(position, ctx.position, math.max(range - 35, NPC.GetAttackRange(task.target) + 200))
			if ctx.unsafePosition(goal) or not GridNav.IsTraversable(goal) then ctx.teamTask = nil; return false end
			taskPolicy.progress(ctx, task, goal)
			if not covered and ctx.distance(ctx.position, goal) < 140 then task.waitSince = task.waitSince or ctx.now
			else task.waitSince = nil end
			if task.waitSince and ctx.now - task.waitSince > 3 or ctx.now - task.progressAt > 6 then
				ctx.pushBlocked = ctx.pushBlocked or {}
				ctx.pushBlocked[Entity.GetIndex(task.target)] = ctx.now + 8
				ctx.teamTask = nil
				return false
			end
			return ctx.move(goal, covered and "Approach allied structure push" or "Wait for cover with allied push", 80)
		end
		intent.begin(ctx, task.target, "structure", false)
		return intent.run(ctx)
	end
	local count = 0
	for _, hero in ipairs(task.members) do if ally(ctx, hero) and ctx.distance(Entity.GetAbsOrigin(hero), task.goal) < 1300 then count = count + 1 end end
	if count < (task.fighting and 1 or 2) then ctx.teamTask = nil; return false end
	if task.fighting then
		local point = visible(task.target) and Entity.GetAbsOrigin(task.target) or task.goal
		if not fights.canJoin(ctx, point) then ctx.teamTask = nil; return false end
		if task.help and not visible(task.target) then return ctx.move(task.goal, "Reconnect with allied fight after teleport", 60) end
		if not visible(task.target) or ctx.unsafePosition(engagement.attackPosition(ctx, task.target)) then ctx.teamTask = nil; return false end
		ctx.target = task.target
		if ctx.distance(ctx.position, Entity.GetAbsOrigin(task.target)) <= 1350 then
			intent.begin(ctx, task.target, "hero", false)
			if intent.run(ctx) then return true end
			if task.help then
				local goal = ctx.toward(task.goal, ctx.home, 250)
				if not ctx.unsafePosition(goal) then return ctx.move(goal, "Find safe opening with allied fight", 60) end
			end
			return false
		end
		if ctx.distance(ctx.position, task.goal) > 2200 and ctx.teleport(task.goal, "fight") then return true end
		return ctx.move(task.goal, "Approach enemy in allied fight", 60)
	end
	if not visible(task.objective) then ctx.teamTask = nil; return false end
	if ctx.farmCandidate and ctx.farmCandidate.start <= ctx.now + 0.5 then return false end
	taskPolicy.progress(ctx, task, task.goal)
	if ctx.now - task.progressAt > 4 and ctx.distance(ctx.position, task.goal) > 300 then
		ctx.teamTask, ctx.nextGroupRotation = nil, ctx.now + 4
		return false
	end
	return ctx.move(task.goal, "Join confirmed allied rotation", 160)
end

function teamplay.hunt(ctx)
	if ctx.settings.turboHunt == false or not ctx.isTurbo then return false end
	if (ctx.role or 5) > 3 or ctx.retreating or ctx.hardRetreat then return false end
	if ctx.intent or ctx.teamTask and ctx.teamTask.fighting or ctx.fightSession then return false end
	local farm = ctx.farmCandidate
	if farm and farm.start <= ctx.now + 0.5 then return false end
	local range = NPC.GetAttackRange(ctx.hero) + NPC.GetAttackRangeBonus(ctx.hero)
	local best, bestScore
	for _, enemy in ipairs(ctx.enemies or {}) do
		if visible(enemy) and not NPC.IsIllusion(enemy) then
			local position = Entity.GetAbsOrigin(enemy)
			local distance = ctx.distance(ctx.position, position)
			if distance < 4500 and distance > range + 150 then
				local enemyLevel = NPC.GetCurrentLevel(enemy)
				local hostile, isolated = 0, true
				for _, other in ipairs(ctx.enemies) do
					if other ~= enemy and visible(other) and ctx.distance(Entity.GetAbsOrigin(other), position) < 1200 then
						hostile, isolated = hostile + 1, false
					end
				end
				local goal = ctx.toward(position, ctx.position, 950)
				if GridNav.IsTraversable(goal) and not ctx.unsafePosition(goal)
					and awareness.damage(ctx, goal, 2) < Entity.GetHealth(ctx.hero) * 0.4 then
					local healthFraction = Entity.GetHealth(enemy) / math.max(1, Entity.GetMaxHealth(enemy))
					local score = (1 - healthFraction) * 120 + math.max(0, NPC.GetCurrentLevel(ctx.hero) - enemyLevel) * 25
						+ (isolated and 40 or hostile * -30) - distance * 0.03
					if not bestScore or score > bestScore then best, bestScore = goal, score end
				end
			end
		end
	end
	if not best or (bestScore or 0) < 20 then return false end
	ctx.campTask, ctx.spacingTask, ctx.aggroTask = nil, nil, nil
	return ctx.move(best, "Turbo hunt: join XP range of weak isolated enemy", 80)
end

return teamplay
