local meepo = {reserved = {meepo_earthbind = true, meepo_poof = true, meepo_megameepo = true,
	meepo_megameepo_fling = true, meepo_petrify = true, meepo_fling = true, meepo_fling_release = true}}
local common = require("self_play.heroes.common")
local navigation = require("self_play.navigation")
local awareness = require("self_play.awareness")

local function family(ctx)
	local result = {ctx.hero}
	for _, unit in ipairs(ctx.summons) do
		if common.visible(unit) and not NPC.IsIllusion(unit) and NPC.GetUnitName(unit) == "npc_dota_hero_meepo" then result[#result + 1] = unit end
	end
	return result
end

local function control(root, ctx, api)
	if api.busy(ctx) or ctx.parent and ctx.health >= 0.4 and ctx.now < (root.heroState.unitBusy[Entity.GetIndex(ctx.hero)] or 0) then return true end
	local members = family(root)
	local team = root.heroState.meepoTeam or {}
	root.heroState.meepoTeam = team
	local desired = root.intent and root.intent.kind == "hero" and root.intent.target or root.target
	if common.visible(desired) and NPC.IsHero(desired) and not Entity.IsSameTeam(root.hero, desired) then
		team.target, team.expires = desired, root.now + 2.5
	elseif not common.visible(team.target) or root.now > (team.expires or 0) then team.target = nil end
	local enemy = team.target
	if enemy and ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy)) > 1600 then enemy = nil end
	ctx.target = enemy or false
	local weakest, safest, health, homeDistance = nil, nil, 1, math.huge
	for _, unit in ipairs(members) do
		if common.visible(unit) then
			local ratio = Entity.GetHealth(unit) / math.max(1, Entity.GetMaxHealth(unit))
			if ratio < health then weakest, health = unit, ratio end
			local distance = ctx.distance(Entity.GetAbsOrigin(unit), ctx.home)
			if ratio > 0.55 and not ctx.unsafePosition(Entity.GetAbsOrigin(unit)) and awareness.damage(ctx, Entity.GetAbsOrigin(unit), 2) < Entity.GetHealth(unit) * 0.2
				and distance < homeDistance then safest, homeDistance = unit, distance end
		end
	end
	local dig = common.ability(ctx, api, "meepo_petrify")
	if dig and ctx.health < 0.35 then return api.cast(ctx, dig, "none") end
	local poof = common.ability(ctx, api, "meepo_poof")
	local incoming = awareness.damage(ctx, ctx.position, 2)
	if ctx.health < 0.4 or incoming > Entity.GetHealth(ctx.hero) * 0.6 or root.retreating then
		if ctx.parent then root.heroState.unitBusy[Entity.GetIndex(ctx.hero)] = ctx.now end
		if poof and safest and safest ~= ctx.hero and homeDistance + 800 < ctx.distance(ctx.position, ctx.home) then
			return api.cast(ctx, poof, "target", safest)
		end
		local mega = ctx.hero == root.hero and common.ability(ctx, api, "meepo_megameepo")
		if mega and weakest and ctx.distance(ctx.position, Entity.GetAbsOrigin(weakest)) < 550 then return api.cast(ctx, mega, "none") end
		return ctx.move(navigation.coverAnchor(ctx), "Meepo: protect endangered clone")
	end
	local mega = ctx.hero == root.hero and health < 0.3 and common.ability(ctx, api, "meepo_megameepo")
	if mega and weakest and ctx.distance(ctx.position, Entity.GetAbsOrigin(weakest)) < 550 then return api.cast(ctx, mega, "none") end
	if common.items(ctx, api, enemy, false) then return true end
	if not enemy then
		local target = common.visible(root.attackTarget) and root.attackTarget or ctx.parent and common.unitTarget(ctx, ctx.hero)
		if poof and target and not NPC.IsHero(target) and not Entity.IsSameTeam(ctx.hero, target) then
			local count = 0
			local radius = common.value(poof, "radius", 400)
			for _, creep in ipairs(root.worldNPCs) do
				if common.visible(creep) and NPC.IsCreep(creep) and not Entity.IsSameTeam(ctx.hero, creep)
					and ctx.distance(ctx.position, Entity.GetAbsOrigin(creep)) < radius - 50 then count = count + 1 end
			end
			local net = NPC.GetAbility(ctx.hero, "meepo_earthbind")
			if count >= 3 and ctx.health > 0.6 and NPC.GetMana(ctx.hero) - Ability.GetManaCost(poof) >= (net and Ability.GetManaCost(net) or 75)
				and incoming < Entity.GetHealth(ctx.hero) * 0.15 then return api.cast(ctx, poof, "target", ctx.hero) end
		end
		return false
	end
	local net = common.ability(ctx, api, "meepo_earthbind")
	local id = Entity.GetIndex(enemy)
	root.heroState.netUntil = root.heroState.netUntil or {}
	local durations = NPC.GetStatesDuration(enemy, {[Enum.ModifierState.MODIFIER_STATE_ROOTED] = true, [Enum.ModifierState.MODIFIER_STATE_STUNNED] = true}, true)
	local controlled = math.max(durations[Enum.ModifierState.MODIFIER_STATE_ROOTED] or 0, durations[Enum.ModifierState.MODIFIER_STATE_STUNNED] or 0)
	if net and ctx.now >= (root.heroState.netUntil[id] or 0) then
		local delay = Ability.GetCastPoint(net) + ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy)) / common.value(net, "speed", 1200)
		local point = ctx.predict(enemy, delay)
		if controlled <= delay + 0.2 and ctx.distance(ctx.position, point) <= Ability.GetCastRange(net) then
			if api.cast(ctx, net, "point", nil, point) then
				root.heroState.netUntil[id] = ctx.now + delay + 0.3
				return true
			end
		end
	end
	if poof and controlled >= common.value(poof, "cast_duration", 1.5) + 0.1 then
		local anchor, distance = nil, 325
		for _, unit in ipairs(members) do
			if common.visible(unit) and Entity.GetHealth(unit) > Entity.GetMaxHealth(unit) * 0.5 then
				local value = ctx.distance(Entity.GetAbsOrigin(unit), Entity.GetAbsOrigin(enemy))
				if value < distance then anchor, distance = unit, value end
			end
		end
		if anchor and not ctx.unsafePosition(Entity.GetAbsOrigin(anchor)) and awareness.damage(ctx, Entity.GetAbsOrigin(anchor), 2) < Entity.GetHealth(ctx.hero) * 0.35 then
			return api.cast(ctx, poof, "target", anchor)
		end
	end
	return false
end

function meepo.update(ctx, api)
	return control(ctx, ctx, api)
end

function meepo.unit(ctx, api, unit)
	if NPC.GetUnitName(unit) ~= "npc_dota_hero_meepo" or NPC.IsIllusion(unit) then return false end
	local actor = common.actor(ctx, unit)
	actor.farmCandidate, actor.teamTask, actor.runeTask = false, false, false
	actor.intent = ctx.intent and ctx.intent.kind == "hero" and {kind = "hero", target = ctx.intent.target, opportunity = ctx.intent.opportunity} or false
	if control(ctx, actor, api) then return true end
	if actor.target then return common.unitAttack(ctx, unit, actor.target) end
	local target = common.visible(ctx.attackTarget) and ctx.attackTarget or common.unitTarget(ctx, unit)
	if target and not NPC.IsHero(target) and not Entity.IsSameTeam(unit, target) and ctx.distance(actor.position, Entity.GetAbsOrigin(target)) < 1400
		and not actor.unsafePosition(Entity.GetAbsOrigin(target)) then return common.unitAttack(ctx, unit, target) end
	if ctx.distance(actor.position, ctx.position) > 300 then
		local poof = common.ability(actor, api, "meepo_poof")
		if poof and ctx.health > 0.65 and not ctx.retreating and ctx.distance(actor.position, ctx.position) > 1800
			and awareness.damage(actor, ctx.position, 2) < Entity.GetHealth(unit) * 0.15 then return api.cast(actor, poof, "target", ctx.hero) end
		local goal = navigation.goal(actor, ctx.toward(ctx.position, ctx.home, 140))
		if goal then actor.move(goal) end
	end
	return true
end

return meepo
