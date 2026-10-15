local shop = {}
local JSON = require("assets.JSON")
local protracker = require("self_play.protracker")
local heroModules = require("self_play.heroes.registry")
local vision = require("self_play.vision")
local deward = require("self_play.deward")
local detection = require("self_play.detection")
local inventoryCleanup = require("self_play.inventory_cleanup")
local userBuilds = require("self_play.user_builds")

local cfg = {buyInterval = 1.5, courierInterval = 2, requestTimeout = 25, retryDelay = 40, cacheAge = 21600}
local itemKV = XHelpers.xkv:GetKV("items").DOTAAbilities

local function outOfStock(name, team)
	local kv = itemKV["item_" .. name]
	return kv and tonumber(kv.ItemStockMax or "0") > 0 and Item.GetStockCount(tonumber(kv.ID), team) <= 0
end

function shop.inventory(ctx)
	local counts, entries, seen = {}, {}, {}
	local courier = Couriers.GetLocal()
	local function scan(unit, lastSlot, localCargo)
		if not unit then return end
		for slot = 0, lastSlot do
			local item = NPC.GetItemByIndex(unit, slot)
			if item and not seen[item] and (unit == ctx.hero or localCargo or Item.GetPlayerOwnerID(item) == ctx.playerId) then
				seen[item] = true
				local name = Ability.GetName(item):gsub("^item_", "")
				local kv = itemKV["item_" .. name]
				local quantity = kv and kv.ItemRecipe == "1" and math.max(1, Item.GetCurrentCharges(item)) or 1
				counts[name] = (counts[name] or 0) + quantity
				entries[#entries + 1] = {item = item, name = name, slot = slot, unit = unit}
			end
		end
	end
	scan(ctx.hero, 16)
	scan(courier, 8, true)
	for _, unit in ipairs(Couriers.GetAll()) do if unit ~= courier then scan(unit, 8, false) end end
	if ctx.heroModule and ctx.heroModule.inventoryUnits then
		for _, unit in ipairs(ctx.heroModule.inventoryUnits(ctx)) do scan(unit, 8) end
	end
	if NPC.HasShard(ctx.hero) then counts.aghanims_shard = math.max(1, counts.aghanims_shard or 0) end
	if NPC.HasModifier(ctx.hero, "modifier_item_ultimate_scepter_consumed")
		or NPC.HasScepter(ctx.hero) and not counts.ultimate_scepter and not counts.ultimate_scepter_2 then
		counts.ultimate_scepter_2 = math.max(1, counts.ultimate_scepter_2 or 0)
	end
	return counts, entries
end

local function planClock(ctx)
	if ctx.clock >= 120 then return ctx.clock end
	if GameRules and GameRules.GetGameState then
		local ok, state = pcall(GameRules.GetGameState)
		if ok and state == Enum.GameState.DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then return 121 end
	end
	return ctx.clock
end

local shopConfig = "self_play_shop"

local function progressKey(ctx)
	return "progress_" .. ctx.heroName
end

local function saveProgress(ctx)
	local state = ctx.shop
	if not state.plan or #state.plan == 0 then return end
	local done = {}
	for name in pairs(state.completed) do done[#done + 1] = name end
	table.sort(done)
	Config.WriteString(shopConfig, progressKey(ctx), JSON:encode({plan = state.plan, done = done, index = state.index}))
end

local function restoreProgress(ctx)
	local state = ctx.shop
	local raw = Config.ReadString(shopConfig, progressKey(ctx), "")
	if raw == "" or not state.plan or #state.plan == 0 then return end
	local ok, saved = pcall(JSON.decode, raw)
	if not ok or type(saved) ~= "table" or type(saved.plan) ~= "table" or type(saved.done) ~= "table" then return end
	if #saved.plan ~= #state.plan then return end
	for index, name in ipairs(state.plan) do
		if saved.plan[index] ~= name then return end
	end
	for _, name in ipairs(saved.done) do state.completed[name] = true end
	state.index = math.max(1, math.min(tonumber(saved.index) or 1, #state.plan + 1))
end

function shop.init(ctx)
	local guide = ctx.planner.selectGuide(ctx.catalog, ctx.heroName, ctx.role)
	ctx.shop = {
		items = ctx.planner.gameItems(ctx.catalog.items, itemKV),
		guide = guide, plan = ctx.planner.build(ctx.catalog, guide, ctx.role, planClock(ctx)),
		index = 1, completed = {}, nextBuy = 0, nextCourier = 0, nextRequest = 0, nextSupply = 0, nextInventory = 0,
		attempts = 0, buildWaitUntil = ctx.now + 5, source = guide and "Cached guide: " .. guide.title or "Offline role build", status = "Starting",
	}
	restoreProgress(ctx)
	ctx.shop.fallbackGuide = guide
	local hero = ctx.catalog.heroes[ctx.heroName]
	if hero then
		for _, role in ipairs(protracker.roles[ctx.role]) do
			local key = ctx.heroName .. "_pos" .. role
			local cached = Config.ReadString("self_play_protracker", key, "")
			local fetched = Config.ReadInt("self_play_protracker", key .. "_time", 0)
			local data = cached ~= "" and os.time() - fetched < 86400 and protracker.parse(cached, hero.id, role)
			local parsed = data and protracker.guide(ctx, data)
			if parsed then
				ctx.shop.guide, ctx.shop.plan = parsed, protracker.plan(ctx, parsed)
				ctx.shop.source, ctx.shop.protrackerRole = protracker.source(role, ctx.role, true), role
				if role == ctx.role and os.time() - fetched < cfg.cacheAge then ctx.shop.nextRequest = ctx.now + cfg.cacheAge end
				break
			end
		end
	end
	ctx.shop.plan = heroModules.plan(ctx, ctx.shop.plan)
end

local function customActive(ctx)
	local custom = ctx.shop.custom
	return custom ~= nil and custom:gsub("%s", "") ~= ""
end

local function applyPlan(ctx, plan, source)
	local state = ctx.shop
	if customActive(ctx) and source ~= "Custom build" then return end
	plan = heroModules.plan(ctx, plan)
	if state.pending then
		state.deferredPlan, state.deferredSource = plan, source
	else
		if state.startedGoal and not ctx.planner.owns(ctx.shop.items, shop.inventory(ctx), state.startedGoal) then
			for index = #plan, 1, -1 do if plan[index] == state.startedGoal then table.remove(plan, index) end end
			table.insert(plan, 1, state.startedGoal)
		end
		state.plan, state.index, state.source, state.completed = plan, 1, source, {}
		restoreProgress(ctx)
		saveProgress(ctx)
	end
end

local function requestGuide(ctx)
	local state, guide = ctx.shop, ctx.shop.fallbackGuide
	if not ctx.settings.online or not guide or state.protrackerRole or state.guideRequested then return end
	state.guideRequested = true
	HTTP.Request("GET", guide.url, {timeout = cfg.requestTimeout}, function(response)
		if not ctx.active or ctx.shop ~= state or not ctx.settings.online then return end
		if tonumber(response.code) ~= 200 or state.protrackerRole then return end
		local parsed = ctx.planner.parseGuide(response.response, ctx.heroName)
		if not parsed then return end
		parsed.hero, parsed.support, parsed.url = guide.hero, guide.support, guide.url
		state.guide = parsed
		applyPlan(ctx, ctx.planner.build(ctx.catalog, parsed, ctx.role, ctx.clock), "Public guide: " .. parsed.title .. " (" .. parsed.patch .. ")")
	end)
end

local function customPlan(ctx, text)
	local plan, problems, counted = {}, {}, {}
	for entry in text:gmatch("[^,%s]+") do
		local name = entry:lower():gsub("^item_", "")
		local record = ctx.shop.items[name]
		if not record then
			problems[#problems + 1] = name .. " (not in game data)"
		elseif record.neutral or record.purchasable == false then
			problems[#problems + 1] = name .. " (not sold in shop)"
		elseif record.recipe and (record.cost or 0) <= 0 then
			problems[#problems + 1] = name .. " (recipe is not sold separately)"
		else
			counted[name] = (counted[name] or 0) + 1
			if record.limit and record.limit > 0 and counted[name] > record.limit then
				problems[#problems + 1] = name .. " (limit " .. record.limit .. " reached)"
			else
				plan[#plan + 1] = name
			end
		end
	end
	if #plan == 0 then
		ctx.shop.status = #problems > 0 and "Skipped: " .. table.concat(problems, ", ") or "Custom build is empty"
		return nil
	end
	if #problems > 0 then ctx.shop.customUnknown = table.concat(problems, ", ") end
	return plan
end

local function customText(ctx)
	if not ctx.settings.customBuilds then return "" end
	local plan = userBuilds.plan(ctx.heroName)
	if not plan or #plan == 0 then return "" end
	return table.concat(plan, ",")
end

local function applyCustom(ctx)
	local state = ctx.shop
	local text = customText(ctx)
	if state.custom == text then return end
	state.custom = text
	if state.customPlan then
		state.plan, state.index, state.source = state.customPlan.plan, state.customPlan.index, state.customPlan.source
		state.customPlan = nil
		saveProgress(ctx)
	end
	if state.deferredSource == "Custom build" then state.deferredPlan, state.deferredSource = nil, nil end
	state.customUnknown = nil
	if text == "" then return end
	local plan = customPlan(ctx, text)
	if not plan then
		if state.customPlan then state.plan, state.index, state.source = state.customPlan.plan, state.customPlan.index, state.customPlan.source end
		state.customPlan = nil
		return
	end
	state.customPlan = {plan = state.plan, index = state.index, source = state.source}
	applyPlan(ctx, plan, "Custom build")
	state.status = state.customUnknown and "Custom build (unknown: " .. state.customUnknown .. ")" or "Custom build"
end

function shop.fetch(ctx)
	local state = ctx.shop
	if customActive(ctx) then return end
	if state.requesting and ctx.now - state.requestStart > cfg.requestTimeout + 5 then
		state.requesting = false
		state.requestVersion = state.requestVersion + 1
		state.providerError = "Dota2ProTracker timed out; using fallback"
		requestGuide(ctx)
	end
	if not ctx.settings.online or state.requesting or state.attempts >= 2 or ctx.now < state.nextRequest then return end
	local hero = ctx.catalog.heroes[ctx.heroName]
	if not hero then return end
	state.requestRoleIndex = state.requestRoleIndex or 1
	local role = protracker.roles[ctx.role][state.requestRoleIndex]
	if not role then return end
	state.attempts, state.requesting = state.attempts + 1, true
	state.requestStart = ctx.now
	state.requestVersion = (state.requestVersion or 0) + 1
	local version = state.requestVersion
	state.nextRequest = ctx.now + cfg.retryDelay
	local sent = HTTP.Request("GET", "https://dota2protracker.com/api/hero/" .. hero.id .. "/builds?position=pos%20" .. role,
		{timeout = cfg.requestTimeout, headers = {Accept = "application/json", ["User-Agent"] = protracker.userAgent,
			Referer = "https://dota2protracker.com/"}}, function(response)
			if not ctx.active or ctx.shop ~= state or version ~= state.requestVersion then return end
			state.requesting = false
			if not ctx.settings.online then return end
			local data, reason
			if tonumber(response.code) == 200 then data, reason = protracker.parse(response.response, hero.id, role) end
			local guide = data and protracker.guide(ctx, data)
			if guide then
				state.attempts, state.protrackerRole, state.guide = 2, role, guide
				applyPlan(ctx, protracker.plan(ctx, guide), protracker.source(role, ctx.role, false))
				local key = ctx.heroName .. "_pos" .. role
				Config.WriteString("self_play_protracker", key, response.response)
				Config.WriteInt("self_play_protracker", key .. "_time", os.time())
				state.providerError = nil
			elseif reason == "empty" and state.requestRoleIndex < #protracker.roles[ctx.role] then
				state.requestRoleIndex, state.attempts, state.nextRequest = state.requestRoleIndex + 1, 0, ctx.now
				shop.fetch(ctx)
			else
				if reason == "empty" then state.attempts = 2 end
				state.providerError = "Dota2ProTracker: " .. (reason == "empty" and "no builds for any role" or reason
					or data and "unsupported item build" or "HTTP " .. tostring(response.code)) .. "; using fallback"
				requestGuide(ctx)
			end
		end)
	if not sent then
		state.requesting = false
		state.providerError = "Dota2ProTracker request could not start"
		requestGuide(ctx)
	end
end

function shop.manageInventory(ctx)
	local state = ctx.shop
	if ctx.now < state.nextInventory or ctx.now < ctx.busyUntil or not Entity.IsAlive(ctx.hero) or NPC.IsChannellingAbility(ctx.hero) then return end
	state.nextInventory = ctx.now + 2
	local _, entries = shop.inventory(ctx)
	if ctx.heroModule and ctx.heroModule.inventory and ctx.heroModule.inventory(ctx, entries) then return end
	local lowest, highest, freeSlot = nil, nil, nil
	local goal = state.plan[state.index]
	for _, entry in ipairs(entries) do
		if goal and entry.unit ~= Couriers.GetLocal() and Item.IsCombineLocked(entry.item)
			and ctx.planner.contains(state.items, goal, entry.name) then
			Player.PrepareUnitOrders(ctx.player, Enum.UnitOrder.DOTA_UNIT_ORDER_SET_ITEM_COMBINE_LOCK, 0, Vector(0, 0, 0), entry.item,
				Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, entry.unit, false, false, false, true, "self_play_combine", false)
			return
		end
	end
	for slot = 0, 5 do if not NPC.GetItemByIndex(ctx.hero, slot) then freeSlot = slot; break end end
	for _, entry in ipairs(entries) do
		if entry.unit == ctx.hero and entry.slot <= 8 then
			entry.cost = Item.GetCost(entry.item)
			if vision.responsible(ctx) and vision.observers(entry.item) > 0 and not ctx.intent
				and Hero.GetRecentDamage(ctx.hero) == 0 and not NPC.IsAttacking(ctx.hero) then entry.cost = entry.cost + 5000 end
			if vision.sentries(entry.item) > 0 and (deward.needed(ctx) and not ctx.intent or detection.opportunity(ctx)) then entry.cost = entry.cost + 5500 end
			if entry.name == "dust" and Item.GetCurrentCharges(entry.item) > 0 and detection.needed(ctx) then entry.cost = entry.cost + 6000 end
			if goal and ctx.planner.contains(ctx.shop.items, goal, entry.name) then entry.cost = entry.cost + 2000 end
			if entry.slot <= 5 and (not lowest or entry.cost < lowest.cost) then lowest = entry end
			if entry.slot >= 6 and (not highest or entry.cost > highest.cost) then highest = entry end
		end
	end
	if highest and (freeSlot or lowest and highest.cost > lowest.cost + 250) then
		Player.PrepareUnitOrders(ctx.player, Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_ITEM, freeSlot or lowest.slot, Vector(0, 0, 0), highest.item,
			Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, ctx.hero, false, false, false, true)
		return
	end
end

function shop.regeneration(ctx, inventory)
	if ctx.clock < 0 or ctx.clock >= 600 or not Entity.IsAlive(ctx.hero)
		or NPC.HasModifier(ctx.hero, "modifier_fountain_aura_buff") then return nil end
	local health, maximum = Entity.GetHealth(ctx.hero), Entity.GetMaxHealth(ctx.hero)
	local healthMissing = maximum - health - math.max(0, NPC.GetHealthRegen(ctx.hero)) * 25
	if healthMissing > 250 and not inventory.tango and not inventory.tango_single and not inventory.flask and not inventory.bottle
		and not NPC.HasModifier(ctx.hero, "modifier_tango_heal") and not NPC.HasModifier(ctx.hero, "modifier_flask_healing") then return "tango" end
	local mana, maximumMana = NPC.GetMana(ctx.hero), NPC.GetMaxMana(ctx.hero)
	local restored = math.max(0, NPC.GetManaRegen(ctx.hero)) * 25
	if inventory.soul_ring and health > maximum * 0.55 then restored = restored + 150 end
	if mana + restored < maximumMana * 0.4 and maximumMana - mana - restored >= 180
		and not inventory.clarity and not inventory.bottle and not inventory.arcane_boots and not inventory.guardian_greaves
		and not NPC.HasModifier(ctx.hero, "modifier_clarity_potion") then return "clarity" end
	return nil
end

local function supply(ctx, inventory)
	local state = ctx.shop
	if ctx.clock < 0 then return false end
	local _, entries = shop.inventory(ctx)
	local supportOnly = ctx.role >= 4
	local detectionSupply = supportOnly and detection.supply(ctx, entries) or nil
	if ctx.now < state.nextSupply and not detectionSupply then return false end
	local name = supportOnly and shop.regeneration(ctx, inventory) or nil
	if not inventory.tpscroll and Player.GetTotalGold(ctx.player) >= 200 then name = "tpscroll" end
	local observers = 0
	if vision.responsible(ctx) then
		local _, entries = shop.inventory(ctx)
		for _, entry in ipairs(entries) do observers = observers + vision.observers(entry.item) end
	end
	if vision.needed(ctx) and observers == 0
		and ctx.now >= (state.nextObserver or 0) then
		local observer = ctx.catalog.items.ward_observer
		if Item.GetStockCount(observer.id, ctx.team) > 0 then
			name = "ward_observer"
		elseif ctx.now >= (state.nextObsLog or 0) then
			state.nextObsLog = ctx.now + 30
			Log.Write(string.format("[SelfPlay ward] vision needed but observer stock is %d",
				Item.GetStockCount(observer.id, ctx.team)))
		end
	end
	if supportOnly and ctx.clock < 600 and ctx.now >= (state.nextGrenade or 0)
		and not NPC.GetItem(ctx.hero, "item_blood_grenade", true) then name = "blood_grenade" end
	if (supportOnly or ctx.role == 3) and ctx.now >= (state.nextSentry or 0) then
		local _, entries = shop.inventory(ctx)
		local sentries = 0
		for _, entry in ipairs(entries) do sentries = sentries + vision.sentries(entry.item) end
		if sentries == 0 and (deward.needed(ctx) or (ctx.role >= 4 and ctx.clock < 90)) then name = "ward_sentry" end
	end
	name = detectionSupply or name
	if not name then return false end
	local item = ctx.catalog.items[name]
	if outOfStock(name, ctx.team) or Player.GetTotalGold(ctx.player) < item.cost then return false end
	state.nextSupply = ctx.now + 30
	if name == "ward_observer" then state.nextObserver = ctx.now + (ctx.role == 2 and 240 or 180) end
	if name == "ward_sentry" then state.nextSentry = ctx.now + 60 end
	if name == "blood_grenade" then state.nextGrenade = ctx.now + 120 end
	if name == "dust" then state.nextDust = ctx.now + 30 end
	Player.PrepareUnitOrders(ctx.player, Enum.UnitOrder.DOTA_UNIT_ORDER_PURCHASE_ITEM, item.id, Vector(0, 0, 0), item.id,
		Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, ctx.hero, false, false, false, true, "self_play_supply", false)
	return true
end

local function courierCast(ctx, courier, name)
	local ability = NPC.GetAbility(courier, name)
	if ability and Ability.IsReady(ability) then
		Player.PrepareUnitOrders(ctx.player, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET, nil, Vector(0, 0, 0), ability,
			Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, courier, false, false, false, true, "self_play_courier", false)
		return true
	end
	return false
end

function shop.courier(ctx, secret)
	if ctx.now < ctx.shop.nextCourier then return end
	ctx.shop.nextCourier = ctx.now + cfg.courierInterval
	local courier = Couriers.GetLocal()
	if not courier or not Entity.IsAlive(courier) then return end
	local position = Entity.GetAbsOrigin(courier)
	for _, enemy in ipairs(ctx.enemies) do
		if Entity.IsEntity(enemy) and Entity.IsAlive(enemy) and not Entity.IsDormant(enemy) and NPC.IsVisible(enemy)
			and ctx.distance(position, Entity.GetAbsOrigin(enemy)) < 1000 then
			courierCast(ctx, courier, "courier_return_stash_items")
			return
		end
	end
	if secret then
		if not NPC.IsInRangeOfShop(courier, Enum.ShopType.DOTA_SHOP_SECRET, true) then
			courierCast(ctx, courier, "courier_go_to_secretshop")
		end
		return
	end
	local hasItems, hasStash = false, false
	for slot = 0, 5 do if NPC.GetItemByIndex(courier, slot) then hasItems = true end end
	for slot = 9, 14 do if NPC.GetItemByIndex(ctx.hero, slot) then hasStash = true end end
	local full = true
	for slot = 0, 8 do if not NPC.GetItemByIndex(ctx.hero, slot) then full = false; break end end
	if not full then ctx.shop.fullDeliveryAt = nil end
	if full and ctx.shop.fullDeliveryAt and ctx.now - ctx.shop.fullDeliveryAt > 3 then
		ctx.shop.status = "Delivery paused: inventory has no free slot"
		if hasItems then courierCast(ctx, courier, "courier_return_stash_items") end
		return
	end
	if hasStash and not hasItems then
		courierCast(ctx, courier, "courier_take_stash_items")
	elseif hasItems and Entity.IsAlive(ctx.hero) and (not ctx.retreating or ctx.recoveryTask and ctx.recoveryTask.phase == "regen") then
		if full then ctx.shop.fullDeliveryAt = ctx.shop.fullDeliveryAt or ctx.now end
		courierCast(ctx, courier, "courier_transfer_items")
	end
end

local function complete(ctx, name)
	local state = ctx.shop
	state.completed[name] = true
	state.startedGoal, state.pending = nil, nil
	state.secretShopping = false
	state.index = state.index + 1
	if state.deferredPlan then
		state.plan, state.source, state.index = state.deferredPlan, state.deferredSource, 1
		state.deferredPlan, state.deferredSource = nil, nil
	end
	saveProgress(ctx)
end

local function goldSpent(ctx)
	local data = Player.GetTeamPlayer(ctx.player)
	return data and (data.gold_spent_on_items or 0) + (data.gold_spent_on_consumables or 0) or nil
end

function shop.pending(ctx, inventory)
	local state, pending = ctx.shop, ctx.shop.pending
	if not pending then return false end
	if ctx.planner.componentCount(state.items, inventory, pending.name) > pending.count
		or ctx.planner.owns(state.items, inventory, pending.goal) then state.pending = nil; return false end
	if pending.cost > 0 then
		local spentNow = goldSpent(ctx)
		if spentNow and pending.spentGold and spentNow > pending.spentGold
			or Player.GetTotalGold(ctx.player) < pending.gold - pending.cost * 0.5 then pending.spent = true end
	end
	local wait = pending.spent and 120 or 8
	if ctx.now - pending.time < wait then
		state.status = (pending.spent and "Await paid item delivery: " or "Confirm purchase: ") .. pending.name
		shop.courier(ctx, false)
		return true
	end
	if pending.spent then
		state.purchaseBlocked = state.purchaseBlocked or {}
		state.purchaseBlocked[pending.name] = ctx.now + 60
	end
	state.pending = nil
	return false
end

function shop.run(ctx)
	applyCustom(ctx)
	shop.fetch(ctx)
	if not ctx.settings.buy then
		shop.courier(ctx, false)
		return
	end
	if ctx.now < ctx.shop.nextBuy then return end
	local state = ctx.shop
	state.nextBuy = ctx.now + cfg.buyInterval
	local _, entries = shop.inventory(ctx)
	if inventoryCleanup.run(ctx, entries) then return end
	shop.manageInventory(ctx)
	local inventory = shop.inventory(ctx)
	if shop.pending(ctx, inventory) then return end
	if ctx.settings.buildItems and ctx.settings.online and not state.protrackerRole and not (state.guide and state.guide.groups)
		and ctx.now < state.buildWaitUntil then
		state.status = "Loading hero build"
		shop.courier(ctx, false)
		return
	end
	if supply(ctx, inventory) then shop.courier(ctx, state.secretShopping); return end
	if not ctx.settings.buildItems then
		state.status = "Manual build: bot buys supplies only"
		shop.courier(ctx, false)
		return
	end
	local name = state.plan[state.index]
	while name and (state.completed[name] or ctx.planner.owns(ctx.shop.items, inventory, name)) do
		complete(ctx, name)
		name = state.plan[state.index]
	end
	if not name then
		state.status = "Build complete"
		shop.courier(ctx, false)
		return
	end
	local missing = ctx.planner.missing(ctx.shop.items, name, inventory)
	if not missing then
		state.status = "Unsupported recipe: " .. name
		complete(ctx, name)
		return
	end
	local nextItem = missing[1]
	if not nextItem then
		state.status = "Waiting for assembly: " .. name
		shop.courier(ctx, false)
		return
	end
	if state.purchaseBlocked and (state.purchaseBlocked[nextItem] or 0) > ctx.now then
		state.status = "Purchase unresolved; wait before retry: " .. nextItem
		shop.courier(ctx, false)
		return
	end
	state.status = name .. " > " .. nextItem
	local kv = itemKV["item_" .. nextItem]
	if not kv then state.status = "Item unavailable in this game: " .. nextItem; complete(ctx, name); return end
	local cost, itemId = tonumber(kv.ItemCost or "0"), tonumber(kv.ID)
	local affordable = Player.GetTotalGold(ctx.player) >= cost
	local secret = kv.SecretShop == "1" and affordable and not NPC.IsInRangeOfShop(ctx.hero, Enum.ShopType.DOTA_SHOP_SECRET, true)
	state.secretShopping = secret
	shop.courier(ctx, secret)
	if not affordable then return end
	if outOfStock(nextItem, ctx.team) then
		state.status = "Out of stock: " .. nextItem
		if not state.stockWait then state.stockWait = ctx.now end
		if ctx.now - state.stockWait > 30 then complete(ctx, name); state.stockWait = nil end
		return
	end
	state.stockWait = nil
	local buyer = ctx.hero
	if secret then
		buyer = Couriers.GetLocal()
		if not buyer or not Entity.IsAlive(buyer) then state.status = "Waiting for courier: " .. nextItem; return end
		if not NPC.IsInRangeOfShop(buyer, Enum.ShopType.DOTA_SHOP_SECRET, true) then
			state.status = "Courier to secret shop: " .. nextItem
			return
		end
	end
	local free = false
	local firstSlot, lastSlot = 0, buyer == ctx.hero and 14 or 5
	if buyer == ctx.hero and not NPC.IsInRangeOfShop(ctx.hero, Enum.ShopType.DOTA_SHOP_HOME, true) then firstSlot = 9 end
	for slot = firstSlot, lastSlot do if not NPC.GetItemByIndex(buyer, slot) then free = true; break end end
	if not free then state.status = "Inventory full; waiting for space"; return end
	if state.quickBuy ~= name then Engine.SetQuickBuy(name, true); state.quickBuy = name end

	local goldBefore = Player.GetTotalGold(ctx.player)
	Player.PrepareUnitOrders(ctx.player, Enum.UnitOrder.DOTA_UNIT_ORDER_PURCHASE_ITEM, itemId, Vector(0, 0, 0), itemId,
		Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, buyer, false, false, false, true, "self_play_purchase", false)
	state.startedGoal = name
	state.pending = {name = nextItem, goal = name, count = ctx.planner.componentCount(state.items, inventory, nextItem), time = ctx.now,
		gold = goldBefore, cost = cost, spentGold = goldSpent(ctx)}
	if ctx.ui and ctx.ui.debug and ctx.ui.debug:Get() then
		Log.Write(string.format("[SelfPlay shop] buy order=%s need=%s gold=%d buyer=%s have=%d", name, nextItem, goldBefore,
			buyer == ctx.hero and "hero" or "courier", ctx.planner.componentCount(state.items, inventory, nextItem)))
	end
end

return shop
