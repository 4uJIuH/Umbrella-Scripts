local qLocalization = (function()
	local lib = {}

	local a = function(...)
		return ...
	end

	local state = {
		lang = Menu.Find("SettingsHidden", "", "", "", "Main", "Language"),
		instances = {},
	}

	local setters = {
		ToolTip = "tooltip",
	}

	local helpers
	do
		helpers = {
			resolve = a(function(root, path)
				for key in path:gmatch("[^.]+") do
					if type(root) ~= "table" then
						return
					end

					root = root[key]
				end

				return root
			end),

			is_object = a(function(value)
				return type(value) == "table" or type(value) == "userdata"
			end),

			has_method = a(function(object, name)
				return helpers.is_object(object) and type(object[name]) == "function"
			end),

			is_menu_object = a(function(value)
				return helpers.has_method(value, "Name") and helpers.has_method(value, "Type")
			end),

			is_list = a(function(value)
				if type(value) ~= "table" or #value == 0 then
					return false
				end

				for i = 1, #value do
					if type(value[i]) ~= "string" then
						return false
					end
				end

				return true
			end),

			is_indexed_list = a(function(object)
				return helpers.has_method(object, "List") and not helpers.has_method(object, "ListEnabled")
			end),
		}
	end

	function lib.new(translations)
		local languages = {}

		for i, name in ipairs(state.lang and state.lang:List() or {}) do
			local code = name:match("%a+")

			if code and translations[code] then
				languages[i - 1] = code
			end
		end

		local localization = {
			translations = translations,
			languages = languages,
			objects = {},
		}

		local methods
		do
			methods = {
				get_language = a(function(language_index)
					if language_index == nil and state.lang then
						language_index = state.lang:Get()
					end

					return localization.languages[language_index] or "en"
				end),

				localize = a(function(path, language_index)
					if type(path) ~= "string" then
						return path
					end

					local language = methods.get_language(language_index)

					return helpers.resolve(localization.translations[language], path)
						or helpers.resolve(localization.translations.en, path)
						or path
				end),

				has = a(function(path)
					if type(path) ~= "string" then
						return false
					end

					return helpers.resolve(localization.translations.en, path) ~= nil
						or helpers.resolve(localization.translations[methods.get_language()], path) ~= nil
				end),

				localize_items = a(function(items, language_index)
					local result, localized = {}, false

					for i = 1, #items do
						local value = items[i]

						if methods.has(value) then
							result[i] = methods.localize(value, language_index)
							localized = true
						else
							result[i] = value
						end
					end

					return result, localized
				end),

				apply = a(function(object, kind, path, language_index)
					if kind == "label" then
						object:ForceLocalization(methods.localize(path, language_index))
					elseif kind == "tooltip" then
						object:ToolTip(methods.localize(path, language_index))
					elseif kind == "items" then
						local value = object:Get()

						object:Update((methods.localize_items(path, language_index)))
						object:Set(value)
					end
				end),

				track = a(function(object, kind, path, apply_now)
					local record = localization.objects[object]

					if record == nil then
						record = {}
						localization.objects[object] = record
					end

					record[kind] = path

					if apply_now then
						methods.apply(object, kind, path)
					end
				end),

				register = a(function(object, path)
					if not methods.has(path) or not helpers.has_method(object, "ForceLocalization") then
						return
					end

					methods.track(object, "label", path, true)
				end),

				update = a(function(language_index)
					for object, record in pairs(localization.objects) do
						for kind, path in pairs(record) do
							methods.apply(object, kind, path, language_index)
						end
					end
				end),

				wrap = a(function(target, bind_self)
					if not helpers.is_object(target) then
						return target
					end

					local proxy

					proxy = setmetatable({}, {
						__index = function(_, key)
							local member = target[key]

							if type(member) ~= "function" then
								return member
							end

							return function(...)
								local args = table.pack(...)

								if bind_self and args[1] == proxy then
									table.remove(args, 1)
									args.n = args.n - 1
								end

								if key == "Switch" and args.n < 2 then
									args[2] = false
									args.n = 2
								end

								local name_path, item_paths

								if setters[key] then
									if methods.has(args[1]) then
										methods.track(target, setters[key], args[1], false)

										args[1] = methods.localize(args[1])
									end
								else
									local name_index = bind_self and 1 or args.n

									if methods.has(args[name_index]) then
										name_path = args[name_index]
									end

									local items_index

									if key == "Combo" then
										items_index = 2
									elseif key == "Update" and helpers.is_indexed_list(target) then
										items_index = 1
									end

									if items_index ~= nil and helpers.is_list(args[items_index]) then
										local items, localized = methods.localize_items(args[items_index])

										if localized then
											item_paths = args[items_index]
											args[items_index] = items
										end
									end
								end

								local results

								if bind_self then
									results = table.pack(member(target, table.unpack(args, 1, args.n)))
								else
									results = table.pack(member(table.unpack(args, 1, args.n)))
								end

								for i = 1, results.n do
									local result = results[i]

									if helpers.is_menu_object(result) then
										if name_path then
											methods.register(result, name_path)
										end

										if item_paths then
											methods.track(result, "items", item_paths, false)
											item_paths = nil
										end

										results[i] = methods.wrap(result, true)
									end
								end

								if item_paths then
									methods.track(target, "items", item_paths, false)
								end

								return table.unpack(results, 1, results.n)
							end
						end,

						__newindex = function(_, key, value)
							target[key] = value
						end,
					})

					return proxy
				end),
			}
		end

		state.instances[methods] = true

		return {
			GetLanguage = methods.get_language,

			Get = methods.localize,
			Localize = methods.localize,

			Update = methods.update,
			Register = methods.register,

			Wrap = methods.wrap,

			WrapLibrary = function(library)
				return methods.wrap(library, false)
			end,
		}
	end

	if state.lang then
		state.lang:SetCallback(function(this)
			local language_index = this:Get()

			for methods in pairs(state.instances) do
				methods.update(language_index)
			end
		end, true)
	else
		Log.Write("[qLocalization] Language widget not found, using English fallback")
	end

	return lib
end)()

local VERSION = "1.0.2"

local localization = qLocalization.new({
	en = {
		ru_group_main = "Main", ru_group_runes = "Runes",
		ru_enable = "Enable", ru_enable_tip = "Send controlled units to runes automatically",
		ru_mode = "Mode", ru_mode_tip = "Automatic sends units by itself. Button uses selected units only",
		ru_modes_auto = "Automatic", ru_modes_button = "By button",
		ru_key = "Send selected units", ru_key_tip = "Send selected units to the next river rune spots",
		ru_gear_extra = "Extra",
		ru_until = "Until minute", ru_until_tip = "Do not start new trips after this game minute",
		ru_lead = "Send before rune", ru_lead_tip = "Send units this many seconds before the rune appears",
		ru_enemy_radius = "Enemy search radius", ru_enemy_radius_tip = "Break the rune if an enemy hero is within this radius",
		ru_ally_radius = "Ally search radius", ru_ally_radius_tip = "Do not break the rune if an allied hero is within this radius",
		ru_force_break = "Always break rune", ru_force_break_tip = "Break visible runes regardless of nearby allies and rune action",
		ru_water = "Water", ru_water_tip = "Water runes spawn at 2:00 and 4:00",
		ru_power = "Power", ru_power_tip = "Power runes spawn from 6:00, every 2 minutes",
		ru_bounty = "Bounty", ru_bounty_tip = "Bounty runes spawn at 0:00, then every 3 minutes",
		ru_water_action = "Water action", ru_power_action = "Power action",
		ru_bounty_action = "Bounty action",
		ru_actions_pickup = "Pick up", ru_actions_deny = "Deny",
		ru_gear_power = "Power rune types",
		ru_double = "Double damage", ru_haste = "Haste", ru_illusion = "Illusion",
		ru_invis = "Invisibility", ru_regen = "Regeneration", ru_arcane = "Arcane", ru_shield = "Shield",
	},
	ru = {
		ru_group_main = "Основное", ru_group_runes = "Руны",
		ru_enable = "Включить", ru_enable_tip = "Отправлять подконтрольных юнитов к рунам",
		ru_mode = "Режим", ru_mode_tip = "Автоматически отправляет юнитов. По кнопке использует только выделенных",
		ru_modes_auto = "Автоматически", ru_modes_button = "По кнопке",
		ru_key = "Отправить выделенных", ru_key_tip = "Отправить выделенных юнитов к ближайшим river-рунам",
		ru_gear_extra = "Дополнительно",
		ru_until = "До минуты", ru_until_tip = "Не начинать новые походы после этой минуты",
		ru_lead = "Отправлять за", ru_lead_tip = "Отправлять юнитов за столько секунд до появления руны",
		ru_enemy_radius = "Радиус поиска врагов", ru_enemy_radius_tip = "Ломать руну, если в радиусе есть вражеский герой",
		ru_ally_radius = "Радиус поиска союзников", ru_ally_radius_tip = "Не ломать руну, если рядом есть союзный герой",
		ru_force_break = "Всегда ломать руну", ru_force_break_tip = "Ломать руны независимо от союзников и выбранного действия",
		ru_water = "Водяные", ru_water_tip = "Появляются на 2:00 и 4:00",
		ru_power = "Усиления", ru_power_tip = "Появляются с 6:00 каждые 2 минуты",
		ru_bounty = "Богатства", ru_bounty_tip = "Появляются на 0:00 и каждые 3 минуты",
		ru_water_action = "Водяные: действие", ru_power_action = "Усиления: действие",
		ru_bounty_action = "Богатства: действие",
		ru_actions_pickup = "Забрать", ru_actions_deny = "Заденаить",
		ru_gear_power = "Типы усилений",
		ru_double = "Двойной урон", ru_haste = "Ускорение", ru_illusion = "Иллюзии",
		ru_invis = "Невидимость", ru_regen = "Регенерация", ru_arcane = "Магия", ru_shield = "Щит",
	},
})

local UI = localization.WrapLibrary(Menu)
local L = localization.Get
local ui, state = {}, { next_run = 0, spots = {}, tasks = {}, completed = {} }
local K = { STEP = 0.2, ORDER = 1.2, PICKUP = 0.65, ARRIVAL = 140, ATTEMPTS = 8 }


do
	local tab = UI.Create("Scripts", "Scripts", "Rune Units")
	tab:Icon("\u{f4d7}")
	local page = tab:Create("Settings")
	local g_main = page:Create("ru_group_main", Enum.GroupSide.Left)
	local g_runes = page:Create("ru_group_runes", Enum.GroupSide.Right)
	ui.enable = g_main:Switch("ru_enable", false, "\u{f011}")
	ui.enable:ToolTip("ru_enable_tip")
	ui.until_minute = g_main:Slider("ru_until", 1, 90, 20, "%d min")
	ui.until_minute:Icon("\u{f11e}")
	ui.until_minute:ToolTip("ru_until_tip")
	ui.lead = g_main:Slider("ru_lead", 5, 60, 30, "%d s")
	ui.lead:Icon("\u{f1ce}")
	ui.lead:ToolTip("ru_lead_tip")
	ui.enemy_radius = g_main:Slider("ru_enemy_radius", 0, 3000, 1000, "%d")
	ui.enemy_radius:ToolTip("ru_enemy_radius_tip")
	ui.ally_radius = g_main:Slider("ru_ally_radius", 0, 3000, 2000, "%d")
	ui.ally_radius:ToolTip("ru_ally_radius_tip")
	ui.force_break = g_main:Switch("ru_force_break", false, "\u{f05b}")
	ui.force_break:ToolTip("ru_force_break_tip")
	ui.mode = g_main:Combo("ru_mode", { "ru_modes_auto", "ru_modes_button" }, 0)
	ui.mode:Icon("\u{f1de}")
	ui.mode:ToolTip("ru_mode_tip")
	ui.key = g_main:Bind("ru_key", Enum.ButtonCode.KEY_NONE, "\u{f11c}")
	ui.key:ToolTip("ru_key_tip")
	ui.key:Properties(L("ru_key"))
	local categories = { "water", "power", "bounty" }
	for _, category in ipairs(categories) do
		ui[category] = g_runes:Switch("ru_" .. category, category == "power", "\u{f05b}")
		ui[category]:ToolTip("ru_" .. category .. "_tip")
		ui[category .. "_action"] = g_runes:Combo("ru_" .. category .. "_action", { "ru_actions_pickup", "ru_actions_deny" }, 1)
		ui[category .. "_action"]:Icon("\u{f3c5}")
	end
	local types = ui.power:Gear("ru_gear_power")
	for _, name in ipairs({ "double", "haste", "illusion", "invis", "regen", "arcane", "shield" }) do
		ui[name] = types:Switch("ru_" .. name, true, "\u{f05b}")
	end
	local function refresh_disabled()
		local on = ui.enable:Get()
		ui.until_minute:Disabled(not on)
		ui.lead:Disabled(not on)
		ui.enemy_radius:Disabled(not on)
		ui.ally_radius:Disabled(not on)
		ui.force_break:Disabled(not on)
		ui.mode:Disabled(not on)
		ui.key:Disabled(not on or ui.mode:Get() ~= 1)
		for _, category in ipairs(categories) do
			ui[category]:Disabled(not on)
			ui[category .. "_action"]:Disabled(not on or not ui[category]:Get())
		end
		for _, name in ipairs({ "double", "haste", "illusion", "invis", "regen", "arcane", "shield" }) do
			ui[name]:Disabled(not on or not ui.power:Get())
		end
	end
	ui.enable:SetCallback(refresh_disabled, true)
	ui.mode:SetCallback(refresh_disabled)
	for _, category in ipairs(categories) do ui[category]:SetCallback(refresh_disabled) end
end

local function distance(a, b)
	local x, y = a.x - b.x, a.y - b.y
	return math.sqrt(x * x + y * y)
end

local function spot_key(pos)
	return math.floor(pos.x / 120) .. ":" .. math.floor(pos.y / 120)
end

local function nearby_spot(pos, group)
	local best_key, best_distance
	for key, spot in pairs(state.spots) do
		if spot.group == group then
			local current = distance(pos, spot.pos)
			if current <= 450 and (not best_distance or current < best_distance) then
				best_key, best_distance = key, current
			end
		end
	end
	return best_key
end

local function rune_category(kind)
	if kind == Enum.RuneType.DOTA_RUNE_WATER then return "water" end
	if kind == Enum.RuneType.DOTA_RUNE_BOUNTY then return "bounty" end
	local power = {
		[Enum.RuneType.DOTA_RUNE_DOUBLEDAMAGE] = "double",
		[Enum.RuneType.DOTA_RUNE_HASTE] = "haste",
		[Enum.RuneType.DOTA_RUNE_ILLUSION] = "illusion",
		[Enum.RuneType.DOTA_RUNE_INVISIBILITY] = "invis",
		[Enum.RuneType.DOTA_RUNE_REGENERATION] = "regen",
		[Enum.RuneType.DOTA_RUNE_ARCANE] = "arcane",
		[Enum.RuneType.DOTA_RUNE_SHIELD] = "shield",
	}
	local name = power[kind]
	if name and ui[name]:Get() then return "power" end
	return nil
end

local function refresh_spots(now, force)
	if not force and now < (state.next_spots or 0) then return end
	state.next_spots = now + 15
	for _, entity in ipairs(Entities.GetAll()) do
		local class = Entity.GetClassName(entity)
		if class and class:find("RuneSpawner", 1, true) then
			local group
			if class:find("Bounty", 1, true) then group = "bounty"
			elseif class:find("Powerup", 1, true) then group = "river" end
			if group then
				local pos = Entity.GetAbsOrigin(entity)
				local key = nearby_spot(pos, group) or spot_key(pos)
				state.spots[key] = { pos = pos, group = group }
			end
		end
	end
end

local function next_spawn(group, clock)
	if group == "river" then
		if clock < 120 then return 120, "water" end
		if clock < 240 then return 240, "water" end
		if clock < 360 then return 360, "power" end
		return math.ceil((clock - 0.01) / 120) * 120, "power"
	end
	if group == "bounty" then return math.max(0, math.ceil((clock - 0.01) / 180) * 180), "bounty" end
end

local function spawn_for_visible(category, clock)
	if category == "water" then return clock < 240 and 120 or 240 end
	if category == "power" then return math.max(360, math.floor(clock / 120) * 120) end
	if category == "bounty" then return math.max(0, math.floor(clock / 180) * 180) end
	return nil
end

local function nearest_visible(visible, pos, category)
	local best, best_distance
	for _, entry in pairs(visible) do
		local current = distance(entry.pos, pos)
		if (not category or entry.category == category) and current <= 450 and (not best_distance or current < best_distance) then
			best, best_distance = entry, current
		end
	end
	return best
end

local function find_units(hero, player_id)
	local units = {}
	for _, npc in ipairs(NPCs.GetAll()) do
		if npc ~= hero and Entity.IsAlive(npc) and not Entity.IsDormant(npc)
			and Entity.GetTeamNum(npc) == Entity.GetTeamNum(hero)
			and Entity.IsControllableByPlayer(npc, player_id)
			and not NPC.IsCourier(npc) and not NPC.IsWard(npc)
			and not NPC.IsLaneCreep(npc) and not NPC.IsStructure(npc) then
			units[#units + 1] = npc
		end
	end
	return units
end

local function issue(player, unit, order, rune, pos, identifier)
	local order_pos = order == Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET and Vector(0, 0, 0) or pos
	Player.PrepareUnitOrders(player, order, rune, order_pos, nil,
		Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, unit,
		false, true, false, true, identifier, false)
end

local function selected_river_units(player, hero, player_id)
	local result = {}
	for _, unit in ipairs(Player.GetSelectedUnits(player) or {}) do
		if unit ~= hero and Entity.IsEntity(unit) and Entity.IsAlive(unit)
			and not Entity.IsDormant(unit) and Entity.IsControllableByPlayer(unit, player_id)
			and (not NPC.IsHero(unit) or NPC.IsIllusion(unit)) and not NPC.IsCourier(unit) and not NPC.IsWard(unit)
			and not NPC.IsLaneCreep(unit) and not NPC.IsStructure(unit) then
			result[#result + 1] = unit
		end
	end
	return result
end

local function assign_button_tasks(player, hero, player_id, clock)
	local units = selected_river_units(player, hero, player_id)
	local spots = {}
	for key, spot in pairs(state.spots) do
		if spot.group == "river" then
			local spawn, category = next_spawn("river", clock)
			if spawn then
				spots[#spots + 1] = { key = key, spot = spot, spawn = spawn, category = category }
			end
		end
	end
	table.sort(spots, function(a, b) return distance(Entity.GetAbsOrigin(hero), a.spot.pos) < distance(Entity.GetAbsOrigin(hero), b.spot.pos) end)
	for i = 1, math.min(#units, #spots, 2) do
		local unit = units[i]
		local target = spots[i]
		state.tasks[target.key] = { unit_id = Entity.GetIndex(unit), pos = target.spot.pos,
			spawn = target.spawn, category = target.category, attempts = 0 }
	end
end

local function run_task(task, player, now, clock, unit, rune)
	local pos = task.pos
	local unit_pos = Entity.GetAbsOrigin(unit)
	local action = ui[task.category .. "_action"]:Get()
	if rune then
		local ally_near, enemy_near = false, false
		for _, npc in ipairs(NPCs.GetAll()) do
			if npc ~= unit and NPC.IsHero(npc) and Entity.IsAlive(npc) and not Entity.IsDormant(npc) then
				local team = Entity.GetTeamNum(npc)
				local dist = distance(Entity.GetAbsOrigin(npc), pos)
				if team == Entity.GetTeamNum(unit) and dist <= ui.ally_radius:Get() then ally_near = true end
				if team ~= Entity.GetTeamNum(unit) and dist <= ui.enemy_radius:Get() then enemy_near = true end
			end
		end
		if ally_near and not enemy_near then return end
		if action == 1 or enemy_near then
			if now >= (task.next_order or 0) then
				issue(player, unit, Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET, rune, pos, "rune_units_deny")
				task.next_order = now + K.PICKUP
				task.attempts = (task.attempts or 0) + 1
			end
		else
			if distance(unit_pos, pos) > K.ARRIVAL then
				if now >= (task.next_order or 0) then
					NPC.MoveTo(unit, pos)
					task.next_order = now + K.ORDER
				end
			elseif now >= (task.next_order or 0) then
				issue(player, unit, Enum.UnitOrder.DOTA_UNIT_ORDER_PICKUP_RUNE, rune, pos, "rune_units_pickup")
				task.next_order = now + K.PICKUP
				task.attempts = (task.attempts or 0) + 1
			end
		end
	elseif clock < task.spawn + 4 and now >= (task.next_order or 0) and distance(unit_pos, pos) > K.ARRIVAL then
		NPC.MoveTo(unit, pos)
		task.next_order = now + K.ORDER
	end
end

local script = {}

function script.OnUpdate()
	if not ui.enable:Get() then
		state.tasks, state.completed, state.spots = {}, {}, {}
		state.next_spots, state.last_clock = nil, nil
		return
	end
	if GameRules.IsPaused() then return end
	local now = GameRules.GetGameTime()
	if ui.mode:Get() == 1 and ui.key:IsPressed() and not Input.IsInputCaptured() then
		state.button_pending = true
	end
	if now < state.next_run - 5 then state.next_run = now end
	if now < state.next_run then return end
	state.next_run = now + K.STEP
	local hero, player = Heroes.GetLocal(), Players.GetLocal()
	if not hero or not player then return end
	local mode = ui.mode:Get()
	if state.last_mode ~= nil and state.last_mode ~= mode then
		state.tasks, state.completed = {}, {}
	end
	state.last_mode = mode
	local clock = GameRules.GetDOTATime(false, false)
	if state.last_clock and clock < state.last_clock - 60 then
		state.tasks, state.completed, state.spots = {}, {}, {}
		state.next_spots = nil
	end
	state.last_clock = clock
	if clock < -120 then return end
	local button_pressed = ui.mode:Get() == 1 and state.button_pending
	refresh_spots(now, button_pressed)
	if button_pressed then
		state.button_pending = false
		state.tasks, state.completed = {}, {}
		assign_button_tasks(player, hero, Player.GetPlayerID(player), clock)
	end
	if ui.mode:Get() == 1 and next(state.tasks) == nil then return end
	local player_id = Player.GetPlayerID(player)
	local units = find_units(hero, player_id)
	local active, reserved, candidates, candidate_reserved = {}, {}, {}, {}
	local visible = {}
	for _, rune in ipairs(Runes.GetAll()) do
		if Entity.IsEntity(rune) and not Entity.IsDormant(rune) then
			local category = rune_category(Rune.GetRuneType(rune))
			if category and ui[category]:Get() then
				local pos = Entity.GetAbsOrigin(rune)
				local group = (category == "water" or category == "power") and "river" or category
				local key = nearby_spot(pos, group) or spot_key(pos)
				visible[key] = { rune = rune, category = category, pos = pos }
				if not state.spots[key] then
					state.spots[key] = { pos = pos, group = group }
				end
			end
		end
	end
	for key, task in pairs(state.tasks) do
		local unit
		for _, npc in ipairs(units) do
			if Entity.GetIndex(npc) == task.unit_id then unit = npc; break end
		end
		local seen = visible[key] or nearest_visible(visible, task.pos, task.category)
		if seen then task.pos = seen.pos end
		local keep_task = seen or clock <= task.spawn + 4
		local attempts_ok = seen or (task.attempts or 0) < K.ATTEMPTS
		if unit and ui[task.category]:Get() and keep_task and attempts_ok then
			active[key] = task
			reserved[task.unit_id] = true
			run_task(task, player, now, clock, unit, seen and seen.rune or nil)
		else
			if not seen and clock > task.spawn + 12 then
				state.completed[key] = task.spawn
			end
			state.tasks[key] = nil
		end
	end
	for key, spot in pairs(state.spots) do
		if not active[key] then
			local spawn, category = next_spawn(spot.group, clock)
			local seen = visible[key] or nearest_visible(visible, spot.pos, spot.group == "river" and nil or spot.group)
			if seen then
				category = seen.category
				spawn = spawn_for_visible(category, clock)
			end
			local river_prepare = spot.group == "river" and clock >= spawn - ui.lead:Get() and clock <= spawn + 3
			if category and ui[category]:Get() and spawn and spawn <= ui.until_minute:Get() * 60
				and (seen or state.completed[key] ~= spawn and river_prepare) then
				local available, best, best_eta = false, nil, nil
				for _, npc in ipairs(units) do
					local id = Entity.GetIndex(npc)
					if not reserved[id] and not candidate_reserved[id] then
						available = true
						local eta = distance(Entity.GetAbsOrigin(npc), spot.pos) / math.max(100, NPC.GetMoveSpeed(npc))
						if (seen or river_prepare and clock >= spawn - ui.lead:Get())
							and (not best_eta or eta < best_eta) then
							best, best_eta = npc, eta
						end
					end
				end
				if best then
					candidate_reserved[Entity.GetIndex(best)] = true
					candidates[#candidates + 1] = { key = key, spot = spot, unit = best,
						eta = best_eta, spawn = spawn, category = category, rune = seen and seen.rune or nil }
				end
			end
		end
	end
	table.sort(candidates, function(a, b) return a.eta < b.eta end)
	for _, candidate in ipairs(candidates) do
		local id = Entity.GetIndex(candidate.unit)
		if not reserved[id] then
			reserved[id] = true
			local task = { unit_id = id, pos = candidate.spot.pos, spawn = candidate.spawn,
				category = candidate.category, attempts = 0 }
			state.tasks[candidate.key] = task
			run_task(task, player, now, clock, candidate.unit, candidate.rune)
		end
	end
end

return script
