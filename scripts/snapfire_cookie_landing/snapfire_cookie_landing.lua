---@diagnostic disable: undefined-global, param-type-mismatch, inject-field

-- UCZone API v2.0
-- Snapfire Firesnap Cookie: self-cast landing predictor + cursor-directed jump.

local script = {}

-- Menu
local group = Menu.Create(
    "Heroes",
    "Main",
    "Snapfire",
    "Firesnap Cookie",
    "Self Cookie"
)

local ui = {}
ui.enabled = group:Switch("Enabled", true, "panorama/images/spellicons/snapfire_firesnap_cookie_png.vtex_c")
ui.predictor = group:Switch("Landing predictor", true, "\u{f06e}")
ui.auto_direction = group:Switch("Jump towards cursor", true, "\u{f124}")
ui.draw_impact = group:Switch("Draw impact radius", true, "\u{f1ce}")

-- Constants
local HERO_NAME = "npc_dota_hero_snapfire"
local COOKIE_NAME = "snapfire_firesnap_cookie"
local ORDER_ID = "snapfire_cookie_self_direction"
local DEFAULT_HOP_DISTANCE = 425
local DEFAULT_IMPACT_RADIUS = 300
local STATS_CACHE_INTERVAL = 0.20
local CIRCLE_SEGMENTS = 36
local TWO_PI = math.pi * 2

local COLOR_READY = Color(70, 225, 120, 235)
local COLOR_NOT_READY = Color(235, 85, 85, 220)

local pending_cast = nil
local cached_local_hero = nil
local cached_hero_is_snapfire = false
local cached_cookie_hero = nil
local cached_cookie = nil

local stats_cache = {
    hero = nil,
    ability = nil,
    level = -1,
    expires_at = 0,
    hop_distance = DEFAULT_HOP_DISTANCE,
    impact_radius = DEFAULT_IMPACT_RADIUS
}

-- Unit-circle geometry and mutable world vectors are allocated only once.
-- OnDraw reuses them instead of creating tables and calculating sin/cos each frame.
local circle_geometry = {}
for i = 0, CIRCLE_SEGMENTS do
    local angle = TWO_PI * i / CIRCLE_SEGMENTS
    circle_geometry[i + 1] = {
        x = math.cos(angle),
        y = math.sin(angle),
        point = Vector(0, 0, 0)
    }
end

local function safe_number(func, ...)
    local ok, value = pcall(func, ...)
    if ok and type(value) == "number" then
        return value
    end

    return 0
end

local function get_local_snapfire(require_alive)
    if not Engine.IsInGame() then
        cached_local_hero = nil
        cached_hero_is_snapfire = false
        return nil
    end

    local hero = Heroes.GetLocal()
    if hero ~= cached_local_hero then
        cached_local_hero = hero
        cached_hero_is_snapfire = hero ~= nil and NPC.GetUnitName(hero) == HERO_NAME
    end

    if not hero or not cached_hero_is_snapfire then
        return nil
    end

    if require_alive and not Entity.IsAlive(hero) then
        return nil
    end

    return hero
end

local function get_cookie(hero)
    if not hero then
        return nil
    end

    if hero ~= cached_cookie_hero or not cached_cookie then
        cached_cookie_hero = hero
        cached_cookie = NPC.GetAbility(hero, COOKIE_NAME)
    end

    return cached_cookie
end

local function get_special_value(ability, names, fallback)
    for _, name in ipairs(names) do
        local value = safe_number(Ability.GetLevelSpecialValueFor, ability, name, -1)
        if value > 0 then
            return value
        end
    end

    return fallback
end

local function get_modifier_property(hero, property_name, highest_only)
    local modifier_functions = Enum.ModifierFunction
    local property = modifier_functions and modifier_functions[property_name]
    if not property then
        return 0
    end

    if highest_only then
        return safe_number(NPC.GetModifierPropertyHighest, hero, property)
    end

    return safe_number(NPC.GetModifierProperty, hero, property)
end

local function get_hop_distance(cookie)
    return get_special_value(cookie, {
        "jump_horizontal_distance",
        "jump_distance",
        "hop_distance"
    }, DEFAULT_HOP_DISTANCE)
end

local function get_impact_radius(hero, cookie)
    local base_radius = get_special_value(cookie, {
        "impact_radius",
        "landing_radius"
    }, DEFAULT_IMPACT_RADIUS)

    -- Non-stacking flat bonuses use the highest value. Explicitly stacking flat
    -- bonuses and percentage bonuses are accumulated by the game. Reading the
    -- hero's modifier properties also covers neutral items/enchantments.
    local flat_unique = get_modifier_property(
        hero,
        "MODIFIER_PROPERTY_AOE_BONUS_CONSTANT",
        true
    )
    local flat_stacking = get_modifier_property(
        hero,
        "MODIFIER_PROPERTY_AOE_BONUS_CONSTANT_STACKING",
        false
    )
    local percentage = get_modifier_property(
        hero,
        "MODIFIER_PROPERTY_AOE_BONUS_PERCENTAGE",
        false
    )

    local radius = (base_radius + flat_unique + flat_stacking) * (1 + percentage / 100)
    return math.max(0, radius)
end

local function get_cached_ability_stats(hero, cookie)
    local now = GlobalVars.GetCurTime()
    local level = Ability.GetLevel(cookie)

    if stats_cache.hero ~= hero
        or stats_cache.ability ~= cookie
        or stats_cache.level ~= level
        or now >= stats_cache.expires_at then
        stats_cache.hero = hero
        stats_cache.ability = cookie
        stats_cache.level = level
        stats_cache.expires_at = now + STATS_CACHE_INTERVAL
        stats_cache.hop_distance = get_hop_distance(cookie)
        stats_cache.impact_radius = get_impact_radius(hero, cookie)
    end

    return stats_cache.hop_distance, stats_cache.impact_radius
end

local function get_landing_position(hero, hop_distance, aim_position)
    local origin = Entity.GetAbsOrigin(hero)
    if not origin or not aim_position then
        return nil
    end

    local landing

    -- When the cursor is directly under the hero, preserve the current facing
    -- direction instead of normalizing a zero-length vector.
    if origin:DistanceSqr2D(aim_position) < 1 then
        landing = origin:MoveForward(Entity.GetRotation(hero), hop_distance)
    else
        landing = origin:Extend2D(aim_position, hop_distance)
    end

    landing:SetZ(World.GetGroundZ(landing.x, landing.y) + 8)
    return landing
end

local function draw_world_circle(center, radius, color, thickness)
    local previous_screen = nil
    local previous_visible = false

    for i = 1, #circle_geometry do
        local geometry = circle_geometry[i]
        geometry.point:Set(
            center.x + geometry.x * radius,
            center.y + geometry.y * radius,
            center.z
        )

        local screen, visible = Render.WorldToScreen(geometry.point)

        if previous_screen and previous_visible and visible then
            Render.Line(previous_screen, screen, color, thickness)
        end

        previous_screen = screen
        previous_visible = visible
    end
end

local function clear_pending_cast()
    pending_cast = nil
end

local function issue_direction_move(player, hero, cursor)
    return pcall(
        Player.PrepareUnitOrders,
        player,
        Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_DIRECTION,
        nil,
        cursor,
        nil,
        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
        hero,
        false, -- queue
        false, -- show effects
        false, -- do not call OnPrepareUnitOrders recursively
        true,  -- execute fast
        ORDER_ID,
        false  -- do not force the order through the minimap
    )
end

function script.OnPrepareUnitOrders(order)
    if not ui.enabled:Get() or not ui.auto_direction:Get() then
        return true
    end

    local hero = get_local_snapfire(true)
    if not hero then
        clear_pending_cast()
        return true
    end

    -- Any new manual order for Snapfire cancels an older delayed self-cast.
    if pending_cast and order.npc == hero then
        clear_pending_cast()
    end

    if order.order ~= Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TARGET then
        return true
    end

    if order.npc and order.npc ~= hero then
        return true
    end

    if order.target ~= hero or not order.ability then
        return true
    end

    if Ability.GetName(order.ability) ~= COOKIE_NAME then
        return true
    end

    if Ability.GetOwner(order.ability) ~= hero then
        return true
    end

    if not Ability.IsCastable(order.ability, NPC.GetMana(hero)) then
        return true
    end

    local player = order.player or Players.GetLocal()
    local cursor = Input.GetWorldCursorPos()
    if not player or not cursor then
        return true
    end

    local moved = issue_direction_move(player, hero, cursor)
    if not moved then
        return true
    end

    local now = GameRules.GetGameTime()
    local tick = math.max(GlobalVars.GetIntervalPerTick(), 0.01)
    local turn_time = math.max(safe_number(NPC.GetTimeToFacePosition, hero, cursor), 0)

    pending_cast = {
        hero = hero,
        ability = order.ability,
        cursor = cursor:Clone(),
        execute_at = now + math.max(turn_time + tick, tick),
        deadline = now + turn_time + 0.30
    }

    -- Replace the original self-cast with direction move -> delayed self-cast.
    return false
end

function script.OnUpdate()
    if not pending_cast then
        return
    end

    if not ui.enabled:Get() or not ui.auto_direction:Get() then
        clear_pending_cast()
        return
    end

    local hero = get_local_snapfire(true)
    if not hero or hero ~= pending_cast.hero then
        clear_pending_cast()
        return
    end

    local cookie = get_cookie(hero)
    if not cookie or cookie ~= pending_cast.ability then
        clear_pending_cast()
        return
    end

    if not Ability.IsCastable(cookie, NPC.GetMana(hero)) then
        clear_pending_cast()
        return
    end

    local now = GameRules.GetGameTime()
    if now < pending_cast.execute_at then
        return
    end

    local tick = math.max(GlobalVars.GetIntervalPerTick(), 0.01)
    local face_time = math.max(
        safe_number(NPC.GetTimeToFacePosition, hero, pending_cast.cursor),
        0
    )

    -- Normally cast as soon as the turn is complete. The deadline prevents a
    -- permanent pending state if the reported turn time never reaches zero.
    if face_time > tick * 1.5 and now < pending_cast.deadline then
        return
    end

    clear_pending_cast()
    Ability.CastTarget(cookie, hero, false, false, true, ORDER_ID)
end

function script.OnDraw()
    if not ui.enabled:Get() or not ui.predictor:Get() then
        return
    end

    local hero = get_local_snapfire(true)
    if not hero then
        return
    end

    local cookie = get_cookie(hero)
    if not cookie or Ability.GetLevel(cookie) <= 0 then
        return
    end

    local hop_distance, impact_radius = get_cached_ability_stats(hero, cookie)

    local aim_position
    if pending_cast and pending_cast.hero == hero then
        aim_position = pending_cast.cursor
    elseif ui.auto_direction:Get() then
        aim_position = Input.GetWorldCursorPos()
    else
        -- Without cursor direction, a self Cookie follows Snapfire's facing.
        local origin = Entity.GetAbsOrigin(hero)
        aim_position = origin:MoveForward(Entity.GetRotation(hero), 100)
    end

    local landing = get_landing_position(hero, hop_distance, aim_position)
    if not landing then
        return
    end

    local ready = Ability.IsCastable(cookie, NPC.GetMana(hero))
    local landing_color = ready and COLOR_READY or COLOR_NOT_READY

    local landing_screen, landing_visible = Render.WorldToScreen(landing)
    if landing_visible then
        Render.FilledCircle(landing_screen, 5, landing_color)
        Render.Circle(landing_screen, 9, landing_color, 2.0)
    end

    if ui.draw_impact:Get() then
        draw_world_circle(landing, impact_radius, landing_color, 2.0)
    end
end

return script
