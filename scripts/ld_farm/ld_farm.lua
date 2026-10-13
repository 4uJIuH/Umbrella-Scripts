--[[
    ~Lone druid auto-farm
    ~ v1.7
    -@-
    ~ кароч много людей просило скрипт на авто фарм за мейн перса, когда у тебя аган на мишке что бы бегать и разьебывать, вообще можно просто включать авто лес, но он выбирает не безопасные точки фарма, тут псведо умная система фармпатеррна реализованна, пару людей тестили отзывы положительны.!!!
    ~ dev: @sediksss // tester: @enffikk // ui: @flatixxx
]]

-- LDfarm v1.7: safe farming, Wisdom timing, Roar + TP escape, and configurable skill leveling.

local C = {}
local Lifecycle = {}
local Settings = {}
local Geometry = {}
local WorldState = {}
local Orders = {}
local Safety = {}
local Spells = {}
local SkillBuild = {}
local Farm = {}
local Stack = {}
local RuneControl = {}
local WisdomControl = {}
local Ui = {}
local Delivery = {}
local Escape = {}
local Threats = {}

-- Data: constants, localization, persistent UI and match state.

local script = {}

C.SCRIPT_VERSION = "v1.7"

-- Patch-sensitive spell/item names and TP slot; API signatures are documented locally.
C.ESCAPE = { roar = "lone_druid_savage_roar", tp = "item_tpscroll", tpSlot = 15,
    radius = 475, retry = 5, unreadyRetry = 0.25, tpStartTimeout = 2.0 }
C.THREATS = { scanInterval = 0.5, memory = 45, radius = 3500,
    releaseGrace = 3, riskLimit = 3.0, retargetGain = 0.35 }
C.SKILL_BUILD = { maxAbilityIndex = 31, confirmDelay = 0.35,
    maxAttempts = 3, retryDelay = 0.25, backoff = 3.0, idleDelay = 0.75 }

C.HERO_NAME = "npc_dota_hero_lone_druid"

C.SPIRIT_BEAR_ABILITY = "lone_druid_spirit_bear"

C.ENTANGLE_ABILITY = "lone_druid_entangle"

C.TRUE_FORM_ABILITY = "lone_druid_true_form"

C.TRUE_FORM_MODIFIER = "modifier_lone_druid_true_form"

C.CAMP_SCAN_INTERVAL = 0.25

C.CAMP_SCAN_RADIUS = 950

C.CAMP_LOOSE_RADIUS = 650

C.CAMP_EMPTY_GRACE_SECOND = 50

C.SAFE_CAMP_MATCH_RADIUS = 700

C.CAMP_RETARGET_MIN_GAIN = 450

C.CAMP_DANGER_MEMORY = 12

C.CAMP_DANGER_MIN_RADIUS = 1700

C.RUNE_SCAN_INTERVAL = 0.35

C.RUNE_MOVE_INTERVAL = 0.60

C.RUNE_PICKUP_INTERVAL = 0.35

C.RUNE_PICKUP_DISTANCE = 425

C.RUNE_TARGET_DISTANCE_GRACE = 600

C.RUNE_ALLIED_HALF_MARGIN = 250

C.RUNE_TARGET_TIMEOUT = 20

C.RUNE_CLOSE_TIMEOUT = 8

C.RUNE_DANGER_RETRY = 3

C.WISDOM = {
    firstSpawn = 420,
    interval = 420,
    preparationLead = 120,
    approachLead = 30,
    postSpawnTimeout = 90,
    activationGrace = 2,
    discoveryRetry = 5,
    arrivalRadius = 250,
    moveInterval = 0.50,
    holdInterval = 0.50,
    shrineName = "npc_dota_xp_fountain",
    activeParticle = "particles/base_static/experience_shrine_active.vpcf",
    ambientParticle = "particles/base_static/experience_shrine_ambient_endcap.vpcf",
    camps = {
        radiant = {
            camp_n8313_n553 = true,
            camp_n8023_n1838 = true,
        },
        dire = {
            camp_7928_n120 = true,
            camp_8430_1263 = true,
        },
    },
}

C.THINK_INTERVAL = 0.10

C.FOUNTAIN_MOVE_INTERVAL = 0.50

C.FOUNTAIN_HOLD_INTERVAL = 1.00

C.PRESPAWN_MOVE_INTERVAL = 0.35

C.PRESPAWN_HOLD_INTERVAL = 0.60

C.FARM_TRAVEL_INTERVAL = 0.90

C.FARM_ENTER_INTERVAL = 0.60

C.ATTACK_ORDER_INTERVAL = 0.50

C.STACK_ORDER_INTERVAL = 0.18

C.ABILITY_ORDER_INTERVAL = 0.15

C.FARM_ABILITY_RETRY_INTERVAL = 0.50

C.CAMP_EMPTY_CONFIRMATION = 0.60

C.PRESPAWN_ARRIVAL_BUFFER = 2.0

C.PRESPAWN_PATH_FACTOR = 1.25

C.PRESPAWN_BOX_MARGIN = 260

C.NEAR_RESPAWN_WAIT_SECOND = 52.0

C.HEALTH_SAMPLE_INTERVAL = 0.4

C.HEALTH_RECOVERY_WINDOW = 4.0

C.HEALTH_RECOVERY_MIN_RATE = 1.0

C.HEALTH_RECOVERY_FLOOR_OFFSET = 8

C.HEALTH_RECOVERY_TARGET_OFFSET = 10

C.STACK_PULL_CLAMP_MIN = 54.6

C.STACK_PULL_CLAMP_MAX = 55.9

C.STACK_PULL_OUTSIDE_MIN = 55.4

C.STACK_ACTION_WINDOW = 1.5

C.STACK_DELAY_2 = 0.1

C.STACK_DELAY_3 = 0.3

C.STACK_EXIT_BOX_MARGIN = 800

C.STACK_FINISH_SECOND = 1.2

C.CAMP_META = {
    [0] = { basePull = 55.5 },
    [1] = { basePull = 55.2 },
    [2] = { basePull = 55.0 },
    [3] = { basePull = 54.8 },
}

C.PACK_MEMBERS = {
    ["npc_dota_neutral_centaur_khan"] = 1.0,
    ["npc_dota_neutral_alpha_wolf"] = 1.0,
    ["npc_dota_neutral_satyr_hellcaller"] = 1.0,
    ["npc_dota_neutral_satyr_soulstealer"] = 1.0,
    ["npc_dota_neutral_ogre_magi"] = 1.0,
    ["npc_dota_neutral_polar_furbolg_ursa_warrior"] = 1.0,
    ["npc_dota_neutral_enraged_wildkin"] = 1.0,
    ["npc_dota_neutral_harpy_storm"] = 1.0,
    ["npc_dota_neutral_kobold_taskmaster"] = 1.0,
    ["npc_dota_neutral_forest_troll_high_priest"] = 1.0,
    ["npc_dota_neutral_dark_troll_warlord"] = 1.0,
    ["npc_dota_neutral_black_dragon"] = 1.0,
    ["npc_dota_neutral_big_thunder_lizard"] = 1.0,
    ["npc_dota_neutral_granite_golem"] = 1.0,
    ["npc_dota_neutral_ice_shaman"] = 1.0,
    ["npc_dota_neutral_mud_golem"] = 0.5,
    ["npc_dota_neutral_ghost"] = 0.5,
    ["npc_dota_neutral_fel_beast"] = 0.34,
    ["npc_dota_neutral_gnoll_assassin"] = 0.16,
}

C.FOUNTAIN_STAND_OFFSET = 325

C.FOUNTAIN_REACHED_RADIUS = 500

C.LANE_PUSH_SCAN_INTERVAL = 0.5

C.LANE_PUSH_T1_FALLBACK_OFFSET = 3000

C.LANE_PUSH_PROGRESS_MARGIN = 450

C.LANE_PUSH_MIN_CREEPS = 2

C.LANE_PUSH_GRACE = 8

C.FARM_LANES = { "top", "mid", "bot" }

C.TIER2_REFERENCE_POSITIONS = {
    radiant = {
        top = { x = -6501, y = -872 },
        mid = { x = -3190, y = -2926 },
        bot = { x = -360, y = -6256 },
    },
    dire = {
        top = { x = -128, y = 6016 },
        mid = { x = 2496, y = 2112 },
        bot = { x = 6400, y = 384 },
    },
}

C.ALL_CAMP_LAYOUTS = {
    { id = "camp_186_n5197", x = 186, y = -5197, lane = "bot", owner = "radiant" },
    { id = "camp_n1454_n3356", x = -1454, y = -3356, lane = "mid", owner = "radiant", defaultRadiant = true },
    { id = "camp_3392_n1408", x = 3392, y = -1408, lane = "bot", owner = "dire" },
    { id = "camp_7928_n120", x = 7928, y = -120, lane = "bot", owner = "dire", defaultDire = true },
    { id = "camp_n4824_3915", x = -4824, y = 3915, lane = "top", owner = "radiant" },
    {
        id = "camp_4649_n3699",
        x = 4649,
        y = -3699,
        lane = "bot",
        owner = "dire",
        additionalOwner = "radiant",
        defaultRadiant = true,
    },
    { id = "camp_3978_n5027", x = 3978, y = -5027, lane = "bot", owner = "radiant" },
    { id = "camp_n2596_3850", x = -2596, y = 3850, lane = "top", owner = "dire" },
    { id = "camp_2768_n8336", x = 2768, y = -8336, lane = "bot", owner = "radiant" },
    { id = "camp_n3911_4829", x = -3911, y = 4829, lane = "top", owner = "dire" },
    { id = "camp_1922_n3975", x = 1922, y = -3975, lane = "bot", owner = "radiant" },
    { id = "camp_336_7696", x = 336, y = 7696, lane = "top", owner = "dire", defaultDire = true },
    { id = "camp_n2880_7376", x = -2880, y = 7376, lane = "top", owner = "dire" },
    { id = "camp_n2415_n8402", x = -2415, y = -8402, lane = "bot", owner = "radiant", defaultRadiant = true, fallbackTeam = "radiant" },
    { id = "camp_n8023_n1838", x = -8023, y = -1838, lane = "top", owner = "radiant", defaultRadiant = true },
    { id = "camp_8430_1263", x = 8430, y = 1263, lane = "bot", owner = "dire", defaultDire = true },
    { id = "camp_n8313_n553", x = -8313, y = -553, lane = "top", owner = "radiant", defaultRadiant = true },
    { id = "camp_2016_7896", x = 2016, y = 7896, lane = "top", owner = "dire", defaultDire = true, fallbackTeam = "dire" },
    { id = "camp_4416_n8432", x = 4416, y = -8432, lane = "bot", owner = "radiant" },
    { id = "camp_n4208_8336", x = -4208, y = 8336, lane = "top", owner = "dire" },
    { id = "camp_4352_48", x = 4352, y = 48, lane = "bot", owner = "dire" },
    { id = "camp_n5015_n96", x = -5015, y = -96, lane = "top", owner = "radiant" },
    { id = "camp_n852_4940", x = -852, y = 4940, lane = "top", owner = "dire" },
    { id = "camp_n720_n7696", x = -720, y = -7696, lane = "bot", owner = "radiant", defaultRadiant = true },
    { id = "camp_n4013_992", x = -4013, y = 992, lane = "top", owner = "radiant" },
    { id = "camp_1064_2580", x = 1064, y = 2580, lane = "mid", owner = "dire", defaultDire = true },
    { id = "camp_1224_4176", x = 1224, y = 4176, lane = "mid", owner = "dire", defaultDire = true },
    { id = "camp_n1983_n4815", x = -1983, y = -4815, lane = "mid", owner = "radiant", defaultRadiant = true },
}

C.CAMP_SELECTION_CONFIG = "lone_druid_auto_farm_camps"

C.SETTINGS_CONFIG = "lone_druid_auto_farm_settings"

C.ENEMY_ALERT_SOUND = "sounds/ui/ping_warning.vsnd_c"

C.ENEMY_ALERT_VOLUME = 0.3

C.ENEMY_ALERT_DURATION = 2.5

C.ENEMY_ALERT_COOLDOWN = 5

C.RADIUS_CIRCLE_SEGMENTS = 48

C.RADIUS_CIRCLE_Z_OFFSET = 25

C.CAMP_PANEL_WORLD_MIN = -8800

C.CAMP_PANEL_WORLD_MAX = 8800

C.CAMP_PANEL_CLICK_DEBOUNCE_FRAMES = 8

C.CAMP_PANEL_MAP_PATHS = {
    "panorama/images/minimap/dotamap_psd.vtex_c",
    "panorama/images/textures/minimap_game_png.vtex_c",
}

C.CAMP_PANEL_FALLBACK_SVG = [[
<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
  <defs>
    <linearGradient id="g" x1="0" y1="1" x2="1" y2="0">
      <stop offset="0" stop-color="#456e42"/>
      <stop offset="0.46" stop-color="#27372f"/>
      <stop offset="0.54" stop-color="#3a4447"/>
      <stop offset="1" stop-color="#50585b"/>
    </linearGradient>
  </defs>
  <rect width="512" height="512" rx="10" fill="#17201d"/>
  <path d="M0 512V214L64 180l70 18 72-46 57 30 64-42 74 16 111-72v428z" fill="url(#g)"/>
  <path d="M-16 352C88 306 120 262 192 248s114 30 184-8 98-81 152-96" fill="none" stroke="#182d3b" stroke-width="38" opacity=".92"/>
  <path d="M-16 352C88 306 120 262 192 248s114 30 184-8 98-81 152-96" fill="none" stroke="#34576a" stroke-width="17" opacity=".7"/>
  <path d="M32 470L470 32M22 418L418 22" stroke="#93a18f" stroke-width="9" opacity=".18"/>
  <circle cx="46" cy="466" r="25" fill="#76a75f" opacity=".75"/>
  <circle cx="466" cy="46" r="25" fill="#b14f4a" opacity=".75"/>
</svg>
]]

local localization = qLocalization.new({
    en = {
        ldaf = {
            groups = {
                main = "Main",
                farming = "Farming & Skills",
                safety = "Safety & Retreat",
                interface = "Interface & Overlays",
            },
            common = {
                settings = "Settings",
            },
            menu = {
                escape_roar_tp = "Roar + TP when attacked",
                escape_roar_tp_tip = "When an enemy gets close (475 units or less), Lone Druid uses Savage Roar to drive them away, then starts a TP to the fountain.\n\nIf TP is unavailable, he uses Roar and retreats on foot. If Roar is unavailable, he tries to TP without it. Your manual order cancels the sequence and pauses it for at least 3 seconds.",
                cautious_farm = "Safe farm",
                cautious_farm_tip = "Prefer protected camps near base and away from recent enemy sightings. Suspend rune detours; wait at base if no safe camp is available.",
                missing_count = "Number of missing enemies",
                missing_seconds = "Seconds without vision",
                enabled = "Enable auto-farm",
                enabled_tip = "Farm orders control only Lone Druid. The courier option may control the local courier; Spirit Bear is only a delivery target and is never commanded.",
                toggle_bind = "Toggle hotkey",
                toggle_bind_tip = "Press once to enable or disable Lone Druid auto-farm.",
                manual_pause = "Pause after a manual order",
                manual_pause_tip = "Your manual Lone Druid order takes priority for the selected number of seconds.",
                require_bear_scepter = "Only with Aghanim on Spirit Bear",
                require_bear_scepter_tip = "Pauses automation until the living Spirit Bear has a purchased or consumed Aghanim's Scepter.",
                auto_courier_bear = "Deliver items to Spirit Bear",
                auto_courier_bear_tip = "Uses the local courier to deliver stash items only to the living Spirit Bear. A manual courier order pauses this automation for 3 seconds; if the bear or items are missing, the courier is left untouched.",
                auto_true_form = "Auto True Form",
                auto_true_form_tip = "Uses True Form when Lone Druid starts farming a living camp.",
                true_form_low_hp_only = "Use Auto True Form only at low health",
                true_form_low_hp_only_tip = "When enabled, Auto True Form waits until Lone Druid's health reaches the configured percentage.",
                true_form_always = "Always (100%)",
                true_form_low_hp = "Health threshold",
                true_form_low_hp_tip = "When set to 100%, True Form is always used when farming. Set below 100% to activate True Form only when health drops to this percentage or lower (including during retreat).",
                auto_entangle = "Auto Entangle on creeps",
                auto_entangle_tip = "Uses Entangle on neutrals within cast range for roots and additional damage.",
                auto_stack = "Auto-stack camps",
                auto_stack_tip = "Pulls surviving neutrals outside the spawn box according to the camp timing.",
                auto_ability_mana = "Minimum mana for auto skills",
                auto_ability_mana_tip = "True Form and Entangle are not used while Lone Druid's mana percentage is below this value. Set to 0% to disable the limit.",
                auto_skill_build = "Auto-leveling",
                auto_skill_build_tip = "Spends available ability points only on True Form and the talents selected below. Regular abilities are never leveled. Starts only when auto-farm is actively pursuing an eligible camp.",
                auto_ultimate = "Auto-level True Form",
                auto_ultimate_tip = "Levels True Form whenever the hero level allows it.",
                talent_10 = "Level 10 talent",
                talent_15 = "Level 15 talent",
                talent_20 = "Level 20 talent",
                talent_25 = "Level 25 talent",
                talent_choice_tip = "Choose the side shown in Lone Druid's talent tree. Leave this at Do not level to spend the point manually.",
                talent_none = "Do not level",
                talent_left = "Left",
                talent_right = "Right",
                auto_runes = "Auto-runes",
                auto_runes_tip = "Master switch for the enabled Bounty and Wisdom automations below.",
                bounty_runes = "Auto-Bounty",
                bounty_runes_tip = "Allows automatic collection of bounty runes.",
                wisdom_runes = "Auto-Wisdom",
                wisdom_runes_tip = "Safely prepares for your team's Wisdom Shrine without interrupting a living camp or an active stack.",
                rune_max_distance = "Maximum rune distance",
                rune_max_distance_tip = "The maximum straight-line distance at which Lone Druid may divert to a rune.",
                enemy_radius = "Enemy detection radius",
                enemy_radius_tip = "The script can detect only living and visible enemy heroes.",
                show_radius = "Show detection radius",
                show_radius_tip = "Draws the current enemy detection radius around Lone Druid.",
                low_hp = "Retreat below health",
                low_hp_tip = "Low health always triggers a retreat.",
                low_mana = "Retreat below mana",
                low_mana_tip = "Retreats to base when mana reaches this percentage. Set to 0% to disable mana retreat.",
                show_camp_panel = "Camp selection panel",
                show_camp_panel_tip = "Opens an in-game panel. Left-click map markers to toggle camps and drag the panel by its header.",
                camp_panel_scale = "Panel size",
                camp_panel_scale_tip = "Changes the size of the camp map and its interface elements.",
                show_status = "Status overlay panel",
                show_status_tip = "Shows mode, camp, health, wait reason, next action, and Wisdom/stack timers. Drag the panel with the left mouse button.",
                status_scale = "Panel size",
                status_scale_tip = "Changes the size of the movable auto-farm status panel.",
            },
            panel = {
                title = "LDfarm v1.7",
                radiant = "Radiant",
                dire = "Dire",
                camp_label = "camp %02d • %s • %s",
                mode = "Mode",
                camp = "Camp",
                health = "Health",
                reason = "Reason",
                next = "Next",
                wisdom = "Wisdom",
                stack = "Stack",
            },
            alert = {
                enemy = "ENEMY NEAR LONE DRUID!",
            },
            status = {
                escape_roar = "Emergency Roar",
                escape_tp = "Teleporting to base",
                safe_farm = "Safe farm",
                disabled = "disabled",
                waiting_scepter = "waiting for Aghanim",
                retreat = "retreating to base",
                manual_pause = "manual control pause",
                farming = "farming camp",
                moving = "moving to camp",
                fountain = "waiting at fountain",
                preposition = "moving early for respawn",
                stacking = "stacking camp",
                healing = "recovering near jungle",
                rune_bounty = "collecting bounty rune",
                wisdom_approach = "moving to Wisdom Shrine",
                wisdom_wait = "waiting for Wisdom Shrine",
                wisdom_claim = "claiming Wisdom Shrine",
                idle = "checking route",
                reason_active = "action in progress",
                reason_manual = "manual control",
                reason_scepter = "Spirit Bear has no Aghanim",
                reason_no_camp = "no safe available camp",
                reason_respawn = "waiting for camp respawn",
                reason_wisdom = "waiting for Wisdom activation",
                reason_route = "searching for an available camp",
                reason_enemy = "enemy nearby",
                reason_health = "low health",
                reason_mana = "low mana",
                next_enable = "enable auto-farm",
                next_scepter = "wait for Spirit Bear's Aghanim",
                next_resume = "resume farming in %s",
                next_recover = "resume farming after recovery",
                next_enter_camp = "enter camp after :00",
                next_wisdom = "claim Wisdom, then resume farming",
                next_saved_camp = "resume saved camp",
                next_finish_camp = "finish current camp",
                next_find_camp = "select next safe camp",
                countdown = "in %s",
                now = "now",
                wisdom_skip = "%s; skipped: %s",
                skip_unsafe = "unsafe near shrine",
                skip_timeout = "arrival window expired",
                skip_escape = "emergency escape",
                skip_safety = "retreat took priority",
                skip_inactive = "shrine already inactive",
                skip_unknown = "unknown reason",
            },
            lanes = {
                top = "top",
                mid = "mid",
                bot = "bottom",
            },
        },
    },
    ru = {
        ldaf = {
            groups = {
                main = "Основное",
                farming = "Фарм и способности",
                safety = "Безопасность и отход",
                interface = "Интерфейс и оверлеи",
            },
            common = {
                settings = "Настройки",
            },
            menu = {
                escape_roar_tp = "Roar + TP при нападении",
                escape_roar_tp_tip = "Когда враг оказывается рядом (475 или ближе), Lone Druid использует Savage Roar, чтобы отогнать его, и сразу после крика начинает TP на фонтан.\n\nЕсли TP недоступен, герой крикнет и побежит к базе. Если крик недоступен, попробует сделать TP без него. Ваш ручной приказ отменяет связку и приостанавливает её минимум на 3 секунды.",
                cautious_farm = "Сейф фарм",
                cautious_farm_tip = "Выбирать защищённые кемпы ближе к базе и дальше от недавних врагов. Не ходить за рунами; ждать на базе, если безопасных кемпов нет.",
                missing_count = "Количество пропавших врагов",
                missing_seconds = "Секунд без видимости",
                enabled = "Включить автофарм",
                enabled_tip = "Приказы фарма управляют только Lone Druid. Опция доставки может управлять локальным курьером; Spirit Bear служит только целью доставки и не получает команд.",
                toggle_bind = "Горячая клавиша",
                toggle_bind_tip = "Одно нажатие включает или выключает автофарм Lone Druid.",
                manual_pause = "Пауза после ручного приказа",
                manual_pause_tip = "Ваш ручной приказ Lone Druid будет приоритетным указанное число секунд.",
                require_bear_scepter = "Только с аганимом на медведе",
                require_bear_scepter_tip = "Приостанавливает автоматику, пока у живого Spirit Bear нет купленного или поглощённого Aghanim's Scepter.",
                auto_courier_bear = "Доставлять предметы курьером медведю",
                auto_courier_bear_tip = "Локальный курьер доставляет предметы из тайника только живому Spirit Bear. Ручной приказ курьеру приостанавливает автоматику на 3 секунды; если нет медведя или предметов, курьер не трогается.",
                auto_true_form = "Авто True Form",
                auto_true_form_tip = "Использует True Form, когда Lone Druid начинает фармить живой кемп.",
                true_form_low_hp_only = "Использовать Auto True Form только при низком здоровье",
                true_form_low_hp_only_tip = "Если включено, Auto True Form ждёт, пока здоровье Lone Druid не опустится до заданного процента.",
                true_form_always = "Всегда (100%)",
                true_form_low_hp = "Порог здоровья",
                true_form_low_hp_tip = "При 100% True Form используется всегда при фарме кемпа. Ниже 100% форма активируется только при падении здоровья до этого процента или ниже (в том числе при отходе).",
                auto_entangle = "Авто Entangle по крипам",
                auto_entangle_tip = "Использует Entangle по нейтралам в радиусе каста для корней и дополнительного урона.",
                auto_stack = "Автостак кемпов",
                auto_stack_tip = "Выводит выживших нейтралов за спавн-бокс по таймингу типа кемпа.",
                auto_ability_mana = "Минимум маны для автоскиллов",
                auto_ability_mana_tip = "True Form и Entangle не используются, пока процент маны Lone Druid ниже выбранного значения. 0% отключает ограничение.",
                auto_skill_build = "Авто-прокачка",
                auto_skill_build_tip = "Тратит доступные очки только на True Form и выбранные ниже таланты. Обычные способности никогда не прокачиваются. Запускается только когда автофарм уже идёт к доступному кемпу.",
                auto_ultimate = "Автопрокачка True Form",
                auto_ultimate_tip = "Прокачивает True Form, как только это разрешает уровень героя.",
                talent_10 = "Талант 10 уровня",
                talent_15 = "Талант 15 уровня",
                talent_20 = "Талант 20 уровня",
                talent_25 = "Талант 25 уровня",
                talent_choice_tip = "Выберите сторону из дерева талантов Lone Druid. Оставьте «Не прокачивать», чтобы потратить очко вручную.",
                talent_none = "Не прокачивать",
                talent_left = "Левый",
                talent_right = "Правый",
                auto_runes = "Авто-руны",
                auto_runes_tip = "Главный переключатель для включённых ниже автоматизаций Bounty и Wisdom.",
                bounty_runes = "Авто-Bounty",
                bounty_runes_tip = "Разрешает автоматически забирать руны богатства.",
                wisdom_runes = "Авто-Wisdom",
                wisdom_runes_tip = "Безопасно готовится к святилищу Wisdom своей команды, не прерывая живой кемп или активный стак.",
                rune_max_distance = "Максимальная дистанция до руны",
                rune_max_distance_tip = "Максимальная дистанция по прямой, с которой Lone Druid может отвлечься на руну.",
                enemy_radius = "Радиус обнаружения врага",
                enemy_radius_tip = "Скрипт может обнаружить только живых и видимых вражеских героев.",
                show_radius = "Показывать радиус",
                show_radius_tip = "Рисует текущий радиус обнаружения врага вокруг Lone Druid.",
                low_hp = "Отход при здоровье ниже",
                low_hp_tip = "Низкое здоровье всегда вызывает отход.",
                low_mana = "Отход при мане ниже",
                low_mana_tip = "Отправляет на базу, когда мана достигает этого процента. 0% отключает отход по мане.",
                show_camp_panel = "Панель выбора кемпов",
                show_camp_panel_tip = "Открывает отдельную панель поверх игры. Точки на карте переключаются левой кнопкой мыши, панель переносится за заголовок.",
                camp_panel_scale = "Размер панели",
                camp_panel_scale_tip = "Меняет размер карты и элементов панели выбора кемпов.",
                show_status = "Панель статуса",
                show_status_tip = "Показывает режим, кемп, здоровье, причину ожидания, следующее действие и таймеры Wisdom/стака. Панель перемещается левой кнопкой мыши.",
                status_scale = "Размер панели",
                status_scale_tip = "Меняет размер перемещаемой панели автофарма.",
            },
            panel = {
                title = "LDfarm v1.7",
                radiant = "Radiant",
                dire = "Dire",
                camp_label = "кемп %02d • %s • %s",
                mode = "Режим",
                camp = "Кемп",
                health = "Здоровье",
                reason = "Причина",
                next = "Дальше",
                wisdom = "Wisdom",
                stack = "Стак",
            },
            alert = {
                enemy = "ВРАГ РЯДОМ С LONE DRUID!",
            },
            status = {
                escape_roar = "Экстренный крик",
                escape_tp = "Телепорт на базу",
                safe_farm = "Сейф фарм",
                disabled = "выключен",
                waiting_scepter = "ждем аганима",
                retreat = "отход на базу",
                manual_pause = "пауза ручного контроля",
                farming = "farming camp",
                moving = "переход к кемпу",
                fountain = "ожидание на фонтане",
                preposition = "ранний выход к респавну",
                stacking = "стак кемпа",
                healing = "восстановление рядом с лесом",
                rune_bounty = "забираем руну богатства",
                wisdom_approach = "идём к святилищу мудрости",
                wisdom_wait = "ожидаем активацию святилища",
                wisdom_claim = "получаем опыт у святилища",
                idle = "проверка маршрута",
                reason_active = "выполняется действие",
                reason_manual = "ручной контроль",
                reason_scepter = "нет Aghanim у медведя",
                reason_no_camp = "нет безопасного доступного кемпа",
                reason_respawn = "ожидание респавна кемпа",
                reason_wisdom = "ожидание активации Wisdom",
                reason_route = "поиск доступного кемпа",
                reason_enemy = "враг рядом",
                reason_health = "мало здоровья",
                reason_mana = "мало маны",
                next_enable = "включить автофарм",
                next_scepter = "дождаться Aghanim у медведя",
                next_resume = "возобновить фарм через %s",
                next_recover = "вернуться к фарму после восстановления",
                next_enter_camp = "зайти в кемп после :00",
                next_wisdom = "забрать Wisdom и вернуться к фарму",
                next_saved_camp = "вернуться к сохранённому кемпу",
                next_finish_camp = "закончить текущий кемп",
                next_find_camp = "выбрать следующий безопасный кемп",
                countdown = "через %s",
                now = "сейчас",
                wisdom_skip = "%s; пропуск: %s",
                skip_unsafe = "опасно у точки",
                skip_timeout = "окно подхода закончилось",
                skip_escape = "экстренный отход",
                skip_safety = "отход важнее Wisdom",
                skip_inactive = "точка уже неактивна",
                skip_unknown = "неизвестная причина",
            },
            lanes = {
                top = "верх",
                mid = "мид",
                bot = "низ",
            },
        },
    },
})

local Menu = localization.WrapLibrary(Menu)

C.UI_TEXT = {
    tab = "~auto-ld",
    groupMain = "ldaf.groups.main",
    groupFarming = "ldaf.groups.farming",
    groupSafety = "ldaf.groups.safety",
    groupInterface = "ldaf.groups.interface",
    enabledSettings = "ldaf.common.settings",
    radiusSettings = "ldaf.common.settings",
    statusSettings = "ldaf.common.settings",
    campPanelSettings = "ldaf.common.settings",
    enabled = "ldaf.menu.enabled",
    enabledTip = "ldaf.menu.enabled_tip",
    toggleBind = "ldaf.menu.toggle_bind",
    toggleBindTip = "ldaf.menu.toggle_bind_tip",
    manualPause = "ldaf.menu.manual_pause",
    manualPauseTip = "ldaf.menu.manual_pause_tip",
    requireBearScepter = "ldaf.menu.require_bear_scepter",
    requireBearScepterTip = "ldaf.menu.require_bear_scepter_tip",
    autoCourierBear = "ldaf.menu.auto_courier_bear",
    autoCourierBearTip = "ldaf.menu.auto_courier_bear_tip",
    autoTrueForm = "ldaf.menu.auto_true_form",
    autoTrueFormTip = "ldaf.menu.auto_true_form_tip",
    trueFormLowHpOnly = "ldaf.menu.true_form_low_hp_only",
    trueFormLowHpOnlyTip = "ldaf.menu.true_form_low_hp_only_tip",
    trueFormLowHp = "ldaf.menu.true_form_low_hp",
    trueFormLowHpTip = "ldaf.menu.true_form_low_hp_tip",
    autoEntangle = "ldaf.menu.auto_entangle",
    autoEntangleTip = "ldaf.menu.auto_entangle_tip",
    autoStack = "ldaf.menu.auto_stack",
    autoStackTip = "ldaf.menu.auto_stack_tip",
    autoAbilityMana = "ldaf.menu.auto_ability_mana",
    autoAbilityManaTip = "ldaf.menu.auto_ability_mana_tip",
    autoRunes = "ldaf.menu.auto_runes",
    autoRunesTip = "ldaf.menu.auto_runes_tip",
    bountyRunes = "ldaf.menu.bounty_runes",
    bountyRunesTip = "ldaf.menu.bounty_runes_tip",
    wisdomRunes = "ldaf.menu.wisdom_runes",
    wisdomRunesTip = "ldaf.menu.wisdom_runes_tip",
    runeMaxDistance = "ldaf.menu.rune_max_distance",
    runeMaxDistanceTip = "ldaf.menu.rune_max_distance_tip",
    enemyRadius = "ldaf.menu.enemy_radius",
    enemyRadiusTip = "ldaf.menu.enemy_radius_tip",
    showRadius = "ldaf.menu.show_radius",
    showRadiusTip = "ldaf.menu.show_radius_tip",
    lowHp = "ldaf.menu.low_hp",
    lowHpTip = "ldaf.menu.low_hp_tip",
    lowMana = "ldaf.menu.low_mana",
    lowManaTip = "ldaf.menu.low_mana_tip",
    showCampPanel = "ldaf.menu.show_camp_panel",
    showCampPanelTip = "ldaf.menu.show_camp_panel_tip",
    campPanelScale = "ldaf.menu.camp_panel_scale",
    campPanelScaleTip = "ldaf.menu.camp_panel_scale_tip",
    showStatus = "ldaf.menu.show_status",
    showStatusTip = "ldaf.menu.show_status_tip",
    statusScale = "ldaf.menu.status_scale",
    statusScaleTip = "ldaf.menu.status_scale_tip",
    campPanelTitle = "ldaf.panel.title",
    campPanelRadiant = "ldaf.panel.radiant",
    campPanelDire = "ldaf.panel.dire",
    campPanelCampLabel = "ldaf.panel.camp_label",
    enemyAlert = "ldaf.alert.enemy",
    statusDisabled = "ldaf.status.disabled",
    statusByActivity = {
        escape_roar = "ldaf.status.escape_roar",
        escape_tp = "ldaf.status.escape_tp",
        waiting_scepter = "ldaf.status.waiting_scepter",
        retreat = "ldaf.status.retreat",
        manual_pause = "ldaf.status.manual_pause",
        farming = "ldaf.status.farming",
        moving = "ldaf.status.moving",
        fountain = "ldaf.status.fountain",
        preposition = "ldaf.status.preposition",
        stacking = "ldaf.status.stacking",
        healing = "ldaf.status.healing",
        rune_bounty = "ldaf.status.rune_bounty",
        wisdom_approach = "ldaf.status.wisdom_approach",
        wisdom_wait = "ldaf.status.wisdom_wait",
        wisdom_claim = "ldaf.status.wisdom_claim",
        idle = "ldaf.status.idle",
    },
    statusModeLabel = "ldaf.panel.mode",
    statusCampLabel = "ldaf.panel.camp",
    statusHealthLabel = "ldaf.panel.health",
    statusReasonLabel = "ldaf.panel.reason",
    statusNextLabel = "ldaf.panel.next",
    statusWisdomLabel = "ldaf.panel.wisdom",
    statusStackLabel = "ldaf.panel.stack",
    statusReasonByActivity = {
        waiting_scepter = "ldaf.status.reason_scepter",
        manual_pause = "ldaf.status.reason_manual",
        retreat = "ldaf.status.reason_active",
        fountain = "ldaf.status.reason_no_camp",
        preposition = "ldaf.status.reason_respawn",
        wisdom_wait = "ldaf.status.reason_wisdom",
        wisdom_claim = "ldaf.status.reason_wisdom",
        idle = "ldaf.status.reason_route",
    },
    statusNextByActivity = {
        waiting_scepter = "ldaf.status.next_scepter",
        retreat = "ldaf.status.next_recover",
        healing = "ldaf.status.next_recover",
        escape_roar = "ldaf.status.next_recover",
        escape_tp = "ldaf.status.next_recover",
        fountain = "ldaf.status.next_find_camp",
        preposition = "ldaf.status.next_enter_camp",
        wisdom_approach = "ldaf.status.next_wisdom",
        wisdom_wait = "ldaf.status.next_wisdom",
        wisdom_claim = "ldaf.status.next_wisdom",
        rune_bounty = "ldaf.status.next_saved_camp",
        farming = "ldaf.status.next_finish_camp",
        moving = "ldaf.status.next_finish_camp",
        stacking = "ldaf.status.next_finish_camp",
        idle = "ldaf.status.next_find_camp",
    },
    wisdomSkipByReason = {
        unsafe = "ldaf.status.skip_unsafe",
        timeout = "ldaf.status.skip_timeout",
        escape = "ldaf.status.skip_escape",
        safety = "ldaf.status.skip_safety",
        shrine_inactive = "ldaf.status.skip_inactive",
    },
    lanes = {
        top = "ldaf.lanes.top",
        mid = "ldaf.lanes.mid",
        bot = "ldaf.lanes.bot",
    },
}

local options = {
    ready = false,
}

Ui.radiusCircleOffsets = {}

Ui.status = {
    x = nil,
    y = nil,
    dragging = false,
    dragOffsetX = 0,
    dragOffsetY = 0,
    radiusColor = nil,
}

Ui.colors = {}

Ui.panel = {
    font = nil,
    iconFont = nil,
    mapImage = nil,
    fallbackImage = nil,
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
    capturingMouse = false,
    mouseHeld = false,
    lastActionFrame = -1000,
    dragOffsetX = 0,
    dragOffsetY = 0,
    markers = {},
    toggleBounds = nil,
    collapseBounds = nil,
    open = 0,
    mini = nil,
    miniSide = nil,
    miniAnim = 0,
    edgeSide = nil,
    mapHidden = false,
    mapAnim = 1,
    toggleAnim = 0,
    togglePress = 0,
    chevronAnim = 0,
    pinAnim = 0,
    pinBounds = nil,
    markerAnim = {},
    markerOn = {},
}

Settings.campSelections = {
    radiant = {},
    dire = {},
}

Settings.campLayoutsBySide = {
    radiant = {},
    dire = {},
}

Settings.attemptedCampSelectionSide = nil

Settings.loadedCampSelectionSide = nil

local state = {
    hero = nil,
    player = nil,
    team = nil,
    alliedFort = nil,
    enemyFort = nil,
    alliedFountain = nil,
    fountainPosition = nil,
    tier2Alive = {
        top = false,
        mid = false,
        bot = false,
    },
    enemyTier2Positions = {
        top = nil,
        mid = nil,
        bot = nil,
    },
    enemyTier1Positions = {
        top = nil,
        mid = nil,
        bot = nil,
    },
    lanePushed = {
        top = false,
        mid = false,
        bot = false,
    },
    lanePushedUntil = {
        top = 0,
        mid = 0,
        bot = 0,
    },
    camps = {},
    campsReady = false,
    targetCamp = nil,
    visited = {},
    campMinute = -1,
    arrivedAt = nil,
    attackTarget = nil,
    nextThinkAt = 0,
    nextOrderAt = 0,
    nextWorldScanAt = 0,
    nextTowerScanAt = 0,
    nextLanePushScanAt = 0,
    nextCampScanAt = 0,
    nextUltimateAt = 0,
    nextEntangleAt = 0,
    nextRuneScanAt = 0,
    targetRune = nil,
    targetRunePosition = nil,
    runeTargetExpiresAt = 0,
    runeCloseSince = nil,
    runePickupIssued = false,
    ignoredRunes = {},
    trueFormGraceUntil = 0,
    manualPauseUntil = 0,
    nextEnemyAlertAt = 0,
    lastEnemySeenAt = -100,
    enemyWasNear = false,
    retreating = false,
    retreatReason = nil,
    bearGateOpen = nil,
    wasEnabled = false,
    lastGameTime = -1,
    lastHealthSample = nil,
    lastHealthSampleAt = 0,
    healthRecoveryRate = 0,
    healthRecoveryActive = false,
    activity = "idle",
    preSpawnSeconds = nil,
    preSpawnCamp = nil,
    preSpawnPosition = nil,
    preSpawnTargetMinute = -1,
    stacking = false,
    stackCamp = nil,
    stackMinute = -1,
    stackStartedAt = 0,
    stackPullAt = 0,
    stackPullPosition = nil,
    courierDelivery = {
        thinkInterval = 0.50,
        orderInterval = 1.50,
        manualPause = 3.0,
        abilities = {
            "courier_take_stash_and_transfer_items",
            "courier_transfer_items_to_other_player",
        },
        courier = nil,
        nextThinkAt = 0,
        nextOrderAt = 0,
        manualPauseUntil = 0,
        abilityMissingLogged = false,
    },
}

-- Lifecycle ------------------------------------------------------------

function Lifecycle.bridgeLog(level, message, data)
    if ai_bridge ~= nil and ai_bridge.mcp_log ~= nil then
        ai_bridge.mcp_log(level, message, data)
    end
end

function Lifecycle.resetMatchState()
    Escape.reset()
    Threats.reset()
    SkillBuild.reset()
    WisdomControl.reset()
    Safety.enemyCache = nil
    state.hero = nil
    state.player = nil
    state.team = nil
    state.alliedFort = nil
    state.enemyFort = nil
    state.alliedFountain = nil
    state.fountainPosition = nil
    state.tier2Alive = {
        top = false,
        mid = false,
        bot = false,
    }
    state.enemyTier2Positions = {
        top = nil,
        mid = nil,
        bot = nil,
    }
    state.enemyTier1Positions = {
        top = nil,
        mid = nil,
        bot = nil,
    }
    state.lanePushed = {
        top = false,
        mid = false,
        bot = false,
    }
    state.lanePushedUntil = {
        top = 0,
        mid = 0,
        bot = 0,
    }
    state.camps = {}
    state.campsReady = false
    state.targetCamp = nil
    state.visited = {}
    state.campMinute = -1
    state.arrivedAt = nil
    state.attackTarget = nil
    state.nextThinkAt = 0
    state.nextOrderAt = 0
    state.nextWorldScanAt = 0
    state.nextTowerScanAt = 0
    state.nextLanePushScanAt = 0
    state.nextCampScanAt = 0
    state.nextUltimateAt = 0
    state.nextEntangleAt = 0
    state.nextRuneScanAt = 0
    RuneControl.clearRuneState()
    state.ignoredRunes = {}
    state.trueFormGraceUntil = 0
    state.manualPauseUntil = 0
    state.nextEnemyAlertAt = 0
    state.lastEnemySeenAt = -100
    state.enemyWasNear = false
    state.retreating = false
    state.retreatReason = nil
    state.bearGateOpen = nil
    state.lastGameTime = -1
    state.lastHealthSample = nil
    state.lastHealthSampleAt = 0
    state.healthRecoveryRate = 0
    state.healthRecoveryActive = false
    state.activity = "idle"
    state.preSpawnSeconds = nil
    state.preSpawnCamp = nil
    state.preSpawnPosition = nil
    state.preSpawnTargetMinute = -1
    state.stacking = false
    state.stackCamp = nil
    state.stackMinute = -1
    state.stackStartedAt = 0
    state.stackPullAt = 0
    state.stackPullPosition = nil
    local delivery = state.courierDelivery
    delivery.courier = nil
    delivery.nextThinkAt = 0
    delivery.nextOrderAt = 0
    delivery.manualPauseUntil = 0
    delivery.abilityMissingLogged = false
end

function Lifecycle.isLoneDruid(hero)
    return hero ~= nil and NPC.GetUnitName(hero) == C.HERO_NAME
end

function Lifecycle.stopAutomatedHero()
    local hero = Heroes.GetLocal()
    local player = Players.GetLocal()

    if player ~= nil and Lifecycle.isLoneDruid(hero) and Entity.IsAlive(hero) then
        Player.HoldPosition(player, hero, false, false, false, "ld_auto_farm_disabled")
    end
end

function Lifecycle.resolveLocalContext()
    local hero = Heroes.GetLocal()
    local player = Players.GetLocal()

    if player == nil or not Lifecycle.isLoneDruid(hero) or not Entity.IsAlive(hero) then
        return false
    end

    if state.hero ~= hero then
        Lifecycle.resetMatchState()
        state.hero = hero
        state.player = player
        state.team = Entity.GetTeamNum(hero)
    else
        state.player = player
    end

    return Settings.initializeCampSelections(state.team)
end

function Lifecycle.inGameClock(now)
    local elapsed = now - GameRules.GetGameStartTime()
    if elapsed < 0 then
        return nil, nil, nil
    end

    return elapsed, math.floor(elapsed / 60), elapsed % 60
end

function Lifecycle.onScriptsLoaded()
    Ui.panel.styleOk = pcall(Menu.Style, "primary")
    Ui.initializeRadiusCircle()
    local menuReady = Settings.initializeMenu()
    Lifecycle.bridgeLog("info", "lone_druid_auto_farm loaded", {
        version = C.SCRIPT_VERSION,
        menu_ready = menuReady,
        controls_bear = false,
        controls_courier = true,
    })
end

function Lifecycle.onUpdate()
    if not options.ready then
        return
    end

    if options.toggleBind:IsPressed() then
        options.enabled:Set(not options.enabled:Get())
    end

    if not options.enabled:Get() then
        if state.wasEnabled then
            state.wasEnabled = false
            Lifecycle.resetMatchState()
        end
        return
    end

    state.wasEnabled = true

    local now = GameRules.GetGameTime()
    if state.lastGameTime >= 0 and now + 1 < state.lastGameTime then
        Lifecycle.resetMatchState()
    end
    state.lastGameTime = now

    if now < state.nextThinkAt then
        return
    end
    state.nextThinkAt = now + C.THINK_INTERVAL

    if not Lifecycle.resolveLocalContext() then
        Escape.reset()
        return
    end

    Delivery.handle(now)

    if not WorldState.bearScepterGateIsOpen() then
        state.activity = "waiting_scepter"
        state.preSpawnSeconds = nil
        Escape.reset()
        state.retreating = false
        state.retreatReason = nil
        return
    end

    if now < state.manualPauseUntil then
        state.activity = "manual_pause"
        state.preSpawnSeconds = nil
        Escape.cancel(now, math.max(0, Escape.data.nextAttemptAt - now), "manual_pause")
        state.retreating = false
        state.retreatReason = nil
        return
    end

    if Escape.handle(now) then
        WisdomControl.cancelCurrentSpawn(now, "escape")
        return
    end

    if not WorldState.ensureWorldData(now) then
        return
    end

    WorldState.updateTier2State(now, false)
    WorldState.updateLanePushSafety(now, false)
    Threats.update(now)
    Farm.updateCampKnowledge(now)

    if Safety.handleSafety(now) then
        WisdomControl.cancelCurrentSpawn(now, "safety")
        return
    end

    Threats.replan(now)

    if WisdomControl.handle(now) then
        return
    end

    if RuneControl.handleRuneControl(now) then
        return
    end

    Farm.farmAlliedJungle(now)
end

-- Settings ------------------------------------------------------------

function Settings.localize(key)
    return localization.Localize(key)
end

function Settings.selectionSideForTeam(team)
    if team == Enum.TeamNum.TEAM_RADIANT then
        return "radiant"
    end

    if team == Enum.TeamNum.TEAM_DIRE then
        return "dire"
    end

    return nil
end

function Settings.campAvailableForSide(camp, side)
    return camp ~= nil
        and side ~= nil
        and (camp.owner == side or camp.additionalOwner == side)
end

function Settings.initializeCampSelections(team)
    local side = Settings.selectionSideForTeam(team)
    if side == nil then
        return false
    end

    if Settings.loadedCampSelectionSide == side then
        return true
    end
    if Settings.attemptedCampSelectionSide == side then
        return false
    end

    Settings.attemptedCampSelectionSide = side
    Settings.campSelections.radiant = {}
    Settings.campSelections.dire = {}
    Settings.campLayoutsBySide.radiant = {}
    Settings.campLayoutsBySide.dire = {}

    for i = 1, #C.ALL_CAMP_LAYOUTS do
        local camp = C.ALL_CAMP_LAYOUTS[i]
        if Settings.campAvailableForSide(camp, side) then
            local defaultEnabled = side == "radiant"
                and camp.defaultRadiant == true
                or side == "dire" and camp.defaultDire == true

            Settings.campSelections[side][camp.id] = Config.ReadInt(
                C.CAMP_SELECTION_CONFIG,
                side .. "_" .. camp.id,
                defaultEnabled and 1 or 0
            ) ~= 0
            Settings.campLayoutsBySide[side][#Settings.campLayoutsBySide[side] + 1] = camp
        end
    end

    Settings.loadedCampSelectionSide = side
    Lifecycle.bridgeLog("info", "lone_druid_auto_farm: camp selections loaded", {
        side = side,
        reads = #Settings.campLayoutsBySide[side],
    })
    return true
end

function Settings.campSelectionEnabled(selectionId, team)
    local side = Settings.selectionSideForTeam(team or state.team)
    return side ~= nil
        and selectionId ~= nil
        and Settings.campSelections[side][selectionId] == true
end

function Settings.setCampSelection(selectionId, team, enabled)
    local side = Settings.selectionSideForTeam(team)
    if side == nil or selectionId == nil then
        return false
    end

    Settings.campSelections[side][selectionId] = enabled == true
    Config.WriteInt(
        C.CAMP_SELECTION_CONFIG,
        side .. "_" .. selectionId,
        enabled and 1 or 0
    )
    return true
end

function Settings.localizedLane(lane)
    local key = C.UI_TEXT.lanes[lane]
    return key ~= nil and Settings.localize(key) or "-"
end

function Settings.campDisplayLabel(camp, index, side)
    local displaySide = side or camp.owner
    local ownerKey = displaySide == "radiant"
        and C.UI_TEXT.campPanelRadiant
        or C.UI_TEXT.campPanelDire
    return string.format(
        Settings.localize(C.UI_TEXT.campPanelCampLabel),
        index,
        Settings.localize(ownerKey),
        Settings.localizedLane(camp.lane)
    )
end

function Settings.applyV11DefaultSettings()
    if Config.ReadInt(C.SETTINGS_CONFIG, "v11_defaults_applied", 0) ~= 0 then
        return
    end

    options.enemyRadius:Set(2000)
    options.lowHp:Set(45)
    options.showCampPanel:Set(true)
    options.showStatus:Set(false)
    Config.WriteInt(C.SETTINGS_CONFIG, "v11_defaults_applied", 1)
end

function Settings.applyV14ThresholdDefaults()
    if Config.ReadInt(C.SETTINGS_CONFIG, "v14_hp_thresholds_applied", 0) ~= 0 then
        return
    end

    options.trueFormLowHp:Set(50)
    options.lowHp:Set(35)
    Config.WriteInt(C.SETTINGS_CONFIG, "v14_hp_thresholds_applied", 1)
end

function Settings.applyV151Defaults()
    if Config.ReadInt(C.SETTINGS_CONFIG, "v151_defaults_applied", 0) ~= 0 then
        return
    end

    options.trueFormLowHp:Set(100)
    Config.WriteInt(C.SETTINGS_CONFIG, "v151_defaults_applied", 1)
end

function Settings.initializeMenu()
    local loneDruidTab = Menu.Find("Heroes", "Hero List", "Lone Druid")
    if loneDruidTab == nil then
        Lifecycle.bridgeLog("error", "lone_druid_auto_farm: lone druid menu tab not found", nil)
        return false
    end

    local autoFarmTab = loneDruidTab:Create(C.UI_TEXT.tab)

    -- Symmetrical 2x2 grid layout
    local mainGroup = autoFarmTab:Create(C.UI_TEXT.groupMain, Enum.GroupSide.Left)
    local farmingGroup = autoFarmTab:Create(C.UI_TEXT.groupFarming, Enum.GroupSide.Left)
    local safetyGroup = autoFarmTab:Create(C.UI_TEXT.groupSafety, Enum.GroupSide.Right)
    local interfaceGroup = autoFarmTab:Create(C.UI_TEXT.groupInterface, Enum.GroupSide.Right)

    -- Group 1: Main (Left)
    options.enabled = mainGroup:Switch(C.UI_TEXT.enabled, false, "\u{f011}")
    local enabledSettings = options.enabled:Gear(C.UI_TEXT.enabledSettings, "\u{f013}")
    options.toggleBind = enabledSettings:Bind(
        C.UI_TEXT.toggleBind,
        Enum.ButtonCode.BUTTON_CODE_INVALID,
        "\u{f11c}"
    )
    options.manualPause = enabledSettings:Slider(C.UI_TEXT.manualPause, 0, 10, 2, "%d s")
    options.manualPause:Icon("\u{f04c}")

    options.requireBearScepter = mainGroup:Switch(
        C.UI_TEXT.requireBearScepter,
        true,
        "panorama/images/items/ultimate_scepter_png.vtex_c"
    )

    options.autoCourierBear = mainGroup:Switch(
        C.UI_TEXT.autoCourierBear,
        true,
        "\u{f0d1}"
    )

    -- Group 2: Farming & Skills (Left)
    options.autoTrueForm = farmingGroup:Switch(
        C.UI_TEXT.autoTrueForm,
        true,
        "panorama/images/spellicons/lone_druid_true_form_png.vtex_c"
    )
    local trueFormSettings = options.autoTrueForm:Gear(
        C.UI_TEXT.enabledSettings,
        "\u{f013}"
    )
    options.trueFormLowHp = trueFormSettings:Slider(
        C.UI_TEXT.trueFormLowHp,
        10,
        100,
        100,
        function(value)
            if value >= 100 then
                return Settings.localize("ldaf.menu.true_form_always")
            end
            return string.format("<= %d%%", value)
        end
    )
    options.trueFormLowHp:Icon("\u{f21e}")
    options.trueFormLowHpOnly = {
        Get = function()
            return options.trueFormLowHp ~= nil and options.trueFormLowHp:Get() < 100
        end,
    }

    options.autoEntangle = farmingGroup:Switch(
        C.UI_TEXT.autoEntangle,
        true,
        "panorama/images/spellicons/lone_druid_entangle_png.vtex_c"
    )

    options.autoStack = farmingGroup:Switch(C.UI_TEXT.autoStack, true, "\u{f5fd}")

    options.autoAbilityMana = farmingGroup:Slider(
        C.UI_TEXT.autoAbilityMana,
        0,
        100,
        50,
        "%d%%"
    )
    options.autoAbilityMana:Icon("\u{f043}")

    options.autoSkillBuild = farmingGroup:Switch(
        "ldaf.menu.auto_skill_build",
        true,
        "\u{f19d}"
    )
    options.autoSkillBuild:ToolTip("ldaf.menu.auto_skill_build_tip")
    local skillBuildSettings = options.autoSkillBuild:Gear(C.UI_TEXT.enabledSettings, "\u{f013}")
    options.autoUltimate = skillBuildSettings:Switch(
        "ldaf.menu.auto_ultimate",
        true,
        "panorama/images/spellicons/lone_druid_true_form_png.vtex_c"
    )
    options.autoUltimate:ToolTip("ldaf.menu.auto_ultimate_tip")
    local talentChoices = {
        "ldaf.menu.talent_none",
        "ldaf.menu.talent_left",
        "ldaf.menu.talent_right",
    }
    options.talentChoices = {
        skillBuildSettings:Combo("ldaf.menu.talent_10", talentChoices, 0),
        skillBuildSettings:Combo("ldaf.menu.talent_15", talentChoices, 0),
        skillBuildSettings:Combo("ldaf.menu.talent_20", talentChoices, 0),
        skillBuildSettings:Combo("ldaf.menu.talent_25", talentChoices, 0),
    }
    for index = 1, #options.talentChoices do
        options.talentChoices[index]:ToolTip("ldaf.menu.talent_choice_tip")
    end

    options.autoRunes = farmingGroup:Switch(C.UI_TEXT.autoRunes, true, "\u{f091}")
    local runeSettings = options.autoRunes:Gear(C.UI_TEXT.enabledSettings, "\u{f013}")
    options.runeMaxDistance = runeSettings:Slider(
        C.UI_TEXT.runeMaxDistance,
        1000,
        6000,
        2500,
        "%d"
    )
    options.runeMaxDistance:Icon("\u{f545}")
    options.bountyRunes = runeSettings:Switch(C.UI_TEXT.bountyRunes, true, "\u{f091}")
    options.wisdomRunes = runeSettings:Switch(C.UI_TEXT.wisdomRunes, true, "\u{f19c}")

    -- Group 3: Safety & Retreat (Right)
    options.enemyRadius = safetyGroup:Slider(C.UI_TEXT.enemyRadius, 800, 2500, 2000, "%d")
    options.enemyRadius:Icon("\u{f05b}")
    local radiusSettings = options.enemyRadius:Gear(C.UI_TEXT.radiusSettings, "\u{f013}")
    options.showRadius = radiusSettings:Switch(C.UI_TEXT.showRadius, false, "\u{f06e}")

    options.lowHp = safetyGroup:Slider(C.UI_TEXT.lowHp, 10, 80, 35, "%d%%")
    options.lowHp:Icon("\u{f21e}")

    options.lowMana = safetyGroup:Slider(C.UI_TEXT.lowMana, 0, 80, 20, "%d%%")
    options.lowMana:Icon("\u{f043}")

    options.escapeRoarTp = safetyGroup:Switch(
        "ldaf.menu.escape_roar_tp", true,
        "panorama/images/spellicons/lone_druid_savage_roar_png.vtex_c"
    )
    options.escapeRoarTp:ToolTip("ldaf.menu.escape_roar_tp_tip")
    options.cautiousFarm = safetyGroup:Switch("ldaf.menu.cautious_farm", true, "\u{f132}")
    options.cautiousFarm:ToolTip("ldaf.menu.cautious_farm_tip")
    local cautiousSettings = options.cautiousFarm:Gear(C.UI_TEXT.enabledSettings, "\u{f013}")
    options.missingCount = cautiousSettings:Slider("ldaf.menu.missing_count", 2, 5, 3, "%d")
    options.missingCount:Icon("\u{f0c0}")
    options.missingSeconds = cautiousSettings:Slider("ldaf.menu.missing_seconds", 5, 30, 10, "%d s")
    options.missingSeconds:Icon("\u{f017}")

    -- Group 4: Interface & Overlays (Right)
    options.showCampPanel = interfaceGroup:Switch(C.UI_TEXT.showCampPanel, true, "\u{f279}")
    local campPanelSettings = options.showCampPanel:Gear(C.UI_TEXT.campPanelSettings, "\u{f013}")
    local savedCampScale = Config.ReadInt(C.SETTINGS_CONFIG, "camp_panel_scale", 100)
    if savedCampScale < 65 or savedCampScale > 145 then
        savedCampScale = 100
    end
    options.campPanelScale = campPanelSettings:Slider(
        C.UI_TEXT.campPanelScale,
        65,
        145,
        savedCampScale,
        "%d%%"
    )
    options.campPanelScale:Icon("\u{f065}")
    options.campPanelScale:Set(savedCampScale)
    options.campPanelScale:SetCallback(function(self)
        Config.WriteInt(C.SETTINGS_CONFIG, "camp_panel_scale", self:Get())
    end)

    options.showStatus = interfaceGroup:Switch(C.UI_TEXT.showStatus, false, "\u{f03a}")
    local statusSettings = options.showStatus:Gear(C.UI_TEXT.statusSettings, "\u{f013}")
    local savedStatusScale = Config.ReadInt(C.SETTINGS_CONFIG, "status_scale", 100)
    if savedStatusScale < 60 or savedStatusScale > 150 then
        savedStatusScale = 100
    end
    options.statusScale = statusSettings:Slider(
        C.UI_TEXT.statusScale,
        60,
        150,
        savedStatusScale,
        "%d%%"
    )
    options.statusScale:Icon("\u{f065}")
    options.statusScale:Set(savedStatusScale)
    options.statusScale:SetCallback(function(self)
        Config.WriteInt(C.SETTINGS_CONFIG, "status_scale", self:Get())
    end)

    Settings.applyV11DefaultSettings()
    Settings.applyV14ThresholdDefaults()
    Settings.applyV151Defaults()

    options.enabled:ToolTip(C.UI_TEXT.enabledTip)
    options.toggleBind:ToolTip(C.UI_TEXT.toggleBindTip)
    options.manualPause:ToolTip(C.UI_TEXT.manualPauseTip)
    options.requireBearScepter:ToolTip(C.UI_TEXT.requireBearScepterTip)
    options.autoCourierBear:ToolTip(C.UI_TEXT.autoCourierBearTip)
    options.autoTrueForm:ToolTip(C.UI_TEXT.autoTrueFormTip)
    options.trueFormLowHp:ToolTip(C.UI_TEXT.trueFormLowHpTip)
    options.autoEntangle:ToolTip(C.UI_TEXT.autoEntangleTip)
    options.autoStack:ToolTip(C.UI_TEXT.autoStackTip)
    options.autoAbilityMana:ToolTip(C.UI_TEXT.autoAbilityManaTip)
    options.autoRunes:ToolTip(C.UI_TEXT.autoRunesTip)
    options.bountyRunes:ToolTip(C.UI_TEXT.bountyRunesTip)
    options.wisdomRunes:ToolTip(C.UI_TEXT.wisdomRunesTip)
    options.runeMaxDistance:ToolTip(C.UI_TEXT.runeMaxDistanceTip)
    options.enemyRadius:ToolTip(C.UI_TEXT.enemyRadiusTip)
    options.showRadius:ToolTip(C.UI_TEXT.showRadiusTip)
    options.lowHp:ToolTip(C.UI_TEXT.lowHpTip)
    options.lowMana:ToolTip(C.UI_TEXT.lowManaTip)
    options.showCampPanel:ToolTip(C.UI_TEXT.showCampPanelTip)
    options.campPanelScale:ToolTip(C.UI_TEXT.campPanelScaleTip)
    options.showStatus:ToolTip(C.UI_TEXT.showStatusTip)
    options.statusScale:ToolTip(C.UI_TEXT.statusScaleTip)

    options.enabled:SetCallback(function(widget)
        if not widget:Get() then
            Lifecycle.stopAutomatedHero()
        end

        Lifecycle.resetMatchState()
        state.wasEnabled = widget:Get()
        Lifecycle.bridgeLog("info", "lone_druid_auto_farm: state changed", {
            enabled = widget:Get(),
        })
    end)

    options.ready = true
    return true
end

-- Geometry ------------------------------------------------------------

function Geometry.getCampCenter(camp)
    local box = Camp.GetCampBox(camp)
    if box == nil or box.min == nil or box.max == nil then
        return nil
    end

    return (box.min + box.max) / 2, box
end

function Geometry.pointInBox(position, box)
    return position.x >= box.min.x
        and position.x <= box.max.x
        and position.y >= box.min.y
        and position.y <= box.max.y
end

function Geometry.pointInExpandedBox(position, box, margin)
    return position.x >= box.min.x - margin
        and position.x <= box.max.x + margin
        and position.y >= box.min.y - margin
        and position.y <= box.max.y + margin
end

function Geometry.clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

function Geometry.outsideCampPosition(camp, preferredPosition, margin)
    local deltaX = preferredPosition.x - camp.center.x
    local deltaY = preferredPosition.y - camp.center.y
    local length = math.sqrt(deltaX * deltaX + deltaY * deltaY)
    if length < 1 then
        deltaX = 1
        deltaY = 0
        length = 1
    end

    local directionX = deltaX / length
    local directionY = deltaY / length
    local distance = 300
    local position = camp.center

    while distance <= 1600 do
        position = Vector(
            camp.center.x + directionX * distance,
            camp.center.y + directionY * distance,
            camp.center.z
        )
        if not Geometry.pointInExpandedBox(position, camp.box, margin) then
            return position
        end
        distance = distance + 100
    end

    return position
end

function Geometry.campKey(position)
    return string.format("%.0f:%.0f", position.x, position.y)
end

-- WorldState ------------------------------------------------------------

function WorldState.findSpiritBear()
    local spiritBearAbility = NPC.GetAbility(state.hero, C.SPIRIT_BEAR_ABILITY)
    if spiritBearAbility == nil then
        return nil
    end

    local bear = CustomEntities.GetSpiritBear(spiritBearAbility)
    if bear == nil or not NPCs.Contains(bear) or not Entity.IsAlive(bear) then
        return nil
    end

    return bear
end

function WorldState.bearScepterGateIsOpen()
    if not options.requireBearScepter:Get() then
        state.bearGateOpen = true
        return true
    end

    local bear = WorldState.findSpiritBear()
    local gateOpen = bear ~= nil and NPC.HasScepter(bear)

    if gateOpen ~= state.bearGateOpen then
        state.bearGateOpen = gateOpen
        state.targetCamp = nil
        state.arrivedAt = nil
        state.attackTarget = nil
        WisdomControl.clearOwnership()
        RuneControl.clearRuneState()
        state.preSpawnCamp = nil
        state.preSpawnPosition = nil
        state.preSpawnTargetMinute = -1
        state.preSpawnSeconds = nil
        state.stacking = false
        state.stackCamp = nil
        state.stackMinute = -1
        state.stackStartedAt = 0
        state.stackPullAt = 0
        state.stackPullPosition = nil

        if not gateOpen then
            Player.HoldPosition(
                state.player,
                state.hero,
                false,
                false,
                false,
                "ld_auto_farm_bear_scepter_gate"
            )
        end

        Lifecycle.bridgeLog("info", "lone_druid_auto_farm: bear scepter gate changed", {
            open = gateOpen,
            bear_found = bear ~= nil,
        })
    end

    return gateOpen
end

function WorldState.entityPosition(entity)
    if entity == nil then
        return nil
    end

    local validCall, isCurrent = pcall(Entity.IsEntity, entity)
    if not validCall or not isCurrent then
        return nil
    end

    local positionCall, position = pcall(Entity.GetAbsOrigin, entity)
    if not positionCall then
        return nil
    end
    return position
end

function WorldState.findForts()
    local forts = NPCs.GetAll(function(npc)
        return NPC.IsFort(npc)
    end)

    state.alliedFort = nil
    state.enemyFort = nil

    for i = 1, #forts do
        local fort = forts[i]
        local fortTeam = Entity.GetTeamNum(fort)

        if fortTeam == state.team then
            state.alliedFort = fort
        elseif fortTeam == Enum.TeamNum.TEAM_RADIANT or fortTeam == Enum.TeamNum.TEAM_DIRE then
            state.enemyFort = fort
        end
    end
end

function WorldState.findAlliedFountain()
    local desiredName = nil
    if state.team == Enum.TeamNum.TEAM_RADIANT then
        desiredName = "ent_dota_fountain_good"
    elseif state.team == Enum.TeamNum.TEAM_DIRE then
        desiredName = "ent_dota_fountain_bad"
    end

    state.alliedFountain = nil
    state.fountainPosition = nil

    if desiredName == nil then
        return
    end

    local entities = Entities.GetAll()
    for i = 1, #entities do
        local entity = entities[i]
        if Entity.GetClassName(entity) == "C_DOTA_Unit_Fountain"
            and Entity.GetUnitName(entity) == desiredName
        then
            state.alliedFountain = entity
            local fountainPosition = Entity.GetAbsOrigin(entity)

            if state.alliedFort ~= nil then
                local fortPosition = Entity.GetAbsOrigin(state.alliedFort)
                local deltaX = fortPosition.x - fountainPosition.x
                local deltaY = fortPosition.y - fountainPosition.y
                local length = math.sqrt(deltaX * deltaX + deltaY * deltaY)

                if length > 0 then
                    fountainPosition = Vector(
                        fountainPosition.x + deltaX / length * C.FOUNTAIN_STAND_OFFSET,
                        fountainPosition.y + deltaY / length * C.FOUNTAIN_STAND_OFFSET,
                        fountainPosition.z
                    )
                end
            end

            state.fountainPosition = fountainPosition
            return
        end
    end
end

function WorldState.initializeEnemyTowerReferences()
    local references = nil
    if state.team == Enum.TeamNum.TEAM_RADIANT then
        references = C.TIER2_REFERENCE_POSITIONS.dire
    elseif state.team == Enum.TeamNum.TEAM_DIRE then
        references = C.TIER2_REFERENCE_POSITIONS.radiant
    end

    if references == nil then
        return
    end

    for i = 1, #C.FARM_LANES do
        local lane = C.FARM_LANES[i]
        local reference = references[lane]
        state.enemyTier2Positions[lane] = Vector(reference.x, reference.y, 0)
    end
end

function WorldState.towerTierAndLane(unitName)
    local tier = tonumber(string.match(unitName, "tower(%d)_"))
    if tier == nil then
        return nil, nil
    end

    if string.find(unitName, "_top", 1, true) ~= nil then
        return tier, "top"
    end

    if string.find(unitName, "_mid", 1, true) ~= nil then
        return tier, "mid"
    end

    if string.find(unitName, "_bot", 1, true) ~= nil then
        return tier, "bot"
    end

    return tier, nil
end

function WorldState.updateTier2State(now, force)
    if not force and now < state.nextTowerScanAt then
        return
    end
    state.nextTowerScanAt = now + 1

    local alive = {
        top = false,
        mid = false,
        bot = false,
    }
    local towers = Towers.GetAll()

    for i = 1, #towers do
        local tower = towers[i]
        local tier, lane = WorldState.towerTierAndLane(NPC.GetUnitName(tower))
        if lane ~= nil then
            local towerTeam = Entity.GetTeamNum(tower)
            if towerTeam == state.team then
                if tier == 2 and Entity.IsAlive(tower) then
                    alive[lane] = true
                end
            elseif towerTeam == Enum.TeamNum.TEAM_RADIANT
                or towerTeam == Enum.TeamNum.TEAM_DIRE
            then
                if tier == 1 then
                    state.enemyTier1Positions[lane] = Entity.GetAbsOrigin(tower)
                elseif tier == 2 then
                    state.enemyTier2Positions[lane] = Entity.GetAbsOrigin(tower)
                end
            end
        end
    end

    local changed = alive.top ~= state.tier2Alive.top
        or alive.mid ~= state.tier2Alive.mid
        or alive.bot ~= state.tier2Alive.bot

    state.tier2Alive = alive

    if changed then
        Lifecycle.bridgeLog("info", "lone_druid_auto_farm: allied tier 2 state changed", alive)
    end
end

function WorldState.updateLanePushSafety(now, force)
    if not force and now < state.nextLanePushScanAt then
        return
    end
    state.nextLanePushScanAt = now + C.LANE_PUSH_SCAN_INTERVAL

    local enemyFortPosition = WorldState.entityPosition(state.enemyFort)
    if enemyFortPosition == nil then
        state.enemyFort = nil
        state.campsReady = false
        state.nextWorldScanAt = 0
        return
    end

    local advancedCreeps = {
        top = 0,
        mid = 0,
        bot = 0,
    }
    local alliedLaneCreeps = NPCs.GetAll(function(npc)
        return Entity.GetTeamNum(npc) == state.team
            and Entity.IsAlive(npc)
            and NPC.IsLaneCreep(npc)
    end)

    for creepIndex = 1, #alliedLaneCreeps do
        local creepPosition = WorldState.entityPosition(alliedLaneCreeps[creepIndex])
        if creepPosition ~= nil then
            local closestLane = nil
            local closestTowerDistance = math.huge

            for laneIndex = 1, #C.FARM_LANES do
                local lane = C.FARM_LANES[laneIndex]
                local tier2Position = state.enemyTier2Positions[lane]
                if tier2Position ~= nil then
                    local towerDistance = creepPosition:Distance2D(tier2Position)
                    if towerDistance < closestTowerDistance then
                        closestTowerDistance = towerDistance
                        closestLane = lane
                    end
                end
            end

            if closestLane ~= nil then
                local tier1Position = state.enemyTier1Positions[closestLane]
                local thresholdDistance = nil

                if tier1Position ~= nil then
                    thresholdDistance = tier1Position:Distance2D(enemyFortPosition)
                else
                    thresholdDistance = state.enemyTier2Positions[closestLane]:Distance2D(
                        enemyFortPosition
                    ) + C.LANE_PUSH_T1_FALLBACK_OFFSET
                end

                local creepDistance = creepPosition:Distance2D(enemyFortPosition)
                if creepDistance <= thresholdDistance + C.LANE_PUSH_PROGRESS_MARGIN then
                    advancedCreeps[closestLane] = advancedCreeps[closestLane] + 1
                end
            end
        end
    end

    for i = 1, #C.FARM_LANES do
        local lane = C.FARM_LANES[i]
        local creepCount = advancedCreeps[lane]

        if creepCount >= C.LANE_PUSH_MIN_CREEPS then
            state.lanePushedUntil[lane] = now + C.LANE_PUSH_GRACE
        end

        local pushed = now < state.lanePushedUntil[lane]
        if pushed ~= state.lanePushed[lane] then
            state.lanePushed[lane] = pushed
            Lifecycle.bridgeLog("info", "lone_druid_auto_farm: lane push safety changed", {
                lane = lane,
                pushed = pushed,
                advanced_allied_creeps = creepCount,
            })
        end
    end
end

function WorldState.rebuildAlliedCamps()
    if state.alliedFort == nil or state.enemyFort == nil then
        return false
    end

    local side = Settings.selectionSideForTeam(state.team)
    if side == nil then
        return false
    end

    local layout = Settings.campLayoutsBySide[side]
    local camps = Camps.GetAll()
    local alliedCamps = {}
    local usedCamps = {}
    local requiredExpected = 0
    local requiredFound = 0

    for layoutIndex = 1, #layout do
        local desired = layout[layoutIndex]
        local required = side == "radiant"
            and desired.defaultRadiant == true
            or side == "dire" and desired.defaultDire == true
        if required then
            requiredExpected = requiredExpected + 1
        end
        local closestIndex = nil
        local closestCenter = nil
        local closestBox = nil
        local closestDistance = C.SAFE_CAMP_MATCH_RADIUS

        for campIndex = 1, #camps do
            if not usedCamps[campIndex] then
                local center, box = Geometry.getCampCenter(camps[campIndex])
                if center ~= nil then
                    local deltaX = center.x - desired.x
                    local deltaY = center.y - desired.y
                    local distance = math.sqrt(deltaX * deltaX + deltaY * deltaY)

                    if distance < closestDistance then
                        closestIndex = campIndex
                        closestCenter = center
                        closestBox = box
                        closestDistance = distance
                    end
                end
            end
        end

        if closestIndex ~= nil then
            usedCamps[closestIndex] = true
            if required then
                requiredFound = requiredFound + 1
            end
            alliedCamps[#alliedCamps + 1] = {
                handle = camps[closestIndex],
                center = closestCenter,
                box = closestBox,
                campType = Camp.GetType(camps[closestIndex]),
                key = Geometry.campKey(closestCenter),
                lane = desired.lane,
                owner = side,
                homeSide = Settings.campAvailableForSide(desired, side),
                fallback = desired.fallbackTeam == side,
                selectionId = desired.id,
                displayName = Settings.campDisplayLabel(desired, layoutIndex, side),
                isEmpty = false,
                isBlocked = false,
                stackCount = 1,
                dangerUntil = 0,
                lastStackMinute = -1,
            }
        end
    end

    state.camps = alliedCamps
    if state.fountainPosition ~= nil then
        for i = 1, #state.camps do
            local camp = state.camps[i]
            camp.waitPosition = Geometry.outsideCampPosition(
                camp,
                state.fountainPosition,
                C.PRESPAWN_BOX_MARGIN
            )
        end
    end
    state.campsReady = requiredExpected > 0
        and requiredFound == requiredExpected
        and state.fountainPosition ~= nil

    if state.campsReady then
        Lifecycle.bridgeLog("info", "lone_druid_auto_farm: safe jungle route built", {
            camps = #alliedCamps,
            expected = #layout,
            default_camps = requiredFound,
            team = state.team,
        })
    else
        Lifecycle.bridgeLog("error", "lone_druid_auto_farm: safe jungle route incomplete", {
            camps = #alliedCamps,
            expected = #layout,
            default_camps = requiredFound,
            required_default_camps = requiredExpected,
            fountain_found = state.fountainPosition ~= nil,
            team = state.team,
        })
    end

    return state.campsReady
end

function WorldState.ensureWorldData(now)
    if state.campsReady then
        local alliedFortCurrent = WorldState.entityPosition(state.alliedFort) ~= nil
        local enemyFortCurrent = WorldState.entityPosition(state.enemyFort) ~= nil
        if alliedFortCurrent and enemyFortCurrent then
            return true
        end

        state.alliedFort = nil
        state.enemyFort = nil
        state.campsReady = false
        state.nextWorldScanAt = 0
    end

    if now < state.nextWorldScanAt then
        return false
    end

    state.nextWorldScanAt = now + 1
    WorldState.findForts()
    WorldState.findAlliedFountain()
    WorldState.initializeEnemyTowerReferences()
    WorldState.updateTier2State(now, true)
    return WorldState.rebuildAlliedCamps()
end

-- Orders ------------------------------------------------------------

function Orders.issueMove(position, now, delay, identifier)
    if position == nil or now < state.nextOrderAt then
        return
    end

    NPC.MoveTo(
        state.hero,
        position,
        false,
        false,
        false,
        false,
        identifier,
        true
    )
    state.nextOrderAt = now + delay
    state.attackTarget = nil
end

function Orders.issueHold(now, delay, identifier)
    if now < state.nextOrderAt then
        return
    end

    Player.HoldPosition(
        state.player,
        state.hero,
        false,
        false,
        false,
        identifier
    )
    state.nextOrderAt = now + delay
    state.attackTarget = nil
end

function Orders.homePosition()
    if state.fountainPosition ~= nil then
        return state.fountainPosition, C.FOUNTAIN_REACHED_RADIUS
    end

    if state.alliedFort ~= nil then
        return Entity.GetAbsOrigin(state.alliedFort), 1200
    end

    return nil, 0
end

function Orders.waitAtFountain(now, moveIdentifier, holdIdentifier)
    local destination, reachedRadius = Orders.homePosition()
    if destination == nil then
        return
    end

    local distance = Entity.GetAbsOrigin(state.hero):Distance2D(destination)
    if distance > reachedRadius then
        Orders.issueMove(destination, now, C.FOUNTAIN_MOVE_INTERVAL, moveIdentifier)
    else
        Orders.issueHold(now, C.FOUNTAIN_HOLD_INTERVAL, holdIdentifier)
    end
end

function Orders.issueAttack(target, now)
    if target == nil or now < state.nextOrderAt then
        return
    end

    Player.AttackTarget(
        state.player,
        state.hero,
        target,
        false,
        false,
        false,
        "ld_auto_farm_attack",
        true
    )
    state.nextOrderAt = now + C.ATTACK_ORDER_INTERVAL
    state.attackTarget = target
end

function Orders.issueRunePickup(rune, position, now)
    if rune == nil or position == nil or now < state.nextOrderAt then
        return false
    end

    Player.PrepareUnitOrders(
        state.player,
        Enum.UnitOrder.DOTA_UNIT_ORDER_PICKUP_RUNE,
        rune,
        position,
        nil,
        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
        state.hero,
        false,
        false,
        false,
        false,
        "ld_auto_farm_pickup_rune",
        true
    )
    state.nextOrderAt = now + C.RUNE_PICKUP_INTERVAL
    state.attackTarget = nil
    return true
end

Orders.manualOrderKinds = {
    [Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION] = true,
    [Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_TARGET] = true,
    [Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_MOVE] = true,
    [Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET] = true,
    [Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION] = true,
    [Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TARGET] = true,
    [Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TARGET_TREE] = true,
    [Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET] = true,
    [Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TOGGLE] = true,
    [Enum.UnitOrder.DOTA_UNIT_ORDER_HOLD_POSITION] = true,
    [Enum.UnitOrder.DOTA_UNIT_ORDER_DROP_ITEM] = true,
    [Enum.UnitOrder.DOTA_UNIT_ORDER_GIVE_ITEM] = true,
    [Enum.UnitOrder.DOTA_UNIT_ORDER_PICKUP_ITEM] = true,
    [Enum.UnitOrder.DOTA_UNIT_ORDER_PICKUP_RUNE] = true,
    [Enum.UnitOrder.DOTA_UNIT_ORDER_STOP] = true,
    [Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_RUNE] = true,
    [Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_DIRECTION] = true,
    [Enum.UnitOrder.DOTA_UNIT_ORDER_PATROL] = true,
    [Enum.UnitOrder.DOTA_UNIT_ORDER_VECTOR_TARGET_POSITION] = true,
    [Enum.UnitOrder.DOTA_UNIT_ORDER_CONTINUE] = true,
    [Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_RELATIVE] = true,
}

function Orders.affectsUnit(data, unit, player)
    if unit == nil then return false end
    local issuer = data.orderIssuer
    if issuer == Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_HERO_ONLY then
        return unit == Heroes.GetLocal()
    end
    if issuer == Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_SELECTED_UNITS then
        local selected = Player.GetSelectedUnits(player)
        for index = 1, math.min(#selected, 64) do
            if selected[index] == unit then return true end
        end
        return false
    end
    if data.npc ~= nil then return data.npc == unit end
    if issuer == Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_CURRENT_UNIT_ONLY then
        if data.ability ~= nil then return Ability.GetOwner(data.ability) == unit end
        local selected = Player.GetSelectedUnits(player)
        -- The API does not document which selected unit is current in a group.
        return #selected == 1 and selected[1] == unit
    end
    return false
end

function Orders.onPrepareUnitOrders(data)
    if not options.ready or not options.enabled:Get() or data == nil
        or not Orders.manualOrderKinds[data.order] then
        return true
    end
    local player = Players.GetLocal()
    if player == nil or (data.player ~= nil and data.player ~= player) then
        return true
    end

    local now = GameRules.GetGameTime()
    if options.autoCourierBear:Get() then
        local courier = Couriers.GetLocal()
        if Orders.affectsUnit(data, courier, player) then
            state.courierDelivery.courier = courier
            state.courierDelivery.manualPauseUntil = now + state.courierDelivery.manualPause
            state.courierDelivery.nextThinkAt = state.courierDelivery.manualPauseUntil
        end
    end

    local hero = Heroes.GetLocal()
    if Lifecycle.isLoneDruid(hero) and Orders.affectsUnit(data, hero, player) then
        local pause = options.manualPause:Get()
        local enteringPause = now >= state.manualPauseUntil
        state.manualPauseUntil = now + pause
        Escape.cancel(now, math.max(3, pause), "manual")
        state.retreating = false
        state.retreatReason = nil
        state.attackTarget = nil
        WisdomControl.clearOwnership()
        RuneControl.clearRuneState()
        state.preSpawnCamp = nil
        state.preSpawnPosition = nil
        state.preSpawnTargetMinute = -1
        state.preSpawnSeconds = nil
        Stack.clearStackState()
        if enteringPause and pause > 0 then
            Lifecycle.bridgeLog("info", "lone_druid_auto_farm: manual control pause", {
                order = data.order, issuer = data.orderIssuer, seconds = pause,
            })
        end
    end

    return true
end

-- Safety ------------------------------------------------------------

function Safety.nearbyEnemies(now)
    local radius = math.max(C.ESCAPE.radius, options.enemyRadius:Get())
    local cache = Safety.enemyCache
    if cache == nil or cache.at ~= now or cache.hero ~= state.hero or cache.radius ~= radius then
        cache = { at = now, hero = state.hero, radius = radius,
            enemies = Entity.GetHeroesInRadius(state.hero, radius, Enum.TeamType.TEAM_ENEMY, true, true) }
        Safety.enemyCache = cache
    end
    return cache.enemies
end

function Safety.healthPercent(hero)
    local maximum = Entity.GetMaxHealth(hero)
    if maximum <= 0 then
        return 0
    end

    return Entity.GetHealth(hero) * 100 / maximum
end

function Safety.manaPercent(hero)
    local maximum = NPC.GetMaxMana(hero)
    if maximum <= 0 then
        return 0
    end

    return NPC.GetMana(hero) * 100 / maximum
end

function Safety.updateHealthRecovery(now, hp)
    if state.lastHealthSample == nil then
        state.lastHealthSample = hp
        state.lastHealthSampleAt = now
        state.healthRecoveryRate = 0
        return
    end

    local elapsed = now - state.lastHealthSampleAt
    if elapsed < C.HEALTH_SAMPLE_INTERVAL then
        return
    end

    local currentRate = (hp - state.lastHealthSample) / math.max(0.01, elapsed)
    state.healthRecoveryRate = state.healthRecoveryRate * 0.6 + currentRate * 0.4
    state.lastHealthSample = hp
    state.lastHealthSampleAt = now
end

function Safety.healthRecoveryCanReplaceRetreat(hp, enemyNear)
    if enemyNear or state.healthRecoveryRate < C.HEALTH_RECOVERY_MIN_RATE then
        return false
    end

    local lowHp = options.lowHp:Get()
    if hp < lowHp - C.HEALTH_RECOVERY_FLOOR_OFFSET then
        return false
    end

    local predictedHealth = hp + state.healthRecoveryRate * C.HEALTH_RECOVERY_WINDOW
    return predictedHealth >= lowHp + C.HEALTH_RECOVERY_TARGET_OFFSET
end

function Safety.showEnemyAlert()
    Engine.PlayVol(C.ENEMY_ALERT_SOUND, C.ENEMY_ALERT_VOLUME)
    Render.CenteredNotification(Settings.localize(C.UI_TEXT.enemyAlert), C.ENEMY_ALERT_DURATION)
end

function Safety.updateEnemyTransition(enemyCount, now)
    local enemyNear = enemyCount > 0
    if enemyNear == state.enemyWasNear then
        return
    end

    state.enemyWasNear = enemyNear
    if enemyNear then
        if now >= state.nextEnemyAlertAt then
            Safety.showEnemyAlert()
            state.nextEnemyAlertAt = now + C.ENEMY_ALERT_COOLDOWN
        end
        Lifecycle.bridgeLog("warn", "lone_druid_auto_farm: enemy detected near hero", {
            enemies = enemyCount,
        })
    else
        Lifecycle.bridgeLog("info", "lone_druid_auto_farm: nearby enemy no longer visible", nil)
    end
end

function Safety.handleSafety(now)
    if not WorldState.bearScepterGateIsOpen() or now < state.manualPauseUntil then
        return false
    end

    local enemies = Safety.nearbyEnemies(now)
    local enemyCount = #enemies
    local enemyNear = enemyCount > 0
    local hp = Safety.healthPercent(state.hero)
    local mana = Safety.manaPercent(state.hero)
    local lowManaThreshold = options.lowMana:Get()
    local destination, reachedRadius = Orders.homePosition()
    local reachedBase = destination ~= nil
        and Entity.GetAbsOrigin(state.hero):Distance2D(destination) <= reachedRadius
    Safety.updateHealthRecovery(now, hp)
    local recoveryCanHold = not reachedBase
        and Safety.healthRecoveryCanReplaceRetreat(hp, enemyNear)
    state.healthRecoveryActive = recoveryCanHold
    local lowHealth = hp <= options.lowHp:Get() and not recoveryCanHold
    local lowMana = lowManaThreshold > 0 and mana <= lowManaThreshold
    local mustRetreat = lowHealth or lowMana
    local retreatReason = lowHealth and "low_health"
        or lowMana and "low_mana"
        or nil

    Safety.updateEnemyTransition(enemyCount, now)

    if enemyNear then
        state.lastEnemySeenAt = now
        mustRetreat = true
        retreatReason = "enemy"
    end

    if options.trueFormLowHpOnly:Get()
        and not reachedBase
        and (state.targetCamp ~= nil or state.retreating)
        and Spells.tryFarmTrueForm(now)
    then
        state.preSpawnSeconds = nil
        return true
    end

    if mustRetreat and not state.retreating then
        state.retreating = true
        state.retreatReason = retreatReason
        state.targetCamp = nil
        state.arrivedAt = nil
        RuneControl.clearRuneState()
        Stack.clearStackState()
        Lifecycle.bridgeLog("warn", "lone_druid_auto_farm: retreat started", {
            reason = retreatReason,
            hp = math.floor(hp),
            mana = math.floor(mana),
        })
    elseif mustRetreat then
        state.retreatReason = retreatReason
    end

    if not state.retreating then
        return false
    end

    local resumeHealth = math.min(95, options.lowHp:Get() + 20)
    local resumeMana = math.min(95, lowManaThreshold + 20)
    local safeLongEnough = not enemyNear and now - state.lastEnemySeenAt >= 3
    local recoveredOnTheWay = state.retreatReason == "low_health"
        and safeLongEnough
        and not reachedBase
        and recoveryCanHold
    local retreatFinished = false

    if state.retreatReason == "low_mana" then
        retreatFinished = safeLongEnough
            and (lowManaThreshold <= 0 or mana >= resumeMana)
    elseif state.retreatReason == "low_health" then
        retreatFinished = (safeLongEnough and hp >= resumeHealth)
            or recoveredOnTheWay
    else
        retreatFinished = safeLongEnough and hp > options.lowHp:Get()
    end

    if retreatFinished then
        state.retreating = false
        state.retreatReason = nil
        Lifecycle.bridgeLog("info", "lone_druid_auto_farm: retreat finished", {
            hp = math.floor(hp),
            mana = math.floor(mana),
            reached_fountain = reachedBase,
            recovery_predicted = recoveredOnTheWay,
        })
        return false
    end

    state.activity = "retreat"
    state.preSpawnSeconds = nil
    Orders.waitAtFountain(
        now,
        "ld_auto_farm_retreat",
        "ld_auto_farm_retreat_hold"
    )

    return true
end

-- Escape ------------------------------------------------------------

-- Emergency escape owns hero orders until the cast/channel resolves. In
-- particular, IsChannellingAbility(hero) does NOT cover teleport items.
Escape.data = { phase = "idle", nextAttemptAt = 0 }

function Escape.reset()
    Escape.data = { phase = "idle", nextAttemptAt = 0 }
end

function Escape.cancel(now, delay, reason)
    if Escape.data.phase ~= "idle" then
        Lifecycle.bridgeLog("info", "lone_druid_auto_farm: escape ended", { reason = reason })
        state.nextOrderAt = now
    end
    Escape.data = { phase = "idle", nextAttemptAt = now + delay }
end

function Escape.teleportItem()
    local item = NPC.GetItemByIndex(state.hero, C.ESCAPE.tpSlot)
    if item ~= nil and Ability.GetName(item) == C.ESCAPE.tp then
        return item
    end
    return nil
end

function Escape.clearActions()
    Farm.setTargetCamp(nil)
    RuneControl.clearRuneState()
    Stack.clearStackState()
    state.preSpawnCamp = nil
    state.preSpawnPosition = nil
    state.preSpawnTargetMinute = -1
    state.preSpawnSeconds = nil
end

function Escape.castTeleport(item, now)
    if item == nil or state.fountainPosition == nil
        or Ability.CanBeExecuted(item) ~= Enum.AbilityCastResult.READY then
        return false
    end
    Escape.data.phase = "tp_wait"
    Escape.data.destination = state.fountainPosition
    Escape.data.deadline = now + C.ESCAPE.tpStartTimeout
    state.activity = "escape_tp"
    state.nextOrderAt = Escape.data.deadline
    Ability.CastPosition(item, Escape.data.destination, false, false, true, "ld_auto_farm_escape_tp", true)
    return true
end

function Escape.fallback(now, reason)
    Escape.cancel(now, C.ESCAPE.retry, reason)
    state.retreating = true
    state.retreatReason = "enemy"
    state.lastEnemySeenAt = now
    state.activity = "retreat"
    state.nextOrderAt = now
    Orders.waitAtFountain(now, "ld_auto_farm_escape_retreat", "ld_auto_farm_escape_hold")
    return true
end

function Escape.handle(now)
    local item = Escape.teleportItem()
    local data = Escape.data
    -- Protect both our own and a player's TP, including when the feature is off.
    if item ~= nil and Ability.IsChannelling(item) then
        if data.phase == "tp_wait" then data.phase = "channel" end
        state.activity = "escape_tp"
        return true
    end
    if not options.escapeRoarTp:Get() then
        if data.phase ~= "idle" then Escape.cancel(now, C.ESCAPE.retry, "disabled") end
        return false
    end
    if data.phase == "channel" then
        local arrived = data.destination ~= nil
            and Entity.GetAbsOrigin(state.hero):Distance2D(data.destination) <= C.FOUNTAIN_REACHED_RADIUS
        return Escape.fallback(now, arrived and "arrived" or "channel_interrupted")
    end
    if data.phase == "tp_wait" then
        if item == nil or now >= data.deadline then
            return Escape.fallback(now, "tp_not_started")
        end
        state.activity = "escape_tp"
        return true
    end
    if data.phase == "roar_wait" then
        local roar = NPC.GetAbility(state.hero, C.ESCAPE.roar)
        if roar == data.roar and now >= data.castReadyAt
            and not Ability.IsInAbilityPhase(roar) and Ability.GetCooldown(roar) > 0 then
            if Escape.castTeleport(item, now) then return true end
            return Escape.fallback(now, "roar_only")
        end
        if roar ~= data.roar or now >= data.deadline then
            return Escape.fallback(now, "roar_not_confirmed")
        end
        state.activity = "escape_roar"
        return true
    end
    if now < data.nextAttemptAt or now < state.manualPauseUntil then return false end
    local position = Entity.GetAbsOrigin(state.hero)
    if state.fountainPosition ~= nil
        and position:Distance2D(state.fountainPosition) <= C.FOUNTAIN_REACHED_RADIUS then
        return false
    end
    local closeEnemy = false
    for _, enemy in ipairs(Safety.nearbyEnemies(now)) do
        if position:Distance2D(Entity.GetAbsOrigin(enemy)) <= C.ESCAPE.radius then
            closeEnemy = true
            break
        end
    end
    if not closeEnemy then return false end
    if state.fountainPosition == nil and now >= (data.nextFountainScanAt or 0) then
        data.nextFountainScanAt = now + C.ESCAPE.retry
        WorldState.findAlliedFountain()
    end
    local roar = NPC.GetAbility(state.hero, C.ESCAPE.roar)
    local tpReady = item ~= nil and state.fountainPosition ~= nil
        and Ability.CanBeExecuted(item) == Enum.AbilityCastResult.READY
    local roarReady = roar ~= nil and Ability.GetLevel(roar) > 0
        and Ability.CanBeExecuted(roar) == Enum.AbilityCastResult.READY
    -- Reserve TP mana: a Roar that consumes the last TP mana is not a combo.
    if roarReady and tpReady then
        roarReady = NPC.GetMana(state.hero) >= Ability.GetManaCost(roar) + Ability.GetManaCost(item)
    end
    if not roarReady and not tpReady then
        -- A jump often starts with a stun: retry readiness promptly when it ends.
        data.nextAttemptAt = now + C.ESCAPE.unreadyRetry
        return false
    end
    data.nextAttemptAt = now + C.ESCAPE.retry
    Escape.clearActions()
    state.lastEnemySeenAt = now
    Lifecycle.bridgeLog("warn", "lone_druid_auto_farm: emergency escape started", { roar = roarReady, tp = tpReady })
    if roarReady then
        local castPoint = math.max(0, Ability.GetCastPoint(roar))
        data.phase = "roar_wait"
        data.roar = roar
        data.castReadyAt = now + castPoint
        data.deadline = now + math.max(1, castPoint + 0.8)
        state.activity = "escape_roar"
        state.nextOrderAt = data.deadline
        Ability.CastNoTarget(roar, false, false, true, "ld_auto_farm_escape_roar")
        return true
    end
    return Escape.castTeleport(item, now)
end

-- Threats ------------------------------------------------------------

-- Match-local observation memory. Dormant entities supply neither positions
-- nor new sightings; multiple real clones count as one player.
Threats.data = { records = {}, nextScanAt = 0, cautious = false, missing = 0 }

function Threats.reset()
    Threats.data = { records = {}, nextScanAt = 0, cautious = false, missing = 0 }
end

function Threats.update(now)
    local data = Threats.data
    if not options.cautiousFarm:Get() then
        if data.cautious or next(data.records) ~= nil then Threats.reset() end
        return
    end
    if now < data.nextScanAt then return end
    data.nextScanAt = now + C.THREATS.scanInterval
    local observed = {}
    for _, hero in ipairs(Heroes.GetAll()) do
        if Entity.GetTeamNum(hero) ~= state.team and not NPC.IsIllusion(hero) then
            local id = Hero.GetPlayerID(hero)
            if id ~= nil and id >= 0 and id < 64 then
                local entry = observed[id] or { alive = false, visible = false }
                observed[id] = entry
                if Entity.IsAlive(hero) then
                    entry.alive = true
                    if not Entity.IsDormant(hero) then
                        entry.visible = true
                        entry.position = Entity.GetAbsOrigin(hero)
                    end
                end
            end
        end
    end
    data.missing = 0
    for id, entry in pairs(observed) do
        local record = data.records[id] or { lastSeenAt = now }
        data.records[id] = record
        if entry.visible then
            record.lastSeenAt = now
            record.position = Vector(entry.position.x, entry.position.y, entry.position.z)
        elseif not entry.alive or not record.alive then
            record.lastSeenAt = now
            record.position = nil
        end
        record.alive = entry.alive
        record.visible = entry.visible
        if entry.alive and not entry.visible and now - record.lastSeenAt >= options.missingSeconds:Get() then
            data.missing = data.missing + 1
        end
    end
    for id in pairs(data.records) do
        if observed[id] == nil then data.records[id] = nil end
    end
    local cautious = data.missing >= options.missingCount:Get()
    if cautious then data.releaseAt = now + C.THREATS.releaseGrace end
    cautious = cautious or (data.cautious and now < (data.releaseAt or 0))
    if cautious ~= data.cautious then
        data.cautious = cautious
        Lifecycle.bridgeLog("info", "lone_druid_auto_farm: cautious farming changed", { active = cautious, missing = data.missing })
    end
end

function Threats.campRisk(camp, now)
    local protected = camp.homeSide and state.tier2Alive[camp.lane] == true
    local risk = protected and 0 or (camp.fallback and 1 or 3)
    local home = Orders.homePosition()
    if home ~= nil then risk = risk + camp.center:Distance2D(home) / 10000 end
    for _, record in pairs(Threats.data.records) do
        local age = now - record.lastSeenAt
        if record.alive and record.position ~= nil and age < C.THREATS.memory then
            local distance = camp.center:Distance2D(record.position)
            if distance < C.THREATS.radius then
                risk = risk + 6 * (1 - age / C.THREATS.memory) * (1 - distance / C.THREATS.radius)
            end
        end
    end
    return risk
end

function Threats.campAllowed(camp, now)
    return (camp.fallback or (camp.homeSide and state.tier2Alive[camp.lane] == true))
        and Threats.campRisk(camp, now) <= C.THREATS.riskLimit
end

function Threats.replan(now)
    if not Threats.data.cautious then return end
    local current = state.targetCamp or state.stackCamp or state.preSpawnCamp
    if current == nil then return end
    local best = Farm.findClosestAvailableCamp(Entity.GetAbsOrigin(state.hero), now)
    local invalid = not Farm.campIsEligible(current, now)
    local safer = best ~= nil and best ~= current
        and Threats.campRisk(best, now) + C.THREATS.retargetGain < Threats.campRisk(current, now)
    if invalid or safer then
        Escape.clearActions()
        Farm.setTargetCamp(best)
        state.nextOrderAt = now
    end
end

-- Spells ------------------------------------------------------------

function Spells.findTrueForm()
    local ability = NPC.GetAbility(state.hero, C.TRUE_FORM_ABILITY)
    if ability ~= nil then
        return ability
    end

    for index = 0, 24 do
        ability = NPC.GetAbilityByIndex(state.hero, index)
        if ability ~= nil and Ability.IsUltimate(ability) then
            return ability
        end
    end

    return nil
end

function Spells.trueFormIsActive()
    return NPC.HasModifier(state.hero, C.TRUE_FORM_MODIFIER)
end

function Spells.farmTrueFormHealthReady()
    local threshold = options.trueFormLowHp:Get()
    if threshold >= 100 then
        return true
    end
    return Safety.healthPercent(state.hero) <= threshold
end

function Spells.farmAbilityManaReady()
    local threshold = options.autoAbilityMana:Get()
    if threshold <= 0 then
        return true
    end

    return Safety.manaPercent(state.hero) >= threshold
end

function Spells.tryTrueForm(now)
    if Spells.trueFormIsActive() or now < state.trueFormGraceUntil then
        return true, false
    end

    if now < state.nextUltimateAt then
        return false, false
    end

    local ability = Spells.findTrueForm()
    if ability == nil or Ability.GetLevel(ability) <= 0 then
        state.nextUltimateAt = now + 1
        return false, false
    end

    if Ability.CanBeExecuted(ability) ~= Enum.AbilityCastResult.READY then
        state.nextUltimateAt = now + 0.5
        return false, false
    end

    Ability.CastNoTarget(ability, false, false, true, "ld_auto_farm_true_form")
    state.nextUltimateAt = now + 1
    state.trueFormGraceUntil = now + 2.5
    state.nextOrderAt = math.max(state.nextOrderAt, now + C.ABILITY_ORDER_INTERVAL)
    return true, true
end

function Spells.tryFarmTrueForm(now)
    if not options.autoTrueForm:Get()
        or Spells.trueFormIsActive()
        or now < state.trueFormGraceUntil
        or not Spells.farmTrueFormHealthReady()
        or not Spells.farmAbilityManaReady()
    then
        return false
    end

    local _, casted = Spells.tryTrueForm(now)
    return casted
end

function Spells.tryFarmEntangle(now, neutral)
    if not options.autoEntangle:Get()
        or neutral == nil
        or now < state.nextEntangleAt
        or now < state.nextOrderAt
        or not Spells.farmAbilityManaReady()
    then
        return false
    end

    local ability = NPC.GetAbility(state.hero, C.ENTANGLE_ABILITY)
    if ability == nil or Ability.GetLevel(ability) <= 0 then
        state.nextEntangleAt = now + 1
        return false
    end

    if Ability.CanBeExecuted(ability) ~= Enum.AbilityCastResult.READY then
        state.nextEntangleAt = now + C.FARM_ABILITY_RETRY_INTERVAL
        return false
    end

    local targetPosition = Entity.GetAbsOrigin(neutral)
    local castRange = Ability.GetCastRange(ability) + NPC.GetCastRangeBonus(state.hero)
    if Entity.GetAbsOrigin(state.hero):Distance2D(targetPosition) > castRange + 50 then
        return false
    end

    Ability.CastPosition(
        ability,
        targetPosition,
        false,
        false,
        true,
        "ld_auto_farm_entangle",
        true
    )
    state.nextEntangleAt = now + 1
    state.nextOrderAt = math.max(state.nextOrderAt, now + C.ABILITY_ORDER_INTERVAL)
    state.attackTarget = nil
    return true
end

-- Skill build ------------------------------------------------------------

SkillBuild.data = {
    nextAttemptAt = 0,
    pendingName = nil,
    pendingLevel = -1,
    pendingUntil = 0,
    lastTargetName = nil,
    attempts = 0,
    failureLogged = false,
}

function SkillBuild.reset()
    local data = SkillBuild.data
    data.nextAttemptAt = 0
    data.pendingName = nil
    data.pendingLevel = -1
    data.pendingUntil = 0
    data.lastTargetName = nil
    data.attempts = 0
    data.failureLogged = false
end

function SkillBuild.clearPending()
    local data = SkillBuild.data
    data.pendingName = nil
    data.pendingLevel = -1
    data.pendingUntil = 0
end

function SkillBuild.findTalentAbilities()
    local talents = {}
    for index = 0, C.SKILL_BUILD.maxAbilityIndex do
        local ability = NPC.GetAbilityByIndex(state.hero, index)
        if ability ~= nil and Ability.IsAttributes(ability) then
            local name = Ability.GetName(ability)
            if name ~= "special_bonus_attributes"
                and string.sub(name, 1, 14) == "special_bonus_"
            then
                talents[#talents + 1] = ability
            end
        end
    end
    return talents
end

function SkillBuild.selectedTalent()
    if options.talentChoices == nil then
        return nil
    end

    local talents = SkillBuild.findTalentAbilities()
    for tier = 1, 4 do
        local choice = options.talentChoices[tier]:Get()
        if choice == 1 or choice == 2 then
            local ability = talents[(tier - 1) * 2 + choice]
            if ability ~= nil and Ability.GetLevel(ability) == 0
                and Ability.CanBeUpgraded(ability) then
                return ability
            end
        end
    end
    return nil
end

function SkillBuild.findCandidate()
    if options.autoUltimate ~= nil and options.autoUltimate:Get() then
        local ultimate = Spells.findTrueForm()
        if ultimate ~= nil and Ability.CanBeUpgraded(ultimate) then
            return ultimate
        end
    end
    return SkillBuild.selectedTalent()
end

function SkillBuild.finishPending(now)
    local data = SkillBuild.data
    if data.pendingName == nil then
        return false
    end

    local ability = NPC.GetAbility(state.hero, data.pendingName)
    if ability ~= nil and Ability.GetLevel(ability) > data.pendingLevel then
        Lifecycle.bridgeLog("info", "lone_druid_auto_farm: ability leveled", {
            ability = data.pendingName,
            level = Ability.GetLevel(ability),
        })
        SkillBuild.clearPending()
        data.lastTargetName = nil
        data.attempts = 0
        data.failureLogged = false
        data.nextAttemptAt = now + C.SKILL_BUILD.retryDelay
        return true
    end

    if now < data.pendingUntil then
        return true
    end

    SkillBuild.clearPending()
    if data.attempts >= C.SKILL_BUILD.maxAttempts then
        if not data.failureLogged then
            Lifecycle.bridgeLog("warn", "lone_druid_auto_farm: ability level order not confirmed", {
                ability = data.lastTargetName,
                attempts = data.attempts,
            })
            data.failureLogged = true
        end
        data.attempts = 0
        data.nextAttemptAt = now + C.SKILL_BUILD.backoff
        return true
    end

    data.nextAttemptAt = now
    return false
end

function SkillBuild.issue(ability, now)
    local data = SkillBuild.data
    local name = Ability.GetName(ability)
    if name == "" then
        data.nextAttemptAt = now + C.SKILL_BUILD.idleDelay
        return false
    end

    if data.lastTargetName ~= name then
        data.lastTargetName = name
        data.attempts = 0
        data.failureLogged = false
    end

    Player.PrepareUnitOrders(
        state.player,
        Enum.UnitOrder.DOTA_UNIT_ORDER_TRAIN_ABILITY,
        nil,
        Entity.GetAbsOrigin(state.hero),
        ability,
        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
        state.hero,
        false,
        false,
        false,
        false,
        "ld_auto_farm_train_ability",
        false
    )
    data.attempts = data.attempts + 1
    data.pendingName = name
    data.pendingLevel = Ability.GetLevel(ability)
    data.pendingUntil = now + C.SKILL_BUILD.confirmDelay
    data.nextAttemptAt = data.pendingUntil
    return true
end

function SkillBuild.handle(now)
    if options.autoSkillBuild == nil or not options.autoSkillBuild:Get() then
        SkillBuild.reset()
        return false
    end

    local data = SkillBuild.data
    if now < data.nextAttemptAt then
        return false
    end
    if SkillBuild.finishPending(now) then
        return false
    end

    if Hero.GetAbilityPoints(state.hero) <= 0 then
        data.lastTargetName = nil
        data.attempts = 0
        data.failureLogged = false
        data.nextAttemptAt = now + C.SKILL_BUILD.idleDelay
        return false
    end

    local ability = SkillBuild.findCandidate()
    if ability == nil then
        data.nextAttemptAt = now + C.SKILL_BUILD.idleDelay
        return false
    end
    return SkillBuild.issue(ability, now)
end

-- Farm ------------------------------------------------------------

function Farm.countCampStacks(creepNames)
    if #creepNames == 0 then
        return 0
    end

    local score = 0
    for i = 1, #creepNames do
        score = score + (C.PACK_MEMBERS[creepNames[i]] or 0)
    end

    if score > 0 then
        return math.max(1, math.floor(score + 0.49))
    end

    return math.max(1, math.floor(#creepNames / 4 + 0.5))
end

function Farm.scanCampNeutrals(camp)
    local neutrals = NPCs.InRadius(
        camp.center,
        C.CAMP_SCAN_RADIUS,
        Enum.TeamNum.TEAM_NEUTRAL,
        Enum.TeamType.TEAM_FRIEND,
        true,
        true
    )
    local names = {}

    for i = 1, #neutrals do
        local neutral = neutrals[i]
        if Entity.IsAlive(neutral) and not NPC.IsWaitingToSpawn(neutral) then
            local neutralPosition = Entity.GetAbsOrigin(neutral)
            if Geometry.pointInBox(neutralPosition, camp.box)
                or neutralPosition:Distance2D(camp.center) < C.CAMP_LOOSE_RADIUS
            then
                names[#names + 1] = NPC.GetUnitName(neutral) or ""
            end
        end
    end

    return #names > 0, names
end

function Farm.handleCampMinuteRollover(minute)
    local activeCamp = state.targetCamp
    local preserveActiveCamp = activeCamp ~= nil
        and Farm.scanCampNeutrals(activeCamp)

    state.campMinute = minute
    state.visited = {}
    if not preserveActiveCamp then
        state.targetCamp = nil
        state.arrivedAt = nil
        state.attackTarget = nil
    elseif state.attackTarget ~= nil
        and (not NPCs.Contains(state.attackTarget)
            or not Entity.IsAlive(state.attackTarget)
            or Entity.IsDormant(state.attackTarget))
    then
        state.attackTarget = nil
    end
    state.preSpawnCamp = nil
    state.preSpawnPosition = nil
    state.preSpawnTargetMinute = -1
    state.preSpawnSeconds = nil

    local heroPosition = Entity.GetAbsOrigin(state.hero)
    for i = 1, #state.camps do
        local camp = state.camps[i]
        if preserveActiveCamp and camp == activeCamp then
            camp.isEmpty = false
            camp.isBlocked = false
        elseif camp.isEmpty then
            if Geometry.pointInBox(heroPosition, camp.box) then
                camp.isBlocked = true
            else
                camp.isEmpty = false
                camp.isBlocked = false
                camp.stackCount = 1
            end
        else
            camp.isBlocked = false
        end
    end
end

function Farm.updateCampKnowledge(now)
    local inGameTime, minute, second = Lifecycle.inGameClock(now)
    if inGameTime == nil then
        return
    end

    if minute ~= state.campMinute then
        Farm.handleCampMinuteRollover(minute)
    end

    if now < state.nextCampScanAt then
        return
    end
    state.nextCampScanAt = now + C.CAMP_SCAN_INTERVAL

    for i = 1, #state.camps do
        local camp = state.camps[i]
        if Settings.campSelectionEnabled(camp.selectionId, state.team) then
            local enemies = Heroes.InRadius(
                camp.center,
                math.max(C.CAMP_DANGER_MIN_RADIUS, options.enemyRadius:Get()),
                state.team,
                Enum.TeamType.TEAM_ENEMY,
                true,
                true
            )
            local enemyFound = false
            for enemyIndex = 1, #enemies do
                if Entity.IsAlive(enemies[enemyIndex]) then
                    enemyFound = true
                    break
                end
            end
            if enemyFound then
                camp.dangerUntil = now + C.CAMP_DANGER_MEMORY
            end

            if FogOfWar.IsPointVisible(camp.center) then
                local hasNeutrals, creepNames = Farm.scanCampNeutrals(camp)
                if hasNeutrals then
                    camp.isEmpty = false
                    camp.isBlocked = false
                    camp.stackCount = Farm.countCampStacks(creepNames)
                elseif second < C.CAMP_EMPTY_GRACE_SECOND then
                    camp.isEmpty = true
                    camp.stackCount = 0
                end
            end
        end
    end
end

function Farm.campIsEligible(camp, now)
    local manuallyEnabled = Settings.campSelectionEnabled(camp.selectionId, state.team)
    local laneIsSafe = camp.fallback
        or state.lanePushed[camp.lane] == true
        or camp.homeSide and state.tier2Alive[camp.lane] == true

    return manuallyEnabled and laneIsSafe and now >= (camp.dangerUntil or 0)
        and (not Threats.data.cautious or Threats.campAllowed(camp, now))
end

function Farm.findClosestAvailableCamp(heroPosition, now)
    local wisdomCamp, wisdomDistance = WisdomControl.findPreferredCamp(heroPosition, now)
    if wisdomCamp ~= nil then
        return wisdomCamp, wisdomDistance
    end

    local closestCamp = nil
    local closestDistance = math.huge
    local bestRisk = math.huge

    for i = 1, #state.camps do
        local camp = state.camps[i]
        if Farm.campIsEligible(camp, now)
            and not state.visited[camp.key]
            and not camp.isEmpty
            and not camp.isBlocked
        then
            local distance = heroPosition:Distance2D(camp.center)
            local risk = Threats.data.cautious and Threats.campRisk(camp, now) or 0
            if risk < bestRisk or (risk == bestRisk and distance < closestDistance) then
                bestRisk = risk
                closestCamp = camp
                closestDistance = distance
            end
        end
    end

    return closestCamp, closestDistance
end

function Farm.setTargetCamp(camp)
    state.targetCamp = camp
    state.arrivedAt = nil
    state.attackTarget = nil
    if camp ~= nil then
        state.preSpawnCamp = nil
        state.preSpawnPosition = nil
        state.preSpawnTargetMinute = -1
        state.preSpawnSeconds = nil
    end
end

function Farm.chooseNextCamp(now)
    local heroPosition = Entity.GetAbsOrigin(state.hero)
    local closestCamp = Farm.findClosestAvailableCamp(heroPosition, now)

    Farm.setTargetCamp(closestCamp)
    return closestCamp
end

function Farm.findClosestFutureCamp(heroPosition, now)
    local closestCamp = nil
    local closestDistance = math.huge
    local bestRisk = math.huge

    for i = 1, #state.camps do
        local camp = state.camps[i]
        if Farm.campIsEligible(camp, now) and not camp.isBlocked then
            local destination = camp.waitPosition or camp.center
            local distance = heroPosition:Distance2D(destination)
            local risk = Threats.data.cautious and Threats.campRisk(camp, now) or 0
            if risk < bestRisk or (risk == bestRisk and distance < closestDistance) then
                bestRisk = risk
                closestCamp = camp
                closestDistance = distance
            end
        end
    end

    return closestCamp, closestDistance
end

function Farm.handlePreSpawnPositioning(now, forceNearest)
    local _, minute, second = Lifecycle.inGameClock(now)
    if minute == nil then
        return false
    end

    if state.preSpawnCamp ~= nil then
        if minute >= state.preSpawnTargetMinute
            or not Farm.campIsEligible(state.preSpawnCamp, now)
            or state.preSpawnCamp.isBlocked
        then
            state.preSpawnCamp = nil
            state.preSpawnPosition = nil
            state.preSpawnTargetMinute = -1
            state.preSpawnSeconds = nil
            return false
        end
    elseif forceNearest or second >= 30 then
        local heroPosition = Entity.GetAbsOrigin(state.hero)
        local camp, distance = Farm.findClosestFutureCamp(heroPosition, now)
        if camp ~= nil then
            local moveSpeed = math.max(1, NPC.GetMoveSpeed(state.hero))
            local travelTime = distance / moveSpeed * C.PRESPAWN_PATH_FACTOR
                + C.PRESPAWN_ARRIVAL_BUFFER
            local secondsUntilSpawn = 60 - second

            if forceNearest or secondsUntilSpawn <= travelTime then
                state.preSpawnCamp = camp
                state.preSpawnPosition = nil
                state.preSpawnTargetMinute = minute + 1
            end
        end
    end

    local camp = state.preSpawnCamp
    if camp == nil then
        return false
    end

    local destination = state.preSpawnPosition or camp.waitPosition or camp.center
    local distance = Entity.GetAbsOrigin(state.hero):Distance2D(destination)
    state.activity = "preposition"
    state.preSpawnSeconds = math.max(0, 60 - second)

    if distance > 180 then
        Orders.issueMove(destination, now, C.PRESPAWN_MOVE_INTERVAL, "ld_auto_farm_pre_spawn")
    else
        Orders.issueHold(now, C.PRESPAWN_HOLD_INTERVAL, "ld_auto_farm_pre_spawn_hold")
    end

    return true
end

function Farm.findNeutralAtCamp(camp)
    local units = NPCs.InRadius(
        camp.center,
        1100,
        Enum.TeamNum.TEAM_NEUTRAL,
        Enum.TeamType.TEAM_FRIEND,
        true,
        true
    )
    local heroPosition = Entity.GetAbsOrigin(state.hero)
    local closestNeutral = nil
    local closestDistance = math.huge

    for i = 1, #units do
        local unit = units[i]
        local unitName = NPC.GetUnitName(unit) or ""
        local isNeutralCampUnit = NPC.IsNeutral(unit)
            or (NPC.IsCreep(unit)
                and string.find(unitName, "npc_dota_neutral_", 1, true) == 1)
        if isNeutralCampUnit and Entity.IsAlive(unit) and not Entity.IsDormant(unit) then
            local distance = heroPosition:Distance2D(Entity.GetAbsOrigin(unit))
            if distance < closestDistance then
                closestNeutral = unit
                closestDistance = distance
            end
        end
    end

    return closestNeutral
end

function Farm.farmAlliedJungle(now)
    if Stack.handleActiveAutoStack(now) then
        return
    end

    local camp = state.targetCamp
    if camp ~= nil
        and (not Farm.campIsEligible(camp, now)
            or state.visited[camp.key]
            or camp.isEmpty
            or camp.isBlocked)
    then
        state.targetCamp = nil
        state.arrivedAt = nil
        state.attackTarget = nil
        camp = nil
    end

    if camp == nil then
        local _, _, second = Lifecycle.inGameClock(now)
        if second ~= nil
            and second >= C.NEAR_RESPAWN_WAIT_SECOND
            and Farm.handlePreSpawnPositioning(now, true)
        then
            return
        end

        camp = Farm.chooseNextCamp(now)
    end

    if camp == nil then
        if Farm.handlePreSpawnPositioning(now, false) then
            return
        end

        state.activity = "fountain"
        state.preSpawnSeconds = nil
        Orders.waitAtFountain(
            now,
            "ld_auto_farm_wait_fountain",
            "ld_auto_farm_wait_fountain_hold"
        )
        return
    end

    local heroPosition = Entity.GetAbsOrigin(state.hero)
    local distanceToCamp = heroPosition:Distance2D(camp.center)

    if state.attackTarget == nil and distanceToCamp > 350 then
        local betterCamp, betterDistance = Farm.findClosestAvailableCamp(heroPosition, now)
        if betterCamp ~= nil
            and betterCamp ~= camp
            and betterDistance + C.CAMP_RETARGET_MIN_GAIN < distanceToCamp
        then
            camp = betterCamp
            distanceToCamp = betterDistance
            Farm.setTargetCamp(betterCamp)
            state.nextOrderAt = now
        end
    end

    -- Level only while pursuing an eligible camp, after the lifecycle,
    -- manual-control and safety gates have allowed farming this tick.
    if SkillBuild.handle(now) then
        return
    end

    if distanceToCamp > 1150 then
        state.arrivedAt = nil
        state.activity = "moving"
        state.preSpawnSeconds = nil
        Orders.issueMove(camp.center, now, C.FARM_TRAVEL_INTERVAL, "ld_auto_farm_move")
        return
    end

    local neutral = Farm.findNeutralAtCamp(camp)
    if neutral ~= nil then
        state.arrivedAt = nil
        if Stack.tryStartAutoStack(now, camp, neutral, heroPosition) then
            return
        end

        state.activity = "farming"
        state.preSpawnSeconds = nil
        if Spells.tryFarmTrueForm(now) or Spells.tryFarmEntangle(now, neutral) then
            return
        end

        if state.attackTarget ~= neutral
            or (not NPC.IsAttacking(state.hero) and now >= state.nextOrderAt)
        then
            Orders.issueAttack(neutral, now)
        end
        return
    end

    local _, currentMinute, currentSecond = Lifecycle.inGameClock(now)
    if currentMinute ~= nil
        and currentSecond >= C.NEAR_RESPAWN_WAIT_SECOND
        and distanceToCamp <= 650
    then
        local preferredExit = heroPosition
        if distanceToCamp < 175 and state.fountainPosition ~= nil then
            preferredExit = state.fountainPosition
        end

        state.visited[camp.key] = true
        state.targetCamp = nil
        state.arrivedAt = nil
        state.attackTarget = nil
        state.preSpawnCamp = camp
        state.preSpawnPosition = Geometry.outsideCampPosition(
            camp,
            preferredExit,
            C.PRESPAWN_BOX_MARGIN
        )
        state.preSpawnTargetMinute = currentMinute + 1
        state.nextOrderAt = now
        Farm.handlePreSpawnPositioning(now, true)
        return
    end

    if distanceToCamp > 350 then
        state.arrivedAt = nil
        state.activity = "moving"
        state.preSpawnSeconds = nil
        Orders.issueMove(camp.center, now, C.FARM_ENTER_INTERVAL, "ld_auto_farm_enter_camp")
        return
    end

    if state.arrivedAt == nil then
        state.arrivedAt = now
        state.activity = "idle"
        state.preSpawnSeconds = nil
        return
    end

    if now - state.arrivedAt >= C.CAMP_EMPTY_CONFIRMATION then
        state.visited[camp.key] = true
        state.targetCamp = nil
        state.arrivedAt = nil
        state.attackTarget = nil
    end
end

-- Stack ------------------------------------------------------------

function Stack.clearStackState()
    state.stacking = false
    state.stackCamp = nil
    state.stackMinute = -1
    state.stackStartedAt = 0
    state.stackPullAt = 0
    state.stackPullPosition = nil
end

function Stack.campPullSecond(camp, heroPosition)
    local meta = C.CAMP_META[camp.campType] or C.CAMP_META[1]
    local base = meta.basePull
    local stackCount = camp.stackCount or 1

    if stackCount >= 3 then
        base = base + C.STACK_DELAY_3
    elseif stackCount == 2 then
        base = base + C.STACK_DELAY_2
    end

    if not Geometry.pointInBox(heroPosition, camp.box) then
        base = math.max(base, C.STACK_PULL_OUTSIDE_MIN)
    end

    return Geometry.clamp(base, C.STACK_PULL_CLAMP_MIN, C.STACK_PULL_CLAMP_MAX)
end

function Stack.handleActiveAutoStack(now)
    if not state.stacking then
        return false
    end

    if not options.autoStack:Get()
        or state.stackCamp == nil
        or not Farm.campIsEligible(state.stackCamp, now)
    then
        Stack.clearStackState()
        return false
    end

    local _, minute, second = Lifecycle.inGameClock(now)
    if minute == nil
        or now - state.stackStartedAt > 8
        or (minute > state.stackMinute and second >= C.STACK_FINISH_SECOND)
    then
        Stack.clearStackState()
        state.targetCamp = nil
        state.arrivedAt = nil
        state.nextOrderAt = now
        return false
    end

    state.activity = "stacking"
    state.preSpawnSeconds = nil
    if now >= state.stackPullAt then
        Orders.issueMove(
            state.stackPullPosition,
            now,
            C.STACK_ORDER_INTERVAL,
            "ld_auto_farm_stack_pull"
        )
    end

    return true
end

function Stack.safePullPosition(camp, preferredPosition)
    local deltaX = preferredPosition.x - camp.center.x
    local deltaY = preferredPosition.y - camp.center.y
    local length = math.sqrt(deltaX * deltaX + deltaY * deltaY)
    if length < 1 then
        deltaX = 1
        deltaY = 0
        length = 1
    end

    local baseAngle = math.atan2(deltaY, deltaX)
    local exitMargin = C.STACK_EXIT_BOX_MARGIN
    local stepAngle = math.pi / 8

    for step = 0, 16 do
        local offset = 0
        if step > 0 then
            local multiplier = math.floor((step + 1) / 2)
            local sign = (step % 2 == 1) and 1 or -1
            offset = sign * multiplier * stepAngle
        end

        local angle = baseAngle + offset
        local dirX = math.cos(angle)
        local dirY = math.sin(angle)

        local distance = 300
        local candidate = nil
        while distance <= 1500 do
            local pos = Vector(
                camp.center.x + dirX * distance,
                camp.center.y + dirY * distance,
                camp.center.z
            )
            if not Geometry.pointInExpandedBox(pos, camp.box, exitMargin) then
                candidate = pos
                break
            end
            distance = distance + 100
        end

        if candidate ~= nil then
            local blocksOther = false
            local campsList = state.camps
            if campsList ~= nil then
                for i = 1, #campsList do
                    local other = campsList[i]
                    if other ~= camp and other.box ~= nil then
                        if Geometry.pointInExpandedBox(candidate, other.box, 150) then
                            blocksOther = true
                            break
                        end
                    end
                end
            end

            if not blocksOther then
                return candidate
            end
        end
    end

    return Geometry.outsideCampPosition(camp, preferredPosition, exitMargin)
end

function Stack.tryStartAutoStack(now, camp, neutral, heroPosition)
    if not options.autoStack:Get() or camp.lastStackMinute == state.campMinute then
        return false
    end

    local _, minute, second = Lifecycle.inGameClock(now)
    if minute == nil then
        return false
    end

    local pullSecond = Stack.campPullSecond(camp, heroPosition)
    if second < pullSecond or second > pullSecond + C.STACK_ACTION_WINDOW then
        return false
    end

    local preferredPosition = heroPosition
    if heroPosition:Distance2D(camp.center) < 175 and state.fountainPosition ~= nil then
        preferredPosition = state.fountainPosition
    end

    camp.lastStackMinute = minute
    state.stacking = true
    state.stackCamp = camp
    state.stackMinute = minute
    state.stackStartedAt = now
    state.stackPullPosition = Stack.safePullPosition(
        camp,
        preferredPosition
    )

    local alreadyAggroed = state.attackTarget ~= nil
        and NPCs.Contains(state.attackTarget)
        and Entity.IsAlive(state.attackTarget)
    state.nextOrderAt = now
    if alreadyAggroed then
        state.stackPullAt = now
    else
        Orders.issueAttack(neutral, now)
        state.stackPullAt = now + 0.40
        state.nextOrderAt = state.stackPullAt
    end

    state.activity = "stacking"
    state.preSpawnSeconds = nil
    return true
end

-- WisdomControl ----------------------------------------------------------

WisdomControl.data = {
    position = nil,
    shrine = nil,
    nextDiscoveryAt = 0,
    phase = "idle",
    spawnAt = nil,
    completedSpawnAt = nil,
    lastSkipReason = nil,
    lastSkipSpawnAt = nil,
    sawActive = false,
    particleIndexes = {},
    particleFallbacks = {
        radiant = { position = nil, active = nil, fx = nil },
        dire = { position = nil, active = nil, fx = nil },
    },
    discoveryLogged = false,
}

function WisdomControl.reset()
    local data = WisdomControl.data
    data.position = nil
    data.shrine = nil
    data.nextDiscoveryAt = 0
    data.phase = "idle"
    data.spawnAt = nil
    data.completedSpawnAt = nil
    data.lastSkipReason = nil
    data.lastSkipSpawnAt = nil
    data.sawActive = false
    data.particleIndexes = {}
    data.particleFallbacks = {
        radiant = { position = nil, active = nil, fx = nil },
        dire = { position = nil, active = nil, fx = nil },
    }
    data.discoveryLogged = false
end

function WisdomControl.clearOwnership()
    local data = WisdomControl.data
    data.phase = "idle"
    data.spawnAt = nil
    data.sawActive = false
end

function WisdomControl.spawnForTime(now)
    if now < C.WISDOM.firstSpawn then
        if WisdomControl.data.completedSpawnAt == C.WISDOM.firstSpawn then
            return C.WISDOM.firstSpawn + C.WISDOM.interval
        end
        return C.WISDOM.firstSpawn
    end

    local elapsed = now - C.WISDOM.firstSpawn
    local spawnAt = C.WISDOM.firstSpawn
        + math.floor(elapsed / C.WISDOM.interval) * C.WISDOM.interval
    if WisdomControl.data.completedSpawnAt == spawnAt
        or now > spawnAt + C.WISDOM.postSpawnTimeout
    then
        return spawnAt + C.WISDOM.interval
    end
    return spawnAt
end

function WisdomControl.positionMatchesTeamSide(position)
    if position == nil then
        return false
    end
    if state.team == Enum.TeamNum.TEAM_RADIANT then
        return position.x < 0
    end
    if state.team == Enum.TeamNum.TEAM_DIRE then
        return position.x > 0
    end
    return false
end

function WisdomControl.copyPosition(position)
    if position == nil then
        return nil
    end
    return Vector(position.x, position.y, position.z)
end

function WisdomControl.teamSideKey()
    if state.team == Enum.TeamNum.TEAM_RADIANT then
        return "radiant"
    end
    if state.team == Enum.TeamNum.TEAM_DIRE then
        return "dire"
    end
    return nil
end

function WisdomControl.shrineIsValid(shrine)
    if shrine == nil then
        return false
    end
    local containsCall, contained = pcall(NPCs.Contains, shrine)
    if not containsCall or not contained then
        return false
    end
    local nameCall, name = pcall(NPC.GetUnitName, shrine)
    return nameCall and name == C.WISDOM.shrineName
end

function WisdomControl.setParticleObservation(index, position, active)
    local data = WisdomControl.data
    if position == nil or position.x == 0 then
        return
    end

    local side = position.x < 0 and "radiant" or "dire"
    local fallback = data.particleFallbacks[side]
    fallback.position = WisdomControl.copyPosition(position)
    fallback.active = active
    fallback.fx = index

    local record = data.particleIndexes[index]
    if record ~= nil then
        record.position = fallback.position
        record.side = side
    end

    if WisdomControl.teamSideKey() == side and data.shrine == nil then
        data.position = WisdomControl.copyPosition(position)
    end
end

function WisdomControl.onParticleCreate(particle)
    if particle == nil or particle.index == nil then
        return
    end
    local fullName = particle.fullName
    if fullName ~= C.WISDOM.activeParticle
        and fullName ~= C.WISDOM.ambientParticle
    then
        return
    end

    local active = fullName == C.WISDOM.activeParticle
    WisdomControl.data.particleIndexes[particle.index] = {
        entity = particle.entity,
        active = active,
        max = 0,
        current = 0,
        position = nil,
        side = nil,
    }

    local position = WorldState.entityPosition(particle.entity)
    if position ~= nil then
        WisdomControl.setParticleObservation(particle.index, position, active)
    end
end

function WisdomControl.onParticleUpdate(particle)
    if particle == nil then
        return
    end
    local record = WisdomControl.data.particleIndexes[particle.index]
    if record == nil then
        return
    end

    if particle.controlPoint == 0 then
        WisdomControl.setParticleObservation(
            particle.index,
            particle.position,
            record.active
        )
    elseif particle.controlPoint == 1 and particle.position ~= nil then
        record.max = particle.position.x
        record.current = particle.position.y
    end
end

function WisdomControl.onParticleDestroy(particle)
    if particle == nil then
        return
    end
    local data = WisdomControl.data
    local record = data.particleIndexes[particle.index]
    if record == nil then
        return
    end

    if record.side ~= nil then
        local fallback = data.particleFallbacks[record.side]
        if fallback.fx == particle.index then
            fallback.active = false
            fallback.fx = nil
        end
    end
    data.particleIndexes[particle.index] = nil
end

function WisdomControl.discoverPosition(now)
    local data = WisdomControl.data
    if WisdomControl.shrineIsValid(data.shrine) then
        local position = WorldState.entityPosition(data.shrine)
        if position ~= nil then
            data.position = WisdomControl.copyPosition(position)
            return data.position
        end
    else
        data.shrine = nil
    end

    if now >= data.nextDiscoveryAt then
        data.nextDiscoveryAt = now + C.WISDOM.discoveryRetry
        local npcs = NPCs.GetAll()
        for i = 1, #npcs do
            local npc = npcs[i]
            local nameCall, name = pcall(NPC.GetUnitName, npc)
            if nameCall and name == C.WISDOM.shrineName then
                local position = WorldState.entityPosition(npc)
                if WisdomControl.positionMatchesTeamSide(position) then
                    data.shrine = npc
                    data.position = WisdomControl.copyPosition(position)
                    break
                end
            end
        end
    end

    if data.position == nil then
        local side = WisdomControl.teamSideKey()
        local fallback = side ~= nil and data.particleFallbacks[side] or nil
        if fallback ~= nil and fallback.position ~= nil then
            data.position = WisdomControl.copyPosition(fallback.position)
        end
    end

    if data.position ~= nil and not data.discoveryLogged then
        data.discoveryLogged = true
        Lifecycle.bridgeLog("info", "lone_druid_auto_farm: Wisdom shrine discovered", {
            x = math.floor(data.position.x),
            y = math.floor(data.position.y),
        })
    end
    return data.position
end

function WisdomControl.shrineActivity()
    local data = WisdomControl.data
    if WisdomControl.shrineIsValid(data.shrine) then
        local fieldCall, active = pcall(Entity.GetField, data.shrine, "m_bActive")
        if fieldCall and type(active) == "boolean" then
            return active, "entity"
        end
        if fieldCall and type(active) == "number" then
            return active ~= 0, "entity"
        end
    end

    local side = WisdomControl.teamSideKey()
    local fallback = side ~= nil and data.particleFallbacks[side] or nil
    if fallback ~= nil then
        return fallback.active, "particle"
    end
    return nil, "unknown"
end

function WisdomControl.isPreparationWindow(now)
    if not options.ready
        or not options.autoRunes:Get()
        or not options.wisdomRunes:Get()
        or Threats.data.cautious
    then
        return false
    end
    local gameSeconds = Lifecycle.inGameClock(now)
    if gameSeconds == nil then
        return false
    end
    local spawnAt = WisdomControl.spawnForTime(gameSeconds)
    return gameSeconds >= spawnAt - C.WISDOM.preparationLead
        and gameSeconds < spawnAt - C.WISDOM.approachLead
end

function WisdomControl.findPreferredCamp(heroPosition, now)
    if not WisdomControl.isPreparationWindow(now) then
        return nil, math.huge
    end
    if WisdomControl.discoverPosition(now) == nil then
        return nil, math.huge
    end

    local side = state.team == Enum.TeamNum.TEAM_RADIANT and "radiant" or "dire"
    local preferredIds = C.WISDOM.camps[side]
    local closestCamp = nil
    local closestDistance = math.huge
    for i = 1, #state.camps do
        local camp = state.camps[i]
        if preferredIds[camp.selectionId]
            and Farm.campIsEligible(camp, now)
            and not state.visited[camp.key]
            and not camp.isEmpty
            and not camp.isBlocked
        then
            local distance = heroPosition:Distance2D(camp.center)
            if distance < closestDistance then
                closestCamp = camp
                closestDistance = distance
            end
        end
    end
    return closestCamp, closestDistance
end

function WisdomControl.farmRouteInProgress()
    if state.stacking or state.preSpawnCamp ~= nil then
        return true
    end

    local target = state.attackTarget
    if target ~= nil and NPCs.Contains(target) and Entity.IsAlive(target) then
        return true
    end

    local camp = state.targetCamp
    return camp ~= nil
        and not state.visited[camp.key]
        and camp.isEmpty ~= true
        and camp.isBlocked ~= true
end

function WisdomControl.finishSpawn(spawnAt, now, reason)
    local data = WisdomControl.data
    data.completedSpawnAt = spawnAt
    if reason == "shrine_inactive" and data.sawActive then
        data.lastSkipReason = nil
        data.lastSkipSpawnAt = nil
    else
        data.lastSkipReason = reason
        data.lastSkipSpawnAt = spawnAt
    end
    WisdomControl.clearOwnership()
    state.nextOrderAt = now
    Lifecycle.bridgeLog("info", "lone_druid_auto_farm: Wisdom route released", {
        spawn = spawnAt,
        reason = reason,
    })
end

function WisdomControl.cancelCurrentSpawn(now, reason)
    local data = WisdomControl.data
    local gameSeconds = Lifecycle.inGameClock(now)
    if gameSeconds == nil then
        WisdomControl.clearOwnership()
        return
    end

    local spawnAt = data.spawnAt or WisdomControl.spawnForTime(gameSeconds)
    if gameSeconds >= spawnAt - C.WISDOM.approachLead
        and gameSeconds <= spawnAt + C.WISDOM.postSpawnTimeout
    then
        WisdomControl.finishSpawn(spawnAt, now, reason)
    elseif data.phase ~= "idle" then
        WisdomControl.clearOwnership()
        state.nextOrderAt = now
    end
end

function WisdomControl.beginRoute(spawnAt, now)
    local data = WisdomControl.data
    data.phase = "approach"
    data.spawnAt = spawnAt
    data.nextRuneScanAt = now
    Farm.setTargetCamp(nil)
    Stack.clearStackState()
    RuneControl.clearRuneState()
    state.nextOrderAt = now
    Lifecycle.bridgeLog("info", "lone_druid_auto_farm: Wisdom route started", {
        spawn = spawnAt,
    })
end

function WisdomControl.handle(now)
    local data = WisdomControl.data
    if not options.autoRunes:Get() or not options.wisdomRunes:Get() then
        if data.phase ~= "idle" then
            WisdomControl.clearOwnership()
            state.nextOrderAt = now
        end
        return false
    end

    local gameSeconds = Lifecycle.inGameClock(now)
    if gameSeconds == nil then
        return false
    end

    if data.spawnAt ~= nil
        and gameSeconds > data.spawnAt + C.WISDOM.postSpawnTimeout
    then
        WisdomControl.finishSpawn(data.spawnAt, now, "timeout")
        return false
    end

    local spawnAt = WisdomControl.spawnForTime(gameSeconds)
    if gameSeconds < spawnAt - C.WISDOM.preparationLead then
        return false
    end
    WisdomControl.discoverPosition(now)
    if gameSeconds < spawnAt - C.WISDOM.approachLead then
        return false
    end

    local active = nil
    if gameSeconds >= spawnAt then
        active = WisdomControl.shrineActivity()
        if active == true then
            data.sawActive = true
        elseif active == false
            and (data.sawActive or gameSeconds > spawnAt + C.WISDOM.activationGrace)
        then
            WisdomControl.finishSpawn(spawnAt, now, "shrine_inactive")
            return false
        end
    end

    local destination = data.position
    if destination == nil then
        return false
    end
    if Threats.data.cautious or RuneControl.visibleEnemyNearRune(destination) then
        WisdomControl.finishSpawn(spawnAt, now, "unsafe")
        return false
    end

    if data.phase == "idle" then
        if WisdomControl.farmRouteInProgress() then
            return false
        end
        WisdomControl.beginRoute(spawnAt, now)
    end

    local distance = Entity.GetAbsOrigin(state.hero):Distance2D(destination)
    state.preSpawnSeconds = math.max(0, spawnAt - gameSeconds)
    if distance > C.WISDOM.arrivalRadius then
        data.phase = "approach"
        state.activity = "wisdom_approach"
        Orders.issueMove(destination, now, C.WISDOM.moveInterval, "ld_auto_farm_wisdom_move")
    else
        data.phase = gameSeconds >= spawnAt and active == true and "claim" or "wait"
        state.activity = data.phase == "claim" and "wisdom_claim" or "wisdom_wait"
        Orders.issueHold(now, C.WISDOM.holdInterval, "ld_auto_farm_wisdom_hold")
    end
    return true
end

-- RuneControl ------------------------------------------------------------

function RuneControl.clearRuneState()
    state.targetRune = nil
    state.targetRunePosition = nil
    state.runeTargetExpiresAt = 0
    state.runeCloseSince = nil
    state.runePickupIssued = false
end

function RuneControl.controlledRuneTypeEnabled(runeType)
    return runeType == Enum.RuneType.DOTA_RUNE_BOUNTY
end

function RuneControl.ignoreRune(rune, now, duration)
    if rune ~= nil then
        state.ignoredRunes[rune] = now + duration
    end
end

-- Entity.IsAlive has no documented semantics for CRune, so rune availability
-- relies on cheat-list membership and visibility alone.
function RuneControl.runeIsAvailable(rune)
    return rune ~= nil
        and Runes.Contains(rune)
        and not Entity.IsDormant(rune)
end

function RuneControl.runeIsOnAlliedHalf(position)
    if position == nil or state.alliedFort == nil or state.enemyFort == nil then
        return false
    end

    local alliedDistance = position:Distance2D(Entity.GetAbsOrigin(state.alliedFort))
    local enemyDistance = position:Distance2D(Entity.GetAbsOrigin(state.enemyFort))
    return alliedDistance + C.RUNE_ALLIED_HALF_MARGIN <= enemyDistance
end

function RuneControl.visibleEnemyNearRune(position)
    local enemies = Heroes.InRadius(
        position,
        math.max(C.CAMP_DANGER_MIN_RADIUS, options.enemyRadius:Get()),
        state.team,
        Enum.TeamType.TEAM_ENEMY,
        true,
        true
    )

    for i = 1, #enemies do
        if Entity.IsAlive(enemies[i]) then
            return true
        end
    end

    return false
end

function RuneControl.campFightInProgress()
    if state.stacking then
        return true
    end

    local target = state.attackTarget
    if target ~= nil and NPCs.Contains(target) and Entity.IsAlive(target) then
        return true
    end

    local camp = state.targetCamp
    if camp == nil then
        return false
    end

    local heroPosition = Entity.GetAbsOrigin(state.hero)
    return heroPosition:Distance2D(camp.center) <= 1150
        and Farm.findNeutralAtCamp(camp) ~= nil
end

function RuneControl.findClosestControlledRune(now)
    if now < state.nextRuneScanAt then
        return nil, nil
    end
    state.nextRuneScanAt = now + C.RUNE_SCAN_INTERVAL

    local heroPosition = Entity.GetAbsOrigin(state.hero)
    local maximumDistance = options.runeMaxDistance:Get()
    local closestRune = nil
    local closestPosition = nil
    local closestDistance = math.huge

    for ignoredRune, ignoredUntil in pairs(state.ignoredRunes) do
        if now >= ignoredUntil then
            state.ignoredRunes[ignoredRune] = nil
        end
    end

    local runes = Runes.GetAll()

    for i = 1, #runes do
        local rune = runes[i]
        local ignoredUntil = state.ignoredRunes[rune] or 0
        if now >= ignoredUntil and RuneControl.runeIsAvailable(rune) then
            if ignoredUntil > 0 then
                state.ignoredRunes[rune] = nil
            end
            local runeType = Rune.GetRuneType(rune)
            if RuneControl.controlledRuneTypeEnabled(runeType) then
                local position = Entity.GetAbsOrigin(rune)
                local distance = heroPosition:Distance2D(position)
                if distance <= maximumDistance
                    and distance < closestDistance
                    and RuneControl.runeIsOnAlliedHalf(position)
                    and not RuneControl.visibleEnemyNearRune(position)
                then
                    closestRune = rune
                    closestPosition = position
                    closestDistance = distance
                end
            end
        end
    end

    return closestRune, closestPosition
end

function RuneControl.selectRuneTarget(rune, position, now)
    state.targetRune = rune
    state.targetRunePosition = position
    state.arrivedAt = nil
    state.attackTarget = nil
    local travelTime = Entity.GetAbsOrigin(state.hero):Distance2D(position)
        / math.max(1, NPC.GetMoveSpeed(state.hero))
        * C.PRESPAWN_PATH_FACTOR
    state.runeTargetExpiresAt = now + math.max(C.RUNE_TARGET_TIMEOUT, travelTime + 5)
    state.runeCloseSince = nil
    state.runePickupIssued = false
    state.nextOrderAt = now

    Lifecycle.bridgeLog("info", "lone_druid_auto_farm: rune target selected", {
        rune = "bounty",
        distance = math.floor(Entity.GetAbsOrigin(state.hero):Distance2D(position)),
    })
end

function RuneControl.handleRuneControl(now)
    if Threats.data.cautious then
        if state.targetRune ~= nil then
            RuneControl.clearRuneState()
            state.nextOrderAt = now
        end
        return false
    end
    if not options.autoRunes:Get() or not options.bountyRunes:Get() then
        if state.targetRune ~= nil then
            RuneControl.clearRuneState()
            state.nextOrderAt = now
        end
        state.nextRuneScanAt = now
        return false
    end

    if state.stacking then
        if state.targetRune ~= nil then
            RuneControl.clearRuneState()
            state.nextOrderAt = now
        end
        return false
    end

    local _, _, second = Lifecycle.inGameClock(now)
    if state.preSpawnCamp ~= nil
        or (second ~= nil and second >= C.NEAR_RESPAWN_WAIT_SECOND)
    then
        if state.targetRune ~= nil then
            RuneControl.clearRuneState()
            state.nextOrderAt = now
        end
        return false
    end

    local rune = state.targetRune
    local position = state.targetRunePosition

    if rune ~= nil then
        if not RuneControl.runeIsAvailable(rune)
            or not RuneControl.controlledRuneTypeEnabled(Rune.GetRuneType(rune))
        then
            RuneControl.clearRuneState()
            state.nextRuneScanAt = now
            state.nextOrderAt = now
            rune = nil
        else
            position = Entity.GetAbsOrigin(rune)
            local targetTimedOut = now >= state.runeTargetExpiresAt
            local enemyNearTarget = false
            if now >= state.nextRuneScanAt then
                state.nextRuneScanAt = now + C.RUNE_SCAN_INTERVAL
                enemyNearTarget = RuneControl.visibleEnemyNearRune(position)
            end
            local tooFar = Entity.GetAbsOrigin(state.hero):Distance2D(position)
                > options.runeMaxDistance:Get() + C.RUNE_TARGET_DISTANCE_GRACE
            if not RuneControl.runeIsOnAlliedHalf(position)
                or enemyNearTarget
                or tooFar
                or targetTimedOut
            then
                if targetTimedOut then
                    RuneControl.ignoreRune(rune, now, C.RUNE_TARGET_TIMEOUT)
                elseif enemyNearTarget then
                    RuneControl.ignoreRune(rune, now, C.RUNE_DANGER_RETRY)
                end
                RuneControl.clearRuneState()
                state.nextRuneScanAt = now
                state.nextOrderAt = now
                return false
            end
            state.targetRunePosition = position
        end
    end

    if rune == nil then
        if now < state.nextRuneScanAt then
            return false
        end

        if RuneControl.campFightInProgress() then
            state.nextRuneScanAt = now + C.RUNE_SCAN_INTERVAL
            return false
        end

        rune, position = RuneControl.findClosestControlledRune(now)
        if rune == nil then
            return false
        end
        RuneControl.selectRuneTarget(rune, position, now)
    end

    local distance = Entity.GetAbsOrigin(state.hero):Distance2D(position)
    state.activity = "rune_bounty"
    state.preSpawnSeconds = nil

    if distance <= C.RUNE_PICKUP_DISTANCE then
        if not state.runePickupIssued
            and Orders.issueRunePickup(rune, position, now)
        then
            state.runePickupIssued = true
            state.runeCloseSince = now
            state.runeTargetExpiresAt = math.max(
                state.runeTargetExpiresAt,
                now + C.RUNE_CLOSE_TIMEOUT
            )
        end

        if state.runePickupIssued
            and state.runeCloseSince ~= nil
            and now - state.runeCloseSince >= C.RUNE_CLOSE_TIMEOUT
        then
            RuneControl.ignoreRune(rune, now, C.RUNE_TARGET_TIMEOUT)
            RuneControl.clearRuneState()
            state.nextRuneScanAt = now
            state.nextOrderAt = now
            return false
        end
    else
        state.runeCloseSince = nil
        state.runePickupIssued = false
        Orders.issueMove(position, now, C.RUNE_MOVE_INTERVAL, "ld_auto_farm_rune_move")
    end

    return true
end

-- Ui ------------------------------------------------------------

-- Render-only storage: bounded across frames and independent of match state.
-- Cache keys include the actual translated text, font handle and font size.
Ui.textCache = { entries = {}, keys = {}, cursor = 1, limit = 512 }
Ui.markerPool = {}
Ui.panelRows = { {}, {}, {} }
Ui.statusRows = { {}, {}, {}, {}, {}, {}, {} }

function Ui.textSize(font, fontSize, text)
    local cache = Ui.textCache
    local key = tostring(font) .. ":" .. tostring(fontSize) .. ":" .. text
    local size = cache.entries[key]
    if size ~= nil then
        return size
    end

    size = Render.TextSize(font, fontSize, text)
    local cursor = cache.cursor
    local previousKey = cache.keys[cursor]
    if previousKey ~= nil then
        cache.entries[previousKey] = nil
    end
    cache.entries[key] = size
    cache.keys[cursor] = key
    cache.cursor = cursor % cache.limit + 1
    return size
end

function Ui.clearMarkers()
    local markers = Ui.panel.markers
    for i = #markers, 1, -1 do
        markers[i] = nil
    end
end

function Ui.setBounds(bounds, x, y, width, height)
    bounds = bounds or {}
    bounds.x = x
    bounds.y = y
    bounds.width = width
    bounds.height = height
    return bounds
end

function Ui.imageHandleIsUsable(handle)
    if type(handle) ~= "number" or handle == 0 then
        return false
    end

    local ok, size = pcall(Render.ImageSize, handle)
    return ok and size ~= nil and size.x > 8 and size.y > 8
end

function Ui.initializeCampPanelImages()
    Ui.panel.mapImage = nil

    for i = 1, #C.CAMP_PANEL_MAP_PATHS do
        local ok, handle = pcall(Render.LoadImage, C.CAMP_PANEL_MAP_PATHS[i])
        if ok and Ui.imageHandleIsUsable(handle) then
            Ui.panel.mapImage = handle
            break
        end
    end

    local ok, fallback = pcall(
        Render.LoadSvgString,
        C.CAMP_PANEL_FALLBACK_SVG,
        Vec2(512, 512),
        "ld_auto_farm_camp_map_fallback_v1"
    )
    if ok and Ui.imageHandleIsUsable(fallback) then
        Ui.panel.fallbackImage = fallback
    else
        Ui.panel.fallbackImage = nil
    end

    Lifecycle.bridgeLog("info", "lone_druid_auto_farm: camp panel images loaded", {
        dota_map = Ui.panel.mapImage ~= nil,
        fallback_map = Ui.panel.fallbackImage ~= nil,
    })
end

function Ui.initializeRadiusCircle()
    -- Resource reload can reuse a font handle; discard its previous measurements.
    Ui.textCache.entries = {}
    Ui.textCache.keys = {}
    Ui.textCache.cursor = 1
    Ui.radiusCircleOffsets = {}

    for index = 0, C.RADIUS_CIRCLE_SEGMENTS do
        local angle = index * math.pi * 2 / C.RADIUS_CIRCLE_SEGMENTS
        Ui.radiusCircleOffsets[#Ui.radiusCircleOffsets + 1] = {
            x = math.cos(angle),
            y = math.sin(angle),
        }
    end

    Ui.status.radiusColor = Color(255, 70, 70, 170)
    Ui.panel.font = Render.LoadFont(
        "MuseoSansEx",
        Enum.FontCreate.FONTFLAG_ANTIALIAS,
        500
    )
    Ui.panel.iconFont = Render.LoadFont(
        "FontAwesomeEx",
        Enum.FontCreate.FONTFLAG_ANTIALIAS,
        400
    )
    Ui.initializeCampPanelImages()
end

function Ui.activityText()
    if options.enabled:Get() and Threats.data.cautious
        and (state.activity == "moving" or state.activity == "farming")
    then
        return Settings.localize("ldaf.status.safe_farm")
    end
    local activity = state.activity or "idle"
    if not options.enabled:Get() then
        return Settings.localize(C.UI_TEXT.statusDisabled)
    end

    return Settings.localize(C.UI_TEXT.statusByActivity[activity] or C.UI_TEXT.statusByActivity.idle)
end

function Ui.formatCountdown(seconds)
    local wholeSeconds = math.max(0, math.ceil(seconds or 0))
    return string.format("%02d:%02d", math.floor(wholeSeconds / 60), wholeSeconds % 60)
end

function Ui.statusReasonText()
    if not options.enabled:Get() then
        return Settings.localize(C.UI_TEXT.statusDisabled)
    end

    if state.activity == "retreat" then
        local retreatKey = state.retreatReason == "enemy"
            and "ldaf.status.reason_enemy"
            or state.retreatReason == "health" and "ldaf.status.reason_health"
            or state.retreatReason == "mana" and "ldaf.status.reason_mana"
        if retreatKey ~= nil then
            return Settings.localize(retreatKey)
        end
    end

    local activity = state.activity or "idle"
    local key = C.UI_TEXT.statusReasonByActivity[activity]
        or "ldaf.status.reason_active"
    return Settings.localize(key)
end

function Ui.statusNextText(now)
    if not options.enabled:Get() then
        return Settings.localize("ldaf.status.next_enable")
    end

    if state.activity == "manual_pause" then
        return string.format(
            Settings.localize("ldaf.status.next_resume"),
            Ui.formatCountdown(state.manualPauseUntil - now)
        )
    end

    local activity = state.activity or "idle"
    local key = C.UI_TEXT.statusNextByActivity[activity]
        or "ldaf.status.next_find_camp"
    return Settings.localize(key)
end

function Ui.wisdomStatusText(now)
    if not options.autoRunes:Get() or not options.wisdomRunes:Get() then
        return Settings.localize(C.UI_TEXT.statusDisabled)
    end

    local gameSeconds = Lifecycle.inGameClock(now)
    if gameSeconds == nil then
        return "-"
    end

    local spawnAt = WisdomControl.spawnForTime(gameSeconds)
    local countdown = string.format(
        Settings.localize("ldaf.status.countdown"),
        Ui.formatCountdown(spawnAt - gameSeconds)
    )
    local skipReason = WisdomControl.data.lastSkipReason
    if skipReason == nil then
        return countdown
    end

    local reasonKey = C.UI_TEXT.wisdomSkipByReason[skipReason]
        or "ldaf.status.skip_unknown"
    return string.format(
        Settings.localize("ldaf.status.wisdom_skip"),
        countdown,
        Settings.localize(reasonKey)
    )
end

function Ui.stackStatusText(hero, now)
    if not options.autoStack:Get() then
        return Settings.localize(C.UI_TEXT.statusDisabled)
    end

    local remaining = nil
    if state.stacking then
        remaining = state.stackPullAt - now
    else
        local camp = state.targetCamp or state.stackCamp
        local _, _, second = Lifecycle.inGameClock(now)
        if camp == nil or camp.box == nil or second == nil then
            return "-"
        end

        remaining = Stack.campPullSecond(camp, Entity.GetAbsOrigin(hero)) - second
        if remaining < 0 then
            remaining = remaining + 60
        end
    end

    if remaining <= 0 then
        return Settings.localize("ldaf.status.now")
    end
    return string.format(
        Settings.localize("ldaf.status.countdown"),
        Ui.formatCountdown(remaining)
    )
end

function Ui.campPanelRound(value)
    return math.floor(value + 0.5)
end

function Ui.campPanelStyle(name, fallback)
    if not Ui.panel.styleOk then
        return fallback
    end

    local color = Menu.Style(name)
    if color == nil or color.r == nil then
        return fallback
    end

    return color
end

function Ui.campPanelSpeed(multiplier)
    if not Ui.panel.animFound then
        Ui.panel.animFound = true
        Ui.panel.animWidget = Menu.Find("SettingsHidden", "", "", "", "Main", "Animation Duration")
    end

    local duration = Ui.panel.animWidget ~= nil and Ui.panel.animWidget:Get() or 50
    return multiplier * 1000 / Geometry.clamp(duration, 10, 1000)
end

function Ui.refreshCampPanelTheme()
    local frame = GlobalVars.GetFrameCount()
    if frame == Ui.panel.themeFrame then
        return
    end
    Ui.panel.themeFrame = frame

    Ui.colors = {
        body = Ui.campPanelStyle("main_background", Color(24, 24, 27, 235)),
        plate = Ui.campPanelStyle("group_background", Color(37, 37, 42, 235)),
        border = Ui.campPanelStyle("outline", Color(48, 48, 55, 180)),
        accent = Ui.campPanelStyle("primary", Color(214, 58, 50, 250)),
        text = Ui.campPanelStyle("primary_widgets_text", Color(238, 238, 242, 250)),
        textMuted = Ui.campPanelStyle("third_tab_text", Color(146, 146, 156, 210)),
        switchOff = Ui.campPanelStyle("disabled_switch_circle", Color(120, 120, 130, 235)),
        enabled = Ui.campPanelStyle("multiselect_item_selected", Color(63, 191, 95, 245)),
        disabled = Ui.campPanelStyle("multiselect_item", Color(224, 50, 45, 245)),
        shadow = Color(0, 0, 0, 130),
        hole = Color(0, 0, 0, 110),
    }
end

function Ui.campPanelEase(current, goal, speed)
    local dt = GlobalVars.GetAbsFrameTime() or 0
    if dt <= 0 or dt > 0.2 then
        return goal
    end
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
    Render.Text(
        Ui.panel.iconFont,
        fontSize,
        glyph,
        Vec2(
            Ui.campPanelRound(centerX - size.x * 0.5),
            Ui.campPanelRound(centerY - size.y * 0.5)
        ),
        color
    )
    return size
end

function Ui.drawCampPanelCenteredText(fontSize, text, x, y, width, height, color)
    local textSize = Ui.textSize(Ui.panel.font, fontSize, text)
    Render.Text(
        Ui.panel.font,
        fontSize,
        text,
        Vec2(
            Ui.campPanelRound(x + (width - textSize.x) * 0.5),
            Ui.campPanelRound(y + (height - textSize.y) * 0.5)
        ),
        color
    )
end

function Ui.drawCampPanelRow(fontSize, label, value, x, y, width, height, labelColor, valueColor)
    local labelSize = Ui.textSize(Ui.panel.font, fontSize, label)
    local valueSize = Ui.textSize(Ui.panel.font, fontSize, value)
    local textY = Ui.campPanelRound(y + (height - labelSize.y) * 0.5)
    Render.Text(Ui.panel.font, fontSize, label, Vec2(x, textY), labelColor)
    Render.Text(
        Ui.panel.font,
        fontSize,
        value,
        Vec2(Ui.campPanelRound(x + width - valueSize.x), textY),
        valueColor
    )
end

function Ui.campPanelPointInside(bounds, cursorX, cursorY)
    return bounds ~= nil
        and cursorX >= bounds.x
        and cursorX <= bounds.x + bounds.width
        and cursorY >= bounds.y
        and cursorY <= bounds.y + bounds.height
end

function Ui.campPanelMarkerAt(cursorX, cursorY)
    local closest = nil
    local closestDistance = math.huge

    for i = 1, #Ui.panel.markers do
        local marker = Ui.panel.markers[i]
        local deltaX = cursorX - marker.x
        local deltaY = cursorY - marker.y
        local distance = deltaX * deltaX + deltaY * deltaY
        if distance <= marker.hitRadius * marker.hitRadius
            and distance < closestDistance
        then
            closest = marker
            closestDistance = distance
        end
    end

    return closest
end

function Ui.campPanelActionReady()
    local frame = GlobalVars.GetFrameCount()
    if frame - Ui.panel.lastActionFrame < C.CAMP_PANEL_CLICK_DEBOUNCE_FRAMES then
        return false
    end

    Ui.panel.lastActionFrame = frame
    return true
end

function Ui.campWorldToPanelMap(worldX, worldY, mapX, mapY, mapSize)
    local worldSpan = C.CAMP_PANEL_WORLD_MAX - C.CAMP_PANEL_WORLD_MIN
    local horizontal = Geometry.clamp((worldX - C.CAMP_PANEL_WORLD_MIN) / worldSpan, 0, 1)
    local vertical = Geometry.clamp(1 - (worldY - C.CAMP_PANEL_WORLD_MIN) / worldSpan, 0, 1)
    local inset = math.max(3, Ui.campPanelRound(mapSize * 0.012))

    return mapX + inset + horizontal * (mapSize - inset * 2),
        mapY + inset + vertical * (mapSize - inset * 2)
end

function Ui.drawCampSelector(hero)
    local panel = Ui.panel
    if panel.mouseHeld
        and not Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE1, true)
    then
        panel.mouseHeld = false
        panel.capturingMouse = false
        panel.dragging = false
    end

    if options.showCampPanel == nil
        or not options.showCampPanel:Get()
        or panel.font == nil
    then
        panel.dragging = false
        Ui.clearMarkers()
        panel.width = 0
        panel.height = 0
        return
    end

    local team = Entity.GetTeamNum(hero)
    local side = Settings.selectionSideForTeam(team)
    if side == nil then
        panel.dragging = false
        Ui.clearMarkers()
        return
    end
    if not Settings.initializeCampSelections(team) then
        panel.dragging = false
        Ui.clearMarkers()
        return
    end
    local layout = Settings.campLayoutsBySide[side]

    Ui.refreshCampPanelTheme()
    local colors = Ui.colors

    local scale = options.campPanelScale:Get() / 100
    local fullWidth = Ui.campPanelRound(360 * scale)
    local headerHeight = Ui.campPanelRound(26 * scale)
    local bodyGap = Ui.campPanelRound(6 * scale)
    local padding = Ui.campPanelRound(12 * scale)
    local rowHeight = Ui.campPanelRound(21 * scale)
    local sectionGap = Ui.campPanelRound(9 * scale)
    local mapSize = fullWidth - padding * 2
    local statusHeight = rowHeight * 3 + Ui.campPanelRound(12 * scale)
    panel.mapAnim = Ui.campPanelEase(
        panel.mapAnim,
        panel.mapHidden and 0 or 1,
        Ui.campPanelSpeed(1)
    )
    local mapShow = panel.mapAnim
    mapShow = mapShow * mapShow * (3 - 2 * mapShow)
    local bodyHeight = padding + statusHeight
        + Ui.campPanelRound((sectionGap + mapSize) * mapShow) + padding

    local iconSize = math.max(9, Ui.campPanelRound(14 * scale))
    local toggleSize = math.max(11, Ui.campPanelRound(18 * scale))
    local scriptEnabled = options.enabled:Get()
    local toggleGlyph = scriptEnabled and "\u{f205}" or "\u{f204}"
    local toggleWidth = Ui.textSize(panel.iconFont, toggleSize, toggleGlyph).x
    local chevronHit = math.max(7, Ui.campPanelRound(11 * scale))
    local miniWidth = Ui.campPanelRound(chevronHit * 2 + toggleWidth + 20 * scale)

    local screen = Render.ScreenSize()
    if panel.x == nil or panel.y == nil then
        panel.x = Config.ReadInt(C.SETTINGS_CONFIG, "camp_panel_x", -1)
        panel.y = Config.ReadInt(C.SETTINGS_CONFIG, "camp_panel_y", -1)
        if panel.x < 0 or panel.y < 0 then
            panel.x = Ui.campPanelRound(screen.x * 0.015)
            panel.y = Ui.campPanelRound(screen.y * 0.09)
        end
    end

    local cursorX, cursorY = Input.GetCursorPos()
    if panel.dragging then
        if Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE1, true) then
            panel.x = cursorX - panel.dragOffsetX - (panel.slide or 0)
            panel.y = cursorY - panel.dragOffsetY
        else
            panel.dragging = false
        end
    end

    local mini = panel.mini
    if mini ~= nil then
        panel.miniSide = mini
    end
    panel.miniAnim = Ui.campPanelEase(
        panel.miniAnim,
        mini ~= nil and 1 or 0,
        Ui.campPanelSpeed(1)
    )
    local fold = panel.miniAnim
    fold = fold * fold * (3 - 2 * fold)
    if fold < 0.002 then
        panel.miniSide = nil
    end

    local width = fullWidth
    local edge = 1
    if panel.miniSide ~= nil then
        panel.edgeSide = panel.miniSide
    elseif panel.x <= edge then
        panel.edgeSide = "left"
    elseif panel.x + fullWidth >= screen.x - edge then
        panel.edgeSide = "right"
    else
        panel.edgeSide = nil
    end

    panel.open = Ui.campPanelEase(
        panel.open,
        (panel.collapsed or mini ~= nil) and 0 or 1,
        Ui.campPanelSpeed(1)
    )
    local open = panel.open
    local ease = open * open * (3 - 2 * open)
    local shown = Ui.campPanelRound(bodyHeight * ease)
    local fade = ease * ease
    local height = headerHeight + (shown > 2 and bodyGap + shown or 0)

    if panel.miniSide == "left" then
        panel.x = 0
    elseif panel.miniSide == "right" then
        panel.x = screen.x - width
    end
    panel.x = Geometry.clamp(panel.x, 0, math.max(0, screen.x - width))
    panel.y = Geometry.clamp(panel.y, 0, math.max(0, screen.y - height))
    panel.width = width
    panel.height = height
    panel.headerHeight = headerHeight
    if panel.wasDragging and not panel.dragging then
        Config.WriteInt(C.SETTINGS_CONFIG, "camp_panel_x", Ui.campPanelRound(panel.x))
        Config.WriteInt(C.SETTINGS_CONFIG, "camp_panel_y", Ui.campPanelRound(panel.y))
    end
    panel.wasDragging = panel.dragging

    local slide = fold * (fullWidth - miniWidth) * (panel.edgeSide == "right" and 1 or -1)
    local x = Ui.campPanelRound(panel.x + slide)
    local y = Ui.campPanelRound(panel.y)
    panel.drawX = x
    panel.slide = slide
    local finishX = x + width
    local rounding = math.max(3, Ui.campPanelRound(6 * scale))

    if shown > 2 then
        local top = y + headerHeight + bodyGap
        local bottom = top + shown

        Render.PushClip(Vec2(x - fullWidth, top), Vec2(finishX + fullWidth, bottom))
        Render.Shadow(
            Vec2(x, top),
            Vec2(finishX, bottom),
            Ui.campPanelFade(colors.shadow, fade),
            math.max(6, Ui.campPanelRound(12 * scale)),
            rounding
        )
        Render.Blur(Vec2(x, top), Vec2(finishX, bottom), 3, fade, rounding)
        Render.FilledRect(
            Vec2(x, top),
            Vec2(finishX, bottom),
            Ui.campPanelFade(colors.body, fade),
            rounding
        )
        Render.Rect(
            Vec2(x, top),
            Vec2(finishX, bottom),
            Ui.campPanelFade(colors.border, fade),
            rounding,
            Enum.DrawFlags.None,
            1
        )

        local mapX = x + padding
        local mapY = top + padding + statusHeight + sectionGap
        local mapRounding = math.max(3, Ui.campPanelRound(5 * scale))
        local mapFade = fade * mapShow * mapShow
        Render.FilledRect(
            Vec2(mapX, mapY),
            Vec2(mapX + mapSize, mapY + mapSize),
            Ui.campPanelFade(colors.plate, mapFade),
            mapRounding
        )
        local mapHandle = panel.mapImage or panel.fallbackImage
        if mapHandle ~= nil then
            Render.Image(
                mapHandle,
                Vec2(mapX, mapY),
                Vec2(mapSize, mapSize),
                Color(255, 255, 255, Ui.campPanelRound(250 * mapFade)),
                mapRounding
            )
        end
        Render.Rect(
            Vec2(mapX, mapY),
            Vec2(mapX + mapSize, mapY + mapSize),
            Ui.campPanelFade(colors.border, mapFade),
            mapRounding,
            Enum.DrawFlags.None,
            1
        )

        Ui.clearMarkers()
        local markerRadius = math.max(5, Ui.campPanelRound(10 * scale))
        local markerHitRadius = markerRadius + math.max(3, Ui.campPanelRound(4 * scale))
        for i = 1, (mapShow > 0.85 and #layout or 0) do
            local desired = layout[i]
            local markerX, markerY = Ui.campWorldToPanelMap(
                desired.x,
                desired.y,
                mapX,
                mapY,
                mapSize
            )
            local marker = Ui.markerPool[i]
            if marker == nil then
                marker = {}
                Ui.markerPool[i] = marker
            end
            marker.x = markerX
            marker.y = markerY
            marker.hitRadius = markerHitRadius
            marker.selectionId = desired.id
            marker.label = Settings.campDisplayLabel(desired, i, side)
            marker.enabled = Settings.campSelectionEnabled(desired.id, team)
            panel.markers[i] = marker
        end

        local hoveredMarker = Ui.campPanelMarkerAt(cursorX, cursorY)
        local ringThickness = math.max(2, 2.8 * scale)
        local onSpeed = Ui.campPanelSpeed(2)
        local hoverSpeed = Ui.campPanelSpeed(3)
        for i = 1, #panel.markers do
            local marker = panel.markers[i]
            local id = marker.selectionId
            local goal = marker.enabled and 1 or 0

            local on = Ui.campPanelEase(panel.markerOn[id] or goal, goal, onSpeed)
            panel.markerOn[id] = on
            local grow = Ui.campPanelEase(
                panel.markerAnim[id] or 0,
                marker == hoveredMarker and 1 or 0,
                hoverSpeed
            )
            panel.markerAnim[id] = grow

            local ring = Ui.campPanelMix(colors.disabled, colors.enabled, on)
            ring = Ui.campPanelMix(ring, colors.text, grow * 0.4)
            local radius = markerRadius + grow * math.max(1, 2 * scale)
            local center = Vec2(marker.x, marker.y)

            Render.FilledCircle(center, radius, Ui.campPanelFade(colors.hole, mapFade))
            Render.Circle(center, radius, Ui.campPanelFade(ring, mapFade), ringThickness)
            if on > 0.02 then
                Render.FilledCircle(
                    center,
                    (math.max(2, Ui.campPanelRound(4.5 * scale)) + grow) * on,
                    Ui.campPanelFade(ring, mapFade)
                )
            end
        end

        local statusY = top + padding
        Render.FilledRect(
            Vec2(mapX, statusY),
            Vec2(mapX + mapSize, statusY + statusHeight),
            Ui.campPanelFade(colors.plate, fade),
            mapRounding
        )

        local statusCamp = state.stackCamp or state.targetCamp or state.preSpawnCamp
        local rowFontSize = math.max(9, Ui.campPanelRound(13 * scale))
        local rowX = mapX + Ui.campPanelRound(10 * scale)
        local rowWidth = mapSize - Ui.campPanelRound(20 * scale)
        local rowY = statusY + Ui.campPanelRound(6 * scale)
        local muted = Ui.campPanelFade(colors.textMuted, fade)
        local rows = Ui.panelRows
        rows[1][1] = Settings.localize(C.UI_TEXT.statusModeLabel)
        rows[1][2] = Ui.activityText()
        rows[1][3] = Ui.campPanelFade(colors.accent, fade)
        rows[2][1] = Settings.localize(C.UI_TEXT.statusCampLabel)
        rows[2][2] = statusCamp ~= nil and Settings.localizedLane(statusCamp.lane) or "-"
        rows[2][3] = Ui.campPanelFade(colors.text, fade)
        rows[3][1] = Settings.localize(C.UI_TEXT.statusHealthLabel)
        rows[3][2] = string.format("%.0f%%", Safety.healthPercent(hero))
        rows[3][3] = Ui.campPanelFade(colors.text, fade)
        for i = 1, #rows do
            Ui.drawCampPanelRow(
                rowFontSize,
                rows[i][1],
                rows[i][2],
                rowX,
                rowY + (i - 1) * rowHeight,
                rowWidth,
                rowHeight,
                muted,
                rows[i][3]
            )
        end

        Render.PopClip()
    else
        Ui.clearMarkers()
    end

    Render.Shadow(
        Vec2(x, y),
        Vec2(finishX, y + headerHeight),
        colors.shadow,
        math.max(6, Ui.campPanelRound(12 * scale)),
        rounding
    )
    Render.Blur(
        Vec2(x, y),
        Vec2(finishX, y + headerHeight),
        3,
        1,
        rounding
    )
    Render.FilledRect(
        Vec2(x, y),
        Vec2(finishX, y + headerHeight),
        colors.body,
        rounding
    )
    Render.Rect(
        Vec2(x, y),
        Vec2(finishX, y + headerHeight),
        colors.border,
        rounding,
        Enum.DrawFlags.None,
        1
    )

    local iconY = y + headerHeight * 0.5
    local inset = Ui.campPanelRound(15 * scale)
    local mirrored = x + fullWidth * 0.5 > screen.x * 0.5

    local chevronGlyph
    if mini ~= nil then
        chevronGlyph = mini == "left" and "\u{f054}" or "\u{f053}"
    elseif panel.edgeSide ~= nil then
        chevronGlyph = panel.edgeSide == "left" and "\u{f053}" or "\u{f054}"
    else
        chevronGlyph = panel.collapsed and "\u{f078}" or "\u{f077}"
    end

    local chevronX = mirrored and x + inset or finishX - inset
    panel.collapseBounds = Ui.setBounds(
        panel.collapseBounds, chevronX - chevronHit, y, chevronHit * 2, headerHeight
    )
    panel.chevronAnim = Ui.campPanelEase(
        panel.chevronAnim,
        Ui.campPanelPointInside(panel.collapseBounds, cursorX, cursorY) and 1 or 0,
        Ui.campPanelSpeed(3)
    )
    Ui.drawCampPanelIcon(
        iconSize,
        chevronGlyph,
        chevronX,
        iconY,
        Ui.campPanelMix(
            colors.textMuted,
            colors.accent,
            panel.chevronAnim
        )
    )

    local step = chevronHit + Ui.campPanelRound(6 * scale) + toggleWidth * 0.5
    local toggleX = mirrored and chevronX + step or chevronX - step
    local toggleHitX = toggleWidth * 0.5 + math.max(3, Ui.campPanelRound(5 * scale))
    panel.toggleBounds = Ui.setBounds(
        panel.toggleBounds, toggleX - toggleHitX, y, toggleHitX * 2, headerHeight
    )
    panel.toggleAnim = Ui.campPanelEase(
        panel.toggleAnim,
        scriptEnabled and 1 or 0,
        Ui.campPanelSpeed(2)
    )
    panel.togglePress = Ui.campPanelEase(panel.togglePress, 0, Ui.campPanelSpeed(2))
    local toggleColor = Ui.campPanelMix(
        colors.switchOff,
        colors.accent,
        panel.toggleAnim
    )
    Ui.drawCampPanelIcon(
        toggleSize,
        toggleGlyph,
        toggleX,
        iconY,
        Ui.campPanelMix(toggleColor, colors.text, panel.togglePress * 0.7)
    )

    local pinX = mirrored and finishX - inset or x + inset
    panel.pinBounds = Ui.setBounds(
        panel.pinBounds, pinX - chevronHit, y, chevronHit * 2, headerHeight
    )
    panel.pinAnim = Ui.campPanelEase(
        panel.pinAnim,
        Ui.campPanelPointInside(panel.pinBounds, cursorX, cursorY) and 1 or 0,
        Ui.campPanelSpeed(3)
    )
    Ui.drawCampPanelIcon(
        math.max(10, Ui.campPanelRound(15 * scale)),
        "\u{f3c5}",
        pinX,
        iconY,
        Ui.campPanelMix(
            Ui.campPanelMix(colors.textMuted, colors.accent, mapShow),
            colors.text,
            panel.pinAnim * 0.35
        )
    )
    Ui.drawCampPanelCenteredText(
        math.max(10, Ui.campPanelRound(16 * scale)),
        Settings.localize(C.UI_TEXT.campPanelTitle),
        x,
        y,
        width,
        headerHeight,
        colors.text
    )
end

function Ui.drawStatus(hero)
    local panel = Ui.panel
    if not options.showStatus:Get() or panel.font == nil then
        Ui.status.dragging = false
        return
    end

    Ui.refreshCampPanelTheme()
    local colors = Ui.colors

    local statusCamp = state.stackCamp or state.targetCamp or state.preSpawnCamp
    local retreating = state.activity == "retreat"
    local now = GameRules.GetGameTime()
    local rows = Ui.statusRows
    rows[1][1] = Settings.localize(C.UI_TEXT.statusModeLabel)
    rows[1][2] = Ui.activityText()
    rows[1][3] = retreating and colors.disabled or colors.accent
    rows[2][1] = Settings.localize(C.UI_TEXT.statusCampLabel)
    rows[2][2] = statusCamp ~= nil and Settings.localizedLane(statusCamp.lane) or "-"
    rows[2][3] = colors.text
    rows[3][1] = Settings.localize(C.UI_TEXT.statusHealthLabel)
    rows[3][2] = string.format("%.0f%%", Safety.healthPercent(hero))
    rows[3][3] = colors.text
    rows[4][1] = Settings.localize(C.UI_TEXT.statusReasonLabel)
    rows[4][2] = Ui.statusReasonText()
    rows[4][3] = colors.text
    rows[5][1] = Settings.localize(C.UI_TEXT.statusNextLabel)
    rows[5][2] = Ui.statusNextText(now)
    rows[5][3] = colors.text
    rows[6][1] = Settings.localize(C.UI_TEXT.statusWisdomLabel)
    rows[6][2] = Ui.wisdomStatusText(now)
    rows[6][3] = colors.accent
    rows[7][1] = Settings.localize(C.UI_TEXT.statusStackLabel)
    rows[7][2] = Ui.stackStatusText(hero, now)
    rows[7][3] = colors.text

    local scale = options.statusScale:Get() / 100
    local fontSize = math.max(9, Ui.campPanelRound(13 * scale))
    local rowHeight = Ui.campPanelRound(21 * scale)
    local padding = Ui.campPanelRound(11 * scale)
    local width = Ui.campPanelRound(180 * scale)
    for i = 1, #rows do
        local line = Ui.textSize(panel.font, fontSize, rows[i][1]).x
            + Ui.textSize(panel.font, fontSize, rows[i][2]).x
        width = math.max(width, Ui.campPanelRound(line + padding * 2 + 24 * scale))
    end
    local height = padding * 2 + rowHeight * #rows
    local screen = Render.ScreenSize()

    if Ui.status.x == nil or Ui.status.y == nil then
        Ui.status.x = Config.ReadInt(C.SETTINGS_CONFIG, "status_x", -1)
        Ui.status.y = Config.ReadInt(C.SETTINGS_CONFIG, "status_y", -1)
        if Ui.status.x < 0 or Ui.status.y < 0 then
            Ui.status.x = Ui.campPanelRound(screen.x * 0.172)
            Ui.status.y = Ui.campPanelRound(screen.y - height - screen.y * 0.017)
        end
    end

    local cursorX, cursorY = Input.GetCursorPos()
    local mouseDown = Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE1, true)
    if not Ui.status.dragging
        and Input.IsCursorInRect(Ui.status.x, Ui.status.y, width, height)
        and Input.IsKeyDownOnce(Enum.ButtonCode.KEY_MOUSE1, true)
    then
        Ui.status.dragging = true
        Ui.status.dragOffsetX = cursorX - Ui.status.x
        Ui.status.dragOffsetY = cursorY - Ui.status.y
    end

    if Ui.status.dragging then
        if mouseDown then
            Ui.status.x = cursorX - Ui.status.dragOffsetX
            Ui.status.y = cursorY - Ui.status.dragOffsetY
        else
            Ui.status.dragging = false
        end
    end

    Ui.status.x = Geometry.clamp(Ui.status.x, 0, math.max(0, screen.x - width))
    Ui.status.y = Geometry.clamp(Ui.status.y, 0, math.max(0, screen.y - height))
    if Ui.status.wasDragging and not Ui.status.dragging then
        Config.WriteInt(C.SETTINGS_CONFIG, "status_x", Ui.campPanelRound(Ui.status.x))
        Config.WriteInt(C.SETTINGS_CONFIG, "status_y", Ui.campPanelRound(Ui.status.y))
    end
    Ui.status.wasDragging = Ui.status.dragging

    local start = Vec2(Ui.campPanelRound(Ui.status.x), Ui.campPanelRound(Ui.status.y))
    local finish = Vec2(start.x + width, start.y + height)
    local rounding = math.max(3, Ui.campPanelRound(6 * scale))

    Render.Shadow(
        start,
        finish,
        colors.shadow,
        math.max(6, Ui.campPanelRound(12 * scale)),
        rounding
    )
    Render.Blur(start, finish, 3, 1, rounding)
    Render.FilledRect(start, finish, colors.body, rounding)
    Render.Rect(start, finish, colors.border, rounding, Enum.DrawFlags.None, 1)

    for i = 1, #rows do
        Ui.drawCampPanelRow(
            fontSize,
            rows[i][1],
            rows[i][2],
            start.x + padding,
            start.y + padding + (i - 1) * rowHeight,
            width - padding * 2,
            rowHeight,
            colors.textMuted,
            rows[i][3]
        )
    end
end

function Ui.onDraw()
    if not options.ready then
        return
    end

    local hero = Heroes.GetLocal()
    if not Lifecycle.isLoneDruid(hero) then
        Ui.panel.dragging = false
        Ui.panel.capturingMouse = false
        return
    end

    Ui.drawCampSelector(hero)

    if not Entity.IsAlive(hero) then
        return
    end

    if options.showRadius:Get() and Ui.status.radiusColor ~= nil then
        local center = Entity.GetAbsOrigin(hero)
        local radius = options.enemyRadius:Get()
        local previousScreen = nil
        local previousVisible = false

        for i = 1, #Ui.radiusCircleOffsets do
            local offset = Ui.radiusCircleOffsets[i]
            local worldPosition = Vector(
                center.x + offset.x * radius,
                center.y + offset.y * radius,
                center.z + C.RADIUS_CIRCLE_Z_OFFSET
            )
            local screenPosition, visible = Render.WorldToScreen(worldPosition)

            if previousScreen ~= nil and previousVisible and visible then
                Render.Line(previousScreen, screenPosition, Ui.status.radiusColor, 1.5)
            end

            previousScreen = screenPosition
            previousVisible = visible
        end
    end

    Ui.drawStatus(hero)
end

function Ui.onKeyEvent(data)
    if data == nil or data.key ~= Enum.ButtonCode.KEY_MOUSE1 then
        return true
    end

    local keyDown = data.event == Enum.EKeyEvent.EKeyEvent_KEY_DOWN
    local keyUp = data.event == Enum.EKeyEvent.EKeyEvent_KEY_UP
    if keyUp then
        local captured = Ui.panel.capturingMouse or Ui.panel.dragging
        Ui.panel.mouseHeld = false
        Ui.panel.capturingMouse = false
        Ui.panel.dragging = false
        return not captured
    end

    if not keyDown then
        return true
    end

    if Ui.panel.mouseHeld then
        return not Ui.panel.capturingMouse
    end
    Ui.panel.mouseHeld = true

    if not options.ready
        or options.showCampPanel == nil
        or not options.showCampPanel:Get()
        or Ui.panel.width <= 0
        or Ui.panel.height <= 0
        or Input.IsPopupOpen()
        or (Input.IsInputCaptured() and not Menu.Opened())
    then
        return true
    end

    local hero = Heroes.GetLocal()
    if not Lifecycle.isLoneDruid(hero) then
        return true
    end

    local cursorX, cursorY = Input.GetCursorPos()
    local panelX = Ui.panel.drawX or Ui.panel.x
    local insidePanel = cursorX >= panelX
        and cursorX <= panelX + Ui.panel.width
        and cursorY >= Ui.panel.y
        and cursorY <= Ui.panel.y + Ui.panel.height
    if not insidePanel then
        return true
    end

    Ui.panel.capturingMouse = true

    if Ui.campPanelPointInside(Ui.panel.toggleBounds, cursorX, cursorY) then
        if Ui.campPanelActionReady() then
            options.enabled:Set(not options.enabled:Get())
            Ui.panel.togglePress = 1
        end
        Ui.panel.dragging = false
        return false
    end

    if Ui.campPanelPointInside(Ui.panel.pinBounds, cursorX, cursorY) then
        if Ui.campPanelActionReady() then
            Ui.panel.mapHidden = not Ui.panel.mapHidden
        end
        Ui.panel.dragging = false
        return false
    end

    if Ui.campPanelPointInside(Ui.panel.collapseBounds, cursorX, cursorY) then
        if Ui.campPanelActionReady() then
            if Ui.panel.mini ~= nil then
                Ui.panel.mini = nil
                Ui.panel.collapsed = false
            elseif Ui.panel.edgeSide ~= nil then
                Ui.panel.mini = Ui.panel.edgeSide
            else
                Ui.panel.collapsed = not Ui.panel.collapsed
            end
        end
        Ui.panel.dragging = false
        return false
    end

    if not Ui.panel.collapsed then
        local marker = Ui.campPanelMarkerAt(cursorX, cursorY)
        if marker ~= nil then
            if not Ui.campPanelActionReady() then
                return false
            end
            local team = Entity.GetTeamNum(hero)
            local enabled = not Settings.campSelectionEnabled(marker.selectionId, team)
            Settings.setCampSelection(marker.selectionId, team, enabled)
            Lifecycle.bridgeLog("info", "lone_druid_auto_farm: manual camp selection changed", {
                camp = marker.label or marker.selectionId,
                enabled = enabled,
            })
            return false
        end
    end

    if cursorY <= Ui.panel.y + Ui.panel.headerHeight then
        Ui.panel.dragging = true
        Ui.panel.dragOffsetX = cursorX - panelX
        Ui.panel.dragOffsetY = cursorY - Ui.panel.y
    end

    return false
end

-- Delivery ------------------------------------------------------------

function Delivery.findBear()
    local bear = WorldState.findSpiritBear()
    if bear == nil or Entity.IsDormant(bear) or NPC.IsWaitingToSpawn(bear) then
        return nil
    end

    return bear
end

function Delivery.findAbility(courier)
    local delivery = state.courierDelivery
    for i = 1, #delivery.abilities do
        local ability = NPC.GetAbility(courier, delivery.abilities[i])
        if ability ~= nil and Ability.GetLevel(ability) > 0 then
            return ability
        end
    end

    return nil
end

function Delivery.hasItems(courier)
    if courier ~= nil then
        for slot = 0, 8 do
            if NPC.GetItemByIndex(courier, slot) ~= nil then
                return true
            end
        end
    end
    if state.hero ~= nil then
        for slot = 9, 14 do
            if NPC.GetItemByIndex(state.hero, slot) ~= nil then
                return true
            end
        end
    end
    return false
end

function Delivery.canStart(courier)
    local courierState = Courier.GetCourierState(courier)
    local stateReady = courierState == Enum.CourierState.COURIER_STATE_IDLE
        or courierState == Enum.CourierState.COURIER_STATE_AT_BASE
    return stateReady and Delivery.hasItems(courier)
end

function Delivery.handle(now)
    local delivery = state.courierDelivery
    if not options.autoCourierBear:Get() then
        delivery.courier = nil
        delivery.nextThinkAt = now
        delivery.abilityMissingLogged = false
        return
    end

    if now < delivery.manualPauseUntil or now < delivery.nextThinkAt then
        return
    end
    delivery.nextThinkAt = now + delivery.thinkInterval

    local bear = Delivery.findBear()
    if bear == nil then
        delivery.courier = nil
        return
    end

    local courier = Couriers.GetLocal()
    if courier == nil
        or not Couriers.Contains(courier)
        or not Entity.IsAlive(courier)
        or Entity.IsDormant(courier)
        or NPC.IsWaitingToSpawn(courier)
    then
        delivery.courier = nil
        return
    end
    delivery.courier = courier

    if not Delivery.canStart(courier) or now < delivery.nextOrderAt then
        return
    end

    local ability = Delivery.findAbility(courier)
    if ability == nil then
        if not delivery.abilityMissingLogged then
            delivery.abilityMissingLogged = true
            Lifecycle.bridgeLog("warn", "lone_druid_auto_farm: courier delivery ability not found", nil)
        end
        return
    end
    delivery.abilityMissingLogged = false

    if Ability.CanBeExecuted(ability) ~= Enum.AbilityCastResult.READY then
        return
    end

    Player.PrepareUnitOrders(
        state.player,
        Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TARGET,
        bear,
        Entity.GetAbsOrigin(bear),
        ability,
        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
        courier,
        false,
        false,
        false,
        false,
        "ld_auto_farm_courier_bear",
        false
    )
    delivery.nextOrderAt = now + delivery.orderInterval
end

-- Platform callback adapters. Ordering lives in Lifecycle.onUpdate.

function script.OnScriptsLoaded()
    return Lifecycle.onScriptsLoaded()
end

function script.OnUpdate()
    return Lifecycle.onUpdate()
end

function script.OnDraw()
    return Ui.onDraw()
end

function script.OnKeyEvent(data)
    return Ui.onKeyEvent(data)
end

function script.OnParticleCreate(data)
    return WisdomControl.onParticleCreate(data)
end

function script.OnParticleUpdate(data)
    return WisdomControl.onParticleUpdate(data)
end

function script.OnParticleDestroy(data)
    return WisdomControl.onParticleDestroy(data)
end

function script.OnPrepareUnitOrders(data)
    return Orders.onPrepareUnitOrders(data)
end

return script
