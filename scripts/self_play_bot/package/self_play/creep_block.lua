local block = {}
local geometry = require("self_play.lane_geometry")
local navigation = require("self_play.navigation")

local function latency()
	return NetChannel.GetAvgLatency(Enum.Flow.FLOW_OUTGOING) + NetChannel.GetAvgLatency(Enum.Flow.FLOW_INCOMING) + 0.033
end

local function live(unit)
	return unit and Entity.IsEntity(unit) and Entity.IsAlive(unit) and not Entity.IsDormant(unit)
end

local function observe(ctx, state)
	state.motion = state.motion or {}
	for _, creep in ipairs(state.members) do
		if live(creep) then
			local position = Entity.GetAbsOrigin(creep)
			local old = state.motion[creep]
			if not old then
				state.motion[creep] = {position = position, time = ctx.now}
			elseif ctx.now - old.time >= 0.03 then
				local dt = ctx.now - old.time
				local vx, vy = (position.x - old.position.x) / dt, (position.y - old.position.y) / dt
				if dt <= 0.3 and math.sqrt(vx * vx + vy * vy) <= NPC.GetMoveSpeed(creep) * 1.4 then
					old.vx, old.vy = vx, vy
				else old.vx, old.vy = nil, nil end
				old.position, old.time = position, ctx.now
			end
		end
	end
end

local function laneGroups()
	if LaneGroupsManager and LaneGroupsManager.visible_ally then return LaneGroupsManager.visible_ally end
	return {}
end

local function laneWave(ctx)
	local members, seen, path = {}, {}, nil
	for _, group in pairs(laneGroups()) do
		if group.lane == ctx.lane then
			path = path or group.lane_path
			for _, entry in pairs(group.creeps) do
				local creep = entry.ref
				if live(creep) and not seen[creep] then members[#members + 1], seen[creep] = creep, true end
			end
		end
	end
	return #members > 0 and members or ctx.waves[ctx.lane], path
end

function block.stage(ctx, state)
	local route = state.route or geometry.route(ctx, ctx.lane)
	if not route then return nil end
	local _, path = laneWave(ctx)
	if path and #path > 1 and not state.creepRoute then
		local actual = {front = route.front, rear = route.rear, points = {}, length = 0}
		local reverse = ctx.distance(path[1], ctx.home) > ctx.distance(path[#path], ctx.home)
		for i = 1, #path do
			local point = path[reverse and #path - i + 1 or i]
			if i > 1 then actual.length = actual.length + ctx.distance(actual.points[i - 1], point) end
			actual.points[i] = point
		end
		local _, rear = geometry.project(ctx, actual, Entity.GetAbsOrigin(route.rear))
		local _, front = geometry.project(ctx, actual, Entity.GetAbsOrigin(route.front))
		if front - rear > 100 then
			local cropped = {front = route.front, rear = route.rear, points = {geometry.point(ctx, actual, rear)}, length = 0}
			local progress = 0
			for i = 2, #actual.points do
				progress = progress + ctx.distance(actual.points[i - 1], actual.points[i])
				if progress > rear and progress < front then cropped.points[#cropped.points + 1] = actual.points[i] end
			end
			cropped.points[#cropped.points + 1] = geometry.point(ctx, actual, front)
			for i = 2, #cropped.points do cropped.length = cropped.length + ctx.distance(cropped.points[i - 1], cropped.points[i]) end
			route, state.creepRoute = cropped, true
		end
	end
	state.route = route
	local safeLane = ctx.team == 2 and 3 or 1
	local fraction = ctx.lane == 2 and 0.25 or ctx.lane == safeLane and 0.6 or 0.4
	local point = geometry.point(ctx, route, route.length * fraction)
	return GridNav.IsTraversable(point) and point or nil
end

local function intercept(ctx, creep, dx, dy)
	local position = Entity.GetAbsOrigin(creep)
	local speed = NPC.GetMoveSpeed(creep)
	local motion = ctx.blockState and ctx.blockState.motion and ctx.blockState.motion[creep]
	local measured = motion and motion.vx and ctx.now - motion.time < 0.2 and math.max(0, math.min(speed, motion.vx * dx + motion.vy * dy)) or speed
	local pause = (speed - measured) / math.max(1, speed) * 0.2
	local width = NPC.GetHullRadius(ctx.hero) + NPC.GetHullRadius(creep)
	local delayNetwork = latency()
	local gap = width + 8 + speed * delayNetwork
	local ahead = (ctx.position.x - position.x) * dx + (ctx.position.y - position.y) * dy
	if ahead > gap then
		local point = Vector(position.x + dx * (ahead + 24), position.y + dy * (ahead + 24), position.z)
		local travel = ctx.distance(ctx.position, point) / math.max(1, NPC.GetMoveSpeed(ctx.hero))
		if travel + delayNetwork + NPC.GetTimeToFacePosition(ctx.hero, point) < (ahead - gap) / math.max(1, speed) + pause then return point, travel end
	end
	local route = ctx.blockState and ctx.blockState.route
	local projection, progress, offset
	if route then projection, progress, offset = geometry.project(ctx, route, position) end
	for step = 0, 20 do
		local time = step * 0.08
		local advance = gap + measured * math.min(time, 0.2) + speed * math.max(0, time - 0.2)
		local point = Vector(position.x + dx * advance, position.y + dy * advance, position.z)
		if route and offset < 120 and progress + advance < route.length and advance > 200 then
			local pathPoint = geometry.point(ctx, route, progress + advance)
			point = Vector(pathPoint.x + position.x - projection.x, pathPoint.y + position.y - projection.y, position.z)
		end
		local delay = delayNetwork + NPC.GetTimeToFacePosition(ctx.hero, point)
		local forward = (point.x - ctx.position.x) * dx + (point.y - ctx.position.y) * dy
		if (ahead <= 0 or forward >= 0) and ctx.distance(ctx.position, point) <= NPC.GetMoveSpeed(ctx.hero) * math.max(0, time - delay) + 10 then return point, time end
	end
	return nil
end

local function finish(ctx, state, reason)
	state.done, state.phase, state.reason = true, "finished", reason
	if state.later then ctx.nextLaneBlock = ctx.now + 12 end
	return false
end

local function waitingOrder(ctx, state)
	local pending = state.pendingOrder
	if not pending then return false end
	local queue = Humanizer.GetOrderQueue()
	if queue then
		for _, order in ipairs(queue) do
			if order.player == ctx.player and order.orderType == pending.kind and order.addTime >= pending.time - 0.04
				and (not pending.point or ctx.distance(order.position, pending.point) < 1) then return true end
		end
	end
	state.pendingOrder = nil
	return false
end

local function stop(ctx, state)
	if ctx.lastOrder ~= "hold" then
		state.pendingOrder = {kind = Enum.UnitOrder.DOTA_UNIT_ORDER_HOLD_POSITION, time = ctx.now}
	end
	return ctx.stop()
end

local function move(ctx, state, point, mode)
	ctx.mode = mode
	if ctx.distance(ctx.position, point) < 12 then return stop(ctx, state) end
	if state.point and ctx.distance(state.point, point) < 18 and ctx.lastOrder == "move" and NPC.IsRunning(ctx.hero) then return true end
	NPC.MoveTo(ctx.hero, point, false, false, false, true, "self_play_block", false)
	state.pendingOrder = {kind = Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION, point = point, time = ctx.now}
	state.point = point
	ctx.attackTarget, ctx.lastOrder = nil, "move"
	return true
end

local function laterWave(ctx)
	if ctx.settings.blockLater == false or ctx.clock > 900 or ctx.now < (ctx.nextLaneBlock or 0) or ctx.farmCandidate or ctx.campTask or ctx.runeTask
		or ctx.objectiveTask or ctx.teamTask and ctx.teamTask.kind ~= "protect" or (ctx.creepPressure or 0) > 0 then return nil end
	local route = geometry.route(ctx, ctx.lane)
	if not route or not live(route.front) then return nil end
	local tower = Entity.GetAbsOrigin(route.front)
	local back = geometry.point(ctx, route, route.length - 250)
	local dx, dy = tower.x - back.x, tower.y - back.y
	local axis = math.max(1, math.sqrt(dx * dx + dy * dy))
	dx, dy = dx / axis, dy / axis
	local enemy, enemyDistance, count = nil, math.huge, 0
	for _, creep in ipairs(ctx.creeps) do
		if live(creep) and NPC.IsVisible(creep) and not Entity.IsSameTeam(ctx.hero, creep) then
			local p = Entity.GetAbsOrigin(creep)
			local distance = ctx.distance(p, tower)
			local forward, lateral = (p.x - tower.x) * dx + (p.y - tower.y) * dy, -(p.x - tower.x) * dy + (p.y - tower.y) * dx
			if distance < 2600 and forward > -250 and math.abs(lateral) < 550 then
				count = count + 1
				if distance < enemyDistance then enemy, enemyDistance = creep, distance end
			end
		end
	end
	if not enemy or count < 2 then return nil end
	local budget = (enemyDistance - NPC.GetAttackRange(route.front) - 400) / math.max(100, NPC.GetMoveSpeed(enemy))
	if budget < 1.2 then return nil end
	local members, seen = {}, {}
	for _, creep in ipairs((laneWave(ctx))) do
		if live(creep) and not NPC.IsAttacking(creep) and (ctx.settings.blockRanged ~= false or not NPC.IsRanged(creep))
			and ctx.distance(ctx.position, Entity.GetAbsOrigin(creep)) < 700
			and ctx.distance(Entity.GetAbsOrigin(creep), Entity.GetAbsOrigin(enemy)) > 800 then
			members[#members + 1], seen[creep] = creep, true
		end
	end
	if #members < 2 then return nil end
	return {members = members, seen = seen, lane = ctx.lane, route = route, phase = "intercept", later = true,
		expires = ctx.now + math.min(3, budget * 0.5)}
end

function block.run(ctx, endTime)
	local state = ctx.blockState
	if not ctx.settings.block or ctx.retreating or ctx.intent or ctx.now < ctx.busyUntil
		or NPC.IsChannellingAbility(ctx.hero) or NPC.HasState(ctx.hero, Enum.ModifierState.MODIFIER_STATE_NO_UNIT_COLLISION)
		or ctx.laneThreat and (ctx.laneThreat.avoid or ctx.laneThreat.attacked) then return false end
	if ctx.clock > endTime then
		if ctx.settings.blockLater == false then return false end
		if not state or not state.later or state.done then state = laterWave(ctx); ctx.blockState = state end
		if not state then return false end
		if ctx.now >= state.expires or ctx.farmCandidate or ctx.campTask or ctx.runeTask or ctx.objectiveTask
			or ctx.teamTask and (ctx.teamTask.fighting or ctx.teamTask.kind ~= "protect") then return finish(ctx, state, "Lane task takes priority") end
	elseif state and state.done then return false end
	state = state or {members = {}, seen = {}, lane = ctx.lane, phase = "stage"}
	ctx.blockState = state
	if state.lane ~= ctx.lane then return finish(ctx, state, "Lane changed") end
	local stage = block.stage(ctx, state)
	if ctx.clock < 40 or state.later then
		local anchor = live(state.lead) and Entity.GetAbsOrigin(state.lead)
		for _, creep in ipairs((laneWave(ctx))) do
			if live(creep) and not NPC.IsAttacking(creep) and not state.seen[creep]
				and (ctx.settings.blockRanged ~= false or not NPC.IsRanged(creep))
				and (not anchor or ctx.distance(anchor, Entity.GetAbsOrigin(creep)) < 600)
				and (not state.later or ctx.distance(ctx.position, Entity.GetAbsOrigin(creep)) < 800) then
				state.seen[creep], state.members[#state.members + 1] = true, creep
			end
		end
	end
	if #state.members == 0 then
		if ctx.clock >= 25 then return finish(ctx, state, "First wave missed") end
		if not stage then return false end
		return ctx.move(stage, "block.stage", 30)
	end
	observe(ctx, state)
	if waitingOrder(ctx, state) then return true end
	local route = state.route
	local front = route and route.front
	if not front then
		local suffix = ({"top", "mid", "bot"})[ctx.lane]
		for _, tower in ipairs(ctx.structures) do
			if live(tower) and Entity.IsSameTeam(ctx.hero, tower) and NPC.GetUnitName(tower):find("tower1_" .. suffix, 1, true) then front = tower; break end
		end
	end
	local lead, bestProgress, dx, dy, retry, phased, lockedLead, leadPassed
	state.escaped = state.escaped or {}
	local activeMembers = 0
	for _, creep in ipairs(state.members) do
		if live(creep) and not state.escaped[creep] and not NPC.IsAttacking(creep)
			and (ctx.settings.blockRanged ~= false or not NPC.IsRanged(creep)) then activeMembers = activeMembers + 1 end
	end
	local groupX, groupY
	if activeMembers > 1 and route then
		local _, progress = geometry.project(ctx, route, ctx.position)
		local from = geometry.point(ctx, route, math.max(0, progress - 80))
		local to = geometry.point(ctx, route, progress + 160)
		local x, y = to.x - from.x, to.y - from.y
		local length = math.sqrt(x * x + y * y)
		if length > 1 then groupX, groupY = x / length, y / length end
	end
	if state.followersUntil and ctx.now >= state.followersUntil then return finish(ctx, state, "Follower block time budget reached") end
	for _, creep in ipairs(state.members) do
		if live(creep) and not state.escaped[creep] and NPC.HasState(creep, Enum.ModifierState.MODIFIER_STATE_NO_UNIT_COLLISION) then phased = true end
		if live(creep) and NPC.IsAttacking(creep) then state.escaped[creep] = true end
		if live(creep) and route and not state.later
			and select(2, geometry.project(ctx, route, Entity.GetAbsOrigin(creep))) >= route.length - 40 then state.escaped[creep] = true end
		if live(creep) and not state.escaped[creep] and not NPC.HasState(creep, Enum.ModifierState.MODIFIER_STATE_NO_UNIT_COLLISION)
			and (ctx.settings.blockRanged ~= false or not NPC.IsRanged(creep)) then
			local position = Entity.GetAbsOrigin(creep)
			local projected, progress
			if route then projected, progress = geometry.project(ctx, route, position) end
			local direction = route and geometry.point(ctx, route, progress + 160) or ctx.enemyHome
			local origin = projected or position
			local x, y = direction.x - origin.x, direction.y - origin.y
			local length = math.sqrt(x * x + y * y)
			if route and (length < 40 or state.later and select(2, geometry.project(ctx, route, position)) >= route.length - 40) then
				if not state.later then return finish(ctx, state, "Reached front tower") end
				local back = geometry.point(ctx, route, route.length - 250)
				x, y = Entity.GetAbsOrigin(route.front).x - back.x, Entity.GetAbsOrigin(route.front).y - back.y
				length = math.sqrt(x * x + y * y)
			end
			x, y = x / math.max(1, length), y / math.max(1, length)
			if groupX then x, y = groupX, groupY end
			local laneX, laneY = x, y
			local laneAhead = (position.x - ctx.position.x) * laneX + (position.y - ctx.position.y) * laneY
			local motion = state.motion[creep]
			local speed = motion and motion.vx and math.sqrt(motion.vx * motion.vx + motion.vy * motion.vy) or 0
			local width = NPC.GetHullRadius(ctx.hero) + NPC.GetHullRadius(creep)
			local close = ctx.distance(ctx.position, position) < 300
			if activeMembers == 1 and speed > NPC.GetMoveSpeed(creep) * 0.25 and NPC.IsRunning(creep)
				and (motion.vx * x + motion.vy * y) / speed > (close and -0.1 or 0.5) then x, y = motion.vx / speed, motion.vy / speed end
			local ahead = (position.x - ctx.position.x) * x + (position.y - ctx.position.y) * y
			progress = progress or position.x * x + position.y * y
			if route and progress <= 0 then
				local a, b = route.points[1], route.points[2]
				local length = math.max(1, ctx.distance(a, b))
				progress = math.min(0, ((position.x - a.x) * (b.x - a.x) + (position.y - a.y) * (b.y - a.y)) / length)
			end
			if state.later then progress = (position.x - ctx.position.x) * x + (position.y - ctx.position.y) * y end
			local lateral = math.abs(-(position.x - ctx.position.x) * y + (position.y - ctx.position.y) * x)
			local aligned = ahead <= -width * 0.5 and lateral < width - 3
			local contact = ahead <= width * 0.2 and ctx.distance(ctx.position, position) < width + 24
			local reachable = contact or aligned or ahead < -950 or intercept(ctx, creep, x, y)
			if (not reachable and laneAhead > 0) or laneAhead >= 350 then
				state.escaped[creep] = true
				state.followersUntil = state.followersUntil or ctx.now + 3.5
			elseif not reachable then
				retry = true
			else
				local forwardSpeed = motion and motion.vx and math.max(0, motion.vx * laneX + motion.vy * laneY) or NPC.GetMoveSpeed(creep)
				local score = (activeMembers > 1 and laneAhead or progress) + math.min(NPC.GetMoveSpeed(creep), forwardSpeed) * 0.2 + (creep == state.lead and 12 or 0)
				if not bestProgress or score > bestProgress then lead, bestProgress, dx, dy, leadPassed = creep, score, x, y, laneAhead > 0 end
				if creep == state.lead and state.phase == "cross" and state.sweepUntil and ctx.now < state.sweepUntil
					and state.point and ctx.distance(ctx.position, state.point) >= 12 and ahead < 0
					and ctx.distance(ctx.position, position) < width * 2.5 then lockedLead = {creep, x, y, laneAhead > 0, score + width * 0.5} end
			end
		end
	end
	if lockedLead and bestProgress <= lockedLead[5] then lead, dx, dy, leadPassed = lockedLead[1], lockedLead[2], lockedLead[3], lockedLead[4] end
	if not lead then
		if phased then
			ctx.mode = "block.stage"
			return stage and ctx.move(stage, ctx.mode, 30) or stop(ctx, state)
		end
		state.retrySince = state.retrySince or ctx.now
		if retry and ctx.now - state.retrySince < 0.65 then
			ctx.mode = "block.retry"
			return stop(ctx, state)
		end
		return finish(ctx, state, "Wave escaped beyond interception")
	end
	state.retrySince = nil
	if state.lead ~= lead then state.point, state.side, state.sweepUntil, state.brakeUntil, state.nextOrder = nil, nil, nil, nil, ctx.now end
	state.lead = lead
	local position = Entity.GetAbsOrigin(lead)
	for _, units in ipairs({ctx.creeps, ctx.enemies}) do
		for _, enemy in ipairs(units) do
			if live(enemy) and not Entity.IsSameTeam(ctx.hero, enemy) and NPC.IsVisible(enemy) then
				local enemyPosition = Entity.GetAbsOrigin(enemy)
				if ctx.distance(position, enemyPosition) < (NPC.IsLaneCreep(enemy) and 650 or 500)
					or live(front) and NPC.IsLaneCreep(enemy) and ctx.distance(enemyPosition, Entity.GetAbsOrigin(front)) < NPC.GetAttackRange(front) + 170 then
					return finish(ctx, state, "Release before enemy contact")
				end
			end
		end
	end
	local rx, ry = ctx.position.x - position.x, ctx.position.y - position.y
	local ahead, lateral = rx * dx + ry * dy, -rx * dy + ry * dx
	local width = NPC.GetHullRadius(ctx.hero) + NPC.GetHullRadius(lead)
	for _, ally in ipairs(ctx.allies) do
		if ally ~= ctx.hero and live(ally) and not NPC.IsIllusion(ally) and Hero.GetReplicatingOtherHeroModel(ally) == nil then
			local p = Entity.GetAbsOrigin(ally)
			local forward = (p.x - position.x) * dx + (p.y - position.y) * dy
			if forward > width and forward < 180 and math.abs(-(p.x - position.x) * dy + (p.y - position.y) * dx) < width then
				return finish(ctx, state, "Teammate already blocking this wave")
			end
		end
	end
	if not state.later and stage and ctx.distance(ctx.position, position) > 950 then
		state.phase = "stage"
		return ctx.move(stage, "block.stage", 30)
	end
	if ctx.now < (state.nextOrder or 0) then return true end
	state.nextOrder = ctx.now + math.max(0.033, math.min(0.07, width / math.max(1, NPC.GetMoveSpeed(lead)) * 0.4))
	local motion = state.motion[lead]
	local speed = motion and motion.vx and math.max(0, motion.vx * dx + motion.vy * dy) or NPC.GetMoveSpeed(lead)
	local turnSide = state.side or (lateral >= 0 and -1 or 1)
	local turnPoint = Vector(ctx.position.x + dx * width * 0.45 - dy * turnSide * width * 0.9,
		ctx.position.y + dy * width * 0.45 + dx * turnSide * width * 0.9, ctx.position.z)
	local reaction = latency() + NPC.GetTimeToFacePosition(ctx.hero, turnPoint) + state.nextOrder - ctx.now
	local gap = width + math.min(width * 2, NPC.GetMoveSpeed(lead) * reaction) + 3
	local left, right = -width * 0.85, width * 0.85
	for _, creep in ipairs(state.members) do
		if creep ~= lead and live(creep) and not state.escaped[creep] and not NPC.IsAttacking(creep)
			and (ctx.settings.blockRanged ~= false or not NPC.IsRanged(creep)) then
			local p = Entity.GetAbsOrigin(creep)
			local forward, cross = (p.x - position.x) * dx + (p.y - position.y) * dy, -(p.x - position.x) * dy + (p.y - position.y) * dx
			if math.abs(forward) < width * 1.5 and math.abs(cross) < width * 2.5 then
				local reach = (NPC.GetHullRadius(ctx.hero) + NPC.GetHullRadius(creep)) * 0.85
				local nextLeft, nextRight = math.max(left, cross - reach), math.min(right, cross + reach)
				if nextLeft <= nextRight then left, right = nextLeft, nextRight end
			end
		end
	end
	local center = math.max(-width * 0.8, math.min(width * 0.8, (left + right) * 0.5))
	local sweep = math.min(width * (activeMembers > 1 and 0.18 or 0.45), math.max(0, (right - left) * 0.5))
	local aligned = math.abs(lateral - center) < width * 0.75
	local pointLateral = state.point and (-(state.point.x - position.x) * dy + (state.point.y - position.y) * dx)
	local coversFront = pointLateral and math.abs(pointLateral - center) <= math.max(width * 0.2, (right - left) * 0.5) + 4
	local crossing = state.phase == "cross" and state.sweepUntil and ctx.now < state.sweepUntil and state.point
		and coversFront and ctx.distance(ctx.position, state.point) >= 12 and ahead >= width * 0.5 and ahead < gap + width
	local stopped = speed < 20 and ahead >= width - 3 and math.abs(lateral - center) < width * 0.3
	if stopped and not state.brakeUntil then state.brakeUntil = ctx.now + 0.1 end
	local braking = stopped and not crossing and ctx.now < state.brakeUntil
	if aligned and (braking or not crossing and ahead > gap and speed >= 20) then
		state.phase = "brake"
		state.sweepUntil, state.point = nil, nil
		ctx.mode = "block.wait"
		return stop(ctx, state)
	end
	local contact = ahead >= -width * 0.2 and ctx.distance(ctx.position, position) < width + 24
	local side = not contact and (not aligned or ahead < width * 0.5)
	local point
	if crossing and not braking then
		point, side = state.point, false
	elseif side then
		point = intercept(ctx, lead, dx, dy)
		if not point then
			if leadPassed then state.escaped[lead], state.followersUntil = true, state.followersUntil or ctx.now + 3.5 end
			state.phase = "intercept"
			state.nextOrder = ctx.now
			ctx.mode = "block.retry"
			return stop(ctx, state)
		end
	else
		if not state.side then state.side = lateral >= center and -1 or 1 end
		local crossed = state.phase == "cross" and (state.side * (lateral - center) >= math.max(4, sweep * 0.67)
			or state.point and ctx.distance(ctx.position, state.point) < 12)
		if crossed then state.side, state.sweepUntil = -state.side, nil end
		local offset = center + state.side * sweep
		local diagonal = math.abs(offset - lateral)
		local contact = math.sqrt(math.max(0, width * width - offset * offset)) + 3
		local forward = math.max(contact, ahead + math.max(16, width * (activeMembers > 1 and 1.2 or 0.25), diagonal * 1.3))
		point = Vector(position.x + dx * forward - dy * offset, position.y + dy * forward + dx * offset, position.z)
		state.sweepUntil = ctx.now + math.min(0.3, ctx.distance(ctx.position, point) / math.max(1, NPC.GetMoveSpeed(ctx.hero))
			+ NPC.GetTimeToFacePosition(ctx.hero, point) + latency())
	end
	if not GridNav.IsTraversable(point) or ctx.unsafePosition(point) or not navigation.safePath(ctx, point, 25) then
		local centerPoint = Vector(position.x + dx * gap - dy * center, position.y + dy * gap + dx * center, position.z)
		if not side and GridNav.IsTraversable(centerPoint) and not ctx.unsafePosition(centerPoint)
			and navigation.safePath(ctx, centerPoint, 25) then point, state.point = centerPoint, nil
		else return finish(ctx, state, "No safe interception") end
	end
	state.phase = side and "intercept" or "cross"
	return move(ctx, state, point, side and "block.intercept" or "block.cross")
end

return block
