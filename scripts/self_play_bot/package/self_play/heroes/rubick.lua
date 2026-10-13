local rubick = {reserved = {rubick_spell_steal = true, rubick_telekinesis_land = true, rubick_telekinesis_land_self = true}}
local common = require("self_play.heroes.common")

local function value(ctx, ability)
	local effect = ctx.catalog.abilities[Ability.GetName(ability)] or {}
	local name = Ability.GetName(ability)
	if Ability.IsPassive(ability) or effect.unsafe or name:find("^ability_") or name:find("^special_bonus_")
		or name:find("^twin_gate_") or name == "abyssal_underlord_portal_warp" then return -100 end
	return (Ability.IsUltimate(ability) and 35 or 0) + (effect.disable and 30 or 0)
		+ (effect.heal and 15 or 0) + math.min(25, math.max(Ability.GetDamage(ability), ctx.planner.levelValue(effect.damage, Ability.GetLevel(ability))) / 15)
end

function rubick.update(ctx, api, retreat)
	local land = common.ability(ctx, api, "rubick_telekinesis_land")
	if land then
		for _, enemy in ipairs(ctx.enemies) do
			if common.visible(enemy) and NPC.HasModifier(enemy, "modifier_rubick_telekinesis") then
				local lift = NPC.GetAbility(ctx.hero, "rubick_telekinesis")
				local distance = lift and common.value(lift, "max_land_distance", 375) or 375
				local position = ctx.toward(Entity.GetAbsOrigin(enemy), retreat and ctx.enemyHome or ctx.position, distance)
				if GridNav.IsTraversable(position) then return api.cast(ctx, land, "point", nil, position) end
			end
		end
	end
	if retreat then return false end
	local steal = common.ability(ctx, api, "rubick_spell_steal")
	if not steal or ctx.now < (ctx.heroState.nextStealScan or 0) then return false end
	ctx.heroState.nextStealScan = ctx.now + 0.3
	local heldValue = -1
	for index = 0, 31 do
		local ability = NPC.GetAbilityByIndex(ctx.hero, index)
		if ability then
			local name = Ability.GetName(ability)
			if not name:find("^rubick_") and not name:find("^special_bonus_") and not name:find("^ability_")
				and Ability.GetLevel(ability) > 0 and not Ability.IsHidden(ability) then heldValue = math.max(heldValue, value(ctx, ability)) end
		end
	end
	local best, bestScore
	for _, enemy in ipairs(ctx.enemies) do
		if common.visible(enemy) and ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy)) <= Ability.GetCastRange(steal) then
			local latest, age = nil, 8
			for index = 0, 31 do
				local ability = NPC.GetAbilityByIndex(enemy, index)
				if ability and not Ability.IsPassive(ability) and Ability.GetLevel(ability) > 0 then
					local since = Ability.SecondsSinceLastUse(ability)
					if since >= 0 and since < age then latest, age = ability, since end
				end
			end
			if latest then
				local score = value(ctx, latest)
				if score > heldValue + 5 and (not bestScore or score > bestScore) and api.allowed(ctx, steal, enemy) then best, bestScore = enemy, score end
			end
		end
	end
	return best and common.cast(ctx, api, steal, "target", best) or false
end

return rubick
