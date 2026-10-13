-- Custom Stats v1.0.0
-- Author: qhols (GitHub: qhols, Discord: ur2m)

local VERSION = "1.0.0"

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
		cs_group_main = "Main",
		cs_group_view = "View",
		cs_enable = "Enable",
		cs_enable_tip = "Your stats in the top left corner.\nClick to expand, drag to move",
		cs_gear_extra = "Extra",
		cs_look = "Appearance",
		cs_look_tip = "Font, size, icons, divider\nand panel width",
		cs_gear_look = "Appearance",
		cs_rows = "Expanded stats",
		cs_rows_tip = "Which rows show up\nwhen the panel is expanded",
		cs_gear_rows = "Expanded stats",
		cs_font = "Font",
		cs_font_tip = "SF Pro has to be installed in Windows,\notherwise pick Segoe UI",
		cs_font_sf_text = "SF Pro Text",
		cs_font_sf_rounded = "SF Pro Rounded",
		cs_font_sf_display = "SF Pro Display",
		cs_font_segoe = "Segoe UI",
		cs_weight = "Weight",
		cs_weight_tip = "How bold the numbers are,\nlabels are one step lighter",
		cs_weight_regular = "Regular",
		cs_weight_medium = "Medium",
		cs_weight_semibold = "Semibold",
		cs_weight_bold = "Bold",
		cs_weight_heavy = "Heavy",
		cs_scale = "Size",
		cs_scale_tip = "Size of the whole panel",
		cs_value_gap = "Label to value gap",
		cs_value_gap_tip = "Space between the label and the number",
		cs_roll = "Number animation",
		cs_roll_tip = "Changed digits roll or fade smoothly",
		cs_pos_auto = "Dota stats spot",
		cs_pos_auto_tip = "Puts the panel where the Dota Plus\nstats were. Dragging turns it off",
		cs_debug = "Debug log",
		cs_debug_tip = "Writes errors and state changes\nto the log",
		cs_hide_native = "Hide Dota stats",
		cs_hide_native_tip = "Hides the default KDA and creeps\npanel in the corner",
		cs_key = "Expand key",
		cs_key_tip = "Shows or hides the extra stats,\nsame as clicking the panel",
		cs_icons = "Icons",
		cs_icons_tip = "Small gray icon before each row",
		cs_divider = "Divider",
		cs_divider_tip = "Thin line between the main\nand the extra stats",
		cs_bench = "Compare with others",
		cs_bench_tip = "Average for your hero, rank and minute\nfrom Stratz, shown to the right",
		cs_gear_bench = "Stratz",
		cs_stratz_key = "Stratz API key",
		cs_stratz_key_tip = "Your token from stratz.com/api,\nwithout it there is no comparison",
		cs_rank = "Your rank",
		cs_rank_tip = "Compare with players of this rank",
		cs_rank_herald = "Herald / Guardian",
		cs_rank_crusader = "Crusader / Archon",
		cs_rank_legend = "Legend / Ancient",
		cs_rank_divine = "Divine / Immortal",
		cs_rank_all = "All ranks",
		cs_row_gpm = "GPM",
		cs_row_gpm_tip = "Gold per minute",
		cs_row_xpm = "XPM",
		cs_row_xpm_tip = "Experience per minute",
		cs_row_lh10 = "Creeps at 10 min",
		cs_row_lh10_tip = "Counted only if the script was running\nat the 10th minute",
		cs_row_part = "Kill participation",
		cs_row_part_tip = "Share of team kills\nwith your kill or assist",
		cs_row_dmg = "Hero damage",
		cs_row_dmg_tip = "Total damage dealt to heroes",
		cs_bind_name = "Custom Stats",
		cs_l_kda = "KDA",
		cs_l_nw = "Net worth",
		cs_l_cs = "Creeps",
		cs_l_gpm = "GPM",
		cs_l_xpm = "XPM",
		cs_l_lh10 = "Creeps 10 min",
		cs_l_part = "Participation",
		cs_l_dmg = "Damage",
	},
	ru = {
		cs_group_main = "Основное",
		cs_group_view = "Вид",
		cs_enable = "Включить",
		cs_enable_tip = "Твоя стата в левом верхнем углу.\nКлик раскрывает, драг двигает",
		cs_gear_extra = "Дополнительно",
		cs_look = "Внешний вид",
		cs_look_tip = "Шрифт, размер, иконки, разделитель\nи ширина панели",
		cs_gear_look = "Внешний вид",
		cs_rows = "Раскрытая стата",
		cs_rows_tip = "Какие строки видны,\nкогда панель раскрыта",
		cs_gear_rows = "Раскрытая стата",
		cs_font = "Шрифт",
		cs_font_tip = "SF Pro должен быть установлен в Windows,\nиначе выбери Segoe UI",
		cs_font_sf_text = "SF Pro Text",
		cs_font_sf_rounded = "SF Pro Rounded",
		cs_font_sf_display = "SF Pro Display",
		cs_font_segoe = "Segoe UI",
		cs_weight = "Жирность",
		cs_weight_tip = "Насколько жирные цифры,\nподписи на ступень тоньше",
		cs_weight_regular = "Обычный",
		cs_weight_medium = "Средний",
		cs_weight_semibold = "Полужирный",
		cs_weight_bold = "Жирный",
		cs_weight_heavy = "Очень жирный",
		cs_scale = "Размер",
		cs_scale_tip = "Размер всей панели",
		cs_value_gap = "Отступ до цифр",
		cs_value_gap_tip = "Расстояние между подписью и цифрой",
		cs_roll = "Анимация цифр",
		cs_roll_tip = "Изменившиеся цифры плавно\nперекатываются или проявляются",
		cs_pos_auto = "На месте статы доты",
		cs_pos_auto_tip = "Ставит панель туда, где была\nстата Dota Plus. Драг это выключает",
		cs_debug = "Отладка в лог",
		cs_debug_tip = "Пишет в лог ошибки и смену состояния",
		cs_hide_native = "Скрыть стату доты",
		cs_hide_native_tip = "Прячет стандартную панель KDA\nи крипов в углу",
		cs_key = "Клавиша раскрытия",
		cs_key_tip = "Показывает или прячет доп. стату,\nкак клик по панели",
		cs_icons = "Иконки",
		cs_icons_tip = "Маленький серый значок перед строкой",
		cs_divider = "Разделитель",
		cs_divider_tip = "Тонкая линия между основной\nи доп. статой",
		cs_bench = "Сравнение с другими",
		cs_bench_tip = "Среднее по твоему герою, рангу и минуте\nсо Stratz, показывается справа",
		cs_gear_bench = "Stratz",
		cs_stratz_key = "Ключ Stratz API",
		cs_stratz_key_tip = "Твой токен с stratz.com/api,\nбез него сравнения не будет",
		cs_rank = "Твой ранг",
		cs_rank_tip = "С игроками какого ранга сравнивать",
		cs_rank_herald = "Рекрут / Страж",
		cs_rank_crusader = "Рыцарь / Герой",
		cs_rank_legend = "Легенда / Властелин",
		cs_rank_divine = "Божество / Титан",
		cs_rank_all = "Все ранги",
		cs_row_gpm = "GPM",
		cs_row_gpm_tip = "Золото в минуту",
		cs_row_xpm = "XPM",
		cs_row_xpm_tip = "Опыт в минуту",
		cs_row_lh10 = "Крипы на 10 минуте",
		cs_row_lh10_tip = "Считается, только если скрипт\nработал на 10 минуте",
		cs_row_part = "Участие в киллах",
		cs_row_part_tip = "Доля киллов команды,\nгде ты убил или помог",
		cs_row_dmg = "Урон по героям",
		cs_row_dmg_tip = "Весь урон, нанесенный героям",
		cs_bind_name = "Custom Stats",
		cs_l_kda = "KDA",
		cs_l_nw = "Нетворс",
		cs_l_cs = "Крипы",
		cs_l_gpm = "GPM",
		cs_l_xpm = "XPM",
		cs_l_lh10 = "Крипы 10 мин",
		cs_l_part = "Участие",
		cs_l_dmg = "Урон",
	},
})

local UI = localization.WrapLibrary(Menu)
local L = localization.Get

local K = {
	CONFIG = "customStats",
	FONTS = { "SF Pro Text", "SF Pro Rounded", "SF Pro Display", "Segoe UI" },
	WEIGHTS = { 400, 500, 600, 700, 800 },
	NATIVE_IDS = { "quickstats", "QuickStats", "QuickStatsContainer" },

	UPDATE_INTERVAL = 0.25,
	NATIVE_INTERVAL = 1,
	NATIVE_RETRY = 0.1,
	NATIVE_TRIES = 20,

	ROW_H = 21,
	FONT_SIZE = 13,
	ICON_SIZE = 10,
	ICON_W = 14,
	GAP = 8,
	EXTRA_GAP = 4,
	DIVIDER_GAP = 11,
	TRI_W = 14,
	TRI_SIZE = 9,
	DEFAULT_X = 20,
	DEFAULT_Y = 80,

	SPEED = 14,
	POS_SPEED = 35,
	ROLL_TIME = 0.35,
	FADE_TIME = 0.18,
	ROLL_DIST = 7,

	DRAG_START = 4,
	SNAP_MARGIN = 16,
	SNAP_DIST = 14,

	STRATZ_URL = "https://api.stratz.com/graphql",
	STRATZ_QUERY = "{ heroStats { stats(heroIds:[%d], bracketBasicIds:[%s], groupByTime:true, maxTime:90) { time kills deaths assists networth xp cs dn heroDamage } } }",
	BRACKETS = { "HERALD_GUARDIAN", "CRUSADER_ARCHON", "LEGEND_ANCIENT", "DIVINE_IMMORTAL", "ALL" },
	REF_FIELDS = { "kills", "deaths", "assists", "networth", "xp", "cs", "dn", "heroDamage" },
	BENCH_RETRY = 30,
	BENCH_MIN = 2,
	REF_STEP = 10,

	C_VALUE = Color(255, 255, 255, 245),
	C_LABEL = Color(255, 255, 255, 185),
	C_ICON = Color(255, 255, 255, 150),
	C_DIM = Color(255, 255, 255, 110),
	C_REF = Color(255, 255, 255, 120),
	C_DIVIDER = Color(255, 255, 255, 45),
	C_UP = Color(110, 215, 125, 235),
	C_DOWN = Color(240, 95, 85, 235),
	SHADOW_A = 210,
}

local ui = {}

do
	local tab = UI.Create("Info Screen", "Main", "Custom Stats")
	tab:Icon("\u{f080}")

	local page = tab:Create("Main")
	local g_main = page:Create("cs_group_main", Enum.GroupSide.Left)
	local g_view = page:Create("cs_group_view", Enum.GroupSide.Right)

	ui.enable = g_main:Switch("cs_enable", true, "\u{f011}")
	ui.enable:ToolTip("cs_enable_tip")
	local g_extra = ui.enable:Gear("cs_gear_extra")
	ui.hide_native = g_extra:Switch("cs_hide_native", true, "\u{f070}")
	ui.hide_native:ToolTip("cs_hide_native_tip")
	ui.pos_auto = g_extra:Switch("cs_pos_auto", true, "\u{f3c5}")
	ui.pos_auto:ToolTip("cs_pos_auto_tip")
	ui.debug = g_extra:Switch("cs_debug", false, "\u{f188}")
	ui.debug:ToolTip("cs_debug_tip")

	ui.key = g_main:Bind("cs_key", Enum.ButtonCode.KEY_NONE, "\u{f11c}")
	ui.key:ToolTip("cs_key_tip")
	ui.key:Properties(L("cs_bind_name"))

	ui.bench = g_main:Switch("cs_bench", true, "\u{f201}")
	ui.bench:ToolTip("cs_bench_tip")
	local g_bench = ui.bench:Gear("cs_gear_bench")
	ui.rank = g_bench:Combo("cs_rank", { "cs_rank_herald", "cs_rank_crusader", "cs_rank_legend", "cs_rank_divine", "cs_rank_all" }, 2)
	ui.rank:Icon("\u{f091}")
	ui.rank:ToolTip("cs_rank_tip")
	ui.stratz_key = g_bench:Input("cs_stratz_key", "", "\u{f084}")
	ui.stratz_key:ToolTip("cs_stratz_key_tip")

	ui.look = g_view:Label("cs_look", "\u{f53f}")
	ui.look:ToolTip("cs_look_tip")
	local g_look = ui.look:Gear("cs_gear_look")
	ui.font = g_look:Combo("cs_font", { "cs_font_sf_text", "cs_font_sf_rounded", "cs_font_sf_display", "cs_font_segoe" }, 0)
	ui.font:Icon("\u{f031}")
	ui.font:ToolTip("cs_font_tip")
	ui.weight = g_look:Combo("cs_weight", { "cs_weight_regular", "cs_weight_medium", "cs_weight_semibold", "cs_weight_bold", "cs_weight_heavy" }, 3)
	ui.weight:Icon("\u{f032}")
	ui.weight:ToolTip("cs_weight_tip")
	ui.scale = g_look:Slider("cs_scale", 80, 160, 100, "%d%%")
	ui.scale:Icon("\u{f065}")
	ui.scale:ToolTip("cs_scale_tip")
	ui.value_gap = g_look:Slider("cs_value_gap", 0, 150, 20, "%d px")
	ui.value_gap:Icon("\u{f035}")
	ui.value_gap:ToolTip("cs_value_gap_tip")
	ui.icons = g_look:Switch("cs_icons", true, "\u{f03e}")
	ui.icons:ToolTip("cs_icons_tip")
	ui.divider = g_look:Switch("cs_divider", false, "\u{f068}")
	ui.divider:ToolTip("cs_divider_tip")
	ui.roll = g_look:Switch("cs_roll", true, "\u{f2f1}")
	ui.roll:ToolTip("cs_roll_tip")

	ui.rows = g_view:Label("cs_rows", "\u{f0ca}")
	ui.rows:ToolTip("cs_rows_tip")
	local g_rows = ui.rows:Gear("cs_gear_rows")
	ui.row_gpm = g_rows:Switch("cs_row_gpm", true, "\u{f155}")
	ui.row_gpm:ToolTip("cs_row_gpm_tip")
	ui.row_xpm = g_rows:Switch("cs_row_xpm", true, "\u{f005}")
	ui.row_xpm:ToolTip("cs_row_xpm_tip")
	ui.row_lh10 = g_rows:Switch("cs_row_lh10", true, "\u{f017}")
	ui.row_lh10:ToolTip("cs_row_lh10_tip")
	ui.row_part = g_rows:Switch("cs_row_part", true, "\u{f2b5}")
	ui.row_part:ToolTip("cs_row_part_tip")
	ui.row_dmg = g_rows:Switch("cs_row_dmg", true, "\u{f0e7}")
	ui.row_dmg:ToolTip("cs_row_dmg_tip")
end

local state = {
	open = false,
	anim = 0,
	next_update = 0,
	next_native = 0,
	lh10 = nil,
	hero_id = nil,
	rows = {},
	extra = {},
	bench = {},
	bench_ready = false,
	texts = {},
	frame_dt = 0,
	rect = nil,
	press = nil,
	pos = nil,
	saved = {
		x = Config.ReadInt(K.CONFIG, "pos_x", -1),
		y = Config.ReadInt(K.CONFIG, "pos_y", -1),
	},
	native = nil,
	native_hidden = false,
	native_missing_logged = false,
	native_pos = nil,
	native_tries = 0,
	update_error = nil,
	draw_error = nil,
}

local json_ok, JSON = pcall(require, "assets.JSON")
if not json_ok then JSON = nil end

local fonts = {
	cache = {},
	metrics = {},
	icon = Render.LoadFont("FontAwesomeEx", Enum.FontCreate.FONTFLAG_ANTIALIAS, 400),
}

local function log(text)
	if ui.debug:Get() then
		Log.Write("[Custom Stats] " .. text)
	end
end

local function get_font(weight)
	local name = K.FONTS[ui.font:Get() + 1] or K.FONTS[1]
	local id = name .. weight
	if not fonts.cache[id] then
		fonts.cache[id] = Render.LoadFont(name, Enum.FontCreate.FONTFLAG_ANTIALIAS, weight)
		log("font loaded: " .. name .. " " .. weight)
	end
	return fonts.cache[id]
end

local function find_native()
	if state.native and state.native:IsValid() then return state.native end
	state.native = nil
	local hud = Panorama.GetPanelByName("Hud", false)
	if not hud then return nil end
	for _, id in ipairs(K.NATIVE_IDS) do
		local p = hud:FindChildTraverse(id)
		if p then
			state.native = p
			log("native stats found: " .. id)
			return p
		end
	end
	if not state.native_missing_logged then
		state.native_missing_logged = true
		log("native stats not found")
	end
	return nil
end

local function read_native_pos(p)
	if state.native_pos or state.native_tries >= K.NATIVE_TRIES then return true end
	if not p:IsVisible() then
		p:SetVisible(true)
		state.next_native = GameRules.GetGameTime() + K.NATIVE_RETRY
		return false
	end
	local box = p:FindChildTraverse("QuickStatsContainer") or p
	local b = box:GetBounds(true)
	if b and b.w > 0 and b.h > 0 then
		state.native_pos = { x = b.x, y = b.y }
		log("native stats at " .. b.x .. ", " .. b.y)
		return true
	end
	state.native_tries = state.native_tries + 1
	state.next_native = GameRules.GetGameTime() + K.NATIVE_RETRY
	if state.native_tries >= K.NATIVE_TRIES then log("native stats bounds not available") end
	return state.native_tries >= K.NATIVE_TRIES
end

local function update_native()
	local want_hidden = ui.enable:Get() and ui.hide_native:Get()
	local p = find_native()
	if not p then return end
	if ui.enable:Get() and not read_native_pos(p) then return end
	if want_hidden then
		if p:IsVisible() then
			p:SetVisible(false)
			if not state.native_hidden then log("native stats hidden") end
		end
		state.native_hidden = true
	elseif state.native_hidden then
		p:SetVisible(true)
		state.native_hidden = false
		log("native stats restored")
	end
end

local function refresh_disabled()
	local on = ui.enable:Get()
	local bench = on and ui.bench:Get()
	ui.key:Disabled(not on)
	ui.bench:Disabled(not on)
	ui.rank:Disabled(not bench)
	ui.stratz_key:Disabled(not bench)
	pcall(update_native)
end

local function persist_combo(widget, name)
	local saved = Config.ReadInt(K.CONFIG, name, -1)
	if saved >= 0 then widget:Set(saved) end
	widget:SetCallback(function(this)
		Config.WriteInt(K.CONFIG, name, this:Get())
	end)
end

persist_combo(ui.font, "font")
persist_combo(ui.weight, "weight")
persist_combo(ui.rank, "rank")

ui.enable:SetCallback(refresh_disabled, true)
ui.bench:SetCallback(refresh_disabled)
ui.hide_native:SetCallback(function() pcall(update_native) end)

local function group_digits(n)
	local s = tostring(math.floor(n + 0.5))
	local out = s:reverse():gsub("(%d%d%d)", "%1 "):reverse()
	return (out:gsub("^ ", ""))
end

local function round_str(v)
	return v and tostring(math.floor(v + 0.5))
end

local function bench_id(hero_id)
	return hero_id .. ":" .. (K.BRACKETS[ui.rank:Get() + 1] or "ALL")
end

local function on_bench(id, res)
	local now = GameRules.GetGameTime()
	local ok, list = pcall(function()
		if not JSON or not res or tostring(res.code) ~= "200" then return nil end
		local data = JSON:decode(res.response)
		return data and data.data and data.data.heroStats and data.data.heroStats.stats
	end)
	if not ok or type(list) ~= "table" or #list == 0 then
		state.bench[id] = { status = "fail", retry = now + K.BENCH_RETRY }
		log("stratz failed for " .. id .. ": code " .. tostring(res and res.code) .. " " .. tostring(res and res.response):sub(1, 200))
		return
	end
	local by_time, last = {}, 0
	for _, entry in ipairs(list) do
		if type(entry.time) == "number" then
			by_time[entry.time] = entry
			last = math.max(last, entry.time)
		end
	end
	state.bench[id] = { status = "ok", by_time = by_time, last = last }
	log("stratz " .. id .. ": " .. #list .. " minutes")
end

local function request_bench(hero_id)
	local key = ui.stratz_key:Get()
	if not key or key == "" then return end
	local id = bench_id(hero_id)
	local b = state.bench[id]
	if b and (b.status ~= "fail" or GameRules.GetGameTime() < b.retry) then return end
	state.bench[id] = { status = "pending" }
	local body = "{\"query\":\"" .. string.format(K.STRATZ_QUERY, hero_id, K.BRACKETS[ui.rank:Get() + 1] or "ALL") .. "\"}"
	local headers = {
		["Authorization"] = "Bearer " .. key,
		["User-Agent"] = "STRATZ_API",
		["Content-Type"] = "application/json",
	}
	local sent = HTTP.Request("POST", K.STRATZ_URL, { headers = headers, data = body, timeout = 15 }, function(res)
		on_bench(id, res)
	end, "cs_" .. id)
	if sent then
		log("stratz request " .. id)
	else
		state.bench[id] = { status = "fail", retry = GameRules.GetGameTime() + K.BENCH_RETRY }
		log("stratz request not sent")
	end
end

local function current_bench()
	if not ui.bench:Get() or not state.hero_id then return nil end
	local b = state.bench[bench_id(state.hero_id)]
	if not b or b.status ~= "ok" then return nil end
	return b
end

local function ref_at(b, field, minutes)
	local t = math.min(minutes, b.last)
	local lo, hi = math.floor(t), math.ceil(t)
	local a, c = b.by_time[lo], b.by_time[hi]
	if not a or not c or type(a[field]) ~= "number" or type(c[field]) ~= "number" then return nil end
	if lo == hi then return a[field] end
	return a[field] + (c[field] - a[field]) * (t - lo)
end

local function mark(value, ref, minutes)
	if not value or not ref or minutes < K.BENCH_MIN then return nil end
	return value >= ref and 1 or -1
end

local function collect()
	local me = Players.GetLocal()
	if not me then return end
	local team = Player.GetTeamData(me)
	local info = Player.GetTeamPlayer(me)
	if not team or not info then return end

	local clock = GameRules.GetDOTATime()
	local minutes = math.max(clock / 60, 1 / 60)
	local kills, deaths, assists = team.kills or 0, team.deaths or 0, team.assists or 0
	local lh, dn = info.lasthit_count or 0, info.deny_count or 0
	local hero = Heroes.GetLocal()
	local xp = hero and Hero.GetCurrentXP(hero) or info.totalearned_xp or 0
	local gpm = (info.totalearned_gold or 0) / minutes
	local xpm = xp / minutes
	local dmg = info.hero_damage or 0
	local nw = info.networth or 0

	if not state.lh10 and clock >= 600 and clock < 610 then
		state.lh10 = lh
		log("creeps at 10 min: " .. lh)
	end

	local my_team = Entity.GetTeamNum(me)
	local team_kills = 0
	for _, p in ipairs(Players.GetAll()) do
		if Entity.GetTeamNum(p) == my_team then
			local d = Player.GetTeamData(p)
			if d then team_kills = team_kills + (d.kills or 0) end
		end
	end

	local hero_id = team.selected_hero_id
	state.hero_id = hero_id and hero_id > 0 and hero_id or nil
	if ui.bench:Get() and state.hero_id then
		request_bench(state.hero_id)
	end

	local b = current_bench()
	state.bench_ready = b ~= nil
	local r = {}
	if b then
		local ref_min = math.max(math.floor(clock / K.REF_STEP) * K.REF_STEP / 60, 1 / 60)
		for _, field in ipairs(K.REF_FIELDS) do
			r[field] = ref_at(b, field, ref_min)
		end
		local nw0 = b.by_time[0] and b.by_time[0].networth or 0
		r.gpm = r.networth and (r.networth - nw0) / ref_min
		r.xpm = r.xp and r.xp / ref_min
		r.cs10 = b.by_time[10] and b.by_time[10].cs
	end

	local kda_mark, kda_ref
	if r.kills and r.deaths and r.assists then
		kda_mark = mark((kills + assists) / math.max(1, deaths), (r.kills + r.assists) / math.max(1, r.deaths), minutes)
		kda_ref = round_str(r.kills) .. "/" .. round_str(r.deaths) .. "/" .. round_str(r.assists)
	end

	state.rows = {
		{ "\u{f54c}", L("cs_l_kda"), { tostring(kills), "/", tostring(deaths), "/", tostring(assists) }, kda_mark, kda_ref },
		{ "\u{f51e}", L("cs_l_nw"), { group_digits(nw) }, mark(nw, r.networth, minutes), r.networth and group_digits(r.networth), "fade" },
		{ "\u{f140}", L("cs_l_cs"), { tostring(lh), "/", tostring(dn) }, mark(lh, r.cs, minutes), r.cs and (round_str(r.cs) .. "/" .. round_str(r.dn or 0)) },
	}

	local extra = {}
	if ui.row_gpm:Get() then
		extra[#extra + 1] = { "\u{f155}", L("cs_l_gpm"), { tostring(math.floor(gpm)) }, mark(gpm, r.gpm, minutes), round_str(r.gpm), "fade" }
	end
	if ui.row_xpm:Get() then
		extra[#extra + 1] = { "\u{f005}", L("cs_l_xpm"), { tostring(math.floor(xpm)) }, mark(xpm, r.xpm, minutes), round_str(r.xpm), "fade" }
	end
	if ui.row_lh10:Get() then
		extra[#extra + 1] = { "\u{f017}", L("cs_l_lh10"), { state.lh10 and tostring(state.lh10) or "-" }, mark(state.lh10, r.cs10, 10), round_str(r.cs10) }
	end
	if ui.row_part:Get() then
		local part = team_kills > 0 and math.floor((kills + assists) / team_kills * 100 + 0.5) or 0
		extra[#extra + 1] = { "\u{f2b5}", L("cs_l_part"), { math.min(part, 100) .. "%" } }
	end
	if ui.row_dmg:Get() then
		extra[#extra + 1] = { "\u{f0e7}", L("cs_l_dmg"), { group_digits(dmg) }, mark(dmg, r.heroDamage, minutes), r.heroDamage and group_digits(r.heroDamage), "fade" }
	end
	state.extra = extra
end

local function text_shadow(font, size, text, x, y, color, alpha)
	x, y = math.floor(x + 0.5), math.floor(y + 0.5)
	Render.Text(font, size, text, Vec2(x + 1, y + 1), Color(0, 0, 0, math.floor(K.SHADOW_A * alpha)))
	Render.Text(font, size, text, Vec2(x, y), Color(color.r, color.g, color.b, math.floor(color.a * alpha)))
end

local function metric(font, size, key, fn)
	local id = font .. ":" .. size .. ":" .. key
	local v = fonts.metrics[id]
	if not v then
		v = fn()
		fonts.metrics[id] = v
	end
	return v
end

local function char_w(font, size, c)
	return metric(font, size, c, function() return Render.TextSize(font, size, c).x end)
end

local function text_h(font, size)
	return metric(font, size, "#h", function() return Render.TextSize(font, size, "0").y end)
end

local function digit_w(font, size)
	return metric(font, size, "#d", function()
		local w = 0
		for d = 0, 9 do
			w = math.max(w, Render.TextSize(font, size, tostring(d)).x)
		end
		return w
	end)
end

local function slot_w(font, size, c)
	if c:match("%d") then return digit_w(font, size) end
	return char_w(font, size, c)
end

local function tab_width(font, size, text)
	local w = 0
	for i = 1, #text do
		w = w + slot_w(font, size, text:sub(i, i))
	end
	return w
end

local function label_width(font, size, text)
	local w = 0
	for _, cp in utf8.codes(text) do
		w = w + char_w(font, size, utf8.char(cp))
	end
	return w
end

local function draw_char(font, size, c, cx, y, color, alpha)
	local sw = slot_w(font, size, c)
	local off = c:match("%d") and (sw - char_w(font, size, c)) / 2 or 0
	text_shadow(font, size, c, cx + off, y, color, alpha)
	return sw
end

local function draw_tab(font, size, text, x, y, color, alpha)
	local cx = x
	for i = 1, #text do
		cx = cx + draw_char(font, size, text:sub(i, i), cx, y, color, alpha)
	end
end

local function draw_label(font, size, text, x, y, color, alpha)
	local cx = x
	for _, cp in utf8.codes(text) do
		local c = utf8.char(cp)
		text_shadow(font, size, c, cx, y, color, alpha)
		cx = cx + char_w(font, size, c)
	end
end

local function numeric(text)
	return tonumber((text:gsub("[^%d]", "")))
end

local function draw_animated(font, size, key, text, x, y, color, alpha, s, mode)
	local a = state.texts[key]
	if not a then
		a = { cur = text, t = 1 }
		state.texts[key] = a
	end
	if a.cur ~= text then
		local old_n, new_n = numeric(a.cur), numeric(text)
		a.dir = (old_n and new_n and new_n < old_n) and -1 or 1
		a.old, a.cur, a.mode = a.cur, text, mode
		a.t = ui.roll:Get() and 0 or 1
	end
	if a.t < 1 then
		a.t = math.min(1, a.t + state.frame_dt / (a.mode == "fade" and K.FADE_TIME or K.ROLL_TIME))
	end
	if a.t >= 1 or not a.old then
		draw_tab(font, size, text, x, y, color, alpha)
		return
	end

	local e = 1 - (1 - a.t) ^ 3
	local d = a.mode == "fade" and 0 or K.ROLL_DIST * s * a.dir
	local out_y, in_y = y - d * e, y + d * (1 - e)
	local out_a, in_a = alpha * (1 - e), alpha * e

	if #a.old ~= #text then
		local ox = x + tab_width(font, size, text) - tab_width(font, size, a.old)
		draw_tab(font, size, a.old, ox, out_y, color, out_a)
		draw_tab(font, size, text, x, in_y, color, in_a)
		return
	end
	local cx = x
	for i = 1, #text do
		local c, o = text:sub(i, i), a.old:sub(i, i)
		if c == o then
			cx = cx + draw_char(font, size, c, cx, y, color, alpha)
		else
			draw_char(font, size, o, cx, out_y, color, out_a)
			cx = cx + draw_char(font, size, c, cx, in_y, color, in_a)
		end
	end
end

local function value_width(font, size, parts)
	local w = 0
	for _, part in ipairs(parts) do
		w = w + tab_width(font, size, part)
	end
	return w
end

local function draw_row(f, row, x, y, w, ref_w, s, alpha)
	local fs = K.FONT_SIZE * s
	local h = K.ROW_H * s
	local tx = x
	if ui.icons:Get() then
		local isz = K.ICON_SIZE * s
		local gsz = Render.TextSize(fonts.icon, isz, row[1])
		text_shadow(fonts.icon, isz, row[1], x + (K.ICON_W * s - gsz.x) / 2, y + (h - gsz.y) / 2, K.C_ICON, alpha)
		tx = x + (K.ICON_W + K.GAP) * s
	end
	draw_label(f.label, fs, row[2], tx, y + (h - text_h(f.label, fs)) / 2, K.C_LABEL, alpha)

	local right = x + w
	if ref_w > 0 then
		if row[5] then
			local ry = y + (h - text_h(f.label, fs)) / 2
			draw_animated(f.label, fs, row[2] .. "|ref", row[5], right - tab_width(f.label, fs, row[5]), ry, K.C_REF, alpha, s, "roll")
		end
		right = right - ref_w - K.TRI_W * s
		if row[4] then
			local glyph = row[4] > 0 and "\u{f0d8}" or "\u{f0d7}"
			local tsz = K.TRI_SIZE * s
			local gsz = Render.TextSize(fonts.icon, tsz, glyph)
			text_shadow(fonts.icon, tsz, glyph, right + (K.TRI_W * s - gsz.x) / 2, y + (h - gsz.y) / 2, row[4] > 0 and K.C_UP or K.C_DOWN, alpha)
		end
	end

	local vy = y + (h - text_h(f.value, fs)) / 2
	local vx = right - value_width(f.value, fs, row[3])
	for i, part in ipairs(row[3]) do
		if part == "/" then
			draw_tab(f.value, fs, part, vx, vy, K.C_DIM, alpha)
		else
			draw_animated(f.value, fs, row[2] .. "|" .. i, part, vx, vy, K.C_VALUE, alpha, s, row[6] or "roll")
		end
		vx = vx + tab_width(f.value, fs, part)
	end
end

local function draw_divider(x, y, w, alpha)
	local ly = math.floor(y + 0.5)
	Render.FilledRect(Vec2(x, ly + 1), Vec2(x + w, ly + 2), Color(0, 0, 0, math.floor(K.SHADOW_A * 0.5 * alpha)))
	Render.FilledRect(Vec2(x, ly), Vec2(x + w, ly + 1), Color(K.C_DIVIDER.r, K.C_DIVIDER.g, K.C_DIVIDER.b, math.floor(K.C_DIVIDER.a * alpha)))
end

local function measure(f, rows, s)
	local fs = K.FONT_SIZE * s
	local lw, vw = 0, 0
	for _, row in ipairs(rows) do
		lw = math.max(lw, label_width(f.label, fs, row[2]))
		vw = math.max(vw, value_width(f.value, fs, row[3]))
	end
	local icon = ui.icons:Get() and (K.ICON_W + K.GAP) * s or 0
	return icon + lw + ui.value_gap:Get() * s + vw
end

local function measure_ref(f, rows, s)
	local fs = K.FONT_SIZE * s
	local rw = 0
	for _, row in ipairs(rows) do
		if row[5] then
			rw = math.max(rw, tab_width(f.label, fs, row[5]))
		end
	end
	return math.ceil(rw)
end

local function snap_points(size, extent, native)
	local m = K.SNAP_MARGIN
	local list = { m, (size - extent) / 2, size - extent - m }
	if native then list[#list + 1] = native end
	return list
end

local function snap_axis(v, points)
	local best, dist = v, K.SNAP_DIST
	for _, pt in ipairs(points) do
		local d = math.abs(v - pt)
		if d < dist then best, dist = pt, d end
	end
	return best
end

local function handle_drag()
	local p, r = state.press, state.rect
	if not p or not r then return end
	local mx, my = Input.GetCursorPos()
	local dx, dy = mx - p.mx, my - p.my
	if not p.drag and (math.abs(dx) > K.DRAG_START or math.abs(dy) > K.DRAG_START) then
		p.drag = true
	end
	if p.drag then
		local screen = Render.ScreenSize()
		local n = state.native_pos
		local x = math.max(0, math.min(screen.x - r[3], p.ox + dx))
		local y = math.max(0, math.min(screen.y - r[4], p.oy + dy))
		p.x = snap_axis(x, snap_points(screen.x, r[3], n and n.x))
		p.y = snap_axis(y, snap_points(screen.y, r[4], n and n.y))
	end
end

local function target_pos()
	local p, n, saved = state.press, state.native_pos, state.saved
	if p and p.drag then return p.x, p.y end
	if ui.pos_auto:Get() and n then return n.x, n.y end
	if saved.x >= 0 and saved.y >= 0 then return saved.x, saved.y end
	if n then return n.x, n.y end
	return K.DEFAULT_X, K.DEFAULT_Y
end

local function update_pos(dt)
	local tx, ty = target_pos()
	local pos = state.pos
	if not pos or (state.press and state.press.drag) then
		state.pos = { x = tx, y = ty }
		return
	end
	local k = 1 - math.exp(-dt * K.POS_SPEED)
	pos.x = pos.x + (tx - pos.x) * k
	pos.y = pos.y + (ty - pos.y) * k
	if math.abs(tx - pos.x) < 0.3 and math.abs(ty - pos.y) < 0.3 then
		pos.x, pos.y = tx, ty
	end
end

local function finish_drag(p)
	local x, y = math.floor(p.x + 0.5), math.floor(p.y + 0.5)
	state.saved = { x = x, y = y }
	Config.WriteInt(K.CONFIG, "pos_x", x)
	Config.WriteInt(K.CONFIG, "pos_y", y)
	local n = state.native_pos
	ui.pos_auto:Set(n ~= nil and p.x == n.x and p.y == n.y)
	state.pos = { x = p.x, y = p.y }
	log("moved to " .. x .. ", " .. y)
end

local function on_mouse(event)
	if event == Enum.EKeyEvent.EKeyEvent_KEY_DOWN then
		if state.press then return false end
		local r = state.rect
		if not r or not state.pos or not Input.IsCursorInRect(r[1], r[2], r[3], r[4]) then return true end
		local mx, my = Input.GetCursorPos()
		state.press = { mx = mx, my = my, ox = state.pos.x, oy = state.pos.y, drag = false }
		return false
	end
	if event == Enum.EKeyEvent.EKeyEvent_KEY_UP and state.press then
		local p = state.press
		state.press = nil
		if p.drag then
			finish_drag(p)
		else
			state.open = not state.open
			log("open by click: " .. tostring(state.open))
		end
		return false
	end
	return true
end

local function draw_panel()
	if #state.rows == 0 then return end
	handle_drag()

	local weight = K.WEIGHTS[ui.weight:Get() + 1] or 700
	local f = { value = get_font(weight), label = get_font(math.max(400, weight - 100)) }
	local s = ui.scale:Get() / 100
	local dt = math.min(0.1, GlobalVars.GetAbsFrameTime())
	state.frame_dt = dt
	update_pos(dt)
	local x = math.floor(state.pos.x + 0.5)
	local y = math.floor(state.pos.y + 0.5)

	local target = (state.open and #state.extra > 0) and 1 or 0
	state.anim = state.anim + (target - state.anim) * (1 - math.exp(-dt * K.SPEED))
	if math.abs(target - state.anim) < 0.002 then state.anim = target end

	local ref_w = state.bench_ready and math.max(measure_ref(f, state.rows, s), measure_ref(f, state.extra, s)) or 0
	local tail = ref_w > 0 and (ref_w + K.TRI_W * s) or 0
	local w = math.ceil(math.max(measure(f, state.rows, s), measure(f, state.extra, s)) + tail)
	local h = K.ROW_H * s
	for i, row in ipairs(state.rows) do
		draw_row(f, row, x, y + (i - 1) * h, w, ref_w, s, 1)
	end

	local base_h = #state.rows * h
	local gap = (ui.divider:Get() and K.DIVIDER_GAP or K.EXTRA_GAP) * s
	local extra_h = (#state.extra * h + gap) * state.anim
	if state.anim > 0 then
		local top = y + base_h
		Render.PushClip(Vec2(x - 2, top), Vec2(x + w + 4, top + extra_h + 2), true)
		if ui.divider:Get() then
			draw_divider(x, top + gap / 2 - 1, w, state.anim)
		end
		local shift = (1 - state.anim) * 6 * s
		for i, row in ipairs(state.extra) do
			draw_row(f, row, x, top + gap + (i - 1) * h - shift, w, ref_w, s, state.anim)
		end
		Render.PopClip()
	end
	state.rect = { x, y, w, base_h + extra_h }
end

local script = {}

function script.OnUpdate()
	if not ui.enable:Get() then return end

	if ui.key:IsPressed() and not Input.IsInputCaptured() then
		state.open = not state.open
		log("open by key: " .. tostring(state.open))
	end

	local now = GameRules.GetGameTime()
	if now >= state.next_native then
		state.next_native = now + K.NATIVE_INTERVAL
		local ok, err = pcall(update_native)
		if not ok then log("native: " .. tostring(err)) end
	end

	if now < state.next_update then return end
	state.next_update = now + K.UPDATE_INTERVAL
	local ok, err = pcall(collect)
	if not ok and err ~= state.update_error then
		state.update_error = err
		Log.Write("[Custom Stats] update: " .. tostring(err))
	end
end

function script.OnDraw()
	if not ui.enable:Get() then return end
	local ok, err = pcall(draw_panel)
	if not ok and err ~= state.draw_error then
		state.draw_error = err
		Log.Write("[Custom Stats] draw: " .. tostring(err))
	end
end

function script.OnKeyEvent(data)
	if data.key ~= Enum.ButtonCode.KEY_MOUSE1 or not ui.enable:Get() or #state.rows == 0 then return true end
	local ok, res = pcall(on_mouse, data.event)
	if not ok then
		log("mouse: " .. tostring(res))
		return true
	end
	return res
end

function script.OnGameEnd()
	state.lh10 = nil
	state.hero_id = nil
	state.rows = {}
	state.extra = {}
	state.bench_ready = false
	state.texts = {}
	state.rect = nil
	state.press = nil
	state.pos = nil
	state.native = nil
	state.native_hidden = false
	state.native_pos = nil
	state.native_tries = 0
end

return script
