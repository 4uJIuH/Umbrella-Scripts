local script = {}

local WIDGETS_DIR = "scripts/html_widgets"

local tab = Menu.Create("General", "Main", "HTML Widget")
tab:Icon("\u{f121}")

local section = tab:Create("HTML Widget")
local grp = section:Create("Settings")
local grp_pos = section:Create("Position", 1)
local grp_widgets = section:Create("Loaded Widgets", 2)

local ui = {}
ui.enabled = grp:Switch("Enabled", true, "\u{f00c}")
ui.rescan = grp:Switch("Rescan HTML", false, "\u{f2f1}")
ui.pos_x = grp_pos:Slider("X", 0, 3840, 400, function(v) return v .. "px" end)
ui.pos_y = grp_pos:Slider("Y", 0, 2160, 200, function(v) return v .. "px" end)

local PID = {
    root = "ucw_r",
    header = "ucw_h",
    title = "ucw_t",
    tabs = "ucw_tb",
    sep = "ucw_s",
    body = "ucw_b",
    label = "ucw_l",
}

local root_panel, label_panel, tabs_panel
local ready, tabs_done = false, false
local lx, ly = -1, -1
local was_on = nil
local wlist = {}
local current = nil
local widget_switches = {}
local toggle_ready = false
local prev_rescan = false

local function css(t)
    local p = {}
    for k, v in pairs(t) do p[#p + 1] = k .. ": " .. v .. ";" end
    return table.concat(p, " ")
end

local function fread(path)
    local ok, fh = pcall(io.open, path, "r")
    if not ok or not fh then return nil end
    local d = fh:read("*a")
    fh:close()
    return d
end

local function basedir()
    local ok, d = pcall(Engine.GetCheatDirectory)
    return (ok and d) or "."
end

local function scan()
    local dir = (basedir() .. "/" .. WIDGETS_DIR):gsub("/", "\\")
    local files = {}
    local ok, h = pcall(io.popen, 'dir /b "' .. dir .. '\\*.html" 2>nul')
    if ok and h then
        for line in h:lines() do
            local n = line:match("^%s*(.+%.html)%s*$")
            if n then files[#files + 1] = n end
        end
        h:close()
    end
    table.sort(files)
    return files
end

local function prettify(s)
    return s:gsub("_", " "):gsub("(%a)([%w]*)", function(a, b) return a:upper() .. b end)
end

local function build()
    wlist = {}
    for _, f in ipairs(scan()) do
        local id = f:gsub("%.html$", ""):gsub("[^%w]", "_")
        wlist[#wlist + 1] = { id = id, name = prettify(id), kind = "file", file = f }
    end
end

local function find_hud()
    for _, n in ipairs({"DotaHud", "Hud", "DotaHUD"}) do
        local p = Panorama.GetPanelByName(n)
        if p and p:IsValid() then return p end
    end
    local p = Panorama.GetPanelByName("DOTAHud", true)
    return (p and p:IsValid()) and p or nil
end

local function rcss(x, y)
    return css({
        ["position"]         = "absolute",
        ["horizontal-align"] = "left",
        ["vertical-align"]   = "top",
        ["margin-left"]      = x .. "px",
        ["margin-top"]       = y .. "px",
        ["width"]            = "500px",
        ["min-height"]       = "80px",
        ["flow-children"]    = "down",
        ["padding"]          = "16px 20px",
        ["border-radius"]    = "12px",
        ["background-color"] = "gradient(linear, 0% 0%, 0% 100%, from(#07192ad8), to(#0c2740d8))",
        ["border"]           = "1px solid #4aa7ff66",
        ["box-shadow"]       = "#0a58a6aa 0px 0px 30px 0px",
        ["blur"]             = "gaussian(8px)",
        ["z-index"]          = "999",
        ["transition"]       = "margin 0.08s ease-out 0s",
    })
end

local function push(html)
    if label_panel and label_panel:IsValid() then
        label_panel:SetTextType(3)
        label_panel:SetText(html)
    end
end

local function activate(w)
    current = w
    local path = basedir() .. "/" .. WIDGETS_DIR .. "/" .. w.file
    local html = fread(path)
    push(html or ("<font color='#F44336' size='14'>Cannot load: " .. w.file .. "</font>"))
end

local function activate_by_id(id)
    for _, w in ipairs(wlist) do
        if w.id == id then
            activate(w)
            return true
        end
    end
    return false
end

local function wire_clicks()
    local js = string.format([[
        (function(){
            var r = $.GetContextPanel().FindChildTraverse("%s");
            if (!r) return;
            var t = r.FindChildTraverse("%s");
            if (!t) return;
            var ch = t.Children();
            for (var i = 0; i < ch.length; i++) {
                (function(c){
                    c.SetPanelEvent("onactivate", function(){
                        var s = c.GetParent().Children();
                        for (var j = 0; j < s.length; j++) {
                            s[j].SetAttributeString("act", "0");
                            s[j].style.backgroundColor = "#00000000";
                            s[j].style.color = "#888888";
                        }
                        c.SetAttributeString("act", "1");
                        c.style.backgroundColor = "#ffffff12";
                        c.style.color = "#7FDBCA";
                        r.SetAttributeString("ucw_sel", c.id);
                    });
                    c.SetPanelEvent("onmouseover", function(){
                        if (c.GetAttributeString("act","0") !== "1")
                            c.style.color = "#BBBBBB";
                    });
                    c.SetPanelEvent("onmouseout", function(){
                        if (c.GetAttributeString("act","0") !== "1")
                            c.style.color = "#888888";
                    });
                })(ch[i]);
            }
        })()
    ]], PID.root, PID.tabs)
    Engine.RunScript(js, root_panel)
end

local function make_tabs()
    if tabs_done or not tabs_panel or not tabs_panel:IsValid() then return end

    build()

    for i, w in ipairs(wlist) do
        local tid = PID.tabs .. "_" .. w.id
        local first = (i == 1)
        local btn = Panorama.CreatePanel("Label", tid, tabs_panel, nil, css({
            ["padding"]          = "4px 10px",
            ["color"]            = first and "#7FDBCA" or "#888888",
            ["font-size"]        = "12px",
            ["font-family"]      = "Radiance",
            ["border-radius"]    = "4px",
            ["margin-right"]     = "4px",
            ["background-color"] = first and "#ffffff12" or "#00000000",
            ["transition"]       = "color 0.1s ease-in-out 0s, background-color 0.1s ease-in-out 0s",
        }))
        if btn then
            btn:SetText(w.name)
            if first then btn:SetAttribute("act", "1") end
        end
    end

    wire_clicks()

    if #wlist == 0 then
        push("<font color='#888' size='14'>No widgets found.<br>Place .html files in html_widgets/ folder.</font>")
        tabs_done = true
        return
    end

    activate(wlist[1])
    if widget_switches[1] then
        widget_switches[1].prev = true
    end

    tabs_done = true
end

local function setup_widget_toggles()
    if toggle_ready or #wlist == 0 then return end
    for _, w in ipairs(wlist) do
        local sw = grp_widgets:Switch(w.name, false)
        widget_switches[#widget_switches + 1] = { id = w.id, obj = sw, prev = false }
    end
    if widget_switches[1] then
        widget_switches[1].prev = true
    end
    toggle_ready = true
end

local function init(x, y)
    if ready then return true end

    local hud = find_hud()
    if not hud then return false end

    local ex = hud:FindChildTraverse(PID.root)
    if ex and ex:IsValid() then
        root_panel = ex
        root_panel:SetStyle(rcss(x, y))
        root_panel:SetVisible(true)
        label_panel = ex:FindChildTraverse(PID.label)
        tabs_panel = ex:FindChildTraverse(PID.tabs)
        ready = true
        tabs_done = tabs_panel ~= nil and tabs_panel:GetChildCount() > 0
        return true
    end

    root_panel = Panorama.CreatePanel("Panel", PID.root, hud, nil, rcss(x, y))
    if not root_panel then return false end

    local hdr = Panorama.CreatePanel("Panel", PID.header, root_panel, nil, css({
        ["width"]          = "100%",
        ["flow-children"]  = "right",
        ["padding-bottom"] = "10px",
    }))

    if hdr then
        local ttl = Panorama.CreatePanel("Label", PID.title, hdr, nil, css({
            ["color"]        = "#7FDBCA",
            ["font-size"]    = "16px",
            ["font-family"]  = "Radiance",
            ["margin-right"] = "12px",
            ["vertical-align"] = "center",
        }))
        if ttl then
            ttl:SetTextType(3)
            ttl:SetText("<b>HTML Widgets</b>")
        end

        tabs_panel = Panorama.CreatePanel("Panel", PID.tabs, hdr, nil, css({
            ["flow-children"]  = "right",
            ["vertical-align"] = "center",
        }))
    end

    Panorama.CreatePanel("Panel", PID.sep, root_panel, nil, css({
        ["width"]            = "100%",
        ["height"]           = "1px",
        ["background-color"] = "#ffffff15",
        ["margin-bottom"]    = "10px",
    }))

    local body = Panorama.CreatePanel("Panel", PID.body, root_panel, nil, css({
        ["width"]      = "100%",
        ["min-height"] = "60px",
    }))

    if body then
        label_panel = Panorama.CreatePanel("Label", PID.label, body, nil, css({
            ["width"]       = "100%",
            ["color"]       = "#E0E0E0",
            ["font-size"]   = "14px",
            ["font-family"] = "Radiance",
            ["line-height"] = "140%",
        }))
        if label_panel then
            label_panel:SetTextType(3)
            label_panel:SetText("<font color='#666' size='14'>Loading...</font>")
        end
    end

    ready = true
    return true
end

local function show(state)
    if root_panel and root_panel:IsValid() then root_panel:SetVisible(state) end
end

local function repos(x, y)
    if x == lx and y == ly then return end
    if root_panel and root_panel:IsValid() then
        root_panel:SetStyle(rcss(x, y))
        lx, ly = x, y
    end
end

function script.SetHTML(html) push(html) end
function script.Reload() if current then activate(current) end end

function script.OnFrame()
    local on = ui.enabled:Get()

    if on ~= was_on then
        if on then
            local x, y = ui.pos_x:Get(), ui.pos_y:Get()
            if init(x, y) then show(true); lx, ly = x, y end
        else
            show(false)
        end
        was_on = on
    end

    if not on then return end

    if not ready then
        local x, y = ui.pos_x:Get(), ui.pos_y:Get()
        if not init(x, y) then return end
        show(true)
        lx, ly = x, y
    end

    if not tabs_done then make_tabs() end
    if tabs_done and not toggle_ready then setup_widget_toggles() end

    if root_panel and root_panel:IsValid() then
        local sel = root_panel:GetAttribute("ucw_sel", "")
        if sel ~= "" then
            root_panel:SetAttribute("ucw_sel", "")
            for _, w in ipairs(wlist) do
                if sel == PID.tabs .. "_" .. w.id then
                    activate(w)
                    break
                end
            end
        end
    end

    if toggle_ready then
        for _, t in ipairs(widget_switches) do
            local now = t.obj:Get()
            if now and not t.prev then
                activate_by_id(t.id)
            end
            t.prev = now
        end
    end

    local rescan_now = ui.rescan:Get()
    if rescan_now and not prev_rescan then
        Engine.ReloadScriptSystem()
    end
    prev_rescan = rescan_now

    repos(ui.pos_x:Get(), ui.pos_y:Get())
end

return script
