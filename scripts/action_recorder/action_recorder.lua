--[[
     ~ qLocalization
     ~ automatic localization wrapper for Lua menu interfaces

     ~ author: qfun (qfun_g9s)
]]

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

local localization = qLocalization.new({
	en = {
		ar_group_main = "Main",
		ar_group_way = "Behavior",
		ar_enable = "Enable",
		ar_enable_tip = "Records your orders and replays\nthem exactly by a key",
		ar_gear_extra = "Debug",
		ar_debug = "Debug log",
		ar_debug_tip = "Writes each recorded order\ninto the log",
		ar_record_key = "Record",
		ar_record_key_tip = "Press to start or stop recording.\nThe first order starts the timer",
		ar_play_key = "Replay",
		ar_play_key_tip = "Replays the current recording,\npress again to stop",
		ar_bind_name = "Action Recorder",
		ar_speed = "Replay speed",
		ar_speed_tip = "Percent of the recorded pace",
		ar_delay = "Start delay",
		ar_delay_tip = "Pause before the first replayed\norder, in ms",
		ar_limit = "Order limit",
		ar_limit_tip = "Recording stops after this many\norders",
		ar_path = "Show the path",
		ar_path_tip = "Draws the recorded path and the\ncurrent order on the screen",
		ar_panel = "Status panel",
		ar_panel_tip = "Shows the state, order count\nand timer",
		ar_gear_look = "Panel look",
		ar_panel_scale = "Size",
		ar_panel_x = "Position X",
		ar_panel_y = "Offset from top",
		ar_panel_blur = "Background blur",
		ar_slot = "Recording slot",
		ar_slot_tip = "Choose which of the 5 slots to\nsave to and load from",
		ar_save = "Save recording",
		ar_save_tip = "Saves the current recording\ninto the selected slot",
		ar_load = "Load recording",
		ar_load_tip = "Loads the recording from\nthe selected slot",
		ar_share = "Share string",
		ar_share_tip = "Paste a friend's string here or copy\nyours after Export",
		ar_export = "Export",
		ar_export_tip = "Puts the current recording into\nthe share field, copy it",
		ar_import = "Import",
		ar_import_tip = "Loads the recording from\nthe share field",
		ar_autoload = "Autoload every game",
		ar_autoload_tip = "The chosen slot loads itself when\na new match starts, no loading needed",
		ar_autoslot = "Slot to autoload",
		ar_autoslot_tip = "Which slot is loaded\nautomatically each game",
		ar_slot_1 = "Slot 1",
		ar_slot_2 = "Slot 2",
		ar_slot_3 = "Slot 3",
		ar_slot_4 = "Slot 4",
		ar_slot_5 = "Slot 5",
		ar_back = "Return to start",
		ar_back_tip = "Before replaying, the unit walks to\nthe point where recording started",
		ar_st_idle = "Idle",
		ar_st_rec = "Recording",
		ar_st_play = "Replaying",
		ar_st_done = "Done",
		ar_act_1 = "order",
		ar_act_few = "orders",
		ar_act_many = "orders",
	},
	ru = {
		ar_group_main = "Основное",
		ar_group_way = "Поведение",
		ar_enable = "Включить",
		ar_enable_tip = "Записывает твои приказы и повторяет\nих точно по клавише",
		ar_gear_extra = "Отладка",
		ar_debug = "Отладка в лог",
		ar_debug_tip = "Пишет каждый записанный приказ\nв лог",
		ar_record_key = "Запись",
		ar_record_key_tip = "Нажми, чтобы начать или остановить запись.\nТаймер стартует с первого приказа",
		ar_play_key = "Повтор",
		ar_play_key_tip = "Повторяет текущую запись,\nповторное нажатие останавливает",
		ar_bind_name = "Рекордер действий",
		ar_speed = "Скорость повтора",
		ar_speed_tip = "Процент от записанного темпа",
		ar_delay = "Пауза перед стартом",
		ar_delay_tip = "Пауза перед первым приказом,\nв мс",
		ar_limit = "Лимит приказов",
		ar_limit_tip = "Запись остановится после этого\nчисла приказов",
		ar_path = "Показывать путь",
		ar_path_tip = "Рисует записанный путь и текущий\nприказ на экране",
		ar_panel = "Панель статуса",
		ar_panel_tip = "Показывает состояние, число\nприказов и таймер",
		ar_gear_look = "Оформление",
		ar_panel_scale = "Размер",
		ar_panel_x = "Положение X",
		ar_panel_y = "Отступ сверху",
		ar_panel_blur = "Размытие фона",
		ar_slot = "Слот записи",
		ar_slot_tip = "Выбери, в какой из 5 слотов\nсохранять и загружать записи",
		ar_save = "Сохранить запись",
		ar_save_tip = "Сохраняет текущую запись\nв выбранный слот",
		ar_load = "Загрузить запись",
		ar_load_tip = "Загружает запись из\nвыбранного слота",
		ar_share = "Строка обмена",
		ar_share_tip = "Вставь сюда строку друга или скопируй\nсвою после экспорта",
		ar_export = "Экспорт",
		ar_export_tip = "Кладет текущую запись в поле строки\nобмена, скопируй ее",
		ar_import = "Импорт",
		ar_import_tip = "Загружает запись из\nполя строки обмена",
		ar_autoload = "Автозагрузка в каждой игре",
		ar_autoload_tip = "Выбранный слот сам загружается\nс началом нового матча, грузить не нужно",
		ar_autoslot = "Слот для автозагрузки",
		ar_autoslot_tip = "Какой слот загружать\nавтоматически каждую игру",
		ar_slot_1 = "Слот 1",
		ar_slot_2 = "Слот 2",
		ar_slot_3 = "Слот 3",
		ar_slot_4 = "Слот 4",
		ar_slot_5 = "Слот 5",
		ar_back = "Возврат к точке старта",
		ar_back_tip = "Перед повтором юнит сам возвращается\nв точку, где началась запись",
		ar_st_idle = "Ожидание",
		ar_st_rec = "Запись",
		ar_st_play = "Повтор",
		ar_st_done = "Готово",
		ar_act_1 = "приказ",
		ar_act_few = "приказа",
		ar_act_many = "приказов",
	},
})

local UI = localization.WrapLibrary(Menu)
local L = localization.Get

local K = {
	PLAY_ID = "ar_playback",
	ISSUER = Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
	CONFIG = "action_recorder",
	SLOTS = 5,
	ORDER_NAMES = {
		[Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION] = "Move",
		[Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_TARGET] = "Move target",
		[Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET] = "Attack target",
		[Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_MOVE] = "Attack move",
		[Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION] = "Cast position",
		[Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TARGET] = "Cast target",
		[Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET] = "Cast",
		[Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TOGGLE] = "Toggle",
		[Enum.UnitOrder.DOTA_UNIT_ORDER_HOLD_POSITION] = "Hold",
		[Enum.UnitOrder.DOTA_UNIT_ORDER_STOP] = "Stop",
		[Enum.UnitOrder.DOTA_UNIT_ORDER_PURCHASE_ITEM] = "Buy item",
		[Enum.UnitOrder.DOTA_UNIT_ORDER_SELL_ITEM] = "Sell item",
		[Enum.UnitOrder.DOTA_UNIT_ORDER_DROP_ITEM] = "Drop item",
		[Enum.UnitOrder.DOTA_UNIT_ORDER_GIVE_ITEM] = "Give item",
		[Enum.UnitOrder.DOTA_UNIT_ORDER_PICKUP_ITEM] = "Pick item",
		[Enum.UnitOrder.DOTA_UNIT_ORDER_PICKUP_RUNE] = "Pick rune",
		[Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_DIRECTION] = "Move direction",
	},
	COL_REC = Color(232, 98, 90, 255),
	COL_REC_A = Color(232, 98, 90, 130),
	COL_PLAY = Color(111, 214, 111, 255),
	COL_PLAY_A = Color(111, 214, 111, 130),
	COL_IDLE = Color(150, 154, 160, 255),
	COL_IDLE_A = Color(150, 154, 160, 130),
	COL_TEXT = Color(240, 240, 242, 255),
	COL_GRAY = Color(150, 154, 160, 255),
	COL_SEP = Color(255, 255, 255, 46),
	BG = Color(14, 16, 18, 184),
}

local ui = {}
local state = {
	mode = "idle",
	rec = {},
	count = 0,
	t0 = nil,
	play_t0 = 0,
	play_pos = 1,
	back_start = nil,
	back_sent = false,
	autoload_done = false,
	autoloaded = false,
	fonts = nil,
	draw_error = nil,
	last_log = nil,
}

local VERSION = "1.0.0"
local script = {}
local save_current
local load_slot
local export_current
local import_share

do
	local tab = UI.Create("Scripts", "Scripts", "Action Recorder")
	tab:Icon("\u{f144}")

	local page = tab:Create("Settings")
	local g_main = page:Create("ar_group_main", Enum.GroupSide.Left)
	local g_way = page:Create("ar_group_way", Enum.GroupSide.Right)

	ui.enable = g_main:Switch("ar_enable", false, "\u{f011}")
	ui.enable:ToolTip("ar_enable_tip")
	local g_gear = ui.enable:Gear("ar_gear_extra")
	ui.debug = g_gear:Switch("ar_debug", false, "\u{f188}")
	ui.debug:ToolTip("ar_debug_tip")

	ui.record_key = g_main:Bind("ar_record_key", Enum.ButtonCode.KEY_NONE, "\u{f0c7}")
	ui.record_key:ToolTip("ar_record_key_tip")
	ui.record_key:Properties(L("ar_bind_name"))

	ui.play_key = g_main:Bind("ar_play_key", Enum.ButtonCode.KEY_NONE, "\u{f04b}")
	ui.play_key:ToolTip("ar_play_key_tip")
	ui.play_key:Properties(L("ar_bind_name"))

	ui.speed = g_way:Slider("ar_speed", 25, 200, 100, "%d%%")
	ui.speed:Icon("\u{f017}")
	ui.speed:ToolTip("ar_speed_tip")

	ui.delay = g_way:Slider("ar_delay", 0, 2000, 300, "%d ms")
	ui.delay:Icon("\u{f1ce}")
	ui.delay:ToolTip("ar_delay_tip")

	ui.limit = g_way:Slider("ar_limit", 50, 500, 200, "%d")
	ui.limit:Icon("\u{f1ce}")
	ui.limit:ToolTip("ar_limit_tip")

	ui.back_to_start = g_way:Switch("ar_back", true, "\u{f3c5}")
	ui.back_to_start:ToolTip("ar_back_tip")

	ui.path = g_way:Switch("ar_path", true, "\u{f03e}")
	ui.path:ToolTip("ar_path_tip")

	ui.panel = g_way:Switch("ar_panel", true, "\u{f05a}")
	ui.panel:ToolTip("ar_panel_tip")
	local g_look = ui.panel:Gear("ar_gear_look")
	ui.panel_scale = g_look:Slider("ar_panel_scale", 80, 160, 100, "%d%%")
	ui.panel_scale:Icon("\u{f065}")
	ui.panel_x = g_look:Slider("ar_panel_x", 0, 100, 50, "%d%%")
	ui.panel_x:Icon("\u{f05b}")
	ui.panel_y = g_look:Slider("ar_panel_y", 0, 600, 60, "%d px")
	ui.panel_y:Icon("\u{f338}")
	ui.panel_blur = g_look:Switch("ar_panel_blur", true, "\u{f042}")
	ui.panel_blur:Icon("\u{f042}")

	local slot_keys = {}
	for i = 1, K.SLOTS do
		slot_keys[i] = "ar_slot_" .. i
	end
	ui.slot = g_way:Combo("ar_slot", slot_keys, 0)
	ui.slot:Icon("\u{f02d}")
	ui.slot:ToolTip("ar_slot_tip")

	ui.save = g_way:Button("ar_save", function()
		if save_current ~= nil then save_current() end
	end)
	ui.save:Icon("\u{f0c7}")
	ui.save:ToolTip("ar_save_tip")

	ui.load = g_way:Button("ar_load", function()
		if load_slot ~= nil then load_slot() end
	end)
	ui.load:Icon("\u{f02d}")
	ui.load:ToolTip("ar_load_tip")

	ui.share = g_way:Input("ar_share", "")
	ui.share:Icon("\u{f1e8}")
	ui.share:ToolTip("ar_share_tip")

	ui.export = g_way:Button("ar_export", function()
		if export_current ~= nil then export_current() end
	end)
	ui.export:Icon("\u{f0e5}")
	ui.export:ToolTip("ar_export_tip")

	ui.import = g_way:Button("ar_import", function()
		if import_share ~= nil then import_share() end
	end)
	ui.import:Icon("\u{f381}")
	ui.import:ToolTip("ar_import_tip")

	ui.autoload = g_main:Switch("ar_autoload", false, "\u{f021}")
	ui.autoload:ToolTip("ar_autoload_tip")

	local auto_keys = {}
	for i = 1, K.SLOTS do
		auto_keys[i] = "ar_slot_" .. i
	end
	ui.autoslot = g_main:Combo("ar_autoslot", auto_keys, 0)
	ui.autoslot:Icon("\u{f02d}")
	ui.autoslot:ToolTip("ar_autoslot_tip")
end

local function refresh_disabled()
	local on = ui.enable:Get()
	if not on and state.mode ~= "idle" then
		state.mode = "idle"
	end
	ui.debug:Disabled(not on)
	ui.record_key:Disabled(not on)
	ui.play_key:Disabled(not on)
	ui.speed:Disabled(not on)
	ui.delay:Disabled(not on)
	ui.limit:Disabled(not on)
	ui.back_to_start:Disabled(not on)
	ui.path:Disabled(not on)
	ui.panel:Disabled(not on)
	ui.panel_scale:Disabled(not on or not ui.panel:Get())
	ui.panel_x:Disabled(not on or not ui.panel:Get())
	ui.panel_y:Disabled(not on or not ui.panel:Get())
	ui.panel_blur:Disabled(not on or not ui.panel:Get())
	ui.slot:Disabled(not on)
	ui.save:Disabled(not on)
	ui.load:Disabled(not on)
	ui.share:Disabled(not on)
	ui.export:Disabled(not on)
	ui.import:Disabled(not on)
	ui.autoload:Disabled(not on)
	ui.autoslot:Disabled(not on or not ui.autoload:Get())
end

ui.enable:SetCallback(refresh_disabled, true)
ui.panel:SetCallback(refresh_disabled)
ui.autoload:SetCallback(refresh_disabled)

local function log(text)
	if not ui.debug:Get() then return end
	if state.last_log == text then return end
	state.last_log = text
	Log.Write("[Action Recorder] " .. text)
end

local function order_name(order)
	return K.ORDER_NAMES[order] or ("Order " .. tostring(order))
end

local function plural(n, one, few, many)
	local m10, m100 = n % 10, n % 100
	if m10 == 1 and m100 ~= 11 then return L(one) end
	if m10 >= 2 and m10 <= 4 and (m100 < 12 or m100 > 14) then return L(few) end
	return L(many)
end

local function format_time(t)
	local s = math.max(0, math.floor(t))
	return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

local function describe_npc(ent)
	if ent == nil then return nil end
	if not Entity.IsEntity(ent) then return nil end
	if Entity.GetIndex(ent) == nil or Entity.GetIndex(ent) < 0 then return nil end
	if Entity.IsHero(ent) then
		return { role = "hero", ent = ent }
	end
	return { role = "unit", name = Entity.GetUnitName(ent), ent = ent }
end

local function describe_ref(ent)
	if ent == nil then return nil end
	if not Entity.IsEntity(ent) then return nil end
	if Entity.GetIndex(ent) == nil or Entity.GetIndex(ent) < 0 then return nil end
	return { name = Entity.GetUnitName(ent), ent = ent }
end

local function find_npc(desc)
	if desc == nil then return nil end
	if desc.role == "hero" then
		local hero = Heroes.GetLocal()
		if hero ~= nil and Entity.IsAlive(hero) then return hero end
		return nil
	end
	if desc.role == "legacy" then
		local ent = Entity.Get(desc.idx)
		if ent ~= nil and Entity.IsEntity(ent) and Entity.IsAlive(ent) then return ent end
		return nil
	end
	if desc.name == nil then
		return Heroes.GetLocal()
	end
	local hero = Heroes.GetLocal()
	if hero ~= nil and NPC.GetUnitName(hero) == desc.name then
		return hero
	end
	local player = Players.GetLocal()
	if player ~= nil then
		local sel = Player.GetSelectedUnits(player)
		if sel ~= nil then
			for i = 1, #sel do
				if NPC.GetUnitName(sel[i]) == desc.name and Entity.IsAlive(sel[i]) then
					return sel[i]
				end
			end
		end
	end
	if hero ~= nil then
		local units = Entity.GetUnitsInRadius(hero, 2500, Enum.TeamType.TEAM_FRIEND)
		if units ~= nil then
			for i = 1, #units do
				if NPC.GetUnitName(units[i]) == desc.name and Entity.IsAlive(units[i]) then
					return units[i]
				end
			end
		end
	end
	return nil
end

local function find_ref(desc)
	if desc == nil then return nil end
	if desc.role ~= nil then
		return find_npc(desc)
	end
	local hero = Heroes.GetLocal()
	if desc.name == nil or desc.name == "" then
		return nil
	end
	local player = Players.GetLocal()
	if player ~= nil then
		local sel = Player.GetSelectedUnits(player)
		if sel ~= nil then
			for i = 1, #sel do
				if NPC.GetUnitName(sel[i]) == desc.name and Entity.IsAlive(sel[i]) then
					return sel[i]
				end
			end
		end
	end
	if hero ~= nil then
		local enemies = Entity.GetHeroesInRadius(hero, 1600, Enum.TeamType.TEAM_ENEMY)
		if enemies ~= nil then
			for i = 1, #enemies do
				if NPC.GetUnitName(enemies[i]) == desc.name and Entity.IsAlive(enemies[i]) then
					return enemies[i]
				end
			end
		end
	end
	return nil
end

local function parse_pos(s)
	if s == nil or s == "0" then return nil end
	local x, y, z = string.match(s, "([%-%d%.]+)|([%-%d%.]+)|([%-%d%.]+)")
	if x == nil then return nil end
	return { x = tonumber(x), y = tonumber(y), z = tonumber(z) }
end

local function serialize()
	local parts = {}
	for i = 1, state.count do
		local rec = state.rec[i]
		local nr = rec.npc.role == "hero" and "0" or "1"
		local nn = rec.npc.name or "0"
		local tn, tp = "0", "0"
		if rec.target ~= nil then
			tn = rec.target.name or "0"
			if rec.target.pos ~= nil then
				tp = string.format("%.1f|%.1f|%.1f", rec.target.pos.x, rec.target.pos.y, rec.target.pos.z)
			end
		end
		local an = rec.ability or "0"
		local rp = "0"
		if rec.pos ~= nil then
			rp = string.format("%.1f|%.1f|%.1f", rec.pos.x, rec.pos.y, rec.pos.z)
		end
		parts[i] = table.concat({
			string.format("%.3f", rec.t),
			tostring(rec.order),
			nr, nn, tn, tp, an, rp,
			rec.queue and "1" or "0",
		}, ",")
	end
	return table.concat(parts, ";")
end

local function deserialize(data)
	if data == nil or data == "" then return nil end
	local out = {}
	local n = 0
	for chunk in string.gmatch(data, "[^;]+") do
		local t, o, nr, nn, tn, tp, an, rp, q = string.match(chunk,
			"([^,]+),([^,]+),([^,]+),([^,]+),([^,]+),([^,]+),([^,]+),([^,]+),([^,]+)")
		if t ~= nil then
			n = n + 1
			out[n] = {
				t = tonumber(t),
				order = tonumber(o),
				npc = {
					role = nr == "0" and "hero" or "unit",
					name = nn ~= "0" and nn or nil,
				},
				target = tn ~= "0" and { name = tn, pos = parse_pos(tp) } or nil,
				ability = an ~= "0" and an or nil,
				pos = parse_pos(rp),
				queue = q == "1",
			}
		else
			local lt, lo, lnpc, ltarget, lability, lpos, lq = string.match(chunk,
				"([^,]+),([^,]+),([^,]+),([^,]+),([^,]+),([^,]+),([^,]+)")
			if lt ~= nil then
				n = n + 1
				local idx_npc = tonumber(lnpc)
				local idx_target = tonumber(ltarget)
				out[n] = {
					t = tonumber(lt),
					order = tonumber(lo),
					npc = { role = "legacy", idx = idx_npc },
					target = idx_target ~= nil and idx_target > 0 and { role = "legacy", idx = idx_target } or nil,
					ability = nil,
					pos = parse_pos(lpos),
					queue = lq == "1",
				}
			end
		end
	end
	if n == 0 then return nil end
	return out
end

save_current = function()
	if state.count < 1 then
		log("nothing to save")
		return
	end
	local slot = ui.slot:Get() + 1
	Config.WriteString(K.CONFIG, "slot_" .. slot, serialize())
	state.mode = "idle"
	log("saved " .. state.count .. " orders to slot " .. slot)
end

load_slot = function()
	local slot = ui.slot:Get() + 1
	local data = Config.ReadString(K.CONFIG, "slot_" .. slot, "")
	local rec = deserialize(data)
	if rec == nil then
		log("slot " .. slot .. " is empty")
		return
	end
	state.rec = rec
	state.count = #rec
	state.mode = "idle"
	state.play_pos = 1
	log("loaded " .. state.count .. " orders from slot " .. slot)
end

export_current = function()
	if state.count < 1 then
		log("nothing to export")
		return
	end
	ui.share:Set("AR1:" .. serialize())
	log("exported " .. state.count .. " orders to the share field")
end

import_share = function()
	local raw = ui.share:Get()
	if raw == nil or raw == "" then
		log("share field is empty")
		return
	end
	local prefix, payload = string.match(raw, "^(AR1:)(.+)$")
	if payload == nil then
		log("not a recorder share string")
		return
	end
	local rec = deserialize(payload)
	if rec == nil then
		log("share string is corrupted")
		return
	end
	state.rec = rec
	state.count = #rec
	state.mode = "idle"
	state.play_pos = 1
	log("imported " .. state.count .. " orders from the share field")
end

local function replay_order(rec)
	local player = Players.GetLocal()
	if player == nil then return end
	local npc = find_npc(rec.npc)
	if npc == nil or not Entity.IsAlive(npc) then
		log("skip " .. order_name(rec.order) .. ": no matching unit")
		return
	end
	local target = find_ref(rec.target)
	if rec.target ~= nil and (target == nil or not Entity.IsAlive(target)) then
		log("skip " .. order_name(rec.order) .. ": target not found")
		return
	end
	local ability = nil
	if rec.ability ~= nil and rec.ability ~= "" then
		ability = NPC.GetAbility(npc, rec.ability)
		if ability == nil then
			log("skip " .. order_name(rec.order) .. ": ability missing, " .. tostring(rec.ability))
			return
		end
	end
	local pos = nil
	if rec.pos ~= nil then
		pos = Vector(rec.pos.x, rec.pos.y, rec.pos.z)
	end
	local issuer = K.ISSUER
	local npc_arg = npc
	if rec.order_issuer == Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_SELECTED_UNITS then
		issuer = Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_SELECTED_UNITS
		Player.ClearSelectedUnits(player)
		Player.AddSelectedUnit(player, npc)
		npc_arg = npc
	end
	Player.PrepareUnitOrders(player, rec.order, target, pos, ability, issuer, npc_arg, rec.queue, false, false, false, K.PLAY_ID)
	log("replay " .. order_name(rec.order))
end

function script.OnUpdate()
	if not ui.enable:Get() then return end
	local gs = GameRules.GetGameState()
	if gs ~= Enum.GameState.DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then return end

	if not state.autoload_done then
		state.autoload_done = true
		if ui.autoload:Get() and load_slot ~= nil then
			local saved_slot_sel = ui.slot:Get()
			ui.slot:Set(ui.autoslot:Get())
			load_slot()
			ui.slot:Set(saved_slot_sel)
			state.autoloaded = true
		end
	end

	local now = GameRules.GetGameTime()

	if not Input.IsInputCaptured() then
		if ui.record_key:IsPressed() then
			if state.mode == "rec" then
				state.mode = "idle"
				log("recording stopped, " .. state.count .. " orders")
			elseif state.mode == "play" then
				state.mode = "idle"
				log("playback stopped")
			else
				state.rec = {}
				state.count = 0
				state.t0 = nil
				state.mode = "rec"
				state.back_start = nil
				log("recording started")
			end
		end
		if ui.play_key:IsPressed() then
			if state.mode == "play" then
				state.mode = "idle"
				log("playback stopped")
			elseif state.mode == "rec" then
				log("stop recording first")
			elseif state.count > 0 then
				local start = state.rec[1].pos
				if start ~= nil and ui.back_to_start:Get() then
					local npc = find_npc(state.rec[1].npc)
					if npc ~= nil and Entity.IsAlive(npc) then
						local cur = Entity.GetAbsOrigin(npc)
						if cur:Distance2D(Vector(start.x, start.y, start.z)) > 100 then
							state.back_start = { x = start.x, y = start.y, z = start.z }
							state.back_sent = false
							state.mode = "back"
							log("moving to the start point")
							return
						end
					end
				end
				state.mode = "play"
				state.play_pos = 1
				state.play_t0 = now + ui.delay:Get() / 1000
				log("playback started")
			else
				log("nothing to replay")
			end
		end
	end

	if state.mode == "back" then
		local npc = find_npc(state.rec[1].npc)
		local sp = state.back_start
		if npc == nil or not Entity.IsAlive(npc) or sp == nil then
			state.mode = "idle"
			log("cannot reach the start point, unit is gone")
			return
		end
		if not state.back_sent then
			local player = Players.GetLocal()
			if player == nil then return end
			local target = Vector(sp.x, sp.y, sp.z)
			Player.PrepareUnitOrders(player, Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION, nil, target, nil, K.ISSUER, npc, false, false, false, false, K.PLAY_ID)
			state.back_sent = true
			return
		end
		local cur = Entity.GetAbsOrigin(npc)
		local target = Vector(sp.x, sp.y, sp.z)
		if cur:Distance2D(target) <= 100 then
			state.mode = "play"
			state.play_pos = 1
			state.play_t0 = now + ui.delay:Get() / 1000
			log("playback started")
		end
	end

	if state.mode == "play" then
		local speed = math.max(ui.speed:Get(), 1) / 100
		local virt = (now - state.play_t0) * speed
		local i = state.play_pos
		while i <= state.count and state.rec[i].t <= virt do
			replay_order(state.rec[i])
			i = i + 1
		end
		state.play_pos = i
		if i > state.count then
			state.mode = "idle"
			log("playback finished")
		end
	end
end

function script.OnPrepareUnitOrders(data)
	if not ui.enable:Get() then return true end
	if state.mode ~= "rec" then return true end
	if data.identifier == K.PLAY_ID then return true end

	local npc = data.npc
	if npc == nil then
		local player = data.player ~= nil and data.player or Players.GetLocal()
		if player ~= nil then
			local sel = Player.GetSelectedUnits(player)
			if sel ~= nil and #sel > 0 then
				npc = sel[1]
			end
		end
	end
	if npc == nil then
		npc = Heroes.GetLocal()
	end
	if npc == nil then
		log("skip: no npc anywhere, order " .. tostring(data.order))
		return true
	end
	local npc_desc = describe_npc(npc)
	if npc_desc == nil then
		log("skip: npc index invalid, class " .. tostring(Entity.GetClassName(npc)))
		return true
	end

	local now = GameRules.GetGameTime()
	if state.t0 == nil then
		state.t0 = now
	end
	local pos = data.position
	state.count = state.count + 1
	state.rec[state.count] = {
		t = now - state.t0,
		order = data.order,
		npc = npc_desc,
		order_issuer = data.orderIssuer,
		target = describe_ref(data.target),
		ability = data.ability ~= nil and Ability.GetName(data.ability) or nil,
		pos = pos ~= nil and { x = pos.x, y = pos.y, z = pos.z } or nil,
		queue = data.queue == true,
	}
	log(order_name(data.order) .. " at " .. string.format("%.2f", state.rec[state.count].t) .. "s")
	if state.count >= ui.limit:Get() then
		state.mode = "idle"
		log("order limit reached, recording stopped")
	end
	return true
end

function script.OnGameEnd()
	state.mode = "idle"
	state.rec = {}
	state.count = 0
	state.play_pos = 1
	state.autoload_done = false
	state.autoloaded = false
end

local function ensure_fonts()
	if state.fonts ~= nil then return end
	state.fonts = {
		bold = Render.LoadFont("Inter", Enum.FontCreate.FONTFLAG_ANTIALIAS, Enum.FontWeight.BOLD),
		normal = Render.LoadFont("Inter", Enum.FontCreate.FONTFLAG_ANTIALIAS, Enum.FontWeight.NORMAL),
		glyph = Render.LoadFont("FontAwesomeEx", Enum.FontCreate.FONTFLAG_ANTIALIAS, 400),
	}
end

local function path_color()
	if state.mode == "rec" then
		return K.COL_REC, K.COL_REC_A
	elseif state.mode == "play" then
		return K.COL_PLAY, K.COL_PLAY_A
	end
	return K.COL_IDLE, K.COL_IDLE_A
end

local function draw_path()
	if not ui.path:Get() then return end
	if state.count < 1 then return end
	local col, col_line = path_color()
	local mark = state.count
	if state.mode == "play" then
		mark = math.min(state.play_pos, state.count)
	end
	local scale = ui.panel_scale:Get() / 100
	local theme = Menu.Style("primary")
	local prev = nil
	for i = 1, state.count do
		local rec = state.rec[i]
		if rec.pos ~= nil then
			local sp, vis = Render.WorldToScreen(Vector(rec.pos.x, rec.pos.y, rec.pos.z))
			if vis then
				local passed = i < mark
				if prev ~= nil then
					local line_col = passed and col or col_line
					Render.Line(prev, sp, line_col, passed and 2.0 or 1.0)
				end
				if i == 1 then
					Render.FilledCircle(sp, 8 * scale, Color(theme.r, theme.g, theme.b, 60))
					Render.Circle(sp, 5 * scale, col, 1.5)
				elseif i == mark then
					Render.FilledCircle(sp, 5 * scale, col)
				else
					Render.FilledCircle(sp, 2.5, col_line)
				end
				prev = sp
			else
				prev = nil
			end
		else
			prev = nil
		end
	end
	if state.mode == "play" and state.play_pos > 1 then
		local rec = state.rec[state.play_pos - 1]
		if rec ~= nil and rec.target ~= nil then
			local ent = find_ref(rec.target)
			if ent ~= nil and Entity.IsAlive(ent) then
				local sp, vis = Render.WorldToScreen(Entity.GetAbsOrigin(ent))
				if vis then
					Render.Circle(sp, 14 * scale, col, 1.5)
				end
			end
		end
	end
end

local function mono_width(font, size, text)
	local w = 0
	for i = 1, #text do
		local c = text:sub(i, i)
		if c ~= ":" then
			local s = Render.TextSize(font, size, c)
			if s.x > w then w = s.x end
		end
	end
	return w * #text
end

local function draw_mono(font, size, text, x, y, color)
	local w = 0
	for i = 1, #text do
		local c = text:sub(i, i)
		if c ~= ":" then
			local s = Render.TextSize(font, size, c)
			if s.x > w then w = s.x end
		end
	end
	for i = 1, #text do
		Render.Text(font, size, text:sub(i, i), Vec2(x, y), color)
		x = x + w
	end
end

local function draw_panel()
	if not ui.panel:Get() then return end
	local f = state.fonts
	local scale = ui.panel_scale:Get() / 100
	local screen = Render.ScreenSize()
	local h = math.floor(26 * scale / 2 + 0.5) * 2
	local theme = Menu.Style("primary")
	local dt = math.min(0.1, GlobalVars.GetAbsFrameTime())

	state.alpha = state.alpha == nil and 1 or math.min(1, state.alpha + dt * 6)
	local ga = math.floor(255 * state.alpha + 0.5)

	local icon, status, col
	if state.mode == "rec" then
		local pulse = 0.5 + 0.5 * math.sin(os.clock() * 4)
		col = Color(
			math.floor(K.COL_REC.r * (0.55 + 0.45 * pulse) + 0.5),
			math.floor(K.COL_REC.g * (0.55 + 0.45 * pulse) + 0.5),
			math.floor(K.COL_REC.b * (0.55 + 0.45 * pulse) + 0.5),
			ga
		)
		icon, status = "\u{f111}", L("ar_st_rec")
	elseif state.mode == "play" or state.mode == "back" then
		icon, status, col = "\u{f04b}", L("ar_st_play"), K.COL_PLAY
	elseif state.count > 0 then
		icon, status, col = "\u{f04d}", L("ar_st_done"), K.COL_IDLE
	else
		icon, status, col = "\u{f04d}", L("ar_st_idle"), K.COL_IDLE
	end
	if col.a ~= ga then
		col = Color(col.r, col.g, col.b, ga)
	end

	local bsize, nsize, gsize = 12 * scale, 11 * scale, 11 * scale
	local gs = Render.TextSize(f.glyph, gsize, icon)
	local ss = Render.TextSize(f.bold, bsize, status)
	local detail
	if state.mode == "play" then
		detail = string.format("%d / %d", math.min(state.play_pos - 1, state.count), state.count)
	else
		detail = state.count .. " " .. plural(state.count, "ar_act_1", "ar_act_few", "ar_act_many")
	end
	local ds = Render.TextSize(f.normal, nsize, detail)

	local timer = ""
	if state.mode == "rec" and state.t0 ~= nil then
		timer = format_time(GameRules.GetGameTime() - state.t0)
	elseif state.mode == "play" then
		timer = format_time(GameRules.GetGameTime() - (state.play_t0 - ui.delay:Get() / 1000))
	end

	local pad_l, gap, pad_r = 10 * scale, 8 * scale, 12 * scale
	local icon_r = (h - 8 * scale) / 2
	local w = pad_l + icon_r * 2 + 3 * scale + gap + ss.x + gap + 1 + gap + ds.x + pad_r
	if timer ~= "" then
		w = w + gap + 1 + gap + mono_width(f.bold, bsize, timer)
	end
	w = math.floor(w / 2 + 0.5) * 2

	local x = math.floor((screen.x - w) * (ui.panel_x:Get() / 100))
	local y = math.floor(ui.panel_y:Get() * scale)

	local a = Vec2(x, y)
	local b = Vec2(x + w, y + h)
	if ui.panel_blur:Get() then
		Render.Blur(a, b, 1.0, 0.6, h / 2, Enum.DrawFlags.RoundCornersAll)
	end
	Render.FilledRect(a, b, Color(K.BG.r, K.BG.g, K.BG.b, math.floor(K.BG.a * state.alpha + 0.5)), h / 2, Enum.DrawFlags.RoundCornersAll)

	local icon_bg = Color(theme.r, theme.g, theme.b, math.floor(34 * state.alpha + 0.5))
	Render.FilledCircle(Vec2(x + pad_l + icon_r, y + h / 2), icon_r + 3 * scale, icon_bg)
	Render.Text(f.glyph, gsize, icon, Vec2(x + pad_l, y + h / 2 - gs.y / 2), col)

	local cy = y + h / 2
	local cx = x + pad_l + icon_r * 2 + 3 * scale + gap
	Render.Text(f.bold, bsize, status, Vec2(cx, cy - ss.y / 2), Color(K.COL_TEXT.r, K.COL_TEXT.g, K.COL_TEXT.b, ga))
	cx = cx + ss.x + gap
	Render.FilledRect(Vec2(cx, cy - 7 * scale), Vec2(cx + 1, cy + 7 * scale), Color(K.COL_SEP.r, K.COL_SEP.g, K.COL_SEP.b, math.floor(K.COL_SEP.a * state.alpha + 0.5)))
	cx = cx + 1 + gap
	Render.Text(f.normal, nsize, detail, Vec2(cx, cy - ds.y / 2), Color(K.COL_GRAY.r, K.COL_GRAY.g, K.COL_GRAY.b, ga))
	cx = cx + ds.x
	if timer ~= "" then
		cx = cx + gap
		Render.FilledRect(Vec2(cx, cy - 7 * scale), Vec2(cx + 1, cy + 7 * scale), Color(K.COL_SEP.r, K.COL_SEP.g, K.COL_SEP.b, math.floor(K.COL_SEP.a * state.alpha + 0.5)))
		cx = cx + 1 + gap
		draw_mono(f.bold, bsize, timer, cx, cy - ss.y / 2, col)
	end

	if state.mode == "play" and state.count > 0 then
		local percent = math.min(1, (state.play_pos - 1) / state.count)
		local bar_h = math.max(2, math.floor(2 * scale + 0.5))
		Render.PushClip(a, b, false)
		Render.FilledRect(Vec2(x, y + h - bar_h), Vec2(x + w * percent, y + h), Color(K.COL_PLAY.r, K.COL_PLAY.g, K.COL_PLAY.b, 190))
		Render.PopClip()
	end
end

local function draw()
	ensure_fonts()
	draw_path()
	draw_panel()
end

function script.OnDraw()
	if not ui.enable:Get() then return end
	local ok, err = pcall(draw)
	if not ok and err ~= state.draw_error then
		state.draw_error = err
		Log.Write("[Action Recorder] draw: " .. tostring(err))
	end
end

return script
