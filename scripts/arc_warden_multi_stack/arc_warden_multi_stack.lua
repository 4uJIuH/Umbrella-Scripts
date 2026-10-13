local script = {}

local HERO = "npc_dota_hero_arc_warden"

local RADIANT = {
    CLONE_MOVE   = Vector(1230, -4239, 0),
    HERO_MOVE    = Vector(-1290, -4617, 0),
    CLONE_CAST   = Vector(284, -5076, 0),
    HERO_CAST    = Vector(-1419, -3380, 0),
    HERO_ATTACK  = Vector(-1928, -4766, 0),
    CLONE_ATTACK = Vector(1943, -3979, 0),
    HERO_RETREAT = Vector(-743, -4728, 0),
    CLONE_RETREAT= Vector(599, -3851, 0),
}

local DIRE = {
    HERO_MOVE    = Vector(697, 3981, 0),
    CLONE_MOVE   = Vector(-2610, 4286, 0),
    HERO_CAST    = Vector(1066, 2634, 0),
    CLONE_CAST   = Vector(-916, 4887, 0),
    HERO_ATTACK  = Vector(1194, 4202, 0),
    CLONE_ATTACK = Vector(-2619, 3918, 0),
    HERO_RETREAT = Vector(-111, 4054, 0),
    CLONE_RETREAT= Vector(-2767, 5101, 0),
}

local DEFAULT_CLONE_CAST_TIME = 52.7
local DEFAULT_HERO_CAST_TIME  = 53.9

local STOP_DISTANCE = 80
local ATTACK_SEARCH_RADIUS = 900
local POST_HIT_DELAY = 0.1
local ATTACK_TIMEOUT = 1.5

local BAT = 1.7
local BASE_HIT_DELAY = 0.6
local CLONE_EXTRA_DELAY = 0.15
local MIN_HIT_DELAY = 0.5
local MAX_HIT_DELAY = 1.2

local IAS_ITEMS = {
    ["item_hyperstone"]          = 60,
    ["item_mjollnir"]            = 90,
    ["item_moon_shard"]          = 140,
    ["item_moon_shard_consumed"] = 60,
    ["item_assault"]             = 30,
    ["item_hand_of_midas"]       = 40,
    ["item_power_treads"]        = 25,
    ["item_power_treads_agi"]    = 25,
    ["item_silver_edge"]         = 35,
    ["item_shadow_blade"]        = 35,
    ["item_butterfly"]           = 30,
    ["item_orchid_malevolence"]  = 35,
    ["item_bloodthorn"]          = 70,
    ["item_sange_and_yasha"]     = 20,
    ["item_yasha"]               = 15,
    ["item_manta"]               = 15,
    ["item_monkey_king_bar"]     = 50,
}

local NEUTRAL_IAS_ITEMS = {
    ["item_enhancement_quickened"] = 20,
    ["item_enhancement_brawny"]    = 10,
    ["item_enhancement_vast"]      = 20,
}

local function calculateAttackSpeed(hero)
    if not hero then return 0 end
    local agility = 0
    if Hero.GetAgility then
        local ok, agi = pcall(Hero.GetAgility, hero)
        if ok and agi then agility = agi end
    end
    if agility == 0 then
        local lvl = (Hero.GetLevel and Hero.GetLevel(hero)) or (NPC.GetCurrentLevel and NPC.GetCurrentLevel(hero)) or 1
        agility = 20 + (lvl - 1) * 2.6
    end
    local total_as = agility
    for slot = 0, 8 do
        local item = NPC.GetItemByIndex(hero, slot)
        if item then
            local name = nil
            if Entity.GetUnitName then
                local ok, n = pcall(Entity.GetUnitName, item)
                if ok then name = n end
            end
            if not name and Ability.GetName then
                local ok, n = pcall(Ability.GetName, item)
                if ok then name = n end
            end
            if name then
                local bonus = IAS_ITEMS[name] or NEUTRAL_IAS_ITEMS[name] or 0
                total_as = total_as + bonus
            end
        end
    end
    return total_as
end

local function calculateCloneHitDelay(hero)
    local as = calculateAttackSpeed(hero)
    local attack_interval = BAT / (1 + as / 100)
    local max_delay = attack_interval * 0.7
    local delay = BASE_HIT_DELAY + CLONE_EXTRA_DELAY
    if delay > max_delay then delay = max_delay end
    if delay < MIN_HIT_DELAY then delay = MIN_HIT_DELAY end
    if delay > MAX_HIT_DELAY then delay = MAX_HIT_DELAY end
    return delay, as, attack_interval
end

local heroSettings = Menu.Find("Heroes", "Hero List", "Arc Warden")
local tab = heroSettings:Create("Мульти Стак")
local controlMenu = tab:Create("Управление", Enum.GroupSide.Left)
local timingMenu = tab:Create("Тайминг Spark Wraith", Enum.GroupSide.Right)
local debugMenu = tab:Create("Отладка", Enum.GroupSide.Right)

local ui = {
    enable = controlMenu:Switch("Включить скрипт", false,
        "panorama/images/heroes/icons/npc_dota_hero_arc_warden_png.vtex_c"),
    toggle = controlMenu:Bind("Клавиша запуска", Enum.ButtonCode.BUTTON_CODE_NONE, "\u{f11c}"),
    side = controlMenu:Combo("Сторона", {"Силы Света", "Силы Тьмы"}, 0),

    cloneCast = timingMenu:Slider("Каст клона", 0.0, 59.9,
        DEFAULT_CLONE_CAST_TIME, "%.1f"),
    heroCast = timingMenu:Slider("Каст героя", 0.0, 59.9,
        DEFAULT_HERO_CAST_TIME, "%.1f"),

    debug = debugMenu:Switch("Отладочная панель", true, "\u{f108}"),
}

ui.enable:ToolTip("Главный выключатель скрипта.")
ui.toggle:ToolTip("Нажатие запускает полную последовательность. Повторное нажатие — стоп.")
ui.side:ToolTip("Силы Света — стак на Radiant. Силы Тьмы — на Dire.")
ui.cloneCast:ToolTip("На какой секунде минуты клон кастует Spark Wraith (например, 52.7).")
ui.heroCast:ToolTip("На какой секунде минуты герой кастует Spark Wraith (например, 53.9).")
ui.debug:ToolTip("Показывает отладочную панель.")

local PHASE_IDLE     = 0
local PHASE_MOVE     = 1
local PHASE_CAST     = 2
local PHASE_ATTACK   = 3
local PHASE_RETREAT  = 4
local PHASE_DONE     = 5

local PHASE_NAMES = {
    [0] = "IDLE",
    [1] = "MOVE",
    [2] = "CAST",
    [3] = "ATTACK",
    [4] = "RETREAT",
    [5] = "DONE",
}

local state = {
    running = false,
    phase = PHASE_IDLE,
    clone = nil,
    cloneIndex = nil,

    cloneCastDone = false,
    heroCastDone = false,

    heroTarget = nil,
    cloneTarget = nil,
    heroTargetHp = nil,
    cloneTargetHp = nil,

    heroHit = false,
    cloneHit = false,
    heroAttackIssued = false,
    cloneAttackIssued = false,
    heroAttackTime = 0,
    cloneAttackTime = 0,
    heroStopIssued = false,
    cloneStopIssued = false,
    heroHitTime = 0,
    cloneHitTime = 0,

    cloneHitDelay = 0.75,
    attackSpeed = 0,
    attackInterval = 1.7,

    scriptOrder = false,
    nextThink = 0,
    _dbgLast = 0,
    _dbgNameWarned = false,
    font = Render.LoadFont("Bahnschrift", Enum.FontCreate.FONTFLAG_ANTIALIAS, 600),
    titleFont = Render.LoadFont("Bahnschrift", Enum.FontCreate.FONTFLAG_ANTIALIAS, 700),
}

local function getSide()
    return ui.side:Get() == 1 and DIRE or RADIANT
end

local function localArcWarden()
    local hero = Heroes.GetLocal()
    if not hero then return nil end
    local name = NPC.GetUnitName(hero)
    if name ~= HERO then
        if not state._dbgNameWarned then
            state._dbgNameWarned = true
            print("[Stack4] local hero name = " .. tostring(name))
        end
        return nil
    end
    return hero
end

local function gameClock()
    local t = GameRules.GetDOTATime and GameRules.GetDOTATime(false, true) or GameRules.GetGameTime()
    return math.max(0, t or 0)
end

local function order(player, unit, kind, target, pos, ability)
    state.scriptOrder = true
    local ok, result = pcall(Player.PrepareUnitOrders, player, kind, target, pos, ability,
        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, unit,
        false, false, false, true, "arc_warden_stack", false)
    state.scriptOrder = false
    return ok and result ~= false
end

local function findClone(player, hero)
    local playerId = Player.GetPlayerID(player)
    if not playerId then return nil end
    local units = NPCs.GetAll() or {}

    for i = 1, #units do
        local unit = units[i]
        if unit and unit ~= hero and Entity.IsAlive(unit)
            and not Entity.IsDormant(unit) then
            local ok, hasMod = pcall(NPC.HasModifier, unit, "modifier_arc_warden_tempest_double")
            if ok and hasMod then
                if Entity.IsControllableByPlayer(unit, playerId) then
                    return unit
                end
            end
        end
    end

    for i = 1, #units do
        local unit = units[i]
        if unit and unit ~= hero and Entity.IsAlive(unit)
            and not Entity.IsDormant(unit)
            and not NPC.IsHero(unit) then
            local name = NPC.GetUnitName(unit) or ""
            if name == HERO then
                if Entity.IsControllableByPlayer(unit, playerId) then
                    return unit
                end
            end
        end
    end
    return nil
end

local function sparkWraithAbility(unit)
    local ability = NPC.GetAbility(unit, "arc_warden_spark_wraith")
    if ability and Ability.GetLevel(ability) > 0 then return ability end
    for slot = 0, 15 do
        local ab = NPC.GetAbilityByIndex(unit, slot)
        local name = ab and Ability.GetName(ab) or ""
        if name:lower():find("spark", 1, true) then
            if Ability.GetLevel(ab) > 0 then return ab end
        end
    end
    return nil
end

local function castSparkWraith(player, unit, pos)
    local ability = sparkWraithAbility(unit)
    if not ability then
        print("[Stack4] spark ability not found")
        return false
    end
    if Ability.CanBeExecuted(ability) ~= -1 then
        print("[Stack4] spark cannot be executed")
        return false
    end
    local mana = NPC.GetMana(unit) or 0
    local cost = Ability.GetManaCost(ability) or 0
    if mana < cost then
        print("[Stack4] not enough mana: " .. mana .. "/" .. cost)
        return false
    end
    local ok = order(player, unit, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION, nil, pos, ability)
    print("[Stack4] castSparkWraith order result: " .. tostring(ok))
    return ok
end

local function findNeutralNear(point, radius)
    local best, bestDist = nil, radius * radius
    local units = NPCs.GetAll() or {}
    for i = 1, #units do
        local unit = units[i]
        if unit and Entity.IsAlive(unit) and not Entity.IsDormant(unit)
            and NPC.IsNeutral(unit) and not NPC.IsRoshan(unit)
            and not NPC.IsWaitingToSpawn(unit) then
            local pos = Entity.GetAbsOrigin(unit)
            if pos then
                local d = pos:DistanceSqr2D(point)
                if d < bestDist then
                    best, bestDist = unit, d
                end
            end
        end
    end
    return best
end

local function isAtPoint(unit, point)
    local unitPos = Entity.GetAbsOrigin(unit)
    if not unitPos then return false end
    return unitPos:Distance2D(point) <= STOP_DISTANCE
end

local function resetState()
    state.phase = PHASE_MOVE
    state.cloneCastDone = false
    state.heroCastDone = false
    state.heroTarget = nil
    state.cloneTarget = nil
    state.heroTargetHp = nil
    state.cloneTargetHp = nil
    state.heroHit = false
    state.cloneHit = false
    state.heroAttackIssued = false
    state.cloneAttackIssued = false
    state.heroAttackTime = 0
    state.cloneAttackTime = 0
    state.heroStopIssued = false
    state.cloneStopIssued = false
    state.heroHitTime = 0
    state.cloneHitTime = 0
end

local function startStack()
    resetState()
    state.running = true
    local hero = localArcWarden()
    if hero then
        local delay, as, interval = calculateCloneHitDelay(hero)
        state.cloneHitDelay = delay
        state.attackSpeed = as
        state.attackInterval = interval
        print("[Stack4] startStack: cloneHitDelay=" .. string.format("%.2f", delay) ..
              " AS=" .. string.format("%.0f", as) ..
              " interval=" .. string.format("%.2f", interval))
    end
end

local function stopStack()
    state.running = false
    state.phase = PHASE_IDLE
    print("[Stack4] stopStack")
end

local function setPhase(newPhase)
    if state.phase ~= newPhase then
        print("[Stack4] phase " .. tostring(state.phase) .. " -> " .. tostring(newPhase))
        state.phase = newPhase
    end
end

local function updateStack(player, hero, now)
    if not state.running then return end
    if not ui.enable:Get() then
        stopStack()
        return
    end
    if now < state.nextThink then return end
    state.nextThink = now + 0.05

    local clone = findClone(player, hero)
    state.clone = clone
    state.cloneIndex = clone and Entity.GetIndex(clone) or nil

    local side = getSide()
    local clock = gameClock()
    local second = clock % 60

    local cloneCastTime = ui.cloneCast:Get()
    local heroCastTime = ui.heroCast:Get()

    if state.phase == PHASE_MOVE then
        local heroReady = isAtPoint(hero, side.HERO_MOVE)
        local cloneReady = clone and isAtPoint(clone, side.CLONE_MOVE)

        if not heroReady then
            order(player, hero, Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION,
                nil, side.HERO_MOVE, nil)
        end
        if clone and not cloneReady then
            order(player, clone, Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION,
                nil, side.CLONE_MOVE, nil)
        end

        if heroReady and (not clone or cloneReady) then
            setPhase(PHASE_CAST)
        end
        return
    end

    if state.phase == PHASE_CAST then
        if clone and not state.cloneCastDone then
            if second >= cloneCastTime and second < cloneCastTime + 5 then
                if castSparkWraith(player, clone, side.CLONE_CAST) then
                    state.cloneCastDone = true
                    print("[Stack4] clone cast DONE")
                end
            end
        end

        if not state.heroCastDone then
            if second >= heroCastTime and second < heroCastTime + 5 then
                if castSparkWraith(player, hero, side.HERO_CAST) then
                    state.heroCastDone = true
                    print("[Stack4] hero cast DONE")
                end
            end
        end

        local allDone = state.heroCastDone and (not clone or state.cloneCastDone)
        if allDone then
            local delay, as, interval = calculateCloneHitDelay(hero)
            state.cloneHitDelay = delay
            state.attackSpeed = as
            state.attackInterval = interval
            print("[Stack4] before ATTACK: cloneHitDelay=" .. string.format("%.2f", delay) ..
                  " AS=" .. string.format("%.0f", as))
            setPhase(PHASE_ATTACK)
        end
        return
    end

    if state.phase == PHASE_ATTACK then
        if not state.heroTarget then
            state.heroTarget = findNeutralNear(side.HERO_ATTACK, ATTACK_SEARCH_RADIUS)
            if state.heroTarget then
                state.heroTargetHp = Entity.GetHealth(state.heroTarget)
                print("[Stack4] hero target HP=" .. tostring(state.heroTargetHp))
            else
                print("[Stack4] hero target NOT found")
            end
        end
        if clone and not state.cloneTarget then
            state.cloneTarget = findNeutralNear(side.CLONE_ATTACK, ATTACK_SEARCH_RADIUS)
            if state.cloneTarget then
                state.cloneTargetHp = Entity.GetHealth(state.cloneTarget)
                print("[Stack4] clone target HP=" .. tostring(state.cloneTargetHp))
            else
                print("[Stack4] clone target NOT found")
            end
        end

        if state.heroTarget and Entity.IsAlive(state.heroTarget) then
            if not state.heroAttackIssued then
                if order(player, hero, Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET,
                    state.heroTarget, nil, nil) then
                    state.heroAttackIssued = true
                    state.heroAttackTime = now
                    print("[Stack4] hero ATTACK_TARGET issued")
                end
            else
                local currentHp = Entity.GetHealth(state.heroTarget)
                local elapsed = now - state.heroAttackTime
                local hpDropped = state.heroTargetHp and currentHp and currentHp < state.heroTargetHp

                if (hpDropped or elapsed > ATTACK_TIMEOUT) and not state.heroStopIssued then
                    order(player, hero, Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION,
                        nil, side.HERO_RETREAT, nil)
                    state.heroStopIssued = true
                    state.heroHit = true
                    state.heroHitTime = now
                    print("[Stack4] hero MOVE retreat (hpDropped=" .. tostring(hpDropped) ..
                          " elapsed=" .. string.format("%.2f", elapsed) .. ")")
                end
            end
        else
            if not state.heroHit then
                order(player, hero, Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION,
                    nil, side.HERO_RETREAT, nil)
                state.heroHit = true
                state.heroHitTime = now
                print("[Stack4] hero no target, retreat")
            end
        end

        if clone and state.cloneTarget and Entity.IsAlive(state.cloneTarget) then
            if not state.cloneAttackIssued then
                if order(player, clone, Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET,
                    state.cloneTarget, nil, nil) then
                    state.cloneAttackIssued = true
                    state.cloneAttackTime = now
                    print("[Stack4] clone ATTACK_TARGET issued")
                end
            else
                local elapsed = now - state.cloneAttackTime
                if elapsed >= state.cloneHitDelay and not state.cloneStopIssued then
                    order(player, clone, Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION,
                        nil, side.CLONE_RETREAT, nil)
                    state.cloneStopIssued = true
                    state.cloneHit = true
                    state.cloneHitTime = now
                    print("[Stack4] clone MOVE retreat (delay=" .. string.format("%.2f", state.cloneHitDelay) .. ")")
                end
            end
        elseif clone then
            if not state.cloneHit then
                order(player, clone, Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION,
                    nil, side.CLONE_RETREAT, nil)
                state.cloneHit = true
                state.cloneHitTime = now
                print("[Stack4] clone no target, retreat")
            end
        end

        local heroDone = state.heroHit and (now - state.heroHitTime >= POST_HIT_DELAY)
        local cloneDone = (not clone) or (state.cloneHit and (now - state.cloneHitTime >= POST_HIT_DELAY))

        if heroDone and cloneDone then
            setPhase(PHASE_RETREAT)
        end
        return
    end

    if state.phase == PHASE_RETREAT then
        local heroRetreated = isAtPoint(hero, side.HERO_RETREAT)
        local cloneRetreated = clone and isAtPoint(clone, side.CLONE_RETREAT)

        if not heroRetreated then
            order(player, hero, Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION,
                nil, side.HERO_RETREAT, nil)
        end
        if clone and not cloneRetreated then
            order(player, clone, Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION,
                nil, side.CLONE_RETREAT, nil)
        end

        if heroRetreated and (not clone or cloneRetreated) then
            setPhase(PHASE_DONE)
        end
        return
    end

    if state.phase == PHASE_DONE then
        return
    end
end

local function drawDebug()
    if not ui.debug:Get() then return end
    if not ui.enable:Get() then return end
    local hero = localArcWarden()
    if not hero then return end

    local panelX, panelY = 36, 180
    local panelW, panelH = 320, 214

    local screen = Render.ScreenSize()
    if panelX + panelW > screen.x then panelX = screen.x - panelW - 10 end
    if panelY + panelH > screen.y then panelY = screen.y - panelH - 10 end

    Render.Shadow(Vec2(panelX, panelY), Vec2(panelX + panelW, panelY + panelH),
        Color(0, 0, 0, 200), 10, 5)
    Render.FilledRect(Vec2(panelX, panelY), Vec2(panelX + panelW, panelY + panelH),
        Color(10, 12, 14, 235), 4)
    Render.Rect(Vec2(panelX, panelY), Vec2(panelX + panelW, panelY + panelH),
        Color(67, 205, 103, 220), 4, nil, 1)

    Render.Text(state.titleFont, 12, "STACK 4 DEBUG",
        Vec2(panelX + 10, panelY + 6), Color(239, 241, 240, 255))
    Render.FilledRect(Vec2(panelX + 10, panelY + 24),
        Vec2(panelX + panelW - 10, panelY + 25), Color(70, 73, 74, 120), 0)

    local muted = Color(150, 154, 156, 235)
    local value = Color(239, 241, 240, 255)
    local ok = Color(90, 230, 120, 255)
    local bad = Color(230, 90, 90, 255)

    local lineY = panelY + 32
    local lineH = 16
    local function row(label, text, color)
        Render.Text(state.font, 10, label, Vec2(panelX + 10, lineY), muted)
        Render.Text(state.font, 10, text, Vec2(panelX + 130, lineY), color or value)
        lineY = lineY + lineH
    end

    row("Сторона", ui.side:Get() == 1 and "Тьма" or "Свет", value)
    row("Запущен", state.running and "ДА" or "НЕТ", state.running and ok or bad)
    row("Фаза", PHASE_NAMES[state.phase] or "?", value)
    row("Клон", state.clone and "НАЙДЕН" or "НЕТ", state.clone and ok or bad)
    row("Каст клона", string.format("%.1f", ui.cloneCast:Get()), value)
    row("Каст героя", string.format("%.1f", ui.heroCast:Get()), value)
    row("Удар героя", state.heroHit and "ДА" or "НЕТ", state.heroHit and ok or value)
    row("Удар клона", state.cloneHit and "ДА" or "НЕТ", state.cloneHit and ok or value)
end

ui.toggle:SetKeyCallback(function(_, _, event)
    local hero = localArcWarden()
    if not hero then
        state.running = false
        return
    end
    if event == Enum.EKeyEvent.EKeyEvent_KEY_DOWN then
        if state.running then
            stopStack()
        else
            startStack()
        end
    end
end)

function script.OnUpdate()
    local hero = localArcWarden()
    if not hero then
        state.running = false
        return
    end
    local player = Players.GetLocal()
    if not player then return end
    local now = GameRules.GetGameTime()
    updateStack(player, hero, now)
end

function script.OnDraw()
    local hero = localArcWarden()
    if not hero then return end
    drawDebug()
end

function script.OnPrepareUnitOrders(data)
    if state.scriptOrder or not data then return true end
    return true
end

function script.OnEntityHurt(data)
    return
end

function script.OnGameEnd()
    state.running = false
    state.phase = PHASE_IDLE
    state.clone = nil
    state.cloneIndex = nil
    state.heroTarget = nil
    state.cloneTarget = nil
    state.heroTargetHp = nil
    state.cloneTargetHp = nil
    state.heroHit = false
    state.cloneHit = false
    state.heroAttackIssued = false
    state.cloneAttackIssued = false
    state.heroAttackTime = 0
    state.cloneAttackTime = 0
    state.heroStopIssued = false
    state.cloneStopIssued = false
    state.heroHitTime = 0
    state.cloneHitTime = 0
    state.nextThink = 0
end

return script