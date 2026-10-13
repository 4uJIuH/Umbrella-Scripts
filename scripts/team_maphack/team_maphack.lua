local heroes = {
    npc_dota_hero_antimage = {"AM", "АМ"}, npc_dota_hero_axe = {"AXE", "АКС"},
    npc_dota_hero_bane = {"BANE", "БЕЙН"}, npc_dota_hero_bloodseeker = {"BS", "БС"},
    npc_dota_hero_crystal_maiden = {"CM", "ЦМ"}, npc_dota_hero_drow_ranger = {"DROW", "ДРОВ"},
    npc_dota_hero_earthshaker = {"EART", "ШЕЙК"}, npc_dota_hero_juggernaut = {"JUG", "ДЖАГ"},
    npc_dota_hero_mirana = {"MIRA", "МИРА"}, npc_dota_hero_morphling = {"MOR", "МОРФ"},
    npc_dota_hero_nevermore = {"SF", "СФ"}, npc_dota_hero_phantom_lancer = {"PL", "ПЛ"},
    npc_dota_hero_puck = {"PUCK", "ПАК"}, npc_dota_hero_pudge = {"PUDG", "ПУДЖ"},
    npc_dota_hero_razor = {"RAZO", "РАЗО"}, npc_dota_hero_sand_king = {"SK", "СК"},
    npc_dota_hero_storm_spirit = {"STOR", "ШТОР"}, npc_dota_hero_sven = {"SVEN", "СВЕН"},
    npc_dota_hero_tiny = {"TINY", "ТИНИ"}, npc_dota_hero_vengefulspirit = {"VENG", "ВЕНГ"},
    npc_dota_hero_windrunner = {"WR", "ВР"}, npc_dota_hero_zuus = {"ZEUS", "ЗЕВС"},
    npc_dota_hero_kunkka = {"KUNK", "КУНК"}, npc_dota_hero_lina = {"LINA", "ЛИНА"},
    npc_dota_hero_lion = {"LION", "ЛИОН"}, npc_dota_hero_shadow_shaman = {"SS", "ШШ"},
    npc_dota_hero_slardar = {"SLAR", "СЛАР"}, npc_dota_hero_tidehunter = {"TIDE", "ТАЙД"},
    npc_dota_hero_witch_doctor = {"WD", "ВД"}, npc_dota_hero_lich = {"LICH", "ЛИЧ"},
    npc_dota_hero_riki = {"RIKI", "РИКИ"}, npc_dota_hero_enigma = {"ENIG", "ЭНИГ"},
    npc_dota_hero_tinker = {"TINK", "ТИНК"}, npc_dota_hero_sniper = {"SNIP", "СНАЙ"},
    npc_dota_hero_necrolyte = {"NEC", "НЕКР"}, npc_dota_hero_warlock = {"WAR", "ВАРЛ"},
    npc_dota_hero_beastmaster = {"BM", "БИСТ"}, npc_dota_hero_queenofpain = {"QOP", "КВОП"},
    npc_dota_hero_venomancer = {"VENO", "ВЕНИ"}, npc_dota_hero_faceless_void = {"VOID", "ВОЙД"},
    npc_dota_hero_skeleton_king = {"WK", "ВК"}, npc_dota_hero_death_prophet = {"DP", "ДП"},
    npc_dota_hero_phantom_assassin = {"PA", "ПА"}, npc_dota_hero_pugna = {"PUG", "ПУГН"},
    npc_dota_hero_templar_assassin = {"TA", "ТА"}, npc_dota_hero_viper = {"VIP", "ВАЙП"},
    npc_dota_hero_luna = {"LUNA", "ЛУНА"}, npc_dota_hero_dragon_knight = {"DK", "ДК"},
    npc_dota_hero_dazzle = {"DAZZ", "ДАЗЛ"}, npc_dota_hero_rattletrap = {"CW", "КЛОК"},
    npc_dota_hero_leshrac = {"LESH", "ЛЕШ"}, npc_dota_hero_furion = {"NP", "ФУРА"},
    npc_dota_hero_life_stealer = {"LS", "ЛС"}, npc_dota_hero_dark_seer = {"DS", "ДС"},
    npc_dota_hero_clinkz = {"CLIN", "КЛИН"}, npc_dota_hero_omniknight = {"OMNI", "ОМНИ"},
    npc_dota_hero_enchantress = {"ENCH", "ЭНЧ"}, npc_dota_hero_huskar = {"HUSK", "ХУСК"},
    npc_dota_hero_night_stalker = {"NS", "НС"}, npc_dota_hero_broodmother = {"BROO", "БРУД"},
    npc_dota_hero_bounty_hunter = {"BH", "БХ"}, npc_dota_hero_weaver = {"WEAV", "ВИВЕ"},
    npc_dota_hero_jakiro = {"JAK", "ДЖАК"}, npc_dota_hero_batrider = {"BAT", "БЭТ"},
    npc_dota_hero_chen = {"CHEN", "ЧЕН"}, npc_dota_hero_spectre = {"SPEC", "СПЕК"},
    npc_dota_hero_ancient_apparition = {"AA", "АПАР"}, npc_dota_hero_doom_bringer = {"DOOM", "ДУМ"},
    npc_dota_hero_ursa = {"URSA", "УРСА"}, npc_dota_hero_spirit_breaker = {"SB", "БАРА"},
    npc_dota_hero_gyrocopter = {"GYRO", "ГИРО"}, npc_dota_hero_alchemist = {"ALCH", "АЛХ"},
    npc_dota_hero_invoker = {"INV", "ИНВ"}, npc_dota_hero_silencer = {"SIL", "САЙЛ"},
    npc_dota_hero_obsidian_destroyer = {"OD", "ОД"}, npc_dota_hero_lycan = {"LYC", "ЛИКА"},
    npc_dota_hero_brewmaster = {"BREW", "БРЮ"}, npc_dota_hero_shadow_demon = {"SD", "СД"},
    npc_dota_hero_lone_druid = {"LD", "ЛД"}, npc_dota_hero_chaos_knight = {"CK", "ЦК"},
    npc_dota_hero_meepo = {"MEE", "МИП"}, npc_dota_hero_treant = {"TREE", "ТРЕН"},
    npc_dota_hero_ogre_magi = {"OGRE", "ОГР"}, npc_dota_hero_undying = {"UND", "АНДА"},
    npc_dota_hero_rubick = {"RUB", "РУБИ"}, npc_dota_hero_disruptor = {"DIS", "ДИЗ"},
    npc_dota_hero_nyx_assassin = {"NYX", "НИКС"}, npc_dota_hero_naga_siren = {"NAGA", "НАГА"},
    npc_dota_hero_keeper_of_the_light = {"KOTL", "КОТЛ"}, npc_dota_hero_wisp = {"IO", "ВИСП"},
    npc_dota_hero_visage = {"VIS", "ВИЗА"}, npc_dota_hero_slark = {"SLAR", "СЛАР"},
    npc_dota_hero_medusa = {"MED", "МЕД"}, npc_dota_hero_troll_warlord = {"TROL", "ТРОЛ"},
    npc_dota_hero_centaur = {"CENT", "КЕНТ"}, npc_dota_hero_magnataur = {"MAGN", "МАГН"},
    npc_dota_hero_shredder = {"TIMB", "ТИМБ"}, npc_dota_hero_bristleback = {"BB", "ББ"},
    npc_dota_hero_tusk = {"TUSK", "ТАСК"}, npc_dota_hero_skywrath_mage = {"SKY", "СКАЙ"},
    npc_dota_hero_abaddon = {"ABAD", "АБАД"}, npc_dota_hero_elder_titan = {"ET", "ТИТА"},
    npc_dota_hero_legion_commander = {"LC", "ЛЕГА"}, npc_dota_hero_techies = {"TECH", "ТЕЧ"},
    npc_dota_hero_ember_spirit = {"EMB", "ЭМБ"}, npc_dota_hero_earth_spirit = {"ES", "ЗЕМЛ"},
    npc_dota_hero_abyssal_underlord = {"PIT", "ПИТ"}, npc_dota_hero_terrorblade = {"TB", "ТБ"},
    npc_dota_hero_phoenix = {"PHX", "ФЕНИ"}, npc_dota_hero_oracle = {"ORAC", "ОРАК"},
    npc_dota_hero_winter_wyvern = {"WW", "ВВ"}, npc_dota_hero_arc_warden = {"ARC", "АРК"},
    npc_dota_hero_monkey_king = {"MK", "МК"}, npc_dota_hero_dark_willow = {"DW", "ВИЛК"},
    npc_dota_hero_pangolier = {"PANG", "ПАНГ"}, npc_dota_hero_grimstroke = {"GRIM", "ГРИМ"},
    npc_dota_hero_mars = {"MARS", "МАРС"}, npc_dota_hero_void_spirit = {"VOID", "ВОЙД"},
    npc_dota_hero_snapfire = {"SNAP", "БАБА"}, npc_dota_hero_hoodwink = {"HOOD", "БЕЛК"},
    npc_dota_hero_dawnbreaker = {"DB", "ДБ"}, npc_dota_hero_marci = {"MARC", "МАРC"},
    npc_dota_hero_primal_beast = {"PB", "ПБ"}, npc_dota_hero_muerta = {"MUER", "МУЭР"},
    npc_dota_hero_ringmaster = {"RING", "РИНГ"}, npc_dota_hero_kez = {"KEZ", "КЕЗ"},
}

local team_map = {}
local lang = Localizer.Get("Main") == "Main" and "en" or "ru"
local TR = {
    en = {
        main_tab = "Main", main_group = "Shared minimap", alerts_tab = "Alerts", alerts_group = "Signals",
        enabled = "Enable script", share = "Draw for team", maphack = "Hidden enemy maphack",
        hidden_delay = "Delay after leaving vision", hidden_refresh = "Repeat hidden mark", hidden_move = "Min distance for new mark",
        hidden_chat_cd = "Maphack msg CD", lines = "Draw speed lines per frame", chat = "Team chat messages",
        tp = "Enemy TP", smoke = "Enemy Smoke", scan = "Enemy Scan", runes = "Rune pickup",
        roshan = "Roshan attack", tormentor = "Tormentor attack", jungle = "Enemy farming jungle",
        sb_charge = "Spirit Breaker charge (Q)",
        sec1 = "%.1f sec", sec0 = "%.0f sec",
        hd_tip = "How long to wait after enemy leaves vision before the first message",
        hr_tip = "Min time before a new mark for the hero",
        hm_tip = "Min hero movement for a new mark",
        hcd_tip = "Min interval between msgs for the same hero",
        lines_tip = "Max minimap line points",
    },
    ru = {
        menu = "Карта для команды", main_tab = "Главное", main_group = "Настройки", alerts_tab = "Сигналы", alerts_group = "Сигнализация",
        enabled = "Включить скрипт", share = "Рисовать союзникам", maphack = "Мапхак скрытых врагов",
        hidden_delay = "Задержка после ухода с вижена", hidden_refresh = "Повтор метки скрытого героя", hidden_move = "Мин. перемещение для новой метки",
        hidden_chat_cd = "КД сообщений мапхака", lines = "Скорость рисования линий за кадр", chat = "Сообщения в командный чат",
        tp = "Вражеский телепорт", smoke = "Вражеский Smoke", scan = "Вражеский Scan", runes = "Подбор рун",
        roshan = "Атака Рошана", tormentor = "Атака Терзателя", jungle = "Враг фармит лес",
        sb_charge = "Разгон Spirit Breaker (Q)",
        sec1 = "%.1f сек", sec0 = "%.0f сек",
        hd_tip = "Сколько ждать после выхода врага из вижена перед первым сообщением",
        hr_tip = "Минимальное время до новой метки для героя",
        hm_tip = "Минимальное перемещение героя для новой метки",
        hcd_tip = "Минимальный интервал между сообщениями об одном герое",
        lines_tip = "Максимум точек линий миникарты",
    }
}
local l = TR[lang]
local RAD = 250

local tab = Menu.Create("Miscellaneous", "In Game", "Team MapHack")
tab:Icon("\u{f0c0}")
local main = tab:Create(l.main_tab):Create(l.main_group)
local alerts = tab:Create(l.alerts_tab):Create(l.alerts_group)

local ui = {
    enabled = main:Switch(l.enabled, false),
    chat = main:Switch(l.chat, true),
    share_team = main:Switch(l.share, true),
    maphack = main:Switch(l.maphack, true),
    hidden_delay = main:Slider(l.hidden_delay, 0.5, 6.0, 2.0, l.sec1),
    hidden_refresh = main:Slider(l.hidden_refresh, 4.0, 30.0, 8.0, l.sec0),
    hidden_move = main:Slider(l.hidden_move, 400, 3000, 800, "%d"),
    hidden_chat_cd = main:Slider(l.hidden_chat_cd, 5.0, 60.0, 15.0, l.sec0),
    lines = main:Slider(l.lines, 1, 24, 16, "%d"),
    tp = alerts:Switch(l.tp, true),
    smoke = alerts:Switch(l.smoke, true),
    scan = alerts:Switch(l.scan, true),
    runes = alerts:Switch(l.runes, true),
    roshan = alerts:Switch(l.roshan, true),
    tormentor = alerts:Switch(l.tormentor, true),
    jungle = alerts:Switch(l.jungle, true),
    sb_charge = alerts:Switch(l.sb_charge, true)
}

ui.chat:Unsafe(true)
ui.roshan:Unsafe(true)
ui.tormentor:Unsafe(true)
ui.hidden_delay:ToolTip(l.hd_tip)
ui.hidden_refresh:ToolTip(l.hr_tip)
ui.hidden_move:ToolTip(l.hm_tip)
ui.hidden_chat_cd:ToolTip(l.hcd_tip)
ui.lines:ToolTip(l.lines_tip)
ui.enabled:Icon("\u{f00c}")
ui.chat:Icon("\u{f075}")
ui.share_team:Icon("\u{f0c0}")
ui.maphack:Icon("\u{f3c5}")
ui.hidden_delay:Icon("\u{f017}")
ui.hidden_refresh:Icon("\u{f2f1}")
ui.hidden_move:Icon("\u{f362}")
ui.hidden_chat_cd:Icon("\u{f1da}")
ui.lines:Icon("\u{f04b}")
ui.tp:Icon("\u{f0ec}")
ui.smoke:Icon("\u{f0c2}")
ui.scan:Icon("\u{f002}")
ui.runes:Icon("\u{f02c}")
ui.roshan:Icon("\u{f6d7}")
ui.tormentor:Icon("\u{f6d7}")
ui.jungle:Icon("\u{f1bb}")
ui.sb_charge:Icon("\u{f0e7}")

local font = {
    A={{1,10,5,0},{5,0,9,10},{3,6,7,6}}, B={{1,0,1,10},{1,0,7,0},{1,5,7,5},{1,10,7,10},{7,0,8,2},{8,2,7,5},{7,5,8,8},{8,8,7,10}},
    C={{8,2,7,0},{7,0,3,0},{3,0,1,2},{1,2,1,8},{1,8,3,10},{3,10,7,10},{7,10,8,8}}, D={{1,0,1,10},{1,0,6,0},{1,10,6,10},{6,0,8,2},{8,2,8,8},{8,8,6,10}},
    E={{1,0,1,10},{1,0,8,0},{1,5,6,5},{1,10,8,10}}, F={{1,0,1,10},{1,0,8,0},{1,5,6,5}}, G={{8,2,7,0},{7,0,3,0},{3,0,1,2},{1,2,1,8},{1,8,3,10},{3,10,7,10},{7,10,8,8},{8,8,8,6},{8,6,6,6}},
    H={{1,0,1,10},{9,0,9,10},{1,5,9,5}}, I={{3,0,7,0},{5,0,5,10},{3,10,7,10}}, J={{2,0,8,0},{5,0,5,8},{5,8,4,10},{4,10,2,10},{2,10,1,8}},
    K={{1,0,1,10},{1,5,9,0},{1,5,9,10}}, L={{1,0,1,10},{1,10,8,10}}, M={{1,10,1,0},{1,0,5,4},{5,4,9,0},{9,0,9,10}}, N={{1,10,1,0},{1,0,9,10},{9,10,9,0}},
    O={{3,0,7,0},{7,0,9,2},{9,2,9,8},{9,8,7,10},{7,10,3,10},{3,10,1,8},{1,8,1,2},{1,2,3,0}}, P={{1,10,1,0},{1,0,7,0},{7,0,8,2},{8,2,7,5},{7,5,1,5}},
    Q={{3,0,7,0},{7,0,9,2},{9,2,9,8},{9,8,7,10},{7,10,3,10},{3,10,1,8},{1,8,1,2},{1,2,3,0},{6,7,9,10}}, R={{1,10,1,0},{1,0,7,0},{7,0,8,2},{8,2,7,5},{7,5,1,5},{5,5,9,10}},
    S={{8,2,7,0},{7,0,2,0},{2,0,1,2},{1,2,2,4},{2,4,7,4},{7,4,8,6},{8,6,7,8},{7,8,2,8},{2,8,1,10}}, T={{1,0,9,0},{5,0,5,10}},
    U={{1,0,1,8},{1,8,3,10},{3,10,7,10},{7,10,9,8},{9,8,9,0}}, V={{1,0,5,10},{5,10,9,0}}, W={{1,0,2,10},{2,10,5,6},{5,6,8,10},{8,10,9,0}},
    X={{1,0,9,10},{9,0,1,10}}, Y={{1,0,5,5},{9,0,5,5},{5,5,5,10}}, Z={{1,0,9,0},{9,0,1,10},{1,10,9,10}},
    ["А"]={{1,10,5,0},{5,0,9,10},{3,6,7,6}}, ["Б"]={{1,0,1,10},{1,0,8,0},{1,5,6,5},{6,5,8,7},{8,7,8,10},{8,10,1,10}},
    ["В"]={{1,0,1,10},{1,0,7,0},{1,5,7,5},{1,10,7,10},{7,0,8,2},{8,2,7,5},{7,5,8,8},{8,8,7,10}}, ["Г"]={{1,0,1,10},{1,0,8,0}},
    ["Д"]={{3,0,7,0},{7,0,7,8},{7,8,9,8},{9,8,9,10},{1,10,1,8},{1,8,3,8},{3,8,3,0},{2,8,8,8}}, ["Е"]={{1,0,1,10},{1,0,8,0},{1,5,6,5},{1,10,8,10}},
    ["Ё"]={{1,0,1,10},{1,0,8,0},{1,5,6,5},{1,10,8,10},{3,-2,3,-1},{6,-2,6,-1}}, ["Ж"]={{1,0,5,5},{9,0,5,5},{5,5,5,10},{1,10,5,5},{9,10,5,5}},
    ["З"]={{1,2,3,0},{3,0,7,0},{7,0,8,2},{8,2,6,5},{6,5,8,8},{8,8,7,10},{7,10,3,10},{3,10,1,8}}, ["И"]={{1,10,1,0},{9,10,9,0},{1,10,9,0}},
    ["Й"]={{1,10,1,0},{9,10,9,0},{1,10,9,0},{3,-2,5,-1},{5,-1,7,-2}}, ["К"]={{1,0,1,10},{1,5,9,0},{1,5,9,10}},
    ["Л"]={{2,10,5,0},{5,0,8,10}}, ["М"]={{1,10,1,0},{1,0,5,4},{5,4,9,0},{9,0,9,10}}, ["Н"]={{1,0,1,10},{9,0,9,10},{1,5,9,5}},
    ["О"]={{3,0,7,0},{7,0,9,2},{9,2,9,8},{9,8,7,10},{7,10,3,10},{3,10,1,8},{1,8,1,2},{1,2,3,0}}, ["П"]={{1,10,1,0},{1,0,9,0},{9,0,9,10}},
    ["Р"]={{1,10,1,0},{1,0,7,0},{7,0,8,2},{8,2,7,5},{7,5,1,5}}, ["С"]={{8,2,7,0},{7,0,3,0},{3,0,1,2},{1,2,1,8},{1,8,3,10},{3,10,7,10},{7,10,8,8}},
    ["Т"]={{1,0,9,0},{5,0,5,10}}, ["У"]={{1,0,5,5},{9,0,5,5},{5,5,3,10},{3,10,1,10},{1,10,0,8}},
    ["Ф"]={{5,0,5,10},{3,2,7,2},{7,2,8,3},{8,3,8,7},{8,7,7,8},{7,8,3,8},{3,8,2,7},{2,7,2,3},{2,3,3,2}}, ["Х"]={{1,0,9,10},{9,0,1,10}},
    ["Ц"]={{1,0,1,10},{7,0,7,10},{1,10,7,10},{7,10,8,12},{8,12,9,12}}, ["Ч"]={{1,0,1,5},{1,5,7,5},{7,0,7,10}},
    ["Ш"]={{1,0,1,10},{5,0,5,10},{9,0,9,10},{1,10,9,10}}, ["Щ"]={{1,0,1,10},{5,0,5,10},{9,0,9,10},{1,10,9,10},{9,10,10,12},{10,12,11,12}},
    ["Ъ"]={{1,0,4,0},{4,0,4,5},{4,5,8,5},{8,5,9,6},{9,6,9,9},{9,9,8,10},{8,10,4,10}}, ["Ы"]={{1,0,1,10},{1,5,5,5},{5,5,6,6},{6,6,6,9},{6,9,5,10},{5,10,1,10},{8,0,8,10}},
    ["Ь"]={{1,0,1,10},{1,5,7,5},{7,5,8,6},{8,6,8,9},{8,9,7,10},{7,10,1,10}}, ["Э"]={{8,2,7,0},{7,0,3,0},{3,0,1,2},{1,2,1,8},{1,8,3,10},{3,10,7,10},{7,10,8,8},{4,5,7,5}},
    ["Ю"]={{1,0,1,10},{1,5,5,5},{7,0,9,2},{9,2,9,8},{9,8,7,10},{7,10,5,10},{5,10,5,0},{5,0,7,0}}, ["Я"]={{9,10,9,0},{9,0,3,0},{3,0,2,2},{2,2,3,5},{3,5,9,5},{5,5,1,10}},
}

local cyrillic_upper = {
    ["а"] = "А", ["б"] = "Б", ["в"] = "В", ["г"] = "Г", ["д"] = "Д", ["е"] = "Е", ["ё"] = "Ё",
    ["ж"] = "Ж", ["з"] = "З", ["и"] = "И", ["й"] = "Й", ["к"] = "К", ["л"] = "Л", ["м"] = "М",
    ["н"] = "Н", ["о"] = "О", ["п"] = "П", ["р"] = "Р", ["с"] = "С", ["т"] = "Т", ["у"] = "У",
    ["ф"] = "Ф", ["х"] = "Х", ["ц"] = "Ц", ["ч"] = "Ч", ["ш"] = "Ш", ["щ"] = "Щ", ["ъ"] = "Ъ",
    ["ы"] = "Ы", ["ь"] = "Ь", ["э"] = "Э", ["ю"] = "Ю", ["я"] = "Я"
}

local function get_chars(text)
    local chars, i = {}, 1
    while i <= #text do
        local b = string.byte(text, i)
        local w = b >= 240 and 4 or b >= 224 and 3 or b >= 192 and 2 or 1
        chars[#chars + 1] = string.sub(text, i, i + w - 1)
        i = i + w
    end
    return chars
end

local ev_text = {
    en = {tp="TP", smoke="SMK", scan="SCAN", rune="RUNE", bounty="BNTY", roshan="ROSH", tormentor="TORM", jungle="JNG", charge="CHRG"},
    ru = {tp="ТП", smoke="СМОК", scan="СКАН", rune="РУНА", bounty="БАУН", roshan="РОШ", tormentor="ТЕРЗ", jungle="ЛЕС", charge="ЧАРДЖ"},
}

local my_hero
local draw_q = {}
local esp_shared = {}
local esp_pending = {}
local last_watch = 0
local last_boss = 0
local msg_throttle = {}
local ptc_watch = {}
local tp_queue = {}
local tp_start_ptc = {}
local tp_end_ptc = {}
local jungle_track = {}
local boss_dmg = {roshan = {}, tormentor = {}}
local boss_pend = {}
local rosh_data = {hp = nil, rep = false, spawned = false}
local smoke_flags = {}
local rune_cache = {}
local runes_init = false
local sb_charge = {}
local now = os.clock

local function is_torm(ent)
    return ent and (Entity.GetUnitName(ent) or "") == "npc_dota_miniboss"
end

local function get_name(h)
    local lbl = heroes[Entity.GetUnitName(h)]
    return lbl and lbl[lang == "ru" and 2 or 1] or "?"
end

local function get_disp(h)
    if not h then return "Враг" end
    local un = Entity.GetUnitName(h)
    return Engine.GetDisplayNameByUnitName(un) or un or get_name(h)
end

local function is_enemy(h)
    return my_hero and h and Entity.IsHero(h) and Entity.IsAlive(h)
        and not Entity.IsSameTeam(h, my_hero) and not NPC.IsIllusion(h)
end

local function get_esp_pos(h)
    return h and Entity.IsDormant(h) and Hero.GetLastMaphackPos(h) or nil
end

local function get_pos(h)
    if not h then return nil end
    return Entity.IsDormant(h) and Hero.GetLastMaphackPos(h) or Entity.GetAbsOrigin(h)
end

local function add_pt(pos, init)
    if #draw_q >= 360 then return false end
    draw_q[#draw_q + 1] = {pos = pos, init = init}
    return true
end

local function add_line(p1, p2)
    if #draw_q > 358 then return end
    add_pt(p1, true)
    add_pt(p2, false)
end

local function draw_circ(pos, rad)
    local pts = 8
    for i = 0, pts do
        local a = math.pi * 2 * i / pts
        add_pt(Vector(pos.x + math.cos(a) * rad, pos.y + math.sin(a) * rad, pos.z), i == 0)
    end
end

local function draw_text(txt, pos, y_off)
    local chars = get_chars(txt)
    local scale = #chars <= 2 and 56 or (#chars == 3 and 44 or 35)
    local spc = 11 * scale
    local x0 = pos.x - ((#chars - 1) * spc) / 2
    local y0 = pos.y + (y_off or 460)

    for i, c in ipairs(chars) do
        local upper_c = cyrillic_upper[c] or string.upper(c)
        local pat = font[upper_c]
        if pat then
            local x = x0 + (i - 1) * spc
            for _, ln in ipairs(pat) do
                add_line(Vector(x + ln[1] * scale, y0 + (10 - ln[2]) * scale, pos.z),
                         Vector(x + ln[3] * scale, y0 + (10 - ln[4]) * scale, pos.z))
            end
        end
    end
end

local function draw_arr(src, dst)
    local dist = src:Distance2D(dst)
    if dist < 100 then return end
    local dx, dy = dst.x - src.x, dst.y - src.y
    local ux, uy = dx / dist, dy / dist
    local hd = math.min(350, math.max(150, dist * 0.18))
    local p1 = Vector(dst.x - ux * hd + (-uy) * hd * 0.55, dst.y - uy * hd + ux * hd * 0.55, dst.z)
    local p2 = Vector(dst.x - ux * hd - (-uy) * hd * 0.55, dst.y - uy * hd - ux * hd * 0.55, dst.z)
    add_line(src, dst)
    add_line(dst, p1)
    add_line(dst, p2)
end

local function mark(pos, txt, rad)
    if not pos or #draw_q > 260 then return end
    draw_circ(pos, rad or RAD)
    draw_text(txt, pos, (rad or RAD) + 70)
end

local function say(key, msg, cd)
    if not ui.chat:Get() then return end
    local t = now()
    if msg_throttle["c:" .. key] and t - msg_throttle["c:" .. key] < (cd or 12) then return end
    msg_throttle["c:" .. key] = t
    Engine.ExecuteCommand('say_team "' .. msg .. '"')
end

local function esp_event(ev, pos, msg, key, cd)
    if not pos then return end
    local t = now()
    key = key or ev
    if msg_throttle["m:" .. key] and t - msg_throttle["m:" .. key] < (cd or 12) then return end
    msg_throttle["m:" .. key] = t
    mark(pos, ev_text[lang][ev] or ev, 430)
    say(key, msg, cd)
end

local function on_tp(h, src, dst, place)
    if not (ui.tp:Get() and h and src and dst) then return end
    local cell = math.floor(dst.x / 160) .. ":" .. math.floor(dst.y / 160)
    local key = "tp:" .. Entity.GetIndex(h) .. ":" .. cell
    local t = now()
    if msg_throttle[key] and t - msg_throttle[key] < 0.45 then return end
    msg_throttle[key] = t

    draw_arr(src, dst)
    mark(src, get_name(h), RAD)
    mark(dst, ev_text[lang]["tp"], 300)
    local msg = get_disp(h) .. (place and " телепортируется на " .. place or " телепнулся")
    say(key, msg, 0.45)
end

local function on_smk(h, pos)
    if not ui.smoke:Get() then return end
    if not is_enemy(h) then return end
    local n = h and get_disp(h) or ev_text[lang]["smoke"]
    esp_event("smoke", pos, n .. " активировал Smoke — отмечено на карте", "smk:" .. (h and Entity.GetIndex(h) or 0), 0.75)
end

local function on_jng(h, pos)
    if not ui.jungle:Get() then return end
    local key = "jng:" .. Entity.GetIndex(h)
    local t = now()
    if msg_throttle["m:" .. key] and t - msg_throttle["m:" .. key] < 1.0 then return end
    msg_throttle["m:" .. key] = t
    mark(pos, get_name(h), RAD)
    say(key, get_disp(h) .. " фармит лес — отмечено на карте", 1.0)
end

local function on_sb_charge(sb, t)
    if not ui.enabled:Get() or not ui.sb_charge:Get() then return end
    local idx = Entity.GetIndex(sb)
    local charging = NPC.HasModifier(sb, "modifier_spirit_breaker_charge_of_darkness")
    if charging and not sb_charge[idx] then
        sb_charge[idx] = {t = t}
        local pos = get_pos(sb) or Entity.GetNetOrigin(sb)
        if not pos then return end
        local msg = get_disp(sb) .. " разгоняется (Q) — Charge of Darkness!"
        esp_event("charge", pos, msg, "sb:" .. idx, 8)
    elseif not charging and sb_charge[idx] then
        sb_charge[idx] = nil
    end
end

local function get_hero(ent)
    local cur = ent
    for _ = 1, 3 do
        if cur and Entity.IsHero(cur) then return cur end
        cur = cur and Entity.GetOwner(cur) or nil
    end
    return nil
end

local function get_boss_attackers(ev, b_pos)
    local res, seen = {}, {}
    local r = boss_dmg[ev]
    for idx, e in pairs(r) do
        if now() - e.t <= 4.0 then
            if not seen[idx] then
                seen[idx] = true
                res[#res + 1] = get_disp(e.h)
            end
        else
            r[idx] = nil
        end
    end

    if #res == 0 then
        for _, h in ipairs(Heroes.GetAll()) do
            if is_enemy(h) then
                local p = get_pos(h)
                local idx = Entity.GetIndex(h)
                if p and p:Distance2D(b_pos) < 1800 and not seen[idx] then
                    seen[idx] = true
                    res[#res + 1] = get_disp(h)
                end
            end
        end
    end
    return res
end

local function add_boss_dmg(npc, ev, src)
    local h = get_hero(src)
    if not is_enemy(h) then
        boss_pend[ev] = {n = npc, due = now()}
        return
    end
    boss_dmg[ev][Entity.GetIndex(h)] = {h = h, t = now()}
    local atks = get_boss_attackers(ev, Entity.GetAbsOrigin(npc))
    if #atks > 0 and (ev == "roshan" and ui.roshan:Get() or ev == "tormentor" and ui.tormentor:Get()) then
        local obj = ev == "roshan" and "Рошана" or "Терзателя"
        esp_event(ev, Entity.GetAbsOrigin(npc), "Враги атакуют " .. obj .. ": " .. table.concat(atks, ", "), ev, 20)
    end
end

local function get_twr_name(ent)
    local n = (Entity.GetUnitName(ent) or ""):lower()
    local t = n:match("tower(%d)") or n:match("tower_(%d)") or "?"
    local loc = n:find("_top", 1, true) and "верхняя" or n:find("_mid", 1, true) and "центральная" or n:find("_bot", 1, true) and "нижняя"
    return "вышку T" .. t .. (loc and " (" .. loc .. ")" or "")
end

local function is_outp(ent)
    local n = (Entity.GetUnitName(ent) or ""):lower()
    return n:find("outpost", 1, true) or n:find("watchtower", 1, true) or n:find("watch_tower", 1, true)
end

local function get_tp_name(dst, tgt)
    if tgt then
        local n = (Entity.GetUnitName(tgt) or ""):lower()
        if n:find("fountain", 1, true) then return "фонтан" end
        if is_outp(tgt) then return Entity.GetAbsOrigin(tgt).x < 0 and "левый аванпост" or "правый аванпост" end
        if n:find("tower", 1, true) then return get_twr_name(tgt) end
        if n:find("rax", 1, true) or n:find("barracks", 1, true) then return "вышку T4" end
    end
    for _, npc in ipairs(NPCs.GetAll()) do
        if is_outp(npc) and Entity.GetAbsOrigin(npc):Distance2D(dst) <= 1000 then
            return Entity.GetAbsOrigin(npc).x < 0 and "левый аванпост" or "правый аванпост"
        end
    end
    local best_twr, best_dist = nil, 999999
    for _, tw in ipairs(Towers.GetAll()) do
        local d = Entity.GetAbsOrigin(tw):Distance2D(dst)
        if d < best_dist then best_twr, best_dist = tw, d end
    end
    if best_twr and best_dist <= 1000 then return get_twr_name(best_twr) end
    for _, npc in ipairs(NPCs.GetAll()) do
        if (Entity.GetUnitName(npc) or ""):lower():find("fountain", 1, true) and Entity.GetAbsOrigin(npc):Distance2D(dst) <= 1250 then
            return "фонтан"
        end
    end
    return nil
end

local function get_nearest(pos, rad)
    local best, dist = nil, rad or 999999
    for _, h in ipairs(Heroes.GetAll()) do
        if is_enemy(h) then
            local p = get_pos(h)
            if p and p:Distance2D(pos) <= dist then
                best, dist = h, p:Distance2D(pos)
            end
        end
    end
    return best
end

local function chk_pos(p)
    return p and (math.abs(p.x) > 32 or math.abs(p.y) > 32) and Vector(p.x, p.y, p.z) or nil
end

local function best_tp_src(h)
    return chk_pos(Entity.GetNetOrigin(h)) or chk_pos(Entity.GetAbsOrigin(h)) or chk_pos(Hero.GetLastMaphackPos(h))
end

function team_map.OnUnitAnimation(d)
    if not ui.enabled:Get() or not d.unit or not is_enemy(d.unit) then return end
    local a = d.activity
    if a == Enum.GameActivity.ACT_DOTA_TELEPORT or a == Enum.GameActivity.ACT_DOTA_TELEPORT_START or a == Enum.GameActivity.ACT_DOTA_TELEPORT_COOP_START then
        local idx = Entity.GetIndex(d.unit)
        tp_queue[idx] = tp_queue[idx] or {h = d.unit, t = now()}
        tp_queue[idx].anim_src = best_tp_src(d.unit)
        tp_queue[idx].anim_t = now()
    end
end

function team_map.OnPrepareUnitOrders(d)
    if not ui.enabled:Get() or not my_hero then return true end

    if d.order == Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TARGET and d.ability and d.npc then
        local ability_name = Ability.GetName(d.ability) or ""
        if ability_name == "spirit_breaker_charge_of_darkness" then
            if is_enemy(d.npc) then
                local target_ent = d.target
                local target_name = nil

                if target_ent then
                    local hero_owner = target_ent
                    for _ = 1, 3 do
                        if hero_owner and Entity.IsHero(hero_owner) then break end
                        hero_owner = hero_owner and Entity.GetOwner(hero_owner) or nil
                    end
                    if hero_owner and Entity.IsHero(hero_owner) then
                        target_name = get_disp(hero_owner)
                    else
                        target_name = get_disp(target_ent)
                    end
                end

                if not target_name or target_name == "" then
                    local sb_pos = get_pos(d.npc) or Entity.GetNetOrigin(d.npc)
                    if sb_pos then
                        local best, best_dist = nil, 2500
                        for _, h in ipairs(Heroes.GetAll()) do
                            if not Entity.IsSameTeam(h, d.npc) then
                                local p = get_pos(h) or Entity.GetAbsOrigin(h)
                                if p then
                                    local dd = p:Distance2D(sb_pos)
                                    if dd < best_dist then best, best_dist = h, dd end
                                end
                            end
                        end
                        if best then
                            target_name = get_disp(best)
                        end
                    end
                end

                if not target_name or target_name == "" then
                    target_name = "?"
                end

                local pos = get_pos(d.npc) or Entity.GetNetOrigin(d.npc)
                if pos and ui.sb_charge:Get() then
                    local msg = get_disp(d.npc) .. " разгоняется в " .. target_name
                    esp_event("charge", pos, msg, "sb:" .. Entity.GetIndex(d.npc), 5)
                end
            end
        end
    end

    if d.order == Enum.UnitOrder.DOTA_UNIT_ORDER_RADAR then
        if d.player and not Entity.IsSameTeam(d.player, my_hero) and ui.scan:Get() then
            esp_event("scan", d.position, "Враги использовали Scan — отмечено на карте", "scan", 0.75)
        end
        return true
    end

    if not is_enemy(d.npc) then return true end

    if d.ability then
        local n = Ability.GetName(d.ability)
        if n == "item_tpscroll" or n == "item_travel_boots" or n == "item_travel_boots_2" then
            local dst = d.target and Entity.GetAbsOrigin(d.target) or d.position
            local idx = Entity.GetIndex(d.npc)
            tp_queue[idx] = tp_queue[idx] or {h = d.npc}
            tp_queue[idx].dst = chk_pos(dst)
            tp_queue[idx].place = get_tp_name(dst, d.target)
            tp_queue[idx].ord_src = best_tp_src(d.npc)
            tp_queue[idx].t = now()
        end
    end

    if d.order == Enum.UnitOrder.DOTA_UNIT_ORDER_PICKUP_RUNE and d.target and ui.runes:Get() then
        local rt = Rune.GetRuneType(d.target)
        if rt ~= Enum.RuneType.DOTA_RUNE_XP then
            local pos = Entity.GetAbsOrigin(d.target)
            local txt = rt == Enum.RuneType.DOTA_RUNE_BOUNTY and ("баунти " .. (pos.y >= 0 and "сверху" or "снизу")) or ("руну " .. (pos.x < 0 and "слева" or "справа"))
            local ev = rt == Enum.RuneType.DOTA_RUNE_BOUNTY and "bounty" or "rune"
            esp_event(ev, pos, get_disp(d.npc) .. " забрал " .. txt .. "!", "r:" .. rt .. ":" .. math.floor(pos.x/600), 0.75)
        end
    end
    return true
end

function team_map.OnEntityHurt(d)
    if not ui.enabled:Get() or not d.target or not Entity.IsNPC(d.target) then return end
    if is_torm(d.target) then
        add_boss_dmg(d.target, "tormentor", d.source)
    end
end

function team_map.OnModifierCreate(ent, mod)
    if not ui.enabled:Get() then return end
    my_hero = my_hero or Heroes.GetLocal()
    if not my_hero then return end
    -- Только для врагов
    if not is_enemy(ent) then return end
    if Modifier.GetName(mod) == "modifier_smoke_of_deceit" then
        on_smk(ent, get_pos(ent) or Entity.GetNetOrigin(ent))
    end
    if NPC.GetUnitName(ent) == "npc_dota_hero_spirit_breaker"
        and Modifier.GetName(mod) == "modifier_spirit_breaker_charge_of_darkness" then
        on_sb_charge(ent, now())
    end
end

local function handle_ptc(d)
    if not ui.enabled:Get() or not d.position then return end
    local h = tp_start_ptc[d.index]
    if h then
        local p = chk_pos(d.position)
        if p then
            local idx = Entity.GetIndex(h)
            tp_queue[idx] = tp_queue[idx] or {h = h, t = now()}
            tp_queue[idx].ptc_src = p
            tp_start_ptc[d.index] = nil
        end
        return
    end
    h = tp_end_ptc[d.index]
    if h then
        local p = chk_pos(d.position)
        if p then
            local idx = Entity.GetIndex(h)
            tp_queue[idx] = tp_queue[idx] or {h = h, t = now()}
            tp_queue[idx].ptc_dst = p
            tp_end_ptc[d.index] = nil
        end
        return
    end
    local w = ptc_watch[d.index]
    if w then
        if w.k == "scan" and not w.rep then
            w.rep = true
            esp_event("scan", d.position, "Враги использовали Scan — отмечено на карте", "scan", 0.75)
        elseif w.k == "smoke" and not w.rep then
            w.rep = true
            local ow = is_enemy(w.ent) and w.ent or nil
            if ow then
                on_smk(ow, get_pos(ow) or d.position)
            end
        end
    end
end

function team_map.OnParticleCreate(d)
    if not ui.enabled:Get() then return end
    my_hero = my_hero or Heroes.GetLocal()
    if not my_hero then return end
    local sn = (d.name or ""):lower()
    local fn = (d.fullName or sn):lower()
    local ent = d.entityForModifiers or d.entity
    if sn == "teleport_start" or fn:find("teleport_start", 1, true) then
        local h = get_hero(ent)
        if is_enemy(h) then tp_start_ptc[d.index] = h end
    elseif sn == "teleport_end" or fn:find("teleport_end", 1, true) then
        local h = get_hero(ent)
        if is_enemy(h) then tp_end_ptc[d.index] = h end
    elseif fn:find("scan", 1, true) then
    elseif fn:find("smoke", 1, true) then
        if is_enemy(ent) then
            ptc_watch[d.index] = {k = "smoke", ent = ent, t = now(), rep = true}
            on_smk(ent, get_pos(ent) or Entity.GetNetOrigin(ent))
        end
    end
end

function team_map.OnParticleUpdate(d) handle_ptc(d) end
function team_map.OnParticleUpdateFallback(d) handle_ptc(d) end
function team_map.OnParticleUpdateEntity(d) handle_ptc(d) end
function team_map.OnParticleDestroy(d)
    ptc_watch[d.index] = nil
    tp_start_ptc[d.index] = nil
    tp_end_ptc[d.index] = nil
end

function team_map.OnUpdate()
    if not ui.enabled:Get() then draw_q = {} return end
    my_hero = Heroes.GetLocal()
    if not my_hero then return end

    if ui.roshan:Get() then
        local hp = Entity.GetRoshanHealth()
        local gt = math.floor(math.max(GameRules.GetGameTime(), 0) / 60)
        local m_hp = 6000 + gt * 130
        local rosh = nil
        for _, n in ipairs(NPCs.GetAll()) do
            if NPC.IsRoshan(n) then rosh = n break end
        end

        if hp > 0 then
            if not rosh_data.spawned then
                rosh_data.spawned = true
                rosh_data.hp = nil
                rosh_data.rep = false
                say("r_spwn", lang == "ru" and "Рошан заспавнился" or "Roshan spawned", 0)
            end

            if rosh_data.hp == nil then
                rosh_data.hp = hp
            elseif hp < rosh_data.hp and not rosh_data.rep then
                if rosh then
                    esp_event("roshan", Entity.GetAbsOrigin(rosh), lang == "ru" and "Кто-то бьет Рошана" or "Someone is attacking Roshan", "rosh", 20)
                else
                    say("rosh", lang == "ru" and "Кто-то бьет Рошана" or "Someone is attacking Roshan", 20)
                end
                rosh_data.rep = true
            elseif hp >= m_hp then
                rosh_data.rep = false
            end
            rosh_data.hp = hp
        else
            rosh_data.spawned = false
            rosh_data.hp = nil
            rosh_data.rep = false
        end
    end

    for ev, p in pairs(boss_pend) do
        if now() >= p.due then
            local atks = get_boss_attackers(ev, Entity.GetAbsOrigin(p.n))
            if #atks > 0 and (ev == "roshan" and ui.roshan:Get() or ev == "tormentor" and ui.tormentor:Get()) then
                esp_event(ev, Entity.GetAbsOrigin(p.n), "Враги атакуют " .. (ev == "roshan" and "Рошана" or "Терзателя") .. ": " .. table.concat(atks, ", "), ev, 20)
            end
            boss_pend[ev] = nil
        end
    end

    for idx, p in pairs(tp_queue) do
        local src = p.ptc_src or p.anim_src or p.ord_src
        local dst = p.ptc_dst or p.dst
        local age = now() - p.t
        if p.ptc_src and dst then
            on_tp(p.h, p.ptc_src, dst, p.place or get_tp_name(dst, nil))
            tp_queue[idx] = nil
        elseif src and dst and age >= 0.50 and not Entity.IsDormant(p.h) then
            on_tp(p.h, src, dst, p.place or get_tp_name(dst, nil))
            tp_queue[idx] = nil
        elseif p.dst and age >= 0.75 and not Entity.IsDormant(p.h) then
            local alt_src = best_tp_src(p.h)
            if alt_src then on_tp(p.h, alt_src, p.dst, p.place) end
            tp_queue[idx] = nil
        elseif age >= 1.25 then
            tp_queue[idx] = nil
        end
    end

    if ui.maphack:Get() then
        for _, h in ipairs(Heroes.GetAll()) do
            if is_enemy(h) then
                local idx = Entity.GetIndex(h)
                if not Entity.IsDormant(h) then
                    esp_shared[idx], esp_pending[idx] = nil, nil
                else
                    esp_pending[idx] = esp_pending[idx] or {t = now()}
                    if now() - esp_pending[idx].t >= ui.hidden_delay:Get() then
                        local pos = Hero.GetLastMaphackPos(h)
                        if pos then
                            local prev = esp_shared[idx]
                            if not prev or (now() - prev.t >= ui.hidden_refresh:Get() and pos:Distance2D(prev.p) >= ui.hidden_move:Get()) then
                                if #draw_q < 260 then
                                    mark(pos, get_name(h), RAD)
                                    esp_shared[idx] = {p = Vector(pos.x, pos.y, pos.z), t = now()}
                                    say("mh:" .. idx, get_disp(h) .. " спалился здесь!", ui.hidden_chat_cd:Get())
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if ui.smoke:Get() then
        for _, h in ipairs(Heroes.GetAll()) do
            if is_enemy(h) then
                local idx = Entity.GetIndex(h)
                if NPC.HasModifier(h, "modifier_smoke_of_deceit") then
                    if not smoke_flags[idx] then
                        smoke_flags[idx] = true
                        on_smk(h, get_pos(h) or Entity.GetNetOrigin(h))
                    end
                else
                    smoke_flags[idx] = nil
                end
            end
        end
    end

    for _, h in ipairs(Heroes.GetAll()) do
        if is_enemy(h) and NPC.GetUnitName(h) == "npc_dota_hero_spirit_breaker" then
            on_sb_charge(h, now())
        end
    end

    if ui.runes:Get() then
        local cur = {}
        for _, r in ipairs(Runes.GetAll()) do
            cur[Entity.GetIndex(r)] = {t = Rune.GetRuneType(r), p = Entity.GetAbsOrigin(r), ts = now()}
        end
        if runes_init then
            for idx, old in pairs(rune_cache) do
                if not cur[idx] and old.t ~= Enum.RuneType.DOTA_RUNE_XP and now() - old.ts < 1.5 then
                    local h = get_nearest(old.p, 900)
                    if h then
                        local txt = old.t == Enum.RuneType.DOTA_RUNE_BOUNTY and ("баунти " .. (old.p.y >= 0 and "сверху" or "снизу")) or ("руну " .. (old.p.x < 0 and "слева" or "справа"))
                        local ev = old.t == Enum.RuneType.DOTA_RUNE_BOUNTY and "bounty" or "rune"
                        esp_event(ev, old.p, get_disp(h) .. " забрал " .. txt .. "!", "r:" .. old.t .. ":" .. math.floor(old.p.x/600), 0.75)
                    end
                end
            end
        end
        runes_init, rune_cache = true, cur
    end

    if now() - last_watch >= 1.0 then
        last_watch = now()
        if ui.jungle:Get() then
            for _, h in ipairs(Heroes.GetAll()) do
                if is_enemy(h) then
                    local pos = get_esp_pos(h)
                    local c_idx = nil
                    if pos then
                        for i, c in ipairs(Camps.GetAll()) do
                            local b = Camp.GetCampBox(c)
                            if b and pos.x >= b.min.x - 220 and pos.x <= b.max.x + 220 and pos.y >= b.min.y - 220 and pos.y <= b.max.y + 220 then
                                c_idx = i break
                            end
                        end
                    end
                    local idx = Entity.GetIndex(h)
                    local old = jungle_track[idx]
                    if c_idx then
                        if not old or old.c ~= c_idx then
                            jungle_track[idx] = {c = c_idx, t = now()}
                        elseif now() - old.t >= 2.0 and not old.rep then
                            old.rep = true
                            on_jng(h, pos)
                        end
                    else
                        jungle_track[idx] = nil
                    end
                end
            end
        end
    end

    if now() - last_boss >= 0.15 then
        last_boss = now()
        if ui.tormentor:Get() then
            for _, n in ipairs(NPCs.GetAll()) do
                if is_torm(n) and Entity.IsAlive(n) and Entity.GetHealth(n) < Entity.GetMaxHealth(n) then
                    local bp = Entity.GetAbsOrigin(n)
                    local atks, seen = {}, {}
                    for _, h in ipairs(Heroes.GetAll()) do
                        if is_enemy(h) then
                            local p = get_pos(h)
                            local idx = Entity.GetIndex(h)
                            if p and p:Distance2D(bp) < 1800 and not seen[idx] then
                                seen[idx] = true
                                atks[#atks + 1] = get_disp(h)
                            end
                        end
                    end
                    if #atks > 0 then
                        esp_event("tormentor", bp, "Враги атакуют Терзателя: " .. table.concat(atks, ", "), "torm", 20)
                    end
                end
            end
        end
    end

    for i, w in pairs(ptc_watch) do
        if now() - w.t > 3.0 then ptc_watch[i] = nil end
    end

    local drawn = 0
    local sh = not ui.share_team:Get()
    while #draw_q > 0 and drawn < ui.lines:Get() do
        local s = table.remove(draw_q, 1)
        MiniMap.SendLine(s.pos, s.init, sh)
        drawn = drawn + 1
    end
end

return team_map
