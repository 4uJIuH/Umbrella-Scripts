local script = {}

local group = Menu.Create("General", "Visuals", "Old Last Match", "Settings", "General")
local tab = Menu.Find("General", "Visuals", "Old Last Match")
if tab then tab:Icon("\u{f1da}") end

local enabled = group:Switch("Enable", false, "\u{f011}")
enabled:ToolTip("Replaces main menu event/promo background with the old last match screen")

local check_delay = 0

local js_enable = [[
    (function() {
        var root = $.GetContextPanel();
        while (root && root.GetParent()) root = root.GetParent();
        if (!root) return;
        var bg = root.FindChildTraverse("DashboardBackgroundManager");
        if (!bg) return;

        var p = null;
        for (var i = 0; i < bg.GetChildCount(); i++) {
            var c = bg.GetChild(i);
            if (!c) continue;
            if (c.id == "CustomLastMatchBackground" || c.paneltype == "DOTADashboardBackgroundLastMatch") {
                if (!p) p = c; else c.DeleteAsync(0);
            } else if (c.visible || c.style.visibility != "collapse") {
                c.SetAttributeInt("was_vis", 1);
                c.style.visibility = "collapse";
                c.visible = false;
            }
        }

        if (!p) {
            p = $.CreatePanel("DOTADashboardBackgroundLastMatch", bg, "CustomLastMatchBackground");
            if (!p) return;
            p.AddClass("DashboardBackground");
        }

        p.style.width = "100%";
        p.style.height = "100%";
        p.style.visibility = "visible";
        p.visible = true;
        p.style.backgroundColor = "gradient( radial, 50% 25%, 0% 0%, 50% 65%, from( #3d556e ), color-stop( 0.6, #1b2633 ), to( #0b0f14 ) );";
    })();
]]

local js_disable = [[
    (function() {
        var root = $.GetContextPanel();
        while (root && root.GetParent()) root = root.GetParent();
        if (!root) return;
        var bg = root.FindChildTraverse("DashboardBackgroundManager");
        if (!bg) return;

        for (var i = bg.GetChildCount() - 1; i >= 0; i--) {
            var c = bg.GetChild(i);
            if (!c) continue;
            if (c.id == "CustomLastMatchBackground") {
                c.DeleteAsync(0);
            } else if (c.GetAttributeInt("was_vis", 0) == 1) {
                c.style.visibility = null;
                c.visible = true;
                c.SetAttributeInt("was_vis", 0);
            }
        }
        bg.SetAttributeString("override-background", "");
    })();
]]

local function update_bg()
    if Engine.GetUIState() ~= Enum.UIState.DOTA_GAME_UI_STATE_DASHBOARD then return end
    Engine.RunScript(enabled:Get() and js_enable or js_disable, "Dashboard")
end

enabled:SetCallback(update_bg)

function script.OnUpdateEx()
    if not enabled:Get() or Engine.GetUIState() ~= Enum.UIState.DOTA_GAME_UI_STATE_DASHBOARD then return end
    local time = GlobalVars.GetCurTime()
    if time - check_delay >= 1.0 then
        check_delay = time
        Engine.RunScript(js_enable, "Dashboard")
    end
end

function script.OnGameEnd()
    Engine.RunScript([[
        var root = $.GetContextPanel();
        while (root && root.GetParent()) root = root.GetParent();
        if (root) {
            var p = root.FindChildTraverse("CustomLastMatchBackground");
            if (p) p.DeleteAsync(0);
        }
    ]], "Dashboard")
end

return script