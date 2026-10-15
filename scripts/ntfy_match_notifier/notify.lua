local NTFY_TOPIC = ""

local enabled = true
local last_game_state = -1
local notified_this_match = false
local last_notification_time = 0
local EVENT_COOLDOWN = 3.0

local function ntfy_post(message, title, priority)
    if not NTFY_TOPIC or NTFY_TOPIC == "" then
        Log.Write("[UCZone] NTFY_TOPIC is not set — enter your topic in the menu")
        return
    end

    priority = priority or "default"

    local ok = HTTP.Request(
        "POST",
        "https://ntfy.sh/" .. NTFY_TOPIC,
        {
            headers = {
                ["Content-Type"] = "text/plain",
                ["Title"]        = title or "Dota 2",
                ["Priority"]     = priority,
                ["Tags"]         = "video_game",
            },
            data    = message,
            timeout = 10.0
        },
        function(response)
            if response.code == "200" then
                Log.Write("[UCZone] ntfy success: " .. message)
            else
                Log.Write("[UCZone] ntfy failed. Code: " .. tostring(response.code))
            end
        end,
        "ntfy_notifier"
    )

    if not ok then
        Log.Write("[UCZone] ntfy HTTP.Request could not be started")
    else
        Log.Write("[UCZone] ntfy HTTP.Request sent")
    end
end

local function setup_menu()
    local group = Menu.Create(
        "UCZone",
        "Utilities",
        "Ntfy",
        "Match Notifier",
        "On Accept/Resolve"
    )

    -- Enable toggle
    local sw = group:Switch("Enable match notifier", true)
    sw:ToolTip("Send a push notification when a match is accepted")
    sw:SetCallback(function(self)
        enabled = self:Get()
        Log.Write("[UCZone] Notifier enabled = " .. tostring(enabled))
    end, true)

    -- ntfy topic input
    local topic_input = group:Input("ntfy topic", "")
    topic_input:ToolTip("Your ntfy.sh topic name — subscribe to it in the ntfy app")
    topic_input:SetCallback(function(self)
        NTFY_TOPIC = self:Get()
        Log.Write("[UCZone] ntfy topic set to: " .. NTFY_TOPIC)
    end, true)

    -- Test button (half width) + Clear button (half width)
    group:Button("Send test notification", function()
        if NTFY_TOPIC == "" then
            Log.Write("[UCZone] Cannot test — ntfy topic is empty")
            return
        end
        ntfy_post("UCZone is connected! Notifications are working.", "UCZone Test", "low")
        Log.Write("[UCZone] Test notification sent to topic: " .. NTFY_TOPIC)
    end, false, 0.5)

    group:Button("Clear topic", function()
        topic_input:Set("")
        NTFY_TOPIC = ""
        Log.Write("[UCZone] ntfy topic cleared")
    end, true, 0.5)
end

local function tick()
    if not enabled then
        return
    end

    local current_game_state = GameRules.GetGameState()
    local current_time = os.time()

    if current_game_state == 2 then
        if last_game_state ~= 2 and not notified_this_match then
            if current_time - last_notification_time >= EVENT_COOLDOWN then
                last_notification_time = current_time
                notified_this_match = true
                ntfy_post("Match accepted! Hero selection phase.", "Dota 2 - Match Found", "high")
                Log.Write("[UCZone] Entered hero selection (state 2) -> ntfy notified")
            end
        end
    end

    if current_game_state == 0 or current_game_state == 1 then
        if notified_this_match then
            notified_this_match = false
            Log.Write("[UCZone] Returned to lobby/queue, reset notification flag")
        end
    end

    last_game_state = current_game_state
end

local function on_scripts_loaded()
    setup_menu()
    Log.Write("[UCZone] ntfy match notifier loaded")
end

return {
    OnScriptsLoaded = on_scripts_loaded,
    OnFrame = tick,
}