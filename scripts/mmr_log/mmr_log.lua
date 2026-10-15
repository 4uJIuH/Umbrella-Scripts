local PLAYER_ACCOUNT_ID = "YOUR_ACCOUNT_ID_HERE"
local OPENDOTA_MATCHES_URL = "https://api.opendota.com/api/players/" .. PLAYER_ACCOUNT_ID .. "/matches?date=1"

local LOG_FILE = Engine.GetCheatDirectory() .. "/mmr_log.csv"
local CSV_HEADER = "match_id,hero,start_mmr,end_mmr,mmr_change,win,start_time,duration\n"
local DAILY_FILE = Engine.GetCheatDirectory() .. "/mmr_daily.txt"

local refresh_ui

local state = {
    match_id = nil,
    start_mmr = nil,
    hero_name = nil,
    start_time = nil,
    logged = false,
    pending_since = nil,
    current_duration = 0,
}

local daily = {
    date = nil,
    games = 0,
    wins = 0,
    losses = 0,
    mmr_change = 0,
    start_mmr = nil,
    last_mmr = nil,
    hero_stats = {},
    time_stats = {},
    duration_stats = {},
    avg_gain = 0,
    avg_loss = 0,
    streak = {
        current = 0,
        best_win = 0,
        best_loss = 0
    },
    daily_goal_mmr = 100,
    daily_goal_games = 5,
    weekly_games = 0,
    weekly_wins = 0,
    weekly_mmr_change = 0,
}

local logged_matches = {}

local ui = {
    group = nil,
    summary_label = nil,
    streak_label = nil,
    hero_label = nil,
    time_label = nil,
    duration_label = nil,
    goals_label = nil,
    overlay_switch = nil,
    overlay_pos_x = nil,
    overlay_pos_y = nil,
    overlay_lock = nil,
}

local overlay = {
    font = nil,
    font_normal = nil,
    fonts_loaded = false,
    drag = { active = false, offset = Vec2(0, 0) },
    panel_pos = Vec2(0, 0),
    panel_size = Vec2(0, 0),
    panel_visible = false,
}

local OVERLAY_FONT_SIZE = 14
local OVERLAY_HEADER_FONT_SIZE = 15
local OVERLAY_PAD_X = 12
local OVERLAY_PAD_Y = 10
local OVERLAY_LINE_GAP = 4

local function ensure_overlay_fonts()
    if overlay.fonts_loaded then return end
    if not Render or not Enum then return end
    local ok1, f1 = pcall(Render.LoadFont, "Segoe UI", Enum.FontCreate.FONTFLAG_ANTIALIAS, Enum.FontWeight.BOLD)
    if ok1 then overlay.font = f1 end
    local ok2, f2 = pcall(Render.LoadFont, "Segoe UI", Enum.FontCreate.FONTFLAG_ANTIALIAS, Enum.FontWeight.NORMAL)
    if ok2 then overlay.font_normal = f2 end
    if overlay.font and overlay.font_normal then
        overlay.fonts_loaded = true
    end
end

local function today_str()
    return os.date("%Y-%m-%d")
end

local function get_week_number()
    local date = os.date("*t")
    local year_start = os.time{year=date.year, month=1, day=1}
    local day_of_year = math.floor((os.time(date) - year_start) / 86400) + 1
    return math.ceil(day_of_year / 7)
end

local function save_daily()
    local f = io.open(DAILY_FILE, "w")
    if not f then
        Log.Write("[mmr_tracker] Failed to open daily stats file for writing: " .. DAILY_FILE)
        return
    end
    f:write("date=" .. (daily.date or "") .. "\n")
    f:write("games=" .. (daily.games or 0) .. "\n")
    f:write("wins=" .. (daily.wins or 0) .. "\n")
    f:write("losses=" .. (daily.losses or 0) .. "\n")
    f:write("mmr_change=" .. (daily.mmr_change or 0) .. "\n")
    f:write("start_mmr=" .. (daily.start_mmr or 0) .. "\n")
    f:write("last_mmr=" .. (daily.last_mmr or 0) .. "\n")
    f:write("avg_gain=" .. (daily.avg_gain or 0) .. "\n")
    f:write("avg_loss=" .. (daily.avg_loss or 0) .. "\n")
    f:write("streak_current=" .. (daily.streak.current or 0) .. "\n")
    f:write("streak_best_win=" .. (daily.streak.best_win or 0) .. "\n")
    f:write("streak_best_loss=" .. (daily.streak.best_loss or 0) .. "\n")
    f:write("weekly_games=" .. (daily.weekly_games or 0) .. "\n")
    f:write("weekly_wins=" .. (daily.weekly_wins or 0) .. "\n")
    f:write("weekly_mmr_change=" .. (daily.weekly_mmr_change or 0) .. "\n")
    f:close()
end

refresh_ui = function()
    if not ui.group then return end

    local win_rate = (daily.games > 0) and (daily.wins / daily.games * 100) or 0
    local ok_mmr, live_mmr = pcall(Engine.GetMMRV2)
    if not ok_mmr or not live_mmr or live_mmr <= 0 then
        live_mmr = daily.last_mmr or daily.start_mmr or 0
    end
    local mmr_gained_total = daily.avg_gain * daily.wins
    local mmr_lost_total = daily.avg_loss * daily.losses

    local summary_lines = {
        string.format("Date: %s   Week: %d", today_str(), get_week_number()),
        string.format("Current MMR: %d", live_mmr),
        string.format("Games: %d   W/L: %d/%d   Win Rate: %.1f%%", daily.games, daily.wins, daily.losses, win_rate),
        string.format("Net MMR: %s%d   (%d -> %d)",
            (daily.mmr_change >= 0 and "+" or ""), daily.mmr_change,
            daily.start_mmr or 0, daily.last_mmr or 0),
        string.format("MMR Gained: +%d   MMR Lost: %d", mmr_gained_total, mmr_lost_total),
        string.format("Weekly: %d games, %d wins, %s%d MMR",
            daily.weekly_games, daily.weekly_wins,
            (daily.weekly_mmr_change >= 0 and "+" or ""), daily.weekly_mmr_change),
    }
    pcall(function() ui.summary_label:ForceLocalization(table.concat(summary_lines, "\n")) end)

    local streak_lines = {
        string.format("Current streak: %s%d", (daily.streak.current >= 0 and "+" or ""), daily.streak.current),
        string.format("Best win streak: %d   Best loss streak: %d", daily.streak.best_win, daily.streak.best_loss),
        string.format("Avg gain: %+.1f   Avg loss: %+.1f", daily.avg_gain, daily.avg_loss),
    }
    pcall(function() ui.streak_label:ForceLocalization(table.concat(streak_lines, "\n")) end)

    local mmr_goal_done = daily.mmr_change >= daily.daily_goal_mmr
    local games_goal_done = daily.games >= daily.daily_goal_games
    local goals_lines = {
        string.format("MMR goal: %d/%d %s", daily.mmr_change, daily.daily_goal_mmr, mmr_goal_done and "[DONE]" or ""),
        string.format("Games goal: %d/%d %s", daily.games, daily.daily_goal_games, games_goal_done and "[DONE]" or ""),
    }
    pcall(function() ui.goals_label:ForceLocalization(table.concat(goals_lines, "\n")) end)

    local hero_lines = {}
    local hero_names = {}
    for hero in pairs(daily.hero_stats) do table.insert(hero_names, hero) end
    table.sort(hero_names)
    if #hero_names == 0 then
        table.insert(hero_lines, "No hero data yet.")
    else
        for _, hero in ipairs(hero_names) do
            local stats = daily.hero_stats[hero]
            local hwr = (stats.games > 0) and (stats.wins / stats.games * 100) or 0
            local avg_mmr = (stats.games > 0) and (stats.mmr_change / stats.games) or 0
            table.insert(hero_lines, string.format("%-18s %2dG %2dW %2dL  %5.1f%%  %+4d net  %+5.1f avg",
                hero, stats.games, stats.wins, stats.losses, hwr, stats.mmr_change, avg_mmr))
        end
    end
    pcall(function() ui.hero_label:ForceLocalization(table.concat(hero_lines, "\n")) end)

    local time_lines = {}
    local slot_order = { "Morning", "Afternoon", "Evening", "Late Night" }
    for _, slot in ipairs(slot_order) do
        local stats = daily.time_stats[slot]
        if stats then
            local twr = (stats.games > 0) and (stats.wins / stats.games * 100) or 0
            table.insert(time_lines, string.format("%-11s %2dG %2dW  %5.1f%%  %+4d MMR",
                slot, stats.games, stats.wins, twr, stats.mmr_change))
        end
    end
    if #time_lines == 0 then table.insert(time_lines, "No time-slot data yet.") end
    pcall(function() ui.time_label:ForceLocalization(table.concat(time_lines, "\n")) end)

    local duration_lines = {}
    local dur_order = { "Short (<25min)", "Medium (25-40min)", "Long (>40min)" }
    for _, category in ipairs(dur_order) do
        local stats = daily.duration_stats[category]
        if stats then
            local dwr = (stats.games > 0) and (stats.wins / stats.games * 100) or 0
            table.insert(duration_lines, string.format("%-18s %2dG %2dW  %5.1f%%  %+4d MMR",
                category, stats.games, stats.wins, dwr, stats.mmr_change))
        end
    end
    if #duration_lines == 0 then table.insert(duration_lines, "No duration data yet.") end
    pcall(function() ui.duration_label:ForceLocalization(table.concat(duration_lines, "\n")) end)
end

local function reset_all_stats()
    daily.date = today_str()
    daily.games = 0
    daily.wins = 0
    daily.losses = 0
    daily.mmr_change = 0
    daily.start_mmr = nil
    daily.last_mmr = nil
    daily.avg_gain = 0
    daily.avg_loss = 0
    daily.streak.current = 0
    daily.streak.best_win = 0
    daily.streak.best_loss = 0
    daily.hero_stats = {}
    daily.time_stats = {}
    daily.duration_stats = {}
    daily.weekly_games = 0
    daily.weekly_wins = 0
    daily.weekly_mmr_change = 0
    
    logged_matches = {}
    
    local f = io.open(LOG_FILE, "w")
    if f then
        f:write(CSV_HEADER)
        f:close()
    end
    
    save_daily()
    Log.Write("[mmr_tracker] All stats have been reset to 0.")
end

local function build_ui()
    local overlay_tab = Menu.Create("MMR Tracker", "Stats", "Overview", "Overlay", "Overlay")
    ui.overlay_switch = overlay_tab:Switch("Show overlay on main menu", true)
    ui.overlay_lock = overlay_tab:Switch("Lock position", false)
    
    local ok_x, slider_x = pcall(function() return overlay_tab:Slider("Overlay X", 0, 3000, 40, "%d") end)
    if ok_x then ui.overlay_pos_x = slider_x end
    local ok_y, slider_y = pcall(function() return overlay_tab:Slider("Overlay Y", 0, 3000, 40, "%d") end)
    if ok_y then ui.overlay_pos_y = slider_y end
    
    local reset_tab = Menu.Create("MMR Tracker", "Stats", "Overview", "Reset", "Reset")
    ui.reset_button = reset_tab:Button("Reset All Stats to 0", function()
        reset_all_stats()
    end)
end

local function build_overlay_lines()
    local win_rate = (daily.games > 0) and (daily.wins / daily.games * 100) or 0
    local lines = {}

    local ok_mmr, live_mmr = pcall(Engine.GetMMRV2)
    if not ok_mmr or not live_mmr or live_mmr <= 0 then
        live_mmr = daily.last_mmr or daily.start_mmr or 0
    end

    local mmr_gained_total = daily.avg_gain * daily.wins
    local mmr_lost_total = daily.avg_loss * daily.losses

    table.insert(lines, string.format("MMR Tracker - %s", today_str()))
    table.insert(lines, string.format("Current MMR: %d", live_mmr))
    table.insert(lines, string.format("Games: %d   W/L: %d/%d   WR: %.1f%%",
        daily.games, daily.wins, daily.losses, win_rate))
    table.insert(lines, string.format("Net MMR: %s%d  (%d -> %d)",
        (daily.mmr_change >= 0 and "+" or ""), daily.mmr_change,
        daily.start_mmr or 0, daily.last_mmr or 0))
    table.insert(lines, string.format("MMR Gained: +%d      MMR Lost: %d",
        mmr_gained_total, mmr_lost_total))
    table.insert(lines, string.format("Avg Gain: %+.1f   Avg Loss: %+.1f",
        daily.avg_gain, daily.avg_loss))
    table.insert(lines, string.format("Streak: %s%d   Best Win: %d   Best Loss: %d",
        (daily.streak.current >= 0 and "+" or ""), daily.streak.current,
        daily.streak.best_win, daily.streak.best_loss))
    table.insert(lines, string.format("Weekly: %d games, %d wins, %s%d MMR",
        daily.weekly_games, daily.weekly_wins,
        (daily.weekly_mmr_change >= 0 and "+" or ""), daily.weekly_mmr_change))

    local top_hero, top_games = nil, 0
    for hero, stats in pairs(daily.hero_stats) do
        if stats.games > top_games then
            top_hero, top_games = hero, stats.games
        end
    end
    if top_hero then
        local hs = daily.hero_stats[top_hero]
        local hwr = (hs.games > 0) and (hs.wins / hs.games * 100) or 0
        table.insert(lines, string.format("Top Hero: %s  %dG %dW %dL  %.0f%%  %+d MMR",
            top_hero, hs.games, hs.wins, hs.losses, hwr, hs.mmr_change))
    end

    return lines
end

local function handle_overlay_drag(pos, size)
    if ui.overlay_lock and ui.overlay_lock:Get() then return end
    if not Input or not Enum then return end

    local ok_down, is_down = pcall(Input.IsKeyDown, Enum.ButtonCode.KEY_MOUSE1)
    if not ok_down then return end

    if is_down then
        local ok_cursor, cx, cy = pcall(Input.GetCursorPos)
        if not ok_cursor then return end
        local cursor = Vec2(cx, cy)
        local ok_in, in_rect = pcall(Input.IsCursorInRect, pos.x, pos.y, size.x, size.y)
        if not overlay.drag.active and ok_in and in_rect then
            overlay.drag.active = true
            overlay.drag.offset = cursor - pos
        elseif overlay.drag.active then
            local new_pos = cursor - overlay.drag.offset
            if ui.overlay_pos_x then ui.overlay_pos_x:Set(math.floor(new_pos.x)) end
            if ui.overlay_pos_y then ui.overlay_pos_y:Set(math.floor(new_pos.y)) end
        end
    else
        overlay.drag.active = false
    end
end

local function draw_overlay()
    if ui.overlay_switch and not ui.overlay_switch:Get() then
        overlay.panel_visible = false
        return
    end
    
    local ok, game_state = pcall(GameRules.GetGameState)
    if ok then
        if game_state == Enum.GameState.DOTA_GAMERULES_STATE_GAME_IN_PROGRESS or
           game_state == Enum.GameState.DOTA_GAMERULES_STATE_POST_GAME or
           game_state == Enum.GameState.DOTA_GAMERULES_STATE_HERO_SELECTION or
           game_state == Enum.GameState.DOTA_GAMERULES_STATE_STRATEGY_TIME or
           game_state == Enum.GameState.DOTA_GAMERULES_STATE_PRE_GAME or
           game_state == Enum.GameState.DOTA_GAMERULES_STATE_DISCONNECT then
            overlay.panel_visible = false
            return
        end
    end
    
    if not Render then return end

    ensure_overlay_fonts()
    if not overlay.fonts_loaded then return end

    local x = (ui.overlay_pos_x and ui.overlay_pos_x:Get()) or 40
    local y = (ui.overlay_pos_y and ui.overlay_pos_y:Get()) or 40
    local pos = Vec2(x, y)

    local lines = build_overlay_lines()

    local max_w, line_h = 0, OVERLAY_FONT_SIZE + 4
    for i, line in ipairs(lines) do
        local font_size = (i == 1) and OVERLAY_HEADER_FONT_SIZE or OVERLAY_FONT_SIZE
        local font = (i == 1) and overlay.font or overlay.font_normal
        local ok_size, sz = pcall(Render.TextSize, font, font_size, line)
        if ok_size and sz then
            if sz.x > max_w then max_w = sz.x end
            if sz.y > line_h then line_h = sz.y end
        end
    end

    local panel_w = max_w + OVERLAY_PAD_X * 2
    local panel_h = OVERLAY_PAD_Y * 2 + (#lines * (line_h + OVERLAY_LINE_GAP)) - OVERLAY_LINE_GAP
    local size = Vec2(panel_w, panel_h)

    overlay.panel_pos = pos
    overlay.panel_size = size
    overlay.panel_visible = true

    handle_overlay_drag(pos, size)

    pcall(Render.FilledRect, pos, pos + size, Color(15, 15, 20, 210), 8, Enum.DrawFlags.RoundCornersAll)

    local text_y = pos.y + OVERLAY_PAD_Y
    for i, line in ipairs(lines) do
        local font_size = (i == 1) and OVERLAY_HEADER_FONT_SIZE or OVERLAY_FONT_SIZE
        local font = (i == 1) and overlay.font or overlay.font_normal
        local color = (i == 1) and Color(255, 220, 130, 255) or Color(255, 255, 255, 255)
        pcall(Render.Text, font, font_size, line, Vec2(pos.x + OVERLAY_PAD_X, text_y), color)
        text_y = text_y + line_h + OVERLAY_LINE_GAP
    end
end

local function get_time_slot()
    local hour = tonumber(os.date("%H", os.time()))
    if hour >= 0 and hour < 6 then return "Late Night"
    elseif hour >= 6 and hour < 12 then return "Morning"
    elseif hour >= 12 and hour < 18 then return "Afternoon"
    else return "Evening" end
end

local function get_duration_category(duration)
    local minutes = math.floor(duration / 60)
    if minutes < 25 then return "Short (<25min)"
    elseif minutes < 40 then return "Medium (25-40min)"
    else return "Long (>40min)" end
end

local function read_daily_file()
    local values = {}
    local f = io.open(DAILY_FILE, "r")
    if not f then return values end
    for line in f:lines() do
        local key, value = line:match("^(%w+)=(.*)$")
        if key then
            values[key] = value
        end
    end
    f:close()
    return values
end

local function load_or_reset_daily()
    local today = today_str()
    local values = read_daily_file()

    if values.date == today then
        daily.date = today
        daily.games = tonumber(values.games) or 0
        daily.wins = tonumber(values.wins) or 0
        daily.losses = tonumber(values.losses) or 0
        local saved_start = tonumber(values.start_mmr) or 0
        daily.start_mmr = saved_start ~= 0 and saved_start or nil
        local saved_last = tonumber(values.last_mmr) or 0
        daily.last_mmr = saved_last ~= 0 and saved_last or nil
        daily.avg_gain = tonumber(values.avg_gain) or 0
        daily.avg_loss = tonumber(values.avg_loss) or 0
        daily.streak.current = tonumber(values.streak_current) or 0
        daily.streak.best_win = tonumber(values.streak_best_win) or 0
        daily.streak.best_loss = tonumber(values.streak_best_loss) or 0
        daily.weekly_games = tonumber(values.weekly_games) or 0
        daily.weekly_wins = tonumber(values.weekly_wins) or 0
        daily.weekly_mmr_change = tonumber(values.weekly_mmr_change) or 0

        if daily.start_mmr and daily.last_mmr then
            daily.mmr_change = daily.last_mmr - daily.start_mmr
        else
            daily.mmr_change = tonumber(values.mmr_change) or 0
        end

        Log.Write(string.format(
            "[mmr_tracker] Resumed today's stats: %d games (%dW-%dL), net %+d MMR",
            daily.games, daily.wins, daily.losses, daily.mmr_change
        ))
    else
        daily.date = today
        daily.games = 0
        daily.wins = 0
        daily.losses = 0
        daily.mmr_change = 0
        daily.start_mmr = nil
        daily.last_mmr = nil
        daily.avg_gain = 0
        daily.avg_loss = 0
        daily.streak.current = 0
        daily.streak.best_win = 0
        daily.streak.best_loss = 0
        daily.hero_stats = {}
        daily.time_stats = {}
        daily.duration_stats = {}
        daily.weekly_games = 0
        daily.weekly_wins = 0
        daily.weekly_mmr_change = 0
        save_daily()
        Log.Write("[mmr_tracker] New day detected, daily stats reset.")
    end
end

local function check_day_rollover()
    local today = today_str()
    if daily.date ~= today then
        load_or_reset_daily()
        pcall(refresh_ui)
    end
end

local function calculate_mmr_change_from_daily(start_mmr, end_mmr)
    if daily.start_mmr and daily.last_mmr and daily.games > 0 then
        local total_change = daily.last_mmr - daily.start_mmr
        if end_mmr == start_mmr then
            local avg_change = math.floor((total_change / daily.games) + 0.5)
            return -math.abs(avg_change)
        end
    end
    return end_mmr - start_mmr
end

local function update_hero_stats(hero_name, mmr_change, win)
    if not hero_name or hero_name == "unknown" then return end

    if not daily.hero_stats[hero_name] then
        daily.hero_stats[hero_name] = {games=0, wins=0, losses=0, mmr_change=0}
    end
    daily.hero_stats[hero_name].games = daily.hero_stats[hero_name].games + 1
    if win then
        daily.hero_stats[hero_name].wins = daily.hero_stats[hero_name].wins + 1
    else
        daily.hero_stats[hero_name].losses = daily.hero_stats[hero_name].losses + 1
    end
    daily.hero_stats[hero_name].mmr_change = daily.hero_stats[hero_name].mmr_change + mmr_change
end

local function update_time_stats(mmr_change, win)
    local time_slot = get_time_slot()
    if not daily.time_stats[time_slot] then
        daily.time_stats[time_slot] = {games=0, wins=0, mmr_change=0}
    end
    daily.time_stats[time_slot].games = daily.time_stats[time_slot].games + 1
    if win then
        daily.time_stats[time_slot].wins = daily.time_stats[time_slot].wins + 1
    end
    daily.time_stats[time_slot].mmr_change = daily.time_stats[time_slot].mmr_change + mmr_change
end

local function update_duration_stats(duration, mmr_change, win)
    if not duration or duration == 0 then return end
    local category = get_duration_category(duration)
    if not daily.duration_stats[category] then
        daily.duration_stats[category] = {games=0, wins=0, mmr_change=0}
    end
    daily.duration_stats[category].games = daily.duration_stats[category].games + 1
    if win then
        daily.duration_stats[category].wins = daily.duration_stats[category].wins + 1
    end
    daily.duration_stats[category].mmr_change = daily.duration_stats[category].mmr_change + mmr_change
end

local function update_streak(mmr_change)
    if mmr_change > 0 then
        if daily.streak.current >= 0 then
            daily.streak.current = daily.streak.current + 1
        else
            daily.streak.current = 1
        end
        if daily.streak.current > daily.streak.best_win then
            daily.streak.best_win = daily.streak.current
        end
    elseif mmr_change < 0 then
        if daily.streak.current <= 0 then
            daily.streak.current = daily.streak.current - 1
        else
            daily.streak.current = -1
        end
        if daily.streak.current < daily.streak.best_loss then
            daily.streak.best_loss = daily.streak.current
        end
    end
end

local function update_daily(match_id, hero_name, start_mmr, end_mmr, mmr_change, start_time, duration, win)
    check_day_rollover()

    if not daily.start_mmr then
        daily.start_mmr = start_mmr or end_mmr
    end

    local actual_change = mmr_change
    if actual_change == 0 and end_mmr == start_mmr then
        actual_change = calculate_mmr_change_from_daily(start_mmr, end_mmr)
    end

    if actual_change ~= 0 then
        daily.last_mmr = (daily.last_mmr or start_mmr) + actual_change
    else
        daily.last_mmr = end_mmr or start_mmr
    end

    daily.games = daily.games + 1
    daily.weekly_games = daily.weekly_games + 1

    if actual_change > 0 then
        daily.wins = daily.wins + 1
        daily.weekly_wins = daily.weekly_wins + 1
        if daily.avg_gain == 0 then
            daily.avg_gain = actual_change
        else
            daily.avg_gain = (daily.avg_gain * (daily.wins - 1) + actual_change) / daily.wins
        end
    elseif actual_change < 0 then
        daily.losses = daily.losses + 1
        if daily.avg_loss == 0 then
            daily.avg_loss = actual_change
        else
            daily.avg_loss = (daily.avg_loss * (daily.losses - 1) + actual_change) / daily.losses
        end
    end

    daily.weekly_mmr_change = daily.weekly_mmr_change + actual_change

    if daily.start_mmr and daily.last_mmr then
        daily.mmr_change = daily.last_mmr - daily.start_mmr
    else
        daily.mmr_change = daily.mmr_change + actual_change
    end

    update_hero_stats(hero_name, actual_change, actual_change > 0)
    update_time_stats(actual_change, actual_change > 0)
    update_duration_stats(duration, actual_change, actual_change > 0)
    update_streak(actual_change)

    save_daily()
    pcall(refresh_ui)

    local win_rate = (daily.games > 0) and (daily.wins / daily.games * 100) or 0
    Log.Write(string.format(
        "[mmr_tracker] Today: %d games (%dW-%dL), Win Rate: %.1f%%, Net: %+d MMR (%d -> %d)",
        daily.games, daily.wins, daily.losses, win_rate, daily.mmr_change,
        daily.start_mmr or end_mmr, daily.last_mmr
    ))
    Log.Write(string.format(
        "[mmr_tracker] Streak: %+d (Best Win: %d, Best Loss: %d), Avg Gain: %+.1f, Avg Loss: %+.1f",
        daily.streak.current, daily.streak.best_win, daily.streak.best_loss,
        daily.avg_gain, daily.avg_loss
    ))

    if daily.mmr_change >= daily.daily_goal_mmr then
        Log.Write(string.format("[mmr_tracker] Daily MMR goal achieved! (+%d MMR)", daily.mmr_change))
    end
    if daily.games >= daily.daily_goal_games then
        Log.Write(string.format("[mmr_tracker] Daily game goal achieved! (%d games)", daily.games))
    end
end

local function resolve_hero_display_name(hero_id)
    if not hero_id then return "unknown" end

    local ok1, unit_name = pcall(Engine.GetHeroNameByID, hero_id)
    if not ok1 or not unit_name or unit_name == "" then
        return "hero_id_" .. tostring(hero_id)
    end

    local ok2, display_name = pcall(Engine.GetDisplayNameByUnitName, unit_name)
    if ok2 and display_name and display_name ~= "" then
        return display_name
    end
    return unit_name
end

local function ensure_log_file()
    local f = io.open(LOG_FILE, "r")
    if f then
        for line in f:lines() do
            local id = line:match("^(%d+),")
            if id then
                logged_matches[id] = true
            end
        end
        f:close()
    else
        local nf = io.open(LOG_FILE, "w")
        if nf then
            nf:write(CSV_HEADER)
            nf:close()
        end
    end
end

local function migrate_hero_id_placeholders()
    local f = io.open(LOG_FILE, "r")
    if not f then return end
    local lines = {}
    for line in f:lines() do
        table.insert(lines, line)
    end
    f:close()

    local changed = false
    for i, line in ipairs(lines) do
        if i > 1 then
            local hero_id_str = line:match(",hero_id_(%d+),")
            if hero_id_str then
                local ok, resolved = pcall(resolve_hero_display_name, tonumber(hero_id_str))
                if ok and resolved and resolved ~= ("hero_id_" .. hero_id_str) then
                    lines[i] = line:gsub(",hero_id_" .. hero_id_str .. ",", "," .. resolved .. ",", 1)
                    changed = true
                end
            end
        end
    end

    if changed then
        local wf = io.open(LOG_FILE, "w")
        if wf then
            for _, l in ipairs(lines) do
                wf:write(l .. "\n")
            end
            wf:close()
            Log.Write("[mmr_tracker] Migrated hero_id placeholders to resolved names in " .. LOG_FILE)
        end
    end
end

local function reset_state()
    state.match_id = nil
    state.start_mmr = nil
    state.hero_name = nil
    state.start_time = nil
    state.logged = false
    state.pending_since = nil
    state.current_duration = 0
end

local function log_match(match_id, hero, start_mmr, end_mmr, mmr_change, start_time, duration, explicit_win)
    local id_str = tostring(match_id)
    if logged_matches[id_str] then
        return
    end

    local win = ""
    if explicit_win ~= nil then
        win = explicit_win
    elseif mmr_change > 0 then
        win = 1
    elseif mmr_change < 0 then
        win = 0
    end

    local f = io.open(LOG_FILE, "a")
    if not f then
        Log.Write("[mmr_tracker] Failed to open log file for writing: " .. LOG_FILE)
        return
    end

    f:write(string.format(
        "%s,%s,%d,%d,%d,%s,%s,%d\n",
        id_str,
        hero or "unknown",
        start_mmr or 0,
        end_mmr or 0,
        mmr_change or 0,
        tostring(win),
        os.date("%Y-%m-%d %H:%M:%S", start_time or os.time()),
        math.floor(duration or 0)
    ))
    f:close()

    logged_matches[id_str] = true
    Log.Write(string.format(
        "[mmr_tracker] Logged match %s: %d -> %d (%+d MMR)",
        id_str, start_mmr or 0, end_mmr or 0, mmr_change or 0
    ))
end

local function capture_hero_name()
    if state.hero_name then return end
    local ok, hero = pcall(Heroes.GetLocal)
    if not ok or not hero then return end

    local ok2, unit_name = pcall(NPC.GetUnitName, hero)
    if not ok2 or not unit_name then return end

    local display_name = unit_name

    local ok3, engine_name = pcall(Engine.GetDisplayNameByUnitName, unit_name)
    if ok3 and engine_name and engine_name ~= "" then
        display_name = engine_name
    else
        local ok4, localized = pcall(GameLocalizer.FindNPC, unit_name)
        if ok4 and localized and localized ~= "" then
            display_name = localized
        end
    end

    state.hero_name = display_name
end

local function capture_start_state()
    if state.match_id then return end

    local ok_id, match_id = pcall(GameRules.GetMatchID)
    if not ok_id then
        Log.Write("[mmr_tracker] GameRules.GetMatchID() errored: " .. tostring(match_id))
        return
    end
    if not match_id or match_id == 0 then return end

    local ok_mmr, mmr = pcall(Engine.GetMMRV2)
    if not ok_mmr then
        Log.Write("[mmr_tracker] Engine.GetMMRV2() errored: " .. tostring(mmr))
        mmr = nil
    end

    state.match_id = match_id
    state.start_mmr = mmr
    state.start_time = os.time()
    state.logged = false
    Log.Write(string.format("[mmr_tracker] Tracking match %s, start MMR %s",
        tostring(match_id), tostring(mmr)))
end

local function do_log()
    if not state.match_id or state.logged then return end

    pcall(capture_hero_name)

    local ok_mmr, end_mmr = pcall(Engine.GetMMRV2)
    if not ok_mmr then
        Log.Write("[mmr_tracker] Engine.GetMMRV2() errored at log time: " .. tostring(end_mmr))
        end_mmr = state.start_mmr or 0
    end

    local mmr_change = 0

    if end_mmr == state.start_mmr then
        if daily.last_mmr and daily.start_mmr then
            local total_games = daily.games + 1
            local total_change = daily.last_mmr - daily.start_mmr

            if daily.games > 0 then
                local avg_change = math.floor((total_change / daily.games) + 0.5)
                mmr_change = -math.abs(avg_change)
            else
                mmr_change = -40
            end
        else
            mmr_change = -40
        end

        end_mmr = (state.start_mmr or 0) + mmr_change
    else
        mmr_change = end_mmr - (state.start_mmr or end_mmr)
    end

    local ok_duration, duration = pcall(function()
        return GameRules.GetGameTime() - GameRules.GetGameStartTime()
    end)
    if not ok_duration then duration = 0 end
    state.current_duration = duration

    local is_win = mmr_change > 0

    log_match(state.match_id, state.hero_name, state.start_mmr, end_mmr,
        mmr_change, state.start_time, duration)

    pcall(update_daily, state.match_id, state.hero_name, state.start_mmr,
        end_mmr, mmr_change, state.start_time, duration, is_win)

    state.logged = true
end

local function is_radiant_slot(player_slot)
    return player_slot < 128
end

local function backfill_matches(matches)
    check_day_rollover()
    local today = today_str()
    local added = 0

    for _, m in ipairs(matches) do
        local match_id = m.match_id
        local start_time = m.start_time
        if match_id and start_time and os.date("%Y-%m-%d", start_time) == today then
            local id_str = tostring(match_id)
            if not logged_matches[id_str] then
                local win = 0
                if m.player_slot ~= nil and m.radiant_win ~= nil then
                    local won = (is_radiant_slot(m.player_slot) == m.radiant_win)
                    win = won and 1 or 0
                end

                local hero_name = resolve_hero_display_name(m.hero_id)
                log_match(match_id, hero_name, 0, 0, 0, start_time, m.duration or 0, win)

                daily.games = daily.games + 1
                daily.weekly_games = daily.weekly_games + 1
                if win == 1 then
                    daily.wins = daily.wins + 1
                    daily.weekly_wins = daily.weekly_wins + 1
                else
                    daily.losses = daily.losses + 1
                end
                added = added + 1
            end
        end
    end

    if added > 0 then
        if daily.start_mmr and daily.last_mmr then
            daily.mmr_change = daily.last_mmr - daily.start_mmr
        end
        save_daily()
        pcall(refresh_ui)
        Log.Write(string.format("[mmr_tracker] Backfilled %d match(es) from today's OpenDota history.", added))
    else
        Log.Write("[mmr_tracker] No new matches to backfill from OpenDota history.")
    end
end

local function fetch_match_history()
    local ok_req, err_req = pcall(function()
        local JSON = require('assets.JSON')
        HTTP.Request("GET", OPENDOTA_MATCHES_URL, {
            headers = { ["User-Agent"] = "mmr_tracker/1.0" },
            timeout = 15,
        }, function(response)
            local ok_cb, err_cb = pcall(function()
                if not response or not response.response or response.response == "" then
                    Log.Write("[mmr_tracker] Match history request returned no data.")
                    return
                end
                local matches = JSON:decode(response.response)
                if type(matches) ~= "table" then
                    Log.Write("[mmr_tracker] Match history: unexpected response format.")
                    return
                end
                backfill_matches(matches)
            end)
            if not ok_cb then
                Log.Write("[mmr_tracker] Match history callback error: " .. tostring(err_cb))
            end
        end, "mmr_tracker_history")
    end)
    if not ok_req then
        Log.Write("[mmr_tracker] Failed to request match history: " .. tostring(err_req))
    end
end

local FINALIZE_DELAY_SECONDS = 6

local function handle_state(game_state)
    if game_state == Enum.GameState.DOTA_GAMERULES_STATE_HERO_SELECTION
        or game_state == Enum.GameState.DOTA_GAMERULES_STATE_STRATEGY_TIME
        or game_state == Enum.GameState.DOTA_GAMERULES_STATE_PRE_GAME
        or game_state == Enum.GameState.DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
        capture_start_state()
        pcall(capture_hero_name)

    elseif game_state == Enum.GameState.DOTA_GAMERULES_STATE_POST_GAME then
        pcall(capture_hero_name)
        if state.match_id and not state.logged and not state.pending_since then
            state.pending_since = os.time()
            Log.Write("[mmr_tracker] Match ended, waiting " .. FINALIZE_DELAY_SECONDS
                .. "s for MMR to update before logging...")
        end

    elseif game_state == Enum.GameState.DOTA_GAMERULES_STATE_DISCONNECT then
        if state.match_id and not state.logged and not state.pending_since then
            state.pending_since = os.time()
            Log.Write("[mmr_tracker] Left match, waiting " .. FINALIZE_DELAY_SECONDS
                .. "s for MMR to update before logging...")
        end
    end
end

local function check_pending_finalize()
    if state.pending_since and not state.logged then
        if os.time() - state.pending_since >= FINALIZE_DELAY_SECONDS then
            do_log()
            reset_state()
        end
    end
end

local last_seen_state = nil

local function poll_state()
    local ok, game_state = pcall(GameRules.GetGameState)
    if not ok then return end
    if game_state == last_seen_state then return end

    last_seen_state = game_state
    Log.Write("[mmr_tracker] Poll fallback: State changed -> " .. tostring(game_state))
    handle_state(game_state)
end

return {
    OnScriptsLoaded = function()
        ensure_log_file()
        pcall(migrate_hero_id_placeholders)
        load_or_reset_daily()
        pcall(build_ui)
        pcall(refresh_ui)
        pcall(ensure_overlay_fonts)
        Log.Write("[mmr_tracker] Loaded with advanced stats tracking!")
        Log.Write("[mmr_tracker] Match log: " .. LOG_FILE)
        Log.Write("[mmr_tracker] Daily state file: " .. DAILY_FILE)
        pcall(fetch_match_history)
    end,

    OnFrame = function()
        local ok, err = pcall(draw_overlay)
        if not ok then
            Log.Write("[mmr_tracker] draw_overlay error: " .. tostring(err))
        end
    end,

    OnUpdate = function()
        local ok, err = pcall(poll_state)
        if not ok then
            Log.Write("[mmr_tracker] OnUpdate error: " .. tostring(err))
        end
        local ok2, err2 = pcall(check_pending_finalize)
        if not ok2 then
            Log.Write("[mmr_tracker] check_pending_finalize error: " .. tostring(err2))
        end
    end,

    OnGameRulesStateChange = function(data)
        local ok, err = pcall(function()
            if data and data.state then
                Log.Write("[mmr_tracker] State changed -> " .. tostring(data.state))
                handle_state(data.state)
            end
        end)
        if not ok then
            Log.Write("[mmr_tracker] OnGameRulesStateChange error: " .. tostring(err))
        end
    end,

    OnGameEnd = function()
        local ok, err = pcall(function()
            if state.match_id and not state.logged and not state.pending_since then
                state.pending_since = os.time()
                Log.Write("[mmr_tracker] OnGameEnd fired, waiting " .. FINALIZE_DELAY_SECONDS
                    .. "s for MMR to update before logging...")
            end
        end)
        if not ok then
            Log.Write("[mmr_tracker] OnGameEnd error: " .. tostring(err))
        end
    end,
}