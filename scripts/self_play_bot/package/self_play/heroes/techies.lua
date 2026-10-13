local techies = {reserved = {techies_land_mines = true, techies_suicide = true, techies_sticky_bomb = true,
	techies_reactive_tazer = true, techies_reactive_tazer_stop = true, techies_minefield_sign = true}}
local common = require("self_play.heroes.common")
local awareness = require("self_play.awareness")

local function blastReady(ctx, api)
	local ability = NPC.GetAbility(ctx.hero, "techies_suicide")
	if ability and api.ready(ctx, ability, false) and NPC.GetMana(ctx.hero) >= Ability.GetManaCost(ability)
		and (ctx.abilityAttempts.techies_suicide or 0) <= ctx.now then return ability end
end

function techies.locked(ctx)
	return ctx.heroState.techiesCombo ~= nil
end

local function finish(ctx)
	ctx.heroState.techiesCombo, ctx.heroState.combo = nil, nil
end

function techies.blastPoint(ctx, ability, enemy)
	if NPC.HasState(ctx.hero, Enum.ModifierState.MODIFIER_STATE_ROOTED)
		or NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_MAGIC_IMMUNE) then return nil end
	local delay = Ability.GetCastPoint(ability) + common.value(ability, "duration", 0.75)
	local point = ctx.predict(enemy, delay)
	local range, radius = Ability.GetCastRange(ability), common.value(ability, "radius", 400)
	if ctx.distance(ctx.position, point) > range then point = ctx.toward(ctx.position, point, range) end
	if ctx.distance(point, ctx.predict(enemy, delay)) > radius - 100 or not GridNav.IsTraversable(point) or ctx.unsafePosition(point) then return nil end
	local cost = Entity.GetMaxHealth(ctx.hero) * common.value(ability, "hp_cost", 20) / 100
	local remaining = Entity.GetHealth(ctx.hero) - cost
	local incoming = awareness.damage(ctx, point, 1.5) + awareness.forecast(ctx, point)
	if remaining < Entity.GetMaxHealth(ctx.hero) * 0.28 or incoming > remaining * 0.55 or ctx.nearEnemies > ctx.nearAllies + 1 then return nil end
	return point, delay
end

local function detonate(ctx, api)
	local stop = common.ability(ctx, api, "techies_reactive_tazer_stop")
	if not stop then return false end
	local tazer = NPC.GetAbility(ctx.hero, "techies_reactive_tazer")
	if not tazer then return false end
	local radius = common.value(tazer, "explosion_radius", 450)
	for _, enemy in ipairs(ctx.enemies) do
		if common.visible(enemy) and not NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_MAGIC_IMMUNE)
			and ctx.distance(ctx.position, ctx.predict(enemy, 0.15)) < radius - 35
			and (not NPC.IsStunned(enemy) or ctx.heroState.techiesCombo and ctx.heroState.techiesCombo.stage == "follow") then
			return api.cast(ctx, stop, "none")
		end
	end
	return false
end

function techies.duringCast(ctx, api)
	local task = ctx.heroState.techiesCombo
	if not task or task.stage ~= "flight" then return false end
	local blast = NPC.GetAbility(ctx.hero, "techies_suicide")
	if ctx.hardRetreat and blast and Ability.IsInAbilityPhase(blast) then ctx.stop(); finish(ctx); return false end
	if ctx.now < task.lands then ctx.mode = "Blast Off: preserve jump"; return true end
	if ctx.distance(ctx.position, task.position) > 550 then finish(ctx); return false end
	task.stage = "follow"
	return false
end

function techies.canPlace(ctx, position, spacing)
	if not GridNav.IsTraversable(position) then return false end
	for _, unit in ipairs(ctx.worldNPCs) do
		if common.visible(unit) and Entity.IsSameTeam(ctx.hero, unit) and NPC.GetUnitName(unit) == "npc_dota_techies_land_mine"
			and ctx.distance(position, Entity.GetAbsOrigin(unit)) < spacing then return false end
	end
	for index = #(ctx.heroState.mines or {}), 1, -1 do
		local mine = ctx.heroState.mines[index]
		if ctx.now > mine.expires then table.remove(ctx.heroState.mines, index)
		elseif ctx.distance(position, mine.position) < spacing then return false end
	end
	return true
end

function techies.update(ctx, api, retreat)
	if api.busy(ctx) then return true end
	if techies.duringCast(ctx, api) then return true end
	local enemy = common.enemy(ctx, 1200)
	local task = ctx.heroState.techiesCombo
	if task and (ctx.now > task.expires or not common.visible(task.target) or ctx.hardRetreat) then finish(ctx); task = nil end
	if task then enemy = task.target; ctx.target = enemy end
	if detonate(ctx, api) then return true end
	local blast = blastReady(ctx, api)
	local point, delay
	if blast and enemy and not ctx.retreating and not ctx.hardRetreat then point, delay = techies.blastPoint(ctx, blast, enemy) end
	local nuke = blast or NPC.GetAbility(ctx.hero, "techies_sticky_bomb")
	local damage = nuke and common.value(nuke, "damage", 200) or 0
	local committed = enemy and (ctx.intent and ctx.intent.kind == "hero" or ctx.laneThreat and ctx.laneThreat.attacked
		or NPC.IsChannellingAbility(enemy) or Entity.GetHealth(enemy) < damage * NPC.GetMagicalArmorDamageMultiplier(enemy) + NPC.GetTrueDamage(ctx.hero) * 2
		or ctx.clock > 15 and ctx.nearAllies > ctx.nearEnemies and Hero.GetRecentDamage(enemy) > 0)
	ctx.heroState.blastReason = not blast and "unavailable" or not point and "unsafe landing or out of reach" or not committed and "no combat opportunity" or "ready"
	if not task and point and committed then
		task = {stage = "prepare", target = enemy, expires = ctx.now + delay + 4}
		ctx.heroState.techiesCombo, ctx.heroState.combo = task, {executing = true}
	end
	local tazer = common.ability(ctx, api, "techies_reactive_tazer")
	if tazer and enemy and (task and task.stage == "prepare" or retreat and Hero.GetRecentDamage(ctx.hero) > 0
		or NPC.IsAttacking(enemy) and ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy)) < 500)
		and ctx.now >= (ctx.heroState.tazerUntil or 0)
		and (not task or blast and NPC.GetMana(ctx.hero) >= Ability.GetManaCost(blast) + Ability.GetManaCost(tazer)) then
		if common.cast(ctx, api, tazer, "target", ctx.hero) then
			ctx.heroState.tazerUntil = ctx.now + common.value(tazer, "duration", 6)
			if task then task.stage = "blast" end
			return true
		end
	end
	if task and (task.stage == "prepare" or task.stage == "blast") then
		if blast and point and api.cast(ctx, blast, "point", nil, point) then
			task.stage, task.position, task.lands = "flight", point, ctx.now + delay + 0.1
			return true
		end
		finish(ctx); task = nil
	end
	if common.items(ctx, api, enemy, retreat) then return true end
	if enemy then
		local bomb = common.ability(ctx, api, "techies_sticky_bomb")
		if bomb and ctx.now >= (ctx.heroState.nextBomb or 0) and (committed or task or retreat and Hero.GetRecentDamage(ctx.hero) > 0) then
			local point = ctx.predict(enemy, Ability.GetCastPoint(bomb) + common.value(bomb, "duration", 1.2))
			if ctx.distance(ctx.position, point) <= Ability.GetCastRange(bomb) and api.cast(ctx, bomb, "point", nil, point) then
				ctx.heroState.nextBomb = ctx.now + math.max(4, common.value(bomb, "duration", 1.2) + common.value(bomb, "countdown", 2))
				return true
			end
		end
	end
	local mine = common.ability(ctx, api, "techies_land_mines")
	if not mine or ctx.now < (ctx.heroState.nextMine or 0) or NPC.GetMana(ctx.hero) < Ability.GetManaCost(mine) + 150 then return false end
	local point
	if enemy then point = ctx.predict(enemy, common.value(mine, "activation_delay", 1) + 0.8)
	elseif ctx.clock > 360 and not retreat and NPC.GetMana(ctx.hero) > NPC.GetMaxMana(ctx.hero) * 0.65 then point = ctx.toward(ctx.position, ctx.home, 220) end
	if not point or ctx.distance(ctx.position, point) > Ability.GetCastRange(mine) then return false end
	local spacing = common.value(mine, "placement_radius", 350)
	if not techies.canPlace(ctx, point, spacing) then return false end
	ctx.heroState.mines = ctx.heroState.mines or {}
	ctx.heroState.mines[#ctx.heroState.mines + 1] = {position = point, expires = ctx.now + 4}
	ctx.heroState.nextMine = ctx.now + (enemy and 1.2 or 10)
	return api.cast(ctx, mine, "point", nil, point)
end

function techies.unit(ctx, api, unit)
	return NPC.GetUnitName(unit):find("^npc_dota_techies_") ~= nil
end

return techies
