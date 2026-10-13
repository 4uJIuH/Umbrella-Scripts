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
		fs_group_main = "Main",
		fs_group_lane = "Lanes",
		fs_group_behave = "Behavior",

		fs_enable = "Enable",
		fs_enable_tip = "Sends your Forge Spirits to the\nnearest lanes to farm creeps",

		fs_key = "Send the spirits",
		fs_key_tip = "One press and the spirits spread\nover the nearest lanes",
		fs_bind_name = "Forge Spirit Farm",

		fs_gear_main = "Extra",
		fs_mode = "Key mode",
		fs_modes_toggle = "Press to switch on",
		fs_modes_hold = "Hold while working",
		fs_debug = "Debug log",
		fs_debug_tip = "Writes to the console what each\nspirit is doing",
		fs_spirits = "Spirits per lane",
		fs_spirits_tip = "1 means each spirit keeps its own lane\nand never takes another one's",

		fs_lane_top = "Top",
		fs_lane_mid = "Mid",
		fs_lane_bot = "Bot",
		fs_lane_any = "A lane is picked by distance",

		fs_slot1 = "1st spirit lane",
		fs_slot2 = "2nd spirit lane",
		fs_slot3 = "3rd spirit lane",
		fs_opt_auto = "Auto",
		fs_slots_tip = "A pinned spirit works only that lane\nand ignores the lane limit.\nSpirits are counted by summon order",

		fs_target = "Which creep to hit",
		fs_targets_nearest = "Closest to the spirit",
		fs_targets_weakest = "Lowest health",
		fs_engage = "Attack range",
		fs_engage_tip = "Closer than this the spirit attacks\nright away, further it walks over",
		fs_push = "Push without creeps",
		fs_push_tip = "No enemy creeps around, the spirit\nkeeps walking down its lane",
		fs_deny = "Deny own creeps",
		fs_deny_tip = "Spirits finish off your own creeps\nso the enemy gets no gold",
		fs_deny_hp = "Deny below health",
		fs_deny_hp_tip = "Creeps below this health can be denied.\n50%% is the game limit for creeps",
		fs_lane_only = "Strictly own lane",
		fs_lane_only_tip = "A spirit touches creeps only inside\nits own lane and never strays",
		fs_no_creeps = "Ignore creeps entirely",
		fs_no_creeps_tip = "Spirits only walk their lane to the\nenemy tower and attack nothing",
		fs_gear_speed = "Order refresh",
		fs_reissue = "Order refresh",
		fs_gear_deny = "Deny",
	},
	ru = {
		fs_group_main = "Основное",
		fs_group_lane = "Лайны",
		fs_group_behave = "Поведение",

		fs_enable = "Включить",
		fs_enable_tip = "Отправляет Forge Spirit на ближайшие\nлайны добивать крипов",

		fs_key = "Отправить духов",
		fs_key_tip = "Одно нажатие, и духи расходятся\nпо ближайшим лайнам",
		fs_bind_name = "Forge Spirit Farm",

		fs_gear_main = "Дополнительно",
		fs_mode = "Режим клавиши",
		fs_modes_toggle = "Нажатие включает",
		fs_modes_hold = "Держать, пока работают",
		fs_debug = "Отладка в лог",
		fs_debug_tip = "Пишет в консоль, что делает\nкаждый дух",
		fs_spirits = "Духов на лайн",
		fs_spirits_tip = "1 значит каждый дух держит свой лайн\nи не лезет на чужой",

		fs_lane_top = "Верх",
		fs_lane_mid = "Мид",
		fs_lane_bot = "Низ",
		fs_lane_any = "Лайн выбирается по близости",

		fs_slot1 = "Лайн 1-го духа",
		fs_slot2 = "Лайн 2-го духа",
		fs_slot3 = "Лайн 3-го духа",
		fs_opt_auto = "Авто",
		fs_slots_tip = "Закрепленный дух работает только\nэтот лайн и игнорирует лимит.\nДухи считаются по порядку призыва",

		fs_target = "Какого крипа бить",
		fs_targets_nearest = "Ближайшего к духу",
		fs_targets_weakest = "С наименьшим здоровьем",
		fs_engage = "Дистанция атаки",
		fs_engage_tip = "Ближе этого дух атакует сразу,\nдальше идет пешком",
		fs_push = "Идти дальше без крипов",
		fs_push_tip = "Если вражеских крипов рядом нет,\nдух продолжает идти по лайну",
		fs_deny = "Добивать своих крипов",
		fs_deny_tip = "Духи добивают твоих крипов,\nчтобы враг не получил золота",
		fs_deny_hp = "Добивать ниже здоровья",
		fs_deny_hp_tip = "Крипов ниже этого здоровья можно\nдобить. 50%% это предел игры для крипов",
		fs_lane_only = "Только свой лайн",
		fs_lane_only_tip = "Дух трогает крипов только в своем\nлайне и никуда не уходит",
		fs_no_creeps = "Не трогать крипов вообще",
		fs_no_creeps_tip = "Духи только идут по лайну к\nвражеской башне и никого не бьют",
		fs_gear_speed = "Обновление приказа",
		fs_reissue = "Обновление приказа",
		fs_gear_deny = "Добивание",
	},
})

local UI = localization.WrapLibrary(Menu)
local L = localization.Get

local VERSION = "0.1.0-beta.1"
local script = {}
local ui = {}

do
	local page
	local ok_find, hero_tab = pcall(function() return UI.Find("Heroes", "Hero List", "Invoker") end)
	if ok_find and hero_tab then
		local ok_page, found = pcall(function() return hero_tab:Find("Forge Spirit") end)
		if ok_page and found then page = found end
		if not page then
			local ok_create, created = pcall(function() return hero_tab:Create("Forge Spirit") end)
			if ok_create and created then page = created end
		end
	end

	if not page then
		local tab = UI.Create("Scripts", "Scripts", "Forge Spirit Farm")
		tab:Icon("\u{f6b6}")
		page = tab:Create("Forge Spirit")
	end

	local g_main = page:Create("fs_group_main", Enum.GroupSide.Left)
	local g_behave = page:Create("fs_group_behave", Enum.GroupSide.Right)
	local g_lane = page:Create("fs_group_lane", Enum.GroupSide.Left)

	ui.enable = g_main:Switch("fs_enable", true, "\u{f011}")
	ui.enable:ToolTip("fs_enable_tip")
	local g_extra = ui.enable:Gear("fs_gear_main")
	ui.mode = g_extra:Combo("fs_mode", { "fs_modes_toggle", "fs_modes_hold" }, 0)
	ui.mode:Icon("\u{f11c}")
	ui.debug = g_extra:Switch("fs_debug", false, "\u{f188}")
	ui.debug:ToolTip("fs_debug_tip")
	ui.spirits = g_extra:Slider("fs_spirits", 1, 3, 2)
	ui.spirits:Icon("\u{f0c0}")
	ui.spirits:ToolTip("fs_spirits_tip")

	ui.key = g_main:Bind("fs_key", Enum.ButtonCode.KEY_NONE, "\u{f1d8}")
	ui.key:ToolTip("fs_key_tip")
	ui.key:Properties(L("fs_bind_name"))

	ui.target = g_behave:Combo("fs_target", { "fs_targets_nearest", "fs_targets_weakest" }, 0)
	ui.target:Icon("\u{f05b}")
	ui.engage = g_behave:Slider("fs_engage", 400, 1600, 900)
	ui.engage:Icon("\u{f1ce}")
	ui.engage:ToolTip("fs_engage_tip")
	ui.push = g_behave:Switch("fs_push", true, "\u{f4d7}")
	ui.push:ToolTip("fs_push_tip")
	local g_speed = ui.push:Gear("fs_gear_speed")
	ui.reissue = g_speed:Slider("fs_reissue", 0.2, 3.0, 0.6, "%.1f s")
	ui.reissue:Icon("\u{f017}")

	ui.deny = g_behave:Switch("fs_deny", true, "\u{f00d}")
	ui.deny:ToolTip("fs_deny_tip")
	local g_deny = ui.deny:Gear("fs_gear_deny")
	ui.deny_hp = g_deny:Slider("fs_deny_hp", 20, 50, 50, "%d%%")
	ui.deny_hp:Icon("\u{f004}")
	ui.deny_hp:ToolTip("fs_deny_hp_tip")

	ui.lane_only = g_behave:Switch("fs_lane_only", true, "\u{f05b}")
	ui.lane_only:ToolTip("fs_lane_only_tip")

	ui.no_creeps = g_behave:Switch("fs_no_creeps", false, "\u{f05e}")
	ui.no_creeps:ToolTip("fs_no_creeps_tip")

	ui.lane_top = g_lane:Switch("fs_lane_top", true, "\u{f447}")
	ui.lane_mid = g_lane:Switch("fs_lane_mid", true, "\u{f447}")
	ui.lane_bot = g_lane:Switch("fs_lane_bot", true, "\u{f447}")
	g_lane:Label("fs_lane_any")

	local slot_options = { "fs_opt_auto", "fs_lane_top", "fs_lane_mid", "fs_lane_bot" }
	ui.slot1 = g_lane:Combo("fs_slot1", slot_options, 0)
	ui.slot1:Icon("\u{f447}")
	ui.slot2 = g_lane:Combo("fs_slot2", slot_options, 0)
	ui.slot2:Icon("\u{f447}")
	ui.slot3 = g_lane:Combo("fs_slot3", slot_options, 0)
	ui.slot3:Icon("\u{f447}")
	ui.slot1:ToolTip("fs_slots_tip")
end

local function refresh_disabled()
	local on = ui.enable:Get()
	local push_on = on and ui.push:Get() or false
	local deny_on = on and ui.deny:Get() or false

	ui.key:Disabled(not on)
	ui.mode:Disabled(not on)
	ui.debug:Disabled(not on)
	ui.spirits:Disabled(not on)
	ui.lane_top:Disabled(not on)
	ui.lane_mid:Disabled(not on)
	ui.lane_bot:Disabled(not on)
	ui.slot1:Disabled(not on)
	ui.slot2:Disabled(not on)
	ui.slot3:Disabled(not on)
	ui.target:Disabled(not on)
	ui.engage:Disabled(not on)
	ui.push:Disabled(not on)
	ui.deny:Disabled(not on)
	ui.deny_hp:Disabled(not deny_on)
	ui.lane_only:Disabled(not on)
	ui.no_creeps:Disabled(not on)
	ui.reissue:Disabled(not push_on)
end

ui.enable:SetCallback(refresh_disabled, true)
ui.push:SetCallback(refresh_disabled)
ui.deny:SetCallback(refresh_disabled)

local function log(text)
	if ui.debug:Get() then
		Log.Write("[ForgeSpirit] " .. text)
	end
end

local K = {
	SPIRIT_UNIT = "npc_dota_invoker_forged_spirit",
	HERO_UNIT   = "npc_dota_hero_invoker",
	CLUSTER     = 650,
	TICK        = 0.1,
	ORDER_GAP   = 0.05,
	TOWER_RANGE = 900,
	ENEMY_CREEP_RANGE = 900,
	LANES       = { "top", "mid", "bot" },
	SLOT_LANES  = { nil, "top", "mid", "bot" },
	-- Опорные точки лайнов. Берутся из карты, а не из живых вышек: вышки
	-- сносятся, и определение лайна пропадало вместе с ними.
	GROUND_Z = 128,
	-- Ломаные лайнов по всем вышкам, от базы Света к базе Тьмы. Одной
	-- опорной точки мало: крип, ушедший вглубь лайна, оказывался ближе по
	-- прямой к чужому лайну, и дух уходил бить не на свою линию.
	LANE_PATHS = {
		top = {
			{ x = -5712, y = -4864 }, { x = -6592, y = -3408 },
			{ x = -6501, y = -872 }, { x = -6336, y = 1856 },
			{ x = -5275, y = 6036 }, { x = -128, y = 6016 },
			{ x = 3552, y = 5776 }, { x = 4944, y = 4776 },
		},
		mid = {
			{ x = -4640, y = -4144 }, { x = -3190, y = -2926 },
			{ x = -1544, y = -1408 }, { x = 524, y = 652 },
			{ x = 2496, y = 2112 }, { x = 4272, y = 3759 },
		},
		bot = {
			{ x = -5392, y = -5192 }, { x = -3952, y = -6112 },
			{ x = -360, y = -6256 }, { x = 4860, y = -6379 },
			{ x = 6269, y = -2240 }, { x = 6400, y = 384 },
			{ x = 6336, y = 3032 }, { x = 5280, y = 4432 },
		},
	},
}

local state = {
	active     = false,
	orders     = {},
	spirit_seq = 0,
	next_tick  = 0,
	last_log   = 0,
	last_issue = -math.huge,
}

local floor, max = math.floor, math.max
local sqrt, format = math.sqrt, string.format

local function dist2d(ax, ay, bx, by)
	local dx, dy = ax - bx, ay - by
	return sqrt(dx * dx + dy * dy)
end

local function is_alive(npc)
	return npc and Entity.IsAlive(npc) == true
end

local function lane_enabled(lane)
	if lane == "top" then return ui.lane_top:Get() end
	if lane == "mid" then return ui.lane_mid:Get() end
	if lane == "bot" then return ui.lane_bot:Get() end
	return true
end

-- Расстояние от точки до отрезка: по нему считаем близость к лайну.
local function seg_dist(px, py, ax, ay, bx, by)
	local dx, dy = bx - ax, by - ay
	local len = dx * dx + dy * dy
	if len <= 0 then return dist2d(px, py, ax, ay) end

	local t = ((px - ax) * dx + (py - ay) * dy) / len
	if t < 0 then t = 0 elseif t > 1 then t = 1 end
	return dist2d(px, py, ax + t * dx, ay + t * dy)
end

-- Близость точки к лайну: минимум по всем отрезкам его ломаной.
local function lane_dist(lane, x, y)
	local path = K.LANE_PATHS[lane]
	if not path or #path < 2 then return math.huge end

	local best = math.huge
	for i = 1, #path - 1 do
		local a, b = path[i], path[i + 1]
		local d = seg_dist(x, y, a.x, a.y, b.x, b.y)
		if d < best then best = d end
	end
	return best
end

-- Лайн точки: ближайшая ломаная. Так крип в глубине лайна остается на нем.
local function lane_of(x, y)
	local best, best_d = nil, math.huge
	for l = 1, #K.LANES do
		local name = K.LANES[l]
		local d = lane_dist(name, x, y)
		if d < best_d then best, best_d = name, d end
	end
	return best
end

-- Куда идти по лайну: вражеская база, иначе самая дальняя точка ломаной.
local function lane_anchor(lane, enemy_team)
	local path = K.LANE_PATHS[lane]
	if not path or #path == 0 then return nil end

	local target
	if enemy_team == Enum.TeamNum.TEAM_RADIANT then
		target = path[1]
	else
		target = path[#path]
	end
	return { x = target.x, y = target.y, z = K.GROUND_Z }
end

local function issue(spirit, order_type, target, x, y, z, identifier)
	local ok_player, player = pcall(Players.GetLocal)
	if not ok_player or not player then return false end

	local position = nil
	if x then position = Vector(x, y, z) end

	local ok = pcall(Player.PrepareUnitOrders, player, order_type, target, position, nil,
		Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, spirit.npc,
		false, false, false, false, identifier, false)
	return ok
end

local function attack_specific(spirit, target, identifier)
	local ok_player, player = pcall(Players.GetLocal)
	if not ok_player or not player then return false end

	if type(Player.AttackTarget) == "function" then
		local ok = pcall(Player.AttackTarget, player, spirit.npc, target,
			false, false, true, identifier, false)
		if ok then return true end
	end
	return issue(spirit, Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET, target,
		nil, nil, nil, identifier)
end

local function deny_attack(spirit, target)
	return attack_specific(spirit, target, "forgespirit-deny")
end

local function find_lane_tower(spirit, lane)
	local ok, nearby = pcall(Entity.GetUnitsInRadius, spirit.npc,
		K.TOWER_RANGE, Enum.TeamType.TEAM_ENEMY, false, true)
	if not ok or not nearby then return nil end

	local best, best_d = nil, math.huge
	for i = 1, #nearby do
		local unit = nearby[i]
		if NPC.IsTower(unit) and is_alive(unit) and not Entity.IsDormant(unit) then
			local tx, ty = Entity.GetAbsOriginXYZ(unit)
			if lane_of(tx, ty) == lane then
				local d = dist2d(spirit.x, spirit.y, tx, ty)
				if d < best_d then best, best_d = unit, d end
			end
		end
	end
	return best
end

local function allied_creeps_on_tower(spirit)
	local ok, nearby = pcall(Entity.GetUnitsInRadius, spirit.npc,
		K.TOWER_RANGE, Enum.TeamType.TEAM_FRIEND, false, true)
	if not ok or not nearby then return false end

	for i = 1, #nearby do
		local unit = nearby[i]
		if unit ~= spirit.npc and NPC.IsLaneCreep(unit) and is_alive(unit) then
			return true
		end
	end
	return false
end

local function enemy_creeps_near(spirit)
	local ok, nearby = pcall(Entity.GetUnitsInRadius, spirit.npc,
		K.ENEMY_CREEP_RANGE, Enum.TeamType.TEAM_ENEMY, false, true)
	if not ok or not nearby then return false end

	for i = 1, #nearby do
		if NPC.IsLaneCreep(nearby[i]) and is_alive(nearby[i]) then
			return true
		end
	end
	return false
end

local function slot_lane(slot)
	local widget = nil
	if slot == 1 then widget = ui.slot1
	elseif slot == 2 then widget = ui.slot2
	elseif slot == 3 then widget = ui.slot3 end
	if not widget then return nil end
	return K.SLOT_LANES[widget:Get()]
end

local function assign(units, me, enemy_team)
	local per_lane = max(ui.spirits:Get(), 1)
	local weakest = ui.target:Get() == 1
	local engage = ui.engage:Get()
	local pushing = ui.push:Get()
	local deny = ui.deny:Get()
	local deny_ratio = ui.deny_hp:Get() / 100
	local lane_only = ui.lane_only:Get()
	local no_creeps = ui.no_creeps:Get()
	local refresh = ui.reissue:Get()
	local now = GameRules.GetGameTime()

	local spirits, waves, own = {}, {}, {}
	local ok_player, player = pcall(Players.GetLocal)
	local player_id = ok_player and player and Player.GetPlayerID(player) or nil

	for i = 1, #units do
		local unit = units[i]
		if unit and is_alive(unit) and not Entity.IsDormant(unit) then
			local name = NPC.GetUnitName(unit)

			if name == K.SPIRIT_UNIT and player_id
				and Entity.IsControllableByPlayer(unit, player_id) then
				local x, y, z = Entity.GetAbsOriginXYZ(unit)
				spirits[#spirits + 1] = { npc = unit, x = x, y = y, z = z }
			elseif unit ~= me and NPC.IsLaneCreep(unit) and not NPC.IsWaitingToSpawn(unit) then
				local x, y, z = Entity.GetAbsOriginXYZ(unit)

				if deny and not no_creeps and Entity.IsSameTeam(unit, me) then
					local hp = Entity.GetHealth(unit) or 0
					local max_hp = max(Entity.GetMaxHealth(unit) or 1, 1)
					if hp / max_hp <= deny_ratio then
						own[#own + 1] = {
							npc = unit, x = x, y = y, z = z, hp = hp,
							lane = lane_of(x, y),
						}
					end
				elseif not Entity.IsSameTeam(unit, me) then
					local group = nil
					for g = 1, #waves do
						if dist2d(x, y, waves[g].x, waves[g].y) <= K.CLUSTER then
							group = waves[g]
							break
						end
					end

					if not group then
						group = { x = x, y = y, z = z, count = 0, members = {}, lane = lane_of(x, y) }
						waves[#waves + 1] = group
					end

					group.count = group.count + 1
					group.x = (group.x * (group.count - 1) + x) / group.count
					group.y = (group.y * (group.count - 1) + y) / group.count
					group.members[#group.members + 1] = unit
					group.lane = lane_of(group.x, group.y)

					local hp = Entity.GetHealth(unit) or math.huge
					if not group.weakest or hp < group.weakest_hp then
						group.weakest, group.weakest_hp = unit, hp
					end
				end
			end
		end
	end

	local by_lane = {}
	for i = 1, #waves do
		local lane = waves[i].lane
		if lane and lane_enabled(lane) then
			by_lane[lane] = by_lane[lane] or {}
			local bucket = by_lane[lane]
			bucket[#bucket + 1] = waves[i]
		end
	end

	-- Лайны для выбора не зависят от крипов: иначе без волны дух встает.
	-- Своя башня лайна годится как цель похода, если вражеских не осталось.
	local my_team = Entity.GetTeamNum(me)
	local lane_choice = {}
	for l = 1, #K.LANES do
		local name = K.LANES[l]
		if lane_enabled(name) then
			local enemy_anchor = lane_anchor(name, enemy_team)
			local own_anchor = lane_anchor(name, my_team)
			if enemy_anchor or own_anchor then
				lane_choice[#lane_choice + 1] = {
					lane = name, enemy = enemy_anchor, own = own_anchor,
					has_wave = by_lane[name] ~= nil,
				}
			end
		end
	end

	-- Духи нумеруются по порядку первого обнаружения: индекс сущности для
	-- этого не годится, он не связан с порядком призыва.
	local function order_of(index)
		local record = state.orders[index]
		if not record then
			state.spirit_seq = state.spirit_seq + 1
			record = {
				target = nil, at = -math.huge, lane = nil,
				seq = state.spirit_seq,
			}
			state.orders[index] = record
		elseif not record.seq then
			state.spirit_seq = state.spirit_seq + 1
			record.seq = state.spirit_seq
		end
		return record
	end

	for i = 1, #spirits do
		spirits[i].index = Entity.GetIndex(spirits[i].npc)
		spirits[i].record = order_of(spirits[i].index)
	end
	table.sort(spirits, function(a, b)
		if a.record.seq ~= b.record.seq then return a.record.seq < b.record.seq end
		return a.index < b.index
	end)

	local claimed_lanes, deny_claimed = {}, {}
	-- Закрепленные лайны резервируются ДО раздачи: иначе авто-дух, идущий
	-- по списку раньше, не видел занятых закрепленных и вставал рядом.
	local pinned_by_index = {}
	for i = 1, #spirits do
		local want = slot_lane(i)
		if want and lane_enabled(want) then
			pinned_by_index[i] = want
			claimed_lanes[want] = (claimed_lanes[want] or 0) + 1
		end
	end

	for i = 1, #spirits do
		local spirit = spirits[i]
		local index = spirit.index
		local record = spirit.record
		local identifier = "forgespirit-" .. tostring(index)
		local due = now - record.at >= refresh

		-- Приказы разным юнитам в одном кадре клиент принимает не все.
		-- Пауза считается по state.last_issue, иначе счетчик сбрасывался
		-- каждый тик и приказ всегда доставался первому духу в списке.
		local can_issue = now - state.last_issue >= K.ORDER_GAP
		local issued = false

		-- 1. Лайн: закрепленный держим всегда, свой - пока он не переполнен.
		local pinned = pinned_by_index[i]
		local lane
		if pinned then
			lane = pinned
		else
			lane = record.lane
			-- Авто-дух не должен сидеть на лайне, занятом закрепленным:
			-- иначе они ходят парой, а третий остается один.
			local taken_by_pin = false
			for s = 1, #spirits do
				if pinned_by_index[s] == lane then
					taken_by_pin = true
					break
				end
			end

			local holds = lane ~= nil
				and lane_enabled(lane)
				and not taken_by_pin
				and (claimed_lanes[lane] or 0) < per_lane

			if not holds then
				-- Сначала свободный лайн под лимитом, с крипами в приоритете.
				local free, free_d, free_wave = nil, math.huge, false
				local any, any_d = nil, math.huge

				for c = 1, #lane_choice do
					local candidate = lane_choice[c]
					local anchor = candidate.enemy or candidate.own
					if anchor then
						local d = dist2d(spirit.x, spirit.y, anchor.x, anchor.y)

						if d < any_d then any, any_d = candidate.lane, d end

						local taken = false
						for s = 1, #spirits do
							if pinned_by_index[s] == candidate.lane then
								taken = true
								break
							end
						end

						if not taken and (claimed_lanes[candidate.lane] or 0) < per_lane then
							local better = false
							if candidate.has_wave and not free_wave then
								better = true
							elseif candidate.has_wave == free_wave and d < free_d then
								better = true
							end
							if better then
								free, free_d, free_wave = candidate.lane, d, candidate.has_wave
							end
						end
					end
				end

				-- Лимит исчерпан, но стоять хуже, чем делить лайн: берем ближайший.
				lane = free or any
			end

			if lane then
				claimed_lanes[lane] = (claimed_lanes[lane] or 0) + 1
				record.lane = lane
			end
		end

		-- 2. Добивание своих крипов. Только в своем лайне: иначе дух уходит
		-- добивать через всю карту и бросает порученный лайн.
		local deny_target, deny_d, deny_index = nil, math.huge, nil
		if deny and not no_creeps then
			for d = 1, #own do
				local creep = own[d]
				if not deny_claimed[d]
					and (not lane_only or creep.lane == lane) then
					local dist = dist2d(spirit.x, spirit.y, creep.x, creep.y)
					if dist < deny_d then deny_target, deny_d, deny_index = creep, dist, d end
				end
			end
		end

		if deny_target then
			deny_claimed[deny_index] = true
			spirit.lane = lane_of(deny_target.x, deny_target.y) or lane
			if (record.target ~= deny_target.npc or due) and can_issue then
				if deny_d <= engage then
					deny_attack(spirit, deny_target.npc)
				else
					issue(spirit, Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION, nil,
						deny_target.x, deny_target.y, deny_target.z, identifier)
				end
				record.at = now
				record.target = deny_target.npc
				issued = true
			end
		else
			spirit.lane = lane

			-- Волну берем только своего лайна. Иначе дух бросает порученный
			-- лайн и идет бить крипов на чужом.
			local bucket = lane and by_lane[lane] or nil
			local wave = nil
			if bucket and not no_creeps then
				local best_d = math.huge
				for b = 1, #bucket do
					local d = dist2d(spirit.x, spirit.y, bucket[b].x, bucket[b].y)
					if d < best_d then wave, best_d = bucket[b], d end
				end
			end

			if wave then
				local target = wave.weakest
				if not weakest then
					local nearest, nearest_d = nil, math.huge
					for m = 1, #wave.members do
						local creep = wave.members[m]
						local cx, cy = Entity.GetAbsOriginXYZ(creep)
						local d = dist2d(spirit.x, spirit.y, cx, cy)
						if d < nearest_d then nearest, nearest_d = creep, d end
					end
					target = nearest
				end
				if not target then target = wave.weakest end

				-- Строгий режим: бьем крипа, только если он в нашем лайне.
				if target and lane_only then
					local tx, ty = Entity.GetAbsOriginXYZ(target)
					if lane_of(tx, ty) ~= lane then target = nil end
				end

				if target and (record.target ~= target or due) and can_issue then
					local reach = dist2d(spirit.x, spirit.y, wave.x, wave.y)
					if reach <= engage then
						attack_specific(spirit, target, identifier)
					else
						issue(spirit, Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION, nil,
							wave.x, wave.y, wave.z, identifier)
					end
					record.at = now
					record.target = target
					issued = true
				end
			end

			if not issued then
				-- У башни в своем лайне, союзные крипы ее ломают, вражеских
				-- нет: дух помогает ломать башню, а не стоит рядом.
				local tower = nil
				if not no_creeps and lane then
					tower = find_lane_tower(spirit, lane)
					if tower and not allied_creeps_on_tower(spirit) then tower = nil end
					if tower and enemy_creeps_near(spirit) then tower = nil end
				end
				if tower then
					if (record.target ~= tower or due) and can_issue then
						attack_specific(spirit, tower, identifier)
						record.at = now
						record.target = tower
						issued = true
					end
				end

				-- Волн в лайне нет: дух идет по своему лайну к вражеской башне.
				-- Своя башня нужна только когда вражеских не осталось.
				-- Закрепленный лайн духи пушат всегда: раз лайн указан явно,
				-- отсутствие видимых крипов его не останавливает.
				local anchor = nil
				for c = 1, #lane_choice do
					if lane_choice[c].lane == lane then
						anchor = lane_choice[c].enemy or lane_choice[c].own
						break
					end
				end
				if anchor and (pushing or pinned) and due and can_issue then
					issue(spirit, Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION, nil,
						anchor.x, anchor.y, anchor.z, identifier)
					record.at = now
					record.target = nil
					issued = true
				end
			end
		end

		if issued then state.last_issue = now end
	end

	local wave_count = 0
	for i = 1, #waves do
		if waves[i].lane and lane_enabled(waves[i].lane) then wave_count = wave_count + 1 end
	end

	local lanes = {}
	for i = 1, #spirits do
		local slot = i
		local pinned = slot_lane(slot)
		lanes[#lanes + 1] = format("%d:%s%s", slot,
			tostring(spirits[i].lane or "-"),
			pinned and "*" or "")
	end

	return #spirits, wave_count, #own, table.concat(lanes, " ")
end

function script.OnUpdate()
	if not ui.enable:Get() then
		state.active = false
		return
	end

	local me = Heroes.GetLocal()
	if not me or not Entity.IsAlive(me) or NPC.GetUnitName(me) ~= K.HERO_UNIT then
		state.active = false
		return
	end

	local key = ui.key:Get()
	if key and key ~= Enum.ButtonCode.KEY_NONE then
		if ui.mode:Get() == 1 then
			state.active = ui.key:IsDown()
		elseif ui.key:IsPressed() and not Input.IsInputCaptured() then
			state.active = not state.active
			log(state.active and "turned on" or "turned off")
		end
	end

	local now = GameRules.GetGameTime()
	if now < state.next_tick then return end
	state.next_tick = now + K.TICK

	local ok, units = pcall(NPCs.GetAll)
	if not ok or not units then return end

	if not state.active then
		if ui.debug:Get() and now - state.last_log > 3 then
			state.last_log = now
			log("waiting for the key")
		end
		return
	end

	local enemy_team = Entity.GetTeamNum(me) == Enum.TeamNum.TEAM_RADIANT
		and Enum.TeamNum.TEAM_DIRE or Enum.TeamNum.TEAM_RADIANT

	local spirit_count, wave_count, deny_count, lane_names = assign(units, me, enemy_team)

	if ui.debug:Get() and now - state.last_log > 2 then
		state.last_log = now
		log(format("spirits=%d [%s] waves=%d deny=%d",
			spirit_count, lane_names, wave_count, deny_count))
	end
end

function script.OnScriptsLoaded()
	log("loaded")
end

function script.OnGameEnd()
	state.active = false
	state.orders = {}
	state.spirit_seq = 0
	state.last_issue = -math.huge
end

function script.OnEntityDestroy(entity)
	if entity then state.orders[Entity.GetIndex(entity)] = nil end
end

return script
