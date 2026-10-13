local primal = {reserved = {primal_beast_onslaught = true, primal_beast_onslaught_release = true,
	primal_beast_trample = true, primal_beast_pulverize = true, primal_beast_uproar = true}}
local common = require("self_play.heroes.common")
local tactics = require("self_play.heroes.tactics")

function primal.locked(ctx)
	return ctx.heroState.onslaught ~= nil or NPC.HasModifier(ctx.hero, "modifier_primal_beast_trample")
end

function primal.duringCast(ctx, api)
	local task = ctx.heroState.onslaught
	if not task then return false end
	if ctx.now > task.expires then ctx.heroState.onslaught = nil; return false end
	if ctx.hardRetreat and task.target then
		task.target, task.point, task.releaseAt = nil, ctx.toward(ctx.position, ctx.home, 1200), ctx.now + 0.5
	end
	local point = common.visible(task.target) and ctx.predict(task.target, 0.3) or task.point
	if ctx.now >= task.releaseAt then
		local used, cast = tactics.cast(ctx, api, "primal_beast_onslaught_release", "none")
		if cast then ctx.heroState.onslaught = nil end
		return true
	end
	return tactics.steer(ctx, point, "Primal Beast: aim Onslaught charge")
end

function primal.update(ctx, api, retreat)
	if primal.duringCast(ctx, api) then return true end
	local enemy = tactics.enemy(ctx, 1800)
	if NPC.HasModifier(ctx.hero, "modifier_primal_beast_trample") then
		if not enemy or retreat or not tactics.safe(ctx, Entity.GetAbsOrigin(enemy), 1) then return false end
		local point = ctx.predict(enemy, 0.2)
		local dx, dy = point.x - ctx.position.x, point.y - ctx.position.y
		local length = math.max(1, math.sqrt(dx * dx + dy * dy))
		local angle = ctx.now * 3
		local goal = length < 180 and Vector(point.x + math.cos(angle) * 130, point.y + math.sin(angle) * 130, point.z)
			or Vector(point.x + dx / length * 110, point.y + dy / length * 110, point.z)
		if tactics.safe(ctx, goal, 1) then return ctx.move(goal, "Primal Beast: move through target during Trample", 20) end
		return false
	end
	if not enemy then return false end
	local distance = ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy))
	if distance < 250 and not retreat and tactics.committed(ctx, enemy)
		and tactics.cast(ctx, api, "primal_beast_pulverize", "target", enemy) then return true end
	local uproar = NPC.GetModifier(ctx.hero, "modifier_primal_beast_uproar")
	if uproar and Modifier.GetStackCount(uproar) >= 3 and distance < 850
		and tactics.cast(ctx, api, "primal_beast_uproar", "none") then return true end
	if distance < 350 and not retreat and tactics.committed(ctx, enemy)
		and tactics.cast(ctx, api, "primal_beast_trample", "none") then return true end
	local rush = NPC.GetAbility(ctx.hero, "primal_beast_onslaught")
	if not rush or distance < 550 or not retreat and not tactics.committed(ctx, enemy) then return false end
	local point = retreat and ctx.toward(ctx.position, ctx.home, 1200) or tactics.point(ctx, rush, enemy, 1200, 1)
	if ctx.unsafePosition(point) or not GridNav.IsTraversable(point) then return false end
	if not retreat and not tactics.safe(ctx, point, 2) then return false end
	local charge = common.value(rush, "max_charge_time", 1.7)
	local required = math.min(charge, ctx.distance(ctx.position, point) / common.value(rush, "max_distance", 2000) * charge + 0.15)
	local used, cast = tactics.cast(ctx, api, "primal_beast_onslaught", "point", nil, point, common.value(rush, "max_distance", 2000))
	if cast then ctx.heroState.onslaught = {target = not retreat and enemy or nil, point = point,
		releaseAt = ctx.now + Ability.GetCastPoint(rush) + required, expires = ctx.now + charge + 1} end
	return used
end

return primal
