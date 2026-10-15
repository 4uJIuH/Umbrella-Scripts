---@diagnostic disable: undefined-global

-- Подсказка направления для Blink после возрождения от Aegis и опциональный
-- Blink по мировой позиции курсора, пока назначенная клавиша удерживается.
-- Во время смерти приказы разрешены только в коротком окне перед Aegis-respawn.

local AegisBlinkoutCone = {}

local MENU_TITLE = "Конус блинка после Aegis"
local MENU_ICON = "\u{f0e7}"
local AEGIS_ITEM_NAME = "item_aegis"
local TEMPEST_DOUBLE_MODIFIER = "modifier_arc_warden_tempest_double"
local DRAW_Z_OFFSET = 20
local ARC_SEGMENTS = 24
local OUTLINE_THICKNESS = 2.0
local AEGIS_RESPAWN_FALLBACK = 5.0
local PRE_RESPAWN_SPAM_INTERVAL = 0.10
local ALIVE_SPAM_RETRY_INTERVAL = 0.20
local PRE_RESPAWN_LATE_GRACE = 0.50
local TIME_EPSILON = 0.0001
local SPAM_ORDER_IDENTIFIER = "aegis_blink_cursor_spam"

local BLINK_ITEMS = {
    "item_blink",
    "item_overwhelming_blink",
    "item_swift_blink",
    "item_arcane_blink",
}

local function safeCall(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end

    local ok, a, b, c = pcall(fn, ...)
    if ok then
        return a, b, c
    end

    return nil
end

local function enumValue(groupName, valueName, fallback)
    local group = Enum and Enum[groupName]
    if group and group[valueName] ~= nil then
        return group[valueName]
    end

    return fallback
end

local function makeColor(r, g, b, a)
    if type(Color) == "function" then
        local color = safeCall(Color, r, g, b, a)
        if color then
            return color
        end
    end

    return { r = r, g = g, b = b, a = a }
end

local DEFAULT_BORDER_COLOR = makeColor(85, 190, 255, 235)
local NO_BIND_KEY = enumValue(
    "ButtonCode",
    "KEY_NONE",
    enumValue("ButtonCode", "BUTTON_CODE_NONE", enumValue("ButtonCode", "BUTTON_CODE_INVALID", -1))
)

local menuTab = Menu.Create("General", "Main", MENU_TITLE)
menuTab:Icon(MENU_ICON)
local menuGroup = menuTab:Create("Настройки"):Create("Общее")

local ui = {
    enabled = menuGroup:Switch("Включить", true),
    coneAngle = menuGroup:Slider("Угол конуса", 5.0, 90.0, 22.5, "%.1f°"),
    postRespawnTime = menuGroup:Slider("Показывать после возрождения", 0.0, 3.0, 0.75, "%.2f с"),
    useBlinkRange = menuGroup:Switch("Использовать дальность Blink", true),
    fallbackRange = menuGroup:Slider("Резервная дальность", 100, 2000, 1200, "%d"),
    onlyWithBlink = menuGroup:Switch("Только при наличии Blink", true),
    showCenterLine = menuGroup:Switch("Показывать центральную линию", true),
    showBorders = menuGroup:Switch("Показывать границы", true),
    borderColor = menuGroup:ColorPicker("Цвет границ", DEFAULT_BORDER_COLOR),
    spamBlink = menuGroup:Switch("Спам блинком по курсору", true),
    preRespawnSpamTime = menuGroup:Slider("Начинать спам до возрождения", 0.0, 1.0, 0.30, "%.2f с"),
    spamBlinkBind = menuGroup:Bind("Клавиша спама Blink", NO_BIND_KEY),
}

safeCall(
    ui.coneAngle and ui.coneAngle.ToolTip,
    ui.coneAngle,
    "Угол задаётся как полная ширина конуса: 22.5° означает ±11.25° от направления героя."
)
safeCall(
    ui.spamBlinkBind and ui.spamBlinkBind.ToolTip,
    ui.spamBlinkBind,
    "Можно зажать заранее: спам начнётся за настроенное время до Aegis-respawn и продолжится после возрождения."
)
safeCall(ui.spamBlinkBind and ui.spamBlinkBind.Unsafe, ui.spamBlinkBind, true)
safeCall(
    ui.spamBlinkBind and ui.spamBlinkBind.Properties,
    ui.spamBlinkBind,
    "Спам Blink по курсору",
    "удержание",
    false
)
safeCall(ui.spamBlinkBind and ui.spamBlinkBind.ShowInBindIsland, ui.spamBlinkBind, true)
safeCall(ui.spamBlinkBind and ui.spamBlinkBind.MouseBinding, ui.spamBlinkBind, true)

local state = {
    hero = nil,
    wasAlive = nil,
    lastAliveSnapshot = nil,
    cone = nil,
    aegisRespawn = nil,
    lastSpamAt = -math.huge,
}

local function widgetValue(widget, fallback)
    if widget and type(widget.Get) == "function" then
        local value = safeCall(widget.Get, widget)
        if value ~= nil then
            return value
        end
    end

    return fallback
end

local function isFinite(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function vectorComponents(vector)
    if not vector then
        return nil, nil, nil
    end

    local x, y, z

    if type(vector.Get) == "function" then
        x, y, z = safeCall(vector.Get, vector)
    end

    if isFinite(vector.x) then x = vector.x end
    if isFinite(vector.y) then y = vector.y end
    if isFinite(vector.z) then z = vector.z end

    if not isFinite(x) and type(vector.GetX) == "function" then
        x = safeCall(vector.GetX, vector)
    end

    if not isFinite(y) and type(vector.GetY) == "function" then
        y = safeCall(vector.GetY, vector)
    end

    if not isFinite(z) and type(vector.GetZ) == "function" then
        z = safeCall(vector.GetZ, vector)
    end

    return x, y, z
end

local function makeVector(x, y, z)
    if not isFinite(x) or not isFinite(y) or not isFinite(z) then
        return nil
    end

    if type(Vector) == "function" then
        local vector = safeCall(Vector, x, y, z)
        if vector then
            return vector
        end
    end

    return { x = x, y = y, z = z }
end

local function copyVector(vector)
    local x, y, z = vectorComponents(vector)
    if not isFinite(x) or not isFinite(y) or not isFinite(z) then
        return nil
    end

    return makeVector(x, y, z)
end

local function setVectorZ(vector, z)
    if not vector or not isFinite(z) then
        return false
    end

    if type(vector.SetZ) == "function" then
        safeCall(vector.SetZ, vector, z)
        return true
    end

    vector.z = z
    return true
end

local function groundPosition(vector, fallbackZ)
    local grounded = copyVector(vector)
    if not grounded then
        return nil
    end

    if type(grounded.SetGroundZ) == "function" then
        safeCall(grounded.SetGroundZ, grounded)
    end

    local _, _, z = vectorComponents(grounded)
    if not isFinite(z) then
        z = fallbackZ
    end

    if not isFinite(z) then
        return nil
    end

    setVectorZ(grounded, z + DRAW_Z_OFFSET)
    return grounded
end

local function normalize2D(vector)
    local x, y = vectorComponents(vector)
    if not isFinite(x) or not isFinite(y) then
        return nil
    end

    local length = math.sqrt(x * x + y * y)
    if length <= 0.001 then
        return nil
    end

    return { x = x / length, y = y / length }
end

local function heroForward(hero)
    local rotation = safeCall(Entity and Entity.GetRotation, hero)
    if rotation and type(rotation.GetForward) == "function" then
        local direction = normalize2D(safeCall(rotation.GetForward, rotation))
        if direction then
            return direction
        end
    end

    local direction = normalize2D(safeCall(NPC and NPC.GetForwardVector, hero))
    if direction then
        return direction
    end

    return nil
end

local function rotateDirection(direction, degrees)
    local radians = math.rad(degrees)
    local cosine = math.cos(radians)
    local sine = math.sin(radians)

    return {
        x = direction.x * cosine - direction.y * sine,
        y = direction.x * sine + direction.y * cosine,
    }
end

local function gameTime()
    local time = safeCall(GameRules and GameRules.GetGameTime)
    if isFinite(time) then
        return time
    end

    time = safeCall(GlobalVars and GlobalVars.GetCurTime)
    if isFinite(time) then
        return time
    end

    return os.clock()
end

local function isInGame()
    return safeCall(Engine and Engine.IsInGame) == true
end

local function isValidLocalHero(hero)
    if not hero then
        return false
    end

    if safeCall(Entity and Entity.IsEntity, hero) == false then
        return false
    end

    if safeCall(Entity and Entity.IsNPC, hero) == false then
        return false
    end

    if safeCall(Entity and Entity.IsHero, hero) == false then
        return false
    end

    if safeCall(NPC and NPC.IsIllusion, hero) == true then
        return false
    end

    if safeCall(NPC and NPC.HasModifier, hero, TEMPEST_DOUBLE_MODIFIER) == true then
        return false
    end

    return true
end

local function findItem(hero, itemNames)
    for _, itemName in ipairs(itemNames) do
        local item = safeCall(NPC and NPC.GetItem, hero, itemName, true)
        if item then
            return item, itemName
        end
    end

    return nil, nil
end

local function resetSpamThrottle()
    state.lastSpamAt = -math.huge
end

local function spamBindIsDown()
    return safeCall(
        ui.spamBlinkBind and ui.spamBlinkBind.IsDown,
        ui.spamBlinkBind
    ) == true
end

local function configuredPreRespawnSpamTime()
    local duration = widgetValue(ui.preRespawnSpamTime, 0.30)
    if not isFinite(duration) then
        return 0.30
    end

    return math.max(0.0, math.min(1.0, duration))
end

local function isInsidePreRespawnSpamWindow(now)
    local respawn = state.aegisRespawn
    if not respawn or not isFinite(respawn.expectedAt) then
        return false
    end

    local startsAt = respawn.expectedAt - configuredPreRespawnSpamTime()
    local endsAt = respawn.expectedAt + PRE_RESPAWN_LATE_GRACE
    return now >= startsAt and now <= endsAt
end

local function trySpamBlinkAtCursor(hero, alive, now, justRespawned)
    if not widgetValue(ui.spamBlink, true) or not spamBindIsDown() then
        resetSpamThrottle()
        return
    end

    local isPreRespawnAttempt = not alive and isInsidePreRespawnSpamWindow(now)
    if not alive and not isPreRespawnAttempt then
        resetSpamThrottle()
        return
    end

    -- Предвозрожденческие попытки не должны задержать первый настоящий живой
    -- приказ: на переходе dead -> alive throttle принудительно сбрасывается.
    if justRespawned then
        resetSpamThrottle()
    end

    local retryInterval = isPreRespawnAttempt
        and PRE_RESPAWN_SPAM_INTERVAL
        or ALIVE_SPAM_RETRY_INTERVAL
    if now - state.lastSpamAt < retryInterval - TIME_EPSILON then
        return
    end

    local blink = findItem(hero, BLINK_ITEMS)
    if not blink then
        return
    end

    -- Для мёртвого героя IsCastable ожидаемо false, поэтому в коротком окне до
    -- Aegis-respawn отправляем прямую попытку. После возрождения снова строго
    -- проверяем готовность и не создаём бесполезных живых приказов.
    if alive then
        local isReady = safeCall(Ability and Ability.IsReady, blink)
        if isReady == false then
            return
        end

        local isCastable = safeCall(Ability and Ability.IsCastable, blink)
        if isCastable == false then
            return
        end
    end

    local cursorPosition = copyVector(safeCall(Humanizer and Humanizer.GetServerCursorPos))
    if not cursorPosition then
        return
    end

    if type(Ability and Ability.CastPosition) ~= "function" then
        return
    end

    state.lastSpamAt = now

    -- Прямой cast без Dota-очереди и без OnPrepareUnitOrders. До возрождения
    -- получится максимум несколько попыток внутри короткого ограниченного окна,
    -- поэтому прежнего многосекундного backlog здесь не возникает.
    safeCall(
        Ability.CastPosition,
        blink,
        cursorPosition,
        false, -- queue
        false, -- push to OnPrepareUnitOrders
        true,  -- execute_fast
        SPAM_ORDER_IDENTIFIER,
        false  -- force_minimap
    )
end

local function findAegis(hero)
    return safeCall(NPC and NPC.GetItem, hero, AEGIS_ITEM_NAME, true)
end

local function readAegisRespawnDuration(aegis)
    if not aegis then
        return AEGIS_RESPAWN_FALLBACK
    end

    local duration = safeCall(
        Ability and Ability.GetLevelSpecialValueFor,
        aegis,
        "reincarnate_time",
        -1
    )
    if not isFinite(duration) or duration <= 0 then
        duration = safeCall(
            Ability and Ability.GetLevelSpecialValueFor,
            aegis,
            "reincarnate_time"
        )
    end

    if isFinite(duration) and duration > 0 and duration <= 15 then
        return duration
    end

    return AEGIS_RESPAWN_FALLBACK
end

local function readBlinkRange(hero, blink, fallbackRange)
    fallbackRange = isFinite(fallbackRange) and fallbackRange > 0 and fallbackRange or 1200
    if not blink then
        return fallbackRange
    end

    local range = safeCall(Ability and Ability.GetCastRange, blink)
    if not isFinite(range) or range <= 0 then
        range = safeCall(Ability and Ability.GetLevelSpecialValueFor, blink, "blink_range", -1)
    end

    if not isFinite(range) or range <= 0 then
        range = safeCall(Ability and Ability.GetLevelSpecialValueFor, blink, "blink_range")
    end

    if not isFinite(range) or range <= 0 then
        range = fallbackRange
    end

    local bonus = safeCall(NPC and NPC.GetCastRangeBonus, hero)
    if isFinite(bonus) then
        range = range + bonus
    end

    return range > 0 and range or fallbackRange
end

local function configuredFallbackRange()
    local range = widgetValue(ui.fallbackRange, 1200)
    if isFinite(range) and range > 0 then
        return range
    end

    return 1200
end

local function captureAliveSnapshot(hero)
    local oldSnapshot = state.lastAliveSnapshot or {}
    local position = groundPosition(safeCall(Entity and Entity.GetAbsOrigin, hero))
    local direction = heroForward(hero)
    local blink, blinkName = findItem(hero, BLINK_ITEMS)
    local aegis = findAegis(hero)
    local fallbackRange = configuredFallbackRange()
    local range = fallbackRange

    if widgetValue(ui.useBlinkRange, true) and blink then
        range = readBlinkRange(hero, blink, fallbackRange) or fallbackRange
    end

    state.lastAliveSnapshot = {
        -- Сохраняем последние валидные геометрические данные: API может вернуть
        -- nil непосредственно перед тем, как IsAlive переключится в false.
        position = position or oldSnapshot.position,
        direction = direction or oldSnapshot.direction,
        hadAegis = aegis ~= nil,
        aegisRespawnDuration = readAegisRespawnDuration(aegis),
        hadBlink = blink ~= nil,
        blinkName = blinkName,
        range = range,
    }
end

local function clearTracking()
    state.hero = nil
    state.wasAlive = nil
    state.lastAliveSnapshot = nil
    state.cone = nil
    state.aegisRespawn = nil
    resetSpamThrottle()
end

local function activateConeFromLastSnapshot(now)
    local snapshot = state.lastAliveSnapshot
    state.aegisRespawn = nil

    if not snapshot or snapshot.hadAegis ~= true then
        state.cone = nil
        return
    end

    local respawnDuration = snapshot.aegisRespawnDuration
    if not isFinite(respawnDuration) or respawnDuration <= 0 then
        respawnDuration = AEGIS_RESPAWN_FALLBACK
    end

    state.aegisRespawn = {
        deathAt = now,
        expectedAt = now + respawnDuration,
    }

    if widgetValue(ui.onlyWithBlink, true) and snapshot.hadBlink ~= true then
        state.cone = nil
        return
    end

    if not snapshot.position or not snapshot.direction then
        state.cone = nil
        return
    end

    local range = snapshot.range
    if not isFinite(range) or range <= 0 then
        range = configuredFallbackRange()
    end

    state.cone = {
        position = copyVector(snapshot.position),
        direction = { x = snapshot.direction.x, y = snapshot.direction.y },
        range = range,
        waitingForRespawn = true,
        expiresAt = nil,
    }
end

local function updateConeLifetime(now, alive)
    local cone = state.cone
    if not cone then
        return
    end

    if alive and cone.waitingForRespawn then
        local duration = widgetValue(ui.postRespawnTime, 0.75)
        if not isFinite(duration) or duration < 0 then
            duration = 0.75
        end

        cone.waitingForRespawn = false
        cone.expiresAt = now + duration
    end

    if not cone.waitingForRespawn
        and isFinite(cone.expiresAt)
        and now >= cone.expiresAt
    then
        state.cone = nil
    end
end

local function pointAt(origin, direction, distance)
    local originX, originY, originZ = vectorComponents(origin)
    if not isFinite(originX) or not isFinite(originY) or not isFinite(originZ) then
        return nil
    end

    local point = makeVector(
        originX + direction.x * distance,
        originY + direction.y * distance,
        originZ - DRAW_Z_OFFSET
    )

    return groundPosition(point, originZ - DRAW_Z_OFFSET)
end

local function projectWorld(position)
    if not position then
        return nil
    end

    if Render and type(Render.WorldToScreen) == "function" then
        local screen, visible = safeCall(Render.WorldToScreen, position)
        local x, y = vectorComponents(screen)
        if isFinite(x) and isFinite(y) then
            return { x = x, y = y, visible = visible ~= false }
        end
    end

    if type(position.ToScreen) == "function" then
        local screen, visible = safeCall(position.ToScreen, position)
        local x, y = vectorComponents(screen)
        if isFinite(x) and isFinite(y) then
            return { x = x, y = y, visible = visible ~= false }
        end
    end

    return nil
end

local function toVec2(point)
    if type(Vec2) == "function" then
        return safeCall(Vec2, point.x, point.y)
    end

    return point
end

local function drawScreenLine(from, to, color, thickness)
    if not from or not to or (from.visible == false and to.visible == false) then
        return
    end

    if Render and type(Render.Line) == "function" then
        local fromVec = toVec2(from)
        local toVec = toVec2(to)
        if fromVec and toVec then
            safeCall(Render.Line, fromVec, toVec, color, thickness)
            return
        end
    end

    if Renderer
        and type(Renderer.SetDrawColor) == "function"
        and type(Renderer.DrawLine) == "function"
    then
        local r = color.r or 255
        local g = color.g or 255
        local b = color.b or 255
        local a = color.a or 255
        safeCall(Renderer.SetDrawColor, r, g, b, a)
        safeCall(
            Renderer.DrawLine,
            math.floor(from.x + 0.5),
            math.floor(from.y + 0.5),
            math.floor(to.x + 0.5),
            math.floor(to.y + 0.5)
        )
    end
end

local function drawWorldLine(from, to, color, thickness)
    drawScreenLine(projectWorld(from), projectWorld(to), color, thickness)
end

local function buildArcPoints(cone, halfAngle)
    local points = {}
    for index = 0, ARC_SEGMENTS do
        local fraction = index / ARC_SEGMENTS
        local degrees = -halfAngle + (halfAngle * 2 * fraction)
        local direction = rotateDirection(cone.direction, degrees)
        local point = pointAt(cone.position, direction, cone.range)
        if not point then
            return nil
        end
        points[#points + 1] = point
    end

    return points
end

local function drawCone(cone)
    if not cone or not cone.position or not cone.direction then
        return
    end

    -- Значение меню — полная ширина. Возвращаем исходную геометрию: 22.5°
    -- строит границы на -11.25° и +11.25°.
    local fullAngle = widgetValue(ui.coneAngle, 22.5)
    if not isFinite(fullAngle) or fullAngle <= 0 then
        fullAngle = 22.5
    end

    local arcPoints = buildArcPoints(cone, fullAngle * 0.5)
    if not arcPoints or #arcPoints < 2 then
        return
    end

    local borderColor = widgetValue(ui.borderColor, DEFAULT_BORDER_COLOR)

    if widgetValue(ui.showBorders, true) then
        drawWorldLine(cone.position, arcPoints[1], borderColor, OUTLINE_THICKNESS)
        drawWorldLine(cone.position, arcPoints[#arcPoints], borderColor, OUTLINE_THICKNESS)

        for index = 1, #arcPoints - 1 do
            drawWorldLine(arcPoints[index], arcPoints[index + 1], borderColor, OUTLINE_THICKNESS)
        end
    end

    if widgetValue(ui.showCenterLine, true) then
        local centerEnd = pointAt(cone.position, cone.direction, cone.range)
        if centerEnd then
            drawWorldLine(cone.position, centerEnd, borderColor, OUTLINE_THICKNESS)
        end
    end
end

function AegisBlinkoutCone.OnUpdate()
    if not widgetValue(ui.enabled, true) or not isInGame() then
        clearTracking()
        return
    end

    local hero = safeCall(Heroes and Heroes.GetLocal)
    if not isValidLocalHero(hero) then
        -- Во время сетевого перехода герой может на один кадр стать недоступен.
        -- Не стираем последний живой снимок: когда тот же handle снова появится
        -- уже мёртвым, переход жив -> мёртв всё ещё будет корректно замечен.
        return
    end

    if state.hero ~= hero then
        clearTracking()
        state.hero = hero
    end

    local alive = safeCall(Entity and Entity.IsAlive, hero) == true
    local now = gameTime()

    if state.wasAlive == nil then
        state.wasAlive = alive
        if alive then
            captureAliveSnapshot(hero)
        end
        trySpamBlinkAtCursor(hero, alive, now, false)
        return
    end

    local justDied = not alive and state.wasAlive == true
    local justRespawned = alive and state.wasAlive == false

    -- Сначала фиксируем Aegis-смерть и ожидаемый момент возрождения, затем уже
    -- проверяем, вошли ли мы в предвозрожденческое окно спама.
    if justDied then
        activateConeFromLastSnapshot(now)
    end

    trySpamBlinkAtCursor(hero, alive, now, justRespawned)

    if alive then
        updateConeLifetime(now, true)
        captureAliveSnapshot(hero)
        if justRespawned then
            state.aegisRespawn = nil
        end
    end

    state.wasAlive = alive
    updateConeLifetime(now, alive)
end

function AegisBlinkoutCone.OnDraw()
    if not widgetValue(ui.enabled, true) or not isInGame() then
        return
    end

    local cone = state.cone
    if not cone then
        return
    end

    updateConeLifetime(gameTime(), false)
    drawCone(state.cone)
end

function AegisBlinkoutCone.OnGameEnd()
    clearTracking()
end

return AegisBlinkoutCone
