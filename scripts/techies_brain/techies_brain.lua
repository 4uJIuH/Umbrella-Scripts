--[[
    Techies Brain — Unified Combo Controller
    Version: 0.2.6 — Hex Lock / BKB Punish Timing

    Goal:
      Make THIS Brain the single owner of Techies' normal combo:
        Hex -> Sticky Bomb -> Reactive Tazer -> Ethereal Blade
        -> Blast Off toward predicted target
        -> verified Proximity Mines
        -> M.A.D. / optional Detonate

    Design:
      - Asynchronous state machine; one controller owns every combo order.
      - IMPORTANT: disable/unbind the older/native Techies combo while testing.
        Two combo controllers issuing orders on the same key can cancel/reorder casts.
      - Hex is early control; Ethereal Blade is intentionally the LAST setup item
        before Blast Off so its amplification window is preserved for the burst.
      - Spell/item setup casts are verified by cooldown/state evidence where practical.
      - Proximity Mines are counted from global charge truth, including delayed acceptance.
      - Blast Off must be positively confirmed; timing fallback no longer starts mines.
      - Live Ability.GetCastRange values are logged so Aether Lens / cast-range
        behavior can be validated from the actual runtime rather than hardcoded.
      - Blink / Force Staff remain intentionally excluded from v0.2.0.

    UCZone/API evidence policy:
      - External UCZone calls in this build are limited to calls supported by the
        official UCZone API v2.0 documentation, the supplied Observatory evidence,
        or the runtime-proven Lina.lua pattern.
      - No undocumented compatibility fallbacks are retained.
      - Timing constants and target prediction are OUR LOGIC, not UCZone facts.
      - The mine formation is frozen around the committed Blast Off anchor so moving
        targets cannot drag Mine #2/#3 away after Techies has already committed.
--]]

local techies = {}

-- ============================================================================
-- Constants
-- ============================================================================

local HERO_NAME = "npc_dota_hero_techies"

local ABILITY_STICKY = "techies_sticky_bomb"
local ABILITY_TAZER  = "techies_reactive_tazer"
local ABILITY_TAZER_STOP = "techies_reactive_tazer_stop" -- RUNTIME_OBSERVED sub-ability
local ABILITY_BLAST  = "techies_suicide" -- RUNTIME_OBSERVED: Blast Off
local ABILITY_MAD    = "techies_mutually_assured_destruction" -- RUNTIME_OBSERVED: M.A.D.
local ABILITY_MINES  = "techies_land_mines" -- RUNTIME_OBSERVED: Proximity Mines
local ABILITY_MAD_DETONATE = "techies_focused_detonate" -- RUNTIME_OBSERVED candidate; validated only when it becomes leveled/ready after M.A.D. placement

-- RUNTIME_OBSERVED through the existing Techies combo supplied by the user.
local ITEM_HEX = "item_sheepstick"
local ITEM_EBLADE = "item_ethereal_blade"
local ITEM_AETHER_LENS = "item_aether_lens" -- passive only; used for diagnostics, never cast

local STATE = {
    IDLE = "IDLE",
    HEX = "HEX",
    WAIT_HEX = "WAIT_HEX",
    STICKY = "STICKY",
    WAIT_AFTER_STICKY = "WAIT_AFTER_STICKY",
    TAZER = "TAZER",
    WAIT_AFTER_TAZER = "WAIT_AFTER_TAZER",
    EBLADE = "EBLADE",
    WAIT_EBLADE = "WAIT_EBLADE",
    BLAST = "BLAST",
    WAIT_AIRBORNE = "WAIT_AIRBORNE",
    AIRBORNE_MINES = "AIRBORNE_MINES",
    POST_LAND_MINES = "POST_LAND_MINES",
    TAZER_DETONATE = "TAZER_DETONATE",
    MAD = "MAD",
    COMPLETE = "COMPLETE",
    ABORT = "ABORT",
}

-- ============================================================================
-- Menu
-- ============================================================================
--
-- Umbrella hero-menu integration follows the same pattern used by Lina.lua:
--
--   Heroes > Hero List > Techies > Brain > <group>
--
-- Menu.Find-then-Create is intentional. On script reload Umbrella may already
-- have instantiated these menu nodes; reusing them avoids duplicate-Create
-- errors and keeps this companion script inside the existing Techies hero UI
-- instead of creating a separate General/TechiesPredictiveCombo tree.
--

local TECHIES_MENU = "Techies"
local TECHIES_BRAIN_TAB = "Brain"

local function MenuGroup(name)
    local existing = nil

    if Menu and Menu.Find then
        local ok, result = pcall(
            Menu.Find,
            "Heroes",
            "Hero List",
            TECHIES_MENU,
            TECHIES_BRAIN_TAB,
            name
        )
        if ok then
            existing = result
        end
    end

    if existing then
        return existing
    end

    return Menu.Create(
        "Heroes",
        "Hero List",
        TECHIES_MENU,
        TECHIES_BRAIN_TAB,
        name
    )
end

local main_group = MenuGroup("Core")
local ui_enable = main_group:Switch("Enable Techies brain", true)
local ui_combo_key = main_group:Bind("Combo Key", Enum.ButtonCode.KEY_NONE)
local ui_target_mode = main_group:Combo(
    "Target Priority",
    {"Closest to Cursor", "Closest to Techies"},
    0
)
local ui_max_target_range = main_group:Slider(
    "Max Start Distance",
    400,
    1600,
    1050,
    function(v) return tostring(v) .. " units" end
)

local spell_group = MenuGroup("Combo")
local ui_use_hex = spell_group:Switch("Use Hex before setup", true)
local ui_use_sticky = spell_group:Switch("Use Sticky Bomb", true)
local ui_use_tazer = spell_group:Switch("Use Reactive Tazer", true)
local ui_auto_detonate_tazer = spell_group:Switch("Detonate Reactive Tazer after Mines", true)
local ui_tazer_detonate_radius = spell_group:Slider(
    "Tazer Detonate Target Radius",
    250,
    500,
    390,
    function(v) return tostring(v) .. " units" end
)
local ui_use_eblade = spell_group:Switch("Use Ethereal Blade before Blast", true)
local ui_mine_count = spell_group:Slider(
    "Mine Count",
    1,
    3,
    3,
    function(v) return tostring(v) end
)
local ui_use_mad = spell_group:Switch("Use M.A.D. (Shard active)", true)
local ui_auto_detonate_mad = spell_group:Switch("Auto Detonate M.A.D.", true)
local ui_post_land_fallback = spell_group:Switch(
    "Post-land Mine Fallback",
    true
)

local timing_group = MenuGroup("Timing")
local ui_setup_verify_ms = timing_group:Slider(
    "Setup Cast Verify Window",
    150,
    900,
    450,
    function(v) return tostring(v) .. " ms" end
)
local ui_airborne_detect_distance = timing_group:Slider(
    "Airborne Detect Distance",
    10,
    160,
    45,
    function(v) return tostring(v) .. " units" end
)
local ui_airborne_fallback_ms = timing_group:Slider(
    "Blast Confirm Timeout",
    300,
    1600,
    1400,
    function(v) return tostring(v) .. " ms" end
)
local ui_air_window_ms = timing_group:Slider(
    "Estimated Airborne Window",
    250,
    1200,
    700,
    function(v) return tostring(v) .. " ms" end
)
local ui_mine_gap_ms = timing_group:Slider(
    "Minimum Mine Cast Gap",
    30,
    350,
    110,
    function(v) return tostring(v) .. " ms" end
)
local ui_post_land_window_ms = timing_group:Slider(
    "Post-land Fallback Window",
    100,
    1500,
    700,
    function(v) return tostring(v) .. " ms" end
)

-- Hex-lock timing guard. These are GAME-MECHANIC timing constants / our logic,
-- not UCZone API facts. Scythe currently Hexes for 2.8s; Blast Off leap is
-- 0.75s. Blast cast point itself is read live through the already-validated
-- Ability.GetCastPoint call. Keep the duration slider adjustable for status
-- resistance or future balance changes rather than pretending we can read a
-- modifier duration through an unverified API.
local ui_protect_hex_chain = timing_group:Switch(
    "Protect Hex -> Blast Lock",
    true
)
local ui_hex_control_window_ms = timing_group:Slider(
    "Hex Control Window",
    1000,
    3500,
    2800,
    function(v) return tostring(v) .. " ms" end
)
local ui_blast_leap_ms = timing_group:Slider(
    "Blast Off Leap Time",
    500,
    1100,
    750,
    function(v) return tostring(v) .. " ms" end
)
local ui_hex_chain_safety_ms = timing_group:Slider(
    "Hex -> Blast Safety Margin",
    50,
    500,
    175,
    function(v) return tostring(v) .. " ms" end
)

local prediction_group = MenuGroup("Prediction")
local ui_predict_target = prediction_group:Switch(
    "Predict Target Movement",
    true
)
local ui_velocity_smoothing = prediction_group:Slider(
    "Velocity Smoothing",
    10,
    90,
    45,
    function(v) return tostring(v) .. "%" end
)
local ui_max_prediction_speed = prediction_group:Slider(
    "Max Predicted Target Speed",
    250,
    1000,
    650,
    function(v) return tostring(v) .. " u/s" end
)
local ui_max_prediction_horizon_ms = prediction_group:Slider(
    "Max Prediction Horizon",
    100,
    1500,
    900,
    function(v) return tostring(v) .. " ms" end
)

local mine_group = MenuGroup("Mine Geometry")
local ui_mine_ring_radius = mine_group:Slider(
    "Mine Ring Radius",
    120,
    420,
    220,
    function(v) return tostring(v) .. " units" end
)
local ui_forward_bias = mine_group:Slider(
    "Escape Direction Bias",
    0,
    250,
    80,
    function(v) return tostring(v) .. " units" end
)

local debug_group = MenuGroup("Diagnostics")
local ui_debug_overlay = debug_group:Switch("Prediction Overlay", true)
local ui_debug_log = debug_group:Switch("Event Log", true)

-- If this line appears, all menu widgets above were constructed successfully.
print("[TECHIES_EVT] LOAD_OK | version=0.2.6-hex-lock-timing")
print("[TECHIES_EVT] UNIFIED_NOTICE | disable/unbind the older/native Techies combo while testing v0.2.6")

-- ============================================================================
-- Runtime state
-- ============================================================================

local combo = {
    active = false,
    state = STATE.IDLE,
    state_started = 0.0,
    combo_started = 0.0,

    hero = nil,
    target = nil,

    pending_setup = nil,
    setup_retries = nil,
    hex_confirmed = false,
    hex_order_time = nil,
    hex_confirm_time = nil,
    hex_deadline = nil,
    sticky_confirmed = false,
    tazer_confirmed = false,
    tazer_detonate_attempted = false,
    tazer_detonate_attempts = 0,
    tazer_detonate_pending = nil,
    tazer_detonate_confirmed = false,
    eblade_confirmed = false,

    blast_order_time = nil,
    blast_start_pos = nil,
    blast_anchor = nil,
    blast_ability = nil,
    blast_cd_before = nil,
    blast_since_before = nil,
    blast_phase_seen = false,
    blast_confirmed = false,
    blast_motion_without_confirm_logged = false,
    airborne_start = nil,
    predicted_land_time = nil,
    mine_plan = nil,

    -- IMPORTANT: mines_placed means CONFIRMED charge consumption, not merely
    -- "Ability.CastPosition returned without throwing".
    mines_placed = 0,
    desired_mines = 0,
    mine_charges_start = nil,
    last_mine_attempt = -999.0,
    last_mine_confirmed = -999.0,
    pending_mine = nil,
    mine_progress_deadline = nil,
    confirmed_mine_positions = nil,
    last_mine_wait_log = -999.0,
    last_mine_wait_distance = nil,
    last_mine_wait_number = nil,

    mad_attempted = false,
    mad_retry_count = 0,
    mad_pending = nil,
    mad_confirmed = false,
    mad_detonate_attempted = false,

    last_reason = "",
}

local motion = {
    target = nil,
    last_pos = nil,
    last_time = nil,
    vx = 0.0,
    vy = 0.0,
    initialized = false,
}

-- Runtime-proven Lina pattern: poll CMenuBind:IsDown() each tick and maintain
-- our own rising-edge latch.
local combo_key_was_down = false
local ability_probe_done = false


-- ============================================================================
-- Safe helpers
-- ============================================================================

local function SafeCall(fn, ...)
    if not fn then return nil, false end
    local ok, result = pcall(fn, ...)
    if not ok then return nil, false end
    return result, true
end

-- RUNTIME-PROVEN in the supplied Lina brain.
local function KeyDown(widget)
    if not widget then return false end
    local ok, value = pcall(widget.IsDown, widget)
    return (ok and value) and true or false
end

local function Now()
    local v, ok = SafeCall(GameRules.GetGameTime)
    if ok and type(v) == "number" then return v end
    return 0.0
end

local function NewVec(x, y, z)
    -- VERIFIED API/example type: UCZone uses Vector for world-space positions.
    return Vector(x, y, z or 0)
end

local function GetPos(ent)
    if not ent then return nil end
    local pos, ok = SafeCall(Entity.GetAbsOrigin, ent)
    if ok and pos then return pos end
    return nil
end

local function GetLocalHero()
    local hero, ok = SafeCall(Heroes.GetLocal)
    if ok then return hero end
    return nil
end

local function IsAlive(ent)
    if not ent or not Entity or not Entity.IsAlive then return false end
    local v, ok = SafeCall(Entity.IsAlive, ent)
    return ok and v == true
end

local function UnitName(ent)
    if not ent or not NPC or not NPC.GetUnitName then return "<unknown>" end
    local v, ok = SafeCall(NPC.GetUnitName, ent)
    if ok and v then return v end
    return "<unknown>"
end

local function TeamNum(ent)
    if not ent then return nil end
    local v, ok = SafeCall(Entity.GetTeamNum, ent)
    if ok then return v end
    return nil
end

local function IsIllusion(ent)
    if NPC and NPC.IsIllusion then
        local v, ok = SafeCall(NPC.IsIllusion, ent)
        return ok and v == true
    end
    return false
end

local function Dist2D(a, b)
    if not a or not b then return math.huge end
    local dx = (a.x or 0) - (b.x or 0)
    local dy = (a.y or 0) - (b.y or 0)
    return math.sqrt(dx * dx + dy * dy)
end

local function Normalize2D(x, y)
    local len = math.sqrt(x * x + y * y)
    if len < 0.001 then return 1.0, 0.0 end
    return x / len, y / len
end

local function Rotate2D(x, y, angle)
    local c = math.cos(angle)
    local s = math.sin(angle)
    return x * c - y * s, x * s + y * c
end

local function Emit(event, detail)
    if not ui_debug_log:Get() then return end
    local line = "[TECHIES_EVT] " .. tostring(event)
    if detail and detail ~= "" then
        line = line .. " | " .. tostring(detail)
    end

    if Log and Log.Write then
        pcall(Log.Write, line)
    else
        print(line)
    end
end

local debug_font = nil

local function GetDebugFont()
    if debug_font then return debug_font end
    local font, ok = SafeCall(Render.LoadFont, "Arial", 0, 500)
    if ok and font then
        debug_font = font
    end
    return debug_font
end

-- ============================================================================
-- Target selection
-- ============================================================================

local function GetCursorWorld()
    local pos, ok = SafeCall(Input.GetWorldCursorPos)
    if ok then return pos end
    return nil
end

local function FindTarget(hero)
    if not hero then return nil end

    local hero_pos = GetPos(hero)
    if not hero_pos then return nil end

    local my_team = TeamNum(hero)
    local cursor = GetCursorWorld()

    local list = nil
    if Heroes and Heroes.GetAll then
        local v, ok = SafeCall(Heroes.GetAll)
        if ok then list = v end
    end

    if not list then return nil end

    local mode = ui_target_mode:Get()
    local best = nil
    local best_score = math.huge
    local max_range = ui_max_target_range:Get()

    for _, enemy in pairs(list) do
        if enemy
            and enemy ~= hero
            and IsAlive(enemy)
            and not IsIllusion(enemy)
        then
            local their_team = TeamNum(enemy)
            if my_team == nil or their_team == nil or their_team ~= my_team then
                local pos = GetPos(enemy)
                if pos then
                    local hero_dist = Dist2D(hero_pos, pos)
                    if hero_dist <= max_range then
                        local score = hero_dist
                        if mode == 0 and cursor then
                            score = Dist2D(cursor, pos)
                        end

                        if score < best_score then
                            best = enemy
                            best_score = score
                        end
                    end
                end
            end
        end
    end

    return best
end

-- ============================================================================
-- Ability helpers
-- ============================================================================

local function GetAbility(hero, name)
    if not hero or not NPC or not NPC.GetAbility then return nil end
    local ability, ok = SafeCall(NPC.GetAbility, hero, name)
    if ok then return ability end
    return nil
end

local function AbilityReady(hero, name)
    local ability = GetAbility(hero, name)
    if not ability then
        return false, nil, "missing_handle"
    end

    -- Runtime-proven Lina rule: an ability handle is not enough. Unlearned slots
    -- can still exist, so require GetLevel > 0 before treating it as usable.
    local level, level_ok = SafeCall(Ability.GetLevel, ability)
    if not level_ok then
        return false, ability, "get_level_error"
    end
    if type(level) ~= "number" or level <= 0 then
        return false, ability, "level_0"
    end

    local ready, ready_ok = SafeCall(Ability.IsReady, ability)
    if not ready_ok then
        return false, ability, "is_ready_error"
    end
    if not ready then
        return false, ability, "is_ready_false"
    end

    local mana, mana_ok = SafeCall(NPC.GetMana, hero)
    if not mana_ok then
        return false, ability, "mana_read_error"
    end

    local castable, castable_ok = SafeCall(Ability.IsCastable, ability, mana)
    if not castable_ok then
        return false, ability, "is_castable_error"
    end
    if not castable then
        return false, ability, "is_castable_false"
    end

    return true, ability, "ready"
end

-- Evidence probe: enumerate the LOCAL Techies ability slots using runtime-proven
-- NPC.GetAbilityByIndex + Ability.GetName/GetLevel/IsReady/IsCastable.
-- This avoids guessing Techies' current internal ability names.
local function ProbeHeroAbilities(hero)
    if not hero then return end

    local mana, mana_ok = SafeCall(NPC.GetMana, hero)
    if not mana_ok then mana = 0 end

    Emit("ABILITY_PROBE_BEGIN", "hero=" .. UnitName(hero))

    local seen = 0
    for slot = 0, 24 do
        local ability, ok = SafeCall(NPC.GetAbilityByIndex, hero, slot)
        if ok and ability then
            seen = seen + 1

            local name, name_ok = SafeCall(Ability.GetName, ability)
            local level, level_ok = SafeCall(Ability.GetLevel, ability)
            local ready, ready_ok = SafeCall(Ability.IsReady, ability)
            local castable, castable_ok = SafeCall(Ability.IsCastable, ability, mana)

            Emit(
                "ABILITY_SLOT",
                "slot=" .. tostring(slot)
                    .. " | name=" .. tostring(name_ok and name or "<name_error>")
                    .. " | level=" .. tostring(level_ok and level or "<level_error>")
                    .. " | ready=" .. tostring(ready_ok and (ready and true or false) or "<ready_error>")
                    .. " | castable=" .. tostring(castable_ok and (castable and true or false) or "<castable_error>")
            )
        end
    end

    Emit("ABILITY_PROBE_END", "count=" .. tostring(seen))

    -- Probe the exact names currently requested by this script.
    local requested = {
        {"sticky", ABILITY_STICKY},
        {"tazer", ABILITY_TAZER},
        {"blast", ABILITY_BLAST},
        {"mad", ABILITY_MAD},
        {"mines", ABILITY_MINES},
        {"mad_detonate_candidate", ABILITY_MAD_DETONATE},
    }

    for _, entry in ipairs(requested) do
        local label = entry[1]
        local name = entry[2]
        local ready, ability, reason = AbilityReady(hero, name)

        local actual_name = "<nil>"
        if ability then
            local got, ok = SafeCall(Ability.GetName, ability)
            if ok and got then actual_name = got end
        end

        Emit(
            "ABILITY_REQUEST",
            "label=" .. label
                .. " | requested=" .. tostring(name)
                .. " | handle=" .. tostring(ability ~= nil)
                .. " | actual_name=" .. tostring(actual_name)
                .. " | usable=" .. tostring(ready)
                .. " | reason=" .. tostring(reason)
        )
    end
end


-- RUNTIME-PROVEN in the supplied Lina brain. Charge consumption is the
-- authoritative confirmation signal for charge-based abilities such as
-- Proximity Mines.
local function AbilityCharges(ability)
    if not ability or not Ability.GetCurrentCharges then return nil end
    local charges, ok = SafeCall(Ability.GetCurrentCharges, ability)
    if ok and type(charges) == "number" then return charges end
    return nil
end

local function AbilityCooldown(ability)
    if not ability or not Ability.GetCooldown then return nil end
    local cd, ok = SafeCall(Ability.GetCooldown, ability)
    if ok and type(cd) == "number" then return cd end
    return nil
end


local function AbilityLevel(ability)
    if not ability or not Ability.GetLevel then return nil end
    local level, ok = SafeCall(Ability.GetLevel, ability)
    if ok and type(level) == "number" then return level end
    return nil
end

local function AbilityCastPoint(ability)
    if not ability or not Ability.GetCastPoint then return 0.0 end
    local cp, ok = SafeCall(Ability.GetCastPoint, ability, true)
    if ok and type(cp) == "number" then return cp end
    return 0.0
end


local function AbilityInPhase(ability)
    if not ability or not Ability.IsInAbilityPhase then return false end
    local v, ok = SafeCall(Ability.IsInAbilityPhase, ability)
    return ok and v and true or false
end

local function SecondsSinceLastUse(ability)
    if not ability or not Ability.SecondsSinceLastUse then return nil end
    local v, ok = SafeCall(Ability.SecondsSinceLastUse, ability)
    if ok and type(v) == "number" then return v end
    return nil
end

local function AbilityCastRange(ability)
    if not ability or not Ability.GetCastRange then return nil end
    local range, ok = SafeCall(Ability.GetCastRange, ability)
    if ok and type(range) == "number" and range > 0 then return range end
    return nil
end

-- ============================================================================
-- Hex -> Blast lock budget
-- ============================================================================
-- Goal: if Hex connected first, do not spend so long on optional setup that the
-- victim regains item use and presses BKB before Blast Off impacts. No new
-- UCZone API is introduced here: we only use Now(), GetAbility(), and the
-- already-validated Ability.GetCastPoint wrapper above.

local function HexRemaining(now)
    if not combo.hex_confirmed or not combo.hex_deadline then return nil end
    return combo.hex_deadline - (now or Now())
end

local function BlastImpactReserve(hero)
    local blast = GetAbility(hero, ABILITY_BLAST)
    local cast_point = AbilityCastPoint(blast)
    local leap = ui_blast_leap_ms:Get() / 1000.0
    local safety = ui_hex_chain_safety_ms:Get() / 1000.0
    return cast_point + leap + safety, cast_point, leap, safety
end

-- setup_sec is OUR conservative allowance for the setup state we are about to
-- enter. preserved_setup_sec reserves time for a higher-value later setup
-- (currently E-Blade). Callers decide which optional state to skip.
local function HexBudgetInsufficient(now, setup_sec, preserved_setup_sec, step_name)
    if not ui_protect_hex_chain:Get() then return false end

    local remaining = HexRemaining(now)
    if remaining == nil then return false end

    local reserve, cast_point, leap, safety = BlastImpactReserve(combo.hero)
    local setup = math.max(0.0, setup_sec or 0.0)
    local preserved = math.max(0.0, preserved_setup_sec or 0.0)
    local needed = reserve + setup + preserved

    if remaining <= needed then
        Emit(
            "HEX_SETUP_SKIPPED",
            "step=" .. tostring(step_name or "unknown")
                .. " | remaining_ms=" .. tostring(math.floor(remaining * 1000))
                .. " | setup_ms=" .. tostring(math.floor(setup * 1000))
                .. " | preserved_ms=" .. tostring(math.floor(preserved * 1000))
                .. " | total_needed_ms=" .. tostring(math.floor(needed * 1000))
                .. " | blast_cast_point_ms=" .. tostring(math.floor(cast_point * 1000))
                .. " | blast_leap_ms=" .. tostring(math.floor(leap * 1000))
                .. " | safety_ms=" .. tostring(math.floor(safety * 1000))
        )
        return true
    end

    return false
end

local function SetupTimeAllowance(handle)
    -- Cast point is runtime-read. The extra 80ms is OUR controller allowance
    -- for order submission + one/few update ticks; it is not claimed as a
    -- UCZone/game constant.
    return AbilityCastPoint(handle) + 0.08
end

local function CastPosition(hero, name, pos)
    if not pos then return false end

    local ready, ability = AbilityReady(hero, name)
    if not ready or not ability then return false end
    if not Ability or not Ability.CastPosition then return false end

    local ok, result = pcall(Ability.CastPosition, ability, pos)
    if not ok then return false end

    -- Some runtime APIs return nil on a successfully submitted order.
    return result ~= false
end

local function CastAbilityTarget(hero, name, target, identifier)
    if not target then return false, nil, "missing_target" end

    local ready, ability, reason = AbilityReady(hero, name)
    if not ready or not ability then
        return false, ability, reason or "not_ready"
    end

    if not Ability or not Ability.CastTarget then
        return false, ability, "Ability.CastTarget_missing"
    end

    local ok = pcall(
        Ability.CastTarget,
        ability,
        target,
        false,  -- queue
        true,   -- push into OnPrepareUnitOrders for observability
        false,  -- execute_fast
        identifier or ("techies-brain-" .. tostring(name))
    )

    if not ok then
        return false, ability, "cast_error"
    end

    -- UCZone cast methods submit an order; positive acceptance is verified later.
    return true, ability, "submitted"
end

local function CastNoTarget(hero, name)
    local ready, ability = AbilityReady(hero, name)
    if not ready or not ability then return false end
    if not Ability or not Ability.CastNoTarget then return false end

    local ok, result = pcall(Ability.CastNoTarget, ability)
    if not ok then return false end
    return result ~= false
end


-- ============================================================================
-- Unified item / setup-cast helpers
-- ============================================================================

local function GetItem(hero, name)
    if not hero or not NPC or not NPC.GetItem then return nil end
    local item, ok = SafeCall(NPC.GetItem, hero, name)
    if ok then return item end
    return nil
end

local function FutureEbladeAllowance(hero)
    if not ui_use_eblade:Get() then return 0.0 end
    local item = GetItem(hero, ITEM_EBLADE)
    if not item then return 0.0 end
    return SetupTimeAllowance(item)
end

local function ItemReady(hero, name)
    local item = GetItem(hero, name)
    if not item then return false, nil, "missing_item" end

    -- OFFICIAL_GITBOOK: CItem extends CAbility. Runtime v0.2.0 proved Item.IsReady
    -- is absent in this Umbrella build, while Ability.* works on the same item
    -- handles (GetCastRange already returned live values).
    local ready, ready_ok = SafeCall(Ability.IsReady, item)
    if not ready_ok then
        return false, item, "ability_is_ready_error"
    end
    if not ready then
        return false, item, "not_ready"
    end

    local mana, mana_ok = SafeCall(NPC.GetMana, hero)
    if not mana_ok then
        return false, item, "mana_read_error"
    end

    local castable, cast_ok = SafeCall(Ability.IsCastable, item, mana)
    if not cast_ok then
        return false, item, "ability_is_castable_error"
    end
    if not castable then
        return false, item, "not_castable"
    end

    return true, item, "ready"
end

local function CastItemTarget(hero, name, target)
    if not target then return false, nil, "missing_target" end

    local ready, item, reason = ItemReady(hero, name)
    if not ready or not item then return false, item, reason end

    local ok = pcall(
        Ability.CastTarget,
        item,
        target,
        false,  -- queue
        true,   -- push through OnPrepareUnitOrders for observability
        false,  -- execute_fast
        "techies-brain-" .. tostring(name)
    )
    if not ok then return false, item, "cast_error" end

    -- Documented cast methods return nil; successful invocation means order
    -- submitted. Cooldown verification below decides whether it actually fired.
    return true, item, "submitted"
end

local function SetupCooldown(handle)
    return AbilityCooldown(handle)
end

local function SetupCastRange(handle)
    return AbilityCastRange(handle)
end

local function RangeString(handle)
    local r = SetupCastRange(handle)
    if r == nil then return "nil" end
    return tostring(math.floor(r))
end

local function LogLiveRanges(hero)
    local hex = GetItem(hero, ITEM_HEX)
    local eblade = GetItem(hero, ITEM_EBLADE)
    local lens = GetItem(hero, ITEM_AETHER_LENS)

    Emit(
        "RANGE_SNAPSHOT",
        "hex=" .. RangeString(hex)
            .. " | eblade=" .. RangeString(eblade)
            .. " | sticky=" .. RangeString(GetAbility(hero, ABILITY_STICKY))
            .. " | tazer=" .. RangeString(GetAbility(hero, ABILITY_TAZER))
            .. " | blast=" .. RangeString(GetAbility(hero, ABILITY_BLAST))
            .. " | mines=" .. RangeString(GetAbility(hero, ABILITY_MINES))
            .. " | mad=" .. RangeString(GetAbility(hero, ABILITY_MAD))
            .. " | aether_lens_owned=" .. tostring(lens ~= nil)
    )
end

local function BeginSetupVerification(kind, name, handle, next_state, extra)
    local now = Now()
    combo.pending_setup = {
        kind = kind,
        name = name,
        handle = handle,
        cd_before = SetupCooldown(handle),
        requested_at = now,
        deadline = now + ui_setup_verify_ms:Get() / 1000.0,
        next_state = next_state,
        extra = extra,
    }

    Emit(
        "SETUP_REQUEST",
        "kind=" .. tostring(kind)
            .. " | name=" .. tostring(name)
            .. " | cd_before=" .. tostring(combo.pending_setup.cd_before)
            .. (extra and (" | " .. tostring(extra)) or "")
    )
end

local function VerifySetup(now, success_label)
    local p = combo.pending_setup
    if not p then return "missing" end

    local cd_now = SetupCooldown(p.handle)
    local cooldown_started =
        p.cd_before ~= nil and cd_now ~= nil and cd_now > p.cd_before + 0.05

    -- Reactive Tazer's current game behavior is a self/ally unit-target buff.
    -- The strongest positive confirmation is the buff modifier appearing on the
    -- chosen target. Cooldown may legitimately remain at 0 while the buff/sub-
    -- ability is active, so cooldown is secondary for Tazer.
    local tazer_modifier = false
    local tazer_stop_level = nil
    local tazer_stop_ready = false

    if p.name == ABILITY_TAZER then
        if NPC and NPC.HasModifier then
            local v, ok = SafeCall(
                NPC.HasModifier,
                combo.hero,
                "modifier_techies_reactive_tazer"
            )
            tazer_modifier = ok and v and true or false
        end

        local stop = GetAbility(combo.hero, ABILITY_TAZER_STOP)
        if stop then
            local lv, lvok = SafeCall(Ability.GetLevel, stop)
            if lvok and type(lv) == "number" then
                tazer_stop_level = lv
            end
            local rv, rvok = SafeCall(Ability.IsReady, stop)
            tazer_stop_ready = rvok and rv and true or false
        end
    end

    if cooldown_started or tazer_modifier then
        Emit(
            "SETUP_CONFIRMED",
            "kind=" .. tostring(p.kind)
                .. " | name=" .. tostring(p.name)
                .. " | cd_before=" .. tostring(p.cd_before)
                .. " | cd_now=" .. tostring(cd_now)
                .. " | tazer_modifier=" .. tostring(tazer_modifier)
                .. " | tazer_stop_level=" .. tostring(tazer_stop_level)
                .. " | tazer_stop_ready=" .. tostring(tazer_stop_ready)
        )
        combo.pending_setup = nil
        return "confirmed"
    end

    if now >= p.deadline then
        Emit(
            "SETUP_UNCONFIRMED",
            "kind=" .. tostring(p.kind)
                .. " | name=" .. tostring(p.name)
                .. " | cd_before=" .. tostring(p.cd_before)
                .. " | cd_now=" .. tostring(cd_now)
                .. " | tazer_modifier=" .. tostring(tazer_modifier)
                .. " | tazer_stop_level=" .. tostring(tazer_stop_level)
                .. " | tazer_stop_ready=" .. tostring(tazer_stop_ready)
                .. " | continuing=true"
        )
        combo.pending_setup = nil
        return "timeout"
    end

    return "waiting"
end

-- ============================================================================
-- Target motion / prediction
-- ============================================================================

local function ResetMotion(target, now)
    motion.target = target
    motion.last_pos = GetPos(target)
    motion.last_time = now
    motion.vx = 0.0
    motion.vy = 0.0
    motion.initialized = motion.last_pos ~= nil
end

local function UpdateMotion(target, now)
    if not target then return end

    if motion.target ~= target or not motion.initialized then
        ResetMotion(target, now)
        return
    end

    local pos = GetPos(target)
    if not pos or not motion.last_pos or not motion.last_time then
        ResetMotion(target, now)
        return
    end

    local dt = now - motion.last_time
    if dt < 0.025 then return end

    local raw_vx = ((pos.x or 0) - (motion.last_pos.x or 0)) / dt
    local raw_vy = ((pos.y or 0) - (motion.last_pos.y or 0)) / dt

    local speed = math.sqrt(raw_vx * raw_vx + raw_vy * raw_vy)
    local max_speed = ui_max_prediction_speed:Get()

    if speed > max_speed and speed > 0 then
        local scale = max_speed / speed
        raw_vx = raw_vx * scale
        raw_vy = raw_vy * scale
    end

    local alpha = ui_velocity_smoothing:Get() / 100.0
    motion.vx = motion.vx * (1.0 - alpha) + raw_vx * alpha
    motion.vy = motion.vy * (1.0 - alpha) + raw_vy * alpha

    motion.last_pos = pos
    motion.last_time = now
end

local function PredictedTargetPos(target, horizon_sec)
    local pos = GetPos(target)
    if not pos then return nil end

    if not ui_predict_target:Get() then
        return pos
    end

    local max_horizon = ui_max_prediction_horizon_ms:Get() / 1000.0
    local h = math.max(0.0, math.min(horizon_sec or 0.0, max_horizon))

    return NewVec(
        (pos.x or 0) + motion.vx * h,
        (pos.y or 0) + motion.vy * h,
        pos.z or 0
    )
end


-- Choose the furthest predicted target point that is already castable from the
-- CURRENT Techies position. This prevents Ability.CastPosition from turning an
-- intended Blast Off into a move-to-cast order that can take longer than the
-- old timing fallback.
local function FindCastablePredictedPos(hero, target, ability, max_horizon)
    local hero_pos = GetPos(hero)
    local target_pos = GetPos(target)
    local cast_range = AbilityCastRange(ability)

    if not hero_pos or not target_pos then
        return nil, 0.0, cast_range, math.huge, "missing_position"
    end

    if not cast_range or cast_range <= 0 then
        return nil, 0.0, cast_range, math.huge, "missing_cast_range"
    end

    -- Use nearly the full runtime-reported cast range. The previous 10-unit
    -- hidden guard cost meaningful airtime at a 675-unit mine range.
    local usable_range = math.max(0.0, cast_range - 1.0)
    local current_distance = Dist2D(hero_pos, target_pos)
    if current_distance > usable_range then
        return nil, 0.0, cast_range, current_distance, "current_target_out_of_range"
    end

    local horizon = math.max(0.0, max_horizon or 0.0)
    local best = target_pos
    local best_h = 0.0
    local low = 0.0
    local high = horizon

    for _ = 1, 8 do
        local mid = (low + high) * 0.5
        local p = PredictedTargetPos(target, mid)
        if p and Dist2D(hero_pos, p) <= usable_range then
            best = p
            best_h = mid
            low = mid
        else
            high = mid
        end
    end

    return best, best_h, cast_range, Dist2D(hero_pos, best), "castable"
end

local function GetMovementBasis(hero, target)
    local vx = motion.vx
    local vy = motion.vy
    local speed = math.sqrt(vx * vx + vy * vy)

    if speed > 25 then
        return Normalize2D(vx, vy)
    end

    local hpos = GetPos(hero)
    local tpos = GetPos(target)

    if hpos and tpos then
        return Normalize2D(
            (tpos.x or 0) - (hpos.x or 0),
            (tpos.y or 0) - (hpos.y or 0)
        )
    end

    return 1.0, 0.0
end

local function MinePositionWithBasis(center, fx, fy, mine_number)
    if not center then return nil end

    local radius = ui_mine_ring_radius:Get()
    local bias = ui_forward_bias:Get()
    local desired = math.max(
        1,
        (combo.desired_mines and combo.desired_mines > 0)
            and combo.desired_mines
            or ui_mine_count:Get()
    )

    local cx = (center.x or 0) + fx * bias
    local cy = (center.y or 0) + fy * bias
    local cz = center.z or 0

    local angle_step = (2.0 * math.pi) / desired
    local base_angle = math.pi
    local angle = base_angle + (mine_number - 1) * angle_step
    local dx, dy = Rotate2D(fx, fy, angle)

    return NewVec(
        cx + dx * radius,
        cy + dy * radius,
        cz
    )
end

local function MinePosition(hero, target, center, mine_number)
    local fx, fy = GetMovementBasis(hero, target)
    return MinePositionWithBasis(center, fx, fy, mine_number)
end

local function FreezeMinePlan(hero, target, anchor)
    if not anchor then return false end

    local desired = combo.desired_mines or ui_mine_count:Get()
    local fx, fy = GetMovementBasis(hero, target)
    local plan = {}

    for i = 1, desired do
        plan[i] = MinePositionWithBasis(anchor, fx, fy, i)
    end

    combo.mine_plan = plan

    local detail = "anchor_x=" .. tostring(math.floor(anchor.x or 0))
        .. " | anchor_y=" .. tostring(math.floor(anchor.y or 0))
        .. " | mine_count=" .. tostring(desired)
        .. " | ring_radius=" .. tostring(ui_mine_ring_radius:Get())
        .. " | forward_bias=" .. tostring(ui_forward_bias:Get())

    for i = 1, desired do
        local p = plan[i]
        if p then
            detail = detail
                .. " | m" .. tostring(i) .. "_x=" .. tostring(math.floor(p.x or 0))
                .. " | m" .. tostring(i) .. "_y=" .. tostring(math.floor(p.y or 0))
        end
    end

    Emit("MINE_PLAN_FROZEN", detail)
    return true
end

-- ============================================================================
-- State machine
-- ============================================================================

local function SetState(new_state, reason)
    combo.state = new_state
    combo.state_started = Now()
    combo.last_reason = reason or ""
    Emit("STATE", new_state .. (reason and (" | " .. reason) or ""))
end

local function ClearCombo()
    combo.active = false
    combo.state = STATE.IDLE
    combo.state_started = 0.0
    combo.combo_started = 0.0
    combo.hero = nil
    combo.target = nil

    combo.pending_setup = nil
    combo.setup_retries = { sticky = 0, tazer = 0 }
    combo.hex_confirmed = false
    combo.hex_order_time = nil
    combo.hex_confirm_time = nil
    combo.hex_deadline = nil
    combo.sticky_confirmed = false
    combo.tazer_confirmed = false
    combo.tazer_detonate_attempted = false
    combo.tazer_detonate_attempts = 0
    combo.tazer_detonate_pending = nil
    combo.tazer_detonate_confirmed = false
    combo.eblade_confirmed = false

    combo.blast_order_time = nil
    combo.blast_start_pos = nil
    combo.blast_anchor = nil
    combo.blast_ability = nil
    combo.blast_cd_before = nil
    combo.blast_since_before = nil
    combo.blast_phase_seen = false
    combo.blast_confirmed = false
    combo.blast_motion_without_confirm_logged = false
    combo.airborne_start = nil
    combo.predicted_land_time = nil
    combo.mine_plan = {}
    combo.mines_placed = 0
    combo.desired_mines = 0
    combo.mine_charges_start = nil
    combo.last_mine_attempt = -999.0
    combo.last_mine_confirmed = -999.0
    combo.pending_mine = nil
    combo.mine_progress_deadline = nil
    combo.confirmed_mine_positions = {}
    combo.last_mine_wait_log = -999.0
    combo.last_mine_wait_distance = nil
    combo.last_mine_wait_number = nil

    combo.mad_attempted = false
    combo.mad_retry_count = 0
    combo.mad_pending = nil
    combo.mad_confirmed = false
    combo.mad_detonate_attempted = false

    combo.last_reason = ""

    motion.target = nil
    motion.last_pos = nil
    motion.last_time = nil
    motion.vx = 0.0
    motion.vy = 0.0
    motion.initialized = false
end

local function Abort(reason)
    if combo.active then
        Emit("ABORT", reason or "unknown")
    end
    combo.state = STATE.ABORT
    combo.last_reason = reason or "unknown"
    combo.active = false
end

local function Complete(reason)
    Emit(
        "COMPLETE",
        (reason or "done") .. " | mines=" .. tostring(combo.mines_placed)
    )
    combo.state = STATE.COMPLETE
    combo.last_reason = reason or "done"
    combo.active = false
end

local function ValidateHero(hero)
    return hero and IsAlive(hero) and UnitName(hero) == HERO_NAME
end

local function StartCombo()
    local hero = GetLocalHero()
    if not ValidateHero(hero) then
        Emit("START_REJECTED", "local hero is not Techies or not alive")
        return
    end

    local target = FindTarget(hero)
    if not target then
        Emit("START_REJECTED", "no valid enemy target")
        return
    end

    local hero_pos = GetPos(hero)
    local target_pos = GetPos(target)
    if not hero_pos or not target_pos then
        Emit("START_REJECTED", "missing position")
        return
    end

    if Dist2D(hero_pos, target_pos) > ui_max_target_range:Get() then
        Emit("START_REJECTED", "target too far")
        return
    end

    local blast_ready, _, blast_reason = AbilityReady(hero, ABILITY_BLAST)
    if not blast_ready then
        Emit(
            "START_REJECTED",
            "Blast Off unavailable"
                .. " | requested=" .. ABILITY_BLAST
                .. " | reason=" .. tostring(blast_reason)
        )
        return
    end

    local mines_ready, _, mines_reason = AbilityReady(hero, ABILITY_MINES)
    if not mines_ready then
        Emit(
            "START_REJECTED",
            "Proximity Mines unavailable"
                .. " | requested=" .. ABILITY_MINES
                .. " | reason=" .. tostring(mines_reason)
        )
        return
    end

    if ui_use_sticky:Get() then
        local sticky_ready, _, sticky_reason = AbilityReady(hero, ABILITY_STICKY)
        if not sticky_ready then
            Emit(
                "START_REJECTED",
                "Sticky Bomb unavailable"
                    .. " | requested=" .. ABILITY_STICKY
                    .. " | reason=" .. tostring(sticky_reason)
            )
            return
        end
    end

    ClearCombo()

    local now = Now()
    combo.active = true
    combo.hero = hero
    combo.target = target
    combo.combo_started = now
    combo.state_started = now
    if ui_use_hex:Get() then
        combo.state = STATE.HEX
    elseif ui_use_sticky:Get() then
        combo.state = STATE.STICKY
    elseif ui_use_tazer:Get() then
        combo.state = STATE.TAZER
    elseif ui_use_eblade:Get() then
        combo.state = STATE.EBLADE
    else
        combo.state = STATE.BLAST
    end

    ResetMotion(target, now)
    LogLiveRanges(hero)

    local mine_ability = GetAbility(hero, ABILITY_MINES)
    local charges = AbilityCharges(mine_ability)
    local requested = ui_mine_count:Get()
    combo.mine_charges_start = charges
    if charges ~= nil and charges >= 0 then
        combo.desired_mines = math.min(requested, charges)
    else
        combo.desired_mines = requested
    end
    combo.confirmed_mine_positions = {}
    combo.mine_plan = {}

    Emit(
        "START",
        "target=" .. UnitName(target)
            .. " | mine_requested=" .. tostring(requested)
            .. " | mine_charges_start=" .. tostring(charges)
            .. " | mine_goal=" .. tostring(combo.desired_mines)
    )
end

local function ReconcileMineCharges(now, ability, source)
    local current = AbilityCharges(ability)
    local start_charges = combo.mine_charges_start
    local desired = combo.desired_mines or ui_mine_count:Get()

    if current == nil or start_charges == nil then
        return current, false
    end

    local consumed = math.max(0, start_charges - current)
    consumed = math.min(desired, consumed)

    if consumed <= combo.mines_placed then
        return current, false
    end

    local old = combo.mines_placed
    combo.mines_placed = consumed
    combo.last_mine_confirmed = now
    combo.mine_progress_deadline =
        now + math.max(0.9, ui_post_land_window_ms:Get() / 1000.0)

    for mine_number = old + 1, consumed do
        local pos = combo.mine_plan and combo.mine_plan[mine_number] or nil
        if pos then
            combo.confirmed_mine_positions[#combo.confirmed_mine_positions + 1] = pos
        end

        Emit(
            "MINE_CONFIRMED",
            "mine=" .. tostring(mine_number)
                .. " | source=" .. tostring(source or "global_charge")
                .. " | charges_start=" .. tostring(start_charges)
                .. " | charges_now=" .. tostring(current)
        )
    end

    if combo.pending_mine
        and combo.pending_mine.mine_number <= combo.mines_placed
    then
        combo.pending_mine = nil
    end

    return current, true
end

local function ShouldLogMineWait(now, mine_number, distance)
    local changed_mine = combo.last_mine_wait_number ~= mine_number
    local changed_distance =
        combo.last_mine_wait_distance == nil
        or math.abs(distance - combo.last_mine_wait_distance) >= 40
    local interval = now - combo.last_mine_wait_log >= 0.15

    if changed_mine or changed_distance or interval then
        combo.last_mine_wait_log = now
        combo.last_mine_wait_number = mine_number
        combo.last_mine_wait_distance = distance
        return true
    end

    return false
end

local function TryAirMine(now)
    local desired = combo.desired_mines or ui_mine_count:Get()

    local ability = GetAbility(combo.hero, ABILITY_MINES)
    if not ability then
        Emit("MINE_BLOCKED", "reason=missing_handle")
        return false
    end

    -- Global charge truth is authoritative. This catches a delayed cast that
    -- consumes a charge AFTER its original request-local verification window.
    local charges_now, reconciled =
        ReconcileMineCharges(now, ability, "global_charge")

    if combo.mines_placed >= desired then
        return true
    end

    if reconciled then
        return false
    end

    -- Reconcile an already-submitted request.
    if combo.pending_mine then
        local pending = combo.pending_mine
        local in_phase = AbilityInPhase(ability)
        local since_last_use = SecondsSinceLastUse(ability)

        -- A second charge read handles consumption that occurred on this tick.
        charges_now, reconciled =
            ReconcileMineCharges(now, ability, "pending_request")
        if reconciled then
            return false
        end

        if now < pending.verify_deadline or in_phase then
            return false
        end

        Emit(
            "MINE_UNCONFIRMED",
            "mine=" .. tostring(pending.mine_number)
                .. " | charges_before=" .. tostring(pending.charges_before)
                .. " | charges_now=" .. tostring(charges_now)
                .. " | request_age_ms="
                .. tostring(math.floor((now - pending.requested_at) * 1000))
                .. " | cast_point_ms="
                .. tostring(math.floor(pending.cast_point * 1000))
                .. " | in_phase=" .. tostring(in_phase)
                .. " | since_last_use=" .. tostring(since_last_use)
                .. " | action=retry"
        )

        combo.pending_mine = nil
        combo.last_mine_attempt = now
    end

    local configured_gap = ui_mine_gap_ms:Get() / 1000.0
    local effective_gap = math.max(configured_gap, 0.06)
    if now - combo.last_mine_confirmed < effective_gap then
        return false
    end
    if now - combo.last_mine_attempt < 0.05 then
        return false
    end

    local ready = AbilityReady(combo.hero, ABILITY_MINES)
    if not ready then
        return false
    end

    local remaining = 0.0
    if combo.predicted_land_time then
        remaining = math.max(0.0, combo.predicted_land_time - now)
    end

    local mine_number = combo.mines_placed + 1

    -- Real-match fix: once Blast Off is committed, do NOT chase the target with
    -- a moving mine formation. Use the exact frozen point built from blast_anchor.
    local pos = combo.mine_plan and combo.mine_plan[mine_number] or nil
    if not pos then
        Emit(
            "MINE_BLOCKED",
            "reason=missing_frozen_plan | mine=" .. tostring(mine_number)
        )
        return false
    end

    local cast_range = AbilityCastRange(ability)
    local hero_pos = GetPos(combo.hero)
    local cast_distance = Dist2D(hero_pos, pos)

    if cast_range and cast_distance > math.max(0, cast_range - 1) then
        if ShouldLogMineWait(now, mine_number, cast_distance) then
            Emit(
                "MINE_WAIT_RANGE",
                "mine=" .. tostring(mine_number)
                    .. " | distance=" .. tostring(math.floor(cast_distance))
                    .. " | cast_range=" .. tostring(math.floor(cast_range))
                    .. " | frozen_plan=true"
                    .. " | remaining_air_ms="
                    .. tostring(math.floor(remaining * 1000))
            )
        end
        return false
    end

    local charges_before = AbilityCharges(ability)
    if charges_before ~= nil and charges_before <= 0 then
        ReconcileMineCharges(now, ability, "no_charges")
        Emit("MINE_NO_CHARGES", "mine=" .. tostring(mine_number))
        return false
    end

    local cast_point = AbilityCastPoint(ability)
    local cd_before = AbilityCooldown(ability)
    local since_before = SecondsSinceLastUse(ability)

    combo.last_mine_attempt = now

    local ok = pcall(
        Ability.CastPosition,
        ability,
        pos,
        false,
        true,
        false,
        "techies-brain-mine-" .. tostring(mine_number)
    )

    if ok then
        local verify_window = math.max(0.45, cast_point + 0.40)

        combo.pending_mine = {
            mine_number = mine_number,
            position = pos,
            charges_before = charges_before,
            requested_at = now,
            cast_point = cast_point,
            cd_before = cd_before,
            since_before = since_before,
            verify_deadline = now + verify_window,
        }

        combo.mine_progress_deadline =
            now + math.max(1.0, verify_window + 0.35)

        local airborne_at_request =
            combo.predicted_land_time ~= nil and now < combo.predicted_land_time

        Emit(
            "MINE_REQUEST",
            "mine=" .. tostring(mine_number)
                .. " | airborne_at_request=" .. tostring(airborne_at_request)
                .. " | charges_before=" .. tostring(charges_before)
                .. " | distance=" .. tostring(math.floor(cast_distance))
                .. " | cast_range="
                .. tostring(cast_range and math.floor(cast_range) or -1)
                .. " | frozen_plan=true"
                .. " | cast_point_ms=" .. tostring(math.floor(cast_point * 1000))
                .. " | cd_before=" .. tostring(cd_before)
                .. " | since_before=" .. tostring(since_before)
                .. " | verify_ms=" .. tostring(math.floor(verify_window * 1000))
                .. " | remaining_air_ms="
                .. tostring(math.floor(remaining * 1000))
        )

        return false
    end

    Emit("MINE_REQUEST_FAILED", "mine=" .. tostring(mine_number))
    return false
end


-- ---------------------------------------------------------------------------
-- Reactive Tazer manual detonation.
--
-- RUNTIME_OBSERVED:
--   1) techies_reactive_tazer is self/ally unit-targeted.
--   2) When the buff is active, pressing W again detonates it.
--   3) The runtime ability list exposes techies_reactive_tazer_stop.
--
-- Current public mechanic documentation calls this sub-ability "Detonate Tazer":
-- it replaces Reactive Tazer while active, has no target, and detonates the
-- current Reactive Tazer immediately.
--
-- Design choice:
--   DO NOT detonate before/during the airborne mine sequence. That sequence is
--   now runtime-stable and should remain uncontaminated by another order.
--   Detonate immediately AFTER all requested Proximity Mines are confirmed,
--   while Techies is on/near the Blast Off target, then proceed to M.A.D.
-- ---------------------------------------------------------------------------

local function HasTazerBuff(hero)
    if not hero or not NPC or not NPC.HasModifier then return false end
    local v, ok = SafeCall(
        NPC.HasModifier,
        hero,
        "modifier_techies_reactive_tazer"
    )
    return ok and v and true or false
end

local function TransitionAfterMines(reason)
    if ui_use_tazer:Get()
        and ui_auto_detonate_tazer:Get()
        and HasTazerBuff(combo.hero)
    then
        SetState(
            STATE.TAZER_DETONATE,
            (reason or "mines complete") .. " | tazer buff active"
        )
    else
        if ui_use_tazer:Get() and ui_auto_detonate_tazer:Get() then
            Emit(
                "TAZER_DETONATE_SKIPPED",
                "reason=no_active_tazer_buff"
            )
        end
        SetState(STATE.MAD, reason or "mines complete")
    end
end

local function UpdateTazerDetonate(now)
    if not ui_use_tazer:Get() or not ui_auto_detonate_tazer:Get() then
        SetState(STATE.MAD, "Tazer detonate disabled")
        return
    end

    local buff_active = HasTazerBuff(combo.hero)

    if combo.tazer_detonate_pending then
        local p = combo.tazer_detonate_pending
        local main = GetAbility(combo.hero, ABILITY_TAZER)
        local stop = GetAbility(combo.hero, ABILITY_TAZER_STOP)

        local main_cd = AbilityCooldown(main)
        local stop_cd = AbilityCooldown(stop)
        local stop_ready = false
        if stop then
            local rv, rok = SafeCall(Ability.IsReady, stop)
            stop_ready = rok and rv and true or false
        end

        if not buff_active then
            combo.tazer_detonate_pending = nil
            combo.tazer_detonate_confirmed = true

            Emit(
                "TAZER_DETONATE_CONFIRMED",
                "buff_removed=true"
                    .. " | main_cd=" .. tostring(main_cd)
                    .. " | stop_cd=" .. tostring(stop_cd)
                    .. " | stop_ready=" .. tostring(stop_ready)
                    .. " | attempts=" .. tostring(combo.tazer_detonate_attempts)
                    .. " | request_age_ms="
                    .. tostring(math.floor((now - p.requested_at) * 1000))
            )

            SetState(STATE.MAD, "Reactive Tazer detonation confirmed")
            return
        end

        if now >= p.verify_deadline then
            combo.tazer_detonate_pending = nil

            if stop_ready and combo.tazer_detonate_attempts < 2 then
                Emit(
                    "TAZER_DETONATE_RETRY",
                    "reason=buff_still_active_and_stop_ready"
                        .. " | attempt=" .. tostring(combo.tazer_detonate_attempts + 1)
                )
                combo.tazer_detonate_attempted = false
                return
            end

            Emit(
                "TAZER_DETONATE_UNCONFIRMED",
                "buff_still_active=true"
                    .. " | main_cd=" .. tostring(main_cd)
                    .. " | stop_cd=" .. tostring(stop_cd)
                    .. " | stop_ready=" .. tostring(stop_ready)
                    .. " | attempts=" .. tostring(combo.tazer_detonate_attempts)
            )

            SetState(STATE.MAD, "Reactive Tazer detonation unconfirmed")
        end
        return
    end

    if combo.tazer_detonate_attempts >= 2 then
        SetState(STATE.MAD, "Reactive Tazer retry budget exhausted")
        return
    end

    if not buff_active then
        Emit("TAZER_DETONATE_SKIPPED", "reason=buff_already_gone")
        SetState(STATE.MAD, "Reactive Tazer buff already gone")
        return
    end

    local hero_pos = GetPos(combo.hero)
    local target_pos = GetPos(combo.target)
    local d = Dist2D(hero_pos, target_pos)

    if d > ui_tazer_detonate_radius:Get() then
        if now - combo.state_started < 0.45 then
            return
        end

        Emit(
            "TAZER_DETONATE_SKIPPED",
            "reason=target_outside_radius"
                .. " | distance=" .. tostring(math.floor(d))
                .. " | radius=" .. tostring(ui_tazer_detonate_radius:Get())
        )
        SetState(STATE.MAD, "target outside Tazer detonate radius")
        return
    end

    local stop = GetAbility(combo.hero, ABILITY_TAZER_STOP)
    if not stop then
        Emit("TAZER_DETONATE_FAILED", "reason=missing_stop_handle")
        SetState(STATE.MAD, "Tazer stop handle missing")
        return
    end

    local stop_ready = false
    local rv, rok = SafeCall(Ability.IsReady, stop)
    stop_ready = rok and rv and true or false

    if not stop_ready then
        if now - combo.state_started < 0.65 then
            return
        end

        Emit(
            "TAZER_DETONATE_FAILED",
            "reason=stop_not_ready"
                .. " | stop_cd=" .. tostring(AbilityCooldown(stop))
        )
        SetState(STATE.MAD, "Tazer detonate sub-ability not ready")
        return
    end

    combo.tazer_detonate_attempted = true
    combo.tazer_detonate_attempts = combo.tazer_detonate_attempts + 1

    local ok = pcall(
        Ability.CastNoTarget,
        stop,
        false,
        true,
        false,
        "techies-brain-tazer-detonate-"
            .. tostring(combo.tazer_detonate_attempts)
    )

    if not ok then
        Emit(
            "TAZER_DETONATE_FAILED",
            "reason=CastNoTarget_error"
                .. " | attempt=" .. tostring(combo.tazer_detonate_attempts)
        )
        if combo.tazer_detonate_attempts < 2 then
            combo.tazer_detonate_attempted = false
            return
        end
        SetState(STATE.MAD, "Tazer detonate request failed")
        return
    end

    combo.tazer_detonate_pending = {
        requested_at = now,
        verify_deadline = now + 0.40,
    }

    Emit(
        "TAZER_DETONATE_REQUEST",
        "ability=" .. ABILITY_TAZER_STOP
            .. " | distance=" .. tostring(math.floor(d))
            .. " | radius=" .. tostring(ui_tazer_detonate_radius:Get())
            .. " | buff_active=true"
            .. " | attempt=" .. tostring(combo.tazer_detonate_attempts)
    )
end

-- ---------------------------------------------------------------------------
-- M.A.D. placement.
--
-- Runtime evidence proved the handle/name. Real-match evidence also proved
-- that Aether Lens can make an inactive M.A.D. report a positive 225 cast
-- range, so positive cast range alone is NOT an active-Shard gate.
-- ---------------------------------------------------------------------------
local function MadActiveState(hero)
    local mad = GetAbility(hero, ABILITY_MAD)
    local det = GetAbility(hero, ABILITY_MAD_DETONATE)
    local det_level = AbilityLevel(det)
    local cast_range = AbilityCastRange(mad)

    -- RUNTIME_OBSERVED in the actual match:
    --   pre-Shard: focused_detonate level=0
    --   Shard-active controlled/runtime cases: focused_detonate level>0
    --
    -- Aether Lens can make otherwise zero-range M.A.D. report 225 range, so
    -- cast_range > 0 is NOT sufficient evidence that the active Shard component
    -- exists.
    local active = type(det_level) == "number" and det_level > 0

    return active, mad, det, det_level, cast_range
end

local function UpdateMad(now)
    if not ui_use_mad:Get() then
        Complete("proximity mines complete | M.A.D. disabled")
        return
    end

    if combo.mad_pending then
        local p = combo.mad_pending
        local mad_now = GetAbility(combo.hero, ABILITY_MAD)
        local det_now = GetAbility(combo.hero, ABILITY_MAD_DETONATE)

        local cd_now = AbilityCooldown(mad_now or p.ability)
        local ready_now = nil
        if mad_now then
            local rv, rok = SafeCall(Ability.IsReady, mad_now)
            if rok then ready_now = rv and true or false end
        end

        local det_level_now = AbilityLevel(det_now)
        local det_cd_now = AbilityCooldown(det_now)
        local det_ready_now = false
        if det_now then
            local rv, rok = SafeCall(Ability.IsReady, det_now)
            det_ready_now = rok and rv and true or false
        end

        local replaced = mad_now == nil
        local cooldown_started =
            p.cd_before ~= nil and cd_now ~= nil and cd_now > p.cd_before + 0.05
        local readiness_consumed =
            p.ready_before == true and ready_now == false
        local det_level_transition =
            (p.det_level_before == nil or p.det_level_before <= 0)
            and type(det_level_now) == "number"
            and det_level_now > 0
        local det_cooldown_started =
            p.det_cd_before ~= nil
            and det_cd_now ~= nil
            and det_cd_now > p.det_cd_before + 0.05

        local confirmed =
            replaced
            or cooldown_started
            or readiness_consumed
            or det_level_transition
            or det_cooldown_started

        if confirmed then
            combo.mad_pending = nil
            combo.mad_confirmed = true

            Emit(
                "MAD_CONFIRMED",
                "replaced=" .. tostring(replaced)
                    .. " | cooldown_started=" .. tostring(cooldown_started)
                    .. " | readiness_consumed=" .. tostring(readiness_consumed)
                    .. " | det_level_transition=" .. tostring(det_level_transition)
                    .. " | det_cooldown_started=" .. tostring(det_cooldown_started)
                    .. " | det_level=" .. tostring(det_level_now)
                    .. " | detonate_ready=" .. tostring(det_ready_now)
                    .. " | attempts=" .. tostring(combo.mad_retry_count + 1)
            )

            if ui_auto_detonate_mad:Get()
                and det_now
                and det_ready_now
                and not combo.mad_detonate_attempted
            then
                combo.mad_detonate_attempted = true
                if CastNoTarget(combo.hero, ABILITY_MAD_DETONATE) then
                    Emit(
                        "MAD_DETONATE_REQUEST",
                        "ability=" .. ABILITY_MAD_DETONATE
                    )
                else
                    Emit("MAD_DETONATE_FAILED", "request_failed")
                end
            end

            Complete("proximity mines complete | M.A.D. confirmed")
            return
        end

        if now >= p.verify_deadline then
            local active, ability, _, det_level, cast_range =
                MadActiveState(combo.hero)
            local hero_pos = GetPos(combo.hero)
            local target_pos = GetPos(combo.target)
            local d = Dist2D(hero_pos, target_pos)

            if combo.mad_retry_count < 1
                and active
                and ability
                and cast_range
                and d <= cast_range
            then
                combo.mad_retry_count = combo.mad_retry_count + 1
                combo.mad_pending = nil
                combo.mad_attempted = false

                Emit(
                    "MAD_RETRY",
                    "reason=unconfirmed_but_still_feasible"
                        .. " | retry=" .. tostring(combo.mad_retry_count)
                        .. " | distance=" .. tostring(math.floor(d))
                        .. " | cast_range=" .. tostring(math.floor(cast_range))
                        .. " | det_level=" .. tostring(det_level)
                )
                return
            end

            Emit(
                "MAD_UNCONFIRMED",
                "cd_before=" .. tostring(p.cd_before)
                    .. " | cd_now=" .. tostring(cd_now)
                    .. " | ready_now=" .. tostring(ready_now)
                    .. " | det_level_before=" .. tostring(p.det_level_before)
                    .. " | det_level_now=" .. tostring(det_level_now)
                    .. " | det_cd_before=" .. tostring(p.det_cd_before)
                    .. " | det_cd_now=" .. tostring(det_cd_now)
                    .. " | cast_point=" .. tostring(p.cast_point)
                    .. " | retries=" .. tostring(combo.mad_retry_count)
            )

            combo.mad_pending = nil
            Complete("proximity mines complete | M.A.D. unconfirmed")
        end
        return
    end

    if combo.mad_attempted then
        Complete("proximity mines complete | M.A.D. attempt finished")
        return
    end

    local active, ability, det, det_level, cast_range =
        MadActiveState(combo.hero)

    if not ability then
        combo.mad_attempted = true
        Emit("MAD_SKIPPED", "reason=missing_handle")
        Complete("proximity mines complete | M.A.D. unavailable")
        return
    end

    if not active then
        combo.mad_attempted = true
        Emit(
            "MAD_SKIPPED",
            "reason=shard_active_not_proven"
                .. " | detonate_level=" .. tostring(det_level)
                .. " | reported_cast_range=" .. tostring(cast_range)
        )
        Complete("proximity mines complete | M.A.D. passive only")
        return
    end

    local ready, _, reason = AbilityReady(combo.hero, ABILITY_MAD)
    if not ready then
        combo.mad_attempted = true
        Emit(
            "MAD_SKIPPED",
            "reason=" .. tostring(reason)
                .. " | detonate_level=" .. tostring(det_level)
        )
        Complete("proximity mines complete | M.A.D. not ready")
        return
    end

    if not cast_range or cast_range <= 0 then
        combo.mad_attempted = true
        Emit(
            "MAD_SKIPPED",
            "reason=active_subability_but_no_cast_range"
                .. " | detonate_level=" .. tostring(det_level)
        )
        Complete("proximity mines complete | M.A.D. missing cast range")
        return
    end

    local pos = GetPos(combo.target)
    local hero_pos = GetPos(combo.hero)
    if not pos or not hero_pos then
        combo.mad_attempted = true
        Emit("MAD_SKIPPED", "reason=missing_position")
        Complete("proximity mines complete | M.A.D. missing position")
        return
    end

    local d = Dist2D(hero_pos, pos)
    if d > cast_range then
        combo.mad_attempted = true
        Emit(
            "MAD_SKIPPED",
            "reason=out_of_range"
                .. " | distance=" .. tostring(math.floor(d))
                .. " | cast_range=" .. tostring(math.floor(cast_range))
        )
        Complete("proximity mines complete | M.A.D. out of range")
        return
    end

    combo.mad_attempted = true

    local cd_before = AbilityCooldown(ability)
    local cast_point = AbilityCastPoint(ability)
    local ready_before = true
    local det_level_before = AbilityLevel(det)
    local det_cd_before = AbilityCooldown(det)

    local ok = pcall(
        Ability.CastPosition,
        ability,
        pos,
        false,
        true,
        false,
        "techies-brain-mad-" .. tostring(combo.mad_retry_count + 1)
    )

    if ok then
        combo.mad_pending = {
            ability = ability,
            requested_at = now,
            cd_before = cd_before,
            ready_before = ready_before,
            cast_point = cast_point,
            det_level_before = det_level_before,
            det_cd_before = det_cd_before,
            verify_deadline = now + cast_point + 0.65,
        }

        Emit(
            "MAD_REQUEST",
            "distance=" .. tostring(math.floor(d))
                .. " | cast_range=" .. tostring(math.floor(cast_range))
                .. " | cast_point=" .. tostring(cast_point)
                .. " | cd_before=" .. tostring(cd_before)
                .. " | detonate_level=" .. tostring(det_level_before)
                .. " | attempt=" .. tostring(combo.mad_retry_count + 1)
        )
    else
        Emit(
            "MAD_REQUEST_FAILED",
            "CastPosition failed"
                .. " | attempt=" .. tostring(combo.mad_retry_count + 1)
        )

        if combo.mad_retry_count < 1 then
            combo.mad_retry_count = combo.mad_retry_count + 1
            combo.mad_attempted = false
            return
        end

        Complete("proximity mines complete | M.A.D. request failed")
    end
end

local function UpdateCombo()
    if not combo.active then return end

    local now = Now()
    local hero = GetLocalHero()

    if not ValidateHero(hero) then
        Abort("Techies unavailable/dead")
        return
    end

    combo.hero = hero

    if not combo.target or not IsAlive(combo.target) then
        Abort("target lost/dead")
        return
    end

    UpdateMotion(combo.target, now)

    local elapsed = now - combo.state_started

    -- ------------------------------------------------------------------------
    -- HEX — early control. Skip cleanly if not owned/ready.
    -- ------------------------------------------------------------------------
    if combo.state == STATE.HEX then
        if not ui_use_hex:Get() then
            SetState(STATE.STICKY, "hex disabled")
            return
        end

        local ready, item, reason = ItemReady(hero, ITEM_HEX)
        if not ready then
            Emit("HEX_SKIPPED", "reason=" .. tostring(reason))
            SetState(STATE.STICKY, "hex unavailable")
            return
        end

        local cast_range = SetupCastRange(item)
        local d = Dist2D(GetPos(hero), GetPos(combo.target))
        if cast_range and d > cast_range then
            Emit(
                "HEX_SKIPPED",
                "reason=out_of_range"
                    .. " | distance=" .. tostring(math.floor(d))
                    .. " | cast_range=" .. tostring(math.floor(cast_range))
            )
            SetState(STATE.STICKY, "hex out of range")
            return
        end

        local submitted, handle, cast_reason =
            CastItemTarget(hero, ITEM_HEX, combo.target)

        if submitted then
            -- Start the timing reference from order submission, not later
            -- cooldown confirmation. This is deliberately conservative: any
            -- verification delay consumes part of the 2.8s control budget.
            combo.hex_order_time = now
            BeginSetupVerification(
                "item_target",
                ITEM_HEX,
                handle,
                STATE.STICKY,
                "target=" .. UnitName(combo.target)
            )
            SetState(STATE.WAIT_HEX, "Hex submitted")
        else
            Emit("HEX_SKIPPED", "reason=" .. tostring(cast_reason))
            SetState(STATE.STICKY, "Hex request failed")
        end
        return
    end

    if combo.state == STATE.WAIT_HEX then
        local result = VerifySetup(now, "hex")
        if result == "confirmed" then
            combo.hex_confirmed = true
            combo.hex_confirm_time = now
            combo.hex_deadline =
                (combo.hex_order_time or now)
                + ui_hex_control_window_ms:Get() / 1000.0
            local reserve, cast_point, leap, safety = BlastImpactReserve(hero)
            Emit(
                "HEX_LOCK_STARTED",
                "window_ms=" .. tostring(ui_hex_control_window_ms:Get())
                    .. " | verify_delay_ms="
                    .. tostring(math.floor((now - (combo.hex_order_time or now)) * 1000))
                    .. " | blast_reserve_ms=" .. tostring(math.floor(reserve * 1000))
                    .. " | blast_cast_point_ms=" .. tostring(math.floor(cast_point * 1000))
                    .. " | blast_leap_ms=" .. tostring(math.floor(leap * 1000))
                    .. " | safety_ms=" .. tostring(math.floor(safety * 1000))
            )

            SetState(STATE.STICKY, "Hex confirmed; lock timer started")
        elseif result == "timeout" then
            SetState(STATE.STICKY, "Hex unconfirmed; continuing")
        end
        return
    end

    -- ------------------------------------------------------------------------
    -- Sticky Bomb
    -- ------------------------------------------------------------------------
    if combo.state == STATE.STICKY then
        if not ui_use_sticky:Get() then
            SetState(STATE.TAZER, "sticky disabled")
            return
        end

        local ability = GetAbility(hero, ABILITY_STICKY)
        if HexBudgetInsufficient(
            now,
            SetupTimeAllowance(ability),
            FutureEbladeAllowance(hero),
            "sticky"
        ) then
            -- Sticky is optional. Preserve the opportunity for Tazer/E-Blade;
            -- those states will independently re-check the shrinking budget.
            SetState(STATE.TAZER, "Hex budget tight; skipping Sticky")
            return
        end

        local target_pos = PredictedTargetPos(combo.target, 0.15)

        if CastPosition(hero, ABILITY_STICKY, target_pos) then
            BeginSetupVerification(
                "ability_position",
                ABILITY_STICKY,
                ability,
                STATE.TAZER,
                "target=" .. UnitName(combo.target)
            )
            SetState(STATE.WAIT_AFTER_STICKY, "sticky submitted")
        else
            Abort("Sticky Bomb cast failed")
        end
        return
    end

    if combo.state == STATE.WAIT_AFTER_STICKY then
        local result = VerifySetup(now, "sticky")
        if result == "confirmed" then
            combo.sticky_confirmed = true
            SetState(STATE.TAZER, "sticky confirmed")
        elseif result == "timeout" then
            local retries = combo.setup_retries.sticky or 0
            local ready = AbilityReady(hero, ABILITY_STICKY)

            if retries < 1 and ready then
                combo.setup_retries.sticky = retries + 1
                Emit(
                    "SETUP_RETRY",
                    "name=" .. ABILITY_STICKY
                        .. " | retry=" .. tostring(combo.setup_retries.sticky)
                )
                SetState(STATE.STICKY, "sticky unconfirmed; retrying once")
            else
                Abort("Sticky Bomb unconfirmed after retry budget")
            end
        end
        return
    end

    -- ------------------------------------------------------------------------
    -- Reactive Tazer
    -- ------------------------------------------------------------------------
    if combo.state == STATE.TAZER then
        if not ui_use_tazer:Get() then
            SetState(STATE.EBLADE, "tazer disabled")
            return
        end

        local tazer_for_budget = GetAbility(hero, ABILITY_TAZER)
        if HexBudgetInsufficient(
            now,
            SetupTimeAllowance(tazer_for_budget),
            FutureEbladeAllowance(hero),
            "tazer"
        ) then
            SetState(STATE.EBLADE, "Hex budget tight; skipping Tazer")
            return
        end

        local ready, ability, reason = AbilityReady(hero, ABILITY_TAZER)
        if not ready then
            Emit("TAZER_SKIPPED", "reason=" .. tostring(reason))
            SetState(STATE.EBLADE, "tazer unavailable")
            return
        end

        -- RUNTIME DIAGNOSIS:
        -- v0.2.2 submitted Ability.CastNoTarget successfully at the API level,
        -- but repeated live tests showed no visible Tazer buff and no
        -- modifier/cooldown confirmation. Current Techies Reactive Tazer is
        -- self/ally unit-targeted, so explicitly cast it on Techies.
        local submitted, tazer_handle, cast_reason = CastAbilityTarget(
            hero,
            ABILITY_TAZER,
            hero,
            "techies-brain-tazer-self"
        )

        if submitted then
            BeginSetupVerification(
                "ability_target_self",
                ABILITY_TAZER,
                tazer_handle or ability,
                STATE.EBLADE,
                "target=self"
                    .. " | cast_range="
                    .. tostring(AbilityCastRange(tazer_handle or ability))
            )
            SetState(STATE.WAIT_AFTER_TAZER, "tazer self-target submitted")
        else
            Emit("TAZER_CAST_FAILED", "reason=" .. tostring(cast_reason))
            SetState(STATE.EBLADE, "tazer self-target failed; skipped")
        end
        return
    end

    if combo.state == STATE.WAIT_AFTER_TAZER then
        local result = VerifySetup(now, "tazer")
        if result == "confirmed" then
            combo.tazer_confirmed = true
            SetState(STATE.EBLADE, "tazer confirmed")
        elseif result == "timeout" then
            local retries = combo.setup_retries.tazer or 0
            local ready = AbilityReady(hero, ABILITY_TAZER)

            if retries < 1 and ready then
                combo.setup_retries.tazer = retries + 1
                Emit(
                    "SETUP_RETRY",
                    "name=" .. ABILITY_TAZER
                        .. " | retry=" .. tostring(combo.setup_retries.tazer)
                )
                SetState(STATE.TAZER, "tazer unconfirmed; retrying once")
            else
                Emit(
                    "TAZER_VERIFY_FAILED",
                    "self_target_order_unconfirmed_after_retry_budget"
                )
                SetState(STATE.EBLADE, "tazer unconfirmed; continuing without proof")
            end
        end
        return
    end

    -- ------------------------------------------------------------------------
    -- ETHEREAL BLADE — intentionally LAST setup cast before Blast Off.
    -- ------------------------------------------------------------------------
    if combo.state == STATE.EBLADE then
        if not ui_use_eblade:Get() then
            SetState(STATE.BLAST, "E-Blade disabled")
            return
        end

        local eblade_for_budget = GetItem(hero, ITEM_EBLADE)
        if HexBudgetInsufficient(
            now,
            SetupTimeAllowance(eblade_for_budget),
            0.0,
            "eblade"
        ) then
            SetState(STATE.BLAST, "Hex budget critical; skipping E-Blade")
            return
        end

        local ready, item, reason = ItemReady(hero, ITEM_EBLADE)
        if not ready then
            Emit("EBLADE_SKIPPED", "reason=" .. tostring(reason))
            SetState(STATE.BLAST, "E-Blade unavailable")
            return
        end

        local cast_range = SetupCastRange(item)
        local d = Dist2D(GetPos(hero), GetPos(combo.target))
        if cast_range and d > cast_range then
            Emit(
                "EBLADE_SKIPPED",
                "reason=out_of_range"
                    .. " | distance=" .. tostring(math.floor(d))
                    .. " | cast_range=" .. tostring(math.floor(cast_range))
            )
            SetState(STATE.BLAST, "E-Blade out of range")
            return
        end

        local submitted, handle, cast_reason =
            CastItemTarget(hero, ITEM_EBLADE, combo.target)

        if submitted then
            BeginSetupVerification(
                "item_target",
                ITEM_EBLADE,
                handle,
                STATE.BLAST,
                "target=" .. UnitName(combo.target)
            )
            SetState(STATE.WAIT_EBLADE, "E-Blade submitted")
        else
            Emit("EBLADE_SKIPPED", "reason=" .. tostring(cast_reason))
            SetState(STATE.BLAST, "E-Blade request failed")
        end
        return
    end

    if combo.state == STATE.WAIT_EBLADE then
        local result = VerifySetup(now, "eblade")
        if result == "confirmed" then
            combo.eblade_confirmed = true
            SetState(STATE.BLAST, "E-Blade confirmed")
        elseif result == "timeout" then
            SetState(STATE.BLAST, "E-Blade unconfirmed; continuing")
        end
        return
    end

    -- ------------------------------------------------------------------------
    -- Blast Off — hard synchronization barrier.
    --
    -- Real-match rule:
    --   * Never permit a move-to-cast Blast request.
    --   * Never start the mine phase from elapsed time alone.
    --   * Require a positive ability-state transition AND real Techies motion.
    -- ------------------------------------------------------------------------
    if combo.state == STATE.BLAST then
        local ready, blast_ability, blast_reason =
            AbilityReady(hero, ABILITY_BLAST)

        if not ready or not blast_ability then
            Abort("Blast Off unavailable at commit | reason=" .. tostring(blast_reason))
            return
        end

        -- Final Hex-lock audit immediately before committing Blast Off. We do
        -- not abort if the window is already too small: at this point Blast is
        -- the fastest remaining action. The event tells us whether the chain
        -- mathematically expected Blast impact before or after our Hex budget.
        local hex_remaining = HexRemaining(now)
        if hex_remaining ~= nil then
            local reserve, cast_point, leap, safety = BlastImpactReserve(hero)
            Emit(
                "HEX_BLAST_COMMIT",
                "remaining_ms=" .. tostring(math.floor(hex_remaining * 1000))
                    .. " | reserve_ms=" .. tostring(math.floor(reserve * 1000))
                    .. " | expected_inside_hex=" .. tostring(hex_remaining > reserve)
                    .. " | cast_point_ms=" .. tostring(math.floor(cast_point * 1000))
                    .. " | leap_ms=" .. tostring(math.floor(leap * 1000))
                    .. " | safety_ms=" .. tostring(math.floor(safety * 1000))
            )
        end

        local aim_horizon = math.min(
            ui_max_prediction_horizon_ms:Get() / 1000.0,
            0.45
        )

        local blast_pos, used_horizon, cast_range, aim_distance, aim_reason =
            FindCastablePredictedPos(
                hero,
                combo.target,
                blast_ability,
                aim_horizon
            )

        if not blast_pos then
            Emit(
                "BLAST_BLOCKED",
                "reason=" .. tostring(aim_reason)
                    .. " | current_distance="
                    .. tostring(math.floor(Dist2D(GetPos(hero), GetPos(combo.target))))
                    .. " | cast_range=" .. tostring(cast_range)
            )
            Abort("Blast Off destination not immediately castable")
            return
        end

        combo.blast_start_pos = GetPos(hero)
        combo.blast_anchor = blast_pos
        combo.blast_ability = blast_ability
        combo.blast_cd_before = AbilityCooldown(blast_ability)
        combo.blast_since_before = SecondsSinceLastUse(blast_ability)
        combo.blast_phase_seen = false
        combo.blast_confirmed = false
        combo.blast_motion_without_confirm_logged = false

        if not FreezeMinePlan(hero, combo.target, blast_pos) then
            Abort("failed to freeze mine plan")
            return
        end

        local ok = pcall(
            Ability.CastPosition,
            blast_ability,
            blast_pos,
            false,
            true,
            false,
            "techies-brain-blast"
        )

        if not ok then
            Abort("Blast Off cast request failed")
            return
        end

        combo.blast_order_time = now

        Emit(
            "BLAST_REQUEST",
            "distance=" .. tostring(math.floor(aim_distance))
                .. " | cast_range=" .. tostring(math.floor(cast_range))
                .. " | prediction_horizon_ms="
                .. tostring(math.floor(used_horizon * 1000))
                .. " | cd_before=" .. tostring(combo.blast_cd_before)
                .. " | since_before=" .. tostring(combo.blast_since_before)
        )

        SetState(STATE.WAIT_AIRBORNE, "Blast Off submitted; awaiting positive confirmation")
        return
    end

    -- ------------------------------------------------------------------------
    -- Detect a REAL Blast Off execution.
    -- ------------------------------------------------------------------------
    if combo.state == STATE.WAIT_AIRBORNE then
        local ability = GetAbility(hero, ABILITY_BLAST) or combo.blast_ability
        local current_pos = GetPos(hero)
        local moved = Dist2D(combo.blast_start_pos, current_pos)
        local threshold = ui_airborne_detect_distance:Get()
        local wait_elapsed =
            combo.blast_order_time and (now - combo.blast_order_time) or 0.0

        local cd_now = AbilityCooldown(ability)
        local in_phase = AbilityInPhase(ability)
        local since_now = SecondsSinceLastUse(ability)

        local ready_now = nil
        if ability then
            local rv, rok = SafeCall(Ability.IsReady, ability)
            if rok then ready_now = rv and true or false end
        end

        if in_phase then
            combo.blast_phase_seen = true
        end

        local cooldown_started =
            combo.blast_cd_before ~= nil
            and cd_now ~= nil
            and cd_now > combo.blast_cd_before + 0.05

        local last_use_advanced =
            since_now ~= nil
            and since_now >= 0
            and (
                combo.blast_since_before == nil
                or combo.blast_since_before < 0
                or since_now < combo.blast_since_before
            )

        local ability_state_positive =
            cooldown_started
            or ready_now == false
            or last_use_advanced

        if ability_state_positive and not combo.blast_confirmed then
            combo.blast_confirmed = true
            Emit(
                "BLAST_CONFIRMED",
                "cooldown_started=" .. tostring(cooldown_started)
                    .. " | phase_seen=" .. tostring(combo.blast_phase_seen)
                    .. " | ready_now=" .. tostring(ready_now)
                    .. " | since_now=" .. tostring(since_now)
                    .. " | moved=" .. tostring(math.floor(moved))
            )
        end

        if moved >= threshold and combo.blast_confirmed then
            combo.airborne_start = now
            combo.predicted_land_time =
                now + ui_air_window_ms:Get() / 1000.0
            combo.mine_progress_deadline =
                now + math.max(1.0, ui_post_land_window_ms:Get() / 1000.0)

            SetState(
                STATE.AIRBORNE_MINES,
                "Blast confirmed + motion " .. tostring(math.floor(moved)) .. "u"
            )

            local first_pos = combo.mine_plan and combo.mine_plan[1] or nil
            if first_pos then
                local mine_ability = GetAbility(hero, ABILITY_MINES)
                Emit(
                    "AIRBORNE_PLAN",
                    "mine1_distance="
                        .. tostring(math.floor(Dist2D(GetPos(hero), first_pos)))
                        .. " | mine_cast_range="
                        .. tostring(math.floor(AbilityCastRange(mine_ability) or -1))
                        .. " | frozen_anchor=true"
                        .. " | ring_radius=" .. tostring(ui_mine_ring_radius:Get())
                        .. " | forward_bias=" .. tostring(ui_forward_bias:Get())
                )
            end

            return
        end

        if moved >= threshold
            and not combo.blast_confirmed
            and not combo.blast_motion_without_confirm_logged
        then
            combo.blast_motion_without_confirm_logged = true
            Emit(
                "BLAST_MOTION_WITHOUT_CONFIRM",
                "moved=" .. tostring(math.floor(moved))
                    .. " | cd_now=" .. tostring(cd_now)
                    .. " | in_phase=" .. tostring(in_phase)
                    .. " | ready_now=" .. tostring(ready_now)
                    .. " | since_now=" .. tostring(since_now)
            )
        end

        local cast_point = AbilityCastPoint(ability)
        local timeout = math.max(
            ui_airborne_fallback_ms:Get() / 1000.0,
            cast_point + 0.80,
            1.30
        )

        if wait_elapsed >= timeout then
            Emit(
                "BLAST_UNCONFIRMED",
                "elapsed_ms=" .. tostring(math.floor(wait_elapsed * 1000))
                    .. " | timeout_ms=" .. tostring(math.floor(timeout * 1000))
                    .. " | moved=" .. tostring(math.floor(moved))
                    .. " | cooldown_started=" .. tostring(cooldown_started)
                    .. " | phase_seen=" .. tostring(combo.blast_phase_seen)
                    .. " | ready_now=" .. tostring(ready_now)
                    .. " | cd_now=" .. tostring(cd_now)
                    .. " | since_now=" .. tostring(since_now)
            )
            Abort("Blast Off execution not positively confirmed")
        end
        return
    end

    -- ------------------------------------------------------------------------
    -- Attempt Proximity Mines DURING Blast Off travel.
    -- ------------------------------------------------------------------------
    if combo.state == STATE.AIRBORNE_MINES then
        local desired = combo.desired_mines or ui_mine_count:Get()

        if combo.mines_placed < desired or combo.pending_mine then
            TryAirMine(now)
        end

        if combo.mines_placed >= desired and not combo.pending_mine then
            TransitionAfterMines(
                "all proximity mines CONFIRMED"
                    .. " | confirmed=" .. tostring(combo.mines_placed)
            )
            return
        end

        if combo.predicted_land_time and now >= combo.predicted_land_time then
            if ui_post_land_fallback:Get() then
                SetState(
                    STATE.POST_LAND_MINES,
                    "air window ended with "
                        .. tostring(combo.mines_placed)
                        .. "/"
                        .. tostring(desired)
                        .. " CONFIRMED mines"
                )
                if not combo.mine_progress_deadline then
                    combo.mine_progress_deadline =
                        now + math.max(1.0, ui_post_land_window_ms:Get() / 1000.0)
                end
            else
                Complete(
                    "air window ended; fallback disabled"
                        .. " | confirmed=" .. tostring(combo.mines_placed)
                )
            end
        end
        return
    end

    -- ------------------------------------------------------------------------
    -- Fallback: finish any mine that was requested but not ACTUALLY consumed.
    -- ------------------------------------------------------------------------
    if combo.state == STATE.POST_LAND_MINES then
        local desired = combo.desired_mines or ui_mine_count:Get()

        if combo.mines_placed < desired or combo.pending_mine then
            TryAirMine(now)
        end

        if combo.mines_placed >= desired and not combo.pending_mine then
            TransitionAfterMines(
                "all proximity mines CONFIRMED after fallback"
                    .. " | confirmed=" .. tostring(combo.mines_placed)
            )
            return
        end

        -- Never leave for M.A.D. while a mine request is still waiting for
        -- verification; that was the deterministic v0.2.0 mine-#3 cancellation.
        if combo.pending_mine then
            return
        end

        local deadline = combo.mine_progress_deadline
            or (combo.state_started + ui_post_land_window_ms:Get() / 1000.0)

        if now >= deadline then
            TransitionAfterMines(
                "mine progress timeout"
                    .. " | confirmed=" .. tostring(combo.mines_placed)
                    .. "/" .. tostring(desired)
            )
        end
        return
    end

    -- ------------------------------------------------------------------------
    -- Explicitly detonate the self-cast Reactive Tazer AFTER mines, while
    -- Techies is already on top of the Blast Off target. This preserves the
    -- now-proven airborne mine order and puts Tazer's magical burst before M.A.D.
    -- ------------------------------------------------------------------------
    if combo.state == STATE.TAZER_DETONATE then
        UpdateTazerDetonate(now)
        return
    end

    -- ------------------------------------------------------------------------
    -- Plant M.A.D. after Proximity Mine handling. If the request starts while
    -- airborne and has a long cast point, verification is allowed to complete
    -- after Blast Off lands. No later mine order can cancel it.
    -- ------------------------------------------------------------------------
    if combo.state == STATE.MAD then
        UpdateMad(now)
        return
    end
end

-- ============================================================================
-- Debug overlay
-- ============================================================================

local function DrawWorldLabel(pos, text, color)
    if not pos or not Render or not Render.WorldToScreen or not Render.Text then
        return
    end

    local screen, visible = Render.WorldToScreen(pos)
    if not screen then return end
    if visible ~= nil and not visible then return end

    local font = GetDebugFont()
    if not font then return end

    pcall(
        Render.Text,
        font,
        15,
        text,
        screen,
        color or Color(255, 255, 255)
    )
end

local function DrawOverlay()
    if not ui_debug_overlay:Get() then return end

    local hero = GetLocalHero()
    if not ValidateHero(hero) then return end

    local hero_pos = GetPos(hero)
    if not hero_pos then return end

    local screen, visible = Render.WorldToScreen(hero_pos)
    if screen and (visible == nil or visible) then
        local target_name = combo.target and UnitName(combo.target) or "-"
        local remaining_ms = 0

        if combo.predicted_land_time then
            remaining_ms = math.max(
                0,
                math.floor((combo.predicted_land_time - Now()) * 1000)
            )
        end

        local text =
            "Techies Combo: " .. tostring(combo.state)
            .. " | target=" .. target_name
            .. " | setup="
            .. (combo.hex_confirmed and "H" or "-")
            .. (combo.sticky_confirmed and "S" or "-")
            .. (combo.tazer_confirmed and "T" or "-")
            .. (combo.tazer_detonate_confirmed and "D" or "-")
            .. (combo.eblade_confirmed and "E" or "-")
            .. " | mines=" .. tostring(combo.mines_placed)
            .. "/" .. tostring(combo.desired_mines or ui_mine_count:Get())
            .. (combo.pending_mine and " (pending)" or "")
            .. " | mad=" .. (combo.mad_confirmed and "confirmed" or (combo.mad_pending and "pending" or "no"))
            .. " | hex=" .. tostring(math.max(0, math.floor((HexRemaining(Now()) or 0) * 1000))) .. "ms"
            .. " | air=" .. tostring(remaining_ms) .. "ms"

        local font = GetDebugFont()
        if font then
            pcall(
                Render.Text,
                font,
                16,
                text,
                screen + Vec2(0, -65),
                Color(0, 255, 255)
            )
        end
    end

    if combo.active and combo.target and IsAlive(combo.target) then
        if combo.blast_anchor then
            DrawWorldLabel(
                combo.blast_anchor,
                "FROZEN BLAST ANCHOR",
                Color(255, 220, 0)
            )
        end

        if combo.mine_plan then
            for i = combo.mines_placed + 1, (combo.desired_mines or ui_mine_count:Get()) do
                local mine_pos = combo.mine_plan[i]
                if mine_pos then
                    DrawWorldLabel(
                        mine_pos,
                        "M" .. tostring(i),
                        Color(255, 80, 80)
                    )
                end
            end
        end
    end
end

-- ============================================================================
-- Callbacks
-- ============================================================================

function techies.OnUpdateEx()
    if not ui_enable:Get() then
        if combo.active then
            Abort("script disabled")
        end
        combo_key_was_down = false
        return
    end

    local hero = GetLocalHero()
    if not ValidateHero(hero) then
        if combo.active then
            Abort("not Techies")
        end
        combo_key_was_down = false
        return
    end

    -- RUNTIME-PROVEN Lina pattern: poll IsDown() and derive the rising edge.
    -- Holding SPACE starts exactly one combo. Releasing SPACE does not cancel
    -- an in-flight combo.
    local key_down = KeyDown(ui_combo_key)
    local press_edge = key_down and not combo_key_was_down

    if press_edge then
        Emit("KEY_DOWN", "combo key press detected")

        if not ability_probe_done then
            ProbeHeroAbilities(hero)
            ability_probe_done = true
        end

        if not combo.active then
            StartCombo()
        else
            Emit("KEY_IGNORED", "combo already active")
        end
    end

    combo_key_was_down = key_down

    if combo.active then
        UpdateCombo()
    end
end

function techies.OnDraw()
    DrawOverlay()
end

function techies.OnGameEnd()
    if combo.active then
        Abort("game ended")
    end
    combo_key_was_down = false
    ClearCombo()
end

return techies
