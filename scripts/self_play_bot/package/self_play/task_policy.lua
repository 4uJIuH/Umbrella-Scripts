local policy = {}

local function active(ctx, task)
	return task and (not task.expires or task.expires > ctx.now)
end

function policy.farmBlocked(ctx)
	if ctx.baseDefense or ctx.fightSession or ctx.helpRotation or active(ctx, ctx.intent) then return true end
	local task = ctx.teamTask
	if active(ctx, task) and (task.fighting or task.kind == "push" or task.kind == "roshan"
		or task.kind == "defend" or task.rotation or task.kind == "group" and task.objective and task.key) then return true end
	return active(ctx, ctx.runeTask) or active(ctx, ctx.riverTask) or active(ctx, ctx.campTask) or active(ctx, ctx.objectiveTask) or false
end

function policy.progress(ctx, task, goal)
	local advanced = not task.progressPosition
		or ctx.distance(task.progressPosition, goal) - ctx.distance(ctx.position, goal) >= 80
	if advanced then
		task.progressAt, task.progressPosition = ctx.now, ctx.position
	end
	return advanced
end

return policy
