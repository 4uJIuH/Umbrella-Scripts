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
		oc_group_main = "Main",
		oc_group_way = "Reaction",
		oc_enable = "Enable",
		oc_enable_tip = "Io casts Overcharge the moment the tethered\nally uses an ultimate",
		oc_gear_extra = "Extra",
		oc_debug = "Debug log",
		oc_debug_tip = "Writes tether and trigger info to the log",
		oc_heroes = "Allies to support",
		oc_mana = "Minimum mana",
		oc_mana_tip = "Overcharge is not cast if Io has less mana\nthan this percent of the pool",
		oc_delay = "Reaction delay",
		oc_delay_tip = "Random delay from 0 up to this value",
		oc_fight = "Only in a fight",
		oc_fight_tip = "Needs an enemy hero near the tethered ally",
		oc_gear_fight = "Fight radius",
		oc_fight_radius = "Radius",
	},
	ru = {
		oc_group_main = "Основное",
		oc_group_way = "Реакция",
		oc_enable = "Включить",
		oc_enable_tip = "Io жмет Overcharge в момент, когда тизернутый\nсоюзник использует ультимейт",
		oc_gear_extra = "Дополнительно",
		oc_debug = "Отладка в лог",
		oc_debug_tip = "Пишет в лог данные о тизере и срабатываниях",
		oc_heroes = "Кого усиливать",
		oc_mana = "Порог маны",
		oc_mana_tip = "Overcharge не жмется, если у Io маны меньше\nэтого процента от максимума",
		oc_delay = "Задержка реакции",
		oc_delay_tip = "Случайная задержка от 0 до этого значения",
		oc_fight = "Только в файте",
		oc_fight_tip = "Нужен вражеский герой рядом с тизернутым союзником",
		oc_gear_fight = "Радиус файта",
		oc_fight_radius = "Радиус",
	},
})

local UI = localization.WrapLibrary(Menu)
local L = localization.Get

local VERSION = "1.0.0"
local script = {}

local HERO_NAME = "npc_dota_hero_wisp"
local MENU_HERO = "Io"
local OVERCHARGE = "wisp_overcharge"
local TETHER_MARK = "wisp_tether"

local CARRIES = {
	{ "npc_dota_hero_juggernaut", { "juggernaut_omni_slash", "juggernaut_swift_slash" } },
	{ "npc_dota_hero_faceless_void", { "faceless_void_chronosphere" } },
	{ "npc_dota_hero_void_spirit", { "void_spirit_astral_step" } },
	{ "npc_dota_hero_sven", { "sven_gods_strength" } },
	{ "npc_dota_hero_bloodseeker", { "bloodseeker_rupture" } },
	{ "npc_dota_hero_luna", { "luna_eclipse" } },
	{ "npc_dota_hero_kez", { "kez_raptor_dance", "kez_ravens_veil" } },
	{ "npc_dota_hero_sniper", { "sniper_assassinate" } },
	{ "npc_dota_hero_medusa", { "medusa_stone_gaze" } },
	{ "npc_dota_hero_chaos_knight", { "chaos_knight_phantasm" } },
	{ "npc_dota_hero_monkey_king", { "monkey_king_wukongs_command" } },
	{ "npc_dota_hero_huskar", { "huskar_life_break" } },
	{ "npc_dota_hero_windrunner", { "windrunner_focusfire" } },
	{ "npc_dota_hero_spirit_breaker", { "spirit_breaker_nether_strike" } },
	{ "npc_dota_hero_marci", { "marci_unleash" } },
	{ "npc_dota_hero_beastmaster", { "beastmaster_primal_roar" } },
	{ "npc_dota_hero_viper", { "viper_viper_strike" } },
	{ "npc_dota_hero_zuus", { "zuus_thundergods_wrath" } },
	{ "npc_dota_hero_skywrath_mage", { "skywrath_mage_mystic_flare" } },
	{ "npc_dota_hero_queenofpain", { "queenofpain_sonic_wave" } },
	{ "npc_dota_hero_obsidian_destroyer", { "obsidian_destroyer_sanity_eclipse" } },
	{ "npc_dota_hero_puck", { "puck_dream_coil" } },
	{ "npc_dota_hero_lina", { "lina_laguna_blade" } },
}

local KEYS = {}
for _, entry in ipairs(CARRIES) do
	local set = {}
	for _, ability_name in ipairs(entry[2]) do
		set[ability_name] = true
	end
	KEYS[entry[1]] = set
end

local ui = {}

do
	local hero_tab = UI.Find("Heroes", "Hero List", MENU_HERO)
	local page = hero_tab and (hero_tab:Find("Overcharge") or hero_tab:Create("Overcharge"))
	if not page then
		local tab = UI.Create("Scripts", "Scripts", "Io Overcharge")
		tab:Icon("\u{f0e7}")
		page = tab:Create("Settings")
	end

	local g_main = page:Create("oc_group_main", Enum.GroupSide.Left)
	local g_way = page:Create("oc_group_way", Enum.GroupSide.Right)

	ui.hero_enable = Menu.Find("Heroes", "Hero List", MENU_HERO, "Main Settings", "Hero Settings", "Enable")

	ui.enable = g_main:Switch("oc_enable", false, "\u{f011}")
	ui.enable:ToolTip("oc_enable_tip")
	local g_extra = ui.enable:Gear("oc_gear_extra")
	ui.debug = g_extra:Switch("oc_debug", false, "\u{f188}")
	ui.debug:ToolTip("oc_debug_tip")

	local items = {}
	for i, entry in ipairs(CARRIES) do
		local name = entry[1]
		items[i] = { name, "panorama/images/heroes/icons/" .. name .. "_png.vtex_c", true }
	end
	ui.heroes = g_main:MultiSelect("oc_heroes", items, false)
	ui.heroes:Icon("\u{f05b}")

	ui.mana = g_way:Slider("oc_mana", 0, 100, 20, "%d%%")
	ui.mana:Icon("\u{f043}")
	ui.mana:ToolTip("oc_mana_tip")

	ui.delay = g_way:Slider("oc_delay", 0, 300, 40, "%d ms")
	ui.delay:Icon("\u{f017}")
	ui.delay:ToolTip("oc_delay_tip")

	ui.fight = g_way:Switch("oc_fight", true, "\u{f1ce}")
	ui.fight:ToolTip("oc_fight_tip")
	local g_fight = ui.fight:Gear("oc_gear_fight")
	ui.fight_radius = g_fight:Slider("oc_fight_radius", 600, 2000, 1200, "%d")
	ui.fight_radius:Icon("\u{f1ce}")
end

local function refresh_disabled()
	local on = ui.enable:Get()
	ui.heroes:Disabled(not on)
	ui.mana:Disabled(not on)
	ui.delay:Disabled(not on)
	ui.fight:Disabled(not on)
	ui.fight_radius:Disabled(not on or not ui.fight:Get())
	ui.debug:Disabled(not on)
end

ui.enable:SetCallback(refresh_disabled, true)
ui.fight:SetCallback(refresh_disabled)

local state = {
	seen = {},
	pending = nil,
	next_scan = 0,
	tether_idx = nil,
	last_note = 0,
	last_trigger = {},
}

local function active()
	return ui.enable:Get() and (not ui.hero_enable or ui.hero_enable:Get())
end

local function note(text)
	if ui.debug:Get() then
		Log.Write("[Io Overcharge] " .. text)
	end
end

local function reset()
	state.seen = {}
	state.pending = nil
	state.tether_idx = nil
	state.last_trigger = {}
end

local function find_tethered(hero)
	local hero_idx = Entity.GetIndex(hero)
	for _, ally in ipairs(Heroes.GetAll()) do
		local ally_idx = Entity.GetIndex(ally)
		if ally_idx ~= hero_idx and Entity.IsSameTeam(ally, hero) and Entity.IsAlive(ally) and not NPC.IsIllusion(ally) then
			for _, mod in ipairs(NPC.GetModifiers(ally)) do
				if string.find(Modifier.GetName(mod), TETHER_MARK, 1, true) then
					local caster = Modifier.GetCaster(mod)
					if caster == nil or Entity.GetIndex(caster) == hero_idx then
						return ally
					end
				end
			end
		end
	end
	return nil
end

local function enemy_near(ally)
	local pos = Entity.GetAbsOrigin(ally)
	local radius = ui.fight_radius:Get()
	for _, other in ipairs(Heroes.GetAll()) do
		if not Entity.IsSameTeam(other, ally) and Entity.IsAlive(other) and not Entity.IsDormant(other) then
			if pos:Distance2D(Entity.GetAbsOrigin(other)) <= radius then
				return true
			end
		end
	end
	return false
end

local function mana_ok(hero)
	local max_mana = NPC.GetMaxMana(hero)
	if max_mana <= 0 then
		return false
	end
	return NPC.GetMana(hero) / max_mana * 100 >= ui.mana:Get()
end

local function observe(mem, ab, name, is_key)
	if not is_key then
		return false
	end

	-- Keep several independent signals. Some instant ultimates can
	-- enter/leave ability phase between two frames, while their cooldown
	-- changes reliably after the cast.
	local cur_cd = Ability.GetCooldown(ab)
	local cur = {
		phase = Ability.IsInAbilityPhase(ab),
		chan = Ability.IsChannelling(ab),
		cd = cur_cd,
	}

	local prev = mem[name]
	mem[name] = cur

	-- First observation only initializes the state.
	if not prev then
		return false
	end

	-- 1) Ability phase started.
	if cur.phase and not prev.phase then
		return true
	end

	-- 2) Channel started.
	if cur.chan and not prev.chan then
		return true
	end

	-- 3) Cooldown appeared.
	if cur.cd > 0.05 and prev.cd <= 0.05 then
		return true
	end

	-- 4) Cooldown jumped upward. This is important for instant-cast
	-- ultimates whose ability-phase window can be missed.
	if cur.cd > prev.cd + 0.05 then
		return true
	end

	return false
end

local function scan(ally)
	local idx = Entity.GetIndex(ally)
	local mem = state.seen[idx]
	if not mem then
		mem = {}
		state.seen[idx] = mem
	end

	local keys = KEYS[NPC.GetUnitName(ally)] or {}
	for i = 0, 31 do
		local ab = NPC.GetAbilityByIndex(ally, i)
		if ab then
			local name = Ability.GetName(ab)
			if name ~= "generic_hidden" then
				local is_key = keys[name] == true or Ability.IsUltimate(ab)
				if observe(mem, ab, name, is_key) then
					return name
				end
			end
		end
	end
	return nil
end

local function try_overcharge(hero)
	local ab = NPC.GetAbility(hero, OVERCHARGE)
	if not ab or Ability.GetLevel(ab) < 1 then
		return false
	end
	if NPC.IsStunned(hero) or NPC.IsSilenced(hero) then
		return false
	end
	if not mana_ok(hero) then
		return false
	end
	if not Ability.IsReady(ab) or not Ability.IsCastable(ab, NPC.GetMana(hero)) then
		return false
	end
	Ability.CastNoTarget(ab)
	return true
end

function script.OnUpdate()
	if not active() then
		return
	end

	local hero = Heroes.GetLocal()
	if not hero or NPC.GetUnitName(hero) ~= HERO_NAME or not Entity.IsAlive(hero) then
		reset()
		return
	end

	local now = GameRules.GetGameTime()

	if state.pending and now >= state.pending.at then
		if try_overcharge(hero) then
			note("Overcharge cast")
			state.pending = nil
		elseif now >= state.pending.expire then
			note("Overcharge not castable, dropped")
			state.pending = nil
		end
	end

	if now < state.next_scan then
		return
	end
	state.next_scan = now + 0.03

	local ally = find_tethered(hero)
	local ally_idx = ally and Entity.GetIndex(ally) or nil
	if ally_idx ~= state.tether_idx then
		state.tether_idx = ally_idx
		note("tether target: " .. (ally and NPC.GetUnitName(ally) or "none"))
	end
	if not ally then
		state.seen = {}
		if ui.debug:Get() and now - state.last_note > 4 then
			state.last_note = now
			local found = {}
			for _, mod in ipairs(NPC.GetModifiers(hero)) do
				local mod_name = Modifier.GetName(mod)
				if string.find(mod_name, "wisp", 1, true) then
					found[#found + 1] = mod_name
				end
			end
			note("no tethered ally, wisp modifiers on Io: " .. table.concat(found, ", "))
		end
		return
	end

	if not ui.heroes:Get(NPC.GetUnitName(ally)) then
		return
	end

	local key = scan(ally)
	if not key or state.pending then
		return
	end
	if ui.fight:Get() and not enemy_near(ally) then
		note("trigger " .. key .. " skipped, no enemies near")
		return
	end

	local delay = math.random(0, ui.delay:Get()) / 1000
	state.pending = { at = now + delay, expire = now + 1.0 }
	note("trigger " .. key .. " delay " .. delay)
end

function script.OnGameEnd()
	reset()
end

return script
