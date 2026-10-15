local script = {}

local HERO = "npc_dota_hero_arc_warden"

local HERO_MOVE_POINT = Vector(-1911, 306, 0)
local CLONE_MOVE_POINT = Vector(631, -1601, 0)

local HERO_CAST_POINT = Vector(-1647, 1110, 0)
local CLONE_CAST_POINT = Vector(1171, -1118, 0)

local STOP_DISTANCE = 80

local CAST_TIME_BY_LEVEL = {
    [1] = 56.0,
    [2] = 55.0,
    [3] = 54.0,
    [4] = 53.5,
}
local DEFAULT_CAST_TIME = 56.0

local heroSettings = Menu.Find("Heroes", "Hero List", "Arc Warden")
local tab = heroSettings:Create("Контроль Рун")
local controlMenu = tab:Create("Управление", Enum.GroupSide.Left)

local ui = {
    enable = controlMenu:Switch("Включить скрипт", false,
        "panorama/images/heroes/icons/npc_dota_hero_arc_warden_png.vtex_c"),
    toggle = controlMenu:Bind("Клавиша движения", Enum.ButtonCode.BUTTON_CODE_NONE, "\u{f11c}"),
    holdMode = controlMenu:Combo("Режим бинда", {
        "Удержание", "Нажатие"
    }, 0),
}

ui.toggle:ToolTip("Клавиша движения. В режиме 'Удержание' — идти пока зажата. В режиме 'Нажатие' — переключает движение.")
ui.holdMode:ToolTip("Удержание — движение пока клавиша зажата. Нажатие — клавиша переключает движение вкл/выкл.")

local state = {
    bindHeld = false,
    bindToggled = false,
    clone = nil,
    scriptOrder = false,
    nextThink = 0,
    heroCastDone = false,
    cloneCastDone = false,
    lastCastMinute = -1,
}

local function localArcWarden()
    local hero = Heroes.GetLocal()
    if not hero or NPC.GetUnitName(hero) ~= HERO then return nil end
    return hero
end

local function order(player, unit, kind, target, pos, ability)
    state.scriptOrder = true
    local ok, result = pcall(Player.PrepareUnitOrders, player, kind, target, pos, ability,
        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, unit,
        false, false, false, true, "arc_warden_point", false)
    state.scriptOrder = false
    return ok and result ~= false
end

local function findClone(player, hero)
    local playerId = Player.GetPlayerID(player)
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

local function magneticFieldAbility(unit)
    local ability = NPC.GetAbility(unit, "arc_warden_magnetic_field")
    if ability and Ability.GetLevel(ability) > 0 then return ability end
    for slot = 0, 15 do
        local ab = NPC.GetAbilityByIndex(unit, slot)
        local name = ab and Ability.GetName(ab) or ""
        if name:lower():find("magnetic", 1, true) then
            if Ability.GetLevel(ab) > 0 then return ab end
        end
    end
    return nil
end

local function getMagneticFieldLevel(unit)
    local ability = magneticFieldAbility(unit)
    if not ability then return 0 end
    return Ability.GetLevel(ability) or 0
end

local function getCastTime(level)
    return CAST_TIME_BY_LEVEL[level] or DEFAULT_CAST_TIME
end

local function castMagneticField(player, unit, pos)
    local ability = magneticFieldAbility(unit)
    if not ability then return false end
    if Ability.CanBeExecuted(ability) ~= -1 then return false end
    local mana = NPC.GetMana(unit) or 0
    local cost = Ability.GetManaCost(ability) or 0
    if mana < cost then return false end
    return order(player, unit, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION, nil, pos, ability)
end

local function isMovementActive()
    if not ui.enable:Get() then return false end
    local mode = ui.holdMode:Get()
    if mode == 0 then
        return state.bindHeld
    else
        return state.bindToggled
    end
end

local function isAtPoint(unit, movePoint)
    local unitPos = Entity.GetAbsOrigin(unit)
    if not unitPos then return false end
    return unitPos:Distance2D(movePoint) <= STOP_DISTANCE
end

local function updateUnit(player, unit, movePoint, castPoint, castFlagName, clock, castLevel)
    if not unit or not Entity.IsAlive(unit) then return end
    local unitPos = Entity.GetAbsOrigin(unit)
    if not unitPos then return end

    local atPoint = isAtPoint(unit, movePoint)

    if not atPoint then
        order(player, unit, Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION, nil, movePoint, nil)
        return
    end

    if state[castFlagName] then return end

    local second = clock % 60
    local castTime = getCastTime(castLevel)

    if second >= castTime and second < castTime + 3 then
        if castMagneticField(player, unit, castPoint) then
            state[castFlagName] = true
        end
    end
end

local function updateMovement(player, hero, now)
    if now < state.nextThink then return end
    state.nextThink = now + 0.10

    local clone = findClone(player, hero)
    state.clone = clone

    if not isMovementActive() then return end

    local clock = GameRules.GetDOTATime and GameRules.GetDOTATime(false, true) or GameRules.GetGameTime()
    clock = math.max(0, clock or 0)
    local minute = math.floor(clock / 60)

    if minute ~= state.lastCastMinute then
        state.lastCastMinute = minute
        state.heroCastDone = false
        state.cloneCastDone = false
    end

    local castLevel = getMagneticFieldLevel(hero)

    updateUnit(player, hero, HERO_MOVE_POINT, HERO_CAST_POINT, "heroCastDone", clock, castLevel)
    if clone then
        updateUnit(player, clone, CLONE_MOVE_POINT, CLONE_CAST_POINT, "cloneCastDone", clock, castLevel)
    end
end

ui.toggle:SetKeyCallback(function(_, _, event)
    local hero = localArcWarden()
    if not hero then
        state.bindHeld = false
        return
    end

    local mode = ui.holdMode:Get()
    if mode == 0 then
        if event == Enum.EKeyEvent.EKeyEvent_KEY_DOWN then
            state.bindHeld = true
            state.heroCastDone = false
            state.cloneCastDone = false
            state.lastCastMinute = -1
        elseif event == Enum.EKeyEvent.EKeyEvent_KEY_UP then
            state.bindHeld = false
        end
    else
        if event == Enum.EKeyEvent.EKeyEvent_KEY_DOWN then
            state.bindToggled = not state.bindToggled
            if state.bindToggled then
                state.heroCastDone = false
                state.cloneCastDone = false
                state.lastCastMinute = -1
            end
        end
    end
end)

function script.OnUpdate()
    local hero = localArcWarden()
    if not hero then
        state.bindHeld = false
        state.bindToggled = false
        return
    end
    local player = Players.GetLocal()
    if not player then return end
    local now = GameRules.GetGameTime()
    updateMovement(player, hero, now)
end

function script.OnPrepareUnitOrders(data)
    if state.scriptOrder or not data then return true end
    return true
end

function script.OnGameEnd()
    state.bindHeld = false
    state.bindToggled = false
    state.clone = nil
    state.nextThink = 0
    state.heroCastDone = false
    state.cloneCastDone = false
    state.lastCastMinute = -1
end

return script