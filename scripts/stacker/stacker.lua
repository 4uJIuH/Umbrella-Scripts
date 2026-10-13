local Stacker = {}

-- Menu variables
local m_enabled, m_key_toggle, m_show_hud = nil, nil, nil
-- Illusion / movable HUD options (populated in SetupMenu)
local m_use_illusions, m_lock_hud = nil, nil
local m_hud_drag_modifier = nil
-- Theme / color menu items (populated in SetupMenu)
local m_color, m_rainbow, m_rainbow_speed, m_pastel = nil, nil, nil, nil

-- Movable HUD state. Position persists across frames; the drag is engaged by
-- holding the configurable "Drag HUD" bind (default ALT) while the cursor is
-- over the panel.
local hud_pos       = Vec2(70, 450)
local hud_dragging  = false
local hud_drag_off  = Vec2(0, 0)
local hud_last_size = Vec2(220, 70) -- updated every OnDraw, used for hit-test

-- Script state variables
local script_enabled_by_menu = false
local logic_enabled_by_bind = false

-- Active stack zone and selected camp (single-camp mode: Beast / KotL / Enigma / Invoker)
local active_stack_zone = nil
local selected_camp = nil

-- Multi-camp assignments (Furion / Brood): each bind press toggles an
-- individual camp, and a free summon is assigned to it. Other active camps
-- are untouched, so the player can stack many camps in parallel.
--   key   = zone_name .. ":" .. camp_id   (string, stable identity for a camp)
--   value = unit_idx                       (Entity.GetIndex of the assigned summon)
local multi_assignments = {}

-- Per-frame cache, populated in OnUpdate and reused in OnDraw on the same
-- frame so we don't walk NPCs.GetAll() twice per tick. Keyed by game time to
-- invalidate automatically if OnDraw runs without a fresh OnUpdate (paused,
-- replay scrub, etc.).
local frame_cache = { time = -1, hero = nil, current_hero = nil, summons = nil }

-- Timing variables
local lastOrderTime = 0
local states = {}
-- lastOrderPos: tracks where we last told the unit to go, to detect drift
-- lastOrderType: "move" or "attack", to avoid re-issuing same order
local lastOrderPos = {}
local lastOrderType = {}

-- Key edge tracking (kept local to avoid leaking into globals)
local lastKeyStatus = false

-- Logging function
local function Log(message)
    if client and client.chat and client.chat.print then
        client.chat.print(message)
    elseif GameRules and GameRules.ChatMessage then
        GameRules.ChatMessage(0, "Debug", message)
    else
        print(message)
    end
end

-- Menu setup
local function SetupMenu()
    if m_enabled ~= nil then return end

    local root = Menu.Create("Scripts", "Stacker", "ST")
    if not root then return end

    local settings_group = root:Create("Settings")
    if not settings_group then return end

    local logic_group = settings_group:Create("Stacker Logic")
    if not logic_group then return end

    m_enabled = logic_group:Switch("Enable Script", false)
    m_key_toggle = logic_group:Bind("Toggle Logic", Enum.ButtonCode.KEY_B)
    m_show_hud = logic_group:Switch("Show HUD", true)
    m_use_illusions = logic_group:Switch("Stack with Illusions", true)
    m_lock_hud = logic_group:Switch("Lock HUD Position", false)
    -- Drag is engaged with the configurable modifier (default ALT) plus
    -- left-mouse on the panel. The click is read directly from the input
    -- system because Bind widgets in UC's API only accept keyboard keys as
    -- a default value, not mouse buttons.
    pcall(function()
        m_hud_drag_modifier = logic_group:Bind("Drag HUD Modifier", Enum.ButtonCode.KEY_LALT)
    end)

    -- Visual theme controls. Wrapped in pcall so missing menu types in
    -- older API builds never break the whole script.
    pcall(function()
        if logic_group.ColorPicker then
            m_color = logic_group:ColorPicker("Color", Color(89, 119, 239, 255))
        end
        if logic_group.Switch then
            m_rainbow = logic_group:Switch("Rainbow", false)
            m_pastel  = logic_group:Switch("Pastel (soft colors)", true)
        end
        if logic_group.Slider then
            -- 1 = very slow (~full cycle in 60s), 20 = fast (~3s)
            m_rainbow_speed = logic_group:Slider("Rainbow Speed", 1, 20, 3)
        elseif logic_group.SliderInt then
            m_rainbow_speed = logic_group:SliderInt("Rainbow Speed", 1, 20, 3)
        end
    end)

    Log("Menu Setup complete.")
end

-- Menu value getter
local function GetVal(item)
    if not item or not item.Get then return false end
    return item:Get()
end

-- HSV->RGB. h in [0,1], s in [0,1], v in [0,1]. Returns three ints in [0,255].
local function HSVtoRGB(h, s, v)
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)
    local r, g, b
    local mod = i % 6
    if     mod == 0 then r, g, b = v, t, p
    elseif mod == 1 then r, g, b = q, v, p
    elseif mod == 2 then r, g, b = p, v, t
    elseif mod == 3 then r, g, b = p, q, v
    elseif mod == 4 then r, g, b = t, p, v
    else                 r, g, b = v, p, q
    end
    return math.floor(r * 255 + 0.5),
           math.floor(g * 255 + 0.5),
           math.floor(b * 255 + 0.5)
end

-- Produces the accent color used by every visual element. Priority:
--   1. Rainbow on  -> HSV cycled by game time, saturation/value tuned by Pastel
--   2. Rainbow off -> user-picked color from the menu (or default blue)
-- Alpha is forced to 255 for "solid" callers; a second helper accepts override.
local DEFAULT_ACCENT = { r = 89, g = 119, b = 239, a = 255 }

local function GetStackerColor(alpha)
    alpha = alpha or 255
    if GetVal(m_rainbow) then
        -- Speed: 1 = 60s cycle, 20 = 3s cycle. speed_val / 60 Hz per second.
        local speed = 3
        if m_rainbow_speed and m_rainbow_speed.Get then speed = m_rainbow_speed:Get() or 3 end
        if type(speed) ~= "number" or speed < 1 then speed = 1 end
        local t = 0
        if GameRules and GameRules.GetGameTime then
            t = GameRules.GetGameTime() or 0
        end
        local cycle_seconds = 60 / speed   -- speed=1 -> 60s, speed=20 -> 3s
        local h = (t / cycle_seconds) % 1
        local sat, val
        if GetVal(m_pastel) then
            -- Soft, muted colors - pastel look as requested
            sat = 0.35
            val = 0.95
        else
            sat = 0.85
            val = 1.0
        end
        local r, g, b = HSVtoRGB(h, sat, val)
        return Color(r, g, b, alpha)
    end

    if m_color and m_color.Get then
        local ok, c = pcall(function() return m_color:Get() end)
        if ok and c then
            -- Some UC builds return a Color userdata, others return a table
            -- with r/g/b/a fields. Normalize both.
            if type(c) == "userdata" then
                return c
            end
            local r = c.r or c[1] or DEFAULT_ACCENT.r
            local g = c.g or c[2] or DEFAULT_ACCENT.g
            local b = c.b or c[3] or DEFAULT_ACCENT.b
            local a = c.a or c[4] or alpha
            return Color(r, g, b, a)
        end
    end
    return Color(DEFAULT_ACCENT.r, DEFAULT_ACCENT.g, DEFAULT_ACCENT.b, alpha)
end

-- Send move order ONLY if unit has drifted from target (or no order was sent yet)
-- Returns true if order was issued
local function SendMoveIfNeeded(idx, unit, target_pos)
    local unit_pos = Entity.GetAbsOrigin(unit)
    local dist_to_target = (unit_pos - target_pos):Length2D()

    -- Already close enough, no order needed
    if dist_to_target < 75 then return false end

    local last_pos = lastOrderPos[idx]
    if last_pos then
        local dist_from_last_order = (target_pos - last_pos):Length2D()
        -- Same destination was already ordered and unit is still moving there
        if dist_from_last_order < 10 then return false end
    end

    -- New destination or unit drifted � issue order once
    Player.PrepareUnitOrders(Players.GetLocal(), Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION, nil, target_pos, nil, Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, unit)
    lastOrderPos[idx] = target_pos
    lastOrderType[idx] = "move"
    return true
end

-- Send attack order ONLY if we haven't already ordered this unit to attack (once per state entry)
local function SendAttackOnce(idx, unit, creep)
    if lastOrderType[idx] == "attack" then return false end
    Player.PrepareUnitOrders(Players.GetLocal(), Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET, creep, Vector(0,0,0), nil, Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, unit)
    lastOrderType[idx] = "attack"
    lastOrderPos[idx] = nil
    return true
end

-- Call this whenever state changes, resets order tracking for the unit
local function ResetOrderState(idx)
    lastOrderPos[idx] = nil
    lastOrderType[idx] = nil
end

-- Read a neutral's HP defensively. Used by the state 2 / state 4 attack
-- branches to detect the INSTANT a hit lands (HP dropped) and bail
-- immediately to the next state, instead of waiting out a fixed timer.
-- Uses pcall because different UC builds expose GetHealth via either
-- Entity or NPC namespaces.
local function TryGetHealth(npc)
    if not npc then return nil end
    if Entity and Entity.GetHealth then
        local ok, hp = pcall(Entity.GetHealth, npc)
        if ok and type(hp) == "number" then return hp end
    end
    if NPC and NPC.GetHealth then
        local ok, hp = pcall(NPC.GetHealth, npc)
        if ok and type(hp) == "number" then return hp end
    end
    return nil
end

-- Wipe all per-unit state. Use when the stacker is turned off or when the
-- selected camp changes mid-flow - otherwise a unit that was e.g. in state 3
-- for camp A will keep marching toward camp A's partner wait-pos even after
-- the user re-selected camp B.
local function ClearAllUnitState()
    states = {}
    lastOrderPos = {}
    lastOrderType = {}
    multi_assignments = {}
end

-- Furion / Broodmother / hero illusions all operate in multi-camp mode: each
-- bind press toggles one camp independently and a random idle controllable
-- summon (or illusion) is assigned to it. Other heroes keep the classic
-- single-select behaviour.
local function IsMultiCampHero(hero_type)
    return hero_type == "Furion" or hero_type == "Brood" or hero_type == "Illusion"
end

local function AssignmentKey(zone_name, camp_id)
    return tostring(zone_name) .. ":" .. tostring(camp_id)
end

-- Detect whether the local player currently controls any hero illusion. Used
-- to fall back to "Illusion" multi-camp mode when the hero itself does not
-- have a dedicated stacker (PA, CK, Naga, Spectre, Phantom Lancer, TB, etc.).
-- Walks Heroes.GetAll() instead of NPCs.GetAll() because the hero list is
-- ~10-20 entries even in late game vs hundreds of NPCs.
local function HasControllableIllusion(hero)
    if not hero then return false end
    local pid = Hero.GetPlayerID(hero)
    if not pid then return false end
    local heroes = Heroes.GetAll()
    for i = 1, #heroes do
        local h = heroes[i]
        if h and h ~= hero and Entity.IsAlive(h)
           and NPC.IsIllusion(h) and NPC.IsControllableByPlayer(h, pid) then
            return true
        end
    end
    return false
end

-- Hero detection
local function GetCurrentHero()
    local hero = Heroes.GetLocal()
    if not hero then
        return nil
    end
    local hero_name = NPC.GetUnitName(hero)
    if hero_name then
        if hero_name:find("beastmaster") then
            return "Beast"
        elseif hero_name:find("keeper_of_the_light") then
            return "KotL"
        elseif hero_name:find("enigma") then
            return "Enigma"
        elseif hero_name:find("invoker") then
            return "Invoker"
        elseif hero_name:find("furion") then
            return "Furion"
        elseif hero_name:find("broodmother") then
            return "Brood"
        end
    end
    -- No dedicated stacker for this hero. If the user opted into illusion
    -- stacking AND the hero currently has any controllable illusion, treat
    -- the player as a multi-camp "Illusion" stacker. Falls through to nil
    -- otherwise so the rest of the script noops cleanly.
    if GetVal(m_use_illusions) and HasControllableIllusion(hero) then
        return "Illusion"
    end
    return nil
end

-- Single place to decide whether a given NPC is a "stackable" summon for the
-- current hero. Keeps OnUpdate, OnDraw, FindFreeSummonFor, etc. in sync.
local function IsSummonForHero(n, hero, name, current_hero)
    if current_hero == "Beast"    then return name:find("wolf") ~= nil or name:find("boar") ~= nil
    elseif current_hero == "KotL"     then return n == hero
    elseif current_hero == "Enigma"   then return name:find("eidolon") ~= nil
    elseif current_hero == "Invoker"  then return name:find("forge_spirit") ~= nil or name:find("forge") ~= nil
    elseif current_hero == "Furion"   then return name:find("treant") ~= nil and n ~= hero
    elseif current_hero == "Brood"    then return name:find("spiderling") ~= nil or name:find("spiderite") ~= nil
    elseif current_hero == "Illusion" then
        -- Any controllable hero illusion (excluding the real local hero).
        -- NPCs.GetAll already returns CNPCs, NPC.IsHero is true for both real
        -- heroes and illusions, so we lean on NPC.IsIllusion to keep the real
        -- hero out of the summon list.
        return n ~= hero and NPC.IsHero(n) and NPC.IsIllusion(n)
    end
    return false
end

-- Collect the list of controllable stackable summons for the local player.
-- Shared by OnUpdate (logic) and OnDraw (visuals) so they can never disagree.
local function CollectSummons(hero, current_hero)
    local out = {}
    if not hero or not current_hero then return out end
    local pid = Hero.GetPlayerID(hero)
    local all = NPCs.GetAll()
    for i = 1, #all do
        local n = all[i]
        if n and Entity.IsAlive(n) and NPC.IsControllableByPlayer(n, pid) then
            local name = NPC.GetUnitName(n) or ""
            local idx  = Entity.GetIndex(n)
            if idx and idx ~= 0 and IsSummonForHero(n, hero, name, current_hero) then
                table.insert(out, {u = n, idx = idx})
            end
        end
    end
    return out
end

-- Configuration for camps
local CampConfig = {
    ["Radiant"] = {
        -- Beastmaster camps
        [1] = {
            CampCenter = Vector(-4859, -44, 256),
            WaitPos = Vector(-4497, 195, 256),
            RunPos = Vector(-3347, -324, 256),
            HitTime = 53,
            IsDoubleStack = true,
            PartnerCamp = 2
        },
        [2] = {
            CampCenter = Vector(-4118, 882, 256),
            WaitPos = Vector(-4280, 522, 256),
            RunPos = Vector(-3347, -324, 256),
            HitTime = 55,
            IsDoubleStack = true,
            PartnerCamp = 1
        },
        -- Keeper of the Light camps
        [3] = {
            CampCenter = Vector(-1999, -4739, 128),
            WaitPos = Vector(-1235, -3867, 135),
            RunPos = Vector(-229, -4561, 136),
            HitTime = 51.9,
            IsDoubleStack = true,
            PartnerCamp = 4,
            HeroType = "KotL"
        },
        [4] = {
            CampCenter = Vector(-1450, -3339, 128),
            WaitPos = Vector(-1235, -3867, 135),
            RunPos = Vector(-229, -4561, 136),
            HitTime = 55,
            IsDoubleStack = true,
            PartnerCamp = 3,
            HeroType = "KotL"
        },
        -- Enigma camps (same as Beastmaster)
        [5] = {
            CampCenter = Vector(-4859, -44, 256),
            WaitPos = Vector(-4497, 195, 256),
            RunPos = Vector(-3347, -324, 256),
            HitTime = 53,
            IsDoubleStack = true,
            PartnerCamp = 6,
            HeroType = "Enigma"
        },
        [6] = {
            CampCenter = Vector(-4118, 882, 256),
            WaitPos = Vector(-4280, 522, 256),
            RunPos = Vector(-3347, -324, 256),
            HitTime = 55,
            IsDoubleStack = true,
            PartnerCamp = 5,
            HeroType = "Enigma"
        },
        -- Invoker camps (same as Beastmaster/Enigma but optimized wait positions)
        [7] = {
            CampCenter = Vector(-4859, -44, 256),
            WaitPos = Vector(-4587, 135, 256),  -- Optimized distance from Camp One
            RunPos = Vector(-3347, -324, 256),
            HitTime = 53,
            IsDoubleStack = true,
            PartnerCamp = 8,
            HeroType = "Invoker"
        },
        [8] = {
            CampCenter = Vector(-4118, 882, 256),
            WaitPos = Vector(-4239, 612, 256),  -- Optimized distance from Camp One
            RunPos = Vector(-3347, -324, 256),
            HitTime = 55,
            IsDoubleStack = true,
            PartnerCamp = 7,
            HeroType = "Invoker"
        },
        -- Beastmaster second zone (bottom camps, single stack each)
        [9] = {
            CampCenter = Vector(-1464, -3297, 128),
            WaitPos = Vector(-1379, -3948, 128),
            RunPos = Vector(-349, -3552, 136),
            HitTime = 55,
            IsDoubleStack = false
        },
        [10] = {
            CampCenter = Vector(-2004, -4749, 128),
            WaitPos = Vector(-1459, -4720, 128),
            RunPos = Vector(-465, -4682, 136),
            HitTime = 55,
            IsDoubleStack = false
        },
        -- Beastmaster third zone (double stack, Radiant far bottom)
        [11] = {
            CampCenter = Vector(4435, -8378, 0),
            WaitPos = Vector(3946, -8119, 8),
            RunPos = Vector(3692, -7163, 0),
            HitTime = 55,
            IsDoubleStack = true,
            PartnerCamp = 12
        },
        [12] = {
            CampCenter = Vector(2821, -8277, 8),
            WaitPos = Vector(3350, -8200, 8),
            RunPos = Vector(3692, -7163, 0),
            HitTime = 57,
            IsDoubleStack = true,
            PartnerCamp = 11
        },
        -- ====================================================================
        -- Furion / Broodmother camps (Radiant side, x < 0)
        -- HitTime is written_in_spec + 1s because Treants / Spiderlings are slow
        -- (spec: 53 -> 54, 55 -> 56).
        -- ====================================================================
        [100] = {
            CampCenter = Vector(-1420, -3312, 128),
            WaitPos    = Vector(-1309,  -3769,  128),
            RunPos     = Vector(-285,  -3582, 134),
            HitTime = 55, IsDoubleStack = false, HeroType = "Slow"
        },
        [101] = {
            CampCenter = Vector(-1951, -4803, 128),
            WaitPos    = Vector(-1484,  -4752,  128),
            RunPos     = Vector(-534,  -4647, 136),
            HitTime = 55, IsDoubleStack = false, HeroType = "Slow"
        },
        [102] = {
            CampCenter = Vector(-5020, -35,   256),
            WaitPos    = Vector(-4561,  66,  256),
            RunPos     = Vector(-3501, -257,  256),
            HitTime = 53, IsDoubleStack = false, HeroType = "Slow"
        },
        [103] = {
            CampCenter = Vector(-4011, 1027,  256),
            WaitPos    = Vector(-3905,  569,  256),
            RunPos     = Vector(-3566, -248,  256),
            HitTime = 53, IsDoubleStack = false, HeroType = "Slow"
        },
        [104] = {
            CampCenter = Vector(-8052, -1794, 256),
            WaitPos    = Vector(-7776,  -1413,  256),
            RunPos     = Vector(-6634, -1356, 128),
            HitTime = 55, IsDoubleStack = false, HeroType = "Slow"
        },
        [105] = {
            CampCenter = Vector(-8335, -511,  256),
            WaitPos    = Vector(-7949,  -243,  256),
            RunPos     = Vector(-7980, 706,   0),
            HitTime = 55, IsDoubleStack = false, HeroType = "Slow"
        },
        [106] = {
            CampCenter = Vector(-4827, 3994,  128),
            WaitPos    = Vector(-5270,  4150,  128),
            RunPos     = Vector(-6188, 3891,  128),
            HitTime = 55, IsDoubleStack = false, HeroType = "Slow"
        },
        [107] = {
            CampCenter = Vector(-3909, 4892,  128),
            WaitPos    = Vector(-4362,  5016,  128),
            RunPos     = Vector(-5319, 4885,  128),
            HitTime = 55, IsDoubleStack = false, HeroType = "Slow"
        },
        [108] = {
            CampCenter = Vector(-696,  -7676, 134),
            WaitPos    = Vector(-1091,  -7931,  136),
            RunPos     = Vector(-1598, -7817, 136),
            HitTime = 55, IsDoubleStack = false, HeroType = "Slow"
        },
        [109] = {
            CampCenter = Vector(-2417, -8395, 128),
            WaitPos    = Vector(-2409,  -7925,  141),
            RunPos     = Vector(-2464, -7406, 136),
            HitTime = 55, IsDoubleStack = false, HeroType = "Slow"
        },
        [110] = {
            CampCenter = Vector(-4207, 8379,  0),
            WaitPos    = Vector(-4081,  7926,  14),
            RunPos     = Vector(-3994, 6995,  128),
            HitTime = 55, IsDoubleStack = false, HeroType = "Slow"
        },
        [111] = {
            CampCenter = Vector(-2881, 7363,  0),
            WaitPos    = Vector(-2677,  7786,  8),
            RunPos     = Vector(-2052, 7893,  8),
            HitTime = 55, IsDoubleStack = false, HeroType = "Slow"
        },
        [112] = {
            CampCenter = Vector(-860,  4954,  136),
            WaitPos    = Vector(-1218,  4650,  136),
            RunPos     = Vector(-1826, 4329,  256),
            HitTime = 55, IsDoubleStack = false, HeroType = "Slow"
        },
        [113] = {
            CampCenter = Vector(-2590, 3869,  256),
            WaitPos    = Vector(-2679,  4330,  256),
            RunPos     = Vector(-2728, 4798,  256),
            HitTime = 55, IsDoubleStack = false, HeroType = "Slow"
        }
    },
    ["Dire"] = {
        -- Beastmaster camps
        [1] = {
            CampCenter = Vector(4276, 106, 256),
            WaitPos = Vector(3905, -300, 256),
            RunPos = Vector(4411, -1443, 128),
            HitTime = 52,
            IsDoubleStack = true,
            PartnerCamp = 2
        },
        [2] = {
            CampCenter = Vector(3425, -1289, 256),
            WaitPos = Vector(3567, -915, 256),
            RunPos = Vector(4411, -1443, 128),
            HitTime = 55,
            IsDoubleStack = true,
            PartnerCamp = 1
        },
        -- Keeper of the Light camps
        [3] = {
            CampCenter = Vector(1261, 4251, 128),
            WaitPos = Vector(700, 2981, 134),
            RunPos = Vector(196, 3706, 136),
            HitTime = 51.9,
            IsDoubleStack = true,
            PartnerCamp = 4,
            HeroType = "KotL"
        },
        [4] = {
            CampCenter = Vector(1010, 2625, 128),
            WaitPos = Vector(700, 2981, 134),
            RunPos = Vector(196, 3706, 136),
            HitTime = 55,
            IsDoubleStack = true,
            PartnerCamp = 3,
            HeroType = "KotL"
        },
        -- Enigma camps (same as Beastmaster)
        [5] = {
            CampCenter = Vector(4276, 106, 256),
            WaitPos = Vector(3905, -300, 256),
            RunPos = Vector(4411, -1443, 128),
            HitTime = 53,
            IsDoubleStack = true,
            PartnerCamp = 6,
            HeroType = "Enigma"
        },
        [6] = {
            CampCenter = Vector(3425, -1289, 256),
            WaitPos = Vector(3567, -915, 256),
            RunPos = Vector(4411, -1443, 128),
            HitTime = 55,
            IsDoubleStack = true,
            PartnerCamp = 5,
            HeroType = "Enigma"
        },
        -- Invoker camps (same as Beastmaster/Enigma but optimized wait positions)
        [7] = {
            CampCenter = Vector(4276, 106, 256),
            WaitPos = Vector(3997, -198, 256),  -- Optimized distance from Camp One
            RunPos = Vector(4411, -1443, 128),
            HitTime = 53,
            IsDoubleStack = true,
            PartnerCamp = 8,
            HeroType = "Invoker"
        },
        [8] = {
            CampCenter = Vector(3425, -1289, 256),
            WaitPos = Vector(3531, -1008, 256),  -- Optimized distance from Camp One
            RunPos = Vector(4411, -1443, 128),
            HitTime = 55,
            IsDoubleStack = true,
            PartnerCamp = 7,
            HeroType = "Invoker"
        },
        -- Beastmaster second zone (top camps, single stack each)
        [9] = {
            CampCenter = Vector(1066, 2599, 128),
            WaitPos = Vector(929, 3020, 144),
            RunPos = Vector(309, 3653, 136),
            HitTime = 55,
            IsDoubleStack = false
        },
        [10] = {
            CampCenter = Vector(1244, 4261, 128),
            WaitPos = Vector(701, 4094, 141),
            RunPos = Vector(-220, 4175, 136),
            HitTime = 55,
            IsDoubleStack = false
        },
        -- Beastmaster third zone (double stack, Dire far top)
        [11] = {
            CampCenter = Vector(-2889, 7450, 0),
            WaitPos = Vector(-3515, 7718, 8),
            RunPos = Vector(-3979, 7059, 128),
            HitTime = 55,
            IsDoubleStack = true,
            PartnerCamp = 12
        },
        [12] = {
            CampCenter = Vector(-4200, 8333, 0),
            WaitPos = Vector(-3850, 8050, 8),
            RunPos = Vector(-3979, 7059, 128),
            HitTime = 57,
            IsDoubleStack = true,
            PartnerCamp = 11
        },
        -- ====================================================================
        -- Furion / Broodmother camps (Dire side, x >= 0)
        -- HitTime is written_in_spec + 1s because Treants / Spiderlings are slow
        -- (spec: 53 -> 54, 55 -> 56).
        -- ====================================================================
        [100] = {
            CampCenter = Vector(188,   -5162, 136),
            WaitPos    = Vector(68,  -4708,  136),
            RunPos     = Vector(232,   -4364, 136),
            HitTime = 55, IsDoubleStack = false, HeroType = "Slow"
        },
        [101] = {
            CampCenter = Vector(1902,  -3944, 256),
            WaitPos    = Vector(1685,  -4361,  256),
            RunPos     = Vector(1518,  -4731, 256),
            HitTime = 55, IsDoubleStack = false, HeroType = "Slow"
        },
        [102] = {
            CampCenter = Vector(3990,  -4990, 128),
            WaitPos    = Vector(4261,  -5374,  128),
            RunPos     = Vector(4137,  -6066, 128),
            HitTime = 55, IsDoubleStack = false, HeroType = "Slow"
        },
        [103] = {
            CampCenter = Vector(4649,  -3696, 128),
            WaitPos    = Vector(4888,  -4101,  128),
            RunPos     = Vector(5762,  -3848, 128),
            HitTime = 55, IsDoubleStack = false, HeroType = "Slow"
        },
        [104] = {
            CampCenter = Vector(4393,  -8371, 0),
            WaitPos    = Vector(4233,  -7929,  10),
            RunPos     = Vector(4095,  -7447, 8),
            HitTime = 55, IsDoubleStack = false, HeroType = "Slow"
        },
        [105] = {
            CampCenter = Vector(2745,  -8287, 8),
            WaitPos    = Vector(2736,  -7817,  8),
            RunPos     = Vector(2711,  -7468, 8),
            HitTime = 55, IsDoubleStack = false, HeroType = "Slow"
        },
        [106] = {
            CampCenter = Vector(4363,  126,   256),
            WaitPos    = Vector(4031,  -206,  256),
            RunPos     = Vector(4058,  -1123, 225),
            HitTime = 53, IsDoubleStack = false, HeroType = "Slow"
        },
        [107] = {
            CampCenter = Vector(3400,  -1378, 256),
            WaitPos    = Vector(3260,  -929,  256),
            RunPos     = Vector(2757,  110,   171),
            HitTime = 53, IsDoubleStack = false, HeroType = "Slow"
        },
        [108] = {
            CampCenter = Vector(7931,  -84,   256),
            WaitPos    = Vector(8400,  -60,  256),
            RunPos     = Vector(8244,  -888,  0),
            HitTime = 55, IsDoubleStack = false, HeroType = "Slow"
        },
        [109] = {
            CampCenter = Vector(8483,  1329,  256),
            WaitPos    = Vector(8031,  1199,  256),
            RunPos     = Vector(7440,  648,   136),
            HitTime = 55, IsDoubleStack = false, HeroType = "Slow"
        },
        [110] = {
            CampCenter = Vector(1201,  4197,  128),
            WaitPos    = Vector(740,  4103,  128),
            RunPos     = Vector(77,    4107,  136),
            HitTime = 55, IsDoubleStack = false, HeroType = "Slow"
        },
        [111] = {
            CampCenter = Vector(1056,  2662,  128),
            WaitPos    = Vector(1279,  3076,  128),
            RunPos     = Vector(1545,  3432,  128),
            HitTime = 55, IsDoubleStack = false, HeroType = "Slow"
        },
        [112] = {
            CampCenter = Vector(384,   7769,  134),
            WaitPos    = Vector(419,  7300,  136),
            RunPos     = Vector(508,   6850,  128),
            HitTime = 55, IsDoubleStack = false, HeroType = "Slow"
        },
        [113] = {
            CampCenter = Vector(2016,  7912,  128),
            WaitPos    = Vector(1586,  7722,  128),
            RunPos     = Vector(888,   7207,  136),
            HitTime = 55, IsDoubleStack = false, HeroType = "Slow"
        }
    }
}

local function GetCreepStrict(campCenter)
    local hero = Heroes.GetLocal()
    if not hero then return nil end
    local enemies = NPCs.InRadius(campCenter, 450, Entity.GetTeamNum(hero), Enum.TeamType.TEAM_ENEMY)
    for _, npc in ipairs(enemies) do
        if NPC.IsCreep(npc) and Entity.IsAlive(npc) then return npc end
    end
    return nil
end

-- Inter font from ogre_magi script
local inter_font = nil
local function safe_call(fn, ...)
    if not fn then return nil end
    local ok, result = pcall(fn, ...)
    if ok then return result end
    return nil
end

-- Initialize Inter font
pcall(function()
    inter_font = Render.LoadFont("Inter", Enum.FontCreate.FONTFLAG_ANTIALIAS, 500)
end)

-- Visual rendering functions
local function DrawSenseBox(position, countdown_text)
    local screen_pos, is_visible = position:ToScreen()
    if not is_visible then return end

    local font = inter_font or Render.LoadFont("Inter", 14, Enum.FontCreate.FONTFLAG_ANTIALIAS, 500)
    local padding = Vec2(12, 6)
    local topBarHeight = 3
    local cornerRadius = 4

    local text_size = Render.TextSize(font, 14, countdown_text)
    local box_width = text_size.x + padding.x * 2
    local box_height = text_size.y + padding.y * 2 + topBarHeight

    local box_start = screen_pos - Vec2(box_width/2, box_height/2)
    local box_end = screen_pos + Vec2(box_width/2, box_height/2)

    Render.FilledRect(box_start, box_end, Color(17, 17, 17, 240), cornerRadius)

    local topBar_end = Vec2(box_end.x, box_start.y + topBarHeight)
    Render.FilledRect(box_start, topBar_end, GetStackerColor(), cornerRadius)

    local text_pos = Vec2(box_start.x + padding.x, box_start.y + topBarHeight + padding.y)
    Render.Text(font, 14, countdown_text, text_pos, Color(255, 255, 255, 255))
end

local function DrawTracerLine(unit, from_pos, to_pos, color, target_box)
    if not unit or not from_pos or not to_pos then return end

    local from_screen, from_visible = from_pos:ToScreen()
    local to_screen, to_visible = to_pos:ToScreen()

    -- Always draw tracer regardless of screen boundaries (only check if points are valid)
    if from_visible and to_visible then
        color = color or GetStackerColor()

        -- If targeting a box, adjust to box edge as shown in reference image
        if target_box then
            local box_height = 30  -- Approximate height of sense box
            local box_edge = Vec2(to_screen.x, to_screen.y - box_height/2)
            Render.Line(from_screen, box_edge, color, 2)
        else
            Render.Line(from_screen, to_screen, color, 2)
        end
    end
end

local function DrawBoarStatus(unit, target)
    if not unit or not target then return end

    local unit_pos = Entity.GetAbsOrigin(unit)
    local target_pos = target

    local unit_screen, unit_visible = unit_pos:ToScreen()
    local target_screen, target_visible = target_pos:ToScreen()

    if not unit_visible or not target_visible then return end

    local idx = Entity.GetIndex(unit)
    local status = "Waiting"

    -- Determine status based on unit state
    if states[idx] then
        local s = states[idx]
        if s.state == 0 then
            status = "Running"
        elseif s.state == 1 then
            status = "Waiting"
        elseif s.state == 2 then
            status = "Pulling"
        elseif s.state == 3 or s.state == 4 then
            status = "Pulling"
        elseif s.state == 5 or s.state == 6 or s.state == 7 then
            status = "Running"
        end
    end

    -- Plain white color for status text
    local font = inter_font or Render.LoadFont("Inter", 14, Enum.FontCreate.FONTFLAG_ANTIALIAS, 500)
    local text_size = Render.TextSize(font, 14, status)
    local mid_point = Vec2((unit_screen.x + target_screen.x) / 2, (unit_screen.y + target_screen.y) / 2)
    Render.Text(font, 14, status, mid_point - Vec2(text_size.x/2, text_size.y/2), Color(255, 255, 255, 255))
end

local function DrawGroundCircle(world_pos, radius, color, label)
    -- Draw ground-flat circle like beta stacker script
    local points = {}
    for i = 0, 40 do
        local angle = i * (math.pi * 2) / 40
        local circle_world_pos = world_pos + Vector(math.cos(angle) * radius, math.sin(angle) * radius, 0)
        local screen_pos, visible = circle_world_pos:ToScreen()
        if visible then table.insert(points, screen_pos) end
    end

    -- Draw circle outline by connecting points
    for i = 1, #points - 1 do
        Render.Line(points[i], points[i+1], color, 2)
    end

    -- Draw label
    local font = inter_font or Render.LoadFont("Inter", 12, Enum.FontCreate.FONTFLAG_ANTIALIAS, 500)
    local text_size = Render.TextSize(font, 12, label)
    local center_screen, _ = world_pos:ToScreen()
    if center_screen then
        local text_pos = Vec2(center_screen.x - text_size.x/2, center_screen.y - radius - 20)
        Render.Text(font, 12, label, text_pos, color)
    end
end

local function DrawStopMarker(run_pos, is_complete)
    local radius = 20  -- Size similar to Boar
    local color = is_complete and Color(0, 255, 0, 255) or GetStackerColor()
    local label = is_complete and "Complete" or "STOP"

    DrawGroundCircle(run_pos, radius, color, label)
end

local function DrawWaitMarker(wait_pos)
    local radius = 20  -- Same size as STOP marker
    local color = GetStackerColor()

    DrawGroundCircle(wait_pos, radius, color, "WAIT")
end

-- Draw countdown box(es) for a single camp and, if it is part of a double
-- stack, for its partner camp as well.
local function DrawCampCountdown(zone_name, camp)
    local gameTime = (GameRules.GetGameTime() - GameRules.GetGameStartTime()) % 60
    if gameTime < 0 then gameTime = 0 end
    local seconds = math.floor(gameTime)

    local function drawOne(c)
        local countdown = c.HitTime - seconds
        if countdown < 0 then countdown = 60 + countdown end
        DrawSenseBox(c.CampCenter, tostring(countdown) .. "s")
    end

    drawOne(camp)
    if camp.IsDoubleStack and camp.PartnerCamp then
        local zone = CampConfig[zone_name]
        local partner = zone and zone[camp.PartnerCamp]
        if partner then drawOne(partner) end
    end
end

local function DrawStackingVisuals()
    -- Single-camp selection (Beast / KotL / Enigma / Invoker)
    if active_stack_zone and selected_camp then
        local zone = CampConfig[active_stack_zone]
        local camp = zone and zone[selected_camp]
        if camp then DrawCampCountdown(active_stack_zone, camp) end
    end

    -- Multi-camp assignments (Furion / Brood) - draw countdowns for every
    -- active camp independently.
    for key, _ in pairs(multi_assignments) do
        local zone_name, camp_id_str = key:match("^(.-):(%-?%d+)$")
        local camp_id = tonumber(camp_id_str)
        local zone = zone_name and CampConfig[zone_name]
        local camp = zone and camp_id and zone[camp_id]
        if camp then DrawCampCountdown(zone_name, camp) end
    end
end

-- Handle camp selection based on cursor position (single-camp mode only:
-- Beast / KotL / Enigma / Invoker). Furion and Broodmother are routed to
-- ToggleMultiCampAtCursor instead.
local function HandleCampSelection()
    if not logic_enabled_by_bind then return end

    if active_stack_zone and selected_camp then
        active_stack_zone = nil
        selected_camp = nil
        logic_enabled_by_bind = false
        ClearAllUnitState()  -- wipe stale per-unit progress from previous selection
        return
    end

    local mouse_pos = Input.GetWorldCursorPos()
    local closest_dist = math.huge
    local closest_zone = nil
    local closest_camp = nil
    local current_hero = GetCurrentHero()

    local function check(zone, camp_id, center)
        local dist = (mouse_pos - center):Length2D()
        if dist < closest_dist then
            closest_dist = dist
            closest_zone = zone
            closest_camp = camp_id
        end
    end

    if current_hero == "Beast" then
        check("Radiant", 1,  Vector(-4488, 419, 256))
        check("Radiant", 9,  Vector(-1464, -3297, 128))
        check("Radiant", 10, Vector(-2004, -4749, 128))
        check("Radiant", 11, Vector(3628, -7748, 0))
        check("Dire",    1,  Vector(3850, -591, 256))
        check("Dire",    9,  Vector(1066, 2599, 128))
        check("Dire",    10, Vector(1244, 4261, 128))
        check("Dire",    11, Vector(-3545, 7892, 0))
    elseif current_hero == "KotL" then
        check("Radiant", 3,  Vector(-1724, -4039, 128))
        check("Dire",    3,  Vector(1135, 3438, 128))
    elseif current_hero == "Enigma" then
        check("Radiant", 5,  Vector(-4488, 419, 256))
        check("Dire",    5,  Vector(3850, -591, 256))
    elseif current_hero == "Invoker" then
        check("Radiant", 7,  Vector(-4488, 419, 256))
        check("Dire",    7,  Vector(3850, -591, 256))
    end

    if closest_zone and closest_camp then
        -- Always wipe per-unit state when entering a new selection so that no
        -- stale state from a previous camp (e.g. "moving to partner X") leaks
        -- into the new camp's state machine.
        ClearAllUnitState()
        active_stack_zone = closest_zone
        selected_camp = closest_camp
        logic_enabled_by_bind = true
    else
        -- Nothing close to the cursor matches the current hero. Don't leave
        -- the bind hanging in "on" state with no selection - that forces the
        -- user to double-tap to retry.
        logic_enabled_by_bind = false
    end
end

-- Picks one controllable summon (Treant for Furion / Spiderling-Spiderite
-- for Brood) that is NOT already assigned to another camp. Returns
-- (unit, idx) or (nil, nil) if none is available.
local function FindFreeSummonFor(hero_type)
    local hero = Heroes.GetLocal()
    if not hero then return nil, nil end
    local assigned = {}
    for _, idx in pairs(multi_assignments) do assigned[idx] = true end
    local summons = CollectSummons(hero, hero_type)
    for i = 1, #summons do
        local s = summons[i]
        if not assigned[s.idx] then return s.u, s.idx end
    end
    return nil, nil
end

-- Toggle a single camp assignment under the mouse cursor. Used for Furion
-- and Broodmother: pressing the bind on camp A toggles ONLY camp A - any
-- other active camps keep running their own assigned units.
local function ToggleMultiCampAtCursor(current_hero)
    local mouse_pos = Input.GetWorldCursorPos()
    local closest_dist = math.huge
    local closest_zone, closest_camp = nil, nil
    for zone_name, zone in pairs(CampConfig) do
        for camp_id, c in pairs(zone) do
            if c.HeroType == "Slow" then
                local dist = (mouse_pos - c.CampCenter):Length2D()
                if dist < closest_dist then
                    closest_dist = dist
                    closest_zone = zone_name
                    closest_camp = camp_id
                end
            end
        end
    end
    -- Ignore clicks that aren't meaningfully close to any camp (half a camp
    -- spacing ~= 1500 units). Prevents a stray click in the fog / minimap
    -- from accidentally toggling a random camp.
    if not closest_zone or closest_dist > 1500 then return end

    local key = AssignmentKey(closest_zone, closest_camp)
    if multi_assignments[key] then
        -- Toggle OFF: free the unit and reset its state machine so it stops
        -- mid-flow. Other active camps are untouched.
        local old_idx = multi_assignments[key]
        multi_assignments[key] = nil
        if old_idx then
            states[old_idx] = nil
            lastOrderPos[old_idx] = nil
            lastOrderType[old_idx] = nil
        end
    else
        -- Toggle ON: grab any free summon and bind it to this camp. If the
        -- player hasn't summoned enough Treants / Spiderlings yet, we simply
        -- leave the camp inactive until one becomes available.
        local _, free_idx = FindFreeSummonFor(current_hero)
        if free_idx then
            multi_assignments[key] = free_idx
        end
    end

    -- Keep the global "logic running" flag in sync with whether there is any
    -- active assignment. OnUpdate uses this flag to decide whether to tick
    -- the stacking logic at all.
    logic_enabled_by_bind = (next(multi_assignments) ~= nil)
end

-- Per-(unit, camp) state machine. Extracted from HandleStackingLogic so that
-- multiple (Furion treant / Broodmother spiderling) units can each run an
-- independent state machine against their OWN assigned camp in parallel.
-- `zone_name` is the CampConfig key ("Radiant"/"Dire"), `camp` is the resolved
-- camp table.
local function RunUnitStateMachine(idx, unit, zone_name, camp)
    if not camp or not zone_name then return end

    if not states[idx] then
        states[idx] = {state = 0, timer = 0}
        ResetOrderState(idx)
    end
    local s = states[idx]

    -- Helper: transition to a new state cleanly. Clears per-state aux
    -- fields so the HP-drop tracker from state 2 / 4 never leaks into
    -- a later cycle (which used to cause a false "hit landed" bail the
    -- very next time the unit re-entered state 2).
    local function GoToState(new_state)
        s.state = new_state
        s.timer = 0
        s.target_creep     = nil
        s.creep_start_hp   = nil
        s.partner_creep    = nil
        s.partner_start_hp = nil
        ResetOrderState(idx)
    end

    -- Reset if unit completed cycle and is idle for too long
    if s.state == 7 then
        s.timer = s.timer + 1
        if s.timer > 180 then
            states[idx] = {state = 0, timer = 0}
            lastOrderPos[idx] = nil
            lastOrderType[idx] = nil
            s = states[idx]
        end
        return  -- Nothing to do in final state except wait for reset
    end

    local is_kotl    = (camp.HeroType == "KotL")
    local is_invoker = (camp.HeroType == "Invoker")

    local unit_pos = Entity.GetAbsOrigin(unit)

    if s.state == 0 then
        -- Send to wait position once
        SendMoveIfNeeded(idx, unit, camp.WaitPos)
        GoToState(1)

    elseif s.state == 1 then
        -- En route to wait position; re-issue if drifted, then wait for timing.
        -- IMPORTANT: once HitTime is reached we fire the attack REGARDLESS of
        -- whether the unit has perfectly arrived at WaitPos. Previously, if the
        -- unit stopped ~150-200 units short (pathing quirk, terrain, idle
        -- aggro), it would hang forever because the "at WaitPos" check gated
        -- the attack. The attack order itself makes the unit path into range.
        local dist = (unit_pos - camp.WaitPos):Length2D()
        local gameTime = (GameRules.GetGameTime() - GameRules.GetGameStartTime()) % 60
        if gameTime < 0 then gameTime = 0 end
        local seconds = math.floor(gameTime)
        -- Brood's spiderlings are melee (range 100) + walk ~370 units from
        -- WaitPos before they can even start attack-point. Give them a 1s
        -- head-start so the aggro hit still lands before the stack deadline.
        local current_hero_for_timing = GetCurrentHero()
        local effective_hit_time = camp.HitTime
        if current_hero_for_timing == "Brood" then
            effective_hit_time = camp.HitTime - 1
        end
        local at_hit_time = (seconds >= effective_hit_time)

        if is_kotl then
            if at_hit_time then
                local hero = Heroes.GetLocal()
                if hero then
                    -- Prefer name lookup because Spirit Form / Aghanim layouts
                    -- shuffle KotL's ability slots and slot 0 is not guaranteed
                    -- to be Illuminate.
                    local illuminate =
                        (NPC.GetAbility and NPC.GetAbility(hero, "keeper_of_the_light_illuminate")) or
                        (NPC.GetAbility and NPC.GetAbility(hero, "keeper_of_the_light_spirit_form_illuminate")) or
                        NPC.GetAbilityByIndex(hero, 0)
                    if illuminate then
                        Player.PrepareUnitOrders(Players.GetLocal(), Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION, nil, camp.CampCenter, illuminate, Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, hero)
                        GoToState(2)
                    end
                end
            elseif dist > 150 then
                SendMoveIfNeeded(idx, unit, camp.WaitPos)
            end
        else
            if at_hit_time then
                local creep = GetCreepStrict(camp.CampCenter)
                if creep then
                    SendAttackOnce(idx, unit, creep)
                    GoToState(2)
                    -- Lock onto this specific creep so state 2 doesn't jump
                    -- between targets between ticks (which caused phantom HP
                    -- drops and a too-early bail out of state 2).
                    s.target_creep   = creep
                    s.creep_start_hp = TryGetHealth(creep)
                else
                    -- No creep visible. Two reasons this can happen:
                    --   a) the camp hasn't been scouted yet and the creeps are
                    --      in the fog (NPCs.InRadius only returns visible
                    --      entities, so GetCreepStrict returns nil);
                    --   b) the camp is genuinely empty (someone else pulled
                    --      it, or it never spawned).
                    -- Walk the summon TOWARD CampCenter to pierce the fog.
                    -- SendMoveIfNeeded dedupes so this is issued once, and as
                    -- soon as the creep enters the summon's vision we'll hit
                    -- the `if creep` branch next tick and attack.
                    SendMoveIfNeeded(idx, unit, camp.CampCenter)
                    -- Tick counter: if still nothing visible after ~6s, bail
                    -- to RunPos so the summon doesn't hang forever on an
                    -- empty camp.
                    s.timer = (s.timer or 0) + 1
                    if s.timer > 180 then
                        SendMoveIfNeeded(idx, unit, camp.RunPos)
                        GoToState(5)
                    end
                end
            elseif dist > 150 then
                SendMoveIfNeeded(idx, unit, camp.WaitPos)
            end
        end

    elseif s.state == 2 then
        if is_kotl then
            -- Wait until ~55s then attack second camp
            local gameTime = (GameRules.GetGameTime() - GameRules.GetGameStartTime()) % 60
            if gameTime < 0 then gameTime = 0 end
            if math.floor(gameTime) >= 55 then
                local partner_camp = CampConfig[zone_name][camp.PartnerCamp]
                if partner_camp then
                    local creep = GetCreepStrict(partner_camp.CampCenter)
                    if creep then
                        SendAttackOnce(idx, unit, creep)
                        GoToState(4)
                    else
                        SendMoveIfNeeded(idx, unit, camp.RunPos)
                        GoToState(5)
                    end
                end
            end
        else
            -- Beast/Enigma/Invoker/Furion/Brood: agro camp 1, then move to camp 2.
            -- Prefer the creep we originally locked onto in state 1 (so we track
            -- its HP stably). Only fall back to GetCreepStrict if that creep
            -- died / became untargetable - in which case we re-snapshot HP.
            local creep = s.target_creep
            if not creep or not Entity.IsAlive(creep) then
                creep = GetCreepStrict(camp.CampCenter)
                s.target_creep   = creep
                s.creep_start_hp = nil
            end
            if not creep then
                -- Creep agro'd - head to partner camp (double-stack) or finish (single-stack)
                if camp.IsDoubleStack and camp.PartnerCamp then
                    local partner_camp = CampConfig[zone_name][camp.PartnerCamp]
                    if partner_camp then
                        SendMoveIfNeeded(idx, unit, partner_camp.WaitPos)
                        GoToState(3)
                    else
                        SendMoveIfNeeded(idx, unit, camp.RunPos)
                        GoToState(5)
                    end
                else
                    SendMoveIfNeeded(idx, unit, camp.RunPos)
                    GoToState(5)
                end
            else
                -- Creep still at spawn. Two ways to exit this state optimally:
                --   1. PRIMARY - HP-drop detection: snapshot creep HP on the
                --      first tick, bail the moment HP drops (hit landed).
                --      Zero wasted ticks; unit starts its next order as soon
                --      as damage registers.
                --   2. FALLBACK - per-hero timer sized to the unit's "walk
                --      into range + attack point" budget. Covers the cases
                --      where HP API is unavailable, creep is untargetable for
                --      an instant, or unit was body-blocked.
                --
                -- Ticks budgeted @ 30 fps, from state-2 entry to safe bail
                -- (walk distance assumes WaitPos at 470 from CampCenter):
                --   Treant     range 125, MS 300: ~345 walk + 0.30 AP = 1.45s \
                --                                                          > 50t
                --   Spiderling range 100, MS 350: ~370 walk + 0.30 AP = 1.36s /
                --   Boar       range 550, MS 340: in range + 0.50 AP = 0.5s  -> 20t
                --   Eidolon    range 500, MS 370: in range + 0.30 AP = 0.3s  -> 15t
                --   Forge Sp.  range 365, MS 320: ~105 walk + 0.40 AP = 0.73s -> 25t
                -- All below one BAT so we never clip a 2nd swing.
                SendAttackOnce(idx, unit, creep)
                s.timer = s.timer + 1

                -- Primary bail: did the creep take damage yet?
                if s.creep_start_hp == nil then
                    s.creep_start_hp = TryGetHealth(creep)
                end
                local hit_landed = false
                if s.creep_start_hp then
                    local cur_hp = TryGetHealth(creep)
                    if cur_hp and cur_hp < s.creep_start_hp then
                        hit_landed = true
                    end
                end

                -- Fallback: per-hero worst-case walk + AP
                local max_wait
                local ht = camp.HeroType
                if     ht == "Slow"    then max_wait = 50
                elseif ht == "Beast"   then max_wait = 20
                elseif ht == "Enigma"  then max_wait = 15
                elseif ht == "Invoker" then max_wait = 25
                else                        max_wait = 30
                end

                if hit_landed or s.timer > max_wait then
                    if camp.IsDoubleStack and camp.PartnerCamp then
                        local partner_camp = CampConfig[zone_name][camp.PartnerCamp]
                        if partner_camp then
                            SendMoveIfNeeded(idx, unit, partner_camp.WaitPos)
                            GoToState(3)
                        end
                    else
                        SendMoveIfNeeded(idx, unit, camp.RunPos)
                        GoToState(5)
                    end
                end
            end
        end

    elseif s.state == 3 then
        -- Moving to partner camp wait position
        local partner_camp = CampConfig[zone_name][camp.PartnerCamp]
        if partner_camp then
            local dist = (unit_pos - partner_camp.WaitPos):Length2D()
            if dist < 80 then
                -- Arrived - attack or bail
                local creep = GetCreepStrict(partner_camp.CampCenter)
                if creep then
                    SendAttackOnce(idx, unit, creep)
                    GoToState(4)
                    -- Lock on for HP-drop tracking
                    s.partner_creep    = creep
                    s.partner_start_hp = TryGetHealth(creep)
                else
                    SendMoveIfNeeded(idx, unit, partner_camp.RunPos)
                    GoToState(6)
                end
            else
                -- Still moving - re-issue only if drifted
                SendMoveIfNeeded(idx, unit, partner_camp.WaitPos)
            end
        end

    elseif s.state == 4 then
        -- Attacking partner camp. Same "HP-drop first, per-hero timeout
        -- second" strategy as state 2 so the unit never wastes a tick
        -- after landing its aggro hit.
        local partner_camp = CampConfig[zone_name][camp.PartnerCamp]
        if partner_camp then
            -- Lock on a specific partner creep; re-acquire only if it dies
            local creep = s.partner_creep
            if not creep or not Entity.IsAlive(creep) then
                creep = GetCreepStrict(partner_camp.CampCenter)
                s.partner_creep    = creep
                s.partner_start_hp = nil
            end
            if not creep then
                SendMoveIfNeeded(idx, unit, partner_camp.RunPos)
                GoToState(6)
            else
                SendAttackOnce(idx, unit, creep)
                s.timer = s.timer + 1

                -- Primary: HP-drop detection on the locked creep
                if s.partner_start_hp == nil then
                    s.partner_start_hp = TryGetHealth(creep)
                end
                local hit_landed = false
                if s.partner_start_hp then
                    local cur_hp = TryGetHealth(creep)
                    if cur_hp and cur_hp < s.partner_start_hp then
                        hit_landed = true
                    end
                end

                -- Fallback timer. KotL is the hero itself (AP 0.48 +
                -- projectile from ~470 ~0.52s = ~1.0s to land), everyone
                -- else was budgeted the same as state 2.
                local limit
                local ht = camp.HeroType
                if     ht == "KotL"    then limit = 35
                elseif ht == "Slow"    then limit = 50
                elseif ht == "Beast"   then limit = 20
                elseif ht == "Enigma"  then limit = 15
                elseif ht == "Invoker" then limit = 25
                else                        limit = 30
                end

                if hit_landed or s.timer > limit then
                    SendMoveIfNeeded(idx, unit, partner_camp.RunPos)
                    GoToState(6)
                end
            end
        end

    elseif s.state == 5 or s.state == 6 then
        -- Running to finish point
        local run_pos
        if s.state == 5 then
            run_pos = camp.RunPos
        elseif camp.PartnerCamp then
            local partner_camp = CampConfig[zone_name][camp.PartnerCamp]
            if partner_camp then run_pos = partner_camp.RunPos end
        end
        -- Safety: if partner is missing for some reason, fall back to camp.RunPos
        if not run_pos then run_pos = camp.RunPos end

        SendMoveIfNeeded(idx, unit, run_pos)
        if (unit_pos - run_pos):Length2D() < 100 then
            GoToState(7)
        end
    end
end

-- Dispatcher: picks the right (unit, camp) pairings based on current hero mode
-- and invokes the per-unit state machine for each.
--
-- Single-camp mode (Beast / KotL / Enigma / Invoker):
--   Everything pointed at one camp (the one selected via HandleCampSelection).
--   We use the first summon in the list, matching the pre-existing behaviour.
--
-- Multi-camp mode (Furion / Brood):
--   Each camp in multi_assignments gets paired with its assigned summon.
--   Stale assignments (unit died / unit list changed) are pruned automatically.
local function HandleStackingLogic(summons)
    local current_hero = GetCurrentHero()

    if IsMultiCampHero(current_hero) then
        -- Build idx -> unit lookup once per frame
        local by_idx = {}
        for i = 1, #summons do by_idx[summons[i].idx] = summons[i].u end

        for key, unit_idx in pairs(multi_assignments) do
            local unit = by_idx[unit_idx]
            if unit then
                local zone_name, camp_id_str = key:match("^(.-):(%-?%d+)$")
                local camp_id = tonumber(camp_id_str)
                local camp = zone_name and camp_id and CampConfig[zone_name] and CampConfig[zone_name][camp_id]
                if camp then
                    RunUnitStateMachine(unit_idx, unit, zone_name, camp)
                    -- Auto-release: once the summon has reached its RunPos
                    -- (state 7 = successful stack complete), clear the
                    -- assignment and its state so the next bind press can
                    -- grab this summon for a different camp. Without this
                    -- the state machine would cycle back to state 0 after
                    -- ~6s of idle in state 7 and start re-stacking the same
                    -- camp, which the user does not want in multi-mode.
                    if states[unit_idx] and states[unit_idx].state == 7 then
                        multi_assignments[key] = nil
                        states[unit_idx]       = nil
                        lastOrderPos[unit_idx] = nil
                        lastOrderType[unit_idx] = nil
                    end
                else
                    -- Camp no longer exists; clean up the assignment
                    multi_assignments[key] = nil
                end
            else
                -- Assigned unit is gone (died / was not controllable this frame) -
                -- drop the assignment and its state so another summon can take it.
                multi_assignments[key] = nil
                states[unit_idx] = nil
                lastOrderPos[unit_idx] = nil
                lastOrderType[unit_idx] = nil
            end
        end
        return
    end

    -- Single-camp mode
    if not active_stack_zone or not selected_camp then return end
    local camp = CampConfig[active_stack_zone] and CampConfig[active_stack_zone][selected_camp]
    if not camp then return end

    local unit_data = summons[1]
    RunUnitStateMachine(unit_data.idx, unit_data.u, active_stack_zone, camp)
end

-- Handle logic activation bind
local function HandleLogicActivationBind()
    if not m_key_toggle then return end
    local key = m_key_toggle:Get()
    if not key or key == 0 then return end

    local isDown = Input.IsKeyDown(key)

    if isDown and not lastKeyStatus then
        local current_hero = GetCurrentHero()
        if IsMultiCampHero(current_hero) then
            -- Furion / Brood: each press toggles the camp under the cursor
            -- independently. Other active camps keep running.
            ToggleMultiCampAtCursor(current_hero)
        else
            -- Single-camp heroes: classic behaviour where the bind is a global
            -- on/off switch. First press selects a camp, second press releases.
            local old_logic_status = logic_enabled_by_bind
            logic_enabled_by_bind = not logic_enabled_by_bind

            if logic_enabled_by_bind and not old_logic_status then
                HandleCampSelection()
            elseif not logic_enabled_by_bind and old_logic_status then
                active_stack_zone = nil
                selected_camp = nil
                ClearAllUnitState()  -- don't carry stale progress into the next session
            end
        end
    end
    lastKeyStatus = isDown
end

-- Main update function
function Stacker.OnUpdate()
    SetupMenu()

    script_enabled_by_menu = GetVal(m_enabled)

    if not script_enabled_by_menu then
        if logic_enabled_by_bind then
            logic_enabled_by_bind = false
        end
        -- Clear stale selection and per-unit state so a fresh re-enable starts clean
        active_stack_zone = nil
        selected_camp = nil
        ClearAllUnitState()
        -- Reset the key-edge latch. Otherwise, if the user happens to be holding
        -- the toggle key when they disable the script, the first press after
        -- re-enabling gets swallowed.
        lastKeyStatus = false
        return
    end

    HandleLogicActivationBind()

    if not logic_enabled_by_bind then
        return
    end

    local hero = Heroes.GetLocal()
    if not hero then return end

    local current_hero = GetCurrentHero()
    local summons = CollectSummons(hero, current_hero)

    -- Populate the per-frame cache so OnDraw doesn't walk NPCs.GetAll() again
    -- on the same tick. Keyed by game time so stale data self-invalidates.
    frame_cache.time         = GameRules.GetGameTime()
    frame_cache.hero         = hero
    frame_cache.current_hero = current_hero
    frame_cache.summons      = summons

    -- Garbage-collect state for units that are no longer in our summons set
    -- (died, turned uncontrollable, re-summoned with a new index, etc.). Without
    -- this the tables grow unboundedly in long games. Also drop any
    -- multi_assignments pointing at a unit that no longer exists.
    if next(states) or next(lastOrderPos) or next(lastOrderType) or next(multi_assignments) then
        local active = {}
        for i = 1, #summons do active[summons[i].idx] = true end
        for idx in pairs(states) do
            if not active[idx] then states[idx] = nil end
        end
        for idx in pairs(lastOrderPos) do
            if not active[idx] then lastOrderPos[idx] = nil end
        end
        for idx in pairs(lastOrderType) do
            if not active[idx] then lastOrderType[idx] = nil end
        end
        for key, idx in pairs(multi_assignments) do
            if not active[idx] then multi_assignments[key] = nil end
        end
        -- If all multi assignments were dropped, also flip the bind flag off
        if IsMultiCampHero(current_hero) and not next(multi_assignments) then
            logic_enabled_by_bind = false
        end
    end

    if #summons > 0 then
        HandleStackingLogic(summons)
    end
end

-- Draw tracer / status / markers for a single (unit, camp) pair. Extracted so
-- multi-camp mode can iterate it over every (assigned_unit, assigned_camp).
local function DrawUnitVisualsForCamp(unit, idx, zone_name, camp)
    if not states[idx] or not camp then return end
    local s = states[idx]
    local unit_pos = Entity.GetAbsOrigin(unit)

    -- Resolve partner camp once (may be nil for single-stack camps)
    local partner_camp = camp.PartnerCamp and CampConfig[zone_name] and CampConfig[zone_name][camp.PartnerCamp] or nil

    -- Pick the "finish" run position for states 5/6/7:
    --   5 -> own camp's run pos (first-camp completion / single-stack finish)
    --   6 -> partner camp run pos (double-stack finish)
    --   7 -> partner run pos if it exists, otherwise own run pos
    local function resolve_run_pos()
        if s.state == 5 then return camp.RunPos end
        if s.state == 6 then
            return partner_camp and partner_camp.RunPos or camp.RunPos
        end
        return partner_camp and partner_camp.RunPos or camp.RunPos  -- state 7
    end

    local is_complete = false
    if s.state == 5 or s.state == 6 or s.state == 7 then
        local run_pos = resolve_run_pos()
        if run_pos then
            is_complete = (unit_pos - run_pos):Length2D() < 50
        end
    end

    if s.state == 0 then
        DrawTracerLine(unit, unit_pos, camp.WaitPos)
        DrawBoarStatus(unit, camp.WaitPos)
        DrawWaitMarker(camp.WaitPos)
        DrawStopMarker(camp.RunPos, is_complete)
    elseif s.state == 1 then
        DrawTracerLine(unit, unit_pos, camp.CampCenter, nil, true)
        DrawBoarStatus(unit, camp.CampCenter)
        DrawWaitMarker(camp.WaitPos)
        DrawStopMarker(camp.RunPos, is_complete)
    elseif s.state == 2 then
        DrawTracerLine(unit, unit_pos, camp.CampCenter, nil, true)
        DrawBoarStatus(unit, camp.CampCenter)
        DrawStopMarker(camp.RunPos, is_complete)
    elseif s.state == 3 then
        if partner_camp then
            DrawTracerLine(unit, unit_pos, partner_camp.WaitPos)
            DrawBoarStatus(unit, partner_camp.WaitPos)
            DrawStopMarker(partner_camp.RunPos, is_complete)
        end
    elseif s.state == 4 then
        if partner_camp then
            DrawTracerLine(unit, unit_pos, partner_camp.CampCenter, nil, true)
            DrawBoarStatus(unit, partner_camp.CampCenter)
            DrawStopMarker(partner_camp.RunPos, is_complete)
        end
    elseif s.state == 5 or s.state == 6 or s.state == 7 then
        if s.state == 5 then
            DrawTracerLine(unit, unit_pos, camp.RunPos)
            DrawBoarStatus(unit, camp.RunPos)
            DrawStopMarker(camp.RunPos, is_complete)
        else
            local target = partner_camp or camp
            DrawTracerLine(unit, unit_pos, target.RunPos)
            DrawBoarStatus(unit, target.RunPos)
            DrawStopMarker(target.RunPos, is_complete)
        end
        if s.state == 5 or s.state == 7 then
            local target_run = resolve_run_pos()
            if target_run then
                local distance_to_run = (unit_pos - target_run):Length2D()
                if distance_to_run < 100 then
                    DrawTracerLine(unit, unit_pos, target_run, Color(0, 255, 0, 255))
                end
            end
        end
    end
end

-- ============================================================================
-- Compact, draggable HUD
-- ============================================================================
-- Single-line, auto-sized status panel. Position is stored in `hud_pos` and
-- can be dragged anywhere on the screen with ALT + left mouse button while
-- the cursor is over the panel. The "Lock HUD Position" menu switch disables
-- dragging entirely.

-- Cache the panel rect every frame so the drag hit-test in OnDraw matches
-- exactly what's painted on screen.
local hud_rect = { x0 = 0, y0 = 0, x1 = 0, y1 = 0 }

-- Whether a CMenuBind is currently held. CMenuBind exposes :IsDown() for
-- "is the bound key/button currently held" (returns boolean) and :Get() for
-- the actual key code (returns number). We use IsDown with a fallback for
-- older API builds where Get() may return a truthy value when held.
local function BindIsDown(bind)
    if not bind then return false end
    if bind.IsDown then
        local ok, v = pcall(bind.IsDown, bind)
        if ok then return v == true end
    end
    if bind.Get then
        local ok, v = pcall(bind.Get, bind)
        if ok and v then
            if type(v) == "boolean" then return v end
            if type(v) == "number"  then return v ~= 0 end
        end
    end
    return false
end

-- Clamp the panel inside the visible screen area so it never gets stuck
-- off-screen (e.g. after switching resolutions).
local function ClampHudPos()
    local sw, sh = 1920, 1080
    if Render and Render.ScreenSize then
        local ok, sz = pcall(Render.ScreenSize)
        if ok and sz then sw, sh = sz.x, sz.y end
    end
    local w, h = hud_last_size.x, hud_last_size.y
    if hud_pos.x < 0 then hud_pos = Vec2(0, hud_pos.y) end
    if hud_pos.y < 0 then hud_pos = Vec2(hud_pos.x, 0) end
    if hud_pos.x + w > sw then hud_pos = Vec2(sw - w, hud_pos.y) end
    if hud_pos.y + h > sh then hud_pos = Vec2(hud_pos.x, sh - h) end
end

-- Read the current cursor position with safe fallbacks. UC v2.0 returns
-- screen-space (x, y) as two return values from Input.GetCursorPos().
local function GetCursor()
    if not Input or not Input.GetCursorPos then return 0, 0 end
    local ok, x, y = pcall(Input.GetCursorPos)
    if not ok or type(x) ~= "number" or type(y) ~= "number" then return 0, 0 end
    return x, y
end

local function CursorInHudRect()
    -- Prefer the documented Input.IsCursorInBounds when available so the
    -- hit-test matches the cheat's own logic exactly. Fallback to a manual
    -- comparison.
    if Input and Input.IsCursorInBounds then
        local ok, hit = pcall(Input.IsCursorInBounds,
            hud_rect.x0, hud_rect.y0, hud_rect.x1, hud_rect.y1)
        if ok then return hit == true end
    end
    local cx, cy = GetCursor()
    return cx >= hud_rect.x0 and cx <= hud_rect.x1
       and cy >= hud_rect.y0 and cy <= hud_rect.y1
end

-- Read raw ALT state straight from Input.IsKeyDown. Tries both LALT and
-- RALT (some keyboards / international layouts only register one of them).
local function IsAltKeyDown()
    if not Input or not Input.IsKeyDown then return false end
    if not Enum or not Enum.ButtonCode then return false end
    local codes = { Enum.ButtonCode.KEY_LALT, Enum.ButtonCode.KEY_RALT }
    for i = 1, #codes do
        local code = codes[i]
        if code then
            local ok, v = pcall(Input.IsKeyDown, code)
            if ok and v == true then return true end
        end
    end
    return false
end

-- Engage / drive / release HUD drag.
--   * Hold ALT while the cursor is over the panel to start dragging.
--   * Panel follows the cursor while ALT stays held.
--   * Release ALT to drop it in place.
-- Reads ALT through both the configurable Bind widget AND the raw
-- Input.IsKeyDown layer; either path triggering is enough so the drag is
-- robust across UC builds even if one of the input layers is flaky.
local function HandleHudDrag()
    if GetVal(m_lock_hud) then
        hud_dragging = false
        return
    end

    local alt_held = BindIsDown(m_hud_drag_modifier) or IsAltKeyDown()
    local cx, cy   = GetCursor()

    if hud_dragging then
        if alt_held then
            hud_pos = Vec2(cx - hud_drag_off.x, cy - hud_drag_off.y)
            ClampHudPos()
        else
            hud_dragging = false
        end
    else
        if alt_held and CursorInHudRect() then
            hud_dragging = true
            hud_drag_off = Vec2(cx - hud_pos.x, cy - hud_pos.y)
        end
    end
end

-- Two-line status panel (matches the original "STACKER: ON" / zone layout).
-- The only change vs the legacy version is that width is computed strictly
-- from the longest of the two text lines + symmetric padding, so there's no
-- dead space on the right when the second line is short.
local function DrawCompactHud()
    local font = inter_font or Render.LoadFont("Inter", 13, Enum.FontCreate.FONTFLAG_ANTIALIAS, 500)

    -- Line 1: ON/OFF status
    local status_text = script_enabled_by_menu and "STACKER: ON" or "STACKER: OFF"

    -- Line 2: zone / multi-stack count / idle
    local zone_text
    if active_stack_zone then
        zone_text = active_stack_zone .. " Zone Active"
    elseif next(multi_assignments) then
        local count = 0
        for _ in pairs(multi_assignments) do count = count + 1 end
        zone_text = "Multi-Stack: " .. tostring(count) .. " camp" .. (count == 1 and "" or "s")
    else
        zone_text = "No Zone Active"
    end

    local pad_x      = 10
    local pad_y      = 8
    local line_gap   = 6
    local accent_bar = 3

    local s1 = Render.TextSize(font, 13, status_text)
    local s2 = Render.TextSize(font, 13, zone_text)
    local text_w = math.max(s1.x, s2.x)

    local w = text_w + pad_x * 2
    local h = accent_bar + pad_y + s1.y + line_gap + s2.y + pad_y

    hud_last_size = Vec2(w, h)
    ClampHudPos()

    local p = hud_pos
    hud_rect.x0 = p.x
    hud_rect.y0 = p.y
    hud_rect.x1 = p.x + w
    hud_rect.y1 = p.y + h

    Render.FilledRect(p, p + Vec2(w, h), Color(17, 17, 17, 240), 8)
    Render.FilledRect(p, p + Vec2(w, accent_bar), GetStackerColor(), 8)

    local text_color = Color(255, 255, 255, 255)
    Render.Text(font, 13, status_text,
        p + Vec2(pad_x, accent_bar + pad_y), text_color)
    Render.Text(font, 13, zone_text,
        p + Vec2(pad_x, accent_bar + pad_y + s1.y + line_gap), text_color)

    -- Visual feedback: while not locked, show a thin border when ALT is
    -- held OR the cursor is hovering over the panel. While actively
    -- dragging the border becomes thicker. Makes it obvious whether the
    -- input is being detected and the hit-test is working.
    if not GetVal(m_lock_hud) then
        local alt_held = BindIsDown(m_hud_drag_modifier) or IsAltKeyDown()
        local hover    = CursorInHudRect()
        if hud_dragging then
            Render.Rect(p, p + Vec2(w, h), GetStackerColor(), 8, nil, 2)
        elseif alt_held or hover then
            Render.Rect(p, p + Vec2(w, h), GetStackerColor(), 8, nil, 1)
        end
    end
end

-- Main draw function
function Stacker.OnDraw()
    SetupMenu()

    if not script_enabled_by_menu then return end

    local has_single = active_stack_zone and selected_camp
    local has_multi  = next(multi_assignments) ~= nil

    if has_single or has_multi then
        DrawStackingVisuals()

        -- Reuse OnUpdate's frame cache if it's from this tick; otherwise
        -- recompute. This skips a full NPCs.GetAll() walk per frame.
        local now = GameRules.GetGameTime()
        local hero, current_hero, summons
        if frame_cache.time == now and frame_cache.hero then
            hero, current_hero, summons = frame_cache.hero, frame_cache.current_hero, frame_cache.summons
        else
            hero = Heroes.GetLocal()
            if hero then
                current_hero = GetCurrentHero()
                summons = CollectSummons(hero, current_hero)
            end
        end
        if hero then

            -- Quick idx -> unit lookup
            local by_idx = {}
            for i = 1, #summons do by_idx[summons[i].idx] = summons[i].u end

            if IsMultiCampHero(current_hero) then
                -- One visual set per active (assigned unit, camp) pairing
                for key, unit_idx in pairs(multi_assignments) do
                    local unit = by_idx[unit_idx]
                    if unit then
                        local zone_name, camp_id_str = key:match("^(.-):(%-?%d+)$")
                        local camp_id = tonumber(camp_id_str)
                        local zone = zone_name and CampConfig[zone_name]
                        local camp = zone and camp_id and zone[camp_id]
                        if camp then
                            DrawUnitVisualsForCamp(unit, unit_idx, zone_name, camp)
                        end
                    end
                end
            elseif has_single and #summons > 0 then
                local unit_data = summons[1]
                local camp = CampConfig[active_stack_zone] and CampConfig[active_stack_zone][selected_camp]
                if camp then
                    DrawUnitVisualsForCamp(unit_data.u, unit_data.idx, active_stack_zone, camp)
                end
            end
        end
    end

    if not GetVal(m_show_hud) then return end

    HandleHudDrag()
    DrawCompactHud()
end

return Stacker
