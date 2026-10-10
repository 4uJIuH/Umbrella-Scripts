
local DEFAULT_ENABLED = true
local UNIT_METER = 37.7358490566
local DEFAULT_MAX_DISTANCE_M = 85.0
local DEFAULT_UPDATE_INTERVAL = 0.12
local DEFAULT_TEXT_SIZE = 14.0
local DEFAULT_MARKER_SCALE = 1.0
local DEFAULT_MAX_ENTRIES = 70
local BOX_STROKE_WIDTH = 1.0
local ICON_EYE = "\239\129\174"
local ICON_SINNER = "\239\129\155"
local ICON_TEXT = "\239\128\177"
local ICON_SCAN = "\239\128\130"
local ICON_LABEL = "\239\128\171"
local ICON_DISTANCE = "\239\133\142"
local ICON_TEXT_SIZE = "\239\128\180"
local ICON_RING = "\239\132\140"
local ICON_BOX_MARKER = "\239\130\150"
local ICON_SCALE = "\239\129\165"
local ICON_INTERVAL = "\239\128\151"
local ICON_LIST = "\239\131\139"

local menu_text = {
    main = "Vault & Tunnel ESP",
    settings = "Settings",
    scan = "Scan",
    scan_options = "Scan Options",
    max_distance = "Max Distance",
    update_interval = "Update Interval",
    max_entries = "Max Entries",
}
local function force_menu_text(widget, text)
    if widget and text then
        pcall(function()
            widget:ForceLocalization(text)
        end)
    end
end

local function set_menu_icon(widget, icon)
    if widget and icon then
        pcall(function()
            widget:Icon(icon)
        end)
    end
end

local menu_group = Menu.Find("Visuals", "", "Visuals", "World", "Show Me More")
if not menu_group then
    menu_group = Menu.Create("Visuals", "", "Visuals", "World", "Show Me More")
end

local menu_enabled = Menu.Find("Visuals", "", "Visuals", "World", "Show Me More", "Vault & Tunnel ESP")
if not menu_enabled then
    menu_enabled = menu_group:Switch("Vault & Tunnel ESP", DEFAULT_ENABLED)
end

local menu_settings = Menu.Find("Visuals", "", "Visuals", "World", "Show Me More", "Vault & Tunnel ESP", "Settings")
if not menu_settings then
    menu_settings = menu_enabled:Gear("Settings")
end

local OBJECT_MENU_ORDER = { "sinner", "fake_wall" }
local OBJECT_MENU_CONFIG = {
    sinner = {
        switch_name = "Souls Vault",
        gear_name = "Souls Vault Settings",
        default_label = "SOULS VAULT",
        icon = ICON_SINNER,
        color = Color(255, 82, 112, 255),
        text_color = Color(245, 245, 245, 255),
    },
    fake_wall = {
        switch_name = "Rem's Tunnel",
        gear_name = "Rem's Tunnel Settings",
        default_label = "REM'S TUNNEL",
        icon = ICON_BOX_MARKER,
        color = Color(80, 210, 255, 230),
        text_color = Color(245, 245, 245, 255),
    },
}

local menu_objects = {}

local function create_object_menu(kind)
    local config = OBJECT_MENU_CONFIG[kind]
    local enabled = menu_settings:Switch(config.switch_name, true)
    local gear = enabled:Gear(config.gear_name)
    local settings = {
        enabled = enabled,
        gear = gear,
        config = config,
    }

    settings.show_name = gear:Switch("Show Name", true)
    settings.label = gear:Input("Name Text", config.default_label)
    settings.text_size = gear:Slider("Text Size", 10.0, 22.0, DEFAULT_TEXT_SIZE, "%.0f")
    settings.color = gear:ColorPicker("Color", config.color)
    settings.text_color = gear:ColorPicker("Text Color", config.text_color)
    settings.show_distance = gear:Switch("Show Distance", true)
    settings.show_3d_box = gear:Switch("Show 3D Box", true)
    settings.show_ring = gear:Switch("Show Ring", true)
    settings.marker_scale = gear:Slider("Ring Scale", 0.6, 1.8, DEFAULT_MARKER_SCALE, "%.1f")

    return settings
end

for i = 1, #OBJECT_MENU_ORDER do
    local kind = OBJECT_MENU_ORDER[i]
    menu_objects[kind] = create_object_menu(kind)
end

-- Доп. настройки таймера возрождения -- только для Souls Vault (sinner).
do
    local sinner = menu_objects.sinner
    sinner.show_timer = sinner.gear:Switch("Show Respawn Timer", true)
    sinner.respawn_time = sinner.gear:Slider("Respawn Time", 30, 600, 300, "%d s")
    sinner.timer_color = sinner.gear:ColorPicker("Timer Color", Color(255, 215, 64, 255))
    sinner.timer_color_soon = sinner.gear:ColorPicker("Timer Color (< 30s)", Color(255, 70, 70, 255))
    sinner.broken_hp_threshold = sinner.gear:Slider("Broken HP Threshold", 1, 200, 50, "%d")
    sinner.show_minimap = sinner.gear:Switch("Show Timer On Minimap", true)
end

local menu_scan_header = menu_settings:Label("Scan")
local menu_scan_options = menu_scan_header:Gear("Scan Options")
local menu_max_distance = menu_scan_options:Slider("Max Distance", 10.0, 185.0, DEFAULT_MAX_DISTANCE_M, "%.0f m")
local menu_update_interval = menu_scan_options:Slider("Update Interval", 0.03, 0.50, DEFAULT_UPDATE_INTERVAL, "%.2fs")
local menu_max_entries = menu_scan_options:Slider("Max Entries", 10, 140, DEFAULT_MAX_ENTRIES, "%d")

local function object_settings(kind)
    return menu_objects[kind] or menu_objects.sinner
end

local function update_object_menu_visibility()
    for i = 1, #OBJECT_MENU_ORDER do
        local settings = object_settings(OBJECT_MENU_ORDER[i])
        settings.label:Visible(settings.show_name:Get())
    end
end

local function apply_menu_language()
    force_menu_text(menu_enabled, menu_text.main)
    force_menu_text(menu_settings, menu_text.settings)

    for i = 1, #OBJECT_MENU_ORDER do
        local settings = object_settings(OBJECT_MENU_ORDER[i])
        local config = settings.config
        force_menu_text(settings.enabled, config.switch_name)
        force_menu_text(settings.gear, config.gear_name)
        force_menu_text(settings.show_name, "Show Name")
        force_menu_text(settings.label, "Name Text")
        force_menu_text(settings.text_size, "Text Size")
        force_menu_text(settings.color, "Color")
        force_menu_text(settings.text_color, "Text Color")
        force_menu_text(settings.show_distance, "Show Distance")
        force_menu_text(settings.show_3d_box, "Show 3D Box")
        force_menu_text(settings.show_ring, "Show Ring")
        force_menu_text(settings.marker_scale, "Ring Scale")
    end

    force_menu_text(menu_scan_header, menu_text.scan)
    force_menu_text(menu_scan_options, menu_text.scan_options)
    force_menu_text(menu_max_distance, menu_text.max_distance)
    force_menu_text(menu_update_interval, menu_text.update_interval)
    force_menu_text(menu_max_entries, menu_text.max_entries)
end

local function apply_menu_icons()
    set_menu_icon(menu_enabled, ICON_EYE)

    for i = 1, #OBJECT_MENU_ORDER do
        local settings = object_settings(OBJECT_MENU_ORDER[i])
        local icon = settings.config.icon
        set_menu_icon(settings.enabled, icon)
        set_menu_icon(settings.show_name, ICON_LABEL)
        set_menu_icon(settings.label, ICON_LABEL)
        set_menu_icon(settings.text_size, ICON_TEXT_SIZE)
        set_menu_icon(settings.color, icon)
        set_menu_icon(settings.text_color, ICON_TEXT)
        set_menu_icon(settings.show_distance, ICON_DISTANCE)
        set_menu_icon(settings.show_3d_box, ICON_BOX_MARKER)
        set_menu_icon(settings.show_ring, ICON_RING)
        set_menu_icon(settings.marker_scale, ICON_SCALE)
    end

    set_menu_icon(menu_scan_header, ICON_SCAN)
    set_menu_icon(menu_max_distance, ICON_DISTANCE)
    set_menu_icon(menu_update_interval, ICON_INTERVAL)
    set_menu_icon(menu_max_entries, ICON_LIST)
end

local function apply_sinner_timer_menu_polish()
    local sinner = menu_objects.sinner
    force_menu_text(sinner.show_timer, "Show Respawn Timer")
    force_menu_text(sinner.respawn_time, "Respawn Time")
    force_menu_text(sinner.timer_color, "Timer Color")
    force_menu_text(sinner.timer_color_soon, "Timer Color (< 30s)")
    force_menu_text(sinner.broken_hp_threshold, "Broken HP Threshold")
    force_menu_text(sinner.show_minimap, "Show Timer On Minimap")

    set_menu_icon(sinner.show_timer, ICON_SINNER)
    set_menu_icon(sinner.respawn_time, ICON_INTERVAL)
    set_menu_icon(sinner.timer_color, ICON_SINNER)
    set_menu_icon(sinner.timer_color_soon, ICON_SINNER)
    set_menu_icon(sinner.broken_hp_threshold, ICON_SINNER)
    set_menu_icon(sinner.show_minimap, ICON_SINNER)
end

apply_menu_icons()
apply_menu_language()
apply_sinner_timer_menu_polish()
update_object_menu_visibility()

for i = 1, #OBJECT_MENU_ORDER do
    local settings = object_settings(OBJECT_MENU_ORDER[i])
    pcall(function()
        settings.show_name:SetCallback(function()
            update_object_menu_visibility()
        end, true)
    end)
end

local title_font = Render.LoadFont("Tahoma", Enum.FontCreate.FONTFLAG_ANTIALIAS, 800)
local body_font = Render.LoadFont("Tahoma", Enum.FontCreate.FONTFLAG_ANTIALIAS, 550)

local SINNER_SACRIFICE_CLASSES = {
    "C_NPC_Neutral_SinnersSacrifice",
    "C_NPC_Neutral_SinnersSacrifice_Hideout",
}

local FAKE_WALL_CLASS = "CCitadelPassthroughFakeWall"

-- Рёбра куба для отрисовки 3D-бокса (индексы соответствуют 8 углам,
-- сгенерированным в build_entry_corners).
local BOX_EDGES = {
    {1, 2}, {2, 4}, {4, 3}, {3, 1},
    {5, 6}, {6, 8}, {8, 7}, {7, 5},
    {1, 5}, {2, 6}, {3, 7}, {4, 8},
}

local SINNER_SACRIFICE_KEYWORDS = {
    "sinnerssacrifice",
    "sinner_sacrifice",
    "sinner",
    "sacrifice",
}

local state = {
    entries = {},
    last_update_time = -9999.0,
}

-- Таймеры возрождения Souls Vault (sinner). Ключ -- index сущности.
-- entry = { was_broken, last_origin, timer_origin, timer_start }
local sinner_timers = {}

local function safe_number(value, default)
    if type(value) == "number" then
        return value
    end

    local parsed = tonumber(value)
    if parsed ~= nil then
        return parsed
    end

    return default or 0
end

local function safe_bool(value, default)
    if type(value) == "boolean" then
        return value
    end

    return default
end

local function clean_menu_text(value, fallback)
    if type(value) ~= "string" then
        return fallback
    end

    local cleaned = value:gsub("^%s+", ""):gsub("%s+$", "")
    if cleaned == "" then
        return fallback
    end

    return cleaned
end

local function get_input_label(input_box, fallback)
    local ok, value = pcall(function()
        return input_box:Get()
    end)

    if not ok then
        return fallback
    end

    return clean_menu_text(value, fallback)
end

local function get_kind_label(kind)
    local settings = object_settings(kind)
    return get_input_label(settings.label, settings.config.default_label)
end

local function safe_field(obj, field_name, default)
    if not obj then
        return default
    end

    local ok, value = pcall(function()
        return obj[field_name]
    end)

    if not ok or value == nil then
        return default
    end

    return value
end

local function safe_method(obj, method_name, default, ...)
    if not obj then
        return default
    end

    local method = obj[method_name]
    if type(method) ~= "function" then
        return default
    end

    local ok, value = pcall(method, obj, ...)
    if not ok or value == nil then
        return default
    end

    return value
end

local function get_now()
    if game_rules and type(game_rules.game_time) == "function" then
        local ok, value = pcall(game_rules.game_time)
        if ok then
            local game_time = safe_number(value, 0.0)
            if game_time > 0.0 then
                return game_time
            end
        end
    end

    return os.clock()
end

local function copy_vector(vec)
    return Vector(vec.x, vec.y, vec.z)
end

local function offset_vector(vec, z_offset)
    return Vector(vec.x, vec.y, vec.z + z_offset)
end

local function get_origin(ent)
    if not ent or not ent:valid() then
        return nil
    end

    return safe_method(ent, "get_origin", nil)
end

local function get_class_name(ent)
    return safe_method(ent, "get_class_name", "")
end

local function get_model_name(ent)
    return safe_method(ent, "get_model_name", "")
end

local function get_entity_name(ent)
    return safe_method(ent, "get_name", "")
end

local function get_vdata_class_name(ent)
    return safe_method(ent, "get_vdata_class_name", "")
end

local function get_index(ent)
    return safe_method(ent, "get_index", nil)
end

local function contains_any(text, keywords)
    if type(text) ~= "string" or text == "" then
        return false
    end

    local lower = text:lower()
    for i = 1, #keywords do
        if lower:find(keywords[i], 1, true) ~= nil then
            return true
        end
    end

    return false
end

local function is_entity_active(ent)
    if not ent or not ent:valid() then
        return false
    end

    if safe_method(ent, "is_dormant", false) == true then
        return false
    end

    if safe_method(ent, "is_alive", true) == false then
        return false
    end

    if safe_bool(safe_field(ent, "m_bActive", true), true) == false then
        return false
    end

    if safe_bool(safe_field(ent, "m_bVacuumFinished", false), false) == true then
        return false
    end

    if safe_bool(safe_field(ent, "m_bBroken", false), false) == true then
        return false
    end

    if safe_bool(safe_field(ent, "m_bPermanentlyBroken", false), false) == true then
        return false
    end

    local health = safe_field(ent, "m_iHealth", nil)
    if health ~= nil and safe_number(health, 1) <= 0 then
        return false
    end

    local life_state = safe_field(ent, "m_lifeState", nil)
    if life_state ~= nil and safe_number(life_state, 0) ~= 0 then
        return false
    end

    local model_scale = safe_field(ent, "m_flModelScale", nil)
    if model_scale ~= nil and safe_number(model_scale, 1.0) <= 0.01 then
        return false
    end

    return true
end

-- То же самое, что учитывают флаги "сломан" внутри is_entity_active, но без
-- проверки dormant/is_alive -- нужно отдельно, чтобы отличать "временно вне
-- PVS" от "реально разрушен", когда объект уже гарантированно валиден.
-- health_threshold: HP <= этого значения тоже считается разрушением (по
-- наблюдению, у Souls Vault HP не обязательно доходит до 0 -- зависает на
-- низком значении вроде 1, а m_bBroken/m_bPermanentlyBroken у этого класса
-- вообще не существуют, т.к. это NPC, а не BreakableProp).
local function is_sinner_broken(ent, health_threshold)
    if not ent or not ent:valid() then
        return false
    end

    if safe_bool(safe_field(ent, "m_bBroken", false), false) == true then
        return true
    end

    if safe_bool(safe_field(ent, "m_bPermanentlyBroken", false), false) == true then
        return true
    end

    local health = safe_field(ent, "m_iHealth", nil)
    if health ~= nil and safe_number(health, 9999) <= (health_threshold or 0) then
        return true
    end

    local life_state = safe_field(ent, "m_lifeState", nil)
    if life_state ~= nil and safe_number(life_state, 0) ~= 0 then
        return true
    end

    return false
end

local function is_sinner_sacrifice(ent, class_name, model_name)
    local entity_name = get_entity_name(ent)
    local vdata_name = get_vdata_class_name(ent)
    local identity = class_name .. " " .. model_name .. " " .. entity_name .. " " .. vdata_name

    return contains_any(identity, SINNER_SACRIFICE_KEYWORDS)
end

local function get_local_origin()
    local local_pawn = entity_list.local_pawn()
    if not local_pawn or not local_pawn:valid() then
        return nil
    end

    return get_origin(local_pawn)
end

local function meters_to_units(meters)
    return meters * UNIT_METER
end

local function units_to_meters(units)
    return units / UNIT_METER
end

local function distance_ok(local_origin, origin)
    if not local_origin or not origin then
        return false, 0.0
    end

    local distance = local_origin:Distance(origin)
    return distance <= meters_to_units(menu_max_distance:Get()), distance
end

local function add_entry(entries, kind, ent, origin, distance)
    local class_name = get_class_name(ent)
    local model_name = get_model_name(ent)
    local entity_name = get_entity_name(ent)
    local vdata_name = get_vdata_class_name(ent)
    local label = get_kind_label(kind)

    entries[#entries + 1] = {
        kind = kind,
        label = label,
        origin = copy_vector(origin),
        distance = distance,
        class_name = class_name,
        model_name = model_name,
        entity_name = entity_name,
        vdata_name = vdata_name,
        index = get_index(ent) or 0,
        ent = ent,
    }
end

local function collect_sinner_sacrifices(entries, local_origin, seen)
    if not object_settings("sinner").enabled:Get() then
        return
    end

    for i = 1, #SINNER_SACRIFICE_CLASSES do
        local ok, entities = pcall(entity_list.by_class_name, SINNER_SACRIFICE_CLASSES[i])
        if ok and type(entities) == "table" then
            for j = 1, #entities do
                local ent = entities[j]
                local index = get_index(ent)
                if index and not seen[index] and is_entity_active(ent) then
                    local class_name = get_class_name(ent)
                    local model_name = get_model_name(ent)

                    if is_sinner_sacrifice(ent, class_name, model_name) then
                        local origin = get_origin(ent)
                        local in_range, distance = distance_ok(local_origin, origin)

                        if in_range then
                            add_entry(entries, "sinner", ent, origin, distance)
                            seen[index] = true
                        end
                    end
                end
            end
        end
    end
end

local function collect_fake_walls(entries, local_origin, seen)
    if not object_settings("fake_wall").enabled:Get() then
        return
    end

    local ok, entities = pcall(entity_list.by_class_name, FAKE_WALL_CLASS)
    if not ok or type(entities) ~= "table" then
        return
    end

    for i = 1, #entities do
        local ent = entities[i]
        local index = get_index(ent)
        if index and not seen[index] and ent and ent:valid() then
            local origin = get_origin(ent)
            local in_range, distance = distance_ok(local_origin, origin)

            if in_range then
                add_entry(entries, "fake_wall", ent, origin, distance)
                seen[index] = true
            end
        end
    end
end

local function rebuild_entries()
    local now = get_now()
    if (now - state.last_update_time) < menu_update_interval:Get() then
        return
    end

    state.last_update_time = now

    local local_origin = get_local_origin()
    if not local_origin then
        state.entries = {}
        return
    end

    local entries = {}
    local seen = {}

    collect_sinner_sacrifices(entries, local_origin, seen)
    collect_fake_walls(entries, local_origin, seen)

    table.sort(entries, function(a, b)
        return a.distance < b.distance
    end)

    local max_entries = menu_max_entries:Get()
    if #entries > max_entries then
        local trimmed = {}
        for i = 1, max_entries do
            trimmed[#trimmed + 1] = entries[i]
        end
        entries = trimmed
    end

    state.entries = entries
end


local function get_entry_color(entry)
    return object_settings(entry.kind).color:Get()
end

local function get_marker_radius(settings)
    return 8.0 * settings.marker_scale:Get()
end

local function draw_shadowed_text(font, font_size, text, pos, color)
    Render.Text(font, font_size, text, Vec2(pos.x + 1.0, pos.y + 1.0), Color(0, 0, 0, 220))
    Render.Text(font, font_size, text, pos, color)
end

local function draw_centered_text(font, font_size, text, center_x, y, color)
    local size = Render.TextSize(font, font_size, text)
    draw_shadowed_text(font, font_size, text, Vec2(center_x - size.x * 0.5, y), color)
    return size
end

local function rotate_yaw(vec, yaw)
    local rad = math.rad(yaw or 0.0)
    local cos_y = math.cos(rad)
    local sin_y = math.sin(rad)

    return Vector(
        vec.x * cos_y - vec.y * sin_y,
        vec.x * sin_y + vec.y * cos_y,
        vec.z
    )
end

local function add_vector(a, b)
    return Vector(a.x + b.x, a.y + b.y, a.z + b.z)
end

local ENTRY_BOUNDS_FALLBACK = {
    sinner = { mins = Vector(-44, -44, 0), maxs = Vector(44, 44, 128) },
    fake_wall = { mins = Vector(-24, -24, 0), maxs = Vector(24, 24, 96) },
}

local function valid_bound_vector(vec)
    return vec
        and type(safe_field(vec, "x", nil)) == "number"
        and type(safe_field(vec, "y", nil)) == "number"
        and type(safe_field(vec, "z", nil)) == "number"
end

local function valid_bounds(mins, maxs)
    if not valid_bound_vector(mins) or not valid_bound_vector(maxs) then
        return false
    end

    return math.abs(maxs.x - mins.x) > 1.0
        or math.abs(maxs.y - mins.y) > 1.0
        or math.abs(maxs.z - mins.z) > 1.0
end

local function get_entry_fallback_bounds(kind)
    local bounds = ENTRY_BOUNDS_FALLBACK[kind] or ENTRY_BOUNDS_FALLBACK.sinner
    return bounds.mins, bounds.maxs
end

local function get_entry_bounds(ent, kind)
    local collision = safe_field(ent, "m_Collision", nil)
    local mins = safe_field(collision, "m_vecMins", nil)
    local maxs = safe_field(collision, "m_vecMaxs", nil)

    if valid_bounds(mins, maxs) then
        return mins, maxs
    end

    return get_entry_fallback_bounds(kind)
end

local function build_entry_corners(ent, origin, kind)
    local mins, maxs = get_entry_bounds(ent, kind)
    local angles = safe_method(ent, "get_angles", nil)
    local yaw = angles and angles.yaw or 0.0
    local local_corners = {
        Vector(mins.x, mins.y, mins.z),
        Vector(maxs.x, mins.y, mins.z),
        Vector(mins.x, maxs.y, mins.z),
        Vector(maxs.x, maxs.y, mins.z),
        Vector(mins.x, mins.y, maxs.z),
        Vector(maxs.x, mins.y, maxs.z),
        Vector(mins.x, maxs.y, maxs.z),
        Vector(maxs.x, maxs.y, maxs.z),
    }
    local corners = {}

    for i = 1, #local_corners do
        corners[i] = add_vector(origin, rotate_yaw(local_corners[i], yaw))
    end

    return corners
end

local function project_corners(corners)
    local projected = {}
    local min_x, min_y = math.huge, math.huge
    local max_x, max_y = -math.huge, -math.huge

    for i = 1, #corners do
        local screen, visible = Render.WorldToScreen(corners[i])
        if not visible then
            return nil
        end

        projected[i] = screen
        if screen.x < min_x then min_x = screen.x end
        if screen.y < min_y then min_y = screen.y end
        if screen.x > max_x then max_x = screen.x end
        if screen.y > max_y then max_y = screen.y end
    end

    return projected, Vec2(min_x, min_y), Vec2(max_x, max_y)
end

local function should_draw_entry_3d_box(entry)
    return object_settings(entry.kind).show_3d_box:Get()
end

local function draw_projected_3d_box(projected, color)
    for i = 1, #BOX_EDGES do
        local edge = BOX_EDGES[i]
        Render.Line(projected[edge[1]], projected[edge[2]], color, BOX_STROKE_WIDTH)
    end
end

local function get_entry_projected_box(entry)
    local ent = entry.ent
    if not ent or not ent:valid() then
        return nil, nil, nil
    end

    local origin = get_origin(ent) or entry.origin
    if not origin then
        return nil, nil, nil
    end

    return project_corners(build_entry_corners(ent, origin, entry.kind))
end

local function draw_entry_3d_box(entry, color, projected)
    if not should_draw_entry_3d_box(entry) or not projected then
        return
    end

    draw_projected_3d_box(projected, color)
end

local function draw_fake_wall_entry(entry)
    local ent = entry.ent
    if not ent or not ent:valid() then
        return
    end

    local origin = get_origin(ent) or entry.origin
    if not origin then
        return
    end

    local corners = build_entry_corners(ent, origin, entry.kind)
    local projected, box_min, box_max = project_corners(corners)
    if not projected then
        return
    end

    local settings = object_settings(entry.kind)
    local color = get_entry_color(entry)

    if should_draw_entry_3d_box(entry) then
        draw_projected_3d_box(projected, color)
    end

    local text_size = settings.text_size:Get()
    if settings.show_name:Get() then
        local label = entry.label
        local label_size = Render.TextSize(title_font, text_size, label)
        local label_pos = Vec2(box_min.x + ((box_max.x - box_min.x) - label_size.x) * 0.5, box_min.y - label_size.y - 6.0)
        draw_shadowed_text(title_font, text_size, label, label_pos, color)
    end

    local next_y = box_max.y + 4.0
    if settings.show_distance:Get() then
        local distance_text = string.format("%.0f m", units_to_meters(entry.distance))
        draw_centered_text(body_font, text_size - 1.0, distance_text, box_min.x + (box_max.x - box_min.x) * 0.5, next_y, settings.text_color:Get())
    end
end

local function draw_entry(entry)
    if entry.kind == "fake_wall" then
        draw_fake_wall_entry(entry)
        return
    end

    local z_offset = 72.0

    local settings = object_settings(entry.kind)
    local color = get_entry_color(entry)
    local projected, box_min, box_max = get_entry_projected_box(entry)
    draw_entry_3d_box(entry, color, projected)

    local screen_pos
    if box_min and box_max then
        screen_pos = Vec2((box_min.x + box_max.x) * 0.5, (box_min.y + box_max.y) * 0.5)
    else
        local visible
        screen_pos, visible = Render.WorldToScreen(offset_vector(entry.origin, z_offset))
        if not visible then
            return
        end
    end

    local text_color = settings.text_color:Get()
    local text_size = settings.text_size:Get()
    local marker_radius = get_marker_radius(settings)

    if settings.show_ring:Get() then
        Render.FilledCircle(screen_pos, marker_radius + 2.0, Color(0, 0, 0, 90), 0.0, 1.0, 28)
        Render.Circle(screen_pos, marker_radius, color, 1.7, 0.0, 1.0, true, 32)
    end

    if settings.show_name:Get() then
        local label_y = screen_pos.y - marker_radius - text_size - 7.0
        if box_min then
            label_y = box_min.y - text_size - 7.0
        end
        draw_centered_text(title_font, text_size, entry.label, screen_pos.x, label_y, color)
    end

    local next_y = screen_pos.y + marker_radius + 4.0
    if box_max then
        next_y = box_max.y + 4.0
    end
    if settings.show_distance:Get() then
        local distance_text = string.format("%.0f m", units_to_meters(entry.distance))
        draw_centered_text(body_font, text_size - 1.0, distance_text, screen_pos.x, next_y, text_color)
    end
end

-- Отслеживание Souls Vault ведётся ПОСТОЯННО через on_add_entity/
-- on_remove_entity (как в camp_esp.lua), а не разовым опросом by_class_name
-- каждый кадр -- потому что при разрушении объект, судя по всему, не
-- остаётся в мире с флагом "сломан", а исчезает из entity_list целиком.
-- Значит сам факт удаления ранее активной сущности -- это и есть момент
-- разрушения, который нужно ловить через on_remove_entity, а не только
-- через опрос флагов на существующей сущности.

local function classify_sinner_entity(ent)
    if not ent or not ent:valid() then return end

    -- Дешёвая проверка class_name первой -- не трогаем более тяжёлые
    -- геттеры (model_name/vdata) для сущностей, которые заведомо не подходят.
    local class_name = get_class_name(ent)
    if not class_name or class_name == "" then return end
    if not contains_any(class_name, SINNER_SACRIFICE_KEYWORDS) then return end

    local handle = get_index(ent)
    if not handle then return end

    local entry = sinner_timers[handle]
    if not entry then
        entry = { was_broken = false }
        sinner_timers[handle] = entry
    end
    entry.ent = ent
end

local function forget_sinner_entity(ent)
    if not ent then return end
    local handle = get_index(ent)
    if not handle then return end

    local entry = sinner_timers[handle]
    if not entry then return end

    entry.ent = nil

    if not entry.was_broken then
        -- Объект пропал из мира без предварительного "сломан"-флага --
        -- значит именно исчезновение и есть момент разрушения.
        entry.timer_origin = entry.last_origin
        entry.timer_start = get_now()
        entry.was_broken = true
    end
    -- Если entry.was_broken уже true -- таймер уже идёт, ничего не делаем.
end

callback.on_add_entity:set(function(ent) pcall(classify_sinner_entity, ent) end)
callback.on_late_add_entity:set(function(ent) pcall(classify_sinner_entity, ent) end)
callback.on_remove_entity:set(function(ent) pcall(forget_sinner_entity, ent) end)

-- Разовый проход по уже существующим на момент (пере)загрузки скрипта сущностям.
do
    local ok, entities = pcall(entity_list.get_all)
    if ok and type(entities) == "table" then
        for i = 1, #entities do
            pcall(classify_sinner_entity, entities[i])
        end
    end
end

-- Каждый кадр обновляем только уже классифицированные сущности (их мало) --
-- обновляем последнюю известную позицию и ловим переход "активен -> сломан"
-- как для случая, когда объект остаётся в мире со сменой HP/флагов, так и
-- для случая, когда объект уходит в dormant ОДНОВРЕМЕННО с разрушением --
-- в этом случае разрушение ловится по самому факту "не dormant -> dormant"
-- при низком HP на последнем известном кадре (в отличие от обычного ухода
-- в dormant на полном HP, когда игрок просто отходит от целого объекта).
local function update_sinner_timers()
    local sinner = menu_objects.sinner
    if not sinner.enabled:Get() or not sinner.show_timer:Get() then
        return
    end

    local now = get_now()
    local hp_threshold = sinner.broken_hp_threshold:Get()

    for handle, entry in pairs(sinner_timers) do
        local ent = entry.ent
        if ent and ent:valid() then
            local dormant_now = safe_method(ent, "is_dormant", false) == true

            if not dormant_now then
                local origin = get_origin(ent)
                if origin then
                    entry.last_origin = origin
                end

                local health = safe_field(ent, "m_iHealth", nil)
                if health ~= nil then
                    entry.last_health = safe_number(health, entry.last_health or 9999)
                end

                local broken_now = is_sinner_broken(ent, hp_threshold)

                if broken_now and not entry.was_broken then
                    entry.timer_origin = entry.last_origin or origin
                    entry.timer_start = now
                    entry.was_broken = true
                elseif not broken_now and entry.was_broken then
                    -- Ожил без ухода в dormant -- сбрасываем таймер, обычный
                    -- ESP снова подхватит его через rebuild_entries.
                    entry.timer_origin = nil
                    entry.timer_start = nil
                    entry.was_broken = false
                end
            elseif not entry.was_dormant then
                -- Только что ушёл в dormant. Если это произошло на низком
                -- HP (а не на полном, как при обычном "отошли подальше") --
                -- считаем это моментом разрушения.
                if not entry.was_broken and entry.last_health and entry.last_health <= hp_threshold then
                    entry.timer_origin = entry.last_origin
                    entry.timer_start = now
                    entry.was_broken = true
                end
            end

            entry.was_dormant = dormant_now
        end
        -- Сущность невалидна в этом кадре -- пропускаем, состояние сохраняется
        -- (окончательное исчезновение отдельно ловится в on_remove_entity).
    end
end

local function format_countdown(seconds)
    if seconds < 0 then seconds = 0 end
    local m = math.floor(seconds / 60)
    local s = math.floor(seconds % 60)
    return string.format("%02d:%02d", m, s)
end

local function draw_sinner_timers()
    local sinner = menu_objects.sinner
    if not sinner.enabled:Get() or not sinner.show_timer:Get() then
        return
    end

    local local_origin = get_local_origin()
    local respawn_time = sinner.respawn_time:Get()
    local now = get_now()

    for index, entry in pairs(sinner_timers) do
        if entry.timer_start and entry.timer_origin then
            local remaining = respawn_time - (now - entry.timer_start)

            if remaining <= 0 then
                -- Расчётное время вышло -- обычный ESP уже должен был
                -- подхватить возрождённый объект.
                entry.timer_origin = nil
                entry.timer_start = nil
            else
                local in_range, distance = distance_ok(local_origin, entry.timer_origin)
                if in_range then
                    local screen_pos, on_screen = Render.WorldToScreen(offset_vector(entry.timer_origin, 72.0))
                    if on_screen then
                        local color = (remaining <= 30) and sinner.timer_color_soon:Get() or sinner.timer_color:Get()
                        local marker_radius = get_marker_radius(sinner)
                        local text_size = sinner.text_size:Get()

                        if sinner.show_ring:Get() then
                            Render.FilledCircle(screen_pos, marker_radius + 2.0, Color(0, 0, 0, 90), 0.0, 1.0, 28)
                            Render.Circle(screen_pos, marker_radius, color, 1.7, 0.0, 1.0, true, 32)
                        end

                        local timer_text = format_countdown(remaining)
                        local next_y = draw_centered_text(title_font, text_size, timer_text, screen_pos.x, screen_pos.y - text_size * 0.5, color)

                        if sinner.show_distance:Get() then
                            local dist_text = string.format("%.0f m", units_to_meters(distance))
                            draw_centered_text(body_font, text_size - 1.0, dist_text, screen_pos.x, screen_pos.y + marker_radius + 4.0, sinner.text_color:Get())
                        end
                    end
                end
            end
        end
    end
end

local function draw_sinner_minimap()
    local sinner = menu_objects.sinner
    if not sinner.enabled:Get() or not sinner.show_timer:Get() or not sinner.show_minimap:Get() then
        return
    end

    if not utils or type(utils.world_to_map) ~= "function" then
        return
    end

    local respawn_time = sinner.respawn_time:Get()
    local now = get_now()

    for _, entry in pairs(sinner_timers) do
        if entry.timer_start and entry.timer_origin then
            local remaining = respawn_time - (now - entry.timer_start)

            if remaining > 0 then
                local ok_map, map_pos = pcall(utils.world_to_map, entry.timer_origin)

                if ok_map and map_pos then
                    local color = (remaining <= 30) and sinner.timer_color_soon:Get() or sinner.timer_color:Get()

                    local timer_text = format_countdown(remaining)
                    local text_size = Render.TextSize(body_font, 10, timer_text)
                    draw_shadowed_text(
                        body_font,
                        10,
                        timer_text,
                        Vec2(map_pos.x - text_size.x * 0.5, map_pos.y),
                        color
                    )
                end
            end
        end
    end
end

callback.on_frame:set(function()
    if not menu_enabled:Get() then
        return
    end

    pcall(rebuild_entries)
    pcall(update_sinner_timers)
end)

callback.on_draw:set(function()
    if not menu_enabled:Get() then
        return
    end

    pcall(function()
        for i = 1, #state.entries do
            draw_entry(state.entries[i])
        end
    end)

    pcall(draw_sinner_timers)
    pcall(draw_sinner_minimap)
end)
