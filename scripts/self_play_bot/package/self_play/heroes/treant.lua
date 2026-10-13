local treant = {reserved = {
	treant_natures_grasp = true, treant_leech_seed = true, treant_living_armor = true,
	treant_overgrowth = true, treant_super_bloom = true,
}}
local common = require("self_play.heroes.common")
local tactics = require("self_play.heroes.tactics")
local intent = require("self_play.intent")

local function armor(ctx, api, urgentOnly)
	local ability = NPC.GetAbility(ctx.hero, "treant_living_armor")
	if not ability or not api.ready(ctx, ability, false) then return false end
	local healing = common.value(ability, "heal_per_second", 4) * common.value(ability, "duration", 12)
	local best, score
	local function consider(unit, building)
		if not common.visible(unit) or not Entity.IsSameTeam(ctx.hero, unit) or NPC.IsIllusion(unit)
			or NPC.HasModifier(unit, "modifier_treant_living_armor") then return end
		local health, maximum = Entity.GetHealth(unit), Entity.GetMaxHealth(unit)
		local missing = maximum - health
		local pressured = not building and Hero.GetRecentDamage(unit) > 0
		for _, enemy in ipairs(ctx.enemies) do
			if common.visible(enemy) and NPC.IsAttacking(enemy) and NPC.FindFacingNPC(enemy, nil, Enum.TeamType.TEAM_ENEMY,
				30, NPC.GetAttackRange(enemy) + 150) == unit then pressured = true; break end
		end
		local urgent = pressured and health < maximum * 0.85
		if urgentOnly and not urgent then return end
		if not urgent and (missing < math.max(60, healing * 0.75) or health > maximum * 0.9) then return end
		local value = math.min(missing, healing) + (1 - health / maximum) * 180 + (pressured and 150 or 0) + (building and 0 or 100)
		if not score or value > score then best, score = unit, value end
	end
	consider(ctx.hero, false)
	for _, ally in ipairs(ctx.allies) do if ally ~= ctx.hero then consider(ally, false) end end
	if not urgentOnly then for _, structure in ipairs(ctx.structures) do consider(structure, true) end end
	return best and tactics.cast(ctx, api, "treant_living_armor", "target", best, nil, math.huge) or false
end

local function root(ctx, api, retreat)
	local ability = NPC.GetAbility(ctx.hero, "treant_overgrowth")
	if not ability or not api.ready(ctx, ability, false) then return false end
	local radius = common.value(ability, "radius", 800)
	local targets, interrupt, involved = 0, false, false
	for _, enemy in ipairs(ctx.enemies) do
		if common.visible(enemy) and not NPC.IsIllusion(enemy)
			and not NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE)
			and not NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_OUT_OF_GAME)
			and ctx.distance(ctx.position, ctx.predict(enemy, Ability.GetCastPoint(ability) + 0.1)) < radius - 40 then
			if NPC.IsChannellingAbility(enemy) then interrupt = true end
			if not NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_ROOTED) and not NPC.IsStunned(enemy) then
				targets = targets + 1
				involved = involved or tactics.committed(ctx, enemy)
			end
		end
	end
	if interrupt or targets >= 2 and involved or targets >= 1 and retreat and (ctx.health < 0.55 or ctx.hardRetreat) then
		return tactics.cast(ctx, api, "treant_overgrowth", "none")
	end
	return false
end

function treant.emergency(ctx, api)
	return root(ctx, api, ctx.retreating or ctx.hardRetreat) or armor(ctx, api, true)
end

function treant.update(ctx, api, retreat)
	if root(ctx, api, retreat) or armor(ctx, api, false) then return true end
	local enemy = tactics.enemy(ctx, 1500)
	if not enemy or not (tactics.committed(ctx, enemy) or retreat and ctx.laneThreat and ctx.laneThreat.attacked) then return false end
	if not retreat and ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy)) < 400
		and not NPC.HasModifier(ctx.hero, "modifier_treant_super_bloom")
		and tactics.cast(ctx, api, "treant_super_bloom", "none") then return true end
	if not retreat then
		local used, cast = tactics.cast(ctx, api, "treant_leech_seed", "target", enemy)
		if used then
			if cast then intent.follow(ctx, enemy) end
			return true
		end
	end
	local grasp = NPC.GetAbility(ctx.hero, "treant_natures_grasp")
	if grasp and not NPC.HasModifier(enemy, "modifier_treant_natures_grasp_damage") then
		local distance = ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy))
		local delay = common.value(grasp, "initial_latch_delay", 0.3)
			+ distance / math.max(1, common.value(grasp, "vine_spawn_interval", 175)) * common.value(grasp, "creation_interval", 0.1)
		local point = tactics.point(ctx, grasp, enemy, nil, math.min(1, delay))
		return tactics.cast(ctx, api, "treant_natures_grasp", "point", nil, point)
	end
	return false
end

return treant
