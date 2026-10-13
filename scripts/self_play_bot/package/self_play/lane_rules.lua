local rules = {}

function rules.canLastHit(ctx, creep)
	if ctx.role <= 3 then return true end
	if not ctx.runeRoles or ctx.now >= (ctx.nextRuneRoles or 0) then
		local entries = {}
		for _, ally in ipairs(ctx.allies) do
			if Entity.IsEntity(ally) and not NPC.IsIllusion(ally) and not NPC.IsMeepoClone(ally)
				and Hero.GetReplicatingOtherHeroModel(ally) == nil then
				entries[#entries + 1] = {id = Entity.GetIndex(ally), scores = ctx.planner.roleScores(ctx.catalog.heroes[NPC.GetUnitName(ally)])}
			end
		end
		ctx.runeRoles, ctx.nextRuneRoles = ctx.planner.assignRoles(entries), ctx.now + 5
	end
	local position = Entity.GetAbsOrigin(creep)
	for _, ally in ipairs(ctx.allies) do
		local role = ctx.runeRoles[Entity.GetIndex(ally)]
		if ally ~= ctx.hero and role and role <= 3 and Entity.IsAlive(ally) and not Entity.IsDormant(ally)
			and Entity.IsSameTeam(ctx.hero, ally) and not NPC.IsIllusion(ally) and not NPC.IsMeepoClone(ally)
			and Hero.GetReplicatingOtherHeroModel(ally) == nil and ctx.distance(Entity.GetAbsOrigin(ally), position) < 1200 then return false end
	end
	return true
end

function rules.denyable(clock, health, maximum, threshold)
	if clock >= 1200 or health <= 0 or maximum <= 0 then return false end
	if threshold <= 0 then threshold = 50 end
	if threshold <= 1 then threshold = threshold * 100 end
	return health < maximum * math.min(50, threshold) / 100
end

function rules.keepFarm(health, meleePressure, rangedPressure, hasCandidate)
	return health >= 0.55 and hasCandidate and meleePressure <= 1
		or health >= 0.65 and meleePressure == 0 and rangedPressure > 0
end

return rules
