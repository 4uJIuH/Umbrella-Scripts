local support = {}

local function live(unit)
	return unit and Entity.IsEntity(unit) and Entity.IsNPC(unit) and Entity.IsAlive(unit)
		and not Entity.IsDormant(unit) and NPC.IsVisible(unit)
end

local function attacking(unit, target)
	return NPC.IsAttacking(unit) and NPC.FindFacingNPC(unit, nil, Enum.TeamType.TEAM_ENEMY, 30,
		NPC.GetAttackRange(unit) + NPC.GetAttackRangeBonus(unit) + 150) == target
end

function support.pressured(ctx, ally)
	if not live(ally) or ally == ctx.hero or not Entity.IsSameTeam(ctx.hero, ally) then return false end
	local position = Entity.GetAbsOrigin(ally)
	for _, enemy in ipairs(ctx.enemies) do
		if live(enemy) and not NPC.IsIllusion(enemy) and ctx.distance(position, Entity.GetAbsOrigin(enemy)) < 1300 then
			local hit = ctx.allyFights and ctx.allyFights[Entity.GetIndex(enemy)]
			if attacking(enemy, ally) or hit and hit.ally == ally and hit.outgoing == false and ctx.now - hit.time < 2.5 then return true end
		end
	end
	for _, projectile in pairs(ctx.projectiles) do
		if projectile.target == ally and projectile.damage > 0 and projectile.impact >= ctx.now and projectile.impact < ctx.now + 2 then return true end
	end
	return false
end

function support.follow(ctx, ally)
	if not live(ally) or ally == ctx.hero or NPC.IsIllusion(ally) or not Entity.IsSameTeam(ctx.hero, ally) then return false end
	if support.pressured(ctx, ally) then return true end
	if not NPC.IsAttacking(ally) then return false end
	local target = NPC.FindFacingNPC(ally, nil, Enum.TeamType.TEAM_ENEMY, 30, NPC.GetAttackRange(ally) + NPC.GetAttackRangeBonus(ally) + 150)
	return live(target) and not Entity.IsSameTeam(ally, target) and (NPC.IsHero(target) or NPC.IsStructure(target))
end

function support.midTeleport(ctx, destination)
	if ctx.role < 4 or ctx.baseDefense or ctx.distance(destination, ctx.home) < 2000 then return true end
	local mid = math.abs(destination.x - destination.y) < 1700
	if not mid then return true end
	for _, ally in ipairs(ctx.allies) do
		if live(ally) and ally ~= ctx.hero and not NPC.IsIllusion(ally)
			and ctx.distance(destination, Entity.GetAbsOrigin(ally)) < 1700 then
			if support.pressured(ctx, ally) then return true end
			for _, tower in ipairs(ctx.towers) do
				if live(tower) and Entity.IsSameTeam(ctx.hero, tower) and NPC.GetUnitName(tower):find('_mid', 1, true)
					and ctx.distance(Entity.GetAbsOrigin(ally), Entity.GetAbsOrigin(tower)) < 1300 then
					for _, enemy in ipairs(ctx.enemies) do
						if live(enemy) and not NPC.IsIllusion(enemy) and attacking(enemy, tower) then return true end
					end
				end
			end
		end
	end
	return false
end

return support
