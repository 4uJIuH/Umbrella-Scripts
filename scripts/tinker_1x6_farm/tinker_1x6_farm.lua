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
		tf_group_main = "Farm",
		tf_group_use = "What to use",
		tf_enable = "Enable",
		tf_enable_tip = "Tinker farms neutral camps by himself",
		tf_gear_main = "Extra",
		tf_debug = "Debug log",
		tf_debug_tip = "Writes decisions and camp values to the log",
		tf_key = "Farm key",
		tf_key_tip = "Press to start farming, press again to stop",
		tf_bind_name = "Tinker 1x6: farm",
		tf_spells = "Spells",
		tf_spells_tip = "March and Turrets hit camps even in the fog,\nbut only camps that still have creeps",
		tf_items = "Items",
		tf_items_tip = "Blink, Fallen Sky and TP move the hero,\nthe rest is spent on camps. Drag for order",
		tf_save_items = "Saved items",
		tf_title = "Farm",
		tf_st_travel = "to camp",
		tf_st_fight = "farming",
		tf_st_channel = "channeling",
		tf_st_home = "going home",
		tf_st_base = "waiting for mana",
		tf_st_wait = "waiting for respawn",
		tf_st_dead = "dead",
		tf_st_pause = "paused",
		tf_st_flee = "leaving the enemy",
		tf_st_wave = "wave",
		tf_st_orb = "sphere",
		tf_orbs = "Pick up my spheres",
		tf_orbs_tip = "While farming, your spheres are picked up\nbefore camps, farm goes on after them",
		tf_waves = "Farm waves",
		tf_waves_tip = "Waves heading to your tower go before camps,\nTP there from anywhere on the map",
	},
	ru = {
		tf_group_main = "Фарм",
		tf_group_use = "Что использовать",
		tf_enable = "Включить",
		tf_enable_tip = "Tinker сам фармит лесные кемпы",
		tf_gear_main = "Дополнительно",
		tf_debug = "Отладка в лог",
		tf_debug_tip = "Пишет в лог решения и стоимость кемпов",
		tf_key = "Клавиша фарма",
		tf_key_tip = "Нажми, чтобы начать фарм, еще раз, чтобы остановить",
		tf_bind_name = "Tinker 1x6: фарм",
		tf_spells = "Способности",
		tf_spells_tip = "March и турели бьют кемп даже в тумане,\nно только если в нем есть крипы",
		tf_items = "Предметы",
		tf_items_tip = "Блинк, Fallen Sky и ТП перемещают героя,\nостальное тратится на кемпы. Перетаскивай для порядка",
		tf_save_items = "Сохраненные предметы",
		tf_title = "Фарм",
		tf_st_travel = "к кемпу",
		tf_st_fight = "фармит",
		tf_st_channel = "каст",
		tf_st_home = "на базу",
		tf_st_base = "ждет ману",
		tf_st_wait = "ждет респавн",
		tf_st_dead = "мертв",
		tf_st_pause = "пауза",
		tf_st_flee = "уходит от врага",
		tf_st_wave = "волна",
		tf_st_orb = "сфера",
		tf_orbs = "Подбирать мои сферы",
		tf_orbs_tip = "Во время фарма сначала собираются твои сферы\nраньше кемпов, фарм идет после них",
		tf_waves = "Фармить волны",
		tf_waves_tip = "Волны, идущие на твою вышку, важнее кемпов,\nТП к ним из любой точки карты",
	},
})

local UI = localization.WrapLibrary(Menu)
local L = localization.Get

local K = {
	ID = "tinker_1x6_farm",
	NAME = "[Tinker 1x6 Farm] ",
	HERO = "npc_dota_hero_tinker",
	SPELLS = {
		{ "Laser", "tinker_laser_custom", "tinker_laser" },
		{ "March", "tinker_march_of_the_machines_custom", "tinker_march_of_the_machines" },
		{ "Turrets", "tinker_deploy_turrets_custom", "tinker_deploy_turrets" },
		{ "Warp Flare", "tinker_warp_grenade_custom", "tinker_warp_grenade" },
		{ "Missile", "tinker_heat_seeking_missile_custom", "tinker_heat_seeking_missile" },
		{ "Rearm", "tinker_rearm_custom", "tinker_rearm" },
	},
	REARM_FOR = { "Laser", "March", "Turrets", "Missile" },
	SLOTS = { 0, 1, 2, 3, 4, 5, 15, 16 },
	SKIP = {
		"travel_boots", "ward_", "dust", "smoke", "bottle", "clarity", "tango", "flask", "courier", "gem", "cheese",
		"aegis", "tome", "upgrade", "madstone", "moon_shard", "enchanted_mango", "alchemist_recipe", "patrol_",
		"grisgris", "muerta_shovel", "essence_of_speed",
	},
	ICON = { starforge_seal = "force_field", celestial_spear = "celestial_spear_custom", soulguard = "craggy_coat", wraith_aura = "wraith_pact" },
	DISPEL = {
		manta = true, black_king_bar = true, lotus_orb = true, guardian_greaves = true, minotaur_horn = true,
		force_boots = true, disperser = true, cyclone = true, wind_waker = true,
		alchemist_gold_satanic = true, alchemist_gold_skadi = true,
	},
	ORBS = { item_gray_upgrade = true, item_blue_upgrade = true, item_purple_upgrade = true, item_legendary_upgrade = true, item_purple_upgrade_shop = true },
	WAVE_MODS = { "modifier_waveupgrade", "modifier_waveupgrade_boss" },
	BOOTS_MODS = { "modifier_item_travel_boots_custom", "modifier_item_travel_boots_2_custom", "modifier_item_travel_boots_2_perma" },
	TP_MOD = "modifier_custom_ability_teleport",
	ORB_BLOCK = "modifier_end_choise",
	PORTAL_FX = "portal_ground_spawn_endpoint",
	VALUE_WORDS = { "gold", "bount", "cost", "worth", "value", "price", "reward", "xp", "exp" },

	TICK = 0.05, ITEM_TICK = 0.5, SCAN_TICK = 0.25, BASE_TICK = 5, PLAN_TICK = 0.25, STAND_TICK = 2,
	GAP = 0.12, MOVE_GAP = 0.35, ORDER_GAP = 0.4, CAST_LAT = 0.1, CHANNEL_START = 0.8, PAUSE = 2,

	EDGE = 25, JUMP_MIN = 400, FALLEN_DELAY = 1.1, STAND = 550, REACH = 780, TURRET_SAFE = 330, CAMP_MIN = 300,
	TP_SHORT = 1000, TP_SHORT_CAST = 0.6, TP_LONG = 4, TP_BOOTS = -1, TP_HASTE_SPEED = 600, TP_HASTE_TIME = 2,
	REARM_CHANNEL = { 2, 1.5, 1 }, REARM_CD = { 4, 3, 2 },

	PLAN_DEPTH = 6, PLAN_WAIT = 6, PLAN_NODES = 4000,
	PATH_UNKNOWN = 1.5, PATH_MAX_FACTOR = 4, PATH_GAP = 150,
	STAND_RADII = { 550, 400, 250 }, STAND_STEPS = 12, STAND_CHECK = 3,
	STUCK_TIME = 1.5, STUCK_DIST = 80, STUCK_BAN = 4, STUCK_MAX = 3,

	MANA_HOME = 15, MANA_OK = 90, MANA_REARM = 20, MANA_RESERVE = 20,
	DANGER = 1300, SAFE_CAMP = 2500, FLEE_GAP = 3, FLEE_DIST = 1200, ESCAPE_CREEP = 900, ESCAPE_DIST = 900,
	TRAVEL_TIMEOUT = 25, FIGHT_TIMEOUT = 40, BASE_TIMEOUT = 60, SKIP_CAMP = 30, RESPAWN_GRACE = 1.5,
	MISSILE_RANGE = 1500, NO_TARGET_REACH = 900,

	WAVE_RADIUS = 3500, WAVE_GROUP = 600, WAVE_LEAD = 3, WAVE_LATE = 2, SPAWN_WAIT = 6, PREP_WINDOW = 20,
	PORTAL_DELAY = 5, PORTAL_BATCH = 1.5,

	ORB_WALK = 1200, ORB_TIMEOUT = 25, ORB_SKIP = 60, ORB_CHECK = 1500, ORB_PICK = 200,
}
K.SPELL = {}
for _, s in ipairs(K.SPELLS) do K.SPELL[s[1]] = s[2] end

local ui = {}
local S = {
	on = false, phase = "idle", phase_at = 0, spot = nil, after = "travel", channel_at = 0, channel_seen = false,
	tick = 0, next_at = 0, move_at = 0, order_at = 0, pause_until = 0, flee_at = 0, silenced = false,
	camps = nil, cleared = {}, value_fn = nil, value_seen = {}, discovered = false,
	base = {}, base_at = 0, waves = {}, wave_at = 0, prep_at = 0,
	spawn_at = nil, timer_text = nil, timer_panel = nil, timer_known = nil,
	spawner = nil, spawner_d = math.huge, spawner_at = 0, portals = {},
	orbs = {}, orb_at = 0, orb_skip = {},
	items = {}, sig = "", item_at = 0, primed = false,
	plan = { "walk" }, plan_at = 0, plan_dest = nil, plan_text = nil,
	prog_pos = nil, prog_at = 0, stuck_until = 0,
	errors = {}, draw = nil,
}
local A = {}

do
	local page = UI.Create("Heroes", "Hero List", "Tinker", "1x6 Farm")
	local g_main = page:Create("tf_group_main", Enum.GroupSide.Left)
	local g_use = page:Create("tf_group_use", Enum.GroupSide.Right)

	ui.enable = g_main:Switch("tf_enable", true, "\u{f011}")
	ui.enable:ToolTip("tf_enable_tip")
	local g_gear = ui.enable:Gear("tf_gear_main")
	ui.debug = g_gear:Switch("tf_debug", false, "\u{f188}")
	ui.debug:ToolTip("tf_debug_tip")
	ui.save_items = g_gear:Input("tf_save_items", "", "\u{f0c7}")
	ui.save_items:Visible(false)

	ui.key = g_main:Bind("tf_key", Enum.ButtonCode.KEY_NONE, "\u{f11c}")
	ui.key:ToolTip("tf_key_tip")
	ui.key:Properties(L("tf_bind_name"))
	ui.waves = g_main:Switch("tf_waves", true, "\u{f0c0}")
	ui.waves:ToolTip("tf_waves_tip")
	ui.orbs = g_main:Switch("tf_orbs", false, "\u{f111}")
	ui.orbs:ToolTip("tf_orbs_tip")

	local rows = {}
	for i, s in ipairs(K.SPELLS) do rows[i] = { s[1], "panorama/images/spellicons/" .. s[3] .. "_png.vtex_c", true } end
	ui.spells = g_use:MultiSelect("tf_spells", rows, true)
	ui.spells:Icon("\u{f0e7}")
	ui.spells:ToolTip("tf_spells_tip")

	ui.items = g_use:MultiSelect("tf_items", {}, true)
	ui.items:Icon("\u{f290}")
	ui.items:ToolTip("tf_items_tip")
	ui.items:DragAllowed(true)
end

ui.enable:SetCallback(function(this)
	local off = not this:Get()
	for _, w in ipairs({ ui.key, ui.waves, ui.orbs, ui.spells, ui.items, ui.debug }) do w:Disabled(off) end
end, true)

function A.log(text, data)
	if not ui.debug:Get() then return end
	if data ~= nil then
		local parts = {}
		for k, v in pairs(data) do parts[#parts + 1] = k .. "=" .. tostring(v) end
		table.sort(parts)
		text = text .. " {" .. table.concat(parts, ", ") .. "}"
	end
	Log.Write(K.NAME .. text)
end

function A.has(value, bit)
	return type(value) == "number" and value // bit % 2 == 1
end

function A.dist(a, b)
	return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2)
end

function A.toward(from, to, length)
	local d = A.dist(from, to)
	if d < 1 then return from end
	return Vector(from.x + (to.x - from.x) / d * length, from.y + (to.y - from.y) / d * length, to.z)
end

function A.away(from, threat, length)
	return A.toward(from, Vector(from.x * 2 - threat.x, from.y * 2 - threat.y, from.z), length)
end

function A.pos(unit)
	return Entity.GetAbsOrigin(unit)
end

function A.mana(hero)
	return NPC.GetMana(hero) / math.max(1, NPC.GetMaxMana(hero)) * 100
end

function A.range(h, fallback)
	local r = Ability.GetCastRange(h)
	return (type(r) == "number" and r > 0) and r or fallback
end

function A.phase(phase, now)
	if S.phase ~= phase then
		A.log(S.phase .. " -> " .. phase)
		S.prog_pos = nil
	end
	S.phase, S.phase_at = phase, now
end

function A.ready(h, hero)
	if h == nil or Ability.GetLevel(h) <= 0 or Ability.IsHidden(h) or NPC.IsStunned(hero)
		or NPC.HasState(hero, Enum.ModifierState.MODIFIER_STATE_HEXED) then
		return false
	end
	if Ability.GetName(h):find("^item_") then
		if NPC.HasState(hero, Enum.ModifierState.MODIFIER_STATE_MUTED) then return false end
	elseif NPC.IsSilenced(hero) then
		return false
	end
	return Ability.IsCastable(h, NPC.GetMana(hero))
end

function A.spell(hero, id)
	if not ui.spells:Get(id) then return nil end
	local h = NPC.GetAbility(hero, K.SPELL[id])
	return A.ready(h, hero) and h or nil
end

function A.order(hero, kind, pos, ability, target)
	Player.PrepareUnitOrders(Players.GetLocal(), kind, target, pos, ability,
		Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, hero, false, false, false, true, K.ID)
end

function A.cast(h, kind, arg, now, why)
	if kind == "point" then
		Ability.CastPosition(h, arg, false, false, true, K.ID)
	elseif kind == "no" then
		Ability.CastNoTarget(h, false, false, true, K.ID)
	else
		Ability.CastTarget(h, arg, false, false, true, K.ID)
	end
	S.next_at = now + math.max(0, Ability.GetCastPoint(h)) + K.GAP
	A.log(why)
	return true
end

function A.move(hero, pos, now, attack)
	if now < S.move_at then return end
	S.move_at = now + K.MOVE_GAP
	A.order(hero, attack and Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_MOVE or Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION, pos, nil)
end

function A.channel_start(now, after)
	S.after, S.channel_at, S.channel_seen = after, now, false
	A.phase("channel", now)
	return true
end

function A.discover()
	S.discovered = true
	local names = {}
	for label, tbl in pairs({ Camp = Camp, Camps = Camps }) do
		local mt = getmetatable(tbl)
		for _, src in ipairs({ tbl, type(mt) == "table" and type(mt.__index) == "table" and mt.__index or {} }) do
			for k, v in pairs(type(src) == "table" and src or {}) do
				if type(v) == "function" then
					names[#names + 1] = label .. "." .. tostring(k)
					local low = tostring(k):lower()
					for _, word in ipairs(K.VALUE_WORDS) do
						if label == "Camp" and S.value_fn == nil and low:find(word, 1, true) then S.value_fn, S.value_name = v, k end
					end
				end
			end
		end
	end
	table.sort(names)
	A.log("api: " .. table.concat(names, ", "))
	A.log("camp value function: " .. tostring(S.value_name or "none, fog and respawn timer are used"))
end

function A.camps()
	if S.camps ~= nil and #S.camps > 0 then return S.camps end
	S.camps = {}
	for _, handle in pairs(Camps.GetAll()) do
		local box = Camp.GetCampBox(handle)
		if box ~= nil and box.min ~= nil and box.max ~= nil then
			local lo, hi = box.min, box.max
			S.camps[#S.camps + 1] = {
				kind = "camp",
				handle = handle,
				index = #S.camps + 1,
				pos = Vector((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, (lo.z + hi.z) / 2),
				radius = math.max(K.CAMP_MIN, math.max(hi.x - lo.x, hi.y - lo.y) / 2 + 150),
			}
		end
	end
	A.log("camps", { count = #S.camps })
	return S.camps
end

function A.camp_value(camp)
	if S.value_fn == nil then return nil end
	local ok, v = pcall(S.value_fn, camp.handle)
	v = (ok and type(v) == "number") and v or nil
	if S.value_seen[camp.index] ~= (v or "fail") then
		S.value_seen[camp.index] = v or "fail"
		A.log("camp value", { camp = camp.index, value = v or "fail" })
	end
	return v
end

function A.bases(hero, now)
	if now < S.base_at and #S.base > 0 then return S.base end
	S.base_at, S.base = now + K.BASE_TICK, {}
	local team = Entity.GetTeamNum(hero)
	for _, t in ipairs(Towers.GetAll()) do
		if Entity.GetTeamNum(t) == team and Entity.IsAlive(t) then S.base[#S.base + 1] = A.pos(t) end
	end
	if #S.base == 0 then
		for _, n in ipairs(NPCs.GetAll(function(n) return NPC.IsStructure(n) and Entity.GetTeamNum(n) == team end)) do
			S.base[#S.base + 1] = A.pos(n)
		end
	end
	return S.base
end

function A.enemy_near(hero, pos, radius)
	for _, e in ipairs(Heroes.InRadius(pos, radius, Entity.GetTeamNum(hero), Enum.TeamType.TEAM_ENEMY, true, true)) do
		if Entity.IsAlive(e) and not NPC.IsIllusion(e) and NPC.IsVisible(e) then return e end
	end
	return nil
end

function A.creeps(hero, spot, now)
	local out = {}
	if spot.kind == "camp" then
		for _, n in ipairs(NPCs.InRadius(spot.pos, spot.radius, Entity.GetTeamNum(hero), Enum.TeamType.TEAM_BOTH, true, true)) do
			if NPC.IsNeutral(n) and Entity.IsAlive(n) and not NPC.IsWaitingToSpawn(n) then out[#out + 1] = n end
		end
	elseif spot.kind ~= "orb" then
		for _, c in ipairs(A.wave_creeps(hero, now)) do
			if Entity.IsAlive(c) and A.dist(spot.pos, A.pos(c)) <= spot.radius + 200 then out[#out + 1] = c end
		end
	end
	return out
end

function A.alive(hero, spot, now, creeps)
	if spot.kind == "orb" then return S.orbs[spot.id] ~= nil end
	if spot.kind == "spawn" then return now < spot.until_at end
	creeps = creeps or A.creeps(hero, spot, now)
	if spot.kind == "wave" then return #creeps > 0 end
	local v = A.camp_value(spot)
	if v ~= nil then return v > 0 end
	if #creeps > 0 then return true end
	return not FogOfWar.IsPointVisible(spot.pos) and now >= (S.cleared[spot.index] or 0)
end

function A.drop(spot, now, delay, why)
	if spot.kind == "camp" then
		local t = GameRules.GetDOTATime(false, false)
		S.cleared[spot.index] = now + (delay or ((t // 60 + 1) * 60 - t + K.RESPAWN_GRACE))
	elseif spot.kind == "orb" then
		S.orb_skip[spot.id] = now + (delay or K.ORB_SKIP)
	end
	A.log(spot.kind .. " " .. why, { id = spot.index or spot.id })
	if S.spot == spot then S.spot = nil end
end

function A.pick_camp(hero, now, avoid)
	local origin = A.pos(hero)
	local best, best_d = nil, math.huge
	for _, camp in ipairs(A.camps()) do
		local d = A.dist(camp.pos, origin)
		if d < best_d and now >= (S.cleared[camp.index] or 0) and (avoid == nil or A.dist(camp.pos, avoid) >= K.SAFE_CAMP)
			and A.enemy_near(hero, camp.pos, K.SAFE_CAMP) == nil and A.alive(hero, camp, now) then
			best, best_d = camp, d
		end
	end
	return best
end

function A.wave_creeps(hero, now)
	if now < S.wave_at then return S.waves end
	S.wave_at, S.waves = now + K.SCAN_TICK, {}
	if not ui.waves:Get() then return S.waves end
	local points, seen = { table.unpack(A.bases(hero, now)) }, {}
	if S.spawner ~= nil then points[#points + 1] = S.spawner end
	for _, point in ipairs(points) do
		for _, n in ipairs(NPCs.InRadius(point, K.WAVE_RADIUS, Entity.GetTeamNum(hero), Enum.TeamType.TEAM_BOTH, true, true)) do
			if not seen[n] and Entity.IsAlive(n) and not Entity.IsSameTeam(hero, n) and NPC.HasAnyModifier(n, K.WAVE_MODS) then
				seen[n] = true
				S.waves[#S.waves + 1] = n
			end
		end
	end
	return S.waves
end

function A.wave_center(hero, now)
	local creeps = A.wave_creeps(hero, now)
	if #creeps == 0 then return nil end
	local origin, near, near_d = A.pos(hero), nil, math.huge
	for _, c in ipairs(creeps) do
		local d = A.dist(origin, A.pos(c))
		if d < near_d then near, near_d = c, d end
	end
	local p0, x, y, n = A.pos(near), 0, 0, 0
	for _, c in ipairs(creeps) do
		local p = A.pos(c)
		if A.dist(p, p0) <= K.WAVE_GROUP then x, y, n = x + p.x, y + p.y, n + 1 end
	end
	return Vector(x / n, y / n, p0.z)
end

function A.read_timer(now)
	local panel = S.timer_panel
	if panel == nil or not panel:IsValid() then
		local ok, root = pcall(Panorama.GetPanelByName, "CreepTimer", false)
		if not ok or root == nil then
			local ok_hud, hud = pcall(Panorama.GetPanelByName, "Hud", false)
			root = (ok_hud and hud ~= nil) and hud:FindChildTraverse("CreepTimer") or nil
		end
		panel = root ~= nil and root:FindChildTraverse("TimerText") or nil
		S.timer_panel = panel
		if panel == nil then return end
	end
	local text = panel:GetText()
	if text == S.timer_text then return end
	S.timer_text = text
	local m, sec = text:match("^(%d+):(%d%d)$")
	S.spawn_at = m ~= nil and now + tonumber(m) * 60 + tonumber(sec) or nil
	if (S.spawn_at ~= nil) ~= S.timer_known then
		S.timer_known = S.spawn_at ~= nil
		A.log("wave timer", { text = text })
	end
end

function A.portal(pos, at)
	local hero = Heroes.GetLocal()
	if hero == nil or NPC.GetUnitName(hero) ~= K.HERO then return end
	local best = math.huge
	for _, b in ipairs(A.bases(hero, at)) do best = math.min(best, A.dist(b, pos)) end
	if at - S.spawner_at > K.PORTAL_BATCH then S.spawner_d = math.huge end
	if best >= S.spawner_d then return end
	S.spawner, S.spawner_d, S.spawner_at = pos, best, at
	if S.spawn_at == nil or math.abs(S.spawn_at - (at + K.PORTAL_DELAY)) > 1.5 then S.spawn_at = at + K.PORTAL_DELAY end
	if S.spot ~= nil and S.spot.kind == "spawn" then S.spot.pos = pos end
	A.log("spawner", { x = math.floor(pos.x), y = math.floor(pos.y), to_base = math.floor(best) })
end

function A.scan_orbs(hero, now)
	if now < S.orb_at then return end
	S.orb_at = now + K.SCAN_TICK
	local me, seen = Player.GetPlayerID(Players.GetLocal()), {}
	for _, phys in ipairs(PhysicalItems.GetAll()) do
		local item = PhysicalItem.GetItem(phys)
		local name = item ~= nil and Ability.GetName(item) or nil
		if name ~= nil and K.ORBS[name] and Item.GetPlayerOwnerID(item) == me then
			local id = Entity.GetIndex(phys)
			if S.orbs[id] == nil then
				S.orbs[id] = { kind = "orb", id = id, name = name, radius = 0 }
				A.log("sphere seen", { name = name })
			end
			S.orbs[id].phys, S.orbs[id].pos = phys, A.pos(phys)
			seen[id] = true
		end
	end
	for id, orb in pairs(S.orbs) do
		if not seen[id] then
			S.orbs[id] = nil
			if S.spot == orb then S.spot = nil end
		end
	end
end

function A.pick_orb(hero, now)
	if not ui.orbs:Get() or NPC.HasModifier(hero, K.ORB_BLOCK) then return nil end
	local free = false
	for slot = 0, 8 do free = free or NPC.GetItemByIndex(hero, slot) == nil end
	if not free then return nil end
	local origin, best, best_d = A.pos(hero), nil, math.huge
	for id, orb in pairs(S.orbs) do
		local d = A.dist(origin, orb.pos)
		if d < best_d and now >= (S.orb_skip[id] or 0) then best, best_d = orb, d end
	end
	return best
end

function A.kind(h)
	local b, B = Ability.GetBehavior(h), Enum.AbilityBehavior
	if A.has(b, B.DOTA_ABILITY_BEHAVIOR_PASSIVE) or A.has(b, B.DOTA_ABILITY_BEHAVIOR_HIDDEN) or A.has(b, B.DOTA_ABILITY_BEHAVIOR_TOGGLE) then return nil end
	if A.has(b, B.DOTA_ABILITY_BEHAVIOR_POINT) then return "point" end
	if A.has(b, B.DOTA_ABILITY_BEHAVIOR_UNIT_TARGET) then
		local team = Ability.GetTargetTeam(h)
		if A.has(team, Enum.TargetTeam.DOTA_UNIT_TARGET_TEAM_ENEMY) then return "enemy" end
		return A.has(team, Enum.TargetTeam.DOTA_UNIT_TARGET_TEAM_FRIENDLY) and "self" or nil
	end
	return A.has(b, B.DOTA_ABILITY_BEHAVIOR_NO_TARGET) and "no" or nil
end

function A.role(base)
	if base == "tpscroll" then return "tp" end
	if base:find("blink", 1, true) or base == "fallen_sky" then return "jump" end
	return "use"
end

function A.skipped(name)
	for _, part in ipairs(K.SKIP) do
		if name:find(part, 1, true) then return true end
	end
	return false
end

function A.restore_items()
	S.primed = true
	if #ui.items:List() > 0 then return end
	local rows, on = {}, {}
	for id, flag in (ui.save_items:Get() or ""):gmatch("([^|]+)=([01])") do
		rows[#rows + 1] = { id, "", flag == "1" }
		if flag == "1" then on[#on + 1] = id end
	end
	if #rows > 0 then
		ui.items:Update(rows, true, true)
		ui.items:Set(on)
	end
end

function A.refresh_items(hero, now)
	if now < S.item_at then return end
	S.item_at = now + K.ITEM_TICK
	if not S.primed then A.restore_items() end
	local saved = {}
	for _, id in ipairs(ui.items:List()) do saved[#saved + 1] = id .. "=" .. (ui.items:Get(id) and "1" or "0") end
	saved = table.concat(saved, "|")
	if saved ~= "" and saved ~= ui.save_items:Get() then ui.save_items:Set(saved) end
	local items, labels = {}, {}
	for _, slot in ipairs(K.SLOTS) do
		local h = NPC.GetItemByIndex(hero, slot)
		if h ~= nil then
			local name = Ability.GetName(h)
			local base = name:gsub("^item_", ""):gsub("_custom$", "")
			local label = base:gsub("_", " ")
			local kind = A.kind(h)
			if items[label] == nil and (base == "tpscroll" or (kind ~= nil and not A.skipped(name))) then
				items[label] = { h = h, name = name, base = base, kind = kind, role = A.role(base) }
				labels[#labels + 1] = label
			end
		end
	end
	S.items = items
	local sig = table.concat(labels, ",")
	if sig == S.sig then return end
	S.sig = sig
	local rank, known, enabled = {}, {}, {}
	for i, id in ipairs(ui.items:List()) do rank[id], known[id] = i, true end
	for _, id in ipairs(ui.items:ListEnabled()) do enabled[id] = true end
	table.sort(labels, function(a, b) return (rank[a] or 1000) < (rank[b] or 1000) end)
	local rows, on = {}, {}
	for i, label in ipairs(labels) do
		local flag = not known[label] or enabled[label] == true
		local base = items[label].base
		rows[i] = { label, "panorama/images/items/" .. (K.ICON[base] or base) .. "_png.vtex_c", flag }
		if flag then on[#on + 1] = label end
	end
	ui.items:Update(rows, true, true)
	ui.items:Set(on)
	A.log("items", { list = sig })
end

function A.enabled_items(role)
	local out = {}
	for _, label in ipairs(ui.items:ListEnabled()) do
		local it = S.items[label]
		if it ~= nil and it.role == role then out[#out + 1] = it end
	end
	return out
end

function A.item(hero, role, ready)
	for _, it in ipairs(A.enabled_items(role)) do
		if not ready or A.ready(it.h, hero) then return it end
	end
	return nil
end

function A.tp(hero, dest, now, after)
	local it = NPC.HasScepter(hero) and A.item(hero, "tp", true) or nil
	if it == nil or not A.has(Ability.GetBehavior(it.h), Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_POINT) then return false end
	A.cast(it.h, "point", dest, now, "tp")
	return A.channel_start(now, after)
end

function A.rearm(hero, now, after, force)
	if not force and A.mana(hero) < K.MANA_REARM then return false end
	local h = A.spell(hero, "Rearm")
	if h == nil then return false end
	A.cast(h, "no", nil, now, "rearm")
	return A.channel_start(now, after)
end

function A.jump(hero, dest, now, exact)
	local origin = A.pos(hero)
	local d = A.dist(origin, dest)
	for _, it in ipairs(A.enabled_items("jump")) do
		local reach = A.range(it.h, 1200) - K.EDGE
		if A.ready(it.h, hero) and (not exact or d <= reach) then
			A.cast(it.h, "point", A.toward(origin, dest, math.min(d, reach)), now, "jump " .. it.base)
			if it.base == "fallen_sky" then S.next_at = now + K.FALLEN_DELAY end
			return true
		end
	end
	if d > K.TP_SHORT - K.EDGE and exact then return false end
	return A.tp(hero, A.toward(origin, dest, math.min(d, K.TP_SHORT - K.EDGE)), now, "travel")
end

function A.jump_reach(hero)
	local reach = 0
	for _, it in ipairs(A.enabled_items("jump")) do
		if A.ready(it.h, hero) then reach = math.max(reach, A.range(it.h, 1200) - K.EDGE) end
	end
	local tp = NPC.HasScepter(hero) and A.item(hero, "tp", false) or nil
	if tp ~= nil and (A.ready(tp.h, hero) or A.spell(hero, "Rearm") ~= nil) then reach = math.max(reach, K.TP_SHORT - K.EDGE) end
	return reach
end

function A.path_len(from, to, trees)
	local ok, path = pcall(GridNav.BuildPath, from, to, not trees)
	if not ok or type(path) ~= "table" or #path < 2 then return nil end
	local len, prev = 0, from
	for _, pt in ipairs(path) do
		len, prev = len + A.dist(prev, pt), pt
	end
	if A.dist(prev, to) > K.PATH_GAP then return nil end
	return math.max(len, A.dist(from, to))
end

function A.walk_len(from, to)
	return A.path_len(from, to) or A.dist(from, to) * K.PATH_UNKNOWN
end

function A.banned(spot, pos)
	for _, bad in ipairs(spot.bad or {}) do
		if A.dist(bad, pos) < K.STAND_RADII[#K.STAND_RADII] then return true end
	end
	return false
end

function A.stand(hero, spot, now)
	local origin = A.pos(hero)
	if A.dist(origin, spot.pos) <= K.STAND and not A.banned(spot, origin) then return origin end
	if spot.stand ~= nil and now ~= nil and now < spot.stand_at then return spot.stand end
	local cands = {}
	for _, radius in ipairs(K.STAND_RADII) do
		for i = 0, K.STAND_STEPS - 1 do
			local a = i / K.STAND_STEPS * math.pi * 2
			local pos = Vector(spot.pos.x + math.cos(a) * radius, spot.pos.y + math.sin(a) * radius, spot.pos.z)
			if GridNav.IsTraversable(pos) and not A.banned(spot, pos) then cands[#cands + 1] = { pos = pos, d = A.dist(origin, pos) } end
		end
	end
	table.sort(cands, function(a, b) return a.d < b.d end)
	local best, best_len = nil, math.huge
	for i = 1, math.min(K.STAND_CHECK, #cands) do
		local len = A.walk_len(origin, cands[i].pos)
		if len < best_len then best, best_len = cands[i].pos, len end
	end
	best = best or A.toward(spot.pos, origin, K.STAND)
	if now ~= nil then spot.stand, spot.stand_at = best, now + K.STAND_TICK end
	return best
end

function A.stuck(hero, spot, dest, now)
	local pos = A.pos(hero)
	if S.prog_pos == nil or A.dist(pos, S.prog_pos) > K.STUCK_DIST then
		S.prog_pos, S.prog_at = pos, now
		return false
	end
	if now - S.prog_at < K.STUCK_TIME then return false end
	S.prog_pos, S.stuck_until, S.plan_at = nil, now + K.STUCK_BAN, 0
	spot.bad = spot.bad or {}
	spot.bad[#spot.bad + 1] = dest
	spot.stand, spot.blocked = nil, true
	spot.stuck = (spot.stuck or 0) + 1
	A.log("stuck", { spot = spot.kind, times = spot.stuck })
	if spot.stuck >= K.STUCK_MAX then A.drop(spot, now, spot.kind == "orb" and K.ORB_SKIP or K.SKIP_CAMP, "unreachable") end
	return true
end

function A.walk_time(P, rem, haste)
	if P.no_walk and rem > K.PATH_GAP then return math.huge end
	rem = rem * P.factor
	local fast = math.max(P.ms, K.TP_HASTE_SPEED)
	if haste > 0 and rem > fast * haste then return haste + (rem - fast * haste) / P.ms end
	return haste > 0 and rem / fast or rem / P.ms
end

function A.walk_dist(P, dt, haste)
	if P.no_walk then return 0 end
	local boosted = math.min(dt, haste)
	return (boosted * math.max(P.ms, K.TP_HASTE_SPEED) + (dt - boosted) * P.ms) / P.factor
end

function A.search(P, st, seq, depth)
	P.nodes = P.nodes + 1
	if st.t >= P.best or P.nodes > K.PLAN_NODES then return end
	local total = st.t + A.walk_time(P, st.rem, st.haste)
	if total < P.best then
		P.best, P.seq = total, table.move(seq, 1, depth, 1, {})
		P.seq[depth + 1] = "walk"
	end
	if depth >= K.PLAN_DEPTH or st.rem < K.JUMP_MIN then return end
	local function go(action, changes)
		local nst = { rem = st.rem, t = st.t, haste = st.haste, tp = st.tp, rr = st.rr, mana = st.mana, used = st.used }
		for k, v in pairs(changes) do nst[k] = v end
		seq[depth + 1] = action
		A.search(P, nst, seq, depth + 1)
		seq[depth + 1] = nil
	end
	for i, tool in ipairs(P.tools) do
		local bit = 1 << i
		if st.used & bit == 0 then
			go(tool.name, { rem = st.rem - math.min(st.rem, tool.range), t = st.t + tool.delay, haste = math.max(0, st.haste - tool.delay), used = st.used | bit })
		end
	end
	if st.tp <= st.t and st.mana >= P.tp_mana then
		local after = { tp = math.huge, haste = K.TP_HASTE_TIME, mana = st.mana - P.tp_mana }
		go("short", { rem = st.rem - math.min(st.rem, K.TP_SHORT - K.EDGE), t = st.t + K.TP_SHORT_CAST + P.lat, tp = after.tp, haste = after.haste, mana = after.mana })
		if st.rem > K.TP_SHORT then go("long", { rem = 0, t = st.t + P.long + P.lat, tp = after.tp, haste = after.haste, mana = after.mana }) end
	end
	if P.tp_owned and st.tp > st.t and st.rr <= st.t and st.mana >= P.rearm_mana then
		local t = st.t + P.rearm_ch + P.lat
		go("rearm", { t = t, haste = math.max(0, st.haste - (t - st.t)), tp = t, rr = t + P.rearm_cd, mana = st.mana - P.rearm_mana })
	end
	for _, ready in ipairs({ st.tp, st.rr }) do
		local dt = ready - st.t
		if dt > 0 and dt <= K.PLAN_WAIT then
			go("walk", { rem = math.max(0, st.rem - A.walk_dist(P, dt, st.haste)), t = ready, haste = math.max(0, st.haste - dt) })
		end
	end
end

function A.plan(hero, dest, now)
	local origin = A.pos(hero)
	local straight = math.max(1, A.dist(origin, dest))
	local tools, seen = {}, {}
	for _, it in ipairs(A.enabled_items("jump")) do
		if not seen[it.base] and A.ready(it.h, hero) then
			seen[it.base] = true
			tools[#tools + 1] = { name = it.base, range = A.range(it.h, 1200) - K.EDGE, delay = it.base == "fallen_sky" and K.FALLEN_DELAY or K.CAST_LAT }
		end
	end
	local tp = NPC.HasScepter(hero) and A.item(hero, "tp", false) or nil
	if tp ~= nil and not A.has(Ability.GetBehavior(tp.h), Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_POINT) then tp = nil end
	local rearm = ui.spells:Get("Rearm") and NPC.GetAbility(hero, K.SPELL["Rearm"]) or nil
	if rearm ~= nil and Ability.GetLevel(rearm) <= 0 then rearm = nil end
	local level = rearm ~= nil and Ability.GetLevel(rearm) or 1
	local P = {
		ms = math.max(100, NPC.GetMoveSpeed(hero)),
		lat = K.CAST_LAT,
		long = K.TP_LONG + (NPC.HasAnyModifier(hero, K.BOOTS_MODS) and K.TP_BOOTS or 0),
		tp_owned = tp ~= nil,
		tp_mana = tp ~= nil and Ability.GetManaCost(tp.h) or 0,
		rearm_ch = K.REARM_CHANNEL[level] or 2,
		rearm_cd = K.REARM_CD[level] or 4,
		rearm_mana = rearm ~= nil and Ability.GetManaCost(rearm) or math.huge,
		tools = tools,
		best = math.huge,
		seq = { "walk" },
		nodes = 0,
		factor = math.min(K.PATH_MAX_FACTOR, A.walk_len(origin, dest) / straight),
		no_walk = now < S.stuck_until,
	}
	A.search(P, {
		rem = straight,
		t = 0,
		haste = 0,
		tp = tp ~= nil and Ability.GetCooldown(tp.h) or math.huge,
		rr = rearm ~= nil and Ability.GetCooldown(rearm) or math.huge,
		mana = NPC.GetMana(hero) - NPC.GetMaxMana(hero) * K.MANA_RESERVE / 100,
		used = 0,
	}, {}, 0)
	return P.seq, P.best
end

function A.go(hero, spot, dest, now)
	if now >= S.plan_at or S.plan_dest == nil or A.dist(S.plan_dest, dest) > 200 then
		local seq, eta = A.plan(hero, dest, now)
		S.plan, S.plan_at, S.plan_dest = seq, now + K.PLAN_TICK, dest
		local text = table.concat(seq, " > ")
		if text ~= S.plan_text then
			S.plan_text = text
			A.log("route " .. text, { eta = math.floor(eta * 10) / 10 })
		end
	end
	local step = S.plan[1]
	local done = false
	if step == "long" then
		done = A.tp(hero, dest, now, "travel")
	elseif step == "short" then
		done = A.tp(hero, A.toward(A.pos(hero), dest, math.min(A.dist(A.pos(hero), dest), K.TP_SHORT - K.EDGE)), now, "travel")
	elseif step == "rearm" then
		done = A.rearm(hero, now, "travel", true)
	elseif step ~= "walk" then
		for _, it in ipairs(A.enabled_items("jump")) do
			if not done and it.base == step and A.ready(it.h, hero) then
				local origin = A.pos(hero)
				done = A.cast(it.h, "point", A.toward(origin, dest, math.min(A.dist(origin, dest), A.range(it.h, 1200) - K.EDGE)), now, "jump " .. step)
				if step == "fallen_sky" then S.next_at = now + K.FALLEN_DELAY end
			end
		end
	end
	if done then
		S.plan_at, S.prog_pos = 0, nil
	elseif not A.stuck(hero, spot, dest, now) then
		A.move(hero, dest, now, false)
	end
end

function A.best_creep(hero, creeps, range)
	local origin, best, hp = A.pos(hero), nil, -1
	for _, c in ipairs(creeps) do
		local h = Entity.GetHealth(c)
		if h > hp and A.dist(origin, A.pos(c)) <= range and not NPC.HasState(c, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE) then
			best, hp = c, h
		end
	end
	return best
end

function A.cooldowns(hero)
	local n = 0
	for _, id in ipairs(K.REARM_FOR) do
		local h = ui.spells:Get(id) and NPC.GetAbility(hero, K.SPELL[id]) or nil
		if h ~= nil and Ability.GetLevel(h) > 0 and not Ability.IsHidden(h) and Ability.GetCooldown(h) > 0 then n = n + 1 end
	end
	return n
end

function A.cast_area(hero, spot, d, now)
	local march = A.spell(hero, "March")
	if march ~= nil then
		local vector = A.has(Ability.GetBehavior(march), Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_VECTOR_TARGETING)
		if d <= A.range(march, vector and 900 or 700) + 50 then
			if not vector then return A.cast(march, "point", spot.pos, now, "march") end
			A.order(hero, Enum.UnitOrder.DOTA_UNIT_ORDER_VECTOR_TARGET_POSITION, A.toward(A.pos(hero), spot.pos, d + 300), march)
			A.order(hero, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION, spot.pos, march)
			S.next_at = now + math.max(0, Ability.GetCastPoint(march)) + K.GAP
			A.log("march vector")
			return true
		end
	end
	local turrets = A.spell(hero, "Turrets")
	if turrets ~= nil and d <= A.range(turrets, 800) + 50 then
		local point = d < K.TURRET_SAFE and A.toward(A.pos(hero), spot.pos, K.TURRET_SAFE) or spot.pos
		return A.cast(turrets, "point", point, now, "turrets")
	end
	return false
end

function A.cast_items(hero, spot, creeps, d, now)
	for _, it in ipairs(A.enabled_items("use")) do
		if A.ready(it.h, hero) then
			local range = A.range(it.h, 0)
			if it.kind == "point" and (range <= 0 or d <= range + 50) then
				return A.cast(it.h, "point", spot.pos, now, "item " .. it.base)
			elseif it.kind == "no" and d <= K.NO_TARGET_REACH then
				return A.cast(it.h, "no", nil, now, "item " .. it.base)
			elseif it.kind == "self" then
				return A.cast(it.h, "target", hero, now, "item " .. it.base)
			elseif it.kind == "enemy" then
				local target = A.best_creep(hero, creeps, (range > 0 and range or 600) + 50)
				if target ~= nil then return A.cast(it.h, "target", target, now, "item " .. it.base) end
			end
		end
	end
	return false
end

function A.cast_targets(hero, spot, creeps, now)
	if #creeps == 0 then return false end
	for _, id in ipairs({ "Laser", "Warp Flare" }) do
		local h = A.spell(hero, id)
		local target = h ~= nil and A.best_creep(hero, creeps, A.range(h, 700) + 50) or nil
		if target ~= nil then
			return A.cast(h, "target", target, now, id)
		end
	end
	local missile = A.spell(hero, "Missile")
	if missile ~= nil and A.best_creep(hero, creeps, K.MISSILE_RANGE) ~= nil then
		return A.cast(missile, "no", nil, now, "missile")
	end
	return false
end

function A.fight(hero, spot, now)
	local creeps = A.creeps(hero, spot, now)
	if not A.alive(hero, spot, now, creeps) then return A.drop(spot, now, nil, "cleared") end
	if now - S.phase_at > K.FIGHT_TIMEOUT then return A.drop(spot, now, K.SKIP_CAMP, "fight timeout") end
	local d = A.dist(A.pos(hero), spot.pos)
	if d > K.REACH + 300 then return A.phase("travel", now) end
	if spot.kind == "spawn" and #creeps == 0 then return end
	if A.cast_area(hero, spot, d, now) or A.cast_targets(hero, spot, creeps, now) or A.cast_items(hero, spot, creeps, d, now) then return end
	if A.cooldowns(hero) > 0 and A.rearm(hero, now, "fight") then return end
	A.move(hero, spot.pos, now, #creeps > 0)
end

function A.orb_travel(hero, orb, now)
	if now - S.phase_at > K.ORB_TIMEOUT then return A.drop(orb, now, K.ORB_SKIP, "timeout") end
	local origin = A.pos(hero)
	local d = A.dist(origin, orb.pos)
	if orb.blocked == nil and d <= K.ORB_CHECK then
		orb.blocked = A.path_len(origin, orb.pos, true) == nil
		if orb.blocked then A.log("sphere behind trees or cliff", { name = orb.name }) end
	end
	if orb.blocked and d > K.ORB_PICK then
		local reach = A.jump_reach(hero)
		if reach <= 0 then return A.drop(orb, now, K.ORB_SKIP, "unreachable, no jump") end
		if d > reach then return A.go(hero, orb, A.toward(orb.pos, origin, reach - K.EDGE), now) end
		if A.jump(hero, orb.pos, now, true) or (A.tp_owned_on_cd(hero) and A.rearm(hero, now, "travel")) then
			S.plan_at, S.prog_pos = 0, nil
		end
		return
	end
	if d > K.ORB_WALK then return A.go(hero, orb, orb.pos, now) end
	if A.stuck(hero, orb, orb.pos, now) or now < S.order_at then return end
	S.order_at = now + K.ORDER_GAP
	A.order(hero, Enum.UnitOrder.DOTA_UNIT_ORDER_PICKUP_ITEM, orb.pos, nil, orb.phys)
end

function A.tp_owned_on_cd(hero)
	local tp = NPC.HasScepter(hero) and A.item(hero, "tp", false) or nil
	return tp ~= nil and Ability.GetCooldown(tp.h) > 0
end

function A.travel(hero, spot, now)
	if not A.alive(hero, spot, now) then return A.drop(spot, now, nil, "empty on the way") end
	if spot.kind == "orb" then return A.orb_travel(hero, spot, now) end
	if A.dist(A.pos(hero), spot.pos) <= K.REACH then return A.phase("fight", now) end
	if now - S.phase_at > K.TRAVEL_TIMEOUT then return A.drop(spot, now, K.SKIP_CAMP, "travel timeout") end
	A.go(hero, spot, A.stand(hero, spot, now), now)
end

function A.go_home(hero, now)
	local it = A.item(hero, "tp", true)
	if it == nil then return A.rearm(hero, now, "home", true) end
	if A.has(Ability.GetBehavior(it.h), Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_UNIT_TARGET) then
		A.cast(it.h, "target", hero, now, "tp home")
	else
		A.cast(it.h, "no", nil, now, "tp home")
	end
	return A.channel_start(now, "base")
end

function A.run_from(hero, from, from_hero, now)
	S.flee_at = math.max(S.flee_at, now + (from_hero and K.FLEE_GAP or 0.5))
	if from_hero then
		local camp = A.pick_camp(hero, now, from)
		S.spot = camp
		A.phase("travel", now)
		if camp ~= nil and A.tp(hero, A.stand(hero, camp), now, "travel") then return end
	end
	local dest = A.away(A.pos(hero), from, from_hero and K.FLEE_DIST or K.ESCAPE_DIST)
	if A.jump(hero, dest, now, false) then return end
	if from_hero and S.spot == nil and A.go_home(hero, now) then return end
	A.move(hero, dest, now, false)
end

function A.dispel(hero, now)
	for _, it in pairs(S.items) do
		if K.DISPEL[it.base] and A.ready(it.h, hero) and it.kind ~= "point" and it.kind ~= nil then
			return A.cast(it.h, it.kind == "no" and "no" or "target", hero, now, "dispel " .. it.base)
		end
	end
	return false
end

function A.escape_silence(hero, now)
	local origin = A.pos(hero)
	local enemy = A.enemy_near(hero, origin, K.DANGER)
	local from = enemy ~= nil and A.pos(enemy) or nil
	if from == nil then
		local best_d = K.ESCAPE_CREEP
		for _, n in ipairs(NPCs.InRadius(origin, K.ESCAPE_CREEP, Entity.GetTeamNum(hero), Enum.TeamType.TEAM_BOTH, true, true)) do
			if Entity.IsAlive(n) and not Entity.IsSameTeam(hero, n) and not NPC.IsStructure(n) and not NPC.IsWaitingToSpawn(n) then
				local d = A.dist(origin, A.pos(n))
				if d < best_d then from, best_d = A.pos(n), d end
			end
		end
	end
	if from == nil then return false end
	if not S.silenced then
		S.silenced = true
		A.log("silenced, escaping", { from_hero = enemy ~= nil })
	end
	if not A.dispel(hero, now) then A.run_from(hero, from, enemy ~= nil, now) end
	return true
end

function A.choose(hero, now)
	local center = A.wave_center(hero, now)
	if center ~= nil then
		if S.spot == nil or S.spot.kind ~= "wave" then
			S.spot = { kind = "wave", pos = center, radius = K.WAVE_GROUP }
			A.log("wave found", { creeps = #S.waves })
			A.phase("travel", now)
		else
			S.spot.pos = center
		end
		return
	end
	if S.spot ~= nil and S.spot.kind == "wave" then S.spot = nil end
	A.prepare_wave(hero, now)
	if S.spot == nil or S.spot.kind == "camp" then
		local orb = A.pick_orb(hero, now)
		if orb ~= nil then
			if S.spot ~= nil then A.log("sphere first", { camp = S.spot.index }) end
			S.spot = orb
			A.log("target", { kind = "orb", id = orb.id })
			A.phase("travel", now)
			return
		end
	end
	if S.spot == nil then
		S.spot = A.pick_camp(hero, now, nil)
		if S.spot == nil then return A.phase("wait", now) end
		A.log("target", { kind = "camp", id = S.spot.index })
		A.phase("travel", now)
	end
end

function A.prepare_wave(hero, now)
	if not ui.waves:Get() or S.spawn_at == nil or now < S.prep_at then return end
	S.prep_at = now + K.SCAN_TICK
	if S.spot ~= nil and S.spot.kind == "spawn" then return end
	local left = S.spawn_at - now
	if left < -K.SPAWN_WAIT or left > K.PREP_WINDOW then return end
	local dest = S.spawner or A.bases(hero, now)[1]
	if dest == nil then return end
	local _, eta = A.plan(hero, A.stand(hero, { pos = dest }), now)
	if left > math.max(K.WAVE_LEAD, math.min(eta, K.PREP_WINDOW) - K.WAVE_LATE) then return end
	S.spot = { kind = "spawn", pos = dest, radius = K.WAVE_GROUP, until_at = S.spawn_at + K.SPAWN_WAIT }
	S.plan_at = 0
	A.log("go to wave spawn", { left = math.floor(left * 10) / 10, eta = math.floor(eta * 10) / 10, known = S.spawner ~= nil })
	A.phase("travel", now)
end

function A.step(hero, now)
	if not Entity.IsAlive(hero) then
		S.spot = nil
		return A.phase("dead", now)
	end
	if S.phase == "dead" then A.phase("travel", now) end
	if now < S.pause_until then return end
	if S.phase == "channel" then
		if NPC.IsChannellingAbility(hero) or NPC.HasModifier(hero, K.TP_MOD) then
			S.channel_seen = true
		elseif S.channel_seen or now - S.channel_at >= K.CHANNEL_START then
			A.phase(S.after, now)
		end
		return
	end
	if now < S.next_at or NPC.IsChannellingAbility(hero) then return end
	if NPC.IsSilenced(hero) then
		if A.escape_silence(hero, now) then return end
	elseif S.silenced then
		S.silenced = false
		A.log("silence ended")
	end
	if S.phase == "base" then
		if A.mana(hero) >= K.MANA_OK or now - S.phase_at > K.BASE_TIMEOUT then A.phase("travel", now) end
		return
	end
	if now >= S.flee_at then
		local enemy = A.enemy_near(hero, A.pos(hero), K.DANGER)
		if enemy ~= nil then
			A.log("flee", { enemy = NPC.GetUnitName(enemy) })
			return A.run_from(hero, A.pos(enemy), true, now)
		end
	end
	if S.phase == "home" then
		if not A.go_home(hero, now) and now - S.phase_at > K.BASE_TIMEOUT then A.phase("travel", now) end
		return
	end
	if A.mana(hero) < K.MANA_HOME then
		S.spot = nil
		return A.phase("home", now)
	end
	A.choose(hero, now)
	if S.spot == nil then return end
	if S.phase == "fight" then return A.fight(hero, S.spot, now) end
	A.travel(hero, S.spot, now)
end

function A.toggle(hero, now)
	S.on = not S.on
	S.spot, S.pause_until = nil, 0
	if S.on and not S.discovered then A.discover() end
	A.phase(S.on and "travel" or "idle", now)
	if not S.on then A.order(hero, Enum.UnitOrder.DOTA_UNIT_ORDER_STOP, A.pos(hero), nil) end
end

function A.update()
	local hero = Heroes.GetLocal()
	if hero == nil or NPC.GetUnitName(hero) ~= K.HERO then return end
	local now = GameRules.GetGameTime()
	if ui.key:IsPressed() and not Input.IsInputCaptured() and ui.enable:Get() then A.toggle(hero, now) end
	if S.on and not ui.enable:Get() then A.toggle(hero, now) end
	if now < S.tick then return end
	S.tick = now + K.TICK
	A.refresh_items(hero, now)
	if not S.on then return end
	if ui.waves:Get() then A.read_timer(now) end
	if ui.orbs:Get() then A.scan_orbs(hero, now) end
	A.step(hero, now)
end

function A.status_key(now)
	if now < S.pause_until then return "tf_st_pause" end
	if now < S.flee_at then return "tf_st_flee" end
	local kind = S.spot ~= nil and S.spot.kind or nil
	if kind == "orb" then return "tf_st_orb" end
	if (kind == "wave" or kind == "spawn") and (S.phase == "travel" or S.phase == "fight") then return "tf_st_wave" end
	return "tf_st_" .. S.phase
end

function A.draw()
	if not S.on then return end
	local key = A.status_key(GameRules.GetGameTime())
	local d = S.draw
	if d == nil then
		d = {
			font = Render.LoadFont("Segoe UI", Enum.FontCreate.FONTFLAG_ANTIALIAS, Enum.FontWeight.SEMIBOLD),
			icon = Render.LoadImage("panorama/images/heroes/icons/npc_dota_hero_tinker_png.vtex_c"),
		}
		S.draw = d
	end
	if d.key ~= key then
		d.key, d.title, d.status = key, L("tf_title"), L(key)
		d.tw, d.sw = Render.TextSize(d.font, 12, d.title), Render.TextSize(d.font, 11, d.status)
		d.w = 61 + d.tw.x + d.sw.x
	end
	local x, y = math.floor(Render.ScreenSize().x / 2 - d.w / 2), 70
	Render.FilledRect(Vec2(x, y), Vec2(x + d.w, y + 26), Color(16, 18, 22, 200), 6)
	Render.Image(d.icon, Vec2(x + 8, y + 3), Vec2(20, 20), Color(255, 255, 255, 255), 4)
	Render.Text(d.font, 12, d.title, Vec2(x + 36, y + 13 - d.tw.y / 2), Color(235, 235, 240, 255))
	local sx = x + 44 + d.tw.x
	Render.FilledRect(Vec2(sx, y + 6), Vec2(sx + 1, y + 20), Color(255, 255, 255, 40))
	Render.Text(d.font, 11, d.status, Vec2(sx + 9, y + 13 - d.sw.y / 2), Color(150, 200, 255, 255))
end

function A.guard(where, fn)
	local ok, err = pcall(fn)
	if ok or S.errors[where] == tostring(err) then return end
	S.errors[where] = tostring(err)
	Log.Write(K.NAME .. where .. ": " .. tostring(err))
end

local script = {}

function script.OnUpdate()
	if Engine.IsInGame() then A.guard("update", A.update) end
end

function script.OnDraw()
	A.guard("draw", A.draw)
end

function script.OnParticleCreate(data)
	local name = data ~= nil and (data.fullName or data.name) or nil
	if type(name) == "string" and name:find(K.PORTAL_FX, 1, true) then S.portals[data.index] = GameRules.GetGameTime() end
end

function script.OnParticleUpdate(data)
	local at = data ~= nil and S.portals[data.index] or nil
	if at == nil or data.controlPoint ~= 0 or data.position == nil then return end
	S.portals[data.index] = nil
	A.guard("portal", function() A.portal(data.position, at) end)
end

function script.OnPrepareUnitOrders(data)
	local hero = Heroes.GetLocal()
	if S.on and data ~= nil and data.npc ~= nil and hero ~= nil and Entity.GetIndex(data.npc) == Entity.GetIndex(hero) then
		S.pause_until = GameRules.GetGameTime() + K.PAUSE
		A.log("manual order, pause")
	end
	return true
end

function script.OnGameEnd()
	S.on, S.phase, S.spot, S.camps = false, "idle", nil, nil
	S.cleared, S.value_seen, S.errors, S.items, S.sig = {}, {}, {}, {}, ""
	S.waves, S.wave_at, S.base, S.base_at = {}, 0, {}, 0
	S.spawn_at, S.timer_text, S.timer_panel, S.timer_known = nil, nil, nil, nil
	S.spawner, S.spawner_d, S.spawner_at, S.portals = nil, math.huge, 0, {}
	S.orbs, S.orb_skip = {}, {}
end

return script
