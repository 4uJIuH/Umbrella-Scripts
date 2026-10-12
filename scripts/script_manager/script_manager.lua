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

local VERSION = "1.1.1"

local localization = qLocalization.new({
	en = {
		sm_group_main = "Script Manager",
		sm_open = "Open manager",
		sm_open_tip = "Opens the Script Manager panel",
		sm_panel_title = "Script Manager",
		sm_panel_subtitle = "UMBRELLA UPDATE CENTER",
		sm_panel_scripts = "DOTA SCRIPTS",
		sm_panel_selected = "SELECTED SCRIPT",
		sm_panel_installed = "INSTALLED",
		sm_panel_latest = "LATEST",
		sm_panel_status = "ACTIVITY",
		sm_panel_localizer_title = "Localization library",
		sm_panel_localizer_desc = "Automatically installed as !_qLocalizer.lua",
		sm_panel_localizer_ready = "Installed",
		sm_panel_not_detected = "Not detected",
		sm_panel_not_checked = "Not checked",
		sm_panel_current_badge = "UP TO DATE",
		sm_panel_update_badge = "UPDATE",
		sm_panel_manual_badge = "MANUAL ZIP",
		sm_panel_installing_badge = "WORKING",
		sm_panel_check_button = "Check updates",
		sm_panel_install_button = "Install update",
		sm_panel_download_button = "Download ZIP",
		sm_panel_localizer_button = "Install qLocalization",
		sm_status_idle = "Select a script and check for updates",
		sm_status_fetching = "Checking GitHub...",
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
		sm_desc_ttd = "Dodges dangerous abilities with Tinker turrets.",
		sm_desc_farm = "Tinker Auto Farm package. ZIP installation is manual.",
		sm_desc_shackleshot = "Automatically assists with Shackleshot.",
		sm_desc_spark = "Automates Spark Wraith placement and targeting.",
		sm_desc_runes = "Sends controlled units to collect or deny runes.",
		sm_desc_earth = "Automates Earth Spirit's Blink and kick combo.",
		sm_desc_hp = "Tracks HP and mana milestones and sends chat alerts.",
		sm_desc_bear = "Uses Lone Druid's bear to pull a creep wave.",
	},
	ru = {
		sm_group_main = "Script Manager",
		sm_open = "Открыть менеджер",
		sm_open_tip = "Открывает панель Script Manager",
		sm_panel_title = "Script Manager",
		sm_panel_subtitle = "ЦЕНТР ОБНОВЛЕНИЙ UMBRELLA",
		sm_panel_scripts = "СКРИПТЫ DOTA",
		sm_panel_selected = "ВЫБРАННЫЙ СКРИПТ",
		sm_panel_installed = "УСТАНОВЛЕНА",
		sm_panel_latest = "ПОСЛЕДНЯЯ",
		sm_panel_status = "СОСТОЯНИЕ",
		sm_panel_localizer_title = "Библиотека локализации",
		sm_panel_localizer_desc = "Установится автоматически как !_qLocalizer.lua",
		sm_panel_localizer_ready = "Установлена",
		sm_panel_not_detected = "Не обнаружена",
		sm_panel_not_checked = "Не проверена",
		sm_panel_current_badge = "АКТУАЛЬНА",
		sm_panel_update_badge = "ОБНОВЛЕНИЕ",
		sm_panel_manual_badge = "ZIP ВРУЧНУЮ",
		sm_panel_installing_badge = "РАБОТАЕТ",
		sm_panel_check_button = "Проверить",
		sm_panel_install_button = "Установить",
		sm_panel_download_button = "Скачать ZIP",
		sm_panel_localizer_button = "Установить qLocalization",
		sm_status_idle = "Выберите скрипт и проверьте обновления",
		sm_status_fetching = "Проверка GitHub...",
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
		sm_desc_ttd = "Уклоняется от опасных способностей с помощью турелей Тинкера.",
		sm_desc_farm = "Пакет Tinker Auto Farm. ZIP нужно установить вручную.",
		sm_desc_shackleshot = "Автоматизирует помощь с Shackleshot.",
		sm_desc_spark = "Автоматизирует размещение и выбор целей для Spark Wraith.",
		sm_desc_runes = "Отправляет подконтрольных юнитов собирать или ломать руны.",
		sm_desc_earth = "Автоматизирует Blink-комбо Earth Spirit с толчком.",
		sm_desc_hp = "Следит за значениями HP и маны и отправляет сообщения в чат.",
		sm_desc_bear = "Использует медведя Lone Druid для отвода волны крипов.",
	},
})

local UI = localization.WrapLibrary(Menu)
local L = localization.Get
local JSON = require("assets.JSON")

local CATALOG_URL = "https://raw.githubusercontent.com/4uJIuH/umbrella-scripts/main/scripts/manager/catalog.json"
local items = {
	{ id = "tinker_turret_dodge", key = "sm_item_ttd", file = "tinker_turret_dodge.lua", needs_localizer = true },
	{ id = "tinker_auto_farm", key = "sm_item_farm", file = "Tinker-Auto-Farm.zip", manual = true },
	{ id = "auto_shackleshot", key = "sm_item_shackleshot", file = "Auto_Shackleshot.lua", needs_localizer = true },
	{ id = "auto_spark", key = "sm_item_spark", file = "Auto_Spark.lua", needs_localizer = true },
	{ id = "rune_destruction", key = "sm_item_runes", file = "rune_units.lua" },
	{ id = "earth_spirit_kick_combo", key = "sm_item_earth", file = "earth_spirit_kick_combo.lua", needs_localizer = true },
	{ id = "hp_mana_67_ping", key = "sm_item_hp", file = "hp_mana_67_ping.lua", needs_localizer = true },
	{ id = "spirit_bear_pull", key = "sm_item_bear", file = "lone_druid_bear_pull.lua", needs_localizer = true },
}
local description_keys = {
	tinker_turret_dodge = "sm_desc_ttd",
	tinker_auto_farm = "sm_desc_farm",
	auto_shackleshot = "sm_desc_shackleshot",
	auto_spark = "sm_desc_spark",
	rune_destruction = "sm_desc_runes",
	earth_spirit_kick_combo = "sm_desc_earth",
	hp_mana_67_ping = "sm_desc_hp",
	spirit_bear_pull = "sm_desc_bear",
}

local ui = {}
local selected_index = 1
local selected_release
local installed_version
local working = false
local reload_at
local can_install = false
local can_download = false
local localizer_installed = false
local panel = {
	open = false,
	width = 820,
	height = 520,
	x = nil,
	y = nil,
	dragging = false,
	mouse_captured = false,
	hits = {},
	status_key = "sm_status_idle",
}

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
	return url:match("^https://raw%.githubusercontent%.com/4uJIuH/umbrella%-scripts/") ~= nil
		or url:match("^https://github%.com/4uJIuH/umbrella%-scripts/releases/download/") ~= nil
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
	set_status("sm_status_fetching")
	fetch(CATALOG_URL, function(text, err)
		if not text then return done(nil, err) end
		local ok, manifest = pcall(function() return JSON:decode(text) end)
		if not ok or type(manifest) ~= "table" then return done(nil, "catalog could not be parsed") end
		done(manifest)
	end)
end

local function validate_script(text, version)
	if type(text) ~= "string" or #text < 100 or text:sub(1, 1) == "<" then return false end
	return text:match('VERSION%s*=%s*"([^"]+)"') == version
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
	return text and text:match('VERSION%s*=%s*"([^"]+)"') or nil
end

local function update_check()
	if working then return end
	working = true
	selected_release = nil
	local requested_item = selected()
	installed_version = installed_script_version(requested_item)
	set_actions(false, false)
	load_catalog(function(manifest, err)
		working = false
		if selected() ~= requested_item then return end
		if not manifest then return set_status("sm_status_error", err) end
		local release, release_error = selected_manifest(manifest, requested_item)
		if not release then return set_status("sm_status_error", release_error) end
		selected_release = release
		if requested_item.manual then
			set_actions(false, true)
			return set_status("sm_status_manual", release.version)
		end

		local path = selected_path(requested_item)
		if not path then return set_status("sm_status_error", "cheat directory is unavailable") end
		local installed_text = read_file(path)
		installed_version = installed_text and installed_text:match('VERSION%s*=%s*"([^"]+)"') or nil
		local comparison = installed_version and compare_versions(installed_version, release.version) or nil

		if comparison == 0 then
			return set_status("sm_status_current", release.version)
		elseif comparison and comparison > 0 then
			return set_status("sm_status_current", installed_version)
		end
		set_actions(true, false)
		set_status("sm_status_available", release.version)
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
				valid = validate_script(text, release.version)
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
	selected_release = nil
	installed_version = installed_script_version(selected())
	set_actions(false, false)
	set_status("sm_status_idle")
end

local script = {}

local panel_fonts
local function ensure_panel_fonts()
	if panel_fonts then return end
	local flags = Enum.FontCreate.FONTFLAG_ANTIALIAS
	panel_fonts = {
		regular = Render.LoadFont("Arial", flags, 400),
		medium = Render.LoadFont("Arial", flags, 600),
		bold = Render.LoadFont("Arial", flags, 700),
	}
end

local function panel_text(font, size, value, x, y, color)
	Render.Text(font, size, tostring(value), Vec2(x, y), color)
end

local function panel_measure(font, size, value)
	return Render.TextSize(font, size, tostring(value)).x
end

local function panel_wrap(value, font, size, width, max_lines)
	local lines, current = {}, ""
	for word in tostring(value):gmatch("%S+") do
		local candidate = current == "" and word or (current .. " " .. word)
		if current ~= "" and panel_measure(font, size, candidate) > width then
			lines[#lines + 1] = current
			current = word
			if max_lines and #lines >= max_lines then break end
		else
			current = candidate
		end
	end
	if current ~= "" and (not max_lines or #lines < max_lines) then
		lines[#lines + 1] = current
	end
	return lines
end

local function point_in(x, y, x0, y0, x1, y1)
	return x >= x0 and x <= x1 and y >= y0 and y <= y1
end

local function panel_hit(kind, x0, y0, x1, y1, value)
	panel.hits[#panel.hits + 1] = {
		kind = kind,
		x0 = x0,
		y0 = y0,
		x1 = x1,
		y1 = y1,
		value = value,
	}
end

local function panel_button(title, x, y, width, height, enabled, primary, mx, my)
	local hover = enabled and point_in(mx, my, x, y, x + width, y + height)
	local fill = primary and Color(54, 186, 169, enabled and (hover and 255 or 235) or 100)
		or Color(34, 46, 59, enabled and (hover and 255 or 220) or 110)
	Render.FilledRect(Vec2(x, y), Vec2(x + width, y + height), fill, 8)
	if not primary then
		Render.Rect(Vec2(x, y), Vec2(x + width, y + height),
			Color(65, 80, 96, enabled and 220 or 110), 8)
	end
	local font = primary and panel_fonts.bold or panel_fonts.medium
	local size = 14
	local text_width = panel_measure(font, size, title)
	local text_color = primary and Color(10, 29, 34, enabled and 255 or 120)
		or Color(225, 232, 239, enabled and 255 or 120)
	panel_text(font, size, title, x + math.max(8, (width - text_width) / 2),
		y + (height - 17) / 2, text_color)
end

local function panel_status_text()
	local message = L(panel.status_key or "sm_status_idle")
	if panel.status_value ~= nil then
		message = string.format(message, tostring(panel.status_value))
	end
	return message
end

local function draw_manager_panel()
	if not panel.open then return end
	ensure_panel_fonts()
	local screen = Render.ScreenSize()
	local width = math.min(panel.width, math.max(480, screen.x - 32))
	local height = math.min(panel.height, math.max(420, screen.y - 32))
	panel.width, panel.height = width, height
	if panel.x == nil or panel.y == nil then
		local saved_x = Config.ReadInt("script_manager", "panel_x", -1)
		local saved_y = Config.ReadInt("script_manager", "panel_y", -1)
		panel.x = saved_x >= 0 and saved_x or math.floor((screen.x - width) / 2)
		panel.y = saved_y >= 0 and saved_y or math.floor((screen.y - height) / 2)
	end
	panel.x = math.max(16, math.min(panel.x, screen.x - width - 16))
	panel.y = math.max(16, math.min(panel.y, screen.y - height - 16))
	local x, y, w, h = math.floor(panel.x), math.floor(panel.y), width, height
	local mx, my = Input.GetCursorPos()
	local edge, text, muted = Color(48, 62, 78), Color(232, 239, 246), Color(143, 159, 176)
	local card, base, sidebar = Color(16, 23, 32), Color(21, 30, 41), Color(19, 28, 39)
	panel.hits = {}

	Render.FilledRect(Vec2(0, 0), Vec2(screen.x, screen.y), Color(3, 7, 12, 96))
	Render.Blur(Vec2(x, y), Vec2(x + w, y + h), 0.7, 0.9, 14)
	Render.FilledRect(Vec2(x, y), Vec2(x + w, y + h), card, 14)
	Render.Rect(Vec2(x, y), Vec2(x + w, y + h), edge, 14)
	Render.FilledRect(Vec2(x + 1, y + 1), Vec2(x + w - 1, y + 5), Color(54, 186, 169), 3)
	Render.FilledRect(Vec2(x + 1, y + 6), Vec2(x + w - 1, y + 62), base, 0)
	Render.Line(Vec2(x, y + 62), Vec2(x + w, y + 62), edge, 1)

	Render.FilledCircle(Vec2(x + 30, y + 33), 11, Color(54, 186, 169, 245))
	Render.FilledCircle(Vec2(x + 30, y + 33), 5, card)
	panel_text(panel_fonts.bold, 19, L("sm_panel_title"), x + 50, y + 14, text)
	panel_text(panel_fonts.medium, 9, L("sm_panel_subtitle"), x + 51, y + 39, muted)

	local close_x, close_y = x + w - 42, y + 16
	local close_hover = point_in(mx, my, close_x, close_y, close_x + 26, close_y + 26)
	Render.FilledRect(Vec2(close_x, close_y), Vec2(close_x + 26, close_y + 26),
		Color(47, 61, 76, close_hover and 255 or 190), 7)
	panel_text(panel_fonts.medium, 16, "x", close_x + 9, close_y + 4, text)
	panel_hit("close", close_x, close_y, close_x + 26, close_y + 26)
	panel_hit("drag", x, y, x + w - 48, y + 62)

	local left_x, left_y = x + 12, y + 74
	local left_w, left_h = 220, h - 88
	Render.FilledRect(Vec2(left_x, left_y), Vec2(left_x + left_w, left_y + left_h), sidebar, 10)
	panel_text(panel_fonts.bold, 10, L("sm_panel_scripts"), left_x + 14, left_y + 13, muted)
	Render.Line(Vec2(left_x + 12, left_y + 35), Vec2(left_x + left_w - 12, left_y + 35), edge, 1)
	for i, item in ipairs(items) do
		local row_y = left_y + 43 + (i - 1) * 39
		local row_x = left_x + 8
		local row_w, row_h = left_w - 16, 34
		local active = i == selected_index
		local hover = point_in(mx, my, row_x, row_y, row_x + row_w, row_y + row_h)
		if active then
			Render.FilledRect(Vec2(row_x, row_y), Vec2(row_x + row_w, row_y + row_h),
				Color(39, 62, 72), 7)
			Render.FilledRect(Vec2(row_x, row_y + 7), Vec2(row_x + 3, row_y + row_h - 7),
				Color(54, 186, 169), 2)
		elseif hover then
			Render.FilledRect(Vec2(row_x, row_y), Vec2(row_x + row_w, row_y + row_h),
				Color(30, 42, 55), 7)
		end
		Render.FilledCircle(Vec2(row_x + 17, row_y + 17), 4,
			active and Color(90, 220, 190) or Color(90, 109, 127))
		panel_text(active and panel_fonts.medium or panel_fonts.regular, 12, L(item.key),
			row_x + 30, row_y + 9, active and text or Color(185, 198, 211))
		panel_hit("select", row_x, row_y, row_x + row_w, row_y + row_h, i)
	end

	local main_x, main_y = x + 250, y + 80
	local main_w = w - 272
	local item = selected()
	local title = item and L(item.key) or L("sm_panel_title")
	local desc = item and L(description_keys[item.id]) or ""
	panel_text(panel_fonts.bold, 9, L("sm_panel_selected"), main_x, main_y, muted)
	panel_text(panel_fonts.bold, 21, title, main_x, main_y + 21, text)
	local lines = panel_wrap(desc, panel_fonts.regular, 13, main_w - 8, 3)
	for i, line in ipairs(lines) do
		panel_text(panel_fonts.regular, 13, line, main_x, main_y + 53 + (i - 1) * 18, muted)
	end

	local badge_text, badge_color
	if working then
		badge_text, badge_color = L("sm_panel_installing_badge"), Color(208, 171, 89)
	elseif item and item.manual then
		badge_text, badge_color = L("sm_panel_manual_badge"), Color(208, 171, 89)
	elseif can_install then
		badge_text, badge_color = L("sm_panel_update_badge"), Color(229, 161, 91)
	elseif selected_release then
		badge_text, badge_color = L("sm_panel_current_badge"), Color(91, 202, 155)
	else
		badge_text, badge_color = L("sm_panel_not_checked"), muted
	end
	local badge_w = panel_measure(panel_fonts.bold, 9, badge_text) + 18
	local badge_y = main_y + 103
	Render.FilledRect(Vec2(main_x, badge_y), Vec2(main_x + badge_w, badge_y + 22),
		Color(badge_color.r, badge_color.g, badge_color.b, 35), 6)
	panel_text(panel_fonts.bold, 9, badge_text, main_x + 9, badge_y + 6, badge_color)

	local box_y = main_y + 140
	local box_gap = 10
	local box_w = (main_w - box_gap) / 2
	local function version_box(box_x, heading, value)
		Render.FilledRect(Vec2(box_x, box_y), Vec2(box_x + box_w, box_y + 68), base, 8)
		Render.Rect(Vec2(box_x, box_y), Vec2(box_x + box_w, box_y + 68), edge, 8)
		panel_text(panel_fonts.bold, 9, heading, box_x + 12, box_y + 11, muted)
		panel_text(panel_fonts.bold, 18, value, box_x + 12, box_y + 32, text)
	end
	version_box(main_x, L("sm_panel_installed"),
		installed_version and ("v" .. installed_version) or L("sm_panel_not_detected"))
	version_box(main_x + box_w + box_gap, L("sm_panel_latest"),
		selected_release and ("v" .. selected_release.version) or L("sm_panel_not_checked"))

	local status_y = box_y + 80
	Render.FilledRect(Vec2(main_x, status_y), Vec2(main_x + main_w, status_y + 58), base, 8)
	Render.FilledCircle(Vec2(main_x + 15, status_y + 17), 4,
		panel.status_key == "sm_status_error" and Color(224, 106, 105) or Color(54, 186, 169))
	panel_text(panel_fonts.bold, 9, L("sm_panel_status"), main_x + 28, status_y + 10, muted)
	local status_color = panel.status_key == "sm_status_error" and Color(239, 152, 145) or text
	local status_lines = panel_wrap(panel_status_text(), panel_fonts.regular, 12, main_w - 24, 2)
	for i, line in ipairs(status_lines) do
		panel_text(panel_fonts.regular, 12, line, main_x + 12, status_y + 27 + (i - 1) * 16, status_color)
	end

	local library_y = status_y + 70
	local library_h = 54
	Render.FilledRect(Vec2(main_x, library_y), Vec2(main_x + main_w, library_y + library_h), base, 8)
	Render.FilledCircle(Vec2(main_x + 17, library_y + 18), 4,
		localizer_installed and Color(91, 202, 155) or Color(208, 171, 89))
	panel_text(panel_fonts.medium, 12, L("sm_panel_localizer_title"), main_x + 30, library_y + 9, text)
	panel_text(panel_fonts.regular, 10, L("sm_panel_localizer_desc"), main_x + 30, library_y + 29, muted)
	local library_button_w = 172
	local library_button_x = main_x + main_w - library_button_w - 10
	local library_button_text = localizer_installed and L("sm_panel_localizer_ready")
		or L("sm_panel_localizer_button")
	panel_button(library_button_text, library_button_x, library_y + 10, library_button_w, 34,
		not working and not localizer_installed, false, mx, my)
	panel_hit("localizer", library_button_x, library_y + 10,
		library_button_x + library_button_w, library_y + 44)

	local footer_y = y + h - 62
	Render.Line(Vec2(x + 12, footer_y), Vec2(x + w - 12, footer_y), edge, 1)
	local button_y, button_h = footer_y + 13, 36
	local check_w, action_w, gap = 174, 174, 10
	local action_text = item and (item.manual and L("sm_panel_download_button")
		or L("sm_panel_install_button")) or L("sm_panel_install_button")
	local action_enabled = item and (item.manual and can_download
		or (not item.manual and can_install)) or false
	panel_button(L("sm_panel_check_button"), main_x, button_y, check_w, button_h,
		not working, false, mx, my)
	panel_hit("check", main_x, button_y, main_x + check_w, button_y + button_h)
	local action_x = main_x + check_w + gap
	panel_button(action_text, action_x, button_y, action_w, button_h,
		action_enabled and not working, true, mx, my)
	panel_hit(item and item.manual and "download" or "install", action_x, button_y,
		action_x + action_w, button_y + button_h)
end

local function select_panel_item(index)
	if not items[index] or index == selected_index then return end
	selected_index = index
	selection_changed()
end

local function handle_panel_click(x, y)
	for i = #panel.hits, 1, -1 do
		local hit = panel.hits[i]
		if point_in(x, y, hit.x0, hit.y0, hit.x1, hit.y1) then
			if hit.kind == "close" then
				panel.open, panel.dragging = false, false
			elseif hit.kind == "drag" then
				panel.dragging = true
				panel.drag_dx, panel.drag_dy = x - panel.x, y - panel.y
			elseif hit.kind == "select" then
				select_panel_item(hit.value)
			elseif hit.kind == "check" then
				if not working then update_check() end
			elseif hit.kind == "install" then
				if can_install and not working then install_selected() end
			elseif hit.kind == "download" then
				if can_download and not working then download_manual() end
			elseif hit.kind == "localizer" then
				if not localizer_installed and not working then install_localizer_button() end
			end
			return
		end
	end
end

set_status("sm_status_idle")
installed_version = installed_script_version(selected())
local scripts_dir = scripts_path()
localizer_installed = scripts_dir ~= nil and read_file(scripts_dir .. "!_qLocalizer.lua") ~= nil
set_actions(false, false)

function script.OnScriptsLoaded()
	if ai_bridge and type(ai_bridge.mcp_log) == "function" then
		ai_bridge.mcp_log("info", "Script Manager loaded", { version = VERSION })
	end
end

function script.OnUpdateEx()
	if ui.open:IsPressed() and not Input.IsInputCaptured() then
		panel.open = not panel.open
		panel.dragging = false
	end
	if panel.dragging then
		if Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE1, true) then
			local cursor_x, cursor_y = Input.GetCursorPos()
			local screen = Render.ScreenSize()
			panel.x = math.max(16, math.min(cursor_x - panel.drag_dx, screen.x - panel.width - 16))
			panel.y = math.max(16, math.min(cursor_y - panel.drag_dy, screen.y - panel.height - 16))
		else
			panel.dragging = false
			Config.WriteInt("script_manager", "panel_x", math.floor(panel.x))
			Config.WriteInt("script_manager", "panel_y", math.floor(panel.y))
		end
	end
	if reload_at and os.clock() >= reload_at then
		reload_at = nil
		Engine.ReloadScriptSystem()
	end
end

function script.OnFrame()
	draw_manager_panel()
end

function script.OnKeyEvent(data)
	if not data then return true end
	if data.key == Enum.ButtonCode.KEY_MOUSE1
		and data.event == Enum.EKeyEvent.EKeyEvent_KEY_UP
		and panel.mouse_captured
	then
		panel.mouse_captured = false
		if panel.dragging then
			panel.dragging = false
			Config.WriteInt("script_manager", "panel_x", math.floor(panel.x))
			Config.WriteInt("script_manager", "panel_y", math.floor(panel.y))
		end
		return false
	end
	if not panel.open then return true end
	if data.key == Enum.ButtonCode.KEY_ESCAPE
		and data.event == Enum.EKeyEvent.EKeyEvent_KEY_DOWN
	then
		panel.open, panel.dragging = false, false
		return false
	end
	if Input.IsInputCaptured() then return true end
	if data.key ~= Enum.ButtonCode.KEY_MOUSE1 then return true end
	if data.event == Enum.EKeyEvent.EKeyEvent_KEY_DOWN then
		local cursor_x, cursor_y = Input.GetCursorPos()
		local inside = point_in(cursor_x, cursor_y, panel.x or 0, panel.y or 0,
			(panel.x or 0) + panel.width, (panel.y or 0) + panel.height)
		if inside then
			panel.mouse_captured = true
			handle_panel_click(cursor_x, cursor_y)
			return false
		end
	end
	local cursor_x, cursor_y = Input.GetCursorPos()
	if point_in(cursor_x, cursor_y, panel.x or 0, panel.y or 0,
		(panel.x or 0) + panel.width, (panel.y or 0) + panel.height)
	then
		return false
	end
	return true
end

return script
