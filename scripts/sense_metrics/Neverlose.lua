
local script = {}
local ui = {}

local INI_PATH = "neverlose_metrics.ini"


local cfg = {
    enabled        = true,
    panel_open     = true,
    lock_panel     = false,

    tag_text       = "NL",
    scale_pct      = 100,
    accent         = Color(40, 170, 255, 255),


    show_ping      = true,
    show_game_time = true,
    show_fps       = false,
    show_farm      = true,


    farm_target_gpm = 540,


    show_buyback   = true,


    panel_x        = 25,
    panel_y        = 90,
    wm_margin_x    = 15,
    wm_y           = 15,
    bb_offset_y    = 10,
}

local st = {
    font       = nil,
    font_bold  = nil,

    ping_ms    = 0,
    fps        = 0,
    ft_smooth  = 0,
    last_ping_t = 0,

    dota_time   = nil,
    gpm         = nil,
    earned_gold = nil,

    dragging   = false,
    drag_off   = Vec2(0, 0),
}


local function tobool(v)
    v = tostring(v or ""):lower()
    return v == "1" or v == "true" or v == "yes" or v == "on"
end

local function clamp(x, a, b)
    if x < a then return a end
    if x > b then return b end
    return x
end

local function lerp(a, b, t) return a + (b - a) * t end
local function round(x) return math.floor(x + 0.5) end
local function floor(x) return math.floor(x) end

local function safe_call(fn, ...)
    local ok, res = pcall(fn, ...)
    if ok then return res end
    return nil
end

local function is_ctrl_down()
    return Input.IsKeyDown(Enum.ButtonCode.KEY_LCONTROL) or Input.IsKeyDown(Enum.ButtonCode.KEY_RCONTROL)
end

local function in_rect(mx, my, x1, y1, x2, y2)
    return mx >= x1 and mx <= x2 and my >= y1 and my <= y2
end

local function fmt_mmss(sec)
    if type(sec) ~= "number" then return nil end
    local sign = ""
    if sec < 0 then sign, sec = "-", -sec end
    local m = floor(sec / 60)
    local s = floor(sec % 60)
    return string.format("%s%02d:%02d", sign, m, s)
end


local function ini_save()
    local f = io.open(INI_PATH, "w")
    if not f then return end
    local function w(k, v) f:write(k .. "=" .. tostring(v) .. "\n") end

    w("enabled",      cfg.enabled and 1 or 0)
    w("panel_open",   cfg.panel_open and 1 or 0)
    w("lock_panel",   cfg.lock_panel and 1 or 0)

    w("tag_text",     cfg.tag_text or "NL")
    w("scale_pct",    cfg.scale_pct or 100)

    w("accent_r", cfg.accent.r); w("accent_g", cfg.accent.g); w("accent_b", cfg.accent.b); w("accent_a", cfg.accent.a)

    w("show_ping",      cfg.show_ping and 1 or 0)
    w("show_game_time", cfg.show_game_time and 1 or 0)
    w("show_fps",       cfg.show_fps and 1 or 0)
    w("show_farm",      cfg.show_farm and 1 or 0)
    w("farm_target_gpm", cfg.farm_target_gpm or 540)

    w("show_buyback", cfg.show_buyback and 1 or 0)

    w("panel_x", round(cfg.panel_x))
    w("panel_y", round(cfg.panel_y))
    w("wm_margin_x", round(cfg.wm_margin_x))
    w("wm_y", round(cfg.wm_y))
    w("bb_offset_y", round(cfg.bb_offset_y))

    f:close()
end

local function ini_load()
    local f = io.open(INI_PATH, "r")
    if not f then return end

    for line in f:lines() do
        local k, v = line:match("^([^=]+)=(.*)$")
        if k and v then
            if k == "enabled" then cfg.enabled = tobool(v)
            elseif k == "panel_open" then cfg.panel_open = tobool(v)
            elseif k == "lock_panel" then cfg.lock_panel = tobool(v)

            elseif k == "tag_text" then cfg.tag_text = v
            elseif k == "scale_pct" then cfg.scale_pct = tonumber(v) or cfg.scale_pct

            elseif k == "accent_r" then cfg.accent.r = tonumber(v) or cfg.accent.r
            elseif k == "accent_g" then cfg.accent.g = tonumber(v) or cfg.accent.g
            elseif k == "accent_b" then cfg.accent.b = tonumber(v) or cfg.accent.b
            elseif k == "accent_a" then cfg.accent.a = tonumber(v) or cfg.accent.a

            elseif k == "show_ping" then cfg.show_ping = tobool(v)
            elseif k == "show_game_time" then cfg.show_game_time = tobool(v)
            elseif k == "show_fps" then cfg.show_fps = tobool(v)
            elseif k == "show_farm" then cfg.show_farm = tobool(v)
            elseif k == "farm_target_gpm" then cfg.farm_target_gpm = tonumber(v) or cfg.farm_target_gpm

            elseif k == "show_buyback" then cfg.show_buyback = tobool(v)

            elseif k == "panel_x" then cfg.panel_x = tonumber(v) or cfg.panel_x
            elseif k == "panel_y" then cfg.panel_y = tonumber(v) or cfg.panel_y
            elseif k == "wm_margin_x" then cfg.wm_margin_x = tonumber(v) or cfg.wm_margin_x
            elseif k == "wm_y" then cfg.wm_y = tonumber(v) or cfg.wm_y
            elseif k == "bb_offset_y" then cfg.bb_offset_y = tonumber(v) or cfg.bb_offset_y
            end
        end
    end

    f:close()
end


local Theme = {}

function Theme:Scale()
    return (cfg.scale_pct or 100) / 100.0
end

function Theme:Accent()
    local a = cfg.accent or Color(40, 170, 255, 255)
    return Color(a.r, a.g, a.b, 255)
end

function Theme:Bg()      return Color(20, 22, 26, 230) end
function Theme:Border()  return Color(255, 255, 255, 18) end
function Theme:Text()    return Color(235, 238, 245, 245) end
function Theme:Muted()   return Color(205, 210, 220, 235) end
function Theme:Sep()     return Color(120, 130, 145, 220) end
function Theme:Bad()     return Color(235, 110, 110, 255) end
function Theme:Good()    return Color(120, 210, 160, 255) end

local Draw = {}

function Draw:Shadow(p1, p2)
    if Render.Shadow then
        Render.Shadow(p1, p2, Color(0, 0, 0, 160), 24, 10)
    end
end

function Draw:Fill(p1, p2, c, r)
    if Render.FilledRect then
        Render.FilledRect(p1, p2, c, r or 0, 0)
    end
end

function Draw:Outline(p1, p2, c)
    if Render.OutlineRect then
        Render.OutlineRect(p1, p2, c, 0, 0)
        return
    end
    if not Render.Line then return end
    local x1, y1, x2, y2 = p1.x, p1.y, p2.x, p2.y
    Render.Line(Vec2(x1, y1), Vec2(x2, y1), c)
    Render.Line(Vec2(x2, y1), Vec2(x2, y2), c)
    Render.Line(Vec2(x2, y2), Vec2(x1, y2), c)
    Render.Line(Vec2(x1, y2), Vec2(x1, y1), c)
end

local function dot_sep(x, y, sc, col)
    if Render.FilledCircle then
        Render.FilledCircle(Vec2(x, y), floor(2 * sc), col)
    else
        Draw:Fill(Vec2(x, y), Vec2(x + floor(4*sc), y + floor(4*sc)), col, floor(2*sc))
    end
end

local function draw_signal_icon(x, y, sc, col)
    local w = floor(2.6 * sc)
    local gap = floor(2.0 * sc)
    local base = floor(12 * sc)
    for i = 1, 4 do
        local h = floor((i / 4) * base)
        local bx1 = x + (i - 1) * (w + gap)
        local by1 = y + (base - h)
        Draw:Fill(Vec2(bx1, by1), Vec2(bx1 + w, y + base), col, floor(1*sc))
    end
end


local function get_local_player()
    if Players and Players.GetLocal then
        return safe_call(Players.GetLocal)
    end
    return nil
end

local function get_team_player_table()
    local p = get_local_player()
    if not p then return nil end
    if Player and Player.GetTeamPlayer then
        return safe_call(Player.GetTeamPlayer, p)
    end
    return nil
end

local function get_dota_time_seconds()
    if GameRules and GameRules.GetDOTATime then
        local t = safe_call(GameRules.GetDOTATime, false, false)
        if type(t) == "number" then return t end
    end
    if GameRules and GameRules.GetGameTime then
        local t = safe_call(GameRules.GetGameTime)
        if type(t) == "number" then return t end
    end
    if GlobalVars and GlobalVars.GetGameTime then
        local t = safe_call(GlobalVars.GetGameTime)
        if type(t) == "number" then return t end
    end
    return nil
end

local function get_current_gold()
    local t = get_team_player_table()
    if not t then return nil end
    if type(t.reliable_gold) == "number" and type(t.unreliable_gold) == "number" then
        return t.reliable_gold + t.unreliable_gold
    end
    if type(t.gold) == "number" then return t.gold end
    if type(t.current_gold) == "number" then return t.current_gold end
    return nil
end

local function get_networth()
    local t = get_team_player_table()
    if not t then return nil end
    if type(t.networth) == "number" then return t.networth end
    if type(t.net_worth) == "number" then return t.net_worth end
    return nil
end

local function get_buyback_state()
    local t = get_team_player_table()
    if not t then return nil end

    local now = get_dota_time_seconds()
    local cd_end = t.buyback_cooldown_time
    local cd_custom = t.custom_buyback_cooldown

    local cd_left = 0
    if type(cd_custom) == "number" and cd_custom > 0 then
        cd_left = cd_custom
    elseif type(cd_end) == "number" and type(now) == "number" then
        cd_left = cd_end - now
    elseif type(cd_end) == "number" and type(now) ~= "number" then
        cd_left = cd_end
    end
    if cd_left < 0 then cd_left = 0 end

    local cost = nil
    if type(t.buyback_cost) == "number" then cost = t.buyback_cost end
    if type(t.buyback_cost_gold) == "number" then cost = t.buyback_cost_gold end
    if type(cost) ~= "number" then
        local nw = get_networth()
        if type(nw) == "number" then
            cost = floor(200 + (nw / 13))
        end
    end

    local gold = get_current_gold()
    local need = nil
    local ready_by_gold = nil
    if type(cost) == "number" and type(gold) == "number" then
        need = cost - gold
        if need < 0 then need = 0 end
        ready_by_gold = (gold >= cost)
    end

    local ready = (cd_left <= 0) and (ready_by_gold ~= false)
    return { cd_left = cd_left, cost = cost, gold = gold, need = need, ready = ready, ready_by_gold = ready_by_gold }
end


local function upd_ping()
    local ct = (GlobalVars.GetCurTime and GlobalVars.GetCurTime()) or 0
    if (ct - st.last_ping_t) < 1.0 then return end
    if NetChannel and NetChannel.GetLatency then
        local lat = safe_call(NetChannel.GetLatency)
        if type(lat) == "number" then st.ping_ms = round(lat * 1000) end
    end
    st.last_ping_t = ct
end

local function upd_fps()
    if not GlobalVars.GetAbsFrameTime then return end
    local ft = GlobalVars.GetAbsFrameTime()
    if not ft or ft <= 0.001 or ft >= 0.1 then return end
    if st.ft_smooth == 0 then st.ft_smooth = ft end
    st.ft_smooth = lerp(st.ft_smooth, ft, 0.10)
    st.fps = round(1.0 / st.ft_smooth)
end

local function upd_dota_cache()
    local t = get_team_player_table()
    st.dota_time = get_dota_time_seconds()


    local income = (t and type(t.income_gold) == "number") and t.income_gold or nil
    if income and income > 0 and income < 3000 then
        st.gpm = floor(income)
    else
        st.gpm = nil
    end


    local earned = nil
    if t then
        if type(t.totalearned_gold) == "number" then earned = t.totalearned_gold end
        if type(t.total_earned_gold) == "number" then earned = t.total_earned_gold end
    end


    local minutes = (type(st.dota_time) == "number" and st.dota_time > 0) and (st.dota_time / 60.0) or nil
    if type(earned) == "number" and minutes then

        local max_ok = 0
        if minutes < 5 then max_ok = 12000
        elseif minutes < 10 then max_ok = 22000
        elseif minutes < 20 then max_ok = 45000
        elseif minutes < 30 then max_ok = 80000
        else max_ok = 140000 end

        if earned < 0 or earned > max_ok then
            earned = nil
        end
    end

    if earned then
        st.earned_gold = floor(earned)
    else
        if minutes and st.gpm then
            st.earned_gold = floor(st.gpm * minutes)
        else
            st.earned_gold = nil
        end
    end
end


local function handle_drag(px, py, pw, ph, header_h)
    if cfg.lock_panel then
        st.dragging = false
        return
    end

    local mx, my = Input.GetCursorPos()
    local hover_header = in_rect(mx, my, px, py, px + pw, py + header_h)

    local ctrl = is_ctrl_down()
    local lmb  = Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE1)

    if ctrl and lmb and hover_header and not st.dragging then
        st.dragging = true
        st.drag_off = Vec2(mx - px, my - py)
    end

    if not st.dragging then return end

    if ctrl and lmb then
        local scr = Render.ScreenSize()
        cfg.panel_x = clamp(mx - st.drag_off.x, 0, scr.x - pw)
        cfg.panel_y = clamp(my - st.drag_off.y, 0, scr.y - ph)
    else
        st.dragging = false
        ini_save()
    end
end


local function build_watermark_segments()
    local seg = {}

    if cfg.show_ping then
        seg[#seg+1] = { kind="ping", text = tostring(st.ping_ms) .. " MS" }
    end

    if cfg.show_game_time then
        local s = (type(st.dota_time) == "number") and fmt_mmss(st.dota_time) or nil
        if s then seg[#seg+1] = { kind="plain", text = s } end
    end

    if cfg.show_fps and st.fps > 0 then
        seg[#seg+1] = { kind="plain", text = tostring(st.fps) .. " FPS" }
    end

    if cfg.show_farm and st.gpm and st.earned_gold and type(st.dota_time) == "number" and st.dota_time > 60 then
        local minutes = st.dota_time / 60.0
        local target = cfg.farm_target_gpm or 540
        local target_gold = floor(target * minutes)
        local delta = st.earned_gold - target_gold
        local dTxt = (delta >= 0) and ("+" .. tostring(delta) .. "g") or (tostring(delta) .. "g")
        seg[#seg+1] = { kind="plain", text = "GPM " .. tostring(st.gpm) }
        seg[#seg+1] = { kind="delta", text = dTxt, delta = delta }
    end

    return seg
end

local function draw_watermark()
    if not cfg.enabled then return nil end
    if not st.font or not st.font_bold then return nil end

    local sc = Theme:Scale()
    local fs = math.max(12, floor(13 * sc))

    local bg     = Theme:Bg()
    local border = Theme:Border()
    local muted  = Theme:Muted()
    local sepCol = Theme:Sep()
    local accent = Theme:Accent()

    local tag = cfg.tag_text
    if not tag or tag == "" then tag = "NL" end

    local segments = build_watermark_segments()
    if #segments == 0 then return nil end

    local padL  = floor(8  * sc)
    local padR  = floor(10 * sc)
    local padY  = floor(7  * sc)
    local rad   = floor(14 * sc)


    local tag_tw = Render.TextSize(st.font_bold, fs, tag).x
    local badgePadX = floor(10 * sc)
    local badgeW = clamp(tag_tw + badgePadX * 2, floor(32 * sc), floor(120 * sc))
    local badgeH = floor(20 * sc)
    local badgeR = floor(8  * sc)

    local iconW   = floor(16 * sc)
    local iconGap = floor(6 * sc)
    local dotGapL = floor(10 * sc)
    local dotGapR = floor(10 * sc)

    local contentW = 0
    for i = 1, #segments do
        local s = segments[i]
        local tw = Render.TextSize(st.font_bold, fs, s.text).x
        local addIcon = (s.kind == "ping")
        contentW = contentW + (addIcon and (iconW + iconGap) or 0) + tw
        if i < #segments then
            contentW = contentW + dotGapL + floor(4 * sc) + dotGapR
        end
    end

    local textH = Render.TextSize(st.font_bold, fs, "A").y
    local h = math.max(floor(28 * sc), textH + padY * 2)
    local w = padL + badgeW + floor(10 * sc) + contentW + padR

    local scr = Render.ScreenSize()
    local x = scr.x - w - (cfg.wm_margin_x or 15)
    local y = (cfg.wm_y or 15)

    Draw:Shadow(Vec2(x, y), Vec2(x + w, y + h))
    Draw:Fill(Vec2(x, y), Vec2(x + w, y + h), bg, rad)
    Draw:Outline(Vec2(x, y), Vec2(x + w, y + h), border)


    local bx1 = x + floor(6 * sc)
    local by1 = y + floor((h - badgeH) * 0.5)
    local bx2 = bx1 + badgeW
    Draw:Fill(Vec2(bx1, by1), Vec2(bx2, by1 + badgeH), accent, badgeR)

    Render.Text(st.font_bold, fs, tag, Vec2(bx1 + floor((badgeW - tag_tw) * 0.5), by1 + floor(2 * sc)), Color(255,255,255,255))


    local cx = bx2 + floor(10 * sc)
    local cy = y + floor((h - textH) * 0.5)

    for i = 1, #segments do
        local s = segments[i]

        if s.kind == "ping" then
            local ix = cx
            local iy = y + floor((h - floor(12*sc)) * 0.5)
            draw_signal_icon(ix, iy, sc, muted)
            cx = cx + iconW + iconGap
        end

        local col = muted
        if s.kind == "delta" and type(s.delta) == "number" then
            col = (s.delta < 0) and Theme:Bad() or Theme:Good()
        end

        Render.Text(st.font_bold, fs, s.text, Vec2(cx, cy), col)
        cx = cx + Render.TextSize(st.font_bold, fs, s.text).x

        if i < #segments then
            cx = cx + dotGapL
            dot_sep(cx, y + h * 0.5, sc, sepCol)
            cx = cx + dotGapR
        end
    end

    return { x = x, y = y, w = w, h = h }
end

local function draw_buyback_chip(wm_rect)
    if not cfg.enabled or not cfg.show_buyback then return end
    if not st.font or not st.font_bold then return end
    if not wm_rect then return end

    local bb = get_buyback_state()
    if not bb then return end

    local sc = Theme:Scale()
    local fs = math.max(12, floor(13 * sc))

    local bg     = Theme:Bg()
    local border = Theme:Border()
    local muted  = Theme:Muted()
    local accent = Theme:Accent()

    local rad = floor(14 * sc)
    local padX = floor(10 * sc)
    local padY = floor(7 * sc)

    local line1, line2, col1
    if bb.cd_left and bb.cd_left > 0 then
        line1 = "BB: " .. fmt_mmss(bb.cd_left)
        col1 = muted
    else
        if bb.ready_by_gold == false and type(bb.need) == "number" then
            line1 = "BB: -" .. tostring(bb.need) .. "g"
            col1 = Theme:Bad()
        else
            line1 = "BB: READY"
            col1 = accent
        end
    end

    if bb.ready_by_gold == false and type(bb.need) == "number" and (bb.cd_left or 0) <= 0 then
        line2 = "Need " .. tostring(bb.need) .. " gold"
    end

    local w1 = Render.TextSize(st.font_bold, fs, line1).x
    local w2 = line2 and Render.TextSize(st.font, fs, line2).x or 0
    local textH = Render.TextSize(st.font_bold, fs, "A").y
    local h = textH + padY * 2
    if line2 then h = h + floor(textH * 0.9) + floor(4 * sc) end

    local w = math.max(w1, w2) + padX * 2
    w = math.max(w, floor(160 * sc))

    local x = wm_rect.x + wm_rect.w - w
    local y = wm_rect.y + wm_rect.h + (cfg.bb_offset_y or 10)

    Draw:Shadow(Vec2(x, y), Vec2(x + w, y + h))
    Draw:Fill(Vec2(x, y), Vec2(x + w, y + h), bg, rad)
    Draw:Outline(Vec2(x, y), Vec2(x + w, y + h), border)

    Draw:Fill(Vec2(x + floor(10*sc), y + h - floor(2*sc)), Vec2(x + w - floor(10*sc), y + h - floor(1*sc)), Color(accent.r, accent.g, accent.b, 140), floor(2*sc))

    Render.Text(st.font_bold, fs, line1, Vec2(x + padX, y + padY), col1)
    if line2 then
        Render.Text(st.font, fs, line2, Vec2(x + padX, y + padY + textH + floor(4*sc)), muted)
    end
end


local function draw_settings_panel()
    if not cfg.panel_open then return end
    if not st.font or not st.font_bold then return end

    local sc = Theme:Scale()

    local px, py = cfg.panel_x, cfg.panel_y
    local pad = floor(12 * sc)
    local rad = floor(14 * sc)

    local bg     = Theme:Bg()
    local border = Theme:Border()
    local muted  = Theme:Muted()
    local text   = Theme:Text()
    local accent = Theme:Accent()

    local fs_t = math.max(12, floor(13 * sc))
    local fs_h = math.max(12, floor(14 * sc))

    local header_h = floor(34 * sc)
    local row_h = floor(30 * sc)

    local rows = {
        { key="show_ping",      label="Ping" },
        { key="show_game_time", label="Game time" },
        { key="show_fps",       label="FPS" },
        { key="show_farm",      label="Farm pace" },
        { key="show_buyback",   label="Buyback chip" },
    }

    local pw = floor(230 * sc)
    local ph = header_h + floor(8*sc) + #rows * row_h + floor(10*sc)


    Draw:Shadow(Vec2(px, py), Vec2(px + pw, py + ph))
    Draw:Fill(Vec2(px, py), Vec2(px + pw, py + ph), bg, rad)
    Draw:Outline(Vec2(px, py), Vec2(px + pw, py + ph), border)


    Draw:Fill(Vec2(px + floor(10*sc), py + floor(2*sc)), Vec2(px + pw - floor(10*sc), py + floor(3*sc)), Color(accent.r, accent.g, accent.b, 150), floor(2*sc))


    Render.Text(st.font_bold, fs_h, "Neverlose Metrics", Vec2(px + pad, py + floor(8*sc)), text)

    local mx, my = Input.GetCursorPos()
    local y = py + header_h

    local function draw_toggle(x, y, on)
        local w = floor(40 * sc)
        local h = floor(18 * sc)
        local r = floor(9  * sc)

        local bgc = on and Color(accent.r, accent.g, accent.b, 180) or Color(26, 30, 38, 230)
        Draw:Fill(Vec2(x, y), Vec2(x + w, y + h), bgc, r)
        Draw:Outline(Vec2(x, y), Vec2(x + w, y + h), Color(255,255,255,16))

        if Render.FilledCircle then
            local kr = floor(6 * sc)
            local kx = on and (x + w - kr - floor(4*sc)) or (x + kr + floor(4*sc))
            Render.FilledCircle(Vec2(kx, y + h * 0.5), kr, on and Color(255,255,255,255) or Color(150,160,175,240))
        end
        return w, h
    end

    for _, r in ipairs(rows) do
        local rx1, ry1 = px + pad, y
        local rx2, ry2 = px + pw - pad, y + row_h

        if in_rect(mx, my, rx1, ry1, rx2, ry2) then
            Draw:Fill(Vec2(rx1, ry1), Vec2(rx2, ry2), Color(255,255,255,8), floor(10*sc))
        end

        Render.Text(st.font, fs_t, r.label, Vec2(rx1, ry1 + floor(6*sc)), muted)

        local tw = floor(40*sc)
        local tx = px + pw - pad - tw
        local ty = ry1 + floor(6*sc)
        draw_toggle(tx, ty, cfg[r.key])

        if in_rect(mx, my, tx, ty, tx + tw, ty + floor(18*sc)) and Input.IsKeyDownOnce(Enum.ButtonCode.KEY_MOUSE1) then
            cfg[r.key] = not cfg[r.key]
            if ui.show and ui.show[r.key] and ui.show[r.key].Set then
                ui.show[r.key]:Set(cfg[r.key])
            end
            ini_save()
        end

        y = y + row_h
    end


    handle_drag(px, py, pw, ph, header_h)
end


local menu = Menu.Create("General", "Sense Metrics", "Sense")
menu:Icon("\u{f2db}")
local root = menu:Create("Neverlose Metrics")

local g_main = root:Create("Main")
ui.enabled    = g_main:Switch("Включить", true)
ui.panel_open = g_main:Switch("Show settings panel", true)
ui.lock_panel = g_main:Switch("Lock panel position", false)

local g_show = root:Create("Show")
ui.show = {}
ui.show.show_ping      = g_show:Switch("Ping", true)
ui.show.show_game_time = g_show:Switch("Game time", true)
ui.show.show_fps       = g_show:Switch("FPS", false)
ui.show.show_farm      = g_show:Switch("Farm pace (GPM vs target)", true)
ui.show.show_buyback   = g_show:Switch("Buyback chip", true)

local g_farm = root:Create("Farm")
ui.farm_target_gpm = g_farm:Slider("Target GPM", 200, 1000, 540, "%d")

local g_app = root:Create("Appearance")
ui.tag_text  = g_app:Input("Tag text", "NL")
ui.scale     = g_app:Slider("Масштаб", 70, 200, 100, "%d%%")
ui.accent    = g_app:ColorPicker("Accent color", Color(40, 170, 255, 255))

local g_keys = root:Create("Hotkeys")
ui.toggle_panel_key = g_keys:Bind("Toggle panel key", Enum.ButtonCode.KEY_INSERT)

local g_pos = root:Create("Position")
g_pos:Button("Reset panel position", function()
    cfg.panel_x, cfg.panel_y = 25, 90
    ini_save()
end)
g_pos:Button("Reset watermark position", function()
    cfg.wm_margin_x, cfg.wm_y = 15, 15
    ini_save()
end)


local function sync_from_menu()
    cfg.enabled     = ui.enabled:Get()
    cfg.panel_open  = ui.panel_open:Get()
    cfg.lock_panel  = ui.lock_panel:Get()

    cfg.tag_text    = ui.tag_text:Get()
    cfg.scale_pct   = ui.scale:Get()
    cfg.accent      = ui.accent:Get()

    cfg.show_ping      = ui.show.show_ping:Get()
    cfg.show_game_time = ui.show.show_game_time:Get()
    cfg.show_fps       = ui.show.show_fps:Get()
    cfg.show_farm      = ui.show.show_farm:Get()
    cfg.show_buyback   = ui.show.show_buyback:Get()

    cfg.farm_target_gpm = ui.farm_target_gpm:Get()
end

local function apply_to_menu()
    ui.enabled:Set(cfg.enabled)
    ui.panel_open:Set(cfg.panel_open)
    ui.lock_panel:Set(cfg.lock_panel)

    ui.tag_text:Set(cfg.tag_text)
    ui.scale:Set(cfg.scale_pct)
    ui.accent:Set(cfg.accent)

    ui.show.show_ping:Set(cfg.show_ping)
    ui.show.show_game_time:Set(cfg.show_game_time)
    ui.show.show_fps:Set(cfg.show_fps)
    ui.show.show_farm:Set(cfg.show_farm)
    ui.show.show_buyback:Set(cfg.show_buyback)

    ui.farm_target_gpm:Set(cfg.farm_target_gpm or 540)
end

local function handle_hotkey()
    local hk = ui.toggle_panel_key:Get()
    if hk ~= Enum.ButtonCode.KEY_NONE and Input.IsKeyDownOnce(hk) then
        cfg.panel_open = not cfg.panel_open
        ui.panel_open:Set(cfg.panel_open)
        ini_save()
    end
end


function script.OnScriptsLoaded()
    ini_load()
    apply_to_menu()

    st.font      = Render.LoadFont("Tahoma", Enum.FontCreate.FONTFLAG_ANTIALIAS, 500)
    st.font_bold = Render.LoadFont("Tahoma", Enum.FontCreate.FONTFLAG_ANTIALIAS, 700)
end

function script.OnDraw()
    sync_from_menu()
    handle_hotkey()

    if not cfg.enabled then return end

    upd_ping()
    upd_fps()
    upd_dota_cache()

    local wm_rect = draw_watermark()
    draw_buyback_chip(wm_rect)
    draw_settings_panel()
end

function script.OnGameEnd()
    st.dragging = false
end

return script
