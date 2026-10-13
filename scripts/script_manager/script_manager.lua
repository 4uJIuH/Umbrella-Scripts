--[[
     ~ author: 4uJIuH
     ~ UI author: watahell / papagdetto

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
		sm_group_main = "Script Manager",
		sm_enable = "Enable",
		sm_enable_tip = "Shows the Script Manager window",
		sm_key = "Manager window",
		sm_key_tip = "Opens and closes Script Manager",
		sm_bind_name = "Script Manager",
		sm_open = "Open or close the window",

		sm_nav_all = "All",
		sm_nav_installed = "Installed",
		sm_nav_updates = "Updates",
		sm_nav_heroes = "Heroes",
		sm_heroes_with = "With scripts",
		sm_heroes_all = "All heroes",
		sm_empty_hero = "No scripts yet",
		sm_empty_hero_d = "Nobody has made one for this hero",
		sm_cats = "Categories",
		sm_cat_dota = "Dota 2",
		sm_cat_deadlock = "Deadlock",
		sm_cat_auxiliary = "Tools",

		sm_search = "Search",
		sm_sort_catalog = "Catalog order",
		sm_sort_name = "By name",
		sm_sort_inst = "Installed first",

		sm_upd_one = "%d update available",
		sm_upd_few = "%d updates available",
		sm_upd_many = "%d updates available",
		sm_update_all = "Update all",

		sm_install = "Install",
		sm_installing = "Installing",
		sm_download = "Download",
		sm_update = "Update",
		sm_installed = "Installed",
		sm_remove = "Remove",
		sm_remove_confirm = "Remove the file?",

		sm_empty_search = "Nothing found",
		sm_empty_search_d = "Try another name",
		sm_empty_upd = "No updates",
		sm_empty_upd_d = "Everything installed is up to date",
		sm_empty = "Empty",
		sm_empty_d = "Nothing here yet",
		sm_loading = "Loading the catalog",
		sm_loading_d = "One moment",
		sm_err_catalog = "Catalog is unavailable",
		sm_err_catalog_d = "Check the connection and press refresh",

		sm_st_version = "Version",
		sm_st_installed = "Installed",
		sm_st_available = "Available",
		sm_st_category = "Category",
		sm_st_library = "Library",
		sm_source = "Source",
		sm_author = "Author",
		sm_lib_nlz = "qLocalization",
		sm_lib_none = "Not needed",
		sm_about = "About",
		sm_features = "Features",

		sm_restart_t = "Restart needed",
		sm_restart_one = "Changes in %s apply after a restart.",
		sm_restart_n_one = "Changes in %d script apply after a restart.",
		sm_restart_n_few = "Changes in %d scripts apply after a restart.",
		sm_restart_n_many = "Changes in %d scripts apply after a restart.",
		sm_restart_btn = "Restart scripts",
		sm_later = "Later",
		sm_restarted = "Restarting scripts",
		sm_checked = "Checked at %s",
		sm_checking = "Checking",
		sm_check_failed = "Check failed",
		sm_unchecked = "Not checked yet",
		sm_err_t = "Something went wrong",
		sm_ok = "Got it",
		sm_manual_t = "Downloaded",
		sm_manual_msg = "%s was downloaded to your scripts folder. Follow the package's installation instructions.",

		sm_e_dir = "Scripts folder is unavailable",
		sm_e_url = "Address is not trusted",
		sm_e_valid = "Downloaded file failed validation",
		sm_e_write = "Could not write the file",
		sm_e_folder = "Could not create the package folder",
		sm_e_nlz = "qLocalization is missing in the catalog",
		sm_e_net = "No answer from the server",
		sm_e_parse = "Catalog could not be read",
		sm_e_remove = "Could not remove the file",

		sm_settings = "Settings",
		sm_g_updates = "UPDATES",
		sm_g_look = "APPEARANCE",
		sm_set_check = "Check",
		sm_check_start = "On launch",
		sm_check_hour = "Every hour",
		sm_set_beta = "Beta versions",
		sm_set_restart = "Restart",
		sm_restart_ask = "Ask",
		sm_restart_now = "Right away",
		sm_set_theme = "Theme",
		sm_set_accent = "Accent",
		sm_theme_graphite = "Graphite",
		sm_theme_midnight = "Midnight",
		sm_theme_warm = "Warm",
		sm_theme_purple = "Purple",
		sm_theme_crimson = "Crimson",
		sm_theme_forest = "Forest",
		sm_theme_oled = "OLED",
		sm_accent_blue = "Blue",
		sm_accent_teal = "Teal",
		sm_accent_green = "Green",
		sm_accent_purple = "Purple",
		sm_accent_orange = "Orange",
		sm_accent_red = "Red",
		sm_accent_pink = "Pink",
	},
	ru = {
		sm_group_main = "Script Manager",
		sm_enable = "Включить",
		sm_enable_tip = "Показывает окно Script Manager",
		sm_key = "Окно менеджера",
		sm_key_tip = "Открывает и закрывает Script Manager",
		sm_bind_name = "Script Manager",
		sm_open = "Открыть или закрыть окно",

		sm_nav_all = "Все",
		sm_nav_installed = "Установленные",
		sm_nav_updates = "Обновления",
		sm_nav_heroes = "Герои",
		sm_heroes_with = "Со скриптами",
		sm_heroes_all = "Все герои",
		sm_empty_hero = "Скриптов пока нет",
		sm_empty_hero_d = "Для этого героя еще никто не сделал",
		sm_cats = "Категории",
		sm_cat_dota = "Dota 2",
		sm_cat_deadlock = "Deadlock",
		sm_cat_auxiliary = "Инструменты",

		sm_search = "Поиск",
		sm_sort_catalog = "Как в каталоге",
		sm_sort_name = "По названию",
		sm_sort_inst = "Установленные сверху",

		sm_upd_one = "Доступно %d обновление",
		sm_upd_few = "Доступно %d обновления",
		sm_upd_many = "Доступно %d обновлений",
		sm_update_all = "Обновить все",

		sm_install = "Установить",
		sm_installing = "Установка",
		sm_download = "Скачать",
		sm_update = "Обновить",
		sm_installed = "Установлен",
		sm_remove = "Удалить",
		sm_remove_confirm = "Удалить файл?",

		sm_empty_search = "Ничего не найдено",
		sm_empty_search_d = "Попробуй другое название",
		sm_empty_upd = "Обновлений нет",
		sm_empty_upd_d = "Все установленные скрипты последней версии",
		sm_empty = "Пусто",
		sm_empty_d = "Здесь пока ничего нет",
		sm_loading = "Загружаю каталог",
		sm_loading_d = "Секунду",
		sm_err_catalog = "Каталог недоступен",
		sm_err_catalog_d = "Проверь соединение и нажми обновить",

		sm_st_version = "Версия",
		sm_st_installed = "Установлена",
		sm_st_available = "Доступна",
		sm_st_category = "Категория",
		sm_st_library = "Библиотека",
		sm_source = "Источник",
		sm_author = "Автор",
		sm_lib_nlz = "qLocalization",
		sm_lib_none = "Не нужна",
		sm_about = "Описание",
		sm_features = "Возможности",

		sm_restart_t = "Нужен перезапуск",
		sm_restart_one = "Изменения в %s вступят в силу после перезапуска.",
		sm_restart_n_one = "Изменения в %d скрипте вступят в силу после перезапуска.",
		sm_restart_n_few = "Изменения в %d скриптах вступят в силу после перезапуска.",
		sm_restart_n_many = "Изменения в %d скриптах вступят в силу после перезапуска.",
		sm_restart_btn = "Перезапустить скрипты",
		sm_later = "Позже",
		sm_restarted = "Перезапуск скриптов",
		sm_checked = "Проверено в %s",
		sm_checking = "Проверка",
		sm_check_failed = "Не удалось проверить",
		sm_unchecked = "Еще не проверялось",
		sm_err_t = "Что-то пошло не так",
		sm_ok = "Понятно",
		sm_manual_t = "Скачано",
		sm_manual_msg = "%s скачан в папку скриптов. Следуй инструкции по установке из этого пакета.",

		sm_e_dir = "Папка скриптов недоступна",
		sm_e_url = "Адрес не из доверенных",
		sm_e_valid = "Скачанный файл не прошел проверку",
		sm_e_write = "Не удалось записать файл",
		sm_e_folder = "Не удалось создать папку пакета",
		sm_e_nlz = "В каталоге нет qLocalization",
		sm_e_net = "Сервер не ответил",
		sm_e_parse = "Не удалось прочитать каталог",
		sm_e_remove = "Не удалось удалить файл",

		sm_settings = "Настройки",
		sm_g_updates = "ОБНОВЛЕНИЯ",
		sm_g_look = "ОФОРМЛЕНИЕ",
		sm_set_check = "Проверять",
		sm_check_start = "При запуске",
		sm_check_hour = "Каждый час",
		sm_set_beta = "Бета-версии",
		sm_set_restart = "Перезапуск",
		sm_restart_ask = "Спрашивать",
		sm_restart_now = "Сразу",
		sm_set_theme = "Тема",
		sm_set_accent = "Акцент",
		sm_theme_graphite = "Графит",
		sm_theme_midnight = "Полночь",
		sm_theme_warm = "Теплая",
		sm_theme_purple = "Фиолетовая",
		sm_theme_crimson = "Бордовая",
		sm_theme_forest = "Лесная",
		sm_theme_oled = "OLED",
		sm_accent_blue = "Синий",
		sm_accent_teal = "Бирюзовый",
		sm_accent_green = "Зеленый",
		sm_accent_purple = "Фиолетовый",
		sm_accent_orange = "Оранжевый",
		sm_accent_red = "Красный",
		sm_accent_pink = "Розовый",
	},
})

local UI = localization.WrapLibrary(Menu)
local L = localization.Get
local JSON = require("assets.JSON")

local VERSION = "2.0.2"

local K = {
	CFG = "script_market",
	CATALOG = "https://raw.githubusercontent.com/4uJIuH/umbrella-scripts/main/scripts/manager/catalog.json",
	META = "https://raw.githubusercontent.com/4uJIuH/umbrella-scripts/main/.github/catalog.json",
	TRUST = {
		"^https://raw%.githubusercontent%.com/[%w%-_%.]+/[%w%-_%.]+/",
		"^https://github%.com/[%w%-_%.]+/[%w%-_%.]+/releases/download/",
	},
	NLZ_FILE = "!_qLocalizer.lua",
	RECHECK = 3600,
	RELOAD_DELAY = 0.6,
	W = 920,
	H = 640,
	SIDE = 220,
	TOP = 68,
	SCALE_MIN = 70,
	SCALE_MAX = 160,
	WHEEL = 72,
	QUERY_MAX = 32,
	SINK_ALIVE = 0.4,
	SINK_TIMEOUT = 1500,
	ACCENT = { 76, 130, 247 },
	ACCENT_TEXT = { 127, 166, 255 },
	G = {
		all = "\u{f03a}", installed = "\u{f058}", updates = "\u{f358}", heroes = "\u{f007}",
		dota = "\u{f11b}", deadlock = "\u{f06d}", auxiliary = "\u{f0ad}",
		search = "\u{f002}", clear = "\u{f057}", sort = "\u{f160}", refresh = "\u{f2f9}", sliders = "\u{f1de}",
		back = "\u{f053}", down = "\u{f078}", up = "\u{f077}", check = "\u{f00c}", store = "\u{f54e}",
	},
}

local T = {
	t1 = { 245, 245, 247 },
	t2 = { 199, 199, 204 },
	t3 = { 154, 154, 160 },
	t4 = { 124, 124, 130 },
	t5 = { 229, 229, 234 },
	white = { 255, 255, 255 },
	pill = { 242, 242, 245 },
	dark = { 17, 17, 19 },
	red = { 255, 122, 114 },
	red_bg = { 255, 92, 82, 41 },
	knob_off = { 142, 142, 147 },
}

local THEME_ORDER = { "graphite", "midnight", "warm", "purple", "crimson", "forest", "oled" }

local THEMES = {
	graphite = { win = { 25, 25, 27 }, side = { 20, 20, 22 }, menu = { 38, 38, 41 }, card = { 32, 32, 35 }, dd = { 42, 42, 46 }, off = { 56, 56, 61 }, line = 18, field = 15 },
	midnight = { win = { 17, 20, 31 }, side = { 13, 16, 26 }, menu = { 32, 38, 56 }, card = { 24, 29, 44 }, dd = { 37, 44, 65 }, off = { 52, 60, 84 }, line = 20, field = 16 },
	warm = { win = { 26, 22, 19 }, side = { 21, 18, 15 }, menu = { 42, 36, 31 }, card = { 35, 30, 26 }, dd = { 47, 40, 34 }, off = { 64, 56, 48 }, line = 18, field = 15 },
	purple = { win = { 22, 17, 32 }, side = { 17, 13, 26 }, menu = { 40, 31, 58 }, card = { 32, 25, 47 }, dd = { 46, 36, 67 }, off = { 62, 49, 88 }, line = 20, field = 16 },
	crimson = { win = { 28, 16, 18 }, side = { 22, 12, 14 }, menu = { 46, 28, 31 }, card = { 38, 22, 25 }, dd = { 52, 32, 36 }, off = { 70, 44, 49 }, line = 20, field = 16 },
	forest = { win = { 17, 25, 21 }, side = { 13, 20, 16 }, menu = { 32, 46, 39 }, card = { 24, 35, 29 }, dd = { 37, 52, 44 }, off = { 52, 70, 60 }, line = 20, field = 16 },
	oled = { win = { 0, 0, 0 }, side = { 9, 9, 10 }, menu = { 26, 26, 28 }, card = { 15, 15, 17 }, dd = { 28, 28, 31 }, off = { 44, 44, 48 }, line = 23, field = 18 },
}

local ACCENT_ORDER = { "blue", "teal", "green", "purple", "orange", "red", "pink" }

local ACCENTS = {
	blue = { 76, 130, 247 },
	teal = { 38, 166, 154 },
	green = { 52, 168, 83 },
	purple = { 138, 99, 210 },
	orange = { 240, 140, 40 },
	red = { 226, 75, 75 },
	pink = { 232, 90, 150 },
}

local PAL = {
	blue = { 90, 162, 255 }, green = { 92, 203, 114 }, orange = { 245, 164, 66 }, pink = { 255, 107, 138 },
	purple = { 180, 140, 255 }, cyan = { 79, 203, 224 }, teal = { 48, 176, 199 }, red = { 255, 122, 114 },
	gray = { 142, 142, 147 }, yellow = { 255, 214, 10 },
}

local PAL_ORDER = { "blue", "green", "orange", "pink", "purple", "cyan", "teal", "red", "yellow" }

local STYLE = {
	tinker_turret_dodge = { "\u{f3ed}", PAL.blue },
	tinker_auto_farm = { "\u{f290}", PAL.orange },
	auto_shackleshot = { "\u{f245}", PAL.teal },
	auto_spark = { "\u{f0e7}", PAL.purple },
	rune_destruction = { "\u{f06b}", PAL.pink },
	earth_spirit_kick_combo = { "\u{f25a}", PAL.green },
	hp_mana_67_ping = { "\u{f295}", PAL.red },
	spirit_bear_pull = { "\u{f0c0}", PAL.cyan },
	script_manager = { "\u{f0ad}", PAL.gray },
}

local CAT_ORDER = { "dota", "deadlock", "auxiliary" }

local SCRIPTS = {}
local BY_ID = {}
local CATS = {}

local HEROES = {
	{ "abaddon", "Abaddon" }, { "alchemist", "Alchemist" }, { "ancient_apparition", "Ancient Apparition" },
	{ "antimage", "Anti-Mage" }, { "arc_warden", "Arc Warden" }, { "axe", "Axe" },
	{ "bane", "Bane" }, { "batrider", "Batrider" }, { "beastmaster", "Beastmaster" },
	{ "bloodseeker", "Bloodseeker" }, { "bounty_hunter", "Bounty Hunter" }, { "brewmaster", "Brewmaster" },
	{ "bristleback", "Bristleback" }, { "broodmother", "Broodmother" }, { "centaur", "Centaur Warrunner" },
	{ "chaos_knight", "Chaos Knight" }, { "chen", "Chen" }, { "clinkz", "Clinkz" },
	{ "rattletrap", "Clockwerk" }, { "crystal_maiden", "Crystal Maiden" }, { "dark_seer", "Dark Seer" },
	{ "dark_willow", "Dark Willow" }, { "dawnbreaker", "Dawnbreaker" }, { "dazzle", "Dazzle" },
	{ "death_prophet", "Death Prophet" }, { "disruptor", "Disruptor" }, { "doom_bringer", "Doom" },
	{ "dragon_knight", "Dragon Knight" }, { "drow_ranger", "Drow Ranger" }, { "earth_spirit", "Earth Spirit" },
	{ "earthshaker", "Earthshaker" }, { "elder_titan", "Elder Titan" }, { "ember_spirit", "Ember Spirit" },
	{ "enchantress", "Enchantress" }, { "enigma", "Enigma" }, { "faceless_void", "Faceless Void" },
	{ "grimstroke", "Grimstroke" }, { "gyrocopter", "Gyrocopter" }, { "hoodwink", "Hoodwink" },
	{ "huskar", "Huskar" }, { "invoker", "Invoker" }, { "wisp", "Io" },
	{ "jakiro", "Jakiro" }, { "juggernaut", "Juggernaut" }, { "keeper_of_the_light", "Keeper of the Light" },
	{ "kez", "Kez" }, { "kunkka", "Kunkka" }, { "largo", "Largo" },
	{ "legion_commander", "Legion Commander" }, { "leshrac", "Leshrac" }, { "lich", "Lich" },
	{ "life_stealer", "Lifestealer" }, { "lina", "Lina" }, { "lion", "Lion" },
	{ "lone_druid", "Lone Druid" }, { "luna", "Luna" }, { "lycan", "Lycan" },
	{ "magnataur", "Magnus" }, { "marci", "Marci" }, { "mars", "Mars" },
	{ "medusa", "Medusa" }, { "meepo", "Meepo" }, { "mirana", "Mirana" },
	{ "monkey_king", "Monkey King" }, { "morphling", "Morphling" }, { "muerta", "Muerta" },
	{ "naga_siren", "Naga Siren" }, { "furion", "Nature's Prophet" }, { "necrolyte", "Necrophos" },
	{ "night_stalker", "Night Stalker" }, { "nyx_assassin", "Nyx Assassin" }, { "ogre_magi", "Ogre Magi" },
	{ "omniknight", "Omniknight" }, { "oracle", "Oracle" }, { "obsidian_destroyer", "Outworld Devourer" },
	{ "pangolier", "Pangolier" }, { "phantom_assassin", "Phantom Assassin" }, { "phantom_lancer", "Phantom Lancer" },
	{ "phoenix", "Phoenix" }, { "primal_beast", "Primal Beast" }, { "puck", "Puck" },
	{ "pudge", "Pudge" }, { "pugna", "Pugna" }, { "queenofpain", "Queen of Pain" },
	{ "razor", "Razor" }, { "riki", "Riki" }, { "ringmaster", "Ring Master" },
	{ "rubick", "Rubick" }, { "sand_king", "Sand King" }, { "shadow_demon", "Shadow Demon" },
	{ "nevermore", "Shadow Fiend" }, { "shadow_shaman", "Shadow Shaman" }, { "silencer", "Silencer" },
	{ "skywrath_mage", "Skywrath Mage" }, { "slardar", "Slardar" }, { "slark", "Slark" },
	{ "snapfire", "Snapfire" }, { "sniper", "Sniper" }, { "spectre", "Spectre" },
	{ "spirit_breaker", "Spirit Breaker" }, { "storm_spirit", "Storm Spirit" }, { "sven", "Sven" },
	{ "techies", "Techies" }, { "templar_assassin", "Templar Assassin" }, { "terrorblade", "Terrorblade" },
	{ "tidehunter", "Tidehunter" }, { "shredder", "Timbersaw" }, { "tinker", "Tinker" },
	{ "tiny", "Tiny" }, { "treant", "Treant Protector" }, { "troll_warlord", "Troll Warlord" },
	{ "tusk", "Tusk" }, { "abyssal_underlord", "Underlord" }, { "undying", "Undying" },
	{ "ursa", "Ursa" }, { "vengefulspirit", "Vengeful Spirit" }, { "venomancer", "Venomancer" },
	{ "viper", "Viper" }, { "visage", "Visage" }, { "void_spirit", "Void Spirit" },
	{ "warlock", "Warlock" }, { "weaver", "Weaver" }, { "windrunner", "Windranger" },
	{ "winter_wyvern", "Winter Wyvern" }, { "witch_doctor", "Witch Doctor" }, { "skeleton_king", "Wraith King" },
	{ "zuus", "Zeus" },
}

local HERO_BY_ID = {}
local HERO_KEY = {}
for i, h in ipairs(HEROES) do
	HERO_BY_ID[h[1]] = { id = h[1], name = h[2], order = i }
	HERO_KEY[h[1]:gsub("[^%a%d]", "")] = h[1]
	HERO_KEY[h[2]:lower():gsub("[^%a%d]", "")] = h[1]
end

local SORTS = {
	{ id = "catalog", key = "sm_sort_catalog", cmp = function(a, b) return a.order < b.order end },
	{ id = "name", key = "sm_sort_name", cmp = function(a, b) return a.title:lower() < b.title:lower() end },
}

local SETS = {
	check = { "start", "hour" },
	restart = { "ask", "now" },
	theme = THEME_ORDER,
	accent = ACCENT_ORDER,
}

local S = {
	open = true, alpha = 0, wx = nil, wy = nil, lang = "en",
	scale = Config.ReadInt(K.CFG, "scale", 100),
	nav = "all", view = "list", sel = nil, hero = nil, hero_n = {}, hero_total = 0, hero_names = {}, images = {},
	sort = Config.ReadString(K.CFG, "sort", "catalog"),
	inst_first = Config.ReadInt(K.CFG, "inst_first", 0) == 1,
	sort_open = false, menu = nil,
	rows = {}, banner_n = 0,
	query = "", focus = false, confirm = nil, qc = 0, qa = nil, q_off = 0, q_drag = false, q_click = 0, q_blink = 0,
	foot = "idle", foot_until = 0, changed = {}, note = nil, reload_at = nil,
	net = { state = "idle", at = 0, stamp = 0, err = nil, loaded = false },
	inst = {}, busy = {}, nlz = nil, nlz_wait = nil, dir = nil,
	set = {
		check = Config.ReadString(K.CFG, "check", "start"),
		beta = Config.ReadInt(K.CFG, "beta", 0) == 1,
		restart = Config.ReadString(K.CFG, "restart", "ask"),
		theme = Config.ReadString(K.CFG, "theme", "graphite"),
		accent = Config.ReadString(K.CFG, "accent", "blue"),
	},
	scroll = 0, scroll_to = 0, scroll_t = -10, content_h = 0, view_h = 0, area = { 0, 0, 0, 0 }, page_key = "",
	tweens = {}, swaps = {}, vers = {}, badges = {}, dt = 0, now = 0, press = nil, drag = nil, resize = nil,
}

do
	local function valid(list, v, default)
		for _, o in ipairs(list) do
			if o == v then return v end
		end
		return default
	end
	for name, list in pairs(SETS) do
		S.set[name] = valid(list, S.set[name], list[1])
	end
	local ids = {}
	for i, o in ipairs(SORTS) do ids[i] = o.id end
	S.sort = valid(ids, S.sort, SORTS[1].id)
	S.scale = math.max(K.SCALE_MIN, math.min(K.SCALE_MAX, S.scale))
end

local C = THEMES[S.set.theme]

local function apply_accent(id)
	local a = ACCENTS[id]
	for i = 1, 3 do
		K.ACCENT[i] = a[i]
		K.ACCENT_TEXT[i] = math.floor(a[i] + (255 - a[i]) * 0.35 + 0.5)
	end
end

apply_accent(S.set.accent)

local ui = {}

do
	local tab = UI.Create("Scripts", "Scripts", "Script Manager")
	tab:Icon(K.G.store)

	local page = tab:Create("Settings")
	local g_main = page:Create("sm_group_main", Enum.GroupSide.Left)

	ui.enable = g_main:Switch("sm_enable", true, "\u{f011}")
	ui.enable:ToolTip("sm_enable_tip")

	ui.key = g_main:Bind("sm_key", Enum.ButtonCode.KEY_NONE, "\u{f11c}")
	ui.key:ToolTip("sm_key_tip")
	ui.key:Properties(L("sm_bind_name"))

	ui.open = g_main:Button("sm_open", function() S.open = not S.open end)
	ui.open:Icon("\u{f2d0}")
end

local ROUND = Enum.DrawFlags.RoundCornersAll
local KEY = Enum.ButtonCode

local function clamp(v, a, b) return v < a and a or (v > b and b or v) end
local function ease_out(t) return 1 - (1 - t) * (1 - t) end
local function ease_in_out(t) return t < 0.5 and 2 * t * t or 1 - (-2 * t + 2) ^ 2 / 2 end
local function tr(x) return x[S.lang] ~= "" and x[S.lang] or x.en end

local function plural(n, base)
	if S.lang ~= "ru" then return L(base .. (n == 1 and "_one" or "_many")) end
	local m10, m100 = n % 10, n % 100
	if m10 == 1 and m100 ~= 11 then return L(base .. "_one") end
	if m10 >= 2 and m10 <= 4 and (m100 < 12 or m100 > 14) then return L(base .. "_few") end
	return L(base .. "_many")
end

local function short_ver(v)
	return v:match("beta%.%d+$") or v:match("alpha%.%d+$") or v
end

local function save(key, value)
	if type(value) == "number" then
		Config.WriteInt(K.CFG, key, value)
	else
		Config.WriteString(K.CFG, key, value)
	end
end

local asset = { fonts = {}, sizes = {} }

function asset.font(weight)
	local f = asset.fonts[weight]
	if not f then
		f = Render.LoadFont("Inter", Enum.FontCreate.FONTFLAG_ANTIALIAS, weight)
		asset.fonts[weight] = f
	end
	return f
end

function asset.icons()
	local f = asset.fonts.icon
	if not f then
		f = Render.LoadFont("FontAwesomeEx", Enum.FontCreate.FONTFLAG_ANTIALIAS, 400)
		asset.fonts.icon = f
	end
	return f
end

function asset.hero(id)
	local img = S.images[id]
	if img == nil then
		img = Render.LoadImage("panorama/images/heroes/icons/npc_dota_hero_" .. id .. "_png.vtex_c")
		if type(img) ~= "number" or img == 0 then img = false end
		S.images[id] = img
	end
	return img
end

function asset.size(font, px, str)
	local key = font .. ":" .. px .. ":" .. str
	local v = asset.sizes[key]
	if not v then
		v = Render.TextSize(font, px, str)
		asset.sizes[key] = v
	end
	return v
end

local g = { x = 0, y = 0, s = 1, a = 1, depth = 0, cache_s = 0, fits = {}, wraps = {}, clips = {} }

function g.reset()
	for _ = 1, g.depth do Render.PopClip() end
	g.depth, g.clips, g.a = 0, {}, 1
end

function g.rescale(s)
	if g.cache_s == s then return end
	g.cache_s, g.fits, g.wraps = s, {}, {}
end

function g.px(x) return math.floor(g.x + x * g.s + 0.5) end
function g.py(y) return math.floor(g.y + y * g.s + 0.5) end
function g.v(x, y) return Vec2(g.px(x), g.py(y)) end
function g.fs(size) return math.max(1, math.floor(size * g.s + 0.5)) end
function g.hair() return math.max(1, math.floor(g.s)) end

function g.col(c, a)
	return Color(math.floor(c[1] + 0.5), math.floor(c[2] + 0.5), math.floor(c[3] + 0.5), math.floor(clamp((c[4] or 255) * (a or 1) * g.a, 0, 255) + 0.5))
end

function g.white(a) return g.col(T.white, a) end

function g.rect(x, y, w, h, c, r, a, flags)
	Render.FilledRect(g.v(x, y), g.v(x + w, y + h), g.col(c, a), (r or 0) * g.s, flags or ROUND)
end

function g.frame(x, y, w, h, c, r, a, t)
	Render.Rect(g.v(x, y), g.v(x + w, y + h), g.col(c, a), (r or 0) * g.s, ROUND, (t or 1) * g.s)
end

function g.hl(x, y, w, c, a)
	local y0 = g.py(y)
	Render.FilledRect(Vec2(g.px(x), y0), Vec2(g.px(x + w), y0 + g.hair()), g.col(c, a))
end

function g.vl(x, y, h, c, a)
	local x0 = g.px(x)
	Render.FilledRect(Vec2(x0, g.py(y)), Vec2(x0 + g.hair(), g.py(y + h)), g.col(c, a))
end

function g.line(x1, y1, x2, y2, c, a, t)
	Render.Line(Vec2(g.x + x1 * g.s, g.y + y1 * g.s), Vec2(g.x + x2 * g.s, g.y + y2 * g.s), g.col(c, a), (t or 1) * g.s)
end

function g.width(weight, size, str)
	return asset.size(asset.font(weight), g.fs(size), str).x / g.s
end

function g.text(weight, size, str, x, cy, c, a, align)
	local font, px = asset.font(weight), g.fs(size)
	local ts = asset.size(font, px, str)
	local tx = g.x + x * g.s
	if align == "r" then tx = tx - ts.x elseif align == "c" then tx = tx - ts.x / 2 end
	Render.Text(font, px, str, Vec2(math.floor(tx + 0.5), math.floor(g.y + cy * g.s - ts.y / 2 + 0.5)), g.col(c, a))
	return ts.x / g.s
end

function g.glyph(glyph, size, x, cy, c, a, align)
	local font, px = asset.icons(), g.fs(size)
	local ts = asset.size(font, px, glyph)
	local tx = g.x + x * g.s
	if align == "r" then tx = tx - ts.x elseif align ~= "l" then tx = tx - ts.x / 2 end
	Render.Text(font, px, glyph, Vec2(math.floor(tx + 0.5), math.floor(g.y + cy * g.s - ts.y / 2 + 0.5)), g.col(c, a))
end

function g.hero(id, x, y, size, a, r)
	local img = asset.hero(id)
	if img then
		local dim = Render.ImageSize(img)
		local u0, v0, u1, v1 = 0, 0, 1, 1
		if dim.x > dim.y and dim.y > 0 then
			local d = (1 - dim.y / dim.x) / 2
			u0, u1 = d, 1 - d
		elseif dim.y > dim.x and dim.x > 0 then
			local d = (1 - dim.x / dim.y) / 2
			v0, v1 = d, 1 - d
		end
		Render.Image(img, g.v(x, y), Vec2(size * g.s, size * g.s), g.col(T.white, a), r * g.s, ROUND, Vec2(u0, v0), Vec2(u1, v1))
	else
		g.rect(x, y, size, size, T.white, r, 0.08 * (a or 1))
	end
end

function g.chars(str)
	local out = {}
	for _, c in utf8.codes(str) do out[#out + 1] = utf8.char(c) end
	return out
end

function g.fit(weight, size, str, max_w)
	local key = weight .. ":" .. size .. ":" .. math.floor(max_w) .. ":" .. g.s .. ":" .. str
	local out = g.fits[key]
	if out then return out end
	out = str
	if g.width(weight, size, str) > max_w then
		local chars = g.chars(str)
		out = "…"
		for n = #chars - 1, 1, -1 do
			local s = table.concat(chars, "", 1, n):gsub("%s+$", "") .. "…"
			if g.width(weight, size, s) <= max_w then
				out = s
				break
			end
		end
	end
	g.fits[key] = out
	return out
end

function g.wrap(weight, size, str, max_w)
	local key = weight .. ":" .. size .. ":" .. math.floor(max_w) .. ":" .. g.s .. ":" .. str
	local out = g.wraps[key]
	if out then return out end
	out = {}
	local line = ""
	for word in str:gmatch("%S+") do
		local next_line = line == "" and word or line .. " " .. word
		if line ~= "" and g.width(weight, size, next_line) > max_w then
			out[#out + 1] = line
			line = word
		else
			line = next_line
		end
	end
	if line ~= "" then out[#out + 1] = line end
	g.wraps[key] = out
	return out
end

function g.ring(cx, cy, r, c, a, t, start, pct)
	local full = (pct or 1) >= 1
	Render.Circle(Vec2(g.x + cx * g.s, g.y + cy * g.s), r * g.s, g.col(c, a), t * g.s, start or 270, pct or 1, not full, 64)
end

function g.dot(cx, cy, r, c, a)
	Render.FilledCircle(Vec2(g.x + cx * g.s, g.y + cy * g.s), r * g.s, g.col(c, a), 0, 1, 24)
end

local hit = { list = {}, prev = {}, hover = nil, clip = nil }

function g.clip(x, y, w, h)
	Render.PushClip(g.v(x, y), g.v(x + w, y + h), true)
	g.depth = g.depth + 1
	g.clips[#g.clips + 1] = hit.clip
	hit.clip = { g.x + x * g.s, g.y + y * g.s, g.x + (x + w) * g.s, g.y + (y + h) * g.s }
end

function g.unclip()
	Render.PopClip()
	g.depth = g.depth - 1
	hit.clip = g.clips[#g.clips]
	g.clips[#g.clips] = nil
end

function hit.begin()
	hit.prev, hit.list, hit.clip = hit.list, {}, nil
	local mx, my = Input.GetCursorPos()
	hit.hover = nil
	for i = #hit.prev, 1, -1 do
		local h = hit.prev[i]
		if mx >= h[1] and mx < h[3] and my >= h[2] and my < h[4] then
			hit.hover = h[5]
			break
		end
	end
	if S.press and S.press.id and hit.hover ~= S.press.id then hit.hover = nil end
	if S.drag or S.resize then hit.hover = nil end
end

function hit.add(x, y, w, h, id, on)
	local x1, y1, x2, y2 = g.x + x * g.s, g.y + y * g.s, g.x + (x + w) * g.s, g.y + (y + h) * g.s
	if hit.clip then
		x1, y1 = math.max(x1, hit.clip[1]), math.max(y1, hit.clip[2])
		x2, y2 = math.min(x2, hit.clip[3]), math.min(y2, hit.clip[4])
		if x2 <= x1 or y2 <= y1 then return end
	end
	hit.list[#hit.list + 1] = { x1, y1, x2, y2, id, on or {} }
end

function hit.is(id) return hit.hover == id end

function hit.at(mx, my)
	for i = #hit.list, 1, -1 do
		local h = hit.list[i]
		if mx >= h[1] and mx < h[3] and my >= h[2] and my < h[4] then return h end
	end
	return nil
end

local anim = {}

function anim.tween(key, target, time, curve)
	local t = S.tweens[key]
	if not t or (t.seen and S.now - t.seen > 0.1) then
		t = { from = target, to = target, v = target, k = 1 }
		S.tweens[key] = t
	end
	t.seen = S.now
	if t.to ~= target then t.from, t.to, t.k = t.v, target, 0 end
	if t.k < 1 then
		t.k = math.min(1, t.k + S.dt / time)
		t.v = t.from + (t.to - t.from) * (curve or ease_out)(t.k)
	else
		t.v = t.to
	end
	return t.v
end

function anim.snap(key, value)
	S.tweens[key] = { from = value, to = value, v = value, k = 1 }
end

function anim.hover(id)
	return anim.tween("hv:" .. id, hit.hover == id and 1 or 0, 0.12)
end

function anim.swap(key, state, time)
	local w = S.swaps[key]
	if not w or S.now - w.t > 0.1 then
		w = { cur = state, k = 1 }
		S.swaps[key] = w
	end
	w.t = S.now
	if w.cur ~= state then w.prev, w.cur, w.k = w.cur, state, 0 end
	if w.k < 1 then w.k = math.min(1, w.k + S.dt / (time or 0.2)) end
	if w.k >= 1 then w.prev = nil end
	return w.cur, w.prev, ease_out(w.k)
end

function anim.cross(key, state, draw, time)
	local cur, prev, k = anim.swap(key, state, time)
	local base = g.a
	if prev ~= nil then
		g.a = base * (1 - k)
		draw(prev, false, 1 - k)
	end
	g.a = base * (prev ~= nil and k or 1)
	draw(cur, true, prev ~= nil and k or 1)
	g.a = base
end

function anim.mix(a, b, k)
	return { a[1] + (b[1] - a[1]) * k, a[2] + (b[2] - a[2]) * k, a[3] + (b[3] - a[3]) * k }
end

function anim.menu(key, open)
	return anim.tween("mn:" .. key, open and 1 or 0, open and 0.16 or 0.12, ease_out)
end

function anim.menu_begin(x, y, w, h, k)
	local a = g.a
	g.a = a * k
	local dy = -6 * (1 - k)
	g.clip(x - 2, y + dy - 2, w + 4, (h + 4) * (0.35 + 0.65 * k))
	return a, y + dy
end

function anim.menu_end(a)
	g.unclip()
	g.a = a
end

local fs = {}

function fs.dir()
	if S.dir then return S.dir end
	local base = Engine.GetCheatDirectory()
	if type(base) ~= "string" or base == "" then return nil end
	if not base:match("[\\/]$") then base = base .. "\\" end
	S.dir = base .. "scripts\\"
	return S.dir
end

function fs.read(path)
	local file = io.open(path, "rb")
	if not file then return nil end
	local text = file:read("a")
	file:close()
	return text
end

function fs.write(path, text)
	local file = io.open(path, "wb")
	if not file then return false end
	local ok = file:write(text)
	local closed = file:close()
	return ok ~= nil and closed ~= nil
end

function fs.ensure_dir(path)
	if type(path) ~= "string" or type(os.execute) ~= "function"
		or path:find('[%%!%^&|<>"]') or path:find("[%z\r\n]") then
		return false
	end
	local command = 'if not exist "' .. path .. '\\." mkdir "' .. path .. '" >nul 2>nul'
	local called, result, reason, code = pcall(os.execute, command)
	return called and (result == true or result == 0 or (reason == "exit" and code == 0))
end

function fs.save(path, text)
	local old = fs.read(path)
	local backup = path .. ".script-manager.bak"
	if old and not fs.read(backup) and not fs.write(backup, old) then return false end
	local temp = path .. ".script-manager.tmp"
	if not fs.write(temp, text) then return false end
	if old then os.remove(path) end
	if os.rename(temp, path) then return true end
	os.remove(temp)
	if old then fs.write(path, old) end
	return false
end

function fs.save_package(dir, files)
	local previous = {}
	local needs_lib = false
	for _, file in ipairs(files) do
		if type(file) ~= "table" or type(file.path) ~= "string" or type(file.body) ~= "string" then
			return false, "sm_e_valid"
		end
		if file.path:match("^lib/[%w_%-]+%.lua$") then
			needs_lib = true
		elseif file.path ~= file.name or type(file.name) ~= "string"
			or not file.name:match("^[%w%._%- ]+%.lua$") then
			return false, "sm_e_valid"
		end
	end
	if needs_lib and not fs.ensure_dir(dir .. "lib") then return false, "sm_e_folder" end
	for _, file in ipairs(files) do
		previous[file.path] = fs.read(dir .. file.path:gsub("/", "\\"))
	end

	local saved = {}
	for _, file in ipairs(files) do
		local path = dir .. file.path:gsub("/", "\\")
		if not fs.save(path, file.body) then
			for i = #saved, 1, -1 do
				local saved_file = saved[i]
				local saved_path = dir .. saved_file.path:gsub("/", "\\")
				if previous[saved_file.path] then
					fs.write(saved_path, previous[saved_file.path])
				else
					os.remove(saved_path)
				end
			end
			return false, "sm_e_write"
		end
		saved[#saved + 1] = file
	end
	return true
end

local web = {}

function web.trusted(url)
	if type(url) ~= "string" then return false end
	for _, pattern in ipairs(K.TRUST) do
		if url:match(pattern) then return true end
	end
	return false
end

function web.get(url, done)
	local sent = HTTP.Request("GET", url, { timeout = 20 }, function(response)
		local code = tonumber(response.code) or 0
		if code == 200 and type(response.response) == "string" and #response.response > 0 then
			done(response.response)
			return
		end
		local msg = response.error_message
		done(nil, "sm_e_net", code ~= 0 and ("HTTP " .. code) or (type(msg) == "string" and msg ~= "" and msg or nil))
	end, "script_manager")
	if not sent then done(nil, "sm_e_net") end
end

local ver = {}

function ver.valid(v)
	return type(v) == "string" and v:match("^%d+%.%d+%.%d+[%w%._%-]*$") ~= nil
end

function ver.pre(v)
	return v:match("^%d+%.%d+%.%d+%-") ~= nil
end

function ver.cmp(a, b)
	local a1, a2, a3, as = a:match("^(%d+)%.(%d+)%.(%d+)(.*)$")
	local b1, b2, b3, bs = b:match("^(%d+)%.(%d+)%.(%d+)(.*)$")
	if not a1 or not b1 then return a == b and 0 or -1 end
	local x = { tonumber(a1), tonumber(a2), tonumber(a3) }
	local y = { tonumber(b1), tonumber(b2), tonumber(b3) }
	for i = 1, 3 do
		if x[i] ~= y[i] then return x[i] < y[i] and -1 or 1 end
	end
	if as == bs then return 0 end
	if as == "" then return 1 end
	if bs == "" then return -1 end
	local an, bn = tonumber(as:match("(%d+)$")), tonumber(bs:match("(%d+)$"))
	if an and bn and as:gsub("%d+$", "") == bs:gsub("%d+$", "") then return an < bn and -1 or (an > bn and 1 or 0) end
	return as < bs and -1 or 1
end

local text = {}

function text.clean(str)
	if type(str) ~= "string" then return "" end
	str = str:gsub("<[^>]*>", ""):gsub("&amp;", "&"):gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&quot;", '"'):gsub("`", "")
	return (str:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", ""))
end

function text.cap(str)
	if str == "" then return str end
	local cp = utf8.codepoint(str, 1)
	local len = #utf8.char(cp)
	if cp >= 0x61 and cp <= 0x7A then cp = cp - 32
	elseif cp >= 0x430 and cp <= 0x44F then cp = cp - 32
	elseif cp >= 0x450 and cp <= 0x45F then cp = cp - 80
	else return str end
	return utf8.char(cp) .. str:sub(len + 1)
end

function text.list(items)
	local out = {}
	if type(items) ~= "table" then return out end
	for _, item in ipairs(items) do
		local str = text.clean(item)
		if str ~= "" then out[#out + 1] = str end
	end
	return out
end

function text.humanize(id)
	return (id:gsub("_", " "):gsub("(%a)([%w]*)", function(a, b) return a:upper() .. b end))
end

local market = {}

function market.status(s)
	if S.busy[s.id] then return "busy" end
	if s.manual then return "manual" end
	local v = S.inst[s.id]
	if not v then return "none" end
	return ver.cmp(v, s.latest) < 0 and "update" or "current"
end

function market.updates()
	local out = {}
	for _, s in ipairs(SCRIPTS) do
		if market.status(s) == "update" then out[#out + 1] = s end
	end
	return out
end

function market.installed_count()
	local n = 0
	for _, s in ipairs(SCRIPTS) do
		if S.inst[s.id] then n = n + 1 end
	end
	return n
end

function market.scan()
	local dir = fs.dir()
	S.inst = {}
	if not dir then return end
	for _, s in ipairs(SCRIPTS) do
		if not s.manual then
			local body = fs.read(dir .. s.file)
			if body then
				local version
				if s.version_marker == "NONE" then
					version = Config.ReadString(K.CFG, "installed_" .. s.id, "0.0.0")
				else
					version = body:match(s.version_marker .. '%s*=%s*"([^"]+)"')
				end
				S.inst[s.id] = ver.valid(version) and version or "0.0.0"
			end
		end
	end
end

function market.parse_heroes(value)
	local names = type(value) == "string" and { value } or value
	if type(names) ~= "table" then return nil end
	local out = {}
	for _, name in ipairs(names) do
		if type(name) == "string" then
			local key = name:lower():gsub("^npc_dota_hero_", ""):gsub("[^%a%d]", "")
			local id = HERO_KEY[key]
			if id then out[#out + 1] = id end
		end
	end
	return out
end

function market.hero_name(id)
	local name = S.hero_names[id]
	if name then return name end
	local _, loc = pcall(GameLocalizer.FindNPC, "npc_dota_hero_" .. id)
	name = type(loc) == "string" and loc ~= "" and loc or HERO_BY_ID[id].name
	S.hero_names[id] = name
	return name
end

function market.package_path(path)
	return type(path) == "string" and path:match("^lib/[%w_%-]+%.lua$") ~= nil
end

function market.build(catalog, meta)
	local described = {}
	if meta and type(meta.scripts) == "table" then
		for _, m in ipairs(meta.scripts) do
			if type(m) == "table" and type(m.id) == "string" then described[m.id] = m end
		end
	end

	local cat_set = {}
	for _, c in ipairs(CAT_ORDER) do cat_set[c] = true end

	for i = #SCRIPTS, 1, -1 do SCRIPTS[i] = nil end
	for id in pairs(BY_ID) do BY_ID[id] = nil end

	for i, e in ipairs(catalog.scripts) do
		local package_files, package_valid = {}, true
		local package_seen = {}
		if type(e) == "table" and e.files ~= nil then
			if type(e.files) ~= "table" or #e.files == 0 or #e.files > 64 then
				package_valid = false
			else
				for _, entry in ipairs(e.files) do
					if type(entry) ~= "table" or not market.package_path(entry.path)
						or not web.trusted(entry.url) or package_seen[entry.path] then
						package_valid = false
						break
					end
					package_seen[entry.path] = true
					package_files[#package_files + 1] = { path = entry.path, url = entry.url }
				end
			end
		end
		local package_file = type(e) == "table" and type(e.install_url) == "string"
			and e.install_url:match("([^/?]+)$") or ""
		local package_install = type(e) == "table" and package_valid and #package_files > 0
			and package_file:match("%.lua$") ~= nil and web.trusted(e.install_url)
		if not package_install then package_files = {} end
		local install_url = package_install and e.install_url or type(e) == "table" and e.url or nil
		local file = type(install_url) == "string" and install_url:match("([^/?]+)$") or ""
		local ext = file:match("^[%w%._%- ]+%.(%a+)$")
		ext = type(ext) == "string" and ext:lower() or ""
		if type(e) == "table" and type(e.id) == "string" and ver.valid(e.version) and web.trusted(install_url)
			and (ext == "lua" or ext == "zip" or ext == "rar") then
			local m = described[e.id] or {}
			local ru, en = m.ru or {}, m.en or {}
			local style = STYLE[e.id] or { "\u{f1c9}", PAL[PAL_ORDER[(i - 1) % #PAL_ORDER + 1]] }
			local item = {
				id = e.id, order = i, latest = e.version, url = install_url,
				release = web.trusted(e.release) and e.release or nil,
				manual = e.manual == true and #package_files == 0, files = package_files,
				nlz = e.needs_q_localizer == true,
				version_marker = e.version_marker == "SCRIPT_VERSION" and "SCRIPT_VERSION"
					or e.version_marker == "NONE" and "NONE" or "VERSION",
				title = type(m.title) == "string" and m.title or text.humanize(e.id),
				file = file,
				source = e.url:match("githubusercontent%.com/([^/]+/[^/]+)/") or e.url:match("github%.com/([^/]+/[^/]+)/"),
				author = text.clean(e.author) ~= "" and text.clean(e.author) or (type(m.author) == "string" and text.clean(m.author) ~= "" and text.clean(m.author) or nil),
				cat = cat_set[m.category] and m.category or "auxiliary",
				glyph = style[1], color = style[2],
				tag = { ru = text.cap(text.clean(ru.tagline)), en = text.cap(text.clean(en.tagline)) },
				about = { ru = text.clean(ru.about), en = text.clean(en.about) },
				features = { ru = text.list(ru.features), en = text.list(en.features) },
			}
			item.heroes = market.parse_heroes(e.heroes or e.hero) or {}
			SCRIPTS[#SCRIPTS + 1] = item
			BY_ID[item.id] = item
		end
	end

	S.hero_n, S.hero_total = {}, 0
	for _, s in ipairs(SCRIPTS) do
		for _, hid in ipairs(s.heroes) do
			if not S.hero_n[hid] then S.hero_total = S.hero_total + 1 end
			S.hero_n[hid] = (S.hero_n[hid] or 0) + 1
		end
	end

	local present = {}
	for _, s in ipairs(SCRIPTS) do present[s.cat] = true end
	for i = #CATS, 1, -1 do CATS[i] = nil end
	for _, c in ipairs(CAT_ORDER) do
		if present[c] then CATS[#CATS + 1] = c end
	end

	local lib = catalog.q_localizer
	S.nlz_src = type(lib) == "table" and ver.valid(lib.version) and web.trusted(lib.url) and lib or nil

	local nav_ok = S.nav == "all" or S.nav == "installed" or S.nav == "updates" or S.nav == "heroes" or present[S.nav]
	if not nav_ok then S.nav = "all" end
	if S.view == "detail" and not BY_ID[S.sel] then S.view = "list" end
	market.scan()
end

function market.finish(ok, err)
	local st = S.net
	st.state, st.err, st.at = ok and "ok" or "error", err, os.time()
	st.next = S.now + (ok and K.RECHECK or 60)
	st.loaded = st.loaded or ok
end

function market.load()
	local st = S.net
	if st.state == "loading" then return end
	st.state, st.err, st.stamp = "loading", nil, st.stamp + 1
	local stamp = os.time() .. "-" .. st.stamp

	web.get(K.CATALOG .. "?_=" .. stamp, function(body, key, detail)
		if not body then return market.finish(false, L(key) .. (detail and (": " .. detail) or "")) end
		local ok, catalog = pcall(function() return JSON:decode(body) end)
		if not ok or type(catalog) ~= "table" or catalog.schema ~= 1 or type(catalog.scripts) ~= "table" then
			return market.finish(false, L("sm_e_parse"))
		end
		web.get(K.META .. "?_=" .. stamp, function(meta_body)
			local meta
			if meta_body then
				local meta_ok, parsed = pcall(function() return JSON:decode(meta_body) end)
				if meta_ok and type(parsed) == "table" then meta = parsed end
			end
			local built, err = pcall(market.build, catalog, meta)
			market.finish(built, not built and tostring(err) or nil)
		end)
	end)
end

function market.note(title, body)
	S.note = { title = title, text = body }
	S.foot = "note"
end

function market.fail(s, key, detail)
	S.busy[s.id] = nil
	market.note("sm_err_t", s.title .. ". " .. L(key) .. (detail and (": " .. detail) or ""))
end

function market.dismiss()
	S.foot = #S.changed > 0 and "pending" or "idle"
end

function market.applied(title)
	if S.set.restart == "now" then
		market.restart()
		return
	end
	S.foot = "pending"
	for _, t in ipairs(S.changed) do
		if t == title then return end
	end
	S.changed[#S.changed + 1] = title
end

function market.restart()
	S.foot, S.foot_until, S.changed = "done", S.now + 2.2, {}
	S.reload_at = S.now + K.RELOAD_DELAY
end

function market.ensure_nlz(done)
	local dir = fs.dir()
	if not dir then return done(false, "sm_e_dir") end
	if fs.read(dir .. K.NLZ_FILE) then return done(true) end
	if S.nlz_wait then
		S.nlz_wait[#S.nlz_wait + 1] = done
		return
	end
	if not S.nlz_src then return done(false, "sm_e_nlz") end
	S.nlz_wait = { done }
	web.get(S.nlz_src.url, function(body, key, detail)
		local ok = false
		if body then
			if #body < 1000 or not body:find("qLocalization", 1, true) then
				key = "sm_e_valid"
			elseif fs.save(dir .. K.NLZ_FILE, body) then
				ok, key = true, nil
			else
				key = "sm_e_write"
			end
		end
		local waiting = S.nlz_wait
		S.nlz_wait = nil
		for _, cb in ipairs(waiting) do cb(ok, key, detail) end
	end)
end

function market.download(s, done)
	local urls = { s.url }
	if #s.files == 0 and s.release and s.release ~= s.url then urls[2] = s.release end

	local function try(i, prev_key, prev_detail)
		if not urls[i] then return done(nil, prev_key or "sm_e_net", prev_detail) end
		web.get(urls[i], function(body, key, detail)
			local valid = false
			if body then
				if s.manual then
					valid = body:sub(1, 2) == "PK"
						or body:sub(1, 7) == "Rar!\26\7\0"
						or body:sub(1, 8) == "Rar!\26\7\1\0"
				else
					valid = #body > 100 and body:sub(1, 1) ~= "<"
					if valid and s.version_marker ~= "NONE" then
						valid = body:match(s.version_marker .. '%s*=%s*"([^"]+)"') == s.latest
					end
				end
				if valid then return done(body) end
				key, detail = "sm_e_valid", nil
			end
			try(i + 1, key, detail)
		end)
	end

	try(1)
end

function market.download_files(s, done)
	local downloaded = {}
	local function next_file(index)
		if index > #s.files then return done(downloaded) end
		local file = s.files[index]
		if not web.trusted(file.url) or not market.package_path(file.path) then
			return done(nil, "sm_e_valid")
		end
		web.get(file.url, function(body, key, detail)
			if not body then return done(nil, key, detail) end
			if #body < 100 or body:sub(1, 1) == "<" then return done(nil, "sm_e_valid") end
			downloaded[#downloaded + 1] = { path = file.path, body = body }
			next_file(index + 1)
		end)
	end
	next_file(1)
end

function market.run(id)
	local s = BY_ID[id]
	if not s or S.busy[id] then return end
	S.busy[id], S.confirm = 0, nil

	local dir = fs.dir()
	if not dir then return market.fail(s, "sm_e_dir") end

	local function fetch()
		market.download(s, function(body, key, detail)
			if not body then return market.fail(s, key, detail) end
			local function finish(files, file_key, file_detail)
				if not files then return market.fail(s, file_key or "sm_e_net", file_detail) end
				local function complete()
					if not s.manual and s.version_marker == "NONE" then
						Config.WriteString(K.CFG, "installed_" .. s.id, s.latest)
					end
					S.busy[id] = nil
					market.scan()
					if s.manual then
						market.note("sm_manual_t", string.format(L("sm_manual_msg"), s.file))
					else
						market.applied(s.title)
					end
				end
				if #s.files == 0 then
					if not fs.save(dir .. s.file, body) then return market.fail(s, "sm_e_write") end
					return complete()
				end
				local package = { { path = s.file, name = s.file, body = body } }
				for _, file in ipairs(files) do package[#package + 1] = file end
				local saved, err = fs.save_package(dir, package)
				if not saved then return market.fail(s, err or "sm_e_write") end
				return complete()
			end
			if #s.files == 0 then return finish({}) end
			market.download_files(s, finish)
		end)
	end

	if not s.nlz then return fetch() end
	market.ensure_nlz(function(ok, key, detail)
		if not ok then return market.fail(s, key, detail) end
		fetch()
	end)
end

function market.remove(id)
	if S.confirm ~= id then
		S.confirm = id
		return
	end
	S.confirm = nil
	local s, dir = BY_ID[id], fs.dir()
	if not s or not dir or not os.remove(dir .. s.file) then
		if s then market.fail(s, "sm_e_remove") end
		return
	end
	market.scan()
	market.applied(s.title)
end

function market.tick()
	local st = S.net
	if st.state == "idle" then
		market.load()
	elseif st.state ~= "loading" and S.set.check == "hour" and S.now >= st.next then
		market.load()
	end
	if S.foot == "done" and S.now > S.foot_until then S.foot = "idle" end
	if S.reload_at and S.now >= S.reload_at then
		S.reload_at = nil
		Engine.ReloadScriptSystem()
	end
end

function market.has_hero(s, id)
	for _, hid in ipairs(s.heroes) do
		if hid == id then return true end
	end
	return false
end

function market.hidden(s)
	return not S.set.beta and ver.pre(s.latest) and not S.inst[s.id]
end

function market.list()
	local q = S.query:lower()
	local in_cat = S.nav ~= "all" and S.nav ~= "installed" and S.nav ~= "updates" and S.nav ~= "heroes"
	local out = {}
	for _, s in ipairs(SCRIPTS) do
		local k = market.status(s)
		local ok = not market.hidden(s)
		if S.nav == "heroes" and S.hero then
			ok = ok and market.has_hero(s, S.hero)
		end
		if S.nav == "installed" and not S.inst[s.id] then ok = false end
		if S.nav == "updates" and k ~= "update" and not (k == "busy" and S.inst[s.id]) then ok = false end
		if in_cat and s.cat ~= S.nav then ok = false end
		if ok and q ~= "" then
			ok = s.title:lower():find(q, 1, true) ~= nil or tr(s.tag):lower():find(q, 1, true) ~= nil
		end
		if ok then out[#out + 1] = s end
	end
	local cmp = SORTS[1].cmp
	for _, o in ipairs(SORTS) do
		if o.id == S.sort then cmp = o.cmp end
	end
	table.sort(out, function(a, b)
		if S.inst_first then
			local ia, ib = S.inst[a.id] ~= nil, S.inst[b.id] ~= nil
			if ia ~= ib then return ia end
		end
		return cmp(a, b)
	end)
	return out
end

function market.set_theme(id)
	S.set.theme = id
	C = THEMES[id]
	save("theme", id)
end

function market.set_accent(id)
	S.set.accent = id
	apply_accent(id)
	save("accent", id)
end

local CHARS = {}
for i = 0, 25 do
	local letter = string.char(65 + i)
	CHARS[KEY["KEY_" .. letter]] = letter:lower()
end
for i = 0, 9 do CHARS[KEY["KEY_" .. i]] = tostring(i) end
CHARS[KEY.KEY_SPACE] = " "
CHARS[KEY.KEY_MINUS] = "-"

local edit = { box = nil }

function edit.chars() return g.chars(S.query) end

function edit.range()
	if S.qa and S.qa ~= S.qc then return math.min(S.qa, S.qc), math.max(S.qa, S.qc) end
	return nil
end

function edit.put(chars, caret)
	S.query = table.concat(chars)
	S.qc, S.qa = caret, nil
end

function edit.cut(chars)
	local lo, hi = edit.range()
	if not lo then return chars, S.qc end
	local out = {}
	for i = 1, lo do out[#out + 1] = chars[i] end
	for i = hi + 1, #chars do out[#out + 1] = chars[i] end
	return out, lo
end

function edit.insert(str)
	local chars, caret = edit.cut(edit.chars())
	if #chars >= K.QUERY_MAX then return end
	table.insert(chars, caret + 1, str)
	edit.put(chars, caret + 1)
end

function edit.word_left(chars, i)
	while i > 0 and chars[i] == " " do i = i - 1 end
	while i > 0 and chars[i] ~= " " do i = i - 1 end
	return i
end

function edit.word_right(chars, i)
	local n = #chars
	while i < n and chars[i + 1] == " " do i = i + 1 end
	while i < n and chars[i + 1] ~= " " do i = i + 1 end
	return i
end

function edit.erase(forward, word)
	local chars = edit.chars()
	if not edit.range() then
		local a, b = S.qc, S.qc
		if forward then
			b = word and edit.word_right(chars, S.qc) or math.min(#chars, S.qc + 1)
		else
			a = word and edit.word_left(chars, S.qc) or math.max(0, S.qc - 1)
		end
		if a == b then return end
		S.qa, S.qc = a, b
	end
	edit.put(edit.cut(chars))
end

function edit.move(to, shift)
	if shift then
		S.qa = S.qa or S.qc
	else
		S.qa = nil
	end
	S.qc = to
end

function edit.key(key, ctrl, shift)
	local chars = edit.chars()
	local n = #chars
	local lo, hi = edit.range()
	if ctrl and key == KEY.KEY_A then
		S.qa, S.qc = 0, n
	elseif key == KEY.KEY_LEFT then
		if lo and not shift then
			edit.move(lo, false)
		else
			edit.move(ctrl and edit.word_left(chars, S.qc) or math.max(0, S.qc - 1), shift)
		end
	elseif key == KEY.KEY_RIGHT then
		if hi and not shift then
			edit.move(hi, false)
		else
			edit.move(ctrl and edit.word_right(chars, S.qc) or math.min(n, S.qc + 1), shift)
		end
	elseif key == KEY.KEY_HOME or key == KEY.KEY_UP then
		edit.move(0, shift)
	elseif key == KEY.KEY_END or key == KEY.KEY_DOWN then
		edit.move(n, shift)
	elseif key == KEY.KEY_BACKSPACE then
		edit.erase(false, ctrl)
	elseif key == KEY.KEY_DELETE then
		edit.erase(true, ctrl)
	elseif key == KEY.KEY_ESCAPE then
		if lo then S.qa = nil else S.focus = false end
	elseif key == KEY.KEY_ENTER or key == KEY.KEY_PAD_ENTER then
		S.focus = false
	elseif not ctrl and CHARS[key] then
		edit.insert(shift and CHARS[key]:upper() or CHARS[key])
	end
	S.q_blink = S.now
end

function edit.index_at(mx)
	local box = edit.box
	if not box then return S.qc end
	local lx = (mx - g.x) / g.s - box.tx + S.q_off
	local chars = edit.chars()
	local prev = 0
	for i = 1, #chars do
		local w = g.width(400, 14, table.concat(chars, "", 1, i))
		if lx < (prev + w) / 2 then return i - 1 end
		prev = w
	end
	return #chars
end

function edit.click(mx)
	local i = edit.index_at(mx)
	S.q_blink = S.now
	if S.focus and S.now - S.q_click < 0.35 then
		local chars = edit.chars()
		S.qa, S.qc, S.q_click = edit.word_left(chars, i), edit.word_right(chars, i), 0
		return
	end
	S.q_click = S.now
	local shift = Input.IsKeyDown(KEY.KEY_LSHIFT) or Input.IsKeyDown(KEY.KEY_RSHIFT)
	if shift and S.focus then
		S.qa = S.qa or S.qc
	else
		S.qa = i
	end
	S.qc = i
	S.focus, S.q_drag = true, true
end

local view = {}

function view.go(name, sel)
	S.view, S.sel, S.confirm, S.sort_open, S.menu = name, sel or S.sel, nil, false, nil
	S.rows = {}
	S.scroll, S.scroll_to = 0, 0
	anim.snap("scroll", 0)
end

function view.nav_item(x, y, w, id, label, glyph, count, badge)
	local on = S.nav == id and S.view ~= "settings"
	local hv = anim.hover("nav:" .. id)
	local ok = anim.tween("nav_on:" .. id, on and 1 or 0, 0.16)
	g.rect(x, y, w, 34, T.white, 8, 0.09 * ok + 0.05 * hv * (1 - ok))
	g.glyph(glyph, 13, x + 18, y + 17, anim.mix(T.t3, K.ACCENT_TEXT, ok))
	g.text(500, 13, label, x + 36, y + 17, anim.mix(T.t2, T.t1, ok))
	local bk = anim.tween("badge:" .. id, badge and 1 or 0, 0.2)
	if badge then S.badges[id] = count end
	if bk > 0.01 then
		local str = tostring(S.badges[id] or count)
		local bw = math.max(20, g.width(700, 11, str) + 12)
		local sc = 0.7 + 0.3 * bk
		local bcx = x + w - 10 - bw / 2
		g.rect(bcx - bw * sc / 2, y + 17 - 9 * sc, bw * sc, 18 * sc, T.pill, 9 * sc, bk)
		g.text(700, 11, str, bcx, y + 17, T.dark, bk, "c")
	end
	if bk < 0.99 then
		g.text(400, 12, tostring(count), x + w - 10, y + 17, T.t4, 1 - bk, "r")
	end
	hit.add(x, y, w, 34, "nav:" .. id, { click = function()
		S.nav, S.hero = id, nil
		view.go("list")
	end })
end

function view.icon_button(x, y, size, glyph, gsize, id, active, click)
	local hv = anim.hover(id)
	local ak = anim.tween("ib_on:" .. id, active and 1 or 0, 0.16)
	g.rect(x, y, size, size, T.white, 8, 0.09 * ak + 0.08 * hv * (1 - ak))
	g.glyph(glyph, gsize, x + size / 2, y + size / 2, anim.mix(T.t3, T.t1, ak))
	hit.add(x, y, size, size, id, { click = click })
end

function view.pill(x, y, w, h, label, kind, id, click, size)
	local hv = id and anim.hover(id) or 0
	size = size or 12
	if kind == "white" then
		g.rect(x, y, w, h, T.pill, h / 2, 1 - 0.08 * hv)
		g.text(600, size, label, x + w / 2, y + h / 2, T.dark, 1, "c")
	elseif kind == "soft" then
		g.rect(x, y, w, h, T.white, h / 2, 0.1 + 0.05 * hv)
		g.text(600, size, label, x + w / 2, y + h / 2, T.t1, 1, "c")
	elseif kind == "red" then
		g.rect(x, y, w, h, T.red_bg, h / 2, 1 + 0.3 * hv)
		g.text(600, size, label, x + w / 2, y + h / 2, T.red, 1, "c")
	else
		g.rect(x, y, w, h, T.white, h / 2, 0.08 * hv)
		g.text(500, size, label, x + w / 2, y + h / 2, T.t3, 1, "c")
	end
	if id then hit.add(x, y, w, h, id, { click = click }) end
end

function view.sidebar()
	g.rect(0, 0, K.SIDE, K.H, C.side, 16, 1, Enum.DrawFlags.RoundCornersLeft)
	g.vl(K.SIDE - 1, 0, K.H, T.white, C.line / 255)
	hit.add(0, 0, K.SIDE, K.H, "drag", { down = view.start_drag })

	local updates = #market.updates()
	local y = 18
	view.nav_item(12, y, 196, "all", L("sm_nav_all"), K.G.all, #SCRIPTS)
	y = y + 36
	view.nav_item(12, y, 196, "installed", L("sm_nav_installed"), K.G.installed, market.installed_count())
	y = y + 36
	view.nav_item(12, y, 196, "updates", L("sm_nav_updates"), K.G.updates, updates, updates > 0)
	y = y + 34 + 22
	g.text(600, 12, L("sm_cats"), 22, y + 7, T.t4)
	y = y + 20
	view.nav_item(12, y, 196, "heroes", L("sm_nav_heroes"), K.G.heroes, S.hero_total)
	y = y + 36
	for _, cat in ipairs(CATS) do
		local n = 0
		for _, s in ipairs(SCRIPTS) do
			if s.cat == cat then n = n + 1 end
		end
		view.nav_item(12, y, 196, cat, L("sm_cat_" .. cat), K.G[cat], n)
		y = y + 36
	end

	local by = K.H - 14 - 36
	local in_settings = S.view == "settings"
	view.icon_button(K.SIDE - 12 - 30, by + 3, 30, K.G.sliders, 13, "gear", in_settings, function()
		if in_settings then view.go("list") else view.go("settings") end
	end)
	view.icon_button(K.SIDE - 12 - 62, by + 3, 30, K.G.refresh, 12, "refresh", S.net.state == "loading", market.load)
	anim.cross("chk", S.net.state, function(st, _, a)
		local label = L("sm_unchecked")
		if st == "loading" then
			label = L("sm_checking")
		elseif st == "error" then
			label = L("sm_check_failed")
		elseif st == "ok" then
			label = string.format(L("sm_checked"), os.date("%H:%M", S.net.at))
		end
		g.text(400, 12, g.fit(400, 12, label, K.SIDE - 22 - 80), 22, by + 18 + 4 * (1 - a), T.t4)
	end, 0.18)

	if S.foot == "pending" then
		S.foot_text = #S.changed == 1 and string.format(L("sm_restart_one"), S.changed[1]) or string.format(plural(#S.changed, "sm_restart_n"), #S.changed)
	end
	local function box(title, body, dy, primary, secondary)
		local lines = g.wrap(400, 12, body, 196 - 28)
		local h = 14 + 18 + 4 + #lines * 17 + 10 + (secondary and 58 or 30) + 8
		local cy = by - 8 - h + dy
		g.rect(12, cy, 196, h, T.white, 12, 0.05)
		g.frame(12, cy, 196, h, T.white, 12, C.line / 255)
		g.text(600, 13, title, 26, cy + 14 + 9, T.t1)
		local ty = cy + 14 + 18 + 4
		for i, line in ipairs(lines) do g.text(400, 12, line, 26, ty + (i - 1) * 17 + 8, T.t3) end
		local bty = ty + #lines * 17 + 10
		view.pill(26, bty, 168, 30, primary[1], primary[2], primary[3], primary[4])
		if secondary then view.pill(26, bty + 30, 168, 28, secondary[1], "ghost", secondary[2], secondary[3]) end
	end
	anim.cross("foot", S.foot, function(st, live, a)
		local dy = 8 * (1 - a)
		if st == "pending" then
			box(L("sm_restart_t"), S.foot_text or "", dy,
				{ L("sm_restart_btn"), "white", live and "restart" or nil, market.restart },
				{ L("sm_later"), live and "later" or nil, function() S.foot, S.changed = "idle", {} end })
		elseif st == "note" and S.note then
			box(L(S.note.title), S.note.text, dy, { L("sm_ok"), "soft", live and "note_ok" or nil, market.dismiss })
		elseif st == "done" then
			g.glyph(K.G.check, 11 * (0.6 + 0.4 * a), 29, by - 8 - 18 + dy, T.t2)
			g.text(400, 12, L("sm_restarted"), 42, by - 8 - 18 + dy, T.t2)
		end
	end, 0.22)
end

function view.start_drag(mx, my)
	S.drag = { mx = mx, my = my, wx = S.wx, wy = S.wy }
end

function view.scroll_area(x, y, w, h)
	S.view_h, S.area = h, { x, y, w, h }
	S.scroll = anim.tween("scroll", S.scroll_to, 0.24)
	hit.add(x, y, w, h, "content", { wheel = function(dir)
		S.scroll_to = clamp(S.scroll_to + dir * K.WHEEL, 0, math.max(0, S.content_h - S.view_h))
		S.scroll_t = S.now
	end })
	g.clip(x, y, w, h)
end

function view.end_scroll(content_h)
	g.unclip()
	S.content_h = content_h
	local max_scroll = math.max(0, content_h - S.view_h)
	if S.scroll_to > max_scroll then
		S.scroll_to = max_scroll
		anim.snap("scroll", max_scroll)
	end
	if max_scroll <= 0 then return end

	local ax, ay, aw, ah = S.area[1], S.area[2], S.area[3], S.area[4]
	local track = ah - 36
	local thumb = math.max(32, track * S.view_h / content_h)
	local top = ay + 8 + (track - thumb) * clamp(S.scroll / max_scroll, 0, 1)
	local sa = anim.tween("scrollbar", S.now - S.scroll_t < 0.9 and 1 or 0, 0.2)
	if sa > 0.01 then g.rect(ax + aw - 8, top, 4, thumb, T.white, 2, 0.22 * sa) end
end

function view.search(x, y, w)
	local h = 36
	local has = S.query ~= ""
	local fa = anim.tween("sf_focus", S.focus and 1 or 0, 0.16)
	local pa = anim.tween("sf_hint", has and 0 or 1, 0.14)
	local ca = anim.tween("sf_clear", has and 1 or 0, 0.14)
	hit.add(x, y, w, h, "search", { down = edit.click })
	g.rect(x, y, w, h, T.white, 10, C.field / 255 + 0.03 * fa)
	if fa > 0.01 then g.frame(x, y, w, h, K.ACCENT_TEXT, 10, 0.55 * fa) end
	local gc = { T.t3[1] + (T.t1[1] - T.t3[1]) * fa, T.t3[2] + (T.t1[2] - T.t3[2]) * fa, T.t3[3] + (T.t1[3] - T.t3[3]) * fa }
	g.glyph(K.G.search, 13, x + 19, y + h / 2, gc)
	local tx = x + 36
	local maxw = w - 36 - 34
	edit.box = { tx = tx, maxw = maxw }
	if pa > 0.01 then g.text(400, 14, L("sm_search"), tx, y + h / 2, T.t4, pa) end

	local chars = edit.chars()
	local widths = { [0] = 0 }
	for i = 1, #chars do widths[i] = g.width(400, 14, table.concat(chars, "", 1, i)) end
	local caret_x = widths[S.qc] or widths[#chars]
	if caret_x - S.q_off > maxw then
		S.q_off = caret_x - maxw
	elseif caret_x < S.q_off then
		S.q_off = caret_x
	end
	S.q_off = clamp(S.q_off, 0, math.max(0, widths[#chars] - maxw))
	local off = anim.tween("sf_off", S.q_off, 0.12, ease_in_out)

	g.clip(tx - 2, y, maxw + 4, h)
	local lo, hi = edit.range()
	local sel_on = lo ~= nil and S.focus
	if sel_on then S.sel_box = { widths[lo], widths[hi] - widths[lo] } end
	local sa = anim.tween("sf_sel", sel_on and 1 or 0, 0.12)
	if sa > 0.01 and S.sel_box then
		local sx = anim.tween("sf_sel_x", S.sel_box[1], 0.1, ease_out)
		local sw = anim.tween("sf_sel_w", S.sel_box[2], 0.1, ease_out)
		g.rect(tx + sx - off, y + 9, sw, 18, K.ACCENT, 3, 0.45 * sa)
	elseif sa <= 0.01 then
		S.sel_box = nil
		anim.snap("sf_sel_x", widths[S.qc] or 0)
		anim.snap("sf_sel_w", 0)
	end
	if has then g.text(400, 14, S.query, tx - off, y + h / 2, T.t1) end
	local cx = anim.tween("sf_caret", caret_x, 0.09, ease_out)
	local t = S.now - S.q_blink
	local blink = t < 0.5 and 1 or (math.cos((t - 0.5) * math.pi * 2) + 1) / 2
	local caret_a = fa * blink * (1 - sa)
	if caret_a > 0.01 then g.rect(tx + cx - off, y + 10, 1.5, 16, T.t1, 0, caret_a) end
	g.unclip()

	if ca > 0.01 then
		local base = g.a
		g.a = base * ca
		if has then
			view.icon_button(x + w - 30, y + 6, 24, K.G.clear, 13, "search_clear", false, function()
				S.query, S.qc, S.qa, S.q_off = "", 0, nil, 0
				S.focus, S.q_blink = true, S.now
			end)
		else
			g.glyph(K.G.clear, 13, x + w - 18, y + h / 2, T.t3)
		end
		g.a = base
	end
end

function view.sort_button(right, y)
	local label = nil
	for _, o in ipairs(SORTS) do
		if o.id == S.sort then label = L(o.key) end
	end
	label = label or L(SORTS[1].key)
	local w = anim.tween("sort_w", 12 + 15 + 8 + g.width(500, 13, label) + 12, 0.2, ease_in_out)
	local x = right - w
	local hv = anim.hover("sort")
	local ok = anim.tween("sort_on", S.sort_open and 1 or 0, 0.16)
	local idle = C.field / 255 + 0.04 * hv
	g.rect(x, y, w, 36, T.white, 10, idle + (0.12 - idle) * ok)
	g.glyph(K.G.sort, 13, x + 12 + 7, y + 18, anim.mix(T.t3, T.t1, ok))
	g.clip(x, y, w, 36)
	anim.cross("sort_l", label, function(str)
		g.text(500, 13, str, x + 35, y + 18, T.t5)
	end, 0.18)
	g.unclip()
	hit.add(x, y, w, 36, "sort", { click = function() S.sort_open = not S.sort_open end })
	return x
end

function view.sort_menu(right, y, k, live)
	local w, h = 240, 5 + #SORTS * 32 + 11 + 32 + 5
	local x = right - w
	local add = live and hit.add or function() end
	local a
	a, y = anim.menu_begin(x, y, w, h, k)
	g.rect(x, y, w, h, C.menu, 12)
	g.frame(x, y, w, h, T.white, 12, 0.12)
	add(x, y, w, h, "menu:sort_bg")
	local iy = y + 5
	local function item(id, label, on, click)
		local hv = anim.hover(id)
		g.rect(x + 5, iy, w - 10, 32, T.white, 7, 0.08 * hv)
		if on then g.glyph(K.G.check, 11, x + 5 + 15, iy + 16, T.t1) end
		g.text(400, 13, label, x + 5 + 30, iy + 16, T.t1)
		add(x + 5, iy, w - 10, 32, id, { click = click })
		iy = iy + 32
	end
	for _, o in ipairs(SORTS) do
		item("menu:sort_" .. o.id, L(o.key), S.sort == o.id, function()
			S.sort, S.sort_open = o.id, false
			save("sort", o.id)
		end)
	end
	g.hl(x + 13, iy + 5, w - 26, T.white, 0.1)
	iy = iy + 11
	item("menu:sort_inst", L("sm_sort_inst"), S.inst_first, function()
		S.inst_first, S.sort_open = not S.inst_first, false
		save("inst_first", S.inst_first and 1 or 0)
	end)
	anim.menu_end(a)
end

function view.action(s, right, cy)
	anim.cross("act:" .. s.id, market.status(s), function(k, live, a)
		local id = live and "act:" .. s.id or nil
		if k == "none" or k == "update" or k == "manual" then
			local label = L(k == "none" and "sm_install" or (k == "update" and "sm_update" or "sm_download"))
			local w = g.width(600, 12, label) + 28
			view.pill(right - w, cy - 14, w, 28, label, k == "update" and "white" or "soft", id, function() market.run(s.id) end)
		elseif k == "busy" then
			local cx = right - 14 - 14
			local r = 11 * (0.8 + 0.2 * a)
			g.ring(cx, cy, r, T.white, 0.14, 2.5, 0, 1)
			g.ring(cx, cy, r, T.pill, 1, 2.5, (S.now * 360) % 360, 0.28)
		else
			local tw = g.width(500, 12, L("sm_installed"))
			local dx = 6 * (1 - a)
			g.text(500, 12, L("sm_installed"), right - 2 + dx, cy, T.t4, 1, "r")
			g.glyph(K.G.check, 9, right - 2 - tw - 9 + dx, cy, T.t4)
		end
	end)
end

function view.row(s, rx, y, rw, interactive, sep)
	local id = "row:" .. s.id
	local hv = interactive and anim.hover(id) or 0
	g.rect(rx, y, rw, 72, T.white, 12, 0.04 * hv)
	if interactive then hit.add(rx, y, rw - 136, 72, id, { click = function() view.go("detail", s.id) end }) end
	g.rect(rx + 12, y + 14, 44, 44, s.color, 12, 0.15)
	g.glyph(s.glyph, 18, rx + 34, y + 36, s.color)
	local tx = rx + 70
	local tw = g.text(600, 14, s.title, tx, y + 27, T.t1)
	local st = market.status(s)
	if st == "update" then
		S.vers[s.id] = short_ver(S.inst[s.id]) .. " → " .. short_ver(s.latest)
	elseif st == "none" then
		S.vers[s.id] = nil
	end
	local va = anim.tween("rv:" .. s.id, (st == "update" or st == "busy") and 1 or 0, 0.2)
	if va > 0.01 and S.vers[s.id] then
		g.text(400, 12, S.vers[s.id], tx + tw + 8, y + 28, T.t3, va)
	end
	g.text(400, 13, g.fit(400, 13, tr(s.tag), rw - 70 - 136 - 12), tx, y + 47, T.t3)
	if interactive then view.action(s, rx + rw - 12, y + 36) end
	if sep then g.hl(rx + 70, y + 72, rw - 70 - 12, T.white, C.line / 255) end
end

function view.list()
	local x0, w0 = K.SIDE, K.W - K.SIDE
	hit.add(x0, 0, w0, K.TOP, "drag", { down = view.start_drag })
	local sort_x = view.sort_button(K.W - 24, 16)
	view.search(x0 + 24, 16, sort_x - 10 - (x0 + 24))

	local list = market.list()
	local updates = market.updates()
	view.scroll_area(x0, K.TOP, w0, K.H - K.TOP)
	local y = K.TOP - S.scroll
	local rx, rw = x0 + 12, w0 - 24

	local show_banner = #updates > 0 and (S.nav == "all" or S.nav == "updates") and S.query == ""
	if show_banner then S.banner_n = #updates end
	local ba = anim.tween("banner", show_banner and 1 or 0, show_banner and 0.2 or 0.16)
	if ba > 0.01 then
		local base = g.a
		g.a = base * ba
		local bx, bw = rx + 12, rw - 24
		g.frame(bx, y, bw, 52, T.white, 12, C.line / 255)
		g.text(400, 13, string.format(plural(S.banner_n, "sm_upd"), S.banner_n), bx + 16, y + 26, T.t2)
		local pw = g.width(600, 12, L("sm_update_all")) + 28
		if show_banner then
			view.pill(bx + bw - 10 - pw, y + 11, pw, 30, L("sm_update_all"), "white", "update_all", function()
				for _, u in ipairs(updates) do market.run(u.id) end
			end)
		else
			view.pill(bx + bw - 10 - pw, y + 11, pw, 30, L("sm_update_all"), "white")
		end
		g.a = base
	end

	local head = S.nav == "heroes" and S.hero
	if head then
		local hv = anim.hover("hero_back")
		g.rect(rx, y + 4, rw, 44, T.white, 12, 0.05 * hv)
		g.glyph(K.G.back, 12, rx + 24, y + 26, T.t3)
		g.hero(S.hero, rx + 42, y + 12, 28, 1, 8)
		local name_w = g.text(600, 15, market.hero_name(S.hero), rx + 82, y + 26, T.t1)
		g.text(400, 12, tostring(#list), rx + 82 + name_w + 10, y + 27, T.t4)
		hit.add(rx, y + 4, rw, 44, "hero_back", { click = function()
			S.hero = nil
			view.go("list")
		end })
	end

	local live = {}
	local cursor = (show_banner and 62 or 0) + (head and 52 or 0)
	for _, s in ipairs(list) do
		local r = S.rows[s.id]
		if not r then
			r = {}
			S.rows[s.id] = r
			anim.snap("ry:" .. s.id, cursor)
			anim.snap("ra:" .. s.id, 0)
		end
		r.ty, r.live, r.s = cursor, true, s
		live[s.id] = true
		cursor = cursor + 73
	end
	local base = g.a
	for id, r in pairs(S.rows) do
		if not live[id] then
			r.live = false
			local a = anim.tween("ra:" .. id, 0, 0.16)
			if a <= 0.01 then
				S.rows[id] = nil
			else
				g.a = base * a
				view.row(r.s, rx, y + anim.tween("ry:" .. id, r.ty, 0.26, ease_in_out), rw, false, false)
			end
		end
	end
	for i, s in ipairs(list) do
		local r = S.rows[s.id]
		g.a = base * anim.tween("ra:" .. s.id, 1, 0.2)
		view.row(s, rx, y + anim.tween("ry:" .. s.id, r.ty, 0.26, ease_in_out), rw, true, i < #list)
	end
	g.a = base
	y = y + cursor

	local ea = anim.tween("empty", #list == 0 and 1 or 0, #list == 0 and 0.2 or 0.1)
	if ea > 0.01 then
		local t, d = "sm_empty", "sm_empty_d"
		if #SCRIPTS == 0 and S.net.state == "error" then
			t, d = "sm_err_catalog", "sm_err_catalog_d"
		elseif #SCRIPTS == 0 and S.net.state ~= "ok" then
			t, d = "sm_loading", "sm_loading_d"
		elseif S.query ~= "" then
			t, d = "sm_empty_search", "sm_empty_search_d"
		elseif S.nav == "heroes" and S.hero then
			t, d = "sm_empty_hero", "sm_empty_hero_d"
		elseif S.nav == "updates" then
			t, d = "sm_empty_upd", "sm_empty_upd_d"
		end
		local cx, cy = x0 + w0 / 2, K.TOP + (K.H - K.TOP) / 2 - 20
		g.text(600, 15, L(t), cx, cy, T.t2, ea, "c")
		g.text(400, 13, L(d), cx, cy + 24, T.t4, ea, "c")
	end
	view.end_scroll(y + S.scroll - K.TOP + 16)
end

function view.pick_hero(id)
	S.hero = id
	S.query, S.qc, S.qa, S.q_off, S.focus = "", 0, nil, 0, false
	view.go("list")
end

function view.heroes()
	local x0, w0 = K.SIDE, K.W - K.SIDE
	hit.add(x0, 0, w0, K.TOP, "drag", { down = view.start_drag })
	view.search(x0 + 24, 16, w0 - 48)

	local q = S.query:lower()
	local with, rest = {}, {}
	for _, h in ipairs(HEROES) do
		local found = q == "" or h[2]:lower():find(q, 1, true) ~= nil or market.hero_name(h[1]):lower():find(q, 1, true) ~= nil
		if found then
			local list = (S.hero_n[h[1]] or 0) > 0 and with or rest
			list[#list + 1] = h[1]
		end
	end

	view.scroll_area(x0, K.TOP, w0, K.H - K.TOP)
	local cx, cw = x0 + 24, w0 - 48
	local cols, gap, th = 4, 8, 46
	local tw = (cw - gap * (cols - 1)) / cols
	local y = K.TOP - S.scroll + 4

	local function tile(id, tx, ty)
		if ty + th < K.TOP - 4 or ty > K.H then return end
		local key = "hero:" .. id
		local n = S.hero_n[id] or 0
		g.rect(tx, ty, tw, th, T.white, 10, 0.04 + 0.05 * anim.hover(key))
		g.hero(id, tx + 9, ty + 9, 28, n > 0 and 1 or 0.45, 8)
		local count_w = 0
		if n > 0 then
			local str = tostring(n)
			count_w = math.max(20, g.width(700, 11, str) + 12)
			g.rect(tx + tw - 10 - count_w, ty + th / 2 - 9, count_w, 18, K.ACCENT, 9, 0.28)
			g.text(700, 11, str, tx + tw - 10 - count_w / 2, ty + th / 2, K.ACCENT_TEXT, 1, "c")
		end
		local room = tw - 46 - 10 - (count_w > 0 and count_w + 6 or 0)
		g.text(500, 13, g.fit(500, 13, market.hero_name(id), room), tx + 46, ty + th / 2, n > 0 and T.t1 or T.t3)
		hit.add(tx, ty, tw, th, key, { click = function() view.pick_hero(id) end })
	end

	local function section(title, list)
		if #list == 0 then return end
		g.text(600, 11, string.format("%s (%d)", L(title), #list), cx + 4, y + 7, T.t4)
		y = y + 24
		for i, id in ipairs(list) do
			local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
			tile(id, cx + col * (tw + gap), y + row * (th + gap))
		end
		y = y + math.ceil(#list / cols) * (th + gap) + 14
	end

	section("sm_heroes_with", with)
	section("sm_heroes_all", rest)

	if #with + #rest == 0 then
		g.text(600, 15, L("sm_empty_search"), x0 + w0 / 2, K.TOP + 140, T.t2, 1, "c")
		g.text(400, 13, L("sm_empty_search_d"), x0 + w0 / 2, K.TOP + 164, T.t4, 1, "c")
	end
	view.end_scroll(y + S.scroll - K.TOP + 12)
end

function view.detail()
	local s = BY_ID[S.sel]
	local x0, w0 = K.SIDE, K.W - K.SIDE
	hit.add(x0, 0, w0, K.TOP, "drag", { down = view.start_drag })

	local back_keys = { all = "sm_nav_all", installed = "sm_nav_installed", updates = "sm_nav_updates", heroes = "sm_nav_heroes" }
	local back = L(back_keys[S.nav] or ("sm_cat_" .. S.nav))
	if S.nav == "heroes" and S.hero then back = market.hero_name(S.hero) end
	local bw = 6 + 18 + 4 + g.width(500, 13, back) + 12
	local hv = anim.hover("back")
	g.rect(x0 + 16, 17, bw, 34, T.white, 9, 0.08 * hv)
	g.glyph(K.G.back, 12, x0 + 16 + 15, 34, T.t5)
	g.text(500, 13, back, x0 + 16 + 28, 34, T.t5)
	hit.add(x0 + 16, 17, bw, 34, "back", { click = function() view.go("list") end })

	view.scroll_area(x0, K.TOP, w0, K.H - K.TOP)
	local cx, cw = x0 + 40, w0 - 80
	local y = K.TOP + 4 - S.scroll
	local k, v = market.status(s), S.inst[s.id]

	local right = cx + cw
	local act_key = { none = "sm_install", update = "sm_update", manual = "sm_download" }
	local function act_w(st)
		if st == "none" or st == "update" or st == "manual" then return g.width(600, 13, L(act_key[st])) + 40 end
		if st == "busy" then return 14 + g.width(500, 13, L("sm_installing")) + 10 + 24 + 6 end
		return 16 + 13 + 7 + g.width(500, 13, L("sm_installed")) + 16
	end
	local aw = anim.tween("d_aw:" .. s.id, act_w(k), 0.22, ease_in_out)
	local ax = right - aw
	local white_k = anim.tween("d_wh:" .. s.id, act_key[k] and 1 or 0, 0.2)
	local bg_a = 0.06 + (k == "busy" and 0.02 or 0)
	g.rect(ax, y + 23, aw, 34, anim.mix(T.white, T.pill, white_k), 17, bg_a + (1 - bg_a) * white_k)
	local hv = anim.hover("d_act")
	if white_k > 0.5 then g.rect(ax, y + 23, aw, 34, T.dark, 17, 0.08 * hv * white_k) end
	g.clip(ax, y + 23, aw, 34)
	anim.cross("d_act:" .. s.id, k, function(st, live, a)
		local dy = 5 * (1 - a)
		if act_key[st] then
			g.text(600, 13, L(act_key[st]), ax + aw / 2, y + 40 + dy, T.dark, 1, "c")
			if live then hit.add(ax, y + 23, aw, 34, "d_act", { click = function() market.run(s.id) end }) end
		elseif st == "busy" then
			g.text(500, 13, L("sm_installing"), right - 6 - 24 - 10, y + 40 + dy, T.t2, 1, "r")
			g.ring(right - 6 - 12, y + 40, 9.5 * (0.8 + 0.2 * a), T.white, 0.14, 2.5, 0, 1)
			g.ring(right - 6 - 12, y + 40, 9.5 * (0.8 + 0.2 * a), T.pill, 1, 2.5, (S.now * 360) % 360, 0.28)
		else
			local tw = 13 + 7 + g.width(500, 13, L("sm_installed"))
			local lx = ax + (aw - tw) / 2
			g.glyph(K.G.check, 10 * (0.6 + 0.4 * a), lx + 6, y + 40, T.t3)
			g.text(500, 13, L("sm_installed"), lx + 20, y + 40 + dy, T.t3)
		end
	end, 0.22)
	g.unclip()
	right = ax

	local show_rm = v ~= nil and k ~= "busy"
	local ra = anim.tween("d_rm:" .. s.id, show_rm and 1 or 0, show_rm and 0.2 or 0.12)
	if ra > 0.01 then
		local confirm = S.confirm == s.id and show_rm
		local rk = anim.tween("d_rc:" .. s.id, confirm and 1 or 0, 0.18, ease_in_out)
		local w_off = g.width(500, 13, L("sm_remove")) + 32
		local w_on = g.width(600, 13, L("sm_remove_confirm")) + 32
		local w = w_off + (w_on - w_off) * rk
		local rx = right - 8 - w
		local rhv = anim.hover("d_remove")
		local base = g.a
		g.a = base * ra
		g.rect(rx, y + 23, w, 34, T.white, 17, 0.08 * rhv * (1 - rk))
		g.rect(rx, y + 23, w, 34, T.red_bg, 17, rk * (1 + 0.3 * rhv))
		g.clip(rx, y + 23, w, 34)
		if rk < 0.99 then g.text(500, 13, L("sm_remove"), rx + w / 2, y + 40, T.t3, 1 - rk, "c") end
		if rk > 0.01 then g.text(600, 13, L("sm_remove_confirm"), rx + w / 2, y + 40, T.red, rk, "c") end
		g.unclip()
		g.a = base
		if show_rm then hit.add(rx, y + 23, w, 34, "d_remove", { click = function() market.remove(s.id) end }) end
		right = right - (8 + w) * ra
	end

	g.rect(cx, y, 80, 80, s.color, 20, 0.15)
	g.glyph(s.glyph, 32, cx + 40, y + 40, s.color)
	local title_w = right - 16 - (cx + 100)
	g.text(700, 26, g.fit(700, 26, s.title, title_w), cx + 100, y + 27, T.t1)
	g.text(400, 14, g.fit(400, 14, tr(s.tag), title_w), cx + 100, y + 56, T.t3)
	y = y + 80 + 28

	local stats
	if k == "update" then
		stats = { { "sm_st_installed", v }, { "sm_st_available", s.latest } }
	else
		stats = { { "sm_st_version", s.latest }, { "sm_st_installed", v or "-" } }
	end
	stats[3] = { "sm_st_category", L("sm_cat_" .. s.cat) }
	stats[4] = { "sm_st_library", s.nlz and L("sm_lib_nlz") or L("sm_lib_none") }
	g.hl(cx, y, cw, T.white, C.line / 255)
	local colw = cw / 4
	for i, st in ipairs(stats) do
		local sx = cx + (i - 1) * colw
		if i > 1 then g.vl(sx, y + 14, 40, T.white, C.line / 255) end
		g.text(400, 12, L(st[1]), sx + 16, y + 14 + 8, T.t4)
		g.text(600, 16, g.fit(600, 16, st[2], colw - 32), sx + 16, y + 14 + 31, T.t1)
	end
	y = y + 68
	g.hl(cx, y, cw, T.white, C.line / 255)
	y = y + 28

	if #s.heroes > 0 then
		local hx = cx
		for _, hid in ipairs(s.heroes) do
			local name = market.hero_name(hid)
			local w = 6 + 18 + 7 + g.width(500, 12, name) + 12
			local chip = "chip:" .. hid
			g.frame(hx, y, w, 26, T.white, 13, 0.12 + 0.1 * anim.hover(chip))
			g.hero(hid, hx + 6, y + 4, 18, 1, 9)
			g.text(500, 12, name, hx + 6 + 18 + 7, y + 13, T.t2)
			hit.add(hx, y, w, 26, chip, { click = function()
				S.nav, S.hero = "heroes", hid
				view.go("list")
			end })
			hx = hx + w + 6
		end
		y = y + 26 + 18
	end

	if s.author or s.source then
		local x = cx
		if s.author then
			local label = g.fit(500, 12, L("sm_author") .. ": " .. s.author, cw / 2)
			x = x + g.text(500, 12, label, x, y + 6, T.t3) + 20
		end
		if s.source then g.text(400, 12, L("sm_source") .. ": " .. s.source, x, y + 6, T.t4) end
		y = y + 28
	end

	local about_text = tr(s.about)
	if about_text ~= "" then
		g.text(700, 17, L("sm_about"), cx, y + 11, T.t1)
		y = y + 22 + 12
		local about = g.wrap(400, 14, about_text, cw)
		for i, line in ipairs(about) do g.text(400, 14, line, cx, y + (i - 1) * 22 + 11, T.t2) end
		y = y + #about * 22 + 28
	end

	local features = s.features[S.lang]
	if #features == 0 then features = s.features.en end
	if #features > 0 then
		g.text(700, 17, L("sm_features"), cx, y + 11, T.t1)
		y = y + 22 + 12
	end
	local fw = (cw - 28) / 2
	local i = 1
	while i <= #features do
		local row_h = 0
		for c = 0, 1 do
			local f = features[i + c]
			if f then
				local fx = cx + c * (fw + 28)
				local lines = g.wrap(400, 13, f, fw - 14)
				g.dot(fx + 2, y + 10, 2, s.color)
				for li, line in ipairs(lines) do g.text(400, 13, line, fx + 14, y + (li - 1) * 19.5 + 10, T.t2) end
				row_h = math.max(row_h, #lines * 19.5)
			end
		end
		y = y + row_h + 10
		i = i + 2
	end
	view.end_scroll(y + S.scroll - K.TOP + 26)
end

function view.switch(x, y, on, id, click)
	local k = anim.tween("sw:" .. id, on and 1 or 0, 0.18, ease_in_out)
	local off, acc = C.off, K.ACCENT
	local track = { off[1] + (acc[1] - off[1]) * k, off[2] + (acc[2] - off[2]) * k, off[3] + (acc[3] - off[3]) * k }
	g.rect(x, y, 34, 20, track, 10)
	local kc = { T.knob_off[1] + (255 - T.knob_off[1]) * k, T.knob_off[2] + (255 - T.knob_off[2]) * k, T.knob_off[3] + (255 - T.knob_off[3]) * k }
	g.dot(x + 10 + 14 * k, y + 10, 8, kc)
	hit.add(x, y, 34, 20, id, { click = click })
end

function view.dropdown(x, y, key, value, open)
	local id = "dd:" .. key
	local hv = anim.hover(id)
	local ok = anim.tween("dd_on:" .. key, open and 1 or 0, 0.16)
	g.rect(x, y, 132, 28, C.dd, 7)
	local fa = 0.14 * hv + (0.18 - 0.14 * hv) * ok
	if fa > 0.005 then g.frame(x, y, 132, 28, T.white, 7, fa) end
	g.clip(x, y, 132 - 26, 28)
	anim.cross("dd_v:" .. key, value, function(str, _, a)
		g.text(500, 12, str, x + 10, y + 14 + 4 * (1 - a), T.t5)
	end, 0.18)
	g.unclip()
	if ok < 0.99 then g.glyph(K.G.down, 9, x + 132 - 15, y + 14 + 2 * ok, T.t3, 1 - ok) end
	if ok > 0.01 then g.glyph(K.G.up, 9, x + 132 - 15, y + 14 - 2 * (1 - ok), T.t3, ok) end
	hit.add(x, y, 132, 28, id, { click = function()
		if open then S.menu = nil else S.menu = key end
	end })
end

function view.dropdown_menu(x, y, key, opts, cur, pick, k, live)
	local h = 8 + #opts * 28
	local add = live and hit.add or function() end
	local a
	a, y = anim.menu_begin(x, y, 132, h, k)
	g.rect(x, y, 132, h, C.menu, 8)
	g.frame(x, y, 132, h, T.white, 8, 0.1)
	add(x, y, 132, h, "menu:" .. key .. "_bg")
	for i, o in ipairs(opts) do
		local id = "menu:" .. key .. "_" .. o
		local iy = y + 4 + (i - 1) * 28
		local hv = anim.hover(id)
		g.rect(x + 4, iy, 124, 28, T.white, 5, 0.08 * hv)
		local on = o == cur
		g.text(on and 600 or 500, 12, L("sm_" .. key .. "_" .. o), x + 12, iy + 14, on and K.ACCENT_TEXT or T.t5)
		add(x + 4, iy, 124, 28, id, { click = function()
			pick(o)
			S.menu = nil
		end })
	end
	anim.menu_end(a)
end

function view.swatches(right, cy, order, cur, prefix, color, pick)
	local size, gap = 20, 8
	local x = right - (#order * size + (#order - 1) * gap)
	for i, id in ipairs(order) do
		local key = prefix .. id
		local hv = anim.hover(key)
		local on = anim.tween("sw_on:" .. key, cur == id and 1 or 0, 0.16)
		local sx = x + (i - 1) * (size + gap) + size / 2
		g.dot(sx, cy, size / 2 - 1 + 0.8 * hv, color(id))
		g.ring(sx, cy, size / 2 - 1, T.white, 0.14, 1, 0, 1)
		if on > 0.01 then g.ring(sx, cy, size / 2 + 3.5, T.white, 0.85 * on, 1.5, 0, 1) end
		hit.add(sx - size / 2 - gap / 2, cy - size / 2 - 4, size + gap, size + 8, key, { click = function() pick(id) end })
	end
end

function view.settings()
	local x0, w0 = K.SIDE, K.W - K.SIDE
	hit.add(x0, 0, w0, K.H, "drag", { down = view.start_drag })
	local cx, cw = x0 + 24, w0 - 48
	local y = 24
	g.text(700, 20, L("sm_settings"), cx + 4, y + 12, T.t1)
	y = y + 24 + 18

	local menus = {}

	local function pick_row(key)
		return { label = "sm_set_" .. key, draw = function(ry, right)
			local open = S.menu == key
			local dx = right - 132
			view.dropdown(dx, ry + 6, key, L("sm_" .. key .. "_" .. S.set[key]), open)
			local mk = anim.menu(key, open)
			if mk > 0.005 then menus[#menus + 1] = { dx, ry + 6 + 32, key, S.set[key], mk, open } end
		end }
	end

	local function card(title, rows)
		g.text(600, 11, L(title), cx + 4, y + 7, T.t4)
		y = y + 22
		g.rect(cx, y, cw, 8 + #rows * 40, C.card, 10)
		for i, row in ipairs(rows) do
			local ry = y + 4 + (i - 1) * 40
			g.text(400, 13, L(row.label), cx + 14, ry + 20, T.t5)
			if row.note then
				g.text(400, 12, row.note(), cx + 14 + g.width(400, 13, L(row.label)) + 10, ry + 20, T.t4)
			end
			row.draw(ry, cx + cw - 12)
		end
		y = y + 8 + #rows * 40 + 20
	end

	card("sm_g_updates", {
		pick_row("check"),
		{ label = "sm_set_beta", draw = function(ry, right)
			view.switch(right - 34, ry + 10, S.set.beta, "beta", function()
				S.set.beta = not S.set.beta
				save("beta", S.set.beta and 1 or 0)
			end)
		end },
		pick_row("restart"),
	})

	card("sm_g_look", {
		{ label = "sm_set_theme", note = function() return L("sm_theme_" .. S.set.theme) end, draw = function(ry, right)
			view.swatches(right, ry + 20, THEME_ORDER, S.set.theme, "th:", function(id) return THEMES[id].menu end, market.set_theme)
		end },
		{ label = "sm_set_accent", note = function() return L("sm_accent_" .. S.set.accent) end, draw = function(ry, right)
			view.swatches(right, ry + 20, ACCENT_ORDER, S.set.accent, "ac:", function(id) return ACCENTS[id] end, market.set_accent)
		end },
	})

	for _, m in ipairs(menus) do
		view.dropdown_menu(m[1], m[2], m[3], SETS[m[3]], m[4], function(o)
			S.set[m[3]] = o
			save(m[3], o)
		end, m[5], m[6])
	end
end

function view.grip()
	local id = "grip"
	local on = hit.is(id) or S.resize ~= nil
	local c = on and T.t2 or { 110, 110, 115 }
	g.line(K.W - 6, K.H - 14, K.W - 14, K.H - 6, c, 1, 1.5)
	g.line(K.W - 6, K.H - 9, K.W - 9, K.H - 6, c, 1, 1.5)
	hit.add(K.W - 20, K.H - 20, 20, 20, id, { down = function(mx)
		S.resize = { mx = mx, w = K.W * g.s, scale = S.scale }
	end })
	if S.resize then
		local label = S.scale .. "%"
		local w = g.width(600, 11, label) + 16
		g.rect(K.W - 26 - w, K.H - 8 - 22, w, 22, C.menu, 11)
		g.frame(K.W - 26 - w, K.H - 8 - 22, w, 22, T.white, 11, 0.12)
		g.text(600, 11, label, K.W - 26 - w / 2, K.H - 8 - 11, T.t5, 1, "c")
	end
end

function view.window()
	local screen = Render.ScreenSize()
	g.s = math.max(0.7, screen.y / 1080) * S.scale / 100
	g.rescale(g.s)
	if not S.wx then
		S.wx = Config.ReadInt(K.CFG, "wx", -1)
		S.wy = Config.ReadInt(K.CFG, "wy", -1)
		if S.wx < 0 then
			S.wx = math.floor((screen.x - K.W * g.s) / 2)
			S.wy = math.floor((screen.y - K.H * g.s) / 2)
		end
	end
	S.wx = clamp(S.wx, 0, math.max(0, screen.x - K.W * g.s))
	S.wy = clamp(S.wy, 0, math.max(0, screen.y - K.H * g.s))
	g.x, g.y, g.a = S.wx, S.wy, S.alpha
	hit.begin()

	hit.add(0, 0, K.W, K.H, "win")
	g.rect(0, 0, K.W, K.H, C.win, 16)
	view.sidebar()

	local key = S.view .. ":" .. S.nav .. ":" .. tostring(S.sel) .. ":" .. tostring(S.hero)
	if key ~= S.page_key then
		S.page_key = key
		anim.snap("page", 0)
		for name in pairs(S.tweens) do
			if name:sub(1, 3) == "mn:" then S.tweens[name] = nil end
		end
	end
	local pa = anim.tween("page", 1, 0.18)
	g.a = S.alpha * pa
	if S.view == "detail" and BY_ID[S.sel] then
		view.detail()
	elseif S.view == "settings" then
		view.settings()
	elseif S.nav == "heroes" and not S.hero then
		S.sort_open = false
		view.heroes()
	else
		view.list()
		local mk = anim.menu("sort", S.sort_open)
		if mk > 0.005 then view.sort_menu(K.W - 24, 16 + 36 + 6, mk, S.sort_open) end
	end
	g.a = S.alpha

	g.frame(0, 0, K.W, K.H, T.white, 16, 0.09)
	view.grip()
end

local JS_SINK = [[
(function () {
	let root = $.GetContextPanel();
	while (root.GetParent()) root = root.GetParent();
	let sink = root.FindChild('ScriptManagerInput');
	const drop = () => {
		sink.text = '';
		sink.DeleteAsync(0);
	};
	if (%s) {
		if (!sink) {
			sink = $.CreatePanel('TextEntry', root, 'ScriptManagerInput');
			sink.style.width = '1px';
			sink.style.height = '1px';
			sink.style.opacity = '0';
			sink.hittest = false;
			const watch = () => {
				if (!sink.IsValid()) return;
				if (Date.now() - Number(sink.GetAttributeString('alive', '0')) > %d) return drop();
				$.Schedule(0.25, watch);
			};
			$.Schedule(0.25, watch);
		}
		sink.SetAttributeString('alive', String(Date.now()));
		sink.text = '';
		sink.SetFocus();
	} else if (sink) {
		drop();
	}
})();
]]

local input = { swallow = false, held = {}, sink_on = false, sink_at = 0 }

function input.sink(on, force)
	local now = os.clock()
	if input.sink_on == on and not force and not (on and now >= input.sink_at) then return end
	input.sink_on, input.sink_at = on, now + K.SINK_ALIVE
	Engine.RunScript(JS_SINK:format(on and "true" or "false", K.SINK_TIMEOUT))
end

Engine.RunScript(JS_SINK:format("false", K.SINK_TIMEOUT))

local function inside(mx, my)
	return S.wx and mx >= S.wx and my >= S.wy and mx < S.wx + K.W * g.s and my < S.wy + K.H * g.s
end

function input.press(mx, my)
	local h = hit.at(mx, my)
	local id, on = h and h[5], h and h[6] or {}
	if (S.sort_open or S.menu) and not (id and (id:sub(1, 5) == "menu:" or id == "sort" or id:sub(1, 3) == "dd:")) then
		S.sort_open, S.menu = false, nil
		S.press = { id = false }
		return
	end
	if id ~= "search" and id ~= "search_clear" then S.focus = false end
	if id ~= "d_remove" then S.confirm = nil end
	S.press = { id = id or false, on = on }
	if on.down then on.down(mx, my) end
end

function input.release(mx, my)
	local press = S.press
	S.press = nil
	if not press or not press.id then return end
	local h = hit.at(mx, my)
	if not h or h[5] ~= press.id then return end
	if press.on.click then press.on.click(mx, my) end
end

function input.end_drag()
	if S.drag then
		save("wx", math.floor(S.wx))
		save("wy", math.floor(S.wy))
	end
	if S.resize then save("scale", S.scale) end
	S.drag, S.resize, S.q_drag = nil, nil, false
end

function input.key(key)
	if S.focus then
		local ctrl = Input.IsKeyDown(KEY.KEY_LCONTROL) or Input.IsKeyDown(KEY.KEY_RCONTROL)
		local shift = Input.IsKeyDown(KEY.KEY_LSHIFT) or Input.IsKeyDown(KEY.KEY_RSHIFT)
		edit.key(key, ctrl, shift)
		return
	end
	if key == KEY.KEY_ESCAPE then
		if S.sort_open or S.menu then
			S.sort_open, S.menu = false, nil
		elseif S.view ~= "list" then
			view.go("list")
		else
			S.open = false
		end
	end
end

local script = {}

function script.OnUpdateEx()
	if not ui.enable:Get() then return end
	if ui.key:IsPressed() and not Input.IsInputCaptured() and not S.focus then S.open = not S.open end
end

function script.OnFrame()
	if not ui.enable:Get() then return end
	local now = os.clock()
	local frame = GlobalVars.GetAbsFrameTime()
	S.dt = clamp(frame > 0 and frame or (now - (S.now > 0 and S.now or now)), 0, 0.1)
	S.now = now
	S.lang = localization.GetLanguage() == "ru" and "ru" or "en"
	market.tick()
	S.alpha = anim.tween("window", S.open and 1 or 0, 0.18)
	if not S.open then S.focus = false end
	input.sink(S.focus and S.open)
	if S.alpha <= 0 then return end

	if S.press and not Input.IsKeyDown(KEY.KEY_MOUSE1, true) then
		input.end_drag()
		S.press = nil
	end
	for key in pairs(input.held) do
		if not Input.IsKeyDown(key, true) then input.held[key] = nil end
	end
	local mx, my = Input.GetCursorPos()
	if S.drag then
		S.wx, S.wy = S.drag.wx + mx - S.drag.mx, S.drag.wy + my - S.drag.my
	end
	if S.q_drag then S.qc = edit.index_at(mx) end
	if S.resize then
		local r = S.resize
		S.scale = clamp(math.floor(r.scale * (r.w + mx - r.mx) / r.w + 0.5), K.SCALE_MIN, K.SCALE_MAX)
	end
	local ok, err = pcall(view.window)
	if ok then return end
	g.reset()
	hit.clip = nil
	if err ~= S.draw_error then
		S.draw_error = err
		Log.Write("[Script Manager] draw: " .. tostring(err))
	end
end

function script.OnKeyEvent(e)
	if not ui.enable:Get() or S.alpha <= 0 or not S.open then return true end
	local mx, my = Input.GetCursorPos()
	local over = inside(mx, my)
	if e.event == Enum.EKeyEvent.EKeyEvent_SCROLL_UP or e.event == Enum.EKeyEvent.EKeyEvent_SCROLL_DOWN then
		if not over then return true end
		for i = #hit.list, 1, -1 do
			local h = hit.list[i]
			if h[5] == "content" and mx >= h[1] and mx < h[3] and my >= h[2] and my < h[4] then
				h[6].wheel(e.event == Enum.EKeyEvent.EKeyEvent_SCROLL_DOWN and 1 or -1)
				break
			end
		end
		return false
	end
	if e.key == KEY.KEY_MOUSE1 or e.key == KEY.KEY_MOUSE2 then
		local left = e.key == KEY.KEY_MOUSE1
		if e.event == Enum.EKeyEvent.EKeyEvent_KEY_DOWN then
			if input.held[e.key] then return not input.swallow end
			input.held[e.key] = true
			if not over then
				S.focus = false
				S.sort_open, S.menu = false, nil
				if left then S.press = { id = false } end
				return true
			end
			input.swallow = true
			if left then input.press(mx, my) end
			return false
		elseif e.event == Enum.EKeyEvent.EKeyEvent_KEY_UP then
			input.held[e.key] = nil
			if left then
				input.end_drag()
				input.release(mx, my)
			end
			if input.swallow then
				input.swallow = false
				return false
			end
		end
		return true
	end
	if S.focus then
		if e.event == Enum.EKeyEvent.EKeyEvent_KEY_DOWN then
			input.sink(true, true)
			input.key(e.key)
		end
		return false
	end
	if e.event == Enum.EKeyEvent.EKeyEvent_KEY_DOWN and e.key == KEY.KEY_ESCAPE and over and not Input.IsInputCaptured() then
		input.key(e.key)
		return false
	end
	return true
end

ui.enable:SetCallback(function()
	local on = ui.enable:Get()
	ui.key:Disabled(not on)
	ui.open:Disabled(not on)
	if not on then
		S.focus = false
		input.sink(false)
	end
end, true)

return script
