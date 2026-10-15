local SessionInfo = {}
cached = cached or { mmr = 0, steam_name = "", flags = {}, stats5 = nil }

local DB_KEY_SIGNEDOUT = "signedout_match_ids"
local DB_KEY_SESSION = "session"
local DB_NAMESPACE = "sessioninfo"

local function InitDB()
    if type(db[DB_NAMESPACE]) ~= "userdata" then db[DB_NAMESPACE] = {} end
end

local function InitSignedOutDB()
    InitDB()
    if type(db[DB_NAMESPACE][DB_KEY_SIGNEDOUT]) ~= "table" then
        if type(db["x"]) == "userdata" and type(db["x"][DB_KEY_SIGNEDOUT]) == "table" then
            db[DB_NAMESPACE][DB_KEY_SIGNEDOUT] = db["x"][DB_KEY_SIGNEDOUT]
        else
            db[DB_NAMESPACE][DB_KEY_SIGNEDOUT] = {}
        end
    end
end

local function LoadSignedOutMatchIds()
    InitSignedOutDB()
    local lst = db[DB_NAMESPACE][DB_KEY_SIGNEDOUT]
    if type(lst) ~= "table" then return {} end
    local out = {}
    for i = 1, math.min(25, #lst) do
        local v = tonumber(lst[i])
        if v and v > 0 then out[#out + 1] = v end
    end
    return out
end

local function SaveSignedOutMatchId(mid)
    if not mid or mid <= 0 then return end
    InitSignedOutDB()
    local lst = db[DB_NAMESPACE][DB_KEY_SIGNEDOUT]
    if type(lst) ~= "table" then lst = {} end
    for i = 1, #lst do
        if lst[i] == mid then return end
    end
    table.insert(lst, 1, mid)
    while #lst > 25 do table.remove(lst) end
    db[DB_NAMESPACE][DB_KEY_SIGNEDOUT] = lst
end

local session = {
    start_clock = 0,
    start_mmr = 0,
    start_time = 0,
    wins = 0,
    losses = 0,
    initialized = false
}

local function GetSessionFilePath()
    local ok, dir = pcall(function() return Engine.GetCheatDirectory() or "" end)
    if not ok or not dir or dir == "" then return nil end
    return (dir:gsub("[\\/]+$", "")) .. "/sessioninfo_session.txt"
end

local function GetDotaLaunchTime()
    return os.time() - math.floor(os.clock())
end

local function SaveSession()
    if not session.initialized then return end
    local dotaLaunch = GetDotaLaunchTime()
    local path = GetSessionFilePath()
    if path then
        pcall(function()
            local f = io.open(path, "w")
            if f then
                f:write(string.format("%d\n%d\n%d\n%d\n%d\n%d",
                    session.start_clock or 0, session.start_mmr or 0, session.start_time or 0,
                    session.wins or 0, session.losses or 0, dotaLaunch))
                f:close()
            end
        end)
    end
    InitDB()
    db[DB_NAMESPACE][DB_KEY_SESSION] = {
        start_clock = session.start_clock, start_mmr = session.start_mmr, start_time = session.start_time,
        wins = session.wins, losses = session.losses, dota_launch_time = dotaLaunch
    }
end

local SESSION_LAUNCH_TOLERANCE = 120

local function LoadSession()
    local path = GetSessionFilePath()
    if path then
        local ok, data = pcall(function()
            local f = io.open(path, "r")
            if not f then return nil end
            local t = {}
            for i = 1, 6 do t[i] = tonumber(f:read("*l")) or 0 end
            f:close()
            return t
        end)
        if ok and data and #data >= 6 then
            local v6 = data[6] or 0
            if v6 > 1000000000 then
                local currentLaunch = GetDotaLaunchTime()
                if math.abs(currentLaunch - v6) > SESSION_LAUNCH_TOLERANCE then return false end
            end
            session.start_clock, session.start_mmr, session.start_time = data[1], data[2], data[3]
            session.wins, session.losses = data[4], data[5]
            session.initialized = (session.start_mmr or 0) > 0
            return true
        end
    end
    InitDB()
    local saved = db[DB_NAMESPACE][DB_KEY_SESSION]
    if type(saved) ~= "table" then return false end
    local savedLaunch = tonumber(saved.dota_launch_time) or tonumber(saved.last_save_time) or tonumber(saved.process_clock) or 0
    if savedLaunch > 1000000000 then
        local currentLaunch = GetDotaLaunchTime()
        if math.abs(currentLaunch - savedLaunch) > SESSION_LAUNCH_TOLERANCE then return false end
    end
    session.start_clock = tonumber(saved.start_clock) or 0
    session.start_mmr = tonumber(saved.start_mmr) or 0
    session.start_time = tonumber(saved.start_time) or 0
    session.wins = tonumber(saved.wins) or 0
    session.losses = tonumber(saved.losses) or 0
    session.initialized = (session.start_mmr or 0) > 0
    return true
end

local countries = {
    {"—", ""},
    {"Afghanistan", "af"}, {"Albania", "al"}, {"Algeria", "dz"}, {"Andorra", "ad"}, {"Angola", "ao"},
    {"Anguilla", "ai"}, {"Antigua and Barbuda", "ag"}, {"Argentina", "ar"}, {"Armenia", "am"}, {"Aruba", "aw"},
    {"Australia", "au"}, {"Austria", "at"}, {"Azerbaijan", "az"}, {"Bahamas", "bs"}, {"Bahrain", "bh"},
    {"Bangladesh", "bd"}, {"Barbados", "bb"}, {"Belarus", "by"}, {"Belgium", "be"}, {"Belize", "bz"},
    {"Benin", "bj"}, {"Bermuda", "bm"}, {"Bhutan", "bt"}, {"Bolivia", "bo"}, {"Bosnia and Herzegovina", "ba"},
    {"Botswana", "bw"}, {"Brazil", "br"}, {"Brunei", "bn"}, {"Bulgaria", "bg"}, {"Burkina Faso", "bf"},
    {"Burundi", "bi"}, {"Cambodia", "kh"}, {"Cameroon", "cm"}, {"Canada", "ca"}, {"Cape Verde", "cv"},
    {"Cayman Islands", "ky"}, {"Central African Republic", "cf"}, {"Chad", "td"}, {"Chile", "cl"},
    {"China", "cn"}, {"Colombia", "co"}, {"Comoros", "km"}, {"Congo", "cg"}, {"DR Congo", "cd"},
    {"Cook Islands", "ck"}, {"Costa Rica", "cr"}, {"Croatia", "hr"}, {"Cuba", "cu"}, {"Curacao", "cw"},
    {"Cyprus", "cy"}, {"Czechia", "cz"}, {"Denmark", "dk"}, {"Djibouti", "dj"}, {"Dominica", "dm"},
    {"Dominican Republic", "do"}, {"Ecuador", "ec"}, {"Egypt", "eg"}, {"El Salvador", "sv"},
    {"Equatorial Guinea", "gq"}, {"Eritrea", "er"}, {"Estonia", "ee"}, {"Eswatini", "sz"}, {"Ethiopia", "et"},
    {"Fiji", "fj"}, {"Finland", "fi"}, {"France", "fr"}, {"Gabon", "ga"}, {"Gambia", "gm"},
    {"Georgia", "ge"}, {"Germany", "de"}, {"Ghana", "gh"}, {"Gibraltar", "gi"}, {"Greece", "gr"},
    {"Grenada", "gd"}, {"Guadeloupe", "gp"}, {"Guam", "gu"}, {"Guatemala", "gt"}, {"Guernsey", "gg"},
    {"Guinea", "gn"}, {"Guinea-Bissau", "gw"}, {"Guyana", "gy"}, {"Haiti", "ht"}, {"Honduras", "hn"},
    {"Hong Kong", "hk"}, {"Hungary", "hu"}, {"Iceland", "is"}, {"India", "in"}, {"Indonesia", "id"},
    {"Iran", "ir"}, {"Iraq", "iq"}, {"Ireland", "ie"}, {"Isle of Man", "im"}, {"Israel", "il"},
    {"Italy", "it"}, {"Ivory Coast", "ci"}, {"Jamaica", "jm"}, {"Japan", "jp"}, {"Jersey", "je"},
    {"Jordan", "jo"}, {"Kazakhstan", "kz"}, {"Kenya", "ke"}, {"Kiribati", "ki"},
    {"North Korea", "kp"}, {"South Korea", "kr"}, {"Kuwait", "kw"}, {"Kyrgyzstan", "kg"}, {"Laos", "la"},
    {"Latvia", "lv"}, {"Lebanon", "lb"}, {"Lesotho", "ls"}, {"Liberia", "lr"}, {"Libya", "ly"},
    {"Liechtenstein", "li"}, {"Lithuania", "lt"}, {"Luxembourg", "lu"}, {"Macau", "mo"}, {"Madagascar", "mg"},
    {"Malawi", "mw"}, {"Malaysia", "my"}, {"Maldives", "mv"}, {"Mali", "ml"}, {"Malta", "mt"},
    {"Marshall Islands", "mh"}, {"Martinique", "mq"}, {"Mauritania", "mr"}, {"Mauritius", "mu"},
    {"Mexico", "mx"}, {"Micronesia", "fm"}, {"Moldova", "md"}, {"Monaco", "mc"}, {"Mongolia", "mn"},
    {"Montenegro", "me"}, {"Montserrat", "ms"}, {"Morocco", "ma"}, {"Mozambique", "mz"}, {"Myanmar", "mm"},
    {"Namibia", "na"}, {"Nauru", "nr"}, {"Nepal", "np"}, {"Netherlands", "nl"}, {"New Caledonia", "nc"},
    {"New Zealand", "nz"}, {"Nicaragua", "ni"}, {"Niger", "ne"}, {"Nigeria", "ng"}, {"North Macedonia", "mk"},
    {"Northern Mariana Islands", "mp"}, {"Norway", "no"}, {"Oman", "om"}, {"Pakistan", "pk"}, {"Palau", "pw"},
    {"Palestine", "ps"}, {"Panama", "pa"}, {"Papua New Guinea", "pg"}, {"Paraguay", "py"}, {"Peru", "pe"},
    {"Philippines", "ph"}, {"Poland", "pl"}, {"Portugal", "pt"}, {"Puerto Rico", "pr"}, {"Qatar", "qa"},
    {"Reunion", "re"}, {"Romania", "ro"}, {"Russia", "ru"}, {"Rwanda", "rw"}, {"Saint Kitts and Nevis", "kn"},
    {"Saint Lucia", "lc"}, {"Saint Vincent and the Grenadines", "vc"}, {"Samoa", "ws"}, {"San Marino", "sm"},
    {"Sao Tome and Principe", "st"}, {"Saudi Arabia", "sa"}, {"Senegal", "sn"}, {"Serbia", "rs"},
    {"Seychelles", "sc"}, {"Sierra Leone", "sl"}, {"Singapore", "sg"}, {"Sint Maarten", "sx"},
    {"Slovakia", "sk"}, {"Slovenia", "si"}, {"Solomon Islands", "sb"}, {"Somalia", "so"}, {"South Africa", "za"},
    {"South Sudan", "ss"}, {"Spain", "es"}, {"Sri Lanka", "lk"}, {"Sudan", "sd"}, {"Suriname", "sr"},
    {"Sweden", "se"}, {"Switzerland", "ch"}, {"Syria", "sy"}, {"Taiwan", "tw"}, {"Tajikistan", "tj"},
    {"Tanzania", "tz"}, {"Thailand", "th"}, {"Timor-Leste", "tl"}, {"Togo", "tg"}, {"Tonga", "to"},
    {"Trinidad and Tobago", "tt"}, {"Tunisia", "tn"}, {"Turkey", "tr"}, {"Turkmenistan", "tm"}, {"Turks and Caicos Islands", "tc"},
    {"Tuvalu", "tv"}, {"Uganda", "ug"}, {"Ukraine", "ua"}, {"UAE", "ae"}, {"United Kingdom", "gb"},
    {"United States", "us"}, {"Uruguay", "uy"}, {"Uzbekistan", "uz"}, {"Vanuatu", "vu"}, {"Venezuela", "ve"},
    {"Vietnam", "vn"}, {"Virgin Islands (British)", "vg"}, {"Virgin Islands (US)", "vi"}, {"Yemen", "ye"},
    {"Zambia", "zm"}, {"Zimbabwe", "zw"}
}
local country_names = {}
for i, c in ipairs(countries) do
    country_names[i] = c[1]
end

local lang_widget_cache = nil
local LANG_PATHS = {
    {"SettingsHidden", "", "", "", "Main", "Language"},
    {"Settings", "Settings", "", "", "Main", "Language"},
    {"Settings", "", "", "", "Main", "Language"},
}

local function GetLangWidget()
    if lang_widget_cache and lang_widget_cache.Get and lang_widget_cache.List then
        return lang_widget_cache
    end
    for _, path in ipairs(LANG_PATHS) do
        local w = Menu.Find(path[1], path[2], path[3], path[4], path[5], path[6])
        if w and w.Get and w.List then
            lang_widget_cache = w
            return w
        end
    end
    return nil
end

local function GetCheatLanguage()
    local w = GetLangWidget()
    if w then
        local ok, idx = pcall(function() return w:Get() end)
        if not ok then
            lang_widget_cache = nil
            return "en"
        end
        if idx and idx >= 0 then
            local ok2, list = pcall(function() return w:List() end)
            if not ok2 then
                lang_widget_cache = nil
                return "en"
            end
            if list and idx < #list then
                local name = list[idx + 1]
                if name and string.lower(tostring(name)):find("ru") then return "ru" end
            end
        end
    end
    return "en"
end

local LOCALIZE = {
    ru = {
        enable_panel = "Включить панель", lock_pos = "Заблокировать позицию", transparent = "Прозрачный фон",
        bg_opacity = "Непрозрачность фона", reset_pos = "Сбросить позицию", refresh_stats = "Обновить статистику 5 игр",
        show_session = "Показывать сессию", elements = "Элементы", country = "Страна", colors = "Цвета",
        steam_name = "Ник Steam", mmr = "MMR", mmr_text = "MMR до ранга (текст)", mmr_icon = "MMR до ранга (иконка)",
        color = "Цвет", mmr_current = "Текущий MMR", mmr_needed = "Нужный MMR до след. ранга",
        glow = "Линия (glow)", stats_extra = "Доп. настройки статистики", roles = "Роли",
        dmg_num = "Урон (цифра)", dmg_icon = "Урон (иконка)", kda_num = "KDA (цифра)", kda_icon = "KDA (иконка)",
        nw_num = "Нетворс (цифра)", nw_icon = "Нетворс (иконка)", creep_num = "Крипы (цифра)", creep_icon = "Крипы (иконка)",
        icon1 = "Иконка 1 (dota/titan)", icon_mmr = "Иконка MMR", icon_mmr_file = "Иконка MMR (файл)", icon_rank = "Иконка ранга",
        bold = "Жирность", stats5 = "Статистика 5 игр", reset_default = "Сбросить настройки по умолчанию",
        match_id = "ID матча (из истории игр)", ready = "Готово", log5 = "Лог 5 матчей (отладка)",
        gc_verbose = "Детальный лог GC в консоль", debug_auto = "Отладка авто-статы", time_btn = "Время",
        session_wr = "Сессия WR: %.1f%% (%dW %dL)", open_history = "Открой историю матчей", mmr_empty = "—"
    },
    en = {
        enable_panel = "Enable panel", lock_pos = "Lock position", transparent = "Transparent background",
        bg_opacity = "Background opacity", reset_pos = "Reset position", refresh_stats = "Update 5 games stats",
        show_session = "Show session", elements = "Elements", country = "Country", colors = "Colors",
        steam_name = "Steam name", mmr = "MMR", mmr_text = "MMR to rank (text)", mmr_icon = "MMR to rank (icon)",
        color = "Color", mmr_current = "Current MMR", mmr_needed = "MMR needed for next rank",
        glow = "Lane (glow)", stats_extra = "Stats extra settings", roles = "Roles",
        dmg_num = "Damage (number)", dmg_icon = "Damage (icon)", kda_num = "KDA (number)", kda_icon = "KDA (icon)",
        nw_num = "Networth (number)", nw_icon = "Networth (icon)", creep_num = "Creeps (number)", creep_icon = "Creeps (icon)",
        icon1 = "Icon 1 (dota/titan)", icon_mmr = "MMR icon", icon_mmr_file = "MMR icon (file)", icon_rank = "Rank icon",
        bold = "Bold", stats5 = "Stats 5 games", reset_default = "Reset to default settings",
        match_id = "Match ID (from history)", ready = "Ready", log5 = "Log 5 matches (debug)",
        gc_verbose = "Verbose GC log to console", debug_auto = "Debug auto-stats", time_btn = "Time",
        session_wr = "Session WR: %.1f%% (%dW %dL)", open_history = "Open match history", mmr_empty = "—"
    }
}

local panel_lang = GetCheatLanguage()

local function L(key)
    local lang = GetCheatLanguage()
    local t = LOCALIZE[lang] or LOCALIZE.en
    return (t and t[key]) or (LOCALIZE.ru and LOCALIZE.ru[key]) or key
end

local function L_panel(key)
    local t = LOCALIZE[panel_lang] or LOCALIZE.en
    return (t and t[key]) or (LOCALIZE.ru and LOCALIZE.ru[key]) or key
end

local g_main = Menu.Create("Scripts", "Other", "Session Info", "Main", "Main")
g_main:Parent():Parent():Icon("\u{f080}")

local s_enable = g_main:Switch(L("enable_panel"), true)
local s_lock = g_main:Switch(L("lock_pos"), false)
local s_transparent = g_main:Switch(L("transparent"), true)
local s_trans_alpha = g_main:Slider(L("bg_opacity"), 0, 100, 60, "%d%%")
local s_x = g_main:Slider("Pos X", 0, 1920, 300, "%d")
local s_y = g_main:Slider("Pos Y", 0, 1080, 100, "%d")
s_x:Visible(false)
s_y:Visible(false)

local s_btn_reset_pos = g_main:Button(L("reset_pos"), function()
    local screen = Render.ScreenSize()
    local panelW, panelH = 320, 110
    s_x:Set(math.floor(screen.x / 2 - panelW / 2))
    s_y:Set(math.floor(screen.y / 2 - panelH / 2))
end)

local s_btn_refresh_stats = g_main:Button(L("refresh_stats"), function()
    cached.stats5 = nil
    cached.manual_stats_refresh = true
end)

local s_session_show = g_main:Switch(L("show_session"), true)

local g_display = Menu.Create("Scripts", "Other", "Session Info", "Main", "\u{f03e} Display")
local DISPLAY_ITEMS = {L_panel("steam_name"), L_panel("mmr"), L_panel("mmr_text"), L_panel("mmr_icon")}
local s_display_items = g_display:MultiCombo(L("elements"), DISPLAY_ITEMS, DISPLAY_ITEMS)
s_display_items:Icon("\u{f0c9}")
local s_display_gear = s_display_items:Gear("Settings")
local s_country = s_display_gear:Combo(L("country"), country_names, 0)

local s_colors_label = g_main:Label(L("colors"), "\u{f53f}")
local colors_gear = s_colors_label:Gear("Settings")
local COLOR_DEFAULTS = {
    steam_name = Color(150, 150, 150, 255),
    mmr = Color(255, 255, 255, 255),
    mmr_current = Color(255, 255, 255, 255),
    mmr_needed = Color(255, 255, 255, 255),
    stats = Color(255, 255, 255, 255),
    glow = Color(255, 240, 250, 220),
    icon = Color(255, 255, 255, 255),
    stats_kda = Color(244, 5, 5, 255),
    stats_nw = Color(232, 224, 19, 255),
    stats_creep = Color(61, 227, 37, 255),
    role_carry = Color(115, 125, 196, 255),
    role_mid = Color(63, 146, 138, 255),
    role_offlane = Color(247, 143, 20, 255),
    role_soft = Color(180, 58, 71, 255),
    role_hard = Color(66, 199, 154, 255)
}
local function addColorSetting(gear, name, default, defaultEnabled)
    defaultEnabled = (defaultEnabled == true)
    local sw = gear:Switch(name, defaultEnabled)
    local cp = sw:ColorPicker(L("color"), default)
    sw:SetCallback(function(w) cp:Visible(w:Get()) end, true)
    cp:Visible(defaultEnabled)
    return sw, cp
end
local s_color_steam_sw, s_color_steam = addColorSetting(colors_gear, L("steam_name"), COLOR_DEFAULTS.steam_name)
local s_color_mmr_sw, s_color_mmr = addColorSetting(colors_gear, L("mmr"), COLOR_DEFAULTS.mmr)
local s_color_mmr_current_sw, s_color_mmr_current = addColorSetting(colors_gear, L("mmr_current"), COLOR_DEFAULTS.mmr_current)
local s_color_mmr_needed_sw, s_color_mmr_needed = addColorSetting(colors_gear, L("mmr_needed"), COLOR_DEFAULTS.mmr_needed)
local s_color_glow_sw, s_color_glow = addColorSetting(colors_gear, L("glow"), COLOR_DEFAULTS.glow)
local s_stats_colors_label = colors_gear:Label(L("stats_extra"))
local stats_colors_gear = s_stats_colors_label:Gear("Settings")
local s_color_stats_dmg_text_sw, s_color_stats_dmg_text = addColorSetting(stats_colors_gear, L("dmg_num"), COLOR_DEFAULTS.stats)
local s_color_stats_dmg_icon_sw, s_color_stats_dmg_icon = addColorSetting(stats_colors_gear, L("dmg_icon"), COLOR_DEFAULTS.icon)
local s_color_stats_kda_text_sw, s_color_stats_kda_text = addColorSetting(stats_colors_gear, L("kda_num"), COLOR_DEFAULTS.stats_kda, true)
local s_color_stats_kda_icon_sw, s_color_stats_kda_icon = addColorSetting(stats_colors_gear, L("kda_icon"), COLOR_DEFAULTS.stats_kda, true)
local s_color_stats_nw_text_sw, s_color_stats_nw_text = addColorSetting(stats_colors_gear, L("nw_num"), COLOR_DEFAULTS.stats_nw, true)
local s_color_stats_nw_icon_sw, s_color_stats_nw_icon = addColorSetting(stats_colors_gear, L("nw_icon"), COLOR_DEFAULTS.stats_nw, true)
local s_color_stats_creep_text_sw, s_color_stats_creep_text = addColorSetting(stats_colors_gear, L("creep_num"), COLOR_DEFAULTS.stats_creep, true)
local s_color_stats_creep_icon_sw, s_color_stats_creep_icon = addColorSetting(stats_colors_gear, L("creep_icon"), COLOR_DEFAULTS.stats_creep, true)
local s_roles_colors_label = stats_colors_gear:Label(L("roles"))
local roles_colors_gear = s_roles_colors_label:Gear("Settings")
local s_color_stats_role_carry_sw, s_color_stats_role_carry = addColorSetting(roles_colors_gear, "Carry", COLOR_DEFAULTS.role_carry, true)
local s_color_stats_role_mid_sw, s_color_stats_role_mid = addColorSetting(roles_colors_gear, "Mid", COLOR_DEFAULTS.role_mid, true)
local s_color_stats_role_offlane_sw, s_color_stats_role_offlane = addColorSetting(roles_colors_gear, "Offlane", COLOR_DEFAULTS.role_offlane, true)
local s_color_stats_role_soft_sw, s_color_stats_role_soft = addColorSetting(roles_colors_gear, "Soft Support", COLOR_DEFAULTS.role_soft, true)
local s_color_stats_role_hard_sw, s_color_stats_role_hard = addColorSetting(roles_colors_gear, "Hard Support", COLOR_DEFAULTS.role_hard, true)
local s_color_icon1_sw, s_color_icon1 = addColorSetting(colors_gear, L("icon1"), COLOR_DEFAULTS.icon)
local s_color_icon2_sw, s_color_icon2 = addColorSetting(colors_gear, L("icon_mmr"), COLOR_DEFAULTS.icon)
local s_color_rank_icon_sw, s_color_rank_icon = addColorSetting(colors_gear, L("icon_rank"), COLOR_DEFAULTS.icon)

local s_bold_label = g_main:Label(L("bold"), "\u{f032}")
local bold_gear = s_bold_label:Gear("Settings")
local BOLD_DEFAULTS = { steam_name = false, mmr = true, stats = true, mmr_current = false, mmr_needed = false }
local s_bold_steam = bold_gear:Switch(L("steam_name"), BOLD_DEFAULTS.steam_name)
local s_bold_mmr = bold_gear:Switch(L("mmr"), BOLD_DEFAULTS.mmr)
local s_bold_stats = bold_gear:Switch(L("stats5"), BOLD_DEFAULTS.stats)
local s_bold_mmr_current = bold_gear:Switch(L("mmr_current"), BOLD_DEFAULTS.mmr_current)
local s_bold_mmr_needed = bold_gear:Switch(L("mmr_needed"), BOLD_DEFAULTS.mmr_needed)

local s_reset_colors_btn = g_main:Button(L("reset_default"), function()
    cached.reset_colors = true
end)

local g_gc = Menu.Create("Scripts", "Other", "Session Info", "Settings", "GC Match")
local s_match_id = g_gc:Input(L("match_id"), "")
local s_gc_trigger = g_gc:Switch(L("ready"), false)
local s_gc_debug_log = g_gc:Switch(L("log5"), false)
local s_gc_verbose_log = g_gc:Switch(L("gc_verbose"), false)
local s_debug_auto = g_gc:Switch(L("debug_auto"), false)
local s_btn_time = g_gc:Button(L("time_btn"), function()
    local oc = os.clock()
    local ot = os.time()
    Log.Write("[SessionInfo] os.clock()=" .. tostring(oc) .. " os.time()=" .. tostring(ot))
    local sec = math.floor(oc)
    local h = math.floor(sec / 3600)
    local m = math.floor((sec % 3600) / 60)
    local s = sec % 60
    Log.Write("[SessionInfo] os.clock: " .. string.format("%d:%02d:%02d", h, m, s))
    Log.Write("[SessionInfo] os.time: " .. tostring(os.date("%H:%M:%S %d.%m.%Y", ot)))
    local path = GetSessionFilePath()
    if path then
        local f = io.open(path, "r")
        if f then
            local lines = {}
            for i = 1, 6 do lines[i] = f:read("*l") or "" end
            f:close()
            local v6 = tonumber(lines[6]) or 0
            local dotaLaunch = GetDotaLaunchTime()
            local diff = v6 > 1000000000 and math.abs(dotaLaunch - v6) or "n/a"
            local ok = v6 > 1000000000 and (type(diff) == "number" and diff <= SESSION_LAUNCH_TOLERANCE) or (v6 <= 1000000000 and "legacy")
            Log.Write("[SessionInfo] file v6(dota_launch)=" .. tostring(v6) .. " current_launch=" .. tostring(dotaLaunch) .. " diff=" .. tostring(diff) .. " TOLERANCE=" .. tostring(SESSION_LAUNCH_TOLERANCE) .. " session_ok=" .. tostring(ok))
        else
            Log.Write("[SessionInfo] session file not found")
        end
    end
end)

local function GcLog(msg)
    if s_gc_verbose_log and s_gc_verbose_log:Get() then
        Log.Write("[SessionInfo GC] " .. tostring(msg))
    end
end

local STEAMID64_OFFSET = 76561197960265728

local function TryGetMMRRank(mmr)
    if not mmr or mmr <= 0 then return 0 end
    local ok, rt = pcall(function()
        if XHelpers and XHelpers.xutil and XHelpers.xutil.GetMMRRank then
            return XHelpers.xutil:GetMMRRank(mmr)
        end
        return nil
    end)
    if ok and rt ~= nil then return rt end
    if mmr >= 5620 then return 80
    elseif mmr >= 5420 then return 75
    elseif mmr >= 5220 then return 74
    elseif mmr >= 5020 then return 73
    elseif mmr >= 4820 then return 72
    elseif mmr >= 4620 then return 71
    elseif mmr >= 4466 then return 65
    elseif mmr >= 4312 then return 64
    elseif mmr >= 4158 then return 63
    elseif mmr >= 4004 then return 62
    elseif mmr >= 3850 then return 61
    elseif mmr >= 3696 then return 55
    elseif mmr >= 3542 then return 54
    elseif mmr >= 3388 then return 53
    elseif mmr >= 3234 then return 52
    elseif mmr >= 3080 then return 51
    elseif mmr >= 2926 then return 45
    elseif mmr >= 2772 then return 44
    elseif mmr >= 2618 then return 43
    elseif mmr >= 2464 then return 42
    elseif mmr >= 2310 then return 41
    elseif mmr >= 2156 then return 35
    elseif mmr >= 2002 then return 34
    elseif mmr >= 1848 then return 33
    elseif mmr >= 1694 then return 32
    elseif mmr >= 1540 then return 31
    elseif mmr >= 1386 then return 25
    elseif mmr >= 1232 then return 24
    elseif mmr >= 1078 then return 23
    elseif mmr >= 924 then return 22
    elseif mmr >= 770 then return 21
    elseif mmr >= 616 then return 15
    elseif mmr >= 462 then return 14
    elseif mmr >= 308 then return 13
    elseif mmr >= 154 then return 12
    elseif mmr > 0 then return 11
    end
    return 0
end

local function Dbg(msg)
    if s_debug_auto and s_debug_auto:Get() then
        Log.Write("[SessionInfo DBG] " .. tostring(msg))
    end
end

local RANK_TABLE = {
    { 154, "Herald", 2 }, { 308, "Herald", 3 }, { 462, "Herald", 4 }, { 616, "Herald", 5 },
    { 770, "Guardian", 1 }, { 924, "Guardian", 2 }, { 1078, "Guardian", 3 }, { 1232, "Guardian", 4 }, { 1386, "Guardian", 5 },
    { 1540, "Crusader", 1 }, { 1694, "Crusader", 2 }, { 1848, "Crusader", 3 }, { 2002, "Crusader", 4 }, { 2156, "Crusader", 5 },
    { 2310, "Archon", 1 }, { 2464, "Archon", 2 }, { 2618, "Archon", 3 }, { 2772, "Archon", 4 }, { 2926, "Archon", 5 },
    { 3080, "Legend", 1 }, { 3234, "Legend", 2 }, { 3388, "Legend", 3 }, { 3542, "Legend", 4 }, { 3696, "Legend", 5 },
    { 3850, "Ancient", 1 }, { 4004, "Ancient", 2 }, { 4158, "Ancient", 3 }, { 4312, "Ancient", 4 }, { 4466, "Ancient", 5 },
    { 4620, "Divine", 1 }, { 4820, "Divine", 2 }, { 5020, "Divine", 3 }, { 5220, "Divine", 4 }, { 5420, "Divine", 5 },
    { 5600, "Immortal", 0 }
}

local function GetRankInfo(mmr)
    if mmr == 0 then return nil, nil end
    local current = { mmr = 0, name = "Herald", tier = 1 }
    local nextRank = nil
    for i, data in ipairs(RANK_TABLE) do
        if mmr < data[1] then
            nextRank = { mmr = data[1], name = data[2], tier = data[3] }
            if i > 1 then
                local prev = RANK_TABLE[i - 1]
                current = { mmr = prev[1], name = prev[2], tier = prev[3] }
            end
            break
        end
    end
    if not nextRank and #RANK_TABLE > 0 then
        local last = RANK_TABLE[#RANK_TABLE]
        current = { mmr = last[1], name = last[2], tier = last[3] }
    end
    return current, nextRank
end

local function GetRankIconHandle(rank_tier_id)
    if not rank_tier_id or rank_tier_id < 1 then return 0 end
    local icon_id = math.floor(rank_tier_id / 10)
    if icon_id < 1 or icon_id > 8 then return 0 end
    cached.rank_icons = cached.rank_icons or {}
    if cached.rank_icons[icon_id] then
        return cached.rank_icons[icon_id]
    end
    local path = "panorama/images/rank_tier_icons/rank" .. tostring(icon_id) .. "_psd.vtex_c"
    cached.rank_icons[icon_id] = Render.LoadImage(path) or 0
    return cached.rank_icons[icon_id]
end

local ROLE_NAMES = { [1] = "Carry", [2] = "Mid", [3] = "Offlane", [4] = "Soft Supp", [5] = "Full Supp" }
local ROLE_ICON_PATHS = {
    [1] = "panorama/images/rank_tier_icons/handicap/safelaneicon_psd.vtex_c",
    [2] = "panorama/images/rank_tier_icons/handicap/midlaneicon_psd.vtex_c",
    [3] = "panorama/images/rank_tier_icons/handicap/offlaneicon_psd.vtex_c",
    [4] = "panorama/images/rank_tier_icons/handicap/softsupporticon_psd.vtex_c",
    [5] = "panorama/images/rank_tier_icons/handicap/hardsupporticon_psd.vtex_c"
}

local session_load_attempted = false

local stats5_state = {
    loading = false,
    pending = 0,
    collected = {},
    match_ids = {},
    last_fetch_frame = 0,
    debug_log = false,
    need_refresh_after_match = false,
    refresh_at = 0,
    loading_start = 0,
    retry_gc_at = 0,
    retry_count = 0,
    dashboard_first_seen = 0
}

local function GetAccountId()
    local sid = GC.GetSteamID()
    if not sid or sid == "" then return nil end
    local ok, accId = pcall(function()
        if XHelpers and XHelpers.xutil and XHelpers.xutil.SteamID64ToAccountID then
            return XHelpers.xutil:SteamID64ToAccountID(sid)
        end
        return nil
    end)
    if ok and accId and accId > 0 then return accId end
    local s64 = tonumber(sid)
    if not s64 then return nil end
    return math.floor(s64 - STEAMID64_OFFSET)
end

local function SendMatchDetailsRequest(mid)
    local pb = require("protobuf")
    local JSON = require("assets.JSON")
    local req = pb.encodeFromJSON("CMsgGCMatchDetailsRequest", JSON:encode({ match_id = mid }))
    local buf = req and (req.binary or req.binary_buffer)
    if buf and req.size then
        GC.SendMessage(buf, 7095, req.size)
        GcLog("SEND 7095 CMsgGCMatchDetailsRequest mid=" .. tostring(mid) .. " size=" .. tostring(req.size))
        return true
    end
    GcLog("SEND 7095 FAILED encode mid=" .. tostring(mid))
    return false
end

local function FindMyPlayer(players)
    local myAcc = GetAccountId()
    local myName = Steam.GetPersonaName() or ""
    for _, p in ipairs(players) do
        local pid = tonumber(p.account_id) or p.account_id or 0
        local pname = (p.player_name or ""):gsub("^%s*(.-)%s*$", "%1")
        if myAcc and pid == myAcc then return p end
        if myName ~= "" and pname == myName then return p end
    end
    return nil
end

local SLOT_TO_ROLE = { [0] = 4, [1] = 5, [2] = 3, [3] = 2, [4] = 1 }
local LANE_FLAGS_TO_ROLE = { [1] = 1, [2] = 3, [4] = 2, [8] = 4, [16] = 5 }

local MMR_TYPE_RANKED_SOLO = 2
local MMR_TYPE_RANKED_PARTY = 3

local function ProcessStats5Player(p, matchId, matchStartTime)
    local slot = tonumber(p.player_slot) or 0
    local flags = tonumber(p.lane_selection_flags) or 0
    local mmrType = tonumber(p.mmr_type) or 0
    local ranked = (mmrType == MMR_TYPE_RANKED_SOLO or mmrType == MMR_TYPE_RANKED_PARTY)
    local roleId = LANE_FLAGS_TO_ROLE[flags]
    if not roleId then
        roleId = SLOT_TO_ROLE[slot % 8] or 1
    end
    if roleId < 1 or roleId > 5 then roleId = 1 end
    local rankChange = tonumber(p.rank_change) or tonumber(p.pro_change) or 0
    local s = {
        damage = tonumber(p.hero_damage) or 0,
        kills = tonumber(p.kills) or 0,
        deaths = tonumber(p.deaths) or 0,
        networth = tonumber(p.net_worth) or tonumber(p.gold_spent) or 0,
        last_hits = tonumber(p.last_hits) or 0,
        denies = tonumber(p.denies) or 0,
        roleId = roleId,
        ranked = ranked,
        player_name = p.player_name or "",
        rank_change = rankChange,
        start_time = matchStartTime or 0
    }
    if matchId then s.match_id = matchId end
    s.player_slot = slot
    return s
end

local function LogMatchTime(mid, startTime, durationSec)
    if not s_gc_verbose_log or not s_gc_verbose_log:Get() then return end
    local startStr = startTime and startTime > 0 and os.date("%H:%M:%S %d.%m.%Y", startTime) or "?"
    local durStr = durationSec and durationSec > 0 and (math.floor(durationSec / 60) .. "m " .. (durationSec % 60) .. "s") or "?"
    Log.Write("[SessionInfo] match " .. tostring(mid) .. " start=" .. startStr .. " duration=" .. durStr)
end

local function FinishStats5()
    local c = stats5_state.collected
    if #c == 0 then
        cached.stats5 = { count = 0, damage = 0, kills = 0, deaths = 0, networth = 0, last_hits = 0, denies = 0, roles = {}, ranked_count = 0 }
        cached.last5_wl = {}
        stats5_state.loading = false
        stats5_state.last_fetch_frame = 0
        if stats5_state.debug_log then
            stats5_state.debug_log = false
        end
        return
    end
    if stats5_state.debug_log then
        stats5_state.debug_log = false
    end
    table.sort(c, function(a, b)
        local ma = tonumber(a.match_id) or 0
        local mb = tonumber(b.match_id) or 0
        return ma > mb
    end)
    local first5 = {}
    for i = 1, math.min(5, #c) do
        first5[#first5 + 1] = c[i]
    end
    local agg = { damage = 0, kills = 0, deaths = 0, networth = 0, last_hits = 0, denies = 0, roles = {}, count = #first5, ranked_count = 0 }
    for _, s in ipairs(first5) do
        agg.damage = agg.damage + s.damage
        agg.kills = agg.kills + s.kills
        agg.deaths = agg.deaths + s.deaths
        agg.networth = agg.networth + s.networth
        agg.last_hits = agg.last_hits + s.last_hits
        agg.denies = agg.denies + s.denies
        if s.ranked then
            agg.ranked_count = agg.ranked_count + 1
            agg.roles[s.roleId] = (agg.roles[s.roleId] or 0) + 1
        end
    end
    cached.stats5 = agg
    local last5Wl = {}
    for i = 1, math.min(5, #first5) do
        local s = first5[i]
        if s.ranked then
            local rc = s.rank_change or 0
            if rc > 0 then last5Wl[#last5Wl + 1] = "W"
            elseif rc < 0 then last5Wl[#last5Wl + 1] = "L"
            end
        end
    end
    cached.last5_wl = last5Wl

    local dotaLaunch = GetDotaLaunchTime()
    local sessionWins, sessionLosses, sessionMmrDelta = 0, 0, 0
    for _, s in ipairs(c) do
        if s.ranked and (s.start_time or 0) >= dotaLaunch then
            local rc = s.rank_change or 0
            if rc > 0 then sessionWins = sessionWins + 1
            elseif rc < 0 then sessionLosses = sessionLosses + 1 end
            sessionMmrDelta = sessionMmrDelta + rc
        end
    end
    if sessionWins + sessionLosses > 0 then
        session.start_clock = os.clock()
        session.start_time = dotaLaunch
        session.start_mmr = (cached.mmr or Engine.GetMMRV2() or 0) - sessionMmrDelta
        session.wins = sessionWins
        session.losses = sessionLosses
        session.initialized = true
        GcLog("session from dota_launch=" .. tostring(os.date("%H:%M:%S %d.%m.%Y", dotaLaunch)) .. " matches=" .. (sessionWins + sessionLosses) .. " W=" .. sessionWins .. " L=" .. sessionLosses)
        SaveSession()
    end
    stats5_state.last_fetch_frame = 0
    stats5_state.loading = false
    local ids = {}
    for i = 1, #first5 do ids[i] = tostring(first5[i].match_id or "?") end
    GcLog("FinishStats5 OK count=" .. tostring(#first5) .. " ids=" .. table.concat(ids, ","))
end

local function SendMatchHistoryRequest()
    local accId = GetAccountId()
    if not accId then return false end
    local pb = require("protobuf")
    local JSON = require("assets.JSON")
    local req = pb.encodeFromJSON("CMsgDOTAGetPlayerMatchHistory", JSON:encode({
        account_id = accId,
        matches_requested = 5
    }))
    local buf = req and (req.binary or req.binary_buffer)
    if buf and req.size then
        GC.SendMessage(buf, 7408, req.size)
        GcLog("SEND 7408 CMsgDOTAGetPlayerMatchHistory account_id=" .. tostring(accId) .. " size=" .. tostring(req.size))
        return true
    end
    GcLog("SEND 7408 FAILED encode")
    return false
end

local function SendGetProfileCard()
    local accId = GetAccountId()
    if not accId then Dbg("SendGetProfileCard: no account_id") return end
    local pb = require("protobuf")
    local JSON = require("assets.JSON")
    for _, name in ipairs({"CMsgClientToGCGetProfileCard", "CMsgGCCClientGetProfileCard"}) do
        local ok, req = pcall(function()
            return pb.encodeFromJSON(name, JSON:encode({ account_id = accId }))
        end)
        if ok and req and (req.binary or req.binary_buffer) and req.size then
            GC.SendMessage(req.binary or req.binary_buffer, 7534, req.size)
            break
        end
    end
end

local function FetchStats5GC()
    local accId = GetAccountId()
    if not accId then GcLog("FetchStats5GC: no account_id") return false end
    if stats5_state.loading then GcLog("FetchStats5GC: skip loading=true") return false end
    GcLog("FetchStats5GC: start account_id=" .. tostring(accId))
    stats5_state.loading = true
    stats5_state.loading_start = os.clock()
    stats5_state.pending = 0
    stats5_state.collected = {}
    stats5_state.match_ids = {}
    SendGetProfileCard()
    if SendMatchHistoryRequest() then
        return true
    end
    stats5_state.loading = false
    return false
end

local function FetchStats5FromSignedOut()
    if stats5_state.loading then GcLog("FetchStats5FromSignedOut: skip loading") return false end
    local ids = LoadSignedOutMatchIds()
    GcLog("FetchStats5FromSignedOut: ids_count=" .. tostring(#ids) .. (#ids > 0 and (" first=" .. tostring(ids[1])) or ""))
    if #ids == 0 then return false end
    stats5_state.loading = true
    stats5_state.loading_start = os.clock()
    stats5_state.pending = math.min(25, #ids)
    stats5_state.collected = {}
    stats5_state.match_ids = {}
    stats5_state.match_start_times = {}
    for i = 1, math.min(25, #ids) do
        SendMatchDetailsRequest(ids[i])
    end
    if stats5_state.pending == 0 then
        FinishStats5()
    end
    return true
end

function SessionInfo.OnGCMessage(msg)
    if not msg then return true end
    local mt = msg.msg_type or msg.message_type
    local buf = msg.binary_buffer_recv or msg.buffer
    local size = msg.size or 0

    if mt == 7409 and buf and size > 0 then
        GcLog("RECV 7409 CMsgDOTAGetPlayerMatchHistoryResponse size=" .. tostring(size))
        local pb = require("protobuf")
        local JSON = require("assets.JSON")
        local ok, jsonStr = pcall(function() return pb.decodeToJSON("CMsgDOTAGetPlayerMatchHistoryResponse", buf, size) end)
        if ok and jsonStr then
            local ok2, data = pcall(JSON.decode, JSON, jsonStr)
            GcLog("7409 decode ok=" .. tostring(ok) .. " json_ok=" .. tostring(ok2) .. " has_matches=" .. (data and data.matches and #data.matches or 0))
            if ok2 and data and data.matches and #data.matches > 0 then
                local toFetch = math.min(25, #data.matches)
                if not stats5_state.loading then
                    stats5_state.loading = true
                    stats5_state.loading_start = os.clock()
                    stats5_state.collected = {}
                    stats5_state.match_ids = {}
                end
                stats5_state.pending = toFetch
                stats5_state.match_start_times = {}
                for i = 1, toFetch do
                    local m = data.matches[i]
                    local mid = tonumber(m.match_id) or m.match_id
                    if mid and mid > 0 then
                        SaveSignedOutMatchId(mid)
                        stats5_state.match_ids[#stats5_state.match_ids + 1] = mid
                        local st = tonumber(m.start_time) or m.start_time or 0
                        stats5_state.match_start_times[mid] = st
                        SendMatchDetailsRequest(mid)
                    else
                        GcLog("7409 skip invalid mid i=" .. tostring(i) .. " mid=" .. tostring(mid))
                        stats5_state.pending = stats5_state.pending - 1
                    end
                end
                if stats5_state.pending == 0 then
                    FinishStats5()
                end
                stats5_state.retry_gc_at = 0
                stats5_state.retry_count = 0
                local ids = {}
                for i = 1, math.min(5, #data.matches) do
                    local mid = tonumber(data.matches[i].match_id) or data.matches[i].match_id
                    ids[i] = tostring(mid or "?")
                end
                GcLog("7409 OK matches=" .. #data.matches .. " ids=" .. table.concat(ids, ","))
            else
                GcLog("7409 EMPTY or NO MATCHES data=" .. (data and "table" or "nil") .. " matches_cnt=" .. (data and data.matches and #data.matches or "nil") .. " json_preview=" .. (type(jsonStr) == "string" and jsonStr:sub(1, 200) or ""))
                if stats5_state.loading then
                    stats5_state.loading = false
                end
                if FetchStats5FromSignedOut() then
                    stats5_state.retry_gc_at = 0
                    stats5_state.retry_count = 0
                else
                    local hasValidData = cached.stats5 and cached.stats5.count and cached.stats5.count > 0
                    if not hasValidData then
                        stats5_state.retry_count = (stats5_state.retry_count or 0) + 1
                        if stats5_state.retry_count < 1 then
                            stats5_state.retry_gc_at = os.clock() + 8
                        else
                            cached.stats5 = { count = 0, damage = 0, kills = 0, deaths = 0, networth = 0, last_hits = 0, denies = 0, roles = {}, ranked_count = 0 }
                            cached.last5_wl = {}
                            stats5_state.retry_count = 0
                        end
                    else
                        stats5_state.retry_gc_at = 0
                        stats5_state.retry_count = 0
                    end
                    stats5_state.last_fetch_frame = 1
                end
            end
        else
            GcLog("7409 PROTOBUF DECODE FAILED ok=" .. tostring(ok))
            stats5_state.loading = false
            if FetchStats5FromSignedOut() then
                stats5_state.retry_gc_at = 0
                stats5_state.retry_count = 0
            else
                local hasValidData = cached.stats5 and cached.stats5.count and cached.stats5.count > 0
                if not hasValidData then
                    stats5_state.retry_count = (stats5_state.retry_count or 0) + 1
                    if stats5_state.retry_count < 3 then
                        stats5_state.retry_gc_at = os.clock() + 5
                    else
                        stats5_state.retry_count = 0
                    end
                else
                    stats5_state.retry_gc_at = 0
                    stats5_state.retry_count = 0
                end
                stats5_state.last_fetch_frame = 1
            end
        end
        return true
    end

    if (mt == 8081 or mt == 7005) and buf and size > 0 then
        GcLog("RECV " .. tostring(mt) .. " size=" .. tostring(size))
        local pb = require("protobuf")
        local JSON = require("assets.JSON")
        local typeName = (mt == 8081) and "CMsgGCToClientMatchSignedOut" or "CMsgGameMatchSignoutResponse"
        local ok, jsonStr = pcall(function() return pb.decodeToJSON(typeName, buf, size) end)
        if ok and jsonStr and jsonStr ~= "" then
            local ok2, data = pcall(JSON.decode, JSON, jsonStr)
            if not ok2 or not data then GcLog(tostring(mt) .. " JSON decode FAIL") end
            if ok2 and data then
                local mid = tonumber(data.match_id) or data.match_id or data.matchid
                if not mid and data.match_details then
                    local md = data.match_details
                    mid = tonumber(md.match_id) or md.match_id or md.matchid
                    midSource = "match_details.match_id"
                end
                if not mid and data.match then
                    local m = data.match
                    mid = tonumber(m.match_id) or m.match_id or tonumber(m.matchid) or m.matchid
                    midSource = "match.match_id"
                end
                if not mid or mid <= 0 then
                    GcLog(tostring(mt) .. " skip invalid mid=" .. tostring(mid))
                elseif mid and mid > 0 then
                    local hasDetails = data.match_details ~= nil
                    local hasPlayers = hasDetails and data.match_details.players and #data.match_details.players > 0
                    GcLog(tostring(mt) .. " match_id=" .. tostring(mid) .. " has_match_details=" .. tostring(hasDetails) .. " has_players=" .. tostring(hasPlayers))
                    SaveSignedOutMatchId(mid)
                    if mt == 7005 and data.match_details and data.match_details.players then
                        local p = FindMyPlayer(data.match_details.players)
                        GcLog("7005 FindMyPlayer " .. (p and "OK" or "FAIL") .. " mid=" .. tostring(mid))
                        if p then
                            local m = data.match_details
                            local startTime = m and (tonumber(m.start_time) or m.start_time or tonumber(m.starttime) or m.starttime)
                            if type(stats5_state.collected) ~= "table" then stats5_state.collected = {} end
                            local alreadyHas = false
                            for _, s in ipairs(stats5_state.collected) do
                                if (s.match_id or 0) == mid then alreadyHas = true break end
                            end
                            if not alreadyHas then
                                local duration = m and (tonumber(m.duration) or m.duration)
                                LogMatchTime(mid, startTime or 0, duration)
                                stats5_state.collected[#stats5_state.collected + 1] = ProcessStats5Player(p, mid, startTime or 0)
                                stats5_state.need_refresh_after_match = false
                                stats5_state.refresh_at = 0
                                FinishStats5()
                            end
                        else
                            GcLog("7005 FindMyPlayer FAIL sending 7095 for mid=" .. tostring(mid))
                            SendMatchDetailsRequest(tostring(mid))
                        end
                    else
                        GcLog(tostring(mt) .. " no_players sending 7095 mid=" .. tostring(mid))
                        SendMatchDetailsRequest(tostring(mid))
                    end
                    if not stats5_state.loading and not (mt == 8081 and not hasPlayers) then
                        GcLog(tostring(mt) .. " try FetchStats5FromSignedOut first")
                        if not FetchStats5FromSignedOut() then
                            GcLog(tostring(mt) .. " FetchStats5FromSignedOut=false fallback FetchStats5GC")
                            cached.stats5 = nil
                            cached.last5_wl = nil
                            stats5_state.last_fetch_frame = 0
                            FetchStats5GC()
                        else
                            GcLog(tostring(mt) .. " FetchStats5FromSignedOut OK")
                        end
                    end
                end
            end
        end
        return true
    end

    if mt == 7096 and buf and size > 0 then
        GcLog("RECV 7096 CMsgGCMatchDetailsResponse size=" .. tostring(size) .. " loading=" .. tostring(stats5_state.loading) .. " pending=" .. tostring(stats5_state.pending or 0))
        local pb = require("protobuf")
        local JSON = require("assets.JSON")
        local ok, jsonStr = pcall(function() return pb.decodeToJSON("CMsgGCMatchDetailsResponse", buf, size) end)
        if not ok or not jsonStr then
            GcLog("7096 PROTOBUF DECODE FAIL ok=" .. tostring(ok))
        elseif true then
            local ok2, data = pcall(JSON.decode, JSON, jsonStr)
            if not ok2 or not data then GcLog("7096 JSON decode FAIL") end
            if ok2 and data and data.match and data.match.players then
                local p = FindMyPlayer(data.match.players)
                local mid = data.match and (tonumber(data.match.match_id) or data.match.match_id or data.match.matchid) or nil
                GcLog("7096 FindMyPlayer " .. (p and "OK" or "FAIL") .. " mid=" .. tostring(mid))
                if p then
                    local m = data.match
                    local mid = m and (tonumber(m.match_id) or m.match_id or tonumber(m.matchid) or m.matchid)
                    if mid and mid > 0 then
                        SaveSignedOutMatchId(mid)
                    end
                    if stats5_state.loading and stats5_state.pending > 0 then
                        local startTime = m and (tonumber(m.start_time) or m.start_time or tonumber(m.starttime) or m.starttime)
                        if not startTime and mid and stats5_state.match_start_times then
                            startTime = stats5_state.match_start_times[mid]
                        end
                        local duration = m and (tonumber(m.duration) or m.duration)
                        LogMatchTime(mid, startTime or 0, duration)
                        stats5_state.collected[#stats5_state.collected + 1] = ProcessStats5Player(p, mid, startTime or 0)
                        stats5_state.pending = stats5_state.pending - 1
                        if stats5_state.pending == 0 then
                            FinishStats5()
                        end
                        return true
                    end
                    local startTime = m and (tonumber(m.start_time) or m.start_time or tonumber(m.starttime) or m.starttime)
                    if type(stats5_state.collected) ~= "table" then stats5_state.collected = {} end
                    local alreadyHas = false
                    for _, s in ipairs(stats5_state.collected) do
                        if (s.match_id or 0) == mid then alreadyHas = true break end
                    end
                    if not alreadyHas then
                        local duration = m and (tonumber(m.duration) or m.duration)
                        LogMatchTime(mid, startTime or 0, duration)
                        GcLog("7096 manual path mid=" .. tostring(mid) .. " FinishStats5")
                        stats5_state.collected[#stats5_state.collected + 1] = ProcessStats5Player(p, mid, startTime or 0)
                        stats5_state.need_refresh_after_match = false
                        stats5_state.refresh_at = 0
                        FinishStats5()
                    end
                    return true
                end
                GcLog("7096 FindMyPlayer FAIL mid=" .. tostring(mid))
                if stats5_state.loading then
                    stats5_state.pending = stats5_state.pending - 1
                    if stats5_state.pending == 0 then
                        FinishStats5()
                    end
                end
            else
                GcLog("7096 NO match or players ok2=" .. tostring(ok2) .. " has_match=" .. (data and data.match and "Y" or "N") .. " has_players=" .. (data and data.match and data.match.players and "Y" or "N"))
            end
        end
        return true
    end
    return true
end

local function RequestMatchDetails(matchIdStr)
    local mid = tonumber(matchIdStr)
    if not mid or mid <= 0 then return end
    SendMatchDetailsRequest(mid)
end

local ICON1_OPTIONS = {"dota", "titan"}
local ICON1_FILES = { dota = "icon1.png", titan = "UmbIcon.png" }
local s_icon1 = g_main:Combo(L("icon1"), ICON1_OPTIONS, 0)
local s_icon2_path = g_main:Input(L("icon_mmr_file"), "stats_up.png")

local menu_translate = {
    {s_enable, "enable_panel"}, {s_lock, "lock_pos"}, {s_transparent, "transparent"}, {s_trans_alpha, "bg_opacity"},
    {s_btn_reset_pos, "reset_pos"}, {s_btn_refresh_stats, "refresh_stats"}, {s_session_show, "show_session"},
    {s_display_items, "elements"}, {s_country, "country"}, {s_colors_label, "colors"},
    {s_color_steam_sw, "steam_name"}, {s_color_mmr_sw, "mmr"}, {s_color_mmr_current_sw, "mmr_current"},
    {s_color_mmr_needed_sw, "mmr_needed"}, {s_color_glow_sw, "glow"}, {s_stats_colors_label, "stats_extra"},
    {s_color_stats_dmg_text_sw, "dmg_num"}, {s_color_stats_dmg_icon_sw, "dmg_icon"},
    {s_color_stats_kda_text_sw, "kda_num"}, {s_color_stats_kda_icon_sw, "kda_icon"},
    {s_color_stats_nw_text_sw, "nw_num"}, {s_color_stats_nw_icon_sw, "nw_icon"},
    {s_color_stats_creep_text_sw, "creep_num"}, {s_color_stats_creep_icon_sw, "creep_icon"},
    {s_roles_colors_label, "roles"}, {s_color_icon1_sw, "icon1"}, {s_color_icon2_sw, "icon_mmr"},
    {s_color_rank_icon_sw, "icon_rank"}, {s_bold_label, "bold"}, {s_bold_steam, "steam_name"},
    {s_bold_mmr, "mmr"}, {s_bold_stats, "stats5"}, {s_bold_mmr_current, "mmr_current"},
    {s_bold_mmr_needed, "mmr_needed"}, {s_reset_colors_btn, "reset_default"},
    {s_match_id, "match_id"}, {s_gc_trigger, "ready"}, {s_gc_debug_log, "log5"},
    {s_gc_verbose_log, "gc_verbose"}, {s_debug_auto, "debug_auto"}, {s_btn_time, "time_btn"},
    {s_icon1, "icon1"}, {s_icon2_path, "icon_mmr_file"}
}
local last_menu_lang = nil
local function UpdateMenuLanguage()
    local lang = GetCheatLanguage()
    if last_menu_lang == lang then return end
    last_menu_lang = lang
    local t = LOCALIZE[lang] or LOCALIZE.en
    for _, entry in ipairs(menu_translate) do
        local w, key = entry[1], entry[2]
        if w and w.ForceLocalization then
            local text = (t and t[key]) or (LOCALIZE.ru and LOCALIZE.ru[key]) or key
            pcall(function() w:ForceLocalization(text) end)
        end
    end
end

local function UpdateDisplayItemStates()
    if not s_enable:Get() then return end
    local steamOn = s_display_items:Get(L_panel("steam_name"))
    local mmrOn = s_display_items:Get(L_panel("mmr"))
    local mmrTextOn = s_display_items:Get(L_panel("mmr_text"))
    local mmrIconOn = s_display_items:Get(L_panel("mmr_icon"))
    s_color_steam_sw:Disabled(not steamOn)
    s_bold_steam:Disabled(not steamOn)
    s_color_mmr_sw:Disabled(not mmrOn)
    s_bold_mmr:Disabled(not mmrOn)
    s_color_icon2_sw:Disabled(not mmrOn)
    s_color_mmr_current_sw:Disabled(not mmrTextOn)
    s_color_mmr_needed_sw:Disabled(not mmrTextOn)
    s_bold_mmr_current:Disabled(not mmrTextOn)
    s_bold_mmr_needed:Disabled(not mmrTextOn)
    s_color_rank_icon_sw:Disabled(not mmrIconOn)
end

s_enable:SetCallback(function(w)
    local enabled = w:Get()
    s_lock:Disabled(not enabled)
    s_transparent:Disabled(not enabled)
    s_trans_alpha:Disabled(not enabled)
    s_btn_reset_pos:Disabled(not enabled)
    s_btn_refresh_stats:Disabled(not enabled)
    s_session_show:Disabled(not enabled)
    s_icon1:Disabled(not enabled)
    s_icon2_path:Disabled(not enabled)
    s_display_items:Disabled(not enabled)
    s_display_gear:Visible(enabled)
    s_colors_label:Disabled(not enabled)
    colors_gear:Visible(enabled)
    s_bold_label:Disabled(not enabled)
    bold_gear:Visible(enabled)
    s_reset_colors_btn:Disabled(not enabled)
    g_display:Disabled(not enabled)
    g_gc:Disabled(not enabled)
    if enabled then UpdateDisplayItemStates() end
end, true)

s_display_items:SetCallback(function()
    UpdateDisplayItemStates()
end, true)

local theme = {
    bg = Color(20, 20, 20, 255),
    text = Color(255, 255, 255, 255),
    steam_name = Color(150, 150, 150, 255),
    glow = Color(255, 235, 245, 220),
    glowSoft = Color(255, 220, 235, 100)
}

local function ToColor(c)
    if not c then return nil end
    if type(c) == "table" and c.r ~= nil then
        return Color(c.r, c.g or 255, c.b or 255, c.a or 255)
    end
    return c
end

local function GetDisplayColor(key)
    local items = {
        steam_name = { sw = s_color_steam_sw, cp = s_color_steam, def = COLOR_DEFAULTS.steam_name },
        mmr = { sw = s_color_mmr_sw, cp = s_color_mmr, def = COLOR_DEFAULTS.mmr },
        mmr_current = { sw = s_color_mmr_current_sw, cp = s_color_mmr_current, def = COLOR_DEFAULTS.mmr_current },
        mmr_needed = { sw = s_color_mmr_needed_sw, cp = s_color_mmr_needed, def = COLOR_DEFAULTS.mmr_needed },
        glow = { sw = s_color_glow_sw, cp = s_color_glow, def = COLOR_DEFAULTS.glow }
    }
    local item = items[key]
    if item and item.sw:Get() then
        local c = ToColor(item.cp:Get())
        if c then return c end
    end
    return (items[key] and items[key].def) or theme.text
end

local ROLE_COLOR_KEYS = { "role_carry", "role_mid", "role_offlane", "role_soft", "role_hard" }
local function GetStatsPartColor(partKey, isIcon, roleId)
    if partKey == "role" and roleId and roleId >= 1 and roleId <= 5 then
        local rk = ROLE_COLOR_KEYS[roleId]
        local roleItems = {
            role_carry = { sw = s_color_stats_role_carry_sw, cp = s_color_stats_role_carry, def = COLOR_DEFAULTS.role_carry },
            role_mid = { sw = s_color_stats_role_mid_sw, cp = s_color_stats_role_mid, def = COLOR_DEFAULTS.role_mid },
            role_offlane = { sw = s_color_stats_role_offlane_sw, cp = s_color_stats_role_offlane, def = COLOR_DEFAULTS.role_offlane },
            role_soft = { sw = s_color_stats_role_soft_sw, cp = s_color_stats_role_soft, def = COLOR_DEFAULTS.role_soft },
            role_hard = { sw = s_color_stats_role_hard_sw, cp = s_color_stats_role_hard, def = COLOR_DEFAULTS.role_hard }
        }
        local item = roleItems[rk]
        if item and item.sw:Get() then
            local c = ToColor(item.cp:Get())
            if c then return c end
        end
        return (item and item.def) or theme.text
    end
    local key = "stats_" .. partKey .. (isIcon and "_icon" or "_text")
    local defByKey = { kda = COLOR_DEFAULTS.stats_kda, nw = COLOR_DEFAULTS.stats_nw, creep = COLOR_DEFAULTS.stats_creep }
    local items = {
        stats_dmg_text = { sw = s_color_stats_dmg_text_sw, cp = s_color_stats_dmg_text, def = COLOR_DEFAULTS.stats },
        stats_dmg_icon = { sw = s_color_stats_dmg_icon_sw, cp = s_color_stats_dmg_icon, def = COLOR_DEFAULTS.icon },
        stats_kda_text = { sw = s_color_stats_kda_text_sw, cp = s_color_stats_kda_text, def = COLOR_DEFAULTS.stats_kda },
        stats_kda_icon = { sw = s_color_stats_kda_icon_sw, cp = s_color_stats_kda_icon, def = COLOR_DEFAULTS.stats_kda },
        stats_nw_text = { sw = s_color_stats_nw_text_sw, cp = s_color_stats_nw_text, def = COLOR_DEFAULTS.stats_nw },
        stats_nw_icon = { sw = s_color_stats_nw_icon_sw, cp = s_color_stats_nw_icon, def = COLOR_DEFAULTS.stats_nw },
        stats_creep_text = { sw = s_color_stats_creep_text_sw, cp = s_color_stats_creep_text, def = COLOR_DEFAULTS.stats_creep },
        stats_creep_icon = { sw = s_color_stats_creep_icon_sw, cp = s_color_stats_creep_icon, def = COLOR_DEFAULTS.stats_creep }
    }
    local item = items[key]
    if item and item.sw:Get() then
        local c = ToColor(item.cp:Get())
        if c then return c end
    end
    return (items[key] and items[key].def) or theme.text
end

local function GetIconColor(sw, cp, def)
    if sw:Get() then
        local c = ToColor(cp:Get())
        if c then return c end
    end
    return def or theme.text
end

local function ItemEnabled(name)
    return s_display_items:Get(name)
end

local font_name = Render.LoadFont("Segoe UI", Enum.FontCreate.FONTFLAG_ANTIALIAS, Enum.FontWeight.NORMAL)
local font_name_bold = Render.LoadFont("Segoe UI", Enum.FontCreate.FONTFLAG_ANTIALIAS, Enum.FontWeight.BOLD)
local font_mmr = Render.LoadFont("PakenhamBl Italic", Enum.FontCreate.FONTFLAG_ANTIALIAS, Enum.FontWeight.BOLD)
local font_mmr_normal = Render.LoadFont("PakenhamBl Italic", Enum.FontCreate.FONTFLAG_ANTIALIAS, Enum.FontWeight.NORMAL)
local font_stats_bold = Render.LoadFont("Segoe UI", Enum.FontCreate.FONTFLAG_ANTIALIAS, Enum.FontWeight.BOLD)
local font_stats_normal = Render.LoadFont("Segoe UI", Enum.FontCreate.FONTFLAG_ANTIALIAS, Enum.FontWeight.NORMAL)

local function GetIcon1Path()
    local idx = s_icon1:Get()
    local name = ICON1_OPTIONS[idx + 1] or "dota"
    return "~/MenuIcons/" .. (ICON1_FILES[name] or "icon1.png")
end

local icons = {
    dota = 0,
    mmr = 0,
    stats_dmg = Render.LoadImage("~/MenuIcons/target_alt.png") or 0,
    stats_kda = Render.LoadImage("~/MenuIcons/skull.png") or 0,
    stats_nw = Render.LoadImage("~/MenuIcons/money_bag.png") or 0,
    stats_creep = Render.LoadImage("~/MenuIcons/enemy_evil.png") or 0
}

local ICON1_SIZE = 58
local ICON2_SIZE = 16
local RANK_ICON_SIZE = 20
local STATS_ICON_SIZE = 14
local STATS_FONT_SIZE = 14
local PAD_X = 12
local PAD_Y = 12
local GAP = 6
local STATS_GAP = 12
local FLAG_SIZE = 16
local FLAG_GAP = 4

local state = {
    drag = { active = false, offset = Vec2(0, 0) },
    panel_pos = Vec2(0, 0),
    panel_size = Vec2(0, 0),
    panel_visible = false,
    lastMMR = 0
}

local function GetRoleIcon(roleId)
    if not roleId or roleId < 1 or roleId > 5 then return 0 end
    if cached.role_icons and cached.role_icons[roleId] then
        return cached.role_icons[roleId]
    end
    cached.role_icons = cached.role_icons or {}
    local path = ROLE_ICON_PATHS[roleId]
    if path then
        cached.role_icons[roleId] = Render.LoadImage(path) or 0
        return cached.role_icons[roleId]
    end
    return 0
end

local function GetFlagHandle(code)
    if not code or code == "" then return 0 end
    if cached.flags[code] then
        return cached.flags[code]
    end
    local h = Render.LoadImage("~/countries/" .. code .. ".png") or 0
    cached.flags[code] = h
    return h
end

function SessionInfo.OnGameThreadInit()
    local mmr = Engine.GetMMRV2()
    cached.mmr = mmr
    cached.steam_name = Steam.GetPersonaName() or "Player"
    if LoadSession() then
        state.lastMMR = mmr > 0 and mmr or session.start_mmr
    else
        session.start_clock = os.clock()
        session.start_time = os.time()
        session.start_mmr = mmr > 0 and mmr or 0
        session.wins = 0
        session.losses = 0
        session.initialized = mmr > 0
        state.lastMMR = mmr > 0 and mmr or 0
        SaveSession()
    end
end

local function TriggerStatsRefresh()
    cached.stats5 = nil
    cached.last5_wl = nil
    stats5_state.last_fetch_frame = 0
    stats5_state.retry_count = 0
    stats5_state.retry_gc_at = 0
    if not FetchStats5FromSignedOut() then
        if FetchStats5GC() then
            stats5_state.last_fetch_frame = 1
        end
    else
        stats5_state.last_fetch_frame = 1
    end
end

local function HandleDrag(pos, size)
    if s_lock:Get() then return end
    if Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE1) then
        local cursor = Vec2(Input.GetCursorPos())
        if not state.drag.active and Input.IsCursorInRect(pos.x, pos.y, size.x, size.y) then
            state.drag.active = true
            state.drag.offset = cursor - pos
        elseif state.drag.active then
            local newPos = cursor - state.drag.offset
            s_x:Set(math.floor(newPos.x))
            s_y:Set(math.floor(newPos.y))
        end
    else
        state.drag.active = false
    end
end

function SessionInfo.OnFrame()
    if Menu.Opened() then
        UpdateMenuLanguage()
    end

    if not session_load_attempted then
        session_load_attempted = true
        if not session.initialized and LoadSession() then
            local mmr = Engine.GetMMRV2()
            state.lastMMR = mmr > 0 and mmr or session.start_mmr
        end
    end

    if s_gc_trigger:Get() then
        s_gc_trigger:Set(false)
        local mid = s_match_id:Get()
        if mid and mid ~= "" then
            RequestMatchDetails(mid)
        end
    end

    if cached.reset_colors then
        cached.reset_colors = nil
        s_color_steam_sw:Set(false); s_color_steam:Visible(false)
        s_color_mmr_sw:Set(false); s_color_mmr:Visible(false)
        s_color_mmr_current_sw:Set(false); s_color_mmr_current:Visible(false)
        s_color_mmr_needed_sw:Set(false); s_color_mmr_needed:Visible(false)
        s_color_glow_sw:Set(false); s_color_glow:Visible(false)
        s_color_stats_dmg_text_sw:Set(false); s_color_stats_dmg_text:Visible(false)
        s_color_stats_dmg_icon_sw:Set(false); s_color_stats_dmg_icon:Visible(false)
        s_color_stats_kda_text_sw:Set(true); s_color_stats_kda_text:Set(COLOR_DEFAULTS.stats_kda); s_color_stats_kda_text:Visible(true)
        s_color_stats_kda_icon_sw:Set(true); s_color_stats_kda_icon:Set(COLOR_DEFAULTS.stats_kda); s_color_stats_kda_icon:Visible(true)
        s_color_stats_nw_text_sw:Set(true); s_color_stats_nw_text:Set(COLOR_DEFAULTS.stats_nw); s_color_stats_nw_text:Visible(true)
        s_color_stats_nw_icon_sw:Set(true); s_color_stats_nw_icon:Set(COLOR_DEFAULTS.stats_nw); s_color_stats_nw_icon:Visible(true)
        s_color_stats_creep_text_sw:Set(true); s_color_stats_creep_text:Set(COLOR_DEFAULTS.stats_creep); s_color_stats_creep_text:Visible(true)
        s_color_stats_creep_icon_sw:Set(true); s_color_stats_creep_icon:Set(COLOR_DEFAULTS.stats_creep); s_color_stats_creep_icon:Visible(true)
        s_color_stats_role_carry_sw:Set(true); s_color_stats_role_carry:Set(COLOR_DEFAULTS.role_carry); s_color_stats_role_carry:Visible(true)
        s_color_stats_role_mid_sw:Set(true); s_color_stats_role_mid:Set(COLOR_DEFAULTS.role_mid); s_color_stats_role_mid:Visible(true)
        s_color_stats_role_offlane_sw:Set(true); s_color_stats_role_offlane:Set(COLOR_DEFAULTS.role_offlane); s_color_stats_role_offlane:Visible(true)
        s_color_stats_role_soft_sw:Set(true); s_color_stats_role_soft:Set(COLOR_DEFAULTS.role_soft); s_color_stats_role_soft:Visible(true)
        s_color_stats_role_hard_sw:Set(true); s_color_stats_role_hard:Set(COLOR_DEFAULTS.role_hard); s_color_stats_role_hard:Visible(true)
        s_color_icon1_sw:Set(false); s_color_icon1:Visible(false)
        s_color_icon2_sw:Set(false); s_color_icon2:Visible(false)
        s_color_rank_icon_sw:Set(false); s_color_rank_icon:Visible(false)
        s_bold_steam:Set(BOLD_DEFAULTS.steam_name); s_bold_mmr:Set(BOLD_DEFAULTS.mmr)
        s_bold_stats:Set(BOLD_DEFAULTS.stats); s_bold_mmr_current:Set(BOLD_DEFAULTS.mmr_current); s_bold_mmr_needed:Set(BOLD_DEFAULTS.mmr_needed)
    end

    if cached.manual_stats_refresh then
        cached.manual_stats_refresh = nil
        TriggerStatsRefresh()
    end

    if s_gc_debug_log:Get() then
        s_gc_debug_log:Set(false)
        stats5_state.last_fetch_frame = 0
        stats5_state.retry_gc_at = 0
        stats5_state.retry_count = 0
        stats5_state.debug_log = true
        if not FetchStats5FromSignedOut() then
            cached.stats5 = nil
            FetchStats5GC()
        end
    end

    local idx1 = s_icon1:Get()
    local path2 = (s_icon2_path:Get() or ""):gsub("^%s*(.-)%s*$", "%1")
    if cached._icon1_idx ~= idx1 then
        cached._icon1_idx = idx1
        icons.dota = Render.LoadImage(GetIcon1Path()) or 0
    end
    if cached._icon2_path ~= path2 then
        cached._icon2_path = path2
        icons.mmr = (path2 ~= "" and Render.LoadImage("~/MenuIcons/" .. path2)) or 0
    end

    local mmr = Engine.GetMMRV2()
    if mmr > 0 then
        cached.mmr = mmr
        if state.lastMMR > 0 and mmr ~= state.lastMMR then
            Dbg("MMR changed: " .. tostring(state.lastMMR) .. " -> " .. tostring(mmr))
            if session.initialized then
                if mmr > state.lastMMR then session.wins = session.wins + 1
                else session.losses = session.losses + 1
                end
                SaveSession()
            end
            state.lastMMR = mmr
            if not stats5_state.loading then
                TriggerStatsRefresh()
            else
                stats5_state.need_refresh_after_match = true
                stats5_state.refresh_at = math.max(stats5_state.refresh_at or 0, os.clock() + 2)
            end
        else
            state.lastMMR = mmr
        end
    end

    if stats5_state.loading and stats5_state.loading_start > 0 and (os.clock() - stats5_state.loading_start) > 25 then
        stats5_state.loading = false
        stats5_state.loading_start = 0
        stats5_state.last_fetch_frame = 0
    end
    local hasCachedStats = cached.stats5 and cached.stats5.count and cached.stats5.count > 0
    if stats5_state.retry_gc_at > 0 and os.clock() >= stats5_state.retry_gc_at and not stats5_state.loading and not hasCachedStats then
        Dbg("retry: trigger FetchStats5GC")
        stats5_state.retry_gc_at = 0
        if FetchStats5GC() then
            stats5_state.last_fetch_frame = 1
        end
    end
    if stats5_state.need_refresh_after_match and not stats5_state.loading then
        if stats5_state.refresh_at > 0 and os.clock() < stats5_state.refresh_at then
        else
            Dbg("need_refresh: delay passed, fetching")
            stats5_state.need_refresh_after_match = false
            stats5_state.refresh_at = 0
            cached.stats5 = nil
            cached.last5_wl = nil
            stats5_state.last_fetch_frame = 0
            stats5_state.retry_count = 0
            stats5_state.retry_gc_at = 0
            if FetchStats5FromSignedOut() or FetchStats5GC() then
                stats5_state.last_fetch_frame = 1
            end
        end
    end

    if not s_enable:Get() then
        state.panel_visible = false
        return
    end
    if Engine.GetUIState() ~= Enum.UIState.DOTA_GAME_UI_STATE_DASHBOARD then
        state.panel_visible = false
        stats5_state.dashboard_first_seen = 0
        return
    end

    state.panel_visible = true

    if not stats5_state.loading and stats5_state.last_fetch_frame == 0 and not cached.stats5 and stats5_state.retry_gc_at == 0 then
        if stats5_state.dashboard_first_seen == 0 then
            stats5_state.dashboard_first_seen = os.clock()
        end
        local elapsed = os.clock() - stats5_state.dashboard_first_seen
        if elapsed >= 3 then
            if FetchStats5FromSignedOut() or FetchStats5GC() then
                stats5_state.last_fetch_frame = 1
                Dbg("initial: fetch started")
            else
                Dbg("initial: fetch failed (no signedout, GC)")
            end
        end
    end

    local steamName = Steam.GetPersonaName()
    if steamName and steamName ~= "" then
        cached.steam_name = steamName
    end

    local pos = Vec2(s_x:Get(), s_y:Get())
    local contentX = pos.x + PAD_X

    local nameFontSize = 14
    local mmrFontSize = 28
    local nameSize = Render.TextSize(font_name, nameFontSize, cached.steam_name)
    local mmrStr = cached.mmr > 0 and tostring(cached.mmr) or L_panel("mmr_empty")
    local mmrSize = Render.TextSize(font_mmr, mmrFontSize, mmrStr)

    local icon2W = ItemEnabled(L_panel("mmr")) and (icons.mmr and icons.mmr > 0) and math.min(ICON2_SIZE, mmrSize.y) or 0
    local rowGap = 4
    local stats5Parts = {}
    local stats5Size = Vec2(0, 0)
    if true then
        if stats5_state.loading then
            stats5Parts = {{ icon = 0, text = "..." }}
        elseif cached.stats5 and cached.stats5.count > 0 then
            local c = cached.stats5
            local avgDmg = math.floor(c.damage / c.count)
            local dmgStr = "~" .. (avgDmg >= 1000 and (math.floor(avgDmg / 1000) .. "k") or tostring(avgDmg))
            local avgK = math.floor(c.kills / c.count + 0.5)
            local avgD = math.floor(c.deaths / c.count + 0.5)
            local kdStr = tostring(avgK) .. "/" .. tostring(avgD)
            local avgNw = math.floor(c.networth / c.count)
            local nwStr = "~" .. (avgNw >= 1000 and (math.floor(avgNw / 1000) .. "k") or tostring(avgNw))
            local avgLh = math.floor(c.last_hits / c.count + 0.5)
            local avgDeny = math.floor(c.denies / c.count + 0.5)
            local creepStr = tostring(avgLh) .. "/" .. tostring(avgDeny)
            local topRole, topCount = 0, 0
            if (c.ranked_count or 0) > 0 then
                for r, cnt in pairs(c.roles) do
                    if cnt > topCount then topRole, topCount = r, cnt end
                end
            end
            local rolePart
            if topRole and topRole > 0 then
                local roleIcon = GetRoleIcon(topRole)
                local roleFallback = (roleIcon and roleIcon > 0) and "" or (ROLE_NAMES[topRole] or "?")
                rolePart = { icon = roleIcon, text = roleFallback }
            else
                rolePart = nil
            end
            stats5Parts = {
                { icon = icons.stats_dmg, text = dmgStr, key = "dmg" },
                { icon = icons.stats_kda, text = kdStr, key = "kda" },
                { icon = icons.stats_nw, text = nwStr, key = "nw" },
                { icon = icons.stats_creep, text = creepStr, key = "creep" }
            }
            if rolePart and (cached.mmr or 0) < 8500 then
                rolePart.key = "role"
                rolePart.roleId = topRole
                stats5Parts[5] = rolePart
            end
        elseif not stats5_state.loading then
            stats5Parts = {{ icon = 0, text = L_panel("open_history") }}
        end
        if #stats5Parts > 0 then
            local fontStats = s_bold_stats:Get() and font_stats_bold or font_stats_normal
            local w, h = 0, 0
            for i, part in ipairs(stats5Parts) do
                local txt = part.text or ""
                local sz = txt ~= "" and Render.TextSize(fontStats, STATS_FONT_SIZE, txt) or Vec2(0, STATS_ICON_SIZE)
                h = math.max(h, sz.y)
                if part.icon and part.icon > 0 then w = w + STATS_ICON_SIZE + (txt ~= "" and 2 or 0) end
                w = w + (txt ~= "" and sz.x or (part.icon and part.icon > 0 and STATS_ICON_SIZE or 0))
                if i < #stats5Parts then w = w + 6 end
            end
            stats5Size = Vec2(w, h)
        end
    end
    local stats5Str = #stats5Parts > 0
    local nameMmrBlockH = (ItemEnabled(L_panel("steam_name")) and (nameSize.y + rowGap) or 0) + math.max(mmrSize.y, icon2W)
    local textBlockH = nameMmrBlockH
    local contentOffsetY = 0
    local scaleNameMmr = not stats5Str and nameMmrBlockH > ICON1_SIZE
    if scaleNameMmr then
        local scale = ICON1_SIZE / nameMmrBlockH
        nameFontSize = math.max(8, math.floor(nameFontSize * scale))
        mmrFontSize = math.max(18, math.floor(mmrFontSize * scale))
        nameSize = Render.TextSize(font_name, nameFontSize, cached.steam_name)
        mmrSize = Render.TextSize(font_mmr, mmrFontSize, mmrStr)
        icon2W = ItemEnabled(L_panel("mmr")) and (icons.mmr and icons.mmr > 0) and math.min(ICON2_SIZE, mmrSize.y) or 0
        nameMmrBlockH = (ItemEnabled(L_panel("steam_name")) and (nameSize.y + rowGap) or 0) + math.max(mmrSize.y, icon2W)
        textBlockH = nameMmrBlockH
        contentOffsetY = math.max(0, (ICON1_SIZE - textBlockH) / 2)
    elseif textBlockH <= ICON1_SIZE then
        contentOffsetY = (ICON1_SIZE - textBlockH) / 2
    end
    local countryIdx = s_country:Get()
    local countryCode = (countryIdx > 0 and countries[countryIdx + 1]) and countries[countryIdx + 1][2] or ""
    local showFlag = countryCode ~= ""
    local showMmrToNextText = ItemEnabled(L_panel("mmr_text")) and cached.mmr and cached.mmr > 0
    local showMmrToNextIcon = ItemEnabled(L_panel("mmr_icon")) and cached.mmr and cached.mmr > 0
    local nextRankForLayout = nil
    if showMmrToNextText or showMmrToNextIcon then _, nextRankForLayout = GetRankInfo(cached.mmr) end
    local hasMmrToNext = nextRankForLayout ~= nil and (showMmrToNextText or showMmrToNextIcon)
    local showSession = s_session_show:Get() and session.initialized and session.start_mmr > 0
    local last5Wl = cached.last5_wl or {}
    local showLast5Wl = #last5Wl > 0
    local SESSION_FONT_SIZE = 11
    local WL_FONT_SIZE = 12
    local hasBottomRow = showFlag or hasMmrToNext or showSession or showLast5Wl

    if not session.initialized and (cached.mmr or 0) > 0 then
        session.start_clock = os.clock()
        session.start_time = os.time()
        session.start_mmr = cached.mmr
        session.wins = 0
        session.losses = 0
        session.initialized = true
        state.lastMMR = cached.mmr
        SaveSession()
    end
    local flagAreaH = hasBottomRow and (FLAG_SIZE + FLAG_GAP) or 0

    local nameMmrW = math.max(nameSize.x, mmrSize.x + icon2W)
    local totalContentW = stats5Str and (nameMmrW + STATS_GAP + stats5Size.x) or nameMmrW
    local sessionStrW = 0
    if showSession then
        local totalGames = session.wins + session.losses
        local winrate = totalGames > 0 and (session.wins / totalGames) * 100 or 0
        local wrStr = string.format(L_panel("session_wr"), winrate, session.wins, session.losses)
        local diff = (cached.mmr or 0) - session.start_mmr
        local diffStr = diff > 0 and ("+" .. diff) or tostring(diff)
        sessionStrW = Render.TextSize(font_name, SESSION_FONT_SIZE, wrStr).x + FLAG_GAP + Render.TextSize(font_name, SESSION_FONT_SIZE, diffStr).x
    end
    local last5WlW = 0
    if showLast5Wl then
        local wlGap = 8
        local total = FLAG_GAP
        for j = 1, #last5Wl do
            total = total + Render.TextSize(font_name_bold, WL_FONT_SIZE, last5Wl[j]).x
            if j < #last5Wl then total = total + wlGap end
        end
        last5WlW = total
    end
    local rankInfoW = 0
    if hasMmrToNext then
        local fontCur = s_bold_mmr_current:Get() and font_name_bold or font_name
        local fontNeed = s_bold_mmr_needed:Get() and font_name_bold or font_name
        local curStr = tostring(cached.mmr)
        local sepStr = " / "
        local needStr = tostring(nextRankForLayout.mmr)
        local rs1 = showMmrToNextText and Render.TextSize(fontCur, 11, curStr) or Vec2(0, 0)
        local rs2 = showMmrToNextText and Render.TextSize(fontCur, 11, sepStr) or Vec2(0, 0)
        local rs3 = showMmrToNextText and Render.TextSize(fontNeed, 11, needStr) or Vec2(0, 0)
        local rs = showMmrToNextText and Vec2(rs1.x + rs2.x + rs3.x, math.max(rs1.y, rs2.y, rs3.y)) or Vec2(0, 0)
        local rt = TryGetMMRRank(cached.mmr)
        local hasRankIcon = showMmrToNextIcon and rt > 0 and GetRankIconHandle(rt) > 0
        rankInfoW = (showFlag and (FLAG_SIZE + FLAG_GAP) or 0) + rs.x + (hasRankIcon and (RANK_ICON_SIZE + 4) or 0)
    end
    rankInfoW = rankInfoW + sessionStrW + last5WlW
    local panelW = math.max(200, math.max(PAD_X + ICON1_SIZE + GAP + totalContentW + PAD_X, PAD_X + rankInfoW + PAD_X))
    local padYBot = stats5Str and math.max(4, PAD_Y - 4) or PAD_Y
    local panelH = PAD_Y + math.max(ICON1_SIZE, textBlockH) + padYBot + flagAreaH
    local size = Vec2(panelW, panelH)

    state.panel_pos = pos
    state.panel_size = size

    HandleDrag(pos, size)

    local bgColor = theme.bg
    if s_transparent:Get() then
        local pct = math.max(0, math.min(100, s_trans_alpha:Get()))
        local alpha = math.floor(pct * 2.55)
        bgColor = Color(20, 20, 20, alpha)
    end
    Render.FilledRect(pos, pos + size, bgColor, 10, Enum.DrawFlags.RoundCornersAll)
    if s_transparent:Get() then
        Render.Blur(pos, pos + size, 1, 0.9, 10, Enum.DrawFlags.RoundCornersAll)
    end

    local blockY = pos.y + PAD_Y
    local blockX = contentX

    if icons.dota and icons.dota > 0 then
        local icon1Col = GetIconColor(s_color_icon1_sw, s_color_icon1, theme.text)
        Render.Image(icons.dota, Vec2(blockX, blockY), Vec2(ICON1_SIZE, ICON1_SIZE), icon1Col)
        blockX = blockX + ICON1_SIZE + GAP
    end

    local nameY = blockY + contentOffsetY
    local mmrRowY = blockY + contentOffsetY + (ItemEnabled(L_panel("steam_name")) and (nameSize.y + rowGap) or 0)
    if ItemEnabled(L_panel("steam_name")) then
        local fontSteam = s_bold_steam:Get() and font_name_bold or font_name
        Render.Text(fontSteam, nameFontSize, cached.steam_name, Vec2(blockX, nameY), GetDisplayColor("steam_name"))
    end

    local icon2WUsed = ItemEnabled(L_panel("mmr")) and (icons.mmr and icons.mmr > 0) and icon2W or 0
    local mmrTextY = mmrRowY + (math.max(mmrSize.y, icon2WUsed) - mmrSize.y) / 2
    if ItemEnabled(L_panel("mmr")) and icons.mmr and icons.mmr > 0 and icon2W > 0 then
        local icon2X = blockX
        local icon2Y = mmrTextY + (mmrSize.y - icon2W) / 2
        local icon2Col = GetIconColor(s_color_icon2_sw, s_color_icon2, theme.text)
        Render.Image(icons.mmr, Vec2(icon2X, icon2Y), Vec2(icon2W, icon2W), icon2Col)
    end
    if ItemEnabled(L_panel("mmr")) then
        local fontMmr = s_bold_mmr:Get() and font_mmr or font_mmr_normal
        local mmrX = blockX + icon2WUsed
        Render.Text(fontMmr, mmrFontSize, mmrStr, Vec2(mmrX, mmrTextY), GetDisplayColor("mmr"))
    end
    if stats5Str then
        local fontStats = s_bold_stats:Get() and font_stats_bold or font_stats_normal
        local statsX = blockX + nameMmrW + STATS_GAP
        local statsY = blockY + contentOffsetY + (textBlockH - stats5Size.y) / 2
        for i, part in ipairs(stats5Parts) do
            local partKey = part.key or "dmg"
            local roleId = part.roleId
            if part.icon and part.icon > 0 then
                local iconY = statsY + (stats5Size.y - STATS_ICON_SIZE) / 2
                local iconCol = GetStatsPartColor(partKey, true, roleId)
                Render.Image(part.icon, Vec2(statsX, iconY), Vec2(STATS_ICON_SIZE, STATS_ICON_SIZE), iconCol)
                statsX = statsX + STATS_ICON_SIZE + ((part.text or "") ~= "" and 2 or 0)
            end
            local txt = part.text or ""
            if txt ~= "" then
                local sz = Render.TextSize(fontStats, STATS_FONT_SIZE, txt)
                local txtCol = GetStatsPartColor(partKey, false, roleId)
                Render.Text(fontStats, STATS_FONT_SIZE, txt, Vec2(statsX, statsY), txtCol)
                statsX = statsX + sz.x
            end
            if i < #stats5Parts then statsX = statsX + 6 end
        end
    end

    local centerX = pos.x + size.x / 2
    local centerY = pos.y + size.y - flagAreaH - 0.5
    local glowLayers = 3
    local layerH = 0.8
    local transparent = Color(255, 255, 255, 0)
    for i = 0, glowLayers do
        local t = 1 - i / (glowLayers + 1)
        local alpha = math.floor(120 * t * t + 30)
        local widthMult = 0.25 + 0.75 * t
        local halfW = (size.x / 2) * widthMult
        local layerY = centerY - i * layerH
        local glowCol = GetDisplayColor("glow")
        glowCol = Color(glowCol.r, glowCol.g, glowCol.b, alpha)
        Render.Gradient(
            Vec2(centerX - halfW, layerY),
            Vec2(centerX, layerY + layerH),
            transparent, glowCol, transparent, glowCol
        )
        Render.Gradient(
            Vec2(centerX, layerY),
            Vec2(centerX + halfW, layerY + layerH),
            glowCol, transparent, glowCol, transparent
        )
    end

    local bottomRowY = pos.y + size.y - FLAG_SIZE - FLAG_GAP / 2
    local bottomRowX = pos.x + PAD_X
    if showFlag then
        local flagH = GetFlagHandle(countryCode)
        if flagH and flagH > 0 then
            local flagPos = Vec2(bottomRowX, bottomRowY)
            local flagEnd = flagPos + Vec2(FLAG_SIZE, FLAG_SIZE)
            local flagRound = 3
            Render.Shadow(flagPos, flagEnd, Color(0, 0, 0, 100), 4, flagRound, Enum.DrawFlags.ShadowCutOutShapeBackground, Vec2(1, 1))
            Render.Image(flagH, flagPos, Vec2(FLAG_SIZE, FLAG_SIZE), Color(255, 255, 255, 255), flagRound, Enum.DrawFlags.RoundCornersAll)
            Render.Rect(flagPos, flagEnd, Color(255, 255, 255, 40), flagRound, Enum.DrawFlags.RoundCornersAll, 1)
            bottomRowX = bottomRowX + FLAG_SIZE + FLAG_GAP
        end
    end
    if hasMmrToNext then
        if showMmrToNextText then
            local fontCur = s_bold_mmr_current:Get() and font_name_bold or font_name
            local fontNeed = s_bold_mmr_needed:Get() and font_name_bold or font_name
            local curStr = tostring(cached.mmr)
            local sepStr = " / "
            local needStr = tostring(nextRankForLayout.mmr)
            local szCur = Render.TextSize(fontCur, 11, curStr)
            local szSep = Render.TextSize(fontCur, 11, sepStr)
            local szNeed = Render.TextSize(fontNeed, 11, needStr)
            local rankY = bottomRowY + (FLAG_SIZE - math.max(szCur.y, szNeed.y)) / 2
            Render.Text(fontCur, 11, curStr, Vec2(bottomRowX, rankY), GetDisplayColor("mmr_current"))
            bottomRowX = bottomRowX + szCur.x
            Render.Text(fontCur, 11, sepStr, Vec2(bottomRowX, rankY), GetDisplayColor("mmr_current"))
            bottomRowX = bottomRowX + szSep.x
            Render.Text(fontNeed, 11, needStr, Vec2(bottomRowX, rankY), GetDisplayColor("mmr_needed"))
            bottomRowX = bottomRowX + szNeed.x + 4
        end
        if showMmrToNextIcon then
            local rt = TryGetMMRRank(cached.mmr)
            if rt > 0 then
                local rankIconH = GetRankIconHandle(rt)
                if rankIconH and rankIconH > 0 then
                    local rankIconY = bottomRowY + (FLAG_SIZE - RANK_ICON_SIZE) / 2
                    local rankIconCol = GetIconColor(s_color_rank_icon_sw, s_color_rank_icon, theme.text)
                    Render.Image(rankIconH, Vec2(bottomRowX, rankIconY), Vec2(RANK_ICON_SIZE, RANK_ICON_SIZE), rankIconCol)
                    bottomRowX = bottomRowX + RANK_ICON_SIZE + 4
                end
            end
        end
    end

    if showSession then
        if showFlag or hasMmrToNext then
            bottomRowX = bottomRowX + FLAG_GAP
        end
        local totalGames = session.wins + session.losses
        local winrate = totalGames > 0 and (session.wins / totalGames) * 100 or 0
        local wrStr = string.format(L_panel("session_wr"), winrate, session.wins, session.losses)
        local diff = (cached.mmr or 0) - session.start_mmr
        local diffStr = diff > 0 and ("+" .. diff) or tostring(diff)
        local sz1 = Render.TextSize(font_name, SESSION_FONT_SIZE, wrStr)
        local sessY = bottomRowY + (FLAG_SIZE - SESSION_FONT_SIZE) / 2
        local wrCol = theme.text
        if winrate >= 50 then wrCol = Color(100, 255, 100, 255) elseif totalGames > 0 then wrCol = Color(255, 100, 100, 255) end
        local diffCol = diff > 0 and Color(100, 255, 100, 255) or (diff < 0 and Color(255, 100, 100, 255) or theme.text)
        Render.Text(font_name, SESSION_FONT_SIZE, wrStr, Vec2(bottomRowX, sessY), wrCol)
        Render.Text(font_name, SESSION_FONT_SIZE, diffStr, Vec2(bottomRowX + sz1.x + 8, sessY), diffCol)
    end

    if showLast5Wl and #last5Wl > 0 then
        local gap = 8
        local wlY = bottomRowY + (FLAG_SIZE - WL_FONT_SIZE) / 2
        local rightEdge = pos.x + size.x - PAD_X
        local cx = rightEdge
        for i = 1, #last5Wl do
            local ch = last5Wl[i]
            local chW = Render.TextSize(font_name_bold, WL_FONT_SIZE, ch).x
            cx = cx - chW
            local col = ch == "W" and Color(100, 255, 100, 255) or Color(255, 100, 100, 255)
            Render.Text(font_name_bold, WL_FONT_SIZE, ch, Vec2(cx, wlY), col)
            cx = cx - gap
        end
    end
end

function SessionInfo.OnGameRulesStateChange(data)
    if data and data.new_state == Enum.GameState.DOTA_GAMERULES_STATE_POST_GAME then
        Dbg("POST_GAME: need_refresh +5s")
        stats5_state.need_refresh_after_match = true
        stats5_state.refresh_at = os.clock() + 5
        if not stats5_state.loading then
            FetchStats5GC()
        else
            Dbg("POST_GAME: skip FetchStats5GC loading=true")
        end
    end
end

function SessionInfo.OnGameEnd()
    if not Engine.IsInGame() then
        local newMmr = Engine.GetMMRV2()
        if newMmr > 0 and state.lastMMR > 0 and session.initialized then
            local diff = newMmr - state.lastMMR
            if diff > 0 then
                session.wins = session.wins + 1
                SaveSession()
            elseif diff < 0 then
                session.losses = session.losses + 1
                SaveSession()
            end
        end
        state.lastMMR = newMmr
    end
end

function SessionInfo.OnKeyEvent(data)
    if not state.panel_visible then
        return true
    end
    if data.event == Enum.EKeyEvent.EKeyEvent_KEY_DOWN and data.key == Enum.ButtonCode.KEY_MOUSE1 then
        local pos = state.panel_pos
        local size = state.panel_size
        if Input.IsCursorInRect(pos.x, pos.y, size.x, size.y) then
            return false
        end
    end
    return true
end

return SessionInfo
