-- Magnus Skewer Ally v1.0.0
-- Author: sataroz (Discord: sataroz)

local VERSION = "1.0.0"

---@diagnostic disable: undefined-global, param-type-mismatch, inject-field
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
        msa_group = "Hero Settings",
        msa_skewer_to_ally = "Skewer To Ally: Enabled",
        msa_ally_selection_mode = "Ally Selection Mode",
        msa_groups_select_from_list = "Select from List",
        msa_groups_nearest_ally_to = "Nearest Ally to Cursor",
        msa_groups_nearest_ally_to_2 = "Nearest Ally to Magnus",
        msa_target_ally_hero = "Target Ally Hero",
        msa_groups_none_default_combo = "None (Default Combo)",
        msa_skewer_distance_mode = "Skewer Distance Mode",
        msa_groups_max_range_in = "Max Range in Direction",
        msa_groups_exact_target_position = "Exact Target Position",
        msa_use_harpoon_in = "Use Harpoon in Combo",
        msa_lock_ally_under = "Lock Ally under Cursor",
        msa_gear_enabled = "Ally Skewer Settings",
        msa_fallback_on_dead = "Fallback to Default if Dead",
        msa_draw_indicator = "Draw Ally / Ground Marker",
        msa_draw_line = "Draw Line to Target",
        msa_draw_radius = "Draw Ground Reach Radius",
        msa_draw_enemy_preview = "Show Enemy Hover Info",
        msa_color_reach = "Can Reach Color",
        msa_color_cant_reach = "Cannot Reach Color",
        msa_debug = "Debug Log",
        msa_notif_target = "Skewer Target: %s",
        msa_notif_ground = "Skewer Target: Ground Point",
        msa_text_point_in = "[POINT: IN RANGE]",
        msa_text_point_out = "[POINT: OUT OF RANGE]",
        msa_text_skewer_in = "[SKEWER: IN RANGE]",
        msa_text_skewer_out = "[SKEWER: OUT OF RANGE]",
        msa_text_range_need = "Need +%d range (%d / %d)",
        msa_text_dist = "Dist: %d / %d",
        msa_text_can_point = "CAN SKEWER TO POINT",
        msa_text_far_point = "TOO FAR FOR POINT",
        msa_text_can_ally = "CAN SKEWER TO %s",
        msa_text_far_ally = "TOO FAR FOR %s",
    },
    ru = {
        msa_group = "Настройки героя",
        msa_skewer_to_ally = "Skewer в союзника: включено",
        msa_ally_selection_mode = "Режим выбора союзника",
        msa_groups_select_from_list = "Выбор из списка",
        msa_groups_nearest_ally_to = "Ближайший союзник к курсору",
        msa_groups_nearest_ally_to_2 = "Ближайший союзник к Магнусу",
        msa_target_ally_hero = "Союзник для Skewer",
        msa_groups_none_default_combo = "Нет (стандартное комбо)",
        msa_skewer_distance_mode = "Режим дистанции Skewer",
        msa_groups_max_range_in = "Максимальная дальность по направлению",
        msa_groups_exact_target_position = "Точная позиция цели",
        msa_use_harpoon_in = "Гарпун в комбо",
        msa_lock_ally_under = "Захват союзника под курсором",
        msa_gear_enabled = "Настройки Skewer в союзника",
        msa_fallback_on_dead = "Стандартное комбо, если цель мертва",
        msa_draw_indicator = "Маркер союзника / точки",
        msa_draw_line = "Линия к цели",
        msa_draw_radius = "Радиус досягаемости на земле",
        msa_draw_enemy_preview = "Инфо о враге под курсором",
        msa_color_reach = "Цвет доступной цели",
        msa_color_cant_reach = "Цвет недоступной цели",
        msa_debug = "Отладочный лог",
        msa_notif_target = "Цель Skewer: %s",
        msa_notif_ground = "Цель Skewer: точка на земле",
        msa_text_point_in = "[ТОЧКА: В РАДИУСЕ]",
        msa_text_point_out = "[ТОЧКА: ВНЕ РАДИУСА]",
        msa_text_skewer_in = "[СКЬЮЕР: В РАДИУСЕ]",
        msa_text_skewer_out = "[СКЬЮЕР: ВНЕ РАДИУСА]",
        msa_text_range_need = "Не хватает +%d (%d / %d)",
        msa_text_dist = "Дист: %d / %d",
        msa_text_can_point = "МОЖНО СКЬЮЕРИТЬ В ТОЧКУ",
        msa_text_far_point = "СЛИШКОМ ДАЛЕКО ДЛЯ ТОЧКИ",
        msa_text_can_ally = "МОЖНО СКЬЮЕРИТЬ В %s",
        msa_text_far_ally = "СЛИШКОМ ДАЛЕКО ДЛЯ %s",
    },
})

local Menu = localization.WrapLibrary(Menu)

local magnus_skewer_addon = {}

local group = Menu.Create("Heroes", "Hero List", "Magnus", "Main Settings", "msa_group")

local ui = {
    enabled = group:Switch("msa_skewer_to_ally", true, "\u{f00c}"),
    target_mode = group:Combo("msa_ally_selection_mode", {
        "msa_groups_select_from_list",
        "msa_groups_nearest_ally_to",
        "msa_groups_nearest_ally_to_2"
    }, 0),
    ally_list = group:Combo("msa_target_ally_hero", { "msa_groups_none_default_combo" }, 0),
    cast_range_mode = group:Combo("msa_skewer_distance_mode", {
        "msa_groups_max_range_in",
        "msa_groups_exact_target_position"
    }, 0),
    use_harpoon = group:Switch("msa_use_harpoon_in", true, "\u{f0c1}"),
    bind_pick_cursor = group:Bind("msa_lock_ally_under", Enum.ButtonCode.BUTTON_CODE_INVALID, "\u{f05b}")
}

local gear = ui.enabled:Gear("msa_gear_enabled")
ui.fallback_on_dead = gear:Switch("msa_fallback_on_dead", true)
ui.draw_indicator = gear:Switch("msa_draw_indicator", true)
ui.draw_line = gear:Switch("msa_draw_line", true)
ui.draw_radius = gear:Switch("msa_draw_radius", true)
ui.draw_enemy_preview = gear:Switch("msa_draw_enemy_preview", true)
ui.color_reach = gear:ColorPicker("msa_color_reach", Color(50, 220, 50, 255))
ui.color_cant_reach = gear:ColorPicker("msa_color_cant_reach", Color(240, 50, 50, 255))
ui.debug = gear:Switch("msa_debug", false)

local function DebugLog(msg)
    if ui.debug:Get() then
        Log.Write("[MagnusSkewer] " .. msg)
    end
end

local my_hero = nil
local ally_cache = {}
local locked_target_index = nil
local locked_target_hero = nil
local custom_ground_pos = nil
local current_target_hero = nil
local current_hovered_enemy = nil

local last_hero_update = 0
local last_lock_time = 0
local last_skewer_time = 0
local last_harpoon_time = 0
local last_notif_target = nil
local last_notif_time = 0

local combo_press_start = 0
local is_combo_active = false
local is_internal_update = false
local key_state = {}

local combo_key_w = nil
local skewer_combo_w = nil
local abilities_w = nil

local font_main = Render.LoadFont("Arial", Enum.FontCreate.FONTFLAG_ANTIALIAS | Enum.FontCreate.FONTFLAG_DROPSHADOW, 600)
local font_small = Render.LoadFont("Arial", Enum.FontCreate.FONTFLAG_ANTIALIAS, 400)

local function HasAghanimShard()
    return my_hero and NPC.HasShard(my_hero) or false
end

local function GetCurrentSkewerRange()
    if not my_hero then return 1100 end
    local skewer = NPC.GetAbility(my_hero, "magnataur_skewer")
    local lvl = skewer and Ability.GetLevel(skewer) or 0
    if not skewer or lvl == 0 then
        return 1100
    end

    local base = Ability.GetLevelSpecialValueFor(skewer, "range")
    if not base or base <= 0 then
        base = ({ 800, 900, 1000, 1100 })[lvl] or 1100
    end

    local range = base
    local cast_range = Ability.GetCastRange(skewer)
    if cast_range and cast_range > range then
        range = cast_range
    end

    if HasAghanimShard() and range < base + 300 then
        range = base + 300
    end

    return range
end

local function GetSkewerRadius()
    if not my_hero then return 145 end
    local skewer = NPC.GetAbility(my_hero, "magnataur_skewer")
    if not skewer or Ability.GetLevel(skewer) == 0 then return 145 end
    local r = Ability.GetLevelSpecialValueFor(skewer, "skewer_radius")
    if r and r > 0 then return r end
    return 145
end

local function GetHarpoonRange(harpoon)
    if not harpoon then return 700 end
    local r = Ability.GetCastRange(harpoon)
    return (r and r > 0) and r or 700
end

local function ShowNotification(text, target_id)
    if not text or text == "" then return end
    local cur_time = GlobalVars.GetCurTime()
    if target_id and target_id == last_notif_target and (cur_time - last_notif_time < 0.5) then
        return
    end
    last_notif_target = target_id
    last_notif_time = cur_time

    Render.CenteredNotification(text, 2.0)
end

local function GetHeroDisplayName(hero)
    local raw = NPC.GetUnitName(hero)
    for _, entry in ipairs(ally_cache) do
        if entry.unit_name == raw then
            return entry.name
        end
    end
    local loc_name = GameLocalizer.FindNPC(raw)
    if loc_name and loc_name ~= "" then
        return loc_name
    end
    return (raw:gsub("npc_dota_hero_", ""))
end

local function UpdateAllyHeroesList(force)
    if not my_hero then return end

    local new_allies = {}
    local menu_items = { "msa_groups_none_default_combo" }
    local all_heroes = Heroes.GetAll()

    for _, hero in ipairs(all_heroes) do
        if hero and hero ~= my_hero and Entity.GetIndex(hero) ~= Entity.GetIndex(my_hero)
           and Entity.IsSameTeam(my_hero, hero) and not NPC.IsIllusion(hero) then
            local loc_name = GetHeroDisplayName(hero)
            table.insert(new_allies, {
                hero = hero,
                index = Entity.GetIndex(hero),
                name = loc_name,
                unit_name = NPC.GetUnitName(hero)
            })
            table.insert(menu_items, loc_name)
        end
    end

    local changed = force or (#new_allies ~= #ally_cache)
    if not changed then
        for i = 1, #new_allies do
            if not ally_cache[i] or ally_cache[i].index ~= new_allies[i].index then
                changed = true
                break
            end
        end
    end

    if changed then
        ally_cache = new_allies
        local target_idx = 0
        if custom_ground_pos then
            target_idx = 0
        elseif locked_target_index then
            for idx, entry in ipairs(ally_cache) do
                if entry.index == locked_target_index then
                    target_idx = idx
                    break
                end
            end
        else
            local cur = ui.ally_list:Get()
            if cur > 0 and cur <= #new_allies then
                target_idx = cur
            end
        end

        is_internal_update = true
        ui.ally_list:Update(menu_items, target_idx)
        is_internal_update = false
    end
end

local function FindAllyUnderCursor()
    if not my_hero then return nil end
    local cursor_world = Input.GetWorldCursorPos()
    local cx, cy = Input.GetCursorPos()
    if not cursor_world or not cx or not cy then return nil end

    local best_hero = nil
    local best_dist = math.huge

    local all_heroes = Heroes.GetAll()
    for _, h in ipairs(all_heroes) do
        if h and h ~= my_hero and Entity.IsSameTeam(my_hero, h)
           and Entity.IsAlive(h) and not Entity.IsDormant(h) and not NPC.IsIllusion(h) then
            local h_pos = Entity.GetAbsOrigin(h)
            local world_dist = cursor_world:Distance2D(h_pos)

            local screen_pos, on_screen = Render.WorldToScreen(h_pos)
            local screen_dist = math.huge
            if on_screen and screen_pos then
                local dx = cx - screen_pos.x
                local dy = cy - screen_pos.y
                screen_dist = math.sqrt(dx * dx + dy * dy)
            end

            if (world_dist <= 200 or screen_dist <= 80) and world_dist < best_dist then
                best_dist = world_dist
                best_hero = h
            end
        end
    end

    return best_hero
end

local function LockTarget(target_hero)
    if not target_hero or not my_hero then return false end
    local target_idx = Entity.GetIndex(target_hero)
    if target_idx == Entity.GetIndex(my_hero) then return false end

    local cur_time = GlobalVars.GetCurTime()
    if cur_time - last_lock_time < 0.15 and locked_target_index == target_idx then
        return true
    end
    last_lock_time = cur_time

    custom_ground_pos = nil
    locked_target_index = target_idx
    locked_target_hero = target_hero
    current_target_hero = target_hero

    UpdateAllyHeroesList(true)

    local matched_idx = 0
    for idx, entry in ipairs(ally_cache) do
        if entry.index == target_idx or entry.unit_name == NPC.GetUnitName(target_hero) then
            matched_idx = idx
            break
        end
    end

    is_internal_update = true
    if matched_idx > 0 then
        ui.ally_list:Set(matched_idx)
    end
    ui.target_mode:Set(0)
    is_internal_update = false

    local ally_name = GetHeroDisplayName(target_hero)
    DebugLog("target locked: " .. ally_name)
    ShowNotification(string.format(localization.Get("msa_notif_target"), ally_name), target_idx)
    return true
end

local function LockGroundPoint(pos)
    if not pos then return false end
    local cur_time = GlobalVars.GetCurTime()
    if cur_time - last_lock_time < 0.15 then return true end
    last_lock_time = cur_time

    custom_ground_pos = Vector(pos.x, pos.y, pos.z)
    locked_target_index = nil
    locked_target_hero = nil
    current_target_hero = nil

    is_internal_update = true
    ui.ally_list:Set(0)
    is_internal_update = false

    DebugLog("target locked: ground point")
    ShowNotification(localization.Get("msa_notif_ground"), 999999)
    return true
end

local function HandleTargetBindPress()
    local ally = FindAllyUnderCursor()
    if ally then
        LockTarget(ally)
    else
        local cursor_world = Input.GetWorldCursorPos()
        if cursor_world then
            LockGroundPoint(cursor_world)
        end
    end
end

ui.ally_list:SetCallback(function(this)
    if is_internal_update then return end

    local idx = this:Get()
    if idx > 0 and ally_cache[idx] then
        local entry = ally_cache[idx]
        local h = entry.hero
        if h and Entity.IsAlive(h) then
            custom_ground_pos = nil
            locked_target_index = entry.index
            locked_target_hero = h
            current_target_hero = h
            ShowNotification(string.format(localization.Get("msa_notif_target"), entry.name), entry.index)
        end
    else
        locked_target_index = nil
        locked_target_hero = nil
        current_target_hero = nil
    end
end)

ui.bind_pick_cursor:SetKeyCallback(function(this, key, event)
    if event == Enum.EKeyEvent.EKeyEvent_KEY_DOWN then
        HandleTargetBindPress()
    end
end)

local function ResolveTargetHero()
    if not my_hero or not ui.enabled:Get() then return nil end
    if custom_ground_pos then return nil end

    local mode = ui.target_mode:Get()

    local idx = ui.ally_list:Get()
    if idx > 0 and ally_cache[idx] then
        local h = ally_cache[idx].hero
        if h and Entity.IsAlive(h) and not Entity.IsDormant(h) then
            return h
        end
    end

    if locked_target_index then
        local ent = Entity.Get(locked_target_index)
        if ent and Entity.IsAlive(ent) and not Entity.IsDormant(ent) then
            return ent
        end
    end

    if mode == 0 then return nil end
    if mode == 1 then return FindAllyUnderCursor() end

    if mode == 2 then
        local mag_pos = Entity.GetAbsOrigin(my_hero)
        local best_hero = nil
        local best_dist = math.huge
        for _, entry in ipairs(ally_cache) do
            local hero = entry.hero
            if hero and Entity.IsAlive(hero) and not Entity.IsDormant(hero) then
                local dist = mag_pos:Distance2D(Entity.GetAbsOrigin(hero))
                if dist < best_dist then
                    best_dist = dist
                    best_hero = hero
                end
            end
        end
        return best_hero
    end

    return nil
end

local function GetTargetDestination()
    if not ui.enabled:Get() then return nil, nil, nil end
    if custom_ground_pos then
        return custom_ground_pos, "ground", nil
    end
    local ally = ResolveTargetHero()
    if ally and Entity.IsAlive(ally) and not Entity.IsDormant(ally) then
        return Entity.GetAbsOrigin(ally), "ally", ally
    end
    return nil, nil, nil
end

local function GetHoveredEnemy()
    if not my_hero then return nil end
    local my_team = Entity.GetTeamNum(my_hero)
    local nearest = Input.GetNearestHeroToCursor(my_team, Enum.TeamType.TEAM_ENEMY)
    if nearest and Entity.IsAlive(nearest) and not Entity.IsDormant(nearest) then
        local cursor_pos = Input.GetWorldCursorPos()
        local enemy_pos = Entity.GetAbsOrigin(nearest)
        if cursor_pos:Distance2D(enemy_pos) <= 350 then
            return nearest
        end
    end
    return nil
end

local function FindBestComboEnemy(range_limit)
    if not my_hero then return nil end
    local mag_pos = Entity.GetAbsOrigin(my_hero)
    range_limit = range_limit or 900

    local all_heroes = Heroes.GetAll()

    for _, enemy in ipairs(all_heroes) do
        if enemy and not Entity.IsSameTeam(my_hero, enemy)
           and Entity.IsAlive(enemy) and not Entity.IsDormant(enemy)
           and not NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE) then
            if NPC.HasModifier(enemy, "modifier_magnataur_reverse_polarity")
               or NPC.HasModifier(enemy, "modifier_magnataur_horn_toss") then
                return enemy
            end
        end
    end

    if current_hovered_enemy and Entity.IsAlive(current_hovered_enemy)
       and not Entity.IsDormant(current_hovered_enemy)
       and not NPC.HasState(current_hovered_enemy, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE) then
        local edist = mag_pos:Distance2D(Entity.GetAbsOrigin(current_hovered_enemy))
        if edist <= range_limit then
            return current_hovered_enemy
        end
    end

    local best_enemy = nil
    local best_score = range_limit
    local cursor_pos = Input.GetWorldCursorPos()

    for _, enemy in ipairs(all_heroes) do
        if enemy and not Entity.IsSameTeam(my_hero, enemy)
           and Entity.IsAlive(enemy) and not Entity.IsDormant(enemy)
           and not NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE) and not NPC.IsIllusion(enemy) then
            local e_pos = Entity.GetAbsOrigin(enemy)
            local m_dist = mag_pos:Distance2D(e_pos)
            if m_dist <= range_limit then
                local c_dist = cursor_pos and cursor_pos:Distance2D(e_pos) or m_dist
                local score = (m_dist * 0.4) + (c_dist * 0.6)
                if score < best_score then
                    best_score = score
                    best_enemy = enemy
                end
            end
        end
    end

    return best_enemy
end

local function IsComboKeyDown()
    if not combo_key_w then
        combo_key_w = Menu.Find("Heroes", "Hero List", "Magnus", "Main Settings", "Hero Settings", "Combo Key")
    end
    if combo_key_w and combo_key_w.IsDown and combo_key_w:IsDown() then
        return true
    end

    if not skewer_combo_w then
        skewer_combo_w = Menu.Find("Heroes", "Hero List", "Magnus", "Main Settings", "Skewer Combo Settings", "Skewer Combo Work Key")
    end
    if skewer_combo_w and skewer_combo_w.IsDown and skewer_combo_w:IsDown() then
        return true
    end

    if key_state[Enum.ButtonCode.KEY_SPACE] then
        return true
    end

    if combo_key_w and combo_key_w.Buttons then
        local k1, k2 = combo_key_w:Buttons()
        if (k1 and k1 > 0 and key_state[k1]) or (k2 and k2 > 0 and key_state[k2]) then
            return true
        end
    end

    if skewer_combo_w and skewer_combo_w.Buttons then
        local s1, s2 = skewer_combo_w:Buttons()
        if (s1 and s1 > 0 and key_state[s1]) or (s2 and s2 > 0 and key_state[s2]) then
            return true
        end
    end

    return false
end

local function SetBuiltinComboSkewer(enabled)
    if not abilities_w then
        abilities_w = Menu.Find("Heroes", "Hero List", "Magnus", "Main Settings", "Hero Settings", "Abilities")
    end
    if abilities_w and abilities_w.Get and abilities_w.Set then
        if abilities_w:Get("magnataur_skewer") ~= enabled then
            abilities_w:Set("magnataur_skewer", enabled)
            DebugLog("builtin skewer combo: " .. tostring(enabled))
        end
    end
end

local function CastHarpoonOn(harpoon, target_enemy)
    last_harpoon_time = GlobalVars.GetCurTime()
    DebugLog("harpoon cast")
    Ability.CastTarget(harpoon, target_enemy, false, false, true, "MagnusHarpoonCatch")
end

function magnus_skewer_addon.OnUpdate()
    if not my_hero then
        my_hero = Heroes.GetLocal()
        if not my_hero then return end
    end

    if NPC.GetUnitName(my_hero) ~= "npc_dota_hero_magnataur" then return end

    local cur_time = GlobalVars.GetCurTime()
    if cur_time - last_hero_update > 1.0 then
        last_hero_update = cur_time
        UpdateAllyHeroesList()
    end

    current_target_hero = ResolveTargetHero()
    current_hovered_enemy = GetHoveredEnemy()

    local dest_pos, dest_type, target_ally = GetTargetDestination()
    local combo_down = IsComboKeyDown()

    if combo_down then
        if not is_combo_active then
            is_combo_active = true
            combo_press_start = cur_time
        end
    else
        is_combo_active = false
        combo_press_start = 0
    end

    if ui.enabled:Get() and dest_pos then
        SetBuiltinComboSkewer(false)
    else
        SetBuiltinComboSkewer(true)
    end

    if ui.enabled:Get() and ui.use_harpoon:Get() and combo_down
       and NPC.HasModifier(my_hero, "modifier_magnataur_skewer_movement")
       and (cur_time - last_harpoon_time > 0.6) then
        local harpoon = NPC.GetItem(my_hero, "item_harpoon")
        if harpoon and Ability.IsCastable(harpoon, NPC.GetMana(my_hero)) then
            local hr = GetHarpoonRange(harpoon)
            local h_enemy = FindBestComboEnemy(hr + 100)
            if h_enemy then
                CastHarpoonOn(harpoon, h_enemy)
            end
        end
    end

    if ui.enabled:Get() and dest_pos and combo_down then
        local skewer = NPC.GetAbility(my_hero, "magnataur_skewer")
        local rp = NPC.GetAbility(my_hero, "magnataur_reverse_polarity")
        local horn = NPC.GetAbility(my_hero, "magnataur_horn_toss")

        if skewer and Ability.IsCastable(skewer, NPC.GetMana(my_hero))
           and not Ability.IsInAbilityPhase(skewer)
           and not NPC.HasModifier(my_hero, "modifier_magnataur_skewer_movement")
           and not NPC.IsStunned(my_hero) and not NPC.IsSilenced(my_hero) then

            local is_rp_busy = rp and (Ability.IsInAbilityPhase(rp) or NPC.IsChannellingAbility(my_hero))
            local is_horn_busy = horn and Ability.IsInAbilityPhase(horn)

            if not is_rp_busy and not is_horn_busy then
                local mag_pos = Entity.GetAbsOrigin(my_hero)
                local caught_enemy = nil
                local nearby_enemy = nil
                local all_heroes = Heroes.GetAll()

                for _, enemy in ipairs(all_heroes) do
                    if enemy and not Entity.IsSameTeam(my_hero, enemy) and Entity.IsAlive(enemy) and not Entity.IsDormant(enemy) then
                        local edist = mag_pos:Distance2D(Entity.GetAbsOrigin(enemy))
                        if NPC.HasModifier(enemy, "modifier_magnataur_reverse_polarity")
                           or NPC.HasModifier(enemy, "modifier_magnataur_horn_toss") then
                            caught_enemy = enemy
                            break
                        elseif edist <= 500 then
                            nearby_enemy = enemy
                        end
                    end
                end

                local target_enemy = caught_enemy or nearby_enemy or FindBestComboEnemy(750)
                if target_enemy then
                    local should_skewer = false

                    if caught_enemy then
                        should_skewer = true
                    elseif rp and Ability.GetLevel(rp) > 0 and (not Ability.IsReady(rp) or Ability.GetCooldown(rp) > 0) then
                        should_skewer = true
                    elseif not rp or Ability.GetLevel(rp) == 0 or not Ability.IsCastable(rp, NPC.GetMana(my_hero)) then
                        should_skewer = true
                    elseif cur_time - combo_press_start > 0.35 then
                        should_skewer = true
                    end

                    if should_skewer and (cur_time - last_skewer_time > 0.6) then
                        local skewer_range = GetCurrentSkewerRange()
                        local cast_pos = dest_pos
                        if ui.cast_range_mode:Get() == 0 then
                            local dir = mag_pos:DirectionTo(dest_pos, skewer_range)
                            cast_pos = mag_pos + dir
                        end
                        cast_pos.z = dest_pos.z

                        local edist = mag_pos:Distance2D(Entity.GetAbsOrigin(target_enemy))
                        local grab_radius = GetSkewerRadius()
                        local harpoon = NPC.GetItem(my_hero, "item_harpoon")
                        local harpoon_ready = harpoon and Ability.IsCastable(harpoon, NPC.GetMana(my_hero))
                        local hr = harpoon_ready and GetHarpoonRange(harpoon) or 700

                        if edist > grab_radius and edist <= (hr + 50) and harpoon_ready and ui.use_harpoon:Get() then
                            CastHarpoonOn(harpoon, target_enemy)
                            Ability.CastPosition(skewer, cast_pos, false, false, true, "MagnusSkewerRedirect")
                            last_skewer_time = cur_time
                        elseif edist <= grab_radius then
                            DebugLog(string.format("skewer cast: dist %.0f, radius %.0f", edist, grab_radius))
                            Ability.CastPosition(skewer, cast_pos, false, false, true, "MagnusSkewerRedirect")
                            last_skewer_time = cur_time
                        end
                    end
                end
            end
        end
    end
end

function magnus_skewer_addon.OnKeyEvent(data)
    if not data then return true end

    if data.event == Enum.EKeyEvent.EKeyEvent_KEY_DOWN then
        key_state[data.key] = true
    elseif data.event == Enum.EKeyEvent.EKeyEvent_KEY_UP then
        key_state[data.key] = false
    end

    if data.event == Enum.EKeyEvent.EKeyEvent_KEY_DOWN and ui.enabled:Get() then
        local b1, b2 = ui.bind_pick_cursor:Buttons()
        local is_our_key = (b1 and b1 > 0 and data.key == b1) or
                           (b2 and b2 > 0 and data.key == b2)

        if is_our_key then
            HandleTargetBindPress()
        end
    end
    return true
end

function magnus_skewer_addon.OnPrepareUnitOrders(order)
    if not ui.enabled:Get() or not order then return true end
    if not my_hero or NPC.GetUnitName(my_hero) ~= "npc_dota_hero_magnataur" then return true end

    if order.ability and Ability.GetName(order.ability) == "magnataur_skewer" then
        if order.identifier == "MagnusSkewerRedirect" then
            return true
        end

        if not IsComboKeyDown() then
            return true
        end

        local dest_pos = GetTargetDestination()
        if dest_pos then
            local mag_pos = Entity.GetAbsOrigin(my_hero)
            local skewer_range = GetCurrentSkewerRange()

            local cast_pos = dest_pos
            if ui.cast_range_mode:Get() == 0 then
                local dir = mag_pos:DirectionTo(dest_pos, skewer_range)
                cast_pos = mag_pos + dir
            end
            cast_pos.z = dest_pos.z

            if ui.use_harpoon:Get() then
                local harpoon = NPC.GetItem(my_hero, "item_harpoon")
                if harpoon and Ability.IsCastable(harpoon, NPC.GetMana(my_hero)) then
                    local enemy = FindBestComboEnemy(GetHarpoonRange(harpoon) + 50)
                    if enemy then
                        local edist = mag_pos:Distance2D(Entity.GetAbsOrigin(enemy))
                        if edist > GetSkewerRadius() then
                            CastHarpoonOn(harpoon, enemy)
                        end
                    end
                end
            end

            last_skewer_time = GlobalVars.GetCurTime()
            order.position = cast_pos
            return true
        end
    end

    return true
end

function magnus_skewer_addon.OnGameEnd()
    custom_ground_pos = nil
    locked_target_index = nil
    locked_target_hero = nil
    current_target_hero = nil
    SetBuiltinComboSkewer(true)
end

local function DrawWorldCircle(center, radius, color, segments, thickness)
    segments = segments or 48
    thickness = thickness or 2
    local step = (math.pi * 2) / segments
    local prev_pos, prev_vis
    for i = 0, segments do
        local a = i * step
        local wp = Vector(center.x + math.cos(a) * radius, center.y + math.sin(a) * radius, center.z)
        local sp, vis = Render.WorldToScreen(wp)
        if i > 0 and prev_vis and vis then
            Render.Line(prev_pos, sp, color, thickness)
        end
        prev_pos = sp
        prev_vis = vis
    end
end

local function DrawStatusLines(pos, status_text, dist_text, color)
    local s1 = Render.TextSize(font_main, 14, status_text)
    local s2 = Render.TextSize(font_small, 12, dist_text)
    local p1 = pos - Vec2(s1.x / 2, s1.y + s2.y + 12)
    local p2 = pos - Vec2(s2.x / 2, s2.y + 6)
    Render.Text(font_main, 14, status_text, p1 + Vec2(1, 1), Color(0, 0, 0, 255))
    Render.Text(font_main, 14, status_text, p1, color)
    Render.Text(font_small, 12, dist_text, p2 + Vec2(1, 1), Color(0, 0, 0, 255))
    Render.Text(font_small, 12, dist_text, p2, Color(255, 255, 255, 220))
end

local function RangeTexts(can_reach, in_key, out_key, dist, range)
    local d, r = math.floor(dist), math.floor(range)
    local status_text = localization.Get(can_reach and in_key or out_key)
    local dist_text = can_reach and string.format("%d / %d", d, r)
        or string.format(localization.Get("msa_text_range_need"), d - r, d, r)
    return status_text, dist_text
end

function magnus_skewer_addon.OnDraw()
    if not ui.enabled:Get() or not my_hero or NPC.GetUnitName(my_hero) ~= "npc_dota_hero_magnataur" then
        return
    end

    local dest_pos, dest_type, target_ally = GetTargetDestination()
    if not dest_pos then return end

    local skewer_range = GetCurrentSkewerRange()
    local hovered_enemy = current_hovered_enemy
    local eval_pos = hovered_enemy and Entity.GetAbsOrigin(hovered_enemy) or Entity.GetAbsOrigin(my_hero)
    local dist_to_target = eval_pos:Distance2D(dest_pos)

    local can_reach = dist_to_target <= skewer_range
    local current_color = can_reach and ui.color_reach:Get() or ui.color_cant_reach:Get()

    if dest_type == "ground" then
        if ui.draw_radius:Get() or ui.draw_indicator:Get() then
            DrawWorldCircle(dest_pos, skewer_range, current_color, 48, 2)
        end

        local ground_screen, ground_vis = Render.WorldToScreen(dest_pos)
        if ground_vis then
            if ui.draw_indicator:Get() then
                Render.Circle(ground_screen, 10, current_color, 2)
                Render.FilledCircle(ground_screen, 4, current_color)
                Render.Line(ground_screen - Vec2(14, 0), ground_screen + Vec2(14, 0), current_color, 2)
                Render.Line(ground_screen - Vec2(0, 14), ground_screen + Vec2(0, 14), current_color, 2)

                local status_text, dist_text = RangeTexts(can_reach, "msa_text_point_in", "msa_text_point_out", dist_to_target, skewer_range)
                DrawStatusLines(ground_screen, status_text, dist_text, current_color)
            end

            if ui.draw_line:Get() then
                local start_screen, start_vis = Render.WorldToScreen(eval_pos)
                if start_vis then
                    Render.Line(start_screen, ground_screen, current_color, 2)
                end
            end
        end

        if hovered_enemy and ui.draw_enemy_preview:Get() then
            local enemy_pos = Entity.GetAbsOrigin(hovered_enemy)
            local eh_pos = enemy_pos + Vector(0, 0, NPC.GetHealthBarOffset(hovered_enemy) + 30)
            local eh_screen, eh_vis = Render.WorldToScreen(eh_pos)
            if eh_vis then
                local ptext = localization.Get(can_reach and "msa_text_can_point" or "msa_text_far_point")
                local psub = string.format(localization.Get("msa_text_dist"), math.floor(dist_to_target), math.floor(skewer_range))
                DrawStatusLines(eh_screen, ptext, psub, current_color)
            end
        end
        return
    end

    local ally = target_ally
    if not ally or not Entity.IsAlive(ally) or Entity.IsDormant(ally) then return end

    local ally_screen, ally_vis = Render.WorldToScreen(dest_pos)

    if ui.draw_line:Get() and ally_vis then
        local start_screen, start_vis = Render.WorldToScreen(eval_pos)
        if start_vis then
            Render.Line(start_screen, ally_screen, current_color, 2)
        end
    end

    if ui.draw_indicator:Get() and ally_vis then
        local head_pos = dest_pos + Vector(0, 0, NPC.GetHealthBarOffset(ally) + 30)
        local head_screen, head_vis = Render.WorldToScreen(head_pos)
        if head_vis then
            local status_text, dist_text = RangeTexts(can_reach, "msa_text_skewer_in", "msa_text_skewer_out", dist_to_target, skewer_range)
            DrawStatusLines(head_screen, status_text, dist_text, current_color)
        end
    end

    if hovered_enemy and ui.draw_enemy_preview:Get() then
        local enemy_pos = Entity.GetAbsOrigin(hovered_enemy)
        local eh_pos = enemy_pos + Vector(0, 0, NPC.GetHealthBarOffset(hovered_enemy) + 30)
        local eh_screen, eh_vis = Render.WorldToScreen(eh_pos)
        if eh_vis then
            local ptext = localization.Get(can_reach and "msa_text_can_ally" or "msa_text_far_ally")
            ptext = string.format(ptext, GetHeroDisplayName(ally):upper())
            local psub = string.format(localization.Get("msa_text_dist"), math.floor(dist_to_target), math.floor(skewer_range))
            DrawStatusLines(eh_screen, ptext, psub, current_color)
        end
    end
end

if ai_bridge and ai_bridge.tool then
    ai_bridge.tool(
        "magnus_get_combo_state",
        "Returns active state of combo keys, target ally or ground, and built-in combo settings",
        {},
        function()
            local dest_pos, dest_type, target = GetTargetDestination()
            local cur_time = GlobalVars.GetCurTime()
            local b1, b2 = ui.bind_pick_cursor:Buttons()
            return {
                is_combo_down = IsComboKeyDown(),
                is_space_down = key_state[Enum.ButtonCode.KEY_SPACE] == true,
                combo_hold_time = is_combo_active and (cur_time - combo_press_start) or 0,
                dest_type = dest_type or "none",
                target_ally = target and NPC.GetUnitName(target) or nil,
                ground_pos = custom_ground_pos and { x = custom_ground_pos.x, y = custom_ground_pos.y, z = custom_ground_pos.z } or nil,
                locked_index = locked_target_index,
                builtin_skewer_suppressed = abilities_w and (abilities_w:Get("magnataur_skewer") == false) or false,
                cursor_bind = { b1 = b1, b2 = b2 }
            }
        end
    )

    ai_bridge.tool(
        "magnus_get_skewer_target",
        "Returns current skewer target (ally or ground) and reachability status",
        {},
        function()
            local dest_pos, dest_type, target = GetTargetDestination()
            if not dest_pos then
                return {
                    has_target = false,
                    reason = "No target selected or script disabled",
                    locked_index = locked_target_index,
                    ground_set = custom_ground_pos ~= nil
                }
            end
            local skewer_range = GetCurrentSkewerRange()
            local mag_pos = Entity.GetAbsOrigin(my_hero)
            local dist = mag_pos:Distance2D(dest_pos)
            return {
                has_target = true,
                target_type = dest_type,
                target_name = target and NPC.GetUnitName(target) or "Ground Point",
                position = { x = dest_pos.x, y = dest_pos.y, z = dest_pos.z },
                skewer_range = math.floor(skewer_range),
                has_shard = HasAghanimShard(),
                distance = math.floor(dist),
                can_reach = dist <= skewer_range
            }
        end
    )

    ai_bridge.tool(
        "magnus_set_ground_target",
        "Sets custom ground position as target for Skewer",
        {
            { "x", "number", "World X coordinate" },
            { "y", "number", "World Y coordinate" },
            { "z", "number", "World Z coordinate (optional)" }
        },
        function(args)
            local x = tonumber(args.x) or 0
            local y = tonumber(args.y) or 0
            local z = tonumber(args.z) or (my_hero and Entity.GetAbsOrigin(my_hero).z or 128)
            LockGroundPoint(Vector(x, y, z))
            return { success = true, position = { x = x, y = y, z = z } }
        end
    )

    ai_bridge.tool(
        "magnus_lock_ally_test",
        "Locks ally by index or search string for testing",
        {
            { "target", "string", "Hero index or name" }
        },
        function(args)
            UpdateAllyHeroesList(true)
            local search = tostring(args.target or ""):lower()
            for _, entry in ipairs(ally_cache) do
                if tostring(entry.index) == search or entry.unit_name:lower():find(search) or entry.name:lower():find(search) then
                    LockTarget(entry.hero)
                    return { success = true, locked = entry.name }
                end
            end
            return { success = false, error = "Ally not found" }
        end
    )

    ai_bridge.tool(
        "magnus_inspect_harpoon",
        "Inspects Harpoon status and inventory",
        {},
        function()
            local res = { has_harpoon = false, harpoon_ready = false, harpoon_range = 0, items = {} }
            if my_hero then
                for i = 0, 8 do
                    local it = NPC.GetItemByIndex(my_hero, i)
                    if it then
                        local iname = Ability.GetName(it)
                        local is_ready = Ability.IsReady(it)
                        local is_castable = Ability.IsCastable(it, NPC.GetMana(my_hero))
                        local cr = Ability.GetCastRange(it)
                        res.items[#res.items + 1] = { name = iname, ready = is_ready, castable = is_castable, range = cr }
                        if iname == "item_harpoon" then
                            res.has_harpoon = true
                            res.harpoon_ready = is_castable
                            res.harpoon_range = cr
                        end
                    end
                end
            end
            return res
        end
    )
end

return magnus_skewer_addon
