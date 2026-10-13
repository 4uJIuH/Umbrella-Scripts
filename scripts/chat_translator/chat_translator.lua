--[[
     ~ qLocalization
     ~ automatic localization wrapper for Lua menu interfaces

     ~ author: qfun (qfun_g9s)
]]

local VERSION = "1.0.0"

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
		ct_group_main = "Output",
		ct_group_tr = "Translation",
		ct_enable = "Enable",
		ct_enable_tip = "Translates chat messages of other\nplayers automatically",
		ct_gear_extra = "Extra",
		ct_color_name = "Nick color",
		ct_color_name_tip = "Color of the [Translate] label and the nick",
		ct_color_text = "Translation color",
		ct_color_text_tip = "Color of the translated text",
		ct_mymemory = "MyMemory (low quality)",
		ct_mymemory_tip = "Last resort when other services fail.\nSingle words are often translated wrong",
		ct_debug = "Debug log",
		ct_debug_tip = "Writes raw chat messages and errors\nto the log",
		ct_dir = "Direction",
		ct_dir_tip = "Which language to translate from and to",
		ct_dirs_en_ru = "English to Russian",
		ct_dirs_ru_en = "Russian to English",
		ct_dirs_both = "Both ways",
		ct_own = "Translate my messages",
		ct_own_tip = "Your Russian messages are translated to English\nbefore sending. Messages starting with - are skipped",
		ct_skip_own = "Skip my messages",
		ct_skip_own_tip = "Does not translate what you wrote yourself",
	},
	ru = {
		ct_group_main = "Вывод",
		ct_group_tr = "Перевод",
		ct_enable = "Включить",
		ct_enable_tip = "Автоматически переводит сообщения\nдругих игроков в чате",
		ct_gear_extra = "Дополнительно",
		ct_color_name = "Цвет ника",
		ct_color_name_tip = "Цвет метки [Translate] и ника",
		ct_color_text = "Цвет перевода",
		ct_color_text_tip = "Цвет переведенного текста",
		ct_mymemory = "MyMemory (низкое качество)",
		ct_mymemory_tip = "Крайний случай, если другие сервисы не ответили.\nОдиночные слова часто переводит неверно",
		ct_debug = "Отладка в лог",
		ct_debug_tip = "Пишет в лог сырые сообщения чата и ошибки",
		ct_dir = "Направление",
		ct_dir_tip = "С какого языка на какой переводить",
		ct_dirs_en_ru = "Английский на русский",
		ct_dirs_ru_en = "Русский на английский",
		ct_dirs_both = "В обе стороны",
		ct_own = "Переводить мои сообщения",
		ct_own_tip = "Твои русские сообщения переводятся на английский\nперед отправкой. Сообщения, начинающиеся с -, пропускаются",
		ct_skip_own = "Пропускать мои",
		ct_skip_own_tip = "Не переводит то, что написал ты сам",
	},
})

local UI = localization.WrapLibrary(Menu)
local L = localization.Get

local K = {
	MSG_CHAT = 612,
	MSG_SEND_CHAT = 394,
	CHAT_CHANNEL = "ConsoleChat",
	DIRS = { "ru", "en", "both" },
	MAX_BYTES = 400,
	MAX_PENDING = 5,
	CACHE_MAX = 200,
	COOLDOWN = 300,
	COOLDOWN_SHORT = 60,
	URL_YANDEX = "https://translate.yandex.net/api/v1/tr.json/translate?ucid=%s&srv=android&format=text",
	URL_EDGE = "https://edge.microsoft.com/translate/translatetext?from=%s&to=%s&isEnterpriseClient=false",
	URL_LINGVA1 = "https://lingva.ml/api/v1/%s/%s/%s",
	URL_LINGVA2 = "https://translate.plausibility.cloud/api/v1/%s/%s/%s",
	URL_BACKUP = "https://api.mymemory.translated.net/get?q=%s&langpair=%s%%7C%s",
	URL = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=%s&dt=t&q=%s",
	ESC = { n = "\n", t = "\t", r = "\r", b = "", f = "", ["\""] = "\"", ["\\"] = "\\", ["/"] = "/" },
}

local state = { pending = 0, last_error = nil, libs = nil, cache = {}, cache_size = 0, cooldown = {}, seen_send = {}, sending = false }
local ui = {}

do
	local tab = UI.Create("Scripts", "Scripts", "Chat Translator")
	tab:Icon("\u{f1ab}")

	local page = tab:Create("Settings")
	local g_main = page:Create("ct_group_main", Enum.GroupSide.Left)
	local g_tr = page:Create("ct_group_tr", Enum.GroupSide.Right)

	ui.enable = g_main:Switch("ct_enable", false, "\u{f011}")
	ui.enable:ToolTip("ct_enable_tip")
	local g_gear = ui.enable:Gear("ct_gear_extra")
	ui.color_name = g_gear:ColorPicker("ct_color_name", Color(80, 140, 255, 255), "\u{f53f}")
	ui.color_name:ToolTip("ct_color_name_tip")
	ui.color_text = g_gear:ColorPicker("ct_color_text", Color(255, 255, 255, 255), "\u{f53f}")
	ui.color_text:ToolTip("ct_color_text_tip")
	ui.debug = g_gear:Switch("ct_debug", false, "\u{f188}")
	ui.debug:ToolTip("ct_debug_tip")

	ui.dir = g_tr:Combo("ct_dir", { "ct_dirs_en_ru", "ct_dirs_ru_en", "ct_dirs_both" }, 0)
	ui.dir:Icon("\u{f1ab}")
	ui.dir:ToolTip("ct_dir_tip")

	ui.skip_own = g_tr:Switch("ct_skip_own", true, "\u{f007}")
	ui.skip_own:ToolTip("ct_skip_own_tip")

	ui.own = g_tr:Switch("ct_own", false, "\u{f1d8}")
	ui.own:ToolTip("ct_own_tip")

	ui.mymemory = g_tr:Switch("ct_mymemory", false, "\u{f0c2}")
	ui.mymemory:ToolTip("ct_mymemory_tip")
end

local function refresh_disabled()
	local on = ui.enable:Get()
	ui.dir:Disabled(not on)
	ui.skip_own:Disabled(not on)
	ui.own:Disabled(not on)
	ui.mymemory:Disabled(not on)
	ui.debug:Disabled(not on)
end

ui.enable:SetCallback(refresh_disabled, true)

local function log(text)
	if ui.debug:Get() then
		Log.Write("[Chat Translator] " .. text)
	end
end

local function log_error(err)
	err = tostring(err)
	if err ~= state.last_error then
		state.last_error = err
		Log.Write("[Chat Translator] " .. err)
	end
end

local function url_encode(s)
	return (s:gsub("[^%w%-_%.~]", function(c)
		return string.format("%%%02X", string.byte(c))
	end))
end

local function escape_html(s)
	return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

local function count_letters(text)
	local latin, cyr = 0, 0
	local ok = pcall(function()
		for _, cp in utf8.codes(text) do
			if (cp >= 65 and cp <= 90) or (cp >= 97 and cp <= 122) then
				latin = latin + 1
			elseif cp >= 0x400 and cp <= 0x4FF then
				cyr = cyr + 1
			end
		end
	end)
	if not ok then return 0, 0 end
	return latin, cyr
end

local function pick_target(text)
	local latin, cyr = count_letters(text)
	local dir = K.DIRS[ui.dir:Get() + 1] or "ru"
	if (dir == "ru" or dir == "both") and latin >= 2 and latin > cyr then return "ru" end
	if (dir == "en" or dir == "both") and cyr >= 2 and cyr > latin then return "en" end
	return nil
end

local function parse_translation(body)
	local parts, lang = {}, nil
	local depth, idx = 0, {}
	local i, n = 1, #body
	while i <= n do
		local c = body:sub(i, i)
		if c == "[" then
			if depth >= 1 then idx[depth] = idx[depth] + 1 end
			depth = depth + 1
			idx[depth] = 0
			i = i + 1
		elseif c == "]" then
			depth = depth - 1
			i = i + 1
		elseif c == "\"" and depth >= 1 then
			local j, buf = i + 1, {}
			while j <= n do
				local d = body:sub(j, j)
				if d == "\\" then
					local e = body:sub(j + 1, j + 1)
					if e == "u" then
						local cp = tonumber(body:sub(j + 2, j + 5), 16) or 63
						j = j + 6
						if cp >= 0xD800 and cp <= 0xDBFF and body:sub(j, j + 1) == "\\u" then
							local lo = tonumber(body:sub(j + 2, j + 5), 16)
							if lo and lo >= 0xDC00 and lo <= 0xDFFF then
								cp = 0x10000 + (cp - 0xD800) * 0x400 + (lo - 0xDC00)
								j = j + 6
							end
						end
						buf[#buf + 1] = utf8.char(cp)
					else
						buf[#buf + 1] = K.ESC[e] or e
						j = j + 2
					end
				elseif d == "\"" then
					break
				else
					buf[#buf + 1] = d
					j = j + 1
				end
			end
			idx[depth] = idx[depth] + 1
			local s = table.concat(buf)
			if depth == 3 and idx[3] == 1 and idx[1] == 1 then
				parts[#parts + 1] = s
			elseif depth == 1 and not lang then
				lang = s
			end
			i = j + 1
		else
			i = i + 1
		end
	end
	return table.concat(parts), lang
end

local function hero_title(hero)
	local unit = NPC.GetUnitName(hero)
	return Engine.GetDisplayNameByUnitName(unit) or unit
end

local function player_name(id)
	local ok, nick = pcall(function()
		for _, p in ipairs(Players.GetAll()) do
			if Player.GetPlayerID(p) == id then
				local n = Player.GetName(p)
				if type(n) == "string" and n ~= "" then return n end
			end
		end
	end)
	if ok and nick then return nick end

	local ok2, data_name = pcall(function()
		for _, p in ipairs(Players.GetAll()) do
			if Player.GetPlayerID(p) == id then
				local data = Player.GetPlayerData(p)
				if data and type(data.PlayerName) == "string" and data.PlayerName ~= "" then
					return data.PlayerName
				end
			end
		end
	end)
	if ok2 and data_name then return data_name end

	local ok3, hero_name = pcall(function()
		for _, h in ipairs(Heroes.GetAll()) do
			if Hero.GetPlayerID(h) == id then return hero_title(h) end
		end
	end)
	if ok3 and hero_name then return hero_name end

	log("name not found for id " .. tostring(id))
	return "Player " .. tostring(id)
end

local function local_id()
	local ok, id = pcall(function() return Player.GetPlayerID(Players.GetLocal()) end)
	return ok and id or -1
end

local function get_libs()
	if not state.libs then
		state.libs = { protobuf = require("protobuf"), JSON = require("assets.JSON") }
	end
	return state.libs
end

local function to_byte(v)
	return math.max(0, math.min(255, math.floor((tonumber(v) or 0) + 0.5)))
end

local function to_hex(c, fallback)
	local ok, r, g, b = pcall(function() return c:ToFraction() end)
	if not ok or type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
		return fallback
	end
	return string.format("%02x%02x%02x", to_byte(r * 255), to_byte(g * 255), to_byte(b * 255))
end

local function show(name, translated)
	local ok, err = pcall(function()
		local name_hex = to_hex(ui.color_name:Get(), "508cff")
		local text_hex = to_hex(ui.color_text:Get(), "ffffff")
		Chat.Print(K.CHAT_CHANNEL, string.format("<font color='#%s'>[Translate] %s:</font> <font color='#%s'>%s</font>",
			name_hex, escape_html(name), text_hex, escape_html(translated)))
	end)
	if not ok then
		log_error("show: " .. tostring(err))
		Chat.Print(K.CHAT_CHANNEL, string.format("[Translate] %s: %s", escape_html(name), escape_html(translated)))
	end
end

local function safe_cb(fn)
	return function(res)
		local ok, err = pcall(fn, res)
		if not ok then log_error("callback: " .. tostring(err)) end
	end
end

local function cache_key(text, target)
	return target .. "|" .. text:lower():gsub("^%s+", ""):gsub("%s+$", "")
end

local function cache_put(key, value)
	if state.cache[key] == nil then
		if state.cache_size >= K.CACHE_MAX then
			state.cache = {}
			state.cache_size = 0
		end
		state.cache_size = state.cache_size + 1
	end
	state.cache[key] = value
end

local function parse_backup(body)
	local ok, data = pcall(function() return get_libs().JSON:decode(body) end)
	local translated
	if ok and type(data) == "table" and type(data.responseData) == "table" then
		local status = tonumber(data.responseStatus)
		if status == nil or status == 200 then
			translated = data.responseData.translatedText
		end
	end
	if type(translated) ~= "string" or translated == "" then return nil end
	if translated:find("MYMEMORY WARNING", 1, true) then return nil end
	return translated
end

local function finish(name, translated, on_done)
	if on_done then
		on_done(translated)
	else
		show(name, translated)
	end
end

local function parse_lingva(body)
	local data = get_libs().JSON:decode(body)
	if type(data) == "table" and type(data.translation) == "string" then
		return data.translation
	end
	return nil
end

local function unescape_html(s)
	return (s:gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&amp;", "&"))
end

local function parse_edge(body)
	local data = get_libs().JSON:decode(body)
	local item = type(data) == "table" and data[1]
	local tr = type(item) == "table" and type(item.translations) == "table" and item.translations[1]
	if type(tr) == "table" and type(tr.text) == "string" then
		return unescape_html(tr.text)
	end
	return nil
end

local function parse_yandex(body)
	local data = get_libs().JSON:decode(body)
	if type(data) ~= "table" then return nil end
	if data.code ~= nil and tonumber(data.code) ~= 200 then return nil end
	if type(data.text) == "table" then return table.concat(data.text, " ") end
	if type(data.text) == "string" then return data.text end
	return nil
end

local function yandex_ucid()
	if not state.ucid then
		state.ucid = string.format("%08x%08x%08x%08x", os.time() % 0xFFFFFFFF,
			math.floor(os.clock() * 1000000) % 0xFFFFFFFF, 0x1badb002, 0x5ca1ab1e)
	end
	return state.ucid
end

local function source_of(target)
	return target == "ru" and "en" or "ru"
end

local function get_request(url_fn)
	return function(text, target)
		return "GET", url_fn(text, target), {}
	end
end

local PROVIDERS = {
	{
		name = "google",
		trusted = true,
		request = get_request(function(text, target) return string.format(K.URL, target, url_encode(text)) end),
		parse = parse_translation,
	},
	{
		name = "yandex",
		trusted = true,
		request = function(text, target)
			return "POST", string.format(K.URL_YANDEX, yandex_ucid()), {
				headers = { ["Content-Type"] = "application/x-www-form-urlencoded" },
				data = string.format("lang=%s-%s&text=%s", source_of(target), target, url_encode(text)),
			}
		end,
		parse = parse_yandex,
	},
	{
		name = "edge",
		trusted = true,
		request = function(text, target)
			local body = get_libs().JSON:encode({ escape_html(text) })
			return "POST", string.format(K.URL_EDGE, source_of(target), target), {
				headers = { ["Content-Type"] = "application/json" },
				data = body,
			}
		end,
		parse = parse_edge,
	},
	{
		name = "lingva1",
		request = get_request(function(text, target) return string.format(K.URL_LINGVA1, source_of(target), target, url_encode(text)) end),
		parse = parse_lingva,
	},
	{
		name = "lingva2",
		request = get_request(function(text, target) return string.format(K.URL_LINGVA2, source_of(target), target, url_encode(text)) end),
		parse = parse_lingva,
	},
	{
		name = "mymemory",
		request = get_request(function(text, target) return string.format(K.URL_BACKUP, url_encode(text), source_of(target), target) end),
		parse = parse_backup,
	},
}

local function next_provider(index)
	while index <= #PROVIDERS do
		local p = PROVIDERS[index]
		local allowed = p.name ~= "mymemory" or ui.mymemory:Get()
		local until_time = state.cooldown[p.name]
		if allowed and not (until_time and os.time() < until_time) then
			return p, index
		end
		index = index + 1
	end
	return nil, index
end

local run_chain

run_chain = function(name, text, target, key, on_done, index)
	local provider
	provider, index = next_provider(index)
	if not provider then
		log("no provider answered: " .. text)
		if on_done then on_done(nil) end
		return
	end
	if state.pending >= K.MAX_PENDING then
		log("dropped, too many pending requests")
		if on_done then on_done(nil) end
		return
	end

	state.pending = state.pending + 1
	log(provider.name .. " request: " .. text .. " -> " .. target)

	local method, url, opts = provider.request(text, target)
	local sent = HTTP.Request(method, url, opts, safe_cb(function(res)
		state.pending = math.max(0, state.pending - 1)
		local code = tostring(res.code)
		if ui.debug:Get() then
			log(provider.name .. " http " .. code .. " " .. tostring(res.response):sub(1, 160))
		end

		if code == "429" or code == "403" then
			state.cooldown[provider.name] = os.time() + K.COOLDOWN
			log(provider.name .. " paused for " .. K.COOLDOWN .. " s")
		elseif code ~= "200" then
			state.cooldown[provider.name] = os.time() + K.COOLDOWN_SHORT
		end

		local translated, src
		if code == "200" and res.response then
			local ok, t, l = pcall(provider.parse, res.response)
			if ok then
				translated, src = t, l
			else
				log_error(provider.name .. " parse: " .. tostring(t))
			end
		end

		if not translated or translated == "" then
			run_chain(name, text, target, key, on_done, index + 1)
			return
		end

		local same = translated:lower() == text:lower()
		if src == target or (same and provider.trusted) then
			cache_put(key, false)
			if on_done then on_done(nil) end
			return
		end
		if same then
			state.cooldown[provider.name] = os.time() + K.COOLDOWN
			log(provider.name .. " returned the text unchanged, paused")
			run_chain(name, text, target, key, on_done, index + 1)
			return
		end

		cache_put(key, translated)
		finish(name, translated, on_done)
	end))

	if not sent then
		state.pending = math.max(0, state.pending - 1)
		log(provider.name .. " request was not sent")
		run_chain(name, text, target, key, on_done, index + 1)
	end
end

local function lower_utf8(text)
	local ok, res = pcall(function()
		local out = {}
		for _, cp in utf8.codes(text) do
			if cp >= 65 and cp <= 90 then
				cp = cp + 32
			elseif cp >= 0x410 and cp <= 0x42F then
				cp = cp + 32
			elseif cp >= 0x400 and cp <= 0x40F then
				cp = cp + 80
			elseif cp == 0x451 then
				cp = 0x435
			end
			out[#out + 1] = utf8.char(cp)
		end
		return table.concat(out)
	end)
	if ok then return res end
	return text:lower()
end

local GLOSSARY = {
	ru = {
		phrases = {
			["good luck have fun"] = "удачи и веселой игры",
			["good luck"] = "удачи",
			["have fun"] = "веселой игры",
			["good game"] = "хорошая игра",
			["well played"] = "хорошо сыграно",
			["thank you"] = "спасибо",
			["no problem"] = "не за что",
			["nice try"] = "хорошая попытка",
			["good job"] = "хорошая работа",
			["my bad"] = "моя вина",
			["be right back"] = "скоро вернусь",
			["see you"] = "увидимся",
		},
		words = {
			gg = false, wp = false, gl = false, hf = false, glhf = false, nt = false, gj = false,
			ty = false, thx = false, tnx = false, np = false, ez = false, izi = false, rip = false,
			afk = false, lol = false, lmao = false, omg = false, wtf = false, brb = false, omw = false,
			gn = false, wb = false, mb = false, ff = false, sry = false, plz = false, pls = false,
			ok = false, okay = false, tp = false, bkb = false, cd = false, ult = false, mid = false,
			push = false, gank = false, smoke = false, rosh = false, roshan = false, noob = false,
			nub = false, feed = false, feeder = false, mute = false, report = false, idk = false,
			wow = false, yo = false,
			sorry = "извини", nice = "красиво", hi = "привет", hello = "привет", hey = "привет",
			bye = "пока", cya = "до встречи", yes = "да", yeah = "да", yep = "да", no = "нет", nope = "нет",
		},
	},
	en = {
		phrases = {
			["удачи и веселой игры"] = "gl hf",
			["удачи веселой игры"] = "gl hf",
			["хорошая игра"] = "gg",
			["хорошо сыграно"] = "wp",
			["гг вп"] = "gg wp",
			["не за что"] = "np",
			["моя вина"] = "my bad",
			["скоро вернусь"] = "brb",
			["спокойной ночи"] = "gn",
			["хорошая попытка"] = "nt",
			["хорошая работа"] = "gj",
			["до встречи"] = "cya",
			["всем привет"] = "hi everyone",
			["всем удачи"] = "gl everyone",
		},
		words = {
			["гг"] = "gg", ["вп"] = "wp", ["изи"] = "ez", ["спс"] = "ty", ["спасибо"] = "thanks",
			["пасиб"] = "thanks", ["удачи"] = "gl", ["нуб"] = "noob", ["афк"] = "afk", ["ку"] = "hi",
			["привет"] = "hi", ["хай"] = "hi", ["пока"] = "bye", ["да"] = "yes", ["нет"] = "no",
			["ок"] = "ok", ["окей"] = "ok", ["пж"] = "pls", ["плиз"] = "pls", ["пжлст"] = "pls",
			["лол"] = "lol", ["рип"] = "rip", ["нт"] = "nt", ["сорри"] = "sorry", ["извини"] = "sorry",
			["прости"] = "sorry", ["репорт"] = "report", ["мид"] = "mid", ["тп"] = "tp", ["бкб"] = "bkb",
			["ульта"] = "ult", ["кд"] = "cd", ["ганк"] = "gank", ["пуш"] = "push", ["рошан"] = "rosh",
			["смок"] = "smoke", ["фид"] = "feed", ["мут"] = "mute", ["ого"] = "wow",
		},
	},
}

local function glossary_translate(text, target)
	local g = GLOSSARY[target]
	if not g or #text > 60 then return nil end

	local tokens = {}
	for w in lower_utf8(text):gmatch("[%w'\128-\255]+") do
		tokens[#tokens + 1] = w
	end
	if #tokens == 0 or #tokens > 6 then return nil end

	local phrase = g.phrases[table.concat(tokens, " ")]
	if phrase then return phrase end

	local out = {}
	for _, w in ipairs(tokens) do
		local t = g.words[w]
		if t == nil then return nil end
		if t then out[#out + 1] = t end
	end
	if #out == 0 then return false end
	return table.concat(out, " ")
end

local function translate(name, text, target, on_done)
	local quick = glossary_translate(text, target)
	if quick ~= nil then
		log("glossary: " .. text)
		if quick then
			finish(name, quick, on_done)
		elseif on_done then
			on_done(nil)
		end
		return
	end

	local key = cache_key(text, target)
	local cached = state.cache[key]
	if cached ~= nil then
		log("cache hit: " .. text)
		if cached then
			finish(name, cached, on_done)
		elseif on_done then
			on_done(nil)
		end
		return
	end
	run_chain(name, text, target, key, on_done, 1)
end

local function handle_chat(msg)
	local libs = get_libs()
	local raw = libs.protobuf.decodeToJSONfromObject(msg.msg_object)
	log("chat: " .. tostring(raw))
	if not raw then return end

	local data = libs.JSON:decode(raw)
	local text = data and data.message_text
	if type(text) ~= "string" or text == "" or #text > K.MAX_BYTES then return end

	local id = tonumber(data.source_player_id) or -1
	if ui.skip_own:Get() and id == local_id() then return end

	local target = pick_target(text)
	if not target then
		log("skipped: " .. text)
		return
	end
	translate(player_name(id), text, target)
end

local function one_line(text)
	return (text:gsub("[\r\n]", " "))
end

local function sanitize(text)
	return (one_line(text):gsub("\"", "'"):gsub(";", ","))
end

local function say(channel, text)
	local libs = get_libs()
	state.sending = true
	local ok, sent = pcall(NetChannel.SendNetMessage, "CDOTAClientMsg_ChatMessage",
		libs.JSON:encode({ channel_type = channel, message_text = text }))
	state.sending = false
	if ok and sent then return end
	log("SendNetMessage failed: " .. tostring(sent) .. ", using the say command")
	state.sending = true
	local cmd = channel == 12 and "say_team" or "say"
	Engine.ExecuteCommand(cmd .. " \"" .. sanitize(text) .. "\"")
	state.sending = false
end

local function decode_outgoing(msg)
	local libs = get_libs()
	local errors = {}
	local function attempt(label, fn, ...)
		local ok, res = pcall(fn, ...)
		if ok and type(res) == "string" and res ~= "" then return res end
		errors[#errors + 1] = label .. ": " .. tostring(res)
		return nil
	end

	local names = { "CDOTAClientMsg_ChatMessage" }
	if type(msg.message_name) == "string" and msg.message_name ~= names[1] then
		names[2] = msg.message_name
	end
	for _, name in ipairs(names) do
		local raw = attempt("decodeToJSON " .. name, libs.protobuf.decodeToJSON, name, msg.buffer, msg.size)
		if raw then return raw end
	end
	for _, field in ipairs({ "buffer", "msg_object" }) do
		if msg[field] ~= nil then
			local raw = attempt("fromObject " .. field, libs.protobuf.decodeToJSONfromObject, msg[field])
			if raw then return raw end
		end
	end

	errors[#errors + 1] = "types: buffer=" .. type(msg.buffer) .. " size=" .. tostring(msg.size)
	return nil, table.concat(errors, " | ")
end

local function handle_outgoing(msg)
	if state.sending then return true end
	local libs = get_libs()
	local raw, why = decode_outgoing(msg)
	if not raw then
		log_error("send: cannot decode the outgoing chat message. " .. tostring(why))
		return true
	end
	log("send: " .. raw)

	local data = libs.JSON:decode(raw)
	if type(data) ~= "table" then return true end

	local text, channel = data.message_text, tonumber(data.channel_type)
	if type(text) ~= "string" or text == "" or #text > K.MAX_BYTES then return true end
	if channel ~= 11 and channel ~= 12 then
		log("send skipped: channel " .. tostring(channel))
		return true
	end

	if text:sub(1, 1) == "-" then
		log("send skipped: command")
		return true
	end

	local latin, cyr = count_letters(text)
	if not (cyr >= 2 and cyr > latin) then
		log("send skipped: not russian")
		return true
	end

	translate(player_name(local_id()), text, "en", function(translated)
		local out = one_line(translated or text)
		log("send out: " .. out)
		say(channel, out)
	end)
	return false
end

local script = {}

function script.OnSendNetMessage(msg)
	if ui.debug:Get() and not state.seen_send[msg.message_id] then
		state.seen_send[msg.message_id] = true
		Log.Write("[Chat Translator] outgoing message id " .. tostring(msg.message_id) .. " " .. tostring(msg.message_name))
	end
	if msg.message_id ~= K.MSG_SEND_CHAT then return true end
	if not ui.enable:Get() or not ui.own:Get() then return true end
	local ok, res = pcall(handle_outgoing, msg)
	if not ok then
		log_error("send: " .. tostring(res))
		return true
	end
	return res
end

function script.OnPostReceivedNetMessage(msg)
	if msg.message_id ~= K.MSG_CHAT then return end
	if not ui.enable:Get() then return end
	local ok, err = pcall(handle_chat, msg)
	if not ok then log_error("chat: " .. tostring(err)) end
end

return script
