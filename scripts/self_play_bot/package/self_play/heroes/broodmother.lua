local brood = {reserved = {broodmother_spawn_spiderlings = true, broodmother_spin_web = true,
	broodmother_insatiable_hunger = true, broodmother_sticky_snare = true, broodmother_spin_web_destroy = true}}
local common = require("self_play.heroes.common")
local tactics = require("self_play.heroes.tactics")
local awareness = require("self_play.awareness")

function brood.update(ctx, api, retreat)
	local enemy = tactics.enemy(ctx, 900)
	local target = enemy and tactics.committed(ctx, enemy) and enemy or tactics.farmTarget(ctx, 900)
	if retreat then target = nil end
	local web = NPC.GetAbility(ctx.hero, "broodmother_spin_web")
	if web and not NPC.HasModifier(ctx.hero, "modifier_broodmother_spin_web") and (target or retreat)
		and ctx.now > (ctx.heroState.nextWeb or 0) then
		local covered = false
		for _, unit in ipairs(ctx.worldNPCs) do
			if Entity.IsEntity(unit) and Entity.IsSameTeam(ctx.hero, unit) and NPC.GetUnitName(unit) == "npc_dota_broodmother_web"
				and ctx.distance(ctx.position, Entity.GetAbsOrigin(unit)) < common.value(web, "radius", 1200) - 150 then covered = true; break end
		end
		if not covered then
			local point = ctx.toward(ctx.position, retreat and ctx.home or Entity.GetAbsOrigin(target), 350)
			local used, cast = tactics.cast(ctx, api, "broodmother_spin_web", "point", nil, point)
			if cast then ctx.heroState.nextWeb = ctx.now + 8 end
			if used then return true end
		end
	end
	if not target then return false end
	if NPC.IsAttacking(ctx.hero) and (NPC.IsHero(target) or ctx.health < 0.8)
		and tactics.cast(ctx, api, "broodmother_insatiable_hunger", "none") then return true end
	local spawn = NPC.GetAbility(ctx.hero, "broodmother_spawn_spiderlings")
	if spawn and (NPC.IsHero(target) or Entity.GetHealth(target) <= common.value(spawn, "damage", 220) * NPC.GetMagicalArmorDamageMultiplier(target) + NPC.GetTrueDamage(ctx.hero)) then
		return tactics.cast(ctx, api, "broodmother_spawn_spiderlings", "target", target)
	end
	return false
end

function brood.unit(ctx, api, unit)
	if not NPC.GetUnitName(unit):find("^npc_dota_broodmother_spider") then return false end
	local actor = common.actor(ctx, unit)
	if awareness.damage(actor, actor.position, 1.5) > Entity.GetHealth(unit) * 0.6 then
		return actor.move(ctx.toward(actor.position, ctx.home, 600))
	end
	local target = ctx.intent and ctx.intent.target or ctx.attackTarget
	if common.visible(target) and not Entity.IsSameTeam(unit, target) and ctx.distance(actor.position, Entity.GetAbsOrigin(target)) < 1600
		and not ctx.unsafePosition(Entity.GetAbsOrigin(target)) then return common.unitAttack(ctx, unit, target) end
	return false
end

function brood.farm(ctx, api)
	return brood.update(ctx, api, false)
end

return brood
