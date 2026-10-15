---@diagnostic disable: undefined-global, param-type-mismatch, inject-field

local ck = {}

-- Chaos Knight script variables
ck._last_attack_time = ck._last_attack_time or 0
ck._cursor_target_pos = ck._cursor_target_pos or nil
ck._cursor_move_start_time = ck._cursor_move_start_time or 0

-- Combo Settings
local COMBO_SETTINGS = {
    ATTACK_REATTACK_DELAY = 0.25,  -- Wait for crit to appear
    CURSOR_MOVE_SPEED = 0.3,      -- Speed of cursor movement
    CURSOR_SMOOTH_TIME = 0.2,     -- Time to smooth cursor movement
    ANTI_SPAM_DELAY = 0.3         -- Minimum time between stop commands
}

-- Helper functions
local function get_game_time()
    if GameRules and GameRules.GetGameTime then
        return GameRules.GetGameTime()
    end
    return 0
end

local function get_entity_key(ent)
    if ent and Entity.GetIndex then
        return "ck_" .. tostring(Entity.GetIndex(ent))
    end
    return "ck_unknown"
end

local function safe_call(func, ...)
    local ok, result = pcall(func, ...)
    if ok then
        return result
    end
    return nil
end

-- UI Menu
local ui = {}
local combo_group = nil
local items_group = nil

if Menu.Create then
    local tab = Menu.Create("Heroes", "Hero List", "Chaos Knight")
    if tab and tab.Create then
        local section = tab:Create("Chaos Knight")
        if section and section.Create then
            combo_group = section:Create("Комбо")
            items_group = section:Create("Предметы")
        end
    end
end

local has_combo_group = combo_group and combo_group.Switch
local has_items_group = items_group and items_group.Label

if has_combo_group then
    ui.crit_enabled = combo_group:Switch("Вечный крит", false)
    ui.debug_enabled = combo_group:Switch("Отладка", false)

    if has_items_group then
        items_group:Label("Создатель: kryzz")
    end
else
    ui.crit_enabled = { Get = function() return false end }
    ui.debug_enabled = { Get = function() return false end }
end

-- Variables
local myHero = nil
local isCK = false
local CHAOS_STRIKE_MOD = "modifier_chaos_knight_chaos_strike"
local crit_modifier_time = 0
local reattack_timer = 0
local last_stop_time = 0  -- Anti-spam protection

-- Helper functions
local function update_hero()
    myHero = Heroes.GetLocal()
    if myHero then
        local name = NPC.GetUnitName(myHero)
        isCK = (name == "npc_dota_hero_chaos_knight")
    end
end

local function debug_print(message)
    if ui.debug_enabled and ui.debug_enabled.Get and ui.debug_enabled:Get() then
        print("[CK] " .. message)
    end
end

local function get_enemies_in_range(range)
    if not myHero then return {} end
    local heroes = safe_call(Heroes.GetAll)
    if not heroes then return {} end

    local my_pos = safe_call(Entity.GetAbsOrigin, myHero)
    if not my_pos then return {} end

    local my_team = safe_call(Entity.GetTeamNum, myHero)
    if not my_team then return {} end

    local enemies = {}
    for _, hero in pairs(heroes) do
        if hero and hero ~= myHero and safe_call(Entity.IsAlive, hero) then
            local hero_team = safe_call(Entity.GetTeamNum, hero)
            if hero_team and hero_team ~= my_team then
                local hero_pos = safe_call(Entity.GetAbsOrigin, hero)
                if hero_pos then
                    local dist = (my_pos - hero_pos):Length2D()
                    if dist <= range then
                        table.insert(enemies, hero)
                    end
                end
            end
        end
    end

    return enemies
end

local function get_smooth_cursor_position()
    if not ck._cursor_target_pos or not myHero then
        return safe_call(Input.GetWorldCursorPos)
    end

    local now = get_game_time()
    local elapsed = now - ck._cursor_move_start_time

    if elapsed >= COMBO_SETTINGS.CURSOR_SMOOTH_TIME then
        return ck._cursor_target_pos
    end

    local progress = elapsed / COMBO_SETTINGS.CURSOR_SMOOTH_TIME
    local cursor_pos = safe_call(Input.GetWorldCursorPos)

    if cursor_pos and ck._cursor_target_pos then
        local smooth_pos = cursor_pos + (ck._cursor_target_pos - cursor_pos) * progress
        return smooth_pos
    end

    return cursor_pos
end

local function stop_attack()
    if not myHero or not Players or not Players.GetLocal then
        return
    end

    local now = get_game_time()
    if now - ck._last_attack_time < COMBO_SETTINGS.ATTACK_REATTACK_DELAY then
        return
    end

    local player = safe_call(Players.GetLocal)
    if not player then
        return
    end

    -- Set smooth cursor movement towards target
    local enemies = get_enemies_in_range(1000)
    if #enemies > 0 then
        local closest = nil
        local closest_dist = math.huge
        local cursor_pos = safe_call(Input.GetWorldCursorPos)

        if cursor_pos then
            for _, enemy in pairs(enemies) do
                local enemy_pos = safe_call(Entity.GetAbsOrigin, enemy)
                if enemy_pos then
                    local dist = (cursor_pos - enemy_pos):Length2D()
                    if dist < closest_dist then
                        closest_dist = dist
                        closest = enemy
                    end
                end
            end

            if closest then
                local enemy_pos = safe_call(Entity.GetAbsOrigin, closest)
                if enemy_pos then
                    ck._cursor_target_pos = enemy_pos
                    ck._cursor_move_start_time = now
                end
            end
        end
    end

    reattack_timer = now + COMBO_SETTINGS.ATTACK_REATTACK_DELAY
    ck._last_attack_time = now

    debug_print("STOP ATTACK CALLED")

    Player.PrepareUnitOrders(
        player,
        Enum.UnitOrder.DOTA_UNIT_ORDER_STOP,
        nil,
        Vector(0, 0, 0),
        nil,
        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_CURRENT_UNIT_ONLY,
        myHero
    )
end

local function try_reattack()
    if not reattack_timer or reattack_timer == 0 then
        return
    end

    local now = get_game_time()
    if now < reattack_timer then
        return
    end

    if not myHero or not Players or not Players.GetLocal then
        reattack_timer = 0
        return
    end

    local player = safe_call(Players.GetLocal)
    if not player then
        reattack_timer = 0
        return
    end

    local smooth_pos = get_smooth_cursor_position()
    if smooth_pos then
        debug_print("REATTACK - Smooth position")

        Player.PrepareUnitOrders(
            player,
            Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_MOVE,
            nil,
            smooth_pos,
            nil,
            Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_CURRENT_UNIT_ONLY,
            myHero
        )
    end

    reattack_timer = 0
    ck._cursor_target_pos = nil
    ck._cursor_move_start_time = 0
end

-- Callbacks
function ck.OnModifierCreate(ent, mod)
    update_hero()

    if not isCK or not myHero or not ui.crit_enabled or not ui.crit_enabled.Get or not ui.crit_enabled:Get() then
        return
    end

    if ent ~= myHero or not Modifier or not Modifier.GetName then
        return
    end

    local name = safe_call(Modifier.GetName, mod)
    if name == CHAOS_STRIKE_MOD then
        crit_modifier_time = get_game_time()
        debug_print("CRIT MODIFIER DETECTED")
    end
end

function ck.OnUpdate()
    update_hero()
    try_reattack()
end

function ck.OnUnitAnimation(anim)
    update_hero()

    if not isCK or not myHero or not ui.crit_enabled or not ui.crit_enabled.Get or not ui.crit_enabled:Get() then
        return
    end

    if not anim or anim.unit ~= myHero then
        return
    end

    local seq = anim.sequenceName or ""

    debug_print("Animation: " .. seq)

    if seq:lower():find("attack") then
        local now = get_game_time()
        debug_print("DEBUG: Attack animation detected, now = " .. string.format("%.3f", now))

        -- Anti-spam protection
        if now - last_stop_time < COMBO_SETTINGS.ANTI_SPAM_DELAY then
            debug_print("DEBUG: ANTI-SPAM - recently stopped, skipping")
            return
        end

        -- Check for crit IMMEDIATELY
        local is_crit_anim = seq:lower():find("crit") or seq:lower():find("critical")
        local has_crit_mod = (now - crit_modifier_time) < 0.15

        local has_crit = is_crit_anim or has_crit_mod

        debug_print("DEBUG: is_crit_anim = " .. tostring(is_crit_anim))
        debug_print("DEBUG: has_crit_mod = " .. tostring(has_crit_mod))
        debug_print("DEBUG: crit_modifier_time = " .. string.format("%.3f", crit_modifier_time))
        debug_print("DEBUG: time since last stop = " .. string.format("%.3f", now - last_stop_time))
        debug_print("Attack detected - Crit anim: " .. tostring(is_crit_anim) .. ", Crit mod: " .. tostring(has_crit_mod) .. ", Has crit: " .. tostring(has_crit))

        if not has_crit then
            debug_print("DEBUG: NO CRIT DETECTED - calling stop_attack() IMMEDIATELY")
            stop_attack()
            last_stop_time = now
        else
            debug_print("DEBUG: CRIT DETECTED - allowing attack")
            crit_modifier_time = 0
        end
    else
        debug_print("DEBUG: Not attack animation")
    end
end

return ck
