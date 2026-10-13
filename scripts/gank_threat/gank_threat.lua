-- gank_threat.lua - Gank Threat (угроза ганка) для Umbrella (Dota 2, Lua API v2.0).
-- Нужна библиотека ulib (папка ulib в корне чита: модули panel, icons, timer).
--
-- Показывает тех, кто может прийти к тебе неожиданно:
--   * телепорт врага к тебе. Частица прибытия телепорта (teleport_end и её косметические варианты,
--     furion_teleport_end у Nature's Prophet) видна и в тумане. Ближе «радиуса тревоги» - карточка
--     «ТП идёт» вверху окна, надпись по центру экрана (один раз за телепорт) и метка с обратным отсчётом
--     на месте прибытия. После прибытия враг считается стоящим в точке ТП, пока нет данных свежее;
--   * невидимых врагов, которые идут к тебе, только что прилетели по ТП или пропали из виду (позиция
--     не обновлялась 8 с), - через сколько они дойдут пешком и откуда.
--
-- Не показывает:
--   * видимых врагов - их и так видно;
--   * соперников по линии: враг «свой» для зоны (базы, верх, мид, низ, лес), если провёл в ней 25 с
--     (смена зоны засчитывается через 4 с - шаг в деревья её не сбрасывает); скрыт, если его зона -
--     твоя линия. Пришедший из другой зоны - угроза первые 25 с;
--   * тех, чья позиция свежая и кто не движется к тебе (фармит, стоит). Направление - по сглаженной
--     скорости из точек «видели» и сдвигов позиции по мапхаку.
-- Исключения - показываются всегда, даже соперник по линии и тот, кто стоит на месте:
--   * враг рядом с тобой в тумане (ближе радиуса «рядом с тобой», по умолчанию 1500) - «рядом с тобой»;
--   * враг, чьи эффекты (способности, атаки) появились в тумане ближе 2000 к тебе за последние 4 с, -
--     «активен рядом». Реакция сразу, без ожидания расчёта.
-- Готовый свиток ТП времени не даёт (у вражеской вышки он «успевал» бы всегда) - это только плашка
-- «ТП готов»; время по телепорту - только у настоящего телепорта.
--
-- Откуда данные:
--   жив ли враг - respawnTime игрока (Player.GetTeamData), а не Entity.IsAlive: у невидимого героя оно
--     застывает, и возродившийся в тумане враг числился бы мёртвым. Возродившийся в тумане - у фонтана;
--   позиция - Entity.GetAbsOrigin у видимых; у невидимых - самое свежее из: эффект, привязанный к герою
--     (OnParticleUpdateEntity - игра присылает его позицию и из тумана), где видели сами,
--     Hero.GetLastMaphackPos (свежесть - по тому, когда позиция последний раз сдвинулась),
--     точка прибытия телепорта (Hero.GetLastVisibleTime у невидимых отдаёт nil, время считаем сами);
--   дорога - GridNav.BuildPath (не больше одного пути за расчёт и только тем, кто по прямой успевает
--     за порог; в кэше - во сколько раз дорога длиннее прямой, 2 с), иначе расстояние по прямой x1.15;
--     у телепорта к тебе - один путь от точки прибытия на каждый телепорт;
--   скорость - NPC.GetMoveSpeed (у невидимых - последняя известная);
--   готов ли ТП - предметы врага в слотах 0-5 и 15 (свиток, Boots of Travel) и их кулдаун;
--   живой ТП - OnParticleCreate / OnParticleUpdate (контрольная точка 0 - место прибытия) / OnParticleDestroy.
-- Только читает игру, приказов не отдаёт. Расчёт раз в 0,5 с (OnUpdate) и сразу при новом телепорте,
-- отрисовка в OnDraw.
--
-- Чего скрипт не знает: куда враг на самом деле идёт (считаем, что прямо к тебе) и что у него
-- случилось, пока его не видно - кулдаун ТП и скорость взяты на момент, когда его видели последний раз.

local Panel = require("ulib.panel")
local Icons = require("ulib.icons")
local Timer = require("ulib.timer")

local gank = {}

local VERSION <const> = "1.7"

local ok_chronos, chronos = pcall(require, "chronos")
local clock = (ok_chronos and type(chronos) == "table" and chronos.nanotime) or os.clock

-- значения из документации - запасные: доке местами нельзя верить (сдвиг Enum.ButtonCode и т.п.)
local UNIT <const> = Enum.UnitTypeFlags
local BUILDINGS <const> = (UNIT.TYPE_TOWER or 4) | (UNIT.TYPE_BARRACKS or 64)
    | (UNIT.TYPE_FORT or 32) | (UNIT.TYPE_STRUCTURE or 16)
local POST_GAME <const> = Enum.GameState.DOTA_GAMERULES_STATE_POST_GAME or 6
local TEAM_RADIANT <const> = Enum.TeamNum.TEAM_RADIANT or 2
local TEAM_DIRE <const> = Enum.TeamNum.TEAM_DIRE or 3

local TICK <const> = 0.5
local RESIDENT_AFTER <const> = 25   -- столько секунд в одной зоне - враг «свой» для неё (соперник по линии)
local ZONE_CONFIRM <const> = 4      -- смена зоны засчитывается, если держится столько секунд
local BASE_RADIUS <const> = 2600    -- на своей базе угроз нет
local BASE_LABEL_RADIUS <const> = 3500 -- ближе к трону - подпись «наша база» / «их база»
local PATH_FACTOR <const> = 1.15    -- поправка, когда дорога считается по прямой
local MAX_PATH_DIST <const> = 9000  -- дальше путь не строим: всё равно не успеет
-- GridNav.BuildPath в матче стоил до 2,8 мс за путь (2026-09-24) - строим не больше одного за расчёт
local PATHS_PER_TICK <const> = 1
local PATH_TTL <const> = 2
local SPEED_MIN <const> = 200
local SPEED_MAX <const> = 700
local SPEED_DEFAULT <const> = 300
local STALE_CHIP <const> = 3        -- позиция старше - пишем «позиция Nс назад»
local UNKNOWN_AFTER <const> = 30    -- позиция старше - для времени подхода бесполезна, врага уводим в сноску
local MAPHACK_MOVED <const> = 20    -- сдвиг позиции по мапхаку больше этого - свежие данные
-- Кого из невидимых показывать: известно, где он, и он не идёт к тебе (фармит, стоит) - нет.
-- Показываем, если сглаженная скорость в твою сторону больше APPROACH_SPEED или если позиция
-- не обновлялась STALE_SHOW секунд (потеряли - может идти к тебе незаметно).
local APPROACH_SPEED <const> = 120  -- ед./с в твою сторону (герой идёт со скоростью ~300)
local VELOCITY_WINDOW <const> = 1.5 -- сглаживание скорости, с: фарм с шагами между крипами - не «идёт»
local JUMP_SPEED <const> = 1000     -- быстрее - скачок (ТП, возрождение, блинк), в скорость не берём
local STALE_SHOW <const> = 8
-- эффекты врагов в тумане (см. «Enemy effects»)
local ACTIVITY_RADIUS <const> = 2000 -- эффект невидимого врага ближе этого к тебе - он активен рядом
local ACTIVE_FOR <const> = 4         -- столько секунд после эффекта враг считается активным рядом
local OWNER_TTL <const> = 30         -- частицу врага, которая не исчезла, забываем через столько секунд
local EFFECTS_LOG_LIMIT <const> = 60 -- событий эффектов в лог за матч (для проверки, что они приходят)
local NOTIFY_ETA <const> = 5
local NOTIFY_COOLDOWN <const> = 10

-- слоты, из которых ТП можно прожать сразу: 0-5 инвентарь, 15 - слот ТП (из рюкзака - через 6 с)
local TP_SLOTS <const> = { 0, 1, 2, 3, 4, 5, 15 }
local TP_ITEMS <const> = { item_tpscroll = true, item_travel_boots = true, item_travel_boots_2 = true }

-- живые телепорты
local TP_PARTICLE <const> = "teleport_end" -- teleport_end, teleport_end_ti10, furion_teleport_end...
-- не прибытие: muerta_ult_teleport_end - не телепорт; *_endcap - эффекты, которые могут появиться
-- уже после прибытия (дали бы вторую тревогу)
local TP_PARTICLE_SKIP <const> = { "muerta", "endcap" }
local TP_CHANNEL <const> = 3.0             -- свиток, BoT 1, Teleportation у Nature's Prophet (каст 3 с)
local TP_CHANNEL_BOT2 <const> = 2.0
local TP_FORGET_AFTER <const> = 5          -- частица не исчезла за канал + 5 с - считаем, что прилетел
local TP_LABEL_RADIUS <const> = 1200       -- постройка ближе к точке прибытия - подпись «Т1 низ»
local TP_TEAM_RADIUS <const> = 1500        -- герой неизвестен - команда по ближайшей к точке постройке
local ARRIVED_FOR <const> = 10             -- столько секунд после прибытия плашка «после ТП»

local WHITE <const> = Color(255, 255, 255, 255)
local URGENT <const> = Color(235, 87, 87)
local SOON <const> = Color(242, 170, 60)
local CHIP_TP <const> = { text = "ТП готов", color = Color(120, 190, 255) }
local CHIP_TP_LIVE <const> = { text = "ТП идёт", color = Color(255, 95, 95) }
local CHIP_ARRIVED <const> = { text = "после ТП", color = Color(242, 170, 60) }
local CHIP_WALK <const> = { text = "пешком", color = Color(190, 195, 205) }
local CHIP_COMING <const> = { text = "идёт к тебе", color = Color(255, 150, 80) }
local CHIP_NEAR <const> = { text = "рядом с тобой", color = Color(255, 95, 95) }
local CHIP_ACTIVE <const> = { text = "активен рядом", color = Color(255, 70, 70) }
local STALE_COLOR <const> = Color(160, 165, 180)
local MARKER_BG <const> = Color(0, 0, 0, 150)

local floor, max, min, sqrt, abs = math.floor, math.max, math.min, math.sqrt, math.abs

local function log(fmt, ...)
    print("[gank] " .. fmt:format(...))
end

-- результат вызова или nil, если функция упала
local function safe(fn, ...)
    local ok, result = pcall(fn, ...)
    if ok then
        return result
    end
    return nil
end

local function dist2d(ax, ay, bx, by)
    local dx, dy = ax - bx, ay - by
    return sqrt(dx * dx + dy * dy)
end

local function seconds(value)
    return ("~%d с"):format(floor(value + 0.5))
end

local function game_now()
    return safe(GameRules.GetGameTime) or 0
end

--#region UI

local ui_group = Menu.Create("General", "Main", "Gank Threat", "Main"):Create("Угроза ганка")
local ui = {}
ui.enabled = ui_group:Switch("Включить", true)
ui.enabled:ToolTip("Невидимые враги не с твоей линии, которые идут к тебе или пропали из виду:\n"
    .. "через сколько дойдут пешком и откуда; телепорты к тебе. Видимых не показываем - их и так видно.\n"
    .. "Отметка слева: красная - меньше 5 с или телепорт к тебе, оранжевая - меньше 10 с.\n"
    .. "Время считается от последней известной позиции, поэтому у давно невидимых оно приблизительное.")
ui.threshold = ui_group:Slider("Порог, секунд", 5, 30, 12)
ui.threshold:ToolTip("Показываем только тех, кто может дойти быстрее этого времени\n"
    .. "(телепорт к тебе и враги рядом с тобой в тумане - всегда).")
ui.residents = ui_group:Switch("Скрывать соперников по линии", true)
ui.residents:ToolTip("Не показывать врагов, которые 25 с и дольше находятся в той же зоне карты, что и ты\n"
    .. "(верх / мид / низ): это соперники по линии, а не ганк. Пришедший из другой зоны - угроза первые 25 с.")
ui.calm = ui_group:Switch("Скрывать тех, кто не идёт к тебе", true)
ui.calm:ToolTip("Невидимый враг, чья позиция по мапхаку свежая и который не движется в твою сторону\n"
    .. "(фармит лагерь, стоит), - не угроза. Показываем, если он идёт к тебе, только что прилетел по ТП\n"
    .. "или его позиция не обновлялась 8 с (потеряли из виду).")
ui.fog_near = ui_group:Switch("Показывать врагов рядом в тумане", true)
ui.fog_near:ToolTip("Невидимый враг ближе радиуса к тебе показывается всегда, с плашкой «рядом с тобой» -\n"
    .. "даже соперник по линии и тот, кто не идёт к тебе (стоит в деревьях, фармит рядом).")
ui.fog_radius = ui_group:Slider("Радиус «рядом с тобой»", 500, 3000, 1500)
ui.fog_radius:ToolTip("Насколько близко должна быть последняя известная позиция врага.")
ui.tp = ui_group:Switch("Показывать готовность ТП", true)
ui.tp:ToolTip("Плашка «ТП готов» у врага, чей свиток или Boots of Travel не на кулдауне\n"
    .. "(кулдаун виден на момент, когда врага последний раз видели).")
ui.tp_alert = ui_group:Switch("Тревога при ТП рядом", true)
ui.tp_alert:ToolTip("Враг телепортируется ближе радиуса к тебе: карточка «ТП идёт» вверху окна,\n"
    .. "надпись по центру экрана и метка с обратным отсчётом на месте прибытия.\n"
    .. "Частица телепорта видна и в тумане.")
ui.tp_radius = ui_group:Slider("Радиус тревоги ТП", 1000, 6000, 3000)
ui.tp_radius:ToolTip("Насколько близко к тебе должна быть точка прибытия. 3000 - примерно твоя линия.")
ui.tp_marker = ui_group:Switch("Метка на месте ТП", true)
ui.tp_marker:ToolTip("Кружок с иконкой героя и обратным отсчётом там, где он появится.")
ui.path = ui_group:Switch("Дорога по карте", true)
ui.path:ToolTip("Путь через GridNav вместо расстояния по прямой.\n"
    .. "Дороже по нагрузке (до ~3 мс за путь): не больше одного за расчёт, только тем, кто может успеть,\n"
    .. "и один на каждый телепорт к тебе.")
ui.show = ui_group:Combo("Показывать", { "Когда есть угроза", "Всегда", "Только с открытым меню" }, 0)
ui.minimap = ui_group:Switch("Отмечать на миникарте", false)
ui.minimap:ToolTip("Иконка героя на миникарте в предполагаемой позиции (цвет - по срочности).")
ui.notify = ui_group:Switch("Предупреждать о внезапных", false)
ui.notify:ToolTip("Надпись по центру экрана, когда невидимый враг может оказаться рядом за 5 секунд.")
ui.debug = ui_group:Switch("Подробный лог", false)
ui.debug:ToolTip("Раз в секунду пишет в debug.log по каждому врагу: виден ли он, где он по мнению скрипта,\n"
    .. "откуда позиция и насколько она свежая, почему он показан или скрыт. Для поиска ошибок; в игре не нужно.")
ui.preview = ui_group:Switch("Предпросмотр в главном меню", false)
ui.preview:ToolTip("Вне матча при открытом меню показывает окно с примером - чтобы посмотреть, как оно выглядит,\n"
    .. "и передвинуть его мышью.")

local panel = Panel.new("gank_threat", { title = "Угроза", x = 40, y = 620, width = 240 })
local marker_font = Render.LoadFont("MuseoSansEx", Enum.FontCreate.FONTFLAG_ANTIALIAS, 700)

log("v%s loaded", VERSION)

--#endregion

--#region State

local threats = {}          -- готовые карточки: телепорты к тебе сверху, дальше по времени
local markers = {}          -- метки на месте прибытия телепортов к тебе
local footer = nil          -- сноска: мёртвые и потерянные враги
local hero_names = {}       -- unit name -> имя для окна
local seen_at = {}          -- unit name -> игровое время, когда врага видели последний раз
local seen_pos = {}         -- unit name -> { x, y, z } там же
local mh_prev = {}          -- unit name -> { x, y } последняя позиция по мапхаку
local mh_at = {}            -- unit name -> игровое время, когда она последний раз сдвинулась
local motion = {}           -- unit name -> { x, y, t, vx, vy } последняя точка и сглаженная скорость
local arrivals = {}         -- unit name -> { x, y, z, at } куда враг прилетел телепортом
local zones = {}            -- unit name -> { zone, since, pending, pending_at } - где враг «живёт»
local life_state = {}       -- unit name -> "dead" / "alive" в прошлом расчёте (ловим возрождение)
local life_mismatch = {}    -- unit name -> расхождение «игрок / герой», уже записанное в лог
local tps = {}              -- индекс частицы -> живой телепорт (см. OnParticleCreate)
-- Эффекты врагов в тумане (см. «Enemy effects»): кто есть кто по индексу сущности, их частицы,
-- позиции из эффектов, привязанных к герою, и активность рядом с тобой.
local enemy_by_index = {}   -- индекс сущности вражеского героя -> unit name (обновляется в расчёте)
local enemy_hero = {}       -- unit name -> герой
local enemy_dormant = {}    -- unit name -> невидим ли он (по последнему расчёту; для обработчиков - без вызовов игры)
local particle_owner = {}   -- индекс частицы -> { unit, t } - частица вражеского героя
local evidence = {}         -- unit name -> { x, y, z, t } позиция героя из эффекта на нём
local activity = {}         -- unit name -> { x, y, z, t } его эффект рядом с тобой
local my_x, my_y = nil, nil -- где ты был в последнем расчёте (для реакции без ожидания тика)
local effects_logged = 0    -- сколько событий эффектов записано в лог за матч
local debug_every = Timer.Every(1) -- «Подробный лог» - не чаще раза в секунду
local paths = {}            -- unit name -> { at = clock, len }
local notified_at = {}      -- unit name -> clock последнего предупреждения о внезапном
local pending_notify = nil  -- текст для Render.CenteredNotification (рисуем в OnDraw)
local idle_note = nil       -- почему список пуст, когда считать нечего («Ты на базе»)
local tp_watch = false      -- следить ли за частицами (скрипт включён)
local force_refresh = false -- новый телепорт: пересчитать, не дожидаясь тика
local last_game_time = -math.huge
local last_error = nil
local path_ms = 0           -- самый долгий GridNav.BuildPath за матч, в миллисекундах
local path_ms_logged = 0
local last_signature = nil  -- список в логе пишем, только когда он меняется
local last_log_at = -math.huge
local diag_done = false     -- разовая строка в лог: работают ли мапхак и ТП врагов

local function reset_match()
    threats, markers, footer = {}, {}, nil
    seen_at, seen_pos, mh_prev, mh_at, arrivals, tps = {}, {}, {}, {}, {}, {}
    zones, life_state, life_mismatch, paths, notified_at, motion = {}, {}, {}, {}, {}, {}
    enemy_by_index, enemy_hero, enemy_dormant, particle_owner, evidence, activity = {}, {}, {}, {}, {}, {}
    my_x, my_y, effects_logged = nil, nil, 0
    pending_notify, idle_note, force_refresh = nil, nil, false
    last_game_time, last_error = -math.huge, nil
    path_ms, path_ms_logged = 0, 0
    last_signature, last_log_at, diag_done = nil, -math.huge, false
end

local function hero_label(h)
    local unit = NPC.GetUnitName(h)
    local label = hero_names[unit]
    if not label then
        -- пустое имя от игры склеило бы разных врагов в одного
        local name = safe(Engine.GetDisplayNameByUnitName, unit)
        label = (type(name) == "string" and name ~= "") and name or (unit:gsub("^npc_dota_hero_", ""))
        hero_names[unit] = label
    end
    return label
end

-- настоящий герой, а не иллюзия, копия Arc Warden или клон Meepo
local function is_real_hero(h)
    return not NPC.IsIllusion(h) and not safe(Hero.GetReplicatingOtherHeroModel, h)
end

-- Секунды до возрождения по игрокам: player id -> respawnTime (-1 у живого). Эти данные приходят
-- всегда, и у врагов тоже (проверено в рейтинге), в отличие от состояния самого героя (см. life).
local function respawn_by_player()
    local out = {}
    for _, player in pairs(Players.GetAll()) do
        local id = safe(Player.GetPlayerID, player)
        local data = id and safe(Player.GetTeamData, player)
        local left = data and tonumber(data.respawnTime)
        if left then
            out[id] = left
        end
    end
    return out
end

-- Жив ли враг и сколько секунд до возрождения. У видимого - состояние героя. Entity.IsAlive у невидимого
-- застывает: враг, умерший или возродившийся в тумане, числится как был (2026-09-24: Lich возродился
-- у фонтана, а скрипт считал его мёртвым, пока его не увидели). Поэтому у невидимого главное - respawnTime
-- игрока; запасной вариант - состояние героя, а если он «мёртв», но время возрождения
-- (Hero.GetRespawnTime) уже прошло - возродился.
local function life(h, game_time, respawns, dormant)
    local id = safe(Hero.GetPlayerID, h)
    local left = id and respawns[id] or nil
    if not dormant then
        -- видимого героя игра обновляет сразу, а данные игрока бывают на тик позже: в момент смерти
        -- выходило «игрок жив, герой мёртв» и ложное «возродился в тумане» (2026-09-24)
        local alive = Entity.IsAlive(h)
        return alive, (not alive and left and left > 0) and left or nil
    end
    if left then
        return left <= 0, left
    end
    if Entity.IsAlive(h) then
        return true, nil
    end
    local at = tonumber(safe(Hero.GetRespawnTime, h))
    if at and at > 0 and at <= game_time then
        return true, nil
    end
    return false, at and at - game_time or nil
end

--#endregion

--#region Map

-- Короткое название постройки для подписи «ТП: Т2 мид».
local BUILDING_LANES <const> = { top = "верх", mid = "мид", bot = "низ" }

local function building_label(unit)
    if unit:find("fort") then
        return "трон"
    end
    if unit:find("fountain") then
        return "фонтан"
    end
    if unit:find("watch_tower") then
        return "аванпост"
    end
    local tier, lane = unit:match("tower(%d)_?(%a*)")
    if tier then
        return "Т" .. tier .. (BUILDING_LANES[lane] and " " .. BUILDING_LANES[lane] or "")
    end
    local rax_lane = unit:match("rax_(%a+)") -- npc_dota_goodguys_melee_rax_top
    if rax_lane then
        return "казармы " .. (BUILDING_LANES[rax_lane] or rax_lane)
    end
    return "постройка"
end

-- Живые постройки обеих команд; записи переиспользуются между расчётами.
local buildings = {}  -- { x, y, z, team, npc, fort, fountain }
local building_count = 0

local function scan_buildings()
    local n = 0
    for _, b in pairs(NPCs.GetAll(BUILDINGS)) do
        if Entity.IsAlive(b) then
            local team = Entity.GetTeamNum(b)
            if team == TEAM_RADIANT or team == TEAM_DIRE then
                n = n + 1
                local rec = buildings[n]
                if not rec then
                    rec = {}
                    buildings[n] = rec
                end
                rec.x, rec.y, rec.z = Entity.GetAbsOriginXYZ(b)
                rec.team, rec.npc, rec.fort = team, b, NPC.IsFort(b)
                rec.fountain = NPC.GetUnitName(b):find("fountain", 1, true) ~= nil
            end
        end
    end
    building_count = n
end

-- Ближайшая к точке постройка команды team (любой, если team = nil): запись и расстояние.
local function nearest_building(x, y, team)
    local best, best_d = nil, math.huge
    for i = 1, building_count do
        local rec = buildings[i]
        if not team or rec.team == team then
            local d = dist2d(rec.x, rec.y, x, y)
            if d < best_d then
                best, best_d = rec, d
            end
        end
    end
    return best, best_d
end

-- Где возрождаются герои команды: фонтан, а если его нет среди построек - трон (он рядом).
local function spawn_of(team)
    local fort = nil
    for i = 1, building_count do
        local rec = buildings[i]
        if rec.team == team then
            if rec.fountain then
                return rec
            end
            fort = rec.fort and rec or fort
        end
    end
    return fort
end

local function fort_of(team)
    for i = 1, building_count do
        local rec = buildings[i]
        if rec.fort and rec.team == team then
            return rec
        end
    end
    return nil
end

-- Зона карты: базы, линии (мид - полоса вдоль диагонали, верх и низ - края карты) или лес.
local ZONE_NAMES <const> = {
    base_my = "наша база", base_enemy = "их база", top = "верх", mid = "мид", bot = "низ", jungle = "лес",
}
local LANES <const> = { top = true, mid = true, bot = true }

local function zone_of(x, y, my_fort, enemy_fort)
    if my_fort and dist2d(x, y, my_fort.x, my_fort.y) < BASE_LABEL_RADIUS then
        return "base_my"
    end
    if enemy_fort and dist2d(x, y, enemy_fort.x, enemy_fort.y) < BASE_LABEL_RADIUS then
        return "base_enemy"
    end
    if abs(x - y) < 1800 then
        return "mid"
    elseif x < -4200 or y > 4200 then
        return "top"
    elseif y < -4200 or x > 4200 then
        return "bot"
    end
    return "jungle"
end

-- Запоминает, в какой зоне враг «живёт». Новая зона засчитывается, если держится ZONE_CONFIRM секунд:
-- соперник по линии, шагнувший в деревья, из неё не выпадает. Первая увиденная зона - как будто враг
-- там давно (после загрузки скрипта посреди матча все не должны разом стать угрозой).
local function track_zone(unit, zone, game_time)
    local rec = zones[unit]
    if not rec then
        zones[unit] = { zone = zone, since = -math.huge }
    elseif zone == rec.zone then
        rec.pending = nil
    elseif rec.pending ~= zone then
        rec.pending, rec.pending_at = zone, game_time
    elseif game_time - rec.pending_at >= ZONE_CONFIRM then
        rec.zone, rec.since, rec.pending = zone, rec.pending_at, nil
    end
end

-- Соперник по линии: давно в той же линии, что и я.
local function is_resident(unit, my_zone, game_time)
    local rec = zones[unit]
    return rec ~= nil and LANES[my_zone] ~= nil and rec.zone == my_zone
        and game_time - rec.since >= RESIDENT_AFTER
end

-- Подпись области: база, иначе линия и чья половина.
local function area_label(x, y, my_fort, enemy_fort)
    local zone = zone_of(x, y, my_fort, enemy_fort)
    if not LANES[zone] and zone ~= "jungle" then
        return ZONE_NAMES[zone]
    end
    local lane = ZONE_NAMES[zone]
    local side = (my_fort and my_fort.x + my_fort.y > 0) and 1 or -1
    local s = x + y
    local half
    if abs(s) < 2500 then
        half = "центр"
    elseif (s < 0) == (side < 0) then
        half = "у нас"
    else
        half = "у них"
    end
    return lane .. ", " .. half
end

-- Подпись точки: постройка команды team рядом («Т1 низ») или область карты.
local function place_label(x, y, team, my_fort, enemy_fort)
    local rec, d = nearest_building(x, y, team)
    if rec and d < TP_LABEL_RADIUS then
        return building_label(NPC.GetUnitName(rec.npc))
    end
    return area_label(x, y, my_fort, enemy_fort)
end

-- Во сколько раз дорога по карте длиннее прямой (GridNav.BuildPath, деревья не учитываем - оценка
-- оптимистичная, для предупреждения так безопаснее) или nil, если путь не построился.
-- Цена - до ~3 мс за путь (замер в матче), поэтому зовут её редко; самый долгий путь пишется в лог.
local function detour_ratio(from, to, straight)
    local started = clock()
    local points = safe(GridNav.BuildPath, from, to, true)
    local spent = (clock() - started) * 1000
    if spent > path_ms then
        path_ms = spent
    end
    if type(points) ~= "table" or #points < 2 or straight < 1 then
        return nil
    end
    local len, px, py = 0, nil, nil
    for _, p in ipairs(points) do
        if px then
            len = len + dist2d(p.x, p.y, px, py)
        end
        px, py = p.x, p.y
    end
    return max(1, len / straight) -- короче прямой быть не может: значит, с точками что-то не так
end

--#endregion

--#region Live teleports

-- Живой телепорт: частица прибытия. Её создают для героя, который телепортируется, поэтому герой
-- и команда обычно известны сразу; если нет - берём героя из OnParticleUpdateEntity, а команду -
-- по ближайшей к точке прибытия постройке (свиток телепортирует к своим постройкам).
-- tps[индекс] = { hero, created, particle, x, y, z, cp, channel, unit, enemy, notified, logged, name }

local function as_hero(e)
    if e ~= nil and safe(Entity.IsHero, e) then
        return e
    end
    return nil
end

local function hero_by_index(id)
    if type(id) == "number" and id > 0 then
        return as_hero(safe(Entity.Get, id))
    end
    return nil
end

-- Герой телепорта известен: его имя, команда и канал (у Boots of Travel 2 - 2 с, телепорт
-- Nature's Prophet - всегда 3 с, даже с ними).
local function resolve_tp(t, me)
    if t.hero and not t.unit and me then
        t.unit = NPC.GetUnitName(t.hero)
        t.enemy = not Entity.IsSameTeam(t.hero, me)
        local bot2 = not t.particle:find("furion", 1, true)
            and safe(NPC.GetItem, t.hero, "item_travel_boots_2", true)
        t.channel = bot2 and TP_CHANNEL_BOT2 or TP_CHANNEL
    end
end

-- Телепорт закончился: успел долететь - запоминаем, где враг теперь; отменён - просто забываем.
-- Команду определяем и здесь: телепорт мог закончиться раньше, чем его увидел расчёт.
local function finish_tp(t, at)
    resolve_tp(t, Heroes.GetLocal())
    local arrived = at >= t.created + (t.channel or TP_CHANNEL) - 0.5
    if arrived and t.x and t.unit and t.enemy then
        arrivals[t.unit] = { t.x, t.y, t.z, at = at }
    end
    if t.logged then
        log("ТП %s: %s", t.name or "?", arrived and "прилетел" or "отменён")
    end
end

--#endregion

--#region Enemy effects

-- Эффекты врагов в тумане. Info Screen рисует невидимых врагов по их эффектам (способности, атаки),
-- а Hero.GetLastMaphackPos обновляется редко: в матче 2026-09-24 у Magnus она была 26 с старой, пока
-- враги кастовали рядом с тобой, и скрипт считал их в 4000+ от тебя и молчал. Поэтому смотрим эффекты сами:
--   * позиция: эффект, привязанный к вражескому герою (OnParticleUpdateEntity), приходит с его позицией
--     и из тумана. Совпадает с застывшей позицией невидимого героя - это не новые данные;
--   * активность: точка эффекта вражеского героя (частица, созданная для него, - OnParticleCreate;
--     точки - OnParticleUpdate) ближе ACTIVITY_RADIUS к тебе - он кастует или бьёт рядом.
--     Такой враг показывается всегда, с плашкой «активен рядом».

-- Точка частицы - координаты на карте или nil. Контрольные точки бывают и параметрами: цвет (255, 0, 0),
-- радиус или длительность (300, 0, 0) и т.п. - у настоящих координат две оси ровно по нулю не бывают.
local function valid_point(p)
    if not p then
        return nil
    end
    local x, y, z = p.x, p.y, p.z
    if not x or abs(x) > 9500 or abs(y) > 9500 then
        return nil
    end
    if (abs(x) <= 256 and abs(y) <= 256 and abs(z) <= 256) or (y == 0 and z == 0) or (x == 0 and z == 0)
        or (x == 0 and y == 0) then
        return nil
    end
    return x, y, z
end

local function log_effect(fmt, ...)
    if effects_logged < EFFECTS_LOG_LIMIT then
        effects_logged = effects_logged + 1
        log(fmt, ...)
    end
end

-- Невидимый живой вражеский герой по unit name или nil. Видимого знаем и так, а у мёртвого эффекты -
-- смерть и возрождение у фонтана (2026-09-24: Ogre Magi, возрождаясь, «был активен в 1798 от тебя»).
-- Флаги - из последнего расчёта: обработчики эффектов в драке вызываются сотни раз в секунду.
local function dormant_enemy(unit)
    if enemy_dormant[unit] and life_state[unit] ~= "dead" then
        return enemy_hero[unit]
    end
    return nil
end

local function note_position(unit, p)
    local h = dormant_enemy(unit)
    local x, y, z = valid_point(p)
    if not h or not x then
        return
    end
    local ox, oy = Entity.GetAbsOriginXYZ(h)
    if dist2d(ox, oy, x, y) < 1 then
        return -- застывшая позиция невидимого героя
    end
    local now = game_now()
    local e = evidence[unit]
    if e then
        e[1], e[2], e[3], e.t = x, y, z, now
    else
        evidence[unit] = { x, y, z, t = now }
    end
    if my_x then
        local d = dist2d(x, y, my_x, my_y)
        if d <= ACTIVITY_RADIUS then
            force_refresh = true
            log_effect("эффект: %s в %d от тебя (позиция героя)", hero_label(h), floor(d))
        end
    end
end

local function note_activity(unit, p)
    local h = dormant_enemy(unit)
    local x, y, z = valid_point(p)
    if not h or not x or not my_x then
        return
    end
    local d = dist2d(x, y, my_x, my_y)
    if d > ACTIVITY_RADIUS then
        return
    end
    local now = game_now()
    local a = activity[unit]
    if not a or now - a.t > 1 then
        force_refresh = true -- новая активность: окно без задержки в полсекунды
        log_effect("эффект: %s активен в %d от тебя", hero_label(h), floor(d))
    end
    if a then
        a[1], a[2], a[3], a.t = x, y, z, now
    else
        activity[unit] = { x, y, z, t = now }
    end
end

--#endregion

--#region Particle callbacks

function gank.OnParticleCreate(data)
    if not tp_watch then
        return
    end
    local index = data.index
    if tps[index] then
        tps[index] = nil -- исчезновение прошлой частицы с этим индексом мы пропустили
    end
    -- частица невидимого вражеского героя: запоминаем, чья она (её точки придут в OnParticleUpdate);
    -- частицы видимых не храним - их в драке много, а активность нужна только у невидимых
    local owner = enemy_by_index[data.entity_for_modifiers_id] or enemy_by_index[data.entity_id]
    if owner and dormant_enemy(owner) then
        particle_owner[index] = { unit = owner, t = game_now() }
    elseif particle_owner[index] then
        particle_owner[index] = nil
    end
    local name = data.name
    if type(name) ~= "string" or not name:find(TP_PARTICLE, 1, true) then
        return
    end
    for _, skip in ipairs(TP_PARTICLE_SKIP) do
        if name:find(skip, 1, true) then
            return
        end
    end
    tps[index] = {
        hero = as_hero(data.entityForModifiers) or as_hero(data.entity)
            or hero_by_index(data.entity_for_modifiers_id) or hero_by_index(data.entity_id),
        created = game_now(),
        particle = name,
    }
end

-- Точки частиц: активность врагов рядом (их частицы) и место прибытия телепорта. У телепорта место
-- прибытия - контрольная точка 0; другие берём, только пока её нет. Маленькие значения - не координаты
-- (цвет, параметры эффекта).
local function on_particle_point(data)
    local index = data.index
    local owner = particle_owner[index]
    if owner then
        note_activity(owner.unit, data.position)
    end
    if next(tps) == nil then
        return
    end
    local t = tps[index]
    if not t or (t.x and data.controlPoint ~= 0) then
        return
    end
    local p = data.position
    if not p then
        return
    end
    local x, y, z = p.x, p.y, p.z
    if abs(x) <= 256 and abs(y) <= 256 and abs(z) <= 256 then
        return
    end
    if not t.x then
        force_refresh = true -- тревога без задержки в полсекунды
    end
    t.x, t.y, t.z, t.cp = x, y, z, data.controlPoint
end

gank.OnParticleUpdate = on_particle_point
gank.OnParticleUpdateFallback = on_particle_point

-- Эффект привязан к сущности: если это невидимый вражеский герой - его позиция; у телепорта без героя -
-- кто телепортируется.
function gank.OnParticleUpdateEntity(data)
    if not tp_watch then
        return
    end
    local unit = enemy_by_index[data.entIdx]
    if unit then
        note_position(unit, data.position)
    end
    if next(tps) == nil then
        return
    end
    local t = tps[data.index]
    if t and not t.hero then
        t.hero = as_hero(data.entity) or hero_by_index(data.entIdx)
    end
end

function gank.OnParticleDestroy(data)
    local index = data.index
    if particle_owner[index] then
        particle_owner[index] = nil
    end
    if next(tps) == nil then
        return
    end
    local t = tps[index]
    if t then
        tps[index] = nil
        finish_tp(t, game_now())
    end
end

--#endregion

--#region Live teleports: list

-- Телепорты врагов с известной точкой прибытия: unit (или "tp<индекс>", если герой неизвестен) ->
-- { t, eta, left, dist, where, near }. Заодно забывает зависшие и определяет команду.
-- quiet - ты мёртв или на базе: телепорты только отслеживаем, тревоги и пути нет.
local function live_tps(me, my_team, enemy_team, mx, my, my_pos, game_time, my_fort, enemy_fort, quiet)
    local out = {}
    local radius = ui.tp_radius:Get()
    for index, t in pairs(tps) do
        resolve_tp(t, me)
        local channel = t.channel or TP_CHANNEL
        if game_time > t.created + channel + TP_FORGET_AFTER then
            tps[index] = nil
            finish_tp(t, t.created + channel)
        elseif t.x then
            if t.enemy == nil and not t.hero then
                local rec, d = nearest_building(t.x, t.y)
                if rec and d < TP_TEAM_RADIUS then
                    t.enemy = rec.team ~= my_team
                end
            end
            if t.enemy then
                local d = dist2d(t.x, t.y, mx, my)
                local left = max(0, t.created + channel - game_time)
                local speed = SPEED_DEFAULT
                if t.hero then
                    local s = tonumber(safe(NPC.GetMoveSpeed, t.hero)) or 0
                    if s >= SPEED_MIN and s <= SPEED_MAX then
                        speed = s
                    end
                end
                local where = place_label(t.x, t.y, enemy_team, my_fort, enemy_fort)
                t.name = t.hero and hero_label(t.hero) or "Враг"
                local near = not quiet and d <= radius
                -- телепорт к тебе - самая важная тревога: один настоящий путь от точки прибытия на телепорт
                if near and not t.ratio then
                    t.ratio = ui.path:Get() and d <= MAX_PATH_DIST
                        and detour_ratio(Vector(t.x, t.y, t.z), my_pos, d) or PATH_FACTOR
                end
                if not t.logged then
                    t.logged = true
                    log("ТП %s -> %s, %d от тебя (%s), канал %.0f с, частица %s, точка cp%s", t.name, where,
                        floor(d), near and "тревога" or "далеко", channel, t.particle, tostring(t.cp))
                end
                out[t.unit or ("tp" .. index)] = {
                    t = t, eta = left + d * (t.ratio or PATH_FACTOR) / speed, left = left, dist = d,
                    where = where, near = near,
                }
            end
        end
    end
    return out
end

--#endregion

--#region Threat

-- Новая точка врага: у видимого - каждый расчёт, у невидимого - когда сдвинулась позиция по мапхаку.
-- Обновляет сглаженную скорость (окно VELOCITY_WINDOW): шаги фармящего между крипами гасят друг
-- друга, а идущий в одну сторону её набирает. Скачки (ТП, блинк) и долгие паузы скорость обнуляют.
local function track_motion(unit, x, y, t)
    local m = motion[unit]
    if not m then
        motion[unit] = { x = x, y = y, t = t, vx = 0, vy = 0 }
        return
    end
    local dt = t - m.t
    if dt < 0.2 then
        return
    end
    local ivx, ivy = (x - m.x) / dt, (y - m.y) / dt
    if dt > 6 or sqrt(ivx * ivx + ivy * ivy) > JUMP_SPEED then
        m.vx, m.vy = 0, 0
    else
        local a = min(1, dt / VELOCITY_WINDOW)
        m.vx = m.vx + (ivx - m.vx) * a
        m.vy = m.vy + (ivy - m.vy) * a
    end
    m.x, m.y, m.t = x, y, t
end

-- Скорость врага в мою сторону (ед./с, отрицательная - уходит). Без новых точек остаётся последней
-- известной: ушедший в туман в мою сторону считается идущим ко мне, пока позиция не устареет.
local function speed_toward(unit, x, y, mx, my)
    local m = motion[unit]
    local dx, dy = mx - x, my - y
    local d = sqrt(dx * dx + dy * dy)
    if not m or d < 1 then
        return 0
    end
    return (m.vx * dx + m.vy * dy) / d
end

-- Где враг сейчас по самым свежим данным. Возвращает x, y, z (или nil), возраст позиции,
-- сколько секунд его не видно (для кулдаунов - их значения застывают), прилетел ли он недавно по ТП
-- и откуда позиция (для лога): «виден», «видели», «мапхак», «эффект», «ТП», «фонтан».
local function locate(h, unit, dormant, game_time, stat)
    if not dormant then
        local x, y, z = Entity.GetAbsOriginXYZ(h)
        seen_at[unit], seen_pos[unit] = game_time, { x, y, z }
        track_motion(unit, x, y, game_time)
        -- мапхак после ухода в туман начинаем с чистого листа (см. ниже)
        mh_prev[unit], mh_at[unit] = nil, nil
        return x, y, z, 0, 0, false, "виден"
    end
    stat.dormant = stat.dormant + 1

    local seen = seen_at[unit]
    if not seen then
        local visible_at = tonumber(safe(Hero.GetLastVisibleTime, h))
        seen = (visible_at and visible_at > 0) and visible_at or nil
    end
    local x, y, z, at, src = nil, nil, nil, nil, nil
    local last = seen_pos[unit]
    if last then
        x, y, z, at, src = last[1], last[2], last[3], seen_at[unit], "видели"
    end

    -- Мапхак. Позиции, которую он отдаёт в первый момент в тумане, верить нельзя: там бывает старая точка
    -- из другого места (2026-09-24: враги на линии рядом с тобой, уйдя в туман, «переезжали» далеко и
    -- пропадали из окна). Поэтому первая позиция после ухода в туман - только отсчёт, а верим мапхаку,
    -- когда позиция сдвинулась уже в тумане; до этого - где видели сами. Свежесть - время последнего сдвига.
    -- Нулевой вектор - «данных нет».
    local mh = safe(Hero.GetLastMaphackPos, h)
    if mh and (abs(mh.x) > 1 or abs(mh.y) > 1) then
        stat.maphack = stat.maphack + 1
        local prev = mh_prev[unit]
        if not prev then
            mh_prev[unit] = { mh.x, mh.y }
        elseif dist2d(prev[1], prev[2], mh.x, mh.y) > MAPHACK_MOVED then
            prev[1], prev[2] = mh.x, mh.y
            mh_at[unit] = game_time
            track_motion(unit, mh.x, mh.y, game_time)
        end
        local mh_time = mh_at[unit]
        if mh_time and (not at or mh_time >= at) then
            x, y, z, at, src = mh.x, mh.y, mh.z, mh_time, "мапхак"
        elseif not x then
            -- своих данных нет вовсе (скрипт загрузили посреди матча): мапхак как есть, возраст неизвестен
            x, y, z, src = mh.x, mh.y, mh.z, "мапхак"
        end
    end
    at = at or (x and seen) or nil

    -- позиция из эффекта, привязанного к герою (см. «Enemy effects»), - если новее остального
    local ev = evidence[unit]
    if ev and (not at or ev.t > at) then
        x, y, z, at, src = ev[1], ev[2], ev[3], ev.t, "эффект"
        track_motion(unit, x, y, at)
    end

    local arrival = arrivals[unit]
    -- arrival - и место прибытия ТП, и фонтан после возрождения; плашка «после ТП» - только у ТП
    local arrived = arrival ~= nil and not arrival.respawn and game_time - arrival.at < ARRIVED_FOR
    if arrival and (not at or arrival.at > at) then
        x, y, z, at = arrival[1], arrival[2], arrival[3], arrival.at
        src = arrival.respawn and "фонтан" or "ТП"
    end

    local unseen = seen and max(0, game_time - seen) or math.huge
    local age = at and max(0, game_time - at) or math.huge
    return x, y, z, age, unseen, arrived, src
end

-- Длина дороги от врага до меня. Точный путь строим не чаще PATH_TTL и не больше PATHS_PER_TICK за расчёт.
-- В кэше - не длина, а во сколько раз дорога длиннее прямой: за время кэша сдвигаетесь и враг, и ты,
-- а обход препятствий меняется медленно. Нет свежего - берём не старше PATH_KEEP, иначе x1.15.
-- reach - сколько враг успевает пройти за порог: если даже по прямой дальше, он в окно не попадёт
-- (дорога по карте не короче прямой), и путь строить незачем.
local PATH_KEEP <const> = 10

local function walk_length(unit, from, fx, fy, to, mx, my, budget, reach)
    local straight = dist2d(fx, fy, mx, my)
    if not ui.path:Get() or straight > MAX_PATH_DIST or straight > reach then
        return straight * PATH_FACTOR, budget
    end
    local cached = paths[unit]
    local now = clock()
    if cached and now - cached.at < PATH_TTL then
        return straight * cached.ratio, budget
    end
    if budget <= 0 then
        local ratio = (cached and now - cached.at < PATH_KEEP) and cached.ratio or PATH_FACTOR
        return straight * ratio, budget
    end
    local ratio = detour_ratio(from, to, straight)
    if not ratio then
        return straight * PATH_FACTOR, budget - 1
    end
    paths[unit] = { at = now, ratio = ratio }
    return straight * ratio, budget - 1
end

-- Готов ли у врага телепорт (свиток или Boots of Travel в инвентаре / слоте ТП без кулдауна).
-- unseen - сколько секунд врага не видно: кулдаун за это время успел стечь, а его значение застыло.
local function tp_ready(h, unseen)
    for _, slot in ipairs(TP_SLOTS) do
        local item = safe(NPC.GetItemByIndex, h, slot)
        local name = item and safe(Ability.GetName, item) or nil
        if name and TP_ITEMS[name] then
            local cd = tonumber(safe(Ability.GetCooldown, item)) or 0
            if cd - unseen <= 0 then
                return true
            end
        end
    end
    return false
end

local function urgency(eta)
    if eta <= 5 then
        return URGENT
    end
    if eta <= 10 then
        return SOON
    end
    return nil
end

-- Строка списка из живого телепорта. К тебе (ближе радиуса тревоги) - закреплена вверху.
local function live_item(tp)
    local t = tp.t
    return {
        unit = t.unit, label = t.name, eta = tp.eta, chips = { CHIP_TP_LIVE },
        subtitle = ("%s, %d от тебя"):format(tp.where, floor(tp.dist / 100) * 100),
        pos = Vector(t.x, t.y, t.z), dormant = false, pinned = (tp.near and ui.tp_alert:Get()) and true or false,
        live = t, land_in = tp.left,
    }
end

-- Невидимый враг возродился: он у своего фонтана, а не там, где умер (там его позиция по мапхаку и
-- «где видели»). Отмечаем один раз на возрождение - как прибытие в точку spawn. Возрождение видно
-- либо по смене «мёртв» -> «жив» между расчётами, либо, если фазу смерти мы пропустили (ты был мёртв
-- или на базе, скрипт загрузился), по застывшему Entity.IsAlive = false; тогда время - Hero.GetRespawnTime.
-- Возвращает true, если отметил.
local function mark_respawn(h, unit, spawn, game_time)
    local at
    if life_state[unit] == "dead" then
        at = game_time
    elseif not Entity.IsAlive(h) then
        -- Возрождение, которое мы пропустили, видно по уже прошедшему времени возрождения. Если оно ещё
        -- не наступило или неизвестно - герой только что умер, а данные игрока не успели обновиться.
        local rt = tonumber(safe(Hero.GetRespawnTime, h))
        if not (rt and rt > 0 and rt <= game_time) then
            return false
        end
        local mark = arrivals[unit]
        if mark and mark.respawn and mark.at >= rt - 1 then
            return false -- это возрождение уже отмечено
        end
        at = rt
    else
        return false
    end
    arrivals[unit] = { spawn.x, spawn.y, spawn.z, at = at, respawn = true }
    return true
end

-- мёртвому и стоящему на базе считать нечего
local function set_idle(note)
    threats, markers, footer, idle_note = {}, {}, nil, note
end

local function refresh()
    -- новый матч без OnGameEnd (выход из демки, реконнект): игровое время пошло заново
    local game_time = game_now()
    if game_time + 5 < last_game_time then
        reset_match()
    end
    last_game_time = game_time

    local me = Heroes.GetLocal()
    if not me or safe(GameRules.GetGameState) == POST_GAME then
        set_idle(nil)
        return
    end
    local my_team = Entity.GetTeamNum(me)
    local enemy_team = my_team == TEAM_RADIANT and TEAM_DIRE or TEAM_RADIANT
    local mx, my, mz = Entity.GetAbsOriginXYZ(me)
    local my_pos = Vector(mx, my, mz)
    my_x, my_y = mx, my -- для обработчиков эффектов между расчётами
    scan_buildings()
    -- частицы врагов, которые так и не исчезли, забываем
    for index, owner in pairs(particle_owner) do
        if game_time - owner.t > OWNER_TTL then
            particle_owner[index] = nil
        end
    end
    local my_fort, enemy_fort = fort_of(my_team), fort_of(enemy_team)

    -- Мёртвому и стоящему на базе показывать нечего, но следить за врагами продолжаем: иначе после
    -- возвращения на линию их зоны, движение, возрождения и прилёты по ТП были бы неизвестны.
    local idle = nil
    if not Entity.IsAlive(me) then
        idle = "Ты мёртв"
    elseif my_fort and dist2d(mx, my, my_fort.x, my_fort.y) < BASE_RADIUS then
        idle = "Ты на базе"
    end

    local my_zone = zone_of(mx, my, my_fort, enemy_fort)
    local hide_residents = ui.residents:Get()
    local hide_calm = ui.calm:Get()
    local show_fog_near = ui.fog_near:Get()
    local fog_radius = ui.fog_radius:Get()
    local threshold = ui.threshold:Get()
    local live = live_tps(me, my_team, enemy_team, mx, my, my_pos, game_time, my_fort, enemy_fort, idle ~= nil)

    local list, dead, lost = {}, {}, {}
    local hidden = {} -- невидимые, которых скрыли фильтры: { ключ для подписи лога, «имя причина расстояние» }
    local debug_due = ui.debug:Get() and debug_every()
    local debug_parts = {}
    local budget = PATHS_PER_TICK
    local respawns = respawn_by_player()
    local enemy_spawn = spawn_of(enemy_team)
    -- для разовой строки диагностики в логе
    local stat = {
        dormant = 0, maphack = 0, tp = 0, visible = 0, residents = 0, calm = 0, near = 0, active = 0, respawned = 0,
    }
    for _, h in pairs(Heroes.GetAll()) do
        if not Entity.IsSameTeam(h, me) and is_real_hero(h) then
            local unit = NPC.GetUnitName(h)
            local dormant = Entity.IsDormant(h)
            -- для обработчиков эффектов: чей это индекс сущности
            local index = safe(Entity.GetIndex, h)
            if index then
                enemy_by_index[index] = unit
            end
            enemy_hero[unit], enemy_dormant[unit] = h, dormant
            local alive, left = life(h, game_time, respawns, dormant)
            -- расхождение данных игрока и состояния героя - в лог при каждом появлении (проверка исправления)
            local hero_alive = Entity.IsAlive(h)
            local mismatch = alive ~= hero_alive and (alive and "alive" or "dead") or nil
            if mismatch and life_mismatch[unit] ~= mismatch then
                log("%s: по данным игрока %s, а герой %s (не виден: %s)", hero_label(h),
                    alive and "жив" or "мёртв", hero_alive and "жив" or "мёртв", tostring(dormant))
            end
            life_mismatch[unit] = mismatch
            if alive and dormant and enemy_spawn and mark_respawn(h, unit, enemy_spawn, game_time) then
                stat.respawned = stat.respawned + 1
                log("%s возродился в тумане: считаем, что он у фонтана", hero_label(h))
            end
            life_state[unit] = alive and "alive" or "dead"

            local x, y, z, age, unseen, arrived, src = locate(h, unit, dormant, game_time, stat)
            if alive and x and age <= UNKNOWN_AFTER then
                track_zone(unit, zone_of(x, y, my_fort, enemy_fort), game_time)
            end
            -- Активен рядом: его эффект был ближе ACTIVITY_RADIUS к тебе за последние ACTIVE_FOR секунд
            -- (кастует или бьёт из тумана). Если позиции свежее нет - считаем его у этого эффекта.
            local act = activity[unit]
            local active = alive and dormant and act ~= nil and game_time - act.t <= ACTIVE_FOR
            if active and (not x or age > game_time - act.t + 1) then
                x, y, z, age, src = act[1], act[2], act[3], game_time - act.t, "эффект рядом"
            end
            -- рядом с тобой в тумане: показываем всегда, мимо фильтров «соперник по линии» и «не идёт к тебе»
            local near_fog = show_fog_near and dormant and x ~= nil and age <= UNKNOWN_AFTER
                and dist2d(x, y, mx, my) <= fog_radius
            local always = near_fog or active

            local decision -- для подробного лога: что скрипт решил про этого врага
            if idle then
                decision = "не считаем: " .. idle
            elseif not alive then
                decision = "мёртв"
                dead[#dead + 1] = hero_label(h) .. ((left and left > 0 and left < 300) and " " .. seconds(left) or "")
            elseif live[unit] then
                -- телепорт показываем, даже если телепортирующегося видно
                decision = "показан: ТП"
                list[#list + 1] = live_item(live[unit])
                live[unit] = nil
            elseif not dormant then
                decision = "скрыт: виден"
                stat.visible = stat.visible + 1 -- видимого не показываем: его и так видно
            elseif not x or age > UNKNOWN_AFTER then
                decision = "в сноске: потерян"
                lost[#lost + 1] = hero_label(h)
            elseif not always and hide_residents and is_resident(unit, my_zone, game_time) then
                decision = "скрыт: соперник по линии"
                stat.residents = stat.residents + 1 -- соперник по линии, не ганк
                hidden[#hidden + 1] = { unit .. ":line", ("%s соперник по линии %d (%s %dс)"):format(
                    hero_label(h), floor(dist2d(x, y, mx, my)), src or "?", floor(age)) }
            elseif not always and hide_calm and age < STALE_SHOW and not arrived
                and speed_toward(unit, x, y, mx, my) < APPROACH_SPEED then
                decision = "скрыт: не идёт к тебе"
                stat.calm = stat.calm + 1 -- знаем, где он, и он не идёт к тебе (фармит, стоит)
                hidden[#hidden + 1] = { unit .. ":calm", ("%s не идёт к тебе %d (%s %dс)"):format(
                    hero_label(h), floor(dist2d(x, y, mx, my)), src or "?", floor(age)) }
            else
                decision = "показан"
                if near_fog then
                    stat.near = stat.near + 1
                end
                if active then
                    stat.active = stat.active + 1
                end
                local coming = speed_toward(unit, x, y, mx, my) >= APPROACH_SPEED
                local speed = tonumber(safe(NPC.GetMoveSpeed, h)) or 0
                if speed < SPEED_MIN or speed > SPEED_MAX then
                    speed = SPEED_DEFAULT
                end
                local pos = Vector(x, y, z or 0)
                local length
                length, budget = walk_length(unit, pos, x, y, my_pos, mx, my, budget, threshold * speed)
                -- первая плашка - самое важное: активен рядом, рядом с тобой, идёт к тебе, иначе «пешком»
                local chips = {}
                if active then
                    chips[#chips + 1] = CHIP_ACTIVE
                end
                if near_fog then
                    chips[#chips + 1] = CHIP_NEAR
                end
                if coming then
                    chips[#chips + 1] = CHIP_COMING
                end
                if #chips == 0 then
                    chips[1] = CHIP_WALK
                end
                if ui.tp:Get() and tp_ready(h, unseen) then
                    stat.tp = stat.tp + 1
                    chips[#chips + 1] = CHIP_TP
                end
                if arrived then
                    chips[#chips + 1] = CHIP_ARRIVED
                end
                if age >= STALE_CHIP then
                    chips[#chips + 1] = { text = ("позиция %dс назад"):format(floor(age)), color = STALE_COLOR }
                end
                local eta = length / speed
                if not always and eta > threshold then
                    decision = ("скрыт: не успевает (%.1f с)"):format(eta)
                end
                list[#list + 1] = {
                    unit = unit, label = hero_label(h), eta = eta, chips = chips,
                    subtitle = area_label(x, y, my_fort, enemy_fort), pos = pos, dormant = true, pinned = false,
                    near = always, src = src, age = age,
                }
            end

            if debug_due then
                local zone = zones[unit]
                debug_parts[#debug_parts + 1] = ("%s: %s; %s, позиция %s %s, %s от тебя, к тебе %s ед/с, зона %s%s%s")
                    :format(hero_label(h), decision, dormant and "невидим" or "виден", src or "нет",
                        age < math.huge and ("%dс"):format(floor(age)) or "?",
                        x and tostring(floor(dist2d(x, y, mx, my))) or "?",
                        x and tostring(floor(speed_toward(unit, x, y, mx, my))) or "?",
                        zone and zone.zone or "?", near_fog and ", рядом" or "", active and ", активен" or "")
            end
        end
    end
    if debug_due and #debug_parts > 0 then
        log("отладка %s: моя зона %s%s || %s", Timer.Format(safe(GameRules.GetDOTATime) or 0), my_zone,
            idle and (", " .. idle) or "", table.concat(debug_parts, " || "))
    end
    if idle then
        set_idle(idle)
        return
    end
    idle_note = nil
    -- телепорты, чей герой так и не определился
    for _, tp in pairs(live) do
        list[#list + 1] = live_item(tp)
    end

    table.sort(list, function(a, b)
        if a.pinned ~= b.pinned then
            return a.pinned
        end
        return a.eta < b.eta
    end)

    local ready, new_markers, now = {}, {}, clock()
    local log_parts, sig_parts = {}, {}
    for _, t in ipairs(list) do
        if t.pinned or t.near or t.eta <= threshold then
            local chip_texts = {}
            for i, c in ipairs(t.chips) do
                chip_texts[i] = c.text
            end
            log_parts[#log_parts + 1] = ("%s %.1fс %s%s"):format(t.label, t.eta, table.concat(chip_texts, ", "),
                t.src and (" (%s %dс)"):format(t.src, floor(t.age or 0)) or "")
            sig_parts[#sig_parts + 1] = ("%s:%d%s"):format(t.unit or "?", floor(t.eta / 5), t.live and "!" or "")
            local color = t.pinned and URGENT or urgency(t.eta)
            ready[#ready + 1] = {
                unit = t.unit, pos = t.pos, color = color,
                entry = {
                    icon = t.unit and Icons.HeroPortrait(t.unit) or nil, icon_w = 44, icon_h = 25,
                    title = t.label, tag = seconds(t.eta), tag_color = color,
                    chips = t.chips, subtitle = t.subtitle, stripe = color,
                },
            }
            if t.live then
                -- телепорт к тебе: надпись один раз за телепорт и метка на месте прибытия
                if t.pinned and not t.live.notified then
                    t.live.notified = true
                    pending_notify = ("ТП к тебе: %s - %s, прилетит через %d с"):format(t.label, t.subtitle,
                        floor((t.land_in or 0) + 0.5))
                end
                if t.pinned and ui.tp_marker:Get() then
                    new_markers[#new_markers + 1] = {
                        pos = t.pos, created = t.live.created, channel = t.live.channel or TP_CHANNEL,
                        icon = t.unit and Icons.Hero(t.unit) or nil,
                    }
                end
            elseif ui.notify:Get() and t.dormant and t.eta <= NOTIFY_ETA
                and now - (notified_at[t.unit] or -math.huge) > NOTIFY_COOLDOWN then
                -- предупреждаем только о тех, кого не видно: видимого ты и так видишь
                notified_at[t.unit] = now
                pending_notify = ("%s может быть здесь через %d с"):format(t.label, floor(t.eta + 0.5))
            end
        end
    end
    threats, markers = ready, new_markers

    local notes = {}
    if #dead > 0 then
        notes[#notes + 1] = "мертвы: " .. table.concat(dead, ", ")
    end
    if #lost > 0 then
        notes[#notes + 1] = "не видно давно: " .. table.concat(lost, ", ")
    end
    footer = #notes > 0 and table.concat(notes, " · ") or nil

    -- Лог: список угроз и почему скрыты остальные невидимые - когда что-то из этого заметно меняется
    -- (не чаще раза в 5 с, телепорт к тебе - сразу), чтобы после матча было видно, что скрипт показывал
    -- и почему кого-то не было в окне; разовая строка диагностики - работают ли мапхак и чтение ТП у врагов.
    local hidden_texts = {}
    for i, entry in ipairs(hidden) do
        sig_parts[#sig_parts + 1] = entry[1]
        hidden_texts[i] = entry[2]
    end
    local signature = table.concat(sig_parts, ",")
    if signature ~= last_signature and (now - last_log_at > 5 or signature:find("!", 1, true)) then
        last_signature, last_log_at = signature, now
        if #log_parts > 0 or #hidden_texts > 0 then
            log("угрозы: %s%s", #log_parts > 0 and table.concat(log_parts, " | ") or "нет",
                #hidden_texts > 0 and (" || скрыты: " .. table.concat(hidden_texts, ", ")) or "")
        end
    end
    if not diag_done and stat.dormant > 0 then
        diag_done = true
        log("диагностика: невидимых %d, из них с позицией по мапхаку %d; ТП готов у %d; "
            .. "скрыты: видимых %d, соперников по линии %d, не идущих к тебе %d; рядом в тумане %d, "
            .. "активных рядом %d; моя зона %s", stat.dormant, stat.maphack, stat.tp, stat.visible, stat.residents,
            stat.calm, stat.near, stat.active, my_zone)
    end

    -- сколько стоит самый долгий путь - в лог, когда рекорд заметно вырос
    if path_ms > path_ms_logged + 0.5 then
        path_ms_logged = path_ms
        log("GridNav.BuildPath: до %.1f мс", path_ms)
    end
end

--#endregion

--#region Drawing

local PREVIEW <const> = {
    {
        entry = {
            icon = Icons.HeroPortrait("npc_dota_hero_nevermore"), icon_w = 44, icon_h = 25,
            title = "Shadow Fiend", tag = "~4 с", tag_color = URGENT, stripe = URGENT,
            chips = { CHIP_TP_LIVE }, subtitle = "Т1 низ, 1100 от тебя",
        },
    },
    {
        entry = {
            icon = Icons.HeroPortrait("npc_dota_hero_life_stealer"), icon_w = 44, icon_h = 25,
            title = "Lifestealer", tag = "~9 с", tag_color = SOON, stripe = SOON,
            chips = { CHIP_COMING }, subtitle = "лес, у нас",
        },
    },
    {
        entry = {
            icon = Icons.HeroPortrait("npc_dota_hero_riki"), icon_w = 44, icon_h = 25,
            title = "Riki", tag = "~3 с", tag_color = URGENT, stripe = URGENT,
            chips = { CHIP_NEAR }, subtitle = "низ, у нас",
        },
    },
    {
        entry = {
            icon = Icons.HeroPortrait("npc_dota_hero_puck"), icon_w = 44, icon_h = 25,
            title = "Puck", tag = "~11 с",
            chips = { CHIP_WALK, CHIP_TP, { text = "позиция 12с назад", color = STALE_COLOR } },
            subtitle = "мид, у них",
        },
    },
}

local function draw(list, note)
    panel.hint = ("до %d с"):format(ui.threshold:Get())
    panel:Begin()
    if #list == 0 then
        panel:Text(idle_note or "Никто не успевает", Menu.Style("primary_widgets_text"))
    end
    for _, t in ipairs(list) do
        panel:Entry(t.entry)
    end
    if note then
        panel:Note(note)
    end
    panel:End()
end

-- Метка на месте прибытия: кружок, дуга - сколько канала прошло, иконка героя и секунды до прибытия.
local function draw_markers()
    local now = game_now()
    local scale = Menu.Scale()
    local s = (scale and scale >= 50 and scale <= 300) and scale / 100 or 1
    local r = 28 * s
    local font_size = floor(16 * s + 0.5)
    for _, m in ipairs(markers) do
        local left = m.created + m.channel - now
        if left > -1 then
            local screen, on_screen = Render.WorldToScreen(m.pos)
            if on_screen then
                Render.FilledCircle(screen, r, MARKER_BG)
                Render.Circle(screen, r, URGENT, 3 * s, 270, min(1, max(0, 1 - left / m.channel)))
                if m.icon then
                    Render.ImageCentered(m.icon, screen, Vec2(32 * s, 32 * s), WHITE, 16 * s)
                end
                local text = left > 0 and ("%.1f"):format(left) or "здесь"
                local size = Render.TextSize(marker_font, font_size, text)
                Render.Text(marker_font, font_size, text,
                    Vec2(floor(screen.x - size.x / 2 + 0.5), floor(screen.y + r + 4 * s + 0.5)), WHITE)
            end
        end
    end
end

local function visible()
    if Menu.Opened() then
        return true -- при открытом меню окно видно всегда, чтобы его можно было передвинуть
    end
    local mode = ui.show:Get()
    if mode == 1 then
        return true
    end
    return mode == 0 and #threats > 0
end

--#endregion

--#region Callbacks

local every_tick = Timer.Every(TICK)

function gank.OnUpdate()
    tp_watch = ui.enabled:Get()
    if not tp_watch then
        return
    end
    -- таймер спрашиваем каждый кадр, чтобы внеочередной расчёт не сбивал его ритм
    local due = every_tick()
    if not due and not force_refresh then
        return
    end
    force_refresh = false
    local ok, err = pcall(refresh)
    if not ok and tostring(err) ~= last_error then
        last_error = tostring(err)
        log("error: %s", last_error)
    end
end

function gank.OnDraw()
    if not ui.enabled:Get() then
        return
    end
    if pending_notify then
        Render.CenteredNotification(pending_notify, 2)
        pending_notify = nil
    end
    if #markers > 0 then
        draw_markers()
    end
    if ui.minimap:Get() then
        for _, t in ipairs(threats) do
            if t.unit and t.pos then
                local c = t.color
                MiniMap.DrawHeroIcon(t.unit, t.pos, c and c.r or 255, c and c.g or 255, c and c.b or 255, 220, 600)
            end
        end
    end
    if visible() then
        draw(threats, footer)
    end
end

-- предпросмотр вне матча: как выглядит окно и где оно стоит
function gank.OnFrame()
    if ui.enabled:Get() and ui.preview:Get() and Menu.Opened() and not Engine.IsInGame() then
        draw(PREVIEW, "мертвы: Riki ~24 с")
    end
end

function gank.OnGameEnd()
    reset_match()
end

--#endregion

return gank
