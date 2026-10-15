local engagement = {}
local awareness = require("self_play.awareness")
local itemKV = XHelpers.xkv:GetKV("items").DOTAAbilities

local function visible(unit)
	return unit and Entity.IsEntity(unit) and Entity.IsAlive(unit) and not Entity.IsDormant(unit) and NPC.IsVisible(unit)
end

function engagement.boldness(ctx)
	local value = (ctx.settings and ctx.settings.confidence or 0.5) - 0.5
	if value < -0.5 then return -0.5 end
	if value > 0.5 then return 0.5 end
	return value
end

local function boldness(ctx)
	return engagement.boldness(ctx)
end

local function strength(unit)
	local health = Entity.GetHealth(unit) / math.max(1, Entity.GetMaxHealth(unit))
	return NPC.GetTrueDamage(unit) / math.max(0.3, NPC.GetSecondsPerAttack(unit, false)) * (0.4 + health * 0.6)
end

function engagement.attackPosition(ctx, target)
	local position = Entity.GetAbsOrigin(target)
	local range = NPC.GetAttackRange(ctx.hero) + NPC.GetAttackRangeBonus(ctx.hero)
	local travel = math.max(0, ctx.distance(ctx.position, position) - range + 20)
	return ctx.toward(ctx.position, position, travel)
end

local function supporters(ctx, target)
	if ctx.supportCacheTick ~= ctx.now then ctx.supportCacheTick, ctx.supportCache = ctx.now, {} end
	local id = Entity.GetIndex(target)
	local cached = ctx.supportCache[id]
	if cached then return cached end
	local result, seen = {}, {}
	local position = Entity.GetAbsOrigin(target)
	local root = ctx.parent or ctx
	local state = root.heroState
	local recent = ctx.allyFights and ctx.allyFights[Entity.GetIndex(target)]
	for group, units in ipairs({ctx.allies, ctx.summons or {}}) do
		for _, ally in ipairs(units) do
			if ally ~= ctx.hero and visible(ally) and Entity.IsSameTeam(ctx.hero, ally) and not seen[ally]
				and (group == 2 or not NPC.IsIllusion(ally)) and not NPC.IsChannellingAbility(ally)
				and not NPC.HasModifier(ally, "modifier_teleporting")
				and not NPC.HasState(ally, Enum.ModifierState.MODIFIER_STATE_OUT_OF_GAME) then
				local id = Entity.GetIndex(ally)
				local order = state and state.unitOrders and state.unitOrders[id]
				local actor = state and state.actors and state.actors[id]
				local ordered = order and order.target == target and ctx.now - order.time < 1.2
				local attacking = NPC.IsAttacking(ally) and NPC.FindFacingNPC(ally, nil, Enum.TeamType.TEAM_ENEMY, 25,
					NPC.GetAttackRange(ally) + NPC.GetAttackRangeBonus(ally) + 150) == target
				local hit = recent and recent.ally == ally and recent.outgoing and ctx.now - recent.time < 1.2
				local distance = ctx.distance(Entity.GetAbsOrigin(ally), position)
				local reach = NPC.GetAttackRange(ally) + NPC.GetAttackRangeBonus(ally)
				local approach = math.max(0, distance - reach) / math.max(100, NPC.GetMoveSpeed(ally))
				if (attacking or ordered or hit) and approach <= (ordered and 1.2 or 0.7)
					and not (actor and actor.retreating) then
					seen[ally] = true
					local control = awareness.control(ctx, ally)
					local disabled = math.max(0, control[Enum.ModifierState.MODIFIER_STATE_STUNNED] or 0,
						control[Enum.ModifierState.MODIFIER_STATE_DISARMED] or 0)
					local unavailable = (NPC.IsStunned(ally) or NPC.HasState(ally, Enum.ModifierState.MODIFIER_STATE_DISARMED)) and disabled == 0
					local point = NPC.GetAttackAnimPoint(ally)
					local modifier = NPC.GetModifier(ally, "modifier_kill")
					local lifetime = modifier and math.max(0, Modifier.GetDieTime(modifier) - ctx.now) or math.huge
					if not unavailable and point and lifetime > disabled then
						local flight = 0
						if NPC.IsRanged(ally) then
							local speed = NPC.GetAttackProjectileSpeed(ally)
							if speed and speed > 0 then flight = math.min(distance, reach) / speed end
						end
						local burst, casting, burstAt = 0, 0, math.min(2, lifetime)
						if group == 2 and actor and actor.hero == ally and ctx.settings.spells and NPC.IsHero(ally) then
							burst, casting = awareness.burst(ctx, ally, target, distance, burstAt)
						end
						local first = math.max(approach, disabled) + NPC.GetTimeToFace(ally, target)
							+ point / math.max(0.2, NPC.GetAttackSpeed(ally)) + flight + casting
						if first < lifetime or burst > 0 then
							result[#result + 1] = {first = first, lifetime = lifetime, burst = burst, burstAt = burstAt,
								period = math.max(0.3, NPC.GetSecondsPerAttack(ally, false)),
								damage = NPC.GetTrueDamage(ally) * NPC.GetArmorDamageMultiplier(target) * 0.7}
						end
					end
				end
			end
		end
	end
	ctx.supportCache[id] = result
	return result
end

local function supportDamage(units, elapsed)
	local damage = 0
	for _, unit in ipairs(units) do
		local duration = math.min(elapsed, unit.lifetime)
		if duration >= unit.first then damage = damage + unit.damage * (1 + math.floor((duration - unit.first) / unit.period)) end
	end
	return damage
end

local function bristleBack(ctx, target, position)
	if NPC.GetUnitName(target) ~= "npc_dota_hero_bristleback" then return false end
	local forward = Entity.GetRotation(target):GetForward()
	local dx, dy = ctx.position.x - position.x, ctx.position.y - position.y
	local length = math.sqrt(dx * dx + dy * dy)
	if length < 1 then return false end
	return (dx * forward.x + dy * forward.y) / length < -0.15
end

function engagement.assess(ctx, target)
	if not visible(target) or not NPC.IsHero(target) or Entity.IsSameTeam(ctx.hero, target)
		or NPC.HasState(target, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE)
		or NPC.HasState(target, Enum.ModifierState.MODIFIER_STATE_ATTACK_IMMUNE)
		or NPC.HasState(ctx.hero, Enum.ModifierState.MODIFIER_STATE_DISARMED) or NPC.IsStunned(ctx.hero) then return nil end
	local position = Entity.GetAbsOrigin(target)
	local distance = ctx.distance(ctx.position, position)
	local range = NPC.GetAttackRange(ctx.hero) + NPC.GetAttackRangeBonus(ctx.hero)
	local travel = math.max(0, distance - range + 20)
	local approach = travel / math.max(100, NPC.GetMoveSpeed(ctx.hero))
	local point = ctx.toward(ctx.position, position, travel)
	local committed = ctx.intent and ctx.intent.kind == "hero" and ctx.intent.target == target
	if distance > (committed and 1400 or 1100) or approach > 3.5 or ctx.unsafePosition(point)
		or not GridNav.IsTraversable(point) then return nil end
	if not committed and bristleBack(ctx, target, position) then return nil end
	local damage = NPC.GetTrueDamage(ctx.hero) * NPC.GetArmorDamageMultiplier(target)
	local dps = damage / math.max(0.3, NPC.GetSecondsPerAttack(ctx.hero, false))
	local support = supporters(ctx, target)
	local burst, casting, selfCost = awareness.burst(ctx, ctx.hero, target, distance, 2)
	local spellCost = selfCost
	local barriers = NPC.GetBarriers(target)
	local barrierHP = barriers and (barriers.all.current + barriers.physical.current + barriers.magic.current) or 0
	local killTime = approach + casting + math.max(0.25, (Entity.GetHealth(target) + barrierHP - burst) / math.max(1, dps - NPC.GetHealthRegen(target)))
	if #support > 0 or ctx.heroModule and ctx.heroModule.attackDamage then
		killTime = math.huge
		for step = 1, 32 do
			local elapsed = step * 0.25
			local seconds = math.max(0, elapsed - approach - casting)
			local extra, cost = 0, 0
			if ctx.heroModule and ctx.heroModule.attackDamage then extra, cost = ctx.heroModule.attackDamage(ctx, target, seconds) end
			if seconds > 0 and burst + extra + dps * seconds + supportDamage(support, elapsed) >= Entity.GetHealth(target) + barrierHP + NPC.GetHealthRegen(target) * elapsed then
				killTime, selfCost = elapsed, selfCost + cost
				break
			end
		end
	end
	local horizon = math.min(8.5, killTime + 0.4)
	local incoming = math.max((awareness.damage(ctx, ctx.position, horizon)), (awareness.damage(ctx, point, horizon)))
	local future = awareness.forecast(ctx, point)
	local projectiles = 0
	for _, entry in pairs(ctx.projectiles or {}) do
		if entry.target == ctx.hero and entry.impact >= ctx.now and entry.impact <= ctx.now + horizon then projectiles = projectiles + entry.damage end
	end
	incoming = incoming + future + projectiles
	local hp, maximum = Entity.GetHealth(ctx.hero), Entity.GetMaxHealth(ctx.hero)
	local regen = NPC.GetHealthRegen(ctx.hero)
	local armlet = NPC.GetItem(ctx.hero, "item_armlet", true)
	if armlet and Item.IsItemEnabled(armlet) and Ability.GetToggleState(armlet) then
		regen = regen - tonumber(itemKV.item_armlet.AbilityValues.unholy_health_drain_per_second)
	end
	if NPC.GetModifierProperty(ctx.hero, Enum.ModifierFunction.MODIFIER_PROPERTY_DISABLE_HEALING) > 0 then regen = 0 end
	local healing = math.min(math.max(0, regen), maximum * 0.08) * math.max(0, horizon - 0.4)
	local immediate = awareness.damage(ctx, ctx.position, 0.65) + projectiles + future
	local ownBarriers = NPC.GetBarriers(ctx.hero)
	local shield = ownBarriers and ownBarriers.all.current or 0
	local remaining = hp + healing + shield - incoming - selfCost
	local bold = boldness(ctx)
	local safe = killTime <= 8 + bold * 3 and immediate < (hp + shield) * (0.6 + bold * 0.45)
		and remaining > math.max(maximum * 0.15 + bold * maximum * 0.12, hp * (0.3 + bold * 0.35))
	local exchange = 2.5
	local seconds = math.max(0, exchange - approach - casting)
	local extra, cost = 0, 0
	if ctx.heroModule and ctx.heroModule.attackDamage then extra, cost = ctx.heroModule.attackDamage(ctx, target, seconds) end
	local assisted = supportDamage(support, exchange)
	local dealt = math.max(0, burst + dps * seconds + extra + assisted - NPC.GetHealthRegen(target) * exchange - barrierHP)
	local received = math.max((awareness.damage(ctx, ctx.position, exchange)), (awareness.damage(ctx, point, exchange)))
		+ future + projectiles + cost + spellCost
	local pursuer = NPC.IsAttacking(target) and NPC.FindFacingNPC(target, nil, Enum.TeamType.TEAM_ENEMY, 25,
		NPC.GetAttackRange(target) + NPC.GetAttackRangeBonus(target) + 150) == ctx.hero
		or ctx.heroHarass and ctx.heroHarass.source == target and ctx.now - ctx.heroHarass.time < 2
	local returnFire = pursuer and approach < 0.9 and future == 0 and hp > maximum * 0.4
		and received < (hp + shield) * 0.3 and dealt / math.max(1, Entity.GetHealth(target)) >= received / math.max(1, hp + shield)
	local trade = approach < 0.2 and hp > maximum * 0.65 and future == 0 and received < hp * 0.18
		and dealt / math.max(1, Entity.GetHealth(target)) > received / math.max(1, hp) * 1.2
	local assist = assisted > 0 and hp > maximum * 0.55 and future == 0 and received < hp * 0.22 and remaining > maximum * 0.3
	local follow = false
	if committed and ctx.intent.followUntil and ctx.now < ctx.intent.followUntil and hp > maximum * 0.55
		and future == 0 and received < hp * 0.22 and immediate < hp * 0.3 then
		local motion = ctx.history and ctx.history[Entity.GetIndex(target)]
		local away = motion and ((position.x - ctx.position.x) * motion.vx + (position.y - ctx.position.y) * motion.vy) / math.max(1, distance) or 0
		local closing = NPC.GetMoveSpeed(ctx.hero) - math.max(0, away)
		follow = travel < 100 or closing > 50 and travel / closing < 2
	end
	return {target = target, safe = safe, follow = follow, assist = assist, trade = trade, returnFire = returnFire, killTime = killTime,
		incoming = incoming, remaining = remaining, approach = approach, supportDamage = assisted, supportUnits = #support}
end

function engagement.keep(decision)
	return decision and (decision.safe or decision.returnFire or decision.trade or decision.assist or decision.follow) == true
end

function engagement.choose(ctx)
	local bold = boldness(ctx)
	if ctx.hardRetreat or ctx.health < 0.2 - bold * 0.15 or ctx.clock < 35 then return nil end
	if ctx.recovering and bold <= 0 then return nil end
	local liveCast = false
	for _, target in ipairs(ctx.enemies) do
		if visible(target) and NPC.IsChannellingAbility(target) then liveCast = true; break end
	end
	if not liveCast and ctx.now < (ctx.nextOpportunity or 0) and ctx.opportunityCache ~= nil then
		return ctx.opportunityCache.best
	end
	local best, bestScore = nil, 0
	local ownStrength = strength(ctx.hero)
	local range = NPC.GetAttackRange(ctx.hero) + NPC.GetAttackRangeBonus(ctx.hero)
	for _, target in ipairs(ctx.enemies) do
		if visible(target) and not NPC.HasState(target, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE)
			and not NPC.HasState(target, Enum.ModifierState.MODIFIER_STATE_ATTACK_IMMUNE)
			and not ctx.unsafePosition(engagement.attackPosition(ctx, target)) then
			local position = Entity.GetAbsOrigin(target)
			local distance = ctx.distance(ctx.position, position)
			if distance <= 1100 then
				local assessment = engagement.assess(ctx, target)
				local winning = assessment and assessment.safe
				local retaliation = assessment and assessment.returnFire
				local approach = math.max(0, distance - range) / math.max(100, NPC.GetMoveSpeed(ctx.hero))
				local physical = NPC.GetTrueDamage(ctx.hero) * NPC.GetArmorDamageMultiplier(target)
				local burst = awareness.burst(ctx, ctx.hero, target, distance, 2)
				local kill = approach < 1.8 and Entity.GetHealth(target) <= burst + physical * math.max(1, (2.5 - approach) / math.max(0.3, NPC.GetSecondsPerAttack(ctx.hero, false)))
				local friendly, hostile, joining = ownStrength, 0, false
				for _, ally in ipairs(ctx.allies) do
					if ally ~= ctx.hero and visible(ally) and ctx.distance(Entity.GetAbsOrigin(ally), position) < 850 then
						friendly = friendly + strength(ally)
						if NPC.IsAttacking(ally) and NPC.FindFacingNPC(ally, nil, Enum.TeamType.TEAM_ENEMY, 25, NPC.GetAttackRange(ally) + 150) == target
							or Hero.GetRecentDamage(ally) > 0 and ctx.distance(Entity.GetAbsOrigin(ally), position) < 500 then joining = true end
					end
				end
				for _, enemy in ipairs(ctx.enemies) do
					if visible(enemy) and ctx.distance(Entity.GetAbsOrigin(enemy), position) < 900 then hostile = hostile + strength(enemy) end
				end
				local favorable = friendly >= hostile * (1.15 - bold * 0.4)
				local interrupt = NPC.IsChannellingAbility(target)
				local controlled = NPC.IsStunned(target) or NPC.HasState(target, Enum.ModifierState.MODIFIER_STATE_ROOTED)
				local facing = NPC.IsAttacking(target) and NPC.FindFacingNPC(target, nil, Enum.TeamType.TEAM_ENEMY, 25, NPC.GetAttackRange(target) + 100)
				local occupied = visible(facing) and NPC.IsLaneCreep(facing) and Entity.IsSameTeam(ctx.hero, facing)
				local trade = ctx.tradeSafe and ctx.health >= 0.68 and distance < range + 100
					and (favorable or occupied or range >= NPC.GetAttackRange(target) + 150)
				local advantage = favorable and ctx.health > 0.62 and approach < 1.6
				local incoming = ctx.laneThreat and ctx.laneThreat.incoming or 0
				local safe = winning or retaliation or ctx.health >= 0.4 - bold * 0.2 and friendly >= hostile * ((kill and 0.65 or 0.95) - bold * 0.3)
					and ((ctx.creepPressure or 0) < 3 or kill)
					and incoming < Entity.GetHealth(ctx.hero) * ((kill and 0.65 or 0.32) + bold * 0.33)
				if safe and assessment and (winning or retaliation or assessment.trade or assessment.assist)
					and (winning or retaliation or kill or interrupt or joining or controlled or trade or advantage) then
					local score = (kill and 110 or 0) + (interrupt and 85 or 0) + (joining and 75 or 0)
						+ (winning and 65 or 0) + (retaliation and 80 or 0) + (controlled and 50 or 0) + (advantage and 45 or 0) + (trade and 30 or 0) - approach * 12
					local huntBonus = 0
					if ctx.isTurbo and ctx.settings.turboHunt ~= false then
						local heroLevel, targetLevel = NPC.GetCurrentLevel(ctx.hero), NPC.GetCurrentLevel(target)
						if targetLevel + 2 <= heroLevel then huntBonus = huntBonus + 40 end
						if Entity.GetHealth(target) < Entity.GetMaxHealth(target) * 0.45 then huntBonus = huntBonus + 25 end
						if hostile <= ownStrength * 0.6 then huntBonus = huntBonus + 20 end
					end
					score = score + huntBonus
					if score > bestScore then
						local urgent = kill or interrupt or retaliation or winning and (assessment.killTime < 2.5 or ctx.laneThreat and ctx.laneThreat.avoid) or joining and (ctx.clock >= (ctx.laneEnd or 600) or ctx.role >= 4
							or ctx.isTurbo or ctx.fullBuild or Entity.GetHealth(target) < Entity.GetMaxHealth(target) * 0.5)
						best, bestScore = {target = target, score = score, approach = approach, urgent = urgent}, score
					end
				end
			end
		end
	end
	ctx.opportunityCache, ctx.nextOpportunity = {best = best}, ctx.now + 0.1
	return best
end

return engagement
