local druid = {reserved = {lone_druid_spirit_bear = true, lone_druid_true_form = true, lone_druid_true_form_druid = true}}
local common = require("self_play.heroes.common")

local function isBear(unit)
	return NPC.GetUnitName(unit):find("^npc_dota_lone_druid_bear") ~= nil
end

function druid.inventoryUnits(ctx)
	local result = {}
	for _, unit in ipairs(ctx.summons) do if common.visible(unit) and isBear(unit) then result[#result + 1] = unit end end
	return result
end

function druid.itemOwner(ctx, name)
	local heroItems = {tango = true, flask = true, clarity = true, bottle = true, magic_wand = true, magic_stick = true,
		tpscroll = true, ultimate_scepter = true, ultimate_scepter_2 = true, aghanim_shard = true, aghanims_shard = true,
		ward_observer = true, ward_sentry = true, ward_dispenser = true, bracer = true, glimmer_cape = true, force_staff = true}
	if heroItems[name] then return "hero" end
	local guide = ctx.shop.guide
	if guide then
		for _, group in ipairs(guide.groups) do
			local title = group.title:lower()
			local owner = title:find("bear", 1, true) and "bear" or title:find("druid", 1, true) and "hero" or nil
			if owner then for _, item in ipairs(group.items) do if item == name then return owner end end end
		end
		if guide.title and guide.title:lower():find("bear", 1, true) then return "bear" end
	end
	local item = ctx.catalog.items[name]
	return item and (item.cost or 0) >= 450 and "bear" or "hero"
end

function druid.inventory(ctx, entries)
	local bear = druid.inventoryUnits(ctx)[1]
	if not bear then return false end
	local state, transfer = ctx.shop, nil
	for _, entry in ipairs(entries) do
		if entry.unit == ctx.hero and entry.slot <= 8 then
			local assigned = druid.itemOwner(ctx, entry.name) == "bear"
			local goal = state.plan[state.index]
			if goal and ctx.planner.contains(state.items, goal, entry.name) then assigned = druid.itemOwner(ctx, goal) == "bear" end
			if assigned then transfer = entry; break end
		end
	end
	state.bearTransferPending = transfer ~= nil
	if not transfer or ctx.nearEnemies > 0 or ctx.retreating or ctx.now < (state.nextBearTransfer or 0) then return false end
	local free = false
	for slot = 0, 5 do if not NPC.GetItemByIndex(bear, slot) then free = true; break end end
	if not free then state.status = "Bear inventory full; transfer pending" end
	if not free or ctx.distance(ctx.position, Entity.GetAbsOrigin(bear)) > 250 then return false end
	Player.PrepareUnitOrders(ctx.player, Enum.UnitOrder.DOTA_UNIT_ORDER_GIVE_ITEM, bear, Vector(0, 0, 0), transfer.item,
		Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, ctx.hero, false, false, false, true, "self_play_bear_item", false)
	state.nextBearTransfer = ctx.now + 1
	state.status = "Transfer to bear: " .. transfer.name
	return true
end

function druid.skillPriority(ctx, name)
	return name == "lone_druid_spirit_bear" and 180 or 0
end

function druid.update(ctx, api, retreat)
	local bear
	for _, unit in ipairs(ctx.summons) do if common.visible(unit) and isBear(unit) then bear = unit; break end end
	local summon = common.ability(ctx, api, "lone_druid_spirit_bear")
	if not bear and summon then return api.cast(ctx, summon, "none") end
	local form = common.ability(ctx, api, "lone_druid_true_form")
	if form and not NPC.HasModifier(ctx.hero, "modifier_lone_druid_true_form")
		and (common.enemy(ctx, 700) or retreat and ctx.health < 0.55) then return api.cast(ctx, form, "none") end
	return false
end

function druid.unit(ctx, api, unit)
	if not isBear(unit) then return false end
	local actor = common.actor(ctx, unit)
	if api.busy(actor) then return true end
	local position = Entity.GetAbsOrigin(unit)
	local distance = ctx.distance(position, ctx.position)
	if not Entity.IsAlive(ctx.hero) then NPC.MoveTo(unit, ctx.home, false, false, false, true); return true end
	if ctx.shop.bearTransferPending and ctx.nearEnemies == 0 and distance > 150 then
		NPC.MoveTo(unit, ctx.position, false, false, false, true)
		return true
	end
	if distance > 900 and not NPC.HasScepter(ctx.hero) then
		if common.unitCast(ctx, api, unit, "lone_druid_spirit_bear_return", "none") then return true end
		NPC.MoveTo(unit, ctx.position, false, false, false, true)
		return true
	end
	if ctx.retreating or Entity.GetHealth(unit) < Entity.GetMaxHealth(unit) * 0.3 then
		local target = common.unitTarget(ctx, unit)
		if target and ctx.distance(position, Entity.GetAbsOrigin(target)) < 350
			and common.unitCast(ctx, api, unit, "lone_druid_savage_roar_bear", "none") then return true end
		NPC.MoveTo(unit, ctx.toward(ctx.position, ctx.home, 250), false, false, false, true)
		return true
	end
	local target = common.unitTarget(ctx, unit)
	if common.items(actor, api, target, ctx.retreating) then return true end
	if target and (NPC.HasScepter(ctx.hero) or ctx.distance(ctx.position, Entity.GetAbsOrigin(target)) < 950)
		and common.unitAttack(ctx, unit, target) then return true end
	if distance > 250 then NPC.MoveTo(unit, ctx.position, false, false, false, true) end
	return true
end

return druid
