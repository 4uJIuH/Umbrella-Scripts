local wyvern = {reserved = {winter_wyvern_splinter_blast = true, winter_wyvern_cold_embrace = true,
	winter_wyvern_winters_curse = true, winter_wyvern_arctic_burn = true}}
local common = require("self_play.heroes.common")
local tactics = require("self_play.heroes.tactics")
local awareness = require("self_play.awareness")

function wyvern.emergency(ctx, api)
	local embrace = NPC.GetAbility(ctx.hero, "winter_wyvern_cold_embrace")
	local ally = embrace and tactics.injured(ctx, Ability.GetCastRange(embrace), 0.5, true)
	if ally and not NPC.IsChannellingAbility(ally) then
		local physical, magic = 0, 0
		for _, enemy in ipairs(ctx.enemies) do
			if common.visible(enemy) then
				local distance = ctx.distance(Entity.GetAbsOrigin(ally), Entity.GetAbsOrigin(enemy))
				if distance < NPC.GetAttackRange(enemy) + 200 and NPC.IsAttacking(enemy) then physical = physical + NPC.GetTrueDamage(enemy) end
				magic = magic + awareness.burst(ctx, enemy, ally, distance, 3)
			end
		end
		if physical > 0 and magic < Entity.GetHealth(ally) * 0.45
			and tactics.cast(ctx, api, "winter_wyvern_cold_embrace", "target", ally) then return true end
	end
	return false
end

function wyvern.update(ctx, api, retreat)
	if wyvern.emergency(ctx, api) then return true end
	local enemy = tactics.enemy(ctx, 1500)
	local burn = NPC.GetAbility(ctx.hero, "winter_wyvern_arctic_burn")
	local toggle = burn and ctx.planner.hasFlag(Ability.GetBehavior(burn), Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_TOGGLE)
	if toggle and Ability.GetToggleState(burn) and (not enemy or NPC.GetMana(ctx.hero) < 100) then
		return tactics.cast(ctx, api, "winter_wyvern_arctic_burn", "toggle")
	end
	if not enemy then return false end
	local curse = NPC.GetAbility(ctx.hero, "winter_wyvern_winters_curse")
	if curse and (tactics.committed(ctx, enemy) or retreat) then
		local best, score
		for _, target in ipairs(ctx.enemies) do
			if common.visible(target) and not NPC.IsStunned(target) and ctx.distance(ctx.position, Entity.GetAbsOrigin(target)) <= Ability.GetCastRange(curse) then
				local hits, allies = 0, 0
				for _, other in ipairs(ctx.enemies) do
					if other ~= target and common.visible(other) and ctx.distance(Entity.GetAbsOrigin(target), Entity.GetAbsOrigin(other)) < common.value(curse, "radius", 525) then hits = hits + NPC.GetTrueDamage(other) end
				end
				for _, friend in ipairs(ctx.allies) do
					if friend ~= ctx.hero and common.visible(friend) and NPC.IsAttacking(friend) and ctx.distance(Entity.GetAbsOrigin(friend), Entity.GetAbsOrigin(target)) < 600 then allies = allies + 1 end
				end
				local value = hits - allies * 120
				if hits > 0 and (retreat or value > 0) and (not score or value > score) then best, score = target, value end
			end
		end
		if best and tactics.cast(ctx, api, "winter_wyvern_winters_curse", "target", best) then return true end
	end
	if not tactics.committed(ctx, enemy) and not retreat then return false end
	local blast = NPC.GetAbility(ctx.hero, "winter_wyvern_splinter_blast")
	if blast then
		for _, unit in ipairs(ctx.worldNPCs) do
			if unit ~= enemy and common.visible(unit) and not Entity.IsSameTeam(ctx.hero, unit) and (NPC.IsHero(unit) or NPC.IsCreep(unit))
				and ctx.distance(Entity.GetAbsOrigin(unit), ctx.predict(enemy, 0.6)) < common.value(blast, "split_radius", 500) - 50 then
				if tactics.cast(ctx, api, "winter_wyvern_splinter_blast", "target", unit) then return true end
			end
		end
	end
	if burn and ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy)) < NPC.GetAttackRange(ctx.hero) + common.value(burn, "attack_range_bonus", 250)
		and not NPC.HasModifier(ctx.hero, "modifier_winter_wyvern_arctic_burn_flight") then
		return tactics.cast(ctx, api, "winter_wyvern_arctic_burn", toggle and "toggle" or "none")
	end
	return false
end

return wyvern
