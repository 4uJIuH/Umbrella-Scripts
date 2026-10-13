local help = {}
local awareness = require("self_play.awareness")
local navigation = require("self_play.navigation")
local itemKV = XHelpers.xkv:GetKV("items").DOTAAbilities

local function visible(unit)
	return unit and Entity.IsEntity(unit) and Entity.IsAlive(unit) and not Entity.IsDormant(unit) and NPC.IsVisible(unit)
end

local function release(ctx, reason)
	ctx.helpRotation, ctx.teamTask = nil, nil
	ctx.nextHelpTeleport, ctx.helpLaneUntil = ctx.now + 8, ctx.now + 10
	ctx.helpStatus = reason
	return false
end

function help.evaluate(ctx, task, arrival)
	if ctx.role <= 3 and not ctx.isTurbo and ctx.settings.carryHoldLane ~= false and not ctx.baseDefense
		and not ctx.fullBuild then
		return nil, "Carry holds lane/jungle; no help rotations"
	end
	local midGate = ctx.isTurbo and 4 or 6
	if ctx.role == 2 and NPC.GetCurrentLevel(ctx.hero) < midGate and not ctx.baseDefense then return nil, "Mid fight rotations unlock at level 6" end
	if not task or not task.fighting or not visible(task.target) or ctx.now < (ctx.nextHelpTeleport or 0) then return nil, "No current fight worth teleporting to" end
	local channel = tonumber(itemKV.item_tpscroll.AbilityChannelTime) + 0.5
	for _, hero in ipairs(ctx.allies) do
		if hero ~= ctx.hero and visible(hero) and NPC.HasModifier(hero, "modifier_teleporting")
			and ctx.distance(Entity.GetAbsOrigin(hero), arrival) < 1000 then channel = channel + 2 end
	end
	local target = task.target
	local point = ctx.predict(target, math.min(2, channel))
	local range = NPC.GetAttackRange(ctx.hero) + NPC.GetAttackRangeBonus(ctx.hero)
	local firing = ctx.toward(point, arrival, math.max(100, range - 40))
	local view = setmetatable({position = arrival}, {__index = ctx})
	local length = navigation.safePath(view, firing, 40)
	if not length then return nil, "No safe path from teleport landing to fight" end
	local eta = channel + length / math.max(100, NPC.GetMoveSpeed(ctx.hero))
	local motion = ctx.history and ctx.history[Entity.GetIndex(target)]
	if motion and NPC.IsRunning(target) then
		local separation = ctx.distance(arrival, point)
		local away = ((point.x - arrival.x) * motion.vx + (point.y - arrival.y) * motion.vy) / math.max(1, separation)
		if separation > range + 250 and away > NPC.GetMoveSpeed(ctx.hero) - 30 then return nil, "Escaping target will outrun our arrival" end
	end
	if eta > 8 or length > 1400 then return nil, "Fight too far from teleport landing" end
	local survivors, alliedDPS, survivorDPS = 0, 0, 0
	for _, hero in ipairs(task.members) do
		if visible(hero) and ctx.distance(Entity.GetAbsOrigin(hero), Entity.GetAbsOrigin(target)) < 1400 then
			local allyView = setmetatable({hero = hero}, {__index = ctx})
			local position = ctx.predict(hero, math.min(2, eta))
			local damage = awareness.damage(allyView, position, eta) * 0.75
			local remaining = Entity.GetHealth(hero) + NPC.GetHealthRegen(hero) * eta - damage
			local dps = NPC.GetTrueDamage(hero) / math.max(0.3, NPC.GetSecondsPerAttack(hero, false))
			if remaining > Entity.GetMaxHealth(hero) * 0.18 then survivors, survivorDPS = survivors + 1, survivorDPS + dps end
			local hit = ctx.allyFights and ctx.allyFights[Entity.GetIndex(target)]
			if NPC.IsAttacking(hero) and NPC.FindFacingNPC(hero, nil, Enum.TeamType.TEAM_ENEMY, 25, NPC.GetAttackRange(hero) + 150) == target
				or hit and hit.ally == hero and hit.outgoing and ctx.now - hit.time < 1.2 then
				alliedDPS = alliedDPS + dps * NPC.GetArmorDamageMultiplier(target) * 0.65
			end
		end
	end
	if survivors == 0 then return nil, "Allies unlikely to survive until arrival" end
	if Entity.GetHealth(target) + NPC.GetHealthRegen(target) * eta < alliedDPS * eta then return nil, "Allies likely finish this target before arrival" end
	local enemyDPS = 0
	for _, enemy in ipairs(ctx.enemies) do
		if visible(enemy) and ctx.distance(Entity.GetAbsOrigin(enemy), point) < 1400 then
			enemyDPS = enemyDPS + NPC.GetTrueDamage(enemy) / math.max(0.3, NPC.GetSecondsPerAttack(enemy, false))
		end
	end
	for _, incoming in ipairs(ctx.teleportArrivals or {}) do
		if incoming.remaining < eta + 2 and ctx.distance(incoming.position, point) < 1400 then return nil, "Enemy reinforcement reaches this fight first" end
	end
	local ownDPS = NPC.GetTrueDamage(ctx.hero) / math.max(0.3, NPC.GetSecondsPerAttack(ctx.hero, false))
	local burst = awareness.burst(ctx, ctx.hero, target, range, 2)
	if survivorDPS + ownDPS + burst / 3 < enemyDPS * 0.95 then return nil, "Our arrival does not turn this fight" end
	if awareness.damage(ctx, firing, 2.5) + awareness.forecast(ctx, firing) > Entity.GetHealth(ctx.hero) * 0.4 then return nil, "Unsafe damage exposure after landing" end
	return {eta = eta, goal = firing, survivors = survivors, target = target}, "Useful arrival predicted"
end

function help.commit(ctx, task, arrival, estimate)
	ctx.helpRotation = {target = estimate.target, members = task.members, arrival = arrival,
		origin = ctx.position, goal = estimate.goal, started = ctx.now, expires = ctx.now + 14,
		phase = "channel", eta = estimate.eta, lastContact = ctx.now}
	ctx.regroupTask, ctx.campTask, ctx.runeTask, ctx.riverTask, ctx.objectiveTask, ctx.clearTask = nil, nil, nil, nil, nil, nil
	ctx.helpStatus = string.format("Teleport committed: arrival in %.1fs, %d allies expected alive", estimate.eta, estimate.survivors)
end

function help.update(ctx)
	local task = ctx.helpRotation
	if not task then return false end
	if ctx.hardRetreat or ctx.retreating or not Entity.IsAlive(ctx.hero) then return release(ctx, "Help rotation released for survival") end
	if ctx.now > task.expires then return release(ctx, "Help rotation time budget expired") end
	if task.phase == "channel" then
		local scroll = NPC.GetItem(ctx.hero, "item_tpscroll", false)
		if NPC.HasModifier(ctx.hero, "modifier_teleporting") or scroll and Ability.IsChannelling(scroll) or NPC.IsChannellingAbility(ctx.hero) then
			task.channelSeen = true
			local modifier = NPC.GetModifier(ctx.hero, "modifier_teleporting")
			if modifier then task.expires = math.max(task.expires, Modifier.GetDieTime(modifier) + 7) end
		elseif ctx.distance(ctx.position, task.arrival) < 900 and ctx.distance(ctx.position, task.origin) > 1800 then
			task.phase, task.expires, task.lastContact = "join", ctx.now + 7, ctx.now
			ctx.nextRotation = ctx.now + 10
		elseif task.channelSeen or ctx.now - task.started > 1.5 then return release(ctx, "Help teleport interrupted or not acknowledged") end
	end
	local members, target = {}, nil
	for _, hero in ipairs(task.members) do
		if visible(hero) and Entity.GetHealth(hero) > Entity.GetMaxHealth(hero) * 0.2
			and ctx.distance(Entity.GetAbsOrigin(hero), task.goal) < 1800 then members[#members + 1] = hero end
	end
	if task.phase == "join" then
		if #members == 0 then return release(ctx, "Allies left or died before we could join") end
		local best = -math.huge
		for _, enemy in ipairs(ctx.enemies) do
			if visible(enemy) and not NPC.IsIllusion(enemy) and ctx.distance(Entity.GetAbsOrigin(enemy), task.goal) < 1600 then
				local evidence = enemy == task.target and ctx.now - task.lastContact < 2
				local hit = ctx.allyFights and ctx.allyFights[Entity.GetIndex(enemy)]
				for _, hero in ipairs(members) do
					if hit and hit.ally == hero and ctx.now - hit.time < 2
						or NPC.IsAttacking(hero) and NPC.FindFacingNPC(hero, nil, Enum.TeamType.TEAM_ENEMY, 25, NPC.GetAttackRange(hero) + 150) == enemy then evidence = true end
				end
				local score = (enemy == task.target and 200 or 0) - Entity.GetHealth(enemy) * 0.1 - ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy)) * 0.1
				if evidence and score > best then target, best = enemy, score end
			end
		end
		if target then
			if target ~= task.target or NPC.IsAttacking(target) or ctx.allyFights and ctx.allyFights[Entity.GetIndex(target)] and ctx.now - ctx.allyFights[Entity.GetIndex(target)].time < 1 then task.lastContact = ctx.now end
			task.target = target
			local range = NPC.GetAttackRange(ctx.hero) + NPC.GetAttackRangeBonus(ctx.hero)
			task.goal = ctx.toward(ctx.predict(target, 0.4), ctx.position, math.max(100, range - 40))
		elseif ctx.now - task.lastContact > 2 then return release(ctx, "Fight ended; no remaining confirmed opponent") end
		if ctx.unsafePosition(task.goal) or awareness.damage(ctx, task.goal, 2) > Entity.GetHealth(ctx.hero) * 0.4 then return release(ctx, "Landing follow-up became unsafe") end
	end
	ctx.teamTask = {kind = "group", target = target or task.target, members = members, fighting = true,
		goal = task.goal, expires = task.expires, help = true}
	ctx.regroupTask, ctx.campTask, ctx.runeTask, ctx.objectiveTask = nil, nil, nil, nil
	ctx.helpStatus = task.phase == "channel" and "Committed help teleport: preserve channel" or "Landed: follow the allied fight"
	return true
end

return help
