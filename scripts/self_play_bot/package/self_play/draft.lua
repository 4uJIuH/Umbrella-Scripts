local draft = {}
local catalog = require("self_play.catalog")
local planner = require("self_play.planner")
local persist = require("self_play.persist")
local JSON = require("assets.JSON")
local localization = require("self_play.localization")

local roleFlags = {1, 4, 2, 8, 16}
local defaults = {
	"phantom_lancer slark juggernaut sven life_stealer spectre necrolyte antimage clinkz windrunner ursa lone_druid luna faceless_void morphling skeleton_king phantom_assassin muerta terrorblade templar_assassin",
	"invoker obsidian_destroyer dragon_knight keeper_of_the_light earth_spirit arc_warden tinker slark ember_spirit puck void_spirit lina wisp snapfire pangolier earthshaker storm_spirit leshrac huskar rubick",
	"enigma night_stalker pudge axe dragon_knight brewmaster dawnbreaker doom_bringer visage dark_seer legion_commander magnataur windrunner kunkka primal_beast lycan phoenix earthshaker death_prophet beastmaster skeleton_king",
	"bounty_hunter spirit_breaker rubick nyx_assassin pudge zuus mirana dark_willow techies earthshaker ringmaster earth_spirit keeper_of_the_light lion invoker tusk winter_wyvern grimstroke undying shadow_shaman",
	"winter_wyvern disruptor dazzle grimstroke ringmaster lich wisp techies oracle crystal_maiden bounty_hunter pudge lion rubick dark_willow silencer zuus ancient_apparition rattletrap phoenix",
}
local state = {nextPick = 0, role = nil}
local attributes = {str = "Strength", agi = "Agility", int = "Intelligence", all = "Universal"}

function draft.merge(full, visible)
	local present, nextIndex = {}, 1
	for _, entry in ipairs(visible) do present[entry[1]] = true end
	for index, entry in ipairs(full) do
		if present[entry[1]] then full[index], nextIndex = visible[nextIndex], nextIndex + 1 end
	end
end

function draft.priority(ui, role)
	local result = {}
	for _, entry in ipairs(ui.models[role]) do if entry[2] then result[#result + 1] = entry[1] end end
	return result
end

function draft.enabled(ui, role, hero)
	for _, name in ipairs(draft.priority(ui, role)) do if name == hero then return true end end
	return false
end

function draft.create(group)
	local ui = {enabled = group:Switch("Auto pick", false), priorities = {}, models = {}, updating = false}
	ui.editRole = group:Combo("Edit hero priorities", {"Carry", "Mid", "Offlane", "Soft support", "Hard support"}, 0)
	ui.restricted = group:Switch("Show only recommended heroes", true)
	ui.attributes = group:MultiSelect("Attributes", {
		{"Strength", "panorama/images/primary_attribute_icons/primary_attribute_icon_strength_psd.vtex_c", true},
		{"Agility", "panorama/images/primary_attribute_icons/primary_attribute_icon_agility_psd.vtex_c", true},
		{"Intelligence", "panorama/images/primary_attribute_icons/primary_attribute_icon_intelligence_psd.vtex_c", true},
		{"Universal", "panorama/images/primary_attribute_icons/primary_attribute_icon_all_psd.vtex_c", true},
	}, true)
	local labels = {"Carry priority", "Mid priority", "Offlane priority", "Soft support priority", "Hard support priority"}
	for role, label in ipairs(labels) do
		local entries, preferred = {}, {}
		for token in defaults[role]:gmatch("[%w_]+") do
			local name = "npc_dota_hero_" .. token
			if catalog.heroes[name] then
				preferred[name] = true
				entries[#entries + 1] = {name, "panorama/images/heroes/icons/" .. name .. "_png.vtex_c", true}
			end
		end
		local model, known = {}, {}
		for _, entry in ipairs(entries) do model[#model + 1], known[entry[1]] = {entry[1], true}, true end
		local remaining = {}
		for name in pairs(catalog.heroes) do if not known[name] then remaining[#remaining + 1] = name end end
		table.sort(remaining)
		for _, name in ipairs(remaining) do model[#model + 1] = {name, false} end
		local saved = Config.ReadString("self_play_draft", "role_" .. role, "")
		if saved ~= "" then
			local ok, decoded = pcall(function() return JSON:decode(saved) end)
			if ok and type(decoded) == "table" then
				local merged, seen = {}, {}
				for _, entry in ipairs(decoded) do
					if type(entry) == "table" and type(entry[1]) == "string" and catalog.heroes[entry[1]] and not seen[entry[1]] then
						seen[entry[1]], entry[2] = true, entry[2] and true or false
						merged[#merged + 1] = entry
					end
				end
				for _, entry in ipairs(model) do if not seen[entry[1]] then merged[#merged + 1] = entry end end
				model = merged
			end
		end
		ui.models[role] = model
		Config.WriteString("self_play_draft", "role_" .. role, JSON:encode(model))
		ui.priorities[role] = group:MultiSelect(label .. " heroes", entries, true)
		ui.priorities[role]:DragAllowed(true)
		localization.bind(ui.priorities[role], label .. " heroes", nil, "draft.priorityHelp")
		ui.priorities[role]:SetCallback(function(widget)
			if ui.updating then return end
			local visible = {}
			for _, name in ipairs(widget:List()) do visible[#visible + 1] = {name, widget:Get(name)} end
			draft.merge(ui.models[role], visible)
			Config.WriteString("self_play_draft", "role_" .. role, JSON:encode(ui.models[role]))
		end)
	end
	local function filter()
		ui.updating = true
		for role, widget in ipairs(ui.priorities) do
			local entries = {}
			for _, entry in ipairs(ui.models[role]) do
				local recommended = entry[2] == true
				for token in defaults[role]:gmatch("[%w_]+") do if entry[1] == "npc_dota_hero_" .. token then recommended = true; break end end
				if (not ui.restricted:Get() or recommended) and ui.attributes:Get(attributes[catalog.heroes[entry[1]].attribute]) then
					entries[#entries + 1] = {entry[1], "panorama/images/heroes/icons/" .. entry[1] .. "_png.vtex_c", entry[2]}
				end
			end
			widget:Update(entries, true, false)
			widget:Visible(role == ui.editRole:Get() + 1)
		end
		ui.updating = false
	end
	ui.editRole:SetCallback(function(widget)
		filter()
		if ui.onRoleChanged then ui.onRoleChanged(widget:Get() + 1) end
	end)
	ui.attributes:SetCallback(filter)
	ui.restricted:SetCallback(filter)
	localization.listen(function()
		local tips = {}
		for _, name in pairs(attributes) do tips[name] = localization.text(name) end
		ui.attributes:UpdateToolTips(tips)
	end)
	filter()
	ui.historyHeader = group:Label("Recent Self Play heroes")
	ui.historyRows, ui.historyStamp = {}, nil
	for i = 1, 8 do ui.historyRows[i] = group:Label("history.row") end
	localization.listen(function() draft.paintHistory(ui) end)
	draft.paintHistory(ui)
	return ui
end

function draft.prettyName(hero)
	local short = hero:gsub("^npc_dota_hero_", ""):gsub("_", " ")
	return short:gsub("(%a)([%w']*)", function(first, rest) return first:upper() .. rest end)
end

function draft.paintHistory(ui)
	local list = persist.history()
	local stamp = #list > 0 and list[1].hero or "empty"
	for i, row in ipairs(ui.historyRows) do
		local entry = list[i]
		if entry and catalog.heroes[entry.hero] then
			local role = entry.role and entry.role > 0 and " · P" .. entry.role or ""
			row:ForceLocalization(i .. ". " .. draft.prettyName(entry.hero) .. role)
		else
			row:ForceLocalization("—")
		end
		row:Visible(entry ~= nil or i == 1)
	end
	ui.historyStamp = stamp
end

function draft.role(selected)
	if selected > 0 then return selected end
	local player = Players.GetLocal()
	if player then
		local data = Player.GetTeamData(player)
		for role, flag in ipairs(roleFlags) do
			if data and data.lane_selection_flags == flag then return role end
		end
	end
	return state.role
end

function draft.team()
	local localPlayer = Players.GetLocal()
	if not localPlayer then return {} end
	local byID, allies = {}, {}
	for _, entry in pairs(catalog.heroes) do byID[entry.id] = entry end
	for _, player in ipairs(Players.GetAll()) do
		if player ~= localPlayer and Entity.GetTeamNum(player) == Entity.GetTeamNum(localPlayer) and #allies < 4 then
			local data = Player.GetTeamData(player)
			if data then
				local role
				for index, flag in ipairs(roleFlags) do if data.lane_selection_flags == flag then role = index; break end end
				local hero = byID[data.selected_hero_id]
				if hero or role then allies[#allies + 1] = {role = role, scores = planner.roleScores(hero)} end
			end
		end
	end
	return allies
end

function draft.auto(ui, available, allies, forcedHero)
	local reserved = {}
	for _, ally in ipairs(allies) do if ally.role then reserved[ally.role] = true end end
	local bestRole, bestHero, bestScore
	for role = 1, 5 do
		local name = forcedHero and draft.enabled(ui, role, forcedHero) and forcedHero
			or draft.choose(available, draft.priority(ui, role), role)
		if name and not reserved[role] then
			local used = {[role] = true}
			local function scoreTeam(index)
				if index > #allies then return 0 end
				local ally, best = allies[index], -math.huge
				for slot = 1, 5 do
					if not used[slot] and (not ally.role or ally.role == slot) then
						used[slot] = true
						best = math.max(best, ally.scores[slot] + scoreTeam(index + 1))
						used[slot] = nil
					end
				end
				return best
			end
			local score = planner.roleScores(catalog.heroes[name])[role] + scoreTeam(1)
			if not bestScore or score > bestScore then bestRole, bestHero, bestScore = role, name, score end
		end
	end
	return bestRole, bestHero
end

function draft.choose(available, priority, role)
	local recent = {}
	for _, entry in ipairs(persist.history()) do if entry.role == role then recent[entry.hero] = true end end
	for _, name in ipairs(priority) do
		if available[name] and not recent[name] then return name end
	end
	for _, name in ipairs(priority) do
		if available[name] then return name end
	end
	local best, score
	for name in pairs(available) do
		local entry = catalog.heroes[name]
		if entry then
			local value = planner.roleScores(entry)[role]
			if not score or value > score or value == score and name < best then best, score = name, value end
		end
	end
	return best
end

function draft.available(root)
	local result, visited = {}, 0
	local function walk(panel, depth)
		visited = visited + 1
		if depth > 12 or visited > 3000 then return end
		if panel:HasClass("HeroCard") then
			if panel:HasClass("Unavailable") or panel:HasClass("AlreadyPicked") or panel:HasClass("Banned") or panel:HasClass("Hidden") then return end
			local picture = panel:FindChildTraverse("HeroImage")
			local source = picture and picture:GetImageSrc()
			local name = source and source:match("(npc_dota_hero_[%w_]+)%.")
			if name and catalog.heroes[name] then result[name] = true end
			return
		end
		for index = 0, panel:GetChildCount() - 1 do
			local child = panel:GetChild(index)
			if child then walk(child, depth + 1) end
		end
	end
	walk(root, 0)
	return result
end

function draft.update(ui, selectedRole, now)
	if not ui.enabled:Get() or now < state.nextPick then return end
	state.nextPick = now + 0.75
	if ui.historyRows then
		local list = persist.history()
		local stamp = #list > 0 and list[1].hero or "empty"
		if stamp ~= ui.historyStamp then draft.paintHistory(ui) end
	end
	local mode = GameRules.GetGameMode()
	if mode ~= 1 and mode ~= 22 and mode ~= 4 and mode ~= 3 and mode ~= 23 then return end
	local root = Panorama.GetPanelByName("DOTAHudPreGame", true)
	if not root or not root:HasClass("DOTA_GAMERULES_STATE_HERO_SELECTION") or root:HasClass("Hidden")
		or root:HasClass("HasSelectedHero") or root:HasClass("IsInBanPhase")
		or not root:HasClass("LocalPlayerInControl") then return end
	local grid = root:FindChildTraverse("HeroGrid")
	if not grid then return end
	local available = draft.available(grid)
	local count = 0
	for _ in pairs(available) do count = count + 1 end
	if mode == 4 and (count == 0 or count > 4) then return end
	local role = draft.role(selectedRole)
	if not role then
		role = ui.editRole:Get() + 1
	end
	local saved = persist.load()
	local forced = saved.hero and available[saved.hero] and saved.hero or nil
	local name
	if role then
		local list = draft.priority(ui, role)
		name = forced and draft.enabled(ui, role, forced) and forced or draft.choose(available, list, role)
	else role, name = draft.auto(ui, available, draft.team(), forced) end
	if not name then return end
	local heroID = catalog.heroes[name].id
	if Engine.RunScript(string.format("$.DispatchEvent('DOTAPickHeroID', %d, false);", heroID), root) then
		state.role, state.nextPick = role, now + 2
		persist.save(role, nil, name)
		persist.pushHistory(name, role)
		draft.paintHistory(ui)
		Log.Write("[SelfPlay draft] Pick requested: " .. name .. " role=" .. role)
	end
end

function draft.reset()
	state.nextPick, state.role = 0, nil
end

return draft
