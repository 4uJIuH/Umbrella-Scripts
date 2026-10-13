---@diagnostic disable: undefined-global

local script = {}

local JSON = require("assets.JSON")

local localization = qLocalization.new({
    en = {
        menu = {
            forecast = "Forecast",
            drawing = "Display",
            enabled = "Enabled",
            settings = "Settings",
            match_cap = "Matches per support",
            match_cap_tip = "Each match is a separate OpenDota request (~270 KB)",
            top_spots = "Spots per support",
            min_score = "Minimum score",
            refresh = "Refresh",
            show_obs = "Observers",
            show_sen = "Sentries",
            use_reach = "Account for hero position",
            use_reach_tip = "Dims the markers of spots the support is currently far from",
            supports = "Supports for OpenDota",
            supports_tip = "Tick the enemy supports. Nothing ticked — picked automatically (top 2 by wards)",
            reload = "Load history",
            minimap = "On minimap",
            world = "In world",
            panel = "Panel",
            scale = "Panel size",
            hero_colors = "Hero colours",
            hero_colors_tip = "Off: colour by ward type — observer yellow, sentry blue",
        },

        picker = {
            waiting = "waiting for the match",
            no_steam = "enemies have no Steam ID",
            unchecked = "not checked yet",
            closed = "profile closed or no parsed games",
            wards = "%d wards in history",
        },

        panel = {
            waiting = "Waiting for the match…",
            no_enemies = "No enemies in this game (demo?)",
            probing = "Looking for supports on OpenDota…",
            empty = "No enemy has public data",
            coverage = "OpenDota sees ~1 in 3 pub players",
            loading = "Loading match history…",
            head = "%s  ·  %d matches, %d wards",
            head_loading = " (loading…)",
            no_parsed = "  no parsed matches",
            obs = "obs score",
            sen = "sentry score",
            low_data = "  little data, score understated",
            hits = "came true",
            draw_error = "WARD PREDICTOR: draw error",
            menu_failed = "WARD PREDICTOR: menu failed to create",
        },
    },

    ru = {
        menu = {
            forecast = "Прогноз",
            drawing = "Отрисовка",
            enabled = "Включён",
            settings = "Настройки",
            match_cap = "Матчей на саппорта",
            match_cap_tip = "Каждый матч — отдельный запрос к OpenDota (~270 КБ)",
            top_spots = "Точек на саппорта",
            min_score = "Минимальный score",
            refresh = "Пересчёт",
            show_obs = "Обсерверы",
            show_sen = "Сентри",
            use_reach = "Учитывать позицию героя",
            use_reach_tip = "Приглушает метки точек, до которых саппорт сейчас далеко",
            supports = "Саппорты для OpenDota",
            supports_tip = "Отметь вражеских саппортов. Ничего не отмечено — выбор автоматом (топ-2 по вардам)",
            reload = "Загрузить историю",
            minimap = "На миникарте",
            world = "В мире",
            panel = "Панель",
            scale = "Размер панели",
            hero_colors = "Цвет героя",
            hero_colors_tip = "Выключено: цвет по типу варда — обсервер жёлтый, сентри синий",
        },

        picker = {
            waiting = "жду начала матча",
            no_steam = "у врагов нет Steam ID",
            unchecked = "ещё не проверен",
            closed = "профиль закрыт или нет разобранных игр",
            wards = "%d вардов в истории",
        },

        panel = {
            waiting = "Жду начала матча…",
            no_enemies = "В игре нет врагов (демка?)",
            probing = "Ищу саппортов в OpenDota…",
            empty = "Ни у кого из врагов нет открытых данных",
            coverage = "OpenDota видит ~1 из 3 паб-игроков",
            loading = "Гружу историю матчей…",
            head = "%s  ·  %d матчей, %d вардов",
            head_loading = " (гружу…)",
            no_parsed = "  нет распаршенных матчей",
            obs = "обсы score",
            sen = "сентри score",
            low_data = "  мало данных, score занижен",
            hits = "сбылось",
            draw_error = "WARD PREDICTOR: ошибка отрисовки",
            menu_failed = "WARD PREDICTOR: меню не создалось",
        },
    },

    cn = {
        menu = {
            forecast = "预测",
            drawing = "显示",
            enabled = "启用",
            settings = "设置",
            match_cap = "每个辅助的比赛数",
            match_cap_tip = "每场比赛都是一次单独的 OpenDota 请求（约 270 KB）",
            top_spots = "每个辅助的点位数",
            min_score = "最低分数",
            refresh = "刷新间隔",
            show_obs = "侦查守卫",
            show_sen = "岗哨守卫",
            use_reach = "考虑英雄位置",
            use_reach_tip = "降低辅助当前距离较远的点位标记亮度",
            supports = "用于 OpenDota 的辅助",
            supports_tip = "勾选敌方辅助。未勾选时自动选择（守卫最多的前两名）",
            reload = "加载历史",
            minimap = "小地图上",
            world = "游戏世界中",
            panel = "面板",
            scale = "面板大小",
            hero_colors = "英雄颜色",
            hero_colors_tip = "关闭：按守卫类型着色——侦查守卫为黄色，岗哨守卫为蓝色",
        },

        picker = {
            waiting = "等待比赛开始",
            no_steam = "敌人没有 Steam ID",
            unchecked = "尚未检查",
            closed = "资料未公开或没有已解析的比赛",
            wards = "历史中 %d 个守卫",
        },

        panel = {
            waiting = "等待比赛开始…",
            no_enemies = "本局没有敌人（演示模式？）",
            probing = "正在 OpenDota 上查找辅助…",
            empty = "没有敌人公开数据",
            coverage = "OpenDota 只能看到约三分之一的路人玩家",
            loading = "正在加载比赛历史…",
            head = "%s  ·  %d 场比赛，%d 个守卫",
            head_loading = "（加载中…）",
            no_parsed = "  没有已解析的比赛",
            obs = "侦查分数",
            sen = "岗哨分数",
            low_data = "  数据较少，分数偏低",
            hits = "命中",
            draw_error = "WARD PREDICTOR：绘制错误",
            menu_failed = "WARD PREDICTOR：菜单创建失败",
        },
    },

    es = {
        menu = {
            forecast = "Pronóstico",
            drawing = "Visualización",
            enabled = "Activado",
            settings = "Ajustes",
            match_cap = "Partidas por soporte",
            match_cap_tip = "Cada partida es una petición aparte a OpenDota (~270 KB)",
            top_spots = "Puntos por soporte",
            min_score = "Puntuación mínima",
            refresh = "Actualización",
            show_obs = "Observadores",
            show_sen = "Centinelas",
            use_reach = "Tener en cuenta la posición del héroe",
            use_reach_tip = "Atenúa las marcas de los puntos de los que el soporte está lejos ahora",
            supports = "Soportes para OpenDota",
            supports_tip = "Marca los soportes enemigos. Sin marcar: elección automática (top 2 por wards)",
            reload = "Cargar historial",
            minimap = "En el minimapa",
            world = "En el mundo",
            panel = "Panel",
            scale = "Tamaño del panel",
            hero_colors = "Color del héroe",
            hero_colors_tip = "Desactivado: color por tipo de ward — observador amarillo, centinela azul",
        },

        picker = {
            waiting = "esperando la partida",
            no_steam = "los enemigos no tienen Steam ID",
            unchecked = "aún no comprobado",
            closed = "perfil privado o sin partidas analizadas",
            wards = "%d wards en el historial",
        },

        panel = {
            waiting = "Esperando la partida…",
            no_enemies = "No hay enemigos en esta partida (¿demo?)",
            probing = "Buscando soportes en OpenDota…",
            empty = "Ningún enemigo tiene datos públicos",
            coverage = "OpenDota ve ~1 de cada 3 jugadores de pub",
            loading = "Cargando historial de partidas…",
            head = "%s  ·  %d partidas, %d wards",
            head_loading = " (cargando…)",
            no_parsed = "  sin partidas analizadas",
            obs = "puntuación obs",
            sen = "puntuación sentry",
            low_data = "  pocos datos, puntuación subestimada",
            hits = "acertados",
            draw_error = "WARD PREDICTOR: error de dibujo",
            menu_failed = "WARD PREDICTOR: no se pudo crear el menú",
        },
    },

    pt = {
        menu = {
            forecast = "Previsão",
            drawing = "Exibição",
            enabled = "Ativado",
            settings = "Configurações",
            match_cap = "Partidas por suporte",
            match_cap_tip = "Cada partida é uma requisição separada ao OpenDota (~270 KB)",
            top_spots = "Pontos por suporte",
            min_score = "Pontuação mínima",
            refresh = "Atualização",
            show_obs = "Observadores",
            show_sen = "Sentinelas",
            use_reach = "Considerar a posição do herói",
            use_reach_tip = "Esmaece as marcas dos pontos dos quais o suporte está longe agora",
            supports = "Suportes para o OpenDota",
            supports_tip = "Marque os suportes inimigos. Nada marcado: escolha automática (top 2 por wards)",
            reload = "Carregar histórico",
            minimap = "No minimapa",
            world = "No mundo",
            panel = "Painel",
            scale = "Tamanho do painel",
            hero_colors = "Cor do herói",
            hero_colors_tip = "Desativado: cor pelo tipo de ward — observador amarelo, sentinela azul",
        },

        picker = {
            waiting = "aguardando a partida",
            no_steam = "os inimigos não têm Steam ID",
            unchecked = "ainda não verificado",
            closed = "perfil privado ou sem partidas analisadas",
            wards = "%d wards no histórico",
        },

        panel = {
            waiting = "Aguardando a partida…",
            no_enemies = "Sem inimigos nesta partida (demo?)",
            probing = "Procurando suportes no OpenDota…",
            empty = "Nenhum inimigo tem dados públicos",
            coverage = "O OpenDota vê ~1 em cada 3 jogadores de pub",
            loading = "Carregando histórico de partidas…",
            head = "%s  ·  %d partidas, %d wards",
            head_loading = " (carregando…)",
            no_parsed = "  sem partidas analisadas",
            obs = "pontuação obs",
            sen = "pontuação sentry",
            low_data = "  poucos dados, pontuação subestimada",
            hits = "acertos",
            draw_error = "WARD PREDICTOR: erro de desenho",
            menu_failed = "WARD PREDICTOR: falha ao criar o menu",
        },
    },
})

local Menu = localization.WrapLibrary(Menu)

local function T(key, ...)
    local s = localization.Get(key)
    if select("#", ...) == 0 then return s end
    return s:format(...)
end

local GRID_CENTER = 128
local GRID_SCALE = 128

local HIST_LIMIT = 300
local HALF_LIFE = 12
local SIGMA_T = 420
local SIDE_OTHER_W = 0.35
local LANE_OTHER_W = 0.6
local LANE_UNKNOWN_W = 0.8
local ALPHA = 1.2
local MERGE_RADIUS = 640
local REACH_SCALE = 4500
local REACH_FLOOR = 0.15
local LIVE_SUPPRESS = 360
local STABLE = { hysteresis = 0.6, match = 320, lastPosTtl = 30, merge = 700 }
local HIT_RADIUS = 900
local REQ_INTERVAL = 1.1
local API = "https://api.opendota.com/api"

local WARD_ICON = {
    [0] = "panorama/images/items/ward_observer_png.vtex_c",
    [1] = "panorama/images/items/ward_sentry_png.vtex_c",
}

local KIND_COLORS = {
    [0] = Color(255, 214, 51, 255),
    [1] = Color(51, 136, 255, 255),
}

local PLAYER_COLORS = {
    [0] = Color(51, 117, 255, 255),
    [1] = Color(102, 255, 191, 255),
    [2] = Color(191, 0, 191, 255),
    [3] = Color(243, 240, 11, 255),
    [4] = Color(255, 107, 0, 255),
    [5] = Color(254, 134, 194, 255),
    [6] = Color(161, 180, 71, 255),
    [7] = Color(101, 217, 247, 255),
    [8] = Color(0, 131, 33, 255),
    [9] = Color(164, 105, 0, 255),
}

local function try(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, r = pcall(fn, ...)
    if ok then return r end
    return nil
end

local function log(level, message, data)
    if type(ai_bridge) ~= "table" or type(ai_bridge.mcp_log) ~= "function" then return end
    pcall(ai_bridge.mcp_log, level, message, data)
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function round(v) return math.floor(v + 0.5) end

local function api(tbl, name)
    return type(tbl) == "table" and type(tbl[name]) == "function" and tbl[name] or nil
end

local ENUM = type(Enum) == "table" and Enum or {}
local DRAW_NONE = (ENUM.DrawFlags and ENUM.DrawFlags.None) or 0
local MOUSE1 = ENUM.ButtonCode and ENUM.ButtonCode.KEY_MOUSE1 or nil
local FONT_AA = ENUM.FontCreate and ENUM.FontCreate.FONTFLAG_ANTIALIAS or 0
local WARD_FLAG = ENUM.UnitTypeFlags and ENUM.UnitTypeFlags.TYPE_WARD or nil
local WORLD_Z = api(World, "GetGroundZ")

local IN_CURSOR = api(Input, "GetCursorPos")
local IN_DOWN   = api(Input, "IsKeyDown")
local IN_ONCE   = api(Input, "IsKeyDownOnce")
local IN_RECT   = api(Input, "IsCursorInRect")
local CAN_DRAG  = IN_CURSOR and IN_DOWN and IN_ONCE and IN_RECT and MOUSE1 ~= nil

local function grid_to_world(g) return (g - GRID_CENTER) * GRID_SCALE end

local Ui = {}

Ui.panel = {
    font = nil,
    iconFont = nil,
    styleOk = false,
    themeFrame = -1,
    animWidget = nil,
    animFound = false,
    x = nil,
    y = nil,
    width = 0,
    height = 0,
    headerHeight = 0,
    collapsed = false,
    dragging = false,
    wasDragging = false,
    dragOffsetX = 0,
    dragOffsetY = 0,
    open = 1,
    chevronAnim = 0,
    collapseBounds = nil,
}

Ui.colors = {}
Ui.textCache = { entries = {}, keys = {}, cursor = 1, limit = 512 }

function Ui.textSize(f, fontSize, text)
    local cache = Ui.textCache
    local key = tostring(f) .. ":" .. tostring(fontSize) .. ":" .. text
    local size = cache.entries[key]
    if size ~= nil then return size end

    size = try(Render.TextSize, f, fontSize, text) or { x = #text * fontSize * 0.55, y = fontSize }
    local cursor = cache.cursor
    local previousKey = cache.keys[cursor]
    if previousKey ~= nil then cache.entries[previousKey] = nil end
    cache.entries[key] = size
    cache.keys[cursor] = key
    cache.cursor = cursor % cache.limit + 1
    return size
end

function Ui.setBounds(bounds, x, y, width, height)
    bounds = bounds or {}
    bounds.x, bounds.y, bounds.width, bounds.height = x, y, width, height
    return bounds
end

function Ui.pointInside(bounds, cursorX, cursorY)
    return bounds ~= nil
        and cursorX >= bounds.x
        and cursorX <= bounds.x + bounds.width
        and cursorY >= bounds.y
        and cursorY <= bounds.y + bounds.height
end

function Ui.style(name, fallback)
    if not Ui.panel.styleOk then return fallback end
    local color = Menu.Style(name)
    if color == nil or color.r == nil then return fallback end
    return color
end

function Ui.speed(multiplier)
    if not Ui.panel.animFound then
        Ui.panel.animFound = true
        Ui.panel.animWidget = try(Menu.Find, "SettingsHidden", "", "", "", "Main", "Animation Duration")
    end
    local duration = Ui.panel.animWidget ~= nil and try(Ui.panel.animWidget.Get, Ui.panel.animWidget) or 50
    return multiplier * 1000 / clamp(duration or 50, 10, 1000)
end

function Ui.refreshTheme()
    local frame = try(GlobalVars.GetFrameCount)
    if frame ~= nil and frame == Ui.panel.themeFrame then return end
    Ui.panel.themeFrame = frame

    Ui.colors = {
        body      = Ui.style("main_background", Color(24, 24, 27, 235)),
        plate     = Ui.style("group_background", Color(37, 37, 42, 235)),
        border    = Ui.style("outline", Color(48, 48, 55, 180)),
        accent    = Ui.style("primary", Color(214, 58, 50, 250)),
        text      = Ui.style("primary_widgets_text", Color(238, 238, 242, 250)),
        textMuted = Ui.style("third_tab_text", Color(146, 146, 156, 210)),
        good      = Ui.style("multiselect_item_selected", Color(63, 191, 95, 245)),
        bad       = Ui.style("multiselect_item", Color(224, 50, 45, 245)),
        shadow    = Color(0, 0, 0, 130),
    }
end

function Ui.ease(current, goal, speed)
    local dt = try(GlobalVars.GetAbsFrameTime) or 0
    if dt <= 0 or dt > 0.2 then return goal end
    return current + (goal - current) * math.min(1, dt * speed)
end

function Ui.fade(color, alpha)
    return Color(color.r, color.g, color.b, round(color.a * alpha))
end

function Ui.mix(from, to, t)
    return Color(
        round(from.r + (to.r - from.r) * t),
        round(from.g + (to.g - from.g) * t),
        round(from.b + (to.b - from.b) * t),
        round(from.a + (to.a - from.a) * t)
    )
end

function Ui.drawIcon(fontSize, glyph, centerX, centerY, color)
    local size = Ui.textSize(Ui.panel.iconFont, fontSize, glyph)
    pcall(Render.Text, Ui.panel.iconFont, fontSize, glyph,
        Vec2(round(centerX - size.x * 0.5), round(centerY - size.y * 0.5)), color)
    return size
end

function Ui.drawCentered(fontSize, text, x, y, width, height, color)
    local textSize = Ui.textSize(Ui.panel.font, fontSize, text)
    pcall(Render.Text, Ui.panel.font, fontSize, text,
        Vec2(round(x + (width - textSize.x) * 0.5), round(y + (height - textSize.y) * 0.5)), color)
end

function Ui.drawRow(fontSize, label, value, x, y, width, height, labelColor, valueColor)
    local labelSize = Ui.textSize(Ui.panel.font, fontSize, label)
    local valueSize = Ui.textSize(Ui.panel.font, fontSize, value)
    local textY = round(y + (height - labelSize.y) * 0.5)
    pcall(Render.Text, Ui.panel.font, fontSize, label, Vec2(x, textY), labelColor)
    pcall(Render.Text, Ui.panel.font, fontSize, value,
        Vec2(round(x + width - valueSize.x), textY), valueColor)
end

function Ui.drawLine(fontSize, text, x, y, height, color)
    local size = Ui.textSize(Ui.panel.font, fontSize, text)
    pcall(Render.Text, Ui.panel.font, fontSize, text,
        Vec2(x, round(y + (height - size.y) * 0.5)), color)
end

local function utf8_char_count(str)
    local count, i, n = 0, 1, #str
    while i <= n do
        local b = str:byte(i)
        local seqLen = (b >= 0xF0 and 4) or (b >= 0xE0 and 3) or (b >= 0xC0 and 2) or 1
        i = i + seqLen
        count = count + 1
    end
    return count
end

local function utf8_sub(str, charCount)
    if charCount <= 0 then return "" end
    local i, count, n = 1, 0, #str
    while i <= n and count < charCount do
        local b = str:byte(i)
        local seqLen = (b >= 0xF0 and 4) or (b >= 0xE0 and 3) or (b >= 0xC0 and 2) or 1
        i = i + seqLen
        count = count + 1
    end
    return str:sub(1, i - 1)
end

local function truncate_to_width(f, size, str, maxWidth)
    if maxWidth <= 0 then return "" end
    if Ui.textSize(f, size, str).x <= maxWidth then return str end
    local ellipsis = "…"
    local lo, hi = 0, utf8_char_count(str)
    while lo < hi do
        local mid = math.ceil((lo + hi) / 2)
        local candidate = utf8_sub(str, mid) .. ellipsis
        if Ui.textSize(f, size, candidate).x <= maxWidth then
            lo = mid
        else
            hi = mid - 1
        end
    end
    if lo <= 0 then return ellipsis end
    return utf8_sub(str, lo) .. ellipsis
end

local ui = {}
local ready = false

local S = {
    phase = "idle",
    enemyTeam = nil,
    enemyRadiant = nil,
    players = {},
    byAcc = {},
    manual = {},
    manualDirty = false,
    queue = {},
    inflight = false,
    nextRequest = 0,
    lastError = nil,
    seenWards = {},
    hitTotal = 0,
    hitOk = 0,
    pickerIds = {},
    pickerSig = nil,
    pickerTip = nil,
    pickerRows = nil,
    pickerApplied = false,
    pickerApplyAt = 0,
    pickerRetries = 0,
    waitReason = nil,
    images = {},
    shown = {},
    lastPos = {},
}

local g_predictions = {}
local g_markers = {}
local g_next = 0

local function steam_to_account(steam64)
    if type(steam64) ~= "number" then return nil end
    local acc = try(function() return math.floor(steam64 % 4294967296) end)
    if acc == nil then return nil end
    if acc <= 0 or acc >= 4294967295 then return nil end
    return acc
end

local function urlencode(s)
    return (s:gsub("[^%w%-%_%.%~]", function(c)
        return string.format("%%%02X", string.byte(c))
    end))
end

local function local_team()
    local hero = try(Heroes.GetLocal)
    if hero == nil then return nil end
    return try(Entity.GetTeamNum, hero)
end

local function collect_enemies()
    local myTeam = local_team()
    if myTeam == nil then
        S.waitReason = "no_hero"
        return false
    end

    local players = try(Players.GetAll) or {}
    local found = {}
    for _, p in pairs(players) do
        local team = try(Entity.GetTeamNum, p)
        if team ~= nil and team ~= myTeam and (team == 2 or team == 3) then
            local data = try(Player.GetPlayerData, p)
            local pid = try(Player.GetPlayerID, p)
            local acc = data and steam_to_account(data.steamid) or nil
            if pid ~= nil and pid >= 0 then
                found[#found + 1] = {
                    player = p,
                    pid = pid,
                    acc = acc,
                    name = (data and data.PlayerName) or ("Player " .. tostring(pid)),
                    team = team,
                }
            end
        end
    end

    if #found == 0 then
        S.waitReason = "no_enemies"
        return false
    end
    table.sort(found, function(a, b) return a.pid < b.pid end)

    S.players = found
    S.enemyTeam = found[1].team
    S.enemyRadiant = (found[1].team == 2)
    S.waitReason = nil
    return true
end

local function record(acc)
    local entry = S.byAcc[acc]
    if entry == nil then
        entry = {
            state = "queued",
            wardCount = 0,
            listed = 0,
            parsed = 0,
            used = 0,
            pending = 0,
            laneCount = {},
            modalLane = nil,
            events = {},
            live = {},
        }
        S.byAcc[acc] = entry
    end
    return entry
end

local function push(job)
    S.queue[#S.queue + 1] = job
end

local function http_get(url, onDone)
    local sent = HTTP.Request("GET", url, {
        headers = {
            ["User-Agent"] = "Umbrella/1.0",
            ["Accept"] = "application/json",
        },
        timeout = 30000,
    }, function(response)
        S.inflight = false
        S.nextRequest = os.clock() + REQ_INTERVAL

        local code = tonumber(response and response.code) or 0
        if code < 200 or code >= 300 then
            S.lastError = "HTTP " .. tostring(code)
            onDone(nil)
            return
        end
        local ok, payload = pcall(function() return JSON:decode(response.response or "null") end)
        if not ok then
            S.lastError = "bad json"
            onDone(nil)
            return
        end
        onDone(payload)
    end, "ward_predictor")

    if not sent then
        S.inflight = false
        S.nextRequest = os.clock() + REQ_INTERVAL
        S.lastError = "request not started"
        onDone(nil)
    end
end

local function job_wardmap(job)
    local entry = record(job.acc)
    entry.state = "probing"
    http_get(API .. "/players/" .. tostring(job.acc) .. "/wardmap?limit=40", function(payload)
        local total = 0
        if type(payload) == "table" then
            for _, key in ipairs({ "obs", "sen" }) do
                local map = payload[key]
                if type(map) == "table" then
                    for _, column in pairs(map) do
                        if type(column) == "table" then
                            for _, n in pairs(column) do
                                total = total + (tonumber(n) or 0)
                            end
                        end
                    end
                end
            end
        end
        entry.wardCount = total
        entry.state = total > 0 and "probed" or "nodata"
    end)
end

local function build_explorer_sql(accounts, cap)
    local list = table.concat(accounts, ",")
    local lim = tostring(cap)
    return table.concat({
        "WITH m AS (SELECT account_id,match_id,player_slot,lane_role,obs_log,sen_log,",
        "row_number() OVER (PARTITION BY account_id ORDER BY match_id DESC) rn ",
        "FROM player_matches WHERE account_id IN (", list, ") ",
        "AND (obs_log IS NOT NULL OR sen_log IS NOT NULL)) ",
        "SELECT account_id a,rn,(player_slot<128) r,lane_role l,0 k,(o->>'time')::int t,",
        "(o->>'x')::float x,(o->>'y')::float y FROM m,unnest(obs_log) o WHERE rn<=", lim, " ",
        "UNION ALL SELECT account_id,rn,(player_slot<128),lane_role,1,(o->>'time')::int,",
        "(o->>'x')::float,(o->>'y')::float FROM m,unnest(sen_log) o WHERE rn<=", lim,
    })
end

local function job_explorer(job)
    for _, acc in ipairs(job.accs) do
        record(acc).state = "probing"
    end

    local cap = ui.matchCap and ui.matchCap:Get() or 15
    local url = API .. "/explorer?sql=" .. urlencode(build_explorer_sql(job.accs, cap))

    http_get(url, function(payload)
        local rows = (type(payload) == "table" and payload.err == nil and payload.rows) or {}
        local ranks = {}

        for _, row in ipairs(rows) do
            local acc = tonumber(row.a)
            local entry = acc ~= nil and S.byAcc[acc] or nil
            if entry ~= nil then
                local rn = tonumber(row.rn) or 1
                local lane = tonumber(row.l)
                ranks[acc] = ranks[acc] or {}
                ranks[acc][rn] = true
                if lane ~= nil then
                    entry.laneCount[lane] = (entry.laneCount[lane] or 0) + 1
                end
                entry.events[#entry.events + 1] = {
                    x = grid_to_world(tonumber(row.x) or GRID_CENTER),
                    y = grid_to_world(tonumber(row.y) or GRID_CENTER),
                    t = tonumber(row.t) or 0,
                    kind = tonumber(row.k) or 0,
                    rank = rn - 1,
                    radiant = row.r == true,
                    lane = lane,
                }
            end
        end

        for _, acc in ipairs(job.accs) do
            local entry = record(acc)
            if #entry.events > 0 then
                local used = 0
                for _ in pairs(ranks[acc] or {}) do used = used + 1 end
                entry.used = used
                entry.parsed = used
                entry.source = "explorer"
                local best, bestN = nil, 0
                for lane, n in pairs(entry.laneCount) do
                    if n > bestN then best, bestN = lane, n end
                end
                entry.modalLane = best
                entry.state = "ok"
            else
                entry.state = "queued"
                push({ kind = "matches", acc = acc })
            end
        end
    end)
end

local function job_matches(job)
    local entry = record(job.acc)
    entry.state = "listing"
    local url = API .. "/players/" .. tostring(job.acc) .. "/matches?limit=" .. tostring(HIST_LIMIT)
        .. "&project=version&project=lane_role&project=start_time"
    http_get(url, function(payload)
        if type(payload) ~= "table" then
            entry.state = "nodata"
            return
        end

        entry.listed = #payload
        local parsed = {}
        for _, m in ipairs(payload) do
            if m.version ~= nil and m.match_id ~= nil then
                parsed[#parsed + 1] = m
            end
        end
        entry.parsed = #parsed

        local cap = ui.matchCap and ui.matchCap:Get() or 15
        local taken = 0
        for rank, m in ipairs(parsed) do
            if taken >= cap then break end
            taken = taken + 1
            entry.pending = entry.pending + 1
            push({
                kind = "match",
                acc = job.acc,
                mid = m.match_id,
                rank = rank - 1,
                radiant = (tonumber(m.player_slot) or 0) < 128,
                lane = tonumber(m.lane_role),
            })
        end

        if taken == 0 then
            entry.state = "nodata"
        else
            entry.state = "loading"
        end
    end)
end

local function job_match(job)
    local entry = record(job.acc)
    http_get(API .. "/matches/" .. tostring(job.mid), function(payload)
        entry.pending = math.max(0, entry.pending - 1)

        if type(payload) == "table" and type(payload.players) == "table" then
            for _, p in ipairs(payload.players) do
                if tonumber(p.account_id) == job.acc then
                    local lane = tonumber(p.lane_role) or job.lane
                    if lane ~= nil then
                        entry.laneCount[lane] = (entry.laneCount[lane] or 0) + 1
                    end
                    local got = 0
                    for kind, field in ipairs({ "obs_log", "sen_log" }) do
                        local log = p[field]
                        if type(log) == "table" then
                            for _, e in ipairs(log) do
                                if e.entityleft ~= true and e.x ~= nil and e.y ~= nil then
                                    got = got + 1
                                    entry.events[#entry.events + 1] = {
                                        x = grid_to_world(tonumber(e.x) or GRID_CENTER),
                                        y = grid_to_world(tonumber(e.y) or GRID_CENTER),
                                        t = tonumber(e.time) or 0,
                                        kind = kind - 1,
                                        rank = job.rank,
                                        radiant = job.radiant,
                                        lane = lane,
                                    }
                                end
                            end
                        end
                    end
                    if got > 0 then entry.used = entry.used + 1 end
                    break
                end
            end
        end

        if entry.pending == 0 then
            local best, bestN = nil, 0
            for lane, n in pairs(entry.laneCount) do
                if n > bestN then best, bestN = lane, n end
            end
            entry.modalLane = best
            entry.source = "api"
            entry.state = #entry.events > 0 and "ok" or "nodata"
        end
    end)
end

local function pump_queue()
    if S.inflight then return end
    if os.clock() < S.nextRequest then return end
    local job = table.remove(S.queue, 1)
    if job == nil then return end

    S.inflight = true
    if job.kind == "wardmap" then
        job_wardmap(job)
    elseif job.kind == "explorer" then
        job_explorer(job)
    elseif job.kind == "matches" then
        job_matches(job)
    else
        job_match(job)
    end
end

local function selected_accounts()
    local chosen = {}
    for _, p in ipairs(S.players) do
        if p.acc ~= nil and S.manual[p.acc] then chosen[#chosen + 1] = p end
    end
    if #chosen > 0 then return chosen end

    local ranked = {}
    for _, p in ipairs(S.players) do
        if p.acc ~= nil then
            local entry = S.byAcc[p.acc]
            ranked[#ranked + 1] = { player = p, wards = entry and entry.wardCount or 0 }
        end
    end
    table.sort(ranked, function(a, b)
        if a.wards ~= b.wards then return a.wards > b.wards end
        return a.player.pid < b.player.pid
    end)

    for i = 1, math.min(2, #ranked) do
        if ranked[i].wards > 0 then chosen[#chosen + 1] = ranked[i].player end
    end
    return chosen
end

local function start_probe()
    if not collect_enemies() then return end
    S.phase = "probing"
    S.byAcc = {}
    S.queue = {}
    for _, p in ipairs(S.players) do
        if p.acc ~= nil then
            record(p.acc)
            push({ kind = "wardmap", acc = p.acc })
        end
    end
end

local function probe_done()
    for _, p in ipairs(S.players) do
        if p.acc ~= nil then
            local st = S.byAcc[p.acc] and S.byAcc[p.acc].state
            if st == "queued" or st == "probing" then return false end
        end
    end
    return true
end

local function start_detail()
    local chosen = selected_accounts()
    if #chosen == 0 then
        S.phase = "empty"
        return
    end
    S.phase = "loading"
    local fresh = {}
    for _, p in ipairs(chosen) do
        local entry = record(p.acc)
        if entry.state ~= "ok" and entry.state ~= "loading" then
            entry.state = "queued"
            entry.events = {}
            entry.used = 0
            entry.parsed = 0
            entry.listed = 0
            entry.pending = 0
            entry.laneCount = {}
            entry.source = nil
            fresh[#fresh + 1] = p.acc
        end
    end
    if #fresh > 0 then
        push({ kind = "explorer", accs = fresh })
    end
end

local function detail_done()
    for _, p in ipairs(selected_accounts()) do
        local st = S.byAcc[p.acc] and S.byAcc[p.acc].state
        if st ~= "ok" and st ~= "nodata" then return false end
    end
    return true
end

local function merge_cells(cells)
    table.sort(cells, function(a, b) return a.mass > b.mass end)
    local out = {}
    for _, cell in ipairs(cells) do
        local host = nil
        for _, kept in ipairs(out) do
            local dx, dy = kept.x - cell.x, kept.y - cell.y
            if dx * dx + dy * dy <= MERGE_RADIUS * MERGE_RADIUS then
                host = kept
                break
            end
        end
        if host == nil then
            out[#out + 1] = { x = cell.x, y = cell.y, mass = cell.mass, n = cell.n }
        else
            local total = host.mass + cell.mass
            if total > 0 then
                host.x = (host.x * host.mass + cell.x * cell.mass) / total
                host.y = (host.y * host.mass + cell.y * cell.mass) / total
            end
            host.mass = total
            host.n = host.n + cell.n
        end
    end
    return out
end

local function context_weight(event, now, modalLane)
    local recency = 0.5 ^ (event.rank / HALF_LIFE)

    local dt = event.t - now
    local timeAffinity = math.exp(-(dt * dt) / (2 * SIGMA_T * SIGMA_T))

    local side = (event.radiant == S.enemyRadiant) and 1 or SIDE_OTHER_W

    local lane = LANE_UNKNOWN_W
    if event.lane == nil or modalLane == nil then
        lane = LANE_UNKNOWN_W
    elseif event.lane == modalLane then
        lane = 1
    else
        lane = LANE_OTHER_W
    end

    return recency * timeAffinity * side * lane
end

local function score_spots(entry, kind, now)
    local cells = {}
    for _, event in ipairs(entry.events) do
        if event.kind == kind then
            local w = context_weight(event, now, entry.modalLane)
            if w > 0.001 then
                cells[#cells + 1] = { x = event.x, y = event.y, mass = w, n = 1 }
            end
        end
    end
    if #cells == 0 then return {} end

    local spots = merge_cells(cells)
    local total = 0
    for _, spot in ipairs(spots) do total = total + spot.mass end

    for _, spot in ipairs(spots) do
        spot.score = spot.mass / (total + ALPHA)
    end
    return spots
end

local function enemy_hero_pos(pid)
    local now = try(GameRules.GetGameTime) or 0
    for _, hero in pairs(try(Heroes.GetAll) or {}) do
        if try(Hero.GetPlayerID, hero) == pid
            and try(Entity.GetTeamNum, hero) == S.enemyTeam
            and not try(NPC.IsIllusion, hero)
        then
            if try(NPC.IsVisible, hero) then
                local pos = try(Entity.GetAbsOrigin, hero)
                if pos ~= nil then
                    S.lastPos[pid] = { x = pos.x, y = pos.y, t = now }
                    return pos
                end
            end
            break
        end
    end
    local last = S.lastPos[pid]
    if last ~= nil and now - last.t <= STABLE.lastPosTtl then return last end
    return nil
end

local function was_shown(previous, spot)
    for _, old in ipairs(previous) do
        local dx, dy = old.x - spot.x, old.y - spot.y
        if dx * dx + dy * dy <= STABLE.match * STABLE.match then return true end
    end
    return false
end

local function reach_factor(heroPos, spot)
    if heroPos == nil then return 1 end
    local dx, dy = heroPos.x - spot.x, heroPos.y - spot.y
    local dist = math.sqrt(dx * dx + dy * dy)
    return clamp(math.exp(-dist / REACH_SCALE), REACH_FLOOR, 1)
end

local function player_color(p, index)
    local color = PLAYER_COLORS[p.pid]
    if color == nil and p.player ~= nil then
        local slot = try(Player.GetPlayerTeamSlot, p.player)
        if type(slot) == "number" and slot >= 0 and slot <= 4 then
            color = PLAYER_COLORS[(p.team == 3 and 5 or 0) + slot]
        end
    end
    return color or PLAYER_COLORS[(index - 1) % 10]
end

local function suppress_factor(live, spot, now, kind)
    if live == nil then return 1 end
    for _, event in ipairs(live) do
        if event.kind == kind and now - event.time < LIVE_SUPPRESS then
            local dx, dy = event.x - spot.x, event.y - spot.y
            if dx * dx + dy * dy < HIT_RADIUS * HIT_RADIUS then return 0.05 end
        end
    end
    return 1
end

local function build_markers(records)
    local markers = {}
    for kind = 0, 1 do
        local flat = {}
        for _, rec in ipairs(records) do
            local list = kind == 0 and rec.obs or rec.sen
            for rank, spot in ipairs(list) do
                flat[#flat + 1] = { rec = rec, spot = spot, rank = rank }
            end
        end
        table.sort(flat, function(a, b) return a.spot.score > b.spot.score end)

        local group = {}
        for _, item in ipairs(flat) do
            local host = nil
            for _, marker in ipairs(group) do
                local dx, dy = marker.x - item.spot.x, marker.y - item.spot.y
                if dx * dx + dy * dy <= STABLE.merge * STABLE.merge and not marker.accs[item.rec.acc] then
                    host = marker
                    break
                end
            end
            if host == nil then
                host = { kind = kind, x = item.spot.x, y = item.spot.y, mass = 0, entries = {}, accs = {},
                    best = false, score = 0, reach = 0 }
                group[#group + 1] = host
                markers[#markers + 1] = host
            end
            local w = math.max(item.spot.score, 0.001)
            host.x = (host.x * host.mass + item.spot.x * w) / (host.mass + w)
            host.y = (host.y * host.mass + item.spot.y * w) / (host.mass + w)
            host.mass = host.mass + w
            host.entries[#host.entries + 1] = item
            host.accs[item.rec.acc] = true
            host.best = host.best or item.rank == 1
            host.score = math.max(host.score, item.spot.score)
            host.reach = math.max(host.reach, item.spot.reach or 1)
        end
    end
    return markers
end

local function rebuild_predictions()
    local out = {}
    local now = try(GameRules.GetGameTime) or 0
    local topN = ui.topSpots and ui.topSpots:Get() or 4
    local minScore = (ui.minScore and ui.minScore:Get() or 8) / 100
    local wantObs = ui.showObs == nil or ui.showObs:Get()
    local wantSen = ui.showSen ~= nil and ui.showSen:Get()
    local useReach = ui.useReach == nil or ui.useReach:Get()
    local shownNext = {}

    for index, p in ipairs(selected_accounts()) do
        local entry = S.byAcc[p.acc]
        if entry ~= nil then
            local heroPos = useReach and enemy_hero_pos(p.pid) or nil
            local record_ = {
                acc = p.acc,
                pid = p.pid,
                name = p.name,
                unit = p.unit,
                color = player_color(p, index),
                used = entry.used,
                parsed = entry.parsed,
                listed = entry.listed,
                state = entry.state,
                source = entry.source,
                events = #entry.events,
                obs = {},
                sen = {},
            }

            for kind = 0, 1 do
                if (kind == 0 and wantObs) or (kind == 1 and wantSen) then
                    local spots = score_spots(entry, kind, now)
                    local target = kind == 0 and record_.obs or record_.sen
                    for _, spot in ipairs(spots) do
                        spot.reach = reach_factor(heroPos, spot)
                        spot.score = spot.score * suppress_factor(entry.live, spot, now, kind)
                    end
                    table.sort(spots, function(a, b) return a.score > b.score end)

                    local key = tostring(p.acc) .. ":" .. kind
                    local previous = S.shown[key] or {}
                    local keep = {}
                    for _, spot in ipairs(spots) do
                        if #target >= topN then break end
                        local threshold = was_shown(previous, spot) and minScore * STABLE.hysteresis or minScore
                        if spot.score >= threshold then
                            target[#target + 1] = spot
                            keep[#keep + 1] = { x = spot.x, y = spot.y }
                        end
                    end
                    shownNext[key] = keep
                end
            end

            out[#out + 1] = record_
        end
    end

    S.shown = shownNext
    g_predictions = out
    g_markers = build_markers(out)
end

local function find_player_by_pid(pid)
    for _, p in ipairs(S.players) do
        if p.pid == pid then return p end
    end
    return nil
end

local function ward_owner(ward)
    local owner = try(Entity.RecursiveGetOwner, ward)
    if owner ~= nil then
        local pid = try(Player.GetPlayerID, owner)
        if pid ~= nil and pid >= 0 then
            local p = find_player_by_pid(pid)
            if p ~= nil then return p end
        end
    end

    local pos = try(Entity.GetAbsOrigin, ward)
    if pos == nil then return nil end
    local best, bestDist = nil, 1600 * 1600
    for _, hero in pairs(try(Heroes.GetAll) or {}) do
        if try(Entity.GetTeamNum, hero) == S.enemyTeam then
            local hp = try(Entity.GetAbsOrigin, hero)
            if hp ~= nil then
                local dx, dy = hp.x - pos.x, hp.y - pos.y
                local d = dx * dx + dy * dy
                if d < bestDist then
                    bestDist = d
                    best = find_player_by_pid(try(Hero.GetPlayerID, hero) or -1)
                end
            end
        end
    end
    return best
end

local function register_ward(ward)
    local key = tostring(ward)
    if S.seenWards[key] then return end
    S.seenWards[key] = true

    if try(Entity.GetTeamNum, ward) ~= S.enemyTeam then return end
    local pos = try(Entity.GetAbsOrigin, ward)
    if pos == nil then return end

    local name = try(NPC.GetUnitName, ward) or ""
    local kind = name:find("sentry") ~= nil and 1 or 0
    local now = try(GameRules.GetGameTime) or 0

    local owner = ward_owner(ward)
    if owner == nil or owner.acc == nil then return end

    local entry = S.byAcc[owner.acc]
    if entry == nil then return end

    entry.live[#entry.live + 1] = { x = pos.x, y = pos.y, kind = kind, time = now }

    local hit, predicted = false, false
    for _, rec in ipairs(g_predictions) do
        if rec.acc == owner.acc then
            local list = kind == 0 and rec.obs or rec.sen
            if #list > 0 then predicted = true end
            for _, spot in ipairs(list) do
                local dx, dy = spot.x - pos.x, spot.y - pos.y
                if dx * dx + dy * dy < HIT_RADIUS * HIT_RADIUS then hit = true end
            end
        end
    end

    if predicted then
        S.hitTotal = S.hitTotal + 1
        if hit then S.hitOk = S.hitOk + 1 end
    end

    entry.events[#entry.events + 1] = {
        x = pos.x,
        y = pos.y,
        t = now,
        kind = kind,
        rank = -HALF_LIFE,
        radiant = S.enemyRadiant,
        lane = entry.modalLane,
    }

    log("info", "ward_predictor observed ward", {
        player = owner.name,
        kind = kind == 0 and "obs" or "sen",
        predicted = predicted,
        hit = hit,
        x = round(pos.x),
        y = round(pos.y),
        time = round(now),
    })
end

local function scan_wards()
    local wards = try(NPCs.GetAll, WARD_FLAG)
    if wards == nil then
        wards = try(NPCs.GetAll, function(npc) return NPC.IsWard(npc) end) or {}
    end
    for _, ward in pairs(wards) do
        register_ward(ward)
    end
end

local function reset_all()
    S.phase = "idle"
    S.players = {}
    S.byAcc = {}
    S.manual = {}
    S.manualDirty = false
    S.queue = {}
    S.inflight = false
    S.lastError = nil
    S.seenWards = {}
    S.hitTotal = 0
    S.hitOk = 0
    S.pickerIds = {}
    S.pickerSig = nil
    S.pickerTip = nil
    S.waitReason = nil
    S.shown = {}
    S.lastPos = {}
    g_predictions = {}
    g_markers = {}
end

local function initialize_menu()
    local side = (type(Enum) == "table" and Enum.GroupSide) or {}
    local section = Menu.Create("General", "Main", "Ward Predictor", "Main")
    local mainGroup = section:Create("menu.forecast", side.Left)
    local drawGroup = section:Create("menu.drawing", side.Right)

    ui.enabled = mainGroup:Switch("menu.enabled", true, "\u{f06e}")
    local settings = ui.enabled:Gear("menu.settings", "\u{f013}")
    ui.matchCap = settings:Slider("menu.match_cap", 5, 30, 15, "%d")
    ui.matchCap:Icon("\u{f1da}")
    ui.matchCap:ToolTip("menu.match_cap_tip")
    ui.topSpots = settings:Slider("menu.top_spots", 1, 8, 4, "%d")
    ui.topSpots:Icon("\u{f3c5}")
    ui.minScore = settings:Slider("menu.min_score", 2, 60, 8, "%d%%")
    ui.minScore:Icon("\u{f200}")
    ui.refresh = settings:Slider("menu.refresh", 250, 3000, 1000, "%d ms")
    ui.refresh:Icon("\u{f017}")

    ui.showObs = mainGroup:Switch("menu.show_obs", true)
    pcall(ui.showObs.Image, ui.showObs, WARD_ICON[0])
    ui.showSen = mainGroup:Switch("menu.show_sen", true)
    pcall(ui.showSen.Image, ui.showSen, WARD_ICON[1])
    ui.useReach = mainGroup:Switch("menu.use_reach", true, "\u{f277}")
    ui.useReach:ToolTip("menu.use_reach_tip")
    ui.supports = mainGroup:MultiSelect("menu.supports", { { T("picker.waiting"), "", false } }, true)
    ui.supports:ToolTip("menu.supports_tip")
    ui.reload = mainGroup:Button("menu.reload", function()
        S.queue = {}
        S.phase = "idle"
        S.byAcc = {}
    end)

    ui.drawMinimap = drawGroup:Switch("menu.minimap", true, "\u{f278}")
    ui.drawWorld = drawGroup:Switch("menu.world", true, "\u{f0ac}")
    ui.heroColors = drawGroup:Switch("menu.hero_colors", true, "\u{f53f}")
    ui.heroColors:ToolTip("menu.hero_colors_tip")
    ui.drawPanel = drawGroup:Switch("menu.panel", true, "\u{f0ca}")
    ui.scale = drawGroup:Slider("menu.scale", 70, 150, 100, "%d%%")
    ui.scale:Icon("\u{f065}")

    local function hidden_store(name)
        local w = settings:Slider(name, -1, 8192, -1)
        if w ~= nil and type(w.Visible) == "function" then pcall(w.Visible, w, false) end
        return w
    end
    ui.posX = hidden_store("panel_x")
    ui.posY = hidden_store("panel_y")

    return true
end

local function saved_pos()
    if ui.posX == nil or ui.posY == nil then return nil end
    local x = try(ui.posX.Get, ui.posX)
    local y = try(ui.posY.Get, ui.posY)
    if type(x) ~= "number" or type(y) ~= "number" or x < 0 or y < 0 then return nil end
    return x, y
end

local function save_pos(x, y)
    if ui.posX == nil or ui.posY == nil then return end
    try(ui.posX.Set, ui.posX, round(x))
    try(ui.posY.Set, ui.posY, round(y))
end

local function initialize_fonts()
    Ui.panel.font = try(Render.LoadFont, "MuseoSansEx", FONT_AA, 500)
        or try(Render.LoadFont, "Arial", 0, 500)
        or try(Render.LoadFont, "Arial")
    Ui.panel.iconFont = try(Render.LoadFont, "FontAwesomeEx", FONT_AA, 400)
end

local g_menu_error = nil

function script.OnScriptsLoaded()
    Ui.panel.styleOk = pcall(Menu.Style, "primary")
    initialize_fonts()
    local ok, res = pcall(initialize_menu)
    ready = ok and res == true
    if not ready then
        g_menu_error = ok and "initialize_menu returned false" or tostring(res)
    end
    log("info", "ward_predictor loaded", { menu_ready = ready, error = g_menu_error })
end

function script.OnGameEnd()
    reset_all()
end

local function hero_label(unit)
    local short = tostring(unit):gsub("^npc_dota_hero_", ""):gsub("_", " ")
    local titled = short:gsub("(%a)(%w*)", function(a, b) return a:upper() .. b end)
    return titled
end

local function hero_unit_for(p)
    if p.unit ~= nil then return p.unit end

    local hero = p.player ~= nil and try(Player.GetAssignedHero, p.player) or nil
    if hero == nil then
        for _, candidate in pairs(try(Heroes.GetAll) or {}) do
            if try(Hero.GetPlayerID, candidate) == p.pid
                and not try(NPC.IsIllusion, candidate)
                and not try(NPC.IsMeepoClone, candidate)
            then
                hero = candidate
                break
            end
        end
    end

    local unit = hero ~= nil and try(NPC.GetUnitName, hero) or nil
    if type(unit) == "string" and unit ~= "" then p.unit = unit end
    return p.unit
end

local function image_handle(path)
    if path == nil or path == "" then return nil end
    local handle = S.images[path]
    if handle == nil then
        handle = try(Render.LoadImage, path) or false
        S.images[path] = handle
    end
    return handle ~= false and handle or nil
end

local function hero_image(unit)
    if unit == nil then return "" end
    local path = "panorama/images/heroes/icons/" .. unit .. "_png.vtex_c"
    image_handle(path)
    return path
end

local function read_picker_selection()
    local changed = false
    for label, acc in pairs(S.pickerIds) do
        local on = try(ui.supports.Get, ui.supports, label) == true
        if (S.manual[acc] == true) ~= on then
            S.manual[acc] = on or nil
            changed = true
        end
    end
    if changed then S.manualDirty = true end
end

local function sync_picker()
    if ui.supports == nil then return end

    local rows, ids, sigParts, tipParts, used = {}, {}, {}, {}, {}
    for _, p in ipairs(S.players) do
        if p.acc ~= nil then
            local unit = hero_unit_for(p)
            local nick = (p.name ~= nil and p.name ~= "") and p.name or ("Player " .. tostring(p.pid))
            local label = unit ~= nil and (hero_label(unit) .. " — " .. nick) or nick
            if used[label] then label = label .. " #" .. tostring(p.pid) end
            used[label] = true

            local image = hero_image(unit)
            rows[#rows + 1] = { label, image, S.manual[p.acc] == true }
            ids[label] = p.acc
            sigParts[#sigParts + 1] = label .. "|" .. image

            local entry = S.byAcc[p.acc]
            local info = T("picker.unchecked")
            if entry ~= nil and entry.state == "nodata" then
                info = T("picker.closed")
            elseif entry ~= nil and (entry.wardCount or 0) > 0 then
                info = T("picker.wards", math.floor(entry.wardCount))
            end
            tipParts[#tipParts + 1] = label .. ": " .. info
        end
    end

    if #rows == 0 then
        local placeholder = T(#S.players == 0 and "picker.waiting" or "picker.no_steam")
        rows[1] = { placeholder, "", false }
        sigParts[1] = "#" .. placeholder
    end

    local sig = table.concat(sigParts, ";")
    if sig ~= S.pickerSig then
        S.pickerSig = sig
        S.pickerIds = ids
        S.pickerRows = rows
        S.pickerApplied = false
        S.pickerApplyAt = 0
        S.pickerRetries = 2
    end

    if #tipParts > 0 then
        local tip = T("menu.supports_tip") .. "\n\n" .. table.concat(tipParts, "\n")
        pcall(ui.supports.ToolTip, ui.supports, tip)
        S.pickerTip = true
    elseif S.pickerTip then
        pcall(ui.supports.ToolTip, ui.supports, T("menu.supports_tip"))
        S.pickerTip = nil
    end

    if S.pickerRows == nil then read_picker_selection() end
end

function script.OnUpdate()
    if not ready or not ui.enabled:Get() then return end

    pump_queue()

    local now = try(GameRules.GetGameTime) or os.clock()
    if now < g_next then return end
    g_next = now + (ui.refresh:Get() / 1000)

    pcall(sync_picker)

    if S.phase == "idle" then
        start_probe()
    elseif S.phase == "probing" and probe_done() then
        start_detail()
    elseif S.phase == "loading" and detail_done() then
        S.phase = "ready"
        local summary = {}
        for _, p in ipairs(selected_accounts()) do
            local e = S.byAcc[p.acc]
            summary[p.name] = e and (tostring(e.used) .. "/" .. tostring(e.parsed) .. " matches, "
                .. tostring(#e.events) .. " wards") or "none"
        end
        log("info", "ward_predictor history ready", {
            enemy_radiant = S.enemyRadiant,
            supports = summary,
        })
    elseif S.manualDirty and (S.phase == "ready" or S.phase == "empty" or S.phase == "loading") then
        S.manualDirty = false
        start_detail()
    end

    pcall(scan_wards)
    if S.phase == "ready" or S.phase == "loading" then
        pcall(rebuild_predictions)
    end
end

function script.OnNpcSpawned(npc)
    if not ready or S.enemyTeam == nil then return end
    if not try(NPC.IsWard, npc) then return end
    pcall(register_ward, npc)
end

local MARK = {
    ringRadius = 110,
    segments = 20,
    stem = 26,
    badgeH = 22,
    icon = 16,
    pad = 5,
    gap = 6,
    rounding = 6,
    cos = {},
    sin = {},
    wardIcon = WARD_ICON,
    useHero = true,
}

local function spot_ground(spot)
    if spot.gz == nil then
        spot.gz = (WORLD_Z ~= nil and try(WORLD_Z, spot.x, spot.y)) or 128
    end
    return spot.gz
end

local function ring_points(spot, z, radius)
    if MARK.cos[0] == nil then
        for i = 0, MARK.segments do
            local a = i / MARK.segments * math.pi * 2
            MARK.cos[i], MARK.sin[i] = math.cos(a), math.sin(a)
        end
    end
    local points = {}
    for i = 0, MARK.segments do
        local sp = Render.WorldToScreen(Vector(spot.x + radius * MARK.cos[i], spot.y + radius * MARK.sin[i], z))
        if sp == nil then return nil end
        points[#points + 1] = sp
    end
    return points
end

local function stroke_ring(points, color, thickness, dashed)
    if not dashed then
        Render.PolyLine(points, color, thickness)
        return
    end
    for i = 1, #points - 1, 2 do
        Render.Line(points[i], points[i + 1], color, thickness)
    end
end

local function item_color(marker, item)
    if MARK.useHero then return item.rec.color end
    return KIND_COLORS[marker.kind]
end

local function lead_color(marker)
    if not MARK.useHero then return KIND_COLORS[marker.kind] end
    for _, item in ipairs(marker.entries) do
        if item.rank == 1 then return item.rec.color end
    end
    return marker.entries[1].rec.color
end

local function draw_ground_ring(marker, z, center, emph)
    local entries = marker.entries
    local dashed = marker.kind == 1
    local lead = lead_color(marker)

    local outer = ring_points(marker, z, MARK.ringRadius)
    if outer == nil then return end

    local count = #entries
    local per = MARK.segments / count
    for i, item in ipairs(entries) do
        local from = math.floor((i - 1) * per) + 1
        local to = i == count and #outer or (math.floor(i * per) + 1)
        local arc = {}
        for j = from, to do arc[#arc + 1] = outer[j] end
        stroke_ring(arc, Ui.fade(item_color(marker, item), 0.95 * emph), 2.5, dashed)
    end

    local inner = ring_points(marker, z, MARK.ringRadius * 0.55)
    if inner ~= nil then
        Render.PolyLine(inner, Ui.fade(lead, 0.3 * emph), 1)
    end
    Render.FilledCircle(center, 2.5, Ui.fade(lead, 0.9 * emph))

    if marker.best then
        local phase = (os.clock() * 0.7) % 1
        local wave = ring_points(marker, z, MARK.ringRadius * (1 + 0.45 * phase))
        if wave ~= nil then
            stroke_ring(wave, Ui.fade(lead, (1 - phase) * 0.6 * emph), 2, dashed)
        end
    end
end

local function draw_badge(anchor, marker, emph, font)
    local colors = Ui.colors
    local ward = image_handle(MARK.wardIcon[marker.kind])

    local parts = {}
    local width = MARK.pad * 2 + (ward ~= nil and (MARK.icon + 4) or 0)
    for i, item in ipairs(marker.entries) do
        local label = tostring(round(item.spot.score * 100)) .. "%"
        local size = Ui.textSize(font, 13, label)
        local unit = item.rec.unit
        local portrait = unit ~= nil and image_handle("panorama/images/heroes/icons/" .. unit .. "_png.vtex_c") or nil
        parts[i] = { label = label, size = size, portrait = portrait, color = item_color(marker, item) }
        width = width + (portrait ~= nil and (MARK.icon + 3) or 9) + size.x + (i > 1 and MARK.gap or 0)
    end

    local x0 = round(anchor.x - width * 0.5)
    local y0 = round(anchor.y - MARK.badgeH)
    local x1, y1 = x0 + round(width), y0 + MARK.badgeH
    local border = (#parts == 1 or not MARK.useHero) and parts[1].color or colors.border

    Render.Shadow(Vec2(x0, y0), Vec2(x1, y1), Ui.fade(colors.shadow, emph), 8, MARK.rounding)
    Render.FilledRect(Vec2(x0, y0), Vec2(x1, y1), Ui.fade(colors.body, emph), MARK.rounding)
    Render.Rect(Vec2(x0, y0), Vec2(x1, y1), Ui.fade(border, 0.9 * emph), MARK.rounding, DRAW_NONE, 1)

    local cx = x0 + MARK.pad
    local cy = y0 + round((MARK.badgeH - MARK.icon) * 0.5)
    local tint = Color(255, 255, 255, round(255 * emph))
    if ward ~= nil then
        Render.Image(ward, Vec2(cx, cy), Vec2(MARK.icon, MARK.icon), tint, 3)
        cx = cx + MARK.icon + 4
    end

    for i, part in ipairs(parts) do
        if i > 1 then cx = cx + MARK.gap end
        if part.portrait ~= nil then
            Render.Image(part.portrait, Vec2(cx, cy), Vec2(MARK.icon, MARK.icon), tint, MARK.icon * 0.5)
            Render.Circle(Vec2(cx + MARK.icon * 0.5, cy + MARK.icon * 0.5), MARK.icon * 0.5, Ui.fade(part.color, emph), 1.5)
            cx = cx + MARK.icon + 3
        else
            Render.FilledCircle(Vec2(cx + 3, y0 + MARK.badgeH * 0.5), 3, Ui.fade(part.color, emph))
            cx = cx + 9
        end
        Render.Text(font, 13, part.label, Vec2(cx, round(y0 + (MARK.badgeH - part.size.y) * 0.5)), Ui.fade(part.color, emph))
        cx = cx + part.size.x
    end
end

local function draw_minimap_marker(marker, emph)
    local flat = Vector(marker.x, marker.y, 0)
    if marker.kind == 0 then
        local lead = lead_color(marker)
        pcall(MiniMap.DrawCircle, flat, lead.r, lead.g, lead.b, round(70 * emph), marker.best and 950 or 700)
    end
    for i, item in ipairs(marker.entries) do
        local c = item_color(marker, item)
        local size = (marker.kind == 0 and (marker.best and 320 or 240) or 520) + 90 * (i - 1)
        pcall(MiniMap.DrawCircle, flat, c.r, c.g, c.b, round((marker.kind == 0 and 235 or 200) * emph), size)
    end
end

local function draw_map_markers()
    if #g_markers == 0 then return end

    local minimap = ui.drawMinimap:Get()
    local world = ui.drawWorld:Get()
    if not minimap and not world then return end

    local font = Ui.panel.font
    MARK.useHero = ui.heroColors == nil or ui.heroColors:Get()
    for _, marker in ipairs(g_markers) do
        local emph = clamp((0.45 + marker.score * 1.4) * (0.6 + 0.4 * marker.reach), 0.35, 1)

        if minimap then draw_minimap_marker(marker, emph) end

        if world and font ~= nil then
            local z = spot_ground(marker)
            local center, visible = Render.WorldToScreen(Vector(marker.x, marker.y, z))
            if center ~= nil and visible ~= false then
                pcall(draw_ground_ring, marker, z, center, emph)
                local top = Vec2(center.x, center.y - MARK.stem)
                pcall(Render.Line, center, top, Ui.fade(lead_color(marker), 0.7 * emph), 1.5)
                pcall(draw_badge, top, marker, emph, font)
            end
        end
    end
end

local function score_string(list)
    if #list == 0 then return "—" end
    local parts = {}
    for _, spot in ipairs(list) do
        parts[#parts + 1] = tostring(round(spot.score * 100)) .. "%"
    end
    return table.concat(parts, " · ")
end

local function build_rows()
    local rows = {}
    local colors = Ui.colors

    if S.phase == "idle" then
        local key = S.waitReason == "no_enemies" and "panel.no_enemies" or "panel.waiting"
        rows[#rows + 1] = { "", T(key), colors.textMuted, "text" }
        return rows
    end
    if S.phase == "probing" then
        rows[#rows + 1] = { "", T("panel.probing"), colors.textMuted, "text" }
        return rows
    end
    if S.phase == "empty" then
        rows[#rows + 1] = { "", T("panel.empty"), colors.bad, "text" }
        rows[#rows + 1] = { "", T("panel.coverage"), colors.textMuted, "text" }
        return rows
    end

    if #g_predictions == 0 then
        rows[#rows + 1] = { "", T("panel.loading"), colors.textMuted, "text" }
        return rows
    end

    local wantSen = ui.showSen:Get()
    for _, rec in ipairs(g_predictions) do
        local head = T("panel.head", tostring(rec.name), math.floor(rec.used or 0), math.floor(rec.events or 0))
        if rec.state == "loading" or rec.state == "queued" or rec.state == "listing" then
            head = head .. T("panel.head_loading")
        end
        rows[#rows + 1] = { "", head, rec.color, "text" }

        if rec.state == "nodata" then
            rows[#rows + 1] = { "", T("panel.no_parsed"), colors.textMuted, "text" }
        else
            rows[#rows + 1] = { T("panel.obs"), score_string(rec.obs), rec.color }
            if wantSen then
                rows[#rows + 1] = { T("panel.sen"), score_string(rec.sen), rec.color }
            end
            if rec.used > 0 and rec.used < 5 then
                rows[#rows + 1] = { "", T("panel.low_data"), colors.textMuted, "text" }
            end
        end
    end

    if S.hitTotal > 0 then
        local acc = round(S.hitOk / S.hitTotal * 100)
        rows[#rows + 1] = {
            T("panel.hits"),
            tostring(S.hitOk) .. "/" .. tostring(S.hitTotal) .. " (" .. tostring(acc) .. "%)",
            acc >= 50 and colors.good or colors.textMuted,
        }
    end

    return rows
end

local function draw_all()
    if not ready or not ui.enabled:Get() then
        Ui.panel.dragging = false
        return
    end

    Ui.refreshTheme()
    pcall(draw_map_markers)

    if not ui.drawPanel:Get() then
        Ui.panel.dragging = false
        return
    end

    local colors = Ui.colors
    local panel = Ui.panel
    local rows = build_rows()

    local scale        = ui.scale:Get() / 100
    local fontSize     = math.max(9, round(13 * scale))
    local titleSize    = math.max(10, round(16 * scale))
    local pinSize      = math.max(10, round(15 * scale))
    local chevronSize  = math.max(9, round(13 * scale))
    local rowHeight    = round(21 * scale)
    local padding      = round(11 * scale)
    local headerHeight = round(26 * scale)
    local bodyGap      = round(6 * scale)
    local rounding     = math.max(3, round(6 * scale))
    local chevronHit   = math.max(7, round(11 * scale))

    local title = "WARD PREDICTOR"
    local titleColor = colors.text

    local pinGlyph = "\u{f3c5}"
    local pinW = panel.iconFont and Ui.textSize(panel.iconFont, pinSize, pinGlyph).x or 0

    local width = round(292 * scale)
    local titleW = Ui.textSize(panel.font, titleSize, title).x
    width = math.max(width, round(titleW + padding * 2 + pinW * 2 + 16 * scale))
    local bodyHeight = padding * 2 + rowHeight * #rows

    panel.open = Ui.ease(panel.open, panel.collapsed and 0 or 1, Ui.speed(1))
    local openT = panel.open
    local ease = openT * openT * (3 - 2 * openT)
    local shown = round(bodyHeight * ease)
    local fade = ease * ease
    local height = headerHeight + (shown > 2 and bodyGap + shown or 0)

    local screen = try(Render.ScreenSize) or Vec2(1920, 1080)
    if panel.x == nil or panel.y == nil then
        panel.x, panel.y = saved_pos()
        if panel.x == nil then
            panel.x = round(screen.x * 0.02)
            panel.y = round(screen.y * 0.42)
        end
    end

    panel.collapseBounds = Ui.setBounds(panel.collapseBounds, panel.x, panel.y, chevronHit * 2 + padding, headerHeight)

    local cursorX, cursorY
    if CAN_DRAG then cursorX, cursorY = IN_CURSOR() end
    if cursorX ~= nil and cursorY ~= nil then
        local mouseDown = IN_DOWN(MOUSE1, true)
        local clickedOnce = IN_ONCE(MOUSE1, true)

        if not panel.dragging and clickedOnce and Ui.pointInside(panel.collapseBounds, cursorX, cursorY) then
            panel.collapsed = not panel.collapsed
        elseif not panel.dragging
            and clickedOnce
            and IN_RECT(panel.x, panel.y, width, headerHeight)
        then
            panel.dragging = true
            panel.dragOffsetX = cursorX - panel.x
            panel.dragOffsetY = cursorY - panel.y
        end

        if panel.dragging then
            if mouseDown then
                panel.x = cursorX - panel.dragOffsetX
                panel.y = cursorY - panel.dragOffsetY
            else
                panel.dragging = false
            end
        end
    end

    panel.x = clamp(panel.x, 0, math.max(0, screen.x - width))
    panel.y = clamp(panel.y, 0, math.max(0, screen.y - height))
    if panel.wasDragging and not panel.dragging then
        save_pos(panel.x, panel.y)
    end
    panel.wasDragging = panel.dragging
    panel.width, panel.height, panel.headerHeight = width, height, headerHeight

    local x, y = round(panel.x), round(panel.y)
    local shadowSize = math.max(6, round(12 * scale))

    pcall(Render.Shadow, Vec2(x, y), Vec2(x + width, y + headerHeight), colors.shadow, shadowSize, rounding)
    pcall(Render.Blur, Vec2(x, y), Vec2(x + width, y + headerHeight), 3, 1, rounding)
    pcall(Render.FilledRect, Vec2(x, y), Vec2(x + width, y + headerHeight), colors.body, rounding)
    pcall(Render.Rect, Vec2(x, y), Vec2(x + width, y + headerHeight), colors.border, rounding, DRAW_NONE, 1)

    local iconY = y + headerHeight * 0.5
    local hoverChevron = cursorX ~= nil and Ui.pointInside(panel.collapseBounds, cursorX, cursorY)
    panel.chevronAnim = Ui.ease(panel.chevronAnim, hoverChevron and 1 or 0, Ui.speed(3))
    local chevronGlyph = panel.collapsed and "\u{f078}" or "\u{f077}"

    if panel.iconFont then
        Ui.drawIcon(chevronSize, chevronGlyph, x + padding + chevronHit, iconY,
            Ui.mix(colors.textMuted, colors.accent, panel.chevronAnim))
        Ui.drawIcon(pinSize, pinGlyph, x + width - padding - chevronHit, iconY, colors.textMuted)
    end
    Ui.drawCentered(titleSize, title, x, y, width, headerHeight, titleColor)

    if shown > 2 then
        local top = y + headerHeight + bodyGap
        local bottom = top + shown

        pcall(Render.Shadow, Vec2(x, top), Vec2(x + width, bottom), Ui.fade(colors.shadow, fade), shadowSize, rounding)
        pcall(Render.Blur, Vec2(x, top), Vec2(x + width, bottom), 3, fade, rounding)
        pcall(Render.FilledRect, Vec2(x, top), Vec2(x + width, bottom), Ui.fade(colors.body, fade), rounding)
        pcall(Render.Rect, Vec2(x, top), Vec2(x + width, bottom), Ui.fade(colors.border, fade), rounding, DRAW_NONE, 1)

        local rowInnerWidth = width - padding * 2
        for i = 1, #rows do
            local rowY = top + padding + (i - 1) * rowHeight
            if rows[i][4] == "text" then
                Ui.drawLine(
                    fontSize,
                    truncate_to_width(panel.font, fontSize, rows[i][2], rowInnerWidth),
                    x + padding,
                    rowY,
                    rowHeight,
                    Ui.fade(rows[i][3], fade)
                )
            else
                local label = rows[i][1]
                local labelW = Ui.textSize(panel.font, fontSize, label).x
                local availW = rowInnerWidth - labelW - round(10 * scale)
                Ui.drawRow(
                    fontSize,
                    label,
                    truncate_to_width(panel.font, fontSize, rows[i][2], availW),
                    x + padding,
                    rowY,
                    rowInnerWidth,
                    rowHeight,
                    Ui.fade(colors.textMuted, fade),
                    Ui.fade(rows[i][3], fade)
                )
            end
        end
    end
end

local g_draw_error = nil

local function draw_error_banner(title, msg)
    local screen = try(Render.ScreenSize) or Vec2(1920, 1080)
    local x, y = round(screen.x * 0.02), round(screen.y * 0.42)
    local w, h = round(screen.x * 0.42), 46
    pcall(Render.FilledRect, Vec2(x, y), Vec2(x + w, y + h), Color(20, 20, 24, 235), 4)
    pcall(Render.Rect, Vec2(x, y), Vec2(x + w, y + h), Color(224, 50, 45, 245), 4, DRAW_NONE, 1)
    local f = Ui.panel.font or try(Render.LoadFont, "Arial", 0, 500)
    pcall(Render.Text, f, 14, tostring(title), Vec2(x + 10, y + 6), Color(224, 50, 45, 245))
    pcall(Render.Text, f, 12, tostring(msg):sub(1, 150), Vec2(x + 10, y + 26), Color(220, 220, 225, 240))
end

local function apply_picker_rows()
    local rows = S.pickerRows
    if rows == nil or ui.supports == nil then return end
    local clock = os.clock()
    if clock < S.pickerApplyAt then return end

    if S.pickerApplied then read_picker_selection() end
    for _, row in ipairs(rows) do
        local acc = S.pickerIds[row[1]]
        if acc ~= nil then row[3] = S.manual[acc] == true end
    end
    pcall(ui.supports.Update, ui.supports, rows, true)
    S.pickerApplied = true

    if S.pickerRetries > 0 then
        S.pickerRetries = S.pickerRetries - 1
        S.pickerApplyAt = clock + 2
    else
        S.pickerRows = nil
    end
end

function script.OnDraw()
    if g_menu_error ~= nil then
        pcall(draw_error_banner, T("panel.menu_failed"), g_menu_error)
        return
    end
    if ready then pcall(apply_picker_rows) end
    local ok, err = pcall(draw_all)
    if ok then
        g_draw_error = nil
        return
    end
    g_draw_error = tostring(err)
    pcall(draw_error_banner, T("panel.draw_error"), g_draw_error)
end

return script
