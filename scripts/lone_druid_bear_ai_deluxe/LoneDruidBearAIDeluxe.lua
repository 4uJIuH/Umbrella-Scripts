---@diagnostic disable: undefined-global, param-type-mismatch, inject-field
local ld = {}

-- =========================================================
-- RENDER
-- =========================================================
local font_big   = Render.LoadFont("Verdana", 14, 700)
local font_small = Render.LoadFont("Verdana", 12, 400)

-- =========================================================
-- ORDERS
-- =========================================================
local O_ATTACK = Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET
local O_MOVE   = Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION
local O_FOLLOW = Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_TARGET
local O_GIVE   = Enum.UnitOrder.DOTA_UNIT_ORDER_GIVE_ITEM
local O_CAST_T = Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TARGET
local O_CAST_N = Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET
local O_ATK_MV = Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_MOVE
local ISSUER   = Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY

-- =========================================================
-- UI
-- =========================================================
local tab  = Menu.Create("Heroes", "Hero List", "Lone Druid")
local root = tab:Create("Bear AI Deluxe")

local ui = {}

-- Language toggle
local g_lang = root:Create("Language / Язык")
ui.lang = g_lang:Switch("English / Английский [F7 to reload]", false)
ui.lang:Icon("\u{f0ac}")

local function L(ru, en)
    return ui.lang:Get() and en or ru
end

-- Groups
local g_main  = root:Create(L("Основное",              "Main"))
local g_modes = root:Create(L("Режимы",                "Modes"))
local g_farm  = root:Create(L("Фарм леса",             "Forest Farm"))
local g_push  = root:Create(L("Пуш лайна",             "Lane Push"))
local g_stack = root:Create(L("Стаки",                  "Stacking"))
local g_aghs  = root:Create(L("Логика с Аганимом",      "Aghanim Logic"))
local g_def   = root:Create(L("Выживание Медведя",      "Bear Survival"))
local g_item  = root:Create(L("Предметы",               "Items"))
local g_vis   = root:Create(L("Визуал",                 "Visuals"))
local g_keys  = root:Create(L("Горячие клавиши",        "Hotkeys"))

-- Main
ui.on        = g_main:Switch(L("Включить Bear AI",                      "Enable Bear AI"), false)
ui.on:Icon("\u{f00c}")
ui.follow    = g_main:Switch(L("Следовать за героем (без Аганима)",      "Follow Hero (no Aghs)"), true)
ui.follow:Icon("\u{f238}")
ui.only_aghs = g_main:Switch(L("Farm/Push/Stack только с Аганимом",     "Farm/Push/Stack Aghs only"), false)
ui.only_aghs:Icon("\u{f005}")

-- Modes
ui.farm = g_modes:Switch(L("Режим: Фарм леса",  "Mode: Forest Farm"), false)
ui.farm:Image("panorama/images/spellicons/lone_druid_spirit_bear_png.vtex_c")
ui.push = g_modes:Switch(L("Режим: Пуш лайна",  "Mode: Lane Push"),   false)
ui.push:Image("panorama/images/spellicons/lone_druid_spirit_bear_entangle_png.vtex_c")

-- Farm
ui.farm_radius = g_farm:Slider(
    L("Радиус поиска нейтралов", "Neutral Search Radius"),
    400, 1200, 800,
    function(v) return v .. L(" ед.", " u.") end
)
ui.farm_radius:Icon("\u{f140}")

-- Push
ui.tower_lvl = g_push:Slider(
    L("Атаковать башню от уровня", "Attack Tower from Level"),
    0, 25, 0,
    function(v)
        return v == 0
            and L("Никогда", "Never")
            or  (L("Уровень ", "Level ") .. v .. "+")
    end
)
ui.tower_lvl:Icon("\u{f132}")

-- Stacks
ui.stack_enable    = g_stack:Switch(L("Включить стаки",       "Enable Stacking"), true)
ui.stack_enable:Icon("\u{f0c9}")
ui.stack_farm      = g_stack:Switch(L("Стаки при фарме",      "Stack during Farm"), true)
ui.stack_farm:Icon("\u{f66b}")
ui.stack_push      = g_stack:Switch(L("Стаки при пуше",       "Stack during Push"), true)
ui.stack_push:Icon("\u{f0e7}")
ui.stack_aggro_sec = g_stack:Slider(
    L("Секунда агра (база)", "Aggro Second (base)"),
    50, 57, 53,
    function(v) return v .. L(" сек", " sec") end
)
ui.stack_aggro_sec:Icon("\u{f017}")
ui.stack_range = g_stack:Slider(
    L("Радиус поиска крипов", "Creep Search Radius"),
    300, 1200, 800,
    function(v) return v .. L(" ед.", " u.") end
)
ui.stack_range:Icon("\u{f140}")

-- Aghanim
ui.aghs_on  = g_aghs:Switch(L("Включить логику Аганима",  "Enable Aghanim Logic"), true)
ui.aghs_on:Image("panorama/images/items/ultimate_scepter_png.vtex_c")
ui.entangle = g_aghs:Switch(L("Авто-путы на врага",        "Auto Entangle"),        true)
ui.entangle:Image("panorama/images/spellicons/lone_druid_spirit_bear_entangle_png.vtex_c")
ui.ent_creeps = g_aghs:Switch(L("Путы на крипов (Push)", "Entangle Creeps (Push)"), false)
ui.ent_creeps:Icon("\u{f188}")
ui.ent_r    = g_aghs:Slider(
    L("Радиус пут", "Entangle Radius"),
    100, 700, 400,
    function(v) return v .. L(" ед.", " u.") end
)
ui.ent_r:Icon("\u{f140}")

-- Bear survival
ui.def_enable = g_def:Switch(L("Инстинкт самосохранения",    "Self-Preservation"),   true)
ui.def_enable:Image("panorama/images/spellicons/lone_druid_spirit_bear_return_png.vtex_c")
ui.def_hp_hero = g_def:Slider(
    L("Отступать к герою при HP <", "Retreat to Hero at HP <"),
    20, 90, 50, function(v) return v .. "%" end
)
ui.def_hp_hero:Icon("\u{f21e}")
ui.def_hp_base = g_def:Slider(
    L("На фонтан при HP <", "To Base at HP <"),
    5, 40, 20, function(v) return v .. "%" end
)
ui.def_hp_base:Icon("\u{f0f9}")
ui.def_hp_resume = g_def:Slider(
    L("Снова фармить при HP >", "Resume Farm at HP >"),
    50, 100, 95, function(v) return v .. "%" end
)
ui.def_hp_resume:Icon("\u{f04e}")
ui.def_roar   = g_def:Switch(L("Авто-Savage Roar",            "Auto Savage Roar"),    true)
ui.def_roar:Image("panorama/images/spellicons/lone_druid_savage_roar_png.vtex_c")
ui.def_phase  = g_def:Switch(L("Авто-Phase Boots",            "Auto Phase Boots"),    true)
ui.def_phase:Image("panorama/images/items/phase_boots_png.vtex_c")
ui.def_gank_r = g_def:Slider(
    L("Радиус опасного героя", "Danger Hero Radius"),
    350, 1000, 600,
    function(v) return v .. L(" ед.", " u.") end
)
ui.def_gank_r:Icon("\u{f06d}")
ui.def_alone  = g_def:Slider(
    L("Медведь 'один' дальше", "Bear 'alone' beyond"),
    800, 2500, 1500,
    function(v) return v .. L(" ед.", " u.") end
)
ui.def_alone:Icon("\u{f124}")
ui.def_alert  = g_def:Switch(L("Показывать DEFENSE alert",    "Show DEFENSE Alert"),  true)
ui.def_alert:Icon("\u{f0f3}")

-- Items
ui.transfer = g_item:Switch(L("Авто-передача предметов медведю", "Auto Item Transfer to Bear"), true)
ui.transfer:Image("panorama/images/items/bag_of_gold_png.vtex_c")

-- Visuals
ui.show_panel   = g_vis:Switch(L("Показывать панель медведя",       "Show Bear Panel"),       true)
ui.show_panel:Icon("\u{f0e5}")
ui.show_warning = g_vis:Switch(L("Warning без Аганима",             "No-Aghs Warning"),       true)
ui.show_warning:Icon("\u{f071}")
ui.drag_mode    = g_vis:Switch(L("Режим перемещения панелей",       "Panel Drag Mode"),       false)
ui.drag_mode:Icon("\u{f047}")

ui.panel_x = g_vis:Slider(L("Панель X", "Panel X"), 0, 1900, 760)
ui.panel_x:Icon("\u{f07e}")
ui.panel_y = g_vis:Slider(L("Панель Y", "Panel Y"), 0, 1000, 150)
ui.panel_y:Icon("\u{f07d}")
ui.aghs_x  = g_vis:Slider("Warning X", 0, 1900, 760)
ui.aghs_x:Icon("\u{f07e}")
ui.aghs_y  = g_vis:Slider("Warning Y", 0, 1000, 70)
ui.aghs_y:Icon("\u{f07d}")

-- Hotkeys
ui.k_toggle = g_keys:Bind(L("Вкл / Выкл AI",       "Toggle AI"),    Enum.ButtonCode.KEY_F7)
ui.k_toggle:Icon("\u{f011}")
ui.k_push   = g_keys:Bind(L("Переключить: Push",    "Toggle: Push"), Enum.ButtonCode.KEY_F5)
ui.k_push:Icon("\u{f0e7}")
ui.k_farm   = g_keys:Bind(L("Переключить: Farm",    "Toggle: Farm"), Enum.ButtonCode.KEY_F6)
ui.k_farm:Icon("\u{f66b}")

-- Humanizer
local hum_tab = tab:Create(L("Хуманайзер", "Humanizer"))
local g_hum   = hum_tab:Create(L("Настройки", "Settings"))

ui.hum_on = g_hum:Switch(L("Включить хуманайзер", "Enable Humanizer"), true)
ui.hum_on:Icon("\u{f007}")
ui.hum_delay = g_hum:Slider(
    L("Задержка тика", "Tick Delay"),
    0, 200, 80,
    function(v) return "± " .. v .. L(" мс", " ms") end
)
ui.hum_delay:Icon("\u{f017}")
ui.hum_atk_delay = g_hum:Slider(
    L("Мин. интервал атаки", "Min Attack Interval"),
    200, 2000, 800,
    function(v) return v .. L(" мс", " ms") end
)
ui.hum_atk_delay:Icon("\u{f017}")
ui.hum_mov_delay = g_hum:Slider(
    L("Мин. интервал move", "Min Move Interval"),
    500, 5000, 2000,
    function(v) return v .. L(" мс", " ms") end
)
ui.hum_mov_delay:Icon("\u{f017}")
ui.hum_jitter = g_hum:Slider(
    L("Разброс назначения", "Destination Jitter"),
    0, 200, 12,
    function(v)
        return v == 0
            and L("Выкл", "Off")
            or  ("± " .. v .. L(" ед.", " u."))
    end
)
ui.hum_jitter:Icon("\u{f074}")

-- Callbacks
ui.push:SetCallback(function()
    if ui.push:Get() then ui.farm:Set(false) end
end)
ui.farm:SetCallback(function()
    if ui.farm:Get() then ui.push:Set(false) end
end)

-- =========================================================
-- CONST
-- =========================================================
local TICK      = 0.25
local TR_DLY    = 1.0
local FOL_START = 950
local FOL_STOP  = 650
local ATK_R     = 800
local WALK_R    = 150
local RESP      = 60.0
local IDLE_T    = 8.0
local AFTER_T   = 2.0
local MOV_RPT   = 1.0
local GIVE_D    = 300
local ROAR_R    = 380

local BEARS = {["npc_dota_lone_druid_bear1"] = true,["npc_dota_lone_druid_bear2"] = true,
    ["npc_dota_lone_druid_bear3"] = true,["npc_dota_lone_druid_bear4"] = true,
}

local PROT = {["item_boots"] = true, ["item_phase_boots"] = true, ["item_power_treads"] = true,
    ["item_arcane_boots"] = true, ["item_travel_boots"] = true, ["item_travel_boots_2"] = true,["item_aghanims_blessing"] = true, ["item_shard"] = true,["item_tpscroll"] = true,
    ["item_ward_observer"] = true, ["item_ward_sentry"] = true,["item_smoke_of_deceit"] = true,
}

local CAMPS = {
    {id=1,  p=Vector(-742,   4325, 134)}, {id=2,  p=Vector(2943,   -796, 256)},
    {id=3,  p=Vector(4082,  -5526, 128)}, {id=4,  p=Vector(8255,   -734, 256)},
    {id=5,  p=Vector(-4806,  4534, 128)}, {id=6,  p=Vector(4284,  -4110, 128)},
    {id=7,  p=Vector(-2121, -3921, 128)}, {id=8,  p=Vector(262,   -4751, 136)},
    {id=9,  p=Vector(-4509,   361, 256)}, {id=10, p=Vector(4072,   -421, 256)},
    {id=11, p=Vector(-1274, -4908, 128)}, {id=12, p=Vector(1515,   8209, 128)},
    {id=13, p=Vector(455,    3965, 134)}, {id=14, p=Vector(-4144,   322, 256)},
    {id=15, p=Vector(316,   -8138, 134)}, {id=16, p=Vector(-2529, -7737, 134)},
    {id=17, p=Vector(-479,   7639, 134)}, {id=18, p=Vector(-4743,  7534,   0)},
    {id=19, p=Vector(1348,   3263, 128)}, {id=20, p=Vector(7969,   1047, 256)},
    {id=21, p=Vector(-7735,  -183, 256)}, {id=22, p=Vector(-3962,  7564,   0)},
    {id=23, p=Vector(-2589,  4502, 256)}, {id=24, p=Vector(3522,  -8186,   8)},
    {id=25, p=Vector(1501,  -4208, 256)}, {id=26, p=Vector(-4338,  4903, 128)},
    {id=27, p=Vector(-7757, -1219, 256)}, {id=28, p=Vector(4781,  -7812,   8)},
}

local STACK_CAMPS = {
    {id=1,  camp=Vector(-742,   4325, 134), pull=Vector(-682,  3881, 236)},
    {id=2,  camp=Vector(2943,   -796, 256), pull=Vector(2817,  -53,  256)},
    {id=3,  camp=Vector(4082,  -5526, 128), pull=Vector(4181, -6368, 128)},
    {id=5,  camp=Vector(-4806,  4534, 128), pull=Vector(-4884, 5071, 128)},
    {id=6,  camp=Vector(4284,  -4110, 128), pull=Vector(3622, -4505, 128)},
    {id=7,  camp=Vector(-2121, -3921, 128), pull=Vector(-1564, -4531, 128)},
    {id=8,  camp=Vector(262,   -4751, 136), pull=Vector(333,  -4101, 254)},
    {id=9,  camp=Vector(-4509,   361, 256), pull=Vector(-5031, 1121, 128)},
    {id=10, camp=Vector(4072,   -421, 256), pull=Vector(4276, -1359, 128)},
    {id=11, camp=Vector(-1274, -4908, 128), pull=Vector(-812, -5282, 128)},
    {id=12, camp=Vector(1515,   8209, 128), pull=Vector(792,   8152, 128)},
    {id=13, camp=Vector(455,    3965, 134), pull=Vector(-78,   3932, 136)},
    {id=14, camp=Vector(-4144,   322, 256), pull=Vector(-5031, 1121, 128)},
    {id=17, camp=Vector(-479,   7639, 134), pull=Vector(-551,  6961, 128)},
    {id=19, camp=Vector(1348,   3263, 128), pull=Vector(1683,  3710, 128)},
    {id=23, camp=Vector(-2589,  4502, 256), pull=Vector(-2651, 5138, 256)},
    {id=25, camp=Vector(1501,  -4208, 256), pull=Vector(1094, -5103, 136)},
    {id=26, camp=Vector(-4338,  4903, 128), pull=Vector(-5198, 4877, 128)},
}

-- =========================================================
-- STATE
-- =========================================================
local hero, bear, player = nil, nil, nil
local our_team, enemy_team = nil, nil
local prev_items = {}
local last_tick = -999
local last_tr   = -999
local npc_cache     = nil
local neutral_cache = nil

local hum_now               = 0
local hum_next_tick         = 0
local hum_last_atk          = -999
local hum_last_tgt          = nil
local hum_last_mov          = -999
local hum_goal_pos          = nil
local hum_goal_jittered     = nil
local hum_goal_tag          = nil
local hum_goal_allow_jitter = nil
local hum_last_follow       = -999
local hum_last_fol_tgt      = nil
local hum_follow_active     = false

local def = {
    panic_until   = 0,
    reason        = "SAFE",
    lock_until    = 0,
    heal_fountain = false,
}

local bind_prev = {toggle=false, push=false, farm=false}

local fc         = {}
local camp_id    = nil
local camp_pos   = nil
local had_mob    = false
local arrived_t  = -999
local cleared_t  = -999
local last_mov_t = -999
local last_seen_mob_pos = nil

local st = {
    active          = false,
    phase           = "idle",
    camp_id         = nil,
    camp_pos        = nil,
    pull_pos        = nil,
    strike_center   = nil,
    last_minute     = -1,
    aggro_time      = 0,
    hit_confirmed   = false,
    pull_issued     = false,
    approach_issued = false,
    last_move_time  = 0,
}

-- ГЛОБАЛЬНОЕ СОСТОЯНИЕ ПЕРЕТАСКИВАНИЯ
local drag_state = {
    main_active = false, main_dx = 0, main_dy = 0,
    aghs_active = false, aghs_dx = 0, aghs_dy = 0,
    was_down = false
}

local entangle_cast_this_tick = false

-- =========================================================
-- UTILS / MOUSE LOGIC (ИСПРАВЛЕННЫЙ БЛОК)
-- =========================================================
local function sc(fn, ...)
    local ok, r = pcall(fn, ...)
    return ok and r or nil
end

local lmb_codes = {
    "KEY_LBUTTON", "MOUSE_LEFT", "KEY_MOUSE1", "MOUSE1",
    "BUTTON_LEFT", "KEY_MOUSE_LEFT", 107, 1, 0
}

local function is_lmb_down()
    if Input.IsKeyDown then
        local bc = Enum.ButtonCode or {}
        for _, code in ipairs(lmb_codes) do
            local c = type(code) == "string" and bc[code] or code
            if c then
                local ok, r = pcall(Input.IsKeyDown, c)
                if ok and r == true then return true end
            end
        end
    end
    if Input.IsButtonDown then
        for _, idx in ipairs({0, 1, 107}) do
            local ok, r = pcall(Input.IsButtonDown, idx)
            if ok and r == true then return true end
        end
    end
    if Render.IsMouseDown then
        for _, idx in ipairs({0, 1}) do
            local ok, r = pcall(Render.IsMouseDown, idx)
            if ok and r == true then return true end
        end
    end
    return false
end

local function get_cursor()
    if Render.GetCursorPos then
        local result = Render.GetCursorPos()
        if result and type(result) == "table" then
            local mx, my = result.x or result[1], result.y or result[2]
            if type(mx) == "number" and type(my) == "number" then
                return mx, my
            end
        end
    end
    if Input.GetCursorPosition then
        local mx, my = Input.GetCursorPosition()
        if type(mx) == "number" and type(my) == "number" then
            return mx, my
        end
    end
    if Input.GetCursorPos then
        local mx, my = Input.GetCursorPos()
        if type(mx) == "table" then
            my = mx.y or mx[2]
            mx = mx.x or mx[1]
        end
        if type(mx) == "number" and type(my) == "number" then
            return mx, my
        end
    end
    return nil, nil
end

local function is_mouse_in_rect(mx, my, x, y, w, h)
    return mx >= x and mx <= x + w and my >= y and my <= y + h
end

local function alive(e)
    return e ~= nil and sc(Entity.IsAlive, e) == true
end

local function bear_hp_pct()
    if not bear or not alive(bear) then return 100 end
    local hp  = sc(Entity.GetHealth, bear) or 1
    local mhp = sc(Entity.GetMaxHealth, bear) or 1
    return (hp / math.max(mhp, 1)) * 100
end

local function gn(u)
    return sc(NPC.GetUnitName, u) or ""
end

local function gp(u)
    return sc(Entity.GetAbsOrigin, u)
end

local function d2(a, b)
    return (a - b):Length2D()
end

local function en(u)
    return enemy_team ~= nil and sc(Entity.GetTeamNum, u) == enemy_team
end

local function hlvl()
    return (hero and sc(Hero.GetLevel, hero)) or 0
end

local function game_min_sec()
    local now = GameRules.GetGameTime()
    local gt  = now - (sc(GameRules.GetGameStartTime) or 0)
    if gt < 0 then gt = 0 end
    local min = math.floor(gt / 60)
    local sec = gt % 60
    return now, min, sec
end

local function reset_farm_state()
    camp_id=nil; camp_pos=nil; had_mob=false
    arrived_t=-999; cleared_t=-999; last_mov_t=-999
    last_seen_mob_pos = nil
end

local function reset_stack_state()
    st.active          = false
    st.phase           = "idle"
    st.camp_id         = nil
    st.camp_pos        = nil
    st.pull_pos        = nil
    st.strike_center   = nil
    st.aggro_time      = 0
    st.hit_confirmed   = false
    st.pull_issued     = false
    st.approach_issued = false
    st.last_move_time  = 0
end

local function reset_hum_move()
    hum_goal_pos          = nil
    hum_goal_jittered     = nil
    hum_goal_tag          = nil
    hum_goal_allow_jitter = nil
end

local function reset_hum_state()
    hum_now           = 0
    hum_next_tick     = 0
    hum_last_atk      = -999
    hum_last_tgt      = nil
    hum_last_mov      = -999
    hum_last_follow   = -999
    hum_last_fol_tgt  = nil
    hum_follow_active = false
    reset_hum_move()
end

local function reset_def_state()
    def.panic_until   = 0
    def.reason        = "SAFE"
    def.lock_until    = 0
    def.heal_fountain = false
end

local function set_panic(reason, now, dur)
    def.reason = reason or "PANIC"
    def.panic_until = math.max(def.panic_until, (now or GameRules.GetGameTime()) + (dur or 2.5))
end

local function panic_active(now)
    return (now or GameRules.GetGameTime()) < def.panic_until
end

local function mode_name()
    if ui.push:Get() then return "PUSH" end
    if ui.farm:Get() then return "FARM" end
    if ui.follow:Get() then return "FOLLOW" end
    return "IDLE"
end

local function bear_item(name)
    if not bear then return nil end
    for i = 0, 5 do
        local it = sc(NPC.GetItemByIndex, bear, i)
        if it and sc(Ability.GetName, it) == name then
            return it
        end
    end
    return nil
end

local function base_pos()
    return (our_team == 2)
        and Vector(-7200, -6600, 384)
        or Vector(7000, 6400, 384)
end

local function nearest_enemy_hero(pos)
    local best, bd = nil, math.huge
    for _, h in pairs(Heroes.GetAll()) do
        if h and alive(h) and h ~= hero and en(h)
        and not sc(NPC.IsIllusion, h)
        and not sc(Hero.IsClone, h) then
            local p = gp(h)
            if p then
                local d = d2(pos, p)
                if d < bd then
                    bd = d
                    best = h
                end
            end
        end
    end
    return best, bd
end

-- =========================================================
-- PANEL RENDERER
-- =========================================================
local function draw_pretty_panel(x, y, w, h, title, lines, line_colors, move_mode)
    local bg        = Color(14, 17, 22, 230)
    local bg2       = Color(22, 25, 32, 200)
    local accent    = Color(220, 70, 70, 255)
    local border    = Color(50, 54, 62, 220)
    local shadow    = Color(0, 0, 0, 100)
    local title_col = Color(245, 245, 245, 255)
    local subtle    = Color(110, 115, 125, 180)
    local sep_col   = Color(50, 54, 62, 140)

    -- Если включен режим перетаскивания, делаем панель зеленоватой
    if move_mode then
        bg     = Color(20, 35, 25, 240)
        bg2    = Color(25, 45, 30, 200)
        accent = Color(80, 255, 100, 255)
        border = Color(80, 255, 100, 255)
    end

    Render.FilledRect(Vec2(x + 5, y + 5), Vec2(x + w + 5, y + h + 5), shadow)
    Render.FilledRect(Vec2(x, y), Vec2(x + w, y + h), bg)
    Render.FilledRect(Vec2(x, y), Vec2(x + w, y + 30), bg2)
    Render.FilledRect(Vec2(x, y), Vec2(x + w, y + 3), accent)
    Render.FilledRect(Vec2(x, y), Vec2(x + 3, y + h), accent)
    Render.Rect(Vec2(x, y), Vec2(x + w, y + h), border)

    Render.Text(font_big, 14, title, Vec2(x + 12, y + 9), title_col)

    if move_mode then
        local tag    = "[drag]"
        local tag_sz = Render.TextSize(font_small, 12, tag)
        Render.Text(font_small, 12, tag, Vec2(x + w - tag_sz.x - 10, y + 10), subtle)
    end

    Render.FilledRect(Vec2(x + 10, y + 32), Vec2(x + w - 10, y + 33), sep_col)

    local yy = y + 40
    for i, text in ipairs(lines) do
        local col = line_colors[i] or Color(180, 180, 180, 255)
        Render.Text(font_small, 12, text, Vec2(x + 12, yy), col)
        yy = yy + 16
    end
end

-- =========================================================
-- INIT
-- =========================================================
local function init_teams()
    if our_team or not hero then return end
    our_team = sc(Entity.GetTeamNum, hero)
    if not our_team then return end
    enemy_team = our_team == 2 and 3 or 2
end

-- =========================================================
-- BEAR
-- =========================================================
local function refresh_bear()
    if bear and alive(bear) and BEARS[gn(bear)] then return end

    bear = nil
    local list = npc_cache or NPCs.GetAll()
    for _, u in pairs(list) do
        if u and alive(u) and BEARS[gn(u)] then
            local team = sc(Entity.GetTeamNum, u)
            if our_team == nil or team == our_team then
                bear = u
                reset_farm_state()
                reset_stack_state()
                reset_hum_state()
                reset_def_state()
                return
            end
        end
    end
end

local function has_aghs()
    -- Если медведя нет, то и проверять нечего
    if not bear then return false end

    -- Списки всех возможных системных названий Аганима
    local scepters = {
        ["item_ultimate_scepter"]   = true,
        ["item_aghanims_scepter"]   = true,
        ["item_ultimate_scepter_2"] = true,
        ["item_aghanims_blessing"]  = true,
    }

    -- Списки баффов (когда Аганим съеден рецептом, выпал с Рошана или передан Алхимиком)
    local mods = {
        "modifier_item_ultimate_scepter_consumed",
        "modifier_item_ultimate_scepter_consumed_alchemist",
        "modifier_item_ultimate_scepter",
        "modifier_item_aghanims_scepter",
    }

    -- Важно: проверяем И медведя И самого героя (т.к. аганим на герое работает и на медведя)
    for _, unit in ipairs({bear, hero}) do
        if unit and alive(unit) then

            -- 1. Системная проверка API чита (если поддерживается)
            if NPC.HasScepter then
                local ok, r = pcall(NPC.HasScepter, unit)
                if ok and r == true then return true end
            end

            -- 2. Проверка баффов Aghanim's Blessing (съеденного аганима)
            for _, m in ipairs(mods) do
                if sc(Entity.HasModifier, unit, m) == true then
                    return true
                end
            end

            -- 3. Проверка инвентаря (цикл до 16, чтобы проверить и рюкзак, и тайш)
            for i = 0, 16 do
                local it = sc(NPC.GetItemByIndex, unit, i)
                if it then
                    local name = sc(Ability.GetName, it) or ""
                    if scepters[name] then
                        return true
                    end
                end
            end

        end
    end

    return false
end

local function bear_ab(name)
    if not bear then return nil end
    for i = 0, 15 do
        local ab = sc(NPC.GetAbilityByIndex, bear, i)
        if ab and sc(Ability.GetName, ab) == name then
            return ab
        end
    end
    return nil
end

-- =========================================================
-- ORDERS
-- =========================================================
local function hum_jitter(pos)
    local j = ui.hum_jitter:Get()
    if j == 0 then return pos end
    local dx = (math.random() * 2 - 1) * j
    local dy = (math.random() * 2 - 1) * j
    return Vector(pos:GetX() + dx, pos:GetY() + dy, pos:GetZ())
end

local function ord(t, tgt, pos, ab)
    if not player or not bear or not alive(bear) then return end
    Player.PrepareUnitOrders(player, t, tgt, pos, ab, ISSUER, bear, false)
end

local function ba(t)
    if not t or not alive(t) then return end
    if ui.hum_on:Get() then
        local min_int = ui.hum_atk_delay:Get() / 1000.0
        if t == hum_last_tgt and (hum_now - hum_last_atk) < min_int then return end
        local cur_tgt = sc(NPC.GetAttackTarget, bear)
        if cur_tgt == t and (hum_now - hum_last_atk) < min_int then return end
    end
    hum_last_tgt = t
    hum_last_atk = hum_now
    reset_hum_move()
    ord(O_ATTACK, t, nil, nil)
end

local function ba_force(t)
    if not t or not alive(t) then return end
    hum_last_tgt = t
    hum_last_atk = hum_now
    reset_hum_move()
    ord(O_ATTACK, t, nil, nil)
end

local function bam(p)
    if not p then return end
    reset_hum_move()
    ord(O_ATK_MV, nil, p, nil)
end

local function bm(p, tag, allow_jitter)
    if not p then return end
    if tag == nil then tag = "move" end
    if allow_jitter == nil then allow_jitter = true end

    local send_pos = p

    if ui.hum_on:Get() then
        local min_int = ui.hum_mov_delay:Get() / 1000.0

        local goal_changed =
            (hum_goal_pos == nil)
            or (hum_goal_tag ~= tag)
            or (hum_goal_allow_jitter ~= allow_jitter)
            or (d2(hum_goal_pos, p) > 200)

        if goal_changed then
            hum_goal_pos          = p
            hum_goal_tag          = tag
            hum_goal_allow_jitter = allow_jitter
            hum_goal_jittered     = (allow_jitter and ui.hum_jitter:Get() > 0) and hum_jitter(p) or p
        end

        if not goal_changed and (hum_now - hum_last_mov) < min_int then return end

        local bpos = gp(bear)
        if bpos and hum_goal_jittered and d2(bpos, hum_goal_jittered) < 90 then return end

        send_pos = hum_goal_jittered or p
    end

    hum_last_mov = hum_now
    ord(O_MOVE, nil, send_pos, nil)
end

local function bm_force(p, tag)
    if not p then return end
    reset_hum_move()
    hum_last_mov = hum_now
    ord(O_MOVE, nil, p, nil)
end

local function bct(a, t)
    reset_hum_move()
    ord(O_CAST_T, t, nil, a)
end

local function bcn(a)
    reset_hum_move()
    ord(O_CAST_N, nil, nil, a)
end

local function hgive(it)
    if not player or not hero or not bear or not it then return end
    if not alive(hero) or not alive(bear) then return end

    local hp = gp(hero)
    local bp2 = gp(bear)
    if not hp or not bp2 then return end
    if d2(hp, bp2) > GIVE_D then return end

    Player.PrepareUnitOrders(player, O_GIVE, bear, nil, it, ISSUER, hero, false)
end

-- =========================================================
-- NEUTRALS
-- =========================================================
local function build_neutral_cache()
    neutral_cache = {}
    local list = npc_cache or NPCs.GetAll()
    for _, u in pairs(list) do
        if u then
            local name = sc(NPC.GetUnitName, u)
            if name and string.find(name, "npc_dota_neutral_", 1, true)
                and sc(Entity.IsAlive, u) == true
                and not sc(NPC.IsWaitingToSpawn, u)
                and not sc(NPC.IsInvulnerable, u) then
                local p = sc(Entity.GetAbsOrigin, u)
                if p then
                    neutral_cache[#neutral_cache + 1] = { unit = u, pos = p }
                end
            end
        end
    end
end

local function find_neutrals(center, radius)
    local best, bd, cnt = nil, math.huge, 0

    if neutral_cache then
        for _, e in ipairs(neutral_cache) do
            local d = d2(e.pos, center)
            if d <= radius then
                cnt = cnt + 1
                if d < bd then
                    bd   = d
                    best = e.unit
                end
            end
        end
    else
        local list = npc_cache or NPCs.GetAll()
        for _, u in pairs(list) do
            if u then
                local name = sc(NPC.GetUnitName, u)
                if name and string.find(name, "npc_dota_neutral_", 1, true)
                    and sc(Entity.IsAlive, u) == true
                    and not sc(NPC.IsWaitingToSpawn, u)
                    and not sc(NPC.IsInvulnerable, u) then
                    local p = sc(Entity.GetAbsOrigin, u)
                    if p then
                        local d = d2(p, center)
                        if d <= radius then
                            cnt = cnt + 1
                            if d < bd then
                                bd   = d
                                best = u
                            end
                        end
                    end
                end
            end
        end
    end

    return best, cnt
end

local function find_strike_center(camp_pos_arg)
    if not Camps or not Camps.GetAll then
        return camp_pos_arg
    end

    local camps = sc(Camps.GetAll)
    if not camps then return camp_pos_arg end

    local best_camp, best_dist = nil, math.huge
    for _, c in ipairs(camps) do
        local box = sc(Camp.GetCampBox, c)
        if box and box.min and box.max then
            local cx = (box.min:GetX() + box.max:GetX()) / 2
            local cy = (box.min:GetY() + box.max:GetY()) / 2
            local cz = (box.min:GetZ() + box.max:GetZ()) / 2
            local center = Vector(cx, cy, cz)
            local d = d2(center, camp_pos_arg)
            if d < best_dist then
                best_dist = d
                best_camp = center
            end
        end
    end

    return best_camp or camp_pos_arg
end

-- =========================================================
-- TRANSFER
-- =========================================================
local function do_transfer(now)
    if not ui.transfer:Get() then return end
    if now - last_tr < TR_DLY then return end
    if not (hero and bear and alive(hero) and alive(bear)) then return end

    local is_tp = sc(NPC.HasModifier, hero, "modifier_teleporting")
    if is_tp then return end

    last_tr = now

    local cur = {}
    for i = 0, 5 do
        local it = sc(NPC.GetItemByIndex, hero, i)
        if it then
            local n = sc(Ability.GetName, it)
            if n then cur[n] = it end
        end
    end

    for n, it in pairs(cur) do
        if not PROT[n] and not prev_items[n] then
            hgive(it)
            break
        end
    end

    prev_items = {}
    for n in pairs(cur) do
        prev_items[n] = true
    end
end

-- =========================================================
-- AGHS LOGIC
-- =========================================================
local function do_aghs(bpos)
    if not ui.aghs_on:Get() then return false end
    if not ui.entangle:Get() then return false end

    local ab = bear_ab("lone_druid_spirit_bear_entangle")
    if not ab or not sc(Ability.IsCastable, ab, sc(NPC.GetMana, bear) or 0) then
        return false
    end

    local ent_r  = ui.ent_r:Get()
    local best, bd = nil, math.huge

    for _, h in pairs(Heroes.GetAll()) do
        if h and alive(h) and h ~= hero and en(h)
        and not sc(NPC.IsIllusion, h)
        and not sc(Hero.IsClone, h) then
            local p = gp(h)
            if p then
                local d = d2(p, bpos)
                if d <= ent_r and d < bd then
                    bd = d
                    best = h
                end
            end
        end
    end

    if not best and ui.push:Get() and ui.ent_creeps:Get() then
        local list = npc_cache or NPCs.GetAll()
        for _, u in pairs(list) do
            if u and alive(u) and en(u) then
                local nm = gn(u)
                if string.find(nm, "npc_dota_creep_", 1, true) then
                    local p = gp(u)
                    if p then
                        local d = d2(p, bpos)
                        if d <= ent_r and d < bd then
                            bd   = d
                            best = u
                        end
                    end
                end
            end
        end
    end

    if best then
        bct(ab, best)
        return true
    end

    return false
end

-- =========================================================
-- SURVIVAL / DEFENSE
-- =========================================================
local function do_defense(bpos, now)
    if not ui.def_enable:Get() or not bear or not alive(bear) then
        return false
    end

    local hp_pct = bear_hp_pct()

    -- Берем значения из новых ползунков
    local hp_hero   = ui.def_hp_hero:Get()
    local hp_base   = ui.def_hp_base:Get()
    local hp_resume = ui.def_hp_resume:Get()

    local hero_pos = (hero and alive(hero)) and gp(hero) or nil
    local enemy, enemy_dist = nearest_enemy_hero(bpos)
    local alone  = (not hero_pos) or (d2(bpos, hero_pos) > ui.def_alone:Get())
    local ganked = enemy ~= nil and alone and enemy_dist < ui.def_gank_r:Get()

    -- 1. ЛОГИКА ВОССТАНОВЛЕНИЯ НА ФОНТАНЕ (Если включился режим хила)
    if def.heal_fountain then
        -- Если вылечились до нужного порога - отпускаем медведя фармить
        if hp_pct >= hp_resume then
            def.heal_fountain = false
            def.reason = "SAFE"
            def.panic_until = 0
            return false
        end

        if now < def.lock_until then return true end

        -- Во время побега или стояния на базе жмем фейзы по кулдауну
        if ui.def_phase:Get() then
            local phase = bear_item("item_phase_boots")
            if phase and sc(Ability.IsCastable, phase, 0) then
                bcn(phase)
                def.lock_until = now + 0.05
                return true
            end
        end

        -- Если по пути на базу встретили врага - пугаем его рыком
        if ui.def_roar:Get() and enemy and enemy_dist <= ROAR_R then
            local roar = bear_ab("lone_druid_savage_roar_bear") or bear_ab("lone_druid_savage_roar")
            if roar and sc(Ability.IsCastable, roar, sc(NPC.GetMana, bear) or 0) then
                bcn(roar)
                def.lock_until = now + 0.12
                return true
            end
        end

        def.reason = "HEALING AT BASE"
        bm(base_pos(), "def_base", false)
        return true
    end

    -- 2. ПРОВЕРКА УГРОЗ ДЛЯ АКТИВАЦИИ ЗАЩИТЫ
    local critical_hp = hp_pct <= hp_base
    local low_hp      = hp_pct <= hp_hero

    if not low_hp and not critical_hp and not ganked and not panic_active(now) then
        return false
    end

    if critical_hp then
        def.heal_fountain = true -- Врубаем режим принудительного хила до фулла
        set_panic("CRITICAL HP -> BASE", now, 3.0)
    elseif low_hp then
        set_panic("LOW HP -> HERO", now, 2.0)
    elseif ganked then
        set_panic("GANKED", now, 2.5)
    end

    if now < def.lock_until then return true end

    -- 3. СПАСАТЕЛЬНЫЕ АБИЛКИ
    if ui.def_roar:Get() and enemy and enemy_dist <= ROAR_R then
        local roar = bear_ab("lone_druid_savage_roar_bear") or bear_ab("lone_druid_savage_roar")
        if roar and sc(Ability.IsCastable, roar, sc(NPC.GetMana, bear) or 0) then
            set_panic("ROAR", now, 2.0)
            bcn(roar)
            def.lock_until = now + 0.12
            return true
        end
    end

    local ret = bear_ab("lone_druid_spirit_bear_return")
    if (critical_hp or low_hp or ganked) and ret and sc(Ability.IsCastable, ret, sc(NPC.GetMana, bear) or 0) then
        -- Если медведь далеко от героя, юзаем Return (к герою безопаснее)
        if hero_pos and d2(bpos, hero_pos) > 1200 then
            set_panic("RETURN", now, 3.0)
            bcn(ret)
            def.lock_until = now + 0.12
            return true
        end
    end

    if ui.def_phase:Get() then
        local phase = bear_item("item_phase_boots")
        if phase and sc(Ability.IsCastable, phase, 0) then
            set_panic("PHASE RUN", now, 2.0)
            bcn(phase)
            def.lock_until = now + 0.05
            return true
        end
    end

    -- 4. МАРШРУТ ПОБЕГА
    if critical_hp or def.heal_fountain then
        bm(base_pos(), "def_base", false) -- Если 20% -> на базу
    elseif low_hp and hero_pos then
        bm(hero_pos, "def_hero", false)   -- Если 50% -> к герою
    else
        bm(base_pos(), "def_base", false)
    end

    return true
end

-- =========================================================
-- ADVANCED FARM LOGIC
-- =========================================================
local function find_best_neutral(center, radius, bpos)
    local best_target = nil
    local best_score = -99999
    local count = 0

    if neutral_cache then
        for _, e in ipairs(neutral_cache) do
            local d = d2(e.pos, center)
            if d <= radius then
                count = count + 1
                local u = e.unit

                -- Вычисляем "ценность" цели
                local hp = sc(Entity.GetHealth, u) or 1
                local dist_to_bear = d2(e.pos, bpos)

                -- Логика: чем меньше HP у крипа и чем он ближе, тем выше приоритет.
                -- Это позволяет быстро убивать мелких крипов и получать меньше урона.
                local score = -hp - (dist_to_bear * 0.5)

                if score > best_score then
                    best_score = score
                    best_target = u
                end
            end
        end
    end

    return best_target, count
end

local function next_camp(bpos, now, skip)
    local best_pos, best_id, best_dist = nil, nil, math.huge
    local _, min, sec = game_min_sec()

    for _, c in ipairs(CAMPS) do
        if c.id ~= skip then
            -- Проверяем, на какой минуте был зачищен кемп
            local cleared_min = fc[c.id] or -1

            -- Кемп доступен, если он был зачищен НЕ на текущей минуте
            -- ИЛИ если время >= 59 секунд (спавн новых крипов)
            if cleared_min < min or sec >= 59 then
                local d = d2(c.p, bpos)
                if d < best_dist then
                    best_dist = d
                    best_pos  = c.p
                    best_id   = c.id
                end
            end
        end
    end

    if best_pos then
        camp_id    = best_id
        camp_pos   = best_pos
        had_mob    = false
        arrived_t  = -999
        cleared_t  = -999
        last_mov_t = -999

        -- Если есть фейзы, нажимаем их для быстрого бега к новому кемпу
        if ui.def_phase:Get() then
            local phase = bear_item("item_phase_boots")
            if phase and sc(Ability.IsCastable, phase, 0) then
                bcn(phase)
            end
        end

        bm(best_pos, "farm_path", true)
    else
        camp_id  = nil
        camp_pos = nil
    end
end

local function do_farm(bpos, now)
    if entangle_cast_this_tick then return end

    local search_radius = ui.farm_radius:Get() or 800
    local tgt, cnt = find_best_neutral(bpos, search_radius, bpos)
    local _, min, sec = game_min_sec()

    -- 1. ЕСЛИ ВИДИМ МОБОВ — АТАКУЕМ
    if cnt > 0 and tgt then
        if not had_mob then
            had_mob   = true
            cleared_t = -999
            arrived_t = -999
        end
        last_seen_mob_pos = gp(tgt) -- Запоминаем позицию
        ba(tgt)
        return
    end

    -- 2. МОБОВ НЕТ (Убили или ушли в тень)
    if had_mob then
        if cleared_t < 0 then cleared_t = now end

        -- УВЕЛИЧИВАЕМ ТАЙМАУТ ДО 4.0 СЕКУНД (чтобы медведь успел забежать в тень за мобом)
        if (now - cleared_t) < 4.0 then
            -- Делаем Attack-Move туда, где моба видели последний раз
            if (now - last_mov_t) >= MOV_RPT then
                bam(last_seen_mob_pos or camp_pos)
                last_mov_t = now
            end
            return
        end

        -- Если прошло 4 секунды и никого не нашли — точно зачистили
        local old = camp_id
        if old then fc[old] = min end
        reset_farm_state()
        next_camp(bpos, now, old)
        return
    end

    -- 3. НЕТ АКТИВНОГО КЕМПА — ИЩЕМ
    if not camp_pos then
        next_camp(bpos, now, nil)
        return
    end

    local dist = d2(bpos, camp_pos)

    -- 4. В ПУТИ К КЕМПУ
    if dist > WALK_R then
        if (now - last_mov_t) >= MOV_RPT then
            -- Если скоро спавн крипов (53-59 сек) и мы близко к кемпу (чтобы не заблочить спавн)
            if sec >= 53 and sec <= 59 and dist < 450 then
                -- Останавливаем медведя на краю кемпа, чтобы не заблокировать спавн!
                bm(bpos, "farm_hold_for_spawn", false)
            else
                bm(camp_pos, "farm_path", true)
                -- Жмем фейзы в пути
                if ui.def_phase:Get() then
                    local phase = bear_item("item_phase_boots")
                    if phase and sc(Ability.IsCastable, phase, 0) then bcn(phase) end
                end
            end
            last_mov_t = now
        end
        return
    end

    -- 5. ПРИБЫЛИ В КЕМП, А ОН ПУСТОЙ
    if arrived_t < 0 then arrived_t = now end

    -- Если сейчас 53-59 секунда, мы не уходим! Ждем спавна мобов на 00:00.
    if sec >= 53 and sec <= 59 then
        -- Немного отходим к краю кемпа, чтобы не заблочить точку спавна своим телом
        if dist < 300 and (now - last_mov_t) >= MOV_RPT then
            local dir = (bpos - camp_pos):Normalized()
            local wait_pos = camp_pos + (dir * 450)
            bm(wait_pos, "farm_wait_spawn", false)
            last_mov_t = now
        end
        return
    end

    -- Sweep-механика (поиск по кругу)
    -- Вместо того чтобы стоять на месте 8 секунд, медведь делает микро-движения по кемпу,
    -- чтобы развеять туман войны (иногда мобы прячутся за деревьями)
    if (now - last_mov_t) >= 1.5 then
        local sweep_angle = math.random() * math.pi * 2
        local sweep_pos = camp_pos + Vector(math.cos(sweep_angle)*300, math.sin(sweep_angle)*300, 0)
        bam(sweep_pos) -- Используем Attack-Move, чтобы сразу сагрить, если увидим
        last_mov_t = now
    end

    -- Если прошло 4 секунды (снизили с 8) и мобов 100% нет — идем на некст кемп
    if (now - arrived_t) >= 4.0 then
        local old = camp_id
        if old then
            fc[old] = min -- Помечаем зачищенным на текущей минуте
        end
        reset_farm_state()
        next_camp(bpos, now, old)
    end
end

-- =========================================================
-- PUSH
-- =========================================================
local function do_push(bpos)
    if entangle_cast_this_tick then return end

    local list = npc_cache or NPCs.GetAll()

    local best_creep, best_creep_dist = nil, math.huge
    for _, u in pairs(list) do
        if u and alive(u) and en(u) and string.find(gn(u), "npc_dota_creep_", 1, true) then
            local p = gp(u)
            if p then
                local d = d2(p, bpos)
                if d < best_creep_dist then
                    best_creep_dist = d
                    best_creep = u
                end
            end
        end
    end
    if best_creep then
        ba(best_creep)
        return
    end

    local best_tower, best_tower_dist = nil, math.huge
    for _, t in pairs(Towers.GetAll()) do
        if t and alive(t) and en(t) and not sc(NPC.IsInvulnerable, t) then
            local p = gp(t)
            if p then
                local d = d2(p, bpos)
                if d < best_tower_dist then
                    best_tower_dist = d
                    best_tower = t
                end
            end
        end
    end

    if best_tower then
        local tp = gp(best_tower)
        if tp then
            local min = ui.tower_lvl:Get()
            if min > 0 and hlvl() >= min then
                ba(best_tower)
            else
                bm(tp, "push_tower", true)
            end
        end
    end
end

-- =========================================================
-- STACK
-- =========================================================
local function next_stack_camp(bpos)
    local best, bd = nil, math.huge
    for _, c in ipairs(STACK_CAMPS) do
        local _, cnt = find_neutrals(c.camp, 600)
        if cnt > 0 then
            local d = d2(bpos, c.camp)
            if d < bd then
                bd   = d
                best = c
            end
        end
    end
    return best
end

local function can_use_independent_modes()
    if not ui.only_aghs:Get() then return true end
    return has_aghs()
end

local function do_stack(bpos)
    if not ui.stack_enable:Get() then
        reset_stack_state()
        return false
    end

    if not bear or not alive(bear) then
        reset_stack_state()
        return false
    end

    local now, minute, sec = game_min_sec()

    if st.last_minute == minute and st.phase == "done" then
        return false
    end

    if st.last_minute ~= minute then
        st.phase           = "idle"
        st.hit_confirmed   = false
        st.pull_issued     = false
        st.approach_issued = false
        st.aggro_time      = 0
        st.last_move_time  = 0
    end

    local bear_speed = sc(NPC.GetMovementSpeed, bear) or 300
    local base_aggro = ui.stack_aggro_sec:Get()

    if not st.camp_pos or st.phase == "idle" then
        local c = next_stack_camp(bpos)
        if not c then return false end
        st.camp_id       = c.id
        st.camp_pos      = c.camp
        st.pull_pos      = c.pull
        st.strike_center = find_strike_center(c.camp)
    end

    local dist_to_camp = d2(bpos, st.camp_pos)

    local travel_time  = dist_to_camp / math.max(bear_speed, 100)
    local approach_sec = base_aggro - math.ceil(travel_time) - 3
    approach_sec = math.max(approach_sec, 35)
    approach_sec = math.min(approach_sec, base_aggro - 5)

    if sec < approach_sec then
        return false
    end

    if sec >= approach_sec and sec < base_aggro and not st.pull_issued then
        st.active = true
        st.phase  = "approach"

        if dist_to_camp > 200 then
            if not st.approach_issued or (now - st.last_move_time) > 1.0 then
                st.approach_issued = true
                st.last_move_time  = now
                bm_force(st.camp_pos, "stack_approach")
            end
            return true
        end

        st.phase = "wait"
        return true
    end

    if st.phase == "wait" and sec < base_aggro then
        st.active = true
        if dist_to_camp > 300 then
            bm_force(st.camp_pos, "stack_wait_return")
        end
        return true
    end

    if sec >= base_aggro and sec < base_aggro + 4 and not st.pull_issued then
        st.active = true
        st.phase  = "aggro"

        if st.aggro_time == 0 then
            st.aggro_time = now
        end

        local search_center = st.strike_center or st.camp_pos
        local tgt, cnt = find_neutrals(search_center, ui.stack_range:Get())

        if tgt then
            -- Запоминаем, где видели моба перед тем, как он ушел в тень
            last_seen_mob_pos = gp(tgt)
            ba(tgt) -- Важно: используем ba(tgt), а не ba_force, чтобы избежать микро-станов медведя от спама кликов
        else
            -- Если моб пропал в тени, делаем Attack-Move на его последнюю позицию
            if (now - st.last_move_time) > 0.8 then
                bam(last_seen_mob_pos or search_center)
                st.last_move_time = now
            end
        end

        local atk_tgt = sc(NPC.GetAttackTarget, bear)
        if atk_tgt and alive(atk_tgt) then
            local time_in_aggro = now - st.aggro_time
            if time_in_aggro >= 0.8 then
                st.hit_confirmed = true
            end
        end

        local time_in_aggro = now - st.aggro_time

        if st.hit_confirmed or time_in_aggro >= 1.5 then
            st.phase       = "pull"
            st.pull_issued = true
            st.last_move_time = now
            bm_force(st.pull_pos, "stack_pull")
        end

        return true
    end

    if st.pull_issued and st.phase ~= "done" then
        st.active = true
        st.phase  = "pull"

        local dist_to_pull = d2(bpos, st.pull_pos)
        if dist_to_pull > 150 and (now - st.last_move_time) > 0.8 then
            st.last_move_time = now
            bm_force(st.pull_pos, "stack_pull")
        end

        if sec >= 59 or sec < 5 then
            st.phase       = "done"
            st.last_minute = minute
            st.active      = false
            st.hit_confirmed   = false
            st.pull_issued     = false
            st.approach_issued = false
            st.aggro_time      = 0
            st.last_move_time  = 0
        end

        return true
    end

    if sec >= base_aggro + 4 and not st.pull_issued then
        st.pull_issued    = true
        st.phase          = "pull"
        st.last_move_time = now
        bm_force(st.pull_pos, "stack_pull_fallback")
        return true
    end

    return false
end

-- =========================================================
-- OnEntityHurt
-- =========================================================
function ld.OnEntityHurt(data)
    if not ui.on:Get() or not ui.stack_enable:Get() then return end
    if not data then return end

    local source = data.source
    if not source or source ~= bear then return end

    if st.phase == "aggro" and not st.pull_issued then
        st.hit_confirmed  = true
        st.phase          = "pull"
        st.pull_issued    = true
        st.last_move_time = GameRules.GetGameTime()

        if st.pull_pos and bear and alive(bear) then
            hum_now = GameRules.GetGameTime()
            bm_force(st.pull_pos, "stack_pull_onhit")
        end
    end
end

-- =========================================================
-- CORE
-- =========================================================
local function on_tick(now)
    npc_cache = NPCs.GetAll()
    build_neutral_cache()
    entangle_cast_this_tick = false

    if not bear or not alive(bear) then
        reset_hum_state()
        reset_def_state()
        npc_cache = nil
        neutral_cache = nil
        return
    end

    local bpos = gp(bear)
    if not bpos then
        reset_hum_move()
        npc_cache = nil
        neutral_cache = nil
        return
    end

    local aghs = has_aghs()

    if aghs then
        entangle_cast_this_tick = do_aghs(bpos)
    end

    if ui.push:Get() then
        if not can_use_independent_modes() then
            npc_cache = nil
            neutral_cache = nil
            return
        end

        if ui.stack_push:Get() and do_stack(bpos) then
            reset_farm_state()
            npc_cache = nil
            neutral_cache = nil
            return
        end

        reset_farm_state()
        do_push(bpos)

    elseif ui.farm:Get() then
        if not can_use_independent_modes() then
            npc_cache = nil
            neutral_cache = nil
            return
        end

        if ui.stack_farm:Get() and do_stack(bpos) then
            npc_cache = nil
            neutral_cache = nil
            return
        end

        do_farm(bpos, now)

    elseif ui.follow:Get() and not aghs then
        reset_farm_state()
        reset_stack_state()

        if hero then
            local hp = gp(hero)
            if hp then
                local dist = d2(bpos, hp)
                if dist > FOL_START then
                    hum_follow_active = true
                elseif dist < FOL_STOP then
                    hum_follow_active = false
                end
                if hum_follow_active and not entangle_cast_this_tick then
                    bm(hp, "follow_move", false)
                end
            end
        end
    else
        reset_farm_state()
        reset_stack_state()
    end

    npc_cache = nil
    neutral_cache = nil
end

-- =========================================================
-- BINDS
-- =========================================================
local function check_binds()
    local t = ui.k_toggle:IsPressed()
    if t and not bind_prev.toggle then
        ui.on:Set(not ui.on:Get())
    end
    bind_prev.toggle = t

    local p = ui.k_push:IsPressed()
    if p and not bind_prev.push then
        local v = not ui.push:Get()
        ui.push:Set(v)
        if v then ui.farm:Set(false) end
    end
    bind_prev.push = p

    local f = ui.k_farm:IsPressed()
    if f and not bind_prev.farm then
        local v = not ui.farm:Get()
        ui.farm:Set(v)
        if v then ui.push:Set(false) end
    end
    bind_prev.farm = f
end

-- =========================================================
-- FRAME
-- =========================================================
function ld.OnFrame()
    if not ui.on:Get() then return end

    -- =====================================================
    -- ОБНОВЛЕННАЯ СИСТЕМА ПЕРЕТАСКИВАНИЯ (БЕЗОПАСНАЯ)
    -- =====================================================
    if ui.drag_mode:Get() then
        local mx, my = get_cursor()
        local is_down = is_lmb_down()

        if is_down and not drag_state.was_down then
            -- Проверка клика по основной панели
            if ui.show_panel:Get() then
                local px, py = ui.panel_x:Get(), ui.panel_y:Get()
                if mx and my and is_mouse_in_rect(mx, my, px, py, 290, 178) then
                    drag_state.main_active = true
                    drag_state.main_dx = mx - px
                    drag_state.main_dy = my - py
                end
            end

            -- Проверка клика по панели Warning
            local show_warn = ui.show_warning:Get()
                and (ui.push:Get() or ui.farm:Get())
                and ui.only_aghs:Get()
                and not has_aghs()

            if show_warn then
                local wx, wy = ui.aghs_x:Get(), ui.aghs_y:Get()
                if mx and my and is_mouse_in_rect(mx, my, wx, wy, 360, 78) then
                    drag_state.aghs_active = true
                    drag_state.aghs_dx = mx - wx
                    drag_state.aghs_dy = my - wy
                end
            end

        elseif not is_down then
            -- Кнопку отпустили — сбрасываем захват
            drag_state.main_active = false
            drag_state.aghs_active = false
        end

        -- Если панель захвачена, обновляем ее координаты в слайдере с учетом смещения
        if drag_state.main_active and mx and my then
            ui.panel_x:Set(math.max(0, math.floor(mx - drag_state.main_dx)))
            ui.panel_y:Set(math.max(0, math.floor(my - drag_state.main_dy)))
        end

        if drag_state.aghs_active and mx and my then
            ui.aghs_x:Set(math.max(0, math.floor(mx - drag_state.aghs_dx)))
            ui.aghs_y:Set(math.max(0, math.floor(my - drag_state.aghs_dy)))
        end

        drag_state.was_down = is_down
    else
        -- Защита от залипания, если выключили тумблер во время перетаскивания
        drag_state.main_active = false
        drag_state.aghs_active = false
        drag_state.was_down = false
    end
    -- =====================================================

    -- Warning panel (only when only_aghs is ON and no aghs)
    if ui.show_warning:Get()
    and (ui.push:Get() or ui.farm:Get())
    and ui.only_aghs:Get()
    and not has_aghs() then
        local wx, wy = ui.aghs_x:Get(), ui.aghs_y:Get()

        local wlines = {
            L("Нужен Аганим для Push / Farm / Stack",
              "Aghanim needed for Push / Farm / Stack"),
            L("Включи другой режим или выдай Aghanim",
              "Switch mode or give Aghanim to bear"),
        }
        local wcol = {
            Color(255, 120, 120, 255),
            Color(210, 210, 210, 255),
        }

        draw_pretty_panel(wx, wy, 360, 78,
            "LONE DRUID WARNING",
            wlines, wcol, ui.drag_mode:Get())
    end

    -- Main panel
    if not ui.show_panel:Get() then return end

    local x, y   = ui.panel_x:Get(), ui.panel_y:Get()
    local mode    = mode_name()
    local aghs_s  = has_aghs() and L("ДА", "YES") or L("НЕТ", "NO")
    local bear_hp = "N/A"
    local now     = GameRules.GetGameTime()
    local d_now   = panic_active(now)

    if bear and alive(bear) then
        bear_hp = tostring(math.floor(bear_hp_pct())) .. "%"
    end

    local stack_state = "OFF"
    if st.active then
        stack_state = string.upper(st.phase or "?")
    elseif ui.stack_enable:Get() then
        stack_state = L("ГОТОВ", "READY")
    end

    local cur_camp = "-"
    if st.camp_id then
        cur_camp = tostring(st.camp_id)
    elseif camp_id then
        cur_camp = tostring(camp_id)
    end

    local _, minute, sec = game_min_sec()

    local aghs_gate = ""
    if ui.only_aghs:Get() and not has_aghs() and (ui.farm:Get() or ui.push:Get()) then
        aghs_gate = "  " .. L("[ЗАБЛОК]", "[BLOCKED]")
    end

    local def_text = L("Защита: ", "Defense: ")
        .. (d_now and tostring(def.reason or "PANIC") or L("БЕЗОПАСНО", "SAFE"))

    local lines = {
        "AI: "   .. (ui.on:Get() and "ON" or "OFF"),
        L("Режим: ", "Mode: ")       .. mode .. aghs_gate,
        L("Аганим: ", "Aghs: ")      .. aghs_s,
        L("HP Медведя: ", "Bear HP: ") .. bear_hp,
        def_text,
        L("Кемп: ", "Camp: ")        .. cur_camp,
        L("Стак: ", "Stack: ")       .. stack_state,
        L("Время: ", "Time: ")       .. tostring(minute) .. ":" .. string.format("%02d", math.floor(sec)),
    }

    local lc = {}
    lc[1] = ui.on:Get() and Color(120, 255, 170, 255) or Color(255, 100, 100, 255)

    if     mode == "PUSH"   then lc[2] = Color(255, 210, 120, 255)
    elseif mode == "FARM"   then lc[2] = Color(120, 200, 255, 255)
    elseif mode == "FOLLOW" then lc[2] = Color(190, 160, 255, 255)
    else                         lc[2] = Color(170, 170, 170, 255) end

    if aghs_gate ~= "" then
        lc[2] = Color(255, 80, 80, 255)
    end

    lc[3] = has_aghs() and Color(120, 255, 170, 255) or Color(255, 110, 110, 255)

    local hp_num = tonumber(string.match(bear_hp, "(%d+)"))
    if hp_num then
        if     hp_num <= 25 then lc[4] = Color(255, 80, 80, 255)
        elseif hp_num <= 50 then lc[4] = Color(255, 180, 80, 255)
        else                     lc[4] = Color(180, 230, 180, 255) end
    else
        lc[4] = Color(170, 170, 170, 255)
    end

    lc[5] = d_now and Color(255, 90, 90, 255) or Color(150, 150, 150, 255)
    lc[6] = Color(210, 210, 210, 255)

    if stack_state == "PULL" or stack_state == "AGGRO"
    or stack_state == "APPROACH" or stack_state == "WAIT" then
        lc[7] = Color(255, 210, 120, 255)
    elseif stack_state == "DONE" then
        lc[7] = Color(120, 255, 170, 255)
    else
        lc[7] = Color(160, 160, 160, 255)
    end

    lc[8] = Color(150, 150, 150, 255)

    draw_pretty_panel(x, y, 290, 178,
        "LONE DRUID BEAR",
        lines, lc, ui.drag_mode:Get())

    -- Defense alert
    if ui.def_alert:Get() and d_now and Render.GetScreenSize then
        local scr = Render.GetScreenSize()
        local txt = L("ЗАЩИТА МЕДВЕДЯ: ", "BEAR DEFENSE: ")
                  .. tostring(def.reason or "PANIC")
        local sz  = Render.TextSize(font_big, 14, txt)

        local cx = math.floor((scr.x - sz.x) * 0.5)
        local cy = math.floor(scr.y * 0.18)

        Render.FilledRect(Vec2(cx - 14, cy - 8), Vec2(cx + sz.x + 14, cy + 26), Color(10, 10, 10, 190))
        Render.Rect(Vec2(cx - 14, cy - 8), Vec2(cx + sz.x + 14, cy + 26), Color(220, 70, 70, 220))
        Render.Text(font_big, 14, txt, Vec2(cx, cy), Color(255, 80, 80, 255))
    end
end

-- =========================================================
-- MAIN
-- =========================================================
function ld.OnUpdate()
    check_binds()

    if not ui.on:Get() then
        reset_farm_state()
        reset_stack_state()
        reset_hum_state()
        reset_def_state()
        return
    end

    if not hero then
        player = Players.GetLocal()
        hero   = Heroes.GetLocal()
        if not hero or not player then return end
        init_teams()

        for i = 0, 5 do
            local it = sc(NPC.GetItemByIndex, hero, i)
            if it then
                local n = sc(Ability.GetName, it)
                if n then prev_items[n] = true end
            end
        end
        return
    end

    if not alive(hero) then
        reset_hum_state()
        reset_def_state()
        return
    end

    if not our_team then
        init_teams()
        return
    end

    refresh_bear()

    if not bear or not alive(bear) then
        reset_farm_state()
        reset_stack_state()
        reset_hum_state()
        reset_def_state()
        return
    end

    local now = GameRules.GetGameTime()
    hum_now = now

    local bpos = gp(bear)
    if bpos and do_defense(bpos, now) then
        reset_farm_state()
        if not (st.active and st.phase == "aggro") then
            reset_stack_state()
        end
        return
    end

    do_transfer(now)

    if st.active and (st.phase == "aggro" or st.phase == "pull") then
        on_tick(now)
        return
    end

    if ui.hum_on:Get() then
        if now < hum_next_tick then return end
        local add = ui.hum_delay:Get() / 1000.0
        hum_next_tick = now + TICK + (math.random() * add)
    else
        if now - last_tick < TICK then return end
        last_tick = now
    end

    on_tick(now)
end

return ld