---@diagnostic disable: undefined-global, param-type-mismatch, inject-field

local script = {}

local tab = Menu.Create("General", "dota imba", "Main", "")
local grp_t    = tab:Create("Buttons")


local ui = {}

ui.chest_slot = grp_t:Slider("Treasure slot", 1, 12, 1,
    function(v) return "Slot " .. tostring(v) end)
ui.btn_select = grp_t:Button("Get any treasure", function()
    local slot = ui.chest_slot:Get()
    fire_event("select_treasure", { PlayerID = get_local_pid(), index = slot })
end)

ui.btn_roll = grp_t:Button("Roll Runes (free)", function()
    local pid = get_local_pid()
    fire_event("roll_runebox", { PlayerID = pid })
end)

ui.btn_rune1 = grp_t:Button("Select rune slot1 x3", function()
    local pid = get_local_pid()
    for _ = 1, 3 do
        fire_event("select_runebox", { PlayerID = pid, index = 1 })
    end
end)

ui.btn_rune2    = grp_t:Button("Select rune slot2 x3", function()
    local pid = get_local_pid()
    for _ = 1, 3 do
        fire_event("select_runebox", { PlayerID = pid, index = 2 })
    end
end)

ui.btn_rune3    = grp_t:Button("Select rune slot3 x3", function()
    if not ui.master:Get() then return end
    local pid = get_local_pid()
    for _ = 1, 3 do
        fire_event("select_runebox", { PlayerID = pid, index = 3 })
    end
end)

function get_local_pid()
    local p = Players.GetLocal()
    return p and Player.GetPlayerID(p) or 0
end

function fire_event(name, payload)
    local buf = {}
    for k, v in pairs(payload) do
        local tp = type(v)
        if tp == "string" then
            buf[#buf + 1] = '"' .. k .. '":"' .. v .. '"'
        elseif tp == "table" then           
            local a = {}
            for _, n in ipairs(v) do a[#a + 1] = tostring(n) end
            buf[#buf + 1] = '"' .. k .. '":[' .. table.concat(a, ",") .. ']'
        else                                
            buf[#buf + 1] = '"' .. k .. '":' .. tostring(v)
        end
    end
    local js = ('GameEvents.SendCustomGameEventToServer("%s",{%s})'):format(
        name, table.concat(buf, ","))
    local script = ([[
        (function () {
            var send = function () {
                if (typeof GameEvents === "undefined" ||
                    !GameEvents.SendCustomGameEventToServer) {
                    return;
                }
                %s;
            };
            $.Schedule(0, send);
        })();
    ]]):format(js)

    local context_names = { "Hud", "DotaHud", "CustomUIRoot", "Dashboard" }
    for _, context_name in ipairs(context_names) do
        local panel = Panorama.GetPanelByName(context_name, false)
        if panel and panel:IsValid() then
            if Engine.RunScript(script, panel) then
                return
            end
        end
        if Engine.RunScript(script, context_name) then
            return
        end
    end
end


function script.OnScriptsLoaded()
    print("dota imba script loaded")
end

return script
