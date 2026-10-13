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
		sn_group_main = "Main",
		sn_group_visual = "Visuals",
		sn_group_model = "Model",
		sn_group_limits = "Thresholds",

		sn_enable = "Enable",
		sn_enable_tip = "Scores how dangerous the enemies\nnear your hero are right now",

		sn_gear_extra = "Extra",
		sn_debug = "Debug log",
		sn_debug_tip = "Writes to the console what the script\nthinks about each enemy",
		sn_memory = "Remember fogged heroes",
		sn_memory_tip = "Keeps the last seen spot of a hero\nwho walked into the fog",
		sn_memory_ttl = "Memory time",

		sn_hold = "Show while held",
		sn_hold_tip = "Hold the key to show the marks.\nNo key means they are always on",
		sn_bind_name = "Sentry",
		sn_reset = "Reset memory",
		sn_reset_tip = "Forgets everything the script remembered",

		sn_panel = "Threat panel",
		sn_panel_tip = "Panel with the total threat score",
		sn_gear_panel = "Panel look",
		sn_scale = "Size",
		sn_dim = "Opacity",
		sn_panel_x = "Offset from left",
		sn_panel_y = "Offset from top",

		sn_marks = "Marks over enemies",
		sn_marks_tip = "Pill above each enemy with his score\nand how soon he reaches you",
		sn_lines = "Movement lines",
		sn_lines_tip = "Line to where the enemy will be\nin a moment",
		sn_rings = "Range rings",
		sn_rings_tip = "Rings around your hero for the close\nand medium distance bands",
		sn_minimap = "Minimap marks",
		sn_minimap_tip = "Circle on the minimap for a hero\nlost in the fog",

		sn_color_low = "Low",
		sn_color_mid = "Medium",
		sn_color_high = "High",
		sn_color_fog = "In the fog",

		sn_react = "Reaction time",
		sn_react_tip = "How many seconds count as a real threat.\nA hero who needs this long scores half",
		sn_w_spell = "Spells",
		sn_w_spell_tip = "How much ready spells add to the score",
		sn_w_burst = "Damage",
		sn_w_burst_tip = "How much of your health he can take\nin the next seconds",
		sn_w_move = "Mobility",
		sn_w_move_tip = "How much a ready blink adds",
		sn_w_allies = "His allies",
		sn_w_allies_tip = "How much the enemies near him add",

		sn_radius = "Close radius",
		sn_radius_tip = "Everyone inside is always shown",
		sn_show = "Show faster than",
		sn_show_tip = "Show an enemy who reaches you\nsooner than this many seconds",
		sn_threshold = "High threat at",
		sn_interval = "Update interval",
		sn_gear_limits = "Fine tuning",
		sn_close = "Contact distance",
		sn_medium = "Mid distance",
		sn_paths = "Path by the map",
		sn_paths_tip = "Time by the real road instead of\na straight line",

		sn_st_none = "no visible threats",
		sn_st_fog = "part of them is in the fog",
		sn_st_heroes = "enemies: %d",
		sn_st_fog_tag = "fog",
		sn_st_proj = "incoming: %d",
		sn_st_haz = "skillshots: %d",
		sn_st_tp = "teleport: %d",
		sn_st_hurt = "hurt: %d%%",
		sn_st_dist = "%d m",
		sn_st_in = "in %s",
		sn_st_now = "next to you",
		sn_st_control = "under control",
		sn_st_smoke = "smoke",
		sn_st_blink = "blink ready",
		sn_st_dead = "dead: %d",
		sn_st_lost = "lost: %d",
		sn_note = "heuristic score, not a probability",

		sn_group_look = "Look",
		sn_group_colors = "Colors",

		sn_panel_rows = "Extra rows",
		sn_panel_rows_tip = "Rows under the main one:\nenemy count, projectiles, teleport",
		sn_panel_x_tip = "Shift of the panel in percent\nof the screen width",

		sn_gear_marks = "Marks",
		sn_show_icon = "Hero icon",
		sn_show_icon_tip = "Icon of the hero on the left\nof the mark",
		sn_show_percent = "Threat percent",
		sn_show_percent_tip = "The main number on the mark",
		sn_show_eta = "Time to reach",
		sn_show_eta_tip = "How soon he gets to you",
		sn_show_dist = "Distance",
		sn_show_dist_tip = "How far he is right now",
		sn_show_tags = "State tags",
		sn_show_tags_tip = "Fog, under control, smoke,\nblink ready",
		sn_show_abilities = "Ready spells",
		sn_show_abilities_tip = "List of his ready spells\nunder the mark",
		sn_ability_lines = "Spell lines",
		sn_ability_lines_tip = "How many spells to list.\n0 turns the list off",
		sn_mark_dx = "Offset X",
		sn_mark_dy = "Offset Y",

		sn_arrows = "Direction arrows",
		sn_arrows_tip = "Arrow at the last seen spot showing\nwhich way he was heading",
		sn_gear_arrows = "Arrows",
		sn_arrow_world = "In the world",
		sn_arrow_map = "On the minimap",
		sn_arrow_len = "Arrow length",
		sn_arrow_wing = "Arrow width",
		sn_arrow_thick = "Thickness",
		sn_arrow_shadow = "Dark outline",
		sn_arrow_shadow_tip = "Dark edge under the arrow so it\nstays readable on any ground",
		sn_arrow_min_speed = "Min speed",
		sn_arrow_min_speed_tip = "Slower than this counts as standing,\nno arrow is drawn",
		sn_arrow_fade = "Fade with age",
		sn_arrow_fade_tip = "The older the position, the dimmer\nthe arrow",

		sn_gear_lines = "Lines",
		sn_line_thick = "Thickness",
		sn_line_head = "Arrow head",
		sn_lines_fog = "Only fogged",
		sn_lines_fog_tip = "Draw the line only for enemies\nwhose position is stale",

		sn_gear_rings = "Rings",
		sn_rings_close = "Close ring",
		sn_rings_medium = "Mid ring",
		sn_ring_thick = "Thickness",
		sn_ring_alpha = "Ring opacity",

		sn_gear_minimap = "Minimap",
		sn_mini_size = "Circle size",
		sn_mini_alpha = "Opacity",
		sn_mini_arrow_len = "Arrow length",

		sn_chat = "Report to chat",
		sn_chat_tip = "Writes to chat when an enemy is\nabout to jump you",
		sn_gear_chat = "Chat",
		sn_chat_where = "Where",
		sn_chat_team = "To the team",
		sn_chat_all = "To everyone",
		sn_chat_threshold = "Report from",
		sn_chat_threshold_tip = "Report only when the chance\nis at least this high",
		sn_chat_cooldown = "Repeat after",
		sn_chat_cooldown_tip = "Do not report the same enemy\nmore often than this",
		sn_chat_msg = "%s may gank you: %d%% (%d m)",
		sn_show_chance = "Attack chance",
		sn_show_chance_tip = "Show the chance he attacks you\nas the main number",

		sn_color_arrow = "Arrows",
		sn_color_ring = "Rings",
		sn_color_line = "Lines",
		sn_color_text = "Text",
		sn_color_bg = "Mark background",
	},
	ru = {
		sn_group_main = "Основное",
		sn_group_visual = "Визуал",
		sn_group_model = "Модель",
		sn_group_limits = "Пороги",

		sn_enable = "Включить",
		sn_enable_tip = "Оценивает, насколько опасны враги\nрядом с героем прямо сейчас",

		sn_gear_extra = "Дополнительно",
		sn_debug = "Отладка в лог",
		sn_debug_tip = "Пишет в консоль, что скрипт думает\nо каждом враге",
		sn_memory = "Помнить героев в тумане",
		sn_memory_tip = "Хранит последнее место, где видели\nгероя, ушедшего в туман",
		sn_memory_ttl = "Время памяти",

		sn_hold = "Показывать по удержанию",
		sn_hold_tip = "Зажми клавишу, чтобы показать метки.\nБез клавиши метки видны всегда",
		sn_bind_name = "Sentry",
		sn_reset = "Сбросить память",
		sn_reset_tip = "Забывает все, что скрипт запомнил",

		sn_panel = "Панель угрозы",
		sn_panel_tip = "Панель с общей оценкой угрозы",
		sn_gear_panel = "Вид панели",
		sn_scale = "Размер",
		sn_dim = "Прозрачность",
		sn_panel_x = "Отступ слева",
		sn_panel_y = "Отступ сверху",

		sn_marks = "Метки над врагами",
		sn_marks_tip = "Плашка над врагом с его оценкой\nи временем до него",
		sn_lines = "Линии движения",
		sn_lines_tip = "Линия туда, где враг окажется\nчерез мгновение",
		sn_rings = "Круги радиуса",
		sn_rings_tip = "Круги вокруг героя для ближней\nи средней дистанции",
		sn_minimap = "Отметки на миникарте",
		sn_minimap_tip = "Круг на миникарте для героя,\nпотерянного в тумане",

		sn_color_low = "Низкая",
		sn_color_mid = "Средняя",
		sn_color_high = "Высокая",
		sn_color_fog = "В тумане",

		sn_react = "Время реакции",
		sn_react_tip = "Сколько секунд считается реальной\nугрозой. Кто идёт столько, берет половину",
		sn_w_spell = "Способности",
		sn_w_spell_tip = "Сколько добавляют готовые\nспособности врага",
		sn_w_burst = "Урон",
		sn_w_burst_tip = "Сколько здоровья он может снять\nза ближайшие секунды",
		sn_w_move = "Мобильность",
		sn_w_move_tip = "Сколько добавляет готовый блинк",
		sn_w_allies = "Его союзники",
		sn_w_allies_tip = "Сколько добавляют враги рядом\nс ним",

		sn_radius = "Радиус рядом",
		sn_radius_tip = "Кто внутри, показывается всегда",
		sn_show = "Показывать быстрее",
		sn_show_tip = "Показывать врага, который дойдет\ndо тебя быстрее этих секунд",
		sn_threshold = "Высокая угроза от",
		sn_interval = "Интервал обновления",
		sn_gear_limits = "Тонкая настройка",
		sn_close = "Дистанция вплотную",
		sn_medium = "Средняя дистанция",
		sn_paths = "Дорога по карте",
		sn_paths_tip = "Время по реальной дороге,\nа не по прямой",

		sn_st_none = "видимых угроз нет",
		sn_st_fog = "часть из них в тумане",
		sn_st_heroes = "врагов: %d",
		sn_st_fog_tag = "туман",
		sn_st_proj = "снаряды: %d",
		sn_st_haz = "скиллшоты: %d",
		sn_st_tp = "телепорт: %d",
		sn_st_hurt = "урон: %d%%",
		sn_st_dist = "%d м",
		sn_st_in = "через %s",
		sn_st_now = "рядом с тобой",
		sn_st_control = "под контролем",
		sn_st_smoke = "смок",
		sn_st_blink = "блинк готов",
		sn_st_dead = "мертвы: %d",
		sn_st_lost = "потеряны: %d",
		sn_note = "эвристическая оценка, не вероятность",
		sn_group_look = "Оформление",
		sn_group_colors = "Цвета",

		sn_panel_rows = "Строк под панелью",
		sn_panel_rows_tip = "Строки под основной: число врагов,\nснаряды, телепорт",
		sn_panel_x_tip = "Сдвиг панели в процентах\nот ширины экрана",

		sn_gear_marks = "Метки",
		sn_show_icon = "Иконка героя",
		sn_show_icon_tip = "Иконка героя слева от метки",
		sn_show_percent = "Процент угрозы",
		sn_show_percent_tip = "Главное число на метке",
		sn_show_eta = "Время до подхода",
		sn_show_eta_tip = "Как скоро он доберется до тебя",
		sn_show_dist = "Дистанция",
		sn_show_dist_tip = "Насколько он далеко сейчас",
		sn_show_tags = "Пометки состояния",
		sn_show_tags_tip = "Туман, под контролем, смок,\nблинк готов",
		sn_show_abilities = "Готовые способности",
		sn_show_abilities_tip = "Список готовых способностей\nпод меткой",
		sn_ability_lines = "Строк способностей",
		sn_ability_lines_tip = "Сколько способностей показывать.\n0 выключает список",
		sn_mark_dx = "Сдвиг по X",
		sn_mark_dy = "Сдвиг по Y",

		sn_arrows = "Стрелки направления",
		sn_arrows_tip = "Стрелка на последнем месте покажет,\nкуда он шел",
		sn_gear_arrows = "Стрелки",
		sn_arrow_world = "В мире",
		sn_arrow_map = "На миникарте",
		sn_arrow_len = "Длина стрелки",
		sn_arrow_wing = "Ширина стрелки",
		sn_arrow_thick = "Толщина",
		sn_arrow_shadow = "Темный контур",
		sn_arrow_shadow_tip = "Темный край под стрелкой, чтобы\nона читалась на любой земле",
		sn_arrow_min_speed = "Минимальная скорость",
		sn_arrow_min_speed_tip = "Медленнее считается стоянием,\nстрелка не рисуется",
		sn_arrow_fade = "Затухание по возрасту",
		sn_arrow_fade_tip = "Чем старее позиция, тем бледнее\nстрелка",

		sn_gear_lines = "Линии",
		sn_line_thick = "Толщина",
		sn_line_head = "Наконечник",
		sn_lines_fog = "Только для тумана",
		sn_lines_fog_tip = "Рисовать линию только врагам,\nчья позиция устарела",

		sn_gear_rings = "Круги",
		sn_rings_close = "Ближний круг",
		sn_rings_medium = "Средний круг",
		sn_ring_thick = "Толщина",
		sn_ring_alpha = "Прозрачность кругов",

		sn_gear_minimap = "Миникарта",
		sn_mini_size = "Размер круга",
		sn_mini_alpha = "Прозрачность",
		sn_mini_arrow_len = "Длина стрелки",

		sn_chat = "Писать в чат",
		sn_chat_tip = "Пишет в чат, когда враг\nсобирается напасть на тебя",
		sn_gear_chat = "Чат",
		sn_chat_where = "Куда писать",
		sn_chat_team = "Команде",
		sn_chat_all = "Всем",
		sn_chat_threshold = "Писать от",
		sn_chat_threshold_tip = "Писать, только если шанс\nне ниже этого",
		sn_chat_cooldown = "Повтор через",
		sn_chat_cooldown_tip = "Не писать про одного врага\nчаще, чем раз в столько секунд",
		sn_chat_msg = "%s может напасть: %d%% (%d м)",
		sn_show_chance = "Шанс нападения",
		sn_show_chance_tip = "Показывать шанс нападения\nглавным числом",

		sn_color_arrow = "Стрелки",
		sn_color_ring = "Круги",
		sn_color_line = "Линии",
		sn_color_text = "Текст",
		sn_color_bg = "Фон метки",
	},
})

local UI = localization.WrapLibrary(Menu)
local L = localization.Get

local script = {}
local ui = {}

do
	local tab = UI.Create("Scripts", "Scripts", "Sentry")
	tab:Icon("\u{f6b6}")

	local page = tab:Create("Settings")
	local g_main = page:Create("sn_group_main", Enum.GroupSide.Left)
	local g_visual = page:Create("sn_group_visual", Enum.GroupSide.Right)
	local g_look = page:Create("sn_group_look", Enum.GroupSide.Left)
	local g_model = page:Create("sn_group_model", Enum.GroupSide.Right)
	local g_limits = page:Create("sn_group_limits", Enum.GroupSide.Left)
	local g_colors = page:Create("sn_group_colors", Enum.GroupSide.Right)

	ui.enable = g_main:Switch("sn_enable", true, "\u{f011}")
	ui.enable:ToolTip("sn_enable_tip")
	local g_extra = ui.enable:Gear("sn_gear_extra")
	ui.debug = g_extra:Switch("sn_debug", false, "\u{f188}")
	ui.debug:ToolTip("sn_debug_tip")
	ui.memory = g_extra:Switch("sn_memory", true, "\u{f06e}")
	ui.memory:ToolTip("sn_memory_tip")
	ui.memory_ttl = g_extra:Slider("sn_memory_ttl", 1.0, 10.0, 5.0, "%.1f s")
	ui.memory_ttl:Icon("\u{f017}")

	ui.hold = g_main:Bind("sn_hold", Enum.ButtonCode.KEY_NONE, "\u{f11c}")
	ui.hold:ToolTip("sn_hold_tip")
	ui.hold:Properties(L("sn_bind_name"))

	ui.reset = g_main:Button("sn_reset", function() script.reset() end)
	ui.reset:Icon("\u{f12d}")
	ui.reset:ToolTip("sn_reset_tip")

	ui.panel = g_visual:Switch("sn_panel", true, "\u{f05a}")
	ui.panel:ToolTip("sn_panel_tip")
	local g_panel = ui.panel:Gear("sn_gear_panel")
	ui.scale = g_panel:Slider("sn_scale", 70, 180, 100, "%d%%")
	ui.scale:Icon("\u{f065}")
	ui.dim = g_panel:Slider("sn_dim", 20, 100, 90, "%d%%")
	ui.dim:Icon("\u{f043}")
	ui.panel_x = g_panel:Slider("sn_panel_x", 0, 90, 2, "%d%%")
	ui.panel_x:Icon("\u{f337}")
	ui.panel_x:ToolTip("sn_panel_x_tip")
	ui.panel_y = g_panel:Slider("sn_panel_y", 0, 800, 180, "%d px")
	ui.panel_y:Icon("\u{f338}")
	ui.panel_rows = g_panel:Slider("sn_panel_rows", 0, 3, 2)
	ui.panel_rows:Icon("\u{f03a}")
	ui.panel_rows:ToolTip("sn_panel_rows_tip")

	ui.marks = g_visual:Switch("sn_marks", true, "\u{f05b}")
	ui.marks:ToolTip("sn_marks_tip")
	local g_marks = ui.marks:Gear("sn_gear_marks")
	ui.show_icon = g_marks:Switch("sn_show_icon", true, "\u{f03e}")
	ui.show_icon:ToolTip("sn_show_icon_tip")
	ui.show_percent = g_marks:Switch("sn_show_percent", true, "\u{f071}")
	ui.show_percent:ToolTip("sn_show_percent_tip")
	ui.show_chance = g_marks:Switch("sn_show_chance", true, "\u{f200}")
	ui.show_chance:ToolTip("sn_show_chance_tip")
	ui.show_eta = g_marks:Switch("sn_show_eta", true, "\u{f017}")
	ui.show_eta:ToolTip("sn_show_eta_tip")
	ui.show_dist = g_marks:Switch("sn_show_dist", true, "\u{f337}")
	ui.show_dist:ToolTip("sn_show_dist_tip")
	ui.show_tags = g_marks:Switch("sn_show_tags", true, "\u{f02b}")
	ui.show_tags:ToolTip("sn_show_tags_tip")
	ui.show_abilities = g_marks:Switch("sn_show_abilities", true, "\u{f0e7}")
	ui.show_abilities:ToolTip("sn_show_abilities_tip")
	ui.ability_lines = g_marks:Slider("sn_ability_lines", 0, 5, 3)
	ui.ability_lines:Icon("\u{f03a}")
	ui.ability_lines:ToolTip("sn_ability_lines_tip")
	ui.mark_dx = g_marks:Slider("sn_mark_dx", -200, 200, -56, "%d px")
	ui.mark_dx:Icon("\u{f337}")
	ui.mark_dy = g_marks:Slider("sn_mark_dy", -200, 200, -66, "%d px")
	ui.mark_dy:Icon("\u{f338}")

	ui.lines = g_visual:Switch("sn_lines", true, "\u{f4d7}")
	ui.lines:ToolTip("sn_lines_tip")
	local g_lines = ui.lines:Gear("sn_gear_lines")
	ui.line_thick = g_lines:Slider("sn_line_thick", 1, 6, 2)
	ui.line_thick:Icon("\u{f065}")
	ui.line_head = g_lines:Switch("sn_line_head", true, "\u{f0da}")
	ui.lines_fog = g_lines:Switch("sn_lines_fog", false, "\u{f06e}")
	ui.lines_fog:ToolTip("sn_lines_fog_tip")

	ui.arrows = g_visual:Switch("sn_arrows", true, "\u{f061}")
	ui.arrows:ToolTip("sn_arrows_tip")
	local g_arrows = ui.arrows:Gear("sn_gear_arrows")
	ui.arrow_world = g_arrows:Switch("sn_arrow_world", true, "\u{f06e}")
	ui.arrow_map = g_arrows:Switch("sn_arrow_map", true, "\u{f279}")
	ui.arrow_len = g_arrows:Slider("sn_arrow_len", 40, 400, 200, "%d")
	ui.arrow_len:Icon("\u{f338}")
	ui.arrow_wing = g_arrows:Slider("sn_arrow_wing", 4, 40, 14, "%d")
	ui.arrow_wing:Icon("\u{f337}")
	ui.arrow_thick = g_arrows:Slider("sn_arrow_thick", 1, 8, 3)
	ui.arrow_thick:Icon("\u{f065}")
	ui.arrow_shadow = g_arrows:Switch("sn_arrow_shadow", true, "\u{f0c8}")
	ui.arrow_shadow:ToolTip("sn_arrow_shadow_tip")
	ui.arrow_min_speed = g_arrows:Slider("sn_arrow_min_speed", 0, 300, 40, "%d")
	ui.arrow_min_speed:Icon("\u{f70c}")
	ui.arrow_min_speed:ToolTip("sn_arrow_min_speed_tip")
	ui.arrow_fade = g_arrows:Switch("sn_arrow_fade", true, "\u{f043}")
	ui.arrow_fade:ToolTip("sn_arrow_fade_tip")

	ui.rings = g_visual:Switch("sn_rings", true, "\u{f1ce}")
	ui.rings:ToolTip("sn_rings_tip")
	local g_rings = ui.rings:Gear("sn_gear_rings")
	ui.rings_close = g_rings:Switch("sn_rings_close", true, "\u{f111}")
	ui.rings_medium = g_rings:Switch("sn_rings_medium", true, "\u{f111}")
	ui.ring_thick = g_rings:Slider("sn_ring_thick", 1, 5, 2)
	ui.ring_thick:Icon("\u{f065}")
	ui.ring_alpha = g_rings:Slider("sn_ring_alpha", 10, 100, 50, "%d%%")
	ui.ring_alpha:Icon("\u{f043}")

	ui.minimap = g_visual:Switch("sn_minimap", false, "\u{f3c5}")
	ui.minimap:ToolTip("sn_minimap_tip")
	local g_mini = ui.minimap:Gear("sn_gear_minimap")
	ui.mini_size = g_mini:Slider("sn_mini_size", 100, 800, 320)
	ui.mini_size:Icon("\u{f065}")
	ui.mini_alpha = g_mini:Slider("sn_mini_alpha", 10, 100, 100, "%d%%")
	ui.mini_alpha:Icon("\u{f043}")
	ui.mini_arrow_len = g_mini:Slider("sn_mini_arrow_len", 300, 2500, 1200)
	ui.mini_arrow_len:Icon("\u{f338}")

	ui.chat = g_main:Switch("sn_chat", false, "\u{f075}")
	ui.chat:ToolTip("sn_chat_tip")
	local g_chat = ui.chat:Gear("sn_gear_chat")
	ui.chat_where = g_chat:Combo("sn_chat_where", { "sn_chat_team", "sn_chat_all" }, 0)
	ui.chat_where:Icon("\u{f0c0}")
	ui.chat_threshold = g_chat:Slider("sn_chat_threshold", 20, 95, 60, "%d%%")
	ui.chat_threshold:Icon("\u{f071}")
	ui.chat_threshold:ToolTip("sn_chat_threshold_tip")
	ui.chat_cooldown = g_chat:Slider("sn_chat_cooldown", 3, 60, 15, "%d s")
	ui.chat_cooldown:Icon("\u{f017}")
	ui.chat_cooldown:ToolTip("sn_chat_cooldown_tip")

	ui.color_low = g_colors:ColorPicker("sn_color_low", Color(161, 147, 255), "\u{f53f}")
	ui.color_mid = g_colors:ColorPicker("sn_color_mid", Color(255, 200, 100))
	ui.color_high = g_colors:ColorPicker("sn_color_high", Color(255, 124, 106))
	ui.color_fog = g_colors:ColorPicker("sn_color_fog", Color(180, 160, 255, 150))
	ui.color_arrow = g_colors:ColorPicker("sn_color_arrow", Color(255, 210, 90))
	ui.color_ring = g_colors:ColorPicker("sn_color_ring", Color(255, 255, 255))
	ui.color_line = g_colors:ColorPicker("sn_color_line", Color(255, 255, 255))
	ui.color_text = g_colors:ColorPicker("sn_color_text", Color(240, 240, 242))
	ui.color_bg = g_colors:ColorPicker("sn_color_bg", Color(14, 16, 18, 184))

	ui.react = g_model:Slider("sn_react", 1.0, 8.0, 3.0, "%.1f s")
	ui.react:Icon("\u{f017}")
	ui.react:ToolTip("sn_react_tip")
	ui.w_spell = g_model:Slider("sn_w_spell", 0, 100, 55, "%d%%")
	ui.w_spell:Icon("\u{f0e7}")
	ui.w_spell:ToolTip("sn_w_spell_tip")
	ui.w_burst = g_model:Slider("sn_w_burst", 0, 100, 60, "%d%%")
	ui.w_burst:Icon("\u{f004}")
	ui.w_burst:ToolTip("sn_w_burst_tip")
	ui.w_move = g_model:Slider("sn_w_move", 0, 100, 45, "%d%%")
	ui.w_move:Icon("\u{f70c}")
	ui.w_move:ToolTip("sn_w_move_tip")
	ui.w_allies = g_model:Slider("sn_w_allies", 0, 100, 40, "%d%%")
	ui.w_allies:Icon("\u{f0c0}")
	ui.w_allies:ToolTip("sn_w_allies_tip")

	ui.radius = g_limits:Slider("sn_radius", 600, 3000, 1600)
	ui.radius:Icon("\u{f1ce}")
	ui.radius:ToolTip("sn_radius_tip")
	ui.show = g_limits:Slider("sn_show", 3, 30, 10, "%d s")
	ui.show:Icon("\u{f06e}")
	ui.show:ToolTip("sn_show_tip")
	ui.threshold = g_limits:Slider("sn_threshold", 30, 95, 70, "%d%%")
	ui.threshold:Icon("\u{f071}")
	ui.interval = g_limits:Slider("sn_interval", 0.05, 0.5, 0.10, "%.2f s")
	ui.interval:Icon("\u{f021}")

	local g_fine = ui.radius:Gear("sn_gear_limits")
	ui.close = g_fine:Slider("sn_close", 200, 900, 450)
	ui.close:Icon("\u{f337}")
	ui.medium = g_fine:Slider("sn_medium", 700, 2200, 1100)
	ui.medium:Icon("\u{f337}")
	ui.paths = g_fine:Switch("sn_paths", true, "\u{f4d7}")
	ui.paths:ToolTip("sn_paths_tip")
end

local function refresh_disabled()
	local on = ui.enable:Get()
	local panel_on = on and ui.panel:Get() or false
	local marks_on = on and ui.marks:Get() or false
	local lines_on = on and ui.lines:Get() or false
	local arrows_on = on and ui.arrows:Get() or false
	local rings_on = on and ui.rings:Get() or false
	local mini_on = on and ui.minimap:Get() or false
	local memory_on = on and ui.memory:Get() or false

	ui.hold:Disabled(not on)
	ui.reset:Disabled(not on)
	ui.panel:Disabled(not on)
	ui.marks:Disabled(not on)
	ui.lines:Disabled(not on)
	ui.arrows:Disabled(not on)
	ui.rings:Disabled(not on)
	ui.minimap:Disabled(not on)

	ui.color_low:Disabled(not on)
	ui.color_mid:Disabled(not on)
	ui.color_high:Disabled(not on)
	ui.color_fog:Disabled(not on)
	ui.color_arrow:Disabled(not arrows_on)
	ui.color_ring:Disabled(not rings_on)
	ui.color_line:Disabled(not lines_on)
	ui.color_text:Disabled(not on)
	ui.color_bg:Disabled(not on)

	ui.react:Disabled(not on)
	ui.w_spell:Disabled(not on)
	ui.w_burst:Disabled(not on)
	ui.w_move:Disabled(not on)
	ui.w_allies:Disabled(not on)
	ui.radius:Disabled(not on)
	ui.show:Disabled(not on)
	ui.threshold:Disabled(not on)
	ui.interval:Disabled(not on)
	ui.debug:Disabled(not on)
	ui.memory:Disabled(not on)
	ui.memory_ttl:Disabled(not memory_on)

	ui.scale:Disabled(not panel_on)
	ui.dim:Disabled(not panel_on)
	ui.panel_x:Disabled(not panel_on)
	ui.panel_y:Disabled(not panel_on)
	ui.panel_rows:Disabled(not panel_on)

	ui.show_icon:Disabled(not marks_on)
	ui.show_percent:Disabled(not marks_on)
	ui.show_chance:Disabled(not marks_on)
	ui.show_eta:Disabled(not marks_on)
	ui.show_dist:Disabled(not marks_on)
	ui.show_tags:Disabled(not marks_on)
	ui.show_abilities:Disabled(not marks_on)
	ui.ability_lines:Disabled(not (marks_on and ui.show_abilities:Get()))
	ui.mark_dx:Disabled(not marks_on)
	ui.mark_dy:Disabled(not marks_on)

	ui.line_thick:Disabled(not lines_on)
	ui.line_head:Disabled(not lines_on)
	ui.lines_fog:Disabled(not lines_on)

	ui.arrow_world:Disabled(not arrows_on)
	ui.arrow_map:Disabled(not arrows_on)
	ui.arrow_len:Disabled(not arrows_on)
	ui.arrow_wing:Disabled(not arrows_on)
	ui.arrow_thick:Disabled(not arrows_on)
	ui.arrow_shadow:Disabled(not arrows_on)
	ui.arrow_min_speed:Disabled(not arrows_on)
	ui.arrow_fade:Disabled(not arrows_on)

	ui.rings_close:Disabled(not rings_on)
	ui.rings_medium:Disabled(not rings_on)
	ui.ring_thick:Disabled(not rings_on)
	ui.ring_alpha:Disabled(not rings_on)

	ui.mini_size:Disabled(not mini_on)
	ui.mini_alpha:Disabled(not mini_on)
	ui.mini_arrow_len:Disabled(not mini_on)

	local chat_on = on and ui.chat:Get() or false
	ui.chat:Disabled(not on)
	ui.chat_where:Disabled(not chat_on)
	ui.chat_threshold:Disabled(not chat_on)
	ui.chat_cooldown:Disabled(not chat_on)

	ui.close:Disabled(not on)
	ui.medium:Disabled(not on)
	ui.paths:Disabled(not on)
end

ui.enable:SetCallback(refresh_disabled, true)
ui.memory:SetCallback(refresh_disabled)
ui.panel:SetCallback(refresh_disabled)
ui.marks:SetCallback(refresh_disabled)
ui.lines:SetCallback(refresh_disabled)
ui.arrows:SetCallback(refresh_disabled)
ui.rings:SetCallback(refresh_disabled)
ui.minimap:SetCallback(refresh_disabled)
ui.show_abilities:SetCallback(refresh_disabled)
ui.chat:SetCallback(refresh_disabled)

local function log(text)
	if ui.debug:Get() then
		Log.Write("[Sentry] " .. text)
	end
end

local K = {
	ABILITY_SLOTS   = 23,
	ITEM_SLOTS      = 17,
	FONT_MAIN       = 13,
	FONT_DETAIL     = 11,
	PILL_H          = 30,
	MAX_AGE         = 1.0,
	TELEPORT_MOD    = "modifier_teleporting",
	SMOKE_MOD       = "modifier_smoke_of_deceit",
	PROJECTILE_LIFE = 2.5,
	HAZARD_LIFE     = 0.4,
	BLINK_RANGE     = 1200,
	BLINK_CAST      = 0.3,
	HULL            = 24,
	SPEED_MIN       = 200,
	SPEED_MAX       = 700,
	SPEED_DEFAULT   = 300,
	PATH_TTL        = 2.0,
	PATH_KEEP       = 10.0,
	PATH_FACTOR     = 1.15,
	PATH_MAX_DIST   = 9000,
	PATHS_PER_TICK  = 2,
	BURST_WINDOW    = 2.5,
	POWER_BASE      = 0.55,
	HAZARD_HULL     = 140,
	TP_WARN_RADIUS  = 2000,
	TP_CHANNEL      = 3.0,
	RING_SEGMENTS   = 64,
	DIR_WINDOW      = 1.5,
	DIR_KEEP        = 1.0,
	ARROW_MIN_SPEED_KEEP = 30,
	ETA_CUTOFF      = 45.0,
	CHAT_MIN_GAP    = 4.0,
	CONTACT_BASE    = 0.85,
	HOSTILE_FOR     = 2.5,
	HOSTILE_CHANCE  = 0.97,
	BAR_H           = 3,
}

local BLINK_ITEMS = {
	"item_blink",
	"item_overwhelming_blink",
	"item_arcane_blink",
	"item_swift_blink",
	"item_super_blink",
}

local state = {
	me          = nil,
	tracks      = {},
	score       = 0,
	count       = 0,
	fogged      = 0,
	dead        = 0,
	lost        = 0,
	memory      = {},
	projectiles = {},
	hazards     = {},
	next_run    = 0,
	draw_error  = nil,
	icons       = {},
	labels      = {},
	font_bold   = nil,
	font_normal = nil,
	last_log    = 0,
	paths       = {},
	chat_said   = {},
	hostile     = {},
}

local floor, max, min = math.floor, math.max, math.min
local sqrt, format = math.sqrt, string.format
local exp = math.exp
local cos, sin, pi = math.cos, math.sin, math.pi

local function clamp(v, lo, hi)
	if v ~= v then return lo end
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

local function to_mask(v)
	local n = tonumber(v)
	if not n or n ~= n then return 0 end
	return floor(n)
end

local function has_behavior(ability, flag)
	local ok, behavior = pcall(Ability.GetBehavior, ability)
	if not ok then return false end
	local f = to_mask(flag)
	if f <= 0 then return false end
	return (to_mask(behavior) & f) ~= 0
end

local function dist2d(ax, ay, bx, by)
	local dx, dy = ax - bx, ay - by
	return sqrt(dx * dx + dy * dy)
end

local function is_alive(npc)
	return npc and Entity.IsAlive(npc) == true
end

local function with_alpha(color, alpha)
	return Color(color.r, color.g, color.b, floor(color.a * clamp(alpha, 0, 1) + 0.5))
end

local function threat_color(value)
	local threshold = ui.threshold:Get()
	if value >= threshold then return ui.color_high:Get() end
	if value >= threshold * 0.5 then return ui.color_mid:Get() end
	return ui.color_low:Get()
end

local function ability_label(ability, is_item)
	local ok, name = pcall(Ability.GetName, ability)
	if not ok or type(name) ~= "string" or name == "" then return "?" end

	local cached = state.labels[name]
	if cached then return cached end

	local label = name
	if is_item then
		local ok_localized, pretty = pcall(GameLocalizer.FindItem, name)
		if ok_localized and type(pretty) == "string" and pretty ~= "" then label = pretty end
	else
		local ok_localized, pretty = pcall(GameLocalizer.FindAbility, name)
		if ok_localized and type(pretty) == "string" and pretty ~= "" then label = pretty end
	end

	state.labels[name] = label
	return label
end

local function hero_icon(unit_name)
	if type(unit_name) ~= "string" or unit_name == "" then return nil end

	local cached = state.icons[unit_name]
	if cached ~= nil then return cached or nil end

	local ok, handle = pcall(Render.LoadImage, "panorama/images/heroes/icons/" .. unit_name .. "_png.vtex_c")
	if ok and handle then
		state.icons[unit_name] = handle
		return handle
	end

	state.icons[unit_name] = false
	return nil
end

local function move_speed(hero)
	local speed = tonumber(NPC.GetMoveSpeed(hero)) or 0
	if speed < K.SPEED_MIN or speed > K.SPEED_MAX then return K.SPEED_DEFAULT end
	return speed
end

local function attack_reach(hero)
	local range = tonumber(NPC.GetAttackRange(hero)) or 0
	local bonus = tonumber(NPC.GetAttackRangeBonus(hero)) or 0
	if range <= 0 then range = 150 end
	return range + bonus + K.HULL
end

local function path_ratio(hero, from_x, from_y, from_z, to_x, to_y, straight, budget)
	if not ui.paths:Get() or straight > K.PATH_MAX_DIST then return K.PATH_FACTOR, budget end

	local index = Entity.GetIndex(hero)
	local now = GameRules.GetGameTime()
	local cached = state.paths[index]

	if cached and now - cached.at < K.PATH_TTL then return cached.ratio, budget end
	if budget <= 0 then
		if cached and now - cached.at < K.PATH_KEEP then return cached.ratio, budget end
		return K.PATH_FACTOR, budget
	end

	local ok, points = pcall(GridNav.BuildPath,
		Vector(from_x, from_y, from_z), Vector(to_x, to_y, from_z), true)
	if not ok or type(points) ~= "table" or #points < 2 or straight < 1 then
		return K.PATH_FACTOR, budget - 1
	end

	local length, px, py = 0, nil, nil
	for i = 1, #points do
		local point = points[i]
		if px then length = length + dist2d(point.x, point.y, px, py) end
		px, py = point.x, point.y
	end

	local ratio = max(1, length / straight)
	state.paths[index] = { at = now, ratio = ratio }
	return ratio, budget - 1
end

local function time_to_reach(distance, reach, speed)
	local gap = distance - reach
	if gap <= 0 then return 0 end
	return gap / max(speed, 1)
end

local function readiness(ability)
	if Ability.IsCastable(ability) then return 1 end
	local cooldown = Ability.GetCooldown(ability) or 0
	local length = Ability.GetCooldownLength(ability) or 0
	if cooldown <= 0 or length <= 0 then return 0 end
	return clamp(1 - cooldown / length, 0, 1)
end

--- Оценка одного попадания. Ability.GetDamage читает только поле damage, а у многих
--- способностей урон лежит в main_damage, base_damage, damage_per_second и подобных.
local DAMAGE_KEYS = {
	"damage", "main_damage", "base_damage", "impact_damage", "burn_damage",
	"max_damage", "bonus_damage", "damage_per_second", "burn_dps", "damage_max",
	"customval_damage", "damage_bonus",
}

local function estimate_damage(ability, target)
	local damage = 0
	local ok, value = pcall(Ability.GetDamage, ability)
	if ok and type(value) == "number" and value > 0 then damage = value end

	if damage <= 0 then
		for i = 1, #DAMAGE_KEYS do
			local ok_special, special = pcall(Ability.GetLevelSpecialValueFor, ability, DAMAGE_KEYS[i])
			if ok_special and type(special) == "number" and special > 0 then
				damage = special
				break
			end
		end
	end

	if damage <= 0 then
		local ok_level, level = pcall(Ability.GetLevel, ability)
		if ok_level and type(level) == "number" and level > 0 then
			for i = 1, #DAMAGE_KEYS do
				local ok_special, special = pcall(Ability.GetLevelSpecialValueFor, ability, DAMAGE_KEYS[i], level)
				if ok_special and type(special) == "number" and special > 0 then
					damage = special
					break
				end
			end
		end
	end
	if damage <= 0 then return 0 end

	local damage_type = Ability.GetDamageType(ability)
	if damage_type == Enum.DamageTypes.DAMAGE_TYPE_MAGICAL then
		damage = damage * (NPC.GetMagicalArmorDamageMultiplier(target) or 1)
	elseif damage_type == Enum.DamageTypes.DAMAGE_TYPE_PHYSICAL then
		damage = damage * (NPC.GetArmorDamageMultiplier(target) or 1)
	end
	return damage
end

local function is_offensive(ability, owner)
	if has_behavior(ability, Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_PASSIVE) then return false, 0 end
	if has_behavior(ability, Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_AURA) then return false, 0 end
	if has_behavior(ability, Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_ATTACK) then return false, 0 end

	local castable =
		has_behavior(ability, Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_UNIT_TARGET) or
		has_behavior(ability, Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_POINT) or
		has_behavior(ability, Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_NO_TARGET) or
		has_behavior(ability, Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_DIRECTIONAL) or
		has_behavior(ability, Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_VECTOR_TARGETING)
	if not castable then return false, 0 end

	local team = to_mask(Ability.GetTargetTeam(ability))
	if (team & to_mask(Enum.TargetTeam.DOTA_UNIT_TARGET_TEAM_ENEMY)) == 0
		and (team & to_mask(Enum.TargetTeam.DOTA_UNIT_TARGET_TEAM_BOTH)) == 0 then
		return false, 0
	end

	local target_type = to_mask(Ability.GetTargetType(ability))
	if (target_type & to_mask(Enum.TargetType.DOTA_UNIT_TARGET_SELF)) ~= 0
		and (target_type & to_mask(Enum.TargetType.DOTA_UNIT_TARGET_HERO)) == 0 then
		return false, 0
	end

	local range = Ability.GetCastRange(ability) or 0
	if range < 0 then range = 0 end
	if owner then range = range + (NPC.GetCastRangeBonus(owner) or 0) end
	return true, range
end

local function penetration(ability)
	if not state.me then return 1 end
	if not NPC.HasState(state.me, Enum.ModifierState.MODIFIER_STATE_MAGIC_IMMUNE) then return 1 end

	local immunity = Ability.GetImmunityType(ability)
	if immunity == Enum.ImmunityTypes.SPELL_IMMUNITY_ENEMIES_YES then return 1 end
	if immunity == Enum.ImmunityTypes.SPELL_IMMUNITY_ALLIES_YES_ENEMIES_NO then return 0 end
	if immunity == Enum.ImmunityTypes.SPELL_IMMUNITY_ENEMIES_NO then
		local damage_type = Ability.GetDamageType(ability)
		if damage_type == Enum.DamageTypes.DAMAGE_TYPE_PHYSICAL
			or damage_type == Enum.DamageTypes.DAMAGE_TYPE_PURE then
			return 1
		end
		return 0
	end
	return 0.25
end

local function scan_offense(hero, distance, my_hp)
	local best, total, list = 0, 0, {}
	if not is_alive(hero) then return best, total, list end

	local mana = NPC.GetMana(hero) or 0
	for i = 0, K.ABILITY_SLOTS do
		local ability = NPC.GetAbilityByIndex(hero, i)
		if ability then
			local level = Ability.GetLevel(ability) or 0
			if level > 0
				and not Ability.IsPassive(ability)
				and not Ability.IsHidden(ability)
				and not Ability.IsAttributes(ability)
				and not Ability.IsInnatePassive(ability) then
				local offensive, range = is_offensive(ability, hero)
				if offensive and distance <= range + 150 and Ability.IsCastable(ability, mana) then
					local ready = readiness(ability)
					if ready > 0 then
						local is_ultimate = Ability.IsUltimate(ability) == true
						local hit = estimate_damage(ability, state.me) * penetration(ability)
						total = total + hit

						local share = my_hp > 0 and clamp(hit / my_hp, 0, 1) or 0
						local pressure = clamp(ready * (0.35 + share * 2.2) * (is_ultimate and 1.3 or 1), 0, 1.4)

						list[#list + 1] = {
							label = ability_label(ability, false),
							ready = ready,
							hit = hit,
							ultimate = is_ultimate,
							pressure = pressure,
						}
						best = max(best, pressure)
					end
				end
			end
		end
	end

	for i = 0, K.ITEM_SLOTS do
		local item = NPC.GetItemByIndex(hero, i)
		if item and not Item.IsRecipe(item) then
			local offensive, range = is_offensive(item, hero)
			if offensive and distance <= range + 150 and Ability.IsCastable(item, mana) then
				local ready = readiness(item)
				if ready > 0 then
					local charges_ok = true
					local ok_charges, needs_charges = pcall(Item.RequiresCharges, item)
					if ok_charges and needs_charges then
						charges_ok = (Ability.GetCurrentCharges(item) or 0) > 0
					end
					if charges_ok then
						local hit = estimate_damage(item, state.me) * penetration(item)
						total = total + hit
						local pressure = clamp(ready * 0.6, 0, 1)
						list[#list + 1] = {
							label = ability_label(item, true),
							ready = ready,
							hit = hit,
							ultimate = false,
							pressure = pressure,
						}
						best = max(best, pressure)
					end
				end
			end
		end
	end

	table.sort(list, function(a, b) return a.pressure > b.pressure end)
	return best, total, list
end

local function scan_blink(hero)
	if not is_alive(hero) then return false, nil end

	for i = 1, #BLINK_ITEMS do
		local item = NPC.GetItem(hero, BLINK_ITEMS[i], true)
		if item then
			local label = ability_label(item, true)
			local cooldown = Ability.GetCooldown(item) or 0
			if cooldown <= 0 then return true, label end
			return false, label
		end
	end
	return false, nil
end

local function scan_support(hero)
	local count = 0
	local ok, allies = pcall(Entity.GetHeroesInRadius, hero, ui.medium:Get(), Enum.TeamType.TEAM_FRIEND, true, true)
	if not ok or not allies then return 0 end

	for i = 1, #allies do
		local ally = allies[i]
		if ally ~= hero and is_alive(ally) then count = count + 1 end
	end
	return count
end

local function scan_smoke(hero)
	if not is_alive(hero) then return false end

	local ok, modifier = pcall(NPC.GetModifier, hero, K.SMOKE_MOD)
	if ok and modifier then return true end

	local ok_list, modifiers = pcall(NPC.GetModifiers, hero)
	if ok_list and modifiers then
		for i = 1, #modifiers do
			local name = Modifier.GetName(modifiers[i])
			if type(name) == "string" and name:find("smoke", 1, true) then return true end
		end
	end
	return false
end

local function observe(hero, now)
	local index = Entity.GetIndex(hero)
	local x, y, z = Entity.GetAbsOriginXYZ(hero)
	local record = state.memory[index]

	if not record then
		record = {
			x = x, y = y, z = z, vx = 0, vy = 0, seen = now,
			dirx = nil, diry = nil, dir_speed = 0,
		}
		state.memory[index] = record
		return record
	end

	local dt = now - record.seen
	local moved = dist2d(x, y, record.x, record.y)
	if dt > 0 and dt < K.MAX_AGE and moved < 1200 * dt + 96 then
		record.vx, record.vy = (x - record.x) / dt, (y - record.y) / dt
	else
		record.vx, record.vy = 0, 0
	end

	-- Направление держим сглаженным: шаги между крипами гасят друг друга,
	-- а идущий в одну сторону набирает устойчивый вектор для стрелки.
	local speed = sqrt(record.vx * record.vx + record.vy * record.vy)
	if speed >= K.ARROW_MIN_SPEED_KEEP then
		local a = clamp(dt / K.DIR_WINDOW, 0, 1)
		if record.dirx then
			record.dirx = record.dirx + (record.vx / speed - record.dirx) * a
			record.diry = record.diry + (record.vy / speed - record.diry) * a
		else
			record.dirx, record.diry = record.vx / speed, record.vy / speed
		end
		record.dir_speed = record.dir_speed + (speed - record.dir_speed) * a
		record.dir_at = now
	else
		local decay = clamp((now - (record.dir_at or 0)) / K.DIR_KEEP, 0, 1)
		if decay >= 1 then
			record.dirx, record.diry, record.dir_speed = nil, nil, 0
		else
			record.dir_speed = record.dir_speed * (1 - decay * 0.5)
		end
	end

	record.x, record.y, record.z = x, y, z
	record.seen = now
	return record
end

local function predict(record, time)
	local speed = sqrt(record.vx * record.vx + record.vy * record.vy)
	if speed < 30 then return record.x, record.y end
	return record.x + record.vx * time, record.y + record.vy * time
end

local function closest_approach(px, py, vx, vy, max_time)
	local a = vx * vx + vy * vy
	if a < 0.001 then return 0, sqrt(px * px + py * py) end
	local t = clamp(-(px * vx + py * vy) / a, 0, max_time)
	local cx, cy = px + vx * t, py + vy * t
	return t, sqrt(cx * cx + cy * cy)
end

local function track_projectile(data, location_targeted)
	if not state.me or not data then return end

	local source = data.source
	if not source or not is_alive(source) or not Entity.IsHero(source) then return end
	if Entity.IsSameTeam(state.me, source) then return end

	local speed = data.moveSpeed or data.original_move_speed or 0
	if type(speed) ~= "number" or speed <= 0 then return end

	local tx, ty
	if location_targeted then
		local loc = data.targetLoc
		if not loc then return end
		tx, ty = loc.x, loc.y
	else
		local target = data.target
		if not target or not is_alive(target) then return end
		tx, ty = Entity.GetAbsOriginXYZ(target)
	end

	local sx, sy, sz = Entity.GetAbsOriginXYZ(source)
	local damage = 0
	if data.isAttack then
		damage = (NPC.GetTrueDamage(source) or 0) * (NPC.GetArmorDamageMultiplier(state.me) or 1)
	elseif data.ability then
		damage = estimate_damage(data.ability, state.me) * penetration(data.ability)
	end

	state.projectiles[data.handle] = {
		target = data.target,
		tx = tx,
		ty = ty,
		damage = damage,
		impact = GameRules.GetGameTime() + dist2d(sx, sy, tx, ty) / speed,
	}
end

local function projectile_channel(now)
	local total, count = 0, 0
	local mx, my = Entity.GetAbsOriginXYZ(state.me)
	local reach = ui.medium:Get()

	for _, projectile in pairs(state.projectiles) do
		local left = projectile.impact - now
		if left > 0 and left < K.PROJECTILE_LIFE then
			if projectile.target == state.me then
				total = total + projectile.damage
				count = count + 1
			elseif dist2d(projectile.tx, projectile.ty, mx, my) < reach then
				total = total + projectile.damage * 0.5
				count = count + 1
			end
		end
	end

	local hp = Entity.GetHealth(state.me) or 0
	if hp <= 0 then return 0, count end
	return clamp(total / hp, 0, 1), count
end

local function refresh_hazards(now)
	local ok, live = pcall(LinearProjectiles.GetAll)
	if not ok or not live then return end

	local seen = {}
	for i = 1, #live do
		local projectile = live[i]
		local handle = projectile.handle
		local source = projectile.source
		if handle and source and is_alive(source) and Entity.IsHero(source)
			and not Entity.IsSameTeam(state.me, source) then
			seen[handle] = true
			local record = state.hazards[handle]
			if not record then
				record = { created = now }
				state.hazards[handle] = record
			end

			local position = projectile.position
			if position then record.x, record.y, record.z = position.x, position.y, position.z end
			local velocity = projectile.velocity
			if velocity then record.vx, record.vy = velocity.x, velocity.y end

			record.last_seen = now
		end
	end

	for handle, record in pairs(state.hazards) do
		if not seen[handle] and now - (record.last_seen or record.created) > K.HAZARD_LIFE then
			state.hazards[handle] = nil
		end
	end
end

local function hazard_channel()
	local count = 0
	local mx, my = Entity.GetAbsOriginXYZ(state.me)
	local hull = (NPC.GetHullRadius(state.me) or K.HULL) + K.HAZARD_HULL

	for _, hazard in pairs(state.hazards) do
		if hazard.x and hazard.vx then
			local _, closest = closest_approach(hazard.x - mx, hazard.y - my, hazard.vx, hazard.vy, 1.6)
			if closest < hull then count = count + 1 end
		end
	end

	if count == 0 then return 0, 0 end
	return clamp(0.45 + count * 0.25, 0, 1), count
end

local function tp_channel(now)
	local count, value = 0, 0
	local mx, my = Entity.GetAbsOriginXYZ(state.me)

	local ok, heroes = pcall(Heroes.GetAll)
	if not ok or not heroes then return value, count end

	for i = 1, #heroes do
		local hero = heroes[i]
		if hero and is_alive(hero) and not Entity.IsSameTeam(state.me, hero) then
			local ok_mod, modifier = pcall(NPC.GetModifier, hero, K.TELEPORT_MOD)
			if ok_mod and modifier then
				local remaining = K.TP_CHANNEL
				local die = Modifier.GetDieTime(modifier)
				if type(die) == "number" and die > now then remaining = die - now end

				local x, y = Entity.GetAbsOriginXYZ(hero)
				if dist2d(x, y, mx, my) < K.TP_WARN_RADIUS then
					count = count + 1
					value = value + clamp(0.4 + (1 - remaining / K.TP_CHANNEL) * 0.6, 0, 1)
				end
			end
		end
	end

	return clamp(value, 0, 1), count
end

local function burst_channel()
	local ok, recent = pcall(Hero.GetRecentDamage, state.me)
	if not ok or type(recent) ~= "number" or recent <= 0 then return 0 end

	local hp = Entity.GetHealth(state.me) or 0
	if hp <= 0 then return 0 end
	return clamp(recent / hp, 0, 1)
end

--- Локальное сообщение в чат: say для всех, say_team для команды.
--- Имя героя чистим от кавычек, иначе команда развалится.
local function say(text)
	local clean = tostring(text):gsub('["\';]', "")
	local channel = ui.chat_where:Get() == 1 and "say" or "say_team"
	Engine.ExecuteCommand(channel .. ' "' .. clean .. '"')
end

local function hero_name(hero)
	local unit_name = NPC.GetUnitName(hero)
	if type(unit_name) == "string" and unit_name ~= "" then
		local pretty = GameLocalizer.FindNPC(unit_name)
		if type(pretty) == "string" and pretty ~= "" then return pretty end
		local display = Engine.GetDisplayNameByUnitName(unit_name)
		if type(display) == "string" and display ~= "" then return display end
		return unit_name
	end
	return "?"
end

local function evaluate(hero, record, now, mx, my, budget)
	local fogged = Entity.IsDormant(hero) == true
	if fogged and not ui.memory:Get() then return nil end

	local ttl = max(ui.memory_ttl:Get(), 0.1)
	local age = now - record.seen
	if age > ttl then return nil end

	local confidence = 1
	if fogged then
		confidence = clamp(1 - age / ttl, 0, 1)
		local ok, last_visible = pcall(Hero.GetLastVisibleTime, hero)
		if ok and type(last_visible) == "number" and last_visible > 0 then
			confidence = min(confidence, clamp(1 - (now - last_visible) / ttl, 0, 1))
		end
		if confidence <= 0 then return nil end
	end

	local distance = dist2d(record.x, record.y, mx, my)
	local radius = ui.radius:Get()
	local speed = move_speed(hero)
	local reach = attack_reach(hero)

	local horizon = ui.react:Get() + (fogged and age or 0)
	local px, py = predict(record, horizon)
	local projected = dist2d(px, py, mx, my)

	local blink, blink_label = false, nil
	local spells, burst_hits, spell_list = 0, 0, {}
	local smoke = false
	local support = 0

	if not fogged then
		blink, blink_label = scan_blink(hero)
		smoke = scan_smoke(hero)
		support = scan_support(hero)
	end

	local walk_distance = distance
	if ui.paths:Get() and distance > reach then
		local ratio
		ratio, budget = path_ratio(hero, record.x, record.y, record.z, mx, my, distance, budget)
		walk_distance = distance * ratio
	end

	local eta
	if blink and distance <= K.BLINK_RANGE + reach then
		eta = K.BLINK_CAST
	else
		eta = time_to_reach(walk_distance, reach, speed)
	end

	local my_health = max(Entity.GetHealth(state.me) or 1, 1)

	if not fogged then
		spells, burst_hits, spell_list = scan_offense(hero, distance, my_health)

		local attack = (NPC.GetTrueDamage(hero) or 0) * (NPC.GetArmorDamageMultiplier(state.me) or 1)
		local attacks = tonumber(NPC.GetAttacksPerSecond(hero)) or 1
		burst_hits = burst_hits + attack * attacks * K.BURST_WINDOW
	end

	local react = max(ui.react:Get(), 0.1)
	local kill = clamp(burst_hits / my_health, 0, 1)

	-- Контакт: успевает ли он меня достать за время реакции. Вплотную это
	-- единица, на времени реакции половина, дальше плавно вниз.
	local ratio = eta / react
	local contact = 1 / (1 + ratio * ratio)
	if distance <= reach then contact = 1 end
	if eta > K.ETA_CUTOFF then contact = 0 end

	-- Летальность: чем он реально может меня убить. Это множитель
	-- к контакту, а не самостоятельная величина: урон без дистанции не угроза.
	local spell_part = clamp(spells / 1.2, 0, 1)
	local mobility_part = blink and 1 or 0
	local support_part = clamp(support / 2, 0, 1)
	local lethality = 0.50 * spell_part
		+ 0.45 * kill
		+ 0.25 * mobility_part
		+ 0.20 * support_part
		+ (smoke and 0.15 or 0)
	lethality = clamp(lethality, 0, 1)

	local control = 1
	if not fogged then
		if NPC.HasState(hero, Enum.ModifierState.MODIFIER_STATE_STUNNED) then control = 0.30 end
		if NPC.HasState(hero, Enum.ModifierState.MODIFIER_STATE_HEXED) then control = min(control, 0.35) end
		if NPC.HasState(hero, Enum.ModifierState.MODIFIER_STATE_SILENCED) then control = min(control, 0.60) end
		if NPC.HasState(hero, Enum.ModifierState.MODIFIER_STATE_ROOTED) then control = min(control, 0.50) end
		if NPC.IsLinkensProtected(state.me) then control = control * 0.85 end
		if NPC.IsMirrorProtected(state.me) then control = control * 0.80 end
	end

	-- Тот, кто уже уходит, давит слабее: он не собирается нападать.
	local closing = 1
	if speed > 30 then
		local radial = (record.vx * (mx - record.x) + record.vy * (my - record.y)) / max(distance, 1)
		if radial < -30 then closing = 0.75 end
	end

	-- Он уже бьет меня: пока урон идет, шанс близок к единице при любом расчёте.
	local hostile = state.hostile[Entity.GetIndex(hero)]
	local is_hostile = hostile ~= nil and now - hostile <= K.HOSTILE_FOR

	-- Вплотную шанс не может быть низким: он уже достал меня, вопрос только в том,
	-- чем именно ударит. Пол это не 0.55 как раньше, а высокая база контакта.
	local chance = contact * (K.CONTACT_BASE + (1 - K.CONTACT_BASE) * lethality)
	if distance <= reach and (is_hostile or contact >= 1) then
		chance = max(chance, K.HOSTILE_CHANCE * (is_hostile and 1 or 0.92))
	end
	chance = clamp(chance * control * confidence * closing, 0, 1)

	return {
		hero = hero,
		fogged = fogged,
		confidence = confidence,
		x = record.x, y = record.y, z = record.z,
		px = px, py = py, pz = record.z,
		distance = distance,
		projected = projected,
		value = chance * 100,
		chance = chance,
		eta = eta,
		contact = contact,
		lethality = lethality,
		power = K.CONTACT_BASE + (1 - K.CONTACT_BASE) * lethality,
		capability = lethality,
		hostile = is_hostile,
		spell_count = #spell_list,
		kill = kill,
		control = control,
		speed = speed,
		blink = blink,
		smoke = smoke,
		support = support,
		abilities = spell_list,
		unit_name = NPC.GetUnitName(hero),
		age = age,
		budget = budget,
		ttl = ttl,
		dirx = record.dirx,
		diry = record.diry,
		dir_speed = record.dir_speed or 0,
	}
end

local function reap(now)
	local ttl = max(ui.memory_ttl:Get(), 0.1) + 2
	for index, record in pairs(state.memory) do
		if now - record.seen > ttl then
			state.memory[index] = nil
			state.paths[index] = nil
		end
	end
	for handle, projectile in pairs(state.projectiles) do
		if projectile.impact < now - 0.5 then state.projectiles[handle] = nil end
	end
end

function script.OnUpdate()
	if not ui.enable:Get() then return end

	local now = GameRules.GetGameTime()
	if now < state.next_run then return end
	state.next_run = now + ui.interval:Get()

	local me = Heroes.GetLocal()
	if not me or not Entity.IsAlive(me) then
		state.me = nil
		return
	end
	state.me = me

	local mx, my = Entity.GetAbsOriginXYZ(me)
	refresh_hazards(now)

	local radius = ui.radius:Get()
	local show_eta = ui.show:Get()
	local tracks, count, fogged, dead, lost = {}, 0, 0, 0, 0
	local budget = K.PATHS_PER_TICK

	local ok_heroes, heroes = pcall(Heroes.GetAll)
	if ok_heroes and heroes then
		for i = 1, #heroes do
			local hero = heroes[i]
			if hero and hero ~= me and not Entity.IsSameTeam(me, hero)
				and Entity.IsHero(hero) and not NPC.IsIllusion(hero) then
				local index = Entity.GetIndex(hero)
				local record = state.memory[index]
				local dormant = Entity.IsDormant(hero) == true

				if not dormant then
					record = observe(hero, now)
					-- Запасной путь для враждебности: OnEntityHurt есть только в unsafe.
					-- Атакующий вплотную враг почти наверняка бьет именно меня.
					if NPC.IsAttacking(hero)
						and NPC.IsPositionInRange(hero, Vector(Entity.GetAbsOriginXYZ(state.me)), ui.close:Get()) then
						state.hostile[Entity.GetIndex(hero)] = now
					end
				end

				if not is_alive(hero) then
					dead = dead + 1
				elseif not record then
					lost = lost + 1
				else
					local track = evaluate(hero, record, now, mx, my, budget)
					if track then
						budget = track.budget or budget
						if track.distance <= radius or track.eta <= show_eta
							or (track.fogged and track.distance <= ui.medium:Get()) then
							count = count + 1
							if track.fogged then fogged = fogged + 1 end
							tracks[#tracks + 1] = track
						end
					end
				end
			end
		end
	end

	table.sort(tracks, function(a, b) return a.value > b.value end)

	if ui.chat:Get() then
		local gate = ui.chat_threshold:Get()
		local cooldown = ui.chat_cooldown:Get()

		-- Пишем про одного, самого опасного за расчёт: иначе толпа врагов
		-- выдаст несколько сообщений подряд в один тик.
		for i = 1, min(#tracks, 2) do
			local track = tracks[i]
			if track.chance * 100 >= gate then
				local index = Entity.GetIndex(track.hero)
				local last = state.chat_said[index] or -math.huge
				if now - last >= cooldown and now - last >= K.CHAT_MIN_GAP then
					state.chat_said[index] = now
					say(format(L("sn_chat_msg"), hero_name(track.hero),
						floor(track.chance * 100 + 0.5), floor(track.distance + 0.5)))
					break
				end
			end
		end
	end

	local best = tracks[1] and tracks[1].value or 0

	local crowd = 0
	for i = 2, #tracks do
		crowd = crowd + tracks[i].value * 0.30
	end
	crowd = min(crowd, 45)

	local projectile_value, projectile_count = projectile_channel(now)
	local hazard_value, hazard_count = hazard_channel()
	local tp_value, tp_count = tp_channel(now)
	local burst = burst_channel()

	local global_value = (ui.w_burst:Get() / 100) * 12 * max(projectile_value, hazard_value, tp_value, burst)

	state.tracks = tracks
	state.count = count
	state.fogged = fogged
	state.dead = dead
	state.lost = lost
	state.score = clamp(best + crowd + global_value, 0, 99)
	state.projectile_count = projectile_count
	state.hazard_count = hazard_count
	state.tp_count = tp_count
	state.burst = burst

	reap(now)

	if ui.debug:Get() and now - state.last_log > 2 then
		state.last_log = now
		local parts = {}
		for i = 1, min(#tracks, 5) do
			local t = tracks[i]
			parts[#parts + 1] = format("%s %.0f%% contact=%.2f leth=%.2f eta=%.1fs dist=%d spells=%d%s%s",
				t.unit_name or "?", t.value, t.contact or 0, t.lethality or 0,
				t.eta, floor(t.distance), t.spell_count or 0,
				t.hostile and " hostile" or "", t.fogged and " fog" or "")
		end
		log(format("score=%d shown=%d fog=%d dead=%d lost=%d | %s",
			floor(state.score + 0.5), count, fogged, dead, lost, table.concat(parts, " | ")))
	end
end

function script.reset()
	state.memory = {}
	state.tracks = {}
	state.projectiles = {}
	state.hazards = {}
	state.paths = {}
	state.chat_said = {}
	state.hostile = {}
	state.score = 0
	state.count = 0
	state.fogged = 0
	state.next_run = 0
	log("memory reset")
end

local function load_fonts()
	if state.font_bold then return end

	local ok_bold, bold = pcall(Render.LoadFont, "Inter", Enum.FontCreate.FONTFLAG_ANTIALIAS, Enum.FontWeight.BOLD)
	if not ok_bold or not bold then
		bold = Render.LoadFont("Segoe UI", Enum.FontCreate.FONTFLAG_ANTIALIAS, Enum.FontWeight.BOLD)
	end

	local ok_normal, normal = pcall(Render.LoadFont, "Inter", Enum.FontCreate.FONTFLAG_ANTIALIAS, Enum.FontWeight.NORMAL)
	if not ok_normal or not normal then
		normal = Render.LoadFont("Segoe UI", Enum.FontCreate.FONTFLAG_ANTIALIAS, Enum.FontWeight.NORMAL)
	end

	state.font_bold = bold
	state.font_normal = normal
end

---Полоска шанса по нижней кромке плашки. Прием из Advanced Wisdom Info:
---полоса поверх фона читается быстрее, чем число в стороне.
local function draw_pill(x, y, icon_handle, title, detail, accent, alpha, chance)
	local font_bold, font_normal = state.font_bold, state.font_normal
	if not font_bold then return K.PILL_H end

	local h, pad, gap, tail = K.PILL_H, 6, 8, 12
	local icon_size = h - 8

	local title_w = title and Render.TextSize(font_bold, K.FONT_MAIN, title).x or 0
	local detail_w = detail and Render.TextSize(font_normal, K.FONT_DETAIL, detail).x or 0

	local width = pad + title_w + tail
	if icon_handle then width = width + icon_size + gap end
	if detail then width = width + gap + 1 + gap + detail_w end

	local bg = ui.color_bg:Get()
	local start, stop = Vec2(x, y), Vec2(x + width, y + h)
	Render.FilledRect(start, stop, Color(bg.r, bg.g, bg.b, floor(bg.a * alpha)), h / 2,
		Enum.DrawFlags.RoundCornersAll)

	if chance and chance > 0 then
		local bar = clamp(chance, 0, 1)
		local inset = 3
		local bar_color = with_alpha(accent, alpha)
		Render.RoundedProgressRect(Vec2(x + inset, y + h - K.BAR_H - inset),
			Vec2(x + width - inset, y + h - inset), bar_color, bar, K.BAR_H / 2, 1)
	end

	local cx = x + pad
	if icon_handle then
		Render.Image(icon_handle, Vec2(cx, y + 4), Vec2(icon_size, icon_size),
			Color(255, 255, 255, floor(235 * alpha)), 5, Enum.DrawFlags.RoundCornersAll,
			Vec2(0, 0), Vec2(1, 1), 0)
		Render.Rect(Vec2(cx, y + 4), Vec2(cx + icon_size, y + 4 + icon_size),
			Color(255, 255, 255, floor(30 * alpha)), 5, Enum.DrawFlags.RoundCornersAll, 1)
		cx = cx + icon_size + gap
	end

	if title then
		Render.Text(font_bold, K.FONT_MAIN, title, Vec2(cx, y + h / 2 - K.FONT_MAIN / 2 - 1),
			with_alpha(accent, alpha))
		cx = cx + title_w
	end

	if detail then
		cx = cx + gap
		Render.FilledRect(Vec2(cx, y + h / 2 - 7), Vec2(cx + 1, y + h / 2 + 7),
			Color(255, 255, 255, floor(46 * alpha)))
		local text = ui.color_text:Get()
		Render.Text(font_normal, K.FONT_DETAIL, detail, Vec2(cx + gap, y + h / 2 - K.FONT_DETAIL / 2 - 1),
			Color(text.r, text.g, text.b, floor(text.a * alpha)))
	end

	return h
end

---Мелкая строка под меткой: список готовых способностей врага.
local function draw_small_row(x, y, text, color, alpha)
	local font = state.font_normal
	if not font then return end

	local width = Render.TextSize(font, K.FONT_DETAIL, text).x
	local h = 16
	local bg = ui.color_bg:Get()
	Render.FilledRect(Vec2(x, y), Vec2(x + width + 10, y + h),
		Color(bg.r, bg.g, bg.b, floor(bg.a * alpha * 0.85)), h / 2, Enum.DrawFlags.RoundCornersAll)
	local text_col = ui.color_text:Get()
	Render.Text(font, K.FONT_DETAIL, text, Vec2(x + 5, y + h / 2 - K.FONT_DETAIL / 2 - 1),
		Color(text_col.r, text_col.g, text_col.b, floor(text_col.a * alpha)))
end

local function draw_world_circle(cx, cy, cz, radius, color, thickness)
	local previous = nil
	local step = 2 * pi / K.RING_SEGMENTS

	for i = 0, K.RING_SEGMENTS do
		local angle = i * step
		local screen, on_screen = Render.WorldToScreen(
			Vector(cx + cos(angle) * radius, cy + sin(angle) * radius, cz))
		if on_screen and screen then
			if previous then Render.Line(previous, screen, color, thickness) end
			previous = screen
		else
			previous = nil
		end
	end
end

local SHADOW = Color(12, 12, 12, 205)

---Стрелка направления на последнем месте врага. Тень под ней держит читаемость на любой земле.
local function draw_arrow(x, y, z, dirx, diry, color, alpha, thickness)
	if not dirx or not diry then return end
	local speed = sqrt(dirx * dirx + diry * diry)
	if speed < 0.0001 then return end
	dirx, diry = dirx / speed, diry / speed

	local length = ui.arrow_len:Get()
	local from = Vector(x, y, z)
	local to = Vector(x + dirx * length, y + diry * length, z)
	local screen_from, ok_from = Render.WorldToScreen(from)
	local screen_to, ok_to = Render.WorldToScreen(to)
	if not ok_from or not ok_to then return end

	local dx, dy = screen_to.x - screen_from.x, screen_to.y - screen_from.y
	local screen_len = sqrt(dx * dx + dy * dy)
	if screen_len < 4 then return end
	dx, dy = dx / screen_len, dy / screen_len

	local wing = ui.arrow_wing:Get()
	local tip = Vec2(screen_from.x + dx * screen_len, screen_from.y + dy * screen_len)
	local base = Vec2(tip.x - dx * wing * 1.6, tip.y - dy * wing * 1.6)
	local left = Vec2(base.x - dy * wing, base.y + dx * wing)
	local right = Vec2(base.x + dy * wing, base.y - dx * wing)

	if ui.arrow_shadow:Get() then
		local sh = with_alpha(SHADOW, alpha * 0.8)
		local st = thickness + 3
		Render.Line(screen_from, tip, sh, st)
		Render.Line(left, tip, sh, st)
		Render.Line(right, tip, sh, st)
	end

	Render.Line(screen_from, tip, color, thickness)
	Render.Line(left, tip, color, thickness)
	Render.Line(right, tip, color, thickness)
end

local function draw_map_arrow(x, y, z, dirx, diry)
	if not dirx or not diry then return end
	local speed = sqrt(dirx * dirx + diry * diry)
	if speed < 0.0001 then return end
	dirx, diry = dirx / speed, diry / speed

	local length = ui.mini_arrow_len:Get()
	local tip_x, tip_y = x + dirx * length, y + diry * length
	local base_x, base_y = tip_x - dirx * length * 0.25, tip_y - diry * length * 0.25
	local wing = length * 0.14

	local wing_left = Vector(base_x - diry * wing, base_y + dirx * wing, z)
	local wing_right = Vector(base_x + diry * wing, base_y - dirx * wing, z)
	local tip = Vector(tip_x, tip_y, z)
	local start = Vector(x, y, z)

	MiniMap.SendLine(start, true, true)
	MiniMap.SendLine(tip, false, true)
	MiniMap.SendLine(wing_left, true, true)
	MiniMap.SendLine(tip, false, true)
	MiniMap.SendLine(wing_right, true, true)
	MiniMap.SendLine(tip, false, true)
end

local function draw_movement_line(track, color)
	local from, from_ok = Render.WorldToScreen(Vector(track.x, track.y, track.z))
	local to, to_ok = Render.WorldToScreen(Vector(track.px, track.py, track.pz))
	if not from_ok or not to_ok then return end

	local dx, dy = to.x - from.x, to.y - from.y
	local length = sqrt(dx * dx + dy * dy)
	if length < 8 then return end

	local thickness = ui.line_thick:Get()
	Render.Line(from, to, color, thickness)
	if not ui.line_head:Get() then return end

	dx, dy = dx / length, dy / length
	local head = 8 + thickness * 2
	Render.Line(Vec2(to.x - dx * head - dy * head * 0.5, to.y - dy * head + dx * head * 0.5), to, color, thickness)
	Render.Line(Vec2(to.x - dx * head + dy * head * 0.5, to.y - dy * head - dx * head * 0.5), to, color, thickness)
end

local function visuals_visible()
	if not ui.enable:Get() then return false end
	local key = ui.hold:Get()
	if key and key ~= Enum.ButtonCode.KEY_NONE then return ui.hold:IsDown() end
	return true
end

local function eta_text(track)
	if track.distance <= attack_reach(track.hero) then return L("sn_st_now") end
	if track.eta < 0.5 then return L("sn_st_now") end
	return format(L("sn_st_in"), format("%.1f", track.eta))
end

local function draw_panel(alpha, accent)
	local screen = Render.ScreenSize()
	local x = screen.x * (ui.panel_x:Get() / 100)
	local y = ui.panel_y:Get()

	local closest = state.tracks[1]
	local title = format("%d%%", floor(state.score + 0.5))
	local detail
	if state.count == 0 then
		detail = L("sn_st_none")
	elseif closest then
		detail = eta_text(closest)
		if state.fogged > 0 then detail = detail .. " · " .. L("sn_st_fog_tag") end
	end

	y = y + draw_pill(x, y, nil, title, detail, accent, alpha) + 4
	if ui.panel_rows:Get() <= 0 then return end

	local extras = {}
	if state.count > 0 then extras[#extras + 1] = format(L("sn_st_heroes"), state.count) end
	if state.projectile_count > 0 then extras[#extras + 1] = format(L("sn_st_proj"), state.projectile_count) end
	if state.hazard_count > 0 then extras[#extras + 1] = format(L("sn_st_haz"), state.hazard_count) end
	if state.tp_count > 0 then extras[#extras + 1] = format(L("sn_st_tp"), state.tp_count) end
	if state.burst > 0.05 then extras[#extras + 1] = format(L("sn_st_hurt"), floor(state.burst * 100)) end
	if state.dead > 0 then extras[#extras + 1] = format(L("sn_st_dead"), state.dead) end
	if state.lost > 0 then extras[#extras + 1] = format(L("sn_st_lost"), state.lost) end

	if #extras > 0 then
		y = y + draw_pill(x, y, nil, table.concat(extras, "  "), nil, accent, alpha) + 4
	end

	if ui.panel_rows:Get() >= 2 and state.count > 0 then
		local fog_note = state.fogged > 0 and L("sn_st_fog") or L("sn_note")
		draw_pill(x, y, nil, fog_note, nil, accent, alpha)
	end
end

local function draw_enemy_marks(alpha)
	local scale = ui.scale:Get() / 100
	local dx_offset, dy_offset = ui.mark_dx:Get() * scale, ui.mark_dy:Get() * scale
	local ability_lines = ui.ability_lines:Get()
	local show_abilities = ui.show_abilities:Get() and ability_lines > 0

	for _, track in ipairs(state.tracks) do
		local position, on_screen = Render.WorldToScreen(Vector(track.x, track.y, track.z))
		if on_screen and position then
			local accent = track.fogged and ui.color_fog:Get() or threat_color(track.value)

			local parts = {}
			if ui.show_eta:Get() then parts[#parts + 1] = eta_text(track) end
			if ui.show_dist:Get() then parts[#parts + 1] = format(L("sn_st_dist"), floor(track.distance + 0.5)) end
			if ui.show_tags:Get() then
				if track.fogged then
					parts[#parts + 1] = L("sn_st_fog_tag")
				elseif track.control < 1 then
					parts[#parts + 1] = L("sn_st_control")
				end
				if track.blink then parts[#parts + 1] = L("sn_st_blink") end
				if track.smoke then parts[#parts + 1] = L("sn_st_smoke") end
			end

			local icon = ui.show_icon:Get() and hero_icon(track.unit_name) or nil
			local number = ui.show_chance:Get() and (track.chance * 100)
				or (ui.show_percent:Get() and track.value or nil)
			local title = number and format("%d%%", floor(number + 0.5)) or nil
			local detail = #parts > 0 and table.concat(parts, " · ") or nil

			local pill_x = position.x + dx_offset
			local pill_y = position.y + dy_offset
			pill_y = pill_y + draw_pill(pill_x, pill_y, icon, title, detail, accent, alpha,
				track.chance) + 2

			if show_abilities then
				local shown = 0
				for i = 1, #track.abilities do
					if track.abilities[i].pressure > 0.3 and shown < ability_lines then
						local ability = track.abilities[i]
						local text = format("%s%s", ability.ultimate and "★ " or "", ability.label)
						draw_small_row(pill_x, pill_y, text, threat_color(track.value), alpha)
						pill_y = pill_y + 18
						shown = shown + 1
					end
				end
			end
		end
	end
end

local function draw_arrows(alpha)
	if not ui.arrows:Get() then return end

	local color = ui.color_arrow:Get()
	local min_speed = ui.arrow_min_speed:Get()
	local fade = ui.arrow_fade:Get()
	local thickness = ui.arrow_thick:Get()
	local paint_world = ui.arrow_world:Get()

	for _, track in ipairs(state.tracks) do
		local dirx, diry = track.dirx, track.diry
		if track.fogged and dirx then
			local speed = track.dir_speed or 0
			if speed >= min_speed then
				local alpha_use = alpha
				if fade and track.ttl and track.ttl > 0 then
					alpha_use = alpha * clamp(1 - track.age / max(track.ttl, 0.1), 0.25, 1)
				end
				if paint_world then
					draw_arrow(track.x, track.y, track.z, dirx, diry, with_alpha(color, alpha_use), alpha_use, thickness)
				end
			end
		end
	end
end

local function draw_minimap(alpha)
	if not ui.minimap:Get() then return end

	local color = ui.color_fog:Get()
	local mini_alpha = alpha * (ui.mini_alpha:Get() / 100)
	local size = ui.mini_size:Get()

	for _, track in ipairs(state.tracks) do
		if track.fogged and track.value >= ui.threshold:Get() * 0.5 then
			MiniMap.DrawCircle(Vector(track.x, track.y, track.z),
				color.r, color.g, color.b, floor(color.a * mini_alpha), size)
		end
	end

	if ui.arrows:Get() and ui.arrow_map:Get() then
		for _, track in ipairs(state.tracks) do
			if track.fogged and track.dirx and (track.dir_speed or 0) >= ui.arrow_min_speed:Get() then
				draw_map_arrow(track.x, track.y, track.z, track.dirx, track.diry)
			end
		end
	end
end

local function draw_body()
	load_fonts()

	local me = state.me or Heroes.GetLocal()
	if not me or not Entity.IsAlive(me) then return end

	local alpha = ui.dim:Get() / 100

	if ui.rings:Get() then
		local mx, my, mz = Entity.GetAbsOriginXYZ(me)
		local ring_color = with_alpha(ui.color_ring:Get(), alpha * (ui.ring_alpha:Get() / 100))
		local thickness = ui.ring_thick:Get()
		if ui.rings_medium:Get() then
			draw_world_circle(mx, my, mz + 8, ui.medium:Get(), ring_color, thickness)
		end
		if ui.rings_close:Get() then
			draw_world_circle(mx, my, mz + 8, ui.close:Get(), ring_color, thickness)
		end
	end

	if ui.lines:Get() then
		local line_color = with_alpha(ui.color_line:Get(), alpha * 0.8)
		local thickness = ui.line_thick:Get()
		for _, hazard in pairs(state.hazards) do
			if hazard.x and hazard.vx then
				local from, from_ok = Render.WorldToScreen(Vector(hazard.x, hazard.y, hazard.z))
				local to, to_ok = Render.WorldToScreen(
					Vector(hazard.x + hazard.vx * 0.8, hazard.y + hazard.vy * 0.8, hazard.z))
				if from_ok and to_ok then Render.Line(from, to, line_color, thickness + 1) end
			end
		end
	end

	if ui.lines:Get() then
		local only_fog = ui.lines_fog:Get()
		for _, track in ipairs(state.tracks) do
			if not only_fog or track.fogged then
				local accent = track.fogged and ui.color_fog:Get() or threat_color(track.value)
				draw_movement_line(track, with_alpha(accent, alpha * 0.9))
			end
		end
	end

	if ui.arrows:Get() then draw_arrows(alpha) end
	if ui.marks:Get() then draw_enemy_marks(alpha) end
	if ui.panel:Get() then draw_panel(alpha, threat_color(state.score)) end
	draw_minimap(alpha)
end

function script.OnDraw()
	if not visuals_visible() then return end

	local ok, err = pcall(draw_body)
	if not ok and err ~= state.draw_error then
		state.draw_error = err
		log("draw: " .. tostring(err))
	end
end

function script.OnScriptsLoaded()
	log("loaded")
end

function script.OnGameEnd()
	script.reset()
	state.labels = {}
	state.icons = {}
end

function script.OnEntityDestroy(entity)
	if entity then
		local index = Entity.GetIndex(entity)
		state.memory[index] = nil
		state.paths[index] = nil
		state.hostile[index] = nil
		state.chat_said[index] = nil
	end
end

--- Он ударил меня: помечаем его враждебным на несколько секунд, чтобы шанс
--- не падал, пока идет урон. OnEntityHurt доступен только в unsafe-режиме,
--- поэтому рядом работает опрос состояния атаки в OnUpdate.
function script.OnEntityHurt(data)
	if not data or not state.me or data.target ~= state.me then return end
	local source = data.source
	if source and Entity.IsHero(source) and not Entity.IsSameTeam(state.me, source) then
		state.hostile[Entity.GetIndex(source)] = GameRules.GetGameTime()
	end
	if ui.debug:Get() and (data.damage or 0) > 0 then
		log(format("hurt for %d", floor(data.damage + 0.5)))
	end
end

function script.OnProjectile(data)
	track_projectile(data, false)
end

function script.OnProjectileLoc(data)
	track_projectile(data, true)
end

return script
