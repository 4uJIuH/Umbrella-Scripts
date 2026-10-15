---@diagnostic disable: undefined-global

local script = {}

local JSON = require("assets.JSON")
local protobuf = require("protobuf")

local ABILITY_CLASS = "CDOTA_Ability_Plus_HighFive"
local MOD_REQUESTED = "modifier_plus_high_five_requested"
local MOD_SUCCESS = "modifier_plus_high_five_success"
local TEMPEST_MODIFIER = "modifier_arc_warden_tempest_double"

local ORDER_MSG = "CDOTAClientMsg_ExecuteOrders"
local ORDER_MSG_ID_GUESS = 350
local ORDER_CAST_NO_TARGET = "DOTA_UNIT_ORDER_CAST_NO_TARGET"
local ORDER_CAST_NO_TARGET_NUM = 8

local ACK_RANGE = 900
local THINK_INTERVAL = 0.2
local RESCAN_INTERVAL = 1
local RECAST_GUARD = 2

local ui = {}
local ready = false

local S = {
    nextThink = 0,
    nextScan = 0,
    lastCast = 0,
    pendingAt = nil,
    status = nil,
    sequence = 0,
    seqSeen = false,
    latency = 30,
    orderMsgId = ORDER_MSG_ID_GUESS,
    probed = {},
    cacheClone = nil,
    cacheAbility = nil,
}

local function try(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, r = pcall(fn, ...)
    if ok then return r end
    return nil
end

local function now()
    return try(GameRules.GetGameTime) or 0
end

local function status(text)
    if S.status == text or ui.enabled == nil then return end
    S.status = text
    pcall(ui.enabled.ToolTip, ui.enabled, "Состояние: " .. text)
end

local function dist2d(a, b)
    if a == nil or b == nil then return math.huge end
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

local function has_modifier(unit, name)
    for _, mod in pairs(try(NPC.GetModifiers, unit) or {}) do
        if (try(Modifier.GetName, mod) or "") == name then return true end
    end
    return false
end

local function find_clone(hero, pid, team)
    local heroName = try(NPC.GetUnitName, hero)
    local fallback = nil
    for _, unit in pairs(try(Heroes.GetAll) or {}) do
        if unit ~= hero
            and try(Entity.GetTeamNum, unit) == team
            and try(Entity.IsAlive, unit)
            and try(Entity.IsControllableByPlayer, unit, pid)
        then
            if has_modifier(unit, TEMPEST_MODIFIER) then return unit end
            if fallback == nil and try(NPC.GetUnitName, unit) == heroName then
                fallback = unit
            end
        end
    end
    return fallback
end

local function ability_for(unit)
    for _, e in pairs(try(Entities.GetAll) or {}) do
        if tostring(try(Entity.GetClassName, e)) == ABILITY_CLASS then
            if try(Entity.GetOwner, e) == unit then return e end
        end
    end
    return nil
end

local function clone_ability(clone)
    local t = now()
    if S.cacheClone == clone and S.cacheAbility ~= nil and t < S.nextScan then
        return S.cacheAbility
    end
    S.nextScan = t + RESCAN_INTERVAL
    S.cacheClone = clone
    S.cacheAbility = ability_for(clone)
    return S.cacheAbility
end

local function send_order(unitIndex, abilityIndex, orderType)
    S.sequence = S.sequence + 1
    local body = {
        orders = {
            {
                order_type = orderType,
                units = { unitIndex },
                target_index = 0,
                ability_index = abilityIndex,
                sequence_number = S.sequence,
                flags = 0,
            },
        },
        last_order_latency = S.latency,
    }
    local ok, sent = pcall(NetChannel.SendNetMessage, ORDER_MSG, JSON:encode(body))
    return ok and sent ~= false
end

local function high_five_as(clone)
    local unitIndex = try(Entity.GetIndex, clone)
    local ability = clone_ability(clone)
    if ability == nil then return false, "у клона нет абилки пятюни" end
    local abilityIndex = try(Entity.GetIndex, ability)
    if unitIndex == nil or abilityIndex == nil then return false, "нет индексов" end
    if not S.seqSeen then
        return false, "жду твой первый приказ, чтобы узнать номер"
    end

    if not send_order(unitIndex, abilityIndex, ORDER_CAST_NO_TARGET) then
        if not send_order(unitIndex, abilityIndex, ORDER_CAST_NO_TARGET_NUM) then
            return false, "SendNetMessage отклонил"
        end
    end
    return true, "отбил"
end

local function find_requester(clone, hero, team, radius)
    local clonePos = try(Entity.GetAbsOrigin, clone)
    if clonePos == nil then return nil end

    local answerSelf = ui.answerSelf == nil or ui.answerSelf:Get()
    local answerAllies = ui.answerAllies == nil or ui.answerAllies:Get()

    for _, unit in pairs(try(Heroes.GetAll) or {}) do
        if unit ~= clone
            and try(Entity.GetTeamNum, unit) == team
            and try(Entity.IsAlive, unit)
        then
            local isSelf = (unit == hero)
            if (isSelf and answerSelf) or (not isSelf and answerAllies) then
                if dist2d(clonePos, try(Entity.GetAbsOrigin, unit)) <= radius then
                    if has_modifier(unit, MOD_REQUESTED) then return unit end
                end
            end
        end
    end
    return nil
end

local function resolve(force)
    local hero = try(Heroes.GetLocal)
    if hero == nil then return end
    local pid = try(Hero.GetPlayerID, hero)
    local team = try(Entity.GetTeamNum, hero)
    if pid == nil or pid < 0 or team == nil then return end

    local clone = find_clone(hero, pid, team)
    if clone == nil then
        S.pendingAt = nil
        status("клона нет")
        return
    end

    if has_modifier(clone, MOD_SUCCESS) or has_modifier(clone, MOD_REQUESTED) then
        S.pendingAt = nil
        status("клон уже отбил")
        return
    end

    local t = now()
    if t - S.lastCast < RECAST_GUARD then return end

    if not force then
        local requester = find_requester(clone, hero, team, ui.radius:Get())
        if requester == nil then
            S.pendingAt = nil
            status("готов, жду запроса пятюни")
            return
        end
        local delay = ui.delay:Get() / 1000
        if S.pendingAt == nil then
            S.pendingAt = t + delay
            return
        end
        if t < S.pendingAt then return end
    end

    local ok, info = high_five_as(clone)
    S.lastCast = t
    S.pendingAt = nil
    status(ok and "отбил" or ("не вышло: " .. tostring(info)))
end

local function initialize_menu()
    local tab = Menu.Create("Heroes", "Hero List", "Arc Warden")
    local column = tab:Create("Arc Warden")
    local group = column:Create("Пятюня", Enum.GroupSide.Left)

    ui.enabled = group:Switch("Отбивать пятюню клоном", true, "\u{f2b5}")
    ui.enabled:ToolTip("Состояние: ещё не считано")

    ui.test = group:Button("Отбить сейчас (тест)", function()
        pcall(resolve, true)
    end)

    ui.radius = group:Slider("Радиус", 300, 1200, ACK_RANGE, "%d")
    ui.radius:Icon("\u{f05b}")
    ui.radius:ToolTip("Игровое значение acknowledge_range = 900")
    ui.delay = group:Slider("Задержка ответа", 0, 1500, 250, "%d ms")
    ui.delay:Icon("\u{f017}")
    ui.answerSelf = group:Switch("Отвечать своему герою", true, "\u{f007}")
    ui.answerAllies = group:Switch("Отвечать союзникам", true, "\u{f0c0}")

    return true
end

function script.OnScriptsLoaded()
    ready = initialize_menu()
end

function script.OnGameEnd()
    S.pendingAt = nil
    S.lastCast = 0
    S.status = nil
    S.sequence = 0
    S.seqSeen = false
    S.orderMsgId = ORDER_MSG_ID_GUESS
    S.probed = {}
    S.cacheClone = nil
    S.cacheAbility = nil
end

local function decode_message(data)
    local ok, json = pcall(protobuf.decodeToJSONfromObject, data)
    if not ok or type(json) ~= "string" or json == "" then
        ok, json = pcall(protobuf.decodeToJSONfromObject, data.msg_object)
    end
    if not ok or type(json) ~= "string" or json == "" then return nil end

    local parsed = try(function() return JSON:decode(json) end)
    if type(parsed) ~= "table" then return nil end
    return parsed
end

function script.OnSendNetMessage(data)
    if not ready or data == nil then return true end

    local id = data.message_id
    if type(id) ~= "number" then return true end

    if S.orderMsgId ~= nil then
        if id ~= S.orderMsgId then return true end
    else
        if S.probed[id] then return true end
        S.probed[id] = true
    end

    local parsed = decode_message(data)
    if parsed == nil or type(parsed.orders) ~= "table" then
        if S.orderMsgId == id then
            S.orderMsgId = nil
            S.probed[id] = true
        end
        return true
    end

    S.orderMsgId = id

    if type(parsed.last_order_latency) == "number" then
        S.latency = parsed.last_order_latency
    end
    for _, order in ipairs(parsed.orders or {}) do
        local seq = tonumber(order.sequence_number)
        if seq ~= nil and seq > S.sequence then
            S.sequence = seq
            S.seqSeen = true
        end
    end

    return true
end

function script.OnUpdate()
    if not ready or not ui.enabled:Get() then return end
    local t = now()
    if t < S.nextThink then return end
    S.nextThink = t + THINK_INTERVAL
    pcall(resolve, false)
end

return script
