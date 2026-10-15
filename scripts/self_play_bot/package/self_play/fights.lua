local fights = {}
local awareness = require("self_play.awareness")
local engagement = require("self_play.engagement")
local navigation = require("self_play.navigation")
local intent = require("self_play.intent")
local taskPolicy = require("self_play.task_policy")

local function alive(unit)
	return unit and Entity.IsEntity(unit) and Entity.IsAlive(unit)
end

local function visible(unit)
	return alive(unit) and not Entity.IsDormant(unit) and NPC.IsVisible(unit)
end

function fights.hurt(ctx, data)
	if data.damage <= 0 or not visible(data.source) or not visible(data.target) or not NPC.IsHero(data.source) or not NPC.IsHero(data.target)
		or Entity.IsSameTeam(data.source, data.target) then return end
	local ally = Entity.IsSameTeam(ctx.hero, data.source) and data.source or data.target
	local enemy = ally == data.source and data.target or data.source
	if ally == ctx.hero or not Entity.IsSameTeam(ctx.hero, ally) then return end
	ctx.fightEvidence = ctx.fightEvidence or {}
	local id = Entity.GetIndex(enemy)
	local record = ctx.fightEvidence[id] or {target = enemy, allies = {}}
	record.allies[Entity.GetIndex(ally)] = {unit = ally, time = GameRules.GetGameTime()}
	ctx.fightEvidence[id] = record
	ctx.nextFightPlan = 0
end

local function position(ctx, target)
	if visible(target) then return Entity.GetAbsOrigin(target), 1 end
	return awareness.fogPosition(ctx, target)
end

local function retreatingHome(ctx, unit)
	local motion = ctx.history and ctx.history[Entity.GetIndex(unit)]
	if not motion or not NPC.IsRunning(unit) or not ctx.home then return false end
	local origin = Entity.GetAbsOrigin(unit)
	local hx, hy = ctx.home.x - origin.x, ctx.home.y - origin.y
	local length = math.sqrt(hx * hx + hy * hy)
	if length < 1 then return false end
	return (motion.vx * hx + motion.vy * hy) / length > 150
end

local function strength(unit)
	return NPC.GetTrueDamage(unit) / math.max(0.3, NPC.GetSecondsPerAttack(unit, false))
end

function fights.carryReady(ctx)
	if ctx.role ~= 1 then return true end
	local coreItems = 0
	for slot = 0, 5 do
		local item = NPC.GetItemByIndex(ctx.hero, slot)
		if item then
			local name = Ability.GetName(item):gsub("^item_", "")
			local record = ctx.catalog.items[name]
			if record and not record.consumable and not record.neutral and (record.cost or 0) >= 1800 then coreItems = coreItems + 1 end
		end
	end
	return coreItems >= 2
end

local boots = {
	item_boots = true, item_power_treads = true, item_phase_boots = true, item_arcane_boots = true,
	item_tranquil_boots = true, item_guardian_greaves = true, item_travel_boots = true,
	item_travel_boots_2 = true, item_boots_of_bearing = true,
}

function fights.midReady(ctx)
	if ctx.role ~= 2 then return true end
	local shod, core = false, false
	for slot = 0, 5 do
		local item = NPC.GetItemByIndex(ctx.hero, slot)
		if item then
			local name = Ability.GetName(item)
			if boots[name] then shod = true
			else
				local record = ctx.catalog.items[name:gsub("^item_", "")]
				if record and not record.consumable and not record.neutral and (record.cost or 0) >= 2000 then core = true end
			end
		end
	end
	return shod and core
end

function fights.canJoin(ctx, point)
	if ctx.role == 1 and not fights.carryReady(ctx) and ctx.baseDefense == nil then return false end
	return ctx.role ~= 2 or NPC.GetCurrentLevel(ctx.hero) >= 4 or ctx.baseDefense ~= nil
		or ctx.distance(ctx.position, point) <= 1800
end

function fights.plan(ctx)
	if ctx.now < (ctx.nextFightPlan or 0) then return ctx.fightSession end
	ctx.nextFightPlan = ctx.now + 0.15
	ctx.fightEvidence = ctx.fightEvidence or {}
	ctx.fightBlocked = ctx.fightBlocked or {}
	for id, expiry in pairs(ctx.fightBlocked) do if expiry <= ctx.now then ctx.fightBlocked[id] = nil end end
	local targets, seen = {}, {}
	for _, target in ipairs(ctx.enemies) do targets[#targets + 1], seen[target] = target, true end
	for _, record in pairs(ctx.memory) do
		if record.source and not seen[record.source] and ctx.now - record.time < 2.5 then targets[#targets + 1], seen[record.source] = record.source, true end
	end
	for id, record in pairs(ctx.fightEvidence) do
		for allyId, hit in pairs(record.allies) do if ctx.now - hit.time > 3 or not alive(hit.unit) then record.allies[allyId] = nil end end
		if not alive(record.target) or next(record.allies) == nil then ctx.fightEvidence[id] = nil end
	end
	local best, bestScore
	for _, target in ipairs(targets) do
		local point, confidence = position(ctx, target)
		if point and confidence >= 0.4 and fights.canJoin(ctx, point) and not ctx.fightBlocked[Entity.GetIndex(target)] and not NPC.IsIllusion(target) and ctx.distance(ctx.position, point) < 6500 then
			local id = Entity.GetIndex(target)
			local record = ctx.fightEvidence[id] or {target = target, allies = {}}
			local recent = ctx.allyFights and ctx.allyFights[id]
			if recent and ctx.now - recent.time < 3 and alive(recent.ally) then
				record.allies[Entity.GetIndex(recent.ally)] = {unit = recent.ally, time = recent.time}
				ctx.fightEvidence[id] = record
			end
			local members, dps, lastEvidence, fleeing = {}, 0, 0, 0
			for _, ally in ipairs(ctx.allies) do
				if ally ~= ctx.hero and visible(ally) and not NPC.IsIllusion(ally) and Hero.GetReplicatingOtherHeroModel(ally) == nil
					and Entity.GetHealth(ally) > Entity.GetMaxHealth(ally) * 0.15 and ctx.distance(Entity.GetAbsOrigin(ally), point) < 1300 then
					local attacking = visible(target) and (NPC.IsAttacking(ally) and NPC.FindFacingNPC(ally, nil, Enum.TeamType.TEAM_ENEMY, 30,
						NPC.GetAttackRange(ally) + NPC.GetAttackRangeBonus(ally) + 200) == target
						or NPC.IsAttacking(target) and NPC.FindFacingNPC(target, nil, Enum.TeamType.TEAM_ENEMY, 30, NPC.GetAttackRange(target) + 200) == ally)
					local allyId = Entity.GetIndex(ally)
					if attacking then record.allies[allyId] = {unit = ally, time = ctx.now}; ctx.fightEvidence[id] = record end
					local evidence = record.allies[allyId]
					if evidence and ctx.now - evidence.time < 3 then
						members[#members + 1] = ally
						dps, lastEvidence = dps + strength(ally), math.max(lastEvidence, evidence.time)
						if retreatingHome(ctx, ally) then fleeing = fleeing + 1 end
					end
				end
			end
			if #members > 0 then
				local range = NPC.GetAttackRange(ctx.hero) + NPC.GetAttackRangeBonus(ctx.hero)
				local spacing = visible(target) and math.max(100, range - 40) or 150
				local goal = ctx.distance(ctx.position, point) <= spacing and ctx.position or ctx.toward(point, ctx.position, spacing)
				local incoming = awareness.damage(ctx, goal, 2) + awareness.forecast(ctx, goal) * 0.5
				local instant = awareness.damage(ctx, ctx.position, 0.75) + awareness.forecast(ctx, ctx.position) * 0.2
				local hostile = 0
				for _, enemy in ipairs(ctx.enemies) do if visible(enemy) and ctx.distance(Entity.GetAbsOrigin(enemy), point) < 1200 then hostile = hostile + strength(enemy) end end
				local burst = visible(target) and awareness.burst(ctx, ctx.hero, target, range, 2) or 0
				local hp = Entity.GetHealth(ctx.hero)
				local support = dps + strength(ctx.hero) + burst / 3 >= hostile * 0.85
				local joining = dps + strength(ctx.hero) >= hostile * 0.45
				local useful = incoming < hp * 0.55 and instant < hp * 0.55
					and fleeing <= #members / 2
					and (support or joining or visible(target) and Entity.GetHealth(target) < burst)
				local farAlone = ctx.role >= 4 and #members < 2 and ctx.distance(ctx.position, point) > 3000
				if useful and not farAlone and not ctx.unsafePosition(goal) and GridNav.IsTraversable(goal) then
					local retained = ctx.fightSession and ctx.fightSession.target == target
					local score = #members * 120 + (retained and 220 or 0) + (visible(target) and NPC.IsChannellingAbility(target) and 160 or 0)
						+ (visible(target) and math.max(0, 1 - Entity.GetHealth(target) / math.max(1, Entity.GetMaxHealth(target))) * 220 or 0)
						- ctx.distance(ctx.position, goal) * 0.08
					if not bestScore or score > bestScore then
						best, bestScore = {target = target, members = members, goal = goal, evidence = lastEvidence,
							confidence = confidence, incoming = incoming, distance = ctx.distance(ctx.position, point), stage = visible(target) and "engage" or "search"}, score
					end
				end
			end
		end
	end
	if not best then
		ctx.fightSession, ctx.fightStatus = nil, "No confirmed allied fight with a survivable approach"
		return nil
	end
	local old = ctx.fightSession
	if old and old.target == best.target then
		best.progressAt, best.progressPosition = old.progressAt, old.progressPosition
		best.route = old.route
	end
	taskPolicy.progress(ctx, best, best.goal)
	best.health = visible(best.target) and Entity.GetHealth(best.target) or old and old.health or 0
	if ctx.now - best.progressAt > 4 and ctx.distance(ctx.position, best.goal) > 250 then
		ctx.fightBlocked[Entity.GetIndex(best.target)] = ctx.now + 3
		ctx.fightSession, ctx.fightStatus = nil, "Fight approach obstructed; reassess route"
		return nil
	end
	ctx.fightSession = best
	ctx.fightStatus = best.stage == "search" and "Follow recent fight observation" or "Confirmed allied combat owns current task"
	ctx.regroupTask, ctx.campTask, ctx.clearTask, ctx.runeTask, ctx.riverTask, ctx.objectiveTask, ctx.aggroTask = nil, nil, nil, nil, nil, nil, nil
	return best
end

function fights.task(ctx)
	local fight = ctx.fightSession
	return fight and {kind = "group", combat = true, fighting = true, target = fight.target, members = fight.members,
		goal = fight.goal, expires = ctx.now + 0.5}
end

function fights.run(ctx)
	local task = ctx.fightSession
	if not task or ctx.retreating or ctx.hardRetreat then return false end
	if not alive(task.target) then ctx.fightSession, ctx.teamTask = nil, nil; return false end
	local point, confidence = position(ctx, task.target)
	if not point or confidence < 0.4 or not fights.canJoin(ctx, point) then ctx.fightSession, ctx.teamTask = nil, nil; return false end
	if not visible(task.target) then
		if ctx.distance(ctx.position, task.goal) < 90 then ctx.mode = "Check briefly hidden fight target"; return ctx.stop() end
		return ctx.move(task.goal, "Follow enemy from recent allied fight", 60)
	end
	ctx.target = task.target
	local distance = ctx.distance(ctx.position, point)
	if NPC.IsRanged(ctx.hero) and not NPC.IsRanged(task.target) and distance < 350 and distance > 150
		and NPC.IsRunning(task.target) and ctx.now < ctx.attackNext then
		local hx, hy = ctx.position.x - point.x, ctx.position.y - point.y
		local length = math.max(1, math.sqrt(hx * hx + hy * hy))
		local kite = Vector(ctx.position.x + hx / length * 150, ctx.position.y + hy / length * 150, ctx.position.z)
		if GridNav.IsTraversable(kite) and not ctx.unsafePosition(kite) then
			return ctx.move(kite, "Kite melee diver between attacks", 20)
		end
	end
	if distance > 1350 then
		if ctx.fightAbilities() then return true end
		if distance > 3000 and ctx.health >= 0.7 and ctx.teleport(task.goal, "fight") then return true end
		local route = task.route
		if not route or ctx.now >= route.expires or ctx.distance(route.goal, task.goal) > 180
			or ctx.distance(ctx.position, route.point) < 100 then
			local length = navigation.safePath(ctx, task.goal)
			local point = length and task.goal or navigation.detour(ctx, task.goal)
			if not point then
				ctx.fightBlocked = ctx.fightBlocked or {}
				ctx.fightBlocked[Entity.GetIndex(task.target)] = ctx.now + 3
				ctx.fightSession, ctx.teamTask = nil, nil
				ctx.fightStatus = "No traversable approach to allied fight"
				return false
			end
			route = {point = point, goal = task.goal, expires = ctx.now + 0.5}
			task.route = route
		end
		return ctx.move(route.point, "Approach enemy in allied fight", 60)
	end
	intent.begin(ctx, task.target, "hero", false)
	ctx.intent.expires, ctx.intent.opportunity = ctx.now + 2, 100
	local swing = ctx.hits.ordered
	if swing and swing.target == task.target and swing.confirmed and swing.release <= ctx.now then ctx.intent.followAttack = false end
	local locked = ctx.heroModule and ctx.heroModule.locked and ctx.heroModule.locked(ctx)
	if (not ctx.intent.followAttack or locked) and ctx.fightAbilities() then return true end
	if NPC.HasState(task.target, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE) or NPC.HasState(task.target, Enum.ModifierState.MODIFIER_STATE_ATTACK_IMMUNE) then
		ctx.mode = "Keep attack access while enemy is temporarily untargetable"
		return ctx.stop()
	end
	return ctx.attack(task.target, "Fight with allies: focus confirmed opponent")
end

return fights
