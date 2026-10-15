---@diagnostic disable: undefined-global
local script = {}

local ZONE = 190
local CATCHUP = 320
local CHASE_RATE = 2
local PATIENCE = 1.5
local SWEEP = 85
local PERIOD = 0.8
local RADIUS = 700
local RATE = 12
local FORGIVE = 120
local TIDY = 600
local WAITGAP = 220
local DRIFT_STEP = 200
local CLEARANCE = 130
local PLANTED = 45
local SPOT_RANGE = 4000

local SPOTS = {
    { -3592, -2807, 128 },
    { -6297, -624, 128 },
    { -2307, -6181, 128 },
    { 1609, 5823, 128 },
    { 6209, 1305, 128 },
    { 3175, 2321, 128 },
}

Menu.Create("Creeps", "Main", "Creep Block"):Icon("\u{f0c0}")
local group = Menu.Create("Creeps", "Main", "Creep Block", "Main", "Блок крипов")
local bind = group:Bind("Блок (удержание)", Enum.ButtonCode.KEY_G)
local use_hero = group:Switch("Герой", true, "\u{f007}")
local use_summons = group:Switch("Саммоны", true, "\u{f6d3}")
local use_illusions = group:Switch("Иллюзии и клоны", true, "\u{f0c5}")
local mark = group:Bind("Запомнить точку", Enum.ButtonCode.KEY_H)
local walk_to = group:Switch("Идти к точке", true, "\u{f3c5}")
local show_spot = group:Switch("Рисовать точку", true, "\u{f03e}")
local unmark = group:Bind("Удалить ближайшую точку", Enum.ButtonCode.KEY_J)
group:Button("Стереть все точки", function()
    Config.WriteInt("creep_block", "count", 0)
end)

for _, name in ipairs({ "Точка перед крипом", "Забег вперёд, если сзади", "Приказов в секунду при забеге",
    "Догонять, если успею за, 0.1с", "Размах качания", "Подработка вбок", "Период прохода, 0.1с",
    "Радиус поиска крипов", "Приказов в секунду", "Прощать проскочивших дальше", "Ждать, пока строй шире",
    "Держать зазор при ожидании", "Шаг отхода при ожидании", "Обход строя сбоку", "Напор к крипам",
    "Вставать намертво ближе", "Качание внутри строя", "Ширина прохода вбок", "Зазор во время ожидания",
    "Самообучение", "Показывать обучение", "Сбросить обучение" }) do
    local old = Menu.Find("General", "Main", "Creep Block", "Main", "Блок крипов", name)
    local moved = Menu.Find("Creeps", "Main", "Creep Block", "Main", "Блок крипов", name)
    if moved then moved:Visible(false) end
    if old then old:Visible(false) end
end

local ONLY_UNIT = Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY
local ORDER_MOVE = Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION
local ORDER_HOLD = Enum.UnitOrder.DOTA_UNIT_ORDER_HOLD_POSITION
local ORDER_STOP = Enum.UnitOrder.DOTA_UNIT_ORDER_STOP

local next_order, last_sent, owned = {}, {}, {}
local RESEND = 60

local function order_move(player, unit, key, pos)
    local seen = last_sent[key]
    if seen and seen.mode == "move" and seen.pos:Distance2D(pos) < RESEND then return end
    last_sent[key] = { mode = "move", pos = pos }
    Player.PrepareUnitOrders(player, ORDER_MOVE, nil, pos, nil,
        ONLY_UNIT, unit, false, false, false, true)
end

local function order_hold(player, unit, key)
    local seen = last_sent[key]
    if seen and seen.mode == "hold" then return end
    last_sent[key] = { mode = "hold", pos = Entity.GetAbsOrigin(unit) }
    Player.PrepareUnitOrders(player, ORDER_HOLD, nil, Entity.GetAbsOrigin(unit), nil,
        ONLY_UNIT, unit, false, false, false, true)
end
local spot_font

local function shipped_spot(origin)
    local best, near = nil, SPOT_RANGE
    for _, s in ipairs(SPOTS) do
        local point = Vector(s[1], s[2], s[3])
        local distance = origin:Distance2D(point)
        if distance < near then best, near = point, distance end
    end
    return best
end

local function saved_points()
    local list = {}
    for index = 1, Config.ReadInt("creep_block", "count", 0) do
        list[#list + 1] = Vector(
            Config.ReadInt("creep_block", "px" .. index, 0),
            Config.ReadInt("creep_block", "py" .. index, 0),
            Config.ReadInt("creep_block", "pz" .. index, 0))
    end
    return list
end

local function write_points(list)
    Config.WriteInt("creep_block", "count", #list)
    for index, point in ipairs(list) do
        Config.WriteInt("creep_block", "px" .. index, math.floor(point.x))
        Config.WriteInt("creep_block", "py" .. index, math.floor(point.y))
        Config.WriteInt("creep_block", "pz" .. index, math.floor(point.z))
    end
end

local function add_point(pos)
    local list = saved_points()
    list[#list + 1] = pos
    write_points(list)
end

local function drop_nearest(pos)
    local list = saved_points()
    local best, near = nil, 400
    for index, point in ipairs(list) do
        local distance = pos:Distance2D(point)
        if distance < near then best, near = index, distance end
    end
    if not best then return end
    table.remove(list, best)
    write_points(list)
end

local function active_spot(origin)
    local best, near = nil, SPOT_RANGE
    for _, point in ipairs(saved_points()) do
        local distance = origin:Distance2D(point)
        if distance < near then best, near = point, distance end
    end
    if best then return best end
    return shipped_spot(origin)
end

local function blocker_allowed(unit)
    if NPC.IsCourier(unit) then return false end
    if NPC.IsIllusion(unit) or NPC.IsMeepoClone(unit) then return use_illusions:Get() end
    if NPC.IsHero(unit) then return use_hero:Get() end
    return use_summons:Get()
end

local function wave(origin, team)
    local found, nearest, best = {}, nil, RADIUS
    for _, npc in pairs(NPCs.GetAll()) do
        if NPC.IsLaneCreep(npc)
            and Entity.GetTeamNum(npc) == team
            and Entity.IsAlive(npc)
            and not Entity.IsDormant(npc)
        then
            local distance = origin:Distance2D(Entity.GetAbsOrigin(npc))
            if distance < RADIUS then
                found[#found + 1] = npc
                if distance < best then nearest, best = npc, distance end
            end
        end
    end
    return found, nearest
end

local function forward_of(creep)
    local spot = Entity.GetAbsOrigin(creep)
    local delta = Entity.GetForwardPosition(creep, 100) - spot
    if delta:Length2D() < 1 then return nil end
    return delta:Normalized()
end

local function pick_target(creeps, forward, unit_proj, my_speed)
    local behind, behind_proj = nil, -math.huge
    local ahead_best, ahead_proj = nil, math.huge
    for _, npc in ipairs(creeps) do
        local spot = Entity.GetAbsOrigin(npc)
        local proj = spot.x * forward.x + spot.y * forward.y
        if proj <= unit_proj + FORGIVE then
            if proj > behind_proj then behind, behind_proj = npc, proj end
        elseif proj < ahead_proj then
            ahead_best, ahead_proj = npc, proj
        end
    end

    if not behind then
        if not ahead_best then return nil, "idle", 0, 0 end
        local margin = my_speed - (NPC.GetMoveSpeed(ahead_best) or 325)
        if margin < 15 then return nil, "idle", 0, 0 end
        if (ahead_proj - unit_proj) / margin > PATIENCE then return nil, "idle", 0, 0 end
        return ahead_best, "chase", 0, 0
    end

    local anchor = Entity.GetAbsOrigin(behind)
    local anchor_side = -anchor.x * forward.y + anchor.y * forward.x
    local low, high, count = math.huge, -math.huge, 0
    for _, npc in ipairs(creeps) do
        local spot = Entity.GetAbsOrigin(npc)
        local proj = spot.x * forward.x + spot.y * forward.y
        if proj > behind_proj - 400 and proj <= unit_proj + FORGIVE then
            local side = -spot.x * forward.y + spot.y * forward.x - anchor_side
            if side < low then low = side end
            if side > high then high = side end
            count = count + 1
        end
    end
    if count == 0 then return behind, "block", 0, 0 end

    local width = high - low
    if width > TIDY then
        return behind, "wait", (low + high) / 2, width / 2
    end
    return behind, "block", (low + high) / 2, width / 2
end

function script.OnUpdate()
    if mark:IsPressed() then
        local me = Heroes.GetLocal()
        if me then add_point(Entity.GetAbsOrigin(me)) end
    end
    if unmark:IsPressed() then
        local me = Heroes.GetLocal()
        if me then drop_nearest(Entity.GetAbsOrigin(me)) end
    end

    if not bind:IsDown() then
        if next(owned) then
            local player = Players.GetLocal()
            for _, unit in pairs(owned) do
                if player and Entity.IsAlive(unit) and not Entity.IsDormant(unit) then
                    Player.PrepareUnitOrders(player, ORDER_STOP, nil, Entity.GetAbsOrigin(unit),
                        nil, ONLY_UNIT, unit, false, false, false, true)
                end
            end
            owned = {}
        end
        next_order, last_sent = {}, {}
        return
    end

    local player = Players.GetLocal()
    local hero = Heroes.GetLocal()
    if not player or not hero then return end

    local team = Entity.GetTeamNum(hero)
    local now = GlobalVars.GetCurTime()
    local gap = 1 / RATE
    local chase_gap = 1 / CHASE_RATE
    local wave_offset = math.sin(now * 2 * math.pi / PERIOD)

    for _, unit in pairs(Player.GetSelectedUnits(player) or {}) do
        if Entity.IsAlive(unit) and not Entity.IsDormant(unit) and blocker_allowed(unit) then
            local key = Entity.GetIndex(unit)
            if not next_order[key] or now >= next_order[key] then
                local origin = Entity.GetAbsOrigin(unit)
                local creeps, nearest = wave(origin, team)
                local point = walk_to:Get() and active_spot(origin) or nil
                if not nearest and point then
                    if origin:Distance2D(point) > 60 then
                        next_order[key] = now + gap
                        owned[key] = unit
                        order_move(player, unit, key, point)
                    end
                elseif nearest then
                    local forward = forward_of(nearest)
                    if forward then
                        local unit_proj = origin.x * forward.x + origin.y * forward.y
                        local front, mode, centre, half = pick_target(creeps, forward,
                            unit_proj, NPC.GetMoveSpeed(unit) or 300)

                        if front then
                            owned[key] = unit
                            local spot = Entity.GetAbsOrigin(front)
                            local target, order_gap = nil, gap

                            if mode == "wait" then
                                local have = (origin.x - spot.x) * forward.x
                                    + (origin.y - spot.y) * forward.y
                                local push = have < WAITGAP and (WAITGAP - have) or 0
                                if push > DRIFT_STEP then push = DRIFT_STEP end
                                target = Vector(
                                    origin.x + forward.x * push,
                                    origin.y + forward.y * push,
                                    origin.z)
                            elseif mode == "chase" then
                                order_gap = chase_gap
                                local mine = -origin.x * forward.y + origin.y * forward.x
                                    + spot.x * forward.y - spot.y * forward.x
                                local aside = half + CLEARANCE
                                if mine < centre then aside = -aside end
                                target = Vector(
                                    spot.x + forward.x * CATCHUP - forward.y * aside,
                                    spot.y + forward.y * CATCHUP + forward.x * aside,
                                    spot.z)
                            else
                                local a_proj = spot.x * forward.x + spot.y * forward.y
                                local a_side = -spot.x * forward.y + spot.y * forward.x
                                local p = a_proj + ZONE
                                local s = a_side + wave_offset * SWEEP
                                target = Vector(
                                    forward.x * p - forward.y * s,
                                    forward.y * p + forward.x * s,
                                    spot.z)
                            end

                            next_order[key] = now + order_gap
                            if mode == "block" and origin:Distance2D(target) < PLANTED then
                                order_hold(player, unit, key)
                            else
                                order_move(player, unit, key, target)
                            end
                        end
                    end
                end
            end
        end
    end
end

function script.OnDraw()
    if not show_spot:Get() or not bind:IsDown() then return end
    local me = Heroes.GetLocal()
    if not me then return end
    if not spot_font then
        spot_font = Render.LoadFont("MuseoSansEx", Enum.FontCreate.FONTFLAG_ANTIALIAS, 500)
    end

    local origin = Entity.GetAbsOrigin(me)
    local live = active_spot(origin)
    local all = saved_points()
    for _, s in ipairs(SPOTS) do all[#all + 1] = Vector(s[1], s[2], s[3]) end

    for _, point in ipairs(all) do
        local screen, visible = Render.WorldToScreen(point)
        if visible then
            local hot = live and live:Distance2D(point) < 1
            local tone = hot and Color(90, 220, 255, 235) or Color(150, 160, 175, 150)
            Render.Circle(screen, hot and 14 or 9, tone, 2)
            if hot then
                local size = Render.TextSize(spot_font, 13, "блок")
                Render.Text(spot_font, 13, "блок",
                    Vec2(screen.x - size.x / 2, screen.y + 16), tone)
            end
        end
    end
end

function script.OnGameEnd()
    next_order, last_sent, owned = {}, {}, {}
end

return script
