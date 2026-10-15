local script = {}

local cfg = {}

local MAX_PHRASES = 6
local RADIUS = 118
local ITEM_RADIUS = 42
local DEADZONE = 28

local state = {
    open = false,
    wasTeamDown = false,
    wasAllDown = false,
    center = nil,
    selected = nil,
    wheel = nil,
    font = nil,
}

local defaults = {
    "Вражеские сапы в миде душат",
    "Го, го я бегу",
    "Начинай первый",
    "Я начну, а ты помоги",
    "Дам дуэль, влейте урон плиз",
    "Надамежьте, я там ему дуэль",
}

local allDefaults = {
    "Вражеские сапы в миде душат",
    "Го, го я бегу",
    "Начинай первый",
    "Я начну, а ты помоги",
    "Дам дуэль, влейте урон плиз",
    "Надамежьте, я там ему дуэль",
}

local function try(fn, ...)
    if not fn then
        return nil
    end
    local ok, a, b, c = pcall(fn, ...)
    if ok then
        return a, b, c
    end
    return nil
end

local function vec2(x, y)
    if Vec2 then
        return Vec2(x, y)
    end
    return { x = x, y = y }
end

local function color(r, g, b, a)
    if Color then
        return Color(r, g, b, a)
    end
    return { r = r, g = g, b = b, a = a }
end

local function getWidgetValue(widget, default)
    if widget and widget.Get then
        local ok, value = pcall(widget.Get, widget)
        if ok and value ~= nil then
            return value
        end
    end
    return default
end

local function menuCall(widget, method, ...)
    if widget and widget[method] then
        pcall(widget[method], widget, ...)
    end
end

local function buttonCode(name, fallback)
    if Enum and Enum.ButtonCode and Enum.ButtonCode[name] then
        return Enum.ButtonCode[name]
    end
    return fallback
end

local function bindKey(bind, defaultName, fallback)
    if bind and bind.Buttons then
        local ok, a, b = pcall(bind.Buttons, bind)
        if ok then
            if a and a > 0 then
                return a
            end
            if b and b > 0 then
                return b
            end
        end
    end
    return buttonCode(defaultName, fallback)
end

local function isHotkeyDown(bind, defaultName, fallback)
    if not (Input and Input.IsKeyDown) then
        return false
    end
    return try(Input.IsKeyDown, bindKey(bind, defaultName, fallback)) == true
end

local function cursorPos()
    if not (Input and Input.GetCursorPos) then
        return vec2(0, 0)
    end
    local x, y = try(Input.GetCursorPos)
    return vec2(tonumber(x) or 0, tonumber(y) or 0)
end

local function phraseAt(wheel, index)
    local source = cfg[wheel]
    local fallback = wheel == "all" and allDefaults or defaults
    local widget = source and source.phrases and source.phrases[index]
    local text = tostring(getWidgetValue(widget, fallback[index] or "") or "")
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    return text
end

local function activePhrases(wheel)
    local out = {}
    for i = 1, MAX_PHRASES do
        local text = phraseAt(wheel, i)
        if text ~= "" then
            out[#out + 1] = { index = i, text = text }
        end
    end
    return out
end

local function escapeConsoleText(text)
    local s = tostring(text or "")
    s = s:gsub("\\", "\\\\")
    s = s:gsub("\"", "\\\"")
    return s
end

local function sendPhrase(text, wheel)
    if text == "" then
        return
    end
    if Engine and Engine.ExecuteCommand then
        local command = wheel == "all" and "say" or "say_team"
        pcall(Engine.ExecuteCommand, command .. " \"" .. escapeConsoleText(text) .. "\"")
    end
end

local function loadFont()
    if state.font ~= nil then
        return state.font or nil
    end
    state.font = false
    if Render and Render.LoadFont then
        local flags = (Enum and Enum.FontCreate and Enum.FontCreate.FONTFLAG_ANTIALIAS) or 0
        state.font = try(Render.LoadFont, "Arial", flags, 500) or false
    end
    return state.font or nil
end

local function textSize(font, size, text)
    if Render and Render.TextSize and font then
        return try(Render.TextSize, font, size, text) or vec2(0, 0)
    end
    return vec2(#tostring(text or "") * size * 0.45, size)
end

local function updateSelection()
    local phrases = activePhrases(state.wheel)
    if #phrases == 0 or not state.center then
        state.selected = nil
        return
    end

    local cur = cursorPos()
    local dx = (cur.x or 0) - (state.center.x or 0)
    local dy = (cur.y or 0) - (state.center.y or 0)
    local d = math.sqrt(dx * dx + dy * dy)
    if d < DEADZONE then
        state.selected = nil
        return
    end

    local angle = math.atan(dy, dx)
    local bestSlot = nil
    local bestDelta = math.huge
    for slot = 1, #phrases do
        local itemAngle = -math.pi * 0.5 + (slot - 1) * (math.pi * 2 / #phrases)
        local delta = math.abs(math.atan(math.sin(angle - itemAngle), math.cos(angle - itemAngle)))
        if delta < bestDelta then
            bestDelta = delta
            bestSlot = slot
        end
    end
    state.selected = bestSlot
end

local function openWheel(wheel)
    state.open = true
    state.center = cursorPos()
    state.selected = nil
    state.wheel = wheel
end

local function closeWheel(send)
    if send and state.selected then
        local phrases = activePhrases(state.wheel)
        local item = phrases[state.selected]
        if item then
            sendPhrase(item.text, state.wheel)
        end
    end
    state.open = false
    state.selected = nil
    state.wheel = nil
end

local function updateWheel()
    if not getWidgetValue(cfg.enabled, true) then
        state.open = false
        state.wasTeamDown = false
        state.wasAllDown = false
        return
    end
    if Input and Input.IsInputCaptured and try(Input.IsInputCaptured) == true and not state.open then
        state.wasTeamDown = false
        state.wasAllDown = false
        return
    end

    local teamDown = isHotkeyDown(cfg.team and cfg.team.hotkey, "KEY_X", 34)
    local allDown = isHotkeyDown(cfg.all and cfg.all.hotkey, "KEY_C", 13)

    if teamDown and not state.wasTeamDown and not state.open then
        openWheel("team")
    elseif allDown and not state.wasAllDown and not state.open then
        openWheel("all")
    elseif state.open and ((state.wheel == "team" and teamDown) or (state.wheel == "all" and allDown)) then
        updateSelection()
    elseif state.open and ((state.wheel == "team" and not teamDown) or (state.wheel == "all" and not allDown)) then
        closeWheel(true)
    end
    state.wasTeamDown = teamDown
    state.wasAllDown = allDown
end

local function drawTextCentered(font, fontSize, text, pos, col)
    if not (Render and Render.Text and font) then
        return
    end
    local size = textSize(font, fontSize, text)
    Render.Text(font, fontSize, text, vec2((pos.x or 0) - (size.x or 0) * 0.5, (pos.y or 0) - (size.y or 0) * 0.5), col)
end

local function utf8Chars(text)
    local chars = {}
    for ch in tostring(text or ""):gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        chars[#chars + 1] = ch
    end
    return chars
end

local function utf8Join(chars, first, last)
    local out = {}
    for i = first, last do
        out[#out + 1] = chars[i]
    end
    return table.concat(out)
end

local function fitText(font, fontSize, text, maxWidth)
    local s = tostring(text or "")
    if (textSize(font, fontSize, s).x or 0) <= maxWidth then
        return s
    end

    local chars = utf8Chars(s)
    if #chars <= 3 then
        return s
    end

    for len = #chars - 1, 1, -1 do
        local candidate = utf8Join(chars, 1, len) .. "..."
        if (textSize(font, fontSize, candidate).x or 0) <= maxWidth then
            return candidate
        end
    end
    return "..."
end

local function drawFittedTextCentered(font, fontSize, text, pos, col, maxWidth)
    drawTextCentered(font, fontSize, fitText(font, fontSize, text, maxWidth), pos, col)
end

local function segmentColor(slot, selected)
    if selected then
        return color(70, 150, 230, 230)
    end
    return color(25, 32, 42, 220)
end

local function drawWheel()
    if not state.open or not state.center or not (Render and Render.FilledCircle and Render.Circle) then
        return
    end

    local phrases = activePhrases(state.wheel)
    if #phrases == 0 then
        return
    end

    local font = loadFont()
    local center = state.center
    Render.FilledCircle(center, RADIUS + 34, color(7, 9, 13, 145), 0, 1, 64)
    Render.Circle(center, RADIUS + 34, color(125, 170, 230, 100), 2, 0, 1, false, 64)
    Render.FilledCircle(center, DEADZONE, color(12, 15, 21, 220), 0, 1, 32)
    Render.Circle(center, DEADZONE, color(145, 175, 215, 120), 1, 0, 1, false, 32)

    for slot = 1, #phrases do
        local angle = -math.pi * 0.5 + (slot - 1) * (math.pi * 2 / #phrases)
        local x = (center.x or 0) + math.cos(angle) * RADIUS
        local y = (center.y or 0) + math.sin(angle) * RADIUS
        local selected = state.selected == slot
        local p = vec2(x, y)
        local fill = segmentColor(slot, selected)
        local outline = selected and color(255, 255, 255, 220) or color(150, 170, 195, 115)
        Render.FilledCircle(p, ITEM_RADIUS, fill, 0, 1, 40)
        Render.Circle(p, ITEM_RADIUS, outline, selected and 3 or 1, 0, 1, false, 40)
        drawFittedTextCentered(font, selected and 13 or 11, phrases[slot].text, p, selected and color(255, 255, 255, 250) or color(210, 223, 240, 225), ITEM_RADIUS * 1.55)
    end

    drawTextCentered(font, 12, state.wheel == "all" and "all" or "team", center, color(235, 242, 255, 235))
end

local function initMenu()
    local root = Menu and Menu.Create and Menu.Create("Scripts", "Utility") or nil
    if not root then
        return
    end
    local tab = root:Create("RadialChat")
    if not tab or not tab.Create then
        return
    end
    local main = tab:Create("Main")
    if not main or not main.Create then
        return
    end
    local mainGroup = main:Create("Колеса чата")
    local teamGroup = main:Create("Командное колесо")
    local allGroup = main:Create("Общее колесо")
    if not mainGroup or not teamGroup or not allGroup then
        return
    end

    cfg.enabled = mainGroup.Switch and mainGroup:Switch("Включить", true, "\u{f00c}") or nil
    local info = mainGroup.Label and mainGroup:Label("Командный и общий чат имеют разные хоткеи.", "\u{f05a}") or nil
    menuCall(info, "ToolTip", "Старые сохраненные поля Phrase не используются. Эти настройки созданы заново.")

    cfg.team = { phrases = {} }
    cfg.all = { phrases = {} }

    cfg.team.hotkey = teamGroup.Bind and teamGroup:Bind("Хоткей командного колеса", buttonCode("KEY_X", 34), "\u{f11c}") or nil
    for i = 1, MAX_PHRASES do
        cfg.team.phrases[i] = teamGroup.Input and teamGroup:Input("Командная фраза " .. tostring(i), defaults[i], "\u{f27a}") or nil
    end

    cfg.all.hotkey = allGroup.Bind and allGroup:Bind("Хоткей общего колеса", buttonCode("KEY_C", 13), "\u{f11c}") or nil
    for i = 1, MAX_PHRASES do
        cfg.all.phrases[i] = allGroup.Input and allGroup:Input("Общая фраза " .. tostring(i), allDefaults[i], "\u{f27a}") or nil
    end
end

function script.OnUpdate()
    updateWheel()
end

function script.OnDraw()
    updateWheel()
    drawWheel()
end

initMenu()

return script
