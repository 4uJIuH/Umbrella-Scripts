---@diagnostic disable: undefined-global
-- 1000-7: по кнопке пишет в чат отсчёт "1000-7=993", "993-7=986", ... до нуля.
-- Повторное нажатие кнопки останавливает отсчёт.

local VERSION = "1.0.0"
local script = {}

--#region UI
local tab = Menu.Create("General", "Main", "Interface")
local group = tab:Create("1000-7"):Create("Main")

local ui = {}
ui.enabled  = group:Switch("Enabled", true, "\u{f00c}")
ui.key      = group:Bind("Start / stop", Enum.ButtonCode.KEY_F9, "\u{f11c}")
ui.channel  = group:Combo("Chat", { "All", "Team" }, 0)
ui.start    = group:Slider("Start", 7, 10000, 1000)
ui.step     = group:Slider("Step", 1, 100, 7)
-- Дота режет сообщения при флуде, поэтому слишком маленькая задержка = пропущенные строки
ui.delay    = group:Slider("Delay (sec)", 0.5, 5.0, 1.2, "%.1f")
ui.final    = group:Input("Final message", "")
ui.final:ToolTip("Sent after the countdown ends. Leave empty to skip.")
--#endregion

local running = false
local value = 0
local next_send = 0
local final_pending = false

local function say(text)
    local cmd = ui.channel:Get() == 1 and "say_team" or "say"
    text = text:gsub('"', "'")
    Engine.ExecuteCommand(cmd .. ' "' .. text .. '"')
end

local function start()
    running = true
    value = ui.start:Get()
    next_send = 0
    final_pending = false
end

local function stop()
    running = false
    final_pending = false
end

function script.OnUpdate()
    if not ui.enabled:Get() then
        if running then stop() end
        return
    end

    if not Input.IsInputCaptured() and ui.key:IsPressed() then
        if running then stop() else start() end
    end

    if not running then return end

    local now = os.clock()
    if now < next_send then return end
    next_send = now + ui.delay:Get()

    if final_pending then
        say(ui.final:Get())
        stop()
        return
    end

    local step = ui.step:Get()
    local result = value - step
    say(string.format("%d-%d=%d", value, step, result))
    value = result

    -- следующий шаг ушёл бы в минус: заканчиваем
    if value - step < 0 then
        local final = ui.final:Get()
        if final and final ~= "" then final_pending = true else stop() end
    end
end

function script.OnGameEnd()
    stop()
end

return script
