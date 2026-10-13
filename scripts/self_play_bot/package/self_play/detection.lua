local detection = {}
local vision = require("self_play.vision")
local awareness = require("self_play.awareness")
local itemKV = XHelpers.xkv:GetKV("items").DOTAAbilities
local radius = tonumber(itemKV.item_ward_sentry.AbilityValues.true_sight_range)
local abilities = {
	riki_permanent_invisibility = true, riki_backstab = true, bounty_hunter_wind_walk = true, bounty_hunter_wind_walk_ally = true,
	clinkz_wind_walk = true, invoker_ghost_walk = true, mirana_invis = true, nyx_assassin_vendetta = true,
	sandking_sand_storm = true, templar_assassin_meld = true, weaver_shukuchi = true,
	treant_natures_guise = true, kez_ravens_veil = true, nyx_assassin_burrow = true, hoodwink_decoy = true,
}
local invisItems = {item_glimmer_cape = true, item_invis_sword = true, item_silver_edge = true,
	item_shadow_amulet = true, item_trickster_cloak = true}
local unrevealable = {"modifier_slark_shadow_dance", "modifier_slark_depth_shroud", "modifier_smoke_of_deceit",
	"modifier_phantom_assassin_blur_active", "modifier_dark_willow_shadow_realm_buff"}

local function enemy(ctx, unit)
	return unit and Entity.IsEntity(unit) and NPC.IsHero(unit) and not Entity.IsSameTeam(ctx.hero, unit) and not NPC.IsIllusion(unit)
end

local function invisible(unit)
	for _, name in ipairs(unrevealable) do if NPC.HasModifier(unit, name) then return false end end
	return NPC.HasState(unit, Enum.ModifierState.MODIFIER_STATE_INVISIBLE)
		or NPC.HasModifier(unit, "modifier_item_glimmer_cape_fade") or NPC.HasModifier(unit, "modifier_invisible")
end

function detection.observe(ctx, heroes)
	local state = ctx.detection or {enemies = {}}
	ctx.detection = state
	for _, unit in ipairs(heroes) do
		if enemy(ctx, unit) then
			local id = Entity.GetIndex(unit)
			local entry = state.enemies[id] or {source = unit}
			state.enemies[id] = entry
			local reason
			for i = 0, 31 do
				local ability = NPC.GetAbilityByIndex(unit, i)
				if ability and Ability.GetLevel(ability) > 0 and abilities[Ability.GetName(ability)] then reason = Ability.GetName(ability); break end
			end
			for i = 0, 8 do
				local item = NPC.GetItemByIndex(unit, i)
				if item and invisItems[Ability.GetName(item)] then reason = Ability.GetName(item); break end
			end
			if not Entity.IsDormant(unit) and invisible(unit) then entry.observedUntil = ctx.now + 300 end
			if reason or not Entity.IsDormant(unit) then
				entry.reason = reason or (entry.observedUntil or 0) > ctx.now and "Observed enemy invisibility" or nil
				entry.expires = ctx.now + 300
			end
		end
	end
	state.needed, state.reason = false, nil
	for id, entry in pairs(state.enemies) do
		if not Entity.IsEntity(entry.source) or (entry.expires or 0) < ctx.now then state.enemies[id] = nil
		elseif entry.reason then state.needed, state.reason = true, entry.reason end
	end
	local target = ctx.intent and ctx.intent.kind == "hero" and ctx.intent.target
		or ctx.fightSession and ctx.fightSession.target or ctx.lastOrder == "attack" and ctx.attackTarget
	if enemy(ctx, target) and Entity.IsAlive(target) and not Entity.IsDormant(target) and NPC.IsVisible(target) then
		state.pursuit = {target = target, time = ctx.now, position = Entity.GetAbsOrigin(target)}
	end
	if state.pursuit and (ctx.now - state.pursuit.time > 3 or not Entity.IsEntity(state.pursuit.target)
		or not Entity.IsAlive(state.pursuit.target)) then state.pursuit = nil end
end

function detection.needed(ctx)
	return ctx.detection and ctx.detection.needed == true or false
end

function detection.covered(ctx, point)
	for _, unit in ipairs(ctx.worldNPCs) do
		if Entity.IsEntity(unit) and Entity.IsAlive(unit) and Entity.IsSameTeam(ctx.hero, unit)
			and NPC.GetUnitName(unit) == "npc_dota_sentry_wards" and ctx.distance(point, Entity.GetAbsOrigin(unit)) < radius - 100 then return true end
	end
	for _, entry in ipairs(ctx.dewardPlacements or {}) do
		if entry.expires > ctx.now and ctx.distance(point, entry.position) < radius - 100 then return true end
	end
	return false
end

function detection.opportunity(ctx)
	local state, task = ctx.detection, ctx.detection and ctx.detection.pursuit
	if not ctx.settings.wards or not task or ctx.retreating or ctx.hardRetreat or ctx.now - task.time > 3
		or not Entity.IsEntity(task.target) or not Entity.IsAlive(task.target) then return nil end
	local target = task.target
	if not Entity.IsDormant(target) and NPC.IsVisible(target) or not invisible(target)
		or NPC.HasModifier(target, "modifier_item_dustofappearance") or NPC.HasModifier(target, "modifier_truesight") then return nil end
	local memory = ctx.memory[Entity.GetIndex(target)]
	local point = memory and ctx.now - memory.time < 2 and memory.position or task.position
	if not FogOfWar.IsPointVisible(point) or ctx.distance(ctx.position, point) > radius - 100 or detection.covered(ctx, point)
		or ctx.unsafePosition(point) or awareness.damage(ctx, ctx.position, 1.5) > Entity.GetHealth(ctx.hero) * 0.4 then return nil end
	if state.placed and state.placed.target == target and ctx.now - state.placed.time < 10 then return nil end
	return point, target
end

function detection.supply(ctx, entries)
	if not detection.needed(ctx) then return nil end
	local dust, sentries, gem, room = 0, 0, false, false
	for _, entry in ipairs(entries) do
		if entry.name == "dust" then dust = dust + Item.GetCurrentCharges(entry.item) end
		sentries = sentries + vision.sentries(entry.item)
		if entry.name == "gem" then gem = true end
	end
	for slot = 0, 8 do if not NPC.GetItemByIndex(ctx.hero, slot) then room = true; break end end
	if not room or gem then return nil end
	if dust == 0 and ctx.now >= (ctx.shop.nextDust or 0) then return "dust" end
	if sentries == 0 and ctx.now >= (ctx.shop.nextSentry or 0) and detection.opportunity(ctx) then return "ward_sentry" end
end

function detection.run(ctx, api)
	if not ctx.settings.spells or ctx.parent or api.busy(ctx) then return false end
	local point, target = detection.opportunity(ctx)
	if not point then return false end
	local item
	for _, name in ipairs({"item_ward_sentry", "item_ward_dispenser"}) do
		local held = NPC.GetItem(ctx.hero, name, true)
		if held and vision.sentries(held) > 0 and api.ready(ctx, held, true) then item = held; break end
	end
	if not item or (ctx.abilityAttempts[Ability.GetName(item)] or 0) > ctx.now then return false end
	local goal = ctx.toward(ctx.position, point, math.min(Ability.GetCastRange(item) - 25, ctx.distance(ctx.position, point) * 0.5))
	if not GridNav.IsTraversable(goal) or ctx.unsafePosition(goal) then return false end
	if Ability.GetName(item) == "item_ward_dispenser" and Ability.GetToggleState(item) then
		Ability.Toggle(item, false, false, true)
		ctx.busyUntil = ctx.now + 0.2
		return true
	end
	if api.cast(ctx, item, "point", nil, goal) then
		ctx.dewardPlacements = ctx.dewardPlacements or {}
		ctx.dewardPlacements[#ctx.dewardPlacements + 1] = {position = goal, expires = ctx.now + 4}
		ctx.detection.placed = {target = target, time = ctx.now}
		ctx.mode = "Reveal pursued invisible hero with sentry"
		return true
	end
	return false
end

return detection
