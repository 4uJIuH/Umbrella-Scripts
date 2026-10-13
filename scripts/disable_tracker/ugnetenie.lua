

local VERSION = "1.0.0"
local oppression = {}

--#region Constants

local CC_TYPES = {
    {key = "sleep",   label = "SLEEP",    color = Color(130, 100, 255), state_name = "MODIFIER_STATE_STUNNED",           hard = true, alt_names = {"nightmare", "sleep", "song_of_the_siren"}},
    {key = "stun",    label = "STUN",     color = Color(255, 75, 75),   state_name = "MODIFIER_STATE_STUNNED",           hard = true},
    {key = "cyclone", label = "CYCLONE",  color = Color(180, 220, 255), state_name = "MODIFIER_STATE_INVULNERABLE",       hard = true, alt_names = {"cyclone", "euls", "wind_waker"}},
    {key = "hex",     label = "HEX",      color = Color(190, 90, 255),  state_name = "MODIFIER_STATE_HEXED",             hard = true},
    {key = "fear",    label = "FEAR",     color = Color(220, 70, 220),  state_name = "MODIFIER_STATE_FEARED",            hard = true},
    {key = "taunt",   label = "TAUNT",    color = Color(255, 110, 110), state_name = "MODIFIER_STATE_TAUNTED",           hard = true},
    {key = "root",    label = "ROOT",     color = Color(110, 220, 120), state_name = "MODIFIER_STATE_ROOTED",            hard = true},
    {key = "silence", label = "SILENCE",  color = Color(255, 205, 70),  state_name = "MODIFIER_STATE_SILENCED"},
    {key = "mute",    label = "MUTE",     color = Color(255, 150, 40),  state_name = "MODIFIER_STATE_MUTED",             alt_names = {"nullifier"}},
    {key = "disarm",  label = "DISARM",   color = Color(140, 150, 255), state_name = "MODIFIER_STATE_DISARMED"},
    {key = "break",   label = "BREAK",    color = Color(255, 120, 120), state_name = "MODIFIER_STATE_PASSIVES_DISABLED"},
    {key = "slow",    label = "SLOW",     color = Color(120, 200, 255)},
}

for _, t in ipairs(CC_TYPES) do
    t.state = t.state_name and Enum.ModifierState[t.state_name] or nil
end

--#endregion

--#region State

local my_hero = nil
local session = nil
local last_tick_time = 0
local current_cc = {}

local dragging = false
local drag_offset = Vec2(0, 0)

--#endregion

--#region UI Menu

local tab = Menu.Create("General", "Main", "Oppression Indicator")
tab:Icon("\u{f6b6}")

local grp_main = tab:Create("Main"):Create("Settings")

local ui = {}
ui.enabled       = grp_main:Switch("Enabled", true, "\u{f00c}")
ui.ignore_allies = grp_main:Switch("Ignore Ally CC", true, "\u{f05e}")
ui.show_current  = grp_main:Switch("Show status over hero", true, "\u{f06e}")
ui.show_panel    = grp_main:Switch("Show HUD widget", true, "\u{f06e}")

local grp_style = tab:Create("Style"):Create("Appearance & Colors")
ui.panel_x       = grp_style:Slider("Widget Position X", 0, 3840, 30)
ui.panel_y       = grp_style:Slider("Widget Position Y", 0, 2160, 350)
ui.panel_width   = grp_style:Slider("Widget Width", 180, 450, 240)
ui.font_size     = grp_style:Slider("Font Size", 11, 20, 14)
ui.corner_radius = grp_style:Slider("Corner Radius", 0, 16, 6)
ui.border_width  = grp_style:Slider("Border Thickness", 1, 3, 1)

ui.bg_alpha      = grp_style:Slider("Background Alpha", 0, 255, 220)
ui.bg_color      = grp_style:ColorPicker("Background Color", Color(20, 22, 28))
ui.border_color  = grp_style:ColorPicker("Border Color", Color(255, 255, 255, 30))
ui.title_color   = grp_style:ColorPicker("Title Text Color", Color(200, 205, 215))
ui.total_color   = grp_style:ColorPicker("Total Time Color", Color(255, 85, 85))
ui.text_color    = grp_style:ColorPicker("Row Text Color", Color(220, 225, 235))
ui.count_color   = grp_style:ColorPicker("Row Count Color", Color(130, 140, 160))
ui.value_color   = grp_style:ColorPicker("Row Value Color", Color(255, 255, 255))

ui.reset_session = grp_main:Button("Reset Current Session")

local function fmt_time(sec)
    sec = math.max(0, sec or 0)
    local m = math.floor(sec / 60)
    local s = sec % 60
    return string.format("%d:%04.1f", m, s)
end

local function new_session()
    local s = {
        total_cc = 0,
        types = {}
    }
    for _, t in ipairs(CC_TYPES) do
        s.types[t.key] = {time = 0, count = 0, was_active = false}
    end
    return s
end

local function is_from_enemy(mod)
    if not mod then return false end
    local caster = Modifier.GetCaster(mod)
    if not caster then return true end
    if ui.ignore_allies:Get() and Entity.IsSameTeam(caster, my_hero) and caster ~= my_hero then
        return false
    end
    return true
end

--#endregion

--#region Logic

local function track()
    if not ui.enabled:Get() then return end

    if not my_hero then my_hero = Heroes.GetLocal() return end
    if not Entity.IsAlive(my_hero) then last_tick_time = 0 return end

    local now = GameRules.GetGameTime()

    if last_tick_time == 0 then last_tick_time = now return end
    local dt = now - last_tick_time
    last_tick_time = now
    if dt <= 0 or dt > 0.5 or GameRules.IsPaused() then return end

    if not session then
        session = new_session()
    end

    local active_states = {}
    local is_sleeping = false

    local modifiers = NPC.GetModifiers(my_hero)
    for _, mod in ipairs(modifiers) do
        if is_from_enemy(mod) then
            local name = Modifier.GetName(mod) or ""
            local die_time = Modifier.GetDieTime(mod)
            local rem = die_time - now

            if rem > 0 then
                if name:find("nightmare") or name:find("sleep") or name:find("song_of_the_siren") then
                    is_sleeping = true
                    if not active_states["sleep"] or rem > active_states["sleep"] then
                        active_states["sleep"] = rem
                    end
                end

                for _, t in ipairs(CC_TYPES) do
                    if t.alt_names then
                        for _, alt in ipairs(t.alt_names) do
                            if name:find(alt) then
                                if not active_states[t.key] or rem > active_states[t.key] then
                                    active_states[t.key] = rem
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    local state_set = {}
    for _, t in ipairs(CC_TYPES) do
        if t.state and t.key ~= "sleep" then
            state_set[t.state] = true
        end
    end
    local durs = NPC.GetStatesDuration(my_hero, state_set)

    for _, t in ipairs(CC_TYPES) do
        if t.state and t.key ~= "sleep" and not is_sleeping then
            if durs[t.state] and durs[t.state] > 0 then
                if not active_states[t.key] or durs[t.state] > active_states[t.key] then
                    active_states[t.key] = durs[t.state]
                end
            end
        end
    end

    current_cc = {}
    local any_hard = false

    local in_hard_cc = is_sleeping
                    or (active_states["stun"] and active_states["stun"] > 0)
                    or (active_states["hex"] and active_states["hex"] > 0)
                    or (active_states["cyclone"] and active_states["cyclone"] > 0)
                    or (active_states["fear"] and active_states["fear"] > 0)

    for _, t in ipairs(CC_TYPES) do
        local active, rem = false, nil

        if t.key == "sleep" then
            active = is_sleeping
            rem = active_states["sleep"]
        elseif t.key == "slow" then
            local base = NPC.GetBaseSpeed(my_hero)
            local ms = NPC.GetMoveSpeed(my_hero)
            active = base > 0 and ms < base * 0.95 and not in_hard_cc
        elseif t.key == "silence" or t.key == "mute" or t.key == "disarm" then
            rem = active_states[t.key]
            active = rem ~= nil and rem > 0 and not in_hard_cc
        else
            rem = active_states[t.key]
            active = rem ~= nil and rem > 0
        end

        if t.hard and active then any_hard = true end

        local st = session.types[t.key]
        if active then
            st.time = st.time + dt
            if not st.was_active then st.count = st.count + 1 end
            table.insert(current_cc, {t = t, rem = rem})
        end
        st.was_active = active
    end

    if any_hard then session.total_cc = session.total_cc + dt end
end

--#endregion

--#region Render HUD & Drag

local font_main = Render.LoadFont("MuseoSansEx", Enum.FontCreate.FONTFLAG_ANTIALIAS)

local function draw_current_cc()
    if #current_cc == 0 then return end

    local pos = Entity.GetAbsOrigin(my_hero) + Vector(0, 0, NPC.GetHealthBarOffset(my_hero) + 35)
    local sp, visible = Render.WorldToScreen(pos)
    if not visible then return end

    for i, e in ipairs(current_cc) do
        local text = e.t.label
        if e.rem and e.rem > 0 then
            text = string.format("%s %.1fs", text, e.rem)
        end

        local f_size = ui.font_size:Get() + 2
        local sz = Render.TextSize(font_main, f_size, text)
        local y_off = sp.y + (i - 1) * (f_size + 6)

        Render.FilledRect(Vec2(sp.x - sz.x/2 - 6, y_off - 2), Vec2(sp.x + sz.x/2 + 6, y_off + f_size + 2), Color(15, 15, 20, 200), 4)
        Render.Rect(Vec2(sp.x - sz.x/2 - 6, y_off - 2), Vec2(sp.x + sz.x/2 + 6, y_off + f_size + 2), e.t.color, 4)

        Render.Text(font_main, f_size, text, Vec2(sp.x - sz.x / 2, y_off), Color(255, 255, 255))
    end
end

local function handle_drag_and_draw_panel()
    if not session then return end

    local x, y = ui.panel_x:Get(), ui.panel_y:Get()
    local w = ui.panel_width:Get()
    local f_size = ui.font_size:Get()
    local row_h = f_size + 8
    local header_h = f_size + 22
    local radius = ui.corner_radius:Get()
    local b_width = ui.border_width:Get()

    local active_rows = {}
    for _, t in ipairs(CC_TYPES) do
        local st = session.types[t.key]
        if st.time > 0 then
            table.insert(active_rows, {t = t, st = st})
        end
    end

    local h = header_h + (#active_rows * row_h) + 8

    local cx, cy = Input.GetCursorPos()
    local is_hover = cx >= x and cx <= x + w and cy >= y and cy <= y + header_h

    if Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE1) then
        if is_hover and not dragging then
            dragging = true
            drag_offset = Vec2(cx - x, cy - y)
        elseif dragging then
            ui.panel_x:Set(math.floor(cx - drag_offset.x))
            ui.panel_y:Set(math.floor(cy - drag_offset.y))
            x, y = ui.panel_x:Get(), ui.panel_y:Get()
        end
    else
        dragging = false
    end

    local base_bg = ui.bg_color:Get()
    local bg_col = Color(base_bg.r, base_bg.g, base_bg.b, ui.bg_alpha:Get())
    local border_col = ui.border_color:Get()

    Render.FilledRect(Vec2(x, y), Vec2(x + w, y + h), bg_col, radius)
    for i = 0, b_width - 1 do
        Render.Rect(Vec2(x - i, y - i), Vec2(x + w + i, y + h + i), border_col, radius)
    end

    Render.Text(font_main, f_size, "OPPRESSION", Vec2(x + 12, y + 8), ui.title_color:Get())

    local total_str = fmt_time(session.total_cc)
    local sz_tot = Render.TextSize(font_main, f_size, total_str)
    Render.Text(font_main, f_size, total_str, Vec2(x + w - sz_tot.x - 12, y + 8), ui.total_color:Get())

    Render.Line(Vec2(x + 8, y + header_h - 4), Vec2(x + w - 8, y + header_h - 4), Color(255, 255, 255, 15))

    local count_col_x = x + math.floor(w * 0.52)

    for i, row in ipairs(active_rows) do
        local ry = y + header_h + (i - 1) * row_h

        Render.FilledRect(Vec2(x + 10, ry + 3), Vec2(x + 13, ry + f_size), row.t.color, 2)

        Render.Text(font_main, f_size - 1, row.t.label, Vec2(x + 20, ry), ui.text_color:Get())

        local count_str = string.format("x%d", row.st.count)
        local sz_cnt = Render.TextSize(font_main, f_size - 1, count_str)
        Render.Text(font_main, f_size - 1, count_str, Vec2(count_col_x - sz_cnt.x / 2, ry), ui.count_color:Get())

        local time_str = fmt_time(row.st.time)
        local sz_val = Render.TextSize(font_main, f_size - 1, time_str)
        Render.Text(font_main, f_size - 1, time_str, Vec2(x + w - sz_val.x - 10, ry), ui.value_color:Get())
    end
end

--#endregion

--#region Callbacks

oppression.OnUpdate = function()
    track()
end

oppression.OnDraw = function()
    if not ui.enabled:Get() or not my_hero then return end

    if ui.show_current:Get() then
        draw_current_cc()
    end
    if ui.show_panel:Get() then
        handle_drag_and_draw_panel()
    end
end

ui.reset_session:SetCallback(function()
    session = new_session()
    current_cc = {}
end)

--#endregion

return oppression