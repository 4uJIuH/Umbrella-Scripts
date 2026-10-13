local lastHit = {}

local navigation = require("self_play.navigation")
local timeline = require("self_play.timeline")
local laneRules = require("self_play.lane_rules")
local awareness = require("self_play.awareness")
local positioning = require("self_play.positioning")
local geometry = require("self_play.lane_geometry")
local cfg = {horizon = 3, wait = 2.2, margin = 1 / 30, searchRange = 1300, pathAge = 0.1}

local function live(unit)
	return unit and Entity.IsEntity(unit) and Entity.IsAlive(unit) and not Entity.IsDormant(unit)
end

function lastHit.init(ctx)
	ctx.hits = {events = {}, cycles = {}, profiles = {}, paths = {}, failures = {}, blocked = {}, retries = {}, serial = 0, confirmed = 0, cancelled = 0}
end

local function flight(ctx, attacker, target, speed, origin, lead)
	if not NPC.IsRanged(attacker) then return 0 end
	speed = speed or NPC.GetAttackProjectileSpeed(attacker)
	if not speed or speed <= 0 then return 0 end
	origin = origin or Entity.GetAbsOrigin(attacker)
	local travel = ctx.distance(origin, Entity.GetAbsOrigin(target)) / speed
	for _ = 1, 3 do
		travel = math.max(0, ctx.distance(origin, ctx.predict(target, travel + (lead or 0))) - NPC.GetHullRadius(target)) / speed
	end
	return math.min(cfg.horizon, travel)
end

function lastHit.timing(ctx, target, origin, approach)
	local basePoint = ctx.hits.observedPoint or NPC.GetAttackAnimPoint(ctx.hero)
	if not basePoint then return nil end
	local point = basePoint / math.max(0.2, NPC.GetAttackSpeed(ctx.hero))
	local turn = NPC.GetTimeToFace(ctx.hero, target)
	if origin and approach and approach > 0 and ctx.distance(ctx.position, origin) > 20 then
		local destination = Entity.GetAbsOrigin(target)
		local ax, ay = origin.x - ctx.position.x, origin.y - ctx.position.y
		local bx, by = destination.x - origin.x, destination.y - origin.y
		local length = math.sqrt((ax * ax + ay * ay) * (bx * bx + by * by))
		if length > 1 then
			local angle = math.acos(math.max(-1, math.min(1, (ax * bx + ay * by) / length)))
			local forward = Entity.GetRotation(ctx.hero):GetForward()
			local behind = Vector(ctx.position.x - forward.x * 100, ctx.position.y - forward.y * 100, ctx.position.z)
			turn = math.max(turn, NPC.GetTimeToFacePosition(ctx.hero, behind) * angle / math.pi)
		end
	end
	local windup = point + turn + NetChannel.GetAvgLatency(Enum.Flow.FLOW_OUTGOING)
	return windup + flight(ctx, ctx.hero, target, nil, origin, (approach or 0) + windup), windup
end

local function damage(attacker, target, ctx)
	local scale = NPC.GetArmorDamageMultiplier(target)
	local bonus = 0
	if ctx and attacker == ctx.hero and NPC.IsLaneCreep(target) and not Entity.IsSameTeam(attacker, target) then
		for slot = 0, 5 do
			local item = NPC.GetItemByIndex(attacker, slot)
			local record = item and ctx.catalog.items[Ability.GetName(item):gsub("^item_", "")]
			if record and record.creepBonus then
				bonus = math.max(bonus, NPC.IsRanged(attacker) and record.creepRangedBonus or record.creepBonus)
			end
		end
	end
	if NPC.IsLaneCreep(target) and NPC.GetAbility(attacker, "creep_piercing") then
		scale = scale * (NPC.GetUnitName(target):find("ranged", 1, true) and 1.5 or 0.5)
	end
	local minimum, maximum = (NPC.GetTrueDamage(attacker) + bonus) * scale, (NPC.GetTrueMaximumDamage(attacker) + bonus) * scale
	local profile = ctx and attacker ~= ctx.hero and ctx.hits.profiles[NPC.GetUnitName(attacker) .. ":" .. NPC.GetUnitName(target)]
	if profile and profile.samples >= 3 then
		minimum, maximum = minimum * profile.scale * 0.96, maximum * profile.scale * 1.04
	end
	return math.floor(minimum), math.ceil(maximum)
end

local function attackTarget(ctx, unit)
	if unit == ctx.hero and live(ctx.attackTarget) then return ctx.attackTarget end
	if NPC.IsTower(unit) then return Tower.GetAttackTarget(unit) end
	return NPC.FindFacingNPC(unit, nil, NPC.IsHero(unit) and Enum.TeamType.TEAM_BOTH or Enum.TeamType.TEAM_ENEMY,
		42, NPC.GetAttackRange(unit) + NPC.GetAttackRangeBonus(unit) + 125)
end

local function insert(ctx, source, target, release, impact, projectile)
	local hits = ctx.hits

	for key, event in pairs(hits.events) do
		if event.source == source and event.target == target and not event.projectile
			and math.abs(event.release - release) < 0.25 then hits.events[key] = nil end
	end
	local minimum, maximum = damage(source, target, ctx)
	hits.serial = hits.serial + 1
	hits.events[hits.serial] = {source = source, target = target, release = release,
		impact = impact, minimum = minimum, maximum = maximum, projectile = projectile}
end

function lastHit.animation(ctx, data)
	if not live(data.unit) or not NPC.IsAttacking(data.unit) then return end
	local target = attackTarget(ctx, data.unit)
	if not live(target) or ctx.distance(ctx.position, Entity.GetAbsOrigin(target)) > 2500 then return end
	local now = GameRules.GetGameTime()
	local base = NPC.GetAttackAnimPoint(data.unit)
	if data.castpoint <= 0 and not base then return end
	local point = data.castpoint > 0 and data.castpoint or base / math.max(0.2, NPC.GetAttackSpeed(data.unit))
	local start = now - math.max(0, data.lag_compensation_time)
	local release = start + point
	if NPC.IsLaneCreep(target) then
		insert(ctx, data.unit, target, release, release + flight(ctx, data.unit, target), false)
		ctx.hits.cycles[Entity.GetIndex(data.unit)] = {source = data.unit, target = target,
			nextStart = start + NPC.GetSecondsPerAttack(data.unit, false)}
	end
	if data.unit == ctx.hero then
		ctx.hits.failures[Entity.GetIndex(target)] = nil
		ctx.hits.retries[Entity.GetIndex(target)] = nil
		if ctx.ui.debug:Get() and not ctx.hits.observedPoint then
			Log.Write(string.format("[SelfPlay timing] base=%.3f speed=%.3f animation=%.3f lag=%.3f",
				NPC.GetAttackAnimPoint(ctx.hero), NPC.GetAttackSpeed(ctx.hero), data.castpoint, data.lag_compensation_time))
		end
		ctx.hits.observedPoint = point * NPC.GetAttackSpeed(ctx.hero)
		ctx.attackNext = start + NPC.GetSecondsPerAttack(ctx.hero, false)
		ctx.hits.ordered = {target = target, release = release, expires = release + 0.25, confirmed = true}
		ctx.busyUntil = release + cfg.margin
		ctx.hits.confirmed = ctx.hits.confirmed + 1
		ctx.hits.lastConfirmedName = NPC.GetUnitName(target)
	end
end

function lastHit.remove(ctx, unit)
	if Entity.IsEntity(unit) then
		local id = Entity.GetIndex(unit)
		ctx.hits.retries[id], ctx.hits.failures[id], ctx.hits.blocked[id], ctx.hits.paths[id] = nil, nil, nil, nil
	end
	if ctx.hits.recovery and ctx.hits.recovery.target == unit then ctx.hits.recovery = nil end
	for key, event in pairs(ctx.hits.events) do
		if event.target == unit or event.source == unit and not event.projectile then ctx.hits.events[key] = nil end
	end
	for key, cycle in pairs(ctx.hits.cycles) do
		if cycle.target == unit or cycle.source == unit then ctx.hits.cycles[key] = nil end
	end
	if ctx.hits.ordered and ctx.hits.ordered.target == unit then
		ctx.hits.ordered, ctx.busyUntil, ctx.attackNext = nil, ctx.now, ctx.now
	end
end

function lastHit.projectile(ctx, data)
	if not data.isAttack or not live(data.source) or not live(data.target) or data.moveSpeed <= 0 then return end
	if ctx.distance(ctx.position, Entity.GetAbsOrigin(data.target)) > 2500 then return end
	local now = GameRules.GetGameTime()
	if NPC.IsLaneCreep(data.target) then
		insert(ctx, data.source, data.target, now, now + flight(ctx, data.source, data.target, data.moveSpeed), true)
		local event = ctx.hits.events[ctx.hits.serial]
		event.origin, event.speed = Entity.GetAbsOrigin(data.source), data.moveSpeed
		local id = Entity.GetIndex(data.source)
		if not ctx.hits.cycles[id] then
			local base = NPC.GetAttackAnimPoint(data.source)
			local point = base and base / math.max(0.2, NPC.GetAttackSpeed(data.source)) or 0
			ctx.hits.cycles[id] = {source = data.source, target = data.target, nextStart = now - point + NPC.GetSecondsPerAttack(data.source, false)}
		end
	end
	if data.source == ctx.hero then
		if ctx.intent and ctx.intent.target == data.target then ctx.intent.followAttack = false end
		ctx.hits.ordered = nil
		ctx.busyUntil = now
	end
end

function lastHit.animationEnd(ctx, data)
	if not live(data.unit) or NPC.IsAttacking(data.unit) then return end
	local now, cancelled = GameRules.GetGameTime(), false
	for key, event in pairs(ctx.hits.events) do
		if event.source == data.unit and not event.projectile and event.release > now then ctx.hits.events[key], cancelled = nil, true end
	end
	local cycle = ctx.hits.cycles[Entity.GetIndex(data.unit)]
	if cycle and (cancelled or attackTarget(ctx, data.unit) ~= cycle.target) then ctx.hits.cycles[Entity.GetIndex(data.unit)] = nil end
	if data.unit == ctx.hero and ctx.hits.ordered and ctx.hits.ordered.release > now then
		ctx.hits.ordered, ctx.attackNext, ctx.busyUntil = nil, now, now
		ctx.hits.cancelled = ctx.hits.cancelled + 1
	end
end

function lastHit.ordered(ctx, target, windup)
	ctx.hits.ordered = {target = target, issued = ctx.now, release = ctx.now + windup, expires = ctx.now + windup + 0.3, confirmed = false}
end

function lastHit.hurt(ctx, data)
	if not data.target or not Entity.IsEntity(data.target) or not Entity.IsNPC(data.target) or not NPC.IsLaneCreep(data.target)
		or not data.source or not Entity.IsEntity(data.source) or data.ability or data.damage <= 0 then return end
	local now, matched, closest = GameRules.GetGameTime(), nil, 0.35
	for key, event in pairs(ctx.hits.events) do
		local difference = math.abs(event.impact - now)
		if event.source == data.source and event.target == data.target and difference < closest then matched, closest = key, difference end
	end
	if not matched then return end
	ctx.hits.events[matched] = nil
	if Entity.IsNPC(data.source) and data.source ~= ctx.hero then
		local minimum, maximum = damage(data.source, data.target)
		local ratio = data.damage / math.max(1, (minimum + maximum) * 0.5)
		if ratio < 0.25 or ratio > 2 then return end
		local key = NPC.GetUnitName(data.source) .. ":" .. NPC.GetUnitName(data.target)
		local profile = ctx.hits.profiles[key] or {scale = ratio, samples = 0}
		profile.scale, profile.samples = profile.scale * 0.7 + ratio * 0.3, profile.samples + 1
		ctx.hits.profiles[key] = profile
	end
end

function lastHit.update(ctx)
	local hits = ctx.hits
	for key, event in pairs(hits.events) do
		if event.projectile and event.origin and live(event.target) and ctx.now < event.impact + 0.15 then
			local distance = math.max(0, ctx.distance(event.origin, Entity.GetAbsOrigin(event.target)) - NPC.GetHullRadius(event.target))
			local remaining = math.max(0, distance / event.speed - (ctx.now - event.release))
			event.impact = event.release + math.max(0, ctx.distance(event.origin, ctx.predict(event.target, remaining)) - NPC.GetHullRadius(event.target)) / event.speed
		end
		if event.impact + 0.2 <= ctx.now or not live(event.target) or not event.projectile and not live(event.source) then
			hits.events[key] = nil
		end
	end
	for key, cycle in pairs(hits.cycles) do
		if not live(cycle.source) or not live(cycle.target) or cycle.nextStart < ctx.now - 0.3
			or attackTarget(ctx, cycle.source) ~= cycle.target then hits.cycles[key] = nil end
	end
	for key, path in pairs(hits.paths) do if path.expires < ctx.now - 2 then hits.paths[key] = nil end end
	local order = hits.ordered
	if order and order.confirmed and order.release <= ctx.now and ctx.intent and ctx.intent.target == order.target then
		ctx.intent.followAttack = false
	end
	if order and not order.confirmed and live(order.target) and NPC.IsAttacking(ctx.hero)
		and NPC.FindFacingNPC(ctx.hero, nil, Enum.TeamType.TEAM_BOTH, 30, NPC.GetAttackRange(ctx.hero) + NPC.GetAttackRangeBonus(ctx.hero) + 125) == order.target then
		order.confirmed = true
		local _, windup = lastHit.timing(ctx, order.target)
		order.release = math.max(ctx.now, (order.issued or ctx.now) + windup)
		order.expires = order.release + 0.25
		ctx.busyUntil = order.release + cfg.margin
		hits.failures[Entity.GetIndex(order.target)] = nil
		hits.retries[Entity.GetIndex(order.target)] = nil
	end
	if order and (not live(order.target) or ctx.now > order.expires) then
		if not order.confirmed then
			ctx.attackNext, ctx.busyUntil = ctx.now, ctx.now
			hits.cancelled = hits.cancelled + 1
			if live(order.target) and ctx.lastOrder == "attack" and ctx.attackTarget == order.target then
				local id = Entity.GetIndex(order.target)
				hits.failures[id] = (hits.failures[id] or 0) + 1
				if hits.failures[id] >= 3 then
					local retry = hits.retries[id] and hits.retries[id].count + 1 or 1
					hits.retries[id] = {count = retry, time = ctx.now}
					hits.blocked[id], hits.failures[id] = ctx.now + (retry <= 2 and 1 or 6), nil
					if retry <= 2 and not NPC.IsStructure(order.target) then
						hits.recovery = {target = order.target, expires = ctx.now + 0.8}
					end
					if ctx.ui.debug:Get() then
						Log.Write(string.format("[SelfPlay blocked attack] unit=%s id=%d distance=%.0f range=%.0f attacking=%s running=%s",
							NPC.GetUnitName(order.target), id, ctx.distance(ctx.position, Entity.GetAbsOrigin(order.target)),
							NPC.GetAttackRange(ctx.hero) + NPC.GetAttackRangeBonus(ctx.hero), tostring(NPC.IsAttacking(ctx.hero)), tostring(NPC.IsRunning(ctx.hero))))
					end
				end
			end
		end
		hits.ordered = nil
	end
	for id, expiry in pairs(hits.blocked) do if expiry < ctx.now then hits.blocked[id] = nil end end
	for id, retry in pairs(hits.retries) do if ctx.now - retry.time > 45 then hits.retries[id], hits.failures[id] = nil, nil end end
end

function lastHit.recover(ctx)
	local task = ctx.hits.recovery
	if not task then return false end
	if ctx.retreating or ctx.intent or ctx.runeTask or not live(task.target) or not NPC.IsVisible(task.target)
		or ctx.now > task.expires or ctx.farmCandidate and ctx.farmCandidate.start <= ctx.now + 0.4 then
		ctx.hits.recovery = nil
		return false
	end
	if not task.goal then
		local target = Entity.GetAbsOrigin(task.target)
		local dx, dy = ctx.position.x - target.x, ctx.position.y - target.y
		local length = math.max(1, math.sqrt(dx * dx + dy * dy))
		local reach = math.min(300, math.max(80, NPC.GetAttackRange(ctx.hero) - 35))
		local best, nearest = nil, 200
		for _, angle in ipairs({-0.7, 0.7, -1.2, 1.2}) do
			local x = target.x + (dx * math.cos(angle) - dy * math.sin(angle)) / length * reach
			local y = target.y + (dx * math.sin(angle) + dy * math.cos(angle)) / length * reach
			local point = Vector(x, y, World.GetGroundZ(x, y))
			local distance = ctx.distance(ctx.position, point)
			if distance > 35 and distance < nearest and GridNav.IsTraversable(point) and not ctx.unsafePosition(point)
				and awareness.farmSafe(ctx, point, distance / math.max(100, NPC.GetMoveSpeed(ctx.hero))) then best, nearest = point, distance end
		end
		if not best then ctx.hits.recovery = nil; return false end
		task.goal = best
	end
	if ctx.distance(ctx.position, task.goal) < 25 then ctx.hits.recovery = nil; return false end
	return ctx.move(task.goal, "Adjust approach after unacknowledged attack", 20)
end

local function ledger(ctx, target)
	local events = {}
	for _, event in pairs(ctx.hits.events) do
		if event.target == target and (event.source ~= ctx.hero or event.projectile) then events[#events + 1] = event end
	end
	for _, cycle in pairs(ctx.hits.cycles) do
		if cycle.target == target and cycle.source ~= ctx.hero then
			local base = NPC.GetAttackAnimPoint(cycle.source)
			local point = base and base / math.max(0.2, NPC.GetAttackSpeed(cycle.source))
			if point then
				local impact = cycle.nextStart + point + flight(ctx, cycle.source, target)
				local period = NPC.GetSecondsPerAttack(cycle.source, false)
				if period > 0 then
					for _ = 1, NPC.IsHero(cycle.source) and 0 or 3 do
						if impact > ctx.now + cfg.horizon then break end
						if impact > ctx.now then
							local minimum, maximum = damage(cycle.source, target, ctx)
							events[#events + 1] = {source = cycle.source, impact = impact, minimum = minimum, maximum = maximum}
						end
						impact = impact + period
					end
				end
			end
		end
	end
	table.sort(events, function(a, b) return a.impact < b.impact end)
	return events
end

local function contest(ctx, candidate)
	local deadline = math.huge
	for _, enemy in ipairs(ctx.enemies) do
		if live(enemy) and NPC.IsVisible(enemy) and not NPC.IsIllusion(enemy)
			and not NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_DISARMED)
			and NPC.IsEntityInRange(enemy, candidate.target, NPC.GetAttackRange(enemy) + NPC.GetAttackRangeBonus(enemy) + 100) then
			local point = NPC.GetAttackAnimPoint(enemy)
			if point then
				local lowDamage = damage(enemy, candidate.target, ctx)
				local reach = NPC.GetAttackRange(enemy) + NPC.GetAttackRangeBonus(enemy)
				local approach = math.max(0, ctx.distance(Entity.GetAbsOrigin(enemy), Entity.GetAbsOrigin(candidate.target)) - reach)
					/ math.max(100, NPC.GetMoveSpeed(enemy))
				local travel = point / math.max(0.2, NPC.GetAttackSpeed(enemy)) + NPC.GetTimeToFace(enemy, candidate.target)
					+ flight(ctx, enemy, candidate.target) + approach + 0.08
				local ready = ctx.now
				local cycle = ctx.hits.cycles[Entity.GetIndex(enemy)]
				if cycle then ready = math.max(ready, cycle.nextStart) end
				local checks = {ready}
				for _, event in ipairs(candidate.events) do
					checks[#checks + 1] = math.max(ready, event.impact + cfg.margin + 0.002 - travel)
					checks[#checks + 1] = math.max(ready, event.impact + cfg.margin + 0.002)
				end
				for _, start in ipairs(checks) do
					local low, high, collision = timeline.predict(candidate.health, candidate.regen, candidate.barrier, ctx.now, start + travel, candidate.events)
					local deny = Entity.IsSameTeam(enemy, candidate.target)
					local orderHealth = deny and select(2, timeline.predict(candidate.health, candidate.regen, 0, ctx.now, start, candidate.events)) or 0
					local threshold = NPC.GetModifierProperty(candidate.target, Enum.ModifierFunction.MODIFIER_PROPERTY_CREEP_DENY_PERCENT)
					if threshold <= 0 then threshold = 50 end
					if start + travel <= ctx.now + cfg.horizon and timeline.canKill(low, high, collision, lowDamage)
						and (not deny or orderHealth <= Entity.GetMaxHealth(candidate.target) * threshold / 100) then
						deadline = math.min(deadline, start + travel)
					end
				end
			end
		end
	end
	return deadline
end

local function window(ctx, candidate, earliest)
	candidate.chance = nil
	local waits, fallback = {0}, nil
	for _, event in ipairs(candidate.events) do
		local delay = event.impact + cfg.margin + 0.002 - earliest
		if delay > 0 and delay <= cfg.wait then waits[#waits + 1] = delay end
	end
	table.sort(waits)
	for _, delay in ipairs(waits) do
		local impact = earliest + delay
		if impact <= ctx.now + cfg.horizon then
			local low, high, collision = timeline.predict(candidate.health, candidate.regen, candidate.barrier, ctx.now, impact, candidate.events)
			if timeline.canKill(low, high, collision, candidate.damage) then return impact, delay end
			if not candidate.allied and not collision and low > 0 and high > candidate.damage and high <= candidate.maximum then
				local chance = (candidate.maximum - high + 1) / math.max(1, candidate.maximum - candidate.damage + 1)
				local futureLow = timeline.predict(candidate.health, candidate.regen, candidate.barrier, ctx.now,
					impact + NPC.GetSecondsPerAttack(ctx.hero, false), candidate.events)
				if chance >= 0.2 and futureLow <= 0 and not fallback then fallback = {impact, delay, chance} end
			end
		end
	end
	if fallback then candidate.chance = fallback[3]; return fallback[1], fallback[2] end
	return nil
end

local function towerPreparation(ctx, candidate, earliest)
	if candidate.allied or not candidate.inRange then return nil end
	for _, enemy in ipairs(ctx.enemies) do
		if live(enemy) and NPC.IsVisible(enemy) and ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy)) < 1000 then return nil end
	end
	for _, event in ipairs(candidate.events) do
		if event.source == ctx.hero and event.projectile then return nil end
	end
	local low, _, collision = timeline.predict(candidate.health, candidate.regen, candidate.barrier, ctx.now, earliest, candidate.events)
	if collision or low <= candidate.maximum then return nil end
	local ready = earliest + NPC.GetSecondsPerAttack(ctx.hero, false)
	for _, event in ipairs(candidate.events) do
		local finish = event.impact + cfg.margin + 0.002
		if event.source and NPC.IsTower(event.source) and finish >= ready and finish <= ctx.now + cfg.horizon then
			local afterLow, afterHigh, overlap = timeline.predict(candidate.health, candidate.regen, candidate.barrier, ctx.now, finish, candidate.events)
			if timeline.canKill(afterLow - candidate.maximum, afterHigh - candidate.damage, overlap, candidate.damage) then
				candidate.preparation = true
				return earliest, 0
			end
		end
	end
	return nil
end

local function route(ctx, target, range, map)
	local id, position = Entity.GetIndex(target), Entity.GetAbsOrigin(target)
	local treeWalking = navigation.treeWalking(ctx)
	local cached = ctx.hits.paths[id]
	if cached and cached.treeWalking == treeWalking and cached.range == range and cached.expires > ctx.now and ctx.distance(cached.origin, ctx.position) < 80
		and ctx.distance(cached.target, position) < 60 then return cached end
	local approach = math.max(0, ctx.distance(ctx.position, position) - range) / math.max(100, NPC.GetMoveSpeed(ctx.hero))
	position = ctx.predict(target, math.min(1, approach))
	local cover = geometry.back(ctx, position)
	local dx, dy = cover.x - position.x, cover.y - position.y
	local length = math.max(1, math.sqrt(dx * dx + dy * dy))
	dx, dy = dx / length, dy / length
	local best
	for _, angle in ipairs({0, -0.45, 0.45, -0.9, 0.9}) do
		local reach = math.max(65, range - 35)
		local x = position.x + (dx * math.cos(angle) - dy * math.sin(angle)) * reach
		local y = position.y + (dx * math.sin(angle) + dy * math.cos(angle)) * reach
		local goal = Vector(x, y, World.GetGroundZ(x, y))
		if GridNav.IsTraversable(goal) and not ctx.unsafePosition(goal) and awareness.farmSafe(ctx, goal, approach) then
			local path = GridNav.BuildPath(ctx.position, goal, treeWalking, map)
			if #path > 0 then
				local distance, previous, waypoint, safe = 0, ctx.position, nil, true
				for _, point in ipairs(path) do
					local segment = ctx.distance(previous, point)
					for step = 1, math.max(1, math.ceil(segment / 150)) do
						local sample = ctx.toward(previous, point, math.min(segment, step * 150))
						if ctx.unsafePosition(sample) or not awareness.farmSafe(ctx, sample, (distance + math.min(segment, step * 150)) / math.max(100, NPC.GetMoveSpeed(ctx.hero))) then safe = false; break end
					end
					if not safe then break end
					distance, previous = distance + ctx.distance(previous, point), point
					if not waypoint and ctx.distance(ctx.position, point) > 120 then waypoint = point end
				end
				distance = distance + ctx.distance(previous, goal)
				local score = distance + awareness.risk(ctx, goal) * 2
				if safe and (not best or score < best.score) then best = {distance = distance, score = score, goal = goal, waypoint = waypoint or goal} end
			end
		end
	end
	if best then
		best.expires, best.origin, best.target, best.range = ctx.now + cfg.pathAge, ctx.position, Entity.GetAbsOrigin(target), range
		best.treeWalking = treeWalking
		ctx.hits.paths[id] = best
	end
	return best
end

function lastHit.plan(ctx)
	if NPC.HasState(ctx.hero, Enum.ModifierState.MODIFIER_STATE_DISARMED) then return false end
	local attackReady = ctx.attackNext
	local range = NPC.GetAttackRange(ctx.hero) + NPC.GetAttackRangeBonus(ctx.hero)
	local speed = math.max(100, NPC.GetMoveSpeed(ctx.hero))
	local candidates, map = {}, nil
	for _, creep in ipairs(ctx.creeps) do
		if live(creep) and NPC.IsVisible(creep) and not ctx.hits.blocked[Entity.GetIndex(creep)] then
			local allied = Entity.IsSameTeam(ctx.hero, creep)
			local laneSupport = ctx.role >= 4
			local denyable = allied and laneRules.denyable(ctx.clock, Entity.GetHealth(creep), Entity.GetMaxHealth(creep),
				NPC.GetModifierProperty(creep, Enum.ModifierFunction.MODIFIER_PROPERTY_CREEP_DENY_PERCENT))
			if (denyable or not laneSupport and not allied and laneRules.canLastHit(ctx, creep))
				and not NPC.HasState(creep, Enum.ModifierState.MODIFIER_STATE_ATTACK_IMMUNE)
				and not NPC.HasState(creep, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE)
				and ctx.distance(ctx.position, Entity.GetAbsOrigin(creep)) < math.max(cfg.searchRange, range + 500) then
				local health = Entity.GetHealth(creep)
				local minimum, maximum = damage(ctx.hero, creep, ctx)
				local events = ledger(ctx, creep)
				local delay, windup = lastHit.timing(ctx, creep)
				local guarding = false
				if not allied then
					local guard = attackTarget(ctx, creep)
					guarding = live(guard) and Entity.IsSameTeam(ctx.hero, guard)
						and (NPC.IsTower(guard) or NPC.IsHero(guard) and guard ~= ctx.hero)
				end
				if delay and minimum > 0 and (health <= maximum or health < minimum * 2 or #events > 0 or guarding) then
					local barriers, barrier = NPC.GetBarriers(creep), 0
					if barriers then barrier = (barriers.physical and barriers.physical.current or 0) + (barriers.all and barriers.all.current or 0) end
					local inRange = NPC.IsEntityInRange(ctx.hero, creep, range)
					local approach = inRange and 0 or math.max(0, ctx.distance(ctx.position, Entity.GetAbsOrigin(creep)) - range + 35) / speed
					local origin = inRange and ctx.position or ctx.toward(ctx.predict(creep, approach), ctx.position, math.max(65, range - 35))
					delay, windup = lastHit.timing(ctx, creep, origin, approach)
					local candidate = {target = creep, health = health, damage = minimum, maximum = maximum, events = events,
						regen = NPC.GetHealthRegen(creep), barrier = barrier, allied = allied, delay = delay,
						approach = approach, inRange = inRange, goal = ctx.position}
					local earliest = math.max(ctx.now + approach, attackReady) + delay
					local impact, wait = window(ctx, candidate, earliest)
					if not impact then impact, wait = towerPreparation(ctx, candidate, earliest) end
					if impact and not inRange then
						if not map then map = GridNav.CreateNpcMap({ctx.hero}, not navigation.treeWalking(ctx)) end
						local path = route(ctx, creep, range, map)
						if path then
							candidate.approach, candidate.goal, candidate.waypoint = path.distance / speed, path.goal, path.waypoint
							delay, windup = lastHit.timing(ctx, creep, path.goal, candidate.approach)
							candidate.delay = delay
							earliest = math.max(ctx.now + candidate.approach, attackReady) + delay
							impact, wait = window(ctx, candidate, earliest)
						else impact = nil end
					end
					if impact and not inRange and approach > 2.5 then impact = nil end
					candidate.contest = contest(ctx, candidate)
					if NPC.IsRanged(ctx.hero) and candidate.contest < math.huge and range > 300
						and (not impact or impact > candidate.contest - 0.1 or attackReady > ctx.now + 0.2) then
						if not map then map = GridNav.CreateNpcMap({ctx.hero}, not navigation.treeWalking(ctx)) end
						local closer = math.max(220, math.min(range - 140, ctx.distance(ctx.position, Entity.GetAbsOrigin(creep)) - 140))
						local path = route(ctx, creep, closer, map)
						if path and path.distance <= 350 then
							local approach = path.distance / speed
							local faster, point = lastHit.timing(ctx, creep, path.goal, approach)
							local previousChance = candidate.chance
							local earlier, waiting = window(ctx, candidate, math.max(ctx.now + approach, attackReady) + faster)
							if earlier and (not impact or earlier < impact - 0.04) then
								impact, wait, delay, windup = earlier, waiting, faster, point
								candidate.delay, candidate.approach = faster, approach
								candidate.goal, candidate.waypoint, candidate.inRange = path.goal, path.waypoint, false
							else candidate.chance = previousChance end
						end
					end
					if not impact and guarding and inRange then impact, wait = earliest, 0 end
					if impact and awareness.farmSafe(ctx, candidate.goal, candidate.approach) then
						local bounty = NPC.GetGoldBountyMin(creep)
						candidate.value = allied and 18 + NPC.GetBountyXP(creep) * 0.3 or math.max(30, bounty) + NPC.GetBountyXP(creep) * 0.4
						if NPC.IsRanged(creep) then candidate.value = candidate.value + (allied and 5 or 15) end
						candidate.value = candidate.value * (candidate.chance or 1)
						if candidate.preparation then candidate.value = candidate.value * 0.55 end
						if candidate.contest < math.huge and impact < candidate.contest then candidate.value = candidate.value + 18 end
						candidate.impact, candidate.wait = impact, wait
						candidate.start, candidate.release = impact - delay, impact - delay + windup
						candidate.x, candidate.y = candidate.goal.x, candidate.goal.y
						candidate.focus = ctx.hits.focus == creep
						candidates[#candidates + 1] = candidate
					end
				end
			end
		end
	end
	if map then GridNav.ReleaseNpcMap(map) end
	ctx.hits.candidateCount = #candidates
	local best = timeline.choose(candidates, ctx.now, NPC.GetSecondsPerAttack(ctx.hero, false), speed)
	if not best then ctx.hits.focus = nil; return false end
	return best
end

function lastHit.execute(ctx, best)
	if not best then return lastHit.harass(ctx) end
	if not live(best.target) or not NPC.IsVisible(best.target)
		or NPC.HasState(best.target, Enum.ModifierState.MODIFIER_STATE_ATTACK_IMMUNE)
		or NPC.HasState(best.target, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE) then return false end
	local eligible = not best.allied and laneRules.canLastHit(ctx, best.target) or best.allied and laneRules.denyable(ctx.clock, Entity.GetHealth(best.target), Entity.GetMaxHealth(best.target),
		NPC.GetModifierProperty(best.target, Enum.ModifierFunction.MODIFIER_PROPERTY_CREEP_DENY_PERCENT))
	if not eligible then return false end
	ctx.hits.focus = best.target
	ctx.aggroTask = nil
	if awareness.farmSafe(ctx, best.goal or ctx.position, best.approach or 0) then
		ctx.farmCommitment = {target = best.target, expires = ctx.now + math.min(0.65, math.max(0.2, best.start - ctx.now + 0.15))}
	end
	if not best.inRange then
		return ctx.move(best.waypoint or best.goal, NPC.IsRanged(best.target) and "Last hit: reach ranged creep" or "Last hit: reach creep window", 15)
	end
	if best.start > ctx.now + cfg.margin or ctx.now < ctx.attackNext then
		if positioning.respond(ctx) then return true end
		if lastHit.harass(ctx, best) then return true end
		if lastHit.zone(ctx, best) then return true end
		local turn = NPC.GetTimeToFace(ctx.hero, best.target)
		local faceLead = math.max(0.45, turn + NetChannel.GetAvgLatency(Enum.Flow.FLOW_OUTGOING) + 0.12)
		if best.start > ctx.now + faceLead and positioning.lane(ctx, best.target, best) then return true end
		if best.start <= ctx.now + faceLead and turn > 0.04 then
			local point = ctx.toward(ctx.position, Entity.GetAbsOrigin(best.target), 25)
			if not ctx.unsafePosition(point) and ctx.now >= (ctx.hits.nextFace or 0) then
				NPC.MoveTo(ctx.hero, point, false, false, false, true)
				ctx.hits.nextFace, ctx.lastOrder, ctx.mode = ctx.now + 0.1, "face", "Last hit: face the reserved creep"
			end
			return true
		end
		ctx.mode = "Last hit: time next creep impact"
		return ctx.stop()
	end
	return ctx.attack(best.target, best.preparation and "Prepare creep for tower last hit" or best.allied and "Deny" or NPC.IsRanged(best.target) and "Last hit ranged creep" or "Last hit")
end

local function pressMelee(ctx, enemy)
	if ctx.health < 0.6 or not live(enemy) or NPC.IsRanged(enemy) then return false end
	for _, other in ipairs(ctx.enemies or {}) do
		if other ~= enemy and live(other) and NPC.IsVisible(other) and NPC.IsRanged(other)
			and ctx.distance(ctx.position, Entity.GetAbsOrigin(other)) < 1100 then return false end
	end
	return true
end

function lastHit.zone(ctx, best)
	if not best or ctx.intent or ctx.retreating or ctx.hardRetreat then return false end
	if ctx.health < 0.6 or ctx.laneThreat and (ctx.laneThreat.lethal or ctx.laneThreat.ambush or ctx.laneThreat.attacked) then return false end
	if best.start <= ctx.now + 0.8 then return false end
	local enemy = ctx.target
	if not live(enemy) or not NPC.IsVisible(enemy) or NPC.IsIllusion(enemy) or not NPC.IsHero(enemy) then return false end
	local range = NPC.GetAttackRange(ctx.hero) + NPC.GetAttackRangeBonus(ctx.hero)
	local enemyPos = Entity.GetAbsOrigin(enemy)
	if ctx.distance(ctx.position, enemyPos) > range + 250 then return false end
	if not live(best.target) then return false end
	local melee = pressMelee(ctx, enemy)
	local creepPos = Entity.GetAbsOrigin(best.target)
	local zonePos = ctx.toward(enemyPos, creepPos, math.max(120, range * (melee and 0.45 or 0.6)))
	if not GridNav.IsTraversable(zonePos) or ctx.unsafePosition(zonePos) then return false end
	if awareness.damage(ctx, zonePos, 1.5) > Entity.GetHealth(ctx.hero) * 0.12 then return false end
	for _, tower in ipairs(ctx.towers or {}) do
		if live(tower) and not Entity.IsSameTeam(ctx.hero, tower)
			and ctx.distance(zonePos, Entity.GetAbsOrigin(tower)) < NPC.GetAttackRange(tower) + 160 then return false end
	end
	if ctx.distance(ctx.position, zonePos) < 40 then
		ctx.mode = "Zone enemy hero off the wave"
		return ctx.stop()
	end
	return ctx.move(zonePos, "Zone enemy hero off the wave", 25)
end

function lastHit.harass(ctx, best)
	if ctx.intent or ctx.retreating or ctx.hardRetreat or ctx.now < ctx.attackNext
		or ctx.now < (ctx.nextLaneHarass or 0) or ctx.laneThreat and (ctx.laneThreat.lethal or ctx.laneThreat.ambush) then return false end
	local period = NPC.GetSecondsPerAttack(ctx.hero, false)
	if best and best.start < ctx.now + period + NPC.GetTimeToFace(ctx.hero, best.target) + 0.25 then return false end
	local foe = ctx.target
	local melee = live(foe) and NPC.IsHero(foe) and pressMelee(ctx, foe)
	local aggro = ctx.creepPressure or 0
	if ctx.role <= 3 and ctx.clock < (ctx.laneEnd or 600) then return false end
	if not ctx.tradeSafe and not (melee and aggro <= 1 and (ctx.enemyCreepCount or 0) <= (ctx.friendlyCreepCount or 0) + 2
		and ctx.health > 0.6) then return false end
	local range = NPC.GetAttackRange(ctx.hero) + NPC.GetAttackRangeBonus(ctx.hero)
	local enemy = ctx.target
	if not live(enemy) or not NPC.IsVisible(enemy) or NPC.IsIllusion(enemy) or not NPC.IsHero(enemy)
		or not NPC.IsEntityInRange(ctx.hero, enemy, range - 25) or ctx.unsafePosition(ctx.position)
		or NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE)
		or NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_ATTACK_IMMUNE)
		or awareness.damage(ctx, ctx.position, period + 0.4) > Entity.GetHealth(ctx.hero) * 0.12 then return false end
	for _, tower in ipairs(ctx.towers) do
		if live(tower) and not Entity.IsSameTeam(ctx.hero, tower)
			and ctx.distance(ctx.position, Entity.GetAbsOrigin(tower)) < NPC.GetAttackRange(tower) + 200 then return false end
	end
	local acted = ctx.attack(enemy, NPC.IsRanged(ctx.hero) and "Ranged support harass" or "Melee support harass")
	if acted then ctx.nextLaneHarass = ctx.now + period + 0.2 end
	return acted
end

function lastHit.finishHero(ctx)
	local enemy = ctx.target
	if ctx.intent or ctx.retreating or ctx.hardRetreat or not live(enemy) or not NPC.IsHero(enemy)
		or NPC.IsIllusion(enemy) or not NPC.IsVisible(enemy) or ctx.health < 0.45 then return false end
	local range = NPC.GetAttackRange(ctx.hero) + NPC.GetAttackRangeBonus(ctx.hero)
	if not NPC.IsEntityInRange(ctx.hero, enemy, range) or ctx.nearEnemies > ctx.nearAllies + 1
		or ctx.unsafePosition(ctx.position) or awareness.damage(ctx, ctx.position, 1) > Entity.GetHealth(ctx.hero) * 0.15 then return false end
	for _, tower in ipairs(ctx.towers) do
		if live(tower) and not Entity.IsSameTeam(ctx.hero, tower)
			and ctx.distance(ctx.position, Entity.GetAbsOrigin(tower)) < NPC.GetAttackRange(tower) + 160 then return false end
	end
	local damage = NPC.GetTrueDamage(ctx.hero) * NPC.GetArmorDamageMultiplier(enemy)
	if Entity.GetHealth(enemy) > damage * 1.05 then return false end
	return ctx.attack(enemy, "Safe finishing attack")
end

function lastHit.recoveryFarm(ctx)
	if ctx.hardRetreat or ctx.laneThreat and (ctx.laneThreat.attacked or ctx.laneThreat.avoid or ctx.laneThreat.ambush)
		or (ctx.creepPressure or 0) > 0 or ctx.now - (ctx.lastDamaged or -10) < 2
		or ctx.unsafePosition(ctx.position) or awareness.damage(ctx, ctx.position, 2) > Entity.GetHealth(ctx.hero) * 0.08 then return false end
	local candidate = lastHit.plan(ctx)
	if not candidate or not candidate.inRange or candidate.start > ctx.now + cfg.margin or ctx.now < ctx.attackNext then return false end
	return lastHit.execute(ctx, candidate)
end

function lastHit.run(ctx)
	return lastHit.execute(ctx, lastHit.plan(ctx))
end

function lastHit.diagnose(ctx)
	if not ctx.farmCandidate and ctx.now >= (ctx.nextLHDiagnose or 0) then
		local near, blocked, hittable = 0, 0, 0
		for _, creep in ipairs(ctx.creeps or {}) do
			if live(creep) and NPC.IsVisible(creep) and NPC.IsLaneCreep(creep)
				and ctx.distance(ctx.position, Entity.GetAbsOrigin(creep)) < 1100 then
				near = near + 1
				if ctx.hits.blocked[Entity.GetIndex(creep)] then blocked = blocked + 1 end
				local allied = Entity.IsSameTeam(ctx.hero, creep)
				local ok = not allied and laneRules.canLastHit(ctx, creep)
					or allied and laneRules.denyable(ctx.clock, Entity.GetHealth(creep), Entity.GetMaxHealth(creep),
						NPC.GetModifierProperty(creep, Enum.ModifierFunction.MODIFIER_PROPERTY_CREEP_DENY_PERCENT))
				if ok then hittable = hittable + 1 end
			end
		end
		if near > 0 then
			ctx.nextLHDiagnose = ctx.now + 10
			local threat = ctx.laneThreat or {}
			Log.Write(string.format("[SelfPlay lasthit-stall] near=%d hittable=%d blocked=%d avoid=%s ambush=%s incoming=%.0f access=%s mode=%s order=%s",
				near, hittable, blocked, tostring(threat.avoid), tostring(threat.ambush), threat.incoming or 0,
				tostring(not threat.avoid or positioning.reserve(ctx)), ctx.mode, ctx.lastOrder or "none"))
		end
	end
end

function lastHit.yieldCore(ctx)
	local target = ctx.attackTarget
	if ctx.role <= 3 or ctx.lastOrder ~= "attack" or not live(target) or not NPC.IsLaneCreep(target)
		or Entity.IsSameTeam(ctx.hero, target) or ctx.hits.focus ~= target or NPC.IsChannellingAbility(ctx.hero)
		or laneRules.canLastHit(ctx, target) then return false end
	ctx.stop()
	ctx.hits.focus, ctx.hits.ordered, ctx.farmCandidate = nil, nil, nil
	ctx.busyUntil, ctx.attackNext, ctx.mode = ctx.now, ctx.now, "Yield lane last hits to nearby core"
	return true
end

return lastHit
