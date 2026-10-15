---@diagnostic disable: undefined-global, param-type-mismatch

-- Zeus Heavenly Jump helper for UCZone API v2.0.
-- The ring shows LEAP DISTANCE, not Heavenly Jump's larger shock range.

local script = {}

local HERO_NAME = "npc_dota_hero_zuus"
local JUMP_NAME = "zuus_heavenly_jump"
local TARGET_TALENT_NAME = "special_bonus_unique_zeus"

-- Hardcoded current Heavenly Jump values for ability levels 1-4.
local LEAP_DISTANCES = { 375, 450, 525, 600 }
local SHOCK_RANGES = { 700, 800, 900, 1000 }

-- Logic is throttled independently from rendering.
local ABILITY_UPDATE_INTERVAL = 0.25
local TARGET_UPDATE_INTERVAL = 0.05

local RADIUS_SEGMENTS = 40
local RADIUS_Z_OFFSET = 10
local RADIUS_OUTLINE_COLOR = Color(10, 20, 30, 210)
local RADIUS_COLOR = Color(75, 185, 255, 235)

-- Unit-circle trigonometry is calculated once when the script is loaded.
local circle_cos = {}
local circle_sin = {}
local radius_screen_points = {}
local radius_visibility = {}
for i = 0, RADIUS_SEGMENTS do
    local angle = (i / RADIUS_SEGMENTS) * math.pi * 2
    circle_cos[i + 1] = math.cos(angle)
    circle_sin[i + 1] = math.sin(angle)
end

local LIGHTNING_SIZE = Vec2(18, 24)
local LIGHTNING_COLOR = Color(255, 255, 255, 255)
local LIGHTNING_SVG = [[
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 18 24">
  <path d="M10.8 1 2.4 13.2h5.1L6.2 23l9.4-13.4h-5.2L10.8 1Z"
        fill="#FFD43B" stroke="#4B3500" stroke-width="1.25"
        stroke-linejoin="round"/>
</svg>
]]

-- A unique cache id makes UCZone create the texture only once.
local lightning_icon = Render.LoadSvgString(
    LIGHTNING_SVG,
    LIGHTNING_SIZE,
    "zeus_heavenly_jump_target_v2"
)

-- Menu -----------------------------------------------------------------------

local group = Menu.Create(
    "General",
    "Main",
    "Zeus Heavenly Jump",
    "Visuals",
    "Main"
)

local enabled = group:Switch(
    "Show leap radius and affected target",
    true,
    "panorama/images/spellicons/zuus_heavenly_jump_png.vtex_c"
)

-- Runtime state ---------------------------------------------------------------

local state = {
    hero = nil,
    jump = nil,
    target_talent = nil,

    level = 0,
    leap_distance = 0,
    shock_range = 0,
    max_targets = 1,

    targets = {},

    -- Reused candidate buffers avoid per-scan tables and table.sort.
    hero_candidates = {},
    hero_distances = {},
    basic_candidates = {},
    basic_distances = {},

    next_ability_update = -math.huge,
    next_target_update = -math.huge,
}

local function clear_array(array)
    for i = #array, 1, -1 do
        array[i] = nil
    end
end

local function clear_targets()
    clear_array(state.targets)
    clear_array(state.hero_candidates)
    clear_array(state.hero_distances)
    clear_array(state.basic_candidates)
    clear_array(state.basic_distances)
end

local function reset_state()
    clear_targets()

    state.hero = nil
    state.jump = nil
    state.target_talent = nil
    state.level = 0
    state.leap_distance = 0
    state.shock_range = 0
    state.max_targets = 1
    state.next_ability_update = -math.huge
    state.next_target_update = -math.huge
end

local function distance_sq_2d(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    return dx * dx + dy * dy
end

local function is_valid_jump_target(unit)
    if not unit
        or not Entity.IsAlive(unit)
        or Entity.IsDormant(unit)
        or not NPC.IsVisible(unit)
        or NPC.IsWaitingToSpawn(unit)
        or NPC.IsWard(unit)
        or NPC.IsStructure(unit)
    then
        return false
    end

    if not NPC.IsHero(unit)
        and not NPC.IsConsideredHero(unit)
        and not NPC.IsCreep(unit)
        and not NPC.IsCourier(unit)
    then
        return false
    end

    -- Heavenly Jump does not affect debuff-immune or untargetable units.
    return not NPC.HasState(unit, Enum.ModifierState.MODIFIER_STATE_MAGIC_IMMUNE)
        and not NPC.HasState(unit, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE)
        and not NPC.HasState(unit, Enum.ModifierState.MODIFIER_STATE_OUT_OF_GAME)
        and not NPC.HasState(unit, Enum.ModifierState.MODIFIER_STATE_UNTARGETABLE)
        and not NPC.HasState(unit, Enum.ModifierState.MODIFIER_STATE_UNTARGETABLE_ENEMY)
end

local function insert_nearest(entities, distances, unit, distance, limit)
    local count = #entities
    local insert_at = count + 1

    for i = 1, count do
        if distance < distances[i] then
            insert_at = i
            break
        end
    end

    if insert_at > limit then
        return
    end

    local last = math.min(count + 1, limit)
    for i = last, insert_at + 1, -1 do
        entities[i] = entities[i - 1]
        distances[i] = distances[i - 1]
    end

    entities[insert_at] = unit
    distances[insert_at] = distance
end

local function update_ability_values()
    local jump = state.jump
    if not jump then
        state.level = 0
        state.leap_distance = 0
        state.shock_range = 0
        state.max_targets = 1
        clear_targets()
        return
    end

    local level = Ability.GetLevel(jump)
    local leap_distance = LEAP_DISTANCES[level] or 0
    local shock_range = SHOCK_RANGES[level] or 0

    if not state.target_talent then
        state.target_talent = NPC.GetAbility(state.hero, TARGET_TALENT_NAME)
    end

    local max_targets = 1
    local target_talent = state.target_talent
    if target_talent and Ability.GetLevel(target_talent) > 0 then
        max_targets = 2
    end

    local targeting_changed = state.shock_range ~= shock_range
        or state.max_targets ~= max_targets

    state.level = level
    state.leap_distance = leap_distance
    state.shock_range = shock_range
    state.max_targets = max_targets

    if targeting_changed then
        state.next_target_update = -math.huge
    end
end

local function update_targets()
    clear_targets()

    local hero = state.hero
    local radius = state.shock_range
    if not hero or radius <= 0 then
        return
    end

    -- API spatial query is cheaper than traversing the complete NPC list.
    local units = Entity.GetUnitsInRadius(
        hero,
        radius,
        Enum.TeamType.TEAM_ENEMY,
        false,
        true
    )

    if not units or #units == 0 then
        return
    end

    local origin = Entity.GetAbsOrigin(hero)
    local limit = state.max_targets

    for i = 1, #units do
        local unit = units[i]
        if is_valid_jump_target(unit) then
            local distance = distance_sq_2d(
                origin,
                Entity.GetAbsOrigin(unit)
            )

            if NPC.IsHero(unit) or NPC.IsConsideredHero(unit) then
                insert_nearest(
                    state.hero_candidates,
                    state.hero_distances,
                    unit,
                    distance,
                    limit
                )
            else
                insert_nearest(
                    state.basic_candidates,
                    state.basic_distances,
                    unit,
                    distance,
                    limit
                )
            end
        end
    end

    -- Heavenly Jump prioritizes heroes, then fills remaining target slots with
    -- the nearest valid basic units.
    local target_count = 0
    for i = 1, math.min(limit, #state.hero_candidates) do
        target_count = target_count + 1
        state.targets[target_count] = state.hero_candidates[i]
    end

    local remaining = limit - target_count
    for i = 1, math.min(remaining, #state.basic_candidates) do
        target_count = target_count + 1
        state.targets[target_count] = state.basic_candidates[i]
    end
end

local function draw_lightning(target)
    if not target
        or not Entity.IsAlive(target)
        or Entity.IsDormant(target)
        or not NPC.IsVisible(target)
    then
        return
    end

    local world_position = Entity.GetAbsOrigin(target)
        + Vector(0, 0, NPC.GetHealthBarOffset(target) + 24)
    local screen_position, on_screen = Render.WorldToScreen(world_position)

    if not on_screen then
        return
    end

    Render.ImageCentered(
        lightning_icon,
        screen_position,
        LIGHTNING_SIZE,
        LIGHTNING_COLOR
    )
end

local function draw_leap_radius()
    local hero = state.hero
    local radius = state.leap_distance
    if not hero or radius <= 0 then
        return
    end

    local origin = Entity.GetAbsOrigin(hero)
    local point_count = #circle_cos
    local all_visible = true

    for i = 1, point_count do
        local x = origin.x + circle_cos[i] * radius
        local y = origin.y + circle_sin[i] * radius
        local world_position = Vector(
            x,
            y,
            World.GetGroundZ(x, y) + RADIUS_Z_OFFSET
        )
        local screen_position, visible = Render.WorldToScreen(world_position)

        radius_screen_points[i] = screen_position
        radius_visibility[i] = visible
        if not visible then
            all_visible = false
        end
    end

    -- Most of the time the full circle is on-screen, so two PolyLine calls draw
    -- it instead of issuing a separate pair of draw calls for every segment.
    if all_visible then
        Render.PolyLine(radius_screen_points, RADIUS_OUTLINE_COLOR, 4.0)
        Render.PolyLine(radius_screen_points, RADIUS_COLOR, 2.0)
        return
    end

    -- When the circle crosses a screen edge, draw only visible segments.
    for i = 2, point_count do
        if radius_visibility[i - 1] and radius_visibility[i] then
            Render.Line(
                radius_screen_points[i - 1],
                radius_screen_points[i],
                RADIUS_OUTLINE_COLOR,
                4.0
            )
            Render.Line(
                radius_screen_points[i - 1],
                radius_screen_points[i],
                RADIUS_COLOR,
                2.0
            )
        end
    end
end

-- Callbacks ------------------------------------------------------------------

function script.OnUpdate()
    if not enabled:Get() then
        if state.hero or #state.targets > 0 then
            reset_state()
        end
        return
    end

    local hero = state.hero
    if not hero then
        hero = Heroes.GetLocal()
        state.hero = hero
    end

    if not hero or NPC.GetUnitName(hero) ~= HERO_NAME then
        if state.hero or #state.targets > 0 then
            reset_state()
        end
        return
    end

    if not Entity.IsAlive(hero) then
        clear_targets()
        return
    end

    if not state.jump then
        state.jump = NPC.GetAbility(hero, JUMP_NAME)
        state.target_talent = NPC.GetAbility(hero, TARGET_TALENT_NAME)
        state.next_ability_update = -math.huge
        state.next_target_update = -math.huge
    end

    if not state.jump then
        clear_targets()
        return
    end

    local now = GlobalVars.GetCurTime()

    if now >= state.next_ability_update then
        update_ability_values()
        state.next_ability_update = now + ABILITY_UPDATE_INTERVAL
    end

    if now >= state.next_target_update then
        update_targets()
        state.next_target_update = now + TARGET_UPDATE_INTERVAL
    end
end

function script.OnDraw()
    if not enabled:Get()
        or not state.hero
        or not Entity.IsAlive(state.hero)
    then
        return
    end

    draw_leap_radius()

    for i = 1, #state.targets do
        draw_lightning(state.targets[i])
    end
end

function script.OnGameEnd()
    reset_state()
end

return script
