local JSON = require("assets.JSON")

local widget = {}

local dbg

local function Combo(grp, label, options, default, icon)
    local ok, el = pcall(function() return grp:Combo(label, options, default, icon) end)
    if ok and el then return el end
    return grp:Slider(label, 0, #options - 1, default or 0, "%d")
end
local function cget(el)
    if not el then return 0 end
    local v = el:Get()
    return type(v) == "number" and v or 0
end

local tab = Menu.Create("General", "Main", "\u{f6c4} PogodaUI", "PogodaUI")

local g_main  = tab:Create("Основное")
local g_fc    = tab:Create("Прогноз")
local g_style = tab:Create("Оформление")
local g_pos   = tab:Create("Позиция")

local g_alarm = tab:Create("Тревога")

local ALARM_REGIONS = {
    { ru = "Крым",                   ua = "Автономна Республіка Крим", match = "Крим",              aliases = { "Крым", "Симферополь", "Ялта", "Керчь", "Евпатория", "Феодосия", "Джанкой", "crimea", "simferopol", "yalta", "kerch", "yevpatoria", "feodosia" } },
    { ru = "Севастополь",            ua = "м. Севастополь",            match = "Севастополь",       aliases = { "Севастополь", "sevastopol" } },
    { ru = "Киев (город)",           ua = "м. Київ",                   match = "",                  aliases = { "Киев", "Київ", "kyiv", "kiev" } },
    { ru = "Киевская обл.",          ua = "Київська область",          match = "Київська",          aliases = { "Бровары", "Бровари", "Борисполь", "Бориспіль", "brovary", "boryspil", "Белая Церковь", "bila tserkva" } },
    { ru = "Винницкая обл.",         ua = "Вінницька область",         match = "Вінницька",         aliases = { "Винница", "Вінниця", "vinnyts", "vinnitsa" } },
    { ru = "Волынская обл.",         ua = "Волинська область",         match = "Волинська",         aliases = { "Луцк", "Луцьк", "lutsk" } },
    { ru = "Днепропетровская обл.",  ua = "Дніпропетровська область",  match = "Дніпропетровська",  aliases = { "Днепр", "Дніпро", "dnipro", "dnepr", "Кривой Рог", "Кривий Ріг", "kryvyi", "krivoy", "Каменское", "kamianske" } },
    { ru = "Донецкая обл.",          ua = "Донецька область",          match = "Донецька",          aliases = { "Донецк", "Донецьк", "donetsk", "Мариуполь", "Маріуполь", "mariupol", "Краматорск", "kramatorsk", "Бахмут", "bakhmut" } },
    { ru = "Житомирская обл.",       ua = "Житомирська область",       match = "Житомирська",       aliases = { "Житомир", "zhytomyr", "Бердичев", "berdychiv" } },
    { ru = "Закарпатская обл.",      ua = "Закарпатська область",      match = "Закарпатська",      aliases = { "Ужгород", "uzhhorod", "uzhgorod", "Мукачево", "mukachevo" } },
    { ru = "Запорожская обл.",       ua = "Запорізька область",        match = "Запорізька",        aliases = { "Запорожье", "Запоріжжя", "zaporizh", "Мелитополь", "melitopol", "Бердянск", "berdiansk" } },
    { ru = "Ивано-Франковская обл.", ua = "Івано-Франківська область", match = "Івано-Франківська", aliases = { "Ивано-Франковск", "Івано-Франківськ", "ivano-frankivsk", "frankivsk" } },
    { ru = "Кировоградская обл.",    ua = "Кіровоградська область",    match = "Кіровоградська",    aliases = { "Кропивницкий", "Кропивницький", "kropyvnyts", "Кировоград", "kirovohrad" } },
    { ru = "Луганская обл.",         ua = "Луганська область",         match = "Луганська",         aliases = { "Луганск", "Луганськ", "luhansk", "lugansk", "Северодонецк", "sievierodonetsk" } },
    { ru = "Львовская обл.",         ua = "Львівська область",         match = "Львівська",         aliases = { "Львов", "Львів", "lviv", "lvov", "Дрогобыч", "drohobych" } },
    { ru = "Николаевская обл.",      ua = "Миколаївська область",      match = "Миколаївська",      aliases = { "Николаев", "Миколаїв", "mykolaiv", "nikolaev" } },
    { ru = "Одесская обл.",          ua = "Одеська область",           match = "Одеська",           aliases = { "Одесса", "Одеса", "odesa", "odessa", "Измаил", "izmail", "Черноморск", "chornomorsk" } },
    { ru = "Полтавская обл.",        ua = "Полтавська область",        match = "Полтавська",        aliases = { "Полтава", "poltava", "Кременчуг", "Кременчук", "kremenchuk" } },
    { ru = "Ровенская обл.",         ua = "Рівненська область",        match = "Рівненська",        aliases = { "Ровно", "Рівне", "rivne", "rovno" } },
    { ru = "Сумская обл.",           ua = "Сумська область",           match = "Сумська",           aliases = { "Сумы", "Суми", "sumy", "Конотоп", "konotop" } },
    { ru = "Тернопольская обл.",     ua = "Тернопільська область",     match = "Тернопільська",     aliases = { "Тернополь", "Тернопіль", "ternopil" } },
    { ru = "Харьковская обл.",       ua = "Харківська область",        match = "Харківська",        aliases = { "Харьков", "Харків", "kharkiv", "kharkov" } },
    { ru = "Херсонская обл.",        ua = "Херсонська область",        match = "Херсонська",        aliases = { "Херсон", "kherson", "Каховка", "kakhovka" } },
    { ru = "Хмельницкая обл.",       ua = "Хмельницька область",       match = "Хмельницька",       aliases = { "Хмельницкий", "Хмельницький", "khmelnyts", "Каменец-Подольский", "kamianets" } },
    { ru = "Черкасская обл.",        ua = "Черкаська область",         match = "Черкаська",         aliases = { "Черкассы", "Черкаси", "cherkasy", "Умань", "uman" } },
    { ru = "Черновицкая обл.",       ua = "Чернівецька область",       match = "Чернівецька",       aliases = { "Черновцы", "Чернівці", "chernivtsi" } },
    { ru = "Черниговская обл.",      ua = "Чернігівська область",      match = "Чернігівська",      aliases = { "Чернигов", "Чернігів", "chernihiv", "Нежин", "nizhyn" } },

    { ru = "Белгородская обл.",      src = "ru", ua = "Белгородская область",      match = "Белгород",   aliases = { "Белгород", "Старый Оскол", "Губ��ин", "Шебекино", "Валуйки", "Алексеевка", "belgorod", "shebekino" } },
    { ru = "Курская обл.",           src = "ru", ua = "Курская область",           match = "Курск",      aliases = { "Курск", "Железногорск", "Курчатов", "Льгов", "Рыльск", "Суджа", "kursk", "kurchatov" } },
    { ru = "Брянская обл.",          src = "ru", ua = "Брянская область",          match = "Брянск",     aliases = { "Брянск", "Клинцы", "Новозыбков", "Унеча", "Стародуб", "bryansk", "briansk" } },
    { ru = "Воронежская обл.",       src = "ru", ua = "Воронежская область",       match = "Воронеж",    aliases = { "Воронеж", "Борисоглебск", "Россошь", "Лиски", "voronezh" } },
    { ru = "Ростовская обл.",        src = "ru", ua = "Ростовская область",        match = "Ростов",     aliases = { "Ростов-на-Дону", "Таганрог", "Шахты", "Новочеркасск", "Волгодонск", "Морозовск", "rostov", "taganrog" } },
    { ru = "Краснодарский край",     src = "ru", ua = "Краснодарский край",        match = "Краснодар",  aliases = { "Краснодар", "Сочи", "Новороссийск", "Армавир", "Ейск", "Анапа", "Туапсе", "krasnodar", "sochi", "novorossiysk", "anapa" } },
    { ru = "Республика Адыгея",      src = "ru", ua = "Республика Адыгея",         match = "Адыге",      aliases = { "Майкоп", "maykop", "adygea" } },
    { ru = "Липецкая обл.",          src = "ru", ua = "Липецкая область",          match = "Липецк",     aliases = { "Липецк", "Елец", "lipetsk", "yelets" } },
    { ru = "Орловская обл.",         src = "ru", ua = "Орловская область",         match = "Орлов",      aliases = { "Орёл", "Орел", "Ливны", "Мценск", "oryol", "orel" } },
    { ru = "Тульская обл.",          src = "ru", ua = "Тульская область",          match = "Тульск",     aliases = { "Тула", "Новомосковск", "Алексин", "Щёкино", "tula" } },
    { ru = "Калужская обл.",         src = "ru", ua = "Калужская область",         match = "Калуж",      aliases = { "Калуга", "Обнинск", "kaluga", "obninsk" } },
    { ru = "Смоленская обл.",        src = "ru", ua = "Смоленская область",        match = "Смоленск",   aliases = { "Смоленск", "Вязьма", "Рославль", "Десногорск", "smolensk" } },
    { ru = "Тамбовская обл.",        src = "ru", ua = "Тамбовская область",        match = "Тамбов",     aliases = { "Тамбов", "Мичуринск", "tambov" } },
    { ru = "Волгоградская обл.",     src = "ru", ua = "Волгоградская область",     match = "Волгоград",  aliases = { "Волгоград", "Волжский", "Камышин", "Михайловка", "volgograd" } },
    { ru = "Астраханская обл.",      src = "ru", ua = "Астраханская область",      match = "Астрахан",   aliases = { "Астрахань", "Ахтубинск", "astrakhan" } },
    { ru = "Саратовская обл.",       src = "ru", ua = "Саратовская область",       match = "Саратов",    aliases = { "Саратов", "Энгельс", "Балаково", "saratov", "engels" } },
    { ru = "Пензенская обл.",        src = "ru", ua = "Пензенская область",        match = "Пензенск",   aliases = { "Пенза", "penza" } },
    { ru = "Рязанская обл.",         src = "ru", ua = "Рязанская область",         match = "Рязанск",    aliases = { "Рязань", "Касимов", "ryazan" } },
    { ru = "Тверская обл.",          src = "ru", ua = "Тверская область",          match = "Тверск",     aliases = { "Тверь", "Ржев", "tver" } },
    { ru = "Московская обл.",        src = "ru", ua = "Московская область",        match = "Московск",   aliases = { "Москва", "Подольск", "Химки", "Балашиха", "Коломна", "Серпухов", "moscow", "moskva", "podolsk" } },
    { ru = "Псковская обл.",         src = "ru", ua = "Псковская область",         match = "Псков",      aliases = { "Псков", "Великие Луки", "pskov" } },
    { ru = "Ленинградская обл.",     src = "ru", ua = "Ленинградская область",     match = "Ленинград",  aliases = { "Санкт-Петербург", "Петербург", "СПб", "Гатчина", "Выборг", "saint petersburg", "st petersburg", "spb", "piter" } },
    { ru = "Нижегородская обл.",     src = "ru", ua = "Нижегородская область",     match = "Нижегород",  aliases = { "Нижний Новгород", "Дзержинск", "Арзамас", "nizhny", "nnov" } },
    { ru = "Республика Татарстан",   src = "ru", ua = "Республика Татарстан",      match = "Татарстан",  aliases = { "Казань", "Елабуга", "Нижнекамск", "Набережные Челны", "Альметьевск", "kazan", "yelabuga", "alabuga", "naberezhnye" } },
    { ru = "ДНР (Донецк)",           src = "ru", ua = "Донецкая Народная Республика", match = "Донецк",   aliases = { "ДНР", "ЛДНР", "Донецк", "Донецкая Народная", "Макеевка", "Горловка", "Енакиево", "Ясиноватая", "Харцызск", "Дебальцево", "Шахтёрск", "Шахтерск", "Торез", "Чистяково", "Снежное", "Мариуполь", "Волноваха", "Докучаевск", "Ждановка", "Амвросиевка", "donetsk", "makiivka", "horlivka", "mariupol" } },
    { ru = "ЛНР (Луганск)",          src = "ru", ua = "Луганская Народная Республика", match = "Луганск",  aliases = { "ЛНР", "ЛДНР", "Луганск", "Луганская Народная", "Алчевск", "Стаханов", "Кадиевка", "Брянка", "Ровеньки", "Свердловск", "Краснодон", "Антрацит", "Красный Луч", "Хрустальный", "Первомайск", "Лисичанск", "Северодонецк", "Рубежное", "��ременная", "Старобельск", "luhansk", "lugansk", "alchevsk", "stakhanov" } },
    { ru = "Запорожская обл. (РФ)",   src = "ru", ua = "Запорожская область",       match = "Запорожск",  aliases = { "Мелитополь", "Бердянск", "Энергодар", "Токмак", "Васильевка", "Пологи", "melitopol", "berdiansk", "enerhodar" } },
    { ru = "Херсонская обл. (РФ)",    src = "ru", ua = "Херсонская область",        match = "��ерсонск",   aliases = { "Геническ", "Скадовск", "Голая Пристань", "Новая Каховка", "Алёшки", "Алешки", "henichesk", "skadovsk" } },
}
local ALARM_REGION_NAMES = {}
for i = 1, #ALARM_REGIONS do ALARM_REGION_NAMES[i] = ALARM_REGIONS[i].ru end

local ui = {}

ui.enabled   = g_main:Switch("Включить виджет", true, "\u{f00c}")
ui.autocity  = g_main:Switch("Автоопределение города", true, "\u{f3c5}")
ui.city      = g_main:Input("Город (вручную)", "Киев", "\u{f002}")
ui.tempunit  = Combo(g_main, "Единицы температуры", { "°C", "°F" }, 0, "\u{f2c9}")
ui.windunit  = Combo(g_main, "Единицы ветра", { "м/с", "км/ч", "mph" }, 0, "\u{f72e}")
ui.lang_ru   = g_main:Switch("Русские подписи", true)
ui.refresh   = g_main:Slider("Обновлять раз в", 1, 60, 10, "%d мин")
ui.update    = g_main:Button("Обновить сейчас", function() widget.force_refresh() end)
ui.om_proxy_first = g_main:Switch("Open-Meteo сразу через прокси (RU)", false, "\u{f0ac}")


ui.layout      = Combo(g_fc, "Режим компоновки", { "Компактный", "Стандартный", "Подробный" }, 1, "\u{f009}")
ui.show_hourly = g_fc:Switch("Почасовой прогноз (в «Подробном»)", true, "\u{f017}")
ui.show_sun    = g_fc:Switch("Восход и закат", true, "\u{f185}")
ui.show_extra  = g_fc:Switch("Давление и UV-индекс", true, "\u{f0c2}")
ui.show_feels  = g_fc:Switch("Показывать «Ощущается»", true)
ui.show_hilo   = g_fc:Switch("Мин/макс за день", true)
ui.show_clock  = g_fc:Switch("Дата и время", true)
ui.clock_secs  = g_fc:Switch("Секунды во времени", false)
ui.show_status = g_fc:Switch("Строка статуса (источник)", true)

ui.theme       = Combo(g_style, "Тема", { "Glass", "ImGui", "Figma HUD", "Neon", "Station", "Aurora", "Bento", "Blueprint", "Ticket" }, 0, "\u{f53f}")
ui.font        = Combo(g_style, "Шрифт", { "Museo Sans", "Tahoma", "Verdana", "Segoe UI", "Roboto" }, 0, "\u{f031}")
ui.auto_accent = g_style:Switch("Акцент по погоде", true, "\u{f5c0}")
ui.accent      = g_style:ColorPicker("Цвет акцента", Color(94, 152, 247), "\u{f53f}")
ui.animations  = g_style:Switch("Анимации", true, "\u{f0e7}")
ui.shadow      = g_style:Switch("Тень", true)
ui.particles   = g_style:Switch("Частицы осадков", true, "\u{f73d}")
ui.scale       = g_style:Slider("Масштаб", 0.7, 2.0, 1.0, "%.1fx")
ui.textsize    = g_style:Slider("Размер текста", 75, 150, 100, "%d%%")
ui.opacity     = g_style:Slider("Прозрачность фона", 120, 255, 238, "%d")
ui.reset       = g_style:Button("Сбросить оформление", function() widget.reset_style() end)

ui.corner = Combo(g_pos, "Привязка к углу", { "Свободно", "Лево верх", "Право верх", "Лево низ", "Право низ" }, 0, "\u{f0b2}")
ui.lock  = g_pos:Switch("Заблокировать позицию", false, "\u{f023}")
ui.pos_x = g_pos:Slider("X", 0, 3840, 40, "%d")
ui.pos_y = g_pos:Slider("Y", 0, 2160, 40, "%d")

ui.alarm_enable  = g_alarm:Switch("Воздушная тревога", true, "\u{f0f3}")
ui.alarm_region  = Combo(g_alarm, "Регион", ALARM_REGION_NAMES, 0, "\u{f3c5}")
ui.alarm_ru_src  = Combo(g_alarm, "Источник РФ", { "Telegram: Купол России", "Свой URL (JSON)" }, 0, "\u{f1d8}")
ui.alarm_ru_url  = g_alarm:Input("URL источника РФ (JSON)", "", "\u{f0c1}")
ui.alarm_auto    = g_alarm:Switch("Регион по городу погоды", false, "\u{f124}")
ui.alarm_flash   = g_alarm:Switch("Подсветка краёв экрана", false, "\u{f0e7}")
ui.alarm_status  = g_alarm:Switch("Плашка статуса", true, "\u{f05a}")
ui.alarm_hide    = Combo(g_alarm, "Скрывать плашку", { "Постоянно", "Через 5 с", "Через 10 с", "Через 15 с", "Через 30 с", "Через 60 с" }, 0, "\u{f017}")
ui.alarm_move    = g_alarm:Switch("Двигать плашку мышью", false, "\u{f0b2}")
ui.alarm_px      = g_alarm:Slider("Плашка X", 0, 3840, 60, "%d")
ui.alarm_py      = g_alarm:Slider("Плашка Y", 0, 2160, 26, "%d")
ui.alarm_refresh = g_alarm:Slider("Проверять раз в", 15, 180, 30, "%d с")
ui.alarm_check   = g_alarm:Button("Проверить тревогу сейчас", function()
    if widget.check_alarm then widget.check_alarm() end
end)

local g_debug = tab:Create("Debug")
ui.debug_on    = g_debug:Switch("Debug-консоль на экране", false, "\u{f188}")
ui.debug_lines = g_debug:Slider("Строк лога", 5, 30, 14, "%d")
ui.debug_test  = g_debug:Button("Принудительно обновить погоду", function()
    if widget.force_refresh then widget.force_refresh() end
end)
ui.debug_clear = g_debug:Button("Очистить лог", function()
    if dbg then dbg.clear() end
end)

local FF = Enum.FontCreate.FONTFLAG_ANTIALIAS | Enum.FontCreate.FONTFLAG_DROPSHADOW
local FONT_FAMILIES = { "MuseoSansEx", "Tahoma", "Verdana", "Segoe UI", "Roboto" }
local function load_weight(name, w)
    local ok, f = pcall(Render.LoadFont, name, FF, w)
    if ok and f then return f end
    return nil
end
local FONTS = {}
for i, fam in ipairs(FONT_FAMILIES) do
    FONTS[i] = { city = load_weight(fam, 600), text = load_weight(fam, 400), temp = load_weight(fam, 700) }
end
local FONT_BASE = FONTS[1]
local font_city = FONT_BASE.city
local font_text = FONT_BASE.text
local font_temp = FONT_BASE.temp
local g_ts = 1.0
local function apply_fonts()
    local fi = (cget(ui.font) or 0) + 1
    local f = FONTS[fi] or FONT_BASE
    font_city = f.city or FONT_BASE.city
    font_text = f.text or FONT_BASE.text
    font_temp = f.temp or FONT_BASE.temp
end

local col_white  = Color(238, 241, 247, 255)
local col_dim    = Color(150, 157, 170, 255)
local col_faint  = Color(108, 114, 126, 255)
local col_line   = Color(255, 255, 255, 16)
local col_top    = Color(255, 255, 255, 18)
local col_sun    = Color(255, 201, 64, 255)
local col_moon   = Color(220, 226, 238, 255)
local col_cloud  = Color(196, 203, 216, 255)
local col_rain   = Color(120, 170, 235, 255)
local col_snow   = Color(232, 238, 250, 255)
local col_shadow = Color(0, 0, 0, 180)
local col_hi     = Color(255, 150, 90, 255)
local col_lo     = Color(110, 170, 235, 255)
local dot_precip = Color(120, 170, 235, 255)
local dot_humid  = Color(80, 200, 190, 255)
local dot_wind   = Color(170, 178, 190, 255)
local dot_feels  = Color(255, 170, 90, 255)
local dot_press  = Color(150, 160, 230, 255)

local WEEKDAYS = { "Воскресенье", "Понедельник", "Вторник", "Среда", "Четверг", "Пятница", "Суббота" }
local DIRS_RU = { "С","ССВ","СВ","ВСВ","В","ВЮВ","ЮВ","ЮЮВ","Ю","ЮЮЗ","ЮЗ","ЗЮЗ","З","ЗСЗ","СЗ","ССЗ" }
local DIRS_EN = { "N","NNE","NE","ENE","E","ESE","SE","SSE","S","SSW","SW","WSW","W","WNW","NW","NNW" }

local state = {
    city = "Киев", temp = nil, feels = nil, humidity = nil,
    precip = nil, wind = nil, wind_dir = nil, pressure = nil, uv = nil,
    desc = "—", cat = "cloud", is_day = true, source = "Open-Meteo",
    t_max = nil, t_min = nil, sunrise = nil, sunset = nil,
    hourly = {},
    loaded = false, loading = false, error = nil,
    last_pull = -1e18, fetched_clock = nil, anim = 0,
    disp_temp = nil, last_draw = nil,
}
local drag = { active = false, dx = 0, dy = 0 }
local adrag = { active = false, dx = 0, dy = 0 }
local particles = {}

local DBG_MAX = 200
dbg = {
    lines = {},
    stats = { req = 0, ok = 0, err = 0 },
}
function dbg.log(lvl, msg)
    local ln = { lvl = lvl or "INFO", ts = os.date("%H:%M:%S"), msg = tostring(msg or "") }
    dbg.lines[#dbg.lines + 1] = ln
    if #dbg.lines > DBG_MAX then table.remove(dbg.lines, 1) end
end
function dbg.clear()
    dbg.lines = {}
    dbg.stats = { req = 0, ok = 0, err = 0 }
    dbg.log("INFO", "Лог очищен")
end
local function dbg_resp(resp)
    if type(resp) ~= "table" then return "нет ответа от сервера" end
    local body = resp["response"]
    local code = resp["status"] or resp["status_code"] or resp["code"] or "?"
    local len = (type(body) == "string") and #body or 0
    return ("HTTP=%s len=%d"):format(tostring(code), len)
end
local function dbg_snip(resp, n)
    local body = type(resp) == "table" and resp["response"]
    if type(body) ~= "string" or body == "" then return "<пустое тело ответа>" end
    return (body:gsub("%s+", " ")):sub(1, n or 160)
end

local function decode_code(code)
    local m = {
        [0]={"Ясно","clear"},[1]={"Преимущественно ясно","clear"},
        [2]={"Пере��енная облачность","partly"},[3]={"Пасмурно","cloud"},
        [45]={"Туман","fog"},[48]={"Из��орозь","fog"},
        [51]={"Лёгкая морось","rain"},[53]={"Морось","rain"},[55]={"Сильная морось","rain"},
        [56]={"Ледяная морось","rain"},[57]={"Ледяная морось","rain"},
        [61]={"Небольшой дождь","rain"},[63]={"Дождь","rain"},[65]={"Сильный дождь","rain"},
        [66]={"Ледяной дождь","rain"},[67]={"Ледяной дождь","rain"},
        [71]={"Небольшой снег","snow"},[73]={"Снег","snow"},[75]={"Сильный снег","snow"},
        [77]={"Снежная крупа","snow"},
        [80]={"Кратковременный дождь","rain"},[81]={"Ливень","rain"},[82]={"Сильный ливень","rain"},
        [85]={"Снегопад","snow"},[86]={"Сильный снегопад","snow"},
        [95]={"Гроза","storm"},[96]={"Гроза с градом","storm"},[99]={"Сильная гроза","storm"},
    }
    local e = m[code]
    if e then return e[1], e[2] end
    return "Облачно", "cloud"
end

local function fmt_secs(s)
    s = math.max(0, math.ceil(s))
    if s >= 60 then return string.format("%d:%02d", math.floor(s / 60), s % 60) end
    return tostring(s) .. "с"
end
local function fmt_ago(s)
    s = math.max(0, math.floor(s))
    if s >= 60 then return string.format("%dм назад", math.floor(s / 60)) end
    return s .. "с назад"
end
local function hhmm(iso) return iso and iso:sub(12, 16) or "--:--" end
local function hour_of(iso) return tonumber(iso and iso:sub(12, 13)) or 0 end

local function is_f() return cget(ui.tempunit) == 1 end
local function conv_temp(c) if c == nil then return nil end if is_f() then return c * 9 / 5 + 32 end return c end
local function temp_unit() return is_f() and "°F" or "°C" end
local WIND_K = { 1.0, 3.6, 2.23694 }
local WIND_L = { "м/с", "км/ч", "mph" }
local function conv_wind(ms) return (ms or 0) * (WIND_K[cget(ui.windunit) + 1] or 1.0) end
local function wind_unit() return WIND_L[cget(ui.windunit) + 1] or "м/с" end
local function compass(deg)
    if not deg then return "—" end
    local t = ui.lang_ru:Get() and DIRS_RU or DIRS_EN
    return t[(math.floor((deg % 360) / 22.5 + 0.5) % 16) + 1]
end

local function urlencode(s)
    return (s:gsub("[^%w%-_%.~]", function(c) return string.format("%%%02X", string.byte(c)) end))
end
local HDR = { headers = { ["User-Agent"] = "PogodaUI/4.2", ["Accept"] = "application/json" } }
local HDR_HTML = { headers = { ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) PogodaUI/4.3", ["Accept"] = "text/html,application/xhtml+xml" } }
local HDR_METNO = { headers = { ["User-Agent"] = "PogodaUI/4.3 weather-widget (uc.zone)", ["Accept"] = "application/json" } }
-- corsproxy.io отдаёт 403 без браузерных заголовков; добавляем Origin + x-requested-with
local HDR_CORS  = { headers = { ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Safari/537.36", ["Accept"] = "application/json", ["x-requested-with"] = "XMLHttpRequest", ["Origin"] = "https://uc.zone", ["Referer"] = "https://uc.zone/" } }

local function apply(o)
    state.city     = o.city or state.city
    state.temp     = o.temp
    state.feels    = o.feels
    state.humidity = o.humidity
    state.precip   = o.precip or 0
    state.wind     = o.wind
    state.wind_dir = o.wind_dir
    state.pressure = o.pressure
    state.uv       = o.uv
    state.desc     = o.desc
    state.cat      = o.cat
    state.is_day   = o.is_day
    state.t_max    = o.t_max
    state.t_min    = o.t_min
    state.sunrise  = o.sunrise
    state.sunset   = o.sunset
    state.hourly   = o.hourly or {}
    state.source   = o.source or state.source or "Open-Meteo"
    state.loaded, state.loading, state.error = true, false, nil
    state.fetched_clock = os.clock()
    dbg.stats.ok = dbg.stats.ok + 1
    dbg.log("OK", ("%s: %s, %s%s"):format(
        o.source or "?", tostring(state.city),
        state.temp ~= nil and (math.floor(state.temp + 0.5) .. "°C") or "?",
        (state.desc and state.desc ~= "" and state.desc ~= "—") and (" / " .. state.desc) or ""))
end

local function numstr(v)
    local s = (type(v) == "number") and string.format("%.6f", v) or tostring(v)
    return (s:gsub(",", "."))
end

local fetch_metno, fetch_wttr, fetch_7timer

local function iso_min(iso)
    if type(iso) ~= "string" then return nil end
    return (tonumber(iso:sub(12, 13)) or 0) * 60 + (tonumber(iso:sub(15, 16)) or 0)
end

local function ampm_to_iso(s)
    if type(s) ~= "string" then return nil end
    local hh, mm, ap = s:match("(%d+):(%d+)%s*([AaPp])")
    if not hh then
        hh, mm = s:match("(%d+):(%d+)")
        if not hh then return nil end
        return ("0000-00-00T%02d:%02d"):format(tonumber(hh), tonumber(mm))
    end
    hh, mm = tonumber(hh), tonumber(mm)
    ap = ap:upper()
    if ap == "P" and hh < 12 then hh = hh + 12 end
    if ap == "A" and hh == 12 then hh = 0 end
    return ("0000-00-00T%02d:%02d"):format(hh, mm)
end

local function decode_metno(sym)
    local s = tostring(sym or ""):gsub("_day$", ""):gsub("_night$", ""):gsub("_polartwilight$", "")
    local function has(p) return s:find(p, 1, true) ~= nil end
    if has("thunder")      then return "Гроза", "storm" end
    if has("snow")         then return "Снег", "snow" end
    if has("sleet")        then return "Мокрый снег", "snow" end
    if has("rainshowers")  then return "Кратковременный дождь", "rain" end
    if has("rain")         then return "Дождь", "rain" end
    if has("fog")          then return "Туман", "fog" end
    if s == "cloudy"       then return "Пасмурно", "cloud" end
    if has("partlycloudy") then return "Переменная облачность", "partly" end
    if has("fair")         then return "Малооблачно", "partly" end
    if has("clearsky")     then return "Ясно", "clear" end
    return "Облачно", "cloud"
end


local SEVENT = {
    clear     = { "Ясно", "clear" },
    pcloudy   = { "Малооблачно", "partly" },
    mcloudy   = { "Облачно", "cloud" },
    cloudy    = { "Пасмурно", "cloud" },
    humid     = { "Туман", "fog" },
    fog       = { "Туман", "fog" },
    lightrain = { "Небольшой дождь", "rain" },
    oshower   = { "Местами дождь", "rain" },
    ishower   = { "Ливень", "rain" },
    rain      = { "Дождь", "rain" },
    lightsnow = { "Небольшой снег", "snow" },
    snow      = { "Снег", "snow" },
    rainsnow  = { "Дождь со снегом", "snow" },
    ts        = { "Гроза", "storm" },
    tsrain    = { "Гроза с дождём", "storm" },
}
local SEV_WIND = { 0.2, 1.5, 5, 9, 14, 20, 28, 35 }
local SEV_DIR  = { N = 0, NE = 45, E = 90, SE = 135, S = 180, SW = 225, W = 270, NW = 315 }
local function decode_7timer(w)
    local s = tostring(w or ""):gsub("day$", ""):gsub("night$", "")
    local e = SEVENT[s]
    if e then return e[1], e[2] end
    return "Облачно", "cloud"
end

local WTTR_CAT = {
    [113]="clear",[116]="partly",[119]="cloud",[122]="cloud",
    [143]="fog",[248]="fog",[260]="fog",
    [176]="rain",[263]="rain",[266]="rain",[281]="rain",[284]="rain",[293]="rain",
    [296]="rain",[299]="rain",[302]="rain",[305]="rain",[308]="rain",[311]="rain",
    [314]="rain",[353]="rain",[356]="rain",[359]="rain",
    [179]="snow",[182]="snow",[185]="snow",[227]="snow",[230]="snow",[317]="snow",
    [320]="snow",[323]="snow",[326]="snow",[329]="snow",[332]="snow",[335]="snow",
    [338]="snow",[350]="snow",[362]="snow",[365]="snow",[368]="snow",[371]="snow",
    [374]="snow",[377]="snow",
    [200]="storm",[386]="storm",[389]="storm",[392]="storm",[395]="storm",
}
local function wttr_cat(code) return WTTR_CAT[tonumber(code) or -1] or "cloud" end

-- Маршруты к Open-Meteo: прямой, прямой короткий, затем через бесплатные прокси (обход блокировки для RU IP). Данные идентичны.
local OM_TRY = {
    { proxy = nil,                                   short = false, name = "прямой" },
    { proxy = nil,                                   short = true,  name = "прямой/короткий" },
    { proxy = "https://corsproxy.io/?url=",              short = false, hdr = HDR_CORS, name = "corsproxy" },
    { proxy = "https://api.codetabs.com/v1/proxy/?quest=", short = false, name = "codetabs" },
    { proxy = "https://api.allorigins.win/raw?url=",       short = false, name = "allorigins" },
    { proxy = "https://thingproxy.freeboard.io/fetch/", short = false, raw = true, name = "thingproxy" },
}

local function fetch_openmeteo(lat, lon, cityName, attempt)
    if not attempt then
        attempt = (ui.om_proxy_first and ui.om_proxy_first:Get()) and 3 or 1
    end
    local t = OM_TRY[attempt] or OM_TRY[1]
    state.load_at = os.clock()  -- сбрасываем таймер активности: перебор маршрутов не должен считаться таймаутом
    local C = "%2C"  -- кодируем запятые: сырые "," в длинном URL часто режут RU-провайдеры (HTTP=0)
    local base = ("https://api.open-meteo.com/v1/forecast?latitude=%s&longitude=%s"):format(numstr(lat), numstr(lon))
    local target
    if t.short then
        target = base .. "&current=temperature_2m" .. C .. "apparent_temperature" .. C .. "relative_humidity_2m" .. C
            .. "precipitation_probability" .. C .. "weather_code" .. C .. "wind_speed_10m" .. C
            .. "wind_direction_10m" .. C .. "is_day" .. C .. "surface_pressure" .. C .. "uv_index"
            .. "&wind_speed_unit=ms&timezone=auto"
    else
        target = base .. "&current=temperature_2m" .. C .. "apparent_temperature" .. C .. "relative_humidity_2m" .. C
            .. "precipitation_probability" .. C .. "weather_code" .. C .. "wind_speed_10m" .. C
            .. "wind_direction_10m" .. C .. "is_day" .. C .. "surface_pressure" .. C .. "uv_index"
            .. "&hourly=temperature_2m" .. C .. "weather_code" .. C .. "precipitation_probability"
            .. "&daily=temperature_2m_max" .. C .. "temperature_2m_min" .. C .. "sunrise" .. C .. "sunset"
            .. "&wind_speed_unit=ms&timezone=auto&forecast_days=2"
    end
    local url
    if t.proxy then
        url = t.proxy .. (t.raw and target or urlencode(target))
    else
        url = target
    end
    dbg.stats.req = dbg.stats.req + 1
    dbg.log("REQ", ("Open-Meteo %s,%s (%s)"):format(numstr(lat), numstr(lon), t.name))
    HTTP.Request("GET", url, t.hdr or HDR, function(resp)
        local body = resp and resp["response"]
        local ok, d = pcall(function() return JSON:decode(body) end)
        if not ok or not d or not d.current then
            local nxt = OM_TRY[attempt + 1]
            if nxt then
                dbg.log("WARN", ("Open-Meteo не ответил (%s, %s) → %s"):format(t.name, dbg_resp(resp), nxt.name))
                fetch_openmeteo(lat, lon, cityName, attempt + 1); return
            end
            dbg.log("WARN", "Open-Meteo недоступен по всем маршрутам (" .. dbg_resp(resp) .. ") → MET.no")
            fetch_metno(lat, lon, cityName); return
        end
        state.loading = false
        local c = d.current
        local desc, cat = decode_code(c.weather_code or 2)

        local hourly = {}
        if d.hourly and d.hourly.time then
            local now = c.time or d.hourly.time[1]
            local start = 1
            for i, tv in ipairs(d.hourly.time) do
                if tv >= now then start = i; break end
            end
            for i = start, math.min(start + 5, #d.hourly.time) do
                local _, hc = decode_code(d.hourly.weather_code[i] or 2)
                hourly[#hourly + 1] = {
                    h = hour_of(d.hourly.time[i]),
                    temp = d.hourly.temperature_2m[i],
                    cat = hc,
                    pop = d.hourly.precipitation_probability and d.hourly.precipitation_probability[i] or 0,
                }
            end
        end

        local dl = d.daily or {}
        apply{
            city = cityName, temp = c.temperature_2m, feels = c.apparent_temperature,
            humidity = c.relative_humidity_2m, precip = c.precipitation_probability or 0,
            wind = c.wind_speed_10m, wind_dir = c.wind_direction_10m,
            pressure = c.surface_pressure, uv = c.uv_index,
            desc = desc, cat = cat, is_day = (c.is_day == 1),
            t_max = dl.temperature_2m_max and dl.temperature_2m_max[1],
            t_min = dl.temperature_2m_min and dl.temperature_2m_min[1],
            sunrise = dl.sunrise and dl.sunrise[1],
            sunset = dl.sunset and dl.sunset[1],
            hourly = hourly, source = "Open-Meteo",
        }
    end, "wx_now")
end

function fetch_metno(lat, lon, cityName)
    state.load_at = os.clock()
    local url = ("https://api.met.no/weatherapi/locationforecast/2.0/compact?lat=%s&lon=%s")
        :format(numstr(lat), numstr(lon))
    dbg.stats.req = dbg.stats.req + 1
    dbg.log("REQ", ("MET.no %s,%s"):format(numstr(lat), numstr(lon)))
    HTTP.Request("GET", url, HDR_METNO, function(resp)
        local body = resp and resp["response"]
        local ok, d = pcall(function() return JSON:decode(body) end)
        local ts = ok and d and d.properties and d.properties.timeseries
        if type(ts) ~= "table" or not ts[1] then
            dbg.log("WARN", "MET.no без данных (" .. dbg_resp(resp) .. ") → 7Timer")
            fetch_7timer(lat, lon, cityName); return
        end
        local function sym_of(node)
            local da = node and node.data
            local n1 = da and da.next_1_hours and da.next_1_hours.summary
            local n6 = da and da.next_6_hours and da.next_6_hours.summary
            return (n1 and n1.symbol_code) or (n6 and n6.symbol_code) or ""
        end
        local cur = (ts[1].data and ts[1].data.instant and ts[1].data.instant.details) or {}
        local sym = sym_of(ts[1])
        local desc, cat = decode_metno(sym)
        local is_day = not tostring(sym):find("_night", 1, true)
        local n1d = ts[1].data and ts[1].data.next_1_hours and ts[1].data.next_1_hours.details
        local pop = (n1d and n1d.probability_of_precipitation) or 0

        local hourly, tmax, tmin = {}, nil, nil
        for i = 1, math.min(#ts, 24) do
            local det = ts[i].data and ts[i].data.instant and ts[i].data.instant.details
            local tv = det and det.air_temperature
            if tv then
                tmax = math.max(tmax or tv, tv)
                tmin = math.min(tmin or tv, tv)
            end
            if i <= 6 then
                local _, hc = decode_metno(sym_of(ts[i]))
                hourly[#hourly + 1] = { h = hour_of(ts[i].time), temp = tv, cat = hc, pop = 0 }
            end
        end

        apply{
            city = cityName, temp = cur.air_temperature, feels = cur.air_temperature,
            humidity = cur.relative_humidity, precip = pop,
            wind = cur.wind_speed, wind_dir = cur.wind_from_direction,
            pressure = cur.air_pressure_at_sea_level, uv = cur.ultraviolet_index_clear_sky,
            desc = desc, cat = cat, is_day = is_day,
            t_max = tmax, t_min = tmin, sunrise = nil, sunset = nil,
            hourly = hourly, source = "MET.no",
        }
    end, "wx_metno")
end

function fetch_wttr(query, cityName)
    state.load_at = os.clock()
    local url = ("https://wttr.in/%s?format=j1&lang=ru"):format(urlencode(tostring(query or "")))
    dbg.stats.req = dbg.stats.req + 1
    dbg.log("REQ", "wttr.in " .. tostring(query))
    HTTP.Request("GET", url, HDR, function(resp)
        local body = resp and resp["response"]
        local ok, d = pcall(function() return JSON:decode(body) end)
        local cc = ok and d and d.current_condition and d.current_condition[1]
        if not cc then
            dbg.stats.err = dbg.stats.err + 1
            dbg.log("ERR", "wttr.in без данных (" .. dbg_resp(resp) .. "). Все источники не ответили!")
            dbg.log("ERR", "Тело: " .. dbg_snip(resp))
            state.loading, state.error = false, "Ошибка данных"; return
        end

        local wname = cityName
        if (not wname or wname == "") and d.nearest_area and d.nearest_area[1]
            and d.nearest_area[1].areaName and d.nearest_area[1].areaName[1] then
            wname = d.nearest_area[1].areaName[1].value
        end
        local cat = wttr_cat(cc.weatherCode)
        local desc = (cc.lang_ru and cc.lang_ru[1] and cc.lang_ru[1].value)
            or (cc.weatherDesc and cc.weatherDesc[1] and cc.weatherDesc[1].value) or "—"

        local w0 = (d.weather and d.weather[1]) or {}
        local astro = (w0.astronomy and w0.astronomy[1]) or {}
        local sr, ss = ampm_to_iso(astro.sunrise), ampm_to_iso(astro.sunset)
        local is_day = true
        if sr and ss then
            local nm = (tonumber(os.date("%H")) or 0) * 60 + (tonumber(os.date("%M")) or 0)
            local a, b = iso_min(sr), iso_min(ss)
            if a and b and b > a then is_day = (nm >= a and nm < b) end
        end

        local nowh = tonumber(os.date("%H")) or 0
        local hourly = {}
        local function add_hours(wd, today)
            if not (wd and wd.hourly) then return end
            for _, hx in ipairs(wd.hourly) do
                local hr = math.floor((tonumber(hx.time) or 0) / 100)
                if #hourly < 6 and ((not today) or hr >= nowh) then
                    hourly[#hourly + 1] = {
                        h = hr, temp = tonumber(hx.tempC),
                        cat = wttr_cat(hx.weatherCode),
                        pop = tonumber(hx.chanceofrain) or 0,
                    }
                end
            end
        end
        add_hours(w0, true)
        add_hours(d.weather and d.weather[2], false)

        apply{
            city = wname, temp = tonumber(cc.temp_C), feels = tonumber(cc.FeelsLikeC),
            humidity = tonumber(cc.humidity), precip = (hourly[1] and hourly[1].pop) or 0,
            wind = (tonumber(cc.windspeedKmph) or 0) / 3.6, wind_dir = tonumber(cc.winddirDegree),
            pressure = tonumber(cc.pressure), uv = tonumber(cc.uvIndex),
            desc = desc, cat = cat, is_day = is_day,
            t_max = tonumber(w0.maxtempC), t_min = tonumber(w0.mintempC),
            sunrise = sr, sunset = ss,
            hourly = hourly, source = "wttr.in",
        }
    end, "wx_wttr")
end




function fetch_7timer(lat, lon, cityName)
    state.load_at = os.clock()
    local url = ("https://www.7timer.info/bin/api.pl?lon=%s&lat=%s&product=civil&output=json")
        :format(numstr(lon), numstr(lat))
    dbg.stats.req = dbg.stats.req + 1
    dbg.log("REQ", ("7Timer %s,%s"):format(numstr(lat), numstr(lon)))
    HTTP.Request("GET", url, HDR, function(resp)
        local body = resp and resp["response"]
        local ok, d = pcall(function() return JSON:decode(body) end)
        local ds = ok and d and d.dataseries
        if type(ds) ~= "table" or not ds[1] then
            dbg.log("WARN", "7Timer без данных (" .. dbg_resp(resp) .. ") → wttr.in")
            fetch_wttr(numstr(lat) .. "," .. numstr(lon), cityName); return
        end
        local init_h = tonumber(tostring(d.init or ""):sub(9, 10)) or 0
        local cur = ds[1]
        local desc, cat = decode_7timer(cur.weather)
        local is_day = not tostring(cur.weather or ""):find("night", 1, true)
        local function rh(v) return tonumber((tostring(v or ""):gsub("%%", ""))) end
        local function wspd(w) return (w and SEV_WIND[tonumber(w.speed) or 0]) or nil end
        local hourly, tmax, tmin = {}, nil, nil
        for i = 1, math.min(#ds, 16) do
            local tv = tonumber(ds[i].temp2m)
            if tv then tmax = math.max(tmax or tv, tv); tmin = math.min(tmin or tv, tv) end
            if i <= 6 then
                local _, hc = decode_7timer(ds[i].weather)
                local hh = (init_h + (tonumber(ds[i].timepoint) or 0)) % 24
                hourly[#hourly + 1] = { h = hh, temp = tv, cat = hc, pop = 0 }
            end
        end
        apply{
            city = cityName, temp = tonumber(cur.temp2m), feels = tonumber(cur.temp2m),
            humidity = rh(cur.rh2m), precip = 0,
            wind = wspd(cur.wind10m),
            wind_dir = (cur.wind10m and SEV_DIR[tostring(cur.wind10m.direction)]) or nil,
            pressure = nil, uv = nil,
            desc = desc, cat = cat, is_day = is_day,
            t_max = tmax, t_min = tmin, sunrise = nil, sunset = nil,
            hourly = hourly, source = "7Timer",
        }
    end, "wx_7timer")
end

local function fetch_by_city(city)
    if not city or city == "" then city = "Киев" end
    local geo = ("https://geocoding-api.open-meteo.com/v1/search?name=%s&count=1&language=ru&format=json")
        :format(urlencode(city))
    dbg.log("REQ", "Геокодер Open-Meteo: " .. tostring(city))
    HTTP.Request("GET", geo, HDR, function(resp)
        local ok, g = pcall(function() return JSON:decode(resp["response"]) end)
        if not ok or not g or not g.results or not g.results[1] then
            dbg.log("WARN", "Геокодер не нашёл город (" .. dbg_resp(resp) .. ") → wttr.in по имени")
            fetch_wttr(city, city); return
        end
        local r = g.results[1]
        dbg.log("INFO", ("Геокодер: %s → %s,%s"):format(tostring(r.name or city), numstr(r.latitude), numstr(r.longitude)))
        fetch_openmeteo(r.latitude, r.longitude, r.name or city)
    end, "wx_geo")
end

local IP_PROVIDERS = {
    { url = "https://ipwho.is/",              lat = "latitude", lon = "longitude", city = "city" },
    { url = "https://ipapi.co/json/",         lat = "latitude", lon = "longitude", city = "city" },
    { url = "https://freeipapi.com/api/json", lat = "latitude", lon = "longitude", city = "cityName" },
}
local function fetch_by_ip(idx)
    idx = idx or 1
    local p = IP_PROVIDERS[idx]
    if not p then
        dbg.log("WARN", "IP-геоло��ация не удалась → определяем город по имени")
        fetch_by_city(ui.city:Get()); return
    end
    dbg.stats.req = dbg.stats.req + 1
    dbg.log("REQ", "IP-геолокация: " .. p.url)
    HTTP.Request("GET", p.url, HDR, function(resp)
        local ok, g = pcall(function() return JSON:decode(resp["response"]) end)
        local lat = ok and g and g[p.lat] or nil
        local lon = ok and g and g[p.lon] or nil
        if lat and lon then
            dbg.log("INFO", ("IP → %s (%s,%s)"):format(tostring(g[p.city] or "?"), numstr(lat), numstr(lon)))
            fetch_openmeteo(lat, lon, (g[p.city]) or "Моё местоположение")
        else
            dbg.log("WARN", ("IP-провайдер не ответил: %s (%s)"):format(p.url, dbg_resp(resp)))
            fetch_by_ip(idx + 1)
        end
    end, "wx_ip")
end

local function pull_weather()
    if state.loading then return end
    state.loading, state.error = true, nil
    state.load_at = os.clock()
    if ui.autocity:Get() then
        dbg.log("REQ", "Старт обновления: автоопределение города по IP")
        fetch_by_ip(1)
    else
        dbg.log("REQ", "Старт обновления: город = " .. tostring(ui.city:Get()))
        fetch_by_city(ui.city:Get())
    end
end

local ALARM_SOURCES = {

    ua = { "https://ubilling.net.ua/aerialalerts/" },
}

local TG_ALARM_URL = "https://t.me/s/kupolrussia"

local function alarm_providers_for(target)
    if target and target.src == "ru" then
        if not (ui.alarm_ru_src and cget(ui.alarm_ru_src) == 1) then
            return { { url = TG_ALARM_URL, kind = "telegram" } }
        end
        local url = (ui.alarm_ru_url and ui.alarm_ru_url:Get()) or ""
        url = url:gsub("^%s+", ""):gsub("%s+$", "")
        if url == "" then return {} end
        return { { url = url, kind = "json" } }
    end
    return { { url = ALARM_SOURCES.ua[1], kind = "json" } }
end

local alarm = {
    active = false, since = nil, region_name = nil,
    cleared_at = nil, cleared_region = nil,
    loading = false, checking = false, error = nil, last_pull = -1e18, last_ok = nil, load_at = nil,
    flash_t = 0, flash_at = nil, flash_manual = false, manual_req = false,
    cur = nil, cur_kind = nil, cur_cause = nil, cur_region = nil, cur_since = nil,
    notif_at = nil, notif_kind = nil, notif_region = nil, notif_cause = nil, last_kind = nil, last_sig = nil,
}

local function alarm_norm(s)
    s = tostring(s or "")
    s = s:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
    return s
end

local function alarm_match_city(city)
    local raw = alarm_norm(city)
    if raw == "" then return nil end
    local low = raw:lower()
    for _, r in ipairs(ALARM_REGIONS) do
        if r.aliases then
            for _, a in ipairs(r.aliases) do
                if raw:find(a, 1, true) or low:find(a, 1, true) then return r end
            end
        end
    end
    return nil
end

local function alarm_target()
    if ui.alarm_auto:Get() and state.loaded then
        local r = alarm_match_city(state.city)
        if r then return r end
    end
    local idx = cget(ui.alarm_region) + 1
    return ALARM_REGIONS[idx] or ALARM_REGIONS[1]
end

local NOTIF_DUR = 5.0
local NOTIF_STYLE = {
    bpla   = { title = "Угроза БПЛА",        en = "UAV threat",     col = { 245, 178, 64 }, icon = "warn" },
    rocket = { title = "Ракетная опасность", en = "Missile threat", col = { 235, 72, 72 },  icon = "rocket" },
    kab    = { title = "Авиабомбы (КАБ)",    en = "Guided bomb",   col = { 235, 110, 60 }, icon = "rocket" },
    arty   = { title = "Обстрел",            en = "Shelling",      col = { 230, 90, 90 },  icon = "warn" },
    threat = { title = "Опасность",          en = "Threat",        col = { 245, 146, 64 }, icon = "warn" },
    clear  = { title = "Отбой",              en = "All clear",     col = { 60, 200, 120 }, icon = "check" },
}

local function alarm_apply(kind, region, sig, cause)
    if kind == nil then return end
    sig = sig or kind

    if kind ~= alarm.cur then alarm.cur_since = os.clock() end
    alarm.cur = kind
    alarm.cur_kind = kind
    alarm.cur_region = region
    alarm.cur_cause = cause

    if sig ~= alarm.last_sig then
        local pop = true
        if kind == "clear" and (alarm.last_kind == nil or alarm.last_kind == "clear") then
            pop = false
        end
        if pop then
            alarm.notif_at = os.clock()
            alarm.notif_kind = kind
            alarm.notif_region = region
            alarm.notif_cause = cause
        end
        alarm.last_kind = kind
        alarm.last_sig = sig
    end
end

local function alarm_mark_checked()
    alarm.flash_at = os.clock()
    alarm.flash_manual = alarm.manual_req == true
    alarm.manual_req = false
end

local function truthy(v)
    if v == true then return true end
    if type(v) == "number" then return v ~= 0 end
    if type(v) == "string" then
        local s = v:lower()
        return s == "true" or s == "1" or s == "yes" or s == "on"
            or s == "active" or s == "alert" or s == "danger" or s == "y"
    end
    return false
end

local function alarm_is_on(info)
    if type(info) == "boolean" or type(info) == "number" or type(info) == "string" then
        return truthy(info)
    end
    if type(info) == "table" then
        return truthy(info.enabled) or truthy(info.alert) or truthy(info.alertnow)
            or truthy(info.alarm) or truthy(info.active) or truthy(info.status)
            or truthy(info.value) or truthy(info.state) or truthy(info.danger)
    end
    return false
end

local function alarm_entry_name(key, info)
    if type(key) == "string" then return key end
    if type(info) == "table" then
        return info.region or info.name or info.title or info.location
            or info.oblast or info.area or info.regionName or info.region_name
    end
    return nil
end

local function region_matches(target, name)
    local nn = alarm_norm(name)
    if nn == "" then return false end
    local low = nn:lower()
    if target.ua and target.ua ~= "" and nn == alarm_norm(target.ua) then return true end
    if target.match and target.match ~= "" then
        if nn:find(target.match, 1, true) or low:find(target.match:lower(), 1, true) then
            return true
        end
    end
    return false
end

local KW_ROCKET = { "ракет", "крылат", "баллист", "кинжал", "искандер", "калибр", "циркон", "оникс", "гиперзв", "точка-у", "х-101", "х-555", "х-59", "х-22", "х-69", "х-32", "х-35", "х-31", "х-47", "миг-31", "ту-95", "ту-160", "ту-22", "пуск ракет", "пуск", "подлет", "подлёт", "с-300", "с-400", "аэробалл", "квазибалл", "ракетоопасн", "missile", "iskander", "kalibr", "kinzhal", "стратегическ", "взлет ту", "взлёт ту", "взлет миг", "взлёт миг", "взлет борт", "взлёт борт" }
local KW_BPLA   = { "бпла", "дрон", "беспилот", "шахед", "шахид", "геран", "гербер", "ланцет", "мопед", "fpv", "mavic", "орлан", "квадрокоптер", "октокоптер", "uav", "разведдрон", "geran", "shahed", "shahid", "бвс", "ударный бпла", "ударные бпла", "рой дрон", "рой бпла", "группа бпла", "группа дрон", "стая дрон", "камикадзе", "взлет бпла", "взлёт бпла" }
local ALARM_THREAT_KW = { "воздушная тревога", "воздушной тревоги", "воздушную тревогу", "объявлена тревога", "объявлена воздушная", "сигнал тревоги", "режим воздушной", "угроза атаки", "угроза удара", "угроза ракетного удара", "угроза применения", "опасность атаки", "опасность удара", "массированная атака", "массированный удар", "комбинированная атака", "пройдите в укрыти", "проследуйте в укрыти", "будьте в укрыти" }
local KW_KAB    = { "авиабомб", "умпк", "умпб", "корректируем бомб", "управляем бомб", "планирующ бомб", "сброс б��мб", "применение каб", "каб-", "фаб-", "каб ", "фаб " }
local KW_ARTY   = { "обстрел", "артиллер", "артудар", "артобстрел", "рсзо", "миномет", "миномет��", "снаряд", "гаубиц", "птур", "танковый обстрел", "ствольн" }
local ALARM_CLEAR_KW  = { "отбой", "отмен", "минова", "снят", "чисто", "спокойно", "нет угроз", "угроз нет", "угрозы нет", "опасности нет", "можно выход", "без угроз", "оконч", "заверш", "конец трев", "можно покинуть", "отбой трев", "тревога окончен", "тревоги нет", "угроза минов", "опасность минов", "угроза устранен", "опасность устранен", "всё чисто", "все чисто", "можно вернут" }

local NATIONWIDE = { "по всей россии", "на всей территории", "вся россия", "по всей стране", "по всей рф", "по всей территории рф", "повсеместно", "во всех регион" }

local function cyr_lower(s)
    s = tostring(s or ""):lower()
    s = s:gsub("\208([\144-\159])", function(c) return "\208" .. string.char(c:byte() + 32) end)
    s = s:gsub("\208([\160-\175])", function(c) return "\209" .. string.char(c:byte() - 32) end)
    s = s:gsub("\208\129", "\209\145")
    return s
end

local function html_to_text(s)
    s = tostring(s or "")
    s = s:gsub("<br%s*/?>", " ")
    s = s:gsub("<[^>]->", " ")
    s = s:gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&quot;", "\"")
    s = s:gsub("&#39;", "'"):gsub("&#x27;", "'"):gsub("&nbsp;", " "):gsub("&amp;", "&")
    s = s:gsub("%s+", " ")
    return s
end

local function is_word_byte(b)
    if (b >= 48 and b <= 57) or (b >= 65 and b <= 90) or (b >= 97 and b <= 122) then return true end
    if b >= 128 then return true end
    return false
end
local function word_at(low, k)
    local from = 1
    while true do
        local a = low:find(k, from, true)
        if not a then return false end
        local prev = a > 1 and low:byte(a - 1) or nil
        if not (prev and is_word_byte(prev)) then return true end
        from = a + 1
    end
end
local function has_keyword(low, list)
    for _, k in ipairs(list) do
        if low:find(k, 1, true) then return true end
    end
    return false
end
local function has_word(low, list)
    for _, k in ipairs(list) do
        if word_at(low, k) then return true end
    end
    return false
end

local function region_in_text(target, low)
    for _, n in ipairs(NATIONWIDE) do
        if low:find(n, 1, true) then return true end
    end
    local m = cyr_lower(target.match or "")
    if m ~= "" and word_at(low, m) then return true end
    if target.aliases then
        for _, a in ipairs(target.aliases) do
            local la = cyr_lower(a)
            if la ~= "" and word_at(low, la) then return true end
        end
    end
    return false
end

local EMO_ROCKET = { "🚀" }
local EMO_BPLA   = { "✈", "🛩", "🛸", "🚁" }
local EMO_CLEAR  = { "🟢", "✅" }

local function tg_classify(low)
    if has_keyword(low, EMO_CLEAR) or has_word(low, ALARM_CLEAR_KW) then return "clear" end
    if has_keyword(low, EMO_ROCKET) or has_word(low, KW_ROCKET) then return "rocket" end
    if has_word(low, KW_KAB) then return "kab" end
    if has_keyword(low, EMO_BPLA) or has_word(low, KW_BPLA) then return "bpla" end
    if has_word(low, KW_ARTY) then return "arty" end
    if has_word(low, ALARM_THREAT_KW) then return "threat" end
    return nil
end

local CAUSES = {
    { "взлет ту", "��злёт стратегической авиации" },
    { "взлёт ту", "Взлёт стратегической авиации" },
    { "стратегическ", "Стратегическая авиация" },
    { "взлет миг", "Взлёт МиГ-31" },
    { "взлёт миг", "Взлёт МиГ-31" },
    { "миг-31", "Взлёт МиГ-31" },
    { "кинжал", "Гиперзвук «Кинжал»" },
    { "kinzhal", "Гиперзвук «Кинжал»" },
    { "циркон", "Гиперзвук «Циркон»" },
    { "аэробалл", "Аэробаллистика" },
    { "квазибалл", "Квазибаллистика" },
    { "баллист", "Баллистическая ракета" },
    { "искандер", "ОТРК «Искандер»" },
    { "iskander", "ОТРК «Искандер»" },
    { "калибр", "Крылатые «Калибр»" },
    { "kalibr", "Крылатые «Калибр»" },
    { "крылат", "Крылатые ракеты" },
    { "пуск ракет", "Пуск ракет" },
    { "пуск", "Пуск ракет" },
    { "подлет", "Подлёт ракет" },
    { "подлёт", "Подлёт ракет" },
    { "ракет", "Ракетная угроза" },
    { "применение каб", "Применение КАБ" },
    { "умпк", "Авиабомба с УМПК" },
    { "умпб", "Авиабомба УМПБ" },
    { "авиабомб", "Управляемая авиабомба" },
    { "каб-", "КАБ" },
    { "каб ", "КАБ" },
    { "фаб-", "ФАБ" },
    { "фаб ", "ФАБ" },
    { "рой дрон", "Рой дронов" },
    { "рой бпла", "Рой дронов" },
    { "группа бпла", "Группа БПЛА" },
    { "группа дрон", "Группа дронов" },
    { "стая дрон", "Стая дронов" },
    { "взлет бпла", "Взлёт БПЛА" },
    { "взлёт бпла", "Взлёт БПЛА" },
    { "шахед", "БПЛА «Шахед»" },
    { "shahed", "БПЛА «Шахед»" },
    { "шахид", "БПЛА «Шахед»" },
    { "геран", "БПЛА «Герань»" },
    { "geran", "БПЛА «Герань»" },
    { "ланцет", "БПЛА «Ланцет»" },
    { "гербер", "БПЛА «Гербера»" },
    { "разведдрон", "Разведдрон" },
    { "камикадзе", "БПЛА-камикадзе" },
    { "fpv", "FPV-дрон" },
    { "квадрокоптер", "Квадрокоптер" },
    { "октокоптер", "Октокоптер" },
    { "беспилот", "Беспилотник" },
    { "дрон", "Беспилотник" },
    { "бпла", "Беспилотник" },
    { "артобстрел", "Артобстрел" },
    { "артиллер", "Артиллерия" },
    { "рсзо", "РСЗО" },
    { "гаубиц", "Гаубичный обстрел" },
    { "миномет", "Миномётный обстрел" },
    { "обстрел", "Обстрел" },
    { "снаряд", "Артиллерия" },
    { "массированн", "Массированный удар" },
    { "комбинированн", "Комбинированный удар" },
    { "угроза удара", "Угроза удара" },
    { "угроза атаки", "Угроза атаки" },
    { "воздушная тревога", "Воздушная тревога" },
    { "воздушной тревоги", "Воздушная тревога" },
    { "сигнал тревоги", "Сигнал тревоги" },
    { "объявлена тревога", "Объявлена тревога" },
    { "укрыти", "Пройдите в укрытие" },
}
local function cause_label(low)
    for _, c in ipairs(CAUSES) do
        if word_at(low, c[1]) then return c[2] end
    end
    return nil
end

local CAUSE_FALLBACK = {
    rocket = "Ракетная угроза",
    bpla = "Замечены БПЛА",
    kab = "Применение КАБ",
    arty = "Артиллерийский обстрел",
    threat = "Воздушная тревога",
}

local function tg_parse(html, target)
    if type(html) ~= "string" then return nil, nil, nil end
    local kind, sig, cause = nil, nil, nil
    local seen = 0
    for raw in html:gmatch("tgme_widget_message_text[^>]->(.-)</div>") do
        seen = seen + 1
        local low = cyr_lower(html_to_text(raw))
        if low ~= "" and region_in_text(target, low) then
            local k = tg_classify(low)
            if k ~= nil then
                kind, sig = k, low
                cause = (k ~= "clear") and cause_label(low) or nil
            end
        end
    end
    if seen == 0 then
        local low = cyr_lower(html_to_text(html))
        if low ~= "" and region_in_text(target, low) then
            local k = tg_classify(low)
            if k ~= nil then
                kind = k
                sig = "full:" .. k
                cause = (k ~= "clear") and cause_label(low) or nil
            end
        end
    end
    return kind, sig, cause
end

local function fetch_alarms(idx)
    idx = idx or 1
    local target = alarm_target()
    local providers = alarm_providers_for(target)
    local prov = providers[idx]
    if not prov then
        alarm.loading = false
        alarm.checking = false
        if target.src == "ru" and #providers == 0 then
            alarm.error = "Укажите URL источника РФ"
        elseif not alarm.last_ok then
            alarm.error = "Нет данных"
        end
        return
    end
    local hdr = (prov.kind == "telegram") and HDR_HTML or HDR
    HTTP.Request("GET", prov.url, hdr, function(resp)
        alarm.loading = false
        alarm.checking = false
        local body = resp and resp["response"]
        if prov.kind == "telegram" then
            if type(body) ~= "string" or body == "" then
                if providers[idx + 1] then
                    alarm.loading = true
                    alarm.load_at = os.clock()
                    fetch_alarms(idx + 1)
                elseif not alarm.last_ok then
                    alarm.error = "Канал недоступен"
                end
                return
            end
            if #body > 140000 then body = body:sub(#body - 140000) end
            local ok, kind, sig, cause = pcall(tg_parse, body, target)
            if ok then
                alarm_apply(kind or "clear", target.ru, sig or "tg:clear", cause)
            else
                alarm_apply("clear", target.ru, "tg:err")
            end
            alarm.error = nil
            alarm.last_ok = os.clock()
            alarm_mark_checked()
            return
        end
        local ok, d = pcall(function() return JSON:decode(body) end)
        if not ok or type(d) ~= "table" then
            if providers[idx + 1] then
                alarm.loading = true
                alarm.load_at = os.clock()
                fetch_alarms(idx + 1)
            else
                alarm.error = "Ошибка тревоги"
            end
            return
        end
        local states = d.states or d.alerts or d.regions or d.data or d
        local on = false
        if type(states) == "table" then
            for key, info in pairs(states) do
                if alarm_is_on(info) then
                    local name = alarm_entry_name(key, info)
                    if name and region_matches(target, name) then
                        on = true
                        break
                    end
                end
            end
        end
        alarm_apply(on and "threat" or "clear", target.ru, "json:" .. (on and "on" or "off"))
        alarm.error = nil
        alarm.last_ok = os.clock()
        alarm_mark_checked()
    end, "wx_alarm")
end

function widget.check_alarm()
    alarm.manual_req = true
    if alarm.loading then
        alarm.checking = true
        return
    end
    alarm.last_pull = os.clock()
    alarm.load_at = os.clock()
    alarm.loading, alarm.checking, alarm.error = true, true, nil
    pcall(fetch_alarms, 1)
end

function widget.reset_style()
    pcall(function()
        ui.theme:Set(0); ui.font:Set(0); ui.scale:Set(1.0); ui.textsize:Set(100)
        ui.opacity:Set(238); ui.animations:Set(true); ui.shadow:Set(true)
        ui.accent:Set(Color(94, 152, 247))
    end)
end

function widget.force_refresh()
    state.last_pull, state.loaded = os.clock(), false
    pull_weather()
end

local function mood_color(cat, is_day)
    if cat == "clear"  then return is_day and Color(255, 196, 72) or Color(120, 150, 235) end
    if cat == "partly" then return is_day and Color(245, 180, 90) or Color(130, 150, 220) end
    if cat == "rain"   then return Color(96, 160, 235) end
    if cat == "snow"   then return Color(170, 205, 245) end
    if cat == "storm"  then return Color(150, 130, 240) end
    if cat == "fog"    then return Color(150, 165, 185) end
    return Color(140, 165, 200)
end
local function accent_color()
    if ui.auto_accent:Get() and state.loaded then return mood_color(state.cat, state.is_day) end
    return ui.accent:Get()
end
local function tint(c, a, t)
    return Color(math.floor(c.r + (a.r - c.r) * t),
                math.floor(c.g + (a.g - c.g) * t),
                math.floor(c.b + (a.b - c.b) * t), c.a or 255)
end
local function alpha(c, a) return Color(c.r, c.g, c.b, a) end

local function tri_fill(x1, y1, x2, y2, x3, y3, color)
    local ymin = math.floor(math.min(y1, y2, y3))
    local ymax = math.ceil(math.max(y1, y2, y3))
    local edges = { { x1, y1, x2, y2 }, { x2, y2, x3, y3 }, { x3, y3, x1, y1 } }
    for yy = ymin, ymax do
        local lo, hi
        for _, e in ipairs(edges) do
            local ay, by = e[2], e[4]
            if ay ~= by then
                local t = (yy - ay) / (by - ay)
                if t >= 0 and t <= 1 then
                    local xx = e[1] + (e[3] - e[1]) * t
                    if not lo or xx < lo then lo = xx end
                    if not hi or xx > hi then hi = xx end
                end
            end
        end
        if lo and hi then Render.FilledRect(Vec2(lo, yy), Vec2(hi, yy + 1.0), color) end
    end
end
local function caret(cx, cy, r, up, color, th)
    if up then
        Render.Line(Vec2(cx - r, cy + r * 0.6), Vec2(cx, cy - r * 0.6), color, th)
        Render.Line(Vec2(cx, cy - r * 0.6), Vec2(cx + r, cy + r * 0.6), color, th)
    else
        Render.Line(Vec2(cx - r, cy - r * 0.6), Vec2(cx, cy + r * 0.6), color, th)
        Render.Line(Vec2(cx, cy + r * 0.6), Vec2(cx + r, cy - r * 0.6), color, th)
    end
end
local function corner_brackets(x, y, w, h, l, color, th)
    Render.Line(Vec2(x, y), Vec2(x + l, y), color, th);         Render.Line(Vec2(x, y), Vec2(x, y + l), color, th)
    Render.Line(Vec2(x + w, y), Vec2(x + w - l, y), color, th); Render.Line(Vec2(x + w, y), Vec2(x + w, y + l), color, th)
    Render.Line(Vec2(x, y + h), Vec2(x + l, y + h), color, th); Render.Line(Vec2(x, y + h), Vec2(x, y + h - l), color, th)
    Render.Line(Vec2(x + w, y + h), Vec2(x + w - l, y + h), color, th); Render.Line(Vec2(x + w, y + h), Vec2(x + w, y + h - l), color, th)
end
local function draw_vgrad(x, y, w, hh, color, a_top, a_bot, steps)
    steps = steps or 14
    local sh = hh / steps
    for i = 0, steps - 1 do
        local t = i / (steps - 1)
        local a = math.floor(a_top + (a_bot - a_top) * t)
        if a > 0 then Render.FilledRect(Vec2(x, y + i * sh), Vec2(x + w, y + (i + 1) * sh), alpha(color, a)) end
    end
end

local function draw_cloud(cx, cy, s, color)
    color = color or col_cloud
    Render.FilledCircle(Vec2(cx - 0.9 * s, cy + 0.15 * s), 0.6 * s, color)
    Render.FilledCircle(Vec2(cx,            cy - 0.15 * s), 0.78 * s, color)
    Render.FilledCircle(Vec2(cx + 0.95 * s, cy + 0.15 * s), 0.6 * s, color)
    Render.FilledRect(Vec2(cx - 1.4 * s, cy + 0.15 * s), Vec2(cx + 1.4 * s, cy + 0.78 * s), color, 0.4 * s)
end
local function draw_sun(cx, cy, r, phase)
    phase = phase or 0
    for i = 0, 7 do
        local a = math.rad(i * 45) + phase
        Render.Line(Vec2(cx + math.cos(a) * (r + 2), cy + math.sin(a) * (r + 2)),
                    Vec2(cx + math.cos(a) * (r + 7), cy + math.sin(a) * (r + 7)), col_sun, 2.0)
    end
    Render.FilledCircle(Vec2(cx, cy), r, col_sun)
end
local function draw_moon(cx, cy, r, bg)
    Render.FilledCircle(Vec2(cx, cy), r, col_moon)
    Render.FilledCircle(Vec2(cx + r * 0.55, cy - r * 0.35), r * 0.92, bg)
end
local function draw_icon(cat, cx, cy, s, is_day, bg, phase)
    if cat == "clear" then
        if is_day then draw_sun(cx, cy, 12 * s, phase) else draw_moon(cx, cy, 12 * s, bg) end
    elseif cat == "partly" then
        if is_day then draw_sun(cx - 8 * s, cy - 7 * s, 9 * s, phase) else draw_moon(cx - 8 * s, cy - 7 * s, 9 * s, bg) end
        draw_cloud(cx + 5 * s, cy + 5 * s, 10 * s)
    elseif cat == "cloud" or cat == "fog" then
        draw_cloud(cx, cy, 12 * s)
    elseif cat == "rain" then
        draw_cloud(cx, cy - 3 * s, 11 * s)
        for i = 0, 2 do local dx = cx - 11 * s + i * 11 * s
            Render.Line(Vec2(dx, cy + 12 * s), Vec2(dx - 3 * s, cy + 21 * s), col_rain, 2.0) end
    elseif cat == "snow" then
        draw_cloud(cx, cy - 3 * s, 11 * s)
        for i = 0, 2 do Render.FilledCircle(Vec2(cx - 11 * s + i * 11 * s, cy + 16 * s), 2.0 * s, col_snow) end
    elseif cat == "storm" then
        draw_cloud(cx, cy - 3 * s, 11 * s)
        Render.PolyLine({ Vec2(cx + 2 * s, cy + 8 * s), Vec2(cx - 5 * s, cy + 18 * s),
                          Vec2(cx + 1 * s, cy + 18 * s), Vec2(cx - 4 * s, cy + 28 * s) }, col_sun, 2.0)
    end
end

local function draw_sun_h(cx, cy, s, rising)
    local r = 3.0 * s
    local hy = cy + 4 * s
    for i = 0, 6 do
        local a = math.rad(180 + i * 30)
        local ox, oy = math.cos(a), math.sin(a)
        Render.Line(Vec2(cx + ox * (r + 1.5 * s), cy + oy * (r + 1.5 * s)),
                    Vec2(cx + ox * (r + 4.5 * s), cy + oy * (r + 4.5 * s)), alpha(col_sun, 200), 1.3)
    end
    Render.FilledCircle(Vec2(cx, cy), r, col_sun)
    Render.Line(Vec2(cx - 8 * s, hy), Vec2(cx + 8 * s, hy), col_dim, 1.4)
    caret(cx, hy + 4 * s, 2.4 * s, rising, rising and col_hi or col_lo, 1.6)
end

local function glow_text(font, size, str, pos, color, glow_col, intensity)
    local gc = glow_col or color
    local a = math.floor(math.max(0, math.min(80, intensity or 22)))
    local off = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 }, { -1.4, -1.4 }, { 1.4, 1.4 }, { 1.4, -1.4 }, { -1.4, 1.4 } }
    for _, o in ipairs(off) do
        Render.Text(font, size, str, Vec2(pos.x + o[1], pos.y + o[2]), Color(gc.r, gc.g, gc.b, a))
    end
    Render.Text(font, size, str, pos, color)
end

local function soft_text(font, size, str, pos, color)
    local h = Color(255, 255, 255, 34)
    local off = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 }, { -1, -1 }, { 1, 1 }, { 1, -1 }, { -1, 1 } }
    for _, o in ipairs(off) do
        Render.Text(font, size, str, Vec2(pos.x + o[1], pos.y + o[2]), h)
    end
    Render.Text(font, size, str, pos, color)
end

local function draw_clock(x, y, w, s, st, align)
    local t = os.date("*t")
    local str = WEEKDAYS[t.wday] .. (ui.clock_secs:Get() and ("  %02d:%02d:%02d"):format(t.hour, t.min, t.sec) or ("  %02d:%02d"):format(t.hour, t.min))
    local sz = Render.TextSize(font_text, math.floor(12 * s * g_ts), str)
    local tx = x
    if align == "right" then tx = x + w - sz.x
    elseif align == "center" then tx = x + (w - sz.x) * 0.5 end
    soft_text(font_text, math.floor(12 * s * g_ts), str, Vec2(tx, y), st.dim)
end

local function card_height(mode)
    local th = cget(ui.theme)
    if th == 1 then return (mode == 0 and 92) or (mode == 2 and 236) or 140 end
    if th == 2 then return (mode == 0 and 96) or (mode == 2 and 250) or 160 end
    if th == 3 then return (mode == 0 and 90) or (mode == 2 and 234) or 144 end
    if th == 4 then return (mode == 0 and 116) or (mode == 2 and 256) or 176 end
    if th == 5 then return (mode == 0 and 150) or (mode == 2 and 312) or 234 end
    if th == 6 then return (mode == 0 and 120) or (mode == 2 and 286) or 200 end
    if th == 7 then return (mode == 0 and 100) or (mode == 2 and 276) or 188 end
    if th == 8 then return (mode == 0 and 122) or (mode == 2 and 272) or 184 end
    return (mode == 0 and 86) or (mode == 2 and 214) or 130
end
local function get_rect()
    local s = ui.scale:Get()
    local mode = cget(ui.layout)
    return ui.pos_x:Get(), ui.pos_y:Get(), math.floor(360 * s), math.floor(card_height(mode) * s), s, mode
end
local function screen_size()
    local ok, v = pcall(function() return Render.ScreenSize() end)
    if ok and v and v.x then return v.x, v.y end
    return 1920, 1080
end

local function get_style(accent)
    local th = cget(ui.theme)
    local op = ui.opacity:Get()
    if th == 1 then
        return {
            key = "imgui", round = 0, glass = false, shadow = false, glow = false,
            accent_override = Color(66, 150, 250, 255),
            bg = Color(15, 15, 15, math.max(op, 240)),
            border = Color(110, 110, 128, 140), border_w = 1.0,
            header = "bar", bar = Color(41, 74, 122, 255),
            divider = Color(110, 110, 128, 90),
            accent_bar = false, brackets = false, cards = false,
            text = Color(236, 236, 236, 255), dim = Color(150, 150, 150, 255),
            faint = Color(120, 120, 120, 255),
            marker = "square", marker_sz = 2.4, accent_text = false,
            strip_card = "square",
            strip_fill = Color(41, 74, 122, 110), strip_border = Color(110, 110, 128, 150),
        }
    elseif th == 2 then
        return {
            key = "figma", round = 8, glass = false, shadow = true, glow = false,
            accent_override = Color(13, 153, 255, 255),
            bg = Color(30, 31, 38, op),
            border = Color(255, 255, 255, 20), border_w = 1.0,
            header = "underline",
            divider = Color(255, 255, 255, 14),
            accent_bar = false, brackets = false, cards = true,
            text = Color(235, 237, 242, 255), dim = Color(150, 155, 166, 255),
            faint = Color(112, 117, 130, 255),
            marker = "dot", marker_sz = 2.2, accent_text = false,
            strip_card = "round",
            strip_fill = Color(255, 255, 255, 12),
        }
    elseif th == 3 then
        return {
            key = "neon", round = 6, glass = false, shadow = false, glow = true,
            bg = Color(7, 9, 16, math.min(op + 14, 255)),
            border = accent, border_w = 1.5,
            header = "neon",
            divider = alpha(accent, 80),
            accent_bar = false, brackets = false, cards = false,
            text = Color(232, 240, 255, 255), dim = tint(col_dim, accent, 0.35),
            faint = tint(col_faint, accent, 0.25),
            marker = "dot", marker_sz = 2.6, accent_text = true,
            strip_card = "none",
        }
    elseif th == 4 then
        return {
            key = "station", full = true, round = 12, shadow = true, glow = false,
            bg = Color(13, 16, 22, op),
            panel = Color(255, 255, 255, 10), panel2 = Color(255, 255, 255, 18),
            border = Color(255, 255, 255, 30), border_w = 1.0,
            divider = Color(255, 255, 255, 22),
            text = Color(228, 236, 246, 255), dim = Color(150, 160, 176, 255),
            faint = Color(104, 114, 130, 255),
            marker = "square", marker_sz = 2.0, accent_text = true,
            strip_card = "none",
        }
    elseif th == 5 then
        return {
            key = "radial", full = true, round = 18, shadow = true, glow = true,
            bg = Color(12, 14, 26, op),
            border = Color(255, 255, 255, 22), border_w = 1.0,
            text = Color(233, 239, 252, 255), dim = Color(150, 158, 182, 255),
            faint = Color(108, 116, 140, 255),
            marker = "dot", marker_sz = 2.4, accent_text = true,
            strip_card = "none",
        }
    elseif th == 6 then
        return {
            key = "bento", full = true, round = 16, shadow = true, glow = false,
            bg = Color(18, 19, 24, op),
            tile = Color(255, 255, 255, 14), tile2 = Color(255, 255, 255, 24),
            border = Color(255, 255, 255, 20), border_w = 1.0,
            divider = Color(255, 255, 255, 20),
            text = Color(236, 240, 248, 255), dim = Color(155, 162, 176, 255),
            faint = Color(110, 116, 130, 255),
            marker = "dot", marker_sz = 2.2, accent_text = true,
            strip_card = "none",
        }
    elseif th == 7 then
        return {
            key = "blueprint", full = true, round = 4, shadow = false, glow = false,
            accent_override = Color(120, 200, 255, 255),
            bg = Color(12, 30, 56, math.max(op, 240)),
            grid = Color(120, 180, 255, 28),
            border = Color(150, 200, 255, 120), border_w = 1.0,
            divider = Color(120, 180, 255, 60),
            text = Color(214, 234, 255, 255), dim = Color(150, 190, 235, 255),
            faint = Color(110, 150, 200, 255),
            marker = "square", marker_sz = 2.0, accent_text = false,
            strip_card = "none",
        }
    elseif th == 8 then
        return {
            key = "ticket", full = true, round = 10, shadow = true, glow = false,
            accent_override = Color(255, 168, 64, 255),
            bg = Color(244, 241, 232, math.max(op, 250)),
            stub = Color(28, 32, 40, 255),
            dash = Color(120, 126, 138, 255),
            border = Color(0, 0, 0, 40), border_w = 1.0,
            divider = Color(120, 126, 138, 120),
            text = Color(30, 34, 42, 255), dim = Color(96, 102, 112, 255),
            faint = Color(140, 146, 156, 255),
            marker = "dot", marker_sz = 2.0, accent_text = false,
            strip_card = "none",
        }
    end

    return {
        key = "glass", round = 14, glass = true, shadow = true,
        bg = Color(14, 16, 22, op),
        border = Color(255, 255, 255, 22), border_w = 1.0,
        header = "gradient",
        divider = col_line,
        accent_bar = true, brackets = false, cards = false,
        text = col_white, dim = col_dim, faint = col_faint,
        marker = "dot", marker_sz = 2.4, accent_text = false,
        strip_card = "none",
    }
end

ui.corner:SetCallback(function()
    local c = cget(ui.corner)
    if c == 0 then return end
    local sw, sh = screen_size()
    local _, _, w, h = get_rect()
    local m = 40
    local x, y = m, m
    if c == 2 or c == 4 then x = math.max(0, sw - w - m) end
    if c == 3 or c == 4 then y = math.max(0, sh - h - m) end
    ui.pos_x:Set(math.floor(x)); ui.pos_y:Set(math.floor(y))
end)

local function handle_drag()
    if adrag.active then drag.active = false; return end
    if ui.lock:Get() or not Menu.Opened() then drag.active = false; return end
    local mx, my = Input.GetCursorPos()
    local x, y, w, h = get_rect()
    if not drag.active and Input.IsKeyDownOnce(Enum.ButtonCode.KEY_MOUSE1)
        and Input.IsCursorInRect(x, y, w, h) then
        drag.active, drag.dx, drag.dy = true, mx - x, my - y
    end
    if drag.active then
        if Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE1) then
            local nx = math.max(0, math.min(3840, math.floor(mx - drag.dx)))
            local ny = math.max(0, math.min(2160, math.floor(my - drag.dy)))
            ui.pos_x:Set(nx); ui.pos_y:Set(ny)
            if cget(ui.corner) ~= 0 then ui.corner:Set(0) end
        else
            drag.active = false
        end
    end
end

local function handle_alarm_drag()
    if not (ui.alarm_enable:Get() and ui.alarm_status:Get()) then adrag.active = false; return end
    if ui.lock:Get() or drag.active or not Menu.Opened() then adrag.active = false; return end
    local r = alarm.rect
    if not r then return end
    local mx, my = Input.GetCursorPos()
    if not adrag.active and Input.IsKeyDownOnce(Enum.ButtonCode.KEY_MOUSE1)
        and Input.IsCursorInRect(r.x, r.y, r.w, r.h) then
        adrag.active, adrag.dx, adrag.dy = true, mx - r.x, my - r.y
    end
    if adrag.active then
        if Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE1) then
            local nx = math.max(0, math.min(3840, math.floor(mx - adrag.dx)))
            local ny = math.max(0, math.min(2160, math.floor(my - adrag.dy)))
            if not ui.alarm_move:Get() then ui.alarm_move:Set(true) end
            ui.alarm_px:Set(nx); ui.alarm_py:Set(ny)
        else
            adrag.active = false
        end
    end
end

local function update_particles(x, y, w, h, dt)
    if not ui.particles:Get() or not state.loaded then return end
    local cat = state.cat
    local is_rain = (cat == "rain" or cat == "storm")
    local is_snow = (cat == "snow")
    if not (is_rain or is_snow) then return end
    local target = is_rain and 26 or 20
    while #particles < target do
        particles[#particles + 1] = { px = math.random(), py = math.random(), v = 0.5 + math.random() }
    end
    while #particles > target do particles[#particles] = nil end
    for _, pt in ipairs(particles) do
        if is_rain then
            pt.py = pt.py + dt * (1.6 + pt.v * 1.2); pt.px = pt.px + dt * 0.18
        else
            pt.py = pt.py + dt * (0.35 + pt.v * 0.35)
            pt.px = pt.px + math.sin((pt.py + pt.v) * 6) * dt * 0.12
        end
        if pt.py > 1 then pt.py = pt.py - 1; pt.px = math.random() end
        if pt.px > 1 then pt.px = pt.px - 1 end
        if pt.px < 0 then pt.px = pt.px + 1 end
        local rx, ry = x + pt.px * w, y + pt.py * h
        if is_rain then
            Render.Line(Vec2(rx, ry), Vec2(rx - 2, ry + 6 + pt.v * 5), Color(150, 185, 240, 90), 1.0)
        else
            Render.FilledCircle(Vec2(rx, ry), 1.4 + pt.v, Color(232, 238, 250, 110))
        end
    end
end

local function draw_hilo(x0, top, s, st)
    if not state.t_max then return end
    local dim = (st and st.dim) or col_dim
    local mx = math.floor((conv_temp(state.t_max) or 0) + 0.5)
    local mn = math.floor((conv_temp(state.t_min) or 0) + 0.5)
    tri_fill(x0, top + 7 * s, x0 + 7 * s, top + 7 * s, x0 + 3.5 * s, top + 1 * s, col_hi)
    soft_text(font_text, math.floor(11 * s * g_ts), ("%d\u{00b0}"):format(mx), Vec2(x0 + 11 * s, top), dim)
    tri_fill(x0, top + 16 * s, x0 + 7 * s, top + 16 * s, x0 + 3.5 * s, top + 22 * s, col_lo)
    soft_text(font_text, math.floor(11 * s * g_ts), ("%d\u{00b0}"):format(mn), Vec2(x0 + 11 * s, top + 15 * s), dim)
end

local function draw_marker(cx, cy, color, st, s)
    local r = ((st and st.marker_sz) or 2.4) * s
    if st and st.marker == "square" then
        Render.FilledRect(Vec2(cx - r, cy - r), Vec2(cx + r, cy + r), color)
    else
        Render.FilledCircle(Vec2(cx, cy), r, color)
    end
end

local function mins_of(iso) return (hour_of(iso) * 60) + (tonumber(iso and iso:sub(15, 16)) or 0) end

local function daylight_frac()
    if not (state.sunrise and state.sunset) then return nil end
    local t = os.date("*t")
    local nowm = t.hour * 60 + t.min
    local sr, sn = mins_of(state.sunrise), mins_of(state.sunset)
    if sn <= sr then return nil end
    return math.max(0, math.min(1, (nowm - sr) / (sn - sr)))
end

local function draw_metrics(x, y, w, s, pad, st)
    local dim = (st and st.dim) or col_dim
    local L = ui.lang_ru:Get()
    local lines = {
        { (L and "Осадки: %d%%"  or "Precip %d%%"):format(state.precip or 0), dot_precip },
        { (L and "Влажность: %d%%" or "Humidity %d%%"):format(state.humidity or 0), dot_humid },
        { (L and "Ветер: %d %s %s" or "Wind %d %s %s"):format(
            math.floor(conv_wind(state.wind) + 0.5), wind_unit(), compass(state.wind_dir)), dot_wind },
    }
    if ui.show_feels:Get() then
        lines[#lines + 1] = { (L and "Ощущается: %d\u{00b0}" or "Feels %d\u{00b0}"):format(
            math.floor((conv_temp(state.feels or state.temp) or 0) + 0.5)), dot_feels }
    end
    local ry = y + 11 * s
    for _, ln in ipairs(lines) do
        local sz = Render.TextSize(font_text, math.floor(12 * s * g_ts), ln[1])
        local tx = x + w - pad - sz.x
        draw_marker(tx - 8 * s, ry + 6 * s, ln[2], st, s)
        soft_text(font_text, math.floor(12 * s * g_ts), ln[1], Vec2(tx, ry), dim)
        ry = ry + 16 * s
    end
end

local function metric_list()
    local L = ui.lang_ru:Get()
    local m = {
        { L and "Осадки"    or "Precip",   ("%d%%"):format(state.precip or 0),   dot_precip },
        { L and "Влажность" or "Humidity", ("%d%%"):format(state.humidity or 0), dot_humid },
        { L and "Ветер"     or "Wind",     ("%d %s %s"):format(
            math.floor(conv_wind(state.wind) + 0.5), wind_unit(), compass(state.wind_dir)), dot_wind },
    }
    if ui.show_feels:Get() then
        m[#m + 1] = { L and "Ощущается" or "Feels",
            ("%d\u{00b0}"):format(math.floor((conv_temp(state.feels or state.temp) or 0) + 0.5)), dot_feels }
    end
    return m
end

local function draw_sun_pressure(x, y, w, s, pad, st, row_y)
    if ui.show_sun:Get() and state.sunrise then
        local fs = math.floor(11 * s * g_ts)
        local sx = x + pad
        draw_sun_h(sx + 7 * s, row_y + 4 * s, s, true)
        local srt = hhmm(state.sunrise)
        soft_text(font_text, fs, srt, Vec2(sx + 20 * s, row_y), st.dim)
        local srw = Render.TextSize(font_text, fs, srt).x
        local sx2 = sx + 20 * s + srw + 18 * s
        draw_sun_h(sx2 + 7 * s, row_y + 4 * s, s, false)
        soft_text(font_text, fs, hhmm(state.sunset), Vec2(sx2 + 20 * s, row_y), st.dim)
    end
    if ui.show_extra:Get() and state.pressure then
        local full = ("%d гПа   UV %.0f"):format(math.floor((state.pressure or 0) + 0.5), state.uv or 0)
        local sz = Render.TextSize(font_text, math.floor(11 * s * g_ts), full)
        local bx = x + w - pad - sz.x
        draw_marker(bx - 8 * s, row_y + 6 * s, dot_press, st, s)
        soft_text(font_text, math.floor(11 * s * g_ts), full, Vec2(bx, row_y), st.dim)
    end
end

local function draw_hourly(x, y, w, h, s, pad, st, now, top)
    if not (ui.show_hourly:Get() and #state.hourly > 0) then return end
    local strip_top = y + top * s
    if st.strip_card == "none" then
        Render.Line(Vec2(x + pad, strip_top - 6 * s), Vec2(x + w - pad, strip_top - 6 * s), st.divider, 1.0)
    end
    local n = #state.hourly
    local col_w = (w - pad * 2) / n
    for i, hr in ipairs(state.hourly) do
        local cx = x + pad + (i - 0.5) * col_w
        if st.strip_card == "round" or st.strip_card == "square" then
            local cr = (st.strip_card == "round") and 6 * s or 0
            local hw = col_w * 0.5 - 2 * s
            local cp1 = Vec2(cx - hw, strip_top - 2 * s)
            local cp2 = Vec2(cx + hw, y + h - 24 * s)
            Render.FilledRect(cp1, cp2, st.strip_fill or Color(255, 255, 255, 8), cr)
            if st.strip_border then Render.Rect(cp1, cp2, st.strip_border, cr, Enum.DrawFlags.None, 1.0) end
        end
        local day_h = true
        if state.sunrise and state.sunset then
            day_h = hr.h >= hour_of(state.sunrise) and hr.h < hour_of(state.sunset)
        end
        local hl = ("%02d"):format(hr.h)
        local hsz = Render.TextSize(font_text, math.floor(10 * s * g_ts), hl)
        soft_text(font_text, math.floor(10 * s * g_ts), hl, Vec2(cx - hsz.x / 2, strip_top), st.dim)
        draw_icon(hr.cat, cx, strip_top + 26 * s + (now > 0 and math.sin(now * 2.0 + i * 0.7) * 1.6 * s or 0), s * 0.44, day_h, st.bg, now * 0.6)
        local tt = ("%d\u{00b0}"):format(math.floor((conv_temp(hr.temp) or 0) + 0.5))
        local tsz2 = Render.TextSize(font_text, math.floor(11 * s * g_ts), tt)
        soft_text(font_text, math.floor(11 * s * g_ts), tt, Vec2(cx - tsz2.x / 2, strip_top + 42 * s), st.text)
        if hr.pop and hr.pop >= 30 then
            local pl = ("%d%%"):format(hr.pop)
            local psz = Render.TextSize(font_text, math.floor(9 * s * g_ts), pl)
            local pa = (now > 0) and (0.65 + 0.35 * math.abs(math.sin(now * 2.0 + i))) or 1
            soft_text(font_text, math.floor(9 * s * g_ts), pl, Vec2(cx - psz.x / 2, strip_top + 56 * s), alpha(dot_precip, math.floor(255 * pa)))
        end
    end
end

local function layout_glass(x, y, w, h, s, mode, st, accent, tstr, temp_col, now)
    local pad = 14 * s
    soft_text(font_text, math.floor(12 * s * g_ts), state.desc, Vec2(x + pad, y + 49 * s), st.dim)
    local big = math.floor(30 * s * g_ts)
    local tsz = Render.TextSize(font_temp, big, tstr)
    local temp_x, temp_y = x + pad + 44 * s, y + 70 * s
    draw_icon(state.cat, x + pad + 14 * s, y + 84 * s, s, state.is_day, st.bg, now * 0.6)
    Render.Text(font_temp, big, tstr, Vec2(temp_x, temp_y), temp_col)
    if ui.show_hilo:Get() then
        draw_hilo(math.min(temp_x + tsz.x + 14 * s, x + w * 0.60 - 36 * s), y + 66 * s, s, st)
    end
    Render.Line(Vec2(x + w * 0.60, y + 16 * s), Vec2(x + w * 0.60, y + 88 * s), st.divider, 1.0)
    draw_metrics(x, y, w, s, pad, st)
    if mode == 2 then
        draw_sun_pressure(x, y, w, s, pad, st, y + 100 * s)
        draw_hourly(x, y, w, h, s, pad, st, now, 122)
    end
end

local function layout_imgui(x, y, w, h, s, mode, st, accent, tstr, temp_col, now)
    local pad = 12 * s
    soft_text(font_text, math.floor(11 * s * g_ts), state.desc, Vec2(x + pad, y + 33 * s), st.dim)
    local big = math.floor(26 * s * g_ts)
    local tsz = Render.TextSize(font_temp, big, tstr)
    draw_icon(state.cat, x + pad + 12 * s, y + 64 * s, s * 0.82, state.is_day, st.bg, now * 0.6)
    glow_text(font_temp, big, tstr, Vec2(x + pad + 28 * s, y + 48 * s), temp_col, nil, 18 + 6 * math.sin(now * 2.2))
    if state.t_max then
        local mx = math.floor((conv_temp(state.t_max) or 0) + 0.5)
        local mn = math.floor((conv_temp(state.t_min) or 0) + 0.5)
        local hl = ("H %d\u{00b0}   L %d\u{00b0}"):format(mx, mn)
        local hlfs = math.floor(12 * s * g_ts)
        local hlx = math.min(x + pad + 28 * s + tsz.x + 14 * s, x + w - pad - Render.TextSize(font_text, hlfs, hl).x)
        soft_text(font_text, hlfs, hl, Vec2(hlx, y + 56 * s), st.dim)
    end
    Render.Line(Vec2(x + pad, y + 80 * s), Vec2(x + w - pad, y + 80 * s), st.divider, 1.0)
    local m = metric_list()
    local cellw = (w - pad * 2) * 0.5
    local gy = y + 88 * s
    for i, it in ipairs(m) do
        local col = (i - 1) % 2
        local rowi = math.floor((i - 1) / 2)
        local cxp = x + pad + col * cellw
        local cyp = gy + rowi * 17 * s
        draw_marker(cxp + 3 * s, cyp + 6 * s, it[3], st, s)
        soft_text(font_text, math.floor(11 * s * g_ts), it[1], Vec2(cxp + 12 * s, cyp), st.dim)
        local vsz = Render.TextSize(font_text, math.floor(11 * s * g_ts), it[2])
        soft_text(font_text, math.floor(11 * s * g_ts), it[2], Vec2(cxp + cellw - 10 * s - vsz.x, cyp), st.text)
    end
    if mode == 2 then
        Render.Line(Vec2(x + pad, y + 124 * s), Vec2(x + w - pad, y + 124 * s), st.divider, 1.0)
        draw_sun_pressure(x, y, w, s, pad, st, y + 130 * s)
        draw_hourly(x, y, w, h, s, pad, st, now, 154)
    end
end

local function layout_figma(x, y, w, h, s, mode, st, accent, tstr, temp_col, now)
    local pad = 14 * s
    local cp1 = Vec2(x + pad, y + 44 * s)
    local cp2 = Vec2(x + w * 0.5 - 4 * s, y + 120 * s)
    Render.FilledRect(cp1, cp2, Color(255, 255, 255, 8), 8 * s)
    soft_text(font_text, math.floor(11 * s * g_ts), state.desc, Vec2(x + pad + 12 * s, y + 50 * s), st.dim)
    local big = math.floor(30 * s * g_ts)
    local tsz = Render.TextSize(font_temp, big, tstr)
    draw_icon(state.cat, x + pad + 22 * s, y + 86 * s, s * 0.82, state.is_day, st.bg, now * 0.6)
    glow_text(font_temp, big, tstr, Vec2(x + pad + 44 * s, y + 72 * s), temp_col, st.glow and accent or nil, 18 + 6 * math.sin(now * 2.2))
    if ui.show_hilo:Get() then draw_hilo(math.min(x + pad + 44 * s + tsz.x + 12 * s, x + w * 0.5 - 30 * s), y + 78 * s, s, st) end
    local chip_x = x + w * 0.5 + 6 * s
    local chip_w = w * 0.5 - 6 * s - pad
    local cy = y + 46 * s
    for _, it in ipairs(metric_list()) do
        Render.FilledRect(Vec2(chip_x, cy), Vec2(chip_x + chip_w, cy + 18 * s), Color(255, 255, 255, 10), 9 * s)
        draw_marker(chip_x + 10 * s, cy + 9 * s, it[3], st, s)
        soft_text(font_text, math.floor(11 * s * g_ts), it[1], Vec2(chip_x + 18 * s, cy + 3 * s), st.dim)
        local vsz = Render.TextSize(font_text, math.floor(11 * s * g_ts), it[2])
        soft_text(font_text, math.floor(11 * s * g_ts), it[2], Vec2(chip_x + chip_w - 9 * s - vsz.x, cy + 3 * s), st.text)
        cy = cy + 22 * s
    end
    if mode == 2 then
        draw_sun_pressure(x, y, w, s, pad, st, y + 132 * s)
        draw_hourly(x, y, w, h, s, pad, st, now, 154)
    end
end

local function layout_neon(x, y, w, h, s, mode, st, accent, tstr, temp_col, now)
    local pad = 14 * s

    local scan = y + 44 * s + ((now * 24) % math.max(1, h - 56 * s))
    Render.Line(Vec2(x + pad, scan), Vec2(x + w - pad, scan), alpha(accent, 22), 1.0)
    local dsz = Render.TextSize(font_text, math.floor(11 * s * g_ts), state.desc)
    soft_text(font_text, math.floor(11 * s * g_ts), state.desc, Vec2(x + (w - dsz.x) * 0.5, y + 34 * s), st.dim)
    local big = math.floor(34 * s * g_ts)
    local tsz = Render.TextSize(font_temp, big, tstr)
    local tx = x + (w - tsz.x) * 0.5
    local ty = y + 50 * s
    draw_icon(state.cat, tx - 24 * s, ty + tsz.y * 0.5, s * 0.8, state.is_day, st.bg, now * 0.6)
    glow_text(font_temp, big, tstr, Vec2(tx, ty), temp_col, accent, 36 + 14 * math.sin(now * 2.2))
    if ui.show_hilo:Get() then draw_hilo(math.min(tx + tsz.x + 14 * s, x + w - pad - 30 * s), ty + 4 * s, s, st) end
    local m = metric_list()
    local seg = (w - pad * 2) / #m
    local row = y + 96 * s
    for i, it in ipairs(m) do
        local sx = x + pad + (i - 0.5) * seg
        local vsz = Render.TextSize(font_text, math.floor(12 * s * g_ts), it[2])
        soft_text(font_text, math.floor(12 * s * g_ts), it[2], Vec2(sx - vsz.x * 0.5, row), st.text)
        local lsz = Render.TextSize(font_text, math.floor(9 * s * g_ts), it[1])
        soft_text(font_text, math.floor(9 * s * g_ts), it[1], Vec2(sx - lsz.x * 0.5, row + 15 * s), st.faint)
        if i > 1 then
            Render.Line(Vec2(x + pad + (i - 1) * seg, row - 2 * s), Vec2(x + pad + (i - 1) * seg, row + 24 * s), alpha(accent, 60), 1.0)
        end
    end
    if mode == 2 then
        draw_sun_pressure(x, y, w, s, pad, st, y + 130 * s)
        draw_hourly(x, y, w, h, s, pad, st, now, 152)
    end
end

local function arc(cx, cy, r, a0, a1, segs, color, th)
    local px, py
    for i = 0, segs do
        local a = a0 + (a1 - a0) * (i / segs)
        local nx, ny = cx + math.cos(a) * r, cy + math.sin(a) * r
        if px then Render.Line(Vec2(px, py), Vec2(nx, ny), color, th or 1.0) end
        px, py = nx, ny
    end
end

local function layout_station(x, y, w, h, s, mode, st, accent, tstr, temp_col, now)
    local pad = 14 * s
    local fb = (ui.show_status:Get() and state.fetched_clock) and 16 * s or 6 * s
    Render.Rect(Vec2(x, y), Vec2(x + w, y + h), st.border, st.round * s, Enum.DrawFlags.None, 1.0)
    glow_text(font_city, math.floor(16 * s * g_ts), state.city, Vec2(x + pad, y + 9 * s), st.text, accent, 12)
    local led = 0.45 + 0.55 * math.abs(math.sin(now * 2.4))
    Render.FilledCircle(Vec2(x + w - pad - 3 * s, y + 16 * s), 3.0 * s, alpha(accent, math.floor(90 + 130 * led)))
    if ui.show_clock:Get() then
        local t = os.date("*t")
        local sep = (now == 0 or math.floor(now * 2) % 2 == 0) and ":" or " "
        local tl = ("%02d%s%02d"):format(t.hour, sep, t.min)
        local tsz = Render.TextSize(font_text, math.floor(12 * s * g_ts), tl)
        soft_text(font_text, math.floor(12 * s * g_ts), tl, Vec2(x + w - pad - 14 * s - tsz.x, y + 10 * s), st.dim)
    end
    Render.Line(Vec2(x + pad, y + 31 * s), Vec2(x + w - pad, y + 31 * s), st.divider, 1.0)
    if not tstr then
        soft_text(font_text, math.floor(12 * s * g_ts), state.error or "Загрузка...", Vec2(x + pad, y + 44 * s), accent)
        return
    end
    local top = y + 38 * s
    local cb = y + h - fb - 4 * s
    local lw = (mode == 0) and (w - pad * 2) or math.floor(w * 0.52)
    local main_b = (mode == 2) and (top + (cb - top) * 0.52) or cb
    Render.FilledRect(Vec2(x + pad, top), Vec2(x + pad + lw, main_b), st.panel, 8 * s)
    Render.Rect(Vec2(x + pad, top), Vec2(x + pad + lw, main_b), alpha(st.text, 18), 8 * s, Enum.DrawFlags.None, 1.0)
    local mcy = (top + main_b) * 0.5
    draw_icon(state.cat, x + pad + 28 * s, mcy - (mode == 0 and 0 or 8) * s, s * 0.74, state.is_day, st.bg, now * 0.6)
    glow_text(font_temp, math.floor(34 * s * g_ts), tstr, Vec2(x + pad + 54 * s, mcy - 24 * s), temp_col, accent, 16 + 8 * math.abs(math.sin(now * 2.0)))
    if mode == 0 then
        if state.t_max then
            local hl = ("%d\u{00b0} / %d\u{00b0}"):format(math.floor((conv_temp(state.t_max) or 0) + 0.5), math.floor((conv_temp(state.t_min) or 0) + 0.5))
            local hsz = Render.TextSize(font_text, math.floor(11 * s * g_ts), hl)
            soft_text(font_text, math.floor(11 * s * g_ts), hl, Vec2(x + pad + lw - 12 * s - hsz.x, mcy - 5 * s), st.dim)
        end
        return
    end
    soft_text(font_text, math.floor(11 * s * g_ts), state.desc, Vec2(x + pad + 14 * s, main_b - 30 * s), st.dim)
    local gx = x + pad + 14 * s
    local gw = lw - 28 * s
    local gyy = main_b - 13 * s
    local mn = conv_temp(state.t_min) or 0
    local mx = conv_temp(state.t_max) or (mn + 1)
    local cur = conv_temp(state.temp) or mn
    local frac = math.max(0, math.min(1, (cur - mn) / math.max(0.1, mx - mn)))
    local segn = 16
    for i = 0, segn - 1 do
        local f0 = i / segn
        local sx0 = gx + gw * f0 + 1.5 * s
        local sx1 = gx + gw * (i + 1) / segn - 1.5 * s
        local cc = (f0 <= frac) and tint(col_lo, col_hi, f0) or alpha(st.text, 24)
        Render.FilledRect(Vec2(sx0, gyy - 2.5 * s), Vec2(sx1, gyy + 2.5 * s), cc, 1 * s)
    end
    if now > 0 and frac > 0 then
        local scan = (now * 0.5) % 1
        if scan <= frac then
            local hx = gx + gw * scan
            Render.FilledRect(Vec2(hx - 1.5 * s, gyy - 4 * s), Vec2(hx + 1.5 * s, gyy + 4 * s), Color(255, 255, 255, 210), 1 * s)
        end
    end
    local rx = x + pad + lw + 8 * s
    local rx2 = x + w - pad
    Render.FilledRect(Vec2(rx, top), Vec2(rx2, main_b), st.panel, 8 * s)
    Render.Rect(Vec2(rx, top), Vec2(rx2, main_b), alpha(st.text, 18), 8 * s, Enum.DrawFlags.None, 1.0)
    local m = metric_list()
    local rh = (main_b - top - 12 * s) / #m
    local ry = top + 6 * s
    for _, it in ipairs(m) do
        draw_marker(rx + 12 * s, ry + rh * 0.5, it[3], st, s)
        soft_text(font_text, math.floor(10 * s * g_ts), it[1], Vec2(rx + 20 * s, ry + rh * 0.5 - 11 * s), st.faint)
        local vsz = Render.TextSize(font_city, math.floor(13 * s * g_ts), it[2])
        soft_text(font_city, math.floor(13 * s * g_ts), it[2], Vec2(rx2 - 10 * s - vsz.x, ry + rh * 0.5 - 8 * s), st.text)
        ry = ry + rh
    end
    if mode ~= 2 then return end
    local bt = main_b + 8 * s
    Render.FilledRect(Vec2(x + pad, bt), Vec2(x + w - pad, cb), st.panel, 8 * s)
    Render.Rect(Vec2(x + pad, bt), Vec2(x + w - pad, cb), alpha(st.text, 18), 8 * s, Enum.DrawFlags.None, 1.0)
    local row_y = bt + 6 * s
    if ui.show_sun:Get() and state.sunrise then
        draw_sun_h(x + pad + 14 * s, row_y + 5 * s, s, true)
        soft_text(font_text, math.floor(10 * s * g_ts), hhmm(state.sunrise), Vec2(x + pad + 26 * s, row_y), st.dim)
        draw_sun_h(x + pad + 72 * s, row_y + 5 * s, s, false)
        soft_text(font_text, math.floor(10 * s * g_ts), hhmm(state.sunset), Vec2(x + pad + 84 * s, row_y), st.dim)
    end
    if ui.show_extra:Get() and state.pressure then
        local full = ("%d гПа  UV %.0f"):format(math.floor((state.pressure or 0) + 0.5), state.uv or 0)
        local sz = Render.TextSize(font_text, math.floor(10 * s * g_ts), full)
        local bx = x + w - pad - 12 * s - sz.x
        if bx > x + pad + 120 * s then
            soft_text(font_text, math.floor(10 * s * g_ts), full, Vec2(bx, row_y), st.dim)
        end
    end
    if ui.show_hourly:Get() and #state.hourly > 0 then
        local hy = row_y + 20 * s
        local n = #state.hourly
        local cw = (w - pad * 2 - 12 * s) / n
        for i, hr in ipairs(state.hourly) do
            local cx = x + pad + 6 * s + (i - 0.5) * cw
            local hl = ("%02d"):format(hr.h)
            local hsz = Render.TextSize(font_text, math.floor(9 * s * g_ts), hl)
            soft_text(font_text, math.floor(9 * s * g_ts), hl, Vec2(cx - hsz.x / 2, hy), st.faint)
            draw_icon(hr.cat, cx, hy + 27 * s + (now > 0 and math.sin(now * 2.0 + i * 0.7) * 1.4 * s or 0), s * 0.36, true, st.bg, now * 0.6)
            local tt = ("%d\u{00b0}"):format(math.floor((conv_temp(hr.temp) or 0) + 0.5))
            local tsz2 = Render.TextSize(font_text, math.floor(10 * s * g_ts), tt)
            soft_text(font_text, math.floor(10 * s * g_ts), tt, Vec2(cx - tsz2.x / 2, hy + 40 * s), st.text)
        end
    end
end

local function layout_aurora(x, y, w, h, s, mode, st, accent, tstr, temp_col, now)
    local pad = 16 * s
    local cx = x + w * 0.5
    local fb = (ui.show_status:Get() and state.fetched_clock) and 16 * s or 4 * s
    if ui.animations:Get() and now > 0 then
        for b = 1, 3 do
            local amp = (6 + b * 3) * s
            local yb = y + (20 + b * 9) * s
            local col = alpha(tint(accent, st.text, 0.18 * b), 24)
            local px, py
            for i = 0, 20 do
                local fx = i / 20
                local nx = x + 6 * s + fx * (w - 12 * s)
                local ny = yb + math.sin(now * (0.6 + b * 0.2) + fx * 6.28 + b) * amp
                if px then Render.Line(Vec2(px, py), Vec2(nx, ny), col, 2.0) end
                px, py = nx, ny
            end
        end
    end
    Render.Rect(Vec2(x, y), Vec2(x + w, y + h), st.border, st.round * s, Enum.DrawFlags.None, 1.0)
    local csz = Render.TextSize(font_city, math.floor(15 * s * g_ts), state.city)
    glow_text(font_city, math.floor(15 * s * g_ts), state.city, Vec2(cx - csz.x * 0.5, y + 9 * s), st.text, accent, 26)
    if ui.show_clock:Get() then
        local tl = os.date("%H:%M")
        local hsz = Render.TextSize(font_text, math.floor(10 * s * g_ts), tl)
        soft_text(font_text, math.floor(10 * s * g_ts), tl, Vec2(cx - hsz.x * 0.5, y + 24 * s), st.faint)
    end
    local ring_r = (mode == 0 and 30 or 45) * s
    local ringcy = y + (mode == 0 and 64 or 90) * s
    if not tstr then
        local lsz = Render.TextSize(font_text, math.floor(12 * s * g_ts), state.error or "Загрузка...")
        soft_text(font_text, math.floor(12 * s * g_ts), state.error or "Загрузка...", Vec2(cx - lsz.x * 0.5, ringcy), accent)
        return
    end
    local a0, a1 = math.rad(135), math.rad(405)
    local tval = conv_temp(state.temp) or 0
    local tmin = is_f() and 0 or -20
    local tmax = is_f() and 110 or 45
    local frac = math.max(0, math.min(1, (tval - tmin) / (tmax - tmin)))
    arc(cx, ringcy, ring_r, a0, a1, 56, alpha(st.text, 26), 3.0 * s)
    for gi = 3, 1, -1 do
        arc(cx, ringcy, ring_r, a0, a0 + (a1 - a0) * frac, 56, alpha(accent, math.floor(55 / gi)), (3.0 + gi) * s)
    end
    arc(cx, ringcy, ring_r, a0, a0 + (a1 - a0) * frac, 56, accent, 3.0 * s)
    if now > 0 then
        local sa = a0 + (a1 - a0) * frac
        Render.FilledCircle(Vec2(cx + math.cos(sa) * ring_r, ringcy + math.sin(sa) * ring_r), 3.0 * s, Color(255, 255, 255, 230))
    end
    for i = 0, 9 do
        local a = a0 + (a1 - a0) * (i / 9)
        Render.Line(Vec2(cx + math.cos(a) * (ring_r + 5 * s), ringcy + math.sin(a) * (ring_r + 5 * s)), Vec2(cx + math.cos(a) * (ring_r + 9 * s), ringcy + math.sin(a) * (ring_r + 9 * s)), alpha(st.text, 50), 1.0)
    end
    local big = math.floor((mode == 0 and 24 or 30) * s)
    local tsz = Render.TextSize(font_temp, big, tstr)
    while tsz.x > ring_r * 1.7 and big > 12 do
        big = big - 1
        tsz = Render.TextSize(font_temp, big, tstr)
    end
    glow_text(font_temp, big, tstr, Vec2(cx - tsz.x * 0.5, ringcy - tsz.y * 0.5), temp_col, accent, 20 + 8 * math.sin(now * 2.2))
    local dsz = Render.TextSize(font_text, math.floor(11 * s * g_ts), state.desc)
    local grp = 22 * s + dsz.x
    local gx0 = cx - grp * 0.5
    local drow = ringcy + ring_r + 12 * s
    draw_icon(state.cat, gx0 + 8 * s, drow, s * 0.46, state.is_day, st.bg, now * 0.6)
    soft_text(font_text, math.floor(11 * s * g_ts), state.desc, Vec2(gx0 + 22 * s, drow - 7 * s), st.dim)
    if mode == 0 then return end
    local m = metric_list()
    local seg = (w - pad * 2) / #m
    local row = ringcy + ring_r + 38 * s
    for i, it in ipairs(m) do
        local mx2 = x + pad + (i - 0.5) * seg
        local vsz = Render.TextSize(font_text, math.floor(12 * s * g_ts), it[2])
        draw_marker(mx2 - vsz.x * 0.5 - 9 * s, row + 6 * s, it[3], st, s)
        soft_text(font_text, math.floor(12 * s * g_ts), it[2], Vec2(mx2 - vsz.x * 0.5, row), st.text)
        local lsz = Render.TextSize(font_text, math.floor(9 * s * g_ts), it[1])
        soft_text(font_text, math.floor(9 * s * g_ts), it[1], Vec2(mx2 - lsz.x * 0.5, row + 15 * s), st.faint)
        if i < #m then Render.Line(Vec2(x + pad + i * seg, row + 2 * s), Vec2(x + pad + i * seg, row + 24 * s), alpha(st.text, 22), 1.0) end
    end
    if mode == 2 and #state.hourly > 0 then
        draw_hourly(x, y, w, h, s, pad, st, now, (h - fb) / s - 56)
    end
end

local function layout_bento(x, y, w, h, s, mode, st, accent, tstr, temp_col, now)
    local pad = 12 * s
    local gap = 5 * s
    local fb = (ui.show_status:Get() and state.fetched_clock) and 16 * s or 6 * s
    local function tile(x1, y1, x2, y2, hot)
        Render.FilledRect(Vec2(x1, y1), Vec2(x2, y2), hot and st.tile2 or st.tile, 12 * s)
        Render.Rect(Vec2(x1, y1), Vec2(x2, y2), alpha(st.text, 16), 12 * s, Enum.DrawFlags.None, 1.0)
    end
    glow_text(font_city, math.floor(16 * s * g_ts), state.city, Vec2(x + pad, y + 12 * s), st.text, accent, 14)
    if ui.show_clock:Get() then
        local tl = os.date("%H:%M")
        local tlsz = Render.TextSize(font_text, math.floor(11 * s * g_ts), tl)
        soft_text(font_text, math.floor(11 * s * g_ts), tl, Vec2(x + w - pad - tlsz.x, y + 14 * s), st.faint)
    end
    local top = y + 38 * s
    if not tstr then
        soft_text(font_text, math.floor(12 * s * g_ts), state.error or "Загрузка...", Vec2(x + pad, top + 6 * s), accent)
        return
    end
    local cb = y + h - fb
    local split = x + pad + math.floor((w - pad * 2 - gap) * 0.5)
    local main_h = (mode == 0) and (cb - top) or ((mode == 2) and 88 * s or 98 * s)
    local main_y2 = top + main_h
    tile(x + pad, top, split, main_y2, true)
    local mcx = x + pad
    local mcy = (top + main_y2) * 0.5
    draw_icon(state.cat, mcx + 28 * s, mcy - 6 * s, s * 0.86, state.is_day, st.bg, now * 0.6)
    glow_text(font_temp, math.floor(34 * s * g_ts), tstr, Vec2(mcx + 54 * s, mcy - 24 * s), temp_col, accent, 18)
    soft_text(font_text, math.floor(11 * s * g_ts), state.desc, Vec2(mcx + 16 * s, main_y2 - 22 * s), st.dim)
    local m = metric_list()
    local gx = split + gap
    local gw = (x + w - pad - gx - gap) * 0.5
    local gh = (main_h - gap) * 0.5
    for i = 1, math.min(4, #m) do
        local it = m[i]
        local cc = (i - 1) % 2
        local rr = math.floor((i - 1) / 2)
        local tx1 = gx + cc * (gw + gap)
        local ty1 = top + rr * (gh + gap)
        tile(tx1, ty1, tx1 + gw, ty1 + gh, false)
        local ip = 11 * s
        draw_marker(tx1 + ip + 2 * s, ty1 + 13 * s, it[3], st, s)
        soft_text(font_text, math.floor(9 * s * g_ts), it[1], Vec2(tx1 + ip + 11 * s, ty1 + 8 * s), st.faint)
        local vfs = math.floor(15 * s * g_ts)
        local maxw = gw - ip * 1.8
        local vsz = Render.TextSize(font_city, vfs, it[2])
        while vsz.x > maxw and vfs > 9 do
            vfs = vfs - 1
            vsz = Render.TextSize(font_city, vfs, it[2])
        end
        soft_text(font_city, vfs, it[2], Vec2(tx1 + ip, ty1 + 22 * s), st.text)
    end
    if mode == 0 then return end
    local by1 = main_y2 + gap
    local by2 = cb
    tile(x + pad, by1, x + w - pad, by2, false)
    if mode == 2 and #state.hourly > 0 then
        local n = #state.hourly
        local cw = (w - pad * 2 - 12 * s) / n
        local mid = (by1 + by2) * 0.5
        for i, hr in ipairs(state.hourly) do
            local hcx = x + pad + 6 * s + (i - 0.5) * cw
            local hl = ("%02d"):format(hr.h)
            local hsz = Render.TextSize(font_text, math.floor(10 * s * g_ts), hl)
            soft_text(font_text, math.floor(10 * s * g_ts), hl, Vec2(hcx - hsz.x / 2, by1 + 11 * s), st.dim)
            draw_icon(hr.cat, hcx, mid + 1 * s + (now > 0 and math.sin(now * 2.0 + i * 0.7) * 1.4 * s or 0), s * 0.4, true, st.bg, now * 0.6)
            local tt = ("%d\u{00b0}"):format(math.floor((conv_temp(hr.temp) or 0) + 0.5))
            local tsz2 = Render.TextSize(font_text, math.floor(11 * s * g_ts), tt)
            soft_text(font_text, math.floor(11 * s * g_ts), tt, Vec2(hcx - tsz2.x / 2, by2 - 17 * s), st.text)
        end
    else
        local midy = (by1 + by2) * 0.5
        if ui.show_sun:Get() and state.sunrise then
            draw_sun_h(x + pad + 16 * s, midy, s, true)
            soft_text(font_text, math.floor(11 * s * g_ts), hhmm(state.sunrise), Vec2(x + pad + 28 * s, midy - 6 * s), st.dim)
            draw_sun_h(x + pad + 86 * s, midy, s, false)
            soft_text(font_text, math.floor(11 * s * g_ts), hhmm(state.sunset), Vec2(x + pad + 98 * s, midy - 6 * s), st.dim)
        end
        if state.pressure then
            local full = ("%d гПа  UV %.0f"):format(math.floor((state.pressure or 0) + 0.5), state.uv or 0)
            local fsz = Render.TextSize(font_text, math.floor(11 * s * g_ts), full)
            local bx = x + w - pad - 16 * s - fsz.x
            if bx > x + pad + 130 * s then
                soft_text(font_text, math.floor(11 * s * g_ts), full, Vec2(bx, midy - 6 * s), st.dim)
            end
        end
    end
end

local function layout_blueprint(x, y, w, h, s, mode, st, accent, tstr, temp_col, now)
    local pad = 16 * s
    local step = 22 * s
    local fb = (ui.show_status:Get() and state.fetched_clock) and 15 * s or 2 * s
    local gx = x + step
    while gx < x + w - 1 do Render.Line(Vec2(gx, y + 1), Vec2(gx, y + h - 1), st.grid, 1.0); gx = gx + step end
    local gy = y + step
    while gy < y + h - 1 do Render.Line(Vec2(x + 1, gy), Vec2(x + w - 1, gy), st.grid, 1.0); gy = gy + step end
    if ui.animations:Get() and now > 0 then
        local sf = (now * 0.16) % 1
        local sy = y + 2 + (h - 4) * sf
        Render.FilledRect(Vec2(x + 1, sy - 9 * s), Vec2(x + w - 1, sy), alpha(accent, 12))
        Render.Line(Vec2(x + 1, sy), Vec2(x + w - 1, sy), alpha(accent, 80), 1.0)
    end
    Render.Rect(Vec2(x, y), Vec2(x + w, y + h), st.border, st.round * s, Enum.DrawFlags.None, 1.2)
    corner_brackets(x + 4 * s, y + 4 * s, w - 8 * s, h - 8 * s, 10 * s, accent, 1.4)
    glow_text(font_city, math.floor(15 * s * g_ts), state.city, Vec2(x + pad, y + 9 * s), st.text, accent, 14)
    if ui.show_clock:Get() then
        local tl = os.date("%H:%M")
        local tlsz = Render.TextSize(font_text, math.floor(11 * s * g_ts), tl)
        soft_text(font_text, math.floor(11 * s * g_ts), tl, Vec2(x + w - pad - tlsz.x, y + 10 * s), st.dim)
    end
    Render.Line(Vec2(x + pad, y + 30 * s), Vec2(x + w - pad, y + 30 * s), st.border, 1.0)
    if not tstr then
        soft_text(font_text, math.floor(12 * s * g_ts), state.error or "fetching...", Vec2(x + pad, y + 42 * s), accent)
        return
    end
    local big = math.floor((mode == 0 and 30 or 40) * s)
    local tsz = Render.TextSize(font_temp, big, tstr)
    local tx = x + pad
    local ty = y + 42 * s
    glow_text(font_temp, big, tstr, Vec2(tx, ty), accent, accent, 14)
    soft_text(font_text, math.floor(11 * s * g_ts), state.desc, Vec2(tx, ty + tsz.y + 4 * s), st.dim)
    draw_icon(state.cat, x + w - pad - 16 * s, ty + 14 * s, s * 0.74, state.is_day, st.bg, now * 0.6)
    if state.t_max then
        local hl = ("H %d\u{00b0}  L %d\u{00b0}"):format(math.floor((conv_temp(state.t_max) or 0) + 0.5), math.floor((conv_temp(state.t_min) or 0) + 0.5))
        local hsz = Render.TextSize(font_text, math.floor(11 * s * g_ts), hl)
        soft_text(font_text, math.floor(11 * s * g_ts), hl, Vec2(x + w - pad - hsz.x, ty + 34 * s), st.dim)
    end
    if mode ~= 0 then
        local m = metric_list()
        local ry = ty + tsz.y + 22 * s
        local bottom = (y + h - fb) - (mode == 2 and 52 * s or 6 * s)
        local rh = math.max(15 * s, math.min(20 * s, (bottom - ry) / #m))
        for _, it in ipairs(m) do
            Render.Line(Vec2(x + pad, ry + 7 * s), Vec2(x + pad + 12 * s, ry + 7 * s), accent, 1.0)
            soft_text(font_text, math.floor(11 * s * g_ts), it[1], Vec2(x + pad + 18 * s, ry), st.dim)
            local vsz = Render.TextSize(font_text, math.floor(11 * s * g_ts), it[2])
            soft_text(font_text, math.floor(11 * s * g_ts), it[2], Vec2(x + w - pad - vsz.x, ry), st.text)
            ry = ry + rh
        end
    end
    if mode == 2 and #state.hourly > 0 then
        draw_hourly(x, y, w, h, s, pad, st, now, (h - fb) / s - 52)
    end
end

local function layout_ticket(x, y, w, h, s, mode, st, accent, tstr, temp_col, now)
    local pad = 16 * s
    local stub_w = 104 * s
    local sx = x + w - stub_w
    local fb = (ui.show_status:Get() and state.fetched_clock) and 16 * s or 6 * s
    Render.FilledRect(Vec2(sx, y), Vec2(x + w, y + h), st.stub)
    Render.FilledCircle(Vec2(sx, y), 5 * s, st.bg)
    Render.FilledCircle(Vec2(sx, y + h), 5 * s, st.bg)
    local dy = y + 8 * s
    while dy < y + h - 8 * s do Render.Line(Vec2(sx, dy), Vec2(sx, dy + 4 * s), st.bg, 2.0); dy = dy + 9 * s end
    soft_text(font_text, math.floor(10 * s * g_ts), (ui.lang_ru:Get() and "СВОДКА ПОГОДЫ" or "WEATHER PASS"), Vec2(x + pad, y + 12 * s), st.faint)
    glow_text(font_city, math.floor(17 * s * g_ts), state.city, Vec2(x + pad, y + 26 * s), st.text, accent, 0)
    Render.Line(Vec2(x + pad, y + 50 * s), Vec2(sx - 14 * s, y + 50 * s), st.dash, 1.0)
    if not tstr then
        soft_text(font_text, math.floor(12 * s * g_ts), state.error or "Загрузка...", Vec2(x + pad, y + 62 * s), accent)
        return
    end
    draw_icon(state.cat, x + pad + 16 * s, y + 80 * s, s * 0.82, state.is_day, st.bg, now * 0.6)
    soft_text(font_text, math.floor(12 * s * g_ts), state.desc, Vec2(x + pad + 44 * s, y + 64 * s), st.dim)
    local left_w = sx - x - pad - 14 * s
    if mode ~= 0 then
        local m = metric_list()
        local ry = y + 100 * s
        for _, it in ipairs(m) do
            soft_text(font_text, math.floor(10 * s * g_ts), it[1], Vec2(x + pad, ry), st.faint)
            local vsz = Render.TextSize(font_text, math.floor(12 * s * g_ts), it[2])
            soft_text(font_text, math.floor(12 * s * g_ts), it[2], Vec2(sx - 14 * s - vsz.x, ry), st.text)
            ry = ry + 17 * s
        end
    end
    local stub_text = Color(244, 241, 232, 255)
    local big = math.floor(30 * s * g_ts)
    local tsz = Render.TextSize(font_temp, big, tstr)
    Render.Text(font_temp, big, tstr, Vec2(sx + (stub_w - tsz.x) * 0.5, y + 22 * s), stub_text)
    if state.t_max then
        local hl = ("%d\u{00b0}/%d\u{00b0}"):format(math.floor((conv_temp(state.t_max) or 0) + 0.5), math.floor((conv_temp(state.t_min) or 0) + 0.5))
        local hsz = Render.TextSize(font_text, math.floor(11 * s * g_ts), hl)
        soft_text(font_text, math.floor(11 * s * g_ts), hl, Vec2(sx + (stub_w - hsz.x) * 0.5, y + 22 * s + tsz.y + 4 * s), accent)
    end
    draw_icon(state.cat, sx + stub_w * 0.5, y + h - 42 * s, s * 0.6, state.is_day, st.stub, now * 0.6)
    local bcx = sx + 10 * s
    local bcw = stub_w - 20 * s
    local bcy = y + h - 22 * s
    local seed = #state.city + math.floor((conv_temp(state.temp) or 0))
    local bx = bcx
    local k = 0
    while bx < bcx + bcw do
        k = k + 1
        local bw = (((seed + k * 7) % 3) + 1) * s
        if k % 2 == 1 then
            local sh = (now > 0) and (0.7 + 0.3 * math.sin(now * 3 + k)) or 1
            Render.FilledRect(Vec2(bx, bcy), Vec2(bx + bw, bcy + 12 * s), alpha(stub_text, math.floor(200 * sh)))
        end
        bx = bx + bw + 1.5 * s
    end
    if mode == 2 and #state.hourly > 0 then
        local syy = y + h - fb - 44 * s
        Render.Line(Vec2(x + pad, syy - 10 * s), Vec2(sx - 14 * s, syy - 10 * s), st.dash, 1.0)
        local n = #state.hourly
        local cw = left_w / n
        for i, hr in ipairs(state.hourly) do
            local cx = x + pad + (i - 0.5) * cw
            local hh2 = ("%02d"):format(hr.h)
            local hsz2 = Render.TextSize(font_text, math.floor(9 * s * g_ts), hh2)
            soft_text(font_text, math.floor(9 * s * g_ts), hh2, Vec2(cx - hsz2.x / 2, syy), st.faint)
            draw_icon(hr.cat, cx, syy + 20 * s, s * 0.34, true, st.bg, now * 0.6)
            local tt = ("%d\u{00b0}"):format(math.floor((conv_temp(hr.temp) or 0) + 0.5))
            local tsz3 = Render.TextSize(font_text, math.floor(10 * s * g_ts), tt)
            soft_text(font_text, math.floor(10 * s * g_ts), tt, Vec2(cx - tsz3.x / 2, syy + 30 * s), st.text)
        end
    end
end

local LAYOUTS = { glass = layout_glass, imgui = layout_imgui, figma = layout_figma, neon = layout_neon, station = layout_station, radial = layout_aurora, bento = layout_bento, blueprint = layout_blueprint, ticket = layout_ticket }

local function draw_widget()
    local x, y, w, h, s, mode = get_rect()
    local pad = 14 * s
    local accent = accent_color()
    local st = get_style(accent)
    if st.accent_override then accent = st.accent_override end
    local round = st.round * s
    local eff_shadow = st.shadow and ui.shadow:Get()
    local temp_col = st.accent_text and tint(st.text, accent, 0.40) or st.text

    local now = os.clock()
    local dt = math.min(0.05, now - (state.last_draw or now))
    state.last_draw = now
    g_ts = ui.textsize:Get() / 100
    apply_fonts()
    local anow = ui.animations:Get() and now or 0

    local p1, p2 = Vec2(x, y), Vec2(x + w, y + h)

    if eff_shadow then Render.Shadow(p1, p2, col_shadow, 30 * s, round) end
    Render.FilledRect(p1, p2, st.bg, round)
    if ui.animations:Get() and state.loaded then
        local sweep = (anow * 0.28) % 1.5 - 0.25
        if sweep >= 0 and sweep <= 1 then
            local hx = x + w * sweep
            Render.FilledRect(Vec2(math.max(x + round, hx - 26 * s), y + 1), Vec2(math.min(x + w - round, hx + 26 * s), y + 2.5 * s), alpha(accent, 70))
        end
    end
    update_particles(x, y, w, h, dt)

    if not st.full then

    local title_y = y + 8 * s
    if st.header == "gradient" then
        draw_vgrad(x + 1, y + 2, w - 2, 42 * s, accent, 32, 0, 12)
        Render.FilledRect(Vec2(x + round, y), Vec2(x + w - round, y + 2 * s), col_top)
    elseif st.header == "neon" then
        draw_vgrad(x + 1, y + 2, w - 2, 46 * s, accent, 64, 0, 14)
    elseif st.header == "bar" then
        local bh = 28 * s
        Render.FilledRect(Vec2(x, y), Vec2(x + w, y + bh), st.bar)
        Render.Line(Vec2(x, y + bh), Vec2(x + w, y + bh), Color(0, 0, 0, 160), 1.0)
        caret(x + pad + 4 * s, y + 15 * s, 4 * s, false, st.text, 1.6)
        local cbx, cby = x + w - 20 * s, y + 8 * s
        Render.Rect(Vec2(cbx, cby), Vec2(cbx + 12 * s, cby + 12 * s), alpha(st.text, 110), 0, Enum.DrawFlags.None, 1.0)
        Render.Line(Vec2(cbx + 3 * s, cby + 3 * s), Vec2(cbx + 9 * s, cby + 9 * s), st.text, 1.4)
        Render.Line(Vec2(cbx + 9 * s, cby + 3 * s), Vec2(cbx + 3 * s, cby + 9 * s), st.text, 1.4)
        title_y = y + 7 * s
    elseif st.header == "underline" then
        Render.FilledRect(Vec2(x + round, y), Vec2(x + w - round, y + 2 * s), Color(255, 255, 255, 10))
    end

    if st.glow then
        for gi = 4, 1, -1 do
            Render.Rect(Vec2(x - gi, y - gi), Vec2(x + w + gi, y + h + gi),
                alpha(accent, math.floor(46 / gi)), round + gi, Enum.DrawFlags.None, 2.0)
        end
    end
    do
        local bcol = drag.active and alpha(accent, 210) or st.border
        Render.Rect(p1, p2, bcol, round, Enum.DrawFlags.None, drag.active and 1.6 or st.border_w)
    end
    if st.brackets then corner_brackets(x, y, w, h, 13 * s, accent, 1.6) end

    local city_sz = Render.TextSize(font_city, math.floor(18 * s * g_ts), state.city)
    local title_x = x + pad + ((st.key == "imgui") and 16 * s or 0)
    if st.key == "neon" then title_x = x + (w - city_sz.x) * 0.5 end
    glow_text(font_city, math.floor(18 * s * g_ts), state.city, Vec2(title_x, title_y), st.text,
        st.glow and accent or nil, st.glow and 30 or 14)
    if st.key == "glass" or st.key == "figma" then
        local ulw = (st.key == "figma") and city_sz.x or 46 * s
        Render.Line(Vec2(title_x, y + 30 * s), Vec2(title_x + ulw, y + 30 * s), accent, 1.5)
    end

    if not state.loaded then
        soft_text(font_text, math.floor(12 * s * g_ts), state.error or "Загрузка...",
            Vec2(x + pad, y + 40 * s), state.error and accent or st.dim)
        return
    end

    local target_t = conv_temp(state.temp) or 0
    if state.disp_temp == nil then state.disp_temp = target_t end
    state.disp_temp = state.disp_temp + (target_t - state.disp_temp) * math.min(1, dt * 6)
    local tstr = ("%d%s"):format(math.floor(state.disp_temp + 0.5), temp_unit())

    if ui.show_clock:Get() then
        if st.key == "imgui" then
            draw_clock(x + pad, y + 33 * s, w - pad * 2 - 22 * s, s, st, "right")
        elseif st.key == "neon" then
            draw_clock(x, y + 8 * s, w - pad, s, st, "right")
        elseif st.key == "figma" then
            draw_clock(x, y + 9 * s, w - pad, s, st, "right")
        else
            draw_clock(x + pad, y + 33 * s, w, s, st, "left")
        end
    end

    if mode == 0 then
        soft_text(font_text, math.floor(11 * s * g_ts), state.desc, Vec2(x + pad, y + 50 * s), st.dim)
        local big = math.floor(26 * s * g_ts)
        local tsz = Render.TextSize(font_temp, big, tstr)
        local tx = x + w - pad - tsz.x
        local ty = y + (h - tsz.y) * 0.5 + 6 * s
        draw_icon(state.cat, tx - 20 * s, ty + tsz.y * 0.5, s * 0.78, state.is_day, st.bg, anow * 0.6)
        Render.Text(font_temp, big, tstr, Vec2(tx, ty), temp_col)
        return
    end

    if st.key ~= "glass" then
        local fn = LAYOUTS[st.key] or layout_glass
        fn(x, y, w, h, s, mode, st, accent, tstr, temp_col, anow)
    else

    soft_text(font_text, math.floor(12 * s * g_ts), state.desc, Vec2(x + pad, y + 49 * s), st.dim)

    local big = math.floor(30 * s * g_ts)
    local tsz = Render.TextSize(font_temp, big, tstr)
    local temp_x, temp_y = x + pad + 44 * s, y + 70 * s
    draw_icon(state.cat, x + pad + 14 * s, y + 84 * s, s, state.is_day, st.bg, anow * 0.6)
    glow_text(font_temp, big, tstr, Vec2(temp_x, temp_y), temp_col, nil, 20 + 8 * math.sin(anow * 2.2))

    if ui.show_hilo:Get() then
        local hx = math.min(temp_x + tsz.x + 30 * s, x + w * 0.60 - 36 * s)
        draw_hilo(hx, y + 66 * s, s, st)
    end

    Render.Line(Vec2(x + w * 0.60, y + 16 * s), Vec2(x + w * 0.60, y + 88 * s), st.divider, 1.0)
    draw_metrics(x, y, w, s, pad, st)

    if mode == 2 then
        local row_y = y + 100 * s
        if ui.show_sun:Get() and state.sunrise then
            local fs = math.floor(11 * s * g_ts)
            local sx = x + pad
            draw_sun_h(sx + 7 * s, row_y + 4 * s, s, true)
            local srt = hhmm(state.sunrise)
            soft_text(font_text, fs, srt, Vec2(sx + 20 * s, row_y), st.dim)
            local srw = Render.TextSize(font_text, fs, srt).x
            local sx2 = sx + 20 * s + srw + 18 * s
            draw_sun_h(sx2 + 7 * s, row_y + 4 * s, s, false)
            soft_text(font_text, fs, hhmm(state.sunset), Vec2(sx2 + 20 * s, row_y), st.dim)
        end
        if ui.show_extra:Get() and state.pressure then
            local pr = ("%d гПа"):format(math.floor((state.pressure or 0) + 0.5))
            local uvv = ("UV %.0f"):format(state.uv or 0)
            local full = pr .. "   " .. uvv
            local sz = Render.TextSize(font_text, math.floor(11 * s * g_ts), full)
            local bx = x + w - pad - sz.x
            draw_marker(bx - 8 * s, row_y + 6 * s, dot_press, st, s)
            soft_text(font_text, math.floor(11 * s * g_ts), full, Vec2(bx, row_y), st.dim)
        end

        local strip_top = y + 122 * s
        if st.strip_card == "none" then
            Render.Line(Vec2(x + pad, strip_top - 6 * s), Vec2(x + w - pad, strip_top - 6 * s), st.divider, 1.0)
        end

        if ui.show_hourly:Get() and #state.hourly > 0 then
            local n = #state.hourly
            local col_w = (w - pad * 2) / n
            for i, hr in ipairs(state.hourly) do
                local cx = x + pad + (i - 0.5) * col_w

                if st.strip_card == "round" or st.strip_card == "square" then
                    local cr = (st.strip_card == "round") and 6 * s or 0
                    local hw = col_w * 0.5 - 2 * s
                    local cp1 = Vec2(cx - hw, strip_top - 2 * s)
                    local cp2 = Vec2(cx + hw, y + h - 24 * s)
                    Render.FilledRect(cp1, cp2, st.strip_fill or Color(255, 255, 255, 8), cr)
                    if st.strip_border then
                        Render.Rect(cp1, cp2, st.strip_border, cr, Enum.DrawFlags.None, 1.0)
                    end
                end
                local day_h = true
                if state.sunrise and state.sunset then
                    day_h = hr.h >= hour_of(state.sunrise) and hr.h < hour_of(state.sunset)
                end
                local hl = ("%02d"):format(hr.h)
                local hsz = Render.TextSize(font_text, math.floor(10 * s * g_ts), hl)
                soft_text(font_text, math.floor(10 * s * g_ts), hl, Vec2(cx - hsz.x / 2, strip_top), st.dim)
                draw_icon(hr.cat, cx, strip_top + 26 * s + (anow > 0 and math.sin(anow * 2.0 + i * 0.7) * 1.6 * s or 0), s * 0.44, day_h, st.bg, anow * 0.6)
                local tt = ("%d\u{00b0}"):format(math.floor((conv_temp(hr.temp) or 0) + 0.5))
                local tsz2 = Render.TextSize(font_text, math.floor(11 * s * g_ts), tt)
                soft_text(font_text, math.floor(11 * s * g_ts), tt, Vec2(cx - tsz2.x / 2, strip_top + 42 * s), st.text)
                if hr.pop and hr.pop >= 30 then
                    local pl = ("%d%%"):format(hr.pop)
                    local psz = Render.TextSize(font_text, math.floor(9 * s * g_ts), pl)
                    local pa = (anow > 0) and (0.65 + 0.35 * math.abs(math.sin(anow * 2.0 + i))) or 1
                    soft_text(font_text, math.floor(9 * s * g_ts), pl, Vec2(cx - psz.x / 2, strip_top + 56 * s), alpha(dot_precip, math.floor(255 * pa)))
                end
            end
        end
    end
    end
    else

        if state.loaded then
            local target_t = conv_temp(state.temp) or 0
            if state.disp_temp == nil then state.disp_temp = target_t end
            state.disp_temp = state.disp_temp + (target_t - state.disp_temp) * math.min(1, dt * 6)
        end
        local tstr_f = state.loaded and ("%d%s"):format(math.floor(state.disp_temp + 0.5), temp_unit()) or nil
        local fn = LAYOUTS[st.key]
        if fn then fn(x, y, w, h, s, mode, st, accent, tstr_f, temp_col, anow) end
    end

    if ui.show_status:Get() and state.fetched_clock then
        local interval  = ui.refresh:Get() * 60
        local remaining = math.max(0, interval - (os.clock() - state.last_pull))
        local status = ("%s \u{00b7} обн. %s \u{00b7} через %s"):format(
            state.source or "Open-Meteo", fmt_ago(os.clock() - state.fetched_clock), fmt_secs(remaining))
        local sz = Render.TextSize(font_text, math.floor(10 * s * g_ts), status)
        local stx = (st.key == "ticket") and (x + pad) or (x + w - pad - sz.x)
        soft_text(font_text, math.floor(10 * s * g_ts), status, Vec2(stx, y + h - 14 * s), st.faint)
    end

    if Menu.Opened() and not ui.lock:Get() then
        local hint = drag.active and "перетаскивание..." or "ЛКМ — перетащить"
        soft_text(font_text, math.floor(10 * s * g_ts), hint, Vec2(x + pad, y + h + 3 * s), st.faint)
    end

end

local function draw_siren(cx, cy, r, col)
    tri_fill(cx - r, cy + r * 0.78, cx + r, cy + r * 0.78, cx, cy - r, col)
    Render.Line(Vec2(cx, cy - r * 0.18), Vec2(cx, cy + r * 0.30), Color(28, 24, 24, 255), math.max(2.0, r * 0.16))
    Render.FilledCircle(Vec2(cx, cy + r * 0.50), math.max(1.4, r * 0.10), Color(28, 24, 24, 255))
end

local WARN_DUR = 5.0

local function draw_warn_icon(cx, cy, r, aa)
    tri_fill(cx, cy - r, cx - r * 0.92, cy + r * 0.82, cx + r * 0.92, cy + r * 0.82, Color(255, 196, 72, aa))
    tri_fill(cx, cy - r + 2.4, cx - r * 0.64, cy + r * 0.56, cx + r * 0.64, cy + r * 0.56, Color(120, 78, 14, aa))
    Render.Line(Vec2(cx, cy - r * 0.26), Vec2(cx, cy + r * 0.22), Color(255, 224, 158, aa), 2.2)
    Render.FilledCircle(Vec2(cx, cy + r * 0.45), 1.6, Color(255, 224, 158, aa))
end

local function draw_check(cx, cy, r, col)
    Render.Line(Vec2(cx - r, cy + r * 0.1), Vec2(cx - r * 0.2, cy + r * 0.75), col, 2.6)
    Render.Line(Vec2(cx - r * 0.2, cy + r * 0.75), Vec2(cx + r, cy - r * 0.7), col, 2.6)
end

local function draw_rocket(cx, cy, r, aa, cr, cg, cb)
    local body = Color(cr, cg, cb, aa)
    tri_fill(cx, cy - r, cx - r * 0.5, cy - r * 0.05, cx + r * 0.5, cy - r * 0.05, body)
    Render.FilledRect(Vec2(cx - r * 0.42, cy - r * 0.05), Vec2(cx + r * 0.42, cy + r * 0.55), body, 1.5)
    tri_fill(cx - r * 0.48, cy + r * 0.55, cx + r * 0.48, cy + r * 0.55, cx, cy + r * 1.15, Color(255, 150, 60, aa))
end

local function draw_notif(now, s, sw, sh)
    if not (alarm.notif_at and alarm.notif_kind) then return end
    local t = now - alarm.notif_at
    if t < 0 or t > NOTIF_DUR then return end
    local style = NOTIF_STYLE[alarm.notif_kind] or NOTIF_STYLE.bpla
    local L = ui.lang_ru:Get()
    local title = L and style.title or style.en
    local region = alarm.notif_region or ""
    local cause = alarm.notif_cause or ""
    if alarm.notif_kind == "clear" then
        cause = ""
    elseif cause == "" then
        cause = CAUSE_FALLBACK[alarm.notif_kind] or ""
    end
    local fin = math.min(1, t / 0.22)
    local fout = math.min(1, (NOTIF_DUR - t) / 0.55)
    local fade = math.max(0, math.min(fin, fout))
    local function A(v) return math.floor(v * fade) end
    local cr, cg, cb = style.col[1], style.col[2], style.col[3]
    local fts = math.floor(15 * s * g_ts)
    local fcs = math.floor(10 * s * g_ts)
    local frs = math.floor(11 * s * g_ts)
    local has_cause = cause ~= ""
    local causetx = has_cause and ("(" .. cause .. ")") or ""
    local tw = Render.TextSize(font_city, fts, title).x
    local cw = has_cause and Render.TextSize(font_text, fcs, causetx).x or 0
    local rw = Render.TextSize(font_text, frs, region).x
    local icon_w = 46 * s
    local bw = math.floor(icon_w + math.max(tw, cw, rw) + 18 * s)
    bw = math.max(bw, math.floor(150 * s))
    bw = math.min(bw, math.floor(sw - 40 * s))
    local maxtw = bw - icon_w - 12 * s
    local function fit(font, sz, str)
        if maxtw <= 0 or str == "" then return str end
        if Render.TextSize(font, sz, str).x <= maxtw then return str end
        local b = #str
        while b > 1 do
            b = b - 1
            local nb = str:byte(b + 1)
            if not (nb and nb >= 128 and nb < 192) then
                local cut = str:sub(1, b) .. "…"
                if Render.TextSize(font, sz, cut).x <= maxtw then return cut end
            end
        end
        return str
    end
    title = fit(font_city, fts, title)
    causetx = has_cause and fit(font_text, fcs, causetx) or ""
    region = fit(font_text, frs, region)
    local bh = math.floor((has_cause and 68 or 52) * s)
    local bx = math.floor((sw - bw) * 0.5)
    local by = math.floor((26 - 10 * (1 - fin)) * s)
    local pulse = 0.5 + 0.5 * math.sin(now * 5.0)
    if alarm.notif_kind ~= "clear" and ui.alarm_flash:Get() and sh then
        local fa = A(math.floor(20 + 30 * pulse))
        local edge = 6 * s
        Render.FilledRect(Vec2(0, 0), Vec2(sw, edge), Color(cr, cg, cb, fa))
        Render.FilledRect(Vec2(0, sh - edge), Vec2(sw, sh), Color(cr, cg, cb, fa))
        Render.FilledRect(Vec2(0, 0), Vec2(edge, sh), Color(cr, cg, cb, fa))
        Render.FilledRect(Vec2(sw - edge, 0), Vec2(sw, sh), Color(cr, cg, cb, fa))
    end
    pcall(function() Render.Shadow(Vec2(bx, by), Vec2(bx + bw, by + bh), Color(0, 0, 0, A(150)), 22 * s, 12 * s) end)
    Render.FilledRect(Vec2(bx, by), Vec2(bx + bw, by + bh), Color(math.floor(cr * 0.16) + 16, math.floor(cg * 0.16) + 14, math.floor(cb * 0.16) + 12, A(240)), 12 * s)
    Render.FilledRect(Vec2(bx + 3 * s, by + 1.5 * s), Vec2(bx + bw - 3 * s, by + 4 * s), Color(255, 255, 255, A(16)), 8 * s)
    Render.FilledRect(Vec2(bx, by + 9 * s), Vec2(bx + 5 * s, by + bh - 9 * s), Color(cr, cg, cb, A(math.floor(150 + 90 * pulse))), 3 * s)
    Render.Rect(Vec2(bx, by), Vec2(bx + bw, by + bh), Color(cr, cg, cb, A(220)), 12 * s, Enum.DrawFlags.None, 1.5)
    local icx, icy = bx + 28 * s, by + bh * 0.46
    Render.FilledCircle(Vec2(icx, icy), (16 + 2 * pulse) * s, Color(cr, cg, cb, A(math.floor(26 + 26 * pulse))))
    Render.FilledCircle(Vec2(icx, icy), 13 * s, Color(cr, cg, cb, A(58)))
    if style.icon == "check" then
        draw_check(icx, icy, 9 * s, Color(cr, cg, cb, A(255)))
    elseif style.icon == "rocket" then
        draw_rocket(icx, icy, 11 * s, A(255), cr, cg, cb)
    else
        draw_warn_icon(icx, icy, 12 * s, A(255))
    end
    local textx = bx + icon_w + 4 * s
    if has_cause then
        glow_text(font_city, fts, title, Vec2(textx, by + 8 * s), Color(255, 255, 255, A(255)), Color(cr, cg, cb, A(255)), 16)
        soft_text(font_text, fcs, causetx, Vec2(textx, by + 27 * s), Color(math.min(255, cr + 45), math.min(255, cg + 45), math.min(255, cb + 45), A(245)))
        soft_text(font_text, frs, region, Vec2(textx, by + 43 * s), Color(235, 235, 235, A(235)))
    else
        glow_text(font_city, fts, title, Vec2(textx, by + 8 * s), Color(255, 255, 255, A(255)), Color(cr, cg, cb, A(255)), 16)
        soft_text(font_text, frs, region, Vec2(textx, by + 28 * s), Color(235, 235, 235, A(235)))
    end
    local frac = math.max(0, 1 - t / NOTIF_DUR)
    Render.FilledRect(Vec2(bx + 12 * s, by + bh - 7 * s), Vec2(bx + bw - 12 * s, by + bh - 4.5 * s), Color(255, 255, 255, A(45)), 2 * s)
    Render.FilledRect(Vec2(bx + 12 * s, by + bh - 7 * s), Vec2(bx + 12 * s + (bw - 24 * s) * frac, by + bh - 4.5 * s), Color(cr, cg, cb, A(255)), 2 * s)
end

local function status_plate(now, s, sw, icon, line1, line2, col, pulsing)
    local cr, cg, cb = col[1], col[2], col[3]
    local fts = math.floor(14 * s * g_ts)
    local fcs = math.floor(11 * s * g_ts)
    local has2 = line2 ~= nil and line2 ~= ""
    local icon_w = 40 * s
    local function fit(font, sz, str, maxtw)
        if Render.TextSize(font, sz, str).x <= maxtw then return str end
        local b = #str
        while b > 1 do
            b = b - 1
            local nb = str:byte(b + 1)
            if not (nb and nb >= 128 and nb < 192) then
                local cut = str:sub(1, b) .. "…"
                if Render.TextSize(font, sz, cut).x <= maxtw then return cut end
            end
        end
        return str
    end
    local maxw = math.floor(440 * s)
    local t1w = Render.TextSize(font_city, fts, line1).x
    local t2w = has2 and Render.TextSize(font_text, fcs, line2).x or 0
    local bw = math.min(maxw, math.floor(icon_w + math.max(t1w, t2w) + 24 * s))
    local maxtw = bw - icon_w - 14 * s
    line1 = fit(font_city, fts, line1, maxtw)
    if has2 then line2 = fit(font_text, fcs, line2, maxtw) end
    local bh = math.floor((has2 and 50 or 38) * s)
    local bx, by
    if ui.alarm_move:Get() then
        bx = math.floor(ui.alarm_px:Get())
        by = math.floor(ui.alarm_py:Get())
    else
        bx = math.floor((sw - bw) * 0.5)
        by = math.floor(26 * s)
    end
    local pulse = pulsing and (0.5 + 0.5 * math.sin(now * 4.0)) or 0
    pcall(function() Render.Shadow(Vec2(bx, by), Vec2(bx + bw, by + bh), Color(0, 0, 0, 150), 20 * s, 10 * s) end)
    Render.FilledRect(Vec2(bx, by), Vec2(bx + bw, by + bh), Color(math.floor(cr * 0.14) + 16, math.floor(cg * 0.14) + 15, math.floor(cb * 0.14) + 13, 238), 11 * s)
    Render.FilledRect(Vec2(bx + 3 * s, by + 1.5 * s), Vec2(bx + bw - 3 * s, by + 4 * s), Color(255, 255, 255, 15), 8 * s)
    Render.FilledRect(Vec2(bx, by + 8 * s), Vec2(bx + 5 * s, by + bh - 8 * s), Color(cr, cg, cb, math.floor(150 + 90 * pulse)), 3 * s)
    Render.Rect(Vec2(bx, by), Vec2(bx + bw, by + bh), Color(cr, cg, cb, 210), 11 * s, Enum.DrawFlags.None, 1.4)
    local flash = 0
    if alarm.flash_at then
        local fdur = alarm.flash_manual and 2.6 or 1.4
        local el = now - alarm.flash_at
        if el >= 0 and el < fdur then flash = 1 - (el / fdur) end
    end
    if flash > 0 then
        local exp = (1 - flash) * 8 * s
        pcall(function() Render.Rect(Vec2(bx - exp, by - exp), Vec2(bx + bw + exp, by + bh + exp), Color(cr, cg, cb, math.floor(165 * flash)), 11 * s + exp, Enum.DrawFlags.None, 1.6) end)
        Render.Rect(Vec2(bx, by), Vec2(bx + bw, by + bh), Color(255, 255, 255, math.floor(55 * flash)), 11 * s, Enum.DrawFlags.None, 1.4)
    end
    local icx, icy = bx + 22 * s, by + bh * 0.5
    Render.FilledCircle(Vec2(icx, icy), (14 + 2 * pulse) * s, Color(cr, cg, cb, math.floor(24 + 24 * pulse)))
    Render.FilledCircle(Vec2(icx, icy), 12 * s, Color(cr, cg, cb, 56))
    if icon == "check" then
        draw_check(icx, icy, 8 * s, Color(cr, cg, cb, 255))
    elseif icon == "rocket" then
        draw_rocket(icx, icy, 10 * s, 255, cr, cg, cb)
    elseif icon == "dots" then
        for i = 0, 2 do
            local a = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(now * 6.0 - i * 0.7))
            Render.FilledCircle(Vec2(icx + (i - 1) * 6 * s, icy), 2.3 * s, Color(255, 255, 255, math.floor(255 * a)))
        end
    else
        draw_warn_icon(icx, icy, 11 * s, 255)
    end
    local textx = bx + icon_w
    if has2 then
        glow_text(font_city, fts, line1, Vec2(textx, by + 7 * s), Color(255, 255, 255, 255), Color(cr, cg, cb, 255), 14)
        soft_text(font_text, fcs, line2, Vec2(textx, by + 28 * s), Color(225, 225, 228, 235))
    else
        glow_text(font_city, fts, line1, Vec2(textx, by + (bh - fts) * 0.5 - 1 * s), Color(255, 255, 255, 255), Color(cr, cg, cb, 255), 14)
    end
    alarm.rect = { x = bx, y = by, w = bw, h = bh }
    if adrag.active then
        Render.Rect(Vec2(bx - 2 * s, by - 2 * s), Vec2(bx + bw + 2 * s, by + bh + 2 * s), Color(255, 255, 255, 185), 12 * s, Enum.DrawFlags.None, 1.6)
    end
end

local ALARM_HIDE_SECS = { 0, 5, 10, 15, 30, 60 }
local function draw_alarm()
    if not ui.alarm_enable:Get() then return end
    local now = os.clock()
    g_ts = ui.textsize:Get() / 100
    apply_fonts()
    local s = ui.scale:Get()
    local sw, sh = screen_size()

    draw_notif(now, s, sw, sh)

    if not ui.alarm_status:Get() then return end
    if alarm.notif_at and (now - alarm.notif_at) <= NOTIF_DUR then return end

    local active = alarm.cur and alarm.cur ~= "clear"
    local busy = alarm.checking or (alarm.loading and not alarm.last_ok)
    if not (active or busy or adrag.active) then
        local hs = ALARM_HIDE_SECS[cget(ui.alarm_hide) + 1] or 0
        if hs > 0 and alarm.flash_at and (now - alarm.flash_at) > hs then return end
    end

    if alarm.checking or (alarm.loading and not alarm.last_ok) then
        status_plate(now, s, sw, "dots", "Проверка тревоги…", nil, { 90, 150, 230 }, true)
    elseif alarm.error then
        status_plate(now, s, sw, "warn", alarm.error, "Повтор проверки…", { 222, 170, 80 }, false)
    elseif alarm.cur and alarm.cur ~= "clear" then
        local st = NOTIF_STYLE[alarm.cur_kind] or NOTIF_STYLE.bpla
        local line2 = alarm.cur_region or ""
        if alarm.cur_cause and alarm.cur_cause ~= "" then
            line2 = (line2 ~= "" and (alarm.cur_cause .. " · " .. line2)) or alarm.cur_cause
        end
        status_plate(now, s, sw, st.icon, st.title, line2, st.col, true)
    elseif alarm.last_ok then
        status_plate(now, s, sw, "check", "Нет ��грозы", alarm.cur_region, { 60, 200, 120 }, false)
    else
        status_plate(now, s, sw, "dots", "Ожидание данных…", nil, { 130, 140, 160 }, true)
    end
end

local function poll_alarm()
    if not ui.alarm_enable:Get() then return end
    local now = os.clock()
    if alarm.loading then
        if (now - (alarm.load_at or now)) > 20 then
            alarm.loading = false
            alarm.checking = false
            if not alarm.last_ok then alarm.error = "Таймаут запроса" end
        else
            return
        end
    end
    local base = math.max(10, ui.alarm_refresh:Get())
    local interval = base
    if alarm.cur and alarm.cur ~= "clear" then interval = math.min(base, 15) end
    if alarm.error then interval = math.min(base, 12) end
    if (now - alarm.last_pull) >= interval then
        alarm.last_pull = now
        alarm.load_at = now
        alarm.loading, alarm.error = true, nil
        pcall(fetch_alarms, 1)
    end
end

function widget.OnUpdate()
    poll_alarm()
    handle_alarm_drag()
    if state.loading and state.load_at and (os.clock() - state.load_at) > 45 then
        state.loading = false
        state.error = state.error or "Таймаут запроса"
        dbg.stats.err = dbg.stats.err + 1
        dbg.log("ERR", "Таймаут: источник не ответил за 45 c (маршрут завис)")
    end
    if not ui.enabled:Get() then return end
    handle_drag()
    if (os.clock() - state.last_pull) >= ui.refresh:Get() * 60 then
        state.last_pull = os.clock()
        pull_weather()
    end
end

local DBG_COL = {
    INFO = { 205, 214, 228 },
    OK   = { 110, 210, 140 },
    WARN = { 235, 190, 90 },
    ERR  = { 240, 110, 110 },
    REQ  = { 120, 170, 240 },
}
local function dbg_fit(str, fs, maxw)
    if Render.TextSize(font_text, fs, str).x <= maxw then return str end
    local b = #str
    while b > 1 do
        b = b - 1
        local nb = str:byte(b + 1)
        if not (nb and nb >= 128 and nb < 192) then
            local cut = str:sub(1, b) .. "…"
            if Render.TextSize(font_text, fs, cut).x <= maxw then return cut end
        end
    end
    return str
end
local function draw_debug()
    g_ts = ui.textsize:Get() / 100
    apply_fonts()
    local _, sh = screen_size()
    local n = math.floor((ui.debug_lines:Get() or 14) + 0.5)
    local fs, hs = 13, 14
    local pad, lineh, headerh = 10, 16, 60
    local w = 560
    local h = headerh + n * lineh + pad
    local x = 20
    local y = math.max(20, sh - h - 20)
    Render.FilledRect(Vec2(x, y), Vec2(x + w, y + h), Color(12, 15, 22, 236), 8)
    Render.Rect(Vec2(x, y), Vec2(x + w, y + h), Color(80, 120, 200, 220), 8, Enum.DrawFlags.None, 1.4)
    Render.FilledRect(Vec2(x, y), Vec2(x + w, y + 24), Color(36, 64, 120, 245), 8)
    soft_text(font_city, hs, "PogodaUI · DEBUG", Vec2(x + pad, y + 5), Color(235, 240, 250, 255))
    local stat = ("req %d · ok %d · err %d"):format(dbg.stats.req, dbg.stats.ok, dbg.stats.err)
    local stsz = Render.TextSize(font_text, fs, stat)
    soft_text(font_text, fs, stat, Vec2(x + w - pad - stsz.x, y + 6), Color(175, 195, 225, 255))
    local l2 = ("источник: %s    загрузка: %s    ошибка: %s"):format(
        tostring(state.source or "—"), state.loading and "да" or "нет", tostring(state.error or "—"))
    soft_text(font_text, fs, dbg_fit(l2, fs, w - 2 * pad), Vec2(x + pad, y + 28), Color(195, 205, 220, 255))
    local l3 = ("город: %s    t=%s    обновлено: %s"):format(
        tostring(state.city or "—"),
        state.temp ~= nil and (math.floor(state.temp + 0.5) .. "°C") or "—",
        state.fetched_clock and fmt_ago(os.clock() - state.fetched_clock) or "—")
    soft_text(font_text, fs, dbg_fit(l3, fs, w - 2 * pad), Vec2(x + pad, y + 43), Color(150, 165, 185, 255))
    Render.Line(Vec2(x + pad, y + headerh - 2), Vec2(x + w - pad, y + headerh - 2), Color(255, 255, 255, 28), 1)
    local total = #dbg.lines
    if total == 0 then
        soft_text(font_text, fs, "лог пуст — нажмите «Принудительно обновить погоду»", Vec2(x + pad, y + headerh), Color(140, 150, 165, 255))
        return
    end
    local first = math.max(1, total - n + 1)
    local row = 0
    for i = first, total do
        local ln = dbg.lines[i]
        local c = DBG_COL[ln.lvl] or DBG_COL.INFO
        local ty = y + headerh + row * lineh
        soft_text(font_text, fs, ln.ts, Vec2(x + pad, ty), Color(110, 120, 135, 255))
        local tagx = x + pad + 62
        soft_text(font_text, fs, ln.lvl, Vec2(tagx, ty), Color(c[1], c[2], c[3], 255))
        local msgx = tagx + 40
        soft_text(font_text, fs, dbg_fit(ln.msg, fs, (x + w - pad) - msgx), Vec2(msgx, ty), Color(c[1], c[2], c[3], 255))
        row = row + 1
    end
end

function widget.OnDraw()
    if ui.enabled:Get() then draw_widget() end
    if ui.alarm_enable:Get() then draw_alarm() end
    if ui.debug_on and ui.debug_on:Get() then pcall(draw_debug) end
end

ui.city:SetCallback(function() if not ui.autocity:Get() then widget.force_refresh() end end)
ui.autocity:SetCallback(function() widget.force_refresh() end)
ui.om_proxy_first:SetCallback(function() widget.force_refresh() end)

return widget
