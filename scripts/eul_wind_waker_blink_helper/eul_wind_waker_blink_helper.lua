---@diagnostic disable: undefined-global

-- Eul / Wind Waker Blink Helper for Umbrella / UCZone.
-- Standalone helper. Does not use or depend on server-side Phase Shift helpers.

local script = {}

local SCRIPT_NAME = "[Eul Blink] "
local BLINK_FALLBACK_RANGE = 1200
local DRAW_CONE_SEGMENTS = 16
local EUL_FALLBACK_DURATION = 2.5
local MAX_CYCLONE_MODIFIER_REMAINING = 8.0
local DRAW_Z_OFFSET = 24
local MENU_TITLE = "Помощник Blink после Eul / Wind Waker"
local MENU_ICON = "\u{f1d8}"

local CYCLONE_MODIFIERS = {
    "modifier_eul_cyclone",
    "modifier_wind_waker",
}

local BLINK_ITEMS = {
    "item_blink",
    "item_arcane_blink",
    "item_swift_blink",
    "item_overwhelming_blink",
}

local BLINK_ITEM_LABELS = {
    item_blink = "Blink Dagger",
    item_arcane_blink = "Arcane Blink",
    item_swift_blink = "Swift Blink",
    item_overwhelming_blink = "Overwhelming Blink",
}

local function localized_blink_name(item_name)
    return BLINK_ITEM_LABELS[item_name] or item_name or "неизвестен"
end

local function make_menu_group()
    local ok, tab = pcall(Menu.Create, "General", "Main", MENU_TITLE)
    if not ok or not tab then
        error("Не удалось создать меню: " .. MENU_TITLE)
    end

    if type(tab.Switch) == "function" then
        return tab, tab
    end

    if type(tab.Create) == "function" then
        local ok_settings, settings = pcall(function()
            return tab:Create("Настройки")
        end)
        if ok_settings and settings then
            if type(settings.Switch) == "function" then
                return tab, settings
            end

            local ok_group, group = pcall(function()
                return settings:Create("Общее")
            end)
            if ok_group and group and type(group.Switch) == "function" then
                return tab, group
            end
        end
    end

    error("Не удалось создать группу меню: " .. MENU_TITLE)
end

local MENU_TAB, MENU = make_menu_group()
if MENU_TAB and type(MENU_TAB.Icon) == "function" then
    pcall(MENU_TAB.Icon, MENU_TAB, MENU_ICON)
end

local function make_color(r, g, b, a)
    if Color then
        local ok, c = pcall(Color, r, g, b, a or 255)
        if ok and c then return c end
    end

    return { r = r, g = g, b = b, a = a or 255 }
end

local DEFAULT_CONE_COLOR = make_color(90, 220, 255, 230)
local DEFAULT_VALID_COLOR = make_color(80, 255, 140, 255)
local DEFAULT_INVALID_COLOR = make_color(255, 80, 80, 255)

local function boot_log(msg)
    print(SCRIPT_NAME .. msg)
    if Engine and Engine.ConsoleColorPrintf then
        pcall(Engine.ConsoleColorPrintf, 120, 210, 255, 255, SCRIPT_NAME .. msg .. "\n")
    end
end

local function dummy_widget(default_value)
    return {
        __dummy = true,
        __value = default_value,
        Get = function(self) return self.__value end,
        IsDown = function() return false end,
        IsPressed = function() return false end,
        IsToggled = function() return false end,
        ForceLocalization = function(self, new_text)
            self.__value = new_text
        end,
        ToolTip = function() return "" end,
        Visible = function() return true end,
        Disabled = function() return false end,
    }
end

local unpack_args = table.unpack or unpack

local function create_menu_widget(kind, name, fallback_value, ...)
    if not MENU or type(MENU[kind]) ~= "function" then
        boot_log(string.format("menu widget missing: %s '%s'", kind, name))
        return dummy_widget(fallback_value)
    end

    local args = { ... }
    local ok, widget = pcall(function()
        return MENU[kind](MENU, name, unpack_args(args))
    end)

    if ok and widget then
        return widget
    end

    boot_log(string.format("menu widget failed: %s '%s': %s", kind, name, tostring(widget)))
    return dummy_widget(fallback_value)
end

local function create_switch(name, default_value, image_icon)
    return create_menu_widget("Switch", name, default_value, default_value, image_icon)
end

local function create_slider(name, min_value, max_value, default_value, format)
    return create_menu_widget("Slider", name, default_value, min_value, max_value, default_value, format)
end

local function create_color_picker(name, default_value)
    return create_menu_widget("ColorPicker", name, default_value, default_value)
end

local function create_label(text)
    return create_menu_widget("Label", text, text)
end

local ui = {}
ui.enabled = create_switch("Включить помощник Eul / Wind Waker", true)

ui.show_cone = create_switch("Показывать конус мгновенного Blink", true)
ui.show_cursor = create_switch("Показывать линию курсора", true)
ui.show_time = create_switch("Показывать оставшееся время", true)
ui.show_debug_overlay = create_switch("Показывать отладочную панель", false)

ui.instant_half_angle = create_slider("Полуугол мгновенного конуса", 5.0, 60.0, 45.0, "%.1f°")

ui.cone_color = create_color_picker("Цвет мгновенного конуса", DEFAULT_CONE_COLOR)
ui.valid_color = create_color_picker("Цвет доступного курсора", DEFAULT_VALID_COLOR)
ui.invalid_color = create_color_picker("Цвет недоступного курсора", DEFAULT_INVALID_COLOR)
ui.thickness = create_slider("Толщина линии", 1.0, 6.0, 2.0, "%.1f")

ui.status = create_label("Статус: ожидание")

local state = {
    hero = nil,
    pending_cyclone = nil,
    cyclone = nil,
    last_pre_cyclone = nil,
    last_status_at = 0,
    last_panorama_at = 0,
    overlay_visible = false,
}

local function safe(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if ok then return a, b, c end
    return nil
end

local function game_time()
    local t = safe(GameRules and GameRules.GetGameTime)
    if type(t) == "number" then return t end
    return os.clock()
end

local function widget_get(widget, fallback)
    if widget and widget.Get then
        local value = safe(widget.Get, widget)
        if value ~= nil then return value end
    end
    return fallback
end

local function set_status(text)
    local t = game_time()
    if t - state.last_status_at < 0.25 then return end
    state.last_status_at = t

    if ui.status and ui.status.ForceLocalization then
        safe(function() ui.status:ForceLocalization("Статус: " .. tostring(text)) end)
    end
end

local function local_hero()
    if not state.hero then state.hero = safe(Heroes.GetLocal) end
    if not state.hero then return nil end

    if Entity and Entity.IsAlive then
        local alive = safe(Entity.IsAlive, state.hero)
        if alive == false then return nil end
    end

    return state.hero
end

local function position_of(entity)
    return safe(Entity and Entity.GetAbsOrigin, entity)
end

local function cursor_position()
    return safe(Humanizer and Humanizer.GetServerCursorPos)
end

local function length2d(x, y)
    return math.sqrt(x * x + y * y)
end

local function atan2(y, x)
    if math.atan2 then return math.atan2(y, x) end
    if x > 0 then return math.atan(y / x) end
    if x < 0 and y >= 0 then return math.atan(y / x) + math.pi end
    if x < 0 and y < 0 then return math.atan(y / x) - math.pi end
    if x == 0 and y > 0 then return math.pi / 2 end
    if x == 0 and y < 0 then return -math.pi / 2 end
    return 0
end

local function vector_components(vec)
    if not vec then return nil, nil, nil end

    local x, y, z
    if type(vec.Get) == "function" then
        x, y, z = safe(vec.Get, vec)
    end

    if type(vec.x) == "number" then x = vec.x end
    if type(vec.y) == "number" then y = vec.y end
    if type(vec.z) == "number" then z = vec.z end

    if type(vec.GetX) == "function" then
        local value = safe(vec.GetX, vec)
        if type(value) == "number" then x = value end
    end

    if type(vec.GetY) == "function" then
        local value = safe(vec.GetY, vec)
        if type(value) == "number" then y = value end
    end

    if type(vec.GetZ) == "function" then
        local value = safe(vec.GetZ, vec)
        if type(value) == "number" then z = value end
    end

    return x, y, z
end

local function vec_x(vec, fallback)
    local x = vector_components(vec)
    if type(x) == "number" then return x end
    return fallback or 0
end

local function vec_y(vec, fallback)
    local _, y = vector_components(vec)
    if type(y) == "number" then return y end
    return fallback or 0
end

local function vec_z(vec, fallback)
    local _, _, z = vector_components(vec)
    if type(z) == "number" then return z end
    return fallback or 0
end

local function normalize2d(x, y)
    local len = length2d(x, y)
    if len <= 0.001 then return nil end
    return { x = x / len, y = y / len, z = 0, length = len }
end

local function direction_between(from, to)
    if not from or not to then return nil end
    return normalize2d(vec_x(to) - vec_x(from), vec_y(to) - vec_y(from))
end

local function point_at(origin, direction, distance)
    return Vector(vec_x(origin) + direction.x * distance, vec_y(origin) + direction.y * distance, vec_z(origin))
end

local function yaw_to_direction(yaw_degrees)
    local r = math.rad(yaw_degrees)
    return { x = math.cos(r), y = math.sin(r), z = 0 }
end

local function direction_yaw(direction)
    return math.deg(atan2(direction.y, direction.x))
end

local function rotate_direction(direction, degrees)
    local r = math.rad(degrees)
    local c, s = math.cos(r), math.sin(r)
    return {
        x = direction.x * c - direction.y * s,
        y = direction.x * s + direction.y * c,
        z = 0,
    }
end

local function copy_direction(direction)
    if not direction then return nil end
    local normalized = normalize2d(vec_x(direction), vec_y(direction))
    if normalized then return normalized end
    return nil
end

local function copy_vector(pos)
    if not pos then return nil end
    local x, y, z = vector_components(pos)
    x, y, z = x or 0, y or 0, z or 0
    if Vector then
        local ok, vec = pcall(Vector, x, y, z)
        if ok and vec then return vec end
    end
    return { x = x, y = y, z = z }
end

local function read_z(pos, fallback)
    if not pos then return fallback end

    local z = vec_z(pos, nil)
    if type(z) == "number" then return z end
    return fallback or 0
end

local function write_z(pos, z)
    if not pos then return nil end

    if type(pos.SetZ) == "function" then
        safe(pos.SetZ, pos, z)
    else
        pos.z = z
    end

    return pos
end

local function ground_draw_position(pos, fallback_ground_z)
    if not pos then return nil, fallback_ground_z end

    local base_z = fallback_ground_z
    if type(base_z) ~= "number" then
        base_z = read_z(pos, 0)
    end

    local grounded = copy_vector({ x = vec_x(pos), y = vec_y(pos), z = base_z })
    if not grounded then return nil, fallback_ground_z end

    if type(grounded.SetGroundZ) == "function" then
        safe(grounded.SetGroundZ, grounded)
    end

    local ground_z = read_z(grounded, base_z)
    write_z(grounded, ground_z + DRAW_Z_OFFSET)
    return grounded, ground_z
end

local function hero_forward(hero)
    local rotation = safe(Entity and Entity.GetRotation, hero)

    local origin = position_of(hero)
    if origin and rotation and type(origin.MoveForward) == "function" then
        local moved = safe(origin.MoveForward, origin, rotation, 100)
        local direction = direction_between(origin, moved)
        if direction then return direction end
    end

    if rotation and type(rotation.GetForward) == "function" then
        local forward = safe(rotation.GetForward, rotation)
        if forward then
            local normalized = normalize2d(vec_x(forward), vec_y(forward))
            if normalized then return normalized end
        end
    end

    if rotation then
        local yaw = nil
        if type(rotation.GetYaw) == "function" then
            yaw = safe(rotation.GetYaw, rotation)
        end
        if type(yaw) ~= "number" and type(rotation.yaw) == "number" then
            yaw = rotation.yaw
        end
        if type(yaw) == "number" then
            return yaw_to_direction(yaw)
        end
    end

    local forward = safe(NPC and NPC.GetForwardVector, hero)
    if forward then
        local normalized = normalize2d(vec_x(forward), vec_y(forward))
        if normalized then return normalized end
    end

    return nil
end

local function angle_between(a, b)
    if not a or not b then return 180 end
    local dot = vec_x(a) * vec_x(b) + vec_y(a) * vec_y(b)
    if dot > 1 then dot = 1 end
    if dot < -1 then dot = -1 end
    return math.deg(math.acos(dot))
end

local function ability_name(ability)
    local name = safe(Ability and Ability.GetName, ability)
    if type(name) == "string" then return name end

    name = safe(Ability and Ability.GetBaseName, ability)
    if type(name) == "string" then return name end

    return nil
end

local function eul_item_type_from_name(item_name)
    if item_name == "item_wind_waker" then return "Wind Waker" end
    if item_name == "item_cyclone" then return "Eul" end
    return nil
end

local function eul_item_info(item)
    local item_name = ability_name(item)
    local item_type = eul_item_type_from_name(item_name)
    return item_type, item_name
end

local function cyclone_item_type_from_modifier(modifier_name)
    if modifier_name == "modifier_wind_waker" then
        return "Wind Waker"
    end

    if modifier_name == "modifier_eul_cyclone" then
        return "Eul"
    end

    return nil
end

local function is_wind_waker_type(item_type)
    return item_type == "Wind Waker"
end

local function get_item(hero, names)
    for _, item_name in ipairs(names) do
        local item = safe(NPC and NPC.GetItem, hero, item_name, true)
        if item then return item, item_name end
    end
    return nil, nil
end

local function modifier_finite_remaining(modifier)
    local now = game_time()

    local die_time = safe(Modifier and Modifier.GetDieTime, modifier)
    if type(die_time) == "number" then
        local remaining = die_time - now
        if remaining > 0 and remaining <= MAX_CYCLONE_MODIFIER_REMAINING then
            return remaining, "modifier die time"
        end
    end

    local duration = safe(Modifier and Modifier.GetDuration, modifier)
    local creation_time = safe(Modifier and Modifier.GetCreationTime, modifier)
    if type(duration) == "number" and duration > 0 and duration <= MAX_CYCLONE_MODIFIER_REMAINING and type(creation_time) == "number" and creation_time > 0 then
        local remaining = creation_time + duration - now
        if remaining > 0 and remaining <= MAX_CYCLONE_MODIFIER_REMAINING then
            return remaining, "modifier duration"
        end
    end

    return nil, nil
end

local function has_recent_pending_cyclone()
    return state.pending_cyclone and game_time() - state.pending_cyclone.time <= 0.35
end

local function get_cyclone_modifier(hero)
    for _, modifier_name in ipairs(CYCLONE_MODIFIERS) do
        local modifier = safe(NPC and NPC.GetModifier, hero, modifier_name)
        if modifier then
            local remaining = modifier_finite_remaining(modifier)
            if remaining or has_recent_pending_cyclone() then
                return modifier, modifier_name
            end
        end
    end

    return nil, nil
end

local function capture_pre_cyclone(hero, item, item_name, item_type, reason)
    local forward = hero_forward(hero)
    local landing, ground_z = ground_draw_position(position_of(hero))
    if not forward then return false end

    item_name = item_name or ability_name(item)
    item_type = item_type or eul_item_type_from_name(item_name)

    state.cyclone = nil
    state.pending_cyclone = {
        time = game_time(),
        landing = landing,
        ground_z = ground_z,
        pre_forward = copy_direction(forward),
        pre_angle = direction_yaw(forward),
        item = item,
        item_name = item_name,
        item_type = item_type,
        reason = reason,
    }

    return true
end

local function refresh_last_pre_cyclone(hero)
    local forward = hero_forward(hero)
    if not forward then return end
    local landing, ground_z = ground_draw_position(position_of(hero))

    state.last_pre_cyclone = {
        time = game_time(),
        landing = landing,
        ground_z = ground_z,
        pre_forward = copy_direction(forward),
        pre_angle = direction_yaw(forward),
    }
end

local function modifier_creation_time(modifier)
    local creation_time = safe(Modifier and Modifier.GetCreationTime, modifier)
    if type(creation_time) == "number" and creation_time > 0 then
        return creation_time
    end
    return nil
end

local function modifier_index(modifier)
    local index = safe(Modifier and Modifier.GetIndex, modifier)
    if type(index) == "number" and index > 0 then
        return index
    end
    return nil
end

local function cyclone_remaining_from_modifier(modifier, cyclone)
    local remaining, source = modifier_finite_remaining(modifier)
    if remaining then
        return remaining, source
    end

    if not cyclone.allow_fallback_remaining then
        return 0, "invalid modifier timing"
    end

    local now = game_time()
    local fallback_duration = cyclone.fallback_duration or EUL_FALLBACK_DURATION
    local start_time = cyclone.start_time or now
    return math.max(0, fallback_duration - (now - start_time)), "fallback"
end

local function begin_cyclone_state(hero, modifier, modifier_name)
    local now = game_time()
    local pending = state.pending_cyclone
    if pending and now - pending.time > 3.5 then
        pending = nil
        state.pending_cyclone = nil
    end

    local last_pre = state.last_pre_cyclone
    local current_pos, current_ground_z = ground_draw_position(position_of(hero), pending and pending.ground_z or last_pre and last_pre.ground_z)
    local forward = pending and pending.pre_forward or last_pre and last_pre.pre_forward or hero_forward(hero)
    if not forward then return nil end

    local item_type = pending and pending.item_type or cyclone_item_type_from_modifier(modifier_name) or "Eul"
    local creation_time = modifier_creation_time(modifier)
    local start_time = creation_time or pending and pending.time or now
    local landing = pending and pending.landing or last_pre and last_pre.landing or current_pos
    local ground_z = pending and pending.ground_z or last_pre and last_pre.ground_z or current_ground_z

    state.cyclone = {
        active = true,
        start_time = start_time,
        modifier_creation_time = creation_time,
        modifier_index = modifier_index(modifier),
        landing = copy_vector(landing),
        ground_z = ground_z,
        pre_forward = copy_direction(forward),
        pre_angle = direction_yaw(forward),
        item_name = pending and pending.item_name or nil,
        item_type = item_type,
        modifier_name = modifier_name,
        modifier = modifier,
        allow_fallback_remaining = pending ~= nil,
        fallback_duration = EUL_FALLBACK_DURATION,
        remaining = EUL_FALLBACK_DURATION,
        remaining_source = "fallback",
    }

    state.pending_cyclone = nil
    return state.cyclone
end

local function is_new_cyclone_modifier(cyclone, modifier, modifier_name)
    if not cyclone then return true end
    if cyclone.modifier_name and modifier_name and cyclone.modifier_name ~= modifier_name then return true end

    local creation_time = modifier_creation_time(modifier)
    if type(creation_time) == "number" then
        if type(cyclone.modifier_creation_time) == "number" then
            if math.abs(creation_time - cyclone.modifier_creation_time) > 0.01 then return true end
        elseif type(cyclone.start_time) == "number" and creation_time > cyclone.start_time + 0.05 then
            return true
        end
    end

    local index = modifier_index(modifier)
    if index and cyclone.modifier_index and index ~= cyclone.modifier_index then return true end

    local pending = state.pending_cyclone
    if pending and type(cyclone.start_time) == "number" and pending.time > cyclone.start_time + 0.1 then
        return true
    end

    return false
end

local function update_cyclone_state(hero)
    local modifier, modifier_name = get_cyclone_modifier(hero)
    if not modifier then
        if state.cyclone then
            state.cyclone = nil
        end

        refresh_last_pre_cyclone(hero)

        if state.pending_cyclone and game_time() - state.pending_cyclone.time > 3.5 then
            state.pending_cyclone = nil
        end

        return nil
    end

    if is_new_cyclone_modifier(state.cyclone, modifier, modifier_name) then
        state.cyclone = nil
    end

    local cyclone = state.cyclone or begin_cyclone_state(hero, modifier, modifier_name)
    if not cyclone then return nil end

    cyclone.modifier = modifier
    cyclone.modifier_name = modifier_name
    cyclone.item_type = cyclone.item_type or cyclone_item_type_from_modifier(modifier_name) or "Eul"

    if is_wind_waker_type(cyclone.item_type) then
        local current_pos, ground_z = ground_draw_position(position_of(hero), cyclone.ground_z)
        if current_pos then
            cyclone.landing = current_pos
            cyclone.ground_z = ground_z
        end
    end

    cyclone.remaining, cyclone.remaining_source = cyclone_remaining_from_modifier(modifier, cyclone)
    if cyclone.remaining <= 0 then
        state.cyclone = nil
        return nil
    end

    return cyclone
end

local function blink_range(hero, blink)
    local fallback_range = BLINK_FALLBACK_RANGE
    if not blink then return fallback_range end

    local range = safe(Ability and Ability.GetCastRange, blink)
    if type(range) ~= "number" or range <= 0 then
        range = safe(Ability and Ability.GetLevelSpecialValueFor, blink, "blink_range", -1)
    end

    if type(range) ~= "number" or range <= 0 then
        range = safe(Ability and Ability.GetLevelSpecialValueFor, blink, "blink_range")
    end

    if type(range) ~= "number" or range <= 0 then
        range = fallback_range
    end

    local bonus = safe(NPC and NPC.GetCastRangeBonus, hero)
    if type(bonus) == "number" then
        range = range + bonus
    end

    return range > 0 and range or fallback_range
end

local function color_from(widget, fallback)
    return widget_get(widget, fallback)
end

local function project_world(pos)
    if not pos then return nil end

    if Render and Render.WorldToScreen then
        local screen, visible = safe(Render.WorldToScreen, pos)
        local sx, sy = vector_components(screen)
        if screen and type(sx) == "number" and type(sy) == "number" then
            return { x = sx, y = sy, visible = visible ~= false }
        end
    end

    if pos.ToScreen then
        local screen, visible = safe(pos.ToScreen, pos)
        local sx, sy = vector_components(screen)
        if screen and type(sx) == "number" and type(sy) == "number" then
            return { x = sx, y = sy, visible = visible ~= false }
        end
    end

    return nil
end

local function screen_vec(point)
    if Vec2 then
        local ok, vec = pcall(Vec2, vec_x(point), vec_y(point))
        if ok and vec then return vec end
    end
    return point
end

local function draw_screen_line(a, b, draw_color, thickness)
    if not a or not b then return false end

    if Render and Render.Line then
        local ok = pcall(Render.Line, screen_vec(a), screen_vec(b), draw_color, thickness)
        if ok then return true end
    end

    if Renderer and Renderer.SetDrawColor and Renderer.DrawLine then
        local r = draw_color.r or 255
        local g = draw_color.g or 255
        local bcol = draw_color.b or 255
        local a_col = draw_color.a or 255
        safe(Renderer.SetDrawColor, r, g, bcol, a_col)
        safe(Renderer.DrawLine, math.floor(a.x + 0.5), math.floor(a.y + 0.5), math.floor(b.x + 0.5), math.floor(b.y + 0.5))
        return true
    end

    return false
end

local function draw_world_line(from, to, draw_color, thickness)
    local a = project_world(from)
    local b = project_world(to)
    if not a or not b then return false end
    return draw_screen_line(a, b, draw_color, thickness)
end

local function add_segment(segments, from, to)
    segments[#segments + 1] = { from = from, to = to }
end

local function build_cone_segments(origin, direction, range, half_angle)
    local segments = {}
    local left = rotate_direction(direction, -half_angle)
    local right = rotate_direction(direction, half_angle)
    add_segment(segments, origin, point_at(origin, left, range))
    add_segment(segments, origin, point_at(origin, right, range))

    local base_yaw = direction_yaw(direction)
    local previous = nil

    for i = 0, DRAW_CONE_SEGMENTS do
        local pct = i / DRAW_CONE_SEGMENTS
        local yaw = base_yaw - half_angle + half_angle * 2 * pct
        local point = point_at(origin, yaw_to_direction(yaw), range)
        if previous then add_segment(segments, previous, point) end
        previous = point
    end

    return segments
end

local function cone_geometry_matches(geometry, origin, direction, range, half_angle)
    if not geometry then return false end
    return math.abs(geometry.origin_x - vec_x(origin)) < 0.5
        and math.abs(geometry.origin_y - vec_y(origin)) < 0.5
        and math.abs(geometry.origin_z - vec_z(origin)) < 0.5
        and math.abs(geometry.direction_x - direction.x) < 0.001
        and math.abs(geometry.direction_y - direction.y) < 0.001
        and math.abs(geometry.range - range) < 0.5
        and math.abs(geometry.half_angle - half_angle) < 0.01
end

local function update_cone_geometry(cyclone, range, half_angle)
    local origin = cyclone.landing
    local direction = cyclone.pre_forward
    if not origin or not direction then return nil end

    if cone_geometry_matches(cyclone.cone_geometry, origin, direction, range, half_angle) then
        return cyclone.cone_geometry.segments
    end

    local geometry = {
        origin_x = vec_x(origin),
        origin_y = vec_y(origin),
        origin_z = vec_z(origin),
        direction_x = direction.x,
        direction_y = direction.y,
        range = range,
        half_angle = half_angle,
        segments = build_cone_segments(origin, direction, range, half_angle),
    }

    cyclone.cone_geometry = geometry
    return geometry.segments
end

local function draw_segments(segments, draw_color, thickness)
    if not segments then return end
    for _, segment in ipairs(segments) do
        draw_world_line(segment.from, segment.to, draw_color, thickness)
    end
end

local function js_escape(text)
    text = tostring(text or "")
    text = text:gsub("\\", "\\\\")
    text = text:gsub("`", "\\`")
    text = text:gsub("%$", "\\$")
    text = text:gsub("\n", "\\n")
    return text
end

local function panorama_overlay(text, visible)
    if not Engine or not Engine.RunScript then return end
    local t = game_time()
    if visible and t - state.last_panorama_at < 0.12 then return end
    if not visible and not state.overlay_visible then return end
    state.last_panorama_at = t

    local js
    if visible then
        state.overlay_visible = true
        js = string.format([[
(function () {
    var root = $.GetContextPanel();
    var panel = root.FindChildTraverse("EulWindWakerBlinkHelperOverlay");
    if (!panel) {
        panel = $.CreatePanel("Label", root, "EulWindWakerBlinkHelperOverlay");
        panel.style.position = "0px 0px 0px";
        panel.style.marginLeft = "28px";
        panel.style.marginTop = "260px";
        panel.style.padding = "10px 14px";
        panel.style.backgroundColor = "rgba(5, 10, 18, 0.78)";
        panel.style.border = "1px solid rgba(120, 210, 255, 0.65)";
        panel.style.borderRadius = "6px";
        panel.style.color = "white";
        panel.style.fontSize = "18px";
        panel.style.textShadow = "0px 1px 3px #000000";
        panel.style.whiteSpace = "pre";
        panel.style.zIndex = "9999";
    }
    panel.text = `%s`;
    panel.visible = true;
})();
]], js_escape(text))
    else
        state.overlay_visible = false
        js = [[
(function () {
    var root = $.GetContextPanel();
    var panel = root.FindChildTraverse("EulWindWakerBlinkHelperOverlay");
    if (panel) panel.visible = false;
})();
]]
    end

    safe(Engine.RunScript, js, "Hud")
end

local function helper_metrics(hero)
    local cyclone = update_cyclone_state(hero)
    if not cyclone or not cyclone.modifier_name then return nil, "герой не в циклоне" end

    local blink, blink_name = get_item(hero, BLINK_ITEMS)
    if not blink then return nil, "Blink-предмет не найден" end

    local cursor = cursor_position()
    local landing = cyclone.landing
    local forward = cyclone.pre_forward
    local remaining = cyclone.remaining or 0

    if remaining <= 0 then return nil, "герой не в циклоне" end
    if not landing then return nil, "нет позиции приземления" end
    if not cursor then return nil, "нет позиции курсора" end
    if not forward then return nil, "нет сохранённого направления взгляда" end

    local cursor_visual = ground_draw_position(cursor, cyclone.ground_z) or cursor
    local range = blink_range(hero, blink)
    local direction_to_cursor = direction_between(landing, cursor_visual) or forward
    local angle_delta = angle_between(forward, direction_to_cursor)
    local half_angle = widget_get(ui.instant_half_angle, 45.0)
    local is_instant = angle_delta <= half_angle

    return {
        cyclone = cyclone,
        landing = landing,
        cursor = cursor_visual,
        forward = forward,
        blink = blink,
        blink_name = blink_name,
        blink_range = range,
        direction_to_cursor = direction_to_cursor,
        angle_delta = angle_delta,
        half_angle = half_angle,
        is_instant = is_instant,
        remaining = remaining,
        remaining_source = cyclone.remaining_source,
        cyclone_name = cyclone.modifier_name,
        pre_facing_angle = cyclone.pre_angle,
        item_type = cyclone.item_type,
    }, nil
end

local function render_helper(metrics)
    local thickness = widget_get(ui.thickness, 2.0)
    local cone_color = color_from(ui.cone_color, DEFAULT_CONE_COLOR)
    local valid_color = color_from(ui.valid_color, DEFAULT_VALID_COLOR)
    local invalid_color = color_from(ui.invalid_color, DEFAULT_INVALID_COLOR)
    local cursor_color = metrics.is_instant and valid_color or invalid_color

    if widget_get(ui.show_cone, true) then
        local segments = update_cone_geometry(metrics.cyclone, metrics.blink_range, metrics.half_angle)
        draw_segments(segments, cone_color, thickness)
    end

    if widget_get(ui.show_cursor, true) then
        draw_world_line(metrics.landing, metrics.cursor, cursor_color, thickness)
    end

    if widget_get(ui.show_debug_overlay, false) and widget_get(ui.show_time, true) then
        local text = string.format(
            "Помощник Blink после Eul / Wind Waker\nосталось: %.2f с\nотклонение: %.1f° / %.1f°\nнаправление взгляда: %.1f°\nBlink: %s\nрежим: %s",
            metrics.remaining,
            metrics.angle_delta,
            metrics.half_angle,
            metrics.pre_facing_angle or 0,
            localized_blink_name(metrics.blink_name),
            metrics.is_instant and "мгновенный" or "с поворотом"
        )
        panorama_overlay(text, true)
    else
        panorama_overlay("", false)
    end
end

local function order_type(order)
    return order and (order.order or order.orderType or order.type)
end

local function order_issuer_npc(order)
    return order and (order.npc or order.unit or order.issuer_npc)
end

local function is_self_eul_order(order, hero)
    if not order or not hero then return false end

    local cast_target = Enum and Enum.UnitOrder and Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TARGET or 6
    if order_type(order) ~= cast_target then return false end

    local issuer = order_issuer_npc(order)
    if issuer and issuer ~= hero then return false end

    if order.target ~= hero then return false end

    local item_type, item_name = eul_item_info(order.ability)
    if not item_type then return false end

    return true, item_type, item_name
end

function script.OnPrepareUnitOrders(order)
    if not widget_get(ui.enabled, true) then return true end

    local hero = local_hero()
    if not hero then return true end

    local is_self_eul, item_type, item_name = is_self_eul_order(order, hero)
    if not is_self_eul then return true end

    capture_pre_cyclone(hero, order.ability, item_name, item_type, "manual self-cast")
    return true
end

function script.OnUpdate()
    if not widget_get(ui.enabled, true) then
        panorama_overlay("", false)
        state.cyclone = nil
        state.pending_cyclone = nil
        return
    end

    local hero = local_hero()
    if not hero then
        panorama_overlay("", false)
        set_status("нет локального героя")
        state.cyclone = nil
        state.pending_cyclone = nil
        return
    end

    local show_overlay = widget_get(ui.show_debug_overlay, false) and widget_get(ui.show_time, true)
    if not show_overlay then
        update_cyclone_state(hero)
        panorama_overlay("", false)
        return
    end

    local metrics, err = helper_metrics(hero)
    if not metrics then
        set_status(err or "ожидание")
        panorama_overlay("", false)
        return
    end

    set_status(string.format(
        "циклон %.2f с / отклонение %.1f° / %s",
        metrics.remaining,
        metrics.angle_delta,
        metrics.is_instant and "мгновенный" or "с поворотом"
    ))
    local text = string.format(
        "Помощник Blink после Eul / Wind Waker\nосталось: %.2f с\nотклонение: %.1f° / %.1f°\nнаправление взгляда: %.1f°\nBlink: %s\nрежим: %s",
        metrics.remaining,
        metrics.angle_delta,
        metrics.half_angle,
        metrics.pre_facing_angle or 0,
        localized_blink_name(metrics.blink_name),
        metrics.is_instant and "мгновенный" or "с поворотом"
    )
    panorama_overlay(text, true)
end

function script.OnDraw()
    if not widget_get(ui.enabled, true) then return end

    local hero = local_hero()
    if not hero then return end

    local metrics = helper_metrics(hero)
    if not metrics then return end

    render_helper(metrics)
end

function script.OnGameEnd()
    state.hero = nil
    state.pending_cyclone = nil
    state.cyclone = nil
    state.last_pre_cyclone = nil
    panorama_overlay("", false)
end

return script
