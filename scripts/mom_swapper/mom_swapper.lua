---@diagnostic disable: undefined-global, param-type-mismatch, inject-field
--[[
    MoM Swapper
    Mask of Madness <-> Echo Sabre / Specialist's Array через общий Broadsword.

    Как работает:
      1. Разбираем текущий собранный предмет (компоненты после разборки игра сама лочит).
      2. Разлочиваем компоненты целевого предмета, Broadsword последним.
      3. Игра сама собирает нужный предмет. Компоненты "другого" предмета остаются залоченными.

    Режимы:
      Auto   - МоМ собран, когда Berserk готов (или вот-вот будет), всё остальное время сабля/аррей.
      Manual - пересборка по бинду.

    Защиты: проверка станa/хекса, свободных слотов (чтобы ничего не упало на землю),
    владельца предметов, возможности разборки, ретраи с таймаутом, анти-флаппинг.
]]

local VERSION = "1.0.0"
local script = {}

--#region Localization (qLocalizer, если загружен; иначе английский фолбэк)
local TR = {
    en = {
        ["MoM Swapper"] = "MoM Swapper",
        ["Main"] = "Main",
        ["General"] = "General",
        ["Auto mode"] = "Auto mode",
        ["Visuals"] = "Visuals",
        ["Enabled"] = "Enabled",
        ["Mode"] = "Mode",
        ["Auto"] = "Auto",
        ["Manual"] = "Manual",
        ["Second item"] = "Second item",
        ["Detect"] = "Detect from inventory",
        ["Echo Sabre"] = "Echo Sabre",
        ["Specialist's Array"] = "Specialist's Array",
        ["Swap key"] = "Swap key",
        ["Mode key"] = "Toggle Auto / Manual",
        ["Prebuild"] = "Build MoM before CD ends",
        ["After cast delay"] = "Swap delay after Berserk",
        ["Keep during Berserk"] = "Keep MoM while Berserk is active",
        ["Min interval"] = "Min interval between swaps",
        ["Allow one-way"] = "Allow one-way builds",
        ["Array refresh"] = "Refresh before lock",
        ["Refresh margin"] = "Refresh margin",
        ["Low HP fallback"] = "Back to MoM below HP",
        ["Draw HUD"] = "Draw HUD",
        ["HUD X"] = "HUD offset X",
        ["HUD Y"] = "HUD offset Y",
        ["Debug log"] = "Debug log",
        tt_swap = "Manual mode only: MoM <-> second item.",
        tt_prebuild = "How early MoM is assembled before Berserk comes off cooldown.",
        tt_after = "Wait a bit after casting Berserk before swapping MoM away.",
        tt_keep = "Do not disassemble MoM while the Berserk buff is active.",
        tt_oneway = "Allow building an item that the game won't let you disassemble back (Specialist's Array is not disassemblable by default). MoM will be gone until you rebuild it yourself.",
        tt_refresh = "Specialist's Array can only be disassembled for 10s after it's assembled. The script rebuilds it before that window closes, which starts a new 10s window. Death or a stun at the wrong moment still locks it.",
        tt_margin = "How long before the 10s window closes to start the rebuild. Raise it if you have high ping.",
        tt_lowhp = "While Array is built and HP drops below this, switch to MoM (dying locks the Array). 0 = off.",
        hud = {
            auto = "AUTO",
            manual = "MANUAL",
            ready = "RDY",
            active = "ON",
            parts_ok = "ready",
            no_parts = "no parts",
            busy = "swapping...",
            hint_manual = "press bind to swap",
            hint_auto = "auto",
            disabled = "stunned / hexed",
            no_slots = "no free slots",
            not_disasm = "can't disassemble",
            oneway = "one-way build blocked",
            no_alt = "no Sabre / Array parts",
            failed = "swap failed",
            wrong = "wrong item assembled",
            refreshing = "refreshing Array...",
            array_lost = "Array locked, MoM is gone",
            locked = "LOCKED",
        },
    },
    ru = {
        ["MoM Swapper"] = "MoM Swapper",
        ["Main"] = "Главное",
        ["General"] = "Основное",
        ["Auto mode"] = "Авто режим",
        ["Visuals"] = "Визуал",
        ["Enabled"] = "Включено",
        ["Mode"] = "Режим",
        ["Auto"] = "Авто",
        ["Manual"] = "Ручной",
        ["Second item"] = "Второй предмет",
        ["Detect"] = "Определять по инвентарю",
        ["Echo Sabre"] = "Echo Sabre",
        ["Specialist's Array"] = "Specialist's Array",
        ["Swap key"] = "Бинд пересборки",
        ["Mode key"] = "Переключить Авто / Ручной",
        ["Prebuild"] = "Собирать МоМ до конца КД",
        ["After cast delay"] = "Задержка после Берсерка",
        ["Keep during Berserk"] = "Держать МоМ пока активен Берсерк",
        ["Min interval"] = "Мин. интервал между пересборками",
        ["Allow one-way"] = "Разрешить необратимую сборку",
        ["Array refresh"] = "Пересобирать до невозврата",
        ["Refresh margin"] = "Запас до невозврата",
        ["Low HP fallback"] = "Вернуть МоМ при HP ниже",
        ["Draw HUD"] = "Рисовать HUD",
        ["HUD X"] = "Сдвиг HUD по X",
        ["HUD Y"] = "Сдвиг HUD по Y",
        ["Debug log"] = "Логи в консоль",
        tt_swap = "Только ручной режим: МоМ <-> второй предмет.",
        tt_prebuild = "За сколько до конца КД Берсерка собирать МоМ.",
        tt_after = "Сколько подождать после каста Берсерка перед разборкой МоМа.",
        tt_keep = "Не разбирать МоМ, пока висит бафф Берсерка.",
        tt_oneway = "Разрешить собирать предмет, который игра не даёт разобрать обратно (Specialist's Array по умолчанию не разбирается). МоМ пропадёт, пока не соберёшь руками.",
        tt_refresh = "Specialist's Array разбирается только 10с после сборки. Скрипт пересобирает его до конца окна, и окно начинается заново. Смерть или стан в неудачный момент всё равно залочат его.",
        tt_margin = "За сколько до конца 10с окна начинать пересборку. С высоким пингом ставь больше.",
        tt_lowhp = "Если собран Array и HP ниже порога, собрать МоМ (смерть лочит Array). 0 = выкл.",
        hud = {
            auto = "АВТО",
            manual = "РУЧНОЙ",
            ready = "ГОТОВ",
            active = "ВКЛ",
            parts_ok = "готов",
            no_parts = "нет частей",
            busy = "пересобираю...",
            hint_manual = "жми бинд",
            hint_auto = "авто",
            disabled = "стан / хекс",
            no_slots = "нет свободных слотов",
            not_disasm = "не разбирается",
            oneway = "необратимая сборка запрещена",
            no_alt = "нет частей сабли / аррея",
            failed = "пересборка не удалась",
            wrong = "собралось не то",
            refreshing = "освежаю Array...",
            array_lost = "Array залочен, МоМа больше нет",
            locked = "ЛОК",
        },
    },
}

local function resolve(t, path)
    for k in path:gmatch("[^.]+") do
        if type(t) ~= "table" then return nil end
        t = t[k]
    end
    return t
end

local Loc = (type(qLocalization) == "table" and qLocalization.new) and qLocalization.new(TR) or nil
local M = Loc and Loc.WrapLibrary(Menu) or Menu

local function T(path)
    if Loc then return Loc.Get(path) end
    return resolve(TR.en, path) or path
end
--#endregion

--#region Menu
local tab = M.Create("Scripts", "Other", "MoM Swapper")
tab:Icon("\u{f0ec}")
local section = tab:Create("Main")
local g_main = section:Create("General")
local g_auto = section:Create("Auto mode")
local g_array = section:Create("Specialist's Array")
local g_vis = section:Create("Visuals")

local function fmt_ms(v) return ("%d ms"):format(v) end
local function fmt_px(v) return ("%d px"):format(v) end

local MODE_AUTO, MODE_MANUAL = 0, 1
local ALT_DETECT, ALT_SABRE, ALT_ARRAY = 0, 1, 2

local ui = {}
ui.enabled      = g_main:Switch("Enabled", false, "\u{f00c}")
ui.mode         = g_main:Combo("Mode", { "Auto", "Manual" }, MODE_AUTO)
ui.alt          = g_main:Combo("Second item", { "Detect", "Echo Sabre", "Specialist's Array" }, ALT_DETECT)
ui.swap_key     = g_main:Bind("Swap key", Enum.ButtonCode.KEY_NONE)
ui.mode_key     = g_main:Bind("Mode key", Enum.ButtonCode.KEY_NONE)

ui.prebuild     = g_auto:Slider("Prebuild", 0, 1500, 250, fmt_ms)
ui.after_cast   = g_auto:Slider("After cast delay", 0, 1000, 80, fmt_ms)
ui.keep_berserk = g_auto:Switch("Keep during Berserk", false)
ui.min_interval = g_auto:Slider("Min interval", 100, 3000, 500, fmt_ms)
ui.allow_oneway = g_auto:Switch("Allow one-way", false)

ui.array_refresh = g_array:Switch("Array refresh", true)
ui.refresh_margin = g_array:Slider("Refresh margin", 500, 4000, 2000, fmt_ms)
ui.low_hp         = g_array:Slider("Low HP fallback", 0, 60, 25, function(v) return v == 0 and "off" or (v .. "%") end)

ui.hud          = g_vis:Switch("Draw HUD", true)
ui.hud_x        = g_vis:Slider("HUD X", -800, 800, 0, fmt_px)
ui.hud_y        = g_vis:Slider("HUD Y", -600, 600, 0, fmt_px)
ui.debug        = g_vis:Switch("Debug log", false)

local function tip(w, key) w:ToolTip(Loc and key or T(key)) end
tip(ui.swap_key, "tt_swap")
tip(ui.prebuild, "tt_prebuild")
tip(ui.after_cast, "tt_after")
tip(ui.keep_berserk, "tt_keep")
tip(ui.allow_oneway, "tt_oneway")
tip(ui.array_refresh, "tt_refresh")
tip(ui.refresh_margin, "tt_margin")
tip(ui.low_hp, "tt_lowhp")

ui.swap_key:Properties("MoM Swap")
ui.mode_key:Properties("MoM Auto", nil, true)

local function refresh_widgets()
    local on = ui.enabled:Get()
    local auto = ui.mode:Get() == MODE_AUTO
    for _, w in ipairs({ ui.mode, ui.alt, ui.swap_key, ui.mode_key, ui.allow_oneway, ui.array_refresh,
                         ui.hud, ui.hud_x, ui.hud_y, ui.debug }) do
        w:Disabled(not on)
    end
    for _, w in ipairs({ ui.prebuild, ui.after_cast, ui.keep_berserk, ui.min_interval }) do
        w:Disabled(not on or not auto)
    end
    local rf = on and ui.array_refresh:Get()
    ui.refresh_margin:Disabled(not rf)
    ui.low_hp:Disabled(not rf)
    ui.mode_key:SetToggled(auto)
end
ui.enabled:SetCallback(refresh_widgets, true)
ui.mode:SetCallback(refresh_widgets, true)
ui.array_refresh:SetCallback(refresh_widgets, true)
--#endregion

--#region Data
local BROAD = "item_broadsword"
local RECIPE_ARRAY = "item_recipe_specialists_array"
local BERSERK_MOD = "modifier_item_mask_of_madness_berserk"

-- broadsword всегда последним: пока он залочен, ничего не соберётся раньше времени
local BUILDS = {
    mom   = { name = "item_mask_of_madness",  parts = { "item_lifesteal", BROAD } },
    sabre = { name = "item_echo_sabre",       parts = { "item_ogre_axe", "item_void_stone", BROAD } },
    array = { name = "item_specialists_array", parts = { "item_blade_of_alacrity", RECIPE_ARRAY, BROAD } },
}
local BUILD_KEYS = { "mom", "sabre", "array" }

-- Предметы, которые (по данным вики) нельзя разобрать после 10с грейса.
-- Уточняется в рантайме через Item.IsDisassemblable, когда предмет реально собран.
local oneway = { array = true }

local IMG = {
    mom   = Render.LoadImage("panorama/images/items/mask_of_madness_png.vtex_c"),
    sabre = Render.LoadImage("panorama/images/items/echo_sabre_png.vtex_c"),
    array = Render.LoadImage("panorama/images/items/specialists_array_png.vtex_c"),
}
local font = Render.LoadFont("MuseoSansEx", Enum.FontCreate.FONTFLAG_ANTIALIAS)
--#endregion

--#region State
local hero, player, my_pid
local inv = {}          -- item name -> CItem (слоты 0..8: инвентарь + рюкзак)
local free_slots = 0

local mom_ready_at = 0  -- игровое время, когда Берсерк откатится (КД привязан к герою и живёт при разборке)
local mom_cast_at = -100
local prev_mom_cd = 0

local job = nil         -- текущая пересборка
local last_swap = -100
local fail_until = 0
local status_key, status_time, status_sticky = nil, -100, false

local key_swap_pressed, key_mode_pressed = false, false

local ARRAY_GRACE = 10.0   -- окно разборки после сборки
local array_built_at = -100
local array_lost = false

local function now() return GameRules.GetGameTime() end

local function log(fmt, ...)
    if ui.debug:Get() then print(("[MoM Swapper] " .. fmt):format(...)) end
end

local function set_status(key, sticky)
    if status_key ~= key then log("status: %s", tostring(key)) end
    status_key, status_time, status_sticky = key, now(), sticky or false
end

local function reset()
    hero, player, my_pid = nil, nil, nil
    for k in pairs(inv) do inv[k] = nil end
    mom_ready_at, mom_cast_at, prev_mom_cd = 0, -100, 0
    job, last_swap, fail_until = nil, -100, 0
    status_key = nil
    oneway = { array = true }
    array_built_at, array_lost = -100, false
end
--#endregion

--#region Inventory helpers
local function is_mine(item)
    if not my_pid then return true end
    local ok, pid = pcall(Item.GetPlayerOwnerID, item)
    return not ok or pid == my_pid
end

local function scan_inventory()
    for k in pairs(inv) do inv[k] = nil end
    free_slots = 0
    for slot = 0, 8 do
        local item = NPC.GetItemByIndex(hero, slot)
        if item then
            local name = Ability.GetName(item)
            if name:find("^item_recipe_specialist") then name = RECIPE_ARRAY end
            if not inv[name] and is_mine(item) then inv[name] = item end
        else
            free_slots = free_slots + 1
        end
    end
end

local function built_key()
    for _, key in ipairs(BUILD_KEYS) do
        if inv[BUILDS[key].name] then return key end
    end
    return nil
end

-- есть ли все компоненты key россыпью (broadsword может сидеть в собранном from)
local function loose_parts_ready(key, from)
    if from == key then return true end -- пересборка того же предмета
    for _, p in ipairs(BUILDS[key].parts) do
        if not inv[p] and not (p == BROAD and from) then return false end
    end
    return true
end

local function alt_key()
    local mode = ui.alt:Get()
    if mode == ALT_SABRE then return "sabre" end
    if mode == ALT_ARRAY then return "array" end
    if inv[BUILDS.sabre.name] or (inv["item_ogre_axe"] and inv["item_void_stone"]) then return "sabre" end
    if inv[BUILDS.array.name] or inv["item_blade_of_alacrity"] then return "array" end
    return nil
end

local function hero_disabled()
    return NPC.IsStunned(hero) or NPC.HasState(hero, Enum.ModifierState.MODIFIER_STATE_HEXED)
end

local function item_order(kind, item)
    Player.PrepareUnitOrders(
        player, kind, nil, Vector(), item,
        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_CURRENT_UNIT_ONLY,
        hero, false, false, false, true, "mom_swapper"
    )
end

local function set_lock(item, lock)
    if item and Item.IsCombineLocked(item) ~= lock then
        item_order(Enum.UnitOrder.DOTA_UNIT_ORDER_SET_ITEM_COMBINE_LOCK, item)
        return true
    end
    return false
end
--#endregion

--#region MoM cooldown tracking
local function track_mom()
    local t = now()
    local mom = inv[BUILDS.mom.name]
    if mom then
        local cd = Ability.GetCooldown(mom)
        if cd > 0 then
            if prev_mom_cd <= 0.05 then mom_cast_at = t end
            mom_ready_at = t + cd
        else
            mom_ready_at = t
        end
        prev_mom_cd = cd
    else
        prev_mom_cd = math.max(0, mom_ready_at - t)
    end
end

local function mom_remaining()
    return math.max(0, mom_ready_at - now())
end
--#endregion

--#region Swap job
local function can_swap(from, to)
    if not loose_parts_ready(to, from) then
        return false, (to == "mom") and "no_parts" or "no_alt"
    end
    local refresh_ok = to == "array" and ui.array_refresh:Get()
    if oneway[to] and not ui.allow_oneway:Get() and not refresh_ok then return false, "oneway" end
    if hero_disabled() then return false, "disabled" end
    if from then
        local item = inv[BUILDS[from].name]
        if not Item.IsDisassemblable(item) then
            oneway[from] = true
            return false, "not_disasm"
        end
        local need = #BUILDS[from].parts - 1
        if free_slots < need then return false, "no_slots" end
    end
    return true
end

local function try_swap(from, to, manual, refresh)
    if from == to and not refresh then return end
    local ok, reason = can_swap(from, to)
    if not ok then
        set_status(reason, not manual)
        return
    end
    job = {
        from = from, to = to,
        stage = from and "disasm" or "asm",
        t0 = now(), last = -100, tries = 0, lock_tries = 0,
    }
    if refresh then set_status("refreshing") else set_status(nil) end
    log("swap %s -> %s", tostring(from), to)
end

local function finish_job(ok, reason)
    local t = now()
    if ok then
        log("done -> %s (%.2fs)", job.to, t - job.t0)
        last_swap = t
        if job.to == "array" then array_built_at = t end
        if status_key == "refreshing" then status_key = nil end
    else
        log("fail: %s", reason)
        set_status(reason)
        fail_until = t + 1.5
    end
    job = nil
end

local function process_job()
    local t = now()
    local target = BUILDS[job.to]

    if inv[target.name] and job.stage == "asm" then
        return finish_job(true)
    end
    if t - job.t0 > 3.0 then return finish_job(false, "failed") end

    for _, key in ipairs(BUILD_KEYS) do
        if key ~= job.to and key ~= job.from and inv[BUILDS[key].name] then
            return finish_job(false, "wrong")
        end
    end

    if job.stage == "disasm" then
        local from_item = inv[BUILDS[job.from].name]
        if from_item then
            if hero_disabled() then return end
            if t - job.last >= 0.3 then
                if job.tries >= 4 then return finish_job(false, "failed") end
                item_order(Enum.UnitOrder.DOTA_UNIT_ORDER_DISASSEMBLE_ITEM, from_item)
                job.last, job.tries = t, job.tries + 1
            end
            return
        end
        if not inv[BROAD] then return end -- ждём, пока компоненты появятся в инвентаре
        job.stage, job.last, job.tries = "asm", -100, 0
    end

    -- stage "asm"
    if t - job.last < 0.12 then return end
    job.last = t

    -- если у "чужого" предмета все компоненты разлочены, лочим один, чтобы broadsword не ушёл туда
    if job.lock_tries < 3 then
        for _, key in ipairs(BUILD_KEYS) do
            if key ~= job.to then
                local all_unlocked, first = true, nil
                for _, p in ipairs(BUILDS[key].parts) do
                    if p ~= BROAD then
                        local it = inv[p]
                        if not it or Item.IsCombineLocked(it) then all_unlocked = false break end
                        first = first or it
                    end
                end
                if all_unlocked and first and set_lock(first, true) then
                    job.lock_tries = job.lock_tries + 1
                    return
                end
            end
        end
    end

    local others_pending = false
    for _, p in ipairs(target.parts) do
        local it = inv[p]
        if not it then return finish_job(false, "no_alt") end
        if p ~= BROAD and set_lock(it, false) then others_pending = true end
    end
    if others_pending then return end

    job.tries = job.tries + 1
    if job.tries > 8 then return finish_job(false, "failed") end
    set_lock(inv[BROAD], false)
end
--#endregion

--#region Specialist's Array guard
local function hp_pct()
    local mx = Entity.GetMaxHealth(hero)
    if not mx or mx <= 0 then return 100 end
    return Entity.GetHealth(hero) / mx * 100
end

local function array_low_hp()
    local thr = ui.low_hp:Get()
    return thr > 0 and Entity.IsAlive(hero) and hp_pct() < thr
end

local function array_grace_left(item)
    local at = Item.GetAssembledTime(item)
    if not at or at <= 0 or at < array_built_at - 0.5 then at = array_built_at end
    return at + ARRAY_GRACE - now()
end

-- true = ситуацию с Array обработали, дальше не решаем
local function array_guard(cur)
    if cur ~= "array" or not ui.array_refresh:Get() then return false end
    local item = inv[BUILDS.array.name]

    if not Item.IsDisassemblable(item) then
        if not array_lost then
            array_lost = true
            set_status("array_lost", true)
        end
        return true
    end
    array_lost = false
    if not Entity.IsAlive(hero) then return true end

    if array_low_hp() and loose_parts_ready("mom", "array") then
        try_swap("array", "mom", false)
        return true
    end

    local margin = ui.refresh_margin:Get() / 1000
    if array_grace_left(item) > margin then return false end

    -- в авто: если МоМ скоро всё равно нужен, сразу в МоМ, иначе освежаем Array
    local to = "array"
    if ui.mode:Get() == MODE_AUTO and loose_parts_ready("mom", "array")
        and mom_remaining() <= ui.prebuild:Get() / 1000 + margin + 1.0 then
        to = "mom"
    end
    log("array grace %.2fs -> %s", array_grace_left(item), to)
    try_swap("array", to, false, to == "array")
    return true
end
--#endregion

--#region Decision
local function auto_logic(cur, alt)
    local t = now()
    local want
    if ui.keep_berserk:Get() and NPC.HasModifier(hero, BERSERK_MOD) then
        want = "mom"
    elseif mom_remaining() <= ui.prebuild:Get() / 1000 then
        want = "mom"
    elseif alt == "array" and ui.array_refresh:Get() and array_low_hp() then
        want = "mom"
    else
        if cur == "mom" and t - mom_cast_at < ui.after_cast:Get() / 1000 then return end
        want = alt
    end
    if want == cur then
        if status_sticky then status_key = nil end
        return
    end
    if t - last_swap < ui.min_interval:Get() / 1000 or t < fail_until then return end
    try_swap(cur, want, false)
end

local function manual_logic(cur, alt)
    local target
    if cur == "mom" then target = alt
    elseif cur then target = "mom"
    else target = loose_parts_ready("mom") and "mom" or alt end
    if not target then return set_status("no_alt") end
    try_swap(cur, target, true)
end
--#endregion

--#region Callbacks
function script.OnUpdate()
    if not ui.enabled:Get() then job = nil return end
    if not Engine.IsInGame() then return end

    local h = Heroes.GetLocal()
    if not h then return end
    if h ~= hero then reset() hero = h end
    player = player or Players.GetLocal()
    if not player then return end
    if not my_pid then my_pid = Player.GetPlayerID(player) end

    scan_inventory()
    track_mom()

    if key_mode_pressed then
        key_mode_pressed = false
        ui.mode:Set(ui.mode:Get() == MODE_AUTO and MODE_MANUAL or MODE_AUTO)
        refresh_widgets()
    end

    local swap_now = key_swap_pressed
    key_swap_pressed = false

    if job then return process_job() end

    -- нет даже частей МоМа - нечего делать
    if not inv[BUILDS.mom.name] and not inv["item_lifesteal"] then return end

    local cur = built_key()
    local alt = alt_key()

    if not swap_now and array_guard(cur) then return end

    if ui.mode:Get() ~= MODE_AUTO then
        if swap_now then manual_logic(cur, alt) end
        return
    end
    if not alt then return set_status("no_alt", true) end
    auto_logic(cur, alt)
end

-- HUD
local anchor, anchor_clock = nil, -100
local function get_anchor()
    local c = os.clock()
    if c - anchor_clock < 2 then return anchor end
    anchor_clock = c
    local min_x, min_y, max_x = math.huge, math.huge, -math.huge
    for i = 0, 5 do
        local p = Panorama.GetPanelByName("inventory_slot_" .. i, false)
        if p and p:IsValid() then
            local b = p:GetBounds()
            min_x, min_y = math.min(min_x, b.x), math.min(min_y, b.y)
            max_x = math.max(max_x, b.x + b.w)
        end
    end
    anchor = (min_x ~= math.huge) and { cx = (min_x + max_x) / 2, top = min_y } or nil
    return anchor
end

local C_BG     = Color(18, 18, 22, 215)
local C_ROW    = Color(255, 255, 255, 10)
local C_ON     = Color(90, 220, 120, 60)
local C_BUSY   = Color(255, 200, 60, 70)
local C_TXT    = Color(235, 235, 235, 255)
local C_DIM    = Color(150, 150, 160, 255)
local C_OK     = Color(110, 230, 140, 255)
local C_WARN   = Color(255, 200, 70, 255)
local C_ERR    = Color(255, 95, 95, 255)
local C_ACCENT = Color(170, 120, 255, 255)
local C_IMG    = Color(255, 255, 255, 255)
local C_IMG_DIM = Color(255, 255, 255, 90)

local ITEM_LABEL = { mom = "Mask of Madness", sabre = "Echo Sabre", array = "Specialist's Array" }
local W, ROW_H, ICON_H = 210, 30, 24
local ICON_W = math.floor(ICON_H * 1.375)

local function draw_row(x, y, key, built, right_text, right_color)
    local busy = job and job.to == key
    Render.FilledRect(Vec2(x + 6, y), Vec2(x + W - 6, y + ROW_H - 2),
        busy and C_BUSY or (built and C_ON or C_ROW), 4)
    if IMG[key] then
        Render.Image(IMG[key], Vec2(x + 10, y + (ROW_H - 2 - ICON_H) / 2), Vec2(ICON_W, ICON_H),
            built and C_IMG or C_IMG_DIM, 3)
    end
    Render.Text(font, 14, ITEM_LABEL[key], Vec2(x + 16 + ICON_W, y + 7), built and C_TXT or C_DIM)
    local sz = Render.TextSize(font, 15, right_text)
    Render.Text(font, 15, right_text, Vec2(x + W - 12 - sz.x, y + 6), right_color)
end

function script.OnDraw()
    if not ui.enabled:Get() then return end

    if not Input.IsInputCaptured() then
        if ui.swap_key:IsPressed() then key_swap_pressed = true end
        if ui.mode_key:IsPressed() then key_mode_pressed = true end
    end

    if not ui.hud:Get() or not hero then return end
    if not inv[BUILDS.mom.name] and not inv["item_lifesteal"] then return end
    local a = get_anchor()
    if not a then return end

    local alt = alt_key()
    local cur = built_key()
    local H = 8 + 18 + ROW_H * (alt and 2 or 1) + 20
    local x = math.floor(a.cx - W / 2 + ui.hud_x:Get())
    local y = math.floor(a.top - H - 14 + ui.hud_y:Get())

    Render.FilledRect(Vec2(x, y), Vec2(x + W, y + H), C_BG, 6)
    Render.FilledRect(Vec2(x, y), Vec2(x + 3, y + H), C_ACCENT, 2)

    local auto = ui.mode:Get() == MODE_AUTO
    Render.Text(font, 14, "MoM Swapper", Vec2(x + 10, y + 6), C_TXT)
    local mode_txt = auto and T("hud.auto") or T("hud.manual")
    local msz = Render.TextSize(font, 13, mode_txt)
    Render.Text(font, 13, mode_txt, Vec2(x + W - 10 - msz.x, y + 7), auto and C_ACCENT or C_WARN)

    local ry = y + 26
    local rem = mom_remaining()
    draw_row(x, ry, "mom", cur == "mom",
        rem > 0 and ("%.1f"):format(rem) or T("hud.ready"),
        rem > 0 and C_WARN or C_OK)
    ry = ry + ROW_H

    if alt then
        local built = cur == alt
        local txt, col
        if built and alt == "array" and ui.array_refresh:Get() then
            if array_lost then txt, col = T("hud.locked"), C_ERR
            else
                local left = math.max(0, array_grace_left(inv[BUILDS.array.name]))
                txt, col = ("%.1f"):format(left), (left <= ui.refresh_margin:Get() / 1000 + 1) and C_WARN or C_OK
            end
        elseif built then txt, col = T("hud.active"), C_OK
        elseif loose_parts_ready(alt, cur) then txt, col = T("hud.parts_ok"), C_DIM
        else txt, col = T("hud.no_parts"), C_ERR end
        draw_row(x, ry, alt, built, txt, col)
        ry = ry + ROW_H
    end

    local s_txt, s_col
    if job then
        s_txt, s_col = T("hud.busy"), C_WARN
    elseif status_key and (status_sticky or now() - status_time < 2.5) then
        s_txt, s_col = T("hud." .. status_key), C_ERR
    else
        s_txt, s_col = auto and T("hud.hint_auto") or T("hud.hint_manual"), C_DIM
    end
    Render.Text(font, 13, s_txt, Vec2(x + 10, ry + 2), s_col)
end

function script.OnGameEnd()
    reset()
end

function script.OnScriptsLoaded()
    reset()
end
--#endregion

return script
