--[[
    Chen's Circus
    UCZone API v2.0 · https://uczone.gitbook.io/api-v2.0

    Point somewhere, press a key, and every creep you own puts on a show there.

      LINE   — they form up in a rank and spin on the spot, all in sync
      CIRCLE — a round dance: everyone chases the next one around the ring
      EIGHT  — single file along a figure of eight
      PULSE  — a flower breathing in and out around the point

    Two things keep the show from falling apart. The figure never turns faster
    than the slowest creep can walk, so nobody cuts the corner, and the troupe
    forms up standing still before the figure starts moving at all.

    What gets drawn is the slot list that was actually ordered, not a fresh one
    computed at draw time, so the overlay cannot disagree with the units.
]]

local VERSION = "1.0.0"
local script = {}

-- Small enough that a unit ordered around it stays in its slot, big enough that
-- it still bothers to turn towards each new order.
local SPIN_RADIUS = 60

-- However fast the creeps are, a rank spinning quicker than this is just noise.
local MAX_SPIN_OMEGA = 2.2

-- Gap between riders along the figure of eight, in curve parameter.
local EIGHT_LAG = 0.55

-- A creep this close to its slot counts as standing where it was told.
local FORM_TOLERANCE = 130
local FORM_TIMEOUT   = 5.0

local MODES = { "line", "circle", "eight", "pulse" }

local MODE_TITLE = {
    line   = "СТРОЙ",
    circle = "ХОРОВОД",
    eight  = "ВОСЬМЁРКА",
    pulse  = "ПУЛЬС",
}

----------------------------------------------------------------------
-- MENU
----------------------------------------------------------------------

local ui = {}

local DEFAULTS = {
    enabled  = true,
    spacing  = 140,
    radius   = 500,
    speed    = 65,
    interval = 200,
    draw     = true,
    leashes  = true,
}

local function opt(name)
    local widget = ui[name]
    if widget == nil then
        return DEFAULTS[name]
    end

    return widget:Get()
end

local function buildMenu()
    local tab = Menu.Create("Scripts", "Utility", "Chen Circus", "Main")
    if tab == nil or tab.Create == nil then
        return false
    end

    local mainGroup  = tab:Create("Основное", Enum.GroupSide.Left)
    local bindGroup  = tab:Create("Номера программы", Enum.GroupSide.Left)
    local shapeGroup = tab:Create("Геометрия", Enum.GroupSide.Right)

    if mainGroup == nil or mainGroup.Switch == nil then
        return false
    end

    ui.enabled = mainGroup:Switch("Включить", true, "\u{f0e7}")
    ui.enabled:ToolTip("Управляет всеми юнитами под твоим контролем, кроме самого героя, курьера и вардов.")

    ui.draw = mainGroup:Switch("Рисовать площадку", true, "\u{f06e}")
    ui.draw:ToolTip("Показывает фигуру и точки, куда юниты отправлены прямо сейчас.")

    ui.leashes = mainGroup:Switch("Поводки", true, "\u{f0c1}")
    ui.leashes:ToolTip("Линия от каждого юнита к его месту — сразу видно, кто отстаёт.")

    ui.stop = bindGroup:Bind("Отмена", Enum.ButtonCode.KEY_NONE, "\u{f04d}")
    ui.stop:ToolTip("Распускает труппу и останавливает юнитов на месте.")

    ui.line = bindGroup:Bind("Строй + вертушка", Enum.ButtonCode.KEY_NONE)
    ui.line:ToolTip("Встают в ровную линию под курсором и синхронно крутятся на месте.")

    ui.circle = bindGroup:Bind("Хоровод", Enum.ButtonCode.KEY_NONE)
    ui.circle:ToolTip("Бегают по кругу друг за другом.")

    ui.eight = bindGroup:Bind("Восьмёрка", Enum.ButtonCode.KEY_NONE)
    ui.eight:ToolTip("Паровозиком по траектории в виде восьмёрки.")

    ui.pulse = bindGroup:Bind("Пульс", Enum.ButtonCode.KEY_NONE)
    ui.pulse:ToolTip("Цветок: то разбегаются от точки, то сбегаются обратно.")

    ui.spacing = shapeGroup:Slider("Интервал в строю", 60, 400, 140, "%d")
    ui.spacing:ToolTip("Расстояние между соседями в линии.")

    ui.radius = shapeGroup:Slider("Радиус фигуры", 200, 1200, 500, "%d")
    ui.radius:ToolTip("Размер круга, восьмёрки и пульса.")

    ui.speed = shapeGroup:Slider("Скорость", 10, 100, 65, "%d%%")
    ui.speed:ToolTip("Доля от максимума, который вытягивает самый медленный юнит. На 100% он бежит на пределе и начинает срезать углы.")

    ui.interval = shapeGroup:Slider("Темп приказов", 80, 500, 200, "%d ms")
    ui.interval:ToolTip("Как часто раздаются приказы. Меньше — плавнее, но больше спама.")

    return true
end

----------------------------------------------------------------------
-- TROUPE
----------------------------------------------------------------------

local state = {
    mode = nil,
    point = nil,
    phase = 0,
    forming = false,
    formUntil = 0,
    nextOrder = 0,
    lastTime = 0,
    slots = nil,
    units = nil,
}

-- Everything you can order around that is not you and not the courier. Sorted by
-- entity index so a given creep keeps its own slot instead of swapping places
-- with its neighbour every tick.
local function troupe(hero, playerId)
    local units = {}

    for _, npc in pairs(NPCs.GetAll()) do
        if npc ~= hero
            and Entity.IsAlive(npc)
            and not Entity.IsDormant(npc)
            and not NPC.IsCourier(npc)
            and not NPC.IsWard(npc)
            and NPC.IsControllableByPlayer(npc, playerId)
        then
            units[#units + 1] = npc
        end
    end

    table.sort(units, function (left, right)
        return Entity.GetIndex(left) < Entity.GetIndex(right)
    end)

    return units
end

local function slowestSpeed(units)
    local slowest = nil

    for _, npc in ipairs(units) do
        local speed = NPC.GetMoveSpeed(npc)
        if speed ~= nil and speed > 0 and (slowest == nil or speed < slowest) then
            slowest = speed
        end
    end

    return slowest or 300
end

----------------------------------------------------------------------
-- FORMATIONS
----------------------------------------------------------------------

local function flat(point, x, y)
    return Vector(point.x + x, point.y + y, point.z)
end

-- Built by hand instead of Vector:Perpendicular2D, which the docs describe as
-- operating in place.
local function perpendicular(direction)
    return Vector(-direction.y, direction.x, 0):Normalized()
end

-- ctx carries everything a figure needs: the stage point, how many riders, how
-- big it is and which way the rank faces.
local function slotAt(mode, ctx, index, phase)
    local point, count = ctx.point, ctx.count

    if mode == "circle" then
        local angle = phase + (index - 1) * math.pi * 2 / count
        return flat(point, math.cos(angle) * ctx.radius, math.sin(angle) * ctx.radius)
    end

    if mode == "eight" then
        -- Lemniscate of Bernoulli: riders sit at fixed gaps along one curve, so
        -- they read as a train rather than as a ring.
        local t = phase - (index - 1) * EIGHT_LAG
        local sin, cos = math.sin(t), math.cos(t)
        local divisor = 1 + sin * sin
        return flat(point, ctx.radius * cos / divisor, ctx.radius * sin * cos / divisor)
    end

    if mode == "pulse" then
        local breath = 0.3 + 0.7 * (0.5 + 0.5 * math.sin(phase))
        local angle = (index - 1) * math.pi * 2 / count
        local reach = ctx.radius * breath
        return flat(point, math.cos(angle) * reach, math.sin(angle) * reach)
    end

    -- line: everyone holds their place in the rank and walks the same little
    -- circle around it, so the rank stays put while each unit keeps turning.
    local offset = (index - (count + 1) / 2) * ctx.spacing
    local spinX, spinY = math.cos(phase) * SPIN_RADIUS, math.sin(phase) * SPIN_RADIUS

    return flat(point, ctx.side.x * offset + spinX, ctx.side.y * offset + spinY)
end

local function buildSlots(mode, ctx, phase)
    local slots = {}

    for index = 1, ctx.count do
        slots[index] = slotAt(mode, ctx, index, phase)
    end

    return slots
end

local function makeContext(hero, point, count)
    local facing = Entity.GetAbsOrigin(hero):DirectionTo(point)

    return {
        point   = point,
        count   = count,
        radius  = opt("radius"),
        spacing = opt("spacing"),
        side    = perpendicular(facing),
    }
end

-- How fast the figure may turn without asking anybody to outrun their legs.
local function angularSpeed(mode, ctx, units)
    local share = opt("speed") / 100
    local travel = slowestSpeed(units) * share

    if mode == "line" then
        return math.min(travel / SPIN_RADIUS, MAX_SPIN_OMEGA)
    end

    if mode == "pulse" then
        -- The riders move along the radius here, not around it.
        return math.min(travel / math.max(ctx.radius, 1) * 1.6, 2.0)
    end

    -- The eight is shorter than the circle it fits in, so it may turn faster.
    local reach = mode == "eight" and ctx.radius * 0.75 or ctx.radius
    return travel / math.max(reach, 1)
end

----------------------------------------------------------------------
-- CONTROL
----------------------------------------------------------------------

-- Orders are addressed to each unit explicitly rather than to the current
-- selection, so the troupe performs whether or not it is selected.
local function orderMove(player, npc, position)
    Player.PrepareUnitOrders(
        player,
        Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION,
        nil,
        position,
        nil,
        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
        npc,
        false,
        false
    )
end

local function stopShow(player, units)
    state.mode = nil
    state.slots = nil
    state.units = nil

    for _, npc in ipairs(units or {}) do
        Player.HoldPosition(player, npc, false, false, false, "chen_circus_stop")
    end
end

local function startShow(mode)
    local point = Input.GetWorldCursorPos()
    if point == nil then
        return
    end

    state.mode  = mode
    state.point = point
    state.phase = 0
    state.slots = nil
    state.units = nil
    state.nextOrder = 0
    -- Stand still and let everyone walk in before the figure starts turning.
    state.forming = true
    state.formUntil = (GameRules.GetGameTime() or 0) + FORM_TIMEOUT
end

local function everybodyInPlace(units, slots)
    for index, npc in ipairs(units) do
        local slot = slots[index]
        if slot ~= nil and Entity.GetAbsOrigin(npc):Distance2D(slot) > FORM_TOLERANCE then
            return false
        end
    end

    return true
end

local function readBinds()
    if ui.stop ~= nil and ui.stop:IsPressed() then
        return "stop"
    end

    for _, mode in ipairs(MODES) do
        local bind = ui[mode]
        if bind ~= nil and bind:IsPressed() then
            return mode
        end
    end

    return nil
end

----------------------------------------------------------------------
-- CALLBACKS
----------------------------------------------------------------------

local font = nil

function script.OnScriptsLoaded()
    local ok, result = pcall(buildMenu)

    font = Render.LoadFont("MuseoSansEx", Enum.FontCreate.FONTFLAG_ANTIALIAS, 500)
        or Render.LoadFont("Tahoma", Enum.FontCreate.FONTFLAG_ANTIALIAS, 500)

    if ai_bridge ~= nil and ai_bridge.mcp_log ~= nil then
        ai_bridge.mcp_log("info", "chen_circus loaded", {
            menu_ready = ok and result == true,
            error = (not ok) and tostring(result) or nil,
        })
    end
end

function script.OnUpdate()
    if not opt("enabled") then
        state.mode = nil
        return
    end

    local hero   = Heroes.GetLocal()
    local player = Players.GetLocal()

    if hero == nil or player == nil or not Entity.IsAlive(hero) then
        state.mode = nil
        return
    end

    local playerId = Player.GetPlayerID(player)
    local pressed  = readBinds()

    if pressed == "stop" then
        stopShow(player, troupe(hero, playerId))
        return
    elseif pressed ~= nil then
        -- Pressing the key of the running number stops it, so one key both
        -- starts and ends its act.
        if state.mode == pressed then
            stopShow(player, troupe(hero, playerId))
        else
            startShow(pressed)
        end
        return
    end

    if state.mode == nil or state.point == nil then
        return
    end

    local now = GameRules.GetGameTime()
    if now < state.nextOrder then
        return
    end

    local interval = opt("interval") / 1000
    local elapsed = state.lastTime > 0 and math.min(1.0, now - state.lastTime) or interval
    state.lastTime = now
    state.nextOrder = now + interval

    local units = troupe(hero, playerId)
    if #units == 0 then
        return
    end

    local ctx = makeContext(hero, state.point, #units)
    local omega = angularSpeed(state.mode, ctx, units)

    if state.forming then
        local resting = buildSlots(state.mode, ctx, 0)

        if everybodyInPlace(units, resting) or now >= state.formUntil then
            state.forming = false
        end

        state.slots, state.units = resting, units

        for index, npc in ipairs(units) do
            orderMove(player, npc, resting[index])
        end

        return
    end

    state.phase = state.phase + omega * elapsed

    -- Aim one order ahead: by the time a creep gets there the figure has moved
    -- on by exactly that much, so it lands on the slot instead of trailing it.
    local slots = buildSlots(state.mode, ctx, state.phase + omega * interval)
    state.slots, state.units = slots, units

    for index, npc in ipairs(units) do
        orderMove(player, npc, slots[index])
    end
end

----------------------------------------------------------------------
-- DRAWING
----------------------------------------------------------------------

local function worldLine(from, to, color, thickness)
    local a, aVisible = Render.WorldToScreen(from)
    local b, bVisible = Render.WorldToScreen(to)

    if aVisible and bVisible then
        Render.Line(a, b, color, thickness or 1.4)
    end
end

-- The stage itself: the curve the riders are travelling along.
local function drawPath(mode, ctx, phase, color)
    if mode == "line" then
        local half = (ctx.count - 1) / 2 * ctx.spacing
        worldLine(
            flat(ctx.point, -ctx.side.x * half, -ctx.side.y * half),
            flat(ctx.point, ctx.side.x * half, ctx.side.y * half),
            color,
            1.6
        )
        return
    end

    local samples = 64
    local previous = nil

    for index = 0, samples do
        local point

        if mode == "eight" then
            local t = index * math.pi * 2 / samples
            local sin, cos = math.sin(t), math.cos(t)
            local divisor = 1 + sin * sin
            point = flat(ctx.point, ctx.radius * cos / divisor, ctx.radius * sin * cos / divisor)
        else
            local reach = ctx.radius
            if mode == "pulse" then
                reach = reach * (0.3 + 0.7 * (0.5 + 0.5 * math.sin(phase)))
            end

            local angle = index * math.pi * 2 / samples
            point = flat(ctx.point, math.cos(angle) * reach, math.sin(angle) * reach)
        end

        if previous ~= nil then
            worldLine(previous, point, color, 1.4)
        end

        previous = point
    end
end

function script.OnDraw()
    if font == nil
        or not opt("enabled")
        or not opt("draw")
        or state.mode == nil
        or state.point == nil
        or state.slots == nil
    then
        return
    end

    local hero = Heroes.GetLocal()
    if hero == nil then
        return
    end

    local accent = state.forming and Color(130, 200, 255, 225) or Color(255, 190, 70, 235)
    local marker = Color(120, 220, 255, 235)
    local leash  = Color(255, 255, 255, 90)

    local ctx = makeContext(hero, state.point, #state.slots)
    drawPath(state.mode, ctx, state.phase, Color(accent.r, accent.g, accent.b, 120))

    -- These are the exact positions the units were ordered to, so the overlay
    -- and the show can never drift apart.
    for index, slot in ipairs(state.slots) do
        local screen, visible = Render.WorldToScreen(slot)
        if visible then
            Render.FilledCircle(screen, 4, marker)
        end

        local npc = state.units and state.units[index]
        if opt("leashes") and npc ~= nil and Entity.IsAlive(npc) then
            worldLine(Entity.GetAbsOrigin(npc), slot, leash, 1)
        end
    end

    local label = string.format(
        "%s · %d%s",
        MODE_TITLE[state.mode] or "?",
        #state.slots,
        state.forming and " · строятся" or ""
    )
    local screen, visible = Render.WorldToScreen(state.point + Vector(0, 0, 160))

    if visible then
        Render.Text(font, 15, label, Vec2(screen.x + 1, screen.y + 1), Color(0, 0, 0, 200))
        Render.Text(font, 15, label, screen, accent)
    end
end

return script
