local TARGET_SEARCH_RADIUS = 1800
local WORLD_SCAN_INTERVAL = 0.08
local THINK_INTERVAL = 0.025
local URGENT_MOVE_ORDER_INTERVAL = 0.05
local COMBAT_MOVE_ORDER_INTERVAL = 0.08
local BACKGROUND_MOVE_ORDER_INTERVAL = 0.16
local ATTACK_ORDER_INTERVAL = 0.035
local ORDER_TRANSITION_LOCK = 0.03
local AI_ORDER_MIN_SPACING = 0.04
local MANUAL_MOVE_TIMEOUT = 6
local PUSH_MEMORY_SECONDS = 2.5
local PUSH_MAX_HERO_DISTANCE = 1700
local PUSH_LANE_TOWER_RADIUS = 1550
local DENY_THREAT_RADIUS = 950
local DENY_COMMIT_SECONDS = 1.25
local TOWER_RETREAT_BUFFER = 240
local TOWER_RETREAT_MEMORY = 1.6
local RESUME_TARGET_SECONDS = 4.0

local group = Menu.Create("Scripts", "Heroes", "Beastmaster", "Razorbacks", "Settings")

local ui = {}
ui.language          = group:Combo("Language / Язык", { "English", "Русский" }, 0)
ui.enable            = group:Switch("Razorbacks Smart Control", true)
ui.autoDisable       = group:Switch("Timed Auto-Disable", true)
ui.autoDisableMinute = group:Slider("Disable After Minute", 1, 60, 15)
ui.passiveUntilMinute = group:Slider("Passive Until Minute", 0, 40, 0, "%d min")
ui.avoidDeath        = group:Switch("Avoid Deaths", true)
ui.retreatHealth     = group:Slider("Maneuver Below Health", 10, 80, 35, "%d%%")
ui.dangerRadius      = group:Slider("Danger Assessment Radius", 400, 1200, 750)
ui.orbwalk           = group:Switch("Orbwalk", true)
ui.combatDistance    = group:Slider("Distance from Target", 50, 90, 70, "%d%%")
ui.engageRadius      = group:Slider("Engage Radius", 600, 2500, 1400, "%d")
ui.kiteBetweenHits   = group:Switch("Kite Between Attacks", true)
ui.helpPush          = group:Switch("Assist Structure Push", true)
ui.spreadFormation   = group:Switch("Spread Against AOE", true)
ui.separationDist    = group:Slider("Minimum Distance Between Razorbacks", 150, 500, 300)
ui.lastHitCreeps     = group:Switch("Last-Hit Creeps", true)
ui.denyCreeps        = group:Switch("Deny Creeps", true)
ui.denyBoars         = group:Switch("Deny Low-HP Boars", true)
ui.denyBoarsHealth   = group:Slider("Boar Deny Below HP", 15, 50, 48, "%d%%")
ui.farmLeash         = group:Slider("Farm Leash Radius", 500, 2200, 1000, "%d")
ui.spreadSlow        = group:Switch("Spread Slow Between Heroes", true)
ui.criticalRetreat   = group:Switch("Critical HP Retreat", true)
ui.targetMode        = group:Combo("Manual Orbwalk Target", { "Hero near cursor", "Unit near cursor", "Nearest enemy" }, 0)
ui.orbwalkKey        = group:Bind("Manual Target Key", Enum.ButtonCode.KEY_NONE)
ui.manualDelay       = group:Slider("Override After Order", 0.5, 5.0, 1.5, "%.1f sec")
ui.playerPriority    = group:Slider("Player Priority After Order", 0.05, 0.5, 0.15, "%.2f sec")
ui.humanizeOrders    = group:Switch("Humanize Orders", true)
ui.maxHumanizerDelay = group:Slider("Max. Humanizer Delay", 0.15, 0.5, 0.32, "%.2f sec")
ui.showStatus        = group:Switch("Show Status", true)
ui.statusPanel       = group:Switch("Status Panel", true)
ui.panelPosX         = group:Slider("Panel Position X", 0, 95, 2, "%d%%")
ui.panelPosY         = group:Slider("Panel Position Y", 0, 95, 20, "%d%%")

local TRANSLATIONS = {
    {
        widget = ui.enable,
        en = { name = "Razorbacks Smart Control", tip = "Enables or disables automatic control." },
        ru = { name = "Умное управление кабанами", tip = "Включает или отключает автоматическое управление." },
    },
    {
        widget = ui.autoDisable,
        en = { name = "Timed Auto-Disable", tip = "Disables the script after a selected minute." },
        ru = { name = "Автоотключение по времени", tip = "Отключает скрипт после выбранной минуты." },
    },
    {
        widget = ui.autoDisableMinute,
        en = { name = "Disable After Minute", tip = "Minute of the match at which auto-disable triggers." },
        ru = { name = "Отключить после минуты", tip = "Минута матча, на которой сработает автоотключение." },
    },
    {
        widget = ui.passiveUntilMinute,
        en = { name = "Passive Until Minute", tip = "Until this minute Boars only farm and follow you without fighting heroes. 0 disables the limit." },
        ru = { name = "Пассивно до минуты", tip = "До этой минуты кабаны только фармят и следуют за героем, не вступая в бой с героями. 0 — отключено." },
    },
    {
        widget = ui.farmLeash,
        en = { name = "Farm Leash Radius", tip = "Boars pick farm/deny targets only within this radius around your hero; beyond it they follow you instead." },
        ru = { name = "Радиус фарма от героя", tip = "Кабаны берут цели для фарма и деная только в этом радиусе от героя, дальше — просто следуют за ним." },
    },
    {
        widget = ui.avoidDeath,
        en = { name = "Avoid Deaths", tip = "Makes Boars retreat from towers, heroes, attacks, and dangerous projectiles." },
        ru = { name = "Избегать смерти", tip = "Заставляет кабанов отходить от вышек, героев, атак и опасных снарядов." },
    },
    {
        widget = ui.retreatHealth,
        en = { name = "Maneuver Below Health", tip = "Health percentage at which defensive movement becomes more cautious." },
        ru = { name = "Маневрировать при здоровье", tip = "Процент здоровья, при котором защитное движение становится более осторожным." },
    },
    {
        widget = ui.dangerRadius,
        en = { name = "Danger Assessment Radius", tip = "Area checked for nearby threats." },
        ru = { name = "Радиус оценки опасности", tip = "Область, проверяемая на наличие угроз рядом." },
    },
    {
        widget = ui.orbwalk,
        en = { name = "Orbwalk", tip = "Automatically attacks and moves between attacks." },
        ru = { name = "Орбволк", tip = "Автоматически атакует и двигается между атаками." },
    },
    {
        widget = ui.combatDistance,
        en = { name = "Distance from Target", tip = "Preferred attack distance as a percentage of attack range." },
        ru = { name = "Дистанция от цели", tip = "Предпочитаемая дистанция атаки в процентах от дальности атаки." },
    },
    {
        widget = ui.engageRadius,
        en = { name = "Engage Radius", tip = "Boars only fight enemy heroes inside this radius." },
        ru = { name = "Радиус вступления в бой", tip = "Кабаны атакуют вражеских героев только внутри этого радиуса." },
    },
    {
        widget = ui.kiteBetweenHits,
        en = { name = "Kite Between Attacks", tip = "Boars drift to the edge of attack range between swings against heroes." },
        ru = { name = "Кайтинг между ударами", tip = "Между замахами по героям кабаны отходят к краю дальности атаки." },
    },
    {
        widget = ui.helpPush,
        en = { name = "Assist Structure Push", tip = "Boars attack the building your hero is hitting." },
        ru = { name = "Помощь в пуше зданий", tip = "Кабаны атакуют здание, которое бьёт ваш герой." },
    },
    {
        widget = ui.spreadFormation,
        en = { name = "Spread Against AOE", tip = "Keeps Boars separated to reduce area damage." },
        ru = { name = "Рассредоточение против AOE", tip = "Держит кабанов на расстоянии друг от друга, чтобы снизить урон по области." },
    },
    {
        widget = ui.separationDist,
        en = { name = "Minimum Distance Between Razorbacks", tip = "Minimum spacing between Boars." },
        ru = { name = "Минимальная дистанция между кабанами", tip = "Минимальное расстояние между кабанами." },
    },
    {
        widget = ui.lastHitCreeps,
        en = { name = "Last-Hit Creeps", tip = "Attacks creeps when no enemy hero is nearby." },
        ru = { name = "Добивание крипов", tip = "Атакует крипов, если рядом нет вражеского героя." },
    },
    {
        widget = ui.denyCreeps,
        en = { name = "Deny Creeps", tip = "Denies friendly creeps below 50% health when there is no better target." },
        ru = { name = "Денай крипов", tip = "Добивает союзных крипов ниже 50% здоровья, если нет цели лучше." },
    },
    {
        widget = ui.denyBoars,
        en = { name = "Deny Low-HP Boars", tip = "The closest healthy Boar denies a dying Boar so enemies get no gold or experience." },
        ru = { name = "Денай своих кабанов", tip = "Ближайший здоровый кабан добивает умирающего кабана, лишая врага золота и опыта." },
    },
    {
        widget = ui.denyBoarsHealth,
        en = { name = "Boar Deny Below HP", tip = "Health percent below which an ally Boar becomes a deny target (summons are deniable below 50%)." },
        ru = { name = "Порог деная кабана", tip = "Процент здоровья, ниже которого кабан становится целью для деная (саммоны денаятся ниже 50%)." },
    },
    {
        widget = ui.spreadSlow,
        en = { name = "Spread Slow Between Heroes", tip = "Boars attack different heroes to slow several enemies, unless a kill is secured." },
        ru = { name = "Размазывать замедление", tip = "Кабаны атакуют разных героев, чтобы замедлить нескольких врагов, если нет гарантированного убийства." },
    },
    {
        widget = ui.criticalRetreat,
        en = { name = "Critical HP Retreat", tip = "At critically low health the Boar returns to Beastmaster." },
        ru = { name = "Отход при крит. HP", tip = "При критически низком здоровье кабан возвращается к Beastmaster." },
    },
    {
        widget = ui.targetMode,
        en = { name = "Manual Orbwalk Target", tip = "Chooses a target near the cursor or the nearest enemy.", items = { "Hero near cursor", "Unit near cursor", "Nearest enemy" } },
        ru = { name = "Ручная цель орбволка", tip = "Выбирает цель у курсора или ближайшего врага.", items = { "Герой у курсора", "Юнит у курсора", "Ближайший враг" } },
    },
    {
        widget = ui.orbwalkKey,
        en = { name = "Manual Target Key", tip = "Key used to activate manual targeting." },
        ru = { name = "Клавиша ручной цели", tip = "Клавиша для активации ручного выбора цели." },
    },
    {
        widget = ui.manualDelay,
        en = { name = "Override After Order", tip = "Time before automatic control resumes after a manual command." },
        ru = { name = "Перехват после приказа", tip = "Время до возвращения автоматического управления после ручной команды." },
    },
    {
        widget = ui.playerPriority,
        en = { name = "Player Priority After Order", tip = "Prevents AI commands from interfering with recent player orders." },
        ru = { name = "Приоритет игрока после приказа", tip = "Не даёт командам ИИ мешать недавним приказам игрока." },
    },
    {
        widget = ui.humanizeOrders,
        en = { name = "Humanize Orders", tip = "Adds natural delays to background movement commands." },
        ru = { name = "Humanizer приказов", tip = "Добавляет естественные задержки к фоновым командам движения." },
    },
    {
        widget = ui.maxHumanizerDelay,
        en = { name = "Max. Humanizer Delay", tip = "Maximum delay for humanized orders." },
        ru = { name = "Макс. задержка Humanizer", tip = "Максимальная задержка для очеловеченных приказов." },
    },
    {
        widget = ui.showStatus,
        en = { name = "Show Status", tip = "Displays the current control mode above each Boar." },
        ru = { name = "Показывать статус", tip = "Отображает текущий режим управления над каждым кабаном." },
    },
    {
        widget = ui.statusPanel,
        en = { name = "Status Panel", tip = "Compact on-screen list with the mode and health of every Boar." },
        ru = { name = "Панель статуса", tip = "Компактный список на экране с режимом и здоровьем каждого кабана." },
    },
    {
        widget = ui.panelPosX,
        en = { name = "Panel Position X", tip = "Horizontal position as % of the screen." },
        ru = { name = "Позиция панели X", tip = "Горизонтальная позиция в % экрана." },
    },
    {
        widget = ui.panelPosY,
        en = { name = "Panel Position Y", tip = "Vertical position as % of the screen." },
        ru = { name = "Позиция панели Y", tip = "Вертикальная позиция в % экрана." },
    },
}


local function ApplyLanguage(this)
    local lang = this:Get() == 1 and "ru" or "en"
    for i = 1, #TRANSLATIONS do
        local entry = TRANSLATIONS[i]
        local text = entry[lang]
        if entry.en.items then
            local currentValue = entry.widget:Get()
            entry.widget:Update(text.items, currentValue)
        end
        entry.widget:ForceLocalization(text.name)
        entry.widget:ToolTip(text.tip)
    end
end

ui.language:SetCallback(ApplyLanguage, true)

local states = {}
local razorbacks = {}
local nearbyEnemiesByRazorback = {}
local enemyTowers = {}
local projectilesByTarget = {}
local nextScanAt = 0
local nextThinkAt = 0
local rosterKey = ""
local thinkCursor = 0
local aiOrderNotBefore = 0
local userOrderPriorityUntil = 0
local autoDisableTriggered = false
local disabledByTimer = false
local statusFont = nil
local metrics = {
    evades = 0,
    lastHits = 0,
    startedAt = nil,
}
local squadFocusTarget = nil
-- Structure the owner hero is currently attacking (siege assist) and a cached
-- reference to the owner hero for damage predictions.
local heroSiegeTarget = nil
local heroSiegeUntil = 0
local ownerHero = nil
local squadFocusKillSecure = false
local friendlyLaneCreeps = {}


ui.enable:SetCallback(function(this)
    if this:Get() then
        disabledByTimer = false
    end
end)

local function IsEntityValid(entity)
    return entity ~= nil and Entity.IsEntity(entity)
end

local function IsEntityAlive(entity)
    return IsEntityValid(entity) and Entity.IsAlive(entity)
end

local function SafeIndex(entity)
    if not IsEntityValid(entity) then
        return nil
    end
    return Entity.GetIndex(entity)
end

local function SameEntity(a, b)
    local ia, ib = SafeIndex(a), SafeIndex(b)
    return ia ~= nil and ia == ib
end

local function PruneEntities(list)
    local result = {}
    for i = 1, #list do
        if IsEntityValid(list[i]) then
            result[#result + 1] = list[i]
        end
    end
    return result
end

local function GetOrigin(entity)
    if not IsEntityValid(entity) then
        return nil
    end
    return Entity.GetAbsOrigin(entity)
end

local function Dist2D(a, b)
    local originA, originB = GetOrigin(a), GetOrigin(b)
    if not originA or not originB then
        return math.huge
    end
    return originA:Distance2D(originB)
end

local function Normalize2D(x, y)
    local len = math.sqrt(x * x + y * y)
    if len < 0.001 then
        return 0, 0
    end
    return x / len, y / len
end

local function Rotate2D(x, y, deg)
    local rad = math.rad(deg)
    local c, s = math.cos(rad), math.sin(rad)
    return x * c - y * s, x * s + y * c
end

local function GroundVector(x, y)
    local v = Vector(x, y, 0)
    v:SetGroundZ()
    return v
end

local function IsGameActive()
    local state = GameRules.GetGameState()
    return state == Enum.GameState.DOTA_GAMERULES_STATE_PRE_GAME
        or state == Enum.GameState.DOTA_GAMERULES_STATE_GAME_IN_PROGRESS
end

local function GetAttackRangeWithBonus(unit)
    return (NPC.GetAttackRange(unit) or 0) + (NPC.GetAttackRangeBonus(unit) or 0)
end

local function IsControlledRazorback(unit, hero, playerId)
    if not unit or not IsEntityAlive(unit) then
        return false
    end
    local name = string.lower(NPC.GetUnitName(unit) or "")
    if not string.find(name, "beastmaster", 1, true) then
        return false
    end
    if not string.find(name, "boar", 1, true) and not string.find(name, "razorback", 1, true) then
        return false
    end
    return Entity.RecursiveOwnedBy(unit, hero) and Entity.IsControllableByPlayer(unit, playerId)
end

local function GetState(unit)
    local index = SafeIndex(unit)
    if not index then
        return nil
    end
    local state = states[index]
    if not state then
        state = {
            nextOrderAt = 0,
            attackPending = false,
            attackIssuedAt = 0,
            attackReadyAt = 0,
            fallbackReleaseAt = 0,
            target = nil,
            lastHealth = Entity.GetHealth(unit),
            focusedUntil = 0,
            strafeSide = index % 2 == 0 and -1 or 1,
            manualUntil = 0,
            manualIssuedAt = 0,
            manualOrder = nil,
            manualPosition = nil,
            manualTarget = nil,
            lastAiOrderAt = -10,
            lastMovePosition = nil,
            orderLockUntil = 0,
            mode = "idle",
            targetIsCreep = false,
            committedTarget = nil,
            commitUntil = 0,
            resumeTarget = nil,
            resumeUntil = 0,
            towerRetreatTower = nil,
            towerRetreatUntil = 0,
        }
        states[index] = state
    end
    return state
end

local function RemoveExpiredStates(activeUnits)
    local active = {}
    for i = 1, #activeUnits do
        local index = SafeIndex(activeUnits[i])
        if index then
            active[index] = true
        end
    end
    for index in pairs(states) do
        if not active[index] then
            states[index] = nil
        end
    end
end

local function IsValidTarget(target, source)
    if not IsEntityAlive(target) or Entity.IsDormant(target) then
        return false
    end
    if source and not IsEntityValid(source) then
        return false
    end
    if source and Entity.IsSameTeam(target, source) then
        return false
    end
    if NPC.HasState(target, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE)
        or NPC.HasState(target, Enum.ModifierState.MODIFIER_STATE_ATTACK_IMMUNE) then
        return false
    end
    return true
end

local function IsDeniableCreep(target, source)
    return IsEntityAlive(target)
        and not Entity.IsDormant(target)
        and source ~= nil
        and Entity.IsSameTeam(target, source)
        and NPC.IsLaneCreep(target)
        and Entity.GetHealth(target) / math.max(1, Entity.GetMaxHealth(target)) <= 0.5
end

local function IsAllyRazorback(target)
    for i = 1, #razorbacks do
        if SameEntity(razorbacks[i], target) then
            return true
        end
    end
    return false
end

local function IsDeniableBoar(target, source)
    return ui.denyBoars:Get()
        and IsEntityAlive(target)
        and source ~= nil
        and not SameEntity(target, source)
        and Entity.IsSameTeam(target, source)
        and IsAllyRazorback(target)
        and Entity.GetHealth(target) / math.max(1, Entity.GetMaxHealth(target)) <= 0.5
end

local function IsOrbwalkTarget(target, source)
    return IsValidTarget(target, source)
        or IsDeniableCreep(target, source)
        or IsDeniableBoar(target, source)
end

local function HasOptionalState(unit, state)
    return state ~= nil and NPC.HasState(unit, state)
end

local function CanReceiveOrders(unit)
    return IsEntityAlive(unit)
        and not Entity.IsDormant(unit)
        and not HasOptionalState(unit, Enum.ModifierState.MODIFIER_STATE_STUNNED)
        and not HasOptionalState(unit, Enum.ModifierState.MODIFIER_STATE_COMMAND_RESTRICTED)
        and not HasOptionalState(unit, Enum.ModifierState.MODIFIER_STATE_IGNORING_MOVE_AND_ATTACK_ORDERS)
end

local function IsMovementOrder(order)
    return order == Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION
        or order == Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_TARGET
        or order == Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_MOVE
        or order == Enum.UnitOrder.DOTA_UNIT_ORDER_PATROL
end

local function GetManualDestination(state)
    if state.manualPosition then
        return state.manualPosition
    end
    if IsEntityAlive(state.manualTarget) then
        return GetOrigin(state.manualTarget)
    end
    return nil
end

local function IsManualControlActive(unit, state, now)
    if now < state.manualUntil then
        return true
    end
    if now - state.manualIssuedAt > MANUAL_MOVE_TIMEOUT then
        return false
    end
    local destination = GetManualDestination(state)
    return destination ~= nil
        and IsMovementOrder(state.manualOrder)
        and GetOrigin(unit):Distance2D(destination) > 90
end

local function ClearManualOrder(state)
    state.manualUntil = 0
    state.manualIssuedAt = 0
    state.manualOrder = nil
    state.manualPosition = nil
    state.manualTarget = nil
end

local EMPTY_PROJECTILE_LIST = {}

local function GetProjectilesOn(unit, now)
    local index = SafeIndex(unit)
    local list = index and projectilesByTarget[index]
    if not list or #list == 0 then
        return EMPTY_PROJECTILE_LIST
    end
    -- Prune expired entries in place to avoid per-frame table allocations.
    local write = 0
    for read = 1, #list do
        local entry = list[read]
        if entry.expireAt > now then
            write = write + 1
            list[write] = entry
        end
    end
    for i = #list, write + 1, -1 do
        list[i] = nil
    end
    return list
end

local function UpdateFocusState(unit, state, now)
    if not IsEntityValid(unit) or not state then
        return
    end
    local currentHealth = Entity.GetHealth(unit)
    if currentHealth < state.lastHealth - 0.5 then
        state.focusedUntil = math.max(state.focusedUntil, now + 1.25)
    end
    for _, projectile in ipairs(GetProjectilesOn(unit, now)) do
        if projectile.isAttack or projectile.dodgeable then
            state.focusedUntil = math.max(state.focusedUntil, now + 1.25)
        end
    end
    if state.targetIsCreep
        and state.target ~= nil
        and not IsEntityAlive(state.target)
        and now - (state.lastAiOrderAt or 0) <= 1.0 then
        metrics.lastHits = metrics.lastHits + 1
        state.targetIsCreep = false
    end
    if not IsEntityValid(state.target) then
        state.target = nil
    end
    if not IsEntityValid(state.manualTarget) then
        state.manualTarget = nil
    end
    state.lastHealth = currentHealth
end

local function GetNearbyEnemies(unit, radius)
    local index = SafeIndex(unit)
    local nearby = (index and nearbyEnemiesByRazorback[index]) or {}
    nearby = PruneEntities(nearby)
    if radius >= TARGET_SEARCH_RADIUS then
        return nearby
    end
    local filtered = {}
    for i = 1, #nearby do
        if Dist2D(unit, nearby[i]) <= radius then
            filtered[#filtered + 1] = nearby[i]
        end
    end
    return filtered
end

local function GetClosest(origin, entities)
    local closest, closestDistance = nil, math.huge
    if not origin then
        return nil
    end
    for i = 1, #entities do
        local entityOrigin = GetOrigin(entities[i])
        local distance = entityOrigin and entityOrigin:Distance2D(origin) or math.huge
        if distance < closestDistance then
            closest = entities[i]
            closestDistance = distance
        end
    end
    return closest
end

local HAS_TIME_TO_FACE = type(NPC.GetTimeToFace) == "function"
local HAS_ARMOR_VALUE = type(NPC.GetPhysicalArmorValue) == "function"
local HAS_MOVE_SPEED = type(NPC.GetMoveSpeed) == "function"
local HAS_IS_STRUCTURE = type(NPC.IsStructure) == "function"
local HAS_ATTACK_TARGET = type(NPC.GetAttackTarget) == "function"
local HAS_HEALTH_BAR_OFFSET = type(NPC.GetHealthBarOffset) == "function"

local function SafeTimeToFace(source, target)
    if NPC.IsTower(source) then
        return 0
    end
    if not HAS_TIME_TO_FACE then
        return 0
    end
    local value = NPC.GetTimeToFace(source, target)
    if type(value) ~= "number" then
        return 0
    end
    return value
end

local function IsLikelyAttackingUnit(attacker, unit)
    if NPC.IsTower(attacker) then
        local target = Tower.GetAttackTarget(attacker)
        return SameEntity(target, unit)
    end
    local reach = GetAttackRangeWithBonus(attacker)
        + NPC.GetHullRadius(attacker)
        + NPC.GetHullRadius(unit)
        + 125
    return NPC.IsAttacking(attacker)
        and Dist2D(attacker, unit) <= reach
        and SafeTimeToFace(attacker, unit) <= 0.25
end

local function HasDangerousIncomingAbility(unit, healthPercent, now)
    for _, projectile in ipairs(GetProjectilesOn(unit, now)) do
        if projectile.dodgeable
            and not projectile.isAttack
            and healthPercent <= ui.retreatHealth:Get() + 15 then
            return true
        end
    end
    return false
end

local function GetTowerSafeRadius(tower, unit)
    return GetAttackRangeWithBonus(tower)
        + NPC.GetHullRadius(tower)
        + NPC.GetHullRadius(unit)
        + TOWER_RETREAT_BUFFER
end

local function GetAggroTower(unit, threats)
    for i = 1, #threats do
        local tower = threats[i]
        if NPC.IsTower(tower) and SameEntity(Tower.GetAttackTarget(tower), unit) then
            return tower
        end
    end
    -- The danger-radius filter may omit a long-range tower for one scan.
    for i = 1, #enemyTowers do
        local tower = enemyTowers[i]
        if IsEntityAlive(tower) and SameEntity(Tower.GetAttackTarget(tower), unit) then
            return tower
        end
    end
    return nil
end

local function RememberTargetBeforeTowerRetreat(state, now)
    if state.mode ~= "evade" and IsEntityAlive(state.target) then
        state.resumeTarget = state.target
        state.resumeUntil = now + RESUME_TARGET_SECONDS
    end
end

local function ShouldEvade(unit, state, threats, now)
    if not ui.avoidDeath:Get() then
        state.towerRetreatTower = nil
        state.towerRetreatUntil = 0
        return false
    end
    local healthPercent = Entity.GetHealth(unit) / math.max(1, Entity.GetMaxHealth(unit)) * 100
    if HasOptionalState(unit, Enum.ModifierState.MODIFIER_STATE_ROOTED) then
        return false
    end

    local aggroTower = GetAggroTower(unit, threats)
    if aggroTower then
        RememberTargetBeforeTowerRetreat(state, now)
        state.towerRetreatTower = aggroTower
        state.towerRetreatUntil = now + TOWER_RETREAT_MEMORY
        return true
    end

    -- Keep walking until fully outside tower range plus buffer. Do not turn back
    -- the instant the tower changes target, which caused repeated aggro loops.
    local rememberedTower = state.towerRetreatTower
    if IsEntityAlive(rememberedTower)
        and Dist2D(unit, rememberedTower) <= GetTowerSafeRadius(rememberedTower, unit) then
        -- Extend the short memory while still inside the unsafe circle. This
        -- prevents turning around early when pathing around trees or creeps.
        state.towerRetreatUntil = math.max(state.towerRetreatUntil, now + 0.4)
        return true
    end
    state.towerRetreatTower = nil
    state.towerRetreatUntil = 0

    if #threats == 0 then
        return false
    end
    if HasDangerousIncomingAbility(unit, healthPercent, now) then
        return true
    end
    for i = 1, #threats do
        if NPC.IsHero(threats[i]) and IsLikelyAttackingUnit(threats[i], unit) then
            return true
        end
    end
    local creepOnly = true
    for i = 1, #threats do
        if NPC.IsHero(threats[i]) or NPC.IsTower(threats[i]) then
            creepOnly = false
            break
        end
    end
    if not creepOnly and state.focusedUntil > now then
        return true
    end
    if creepOnly then
        if healthPercent >= ui.retreatHealth:Get() then
            return false
        end
        local pressure = 0
        for i = 1, #threats do
            local threat = threats[i]
            local reach = GetAttackRangeWithBonus(threat)
                + NPC.GetHullRadius(threat)
                + NPC.GetHullRadius(unit)
                + 60
            if Dist2D(unit, threat) <= reach and SafeTimeToFace(threat, unit) <= 0.35 then
                pressure = pressure + 1
            end
        end
        if pressure >= 3 then
            return true
        end
        return pressure >= 1
            and state.focusedUntil > now
            and healthPercent < ui.retreatHealth:Get() * 0.6
    end
    if healthPercent > ui.retreatHealth:Get() and state.focusedUntil <= now then
        return false
    end
    local closest = GetClosest(GetOrigin(unit), threats)
    if not closest then
        return false
    end
    local minimumSpacing = math.max(225, math.min(425, GetAttackRangeWithBonus(unit) * 0.65))
    local threatReach = GetAttackRangeWithBonus(closest)
        + NPC.GetHullRadius(closest)
        + NPC.GetHullRadius(unit)
        + 100
    return Dist2D(unit, closest) <= math.max(minimumSpacing, threatReach)
        and SafeTimeToFace(closest, unit) <= 0.3
end
local function IsTowerSafeMove(unit, candidate)
    for i = 1, #enemyTowers do
        local tower = enemyTowers[i]
        if IsEntityAlive(tower) and not Entity.IsDormant(tower) then
            local dangerRange = GetAttackRangeWithBonus(tower) + 100
            local currentDistance = GetOrigin(tower):Distance2D(GetOrigin(unit))
            local candidateDistance = GetOrigin(tower):Distance2D(candidate)
            if candidateDistance <= dangerRange and candidateDistance <= currentDistance + 25 then
                return false
            end
        end
    end
    return true
end

local function FindSafeStepPoint(unit, origin, dirX, dirY, distance, threats)
    local angles = { 0, 20, -20, 40, -40, 65, -65, 90, -90, 120, -120 }
    local best, bestScore = nil, -math.huge
    for i = 1, #angles do
        local rx, ry = Rotate2D(dirX, dirY, angles[i])
        local candidate = GroundVector(origin.x + rx * distance, origin.y + ry * distance)
        if GridNav.IsTraversable(candidate) and IsTowerSafeMove(unit, candidate) then
            if not threats or #threats == 0 then
                -- No scoring context: first traversable point along the desired direction wins.
                return candidate
            end
            -- Prefer the point with the most clearance from the nearest threat,
            -- lightly penalizing rotation away from the desired escape direction.
            local clearance = math.huge
            for j = 1, #threats do
                if IsEntityAlive(threats[j]) then
                    clearance = math.min(clearance, GetOrigin(threats[j]):Distance2D(candidate))
                end
            end
            if clearance == math.huge then
                return candidate
            end
            local score = clearance - math.abs(angles[i]) * 2.2
            if score > bestScore then
                best, bestScore = candidate, score
            end
        end
    end
    return best or origin
end

local function GetSeparationDirection(unit, radius)
    local origin = GetOrigin(unit)
    local sx, sy = 0, 0
    for i = 1, #razorbacks do
        local other = razorbacks[i]
        if IsEntityAlive(other) and not SameEntity(other, unit) then
            local distance = Dist2D(unit, other)
            if distance < radius then
                local otherOrigin = GetOrigin(other)
                local ax, ay = Normalize2D(origin.x - otherOrigin.x, origin.y - otherOrigin.y)
                if ax == 0 and ay == 0 then
                    ax, ay = Rotate2D(1, 0, Entity.GetIndex(unit) * 73)
                end
                local weight = 1 - distance / radius
                sx = sx + ax * weight
                sy = sy + ay * weight
            end
        end
    end
    local strength = math.sqrt(sx * sx + sy * sy)
    if strength > 1 then
        return sx / strength, sy / strength
    end
    return sx, sy
end

local function GetHumanizedInterval()
    if not ui.humanizeOrders:Get() then
        return BACKGROUND_MOVE_ORDER_INTERVAL
    end
    return math.max(BACKGROUND_MOVE_ORDER_INTERVAL, math.random() * ui.maxHumanizerDelay:Get())
end

local function CanIssueAiOrder(now, urgent)
    -- Emergency deny/evasion bypasses the short player/background queue lock.
    if not urgent and (now < userOrderPriorityUntil or now < aiOrderNotBefore) then
        return false
    end
    if urgent then
        return true
    end
    local queue = Humanizer and type(Humanizer.GetOrderQueue) == "function"
        and Humanizer.GetOrderQueue() or nil
    return not queue or #queue == 0
end

local DISABLE_ORDER_STATES = {}
for _, stateKey in ipairs({
    "MODIFIER_STATE_STUNNED",
    "MODIFIER_STATE_HEXED",
    "MODIFIER_STATE_TAUNTED",
    "MODIFIER_STATE_FEARED",
    "MODIFIER_STATE_COMMAND_RESTRICTED",
}) do
    if Enum.ModifierState[stateKey] ~= nil then
        DISABLE_ORDER_STATES[#DISABLE_ORDER_STATES + 1] = Enum.ModifierState[stateKey]
    end
end

local function IsUnitActionable(unit)
    for i = 1, #DISABLE_ORDER_STATES do
        if NPC.HasState(unit, DISABLE_ORDER_STATES[i]) then
            return false
        end
    end
    return true
end

local function IssueMove(player, unit, state, position, now, urgent, humanized)
    if not position or not IsUnitActionable(unit) or GetOrigin(unit):Distance2D(position) <= 30 then
        return false
    end
    local orderDelay = urgent and URGENT_MOVE_ORDER_INTERVAL
        or (humanized and GetHumanizedInterval() or COMBAT_MOVE_ORDER_INTERVAL)
    if (not urgent and now < state.orderLockUntil) or now - state.lastAiOrderAt < orderDelay then
        return false
    end
    if state.lastMovePosition
        and state.lastMovePosition:Distance2D(position) < 45
        and now - state.lastAiOrderAt < (urgent and 0.12 or 0.35) then
        return false
    end
    if not CanIssueAiOrder(now, urgent) then
        return false
    end
    state.lastAiOrderAt = now
    state.lastMovePosition = position:Clone()
    state.orderLockUntil = now + (urgent and 0.01 or ORDER_TRANSITION_LOCK)
    aiOrderNotBefore = now + AI_ORDER_MIN_SPACING
    Player.PrepareUnitOrders(
        player,
        Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION,
        nil,
        position,
        nil,
        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
        unit,
        false,
        false,
        nil,
        not humanized,
        nil,
        false
    )
    return true
end

local function IssueAttack(player, unit, target, state, now, urgent)
    if not IsOrbwalkTarget(target, unit) or not IsUnitActionable(unit) then
        return false
    end
    local spacing = urgent and 0.015 or ATTACK_ORDER_INTERVAL
    if (not urgent and now < state.orderLockUntil) or now - state.lastAiOrderAt < spacing then
        return false
    end
    if not CanIssueAiOrder(now, urgent) then
        return false
    end
    state.lastAiOrderAt = now
    state.attackIssuedAt = now
    state.lastMovePosition = nil
    state.orderLockUntil = now + (urgent and 0.005 or ORDER_TRANSITION_LOCK)
    aiOrderNotBefore = now + (urgent and 0.015 or AI_ORDER_MIN_SPACING)

    -- The dedicated API is less sensitive to malformed position payloads and
    -- is especially reliable for allied deny targets.
    if type(Player.AttackTarget) == "function" then
        Player.AttackTarget(player, unit, target, false, false, true, nil, false)
    else
        Player.PrepareUnitOrders(
            player,
            Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET,
            target,
            GetOrigin(target),
            nil,
            Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
            unit,
            false,
            false,
            nil,
            true,
            nil,
            false
        )
    end
    return true
end
local function GetEvasionPosition(unit, hero, state, threats)
    local origin = GetOrigin(unit)
    local activeAttacker = nil
    for i = 1, #threats do
        if IsLikelyAttackingUnit(threats[i], unit) then
            activeAttacker = threats[i]
            break
        end
    end
    local closest = activeAttacker or GetClosest(origin, threats)
    if not closest then
        return origin
    end
    local closestOrigin = GetOrigin(closest)
    local heroOrigin = GetOrigin(hero)
    local awayX, awayY = Normalize2D(origin.x - closestOrigin.x, origin.y - closestOrigin.y)
    local towardX, towardY = Normalize2D(heroOrigin.x - origin.x, heroOrigin.y - origin.y)
    local sepX, sepY = 0, 0
    if ui.spreadFormation:Get() then
        sepX, sepY = GetSeparationDirection(unit, ui.separationDist:Get())
    end
    local dodgeX, dodgeY = 0, 0
    for _, projectile in ipairs(GetProjectilesOn(unit, GameRules.GetGameTime())) do
        if projectile.dodgeable and not projectile.isAttack then
            local projectileSource = IsEntityValid(projectile.source) and GetOrigin(projectile.source) or closestOrigin
            local lineX, lineY = Normalize2D(origin.x - projectileSource.x, origin.y - projectileSource.y)
            local perpX, perpY = -lineY, lineX
            if perpX * towardX + perpY * towardY < 0 then
                perpX, perpY = -perpX, -perpY
            end
            dodgeX, dodgeY = dodgeX + perpX, dodgeY + perpY
        end
    end
    dodgeX, dodgeY = Normalize2D(dodgeX, dodgeY)
    -- The lower the health, the harder the boar hugs the hero while escaping.
    local hpFraction = Entity.GetHealth(unit) / math.max(1, Entity.GetMaxHealth(unit))
    local towardWeight = 0.12 + (1 - hpFraction) * 0.5
    local dirX = awayX * 0.95 + towardX * towardWeight + sepX * 0.3 + dodgeX * 0.85
    local dirY = awayY * 0.95 + towardY * towardWeight + sepY * 0.3 + dodgeY * 0.85
    dirX, dirY = Normalize2D(dirX, dirY)
    if dirX == 0 and dirY == 0 then
        dirX, dirY = awayX, awayY
    end
    -- Step farther when the chaser is a hero and when the boar is badly hurt.
    local step = math.max(200, GetAttackRangeWithBonus(unit) * 0.35)
    if NPC.IsHero(closest) then
        step = step + 110
    end
    if hpFraction < 0.35 then
        step = step + 80
    end
    return FindSafeStepPoint(unit, origin, dirX, dirY, step, threats)
end

local function GetTowerRetreatPosition(unit, hero, tower)
    local origin = GetOrigin(unit)
    local towerOrigin = GetOrigin(tower)
    if not origin or not towerOrigin then
        return nil
    end
    local awayX, awayY = Normalize2D(origin.x - towerOrigin.x, origin.y - towerOrigin.y)
    if awayX == 0 and awayY == 0 then
        local heroOrigin = GetOrigin(hero)
        awayX, awayY = Normalize2D(heroOrigin.x - towerOrigin.x, heroOrigin.y - towerOrigin.y)
    end
    local safeRadius = GetTowerSafeRadius(tower, unit) + 80
    local angles = { 0, 12, -12, 25, -25, 40, -40, 60, -60 }
    local best, bestScore = nil, -math.huge
    for i = 1, #angles do
        local dx, dy = Rotate2D(awayX, awayY, angles[i])
        local candidate = GroundVector(towerOrigin.x + dx * safeRadius, towerOrigin.y + dy * safeRadius)
        if GridNav.IsTraversable(candidate) then
            local score = candidate:Distance2D(towerOrigin) - math.abs(angles[i]) * 1.5
            local heroOrigin = GetOrigin(hero)
            if heroOrigin then
                score = score - candidate:Distance2D(heroOrigin) * 0.08
            end
            if score > bestScore then
                best, bestScore = candidate, score
            end
        end
    end
    return best
end

local function Evade(player, unit, hero, state, threats, now)
    if state.mode ~= "evade" then
        metrics.evades = metrics.evades + 1
    end
    state.mode = "evade"
    if state.attackPending then
        state.attackReadyAt = now
    end
    state.attackPending = false
    if now < state.nextOrderAt then
        return
    end
    local tower = state.towerRetreatTower
    local position = IsEntityAlive(tower) and GetTowerRetreatPosition(unit, hero, tower)
        or GetEvasionPosition(unit, hero, state, threats)
    IssueMove(player, unit, state, position, now, true, false)
    state.nextOrderAt = now + (tower and 0.04 or 0.08)
end

local incomingDpsCache = {}

local function IsAttackingTarget(attacker, target)
    if not IsEntityAlive(attacker) or not IsEntityAlive(target) then
        return false
    end
    if HAS_ATTACK_TARGET then
        local attackTarget = NPC.GetAttackTarget(attacker)
        if attackTarget then
            return SameEntity(attackTarget, target)
        end
    end
    local reach = GetAttackRangeWithBonus(attacker)
        + NPC.GetHullRadius(attacker)
        + NPC.GetHullRadius(target)
        + 120
    return NPC.IsAttacking(attacker)
        and Dist2D(attacker, target) <= reach
        and SafeTimeToFace(attacker, target) <= 0.3
end

local function EstimateIncomingCreepDps(creep)
    -- TEAM_ENEMY is relative to the creep. This works for both enemy last-hits
    -- and allied denies, unlike a fixed list of our friendly lane creeps.
    local index = SafeIndex(creep)
    local now = GameRules.GetGameTime()
    local cached = index and incomingDpsCache[index]
    if cached and now - cached.at <= 0.08 then
        return cached.value
    end
    local dps = 0
    local attackers = Entity.GetUnitsInRadius(creep, DENY_THREAT_RADIUS, Enum.TeamType.TEAM_ENEMY, true, true) or {}
    for i = 1, #attackers do
        local attacker = attackers[i]
        if IsAttackingTarget(attacker, creep) then
            local damage = (NPC.GetTrueMaximumDamage(attacker) or 0) * 0.92
            dps = dps + damage / math.max(0.4, NPC.GetAttackTime(attacker) or 1)
        end
    end
    if index then
        incomingDpsCache[index] = { at = now, value = dps }
    end
    return dps
end

local function GetArmorMultiplier(target)
    local armor = HAS_ARMOR_VALUE and NPC.GetPhysicalArmorValue(target) or nil
    if type(armor) ~= "number" then
        return 0.9
    end
    return 1 - (0.06 * armor) / (1 + 0.06 * math.abs(armor))
end

local function GetSecureDamage(unit, target)
    -- Guaranteed hit: minimum damage roll reduced by the target's armor.
    local minDamage = NPC.GetTrueDamage(unit) or 0
    if minDamage <= 0 then
        minDamage = (NPC.GetTrueMaximumDamage(unit) or 0) * 0.88
    end
    return minDamage * GetArmorMultiplier(target)
end

local function GetNetworkLatency()
    if not NetChannel or type(NetChannel.GetLatency) ~= "function"
        or not Enum.Flow or Enum.Flow.FLOW_OUTGOING == nil then
        return 0
    end
    return NetChannel.GetLatency(Enum.Flow.FLOW_OUTGOING) or 0
end

local function GetImpactDelay(unit, creep)
    local delay = math.max(0.05, NPC.GetAttackAnimPoint(unit) or 0.3)
        + SafeTimeToFace(unit, creep)
        + GetNetworkLatency()
    -- Walking time when the boar is still out of attack range.
    local gap = Dist2D(unit, creep)
        - GetAttackRangeWithBonus(unit)
        - NPC.GetHullRadius(unit)
        - NPC.GetHullRadius(creep)
    if gap > 0 then
        local speed = HAS_MOVE_SPEED and NPC.GetMoveSpeed(unit) or nil
        if type(speed) ~= "number" or speed <= 0 then
            speed = 320
        end
        delay = delay + gap / math.max(150, speed)
    end
    return delay
end

local function IsLastHittable(unit, creep)
    local secureDamage = GetSecureDamage(unit, creep)
    if secureDamage <= 0 then
        return false
    end
    local predicted = Entity.GetHealth(creep) - EstimateIncomingCreepDps(creep) * GetImpactDelay(unit, creep)
    -- Commit only when the minimum guaranteed hit kills; the small negative window
    -- still secures creeps that drop lower to allied damage mid-swing.
    return predicted <= secureDamage * 1.02
end

local function IsCreepKillSecure(unit, target)
    -- Target dies to a single guaranteed hit right now.
    return Entity.GetHealth(target) <= GetSecureDamage(unit, target) * 0.98
end

local function IsDenyHittable(unit, target)
    local secure = GetSecureDamage(unit, target)
    if secure <= 0 then
        return false
    end
    local predicted = Entity.GetHealth(target)
        - EstimateIncomingCreepDps(target) * GetImpactDelay(unit, target)
    -- If prediction says the target may already die, attack immediately rather
    -- than leaving DENY indication hanging without an order.
    return predicted <= secure * 1.12
end

local function BuildCreepClaims(unit)
    local claimed = {}
    local unitIndex = SafeIndex(unit)
    for i = 1, #razorbacks do
        local otherIndex = SafeIndex(razorbacks[i])
        if otherIndex and unitIndex and otherIndex ~= unitIndex then
            local otherState = states[otherIndex]
            local target = otherState and (otherState.committedTarget or otherState.target) or nil
            if IsEntityAlive(target) and NPC.IsLaneCreep(target) then
                claimed[SafeIndex(target)] = true
            end
        end
    end
    return claimed
end

local function IsCreepTaskAlive(unit, hero, creep, state, now)
    if not IsEntityAlive(creep) or not NPC.IsLaneCreep(creep) or now >= state.commitUntil then
        return false
    end
    if hero and Dist2D(hero, creep) > ui.farmLeash:Get() + 250 then
        return false
    end
    if Entity.IsSameTeam(creep, unit) then
        return ui.denyCreeps:Get() and IsDeniableCreep(creep, unit)
    end
    return ui.lastHitCreeps:Get()
        and IsValidTarget(creep, unit)
        and Entity.GetHealth(creep) <= GetSecureDamage(unit, creep) * 2.6
end

local function GetCreepTask(unit, state, nearbyEnemies, hero, now)
    local wantFarm = ui.lastHitCreeps:Get()
    local wantDeny = ui.denyCreeps:Get()
    if not wantFarm and not wantDeny then
        state.committedTarget = nil
        return nil
    end
    -- Honor the running commitment while the kill stays winnable: this
    -- hysteresis is what stops mode flip-flopping.
    if state.committedTarget then
        if IsCreepTaskAlive(unit, hero, state.committedTarget, state, now) then
            return state.committedTarget
        end
        state.committedTarget = nil
    end
    local leash = ui.farmLeash:Get()
    local claimed = BuildCreepClaims(unit)
    local best, bestScore = nil, math.huge
    if wantFarm then
        for i = 1, #nearbyEnemies do
            local creep = nearbyEnemies[i]
            if NPC.IsLaneCreep(creep)
                and IsValidTarget(creep, unit)
                and not claimed[SafeIndex(creep)]
                and (not hero or Dist2D(hero, creep) <= leash) then
                local secure = GetSecureDamage(unit, creep)
                local health = Entity.GetHealth(creep)
                -- Take creeps already in the window, or approach ones the lane
                -- will bring into it within roughly two hits.
                if IsLastHittable(unit, creep)
                    or (health <= secure * 2.2 and EstimateIncomingCreepDps(creep) > 0) then
                    local score = health / math.max(1, secure) + Dist2D(unit, creep) / 3000
                    if score < bestScore then
                        best, bestScore = creep, score
                    end
                end
            end
        end
    end
    if wantDeny then
        for i = 1, #friendlyLaneCreeps do
            local creep = friendlyLaneCreeps[i]
            if IsDeniableCreep(creep, unit)
                and not SameEntity(creep, unit)
                and not claimed[SafeIndex(creep)]
                and (not hero or Dist2D(hero, creep) <= leash)
                and Dist2D(unit, creep) <= TARGET_SEARCH_RADIUS then
                local secure = GetSecureDamage(unit, creep)
                local health = Entity.GetHealth(creep)
                local incomingDps = EstimateIncomingCreepDps(creep)
                local predicted = health - incomingDps * GetImpactDelay(unit, creep)
                if predicted <= secure * 1.15 then
                    -- Denies use impact-time prediction, so the boar starts its
                    -- swing before the allied creep is already dead.
                    local score = (math.max(0, predicted) / math.max(1, secure)) * 1.15
                        + Dist2D(unit, creep) / 3000
                    if score < bestScore then
                        best, bestScore = creep, score
                    end
                end
            end
        end
    end
    if best then
        state.committedTarget = best
        state.commitUntil = now + (Entity.IsSameTeam(best, unit) and DENY_COMMIT_SECONDS or 2.0)
    end
    return best
end

local function GetArmorValue(target)
    if not HAS_ARMOR_VALUE then
        return 0
    end
    local value = NPC.GetPhysicalArmorValue(target)
    if type(value) ~= "number" then
        return 0
    end
    return value
end

local function GetEffectiveHealth(target)
    local armor = GetArmorValue(target)
    local multiplier = 1 - 0.06 * armor / (1 + 0.06 * math.abs(armor))
    return Entity.GetHealth(target) / math.max(0.25, multiplier)
end

local squadDpsCache = 1
local squadDpsCacheAt = -1

local function GetSquadDamagePerSecond()
    local now = GameRules.GetGameTime()
    if squadDpsCacheAt == now then
        return squadDpsCache
    end
    local dps = 0
    for i = 1, #razorbacks do
        local boar = razorbacks[i]
        if IsEntityAlive(boar) then
            local averageDamage = ((NPC.GetTrueDamage(boar) or 0) + (NPC.GetTrueMaximumDamage(boar) or 0)) * 0.5
            if averageDamage <= 0 then
                averageDamage = NPC.GetTrueMaximumDamage(boar) or 0
            end
            local attacksPerSecond = NPC.GetAttacksPerSecond and NPC.GetAttacksPerSecond(boar) or nil
            if not attacksPerSecond or attacksPerSecond <= 0 then
                attacksPerSecond = 1 / math.max(0.4, NPC.GetAttackTime(boar) or 1)
            end
            dps = dps + averageDamage * attacksPerSecond
        end
    end
    squadDpsCache = math.max(1, dps)
    squadDpsCacheAt = now
    return squadDpsCache
end

local function ScoreHeroTarget(unit, state, target, squadDps)
    local timeToKill = GetEffectiveHealth(target) / squadDps
    local score = -timeToKill * 100 - Dist2D(unit, target) * 0.06
    if timeToKill <= 3.5 then
        score = score + 400
    end
    if state and SameEntity(state.target, target) then
        score = score + 60
    end
    -- Burst window: a disabled hero cannot fight back or escape.
    if not IsUnitActionable(target) then
        score = score + 260
    elseif Enum.ModifierState.MODIFIER_STATE_ROOTED and NPC.HasState(target, Enum.ModifierState.MODIFIER_STATE_ROOTED) then
        score = score + 140
    end
    return score
end

local function GetBestHeroTarget(unit, state, heroes)
    if #heroes == 0 then
        return nil
    end
    local squadDps = GetSquadDamagePerSecond()
    local best, bestScore = nil, -math.huge
    for i = 1, #heroes do
        local score = ScoreHeroTarget(unit, state, heroes[i], squadDps)
        if score > bestScore then
            best, bestScore = heroes[i], score
        end
    end
    return best
end

local function GetBoarDenyTarget(unit)
    if not ui.denyBoars:Get() or not IsUnitActionable(unit) then
        return nil
    end
    local configuredThreshold = math.min(ui.denyBoarsHealth:Get(), 49)
    local unitHp = Entity.GetHealth(unit) / math.max(1, Entity.GetMaxHealth(unit)) * 100
    local best, bestScore = nil, math.huge

    for i = 1, #razorbacks do
        local ally = razorbacks[i]
        if not SameEntity(ally, unit)
            and IsDeniableBoar(ally, unit)
            and Dist2D(unit, ally) <= TARGET_SEARCH_RADIUS then
            local hpPercent = Entity.GetHealth(ally) / math.max(1, Entity.GetMaxHealth(ally)) * 100
            local incomingDps = EstimateIncomingCreepDps(ally)
            local allyIndex = SafeIndex(ally)
            local enemies = allyIndex and nearbyEnemiesByRazorback[allyIndex] or EMPTY_PROJECTILE_LIST
            local immediateThreat = incomingDps > 0

            -- Projectiles and a hero/tower actively hitting the summon are urgent.
            for j = 1, #enemies do
                local enemy = enemies[j]
                if IsEntityAlive(enemy) and Dist2D(enemy, ally) <= DENY_THREAT_RADIUS then
                    if NPC.IsHero(enemy) or NPC.IsTower(enemy) or IsAttackingTarget(enemy, ally) then
                        immediateThreat = true
                        break
                    end
                end
            end
            local projectiles = GetProjectilesOn(ally, GameRules.GetGameTime())
            for j = 1, #projectiles do
                if projectiles[j].isAttack or projectiles[j].dodgeable then
                    immediateThreat = true
                    break
                end
            end

            -- In danger start at 49%, regardless of an older saved low slider value.
            local trigger = immediateThreat and 49 or configuredThreshold
            -- Any living sibling that is healthier than the victim may perform the deny.
            local healthyEnough = unitHp >= math.max(20, hpPercent + 5)
            if hpPercent <= trigger and healthyEnough then
                local impact = GetImpactDelay(unit, ally)
                local predicted = Entity.GetHealth(ally) - incomingDps * impact
                -- Prefer the boar that can land soonest; strongly prefer emergencies.
                local score = impact * 500 + Dist2D(unit, ally)
                    + (immediateThreat and -1000 or 0)
                    + math.max(0, predicted) * 0.25
                if score < bestScore then
                    best, bestScore = ally, score
                end
            end
        end
    end

    if not best then
        return nil
    end

    local incomingDps = EstimateIncomingCreepDps(best)
    local secureDamage = math.max(1, GetSecureDamage(unit, best))
    local attackTime = math.max(0.4, NPC.GetAttackTime(unit) or 1)
    local hitsNeeded = math.ceil(Entity.GetHealth(best) / secureDamage)
    local soloFinishTime = GetImpactDelay(unit, best) + math.max(0, hitsNeeded - 1) * attackTime
    local enemyFinishTime = incomingDps > 0 and Entity.GetHealth(best) / incomingDps or math.huge

    -- If one boar cannot finish before the enemy, every healthy sibling helps.
    -- Otherwise exactly one sibling attacks, chosen by earliest impact.
    if enemyFinishTime <= soloFinishTime + 0.35 then
        return best
    end

    local myImpact = GetImpactDelay(unit, best)
    local myIndex = SafeIndex(unit) or math.huge
    for i = 1, #razorbacks do
        local other = razorbacks[i]
        if not SameEntity(other, best) and not SameEntity(other, unit)
            and IsEntityAlive(other) and IsUnitActionable(other) then
            local otherHp = Entity.GetHealth(other) / math.max(1, Entity.GetMaxHealth(other)) * 100
            local victimHp = Entity.GetHealth(best) / math.max(1, Entity.GetMaxHealth(best)) * 100
            if otherHp >= math.max(20, victimHp + 5) then
                local otherImpact = GetImpactDelay(other, best)
                local otherIndex = SafeIndex(other) or math.huge
                if otherImpact < myImpact - 0.03
                    or (math.abs(otherImpact - myImpact) <= 0.03 and otherIndex < myIndex) then
                    return nil
                end
            end
        end
    end
    return best
end
local function GetBoarOrder(unit)
    for i = 1, #razorbacks do
        if SameEntity(razorbacks[i], unit) then
            return i
        end
    end
    return 1
end

local function GetSpreadTarget(unit, state, heroes)
    local squadDps = GetSquadDamagePerSecond()
    local scored = {}
    for i = 1, #heroes do
        scored[#scored + 1] = { hero = heroes[i], value = ScoreHeroTarget(unit, state, heroes[i], squadDps) }
    end
    table.sort(scored, function(left, right)
        return left.value > right.value
    end)
    if GetEffectiveHealth(scored[1].hero) / squadDps <= 3.5 then
        return scored[1].hero
    end
    local pick = ((GetBoarOrder(unit) - 1) % #scored) + 1
    return scored[pick].hero
end

local function IsPassiveFarmPhase()
    local untilMinute = ui.passiveUntilMinute:Get()
    return untilMinute > 0 and GameRules.GetGameTime() < untilMinute * 60
end

local function IsBuildingUnit(unit)
    if not unit then
        return false
    end
    if NPC.IsTower(unit) then
        return true
    end
    return HAS_IS_STRUCTURE and NPC.IsStructure(unit) == true
end

local function GetPushTowerNearHero(hero)
    local closest, closestDistance = nil, math.huge
    for i = 1, #enemyTowers do
        local tower = enemyTowers[i]
        if IsEntityAlive(tower) and not Entity.IsDormant(tower) then
            local distance = Dist2D(hero, tower)
            if distance <= PUSH_LANE_TOWER_RADIUS and distance < closestDistance then
                closest, closestDistance = tower, distance
            end
        end
    end
    return closest
end

local function IsSupportedPushTarget(target, hero)
    if not IsValidTarget(target, hero) then
        return false
    end
    if IsBuildingUnit(target) then
        return true
    end
    -- Under an enemy tower, attacking its defending wave is also an explicit push.
    return NPC.IsLaneCreep(target) and GetPushTowerNearHero(hero) ~= nil
end

local function UpdateHeroSiegeTarget(hero, now)
    ownerHero = hero
    if not ui.helpPush:Get() or not hero then
        heroSiegeTarget = nil
        heroSiegeUntil = 0
        return
    end
    if HAS_ATTACK_TARGET then
        local value = NPC.GetAttackTarget(hero)
        if IsSupportedPushTarget(value, hero) then
            heroSiegeTarget = value
            heroSiegeUntil = now + PUSH_MEMORY_SECONDS
            return
        end
    end
    if now >= heroSiegeUntil or not IsEntityAlive(heroSiegeTarget) then
        heroSiegeTarget = nil
    end
end

local function IsActivePushTarget(target, unit, hero, now)
    return ui.helpPush:Get()
        and SameEntity(target, heroSiegeTarget)
        and IsSupportedPushTarget(target, hero)
        and now < heroSiegeUntil
        and Dist2D(hero, target) <= PUSH_MAX_HERO_DISTANCE
        and Dist2D(unit, target) <= math.max(ui.engageRadius:Get(), PUSH_MAX_HERO_DISTANCE)
end

local function UpdateSquadFocus()
    squadFocusTarget = nil
    squadFocusKillSecure = false
    if IsPassiveFarmPhase() then
        return
    end
    local seen, heroes = {}, {}
    for i = 1, #razorbacks do
        local index = SafeIndex(razorbacks[i])
        local nearby = (index and nearbyEnemiesByRazorback[index]) or {}
        for j = 1, #nearby do
            local enemy = nearby[j]
            if IsEntityAlive(enemy) and NPC.IsHero(enemy) and IsValidTarget(enemy) then
                local enemyIndex = SafeIndex(enemy)
                if enemyIndex and not seen[enemyIndex] then
                    seen[enemyIndex] = true
                    heroes[#heroes + 1] = enemy
                end
            end
        end
    end
    local reference = nil
    for i = 1, #razorbacks do
        if IsEntityAlive(razorbacks[i]) then
            reference = razorbacks[i]
            break
        end
    end
    if not reference then
        return
    end
    squadFocusTarget = GetBestHeroTarget(reference, GetState(reference), heroes)
    if squadFocusTarget then
        squadFocusKillSecure = GetEffectiveHealth(squadFocusTarget) / GetSquadDamagePerSecond() <= 3.5
    end
end

local function IsHeroImmediateThreat(unit, owner, enemy, state, now)
    if not IsValidTarget(enemy, unit) or not NPC.IsHero(enemy) then
        return false
    end
    local distance = Dist2D(unit, enemy)
    if distance <= 425 then
        return true
    end
    if IsLikelyAttackingUnit(enemy, unit)
        or (IsEntityAlive(owner) and IsLikelyAttackingUnit(enemy, owner)) then
        return true
    end
    if state.focusedUntil > now and distance <= 800 then
        return true
    end
    -- Interrupt a push for a very quick secured kill, but not merely because an
    -- enemy hero is visible somewhere inside the broad engage radius.
    local timeToKill = GetEffectiveHealth(enemy) / GetSquadDamagePerSecond()
    return timeToKill <= 2.5 and distance <= 700
end

local function GetAutonomousTarget(unit, state, nearbyEnemies, hero, now)
    local boarDeny = GetBoarDenyTarget(unit)
    if boarDeny then
        state.committedTarget = nil
        return boarDeny
    end

    local creepTask = GetCreepTask(unit, state, nearbyEnemies, hero, now)
    if creepTask and IsCreepKillSecure(unit, creepTask) then
        return creepTask
    end

    if not IsPassiveFarmPhase() then
        local engage = ui.engageRadius:Get()
        local activePush = IsActivePushTarget(heroSiegeTarget, unit, hero, now)
        local heroes = {}
        local immediateHeroes = {}
        for i = 1, #nearbyEnemies do
            local enemy = nearbyEnemies[i]
            if NPC.IsHero(enemy) and IsValidTarget(enemy, unit)
                and Dist2D(unit, enemy) <= engage then
                heroes[#heroes + 1] = enemy
                if IsHeroImmediateThreat(unit, hero, enemy, state, now) then
                    immediateHeroes[#immediateHeroes + 1] = enemy
                end
            end
        end

        if activePush then
            -- While Beastmaster is explicitly hitting a tower/wave, visibility
            -- alone does not switch the boar to COMBAT. Only a close attacker or
            -- a secured quick kill may interrupt the push.
            if #immediateHeroes > 0 then
                local threatTarget = GetBestHeroTarget(unit, state, immediateHeroes)
                if threatTarget then
                    return threatTarget
                end
            end
            state.committedTarget = nil
            return heroSiegeTarget
        end

        -- Outside an active push, ordinary combat selection is restored.
        if IsEntityAlive(state.target)
            and NPC.IsHero(state.target)
            and IsValidTarget(state.target, unit)
            and Dist2D(unit, state.target) <= engage then
            return state.target
        end
        if IsEntityAlive(squadFocusTarget)
            and IsValidTarget(squadFocusTarget, unit)
            and Dist2D(unit, squadFocusTarget) <= engage
            and (squadFocusKillSecure or not ui.spreadSlow:Get()) then
            return squadFocusTarget
        end
        local heroTarget = ui.spreadSlow:Get() and #heroes > 1
            and GetSpreadTarget(unit, state, heroes)
            or GetBestHeroTarget(unit, state, heroes)
        if heroTarget then
            return heroTarget
        end

        if now < state.resumeUntil and IsEntityAlive(state.resumeTarget)
            and IsValidTarget(state.resumeTarget, unit) then
            local resume = state.resumeTarget
            local heroStillPushing = Dist2D(hero, resume) <= PUSH_MAX_HERO_DISTANCE
                and GetPushTowerNearHero(hero) ~= nil
            if IsActivePushTarget(resume, unit, hero, now)
                or (heroStillPushing and (IsBuildingUnit(resume) or NPC.IsLaneCreep(resume))) then
                return resume
            end
        else
            state.resumeTarget = nil
            state.resumeUntil = 0
        end
    end

    return creepTask
end
local function GetCombatPosition(unit, target, state, kite)
    local origin = GetOrigin(unit)
    local targetOrigin = GetOrigin(target)
    local radX, radY = Normalize2D(origin.x - targetOrigin.x, origin.y - targetOrigin.y)
    if radX == 0 and radY == 0 then
        radX, radY = Rotate2D(1, 0, Entity.GetIndex(unit) * 47)
    end
    local sepX, sepY = 0, 0
    if ui.spreadFormation:Get() then
        sepX, sepY = GetSeparationDirection(unit, ui.separationDist:Get())
    end
    local dirX, dirY = Normalize2D(radX + sepX * 0.28, radY + sepY * 0.28)
    if dirX == 0 and dirY == 0 then
        dirX, dirY = radX, radY
    end
    dirX, dirY = Rotate2D(dirX, dirY, state.strafeSide * 6)
    local desiredDistance = math.max(180, GetAttackRangeWithBonus(unit) * ui.combatDistance:Get() / 100)
    if kite then
        -- Between swings: drift to the edge of attack range to soak less damage.
        desiredDistance = math.min(GetAttackRangeWithBonus(unit) + 130, desiredDistance * 1.45)
    end
    local corrections = { 0, 10, -10, 20, -20 }
    for i = 1, #corrections do
        local rx, ry = Rotate2D(dirX, dirY, corrections[i])
        local candidate = GroundVector(targetOrigin.x + rx * desiredDistance, targetOrigin.y + ry * desiredDistance)
        -- During an explicit push the boar must be allowed to enter firing
        -- range of the structure; tower aggro is handled separately by ShouldEvade.
        if GridNav.IsTraversable(candidate)
            and (state.mode == "push" or state.mode == "deny" or IsTowerSafeMove(unit, candidate)) then
            return candidate
        end
    end
    return nil
end

local function ResetAttackSequence(state, clearTarget)
    state.attackPending = false
    state.attackIssuedAt = 0
    state.attackReadyAt = 0
    if clearTarget then
        state.target = nil
    end
end

local function OrbwalkRazorback(player, unit, target, state, now)
    if not IsOrbwalkTarget(target, unit) then
        ResetAttackSequence(state, true)
        return
    end
    if not SameEntity(state.target, target) then
        state.attackPending = false
        state.target = target
        state.nextOrderAt = 0
    end
    if state.attackPending and HAS_ATTACK_TARGET
        and now - (state.attackIssuedAt or 0) >= 0.18 then
        local actualTarget = NPC.GetAttackTarget(unit)
        if not SameEntity(actualTarget, target) and not NPC.IsAttacking(unit) then
            state.attackPending = false
            state.nextOrderAt = 0
        end
    end
    if state.attackPending and now >= state.fallbackReleaseAt then
        state.attackPending = false
        state.strafeSide = state.strafeSide * -1
        local sameTeamTarget = Entity.IsSameTeam(target, unit)
        local kite = not sameTeamTarget and ui.kiteBetweenHits:Get() and NPC.IsHero(target)
        local nextPosition = not sameTeamTarget and not IsBuildingUnit(target)
            and GetCombatPosition(unit, target, state, kite) or nil
        if nextPosition then
            IssueMove(player, unit, state, nextPosition, now, false, false)
        end
        state.nextOrderAt = now + 0.1
        return
    end
    if state.attackPending or now < state.nextOrderAt then
        return
    end
    local combatPosition = GetCombatPosition(unit, target, state)
    local positionError = combatPosition and GetOrigin(unit):Distance2D(combatPosition) or 0
    local attackRange = GetAttackRangeWithBonus(unit)
        + NPC.GetHullRadius(unit)
        + NPC.GetHullRadius(target)
    local targetInRange = Dist2D(unit, target) <= attackRange + 20
    if now >= state.attackReadyAt and targetInRange then
        -- Creep discipline: never push with idle hits. Farm swings wait for the
        -- last-hit window, deny swings wait for a guaranteed-kill window.
        if state.targetIsCreep and not IsCreepKillSecure(unit, target) then
            local sameTeam = Entity.IsSameTeam(target, unit)
            local ready = sameTeam and IsDenyHittable(unit, target) or IsLastHittable(unit, target)
            if not ready then
                state.nextOrderAt = now + 0.015
                return
            end
        end
        -- Kill-secure: creeps and boars dying to one guaranteed hit skip humanized pacing.
        local urgent = Entity.IsSameTeam(target, unit)
            or (not NPC.IsHero(target) and IsCreepKillSecure(unit, target))
        if not IssueAttack(player, unit, target, state, now, urgent) then
            state.nextOrderAt = now + (urgent and 0.015 or 0.025)
            return
        end
        state.attackPending = true
        local releaseDelay = math.max(0.05, NPC.GetAttackAnimPoint(unit) or 0.3)
            + SafeTimeToFace(unit, target)
            + GetNetworkLatency()
        state.fallbackReleaseAt = now + math.min(1.1, releaseDelay + 0.05)
        state.attackReadyAt = now + math.max(0.2, NPC.GetAttackTime(unit) or 1)
        state.nextOrderAt = now + (urgent and 0.02 or 0.045)
        return
    end
    if not targetInRange then
        if combatPosition then
            IssueMove(player, unit, state, combatPosition, now, false, false)
        end
        state.nextOrderAt = now + 0.08
        return
    end
    if now < state.attackReadyAt then
        if Entity.IsSameTeam(target, unit) then
            state.nextOrderAt = math.min(state.attackReadyAt, now + 0.025)
            return
        end
        local kiting = ui.kiteBetweenHits:Get()
            and NPC.IsHero(target)
            and (state.attackReadyAt - now) >= 0.35
        local holdPosition = combatPosition
        local holdError = positionError
        if kiting then
            local kitePosition = GetCombatPosition(unit, target, state, true)
            if kitePosition then
                holdPosition = kitePosition
                holdError = GetOrigin(unit):Distance2D(kitePosition)
            end
        end
        if holdPosition and holdError > (kiting and 45 or 75) then
            IssueMove(player, unit, state, holdPosition, now, false, false)
        end
    end
    state.nextOrderAt = now + 0.08
end

local function FollowBeastmaster(player, unit, hero, state, now)
    local gap = Dist2D(unit, hero)
    if now < state.nextOrderAt or gap <= 550 then
        return
    end
    local heroOrigin = GetOrigin(hero)
    local origin = GetOrigin(unit)
    local dirX, dirY = Normalize2D(origin.x - heroOrigin.x, origin.y - heroOrigin.y)
    if dirX == 0 and dirY == 0 then
        dirX, dirY = Rotate2D(1, 0, Entity.GetIndex(unit) * 47)
    end
    -- Escort slots: each boar keeps its own flank (~30 degrees to a side)
    -- instead of the pack stacking on a single point behind the hero.
    local side = state.strafeSide or 1
    local slotX = dirX * 0.86 - dirY * 0.5 * side
    local slotY = dirY * 0.86 + dirX * 0.5 * side
    local destination = GroundVector(heroOrigin.x + slotX * 325, heroOrigin.y + slotY * 325)
    if IsTowerSafeMove(unit, destination) then
        IssueMove(player, unit, state, destination, now, false, true)
    end
    -- Far behind the hero: reissue moves faster to catch up smoothly.
    state.nextOrderAt = now + (gap > 1400 and 0.15 or 0.25)
end

local function GetCursorTarget(hero, mode)
    local teamNum = Entity.GetTeamNum(hero)
    local target
    if mode == 0 then
        target = Input.GetNearestHeroToCursor(teamNum, Enum.TeamType.TEAM_ENEMY)
    else
        target = Input.GetNearestUnitToCursor(teamNum, Enum.TeamType.TEAM_ENEMY)
    end
    if not target or not IsValidTarget(target) then
        return nil
    end
    if mode == 1 and GetOrigin(target):Distance2D(Input.GetWorldCursorPos()) > 700 then
        return nil
    end
    return target
end

local function GetNearestTarget(unit)
    local valid = {}
    local nearby = GetNearbyEnemies(unit, TARGET_SEARCH_RADIUS)
    for i = 1, #nearby do
        if IsValidTarget(nearby[i], unit) then
            valid[#valid + 1] = nearby[i]
        end
    end
    return GetClosest(GetOrigin(unit), valid)
end

local function GetThinkPriority(unit, now)
    if not CanReceiveOrders(unit) then
        return 0
    end
    local state = GetState(unit)
    if IsManualControlActive(unit, state, now) then
        return 0
    end
    if state.focusedUntil > now then
        return 3
    end
    if state.attackPending or now < state.attackReadyAt or not state.target then
        return 1
    end
    if not IsValidTarget(state.target, unit) then
        return 1
    end
    local attackRange = GetAttackRangeWithBonus(unit)
        + NPC.GetHullRadius(unit)
        + NPC.GetHullRadius(state.target)
        + 20
    return Dist2D(unit, state.target) <= attackRange and 2 or 1
end

local function GetOrderedRazorbacks(data, hero, player, playerId)
    if data.orderIssuer == Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_SELECTED_UNITS then
        local selected = Player.GetSelectedUnits(player) or {}
        local result = {}
        for i = 1, #selected do
            if IsControlledRazorback(selected[i], hero, playerId) then
                result[#result + 1] = selected[i]
            end
        end
        return result
    end
    if data.npc and IsControlledRazorback(data.npc, hero, playerId) then
        return { data.npc }
    end
    return {}
end

local function ResetRuntime()
    if disabledByTimer and not ui.enable:Get() then
        ui.enable:Set(true)
    end
    states = {}
    razorbacks = {}
    nearbyEnemiesByRazorback = {}
    enemyTowers = {}
    projectilesByTarget = {}
    nextScanAt = 0
    nextThinkAt = 0
    rosterKey = ""
    thinkCursor = 0
    aiOrderNotBefore = 0
    userOrderPriorityUntil = 0
    autoDisableTriggered = false
    disabledByTimer = false
    metrics.evades = 0
    metrics.lastHits = 0
    metrics.startedAt = nil
    squadFocusTarget = nil
    friendlyLaneCreeps = {}
    incomingDpsCache = {}
    heroSiegeTarget = nil
    heroSiegeUntil = 0
end

local Callbacks = {}

function Callbacks.OnProjectile(data)
    -- API v2 exposes source, target, timing and projectile flags. Keep the
    -- source for directional dodging and fall back safely when it is absent.
    if not IsEntityValid(data.target) then
        return
    end
    local index = Entity.GetIndex(data.target)
    local list = projectilesByTarget[index]
    if not list then
        list = {}
        projectilesByTarget[index] = list
    end
    list[#list + 1] = {
        source = IsEntityValid(data.source) and data.source or nil,
        targetLoc = data.target_loc and data.target_loc:Clone() or nil,
        isAttack = data.isAttack,
        dodgeable = data.dodgeable,
        expireAt = GameRules.GetGameTime() + math.min(2, math.max(0.25, data.maxImpactTime or 1)),
    }
end

function Callbacks.OnPrepareUnitOrders(data)
    if not ui.enable:Get() or not IsGameActive() then
        return true
    end
    local player = Players.GetLocal()
    if not player or not SameEntity(data.player, player) then
        return true
    end
    local hero = Player.GetAssignedHero(player)
    if not hero then
        return true
    end
    local playerId = Player.GetPlayerID(player)
    local now = GameRules.GetGameTime()
    userOrderPriorityUntil = math.max(userOrderPriorityUntil, now + ui.playerPriority:Get())
    -- Siege assist fallback: remember manual attack orders on buildings.
    if data.order == Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET
        and IsSupportedPushTarget(data.target, hero) then
        heroSiegeTarget = data.target
        heroSiegeUntil = now + 5
    end
    local ordered = GetOrderedRazorbacks(data, hero, player, playerId)
    for i = 1, #ordered do
        local state = GetState(ordered[i])
        if state then
        state.manualUntil = now + ui.manualDelay:Get()
        state.manualIssuedAt = now
        state.manualOrder = data.order
        state.manualPosition = data.position and data.position:Clone() or nil
        state.manualTarget = data.target
        state.attackPending = false
        state.nextOrderAt = state.manualUntil
        if data.order == Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET and IsEntityValid(data.target) then
            state.target = data.target
        end
        end
    end
    return true
end

function Callbacks.OnUpdate()
    if not IsGameActive() or GameRules.IsPaused() then
        return
    end
    local now = GameRules.GetGameTime()
    if not autoDisableTriggered and ui.autoDisable:Get() and now >= ui.autoDisableMinute:Get() * 60 then
        autoDisableTriggered = true
        if ui.enable:Get() then
            disabledByTimer = true
            ui.enable:Set(false)
        end
    end
    if not ui.enable:Get() then
        return
    end
    if metrics.startedAt == nil then
        metrics.startedAt = now
    end
    if now < nextThinkAt and now < nextScanAt then
        return
    end
    local player = Players.GetLocal()
    if not player then
        return
    end
    local hero = Player.GetAssignedHero(player)
    if not hero or not string.find(NPC.GetUnitName(hero) or "", "beastmaster", 1, true) then
        return
    end
    local playerId = Player.GetPlayerID(player)
    if now >= nextScanAt then
        local friendly = Entity.GetUnitsInRadius(hero, 99999, Enum.TeamType.TEAM_FRIEND, true, true) or {}
        local scanned = {}
        for i = 1, #friendly do
            if IsControlledRazorback(friendly[i], hero, playerId) then
                scanned[#scanned + 1] = friendly[i]
            end
        end
        table.sort(scanned, function(left, right)
            return (SafeIndex(left) or 0) < (SafeIndex(right) or 0)
        end)
        razorbacks = PruneEntities(scanned)
        friendlyLaneCreeps = {}
        for i = 1, #friendly do
            if IsEntityAlive(friendly[i]) and NPC.IsLaneCreep(friendly[i]) then
                friendlyLaneCreeps[#friendlyLaneCreeps + 1] = friendly[i]
            end
        end
        nearbyEnemiesByRazorback = {}
        enemyTowers = {}
        local towerSeen = {}
        for i = 1, #razorbacks do
            local razorback = razorbacks[i]
            local units = IsEntityValid(razorback)
                and (Entity.GetUnitsInRadius(razorback, TARGET_SEARCH_RADIUS, Enum.TeamType.TEAM_ENEMY, true, true) or {})
                or {}
            local enemies = {}
            for j = 1, #units do
                local unit = units[j]
                if IsEntityAlive(unit)
                    and not Entity.IsDormant(unit)
                    and (NPC.IsHero(unit) or NPC.IsTower(unit) or NPC.IsCreep(unit)) then
                    enemies[#enemies + 1] = unit
                    if NPC.IsTower(unit) and not towerSeen[Entity.GetIndex(unit)] then
                        towerSeen[Entity.GetIndex(unit)] = true
                        enemyTowers[#enemyTowers + 1] = unit
                    end
                end
            end
            local razorbackIndex = SafeIndex(razorback)
            if razorbackIndex then
                nearbyEnemiesByRazorback[razorbackIndex] = enemies
            end
        end
        local key = {}
        for i = 1, #razorbacks do
            key[#key + 1] = tostring(SafeIndex(razorbacks[i]) or 0)
        end
        local scannedKey = table.concat(key, "|")
        if scannedKey ~= rosterKey then
            for i = 1, #razorbacks do
                local state = GetState(razorbacks[i])
                if state then
                state.attackPending = false
                state.fallbackReleaseAt = 0
                state.nextOrderAt = now + (i - 1) * 0.04
                state.lastAiOrderAt = -10
                state.orderLockUntil = now
                state.lastMovePosition = nil
                end
            end
            rosterKey = scannedKey
        end
        RemoveExpiredStates(razorbacks)
        nextScanAt = now + WORLD_SCAN_INTERVAL
    end
    if now < nextThinkAt then
        return
    end
    nextThinkAt = now + THINK_INTERVAL
    UpdateSquadFocus()
    UpdateHeroSiegeTarget(hero, GameRules.GetGameTime())
    local manualTargetMode = ui.orbwalk:Get() and ui.orbwalkKey:IsDown()
    local cursorTarget = nil
    if manualTargetMode and ui.targetMode:Get() < 2 then
        cursorTarget = GetCursorTarget(hero, ui.targetMode:Get())
    end
    razorbacks = PruneEntities(razorbacks)
    local razorbackCount = #razorbacks
    if razorbackCount == 0 then
        thinkCursor = 0
        return
    end
    local thinkOrder = {}
    for offset = 0, razorbackCount - 1 do
        local razorback = razorbacks[(thinkCursor + offset) % razorbackCount + 1]
        if CanReceiveOrders(razorback) then
            UpdateFocusState(razorback, GetState(razorback), now)
        end
        thinkOrder[#thinkOrder + 1] = {
            unit = razorback,
            sequence = offset,
            priority = GetThinkPriority(razorback, now),
        }
    end
    table.sort(thinkOrder, function(left, right)
        if left.priority ~= right.priority then
            return left.priority > right.priority
        end
        return left.sequence < right.sequence
    end)
    for i = 1, #thinkOrder do
        local razorback = thinkOrder[i].unit
        if CanReceiveOrders(razorback) then
            local state = GetState(razorback)
            if not IsManualControlActive(razorback, state, now) then
                ClearManualOrder(state)
                local nearbyEnemies = GetNearbyEnemies(razorback, TARGET_SEARCH_RADIUS)
                local immediateThreats = {}
                if ui.avoidDeath:Get() then
                    for j = 1, #nearbyEnemies do
                        if Dist2D(razorback, nearbyEnemies[j]) <= ui.dangerRadius:Get() then
                            immediateThreats[#immediateThreats + 1] = nearbyEnemies[j]
                        end
                    end
                end
                if ShouldEvade(razorback, state, immediateThreats, now) then
                    Evade(player, razorback, hero, state, immediateThreats, now)
                elseif ui.criticalRetreat:Get()
                    and ui.avoidDeath:Get()
                    and Entity.GetHealth(razorback) / math.max(1, Entity.GetMaxHealth(razorback)) * 100 <= ui.retreatHealth:Get() * 0.7 then
                    state.mode = "retreat"
                    ResetAttackSequence(state, false)
                    FollowBeastmaster(player, razorback, hero, state, now)
                elseif not ui.orbwalk:Get() then
                    state.mode = "idle"
                    ResetAttackSequence(state, false)
                else
                    local target
                    if manualTargetMode then
                        target = ui.targetMode:Get() == 2 and GetNearestTarget(razorback) or cursorTarget
                    else
                        target = GetAutonomousTarget(razorback, state, nearbyEnemies, hero, now)
                    end
                    if not target then
                        state.mode = "follow"
                        ResetAttackSequence(state, true)
                        FollowBeastmaster(player, razorback, hero, state, now)
                    else
                        if IsActivePushTarget(target, razorback, hero, now) then
                            state.mode = "push"
                        elseif Entity.IsSameTeam(target, razorback) then
                            state.mode = "deny"
                        elseif NPC.IsLaneCreep(target) then
                            state.mode = "lasthit"
                        elseif IsBuildingUnit(target) then
                            state.mode = "push"
                        else
                            state.mode = "combat"
                        end
                        state.targetIsCreep = (state.mode == "lasthit" or state.mode == "deny") and NPC.IsLaneCreep(target)
                        OrbwalkRazorback(player, razorback, target, state, now)
                    end
                end
            end
        end
    end
    if razorbackCount > 0 then
        thinkCursor = (thinkCursor + 1) % razorbackCount
    end
end

local HUD_THEMES = {
    { -- NeverLose: dark navy, electric blue accent, glowing underline
        window  = { 10, 14, 22, 236 },
        header  = { 14, 19, 30, 255 },
        card    = { 17, 23, 35, 255 },
        accent  = { 0, 162, 255 },
        text    = { 232, 238, 247 },
        muted   = { 108, 121, 143 },
        good    = { 53, 211, 146 },
        warn    = { 255, 194, 75 },
        bad     = { 255, 75, 92 },
        outline = { 34, 44, 64 },
        barBack = { 30, 39, 56 },
    },
    { -- Discord: graphite, blurple accent
        window  = { 30, 31, 34, 240 },
        header  = { 24, 25, 28, 255 },
        card    = { 43, 45, 49, 255 },
        accent  = { 88, 101, 242 },
        text    = { 219, 222, 225 },
        muted   = { 148, 155, 164 },
        good    = { 35, 165, 90 },
        warn    = { 240, 178, 50 },
        bad     = { 242, 63, 67 },
        outline = { 55, 57, 62 },
        barBack = { 55, 57, 62 },
    },
    { -- Spotify: near-black, green accent
        window  = { 18, 18, 18, 242 },
        header  = { 12, 12, 12, 255 },
        card    = { 24, 24, 24, 255 },
        accent  = { 30, 215, 96 },
        text    = { 255, 255, 255 },
        muted   = { 179, 179, 179 },
        good    = { 30, 215, 96 },
        warn    = { 255, 194, 75 },
        bad     = { 241, 94, 108 },
        outline = { 40, 40, 40 },
        barBack = { 51, 51, 51 },
    },
}

local MODE_LABELS = {
    en = { combat = "COMBAT", push = "PUSH", lasthit = "FARM", deny = "DENY", follow = "FOLLOW", retreat = "RETREAT", evade = "EVADE", manual = "OVERRIDE", idle = "IDLE" },
    ru = { combat = "БОЙ", push = "ПУШ", lasthit = "ФАРМ", deny = "ДЕНАЙ", follow = "СЛЕДУЕТ", retreat = "ОТХОД", evade = "УКЛОН", manual = "ПЕРЕХВАТ", idle = "ОЖИДАНИЕ" },
}


local hudFont = nil
local drawCaps = {
    rect = type(Render.FilledRect) == "function",
    outline = type(Render.Rect) == "function",
    circle = type(Render.FilledCircle) == "function",
    text = type(Render.Text) == "function",
    textSize = type(Render.TextSize) == "function",
    screenSize = type(Render.ScreenSize) == "function",
}
local function HudColor(rgb, alpha)
    local a = alpha or rgb[4] or 255
    return Color(rgb[1], rgb[2], rgb[3], math.floor(math.max(0, math.min(255, a))))
end

local function RectSecond(x, y, w, h)
    -- Per UCZone API v2: Render.FilledRect/Rect take start and end corner points.
    return Vec2(x + w, y + h)
end

local function HudRect(x, y, w, h, rgb, alpha, rounding)
    if not drawCaps.rect or w <= 0 or h <= 0 then
        return
    end
    Render.FilledRect(Vec2(x, y), RectSecond(x, y, w, h), HudColor(rgb, alpha), rounding or 0)
end

local function HudOutline(x, y, w, h, rgb, alpha, rounding)
    if not drawCaps.outline then
        return
    end
    Render.Rect(Vec2(x, y), RectSecond(x, y, w, h), HudColor(rgb, alpha), rounding or 0)
end

local function HudCircle(x, y, radius, rgb, alpha)
    if drawCaps.circle then
        Render.FilledCircle(Vec2(x, y), radius, HudColor(rgb, alpha))
        return
    end
    HudRect(x - radius, y - radius, radius * 2, radius * 2, rgb, alpha, radius)
end

local function HudText(font, size, text, x, y, rgb, alpha)
    if drawCaps.text then
        Render.Text(font, size, text, Vec2(x, y), HudColor(rgb, alpha))
    end
end

local function Utf8Length(text)
    -- Count characters, not bytes: Cyrillic letters are 2 bytes each in UTF-8.
    local _, count = string.gsub(text, "[^\128-\191]", "")
    return count
end

local function HudTextSize(font, size, text)
    if drawCaps.textSize then
        local result = Render.TextSize(font, size, text)
        if result and result.x and result.x > 0 then
            return result
        end
    end
    return Vec2(Utf8Length(text) * size * 0.6, size)
end

local function GetHudLang()
    return ui.language:Get() == 1 and "ru" or "en"
end

local function GetModeColor(theme, mode)
    if mode == "combat" or mode == "push" then
        return theme.accent
    end
    if mode == "lasthit" or mode == "deny" then
        return theme.good
    end
    if mode == "evade" then
        return theme.bad
    end
    if mode == "manual" or mode == "retreat" then
        return theme.warn
    end
    return theme.muted
end

local function GetHealthColor(theme, fraction)
    if fraction > 0.55 then
        return theme.good
    end
    if fraction > 0.3 then
        return theme.warn
    end
    return theme.bad
end

local function GetDisplayMode(unit, state, now)
    if IsManualControlActive(unit, state, now) then
        return "manual"
    end
    return state.mode or "idle"
end

-- Mouse drag state for the status panel. The overhead chips are pinned to
-- each unit's health bar and can no longer be moved with the cursor.
local HUD_WHITE = { 255, 255, 255 }
local SHADOW_BLACK = { 0, 0, 0 }
local panelDrag = { active = false, offsetX = 0, offsetY = 0, wasDown = false }

-- World-space anchor glued to the top of the unit's health bar, so the chip
-- keeps its place at any camera zoom or angle.
local function GetHealthBarAnchor(unit)
    local origin = GetOrigin(unit)
    if not origin then
        return nil
    end
    local offset = 180
    if HAS_HEALTH_BAR_OFFSET then
        local value = NPC.GetHealthBarOffset(unit)
        if type(value) == "number" and value > 0 then
            offset = value
        end
    end
    return Vector(origin.x, origin.y, origin.z + offset)
end

local function DrawOverheadChips(theme, now, lang)
    for i = 1, #razorbacks do
        local razorback = razorbacks[i]
        local state = IsEntityAlive(razorback) and GetState(razorback) or nil
        if state then
            local anchor = GetHealthBarAnchor(razorback)
            local screenPos, visible = nil, false
            if anchor then
                screenPos, visible = Render.WorldToScreen(anchor)
            end
            if visible and screenPos then
                local mode = GetDisplayMode(razorback, state, now)
                local text = MODE_LABELS[lang][mode] or mode
                if mode == "manual" then
                    local remaining = math.max(0, state.manualUntil - now)
                    if remaining > 0 then
                        text = string.format("%s %.1f", text, remaining)
                    end
                end
                local modeColor = GetModeColor(theme, mode)
                if drawCaps.rect then
                    local textSize = HudTextSize(hudFont, 11, text)
                    -- Dot zone (16px) + text + right padding; the pill is centered
                    -- on the health bar and sits a fixed gap above it.
                    local chipW = 16 + textSize.x + 10
                    local chipH = 17
                    local chipX = math.floor(screenPos.x - chipW / 2 + 0.5)
                    local chipY = math.floor(screenPos.y - chipH - 20 + 0.5)
                    -- Soft shadow, pill body, glass highlight, mode-colored ring
                    HudRect(chipX + 1, chipY + 2, chipW, chipH, SHADOW_BLACK, 90, 9)
                    HudRect(chipX, chipY, chipW, chipH, theme.window, 235, 9)
                    HudRect(chipX + 1, chipY + 1, chipW - 2, math.floor(chipH / 2), HUD_WHITE, 10, 8)
                    HudOutline(chipX, chipY, chipW, chipH, modeColor, 120, 9)
                    -- Status dot with a soft glow halo
                    HudCircle(chipX + 9, chipY + chipH / 2, 4.5, modeColor, 55)
                    HudCircle(chipX + 9, chipY + chipH / 2, 2.4, modeColor, 255)
                    HudText(hudFont, 11, text, chipX + 16, chipY + math.floor((chipH - textSize.y) / 2), theme.text, 255)
                    -- Slim health strip docked under the pill, right above the game bar
                    local hpFraction = Entity.GetHealth(razorback) / math.max(1, Entity.GetMaxHealth(razorback))
                    HudRect(chipX + 4, chipY + chipH + 2, chipW - 8, 2, theme.barBack, 170, 1)
                    HudRect(chipX + 4, chipY + chipH + 2, (chipW - 8) * hpFraction, 2, GetHealthColor(theme, hpFraction), 255, 1)
                else
                    local textSize = HudTextSize(statusFont, 13, text)
                    HudText(statusFont, 13, text, screenPos.x - textSize.x / 2, screenPos.y - textSize.y - 18, modeColor, 255)
                end
            end
        end
    end
end

local function GetScreenSize()
    if drawCaps.screenSize then
        local size = Render.ScreenSize()
        if size then
            return size
        end
    end
    return Vec2(1920, 1080)
end

local PANEL_TITLES = { en = "Razorbacks", ru = "Кабаны" }

local function DrawStatusPanel(theme, now, lang)
    if not drawCaps.rect then
        return
    end
    local rows = {}
    local maxNameW, maxRightW = 0, 0
    for i = 1, #razorbacks do
        local razorback = razorbacks[i]
        local state = IsEntityAlive(razorback) and GetState(razorback) or nil
        if state then
            local mode = GetDisplayMode(razorback, state, now)
            local name = string.format("%s %d", MODE_LABELS[lang][mode] or mode, #rows + 1)
            local hpFraction = Entity.GetHealth(razorback) / math.max(1, Entity.GetMaxHealth(razorback))
            local right
            local remaining = math.max(0, state.manualUntil - now)
            if mode == "manual" and remaining > 0 then
                right = string.format("%d:%02d", math.floor(remaining / 60), math.floor(remaining % 60))
            else
                right = string.format("%d%%", math.floor(hpFraction * 100 + 0.5))
            end
            local nameSize = HudTextSize(hudFont, 12, name)
            local rightSize = HudTextSize(hudFont, 12, right)
            maxNameW = math.max(maxNameW, nameSize.x)
            maxRightW = math.max(maxRightW, rightSize.x)
            rows[#rows + 1] = {
                color = GetModeColor(theme, mode),
                name = name,
                right = right,
                rightW = rightSize.x,
                textH = nameSize.y,
                hp = hpFraction,
            }
        end
    end
    if #rows == 0 then
        return
    end
    local pad = 10
    local rowH = 26
    local headerH = 32
    local tile = 18
    local width = math.floor(math.max(170, pad + tile + 8 + maxNameW + 24 + maxRightW + pad))
    local height = headerH + #rows * rowH + pad
    local screen = GetScreenSize()
    local x = math.floor(screen.x * ui.panelPosX:Get() / 100)
    local y = math.floor(screen.y * ui.panelPosY:Get() / 100)
    -- Drag: grab the header with the left mouse button; release saves to the menu.
    local cursorX, cursorY = Input.GetCursorPos()
    local mouseDown = Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE1)
    if panelDrag.active then
        if mouseDown then
            x = math.floor(cursorX - panelDrag.offsetX + 0.5)
            y = math.floor(cursorY - panelDrag.offsetY + 0.5)
        else
            panelDrag.active = false
            if screen.x > 0 and screen.y > 0 then
                local px = math.floor((cursorX - panelDrag.offsetX) / screen.x * 100 + 0.5)
                local py = math.floor((cursorY - panelDrag.offsetY) / screen.y * 100 + 0.5)
                ui.panelPosX:Set(math.max(0, math.min(95, px)))
                ui.panelPosY:Set(math.max(0, math.min(95, py)))
                x = math.floor(screen.x * ui.panelPosX:Get() / 100)
                y = math.floor(screen.y * ui.panelPosY:Get() / 100)
            end
        end
    elseif mouseDown and not panelDrag.wasDown
        and not Input.IsInputCaptured()
        and Input.IsCursorInRect(x, y, width, headerH) then
        panelDrag.active = true
        panelDrag.offsetX = cursorX - x
        panelDrag.offsetY = cursorY - y
    end
    panelDrag.wasDown = mouseDown
    -- drop shadow + window
    HudRect(x + 3, y + 4, width, height, { 0, 0, 0 }, 100, 12)
    HudRect(x, y, width, height, theme.window, 245, 10)
    HudOutline(x, y, width, height, theme.outline, nil, 10)
    -- header band + underline
    HudRect(x + 2, y + 2, width - 4, headerH - 4, theme.header, 150, 9)
    HudRect(x + pad, y + headerH - 2, width - pad * 2, 2, theme.accent, 130, 1)
    -- header: title left, accent badge right
    local title = PANEL_TITLES[lang] or PANEL_TITLES.en
    local titleSize = HudTextSize(hudFont, 13, title)
    HudText(hudFont, 13, title, x + pad, y + math.floor((headerH - titleSize.y) / 2), theme.text, 255)
    local btn = 16
    local btnX = x + width - pad - btn
    local btnY = y + math.floor((headerH - btn) / 2)
    HudRect(btnX, btnY, btn, btn, theme.accent, 55, 5)
    HudOutline(btnX, btnY, btn, btn, theme.accent, 110, 5)
    -- tiny paw icon
    HudCircle(btnX + 5, btnY + 6, 1.5, theme.accent, 255)
    HudCircle(btnX + 8, btnY + 4.5, 1.5, theme.accent, 255)
    HudCircle(btnX + 11, btnY + 6, 1.5, theme.accent, 255)
    HudCircle(btnX + 8, btnY + 10, 2.8, theme.accent, 255)
    -- rows
    local rowY = y + headerH
    for i = 1, #rows do
        local row = rows[i]
        if i % 2 == 1 then
            HudRect(x + 4, rowY, width - 8, rowH, theme.card, 95, 6)
        end
        -- Mode-colored notch keeps rows scannable at a glance.
        HudRect(x + 4, rowY + 6, 2, rowH - 12, row.color, 210, 1)
        local tileX = x + pad
        local tileY = rowY + math.floor((rowH - tile) / 2)
        HudRect(tileX, tileY, tile, tile, row.color, 45, 5)
        HudOutline(tileX, tileY, tile, tile, row.color, 130, 5)
        -- mini boar icon: body, head, snout, ear, legs, eye
        HudCircle(tileX + 8, tileY + 10, 4.2, row.color, 255)
        HudCircle(tileX + 12.5, tileY + 9, 2.9, row.color, 255)
        HudCircle(tileX + 15, tileY + 9.8, 1.5, row.color, 255)
        HudCircle(tileX + 11.6, tileY + 5.9, 1.4, row.color, 255)
        HudRect(tileX + 6, tileY + 13, 2, 3, row.color, 255, 1)
        HudRect(tileX + 10, tileY + 13, 2, 3, row.color, 255, 1)
        HudCircle(tileX + 13, tileY + 8.4, 0.8, theme.window, 255)
        local textY = rowY + math.floor((rowH - row.textH) / 2) - 1
        HudText(hudFont, 12, row.name, tileX + tile + 8, textY, theme.text, 255)
        HudText(hudFont, 12, row.right, x + width - pad - row.rightW, textY, theme.muted, 255)
        -- health micro-bar under the name
        local hbX = tileX + tile + 8
        local hbW = (x + width - pad - row.rightW - 8) - hbX
        if hbW > 10 then
            HudRect(hbX, rowY + rowH - 5, hbW, 2, theme.barBack, 150, 1)
            HudRect(hbX, rowY + rowH - 5, hbW * math.max(0, math.min(1, row.hp)), 2, GetHealthColor(theme, row.hp), 235, 1)
        end
        rowY = rowY + rowH
    end
end

function Callbacks.OnDraw()
    if not IsGameActive() then
        return
    end
    if not hudFont then
        local flag = Enum.FontCreate.FONTFLAG_ANTIALIAS or Enum.FontCreate.FONTFLAG_OUTLINE
        hudFont = Render.LoadFont("Verdana", flag, (Enum.FontWeight and Enum.FontWeight.MEDIUM) or 500)
        statusFont = Render.LoadFont("Arial", Enum.FontCreate.FONTFLAG_OUTLINE, (Enum.FontWeight and Enum.FontWeight.MEDIUM) or 500)
    end
    local now = GameRules.GetGameTime()
    local lang = GetHudLang()
    local theme = HUD_THEMES[1] -- NeverLose style
    razorbacks = PruneEntities(razorbacks)
    local enabled = ui.enable:Get()
    if enabled and ui.showStatus:Get() then
        DrawOverheadChips(theme, now, lang)
    end
    if enabled and ui.statusPanel:Get() then
        DrawStatusPanel(theme, now, lang)
    end
end

function Callbacks.OnGameEnd()
    ResetRuntime()
end

return Callbacks
