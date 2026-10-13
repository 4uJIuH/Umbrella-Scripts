local safety = {}
local awareness = require("self_play.awareness")

local function live(unit)
	return unit and Entity.IsEntity(unit) and Entity.IsAlive(unit) and not Entity.IsDormant(unit) and NPC.IsVisible(unit)
end

function safety.attackers(ctx, structure)
	local count = 0
	for _, hero in ipairs(ctx.allies) do
		if hero ~= ctx.hero and live(hero) and Entity.IsSameTeam(ctx.hero, hero) and not NPC.IsIllusion(hero)
			and Hero.GetReplicatingOtherHeroModel(hero) == nil and Entity.GetHealth(hero) > Entity.GetMaxHealth(hero) * 0.4
			and ctx.distance(Entity.GetAbsOrigin(hero), Entity.GetAbsOrigin(structure)) < NPC.GetAttackRange(hero) + NPC.GetHullRadius(structure) + 200
			and NPC.IsAttacking(hero) and NPC.FindFacingNPC(hero, nil, Enum.TeamType.TEAM_ENEMY, 30,
				NPC.GetAttackRange(hero) + NPC.GetHullRadius(structure) + 200) == structure then count = count + 1 end
	end
	return count
end

function safety.siege(ctx, structure)
	local count = 0
	for _, wave in ipairs(ctx.waves) do
		for _, creep in ipairs(wave) do
			if live(creep) and not NPC.IsRanged(creep) and NPC.IsAttacking(creep)
				and NPC.FindFacingNPC(creep, nil, Enum.TeamType.TEAM_ENEMY, 30,
					NPC.GetAttackRange(creep) + NPC.GetHullRadius(structure) + 200) == structure then count = count + 1 end
		end
	end
	return count
end

function safety.cover(ctx, tower)
	local tank = Tower.GetAttackTarget(tower)
	local position, range = Entity.GetAbsOrigin(tower), NPC.GetAttackRange(tower)
	local damage = math.max(1, NPC.GetTrueDamage(tower))
	local function shots(unit)
		return Entity.GetHealth(unit) / math.max(1, damage * NPC.GetArmorDamageMultiplier(unit))
	end
	if live(tank) and tank ~= ctx.hero and Entity.IsSameTeam(ctx.hero, tank) then
		if NPC.IsHero(tank) and not NPC.IsIllusion(tank) then
			return Entity.GetHealth(tank) >= Entity.GetMaxHealth(tank) * 0.5 and shots(tank) >= (NPC.GetAttackRange(ctx.hero) >= 500 and 4 or 6)
		end
	else
		tank = nil
	end
	local frontline, budget, successors, seen = 0, 0, 0, {}
	local heroDistance = ctx.distance(ctx.position, position)
	local attackRange = NPC.GetAttackRange(ctx.hero) + NPC.GetAttackRangeBonus(ctx.hero)
	local attackingDistance = math.min(heroDistance, attackRange + NPC.GetHullRadius(tower))
	for _, wave in ipairs(ctx.waves) do
		for _, creep in ipairs(wave) do
			if live(creep) and Entity.IsSameTeam(ctx.hero, creep) and not seen[creep]
				and ctx.distance(Entity.GetAbsOrigin(creep), position) < range - 50 then
				seen[creep] = true
				local remaining = shots(creep)
				if not NPC.IsRanged(creep) and remaining >= 2.5 then
					frontline, budget = frontline + 1, budget + remaining
					if creep ~= tank and ctx.distance(Entity.GetAbsOrigin(creep), position) < attackingDistance + 40 then
						successors = successors + 1
					end
				end
			end
		end
	end
	local tankShots = tank and shots(tank) or 0
	if tank then
		if tankShots < 2.5 and successors == 0 then return false end
	elseif frontline == 0 then return false end
	local approach = math.max(0, ctx.distance(ctx.position, position) - attackRange - NPC.GetHullRadius(tower))
	local escape = math.max(0, range + 150 - attackRange)
	local seconds = (approach + escape) / math.max(100, NPC.GetMoveSpeed(ctx.hero)) + NPC.GetSecondsPerAttack(ctx.hero, false) + 1
	local required = seconds / math.max(0.3, NPC.GetSecondsPerAttack(tower, false)) + 2
	local covered = frontline >= 2 or attackRange >= 500 and frontline >= 1
		and (tankShots >= required or successors > 0)
	return covered and budget >= required
end

function safety.position(ctx, tower, position)
	local reach = NPC.GetAttackRange(tower) + NPC.GetAttackRangeBonus(tower) + NPC.GetHullRadius(ctx.hero) + 60
	if ctx.distance(position, Entity.GetAbsOrigin(tower)) >= reach then
		return awareness.damage(ctx, position, 2.5) + awareness.forecast(ctx, position) < Entity.GetHealth(ctx.hero) * 0.15
	end
	if not safety.cover(ctx, tower) or Entity.GetHealth(ctx.hero) < Entity.GetMaxHealth(ctx.hero) * 0.55 then return false end
	local origin = Entity.GetAbsOrigin(tower)
	local hostile, friendly, defenders = 0, 0, 0
	for _, enemy in ipairs(ctx.enemies) do
		if live(enemy) and ctx.distance(Entity.GetAbsOrigin(enemy), origin) < 1200 then
			defenders = defenders + 1
			hostile = hostile + NPC.GetTrueDamage(enemy) / math.max(0.3, NPC.GetSecondsPerAttack(enemy, false))
		end
	end
	if defenders == 0 then return true end
	if safety.attackers(ctx, tower) + safety.siege(ctx, tower) < 2 or ctx.health < 0.75 then return false end
	for _, ally in ipairs(ctx.allies) do
		if live(ally) and not NPC.IsIllusion(ally) and ctx.distance(Entity.GetAbsOrigin(ally), origin) < 1200
			and Entity.GetHealth(ally) > Entity.GetMaxHealth(ally) * 0.55 then
			friendly = friendly + NPC.GetTrueDamage(ally) / math.max(0.3, NPC.GetSecondsPerAttack(ally, false))
		end
	end
	return friendly > hostile * 1.6 and ctx.nearAllies >= defenders + 2
		and awareness.damage(ctx, position, 2.5) + awareness.forecast(ctx, position) < Entity.GetHealth(ctx.hero) * 0.22
end

return safety
