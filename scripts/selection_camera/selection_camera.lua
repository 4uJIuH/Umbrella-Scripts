-- Selection Camera 1.1.0 / Umbrella API v2.0
-- https://uczone.gitbook.io/api-v2.0
-- One camera jump per selection change; never locks or follows the camera.

local VERSION = "1.1.0"
local script = {}
local group = Menu.Create("General", "Main", "Selection Camera", "Settings", "Main")
local ui = {
    enabled = group:Switch("Enabled", true),
    controlled = group:Switch("Only controllable units", true),
    hero = group:Switch("Include main hero", true),
    active = group:Switch("React to active unit change (Tab)", true),
    keyboard = group:Switch("Не переносить при выборе мышкой", true),
    mode = group:Combo("Camera target", { "Active unit", "Group center" }, 0),
    indicator = group:Switch("Show status indicator", true),
    logs = group:Switch("Log camera jumps", true),
    status = group:Label("Status: loaded; waiting for game"),
    count = group:Label("Camera jumps: 0"),
}

local state = {
    player = nil, signature = nil, active = nil, enabled = nil,
    status = "Loaded; waiting for game", count = 0, lastTarget = "-",
    errors = {}, lastError = nil, font = nil,
    selectionKey = nil, inputUpdates = 0, mouseSelecting = false,
}

-- OnKeyEvent runs before the game handles the input. Allow a short-lived,
-- single-use key token for the resulting selection; left clicks revoke it.
local buttons = Enum and Enum.ButtonCode or {}
local keyEvents = Enum and Enum.EKeyEvent or {}
local KEY_DOWN = keyEvents.EKeyEvent_KEY_DOWN or 2
local KEY_UP = keyEvents.EKeyEvent_KEY_UP or 3
local MOUSE_LEFT = buttons.KEY_MOUSE1 or 119
local modifiers = {}
for _, name in ipairs({ "KEY_LSHIFT", "KEY_RSHIFT", "KEY_LCONTROL", "KEY_RCONTROL",
    "KEY_LALT", "KEY_RALT", "KEY_LWIN", "KEY_RWIN" }) do
    if buttons[name] then modifiers[buttons[name]] = true end
end
local KEY_WINDOW = 0.35
local MAX_INPUT_UPDATES = 8

local function clearInput()
    state.selectionKey, state.inputUpdates = nil, 0
end

function script.OnKeyEvent(data)
    if not data then return true end
    local key, event = data.key, data.event
    if key == MOUSE_LEFT then
        if event == KEY_DOWN then state.mouseSelecting = true end
        if event == KEY_UP then state.mouseSelecting = false end
        -- Both press and release matter: box selection commits on release.
        clearInput()
        return true
    end
    if not ui.enabled:Get() or not ui.keyboard:Get() then return true end
    if event ~= KEY_DOWN or type(key) ~= "number" then return true end
    local keyboard = key > (buttons.KEY_NONE or 0) and key < MOUSE_LEFT
    local sideButton = key == buttons.KEY_MOUSE4 or key == buttons.KEY_MOUSE5
    if (keyboard and not modifiers[key]) or sideButton then
        if state.mouseSelecting
            or (Input and Input.IsInputCaptured and Input.IsInputCaptured())
            or (Input and Input.IsPopupOpen and Input.IsPopupOpen()) then
            clearInput()
        else
            state.selectionKey = os.clock()
            state.inputUpdates = 0
        end
    end
    -- Observe input without intercepting the game's binds or mouse clicks.
    return true
end

local function writeLog(message)
    -- Umbrella print writes to its console and %cheat_dir%/debug.log.
    print("[Selection Camera] " .. message)
end

local function setStatus(message)
    if state.status == message then return end
    state.status = message
    ui.status:Name("Status: " .. message)
end

local function errorOnce(message)
    state.lastError = message
    setStatus("Error: " .. message)
    if not state.errors[message] then
        state.errors[message] = true
        writeLog("ERROR: " .. message)
    end
end

local function clearSelection()
    state.player, state.signature, state.active = nil, nil, nil
    clearInput()
end

local function checkAPI()
    local required = {
        { "Players.GetLocal", Players and Players.GetLocal },
        { "Player.GetPlayerID", Player and Player.GetPlayerID },
        { "Player.GetSelectedUnits", Player and Player.GetSelectedUnits },
        { "Entity.IsEntity", Entity and Entity.IsEntity },
        { "Entity.IsNPC", Entity and Entity.IsNPC },
        { "Entity.IsAlive", Entity and Entity.IsAlive },
        { "Entity.IsDormant", Entity and Entity.IsDormant },
        { "Entity.GetIndex", Entity and Entity.GetIndex },
        { "Entity.GetAbsOrigin", Entity and Entity.GetAbsOrigin },
        { "NPC.IsControllableByPlayer", NPC and NPC.IsControllableByPlayer },
        { "Engine.LookAt", Engine and Engine.LookAt },
    }
    for _, item in ipairs(required) do
        if type(item[2]) ~= "function" then
            errorOnce("Missing API: " .. item[1])
            return false
        end
    end
    return true
end

local apiReady = checkAPI()

local function isUsable(unit, playerID, mainHero)
    return unit ~= nil and Entity.IsEntity(unit) and Entity.IsNPC(unit)
        and Entity.IsAlive(unit) and not Entity.IsDormant(unit)
        and (not ui.controlled:Get() or NPC.IsControllableByPlayer(unit, playerID))
        and (ui.hero:Get() or unit ~= mainHero)
end

local function update()
    local enabled = ui.enabled:Get()
    if state.enabled ~= enabled then
        state.enabled = enabled
        clearSelection()
        writeLog(enabled and "Enabled" or "Disabled")
    end
    if not enabled then setStatus("Disabled"); return end
    if not apiReady then setStatus("Error: " .. state.lastError); return end

    local player = Players.GetLocal()
    if not player then
        clearSelection()
        setStatus("Waiting for local player")
        return
    end
    if state.player ~= player then
        clearSelection()
        state.player = player
    end

    local selected = Player.GetSelectedUnits(player)
    if type(selected) ~= "table" then
        errorOnce("GetSelectedUnits returned no table")
        return
    end
    local playerID = Player.GetPlayerID(player)
    if playerID < 0 then clearSelection(); setStatus("Waiting for player ID"); return end
    local mainHero = Player.GetAssignedHero and Player.GetAssignedHero(player) or nil
    local ids, units, members, seen = {}, {}, {}, {}
    for _, unit in pairs(selected) do
        if unit and Entity.IsEntity(unit) then
            local id = Entity.GetIndex(unit)
            if not seen[id] then
                seen[id] = true
                ids[#ids + 1] = id
                if isUsable(unit, playerID, mainHero) then
                    units[#units + 1] = unit
                    members[id] = unit
                end
            end
        end
    end
    -- Order-independent signature: merely reordering the API array is not a change.
    table.sort(ids)
    local signature = table.concat(ids, ",")
    table.sort(units, function(a, b) return Entity.GetIndex(a) < Entity.GetIndex(b) end)
    local target = units[1]
    if Player.GetQueryUnit then
        local query = Player.GetQueryUnit(player)
        -- Inspecting an enemy outside the selected group must not move the camera.
        if query and Entity.IsEntity(query) and members[Entity.GetIndex(query)] then
            target = query
        end
    end
    local activeID = target and Entity.GetIndex(target) or nil
    local changed = state.signature ~= signature
        or (ui.active:Get() and state.active ~= activeID)
    local initialized = state.signature ~= nil
    state.signature, state.active = signature, activeID

    local fromKey = false
    if state.selectionKey then
        state.inputUpdates = state.inputUpdates + 1
        local elapsed = os.clock() - state.selectionKey
        fromKey = not state.mouseSelecting and elapsed >= 0 and elapsed <= KEY_WINDOW
            and state.inputUpdates <= MAX_INPUT_UPDATES
        if changed or not fromKey then clearInput() end
    end

    if not target then
        setStatus(#ids == 0 and "Ready; no selection" or "Ready; no eligible units")
        return
    end
    -- Take a baseline on load/re-enable without unexpectedly moving the camera.
    if not initialized or not changed then
        setStatus(state.lastError and ("Error: " .. state.lastError)
            or ("Ready; last target: " .. state.lastTarget))
        return
    end
    if ui.keyboard:Get() and not fromKey then
        setStatus("Ready; mouse/non-key selection skipped")
        return
    end
    -- Consume changes during chat/shop/console so they cannot trigger a delayed jump.
    if Input and Input.IsInputCaptured and Input.IsInputCaptured() then
        setStatus("Paused; input captured")
        return
    end
    if Input and Input.IsPopupOpen and Input.IsPopupOpen() then
        setStatus("Paused; popup open")
        return
    end

    local x, y = 0, 0
    local description
    if ui.mode:Get() == 1 then
        for _, unit in ipairs(units) do
            local position = Entity.GetAbsOrigin(unit)
            x, y = x + position.x, y + position.y
        end
        x, y = x / #units, y / #units
        description = "group (" .. #units .. " units)"
    else
        local position = Entity.GetAbsOrigin(target)
        x, y = position.x, position.y
        description = (NPC.GetUnitName and NPC.GetUnitName(target) or "unit")
            .. " #" .. activeID
    end
    if type(x) ~= "number" or type(y) ~= "number"
        or x ~= x or y ~= y or math.abs(x) == math.huge or math.abs(y) == math.huge then
        errorOnce("Invalid target position")
        return
    end
    Engine.LookAt(x, y)
    state.lastError = nil
    state.count = state.count + 1
    state.lastTarget = description
    ui.count:Name("Camera jumps: " .. state.count)
    setStatus("Ready; last target: " .. description)
    if ui.logs:Get() then
        writeLog(string.format("Jump #%d -> %s at (%.0f, %.0f)",
            state.count, description, x, y))
    end
end

function script.OnUpdate()
    local ok, err = pcall(update)
    if not ok then errorOnce(tostring(err)) end
end

function script.OnDraw()
    if not ui.indicator:Get() or not Render then return end
    local ok, err = pcall(function()
        if not state.font then state.font = Render.LoadFont("Tahoma", 0, 500) end
        if not state.font then return end
        local color = ui.enabled:Get() and Color(130, 230, 160, 255)
            or Color(180, 180, 180, 255)
        if state.status:sub(1, 6) == "Error:" then color = Color(255, 130, 110, 255) end
        Render.Text(state.font, 14, "Selection Camera | " .. state.status,
            Vec2(24, 180), color)
        Render.Text(state.font, 13, "Camera jumps: " .. state.count,
            Vec2(24, 199), color)
    end)
    if not ok and not state.errors.draw then
        state.errors.draw = true
        writeLog("Indicator unavailable: " .. tostring(err) .. "; menu status still available")
    end
end

function script.OnGameEnd()
    clearSelection()
    state.mouseSelecting = false
    setStatus("Waiting for game")
end

ui.enabled:SetCallback(function()
    clearSelection()
    state.mouseSelecting = false
    setStatus(ui.enabled:Get() and "Ready; waiting for selection" or "Disabled")
end)

-- Editing filters/mode takes a new baseline instead of causing a camera jump.
for _, widget in ipairs({ ui.controlled, ui.hero, ui.active, ui.mode, ui.keyboard }) do
    widget:SetCallback(clearSelection)
end

if apiReady then
    writeLog("Loaded v1.1.0. Menu: General > Main > Selection Camera > Settings > Main")
    if not Player.GetQueryUnit then
        writeLog("GetQueryUnit unavailable; using the unit with the lowest entity index")
    end
end

return script
