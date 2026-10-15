--- Mini Games Menu, AI made
---@diagnostic disable: undefined-global, param-type-mismatch, inject-field

local script = {}

local DEBUG_LOG = false

local HTTP = HTTP -- см. MusicUI.lua — тот же способ обращения к HTTP


local function V(x, y) return Vec2(x, y) end

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

-- Render transform: lets every window be drawn/scaled around its own
-- origin (its top-left corner) without touching each game's own drawing
-- math, which stays in "logical" (unscaled) pixel coordinates.
local RT = { ox = 0, oy = 0, scale = 1 }
local function set_transform(ox, oy, scale)
    RT.ox, RT.oy, RT.scale = ox, oy, scale or 1
end
local function clear_transform()
    RT.ox, RT.oy, RT.scale = 0, 0, 1
end
local function tx(x) return RT.ox + (x - RT.ox) * RT.scale end
local function ty(y) return RT.oy + (y - RT.oy) * RT.scale end

local R = {}
function R.rect(x, y, w, h, c, rnd)
    local sx, sy = tx(x), ty(y)
    pcall(Render.FilledRect, V(sx, sy), V(sx + w * RT.scale, sy + h * RT.scale), c, (rnd or 0) * RT.scale)
end
function R.outline(x, y, w, h, c, rnd)
    local sx, sy = tx(x), ty(y)
    pcall(Render.Rect, V(sx, sy), V(sx + w * RT.scale, sy + h * RT.scale), c, (rnd or 0) * RT.scale)
end
function R.line(x1, y1, x2, y2, c, th)
    pcall(Render.Line, V(tx(x1), ty(y1)), V(tx(x2), ty(y2)), c, math.max(1, (th or 1) * RT.scale))
end
function R.circle(x, y, r, c, th, filled, segments)
    pcall(Render.Circle, V(tx(x), ty(y)), r * RT.scale, c, math.max(1, (th or 1) * RT.scale), 0, 1, filled or false, segments or 48)
end
function R.fcircle(x, y, r, c, segments)
    pcall(Render.FilledCircle, V(tx(x), ty(y)), r * RT.scale, c, 0, 1, segments or 48)
end
function R.text(font, size, s, x, y, c)
    if font then pcall(Render.Text, font, size * RT.scale, s, V(tx(x), ty(y)), c) end
end
function R.text_size(font, size, s)
    -- Intentionally NOT scaled: callers use this to lay out things in the
    -- same logical/unscaled coordinate space as everything else, and
    -- R.text() applies the scale itself when it actually draws.
    local ok, v = pcall(Render.TextSize, font, size, s)
    if ok and v then return v.x or 0, v.y or 0 end
    return #tostring(s) * size * 0.5, size
end
function R.text_centered(font, size, s, cx, cy, c)
    local w, h = R.text_size(font, size, s)
    R.text(font, size, s, cx - w / 2, cy - h / 2, c)
end
function R.text_right(font, size, s, rx, y, c)
    local w = R.text_size(font, size, s)
    R.text(font, size, s, rx - w, y, c)
end
-- Word-wraps `s` into up to max_lines lines that each fit within max_w,
-- drawing them starting at (x, y) with line_h spacing. The last visible
-- line is truncated with "..." if there was more text than fits. This is
-- what keeps long/dynamic status strings (e.g. casino win messages) from
-- being crammed into one line and overlapping neighboring text -- the
-- root cause of the header text collision bug. Returns how many lines
-- were actually drawn, so callers can reserve the right amount of space.
function R.text_wrap(font, size, s, x, y, max_w, line_h, c, max_lines, align_center)
    max_lines = max_lines or 2
    s = tostring(s or "")
    local words = {}
    for w in s:gmatch("%S+") do words[#words + 1] = w end
    if #words == 0 then return 0 end

    local lines = {}
    local cur = words[1]
    for i = 2, #words do
        local candidate = cur .. " " .. words[i]
        local w = R.text_size(font, size, candidate)
        if w <= max_w then
            cur = candidate
        else
            lines[#lines + 1] = cur
            cur = words[i]
            if #lines >= max_lines then break end
        end
    end
    if #lines < max_lines then lines[#lines + 1] = cur end

    local drawn = math.min(#lines, max_lines)
    for i = 1, drawn do
        local line = lines[i]
        if i == max_lines and i < #lines then
            while #line > 1 and R.text_size(font, size, line .. "...") > max_w do
                line = line:sub(1, #line - 1)
            end
            line = line .. "..."
        end
        if align_center then
            R.text_centered(font, size, line, x, y + (i - 1) * line_h, c)
        else
            R.text(font, size, line, x, y + (i - 1) * line_h, c)
        end
    end
    return drawn
end

local function point_in_rect(mx, my, x, y, w, h)
    return mx >= x and mx <= x + w and my >= y and my <= y + h
end

local function screen_size()
    local ok, w, h = pcall(Render.ScreenSize)
    if ok and type(w) == "number" then return w, h or 1080 end
    return 1920, 1080
end


local function mouse_pos()
    local ok, x, y = pcall(Input.GetCursorPos)
    if ok and type(x) == "number" then return x, y or 0 end
    return -9999, -9999
end

local function input_captured()
    local ok, v = pcall(Input.IsInputCaptured)
    return ok and v == true
end

local LMOUSE_CODES = {}
do
    if Enum and Enum.ButtonCode then
        if Enum.ButtonCode.KEY_MOUSE1 then LMOUSE_CODES[#LMOUSE_CODES + 1] = Enum.ButtonCode.KEY_MOUSE1 end
        if Enum.ButtonCode.MOUSE_LEFT then LMOUSE_CODES[#LMOUSE_CODES + 1] = Enum.ButtonCode.MOUSE_LEFT end
    end
    LMOUSE_CODES[#LMOUSE_CODES + 1] = 1
end

local RMOUSE_CODES = {}
do
    if Enum and Enum.ButtonCode then
        if Enum.ButtonCode.KEY_MOUSE2 then RMOUSE_CODES[#RMOUSE_CODES + 1] = Enum.ButtonCode.KEY_MOUSE2 end
        if Enum.ButtonCode.MOUSE_RIGHT then RMOUSE_CODES[#RMOUSE_CODES + 1] = Enum.ButtonCode.MOUSE_RIGHT end
    end
    RMOUSE_CODES[#RMOUSE_CODES + 1] = 2
end

local function any_key_down(codes)
    for i = 1, #codes do
        local ok, v = pcall(Input.IsKeyDown, codes[i])
        if ok and v then return true end
    end
    return false
end


local drag

local mouse_l = { down = false, prev = false, clicked = false }
local mouse_r = { down = false, prev = false, clicked = false }

local function update_mouse_state()
    local raw_l = any_key_down(LMOUSE_CODES)
    local raw_r = any_key_down(RMOUSE_CODES)

    mouse_l.prev = mouse_l.down
    mouse_l.down = raw_l
    mouse_l.clicked = raw_l and not mouse_l.prev

    mouse_r.prev = mouse_r.down
    mouse_r.down = raw_r
    mouse_r.clicked = raw_r and not mouse_r.prev
end



local FONT = {}
local fonts_ready = false
local function load_fonts()
    if fonts_ready then return end
    fonts_ready = true
    local flag = (Enum and Enum.FontCreate and Enum.FontCreate.FONTFLAG_ANTIALIAS) or 0
    local function mk(weight)
        local ok, f = pcall(Render.LoadFont, "Arial", flag, weight)
        return ok and f or nil
    end
    FONT.title = mk(800)
    FONT.body = mk(600)
    FONT.small = mk(400)
    FONT.big = mk(800)
end



local PANEL_BG = Color(18, 20, 26, 235)
local PANEL_BORDER = Color(255, 255, 255, 22)

local function draw_panel(x, y, w, h, title, status, accent, header_h)
    header_h = header_h or 34
    R.rect(x, y, w, h, PANEL_BG, 10)
    R.rect(x, y, w, header_h, Color(accent.r, accent.g, accent.b, 40), 10)
    R.outline(x, y, w, h, PANEL_BORDER, 10)
    R.line(x + 6, y + header_h, x + w - 6, y + header_h, Color(255, 255, 255, 25), 1)
    R.text(FONT.title, 15, title, x + 14, y + 8, Color(240, 240, 245, 255))
    if status and status ~= "" then
        R.text_right(FONT.small, 12, status, x + w - 14, y + header_h / 2 - 6, accent)
    end
   
    for i = 0, 2 do
        R.rect(x + w - 26 + i * 7, y + header_h / 2 - 5, 4, 10, Color(255, 255, 255, 70), 1)
    end

    -- resize grip, bottom-right corner
    local g = 14
    for i = 0, 2 do
        R.line(x + w - g + i * 5, y + h - 2, x + w - 2, y + h - g + i * 5, Color(255, 255, 255, 90), 2)
    end
end

local function draw_button(x, y, w, h, label, mx, my, hover_color, base_color)
    local hover = point_in_rect(mx, my, x, y, w, h)
    R.rect(x, y, w, h, hover and hover_color or base_color, 6)
    R.outline(x, y, w, h, Color(255, 255, 255, 35), 6)
    R.text_centered(FONT.small, 12, label, x + w / 2, y + h / 2, Color(240, 240, 245, 255))
    return hover
end



-- Natural (unscaled) size of each window, filled in by each game module
-- right after it computes its own *_W / *_H / *_HEADER constants. This is
-- what let OnDraw resolve those sizes later on (previously it referenced
-- the modules' local constants directly from outside their scope, which
-- silently resolved to nil globals -- see notes near script.OnDraw).
local PANEL_SIZE = {}

local pos = {
    ttt = {x = 40, y = 60, scale = 1},
    chess = {x = 330, y = 60, scale = 1},
    mine = {x = 800, y = 60, scale = 1},
    weather = {x = 1100, y = 60, scale = 1},
    sol = {x = 40, y = 380, scale = 1},
    battleship = {x = 420, y = 380, scale = 1},
    g2048 = {x = 940, y = 380, scale = 1},
    casino = {x = 1320, y = 380, scale = 1},
    calc = {x = 1320, y = 60, scale = 1},
}

local MIN_SCALE, MAX_SCALE = 0.6, 1.8

drag = {active_id = nil, gx = 0, gy = 0}
local resize = {active_id = nil}

local function panel_drag(id, pos_tbl, w, header_h, mx, my)
    local scale = pos_tbl.scale or 1
    local sw, sh = screen_size()

    if drag.active_id == id then
        if mouse_l.down then
            pos_tbl.x = clamp(mx - drag.gx, 0, math.max(0, sw - w * scale))
            pos_tbl.y = clamp(my - drag.gy, 0, math.max(0, sh - header_h * scale))
        else
            drag.active_id = nil
        end
        return
    end

    if drag.active_id == nil and resize.active_id == nil and mouse_l.clicked
        and point_in_rect(mx, my, pos_tbl.x, pos_tbl.y, w * scale, header_h * scale) then
        drag.active_id = id
        drag.gx = mx - pos_tbl.x
        drag.gy = my - pos_tbl.y
    end
end

-- Lets the user grab the bottom-right corner grip and drag to scale the
-- whole window uniformly (all games keep their fixed internal layout in
-- "logical" pixels; only the on-screen size changes, via the R render
-- transform set in script.OnDraw).
local function panel_resize(id, pos_tbl, w, h, mx, my)
    local scale = pos_tbl.scale or 1
    local grip = 16
    local gx = pos_tbl.x + w * scale - grip
    local gy = pos_tbl.y + h * scale - grip

    if resize.active_id == id then
        if mouse_l.down then
            local new_scale = (mx - pos_tbl.x) / w
            pos_tbl.scale = clamp(new_scale, MIN_SCALE, MAX_SCALE)
        else
            resize.active_id = nil
        end
        return
    end

    if drag.active_id == nil and resize.active_id == nil and mouse_l.clicked
        and point_in_rect(mx, my, gx, gy, grip, grip) then
        resize.active_id = id
    end
end


local ui_ttt_open, ui_chess_open, ui_sol_open, ui_mine_open, ui_weather_open, ui_battleship_open, ui_g2048_open, ui_casino_open, ui_calc_open

local function get_ui_value(el, default)
    if not el then return default end
    local ok, v = pcall(function() return el:Get() end)
    if ok and v ~= nil then return v end
    return default
end

do
    local ok, tab = pcall(Menu.Create, "Scripts", "Utility", "Мини-игры")
    if not ok or not tab then
        print("[MiniGames] Menu.Create упал: " .. tostring(tab))
        goto menu_done
    end

    local ok2, section = pcall(function() return tab:Create("Мини-игры") end)
    if not ok2 or not section then
        print("[MiniGames] tab:Create упал: " .. tostring(section))
        goto menu_done
    end

    local ok3, main_tab = pcall(function() return section:Create("Игры") end)
    if not ok3 or not main_tab then
        print("[MiniGames] section:Create упал: " .. tostring(main_tab))
        goto menu_done
    end

    local switches = {
        {"ui_ttt_open", "Крестики-нолики: открыть"},
        {"ui_chess_open", "Шахматы: открыть"},
        {"ui_sol_open", "Пасьянс: открыть"},
        {"ui_mine_open", "Сапёр: открыть"},
        {"ui_weather_open", "Погода (Владимир): открыть"},
        {"ui_battleship_open", "Морской бой: открыть"},
        {"ui_g2048_open", "2048: открыть"},
        {"ui_casino_open", "Казино: открыть"},
        {"ui_calc_open", "Калькулятор: открыть"},
    }

    for _, def in ipairs(switches) do
        local key, label = def[1], def[2]
        local ok4, el = pcall(function() return main_tab:Switch(label, false) end)
        if ok4 and el then
            if key == "ui_ttt_open" then ui_ttt_open = el
            elseif key == "ui_chess_open" then ui_chess_open = el
            elseif key == "ui_sol_open" then ui_sol_open = el
            elseif key == "ui_mine_open" then ui_mine_open = el
            elseif key == "ui_weather_open" then ui_weather_open = el
            elseif key == "ui_battleship_open" then ui_battleship_open = el
            elseif key == "ui_g2048_open" then ui_g2048_open = el
            elseif key == "ui_casino_open" then ui_casino_open = el
            elseif key == "ui_calc_open" then ui_calc_open = el
            end
        else
            print("[MiniGames] Switch '" .. label .. "' упал: " .. tostring(el))
        end
    end

    ::menu_done::
end



local ttt_reset, ttt_draw
do
local TTT_HEADER = 34
local TTT_PAD = 16
local TTT_CELL = 66
local TTT_BTN_H = 26
local TTT_W = TTT_PAD * 2 + TTT_CELL * 3
local TTT_H = TTT_HEADER + TTT_PAD * 2 + TTT_CELL * 3 + TTT_BTN_H + 10
PANEL_SIZE.ttt = {w = TTT_W, h = TTT_H, header = TTT_HEADER}

local TTT_WIN_LINES = {
    {1, 2, 3}, {4, 5, 6}, {7, 8, 9},
    {1, 4, 7}, {2, 5, 8}, {3, 6, 9},
    {1, 5, 9}, {3, 5, 7},
}

local ttt = { board = nil, status = "", game_over = false, win_line = nil }

local function ttt_winner(board)
    for _, line in ipairs(TTT_WIN_LINES) do
        local a, b, c = board[line[1]], board[line[2]], board[line[3]]
        if a ~= "" and a == b and b == c then return a, line end
    end
    for i = 1, 9 do
        if board[i] == "" then return nil end
    end
    return "draw", nil
end

function ttt_reset()
    ttt.board = {"", "", "", "", "", "", "", "", ""}
    ttt.status = "Ваш ход — X"
    ttt.game_over = false
    ttt.win_line = nil
end

local function ttt_result_text(w)
    if w == "X" then return "Победа! Вы выиграли" end
    if w == "draw" then return "Ничья" end
    return "Бот победил"
end

local function ttt_bot_move()
    local board = ttt.board

    for i = 1, 9 do
        if board[i] == "" then
            board[i] = "O"
            if ttt_winner(board) == "O" then return end
            board[i] = ""
        end
    end

    for i = 1, 9 do
        if board[i] == "" then
            board[i] = "X"
            local w = ttt_winner(board)
            board[i] = ""
            if w == "X" then
                board[i] = "O"
                return
            end
        end
    end

    if board[5] == "" then
        board[5] = "O"
        return
    end

    for _, i in ipairs({1, 3, 7, 9}) do
        if board[i] == "" then
            board[i] = "O"
            return
        end
    end

    for i = 1, 9 do
        if board[i] == "" then
            board[i] = "O"
            return
        end
    end
end

local function ttt_cell_rect(i, px, py)
    local idx = i - 1
    local col = idx % 3
    local row = math.floor(idx / 3)
    local x = px + TTT_PAD + col * TTT_CELL
    local y = py + TTT_HEADER + TTT_PAD + row * TTT_CELL
    return x, y
end

local function ttt_handle_click_index(i)
    if ttt.game_over then return end
    if ttt.board[i] ~= "" then return end

    ttt.board[i] = "X"
    local w, line = ttt_winner(ttt.board)
    if w then
        ttt.game_over = true
        ttt.win_line = line
        ttt.status = ttt_result_text(w)
        return
    end

    ttt_bot_move()
    w, line = ttt_winner(ttt.board)
    if w then
        ttt.game_over = true
        ttt.win_line = line
        ttt.status = ttt_result_text(w)
    else
        ttt.status = "Ваш ход — X"
    end
end

function ttt_draw(mx, my, clicked, px, py)
    if not ttt.board then ttt_reset() end
    local accent = Color(90, 190, 255, 255)
    draw_panel(px, py, TTT_W, TTT_H, "Крестики-нолики", ttt.status, accent, TTT_HEADER)

    local gx0, gy0 = px + TTT_PAD, py + TTT_HEADER + TTT_PAD
    local gx1, gy1 = gx0 + TTT_CELL * 3, gy0 + TTT_CELL * 3
    for k = 1, 2 do
        R.line(gx0 + k * TTT_CELL, gy0, gx0 + k * TTT_CELL, gy1, Color(255, 255, 255, 45), 2)
        R.line(gx0, gy0 + k * TTT_CELL, gx1, gy0 + k * TTT_CELL, Color(255, 255, 255, 45), 2)
    end

    for i = 1, 9 do
        local x, y = ttt_cell_rect(i, px, py)
        local hover = (not ttt.game_over) and ttt.board[i] == "" and point_in_rect(mx, my, x, y, TTT_CELL, TTT_CELL)
        if hover then R.rect(x + 2, y + 2, TTT_CELL - 4, TTT_CELL - 4, Color(255, 255, 255, 18), 4) end

        local v = ttt.board[i]
        local inset = TTT_CELL * 0.28
        if v == "X" then
            local c = Color(100, 200, 255, 255)
            R.line(x + inset, y + inset, x + TTT_CELL - inset, y + TTT_CELL - inset, c, 6)
            R.line(x + TTT_CELL - inset, y + inset, x + inset, y + TTT_CELL - inset, c, 6)
        elseif v == "O" then
            local c = Color(255, 120, 120, 255)
            R.circle(x + TTT_CELL / 2, y + TTT_CELL / 2, TTT_CELL / 2 - inset, c, 6, false, 40)
        end

        if clicked and hover then ttt_handle_click_index(i) end
    end

    if ttt.win_line then
        local a, cIdx = ttt.win_line[1], ttt.win_line[3]
        local ax, ay = ttt_cell_rect(a, px, py)
        local cx2, cy2 = ttt_cell_rect(cIdx, px, py)
        R.line(ax + TTT_CELL / 2, ay + TTT_CELL / 2, cx2 + TTT_CELL / 2, cy2 + TTT_CELL / 2, Color(255, 220, 80, 255), 5)
    end

    local by = py + TTT_HEADER + TTT_PAD + TTT_CELL * 3 + 10
    local bx = px + TTT_PAD
    local bw = TTT_CELL * 3
    local hover_btn = draw_button(bx, by, bw, TTT_BTN_H, "Новая игра", mx, my, Color(70, 90, 120, 255), Color(40, 44, 54, 255))
    if clicked and hover_btn then ttt_reset() end
end
end



local chess_reset, chess_draw
do
local CHESS_HEADER = 34
local CHESS_PAD = 16
local CHESS_CELL = 46
local CHESS_COORD = 16
local CHESS_BTN_H = 26
local CHESS_W = CHESS_PAD * 2 + CHESS_COORD + CHESS_CELL * 8
local CHESS_H = CHESS_HEADER + CHESS_PAD * 2 + CHESS_CELL * 8 + CHESS_COORD + CHESS_BTN_H + 10
PANEL_SIZE.chess = {w = CHESS_W, h = CHESS_H, header = CHESS_HEADER}

local LIGHT_SQ = Color(235, 224, 200, 255)
local DARK_SQ = Color(120, 90, 70, 255)

local CHESS_ROOK_DIRS = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}}
local CHESS_BISHOP_DIRS = {{1, 1}, {1, -1}, {-1, 1}, {-1, -1}}
local CHESS_QUEEN_DIRS = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}, {1, 1}, {1, -1}, {-1, 1}, {-1, -1}}
local CHESS_KNIGHT_OFFS = {{1, 2}, {2, 1}, {2, -1}, {1, -2}, {-1, -2}, {-2, -1}, {-2, 1}, {-1, 2}}
local CHESS_VALUES = {P = 1, N = 3, B = 3, R = 5, Q = 9, K = 0}

local function chess_in_bounds(r, c)
    return r >= 1 and r <= 8 and c >= 1 and c <= 8
end

local function chess_new_board()
    local b = {}
    for r = 1, 8 do
        b[r] = {}
        for c = 1, 8 do b[r][c] = "" end
    end
    local back = {"R", "N", "B", "Q", "K", "B", "N", "R"}
    for c = 1, 8 do
        b[1][c] = back[c]
        b[2][c] = "P"
        b[7][c] = "p"
        b[8][c] = back[c]:lower()
    end
    return b
end

local function chess_pseudo_moves(board, r, c)
    local p = board[r][c]
    if p == "" then return {} end
    local white = p:match("%u") ~= nil
    local kind = p:upper()
    local moves = {}

    local function add(tr, tc)
        if not chess_in_bounds(tr, tc) then return false end
        local target = board[tr][tc]
        if target == "" then
            table.insert(moves, {tr, tc})
            return true
        else
            local target_white = target:match("%u") ~= nil
            if target_white ~= white then
                table.insert(moves, {tr, tc})
            end
            return false
        end
    end

    if kind == "P" then
        local dir = white and 1 or -1
        local start_row = white and 2 or 7
        local one_r = r + dir
        if chess_in_bounds(one_r, c) and board[one_r][c] == "" then
            table.insert(moves, {one_r, c})
            local two_r = r + 2 * dir
            if r == start_row and chess_in_bounds(two_r, c) and board[two_r][c] == "" then
                table.insert(moves, {two_r, c})
            end
        end
        for _, dc in ipairs({-1, 1}) do
            local tr, tc = r + dir, c + dc
            if chess_in_bounds(tr, tc) then
                local target = board[tr][tc]
                if target ~= "" and (target:match("%u") ~= nil) ~= white then
                    table.insert(moves, {tr, tc})
                end
            end
        end
    elseif kind == "N" then
        for _, off in ipairs(CHESS_KNIGHT_OFFS) do
            add(r + off[1], c + off[2])
        end
    elseif kind == "B" then
        for _, d in ipairs(CHESS_BISHOP_DIRS) do
            local tr, tc = r + d[1], c + d[2]
            while chess_in_bounds(tr, tc) do
                if not add(tr, tc) then break end
                tr, tc = tr + d[1], tc + d[2]
            end
        end
    elseif kind == "R" then
        for _, d in ipairs(CHESS_ROOK_DIRS) do
            local tr, tc = r + d[1], c + d[2]
            while chess_in_bounds(tr, tc) do
                if not add(tr, tc) then break end
                tr, tc = tr + d[1], tc + d[2]
            end
        end
    elseif kind == "Q" then
        for _, d in ipairs(CHESS_QUEEN_DIRS) do
            local tr, tc = r + d[1], c + d[2]
            while chess_in_bounds(tr, tc) do
                if not add(tr, tc) then break end
                tr, tc = tr + d[1], tc + d[2]
            end
        end
    elseif kind == "K" then
        for _, d in ipairs(CHESS_QUEEN_DIRS) do
            add(r + d[1], c + d[2])
        end
    end

    return moves
end

local function chess_square_attacked(board, r, c, by_white)
    for rr = 1, 8 do
        for cc = 1, 8 do
            local p = board[rr][cc]
            if p ~= "" then
                local pwhite = p:match("%u") ~= nil
                if pwhite == by_white then
                    local moves = chess_pseudo_moves(board, rr, cc)
                    for _, m in ipairs(moves) do
                        if m[1] == r and m[2] == c then return true end
                    end
                end
            end
        end
    end
    return false
end

local function chess_find_king(board, white)
    local target = white and "K" or "k"
    for r = 1, 8 do
        for c = 1, 8 do
            if board[r][c] == target then return r, c end
        end
    end
    return nil
end

local function chess_in_check(board, white)
    local kr, kc = chess_find_king(board, white)
    if not kr then return false end
    return chess_square_attacked(board, kr, kc, not white)
end

local function chess_legal_moves(board, r, c)
    local p = board[r][c]
    if p == "" then return {} end
    local white = p:match("%u") ~= nil
    local pseudo = chess_pseudo_moves(board, r, c)
    local legal = {}
    for _, m in ipairs(pseudo) do
        local tr, tc = m[1], m[2]
        local captured = board[tr][tc]
        local moved = board[r][c]
        board[tr][tc] = moved
        board[r][c] = ""
        local ok = not chess_in_check(board, white)
        board[r][c] = moved
        board[tr][tc] = captured
        if ok then table.insert(legal, m) end
    end
    return legal
end

local function chess_all_legal_moves(board, white)
    local all = {}
    for r = 1, 8 do
        for c = 1, 8 do
            local p = board[r][c]
            if p ~= "" and (p:match("%u") ~= nil) == white then
                local lm = chess_legal_moves(board, r, c)
                for _, m in ipairs(lm) do
                    table.insert(all, {from = {r, c}, to = m})
                end
            end
        end
    end
    return all
end

local function chess_make_move(board, from, to)
    local p = board[from[1]][from[2]]
    local captured = board[to[1]][to[2]]
    board[to[1]][to[2]] = p
    board[from[1]][from[2]] = ""
    if p == "P" and to[1] == 8 then board[to[1]][to[2]] = "Q" end
    if p == "p" and to[1] == 1 then board[to[1]][to[2]] = "q" end
    return captured
end

local function chess_piece_value(p)
    if p == "" then return 0 end
    return CHESS_VALUES[p:upper()] or 0
end

local function chess_bot_move(board)
    local moves = chess_all_legal_moves(board, false)
    if #moves == 0 then return nil end
    local best, best_val = nil, -1
    for _, mv in ipairs(moves) do
        local target = board[mv.to[1]][mv.to[2]]
        local val = chess_piece_value(target)
        if val > best_val then
            best_val = val
            best = mv
        end
    end
    if best_val <= 0 then
        best = moves[math.random(#moves)]
    end
    chess_make_move(board, best.from, best.to)
    return best
end

local chess = { board = nil, turn = "white", selected = nil, status = "", game_over = false }

function chess_reset()
    chess.board = chess_new_board()
    chess.turn = "white"
    chess.selected = nil
    chess.status = "Ваш ход (белые)"
    chess.game_over = false
end

local function chess_after_move(white_that_just_moved)
    local other_white = not white_that_just_moved
    local moves = chess_all_legal_moves(chess.board, other_white)
    local in_check = chess_in_check(chess.board, other_white)

    if #moves == 0 then
        chess.game_over = true
        if in_check then
            chess.status = other_white and "Мат! Победили чёрные (бот)" or "Мат! Вы победили!"
        else
            chess.status = "Пат (ничья)"
        end
        return true
    end

    if in_check then
        chess.status = other_white and "Шах чёрным (бот думает)" or "Шах вам! Ваш ход"
    end
    return false
end

local function chess_cell_xy(r, c, px, py)
    local board_x = px + CHESS_PAD + CHESS_COORD
    local board_y = py + CHESS_HEADER + CHESS_PAD
    local x = board_x + (c - 1) * CHESS_CELL
    local row_from_top = 8 - r
    local y = board_y + row_from_top * CHESS_CELL
    return x, y
end

local function chess_cell_at(mx, my, px, py)
    local board_x = px + CHESS_PAD + CHESS_COORD
    local board_y = py + CHESS_HEADER + CHESS_PAD
    if mx < board_x or my < board_y then return nil end
    local c = math.floor((mx - board_x) / CHESS_CELL) + 1
    local row_from_top = math.floor((my - board_y) / CHESS_CELL)
    local r = 8 - row_from_top
    if c < 1 or c > 8 or r < 1 or r > 8 then return nil end
    return r, c
end

local function chess_handle_click(r, c)
    if chess.game_over then return end
    if chess.turn ~= "white" then return end
    if not r then return end

    if chess.selected then
        local sr, sc = chess.selected[1], chess.selected[2]
        if sr == r and sc == c then
            chess.selected = nil
            return
        end

        local legal = chess_legal_moves(chess.board, sr, sc)
        local found = false
        for _, m in ipairs(legal) do
            if m[1] == r and m[2] == c then
                found = true
                break
            end
        end

        if found then
            chess_make_move(chess.board, {sr, sc}, {r, c})
            chess.selected = nil
            local over = chess_after_move(true)
            if not over then
                chess.turn = "black"
                chess_bot_move(chess.board)
                local over2 = chess_after_move(false)
                if not over2 then
                    chess.turn = "white"
                    chess.status = "Ваш ход (белые)"
                end
            end
        else
            local p = chess.board[r][c]
            if p ~= "" and p:match("%u") ~= nil then
                chess.selected = {r, c}
            else
                chess.selected = nil
            end
        end
    else
        local p = chess.board[r][c]
        if p ~= "" and p:match("%u") ~= nil then
            chess.selected = {r, c}
        end
    end
end

local function chess_piece_color(p)
    local white = p:match("%u") ~= nil
    if white then
        return Color(245, 245, 240, 255), Color(30, 30, 35, 255), Color(90, 90, 95, 200)
    end
    return Color(40, 42, 50, 255), Color(235, 235, 240, 255), Color(10, 10, 12, 220)
end

local function chess_draw_piece(p, cx, cy)
    if p == "" then return end
    local fill, ink, ring = chess_piece_color(p)
    local r = CHESS_CELL * 0.36
    R.fcircle(cx, cy, r, fill, 32)
    R.circle(cx, cy, r, ring, 2, false, 32)
    R.text_centered(FONT.big, CHESS_CELL * 0.34, p:upper(), cx, cy + 1, ink)
end

function chess_draw(mx, my, clicked, px, py)
    if not chess.board then chess_reset() end
    local accent = Color(200, 170, 90, 255)
    draw_panel(px, py, CHESS_W, CHESS_H, "Шахматы", chess.status, accent, CHESS_HEADER)

    local board_x = px + CHESS_PAD + CHESS_COORD
    local board_y = py + CHESS_HEADER + CHESS_PAD

    for r = 1, 8 do
        for c = 1, 8 do
            local x, y = chess_cell_xy(r, c, px, py)
            local dark = (r + c) % 2 == 0
            R.rect(x, y, CHESS_CELL, CHESS_CELL, dark and DARK_SQ or LIGHT_SQ, 0)
        end
    end

    if chess.selected then
        local x, y = chess_cell_xy(chess.selected[1], chess.selected[2], px, py)
        R.rect(x, y, CHESS_CELL, CHESS_CELL, Color(255, 230, 90, 110), 0)
    end

    if not chess.game_over then
        local turn_white = chess.turn == "white"
        if chess_in_check(chess.board, turn_white) then
            local kr, kc = chess_find_king(chess.board, turn_white)
            if kr then
                local x, y = chess_cell_xy(kr, kc, px, py)
                R.rect(x, y, CHESS_CELL, CHESS_CELL, Color(230, 60, 60, 120), 0)
            end
        end
    end

    local legal = nil
    if chess.selected then
        legal = chess_legal_moves(chess.board, chess.selected[1], chess.selected[2])
    end
    if legal then
        for _, m in ipairs(legal) do
            local x, y = chess_cell_xy(m[1], m[2], px, py)
            local occupied = chess.board[m[1]][m[2]] ~= ""
            if occupied then
                R.circle(x + CHESS_CELL / 2, y + CHESS_CELL / 2, CHESS_CELL / 2 - 3, Color(230, 90, 90, 220), 3, false, 28)
            else
                R.fcircle(x + CHESS_CELL / 2, y + CHESS_CELL / 2, CHESS_CELL * 0.12, Color(60, 200, 110, 200), 20)
            end
        end
    end

    for r = 1, 8 do
        for c = 1, 8 do
            local p = chess.board[r][c]
            if p ~= "" then
                local x, y = chess_cell_xy(r, c, px, py)
                chess_draw_piece(p, x + CHESS_CELL / 2, y + CHESS_CELL / 2)
            end
        end
    end

    for c = 1, 8 do
        local x, _ = chess_cell_xy(1, c, px, py)
        R.text_centered(FONT.small, 11, string.char(96 + c), x + CHESS_CELL / 2, board_y + CHESS_CELL * 8 + 8, Color(200, 200, 205, 200))
    end
    for r = 1, 8 do
        local _, y = chess_cell_xy(r, 1, px, py)
        R.text_centered(FONT.small, 11, tostring(r), board_x - 10, y + CHESS_CELL / 2, Color(200, 200, 205, 200))
    end

    if clicked then
        local r, c = chess_cell_at(mx, my, px, py)
        if r then chess_handle_click(r, c) end
    end

    local by = board_y + CHESS_CELL * 8 + CHESS_COORD
    local bw = CHESS_CELL * 8
    local hover_btn = draw_button(board_x, by, bw, CHESS_BTN_H, "Новая игра", mx, my, Color(120, 95, 60, 255), Color(40, 44, 54, 255))
    if clicked and hover_btn then chess_reset() end
end
end


local sol_reset, sol_draw
do
local SOL_HEADER = 34
local SOL_PAD = 16
local CARD_W, CARD_H = 50, 70
local SOL_GAP = 14
local SOL_COL_W = CARD_W + 12
local SOL_FACEDOWN_OFF = 8
local SOL_FACEUP_OFF = 20
local SOL_BTN_H = 24
local SOL_W = SOL_PAD * 2 + SOL_COL_W * 7 - 12
local SOL_H = SOL_HEADER + SOL_PAD * 2 + CARD_H + SOL_GAP + 13 * SOL_FACEUP_OFF + CARD_H + SOL_BTN_H + 20
PANEL_SIZE.sol = {w = SOL_W, h = SOL_H, header = SOL_HEADER}

local SOL_SUITS = {"S", "H", "D", "C"}
local SUIT_GLYPH = {S = "\u{2660}", H = "\u{2665}", D = "\u{2666}", C = "\u{2663}"}

local function sol_is_red(suit)
    return suit == "H" or suit == "D"
end

local function suit_color(suit)
    if sol_is_red(suit) then return Color(210, 60, 60, 255) end
    return Color(30, 32, 38, 255)
end

local function rank_label(rank)
    if rank == 1 then return "A" end
    if rank == 11 then return "J" end
    if rank == 12 then return "Q" end
    if rank == 13 then return "K" end
    return tostring(rank)
end

local function sol_new_deck()
    local deck = {}
    for _, s in ipairs(SOL_SUITS) do
        for r = 1, 13 do
            table.insert(deck, {suit = s, rank = r, faceup = false})
        end
    end
    for i = #deck, 2, -1 do
        local j = math.random(i)
        deck[i], deck[j] = deck[j], deck[i]
    end
    return deck
end

local sol = {
    tableau = {},
    foundation = {S = 0, H = 0, D = 0, C = 0},
    stock = {},
    waste = {},
    selected = nil,
    status = "",
    won = false,
}

local function sol_seed_random()
    local ok, t = pcall(function() return GameRules.GetGameTime() end)
    if not ok or not t then t = 42 end
    math.randomseed(math.floor(t * 1000) % 2147483647)
end

function sol_reset()
    sol_seed_random()
    local deck = sol_new_deck()

    sol.tableau = {}
    for col = 1, 7 do
        sol.tableau[col] = {}
        for k = 1, col do
            local card = table.remove(deck)
            card.faceup = (k == col)
            table.insert(sol.tableau[col], card)
        end
    end

    sol.stock = deck
    sol.waste = {}
    sol.foundation = {S = 0, H = 0, D = 0, C = 0}
    sol.selected = nil
    sol.status = "Пасьянс (Косынка)"
    sol.won = false
end

local function sol_can_place_on_tableau(card, dest_col)
    local pile = sol.tableau[dest_col]
    if #pile == 0 then
        return card.rank == 13
    end
    local top = pile[#pile]
    if not top.faceup then return false end
    local alt_color = sol_is_red(card.suit) ~= sol_is_red(top.suit)
    return alt_color and card.rank == top.rank - 1
end

local function sol_can_place_on_foundation(card)
    local cur = sol.foundation[card.suit]
    return card.rank == cur + 1
end

local function sol_get_selected_card()
    if not sol.selected then return nil end
    if sol.selected.zone == "waste" then
        return sol.waste[#sol.waste]
    elseif sol.selected.zone == "tableau" then
        local pile = sol.tableau[sol.selected.col]
        return pile[#pile]
    end
    return nil
end

local function sol_remove_selected_card()
    if sol.selected.zone == "waste" then
        return table.remove(sol.waste)
    elseif sol.selected.zone == "tableau" then
        local pile = sol.tableau[sol.selected.col]
        local card = table.remove(pile)
        if #pile > 0 then pile[#pile].faceup = true end
        return card
    end
    return nil
end

local function sol_check_win()
    for _, s in ipairs(SOL_SUITS) do
        if sol.foundation[s] < 13 then return false end
    end
    return true
end

local function sol_col_x(col, px)
    return px + SOL_PAD + (col - 1) * SOL_COL_W
end

local function sol_zone_at(mx, my, px, py)
    local top_y = py + SOL_HEADER + SOL_PAD
    local tab_y = top_y + CARD_H + SOL_GAP

    if my < top_y then return nil end

    if my < top_y + CARD_H then
        for col = 1, 7 do
            local x = sol_col_x(col, px)
            if mx >= x and mx <= x + CARD_W then
                if col == 1 then return {zone = "stock"} end
                if col == 2 then return {zone = "waste"} end
                if col >= 4 then return {zone = "foundation", suit = SOL_SUITS[col - 3]} end
                return nil
            end
        end
        return nil
    end

    if my < tab_y then return nil end

    for col = 1, 7 do
        local x = sol_col_x(col, px)
        if mx >= x and mx <= x + CARD_W then
            return {zone = "tableau", col = col}
        end
    end
    return nil
end

local function sol_handle_click(mx, my, px, py)
    if sol.won then return end
    local z = sol_zone_at(mx, my, px, py)
    if not z then return end

    if z.zone == "stock" then
        if #sol.stock == 0 then
            while #sol.waste > 0 do
                local c = table.remove(sol.waste)
                c.faceup = false
                table.insert(sol.stock, c)
            end
        else
            local c = table.remove(sol.stock)
            c.faceup = true
            table.insert(sol.waste, c)
        end
        sol.selected = nil
        return
    end

    if not sol.selected then
        if z.zone == "waste" and #sol.waste > 0 then
            sol.selected = {zone = "waste"}
        elseif z.zone == "tableau" then
            local pile = sol.tableau[z.col]
            if #pile > 0 and pile[#pile].faceup then
                sol.selected = {zone = "tableau", col = z.col}
            end
        end
        return
    end

    local card = sol_get_selected_card()
    if not card then
        sol.selected = nil
        return
    end

    local moved = false
    if z.zone == "foundation" and z.suit == card.suit and sol_can_place_on_foundation(card) then
        sol_remove_selected_card()
        sol.foundation[card.suit] = card.rank
        moved = true
    elseif z.zone == "tableau" and sol_can_place_on_tableau(card, z.col) then
        sol_remove_selected_card()
        card.faceup = true
        table.insert(sol.tableau[z.col], card)
        moved = true
    end

    sol.selected = nil

    if moved then
        if sol_check_win() then
            sol.won = true
            sol.status = "Вы выиграли!"
        end
    elseif z.zone == "tableau" then
        local pile = sol.tableau[z.col]
        if #pile > 0 and pile[#pile].faceup then
            sol.selected = {zone = "tableau", col = z.col}
        end
    elseif z.zone == "waste" and #sol.waste > 0 then
        sol.selected = {zone = "waste"}
    end
end

local function draw_card_face(x, y, card, selected)
    R.rect(x, y, CARD_W, CARD_H, Color(250, 250, 245, 255), 6)
    R.outline(x, y, CARD_W, CARD_H, selected and Color(255, 220, 90, 255) or Color(40, 40, 45, 180), 6)
    local c = suit_color(card.suit)
    local rl = rank_label(card.rank)
    R.text(FONT.body, 14, rl, x + 6, y + 4, c)
    R.text(FONT.body, 12, SUIT_GLYPH[card.suit], x + 6, y + 19, c)
    R.text_centered(FONT.title, 22, SUIT_GLYPH[card.suit], x + CARD_W / 2, y + CARD_H / 2 + 4, c)
    R.text_right(FONT.body, 14, rl, x + CARD_W - 6, y + CARD_H - 19, c)
end

local function draw_card_back(x, y)
    R.rect(x, y, CARD_W, CARD_H, Color(40, 70, 120, 255), 6)
    R.outline(x, y, CARD_W, CARD_H, Color(20, 30, 50, 255), 6)
    R.outline(x + 5, y + 5, CARD_W - 10, CARD_H - 10, Color(255, 255, 255, 40), 4)
    for i = 1, 3 do
        R.line(x + 6, y + 6 + i * ((CARD_H - 12) / 4), x + CARD_W - 6, y + 6 + i * ((CARD_H - 12) / 4), Color(255, 255, 255, 30), 1)
    end
end

local function draw_empty_slot(x, y, glyph, col)
    R.outline(x, y, CARD_W, CARD_H, Color(255, 255, 255, 50), 6)
    if glyph then R.text_centered(FONT.title, 20, glyph, x + CARD_W / 2, y + CARD_H / 2, col or Color(255, 255, 255, 60)) end
end

function sol_draw(mx, my, clicked, px, py)
    if not sol.tableau or #sol.tableau == 0 then sol_reset() end
    local accent = Color(120, 200, 140, 255)
    draw_panel(px, py, SOL_W, SOL_H, "Пасьянс (Косынка)", sol.status, accent, SOL_HEADER)

    local top_y = py + SOL_HEADER + SOL_PAD
    local tab_y = top_y + CARD_H + SOL_GAP

    local sx, sy = sol_col_x(1, px), top_y
    if #sol.stock > 0 then
        draw_card_back(sx, sy)
    else
        draw_empty_slot(sx, sy, "\u{21bb}", Color(200, 200, 200, 120))
    end

    local wx, wy = sol_col_x(2, px), top_y
    if #sol.waste > 0 then
        local top = sol.waste[#sol.waste]
        local selected = sol.selected and sol.selected.zone == "waste"
        draw_card_face(wx, wy, top, selected)
    else
        draw_empty_slot(wx, wy)
    end

    for i, s in ipairs(SOL_SUITS) do
        local fx, fy = sol_col_x(3 + i, px), top_y
        local rank = sol.foundation[s]
        if rank > 0 then
            draw_card_face(fx, fy, {suit = s, rank = rank}, false)
        else
            draw_empty_slot(fx, fy, SUIT_GLYPH[s], suit_color(s))
        end
    end

    for col = 1, 7 do
        local pile = sol.tableau[col]
        local x = sol_col_x(col, px)
        if #pile == 0 then
            draw_empty_slot(x, tab_y)
        else
            for k, card in ipairs(pile) do
                local off = card.faceup and SOL_FACEUP_OFF or SOL_FACEDOWN_OFF
                local cy = tab_y + (k - 1) * off
                local is_top = (k == #pile)
                local selected = is_top and sol.selected and sol.selected.zone == "tableau" and sol.selected.col == col
                if card.faceup then
                    draw_card_face(x, cy, card, selected)
                else
                    draw_card_back(x, cy)
                end
            end
        end
    end

    if sol.won then
        R.text_centered(FONT.title, 20, "Вы выиграли!", px + SOL_W / 2, py + SOL_H - 40, Color(255, 220, 90, 255))
    end

    if clicked then
        sol_handle_click(mx, my, px, py)
    end

    local by = py + SOL_H - SOL_BTN_H - 10
    local hover_btn = draw_button(px + SOL_PAD, by, 120, SOL_BTN_H, "Новая игра", mx, my, Color(70, 120, 90, 255), Color(40, 44, 54, 255))
    if clicked and hover_btn then sol_reset() end
end
end


local mine_reset, mine_draw
do
local MINE_COLS, MINE_ROWS = 9, 9
local MINE_COUNT = 10
local MINE_CELL = 26
local MINE_HEADER = 34
local MINE_PAD = 16
local MINE_BTN_H = 24
local MINE_W = MINE_PAD * 2 + MINE_COLS * MINE_CELL
local MINE_H = MINE_HEADER + MINE_PAD * 2 + MINE_ROWS * MINE_CELL + MINE_BTN_H + 10
PANEL_SIZE.mine = {w = MINE_W, h = MINE_H, header = MINE_HEADER}

local MINE_NUM_COLORS = {
    [1] = Color(90, 140, 255, 255), [2] = Color(90, 190, 110, 255), [3] = Color(230, 90, 90, 255),
    [4] = Color(120, 90, 200, 255), [5] = Color(190, 90, 70, 255), [6] = Color(80, 190, 190, 255),
    [7] = Color(230, 230, 230, 255), [8] = Color(160, 160, 160, 255),
}

local mine = { cells = nil, generated = false, game_over = false, won = false, status = "" }

function mine_reset()
    mine.cells = {}
    for r = 1, MINE_ROWS do
        mine.cells[r] = {}
        for c = 1, MINE_COLS do
            mine.cells[r][c] = {mine = false, revealed = false, flagged = false, adj = 0}
        end
    end
    mine.generated = false
    mine.game_over = false
    mine.won = false
    mine.status = "ЛКМ — открыть, ПКМ — флаг"
end

local function mine_neighbors(r, c)
    local out = {}
    for dr = -1, 1 do
        for dc = -1, 1 do
            if not (dr == 0 and dc == 0) then
                local rr, cc = r + dr, c + dc
                if rr >= 1 and rr <= MINE_ROWS and cc >= 1 and cc <= MINE_COLS then
                    out[#out + 1] = {rr, cc}
                end
            end
        end
    end
    return out
end

local function mine_generate(safe_r, safe_c)
    local safe = {}
    safe[safe_r .. "_" .. safe_c] = true
    for _, n in ipairs(mine_neighbors(safe_r, safe_c)) do
        safe[n[1] .. "_" .. n[2]] = true
    end

    local placed = 0
    local guard = 0
    while placed < MINE_COUNT and guard < 10000 do
        guard = guard + 1
        local r = math.random(1, MINE_ROWS)
        local c = math.random(1, MINE_COLS)
        local key = r .. "_" .. c
        if not mine.cells[r][c].mine and not safe[key] then
            mine.cells[r][c].mine = true
            placed = placed + 1
        end
    end

    for r = 1, MINE_ROWS do
        for c = 1, MINE_COLS do
            if not mine.cells[r][c].mine then
                local cnt = 0
                for _, p in ipairs(mine_neighbors(r, c)) do
                    if mine.cells[p[1]][p[2]].mine then cnt = cnt + 1 end
                end
                mine.cells[r][c].adj = cnt
            end
        end
    end

    mine.generated = true
end

local function mine_reveal(r, c)
    local cell = mine.cells[r][c]
    if cell.revealed or cell.flagged then return end
    cell.revealed = true
    if cell.adj == 0 and not cell.mine then
        for _, n in ipairs(mine_neighbors(r, c)) do
            local nc = mine.cells[n[1]][n[2]]
            if not nc.revealed and not nc.flagged then
                mine_reveal(n[1], n[2])
            end
        end
    end
end

local function mine_check_win()
    for r = 1, MINE_ROWS do
        for c = 1, MINE_COLS do
            local cell = mine.cells[r][c]
            if not cell.mine and not cell.revealed then return false end
        end
    end
    return true
end

local function mine_handle_left(r, c)
    if mine.game_over then return end
    if not mine.generated then mine_generate(r, c) end
    local cell = mine.cells[r][c]
    if cell.flagged or cell.revealed then return end

    if cell.mine then
        cell.revealed = true
        mine.game_over = true
        mine.status = "Бум! Вы подорвались"
        for rr = 1, MINE_ROWS do
            for cc = 1, MINE_COLS do
                if mine.cells[rr][cc].mine then mine.cells[rr][cc].revealed = true end
            end
        end
        return
    end

    mine_reveal(r, c)
    if mine_check_win() then
        mine.game_over = true
        mine.won = true
        mine.status = "Победа! Все мины найдены"
    else
        mine.status = "ЛКМ — открыть, ПКМ — флаг"
    end
end

local function mine_handle_right(r, c)
    if mine.game_over then return end
    local cell = mine.cells[r][c]
    if cell.revealed then return end
    cell.flagged = not cell.flagged
end

local function mine_cell_xy(r, c, px, py)
    local x = px + MINE_PAD + (c - 1) * MINE_CELL
    local y = py + MINE_HEADER + MINE_PAD + (r - 1) * MINE_CELL
    return x, y
end

local function mine_cell_at(mx, my, px, py)
    local gx, gy = px + MINE_PAD, py + MINE_HEADER + MINE_PAD
    if mx < gx or my < gy then return nil end
    local c = math.floor((mx - gx) / MINE_CELL) + 1
    local r = math.floor((my - gy) / MINE_CELL) + 1
    if r < 1 or r > MINE_ROWS or c < 1 or c > MINE_COLS then return nil end
    return r, c
end

local function mine_flags_count()
    local n = 0
    for r = 1, MINE_ROWS do
        for c = 1, MINE_COLS do
            if mine.cells[r][c].flagged then n = n + 1 end
        end
    end
    return n
end

function mine_draw(mx, my, clicked, rclicked, px, py)
    if not mine.cells then mine_reset() end
    local accent = Color(210, 200, 90, 255)
    local remaining = MINE_COUNT - mine_flags_count()
    draw_panel(px, py, MINE_W, MINE_H, "Сапёр", mine.status .. "  |  мин: " .. remaining, accent, MINE_HEADER)

    for r = 1, MINE_ROWS do
        for c = 1, MINE_COLS do
            local x, y = mine_cell_xy(r, c, px, py)
            local cell = mine.cells[r][c]
            local hover = (not mine.game_over) and not cell.revealed and point_in_rect(mx, my, x, y, MINE_CELL, MINE_CELL)

            if cell.revealed then
                if cell.mine then
                    R.rect(x + 1, y + 1, MINE_CELL - 2, MINE_CELL - 2, Color(200, 60, 60, 255), 2)
                    R.fcircle(x + MINE_CELL / 2, y + MINE_CELL / 2, MINE_CELL * 0.22, Color(20, 20, 20, 255), 16)
                else
                    R.rect(x + 1, y + 1, MINE_CELL - 2, MINE_CELL - 2, Color(60, 62, 70, 255), 2)
                    if cell.adj > 0 then
                        R.text_centered(FONT.body, 14, tostring(cell.adj), x + MINE_CELL / 2, y + MINE_CELL / 2, MINE_NUM_COLORS[cell.adj] or Color(255, 255, 255, 255))
                    end
                end
            else
                R.rect(x + 1, y + 1, MINE_CELL - 2, MINE_CELL - 2, hover and Color(105, 108, 120, 255) or Color(85, 88, 98, 255), 2)
                R.outline(x + 1, y + 1, MINE_CELL - 2, MINE_CELL - 2, Color(255, 255, 255, 25), 2)
                if cell.flagged then
                    R.line(x + MINE_CELL * 0.4, y + MINE_CELL * 0.22, x + MINE_CELL * 0.4, y + MINE_CELL * 0.8, Color(230, 230, 230, 255), 2)
                    R.rect(x + MINE_CELL * 0.4, y + MINE_CELL * 0.22, MINE_CELL * 0.32, MINE_CELL * 0.24, Color(220, 70, 70, 255), 1)
                end
            end

            if clicked and hover then mine_handle_left(r, c) end
            if rclicked and not mine.game_over and point_in_rect(mx, my, x, y, MINE_CELL, MINE_CELL) then
                mine_handle_right(r, c)
            end
        end
    end

    local by = py + MINE_HEADER + MINE_PAD * 2 + MINE_ROWS * MINE_CELL
    local bw = MINE_COLS * MINE_CELL
    local hover_btn = draw_button(px + MINE_PAD, by, bw, MINE_BTN_H, "Новая игра", mx, my, Color(120, 110, 60, 255), Color(40, 44, 54, 255))
    if clicked and hover_btn then mine_reset() end
end
end



local weather_draw
do
local WEATHER_W = 260
local WEATHER_HEADER = 34
local WEATHER_BTN_H = 24
local WEATHER_H = WEATHER_HEADER + 16 * 2 + 90 + WEATHER_BTN_H
PANEL_SIZE.weather = {w = WEATHER_W, h = WEATHER_H, header = WEATHER_HEADER}

local WEATHER_CITY = "Vladimir,RU"
local WEATHER_POLL_INTERVAL = 300 -- сек

local weather = {
    ok = false,
    in_flight = false,
    last_poll = -999999,
    cond = "",
    temp = "",
    hum = "",
    wind = "",
    err = "",
}

local function weather_now()
    local ok, t = pcall(function() return GlobalVars.GetCurTime() end)
    if ok and type(t) == "number" then return t end
    return os.clock()
end

local function weather_trim(s)
    return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function weather_on_response(resp)
    weather.in_flight = false
    if not resp or not resp.response or resp.response == "" then
        weather.ok = false
        weather.err = "нет ответа от wttr.in"
        return
    end

    local raw = tostring(resp.response)
    local cond, temp, hum, wind = raw:match("([^|]*)|([^|]*)|([^|]*)|([^|]*)")
    if not temp then
        weather.ok = false
        weather.err = "не разобрать ответ"
        return
    end

    weather.ok = true
    weather.err = ""
    weather.cond = weather_trim(cond)
    weather.temp = weather_trim(temp)
    weather.hum = weather_trim(hum)
    weather.wind = weather_trim(wind)
end

local function weather_poll(force)
    if weather.in_flight then return end
    local now = weather_now()
    if not force and weather.ok and (now - weather.last_poll) < WEATHER_POLL_INTERVAL then return end
    weather.last_poll = now
    weather.in_flight = true

    local url = "https://wttr.in/" .. WEATHER_CITY .. "?format=%C|%t|%h|%w"
    local ok = pcall(function()
        HTTP.Request("GET", url, {timeout = 4000}, weather_on_response, "minigames_weather")
    end)
    if not ok then
        weather.in_flight = false
        weather.err = "HTTP недоступен в этом окружении"
    end
end

function weather_draw(mx, my, clicked, px, py)
    weather_poll(false)

    local accent = Color(120, 170, 230, 255)
    draw_panel(px, py, WEATHER_W, WEATHER_H, "Погода: Владимир", weather.ok and "wttr.in" or "офлайн", accent, WEATHER_HEADER)

    local body_y = py + WEATHER_HEADER + 16

    if weather.ok then
        R.text(FONT.big, 28, weather.temp ~= "" and weather.temp or "--", px + 16, body_y, Color(240, 240, 245, 255))
        R.text(FONT.body, 13, weather.cond ~= "" and weather.cond or "-", px + 16, body_y + 34, Color(200, 205, 215, 255))
        R.text(FONT.small, 12, "Влажность: " .. (weather.hum ~= "" and weather.hum or "-"), px + 16, body_y + 56, Color(170, 175, 185, 255))
        R.text(FONT.small, 12, "Ветер: " .. (weather.wind ~= "" and weather.wind or "-"), px + 16, body_y + 74, Color(170, 175, 185, 255))
    else
        local msg = weather.in_flight and "Загрузка..." or (weather.err ~= "" and weather.err or "Нет данных")
        R.text(FONT.body, 13, msg, px + 16, body_y, Color(200, 200, 205, 255))
    end

    local by = py + WEATHER_H - WEATHER_BTN_H - 10
    local hover_btn = draw_button(px + 16, by, 110, WEATHER_BTN_H, "Обновить", mx, my, Color(70, 100, 140, 255), Color(40, 44, 54, 255))
    if clicked and hover_btn then
        weather.ok = false
        weather_poll(true)
    end
end
end




local bs_reset, bs_draw, bs_seed_random
do
local BS_SIZE = 8
local BS_CELL = 26
local BS_PAD = 16
local BS_HEADER = 34
local BS_GAP = 26
local BS_LABEL_H = 18
local BS_BTN_H = 24

local BS_GRID_W = BS_SIZE * BS_CELL
local BS_W = BS_PAD * 2 + BS_GRID_W * 2 + BS_GAP
local BS_H = BS_HEADER + BS_PAD + BS_LABEL_H + BS_GRID_W + BS_PAD + BS_BTN_H + BS_PAD
PANEL_SIZE.battleship = {w = BS_W, h = BS_H, header = BS_HEADER}

local BS_SHIPS = {4, 3, 2, 2, 1, 1, 1}

local bs = {
    player = nil, -- board: player.cells[r][c] = {ship=bool, hit=bool}
    enemy = nil,
    game_over = false,
    won = false,
    status = "",
    bot_delay = 0,
}

local function bs_new_board()
    local b = {}
    for r = 1, BS_SIZE do
        b[r] = {}
        for c = 1, BS_SIZE do
            b[r][c] = {ship = false, hit = false}
        end
    end
    return b
end

local function bs_can_place(board, r, c, len, horizontal)
    for i = 0, len - 1 do
        local rr = horizontal and r or (r + i)
        local cc = horizontal and (c + i) or c
        if rr < 1 or rr > BS_SIZE or cc < 1 or cc > BS_SIZE then return false end
        -- сама клетка и соседние не должны содержать другой корабль (небольшой буфер)
        for dr = -1, 1 do
            for dc = -1, 1 do
                local nr, nc = rr + dr, cc + dc
                if nr >= 1 and nr <= BS_SIZE and nc >= 1 and nc <= BS_SIZE then
                    if board[nr][nc].ship then return false end
                end
            end
        end
    end
    return true
end

local function bs_place_ships(board)
    for _, len in ipairs(BS_SHIPS) do
        local placed = false
        local guard = 0
        while not placed and guard < 500 do
            guard = guard + 1
            local horizontal = math.random(0, 1) == 1
            local r = math.random(1, BS_SIZE)
            local c = math.random(1, BS_SIZE)
            if bs_can_place(board, r, c, len, horizontal) then
                for i = 0, len - 1 do
                    local rr = horizontal and r or (r + i)
                    local cc = horizontal and (c + i) or c
                    board[rr][cc].ship = true
                end
                placed = true
            end
        end
    end
end

function bs_seed_random()
    local ok, t = pcall(function() return GlobalVars.GetCurTime() end)
    if ok and type(t) == "number" then
        math.randomseed(math.floor(t * 1000) % 2147483647)
    end
end

local function bs_ship_cells(r, c, len, horizontal)
    local cells = {}
    for i = 0, len - 1 do
        local rr = horizontal and r or (r + i)
        local cc = horizontal and (c + i) or c
        cells[#cells + 1] = {rr, cc}
    end
    return cells
end

function bs_reset()
    bs_seed_random()
    bs.player = bs_new_board()
    bs.enemy = bs_new_board()
    bs_place_ships(bs.enemy)
    bs.phase = "placing"
    bs.place_index = 1
    bs.place_horizontal = true
    bs.game_over = false
    bs.won = false
    bs.status = "Расставьте корабли на своём поле"
    bs.bot_targets_left = nil
end

local function bs_all_sunk(board)
    for r = 1, BS_SIZE do
        for c = 1, BS_SIZE do
            local cell = board[r][c]
            if cell.ship and not cell.hit then return false end
        end
    end
    return true
end

local function bs_bot_turn()
    if bs.game_over then return end
    local free = {}
    for r = 1, BS_SIZE do
        for c = 1, BS_SIZE do
            if not bs.player[r][c].hit then free[#free + 1] = {r, c} end
        end
    end
    if #free == 0 then return end
    local pick = free[math.random(1, #free)]
    local cell = bs.player[pick[1]][pick[2]]
    cell.hit = true
    if cell.ship and bs_all_sunk(bs.player) then
        bs.game_over = true
        bs.won = false
        bs.status = "Поражение! Ваш флот уничтожен"
    end
end

local function bs_handle_click(r, c)
    if bs.phase ~= "playing" or bs.game_over then return end
    local cell = bs.enemy[r][c]
    if cell.hit then return end
    cell.hit = true

    if cell.ship then
        if bs_all_sunk(bs.enemy) then
            bs.game_over = true
            bs.won = true
            bs.status = "Победа! Флот противника уничтожен"
            return
        end
        bs.status = "Попадание! Стреляйте ещё раз"
    else
        bs.status = "Промах. Ход противника..."
        bs_bot_turn()
        if not bs.game_over then
            bs.status = "Стреляйте по правому полю"
        end
    end
end

local function bs_auto_place_remaining()
    while bs.place_index <= #BS_SHIPS do
        local len = BS_SHIPS[bs.place_index]
        local placed = false
        local guard = 0
        while not placed and guard < 500 do
            guard = guard + 1
            local horizontal = math.random(0, 1) == 1
            local r = math.random(1, BS_SIZE)
            local c = math.random(1, BS_SIZE)
            if bs_can_place(bs.player, r, c, len, horizontal) then
                for _, cell in ipairs(bs_ship_cells(r, c, len, horizontal)) do
                    bs.player[cell[1]][cell[2]].ship = true
                end
                placed = true
            end
        end
        bs.place_index = bs.place_index + 1
    end
    bs.phase = "playing"
    bs.status = "Стреляйте по правому полю"
end

local function bs_grid_xy(side, r, c, px, py)
    local gx = px + BS_PAD + (side == "right" and (BS_GRID_W + BS_GAP) or 0)
    local gy = py + BS_HEADER + BS_LABEL_H
    return gx + (c - 1) * BS_CELL, gy + (r - 1) * BS_CELL
end

local function bs_cell_at(side, mx, my, px, py)
    local gx = px + BS_PAD + (side == "right" and (BS_GRID_W + BS_GAP) or 0)
    local gy = py + BS_HEADER + BS_LABEL_H
    if mx < gx or my < gy then return nil end
    local c = math.floor((mx - gx) / BS_CELL) + 1
    local r = math.floor((my - gy) / BS_CELL) + 1
    if r < 1 or r > BS_SIZE or c < 1 or c > BS_SIZE then return nil end
    return r, c
end

local function bs_draw_grid(side, board, reveal_ships, mx, my, px, py)
    local label = side == "left" and "Ваш флот" or "Противник"
    local lx = px + BS_PAD + (side == "right" and (BS_GRID_W + BS_GAP) or 0)
    R.text(FONT.small, 12, label, lx, py + BS_HEADER + 2, Color(190, 195, 205, 255))

    for r = 1, BS_SIZE do
        for c = 1, BS_SIZE do
            local x, y = bs_grid_xy(side, r, c, px, py)
            local cell = board[r][c]
            local hover = side == "right" and bs.phase == "playing" and not bs.game_over and not cell.hit and point_in_rect(mx, my, x, y, BS_CELL, BS_CELL)

            local base_color = Color(50, 90, 130, 255)
            if side == "right" and bs.phase == "placing" then base_color = Color(35, 38, 46, 255) end
            if reveal_ships and cell.ship and not cell.hit then base_color = Color(90, 95, 105, 255) end
            if hover then base_color = Color(70, 115, 155, 255) end

            R.rect(x + 1, y + 1, BS_CELL - 2, BS_CELL - 2, base_color, 2)
            R.outline(x + 1, y + 1, BS_CELL - 2, BS_CELL - 2, Color(255, 255, 255, 25), 2)

            if cell.hit then
                if cell.ship then
                    R.fcircle(x + BS_CELL / 2, y + BS_CELL / 2, BS_CELL * 0.24, Color(220, 70, 70, 255), 16)
                else
                    R.fcircle(x + BS_CELL / 2, y + BS_CELL / 2, BS_CELL * 0.12, Color(210, 215, 225, 200), 12)
                end
            end

            if side == "right" and hover and mouse_l.clicked then
                bs_handle_click(r, c)
            end
        end
    end
end

local function bs_draw_placement(mx, my, px, py)
    if bs.phase ~= "placing" then return end
    local len = BS_SHIPS[bs.place_index]
    if not len then return end

    local r, c = bs_cell_at("left", mx, my, px, py)
    if not r then return end

    local cells = bs_ship_cells(r, c, len, bs.place_horizontal)
    local valid = bs_can_place(bs.player, r, c, len, bs.place_horizontal)
    local color = valid and Color(90, 200, 120, 190) or Color(210, 70, 70, 190)

    for _, cell in ipairs(cells) do
        local rr, cc = cell[1], cell[2]
        if rr >= 1 and rr <= BS_SIZE and cc >= 1 and cc <= BS_SIZE then
            local x, y = bs_grid_xy("left", rr, cc, px, py)
            R.rect(x + 1, y + 1, BS_CELL - 2, BS_CELL - 2, color, 2)
        end
    end

    if mouse_l.clicked and valid then
        for _, cell in ipairs(cells) do
            bs.player[cell[1]][cell[2]].ship = true
        end
        bs.place_index = bs.place_index + 1
        if bs.place_index > #BS_SHIPS then
            bs.phase = "playing"
            bs.status = "Стреляйте по правому полю"
        end
    end
end

function bs_draw(mx, my, clicked, px, py)
    if not bs.player then bs_reset() end

    if bs.phase == "placing" and mouse_r.clicked then
        bs.place_horizontal = not bs.place_horizontal
    end

    local accent = Color(90, 160, 220, 255)
    local display_status = bs.status
    if bs.phase == "placing" and BS_SHIPS[bs.place_index] then
        display_status = ("Корабль %d/%d (%d палубы), %s — ЛКМ ставить, ПКМ повернуть"):format(
            bs.place_index, #BS_SHIPS, BS_SHIPS[bs.place_index],
            bs.place_horizontal and "гориз." or "вертик.")
    end
    draw_panel(px, py, BS_W, BS_H, "Морской бой", display_status, accent, BS_HEADER)

    bs_draw_grid("left", bs.player, true, mx, my, px, py)
    bs_draw_grid("right", bs.enemy, false, mx, my, px, py)
    bs_draw_placement(mx, my, px, py)

    local by = py + BS_H - BS_BTN_H - BS_PAD
    local hover_new = draw_button(px + BS_PAD, by, 110, BS_BTN_H, "Новая игра", mx, my, Color(70, 110, 150, 255), Color(40, 44, 54, 255))
    if clicked and hover_new then bs_reset() end

    if bs.phase == "placing" then
        local hover_auto = draw_button(px + BS_PAD + 120, by, 130, BS_BTN_H, "Авто-расстановка", mx, my, Color(70, 110, 150, 255), Color(40, 44, 54, 255))
        if clicked and hover_auto then bs_auto_place_remaining() end
    end
end
end

local g2048_reset, g2048_draw
do
local G2048_SIZE = 4
local G2048_CELL = 54
local G2048_GAP = 6
local G2048_PAD = 16
local G2048_HEADER = 34
local G2048_BTN = 30
local G2048_NEWGAME_H = 24

local G2048_GRID_W = G2048_SIZE * G2048_CELL + (G2048_SIZE - 1) * G2048_GAP
local G2048_CTRL_H = G2048_BTN * 3 + G2048_GAP * 2
local G2048_W = G2048_PAD * 2 + G2048_GRID_W
local G2048_H = G2048_HEADER + G2048_PAD + G2048_GRID_W + G2048_PAD + G2048_CTRL_H + G2048_PAD + G2048_NEWGAME_H + G2048_PAD
PANEL_SIZE.g2048 = {w = G2048_W, h = G2048_H, header = G2048_HEADER}

local G2048_TILE_COLORS = {
    [2] = Color(60, 64, 74, 255),
    [4] = Color(70, 70, 82, 255),
    [8] = Color(200, 130, 70, 255),
    [16] = Color(210, 110, 60, 255),
    [32] = Color(215, 95, 80, 255),
    [64] = Color(220, 75, 60, 255),
    [128] = Color(215, 190, 90, 255),
    [256] = Color(215, 180, 70, 255),
    [512] = Color(215, 170, 50, 255),
    [1024] = Color(215, 160, 30, 255),
    [2048] = Color(210, 180, 40, 255),
}

local g2048 = { grid = nil, score = 0, game_over = false, won = false, status = "" }

local function g2048_empty_cells(grid)
    local out = {}
    for r = 1, G2048_SIZE do
        for c = 1, G2048_SIZE do
            if grid[r][c] == 0 then out[#out + 1] = {r, c} end
        end
    end
    return out
end

local function g2048_spawn(grid)
    local empty = g2048_empty_cells(grid)
    if #empty == 0 then return end
    local cell = empty[math.random(1, #empty)]
    grid[cell[1]][cell[2]] = (math.random() < 0.9) and 2 or 4
end

local function g2048_has_moves(grid)
    for r = 1, G2048_SIZE do
        for c = 1, G2048_SIZE do
            if grid[r][c] == 0 then return true end
            if c < G2048_SIZE and grid[r][c] == grid[r][c + 1] then return true end
            if r < G2048_SIZE and grid[r][c] == grid[r + 1][c] then return true end
        end
    end
    return false
end

function g2048_reset()
    bs_seed_random()
    local grid = {}
    for r = 1, G2048_SIZE do
        grid[r] = {}
        for c = 1, G2048_SIZE do grid[r][c] = 0 end
    end
    g2048.grid = grid
    g2048.score = 0
    g2048.game_over = false
    g2048.won = false
    g2048.status = "Стрелками сдвигайте плитки"
    g2048_spawn(g2048.grid)
    g2048_spawn(g2048.grid)
end

-- сжимает и сливает один ряд влево; возвращает новый ряд, набранные очки, было ли изменение
local function g2048_compress_line(line)
    local vals = {}
    for i = 1, #line do
        if line[i] ~= 0 then vals[#vals + 1] = line[i] end
    end
    local out = {}
    local gained = 0
    local i = 1
    while i <= #vals do
        if vals[i + 1] and vals[i] == vals[i + 1] then
            local merged = vals[i] * 2
            out[#out + 1] = merged
            gained = gained + merged
            i = i + 2
        else
            out[#out + 1] = vals[i]
            i = i + 1
        end
    end
    local changed = false
    local result = {}
    for j = 1, G2048_SIZE do
        result[j] = out[j] or 0
        if result[j] ~= line[j] then changed = true end
    end
    return result, gained, changed
end

local function g2048_get_line(grid, dir, idx)
    local line = {}
    if dir == "left" or dir == "right" then
        for c = 1, G2048_SIZE do line[c] = grid[idx][c] end
        if dir == "right" then
            local rev = {}
            for c = 1, G2048_SIZE do rev[c] = line[G2048_SIZE - c + 1] end
            line = rev
        end
    else
        for r = 1, G2048_SIZE do line[r] = grid[r][idx] end
        if dir == "down" then
            local rev = {}
            for r = 1, G2048_SIZE do rev[r] = line[G2048_SIZE - r + 1] end
            line = rev
        end
    end
    return line
end

local function g2048_set_line(grid, dir, idx, line)
    if dir == "right" then
        local rev = {}
        for c = 1, G2048_SIZE do rev[c] = line[G2048_SIZE - c + 1] end
        line = rev
    elseif dir == "down" then
        local rev = {}
        for r = 1, G2048_SIZE do rev[r] = line[G2048_SIZE - r + 1] end
        line = rev
    end
    if dir == "left" or dir == "right" then
        for c = 1, G2048_SIZE do grid[idx][c] = line[c] end
    else
        for r = 1, G2048_SIZE do grid[r][idx] = line[r] end
    end
end

local function g2048_move(dir)
    if g2048.game_over then return end
    local grid = g2048.grid
    local any_changed = false
    local total_gained = 0
    for idx = 1, G2048_SIZE do
        local line = g2048_get_line(grid, dir, idx)
        local new_line, gained, changed = g2048_compress_line(line)
        if changed then any_changed = true end
        total_gained = total_gained + gained
        g2048_set_line(grid, dir, idx, new_line)
    end

    if any_changed then
        g2048.score = g2048.score + total_gained
        g2048_spawn(grid)
        if not g2048.won then
            for r = 1, G2048_SIZE do
                for c = 1, G2048_SIZE do
                    if grid[r][c] >= 2048 then g2048.won = true end
                end
            end
            if g2048.won then g2048.status = "2048! Можно продолжать играть" end
        end
        if not g2048_has_moves(grid) then
            g2048.game_over = true
            g2048.status = "Ходов нет. Игра окончена"
        elseif not g2048.won then
            g2048.status = "Стрелками сдвигайте плитки"
        end
    end
end

function g2048_draw(mx, my, clicked, px, py)
    if not g2048.grid then g2048_reset() end
    local accent = Color(210, 170, 60, 255)
    draw_panel(px, py, G2048_W, G2048_H, "2048", ("Очки: %d  |  %s"):format(g2048.score, g2048.status), accent, G2048_HEADER)

    local gx, gy = px + G2048_PAD, py + G2048_HEADER + G2048_PAD
    for r = 1, G2048_SIZE do
        for c = 1, G2048_SIZE do
            local x = gx + (c - 1) * (G2048_CELL + G2048_GAP)
            local y = gy + (r - 1) * (G2048_CELL + G2048_GAP)
            local v = g2048.grid[r][c]
            R.rect(x, y, G2048_CELL, G2048_CELL, v == 0 and Color(40, 42, 50, 255) or (G2048_TILE_COLORS[v] or Color(200, 60, 200, 255)), 4)
            if v ~= 0 then
                local size = v >= 1024 and 15 or (v >= 128 and 17 or 20)
                R.text_centered(FONT.title, size, tostring(v), x + G2048_CELL / 2, y + G2048_CELL / 2, Color(250, 250, 252, 255))
            end
        end
    end

    local cy = gy + G2048_GRID_W + G2048_PAD
    local cx = px + G2048_PAD + G2048_GRID_W / 2 - G2048_BTN / 2
    local function arrow_btn(bx, by, glyph, dir)
        local hover = draw_button(bx, by, G2048_BTN, G2048_BTN, glyph, mx, my, Color(90, 90, 100, 255), Color(50, 52, 60, 255))
        if clicked and hover then g2048_move(dir) end
    end
    arrow_btn(cx, cy, "^", "up")
    arrow_btn(cx - G2048_BTN - G2048_GAP, cy + G2048_BTN + G2048_GAP, "<", "left")
    arrow_btn(cx, cy + G2048_BTN + G2048_GAP, "v", "down")
    arrow_btn(cx + G2048_BTN + G2048_GAP, cy + G2048_BTN + G2048_GAP, ">", "right")

    local by2 = cy + G2048_CTRL_H + G2048_PAD - 6
    local hover_btn = draw_button(px + G2048_PAD, by2, 110, G2048_NEWGAME_H, "Новая игра", mx, my, Color(120, 100, 50, 255), Color(40, 44, 54, 255))
    if clicked and hover_btn then g2048_reset() end
end
end



-- Казино: фишки визуально привязаны к количеству добитых крипов (лосхиты),
-- но выигрыш/проигрыш меняют только этот визуальный счётчик, сам крипстат не трогается.

local casino_reset, casino_draw
do
local CASINO_HEADER = 34
local CASINO_PAD = 16
local CASINO_REEL = 60
local CASINO_REEL_GAP = 10
local CASINO_GAP1 = 14
local CASINO_BTN_H = 26
local CASINO_GAP2 = 10
local CASINO_SPIN_H = 30
local CASINO_GAP3 = 10
local CASINO_SYNC_H = 22

-- The old code crammed "Фишки: N  |  <status>" into the header's status
-- slot, right next to the title, in a header only 34px tall. Long status
-- strings (win/lose messages) had nowhere to go but straight through the
-- title text, which is the text-overlap bug. Fix: give the status its own
-- wrapped, reserved line below the header, and keep the header itself
-- short (just the chip count).
local CASINO_STATUS_LINE_H = 15
local CASINO_STATUS_LINES = 2
local CASINO_STATUS_H = CASINO_STATUS_LINE_H * CASINO_STATUS_LINES + 8

local CASINO_REELS_W = 3 * CASINO_REEL + 2 * CASINO_REEL_GAP
local CASINO_W = CASINO_REELS_W + CASINO_PAD * 2
local CASINO_H = CASINO_HEADER + CASINO_STATUS_H + CASINO_REEL + CASINO_GAP1 + CASINO_BTN_H + CASINO_GAP2 + CASINO_SPIN_H + CASINO_GAP3 + CASINO_SYNC_H + CASINO_PAD
PANEL_SIZE.casino = {w = CASINO_W, h = CASINO_H, header = CASINO_HEADER}

local CASINO_MIN_BET = 5
local CASINO_BET_STEP = 5
local CASINO_SPIN_DURATION = 0.7

local CASINO_SYMS = {
    {key = "X", color = Color(150, 155, 165, 255), weight = 35, mult = 2},
    {key = "C", color = Color(215, 95, 95, 255), weight = 28, mult = 3},
    {key = "B", color = Color(215, 175, 65, 255), weight = 20, mult = 5},
    {key = "$", color = Color(95, 195, 125, 255), weight = 12, mult = 8},
    {key = "7", color = Color(225, 65, 65, 255), weight = 5, mult = 15},
}
local CASINO_TOTAL_WEIGHT = 0
for _, s in ipairs(CASINO_SYMS) do CASINO_TOTAL_WEIGHT = CASINO_TOTAL_WEIGHT + s.weight end

local casino = {
    chips = 0,
    bet = CASINO_MIN_BET,
    reels = {1, 1, 1},
    state = "idle", -- idle | spinning
    spin_end = 0,
    pending_result = nil,
    pending_bet = 0,
    status = "",
    inited = false,
    baseline = nil, -- last-seen {lasthits, kills, towers, roshans, assists}
}

local function casino_random_sym_index()
    local roll = math.random(1, CASINO_TOTAL_WEIGHT)
    local acc = 0
    for i, s in ipairs(CASINO_SYMS) do
        acc = acc + s.weight
        if roll <= acc then return i end
    end
    return #CASINO_SYMS
end

-- Chips are earned automatically from in-game progress (see casino_accrue
-- below), at these rates per event:
local CASINO_PAYOUT = {
    lasthits = 1,   -- creep last hit
    kills = 100,    -- hero kill
    towers = 20,    -- tower kill (tower_Kills is only credited to you if you got the last hit)
    roshans = 50,   -- roshan kill (same: only credited on the last hit)
    assists = 15,   -- kill assist
}

local function casino_get_stats()
    local ok, player = pcall(function() return Players.GetLocal() end)
    if not ok or not player then return nil end

    local stats = {lasthits = 0, towers = 0, roshans = 0, kills = 0, assists = 0}

    local ok2, tp = pcall(function() return Player.GetTeamPlayer(player) end)
    if ok2 and tp then
        stats.lasthits = tp.lasthit_count or 0
        stats.towers = tp.tower_Kills or 0
        stats.roshans = tp.roshan_kills or 0
    end

    local ok3, td = pcall(function() return Player.GetTeamData(player) end)
    if ok3 and td then
        stats.kills = td.kills or 0
        stats.assists = td.assists or 0
    end

    return stats
end

function casino_reset()
    bs_seed_random()
    -- Clearing the baseline (not the chip count!) means the next accrue
    -- call just re-anchors to the current stats instead of granting
    -- anything for progress already made. This is what fixes the old bug
    -- where the "sync" button reset chips = lasthit_count outright: if
    -- you'd already spent chips down to zero, pressing it handed you a
    -- full refill of free chips out of nowhere.
    casino.baseline = nil
    casino.bet = CASINO_MIN_BET
    casino.reels = {1, 1, 1}
    casino.state = "idle"
    casino.status = "Готово к игре"
    casino.inited = true
end

-- Called every frame the casino window is open. Compares current stats to
-- the last known baseline and credits chips only for the positive delta,
-- so kills/lasthits/etc. are each counted exactly once. Also safely
-- absorbs a stat *decrease* (e.g. a new match started) by just re-anchoring
-- the baseline, rather than ever handing out negative chips.
local function casino_accrue()
    local stats = casino_get_stats()
    if not stats then return end

    if not casino.baseline then
        casino.baseline = stats
        return
    end

    local gained = 0
    for key, payout in pairs(CASINO_PAYOUT) do
        local delta = (stats[key] or 0) - (casino.baseline[key] or 0)
        if delta > 0 then
            gained = gained + delta * payout
        end
    end

    if gained > 0 then
        casino.chips = casino.chips + gained
        if casino.state ~= "spinning" then
            casino.status = ("+%d фишек за успехи в игре"):format(gained)
        end
    end

    casino.baseline = stats
end

local function casino_now()
    local ok, t = pcall(function() return GlobalVars.GetCurTime() end)
    return (ok and type(t) == "number") and t or 0
end

local function casino_start_spin()
    if casino.state == "spinning" then return end
    if casino.chips < casino.bet then
        casino.status = "Недостаточно фишек"
        return
    end
    casino.chips = casino.chips - casino.bet
    casino.pending_bet = casino.bet
    casino.pending_result = {casino_random_sym_index(), casino_random_sym_index(), casino_random_sym_index()}
    casino.state = "spinning"
    casino.spin_end = casino_now() + CASINO_SPIN_DURATION
    casino.status = "Крутим..."
end

local function casino_update()
    if casino.state ~= "spinning" then return end
    if casino_now() >= casino.spin_end then
        casino.reels = casino.pending_result
        casino.state = "idle"
        local r = casino.reels
        if r[1] == r[2] and r[2] == r[3] then
            local sym = CASINO_SYMS[r[1]]
            local payout = casino.pending_bet * sym.mult
            casino.chips = casino.chips + payout
            casino.status = ("Выигрыш! +%d фишек (%s x%d)"):format(payout, sym.key, sym.mult)
        else
            casino.status = ("Мимо. -%d фишек"):format(casino.pending_bet)
        end
    end
end

function casino_draw(mx, my, clicked, px, py)
    if not casino.inited then casino_reset() end
    casino_accrue()
    casino_update()

    local accent = Color(205, 175, 90, 255)
    draw_panel(px, py, CASINO_W, CASINO_H, "Казино", ("Фишки: %d"):format(casino.chips), accent, CASINO_HEADER)

    R.text_wrap(FONT.small, 12, casino.status, px + CASINO_PAD, py + CASINO_HEADER + 6,
        CASINO_REELS_W, CASINO_STATUS_LINE_H, Color(205, 210, 220, 255), CASINO_STATUS_LINES)

    local rx = px + (CASINO_W - CASINO_REELS_W) / 2
    local ry = py + CASINO_HEADER + CASINO_STATUS_H
    for i = 1, 3 do
        local x = rx + (i - 1) * (CASINO_REEL + CASINO_REEL_GAP)
        local idx = casino.state == "spinning" and casino_random_sym_index() or casino.reels[i]
        local sym = CASINO_SYMS[idx]
        R.rect(x, ry, CASINO_REEL, CASINO_REEL, Color(30, 32, 38, 255), 6)
        R.outline(x, ry, CASINO_REEL, CASINO_REEL, Color(255, 255, 255, 30), 6)
        R.text_centered(FONT.title, 22, sym.key, x + CASINO_REEL / 2, ry + CASINO_REEL / 2, sym.color)
    end

    local by = ry + CASINO_REEL + CASINO_GAP1
    local bw = 30
    local hover_minus = draw_button(px + CASINO_PAD, by, bw, CASINO_BTN_H, "-", mx, my, Color(90, 90, 100, 255), Color(50, 52, 60, 255))
    if clicked and hover_minus then casino.bet = math.max(CASINO_MIN_BET, casino.bet - CASINO_BET_STEP) end
    R.text_centered(FONT.body, 14, "Ставка: " .. casino.bet, px + CASINO_W / 2, by + CASINO_BTN_H / 2, Color(230, 230, 235, 255))
    local hover_plus = draw_button(px + CASINO_W - CASINO_PAD - bw, by, bw, CASINO_BTN_H, "+", mx, my, Color(90, 90, 100, 255), Color(50, 52, 60, 255))
    if clicked and hover_plus then casino.bet = math.min(math.max(CASINO_MIN_BET, casino.chips), casino.bet + CASINO_BET_STEP) end

    local sby = by + CASINO_BTN_H + CASINO_GAP2
    local spin_w = CASINO_W - CASINO_PAD * 2
    local can_spin = casino.state == "idle" and casino.chips >= casino.bet
    local hover_spin = draw_button(px + CASINO_PAD, sby, spin_w, CASINO_SPIN_H, casino.state == "spinning" and "Крутим..." or "Крутить",
        mx, my, can_spin and Color(150, 120, 50, 255) or Color(60, 62, 70, 255), can_spin and Color(110, 90, 40, 255) or Color(45, 47, 54, 255))
    if clicked and hover_spin and can_spin then casino_start_spin() end

    local syby = sby + CASINO_SPIN_H + CASINO_GAP3
    local hover_sync = draw_button(px + CASINO_PAD, syby, spin_w, CASINO_SYNC_H, "Пересчитать сейчас", mx, my, Color(70, 90, 110, 255), Color(40, 44, 54, 255))
    if clicked and hover_sync then casino_accrue() end
end
end


-- Обычный калькулятор: дисплей + кнопки (цифры, +/-/×/÷, %, ±, C, ⌫, =).
-- Работает как классический калькулятор с немедленным вычислением
-- (не разбирает полное выражение, а считает пара за парой — как обычный
-- карманный/настольный калькулятор).
local calc_draw
do
local CALC_HEADER = 34
local CALC_PAD = 12
local CALC_DISPLAY_H = 54
local CALC_BTN = 46
local CALC_GAP = 6
local CALC_COLS, CALC_ROWS = 4, 5

local CALC_GRID_W = CALC_COLS * CALC_BTN + (CALC_COLS - 1) * CALC_GAP
local CALC_GRID_H = CALC_ROWS * CALC_BTN + (CALC_ROWS - 1) * CALC_GAP
local CALC_W = CALC_PAD * 2 + CALC_GRID_W
local CALC_H = CALC_HEADER + CALC_PAD + CALC_DISPLAY_H + CALC_GAP + CALC_GRID_H + CALC_PAD
PANEL_SIZE.calc = {w = CALC_W, h = CALC_H, header = CALC_HEADER}

-- Раскладка клавиш, 5 строк по 4: функции сверху, цифры и операторы ниже,
-- как на любом обычном калькуляторе.
local CALC_KEYS = {
    {"C", "⌫", "%", "÷"},
    {"7", "8", "9", "×"},
    {"4", "5", "6", "−"},
    {"1", "2", "3", "+"},
    {"±", "0", ".", "="},
}

local CALC_OPS = {["÷"] = true, ["×"] = true, ["−"] = true, ["+"] = true}

local calc = {
    display = "0",
    expr = "",      -- верхняя строка: "12 ×" пока вводится второе число
    stored = nil,   -- первое число операции
    op = nil,       -- ожидающий оператор
    fresh = true,   -- следующая цифра начинает новое число
    err = false,
}

-- Компактно форматирует число под дисплей: без мусорных хвостовых нулей
-- и без потери точности для обычных сумм.
local function calc_fmt(n)
    if n ~= n or n == math.huge or n == -math.huge then return "Ошибка" end
    local s = string.format("%.10g", n)
    if #s > 14 then s = string.format("%.6g", n) end
    return s
end

local function calc_clear()
    calc.display = "0"
    calc.expr = ""
    calc.stored = nil
    calc.op = nil
    calc.fresh = true
    calc.err = false
end

local function calc_apply(a, op, b)
    if op == "+" then return a + b end
    if op == "−" then return a - b end
    if op == "×" then return a * b end
    if op == "÷" then
        if b == 0 then return nil end
        return a / b
    end
    return b
end

local function calc_digit(d)
    if calc.err then calc_clear() end
    if calc.fresh then
        calc.display = (d == ".") and "0." or d
        calc.fresh = false
        return
    end
    if d == "." then
        if not calc.display:find("%.") then calc.display = calc.display .. "." end
        return
    end
    if calc.display == "0" then
        calc.display = d
    else
        if #calc.display < 15 then calc.display = calc.display .. d end
    end
end

local function calc_backspace()
    if calc.err or calc.fresh then return end
    if #calc.display <= 1 then
        calc.display = "0"
    else
        calc.display = calc.display:sub(1, #calc.display - 1)
    end
end

local function calc_sign()
    if calc.err then return end
    if calc.display == "0" then return end
    if calc.display:sub(1, 1) == "-" then
        calc.display = calc.display:sub(2)
    else
        calc.display = "-" .. calc.display
    end
end

local function calc_percent()
    if calc.err then return end
    local v = tonumber(calc.display) or 0
    calc.display = calc_fmt(v / 100)
end

-- Выполняет накопленную операцию (если есть) и кладёт результат на дисплей.
local function calc_resolve()
    if not (calc.stored and calc.op) then return tonumber(calc.display) end
    local b = tonumber(calc.display) or 0
    local result = calc_apply(calc.stored, calc.op, b)
    if not result then
        calc.err = true
        calc.display = "Ошибка"
        calc.stored, calc.op, calc.expr = nil, nil, ""
        return nil
    end
    calc.display = calc_fmt(result)
    return result
end

local function calc_set_op(op)
    if calc.err then calc_clear() end
    if calc.stored and calc.op and not calc.fresh then
        local r = calc_resolve()
        if not r then return end
        calc.stored = r
    else
        calc.stored = tonumber(calc.display) or 0
    end
    calc.op = op
    calc.expr = calc_fmt(calc.stored) .. " " .. op
    calc.fresh = true
end

local function calc_equals()
    if calc.err then return end
    if not (calc.stored and calc.op) then return end
    calc.expr = calc_fmt(calc.stored) .. " " .. calc.op .. " " .. calc.display .. " ="
    calc_resolve()
    calc.stored, calc.op = nil, nil
    calc.fresh = true
end

local function calc_press(key)
    if key == "C" then calc_clear()
    elseif key == "⌫" then calc_backspace()
    elseif key == "%" then calc_percent()
    elseif key == "±" then calc_sign()
    elseif key == "=" then calc_equals()
    elseif CALC_OPS[key] then calc_set_op(key)
    elseif key == "." then calc_digit(".")
    else calc_digit(key) end
end

local CALC_DIGIT_BG = Color(48, 51, 60, 255)
local CALC_DIGIT_HOVER = Color(64, 68, 80, 255)
local CALC_FUNC_BG = Color(70, 73, 82, 255)
local CALC_FUNC_HOVER = Color(88, 92, 104, 255)
local CALC_OP_BG = Color(150, 120, 50, 255)
local CALC_OP_HOVER = Color(180, 145, 65, 255)
local CALC_EQ_BG = Color(70, 150, 100, 255)
local CALC_EQ_HOVER = Color(85, 180, 120, 255)

local function calc_key_colors(key)
    if key == "=" then return CALC_EQ_HOVER, CALC_EQ_BG end
    if CALC_OPS[key] then return CALC_OP_HOVER, CALC_OP_BG end
    if key == "C" or key == "⌫" or key == "%" or key == "±" then return CALC_FUNC_HOVER, CALC_FUNC_BG end
    return CALC_DIGIT_HOVER, CALC_DIGIT_BG
end

function calc_draw(mx, my, clicked, px, py)
    local accent = Color(150, 190, 230, 255)
    draw_panel(px, py, CALC_W, CALC_H, "Калькулятор", "", accent, CALC_HEADER)

    local dy = py + CALC_HEADER + CALC_PAD
    R.rect(px + CALC_PAD, dy, CALC_GRID_W, CALC_DISPLAY_H, Color(14, 16, 20, 255), 6)
    R.outline(px + CALC_PAD, dy, CALC_GRID_W, CALC_DISPLAY_H, Color(255, 255, 255, 20), 6)
    if calc.expr ~= "" then
        R.text_right(FONT.small, 12, calc.expr, px + CALC_PAD + CALC_GRID_W - 10, dy + 6, Color(150, 155, 165, 255))
    end
    local disp_size = #calc.display > 10 and 18 or 24
    R.text_right(FONT.title, disp_size, calc.display, px + CALC_PAD + CALC_GRID_W - 10, dy + CALC_DISPLAY_H - disp_size - 8, Color(240, 240, 245, 255))

    local gy = dy + CALC_DISPLAY_H + CALC_GAP
    for r = 1, CALC_ROWS do
        for c = 1, CALC_COLS do
            local key = CALC_KEYS[r][c]
            local x = px + CALC_PAD + (c - 1) * (CALC_BTN + CALC_GAP)
            local y = gy + (r - 1) * (CALC_BTN + CALC_GAP)
            local hover_c, base_c = calc_key_colors(key)
            local hover = draw_button(x, y, CALC_BTN, CALC_BTN, key, mx, my, hover_c, base_c)
            if clicked and hover then calc_press(key) end
        end
    end
end
end



local prev_open = {ttt = false, chess = false, sol = false, mine = false, weather = false, battleship = false, g2048 = false, casino = false, calc = false}
local last_errors = {}

-- Runs one window: resolves its real (registered) size, handles header
-- drag-to-move and corner drag-to-resize, then draws it through the
-- render transform so the whole thing scales around its own origin.
-- `extra`, if given, is inserted just before px/py (used by minesweeper's
-- extra `rclicked` argument).
local function run_window(id, draw_fn, mx, my, clicked, extra)
    local sz = PANEL_SIZE[id]
    local pos_tbl = pos[id]
    if not sz or not pos_tbl then return end

    panel_drag(id, pos_tbl, sz.w, sz.header, mx, my)
    panel_resize(id, pos_tbl, sz.w, sz.h, mx, my)

    local scale = pos_tbl.scale or 1
    local lx = pos_tbl.x + (mx - pos_tbl.x) / scale
    local ly = pos_tbl.y + (my - pos_tbl.y) / scale

    set_transform(pos_tbl.x, pos_tbl.y, scale)
    local ok, err
    if extra ~= nil then
        ok, err = pcall(draw_fn, lx, ly, clicked, extra, pos_tbl.x, pos_tbl.y)
    else
        ok, err = pcall(draw_fn, lx, ly, clicked, pos_tbl.x, pos_tbl.y)
    end
    clear_transform()

    if not ok then
        last_errors[#last_errors + 1] = id .. ": " .. tostring(err)
        if DEBUG_LOG then print("[MiniGames][" .. id .. "] " .. tostring(err)) end
    end
end

function script.OnDraw()
    load_fonts()

    local ttt_open = get_ui_value(ui_ttt_open, false)
    local chess_open = get_ui_value(ui_chess_open, false)
    local sol_open = get_ui_value(ui_sol_open, false)
    local mine_open = get_ui_value(ui_mine_open, false)
    local weather_open = get_ui_value(ui_weather_open, false)
    local battleship_open = get_ui_value(ui_battleship_open, false)
    local g2048_open = get_ui_value(ui_g2048_open, false)
    local casino_open = get_ui_value(ui_casino_open, false)
    local calc_open = get_ui_value(ui_calc_open, false)

    if ttt_open and not prev_open.ttt then ttt_reset() end
    if chess_open and not prev_open.chess then chess_reset() end
    if sol_open and not prev_open.sol then sol_reset() end
    if mine_open and not prev_open.mine then mine_reset() end
    if battleship_open and not prev_open.battleship then bs_reset() end
    if g2048_open and not prev_open.g2048 then g2048_reset() end
    if casino_open and not prev_open.casino then casino_reset() end
    prev_open.ttt, prev_open.chess, prev_open.sol, prev_open.mine, prev_open.weather, prev_open.battleship, prev_open.g2048, prev_open.casino, prev_open.calc =
ttt_open, chess_open, sol_open, mine_open, weather_open, battleship_open, g2048_open, casino_open, calc_open

    if not (ttt_open or chess_open or sol_open or mine_open or weather_open or battleship_open or g2048_open or casino_open or calc_open) then return end

    update_mouse_state()
    local mx, my = mouse_pos()
    local clicked = mouse_l.clicked
    local rclicked = mouse_r.clicked

    last_errors = {}

    if ttt_open then run_window("ttt", ttt_draw, mx, my, clicked) end
    if chess_open then run_window("chess", chess_draw, mx, my, clicked) end
    if mine_open then run_window("mine", mine_draw, mx, my, clicked, rclicked) end
    if weather_open then run_window("weather", weather_draw, mx, my, clicked) end
    if battleship_open then run_window("battleship", bs_draw, mx, my, clicked) end
    if g2048_open then run_window("g2048", g2048_draw, mx, my, clicked) end
    if casino_open then run_window("casino", casino_draw, mx, my, clicked) end
    if calc_open then run_window("calc", calc_draw, mx, my, clicked) end
    if sol_open then run_window("sol", sol_draw, mx, my, clicked) end

    if DEBUG_LOG and #last_errors > 0 then
        for i, e in ipairs(last_errors) do
            R.text(FONT.small, 13, e, 20, 20 + (i - 1) * 18, Color(255, 90, 90, 255))
        end
    end
end

return script