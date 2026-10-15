local JSON = require("assets.JSON");
local protobuf = require("protobuf");
local HTTP = HTTP;

local is_recording = false;
local message_count = 0;

-- Ntfy.sh settings
local NTFY_TOPIC = ""
local ntfy_enabled = true
local last_poll_time = 0
local last_message_id = nil
local is_polling = false
local POLL_INTERVAL = 15.0
local auto_queue_on_end = true

-- Key Emulator settings
local CONTROL_URL = "http://127.0.0.1:5001/keypress"
local STATUS_URL = "http://127.0.0.1:5001/status"

-- Initialize db for auto-search
db.autoSearch = db.autoSearch or {};

-- Utility function for getting game time
local function getGameTime()
    if GameRules and GameRules.GetGameTime then
        return GameRules.GetGameTime()
    else
        return os.clock()
    end
end

-- Timer system
local Timers = {};
do
    local Queue = {};
    function Timers.ExecuteAfter(delay, func, ...)
        local Info = { Delay = delay, Func = func, Args = { ... } };
        Queue[#Queue + 1] = Info;
    end
    function Timers.Listener()
        local DeltaTime = GlobalVars.GetAbsFrameTime();
        for Index = #Queue, 1, -1 do
            local Info = Queue[Index];
            Info.Delay = Info.Delay - DeltaTime;
            if Info.Delay <= 0 then
                Info.Func(table.unpack(Info.Args));
                table.remove(Queue, Index);
            end
        end
    end
end

-- Game modes and matchgroups
local GAME_MODES = {
    "All pick",
    "Turbo",
    "Single draft",
    "Random draft",
    "Ability draft",
    "Last Search",
};

local MATCHGROUPS = {
    "US West",
    "US East",
    "EU West",
    "SE Asia",
    "Brazil",
    "Argentina",
    "Russia",
    "EU East",
    "Australia",
    "South Africa",
    "China Telecom Shanghai",
    "China Unicom",
    "Dubai",
    "Chile",
    "Peru",
    "India",
    "China Telecom Guangdong",
    "China Telecom Zhejiang",
    "Japan",
    "China Telecom Wuhan",
    "China Unicom 2",
};

local ENUM_GAME_MODES = {
    ["All pick"] = 1 << 1,        -- 2 (Unranked All Pick)
    ["Turbo"] = 1 << 23,          -- 8388608
    ["Single draft"] = 1 << 4,    -- 16
    ["Random draft"] = 1 << 3,    -- 8
    ["Ability draft"] = 1 << 18,  -- 262144
};

local ENUM_GAME_MODES_RANKED = {
    ["All pick"] = 1 << 22,       -- 4194304 (Ranked All Pick / Ranked Roles)
    ["Turbo"] = 1 << 23,          -- 8388608
    ["Single draft"] = 1 << 4,    -- 16
    ["Random draft"] = 1 << 3,    -- 8
    ["Ability draft"] = 1 << 18,  -- 262144
};

local ENUM_GAME_MODES_RANKED_ROLES = {
    ["All pick"] = 1 << 22,       -- 4194304 (Same as Ranked Classic)
    ["Turbo"] = 1 << 23,          -- 8388608
    ["Single draft"] = 1 << 4,    -- 16
    ["Random draft"] = 1 << 3,    -- 8
    ["Ability draft"] = 1 << 18,  -- 262144
};

local ENUM_MATCHGROUPS = {
    [MATCHGROUPS[1]] = 1 << 0,   -- US West
    [MATCHGROUPS[2]] = 1 << 1,   -- US East
    [MATCHGROUPS[3]] = 1 << 2,   -- EU West
    [MATCHGROUPS[4]] = 1 << 3,   -- SE Asia
    [MATCHGROUPS[5]] = 1 << 5,   -- Brazil
    [MATCHGROUPS[6]] = 1 << 6,   -- Argentina
    [MATCHGROUPS[7]] = 1 << 7,   -- Russia
    [MATCHGROUPS[8]] = 1 << 8,   -- EU East
    [MATCHGROUPS[9]] = 1 << 9,   -- Australia
    [MATCHGROUPS[10]] = 1 << 10, -- South Africa
    [MATCHGROUPS[11]] = 1 << 11, -- China Telecom Shanghai
    [MATCHGROUPS[12]] = 1 << 12, -- China Unicom
    [MATCHGROUPS[13]] = 1 << 13, -- Dubai
    [MATCHGROUPS[14]] = 1 << 14, -- Chile
    [MATCHGROUPS[15]] = 1 << 15, -- Peru
    [MATCHGROUPS[16]] = 1 << 16, -- India
    [MATCHGROUPS[17]] = 1 << 17, -- China Telecom Guangdong
    [MATCHGROUPS[18]] = 1 << 18, -- China Telecom Zhejiang
    [MATCHGROUPS[19]] = 1 << 19, -- Japan
    [MATCHGROUPS[20]] = 1 << 20, -- China Telecom Wuhan
    [MATCHGROUPS[21]] = 1 << 21  -- China Unicom 2
};

-- Role flags for Ranked Roles
local ROLE_FLAGS = {
    ["All Roles"] = 1,
    ["Safe Lane"] = 1,
    ["Mid Lane"] = 2,
    ["Off Lane"] = 4,
    ["Support"] = 8,
    ["Hard Support"] = 16,
    ["Core (Safe+Mid+Off)"] = 7,
    ["Safelane+Mid"] = 3,
    ["Safelane+Offlane"] = 5,
    ["Mid+Offlane"] = 6,
    ["Support+Hard Support"] = 24,
    ["All Roles (1+2+4+8+16)"] = 31,
};

local ROLE_NAMES = {
    "All Roles",
    "Safe Lane",
    "Mid Lane",
    "Off Lane",
    "Support",
    "Hard Support",
    "Core (Safe+Mid+Off)",
    "Safelane+Mid",
    "Safelane+Offlane",
    "Mid+Offlane",
    "Support+Hard Support",
    "All Roles (1+2+4+8+16)",
};

local function resolveLaneFlags(flag)
    -- Check exact matches first
    for role_name, role_flag in pairs(ROLE_FLAGS) do
        if role_flag == flag then
            return role_name
        end
    end
    -- Fallback: build a name from individual bits
    local parts = {}
    if flag & 1  ~= 0 then parts[#parts+1] = "Safe" end
    if flag & 2  ~= 0 then parts[#parts+1] = "Mid"  end
    if flag & 4  ~= 0 then parts[#parts+1] = "Off"  end
    if flag & 8  ~= 0 then parts[#parts+1] = "Support" end
    if flag & 16 ~= 0 then parts[#parts+1] = "Hard Support" end
    return #parts > 0 and table.concat(parts, "+") or "None"
end

-- Key Emulator variables
local keys = {
    "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
    "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
    "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
    "Space", "Enter", "Tab", "Escape", "Backspace", "Delete", "Insert",
    "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12",
    "Shift", "Ctrl", "Alt", "CapsLock",
    "Home", "End", "PageUp", "PageDown", "Left", "Up", "Right", "Down"
}

local appConnected = false
local lastStatusTime = 0

-- Ntfy.sh functions
local function ntfy_post(message, title, priority)
    if not NTFY_TOPIC or NTFY_TOPIC == "" then return end
    HTTP.Request("POST", "https://ntfy.sh/" .. NTFY_TOPIC, {
        headers = {
            ["Content-Type"] = "text/plain",
            ["Title"]        = title or "Dota 2",
            ["Priority"]     = priority or "default",
            ["Tags"]         = "video_game",
        },
        data    = message,
        timeout = 10.0,
    }, function(res)
        print("[UCZone] ntfy POST code: " .. tostring(res.code))
    end, "ntfy_post")
end

-- Key Emulator functions
local function sendKeyCommand(key, mode, action)
    if not appConnected then
        print("Key Emulator: C# App not connected, skipping key command")
        return
    end

    local url = CONTROL_URL .. "?key=" .. key .. "&mode=" .. mode .. "&action=" .. action
    local sent = HTTP.Request("GET", url, {}, function(resp)
        if tonumber(resp.code) == 200 then
            print("Key Emulator: Key command sent successfully")
        else
            print("Key Emulator: Failed to send key command")
        end
    end, "")

    print("Key Emulator: HTTP.Request(keypress) → sent=" .. tostring(sent) .. " url=" .. url)
end

local function onStatus(resp)
    if tonumber(resp.code) == 200 then
        if not appConnected then
            print("Key Emulator: Connected to Key Emulator Server")
        end
        appConnected = true
    else
        if appConnected then
            print("Key Emulator: Lost connection to Key Emulator Server")
        end
        appConnected = false
    end
end

local function checkKeyEmulatorStatus()
    local now = getGameTime()
    if now - lastStatusTime >= 2.0 then
        lastStatusTime = now
        local sent = HTTP.Request("GET", STATUS_URL, {}, onStatus, "")
        print("Key Emulator: HTTP.Request(status) → sent=" .. tostring(sent) .. " url=" .. STATUS_URL)
    end
end

-- Save and load message functions
local function saveMessage(msg_type, data, size)
    if msg_type == 7033 then
        local success, decoded = pcall(protobuf.decodeToJSON, 'CMsgStartFindingMatch', data, size)
        if success and decoded then
            local search_params = JSON:decode(decoded)

            local params_table = {}
            if type(search_params) == "userdata" then
                for key, value in pairs(search_params) do
                    params_table[key] = value
                end
            else
                params_table = search_params
            end

            db.autoSearch.last_search_msg_type = msg_type;
            db.autoSearch.last_search_size = size;
            db.autoSearch.last_search_timestamp = os.time();

            for key, value in pairs(params_table) do
                db.autoSearch["last_search_params." .. key] = value
            end

            db.autoSearch.last_search_params_json = JSON:encode(params_table)

            print("Decoded and saved search parameters to db:", JSON:encode(params_table))
        else
            print("Failed to decode search message")
        end
    end

    message_count = message_count + 1;
    print("Saved message info - Type: " .. msg_type .. " Size: " .. size)
end

local function loadMessage()
    print("=== LOADING MESSAGE FROM DB ===")
    print("db.autoSearch.last_search_msg_type:", db.autoSearch.last_search_msg_type)

    if not db.autoSearch.last_search_msg_type then
        print("No msg_type found in db")
        return nil
    end

    if db.autoSearch.last_search_params_json then
        print("Found JSON data in db, loading from JSON")
        local success, search_params = pcall(JSON.decode, JSON, db.autoSearch.last_search_params_json)
        if success and search_params then
            print("Successfully loaded search parameters from JSON")
            return {
                msg_type = db.autoSearch.last_search_msg_type,
                size = db.autoSearch.last_search_size,
                search_params = search_params
            }
        else
            print("Failed to decode JSON from db")
        end
    end

    local search_params = {}

    search_params.bot_difficulty_mask = db.autoSearch["last_search_params.bot_difficulty_mask"]
    search_params.bot_script_index_mask = db.autoSearch["last_search_params.bot_script_index_mask"]
    search_params.client_version = db.autoSearch["last_search_params.client_version"]
    search_params.custom_game_difficulty_mask = db.autoSearch["last_search_params.custom_game_difficulty_mask"]
    search_params.disable_experimental_gameplay = db.autoSearch["last_search_params.disable_experimental_gameplay"]
    search_params.game_language_enum = db.autoSearch["last_search_params.game_language_enum"]
    search_params.game_language_name = db.autoSearch["last_search_params.game_language_name"]
    search_params.game_modes = db.autoSearch["last_search_params.game_modes"]
    search_params.high_priority_disabled = db.autoSearch["last_search_params.high_priority_disabled"]
    search_params.is_challenge_match = db.autoSearch["last_search_params.is_challenge_match"]
    search_params.key = db.autoSearch["last_search_params.key"]
    search_params.lane_selection_flags = db.autoSearch["last_search_params.lane_selection_flags"]
    search_params.match_type = db.autoSearch["last_search_params.match_type"]
    search_params.matchgroups = db.autoSearch["last_search_params.matchgroups"]
    search_params.matchlanguages = db.autoSearch["last_search_params.matchlanguages"]
    search_params.region_select_flags = db.autoSearch["last_search_params.region_select_flags"]
    search_params.solo_queue = db.autoSearch["last_search_params.solo_queue"]
    search_params.steam_clan_account_id = db.autoSearch["last_search_params.steam_clan_account_id"]
    search_params.team_id = db.autoSearch["last_search_params.team_id"]

    print("Loaded game_modes:", search_params.game_modes)
    print("Loaded matchgroups:", search_params.matchgroups)

    if not search_params.game_modes then
        print("No game_modes found in db")
        return nil
    end

    print("Successfully loaded search parameters from db")
    return {
        msg_type = db.autoSearch.last_search_msg_type,
        size = db.autoSearch.last_search_size,
        search_params = search_params
    }
end

local function replayMessage()
    local msg = loadMessage()
    if msg and msg.search_params and type(msg.search_params) == "table" then
        print("Replaying saved search message from db")
        print("Search params from db:", JSON:encode(msg.search_params))
        local enc_message = protobuf.encodeFromJSON('CMsgStartFindingMatch', JSON:encode(msg.search_params))
        GC.SendMessage(enc_message.binary, msg.msg_type, enc_message.size)
        return true
    else
        print("No saved search message found in db or invalid data type")
        if msg and msg.search_params then
            print("Data type:", type(msg.search_params))
        end
        return false
    end
end

-- ============================================================
-- FIX: Forward-declare menu elements that search_match closes
-- over, so they resolve as locals instead of (nil) globals.
-- ============================================================
local game_mode_selector
local matchgroup_selector
local enableKeyOnSearch
local targetKey
local keyMode
local matchType
local roleSelector

-- Search match function
local search_match = function()
    print("=== SEARCH_MATCH CALLED ===")

    if not (Players.GetLocal() == nil and Heroes.GetLocal() == nil) then
        print("Local player or hero found, skipping search");
        ntfy_post("⚠️ Already in a game!", "Dota 2", "low")
        return;
    end

    local enabled_modes = game_mode_selector:ListEnabled();
    local use_last_search = false;

    print("Enabled modes:", JSON:encode(enabled_modes))

    for _, mode in pairs(enabled_modes) do
        if mode == "Last Search" then
            use_last_search = true;
            break;
        end
    end

    if use_last_search then
        print("Using last search parameters");
        local success = replayMessage();
        if success then
            ntfy_post("✅ Match search started (Last Search)", "Dota 2", "default")
        else
            ntfy_post("❌ Failed to start search - no saved parameters", "Dota 2", "high")
        end
        return;
    end

    local game_mode = 0;
    local matchgroup = 0;

    -- Determine which game mode enum to use based on match type
    local match_type_index = matchType:Get()
    local is_ranked = match_type_index == 1  -- 1 = Ranked Classic
    local is_ranked_roles = match_type_index == 2  -- 2 = Ranked Roles

    local game_mode_enum
    if is_ranked_roles then
        game_mode_enum = ENUM_GAME_MODES_RANKED
        print("Using Ranked Roles game modes")
    elseif is_ranked then
        game_mode_enum = ENUM_GAME_MODES_RANKED
        print("Using Ranked Classic game modes")
    else
        game_mode_enum = ENUM_GAME_MODES
        print("Using Normal game modes")
    end

    for _, GameMode in pairs(enabled_modes) do
        if GameMode ~= "Last Search" then
            local mode_bit = game_mode_enum[GameMode]
            if mode_bit then
                game_mode = game_mode | mode_bit
                print("Added game mode:", GameMode, "bit:", mode_bit)
            else
                print("Unknown game mode:", GameMode)
            end
        end
    end

    for _, MatchGroup in pairs(matchgroup_selector:ListEnabled()) do
        matchgroup = matchgroup | ENUM_MATCHGROUPS[MatchGroup];
    end

    -- Get the match type value based on index
    local match_type_value
    local solo_queue = false
    local lane_selection_flags = 0
    local region_select_flags = 137  -- From your recording

    if match_type_index == 0 then
        match_type_value = "MATCH_TYPE_CASUAL"      -- Normal/Unranked
        solo_queue = false
        lane_selection_flags = 0
    elseif match_type_index == 1 then
        match_type_value = "MATCH_TYPE_COMPETITIVE" -- Ranked Classic
        solo_queue = false
        lane_selection_flags = 0
    elseif match_type_index == 2 then
        match_type_value = "MATCH_TYPE_COMPETITIVE" -- Ranked Roles
        solo_queue = false
        -- Get the role from the dropdown
        local role_name = ROLE_NAMES[roleSelector:Get() + 1]
        lane_selection_flags = ROLE_FLAGS[role_name] or 1  -- Default to 1 if not found
        print("Selected role:", role_name, "Flag:", lane_selection_flags)
    else
        match_type_value = "MATCH_TYPE_CASUAL"      -- Default to Normal
        solo_queue = false
        lane_selection_flags = 0
    end

    print("Match type index:", match_type_index)
    print("Match type value:", match_type_value)
    print("Solo queue:", solo_queue)
    print("Lane selection flags:", lane_selection_flags, "(" .. resolveLaneFlags(lane_selection_flags) .. ")")
    print("Game mode:", game_mode)
    print("Matchgroup:", matchgroup)

    -- Build search parameters
    local search_params = {
        matchgroups = matchgroup,
        game_modes = game_mode,
        match_type = match_type_value,
        solo_queue = solo_queue,
        lane_selection_flags = lane_selection_flags,
        -- Add other required fields from your recording
        bot_difficulty_mask = 0,
        bot_script_index_mask = 0,
        custom_game_difficulty_mask = 0,
        disable_experimental_gameplay = true,
        high_priority_disabled = false,
        is_challenge_match = false,
        matchlanguages = 0,
        region_select_flags = region_select_flags,
        steam_clan_account_id = 0,
        team_id = 0,
    }

    -- Add Ranked specific fields from your recording
    if is_ranked or is_ranked_roles then
        search_params.client_version = 6839
        search_params.game_language_enum = "MATCH_LANGUAGE_ENGLISH"
        search_params.game_language_name = "english"
        print("Added Ranked specific fields")
    end

    print("Final search params:", JSON:encode(search_params))

    local start_finding_match = protobuf.encodeFromJSON('CMsgStartFindingMatch', JSON:encode(search_params));
    GC.SendMessage(start_finding_match.binary, 7033, start_finding_match.size);
    print("Search message sent!")

    local match_label = "Normal"
    if match_type_index == 1 then
        match_label = "Ranked Classic"
    elseif match_type_index == 2 then
        match_label = "Ranked Roles"
    end
    local role_display = (match_type_index == 2)
    and (" [" .. resolveLaneFlags(lane_selection_flags) .. "]")
    or ""
ntfy_post("✅ " .. match_label .. role_display .. " match search started!", "Dota 2", "default")

    if enableKeyOnSearch:Get() then
        local selectedKey = keys[targetKey:Get() + 1]
        local selectedMode = keyMode:Get()

        if selectedMode == 1 then
            sendKeyCommand(selectedKey, "press", "down")
            sendKeyCommand(selectedKey, "press", "up")
        elseif selectedMode == 2 then
            sendKeyCommand(selectedKey, "hold", "start")
            sendKeyCommand(selectedKey, "hold", "stop")
        elseif selectedMode == 3 then
            sendKeyCommand(selectedKey, "toggle", "on")
            sendKeyCommand(selectedKey, "toggle", "off")
        end

        print("Key Emulator: Sent key command for search - Key: " .. selectedKey .. ", Mode: " .. selectedMode)
    end
end

-- Ntfy.sh polling function
-- Ntfy.sh polling function
local function poll_ntfy()
    if not ntfy_enabled or NTFY_TOPIC == "" then return end
    if is_polling then return end
    is_polling = true

    local since
    if last_message_id == nil then
        since = tostring(os.time())
    else
        since = last_message_id
    end

    local url = "https://ntfy.sh/" .. NTFY_TOPIC .. "/json?poll=1&since=" .. since

    HTTP.Request("GET", url, { timeout = 12.0 }, function(res)
        is_polling = false

        if tostring(res.code) ~= "200" then
            print("[UCZone] ntfy poll error, code: " .. tostring(res.code))
            return
        end

        local body = res.response or ""
        if body == "" or body:match("^%s*$") then
            print("[UCZone] ntfy poll OK — no new messages")
            return
        end

        local triggered = false
        local role_override = nil

        for line in body:gmatch("[^\n]+") do
            local ok_parse, msg = pcall(function() return JSON:decode(line) end)
            if ok_parse and msg and type(msg) == "table" then
                local msg_id   = tostring(msg.id or "")
                local msg_text = string.lower(tostring(msg.message or ""):gsub("^%s+", ""):gsub("%s+$", ""))

                if msg_id ~= "" and msg_id ~= last_message_id then
                    last_message_id = msg_id
                    print("[UCZone] ntfy [" .. msg_id .. "]: '" .. msg_text .. "'")

                    -- Role-specific command mapping
                    local role_mapping = {
                        ["safe"] = "Safe Lane",
                        ["safelane"] = "Safe Lane",
                        ["carry"] = "Safe Lane",
                        ["mid"] = "Mid Lane",
                        ["midlane"] = "Mid Lane",
                        ["off"] = "Off Lane",
                        ["offlane"] = "Off Lane",
                        ["support"] = "Support",
                        ["sup"] = "Support",
                        ["hard support"] = "Hard Support",
                        ["hardsup"] = "Hard Support",
                        ["core"] = "Core (Safe+Mid+Off)",
                        ["all"] = "All Roles",
                        ["allroles"] = "All Roles",
                        ["roam"] = "Support+Hard Support",
                    }

                    -- Check for role keywords
                    for keyword, role_name in pairs(role_mapping) do
                        if msg_text == keyword or msg_text:find(keyword) then
                            role_override = role_name
                            print("[UCZone] Role override detected: " .. role_name)
                            break
                        end
                    end

                    -- Check if this is a search command (including role keywords)
                    if not triggered and (
                        msg_text == "start_queue" or
                        msg_text == "queue" or
                        msg_text == "find match" or
                        msg_text == "search" or
                        msg_text == "play" or
                        msg_text == "go" or
                        msg_text == "start" or
                        msg_text == "match" or
                        msg_text == "auto search" or
                        msg_text == "safe" or
                        msg_text == "mid" or
                        msg_text == "off" or
                        msg_text == "support" or
                        msg_text == "carry" or
                        msg_text == "core" or
                        msg_text == "all" or
                        msg_text == "roam"
                    ) then
                        triggered = true
                        Timers.ExecuteAfter(0.1, function()
                            print("[UCZone] Remote queue triggered!")

                            -- If role override is set and Ranked Roles is selected, update the role
                            if role_override and matchType:Get() == 2 then
                                for i, name in ipairs(ROLE_NAMES) do
                                    if name == role_override then
                                        roleSelector:Set(i - 1)
                                        print("[UCZone] Role set to: " .. role_override)
                                        break
                                    end
                                end
                            end

                            game_ended = false
                            search_match()
                        end)
                    end
                end
            end
        end
    end, "ntfy_poll")
end

-- Menu creation
local menu = Menu.Create("Miscellaneous", "Other", "Message Recorder");
local tab = menu:Create("Main");

-- Recording controls
local recording_group = tab:Create("Recording");
local start_button, stop_button, replay_button;

start_button = recording_group:Button("Start Recording", function()
    is_recording = true;
    message_count = 0;
    start_button:Disabled(true);
    stop_button:Disabled(false);
    print("Recording started - search message will be saved to db")
end, true)

stop_button = recording_group:Button("Stop Recording", function()
    is_recording = false;
    start_button:Disabled(false);
    stop_button:Disabled(true);
    replay_button:Disabled(false);
    print("Recording stopped - saved " .. message_count .. " messages to db")
end)

replay_button = recording_group:Button("Replay Message", function()
    if replayMessage() then
        print("Message sent successfully")
    else
        print("Failed to send message")
    end
end)

stop_button:Disabled(true);

-- Auto search game controls
-- NOTE: Assign to the forward-declared locals (no 'local' keyword here).
-- Auto search game controls
-- Auto search game controls
local auto_search_game_group = tab:Create("Auto Search Game");
game_mode_selector  = auto_search_game_group:MultiCombo("Game Mode",   GAME_MODES,   {});
matchgroup_selector = auto_search_game_group:MultiCombo("Match Group",  MATCHGROUPS,  {});
matchType           = auto_search_game_group:Combo("Match Type", {"Normal", "Ranked Classic", "Ranked Roles"}, 0, "🏆");
roleSelector        = auto_search_game_group:Combo("Ranked Role", ROLE_NAMES, 0, "🎯");  -- <-- ADD THIS LINE
roleSelector:ToolTip("Select which role to queue for in Ranked Roles");  -- <-- ADD THIS LINE
roleSelector:Visible(false);  -- <-- ADD THIS LINE - hidden by default


matchType:SetCallback(function(self)
    local selected = self:Get()
    if selected == 2 then  -- Ranked Roles selected
        roleSelector:Visible(true)
    else
        roleSelector:Visible(false)
    end
end, true);


local auto_queue_switch = auto_search_game_group:Switch("Auto-queue on game end", true);  -- <-- ADD THIS LINE
auto_queue_switch:ToolTip("Automatically start a new match when game ends");  -- <-- ADD THIS LINE
auto_queue_switch:SetCallback(function(self)  -- <-- ADD THIS LINE
    auto_queue_on_end = self:Get();  -- <-- ADD THIS LINE
    print("[UCZone] Auto-queue on game end = " .. tostring(auto_queue_on_end));  -- <-- ADD THIS LINE
end, true);

-- ===== ADD THIS DEBUG SECTION HERE =====
local debug_group = tab:Create("Debug");
debug_group:Button("Show Recorded Match Type", function()
    if db.autoSearch.last_search_params_json then
        local success, params = pcall(JSON.decode, JSON, db.autoSearch.last_search_params_json)
        if success and params then
            print("=== RECORDED MATCH TYPE ===")
            print("match_type:", params.match_type)
            print("matchgroups:", params.matchgroups)
            print("game_modes:", params.game_modes)
            print("Full params:", JSON:encode(params))
            ntfy_post("📊 match_type = " .. tostring(params.match_type), "Dota 2", "default")
        else
            print("Failed to decode recorded search")
            ntfy_post("❌ Failed to decode recorded search", "Dota 2", "low")
        end
    else
        print("No recorded search found!")
        ntfy_post("❌ No recorded search found - record a match first", "Dota 2", "low")
    end
end, false, 1.0);

debug_group:Button("Verify Queued Role", function()
    local local_player = Players.GetLocal()
    if not local_player then
        print("No local player found (expected if in queue)")
    end

    -- 1. Check what was sent in the last search params
    if db.autoSearch.last_search_params_json then
        local ok, params = pcall(JSON.decode, JSON, db.autoSearch.last_search_params_json)
        if ok and params then
            local flag = params.lane_selection_flags or 0
            print("=== QUEUED ROLE FLAGS ===")
            print("lane_selection_flags sent:", flag)

            -- Reverse-lookup which role name matches the flag
            for role_name, role_flag in pairs(ROLE_FLAGS) do
                if role_flag == flag then
                    print("Matched role: " .. role_name)
                    ntfy_post("✅ Queued as: " .. role_name .. " (flag=" .. flag .. ")", "Dota 2", "default")
                end
            end

            if flag == 0 then
                ntfy_post("ℹ️ No role flag set (Normal/Ranked Classic)", "Dota 2", "low")
            end
        end
    else
        print("No recorded search found in db")
    end

    -- 2. If in a game, also check GetTeamData for the live lane_selection_flags
    if local_player then
        local team_data = Player.GetTeamData(local_player)
        if team_data then
            print("Live lane_selection_flags from GetTeamData:", team_data.lane_selection_flags)
        end
    end
end, false, 1.0)
-- ===== END OF DEBUG SECTION =====

-- Ntfy.sh controls
local ntfy_group = tab:Create("Ntfy Remote Queue");
local ntfy_topic_input = ntfy_group:Input("ntfy topic", "");
ntfy_topic_input:ToolTip("Your ntfy.sh topic name");
ntfy_topic_input:SetCallback(function(self)
    NTFY_TOPIC = self:Get();
    last_message_id = nil;
    print("[UCZone] ntfy topic set to: " .. NTFY_TOPIC);
end, true);

local ntfy_switch = ntfy_group:Switch("Enable remote queue", true);
ntfy_switch:ToolTip("Poll ntfy.sh every 15s — send 'start_queue' to trigger search");
ntfy_switch:SetCallback(function(self)
    ntfy_enabled = self:Get();
    print("[UCZone] Remote queue enabled = " .. tostring(ntfy_enabled));
end, true);

local ntfy_poll_btn = ntfy_group:Button("Force poll now", function()
    if NTFY_TOPIC == "" then
        print("[UCZone] Cannot poll — topic is empty")
        return
    end
    last_poll_time = 0;
    print("[UCZone] Poll forced");
end, false, 0.5);

local ntfy_clear_btn = ntfy_group:Button("Clear topic", function()
    ntfy_topic_input:Set("");
    NTFY_TOPIC = "";
    last_message_id = nil;
    print("[UCZone] Topic cleared");
end, true, 0.5);

-- Key Emulator controls
-- NOTE: Assign to the forward-declared locals (no 'local' keyword here).
local key_emulator_group = tab:Create("Key Emulator");
enableKeyOnSearch = key_emulator_group:Switch("Enable Key on Search", false, "⌨️");
local keyBind     = key_emulator_group:Bind("Trigger Key (hold)", Enum.ButtonCode.KEY_G, "⌨️");
targetKey         = key_emulator_group:Combo("Target Key", keys, 1, "🎯");
keyMode           = key_emulator_group:Combo("Key Mode", {"Press", "Hold", "Toggle"}, 1, "🔄");
local autoHotkey  = key_emulator_group:Switch("Auto Hotkey (2s)", false, "⏱️");

-- Key Emulator state variables
local lastKeyBind = false
local isToggled = false
local autoHotkeyStarted = false
local autoHotkeyStartTime = 0
local autoHotkeyTriggered = false

-- Function to update matchgroup selector visibility
local function updateMatchgroupVisibility()
    local enabled_modes = game_mode_selector:ListEnabled();
    local show_matchgroup = true;

    for _, mode in pairs(enabled_modes) do
        if mode == "Last Search" then
            show_matchgroup = false;
            break;
        end
    end

    matchgroup_selector:Visible(show_matchgroup);
end

-- Set callback for game mode selector to update visibility
game_mode_selector:SetCallback(function(this)
    updateMatchgroupVisibility();
end);

local search_button = auto_search_game_group:Button("Search", function()
    search_match();
end);

local search_state_group = tab:Create("Search State");
local start_search_button = search_state_group:Button("Start", function() end, true);
search_state_group:Switch("##", true):Visible(false);
local stop_search_button = search_state_group:Button("Stop", function() end);

local search_state, update_search_state;
do
    update_search_state = function()
        search_state = Config.ReadInt("auto-search", "search-state", 0) == 1;
        if search_state then
            print("SEARCHING");
            search_match();
        else
            print("NOT SEARCHING");
        end
        start_search_button:Disabled(search_state);
        stop_search_button:Disabled(not search_state);
    end
end

start_search_button:SetCallback(function(this)
    Config.WriteInt("auto-search", "search-state", 1);
    update_search_state();
    search_match();
end);

stop_search_button:SetCallback(function(this)
    Config.WriteInt("auto-search", "search-state", 0);
    update_search_state();
end);

local game_ended = false;

update_search_state();

-- Main script return
return {
    OnFrame = function()
        Timers.Listener()

        -- Check Key Emulator status
        checkKeyEmulatorStatus()

        -- Ntfy.sh polling
        if ntfy_enabled and NTFY_TOPIC ~= "" then
            local now = os.time()
            if now - last_poll_time >= POLL_INTERVAL then
                last_poll_time = now
                poll_ntfy()
            end
        end

        -- Auto Hotkey logic
        if autoHotkey:Get() then
            if not autoHotkeyStarted then
                autoHotkeyStarted = true
                autoHotkeyStartTime = os.clock()
                autoHotkeyTriggered = false
                print("Key Emulator: AutoHotkey timer started")
            elseif not autoHotkeyTriggered and (os.clock() - autoHotkeyStartTime >= 2) then
                local targetKeySelected = keys[targetKey:Get() + 1]
                local keyModeSelected = keyMode:Get()
                if keyModeSelected == 1 then
                    sendKeyCommand(targetKeySelected, "press", "down")
                    sendKeyCommand(targetKeySelected, "press", "up")
                elseif keyModeSelected == 2 then
                    sendKeyCommand(targetKeySelected, "hold", "start")
                    sendKeyCommand(targetKeySelected, "hold", "stop")
                elseif keyModeSelected == 3 then
                    sendKeyCommand(targetKeySelected, "toggle", "on")
                    sendKeyCommand(targetKeySelected, "toggle", "off")
                end
                autoHotkeyTriggered = true
                print("Key Emulator: AutoHotkey triggered after 2s")
            end
        else
            autoHotkeyStarted = false
            autoHotkeyTriggered = false
        end

        -- Key Emulator: Handle key bind presses
        local keyBindPressed = keyBind:IsDown()
        local targetKeySelected = keys[targetKey:Get() + 1]
        local keyModeSelected = keyMode:Get()

        if keyBindPressed ~= lastKeyBind then
            lastKeyBind = keyBindPressed

            if keyModeSelected == 1 then
                if keyBindPressed then
                    sendKeyCommand(targetKeySelected, "press", "down")
                else
                    sendKeyCommand(targetKeySelected, "press", "up")
                end
            elseif keyModeSelected == 2 then
                if keyBindPressed then
                    sendKeyCommand(targetKeySelected, "hold", "start")
                else
                    sendKeyCommand(targetKeySelected, "hold", "stop")
                end
            elseif keyModeSelected == 3 then
                if keyBindPressed then
                    isToggled = not isToggled
                    if isToggled then
                        sendKeyCommand(targetKeySelected, "toggle", "on")
                    else
                        sendKeyCommand(targetKeySelected, "toggle", "off")
                    end
                end
            end
        end
    end,
    OnGCMessage = function(msg)
        if is_recording and msg.binary_buffer_send and msg.msg_type == 7033 then
            saveMessage(msg.msg_type, msg.binary_buffer_send, msg.size)
        end
        return true;
    end,
    OnGameEnd = function()
    if (not game_ended) then
        game_ended = true;
        print("GAME ENDED");

        -- Check if auto-queue is enabled
        if not auto_queue_on_end then
            print("Auto-queue disabled - not searching");
            ntfy_post("Game ended - auto-queue disabled", "Dota 2", "low")
            return;
        end

        print("GAME ENDED, SEARCHING");

        -- Send notification
        ntfy_post("Game ended - searching for new match", "Dota 2", "default")

        -- Key Emulator: Send key command when game ends and auto-search starts
        if enableKeyOnSearch:Get() then
            local selectedKey = keys[targetKey:Get() + 1]
            local selectedMode = keyMode:Get()

            if selectedMode == 1 then
                sendKeyCommand(selectedKey, "press", "down")
                sendKeyCommand(selectedKey, "press", "up")
            elseif selectedMode == 2 then
                sendKeyCommand(selectedKey, "hold", "start")
                sendKeyCommand(selectedKey, "hold", "stop")
            elseif selectedMode == 3 then
                sendKeyCommand(selectedKey, "toggle", "on")
                sendKeyCommand(selectedKey, "toggle", "off")
            end

            print("Key Emulator: Sent key command on game end - Key: " .. selectedKey .. ", Mode: " .. selectedMode)
        end

        Timers.ExecuteAfter(5, search_match);
    end
end
}