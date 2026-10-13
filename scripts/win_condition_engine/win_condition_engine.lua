---@diagnostic disable: undefined-global

local script = {}

local function try(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, r = pcall(fn, ...)
    if ok then return r end
    return nil
end

local function pct(cur, max)
    if not cur or not max or max <= 0 then return 0 end
    return cur / max
end

local function dist2d(a, b)
    if not a or not b then return math.huge end
    local dx, dy = (a.x - b.x), (a.y - b.y)
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function round(v) return math.floor(v + 0.5) end

local CFG = {
    reach        = 2500,
    group_radius = 1600,
    isolate_gap  = 2400,
    low_hp       = 0.45,
    low_mana     = 0.25,
    tower_low_hp = 0.35,
    rosh_min_time= 900,
    rosh_kill_seconds = 20,

    rosh_threat_gate = 0.55,

    rosh_support_grace = 18,

    pinned_radius  = 1800,

    siege_radius   = 3000,
    siege_min_enemies = 2,
    pickoff_min_time = 600,

    stage_early_until = 720,
    stage_mid_until   = 1800,

    torm_min_time = 1200,
    torm_reach = 1600,
    torm_reflect_share = 0.45,
    torm_max_kill_seconds = 30,
    torm_hp_margin = 1.35,
}

local function game_stage(t)
    if t < CFG.stage_early_until then return "early" end
    if t < CFG.stage_mid_until then return "mid" end
    return "late"
end

local STAGE_BIAS = {
    early = {
        { obj = "FARM",    pts =  20, reason = "wce.r.stage_early" },
        { obj = "PICKOFF", pts = -18 },
        { obj = "PUSH",    pts = -10 },
        { obj = "ROSHAN",  pts = -60 },
        { obj = "TORMENT", pts = -60 },
        { obj = "FIGHT",   pts =  -8 },
    },
    mid = {
        { obj = "PUSH",    pts =   6 },
        { obj = "PICKOFF", pts =   6 },
    },
    late = {
        { obj = "FARM",    pts = -16, reason = "wce.r.stage_late_farm" },
        { obj = "ROSHAN",  pts =  12, reason = "wce.r.stage_late_aegis" },
        { obj = "TORMENT", pts =   8 },
        { obj = "PUSH",    pts =   8 },
        { obj = "DEFEND",  pts =   6 },
    },
}

local localization = qLocalization.new({
    en = { wce = {
        menu = { column = "Overview", advisor = "Advisor", overlay = "Overlay", enabled = "Enabled", settings = "Settings", refresh = "Refresh", reach = "Reach radius", verbose = "Objective ranking", scale = "Panel size" },
        panel = { status = "Status", menu_failed = "menu failed to create", error = "error", no_data = "no data", waiting = "waiting for the game…", advice = "Advice", stage = "Stage", networth = "Net worth", networth_est = "Net worth (est.)", nw_no_data = "no data %d/%d · %d/%d", overall = "overall assessment", draw_error = "WIN ENGINE: draw error" },
        obj = { FIGHT = "Fight", ROSHAN = "Roshan", PUSH = "Push", FARM = "Farm", PICKOFF = "Pick-off", DEFEND = "Defend", TORMENT = "Tormentor", RESET = "Retreat / regen" },
        stage = { early = "early", mid = "mid", late = "late" },
        wait = { no_hero = "no local hero", teams = "need both teams: allies %d, enemies %d" },
        nw = "%.1fk net worth",
        r = {
            stage_early = "early game — lanes and farm", stage_late_farm = "late game — farm matters less", stage_late_aegis = "late game — Aegis decides",
            fight_more_dead = "%d more enemies dead", ults_ready = "ultimates ready (%d/%d)", stronger = "we are stronger: +%s", grouped = "we are grouped", low_hp = "%d allies low on HP",
            enemy = "enemy", rosh_dead = "%d enemies dead", rosh_ok_weak = "we have time: only %s (weak) respawns", rosh_ok_window = "we have time: %d enemies dead, %ds window",
            rosh_low_dmg = "not enough damage: ~%d%% before %s returns", rosh_dead_window = "%d enemies dead (%ds window)", rosh_too_slow = "no time: %s respawns in %ds, need ~%ds",
            spells_ready = "spells ready", core_near = "core nearby (%s)", together = "team together",
            rosh_sieged = "enemies in our base (%d) — no time for Roshan", rosh_pinned = "%d enemies nearby — we're held, can't go Roshan",
            summons_soak = "%d summons will soak the reflect", torm_ok = "enough power: %d heroes, ~%ds", torm_low_hp = "not enough HP for the reflect: %.1fk of ~%.1fk", torm_slow = "too slow: ~%ds",
            enemies_dead = "%d enemies dead", base_enemies = "enemies in our base", enemies_near = "%d enemies nearby",
            tower_low = "tower low (%d%%)", push_window = "push window: %d enemies dead", long_respawn = "long enemy respawn (%ds)", ahead = "we're ahead, pressure the map", lift_siege = "clear the siege on our base first",
            no_adv = "no advantage — farm and level up", behind_farm = "behind: -%s — need farm", spread = "team spread across the map",
            isolated = "%s is cut off from the team", isolated_hp = "and at %d%% HP", can_kill = "we have the damage to kill",
            man_down = "we're down players (%d)", behind_defend = "behind — play defensively", battered = "team is battered", hold_hg = "%d enemies in our base — hold high ground",
            no_resources = "%d allies out of resources — regen", ults_cd = "ultimates on cooldown",
        },
    } },
    ru = { wce = {
        menu = { column = "Обзор", advisor = "Советник", overlay = "Оверлей", enabled = "Включён", settings = "Настройки", refresh = "Пересчёт", reach = "Радиус досягаемости", verbose = "Рейтинг целей", scale = "Размер панели" },
        panel = { status = "Статус", menu_failed = "меню не создалось", error = "ошибка", no_data = "нет данных", waiting = "жду начала игры…", advice = "Совет", stage = "Стадия", networth = "Нетворс", networth_est = "Нетворс (пред.)", nw_no_data = "нет данных %d/%d · %d/%d", overall = "по совокупности факторов", draw_error = "WIN ENGINE: ошибка отрисовки" },
        obj = { FIGHT = "Файт", ROSHAN = "Рошан", PUSH = "Пуш", FARM = "Фарм", PICKOFF = "Пик-офф", DEFEND = "Защита", TORMENT = "Терзатель", RESET = "Отступить / реген" },
        stage = { early = "ранняя", mid = "средняя", late = "поздняя" },
        wait = { no_hero = "нет своего героя", teams = "нужны обе команды: своих %d, врагов %d" },
        nw = "%.1fk нетворс",
        r = {
            stage_early = "ранняя стадия — лайны и фарм", stage_late_farm = "поздняя стадия — фарм уже мало решает", stage_late_aegis = "лейт — аегис решает",
            fight_more_dead = "врагов мертво больше на %d", ults_ready = "ульты готовы (%d/%d)", stronger = "мы сильнее: +%s", grouped = "мы сгруппированы", low_hp = "%d союзника на низком хп",
            enemy = "враг", rosh_dead = "%d врагов мертвы", rosh_ok_weak = "успеваем: из таверны только %s (слабый)", rosh_ok_window = "успеваем: %d врагов в таверне, окно %dс",
            rosh_low_dmg = "не хватит урона: снимем ~%d%% до возврата %s", rosh_dead_window = "%d врагов мертвы (окно %dс)", rosh_too_slow = "не успеваем: %s встанет через %dс, нужно ~%dс",
            spells_ready = "кнопки готовы", core_near = "кор рядом (%s)", together = "команда вместе",
            rosh_sieged = "враги на нашей базе (%d) — не до рошана", rosh_pinned = "рядом %d врагов — нас держат, не уйти на рошана",
            summons_soak = "%d суммонов примут отдачу", torm_ok = "хватит сил: %d героев, ~%dс", torm_low_hp = "мало хп на отдачу: %.1fk из ~%.1fk", torm_slow = "слишком долго: ~%dс",
            enemies_dead = "врагов мертво %d", base_enemies = "враги на нашей базе", enemies_near = "рядом %d врагов",
            tower_low = "вышка на добивание (%d%%)", push_window = "окно для пуша: врагов мертво %d", long_respawn = "долгий реген у врага (%dс)", ahead = "мы впереди, давим карту", lift_siege = "сначала снять осаду со своей базы",
            no_adv = "перевеса нет — фармим и качаемся", behind_farm = "отстаём: -%s — нужен фарм", spread = "команда раскидана по карте",
            isolated = "%s оторван от команды", isolated_hp = "и на %d%% хп", can_kill = "есть чем убить",
            man_down = "мы в минусе по игрокам (%d)", behind_defend = "отстаём — играем от обороны", battered = "команда потрёпана", hold_hg = "%d врагов на нашей базе — держим хайграунд",
            no_resources = "%d союзников без ресурсов — на реген", ults_cd = "ульты на кд",
        },
    } },
    cn = { wce = {
        menu = { column = "概览", advisor = "顾问", overlay = "界面", enabled = "启用", settings = "设置", refresh = "刷新间隔", reach = "作用半径", verbose = "目标排名", scale = "面板大小" },
        panel = { status = "状态", menu_failed = "菜单创建失败", error = "错误", no_data = "无数据", waiting = "等待游戏开始…", advice = "建议", stage = "阶段", networth = "经济", networth_est = "经济（估算）", nw_no_data = "无数据 %d/%d · %d/%d", overall = "综合判断", draw_error = "WIN ENGINE: 绘制错误" },
        obj = { FIGHT = "团战", ROSHAN = "肉山", PUSH = "推进", FARM = "发育", PICKOFF = "抓人", DEFEND = "防守", TORMENT = "痛苦魔方", RESET = "撤退 / 回复" },
        stage = { early = "前期", mid = "中期", late = "后期" },
        wait = { no_hero = "没有本地英雄", teams = "需要双方队伍：友方%d，敌方%d" },
        nw = "%.1fk 经济",
        r = {
            stage_early = "前期——对线发育", stage_late_farm = "后期——发育不再关键", stage_late_aegis = "后期——不朽之守护是关键",
            fight_more_dead = "敌方多阵亡%d人", ults_ready = "大招就绪（%d/%d）", stronger = "我方更强：+%s", grouped = "我方已集结", low_hp = "%d名友方残血",
            enemy = "敌人", rosh_dead = "%d名敌人阵亡", rosh_ok_weak = "来得及：只有%s（弱）复活", rosh_ok_window = "来得及：%d名敌人阵亡，窗口%d秒",
            rosh_low_dmg = "伤害不足：只能打掉约%d%%，%s即将复活", rosh_dead_window = "%d名敌人阵亡（窗口%d秒）", rosh_too_slow = "来不及：%s将在%d秒后复活，需要约%d秒",
            spells_ready = "技能就绪", core_near = "核心在附近（%s）", together = "队伍在一起",
            rosh_sieged = "敌人在我方基地（%d）——无暇打肉山", rosh_pinned = "附近有%d名敌人——被牵制，无法去打肉山",
            summons_soak = "%d个召唤物承受反伤", torm_ok = "实力足够：%d名英雄，约%d秒", torm_low_hp = "承受反伤的生命不足：%.1fk / 约%.1fk", torm_slow = "太慢：约%d秒",
            enemies_dead = "敌方阵亡%d人", base_enemies = "敌人在我方基地", enemies_near = "附近有%d名敌人",
            tower_low = "防御塔残血（%d%%）", push_window = "推进窗口：敌方阵亡%d人", long_respawn = "敌方复活时间长（%d秒）", ahead = "我方领先，压制地图", lift_siege = "先解除基地之围",
            no_adv = "没有优势——发育升级", behind_farm = "落后：-%s——需要发育", spread = "队伍分散在地图各处",
            isolated = "%s脱离了队伍", isolated_hp = "且只剩%d%%生命", can_kill = "有能力击杀",
            man_down = "我方人数劣势（%d）", behind_defend = "落后——防守为主", battered = "队伍状态不佳", hold_hg = "%d名敌人在我方基地——守住高地",
            no_resources = "%d名友方资源耗尽——回复", ults_cd = "大招冷却中",
        },
    } },
    es = { wce = {
        menu = { column = "Resumen", advisor = "Asesor", overlay = "Superposición", enabled = "Activado", settings = "Ajustes", refresh = "Recalcular", reach = "Radio de alcance", verbose = "Ranking de objetivos", scale = "Tamaño del panel" },
        panel = { status = "Estado", menu_failed = "no se creó el menú", error = "error", no_data = "sin datos", waiting = "esperando la partida…", advice = "Consejo", stage = "Fase", networth = "Patrimonio", networth_est = "Patrimonio (est.)", nw_no_data = "sin datos %d/%d · %d/%d", overall = "evaluación general", draw_error = "WIN ENGINE: error de dibujo" },
        obj = { FIGHT = "Pelea", ROSHAN = "Roshan", PUSH = "Pushear", FARM = "Farmear", PICKOFF = "Cazar", DEFEND = "Defender", TORMENT = "Atormentador", RESET = "Retirarse / regenerar" },
        stage = { early = "temprana", mid = "media", late = "tardía" },
        wait = { no_hero = "sin héroe propio", teams = "se necesitan ambos equipos: aliados %d, enemigos %d" },
        nw = "%.1fk de patrimonio",
        r = {
            stage_early = "fase temprana — líneas y farmeo", stage_late_farm = "fase tardía — el farmeo ya importa poco", stage_late_aegis = "fase tardía — el Aegis decide",
            fight_more_dead = "%d enemigos más muertos", ults_ready = "ultis listas (%d/%d)", stronger = "somos más fuertes: +%s", grouped = "estamos agrupados", low_hp = "%d aliados con poca vida",
            enemy = "enemigo", rosh_dead = "%d enemigos muertos", rosh_ok_weak = "llegamos: solo revive %s (débil)", rosh_ok_window = "llegamos: %d enemigos muertos, ventana de %ds",
            rosh_low_dmg = "daño insuficiente: ~%d%% antes de que vuelva %s", rosh_dead_window = "%d enemigos muertos (ventana de %ds)", rosh_too_slow = "no llegamos: %s revive en %ds, hacen falta ~%ds",
            spells_ready = "habilidades listas", core_near = "core cerca (%s)", together = "equipo junto",
            rosh_sieged = "enemigos en nuestra base (%d) — no hay tiempo para Roshan", rosh_pinned = "%d enemigos cerca — nos retienen, no se puede ir a Roshan",
            summons_soak = "%d invocaciones absorberán el reflejo", torm_ok = "hay fuerza: %d héroes, ~%ds", torm_low_hp = "poca vida para el reflejo: %.1fk de ~%.1fk", torm_slow = "demasiado lento: ~%ds",
            enemies_dead = "%d enemigos muertos", base_enemies = "enemigos en nuestra base", enemies_near = "%d enemigos cerca",
            tower_low = "torre baja (%d%%)", push_window = "ventana para pushear: %d enemigos muertos", long_respawn = "reaparición enemiga larga (%ds)", ahead = "vamos por delante, presiona el mapa", lift_siege = "primero rompe el asedio de nuestra base",
            no_adv = "sin ventaja — farmea y sube de nivel", behind_farm = "vamos por detrás: -%s — hace falta farmear", spread = "equipo disperso por el mapa",
            isolated = "%s está aislado del equipo", isolated_hp = "y con %d%% de vida", can_kill = "tenemos con qué matar",
            man_down = "tenemos menos jugadores (%d)", behind_defend = "vamos por detrás — juega a la defensiva", battered = "equipo desgastado", hold_hg = "%d enemigos en nuestra base — defiende la parte alta",
            no_resources = "%d aliados sin recursos — a regenerar", ults_cd = "ultis en enfriamiento",
        },
    } },
    pt = { wce = {
        menu = { column = "Resumo", advisor = "Conselheiro", overlay = "Sobreposição", enabled = "Ativado", settings = "Configurações", refresh = "Recalcular", reach = "Raio de alcance", verbose = "Ranking de objetivos", scale = "Tamanho do painel" },
        panel = { status = "Status", menu_failed = "o menu não foi criado", error = "erro", no_data = "sem dados", waiting = "aguardando a partida…", advice = "Conselho", stage = "Fase", networth = "Patrimônio", networth_est = "Patrimônio (est.)", nw_no_data = "sem dados %d/%d · %d/%d", overall = "avaliação geral", draw_error = "WIN ENGINE: erro de desenho" },
        obj = { FIGHT = "Luta", ROSHAN = "Roshan", PUSH = "Push", FARM = "Farmar", PICKOFF = "Caçar", DEFEND = "Defender", TORMENT = "Atormentador", RESET = "Recuar / regenerar" },
        stage = { early = "inicial", mid = "meio", late = "final" },
        wait = { no_hero = "sem herói próprio", teams = "precisa das duas equipes: aliados %d, inimigos %d" },
        nw = "%.1fk de patrimônio",
        r = {
            stage_early = "início de jogo — lanes e farm", stage_late_farm = "fim de jogo — farm já pesa pouco", stage_late_aegis = "fim de jogo — o Aegis decide",
            fight_more_dead = "%d inimigos a mais mortos", ults_ready = "ultimates prontas (%d/%d)", stronger = "estamos mais fortes: +%s", grouped = "estamos agrupados", low_hp = "%d aliados com pouca vida",
            enemy = "inimigo", rosh_dead = "%d inimigos mortos", rosh_ok_weak = "dá tempo: só %s (fraco) renasce", rosh_ok_window = "dá tempo: %d inimigos mortos, janela de %ds",
            rosh_low_dmg = "dano insuficiente: ~%d%% antes de %s voltar", rosh_dead_window = "%d inimigos mortos (janela de %ds)", rosh_too_slow = "não dá tempo: %s renasce em %ds, precisa ~%ds",
            spells_ready = "habilidades prontas", core_near = "core por perto (%s)", together = "time junto",
            rosh_sieged = "inimigos na nossa base (%d) — sem tempo para Roshan", rosh_pinned = "%d inimigos por perto — estamos presos, sem ir ao Roshan",
            summons_soak = "%d invocações vão absorver o reflexo", torm_ok = "força suficiente: %d heróis, ~%ds", torm_low_hp = "pouca vida para o reflexo: %.1fk de ~%.1fk", torm_slow = "lento demais: ~%ds",
            enemies_dead = "%d inimigos mortos", base_enemies = "inimigos na nossa base", enemies_near = "%d inimigos por perto",
            tower_low = "torre baixa (%d%%)", push_window = "janela de push: %d inimigos mortos", long_respawn = "renascimento inimigo longo (%ds)", ahead = "estamos na frente, pressione o mapa", lift_siege = "primeiro quebre o cerco da nossa base",
            no_adv = "sem vantagem — farme e suba de nível", behind_farm = "atrás: -%s — precisa farmar", spread = "time espalhado pelo mapa",
            isolated = "%s está isolado do time", isolated_hp = "e com %d%% de vida", can_kill = "temos como matar",
            man_down = "estamos com menos jogadores (%d)", behind_defend = "atrás — jogue na defesa", battered = "time desgastado", hold_hg = "%d inimigos na nossa base — segure o high ground",
            no_resources = "%d aliados sem recursos — regenerar", ults_cd = "ultimates em recarga",
        },
    } },
})

local Menu = localization.WrapLibrary(Menu)

local function T(key, ...)
    local s = localization.Get(key)
    if select("#", ...) == 0 then return s end
    return s:format(...)
end

local ui    = {}
local ready = false
local g_menu_error = nil

local ENUM = type(Enum) == "table" and Enum or {}
local DRAW_NONE = (ENUM.DrawFlags and ENUM.DrawFlags.None) or 0
local MOUSE1 = ENUM.ButtonCode and ENUM.ButtonCode.KEY_MOUSE1 or nil
local FONT_AA = ENUM.FontCreate and ENUM.FontCreate.FONTFLAG_ANTIALIAS or 0

local function api(tbl, name)
    return type(tbl) == "table" and type(tbl[name]) == "function" and tbl[name] or nil
end

local IN_CURSOR = api(Input, "GetCursorPos")
local IN_DOWN   = api(Input, "IsKeyDown")
local IN_ONCE   = api(Input, "IsKeyDownOnce")
local IN_RECT   = api(Input, "IsCursorInRect")
local CAN_DRAG  = IN_CURSOR and IN_DOWN and IN_ONCE and IN_RECT and MOUSE1 ~= nil

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

Ui.campPanelRound = round

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

function Ui.campPanelPointInside(bounds, cursorX, cursorY)
    return bounds ~= nil
        and cursorX >= bounds.x
        and cursorX <= bounds.x + bounds.width
        and cursorY >= bounds.y
        and cursorY <= bounds.y + bounds.height
end

function Ui.campPanelStyle(name, fallback)
    if not Ui.panel.styleOk then return fallback end
    local color = Menu.Style(name)
    if color == nil or color.r == nil then return fallback end
    return color
end

function Ui.campPanelSpeed(multiplier)
    if not Ui.panel.animFound then
        Ui.panel.animFound = true
        Ui.panel.animWidget = try(Menu.Find, "SettingsHidden", "", "", "", "Main", "Animation Duration")
    end
    local duration = Ui.panel.animWidget ~= nil and try(Ui.panel.animWidget.Get, Ui.panel.animWidget) or 50
    return multiplier * 1000 / clamp(duration or 50, 10, 1000)
end

function Ui.refreshCampPanelTheme()
    local frame = try(GlobalVars.GetFrameCount)
    if frame ~= nil and frame == Ui.panel.themeFrame then return end
    Ui.panel.themeFrame = frame

    Ui.colors = {
        body      = Ui.campPanelStyle("main_background", Color(24, 24, 27, 235)),
        plate     = Ui.campPanelStyle("group_background", Color(37, 37, 42, 235)),
        border    = Ui.campPanelStyle("outline", Color(48, 48, 55, 180)),
        accent    = Ui.campPanelStyle("primary", Color(214, 58, 50, 250)),
        text      = Ui.campPanelStyle("primary_widgets_text", Color(238, 238, 242, 250)),
        textMuted = Ui.campPanelStyle("third_tab_text", Color(146, 146, 156, 210)),
        enabled   = Ui.campPanelStyle("multiselect_item_selected", Color(63, 191, 95, 245)),
        disabled  = Ui.campPanelStyle("multiselect_item", Color(224, 50, 45, 245)),
        shadow    = Color(0, 0, 0, 130),
        hole      = Color(0, 0, 0, 110),
    }
end

function Ui.campPanelEase(current, goal, speed)
    local dt = try(GlobalVars.GetAbsFrameTime) or 0
    if dt <= 0 or dt > 0.2 then return goal end
    return current + (goal - current) * math.min(1, dt * speed)
end

function Ui.campPanelFade(color, alpha)
    return Color(color.r, color.g, color.b, Ui.campPanelRound(color.a * alpha))
end

function Ui.campPanelMix(from, to, t)
    return Color(
        Ui.campPanelRound(from.r + (to.r - from.r) * t),
        Ui.campPanelRound(from.g + (to.g - from.g) * t),
        Ui.campPanelRound(from.b + (to.b - from.b) * t),
        Ui.campPanelRound(from.a + (to.a - from.a) * t)
    )
end

function Ui.drawCampPanelIcon(fontSize, glyph, centerX, centerY, color)
    local size = Ui.textSize(Ui.panel.iconFont, fontSize, glyph)
    pcall(Render.Text, Ui.panel.iconFont, fontSize, glyph,
        Vec2(Ui.campPanelRound(centerX - size.x * 0.5), Ui.campPanelRound(centerY - size.y * 0.5)), color)
    return size
end

function Ui.drawCampPanelCenteredText(fontSize, text, x, y, width, height, color)
    local textSize = Ui.textSize(Ui.panel.font, fontSize, text)
    pcall(Render.Text, Ui.panel.font, fontSize, text,
        Vec2(Ui.campPanelRound(x + (width - textSize.x) * 0.5), Ui.campPanelRound(y + (height - textSize.y) * 0.5)), color)
end

function Ui.drawCampPanelRow(fontSize, label, value, x, y, width, height, labelColor, valueColor)
    local labelSize = Ui.textSize(Ui.panel.font, fontSize, label)
    local valueSize = Ui.textSize(Ui.panel.font, fontSize, value)
    local textY = Ui.campPanelRound(y + (height - labelSize.y) * 0.5)
    pcall(Render.Text, Ui.panel.font, fontSize, label, Vec2(x, textY), labelColor)
    pcall(Render.Text, Ui.panel.font, fontSize, value,
        Vec2(Ui.campPanelRound(x + width - valueSize.x), textY), valueColor)
end

function Ui.drawPanelTextLine(fontSize, text, x, y, height, color)
    local size = Ui.textSize(Ui.panel.font, fontSize, text)
    pcall(Render.Text, Ui.panel.font, fontSize, text,
        Vec2(x, Ui.campPanelRound(y + (height - size.y) * 0.5)), color)
end

local function get_team(ent)
    return try(Entity.GetTeamNum, ent)
end

local TEAM_RADIANT = (ENUM.TeamNum and ENUM.TeamNum.TEAM_RADIANT) or 2
local TEAM_DIRE = (ENUM.TeamNum and ENUM.TeamNum.TEAM_DIRE) or 3


local function hero_pid(hero)
    local pid = try(Hero.GetPlayerID, hero)
    if type(pid) == "number" and pid >= 0 then return pid end
    return nil
end

local NW_SLOTS = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 16 }

local function item_networth(hero)
    local total = 0
    for _, slot in ipairs(NW_SLOTS) do
        local item = try(NPC.GetItemByIndex, hero, slot)
        if item then
            local cost = try(Item.GetCost, item)
            if type(cost) == "number" and cost > 0 then
                local charges = try(Item.GetCurrentCharges, item)
                if try(Item.IsStackable, item) and type(charges) == "number" and charges > 1 then
                    total = total + cost * charges
                else
                    total = total + cost
                end
            end
        end
    end
    return total
end

local nw_seen = {}

local function hero_item_value(hero)
    local idx = try(Entity.GetIndex, hero)
    if idx and try(Entity.IsDormant, hero) and nw_seen[idx] then
        return nw_seen[idx]
    end
    local value = item_networth(hero)
    if idx then nw_seen[idx] = value end
    return value
end

local function read_player_networth(myTeam)
    local ours, theirs, byHero = { sum = 0, n = 0 }, { sum = 0, n = 0 }, {}
    for _, p in pairs(try(Players.GetAll) or {}) do
        local team = try(Entity.GetTeamNum, p)
        local hero = (team == TEAM_RADIANT or team == TEAM_DIRE) and try(Player.GetAssignedHero, p)
        if hero then
            local nw = hero_item_value(hero)
            local bucket = team == myTeam and ours or theirs
            bucket.sum = bucket.sum + nw
            bucket.n = bucket.n + 1
            local idx = try(Entity.GetIndex, hero)
            if idx then byHero[idx] = nw end
        end
    end
    return ours, theirs, byHero
end

local function ult_status(hero)
    local has, ready_ = false, false
    for i = 0, 30 do
        local ab = try(NPC.GetAbilityByIndex, hero, i)
        if ab and try(Ability.IsUltimate, ab) then
            local lvl = try(Ability.GetLevel, ab) or 0
            if lvl > 0 then
                has = true

                if try(Ability.IsReady, ab) then ready_ = true end
            end
        end
    end
    return has, ready_
end

local function hero_dps(h)
    local dmgMin = try(NPC.GetTrueDamage, h)
    local aps    = try(NPC.GetAttacksPerSecond, h)
    if type(dmgMin) ~= "number" or type(aps) ~= "number" or aps <= 0 then return nil end
    local dmgMax = try(NPC.GetTrueMaximumDamage, h)
    local avg = (type(dmgMax) == "number" and dmgMax > dmgMin) and ((dmgMin + dmgMax) / 2) or dmgMin
    if avg <= 0 then return nil end
    return avg * aps
end

local function bkb_ready(hero)
    local it = try(NPC.GetItem, hero, "item_black_king_bar")
    if it and try(Ability.IsReady, it) then return true end
    return false
end

local function pretty_name(unit)
    local n = try(NPC.GetUnitName, unit) or "unit"
    n = n:gsub("^npc_dota_hero_", ""):gsub("^npc_dota_", "")
    n = n:gsub("_", " ")
    return (n:gsub("^%l", string.upper))
end

local function boss_info(npc, useRoshanFallback)
    local hpAbs = try(Entity.GetHealth, npc)
    if useRoshanFallback and (type(hpAbs) ~= "number" or hpAbs <= 0) then
        hpAbs = try(Entity.GetRoshanHealth)
    end
    if type(hpAbs) ~= "number" or hpAbs <= 0 then
        hpAbs = try(Entity.GetMaxHealth, npc)
    end
    return {
        unit  = npc,
        alive = try(Entity.IsAlive, npc) and true or false,
        pos   = try(Entity.GetAbsOrigin, npc),
        hp    = pct(try(Entity.GetHealth, npc), try(Entity.GetMaxHealth, npc)),
        hpAbs = type(hpAbs) == "number" and hpAbs or nil,
        armorMult = try(NPC.GetArmorDamageMultiplier, npc),
    }
end

local function is_ally_summon(npc, myTeam)
    if get_team(npc) ~= myTeam then return false end
    if not try(Entity.IsAlive, npc) then return false end
    if try(NPC.IsHero, npc) then return false end
    if try(NPC.IsLaneCreep, npc) or try(NPC.IsNeutral, npc) then return false end
    if try(NPC.IsStructure, npc) or try(NPC.IsTower, npc) then return false end
    if try(NPC.IsBarracks, npc) or try(NPC.IsFort, npc) then return false end
    if try(NPC.IsCourier, npc) or try(NPC.IsWard, npc) then return false end
    if try(NPC.IsRoshan, npc) or try(NPC.IsTormentor, npc) or try(NPC.IsBoss, npc) then return false end
    return true
end

local function scan_world(myTeam)
    local roshan, myFort = nil, nil
    local tormentors, summons = {}, {}
    local list = try(NPCs.GetAll) or {}
    for _, npc in pairs(list) do
        if roshan == nil and try(NPC.IsRoshan, npc) then
            roshan = boss_info(npc, true)
        elseif try(NPC.IsTormentor, npc) then
            tormentors[#tormentors + 1] = boss_info(npc, false)
        elseif myFort == nil and try(NPC.IsFort, npc) and get_team(npc) == myTeam then
            myFort = { unit = npc, pos = try(Entity.GetAbsOrigin, npc) }
        elseif is_ally_summon(npc, myTeam) then
            local dps = hero_dps(npc)
            if dps then
                summons[#summons + 1] = {
                    unit = npc,
                    pos  = try(Entity.GetAbsOrigin, npc),
                    hp   = try(Entity.GetHealth, npc) or 0,
                    dps  = dps,
                    name = pretty_name(npc),
                }
            end
        end
    end
    return roshan, myFort, tormentors, summons
end

local function nearest_tormentor(tormentors, centroid)
    local best, bestDist = nil, math.huge
    for _, t in pairs(tormentors or {}) do
        if t.alive and t.pos then
            local d = centroid and dist2d(t.pos, centroid) or 0
            if d < bestDist then best, bestDist = t, d end
        end
    end
    return best
end

local function collect_state()
    local me = try(Heroes.GetLocal)
    if not me then return nil, T("wce.wait.no_hero") end
    local myTeam = get_team(me)
    local nwOurs, nwTheirs, nwByHero = read_player_networth(myTeam)

    local heroes = try(Heroes.GetAll) or {}
    local allies, enemies = {}, {}

    for _, h in pairs(heroes) do
        if h and not try(NPC.IsIllusion, h) and not try(NPC.IsMeepoClone, h) then
            local hasUlt, ultReady = ult_status(h)
            local info = {
                unit    = h,
                pid     = hero_pid(h),
                name    = pretty_name(h),
                alive   = try(Entity.IsAlive, h) and true or false,
                hp      = try(Entity.GetHealth, h) or 0,
                hpPct   = pct(try(Entity.GetHealth, h), try(Entity.GetMaxHealth, h)),
                manaPct = pct(try(NPC.GetMana, h), try(NPC.GetMaxMana, h)),
                pos     = try(Entity.GetAbsOrigin, h),
                level   = try(NPC.GetCurrentLevel, h) or 0,
                hasUlt  = hasUlt,
                ultReady= ultReady,
                bkb     = bkb_ready(h),
                nw      = nwByHero[try(Entity.GetIndex, h) or -1],
                nwItems = item_networth(h),
                speed   = try(NPC.GetMoveSpeed, h) or 300,
                dps     = hero_dps(h),
                respawn = 0,
            }
            if not info.alive then
                info.respawn = try(Hero.GetRespawnTime, h) or 0
            end
            local team = get_team(h)
            if team ~= nil and myTeam ~= nil then
                if team == myTeam then allies[#allies + 1] = info
                else enemies[#enemies + 1] = info end
            end
        end
    end

    if #allies == 0 or #enemies == 0 then
        return nil, T("wce.wait.teams", #allies, #enemies)
    end

    local function summarize(list)
        local s = { alive = 0, dead = 0, ultReady = 0, levelSum = 0,
                    nwSum = 0, nwCount = 0, nwKnown = false,
                    itemSum = 0, itemCount = 0, itemKnown = false,
                    count = 0, maxRespawn = 0, lowHp = 0 }
        local seenPid, seenItemPid = {}, {}
        for _, u in pairs(list) do
            s.count = s.count + 1
            s.levelSum = s.levelSum + u.level
            if u.nw and not (u.pid and seenPid[u.pid]) then
                if u.pid then seenPid[u.pid] = true end
                s.nwSum = s.nwSum + u.nw
                s.nwCount = s.nwCount + 1
            end
            if u.nwItems and not (u.pid and seenItemPid[u.pid]) then
                if u.pid then seenItemPid[u.pid] = true end
                s.itemSum = s.itemSum + u.nwItems
                s.itemCount = s.itemCount + 1
            end
            if u.alive then
                s.alive = s.alive + 1
                if u.ultReady then s.ultReady = s.ultReady + 1 end
                if u.hpPct > 0 and u.hpPct < CFG.low_hp then s.lowHp = s.lowHp + 1 end
            else
                s.dead = s.dead + 1
                if u.respawn > s.maxRespawn then s.maxRespawn = u.respawn end
            end
        end

        s.nwKnown = s.count > 0 and s.nwCount == s.count
        s.itemKnown = s.count > 0 and s.itemCount == s.count
        return s
    end

    local A = summarize(allies)
    local E = summarize(enemies)

    local cx, cy, n = 0, 0, 0
    for _, u in pairs(allies) do
        if u.alive and u.pos then cx = cx + u.pos.x; cy = cy + u.pos.y; n = n + 1 end
    end
    local centroid = n > 0 and { x = cx / n, y = cy / n } or nil
    local grouped = 0
    if centroid then
        for _, u in pairs(allies) do
            if u.alive and u.pos and dist2d(u.pos, centroid) <= CFG.group_radius then
                grouped = grouped + 1
            end
        end
    end

    local core = nil
    for _, u in pairs(allies) do
        if u.alive and (not core or u.level > core.level) then core = u end
    end

    local reach = ui.reach:Get()
    local isolated = nil
    for _, e in pairs(enemies) do
        if e.alive and e.pos then
            local nearestAlly = math.huge
            for _, o in pairs(enemies) do
                if o ~= e and o.alive and o.pos then
                    nearestAlly = math.min(nearestAlly, dist2d(e.pos, o.pos))
                end
            end
            local toUs = centroid and dist2d(e.pos, centroid) or math.huge
            if nearestAlly >= CFG.isolate_gap and toUs <= reach then
                if not isolated or e.hpPct < isolated.hpPct then isolated = e end
            end
        end
    end

    local towerTarget = nil
    for _, t in pairs(try(Towers.GetAll) or {}) do
        local tteam = get_team(t)
        if tteam ~= nil and tteam ~= myTeam and try(Entity.IsAlive, t) then
            local hpp = pct(try(Entity.GetHealth, t), try(Entity.GetMaxHealth, t))
            local tpos = try(Entity.GetAbsOrigin, t)
            local near = centroid and tpos and dist2d(tpos, centroid) <= reach
            if hpp > 0 and hpp < CFG.tower_low_hp and near then
                if not towerTarget or hpp < towerTarget.hp then
                    towerTarget = { hp = hpp, pos = tpos }
                end
            end
        end
    end

    local roshan, myFort, tormentors, summons = scan_world(myTeam)
    local tormentor = nearest_tormentor(tormentors, centroid)

    local maxNw, maxLevel, maxDps = 0, 0, 0
    for _, e in pairs(enemies) do
        if e.nw and e.nw > maxNw then maxNw = e.nw end
        if e.level > maxLevel then maxLevel = e.level end
        if e.dps and e.dps > maxDps then maxDps = e.dps end
    end
    for _, e in pairs(enemies) do
        if E.nwKnown and maxNw > 0 and e.nw then
            e.threat = clamp(e.nw / maxNw, 0, 1)
        elseif maxDps > 0 and e.dps then
            e.threat = clamp(e.dps / maxDps, 0, 1)
        elseif maxLevel > 0 then
            e.threat = clamp(e.level / maxLevel, 0, 1)
        else
            e.threat = 1
        end
    end

    local roshWindow, roshBlocker = nil, nil
    for _, e in pairs(enemies) do
        if not e.alive and (e.respawn or 0) > 0 then
            local deadline = e.respawn
            if (e.threat or 1) < CFG.rosh_threat_gate then
                deadline = deadline + CFG.rosh_support_grace
            end
            if roshWindow == nil or deadline < roshWindow then
                roshWindow = deadline
                roshBlocker = e
            end
        end
    end

    local enemiesNearUs = 0
    if centroid then
        for _, e in pairs(enemies) do
            if e.alive and e.pos and dist2d(e.pos, centroid) <= CFG.pinned_radius then
                enemiesNearUs = enemiesNearUs + 1
            end
        end
    end

    local enemiesAtOurBase = 0
    if myFort and myFort.pos then
        for _, e in pairs(enemies) do
            if e.alive and e.pos and dist2d(e.pos, myFort.pos) <= CFG.siege_radius then
                enemiesAtOurBase = enemiesAtOurBase + 1
            end
        end
    end

    local roshTravel = nil
    if roshan and roshan.pos and centroid then
        local speed = (core and core.speed and core.speed > 0) and core.speed or 300
        roshTravel = dist2d(centroid, roshan.pos) / speed
    end

    return {
        allies = allies, enemies = enemies,
        A = A, E = E,
        manAdv = E.dead - A.dead,
        centroid = centroid, grouped = grouped, groupedFrac = A.alive > 0 and grouped / A.alive or 0,
        core = core, reach = reach,
        isolated = isolated, towerTarget = towerTarget,
        roshan = roshan,
        myFort = myFort,
        tormentor = tormentor,
        summons = summons,
        nwPlayers = { ours = nwOurs, theirs = nwTheirs },
        enemiesNearUs = enemiesNearUs,
        enemiesAtOurBase = enemiesAtOurBase,
        sieged = enemiesAtOurBase >= CFG.siege_min_enemies,
        roshTravel = roshTravel,
        roshWindow = roshWindow,
        roshBlocker = roshBlocker,
        stage = game_stage(try(GameRules.GetGameTime) or try(GlobalVars.GetCurTime) or 0),
        time = try(GameRules.GetGameTime) or try(GlobalVars.GetCurTime) or 0,
    }
end

local OBJ = { "FIGHT", "ROSHAN", "TORMENT", "PUSH", "FARM", "PICKOFF", "DEFEND", "RESET" }
local LABEL = setmetatable({}, { __index = function(_, key) return T("wce.obj." .. tostring(key)) end })

local OBJ_COLOR = {
    FIGHT   = function() return Color(255, 90, 90) end,
    ROSHAN  = function() return Color(255, 180, 60) end,
    PUSH    = function() return Color(120, 200, 255) end,
    FARM    = function() return Color(140, 230, 140) end,
    PICKOFF = function() return Color(230, 150, 255) end,
    DEFEND  = function() return Color(255, 230, 120) end,
    TORMENT = function() return Color(180, 130, 255) end,
    RESET   = function() return Color(190, 190, 190) end,
}

local function team_nw_totals(st)
    local pl = st.nwPlayers
    if pl and pl.ours.n > 0 and pl.theirs.n > 0 then
        return pl.ours.sum, pl.theirs.sum, "umbrella"
    end
    local A, E = st.A, st.E
    if A.itemCount > 0 and E.itemCount > 0 then
        local size = math.max(A.count, E.count, 1)
        return A.itemSum / A.itemCount * size, E.itemSum / E.itemCount * size, "items"
    end
    return nil
end

local function strength_diff(st)
    local ours, theirs, mode = team_nw_totals(st)
    if not ours then return nil, "unknown", 0 end
    local gold = ours - theirs
    return gold, mode, gold
end

local function advantage_text(sMode, sRaw)
    return T("wce.nw", math.abs(sRaw) / 1000)
end

local function rosh_damage_in_window(st, window)
    local rosh = st.roshan
    if not rosh or not rosh.pos then return nil end
    if type(rosh.hpAbs) ~= "number" or rosh.hpAbs <= 0 then return nil end
    if type(window) ~= "number" or window <= 0 then return nil end

    local mult = (type(rosh.armorMult) == "number" and rosh.armorMult > 0) and rosh.armorMult or 1.0
    local total, contributors = 0, 0
    for _, u in pairs(st.allies) do
        if u.alive and u.dps and u.pos then
            local speed = (u.speed and u.speed > 0) and u.speed or 300
            local fighting = window - (dist2d(u.pos, rosh.pos) / speed)
            if fighting > 0 then
                total = total + fighting * u.dps * mult
                contributors = contributors + 1
            end
        end
    end
    for _, s in pairs(st.summons or {}) do
        if s.pos and s.dps then
            local fighting = window - (dist2d(s.pos, rosh.pos) / 300)
            if fighting > 0 then
                total = total + fighting * s.dps * mult
                contributors = contributors + 1
            end
        end
    end
    if contributors == 0 then return nil end
    return total, rosh.hpAbs
end

local function tormentor_plan(st)
    local t = st.tormentor
    if not t or not t.alive or not t.pos then return nil end
    if type(t.hpAbs) ~= "number" or t.hpAbs <= 0 then return nil end

    local mult = (type(t.armorMult) == "number" and t.armorMult > 0) and t.armorMult or 1.0
    local dps, hpPool, heroes, summons = 0, 0, 0, 0

    for _, u in pairs(st.allies) do
        if u.alive and u.pos and u.dps and dist2d(u.pos, t.pos) <= CFG.torm_reach then
            dps = dps + u.dps * mult
            hpPool = hpPool + (u.hp or 0)
            heroes = heroes + 1
        end
    end
    for _, s in pairs(st.summons or {}) do
        if s.pos and s.dps and dist2d(s.pos, t.pos) <= CFG.torm_reach then
            dps = dps + s.dps * mult
            hpPool = hpPool + (s.hp or 0)
            summons = summons + 1
        end
    end

    if heroes == 0 or dps <= 0 then return nil end

    local killTime = t.hpAbs / dps
    local reflected = t.hpAbs * CFG.torm_reflect_share
    local survivable = hpPool >= reflected * CFG.torm_hp_margin

    return {
        killTime = killTime,
        heroes = heroes,
        summons = summons,
        hpPool = hpPool,
        reflected = reflected,
        survivable = survivable,
        fast = killTime <= CFG.torm_max_kill_seconds,
    }
end

local function evaluate(st)
    local S = {}
    for _, k in ipairs(OBJ) do S[k] = { score = 0, reasons = {} } end
    local function add(k, pts, reason)
        S[k].score = S[k].score + pts
        if reason and pts ~= 0 then S[k].reasons[#S[k].reasons + 1] = { pts = pts, text = reason } end
    end

    local manAdv   = st.manAdv
    local ultFrac  = st.A.alive > 0 and st.A.ultReady / st.A.alive or 0
    local sDiff, sMode, sRaw = strength_diff(st)

    local aheadK   = sDiff and (sDiff / 1000) or 0
    local grouped  = st.groupedFrac >= 0.6

    if manAdv > 0 then
        add("FIGHT", 22 * manAdv, T("wce.r.fight_more_dead", manAdv))
    elseif manAdv < 0 then
        add("FIGHT", 20 * manAdv)
    end
    if ultFrac >= 0.6 then
        add("FIGHT", 16, T("wce.r.ults_ready", st.A.ultReady, st.A.alive))
    else
        add("FIGHT", -10)
    end
    if aheadK >= 3 then add("FIGHT", 12, T("wce.r.stronger", advantage_text(sMode, sRaw)))
    elseif aheadK <= -4 then add("FIGHT", -14) end
    if grouped then add("FIGHT", 10, T("wce.r.grouped")) else add("FIGHT", -8, nil) end
    if st.A.lowHp >= 2 then add("FIGHT", -12, T("wce.r.low_hp", st.A.lowHp)) end

    if st.roshan and st.roshan.alive then
        if st.time >= CFG.rosh_min_time then
            local base = 6
            add("ROSHAN", base)
            if manAdv >= 1 then

                local window = st.roshWindow or st.E.maxRespawn
                local dmg, roshHp = rosh_damage_in_window(st, window)
                local blocker = st.roshBlocker
                local who = blocker and blocker.name or T("wce.r.enemy")

                if window <= 0 then
                    add("ROSHAN", 20 * manAdv, T("wce.r.rosh_dead", st.E.dead))
                elseif dmg then
                    local share = dmg / roshHp
                    if share >= 1 then
                        local soft = blocker and (blocker.threat or 1) < CFG.rosh_threat_gate
                        add("ROSHAN", 20 * manAdv, soft
                            and T("wce.r.rosh_ok_weak", who)
                            or  T("wce.r.rosh_ok_window", st.E.dead, math.floor(window)))
                    else
                        add("ROSHAN", -22, T("wce.r.rosh_low_dmg",
                            math.floor(share * 100), who))
                    end
                else

                    local needed = CFG.rosh_kill_seconds + (st.roshTravel or 0)
                    if window >= needed then
                        add("ROSHAN", 20 * manAdv, T("wce.r.rosh_dead_window",
                            st.E.dead, math.floor(window)))
                    else
                        add("ROSHAN", -22, T("wce.r.rosh_too_slow",
                            who, math.floor(window), math.floor(needed)))
                    end
                end
            end
            if ultFrac >= 0.5 then add("ROSHAN", 14, T("wce.r.spells_ready")) end
            if st.core and st.roshan.pos and st.core.pos and dist2d(st.core.pos, st.roshan.pos) <= st.reach then
                add("ROSHAN", 16, T("wce.r.core_near", st.core.name))
            elseif st.core then
                add("ROSHAN", -10)
            end
            if grouped then add("ROSHAN", 8, T("wce.r.together")) end
            if aheadK <= -4 and manAdv <= 0 then add("ROSHAN", -18) end

            if st.sieged then
                add("ROSHAN", -60, T("wce.r.rosh_sieged", st.enemiesAtOurBase))
            elseif st.enemiesNearUs >= 2 then
                add("ROSHAN", -35, T("wce.r.rosh_pinned", st.enemiesNearUs))
            end
        end
    end

    if st.tormentor and st.tormentor.alive and st.time >= CFG.torm_min_time then
        local plan = tormentor_plan(st)
        if plan then
            add("TORMENT", 10)

            if plan.summons > 0 then
                add("TORMENT", 14, T("wce.r.summons_soak", plan.summons))
            end

            if plan.survivable and plan.fast then
                add("TORMENT", 26, T("wce.r.torm_ok",
                    plan.heroes, math.floor(plan.killTime)))
            elseif not plan.survivable then
                add("TORMENT", -30, T("wce.r.torm_low_hp",
                    plan.hpPool / 1000, plan.reflected * CFG.torm_hp_margin / 1000))
            elseif not plan.fast then
                add("TORMENT", -20, T("wce.r.torm_slow", math.floor(plan.killTime)))
            end

            if manAdv >= 1 then
                add("TORMENT", 10 * manAdv, T("wce.r.enemies_dead", st.E.dead))
            end
            if st.sieged then
                add("TORMENT", -60, T("wce.r.base_enemies"))
            elseif st.enemiesNearUs >= 2 then
                add("TORMENT", -30, T("wce.r.enemies_near", st.enemiesNearUs))
            end
        end
    end

    if st.towerTarget then
        add("PUSH", 22, T("wce.r.tower_low", math.floor(st.towerTarget.hp * 100)))
    end
    if manAdv >= 1 then
        add("PUSH", 12 * manAdv, T("wce.r.push_window", st.E.dead))
        if st.E.maxRespawn >= 25 then
            add("PUSH", 8, T("wce.r.long_respawn", math.floor(st.E.maxRespawn)))
        end
    end
    if aheadK >= 2 then add("PUSH", 8, T("wce.r.ahead")) end
    if grouped then add("PUSH", 6) else add("PUSH", -6) end

    if st.sieged then add("PUSH", -50, T("wce.r.lift_siege")) end

    if manAdv == 0 and math.abs(aheadK) < 3 then
        add("FARM", 16, T("wce.r.no_adv"))
    end
    if aheadK <= -3 then add("FARM", 14, T("wce.r.behind_farm", advantage_text(sMode, sRaw))) end

    if st.groupedFrac < 0.4 then add("FARM", 8, T("wce.r.spread")) end
    if st.A.lowHp >= 2 then add("FARM", 6) end
    if manAdv >= 2 then add("FARM", -12) end

    if st.isolated and st.time >= CFG.pickoff_min_time then
        add("PICKOFF", 26, T("wce.r.isolated", st.isolated.name))
        if st.isolated.hpPct < 0.6 then
            add("PICKOFF", 10, T("wce.r.isolated_hp", math.floor(st.isolated.hpPct * 100)))
        end
        if ultFrac >= 0.4 then add("PICKOFF", 8, T("wce.r.can_kill")) end
        if not grouped and st.A.alive >= 2 then add("PICKOFF", -6) end
    end

    if manAdv < 0 then
        add("DEFEND", 18 * (-manAdv), T("wce.r.man_down", -manAdv))
    end
    if aheadK <= -4 then add("DEFEND", 12, T("wce.r.behind_defend")) end
    if st.A.lowHp >= 2 and manAdv <= 0 then add("DEFEND", 8, T("wce.r.battered")) end

    if st.sieged then
        add("DEFEND", 45, T("wce.r.hold_hg", st.enemiesAtOurBase))
    end

    do
        local lowResources = 0
        for _, u in pairs(st.allies) do
            if u.alive and (u.hpPct < CFG.low_hp or u.manaPct < CFG.low_mana) then
                lowResources = lowResources + 1
            end
        end
        if lowResources >= math.max(2, math.ceil(st.A.alive * 0.6)) and manAdv <= 0 then
            add("RESET", 20, T("wce.r.no_resources", lowResources))
            if ultFrac < 0.4 then add("RESET", 8, T("wce.r.ults_cd")) end
        end
    end

    for _, bias in ipairs(STAGE_BIAS[st.stage] or {}) do
        add(bias.obj, bias.pts, bias.reason and T(bias.reason))
    end

    local ranked = {}
    for _, k in ipairs(OBJ) do
        table.sort(S[k].reasons, function(a, b) return a.pts > b.pts end)
        ranked[#ranked + 1] = { key = k, score = S[k].score, reasons = S[k].reasons }
    end
    table.sort(ranked, function(a, b) return a.score > b.score end)
    return ranked
end

local function has_widgets(node)
    return node ~= nil and type(node.Switch) == "function"
end

local function descend(node, name, side)
    if has_widgets(node) then return node end
    if node == nil or type(node.Create) ~= "function" then return nil end
    local ok, child = pcall(node.Create, node, name, side)
    return (ok and child ~= nil) and child or nil
end

local function initialize_menu()
    local side         = (type(Enum) == "table" and Enum.GroupSide) or {}
    local tab          = Menu.Create("General", "Main", "Win Engine")
    local column       = descend(tab, "wce.menu.column")
    local mainGroup    = descend(column, "wce.menu.advisor", side.Left)
    local overlayGroup = descend(column, "wce.menu.overlay", side.Right) or mainGroup

    if not has_widgets(mainGroup) then
        return false
    end
    if not has_widgets(overlayGroup) then overlayGroup = mainGroup end

    local function icon(w, glyph)
        if w ~= nil and type(w.Icon) == "function" then pcall(w.Icon, w, glyph) end
        return w
    end

    ui.enabled = mainGroup:Switch("wce.menu.enabled", true, "\u{f011}")
    local gear = type(ui.enabled.Gear) == "function"
        and select(2, pcall(ui.enabled.Gear, ui.enabled, "wce.menu.settings", "\u{f013}"))
    local advSettings = (gear ~= nil and type(gear) ~= "boolean") and gear or mainGroup

    ui.refresh = icon(advSettings:Slider("wce.menu.refresh", 100, 2000, 500, "%d ms"), "\u{f017}")
    ui.reach   = icon(advSettings:Slider("wce.menu.reach", 1200, 4000, CFG.reach, "%d"), "\u{f05b}")

    ui.verbose = overlayGroup:Switch("wce.menu.verbose", true, "\u{f03a}")
    ui.scale   = icon(overlayGroup:Slider("wce.menu.scale", 70, 150, 100, "%d%%"), "\u{f065}")
    local function hidden_store(name)
        local w = advSettings:Slider(name, -1, 8192, -1)
        if w ~= nil and type(w.Visible) == "function" then pcall(w.Visible, w, false) end
        return w
    end
    ui.posX = hidden_store("panel_x")
    ui.posY = hidden_store("panel_y")

    return ui.enabled ~= nil and ui.refresh ~= nil and ui.reach ~= nil
        and ui.verbose ~= nil and ui.scale ~= nil
end

local function initialize_fonts()
    Ui.panel.font = try(Render.LoadFont, "MuseoSansEx", FONT_AA, 500)
        or try(Render.LoadFont, "Arial", 0, 500)
        or try(Render.LoadFont, "Arial")
    Ui.panel.iconFont = try(Render.LoadFont, "FontAwesomeEx", FONT_AA, 400)
end

function script.OnGameEnd()
    nw_seen = {}
end

function script.OnScriptsLoaded()
    Ui.panel.styleOk = pcall(Menu.Style, "primary")
    initialize_fonts()
    local ok, err = pcall(initialize_menu)
    if ok and err == true then
        ready = true
        return
    end
    g_menu_error = ok and "initialize_menu returned false" or tostring(err)
    local function const(v) return { Get = function() return v end } end
    ui.enabled, ui.verbose = const(true), const(false)
    ui.refresh, ui.reach, ui.scale = const(500), const(CFG.reach), const(100)
    ready = true
end

local g_ranked = nil
local g_next   = 0
local g_error  = nil
local g_stage  = nil
local g_nw     = nil
local g_wait   = nil

function script.OnUpdate()
    if not ready then return end
    if not ui.enabled:Get() then g_ranked = nil; g_stage = nil; g_nw = nil; return end
    local now = try(GameRules.GetGameTime) or os.clock()
    local interval = ui.refresh:Get() / 1000
    if now < g_next then return end
    g_next = now + interval

    local ok, res, stage, nw, wait = pcall(function()
        local st, why = collect_state()
        if not st then return nil, nil, nil, why end
        local pl = st.nwPlayers
        local info = {
            oursTotal = st.A.count, theirsTotal = st.E.count,
            oursRead = pl.ours.n > 0 and pl.ours.n or st.A.itemCount,
            theirsRead = pl.theirs.n > 0 and pl.theirs.n or st.E.itemCount,
        }
        info.ours, info.theirs, info.src = team_nw_totals(st)
        info.src = info.src or "none"
        info.partial = info.src == "items" and (info.oursRead < st.A.count or info.theirsRead < st.E.count)
        return evaluate(st), st.stage, info
    end)
    if ok then g_ranked = res; g_stage = stage; g_nw = nw; g_wait = wait; g_error = nil
    else g_error = tostring(res) end
end

local function build_rows()
    local rows = {}
    if g_error or g_menu_error or not g_ranked or #g_ranked == 0 then
        local err = g_menu_error or g_error
        local note = err or g_wait
        rows[#rows + 1] = {
            T("wce.panel.status"),
            err and (g_menu_error and T("wce.panel.menu_failed") or T("wce.panel.error"))
                or (g_wait and T("wce.panel.no_data") or T("wce.panel.waiting")),
            err and Ui.colors.disabled or Ui.colors.textMuted,
        }
        if note then rows[#rows + 1] = { "", "• " .. note, Ui.colors.textMuted, "text" } end
        return rows
    end

    local best = g_ranked[1]
    local objc = (OBJ_COLOR[best.key] or function() return Ui.colors.accent end)()
    rows[#rows + 1] = { T("wce.panel.advice"), LABEL[best.key], objc }
    if g_stage then
        rows[#rows + 1] = { T("wce.panel.stage"), T("wce.stage." .. g_stage), Ui.colors.textMuted }
    end
    if g_nw then
        if g_nw.src == "none" then
            rows[#rows + 1] = {
                T("wce.panel.networth"),
                T("wce.panel.nw_no_data",
                    g_nw.oursRead or 0, g_nw.oursTotal or 0,
                    g_nw.theirsRead or 0, g_nw.theirsTotal or 0),
                Ui.colors.disabled,
            }
        else
            local diff = (g_nw.ours - g_nw.theirs) / 1000
            local label = g_nw.src == "items" and T("wce.panel.networth_est") or T("wce.panel.networth")
            if g_nw.partial then
                label = label .. ("  %d/%d·%d/%d"):format(
                    g_nw.oursRead, g_nw.oursTotal, g_nw.theirsRead, g_nw.theirsTotal)
            end
            rows[#rows + 1] = {
                label,
                ("%.1fk / %.1fk  %+.1fk"):format(g_nw.ours / 1000, g_nw.theirs / 1000, diff),
                diff >= 0 and Ui.colors.enabled or Ui.colors.disabled,
            }
        end
    end

    local reasons = {}
    for _, r in ipairs(best.reasons) do
        if r.pts > 0 and #reasons < 3 then reasons[#reasons + 1] = r.text end
    end
    if #reasons == 0 then reasons[1] = T("wce.panel.overall") end

    for _, t in ipairs(reasons) do
        rows[#rows + 1] = { "", "• " .. t, Ui.colors.text, "text" }
    end

    if ui.verbose:Get() then
        for i, r in ipairs(g_ranked) do
            local top = (i == 1)
            rows[#rows + 1] = {
                ("%d %s"):format(i, LABEL[r.key]),
                ("%d"):format(math.floor(r.score)),
                top and Ui.colors.accent or Ui.colors.textMuted,
            }
        end
    end

    return rows
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

local function draw_panel()
    if not ready or not ui.enabled:Get() then
        Ui.panel.dragging = false
        return
    end
    Ui.refreshCampPanelTheme()
    local colors = Ui.colors
    local panel = Ui.panel

    local rows = build_rows()

    local scale       = ui.scale:Get() / 100
    local fontSize    = math.max(9, Ui.campPanelRound(13 * scale))
    local titleSize   = math.max(10, Ui.campPanelRound(16 * scale))
    local pinSize     = math.max(10, Ui.campPanelRound(15 * scale))
    local chevronSize = math.max(9, Ui.campPanelRound(13 * scale))
    local rowHeight   = Ui.campPanelRound(21 * scale)
    local padding     = Ui.campPanelRound(11 * scale)
    local headerHeight= Ui.campPanelRound(26 * scale)
    local bodyGap     = Ui.campPanelRound(6 * scale)
    local rounding    = math.max(3, Ui.campPanelRound(6 * scale))
    local chevronHit  = math.max(7, Ui.campPanelRound(11 * scale))

    local best = (g_ranked and g_ranked[1]) or nil
    local adviceTitle = best and LABEL[best.key] or nil
    local title, titleColor = "WIN ENGINE", colors.text
    if panel.collapsed and adviceTitle then
        title = adviceTitle
        titleColor = (OBJ_COLOR[best.key] or function() return colors.accent end)()
    end

    local pinGlyph = "\u{f3c5}"
    local pinW = panel.iconFont and Ui.textSize(panel.iconFont, pinSize, pinGlyph).x or 0

    local width = Ui.campPanelRound(260 * scale)
    local titleW = Ui.textSize(panel.font, titleSize, "WIN ENGINE").x
    if adviceTitle then
        titleW = math.max(titleW, Ui.textSize(panel.font, titleSize, adviceTitle).x)
    end
    width = math.max(width, Ui.campPanelRound(titleW + padding * 2 + pinW * 2 + 16 * scale))
    local bodyHeight = padding * 2 + rowHeight * #rows

    panel.open = Ui.campPanelEase(panel.open, panel.collapsed and 0 or 1, Ui.campPanelSpeed(1))
    local openT = panel.open
    local ease  = openT * openT * (3 - 2 * openT)
    local shown = Ui.campPanelRound(bodyHeight * ease)
    local fade  = ease * ease
    local height = headerHeight + (shown > 2 and bodyGap + shown or 0)

    local screen = try(Render.ScreenSize) or Vec2(1920, 1080)
    if panel.x == nil or panel.y == nil then
        panel.x, panel.y = saved_pos()
        if panel.x == nil then
            panel.x = Ui.campPanelRound(screen.x * 0.02)
            panel.y = Ui.campPanelRound(screen.y * 0.18)
        end
    end

    panel.collapseBounds = Ui.setBounds(panel.collapseBounds, panel.x, panel.y, chevronHit * 2 + padding, headerHeight)

    local cursorX, cursorY
    if CAN_DRAG then cursorX, cursorY = IN_CURSOR() end
    if cursorX ~= nil and cursorY ~= nil then
        local mouseDown   = IN_DOWN(MOUSE1, true)
        local clickedOnce = IN_ONCE(MOUSE1, true)

        if not panel.dragging and clickedOnce and Ui.campPanelPointInside(panel.collapseBounds, cursorX, cursorY) then
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

    local x, y = Ui.campPanelRound(panel.x), Ui.campPanelRound(panel.y)
    local shadowSize = math.max(6, Ui.campPanelRound(12 * scale))

    pcall(Render.Shadow, Vec2(x, y), Vec2(x + width, y + headerHeight), colors.shadow, shadowSize, rounding)
    pcall(Render.Blur, Vec2(x, y), Vec2(x + width, y + headerHeight), 3, 1, rounding)
    pcall(Render.FilledRect, Vec2(x, y), Vec2(x + width, y + headerHeight), colors.body, rounding)
    pcall(Render.Rect, Vec2(x, y), Vec2(x + width, y + headerHeight), colors.border, rounding, DRAW_NONE, 1)

    local iconY = y + headerHeight * 0.5
    local hoverChevron = cursorX ~= nil and Ui.campPanelPointInside(panel.collapseBounds, cursorX, cursorY)
    panel.chevronAnim = Ui.campPanelEase(panel.chevronAnim, hoverChevron and 1 or 0, Ui.campPanelSpeed(3))
    local chevronGlyph = panel.collapsed and "\u{f078}" or "\u{f077}"

    if panel.iconFont then
        Ui.drawCampPanelIcon(chevronSize, chevronGlyph, x + padding + chevronHit, iconY,
            Ui.campPanelMix(colors.textMuted, colors.accent, panel.chevronAnim))
        Ui.drawCampPanelIcon(pinSize, pinGlyph, x + width - padding - chevronHit, iconY, colors.textMuted)
    end
    Ui.drawCampPanelCenteredText(titleSize, title, x, y, width, headerHeight, titleColor)

    if shown > 2 then
        local top = y + headerHeight + bodyGap
        local bottom = top + shown

        pcall(Render.Shadow, Vec2(x, top), Vec2(x + width, bottom), Ui.campPanelFade(colors.shadow, fade), shadowSize, rounding)
        pcall(Render.Blur, Vec2(x, top), Vec2(x + width, bottom), 3, fade, rounding)
        pcall(Render.FilledRect, Vec2(x, top), Vec2(x + width, bottom), Ui.campPanelFade(colors.body, fade), rounding)
        pcall(Render.Rect, Vec2(x, top), Vec2(x + width, bottom), Ui.campPanelFade(colors.border, fade), rounding, DRAW_NONE, 1)

        local rowInnerWidth = width - padding * 2
        for i = 1, #rows do
            local rowY = top + padding + (i - 1) * rowHeight
            if rows[i][4] == "text" then

                Ui.drawPanelTextLine(
                    fontSize,
                    truncate_to_width(panel.font, fontSize, rows[i][2], rowInnerWidth),
                    x + padding,
                    rowY,
                    rowHeight,
                    Ui.campPanelFade(rows[i][3], fade)
                )
            else
                local label = rows[i][1]
                local labelW = Ui.textSize(panel.font, fontSize, label).x
                local availW = rowInnerWidth - labelW - Ui.campPanelRound(10 * scale)
                Ui.drawCampPanelRow(
                    fontSize,
                    label,
                    truncate_to_width(panel.font, fontSize, rows[i][2], availW),
                    x + padding,
                    rowY,
                    rowInnerWidth,
                    rowHeight,
                    Ui.campPanelFade(colors.textMuted, fade),
                    Ui.campPanelFade(rows[i][3], fade)
                )
            end
        end
    end
end

local g_draw_error = nil

local function draw_error_banner(msg)
    local screen = try(Render.ScreenSize) or Vec2(1920, 1080)
    local x, y = round(screen.x * 0.02), round(screen.y * 0.18)
    local w, h = round(screen.x * 0.42), 46
    pcall(Render.FilledRect, Vec2(x, y), Vec2(x + w, y + h), Color(20, 20, 24, 235), 4)
    pcall(Render.Rect, Vec2(x, y), Vec2(x + w, y + h), Color(224, 50, 45, 245), 4, DRAW_NONE, 1)
    local f = Ui.panel.font or try(Render.LoadFont, "Arial", 0, 500)
    pcall(Render.Text, f, 14, T("wce.panel.draw_error"), Vec2(x + 10, y + 6), Color(224, 50, 45, 245))
    pcall(Render.Text, f, 12, tostring(msg):sub(1, 150), Vec2(x + 10, y + 26), Color(220, 220, 225, 240))
end

function script.OnDraw()
    local ok, err = pcall(draw_panel)
    if ok then
        g_draw_error = nil
        return
    end
    g_draw_error = tostring(err)
    pcall(draw_error_banner, g_draw_error)
end

return script
