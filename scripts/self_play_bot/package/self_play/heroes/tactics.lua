local tactics = {}
local common = require("self_play.heroes.common")
local awareness = require("self_play.awareness")
local activeItems = require("self_play.active_items")

function tactics.committed(ctx, enemy)
	return common.visible(enemy) and (ctx.intent and ctx.intent.kind == "hero" and ctx.intent.target == enemy
		or ctx.attackTarget == enemy and NPC.IsAttacking(ctx.hero) or NPC.IsChannellingAbility(enemy)
		or Hero.GetRecentDamage(ctx.hero) > 0 and ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy)) < 900
		or ctx.fightSession ~= nil)
end

function tactics.enemy(ctx, range)
	local target = common.enemy(ctx, range)
	if target then return target end
	local best, score
	for _, enemy in ipairs(ctx.enemies) do
		if common.visible(enemy) and not NPC.IsIllusion(enemy)
			and not NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE)
			and not NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_OUT_OF_GAME) then
			local distance = ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy))
			if distance <= range and (not score or distance < score) then best, score = enemy, distance end
		end
	end
	return best
end

function tactics.count(ctx, position, radius, allies)
	local count = 0
	for _, unit in ipairs(allies and ctx.allies or ctx.enemies) do
		if common.visible(unit) and not NPC.IsIllusion(unit) and ctx.distance(position, Entity.GetAbsOrigin(unit)) < radius then count = count + 1 end
	end
	return count
end

function tactics.safe(ctx, point, seconds)
	return not ctx.hardRetreat and GridNav.IsTraversable(point) and not ctx.unsafePosition(point)
		and awareness.damage(ctx, point, seconds or 2) + awareness.forecast(ctx, point) < Entity.GetHealth(ctx.hero) * 0.55
end

function tactics.injured(ctx, range, threshold, threatened)
	local best, score
	for _, ally in ipairs(ctx.allies) do
		if common.visible(ally) and not NPC.IsIllusion(ally) and ctx.distance(ctx.position, Entity.GetAbsOrigin(ally)) <= range then
			local health = Entity.GetHealth(ally) / math.max(1, Entity.GetMaxHealth(ally))
			local incoming = awareness.damage(ctx, Entity.GetAbsOrigin(ally), 1.5)
			if health < threshold and (not threatened or Hero.GetRecentDamage(ally) > 0 or incoming > Entity.GetHealth(ally) * 0.15)
				and (not score or health < score) then best, score = ally, health end
		end
	end
	return best
end

function tactics.point(ctx, ability, target, speed, delay)
	local time = Ability.GetCastPoint(ability) + (delay or 0) + NetChannel.GetAvgLatency(Enum.Flow.FLOW_OUTGOING)
	if not NPC.IsHero(target) then return Entity.GetAbsOrigin(target) end
	local point = ctx.predict(target, time)
	for _ = 1, 3 do
		point = ctx.predict(target, time + (speed and ctx.distance(ctx.position, point) / math.max(1, speed) or 0))
	end
	return point
end

function tactics.cast(ctx, api, name, kind, target, point, reach)
	local ability = NPC.GetAbility(ctx.hero, name)
	if not ctx.settings.spells or NPC.IsSilenced(ctx.hero) or not ability or Ability.GetLevel(ability) < 1 or Ability.IsHidden(ability) or not Ability.IsActivated(ability)
		or not Ability.IsReady(ability) or (ctx.abilityAttempts[name] or 0) > ctx.now then return false end
	local range = reach or Ability.GetCastRange(ability)
	if kind == "target" and (not common.visible(target) or not api.allowed(ctx, ability, target)
		or ctx.distance(ctx.position, Entity.GetAbsOrigin(target)) > range) then return false end
	if kind == "point" and (not point or ctx.distance(ctx.position, point) > range) then return false end
	if kind ~= "toggle" and Ability.GetManaCost(ability) > 0 and activeItems.fuel(ctx, api, ability) then return true, false end
	if not api.ready(ctx, ability, false) then return false end
	if api.cast(ctx, ability, kind, target, point) then return true, true end
	return false
end

function tactics.blink(ctx, api, point, follow, radius)
	local spell = NPC.GetAbility(ctx.hero, follow)
	if not spell or not api.ready(ctx, spell, false) or not tactics.safe(ctx, point, 2) then return false end
	if ctx.distance(ctx.position, point) < radius then return false end
	for _, name in ipairs({"item_overwhelming_blink", "item_arcane_blink", "item_swift_blink", "item_blink"}) do
		local blink = common.ability(ctx, api, name)
		if blink and ctx.distance(ctx.position, point) <= Ability.GetCastRange(blink) - 50 then
			if api.cast(ctx, blink, "point", nil, point) then
				ctx.heroState.initiation = {expires = ctx.now + 1.5, target = ctx.target}
				return true
			end
		end
	end
	return false
end

function tactics.steer(ctx, point, label)
	if ctx.now >= (ctx.heroState.nextSteer or 0) then
		NPC.MoveTo(ctx.hero, point, false, false, false, true)
		ctx.heroState.nextSteer = ctx.now + 0.15
	end
	ctx.mode = label
	return true
end

function tactics.farmTarget(ctx, range)
	local target = ctx.attackTarget
	if common.visible(target) and not Entity.IsSameTeam(ctx.hero, target) and NPC.IsCreep(target)
		and ctx.distance(ctx.position, Entity.GetAbsOrigin(target)) <= range and NPC.IsAttacking(ctx.hero) then return target end
	if ctx.jungleState and ctx.jungleState.task then
		target = ctx.jungleState.task.target
		if common.visible(target) and ctx.distance(ctx.position, Entity.GetAbsOrigin(target)) <= range then return target end
	end
end

return tactics
