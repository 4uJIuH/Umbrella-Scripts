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

local VERSION = "1.6.0"

local localization = qLocalization.new({
	en = {
		sm_group_main = "Script Manager",
		sm_open = "Open manager",
		sm_open_tip = "Opens the Script Manager panel",
		sm_ui_tab = "Script Manager Visuals",
		sm_ui_group = "Interface",
		sm_ui_subtitle = "Settings are saved automatically and applied to the panel",
		sm_ui_enabled = "Enabled",
		sm_ui_disabled = "Disabled",
		sm_ui_back = "Back",
		sm_ui_blur = "Background blur",
		sm_ui_blur_tip = "Blur the game behind the manager",
		sm_ui_blur_power = "Blur strength",
		sm_ui_opacity = "Panel opacity",
		sm_ui_scale = "Panel scale",
		sm_ui_theme = "Theme",
		sm_ui_accent = "Accent color",
		sm_ui_compact = "Compact mode",
		sm_ui_compact_tip = "Use tighter spacing in the script list",
		sm_theme_graphite = "Graphite",
		sm_theme_midnight = "Midnight",
		sm_theme_warm = "Warm",
		sm_theme_purple = "Purple",
		sm_theme_red = "Red",
		sm_theme_oled = "OLED",
		sm_accent_red = "Red",
		sm_accent_teal = "Teal",
		sm_accent_blue = "Blue",
		sm_accent_purple = "Purple",
		sm_accent_orange = "Orange",
		sm_accent_green = "Green",
		sm_panel_title = "Script Manager",
		sm_panel_subtitle = "UMBRELLA UPDATE CENTER",
		sm_panel_scripts = "DOTA SCRIPTS",
		sm_panel_selected = "SELECTED SCRIPT",
		sm_panel_installed = "INSTALLED",
		sm_panel_latest = "LATEST",
		sm_panel_status = "ACTIVITY",
		sm_panel_localizer_title = "qLocalization",
		sm_panel_localizer_desc = "Author: qfun (qfun_g9s) · installed as !_qLocalizer.lua",
		sm_panel_localizer_ready = "Installed",
		sm_panel_not_detected = "Not detected",
		sm_panel_not_checked = "Not checked",
		sm_panel_current_badge = "UP TO DATE",
		sm_panel_update_badge = "UPDATE",
		sm_panel_manual_badge = "MANUAL ZIP",
		sm_panel_installing_badge = "WORKING",
		sm_panel_check_button = "Check all",
		sm_panel_install_button = "Install update",
		sm_panel_download_button = "Download ZIP",
		sm_panel_localizer_button = "Install qLocalization",
		sm_panel_last_checked = "Last checked: %s",
		sm_panel_never_checked = "No successful checks yet",
		sm_panel_cached = "CACHED",
		sm_panel_checking = "CHECKING",
		sm_panel_error_badge = "CHECK FAILED",
		sm_panel_state_current = "UP TO DATE",
		sm_panel_state_available = "UPDATE AVAILABLE",
		sm_panel_state_manual = "PACKAGE",
		sm_panel_state_error = "CHECK FAILED",
		sm_panel_state_unknown = "NOT CHECKED",
		sm_status_idle = "Select a script to see its saved update status",
		sm_status_fetching = "Refreshing all script versions from GitHub...",
		sm_status_checked = "Check complete (successful / failed): %s",
		sm_status_cache_current = "Saved result: up to date at v%s",
		sm_status_cache_available = "Saved update available: v%s",
		sm_status_cache_manual = "Saved package version: v%s",
		sm_status_cache_error = "Last check failed: %s",
		sm_status_current = "Already up to date: %s",
		sm_status_available = "Update available: %s",
		sm_status_installed = "Installed %s. Reloading scripts...",
		sm_status_manual = "ZIP is ready to download: %s",
		sm_status_localizer = "qLocalization is already installed",
		sm_status_localizer_installed = "qLocalization installed. Reloading scripts...",
		sm_status_error = "Error: %s",
		sm_item_ttd = "Tinker Turret Dodge",
		sm_item_farm = "Tinker Auto Farm",
		sm_item_shackleshot = "Auto Shackleshot",
		sm_item_spark = "Auto Spark",
		sm_item_runes = "Rune Destruction",
		sm_item_earth = "Earth Spirit Kick Combo",
		sm_item_hp = "HP/Mana 67 Ping",
		sm_item_bear = "Spirit Bear Pull",
		sm_item_manager = "Script Manager",
		sm_item_dynamic_island = "Dynamic Island",
		sm_item_tinker_escape = "Tinker Smart Escape",
		sm_desc_ttd = "Uses Tinker's turrets to dodge dangerous enemy abilities.",
		sm_desc_farm = "Tinker farming script distributed as a ZIP package.",
		sm_desc_shackleshot = "Automatically aims and casts Windranger's Shackleshot.",
		sm_desc_spark = "Automatically places and targets Arc Warden's Spark Wraiths.",
		sm_desc_runes = "Sends controlled units to collect or destroy runes.",
		sm_desc_earth = "Automates Earth Spirit's Blink and kick combo.",
		sm_desc_hp = "Tracks HP and mana thresholds and sends chat alerts.",
		sm_desc_bear = "Uses Lone Druid's Spirit Bear to pull a creep wave.",
		sm_desc_manager = "Checks script versions and installs selected updates.",
		sm_desc_dynamic_island = "By \"ur2m\" (@qhols). The Lua script works alone; music and sounds need the optional media bridge.",
		sm_desc_tinker_escape = "By sataroz. Hold one key to escape towards the cursor using Tinker abilities and items.",
		sm_tip_settings = "Appearance",
		sm_tip_back = "Back to scripts",
		sm_tip_close = "Close",
		sm_tip_check = "Check every script for updates",
		sm_ui_theme_sub = "Color scheme of the panel",
		sm_ui_accent_sub = "Buttons, highlights and active items",
		sm_ui_window = "Window",
		sm_ui_defaults = "Reset",
		sm_ui_scale_sub = "Size of the whole panel",
		sm_ui_opacity_sub = "How see-through the panel is",
		sm_row_update = "Update v%s",
		sm_pill_updates = "%d updates",
		sm_pill_current = "All up to date",
		sm_chip_zip = "ZIP package",
		sm_chip_localizer = "Needs qLocalization",
	},
	ru = {
		sm_group_main = "Script Manager",
		sm_open = "Открыть менеджер",
		sm_open_tip = "Открывает панель Script Manager",
		sm_ui_tab = "Визуал Script Manager",
		sm_ui_group = "Внешний вид",
		sm_ui_subtitle = "Настройки сохраняются автоматически и сразу применяются к панели",
		sm_ui_enabled = "Включено",
		sm_ui_disabled = "Выключено",
		sm_ui_back = "Назад",
		sm_ui_blur = "Размытие фона",
		sm_ui_blur_tip = "Размывает игру за окном менеджера",
		sm_ui_blur_power = "Сила размытия",
		sm_ui_opacity = "Прозрачность панели",
		sm_ui_scale = "Масштаб панели",
		sm_ui_theme = "Тема",
		sm_ui_accent = "Акцентный цвет",
		sm_ui_compact = "Компактный режим",
		sm_ui_compact_tip = "Уменьшает интервалы в списке скриптов",
		sm_theme_graphite = "Графит",
		sm_theme_midnight = "Полночь",
		sm_theme_warm = "Тёплая",
		sm_theme_purple = "Фиолетовая",
		sm_theme_red = "Красная",
		sm_theme_oled = "OLED",
		sm_accent_red = "Красный",
		sm_accent_teal = "Бирюзовый",
		sm_accent_blue = "Синий",
		sm_accent_purple = "Фиолетовый",
		sm_accent_orange = "Оранжевый",
		sm_accent_green = "Зелёный",
		sm_panel_title = "Script Manager",
		sm_panel_subtitle = "ЦЕНТР ОБНОВЛЕНИЙ UMBRELLA",
		sm_panel_scripts = "СКРИПТЫ DOTA",
		sm_panel_selected = "ВЫБРАННЫЙ СКРИПТ",
		sm_panel_installed = "УСТАНОВЛЕНА",
		sm_panel_latest = "ПОСЛЕДНЯЯ",
		sm_panel_status = "СОСТОЯНИЕ",
		sm_panel_localizer_title = "qLocalization",
		sm_panel_localizer_desc = "Автор: qfun (qfun_g9s) · устанавливается как !_qLocalizer.lua",
		sm_panel_localizer_ready = "Установлена",
		sm_panel_not_detected = "Не обнаружена",
		sm_panel_not_checked = "Не проверена",
		sm_panel_current_badge = "АКТУАЛЬНА",
		sm_panel_update_badge = "ОБНОВЛЕНИЕ",
		sm_panel_manual_badge = "ZIP ВРУЧНУЮ",
		sm_panel_installing_badge = "РАБОТАЕТ",
		sm_panel_check_button = "Проверить все",
		sm_panel_install_button = "Установить",
		sm_panel_download_button = "Скачать ZIP",
		sm_panel_localizer_button = "Установить qLocalization",
		sm_panel_last_checked = "Последняя проверка: %s",
		sm_panel_never_checked = "Успешных проверок ещё не было",
		sm_panel_cached = "СОХРАНЕНО",
		sm_panel_checking = "ПРОВЕРКА",
		sm_panel_error_badge = "ОШИБКА",
		sm_panel_state_current = "АКТУАЛЕН",
		sm_panel_state_available = "ЕСТЬ ОБНОВЛЕНИЕ",
		sm_panel_state_manual = "ZIP-ПАКЕТ",
		sm_panel_state_error = "ОШИБКА",
		sm_panel_state_unknown = "НЕ ПРОВЕРЕН",
		sm_status_idle = "Выберите скрипт, чтобы увидеть сохранённый статус обновления",
		sm_status_fetching = "Обновление версий всех скриптов с GitHub...",
		sm_status_checked = "Проверка завершена (успешно / с ошибкой): %s",
		sm_status_cache_current = "Сохранённый результат: актуальная версия v%s",
		sm_status_cache_available = "Доступно обновление: v%s (сохранённый результат)",
		sm_status_cache_manual = "Сохранённая версия пакета: v%s",
		sm_status_cache_error = "Последняя проверка завершилась ошибкой: %s",
		sm_status_current = "Установлена последняя версия: %s",
		sm_status_available = "Доступно обновление: %s",
		sm_status_installed = "Установлена версия %s. Перезагрузка скриптов...",
		sm_status_manual = "ZIP готов к скачиванию: %s",
		sm_status_localizer = "qLocalization уже установлен",
		sm_status_localizer_installed = "qLocalization установлен. Перезагрузка скриптов...",
		sm_status_error = "Ошибка: %s",
		sm_item_ttd = "Tinker Turret Dodge",
		sm_item_farm = "Tinker Auto Farm",
		sm_item_shackleshot = "Auto Shackleshot",
		sm_item_spark = "Auto Spark",
		sm_item_runes = "Rune Destruction",
		sm_item_earth = "Earth Spirit Kick Combo",
		sm_item_hp = "HP/Mana 67 Ping",
		sm_item_bear = "Spirit Bear Pull",
		sm_item_manager = "Script Manager",
		sm_item_dynamic_island = "Dynamic Island",
		sm_item_tinker_escape = "Tinker Smart Escape",
		sm_desc_ttd = "Уклоняется от опасных способностей врагов с помощью турелей Тинкера.",
		sm_desc_farm = "Скрипт для фарма за Тинкера. Распространяется ZIP-пакетом.",
		sm_desc_shackleshot = "Автоматически наводит и применяет Shackleshot за Windranger.",
		sm_desc_spark = "Автоматически устанавливает Spark Wraith и выбирает цели за Arc Warden.",
		sm_desc_runes = "Отправляет подконтрольных юнитов собирать или уничтожать руны.",
		sm_desc_earth = "Автоматизирует Blink-комбо Earth Spirit с толчком.",
		sm_desc_hp = "Отслеживает пороги здоровья и маны и отправляет сообщения в чат.",
		sm_desc_bear = "Использует Spirit Bear Lone Druid для отвода волны крипов.",
		sm_desc_manager = "Проверяет версии скриптов и устанавливает выбранные обновления.",
		sm_desc_dynamic_island = "Автор: \"ur2m\" (GitHub: @qhols). Lua-скрипт работает отдельно; для музыки и звуков нужен дополнительный media bridge.",
		sm_desc_tinker_escape = "Автор: sataroz. Побег Тинкера к курсору с использованием предметов и способностей по одной клавише.",
		sm_tip_settings = "Оформление",
		sm_tip_back = "Назад к скриптам",
		sm_tip_close = "Закрыть",
		sm_tip_check = "Проверить обновления всех скриптов",
		sm_ui_theme_sub = "Цветовая схема панели",
		sm_ui_accent_sub = "Кнопки, выделение и активные элементы",
		sm_ui_window = "Окно",
		sm_ui_defaults = "Сбросить",
		sm_ui_scale_sub = "Размер всей панели",
		sm_ui_opacity_sub = "Насколько прозрачна панель",
		sm_row_update = "Обновление v%s",
		sm_pill_updates = "Обновлений: %d",
		sm_pill_current = "Всё актуально",
		sm_chip_zip = "ZIP-пакет",
		sm_chip_localizer = "Нужна qLocalization",
	},
})

local UI = localization.WrapLibrary(Menu)
local L = localization.Get
local JSON = require("assets.JSON")

local CATALOG_URL = "https://raw.githubusercontent.com/4uJIuH/umbrella-scripts/main/scripts/manager/catalog.json"
local catalog_request_count = 0
local PAL = {
	blue = { 10, 132, 255 }, indigo = { 94, 92, 230 }, orange = { 255, 159, 10 }, green = { 48, 209, 88 },
	purple = { 191, 90, 242 }, teal = { 48, 176, 199 }, red = { 255, 69, 58 }, gray = { 142, 142, 147 },
	cyan = { 100, 210, 255 }, yellow = { 255, 214, 10 }, pink = { 255, 55, 95 },
}

local items = {
	{ id = "tinker_turret_dodge", key = "sm_item_ttd", description_key = "sm_desc_ttd", file = "tinker_turret_dodge.lua", needs_localizer = true },
	{ id = "tinker_auto_farm", key = "sm_item_farm", description_key = "sm_desc_farm", file = "Tinker-Auto-Farm.zip", manual = true },
	{ id = "auto_shackleshot", key = "sm_item_shackleshot", description_key = "sm_desc_shackleshot", file = "Auto_Shackleshot.lua", needs_localizer = true },
	{ id = "auto_spark", key = "sm_item_spark", description_key = "sm_desc_spark", file = "Auto_Spark.lua", needs_localizer = true },
	{ id = "rune_destruction", key = "sm_item_runes", description_key = "sm_desc_runes", file = "rune_units.lua" },
	{ id = "earth_spirit_kick_combo", key = "sm_item_earth", description_key = "sm_desc_earth", file = "earth_spirit_kick_combo.lua", needs_localizer = true },
	{ id = "hp_mana_67_ping", key = "sm_item_hp", description_key = "sm_desc_hp", file = "hp_mana_67_ping.lua", needs_localizer = true },
	{ id = "spirit_bear_pull", key = "sm_item_bear", description_key = "sm_desc_bear", file = "lone_druid_bear_pull.lua", needs_localizer = true },
	{ id = "script_manager", key = "sm_item_manager", description_key = "sm_desc_manager", file = "script_manager.lua" },
	{ id = "dynamic_island_dota", key = "sm_item_dynamic_island", description_key = "sm_desc_dynamic_island", file = "dynamic_island.lua", version_marker = "SCRIPT_VERSION" },
	{ id = "tinker_smart_escape", key = "sm_item_tinker_escape", description_key = "sm_desc_tinker_escape", file = "tinker_smart_escape.lua" },
}

local ITEM_STYLE = {
	tinker_turret_dodge = { "shield", PAL.blue },
	tinker_auto_farm = { "bag", PAL.orange },
	auto_shackleshot = { "pointer", PAL.teal },
	auto_spark = { "bolt", PAL.indigo },
	rune_destruction = { "gift", PAL.pink },
	earth_spirit_kick_combo = { "hand", PAL.green },
	hp_mana_67_ping = { "percent", PAL.red },
	spirit_bear_pull = { "users", PAL.purple },
	script_manager = { "wrench", PAL.gray },
	dynamic_island_dota = { "bolt", PAL.cyan },
	tinker_smart_escape = { "arrow_right", PAL.orange },
}
for _, entry in ipairs(items) do
	local style = ITEM_STYLE[entry.id]
	entry.glyph = style and style[1] or "bolt"
	entry.tile = style and style[2] or PAL.gray
end

local ui = {}
local selected_index = math.max(1, math.min(#items,
	Config.ReadInt("script_manager", "selected_index", 1)))
local selected_release
local installed_version
local working = false
local reload_at
local can_install = false
local can_download = false
local localizer_installed = false
local cached_releases = {}
local last_checked_at = Config.ReadInt("script_manager", "last_checked_at", 0)
local panel = { status_key = "sm_status_idle" }

do
	local tab = UI.Create("Scripts", "Scripts", "Script Manager")
	tab:Icon("\u{f013}")

	local page = tab:Create("Settings")
	local g_main = page:Create("sm_group_main", Enum.GroupSide.Left)
	ui.open = g_main:Bind("sm_open", Enum.ButtonCode.KEY_INSERT)
	ui.open:ToolTip("sm_open_tip")
end


local function set_status(key, value)
	panel.status_key = key
	panel.status_value = value
end

local function set_actions(allow_install, allow_download)
	can_install = allow_install == true
	can_download = allow_download == true
end

local function scripts_path()
	local dir = Engine.GetCheatDirectory()
	if type(dir) ~= "string" or dir == "" then return nil end
	if not dir:match("[\\/]$") then dir = dir .. "\\" end
	return dir .. "scripts\\"
end

local function read_file(path)
	local file = io.open(path, "rb")
	if not file then return nil end
	local text = file:read("a")
	file:close()
	return text
end

local function write_file(path, text)
	local file, err = io.open(path, "wb")
	if not file then return false, err end
	local ok, write_err = file:write(text)
	local closed, close_err = file:close()
	if not ok then return false, write_err end
	if not closed then return false, close_err end
	return true
end

local function write_download(path, text)
	local old_text = read_file(path)
	local backup_path = path .. ".script-manager.bak"

	if old_text and not read_file(backup_path) then
		local backed_up, backup_error = write_file(backup_path, old_text)
		if not backed_up then return false, backup_error or "could not create backup" end
	end

	local temp_path = path .. ".script-manager.tmp"
	local saved, save_error = write_file(temp_path, text)
	if not saved then return false, save_error or "could not write temporary file" end

	if old_text then os.remove(path) end
	local renamed, rename_error = os.rename(temp_path, path)
	if not renamed then
		os.remove(temp_path)
		if old_text then write_file(path, old_text) end
		return false, rename_error or "could not replace target file"
	end
	return true
end

local function trusted_url(url)
	if type(url) ~= "string" then return false end
	return url:match("^https://raw%.githubusercontent%.com/[%w%-_%.]+/[%w%-_%.]+/") ~= nil
		or url:match("^https://github%.com/[%w%-_%.]+/[%w%-_%.]+/releases/download/") ~= nil
end

local function valid_version(version)
	return type(version) == "string" and version:match("^%d+%.%d+%.%d+[%w%._%-]*$") ~= nil
end

local function compare_versions(left, right)
	local la, lb, lc, ls = left:match("^(%d+)%.(%d+)%.(%d+)(.*)$")
	local ra, rb, rc, rs = right:match("^(%d+)%.(%d+)%.(%d+)(.*)$")
	if not la or not ra then return nil end
	local lparts = { tonumber(la), tonumber(lb), tonumber(lc) }
	local rparts = { tonumber(ra), tonumber(rb), tonumber(rc) }
	for i = 1, 3 do
		if lparts[i] < rparts[i] then return -1 end
		if lparts[i] > rparts[i] then return 1 end
	end
	if ls == rs then return 0 end
	if ls == "" then return 1 end
	if rs == "" then return -1 end
	if ls < rs then return -1 end
	return 1
end

local function selected()
	return items[selected_index]
end

local function selected_manifest(manifest, item)
	if type(manifest) ~= "table" or manifest.schema ~= 1 or type(manifest.scripts) ~= "table" then
		return nil, "invalid catalog format"
	end
	for _, entry in ipairs(manifest.scripts) do
		if type(entry) == "table" and entry.id == item.id then
			if not valid_version(entry.version) or not trusted_url(entry.url) then
				return nil, "invalid release entry"
			end
			if entry.release ~= nil and not trusted_url(entry.release) then
				return nil, "invalid fallback URL"
			end
			return entry
		end
	end
	return nil, "script not found in catalog"
end

local function fetch(url, done)
	local sent = HTTP.Request("GET", url, { timeout = 20 }, function(response)
		local code = tonumber(response.code) or 0
		if code == 200 and type(response.response) == "string" and #response.response > 0 then
			done(response.response)
		else
			local detail = type(response.error_message) == "string" and response.error_message ~= ""
				and response.error_message or ("HTTP " .. tostring(code))
			done(nil, detail)
		end
	end, "script_manager")
	if not sent then done(nil, "request was not sent") end
end

local function load_catalog(done)
	catalog_request_count = catalog_request_count + 1
	set_status("sm_status_fetching")
	fetch(CATALOG_URL .. "?_=" .. tostring(os.time()) .. "-" .. tostring(catalog_request_count), function(text, err)
		if not text then return done(nil, err) end
		local ok, manifest = pcall(function() return JSON:decode(text) end)
		if not ok or type(manifest) ~= "table" then return done(nil, "catalog could not be parsed") end
		done(manifest)
	end)
end

local function script_version(text, marker)
	local pattern = marker == "SCRIPT_VERSION"
		and 'SCRIPT_VERSION%s*=%s*"([^"]+)"'
		or 'VERSION%s*=%s*"([^"]+)"'
	return text and text:match(pattern) or nil
end

local function validate_script(text, version, marker)
	if type(text) ~= "string" or #text < 100 or text:sub(1, 1) == "<" then return false end
	return script_version(text, marker) == version
end

local function selected_path(item)
	local dir = scripts_path()
	if not dir then return nil end
	return dir .. item.file
end

local function installed_script_version(item)
	if item.manual then return nil end
	local path = selected_path(item)
	local text = path and read_file(path)
	return script_version(text, item.version_marker)
end

local function cache_key(suffix, item)
	return suffix .. "_" .. item.id
end

local function load_update_cache()
	last_checked_at = math.max(0, Config.ReadInt("script_manager", "last_checked_at", 0))
	for _, item in ipairs(items) do
		local version = Config.ReadString("script_manager", cache_key("latest", item), "")
		local url = Config.ReadString("script_manager", cache_key("url", item), "")
		local release_url = Config.ReadString("script_manager", cache_key("release", item), "")
		if valid_version(version) and trusted_url(url)
			and (release_url == "" or trusted_url(release_url))
		then
			cached_releases[item.id] = {
				version = version,
				url = url,
				release = release_url ~= "" and release_url or nil,
				manual = item.manual == true,
				status = Config.ReadString("script_manager", cache_key("status", item), ""),
				error = Config.ReadString("script_manager", cache_key("error", item), ""),
			}
		end
	end
end

local function save_cached_release(item, release, status, err)
	local cached = {
		version = release and release.version or nil,
		url = release and release.url or nil,
		release = release and release.release or nil,
		manual = item.manual == true,
		status = status,
		error = err or "",
	}
	cached_releases[item.id] = cached
	if release then
		Config.WriteString("script_manager", cache_key("latest", item), release.version)
		Config.WriteString("script_manager", cache_key("url", item), release.url)
		Config.WriteString("script_manager", cache_key("release", item), release.release or "")
	end
	Config.WriteString("script_manager", cache_key("status", item), status)
	Config.WriteString("script_manager", cache_key("error", item), cached.error)
end

local function last_checked_text()
	if last_checked_at <= 0 then return L("sm_panel_never_checked") end
	return string.format(L("sm_panel_last_checked"), os.date("%Y-%m-%d %H:%M", last_checked_at))
end

local function show_cached_selection()
	local item = selected()
	selected_release = item and cached_releases[item.id] or nil
	installed_version = item and installed_script_version(item) or nil
	set_actions(false, false)

	local cached = selected_release
	if not cached then
		return set_status("sm_status_idle")
	elseif cached.status == "error" then
		return set_status("sm_status_cache_error", cached.error)
	elseif item.manual then
		set_actions(false, true)
		return set_status("sm_status_cache_manual", cached.version)
	end

	local comparison = installed_version and compare_versions(installed_version, cached.version) or nil
	if comparison == 0 or (comparison and comparison > 0) then
		return set_status("sm_status_cache_current", comparison > 0 and installed_version or cached.version)
	end
	set_actions(true, false)
	set_status("sm_status_cache_available", cached.version)
end

local function update_check()
	if working then return end
	working = true
	set_actions(false, false)
	load_catalog(function(manifest, err)
		working = false
		if not manifest then return set_status("sm_status_error", err) end

		local checked_count, errors = 0, 0
		for _, item in ipairs(items) do
			local release, release_error = selected_manifest(manifest, item)
			if release then
				local state = "available"
				if item.manual then
					state = "manual"
				else
					local local_version = installed_script_version(item)
					local comparison = local_version and compare_versions(local_version, release.version) or nil
					if comparison == 0 or (comparison and comparison > 0) then
						state = "current"
					end
				end
				save_cached_release(item, release, state)
				checked_count = checked_count + 1
			else
				local cached = cached_releases[item.id]
				save_cached_release(item, cached, "error", release_error)
				errors = errors + 1
			end
		end

		last_checked_at = os.time()
		Config.WriteInt("script_manager", "last_checked_at", last_checked_at)
		show_cached_selection()
		set_status("sm_status_checked", string.format("%d / %d", checked_count, errors))
	end)
end

local function install_localizer(manifest, done)
	local dir = scripts_path()
	if not dir then return done(false, "cheat directory is unavailable") end
	local path = dir .. "!_qLocalizer.lua"
	if read_file(path) then return done(true) end

	local dependency = manifest.q_localizer
	if type(dependency) ~= "table" or not valid_version(dependency.version) or not trusted_url(dependency.url) then
		return done(false, "qLocalization release is missing from catalog")
	end
	fetch(dependency.url, function(text, err)
		if not text then return done(false, err) end
		if #text < 1000 or not text:find("qLocalization", 1, true) then
			return done(false, "downloaded qLocalization file failed validation")
		end
		local saved, save_error = write_download(path, text)
		if not saved then return done(false, save_error) end
		done(true, nil, true)
	end)
end

local function fetch_release(item, release, done)
	local urls = { release.url }
	if release.release and release.release ~= release.url then
		urls[#urls + 1] = release.release
	end

	local function try_url(index, previous_error)
		if not urls[index] then return done(nil, previous_error or "download failed") end
		fetch(urls[index], function(text, err)
			local valid
			if item.manual then
				valid = text and text:sub(1, 2) == "PK"
			else
				valid = validate_script(text, release.version, item.version_marker)
			end
			if valid then return done(text) end
			try_url(index + 1, err or "downloaded file failed validation")
		end)
	end

	try_url(1)
end

local function install_selected()
	local requested_item = selected()
	if working or not requested_item or not selected_release then return end
	if requested_item.manual then return set_status("sm_status_error", "use the ZIP download button") end
	working = true
	set_actions(false, false)
	local dependency_installed = false
	load_catalog(function(manifest, err)
		if not manifest then
			working = false
			set_actions(true, false)
			return set_status("sm_status_error", err)
		end
		if selected() ~= requested_item then
			working = false
			return
		end
		local release, release_error = selected_manifest(manifest, requested_item)
		if not release then
			working = false
			set_actions(true, false)
			return set_status("sm_status_error", release_error)
		end
		local function after_dependency(ok, dependency_error, installed_dependency)
			if not ok then
				working = false
				set_actions(true, false)
				return set_status("sm_status_error", dependency_error)
			end
			dependency_installed = installed_dependency == true
			if requested_item.needs_localizer then
				localizer_installed = true
			end
			fetch_release(requested_item, release, function(text, fetch_error)
				if not text then
					working = false
					set_actions(true, false)
					if dependency_installed then reload_at = os.clock() + 1.0 end
					return set_status("sm_status_error", fetch_error)
				end
				local path = selected_path(requested_item)
				if not path then
					working = false
					if dependency_installed then reload_at = os.clock() + 1.0 end
					return set_status("sm_status_error", "cheat directory is unavailable")
				end
				local saved, save_error = write_download(path, text)
				working = false
				if not saved then
					set_actions(true, false)
					if dependency_installed then reload_at = os.clock() + 1.0 end
					return set_status("sm_status_error", save_error)
				end
				set_status("sm_status_installed", release.version)
				reload_at = os.clock() + 1.0
			end)
		end
		if requested_item.needs_localizer then
			install_localizer(manifest, after_dependency)
		else
			after_dependency(true)
		end
	end)
end

local function download_manual()
	local requested_item = selected()
	if working or not requested_item or not requested_item.manual or not selected_release then return end
	local release = selected_release
	working = true
	set_actions(false, false)
	fetch_release(requested_item, release, function(text, err)
		if not text then
			working = false
			set_actions(false, true)
			return set_status("sm_status_error", err)
		end
		local path = selected_path(requested_item)
		if not path then
			working = false
			return set_status("sm_status_error", "cheat directory is unavailable")
		end
		local saved, save_error = write_download(path, text)
		working = false
		if not saved then
			set_actions(false, true)
			return set_status("sm_status_error", save_error)
		end
		set_status("sm_status_manual", release.version)
	end)
end

local function install_localizer_button()
	if working then return end
	working = true
	set_actions(false, false)
	load_catalog(function(manifest, err)
		if not manifest then
			working = false
			return set_status("sm_status_error", err)
		end
		install_localizer(manifest, function(ok, dependency_error, installed_dependency)
			working = false
			if not ok then return set_status("sm_status_error", dependency_error) end
			if installed_dependency then
				localizer_installed = true
				set_status("sm_status_localizer_installed")
				reload_at = os.clock() + 1.0
			else
				localizer_installed = true
				set_status("sm_status_localizer")
			end
		end)
	end)
end

local function selection_changed()
	show_cached_selection()
end

local script = {}

----------------------------------------------------------------------
-- Visual layer
----------------------------------------------------------------------

local ROUND = Enum.DrawFlags.RoundCornersAll
local ROUND_TOP = Enum.DrawFlags.RoundCornersTop
local ROUND_BOTTOM = Enum.DrawFlags.RoundCornersBottom
local ROUND_NONE = Enum.DrawFlags.RoundCornersNone

local K = {
	W = 960,
	H = 640,
	TB = 52,
	FT = 64,
	P = 14,
	SIDE = 292,
	WHEEL = 80,
	TIP_DELAY = 0.35,
	SCALES = { 80, 90, 100, 110, 125, 150 },
	GLYPH = {
		gear = "\u{f013}", close = "\u{f00d}", check = "\u{f00c}", arrow_down = "\u{f063}",
		alert = "\u{f06a}", info = "\u{f05a}", palette = "\u{f53f}", moon = "\u{f186}",
		compress = "\u{f066}", blur = "\u{f042}", drop = "\u{f043}", eye = "\u{f06e}",
		expand = "\u{f424}", shield = "\u{f3ed}", bag = "\u{f290}", pointer = "\u{f245}",
		bolt = "\u{f0e7}", gift = "\u{f06b}", hand = "\u{f25a}", percent = "\u{f295}",
		users = "\u{f0c0}", wrench = "\u{f0ad}", lang = "\u{f1ab}", chevron = "\u{f054}",
		search = "\u{f002}",
	},
	THEMES = {
		{ id = "graphite", main = { 15, 15, 16 }, side = { 22, 22, 24 }, bar = { 26, 26, 28 }, card = { 28, 28, 30 }, raised = { 44, 44, 46 }, pill = { 58, 58, 60 }, thumb = { 99, 99, 102 } },
		{ id = "midnight", main = { 11, 14, 24 }, side = { 16, 20, 33 }, bar = { 20, 25, 40 }, card = { 22, 27, 43 }, raised = { 36, 44, 66 }, pill = { 49, 58, 84 }, thumb = { 84, 96, 130 } },
		{ id = "warm", main = { 19, 16, 14 }, side = { 27, 23, 20 }, bar = { 31, 27, 23 }, card = { 34, 29, 25 }, raised = { 52, 45, 39 }, pill = { 66, 58, 51 }, thumb = { 108, 97, 88 } },
		{ id = "purple", main = { 16, 12, 24 }, side = { 23, 17, 34 }, bar = { 27, 20, 40 }, card = { 30, 22, 44 }, raised = { 48, 36, 68 }, pill = { 62, 48, 86 }, thumb = { 104, 86, 136 } },
		{ id = "red", main = { 22, 11, 13 }, side = { 31, 16, 18 }, bar = { 36, 19, 22 }, card = { 40, 21, 24 }, raised = { 60, 34, 38 }, pill = { 76, 45, 50 }, thumb = { 124, 84, 90 } },
		{ id = "oled", main = { 0, 0, 0 }, side = { 8, 8, 9 }, bar = { 12, 12, 13 }, card = { 17, 17, 18 }, raised = { 34, 34, 36 }, pill = { 48, 48, 50 }, thumb = { 92, 92, 96 } },
	},
	ACCENTS = {
		{ id = "red", c = PAL.red },
		{ id = "teal", c = PAL.teal },
		{ id = "blue", c = PAL.blue },
		{ id = "purple", c = PAL.purple },
		{ id = "orange", c = PAL.orange },
		{ id = "green", c = PAL.green },
	},
	ACCENT_ALPHA = { accent = 255, select = 51, accent_soft = 36, accent_pill = 90 },
	DEFAULTS = { blur = 1, blur_power = 70, opacity = 92, scale = 100, compact = 0, theme = "graphite", accent = "teal" },
}

local C = {
	main = { 15, 15, 16 }, side = { 22, 22, 24 }, bar = { 26, 26, 28 }, card = { 28, 28, 30 },
	raised = { 44, 44, 46 }, pill = { 58, 58, 60 }, thumb = { 99, 99, 102 },
	text = { 255, 255, 255 }, text2 = { 235, 235, 245, 153 }, text3 = { 235, 235, 245, 77 }, text4 = { 235, 235, 245, 46 },
	sep = { 84, 84, 88, 153 }, sep2 = { 84, 84, 88, 87 },
	fill2 = { 120, 120, 128, 82 }, fill3 = { 118, 118, 128, 61 }, fill4 = { 118, 118, 128, 46 },
	hover = { 255, 255, 255, 9 }, glow = { 255, 255, 255, 28 }, press = { 0, 0, 0, 46 },
	border = { 255, 255, 255, 20 }, outline = { 255, 255, 255, 26 }, black = { 0, 0, 0 },
	sb = { 235, 235, 245, 77 }, sb_hover = { 235, 235, 245, 140 },
	accent = { 54, 186, 169 }, accent_soft = { 54, 186, 169, 36 }, accent_pill = { 54, 186, 169, 90 }, select = { 54, 186, 169, 51 },
}

local function clamp(v, a, b) return v < a and a or (v > b and b or v) end
local function ease_out(t) return 1 - (1 - t) * (1 - t) end
local function ease_in_out(t)
	if t < 0.5 then return 2 * t * t end
	return 1 - ((-2 * t + 2) ^ 2) / 2
end

local S = {
	open = false,
	alpha = 0,
	now = os.clock(),
	dt = 0.016,
	tweens = {},
	settings = false,
	last_settings = false,
	fade_t = 1,
	detail_t = 1,
	wx = nil,
	wy = nil,
	press = nil,
	drag = nil,
	slide = nil,
	sb_drag = nil,
	scroll = 0,
	scroll_to = 0,
	content_h = 0,
	view_h = 0,
	sb_until = 0,
	tip = nil,
	tip_shown = nil,
	tip_since = 0,
	pill = {},
}

----------------------------------------------------------------------
-- Settings (persisted in Config, same keys as before)
----------------------------------------------------------------------

local SET = {}

local function find_id(list, id)
	for _, entry in ipairs(list) do
		if entry.id == id then return entry end
	end
	return list[1]
end

local function nearest_scale(value)
	local best = K.SCALES[1]
	for _, option in ipairs(K.SCALES) do
		if math.abs(option - value) < math.abs(best - value) then best = option end
	end
	return best
end

local function load_settings()
	local d = K.DEFAULTS
	SET.blur = Config.ReadInt("script_manager", "blur", d.blur) ~= 0 and 1 or 0
	SET.blur_power = clamp(Config.ReadInt("script_manager", "blur_power", d.blur_power), 10, 100)
	SET.opacity = clamp(Config.ReadInt("script_manager", "opacity", d.opacity), 45, 100)
	SET.scale = nearest_scale(Config.ReadInt("script_manager", "ui_scale",
		Config.ReadInt("script_manager", "scale", d.scale)))
	SET.compact = Config.ReadInt("script_manager", "compact", d.compact) ~= 0 and 1 or 0
	SET.theme = find_id(K.THEMES, Config.ReadString("script_manager", "theme", d.theme)).id
	SET.accent = find_id(K.ACCENTS, Config.ReadString("script_manager", "accent", d.accent)).id
end

local function save_settings()
	Config.WriteInt("script_manager", "blur", SET.blur)
	Config.WriteInt("script_manager", "blur_power", SET.blur_power)
	Config.WriteInt("script_manager", "opacity", SET.opacity)
	Config.WriteInt("script_manager", "ui_scale", SET.scale)
	Config.WriteInt("script_manager", "compact", SET.compact)
	Config.WriteString("script_manager", "theme", SET.theme)
	Config.WriteString("script_manager", "accent", SET.accent)
end

----------------------------------------------------------------------
-- Theme (animated palette transitions)
----------------------------------------------------------------------

local theme = { from = {}, to = {}, k = 1 }

function theme.target()
	local base = find_id(K.THEMES, SET.theme)
	local pick = find_id(K.ACCENTS, SET.accent)
	local out = {}
	for name, c in pairs(base) do
		if name ~= "id" then out[name] = { c[1], c[2], c[3], c[4] or 255 } end
	end
	for name, alpha in pairs(K.ACCENT_ALPHA) do
		out[name] = { pick.c[1], pick.c[2], pick.c[3], alpha }
	end
	return out
end

function theme.tick(dt)
	if theme.k >= 1 then return end
	theme.k = math.min(1, theme.k + dt / 0.3)
	local e = ease_in_out(theme.k)
	for name, c in pairs(theme.to) do
		local from, dest = theme.from[name], C[name]
		for i = 1, 4 do dest[i] = from[i] + (c[i] - from[i]) * e end
	end
end

function theme.set(instant)
	theme.to, theme.from, theme.k = theme.target(), {}, 0
	for name in pairs(theme.to) do
		local d = C[name]
		theme.from[name] = { d[1], d[2], d[3], d[4] or 255 }
	end
	if instant then theme.tick(0.3) end
end

local function reset_settings()
	local d = K.DEFAULTS
	SET.blur, SET.blur_power, SET.opacity = d.blur, d.blur_power, d.opacity
	SET.scale, SET.compact, SET.theme, SET.accent = d.scale, d.compact, d.theme, d.accent
	save_settings()
	theme.set()
end

load_settings()
theme.set(true)

----------------------------------------------------------------------
-- Animation + hit-testing
----------------------------------------------------------------------

local anim = {}

function anim.tween(key, target, time, curve)
	local t = S.tweens[key]
	if not t then
		t = { from = target, to = target, v = target, k = 1 }
		S.tweens[key] = t
	end
	if t.to ~= target then t.from, t.to, t.k = t.v, target, 0 end
	if t.k < 1 then
		t.k = math.min(1, t.k + S.dt / time)
		t.v = t.from + (t.to - t.from) * (curve or ease_out)(t.k)
	else
		t.v = t.to
	end
	return t.v
end

local HOVER_KEY = setmetatable({}, { __index = function(t, id)
	local v = "hv:" .. id
	t[id] = v
	return v
end })

function anim.hover(id, on)
	return anim.tween(HOVER_KEY[id], on and 1 or 0, 0.12)
end

local hit = { list = {}, prev = {}, hover = nil, clip = nil }

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
	if S.press and hit.hover ~= S.press.id then hit.hover = nil end
end

function hit.is(id) return hit.hover == id end

function hit.at(mx, my)
	for i = #hit.list, 1, -1 do
		local h = hit.list[i]
		if mx >= h[1] and mx < h[3] and my >= h[2] and my < h[4] then return h end
	end
	return nil
end

----------------------------------------------------------------------
-- Fonts / drawing helpers
----------------------------------------------------------------------

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
	if not asset.fonts.icon then
		asset.fonts.icon = Render.LoadFont("FontAwesomeEx", Enum.FontCreate.FONTFLAG_ANTIALIAS, 400)
	end
	return asset.fonts.icon
end

function asset.size(font, px, str)
	local by_font = asset.sizes[font]
	if not by_font then
		by_font = {}
		asset.sizes[font] = by_font
	end
	local by_px = by_font[px]
	if not by_px then
		by_px = {}
		by_font[px] = by_px
	end
	local v = by_px[str]
	if not v then
		v = Render.TextSize(font, px, str)
		by_px[str] = v
	end
	return v
end

local function F(weight) return asset.font(weight) end

local g = {
	x = 0, y = 0, s = 1, a = 1, cmp = 0,
	vcache = {}, vc_n = 0, ccache = {}, cc_n = 0,
	fits = {}, fit_n = 0, wraps = {}, wrap_n = 0,
}

function hit.add(x, y, w, h, id, on)
	local x1, y1, x2, y2 = g.x + x * g.s, g.y + y * g.s, g.x + (x + w) * g.s, g.y + (y + h) * g.s
	if hit.clip then
		x1, y1 = math.max(x1, hit.clip[1]), math.max(y1, hit.clip[2])
		x2, y2 = math.min(x2, hit.clip[3]), math.min(y2, hit.clip[4])
		if x2 <= x1 or y2 <= y1 then return end
	end
	hit.list[#hit.list + 1] = { x1, y1, x2, y2, id, on or {} }
end

function g.lay(n, c) return n + (c - n) * g.cmp end
function g.px(x) return math.floor(g.x + x * g.s + 0.5) end
function g.py(y) return math.floor(g.y + y * g.s + 0.5) end

function g.pt(x, y)
	local key = (x + 32768) * 65536 + y + 32768
	local v = g.vcache[key]
	if v then return v end
	if g.vc_n >= 20000 then g.vcache, g.vc_n = {}, 0 end
	v = Vec2(x, y)
	g.vcache[key], g.vc_n = v, g.vc_n + 1
	return v
end

function g.v(x, y) return g.pt(g.px(x), g.py(y)) end
function g.size(x, y, w, h) return g.pt(g.px(x + w) - g.px(x), g.py(y + h) - g.py(y)) end
function g.fs(size) return math.max(1, math.floor(size * g.s + 0.5)) end

function g.col(c, a)
	local r, gr, b = math.floor(c[1] + 0.5), math.floor(c[2] + 0.5), math.floor(c[3] + 0.5)
	local al = clamp(math.floor((c[4] or 255) * (a or 1) * g.a + 0.5), 0, 255)
	local key = ((r * 256 + gr) * 256 + b) * 256 + al
	local v = g.ccache[key]
	if v then return v end
	if g.cc_n >= 8000 then g.ccache, g.cc_n = {}, 0 end
	v = Color(clamp(r, 0, 255), clamp(gr, 0, 255), clamp(b, 0, 255), al)
	g.ccache[key], g.cc_n = v, g.cc_n + 1
	return v
end

function g.rect(x, y, w, h, c, r, a, flags)
	Render.FilledRect(g.v(x, y), g.v(x + w, y + h), g.col(c, a), (r or 0) * g.s, flags or ROUND)
end

function g.frame(x, y, w, h, c, r, a, t)
	Render.Rect(g.v(x, y), g.v(x + w, y + h), g.col(c, a), (r or 0) * g.s, ROUND, (t or 1) * g.s)
end

function g.glass(x, y, w, h, r)
	local blur = SET.blur == 1
	local power = SET.blur_power / 100
	local k = g.a ^ 4
	if blur and k > 0.01 then
		Render.Blur(g.v(x, y), g.v(x + w, y + h), power * 2 * k, k, r * g.s, ROUND)
	end
	local alpha = SET.opacity / 100
	if blur then alpha = alpha * (1 - 0.3 * power) end
	g.rect(x, y, w, h, C.main, r, alpha)
end

function g.inset() return math.max(1, math.floor(2 * g.s + 0.5)) end

function g.thumb(x, y, w, h, from, to, c, r, a)
	local x1, y1, x2, y2, i = g.px(x), g.py(y), g.px(x + w), g.py(y + h), g.inset()
	local l = x1 + i
	local k = (x2 - i - l) / (w - 4)
	Render.FilledRect(g.pt(l + math.floor(from * k + 0.5), y1 + i), g.pt(l + math.floor(to * k + 0.5), y2 - i),
		g.col(c, a), r * g.s, ROUND)
end

function g.hair() return math.max(1, math.floor(g.s)) end

function g.hl(x, y, w, c, a)
	local y0 = g.py(y)
	Render.FilledRect(g.pt(g.px(x), y0), g.pt(g.px(x + w), y0 + g.hair()), g.col(c, a))
end

function g.vl(x, y, h, c, a)
	local x0 = g.px(x)
	Render.FilledRect(g.pt(x0, g.py(y)), g.pt(x0 + g.hair(), g.py(y + h)), g.col(c, a))
end

function g.vr(x, cy, h, a) g.vl(x, cy - h / 2, h, C.sep, a) end

function g.width(font, size, str)
	return asset.size(font, g.fs(size), str).x / g.s
end

function g.text(font, size, str, x, cy, c, a, align)
	local px = g.fs(size)
	local ts = asset.size(font, px, str)
	local tx = g.x + x * g.s
	if align == "r" then tx = tx - ts.x elseif align == "c" then tx = tx - ts.x / 2 end
	Render.Text(font, px, str, g.pt(math.floor(tx + 0.5), math.floor(g.y + cy * g.s - ts.y / 2 + 0.5)), g.col(c, a))
	return ts.x / g.s
end

function g.glyph(name, size, x, cy, c, a, align)
	return g.text(asset.icons(), size, K.GLYPH[name], x, cy, c, a, align or "c")
end

function g.clip(x, y, w, h) Render.PushClip(g.v(x, y), g.v(x + w, y + h), true) end
function g.unclip() Render.PopClip() end

function g.fit(weight, size, str, max_w)
	local key = localization.GetLanguage() .. ":" .. weight .. ":" .. size .. ":" .. math.floor(max_w) .. ":" .. str
	local out = g.fits[key]
	if out then return out end
	local font = F(weight)
	out = str
	if g.width(font, size, str) > max_w then
		local chars = {}
		for _, code in utf8.codes(str) do chars[#chars + 1] = utf8.char(code) end
		out = "…"
		for n = #chars - 1, 1, -1 do
			local candidate = table.concat(chars, "", 1, n):gsub("%s+$", "") .. "…"
			if g.width(font, size, candidate) <= max_w then
				out = candidate
				break
			end
		end
	end
	if g.fit_n >= 600 then g.fits, g.fit_n = {}, 0 end
	g.fits[key], g.fit_n = out, g.fit_n + 1
	return out
end

function g.wrap(weight, size, str, max_w, max_lines)
	local key = localization.GetLanguage() .. ":" .. weight .. ":" .. size .. ":" .. math.floor(max_w) .. ":"
		.. tostring(max_lines) .. ":" .. str
	local out = g.wraps[key]
	if out then return out end
	local font = F(weight)
	local words = {}
	for word in str:gmatch("%S+") do words[#words + 1] = word end
	local lines, current, i, cut = {}, "", 1, false
	while i <= #words do
		local word = words[i]
		local candidate = current == "" and word or (current .. " " .. word)
		if current ~= "" and g.width(font, size, candidate) > max_w then
			lines[#lines + 1] = current
			current = ""
			if max_lines and #lines >= max_lines then
				cut = true
				break
			end
		else
			current = candidate
			i = i + 1
		end
	end
	if not cut and current ~= "" then lines[#lines + 1] = current end
	for n = 1, #lines do
		local line = lines[n]
		if cut and n == #lines then line = line .. "…" end
		lines[n] = g.fit(weight, size, line, max_w)
	end
	if g.wrap_n >= 300 then g.wraps, g.wrap_n = {}, 0 end
	g.wraps[key], g.wrap_n = lines, g.wrap_n + 1
	return lines
end

----------------------------------------------------------------------
-- Status helpers
----------------------------------------------------------------------

local STATUS_COLOR = { current = PAL.green, available = PAL.orange, manual = PAL.cyan, error = PAL.red }

local function count_status(name)
	local n = 0
	for _, item in ipairs(items) do
		local cached = cached_releases[item.id]
		if cached and cached.status == name then n = n + 1 end
	end
	return n
end

local function row_summary(item)
	local cached = cached_releases[item.id]
	if not cached then return L("sm_panel_state_unknown"), C.text3, PAL.gray end
	if cached.status == "available" then
		return string.format(L("sm_row_update"), cached.version), PAL.orange, PAL.orange
	elseif cached.status == "current" then
		return L("sm_panel_state_current"), C.text3, PAL.green
	elseif cached.status == "manual" then
		return L("sm_panel_state_manual"), C.text3, PAL.cyan
	elseif cached.status == "error" then
		return L("sm_panel_state_error"), PAL.red, PAL.red
	end
	return L("sm_panel_state_unknown"), C.text3, PAL.gray
end

local function badge_for(item, cached)
	if working then return L("sm_panel_checking"), C.accent end
	if cached and cached.status == "error" then return L("sm_panel_error_badge"), PAL.red end
	if item.manual then return L("sm_panel_manual_badge"), PAL.yellow end
	if can_install then return L("sm_panel_update_badge"), PAL.orange end
	if cached and cached.status == "current" then return L("sm_panel_current_badge"), PAL.green end
	if selected_release then return L("sm_panel_cached"), PAL.gray end
	return L("sm_panel_not_checked"), PAL.gray
end

local function panel_status_text()
	local message = L(panel.status_key or "sm_status_idle")
	if panel.status_value ~= nil then
		message = string.format(message, tostring(panel.status_value))
	end
	return message
end

local function activity_kind()
	if working then return "work" end
	local key = panel.status_key or ""
	if key:find("error", 1, true) then return "error" end
	if key == "sm_status_installed" or key == "sm_status_manual" or key == "sm_status_localizer_installed"
		or key == "sm_status_localizer" or key == "sm_status_current" or key == "sm_status_cache_current"
		or key == "sm_status_checked"
	then
		return "ok"
	end
	if key == "sm_status_available" or key == "sm_status_cache_available" then return "update" end
	return "info"
end

local function select_panel_item(index)
	if not items[index] or index == selected_index then return end
	selected_index = index
	Config.WriteInt("script_manager", "selected_index", selected_index)
	S.detail_t = 0
	selection_changed()
end

local view = {}

local function hidden(y, h)
	return S.vis_top ~= nil and (y + h < S.vis_top or y > S.vis_bottom)
end

function view.hint(id, text)
	if hit.is(id) then S.tip = text end
end

----------------------------------------------------------------------
-- Reusable widgets
----------------------------------------------------------------------

-- Right-aligned button. Returns the left edge so buttons can be chained.
function view.button(id, label, glyph, right, y, h, kind, enabled, on_click)
	local fw = F(500)
	local tw = g.width(fw, 14, label)
	local gw = glyph and 22 or 0
	local w = tw + gw + 36
	local x = right - w
	local hot = enabled and hit.is(id)
	local k = anim.hover(id, hot)
	local base = kind == "primary" and C.accent or C.fill2
	g.rect(x, y, w, h, base, 9, enabled and 1 or (kind == "primary" and 0.35 or 0.55))
	if k > 0 then g.rect(x, y, w, h, C.glow, 9, k) end
	if hot and S.press and S.press.id == id then g.rect(x, y, w, h, C.press, 9) end
	local ta = enabled and 1 or 0.45
	if glyph then g.glyph(glyph, 13, x + 18 + 4, y + h / 2, C.text, ta) end
	g.text(fw, 14, label, x + 18 + gw, y + h / 2, C.text, ta)
	if enabled then hit.add(x, y, w, h, id, { click = on_click }) end
	return x
end

function view.chip(x, cy, glyph, label, color)
	local fw = F(500)
	local tw = g.width(fw, 12, label)
	local gw = glyph and 18 or 0
	local w = tw + gw + 20
	g.rect(x, cy - 13, w, 26, C.fill4, 8)
	if glyph then g.glyph(glyph, 11, x + 16, cy, color or C.text2) end
	g.text(fw, 12, label, x + 10 + gw, cy, color or C.text2)
	return w
end

function view.spinner(cx, cy, r, c, a)
	Render.Circle(g.v(cx, cy), r * g.s, g.col(c, 0.3 * (a or 1)), 2 * g.s)
	Render.Circle(g.v(cx, cy), r * g.s, g.col(c, a or 1), 2 * g.s, (S.now * 400) % 360, 0.25, true)
end

----------------------------------------------------------------------
-- Title bar
----------------------------------------------------------------------

function view.icon_button(name, x, id, on_click, active, tip)
	local k = anim.hover(id, hit.is(id) or active)
	if k > 0 then g.rect(x, 12, 32, 28, active and C.fill3 or C.fill4, 6, k) end
	g.glyph(name, 16, x + 16, 26, (hit.is(id) or active) and C.text or C.text2)
	hit.add(x, 12, 32, 28, id, { click = on_click })
	if tip then view.hint(id, tip) end
end

function view.status_pill(right)
	local glyph, label, bg, fg
	local spin = false
	if working then
		label, bg, fg, spin = L("sm_panel_checking"), C.accent_pill, C.text, true
	else
		local updates = count_status("available")
		if updates > 0 then
			glyph, label, bg, fg = "arrow_down", string.format(L("sm_pill_updates"), updates), C.accent, C.text
		elseif count_status("error") > 0 then
			glyph, label, bg, fg = "alert", L("sm_panel_error_badge"), PAL.red, PAL.red
		elseif last_checked_at > 0 then
			glyph, label, bg, fg = "check", L("sm_pill_current"), PAL.green, PAL.green
		end
	end
	local shown = label ~= nil
	if shown then
		S.pill.glyph, S.pill.label, S.pill.bg, S.pill.fg, S.pill.spin = glyph, label, bg, fg, spin
		S.pill.soft = bg == PAL.red or bg == PAL.green
	end
	local a = anim.tween("pill_a", shown and 1 or 0, 0.2)
	local p = S.pill
	if a <= 0.01 or not p.label then return right end
	local fw = F(500)
	local w = 11 + 18 + 7 + g.width(fw, 13, p.label) + 13
	local x = right - 8 - w
	g.rect(x, 12, w, 28, p.bg, 14, p.soft and 0.22 * a or a)
	if p.spin then
		view.spinner(x + 20, 26, 5.5, C.text, a)
	elseif p.glyph then
		g.glyph(p.glyph, 13, x + 20, 26, p.fg, a)
	end
	g.text(fw, 13, p.label, x + 36, 26, p.fg, a)
	return x
end

function view.titlebar()
	g.rect(0, 0, K.W, K.TB, C.bar, 16, 1, ROUND_TOP)
	g.hl(0, K.TB - 1, K.W, C.black)
	hit.add(0, 0, K.W, K.TB, "drag", { down = function(mx, my)
		S.drag = { mx = mx, my = my, wx = S.wx, wy = S.wy }
	end })

	Render.FilledCircle(g.v(32, 26), 11 * g.s, g.col(C.accent))
	Render.FilledCircle(g.v(32, 26), 5 * g.s, g.col(C.bar))
	local x = 54
	x = x + g.text(F(700), 16, L("sm_panel_title"), x, 26, C.text) + 14
	g.vr(x, 26, 13)
	g.text(F(500), 11, L("sm_panel_subtitle"), x + 13, 26, C.text2)

	local right = K.W - K.P - 32
	view.icon_button("close", right, "tb_close", function()
		S.open, S.drag, S.slide, S.sb_drag = false, nil, nil, nil
	end, false, L("sm_tip_close"))
	right = right - 40
	view.icon_button("gear", right, "tb_gear", function()
		S.settings = not S.settings
	end, S.settings, L(S.settings and "sm_tip_back" or "sm_tip_settings"))
	view.status_pill(right)
end

----------------------------------------------------------------------
-- Main view: sidebar + detail
----------------------------------------------------------------------

function view.sidebar(x, y, w, h)
	g.rect(x, y, w, h, C.card, 14)
	g.text(F(700), 11, L("sm_panel_scripts"), x + 18, y + 22, C.text3)
	local count = tostring(#items)
	local cw = g.width(F(600), 11, count) + 14
	g.rect(x + w - 16 - cw, y + 13, cw, 18, C.fill3, 9)
	g.text(F(600), 11, count, x + w - 16 - cw / 2, y + 22, C.text2, 1, "c")
	g.hl(x + 16, y + 40, w - 32, C.sep2)

	local rh, step = g.lay(46, 36), g.lay(50, 40)
	step = math.min(step, math.floor((h - 52) / #items))
	rh = math.min(rh, step - 2)
	local ts = g.lay(32, 24)
	for i, item in ipairs(items) do
		local ry = y + 46 + (i - 1) * step
		local id = "row" .. i
		local rx, rw = x + 8, w - 16
		local active = i == selected_index
		local k = anim.hover(id, hit.is(id))
		local sel = anim.tween(id .. "_sel", active and 1 or 0, 0.15)
		if k > 0 and sel < 1 then g.rect(rx, ry, rw, rh, C.hover, 10, k * (1 - sel)) end
		if sel > 0 then g.rect(rx, ry, rw, rh, C.select, 10, sel) end

		local summary, summary_color, dot_color = row_summary(item)
		g.rect(rx + 8, ry + (rh - ts) / 2, ts, ts, item.tile, 8)
		g.glyph(item.glyph, g.lay(15, 12), rx + 8 + ts / 2, ry + rh / 2, C.text)

		local tx = rx + 8 + ts + 11
		local max_w = rw - (tx - rx) - 28
		local name_cy = ry + rh / 2 - 8 * (1 - g.cmp)
		g.text(F(active and 700 or 600), 13, g.fit(active and 700 or 600, 13, L(item.key), max_w), tx, name_cy,
			active and C.text or { 235, 235, 245, 220 })
		local sub_a = 1 - g.cmp
		if sub_a > 0.02 then
			g.text(F(400), 11, g.fit(400, 11, summary, max_w), tx, ry + rh / 2 + 9, summary_color, sub_a)
		end
		Render.FilledCircle(g.v(rx + rw - 14, ry + rh / 2), 4 * g.s, g.col(dot_color))
		hit.add(rx, ry, rw, rh, id, { click = function() select_panel_item(i) end })
	end
end

function view.hero(x, y, w, h, item, cached)
	g.rect(x, y, w, h, C.card, 14)
	local ts = 64
	g.rect(x + 18, y + 18, ts, ts, item.tile, 16)
	g.glyph(item.glyph, 26, x + 18 + ts / 2, y + 18 + ts / 2, C.text)
	local tx = x + 18 + ts + 16

	local badge_text, badge_color = badge_for(item, cached)
	local bw = g.width(F(700), 11, badge_text) + 22
	g.rect(x + w - 18 - bw, y + 22, bw, 24, badge_color, 12, 0.22)
	g.text(F(700), 11, badge_text, x + w - 18 - bw / 2, y + 34, badge_color, 1, "c")

	local title_w = w - (tx - x) - 18 - bw - 14
	g.text(F(700), 22, g.fit(700, 22, L(item.key), title_w), tx, y + 34, C.text)
	local lines = g.wrap(400, 13, L(item.description_key), w - (tx - x) - 18, 2)
	for i, line in ipairs(lines) do
		g.text(F(400), 13, line, tx, y + 62 + (i - 1) * 19, C.text2)
	end

	g.hl(x + 18, y + h - 52, w - 36, C.sep2)
	local cx, cy = x + 18, y + h - 26
	cx = cx + view.chip(cx, cy, nil, item.file) + 8
	if item.manual then
		cx = cx + view.chip(cx, cy, "arrow_down", L("sm_chip_zip")) + 8
	end
	if item.needs_localizer then
		view.chip(cx, cy, "lang", L("sm_chip_localizer"), localizer_installed and PAL.green or PAL.orange)
	end
end

function view.versions(x, y, w, h, item, cached)
	local gap = 12
	local cw = (w - gap) / 2
	local function card(cx, label, value, color, outline)
		g.rect(cx, y, cw, h, C.card, 14)
		if outline then g.frame(cx, y, cw, h, outline, 14, 0.6, 1.5) end
		g.text(F(700), 11, label, cx + 20, y + 28, C.text3)
		if value:match("^v%d") then
			g.text(F(700), 28, value, cx + 20, y + 64, color or C.text)
		else
			g.text(F(600), 17, g.fit(600, 17, value, cw - 40), cx + 20, y + 64, color or C.text2)
		end
	end
	card(x, L("sm_panel_installed"), installed_version and ("v" .. installed_version) or L("sm_panel_not_detected"))
	local latest_color = can_install and PAL.orange or ((cached and cached.status == "current") and PAL.green or nil)
	card(x + cw + gap, L("sm_panel_latest"),
		selected_release and ("v" .. selected_release.version) or L("sm_panel_not_checked"),
		latest_color, can_install and PAL.orange or nil)
	local mx, my = x + cw + gap / 2, y + h / 2
	Render.FilledCircle(g.v(mx, my), 13 * g.s, g.col(C.raised))
	Render.Circle(g.v(mx, my), 13 * g.s, g.col(C.outline), 1 * g.s)
	g.glyph("chevron", 10, mx + 1, my, C.text2)
end

function view.activity(x, y, w, h)
	g.rect(x, y, w, h, C.card, 14)
	local kind = activity_kind()
	local tile, glyph = PAL.blue, "info"
	if kind == "error" then
		tile, glyph = PAL.red, "alert"
	elseif kind == "ok" then
		tile, glyph = PAL.green, "check"
	elseif kind == "update" then
		tile, glyph = PAL.orange, "arrow_down"
	elseif kind == "work" then
		tile = C.accent
	end
	g.rect(x + 18, y + 18, 40, 40, tile, 12)
	if kind == "work" then
		view.spinner(x + 38, y + 38, 9, C.text)
	else
		g.glyph(glyph, 16, x + 38, y + 38, C.text)
	end
	local tx = x + 18 + 40 + 16
	g.text(F(700), 11, L("sm_panel_status"), tx, y + 27, C.text3)
	local lines = g.wrap(500, 14, panel_status_text(), w - (tx - x) - 20, 2)
	for i, line in ipairs(lines) do
		g.text(F(500), 14, line, tx, y + 51 + (i - 1) * 20, kind == "error" and PAL.red or C.text)
	end
	if kind == "work" then
		local bx, bw = x + 18, w - 36
		g.rect(bx, y + h - 20, bw, 4, C.fill2, 2)
		local t = (S.now * 0.8) % 1
		local seg = bw * 0.3
		local sx = bx + (bw + seg) * t - seg
		local x0, x1 = math.max(bx, sx), math.min(bx + bw, sx + seg)
		if x1 > x0 then g.rect(x0, y + h - 20, x1 - x0, 4, C.accent, 2) end
	end
end

function view.library(x, y, w, h)
	g.rect(x, y, w, h, C.card, 14)
	local ts = 40
	g.rect(x + 18, y + (h - ts) / 2, ts, ts, localizer_installed and PAL.green or PAL.orange, 12)
	g.glyph("lang", 17, x + 18 + ts / 2, y + h / 2, C.text)
	local tx = x + 18 + ts + 14
	local right = x + w - 18
	local left_edge
	if localizer_installed then
		local label = L("sm_panel_localizer_ready")
		local bw = g.width(F(600), 13, label) + 18 + 30
		g.rect(right - bw, y + h / 2 - 16, bw, 32, PAL.green, 16, 0.2)
		g.glyph("check", 12, right - bw + 20, y + h / 2, PAL.green)
		g.text(F(600), 13, label, right - bw + 36, y + h / 2, PAL.green)
		left_edge = right - bw
	else
		left_edge = view.button("localizer", L("sm_panel_localizer_button"), "arrow_down", right, y + h / 2 - 17, 34,
			"secondary", not working, function()
				if not localizer_installed and not working then install_localizer_button() end
			end)
	end
	local text_w = left_edge - 14 - tx
	g.text(F(600), 14, L("sm_panel_localizer_title"), tx, y + h / 2 - 10, C.text)
	g.text(F(400), 12, g.fit(400, 12, L("sm_panel_localizer_desc"), text_w), tx, y + h / 2 + 11, C.text3)
end

function view.detail(x, y, w, h)
	local item = selected()
	if not item then return end
	local cached = cached_releases[item.id]
	local base = g.a
	g.a = base * (0.4 + 0.6 * ease_out(S.detail_t))
	local gap = 12
	local hero_h, ver_h, lib_h = 164, 104, 76
	local act_h = h - hero_h - ver_h - lib_h - gap * 3
	local cy = y
	view.hero(x, cy, w, hero_h, item, cached)
	cy = cy + hero_h + gap
	view.versions(x, cy, w, ver_h, item, cached)
	cy = cy + ver_h + gap
	view.activity(x, cy, w, act_h)
	cy = cy + act_h + gap
	view.library(x, cy, w, lib_h)
	g.a = base
end

function view.main()
	local P = K.P
	local top = K.TB + P
	local bottom = K.H - K.FT - 10
	view.sidebar(P, top, K.SIDE, bottom - top)
	local dx = P + K.SIDE + 12
	view.detail(dx, top, K.W - dx - P, bottom - top)
end

----------------------------------------------------------------------
-- Settings view
----------------------------------------------------------------------

function view.group_header(text, y, a)
	local h = g.lay(38, 34)
	if not hidden(y, h) then g.text(F(700), 17, text, K.P + 4, y + g.lay(16, 14), C.text, a) end
	return h
end

function view.gap() return g.lay(22, 14) end

function view.fold(key, on)
	return anim.tween("fold_" .. key, on and 1 or 0, 0.26, ease_in_out)
end

function view.row_geom(sub)
	local rh, ts = sub and g.lay(50, 46) or g.lay(50, 42), g.lay(30, 26)
	return rh, ts, K.P + ts + 14
end

function view.setting_rows(rows, y, a)
	local x, w = K.P, K.W - 2 * K.P
	local _, ts, tx = view.row_geom()
	local rhs, hs, total = {}, {}, 0
	for n, row in ipairs(rows) do
		rhs[n] = view.row_geom(row.sub)
		hs[n] = math.floor(rhs[n] * (row.fold or 1) + 0.5)
		total = total + hs[n]
	end
	if total <= 0 then return 0 end
	if hidden(y, total) then return total end
	g.rect(x, y, w, total, C.card, 12, a)
	local ry = y
	for n, row in ipairs(rows) do
		local f, rh = row.fold or 1, rhs[n]
		local cy = rh / 2
		if hs[n] > 0 and not hidden(ry, hs[n]) then
			local ra = a * f * f
			if f < 1 then g.clip(x, ry, w, hs[n]) end
			if n > 1 then g.hl(x + tx, ry, w - tx, C.sep2, ra) end
			g.rect(x + K.P, ry + (rh - ts) / 2, ts, ts, row.tile, 8, ra)
			g.glyph(row.glyph, g.lay(16, 14), x + K.P + ts / 2, ry + cy, C.text, ra)
			if row.sub then
				g.text(F(600), 14, row.title, x + tx, ry + cy - g.lay(8, 7), C.text, ra)
				g.text(F(400), 12, row.sub, x + tx, ry + cy + g.lay(9, 8), C.text3, ra)
			else
				g.text(F(600), 14, row.title, x + tx, ry + cy, C.text, ra)
			end
			if row.control and f > 0.98 then
				row.control(x + w - K.P, ry + cy, ra)
			elseif row.control then
				local hold = hit.list
				hit.list = {}
				row.control(x + w - K.P, ry + cy, ra)
				hit.list = hold
			end
			if f < 1 then g.unclip() end
		end
		ry = ry + hs[n]
	end
	return total
end

function view.switch(key)
	return function(right, cy, a)
		local on = SET[key] == 1
		local k = anim.tween("sw" .. key, on and 1 or 0, 0.25, ease_in_out)
		local x = right - 42
		local bg = { 120 + (48 - 120) * k, 120 + (209 - 120) * k, 128 + (88 - 128) * k, 82 + (255 - 82) * k }
		g.rect(x, cy - 13, 42, 26, bg, 13, a)
		local x1, y1, x2, y2 = g.px(x), g.py(cy - 13), g.px(x + 42), g.py(cy + 13)
		local half = (y2 - y1) / 2
		Render.FilledCircle(Vec2(x1 + half + (x2 - x1 - 2 * half) * k, y1 + half), half - g.inset(), g.col(C.text, a))
		hit.add(x, cy - 13, 42, 26, "sw" .. key, { click = function()
			SET[key] = on and 0 or 1
			save_settings()
		end })
	end
end

function view.choice(id, options, current, on_pick)
	return function(right, cy, a)
		local widths, total = {}, 4
		for i, o in ipairs(options) do
			widths[i] = g.width(F(500), 12, o[2]) + 22
			total = total + widths[i]
		end
		local x = right - total
		g.rect(x, cy - 14, total, 28, C.fill3, 8, a)
		local sel_x, sel_w, bx = 2, widths[1], 2
		local found = false
		for i, o in ipairs(options) do
			if o[1] == current then sel_x, sel_w, found = bx, widths[i], true end
			bx = bx + widths[i]
		end
		local tx = anim.tween(id .. "_x", sel_x, 0.28, ease_in_out)
		local tw = anim.tween(id .. "_w", sel_w, 0.28, ease_in_out)
		if found then g.thumb(x, cy - 14, total, 28, tx - 2, tx - 2 + tw, C.thumb, 6, a) end
		bx = x + 2
		for i, o in ipairs(options) do
			local on = o[1] == current
			g.text(F(500), 12, o[2], bx + widths[i] / 2, cy, on and C.text or C.text2, a, "c")
			hit.add(bx, cy - 12, widths[i], 24, id .. i, { click = function() on_pick(o[1]) end })
			bx = bx + widths[i]
		end
	end
end

function view.swatches(right, cy, a)
	local step, r = 30, 9
	local x0 = right - (#K.ACCENTS - 1) * step - r - 4
	for i, acc in ipairs(K.ACCENTS) do
		local cx, id = x0 + (i - 1) * step, "acc_" .. acc.id
		local on = anim.tween(id, SET.accent == acc.id and 1 or 0, 0.2, ease_in_out)
		local ring = math.max(on, anim.hover(id, hit.is(id)) * 0.35)
		if ring > 0 then Render.Circle(g.v(cx, cy), (r + 4) * g.s, g.col(C.text, a * ring), 1.5 * g.s) end
		Render.FilledCircle(g.v(cx, cy), r * g.s, g.col(acc.c, a))
		hit.add(cx - 13, cy - 13, 26, 26, id, { click = function()
			if SET.accent == acc.id then return end
			SET.accent = acc.id
			save_settings()
			theme.set()
		end })
		view.hint(id, L("sm_accent_" .. acc.id))
	end
end

function view.slide_to(mx)
	local s = S.slide
	local v = clamp((mx - s.x) / s.w, 0, 1)
	SET[s.key] = s.min + math.floor((s.max - s.min) * v / 5 + 0.5) * 5
end

function view.slider(key, min, max)
	return function(right, cy, a)
		local tw = 180
		local x = right - tw - 10
		local v = (SET[key] - min) / (max - min)
		local sx, sw = g.x + x * g.s, tw * g.s
		local id = "sl_" .. key
		local hot = hit.is(id) or (S.slide ~= nil and S.slide.key == key)
		g.text(F(600), 13, SET[key] .. "%", x - 18, cy, C.text2, a, "r")
		g.rect(x, cy - 2, tw, 4, C.fill2, 2, a)
		g.rect(x, cy - 2, math.max(4, tw * v), 4, C.accent, 2, a)
		Render.FilledCircle(g.v(x + tw * v, cy), (hot and 11 or 10) * g.s, g.col(C.text, a))
		hit.add(x - 12, cy - 14, tw + 24, 28, id, { down = function(mx)
			S.slide = { key = key, min = min, max = max, x = sx, w = sw }
			view.slide_to(mx)
		end })
	end
end

function view.settings(y, a)
	local h = 0
	local theme_options, scale_options = {}, {}
	for i, t in ipairs(K.THEMES) do theme_options[i] = { t.id, L("sm_theme_" .. t.id) } end
	for i, v in ipairs(K.SCALES) do scale_options[i] = { v, v .. "%" } end

	h = h + view.group_header(L("sm_ui_group"), y + h, a)
	h = h + view.setting_rows({
		{ tile = PAL.indigo, glyph = "moon", title = L("sm_ui_theme"), sub = L("sm_ui_theme_sub"),
			control = view.choice("theme", theme_options, SET.theme, function(v)
				if SET.theme == v then return end
				SET.theme = v
				save_settings()
				theme.set()
			end) },
		{ tile = C.accent, glyph = "palette", title = L("sm_ui_accent"), sub = L("sm_ui_accent_sub"), control = view.swatches },
		{ tile = PAL.teal, glyph = "compress", title = L("sm_ui_compact"), sub = L("sm_ui_compact_tip"), control = view.switch("compact") },
	}, y + h, a) + view.gap()

	h = h + view.group_header(L("sm_ui_window"), y + h, a)
	h = h + view.setting_rows({
		{ tile = PAL.blue, glyph = "blur", title = L("sm_ui_blur"), sub = L("sm_ui_blur_tip"), control = view.switch("blur") },
		{ fold = view.fold("blur", SET.blur == 1), tile = PAL.indigo, glyph = "drop", title = L("sm_ui_blur_power"),
			control = view.slider("blur_power", 10, 100) },
		{ tile = PAL.purple, glyph = "eye", title = L("sm_ui_opacity"), sub = L("sm_ui_opacity_sub"),
			control = view.slider("opacity", 45, 100) },
		{ tile = PAL.orange, glyph = "expand", title = L("sm_ui_scale"), sub = L("sm_ui_scale_sub"),
			control = view.choice("scale", scale_options, SET.scale, function(v)
				SET.scale = v
				save_settings()
			end) },
	}, y + h, a)
	return h
end

function view.scrollbar(top, vh, max_scroll)
	if max_scroll <= 0 then return end
	local x, y, h = K.W - 24, top + 6, vh - 12
	local th = math.max(32, h * h / S.content_h)
	local ty = y + (h - th) * clamp(S.scroll / max_scroll, 0, 1)
	local hover = hit.is("sb") or hit.is("sb_thumb") or S.sb_drag ~= nil
	local k = anim.tween("sb", (hover or S.now < S.sb_until) and 1 or 0, 0.2)
	local wide = anim.tween("sb_w", hover and 1 or 0, 0.15)
	if k > 0 then
		g.rect(x + 2, y, 8, h, { 255, 255, 255, 13 }, 4, k * wide)
		local w = 6 + 2 * wide
		g.rect(x + 10 - w, ty, w, th, hover and C.sb_hover or C.sb, w / 2, k)
	end
	hit.add(x, y, 12, h, "sb", { down = function(mx, my)
		local rel = (my - g.y) / g.s - y - th / 2
		S.scroll_to = clamp(rel / (h - th), 0, 1) * max_scroll
	end })
	hit.add(x, ty, 12, th, "sb_thumb", { down = function(mx, my)
		S.sb_drag = { my = my, scroll = S.scroll, k = max_scroll / math.max(1, h - th) }
	end })
end

function view.settings_content()
	local top, bottom = K.TB, K.H - K.FT
	local vh = bottom - top
	S.view_h = vh
	S.scroll = anim.tween("scroll", S.scroll_to, 0.24)
	hit.add(0, top, K.W, vh, "content", { wheel = function(dir)
		S.scroll_to = clamp(S.scroll_to + dir * K.WHEEL, 0, math.max(0, S.content_h - S.view_h))
		S.sb_until = S.now + 1.2
	end })
	g.clip(0, top, K.W, vh)
	hit.clip = { g.x, g.y + top * g.s, g.x + K.W * g.s, g.y + bottom * g.s }
	local y = top + 8 - math.floor(S.scroll * g.s + 0.5) / g.s
	S.vis_top, S.vis_bottom = top, bottom
	local h = view.settings(y, 1)
	S.vis_top, S.vis_bottom = nil, nil
	hit.clip = nil
	g.unclip()
	S.content_h = h + 8 + 20
	local max_scroll = math.max(0, S.content_h - vh)
	S.scroll_to = clamp(S.scroll_to, 0, max_scroll)
	view.scrollbar(top, vh, max_scroll)
end

----------------------------------------------------------------------
-- Footer + tooltip + window
----------------------------------------------------------------------

function view.footer()
	local top = K.H - K.FT
	g.rect(0, top, K.W, K.FT, C.bar, 16, 1, ROUND_BOTTOM)
	g.hl(0, top, K.W, C.black)
	local by, bh = top + 14, 36
	local right = K.W - 18
	if S.settings then
		g.text(F(400), 12, L("sm_ui_subtitle"), 22, top + K.FT / 2, C.text3)
		local x = view.button("set_back", L("sm_ui_back"), nil, right, by, bh, "primary", true, function()
			S.settings = false
		end)
		view.button("set_reset", L("sm_ui_defaults"), nil, x - 10, by, bh, "secondary", true, reset_settings)
		return
	end

	g.text(F(400), 12, last_checked_text(), 22, top + K.FT / 2, C.text3)
	local item = selected()
	local is_manual = item and item.manual
	local action_label = is_manual and L("sm_panel_download_button") or L("sm_panel_install_button")
	local action_on = item ~= nil and not working and ((is_manual and can_download) or (not is_manual and can_install))
	local x = view.button("act", action_label, "arrow_down", right, by, bh, "primary", action_on, function()
		if working then return end
		if is_manual then
			if can_download then download_manual() end
		elseif can_install then
			install_selected()
		end
	end)
	x = view.button("check", L("sm_panel_check_button"), "search", x - 10, by, bh, "secondary", not working, function()
		if not working then update_check() end
	end)
	view.hint("check", L("sm_tip_check"))
end

function view.tip()
	if S.tip ~= S.tip_shown then S.tip_shown, S.tip_since = S.tip, S.now end
	if not S.tip then return end
	local k = clamp((S.now - S.tip_since - K.TIP_DELAY) / 0.12, 0, 1)
	if k <= 0 then return end
	local mx, my = Input.GetCursorPos()
	local cx, cy = (mx - g.x) / g.s, (my - g.y) / g.s
	local w = g.width(F(600), 12, S.tip) + 20
	local over = hit.at(mx, my)
	local top = over and (over[2] - g.y) / g.s or cy
	local bottom = over and (over[4] - g.y) / g.s or cy
	local y = math.max(bottom + 6, cy + 24)
	if y + 30 > K.H then y = math.min(top - 32, cy - 34) end
	local x = clamp(cx - w / 2, 4, K.W - w - 4)
	g.rect(x, y, w, 26, C.raised, 7, k)
	g.frame(x, y, w, 26, C.outline, 7, k)
	g.text(F(600), 12, S.tip, x + 10, y + 13, C.text, k)
end

function view.window()
	local screen = Render.ScreenSize()
	g.s = math.max(0.7, screen.y / 1080) * SET.scale / 100
	if not S.wx then
		S.wx = Config.ReadInt("script_manager", "panel_x", -1)
		S.wy = Config.ReadInt("script_manager", "panel_y", -1)
		if S.wx < 0 or S.wy < 0 then
			S.wx = math.floor((screen.x - K.W * g.s) / 2)
			S.wy = math.floor((screen.y - K.H * g.s) / 2)
		end
	end
	S.wx = clamp(S.wx, 0, math.max(0, screen.x - K.W * g.s))
	S.wy = clamp(S.wy, 0, math.max(0, screen.y - K.H * g.s))
	g.x, g.a = S.wx, S.alpha
	g.y = S.wy + (1 - S.alpha) * 10 * g.s
	g.cmp = anim.tween("compact", SET.compact == 1 and 1 or 0, 0.25, ease_in_out)

	if S.settings ~= S.last_settings then
		S.last_settings, S.fade_t = S.settings, 0
		S.scroll_to = 0
		S.tweens.scroll = nil
	end
	S.fade_t = math.min(1, S.fade_t + S.dt / 0.2)
	S.detail_t = math.min(1, S.detail_t + S.dt / 0.18)

	hit.begin()
	S.tip = nil

	Render.FilledRect(Vec2(0, 0), Vec2(screen.x, screen.y), Color(3, 7, 12, math.floor(78 * S.alpha)))

	hit.add(0, 0, K.W, K.H, "window", {})
	g.glass(0, 0, K.W, K.H, 16)
	view.titlebar()

	local base = g.a
	g.a = base * (0.35 + 0.65 * ease_out(S.fade_t))
	if S.settings then
		view.settings_content()
	else
		view.main()
	end
	g.a = base

	view.footer()
	view.tip()
	g.frame(0, 0, K.W, K.H, C.border, 16)
end

----------------------------------------------------------------------
-- Input
----------------------------------------------------------------------

local input = { held = {}, swallow = false }

local function inside(mx, my)
	return mx >= S.wx and my >= S.wy and mx < S.wx + K.W * g.s and my < S.wy + K.H * g.s
end

function input.press(mx, my, button)
	if button ~= 1 then return end
	local h = hit.at(mx, my)
	local id, on = h and h[5], h and h[6] or {}
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
	if S.drag and S.wx then
		Config.WriteInt("script_manager", "panel_x", math.floor(S.wx))
		Config.WriteInt("script_manager", "panel_y", math.floor(S.wy))
	end
	if S.slide then save_settings() end
	S.drag, S.sb_drag, S.slide = nil, nil, nil
end

----------------------------------------------------------------------
-- Init
----------------------------------------------------------------------

set_status("sm_status_idle")
load_update_cache()
show_cached_selection()
local scripts_dir = scripts_path()
localizer_installed = scripts_dir ~= nil and read_file(scripts_dir .. "!_qLocalizer.lua") ~= nil

----------------------------------------------------------------------
-- Callbacks
----------------------------------------------------------------------

function script.OnScriptsLoaded()
	if ai_bridge and type(ai_bridge.mcp_log) == "function" then
		ai_bridge.mcp_log("info", "Script Manager loaded", { version = VERSION })
	end
	update_check()
end

function script.OnUpdateEx()
	if ui.open:IsPressed() and not Input.IsInputCaptured() then
		S.open = not S.open
		S.drag, S.slide, S.sb_drag, S.press = nil, nil, nil, nil
	end
	if reload_at and os.clock() >= reload_at then
		reload_at = nil
		Engine.ReloadScriptSystem()
	end
end

function script.OnFrame()
	local now = os.clock()
	local frame = GlobalVars.GetAbsFrameTime()
	S.dt = clamp(frame > 0 and frame or (now - S.now), 0, 0.1)
	S.now = now
	theme.tick(S.dt)
	S.alpha = anim.tween("window", S.open and 1 or 0, 0.18)
	if S.alpha <= 0 then return end

	if S.press and not Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE1, true) then
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
	if S.slide then view.slide_to(mx) end
	if S.sb_drag then
		S.scroll_to = clamp(S.sb_drag.scroll + (my - S.sb_drag.my) * S.sb_drag.k, 0, math.max(0, S.content_h - S.view_h))
		S.tweens.scroll = nil
		S.scroll = S.scroll_to
		S.sb_until = S.now + 1.2
	end
	view.window()
end

function script.OnKeyEvent(e)
	if not e then return true end
	if S.alpha <= 0 or not S.wx then return true end
	if not S.open then
		if e.key == Enum.ButtonCode.KEY_MOUSE1 and e.event == Enum.EKeyEvent.EKeyEvent_KEY_UP then
			input.held[e.key] = nil
			input.end_drag()
			S.press = nil
			input.swallow = false
		end
		return true
	end

	if e.key == Enum.ButtonCode.KEY_ESCAPE and e.event == Enum.EKeyEvent.EKeyEvent_KEY_DOWN then
		if S.settings then S.settings = false else S.open = false end
		S.drag, S.slide, S.sb_drag, S.press = nil, nil, nil, nil
		return false
	end

	local mx, my = Input.GetCursorPos()
	if e.event == Enum.EKeyEvent.EKeyEvent_SCROLL_UP or e.event == Enum.EKeyEvent.EKeyEvent_SCROLL_DOWN then
		if not inside(mx, my) then return true end
		if S.settings then
			local content
			for i = #hit.list, 1, -1 do
				if hit.list[i][5] == "content" then
					content = hit.list[i]
					break
				end
			end
			if content and mx >= content[1] and mx < content[3] and my >= content[2] and my < content[4] then
				content[6].wheel(e.event == Enum.EKeyEvent.EKeyEvent_SCROLL_DOWN and 1 or -1)
			end
		end
		return false
	end

	if e.key == Enum.ButtonCode.KEY_MOUSE1 or e.key == Enum.ButtonCode.KEY_MOUSE2 then
		local left = e.key == Enum.ButtonCode.KEY_MOUSE1
		if e.event == Enum.EKeyEvent.EKeyEvent_KEY_DOWN then
			if input.held[e.key] then return not input.swallow end
			input.held[e.key] = true
			if not inside(mx, my) then
				if left then S.press = { id = false } end
				return true
			end
			input.swallow = true
			input.press(mx, my, left and 1 or 2)
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
	return true
end

return script
