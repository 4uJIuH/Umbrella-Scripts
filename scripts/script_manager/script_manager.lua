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

local VERSION = "1.0.1"

local localization = qLocalization.new({
	en = {
		sm_group_main = "Script updates",
		sm_group_actions = "Actions",
		sm_script = "Dota script",
		sm_status_idle = "Select a script and check for updates",
		sm_status_fetching = "Checking GitHub...",
		sm_status_current = "Already up to date: %s",
		sm_status_available = "Update available: %s",
		sm_status_installed = "Installed %s. Reloading scripts...",
		sm_status_manual = "ZIP is ready to download: %s",
		sm_status_localizer = "qLocalization is already installed",
		sm_status_localizer_installed = "qLocalization installed. Reloading scripts...",
		sm_status_error = "Error: %s",
		sm_check = "Check for updates",
		sm_install = "Install update",
		sm_download_zip = "Download Tinker Auto Farm ZIP",
		sm_install_localizer = "Install qLocalization",
		sm_help = "Tinker Auto Farm is downloaded as a ZIP.\nUnpack it manually into the scripts folder.",
		sm_item_ttd = "Tinker Turret Dodge",
		sm_item_farm = "Tinker Auto Farm",
		sm_item_shackleshot = "Auto Shackleshot",
		sm_item_spark = "Auto Spark",
		sm_item_runes = "Rune Destruction",
		sm_item_earth = "Earth Spirit Kick Combo",
		sm_item_hp = "HP/Mana 67 Ping",
		sm_item_bear = "Spirit Bear Pull",
		sm_item_manager = "Script Manager",
	},
	ru = {
		sm_group_main = "Обновление скриптов",
		sm_group_actions = "Действия",
		sm_script = "Скрипт Dota",
		sm_status_idle = "Выберите скрипт и проверьте обновления",
		sm_status_fetching = "Проверка GitHub...",
		sm_status_current = "Установлена последняя версия: %s",
		sm_status_available = "Доступно обновление: %s",
		sm_status_installed = "Установлена версия %s. Перезагрузка скриптов...",
		sm_status_manual = "ZIP готов к скачиванию: %s",
		sm_status_localizer = "qLocalization уже установлен",
		sm_status_localizer_installed = "qLocalization установлен. Перезагрузка скриптов...",
		sm_status_error = "Ошибка: %s",
		sm_check = "Проверить обновления",
		sm_install = "Установить обновление",
		sm_download_zip = "Скачать ZIP Tinker Auto Farm",
		sm_install_localizer = "Установить qLocalization",
		sm_help = "Tinker Auto Farm скачивается как ZIP.\nРаспакуйте его вручную в папку scripts.",
		sm_item_ttd = "Tinker Turret Dodge",
		sm_item_farm = "Tinker Auto Farm",
		sm_item_shackleshot = "Auto Shackleshot",
		sm_item_spark = "Auto Spark",
		sm_item_runes = "Rune Destruction",
		sm_item_earth = "Earth Spirit Kick Combo",
		sm_item_hp = "HP/Mana 67 Ping",
		sm_item_bear = "Spirit Bear Pull",
		sm_item_manager = "Script Manager",
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
	{ id = "script_manager", key = "sm_item_manager", file = "script_manager.lua" },
}

local ui = {}
local selected_item
local selected_release
local working = false
local reload_at

do
	local tab = UI.Create("Scripts", "Scripts", "Script Manager")
	tab:Icon("\u{f013}")

	local page = tab:Create("Settings")
	local g_main = page:Create("sm_group_main", Enum.GroupSide.Left)
	local g_actions = page:Create("sm_group_actions", Enum.GroupSide.Right)
	local item_keys = {}

	for i, item in ipairs(items) do
		item_keys[i] = item.key
	end

	ui.selection = g_main:Combo("sm_script", item_keys, 0)
	ui.status = g_main:Label("sm_status_idle")
	ui.check = g_main:Button("sm_check", function() end)
	ui.install = g_main:Button("sm_install", function() end)
	ui.download_zip = g_main:Button("sm_download_zip", function() end)
	ui.install_localizer = g_actions:Button("sm_install_localizer", function() end)
	ui.help = g_actions:Label("sm_help")
end

local function set_status(key, value)
	local text = L(key)
	if value ~= nil then text = string.format(text, tostring(value)) end
	ui.status:ForceLocalization(text)
end

local function set_actions(can_install, can_download)
	ui.install:Disabled(not can_install)
	ui.download_zip:Disabled(not can_download)
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
	return items[(ui.selection:Get() or 0) + 1]
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

local function update_check()
	if working then return end
	working = true
	selected_release = nil
	local requested_item = selected()
	selected_item = requested_item
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
		local installed_version = installed_text and installed_text:match('VERSION%s*=%s*"([^"]+)"') or nil
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
				set_status("sm_status_localizer_installed")
				reload_at = os.clock() + 1.0
			else
				set_status("sm_status_localizer")
			end
		end)
	end)
end

local function selection_changed()
	selected_item = selected()
	selected_release = nil
	set_actions(false, false)
	set_status("sm_status_idle")
end

ui.check:SetCallback(update_check)
ui.install:SetCallback(install_selected)
ui.download_zip:SetCallback(download_manual)
ui.install_localizer:SetCallback(install_localizer_button)
ui.selection:SetCallback(selection_changed)
set_actions(false, false)

local script = {}

function script.OnScriptsLoaded()
	if ai_bridge and type(ai_bridge.mcp_log) == "function" then
		ai_bridge.mcp_log("info", "Script Manager loaded", { version = VERSION })
	end
end

function script.OnUpdateEx()
	if reload_at and os.clock() >= reload_at then
		reload_at = nil
		Engine.ReloadScriptSystem()
	end
end

return script
