local rampage_timer = {}

local a = function (...) return ... end

local floor = math.floor
local sin = math.sin

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function rgba(r, g, b, al)
    return Color(floor(r), floor(g), floor(b), floor(clamp(al, 0, 255)))
end

local function fade(c, al)
    return Color(c.r, c.g, c.b, floor(clamp((c.a or 255) * al, 0, 255)))
end

local function damp(cur, target, lambda, dt)
    return cur + (target - cur) * (1 - math.exp(-lambda * dt))
end

local function ease_out_cubic(t) t = clamp(t, 0, 1); return 1 - (1 - t) ^ 3 end

local cfg = {
    config_path = "rampage_timer_panel.ini",
    window = 18.0,
    max_streak = 5,
    alpha_idle = 0.55,

    anim = { scale = 14, alpha = 12, color = 10, fill = 16 },

    panel = {
        W = 182,
        H = 76,

        pad = 12,
        round = 18,

        pip_h = 5,
        pip_gap = 5,
        pip_cy = 43,

        bar_h = 6,
        bar_y = 58,

        f_label = 16,
        f_small = 11,
    },

    levels = {
        [0] = { label = "ready", color = Color(150, 160, 180) },
        [1] = { label = "kill", color = Color(213, 246, 226) },
        [2] = { label = "double kill!", color = Color(200, 242, 212) },
        [3] = { label = "TRIPLE kill!", color = Color(127, 216, 255) },
        [4] = { label = "ULTRA KILL!", color = Color(255, 214, 232) },
        [5] = { label = "RAMPAGE!!!", color = Color(255, 90, 95) },
    },
}

local ui, render_ctx, state do
    local tab = Menu.Create("Scripts", "Other", "Rampage Timer")
    tab:Icon("\u{f54c}")
    local group = tab:Create("Main Settings"):Create("Timer")

    ui = {
        global_switch = group:Switch("Enabled", false, "\u{f00c}"),
        panel_scale = group:Slider("Scale", 75, 200, 100),
        min_streak = group:Slider("Show From Kills", 1, 5, 2),
        panel_lock = group:Switch("Lock Position", false, "\u{f023}"),
        show_idle = group:Switch("Show When Idle", true, "\u{f06e}"),
    }

    ui.min_streak:SetCallback(function ()
        ui.show_idle:Disabled(ui.min_streak:Get() ~= 1)
    end, true)

    render_ctx = {
        font_bold = Render.LoadFont("SF Pro Text", Enum.FontCreate.FONTFLAG_ANTIALIAS, 500),
        font_medium = Render.LoadFont("SF Pro Text", Enum.FontCreate.FONTFLAG_ANTIALIAS, 500),
    }

    state = {
        streak = 0,
        active = false,
        window_end = 0,

        pos = {
            x = 220,
            y = 220
        },

        dragging = false,
        mouse_was = false,

        drag_off = {
            x = 0,
            y = 0
        },

        alpha = 0,
        scale = 1,
        col = { r = 150, g = 160, b = 180 },
        fill = 0,
        appear_start = -10,
        pop_start = -10,
        shown_before = false,
        last_clock = os.clock(),
    }

    state.scale = (ui.panel_scale:Get() or 100) / 100
end

local helpers do
    helpers = {
        load_pos = a(function ()
            local x, y = 220, 220
            local f = io.open(cfg.config_path, "r")
            if f then
                for line in f:lines() do
                    local mx = line:match("pos_x=(%-?%d+)")
                    local my = line:match("pos_y=(%-?%d+)")
                    if mx then x = tonumber(mx) end
                    if my then y = tonumber(my) end
                end
                f:close()
            end
            return x, y
        end),

        save_pos = a(function (x, y)
            local f = io.open(cfg.config_path, "w")
            if f then
                f:write(string.format("pos_x=%d\npos_y=%d\n", floor(x), floor(y)))
                f:close()
            end
        end),

        is_credited_kill = a(function (source, target)
            local hero = Heroes.GetLocal()
            if not hero or not source or not target then return false end

            if not NPC.IsHero(target) then return false end
            if NPC.IsIllusion(target) then return false end
            if Entity.GetTeamNum(target) == Entity.GetTeamNum(hero) then return false end

            if source == hero or Entity.IsControllableByPlayer(source, Player.GetLocal()) then return true end
            return false
        end),

        register_kill = a(function (now)
            state.streak = state.streak + 1
            state.window_end = now + cfg.window
            state.active = true
            state.pop_start = os.clock()
        end),

        reset_streak = a(function ()
            state.streak = 0
            state.active = false
        end),

        handle_input = a(function (x, y, w, h)
            local cx, cy = Input.GetCursorPos()
            local down = Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE1)
            local inside = cx >= x and cx <= x + w and cy >= y and cy <= y + h

            if not ui.panel_lock:Get() then
                if inside and down and not state.mouse_was and not state.dragging then
                    state.dragging = true
                    state.drag_off.x = cx - state.pos.x
                    state.drag_off.y = cy - state.pos.y
                end
                if state.dragging then
                    if down then
                        state.pos.x = cx - state.drag_off.x
                        state.pos.y = cy - state.drag_off.y
                    else
                        state.dragging = false
                        helpers.save_pos(state.pos.x, state.pos.y)
                    end
                end
            else
                state.dragging = false
            end

            state.mouse_was = down
        end),

        draw_glass = a(function (x, y, w, h, r, al)
            Render.Blur(Vec2(x, y), Vec2(x + w, y + h), 0.7, 0.9 * al, r)

            Render.Shadow(Vec2(x, y), Vec2(x + w, y + h), rgba(0, 0, 0, 65 * al), 26, r, Enum.DrawFlags.ShadowCutOutShapeBackground, Vec2(0, 6))

            Render.Gradient(Vec2(x, y), Vec2(x + w, y + h), rgba(165, 173, 190, 9 * al), rgba(165, 173, 190, 9 * al), rgba(115, 123, 143, 11 * al), rgba(115, 123, 143, 11 * al), r)
            Render.Gradient(Vec2(x, y + h * 0.5), Vec2(x + w, y + h), rgba(0, 0, 0, 0), rgba(0, 0, 0, 0), rgba(10, 12, 18, 30 * al), rgba(10, 12, 18, 30 * al), r)
            Render.Gradient(Vec2(x, y), Vec2(x + w, y + h * 0.5), rgba(255, 255, 255, 40 * al), rgba(255, 255, 255, 40 * al), rgba(255, 255, 255, 0), rgba(255, 255, 255, 0), r)

            Render.OutlineGradient(Vec2(x, y), Vec2(x + w, y + h), rgba(255, 255, 255, 190 * al), rgba(255, 255, 255, 150 * al), rgba(255, 255, 255, 40 * al), rgba(255, 255, 255, 25 * al), r, Enum.DrawFlags.None, 1.6)

            Render.Rect(Vec2(x + 1.5, y + 1.5), Vec2(x + w - 1.5, y + h - 1.5), rgba(255, 255, 255, 22 * al), math.max(0, r - 1.5), Enum.DrawFlags.None, 1.0)
        end),
    }
end

local core do
    core = {
        on_kill = a(function (data)
            if not ui.global_switch:Get() then return end
            if not data then return end
            if not helpers.is_credited_kill(data.source, data.target) then return end
            helpers.register_kill(GameRules.GetGameTime())
        end),

        tick_time = a(function ()
            local now = os.clock()
            local dt = clamp(now - state.last_clock, 0, 0.05)
            state.last_clock = now
            return dt, now
        end),

        refresh_streak = a(function (logic_now)
            if state.active and logic_now >= state.window_end then
                helpers.reset_streak()
            end
        end),

        resolve_display = a(function (anim_now)
            local min_streak = ui.min_streak:Get() or 2
            local display = state.active and state.streak >= min_streak

            if display and not state.shown_before then
                state.appear_start = anim_now
                state.shown_before = true
            elseif not display then
                state.shown_before = false
            end

            return display
        end),

        target_alpha = a(function (display)
            if display then
                return 1.0
            elseif ui.min_streak:Get() == 1 and ui.show_idle:Get() and not state.active then
                return cfg.alpha_idle
            end
            return 0.0
        end),

        pick_level = a(function (shown_streak)
            if shown_streak >= 5 then
                local mult = shown_streak - 4
                return {
                    label = mult == 1 and "RAMPAGE!!!" or ("RAMPAGE x" .. mult),
                    color = cfg.levels[5].color,
                }
            end
            return cfg.levels[shown_streak] or cfg.levels[0]
        end),

        advance_fill = a(function (display, remaining, dt)
            local target = (display and cfg.window > 0) and (remaining / cfg.window) or 0
            if target > state.fill then
                state.fill = damp(state.fill, target, cfg.anim.fill, dt)
            else
                state.fill = target
            end
        end),

        build_frame = a(function ()
            local dt, anim_now = core.tick_time()
            local logic_now = GameRules.GetGameTime()

            core.refresh_streak(logic_now)
            local display = core.resolve_display(anim_now)

            state.scale = damp(state.scale, (ui.panel_scale:Get() or 100) / 100, cfg.anim.scale, dt)
            local s = state.scale
            local P = cfg.panel

            state.alpha = damp(state.alpha, core.target_alpha(display), cfg.anim.alpha, dt)
            local al = state.alpha

            local shown_streak = display and state.streak or 0
            local lvl = core.pick_level(shown_streak)

            state.col.r = damp(state.col.r, lvl.color.r, cfg.anim.color, dt)
            state.col.g = damp(state.col.g, lvl.color.g, cfg.anim.color, dt)
            state.col.b = damp(state.col.b, lvl.color.b, cfg.anim.color, dt)

            local remaining = math.max(0, state.window_end - logic_now)
            core.advance_fill(display, remaining, dt)

            local W = P.W * s
            local H = P.H * s

            local screen = Render.ScreenSize()
            state.pos.x = clamp(state.pos.x, 0, math.max(0, screen.x - W))
            state.pos.y = clamp(state.pos.y, 0, math.max(0, screen.y - H))

            if al < 0.01 then
                state.mouse_was = Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE1)
                return nil
            end

            helpers.handle_input(state.pos.x, state.pos.y, W, H)

            local appear = ease_out_cubic((anim_now - state.appear_start) / 0.32)
            local pulse = 0
            local pt = (anim_now - state.pop_start) / 0.42
            if pt >= 0 and pt <= 1 then pulse = sin(pt * math.pi) end

            local pad = P.pad * s
            local x = state.pos.x
            local y = state.pos.y + (1 - appear) * 8 * s

            return {
                now = anim_now,
                display = display,
                s = s,
                al = al,
                x = x,
                y = y,
                W = W,
                H = H,
                pad = pad,
                r = P.round * s,
                cx0 = x + pad,
                cw = W - pad * 2,
                col = rgba(state.col.r, state.col.g, state.col.b, 255),
                lvl = lvl,
                pulse = pulse,
                remaining = remaining,
                shown_streak = shown_streak,
            }
        end),

        draw_glow = a(function (f)
            if not (f.display and state.streak >= 4) then return end
            local g = 0.5 + 0.5 * sin(f.now * 3.0)
            Render.Shadow(Vec2(f.x, f.y), Vec2(f.x + f.W, f.y + f.H), fade(f.col, 0.45 * g * f.al), 34 * f.s, f.r, Enum.DrawFlags.ShadowCutOutShapeBackground, Vec2(0, 0))
        end),

        draw_label = a(function (f)
            local P = cfg.panel
            local row_cy = f.y + (P.pad + P.f_label / 2) * f.s
            local label_font = P.f_label * f.s * (1 + 0.16 * f.pulse)
            local lts = Render.TextSize(render_ctx.font_bold, label_font, f.lvl.label)
            local ly = row_cy - lts.y / 2

            Render.Text(render_ctx.font_bold, label_font, f.lvl.label, Vec2(f.cx0, ly), fade(Color(255, 255, 255), f.al))
        end),

        draw_timer = a(function (f)
            if not f.display then return end
            local P = cfg.panel
            local row_cy = f.y + (P.pad + P.f_label / 2) * f.s
            local sec_str = string.format("%.1fs", f.remaining)
            local sf = P.f_small * f.s
            local sts = Render.TextSize(render_ctx.font_medium, sf, sec_str)
            local sy = row_cy - sts.y / 2
            local sec_col
            if f.remaining <= 4 then
                local blink = 0.55 + 0.45 * math.abs(sin(f.now * 6))
                sec_col = fade(Color(255, 95, 95), blink * f.al)
            else
                sec_col = fade(Color(235, 238, 245), 0.9 * f.al)
            end
            Render.Text(render_ctx.font_medium, sf, sec_str, Vec2(f.cx0 + f.cw - sts.x, sy), sec_col)
        end),

        draw_pips = a(function (f)
            local P = cfg.panel
            local pip_h = P.pip_h * f.s
            local pip_gap = P.pip_gap * f.s
            local pip_w = (f.cw - pip_gap * 4) / 5
            local pip_cy = f.y + P.pip_cy * f.s
            for i = 1, 5 do
                local pxp = f.cx0 + (i - 1) * (pip_w + pip_gap)
                local lit = i <= f.shown_streak
                local sc = (lit and i == f.shown_streak) and (1 + 0.6 * f.pulse) or 1
                local hh = pip_h * sc
                local yy = pip_cy - hh / 2
                if lit then
                    Render.FilledRect(Vec2(pxp - 1, yy - 1), Vec2(pxp + pip_w + 1, yy + hh + 1), fade(f.col, 0.25 * f.al), (hh + 2) / 2)
                    Render.FilledRect(Vec2(pxp, yy), Vec2(pxp + pip_w, yy + hh), fade(f.col, f.al), hh / 2)
                else
                    Render.FilledRect(Vec2(pxp, yy), Vec2(pxp + pip_w, yy + hh), fade(Color(10, 12, 18), 0.35 * f.al), hh / 2)
                end
            end
        end),

        draw_bar = a(function (f)
            local P = cfg.panel
            local bar_h = P.bar_h * f.s
            local bar_y = f.y + P.bar_y * f.s
            Render.FilledRect(Vec2(f.cx0, bar_y), Vec2(f.cx0 + f.cw, bar_y + bar_h), fade(Color(10, 12, 18), 0.30 * f.al), bar_h / 2)

            local fw = f.cw * state.fill
            if fw > 1 then
                local col = f.col
                local top = rgba(math.min(col.r + 35, 255), math.min(col.g + 35, 255), math.min(col.b + 35, 255), 255)
                Render.Gradient(Vec2(f.cx0, bar_y), Vec2(f.cx0 + fw, bar_y + bar_h), fade(top, f.al), fade(top, f.al), fade(col, f.al), fade(col, f.al), bar_h / 2)
            end
        end),

        burmalda = a(function ()
            if not ui.global_switch:Get() then return end

            local f = core.build_frame()
            if not f then return end

            core.draw_glow(f)

            helpers.draw_glass(f.x, f.y, f.W, f.H, f.r, f.al)
            core.draw_label(f)
            core.draw_timer(f)
            core.draw_pips(f)
            core.draw_bar(f)
        end),
    }
end

do
    local px, py = helpers.load_pos()
    state.pos.x, state.pos.y = px, py
end

function rampage_timer.OnDraw()
    core.burmalda()
end

function rampage_timer.OnEntityKilled(data)
    core.on_kill(data)
end

rampage_timer.RegisterKill = function () helpers.register_kill(GameRules.GetGameTime()) end
rampage_timer.ResetStreak = helpers.reset_streak

return rampage_timer
