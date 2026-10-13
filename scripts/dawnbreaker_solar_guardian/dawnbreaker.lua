--[[
    Dawnbreaker: Solar Guardian Auto-Save Helper (Umbrella Lua API v2.0)
    
    Специализированный скрипт для ульты Dawnbreaker (Solar Guardian):
    1. Авто-спасение союзников по порогу здоровья (% HP):
       - Настраиваемый порог здоровья союзника (по умолчанию 35% HP).
       - Проверка угрозы: спасает только если рядом с союзником есть враги.
    2. Учет ресурсов Dawnbreaker (% Mana и % HP):
       - Минимальный процент маны Dawnbreaker (дефолт 20% Mana): не тратит ульту,
         если у Dawnbreaker мало маны, чтобы не прилетать пустой.
       - Минимальный процент здоровья Dawnbreaker (дефолт 25% HP): защита от фида,
         не дает лететь на помощь, если сама Dawnbreaker при смерти.
    3. Мгновенное спасение при фатальных дисейблах (CC Trigger):
       - Мгновенный каст при Duel, Black Hole, Chronosphere, Fiend's Grip, 
         Dismember, Shackles, Lasso, Reaper's Scythe, Berserker's Call, Pulverize или стане.
    4. Экстренная клавиша ручного спасения (Panic Save Key):
       - Мгновенно находит самого уязвимого тиммейта и кастует ульту на него.
    5. Умное упреждение движения (Lead Position Prediction):
       - Кастует круг наперед по траектории бега союзника (0.4с вперед),
         удерживая его в центре исцеления и урона.
    6. Защита от руина:
       - Игнорирует союзников на фонтане и иллюзии.
       - Не кастует под станом/сайленсом/хексом самой Dawnbreaker.
    7. Aghanim's Scepter Support:
       - Автоматически направляет круг ульты за союзником во время ченнелинга.
    8. Нулевая нагрузка на FPS (0% CPU, если герой не Dawnbreaker).
--]]

---@diagnostic disable: undefined-global

local Script = {}

--#region Constants & Icons

local HERO_NAME = "npc_dota_hero_dawnbreaker"
local ULT_NAME  = "dawnbreaker_solar_guardian"

local MODIFIERS = {
    r_channel = "modifier_dawnbreaker_solar_guardian",
    thinker   = "modifier_dawnbreaker_solar_guardian_thinker",
    aghs      = "modifier_item_ultimate_scepter",
    fountain  = "modifier_fountain_passive",
}

-- Фатальные дисейблы для мгновенного спасения
local FATAL_DEBUFFS = {
    ["modifier_legion_commander_duel"]             = true,
    ["modifier_enigma_black_hole_pull"]            = true,
    ["modifier_faceless_void_chronosphere_freeze"] = true,
    ["modifier_bane_fiends_grip"]                  = true,
    ["modifier_pudge_dismember"]                   = true,
    ["modifier_shadow_shaman_shackles"]            = true,
    ["modifier_batrider_flaming_lasso"]            = true,
    ["modifier_necrolyte_reapers_scythe"]          = true,
    ["modifier_axe_berserkers_call"]               = true,
    ["modifier_primal_beast_pulverize"]            = true,
}

-- Станы от нейтральных крипов, Рошана и Торментора
local CREEP_STUN_MODIFIERS = {
    ["modifier_centaur_khan_war_stomp"]                 = true,
    ["modifier_mud_golem_hurl_boulder"]                 = true,
    ["modifier_polar_furbolg_ursa_warrior_thunder_clap"] = true,
    ["modifier_satyr_hellcaller_shockwave"]             = true,
    ["modifier_roshan_slam"]                            = true,
    ["modifier_roshan_bash"]                            = true,
}

-- Модификаторы всех видов иллюзий и клонов
local ILLUSION_MODIFIERS = {
    ["modifier_illusion"]                                   = true,
    ["modifier_phantom_lancer_juxtapose_illusion"]          = true,
    ["modifier_phantom_lancer_doppelwalk_illusion"]         = true,
    ["modifier_terrorblade_conjureimage"]                   = true,
    ["modifier_chaos_knight_phantasm_illusion"]             = true,
    ["modifier_dark_seer_wallofreplica_illusion"]           = true,
    ["modifier_grimstroke_dark_portrait"]                  = true,
    ["modifier_morphling_replicate_illusion"]               = true,
    ["modifier_vengefulspirit_hybrid_special"]              = true,
    ["modifier_vengefulspirit_command_aura_illusion"]       = true,
    ["modifier_arc_warden_tempest_double"]                 = true,
    ["modifier_muerta_parting_shot_soul"]                  = true,
}

-- Модификаторы астрала, неуязвимости и изгнания
local BANISHED_OR_INVULNERABLE_MODIFIERS = {
    ["modifier_obsidian_destroyer_astral_imprisonment_prison"] = true,
    ["modifier_shadow_demon_disruption"]                     = true,
    ["modifier_eul_cyclone"]                                 = true,
    ["modifier_wind_waker"]                                  = true,
    ["modifier_puck_phase_shift"]                            = true,
    ["modifier_brewmaster_primal_split"]                     = true,
    ["modifier_slark_shadow_dance"]                          = true,
    ["modifier_item_aeon_disk_buff"]                         = true,
    ["modifier_winter_wyvern_winters_curse"]                 = true,
}

-- Список героев-саппортов для приоритета Cores (1/2/3 позиций)
local SUPPORT_HEROES = {
    ["npc_dota_hero_crystal_maiden"] = true,
    ["npc_dota_hero_disruptor"] = true,
    ["npc_dota_hero_keeper_of_the_light"] = true,
    ["npc_dota_hero_bane"] = true,
    ["npc_dota_hero_shadow_shaman"] = true,
    ["npc_dota_hero_lion"] = true,
    ["npc_dota_hero_witch_doctor"] = true,
    ["npc_dota_hero_dazzle"] = true,
    ["npc_dota_hero_jakiro"] = true,
    ["npc_dota_hero_lich"] = true,
    ["npc_dota_hero_ancient_apparition"] = true,
    ["npc_dota_hero_oracle"] = true,
    ["npc_dota_hero_rubick"] = true,
    ["npc_dota_hero_treant_protector"] = true,
    ["npc_dota_hero_winter_wyvern"] = true,
    ["npc_dota_hero_warlock"] = true,
    ["npc_dota_hero_undying"] = true,
    ["npc_dota_hero_shadow_demon"] = true,
    ["npc_dota_hero_chen"] = true,
    ["npc_dota_hero_enchantress"] = true,
    ["npc_dota_hero_grimstroke"] = true,
    ["npc_dota_hero_snapfire"] = true,
    ["npc_dota_hero_io"] = true,
    ["npc_dota_hero_omniknight"] = true,
    ["npc_dota_hero_pugna"] = true,
    ["npc_dota_hero_venomancer"] = true,
    ["npc_dota_hero_abaddon"] = true,
}

local ICONS = {
    Tab     = "\u{f013}",
    Shield  = "\u{1F6E1}",
    Heart   = "\u{f004}",
    Bolt    = "\u{f0e7}",
    Eye     = "\u{f06e}",
    Key     = "\u{f084}",
    Clock   = "\u{f017}",
    Sun     = "\u{2600}",
    Spell_R = "panorama/images/spellicons/dawnbreaker_solar_guardian_png.vtex_c",
}

--#endregion

--#region State & Variables

local State = {
    me = nil,
    player = nil,
    is_dawnbreaker = false,
    
    r_spell = nil,
    
    last_act_time = 0,
    last_ally_scan_time = 0,
    last_auto_save_time = 0,
    last_blacklist_sync = 0,
    
    endangered_ally = nil,
    targeted_ally = nil,
    highest_threat_score = 0,
    
    ally_tracking = {},
    
    is_script_order = false,
    hud_font = nil,
    bold_font = nil,

    is_channeling = false,
    channel_start_time = 0,
    landing_pos = nil,
    landing_thinker = nil,
    last_minimap_draw_time = 0,

    teamfight_cast_pos = nil,
    is_teamfight_target = false,
    last_aghs_reposition_time = 0,

    active_danger_aoes = {},
    is_edge_drop = false,
    edge_drop_type = nil,
    last_icon_ping = 0,
    blacklist_populated = false,
    last_minimap_flight_send = 0,
}

local UI = {}

-- Safe function executor
local function Safe(func, ...)
    if not func then return nil end
    local ok, res = pcall(func, ...)
    if ok then return res end
    return nil
end

local function Dist2D(p1, p2)
    if not p1 or not p2 then return 999999 end
    local dx = p1.x - p2.x
    local dy = p1.y - p2.y
    return math.sqrt(dx * dx + dy * dy)
end

local Distance2D = Dist2D

local function Alpha(col, a)
    if not col then return Color(255, 255, 255, math.floor(a or 255)) end
    return Color(col.r or 255, col.g or 255, col.b or 255, math.floor(math.max(0, math.min(255, a or 255))))
end

local function LerpColor(c1, c2, t)
    t = math.max(0, math.min(1, t))
    return Color(
        math.floor(c1.r + (c2.r - c1.r) * t),
        math.floor(c1.g + (c2.g - c1.g) * t),
        math.floor(c1.b + (c2.b - c1.b) * t),
        math.floor((c1.a or 255) + ((c2.a or 255) - (c1.a or 255)) * t)
    )
end

local function IsPointInFountain(pos)
    if not pos then return false end
    -- Radiant fountain ~ (-7200, -6800), Dire fountain ~ (7200, 6800)
    if pos.x < -6000 and pos.y < -5600 then return true end
    if pos.x > 6000 and pos.y > 5600 then return true end
    return false
end

--#endregion

--#region Menu Setup

--#region Localization Setup (using !_qLocalizer.lua)

local qLocalization = qLocalization
if not qLocalization then
    local ok, lib = pcall(require, "!_qLocalizer")
    if ok and lib then
        qLocalization = lib
    end
end

local TRANSLATIONS = {
        en = {
            menu = {
                -- 1. Core Save Settings
                grp_save = "1. Core Save Settings",
                save_enable = "Enable Auto-Save Ultimate",
                save_enable_tip = "Automatically casts Solar Guardian to save allies across the map.",
                save_panic_key = "Panic Save Hotkey",
                save_panic_key_tip = "Instantly casts ultimate on the most vulnerable teammate (ignores min mana/HP thresholds).",
                save_threshold = "Ally Save HP Threshold (%)",
                save_threshold_tip = "Ultimate triggers if ally HP drops below this value and enemies are nearby.",
                save_threat_only = "Save On Threat Only (Enemies Nearby)",
                save_threat_only_tip = "Does not waste ultimate if a low-HP ally is safe (farming jungle or retreating without enemies).",
                threat_radius = "Enemy Detection Radius Near Ally",
                threat_radius_tip = "Radius around ally to search for enemy heroes.",
                save_predict = "Ally Movement Lead Prediction",
                save_predict_tip = "Casts the circle slightly ahead along ally movement vector to keep them centered in heal.",
                save_min_mana = "Min Dawnbreaker Mana for Save (%)",
                save_min_mana_tip = "Do not use ultimate for save if Dawnbreaker has less than this % mana (prevents arriving with no mana).",
                save_min_self_hp = "Min Dawnbreaker HP for Save (%)",
                save_min_self_hp_tip = "Do not fly to save teammates if Dawnbreaker's own health is critically low (anti-feed protection).",

                -- 2. Teamfight & Combat Tactics
                grp_combat = "2. Teamfight & Combat Tactics",
                teamfight_ult = "Auto-Ult Enemy Cluster (Teamfight)",
                teamfight_ult_tip = "Automatically casts Solar Guardian into enemy clusters near allies for counter-initiation and AoE stun.",
                teamfight_min_enemies = "Min Enemies in 450 AoE to Engage",
                teamfight_min_enemies_tip = "Minimum number of enemy heroes clustered together to trigger teamfight ultimate.",
                early_land_enable = "Auto Early Land",
                early_land_enable_tip = "Automatically casts 'dawnbreaker_land' to land early if the ally is critical (<15% HP) or enemies are exiting 400 AoE.",
                early_land_hp = "Ally HP Threshold for Early Land",
                early_land_hp_tip = "If the target ally's HP drops below this threshold during cast, immediately lands the ult for stun and burst heal.",
                auto_bkb = "Auto BKB Before Ult Cast",
                auto_bkb_tip = "Automatically activates Black King Bar before casting Solar Guardian if enemy heroes are within 850 range of Dawnbreaker.",
                smart_aghs = "Smart Aghanim's Circle Repositioning",
                smart_aghs_tip = "With Aghanim's Scepter: if target ally is already safe (>80% HP and 0 enemies), smoothly redirects circle to other wounded allies or fight center.",

                -- 3. Anti-Cancel & Ruin Protection
                grp_safety = "3. Anti-Cancel & Ruin Protection",
                block_orders = "Block Orders During Ult Channel",
                block_orders_tip = "Blocks accidental mouse clicks and player orders during Solar Guardian channeling to prevent canceling the ult.",
                block_orders_hp = "Min Dawnbreaker HP to Block Orders (%)",
                block_orders_hp_tip = "Orders are blocked while Dawnbreaker's HP is above threshold. When attacked, order blocking is lifted (0% = always block).",
                anti_feed_cancel = "Cancel Ult on Target Death (Anti-Feed)",
                anti_feed_cancel_tip = "If ally dies during ult channeling (before landing), script cancels channeling, saving Dawnbreaker from feeding into enemies.",
                ttd_check = "Savability Check (TTD - Time to Death)",
                ttd_check_tip = "Does not waste ult if ally is guaranteed to die faster than Dawnbreaker can land (1.7s delay).",
                ttd_min_time = "Min Estimated Ally Lifespan (TTD)",
                ttd_min_time_tip = "Minimum time ally must survive before Dawnbreaker lands.",
                ignore_creep_stuns = "Ignore Creep Stuns (If No Enemies)",
                ignore_creep_stuns_tip = "Ignores stuns from neutral creeps, Roshan, and Tormentor if no enemy heroes are near ally.",
                ignore_illusions = "Ignore Teammate Illusions",
                ignore_illusions_tip = "Excludes teammate illusions (Manta, runes, spells). Saves only real heroes.",
                ignore_aegis = "Ignore Allies with Aegis",
                ignore_aegis_tip = "Does not waste ult on an ally carrying Aegis of the Immortal, as they will resurrect.",
                ignore_invulnerable = "Ignore Banished / Invulnerable Allies",
                ignore_invulnerable_tip = "Does not waste ult while ally is in Astral Imprisonment, Disruption, Eul's cyclone, or Phase Shift.",
                ignore_fountain = "Ignore Allies in Fountain",
                ignore_fountain_tip = "Does not waste ult on allies standing in their own fountain.",
                anti_chrono_edge = "Edge Drop on Chrono / Black Hole",
                anti_chrono_edge_tip = "When saving an ally in Chronosphere or Black Hole, offsets landing point to outer edge (320 units) so Dawnbreaker lands outside while maintaining 400 AoE stun and heal.",

                -- 4. Target Priorities & Blacklist
                grp_targets = "4. Target Priorities & Blacklist",
                prioritize_cores = "Prioritize Core Heroes (Pos 1/2/3)",
                prioritize_cores_tip = "Prioritizes saving Carry, Mid, and Offlane heroes over Position 4/5 supports.",
                save_on_cc = "Instant Save on Hard CC (Duel/BH/Chrono)",
                save_on_cc_tip = "Immediately casts ultimate if ally is caught in Duel, Black Hole, Chronosphere, Fiend's Grip, Dismember, etc.",
                save_on_cc_hp = "Max Ally HP % for CC Save",
                save_on_cc_hp_tip = "CC save triggers only if disabled ally's HP is less than or equal to this threshold.",
                ally_blacklist = "Ally Blacklist (Do Not Save)",
                ally_blacklist_tip = "Select allies on whom the script will never cast the ultimate under any condition.",

                -- 5. World & Minimap ESP
                grp_world = "5. World & Minimap ESP",
                world_landing = "World Landing Zone Circle (400 AoE)",
                world_landing_tip = "Displays 3D terrain-aligned landing circle with crosshair, time-to-impact indicator, and channel progress bar.",
                radar_arrow = "Offscreen Radar Arrow",
                radar_arrow_tip = "Displays a sleek chevron with arrow and distance at screen edge if landing position is off-camera.",
                minimap_landing = "Minimap Landing Position Indicator",
                minimap_landing_tip = "Renders landing circle radius (400 AoE) and crosshair center marker on the minimap.",
                minimap_line = "Minimap Flight Trajectory Line",
                minimap_line_tip = "Draws a flight trajectory line on the minimap from Dawnbreaker to landing point.",
                danger_rings = "Ally Minimap Danger Rings",
                danger_rings_tip = "Displays colored rings around allies on minimap: green - safe, yellow - skirmish/trading, pulsing red - critical danger (focused / stunned / low HP).",
                show_green_rings = "Show Green Rings (Safe Allies)",
                show_green_rings_tip = "If disabled, only allies in danger (yellow and red) are highlighted on the minimap to reduce visual clutter.",

                -- 6. Hero Indicators & HUD
                grp_hud = "6. Hero Indicators & HUD",
                draw_status = "Ult Readiness HUD / Overhead CD Timer",
                draw_status_tip = "Displays ultimate status: readiness, exact cooldown countdown (seconds), or low mana warning.",
                draw_safe_cast = "Cast Position Safety Indicator",
                draw_safe_cast_tip = "Shows Dawnbreaker's visibility status to enemies: green SAFE (in fog), yellow VISIBLE, red IN DANGER.",
                draw_luminosity = "Luminosity Passive Stacks Indicator",
                draw_luminosity_tip = "Sleek passive charge battery (0-3 hits) and pulsing golden banner when healing crit is ready.",
                draw_ally_threat = "Highlight Endangered Ally / Teamfight",
                draw_ally_threat_tip = "Draws a threat badge above endangered ally showing HP percentage or teamfight cluster tag.",
                draw_heal_proj = "Ult Heal Projection (+HP & % Forecast)",
                draw_heal_proj_tip = "Shows exact health restoration amount and projected HP percentage after landing above the ally.",
                overhead_offset = "Overhead HUD Vertical Offset",
                overhead_offset_tip = "Adjusts vertical position of overhead indicators and Luminosity battery above heroes (0 = perfect default above HP bar).",
            },
            hud = {
                crit_ready = "✦ CRIT & HEAL READY ✦",
                safe_fog = "✔ IN FOG (SAFE)",
                visible = "▲ VISIBLE TO ENEMY",
                danger_enemies = "⚠ DANGER: %d ENEMIES",
                landing_countdown = "⚡ LANDING %.1fs",
                disabled = "⛔ DISABLED",
                ult_ready = "☀️ READY",
                ult_cd = "⏳ %.1fs",
                mana_low = "💧 MANA: %d/%d",
                not_ready = "NOT READY",
                heal_projection = "✚ +%d HP HEAL (➔ %d%% HP)",
                saving_ally = "⚠ ENDANGERED ALLY (%d%% HP) ⚠",
                teamfight_target = "⚔ TEAMFIGHT CLUSTER (%d%% HP) ⚔",
                edge_drop = "🛡️ EDGE DROP: ",
                landing_zone_label = "[SOLAR LANDING ZONE]",
                landing_tag = "⚡ LANDING (%dm)",
                solar_tag = "☀️ SOLAR (%dm)",
                stunned = "★ STUNNED",
                channeled = "★ CHANNELED",
                distance_m = "%dm",
                ult_badge = "ULT",
                units_format = "%d units",
                enemies_format = "%d enemies",
                percent_hp = "%d%% HP",
                percent_mana = "%d%% Mana",
                seconds_format = "%.1f s",
                px_format = "%d px",
            }
        },
        ru = {
            menu = {
                -- 1. Основные настройки спасения
                grp_save = "1. Основные настройки спасения",
                save_enable = "Включить авто-спасение ультой",
                save_enable_tip = "Автоматически применяет Solar Guardian для спасения союзников по всей карте.",
                save_panic_key = "Горячая клавиша экстренного спасения",
                save_panic_key_tip = "Нажатие мгновенно кастует ульту на самого уязвимого тиммейта (игнорирует пороги мин. маны/HP).",
                save_threshold = "Порог здоровья союзника для сейва (%)",
                save_threshold_tip = "Ульта сработает, если HP союзника упало ниже этого значения и рядом есть враги.",
                save_threat_only = "Спасать только при угрозе (враги рядом)",
                save_threat_only_tip = "Не тратит ульту, если союзник с лоу-HP фармит лес или отходит без врагов поблизости.",
                threat_radius = "Радиус обнаружения врагов у союзника",
                threat_radius_tip = "Радиус поиска вражеских героев вокруг союзника.",
                save_predict = "Упреждение движения союзника",
                save_predict_tip = "Кастует круг слегка вперед по вектору бега союзника, чтобы он оставался в центре хила.",
                save_min_mana = "Мин. % маны Dawnbreaker для сейва",
                save_min_mana_tip = "Не использовать ультимейт, если у Dawnbreaker меньше указанного % маны (защита от приземления 'пустым').",
                save_min_self_hp = "Мин. % HP Dawnbreaker для сейва",
                save_min_self_hp_tip = "Не лететь на спасение, если у самой Dawnbreaker критически мало здоровья (защита от фида).",

                -- 2. Боевые тактики и тимфайты
                grp_combat = "2. Боевые тактики и тимфайты",
                teamfight_ult = "Авто-ульт в скопление врагов (тимфайт)",
                teamfight_ult_tip = "Автоматически применяет Solar Guardian при скоплении врагов рядом с союзниками для контринициации и массового стана.",
                teamfight_min_enemies = "Мин. врагов в радиусе 450 для тимфайта",
                teamfight_min_enemies_tip = "Минимальное количество врагов в куче для применения ульты в тимфайт.",
                early_land_enable = "Авто-раннее приземление (Early Land)",
                early_land_enable_tip = "Автоматически жмет 'dawnbreaker_land' при критическом HP союзника (<15%) или когда враги выходят из зоны 400 AoE.",
                early_land_hp = "Порог HP союзника для раннего удара",
                early_land_hp_tip = "Если здоровье союзника падает ниже порога во время каста, скрипт мгновенно сажает ульт для стана и взрывного хила.",
                auto_bkb = "Авто-BKB перед кастом ульты",
                auto_bkb_tip = "Автоматически прожимает Black King Bar перед кастом Solar Guardian, если в радиусе 850 от Dawnbreaker есть вражеские герои.",
                smart_aghs = "Умная репозиция круга с Аганимом",
                smart_aghs_tip = "При наличии Aghanim's Scepter: если союзник уже спасен (>80% HP и 0 врагов), плавно смещает круг к другим раненым тиммейтам или в эпицентр драки.",

                -- 3. Защита от руина и отмены
                grp_safety = "3. Защита от руина и отмены",
                block_orders = "Блокировка ордеров во время ульты",
                block_orders_tip = "Блокирует случайные клики мыши и приказы игрока во время ченнелинга Solar Guardian, чтобы не сбить ульту.",
                block_orders_hp = "Мин. % HP Dawnbreaker для блокировки",
                block_orders_hp_tip = "Приказы блокируются, пока HP Dawnbreaker выше порога. При нападении на вас блокировка снимается (0% = блокировать всегда).",
                anti_feed_cancel = "Отменять ульт при гибели союзника (Anti-Feed)",
                anti_feed_cancel_tip = "Если союзник погибает во время каста ульты (до приземления), скрипт прерывает ченнелинг, спасая Dawnbreaker от фида в толпу врагов.",
                ttd_check = "Проверка спасаемости (TTD - Time to Death)",
                ttd_check_tip = "Не тратит ульту, если союзник гарантированно погибнет быстрее, чем Dawnbreaker успеет приземлиться (задержка 1.7с).",
                ttd_min_time = "Мин. расчетное время жизни союзника (TTD)",
                ttd_min_time_tip = "Минимальное расчетное время выживания союзника до момента приземления.",
                ignore_creep_stuns = "Не лететь на станы крипов (если нет врагов)",
                ignore_creep_stuns_tip = "Игнорирует станы от нейтральных крипов, Рошана и Торментора, если рядом с союзником нет вражеских героев.",
                ignore_illusions = "Не лететь на иллюзии тиммейтов",
                ignore_illusions_tip = "Исключает иллюзии союзников (Manta, руны, скиллы). Спасает только реальных героев.",
                ignore_aegis = "Игнорировать союзников с Аегисом",
                ignore_aegis_tip = "Не тратит ульту на союзника с Аегисом, так как он мгновенно возродится.",
                ignore_invulnerable = "Игнорировать в астрале / неуязвимых",
                ignore_invulnerable_tip = "Не тратит ульту, пока союзник находится в Astral Imprisonment, Disruption, ветрах (Eul) или Phase Shift.",
                ignore_fountain = "Игнорировать союзников на фонтане",
                ignore_fountain_tip = "Не кастует ульту на союзников, находящихся на своем фонтане.",
                anti_chrono_edge = "Высадка на край Chrono / Black Hole",
                anti_chrono_edge_tip = "При сейве союзника в Chronosphere или Black Hole смещает точку посадки к внешнему краю (320 ед.), чтобы Dawnbreaker приземлилась снаружи купола, сохранив 400 AoE стан и хил союзника.",

                -- 4. Приоритеты целей и черный список
                grp_targets = "4. Приоритеты целей и черный список",
                prioritize_cores = "Приоритет Core-героям (1/2/3 позиции)",
                prioritize_cores_tip = "Приоритетно спасает Керри, Мидера и Оффлейнера перед саппортами 4/5 позиций.",
                save_on_cc = "Мгновенный сейв при дисейблах (Duel/BH/Chrono)",
                save_on_cc_tip = "Немедленно кастует ульту, если союзник попал в Duel, Black Hole, Chronosphere, Fiend's Grip, Dismember и т.д.",
                save_on_cc_hp = "Макс. % HP союзника для сейва в контроле",
                save_on_cc_hp_tip = "Ульта на контроль сработает только если у союзника в дисейбле меньше или равно этому значению здоровья.",
                ally_blacklist = "Черный список союзников (не спасать)",
                ally_blacklist_tip = "Выберите союзников, на которых скрипт ни при каких условиях не будет применять ультимейт.",

                -- 5. Мир и миникарта (World & Minimap ESP)
                grp_world = "5. Мир и миникарта (World & Minimap ESP)",
                world_landing = "Зона приземления ульты в мире (AoE 400)",
                world_landing_tip = "Отображает 3D-круг приземления по рельефу с прицелом, индикатором времени до удара и прогресс-баром каста.",
                radar_arrow = "Радар-стрелка на краю экрана (Offscreen)",
                radar_arrow_tip = "Показывает стильный шеврон со стрелкой и дистанцией на краю монитора, если точка приземления вне поля зрения камеры.",
                minimap_landing = "Отображение места приземления на миникарте",
                minimap_landing_tip = "Отображает на миникарте круг радиуса приземления (AoE 400) и прицельный маркер центра.",
                minimap_line = "Линия траектории полета на миникарте",
                minimap_line_tip = "Рисует локальную траекторию полета на миникарте от Dawnbreaker к месту приземления.",
                danger_rings = "Кольца опасности союзников на миникарте",
                danger_rings_tip = "Отображает цветные кольца вокруг союзников на миникарте: зеленый - в безопасности, желтый - размен, красный пульсирующий - критическая опасность (фокус врагов / стан / лоу HP).",
                show_green_rings = "Показывать зеленые кольца (в безопасности)",
                show_green_rings_tip = "Если выключено, на миникарте подсвечиваются только союзники в опасности (желтые и красные), чтобы не перегружать обзор.",

                -- 6. Индикаторы и HUD героя
                grp_hud = "6. Индикаторы и HUD героя",
                draw_status = "HUD готовности ульты / таймер КД над героем",
                draw_status_tip = "Отображает статус ультимейта: готовность, точный отсчет перезарядки (секунды) или предупреждение о нехватке маны.",
                draw_safe_cast = "Индикатор безопасности позиции каста",
                draw_safe_cast_tip = "Показывает статус видимости Dawnbreaker врагами: зеленый SAFE (в тумане), желтый VISIBLE, красный IN DANGER.",
                draw_luminosity = "Индикатор стаков пассивки Luminosity",
                draw_luminosity_tip = "Стильная батарея заряда пассивки (0-3 удара) и золотой пульсирующий баннер готовности исцеляющего крита.",
                draw_ally_threat = "Подсветка уязвимого союзника / тимфайта",
                draw_ally_threat_tip = "Выводит бейдж опасности над спасаемым союзником с указанием процента здоровья или метки тимфайта.",
                draw_heal_proj = "Проекция исцеления ульты (+HP и % прогноза)",
                draw_heal_proj_tip = "Показывает над союзником точный объем восстановления здоровья и прогнозируемый процент HP после приземления.",
                overhead_offset = "Смещение HUD по высоте",
                overhead_offset_tip = "Настраивает высоту индикаторов и батареи пассивки над полоской здоровья героя (0 = идеально над HP).",
            },
            hud = {
                crit_ready = "✦ КРИТ И ХИЛ ГОТОВЫ ✦",
                safe_fog = "✔ В ТЕМНОТЕ (FOG)",
                visible = "▲ ВИДЕН ВРАГУ",
                danger_enemies = "⚠ ОПАСНО: %d ВРАГОВ",
                landing_countdown = "⚡ ПРИЗЕМЛЕНИЕ %.1fs",
                disabled = "⛔ ОТКЛЮЧЕНО",
                ult_ready = "☀️ ГОТОВО",
                ult_cd = "⏳ %.1fs",
                mana_low = "💧 МАНА: %d/%d",
                not_ready = "НЕ ГОТОВО",
                heal_projection = "✚ ХИЛ: +%d HP (➔ %d%% HP)",
                saving_ally = "⚠ СОЮЗНИК В ОПАСНОСТИ (%d%% HP) ⚠",
                teamfight_target = "⚔ ТИМФАЙТ СКОПЛЕНИЕ (%d%% HP) ⚔",
                edge_drop = "🛡️ ВЫСАДКА НА КРАЙ: ",
                landing_zone_label = "[ЗОНА ПРИЗЕМЛЕНИЯ]",
                landing_tag = "⚡ ПРИЗЕМЛЕНИЕ (%dm)",
                solar_tag = "☀️ SOLAR (%dm)",
                stunned = "★ ЗАСТАНЕН",
                channeled = "★ ЧЕННЕЛИНГ",
                distance_m = "%dм",
                ult_badge = "УЛЬТ",
                units_format = "%d ед.",
                enemies_format = "%d врагов",
                percent_hp = "%d%% HP",
                percent_mana = "%d%% маны",
                seconds_format = "%.1f с",
                px_format = "%d px",
            }
        }
    }

local localization
if qLocalization and qLocalization.new then
    localization = qLocalization.new(TRANSLATIONS)
else
    -- Встроенный автономный движок локализации (100% Standalone, без сторонних файлов)
    local langWidget = Menu.Find("SettingsHidden", "", "", "", "Main", "Language")
    local objects = {}
    local function GetLang()
        if langWidget and langWidget:Get() == 0 then return "en" end
        return "ru"
    end
    local function Resolve(path, lang)
        lang = lang or GetLang()
        local root = TRANSLATIONS and TRANSLATIONS[lang] or (TRANSLATIONS and TRANSLATIONS.en)
        if not root then return path end
        for k in path:gmatch("[^.]+") do
            if type(root) ~= "table" then return path end
            root = root[k]
        end
        return root or path
    end
    local function UpdateAll(lang_idx)
        local lang = (lang_idx == 0) and "en" or "ru"
        for obj, rec in pairs(objects) do
            if rec.label and obj.ForceLocalization then
                obj:ForceLocalization(Resolve(rec.label, lang))
            end
            if rec.tip and obj.ToolTip then
                obj:ToolTip(Resolve(rec.tip, lang))
            end
        end
    end
    if langWidget then
        langWidget:SetCallback(function(this)
            UpdateAll(this:Get())
        end, true)
    end
    local function WrapObj(target)
        if not target then return target end
        local proxy
        proxy = setmetatable({}, {
            __index = function(_, key)
                local member = target[key]
                if type(member) ~= "function" then return member end
                return function(...)
                    local args = table.pack(...)
                    if args[1] == proxy then table.remove(args, 1); args.n = args.n - 1 end
                    if key == "ToolTip" then
                        local tip_path = args[1]
                        if type(tip_path) == "string" and tip_path:find("^menu%.") then
                            if not objects[target] then objects[target] = {} end
                            objects[target].tip = tip_path
                            args[1] = Resolve(tip_path)
                        end
                        return member(target, table.unpack(args, 1, args.n))
                    else
                        local name_path = args[1]
                        local res = member(target, table.unpack(args, 1, args.n))
                        if res and (type(res) == "userdata" or type(res) == "table") then
                            if type(name_path) == "string" and name_path:find("^menu%.") then
                                if not objects[res] then objects[res] = {} end
                                objects[res].label = name_path
                                if res.ForceLocalization then
                                    res:ForceLocalization(Resolve(name_path))
                                end
                            end
                            return WrapObj(res)
                        end
                        return res
                    end
                end
            end
        })
        return proxy
    end
    localization = {
        GetLanguage = GetLang,
        Localize = Resolve,
        Get = Resolve,
        Wrap = WrapObj,
        WrapLibrary = function(lib)
            local proxy
            proxy = setmetatable({}, {
                __index = function(_, key)
                    local fn = lib[key]
                    if type(fn) ~= "function" then return fn end
                    return function(...)
                        local res = fn(...)
                        return WrapObj(res)
                    end
                end
            })
            return proxy
        end,
    }
end

local Menu = (localization.WrapLibrary and localization.WrapLibrary(Menu)) or Menu

local function Loc(path, ...)
    local text = localization.Localize(path) or path
    if select("#", ...) > 0 then
        return string.format(text, ...)
    end
    return text
end

--#endregion

local function InitMenu()
    if UI.ready then return end

    local tab = Menu.Create("Heroes", "Hero List", "Dawnbreaker", "Main Settings")
    if not tab then return end
    tab:Icon(ICONS.Sun)

    -- =========================================================================
    -- КОЛОНКА 1: ЛОГИКА И АВТОМАТИЗАЦИЯ
    -- =========================================================================

    -- 1. Основные настройки авто-спасения
    local grpMain = tab:Create("menu.grp_save", 1)

    UI.SaveEnable = grpMain:Switch("menu.save_enable", true, ICONS.Shield)
    UI.SaveEnable:ToolTip("menu.save_enable_tip")

    UI.SavePanicKey = grpMain:Bind("menu.save_panic_key", Enum.ButtonCode.KEY_NONE, ICONS.Key)
    UI.SavePanicKey:ToolTip("menu.save_panic_key_tip")

    UI.SaveThreshold = grpMain:Slider("menu.save_threshold", 10, 80, 35, function(val)
        return string.format(Loc("hud.percent_hp"), val)
    end)
    UI.SaveThreshold:Icon(ICONS.Heart)
    UI.SaveThreshold:ToolTip("menu.save_threshold_tip")

    UI.SaveOnThreatOnly = grpMain:Switch("menu.save_threat_only", true, ICONS.Eye)
    UI.SaveOnThreatOnly:ToolTip("menu.save_threat_only_tip")

    UI.ThreatRadius = grpMain:Slider("menu.threat_radius", 600, 1400, 950, function(val)
        return string.format(Loc("hud.units_format"), val)
    end)
    UI.ThreatRadius:Icon(ICONS.Clock)
    UI.ThreatRadius:ToolTip("menu.threat_radius_tip")

    UI.SavePredict = grpMain:Switch("menu.save_predict", true, ICONS.Clock)
    UI.SavePredict:ToolTip("menu.save_predict_tip")

    UI.SaveMinMana = grpMain:Slider("menu.save_min_mana", 0, 80, 20, function(val)
        return string.format(Loc("hud.percent_mana"), val)
    end)
    UI.SaveMinMana:Icon(ICONS.Bolt)
    UI.SaveMinMana:ToolTip("menu.save_min_mana_tip")

    UI.SaveMinSelfHP = grpMain:Slider("menu.save_min_self_hp", 0, 80, 25, function(val)
        return string.format(Loc("hud.percent_hp"), val)
    end)
    UI.SaveMinSelfHP:Icon(ICONS.Heart)
    UI.SaveMinSelfHP:ToolTip("menu.save_min_self_hp_tip")

    -- 2. Боевые тактики и тимфайты
    local grpCombat = tab:Create("menu.grp_combat", 1)

    UI.TeamfightUlt = grpCombat:Switch("menu.teamfight_ult", true, ICONS.Sun)
    UI.TeamfightUlt:ToolTip("menu.teamfight_ult_tip")

    UI.TeamfightMinEnemies = grpCombat:Slider("menu.teamfight_min_enemies", 2, 5, 3, function(val)
        return string.format(Loc("hud.enemies_format"), val)
    end)
    UI.TeamfightMinEnemies:Icon(ICONS.Clock)
    UI.TeamfightMinEnemies:ToolTip("menu.teamfight_min_enemies_tip")

    UI.EarlyLandEnable = grpCombat:Switch("menu.early_land_enable", true, ICONS.Bolt)
    UI.EarlyLandEnable:ToolTip("menu.early_land_enable_tip")

    UI.EarlyLandHP = grpCombat:Slider("menu.early_land_hp", 5, 30, 15, function(val)
        return string.format(Loc("hud.percent_hp"), val)
    end)
    UI.EarlyLandHP:Icon(ICONS.Heart)
    UI.EarlyLandHP:ToolTip("menu.early_land_hp_tip")

    UI.AutoBKBOnUlt = grpCombat:Switch("menu.auto_bkb", true, ICONS.Shield)
    UI.AutoBKBOnUlt:ToolTip("menu.auto_bkb_tip")

    UI.SmartAghsReposition = grpCombat:Switch("menu.smart_aghs", true, ICONS.Sun)
    UI.SmartAghsReposition:ToolTip("menu.smart_aghs_tip")

    -- 3. Защита от руина и отмены
    local grpSafety = tab:Create("menu.grp_safety", 1)

    UI.BlockOrders = grpSafety:Switch("menu.block_orders", true, ICONS.Shield)
    UI.BlockOrders:ToolTip("menu.block_orders_tip")

    UI.BlockOrdersMinHP = grpSafety:Slider("menu.block_orders_hp", 0, 80, 25, function(val)
        return string.format(Loc("hud.percent_hp"), val)
    end)
    UI.BlockOrdersMinHP:Icon(ICONS.Heart)
    UI.BlockOrdersMinHP:ToolTip("menu.block_orders_hp_tip")

    UI.AntiFeedCancel = grpSafety:Switch("menu.anti_feed_cancel", true, ICONS.Shield)
    UI.AntiFeedCancel:ToolTip("menu.anti_feed_cancel_tip")

    UI.TTDCheck = grpSafety:Switch("menu.ttd_check", true, ICONS.Clock)
    UI.TTDCheck:ToolTip("menu.ttd_check_tip")

    UI.TTDMinTime = grpSafety:Slider("menu.ttd_min_time", 3, 15, 6, function(val)
        return string.format(Loc("hud.seconds_format"), val / 10)
    end)
    UI.TTDMinTime:Icon(ICONS.Clock)
    UI.TTDMinTime:ToolTip("menu.ttd_min_time_tip")

    UI.IgnoreCreepStuns = grpSafety:Switch("menu.ignore_creep_stuns", true, ICONS.Eye)
    UI.IgnoreCreepStuns:ToolTip("menu.ignore_creep_stuns_tip")

    UI.IgnoreIllusions = grpSafety:Switch("menu.ignore_illusions", true, ICONS.Shield)
    UI.IgnoreIllusions:ToolTip("menu.ignore_illusions_tip")

    UI.IgnoreAegis = grpSafety:Switch("menu.ignore_aegis", true, ICONS.Shield)
    UI.IgnoreAegis:ToolTip("menu.ignore_aegis_tip")

    UI.IgnoreInvulnerable = grpSafety:Switch("menu.ignore_invulnerable", true, ICONS.Shield)
    UI.IgnoreInvulnerable:ToolTip("menu.ignore_invulnerable_tip")

    UI.IgnoreFountain = grpSafety:Switch("menu.ignore_fountain", true, ICONS.Shield)
    UI.IgnoreFountain:ToolTip("menu.ignore_fountain_tip")

    UI.AntiChronoEdgeDrop = grpSafety:Switch("menu.anti_chrono_edge", true, ICONS.Shield)
    UI.AntiChronoEdgeDrop:ToolTip("menu.anti_chrono_edge_tip")

    -- =========================================================================
    -- КОЛОНКА 2: ЦЕЛИ, ВИЗУАЛИЗАЦИЯ И HUD
    -- =========================================================================

    -- 4. Приоритеты целей и черный список
    local grpTargets = tab:Create("menu.grp_targets", 2)

    UI.PrioritizeCores = grpTargets:Switch("menu.prioritize_cores", true, ICONS.Heart)
    UI.PrioritizeCores:ToolTip("menu.prioritize_cores_tip")

    UI.SaveOnCC = grpTargets:Switch("menu.save_on_cc", true, ICONS.Bolt)
    UI.SaveOnCC:ToolTip("menu.save_on_cc_tip")

    UI.SaveOnCCHP = grpTargets:Slider("menu.save_on_cc_hp", 10, 100, 75, function(val)
        return string.format(Loc("hud.percent_hp"), val)
    end)
    UI.SaveOnCCHP:Icon(ICONS.Heart)
    UI.SaveOnCCHP:ToolTip("menu.save_on_cc_hp_tip")

    UI.AllyBlacklist = grpTargets:MultiSelect("menu.ally_blacklist", {}, true)
    UI.AllyBlacklist:ToolTip("menu.ally_blacklist_tip")

    -- 5. Отображение в мире и на миникарте
    local grpWorld = tab:Create("menu.grp_world", 2)

    UI.DrawWorldLandingCircle = grpWorld:Switch("menu.world_landing", true, ICONS.Sun)
    UI.DrawWorldLandingCircle:ToolTip("menu.world_landing_tip")

    UI.DrawOffscreenRadar = grpWorld:Switch("menu.radar_arrow", true, ICONS.Clock)
    UI.DrawOffscreenRadar:ToolTip("menu.radar_arrow_tip")

    UI.DrawMinimapLanding = grpWorld:Switch("menu.minimap_landing", true, ICONS.Sun)
    UI.DrawMinimapLanding:ToolTip("menu.minimap_landing_tip")

    UI.DrawMinimapLine = grpWorld:Switch("menu.minimap_line", true, ICONS.Sun)
    UI.DrawMinimapLine:ToolTip("menu.minimap_line_tip")

    UI.MinimapDangerRings = grpWorld:Switch("menu.danger_rings", true, ICONS.Eye)
    UI.MinimapDangerRings:ToolTip("menu.danger_rings_tip")

    UI.MinimapShowGreen = grpWorld:Switch("menu.show_green_rings", false, ICONS.Shield)
    UI.MinimapShowGreen:ToolTip("menu.show_green_rings_tip")

    -- 6. Информационный HUD и оверлеи
    local grpHUD = tab:Create("menu.grp_hud", 2)

    UI.DrawStatus = grpHUD:Switch("menu.draw_status", true, ICONS.Eye)
    UI.DrawStatus:ToolTip("menu.draw_status_tip")

    UI.DrawSafeCastZone = grpHUD:Switch("menu.draw_safe_cast", true, ICONS.Shield)
    UI.DrawSafeCastZone:ToolTip("menu.draw_safe_cast_tip")

    UI.DrawLuminosity = grpHUD:Switch("menu.draw_luminosity", true, ICONS.Sun)
    UI.DrawLuminosity:ToolTip("menu.draw_luminosity_tip")

    UI.DrawAllyThreat = grpHUD:Switch("menu.draw_ally_threat", true, ICONS.Heart)
    UI.DrawAllyThreat:ToolTip("menu.draw_ally_threat_tip")

    UI.DrawHealProjection = grpHUD:Switch("menu.draw_heal_proj", true, ICONS.Heart)
    UI.DrawHealProjection:ToolTip("menu.draw_heal_proj_tip")

    UI.OverheadOffset = grpHUD:Slider("menu.overhead_offset", -30, 80, 0, function(val)
        return string.format(Loc("hud.px_format"), val)
    end)
    UI.OverheadOffset:Icon(ICONS.Eye)
    UI.OverheadOffset:ToolTip("menu.overhead_offset_tip")

    UI.ready = true
    Log.Write("[DB_INIT_SUCCESS] Dawnbreaker menu registered with dynamic localization!")
end

-- Initialize Menu immediately upon script load
InitMenu()

--#endregion

--#region Helper & Cache Functions

local function UpdateHeroCache()
    State.me = Heroes.GetLocal()
    if not State.me then
        State.is_dawnbreaker = false
        return false
    end

    local unit_name = Safe(NPC.GetUnitName, State.me)
    if unit_name ~= HERO_NAME then
        State.is_dawnbreaker = false
        return false
    end

    State.is_dawnbreaker = true
    State.player = Players.GetLocal()
    State.r_spell = NPC.GetAbility(State.me, ULT_NAME)

    return true
end

local function CanCastSpell(spell)
    if not spell or not State.me then return false end
    local mana = Safe(NPC.GetMana, State.me) or 0
    return Safe(Ability.IsCastable, spell, mana) == true
end

local function IsSilencedOrStunned(hero)
    if not hero then return true end
    if Safe(NPC.IsStunned, hero) then return true end
    if Safe(NPC.IsSilenced, hero) then return true end
    if Safe(NPC.HasState, hero, Enum.ModifierState.MODIFIER_STATE_HEXED) then return true end
    if Safe(NPC.HasState, hero, Enum.ModifierState.MODIFIER_STATE_MUTED) then return true end
    return false
end

-- Расчет безопасной точки высадки на внешний край Chronosphere / Black Hole
local function GetChronoOrBlackHoleEdgePos(ally, origin)
    if not UI.AntiChronoEdgeDrop or not UI.AntiChronoEdgeDrop:Get() then
        return nil, nil
    end

    local is_chrono = Safe(NPC.HasModifier, ally, "modifier_faceless_void_chronosphere_freeze")
    local is_bh = Safe(NPC.HasModifier, ally, "modifier_enigma_black_hole_pull")

    if not is_chrono and not is_bh then
        return nil, nil
    end

    local danger_type = is_chrono and "chrono" or "black_hole"
    local danger_center = nil

    -- 1. Проверяем зарегистрированные thinker-сущности куполов / блэкхолов
    local now = GameRules.GetGameTime()
    if State.active_danger_aoes then
        for idx, info in pairs(State.active_danger_aoes) do
            if info and info.expire and now <= info.expire and info.pos then
                if Dist2D(origin, info.pos) <= (info.radius + 250) then
                    danger_center = info.pos
                    danger_type = info.type
                    break
                end
            else
                State.active_danger_aoes[idx] = nil
            end
        end
    end

    -- 2. Если thinker не найден в таблице, ищем кастера (Void / Enigma)
    if not danger_center then
        local all_heroes = Heroes.GetAll() or {}
        if is_chrono then
            for _, h in ipairs(all_heroes) do
                if h and Safe(Entity.IsAlive, h) and not Safe(Entity.IsSameTeam, State.me, h) then
                    if Safe(NPC.GetUnitName, h) == "npc_dota_hero_faceless_void" then
                        local v_pos = Safe(Entity.GetAbsOrigin, h)
                        if v_pos and Dist2D(origin, v_pos) <= 800 then
                            danger_center = v_pos
                            break
                        end
                    end
                end
            end
        elseif is_bh then
            for _, h in ipairs(all_heroes) do
                if h and Safe(Entity.IsAlive, h) and not Safe(Entity.IsSameTeam, State.me, h) then
                    if Safe(NPC.GetUnitName, h) == "npc_dota_hero_enigma" then
                        local e_pos = Safe(Entity.GetAbsOrigin, h)
                        if e_pos and Dist2D(origin, e_pos) <= 1200 then
                            danger_center = e_pos
                            break
                        end
                    end
                end
            end
        end
    end

    if not danger_center then
        danger_center = origin
    end

    -- Направление от эпицентра опасности наружу через союзника
    local dx = origin.x - danger_center.x
    local dy = origin.y - danger_center.y
    local dist = math.sqrt(dx * dx + dy * dy)
    local u_x, u_y

    if dist > 25 then
        u_x = dx / dist
        u_y = dy / dist
    else
        -- Союзник ровно в центре: уходим в безопасную сторону (к Dawnbreaker или базе)
        local my_pos = State.me and Safe(Entity.GetAbsOrigin, State.me)
        if my_pos then
            local mx = my_pos.x - origin.x
            local my = my_pos.y - origin.y
            local md = math.sqrt(mx * mx + my * my)
            if md > 0 then
                u_x = mx / md
                u_y = my / md
            else
                u_x, u_y = 1, 0
            end
        else
            u_x, u_y = 1, 0
        end
    end

    -- Смещение 320 ед. (лимит каста Solar Guardian в Dota 2 - 350 ед., радиус стана/хила - 400 ед.)
    -- Союзник гарантированно попадает под 400 AoE исцеления и стана,
    -- а сама Dawnbreaker приземляется снаружи Chronosphere / Black Hole!
    local edge_pos = Vector(origin.x + u_x * 320, origin.y + u_y * 320, origin.z)
    return edge_pos, danger_type
end

-- Prediction for Solar Guardian lead position
local function GetSolarGuardianCastPos(ally, is_teamfight, cluster_centroid)
    local origin = Safe(Entity.GetAbsOrigin, ally)
    if not origin then return nil end

    -- 1. Приоритет: Anti-Chronosphere / Anti-Black Hole Edge Drop
    local edge_pos, danger_type = GetChronoOrBlackHoleEdgePos(ally, origin)
    if edge_pos then
        State.is_edge_drop = true
        State.edge_drop_type = danger_type
        return edge_pos
    else
        State.is_edge_drop = false
        State.edge_drop_type = nil
        State.channel_start_time = 0
    end

    if is_teamfight and cluster_centroid then
        -- Направляем круг в сторону центра скопления врагов, но не далее 300 ед. от союзника (лимит Dota 2 - 350 ед.)
        local dx = cluster_centroid.x - origin.x
        local dy = cluster_centroid.y - origin.y
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist <= 300 then
            return Vector(cluster_centroid.x, cluster_centroid.y, origin.z)
        elseif dist > 0 then
            local factor = 300 / dist
            return Vector(origin.x + dx * factor, origin.y + dy * factor, origin.z)
        end
        return origin
    end

    if not UI.SavePredict or not UI.SavePredict:Get() or not Safe(NPC.IsRunning, ally) then
        return origin
    end    local rot = Safe(Entity.GetAbsRotation, ally) or Safe(Entity.GetRotation, ally)
    if not rot then return origin end
    local fwd = Safe(rot.GetForward, rot)
    if not fwd then return origin end
    local fwd_len = math.sqrt(fwd.x * fwd.x + fwd.y * fwd.y)
    if fwd_len <= 0 then return origin end
    local fx = fwd.x / fwd_len
    local fy = fwd.y / fwd_len
    local ms = Safe(NPC.GetMoveSpeed, ally) or 320

    -- Ограничиваем дистанцию упреждения 250 единицами, чтобы не вылететь за 350 привязки к союзнику
    local lead_dist = math.min(250, ms * 0.40)
    return Vector(origin.x + fx * lead_dist, origin.y + fy * lead_dist, origin.z)
end

--#endregion

--#region Auto-Save Solar Guardian Engine

local function IsRealAllyHero(ally)
    if not ally or ally == State.me then return false end
    if not Safe(Entity.IsAlive, ally) then return false end
    if Safe(Entity.IsDormant, ally) then return false end
    if not Safe(Entity.IsSameTeam, State.me, ally) then return false end

    if Entity.IsHero and not Safe(Entity.IsHero, ally) then return false end

    -- Если включена защита от иллюзий союзников
    if UI.IgnoreIllusions and UI.IgnoreIllusions:Get() then
        -- 1. Umbrella API IsIllusion check
        if Safe(NPC.IsIllusion, ally) == true then return false end

        -- 2. Проверка известных модификаторов иллюзий и клонов
        for mod_name, _ in pairs(ILLUSION_MODIFIERS) do
            if Safe(NPC.HasModifier, ally, mod_name) then
                return false
            end
        end

        -- 3. Проверка на репликацию модели другого героя
        if NPC.GetReplicatingOtherHeroModel and Safe(NPC.GetReplicatingOtherHeroModel, ally) then
            return false
        end

        -- 4. Сверка с назначенными героями игроков (Player.GetAssignedHero)
        if Players and Players.GetAll and Player and Player.GetAssignedHero then
            local players = Safe(Players.GetAll)
            if players and #players > 0 then
                local is_assigned = false
                for _, p in ipairs(players) do
                    if p and Safe(Entity.IsPlayer, p) and Safe(Entity.IsSameTeam, State.me, p) then
                        local assigned = Safe(Player.GetAssignedHero, p)
                        if assigned and assigned == ally then
                            is_assigned = true
                            break
                        end
                    end
                end
                -- Исключение для клонов Meepo (смерть клона = смерть Meepo)
                if not is_assigned then
                    local unit_name = Safe(NPC.GetUnitName, ally)
                    if unit_name == "npc_dota_hero_meepo" and NPC.IsMeepoClone and Safe(NPC.IsMeepoClone, ally) then
                        is_assigned = true
                    end
                end
                if not is_assigned then
                    return false
                end
            end
        end
    end

    return true
end

local function HasFatalDebuff(ally, enemies_near)
    if not ally then return false, nil end

    -- Фатальные способности вражеских героев (Duel, Black Hole, Chronosphere, etc.)
    for debuff_name, _ in pairs(FATAL_DEBUFFS) do
        if Safe(NPC.HasModifier, ally, debuff_name) then
            return true, debuff_name
        end
    end

    -- Общее состояние стана
    if Safe(NPC.IsStunned, ally) then
        if UI.IgnoreCreepStuns and UI.IgnoreCreepStuns:Get() then
            -- Если рядом вообще нет вражеских героев (enemies_near == 0), стан гарантированно от крипов/нейтралов
            if enemies_near == 0 then
                return false, nil
            end
            -- Проверка на специфические станы от нейтральных крипов, Рошана и Торментора
            for mod_name, _ in pairs(CREEP_STUN_MODIFIERS) do
                if Safe(NPC.HasModifier, ally, mod_name) then
                    return false, nil
                end
            end
        end
        return true, "stunned"
    end

    return false, nil
end

local function CountEnemiesNearUnit(unit, radius)
    if not unit then return 0 end
    local u_pos = Safe(Entity.GetAbsOrigin, unit)
    if not u_pos then return 0 end

    local count = 0
    local all_heroes = Heroes.GetAll()
    if not all_heroes then return 0 end

    for _, enemy in ipairs(all_heroes) do
        if enemy and enemy ~= unit and Safe(Entity.IsAlive, enemy) then
            if not Safe(Entity.IsSameTeam, unit, enemy) and not Safe(Entity.IsDormant, enemy) then
                local is_illusion = (Safe(NPC.IsIllusion, enemy) == true)
                if not is_illusion then
                    for mod_name, _ in pairs(ILLUSION_MODIFIERS) do
                        if Safe(NPC.HasModifier, enemy, mod_name) then
                            is_illusion = true
                            break
                        end
                    end
                end

                if not is_illusion then
                    local e_pos = Safe(Entity.GetAbsOrigin, enemy)
                    if e_pos and Dist2D(u_pos, e_pos) <= radius then
                        count = count + 1
                    end
                end
            end
        end
    end
    return count
end

local function CountEnemiesNearPos(pos, radius)
    if not pos or not State.me then return 0 end
    local count = 0
    local all_heroes = Heroes.GetAll()
    if not all_heroes then return 0 end

    for _, enemy in ipairs(all_heroes) do
        if enemy and enemy ~= State.me and Safe(Entity.IsAlive, enemy) then
            if not Safe(Entity.IsSameTeam, State.me, enemy) and not Safe(Entity.IsDormant, enemy) then
                local is_illusion = (Safe(NPC.IsIllusion, enemy) == true)
                if not is_illusion then
                    for mod_name, _ in pairs(ILLUSION_MODIFIERS) do
                        if Safe(NPC.HasModifier, enemy, mod_name) then
                            is_illusion = true
                            break
                        end
                    end
                end

                if not is_illusion then
                    local e_pos = Safe(Entity.GetAbsOrigin, enemy)
                    if e_pos and Dist2D(pos, e_pos) <= radius then
                        count = count + 1
                    end
                end
            end
        end
    end
    return count
end

local function GetEnemiesCentroidNearPos(pos, radius)
    if not pos or not State.me then return pos, 0 end
    local cx, cy, cz = 0, 0, 0
    local count = 0
    local all_heroes = Heroes.GetAll()
    if not all_heroes then return pos, 0 end

    for _, enemy in ipairs(all_heroes) do
        if enemy and enemy ~= State.me and Safe(Entity.IsAlive, enemy) then
            if not Safe(Entity.IsSameTeam, State.me, enemy) and not Safe(Entity.IsDormant, enemy) then
                local is_illusion = (Safe(NPC.IsIllusion, enemy) == true)
                if not is_illusion then
                    for mod_name, _ in pairs(ILLUSION_MODIFIERS) do
                        if Safe(NPC.HasModifier, enemy, mod_name) then
                            is_illusion = true
                            break
                        end
                    end
                end

                if not is_illusion then
                    local e_pos = Safe(Entity.GetAbsOrigin, enemy)
                    if e_pos and Dist2D(pos, e_pos) <= radius then
                        cx = cx + e_pos.x
                        cy = cy + e_pos.y
                        cz = cz + e_pos.z
                        count = count + 1
                    end
                end
            end
        end
    end

    if count > 0 then
        return Vector(cx / count, cy / count, cz / count), count
    end
    return pos, 0
end

local function GetLuminosityModifier(hero)
    if not hero then return nil end
    local mod = Safe(NPC.GetModifier, hero, "modifier_dawnbreaker_luminosity")
    if mod then return mod end
    local mods = Safe(NPC.GetModifiers, hero)
    if mods then
        for _, m in ipairs(mods) do
            local name = Safe(Modifier.GetName, m)
            if name and string.find(name, "luminosity") then
                return m
            end
        end
    end
    return nil
end

local function IsBanishedOrInvulnerable(ally)
    if not ally then return false end
    for mod_name, _ in pairs(BANISHED_OR_INVULNERABLE_MODIFIERS) do
        if Safe(NPC.HasModifier, ally, mod_name) then
            return true
        end
    end
    if Safe(NPC.HasState, ally, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE) then
        return true
    end
    return false
end

local function IsImmortalOrProtected(ally)
    if not ally then return false end
    if Safe(NPC.HasModifier, ally, "modifier_dazzle_shallow_grave") then return true end
    if Safe(NPC.HasModifier, ally, "modifier_oracle_false_promise") then return true end
    if Safe(NPC.HasModifier, ally, "modifier_abaddon_borrowed_time") then return true end
    if Safe(NPC.HasModifier, ally, "modifier_troll_warlord_battle_trance") then return true end
    return false
end

local function IsCoreHero(ally)
    if not ally then return false end
    local name = Safe(NPC.GetUnitName, ally)
    if not name then return false end
    return not SUPPORT_HEROES[name]
end

local function CalculateAllyTTD(ally, hp, enemies_near, now)
    if IsImmortalOrProtected(ally) then
        return 999.0
    end

    local idx = Safe(Entity.GetIndex, ally)
    if not idx then return 999.0 end

    local track = State.ally_tracking[idx]
    if not track then
        track = { last_hp = hp, last_time = now, dps = 0 }
        State.ally_tracking[idx] = track
    else
        local dt = now - track.last_time
        if dt >= 0.08 then
            local dhp = track.last_hp - hp
            if dhp > 0 then
                local cur_dps = dhp / dt
                track.dps = (track.dps or 0) * 0.35 + cur_dps * 0.65
            else
                track.dps = (track.dps or 0) * 0.75
            end
            track.last_hp = hp
            track.last_time = now
        end
    end

    local estimated_dps = math.max(track.dps or 0, enemies_near * 130)
    if estimated_dps <= 10 then
        return 999.0
    end

    return hp / estimated_dps
end

local function UpdateAllyBlacklistMenu()
    if not UI.AllyBlacklist or not UI.AllyBlacklist.Update then return end
    if not State.me or not State.is_dawnbreaker then return end
    if State.blacklist_populated then return end

    local allies = {}
    local all_players = Players and Players.GetAll and Players.GetAll() or {}
    for _, p in ipairs(all_players) do
        if p and Safe(Entity.IsPlayer, p) and Safe(Entity.IsSameTeam, State.me, p) then
            local hero = Player.GetAssignedHero and Safe(Player.GetAssignedHero, p)
            if hero and hero ~= State.me then
                local unit_name = Safe(NPC.GetUnitName, hero)
                if unit_name and unit_name ~= "" then
                    local icon = "panorama/images/heroes/" .. unit_name .. "_png.vtex_c"
                    local was_selected = UI.AllyBlacklist:Get(unit_name) == true
                    allies[#allies + 1] = {
                        unit_name,
                        icon,
                        was_selected
                    }
                end
            end
        end
    end
    if #allies > 0 then
        Safe(UI.AllyBlacklist.Update, UI.AllyBlacklist, allies, true, false)
        if #allies >= 4 then
            State.blacklist_populated = true
        end
    end
end

local function ScanAlliesForSave(now)
    local best_ally = nil
    local max_score = 0
    local best_tf_pos = nil

    local all_heroes = Heroes.GetAll()
    if not all_heroes then return nil, 0 end

    local threat_rad = UI.ThreatRadius and UI.ThreatRadius:Get() or 950
    local hp_threshold = UI.SaveThreshold and UI.SaveThreshold:Get() or 35
    local check_threat_only = UI.SaveOnThreatOnly and (UI.SaveOnThreatOnly:Get() == true) or false
    local save_on_cc = UI.SaveOnCC and (UI.SaveOnCC:Get() == true) or false
    local save_on_cc_hp = UI.SaveOnCCHP and UI.SaveOnCCHP:Get() or 100
    local ignore_fountain = UI.IgnoreFountain and (UI.IgnoreFountain:Get() == true) or false

    local tf_enabled = UI.TeamfightUlt and UI.TeamfightUlt:Get()
    local tf_min_enemies = UI.TeamfightMinEnemies and UI.TeamfightMinEnemies:Get() or 3

    for _, ally in ipairs(all_heroes) do
        if IsRealAllyHero(ally) then
            local u_name = Safe(NPC.GetUnitName, ally)
            local is_blacklisted = UI.AllyBlacklist and u_name and (UI.AllyBlacklist:Get(u_name) == true)

            -- Фильтр черного списка союзников
            if not is_blacklisted then
                -- Фильтр Аегиса
                local has_aegis = UI.IgnoreAegis and UI.IgnoreAegis:Get() and (Safe(NPC.HasItem, ally, "item_aegis", true) or Safe(NPC.HasModifier, ally, "modifier_item_aegis"))

                -- Фильтр астрала / неуязвимости
                local is_invuln = UI.IgnoreInvulnerable and UI.IgnoreInvulnerable:Get() and IsBanishedOrInvulnerable(ally)

                if not has_aegis and not is_invuln then
                    local pos = Safe(Entity.GetAbsOrigin, ally)
                    local in_fountain = pos and ignore_fountain and (IsPointInFountain(pos) or Safe(NPC.HasModifier, ally, MODIFIERS.fountain))

                    if not in_fountain then
                        local hp = Safe(Entity.GetHealth, ally) or 1000
                        local max_hp = Safe(Entity.GetMaxHealth, ally) or 1000
                        local hp_pct = (hp / max_hp) * 100

                        local enemies_near = CountEnemiesNearUnit(ally, threat_rad)
                        local is_cc, cc_type = HasFatalDebuff(ally, enemies_near)

                        local score = 0
                        local is_tf = false
                        local tf_centroid = nil

                        -- 1. Критический триггер: фатальный контроль (Duel, BH, Chrono, Stun)
                        -- ТРЕБУЕТ наличие врагов рядом (enemies_near > 0) и HP союзника <= порогу SaveOnCCHP!
                        if save_on_cc and is_cc and enemies_near > 0 and hp_pct <= save_on_cc_hp then
                            score = 1000 + (100 - hp_pct) + (enemies_near * 30)
                        end

                        -- 2. Триггер низкого здоровья: HP < порога и есть угроза
                        if hp_pct <= hp_threshold then
                            if not check_threat_only or enemies_near > 0 then
                                local threat_score = 500 + (100 - hp_pct) + (enemies_near * 40)
                                if threat_score > score then
                                    score = threat_score
                                end
                            end
                        end

                        -- 3. Командный врыв в замес (Teamfight Density): скопление >= tf_min_enemies в 450 AoE вокруг союзника
                        if tf_enabled then
                            local centroid, tf_count = GetEnemiesCentroidNearPos(pos, 450)
                            if tf_count >= tf_min_enemies then
                                local tf_score = 900 + (tf_count * 150) + (100 - hp_pct)
                                if tf_score > score then
                                    score = tf_score
                                    is_tf = true
                                    tf_centroid = centroid
                                end
                            end
                        end

                        -- Проверка TTD (Time to Death): успеет ли ульта долететь и спасти
                        if score > 0 and not is_tf and UI.TTDCheck and UI.TTDCheck:Get() then
                            local ttd = CalculateAllyTTD(ally, hp, enemies_near, now)
                            local min_ttd = (UI.TTDMinTime and UI.TTDMinTime:Get() or 6) / 10
                            if ttd < min_ttd then
                                -- Союзник погибнет быстрее, чем ульта приземлится -> сохраняем ульт!
                                score = 0
                            end
                        end

                        -- Бонус приоритета для Core-героев (Керри / Мид / Офф)
                        if score > 0 then
                            if UI.PrioritizeCores and UI.PrioritizeCores:Get() and IsCoreHero(ally) then
                                score = score + 200
                            end

                            if score > max_score then
                                max_score = score
                                best_ally = ally
                                best_tf_pos = is_tf and tf_centroid or nil
                            end
                        end
                    end
                end
            end
        end
    end

    -- Если тимфайт вокруг самой Dawnbreaker и других приоритетных целей нет
    if tf_enabled and State.me and Safe(Entity.IsAlive, State.me) and max_score < 900 then
        local my_pos = Safe(Entity.GetAbsOrigin, State.me)
        if my_pos and not (ignore_fountain and IsPointInFountain(my_pos)) then
            local centroid, tf_count = GetEnemiesCentroidNearPos(my_pos, 450)
            if tf_count >= tf_min_enemies then
                local my_hp = Safe(Entity.GetHealth, State.me) or 1000
                local my_max_hp = Safe(Entity.GetMaxHealth, State.me) or 1000
                local my_pct = (my_hp / my_max_hp) * 100
                local my_tf_score = 900 + (tf_count * 150) + (100 - my_pct)
                if my_tf_score > max_score then
                    max_score = my_tf_score
                    best_ally = State.me
                    best_tf_pos = centroid
                end
            end
        end
    end

    State.endangered_ally = best_ally
    State.highest_threat_score = max_score
    if best_tf_pos then
        State.is_teamfight_target = true
        State.teamfight_cast_pos = best_tf_pos
    else
        State.is_teamfight_target = false
        State.teamfight_cast_pos = nil
    end
    return best_ally, max_score
end

local function ProcessAutoSave(now)
    if not UI.SaveEnable or not UI.SaveEnable:Get() then return end
    if not State.me or not State.is_dawnbreaker then return end

    local is_channeling = Safe(NPC.HasModifier, State.me, MODIFIERS.r_channel)
        or (Safe(NPC.IsChannellingAbility, State.me) and State.r_spell and Safe(Ability.IsChannelling, State.r_spell))

    State.is_channeling = is_channeling

    -- 1. ЕСЛИ УЛЬТА УЖЕ КАСТУЕТСЯ (ЧЕННЕЛИНГ)
    if is_channeling then
        -- Очищаем пред-кастовую цель, так как ульта уже применяется
        State.endangered_ally = nil
        State.highest_threat_score = 0

        -- Синхронизируем позицию с thinker-сущностью ульты (если создана)
        if State.landing_thinker and Safe(Entity.IsAlive, State.landing_thinker) then
            local t_pos = Safe(Entity.GetAbsOrigin, State.landing_thinker)
            if t_pos then
                State.landing_pos = t_pos
            end
        end

        -- Защита от суицида (Anti-Feed Cancel): если союзник погиб во время каста
        if UI.AntiFeedCancel and UI.AntiFeedCancel:Get() and State.targeted_ally then
            if not Safe(Entity.IsAlive, State.targeted_ally) or Safe(Entity.IsDormant, State.targeted_ally) then
                State.is_script_order = true
                Player.PrepareUnitOrders(
                    State.player,
                    Enum.UnitOrder.DOTA_UNIT_ORDER_STOP,
                    nil,
                    Vector(0, 0, 0),
                    nil,
                    Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                    State.me
                )
                State.is_script_order = false
                State.targeted_ally = nil
                State.landing_pos = nil
                State.landing_thinker = nil
                return
            end
        end

        -- 1.1 Досрочное приземление (Early Land)
        if UI.EarlyLandEnable and UI.EarlyLandEnable:Get() then
            local land_spell = NPC.GetAbility(State.me, "dawnbreaker_land")
            if land_spell and CanCastSpell(land_spell) then
                local should_land_early = false

                -- Союзник при смерти (< EarlyLandHP %)
                if State.targeted_ally and Safe(Entity.IsAlive, State.targeted_ally) then
                    local ally_hp = Safe(Entity.GetHealth, State.targeted_ally) or 1000
                    local ally_max_hp = Safe(Entity.GetMaxHealth, State.targeted_ally) or 1000
                    local ally_hp_pct = (ally_hp / ally_max_hp) * 100
                    local early_thresh = UI.EarlyLandHP and UI.EarlyLandHP:Get() or 15
                    if ally_hp_pct <= early_thresh then
                        should_land_early = true
                    end
                end

                -- Враги выходят из зоны 400 AoE
                if not should_land_early and State.landing_pos then
                    local elapsed = (State.channel_start_time > 0) and (now - State.channel_start_time) or 0
                    if elapsed >= 0.35 then
                        local in_aoe = 0
                        local escaping = 0
                        local all_heroes = Heroes.GetAll() or {}
                        for _, enemy in ipairs(all_heroes) do
                            if enemy and enemy ~= State.me and Safe(Entity.IsAlive, enemy) and not Safe(Entity.IsSameTeam, State.me, enemy) and not Safe(Entity.IsDormant, enemy) and not Safe(NPC.IsIllusion, enemy) then
                                local e_pos = Safe(Entity.GetAbsOrigin, enemy)
                                if e_pos then
                                    local d = Dist2D(State.landing_pos, e_pos)
                                    if d <= 400 then
                                        in_aoe = in_aoe + 1
                                        if d >= 310 and Safe(NPC.IsRunning, enemy) then
                                            escaping = escaping + 1
                                        end
                                    end
                                end
                            end
                        end
                        if in_aoe > 0 and escaping == in_aoe then
                            should_land_early = true
                        end
                    end
                end

                if should_land_early then
                    Ability.CastNoTarget(land_spell, false, false, true)
                    return
                end
            end
        end

        -- 1.2 Поддержка Аганима: плавное перемещение области за союзником / замесом (Smart Aghs Reposition)
        if Safe(NPC.HasModifier, State.me, MODIFIERS.aghs) then
            local desired_pos = nil
            local cur_target = State.targeted_ally
            local cur_hp = cur_target and Safe(Entity.GetHealth, cur_target) or 1000
            local cur_max_hp = cur_target and Safe(Entity.GetMaxHealth, cur_target) or 1000
            local cur_pct = (cur_hp / cur_max_hp) * 100
            local cur_enemies = cur_target and CountEnemiesNearUnit(cur_target, 550) or 0

            -- Если союзник в безопасности (>80% HP и 0 врагов), перенаправляем круг на другого раненого или в бой
            if UI.SmartAghsReposition and UI.SmartAghsReposition:Get() and (cur_pct > 80 and cur_enemies == 0) then
                local cur_landing = State.landing_pos or (cur_target and Safe(Entity.GetAbsOrigin, cur_target))
                local best_new_ally = nil
                local lowest_hp = 80

                if cur_landing then
                    for _, other_ally in ipairs(Heroes.GetAll() or {}) do
                        if IsRealAllyHero(other_ally) and other_ally ~= cur_target then
                            local o_pos = Safe(Entity.GetAbsOrigin, other_ally)
                            if o_pos and Dist2D(cur_landing, o_pos) <= 900 then
                                local o_hp = Safe(Entity.GetHealth, other_ally) or 1000
                                local o_max = Safe(Entity.GetMaxHealth, other_ally) or 1000
                                local o_pct = (o_hp / o_max) * 100
                                local o_enemies = CountEnemiesNearUnit(other_ally, 600)
                                if o_pct < lowest_hp or o_enemies > 0 then
                                    lowest_hp = o_pct
                                    best_new_ally = other_ally
                                end
                            end
                        end
                    end

                    if best_new_ally then
                        desired_pos = Safe(Entity.GetAbsOrigin, best_new_ally)
                    else
                        local centroid, enemy_count = GetEnemiesCentroidNearPos(cur_landing, 800)
                        if enemy_count > 0 then
                            desired_pos = centroid
                        end
                    end
                end
            end

            if not desired_pos and cur_target and Safe(Entity.IsAlive, cur_target) then
                desired_pos = Safe(Entity.GetAbsOrigin, cur_target)
            end

            if desired_pos and State.player and (now - State.last_aghs_reposition_time >= 0.12) then
                State.last_aghs_reposition_time = now
                State.is_script_order = true
                Player.PrepareUnitOrders(
                    State.player,
                    Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION,
                    nil,
                    desired_pos,
                    nil,
                    Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                    State.me
                )
                State.is_script_order = false
                State.landing_pos = desired_pos
            end
        end
        return    else
        -- Не кастуем: сбрасываем цели только если не находимся в анимации каста (0.2с задержка)
        local in_cast_anim = (State.channel_start_time > 0) and ((now - State.channel_start_time) < 0.6)
        if not in_cast_anim and not (State.r_spell and CanCastSpell(State.r_spell)) then
            State.targeted_ally = nil
            State.landing_pos = nil
            State.landing_thinker = nil
            State.channel_start_time = 0
        end
    end

    -- 2. ЕСЛИ УЛЬТА НЕ ГОТОВА (КД, НЕТ МАНЫ, САЙЛЕНС, СТАН)
    local r_ready = State.r_spell and CanCastSpell(State.r_spell)
    if not r_ready or IsSilencedOrStunned(State.me) then
        State.endangered_ally = nil
        State.highest_threat_score = 0
        return
    end

    -- 3. Защита от спама кастами: не чаще чем раз в 1.0 сек
    if (now - State.last_auto_save_time) < 1.0 then return end

    -- 4. Сканирование союзников раз в 80 мс
    if (now - State.last_ally_scan_time) >= 0.08 then
        State.last_ally_scan_time = now
        ScanAlliesForSave(now)
    end

    local panic_key_pressed = UI.SavePanicKey and UI.SavePanicKey:IsDown()
    local target_ally = State.endangered_ally

    -- Проверка ресурсов Dawnbreaker (если не зажата принудительная кнопка Panic Key)
    if not panic_key_pressed then
        local my_mana = Safe(NPC.GetMana, State.me) or 0
        local my_max_mana = Safe(NPC.GetMaxMana, State.me) or 1
        local my_mana_pct = (my_mana / my_max_mana) * 100
        local min_mana_pct = UI.SaveMinMana and UI.SaveMinMana:Get() or 20
        if my_mana_pct < min_mana_pct then
            State.endangered_ally = nil
            State.highest_threat_score = 0
            return
        end

        local my_hp = Safe(Entity.GetHealth, State.me) or 1000
        local my_max_hp = Safe(Entity.GetMaxHealth, State.me) or 1000
        local my_hp_pct = (my_hp / my_max_hp) * 100
        local min_self_hp_pct = UI.SaveMinSelfHP and UI.SaveMinSelfHP:Get() or 25
        if my_hp_pct < min_self_hp_pct then
            State.endangered_ally = nil
            State.highest_threat_score = 0
            return
        end
    end

    -- Если зажата кнопка экстренного спасения, но опасности не было зафиксировано, берем союзника с минимальным HP
    if panic_key_pressed and not target_ally then
        local min_hp_pct = 100
        for _, ally in ipairs(Heroes.GetAll() or {}) do
            if IsRealAllyHero(ally) then
                local u_name = Safe(NPC.GetUnitName, ally)
                local is_bl = UI.AllyBlacklist and u_name and (UI.AllyBlacklist:Get(u_name) == true)
                if not is_bl then
                    local hp = Safe(Entity.GetHealth, ally) or 1000
                    local max_hp = Safe(Entity.GetMaxHealth, ally) or 1000
                    local pct = (hp / max_hp) * 100
                    if pct < min_hp_pct then
                        min_hp_pct = pct
                        target_ally = ally
                    end
                end
            end
        end
    end

    if target_ally and (State.highest_threat_score > 0 or panic_key_pressed) then
        local cast_pos = GetSolarGuardianCastPos(target_ally, State.is_teamfight_target, State.teamfight_cast_pos)
        if cast_pos then
            -- 3. Авто-BKB перед кастом ульты
            if UI.AutoBKBOnUlt and UI.AutoBKBOnUlt:Get() then
                local enemies_near_me = CountEnemiesNearUnit(State.me, 850)
                if enemies_near_me > 0 then
                    local bkb = NPC.GetItem(State.me, "item_black_king_bar", true)
                    if bkb and CanCastSpell(bkb) then
                        Ability.CastNoTarget(bkb, false, false, true)
                    end
                end
            end

            Ability.CastPosition(State.r_spell, cast_pos, false, false, true)
            State.last_auto_save_time = now
            State.last_act_time = now + 0.3
            State.targeted_ally = target_ally
            State.landing_pos = cast_pos
            State.channel_start_time = now
            State.endangered_ally = nil
            State.highest_threat_score = 0
            State.is_teamfight_target = false
            State.teamfight_cast_pos = nil
        end
    end
end

--#endregion

--#region Callbacks & Visuals

-- Вспомогательная функция для отрисовки аккуратных бейджей с фоном, рамкой и тенью
-- Calculate screen position strictly ABOVE hero health/mana bar (Zero Overlap)
local function GetHealthBarAnchor(hero, gap)
    if not hero then return nil end
    local origin = Safe(Entity.GetAbsOrigin, hero)
    if not origin then return nil end
    local offset = Safe(NPC.GetHealthBarOffset, hero) or 220
    local sp, vis = Render.WorldToScreen(Vector(origin.x, origin.y, origin.z + offset))
    if not vis or not sp then return nil end
    gap = gap or 14

    -- In Source 2 / Panorama UI:
    -- Health bar screen offset is ~ -37px vertically from WorldToScreen(origin + offset).
    -- Hero name / level / debuff icons occupy another 20-24px above the health bar.
    local hbso_y = -38
    local name_height = 22
    if XHelpers and XHelpers.XNPC and XHelpers.XNPC.GetHealthbarScreenData then
        local hbso, hbsize = Safe(XHelpers.XNPC.GetHealthbarScreenData, XHelpers.XNPC, hero)
        if hbso and hbso.y then
            hbso_y = hbso.y
        end
    end

    local user_offset = (UI and UI.OverheadOffset and UI.OverheadOffset:Get()) or 0
    local top_y = sp.y + hbso_y - name_height - gap - user_offset
    return sp.x, top_y
end

local function DrawBadge(font, font_size, text, x, y, bg_col, border_col, text_col, pad_x, pad_y, rounding)
    if not Render or not Render.Text or not font or not text then return y end
    pad_x = pad_x or 7
    pad_y = pad_y or 4
    rounding = rounding or 5
    local t_size = Render.TextSize(font, font_size, text)
    local x1 = x - (t_size.x / 2) - pad_x
    local y1 = y - pad_y
    local x2 = x + (t_size.x / 2) + pad_x
    local y2 = y + t_size.y + pad_y

    Safe(Render.FilledRect, Vec2(x1, y1), Vec2(x2, y2), bg_col, rounding)
    Safe(Render.Rect, Vec2(x1, y1), Vec2(x2, y2), border_col, rounding, nil, 1.2)

    local tx = x - (t_size.x / 2)
    local ty = y
    Render.Text(font, font_size, text, Vec2(tx + 1, ty + 1), Color(0, 0, 0, 240))
    Render.Text(font, font_size, text, Vec2(tx, ty), text_col)
    return y2
end

-- Отрисовка 4 тактических засечек (compass ticks) на периметре круга AoE 400
local function DrawGroundCompassTicks(center, radius, color, thickness)
    if not Render or not Render.WorldToScreen or not center then return end
    thickness = thickness or 2.2
    local tick_len = 24
    local angles = { 0, math.pi * 0.5, math.pi, math.pi * 1.5 }
    for _, a in ipairs(angles) do
        local cos_a, sin_a = math.cos(a), math.sin(a)
        local x1 = center.x + cos_a * (radius - 12)
        local y1 = center.y + sin_a * (radius - 12)
        local x2 = center.x + cos_a * (radius + tick_len)
        local y2 = center.y + sin_a * (radius + tick_len)

        local gz1 = World and World.GetGroundZ and Safe(World.GetGroundZ, x1, y1)
        local wz1 = (gz1 and gz1 > -5000 and gz1 or center.z) + 4
        local gz2 = World and World.GetGroundZ and Safe(World.GetGroundZ, x2, y2)
        local wz2 = (gz2 and gz2 > -5000 and gz2 or center.z) + 4

        local p1, v1 = Render.WorldToScreen(Vector(x1, y1, wz1))
        local p2, v2 = Render.WorldToScreen(Vector(x2, y2, wz2))
        if v1 and v2 then
            Safe(Render.Line, p1, p2, Alpha(color, 80), thickness * 2.8)
            Safe(Render.Line, p1, p2, color, thickness)
            Safe(Render.Line, p1, p2, Color(255, 255, 255, 220), 1.0)
            Safe(Render.FilledCircle, p2, 4, Alpha(color, 120))
            Safe(Render.FilledCircle, p2, 2.2, Color(255, 255, 255, 255))
        end
    end
end

-- Отрисовка 3D-круга по рельефу земли (terrain)
local function DrawGroundCircleSimple(center, radius, color, thickness, segments)
    if not Render or not Render.WorldToScreen or not center then return end
    segments = segments or 28
    thickness = thickness or 2.0
    local step = (math.pi * 2) / segments
    local prev_sp, prev_vis = nil, false
    local first_sp, first_vis = nil, false

    for i = 0, segments do
        local a = i * step
        local wx = center.x + math.cos(a) * radius
        local wy = center.y + math.sin(a) * radius
        local gz = World and World.GetGroundZ and Safe(World.GetGroundZ, wx, wy)
        local wz = (gz and gz > -5000 and gz or center.z) + 4
        local sp, vis = Render.WorldToScreen(Vector(wx, wy, wz))

        if i == 0 then first_sp, first_vis = sp, vis end
        if i > 0 and prev_vis and vis then
            Safe(Render.Line, prev_sp, sp, color, thickness)
        end
        prev_sp, prev_vis = sp, vis
    end
    if prev_vis and first_vis and segments > 2 then
        Safe(Render.Line, prev_sp, first_sp, color, thickness)
    end
end

-- Ultra-Hype 3D Celestial Solar Ritual Ground FX
local function DrawGroundCircle(center, radius, color, thickness, segments, now, is_channeling)
    if not Render or not Render.WorldToScreen or not center then return end
    segments = segments or 36
    thickness = thickness or 2.2
    now = now or GameRules.GetGameTime()

    local step = (math.pi * 2) / segments
    local prev_sp, prev_vis = nil, false
    local first_sp, first_vis = nil, false

    local c_outer = Alpha(color, (color.a or 255) * 0.28)
    local c_core = color
    local c_glow = Alpha(Color(255, 255, 255), (color.a or 255) * 0.70)

    -- 1. Triple-pass silk radiant ring (Flashy silk bloom)
    for i = 0, segments do
        local a = i * step
        local wx = center.x + math.cos(a) * radius
        local wy = center.y + math.sin(a) * radius
        local gz = World and World.GetGroundZ and Safe(World.GetGroundZ, wx, wy)
        local wz = (gz and gz > -5000 and gz or center.z) + 4
        local sp, vis = Render.WorldToScreen(Vector(wx, wy, wz))

        if i == 0 then first_sp, first_vis = sp, vis end

        if i > 0 and prev_vis and vis then
            Safe(Render.Line, prev_sp, sp, c_outer, thickness * 2.8)
            Safe(Render.Line, prev_sp, sp, c_core, thickness)
            Safe(Render.Line, prev_sp, sp, c_glow, math.max(1.0, thickness * 0.5))
        end
        prev_sp, prev_vis = sp, vis
    end

    if prev_vis and first_vis and segments > 2 then
        Safe(Render.Line, prev_sp, first_sp, c_outer, thickness * 2.8)
        Safe(Render.Line, prev_sp, first_sp, c_core, thickness)
        Safe(Render.Line, prev_sp, first_sp, c_glow, math.max(1.0, thickness * 0.5))
    end

    -- 2. Orbiting Celestial Stars / Sun Motes (6 glowing particles traveling around the 400 AoE rim)
    local mote_count = 6
    for m = 1, mote_count do
        local ma = (m * (math.pi * 2 / mote_count)) + (now * 1.8)
        local mx = center.x + math.cos(ma) * radius
        local my = center.y + math.sin(ma) * radius
        local gz = World and World.GetGroundZ and Safe(World.GetGroundZ, mx, my)
        local wz = (gz and gz > -5000 and gz or center.z) + 6
        local msp, mvis = Render.WorldToScreen(Vector(mx, my, wz))
        if mvis then
            Safe(Render.FilledCircle, msp, 6.5, Alpha(color, 65))
            Safe(Render.FilledCircle, msp, 3.8, color)
            Safe(Render.FilledCircle, msp, 1.8, Color(255, 255, 255, 255))
        end
    end

    -- 3. Counter-rotating segmented dashed celestial ring (radius 230)
    local inner_r = 230
    local inner_segs = 16
    local i_step = (math.pi * 2) / inner_segs
    local rot_offset = -(now * 0.85)
    for i = 0, inner_segs - 1, 2 do
        local a1 = i * i_step + rot_offset
        local a2 = (i + 0.85) * i_step + rot_offset
        local p1_w = Vector(center.x + math.cos(a1) * inner_r, center.y + math.sin(a1) * inner_r, center.z + 4)
        local p2_w = Vector(center.x + math.cos(a2) * inner_r, center.y + math.sin(a2) * inner_r, center.z + 4)
        local sp1, v1 = Render.WorldToScreen(p1_w)
        local sp2, v2 = Render.WorldToScreen(p2_w)
        if v1 and v2 then
            Safe(Render.Line, sp1, sp2, Alpha(color, 140), 2.0)
            Safe(Render.Line, sp1, sp2, Color(255, 255, 255, 210), 1.0)
        end
    end

    -- 4. Expanding Solar Beacon Shockwave (during channel)
    if is_channeling and State.channel_start_time and State.channel_start_time > 0 then
        local wave_t = ((now - State.channel_start_time) % 0.75) / 0.75
        local wave_r = wave_t * 400
        local wave_alpha = math.floor((1.0 - wave_t) * 190)
        if wave_alpha > 12 then
            DrawGroundCircleSimple(center, wave_r, Alpha(Color(255, 205, 30), wave_alpha), 2.0, 24)
        end
    end
end

local function DrawOffscreenIndicator(target_pos, is_channeling)
    if UI.DrawOffscreenRadar and not UI.DrawOffscreenRadar:Get() then return end
    if not Render or not Render.ScreenSize or not target_pos or not State.me then return end
    local scr = Render.ScreenSize()
    if not scr or scr.x <= 0 or scr.y <= 0 then return end

    local cx, cy = scr.x * 0.5, scr.y * 0.5
    local target_sp, vis = Render.WorldToScreen(target_pos)

    local dir_x, dir_y
    if target_sp and vis then
        dir_x = target_sp.x - cx
        dir_y = target_sp.y - cy
    elseif target_sp and not vis then
        dir_x = -(target_sp.x - cx)
        dir_y = -(target_sp.y - cy)
    else
        local me_pos = Safe(Entity.GetAbsOrigin, State.me)
        if me_pos then
            dir_x = target_pos.x - me_pos.x
            dir_y = target_pos.y - me_pos.y
        else
            dir_x, dir_y = 1, 0
        end
    end

    local len = math.sqrt(dir_x * dir_x + dir_y * dir_y)
    if len <= 0.001 then return end
    dir_x, dir_y = dir_x / len, dir_y / len

    local margin = 60
    local max_w = (scr.x * 0.5) - margin
    local max_h = (scr.y * 0.5) - margin

    local scale_x = (dir_x ~= 0) and (max_w / math.abs(dir_x)) or 999999
    local scale_y = (dir_y ~= 0) and (max_h / math.abs(dir_y)) or 999999
    local scale = math.min(scale_x, scale_y)

    local edge_x = cx + dir_x * scale
    local edge_y = cy + dir_y * scale
    local edge_sp = Vec2(edge_x, edge_y)

    local me_pos = Safe(Entity.GetAbsOrigin, State.me)
    local dist = me_pos and math.floor(Dist2D(me_pos, target_pos)) or 0
    local tag = is_channeling and Loc("hud.landing_tag", dist) or Loc("hud.solar_tag", dist)
    local col = is_channeling and Color(255, 160, 20, 240) or Color(255, 215, 0, 230)
    local font = State.bold_font or State.hud_font

    local perp_x, perp_y = -dir_y, dir_x
    local tip = Vec2(edge_sp.x + dir_x * 14, edge_sp.y + dir_y * 14)
    local p2 = Vec2(edge_sp.x - dir_x * 9 + perp_x * 9, edge_sp.y - dir_y * 9 + perp_y * 9)
    local p3 = Vec2(edge_sp.x - dir_x * 9 - perp_x * 9, edge_sp.y - dir_y * 9 - perp_y * 9)

    Safe(Render.FilledTriangle, {tip, p2, p3}, col)
    Safe(Render.Triangle, {tip, p2, p3}, Color(12, 14, 18, 230), 5, nil, 1.8)

    Safe(Render.FilledCircle, edge_sp, 14, Alpha(col, 50))
    Safe(Render.FilledCircle, edge_sp, 10, Color(14, 16, 22, 230))
    Safe(Render.Circle, edge_sp, 10, col, 2.0)
    Safe(Render.FilledCircle, edge_sp, 3.5, Color(255, 255, 255, 255))

    if font then
        local t_size = Render.TextSize(font, 12, tag)
        local tx = edge_sp.x - (t_size.x * 0.5)
        local ty = edge_sp.y - 30
        tx = math.max(14, math.min(scr.x - t_size.x - 14, tx))
        ty = math.max(14, math.min(scr.y - 30, ty))

        Render.FilledRect(Vec2(tx - 6, ty - 3), Vec2(tx + t_size.x + 6, ty + t_size.y + 3), Color(12, 14, 18, 230), 4)
        Render.Rect(Vec2(tx - 6, ty - 3), Vec2(tx + t_size.x + 6, ty + t_size.y + 3), col, 4, nil, 1.2)
        Render.Text(font, 12, tag, Vec2(tx + 1, ty + 1), Color(0, 0, 0, 240))
        Render.Text(font, 12, tag, Vec2(tx, ty), Color(255, 235, 100, 255))
    end
end

local function UpdateMinimapDisplay(now)
    if (now - State.last_minimap_draw_time) < 0.10 then return end
    State.last_minimap_draw_time = now

    local show_line = UI.DrawMinimapLine and UI.DrawMinimapLine:Get()
    if not show_line then return end
    if not MiniMap or not MiniMap.SendLine then return end
    if not State.me or not State.is_dawnbreaker then return end
    if not State.is_channeling or not State.landing_pos then return end

    -- Ограничиваем отправку пакета траектории 1 разом в 1.5 сек для нулевого влияния на буфер
    if (now - (State.last_minimap_flight_send or 0)) < 1.5 then return end
    State.last_minimap_flight_send = now

    local me_pos = Safe(Entity.GetAbsOrigin, State.me)
    if me_pos and State.landing_pos then
        Safe(MiniMap.SendLine, me_pos, true, true)
        Safe(MiniMap.SendLine, State.landing_pos, false, true)
    end
end

local function GetAllyDangerStatus(ally, now)
    if not ally then return nil end
    local hp = Safe(Entity.GetHealth, ally) or 1
    local max_hp = Safe(Entity.GetMaxHealth, ally) or 1
    local pct = (hp / max_hp) * 100

    local threat_rad = (UI.ThreatRadius and UI.ThreatRadius:Get()) or 950
    local enemies_near = CountEnemiesNearUnit(ally, threat_rad)
    local has_fatal, fatal_name = HasFatalDebuff(ally, enemies_near)
    local ttd = CalculateAllyTTD(ally, hp, enemies_near, now)

    -- 1. КРИТИЧЕСКАЯ ОПАСНОСТЬ (DANGER / RED)
    local save_threshold = (UI.SaveThreshold and UI.SaveThreshold:Get()) or 35
    local cc_threshold = (UI.SaveOnCCHP and UI.SaveOnCCHP:Get()) or 75

    if (has_fatal and pct <= cc_threshold)
        or (enemies_near >= 1 and pct <= save_threshold)
        or (enemies_near >= 2 and pct <= 50)
        or (enemies_near >= 1 and ttd < 3.5) then
        return "DANGER", pct, enemies_near, fatal_name, ttd
    end

    -- 2. В БОЮ / РАЗМЕН (WARNING / YELLOW)
    if enemies_near >= 1 or pct <= 55 or (ttd < 8.0 and enemies_near > 0) then
        return "WARNING", pct, enemies_near, nil, ttd
    end

    -- 3. В БЕЗОПАСНОСТИ (SAFE / GREEN)
    return "SAFE", pct, enemies_near, nil, ttd
end

-- Отрисовка цветных пульсирующих колец опасности союзников на миникарте (Feature #19)
local function DrawMinimapAllyRings(now)
    if not UI.MinimapDangerRings or not UI.MinimapDangerRings:Get() then return end
    if not MiniMap or not MiniMap.DrawCircle then return end
    if not State.me or not State.is_dawnbreaker then return end

    local show_green = UI.MinimapShowGreen and UI.MinimapShowGreen:Get()
    local all_heroes = Heroes.GetAll()
    if not all_heroes then return end

    local pulse = math.sin(now * 7.5) * 60

    for _, ally in ipairs(all_heroes) do
        if ally and Safe(Entity.IsAlive, ally) and not Safe(Entity.IsDormant, ally) and Safe(Entity.IsSameTeam, State.me, ally) then
            local is_real = IsRealAllyHero(ally) or (ally == State.me)
            if is_real then
                local a_pos = Safe(Entity.GetAbsOrigin, ally)
                if a_pos then
                    local status, pct, enemies_near, fatal_name, ttd = GetAllyDangerStatus(ally, now)
                    if status == "DANGER" then
                        -- 🔴 Красное пульсирующее кольцо критической опасности (3-уровневый радарный маяк)
                        local rad = 430 + pulse
                        Safe(MiniMap.DrawCircle, a_pos, rad, Color(255, 30, 30, 240))
                        Safe(MiniMap.DrawCircle, a_pos, rad - 40, Color(255, 70, 70, 200))
                        Safe(MiniMap.DrawCircle, a_pos, rad - 80, Color(255, 120, 120, 160))
                    elseif status == "WARNING" then
                        -- 🟡 Желтое кольцо (бой / размен ресурсов)
                        Safe(MiniMap.DrawCircle, a_pos, 380, Color(255, 205, 30, 190))
                    elseif status == "SAFE" and show_green then
                        -- 🟢 Зеленое кольцо (в безопасности)
                        Safe(MiniMap.DrawCircle, a_pos, 320, Color(50, 230, 80, 120))
                    end
                end
            end
        end
    end
end

function Script.OnScriptsLoaded()
    InitMenu()
end

function Script.OnUpdate()
    if not UI.ready then
        InitMenu()
    end
    if not UI.ready then return end

    local is_db = UpdateHeroCache()
    if not is_db then return end

    local now = GameRules.GetGameTime()

    -- Синхронизация состояния ченнелинга
    local is_chan = Safe(NPC.HasModifier, State.me, MODIFIERS.r_channel)
        or (Safe(NPC.IsChannellingAbility, State.me) and State.r_spell and Safe(Ability.IsChannelling, State.r_spell))
    State.is_channeling = is_chan

    -- Синхронизация координат с thinker-сущностью
    if is_chan and State.landing_thinker and Safe(Entity.IsAlive, State.landing_thinker) then
        local t_pos = Safe(Entity.GetAbsOrigin, State.landing_thinker)
        if t_pos then
            State.landing_pos = t_pos
        end
    end

    -- Периодическая синхронизация черного списка союзников в меню
    if (now - State.last_blacklist_sync) >= 3.0 then
        State.last_blacklist_sync = now
        UpdateAllyBlacklistMenu()
    end

    -- Авто-спасение ультой
    ProcessAutoSave(now)

    -- Обновление отображения на миникарте (10 Гц)
    UpdateMinimapDisplay(now)
end

function Script.OnDraw()
    if not UI.ready then InitMenu() end
    if not State.is_dawnbreaker or not State.me then return end

    -- Загрузка шрифтов при первом вызове (обычный и жирный)
    if not State.hud_font and Render and Render.LoadFont then
        State.hud_font = Render.LoadFont("Tahoma", Enum.FontCreate.FONTFLAG_ANTIALIAS)
    end
    if not State.bold_font and Render and Render.LoadFont then
        State.bold_font = Render.LoadFont("Tahoma", Enum.FontCreate.FONTFLAG_ANTIALIAS, 700)
    end

    local now = GameRules.GetGameTime()
    -- Отображение колец опасности на миникарте (Фича #19)
    DrawMinimapAllyRings(now)

    -- GPU-оверлей зоны приземления на миникарте (без спама сетевыми пакетами)
    if UI.DrawMinimapLanding and UI.DrawMinimapLanding:Get() and State.landing_pos and MiniMap and MiniMap.DrawCircle then
        local pulse = math.sin(now * 5.0) * 15
        Safe(MiniMap.DrawCircle, State.landing_pos, 400 + pulse, Color(255, 185, 20, 220))
        Safe(MiniMap.DrawCircle, State.landing_pos, 350, Color(255, 220, 70, 160))
        Safe(MiniMap.DrawCircle, State.landing_pos, 70, Color(255, 255, 255, 240))
    end

    local is_channeling = State.is_channeling
        or Safe(NPC.HasModifier, State.me, MODIFIERS.r_channel)
        or (Safe(NPC.IsChannellingAbility, State.me) and State.r_spell and Safe(Ability.IsChannelling, State.r_spell))

    local r_ready = State.r_spell and CanCastSpell(State.r_spell)

    local target_ally = nil
    local landing_pos = nil

    if is_channeling then
        target_ally = State.targeted_ally
        landing_pos = State.landing_pos or (target_ally and Safe(Entity.GetAbsOrigin, target_ally))
    elseif r_ready and State.endangered_ally then
        target_ally = State.endangered_ally
        landing_pos = GetSolarGuardianCastPos(target_ally, State.is_teamfight_target, State.teamfight_cast_pos) or Safe(Entity.GetAbsOrigin, target_ally)
    end

    if target_ally and (not Safe(Entity.IsAlive, target_ally) or Safe(Entity.IsDormant, target_ally)) then
        target_ally = nil
    end

    -- ИНДИКАТОРЫ НАД DAWNBREAKER (Строго НАД полосками HP и маны - Zero Overlap)
    -- =========================================================================
    local me_hx, me_hy = GetHealthBarAnchor(State.me, 24)
    if me_hx and me_hy and State.hud_font then
        local cur_y = me_hy
        local bold_font = State.bold_font or State.hud_font

        -- 1. Индикатор стаков Luminosity (Нижний ряд, безопасно на 24px выше полоски HP)
        if UI.DrawLuminosity and UI.DrawLuminosity:Get() then
            local lum_spell = NPC.GetAbility(State.me, "dawnbreaker_luminosity")
            local lum_level = lum_spell and Safe(Ability.GetLevel, lum_spell) or 0

            if lum_level > 0 then
                local lum_mod = GetLuminosityModifier(State.me)
                local stacks = lum_mod and Safe(Modifier.GetStackCount, lum_mod) or 0
                local lx = me_hx
                local ly = cur_y - 10

                if stacks >= 3 then
                    local pulse = math.abs(math.sin(now * 7))
                    local glow_a = math.floor(180 + 75 * pulse)
                    -- Сияющий баннер готовности крита с анимацией боковых искр
                    local b_y = DrawBadge(bold_font, 11, Loc("hud.crit_ready"), lx, ly, Color(26, 18, 5, 235), Color(255, 200, 0, glow_a), Color(255, 225, 60, 255), 9, 3, 5)
                    local spark_pulse = math.sin(now * 8) * 2
                    Safe(Render.FilledCircle, Vec2(lx - 85 - spark_pulse, ly + 6), 3, Color(255, 235, 120, 255))
                    Safe(Render.FilledCircle, Vec2(lx + 85 + spark_pulse, ly + 6), 3, Color(255, 235, 120, 255))
                    cur_y = ly - 18
                else
                    local pip_w = 16
                    local pip_h = 7
                    local pip_gap = 4
                    local total_w = (3 * pip_w) + (2 * pip_gap)
                    local start_x = lx - (total_w / 2)
                    local py = ly

                    -- Высокотехнологичный темный корпус
                    Safe(Render.FilledRect, Vec2(start_x - 5, py - 3), Vec2(start_x + total_w + 5, py + pip_h + 3), Color(10, 12, 16, 230), 4)
                    Safe(Render.Rect, Vec2(start_x - 5, py - 3), Vec2(start_x + total_w + 5, py + pip_h + 3), Color(50, 55, 65, 180), 4, nil, 1.0)

                    for i = 1, 3 do
                        local px = start_x + (i - 1) * (pip_w + pip_gap)
                        local is_active = (i <= stacks)
                        local fill_col = is_active and Color(255, 205, 30, 245) or Color(22, 25, 32, 190)
                        local border_col = is_active and Color(255, 235, 120, 255) or Color(45, 50, 60, 160)

                        Safe(Render.FilledRect, Vec2(px, py), Vec2(px + pip_w, py + pip_h), fill_col, 2)
                        Safe(Render.Rect, Vec2(px, py), Vec2(px + pip_w, py + pip_h), border_col, 2, nil, 1.0)
                        if is_active then
                            Safe(Render.FilledCircle, Vec2(px + pip_w * 0.5, py + pip_h * 0.5), 1.6, Color(255, 255, 255, 255))
                        end
                    end
                    cur_y = ly - 16
                end
            end
        end

        -- 2. Единая кибер-панель статуса (Безопасность + Готовность ульты в одной плашке)
        if (UI.DrawSafeCastZone and UI.DrawSafeCastZone:Get()) or (UI.DrawStatus and UI.DrawStatus:Get()) then
            local enemies_850 = CountEnemiesNearUnit(State.me, 850)
            local enemies_1200 = CountEnemiesNearUnit(State.me, 1200)
            local is_vis = Safe(NPC.IsVisibleToEnemies, State.me) == true

            local cd_remaining = State.r_spell and Safe(Ability.GetCooldownTimeRemaining, State.r_spell) or 0
            local my_mana = Safe(NPC.GetMana, State.me) or 0
            local mana_cost = State.r_spell and Safe(Ability.GetManaCost, State.r_spell) or 150

            -- Слева: статус видимости
            local zone_str = ""
            local zone_col = Color(60, 255, 130, 255)
            if enemies_850 > 0 then
                zone_str = Loc("hud.danger_enemies", enemies_850)
                zone_col = Color(255, 65, 65, 255)
            elseif is_vis or enemies_1200 > 0 then
                zone_str = Loc("hud.visible")
                zone_col = Color(255, 185, 40, 255)
            else
                zone_str = Loc("hud.safe_fog")
                zone_col = Color(60, 255, 130, 255)
            end

            -- Справа: готовность ульты
            local ult_str = ""
            local ult_col = Color(50, 255, 120, 255)
            if is_channeling then
                local remain = (State.channel_start_time > 0) and math.max(0, 1.7 - (now - State.channel_start_time)) or 0
                ult_str = Loc("hud.landing_countdown", remain)
                ult_col = Color(255, 195, 30, 255)
            elseif IsSilencedOrStunned(State.me) then
                ult_str = Loc("hud.disabled")
                ult_col = Color(255, 70, 70, 255)
            elseif r_ready then
                ult_str = Loc("hud.ult_ready")
                ult_col = Color(50, 255, 120, 255)
            elseif cd_remaining > 0 then
                ult_str = Loc("hud.ult_cd", cd_remaining)
                ult_col = Color(255, 135, 70, 255)
            elseif my_mana < mana_cost then
                ult_str = Loc("hud.mana_low", math.floor(my_mana), math.floor(mana_cost))
                ult_col = Color(80, 200, 255, 255)
            else
                ult_str = Loc("hud.not_ready")
                ult_col = Color(180, 180, 180, 220)
            end

            local show_zone = UI.DrawSafeCastZone and UI.DrawSafeCastZone:Get()
            local show_status = UI.DrawStatus and UI.DrawStatus:Get()
            local text = ""
            if show_zone and show_status then
                text = zone_str .. "  │  " .. ult_str
            elseif show_zone then
                text = zone_str
            else
                text = ult_str
            end

            local pill_col = is_channeling and Color(255, 180, 30, 255) or ((enemies_850 > 0) and Color(255, 60, 60, 255) or (r_ready and Color(50, 220, 110, 230) or Color(200, 140, 40, 220)))
            local py = cur_y - 12
            DrawBadge(bold_font, 11, text, me_hx, py, Color(10, 12, 16, 235), pill_col, Color(245, 245, 250, 255), 10, 4, 6)
        end
    end

    -- =========================================================================
    -- ИНДИКАТОРЫ НАД ЦЕЛЕВЫМ СОЮЗНИКОМ (Строго НАД полосками HP и маны)
    -- =========================================================================
    if target_ally then
        local ax, ay = GetHealthBarAnchor(target_ally, 24)
        if ax and ay and State.hud_font then
            local cur_y = ay
            local bold_font = State.bold_font or State.hud_font

            -- 1. Проекция исцеления ульты с интерактивной шкалой HP
            if UI.DrawHealProjection and UI.DrawHealProjection:Get() then
                local r_lvl = State.r_spell and Safe(Ability.GetLevel, State.r_spell) or 1
                if r_lvl < 1 then r_lvl = 1 end

                local pulse_table = {35, 45, 55}
                local land_table = {300, 425, 550}
                local pulse_heal = pulse_table[r_lvl] or 45
                local land_heal = land_table[r_lvl] or 425

                if Safe(NPC.HasModifier, State.me, MODIFIERS.aghs) then
                    pulse_heal = pulse_heal + 25
                end

                local pulses = 8
                if is_channeling and State.channel_start_time > 0 then
                    local elapsed = now - State.channel_start_time
                    pulses = math.max(0, math.floor((1.7 - elapsed) / 0.2))
                end

                local total_heal = math.floor((pulses * pulse_heal) + land_heal)
                local cur_hp = Safe(Entity.GetHealth, target_ally) or 1000
                local max_hp = Safe(Entity.GetMaxHealth, target_ally) or 1000
                local predicted_hp_pct = math.min(100, math.floor(((cur_hp + total_heal) / max_hp) * 100))
                local cur_hp_pct = math.floor((cur_hp / max_hp) * 100)

                local heal_text = Loc("hud.heal_projection", total_heal, predicted_hp_pct)
                local py = cur_y - 20
                DrawBadge(bold_font, 12, heal_text, ax, py, Color(10, 24, 14, 235), Color(40, 220, 100, 230), Color(70, 255, 130, 255), 9, 3, 5)

                -- Двухсегментная интерактивная полоска прогноза здоровья
                local bar_w = 110
                local bar_h = 5
                local bar_x = ax - (bar_w / 2)
                local bar_y = py + 18
                local cur_w = math.floor(bar_w * math.max(0, math.min(1.0, cur_hp / max_hp)))
                local pred_w = math.floor(bar_w * math.max(0, math.min(1.0, (cur_hp + total_heal) / max_hp)))

                -- Базовый корпус
                Safe(Render.FilledRect, Vec2(bar_x, bar_y), Vec2(bar_x + bar_w, bar_y + bar_h), Color(12, 14, 18, 235), 3)
                Safe(Render.Rect, Vec2(bar_x, bar_y), Vec2(bar_x + bar_w, bar_y + bar_h), Color(50, 60, 70, 190), 3, nil, 1.0)

                -- Сегмент прогноза хила (Золотое / Изумрудное свечение)
                if pred_w > cur_w then
                    Safe(Render.FilledRect, Vec2(bar_x + cur_w, bar_y), Vec2(bar_x + pred_w, bar_y + bar_h), Color(255, 205, 30, 220), 2)
                end
                -- Сегмент текущего здоровья (Яркий изумруд)
                if cur_w > 0 then
                    Safe(Render.FilledRect, Vec2(bar_x, bar_y), Vec2(bar_x + cur_w, bar_y + bar_h), Color(50, 235, 110, 255), 2)
                end
                -- Тактические насечки 25%, 50%, 75%
                for t = 1, 3 do
                    local tx = bar_x + (bar_w * (t * 0.25))
                    Safe(Render.Line, Vec2(tx, bar_y), Vec2(tx, bar_y + bar_h), Color(15, 18, 24, 200), 1.0)
                end

                cur_y = py - 6
            end

            -- 2. Подсветка угрозы союзнику / тимфайта (Верхний ряд, над полоской хила)
            if UI.DrawAllyThreat and UI.DrawAllyThreat:Get() then
                local ally_hp = Safe(Entity.GetHealth, target_ally) or 1000
                local ally_max_hp = Safe(Entity.GetMaxHealth, target_ally) or 1000
                local ally_pct = math.floor((ally_hp / ally_max_hp) * 100)

                local text = ""
                local alert_col = Color(255, 50, 50, 255)
                local border_col = Color(255, 40, 40, 220)
                local bg_col = Color(28, 10, 10, 230)

                if State.is_teamfight_target then
                    text = Loc("hud.teamfight_target", ally_pct)
                    alert_col = Color(255, 175, 30, 255)
                    border_col = Color(255, 150, 20, 240)
                    bg_col = Color(28, 16, 8, 230)
                else
                    text = Loc("hud.saving_ally", ally_pct)
                    local pulse = math.abs(math.sin(now * 8))
                    border_col = Color(255, 40, 40, math.floor(180 + 75 * pulse))
                end

                DrawBadge(bold_font, 12, text, ax, cur_y - 12, bg_col, border_col, alert_col, 9, 3, 5)
            end
        end
    end

    -- =========================================================================
    -- ЗОНА ПРИЗЕМЛЕНИЯ В МИРЕ (AoE 400, Compass Ticks, Progress Bar)
    -- =========================================================================
    if UI.DrawWorldLandingCircle and UI.DrawWorldLandingCircle:Get() and landing_pos then
        local circle_col = is_channeling and Color(255, 160, 20, 220) or Color(255, 215, 0, 180)
        DrawGroundCircle(landing_pos, 400, circle_col, 2.2, 36, now, is_channeling)
        DrawGroundCompassTicks(landing_pos, 400, circle_col, 2.2)

        local gz_c = World and World.GetGroundZ and Safe(World.GetGroundZ, landing_pos.x, landing_pos.y)
        local wz_c = (gz_c and gz_c > -5000 and gz_c or landing_pos.z) + 6
        local csp, cvis = Render.WorldToScreen(Vector(landing_pos.x, landing_pos.y, wz_c))

        if cvis then
            -- Radiant solar flare center crosshair
            Render.FilledCircle(csp, 4.5, Color(255, 255, 255, 255))
            Render.Circle(csp, 11, circle_col, 2.2)
            Render.Circle(csp, 16 + math.sin(now * 6.5) * 3, Alpha(circle_col, 90), 1.2)

            Render.Line(Vec2(csp.x - 20, csp.y), Vec2(csp.x - 7, csp.y), circle_col, 2.2)
            Render.Line(Vec2(csp.x + 7, csp.y), Vec2(csp.x + 20, csp.y), circle_col, 2.2)
            Render.Line(Vec2(csp.x, csp.y - 20), Vec2(csp.x, csp.y - 7), circle_col, 2.2)
            Render.Line(Vec2(csp.x, csp.y + 7), Vec2(csp.x, csp.y + 20), circle_col, 2.2)

            if State.hud_font then
                local text = Loc("hud.landing_zone_label")
                local is_chan = is_channeling and State.channel_start_time > 0
                local elapsed = is_chan and (now - State.channel_start_time) or 0
                if is_chan then
                    local remain = math.max(0, 1.7 - elapsed)
                    text = Loc("hud.landing_countdown", remain)
                end

                local font = State.bold_font or State.hud_font
                local t_size = Render.TextSize(font, 13, text)
                local tx = csp.x - (t_size.x / 2)
                local ty = csp.y - (is_chan and 44 or 36)

                local box_w = math.max(t_size.x + 16, 120)
                local bx = csp.x - (box_w / 2)

                Safe(Render.FilledRect, Vec2(bx, ty - 4), Vec2(bx + box_w, ty + t_size.y + (is_chan and 11 or 4)), Color(12, 14, 18, 230), 5)
                Safe(Render.Rect, Vec2(bx, ty - 4), Vec2(bx + box_w, ty + t_size.y + (is_chan and 11 or 4)), circle_col, 5, nil, 1.2)

                Render.Text(font, 13, text, Vec2(tx + 1, ty + 1), Color(0, 0, 0, 240))
                Render.Text(font, 13, text, Vec2(tx, ty), is_chan and Color(255, 215, 60, 255) or Color(255, 235, 120, 255))

                -- Cast progress bar (rounded glowing bar with lead pip)
                if is_chan then
                    local p_bar_y = ty + t_size.y + 3
                    local p_bar_w = box_w - 8
                    local p_bar_x = bx + 4
                    local progress = math.min(1.0, math.max(0.0, elapsed / 1.7))

                    Safe(Render.FilledRect, Vec2(p_bar_x, p_bar_y), Vec2(p_bar_x + p_bar_w, p_bar_y + 5), Color(22, 24, 30, 220), 2)
                    Safe(Render.Rect, Vec2(p_bar_x, p_bar_y), Vec2(p_bar_x + p_bar_w, p_bar_y + 5), Color(70, 60, 40, 180), 2, nil, 1.0)
                    if progress > 0 then
                        Safe(Render.FilledRect, Vec2(p_bar_x, p_bar_y), Vec2(p_bar_x + (p_bar_w * progress), p_bar_y + 5), Color(255, 175, 20, 255), 2)
                        Safe(Render.FilledCircle, Vec2(p_bar_x + (p_bar_w * progress), p_bar_y + 2.5), 3.2, Color(255, 235, 140, 255))
                    end
                end

                -- Индикатор высадки на внешний край купола (Feature #1)
                if State.is_edge_drop then
                    local d_label = (State.edge_drop_type == "black_hole") and "BLACK HOLE" or ((State.edge_drop_type == "winters_curse") and "WINTER'S CURSE" or "CHRONOSPHERE")
                    DrawBadge(font, 12, Loc("hud.edge_drop") .. d_label, csp.x, ty - 26, Color(18, 10, 24, 230), Color(255, 60, 60, 255), Color(255, 120, 120, 255), 8, 3)
                end
            end

            local my_pos = Safe(Entity.GetAbsOrigin, State.me)
            if my_pos then
                local me_sp, me_vis = Render.WorldToScreen(my_pos)
                if me_vis then
                    -- Shimmering silk laser beam connecting Dawnbreaker to landing zone
                    Safe(Render.Line, me_sp, csp, Alpha(circle_col, 45), 6.0)
                    Safe(Render.Line, me_sp, csp, circle_col, 2.2)
                    Safe(Render.Line, me_sp, csp, Color(255, 255, 255, 210), 1.0)

                    -- Animated traveling celestial energy bolt
                    local bolt_t = (now * 2.2) % 1.0
                    local bx = me_sp.x + (csp.x - me_sp.x) * bolt_t
                    local by = me_sp.y + (csp.y - me_sp.y) * bolt_t
                    Safe(Render.FilledCircle, Vec2(bx, by), 9, Alpha(circle_col, 70))
                    Safe(Render.FilledCircle, Vec2(bx, by), 4.5, Color(255, 220, 80, 240))
                    Safe(Render.FilledCircle, Vec2(bx, by), 2.0, Color(255, 255, 255, 255))
                end
            end
        else
            -- Точка вне экрана: рисуем радар-стрелку на краю экрана
            DrawOffscreenIndicator(landing_pos, is_channeling)
        end
    end
end

function Script.OnPrepareUnitOrders(data)
    if not State.me or not State.is_dawnbreaker then
        return true
    end

    -- Отслеживаем приказы применения ульты (как автоматические, так и ручные игроком)
    if data then
        local is_solar_order = false
        if data.ability then
            if data.ability == State.r_spell or Safe(Ability.GetName, data.ability) == ULT_NAME then
                is_solar_order = true
            end
        end

        if is_solar_order then
            State.channel_start_time = GameRules.GetGameTime()
            if data.order == Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION and data.position then
                State.landing_pos = data.position
            elseif data.order == Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TARGET and data.target then
                State.targeted_ally = data.target
                State.landing_pos = Safe(Entity.GetAbsOrigin, data.target)
            end

            -- Авто-BKB при ручном применении ультимейта игроком
            if UI.AutoBKBOnUlt and UI.AutoBKBOnUlt:Get() and not State.is_script_order then
                local enemies_near_me = CountEnemiesNearUnit(State.me, 850)
                if enemies_near_me > 0 then
                    local bkb = NPC.GetItem(State.me, "item_black_king_bar", true)
                    if bkb and CanCastSpell(bkb) then
                        Ability.CastNoTarget(bkb, false, false, true)
                    end
                end
            end
        end

        -- Если у Dawnbreaker есть Аганим и она смещает круг кликами перемещения во время ченнелинга
        if State.is_channeling and data.order == Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION and data.position then
            State.landing_pos = data.position
        end
    end

    if not UI.ready or not UI.BlockOrders or not UI.BlockOrders:Get() then
        return true
    end

    -- Не блокируем собственные приказы скрипта
    if State.is_script_order then
        return true
    end

    local me = State.me

    -- Проверяем, направлен ли приказ на Dawnbreaker
    local affects_me = false
    if data then
        if data.npc and data.npc == me then
            affects_me = true
        elseif not data.npc then
            local issuer = data.orderIssuer
            if not issuer or issuer == Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_HERO_ONLY
            or issuer == Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_SELECTED_UNITS then
                affects_me = true
            end
        end
    end

    if not affects_me then
        return true
    end

    -- Проверяем, идет ли сейчас ченнелинг Solar Guardian
    local is_channeling = Safe(NPC.HasModifier, me, MODIFIERS.r_channel)
        or (Safe(NPC.IsChannellingAbility, me) and State.r_spell and Safe(Ability.IsChannelling, State.r_spell))

    if not is_channeling then
        return true
    end

    -- Whitelist early land sub-ability
    if data and data.ability then
        local ab_name = Safe(Ability.GetName, data.ability)
        if ab_name == "dawnbreaker_land" then
            return true
        end
    end

    -- Проверяем процент здоровья Dawnbreaker
    local hp = Safe(Entity.GetHealth, me) or 1000
    local max_hp = Safe(Entity.GetMaxHealth, me) or 1000
    local hp_pct = (hp / max_hp) * 100

    local min_hp_thresh = UI.BlockOrdersMinHP and UI.BlockOrdersMinHP:Get() or 0

    -- Если HP выше или равно порогу — блокируем ордер игрока во избежание сбития ульты
    if hp_pct >= min_hp_thresh then
        -- Если у Dawnbreaker есть Аганим, клики перемещения управляют областью и не сбивают ульт
        local has_aghs = Safe(NPC.HasModifier, me, MODIFIERS.aghs)
        if has_aghs and data and (data.order == Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION or data.order == Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_TARGET) then
            return true -- Разрешаем ручное смещение круга с Аганимом
        end

        -- Все остальные приказы (Move без Аганима, Stop, Hold, Attack, Cast) сбивают ульту -> блокируем!
        return false
    end

    -- Если HP упало ниже порога — снимаем блокировку, игрок может прервать ульт и спастись
    return true
end

function Script.OnModifierCreate(entity, modifier)
    if not State.me or not State.is_dawnbreaker then return end
    local mod_name = Safe(Modifier.GetName, modifier)
    if not mod_name then return end

    if mod_name == MODIFIERS.r_channel and entity == State.me then
        State.is_channeling = true
        if not State.channel_start_time or (GameRules.GetGameTime() - State.channel_start_time > 0.4) then
            State.channel_start_time = GameRules.GetGameTime()
        end
    elseif mod_name == MODIFIERS.thinker then
        local caster = Safe(Modifier.GetCaster, modifier)
        if not caster or caster == State.me or (State.is_channeling and Safe(Entity.IsSameTeam, State.me, entity)) then
            State.landing_thinker = entity
            local t_pos = Safe(Entity.GetAbsOrigin, entity)
            if t_pos then
                State.landing_pos = t_pos
            end
        end
    elseif mod_name == "modifier_faceless_void_chronosphere" then
        local now = GameRules.GetGameTime()
        local pos = Safe(Entity.GetAbsOrigin, entity)
        local idx = Safe(Entity.GetIndex, entity) or tostring(entity)
        if pos then
            State.active_danger_aoes[idx] = { type = "chrono", radius = 500, pos = Vector(pos.x, pos.y, pos.z), expire = now + 6.0 }
        end
    elseif mod_name == "modifier_enigma_black_hole" then
        -- Only treat ENEMY Black Hole as danger zone! Allied Black Hole is safe for Dawnbreaker.
        if entity and not Safe(Entity.IsSameTeam, State.me, entity) then
            local now = GameRules.GetGameTime()
            local pos = Safe(Entity.GetAbsOrigin, entity)
            local idx = Safe(Entity.GetIndex, entity) or tostring(entity)
            if pos then
                State.active_danger_aoes[idx] = { type = "black_hole", radius = 420, pos = Vector(pos.x, pos.y, pos.z), expire = now + 4.5 }
            end
        end
    end
end

function Script.OnModifierDestroy(entity, modifier)
    if not State.me or not State.is_dawnbreaker then return end
    local mod_name = Safe(Modifier.GetName, modifier)
    if not mod_name then return end

    if mod_name == MODIFIERS.r_channel and entity == State.me then
        State.is_channeling = false
        State.landing_pos = nil
        State.landing_thinker = nil
        State.targeted_ally = nil
        State.is_edge_drop = false
        State.edge_drop_type = nil
    elseif mod_name == MODIFIERS.thinker then
        if entity == State.landing_thinker then
            State.landing_thinker = nil
        end
    elseif mod_name == "modifier_faceless_void_chronosphere" or mod_name == "modifier_enigma_black_hole" then
        local idx = Safe(Entity.GetIndex, entity) or tostring(entity)
        if State.active_danger_aoes and State.active_danger_aoes[idx] then
            State.active_danger_aoes[idx] = nil
        end
    end
end

function Script.OnGameEnd()
    State.endangered_ally = nil
    State.targeted_ally = nil
    State.highest_threat_score = 0
    State.ally_tracking = {}
    State.is_script_order = false
    State.last_blacklist_sync = 0
    State.is_channeling = false
    State.channel_start_time = 0
    State.landing_pos = nil
    State.landing_thinker = nil
    State.last_minimap_draw_time = 0
    State.teamfight_cast_pos = nil
    State.is_teamfight_target = false
    State.last_aghs_reposition_time = 0
    State.active_danger_aoes = {}
    State.is_edge_drop = false
    State.edge_drop_type = nil
    State.last_icon_ping = 0
    State.blacklist_populated = false
    State.last_minimap_flight_send = 0
end

return Script
