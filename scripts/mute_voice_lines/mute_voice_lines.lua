---@class MuteVoiceLines
local MuteVoiceLines = {
    chat_wheel_message_id = 501,
    mute_duration = 0.5,

    -- Если вам делать нечего - ловите и отлавливайте айдишники, которые вам нужны сами и добавляйте также, как снизу.
    blocked_voice_lines = {
        [166] = true,
    },
}

function MuteVoiceLines:Init()
    for id = 401851, 402082 do
        MuteVoiceLines.blocked_voice_lines[id] = true
    end

    self.menu = Menu.Create("Miscellaneous", "In Game", "Mute Voice Lines")
    self.menu:Icon("\u{f6a9}")

    self.menu_main = self.menu:Create("Main")
    self.menu_general = self.menu_main:Create("General")

    self.enable = self.menu_general:Switch("Enable", true, "\u{f05e}")
    self.enable_gear = self.enable:Gear("Settings")
    self.log_blocked = self.enable_gear:Switch("Log Muted Voice Lines", false, "\u{f188}")

    self.enable:SetCallback(function(widget)
        self.enable_gear:Visible(widget:Get())
    end, true)
end

---@param player_id integer
function MuteVoiceLines:MutePlayerBriefly(player_id)
    Engine.RunScript([[
(function () {
    var playerId = ]] .. player_id .. [[;
    var states = Game.__muteVoiceLinesStates || (Game.__muteVoiceLinesStates = {});
    var state = states[playerId];

    if (!state) {
        state = states[playerId] = {
            generation: 0,
            restore: !Game.IsPlayerMuted(playerId)
        };

        if (state.restore) {
            Game.SetPlayerMuted(playerId, true);
        }
    }

    state.generation++;
    var generation = state.generation;

    $.Schedule(]] .. self.mute_duration .. [[, function () {
        if (states[playerId] !== state || state.generation !== generation) {
            return;
        }

        if (state.restore) {
            Game.SetPlayerMuted(playerId, false);
        }

        delete states[playerId];
    });
})();
]], "Dashboard")
end

---@param data PostReceivedNetMessageData
function MuteVoiceLines:OnPostReceivedNetMessage(data)
    if not self.enable:Get()
        or data.message_id ~= self.chat_wheel_message_id
        or data.msg_object == nil then
        return
    end

    local protobuf_success, json = pcall(
        XHelpers.protobuf.decodeToJSONfromObject,
        data.msg_object
    )
    if not protobuf_success or type(json) ~= "string" then
        return
    end

    local json_success, message = pcall(XHelpers.JSON.decode, XHelpers.JSON, json)
    if not json_success or type(message) ~= "table" then
        return
    end

    local voice_line_id = message.chat_message_id
    local player_id = message.player_id
    if not self.blocked_voice_lines[voice_line_id]
        or type(player_id) ~= "number"
        or player_id < 0 then
        return
    end

    if self.log_blocked:Get() then
        print("[MuteVoiceLines] line = " .. voice_line_id .. " | player = " .. player_id)
    end

    self:MutePlayerBriefly(player_id)
end

return XHelpers.WrapCallbacks(MuteVoiceLines, "mute_voice_lines")
