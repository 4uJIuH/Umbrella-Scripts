--[[
  Broodmother Helper — UCZone API v2.0
  Пауки: сбор/развод, авто-следование/чейз/сплит/фарм, Soul Ring, Orchid/Bloodthorn, веб-хелпер.
  Оптимизировано: реже ордера = меньше перехват управления, плавная работа.
]]

local broodmother = {}

-- ═══════════════════════════════════════════════════════════════════════════
--  Константы оптимизации (реже ордера → меньше конфликт с ручным управлением)
-- ═══════════════════════════════════════════════════════════════════════════
local ORDER_INTERVAL_FOLLOW  = 2.8   -- сек между ордерами "следовать за героем"
local ORDER_INTERVAL_CHASE   = 2.4   -- сек между ордерами "атаковать врага"
local ORDER_INTERVAL_FARM   = 2.0   -- сек между ордерами "фармить крипов"
local ORDER_INTERVAL_FAR    = 3.2   -- сек между ордерами для далеких пауков
local ORDER_INTERVAL_JUGGLE = 0.45  -- сек между ордерами "развести"
local JUGGLE_REISSUE_DISTANCE = 140 -- переотправлять ордер только если паук заметно ушёл с точки
local SPIDER_CACHE_TTL       = 0.12  -- кэш списка пауков (сек), меньше вызовов NPCs.GetAll()
-- Тайминг первого удара и сдвиг по стакам (из Auto Stacker By GLTM)
local STACK_FIRST_HIT_MELEE  = 53
local STACK_PER_STACK_SHIFT  = 0.4   -- секунд на стак (40 centi)

-- Точки wait/pull для стака нейтралов (координаты из Auto Stacker By GLTM)
local CAMP_POINTS = {
    [1]  = { wait = Vector(-742, 4325, 134),   pull = Vector(-682, 3881, 236) },
    [2]  = { wait = Vector(2943, -796, 256),   pull = Vector(2817, -53, 256) },
    [3]  = { wait = Vector(4082, -5526, 128),  pull = Vector(4181, -6368, 128) },
    [4]  = { wait = Vector(8255, -734, 256),   pull = Vector(8204, -1369, 256) },
    [5]  = { wait = Vector(-4806, 4534, 128),  pull = Vector(-4884, 5071, 128) },
    [6]  = { wait = Vector(4284, -4110, 128),   pull = Vector(3622, -4505, 128) },
    [7]  = { wait = Vector(-2121, -3921, 128), pull = Vector(-1564, -4531, 128) },
    [8]  = { wait = Vector(262, -4751, 136),   pull = Vector(333, -4101, 254) },
    [9]  = { wait = Vector(-4509, 361, 256),   pull = Vector(-5031, 1121, 128) },
    [10] = { wait = Vector(4072, -421, 256),   pull = Vector(4276, -1359, 128) },
    [11] = { wait = Vector(-1274, -4908, 128), pull = Vector(-812, -5282, 128) },
    [12] = { wait = Vector(1515, 8209, 128),   pull = Vector(792, 8152, 128) },
    [13] = { wait = Vector(455, 3965, 134),    pull = Vector(-78, 3932, 136) },
    [14] = { wait = Vector(-4144, 322, 256),   pull = Vector(-5031, 1121, 128) },
    [15] = { wait = Vector(316, -8138, 134),   pull = Vector(954, -8538, 136) },
    [16] = { wait = Vector(-2529, -7737, 134), pull = Vector(-2690, -7154, 134) },
    [17] = { wait = Vector(-479, 7639, 134),   pull = Vector(-551, 6961, 128) },
    [18] = { wait = Vector(-4743, 7534, 0),    pull = Vector(-4832, 7136, 0) },
    [19] = { wait = Vector(1348, 3263, 128),    pull = Vector(1683, 3710, 128) },
    [20] = { wait = Vector(7969, 1047, 256),   pull = Vector(7681, 695, 256) },
    [21] = { wait = Vector(-7735, -183, 256),  pull = Vector(-7436, 685, 256) },
    [22] = { wait = Vector(-3962, 7564, 0),    pull = Vector(-4521, 7474, 8) },
    [23] = { wait = Vector(-2589, 4502, 256),  pull = Vector(-2651, 5138, 256) },
    [24] = { wait = Vector(3522, -8186, 8),     pull = Vector(4028, -7376, 0) },
    [25] = { wait = Vector(1501, -4208, 256),  pull = Vector(1094, -5103, 136) },
    [26] = { wait = Vector(-4338, 4903, 128),   pull = Vector(-5198, 4877, 128) },
    [27] = { wait = Vector(-7757, -1219, 256), pull = Vector(-7693, -727, 256) },
    [28] = { wait = Vector(4781, -7812, 8),    pull = Vector(4510, -7260, 82) },
}

-- Состояние стака по кнопке (логика GLTM: без выделения, пауки по назначенным кампам)
local stackSessionActive   = false
local stackWasKeyHeld     = false
local stackUnitToCampId   = {}
local stackCampStrikeCenters = {}
local stackCampBoxes      = {}
local stackCampStacks     = {}
local stackCampStacksMinute = {}
local stackLastCampStacks = {}
local stackTimeline       = {}

-- ═══════════════════════════════════════════════════════════════════════════
--  Lane Pull: точки линий, время подхода крипов
-- ═══════════════════════════════════════════════════════════════════════════
local PullLanePoints = {
    radiant = {
        { pos = Vector(2266.9, 5839.9, 136.0), name = "Top" },
        { pos = Vector(3503.1, 2892.1, 136.0), name = "Mid" },
        { pos = Vector(6344.7, 1852.7, 136.0), name = "Bot" },
    },
    dire = {
        { pos = Vector(-6599.8, -2183.7, 128.0), name = "Top" },
        { pos = Vector(-3945.1, -3491.4, 136.8), name = "Mid" },
        { pos = Vector(-2440.2, -6167.0, 128.0), name = "Bot" },
    },
}

local PullCreepTravelTime = {
    radiant = { Top = 25, Mid = 20, Bot = 25 },
    dire    = { Top = 25, Mid = 20, Bot = 25 },
}

local PullFonts = {
    Main = Render.LoadFont("Verdana", Enum.FontCreate.FONTFLAG_ANTIALIAS)
}

local PullState = {
    pullToggled = false,
    assignments = {},
    cachedTowers = nil,
    cachedTowersTime = 0,
    lastDispatchClock = -999,
}

-- ═══════════════════════════════════════════════════════════════════════════
--  Конфиг и сохранение позиции панели
-- ═══════════════════════════════════════════════════════════════════════════

local function GetConfigPath()
    return "brood_panel.ini"
end

local function LoadPanelPosition()
    local configPath = GetConfigPath()
    local file = io.open(configPath, "r")
    local x, y = 100.0, 100.0
    if file then
        for line in file:lines() do
            local xMatch = line:match("pos_x=(%d+)")
            local yMatch = line:match("pos_y=(%d+)")
            if xMatch then x = tonumber(xMatch) or x end
            if yMatch then y = tonumber(yMatch) or y end
        end
        file:close()
    end
    return x, y
end

local function SavePanelPosition(x, y)
    local configPath = GetConfigPath()
    local file = io.open(configPath, "w")
    if file then
        file:write(string.format("pos_x=%d\n", x))
        file:write(string.format("pos_y=%d\n", y))
        file:close()
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
--  Встроенные точки паутины (карта)
-- ═══════════════════════════════════════════════════════════════════════════

local BuiltInWebPoints = {
    radiant = {
        Vector(-201.0,-77.7,116.6), Vector(-1650.3,-1035.8,128.0), Vector(1139.7,926.0,128.0), Vector(-1441.3,-3310.8,128.0),
        Vector(-1073.8,-4963.5,128.0), Vector(937.3,-4405.5,244.2), Vector(3016.3,-5293.7,153.8), Vector(4838.3,-4607.0,128.0),
        Vector(6350.6,-5282.3,128.0), Vector(3007.3,-3204.2,14.0), Vector(4760.9,-6695.1,128.0), Vector(6952.3,-7236.4,256.0),
        Vector(3804.3,-8109.5,8.0), Vector(1358.6,-6705.8,8.0), Vector(-572.4,-7852.3,136.0), Vector(-2781.3,-7820.2,136.0),
        Vector(432.3,-2011.2,128.0), Vector(-3359.8,-2404.2,128.0), Vector(-4038.6,-128.5,256.0), Vector(-6294.8,-81.0,128.0),
        Vector(-7853.7,-720.1,256.0), Vector(-5477.0,1837.9,128.0), Vector(-7644.1,1684.1,256.0), Vector(-7946.9,3872.9,128.0),
        Vector(-7209.8,5891.9,128.0), Vector(-7249.5,7903.7,256.0), Vector(-5578.5,4211.5,128.0), Vector(-5522.4,6315.3,128.0),
        Vector(-3559.2,4280.8,140.4), Vector(-1561.8,4555.9,136.0), Vector(-3146.4,6256.3,128.0), Vector(-4126.5,8058.1,17.9),
        Vector(-1280.8,7674.4,256.0), Vector(782.5,7706.2,134.0), Vector(2627.1,7279.6,134.0), Vector(1627.7,5371.9,128.0),
        Vector(-1262.3,2169.0,256.0), Vector(287.8,3399.1,136.0), Vector(2294.0,2973.3,128.0), Vector(3097.4,1399.3,128.0),
        Vector(4161.7,-441.1,256.0), Vector(1980.0,-1044.2,256.0), Vector(5165.5,1637.2,128.0), Vector(7498.3,1572.4,256.0),
        Vector(7553.4,-640.2,194.5), Vector(5925.3,-1202.9,128.0), Vector(6223.9,-3209.6,128.0), Vector(-333.4,-6524.6,128.0),
        Vector(-2538.9,698.8,0.0), Vector(-3304.7,2564.7,74.9), Vector(-7291.8,2830.6,52.2)
    },
    dire = {
        Vector(577.4,220.4,128.0), Vector(-876.4,-695.2,128.0), Vector(623.2,-1765.3,128.0), Vector(-2676.0,389.6,128.0),
        Vector(-1115.8,1490.1,128.0), Vector(-4499.0,589.8,256.0), Vector(-6297.6,1723.0,128.0), Vector(-4719.2,2781.3,0.0),
        Vector(-1705.4,-2356.7,128.0), Vector(-3187.1,-1237.9,256.0), Vector(-1578.5,-4574.9,128.0), Vector(615.3,-4684.3,136.0),
        Vector(144.2,-3264.8,256.0), Vector(2740.0,-4209.9,256.0), Vector(4773.7,-4620.6,128.0), Vector(3174.1,-6286.9,128.0),
        Vector(5171.5,-6917.3,128.0), Vector(6710.5,-5165.4,128.0), Vector(7340.3,-7211.4,256.0), Vector(3485.5,-8188.2,8.0),
        Vector(1301.2,-7854.0,134.0), Vector(-883.8,-7865.6,136.0), Vector(-2983.0,-7481.6,131.9), Vector(-2115.3,-6160.5,128.0),
        Vector(-3850.4,-4844.2,256.0), Vector(-4180.6,-2536.2,128.0), Vector(-6439.4,-2212.2,128.0), Vector(-7913.8,-946.2,256.0),
        Vector(-7952.4,1369.9,256.0), Vector(-4801.4,-1009.6,256.0), Vector(2687.5,-98.2,240.9), Vector(4333.0,-652.1,256.0),
        Vector(6481.7,-433.7,128.0), Vector(7971.8,757.7,256.0), Vector(7933.0,-2114.0,256.0), Vector(5397.7,-2473.7,128.0),
        Vector(1011.2,2511.2,128.0), Vector(126.7,4245.9,136.0), Vector(-1915.0,4310.5,256.0), Vector(-1035.0,2883.5,256.0),
        Vector(-4098.5,4298.6,128.0), Vector(-6145.8,3511.2,128.0), Vector(-7861.2,4548.8,128.0), Vector(-7044.3,6549.5,256.0),
        Vector(-5528.9,5512.7,128.0), Vector(-5069.2,7786.7,8.0), Vector(-2878.3,7706.6,8.0), Vector(-2966.6,5917.6,128.0),
        Vector(-216.3,5558.3,128.0), Vector(1369.2,7798.8,142.5), Vector(1703.4,5670.7,128.0), Vector(4132.2,1559.8,128.0),
        Vector(6327.4,1596.6,128.0), Vector(2893.6,3347.3,128.0), Vector(2185.7,1661.9,128.0), Vector(2418.7,-3067.0,0.0),
        Vector(4123.6,-2100.7,0.0), Vector(-2959.7,2653.2,0.0)
    },
    neutral = {}
}

local function IsBroodmother()
    local myHero = Heroes.GetLocal()
    return myHero and NPC.GetUnitName(myHero) == "npc_dota_hero_broodmother"
end

local Config = {
    UI = {
        TabName = "General",
        ScriptName = "Broodmother Helper",
        ScriptID = "brood_helper_v3",
        UsePanoramaIcons = true,  -- false = иконки меню через Unicode (если картинки не грузятся)
        Icons = {
            Main   = "panorama/images/heroes/icons/npc_dota_hero_broodmother_png.vtex_c",
            Soul   = "panorama/images/items/soul_ring_png.vtex_c",
            Gather = "panorama/images/items/quelling_blade_png.vtex_c",
            Juggle = "panorama/images/items/branches_png.vtex_c",
            Blood  = "panorama/images/items/bloodthorn_png.vtex_c",
            Web    = "panorama/images/spellicons/broodmother_spin_web_png.vtex_c",
            MainFallback   = "\u{f188}",
            SoulFallback   = "\u{f06e}",
            GatherFallback = "\u{f0c0}",
            JuggleFallback = "\u{f110}",
            BloodFallback  = "\u{f219}",
        }
    },
    Fonts = {
        Main = Render.LoadFont("SF Pro Text", Enum.FontCreate.FONTFLAG_ANTIALIAS)
    }
}

local PanelConfig = {
    Width = 200,
    Height = 50,
    HeaderHeight = 26,
    CellSize = 26,
    CellSpacing = 5,
    BorderRadius = 8,
    ShadowOffset = 2,
    BlurStrength = 15,
    BlurStrengthHeader = 10
}

local PanelColors = {
    Background = Color(20, 20, 25, 220),
    BackgroundHover = Color(25, 25, 30, 230),
    Border = Color(60, 60, 70, 180),
    BorderHover = Color(80, 120, 255, 200),
    Header = Color(10, 10, 10, 200),
    HeaderText = Color(255, 255, 255, 255),
    Shadow = Color(0, 0, 0, 100),
    StatusColors = {
        ["Gather"] = Color(120, 255, 120, 255),
        ["Spread"] = Color(255, 120, 255, 255),
        ["Attack"] = Color(255, 80, 80, 255),
        ["Idle"] = Color(180, 180, 180, 255),
        ["HP"] = Color(120, 200, 255, 255)
    }
}

local function InitializeUI()
    -- Создаём красивое меню в стиле AutoRuin - всё в одной вкладке
    local tab = Menu.Create("Heroes", "Hero List", "Broodmother")
    local main = tab:Create("Дополнительные настройки")

    local UI = {}

    -- === ГЛАВНАЯ СЕКЦИЯ ===
    local g_main = main:Create("Общее")

    UI.Enabled = g_main:Switch("Включить скрипт", true, "panorama/images/heroes/icons/npc_dota_hero_broodmother_png.vtex_c")
    UI.Enabled:ToolTip("Включить/выключить весь функционал скрипта")

    UI.ShowPanel = g_main:Switch("Показать панель", true, "\u{f06e}")
    UI.ShowPanel:ToolTip("Показать информационную панель с количеством пауков и их статусом")

    -- === РУЧНОЕ УПРАВЛЕНИЕ ПАУКАМИ ===
    local g_manual = main:Create("Ручное управление пауками")

    UI.GatherKey = g_manual:Bind("Собрать пауков", Enum.ButtonCode.KEY_NONE, "\u{f0c0}")
    UI.GatherKey:ToolTip("Отправляет всех пауков в точку курсора")

    local gather_gear = UI.GatherKey:Gear("Настройки сбора")
    UI.GatherDelay = gather_gear:Slider("Задержка команд (мс)", 30, 300, 50, "%d")
    UI.GatherDelay:ToolTip("Задержка между командами для каждого паука при сборе")

    UI.JuggleKey = g_manual:Bind("Развести пауков", Enum.ButtonCode.KEY_NONE, "\u{f0e8}")
    UI.JuggleKey:ToolTip("Разводит пауков по кругу вокруг героя")

    local juggle_gear = UI.JuggleKey:Gear("Настройки развода")
    UI.JuggleMode = juggle_gear:Combo("Режим кнопки", {"Зажатие (Hold)", "Переключение (Toggle)"}, 0)
    UI.JuggleMode:ToolTip("Hold: работает, пока кнопка зажата. Toggle: первое нажатие включает, второе выключает")
    UI.JuggleRadius = juggle_gear:Slider("Радиус круга", 100, 2000, 885, "%d")
    UI.JuggleRadius:ToolTip("Расстояние от героя до точек, куда разводятся пауки")

    UI.JuggleCount = juggle_gear:Slider("Макс. пауков", 1, 10, 5, "%d")
    UI.JuggleCount:ToolTip("Сколько пауков максимум участвует в разводе")

    -- === АВТОМАТИЧЕСКОЕ УПРАВЛЕНИЕ ===
    local g_auto = main:Create("Авто-управление пауками")

    -- Авто-следование
    UI.AutoFollow = g_auto:Switch("Авто-следование за героем", true, "\u{f0b2}")
    UI.AutoFollow:ToolTip("Выделяет часть пауков в роль сопровождения и держит их рядом с героем")

    local follow_gear = UI.AutoFollow:Gear("Настройки следования")
    UI.AutoFollowCount = follow_gear:Slider("Пауков в следовании", 0, 15, 2, "%d")
    UI.AutoFollowCount:ToolTip("Сколько пауков одновременно держать рядом с героем")

    UI.AutoFollowRadius = follow_gear:Slider("Радиус следования", 100, 600, 300, "%d")
    UI.AutoFollowRadius:ToolTip("Радиус вокруг героя, в котором будут находиться следующие пауки")

    -- Авто-чейз
    UI.AutoChase = g_auto:Switch("Авто-атака героев", true, "\u{f05b}")
    UI.AutoChase:ToolTip("Пауки автоматически переключаются на ближайших вражеских героев")

    local chase_gear = UI.AutoChase:Gear("Настройки атаки")
    UI.AutoChaseRadius = chase_gear:Slider("Радиус атаки", 800, 2000, 1200, "%d")
    UI.AutoChaseRadius:ToolTip("Радиус поиска врагов для автоматической атаки")

    -- Авто-сплит
    UI.AutoSplit = g_auto:Switch("Авто-распределение атак", true, "\u{f0e8}")
    UI.AutoSplit:ToolTip("Автоматически распределяет пауков по разным целям для эффективного фокуса")

    local split_gear = UI.AutoSplit:Gear("Настройки распределения")
    UI.AutoSplitMax = split_gear:Slider("Макс. пауков на цель", 3, 20, 6, "%d")
    UI.AutoSplitMax:ToolTip("Лимит пауков, назначаемых на одного врага при сплите")

    -- Авто-фарм
    UI.AutoFarmCreeps = g_auto:Switch("Авто-фарм пауками", false, "\u{f0ec}")
    UI.AutoFarmCreeps:ToolTip("Пауки автоматически фармят крипов и нейтралов рядом с героем")

    local farm_gear = UI.AutoFarmCreeps:Gear("Настройки фарма")
    UI.AutoFarmRadius = farm_gear:Slider("Радиус фарма", 600, 2000, 1200, "%d")
    UI.AutoFarmRadius:ToolTip("Радиус поиска крипов для фарма")

    UI.AutoFarmCampRange = farm_gear:Slider("Радиус поиска кемпов", 300, 900, 600, "%d")
    UI.AutoFarmCampRange:ToolTip("Дополнительный радиус для поиска нейтральных кемпов")

    -- Переопределение игроком
    UI.PlayerOverride = g_auto:Slider("Приоритет ручного контроля (сек)", 0.5, 5.0, 3.0, "%.1f")
    UI.PlayerOverride:ToolTip("После вашей команды паук игнорирует авто-логику указанное время")

    -- === АВТО-СТАК ===
    local g_stack = main:Create("Авто-стак нейтралов")

    UI.AutoStackCamps = g_stack:Switch("Стак по кнопке", true, "\u{f0c0}")
    UI.AutoStackCamps:ToolTip("Включает режим стака: пауки назначаются по кемпам и стакают их по таймингу")

    local stack_gear = UI.AutoStackCamps:Gear("Настройки стака")
    UI.StackKey = stack_gear:Bind("Кнопка стака", Enum.ButtonCode.KEY_NONE)
    UI.StackKey:ToolTip("Переключает режим стака вкл/выкл")

    UI.StackRadius = stack_gear:Slider("Макс. дистанция назначения", 2000, 6000, 4000, "%d")
    UI.StackRadius:ToolTip("Пауки назначаются только в кемпы в пределах этой дистанции")

    -- === ПРЕДМЕТЫ ===
    local g_items = main:Create("Предметы")

    UI.AutoSoulRing = g_items:Switch("Авто Soul Ring", true, "panorama/images/items/soul_ring_png.vtex_c")
    UI.AutoSoulRing:ToolTip("Автоматически использует Soul Ring при касте Spawn Spiderlings")

    UI.SmartBloodthorn = g_items:Switch("Умный Orchid/Bloodthorn", true, "panorama/images/items/bloodthorn_png.vtex_c")
    UI.SmartBloodthorn:ToolTip("Умное использование Orchid/Bloodthorn с учетом HP врага и Manta Style")

    local blood_gear = UI.SmartBloodthorn:Gear("Настройки Bloodthorn")
    UI.BloodthornRange = blood_gear:Slider("Дальность каста", 500, 1100, 900, "%d")
    UI.BloodthornRange:ToolTip("Максимальная дальность для использования предмета")

    UI.BloodthornHPThreshold = blood_gear:Slider("Порог HP (%)", 30, 100, 70, "%d")
    UI.BloodthornHPThreshold:ToolTip("Использовать только если HP врага ниже этого порога")

    UI.BloodthornDelay = blood_gear:Slider("Задержка каста (мс)", 0, 500, 100, "%d")
    UI.BloodthornDelay:ToolTip("Задержка перед использованием (для ожидания Manta)")

    -- === ПОМОЩНИК ПАУТИНЫ ===
    local g_web = main:Create("Помощник паутины")

    UI.WebHelperEnabled = g_web:Switch("Показать точки паутины", true, "panorama/images/spellicons/broodmother_spin_web_png.vtex_c")
    UI.WebHelperEnabled:ToolTip("Показывает оптимальные точки для размещения паутины на карте")
    local web_gear = UI.WebHelperEnabled:Gear("Настройки отображения")
    UI.ShowWebPointsOnlyAlt = web_gear:Switch("Показывать только при ALT", false)
    UI.ShowWebPointsOnlyAlt:ToolTip("Точки паутины будут видны только при зажатом ALT")

    UI.WebClickToCast = web_gear:Switch("Клик для каста", true)
    UI.WebClickToCast:ToolTip("Клик по точке автоматически кастует паутину в это место")

    -- === LANE PULL (ПУЛЛ КРИПОВ ПАУКАМИ) ===
    local g_pull = main:Create("Пулл крипов пауками")

    UI.PullEnabled = g_pull:Switch("Включить lane pull", true, "\u{f0c1}")
    UI.PullEnabled:ToolTip("Отправляет паука на линию для агра вражеской волны и отвода к герою; учитывает вражеские вышки")

    UI.PullKey = g_pull:Bind("Кнопка пулла", Enum.ButtonCode.KEY_NONE, "\u{f11c}")
    UI.PullKey:ToolTip("Запускает pull. Поведение кнопки задаётся режимом ниже (Hold/Toggle)")

    local pull_gear = UI.PullKey:Gear("Настройки пулла")

    UI.PullMode = pull_gear:Combo("Режим активации", {"Зажатие (Hold)", "Переключение (Toggle)"}, 0)
    UI.PullMode:ToolTip("Hold — пулл работает пока кнопка зажата. Toggle — одно нажатие включает, второе выключает")

    UI.PullLaneCount = pull_gear:Slider("Количество линий", 1, 3, 2, "%d")
    UI.PullLaneCount:ToolTip("Сколько ближайших линий одновременно обрабатывать: 1, 2 или 3")

    local pull_vis = UI.PullEnabled:Gear("Визуальные настройки")

    UI.PullShowLines = pull_vis:Switch("Показать линии маршрута", true)
    UI.PullShowLines:ToolTip("Рисует линии от паука к точке назначения. Цвет зависит от фазы: синий = идёт, жёлтый = ждёт, красный = агрит, оранжевый = возвращается")

    UI.PullShowText = pull_vis:Switch("Текст 'Pulling...' над героем", true)
    UI.PullShowText:ToolTip("Показывает текст над героем, когда пулл активен — удобно для отслеживания статуса")

    return UI
end

local UI = InitializeUI()
local panelX, panelY = LoadPanelPosition()
followRole = followRole or {}
followLastOrder = followLastOrder or {}
chaseRole = chaseRole or {}
chaseLastOrder = chaseLastOrder or {}
splitRole = splitRole or {}
splitTarget = splitTarget or {}
playerOverrideRole = playerOverrideRole or {}
playerOverrideUntil = playerOverrideUntil or {}
farmRole = farmRole or {}
farmLastOrder = farmLastOrder or {}

local HeroIconCache = {}
local AbilityIconCache = {}
local spiderCache = {}
local lastCacheUpdate = 0

local State = {
    lastSoulRingTime = 0,
    juggling = false,
    juggleWasDown = false,
    juggleToggleActive = false,
    juggleActiveIds = {},
    lastJuggleOrderTime = 0,
    lastGatherTime = 0,
    lastGatherPos = nil,
    spiderlingCount = 0,
    spideriteCount = 0,
    juggleTime = 0,
    panelPos = {x = panelX, y = panelY},
    isDragging = false,
    dragOffset = {x = 0, y = 0},
    webPoints = BuiltInWebPoints,
    webMouseWasDown = false,
    webAltAlpha = 0,
    panelAnimation = {
        cellsAlpha = 0,
        titleAlpha = 255,
        headerAlpha = 255,
        cellsTargetAlpha = 0,
        titleTargetAlpha = 255,
        headerTargetAlpha = 255,
        lastSpiderCount = 0,
        headerInCellsPosition = true
    },
}

-- ═══════════════════════════════════════════════════════════════════════════
--  Пауки: кэш, контроль, переопределение игроком
-- ═══════════════════════════════════════════════════════════════════════════

local function GetAllSpiders()
    local now = os.clock()
    if now - lastCacheUpdate < SPIDER_CACHE_TTL then
        return spiderCache
    end

    local myHero = Heroes.GetLocal()
    if not myHero then
        spiderCache = {}
        return spiderCache
    end

    local playerId = Hero.GetPlayerID(myHero)
    local allNPCs = NPCs.GetAll()
    local result = {}
    local spiderlingCount = 0
    local spideriteCount = 0

    for i = 1, #allNPCs do
        local npc = allNPCs[i]
        if Entity.IsAlive(npc) and Entity.IsControllableByPlayer(npc, playerId) then
            local unitName = NPC.GetUnitName(npc)
            if unitName == "npc_dota_broodmother_spiderling" then
                result[#result + 1] = npc
                spiderlingCount = spiderlingCount + 1
            elseif unitName == "npc_dota_broodmother_spiderite" then
                spideriteCount = spideriteCount + 1
            end
        end
    end

    State.spiderlingCount = spiderlingCount
    State.spideriteCount = spideriteCount
    spiderCache = result
    lastCacheUpdate = now

    return result
end

local function IsSpiderUnderPlayerOverride(spider)
    local id = Entity.GetIndex(spider)
    local untilTime = playerOverrideUntil[id]
    return untilTime and os.clock() < untilTime
end

local function GetControllableSpiders()
    local spiders = GetAllSpiders()
    local result = {}

    for i = 1, #spiders do
        if not IsSpiderUnderPlayerOverride(spiders[i]) then
            result[#result + 1] = spiders[i]
        end
    end
    return result
end

local function CleanupPlayerOverride()
    local now = os.clock()
    local toRemove = {}

    for id, t in pairs(playerOverrideUntil) do
        if now >= t then
            toRemove[#toRemove + 1] = id
        end
    end

    for i = 1, #toRemove do
        local id = toRemove[i]
        playerOverrideUntil[id] = nil
        playerOverrideRole[id] = nil
    end

    local alive = {}
    local spiders = GetAllSpiders()
    for i = 1, #spiders do
        alive[Entity.GetIndex(spiders[i])] = true
    end

    for id, _ in pairs(playerOverrideRole) do
        if not alive[id] then
            playerOverrideRole[id] = nil
            playerOverrideUntil[id] = nil
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
--  Авто-логика: следование, чейз, сплит, фарм
-- ═══════════════════════════════════════════════════════════════════════════

local function AutoFollowSpiders()
    if not UI.AutoFollow:Get() then return end
    local spiders = GetControllableSpiders()
    local myHero = Heroes.GetLocal()
    if not myHero or #spiders == 0 then return end

    local now = os.clock()
    local enemies = Entity.GetHeroesInRadius(myHero, 1200, Enum.TeamType.TEAM_ENEMY, true) or {}

    if #enemies > 0 then
        for i = 1, #spiders do
            followRole[Entity.GetIndex(spiders[i])] = nil
        end
        return
    end

    local freeSpiders = {}
    for i = 1, #spiders do
        local id = Entity.GetIndex(spiders[i])
        if not chaseRole[id] and not splitRole[id] and not farmRole[id] then
            freeSpiders[#freeSpiders + 1] = spiders[i]
        else
            followRole[id] = nil
        end
    end

    local count = math.min(UI.AutoFollowCount:Get(), #freeSpiders)
    local selected = {}
    for i = 1, count do
        if freeSpiders[i] then
            local id = Entity.GetIndex(freeSpiders[i])
            followRole[id] = true
            selected[#selected + 1] = freeSpiders[i]
        end
    end

    for i = 1, #spiders do
        local id = Entity.GetIndex(spiders[i])
        if not chaseRole[id] and not splitRole[id] and not farmRole[id] then
            local found = false
            for j = 1, #selected do
                if Entity.GetIndex(selected[j]) == id then
                    found = true
                    break
                end
            end
            if not found then
                followRole[id] = nil
            end
        elseif followRole[id] then
            followRole[id] = nil
        end
    end

    for i = 1, #selected do
        local spider = selected[i]
        local id = Entity.GetIndex(spider)
        local heroPos = Entity.GetAbsOrigin(myHero)
        local spiderPos = Entity.GetAbsOrigin(spider)
        local distToHero = (spiderPos - heroPos):Length2D()
        local followRadius = UI.AutoFollowRadius:Get()

        -- Use ORDER_INTERVAL_FAR for spiders that are far away (beyond 2x follow radius)
        local interval = (distToHero > followRadius * 2) and ORDER_INTERVAL_FAR or ORDER_INTERVAL_FOLLOW

        if not followLastOrder[id] or (now - followLastOrder[id] > interval) then
            local radius = followRadius
            local angle = math.rad(math.random(0, 359))
            local dist = math.random(100, radius)
            local offset = Vector(math.cos(angle), math.sin(angle), 0) * dist
            local targetPos = heroPos + offset

            Player.PrepareUnitOrders(
                Players.GetLocal(),
                Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION,
                nil,
                targetPos,
                nil,
                Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                spider,
                false, false, false, false,
                "brood_auto_follow"
            )
            followLastOrder[id] = now
        end
    end
end

local function IsHeroUnderPressure(myHero)
    if not myHero then return false end
    local enemies = Entity.GetHeroesInRadius(myHero, 1200, Enum.TeamType.TEAM_ENEMY, true) or {}
    if #enemies > 0 then return true end
    if NPC.IsAttacking(myHero) then return true end
    return false
end

local function AutoChaseEnemies()
    if not UI.AutoChase:Get() then return end
    local spiders = GetControllableSpiders()
    local myHero = Heroes.GetLocal()
    if not myHero or #spiders == 0 then return end

    local now = os.clock()
    local radius = UI.AutoChaseRadius:Get()
    local enemies = Entity.GetHeroesInRadius(myHero, radius, Enum.TeamType.TEAM_ENEMY, true) or {}

    if #enemies == 0 then
        for i = 1, #spiders do
            chaseRole[Entity.GetIndex(spiders[i])] = nil
        end
        return
    end

    for i = 1, #spiders do
        local spider = spiders[i]
        local id = Entity.GetIndex(spider)
        if not followRole[id] and not splitRole[id] then
            local closestEnemy = nil
            local closestDist = math.huge

            local spiderPos = Entity.GetAbsOrigin(spider)
            for j = 1, #enemies do
                local enemy = enemies[j]
                if Entity.IsAlive(enemy) then
                    local enemyPos = Entity.GetAbsOrigin(enemy)
                    local dist = (spiderPos - enemyPos):Length()
                    if dist < closestDist then
                        closestDist = dist
                        closestEnemy = enemy
                    end
                end
            end

            if closestEnemy then
                chaseRole[id] = true
                if not chaseLastOrder[id] or (now - chaseLastOrder[id] > ORDER_INTERVAL_CHASE) then
                    Player.PrepareUnitOrders(
                        Players.GetLocal(),
                        Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET,
                        closestEnemy,
                        Vector(0, 0, 0),
                        nil,
                        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                        spider,
                        false, false, false, false,
                        "brood_auto_chase"
                    )
                    chaseLastOrder[id] = now
                end
            end
        else
            chaseRole[id] = nil
        end
    end
end

local function AutoSplitAttack()
    if not UI.AutoSplit:Get() then return end
    local spiders = GetControllableSpiders()
    local myHero = Heroes.GetLocal()
    if not myHero or #spiders == 0 then return end

    local enemies = Entity.GetHeroesInRadius(myHero, 1200, Enum.TeamType.TEAM_ENEMY, true) or {}

    if #enemies < 2 then
        for i = 1, #spiders do
            local id = Entity.GetIndex(spiders[i])
            splitRole[id] = nil
            splitTarget[id] = nil
        end
        return
    end

    local targetCounts = {}
    for i = 1, #spiders do
        local id = Entity.GetIndex(spiders[i])
        local target = splitTarget[id]
        if target and Entity.IsAlive(target) then
            local targetId = Entity.GetIndex(target)
            targetCounts[targetId] = (targetCounts[targetId] or 0) + 1
        end
    end

    local maxPerTarget = UI.AutoSplitMax:Get()
    for i = 1, #spiders do
        local spider = spiders[i]
        local id = Entity.GetIndex(spider)
        if not followRole[id] then
            local currentTarget = splitTarget[id]
            local needNewTarget = false

            if currentTarget then
                local targetId = Entity.GetIndex(currentTarget)
                if not Entity.IsAlive(currentTarget) or (targetCounts[targetId] or 0) > maxPerTarget then
                    needNewTarget = true
                end
            else
                needNewTarget = true
            end

            if needNewTarget then
                local bestTarget = nil
                local lowestCount = math.huge
                for j = 1, #enemies do
                    local enemy = enemies[j]
                    if Entity.IsAlive(enemy) then
                        local enemyId = Entity.GetIndex(enemy)
                        local count = targetCounts[enemyId] or 0
                        if count < lowestCount and count < maxPerTarget then
                            lowestCount = count
                            bestTarget = enemy
                        end
                    end
                end

                if bestTarget then
                    splitTarget[id] = bestTarget
                    targetCounts[Entity.GetIndex(bestTarget)] = lowestCount + 1
                    splitRole[id] = true

                    Player.PrepareUnitOrders(
                        Players.GetLocal(),
                        Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET,
                        bestTarget,
                        Vector(0, 0, 0),
                        nil,
                        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                        spider,
                        false, false, false, false,
                        "brood_auto_split"
                    )
                end
            end
        else
            splitRole[id] = nil
            splitTarget[id] = nil
        end
    end
end

local function AutoFarmCreeps()
    if not UI.AutoFarmCreeps:Get() then return end

    local myHero = Heroes.GetLocal()
    if not myHero or not Entity.IsAlive(myHero) then return end

    local myPlayer = Players.GetLocal()
    if not myPlayer then return end

    local now = os.clock()

    if IsHeroUnderPressure(myHero) then
        local spiders = GetAllSpiders()
        for i = 1, #spiders do
            farmRole[Entity.GetIndex(spiders[i])] = nil
        end
        return
    end

    local spiders = GetControllableSpiders()
    if #spiders == 0 then return end

    local heroPos = Entity.GetAbsOrigin(myHero)
    local farmRadius = UI.AutoFarmRadius:Get()
    local allNPCs = NPCs.GetAll()
    local targets = {}

    for i = 1, #allNPCs do
        local npc = allNPCs[i]
        if Entity.IsAlive(npc) and NPC.IsCreep(npc) and not NPC.IsAncient(npc) then
            if Entity.GetTeamNum(npc) ~= Entity.GetTeamNum(myHero) then
                local npcPos = Entity.GetAbsOrigin(npc)
                local dist = (heroPos - npcPos):Length()
                if dist <= farmRadius then
                    targets[#targets + 1] = npc
                end
            end
        end
    end

    if #targets < 3 then
        local campRange = UI.AutoFarmCampRange:Get()
        for i = 1, #allNPCs do
            local npc = allNPCs[i]
            if Entity.IsAlive(npc) and NPC.IsCreep(npc) and not NPC.IsAncient(npc) then
                if Entity.GetTeamNum(npc) ~= Entity.GetTeamNum(myHero) then
                    local npcPos = Entity.GetAbsOrigin(npc)
                    local dist = (heroPos - npcPos):Length()
                    if dist <= farmRadius + campRange then
                        local alreadyInTargets = false
                        for j = 1, #targets do
                            if targets[j] == npc then
                                alreadyInTargets = true
                                break
                            end
                        end
                        if not alreadyInTargets then
                            targets[#targets + 1] = npc
                        end
                    end
                end
            end
        end
    end

    if #targets == 0 then
        for i = 1, #spiders do
            farmRole[Entity.GetIndex(spiders[i])] = nil
        end
        return
    end

    for i = 1, #spiders do
        local spider = spiders[i]
        local spiderId = Entity.GetIndex(spider)

        if chaseRole[spiderId] or splitRole[spiderId] then
            farmRole[spiderId] = nil
            farmLastOrder[spiderId] = nil
        else
            farmRole[spiderId] = true
            followRole[spiderId] = nil

            local spiderPos = Entity.GetAbsOrigin(spider)
            local bestTarget = nil
            local bestDist = math.huge

            for j = 1, #targets do
                local target = targets[j]
                if Entity.IsAlive(target) then
                    local targetPos = Entity.GetAbsOrigin(target)
                    local dist = (spiderPos - targetPos):Length()
                    if dist < bestDist then
                        bestDist = dist
                        bestTarget = target
                    end
                end
            end

            if bestTarget and (not farmLastOrder[spiderId] or (now - farmLastOrder[spiderId] > ORDER_INTERVAL_FARM)) then
                Player.PrepareUnitOrders(
                    myPlayer,
                    Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET,
                    bestTarget,
                    Vector(0, 0, 0),
                    nil,
                    Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                    spider,
                    false, false, false, false,
                    "brood_auto_farm"
                )
                farmLastOrder[spiderId] = now
            end
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
--  Авто-стак нейтральных кампов паучками (:53–:55), как в Auto Stacker By GLTM
--  Используем ATTACK_MOVE в центр кампа — паук идёт бить, нейтралы выходят.
-- ═══════════════════════════════════════════════════════════════════════════

local function vecX(v)
    if not v then return 0 end
    return type(v.GetX) == "function" and v:GetX() or (v.x or 0)
end
local function vecY(v)
    if not v then return 0 end
    return type(v.GetY) == "function" and v:GetY() or (v.y or 0)
end
local function vecZ(v)
    if not v then return 0 end
    return type(v.GetZ) == "function" and v:GetZ() or (v.z or 0)
end

local function GetCampBoxCenter(camp)
    if not camp then return nil end
    local box = Camp.GetCampBox(camp)
    if not box or not box.min or not box.max then return nil end
    local cx = (vecX(box.min) + vecX(box.max)) * 0.5
    local cy = (vecY(box.min) + vecY(box.max)) * 0.5
    local cz = (vecZ(box.min) + vecZ(box.max)) * 0.5
    return Vector(cx, cy, cz)
end

-- ─── Стак по кнопке (логика GLTM): точки кампа, ближайший лагерь, strike center ───
local function GetStackCampPoints(campId)
    return CAMP_POINTS[campId]
end

local function StackGameTimeSeconds()
    local t = (GameRules.GetGameTime() or 0) - (GameRules.GetGameStartTime and GameRules.GetGameStartTime() or 0)
    return t < 0 and 0 or t
end

local function FindClosestRealCamp(pos)
    local all = (Camps and Camps.GetAll and Camps.GetAll()) or {}
    if not all or #all == 0 then return nil end
    local bestCamp, bestDist = nil, math.huge
    for _, c in ipairs(all) do
        local center = GetCampBoxCenter(c)
        if center then
            local d = (center - pos):Length2D()
            if d < bestDist then
                bestDist = d
                bestCamp = c
            end
        end
    end
    return bestCamp
end

local function EnsureStrikeCenterForCamp(campId)
    if stackCampStrikeCenters[campId] then return end
    local points = GetStackCampPoints(campId)
    if not points then return end
    local realCamp = FindClosestRealCamp(points.wait)
    if not realCamp then return end
    local center = GetCampBoxCenter(realCamp)
    if center then
        stackCampStrikeCenters[campId] = center
        local box = Camp.GetCampBox(realCamp)
        if box and box.min and box.max then
            stackCampBoxes[campId] = { min = box.min, max = box.max }
        end
    end
end

local function AssignSpidersToNearestCamps(units)
    local assignment = {}
    local availableCampIds = {}
    local stackRadius = (UI.StackRadius and UI.StackRadius:Get()) or math.huge
    for campId, _ in pairs(CAMP_POINTS) do
        availableCampIds[#availableCampIds + 1] = campId
    end
    -- Храним по индексу сущности, чтобы не получать bad argument (entity может стать числом в ключе)
    if #units <= #availableCampIds then
        for _, u in ipairs(units) do
            local unitPos = Entity.GetAbsOrigin(u)
            if unitPos then
                local bestCamp, bestDist, bestIdx = nil, math.huge, nil
                for idx, campId in ipairs(availableCampIds) do
                    local pts = GetStackCampPoints(campId)
                    if pts then
                        local d = (pts.wait - unitPos):Length2D()
                        if d <= stackRadius and d < bestDist then
                            bestDist = d
                            bestCamp = campId
                            bestIdx = idx
                        end
                    end
                end
                if bestCamp then
                    assignment[Entity.GetIndex(u)] = bestCamp
                    table.remove(availableCampIds, bestIdx)
                end
            end
        end
    else
        for _, u in ipairs(units) do
            local unitPos = Entity.GetAbsOrigin(u)
            if unitPos then
                local bestCamp, bestDist = nil, math.huge
                for campId, _ in pairs(CAMP_POINTS) do
                    local pts = GetStackCampPoints(campId)
                    if pts then
                        local d = (pts.wait - unitPos):Length2D()
                        if d <= stackRadius and d < bestDist then
                            bestDist = d
                            bestCamp = campId
                        end
                    end
                end
                if bestCamp then assignment[Entity.GetIndex(u)] = bestCamp end
            end
        end
    end
    return assignment
end

local function EnsureStackTimelineFor(unitOrIndex, minute)
    local idx = type(unitOrIndex) == "number" and unitOrIndex or Entity.GetIndex(unitOrIndex)
    if not idx then return nil end
    if not stackTimeline[idx] then stackTimeline[idx] = {} end
    if not stackTimeline[idx][minute] then
        stackTimeline[idx][minute] = {
            movedToWait = false,
            attackIssued = false,
            hitConfirmed = false,
            pullIssued = false,
        }
    end
    return stackTimeline[idx][minute]
end

local function PointInsideBox(pos, box, margin)
    if not box or not box.min or not box.max then return false end
    margin = margin or 0
    local x, y = pos:GetX(), pos:GetY()
    return (x >= (vecX(box.min) - margin)) and (x <= (vecX(box.max) + margin))
        and (y >= (vecY(box.min) - margin)) and (y <= (vecY(box.max) + margin))
end

local function EvaluateCampStacks(campId)
    local box = stackCampBoxes[campId]
    if not box then return 0 end
    local all = Entities.GetAll and Entities.GetAll() or {}
    local maxStacks = 0
    for _, e in pairs(all) do
        if Entity.IsAlive(e) and Entity.IsNPC(e) and NPC.IsCreep(e)
            and not (NPC.IsLaneCreep and NPC.IsLaneCreep(e)) and not (NPC.IsHero and NPC.IsHero(e)) then
            local pos = Entity.GetAbsOrigin(e)
            if pos and PointInsideBox(pos, box, 200) then
                local mod = NPC.GetModifier and NPC.GetModifier(e, "modifier_stacked_neutral")
                if mod then
                    local c = Modifier.GetStackCount and Modifier.GetStackCount(mod) or 0
                    if c > maxStacks then maxStacks = c end
                end
            end
        end
    end
    return maxStacks
end

local function StackMoveUnitTo(player, unit, pos)
    if not unit or not Entity.IsAlive(unit) or not pos then return end
    Player.PrepareUnitOrders(
        player,
        Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION,
        nil,
        pos,
        nil,
        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
        unit,
        false, false, false, false,
        "brood_stack_move"
    )
end

local function StackAttackMoveUnitTo(player, unit, pos)
    if not unit or not Entity.IsAlive(unit) or not pos then return end
    Player.PrepareUnitOrders(
        player,
        Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_MOVE,
        nil,
        pos,
        nil,
        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
        unit,
        false, false, false, false,
        "brood_stack_attack"
    )
end

local function BeginStackSession()
    local spiders = GetControllableSpiders()
    if #spiders == 0 then return false end
    stackUnitToCampId = AssignSpidersToNearestCamps(spiders)
    stackLastCampStacks = {}
    for _, campId in pairs(stackUnitToCampId) do
        EnsureStrikeCenterForCamp(campId)
    end
    stackTimeline = {}
    return true
end

local function AutoStackCampsLogic()
    if not UI.AutoStackCamps or not UI.AutoStackCamps:Get() then return end
    local myPlayer = Players.GetLocal()
    if not myPlayer then return end

    -- Переключение сессии по кнопке (без выделения пауков)
    local keyPressed = UI.StackKey and UI.StackKey:IsPressed()
    if keyPressed and not stackWasKeyHeld then
        stackSessionActive = not stackSessionActive
        if stackSessionActive then
            if not BeginStackSession() then
                stackSessionActive = false
            end
        else
            stackUnitToCampId = {}
            stackTimeline = {}
        end
    end
    stackWasKeyHeld = keyPressed
    if not stackSessionActive then return end

    -- Живые пауки из текущего назначения (по индексу, берём актуальные entity из текущего кадра)
    local alive = {}
    local spiders = GetControllableSpiders()
    for i = 1, #spiders do
        local u = spiders[i]
        local id = Entity.GetIndex(u)
        if id and stackUnitToCampId[id] and Entity.IsAlive(u) then
            alive[#alive + 1] = u
        end
    end
    if #alive == 0 then
        stackSessionActive = false
        return
    end

    local t = StackGameTimeSeconds()
    local minute = math.floor(t / 60)
    local sec = t % 60
    -- Паучки мелевые, baseHit = STACK_FIRST_HIT_MELEE
    local baseHit = STACK_FIRST_HIT_MELEE

    for _, u in ipairs(alive) do
        local campId = stackUnitToCampId[Entity.GetIndex(u)]
        if not campId then goto continue_unit end
        local points = GetStackCampPoints(campId)
        local strike = stackCampStrikeCenters[campId]
        if not strike then
            EnsureStrikeCenterForCamp(campId)
            strike = stackCampStrikeCenters[campId]
            if not strike then goto continue_unit end
        end
        local st = EnsureStackTimelineFor(u, minute)

        -- Обновление стаков по кампу (раз в минуту)
        if sec >= 50 then
            if (stackCampStacksMinute[campId] or -1) ~= minute then
                local stacksNow = EvaluateCampStacks(campId)
                local lastStacks = stackLastCampStacks[campId] or 0
                stackCampStacks[campId] = stacksNow
                stackCampStacksMinute[campId] = minute
                stackLastCampStacks[campId] = stacksNow
            end
        end
        local stacks = stackCampStacks[campId] or 0
        local effFirstHit = math.max(52, math.min(54, baseHit - (stacks * STACK_PER_STACK_SHIFT)))

        if sec < effFirstHit then
            if not st.movedToWait then
                st.movedToWait = true
                StackMoveUnitTo(myPlayer, u, points.wait)
            end
        else
            if (sec >= effFirstHit) and (sec < (effFirstHit + 2)) and not st.attackIssued then
                st.attackIssued = true
                StackAttackMoveUnitTo(myPlayer, u, strike)
            end
            if st.hitConfirmed and not st.pullIssued then
                st.pullIssued = true
                StackMoveUnitTo(myPlayer, u, points.pull)
            elseif (sec >= 57) and (sec < 58) and not st.pullIssued then
                st.pullIssued = true
                StackMoveUnitTo(myPlayer, u, points.pull)
            end
        end
        ::continue_unit::
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
--  Lane Pull: вспомогательные функции и основная логика
-- ═══════════════════════════════════════════════════════════════════════════

local function PullDist2D(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

local function PullGetClockData()
    local realNow = GameRules.GetGameTime()
    local startTime = (GameRules.GetGameStartTime and GameRules.GetGameStartTime()) or 0
    local clockNow = realNow - startTime
    if clockNow < 0 then clockNow = 0 end
    return realNow, clockNow
end

local function PullGetSpiderRemainingLife(spider)
    if not spider then return 0 end
    local mods = NPC.GetModifiers(spider)
    if not mods or #mods == 0 then return 0 end
    local now = GameRules.GetGameTime()
    local best = 0
    for _, m in ipairs(mods) do
        local die = Modifier.GetDieTime(m)
        if die and die > 0 then
            local rem = die - now
            if rem > best then best = rem end
        end
    end
    return best
end

local function PullIsSpiderAssigned(spider)
    for _, asg in ipairs(PullState.assignments) do
        if asg.spider == spider then return true end
    end
    return false
end

local function PullGetAvailableSpiders()
    local spiders = GetAllSpiders()
    local available = {}
    for _, s in ipairs(spiders) do
        if not PullIsSpiderAssigned(s) then
            table.insert(available, s)
        end
    end
    table.sort(available, function(a, b)
        local lifeA = PullGetSpiderRemainingLife(a)
        local lifeB = PullGetSpiderRemainingLife(b)
        if math.abs(lifeA - lifeB) > 3 then
            return lifeA > lifeB
        end
        local hpA = Entity.GetHealth(a) or 0
        local hpB = Entity.GetHealth(b) or 0
        return hpA > hpB
    end)
    return available
end

local function PullGetEnemyTowers()
    local now = GameRules.GetGameTime()
    if PullState.cachedTowers and (now - PullState.cachedTowersTime) < 2 then
        return PullState.cachedTowers
    end
    local myHero = Heroes.GetLocal()
    if not myHero then return {} end
    PullState.cachedTowers = {}
    local allNPCs = NPCs.GetAll()
    for _, npc in ipairs(allNPCs) do
        if Entity.IsAlive(npc) and not Entity.IsSameTeam(npc, myHero) and NPC.IsTower(npc) then
            table.insert(PullState.cachedTowers, {
                entity = npc,
                pos = Entity.GetAbsOrigin(npc),
                name = NPC.GetUnitName(npc),
            })
        end
    end
    PullState.cachedTowersTime = now
    return PullState.cachedTowers
end

local function PullIsPathNearTower(from, to, safeRadius)
    local towers = PullGetEnemyTowers()
    for _, tower in ipairs(towers) do
        local tp = tower.pos
        local dx, dy = to.x - from.x, to.y - from.y
        local lenSq = dx * dx + dy * dy
        if lenSq > 0 then
            local t = math.max(0, math.min(1,
                ((tp.x - from.x) * dx + (tp.y - from.y) * dy) / lenSq
            ))
            local closestX = from.x + t * dx
            local closestY = from.y + t * dy
            local dist = math.sqrt((tp.x - closestX)^2 + (tp.y - closestY)^2)
            if dist < safeRadius then
                return true, tower
            end
        end
    end
    return false, nil
end

local function PullGetSafeRetreatPos(lanePoint, heroPos, safeRadius)
    local dangerous, tower = PullIsPathNearTower(lanePoint, heroPos, safeRadius)
    if not dangerous then return heroPos end
    local tp = tower.pos
    local midX = (lanePoint.x + heroPos.x) / 2
    local midY = (lanePoint.y + heroPos.y) / 2
    local dx, dy = heroPos.x - lanePoint.x, heroPos.y - lanePoint.y
    local perpX, perpY = -dy, dx
    local perpLen = math.sqrt(perpX * perpX + perpY * perpY)
    if perpLen > 0 then perpX, perpY = perpX / perpLen, perpY / perpLen end
    local side1X = midX + perpX * (safeRadius + 200)
    local side1Y = midY + perpY * (safeRadius + 200)
    local side2X = midX - perpX * (safeRadius + 200)
    local side2Y = midY - perpY * (safeRadius + 200)
    local dist1 = math.sqrt((tp.x - side1X)^2 + (tp.y - side1Y)^2)
    local dist2 = math.sqrt((tp.x - side2X)^2 + (tp.y - side2Y)^2)
    local waypointX, waypointY
    if dist1 > dist2 then
        waypointX, waypointY = side1X, side1Y
    else
        waypointX, waypointY = side2X, side2Y
    end
    return Vector(waypointX, waypointY, lanePoint.z)
end

local function PullGetTeamLanes()
    local myHero = Heroes.GetLocal()
    if not myHero then return nil end
    local team = Entity.GetTeamNum(myHero)
    if team == Enum.TeamNum.TEAM_RADIANT then
        return PullLanePoints.radiant, "radiant"
    elseif team == Enum.TeamNum.TEAM_DIRE then
        return PullLanePoints.dire, "dire"
    end
    return nil, nil
end

local function PullGetClosestLanes(heroPos, count)
    local lanes, teamKey = PullGetTeamLanes()
    if not lanes then return {} end
    local sorted = {}
    for i, lane in ipairs(lanes) do
        table.insert(sorted, {
            idx = i,
            lane = lane,
            dist = PullDist2D(heroPos, lane.pos),
            teamKey = teamKey,
        })
    end
    table.sort(sorted, function(a, b) return a.dist < b.dist end)
    local result = {}
    for i = 1, math.min(count, #sorted) do
        table.insert(result, sorted[i])
    end
    return result
end

local function PullGetNextCreepSpawnClock(clockNow)
    local interval = 30
    local next = math.ceil(clockNow / interval) * interval
    if next <= clockNow then next = next + interval end
    return next
end

local function PullGetTimeUntilCreepsArrive(clockNow, teamKey, laneName)
    local nextSpawn = PullGetNextCreepSpawnClock(clockNow)
    local timeUntilSpawn = nextSpawn - clockNow
    local travelTime = 0
    if PullCreepTravelTime[teamKey] and PullCreepTravelTime[teamKey][laneName] then
        travelTime = PullCreepTravelTime[teamKey][laneName]
    end
    return timeUntilSpawn + travelTime, nextSpawn
end

local function PullGetSpiderTravelTime(spider, targetPos)
    local spiderPos = Entity.GetAbsOrigin(spider)
    local dist = PullDist2D(spiderPos, targetPos)
    local speed = NPC.GetMoveSpeed(spider) or 350
    return dist / speed
end

local function PullBuildGridNavPath(spider, startPos, goalPos)
    local npcMap = GridNav.CreateNpcMap({ spider }, true)
    local path = GridNav.BuildPath(startPos, goalPos, false, npcMap)
    GridNav.ReleaseNpcMap(npcMap)
    return path
end

local function PullHasEnemyCreepsNear(pos, radius)
    local myHero = Heroes.GetLocal()
    if not myHero then return false end
    local heroPos = Entity.GetAbsOrigin(myHero)
    local heroToPos = PullDist2D(heroPos, pos)
    local searchRadius = heroToPos + radius + 500
    local units = Entity.GetUnitsInRadius(myHero, searchRadius, Enum.TeamType.TEAM_ENEMY)
    for _, npc in ipairs(units) do
        if Entity.IsAlive(npc) and not Entity.IsDormant(npc) and NPC.IsLaneCreep(npc) then
            local creepPos = Entity.GetAbsOrigin(npc)
            if PullDist2D(pos, creepPos) < radius then
                return true
            end
        end
    end
    return false
end

local function PullDispatch()
    local myHero = Heroes.GetLocal()
    if not myHero then return end
    local myPlayer = Players.GetLocal()
    if not myPlayer then return end

    local heroPos = Entity.GetAbsOrigin(myHero)
    local _, clockNow = PullGetClockData()
    local laneCount = UI.PullLaneCount:Get()
    local safeRadius = 900

    local closestLanes = PullGetClosestLanes(heroPos, laneCount)
    if #closestLanes == 0 then return end

    local available = PullGetAvailableSpiders()
    if #available == 0 then return end

    local now = GameRules.GetGameTime()
    local spiderIdx = 1

    for _, laneInfo in ipairs(closestLanes) do
        if spiderIdx > #available then break end

        local lane = laneInfo.lane
        local lanePos = lane.pos
        local teamKey = laneInfo.teamKey

        local retreatPos = PullGetSafeRetreatPos(lanePos, heroPos, safeRadius)

        local spider = available[spiderIdx]
        local travelTime = PullGetSpiderTravelTime(spider, lanePos)
        local remainLife = PullGetSpiderRemainingLife(spider)

        local totalNeeded = travelTime + 1.25 + 5
        if remainLife > 0 and remainLife < totalNeeded then
            local found = false
            for j = spiderIdx + 1, #available do
                local alt = available[j]
                local altLife = PullGetSpiderRemainingLife(alt)
                local altTravel = PullGetSpiderTravelTime(alt, lanePos)
                if altLife == 0 or altLife >= (altTravel + 1.25 + 5) then
                    available[spiderIdx], available[j] = available[j], available[spiderIdx]
                    spider = available[spiderIdx]
                    travelTime = altTravel
                    found = true
                    break
                end
            end
            if not found then
                spiderIdx = spiderIdx + 1
                goto nextLane
            end
        end

        local creepArrivalTime, _ = PullGetTimeUntilCreepsArrive(clockNow, teamKey, lane.name)

        local spiderStartPos = Entity.GetAbsOrigin(spider)
        local dangerous, _ = PullIsPathNearTower(spiderStartPos, lanePos, safeRadius)
        local towerWaypoint = nil

        if dangerous then
            towerWaypoint = PullGetSafeRetreatPos(spiderStartPos, lanePos, safeRadius)
        end

        local firstTarget = towerWaypoint or lanePos

        Player.PrepareUnitOrders(
            myPlayer,
            Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION,
            nil,
            firstTarget,
            nil,
            Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
            spider,
            false, false, false, false,
            "brood_pull_travel"
        )

        table.insert(PullState.assignments, {
            spider = spider,
            lanePos = lanePos,
            retreatPos = retreatPos,
            laneName = lane.name,
            teamKey = teamKey,
            phase = "travel",
            phaseTime = now,
            travelTime = travelTime,
            creepArrivalTime = creepArrivalTime,
            dispatchTime = now,
            towerWaypoint = towerWaypoint,
            towerWPReached = not towerWaypoint,
            lastSteerTime = now,
        })

        spiderIdx = spiderIdx + 1
        ::nextLane::
    end

    PullState.lastDispatchClock = clockNow
end

local function PullUpdateAssignments()
    local myPlayer = Players.GetLocal()
    if not myPlayer then return end
    local myHero = Heroes.GetLocal()

    local now = GameRules.GetGameTime()
    local aggroDuration = 1.25
    local safeRadius = 900

    for i = #PullState.assignments, 1, -1 do
        local asg = PullState.assignments[i]
        local spider = asg.spider

        if not spider or not Entity.IsAlive(spider) then
            table.remove(PullState.assignments, i)
            goto continue
        end

        local spiderPos = Entity.GetAbsOrigin(spider)

        if asg.phase == "travel" then
            local distToLane = PullDist2D(spiderPos, asg.lanePos)
            if distToLane < 250 then
                asg.phase = "wait"
                asg.phaseTime = now
            elseif now - asg.phaseTime > 30 then
                table.remove(PullState.assignments, i)
            else
                if not asg.towerWPReached and asg.towerWaypoint then
                    if PullDist2D(spiderPos, asg.towerWaypoint) < 200 then
                        asg.towerWPReached = true
                    end
                end
                if now - asg.lastSteerTime >= 0.5 then
                    local target
                    if not asg.towerWPReached and asg.towerWaypoint then
                        target = asg.towerWaypoint
                    else
                        target = asg.lanePos
                    end
                    Player.PrepareUnitOrders(
                        myPlayer,
                        Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION,
                        nil,
                        target,
                        nil,
                        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                        spider,
                        false, false, false, false,
                        "brood_pull_travel"
                    )
                    asg.lastSteerTime = now
                end
            end

        elseif asg.phase == "wait" then
            local creepsHere = PullHasEnemyCreepsNear(asg.lanePos, 500)
            if creepsHere then
                asg.phase = "aggro"
                asg.phaseTime = now
                Player.PrepareUnitOrders(
                    myPlayer,
                    Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_MOVE,
                    nil,
                    asg.lanePos,
                    nil,
                    Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                    spider,
                    false, false, false, false,
                    "brood_pull_aggro"
                )
            elseif now - asg.phaseTime > 35 then
                table.remove(PullState.assignments, i)
            end

        elseif asg.phase == "aggro" then
            if now - asg.phaseTime >= aggroDuration then
                asg.phase = "retreat"
                asg.phaseTime = now
                asg.lastSteerTime = 0
            end

        elseif asg.phase == "retreat" then
            local heroPos = myHero and Entity.GetAbsOrigin(myHero) or asg.retreatPos
            local distToHero = PullDist2D(spiderPos, heroPos)

            if not asg.gridPath or not asg.gridPathTime or (now - asg.gridPathTime > 3) then
                local safeTarget = PullGetSafeRetreatPos(spiderPos, heroPos, 900)
                asg.gridPath = PullBuildGridNavPath(spider, spiderPos, safeTarget)
                asg.gridPathIdx = 1
                asg.gridPathTime = now
            end

            if not asg.reaggroUntil then asg.reaggroUntil = 0 end
            if not asg.reaggroCooldown then asg.reaggroCooldown = 0 end
            if not asg.lastTraversableCheck then asg.lastTraversableCheck = 0 end

            if now - asg.lastTraversableCheck >= 0.5 and now > asg.reaggroUntil and now > asg.reaggroCooldown then
                asg.lastTraversableCheck = now
                local lp = asg.lanePos or spiderPos
                local backDx, backDy = lp.x - spiderPos.x, lp.y - spiderPos.y
                local backDist = math.sqrt(backDx * backDx + backDy * backDy)
                if backDist > 50 then
                    local backPos = Vector(
                        spiderPos.x + backDx / backDist * 400,
                        spiderPos.y + backDy / backDist * 400,
                        spiderPos.z
                    )
                    local canPass = GridNav.IsTraversableFromTo(spiderPos, backPos, true)
                    if not canPass then
                        asg.reaggroUntil = now + 1.2
                        asg.reaggroCooldown = now + 5.0
                    end
                end
            end

            local wp = asg.gridPath and asg.gridPath[asg.gridPathIdx]
            if wp and PullDist2D(spiderPos, wp) < 150 then
                asg.gridPathIdx = asg.gridPathIdx + 1
                wp = asg.gridPath[asg.gridPathIdx]
            end
            if not wp then wp = heroPos end

            if distToHero < 300 or (now - asg.phaseTime > 25) then
                table.remove(PullState.assignments, i)
            elseif now < asg.reaggroUntil then
                if now - asg.lastSteerTime >= 0.4 then
                    Player.PrepareUnitOrders(
                        myPlayer,
                        Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_MOVE,
                        nil,
                        spiderPos,
                        nil,
                        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                        spider,
                        false, false, false, false,
                        "brood_pull_reaggro"
                    )
                    asg.lastSteerTime = now
                end
            else
                local creepsAggroed = false
                local myHeroEnt = Heroes.GetLocal()
                local teamNum = myHeroEnt and Entity.GetTeamNum(myHeroEnt) or 0
                local nearCreeps = NPCs.InRadius(spiderPos, 700, teamNum, Enum.TeamType.TEAM_ENEMY)
                if nearCreeps then
                    for _, creep in ipairs(nearCreeps) do
                        if Entity.IsAlive(creep) and NPC.IsLaneCreep(creep) then
                            if NPC.IsRunning(creep) or NPC.IsAttacking(creep) then
                                creepsAggroed = true
                                break
                            end
                        end
                    end
                end

                if creepsAggroed then
                    if now - asg.lastSteerTime >= 0.5 then
                        Player.PrepareUnitOrders(
                            myPlayer,
                            Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION,
                            nil,
                            wp,
                            nil,
                            Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                            spider,
                            false, false, false, false,
                            "brood_pull_retreat"
                        )
                        asg.lastSteerTime = now
                    end
                else
                    if now - asg.lastSteerTime >= 0.5 then
                        Player.PrepareUnitOrders(
                            myPlayer,
                            Enum.UnitOrder.DOTA_UNIT_ORDER_STOP,
                            nil, nil, nil,
                            Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                            spider,
                            false, false, false, false,
                            "brood_pull_retreat"
                        )
                        asg.lastSteerTime = now
                    end
                end
            end
        end

        ::continue::
    end
end

local function PullDrawText()
    if not UI.PullShowText:Get() then return end
    if #PullState.assignments == 0 then return end
    local myHero = Heroes.GetLocal()
    if not myHero then return end
    local heroPos = Entity.GetAbsOrigin(myHero)
    local abovePos = Vector(heroPos.x, heroPos.y, heroPos.z + 200)
    local sp, vis = Render.WorldToScreen(abovePos)
    if not vis then return end
    local txt = "Pulling..."
    local tSize = Render.TextSize(PullFonts.Main, 14, txt)
    local tx = sp.x - tSize.x / 2
    local ty = sp.y - tSize.y / 2
    Render.Text(PullFonts.Main, 14, txt, Vec2(tx + 1, ty + 1), Color(0, 0, 0, 180))
    Render.Text(PullFonts.Main, 14, txt, Vec2(tx, ty), Color(255, 200, 100, 255))
end

local function PullDrawLines()
    if not UI.PullShowLines:Get() then return end
    for _, asg in ipairs(PullState.assignments) do
        local spider = asg.spider
        if not spider or not Entity.IsAlive(spider) then goto cont end
        local spiderPos = Entity.GetAbsOrigin(spider)
        local sSp, sOk = Render.WorldToScreen(spiderPos)
        local lSp, lOk = Render.WorldToScreen(asg.lanePos)

        local phaseCol
        if asg.phase == "travel" then
            phaseCol = Color(100, 180, 255, 200)
        elseif asg.phase == "wait" then
            phaseCol = Color(200, 200, 100, 200)
        elseif asg.phase == "aggro" then
            phaseCol = Color(255, 50, 50, 200)
        elseif asg.phase == "retreat" then
            phaseCol = Color(255, 120, 60, 200)
        end

        if asg.phase == "travel" or asg.phase == "wait" or asg.phase == "aggro" then
            if sOk and lOk then Render.Line(sSp, lSp, phaseCol, 2) end
        elseif asg.phase == "retreat" and asg.gridPath then
            local prevSp, prevOk = sSp, sOk
            for wi = (asg.gridPathIdx or 1), #asg.gridPath do
                local wpSp, wpOk = Render.WorldToScreen(asg.gridPath[wi])
                if prevOk and wpOk then
                    Render.Line(prevSp, wpSp, phaseCol, 2)
                end
                prevSp, prevOk = wpSp, wpOk
            end
        end
        ::cont::
    end
end

local function PullOnUpdate()
    if not UI.PullEnabled:Get() then return end

    if #PullState.assignments > 0 then
        local player = Players.GetLocal()
        if player then
            local selected = Player.GetSelectedUnits(player) or {}
            if #selected > 0 then
                local clean = {}
                local dirty = false
                for _, u in ipairs(selected) do
                    if PullIsSpiderAssigned(u) then
                        dirty = true
                    else
                        table.insert(clean, u)
                    end
                end
                if dirty then
                    Player.ClearSelectedUnits(player)
                    for _, u in ipairs(clean) do
                        Player.AddSelectedUnit(player, u)
                    end
                end
            end
        end
    end

    local mode = UI.PullMode:Get()

    if mode == 0 then
        if UI.PullKey:IsDown() then
            if #PullState.assignments == 0 then
                PullDispatch()
            end
        end
    else
        if UI.PullKey:IsPressed() then
            PullState.pullToggled = not PullState.pullToggled
            if PullState.pullToggled then
                PullDispatch()
            else
                PullState.assignments = {}
            end
        end
    end

    PullUpdateAssignments()

    if mode == 1 and PullState.pullToggled and #PullState.assignments == 0 then
        PullState.pullToggled = false
    end
end

local function PullOnDraw()
    if not UI.PullEnabled:Get() then return end
    PullDrawLines()
    PullDrawText()
end

local function PullOnPrepareUnitOrders(data)
    if not UI.PullEnabled:Get() then return true end
    if #PullState.assignments == 0 then return true end

    if data.identifier == "brood_pull_travel"
    or data.identifier == "brood_pull_aggro"
    or data.identifier == "brood_pull_retreat"
    or data.identifier == "brood_pull_reaggro"
    or data.identifier == "brood_pull_relay" then
        return true
    end

    if data.npc and PullIsSpiderAssigned(data.npc) then
        return false
    end

    if data.orderIssuer == Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_SELECTED_UNITS then
        local player = Players.GetLocal()
        if player then
            local selected = Player.GetSelectedUnits(player) or {}
            local allowed = {}
            local hasLocked = false

            for _, u in ipairs(selected) do
                if PullIsSpiderAssigned(u) then
                    hasLocked = true
                else
                    table.insert(allowed, u)
                end
            end

            if hasLocked then
                if #allowed > 0 then
                    Player.PrepareUnitOrders(
                        player,
                        data.order,
                        data.target,
                        data.position,
                        data.ability,
                        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                        allowed,
                        data.queue or false,
                        data.showEffects or false,
                        false, false,
                        "brood_pull_relay"
                    )
                end
                return false
            end
        end
    end

    return true
end

local function PullOnGameEnd()
    PullState.assignments = {}
    PullState.pullToggled = false
    PullState.cachedTowers = nil
end

local function GatherSpidersToPos(targetPos, orderId)
    local currentTime = GameRules.GetGameTime()
    if not targetPos then return end

    local spiders = GetAllSpiders()
    State.juggling = false
    State.lastGatherTime = currentTime
    State.lastGatherPos = targetPos

    if #spiders > 0 then
        local myPlayer = Players.GetLocal()
        for i = 1, #spiders do
            if Entity.IsAlive(spiders[i]) then
                Player.PrepareUnitOrders(
                    myPlayer,
                    Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION,
                    nil,
                    targetPos,
                    nil,
                    Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                    spiders[i],
                    false, false, false, false,
                    orderId or "brood_gather"
                )
            end
        end
    end
end

local function GatherSpiders()
    if not UI.GatherKey:IsPressed() then return end

    local currentTime = GameRules.GetGameTime()
    local gatherDelay = UI.GatherDelay:Get() / 1000
    if currentTime - State.lastGatherTime < gatherDelay then return end

    local myHero = Heroes.GetLocal()
    if not myHero then return end

    local cursorPos = Input.GetWorldCursorPos()
    if not cursorPos then
        cursorPos = Entity.GetAbsOrigin(myHero)
    end

    GatherSpidersToPos(cursorPos, "brood_gather")
end

local function StopJuggledSpiders()
    local activeIds = State.juggleActiveIds or {}
    if not next(activeIds) then return end

    local myPlayer = Players.GetLocal()
    if not myPlayer then
        State.juggleActiveIds = {}
        return
    end

    local spiders = GetAllSpiders()
    for i = 1, #spiders do
        local spider = spiders[i]
        local id = Entity.GetIndex(spider)
        if id and activeIds[id] and Entity.IsAlive(spider) then
            Player.PrepareUnitOrders(
                myPlayer,
                Enum.UnitOrder.DOTA_UNIT_ORDER_STOP,
                nil, nil, nil,
                Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                spider,
                false, false, false, false,
                "brood_juggle_stop"
            )
        end
    end

    State.juggleActiveIds = {}
end

local function JuggleSpiders()
    local myHero = Heroes.GetLocal()
    if not myHero then return end
    local mode = UI.JuggleMode and UI.JuggleMode:Get() or 0

    local active = false
    if mode == 0 then
        State.juggleToggleActive = false
        local keyDown = UI.JuggleKey:IsDown()
        if keyDown then
            State.juggleWasDown = true
            active = true
        else
            if State.juggleWasDown then
                StopJuggledSpiders()
            end
            State.juggleWasDown = false
        end
    else
        if UI.JuggleKey:IsPressed() then
            State.juggleToggleActive = not State.juggleToggleActive
            if not State.juggleToggleActive then
                StopJuggledSpiders()
            end
        end
        active = State.juggleToggleActive
    end

    if not active then
        State.juggling = false
        return
    end

    local now = GameRules.GetGameTime()
    if now - (State.lastJuggleOrderTime or 0) < ORDER_INTERVAL_JUGGLE then
        return
    end

    local heroPos = Entity.GetAbsOrigin(myHero)
    local radius = UI.JuggleRadius:Get()
    local spiders = GetAllSpiders()
    local count = math.min(UI.JuggleCount:Get(), #spiders)
    if count <= 0 then
        State.juggling = false
        return
    end

    local myPlayer = Players.GetLocal()
    if not myPlayer then return end
    local activeIds = {}
    for i = 1, count do
        if spiders[i] and Entity.IsAlive(spiders[i]) then
            local spider = spiders[i]
            local spiderId = Entity.GetIndex(spider)
            if spiderId then
                activeIds[spiderId] = true
            end

            local angle = (i - 1) * (2 * math.pi / count)
            local x = heroPos.x + radius * math.cos(angle)
            local y = heroPos.y + radius * math.sin(angle)
            local targetPos = Vector(x, y, heroPos.z)

            local spiderPos = Entity.GetAbsOrigin(spider)
            if spiderPos and (spiderPos - targetPos):Length2D() >= JUGGLE_REISSUE_DISTANCE then
                Player.PrepareUnitOrders(
                    myPlayer,
                    Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION,
                    nil,
                    targetPos,
                    nil,
                    Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                    spider,
                    false, false, false, false,
                    "brood_juggle"
                )
            end
        end
    end

    State.juggleActiveIds = activeIds
    State.lastJuggleOrderTime = now
    State.juggling = true
    State.juggleTime = now
end

-- ═══════════════════════════════════════════════════════════════════════════
--  Предметы: Bloodthorn, Orchid, Manta (враг), Soul Ring
-- ═══════════════════════════════════════════════════════════════════════════

local function GetBloodthornItem(hero)
    if not hero then return nil end
    for i = 0, 8 do
        local item = NPC.GetItemByIndex(hero, i)
        if item and Ability.GetName(item) == "item_bloodthorn" then
            return item
        end
    end
    return nil
end

local function GetOrchidItem(hero)
    if not hero then return nil end
    for i = 0, 8 do
        local item = NPC.GetItemByIndex(hero, i)
        if item and Ability.GetName(item) == "item_orchid" then
            return item
        end
    end
    return nil
end

local function GetMantaItem(enemy)
    if not enemy then return nil end
    for i = 0, 8 do
        local item = NPC.GetItemByIndex(enemy, i)
        if item and Ability.GetName(item) == "item_manta" then
            return item
        end
    end
    return nil
end

local function HasActiveMantaIllusions(enemy)
    if not enemy then return false end
    local enemyPos = Entity.GetAbsOrigin(enemy)
    local allNPCs = NPCs.GetAll()
    local enemyName = NPC.GetUnitName(enemy)

    for i = 1, #allNPCs do
        local npc = allNPCs[i]
        if NPC.IsIllusion(npc) and Entity.IsAlive(npc) and
           NPC.GetUnitName(npc) == enemyName and
           Entity.GetTeamNum(npc) == Entity.GetTeamNum(enemy) then
            local illuPos = Entity.GetAbsOrigin(npc)
            local dist = (enemyPos - illuPos):Length()
            if dist < 800 then
                return true
            end
        end
    end
    return false
end

local function IsMantaOnCooldown(enemy)
    local manta = GetMantaItem(enemy)
    if not manta then return true end
    local cd = Ability.GetCooldown(manta)
    local buffer = UI.BloodthornDelay:Get() / 1000
    return cd > buffer
end

local function ShouldWaitForManta(enemy)
    local manta = GetMantaItem(enemy)
    if not manta then return false end
    if IsMantaOnCooldown(enemy) then return false end
    if HasActiveMantaIllusions(enemy) then return true end

    local enemyHP = Entity.GetHealth(enemy)
    local enemyMaxHP = Entity.GetMaxHealth(enemy)
    local hpPercent = (enemyHP / enemyMaxHP) * 100
    if hpPercent < 25 then return false end
    return true
end

local function FindBloodthornTarget(myHero)
    if not myHero then return nil end

    local range = UI.BloodthornRange:Get()
    local hpThreshold = UI.BloodthornHPThreshold:Get()
    local enemies = Entity.GetHeroesInRadius(myHero, range, Enum.TeamType.TEAM_ENEMY, true) or {}

    local validTargets = {}
    for i = 1, #enemies do
        local enemy = enemies[i]
        if Entity.IsAlive(enemy) and not Entity.IsDormant(enemy) and NPC.IsVisible(enemy) then
            local enemyHP = Entity.GetHealth(enemy)
            local enemyMaxHP = Entity.GetMaxHealth(enemy)
            local hpPercent = (enemyHP / enemyMaxHP) * 100

                if hpPercent <= hpThreshold then
                if not NPC.HasModifier(enemy, "modifier_item_bloodthorn_debuff") and
                   not NPC.HasModifier(enemy, "modifier_item_orchid_malevolence_debuff") and
                   not NPC.HasModifier(enemy, "modifier_teleporting") and
                   not NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_MAGIC_IMMUNE) and
                   not NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE) and
                   not NPC.IsLinkensProtected(enemy) then

                    if not ShouldWaitForManta(enemy) then
                        local score = (100 - hpPercent)
                        if IsMantaOnCooldown(enemy) then score = score + 30 end
                        if not HasActiveMantaIllusions(enemy) then score = score + 20 end
                        validTargets[#validTargets + 1] = {enemy = enemy, score = score}
                    end
                end
            end
        end
    end

    if #validTargets == 0 then return nil end
    table.sort(validTargets, function(a, b) return a.score > b.score end)
    return validTargets[1].enemy
end

local function AutoBloodthorn()
    if not UI.SmartBloodthorn:Get() then return end
    local myHero = Heroes.GetLocal()
    if not myHero then return end

    local bloodthorn = GetBloodthornItem(myHero)
    if not bloodthorn then return end

    if not Ability.IsReady(bloodthorn) or not Ability.IsCastable(bloodthorn, NPC.GetMana(myHero)) then return end

    local now = GameRules.GetGameTime()
    if now - State.lastSoulRingTime < 0.3 then return end

    local target = FindBloodthornTarget(myHero)
    if not target then return end

    local myPos = Entity.GetAbsOrigin(myHero)
    local targetPos = Entity.GetAbsOrigin(target)
    local dist = (myPos - targetPos):Length()
    local castRange = Ability.GetCastRange(bloodthorn) or 900

    if dist <= castRange then
        Ability.CastTarget(bloodthorn, target)
        State.lastSoulRingTime = now
    end
end

local function AutoOrchid()
    if not UI.SmartBloodthorn:Get() then return end
    local myHero = Heroes.GetLocal()
    if not myHero then return end

    local orchid = GetOrchidItem(myHero)
    if not orchid then return end

    if not Ability.IsReady(orchid) or not Ability.IsCastable(orchid, NPC.GetMana(myHero)) then return end

    local now = GameRules.GetGameTime()
    if now - State.lastSoulRingTime < 0.3 then return end

    local target = FindBloodthornTarget(myHero)
    if not target then return end

    local myPos = Entity.GetAbsOrigin(myHero)
    local targetPos = Entity.GetAbsOrigin(target)
    local dist = (myPos - targetPos):Length()
    local castRange = Ability.GetCastRange(orchid) or 900

    if dist <= castRange then
        Ability.CastTarget(orchid, target)
        State.lastSoulRingTime = now
    end
end

local function AutoSoulRing()
    if not UI.AutoSoulRing:Get() then return end
    local myHero = Heroes.GetLocal()
    if not myHero then return end

    local spawnAbility = NPC.GetAbility(myHero, "broodmother_spawn_spiderlings")
    if not spawnAbility then return end

    if not Ability.IsInAbilityPhase(spawnAbility) and not Ability.IsChannelling(spawnAbility) then
        return
    end

    local soulRing = NPC.GetItem(myHero, "item_soul_ring")
    if soulRing and Ability.IsCastable(soulRing, 0) then
        local soulRingActive = NPC.HasModifier(myHero, "modifier_item_soul_ring_buff")
        if not soulRingActive then
            Ability.CastNoTarget(soulRing)
            State.lastSoulRingTime = GameRules.GetGameTime()
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
--  Отрисовка: панель, ячейки, веб-поинты, иконки
-- ═══════════════════════════════════════════════════════════════════════════

local function GetHeroIconHandle(unitName)
    if not unitName then return nil end
    if HeroIconCache[unitName] then return HeroIconCache[unitName] end
    local path = "panorama/images/heroes/icons/" .. unitName .. "_png.vtex_c"
    local handle = Render.LoadImage(path)
    HeroIconCache[unitName] = handle
    return handle
end

local function GetAbilityIconHandle(abilityName)
    if not abilityName then return nil end
    if AbilityIconCache[abilityName] then return AbilityIconCache[abilityName] end
    local path = "panorama/images/spellicons/" .. abilityName .. "_png.vtex_c"
    local handle = Render.LoadImage(path)
    AbilityIconCache[abilityName] = handle
    return handle
end

local function DrawBlurredBackground(x, y, width, height, radius, blurStrength, alpha)
    Render.Blur(
        Vec2(x, y),
        Vec2(x + width, y + height),
        blurStrength,
        alpha,
        radius,
        Enum.DrawFlags.None
    )
end

local function DrawCell(x, y, alpha, text, fontSize, textColor)
    local size = PanelConfig.CellSize
    DrawBlurredBackground(x, y, size, size, 6, 8, 0.97 * (alpha / 255))
    Render.Shadow(
        Vec2(x, y),
        Vec2(x + size, y + size),
        Color(0, 0, 0, math.floor(alpha)),
        24,
        6,
        Enum.DrawFlags.ShadowCutOutShapeBackground,
        Vec2(1, 1)
    )
    Render.FilledRect(
        Vec2(x, y),
        Vec2(x + size, y + size),
        Color(0, 0, 0, math.floor(140 * alpha / 255)),
        6
    )

    local textSize = Render.TextSize(Config.Fonts.Main, fontSize, text)
    local textX = x + (size - textSize.x) / 2
    local textY = y + (size - textSize.y) / 2

    Render.Text(Config.Fonts.Main, fontSize, text, Vec2(textX + 1, textY + 1), Color(0, 0, 0, math.floor(alpha * 0.4)))
    Render.Text(Config.Fonts.Main, fontSize, text, Vec2(textX, textY), Color(textColor.r, textColor.g, textColor.b, math.floor(alpha)))
end

local function DrawIconCell(x, y, alpha, imageHandle, scale, rounding)
    local size = PanelConfig.CellSize
    DrawBlurredBackground(x, y, size, size, 6, 8, 0.97 * (alpha / 255))
    Render.Shadow(
        Vec2(x, y),
        Vec2(x + size, y + size),
        Color(0, 0, 0, math.floor(alpha)),
        24,
        6,
        Enum.DrawFlags.ShadowCutOutShapeBackground,
        Vec2(1, 1)
    )
    Render.FilledRect(
        Vec2(x, y),
        Vec2(x + size, y + size),
        Color(0, 0, 0, math.floor(140 * alpha / 255)),
        6
    )

    if imageHandle then
        local basePad = 2
        local iconScale = math.max(0.5, math.min(scale or 1.0, 1.0))
        local inner = (size - basePad * 2)
        local iconSize = math.floor(inner * iconScale)
        local offset = math.floor((inner - iconSize) / 2)
        local pos = Vec2(x + basePad + offset + 0.5, y + basePad + 1 + offset)
        local sz = Vec2(iconSize, iconSize)
        local r = rounding or 0
        r = math.max(0, math.min(r, math.floor(iconSize / 2)))
        Render.Image(imageHandle, pos, sz, Color(255, 255, 255, math.floor(alpha)), r)
    end
end

local function AnimateAlpha(current, target, speed)
    if current < target then
        return math.min(current + speed, target)
    elseif current > target then
        return math.max(current - speed, target)
    end
    return current
end

local function GetSpiderStatus(spiders)
    spiders = spiders or GetAllSpiders()
    local totalSpiders = #spiders

    if totalSpiders == 0 then
        return "0", "Idle"
    end

    local status = "Idle"
    if State.juggling and (GameRules.GetGameTime() - State.juggleTime < 3) then
        status = "Spread"
    elseif State.lastGatherPos and (GameRules.GetGameTime() - State.lastGatherTime < 2) then
        status = "Gather"
    else
        local attackingCount = 0
        for i = 1, #spiders do
            if NPC.IsAttacking(spiders[i]) then
                attackingCount = attackingCount + 1
            end
        end
        if attackingCount > totalSpiders * 0.3 then
            status = "Attack"
        end
    end

    return tostring(totalSpiders), status
end

local function GetAverageSpiderHP(spiders)
    spiders = spiders or GetAllSpiders()
    if #spiders == 0 then return 0 end

    local totalHP = 0
    local totalMaxHP = 0

    for i = 1, #spiders do
        totalHP = totalHP + Entity.GetHealth(spiders[i])
        totalMaxHP = totalMaxHP + Entity.GetMaxHealth(spiders[i])
    end

    if totalMaxHP == 0 then return 0 end
    return math.floor((totalHP / totalMaxHP) * 100)
end

local function HandlePanelInput()
    local cursorX, cursorY = Input.GetCursorPos()

    local headerY = State.panelPos.y
    if State.panelAnimation.headerInCellsPosition then
        headerY = State.panelPos.y + PanelConfig.HeaderHeight + 5
    end

    local isInHeader = cursorX >= State.panelPos.x and cursorX <= State.panelPos.x + PanelConfig.Width and
                      cursorY >= headerY and cursorY <= headerY + PanelConfig.HeaderHeight

    if isInHeader and Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE1) and not State.isDragging then
        State.isDragging = true
        State.dragOffset.x = cursorX - State.panelPos.x
        State.dragOffset.y = cursorY - State.panelPos.y
    end

    if State.isDragging then
        if Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE1) then
            State.panelPos.x = cursorX - State.dragOffset.x
            State.panelPos.y = cursorY - State.dragOffset.y

            local screenSize = Render.ScreenSize()
            State.panelPos.x = math.max(0, math.min(State.panelPos.x, screenSize.x - PanelConfig.Width))
            State.panelPos.y = math.max(0, math.min(State.panelPos.y, screenSize.y - PanelConfig.Height))
        else
            State.isDragging = false
            SavePanelPosition(State.panelPos.x, State.panelPos.y)
        end
    end
end

local function UpdatePanelAnimation()
    local spiders = GetAllSpiders()
    local currentSpiderCount = #spiders

    local nextInCells = (currentSpiderCount == 0)

    if currentSpiderCount ~= State.panelAnimation.lastSpiderCount then
        State.panelAnimation.lastSpiderCount = currentSpiderCount
        State.panelAnimation.cellsTargetAlpha = nextInCells and 0 or 255
    end

    if State.panelAnimation.headerInCellsPosition ~= nextInCells then
        if State.panelAnimation.headerAlpha > 0 then
            State.panelAnimation.headerTargetAlpha = 0
            if not nextInCells then
                State.panelAnimation.cellsTargetAlpha = 0
            end
        else
            State.panelAnimation.headerInCellsPosition = nextInCells
            State.panelAnimation.headerTargetAlpha = 255
            if not nextInCells then
                State.panelAnimation.cellsTargetAlpha = 255
            end
        end
    else
        State.panelAnimation.headerTargetAlpha = 255
    end

    local animationSpeed = 15

    State.panelAnimation.cellsAlpha  = AnimateAlpha(State.panelAnimation.cellsAlpha,  State.panelAnimation.cellsTargetAlpha,  animationSpeed)
    State.panelAnimation.headerAlpha = AnimateAlpha(State.panelAnimation.headerAlpha, State.panelAnimation.headerTargetAlpha, animationSpeed)

    State.panelAnimation.titleTargetAlpha = State.panelAnimation.headerTargetAlpha
    State.panelAnimation.titleAlpha = AnimateAlpha(State.panelAnimation.titleAlpha, State.panelAnimation.titleTargetAlpha, animationSpeed)
end

local function DrawPanel()
    if not UI.ShowPanel:Get() then return end

    UpdatePanelAnimation()
    HandlePanelInput()

    local headerY = State.panelPos.y
    if State.panelAnimation.headerInCellsPosition then
        headerY = State.panelPos.y + PanelConfig.HeaderHeight + 5
    end

    DrawBlurredBackground(State.panelPos.x, headerY, PanelConfig.Width, PanelConfig.HeaderHeight, PanelConfig.BorderRadius, PanelConfig.BlurStrengthHeader, 0.91 * (State.panelAnimation.headerAlpha / 255))

    Render.Shadow(
        Vec2(State.panelPos.x, headerY),
        Vec2(State.panelPos.x + PanelConfig.Width, headerY + PanelConfig.HeaderHeight),
        Color(0, 0, 0, math.floor(State.panelAnimation.headerAlpha)),
        24,
        PanelConfig.BorderRadius,
        Enum.DrawFlags.ShadowCutOutShapeBackground,
        Vec2(1, 1)
    )

    Render.FilledRect(
        Vec2(State.panelPos.x, headerY),
        Vec2(State.panelPos.x + PanelConfig.Width, headerY + PanelConfig.HeaderHeight),
        Color(PanelColors.Header.r, PanelColors.Header.g, PanelColors.Header.b, math.floor(PanelColors.Header.a * State.panelAnimation.headerAlpha / 255)),
        PanelConfig.BorderRadius
    )

    local iconHandle = GetHeroIconHandle("npc_dota_hero_broodmother")
    local iconSizePx = 18
    local iconX = State.panelPos.x + 8
    local iconY = headerY + (PanelConfig.HeaderHeight - iconSizePx) / 2
    if iconHandle then
        Render.Image(iconHandle, Vec2(iconX, iconY), Vec2(iconSizePx, iconSizePx), Color(255, 255, 255, math.floor(State.panelAnimation.headerAlpha)), 0)
    end

    local separatorX = iconX + iconSizePx + 8
    local separatorY = headerY + 4
    local separatorHeight = PanelConfig.HeaderHeight - 8

    Render.FilledRect(
        Vec2(separatorX, separatorY-4),
        Vec2(separatorX + 2, separatorY + separatorHeight + 4),
        Color(15, 15, 15, math.floor(70 * State.panelAnimation.headerAlpha / 255))
    )

    local title = "@spiders"
    local titleSize = Render.TextSize(Config.Fonts.Main, 12, title)
    local titleX = separatorX + 8
    local titleY = headerY + (PanelConfig.HeaderHeight - titleSize.y) / 2

    Render.Text(Config.Fonts.Main, 12, title, Vec2(titleX + 1, titleY + 1), Color(0, 0, 0, math.floor(State.panelAnimation.headerAlpha * 0.3)))
    Render.Text(Config.Fonts.Main, 12, title, Vec2(titleX, titleY), Color(170, 170, 170, math.floor(State.panelAnimation.headerAlpha)))

    local contentY = State.panelPos.y + PanelConfig.HeaderHeight + 5
    local cellStartX = State.panelPos.x + 8
    local cellY = contentY

    local spiders = GetAllSpiders()
    local spiderCount, spiderStatus = GetSpiderStatus(spiders)
    local avgHP = GetAverageSpiderHP(spiders)

    local myHero = Heroes.GetLocal()
    local webText, webColor = "-", Color(120, 200, 255, 255)
    local hungerText, hungerColor = "-", Color(255, 200, 120, 255)

    if myHero then
        local spinWeb = NPC.GetAbility(myHero, "broodmother_spin_web")
        if spinWeb then
            local charges = Ability.GetCurrentCharges(spinWeb)
            if charges and charges >= 0 then
                webText = tostring(charges)
                if charges == 0 then
                    webColor = Color(255, 120, 120, 255)
                end
            end
        end

        local hunger = NPC.GetAbility(myHero, "broodmother_insatiable_hunger")
        if hunger then
            if NPC.HasModifier(myHero, "modifier_broodmother_insatiable_hunger") then
                hungerText = "ON"
                hungerColor = Color(255, 200, 120, 255)
            elseif Ability.IsCastable(hunger, NPC.GetMana(myHero)) then
                hungerText = "RDY"
                hungerColor = Color(120, 255, 120, 255)
            else
                local cd = Ability.GetCooldown(hunger)
                hungerText = tostring(math.ceil(cd))
                hungerColor = Color(255, 120, 120, 255)
            end
        end
    end

    local cells = {
        {text = spiderCount, font = 12, color = Color(255, 255, 255, 255)},
        {
            text = (function()
                if spiderStatus == "Gather" then return "G" end
                if spiderStatus == "Spread" then return "S" end
                if spiderStatus == "Attack" then return "A" end
                return "I"
            end)(),
            font = 12,
            color = PanelColors.StatusColors[spiderStatus] or PanelColors.StatusColors["Idle"]
        },
        {
            text = tostring(avgHP) .. "%",
            font = 9,
            color = (function()
                if avgHP < 25 then return Color(255, 120, 120, 255) end
                if avgHP < 50 then return Color(255, 255, 120, 255) end
                return PanelColors.StatusColors["HP"]
            end)()
        },
        {text = webText, font = 12, color = webColor},
        {text = hungerText, font = 11, color = hungerColor}
    }

    local cellX = cellStartX
    for i = 1, #cells do
        local c = cells[i]
        DrawCell(cellX, cellY, State.panelAnimation.cellsAlpha, c.text, c.font, c.color)
        cellX = cellX + PanelConfig.CellSize + PanelConfig.CellSpacing
    end
end

local function DrawWebPoints()
    if not UI.WebHelperEnabled:Get() then return end

    local altHeld = Input.IsKeyDown(Enum.ButtonCode.KEY_LALT) or Input.IsKeyDown(Enum.ButtonCode.KEY_RALT)
    local altActive = (not UI.ShowWebPointsOnlyAlt:Get()) or altHeld
    local targetAlpha = altActive and 255 or 0
    State.webAltAlpha = AnimateAlpha(State.webAltAlpha, targetAlpha, 25)
    if State.webAltAlpha <= 0 then return end

    local webIcon = GetAbilityIconHandle("broodmother_spin_web")
    local rounding = 6
    local myHero = Heroes.GetLocal()
    local team = myHero and Entity.GetTeamNum(myHero) or nil
    local cursorX, cursorY = Input.GetCursorPos()
    local mouseDown = Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE1)
    local justClicked = mouseDown and (not State.webMouseWasDown)
    local didCast = false
    local alphaScale = State.webAltAlpha / 255

    local function drawList(list)
        for i = 1, #(list or {}) do
            local wp = list[i]
            local screenPos, visible = Render.WorldToScreen(wp)
            if visible then
                local size = PanelConfig.CellSize
                local x = screenPos.x - size / 2
                local y = screenPos.y - size / 2

                local isHovered = cursorX >= x and cursorX <= (x + size) and cursorY >= y and cursorY <= (y + size)
                local baseAlpha = isHovered and math.floor(230 * 0.6) or 230
                local alpha = math.floor(baseAlpha * alphaScale)

                if webIcon then
                    DrawIconCell(x, y, alpha, webIcon, 0.88, rounding)

                    local basePad = 2
                    local iconScale = 0.88
                    local inner = (size - basePad * 2)
                    local iconSize = math.floor(inner * iconScale)
                    local offset = math.floor((inner - iconSize) / 2)
                    local pos = Vec2(x + basePad + offset + 0.5, y + basePad + 1 + offset)
                    local endPos = Vec2(pos.x + iconSize, pos.y + iconSize)
                    local baseBorder = isHovered and 180 or 220
                    local borderAlpha = math.floor(baseBorder * alphaScale)
                    Render.Rect(pos, endPos, Color(170, 170, 170, borderAlpha), rounding, Enum.DrawFlags.None, 0.5)
                else
                    DrawCell(x, y, alpha, "", 14, Color(120, 200, 255, 255))
                end

                if (not didCast) and UI.WebClickToCast:Get() and justClicked and isHovered and myHero then
                    local spinWeb = NPC.GetAbility(myHero, "broodmother_spin_web")
                    if spinWeb and Ability.IsCastable(spinWeb, NPC.GetMana(myHero)) then
                        -- Ability.CastPosition(ability, pos, [queue], [push], [execute_fast], [identifier], [force_minimap])
                        Ability.CastPosition(spinWeb, wp, false, false, false, "web_click")
                        didCast = true
                    end
                end
            end
        end
    end

    if team == Enum.TeamNum.TEAM_RADIANT then
        drawList(State.webPoints.radiant)
    elseif team == Enum.TeamNum.TEAM_DIRE then
        drawList(State.webPoints.dire)
    else
        drawList(State.webPoints.neutral)
    end

    State.webMouseWasDown = mouseDown
end

-- ═══════════════════════════════════════════════════════════════════════════
--  Callbacks: OnUpdate, OnDraw, OnGameEnd, OnPrepareUnitOrders
-- ═══════════════════════════════════════════════════════════════════════════

broodmother.OnUpdate = function()
    if not IsBroodmother() or not UI.Enabled:Get() then return end

    CleanupPlayerOverride()

    local spiderCount = #GetAllSpiders()

    if not State.updateFrame then
        State.updateFrame = 0
    end
    State.updateFrame = (State.updateFrame + 1)

    -- Реже обновляем авто-логику при большом числе пауков → меньше перехват, плавнее
    local throttleRate = 2
    if spiderCount > 20 then
        throttleRate = 6
    elseif spiderCount > 15 then
        throttleRate = 5
    elseif spiderCount > 10 then
        throttleRate = 4
    elseif spiderCount > 5 then
        throttleRate = 3
    end

    GatherSpiders()
    JuggleSpiders()
    AutoBloodthorn()
    AutoOrchid()
    AutoSoulRing()
    AutoStackCampsLogic()
    PullOnUpdate()

    if State.updateFrame % throttleRate == 0 then
        if spiderCount <= 20 then
            AutoChaseEnemies()
            AutoSplitAttack()
            AutoFarmCreeps()
            AutoFollowSpiders()
        else
            AutoFarmCreeps()
        end
    end
end

broodmother.OnDraw = function()
    if not IsBroodmother() or not UI.Enabled:Get() then return end

    DrawPanel()
    DrawWebPoints()
    PullOnDraw()

    if State.lastGatherPos and (GameRules.GetGameTime() - State.lastGatherTime < 2) then
        local screenPos, isVisible = Render.WorldToScreen(State.lastGatherPos)
        if isVisible then
            local alpha = math.max(0, 255 - (GameRules.GetGameTime() - State.lastGatherTime) * 127)
            Render.Line(Vec2(screenPos.x - 5, screenPos.y), Vec2(screenPos.x + 5, screenPos.y), Color(100, 255, 100, alpha), 2)
            Render.Line(Vec2(screenPos.x, screenPos.y - 5), Vec2(screenPos.x, screenPos.y + 5), Color(100, 255, 100, alpha), 2)
        end
    end

    if State.juggling and (GameRules.GetGameTime() - State.juggleTime < 3) then
        local myHero = Heroes.GetLocal()
        if myHero then
            local heroPos = Entity.GetAbsOrigin(myHero)
            local radius = UI.JuggleRadius:Get()
            local alpha = math.max(0, 255 - (GameRules.GetGameTime() - State.juggleTime) * 85)

            local points = 32
            for i = 0, points do
                local angle = (i / points) * 2 * math.pi
                local x = heroPos.x + radius * math.cos(angle)
                local y = heroPos.y + radius * math.sin(angle)
                local worldPos = Vector(x, y, heroPos.z)
                local screenPos, isVisible = Render.WorldToScreen(worldPos)

                if isVisible and i > 0 then
                    local prevAngle = ((i - 1) / points) * 2 * math.pi
                    local prevX = heroPos.x + radius * math.cos(prevAngle)
                    local prevY = heroPos.y + radius * math.sin(prevAngle)
                    local prevWorldPos = Vector(prevX, prevY, heroPos.z)
                    local prevScreenPos, prevVisible = Render.WorldToScreen(prevWorldPos)

                    if prevVisible then
                        Render.Line(prevScreenPos, screenPos, Color(255, 120, 0, alpha), 2)
                    end
                end
            end

            local spiders = GetAllSpiders()
            local count = math.min(UI.JuggleCount:Get(), #spiders)

            for i = 1, count do
                local angle = (i - 1) * (2 * math.pi / count)
                local x = heroPos.x + radius * math.cos(angle)
                local y = heroPos.y + radius * math.sin(angle)
                local worldPos = Vector(x, y, heroPos.z)
                local screenPos, isVisible = Render.WorldToScreen(worldPos)

                if isVisible then
                    Render.FilledCircle(screenPos, 6, Color(255, 120, 0, alpha))
                    Render.Text(Config.Fonts.Main, 12, tostring(i), Vec2(screenPos.x - 4, screenPos.y - 6), Color(255, 255, 255, alpha))
                end
            end
        end
    else
        State.juggling = false
    end
end

broodmother.OnGameEnd = function()
    State.juggling = false
    State.juggleWasDown = false
    State.juggleToggleActive = false
    State.juggleActiveIds = {}
    State.lastJuggleOrderTime = 0
    PullOnGameEnd()
end

broodmother.OnPrepareUnitOrders = function(data)
    if not IsBroodmother() or not UI.Enabled:Get() then return true end
    if not data then return true end

    local localPlayer = Players.GetLocal()
    local lpId = localPlayer and Player.GetPlayerID(localPlayer) or -1
    local issuerPlayerId = data.player and Player.GetPlayerID(data.player) or -2
    if issuerPlayerId ~= lpId then return true end

    if data.identifier and type(data.identifier) == "string" and data.identifier:find("^brood_") then
        return true
    end

    local pullResult = PullOnPrepareUnitOrders(data)
    if pullResult == false then return false end

    local function IsSpiderling(npc)
        if not npc or not Entity.IsNPC(npc) then return false end
        return NPC.GetUnitName(npc) == "npc_dota_broodmother_spiderling"
    end

    local function applyOverride(npc)
        if npc and IsSpiderling(npc) then
            local id = Entity.GetIndex(npc)
            playerOverrideRole[id] = true
            playerOverrideUntil[id] = os.clock() + UI.PlayerOverride:Get()

            followRole[id] = nil
            chaseRole[id] = nil
            splitRole[id] = nil
            splitTarget[id] = nil
            farmRole[id] = nil
            farmLastOrder[id] = nil
        end
    end

    if data.orderIssuer == Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_SELECTED_UNITS then
        local selected = Player.GetSelectedUnits and Player.GetSelectedUnits(localPlayer) or {}
        for i = 1, #selected do
            applyOverride(selected[i])
        end
    else
        applyOverride(data.npc)
    end

    return true
end

-- Стак по кнопке: при ударе паука по нейтралу — сразу пулл (как в GLTM)
broodmother.OnEntityHurt = function(data)
    if not stackSessionActive or not data or not data.source then return end
    local src = data.source
    if not Entity.IsAlive(src) then return end
    local srcId = Entity.GetIndex(src)
    if not srcId or not stackUnitToCampId[srcId] then return end
    local campId = stackUnitToCampId[srcId]
    local t = StackGameTimeSeconds()
    local minute = math.floor(t / 60)
    local st = EnsureStackTimelineFor(src, minute)
    if not (st.attackIssued and not st.hitConfirmed) then return end
    st.hitConfirmed = true
    local points = GetStackCampPoints(campId)
    if points and not st.pullIssued then
        st.pullIssued = true
        local myPlayer = Players.GetLocal()
        if myPlayer then
            StackMoveUnitTo(myPlayer, src, points.pull)
        end
    end
end

return broodmother
