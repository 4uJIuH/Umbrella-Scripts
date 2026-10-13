local fiend = {reserved = {item_cyclone = true, nevermore_requiem = true, nevermore_frenzy = true,
	nevermore_shadowraze1 = true, nevermore_shadowraze2 = true, nevermore_shadowraze3 = true}}
local common = require("self_play.heroes.common")
local geometry = require("self_play.cast_geometry")

function fiend.locked(ctx)
	return ctx.heroState.cyclone ~= nil or ctx.heroState.razeAim ~= nil
end

function fiend.skillPriority(ctx, name)
	return name == "nevermore_shadowraze1" and 180 or name == "nevermore_requiem" and 190 or 0
end

local function raze(ctx, api, enemy)
	local state = ctx.heroState
	if not enemy then state.razeAim = nil; return false end
	local best, bestOffset, bestRadius, bestScore, bestPosition
	for index = 1, 3 do
		local ability = common.ability(ctx, api, "nevermore_shadowraze" .. index)
		if ability then
			local offset = common.value(ability, "shadowraze_range", 200 + (index - 1) * 250)
			local radius = common.value(ability, "shadowraze_radius", 250)
			local predicted = ctx.predict(enemy, Ability.GetCastPoint(ability) + NetChannel.GetAvgLatency(Enum.Flow.FLOW_OUTGOING))
			local distance = ctx.distance(ctx.position, predicted)
			local reserve = NPC.GetMaxMana(ctx.hero) * (ctx.settings.manaReserve or 22) / 100
			if math.abs(distance - offset) < radius - 60 and NPC.GetMana(ctx.hero) - Ability.GetManaCost(ability) >= reserve then
				local score = radius - math.abs(distance - offset)
				if state.razeAim and state.razeAim.name == Ability.GetName(ability) then score = score + 100 end
				if not bestScore or score > bestScore then
					best, bestOffset, bestRadius, bestScore, bestPosition = ability, offset, radius, score, predicted
				end
			end
		end
	end
	if not best then state.razeAim = nil; return false end
	local forward = Entity.GetRotation(ctx.hero):GetForward()
	local dx, dy = bestPosition.x - ctx.position.x, bestPosition.y - ctx.position.y
	local distance = math.max(1, math.sqrt(dx * dx + dy * dy))
	if (dx * forward.x + dy * forward.y) / distance > 0.9
		and geometry.frontHit(ctx.position, forward, bestPosition, bestOffset, bestRadius - 25) then
		state.razeAim = nil
		return api.cast(ctx, best, "none")
	end
	if state.razeAim and ctx.now > state.razeAim.expires then
		state.razeAim, state.nextRazeAim = nil, ctx.now + 0.6
		return false
	end
	if ctx.now < (state.nextRazeAim or 0) then return false end
	state.razeAim = state.razeAim or {name = Ability.GetName(best), expires = ctx.now + 0.65}
	return common.face(ctx, enemy, "Shadow Fiend: face raze target")
end

function fiend.update(ctx, api, retreat)
	local state = ctx.heroState
	local ultimate = common.ability(ctx, api, "nevermore_requiem")
	local combo = state.cyclone
	if combo then
		if retreat or ctx.now > combo.expires or not common.visible(combo.target) or not ultimate
			or ctx.unsafePosition(Entity.GetAbsOrigin(combo.target)) then state.cyclone = nil; return false end
		local lifted = NPC.GetModifier(combo.target, "modifier_eul_cyclone")
		if not lifted then
			if ctx.now - combo.started > 0.65 then state.cyclone = nil; return false end
			ctx.mode = "Shadow Fiend: confirm cyclone"
			return true
		end
		local remaining = common.remaining(lifted, ctx.now)
		local position = Entity.GetAbsOrigin(combo.target)
		local distance = ctx.distance(ctx.position, position)
		local castTime = Ability.GetCastPoint(ultimate) + NetChannel.GetAvgLatency(Enum.Flow.FLOW_OUTGOING)
		if distance > 100 then
			local blink = common.ability(ctx, api, "item_blink")
			if blink and distance <= Ability.GetCastRange(blink) and GridNav.IsTraversable(position) then return api.cast(ctx, blink, "point", nil, position) end
			local travel = math.max(0, distance - 70) / math.max(100, NPC.GetMoveSpeed(ctx.hero))
			if remaining < castTime + travel then state.cyclone = nil; return false end
			return ctx.move(position, "Shadow Fiend: approach cyclone", 65)
		end
		if remaining <= castTime + 0.06 and remaining >= castTime - 0.2 then
			state.cyclone = nil
			ctx.mode = "Shadow Fiend: Requiem on landing"
			return api.cast(ctx, ultimate, "none")
		end
		if remaining < castTime - 0.2 then state.cyclone = nil; return false end
		ctx.mode = "Shadow Fiend: time cyclone landing"
		return ctx.stop()
	end
	if retreat then state.razeAim = nil; return false end
	local combatEnemy = common.enemy(ctx, 950)
	if combatEnemy and not NPC.HasState(combatEnemy, Enum.ModifierState.MODIFIER_STATE_MAGIC_IMMUNE)
		and not ctx.unsafePosition(Entity.GetAbsOrigin(combatEnemy)) and raze(ctx, api, combatEnemy) then return true end
	if not combatEnemy then state.razeAim = nil end
	local feast = common.ability(ctx, api, "nevermore_frenzy")
	local souls = NPC.GetModifier(ctx.hero, "modifier_nevermore_necromastery")
	local attackTarget = ctx.attackTarget
	if feast and common.visible(attackTarget) and NPC.IsHero(attackTarget) and not Entity.IsSameTeam(ctx.hero, attackTarget)
		and NPC.IsAttacking(ctx.hero) and ctx.health > 0.55 and ctx.nearEnemies <= ctx.nearAllies
		and ctx.distance(ctx.position, Entity.GetAbsOrigin(attackTarget)) <= NPC.GetAttackRange(ctx.hero)
		and Entity.GetHealth(attackTarget) > NPC.GetTrueDamage(ctx.hero) * 2
		and not ctx.unsafePosition(Entity.GetAbsOrigin(attackTarget)) then return api.cast(ctx, feast, "none") end
	if not ultimate then return false end
	if not souls or Modifier.GetStackCount(souls) < 8 then return false end
	local enemy = common.enemy(ctx, 650)
	if not enemy or ctx.health < 0.55 or ctx.nearEnemies > ctx.nearAllies then return false end
	local distance = ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy))
	local cyclone = common.ability(ctx, api, "item_cyclone")
	if cyclone and ctx.now >= (state.nextCombo or 0) and Entity.GetHealth(enemy) > NPC.GetTrueDamage(ctx.hero) * 2
		and NPC.GetMana(ctx.hero) >= Ability.GetManaCost(cyclone) + Ability.GetManaCost(ultimate) + 40 then
		local blink = common.ability(ctx, api, "item_blink")
		local travel = blink and 0.2 or math.max(0, distance - 70) / math.max(100, NPC.GetMoveSpeed(ctx.hero))
		if travel + Ability.GetCastPoint(ultimate) + 0.15 < common.value(cyclone, "cyclone_duration", 2.5)
			and common.cast(ctx, api, cyclone, "target", enemy) then
			state.cyclone, state.nextCombo = {target = enemy, started = ctx.now, expires = ctx.now + 4}, ctx.now + 4
			return true
		end
	end
	if distance < 300 and NPC.IsStunned(enemy) then return api.cast(ctx, ultimate, "none") end
	return false
end

function fiend.duringCast(ctx, api)
	local state = ctx.heroState
	if not NPC.IsChannellingAbility(ctx.hero) then state.requiem = nil; return false end
	state.requiem = state.requiem or ctx.now
	local hurt = Hero.GetRecentDamage(ctx.hero) > 0
	if ctx.hardRetreat or ctx.unsafePosition(ctx.position) or hurt or ctx.now - state.requiem > 1.2 then
		ctx.stop()
		state.requiem = nil
		return true
	end
	return true
end

return fiend
