--[[
	Tinker Smart Escape
	Author: sataroz
	Version: 1.0.0
	Made with Antigravity
]]

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

local VERSION = "1.0.0"

local localization = qLocalization.new({
	en = {
		tse_tab = "Tinker Escape",
		tse_group_main = "Main",
		tse_group_items = "Items & Skills",
		tse_enable = "Enable",
		tse_enable_tip = "Enables auto-escape for Tinker",
		tse_gear_extra = "Extra",
		tse_debug = "Debug log",
		tse_debug_tip = "Writes state transitions to debug.log",
		tse_key = "Escape key",
		tse_key_tip = "Hold to escape towards cursor",
		tse_bind_name = "Tinker Escape",
		tse_sequence = "Sequence",
		tse_sequence_tip = "Order of escape actions",
		tse_seq_smart = "Wind Waker / Glimmer -> Blink",
		tse_seq_blink_first = "Blink first -> WW / Glimmer",
		tse_visuals = "Visuals",
		tse_visuals_tip = "Shows escape line, status and Blink range",
		tse_items = "Escape items",
		tse_items_tip = "Select items to use during escape",
		tse_eblade_range = "Threat check radius",
		tse_eblade_range_tip = "Enemy scan radius for physical cores\nand magic nukers",
		tse_glimmer_break = "Glimmer break threshold",
		tse_glimmer_break_tip = "Seconds before invis ends to cast\nturrets and blink",
		tse_use_turrets = "Deploy Turrets push",
		tse_use_turrets_tip = "Casts turrets to knock Tinker\nforward towards cursor",
		tse_gear_turrets = "Turret settings",
		tse_turrets_offset = "Drop offset",
		tse_turrets_offset_tip = "0 = cast directly on self, > 0 = behind Tinker",
	},
	ru = {
		tse_tab = "Побег Тинкера",
		tse_group_main = "Основное",
		tse_group_items = "Предметы и навыки",
		tse_enable = "Включить",
		tse_enable_tip = "Включает авто-побег для Тинкера",
		tse_gear_extra = "Дополнительно",
		tse_debug = "Отладка в лог",
		tse_debug_tip = "Пишет состояние и действия в debug.log",
		tse_key = "Клавиша побега",
		tse_key_tip = "Зажми, чтобы начать побег к курсору",
		tse_bind_name = "Побег Тинкера",
		tse_sequence = "Порядок побега",
		tse_sequence_tip = "Очередность предметов при побеге",
		tse_seq_smart = "Wind Waker / Глиммер -> Блинк",
		tse_seq_blink_first = "Сначала Блинк -> затем WW / Глиммер",
		tse_visuals = "Отрисовка",
		tse_visuals_tip = "Показывает линию побега, статус и радиус блинка",
		tse_items = "Предметы для побега",
		tse_items_tip = "Выбор предметов для использования при побеге",
		tse_eblade_range = "Радиус проверки угроз",
		tse_eblade_range_tip = "Радиус поиска физ. коров\nи сильных магов",
		tse_glimmer_break = "Порог конца инвиза",
		tse_glimmer_break_tip = "За сколько секунд до конца инвиза\nсбрасывать турели и блинкаться",
		tse_use_turrets = "Турели для толчка",
		tse_use_turrets_tip = "Сбрасывает турели для толчка\nТинкера вперед к курсору",
		tse_gear_turrets = "Настройка турелей",
		tse_turrets_offset = "Смещение сброса",
		tse_turrets_offset_tip = "0 = прямо в себя, > 0 = позади Тинкера",
	},
})

local UI = localization.WrapLibrary(Menu)
local L = localization.Get

local K = {
	HERO_NAME = "npc_dota_hero_tinker",
	UPDATE_INTERVAL = 0.04,
	BLINK_ITEMS = {
		"item_blink",
		"item_arcane_blink",
		"item_swift_blink",
		"item_overwhelming_blink",
	},
	HEAVY_MAGIC_HEROES = {
		["npc_dota_hero_zuus"] = true,
		["npc_dota_hero_skywrath_mage"] = true,
		["npc_dota_hero_lion"] = true,
		["npc_dota_hero_lina"] = true,
		["npc_dota_hero_invoker"] = true,
		["npc_dota_hero_pugna"] = true,
		["npc_dota_hero_leshrac"] = true,
		["npc_dota_hero_necrolyte"] = true,
		["npc_dota_hero_queenofpain"] = true,
		["npc_dota_hero_storm_spirit"] = true,
		["npc_dota_hero_void_spirit"] = true,
		["npc_dota_hero_tinker"] = true,
		["npc_dota_hero_puck"] = true,
		["npc_dota_hero_sand_king"] = true,
		["npc_dota_hero_obsidian_destroyer"] = true,
		["npc_dota_hero_nevermore"] = true,
		["npc_dota_hero_crystal_maiden"] = true,
		["npc_dota_hero_jakiro"] = true,
		["npc_dota_hero_witch_doctor"] = true,
		["npc_dota_hero_disruptor"] = true,
		["npc_dota_hero_ancient_apparition"] = true,
		["npc_dota_hero_venomancer"] = true,
		["npc_dota_hero_viper"] = true,
		["npc_dota_hero_techies"] = true,
		["npc_dota_hero_earthshaker"] = true,
		["npc_dota_hero_snapfire"] = true,
		["npc_dota_hero_shredder"] = true,
		["npc_dota_hero_tiny"] = true,
		["npc_dota_hero_phoenix"] = true,
		["npc_dota_hero_primal_beast"] = true,
		["npc_dota_hero_rubick"] = true,
		["npc_dota_hero_shadow_shaman"] = true,
		["npc_dota_hero_warlock"] = true,
		["npc_dota_hero_ogre_magi"] = true,
		["npc_dota_hero_keeper_of_the_light"] = true,
		["npc_dota_hero_enigma"] = true,
		["npc_dota_hero_luna"] = true,
		["npc_dota_hero_batrider"] = true,
		["npc_dota_hero_dark_willow"] = true,
		["npc_dota_hero_gyrocopter"] = true,
	},
	PHYS_CORE_HEROES = {
		["npc_dota_hero_phantom_assassin"] = true,
		["npc_dota_hero_ursa"] = true,
		["npc_dota_hero_sven"] = true,
		["npc_dota_hero_juggernaut"] = true,
		["npc_dota_hero_antimage"] = true,
		["npc_dota_hero_drow_ranger"] = true,
		["npc_dota_hero_sniper"] = true,
		["npc_dota_hero_troll_warlord"] = true,
		["npc_dota_hero_slark"] = true,
		["npc_dota_hero_faceless_void"] = true,
		["npc_dota_hero_life_stealer"] = true,
		["npc_dota_hero_skeleton_king"] = true,
		["npc_dota_hero_chaos_knight"] = true,
		["npc_dota_hero_templar_assassin"] = true,
		["npc_dota_hero_monkey_king"] = true,
		["npc_dota_hero_marci"] = true,
		["npc_dota_hero_clinkz"] = true,
		["npc_dota_hero_riki"] = true,
		["npc_dota_hero_phantom_lancer"] = true,
		["npc_dota_hero_terrorblade"] = true,
		["npc_dota_hero_morphling"] = true,
		["npc_dota_hero_bloodseeker"] = true,
		["npc_dota_hero_weaver"] = true,
		["npc_dota_hero_medusa"] = true,
		["npc_dota_hero_spectre"] = true,
		["npc_dota_hero_alchemist"] = true,
		["npc_dota_hero_lycan"] = true,
		["npc_dota_hero_night_stalker"] = true,
		["npc_dota_hero_razor"] = true,
		["npc_dota_hero_legion_commander"] = true,
		["npc_dota_hero_windrunner"] = true,
		["npc_dota_hero_muerta"] = true,
		["npc_dota_hero_bristleback"] = true,
		["npc_dota_hero_dragon_knight"] = true,
		["npc_dota_hero_broodmother"] = true,
		["npc_dota_hero_meepo"] = true,
		["npc_dota_hero_kunkka"] = true,
		["npc_dota_hero_huskar"] = true,
		["npc_dota_hero_naga_siren"] = true,
		["npc_dota_hero_lone_druid"] = true,
		["npc_dota_hero_beastmaster"] = true,
		["npc_dota_hero_slardar"] = true,
		["npc_dota_hero_magnataur"] = true,
		["npc_dota_hero_abaddon"] = true,
		["npc_dota_hero_dawnbreaker"] = true,
	},
}

local ui = {}

do
	local tab = UI.Create("Heroes", "Hero List", "Tinker")
	local page = tab:Create("Smart Escape")
	pcall(page.Icon, page, "\u{f135}")

	local g_main = page:Create("tse_group_main", Enum.GroupSide.Left)
	local g_items = page:Create("tse_group_items", Enum.GroupSide.Right)

	ui.enable = g_main:Switch("tse_enable", false, "\u{f011}")
	ui.enable:ToolTip("tse_enable_tip")
	local g_extra = ui.enable:Gear("tse_gear_extra")
	ui.debug = g_extra:Switch("tse_debug", false, "\u{f188}")
	ui.debug:ToolTip("tse_debug_tip")

	ui.key = g_main:Bind("tse_key", Enum.ButtonCode.KEY_NONE, "\u{f11c}")
	ui.key:ToolTip("tse_key_tip")
	ui.key:Properties(L("tse_bind_name"))

	ui.sequence = g_main:Combo("tse_sequence", { "tse_seq_smart", "tse_seq_blink_first" }, 0)
	ui.sequence:Icon("\u{f0cb}")
	ui.sequence:ToolTip("tse_sequence_tip")

	ui.visuals = g_main:Switch("tse_visuals", true, "\u{f06e}")
	ui.visuals:ToolTip("tse_visuals_tip")

	local ESCAPE_ITEMS = {
		{ "item_blink", "panorama/images/items/blink_png.vtex_c", true },
		{ "item_wind_waker", "panorama/images/items/wind_waker_png.vtex_c", true },
		{ "item_glimmer_cape", "panorama/images/items/glimmer_cape_png.vtex_c", true },
		{ "item_ethereal_blade", "panorama/images/items/ethereal_blade_png.vtex_c", true },
		{ "item_crellas_crozier", "panorama/images/items/crellas_crozier_png.vtex_c", true },
		{ "item_ghost", "panorama/images/items/ghost_png.vtex_c", true },
		{ "item_cyclone", "panorama/images/items/cyclone_png.vtex_c", true },
		{ "item_force_staff", "panorama/images/items/force_staff_png.vtex_c", true },
		{ "item_phase_boots", "panorama/images/items/phase_boots_png.vtex_c", true },
	}

	ui.items = g_items:MultiSelect("tse_items", ESCAPE_ITEMS, true)
	ui.items:Icon("\u{f0ca}")
	ui.items:ToolTip("tse_items_tip")

	ui.eblade_range = g_items:Slider("tse_eblade_range", 800, 2500, 1500, "%d")
	ui.eblade_range:Icon("\u{f1ce}")
	ui.eblade_range:ToolTip("tse_eblade_range_tip")

	ui.glimmer_break = g_items:Slider("tse_glimmer_break", 0.1, 1.0, 0.4, "%.1fs")
	ui.glimmer_break:Icon("\u{f017}")
	ui.glimmer_break:ToolTip("tse_glimmer_break_tip")

	ui.use_turrets = g_items:Switch("tse_use_turrets", true, "\u{f135}")
	ui.use_turrets:ToolTip("tse_use_turrets_tip")
	local g_turrets = ui.use_turrets:Gear("tse_gear_turrets")
	ui.turrets_offset = g_turrets:Slider("tse_turrets_offset", 0, 120, 0, "%d")
	ui.turrets_offset:Icon("\u{f337}")
	ui.turrets_offset:ToolTip("tse_turrets_offset_tip")
end

local function is_item_enabled(name)
	return ui.items and ui.items:Get(name) == true
end

local function refresh_disabled()
	local on = ui.enable:Get()
	ui.key:Disabled(not on)
	ui.debug:Disabled(not on)
	ui.sequence:Disabled(not on)
	ui.visuals:Disabled(not on)
	ui.items:Disabled(not on)
	local has_ethereal = is_item_enabled("item_ethereal_blade") or is_item_enabled("item_crellas_crozier") or is_item_enabled("item_ghost")
	ui.eblade_range:Disabled(not on or not has_ethereal)
	ui.glimmer_break:Disabled(not on or not is_item_enabled("item_glimmer_cape"))
	ui.use_turrets:Disabled(not on)
	ui.turrets_offset:Disabled(not on or not ui.use_turrets:Get())
end

ui.enable:SetCallback(refresh_disabled, true)
ui.items:SetCallback(refresh_disabled)
ui.use_turrets:SetCallback(refresh_disabled)

local state = {
	next_run = 0,
	next_move = 0,
	last_action_time = 0,
	glimmer_cast_time = 0,
	turrets_cast_time = 0,
	blink_cast_time = 0,
	is_escaping = false,
	status_text = "",
	last_logged_text = "",
	draw_error = nil,
}

local font_status = nil

local function get_font()
	if not font_status then
		font_status = Render.LoadFont("Segoe UI", Enum.FontCreate.FONTFLAG_ANTIALIAS, 600)
	end
	return font_status
end

local function log(text)
	if ui.debug:Get() and text ~= state.last_logged_text then
		state.last_logged_text = text
		Log.Write("[Tinker Escape] " .. text)
	end
end

local function get_blink_item(hero)
	for i = 1, #K.BLINK_ITEMS do
		local item = NPC.GetItem(hero, K.BLINK_ITEMS[i])
		if item then
			return item
		end
	end
	return nil
end

local function get_cyclone_modifier(hero)
	local mods = NPC.GetModifiers(hero)
	for i = 1, #mods do
		local mod = mods[i]
		if mod and Modifier.GetDuration(mod) > 0 then
			local name = Modifier.GetName(mod)
			if name and (name == "modifier_wind_waker" or name == "modifier_eul_cyclone" or name == "modifier_cyclone" or name:find("cyclone", 1, true)) then
				return mod, name
			end
		end
	end
	return nil, nil
end

local function get_glimmer_modifier(hero)
	local mods = NPC.GetModifiers(hero)
	for i = 1, #mods do
		local mod = mods[i]
		if mod and Modifier.GetDuration(mod) > 0 then
			local name = Modifier.GetName(mod)
			if name and (name == "modifier_item_glimmer_cape_fade" or name:find("glimmer_cape_fade", 1, true)) then
				return mod
			end
		end
	end
	return nil
end

local function is_revealed_by_sentry_or_truesight(hero, now, glimmer_mod)
	if glimmer_mod then
		local creation = Modifier.GetCreationTime(glimmer_mod) or 0
		local elapsed = creation > 0 and (now - creation) or 1.0
		if elapsed >= 0.6 and NPC.IsVisibleToEnemies(hero) then
			return true
		end
	elseif NPC.IsVisibleToEnemies(hero) then
		return true
	end

	local mods = NPC.GetModifiers(hero)
	for i = 1, #mods do
		local mod = mods[i]
		if mod then
			local name = Modifier.GetName(mod)
			if name and (name == "modifier_truesight"
				or name:find("truesight", 1, true)
				or name:find("dust", 1, true)
				or name == "modifier_bounty_hunter_track"
				or name == "modifier_slardar_amplify_damage") then
				return true
			end
		end
	end

	local hero_pos = Entity.GetAbsOrigin(hero)
	local hero_team = Entity.GetTeamNum(hero)
	local nearby = NPCs.InRadius(hero_pos, 1000, hero_team, Enum.TeamType.TEAM_ENEMY, true, true)
	for i = 1, #nearby do
		local u = nearby[i]
		if u and Entity.IsAlive(u) then
			local uname = NPC.GetUnitName(u)
			if uname and (uname == "npc_dota_sentry_wards" or uname:find("sentry", 1, true) or NPC.IsTower(u)) then
				return true
			elseif NPC.IsHero(u) and NPC.GetItem(u, "item_gem") then
				return true
			end
		end
	end

	return false
end

local function is_ethereal(hero)
	local mods = NPC.GetModifiers(hero)
	for i = 1, #mods do
		local mod = mods[i]
		if mod and Modifier.GetDuration(mod) > 0 then
			local name = Modifier.GetName(mod)
			if name and (name == "modifier_ghost_state" or name:find("ethereal", 1, true) or name:find("crella", 1, true)) then
				return true
			end
		end
	end
	return false
end

local function should_cast_ethereal(hero, range)
	local hero_pos = Entity.GetAbsOrigin(hero)
	local hero_team = Entity.GetTeamNum(hero)
	local has_phys_core = false
	local has_heavy_magic = false
	local enemy_count = 0

	local all_heroes = Heroes.GetAll()
	for i = 1, #all_heroes do
		local e = all_heroes[i]
		if e and e ~= hero and Entity.IsAlive(e) and not Entity.IsDormant(e) and Entity.GetTeamNum(e) ~= hero_team then
			local e_pos = Entity.GetAbsOrigin(e)
			local d = hero_pos:Distance2D(e_pos)
			if d <= range then
				enemy_count = enemy_count + 1
				local name = NPC.GetUnitName(e)
				if K.PHYS_CORE_HEROES[name] then
					has_phys_core = true
				end
				if K.HEAVY_MAGIC_HEROES[name] then
					has_heavy_magic = true
				end
			end
		end
	end

	if enemy_count == 0 then
		return false
	end

	if has_phys_core then
		return true
	end

	if not has_heavy_magic then
		return true
	end

	return false
end

local function cast_blink(hero, blink, hero_pos, cursor_pos, dir)
	local max_range = Ability.GetCastRange(blink) + NPC.GetCastRangeBonus(hero)
	local dist = hero_pos:Distance2D(cursor_pos)
	local target = cursor_pos
	if dist > max_range then
		target = hero_pos + dir * max_range
	end
	Ability.CastPosition(blink, target)
	state.blink_cast_time = GameRules.GetGameTime()
	state.next_move = state.blink_cast_time + 0.04
end

local function move_hero(hero, move_pos, now)
	if now >= state.next_move then
		NPC.MoveTo(hero, move_pos)
		state.next_move = now + 0.09
	end
end

local function draw_world_circle(center, radius, color, segments)
	segments = segments or 32
	local pts = {}
	local step = (math.pi * 2) / segments
	for i = 0, segments - 1 do
		local a = i * step
		local p = Vector(center.x + math.cos(a) * radius, center.y + math.sin(a) * radius, center.z)
		local s_pos, vis = Render.WorldToScreen(p)
		if not vis then return end
		pts[#pts + 1] = s_pos
	end
	if #pts > 2 then
		Render.PolyLine(pts, color, 1.2)
	end
end

local function draw_overlay(hero)
	if not ui.visuals:Get() then return end
	if not state.is_escaping then return end

	local hero_pos = Entity.GetAbsOrigin(hero)
	local cursor_pos = Input.GetWorldCursorPos()
	local s_hero, h_vis = Render.WorldToScreen(hero_pos)
	local s_cur, c_vis = Render.WorldToScreen(cursor_pos)

	if h_vis and c_vis then
		Render.Line(s_hero, s_cur, Color(100, 200, 255, 140), 1.5)
	end

	if h_vis and state.status_text ~= "" then
		local font = get_font()
		local text = state.status_text
		local size = Render.TextSize(font, 12, text)
		local pad_x = 6
		local pad_y = 2
		local y_offset = 24
		local box_start = Vec2(s_hero.x - size.x * 0.5 - pad_x, s_hero.y + y_offset - pad_y)
		local box_end = Vec2(s_hero.x + size.x * 0.5 + pad_x, s_hero.y + y_offset + size.y + pad_y)

		Render.FilledRect(box_start, box_end, Color(16, 20, 28, 200), 4)
		Render.Rect(box_start, box_end, Color(80, 160, 240, 120), 4, Enum.DrawFlags.None, 1)
		Render.Text(font, 12, text, Vec2(s_hero.x - size.x * 0.5, s_hero.y + y_offset), Color(240, 245, 255, 240))
	end

	if is_item_enabled("item_blink") then
		local blink = get_blink_item(hero)
		if blink then
			local max_range = Ability.GetCastRange(blink) + NPC.GetCastRangeBonus(hero)
			local can_blink = Ability.IsCastable(blink, NPC.GetMana(hero)) and not NPC.HasState(hero, Enum.ModifierState.MODIFIER_STATE_ROOTED)
			local col = can_blink and Color(80, 220, 120, 60) or Color(220, 80, 80, 40)
			draw_world_circle(hero_pos, max_range, col, 36)
		end
	end
end

local script = {}

function script.OnUpdate()
	if not ui.enable:Get() then return end

	local now = GameRules.GetGameTime()
	local key = ui.key:Get()
	local key_down = (ui.key:IsDown() or (key ~= Enum.ButtonCode.KEY_NONE and Input.IsKeyDown(key))) and not Input.IsInputCaptured()

	if ui.key:IsToggled() then
		ui.key:SetToggled(false)
	end

	if not key_down then
		if state.is_escaping then
			state.is_escaping = false
			state.status_text = ""
			log("escape stopped")
		end
		return
	end

	local hero = Heroes.GetLocal()
	if not hero or not Entity.IsAlive(hero) then return end
	if NPC.GetUnitName(hero) ~= K.HERO_NAME then return end

	if now < state.next_run then return end
	state.next_run = now + K.UPDATE_INTERVAL

	local hero_pos = Entity.GetAbsOrigin(hero)
	local cursor_pos = Input.GetWorldCursorPos()
	local dist = hero_pos:Distance2D(cursor_pos)
	local dir
	if dist > 20 then
		dir = Vector(cursor_pos.x - hero_pos.x, cursor_pos.y - hero_pos.y, 0):Normalized()
	else
		local forward = Entity.GetRotation(hero):GetForward()
		dir = Vector(forward.x, forward.y, 0):Normalized()
	end
	local move_pos = dist >= 50 and cursor_pos or (hero_pos + dir * 300)
	local mana = NPC.GetMana(hero)
	state.is_escaping = true

	local cyclone_mod, cyclone_name = get_cyclone_modifier(hero)
	if cyclone_mod then
		local is_ww = cyclone_name == "modifier_wind_waker"
		local rem = math.max(0, Modifier.GetDieTime(cyclone_mod) - now)
		state.status_text = is_ww and string.format("WIND WAKER (%.1fs)", rem) or string.format("CYCLONE (%.1fs)", rem)

		if is_ww then
			move_hero(hero, move_pos, now)
		end

		if is_item_enabled("item_blink") then
			local blink = get_blink_item(hero)
			if blink and Ability.IsCastable(blink, mana) and not NPC.HasState(hero, Enum.ModifierState.MODIFIER_STATE_ROOTED) then
				if is_ww or rem <= 0.25 then
					cast_blink(hero, blink, hero_pos, cursor_pos, dir)
					log(is_ww and "blink inside wind waker" or "blink on cyclone exit")
					state.status_text = "BLINK"
					return
				end
			end
		end
		return
	end

	local glimmer_mod = get_glimmer_modifier(hero)
	local glimmer_revealed = false
	local glimmer_rem = 0
	if glimmer_mod then
		glimmer_rem = math.max(0, Modifier.GetDieTime(glimmer_mod) - now)
		glimmer_revealed = is_revealed_by_sentry_or_truesight(hero, now, glimmer_mod)

		if glimmer_revealed then
			state.status_text = string.format("GLIMMER REVEALED (%.1fs)", glimmer_rem)
			log("glimmer revealed on sentry/truesight")
		else
			state.status_text = string.format("GLIMMER (%.1fs)", glimmer_rem)
		end
	end

	if NPC.HasState(hero, Enum.ModifierState.MODIFIER_STATE_STUNNED)
		or NPC.HasState(hero, Enum.ModifierState.MODIFIER_STATE_HEXED)
		or NPC.HasState(hero, Enum.ModifierState.MODIFIER_STATE_NIGHTMARED)
		or NPC.HasState(hero, Enum.ModifierState.MODIFIER_STATE_FEARED)
		or NPC.HasState(hero, Enum.ModifierState.MODIFIER_STATE_TAUNTED)
		or NPC.HasState(hero, Enum.ModifierState.MODIFIER_STATE_OUT_OF_GAME)
		or NPC.HasState(hero, Enum.ModifierState.MODIFIER_STATE_COMMAND_RESTRICTED) then
		state.status_text = "DISABLED"
		return
	end

	local blink_first = ui.sequence:Get() == 1

	if blink_first and is_item_enabled("item_blink") then
		local blink = get_blink_item(hero)
		if blink and Ability.IsCastable(blink, mana) and not NPC.HasState(hero, Enum.ModifierState.MODIFIER_STATE_ROOTED) then
			cast_blink(hero, blink, hero_pos, cursor_pos, dir)
			log("instant blink")
			state.status_text = "BLINK"
			return
		end
	end

	local eul_item = is_item_enabled("item_cyclone") and NPC.GetItem(hero, "item_cyclone")
	local has_eul = eul_item and Ability.IsCastable(eul_item, mana)

	local ww_item = is_item_enabled("item_wind_waker") and NPC.GetItem(hero, "item_wind_waker")
	local has_ww = ww_item and Ability.IsCastable(ww_item, mana)

	local has_cyclone = (eul_item and (has_eul or Ability.GetCooldown(eul_item) <= 3.5))
		or (ww_item and (has_ww or Ability.GetCooldown(ww_item) <= 3.5))

	if has_ww and (now - state.turrets_cast_time > 2.5) then
		Ability.CastTarget(ww_item, hero)
		state.next_move = now + 0.08
		log("cast wind waker")
		state.status_text = "WIND WAKER"
		return
	end

	if not glimmer_mod and is_item_enabled("item_glimmer_cape") then
		local glimmer = NPC.GetItem(hero, "item_glimmer_cape")
		if glimmer and Ability.IsCastable(glimmer, mana) then
			Ability.CastTarget(glimmer, hero)
			state.glimmer_cast_time = now
			state.next_move = now + 0.08
			log("cast glimmer cape")
			state.status_text = "GLIMMER"
			return
		end
	end

	if not blink_first and is_item_enabled("item_blink") then
		local blink = get_blink_item(hero)
		if blink and Ability.IsCastable(blink, mana) and not NPC.HasState(hero, Enum.ModifierState.MODIFIER_STATE_ROOTED) then
			cast_blink(hero, blink, hero_pos, cursor_pos, dir)
			log("instant blink")
			state.status_text = "BLINK"
			return
		end
	end

	if not is_ethereal(hero) then
		local eblade = is_item_enabled("item_ethereal_blade") and NPC.GetItem(hero, "item_ethereal_blade") or nil
		local crella = is_item_enabled("item_crellas_crozier") and NPC.GetItem(hero, "item_crellas_crozier") or nil
		local ghost = is_item_enabled("item_ghost") and NPC.GetItem(hero, "item_ghost") or nil
		local item = eblade or crella or ghost
		if item and Ability.IsCastable(item, mana) then
			if should_cast_ethereal(hero, ui.eblade_range:Get()) then
				if item == eblade then
					Ability.CastTarget(eblade, hero)
				else
					Ability.CastNoTarget(item)
				end
				state.next_move = now + 0.08
				log("cast ghost/eblade/crella on self")
				state.status_text = "ETHEREAL"
				return
			end
		end
	end

	local is_invisible = (glimmer_mod ~= nil) or NPC.HasState(hero, Enum.ModifierState.MODIFIER_STATE_INVISIBLE)
	local eul_allowed = (not is_invisible) or glimmer_revealed

	if eul_allowed and has_eul and (now - state.turrets_cast_time > 2.5) then
		local blink = get_blink_item(hero)
		local blink_cd = blink and Ability.GetCooldown(blink) or 0
		if blink and (blink_cd > 0 and blink_cd <= 3.0) then
			Ability.CastTarget(eul_item, hero)
			state.next_move = now + 0.08
			log("cast self eul")
			state.status_text = "SELF EUL"
			return
		end
	end

	if not has_cyclone and ui.use_turrets:Get() and (now - state.turrets_cast_time > 1.5) then
		local blink = get_blink_item(hero)
		local blink_cd = blink and Ability.GetCooldown(blink) or 0
		if not blink or blink_cd > 0.5 then
			local turrets = NPC.GetAbility(hero, "tinker_deploy_turrets")
			if turrets and Ability.IsCastable(turrets, mana) then
				local offset = ui.turrets_offset:Get()
				local drop_pos = offset > 0 and (hero_pos - dir * offset) or (hero_pos - dir * 50)
				Ability.CastPosition(turrets, drop_pos)
				state.turrets_cast_time = now
				state.next_move = now + 0.15
				log("cast turrets knockback")
				state.status_text = "TURRET PUSH"
				return
			end
		end
	end

	if is_item_enabled("item_force_staff") then
		local force = NPC.GetItem(hero, "item_force_staff") or NPC.GetItem(hero, "item_hurricane_pike")
		if force and Ability.IsCastable(force, mana) and not NPC.HasState(hero, Enum.ModifierState.MODIFIER_STATE_ROOTED) then
			local forward = Entity.GetRotation(hero):GetForward()
			if forward:Dot(dir) > 0.85 then
				Ability.CastTarget(force, hero)
				log("cast force staff")
				state.status_text = "FORCE"
			end
		end
	end

	if is_item_enabled("item_phase_boots") then
		local phase = NPC.GetItem(hero, "item_phase_boots")
		if phase and Ability.IsCastable(phase, 0) then
			Ability.CastNoTarget(phase)
		end
	end

	move_hero(hero, move_pos, now)
	if is_ethereal(hero) then
		state.status_text = "ETHEREAL RUN"
	elseif glimmer_mod then
		state.status_text = glimmer_revealed and string.format("GLIMMER REVEALED (%.1fs)", glimmer_rem)
			or string.format("GLIMMER (%.1fs)", glimmer_rem)
	else
		state.status_text = "RUNNING"
	end
end

function script.OnDraw()
	if not ui.enable:Get() then return end
	local hero = Heroes.GetLocal()
	if not hero or not Entity.IsAlive(hero) then return end
	if NPC.GetUnitName(hero) ~= K.HERO_NAME then return end

	local ok, err = pcall(draw_overlay, hero)
	if not ok and err ~= state.draw_error then
		state.draw_error = err
		Log.Write("[Tinker Escape] draw error: " .. tostring(err))
	end
end

return script
