local domination = {}
local kv = XHelpers.xkv:GetKV("items").DOTAAbilities

local function live(unit)
	return unit and Entity.IsEntity(unit) and Entity.IsAlive(unit) and not Entity.IsDormant(unit) and NPC.IsVisible(unit)
end

local function strength(unit)
	local value = NPC.GetTrueDamage(unit) + Entity.GetMaxHealth(unit) * 0.035 + (NPC.IsAncient(unit) and 150 or 0)
	for index = 0, 7 do
		local ability = NPC.GetAbilityByIndex(unit, index)
		if ability and Ability.GetLevel(ability) > 0 and not Ability.IsHidden(ability) then value = value + (Ability.IsPassive(ability) and 18 or 45) end
	end
	return value
end

function domination.run(ctx, api)
	if ctx.retreating or ctx.intent or ctx.nearEnemies > 0 or ctx.parent or NPC.IsIllusion(ctx.hero)
		or ctx.farmCandidate and ctx.farmCandidate.start < ctx.now + 0.7 then return false end
	local item, name
	for _, candidate in ipairs({"item_helm_of_the_overlord", "item_helm_of_the_dominator"}) do
		local found = NPC.GetItem(ctx.hero, candidate, true)
		if found and api.ready(ctx, found, true) and (ctx.abilityAttempts[candidate] or 0) <= ctx.now then item, name = found, candidate; break end
	end
	if not item then return false end
	local state = ctx.heroState.domination or {}
	ctx.heroState.domination = state
	if ctx.now < (state.nextAttempt or 0) then return false end
	local current, count, weakest = nil, 0, math.huge
	for _, unit in ipairs(ctx.summons) do
		if live(unit) and (unit == state.target or NPC.HasModifier(unit, "modifier_dominated")) then
			count = count + 1
			local score = strength(unit)
			if score < weakest then current, weakest = unit, score end
		end
	end
	local limit = tonumber(kv[name] and kv[name].AbilityValues and kv[name].AbilityValues.count_limit) or 1
	local range = Ability.GetCastRange(item)
	local best, score
	for _, unit in ipairs(ctx.worldNPCs) do
		if live(unit) and not Entity.IsSameTeam(ctx.hero, unit) and NPC.IsNeutral(unit) and NPC.IsCreep(unit)
			and not NPC.IsRoshan(unit) and not NPC.IsTormentor(unit) and not NPC.IsWaitingToSpawn(unit)
			and (name == "item_helm_of_the_overlord" or not NPC.IsAncient(unit)) and api.allowed(ctx, item, unit) then
			local distance = ctx.distance(ctx.position, Entity.GetAbsOrigin(unit))
			local power = strength(unit)
			if distance < range + 600 and not ctx.unsafePosition(Entity.GetAbsOrigin(unit))
				and (count < limit or current and power > weakest * 1.3 + 30) then
				local value = power - math.max(0, distance - range) * 0.12
				if not score or value > score then best, score = unit, value end
			end
		end
	end
	if not best then return false end
	local position = Entity.GetAbsOrigin(best)
	if ctx.distance(ctx.position, position) > range then
		if count > 0 then return false end
		return ctx.move(ctx.toward(position, ctx.position, math.max(80, range - 50)), "Approach useful creep for Dominate")
	end
	if api.cast(ctx, item, "target", best) then
		state.target, state.nextAttempt = best, ctx.now + 2
		return true
	end
	return false
end

return domination
