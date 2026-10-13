local camps = {}
local geometry = require("self_play.lane_geometry")
local navigation = require("self_play.navigation")
local awareness = require("self_play.awareness")
local lastHit = require("self_play.last_hit")

local function live(unit)
	return unit and Entity.IsEntity(unit) and Entity.IsAlive(unit) and not Entity.IsDormant(unit) and NPC.IsVisible(unit)
end

local function inside(box, point, margin)
	return point.x >= box.min.x - margin and point.x <= box.max.x + margin
		and point.y >= box.min.y - margin and point.y <= box.max.y + margin
end

local function units(ctx, camp)
	local found = {}
	for _, unit in ipairs(ctx.worldNPCs) do
		if live(unit) and NPC.IsNeutral(unit) and NPC.IsCreep(unit) and not NPC.IsWaitingToSpawn(unit)
			and not NPC.IsAncient(unit) and inside(camp.box, Entity.GetAbsOrigin(unit), 120) then found[#found + 1] = unit end
	end
	return found
end

local function finish(ctx, reason)
	ctx.campStatus, ctx.campTask, ctx.nextCampPlan = reason, nil, ctx.now + 2
	return false
end

local function destination(ctx, camp, kind, route)
	if kind == "pull" then
		if not route then return nil end
		local point, progress, distance = geometry.project(ctx, route, camp.position_)
		if distance < 350 or distance > 1400 then return nil end
		return point, progress
	end
	local best, score
	local shelter = navigation.coverAnchor(ctx)
	for index = 0, 15 do
		local angle = index * math.pi / 8
		local x, y = math.cos(angle), math.sin(angle)
		local edgeX = x > 0 and camp.box.max.x or camp.box.min.x
		local edgeY = y > 0 and camp.box.max.y or camp.box.min.y
		local extent = math.min(math.abs(x) > 0.01 and math.abs((edgeX - camp.position_.x) / x) or math.huge,
			math.abs(y) > 0.01 and math.abs((edgeY - camp.position_.y) / y) or math.huge)
		local point = Vector(camp.position_.x + x * (extent + 450), camp.position_.y + y * (extent + 450), camp.position_.z)
		if GridNav.IsTraversable(point) and not ctx.unsafePosition(point) then
			local value = extent + ctx.distance(point, shelter) * 0.3 + awareness.risk(ctx, point) * 4
			if not score or value < score then best, score = point, value end
		end
	end
	if kind ~= "pull" and best then
		local dx, dy = best.x - camp.position_.x, best.y - camp.position_.y
		local length = math.max(1, math.sqrt(dx * dx + dy * dy))
		local point = best
		for _ = 1, 10 do
			if not inside(camp.box, point, 200) then break end
			point = Vector(point.x + dx / length * 100, point.y + dy / length * 100, point.z)
		end
		if GridNav.IsTraversable(point) and not ctx.unsafePosition(point) then best = point end
	end
	return best
end

local function dragTime(ctx, camp, members, goal)
	local length, previous = 0, camp.position_
	local path = GridNav.BuildPath(previous, goal)
	if #path == 0 then return nil end
	for _, point in ipairs(path) do length, previous = length + ctx.distance(previous, point), point end
	length = length + ctx.distance(previous, goal)
	local speed = 300
	for _, unit in ipairs(members) do speed = math.min(speed, NPC.GetMoveSpeed(unit), NPC.GetMoveSpeed(ctx.hero)) end
	return length / math.max(100, speed) + 0.65
end

local function trigger(ctx, task, members)
	local travel = dragTime(ctx, task.camp, members, task.destination)
	if not travel then return nil end
	local delay = members[1] and lastHit.timing(ctx, members[1]) or 0.6
	if not delay then return nil end
	if task.kind == "stack" then return task.spawn - travel - delay end
	local earliest = math.huge
	for _, creep in ipairs(ctx.waves[ctx.lane]) do
		if live(creep) and not NPC.IsRanged(creep) and NPC.IsRunning(creep) and not NPC.IsAttacking(creep) then
			local _, progress, offset = geometry.project(ctx, task.route, Entity.GetAbsOrigin(creep))
			if progress < task.crossing - 150 and offset < 350 then
				earliest = math.min(earliest, (task.crossing - progress) / math.max(100, NPC.GetMoveSpeed(creep)))
			end
		end
	end
	if earliest == math.huge then return nil end
	return ctx.clock + earliest - travel - delay
end

local function allowed(ctx)
	if ctx.role < 4 or ctx.clock < 60 or ctx.health < 0.55 or ctx.retreating or ctx.intent or ctx.runeTask or ctx.objectiveTask
		or ctx.teamTask and (ctx.teamTask.fighting or ctx.teamTask.kind ~= "protect")
		or ctx.laneThreat and (ctx.laneThreat.avoid or ctx.laneThreat.attacked) then return false end
	for _, ally in ipairs(ctx.allies) do
		if live(ally) and ally ~= ctx.hero and ctx.distance(ctx.position, Entity.GetAbsOrigin(ally)) < 1300 and Hero.GetRecentDamage(ally) > 0 then return false end
	end
	return true
end

function camps.plan(ctx)
	if ctx.now < (ctx.nextCampPlan or 0) or not allowed(ctx) then return nil end
	ctx.nextCampPlan = ctx.now + 0.5
	for _, wave in ipairs(ctx.waves or {}) do
		for _, creep in ipairs(wave) do
			if live(creep) and ctx.distance(ctx.position, Entity.GetAbsOrigin(creep)) < 1200 then return nil end
		end
	end
	ctx.campAttempts = ctx.campAttempts or {}
	for key, expiry in pairs(ctx.campAttempts) do
		if type(expiry) ~= "number" or expiry < ctx.clock then ctx.campAttempts[key] = nil end
	end
	local route = geometry.route(ctx, ctx.lane)
	local best, score
	local camps = JungleCampsManager and JungleCampsManager.camps or {}
	for _, camp in pairs(camps) do
		local dist = ctx.distance(ctx.position, camp.position_)
		local far = dist >= 2000
		local kind = camp.camp_type == 0 and ctx.clock < 1200 and route and not far and "pull" or "stack"
		local reach = kind == "stack" and ctx.settings.autoStack ~= false and 4000 or 2000
		if camp.team_ == ctx.team and not camp.is_farmed_ and camp.camp_type <= 2 and dist < reach then
			local members = units(ctx, camp)
			local goal, crossing = destination(ctx, camp, kind, route)
			local key = tostring(camp.index_) .. ":" .. kind .. ":" .. math.floor(ctx.clock / (kind == "pull" and 30 or 60))
			if goal and not ctx.campAttempts[key] and not ctx.unsafePosition(goal) then
				local stale = ctx.now < (ctx.campTriggerAt or 0)
				local task = {camp = camp, kind = kind, destination = goal, crossing = crossing, route = route, key = key,
					spawn = (math.floor(ctx.clock / 60) + 1) * 60, phase = "stage", members = members}
				local range = NPC.GetAttackRange(ctx.hero) + NPC.GetAttackRangeBonus(ctx.hero)
				task.stage = ctx.toward(camp.position_, goal, math.max(100, range - 60))
				task.trigger = trigger(ctx, task, members)
				local length = GridNav.IsTraversable(task.stage) and navigation.safePath(ctx, task.stage, 20)
				local arrival = length and length / math.max(100, NPC.GetMoveSpeed(ctx.hero))
				local remaining = task.trigger and task.trigger - ctx.clock
				local waveAtTower = false
				if kind == "pull" then
					for _, creep in ipairs(ctx.creeps) do
						if live(creep) and not Entity.IsSameTeam(ctx.hero, creep) and ctx.distance(Entity.GetAbsOrigin(creep), Entity.GetAbsOrigin(route.front)) < 950 then waveAtTower = true; break end
					end
				end
				if arrival and arrival <= 15 and remaining and remaining >= arrival - 0.2 and remaining <= arrival + 5
					and not waveAtTower and not stale then
					local value = arrival + remaining * 0.3 + (kind == "stack" and 2 or 0)
					if not score or value < score then best, score = task, value end
					if kind == "stack" then ctx.campTriggerAt = (task.trigger or 0) + 1 end
				end
			end
		end
	end
	return best
end

function camps.hurt(ctx, data)
	local task = ctx.campTask
	if task and task.phase == "aggro" and data.source == ctx.hero and data.target == task.target and data.damage > 0 then task.hit = true end
end

function camps.run(ctx)
	if not allowed(ctx) then if ctx.campTask then finish(ctx, "Camp interrupted by lane danger") end; return false end
	local task = ctx.campTask
	if not task then
		local farm = ctx.farmCandidate
		if farm and not farm.allied and farm.start < ctx.now + 1.2 then return false end
		task = camps.plan(ctx)
		if not task then return false end
		ctx.campTask, ctx.campAttempts[task.key] = task, ctx.clock + 65
		task.expires = ctx.now + math.max(0, task.trigger - ctx.clock) + 18
	end
	if ctx.now > task.expires or ctx.unsafePosition(task.destination) then return finish(ctx, "Camp attempt expired or became unsafe") end
	if task.phase == "stage" then
		if task.camp.is_farmed_ then return finish(ctx, "Camp already farmed") end
		local members = units(ctx, task.camp)
		if #members > 0 then
			task.members = members
			local revised = trigger(ctx, task, members)
			if not revised or revised < ctx.clock - 0.6 then return finish(ctx, "Missed camp timing") end
			task.trigger = revised
		elseif ctx.distance(ctx.position, task.camp.position_) < 500 then return finish(ctx, "Camp is empty") end
		if ctx.distance(ctx.position, task.stage) > 60 then return ctx.move(task.stage, "Prepare support " .. task.kind, 40) end
		if ctx.clock < task.trigger then ctx.mode = "Wait for measured " .. task.kind .. " timing"; return ctx.stop() end
		local target = task.members[1]
		if not live(target) then return finish(ctx, "No visible neutral to pull") end
		local acted, issued = ctx.attack(target, "Aggro neutral for " .. task.kind)
		if issued then
			task.target, task.phase, task.aggroAt = target, "aggro", ctx.now
			task.ids = {}
			for _, unit in ipairs(task.members) do task.ids[Entity.GetIndex(unit)] = true end
		end
		return acted
	end
	if task.phase == "aggro" then
		if not live(task.target) then return finish(ctx, "Neutral target lost") end
		local facing = NPC.FindFacingNPC(task.target, nil, Enum.TeamType.TEAM_ENEMY, 30, 1000)
		if task.hit or facing == ctx.hero and NPC.IsRunning(task.target) then
			task.phase, task.followedAt = "drag", ctx.now
		elseif ctx.now - task.aggroAt > 2.5 then return finish(ctx, "Neutral did not follow attack")
		else ctx.mode = "Confirm neutral aggro"; return true end
	end
	if task.kind == "pull" then
		for _, creep in ipairs(ctx.waves[ctx.lane]) do
			if live(creep) and NPC.IsAttacking(creep) then
				local target = NPC.FindFacingNPC(creep, nil, Enum.TeamType.TEAM_ENEMY, 35, NPC.GetAttackRange(creep) + 150)
				if live(target) and NPC.IsNeutral(target) and task.ids[Entity.GetIndex(target)] then return finish(ctx, "Pull connected to allied wave") end
			end
		end
	elseif ctx.clock >= task.spawn + 0.3 then
		ctx.campTriggerAt = 0
		for _, unit in ipairs(units(ctx, task.camp)) do
			if not task.ids[Entity.GetIndex(unit)] then return finish(ctx, "New neutral spawn confirmed") end
		end
		if ctx.clock > task.spawn + 2 then return finish(ctx, "Spawn not confirmed after stack") end
	end
	if ctx.distance(ctx.position, task.destination) < 65 then ctx.mode = "Hold neutral " .. task.kind .. " exit"; return ctx.stop() end
	return ctx.move(task.destination, task.kind == "pull" and "Pull neutrals into approaching wave" or "Stack: lead neutrals clear of spawn box", 40)
end

return camps
