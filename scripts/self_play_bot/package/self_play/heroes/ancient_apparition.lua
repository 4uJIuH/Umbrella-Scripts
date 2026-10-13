local ancient = {reserved = {ancient_apparition_ice_blast = true, ancient_apparition_ice_blast_release = true,
	ancient_apparition_cold_feet = true, ancient_apparition_ice_vortex = true, ancient_apparition_chilling_touch = true}}
local common = require("self_play.heroes.common")
local tactics = require("self_play.heroes.tactics")

local function available(ctx, api, name, urgent)
	local ability = NPC.GetAbility(ctx.hero, name)
	if not ability or (ctx.abilityAttempts[name] or 0) > ctx.now or not api.ready(ctx, ability, false) then return nil end
	local remaining = NPC.GetMana(ctx.hero) - Ability.GetManaCost(ability)
	local reserve = urgent and 0 or NPC.GetMaxMana(ctx.hero) * (ctx.settings.manaReserve or 22) / 100
	return remaining >= reserve and ability or nil
end

function ancient.covered(ctx, point)
	local zones = ctx.heroState.vortexZones or {}
	for index = #zones, 1, -1 do
		local zone = zones[index]
		if ctx.now >= zone.expires then table.remove(zones, index)
		elseif ctx.distance(point, zone.position) < zone.radius * 0.85 then return true end
	end
	return false
end

function ancient.basics(ctx, api, retreat)
	if not ctx.settings.spells or api.busy(ctx) then return false end
	local task = ctx.heroState.iceBlast
	if task and ctx.now >= task.launched + task.distance / task.speed - 0.3 then return false end
	local enemy = tactics.enemy(ctx, 1600)
	if not enemy or NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_MAGIC_IMMUNE)
		or NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE)
		or NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_OUT_OF_GAME) then return false end
	local position = Entity.GetAbsOrigin(enemy)
	local distance = ctx.distance(ctx.position, position)
	local controlled = NPC.IsStunned(enemy) or NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_ROOTED)
	local pressured = ctx.laneThreat and ctx.laneThreat.attacked and ctx.laneThreat.enemy == enemy
	local fighting = retreat or pressured or tactics.committed(ctx, enemy)
		or Hero.GetRecentDamage(enemy) > 0 and tactics.count(ctx, position, 900, true) > 0
	local feetActive = NPC.HasModifier(enemy, "modifier_cold_feet") or NPC.HasModifier(enemy, "modifier_ancient_apparition_cold_feet")
	local feet = available(ctx, api, "ancient_apparition_cold_feet", retreat or pressured)
	if feet and not feetActive and fighting and (controlled or retreat or pressured or NPC.IsAttacking(enemy)) then
		local acted = tactics.cast(ctx, api, "ancient_apparition_cold_feet", "target", enemy)
		if acted then return true end
	end
	local vortex = available(ctx, api, "ancient_apparition_ice_vortex", retreat or pressured)
	if vortex and (fighting or feetActive) and not ancient.covered(ctx, position) then
		local radius = common.value(vortex, "radius", 275)
		local predicted = ctx.predict(enemy, Ability.GetCastPoint(vortex) + 0.25)
		local point = ctx.toward(position, predicted, radius * 0.45)
		if ctx.distance(ctx.position, point) > Ability.GetCastRange(vortex) then
			point = ctx.toward(ctx.position, point, Ability.GetCastRange(vortex))
		end
		if ctx.distance(point, position) < radius * 0.8 and not ancient.covered(ctx, point) then
			local acted, casted = tactics.cast(ctx, api, "ancient_apparition_ice_vortex", "point", nil, point)
			if casted then
				ctx.heroState.vortexZones = ctx.heroState.vortexZones or {}
				ctx.heroState.vortexZones[#ctx.heroState.vortexZones + 1] = {position = point, radius = radius,
					expires = ctx.now + common.value(vortex, "vortex_duration", 6)}
			end
			if acted then return true end
		end
	end
	if feet and not feetActive and fighting then
		if tactics.cast(ctx, api, "ancient_apparition_cold_feet", "target", enemy) then return true end
	end
	local touch = available(ctx, api, "ancient_apparition_chilling_touch", retreat or pressured)
	if not touch or NPC.HasState(ctx.hero, Enum.ModifierState.MODIFIER_STATE_DISARMED)
		or NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_ATTACK_IMMUNE) then return false end
	local range = math.max(Ability.GetCastRange(touch), NPC.GetAttackRange(ctx.hero) + NPC.GetAttackRangeBonus(ctx.hero)
		+ common.value(touch, "attack_range_bonus", 60))
	if distance > range or ctx.now < (ctx.attackNext or 0) then return false end
	local hitTime = (NPC.GetAttackAnimPoint(ctx.hero) or 0) / math.max(0.1, NPC.GetAttackSpeed(ctx.hero))
		+ NPC.GetTimeToFacePosition(ctx.hero, position)
	if task and ctx.now + hitTime + 0.15 >= task.launched + task.distance / task.speed then return false end
	local farm = ctx.farmCandidate
	if not fighting and (ctx.clock < 15 or ctx.health < 0.65 or ctx.nearEnemies > ctx.nearAllies
		or ctx.unsafePosition(ctx.position) or farm and farm.start < ctx.now + hitTime + 0.8
		or ctx.now < (ctx.heroState.nextTouchHarass or 0)) then return false end
	if retreat and (ctx.health < 0.3 or distance < NPC.GetAttackRange(enemy) + 100) then return false end
	local acted, casted = tactics.cast(ctx, api, "ancient_apparition_chilling_touch", "target", enemy, nil, range)
	if casted then
		ctx.busyUntil = math.max(ctx.busyUntil, ctx.now + hitTime + 0.08)
		ctx.attackTarget = enemy
		ctx.heroState.nextTouchHarass = ctx.now + (fighting and 0 or 4)
	end
	return acted
end

function ancient.duringCast(ctx, api)
	local task = ctx.heroState.iceBlast
	if not task then return false end
	if ctx.now > task.expires then ctx.heroState.iceBlast = nil; return false end
	local distance = task.distance
	if common.visible(task.target) then
		local point = ctx.predict(task.target, 0.5)
		local along = (point.x - task.origin.x) * task.dx + (point.y - task.origin.y) * task.dy
		local across = math.abs((point.x - task.origin.x) * task.dy - (point.y - task.origin.y) * task.dx)
		if along > 0 and across < task.radius then distance = math.min(task.distance + 350, along) end
	end
	if ctx.now >= task.launched + distance / task.speed - NetChannel.GetAvgLatency(Enum.Flow.FLOW_OUTGOING) then
		local used, released = tactics.cast(ctx, api, "ancient_apparition_ice_blast_release", "none")
		if released then ctx.heroState.iceBlast = nil end
		return used
	end
	return false
end

function ancient.blast(ctx, api, retreat)
	if retreat or ctx.heroState.iceBlast then return false end
	local blast = common.ability(ctx, api, "ancient_apparition_ice_blast")
	if not blast then return false end
	local target, score
	for _, enemy in ipairs(ctx.enemies) do
		if common.visible(enemy) and not NPC.IsIllusion(enemy) then
			local position = Entity.GetAbsOrigin(enemy)
			local allies = tactics.count(ctx, position, 1000, true)
			local low = Entity.GetHealth(enemy) < Entity.GetMaxHealth(enemy) * 0.4
			if allies > 0 and Hero.GetRecentDamage(enemy) > 0 or low and NPC.IsStunned(enemy) or tactics.committed(ctx, enemy) then
				local value = tactics.count(ctx, position, 400) * 100 + (low and 70 or 0) - ctx.distance(ctx.position, position) * 0.005
				if not score or value > score then target, score = enemy, value end
			end
		end
	end
	if not target then return false end
	local speed = common.value(blast, "speed", 1500)
	local point = tactics.point(ctx, blast, target, speed, 0.5)
	local distance = ctx.distance(ctx.position, point)
	local used, launched = tactics.cast(ctx, api, "ancient_apparition_ice_blast", "point", nil, point, math.huge)
	if launched then ctx.heroState.iceBlast = {target = target, origin = ctx.position, distance = distance,
		dx = (point.x - ctx.position.x) / math.max(1, distance), dy = (point.y - ctx.position.y) / math.max(1, distance),
		launched = ctx.now + Ability.GetCastPoint(blast), speed = speed, radius = common.value(blast, "radius_min", 275),
		expires = ctx.now + Ability.GetCastPoint(blast) + distance / speed + 3} end
	return used
end

function ancient.update(ctx, api, retreat)
	if ancient.duringCast(ctx, api) then return true end
	if ancient.blast(ctx, api, retreat) then return true end
	return ancient.basics(ctx, api, retreat)
end

function ancient.opportunity(ctx, api)
	return ancient.update(ctx, api, false)
end

return ancient
