local selfPlay = {}

local catalog = require("self_play.catalog")
local planner = require("self_play.planner")
local combat = require("self_play.combat")
local shop = require("self_play.shop")
local lastHit = require("self_play.last_hit")
local consumables = require("self_play.consumables")
local objectives = require("self_play.objectives")
local positioning = require("self_play.positioning")
local intent = require("self_play.intent")
local laneRules = require("self_play.lane_rules")
local recovery = require("self_play.recovery")
local runes = require("self_play.runes")
local heroModules = require("self_play.heroes.registry")
local towerSafety = require("self_play.tower_safety")
local navigation = require("self_play.navigation")
local engagement = require("self_play.engagement")
local teamplay = require("self_play.teamplay")
local helpRotation = require("self_play.help_rotation")
local supportPolicy = require("self_play.support_policy")
local fights = require("self_play.fights")
local awareness = require("self_play.awareness")
local neutralItems = require("self_play.neutral_items")
local jungle = require("self_play.jungle")
local baseDefense = require("self_play.base_defense")
local teleports = require("self_play.teleports")
local deward = require("self_play.deward")
local detection = require("self_play.detection")
local supportCamps = require("self_play.support_camps")
local unitControl = require("self_play.units")
local camera = require("self_play.camera")
local matchmaking = require("self_play.matchmaking")
local draft = require("self_play.draft")
local localization = require("self_play.localization")
local taskPolicy = require("self_play.task_policy")
local mapFarm = require("self_play.map_farm")
local laneRotation = require("self_play.lane_rotation")
local persist = require("self_play.persist")
local heroPolicy = require("self_play.hero_policy")

local excuses = require("self_play.excuses")

local cfg = {
	buy = true, online = true, level = true, talents = true, spells = true, block = true, pull = true,
	wards = true, units = true, objectives = true, retreatHealth = 32, manaReserve = 22,
	blockLater = true, blockRanged = true, teleport = true, buyback = true, dodge = true, buildItems = true,
	customBuilds = false, customHero = "", customItems = "",
	tick = 0.025, scanInterval = 0.12, moveInterval = 0.08, manualPause = 4,
	laneEnd = 600, blockEnd = 45, memoryLifetime = 6,
	turboLaneEnd = 360, turboBlockEnd = 30,
	fountainHealth = 0.68, fountainMana = 0.45, fountainHoldTimeout = 3, fountainEnter = 0.5,
	creepFallback = true, laneDiscipline = true, carryHoldLane = true, turboHunt = true,
	watchdogTime = 5, riverExit = true, roleSnap = true, loneSoak = true, laneRotation = true, ditherLock = true, humanizer = true,
	coexist = false, confidence = 0.5,
	autoStack = true,
	home = {[2] = Vector(-7200, -6600, 256), [3] = Vector(7100, 6500, 256)},
	anchors = {
		[2] = {Vector(-5800, 1400, 128), Vector(-850, -700, 128), Vector(1700, -5900, 128)},
		[3] = {Vector(-1600, 5800, 128), Vector(600, 560, 128), Vector(5800, -1600, 128)},
	},
	lanes = {"top", "mid", "bot"},
}

local ui, renderContext
local reconnectState = {nextAttempt = 0, attempts = 0}
do
	local tab = localization.group(Menu.Create("Scripts", "Self Play", "Main"))
	local page = tab:Create("Bot")
	local general = page:Create("Control", Enum.GroupSide.Left)
	ui = {
		enabled = general:Switch("Enabled", false),
		pause = general:Bind("Pause while held", Enum.ButtonCode.KEY_SPACE),
		role = general:Combo("Role", {"Auto", "1 Carry", "2 Mid", "3 Offlane", "4 Soft support", "5 Hard support"}, 0),
		lane = general:Combo("Lane", {"Auto", "Top", "Mid", "Bottom"}, 0),
		draw = general:Switch("Show status", true),
		camera = general:Switch("Follow hero camera", true),
		debug = general:Switch("Write decision diagnostics", false),
	}
	do
		local saved = persist.load()
		if saved.role > 0 then ui.role:Set(saved.role) end
		ui.lane:Set(0)
		ui.role:SetCallback(function() persist.save(ui.role:Get(), nil, nil) end)
		ui.lane:SetCallback(function(widget)
			if widget:Get() ~= 0 then widget:Set(0) end
			persist.save(nil, 0, nil)
		end)
		ui.lane:Disabled(true)
	end
	local automation = tab:Create("Queue and draft")
	ui.matchmaking = matchmaking.create(automation:Create("Matchmaking", Enum.GroupSide.Left))
	ui.draft = draft.create(automation:Create("Hero selection", Enum.GroupSide.Right))
	ui.draft.onRoleChanged = function(role)
		ui.role:Set(role)
		ui.lane:Set(0)
		persist.save(role, 0, nil)
	end
	ui.excuses = excuses.create(tab:Create("Excuses"))
	local behaviors = tab:Create("Behaviors")
	ui.behaviors, ui.groups = {}, {}
	for _, section in ipairs({
		{"Combat and control", Enum.GroupSide.Left, {
			{"spells", "Abilities, active items and consumables"},
			{"level", "Learn abilities and talents"},
			{"units", "Control summoned units"},
			{"dodge", "Dodge projectiles with movement"},
			{"coexist", "Ignore orders from other scripts"},
		}},
		{"Lane and support", Enum.GroupSide.Right, {
			{"block", "Creep blocking"},
			{"blockLater", "Block later waves"},
			{"blockRanged", "Include ranged creeps when blocking"},
			{"pull", "Stack and pull camps"},
			{"wards", "Warding and dewarding"},
			{"objectives", "Collect lotus and wisdom"},
		}},
		{"Economy and travel", Enum.GroupSide.Left, {
			{"buy", "Buy items and manage courier"},
			{"buildItems", "Buy items from the build guide"},
			{"online", "Fetch online builds"},
			{"buyback", "Use buyback"},
			{"teleport", "Use hero TP scrolls"},
		}},
	}) do
		local group = behaviors:Create(section[1], section[2])
		ui.groups[section[1]] = group
		for _, entry in ipairs(section[3]) do
			local key = entry[1]
			ui.behaviors[key] = group:Switch(entry[2], cfg[key])
			cfg[key] = ui.behaviors[key]:Get()
		end
	end
	do
		local group = ui.groups["Economy and travel"]
		ui.fountainEnter = group:Slider("Fountain health %", 0, 100, math.floor(cfg.fountainEnter * 100), "%d%%")
		ui.fountainEnter:SetCallback(function(widget) cfg.fountainEnter = widget:Get() / 100 end, true)
	end
	do
		local group = ui.groups["Combat and control"]
		ui.confidence = group:Slider("Confidence", 0, 100, math.floor(cfg.confidence * 100), "%d%%")
		ui.confidence:SetCallback(function(widget) cfg.confidence = widget:Get() / 100 end, true)
	end
	do
		local userBuilds = require("self_play.user_builds")
		local editor = {hero = nil, items = {}, order = {}, buildId = nil, dirty = false, armed = nil}
		local build = {}
		local JSON = require("assets.JSON")
		local refreshMyBuilds
		ui.custom = editor
		local custom = tab:Create("Create custom build")
		local left = custom:Create("Hero and builds", Enum.GroupSide.Left)
		local right = custom:Create("Item editor", Enum.GroupSide.Right)
		ui.behaviors.customBuilds = left:Switch("Use custom builds", cfg.customBuilds)
		cfg.customBuilds = ui.behaviors.customBuilds:Get()

		local heroNames, itemNames, heroTitles, itemTitles, itemRecords, busy = {}, {}, {}, {}, {}, false
		local itemKV = XHelpers.xkv:GetKV("items").DOTAAbilities
		for hero in pairs(catalog.heroes) do heroNames[#heroNames + 1] = hero end
		table.sort(heroNames)
		for name in pairs(catalog.items) do itemNames[#itemNames + 1] = name end
		for name, record in pairs(itemKV) do
			local key = name:gsub("^item_", "")
			if type(record) == "table" and tonumber(record.ID or "0") > 0 and catalog.items[key] == nil then
				itemNames[#itemNames + 1] = key
			end
		end
		table.sort(itemNames)
		for _, hero in ipairs(heroNames) do
			local title = GameLocalizer.FindNPC(hero)
			heroTitles[hero] = title ~= "" and title or draft.prettyName(hero)
		end
		for _, name in ipairs(itemNames) do
			local title = GameLocalizer.FindItem("item_" .. name)
			itemTitles[name] = title ~= "" and title or draft.prettyName(name)
		end
		itemRecords = planner.gameItems(catalog.items, itemKV)

		local function itemTitle(name)
			local record = itemRecords[name]
			local title = itemTitles[name]
			local cost = record and record.cost or 0
			local flag = (record and record.recipe or name:sub(1, 7) == "recipe_") and localization.text("recipe")
				or record and record.neutral and localization.text("neutral")
				or record and record.purchasable == false and localization.text("not buyable")
				or record and record.consumable and localization.text("consumable")
				or record and record.secret and localization.text("secret") or ""
			if record and record.limit and record.limit > 0 then flag = flag ~= "" and flag .. ", " or ""
				flag = flag .. localization.text("limit") .. " " .. record.limit end
			return title .. " (" .. cost .. (flag ~= "" and ", " .. flag or "") .. ")"
		end

		ui.customHeroSearch = left:Input("Hero search", "")
		ui.customHeroList = left:MultiSelect("Hero list", {})
		ui.customHeroList:OneItemSelection(true)
		ui.customBuildName = left:Input("Build name", "Custom")
		ui.customBuildList = left:MultiSelect("Saved builds", {})
		ui.customBuildList:OneItemSelection(true)
		ui.customBuildInfo = left:Label("Build info")
		left:Button("Finish custom build", function() build.onBuildFinish() end)
		left:Button("Use saved build", function() build.onBuildUse() end)
		left:Button("Copy build", function() build.onBuildCopy() end)
		left:Button("Rename build", function() build.onBuildRename() end)
		left:Button("Delete build", function() build.onBuildDelete() end)
		ui.customItemSearch = right:Input("Item search", "")
		ui.customItemList = right:MultiSelect("Item list", {})
		ui.customItems = right:MultiSelect("Build items", {})
		ui.customItems:DragAllowed(true)
		right:Button("Move up", function() build.onBuildMove(-1) end)
		right:Button("Move down", function() build.onBuildMove(1) end)
		right:Button("Remove selected", function() build.onBuildRemove() end)
		right:Button("Clear build", function() build.onBuildClear() end)
		right:Button("Save build", function() build.onBuildSave() end)
		right:Button("Export builds", function() build.onBuildExport() end)
		ui.customTransfer = right:Input("Build transfer", "")
		right:Button("Import builds", function() build.onBuildImport() end)

		local function refreshHeroes()
			local query = ui.customHeroSearch:Get():lower():gsub("%s", "")
			local entries, keys, used = {}, {}, {}
			for _, hero in ipairs(heroNames) do
				local short = draft.prettyName(hero)
				local title = heroTitles[hero]
				if query == "" or short:lower():find(query, 1, true) or title:lower():find(query, 1, true) then
					local label = title .. " · " .. short
					used[label] = (used[label] or 0) + 1
					if used[label] > 1 then label = label .. " #" .. used[label] end
					keys[label] = hero
					entries[#entries + 1] = {label, "panorama/images/heroes/icons/" .. hero .. "_png.vtex_c", false}
				end
			end
			editor.heroKeys = keys
			ui.customHeroList:Update(entries, true)
		end

		local function refreshItems()
			local query = ui.customItemSearch:Get():lower():gsub("%s", "")
			local entries, keys, used = {}, {}, {}
			for _, name in ipairs(itemNames) do
				local short = draft.prettyName(name)
				local title = itemTitles[name]
				if query == "" or short:lower():find(query, 1, true) or title:lower():find(query, 1, true) then
					local label = itemTitle(name)
					used[label] = (used[label] or 0) + 1
					if used[label] > 1 then label = label .. " #" .. used[label] end
					keys[label] = name
					entries[#entries + 1] = {label, "panorama/images/items/" .. name .. "_png.vtex_c", false}
				end
			end
			editor.itemKeys = keys
			ui.customItemList:Update(entries, true)
		end

		local function refreshBuild()
			local entries, order, seen, total = {}, {}, {}, 0
			for _, name in ipairs(editor.items) do
				seen[name] = (seen[name] or 0) + 1
				local label = itemTitle(name) .. (seen[name] > 1 and " #" .. seen[name] or "")
				order[label] = name
				entries[#entries + 1] = {label, "panorama/images/items/" .. name .. "_png.vtex_c", false}
				total = total + ((itemRecords[name] and itemRecords[name].cost) or 0)
			end
			editor.order = order
			ui.customItems:Update(entries, true)
			ui.customItems:DragAllowed(true)
			ui.customBuildInfo:ForceLocalization(string.format("%s: %d · %d",
				localization.text("Build info"), #editor.items, total))
		end

		local function refreshBuilds()
			local hero = editor.hero or ""
			local current = userBuilds.active(hero)
			local entries, checked, keys, used = {}, {}, {}, {}
			for _, record in ipairs(userBuilds.forHero(hero)) do
				local label = (current == record.id and "* " or "") .. record.name
				used[label] = (used[label] or 0) + 1
				if used[label] > 1 then label = label .. " #" .. used[label] end
				keys[label] = record.id
				entries[#entries + 1] = {label, "panorama/images/heroes/icons/" .. record.hero .. "_png.vtex_c", false}
				if record.id == editor.buildId or (not editor.buildId and record.id == current) then checked[#checked + 1] = label end
			end
			editor.buildKeys = keys
			ui.customBuildList:Update(entries, true)
			if #checked > 0 and not busy then
				busy = true
				ui.customBuildList:Set({checked[1]})
				busy = false
			end
		end

		local function loadHero(hero, keepName)
			editor.hero = hero
			local active = hero and userBuilds.active(hero) or nil
			local list = hero and userBuilds.forHero(hero) or {}
			local entry = active and userBuilds.get(active) or list[1]
			editor.buildId = entry and entry.id or nil
			editor.items = entry and userBuilds.items(entry.id) or {}
			editor.dirty = false
			if entry and not keepName then ui.customBuildName:Set(entry.name) end
			refreshBuilds()
			refreshBuild()
		end

		local function checkedHero()
			local selected = ui.customHeroList:ListEnabled()[1]
			return selected and editor.heroKeys and editor.heroKeys[selected] or nil
		end

		local function checkedBuild()
			local selected = ui.customBuildList:ListEnabled()[1]
			if not selected or not editor.buildKeys then return nil end
			return editor.buildKeys[selected]
		end

		local function info(text)
			editor.armed = nil
			ui.customBuildInfo:ForceLocalization(text)
		end

		local function blockDirty()
			if not editor.dirty then return false end
			ui.customBuildInfo:ForceLocalization(localization.text("Unsaved changes: press Finish custom build first"))
			return true
		end

		local function requireHero()
			local hero = checkedHero() or editor.hero
			if not hero then
				ui.customBuildInfo:ForceLocalization(localization.text("Pick a hero first"))
				return nil
			end
			if hero ~= editor.hero then loadHero(hero) end
			return hero
		end

		build.onBuildFinish = function()
			local hero = requireHero()
			if not hero then return end
			local name = ui.customBuildName:Get()
			if name == nil or name == "" then
				info(localization.text("Give the build a name first"))
				return
			end
			if #editor.items == 0 then
				info(localization.text("Add at least one item first"))
				return
			end
			local saved
			if editor.buildId and userBuilds.get(editor.buildId) then
				if not userBuilds.rename(editor.buildId, name) then return end
				userBuilds.update(editor.buildId, editor.items)
				saved = editor.buildId
				info(localization.text("Build updated"))
			else
				saved = userBuilds.create(hero, name, editor.items)
				if not saved then
					info(localization.text("Could not save the build"))
					return
				end
				info(localization.text("Build created"))
			end
			editor.buildId, editor.dirty = saved, false
			local record = userBuilds.get(saved)
			info(string.format("%s: %s · %s", localization.text("Saved"), heroTitles[hero] or hero, record and record.name or name))
			refreshBuilds()
			refreshBuild()
			refreshMyBuilds()
		end

		build.onBuildUse = function()
			local hero = requireHero()
			local id = editor.buildId or checkedBuild()
			if not hero or not id then
				info(localization.text("Finish a build first"))
				return
			end
			if not userBuilds.setActive(hero, id) then return end
			ui.customBuildName:Set(userBuilds.get(id).name)
			refreshBuilds()
			refreshMyBuilds()
			info(localization.text("Build is now active"))
		end

		build.onBuildCopy = function()
			local hero = requireHero()
			local from = editor.buildId or checkedBuild()
			if not hero or not from then return end
			local record = userBuilds.get(from)
			local name = ui.customBuildName:Get()
			if name == "" or name == record.name then name = record.name .. " copy" end
			local copy = userBuilds.copy(from, name)
			if not copy then
				info(localization.text("Could not copy the build"))
				return
			end
			editor.buildId, editor.dirty = nil, true
			ui.customBuildName:Set(name)
			refreshBuilds()
			refreshMyBuilds()
			info(localization.text("Build copied"))
		end

		build.onBuildRename = function()
			local hero = requireHero()
			local id = editor.buildId or checkedBuild()
			local name = ui.customBuildName:Get()
			if not hero or not id or name == "" then
				info(localization.text("Finish a build first"))
				return
			end
			if not userBuilds.rename(id, name) then return end
			refreshBuilds()
			refreshMyBuilds()
			info(localization.text("Build renamed"))
		end

		build.onBuildDelete = function()
			local hero = requireHero()
			local id = editor.buildId or checkedBuild()
			if not hero or not id then return end
			if editor.armed ~= id then
				editor.armed = id
				ui.customBuildInfo:ForceLocalization(localization.text("Press Delete build again to confirm"))
				return
			end
			userBuilds.remove(id)
			editor.buildId, editor.dirty, editor.armed = nil, false, nil
			editor.items = {}
			ui.customBuildName:Set("")
			refreshBuilds()
			refreshBuild()
			refreshMyBuilds()
			info(localization.text("Build deleted"))
		end

		build.onBuildMove = function(step)
			local selected = ui.customItems:ListEnabled()
			if #selected == 0 then
				ui.customBuildInfo:ForceLocalization(localization.text("Nothing to move"))
				return
			end
			local moving = {}
			for _, label in ipairs(selected) do moving[label] = true end
			local labels, items = {}, {}
			for index, label in ipairs(ui.customItems:List()) do
				local item = editor.order[label]
				if item then labels[index], items[index] = label, item end
			end
			if step < 0 then
				for index = 2, #items do
					if moving[labels[index]] and not moving[labels[index - 1]] then
						items[index - 1], items[index] = items[index], items[index - 1]
						labels[index - 1], labels[index] = labels[index], labels[index - 1]
					end
				end
			else
				for index = #items - 1, 1, -1 do
					if moving[labels[index]] and not moving[labels[index + 1]] then
						items[index + 1], items[index] = items[index], items[index + 1]
						labels[index + 1], labels[index] = labels[index], labels[index + 1]
					end
				end
			end
			editor.items, editor.dirty = items, true
			editor.armed = nil
			refreshBuild()
		end

		build.onBuildRemove = function()
			local remove = {}
			for _, label in ipairs(ui.customItems:ListEnabled()) do remove[label] = true end
			if next(remove) == nil then
				ui.customBuildInfo:ForceLocalization(localization.text("Nothing selected"))
				return
			end
			local keep = {}
			for index, entry in ipairs(ui.customItems:List()) do
				if not remove[entry] then keep[#keep + 1] = editor.order[entry] end
			end
			editor.items, editor.dirty = keep, true
			editor.armed = nil
			refreshBuild()
		end

		build.onBuildClear = function()
			editor.items, editor.dirty, editor.armed = {}, true, nil
			refreshBuild()
		end

		build.onBuildExport = function()
			ui.customTransfer:Set(userBuilds.export())
			info(localization.text("Builds exported to the transfer field"))
		end

		build.onBuildImport = function()
			if userBuilds.import(ui.customTransfer:Get()) then
				loadHero(editor.hero, true)
				refreshMyBuilds()
				info(localization.text("Builds imported"))
			else
				info(localization.text("Transfer data is broken"))
			end
		end

		ui.customHeroSearch:SetCallback(function() refreshHeroes() end, true)
		ui.customItemSearch:SetCallback(function() refreshItems() end, true)
		ui.customHeroList:SetCallback(function()
			local hero = checkedHero()
			if not hero or hero == editor.hero then return end
			if blockDirty() then return end
			loadHero(hero)
		end)
		ui.customBuildList:SetCallback(function()
			if busy then return end
			local hero = editor.hero
			local id = checkedBuild()
			if not hero or not id or id == editor.buildId then return end
			if blockDirty() then return end
			local record = userBuilds.get(id)
			editor.buildId, editor.dirty = id, false
			editor.items = userBuilds.items(id)
			ui.customBuildName:Set(record and record.name or "")
			refreshBuild()
		end)
		ui.customItemList:SetCallback(function()
			local selected = {}
			for _, label in ipairs(ui.customItemList:ListEnabled()) do
				if editor.itemKeys[label] then selected[#selected + 1] = editor.itemKeys[label] end
			end
			for _, name in ipairs(selected) do editor.items[#editor.items + 1] = name end
			if #selected > 0 then
				busy = true
				ui.customItemList:Set({})
				busy = false
			end
			editor.dirty = #editor.items > 0
			editor.armed = nil
			refreshBuild()
		end)
		ui.customItems:SetCallback(function()
			local keep = {}
			for _, label in ipairs(ui.customItems:List()) do
				if editor.order[label] then keep[#keep + 1] = editor.order[label] end
			end
			if #keep > 0 and #keep ~= #editor.items then editor.items, editor.dirty = keep, true end
		end)

		do
			local mine = tab:Create("My Builds")
			local group = mine:Create("My Builds", Enum.GroupSide.Left)
			local list = {label = {}, id = {}, armed = nil}
			ui.myBuilds = list
			ui.mySearch = group:Input("My builds search", "")
			ui.myHeroFilter = group:Combo("My builds hero filter", {"All heroes"}, 0)
			ui.myList = group:MultiSelect("My builds list", {})
			ui.myList:OneItemSelection(true)
			ui.myContents = group:MultiSelect("My builds contents", {})
			ui.myInfo = group:Label("My builds info")
			group:Button("Use build", function() list.action("use") end)
			group:Button("Edit build", function() list.action("edit") end)
			group:Button("Copy build", function() list.action("copy") end)
			group:Button("Rename build", function() list.action("rename") end)
			group:Button("Delete build", function() list.action("delete") end)
			group:Button("Export build", function() list.action("export") end)

			local function cost(name)
				local record = itemRecords[name]
				return record and record.cost or 0
			end

			local function total(items)
				local sum = 0
				for _, name in ipairs(items) do sum = sum + cost(name) end
				return sum
			end

			local function statusOf(record)
				return userBuilds.active(record.hero) == record.id and localization.text("active")
					or localization.text("saved")
			end

			local function matches(record, query)
				if query == "" then return true end
				if draft.prettyName(record.hero):lower():find(query, 1, true) then return true end
				if (heroTitles[record.hero] or ""):lower():find(query, 1, true) then return true end
				if record.name:lower():find(query, 1, true) then return true end
				for _, name in ipairs(userBuilds.items(record.id)) do
					if (itemTitles[name] or name):lower():find(query, 1, true) then return true end
				end
				return false
			end

			local function heroFilter()
				local value = ui.myHeroFilter:Get() or 0
				return value > 0 and userBuilds.heroes()[value] or nil
			end

			local function refreshContents()
				local entries, problems, brief = {}, {}, {}
				local id = list.selected
				local record = id and userBuilds.get(id) or nil
				busy = true
				if not record then
					ui.myContents:Update({}, true)
					busy = false
				ui.myInfo:ForceLocalization(localization.text("Pick a build to see its items"))
				return
				end
				for index, name in ipairs(userBuilds.items(id)) do
					local record2 = itemRecords[name]
					if not record2 then
						problems[#problems + 1] = name
					elseif record2.purchasable == false or record2.neutral then
						problems[#problems + 1] = itemTitles[name] or name
					end
					if index <= 3 then brief[#brief + 1] = itemTitles[name] or name end
					entries[#entries + 1] = {index .. ". " .. itemTitle(name),
						"panorama/images/items/" .. name .. "_png.vtex_c", true}
				end
				ui.myContents:Update(entries, true)
				busy = false
				local text = string.format("%s: %s · %s · %d %s · %d", localization.text("Build"), heroTitles[record.hero] or record.hero,
					record.name, #userBuilds.items(id), localization.text("items"), total(userBuilds.items(id)))
				local stamp = userBuilds.stamp(id)
				if stamp ~= "" then text = text .. " · " .. stamp end
				if #entries > 0 then
					text = text .. " · " .. table.concat(brief, ", ")
					if #entries > 3 then text = text .. " +" .. (#entries - 3) end
				end
				if #problems > 0 then
					text = text .. " · " .. localization.text("cannot buy") .. ": " .. table.concat(problems, ", ")
				end
				ui.myInfo:ForceLocalization(text)
			end

			refreshMyBuilds = function()
				local query = ui.mySearch:Get():lower():gsub("%s", "")
				local only = heroFilter()
				local options, filter = {"All heroes"}, 0
				for index, hero in ipairs(userBuilds.heroes()) do
					options[#options + 1] = heroTitles[hero] or draft.prettyName(hero)
					if only == hero then filter = index end
				end
				ui.myHeroFilter:Update(options, filter)
				local entries, keys, selected = {}, {}, nil
				local used = {}
				for _, record in ipairs(userBuilds.all()) do
					if (not only or record.hero == only) and matches(record, query) then
						local items = userBuilds.items(record.id)
						local label = string.format("%s · %s · %d %s · %d · %s", heroTitles[record.hero] or draft.prettyName(record.hero),
							record.name, #items, localization.text("items"), total(items), statusOf(record))
						used[label] = (used[label] or 0) + 1
						if used[label] > 1 then label = label .. " #" .. used[label] end
						keys[label] = record.id
						entries[#entries + 1] = {label, "panorama/images/heroes/icons/" .. record.hero .. "_png.vtex_c", false}
						if record.id == list.selected then selected = label end
					end
				end
				list.label = keys
				busy = true
				ui.myList:Update(entries, true)
				busy = false
				if selected and not busy then
					busy = true
					ui.myList:Set({selected})
					busy = false
				end
				refreshContents()
			end

			local function requireBuild()
				local id = list.selected
				if not id or not userBuilds.get(id) then
					ui.myInfo:ForceLocalization(localization.text("Pick a build first"))
					return nil
				end
				return id
			end

			local function announce(text)
				list.armed = nil
				ui.myInfo:ForceLocalization(text)
				refreshContents()
			end

			list.action = function(action)
				local id = requireBuild()
				if not id then return end
				local record = userBuilds.get(id)
				if action == "use" then
					if not userBuilds.setActive(record.hero, id) then return end
					if editor.hero == record.hero then
						editor.buildId = id
						ui.customBuildName:Set(record.name)
						refreshBuilds()
					end
					refreshMyBuilds()
					announce(localization.text("Build is now active"))
				elseif action == "edit" then
					if blockDirty() then return end
					editor.hero, editor.buildId, editor.dirty = record.hero, id, false
					editor.items = userBuilds.items(id)
					ui.customBuildName:Set(record.name)
					ui.customHeroSearch:Set("")
					refreshHeroes()
					local target
					for label, hero in pairs(editor.heroKeys or {}) do
						if hero == record.hero then target = label; break end
					end
					if target and not busy then
						busy = true
						ui.customHeroList:Set({target})
						busy = false
					end
					refreshBuilds()
					refreshBuild()
					announce(localization.text("Build loaded into the editor"))
				elseif action == "copy" then
					local copy = userBuilds.copy(id, record.name .. " copy")
					if not copy then return end
					refreshMyBuilds()
					announce(localization.text("Build copied"))
				elseif action == "rename" then
					local name = ui.customBuildName:Get()
					if name == "" then
						announce(localization.text("Type a new name in the build name field"))
						return
					end
					if not userBuilds.rename(id, name) then return end
					if editor.buildId == id then ui.customBuildName:Set(name) end
					refreshBuilds()
					refreshMyBuilds()
					announce(localization.text("Build renamed"))
				elseif action == "delete" then
					if list.armed ~= id then
						list.armed = id
						ui.myInfo:ForceLocalization(localization.text("Press Delete build again to confirm"))
						return
					end
					userBuilds.remove(id)
					if editor.buildId == id then
						editor.buildId, editor.dirty, editor.items = nil, false, {}
						ui.customBuildName:Set("")
						refreshBuilds()
						refreshBuild()
					end
					list.selected = nil
					refreshMyBuilds()
					announce(localization.text("Build deleted"))
				elseif action == "export" then
					local payload = JSON:encode({version = 2, nextId = 1, builds = {{
						id = record.id, hero = record.hero, name = record.name, items = record.items,
						updated = record.updated, active = record.active}}})
					ui.customTransfer:Set(payload)
					announce(localization.text("Build exported to the transfer field"))
				end
			end

			ui.mySearch:SetCallback(function() refreshMyBuilds() end, true)
			ui.myHeroFilter:SetCallback(function() refreshMyBuilds() end)
			ui.myList:SetCallback(function()
				if busy then return end
				local selected = ui.myList:ListEnabled()[1]
				list.selected = selected and list.label and list.label[selected] or nil
				list.armed = nil
				refreshContents()
				local record = list.selected and userBuilds.get(list.selected) or nil
				if record then
					ui.myInfo:ForceLocalization(localization.text("Loaded: ") .. record.name)
					ui.customTransfer:Set(record.items)
				end
			end)
			localization.listen(function()
				refreshHeroes()
				refreshItems()
				refreshBuilds()
				refreshBuild()
				refreshMyBuilds()
			end)
		end
	end
	renderContext = {font = Render.LoadFont("Tahoma", Enum.FontCreate.FONTFLAG_ANTIALIAS, 500)}
	localization.init()
end

local state = {ctx = nil}
local helpers, core = {}, {}

function helpers.settings()
	for key, control in pairs(ui.behaviors) do
		local enabled = control:Get()
		if cfg[key] ~= enabled then
			cfg[key] = enabled
			local ctx = state.ctx
			if ctx and not enabled then
				if (key == "block" or key == "blockLater") and ctx.blockState and ctx.blockState.later then ctx.blockState = nil end
				if key == "pull" then ctx.campTask = nil end
				if key == "wards" then ctx.wardTask, ctx.dewardTask = nil, nil end
				if key == "objectives" then ctx.objectiveTask = nil end
				if key == "spells" then ctx.aimTask, ctx.spellFinish = nil, nil end
			end
		end
	end
end

function helpers.distance(a, b)
	local x, y = a.x - b.x, a.y - b.y
	return math.sqrt(x * x + y * y)
end

function helpers.clearance(point)
	local open = 0
	for _, offset in ipairs({{90, 0}, {-90, 0}, {0, 90}, {0, -90}}) do
		if GridNav.IsTraversable(Vector(point.x + offset[1], point.y + offset[2], point.z)) then open = open + 1 end
	end
	return open
end

function helpers.toward(a, b, distance)
	local length = helpers.distance(a, b)
	if length < 1 then return a end
	local fraction = math.min(1, distance / length)
	return Vector(a.x + (b.x - a.x) * fraction, a.y + (b.y - a.y) * fraction, a.z + (b.z - a.z) * fraction)
end

function helpers.valid(unit)
	return unit and Entity.IsEntity(unit) and Entity.IsAlive(unit) and not Entity.IsDormant(unit)
end

function helpers.visible(unit)
	return helpers.valid(unit) and NPC.IsVisible(unit)
end

function helpers.gameMode()
	if GameRules and GameRules.GetGameMode then
		local ok, mode = pcall(GameRules.GetGameMode)
		if ok and type(mode) == "number" then return mode end
	end
	return nil
end

function helpers.isTurbo()
	return helpers.gameMode() == 23
end

function helpers.laneEnd(ctx)
	if ctx and ctx.laneEnd then return ctx.laneEnd end
	return helpers.isTurbo() and cfg.turboLaneEnd or cfg.laneEnd
end

function helpers.blockEnd(ctx)
	if ctx and ctx.blockEnd then return ctx.blockEnd end
	return helpers.isTurbo() and cfg.turboBlockEnd or cfg.blockEnd
end

function helpers.laneGroups()
	if LaneGroupsManager and LaneGroupsManager.visible_ally then return LaneGroupsManager.visible_ally end
	return nil
end

function helpers.tierOneAlive(ctx, allySide, lane)
	local suffix = cfg.lanes[lane or ctx.homeLane or ctx.lane]
	if not suffix then return false end
	for _, tower in ipairs(ctx.towers or {}) do
		if helpers.valid(tower) and (Entity.IsSameTeam(tower, ctx.hero) == allySide)
			and NPC.GetUnitName(tower):find("tower1_" .. suffix, 1, true) then return true end
	end
	return false
end

function helpers.fullBuild(ctx)
	if ctx.shop and ctx.shop.plan and ctx.shop.index > #ctx.shop.plan then return true end
	for slot = 0, 5 do
		local item = NPC.GetItemByIndex(ctx.hero, slot)
		if not item then return false end
		local record = ctx.catalog.items[Ability.GetName(item):gsub("^item_", "")]
		if not record or record.consumable or (record.cost or 0) < 500 then return false end
	end
	return true
end

function helpers.laneLocked(ctx)
	if ctx.settings.laneDiscipline == false then return false end
	if ctx.clock >= helpers.laneEnd(ctx) then return false end
	if ctx.baseDefense then return false end
	return helpers.tierOneAlive(ctx, false, ctx.homeLane or ctx.lane)
end

function helpers.laneWaveAlive(ctx)
	for _, creep in ipairs((ctx.waves or {})[ctx.lane] or {}) do
		if helpers.valid(creep) then return true end
	end
	return false
end

function helpers.creepsUnfinished(ctx)
	for _, creep in ipairs(ctx.creeps or {}) do
		if helpers.visible(creep) and NPC.IsLaneCreep(creep)
			and helpers.distance(ctx.position, Entity.GetAbsOrigin(creep)) < 1100 then
			if Entity.IsSameTeam(ctx.hero, creep) then
				if laneRules.denyable(ctx.clock, Entity.GetHealth(creep), Entity.GetMaxHealth(creep),
					NPC.GetModifierProperty(creep, Enum.ModifierFunction.MODIFIER_PROPERTY_CREEP_DENY_PERCENT)) then return true end
			elseif laneRules.canLastHit(ctx, creep) then
				return true
			end
		end
	end
	return false
end

function helpers.riverExit(ctx, destination)
	if not destination then return nil end
	if helpers.distance(ctx.position, ctx.home) > 1300 then return nil end
	if helpers.distance(ctx.position, destination) < 3000 then return nil end
	local mid = helpers.toward(ctx.position, destination, helpers.distance(ctx.position, destination) * 0.5)
	local m = (mid.x + mid.y) * 0.5
	local point = Vector(m, m, World.GetGroundZ(m, m))
	if not GridNav.IsTraversable(point) or helpers.unsafePosition(ctx, point) then return nil end
	if helpers.distance(ctx.position, point) < 400 then return nil end
	if helpers.distance(point, destination) > helpers.distance(ctx.position, destination) - 300 then return nil end
	return point
end

function helpers.reset()
	if state.ctx then state.ctx.active = false end
	state.ctx = nil
end

function helpers.role(hero, team)
	if ui.draft.enabled:Get() then
		local pickedRole = draft.role(ui.role:Get())
		if pickedRole then return pickedRole end
	end
	if ui.role:Get() > 0 then return ui.role:Get() end
	local entries = {}
	for _, ally in ipairs(Heroes.GetAll()) do
		if Entity.GetTeamNum(ally) == team and not NPC.IsIllusion(ally) and not NPC.IsMeepoClone(ally) then
			entries[#entries + 1] = {id = Entity.GetIndex(ally), scores = planner.roleScores(catalog.heroes[NPC.GetUnitName(ally)])}
			if #entries == 5 then break end
		end
	end
	return planner.assignRoles(entries)[Entity.GetIndex(hero)] or 5
end

function helpers.lane(role, team)
	if ui.lane:Get() > 0 then return ui.lane:Get() end
	if role == 2 then return 2 end
	local safe = team == 2 and 3 or 1
	return (role == 1 or role == 5) and safe or 4 - safe
end

function helpers.naturalRole(heroName)
	local entry = catalog.heroes[heroName]
	if not entry then return nil end
	local scores = planner.roleScores(entry)
	local best, bestScore = nil, -math.huge
	for role = 1, 5 do if scores[role] > bestScore then best, bestScore = role, scores[role] end end
	return best
end

function helpers.snapRole(hero, role)
	if cfg.roleSnap == false or ui.role:Get() ~= 0 then return role end
	local natural = helpers.naturalRole(NPC.GetUnitName(hero))
	if natural and natural ~= role then
		return role
	end
	return role
end

function helpers.init(hero, player)
	local team = Entity.GetTeamNum(hero)
	if team ~= 2 and team ~= 3 then return nil end
	local role = helpers.snapRole(hero, helpers.role(hero, team))
	local turbo = helpers.isTurbo()
	local lane = helpers.lane(role, team)
	local ctx = {
		hero = hero, heroName = NPC.GetUnitName(hero), player = player, playerId = Player.GetPlayerID(player),
		team = team, role = role, lane = lane, homeLane = lane, active = true,
		isTurbo = turbo, laneEnd = turbo and cfg.turboLaneEnd or cfg.laneEnd, blockEnd = turbo and cfg.turboBlockEnd or cfg.blockEnd,
		ui = ui, settings = cfg, catalog = catalog, planner = planner, home = cfg.home[team], enemyHome = cfg.home[5 - team],
		now = GameRules.GetGameTime(), clock = 0, nextTick = 0, nextScan = 0, nextMove = 0,
		busyUntil = 0, attackNext = 0, nextLevel = 0, pauseUntil = 0, nextUnits = 0, nextWard = 0, channelIdleSince = nil,
		mode = "Starting", lastAbility = "", history = {}, memory = {}, projectiles = {}, hazards = {}, abilityAttempts = {},
		allies = {}, enemies = {}, creeps = {}, neutrals = {}, towers = {}, structures = {}, summons = {},
		campAttempts = {}, roleSetting = ui.role:Get(), laneSetting = ui.lane:Get(),
		distance = helpers.distance, toward = helpers.toward, clearance = helpers.clearance,
	}
	ctx.position = Entity.GetAbsOrigin(hero)
	ctx.clock = GameRules.GetGameStartTime() > 0 and ctx.now - GameRules.GetGameStartTime() or -1
	ctx.unsafePosition = function(position) return helpers.unsafePosition(ctx, position) end
	ctx.countOrder = function()
		ctx.orders = (ctx.orders or 0) + 1
		if ctx.now - (ctx.apmSince or 0) >= 60 then
			ctx.apm, ctx.orders, ctx.apmSince = ctx.orders, 0, ctx.now
		end
	end
	ctx.predict = function(unit, delay) return helpers.predict(ctx, unit, delay) end
	ctx.move = function(position, mode, tolerance) return helpers.move(ctx, position, mode, false, tolerance) end
	ctx.stop = function() return helpers.stop(ctx) end
	ctx.attack = function(target, mode) return helpers.attack(ctx, target, mode) end
	ctx.pushSafe = function(target) return helpers.pushSafe(ctx, target) end
	ctx.teleport = function(position, purpose) return core.teleport(ctx, position, purpose) end
	ctx.fightAbilities = function() return heroModules.update(ctx, combat, false) or combat.run(ctx, false) end
	ctx.clearAbilities = function(units, defending) return combat.farm(ctx, units, defending) end
	lastHit.init(ctx)
	heroModules.attach(ctx)
	ctx.policy = heroPolicy.enrich(ctx)
	shop.init(ctx)
	persist.save(role, ctx.lane, ctx.heroName)
	persist.pushHistory(ctx.heroName, role)
	if ui.draft and ui.draft.historyRows then draft.paintHistory(ui.draft) end
	return ctx
end

function helpers.predict(ctx, unit, delay)
	if NPC.IsCreep(unit) or NPC.IsLaneCreep(unit) then return Entity.GetAbsOrigin(unit) end
	local record = ctx.history[Entity.GetIndex(unit)]
	local position = Entity.GetAbsOrigin(unit)
	if not record or not NPC.IsRunning(unit) then return position end
	return Vector(position.x + record.vx * delay, position.y + record.vy * delay, position.z)
end

function helpers.scan(ctx)
	ctx.allies, ctx.enemies, ctx.creeps, ctx.neutrals, ctx.summons = {}, {}, {}, {}, {}
	ctx.towers, ctx.structures = {}, {}
	ctx.waves, ctx.mapObjectives = {{}, {}, {}}, {}
	ctx.worldNPCs = NPCs.GetAll()
	for _, unit in ipairs(ctx.worldNPCs) do
		if helpers.valid(unit) and not NPC.IsWaitingToSpawn(unit) then
			local same = Entity.IsSameTeam(ctx.hero, unit)
			local visible = same or NPC.IsVisible(unit)
			local position = Entity.GetAbsOrigin(unit)
			if same and NPC.GetUnitName(unit) == "dota_fountain" then ctx.home, ctx.fountain = position, unit end
			local distance = helpers.distance(ctx.position, position)
			local name = NPC.GetUnitName(unit)
			if name == "npc_dota_lotus_pool" or name == "npc_dota_xp_fountain" then
				ctx.mapObjectives[#ctx.mapObjectives + 1] = unit
			end
			if same and NPC.IsLaneCreep(unit) then
				local lane = math.abs(position.x - position.y) < 2000 and 2 or position.y > position.x and 1 or 3
				ctx.waves[lane][#ctx.waves[lane] + 1] = unit
			end
			if NPC.IsTower(unit) and visible then ctx.towers[#ctx.towers + 1] = unit end
			if NPC.IsStructure(unit) and visible then ctx.structures[#ctx.structures + 1] = unit end
			if NPC.IsHero(unit) and not NPC.IsIllusion(unit) and not NPC.IsMeepoClone(unit) and visible then
				local list = same and ctx.allies or ctx.enemies
				list[#list + 1] = unit
			elseif visible and distance < 2400 then
				if NPC.IsLaneCreep(unit) then ctx.creeps[#ctx.creeps + 1] = unit
				elseif NPC.IsNeutral(unit) and NPC.IsCreep(unit) and not NPC.IsRoshan(unit) and not NPC.IsTormentor(unit) then
					ctx.neutrals[#ctx.neutrals + 1] = unit
				end
			end
			if unitControl.eligible(ctx, unit) then ctx.summons[#ctx.summons + 1] = unit end
		end
	end
	local heroes = Heroes.GetAll()
	awareness.observe(ctx, heroes)
	detection.observe(ctx, heroes)
	ctx.nextScan = ctx.now + cfg.scanInterval
end

function helpers.sample(ctx)
	for _, list in ipairs({ctx.creeps, ctx.enemies, ctx.allies}) do
		for _, unit in ipairs(list) do
			if helpers.visible(unit) then
				local id, position, health = Entity.GetIndex(unit), Entity.GetAbsOrigin(unit), Entity.GetHealth(unit)
				local old = ctx.history[id]
				local record = {time = ctx.now, health = health, position = position, rate = 0, vx = 0, vy = 0}
				if old and ctx.now > old.time then
					local dt = ctx.now - old.time
					local rate = math.max(0, (old.health - health) / dt)
					record.rate = old.rate * 0.65 + rate * 0.35
					if helpers.distance(position, old.position) < NPC.GetMoveSpeed(unit) * dt * 1.4 then
						record.vx, record.vy = (position.x - old.position.x) / dt, (position.y - old.position.y) / dt
					end
				end
				ctx.history[id] = record
			end
		end
	end
	for id, entry in pairs(ctx.history) do if ctx.now - entry.time > 3 then ctx.history[id] = nil end end
	for id, entry in pairs(ctx.memory) do if ctx.now - entry.time > cfg.memoryLifetime then ctx.memory[id] = nil end end
	for handle, entry in pairs(ctx.projectiles) do if entry.impact < ctx.now then ctx.projectiles[handle] = nil end end
	for handle, entry in pairs(ctx.hazards) do if entry.expires < ctx.now then ctx.hazards[handle] = nil end end
	for name, expiry in pairs(ctx.abilityAttempts) do if expiry < ctx.now then ctx.abilityAttempts[name] = nil end end
end

function helpers.unsafePosition(ctx, position)
	for _, tower in ipairs(ctx.towers) do
		if helpers.valid(tower) and not Entity.IsSameTeam(ctx.hero, tower) then
			local towerPosition, range = Entity.GetAbsOrigin(tower), NPC.GetAttackRange(tower)
			if helpers.distance(position, towerPosition) < range + 160 then
				if not towerSafety.position(ctx, tower, position) then return true end
			end
		end
	end
	return false
end

function helpers.threat(ctx)
	teleports.update(ctx)
	local allies, enemies, nearest, nearestDistance = 0, 0, nil, math.huge
	for _, ally in ipairs(ctx.allies) do
		if helpers.valid(ally) and helpers.distance(ctx.position, Entity.GetAbsOrigin(ally)) < 1100 then allies = allies + 1 end
	end
	for _, enemy in ipairs(ctx.enemies) do
		if helpers.visible(enemy) then
			local distance = helpers.distance(ctx.position, Entity.GetAbsOrigin(enemy))
			if distance < 1400 then enemies = enemies + 1 end
			if distance < nearestDistance then nearest, nearestDistance = enemy, distance end
		end
	end
	local health = Entity.GetHealth(ctx.hero) / math.max(1, Entity.GetMaxHealth(ctx.hero))
	local projectileDamage = 0
	for _, entry in pairs(ctx.projectiles) do
		if entry.target == ctx.hero and entry.impact > ctx.now and entry.impact < ctx.now + 1.5 then projectileDamage = projectileDamage + entry.damage end
	end
	local barriers = NPC.GetBarriers(ctx.hero)
	if barriers then projectileDamage = math.max(0, projectileDamage - barriers.all.current) end
	local towerAggro = false
	for _, tower in ipairs(ctx.towers) do
		if helpers.valid(tower) and not Entity.IsSameTeam(ctx.hero, tower) and Tower.GetAttackTarget(tower) == ctx.hero then towerAggro = true end
	end
	local remembered = 0
	for _, entry in pairs(ctx.memory) do
		if ctx.now - entry.time > cfg.scanInterval + 0.1 and ctx.now - entry.time < 4
			and helpers.distance(ctx.position, entry.position) < 1000 then remembered = remembered + 0.5 end
	end
	local losing = enemies + remembered + ctx.incomingEnemies > allies and nearestDistance < 900
	local hurt = Hero.GetRecentDamage(ctx.hero) > Entity.GetMaxHealth(ctx.hero) * 0.18
	ctx.nearEnemies, ctx.nearAllies = enemies + ctx.incomingEnemies, allies
	ctx.health = health
	awareness.update(ctx)
	fights.plan(ctx)
	local counterattack = baseDefense.prepare(ctx)
	local committed = intent.target(ctx)
	local attacker = ctx.laneThreat.attacked and ctx.laneThreat.enemy
	ctx.target = counterattack and counterattack.target or ctx.fightSession and helpers.visible(ctx.fightSession.target) and ctx.fightSession.target or committed and NPC.IsHero(committed) and committed or helpers.visible(attacker) and attacker or nearestDistance < 1100 and nearest or nil
	local teleportDanger = false
	for _, arrival in ipairs(ctx.teleportArrivals) do
		if arrival.remaining < 2.5 and helpers.distance(ctx.position, arrival.position) < 950
			and enemies + ctx.incomingEnemies > allies then teleportDanger = true; break end
	end
	local immediateFinish = committed and NPC.IsHero(committed) and health > 0.55
		and Entity.GetHealth(committed) <= NPC.GetTrueDamage(ctx.hero) * NPC.GetArmorDamageMultiplier(committed)
		and helpers.distance(ctx.position, Entity.GetAbsOrigin(committed)) < NPC.GetAttackRange(ctx.hero) + NPC.GetAttackRangeBonus(ctx.hero) + 60
	ctx.spellFinish = ctx.settings.spells and ctx.heroModule and ctx.heroModule.finish and ctx.heroModule.finish(ctx, combat) or nil
	ctx.combatDecision = engagement.assess(ctx, ctx.target)
	if committed and NPC.IsHero(committed) and helpers.visible(committed) and not engagement.keep(ctx.combatDecision)
		and not counterattack and not ctx.spellFinish and not (ctx.fightSession and ctx.fightSession.target == committed) then
		ctx.combatRelease = {time = ctx.now, target = committed, reason = ctx.combatDecision and string.format("Fight reassessed: kill=%.2f incoming=%.0f remaining=%.0f", ctx.combatDecision.killTime, ctx.combatDecision.incoming, ctx.combatDecision.remaining) or "Target outside safe attack position or pursuit reach"}
		ctx.intent = nil
	end
	local fightSafe = ctx.fightSession and ctx.fightSession.distance < 1400
		and awareness.damage(ctx, ctx.position, 0.75) + awareness.forecast(ctx, ctx.position) * 0.2 + projectileDamage < Entity.GetHealth(ctx.hero) * 0.4
	local canFinish = (ctx.combatDecision and ctx.combatDecision.safe or fightSafe or ctx.spellFinish ~= nil) and not towerAggro
		and (not teleportDanger and not ctx.laneThreat.ambush or fightSafe or ctx.spellFinish ~= nil)
	local danger = towerAggro or projectileDamage > Entity.GetHealth(ctx.hero) * 0.4
		or not canFinish and (health < 0.55 and hurt and ctx.laneThreat.attacked or ctx.laneThreat.lethal)
		or (teleportDanger or ctx.laneThreat.ambush) and not immediateFinish and not fightSafe and not ctx.spellFinish
	losing = losing and (ctx.laneThreat.incoming > Entity.GetHealth(ctx.hero) * 0.2 or health < 0.55)
	if canFinish then losing = false end
	if ctx.spellFinish and not danger then ctx.recoveryTask, ctx.retreating, ctx.hardRetreat = nil, false, false end
	if counterattack then
		ctx.recoveryTask, ctx.disengage, ctx.retreatUntil = nil, nil, nil
		ctx.retreating, ctx.hardRetreat, ctx.recovering = false, false, false
		intent.begin(ctx, counterattack.target, "hero", false)
	else
		ctx.baseCounterattack = nil
		recovery.update(ctx, danger, losing)
	end
	if canFinish and ctx.target and not ctx.retreating and not ctx.intent and (ctx.laneThreat.attacked or ctx.combatDecision and ctx.combatDecision.killTime < 2.5) then
		intent.begin(ctx, ctx.target, "hero", false)
		ctx.intent.opportunity = 110
	end
	ctx.health = health
end

function helpers.stop(ctx)
	if ctx.lastOrder == "hold" then return true end
	Player.HoldPosition(ctx.player, ctx.hero, false, false, true, "self_play_hold")
	ctx.countOrder()
	ctx.lastOrder, ctx.attackTarget = "hold", nil
	return true
end

function helpers.move(ctx, position, mode, allowTower, tolerance)
	ctx.mode = mode
	local requested = position
	if NPC.IsChannellingAbility(ctx.hero) or ctx.now < ctx.busyUntil then return true, "waiting" end
	if NPC.HasState(ctx.hero, Enum.ModifierState.MODIFIER_STATE_ROOTED) or NPC.GetMoveSpeed(ctx.hero) <= 0 then return false, "impossible" end
	if ctx.now < ctx.nextMove then return true, "waiting" end
	if ctx.retreating or ctx.hardRetreat or ctx.defensiveCast then
		ctx.goalTrail, ctx.goalLock, ctx.goalLockUntil = {}, nil, nil
	elseif cfg.ditherLock ~= false then
		ctx.goalTrail = ctx.goalTrail or {}
		local trail = {}
		for _, entry in ipairs(ctx.goalTrail) do
			if ctx.now - entry.time < 3 then trail[#trail + 1] = entry end
		end
		trail[#trail + 1] = {x = position.x, y = position.y, time = ctx.now}
		ctx.goalTrail = trail
		local distinct = {}
		for _, entry in ipairs(trail) do
			local seen = false
			for _, other in ipairs(distinct) do
				local dx, dy = entry.x - other.x, entry.y - other.y
				if dx * dx + dy * dy < 90000 then seen = true; break end
			end
			if not seen then distinct[#distinct + 1] = entry end
		end
		if #distinct >= 4 then
			if not ctx.goalLock or ctx.now >= (ctx.goalLockUntil or 0) then
				ctx.goalLock, ctx.goalLockUntil = position, ctx.now + 2
				if ctx.now >= (ctx.nextDitherLog or 0) then
					ctx.nextDitherLog = ctx.now + 30
					Log.Write(string.format("[SelfPlay dither] %d goals in 3s, locking movement for 2s (mode=%s)",
						#distinct, mode))
				end
			end
			position, ctx.mode = ctx.goalLock, mode .. " (dither lock)"
		end
	end
	if not allowTower and not ctx.retreating and ctx.settings.riverExit ~= false then
		local exit = helpers.riverExit(ctx, position)
		if exit then position, ctx.mode = exit, mode .. " (river exit)" end
	end
	if not allowTower then
		position = navigation.goal(ctx, requested)
		if not position then ctx.mode = mode .. ": no safe route"; return helpers.stop(ctx) end
		if helpers.distance(position, requested) > 90 then
			if not ctx.edgeWaitSince or ctx.now - ctx.edgeWaitSince > 10 then ctx.edgeWaitSince = ctx.now end
			ctx.mode = mode .. ": wait at safe edge"
		else
			ctx.edgeWaitSince = nil
		end
		if not ctx.retreating and not ctx.intent and not ctx.runeTask and not ctx.aggroTask and not (ctx.teamTask and ctx.teamTask.fighting) then
			local clipped
			position, clipped = awareness.moveGoal(ctx, position)
			if clipped then ctx.mode = "Keep lane access outside enemy threat" end
		end
	end
	if helpers.distance(ctx.position, position) < (tolerance or 60) then return helpers.stop(ctx), "completed" end
	local goal = Vector(position.x, position.y, World.GetGroundZ(position.x, position.y))
	local goalDist = helpers.distance(ctx.position, goal)
	local progressed = ctx.lastOrder ~= "move" or not ctx.moveGoal or helpers.distance(ctx.moveGoal, goal) > 120
		or not ctx.stuckGoalDist or ctx.stuckGoalDist - goalDist > 60
	if progressed then
		ctx.stuckPosition, ctx.stuckTime, ctx.stuckAttempts = ctx.position, ctx.now, 0
		ctx.stuckGoalDist = goalDist
	end
	local precision = math.max(25, math.min(100, helpers.distance(ctx.position, goal) * 0.12))
	if ctx.moveGoal and helpers.distance(ctx.moveGoal, goal) < precision and ctx.lastOrder == "move" and NPC.IsRunning(ctx.hero)
		and ctx.now - ctx.stuckTime < 2 then return true end
	position = goal
	if not GridNav.IsTraversable(position) then
		local found, foundScore
		for radius = 100, 600, 100 do
			for angle = 0, 7 do
				local theta = angle * math.pi / 4
				local x, y = position.x + math.cos(theta) * radius, position.y + math.sin(theta) * radius
				local candidate = Vector(x, y, World.GetGroundZ(x, y))
				if GridNav.IsTraversable(candidate) and (allowTower or not helpers.unsafePosition(ctx, candidate)) then
					local clearance = helpers.clearance(candidate)
					local score = clearance * 1000 - helpers.distance(ctx.position, candidate)
					if not foundScore or score > foundScore then found, foundScore = candidate, score end
					if clearance >= 4 then break end
				end
			end
			if foundScore and found and helpers.clearance(found) >= 4 then break end
		end
		if not found then return false, "impossible" end
		position = found
	end

	if ctx.now - ctx.stuckTime > 2 then
		local path = GridNav.BuildPath(ctx.position, position, navigation.treeWalking(ctx))
		ctx.stuckAttempts = (ctx.stuckAttempts or 0) + 1
		if #path > 0 then
			for _, waypoint in ipairs(path) do
				if helpers.distance(ctx.position, waypoint) > 250 then position = waypoint; break end
			end
		else
			local detour = navigation.escape(ctx, navigation.coverAnchor(ctx))
			if not detour then ctx.mode = mode .. ": path obstructed"; return false, "impossible" end
			position = detour
		end
		ctx.stuckPosition, ctx.stuckTime = ctx.position, ctx.now
		ctx.mode = mode .. " (rerouting)"
	end
	if not allowTower then
		position = navigation.goal(ctx, position)
		if not position or helpers.distance(ctx.position, position) < 30 then return helpers.stop(ctx), "completed" end
	end
	if ctx.lastOrder == "move" and ctx.lastMoveOrder and ctx.now - ctx.lastMoveOrder < 0.3
		and ctx.moveGoal and helpers.distance(ctx.moveGoal, goal) < 200 then return true, "waiting" end
	NPC.MoveTo(ctx.hero, position, false, true, false, true, "self_play_move")
	ctx.countOrder()
	ctx.attackTarget = nil
	ctx.moveTarget, ctx.moveGoal, ctx.moveCommand = requested or goal, position, position
	ctx.lastOrder, ctx.nextMove = "move", ctx.now + cfg.moveInterval
	ctx.lastMoveOrder = ctx.now
	return true, "issued"
end

function helpers.attackDelay(ctx, target)
	return lastHit.timing(ctx, target)
end

function helpers.attack(ctx, target, mode, allowTower)
	if not helpers.visible(target) or NPC.HasState(ctx.hero, Enum.ModifierState.MODIFIER_STATE_DISARMED)
		or NPC.IsWaitingToSpawn(target) or NPC.HasState(target, Enum.ModifierState.MODIFIER_STATE_OUT_OF_GAME)
		or NPC.HasState(target, Enum.ModifierState.MODIFIER_STATE_UNTARGETABLE)
		or NPC.HasState(target, Enum.ModifierState.MODIFIER_STATE_ATTACK_IMMUNE)
		or NPC.HasState(target, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE)
		or NPC.HasModifier(ctx.hero, "modifier_ghost_state")
		or NPC.HasModifier(ctx.hero, "modifier_item_ethereal_blade_ethereal")
		or NPC.HasModifier(target, "modifier_ghost_state")
		or NPC.HasModifier(target, "modifier_item_ethereal_blade_ethereal") then return false end
	if NPC.IsLaneCreep(target) and Entity.IsSameTeam(ctx.hero, target)
		and not laneRules.denyable(ctx.clock, Entity.GetHealth(target), Entity.GetMaxHealth(target),
			NPC.GetModifierProperty(target, Enum.ModifierFunction.MODIFIER_PROPERTY_CREEP_DENY_PERCENT)) then return false end
	local targetPosition = Entity.GetAbsOrigin(target)
	local attackRange = NPC.GetAttackRange(ctx.hero) + NPC.GetAttackRangeBonus(ctx.hero)
	local firingPosition = NPC.IsStructure(target) and engagement.attackPosition(ctx, target) or helpers.distance(ctx.position, targetPosition) <= attackRange and ctx.position
		or helpers.toward(targetPosition, ctx.position, math.max(50, attackRange - 35))
	if not allowTower and helpers.unsafePosition(ctx, firingPosition) then return false end
	if ctx.hits.blocked[Entity.GetIndex(target)] then return false end
	ctx.mode = mode
	local position = Entity.GetAbsOrigin(target)
	local range = NPC.GetAttackRange(ctx.hero) + NPC.GetAttackRangeBonus(ctx.hero)
	if NPC.IsStructure(target) and not NPC.IsEntityInRange(ctx.hero, target, range) then

		if ctx.attackTarget ~= target or ctx.lastOrder ~= "attack" or ctx.now >= (ctx.structureOrderAt or 0) + 2 then
			Player.AttackTarget(ctx.player, ctx.hero, target, false, false, true, "self_play_structure", false)
			ctx.countOrder()
			ctx.attackTarget, ctx.lastOrder, ctx.structureOrderAt = target, "attack", ctx.now
		end
		return true, false
	end
	if ctx.now < ctx.attackNext then
		if NPC.IsHero(target) and ctx.attackTarget == target and ctx.lastOrder == "attack" and NPC.IsAttacking(ctx.hero) then return true, false end
		if NPC.IsHero(target) and not NPC.IsEntityInRange(ctx.hero, target, range) then
			return helpers.move(ctx, helpers.toward(ctx.predict(target, 0.2), ctx.position, math.max(50, range - 50)), mode, allowTower, 20), false
		end
		if ctx.lastOrder ~= "attack" then helpers.stop(ctx) end
		return true, false
	end
	if not NPC.IsEntityInRange(ctx.hero, target, range) then
		if NPC.IsHero(target) and ctx.attackTarget == target and ctx.lastOrder == "attack" and NPC.IsAttacking(ctx.hero)
			and helpers.distance(ctx.position, position) <= range + NPC.GetHullRadius(target) then return true, false end
		return helpers.move(ctx, helpers.toward(position, ctx.position, math.max(50, range - 65)), mode, allowTower, 15), false
	end
	if ctx.attackTarget == target and ctx.lastOrder == "attack" and NPC.IsAttacking(ctx.hero) then return true, false end
	local _, windup = helpers.attackDelay(ctx, target)
	if not windup then return false end
	Player.AttackTarget(ctx.player, ctx.hero, target, false, false, true, "self_play_attack", false)
	ctx.countOrder()
	if NPC.IsHero(target) then ctx.nextAggro = ctx.now + 3.1 end
	lastHit.ordered(ctx, target, windup)
	ctx.busyUntil, ctx.attackNext = ctx.now + windup + 0.04, ctx.now + NPC.GetSecondsPerAttack(ctx.hero, false)
	ctx.lastOrder, ctx.attackTarget, ctx.mode = "attack", target, mode
	return true, true
end

function helpers.pushSafe(ctx, structure)
	if not helpers.visible(structure) or Entity.IsSameTeam(structure, ctx.hero) or ctx.nearEnemies > ctx.nearAllies
		or ctx.health < 0.60 or NPC.HasState(structure, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE)
		or NPC.HasState(structure, Enum.ModifierState.MODIFIER_STATE_ATTACK_IMMUNE)
		or helpers.unsafePosition(ctx, engagement.attackPosition(ctx, structure)) then return false end
	local cover = 0
	for _, wave in ipairs(ctx.waves) do
		for _, creep in ipairs(wave) do
			if helpers.visible(creep) and helpers.distance(Entity.GetAbsOrigin(creep), Entity.GetAbsOrigin(structure)) < 800 then cover = cover + 1 end
		end
	end
	return NPC.IsTower(structure) and towerSafety.position(ctx, structure, engagement.attackPosition(ctx, structure))
		or not NPC.IsTower(structure) and (cover >= 2 or towerSafety.attackers(ctx, structure) > 0)
end

function core.push(ctx)
	for _, structure in ipairs(ctx.structures) do
		if helpers.distance(ctx.position, Entity.GetAbsOrigin(structure)) < 1200 and helpers.pushSafe(ctx, structure) then
			intent.begin(ctx, structure, "structure", false)
			if intent.run(ctx) then return true end
		end
	end
	return false
end

function helpers.lanePath(ctx)
	local groups = helpers.laneGroups()
	if not groups then return nil end
	for _, group in pairs(groups) do
		if group.lane == ctx.lane and #group.lane_path >= 2 then return group.lane_path end
	end
	return nil
end

function helpers.laneAnchor(ctx)
	local best, score = nil, math.huge
	for _, creep in ipairs(ctx.waves[ctx.lane]) do
		if helpers.valid(creep) then
			local position = Entity.GetAbsOrigin(creep)
			local distance = helpers.distance(position, ctx.enemyHome)
			if distance < score then best, score = position, distance end
		end
	end
	local groups = helpers.laneGroups()
	if groups then
		for _, group in pairs(groups) do
			if group.lane == ctx.lane then
				for _, creep in pairs(group.creeps) do
					if helpers.visible(creep.ref) then
						local position = Entity.GetAbsOrigin(creep.ref)
						local distance = helpers.distance(position, ctx.enemyHome)
						if distance < score then best, score = position, distance end
					end
				end
			end
		end
	end
	local regroup = navigation.regroup(ctx, best, cfg.anchors[ctx.team][ctx.lane])
	if regroup then return regroup end
	if best then
		if ctx.clock > 35 then
			local previous = ctx.waveLane == ctx.lane and ctx.waveAnchor
			if previous and ctx.now - ctx.waveSeen < 35 and not helpers.unsafePosition(ctx, previous)
				and helpers.distance(best, ctx.home) < helpers.distance(previous, ctx.home) - 350 then return previous end
			if not previous and helpers.distance(best, ctx.home) < helpers.distance(ctx.position, ctx.home) - 500 then
				return helpers.distance(ctx.position, cfg.anchors[ctx.team][ctx.lane]) < 2200 and ctx.position or cfg.anchors[ctx.team][ctx.lane]
			end
		end
		ctx.waveSeen, ctx.wavePosition = ctx.now, best
		ctx.waveAnchor, ctx.waveLane = helpers.toward(best, ctx.home, ctx.role >= 4 and 350 or 180), ctx.lane
		return ctx.waveAnchor
	end
	if ctx.waveLane == ctx.lane and ctx.waveSeen and ctx.now - ctx.waveSeen < 12 then return ctx.waveAnchor end
	for _, tower in ipairs(ctx.towers) do
		if Entity.IsSameTeam(tower, ctx.hero) and NPC.GetUnitName(tower):find("tower1_" .. cfg.lanes[ctx.lane], 1, true) then
			return helpers.toward(Entity.GetAbsOrigin(tower), ctx.enemyHome, 400)
		end
	end
	return cfg.anchors[ctx.team][ctx.lane]
end

function core.block(ctx)
	return positioning.block(ctx, helpers.blockEnd(ctx))
end

function core.lastHit(ctx)
	return lastHit.run(ctx)
end

function core.camp(ctx)
	return cfg.pull and supportCamps.run(ctx) or false
end

function core.teleporting(ctx)
	local scroll = NPC.GetItem(ctx.hero, "item_tpscroll", false)
	local task = ctx.teleportOrder
	if task and ctx.now - (task.started or ctx.now) > 8 then ctx.teleportOrder, task = nil, nil end
	local active = NPC.HasModifier(ctx.hero, "modifier_teleporting") or scroll and Ability.IsChannelling(scroll)
		or task and task.ability and Entity.IsEntity(task.ability) and Ability.IsChannelling(task.ability)
	if active then
		if not task then task = {started = ctx.now}; ctx.teleportOrder = task end
		task.seen, task.lastActive = true, ctx.now
		ctx.mode = "Teleport: preserve channel until landing"
		return true
	end
	if not task then return false end
	if task.seen and ctx.now - task.lastActive < 0.15
		or not task.seen and ctx.now - task.started < 0.6 + NetChannel.GetAvgLatency(Enum.Flow.FLOW_OUTGOING) then return true end
	ctx.teleportOrder = nil
	return false
end

function core.teleport(ctx, destination, purpose)
	if ctx.settings.teleport == false then return false end
	if not supportPolicy.midTeleport(ctx, destination) then return false end
	if purpose == "fight" and ctx.role == 2 and NPC.GetCurrentLevel(ctx.hero) < 6 and not ctx.baseDefense then return false end
	if ctx.helpRotation or purpose ~= "fight" and purpose ~= "defend" and ctx.now < (ctx.helpLaneUntil or 0) then return false end
	if ctx.now < (ctx.nextTeleport or 0) or ctx.nearEnemies > 0 or Hero.GetRecentDamage(ctx.hero) > 0
		or helpers.distance(ctx.position, destination) < 3000 then return false end
	local scroll = NPC.GetItem(ctx.hero, "item_tpscroll", false)
	local travel = ctx.heroModule and ctx.heroModule.travelAbility and ctx.heroModule.travelAbility(ctx)
	scroll = travel or scroll
	if not scroll or not travel and not Item.IsItemEnabled(scroll) or Ability.CanBeExecuted(scroll) ~= -1
		or not Ability.IsReady(scroll) or not Ability.IsCastable(scroll, NPC.GetMana(ctx.hero)) then return false end
	local best, distance, estimate = nil, 2200, nil
	if purpose ~= "fight" and helpers.distance(destination, ctx.home) < 600 and ctx.fountain then best, distance = ctx.home, 0 end
	for _, structure in ipairs(ctx.structures) do
		if helpers.valid(structure) and Entity.IsSameTeam(structure, ctx.hero) then
			local position = Entity.GetAbsOrigin(structure)
			local score = helpers.distance(position, destination)
			local safe = true
			local friendly = 0
			for _, ally in ipairs(ctx.allies) do
				if ally ~= ctx.hero and helpers.valid(ally) and Entity.GetHealth(ally) > Entity.GetMaxHealth(ally) * 0.45
					and helpers.distance(position, Entity.GetAbsOrigin(ally)) < 1200 then friendly = friendly + 1 end
			end
			local clearance = purpose == "fight" and friendly >= 2 and 900 or 1600
			for _, enemy in ipairs(ctx.enemies) do
				if helpers.visible(enemy) and helpers.distance(position, Entity.GetAbsOrigin(enemy)) < clearance then safe = false; break end
			end
			for _, arrival in ipairs(ctx.teleportArrivals or {}) do
				if helpers.distance(position, arrival.position) < 1400 then safe = false; break end
			end
			local prediction
			if safe and purpose == "fight" then
				prediction, ctx.helpStatus = helpRotation.evaluate(ctx, ctx.teamTask, position)
				safe = prediction ~= nil
				if prediction then score = prediction.eta * 200 end
			end
			if safe and score < distance then best, distance, estimate = position, score, prediction end
		end
	end
	if not best or purpose == "fight" and not estimate or not navigation.teleportWorth(ctx, destination, best, purpose) then return false end
	Ability.CastPosition(scroll, best, false, false, true)
	ctx.teleportOrder = {started = ctx.now, ability = scroll}
	ctx.attackTarget, ctx.hits.ordered = nil, nil
	if purpose == "fight" then helpRotation.commit(ctx, ctx.teamTask, best, estimate) end
	ctx.nextTeleport = ctx.now + 8
	ctx.busyUntil, ctx.mode, ctx.lastOrder = ctx.now + 0.6, purpose == "fight" and "Teleport to allied fight" or "Teleport", "cast"
	return true
end

function core.dodge(ctx)
	if ctx.settings.dodge == false then return false end
	local best, bestScore, earliest
	for _, hazard in pairs(ctx.hazards) do
		local dt = ctx.now - hazard.created
		local x = hazard.origin.x + hazard.velocity.x * dt
		local y = hazard.origin.y + hazard.velocity.y * dt
		local time, distance = planner.closestApproach(x - ctx.position.x, y - ctx.position.y,
			hazard.velocity.x, hazard.velocity.y, math.min(0.65, hazard.expires - ctx.now))
		local width = math.max(48, hazard.radius or 0)
		if time > 0 and distance < NPC.GetHullRadius(ctx.hero) + width then
			local speed = math.sqrt(hazard.velocity.x ^ 2 + hazard.velocity.y ^ 2)
			for _, side in ipairs({-1, 1}) do
				local offset = NPC.GetHullRadius(ctx.hero) + width + math.max(90, NPC.GetMoveSpeed(ctx.hero) * time * 0.55)
				local position = Vector(ctx.position.x - hazard.velocity.y / speed * offset * side,
					ctx.position.y + hazard.velocity.x / speed * offset * side, ctx.position.z)
				if GridNav.IsTraversable(position) and not helpers.unsafePosition(ctx, position) then
					local score = awareness.risk(ctx, position) * 4 + awareness.damage(ctx, position, math.max(0.4, time + 0.4)) * 2
						+ helpers.distance(ctx.position, position) * 0.15
					if score < bestScore then best, bestScore = position, score end
				end
			end
			if not earliest or time < earliest then earliest = time end
		end
	end
	if best then
		ctx.campTask = nil
		local occupied = NPC.IsChannellingAbility(ctx.hero) or ctx.now < ctx.busyUntil
		local critical = (earliest or 1) < 0.22 or ctx.hardRetreat
			or awareness.forecast(ctx, ctx.position) > Entity.GetHealth(ctx.hero) * 0.15
		if occupied and not critical then return false end
		if occupied then
			helpers.stop(ctx)
			ctx.hits.ordered, ctx.busyUntil, ctx.attackNext = nil, ctx.now, ctx.now
		end
		local moved, status = helpers.move(ctx, best, "Dodge linear projectile")
		return moved or status ~= "impossible"
	end
	return false
end

function core.sustain(ctx, combatOnly)
	return consumables.run(ctx, combatOnly) or not combatOnly and neutralItems.use(ctx, combat)
end

function core.committed(ctx)
	if ctx.retreating or ctx.hardRetreat then return false end
	if ctx.heroModule and ctx.heroModule.locked and ctx.heroModule.locked(ctx)
		and heroModules.update(ctx, combat, false) then return true end
	local task = ctx.teamTask
	local fighting = ctx.fightSession or task and task.fighting or ctx.intent and ctx.intent.kind == "hero"
	if fighting and (core.sustain(ctx, true) or combat.items(ctx, false)) then return true end
	if ctx.fightSession and not ctx.helpRotation and fights.run(ctx) then return true end
	if task and task.fighting and teamplay.run(ctx) then return true end
	if ctx.intent and ctx.intent.kind == "hero" and intent.run(ctx) then return true end
	if task and (task.kind == "push" or task.kind == "roshan") then
		if core.sustain(ctx) or combat.items(ctx, false) then return true end
		if task.kind == "push" and combat.farm(ctx, ctx.creeps, true) then return true end
		if teamplay.run(ctx) then return true end
	end
	local tower = baseDefense.outer(ctx)
	if tower and supportPolicy.midTeleport(ctx, tower.position) then
		ctx.farmCandidate, ctx.aggroTask, ctx.spacingTask, ctx.regroupTask = nil, nil, nil, nil
		if ctx.distance(ctx.position, tower.position) > 1100 then
			return core.teleport(ctx, tower.goal, "defend") or helpers.move(ctx, tower.goal, "Respond to tower siege")
		end
		if combat.farm(ctx, ctx.creeps, true) then return true end
		local target, distance
		for _, creep in ipairs(ctx.creeps) do
			if helpers.visible(creep) and NPC.IsLaneCreep(creep) and not Entity.IsSameTeam(ctx.hero, creep)
				and ctx.distance(Entity.GetAbsOrigin(creep), tower.position) < 1100
				and awareness.farmSafe(ctx, engagement.attackPosition(ctx, creep), 1) then
				local current = ctx.distance(ctx.position, Entity.GetAbsOrigin(creep))
				if not distance or current < distance then target, distance = creep, current end
			end
		end
		if target then return ctx.attack(target, "Clear wave threatening allied tower") end
	end
	return false
end

function core.strategy(ctx)
	if not ctx.settings.spells or not ctx.heroModule or not ctx.heroModule.strategy or taskPolicy.farmBlocked(ctx) then return false end
	if core.sustain(ctx) or combat.items(ctx, false) then return true end
	return ctx.heroModule.strategy(ctx, combat)
end

function core.ward(ctx)
	return objectives.ward(ctx, helpers.laneAnchor(ctx))
end

function core.units(ctx)
	if not cfg.units or ctx.now < ctx.nextUnits then return end
	ctx.nextUnits = ctx.now + 0.1
	for _, unit in ipairs(ctx.summons) do
		if helpers.valid(unit) and unitControl.eligible(ctx, unit) and not NPC.HasModifier(unit, "modifier_teleporting")
			and not NPC.IsChannellingAbility(unit) and not heroModules.unit(ctx, combat, unit) then unitControl.run(ctx, combat, unit) end
	end
	for id, actor in pairs(ctx.heroState.actors or {}) do
		if not Entity.IsEntity(actor.hero) or not Entity.IsAlive(actor.hero) then
			ctx.heroState.actors[id], ctx.heroState.unitOrders[id], ctx.heroState.unitBusy[id] = nil, nil, nil
		end
	end
end

function core.macro(ctx)
	if core.push(ctx) then return true end
	if mapFarm.run(ctx) then return true end
	local fallback = ctx.waveFallback
	if fallback then
		if ctx.now < fallback.expires and helpers.distance(ctx.position, fallback.goal) > 120 then
			return helpers.move(ctx, fallback.goal, "Rotate away from blocked wave")
		end
		ctx.waveFallback = nil
	end
	if ctx.clock >= helpers.laneEnd(ctx) and ctx.role <= 3 and ctx.nearEnemies == 0 and ctx.now >= (ctx.nextRotation or 0) then
		ctx.nextRotation = ctx.now + 20
		local chosen, bestScore = ctx.lane, -math.huge
		for lane, wave in ipairs(ctx.waves) do
			for _, creep in ipairs(wave) do
				if helpers.valid(creep) then
					local position = Entity.GetAbsOrigin(creep)
					local value = 2200 - helpers.distance(ctx.position, position) * 0.2 + (lane == ctx.lane and 350 or 0)
					for _, ally in ipairs(ctx.allies) do
						if ally ~= ctx.hero and helpers.valid(ally) and helpers.distance(Entity.GetAbsOrigin(ally), position) < 1500 then value = value - 800 end
					end
					for _, enemy in ipairs(ctx.enemies) do
						if helpers.visible(enemy) and helpers.distance(Entity.GetAbsOrigin(enemy), position) < 1800 then value = value - 2500 end
					end
					if value > bestScore then chosen, bestScore = lane, value end
				end
			end
		end
		ctx.lane = chosen
	end
	if ctx.clock < helpers.laneEnd(ctx) then
		if ctx.nearEnemies == 0 and ctx.heroModule and ctx.heroModule.farmReady and ctx.heroModule.farmReady(ctx) then
			local laneAvailable = false
			for _, creep in ipairs(ctx.creeps) do
				if helpers.visible(creep) and not Entity.IsSameTeam(ctx.hero, creep)
					and helpers.distance(ctx.position, Entity.GetAbsOrigin(creep)) < 1100 then laneAvailable = true; break end
			end
			if not laneAvailable and jungle.run(ctx) then return true end
		end
		local best, score = nil, math.huge
		for _, creep in ipairs(ctx.creeps) do
			if helpers.visible(creep) then
				local allied = Entity.IsSameTeam(creep, ctx.hero)
				local distance = helpers.distance(ctx.position, Entity.GetAbsOrigin(creep))
				local fraction = Entity.GetHealth(creep) / math.max(1, Entity.GetMaxHealth(creep))
				if distance < 1100 and (not allied and laneRules.canLastHit(ctx, creep) or ctx.role >= 4 and allied and fraction < 0.5)
					and not helpers.unsafePosition(ctx, engagement.attackPosition(ctx, creep)) then
					local value = distance + fraction * 250
					if value < score then best, score = creep, value end
				end
			end
		end
		if best then
			if positioning.lane(ctx, best) then return true end
		end
		local anchor = helpers.laneAnchor(ctx)
		local waveAlive = helpers.laneWaveAlive(ctx) and not helpers.creepsUnfinished(ctx)
		local takeTeleport = waveAlive and core.teleport(ctx, anchor, "lane")
		return takeTeleport or helpers.move(ctx, anchor, ctx.regroupTask and "Regroup with incoming wave"
			or ctx.role >= 4 and "Support lane: deny and protect" or "Lane: wait for last hit")
	end
	local defense = baseDefense.outer(ctx)
	if defense and supportPolicy.midTeleport(ctx, defense.position) then
		return core.teleport(ctx, defense.goal, "defend") or helpers.move(ctx, defense.goal, "Respond to tower siege")
	end
	if ctx.role >= 4 then
		local coreHero, score = nil, math.huge
		for _, ally in ipairs(ctx.allies) do
			if supportPolicy.follow(ctx, ally) then
				local value = helpers.distance(ctx.position, Entity.GetAbsOrigin(ally)) - NPC.GetTrueDamage(ally) * 5
				if value < score then coreHero, score = ally, value end
			end
		end
		if coreHero then
			local anchor = helpers.toward(Entity.GetAbsOrigin(coreHero), ctx.home, 350)
			return core.teleport(ctx, anchor, "rotate") or helpers.move(ctx, anchor, "Protect allied core")
		end
	end
	if ctx.role <= 3 and ctx.nearEnemies == 0 then
		local target, nearest = nil, math.huge
		for _, creep in ipairs(ctx.creeps) do
			if helpers.visible(creep) and not Entity.IsSameTeam(creep, ctx.hero) and not helpers.unsafePosition(ctx, engagement.attackPosition(ctx, creep)) then
				local current = helpers.distance(ctx.position, Entity.GetAbsOrigin(creep))
				if current < nearest then target, nearest = creep, current end
			end
		end
		if target and nearest < 1000 then
			if combat.farm(ctx, ctx.creeps, false) or helpers.attack(ctx, target, "Farm lane wave") then return true end
		end
		if jungle.run(ctx) then return true end
	end
	local anchor = helpers.laneAnchor(ctx)
	local blocked = ctx.waveBlocked
	if ctx.lastOrder == "hold" and not NPC.IsAttacking(ctx.hero) and helpers.distance(ctx.position, anchor) > 150 then
		if not blocked or helpers.distance(ctx.position, blocked.position) > 100 then
			blocked = {position = ctx.position, since = ctx.now}
			ctx.waveBlocked = blocked
		end
		if ctx.now - blocked.since > 3 then
			local locked = helpers.laneLocked(ctx)
			local best, nearest, chosenLane = nil, 6000, nil
			for lane, wave in ipairs(ctx.waves) do
				if lane ~= ctx.lane and locked then
				elseif lane ~= ctx.lane then
					for _, creep in ipairs(wave) do
						if helpers.valid(creep) then
							local point = helpers.toward(Entity.GetAbsOrigin(creep), ctx.home, 400)
							local distance = helpers.distance(ctx.position, point)
							if distance > 800 and distance < nearest and awareness.farmSafe(ctx, point, 0)
								and navigation.safePath(ctx, point, 40) then best, nearest, chosenLane = point, distance, lane end
						end
					end
				end
			end
			if not best then
				local point = navigation.coverAnchor(ctx)
				if helpers.distance(ctx.position, point) > 450 and navigation.safePath(ctx, point, 40) then best = point end
			end
			if best then
				ctx.waveFallback, ctx.waveBlocked, ctx.regroupTask = {goal = best, expires = ctx.now + 12}, nil, nil
				if chosenLane and not helpers.laneLocked(ctx) then ctx.lane, ctx.waveAnchor, ctx.waveLane, ctx.nextRotation = chosenLane, nil, nil, ctx.now + 15 end
				return helpers.move(ctx, best, "Rotate away from blocked wave")
			end
		end
	elseif ctx.lastOrder == "attack" or blocked and helpers.distance(ctx.position, blocked.position) > 100 then ctx.waveBlocked = nil end
	local takeTeleport = helpers.laneWaveAlive(ctx) and not helpers.creepsUnfinished(ctx) and core.teleport(ctx, anchor, "lane")
	return takeTeleport or helpers.move(ctx, anchor, ctx.regroupTask and "Regroup with incoming wave" or "Advance with wave")
end

function core.run()
	if not ui.enabled:Get() or not Engine.IsInGame() then return end
	if GameRules.IsPaused() then return end
	local gameState = GameRules.GetGameState()
	if gameState ~= Enum.GameState.DOTA_GAMERULES_STATE_PRE_GAME and gameState ~= Enum.GameState.DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then return end
	local hero, player = Heroes.GetLocal(), Players.GetLocal()
	if not hero or not player or not Entity.IsEntity(hero) then return end
	local ctx = state.ctx
	if not ctx or ctx.hero ~= hero or ctx.roleSetting ~= ui.role:Get() or ctx.laneSetting ~= ui.lane:Get() then
		helpers.reset()
		ctx = helpers.init(hero, player)
		state.ctx = ctx
	end
	if not ctx then return end
	ctx.now = GameRules.GetGameTime()
	if ctx.now < ctx.nextTick then return end
	ctx.nextTick = ctx.now + cfg.tick
	ctx.clock = gameState == Enum.GameState.DOTA_GAMERULES_STATE_PRE_GAME and -1 or ctx.now - GameRules.GetGameStartTime()
	ctx.position = Entity.GetAbsOrigin(hero)
	local _, heroOnScreen = Render.WorldToScreen(ctx.position)
	if not heroOnScreen then
		ctx.mode = "Paused: camera away from hero"
		return
	end
	local currentHealth = Entity.GetHealth(hero)
	ctx.healthLost = ctx.previousHealth and math.max(0, ctx.previousHealth - currentHealth) or 0
	if ctx.healthLost > 0 then ctx.lastDamaged = ctx.now end
	ctx.previousHealth = currentHealth
	if Input.IsInputCaptured() or ui.pause:IsDown() or ctx.now < ctx.pauseUntil then
		ctx.mode = "Paused: manual control"
		return
	end
	if ctx.now >= ctx.nextScan then helpers.scan(ctx) end
	helpers.sample(ctx)
	do
		local watch = cfg.watchdogTime or 5
		local busy = NPC.IsChannellingAbility(hero) or NPC.IsStunned(hero)
			or NPC.HasState(hero, Enum.ModifierState.MODIFIER_STATE_ROOTED)
		local resting = NPC.HasModifier(hero, "modifier_fountain_aura_buff") and recovery.fountainNeeded(ctx)
		local attacking = ctx.lastOrder == "attack" and helpers.valid(ctx.attackTarget)
		if not Entity.IsAlive(hero) or busy or resting or attacking then
			ctx.watchPos, ctx.watchSince = ctx.position, ctx.now
		elseif not ctx.watchPos or helpers.distance(ctx.position, ctx.watchPos) > 60 then
			ctx.watchPos, ctx.watchSince = ctx.position, ctx.now
		elseif ctx.now - (ctx.watchSince or ctx.now) > 2.5 and ctx.now >= (ctx.nextStallLog or 0)
			and (ctx.now - (ctx.watchSince or ctx.now) <= watch) then
			ctx.nextStallLog = ctx.now + 15
			local tasks = {}
			if ctx.blockState and not ctx.blockState.done then tasks[#tasks + 1] = "block:" .. (ctx.blockState.phase or "?") end
			if ctx.campTask then tasks[#tasks + 1] = "camp:" .. (ctx.campTask.phase or "?") end
			if ctx.runeTask then tasks[#tasks + 1] = "rune" end
			if ctx.riverTask then tasks[#tasks + 1] = "river" end
			if ctx.objectiveTask then tasks[#tasks + 1] = "objective:" .. (ctx.objectiveTask.kind or "?") end
			if ctx.teamTask then tasks[#tasks + 1] = "team:" .. (ctx.teamTask.kind or "?") end
			if ctx.fightSession then tasks[#tasks + 1] = "fight" end
			if ctx.intent then tasks[#tasks + 1] = "intent:" .. (ctx.intent.kind or "?") end
			if ctx.recoveryTask then tasks[#tasks + 1] = "recovery:" .. (ctx.recoveryTask.phase or "?") end
			if ctx.spacingTask then tasks[#tasks + 1] = "spacing" end
			if ctx.aggroTask then tasks[#tasks + 1] = "aggro" end
			if ctx.farmCandidate then tasks[#tasks + 1] = "farm" end
			if ctx.teleportOrder then tasks[#tasks + 1] = "teleport" end
			Log.Write(string.format("[SelfPlay stall] still=%.1fs mode=%s order=%s tasks=%s",
				ctx.now - (ctx.watchSince or ctx.now), ctx.mode, ctx.lastOrder or "none",
				#tasks > 0 and table.concat(tasks, ",") or "none"))
		elseif ctx.now - (ctx.watchSince or ctx.now) > watch
			and not (ctx.blockState and not ctx.blockState.done)
			and not core.teleporting(ctx) then
			ctx.busyUntil, ctx.attackNext, ctx.nextMove = ctx.now, ctx.now, 0
			ctx.teleportOrder, ctx.moveGoal, ctx.navigationGoal = nil, nil, nil
			ctx.navigationDetour, ctx.escapeRoute, ctx.waveBlocked = nil, nil, nil
			ctx.stuckPosition, ctx.stuckTime, ctx.stuckAttempts = ctx.position, ctx.now, 0
			ctx.watchPos, ctx.watchSince = ctx.position, ctx.now
			ctx.mode = (ctx.mode or "Unknown") .. " (watchdog: orders reset)"
			if ctx.now >= (ctx.nextWatchLog or 0) then
				ctx.nextWatchLog = ctx.now + 30
				Log.Write(string.format("[SelfPlay watchdog] no movement for %.0fs, orders reset (mode=%s)", watch, ctx.mode))
			end
		end
	end
	if Entity.IsAlive(hero) and core.teleporting(ctx) then core.units(ctx); return end
	baseDefense.update(ctx)
	lastHit.update(ctx)
	combat.level(ctx)
	neutralItems.run(ctx)
	if not Entity.IsAlive(hero) then
		if not ctx.wasDead then heroModules.reset(ctx) end
		ctx.intent, ctx.teleportOrder = nil, nil
		ctx.clearTask, ctx.teamTask, ctx.regroupTask = nil, nil, nil
		ctx.runeTask, ctx.aggroTask, ctx.spacingTask, ctx.laneGoal, ctx.aimTask, ctx.wardTask = nil, nil, nil, nil, nil, nil
		if (ctx.laneRotTask or ctx.crowdSince) and ui.debug:Get() then Log.Write("[SelfPlay lane rotation] reset: hero dead") end
		ctx.riverTask, ctx.jungleState, ctx.laneRotTask, ctx.crowdSince = nil, nil, nil, nil
		ctx.mapFarm, ctx.mapFarmBlocked = nil, nil
		ctx.recoveryTask, ctx.dewardTask = nil, nil
		ctx.disengage, ctx.waveFallback, ctx.waveBlocked = nil, nil, nil
		ctx.roshanState, ctx.roshanExit, ctx.roshanLoot = nil, nil, nil
		ctx.goalTrail, ctx.goalLock, ctx.goalLockUntil = {}, nil, nil
		ctx.afterDeath, ctx.edgeWaitSince = nil, nil
		ctx.mode, ctx.campTask, ctx.wasDead = "Dead: wait for respawn", nil, true
		ctx.busyUntil, ctx.attackNext, ctx.moveGoal = 0, 0, nil
		core.units(ctx)
		if not cfg.buyback or not recovery.buyback(ctx) then shop.run(ctx) end
		return
	end
	if ctx.wasDead then
		ctx.wasDead, ctx.recovering, ctx.retreatUntil, ctx.nextTeleport = false, false, nil, 0
		ctx.respawnedAt, ctx.afterDeath, ctx.lastOrder = ctx.now, true, nil
	end
	helpers.threat(ctx)
	shop.run(ctx)
	ctx.fullBuild = helpers.fullBuild(ctx)
	if ctx.settings.spells and ctx.heroModule and ctx.heroModule.background then ctx.heroModule.background(ctx, combat) end
	positioning.observe(ctx)
	runes.observe(ctx)
	teamplay.plan(ctx)
	jungle.update(ctx)
	core.units(ctx)
	if ctx.settings.spells and ctx.heroModule and ctx.heroModule.duringCast and ctx.heroModule.duringCast(ctx, combat) then return end
	if helpers.unsafePosition(ctx, ctx.position) and not NPC.IsChannellingAbility(hero) and not NPC.IsStunned(hero) then
		ctx.intent, ctx.hits.ordered, ctx.busyUntil, ctx.attackNext = nil, nil, ctx.now, ctx.now
		helpers.move(ctx, navigation.coverAnchor(ctx), "Exit exposed enemy tower range")
		return
	end
	if helpers.visible(ctx.attackTarget) and NPC.IsStructure(ctx.attackTarget) and not helpers.pushSafe(ctx, ctx.attackTarget)
		and not NPC.IsChannellingAbility(hero) then
		ctx.intent, ctx.hits.ordered, ctx.busyUntil = nil, nil, ctx.now
		if helpers.unsafePosition(ctx, ctx.position) then
			helpers.move(ctx, helpers.toward(ctx.position, ctx.home, 350), "Leave tower as wave cover expires")
		else helpers.stop(ctx) end
		return
	end
	if helpers.valid(ctx.attackTarget) and NPC.IsLaneCreep(ctx.attackTarget) and Entity.IsSameTeam(hero, ctx.attackTarget)
		and not laneRules.denyable(ctx.clock, Entity.GetHealth(ctx.attackTarget), Entity.GetMaxHealth(ctx.attackTarget),
			NPC.GetModifierProperty(ctx.attackTarget, Enum.ModifierFunction.MODIFIER_PROPERTY_CREEP_DENY_PERCENT)) then
		helpers.stop(ctx)
		ctx.hits.ordered, ctx.busyUntil = nil, ctx.now
	end
	if lastHit.yieldCore(ctx) then return end
	local pendingAttack = ctx.hits.ordered
	if pendingAttack and ctx.lastOrder == "attack" and not NPC.IsHero(pendingAttack.target)
		and (ctx.hardRetreat or baseDefense.interrupt(ctx, pendingAttack.target) or (ctx.fightSession or ctx.spellFinish) and (not pendingAttack.confirmed or pendingAttack.release > ctx.now + 0.12) or ctx.laneThreat.attacked and ctx.laneThreat.incoming > currentHealth * 0.3
			and (not pendingAttack.confirmed or pendingAttack.release > ctx.now + 0.12)) then
		helpers.stop(ctx)
		ctx.hits.ordered, ctx.busyUntil, ctx.attackNext = nil, ctx.now, ctx.now
	end
	if core.dodge(ctx) then return end
	if combat.items(ctx, true) then return end
	if NPC.IsChannellingAbility(hero) and (ctx.nearEnemies or 0) == 0 then
		ctx.channelIdleSince = ctx.channelIdleSince or ctx.now
		if ctx.now - ctx.channelIdleSince > 1.5 then
			helpers.stop(ctx)
			return
		end
	else
		ctx.channelIdleSince = nil
	end
	if combat.busy(ctx) or NPC.IsStunned(hero) then return end
	if detection.run(ctx, combat) then return end
	if ctx.settings.spells and ctx.heroModule and ctx.heroModule.emergency and ctx.heroModule.emergency(ctx, combat) then return end
	if ctx.spellFinish and ctx.heroModule.finishCast(ctx, combat) then return end
	if baseDefense.run(ctx) then return end
	if core.committed(ctx) then return end
	if core.strategy(ctx) then return end
	if ctx.mapFarm and mapFarm.run(ctx, true) then return end
	if ctx.retreating then
		ctx.intent, ctx.farmCandidate, ctx.campTask, ctx.clearTask, ctx.teamTask = nil, nil, nil, nil, nil
		ctx.runeTask, ctx.riverTask, ctx.aggroTask, ctx.spacingTask, ctx.aimTask = nil, nil, nil, nil, nil
		if ctx.recoveryTask.phase == "escape" then
			ctx.defensiveCast = true
			local defended = heroModules.update(ctx, combat, true) or combat.run(ctx, true)
			ctx.defensiveCast = nil
			if defended then return end
		end
		if ctx.recoveryTask.phase == "regen" and lastHit.recoveryFarm(ctx) then return end
		recovery.run(ctx)
		return
	end
	if not ctx.hardRetreat and teamplay.escape(ctx) then return end
	if ctx.clock <= helpers.blockEnd(ctx) and not ctx.laneThreat.avoid and core.block(ctx) then return end
	ctx.farmCandidate = nil
	local profileLocked = cfg.spells and ctx.heroModule and ctx.heroModule.locked and ctx.heroModule.locked(ctx)
	if not ctx.retreating and not ctx.campTask and not ctx.objectiveTask and not profileLocked and not jungle.active(ctx)
		and not (ctx.teamTask and ctx.teamTask.kind == "roshan") then ctx.farmCandidate = lastHit.plan(ctx) end
	if lastHit.finishHero(ctx) then return end
	if ctx.settings.spells and not profileLocked and ctx.heroModule and ctx.heroModule.opportunity
		and ctx.heroModule.opportunity(ctx, combat) then return end
	if not profileLocked and not ctx.hardRetreat and ctx.teamTask and ctx.teamTask.fighting and (ctx.role ~= 1 or fights.carryReady(ctx) or ctx.baseDefense ~= nil) and (ctx.role ~= 2 or fights.midReady(ctx) or ctx.baseDefense ~= nil or not ctx.teamTask.goal or ctx.distance(ctx.position, ctx.teamTask.goal) <= 1800) and teamplay.run(ctx) then return end
	if ctx.aggroTask and positioning.aggro(ctx) then return end
		if not ctx.hardRetreat and not ctx.intent and not profileLocked and (ctx.role ~= 1 or fights.carryReady(ctx)) then
		local opportunity = engagement.choose(ctx)
		if opportunity then
			local farm = ctx.farmCandidate
			local timeNeeded = NPC.GetSecondsPerAttack(hero, false) + (opportunity.approach or 0) + 0.4
			local reserved = farm and farm.start <= ctx.now + timeNeeded
			if opportunity.urgent or not reserved and not ctx.campTask and not ctx.teamTask and not ctx.runeTask and not ctx.objectiveTask then
				ctx.target, ctx.retreating, ctx.retreatUntil = opportunity.target, false, nil
				ctx.campTask, ctx.spacingTask, ctx.aggroTask = nil, nil, nil
				intent.begin(ctx, opportunity.target, "hero", false)
				ctx.intent.opportunity = opportunity.score
			end
		end
	end
		if not profileLocked and not ctx.hardRetreat and (ctx.role ~= 1 or fights.carryReady(ctx)) and teamplay.hunt(ctx) then return end
	if not profileLocked and jungle.active(ctx) then
		if core.sustain(ctx) then return end
		if ctx.settings.spells and ctx.heroModule and ctx.heroModule.farm and ctx.heroModule.farm(ctx, combat) then return end
		if combat.farm(ctx, ctx.neutrals, false) then return end
		if jungle.run(ctx, true) then return end
	end
	local farmPriority = not ctx.teamTask or (ctx.teamTask.kind == "protect" or ctx.teamTask.kind == "group") and not ctx.teamTask.fighting
	local farmAccess = not ctx.laneThreat.avoid or positioning.reserve(ctx)
	if not ctx.retreating and not ctx.campTask and not ctx.intent and not profileLocked and farmPriority and farmAccess then
		local candidate = ctx.farmCandidate
		if not ctx.clearTask and not ctx.runeTask and candidate and candidate.inRange and candidate.start <= ctx.now + 1 / 30 and ctx.now >= ctx.attackNext
			and lastHit.execute(ctx, candidate) then return end
	end
	if ctx.runeTask and ctx.runeTask.travelUntil and ctx.now < ctx.runeTask.travelUntil and not ctx.hardRetreat
		and runes.run(ctx, ctx.farmCandidate) then return end
	local imminentFarm = ctx.farmCandidate
	if not ctx.intent and not profileLocked and farmPriority and farmAccess and not ctx.runeTask
		and imminentFarm and imminentFarm.start <= ctx.now + math.max(0.4, imminentFarm.approach or 0)
		and lastHit.execute(ctx, imminentFarm) then return end
	if core.sustain(ctx) then return end
	if not profileLocked and combat.items(ctx, false) then return end
	if not profileLocked and not ctx.retreating and not ctx.intent and ctx.laneThreat.avoid then
		ctx.defensiveCast = true
		local defended = heroModules.update(ctx, combat, true) or combat.run(ctx, true)
		ctx.defensiveCast = nil
		if defended or positioning.respond(ctx) then return end
	end
	if not profileLocked and not ctx.retreating and positioning.aggro(ctx) then return end
	if not profileLocked and not ctx.retreating and positioning.respond(ctx) then return end
	if not profileLocked and ctx.campTask and core.camp(ctx) then return end
	if not ctx.intent and not profileLocked and not ctx.retreating then
		if ctx.teamTask and ctx.teamTask.kind == "push" and (ctx.role ~= 1 or fights.carryReady(ctx) or ctx.baseDefense ~= nil) and (ctx.role ~= 2 or fights.midReady(ctx) or ctx.baseDefense ~= nil or not ctx.teamTask.goal or ctx.distance(ctx.position, ctx.teamTask.goal) <= 1800) and teamplay.run(ctx) then return end
		if ctx.teamTask and ctx.teamTask.kind == "roshan" and teamplay.run(ctx) then return end
		if teamplay.loot(ctx) then return end
	end
	if not ctx.intent and not profileLocked and ctx.objectiveTask and objectives.collect(ctx) then return end
	if not ctx.intent and not profileLocked and not ctx.objectiveTask and runes.run(ctx, ctx.farmCandidate) then return end
	if heroModules.update(ctx, combat, ctx.retreating) then return end
	if ctx.aimTask and combat.run(ctx, ctx.retreating) then return end
	if not ctx.intent and ctx.target and not ctx.hardRetreat and ctx.health > 0.45 - engagement.boldness(ctx) * 0.28
		and Entity.GetHealth(ctx.target) <= NPC.GetTrueDamage(hero) * NPC.GetArmorDamageMultiplier(ctx.target) * 2
		and helpers.distance(ctx.position, Entity.GetAbsOrigin(ctx.target)) < NPC.GetAttackRange(hero) + NPC.GetAttackRangeBonus(hero) + 300 then
		intent.begin(ctx, ctx.target, "hero", true)
	end
	if intent.run(ctx) then return end
	if unitControl.summon(ctx, combat) then return end
	if NPC.HasModifier(hero, "modifier_fountain_aura_buff") and recovery.fountainNeeded(ctx) then
		ctx.fountainHoldSince = ctx.fountainHoldSince or ctx.now
		if ctx.now - ctx.fountainHoldSince <= (cfg.fountainHoldTimeout or 3) then
			ctx.mode = "Recover at fountain"
			helpers.stop(ctx)
			return
		end
	else
		ctx.fountainHoldSince = nil
	end
	if not profileLocked and core.camp(ctx) then return end
	if teamplay.run(ctx) then return end
	if deward.run(ctx) then return end
	if objectives.collect(ctx, true) then return end
	if lastHit.recover(ctx) then return end
	if jungle.run(ctx, true) then return end
	if positioning.aggro(ctx) then return end
	if positioning.creepWaveFallback(ctx) then return end
	if laneRotation.run(ctx) then return end
	if positioning.soakAlone(ctx) then return end
	if positioning.fightCreeps(ctx) then return end
	local farm = ctx.farmCandidate
	if not ctx.runeTask and farm and farm.inRange and farm.start <= ctx.now + 1 / 30 and ctx.now >= ctx.attackNext then
		if lastHit.execute(ctx, farm) then return end
	end
	if ctx.target and not helpers.unsafePosition(ctx, Entity.GetAbsOrigin(ctx.target))
		and ctx.nearEnemies <= ctx.nearAllies and combat.run(ctx, false) then ctx.mode = "Combat ability"; return end
	if core.push(ctx) then return end
	if positioning.evade(ctx) then return end
	if lastHit.execute(ctx, ctx.farmCandidate) then return end
	if ctx.clock > helpers.blockEnd(ctx) and not profileLocked and not ctx.laneThreat.avoid and core.block(ctx) then return end
	if ctx.target and not helpers.unsafePosition(ctx, Entity.GetAbsOrigin(ctx.target))
		and (ctx.nearEnemies <= ctx.nearAllies or NPC.IsChannellingAbility(ctx.target)) then
		if combat.run(ctx, false) then ctx.mode = "Combat ability"; return end
		local distance = helpers.distance(ctx.position, Entity.GetAbsOrigin(ctx.target))
		local killable = Entity.GetHealth(ctx.target) <= NPC.GetTrueDamage(hero) * NPC.GetArmorDamageMultiplier(ctx.target) * 2
		if (ctx.tradeSafe or killable and ctx.health > 0.45) and (distance < NPC.GetAttackRange(hero) + NPC.GetAttackRangeBonus(hero) + 80
			or Hero.GetRecentDamage(hero) > 0 and distance < 450) then
			intent.begin(ctx, ctx.target, "hero", true)
			if intent.run(ctx) then return end
		end
	end
	if objectives.collect(ctx) or core.ward(ctx) then return end
	if combat.run(ctx, false) then ctx.mode = "Utility ability"; return end
	if not ctx.intent and not ctx.retreating and not profileLocked then lastHit.diagnose(ctx) end
	core.macro(ctx)
end

function selfPlay.OnUpdate()
	core.run()
	local ctx = state.ctx
	local now = GameRules.GetGameTime()
	if ctx and ui.debug:Get() and now >= (ctx.nextDebug or 0) then
		ctx.nextDebug = now + 3
		if ui.enabled:Get() and Entity.IsEntity(ctx.player) and now >= (ctx.nextScoreReport or 0) then
			ctx.nextScoreReport = now + 60
			local score = Player.GetTeamPlayer(ctx.player)
			Log.Write(string.format("[SelfPlay score] clock=%.1f hero=%s role=%d lastHits=%d denies=%d networth=%d gold=%d xp=%d heroDamage=%.0f laneGold=%d jungleGold=%d",
				ctx.clock, NPC.GetUnitName(ctx.hero), ctx.role, score.lasthit_count, score.deny_count, score.networth,
				score.totalearned_gold, score.totalearned_xp, score.hero_damage, score.creep_kill_gold, score.neutral_kill_gold))
		end
		if ctx.policy then
			local arch = ctx.policy
			Log.Write(string.format("[SelfPlay policy] hero=%s archetype=%s aggression=%.2f hold=%.2f engage=%d ult=%.2f backline=%.2f farm=%.2f join=%.2f initiate=%.2f retreat=%.2f save=%s disable=%s summon=%s channel=%s mobility=%s registered=%s",
				arch.name, arch.archetype, arch.aggression, arch.holdDistance, arch.engageRange, arch.ultWeight,
				arch.targetBackline, arch.farmPriority, arch.joinFights, arch.initiate, arch.retreatValue,
				tostring(arch.hasSave), tostring(arch.hasDisable), tostring(arch.hasSummon),
				tostring(arch.hasChannel), tostring(arch.hasMobility), tostring(arch.registered)))
		end
		Log.Write(string.format("[SelfPlay] role=%d lane=%d mode=%s hp=%.2f pos=%.0f,%.0f busy=%.2f attacks=%d cancelled=%d build=%s buy=%s cast=%s provider=%s order=%s",
			ctx.role, ctx.lane, ctx.mode, ctx.health or 0, ctx.position.x, ctx.position.y,
			math.max(0, ctx.busyUntil - ctx.now), ctx.hits.confirmed, ctx.hits.cancelled, ctx.shop.source, ctx.shop.status, ctx.lastAbility,
			ctx.shop.providerError or ctx.shop.deferredSource or "ok", ctx.lastOrder or "none"))
		Log.Write(string.format("[SelfPlay actions] time=%.2f target=%s lock=%s creepAggro=%d candidates=%d lastSwing=%s apm=%d",
			ctx.now, helpers.valid(ctx.attackTarget) and NPC.GetUnitName(ctx.attackTarget) or "none",
			ctx.intent and ctx.intent.kind or "none", ctx.creepPressure or 0, ctx.hits.candidateCount or 0,
			ctx.hits.lastConfirmedName or "none", ctx.apm or 0))
		if ai_bridge and ai_bridge.mcp_log then
			ai_bridge.mcp_log("debug", "self_play tick", {
				role = ctx.role, lane = ctx.lane, mode = ctx.mode,
				health = ctx.health, clock = ctx.clock, order = ctx.lastOrder or "none", apm = ctx.apm or 0,
			})
		end
		local farm = ctx.farmCandidate
		if farm and helpers.valid(farm.target) then
			Log.Write(string.format("[SelfPlay last hit] target=%s hp=%.0f damage=%d events=%d start=%.3f impact=%.3f approach=%.2f inRange=%s",
				NPC.GetUnitName(farm.target), Entity.GetHealth(farm.target), farm.damage, #farm.events,
				farm.start - ctx.now, farm.impact - ctx.now, farm.approach, tostring(farm.inRange)))
		end
		if ctx.blockState and not ctx.blockState.done then
			Log.Write(string.format("[SelfPlay block] phase=%s later=%s", ctx.blockState.phase, tostring(ctx.blockState.later == true)))
		end
		if ctx.teamTask and ctx.teamTask.kind == "group" then
			Log.Write(string.format("[SelfPlay group] members=%d fighting=%s objective=%s",
				#ctx.teamTask.members, tostring(ctx.teamTask.fighting), helpers.valid(ctx.teamTask.objective) and NPC.GetUnitName(ctx.teamTask.objective) or "Active fight"))
		end
		if ctx.fightStatus then Log.Write("[SelfPlay fight task] " .. ctx.fightStatus) end
		if ctx.baseDefense then Log.Write(string.format("[SelfPlay base defense] building=%s heroes=%d creeps=%d", ctx.baseDefense.name, ctx.baseDefense.heroes, ctx.baseDefense.creeps)) end
		if ctx.baseCounterattack then
			Log.Write(string.format("[SelfPlay base counterattack] target=%s allies=%d critical=%s actionDamage=%.0f",
				NPC.GetUnitName(ctx.baseCounterattack.target), ctx.baseCounterattack.allies, tostring(ctx.baseCounterattack.critical), ctx.baseCounterattack.incoming))
		end
		if ctx.helpStatus then Log.Write("[SelfPlay help] " .. ctx.helpStatus) end
		if ctx.laneThreat then
			Log.Write(string.format("[SelfPlay threat] incoming=%.0f future=%d ambush=%s attacked=%s retreat=%s",
				ctx.laneThreat.incoming, ctx.laneThreat.futureCount, tostring(ctx.laneThreat.ambush), tostring(ctx.laneThreat.attacked), tostring(ctx.hardRetreat)))
		end
		if ctx.combatDecision then
			Log.Write(string.format("[SelfPlay fight] target=%s keep=%s returnFire=%s kill=%.2fs incoming=%.0f remainingHP=%.0f supportDamage=%.0f supportUnits=%d",
				NPC.GetUnitName(ctx.combatDecision.target), tostring(engagement.keep(ctx.combatDecision)), tostring(ctx.combatDecision.returnFire), ctx.combatDecision.killTime,
				ctx.combatDecision.incoming, ctx.combatDecision.remaining, ctx.combatDecision.supportDamage, ctx.combatDecision.supportUnits))
		end
		if ctx.combatRelease and ctx.now - ctx.combatRelease.time < 4 then
			Log.Write("[SelfPlay fight release] " .. ctx.combatRelease.reason)
		end
		for _, event in ipairs(ctx.heroState.invokerEvents or {}) do Log.Write("[SelfPlay Invoker] " .. event) end
		ctx.heroState.invokerEvents = nil
		if ctx.heroState.blastReason then
			Log.Write(string.format("[SelfPlay Techies] blast=%s stage=%s", ctx.heroState.blastReason,
				ctx.heroState.techiesCombo and ctx.heroState.techiesCombo.stage or "none"))
		end
		if ctx.neutralItems then
			Log.Write(string.format("[SelfPlay neutral] madstones=%d status=%s", ctx.neutralItems.madstones or 0,
				ctx.neutralItems.status or "Waiting for crafting currency"))
		end
		if ctx.jungleState and ctx.jungleState.status then Log.Write("[SelfPlay jungle] " .. ctx.jungleState.status) end
		if ctx.campTask or ctx.campStatus then
			Log.Write(string.format("[SelfPlay support camp] state=%s status=%s", ctx.campTask and ctx.campTask.phase or "idle", ctx.campStatus or "Timed camp task"))
		end
		if ctx.roshanAssessment then
			local estimate = ctx.roshanAssessment
			Log.Write(string.format("[SelfPlay Roshan] %s kill=%.1fs remainingHP=%.0f", estimate.reason, estimate.timeToKill, estimate.remainingHealth))
		end
		for id, actor in pairs(ctx.heroState.actors or {}) do
			if helpers.valid(actor.hero) and actor.temporaryUnit then
				local scroll = NPC.GetItem(actor.hero, "item_tpscroll", false)
				Log.Write(string.format("[SelfPlay Double control] id=%d hp=%.2f target=%s order=%s busy=%.2f stunned=%s",
					id, actor.health, helpers.valid(actor.target) and NPC.GetUnitName(actor.target) or "none", tostring(actor.lastOrder),
					math.max(0, actor.busyUntil - ctx.now, (ctx.heroState.unitBusy[id] or 0) - ctx.now), tostring(NPC.IsStunned(actor.hero))))
				Log.Write(string.format("[SelfPlay Double] id=%d task=%s tp=%s remaining=%.1f pos=%.0f,%.0f cast=%s attacking=%s", id, actor.heroState.travelReason or "Combat or local farm",
					scroll and tostring(Ability.CanBeExecuted(scroll)) or "missing", actor.heroState.remaining or 0,
					actor.position.x, actor.position.y, actor.lastAbility or "none", tostring(NPC.IsAttacking(actor.hero))))
			end
		end
	end
end

function selfPlay.OnPrepareUnitOrders(data)
	local ctx = state.ctx
	if not ctx or not ui.enabled:Get() or data.player ~= ctx.player then return true end
	if data.identifier and type(data.identifier) == "string" and data.identifier:find("^self_play_") then return true end
	if ctx.settings.coexist then return true end
	if data.orderIssuer ~= Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_SELECTED_UNITS then return true end
	local controlsHero = data.npc == ctx.hero
	if not controlsHero then
		for _, unit in ipairs(Player.GetSelectedUnits(ctx.player) or {}) do
			if unit == ctx.hero then controlsHero = true; break end
		end
	end
	if controlsHero then
		if cfg.humanizer then Humanizer.ForceUserOrderByMinimap() end
		heroModules.reset(ctx)
		ctx.intent = nil
		ctx.pauseUntil = GameRules.GetGameTime() + cfg.manualPause
		ctx.campTask, ctx.aimTask, ctx.runeTask, ctx.clearTask, ctx.teamTask, ctx.regroupTask = nil, nil, nil, nil, nil, nil
		ctx.aggroTask, ctx.spacingTask, ctx.laneGoal, ctx.heroHarass = nil, nil, nil, nil
		if (ctx.laneRotTask or ctx.crowdSince) and ui.debug:Get() then Log.Write("[SelfPlay lane rotation] reset: manual control") end
		ctx.riverTask, ctx.jungleState, ctx.laneRotTask, ctx.crowdSince = nil, nil, nil, nil
		ctx.afterDeath, ctx.edgeWaitSince = nil, nil
		ctx.mapFarm = nil
		ctx.recoveryTask, ctx.dewardTask = nil, nil
		ctx.disengage, ctx.waveFallback, ctx.waveBlocked = nil, nil, nil
		ctx.roshanState, ctx.roshanExit, ctx.roshanLoot = nil, nil, nil
		ctx.goalTrail, ctx.goalLock, ctx.goalLockUntil = {}, nil, nil
		ctx.lastOrder, ctx.moveGoal = "manual", nil
	end
	return true
end

function selfPlay.OnProjectile(data)
	local ctx = state.ctx
	if not ctx or not ui.enabled:Get() or not data.source or not data.target or data.moveSpeed <= 0 then return end
	lastHit.projectile(ctx, data)
	if data.isAttack and data.target == ctx.hero and helpers.visible(data.source) and NPC.IsHero(data.source)
		and not Entity.IsSameTeam(ctx.hero, data.source) then
		ctx.heroHarass = {source = data.source, time = GameRules.GetGameTime()}
	end
	if data.isAttack and data.target == ctx.hero and helpers.valid(data.source) and NPC.IsLaneCreep(data.source) then
		ctx.creepAggro = ctx.creepAggro or {}
		ctx.creepAggro[Entity.GetIndex(data.source)] = GameRules.GetGameTime()
			+ helpers.distance(Entity.GetAbsOrigin(data.source), ctx.position) / data.moveSpeed + 0.25
	end
	if not helpers.visible(data.source) or not helpers.valid(data.target) then return end
	if helpers.distance(ctx.position, Entity.GetAbsOrigin(data.target)) > 2500 then return end
	local damage = data.isAttack and NPC.GetTrueDamage(data.source) * NPC.GetArmorDamageMultiplier(data.target) or 0
	if not data.isAttack and data.ability then
		damage = Ability.GetDamage(data.ability)
		local damageType = Ability.GetDamageType(data.ability)
		if damageType == Enum.DamageTypes.DAMAGE_TYPE_MAGICAL then damage = damage * NPC.GetMagicalArmorDamageMultiplier(data.target)
		elseif damageType == Enum.DamageTypes.DAMAGE_TYPE_PHYSICAL then damage = damage * NPC.GetArmorDamageMultiplier(data.target) end
	end
	ctx.projectiles[data.handle] = {target = data.target, damage = damage,
		impact = GameRules.GetGameTime() + helpers.distance(Entity.GetAbsOrigin(data.source), Entity.GetAbsOrigin(data.target)) / data.moveSpeed}
end

function selfPlay.OnUnitAnimation(data)
	if state.ctx and ui.enabled:Get() then
		lastHit.animation(state.ctx, data)
		positioning.animation(state.ctx, data)
	end
end

function selfPlay.OnUnitAnimationEnd(data)
	if state.ctx and ui.enabled:Get() then lastHit.animationEnd(state.ctx, data) end
end

function selfPlay.OnEntityDestroy(entity)
	if state.ctx then
		if Entity.IsEntity(entity) then heroModules.remove(state.ctx, entity) end
		lastHit.remove(state.ctx, entity)
		if state.ctx.intent and state.ctx.intent.target == entity then state.ctx.intent = nil end
	end
end

function selfPlay.OnNpcDying(npc)
	if state.ctx then teamplay.dying(state.ctx, npc) end
	selfPlay.OnEntityDestroy(npc)
end

function selfPlay.OnEntityHurt(data)
	if state.ctx and ui.enabled:Get() then
		lastHit.hurt(state.ctx, data)
		positioning.hurt(state.ctx, data)
		supportCamps.hurt(state.ctx, data)
		teamplay.hurt(state.ctx, data)
	end
end

function selfPlay.OnLinearProjectileCreate(data)
	local ctx = state.ctx
	if not ctx or not ui.enabled:Get() or not data.source or Entity.IsSameTeam(ctx.hero, data.source) then return end
	local speed = math.sqrt(data.velocity.x ^ 2 + data.velocity.y ^ 2)
	if speed < 100 or data.distance <= 0 or helpers.distance(ctx.position, data.origin) > 3500 then return end

	ctx.hazards[data.handle] = {origin = data.origin, velocity = data.velocity,
		created = GameRules.GetGameTime(), expires = GameRules.GetGameTime() + math.min(5, data.distance / speed),
		radius = data.fowRadius or 0}
end

function selfPlay.OnParticleCreate(data)
	if state.ctx and ui.enabled:Get() then teleports.create(state.ctx, data) end
end

function selfPlay.OnParticleUpdate(data)
	if state.ctx then teleports.point(state.ctx, data) end
end

function selfPlay.OnParticleUpdateFallback(data)
	if state.ctx then teleports.point(state.ctx, data) end
end

function selfPlay.OnParticleUpdateEntity(data)
	if state.ctx then teleports.attach(state.ctx, data) end
end

function selfPlay.OnParticleDestroy(data)
	if state.ctx then teleports.destroy(state.ctx, data) end
end

function selfPlay.OnLinearProjectileDestroy(data)
	if state.ctx then state.ctx.hazards[data.handle] = nil end
end

function selfPlay.OnDraw()
	local ctx = state.ctx
	if not ctx or not ui.enabled:Get() or not ui.draw:Get() then return end
	local text = string.format(localization.text("hud.header"), ctx.role, localization.text(cfg.lanes[ctx.lane]),
		localization.text(ctx.mode), ctx.shop.source, ctx.shop.status, ctx.lastAbility)
	if ctx.shop.providerError then text = text .. "\n" .. ctx.shop.providerError end
	Render.Text(renderContext.font, 16, text, Vec2(30, 260), Color(225, 235, 245, 255))
end

function selfPlay.OnGameEnd()
	local ctx = state.ctx
	if ctx then persist.save(ctx.role, ctx.lane, ctx.heroName) end
	camera.release()
	matchmaking.gameEnd()
	draft.reset()
	excuses.reset()
	helpers.reset()
end

local function panelInfo(panel)
	if not panel or not panel:IsValid() then return "none" end
	local parts = {}
	if panel:HasID() then parts[#parts + 1] = "id=" .. tostring(panel:GetID()) end
	local classes = panel:GetClassList()
	if classes then parts[#parts + 1] = "class=" .. table.concat(classes, "|") end
	parts[#parts + 1] = "children=" .. tostring(panel:GetChildCount())
	return table.concat(parts, " ")
end

local function reconnectTree(panel, depth)
	if not panel or depth > 6 then return nil end
	if not panel:IsValid() then return nil end
	local count = panel:GetChildCount()
	for index = 0, count - 1 do
		local child = panel:GetChild(index)
		if child and child:IsValid() then
			if child:HasClass("CanReconnect") then return child end
			if child:HasID() then
				local id = child:GetID()
				if type(id) == "string" and id:lower():find("reconnect", 1, true) then return child end
			end
			local found = reconnectTree(child, depth + 1)
			if found then return found end
		end
	end
	return nil
end

local function reconnectTarget(root)
	if not root or not root:IsValid() then return nil end
	for _, name in ipairs({"DOTAPlay", "DOTA_GamePanel", "HUD", "DOTA_LoadingScreen"}) do
		local panel = Panorama.GetPanelByName(name, true)
		if panel and panel:IsValid() then
			local found = reconnectTree(panel, 0)
			if found then return found, panel end
		end
	end
	if root and root:IsValid() and root:HasClass("CanReconnect") then return root, root end
	return nil, root
end

function selfPlay.OnUpdateEx()
	helpers.settings()
	camera.update(ui.enabled:Get() and ui.camera:Get())
	local now = matchmaking.update(ui.matchmaking, ui.role:Get())
	local uiState = Engine.GetUIState()
	if Engine.IsInGame() then
		reconnectState.attempts = 0
		reconnectState.nextAttempt = now + 5
	elseif now >= reconnectState.nextAttempt then
		reconnectState.nextAttempt = now + 5
		local play = Panorama.GetPanelByName("DOTAPlay", true)
		local target, host = reconnectTarget(play)
		if target and target:IsVisible() then
			local sent = Engine.RunScript(
				"$.DispatchEvent('PointerDown', $.GetContextPanel(), 'mouse');"
				.. "$.DispatchEvent('PointerUp', $.GetContextPanel(), 'mouse');"
				.. "$.DispatchEvent('Activated', $.GetContextPanel(), 'mouse');", target)
			reconnectState.attempts = reconnectState.attempts + 1
			if ui.debug:Get() then
				Log.Write(string.format("[SelfPlay reconnect] uiState=%d dashboard=%s attempt=%d sent=%s target=%s",
					uiState, tostring(uiState == Enum.UIState.DOTA_GAME_UI_STATE_DASHBOARD),
					reconnectState.attempts, tostring(sent), panelInfo(target)))
			end
		else
			if ui.debug:Get() and reconnectState.attempts > 0 then
				Log.Write(string.format("[SelfPlay reconnect] uiState=%d dashboard=%s no control play=%s",
					uiState, tostring(uiState == Enum.UIState.DOTA_GAME_UI_STATE_DASHBOARD), panelInfo(play)))
			end
			reconnectState.attempts = 0
		end
	end
	if ui.enabled:Get() then draft.update(ui.draft, ui.role:Get(), now) end
	excuses.update(ui.excuses)
end

function selfPlay.OnGCMessage(data)
	return matchmaking.message(data)
end

function selfPlay.OnScriptsLoaded()
	localization.init()
	Engine.ExecuteCommand("-dota_camera_center_on_hero")
	if ai_bridge and ai_bridge.mcp_log then
		ai_bridge.mcp_log("info", "self_play loaded", { turbo = helpers.isTurbo() })
	end
end

do
	if ai_bridge and ai_bridge.tool then
		ai_bridge.tool("self_play_status", "Returns Self Play bot runtime state.", {}, function()
			local ctx = state.ctx
			if not ctx then return { running = false } end
			local held, done = {}, {}
			if ctx.shop then
				local counts = shop.inventory(ctx)
				for name in pairs(counts) do held[#held + 1] = name end
				for name in pairs(ctx.shop.completed or {}) do done[#done + 1] = name end
				table.sort(held)
				table.sort(done)
			end
			return {
				running = ui.enabled:Get(),
				role = ctx.role, lane = ctx.lane, mode = ctx.mode,
				health = ctx.health, clock = ctx.clock,
				turbo = ctx.isTurbo == true,
				target = ctx.target and NPC.GetUnitName(ctx.target) or nil,
				order = ctx.lastOrder or "none",
				apm = ctx.apm or 0,
				buyStatus = ctx.shop and ctx.shop.status or "none",
				buyIndex = ctx.shop and ctx.shop.index or 0,
				buyPlanSize = ctx.shop and ctx.shop.plan and #ctx.shop.plan or 0,
				buyGoal = ctx.shop and ctx.shop.plan and ctx.shop.plan[ctx.shop.index] or nil,
				buyCompleted = table.concat(done, ","),
				buySource = ctx.shop and ctx.shop.source or "none",
				buyHeld = table.concat(held, ","),
			}
		end)
	end
end

if Profiler and Profiler.wrap_script then
	return Profiler.wrap_script("Self Play", selfPlay)
end

return selfPlay
