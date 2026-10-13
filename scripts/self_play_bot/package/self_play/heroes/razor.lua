local razor = {reserved = {razor_static_link = true, razor_eye_of_the_storm = true, razor_plasma_field = true}}
local common = require("self_play.heroes.common")
local tactics = require("self_play.heroes.tactics")

function razor.locked(ctx)
	local task = ctx.heroState.link
	return task and ctx.now < task.expires or false
end

function razor.update(ctx, api, retreat)
	local task = ctx.heroState.link
	if task then
		local live = common.visible(task.target)
		local linked = NPC.HasModifier(ctx.hero, "modifier_razor_static_link")
		if retreat or ctx.hardRetreat or not live or ctx.now > task.expires
			or ctx.now > task.started + 1 and not linked
			or live and not tactics.safe(ctx, Entity.GetAbsOrigin(task.target), 1.5) then
			ctx.heroState.link = nil; task = nil
		end
	end
	local enemy = task and task.target or tactics.enemy(ctx, 900)
	if not enemy then return false end
	local distance = ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy))
	if not retreat and tactics.committed(ctx, enemy) then
		if not task then
			local used, cast = tactics.cast(ctx, api, "razor_static_link", "target", enemy)
			if cast then
				local link = NPC.GetAbility(ctx.hero, "razor_static_link")
				ctx.heroState.link = {target = enemy, started = ctx.now, expires = ctx.now + common.value(link, "drain_length", 10)}
			end
			if used then return true end
		end
		if distance < 500 and tactics.cast(ctx, api, "razor_eye_of_the_storm", "none") then return true end
	end
	if distance < 650 and (task or retreat or tactics.committed(ctx, enemy)) and tactics.cast(ctx, api, "razor_plasma_field", "none") then return true end
	if task then
		ctx.target = task.target
		local point = ctx.predict(task.target, 0.25)
		local goal = ctx.toward(point, ctx.position, math.max(120, NPC.GetAttackRange(ctx.hero) - 40))
		if not tactics.safe(ctx, goal, 1.5) then ctx.heroState.link = nil; return false end
		if distance > NPC.GetAttackRange(ctx.hero) - 30 then return ctx.move(goal, "Razor: maintain safe Static Link", 30) end
		return ctx.attack(task.target, "Razor: attack linked enemy")
	end
	return false
end

return razor
