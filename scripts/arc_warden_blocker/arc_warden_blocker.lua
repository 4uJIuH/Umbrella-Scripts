-- Arc Warden Blocker v1.0.0
-- Author: sataroz (Discord: sataroz)

local VERSION = "1.0.0"

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
        aw_tab_title = "Anti-Hook and Anti-Roll",
        aw_group_g_main = "Main Settings",
        aw_enabled = "Enable Script",
        aw_min_mana = "Minimum Mana %",
        aw_group_g_hook = "Pudge Hook Block",
        aw_hook_block = "Block Hook",
        aw_hook_cast_tempest = "Spawn Clone (Tempest)",
        aw_hook_use_existing_clone = "Move Existing Clone",
        aw_hook_save_allies = "Save Allies",
        aw_hook_priority = "Protection Priority",
        aw_hook_prioritys_item = "Self First",
        aw_hook_prioritys_item_2 = "Ally First",
        aw_hook_draw = "Draw Hook Trajectory",
        aw_group_g_roll = "Earth Spirit Roll Block",
        aw_roll_block = "Block Roll",
        aw_roll_cast_tempest = "Spawn Clone (Tempest)",
        aw_roll_use_existing_clone = "Move Existing Clone",
        aw_roll_mode = "Block Mode",
        aw_roll_modes_item = "Rolling Towards Me",
        aw_roll_modes_item_2 = "Rolling Away (Escape)",
        aw_roll_modes_item_3 = "Always (Towards and Away)",
        aw_roll_draw = "Draw Block Point",
    },
    ru = {
        aw_tab_title = "Анти-Хук и Анти-Ролл",
        aw_group_g_main = "Основное",
        aw_enabled = "Включить скрипт",
        aw_min_mana = "Минимум маны %",
        aw_group_g_hook = "Блок хука Пуджа",
        aw_hook_block = "Блокировать хук",
        aw_hook_cast_tempest = "Призывать клона (Tempest)",
        aw_hook_use_existing_clone = "Двигать живого клона",
        aw_hook_save_allies = "Спасать союзников",
        aw_hook_priority = "Приоритет спасения",
        aw_hook_prioritys_item = "Сначала себя",
        aw_hook_prioritys_item_2 = "Сначала союзника",
        aw_hook_draw = "Рисовать траекторию хука",
        aw_group_g_roll = "Блок переката Земли",
        aw_roll_block = "Блокировать перекат",
        aw_roll_cast_tempest = "Призывать клона (Tempest)",
        aw_roll_use_existing_clone = "Двигать живого клона",
        aw_roll_mode = "Режим блокировки",
        aw_roll_modes_item = "Когда катится НА меня",
        aw_roll_modes_item_2 = "Когда укатывается (ОТ меня)",
        aw_roll_modes_item_3 = "Всегда (и на меня и от меня)",
        aw_roll_draw = "Рисовать точку блока",
    },
})

local Menu = localization.WrapLibrary(Menu)

--[[
    Arc Warden Blocker (Anti-Hook & Anti-Roll)
    Umbrella API v2.0
]]

local arc_blocker = {}

local font_main = Render.LoadFont("Tahoma", Enum.FontCreate.FONTFLAG_OUTLINE, 600)
local font_small = Render.LoadFont("Tahoma", Enum.FontCreate.FONTFLAG_OUTLINE, 400)

local ui = {}
local T_MENU = "\xD0\x90\xD0\xBD\xD1\x82\xD0\xB8-\xD0\xA5\xD1\x83\xD0\xBA \xD0\xB8 \xD0\x90\xD0\xBD\xD1\x82\xD0\xB8-\xD0\xA0\xD0\xBE\xD0\xBB\xD0\xBB"

local g_main = Menu.Create("Heroes", "Hero List", "Arc Warden", T_MENU, "aw_group_g_main")
ui.enabled = g_main:Switch("aw_enabled", true)
ui.min_mana = g_main:Slider("aw_min_mana", 0, 100, 10, "%d%%")

local g_hook = Menu.Create("Heroes", "Hero List", "Arc Warden", T_MENU, "aw_group_g_hook")
ui.hook_block = g_hook:Switch("aw_hook_block", true)
ui.hook_cast_tempest = g_hook:Switch("aw_hook_cast_tempest", true)
ui.hook_use_existing_clone = g_hook:Switch("aw_hook_use_existing_clone", true)
ui.hook_save_allies = g_hook:Switch("aw_hook_save_allies", true)
ui.hook_priority = g_hook:Combo("aw_hook_priority", {"aw_hook_prioritys_item", "aw_hook_prioritys_item_2"}, 0)
ui.hook_draw = g_hook:Switch("aw_hook_draw", true)

local g_roll = Menu.Create("Heroes", "Hero List", "Arc Warden", T_MENU, "aw_group_g_roll")
ui.roll_block = g_roll:Switch("aw_roll_block", true)
ui.roll_cast_tempest = g_roll:Switch("aw_roll_cast_tempest", true)
ui.roll_use_existing_clone = g_roll:Switch("aw_roll_use_existing_clone", true)
ui.roll_mode = g_roll:Combo("aw_roll_mode", {"aw_roll_modes_item", "aw_roll_modes_item_2", "aw_roll_modes_item_3"}, 1)
ui.roll_draw = g_roll:Switch("aw_roll_draw", true)

local my_hero = nil
local tempest_double = nil

local active_hooks = {}
local active_rolls = {}
local pudge_last_cd = {}
local enemy_pos_history = {}

local last_hook_order_time = 0
local last_roll_order_time = 0
local last_order_target_pos = nil

local function IsActiveGameCondition()
    local local_h = Heroes.GetLocal()
    if not local_h or NPC.GetUnitName(local_h) ~= "npc_dota_hero_arc_warden" then
        return false, nil, false, false
    end

    local has_pudge = false
    local has_earth_spirit = false

    for _, h in ipairs(Heroes.GetAll()) do
        if not Entity.IsSameTeam(local_h, h) then
            local uname = NPC.GetUnitName(h)
            if uname == "npc_dota_hero_pudge" then
                has_pudge = true
            elseif uname == "npc_dota_hero_earth_spirit" then
                has_earth_spirit = true
            end
        end
    end

    if not has_pudge and not has_earth_spirit then
        return false, nil, false, false
    end

    return true, local_h, has_pudge, has_earth_spirit
end

local function FindMainArcWarden()
    local is_active, hero = IsActiveGameCondition()
    if is_active and hero and Entity.IsAlive(hero) and not Entity.IsDormant(hero) then
        return hero
    end
    return nil
end

local function GetExistingClone(main_arc)
    if not main_arc then return nil end
    local tempest_ab = NPC.GetAbility(main_arc, "arc_warden_tempest_double")
    if tempest_ab and CustomEntities and CustomEntities.GetTempestDouble then
        local c = CustomEntities.GetTempestDouble(tempest_ab)
        if c and Entity.IsAlive(c) and not Entity.IsDormant(c) then
            return c
        end
    end
    for _, h in ipairs(Heroes.GetAll()) do
        if h ~= main_arc and Entity.IsSameTeam(main_arc, h) and Entity.IsAlive(h) and not Entity.IsDormant(h) then
            if NPC.GetUnitName(h) == "npc_dota_hero_arc_warden" then
                return h
            end
        end
    end
    return nil
end

local function CanCastTempest(hero)
    if not hero or not tempest_double or not Entity.IsAlive(hero) then return false end
    local cur_mana = NPC.GetMana(hero)
    if not Ability.IsCastable(tempest_double, cur_mana) then
        return false
    end
    local max_mana = NPC.GetMaxMana(hero)
    if max_mana > 0 then
        local mana_pct = (cur_mana / max_mana) * 100
        if mana_pct < ui.min_mana:Get() then
            return false
        end
    end
    if NPC.IsStunned(hero) or NPC.IsSilenced(hero) then
        return false
    end
    return true
end

local function CanOrderUnit(unit)
    if not unit or not Entity.IsAlive(unit) or Entity.IsDormant(unit) then return false end
    if NPC.IsStunned(unit) then return false end
    if NPC.HasState(unit, Enum.ModifierState.MODIFIER_STATE_ROOTED) then return false end
    return true
end

local function MoveCloneTo(clone, pos)
    if not clone or not pos then return end
    NPC.MoveTo(clone, pos, false, false, nil, true, "ArcBlockerCloneMove")
    local player = Players.GetLocal()
    if player then
        Player.PrepareUnitOrders(
            player,
            Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION,
            nil,
            pos,
            nil,
            Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
            clone,
            false,
            false,
            nil,
            true
        )
    end
end

local function CastTempestAt(hero, pos)
    if not tempest_double or not hero then return end
    local beh = Ability.GetBehavior(tempest_double) or 0
    -- In Enum.AbilityBehavior: DOTA_ABILITY_BEHAVIOR_POINT = 16, NO_TARGET = 4
    local is_point = (beh % 32) >= 16
    local player = Players.GetLocal()

    if is_point and pos then
        Ability.CastPosition(tempest_double, pos, false, false, true, "ArcBlockerTempest")
        if player then
            Player.PrepareUnitOrders(
                player,
                Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION,
                nil,
                pos,
                tempest_double,
                Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                hero,
                false,
                false,
                nil,
                true
            )
        end
    else
        Ability.CastNoTarget(tempest_double, false, false, true, "ArcBlockerTempest")
        if player then
            Player.PrepareUnitOrders(
                player,
                Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET,
                nil,
                Vector(0, 0, 0),
                tempest_double,
                Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                hero,
                false,
                false,
                nil,
                true
            )
        end
    end
end

local function ClampToCastRange(center, target, cast_range)
    local offset = target - center
    local dist = offset:Length2D()
    if dist <= cast_range then
        return target
    end
    if dist < 0.001 then return center end
    return center + offset:Normalized() * cast_range
end

local function GetClosestPointOnSegment(point, seg_a, seg_b)
    local ab = seg_b - seg_a
    local ab_len2 = ab:Dot(ab)
    if ab_len2 < 1.0 then
        return seg_a, 0
    end
    local ap = point - seg_a
    local t = ap:Dot(ab) / ab_len2
    t = math.max(0.0, math.min(1.0, t))
    return seg_a + ab * t, t
end

local function FindPudge()
    for _, h in ipairs(Heroes.GetAll()) do
        if NPC.GetUnitName(h) == "npc_dota_hero_pudge" and Entity.IsAlive(h) and not Entity.IsDormant(h) then
            return h
        end
    end
    for _, h in ipairs(Heroes.GetAll()) do
        if NPC.GetUnitName(h) == "npc_dota_hero_pudge" then
            return h
        end
    end
    return nil
end

function arc_blocker.OnPrepareUnitOrders(data)
    if not data or not data.ability then return true end
    local is_active = IsActiveGameCondition()
    if not is_active then return true end
    local aname = Ability.GetName(data.ability)
    local cur_time = GameRules.GetGameTime()

    if aname == "pudge_meat_hook" and data.npc then
        local p_pos = Entity.GetAbsOrigin(data.npc)
        local target_pos = data.position or (data.target and Entity.GetAbsOrigin(data.target))
        if p_pos and target_pos then
            local diff = target_pos - p_pos
            if diff:Length2D() > 10 then
                local dir = diff:Normalized()
                local hook_range = Ability.GetCastRange(data.ability) or 1300
                if hook_range < 500 then hook_range = 1300 end
                local p_idx = Entity.GetIndex(data.npc)
                active_hooks[p_idx] = {
                    origin = p_pos,
                    dir = dir,
                    speed = 1450,
                    max_dist = hook_range,
                    created_time = cur_time,
                    expire_time = cur_time + (hook_range / 1450) + 0.4,
                    source_idx = p_idx
                }
            end
        end
    elseif aname == "earth_spirit_rolling_boulder" and data.npc then
        local es_pos = Entity.GetAbsOrigin(data.npc)
        local target_pos = data.position or (data.target and Entity.GetAbsOrigin(data.target))
        if es_pos and target_pos then
            local diff = target_pos - es_pos
            if diff:Length2D() > 10 then
                local dir = diff:Normalized()
                local e_idx = Entity.GetIndex(data.npc)
                active_rolls[e_idx] = {
                    enemy = data.npc,
                    dir = dir,
                    block_pos = es_pos + dir * 300,
                    expire_time = cur_time + 1.2
                }
            end
        end
    end
    return true
end

function arc_blocker.OnLinearProjectileCreate(data)
    if not data then return end
    local name = string.lower(data.fullName or data.name or "")
    local is_hook = string.find(name, "hook") or string.find(name, "meat_hook")

    if not is_hook and data.source then
        if NPC.GetUnitName(data.source) == "npc_dota_hero_pudge" then
            is_hook = true
        end
    end
    if not is_hook then return end

    local pudge = data.source or FindPudge()
    local p_idx = pudge and Entity.GetIndex(pudge) or 1

    local origin = data.origin or (pudge and Entity.GetAbsOrigin(pudge))
    local vel = data.velocity
    local speed = data.maxSpeed or (vel and vel:Length2D()) or 1450
    local dist = data.distance or 1300
    if dist < 400 then dist = 1300 end
    local dir = nil
    if vel and vel:Length2D() > 10 then
        dir = vel:Normalized()
    end

    if not dir and pudge then
        local rot = Entity.GetRotation(pudge)
        if rot then
            local rad = rot:GetYaw() * math.pi / 180
            dir = Vector(math.cos(rad), math.sin(rad), 0)
        end
    end
    origin = origin or Vector(0, 0, 0)
    dir = dir or Vector(1, 0, 0)
    local cur_time = GameRules.GetGameTime()

    active_hooks[p_idx] = {
        origin = origin,
        dir = dir,
        speed = speed,
        max_dist = dist,
        created_time = cur_time,
        expire_time = cur_time + (dist / speed) + 0.3,
        source_idx = p_idx
    }
end

function arc_blocker.OnLinearProjectileDestroy(data)
    if not data then return end
    local pudge = FindPudge()
    if pudge then
        active_hooks[Entity.GetIndex(pudge)] = nil
    end
end

function arc_blocker.OnParticleCreate(data)
    if not data then return end
    local name = string.lower(data.fullName or data.name or "")
    if string.find(name, "hook") then
        local pudge = (data.entity and NPC.GetUnitName(data.entity) == "npc_dota_hero_pudge" and data.entity) or FindPudge()
        local p_idx = pudge and Entity.GetIndex(pudge) or 1
        local origin = (data.entity and Entity.GetAbsOrigin(data.entity)) or (pudge and Entity.GetAbsOrigin(pudge))
        local cur_time = GameRules.GetGameTime()

        if not active_hooks[p_idx] or (cur_time - active_hooks[p_idx].created_time > 0.4) then
            active_hooks[p_idx] = {
                particle_index = data.index,
                origin = origin,
                target_pos = nil,
                speed = 1450,
                max_dist = 1300,
                created_time = cur_time,
                expire_time = cur_time + 1.4,
                source_idx = p_idx
            }
        else
            active_hooks[p_idx].particle_index = data.index
        end
    end
end

function arc_blocker.OnParticleUpdate(data)
    if not data then return end
    for p_idx, hook in pairs(active_hooks) do
        if hook.particle_index == data.index then
            if data.controlPoint == 0 then
                hook.origin = data.position
            elseif data.controlPoint == 1 then
                hook.target_pos = data.position
                if hook.origin and hook.target_pos then
                    local diff = hook.target_pos - hook.origin
                    local len = diff:Length2D()
                    if len > 50 then
                        hook.dir = diff:Normalized()
                        hook.max_dist = math.min(1450, len)
                    end
                end
            end
            break
        end
    end
end

function arc_blocker.OnParticleUpdateFallback(data)
    if not data then return end
    arc_blocker.OnParticleUpdate(data)
end

function arc_blocker.OnParticleDestroy(data)
    if not data then return end
    for p_idx, hook in pairs(active_hooks) do
        if hook.particle_index == data.index then
            active_hooks[p_idx] = nil
            break
        end
    end
end

function arc_blocker.OnModifierCreate(entity, modifier)
    if not entity or not modifier then return end
    if NPC.GetUnitName(entity) == "npc_dota_hero_earth_spirit" then
        local mname = string.lower(Modifier.GetName(modifier) or "")
        if string.find(mname, "rolling_boulder") or string.find(mname, "earth_spirit_roll") then
            local rot = Entity.GetRotation(entity)
            local dir = nil
            if rot then
                local rad = rot:GetYaw() * math.pi / 180
                dir = Vector(math.cos(rad), math.sin(rad), 0)
            end
            local es_pos = Entity.GetAbsOrigin(entity)
            if dir and es_pos then
                local cur_time = GameRules.GetGameTime()
                local e_idx = Entity.GetIndex(entity)
                active_rolls[e_idx] = {
                    enemy = entity,
                    dir = dir,
                    block_pos = es_pos + dir * 300,
                    expire_time = cur_time + 1.2
                }
            end
        end
    end
end

function arc_blocker.OnModifierDestroy(entity, modifier)
    if not entity or not modifier then return end
    if NPC.GetUnitName(entity) == "npc_dota_hero_earth_spirit" then
        local mname = string.lower(Modifier.GetName(modifier) or "")
        if string.find(mname, "rolling_boulder") or string.find(mname, "earth_spirit_roll") then
            local e_idx = Entity.GetIndex(entity)
            active_rolls[e_idx] = nil
        end
    end
end

function arc_blocker.OnUnitAnimation(data)
    if not data or not data.unit then return end
    local uname = NPC.GetUnitName(data.unit)
    local cur_time = GameRules.GetGameTime()

    if uname == "npc_dota_hero_pudge" then
        local seq = string.lower(data.sequenceName or "")
        if string.find(seq, "hook") or string.find(seq, "cast1") then
            local p_idx = Entity.GetIndex(data.unit)
            if not active_hooks[p_idx] or (cur_time - active_hooks[p_idx].created_time > 0.4) then
                local rot = Entity.GetRotation(data.unit)
                if rot then
                    local rad = rot:GetYaw() * math.pi / 180
                    local dir = Vector(math.cos(rad), math.sin(rad), 0)
                    local p_pos = Entity.GetAbsOrigin(data.unit)
                    active_hooks[p_idx] = {
                        origin = p_pos,
                        dir = dir,
                        speed = 1450,
                        max_dist = 1300,
                        created_time = cur_time,
                        expire_time = cur_time + 1.3,
                        source_idx = p_idx
                    }
                end
            end
        end
    elseif uname == "npc_dota_hero_earth_spirit" then
        local seq = string.lower(data.sequenceName or "")
        if string.find(seq, "roll") or string.find(seq, "boulder") then
            local rot = Entity.GetRotation(data.unit)
            if rot then
                local rad = rot:GetYaw() * math.pi / 180
                local dir = Vector(math.cos(rad), math.sin(rad), 0)
                local es_pos = Entity.GetAbsOrigin(data.unit)
                local e_idx = Entity.GetIndex(data.unit)
                active_rolls[e_idx] = {
                    enemy = data.unit,
                    dir = dir,
                    block_pos = es_pos + dir * 300,
                    expire_time = cur_time + 1.2
                }
            end
        end
    end
end

local function CleanStaleTrackers(cur_time)
    for k, hook in pairs(active_hooks) do
        if cur_time > hook.expire_time then
            active_hooks[k] = nil
        end
    end
    for k, roll in pairs(active_rolls) do
        if cur_time > roll.expire_time then
            active_rolls[k] = nil
        end
    end
end

local function TrackProjectilesInUpdate(cur_time)
    if LinearProjectiles and LinearProjectiles.GetAll then
        local projectiles = LinearProjectiles.GetAll()
        if projectiles then
            for _, proj in pairs(projectiles) do
                local src = proj.source
                if src and NPC.GetUnitName(src) == "npc_dota_hero_pudge" then
                    local vel = proj.velocity
                    if vel and vel:Length2D() > 100 then
                        local dir = vel:Normalized()
                        local origin = proj.start_position or proj.position
                        local p_idx = Entity.GetIndex(src)
                        active_hooks[p_idx] = {
                            origin = origin,
                            dir = dir,
                            speed = proj.max_speed or vel:Length2D(),
                            max_dist = proj.max_dist or 1300,
                            created_time = cur_time,
                            expire_time = cur_time + 1.2,
                            source_idx = p_idx
                        }
                    end
                end
            end
        end
    end

    for _, pudge in ipairs(Heroes.GetAll()) do
        if NPC.GetUnitName(pudge) == "npc_dota_hero_pudge" and Entity.IsAlive(pudge) and not Entity.IsDormant(pudge) then
            local hook_ab = NPC.GetAbility(pudge, "pudge_meat_hook")
            if hook_ab then
                local p_idx = Entity.GetIndex(pudge)
                local cd = Ability.GetCooldown(hook_ab) or 0
                local prev_cd = pudge_last_cd[p_idx] or 0
                pudge_last_cd[p_idx] = cd

                local in_phase = Ability.IsInAbilityPhase(hook_ab)
                local just_cast = (prev_cd == 0 and cd > 0) or (cd > prev_cd + 1.0)

                if in_phase or just_cast then
                    if not active_hooks[p_idx] or (cur_time - active_hooks[p_idx].created_time > 0.4) then
                        local p_pos = Entity.GetAbsOrigin(pudge)
                        local rot = Entity.GetRotation(pudge)
                        local dir = nil
                        if rot then
                            local rad = rot:GetYaw() * math.pi / 180
                            dir = Vector(math.cos(rad), math.sin(rad), 0)
                        end
                        if dir and p_pos then
                            local hook_range = Ability.GetCastRange(hook_ab) or 1300
                            if hook_range < 500 then hook_range = 1300 end
                            active_hooks[p_idx] = {
                                origin = p_pos,
                                dir = dir,
                                speed = 1450,
                                max_dist = hook_range,
                                created_time = cur_time,
                                expire_time = cur_time + (hook_range / 1450) + 0.3,
                                source_idx = p_idx
                            }
                        end
                    end
                end
            end
        end
    end
end

local function GetHookCurrentPos(hook, cur_time)
    local elapsed = cur_time - hook.created_time
    if elapsed < 0 then elapsed = 0 end
    local dist = math.min(hook.max_dist, hook.speed * elapsed)
    return hook.origin + hook.dir * dist, dist
end

local function ProcessHookInterceptions(cur_time)
    if not ui.hook_block:Get() then return end
    if not my_hero or not Entity.IsAlive(my_hero) then return end

    local cast_range = Ability.GetCastRange(tempest_double) or 700
    if cast_range < 100 then cast_range = 700 end
    local my_pos = Entity.GetAbsOrigin(my_hero)
    local clone = GetExistingClone(my_hero)
    local can_use_clone = ui.hook_use_existing_clone:Get() and CanOrderUnit(clone)
    local can_cast = ui.hook_cast_tempest:Get() and CanCastTempest(my_hero)

    if not can_use_clone and not can_cast then return end

    local targets = {}
    targets[#targets + 1] = { hero = my_hero, is_me = true, pos = my_pos }

    local local_p = Heroes.GetLocal()
    if local_p and local_p ~= my_hero and Entity.IsAlive(local_p) then
        targets[#targets + 1] = { hero = local_p, is_me = true, pos = Entity.GetAbsOrigin(local_p) }
    end

    if ui.hook_save_allies:Get() then
        for _, ally in ipairs(Heroes.GetAll()) do
            if ally ~= my_hero and ally ~= local_p and Entity.IsSameTeam(my_hero, ally) and Entity.IsAlive(ally) and not Entity.IsDormant(ally) and not NPC.IsIllusion(ally) then
                if clone == nil or ally ~= clone then
                    targets[#targets + 1] = { hero = ally, is_me = false, pos = Entity.GetAbsOrigin(ally) }
                end
            end
        end
    end

    local priority_mode = ui.hook_priority:Get()

    for _, hook in pairs(active_hooks) do
        if hook.origin and hook.dir then
            local current_pos, dist_traveled = GetHookCurrentPos(hook, cur_time)
            local rem_dist = hook.max_dist - dist_traveled
            if rem_dist > 20 then
                local threats = {}

                for _, candidate in ipairs(targets) do
                    local h_pos = candidate.pos
                    local v_to_hero = h_pos - current_pos
                    local t_proj = v_to_hero:Dot(hook.dir)

                    if t_proj > -30 and t_proj <= rem_dist + 50 then
                        local p_closest = current_pos + hook.dir * math.max(0, t_proj)
                        local lateral_dist = (h_pos - p_closest):Length2D()

                        if lateral_dist <= 175 then
                            local time_to_hit = math.max(0, t_proj) / hook.speed
                            local dist_tip = t_proj
                            local lead = math.min(220, math.max(70, dist_tip * 0.45))
                            local intercept_pos = p_closest - hook.dir * lead

                            local can_intercept = false
                            local intercept_type = nil
                            local spawn_point = nil

                            if can_use_clone then
                                local clone_pos = Entity.GetAbsOrigin(clone)
                                local clone_speed = NPC.GetMoveSpeed(clone)
                                local dist_to_intercept = (intercept_pos - clone_pos):Length2D()
                                local time_to_reach = dist_to_intercept / math.max(1, clone_speed)
                                if time_to_reach <= time_to_hit + 0.35 then
                                    can_intercept = true
                                    intercept_type = "clone"
                                end
                            end

                            if not can_intercept and can_cast then
                                local dist_me = (intercept_pos - my_pos):Length2D()
                                if dist_me <= cast_range then
                                    can_intercept = true
                                    intercept_type = "cast"
                                    spawn_point = intercept_pos
                                else
                                    local pt_on_ray = GetClosestPointOnSegment(my_pos, current_pos, p_closest)
                                    if (pt_on_ray - my_pos):Length2D() <= cast_range and (pt_on_ray - current_pos):Length2D() >= 50 then
                                        can_intercept = true
                                        intercept_type = "cast"
                                        spawn_point = pt_on_ray
                                    end
                                end
                            end

                            if can_intercept then
                                threats[#threats + 1] = {
                                    candidate = candidate,
                                    time_to_hit = time_to_hit,
                                    impact_pos = p_closest,
                                    hero_pos = h_pos,
                                    dist_from_tip = t_proj,
                                    intercept_pos = intercept_pos,
                                    intercept_type = intercept_type,
                                    spawn_point = spawn_point
                                }
                            end
                        end
                    end
                end

                if #threats > 0 then
                    table.sort(threats, function(a, b)
                        if priority_mode == 0 then
                            if a.candidate.is_me ~= b.candidate.is_me then
                                return a.candidate.is_me
                            end
                        else
                            if a.candidate.is_me ~= b.candidate.is_me then
                                return not a.candidate.is_me
                            end
                        end
                        return a.time_to_hit < b.time_to_hit
                    end)

                    local best_threat = threats[1]

                    if cur_time - last_hook_order_time > 0.08 or (last_order_target_pos and (best_threat.intercept_pos - last_order_target_pos):Length2D() > 50) then
                        if best_threat.intercept_type == "clone" then
                            MoveCloneTo(clone, best_threat.intercept_pos)
                            last_hook_order_time = cur_time
                            last_order_target_pos = best_threat.intercept_pos
                        elseif best_threat.intercept_type == "cast" and best_threat.spawn_point then
                            CastTempestAt(my_hero, best_threat.spawn_point)
                            last_hook_order_time = cur_time
                            last_order_target_pos = best_threat.spawn_point
                        end
                    end
                end
            end
        end
    end
end

local function IsEarthSpiritRolling(enemy, cur_time)
    if not enemy or not Entity.IsAlive(enemy) or Entity.IsDormant(enemy) then return false, nil, 0 end

    local e_idx = Entity.GetIndex(enemy)
    local cur_pos = Entity.GetAbsOrigin(enemy)
    local dir = nil
    local speed = 0

    local hist = enemy_pos_history[e_idx]
    if hist and cur_pos then
        local dt = cur_time - hist.time
        if dt > 0.005 and dt < 0.5 then
            local delta = cur_pos - hist.pos
            speed = delta:Length2D() / dt
            if speed > 200 then
                dir = delta:Normalized()
            end
        end
    end
    if cur_pos then
        enemy_pos_history[e_idx] = { pos = cur_pos, time = cur_time }
    end

    local rot = Entity.GetRotation(enemy)
    if not dir and rot then
        local rad = rot:GetYaw() * math.pi / 180
        dir = Vector(math.cos(rad), math.sin(rad), 0)
    end

    local roll_ab = NPC.GetAbility(enemy, "earth_spirit_rolling_boulder")
    local is_charging = roll_ab and Ability.IsInAbilityPhase(roll_ab)

    local has_mod = false
    for _, mod in ipairs(NPC.GetModifiers(enemy)) do
        local mname = string.lower(Modifier.GetName(mod) or "")
        if string.find(mname, "rolling_boulder") or string.find(mname, "earth_spirit_roll") then
            has_mod = true
            break
        end
    end

    local is_speed_rolling = (speed > 450) and (roll_ab and (Ability.GetCooldown(roll_ab) or 0) > 0)

    if not has_mod and not is_charging and not is_speed_rolling then
        return false, nil, 0
    end

    return true, dir, math.max(800, speed)
end

local function ProcessEarthSpiritRolls(cur_time)
    if not ui.roll_block:Get() then return end
    if not my_hero or not Entity.IsAlive(my_hero) then return end

    local cast_range = Ability.GetCastRange(tempest_double) or 700
    if cast_range < 100 then cast_range = 700 end
    local my_pos = Entity.GetAbsOrigin(my_hero)
    local clone = GetExistingClone(my_hero)
    local can_use_clone = ui.roll_use_existing_clone:Get() and CanOrderUnit(clone)
    local can_cast = ui.roll_cast_tempest:Get() and CanCastTempest(my_hero)

    if not can_use_clone and not can_cast then return end

    local mode = ui.roll_mode:Get()

    for _, enemy in ipairs(Heroes.GetAll()) do
        if enemy and not Entity.IsSameTeam(my_hero, enemy) and Entity.IsAlive(enemy) and not Entity.IsDormant(enemy) then
            if NPC.GetUnitName(enemy) == "npc_dota_hero_earth_spirit" then
                local is_rolling, dir, roll_speed = IsEarthSpiritRolling(enemy, cur_time)
                local e_idx = Entity.GetIndex(enemy)

                if is_rolling and dir then
                    local es_pos = Entity.GetAbsOrigin(enemy)
                    local to_me = my_pos - es_pos
                    local dist_to_me = to_me:Length2D()

                    local is_towards_me = false
                    local t_proj_me = to_me:Dot(dir)
                    if t_proj_me > 0 and t_proj_me <= 1600 then
                        local closest_pt_me = es_pos + dir * t_proj_me
                        if (my_pos - closest_pt_me):Length2D() <= 220 then
                            is_towards_me = true
                        end
                    end

                    local is_towards_clone = false
                    if clone and Entity.IsAlive(clone) then
                        local clone_pos = Entity.GetAbsOrigin(clone)
                        local to_clone = clone_pos - es_pos
                        local t_proj_c = to_clone:Dot(dir)
                        if t_proj_c > 0 and t_proj_c <= 1600 then
                            local closest_pt_c = es_pos + dir * t_proj_c
                            if (clone_pos - closest_pt_c):Length2D() <= 220 then
                                is_towards_clone = true
                            end
                        end
                    end

                    local is_away_from_me = false
                    if dist_to_me <= 1100 then
                        local to_me_norm = dist_to_me > 1 and (to_me / dist_to_me) or dir
                        if dir:Dot(to_me_norm) < -0.2 then
                            is_away_from_me = true
                        end
                    end

                    local trigger = false
                    if mode == 0 then
                        trigger = is_towards_me or is_towards_clone
                    elseif mode == 1 then
                        trigger = is_away_from_me
                    else
                        trigger = is_towards_me or is_towards_clone or is_away_from_me or (dist_to_me <= (cast_range + 250))
                    end

                    if trigger then
                        local lead = math.min(360, math.max(160, roll_speed * 0.18 + 40))
                        local block_pos = es_pos + dir * lead

                        active_rolls[e_idx] = {
                            block_pos = block_pos,
                            dir = dir,
                            expire_time = cur_time + 0.35
                        }

                        if cur_time - last_roll_order_time > 0.10 or (last_order_target_pos and (block_pos - last_order_target_pos):Length2D() > 50) then
                            local handled = false

                            if can_use_clone then
                                local clone_pos = Entity.GetAbsOrigin(clone)
                                local dist_clone = (block_pos - clone_pos):Length2D()
                                local clone_speed = NPC.GetMoveSpeed(clone)
                                local time_to_block = lead / math.max(1, roll_speed)
                                if (dist_clone / math.max(1, clone_speed)) <= (time_to_block + 0.15) then
                                    MoveCloneTo(clone, block_pos)
                                    last_roll_order_time = cur_time
                                    last_order_target_pos = block_pos
                                    handled = true
                                end
                            end

                            if not handled and can_cast then
                                local dist_to_block = (block_pos - my_pos):Length2D()
                                if dist_to_block <= (cast_range + 25) then
                                    local spawn_pos = ClampToCastRange(my_pos, block_pos, cast_range)
                                    CastTempestAt(my_hero, spawn_pos)
                                    last_roll_order_time = cur_time
                                    last_order_target_pos = spawn_pos
                                    handled = true
                                end
                            end
                        end
                    else
                        active_rolls[e_idx] = nil
                    end
                else
                    active_rolls[e_idx] = nil
                end
            end
        end
    end
end

function arc_blocker.OnUpdate()
    if not ui.enabled:Get() then return end

    local is_active, hero, has_pudge, has_es = IsActiveGameCondition()
    if not is_active or not hero or not Entity.IsAlive(hero) then
        my_hero = nil
        return
    end

    my_hero = hero
    tempest_double = NPC.GetAbility(my_hero, "arc_warden_tempest_double")
    if not tempest_double then return end

    local cur_time = GameRules.GetGameTime()

    CleanStaleTrackers(cur_time)
    if has_pudge then
        TrackProjectilesInUpdate(cur_time)
        ProcessHookInterceptions(cur_time)
    end
    if has_es then
        ProcessEarthSpiritRolls(cur_time)
    end
end

function arc_blocker.OnDraw()
    if not ui.enabled:Get() then return end
    if not my_hero or not Entity.IsAlive(my_hero) then return end

    if ui.hook_draw:Get() then
        local cur_time = GameRules.GetGameTime()
        for _, hook in pairs(active_hooks) do
            if hook.origin and hook.dir then
                local cur_p = GetHookCurrentPos(hook, cur_time)
                local end_p = hook.origin + hook.dir * hook.max_dist
                local s_cur, v_cur = Render.WorldToScreen(cur_p)
                local s_end, v_end = Render.WorldToScreen(end_p)
                if v_cur and v_end then
                    Render.Line(s_cur, s_end, Color(255, 80, 80, 200), 2)
                    Render.Circle(s_cur, 8, Color(255, 220, 50, 255), 2)
                end
            end
        end
    end

    if ui.roll_draw:Get() then
        for _, roll in pairs(active_rolls) do
            if roll.block_pos and roll.dir then
                local s_pos, vis = Render.WorldToScreen(roll.block_pos)
                if vis then
                    Render.Circle(s_pos, 14, Color(255, 140, 0, 220), 2)
                end
            end
        end
    end
end

if ai_bridge and ai_bridge.tool then
    ai_bridge.tool(
        "arc_blocker_get_status",
        "Returns Arc Warden blocker status, clone state, and tracked threats",
        {},
        function()
            local arc = FindMainArcWarden()
            local clone = GetExistingClone(arc)
            local ult_castable = CanCastTempest(arc)
            local hook_cnt = 0
            for _ in pairs(active_hooks) do hook_cnt = hook_cnt + 1 end
            local roll_cnt = 0
            for _ in pairs(active_rolls) do roll_cnt = roll_cnt + 1 end

            local beh = 0
            local ab_level = 0
            if arc and tempest_double then
                beh = Ability.GetBehavior(tempest_double) or 0
                ab_level = Ability.GetLevel(tempest_double) or 0
            end

            local is_active, _, has_pudge, has_es = IsActiveGameCondition()
            return {
                is_active = is_active,
                enemy_has_pudge = has_pudge,
                enemy_has_earth_spirit = has_es,
                arc_found = arc ~= nil,
                arc_index = arc and Entity.GetIndex(arc) or 0,
                arc_alive = arc and Entity.IsAlive(arc) or false,
                local_hero = Heroes.GetLocal() and NPC.GetUnitName(Heroes.GetLocal()) or "none",
                enabled = ui.enabled:Get(),
                hook_block = ui.hook_block:Get(),
                roll_block = ui.roll_block:Get(),
                clone_alive = clone ~= nil,
                tempest_ready = ult_castable,
                tempest_level = ab_level,
                tempest_behavior = beh,
                tracked_hooks = hook_cnt,
                tracked_rolls = roll_cnt,
                save_allies = ui.hook_save_allies:Get(),
                roll_mode = ui.roll_mode:Get()
            }
        end
    )
end

return arc_blocker
