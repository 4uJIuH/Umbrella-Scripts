-- Fallback jungle spots data if LIB_HEROES_DATA is not available
local FALLBACK_JUNGLE_SPOTS = {
  -- Radiant jungle camps (patch 7.40, provided by user)
  {pos = Vector(-4014.1, 1052.4, 256.0), team = 2, type = 2, index = 1},
  {pos = Vector(-5102.7, -105.4, 256.0), team = 2, type = 4, index = 2},
  {pos = Vector(-7990.0, -1738.2, 256.0), team = 2, type = 1, index = 3},
  {pos = Vector(-8367.4, -576.9, 256.0), team = 2, type = 3, index = 4},
  {pos = Vector(-812.2, -7538.8, 134.0), team = 2, type = 2, index = 5},
  {pos = Vector(-2341.2, -8374.5, 128.0), team = 2, type = 2, index = 6},
  {pos = Vector(2673.2, -8345.6, 0.0), team = 2, type = 1, index = 7},
  {pos = Vector(4332.1, -8247.1, 3.3), team = 2, type = 2, index = 8},
  {pos = Vector(4084.7, -5187.9, 128.0), team = 2, type = 1, index = 9},
  {pos = Vector(4615.0, -3720.0, 128.0), team = 2, type = 3, index = 10},
  {pos = Vector(-1509.0, -3546.8, 128.0), team = 2, type = 3, index = 21},
  {pos = Vector(-1938.0, -4755.7, 128.0), team = 2, type = 2, index = 22},

  -- Dire jungle camps (patch 7.40, provided by user)
  {pos = Vector(4232.1, 39.8, 256.0), team = 3, type = 4, index = 11},
  {pos = Vector(3327.2, -1333.3, 256.0), team = 3, type = 2, index = 12},
  {pos = Vector(8463.4, 1304.0, 256.0), team = 3, type = 1, index = 13},
  {pos = Vector(7899.2, -114.0, 256.0), team = 3, type = 3, index = 14},
  {pos = Vector(1064.9, 2566.2, 128.0), team = 3, type = 3, index = 15},
  {pos = Vector(1309.2, 4235.9, 128.0), team = 3, type = 2, index = 16},
  {pos = Vector(-4723.6, 8215.5, 0.0), team = 3, type = 2, index = 17},
  {pos = Vector(-3367.3, 7484.8, 0.0), team = 3, type = 1, index = 18},
  {pos = Vector(-4061.7, 4912.9, 128.0), team = 3, type = 1, index = 19},
  {pos = Vector(-4863.8, 4020.4, 128.0), team = 3, type = 3, index = 20},
}

local IniConfig = Config

-- ── Custom camps + camp mirror ──────────────────────────────
local CUSTOM_CAMP_BASE_INDEX = 1000
local CustomJungleSpots = {}

local function LoadCustomCamps()
    CustomJungleSpots = {}
    local count = IniConfig.ReadInt("tinker_custom_camps", "count", 0)
    for i = 1, count do
        local x     = IniConfig.ReadInt("tinker_custom_camps", "c" .. i .. "_x", 0)
        local y     = IniConfig.ReadInt("tinker_custom_camps", "c" .. i .. "_y", 0)
        local z     = IniConfig.ReadInt("tinker_custom_camps", "c" .. i .. "_z", 0)
        local team  = IniConfig.ReadInt("tinker_custom_camps", "c" .. i .. "_team", 2)
        local ctype = IniConfig.ReadInt("tinker_custom_camps", "c" .. i .. "_type", 2)
        local idx   = IniConfig.ReadInt("tinker_custom_camps", "c" .. i .. "_index", CUSTOM_CAMP_BASE_INDEX + i)
        table.insert(CustomJungleSpots, {
            pos = Vector(x, y, z), team = team, type = ctype, index = idx, custom = true
        })
    end
end

pcall(LoadCustomCamps)

-- Camp mirror: Radiant <-> Dire auto-switch on team change.
local CAMP_MIRROR_PAIRS = {
    {1, 12}, {2, 11}, {21, 15}, {22, 16}, {5, 1001}, {6, 1002},
    {3, 13}, {9, 19}, {10, 20}, {7, 18}, {8, 17}, {4, 1003},
}

local MAP_URL = "https://raw.githubusercontent.com/coderx756/map/main/menu4.jpg"

local ABILITY_INDEX   = 2
local DOUBLE_TAP_TIME = 0.4
local HERO_NAME       = "npc_dota_hero_tinker"
local BOOST_DISTANCE  = 150

local lastTapTime   = 0
local showIndicator = false
-- ============================================================
-- CAMP SELECTION PATCH
-- Place this block AFTER the FALLBACK_JUNGLE_SPOTS table and
-- AFTER the translation/L() system is defined.
-- Then REPLACE the existing GetJungleSpots() function below.
-- ============================================================



-- Fallback Camp functions if not available
if not Camp then
  Camp = {}
end
if not Camp.GetGoldBounty then
  function Camp.GetGoldBounty(camp, useBounty)
    local gold = 0
    if camp.type == 1 then -- Small camp
      gold = useBounty and 71 or 43
    elseif camp.type == 2 then -- Medium camp
      gold = useBounty and 94 or 56
    elseif camp.type == 3 then -- Large camp
      gold = useBounty and 119 or 71
    elseif camp.type == 4 then -- Ancient camp
      gold = useBounty and 162 or 97
    end
    return gold
  end
end

local script        = {}
local translation   = {
  en = {
    root = "Tinker Helper",

    menu_general = "AutoFarm",
    autofarm_switch = "AutoFarm",
    menu_utilities = "Utilities",
    menu_debug = "Visual Debug",
    toggle_key = "Toggle Key",
    farm_targets = "Farming Targets",
    target_ancients = "Ancient Camps",
    target_non_ancients = "Non‑Ancients",
    target_lane = "Lane Creeps",

    items_to_use = "Usable Items",
    item_bottle = "Bottle",
    item_blink = "Blink Dagger",
    item_shivas_guard = "Shiva's Guard",
    item_dagon = "Dagon",
    item_meteor_hammer = "Meteor Hammer",

    auto_deploy_turrets = "Deploy Turrets (Double‑Tap)",
    camera_follow = "Camera Follow",
    wisdom_rune = "Wisdom Shrine (Rune)",
    auto_glimmer = "Auto-Glimmer",
    gear_auto_glimmer = "Glimmer Options",
    auto_glimmer_enable = "Enable",
    auto_glimmer_rearm = "Use during Rearm",
    auto_glimmer_blink = "Use after Blink",

    prefer_bounty = "Prioritize High‑Gold Camps",

    blink_options_label = "Blink Settings",
    gear_blink_behavior = "Blink Behavior",
    blink_travel = "Use for Traveling",
    blink_escape = "Use for Escaping",
    blink_hold_after_rearm = "Delay after Rearm",
    blink_hold_tp_lock = "Hold during TP Lock",

    lane_logic_label = "Lane Logic",
    gear_lane_logic = "Lane Logic Settings",
    lane_blink_tp_after_clear = "Blink TP after clearing creeps",
    lane_no_tp_near_tower = "Don't TP if enemy tower nearby",
    lane_blink_tp_near_enemy = "Blink TP if enemy hero nearby",
    lane_safety = "Lane Safety",
    gear_lane_safety = "Safety Mode",
    lane_safety_unsafe = "Unsafe Farm",
    lane_safety_safe = "Safe Farm",
    lane_safety_ultra = "Ultra Safe Farm",

    turret_dodge = "Turret Dodge",
    gear_turret_dodge = "Dodge Settings",
    turret_dodge_enable = "Enable",
    turret_dodge_interrupt = "Interrupt movement",
    turret_dodge_heroes = "Dodge Blink from",
    turret_dodge_invis_safe = "Don't cast in invisibility",
    turret_dodge_melee = "Melee attack protection",
    turret_dodge_melee_minute = "Melee protection from minute",

    bottle_options_label = "Bottle Settings",
    gear_bottle_behavior = "Bottle Behavior",
    bottle_use_hp = "Use when Low HP",
    bottle_use_mana = "Use when Low Mana",

    marching_control_label = "March Control",
    gear_controls = "Controls",
    march_use_custom = "Custom March Counts per Camp",
    march_small = "Small Camps",
    march_medium = "Medium Camps",
    march_large = "Large Camps",
    march_ancient = "Ancient Camps",
    march_count_fmt = "%d Marches",
    march_lane_pack1 = "Lane: 1 Pack",
    march_lane_pack2 = "Lane: 2+ Packs",

    status_overlay = "Show Status Overlay",
    gear_overlay_options = "Overlay Settings",
    status_lock = "Lock Position (disable dragging)",
    status_show_autofarm = "Show AutoFarm",
    status_show_autoglimmer = "Show AutoGlimmer",

    debug_overlay = "Enable Debug Overlay",
    debug_world = "Draw World Guides",
    gear_world_options = "World Settings",
    debug_show_order_throttle = "Show Order Rate",
    debug_show_spot_metrics = "Show Camp Metrics",
    debug_pretty_map = "Use Polished Map Drawing",
    debug_bounty = "Show Gold on Map/Overlay",

    tooltip_autofarm =
    "Autofarm is still in development (enemies may catch you).\nRecommended once March of the Machines is Level 4 and Rearm is Level 1."
  },
  ru = {
    root = "Tinker Helper",

    menu_general = "АвтоФарм",
    autofarm_switch = "Автофарм",
    menu_utilities = "Утилиты",
    menu_debug = "Визуал",
    toggle_key = "Клавиша включения",
    farm_targets = "Цели фарма",
    target_ancients = "Древние лагеря",
    target_non_ancients = "Обычные лагеря",
    target_lane = "Крипы на линии",

    items_to_use = "Использовать",
    item_bottle = "Боттл",
    item_blink = "Блинк‑даггер",
    item_meteor_hammer = "Метеор Хаммер",

    auto_deploy_turrets = "Deploy Turrets (двойное нажатие)",
    camera_follow = "Следование камеры",
    wisdom_rune = "Алтарь мудрости (руна)",
    auto_glimmer = "Auto-Glimmer",
    gear_auto_glimmer = "Настройки Глиммера",
    auto_glimmer_enable = "Включить",
    auto_glimmer_rearm = "Использовать при Реарме",
    auto_glimmer_blink = "Использовать при блинке",

    prefer_bounty = "Предпочитать более выгодные кемпы",

    blink_options_label = "Настройки Блинка",
    gear_blink_behavior = "Поведение Блинка",
    blink_travel = "Использовать для перемещения",
    blink_escape = "Использовать при побеге",
    blink_hold_after_rearm = "Задержка после Rearm",
    blink_hold_tp_lock = "Блокировать при ТП‑локе",

    lane_logic_label = "Логика линии",
    gear_lane_logic = "Настройки логики линии",
    lane_blink_tp_after_clear = "После зачистки лайновых крипов блинк ТП",
    lane_no_tp_near_tower = "Не телепортироваться если рядом вражеская вышка",
    lane_blink_tp_near_enemy = "Блинк ТП если рядом вражеский герой",
    lane_safety = "Безопасность линии",
    gear_lane_safety = "Режим безопасности",
    lane_safety_unsafe = "Небезопасный фарм",
    lane_safety_safe = "Безопасный фарм",
    lane_safety_ultra = "Ультрабезопасный фарм",

    turret_dodge = "Додж турелями",
    gear_turret_dodge = "Настройки доджа",
    turret_dodge_enable = "Включить",
    turret_dodge_interrupt = "Сбивать передвижение",
    turret_dodge_heroes = "Доджить Blink от",
    turret_dodge_invis_safe = "Не кастовать в инвизе",
    turret_dodge_melee = "Защита от атак мили-героев",
    turret_dodge_melee_minute = "Защита от мили с минуты",

    bottle_options_label = "Настройки Ботла",
    gear_bottle_behavior = "Поведение Ботла",
    bottle_use_hp = "Использовать для лечения HP",
    bottle_use_mana = "Использовать для восстановления маны",

    marching_control_label = "Настройки March",
    gear_controls = "Контроль",
    march_use_custom = "Своё количество для каждого лагеря",
    march_small = "Маленькие лагеря",
    march_medium = "Средние лагеря",
    march_large = "Большие лагеря",
    march_ancient = "Древние лагеря",
    march_count_fmt = "%d каста",
    march_lane_pack1 = "Линия: 1 пачка",
    march_lane_pack2 = "Линия: 2+ пачки",

    status_overlay = "Показывать оверлей статуса",
    gear_overlay_options = "Настройки оверлея",
    status_lock = "Зафиксировать позицию (запрещает двигать)",
    status_show_autofarm = "Показывать AutoFarm",
    status_show_autoglimmer = "Показывать AutoGlimmer",

    debug_overlay = "Включить оверлей отладки",
    debug_world = "Рисовать информацию в мире",
    gear_world_options = "Настройки мира",
    debug_show_order_throttle = "Показывать частоту команд",
    debug_show_spot_metrics = "Показывать метрики лагерей",
    debug_pretty_map = "Красивое оформление карты",
    debug_bounty = "Показывать золото на карте/оверлее",

    tooltip_autofarm =
    "Скрипт всё ещё в разработке (враги могут поймать).\nРекомендуется включать при March of the Machines 4 уровня и Rearm 1 уровня."
  }
}

local __lang_cached = nil
local function __lang_index()
  if __lang_cached ~= nil then return __lang_cached end
  local d = Menu.Find("SettingsHidden", "", "", "", "Main", "Language")
  local v = d and d:Get() or 0
  if v ~= 0 and v ~= 1 then v = 0 end
  __lang_cached = v
  return v
end

local function __lang_code()
  return __lang_index() == 1 and "ru" or "en"
end

function L(key)
  local code = __lang_code()
  return (translation[code] and translation[code][key]) or (translation.en and translation.en[key]) or tostring(key)
end

do
  local d = Menu.Find("SettingsHidden", "", "", "", "Main", "Language")
  if d and d.SetCallback then
    local prev = d:Get()
    d:SetCallback(function(ctrl)
      local cur = (ctrl and ctrl.Get and ctrl:Get()) or d:Get()
      if cur ~= prev then
        prev = cur
        Engine.ReloadScriptSystem()
      end
    end)
  end
end

local autoFarmMenu = Menu.Create("Heroes", "Hero List", "Tinker", L("root"), L("menu_general"))
local utilityMenu  = Menu.Create("Heroes", "Hero List", "Tinker", L("root"), L("menu_utilities"))
local debugMenu    = Menu.Create("Heroes", "Hero List", "Tinker", L("root"), L("menu_debug"))
Config             = {
  AutoFarmSwitch = autoFarmMenu:Switch(L("autofarm_switch"), false, "\u{f11c}"),
  AutoFarm = autoFarmMenu:Bind(L("toggle_key"), Enum.ButtonCode.BUTTON_CODE_NONE, "\u{f11c}"),
  ToFarm = autoFarmMenu:MultiCombo(L("farm_targets"), {
    L("target_ancients"), L("target_non_ancients"), L("target_lane")
  }, { L("target_ancients"), L("target_non_ancients") }),
  ItemsToUse = utilityMenu:MultiSelect(L("items_to_use"), {
    { L("item_bottle"), "panorama/images/items/bottle_png.vtex_c", true },
    { L("item_blink"),  "panorama/images/items/blink_png.vtex_c",  true },
    { L("item_shivas_guard"), "panorama/images/items/shivas_guard_png.vtex_c", true },
    { L("item_meteor_hammer"),  "panorama/images/items/meteor_hammer_png.vtex_c",   false },
    { L("item_dagon"), "panorama/images/items/dagon_png.vtex_c", false }
  }, true),
  AutoMatrix = utilityMenu:Switch(L("auto_deploy_turrets"), true,
    "panorama/images/spellicons/tinker_deploy_turrets_png.vtex_c"),
  Matrix = {},
  CameraFollow = autoFarmMenu:Switch(L("camera_follow"), false, "\u{f030}"),
  AutoGlimmer = utilityMenu:Switch(L("auto_glimmer"), true, "panorama/images/items/glimmer_cape_png.vtex_c"),
  AutoGlimmerKey = utilityMenu:Bind(L("toggle_key"), Enum.ButtonCode.BUTTON_CODE_NONE, "\u{f0c1}"),
  AutoGlimmerOptions = {},
  -- Always prefer high-gold camps (fixed, no widget).
  PreferBounty = { Get = function() return true end },
  WisdomRune = autoFarmMenu:Switch(L("wisdom_rune"), true, "\u{f005}"),
  BlinkGroup = utilityMenu:Label(L("blink_options_label"), "panorama/images/items/blink_png.vtex_c"),
  Blink = {},
  LaneGroup = autoFarmMenu:Label(L("lane_logic_label"), "panorama/images/spellicons/tinker_laser_png.vtex_c"),
  LaneSafetyGroup = autoFarmMenu:Label(L("lane_safety"), "\u{f132}"),
  -- Old lane tuning is now fixed (non-editable); only our stub toggles are exposed.
  Lane = {
    Advanced           = { Get = function() return true end },
    TreeBlinkApproach  = { Get = function() return true end },
    TreeBlinkRetreat   = { Get = function() return true end },
    UseLaser           = { Get = function() return true end },
    RotateAfterClear   = { Get = function() return true end },
    DynamicMixPriority = { Get = function() return true end },
    MarchesPerWave     = { Get = function() return 1 end },
  },
  LaneExtras = {},
  MarchControl = {},
  StatusOverlay = debugMenu:Switch(L("status_overlay"), true, "\u{f2d2}"),
  Status = {},
  Debug = {
    Overlay = debugMenu:Switch(L("debug_overlay"), false, "\u{f108}"),
    World   = debugMenu:Switch(L("debug_world"), false, "\u{f279}"),
  }
}

Config.AutoFarm:ToolTip(L("tooltip_autofarm"))

do
  -- Deploy Turrets double-tap is toggled via Config.AutoMatrix (no sub-options needed)

  -- Keep the AutoFarm menu switch in sync with the toggle-key bind.
  Config.AutoFarmSwitch:SetCallback(function(sw)
    if sw:Get() ~= Config.AutoFarm:IsToggled() then
      Config.AutoFarm:SetToggled(sw:Get())
    end
  end)

  -- Auto-Glimmer options.
  local agg = Config.AutoGlimmer:Gear(L("gear_auto_glimmer"))
  Config.AutoGlimmerOptions.OnRearm = agg:Switch(L("auto_glimmer_rearm"), true, "\u{f021}")
  Config.AutoGlimmerOptions.OnBlink = agg:Switch(L("auto_glimmer_blink"), false, "\u{f48b}")
  Config.AutoGlimmer:SetCallback(function(sw)
    if sw:Get() ~= Config.AutoGlimmerKey:IsToggled() then
      Config.AutoGlimmerKey:SetToggled(sw:Get())
    end
  end)

  local sg                        = Config.StatusOverlay:Gear(L("gear_overlay_options"))
  Config.Status.Lock              = sg:Switch(L("status_lock"), true, "\u{f023}")
  Config.Status.ShowAutoFarm      = sg:Switch(L("status_show_autofarm"), true, "\u{f11c}")
  Config.Status.ShowAutoGlimmer   = sg:Switch(L("status_show_autoglimmer"), true, "panorama/images/items/glimmer_cape_png.vtex_c")

  local overlayGear               = Config.Debug.Overlay:Gear(L("gear_overlay_options"))
  Config.Debug.Orders             = overlayGear:Switch(L("debug_show_order_throttle"), false, "\u{f0ae}")
  Config.Debug.Spot               = overlayGear:Switch(L("debug_show_spot_metrics"), true, "\u{f080}")

  local worldGear                 = Config.Debug.World:Gear(L("gear_world_options"))
  Config.Debug.Pretty             = worldGear:Switch(L("debug_pretty_map"), true, "\u{f5a0}")
  Config.Debug.Bounty             = worldGear:Switch(L("debug_bounty"), true, "\u{f51e}")

  local m                         = autoFarmMenu:Label(L("marching_control_label"), "\u{f0c9}"):Gear(L("gear_controls"))
  Config.MarchControl.UseCustom   = m:Switch(L("march_use_custom"), true, "\u{f013}")
  Config.MarchControl.Small       = m:Slider(L("march_small"), 1, 5, 2, L("march_count_fmt"))
  Config.MarchControl.Medium      = m:Slider(L("march_medium"), 1, 5, 3, L("march_count_fmt"))
  Config.MarchControl.Large       = m:Slider(L("march_large"), 1, 5, 3, L("march_count_fmt"))
  Config.MarchControl.Ancient     = m:Slider(L("march_ancient"), 1, 5, 4, L("march_count_fmt"))
  Config.MarchControl.LanePack1   = m:Slider(L("march_lane_pack1"), 1, 5, 1, L("march_count_fmt"))
  Config.MarchControl.LanePack2   = m:Slider(L("march_lane_pack2"), 1, 5, 2, L("march_count_fmt"))

  local bg                        = Config.BlinkGroup:Gear(L("gear_blink_behavior"))
  Config.Blink.Travel             = bg:Switch(L("blink_travel"), true, "\u{f70c}")
  Config.Blink.Escape             = bg:Switch(L("blink_escape"), true, "\u{f2f5}")
  Config.Blink.HoldAfterRearm     = bg:Switch(L("blink_hold_after_rearm"), true, "\u{f017}")
  Config.Blink.HoldTPLock         = bg:Switch(L("blink_hold_tp_lock"), true, "\u{f023}")
  Config.Blink.PostTPLockTime     = bg:Slider("Post-TP Blink Lock (s)", 0, 40, 15, "%.1fs")
  Config.Blink.MinDistance        = bg:Slider("Min Blink Distance", 0, 800, 250, "%d units")
  Config.Blink.SafeStandoff       = bg:Slider("Blink Standoff", 0, 400, 100, "%d units")
  Config.Blink.HoldAfterRearmTime = bg:Slider("Hold After Rearm (s)", 0, 20, 2, "%.1fs")
  Config.Blink.NoRearmAfterTP     = bg:Slider("No Rearm After TP (s)", 0, 30, 8, "%.1fs")

  local lg                        = Config.LaneGroup:Gear(L("gear_lane_logic"))
  -- Stub toggles (GUI only, no logic).
  Config.LaneExtras.BlinkTpAfterClear   = lg:Switch(L("lane_blink_tp_after_clear"), false, "\u{f5aa}")
  Config.LaneExtras.NoTpNearEnemyTower  = lg:Switch(L("lane_no_tp_near_tower"), false, "\u{f071}")
  Config.LaneExtras.BlinkTpNearEnemy    = lg:Switch(L("lane_blink_tp_near_enemy"), false, "\u{f071}")

  -- Lane Safety (stub, separate setting): only one mode can be ON at a time.
  local lsg = Config.LaneSafetyGroup:Gear(L("gear_lane_safety"))
  Config.LaneSafety = {
    Unsafe    = lsg:Switch(L("lane_safety_unsafe"), false, "\u{f071}"),
    Safe      = lsg:Switch(L("lane_safety_safe"),   false, "\u{f132}"),
    UltraSafe = lsg:Switch(L("lane_safety_ultra"),  false, "\u{f3ed}"),
  }
  local syncingSafety = false
  local function SyncLaneSafety()
    if syncingSafety then return end
    syncingSafety = true
    local active = nil
    for _, w in pairs(Config.LaneSafety) do
      if w:Get() then active = w; break end
    end
    if active then
      for _, w in pairs(Config.LaneSafety) do
        if w ~= active then w:Set(false) end
      end
    end
    syncingSafety = false
  end
  for _, w in pairs(Config.LaneSafety) do
    w:SetCallback(SyncLaneSafety)
  end

  -- ── Turret Dodge ("Додж турелями") ──
  Config.TurretDodge = {}
  local tdGroup = utilityMenu:Label(L("turret_dodge"), "\u{f0e7}")
  local tdGear  = tdGroup:Gear(L("gear_turret_dodge"))
  Config.TurretDodge.Enabled   = tdGear:Switch(L("turret_dodge_enable"), true, "\u{f00c}")
  Config.TurretDodge.Interrupt = tdGear:Switch(L("turret_dodge_interrupt"), true, "\u{f05e}")
  Config.TurretDodge.InvisSafe = tdGear:Switch(L("turret_dodge_invis_safe"), true, "\u{f070}")
  Config.TurretDodge.MeleeProtect = tdGear:Switch(L("turret_dodge_melee"), true, "\u{f05b}")
  Config.TurretDodge.MeleeMinute  = tdGear:Slider(L("turret_dodge_melee_minute"), 0, 60, 0, "%d")
  Config.TurretDodge.Heroes    = tdGear:MultiSelect(L("turret_dodge_heroes"), {}, false)

end

-- ── 1.  Camp-selection menu group ───────────────────────────
local campSelectMenu = Menu.Create(
    "Heroes", "Hero List", "Tinker", L("root"), "Camp Selection"
)

-- Type / team display names (used for the switch label)
local _CAMP_TYPE_LABEL  = { [1] = "Small", [2] = "Medium", [3] = "Large", [4] = "Ancient" }
local _CAMP_TEAM_LABEL  = { [2] = "Radiant", [3] = "Dire" }
local _CAMP_TYPE_ICON   = {
    [1] = "\u{f111}",   -- circle  (small)
    [2] = "\u{f0c8}",   -- square  (medium)
    [3] = "\u{f5a0}",   -- gem     (large)
    [4] = "\u{f6ff}",   -- dragon  (ancient)
}

-- Build one Switch per camp – all enabled by default.
-- Key = camp.index (integer, 1-20 for the hard-coded spots).
local CampSwitches = {}

for _, camp in ipairs(FALLBACK_JUNGLE_SPOTS) do
    CampSwitches[camp.index] = IniConfig.ReadInt("tinker_camps", "camp_" .. camp.index, 1) == 1
end
for _, camp in ipairs(CustomJungleSpots) do
    CampSwitches[camp.index] = IniConfig.ReadInt("tinker_camps", "camp_" .. camp.index, 1) == 1
end

local function ReadCampSwitch(index)
    return IniConfig.ReadInt("tinker_camps", "camp_" .. index, 1) == 1
end

-- On joining a team, mirror the previously played team's selection onto the current one.
local function ApplyCampSelection(team, prevTeam)
    if team ~= 2 and team ~= 3 then return end
    for _, p in ipairs(CAMP_MIRROR_PAIRS) do
        local r, d = p[1], p[2]
        if prevTeam == 2 and team == 3 then
            local v = ReadCampSwitch(r)
            IniConfig.WriteInt("tinker_camps", "camp_" .. d, v and 1 or 0)
        elseif prevTeam == 3 and team == 2 then
            local v = ReadCampSwitch(d)
            IniConfig.WriteInt("tinker_camps", "camp_" .. r, v and 1 or 0)
        end
        local curIdx   = (team == 3) and d or r
        local otherIdx = (team == 3) and r or d
        CampSwitches[curIdx]   = ReadCampSwitch(curIdx)
        CampSwitches[otherIdx] = false
    end
end

local LastCampTeam = nil
local function UpdateCampMirrorForTeam(team)
    if team ~= 2 and team ~= 3 then return end
    if team == LastCampTeam then return end
    local prev = LastCampTeam
    if prev == nil then
        local stored = IniConfig.ReadInt("tinker_camps", "last_team", 0)
        if stored == 2 or stored == 3 then prev = stored end
    end
    LastCampTeam = team
    ApplyCampSelection(team, prev)
    IniConfig.WriteInt("tinker_camps", "last_team", team)
end



Config.ShowCampMap = campSelectMenu:Switch("Show Camp Map", false, "\u{f279}")
Config.ShowCampMapKey = campSelectMenu:Bind("Camp Map Toggle Key", Enum.ButtonCode.BUTTON_CODE_NONE, "\u{f279}")

-- ── 3.  REPLACE the existing GetJungleSpots() with this ─────
--
-- Original was:
--   local function GetJungleSpots()
--     if LIB_HEROES_DATA and LIB_HEROES_DATA.jungle_spots then
--       return LIB_HEROES_DATA.jungle_spots
--     end
--     return FALLBACK_JUNGLE_SPOTS
--   end
--
-- New version filters by your per-camp switches:

local function GetJungleSpots()
    local base
    if LIB_HEROES_DATA and LIB_HEROES_DATA.jungle_spots then
        base = LIB_HEROES_DATA.jungle_spots
    else
        base = FALLBACK_JUNGLE_SPOTS
    end

    -- Always include user-added camps, even when LIB_HEROES_DATA is present.
    local merged = {}
    for _, camp in ipairs(base) do table.insert(merged, camp) end
    for _, camp in ipairs(CustomJungleSpots) do table.insert(merged, camp) end

    -- If CampSwitches hasn't been populated yet (shouldn't happen, but safe guard)
    if not next(CampSwitches) then return merged end

    local filtered = {}
    for _, camp in ipairs(merged) do
        local sw = CampSwitches[camp.index]
        -- If no switch exists for this index (e.g. LIB_HEROES_DATA has extra camps),
        -- allow it through so we don't silently block unknown camps.
        if (sw == nil) or sw then
            table.insert(filtered, camp)
        end
    end
    return filtered
end
-- ============================================================
-- END OF PATCH – nothing else needs changing.
-- ============================================================

local function SyncMarchSlidersDisabled()
  local useCustom = Config.MarchControl.UseCustom:Get()
  Config.MarchControl.Small:Disabled(not useCustom)
  Config.MarchControl.Medium:Disabled(not useCustom)
  Config.MarchControl.Large:Disabled(not useCustom)
  Config.MarchControl.Ancient:Disabled(not useCustom)
end
Constants = {
  MARCH_CAST_RANGE              = 900,
  MARCH_PAIR_COVERAGE_FRAC      = 1.1,
  TP_MIN_DISTANCE               = 2000,
  BLINK_CAST_RANGE              = 1190,
  BLINK_MAX_RANGE               = 1200,
  POST_TP_LOCK_TIME             = 3.8,
  NO_REARM_AFTER_TP             = 1.6,
  SAME_SPOT_TP_EPS              = 800,
  SAME_SPOT_TP_COOLDOWN         = 7.5,
  BLINK_HOLD_AFTER_REARM        = 0.6,
  BLINK_HOLD_BEFORE_TP          = 0.6,
  REARM_HOLD_ARM_FALLBACK       = 0.15,
  BLINK_SAFE_STANDOFF           = 220,
  BLINK_MIN_DISTANCE            = 450,
  ORDER_COOLDOWN                = 0.02,
  ORDERS_PER_UPDATE             = 1,
  MOVE_RESEND_INTERVAL          = 0.25,
  MOVE_POS_EPS                  = 72,
  ABILITY_DEDUP_INTERVAL        = 0.18,
  CAST_POS_EPS                  = 48,
  BOTTLE_CHECK_COOLDOWN         = 0.1,
  BOTTLE_MISSING_THRESHOLD      = 50,
  FOUNTAIN_MIN_MANA_FRAC        = 0.5,
  -- Updated for patch 7.40 (user-provided Radiant pos).
  -- Team 2 = Radiant, Team 3 = Dire.
  FOUNTAIN_RADIANT              = Vector(-7250.5, -6733.7, 390.6),
  FOUNTAIN_DIRE                 = Vector(6752.5625, 6281.28125, 384.0),
  SPOT_SCAN_INTERVAL            = 0.35,
  CAMP_CLEAR_DELAY              = 0.8,
  CAMP_CLEAR_CONFIRM_DELAY      = 2,
  CAMP_ALIVE_SCAN_RADIUS        = 900,
  CAMP_ALIVE_SCAN_RADIUS_ANCIENT = 1200,
  CAMP_ALIVE_SCAN_CACHE_TTL     = 0.10,
  NEUTRAL_SNAPSHOT_CACHE_TTL    = 0.10,
  LANE_CREEP_SNAPSHOT_CACHE_TTL = 0.10,
  LANE_CLUSTER_SEED_RADIUS      = 900,
  LANE_TRACK_RADIUS             = 1000,
  LANE_REACQUIRE_RADIUS         = 1800,
  LANE_MIN_CREEPS               = 2,
  LANE_ENEMY_TOWER_BLOCK_RADIUS = 1100,
  LANE_SCORE_PER_CREEP          = 2.0,
  LANE_SCORE_PER_SIEGE          = 1.0,
  LANE_POS_BUCKET               = 320,
  LANE_TREE_NEARBY_RADIUS       = 140,
  LANE_TREE_MIN_WAVE_DIST       = 420,
  LANE_TREE_MAX_WAVE_DIST       = 900,
  LANE_TREE_CANDIDATE_RINGS     = { 460, 600, 760, 880 },
  LANE_TREE_CANDIDATE_ANGLE_STEP = 20,
  LANE_TREE_CACHE_TTL           = 0.20,
  LANE_RETREAT_TREE_SEARCH_RADIUS = 1100,
  LANE_BURST_GAP                = 0.10,
  LANE_ROTATE_MIN_CREEPS_LEFT   = 1,
  LANE_ROTATE_BYPASS_IDLE_DELAY = true,
  LANE_DYNAMIC_SCORE_BIAS       = 1.5,
  LANE_LASER_MIN_VALUE_CREEPS   = 3,
  LANE_DAGON_USE_MAX_CREEPS     = 2,
  LANE_DAGON_MIN_ROTATE_MANA_BUFFER = 35,
  LANE_SPOT_RESELECT_COOLDOWN   = 2.0,
  MARCH_MIN_RECAST_GAP          = 0.6,
  REARM_MIN_GAP_AFTER_MARCH     = 0.35,
  HOLD_ACTIONS_DURING_CONFIRM   = true,
  PANIC_HP_FRAC                 = 0.40,
  PANIC_COOLDOWN                = 1.5,
  PANIC_ARM_TIME                = 0.25,
  PANIC_MATRIX_COOLDOWN         = 1.0,
  SPOT_COMMIT_TIME              = 5.0,
  FARM_TP_MIN_INTERVAL          = 5.0,
  IDLE_DECISION_DELAY           = 0.6,
  BOUNTY_SCORE_FACTOR_HIGH      = 1.0,
  BOUNTY_SCORE_FACTOR_LOW       = 0.3,
  KEEN_LANDING_RADIUS_STRUCTURE = 800,
  KEEN_LANDING_RADIUS_OUTPOST   = 250,
  ENEMY_RISK_RADIUS             = 1400,
  ENEMY_RISK_PATH_STEP          = 550,
  ENEMY_RISK_W_SPOT             = 1.0,
  ENEMY_RISK_W_ANCHOR           = 1.0,
  ENEMY_RISK_W_PATH             = 1.4,
  ENEMY_RISK_WEIGHT             = 80.0,
  ENEMY_RISK_HARD_BLOCK         = 0.45,
  ENEMY_RISK_BLOCK_RADIUS       = 1000,
  PENDING_TP_MAX_AGE            = 2.5,
  MARCH_VERIFY_MAX_AGE          = 1.2,
  MARCH_VERIFY_COOLDOWN_EPS     = 0.01,
}
State = {
  Hero = nil,
  Player = nil,
  HeroTeam = nil,
  IsChanneling = false,
  Rearm = nil,
  March = nil,
  KeenTeleport = nil,
  Blink = nil,
  Laser = nil,
  Shiva = nil,
  Dagon = nil,
  Meteor = nil,

  FarmState = "IDLE",
  CurrentFarmSpot = nil,

  MatrixCastTime = 0,

  NextOrderTime = 0,
  OrdersThisUpdate = 0,
  NextBottleCheck = 0,

  LastMovePos = nil,
  LastMoveTime = 0,
  LastAbilityOrders = {},

  DebugFont = nil,
  LastOrderDebug = nil,
  OrderCounterStart = 0,
  OrdersSentThisSecond = 0,
  OrdersPerSec = 0,

  LastTeleportAt = 0,
  TeleportLockUntil = 0,
  MovingAfterTeleport = false,
  LastTeleportCastPos = nil,
  RecalcAfterTP = false,

  PendingTPPos = nil,
  PendingTPSince = 0,
  PendingTPForce = false,

  BlockTPThisSpot = false,
  LastSpotTelePos = nil,

  LastRearmAt = 0,
  RearmBlinkHoldPending = false,
  RearmBlinkChannelSeen = false,
  RearmBlinkHoldUntil = 0,
  LastSpotScan = 0,

  CachedBestSpot = nil,
  AfterMarchCheck = nil,
  CampAliveScanCache = {},
  NeutralSnapshot = { at = 0, list = {} },
  LaneCreepSnapshot = { at = 0, list = {} },
  SessionSig = nil,
  LastObservedGameTime = 0,
  LastNeutralRespawnMinute = nil,

  LastHP = 0,
  LastHPTime = 0,
  PanicCooldownUntil = 0,
  PanicArmingSince = nil,
  LastPanicMatrixAt = 0,
  PanicReason = nil,

  TargetSpotKey = nil,
  SpotCommitUntil = 0,
  LastFarmTPAt = 0,
  JustClearedSpotAt = 0,
  LastLaneBurstAt = 0,
  LastLaneRetreatBlinkAt = 0,
  PendingLaneRotate = false,
  LastLaneSpotKey = nil,
  LaneTreeBlinkCache = {},
  LastLaneTreeSearchAt = 0,
  LaneBurstTargets = {},
  LastLaneSkipKey = nil,
  LastLaneSkipUntil = 0,

  LastMarchCastAt = 0,

  LastTeleportAnchor = nil,
  CurrentSpotMarchCasts = 0,
  CurrentSpotMarchRequired = nil,
  MarchTotalCasts = 0,
  MarchModeWasCustom = false,
  PendingMarchVerify = nil,
  StatusUI = {
    x = Render.ScreenSize().x / 1.35,
    y = Render.ScreenSize().y / 1.1,
    dragging = false,
    dragDX = 0,
    dragDY = 0,
    mousePrevDown = false
  },

  -- Tracks AutoFarm toggle state between updates
  AutoFarmWasOn = false
}

local Utils = {}
local Tinker = {}
local RefreshLaneCamp
local GetLaneMarchLimit

local ORDER_NAME = {
  [Enum.UnitOrder.DOTA_UNIT_ORDER_NONE]             = "NONE",
  [Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION] = "MOVE",
  [Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET]   = "CAST_NO_TARGET",
  [Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION]    = "CAST_POSITION",
  [Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TARGET]      = "CAST_TARGET",
}

local function RecordOrder(order, ability, allowed, reason, targetEntity, targetPos)
  State.LastOrderDebug = {
    at      = GameRules.GetGameTime(),
    order   = ORDER_NAME[order] or tostring(order),
    ability = ability and Ability.GetName(ability) or nil,
    allowed = allowed,
    reason  = reason or (allowed and "sent" or "blocked"),
    tpos    = targetPos
  }
end

local function ShouldAllowOrder(order, ability, targetEntity, targetPos)
  local t = GameRules.GetGameTime()

  -- Prevent accidental order spam from cancelling Rearm during cast point / early channel frames.
  if State.RearmBlinkHoldPending and ability ~= State.Rearm then
    return false, "rearmPendingLock"
  end

  if (State.OrdersThisUpdate or 0) >= (Constants.ORDERS_PER_UPDATE or 1) then
    return false, "perUpdateCap"
  end

  if t < (State.NextOrderTime or 0) then
    return false, "globalCooldown"
  end

  if order == Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION and targetPos then
    local lastPos, lastTime = State.LastMovePos, State.LastMoveTime or 0
    if lastPos and (t - lastTime) < Constants.MOVE_RESEND_INTERVAL and targetPos:Distance(lastPos) < Constants.MOVE_POS_EPS then
      return false, "moveDedup"
    end
    return true
  end

  if ability then
    local aKey = tostring(ability)
    local last = State.LastAbilityOrders[aKey]
    if last and (t - (last.at or 0)) < Constants.ABILITY_DEDUP_INTERVAL then
      if last.order == order then
        if order == Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET then
          return false, "abilityNoTargetDedup"
        elseif order == Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TARGET and targetEntity and last.target == targetEntity then
          return false, "abilityTargetDedup"
        elseif order == Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION and targetPos and last.pos
            and targetPos:Distance(last.pos) < Constants.CAST_POS_EPS then
          return false, "abilityPosDedup"
        end
      end
    end
    return true
  end

  return true
end
local function OnMarchIssued() end

function Utils.IssueOrder(order, ability, data)
  local t = GameRules.GetGameTime()

  if State.IsChanneling then
    RecordOrder(order, ability, false, "channeling", nil, nil)
    return false
  end

  local targetEntity  = (data and type(data) == "userdata" and Entity.IsEntity(data)) and data or nil
  local targetPos     = (data and type(data) == "userdata" and not Entity.IsEntity(data)) and data or nil

  local allow, reason = ShouldAllowOrder(order, ability, targetEntity, targetPos)
  if not allow then
    RecordOrder(order, ability, false, reason, targetEntity, targetPos)
    return false
  end

  Player.PrepareUnitOrders(
    State.Player, order, targetEntity, targetPos, ability,
    Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_HERO_ONLY, State.Hero,
    false, false, false, true, false, false
  )

  State.NextOrderTime    = t + Constants.ORDER_COOLDOWN
  State.OrdersThisUpdate = (State.OrdersThisUpdate or 0) + 1

  if t - (State.OrderCounterStart or 0) >= 1.0 then
    State.OrdersPerSec         = State.OrdersSentThisSecond or 0
    State.OrdersSentThisSecond = 0
    State.OrderCounterStart    = t
  end
  State.OrdersSentThisSecond = (State.OrdersSentThisSecond or 0) + 1

  if order == Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION and targetPos then
    State.LastMovePos  = targetPos
    State.LastMoveTime = t
  end

  if ability then
    local aKey = tostring(ability)
    State.LastAbilityOrders[aKey] = { order = order, at = t, pos = targetPos, target = targetEntity }
  end

  RecordOrder(order, ability, true, "sent", targetEntity, targetPos)
  if ability and State.March and ability == State.March then
    OnMarchIssued()
  end
  return true
end

function Utils.CastAbility(ability, order, data)
  if ability and Ability.CanBeExecuted(ability) == -1 then
    local ok = Utils.IssueOrder(order, ability, data)
    return ok
  end
  return false
end

function Utils.MoveTo(pos)
  return Utils.IssueOrder(Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION, nil, pos)
end

local function CanExecuteAbility(ability)
  if not ability then return false end
  if Ability and Ability.CanBeExecuted then
    return Ability.CanBeExecuted(ability) == -1
  end
  if Ability and Ability.IsReady then
    return Ability.IsReady(ability)
  end
  if ability.IsReady then
    return ability:IsReady()
  end
  return false
end

function Tinker.GetDagonItem()
  if not State.Hero then return nil end
  return NPC.GetItem(State.Hero, "item_dagon_5", true)
      or NPC.GetItem(State.Hero, "item_dagon_4", true)
      or NPC.GetItem(State.Hero, "item_dagon_3", true)
      or NPC.GetItem(State.Hero, "item_dagon_2", true)
      or NPC.GetItem(State.Hero, "item_dagon", true)
end

function Tinker.IsOverwhelmingBlink()
  return State.Blink and Ability.GetName(State.Blink) == "item_overwhelming_blink"
end

local function FormatGold(n) return tostring(math.floor(n + 0.5)) .. "g" end

local MarkRearmIssued = function(now)
  now = now or GameRules.GetGameTime()
  State.LastRearmAt           = now
  State.RearmBlinkHoldPending = true
  State.RearmBlinkChannelSeen = false
end

local function UpdateRearmBlinkHold()
  if not State.RearmBlinkHoldPending then return end

  local now = GameRules.GetGameTime()
  if State.IsChanneling then
    State.RearmBlinkChannelSeen = true
    return
  end

  local fallbackDelay = Constants.REARM_HOLD_ARM_FALLBACK or 0.15
  if State.RearmBlinkChannelSeen or (now - (State.LastRearmAt or 0)) >= fallbackDelay then
    State.RearmBlinkHoldPending = false
    State.RearmBlinkChannelSeen = false
    State.RearmBlinkHoldUntil   = now + (Constants.BLINK_HOLD_AFTER_REARM or 0)
  end
end

local function IsBlinkLockedNow()
  local now = GameRules.GetGameTime()

  if Config.Blink and Config.Blink.HoldTPLock and Config.Blink.HoldTPLock:Get() then
    if now < (State.TeleportLockUntil or 0) then
      return true
    end
  end

  if Config.Blink and Config.Blink.HoldAfterRearm and Config.Blink.HoldAfterRearm:Get() then
    if State.RearmBlinkHoldPending and (State.IsChanneling or State.RearmBlinkChannelSeen) then
      return true
    end
    if now < (State.RearmBlinkHoldUntil or 0) then
      return true
    end
  end

  return false
end

Tinker = Tinker or {}
local function GetAbilityCooldownRemaining(ability)
  if not ability then return 0 end
  if Ability.GetCooldownTimeRemaining then
    local cd = Ability.GetCooldownTimeRemaining(ability) or 0
    if cd < 0 then cd = 0 end
    return cd
  end
  if Ability.GetCooldown then
    local cd = Ability.GetCooldown(ability) or 0
    if cd < 0 then cd = 0 end
    return cd
  end
  return (Ability.CanBeExecuted(ability) == -1) and 0 or 0.1
end

function Tinker.QueueMarchVerify()
  if not State.March then return end
  State.PendingMarchVerify = {
    requestedAt = GameRules.GetGameTime(),
    baseCD      = GetAbilityCooldownRemaining(State.March),
    expireAt    = GameRules.GetGameTime() + Constants.MARCH_VERIFY_MAX_AGE
  }
end

function Tinker.ProcessMarchVerify()
  local v = State.PendingMarchVerify
  if not v or not State.March then return end
  local now = GameRules.GetGameTime()
  if now > (v.expireAt or 0) then
    State.PendingMarchVerify = nil
    return
  end
  local cd  = GetAbilityCooldownRemaining(State.March)
  local eps = Constants.MARCH_VERIFY_COOLDOWN_EPS or 0.01
  if cd > (v.baseCD or 0) + eps then
    State.MarchTotalCasts = (State.MarchTotalCasts or 0) + 1
    if State.FarmState == "FARMING_SPOT" and State.CurrentFarmSpot then
      State.CurrentSpotMarchCasts = (State.CurrentSpotMarchCasts or 0) + 1
    end
    State.LastMarchCastAt    = now
    State.PendingMarchVerify = nil
  end
end

local function GetRequiredMarchesForCampType(campType)
  local mc = Config.MarchControl
  if campType == 1 then
    return mc.Small:Get()
  elseif campType == 2 then
    return mc.Medium:Get()
  elseif campType == 3 then
    return mc.Large:Get()
  elseif campType == 4 then
    return mc.Ancient:Get()
  end
  return 0
end

local function ComputeRequiredMarchesForSpot(spot)
  if not spot then return 0 end
  if spot.kind == "lane" then
    -- Count creep packs (a standard pack is ~4 creeps).
    local cnt   = (spot.creepCount or (spot.camp1 and spot.camp1.creepCount)) or 1
    local packs = math.max(1, math.floor((cnt + 3) / 4))
    if packs >= 2 then
      return math.max(1, (Config.MarchControl.LanePack2 and Config.MarchControl.LanePack2:Get()) or 2)
    end
    return math.max(1, (Config.MarchControl.LanePack1 and Config.MarchControl.LanePack1:Get()) or 1)
  end
  local function req(c)
    if not c or not c.type then return 0 end
    return GetRequiredMarchesForCampType(c.type)
  end
  local r1 = req(spot.camp1)
  if spot.single then return r1 end
  local r2 = req(spot.camp2)
  return math.max(r1, r2)
end

local function NextNeutralCampRespawnTime(now)
  local nextMin = (math.floor(now / 60) + 1) * 60
  return nextMin + 0.25
end

local function MarkCampFarmed(camp, now)
  if not camp then return end
  if camp.kind == "lane_wave" then
    camp.farmed = true
    camp.farmedAt = now
    camp.respawnAt = nil
    return
  end
  camp.farmed = true
  camp.farmedAt = now
  camp.respawnAt = NextNeutralCampRespawnTime(now)
end

local function UpdateFarmedCampRespawns()
  local now = GameRules.GetGameTime()
  for _, camp in pairs(GetJungleSpots() or {}) do
    if camp and camp.farmed then
      camp.respawnAt = camp.respawnAt or NextNeutralCampRespawnTime(now)
      if camp.respawnAt and now >= camp.respawnAt then
        camp.farmed = false
        camp.farmedAt = nil
        camp.respawnAt = nil
      end
    end
  end
end

local function MarkSpotFarmedAndLeave()
  local curSpot = State.CurrentFarmSpot
  local now = GameRules.GetGameTime()
  if curSpot then
    if curSpot.camp1 then MarkCampFarmed(curSpot.camp1, now) end
    if (not curSpot.single) and curSpot.camp2 then
      MarkCampFarmed(curSpot.camp2, now)
    end
  end
  State.AfterMarchCheck          = nil
  State.CurrentFarmSpot          = curSpot
  if curSpot and curSpot.kind == "lane" then
    if curSpot.pos then
      State.LaneBurstPos   = Vector(curSpot.pos.x, curSpot.pos.y, curSpot.pos.z)
      State.LaneBurstUntil = now + 13.0
    end
    if Tinker.TryRotateAfterLaneClear and Tinker.TryRotateAfterLaneClear(curSpot) then
      return
    end
  end
  State.FarmState                = "IDLE"
  State.JustClearedSpotAt        = GameRules.GetGameTime()
  State.CurrentFarmSpot          = nil
  State.CurrentSpotMarchCasts    = 0
  State.CurrentSpotMarchRequired = nil
end
OnMarchIssued = function()
  State.LastMarchCastAt = GameRules.GetGameTime()
  Tinker.QueueMarchVerify()
end
local function KeenLevel()
  if not State.KeenTeleport then return 0 end
  return Ability.GetLevel(State.KeenTeleport) or 0
end
local function GetLandingRadiusForAnchor(e)
  if not e or not Entity.IsEntity(e) then return 0 end
  if NPC.IsStructure(e) then
    if string.find((Entity.GetUnitName(e) or ""), "npc_dota_watch_tower") then
      return Constants.KEEN_LANDING_RADIUS_OUTPOST
    end
    return Constants.KEEN_LANDING_RADIUS_STRUCTURE
  end
  return NPC.GetPaddedCollisionRadius(e) or 72
end
function Tinker.ResolveKeenTeleport(desiredPos)
  local lvl                           = KeenLevel()
  local allowCreep                    = lvl >= 2
  local allowHero                     = lvl >= 3

  local bestAnchor, bestCat, bestDist = nil, nil, math.huge

  local function consider(e, cat)
    if not e or not Entity.IsAlive(e) then return end
    if Entity.GetTeamNum(e) ~= State.HeroTeam then return end
    if e == State.Hero then return end
    local p = Entity.GetAbsOrigin(e)
    local d = p:Distance(desiredPos)
    if d < bestDist then
      bestDist, bestAnchor, bestCat = d, e, cat
    end
  end

  for _, e in ipairs(NPCs.GetAll(Enum.UnitTypeFlags.TYPE_STRUCTURE) or {}) do
    consider(e, "structure")
  end
  if allowCreep then
    for _, e in ipairs(NPCs.GetAll(Enum.UnitTypeFlags.TYPE_LANE_CREEP) or {}) do
      if Entity.IsSameTeam(e, State.Hero) and Entity.IsAlive(e) and not Entity.IsDormant(e) and not NPC.IsWaitingToSpawn(e) then
        consider(e, "creep")
      end
    end
  end
  if allowHero then
    for _, e in ipairs(Heroes.GetAll() or {}) do
      consider(e, "hero")
    end
  end

  if bestAnchor then
    local anchorPos = Entity.GetAbsOrigin(bestAnchor)
    local r         = GetLandingRadiusForAnchor(bestAnchor)
    local d         = desiredPos:Distance(anchorPos)
    local finalPos  = (d > r) and (anchorPos + (desiredPos - anchorPos):Normalized() * r) or desiredPos
    return {
      castOrder     = Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION,
      castData      = finalPos,
      anchor        = bestAnchor,
      anchorPos     = anchorPos,
      landingRadius = r,
      finalPos      = finalPos,
      cat           = bestCat
    }
  end

  return {
    castOrder     = Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION,
    castData      = desiredPos,
    anchor        = nil,
    anchorPos     = nil,
    landingRadius = 0,
    finalPos      = desiredPos,
    cat           = "raw"
  }
end

function Tinker.SelectTeleportAnchor(targetPos)
  local res = Tinker.ResolveKeenTeleport(targetPos)
  if res and res.anchor then
    return {
      entity        = res.anchor,
      pos           = res.anchorPos,
      cat           = res.cat,
      landingRadius = res.landingRadius,
      finalPos      = res.finalPos
    }
  end
  return nil
end

function Tinker.IntendedKeenTPPos(rawPos)
  local res = Tinker.ResolveKeenTeleport(rawPos)
  return res and res.finalPos or rawPos
end

function Tinker.GetEnemyLastKnownPositions()
  local out = {}
  if not Heroes or not Heroes.GetAll then return out end
  for _, h in ipairs(Heroes.GetAll() or {}) do
    if h ~= State.Hero
        and Entity.IsEntity(h)
        and Entity.GetTeamNum(h) ~= State.HeroTeam
        and Entity.IsAlive(h)
        and (not NPC.IsIllusion or not NPC.IsIllusion(h)) then
      local p = (not Entity.IsDormant(h)) and Entity.GetAbsOrigin(h)
          or (Hero.GetLastMaphackPos and Hero.GetLastMaphackPos(h))
      if p then table.insert(out, p) end
    end
  end
  return out
end

local function MinDistToEnemies(pt, enemyPts)
  local best = math.huge
  for _, ep in ipairs(enemyPts) do
    local d = pt:Distance(ep)
    if d < best then best = d end
  end
  return best
end

local function RiskAtPoint(pt, enemyPts)
  local R = Constants.ENEMY_RISK_RADIUS
  if #enemyPts == 0 then return 0 end
  local d = MinDistToEnemies(pt, enemyPts)
  if d >= R then return 0 end
  local r = 1 - (d / R)
  return math.max(0, math.min(1, r * r))
end
local function AnyEnemyWithin(pt, enemyPts, radius)
  for _, ep in ipairs(enemyPts or {}) do
    if pt:Distance(ep) <= radius then return true end
  end
  return false
end
local function PathRisk(a, b, enemyPts)
  if #enemyPts == 0 then return 0 end
  local step = Constants.ENEMY_RISK_PATH_STEP
  local ab   = b - a
  local L    = ab:Length()
  if L < 1 then return RiskAtPoint(b, enemyPts) end
  local dir   = ab / L
  local t     = 0
  local worst = 0
  while t <= L do
    local p = a + dir * t
    local r = RiskAtPoint(p, enemyPts)
    if r > worst then worst = r end
    t = t + step
  end
  local rend = RiskAtPoint(b, enemyPts)
  if rend > worst then worst = rend end
  return worst
end
function Tinker.IsTeleportSafe(rawTargetPos)
  local enemyPts = Tinker.GetEnemyLastKnownPositions()
  if #enemyPts == 0 then return true end

  local res       = Tinker.ResolveKeenTeleport(rawTargetPos)
  local land      = (res and res.finalPos) or rawTargetPos
  local anchorPos = (res and res.anchorPos) or land

  local riskLimit = Constants.ENEMY_RISK_HARD_BLOCK or 0.45
  local blockR    = Constants.ENEMY_RISK_BLOCK_RADIUS or 1000

  if RiskAtPoint(rawTargetPos, enemyPts) >= riskLimit then return false end
  if RiskAtPoint(land, enemyPts) >= riskLimit then return false end
  if PathRisk(anchorPos, rawTargetPos, enemyPts) >= riskLimit then return false end

  if AnyEnemyWithin(land, enemyPts, blockR) then return false end
  if AnyEnemyWithin(rawTargetPos, enemyPts, blockR) then return false end

  return true
end

local function HasFountainBuff()
  local modifier = NPC.GetModifier(State.Hero, "modifier_fountain_aura_buff")
  if modifier then
    local continous = Modifier.IsCurrentlyInAuraRange(modifier)
    if continous then
      return true
    end
  end
  return false
end
local function CampIndex(camp)
  if not camp then return "nil" end
  return camp.index and tostring(camp.index) or tostring(camp)
end

local function SpotKey(spot)
  if not spot then return "nil" end
  if spot.single then return "S:" .. CampIndex(spot.camp1) end
  local a = CampIndex(spot.camp1)
  local b = CampIndex(spot.camp2)
  if b < a then a, b = b, a end
  return "P:" .. a .. "|" .. b
end

local function RecenterSpot(spot)
  if not spot then return end
  if spot.kind == "lane" and spot.camp1 then
    RefreshLaneCamp(spot.camp1)
    if spot.camp1.pos then spot.pos = spot.camp1.pos end
    return
  end
  if spot.single then
    if spot.camp1 and spot.camp1.pos then spot.pos = spot.camp1.pos end
  else
    if spot.camp1 and spot.camp1.pos and spot.camp2 and spot.camp2.pos then
      spot.pos = (spot.camp1.pos + spot.camp2.pos) / 2
    end
  end
end

local function ClearCampScanCaches()
  State.CampAliveScanCache = {}
  State.NeutralSnapshot    = { at = 0, list = {} }
  State.LaneCreepSnapshot  = { at = 0, list = {} }
end

local function ResetFarmedCampFlags(reason)
  for _, camp in pairs(GetJungleSpots() or {}) do
    if type(camp) == "table" then
      camp.farmed    = false
      camp.farmedAt  = nil
      camp.respawnAt = nil
    end
  end
  State.CachedBestSpot = nil
  State.LastSpotScan   = 0
  ClearCampScanCaches()
  State.LastCampResetReason = reason or "manual"
end

local function MaybeResetCampStateForSession()
  local matchId = (GameRules.GetMatchID and GameRules.GetMatchID()) or 0
  local startAt = (GameRules.GetGameStartTime and GameRules.GetGameStartTime()) or 0
  local sig     = tostring(matchId) .. "|" .. tostring(startAt)

  if State.SessionSig ~= sig then
    State.SessionSig = sig
    ResetFarmedCampFlags("sessionChange")
  end

  local now = GameRules.GetGameTime() or 0
  if (State.LastObservedGameTime or 0) > (now + 1.0) then
    ResetFarmedCampFlags("timeRewind")
  end
  State.LastObservedGameTime = now

  local dotaTime = (GameRules.GetDOTATime and GameRules.GetDOTATime()) or now
  local minute   = math.floor(math.max(0, dotaTime) / 60)
  if State.LastNeutralRespawnMinute == nil then
    State.LastNeutralRespawnMinute = minute
  elseif minute > State.LastNeutralRespawnMinute then
    State.LastNeutralRespawnMinute = minute
    State.CachedBestSpot = nil
    State.LastSpotScan   = 0
    ClearCampScanCaches()
  elseif minute < State.LastNeutralRespawnMinute then
    State.LastNeutralRespawnMinute = minute
  end
end

local function GetNeutralSnapshot()
  local ttl  = Constants.NEUTRAL_SNAPSHOT_CACHE_TTL or 0.10
  local now  = GameRules.GetGameTime() or 0
  local snap = State.NeutralSnapshot
  if snap and (now - (snap.at or 0)) <= ttl and type(snap.list) == "table" then
    return snap.list
  end

  local out = {}
  for _, unit in ipairs(NPCs.GetAll(Enum.UnitTypeFlags.TYPE_NEUTRAL_CREEP) or {}) do
    if unit and Entity.IsEntity(unit) and Entity.IsAlive(unit)
        and NPC.IsCreep(unit)
        and (not NPC.IsWaitingToSpawn or not NPC.IsWaitingToSpawn(unit)) then
      table.insert(out, unit)
    end
  end

  State.NeutralSnapshot = { at = now, list = out }
  return out
end

local function CountCampAliveCreepsByScan(camp)
  if not camp or not camp.pos then return 0 end

  local key   = CampIndex(camp)
  local now   = GameRules.GetGameTime() or 0
  local cache = State.CampAliveScanCache and State.CampAliveScanCache[key] or nil
  local ttl   = Constants.CAMP_ALIVE_SCAN_CACHE_TTL or 0.10
  if cache and (now - (cache.at or 0)) <= ttl then
    return cache.cnt or 0
  end

  local radius = (camp.type == 4) and (Constants.CAMP_ALIVE_SCAN_RADIUS_ANCIENT or 1200)
      or (Constants.CAMP_ALIVE_SCAN_RADIUS or 900)
  local cnt = 0
  for _, unit in ipairs(GetNeutralSnapshot()) do
    if unit and Entity.IsEntity(unit) then
      local upos = Entity.GetAbsOrigin(unit)
      if upos and upos:Distance(camp.pos) <= radius then
        cnt = cnt + 1
      end
    end
  end

  State.CampAliveScanCache = State.CampAliveScanCache or {}
  State.CampAliveScanCache[key] = { at = now, cnt = cnt }
  return cnt
end

local function MaybeUnmarkFarmedCamp(camp)
  if not camp or not camp.farmed then return end
  if not (GameRules.IsCheatsEnabled and GameRules.IsCheatsEnabled()) then return end
  if CountCampAliveCreepsByScan(camp) > 0 then
    camp.farmed    = false
    camp.farmedAt  = nil
    camp.respawnAt = nil
  end
end

local function GetCampTeam(camp)
  if not camp then return nil end
  if camp.team ~= nil then return camp.team end
  if not camp.pos then return nil end
  local dR = camp.pos:Distance(Constants.FOUNTAIN_RADIANT)
  local dD = camp.pos:Distance(Constants.FOUNTAIN_DIRE)
  return (dR <= dD) and 2 or 3
end

local function GetEnemyLaneCreepsSnapshot()
  local ttl  = Constants.LANE_CREEP_SNAPSHOT_CACHE_TTL or 0.10
  local now  = GameRules.GetGameTime() or 0
  local snap = State.LaneCreepSnapshot
  if snap and (now - (snap.at or 0)) <= ttl and type(snap.list) == "table" then
    return snap.list
  end

  local raw = nil
  if NPCs and NPCs.GetAll then
    raw = NPCs.GetAll(Enum.UnitTypeFlags.TYPE_LANE_CREEP)
    if type(raw) ~= "table" or #raw == 0 then
      raw = NPCs.GetAll()
    end
  end
  raw = raw or {}

  local out = {}
  for _, unit in ipairs(raw) do
    if unit and Entity.IsEntity(unit) and Entity.IsAlive(unit)
        and NPC.IsCreep(unit)
        and (NPC.IsLaneCreep and NPC.IsLaneCreep(unit))
        and Entity.GetTeamNum(unit) ~= State.HeroTeam
        and (not Entity.IsDormant or not Entity.IsDormant(unit))
        and (not NPC.IsWaitingToSpawn or not NPC.IsWaitingToSpawn(unit)) then
      table.insert(out, unit)
    end
  end

  State.LaneCreepSnapshot = { at = now, list = out }
  return out
end

local function IsSiegeLikeLaneCreep(unit)
  local name = (unit and Entity.GetUnitName(unit)) or ""
  return string.find(name, "siege", 1, true) ~= nil or string.find(name, "catapult", 1, true) ~= nil
end

local function CollectLaneCreepsAround(center, creeps, radius)
  if not center then return {}, nil, 0, 0 end
  local picked = {}
  local sx, sy, sz = 0, 0, 0
  local siegeCnt = 0

  for _, unit in ipairs(creeps or {}) do
    if unit and Entity.IsEntity(unit) and Entity.IsAlive(unit) then
      local p = Entity.GetAbsOrigin(unit)
      if p and p:Distance(center) <= radius then
        table.insert(picked, unit)
        sx, sy, sz = sx + (p.x or 0), sy + (p.y or 0), sz + (p.z or 0)
        if IsSiegeLikeLaneCreep(unit) then siegeCnt = siegeCnt + 1 end
      end
    end
  end

  local n = #picked
  if n == 0 then return picked, nil, 0, 0 end

  local avg = Vector(sx / n, sy / n, sz / n)
  local maxDist = 0
  for _, unit in ipairs(picked) do
    local p = Entity.GetAbsOrigin(unit)
    if p then
      local d = p:Distance(avg)
      if d > maxDist then maxDist = d end
    end
  end

  return picked, avg, maxDist, siegeCnt
end

local function MakeLaneBucketIndex(pos)
  local b = Constants.LANE_POS_BUCKET or 320
  return string.format("lane:%d:%d", math.floor((pos.x or 0) / b), math.floor((pos.y or 0) / b))
end

RefreshLaneCamp = function(camp)
  if not camp or camp.kind ~= "lane_wave" then return nil end
  if not camp.pos then
    camp.alive_creeps = {}
    camp.farmed = true
    return 0
  end

  local creeps = GetEnemyLaneCreepsSnapshot()
  local trackR = camp.track_radius or Constants.LANE_TRACK_RADIUS or 1000
  local reacqR = camp.reacquire_radius or Constants.LANE_REACQUIRE_RADIUS or 1800

  local picked, avg, _, siegeCnt = CollectLaneCreepsAround(camp.pos, creeps, trackR)
  if #picked == 0 then
    local nearestPos, nearestDist = nil, math.huge
    for _, unit in ipairs(creeps) do
      local p = Entity.GetAbsOrigin(unit)
      if p then
        local d = p:Distance(camp.pos)
        if d < nearestDist and d <= reacqR then
          nearestDist, nearestPos = d, p
        end
      end
    end
    if nearestPos then
      picked, avg, _, siegeCnt = CollectLaneCreepsAround(nearestPos, creeps, trackR)
    end
  end

  camp.alive_creeps = picked or {}
  if avg then
    camp.pos = avg
    camp.index = MakeLaneBucketIndex(avg)
    camp.farmed = false
    camp.creepCount = #camp.alive_creeps
    camp.siegeCount = siegeCnt or 0
  else
    camp.farmed = true
    camp.creepCount = 0
    camp.siegeCount = 0
  end

  return #camp.alive_creeps
end

GetLaneMarchLimit = function()
  if Config and Config.Lane and Config.Lane.MarchesPerWave and Config.Lane.MarchesPerWave.Get then
    return math.max(1, Config.Lane.MarchesPerWave:Get() or 1)
  end
  return 1
end

local function IsLaneSpotTemporarilySkipped(spotKey)
  if not spotKey then return false end
  return State.LastLaneSkipKey == spotKey and (GameRules.GetGameTime() or 0) < (State.LastLaneSkipUntil or 0)
end

-- Is an enemy tower within `radius` of the pack?
local function EnemyTowerNear(pos, radius)
  if not pos then return false end
  radius = radius or (Constants.LANE_ENEMY_TOWER_BLOCK_RADIUS or 1100)

  local function isEnemyTower(npc)
    return npc and Entity.IsEntity(npc) and Entity.IsAlive(npc)
        and Entity.GetTeamNum(npc) ~= State.HeroTeam
  end

  for _, tower in ipairs(Towers.GetAll() or {}) do
    if isEnemyTower(tower) then
      local p = Entity.GetAbsOrigin(tower)
      if p and p:Distance(pos) <= radius then return true end
    end
  end

  -- Fallback for builds where Towers.GetAll() is empty.
  for _, npc in ipairs(NPCs.GetAll(Enum.UnitTypeFlags.TYPE_STRUCTURE) or {}) do
    if isEnemyTower(npc) then
      local nm = Entity.GetUnitName(npc) or ""
      if (NPC.IsTower and NPC.IsTower(npc)) or string.find(nm, "tower") then
        local p = Entity.GetAbsOrigin(npc)
        if p and p:Distance(pos) <= radius then return true end
      end
    end
  end
  return false
end

-- After clearing a lane, don't TP back to it for a while.
local LANE_BURST_SKIP_RADIUS = 1500
local LANE_BURST_SKIP_TIME   = 13.0

local function MarkLaneBurstCooldown(spot)
  if not (spot and spot.kind == "lane" and spot.pos) then return end
  State.LaneBurstPos   = Vector(spot.pos.x, spot.pos.y, spot.pos.z)
  State.LaneBurstUntil = GameRules.GetGameTime() + LANE_BURST_SKIP_TIME
end

local function LaneBurstOnCooldown(pos)
  if not pos or not State.LaneBurstUntil then return false end
  if GameRules.GetGameTime() >= State.LaneBurstUntil then return false end
  if not State.LaneBurstPos then return false end
  return pos:Distance(State.LaneBurstPos) <= LANE_BURST_SKIP_RADIUS
end

-- ── Enemy teleport detector (works even in fog) ──
local EnemyTp = (function()
  local function currentDest(hero)
    local mod = NPC.GetModifier and NPC.GetModifier(hero, "modifier_teleporting")
    if mod then
      local p = Modifier.GetField and Modifier.GetField(mod, "m_vTargetPosition")
      if p then return p end
    end
    return nil
  end

  local function isTeleporting(hero)
    if NPC.HasModifier and NPC.HasModifier(hero, "modifier_teleporting") then return true end
    if NPC.GetActivity and Enum.GameActivity then
      local act = NPC.GetActivity(hero)
      if act == Enum.GameActivity.ACT_DOTA_TELEPORT then return true end
    end
    return false
  end

  local function Threats()
    local out = {}
    for _, h in ipairs(Heroes.GetAll() or {}) do
      if h ~= State.Hero and Entity.IsEntity(h) and Entity.IsAlive(h)
          and Entity.GetTeamNum(h) ~= State.HeroTeam
          and (not NPC.IsIllusion or not NPC.IsIllusion(h)) then
        if isTeleporting(h) then
          local dest = currentDest(h)
          if not dest then
            dest = (not Entity.IsDormant(h)) and Entity.GetAbsOrigin(h)
                or (Hero.GetLastMaphackPos and Hero.GetLastMaphackPos(h))
          end
          out[#out + 1] = { hero = h, pos = dest }
        end
      end
    end
    return out
  end

  local function Near(pos, radius)
    if not pos then return nil end
    local best, bestD = nil, radius or 1500
    for _, t in ipairs(Threats()) do
      if t.pos then
        local d = pos:Distance(t.pos)
        if d <= bestD then bestD, best = d, t.pos end
      end
    end
    return best
  end

  return { Threats = Threats, Near = Near, IsTeleporting = isTeleporting }
end)()

-- ── Track last time each enemy hero was VISIBLE (near the lane) ──
local LANE_SEEN_RADIUS = 1200

local function UpdateEnemySeen()
  local now = GameRules.GetGameTime()
  State.EnemySeen = State.EnemySeen or {}
  for _, h in ipairs(Heroes.GetAll() or {}) do
    if h ~= State.Hero and Entity.IsEntity(h) and Entity.IsAlive(h)
        and Entity.GetTeamNum(h) ~= State.HeroTeam
        and (not NPC.IsIllusion or not NPC.IsIllusion(h))
        and not Entity.IsDormant(h) then
      local p = Entity.GetAbsOrigin(h)
      if p then
        State.EnemySeen[Entity.GetIndex(h)] = { pos = Vector(p.x, p.y, p.z), t = now }
      end
    end
  end
end

local function LaneRecentlySeen(anchor, seconds, radius)
  if not anchor then return false end
  seconds = seconds or 10
  radius  = radius or LANE_SEEN_RADIUS
  local now = GameRules.GetGameTime()
  for _, e in pairs(State.EnemySeen or {}) do
    if e and (now - (e.t or 0)) <= seconds and e.pos
        and e.pos:Distance(anchor) <= radius then
      return true
    end
  end
  return false
end

local function LaneSafetySeconds()
  local u = Config.LaneSafety and Config.LaneSafety.UltraSafe and Config.LaneSafety.UltraSafe:Get()
  if u then return 20 end
  local s = Config.LaneSafety and Config.LaneSafety.Safe and Config.LaneSafety.Safe:Get()
  if s then return 10 end
  return 0
end

-- All enemy heroes are dead -> no restrictions, hard-push lanes.
local function AllEnemiesDead()
  local found = false
  for _, h in ipairs(Heroes.GetAll() or {}) do
    if h ~= State.Hero and Entity.IsEntity(h) and Entity.GetTeamNum(h) ~= State.HeroTeam then
      if Entity.IsAlive(h) then return false end
      found = true
    end
  end
  return found
end

-- ── Ultra-safe lane: only farm when "dangerous" enemies are visible and far ──
-- Dangerous = has an interrupt item, OR a control ability, OR can burst us
-- in ~4s (TP duration). Any enemy near the pack also makes it unsafe.
local LaneUltraSafe = (function()
  local INTERRUPT_ITEMS = {
    item_cyclone = true, item_wind_waker = true, item_sheepstick = true,
    item_abyssal_blade = true, item_basher = true, item_meteor_hammer = true,
    item_rod_of_atos = true, item_gleipnir = true, item_orchid = true, item_bloodthorn = true,
  }

  local CONTROL_ABILITIES = {
    -- hard stuns / disables
    "axe_berserkers_call", "bane_nightmare", "bane_fiends_grip",
    "batrider_flaming_lasso", "beastmaster_primal_roar", "brewmaster_primal_split",
    "centaur_hoof_stomp", "chaos_knight_chaos_bolt",
    "rattletrap_battery_assault", "rattletrap_power_cogs", "rattletrap_hookshot",
    "dragon_knight_dragon_tail", "earthshaker_fissure", "earthshaker_echo_slam",
    "elder_titan_echo_stomp", "enigma_malefice", "enigma_black_hole",
    "faceless_void_chronosphere", "gyrocopter_homing_missile",
    "hoodwink_bushwhack", "hoodwink_sharpshooter", "jakiro_ice_path",
    "kunkka_torrent", "kunkka_ghostship", "largo_frogstomp", "leshrac_split_earth",
    "lina_light_strike_array", "lion_impale", "lion_voodoo", "luna_lucent_beam",
    "magnataur_reverse_polarity", "magnataur_skewer", "mars_spear", "medusa_stone_gaze",
    "mirana_arrow", "monkey_king_boundless_strike", "morphling_adaptive_strike_str",
    "nyx_assassin_impale", "nyx_assassin_spiked_carapace", "ogre_magi_fireblast",
    "phoenix_supernova", "primal_beast_onslaught", "primal_beast_pulverize",
    "puck_dream_coil", "pudge_meat_hook", "pudge_dismember", "ringmaster_wheel",
    "rubick_telekinesis", "sandking_burrowstrike", "shadow_shaman_voodoo",
    "shadow_shaman_shackles", "slardar_slithereen_crush", "slardar_bash",
    "spirit_breaker_charge_of_darkness", "spirit_breaker_nether_strike",
    "spirit_breaker_greater_bash", "sven_storm_bolt", "snapfire_firesnap_cookie",
    "techies_suicide", "tidehunter_ravage", "tiny_avalanche", "tiny_toss",
    "tusk_walrus_punch", "tusk_snowball", "vengefulspirit_magic_missile",
    "visage_stone_form", "warlock_chaotic_offering", "windrunner_shackleshot",
    "witch_doctor_paralyzing_cask", "skeleton_king_hellfire_blast", "zuus_lightning_bolt",
    -- roots
    "crystal_maiden_frostbite", "ember_spirit_searing_chains", "lone_druid_entangle",
    "meepo_earthbind", "naga_siren_ensnare", "oracle_fortunes_end",
    "treant_natures_grasp", "treant_overgrowth", "treant_leech_seed",
    "abyssal_underlord_pit_of_malice", "pangolier_lucky_shot", "keeper_of_the_light_mana_leak",
    -- silences
    "death_prophet_silence", "doom_bringer_doom", "drow_ranger_gust",
    "disruptor_static_storm", "grimstroke_ink_creature", "kez_talon_toss",
    "night_stalker_crippling_fear", "puck_waning_rift", "riki_smoke_screen",
    "silencer_last_word", "silencer_global_silence", "skywrath_mage_ancient_seal",
    -- sleep / fear / taunt / banish / leash / pull
    "dark_willow_terrorize", "legion_commander_duel", "lich_sinister_gaze",
    "muerta_dead_shot", "outworld_destroyer_astral_imprisonment",
    "shadow_demon_disruption", "slark_pounce", "storm_spirit_electric_vortex",
    "void_spirit_aether_remnant", "winter_wyvern_winters_curse", "largo_catchy_lick",
    "kez_kazurai_katana", "ringmaster_impalement_act", "ringmaster_the_box",
  }

  local NEAR_PACK_RADIUS  = 1500
  local DANGER_FAR_RADIUS = 2500
  local TP_TIME           = 4.0

  local function hasInterruptItem(hero)
    for name in pairs(INTERRUPT_ITEMS) do
      if NPC.HasItem(hero, name, true) then return true end
    end
    return false
  end

  local function hasControlAbility(hero)
    for _, name in ipairs(CONTROL_ABILITIES) do
      local ab = NPC.GetAbility(hero, name)
      if ab and (Ability.GetLevel(ab) or 0) > 0 then return true end
    end
    return false
  end

  local function burstDamage(hero)
    -- Ability damage is mostly magical (~0.75 after base magic resist),
    -- plus ~2s of right-clicks (a fair estimate, not the whole TP window).
    local abilityDmg = 0
    for i = 0, 20 do
      local ab = NPC.GetAbilityByIndex(hero, i)
      if ab and (Ability.GetLevel(ab) or 0) > 0
          and not (Ability.IsPassive and Ability.IsPassive(ab))
          and Ability.GetDamage then
        abilityDmg = abilityDmg + (Ability.GetDamage(ab) or 0)
      end
    end
    local dmg  = (NPC.GetTrueMaximumDamage and NPC.GetTrueMaximumDamage(hero))
        or (NPC.GetTrueDamage and NPC.GetTrueDamage(hero)) or 0
    local aspd = (NPC.GetAttacksPerSecond and NPC.GetAttacksPerSecond(hero)) or 1
    return abilityDmg * 0.75 + dmg * aspd * 2.0
  end

  local function canKillUs(hero)
    if not State.Hero then return false end
    local hp = Entity.GetHealth(State.Hero) or 0
    if hp <= 0 then return false end
    return burstDamage(hero) >= hp
  end

  local function isDangerous(hero)
    return hasInterruptItem(hero) or hasControlAbility(hero) or canKillUs(hero)
  end

  -- Returns true if it is safe to farm the lane `spot` right now.
  -- How much time we need on the lane (burst + leave). If an enemy can get
  -- here faster than this, the lane is unsafe.
  local ULTRA_FARM_WINDOW = 6.0
  local BLINK_RANGE       = 1200

  local function heroHasBlink(hero)
    return NPC.HasItem(hero, "item_blink", true)
        or NPC.HasItem(hero, "item_overwhelming_blink", true)
        or NPC.HasItem(hero, "item_swift_blink", true)
        or NPC.HasItem(hero, "item_arcane_blink", true)
  end

  -- Can this hero reach `anchor` within `window` seconds?
  -- Uses the LAST-SEEN position/time (VBE) for fogged heroes + move speed + blink.
  local function heroCanReach(hero, anchor, window)
    local now     = GameRules.GetGameTime()
    local visible = not Entity.IsDormant(hero)
    local pos, seenAt
    if visible then
      pos, seenAt = Entity.GetAbsOrigin(hero), now
    else
      local seen = State.EnemySeen and State.EnemySeen[Entity.GetIndex(hero)]
      if seen then pos, seenAt = seen.pos, seen.t else return true end
    end
    if not pos then return true end

    local speed = (NPC.GetMoveSpeed and NPC.GetMoveSpeed(hero)) or 300
    if not speed or speed < 50 then speed = 300 end

    local dist  = anchor:Distance(pos)
    local since = math.max(0, now - (seenAt or 0))
    dist = math.max(0, dist - since * speed)             -- worst case: ran straight at us
    if heroHasBlink(hero) then dist = math.max(0, dist - BLINK_RANGE) end
    return (dist / speed) <= window
  end

  local function Ok(spot)
    local anchor = (spot and spot.pos) or (State.Hero and Entity.GetAbsOrigin(State.Hero))
    if not anchor then return false end
    -- An enemy teleporting onto the pack -> unsafe (escape immediately).
    if EnemyTp.Near(anchor, NEAR_PACK_RADIUS) then return false end
    for _, h in ipairs(Heroes.GetAll() or {}) do
      if h ~= State.Hero and Entity.IsEntity(h) and Entity.IsAlive(h)
          and Entity.GetTeamNum(h) ~= State.HeroTeam
          and (not NPC.IsIllusion or not NPC.IsIllusion(h)) then
        -- Any VISIBLE enemy near the pack -> unsafe.
        if not Entity.IsDormant(h) then
          local p = Entity.GetAbsOrigin(h)
          if p and anchor:Distance(p) <= NEAR_PACK_RADIUS then return false end
        end
        -- Dangerous hero -> unsafe only if it can actually reach us in time.
        if isDangerous(h) and heroCanReach(h, anchor, ULTRA_FARM_WINDOW) then
          return false
        end
      end
    end
    return true
  end

  -- "Safe" (balanced): only VISIBLE enemies matter; fog does not block,
  -- the emergency blink-TP covers surprises. Attack if we can farm.
  local SAFE_NEAR_RADIUS   = 1400
  local SAFE_DANGER_RADIUS = 1800

  local function SafeOk(spot)
    local anchor = (spot and spot.pos) or (State.Hero and Entity.GetAbsOrigin(State.Hero))
    if not anchor then return false end
    if EnemyTp.Near(anchor, SAFE_NEAR_RADIUS) then return false end
    for _, h in ipairs(Heroes.GetAll() or {}) do
      if h ~= State.Hero and Entity.IsEntity(h) and Entity.IsAlive(h)
          and Entity.GetTeamNum(h) ~= State.HeroTeam
          and (not NPC.IsIllusion or not NPC.IsIllusion(h)) then
        local visible = not Entity.IsDormant(h)
        local p = visible and Entity.GetAbsOrigin(h)
            or (Hero.GetLastMaphackPos and Hero.GetLastMaphackPos(h))
        if p then
          local d = anchor:Distance(p)
          if isDangerous(h) then
            -- Dangerous hero: check even in fog (by maphack pos), but only close.
            if d <= SAFE_DANGER_RADIUS then return false end
          else
            -- Non-dangerous: only if actually visible.
            if visible and d <= SAFE_NEAR_RADIUS then return false end
          end
        end
      end
    end
    return true
  end

  -- "Unsafe": most aggressive, but keep a MINIMAL baseline safety so we
  -- don't fly straight into an enemy's face.
  local UNSAFE_RADIUS = 900
  local UNSAFE_SEEN   = 4

  local function UnsafeOk(spot)
    local anchor = (spot and spot.pos) or (State.Hero and Entity.GetAbsOrigin(State.Hero))
    if not anchor then return false end
    if EnemyTp.Near(anchor, UNSAFE_RADIUS) then return false end
    if LaneRecentlySeen(anchor, UNSAFE_SEEN, UNSAFE_RADIUS) then return false end
    for _, h in ipairs(Heroes.GetAll() or {}) do
      if h ~= State.Hero and Entity.IsEntity(h) and Entity.IsAlive(h)
          and Entity.GetTeamNum(h) ~= State.HeroTeam
          and (not NPC.IsIllusion or not NPC.IsIllusion(h))
          and not Entity.IsDormant(h) then
        local p = Entity.GetAbsOrigin(h)
        if p and anchor:Distance(p) <= UNSAFE_RADIUS then return false end
      end
    end
    return true
  end

  return { Ok = Ok, SafeOk = SafeOk, UnsafeOk = UnsafeOk, IsDangerous = isDangerous }
end)()

function Tinker.FindBestLaneCreepSpot(excludeSpotKey)
  local creeps = GetEnemyLaneCreepsSnapshot()
  if #creeps < (Constants.LANE_MIN_CREEPS or 2) then return nil end

  local myPos    = Entity.GetAbsOrigin(State.Hero)
  local enemyPts = Tinker.GetEnemyLastKnownPositions()
  local bestSpot, bestScore = nil, math.huge

  for _, seed in ipairs(creeps) do
    local seedPos = Entity.GetAbsOrigin(seed)
    if seedPos then
      local _, center = CollectLaneCreepsAround(seedPos, creeps, Constants.LANE_CLUSTER_SEED_RADIUS or 900)
      if center then
        local cluster2, center2, maxDist, siegeCnt = CollectLaneCreepsAround(center, creeps,
          Constants.MARCH_CAST_RANGE or 900)
        local count = #cluster2
        if count >= (Constants.LANE_MIN_CREEPS or 2) and center2 and maxDist <= (Constants.MARCH_CAST_RANGE or 900)
            and (AllEnemiesDead() or not LaneBurstOnCooldown(center2))
            and (AllEnemiesDead() or not (Config.LaneSafety and Config.LaneSafety.UltraSafe
                and Config.LaneSafety.UltraSafe:Get()) or LaneUltraSafe.Ok({ pos = center2 }))
            and (AllEnemiesDead() or LaneSafetySeconds() <= 0 or not LaneRecentlySeen(center2, LaneSafetySeconds(), LANE_SEEN_RADIUS))
            and (AllEnemiesDead() or not (Config.LaneExtras and Config.LaneExtras.NoTpNearEnemyTower
                and Config.LaneExtras.NoTpNearEnemyTower:Get()) or not EnemyTowerNear(center2)) then
          local anchorPos = Tinker.IntendedKeenTPPos(center2)
          local rSpot     = RiskAtPoint(center2, enemyPts)
          local rAnchor   = RiskAtPoint(anchorPos, enemyPts)
          local rPath     = PathRisk(anchorPos, center2, enemyPts)

          local riskLimit = Constants.ENEMY_RISK_HARD_BLOCK
          local blockR    = Constants.ENEMY_RISK_BLOCK_RADIUS
          if not ((rSpot >= riskLimit) or (rAnchor >= riskLimit) or (rPath >= riskLimit)
              or AnyEnemyWithin(anchorPos, enemyPts, blockR)) then
            local distScore   = myPos:Distance(center2) / 100.0
            local riskPenalty = (Constants.ENEMY_RISK_W_SPOT * rSpot
                + Constants.ENEMY_RISK_W_ANCHOR * rAnchor
                + Constants.ENEMY_RISK_W_PATH * rPath) * Constants.ENEMY_RISK_WEIGHT
            local waveValue   = count * (Constants.LANE_SCORE_PER_CREEP or 2.0)
                + siegeCnt * (Constants.LANE_SCORE_PER_SIEGE or 1.0)
            local score       = distScore + riskPenalty - waveValue

            if score < bestScore then
              local camp = {
                pos              = center2,
                type             = 2,
                index            = MakeLaneBucketIndex(center2),
                alive_creeps     = cluster2,
                farmed           = false,
                kind             = "lane_wave",
                creepCount       = count,
                siegeCount       = siegeCnt or 0,
                laneScoreRaw     = score,
                track_radius     = Constants.LANE_TRACK_RADIUS or 1000,
                reacquire_radius = Constants.LANE_REACQUIRE_RADIUS or 1800
              }
              local candidate = {
                pos    = center2,
                camp1  = camp,
                single = true,
                gold   = 0,
                kind   = "lane",
                creepCount = count,
                siegeCount = siegeCnt or 0,
                score = score
              }
              local cKey = SpotKey(candidate)
              if (not excludeSpotKey or cKey ~= excludeSpotKey) and (not IsLaneSpotTemporarilySkipped(cKey)) then
                bestScore = score
                bestSpot = candidate
              end
            end
          end
        end
      end
    end
  end

  return bestSpot
end

local function IsCampAncient(camp) return camp and camp.type == 4 end
local function ComputeMarchCastInfo(spot)
  if not spot then return nil end
  if spot.kind == "lane" and spot.camp1 then
    local cnt = RefreshLaneCamp(spot.camp1) or 0
    if cnt <= 0 then return nil end

    local castPos = spot.camp1.pos or spot.pos
    if not castPos then return nil end

    local alive = {}
    local sx, sy, sz = 0, 0, 0
    for _, unit in ipairs(spot.camp1.alive_creeps or {}) do
      if unit and Entity.IsEntity(unit) and Entity.IsAlive(unit) then
        local p = Entity.GetAbsOrigin(unit)
        if p then
          table.insert(alive, unit)
          sx, sy, sz = sx + (p.x or 0), sy + (p.y or 0), sz + (p.z or 0)
        end
      end
    end
    if #alive == 0 then
      spot.camp1.alive_creeps = {}
      spot.camp1.farmed = true
      return nil
    end

    castPos = Vector(sx / #alive, sy / #alive, sz / #alive)
    spot.camp1.alive_creeps = alive
    spot.camp1.pos = castPos
    spot.camp1.creepCount = #alive
    spot.pos = castPos
    spot.creepCount = #alive

    local maxDist = 0
    local siegeCnt = 0
    for _, unit in ipairs(alive) do
      local p = Entity.GetAbsOrigin(unit)
      if p then
        local d = castPos:Distance(p)
        if d > maxDist then maxDist = d end
      end
      if IsSiegeLikeLaneCreep(unit) then siegeCnt = siegeCnt + 1 end
    end
    spot.camp1.siegeCount = siegeCnt
    spot.siegeCount = siegeCnt
    return { pos = castPos, maxDist = maxDist, count = #alive, siegeCount = siegeCnt }
  end
  local castPos = spot.pos
  local maxDist = 0
  if spot.camp1 and spot.camp1.pos then maxDist = math.max(maxDist, castPos:Distance(spot.camp1.pos)) end
  if spot.camp2 and spot.camp2.pos then maxDist = math.max(maxDist, castPos:Distance(spot.camp2.pos)) end
  return { pos = castPos, maxDist = maxDist }
end

-- Do NOT fly onto jungle camps our allies are already clearing.
local ALLY_FARM_CAMP_RADIUS = 1000

local function GetActiveAlliesPos()
  local out = {}
  local my  = State.Hero
  for _, h in ipairs(Heroes.GetAll() or {}) do
    if h and h ~= my and Entity.IsEntity(h)
        and Entity.GetTeamNum(h) == State.HeroTeam
        and Entity.IsAlive(h) then
      local p = Entity.GetAbsOrigin(h)
      if p then out[#out + 1] = p end
    end
  end
  return out
end

local function AllyIsFarmingCamp(camp)
  if not camp or not camp.pos then return false end
  if CountCampAliveCreepsByScan(camp) <= 0 then return false end
  local allies = GetActiveAlliesPos()
  for i = 1, #allies do
    if allies[i]:Distance(camp.pos) <= ALLY_FARM_CAMP_RADIUS then return true end
  end
  return false
end

function Tinker.FindBestJungleSpot(wantAncient, wantNonAnc)
  local myPos = Entity.GetAbsOrigin(State.Hero)
  if not (wantAncient or wantNonAnc) then return nil end
  local allCamps, selectedSet = {}, {}
  for _, camp in pairs(GetJungleSpots()) do
    MaybeUnmarkFarmedCamp(camp)
    if not camp.farmed and GetCampTeam(camp) == State.HeroTeam
        and not AllyIsFarmingCamp(camp) then
      table.insert(allCamps, camp)
      local isAnc = IsCampAncient(camp)
      if (isAnc and wantAncient) or (not isAnc and wantNonAnc) then
        selectedSet[camp] = true
      end
    end
  end
  if #allCamps == 0 then return nil end

  local coverageMax                           = Constants.MARCH_CAST_RANGE * Constants.MARCH_PAIR_COVERAGE_FRAC
  local bountyK                               = Config.PreferBounty:Get() and Constants.BOUNTY_SCORE_FACTOR_HIGH or
      Constants.BOUNTY_SCORE_FACTOR_LOW

  local enemyPts                              = Tinker.GetEnemyLastKnownPositions()
  local wSpot                                 = Constants.ENEMY_RISK_W_SPOT
  local wAnchor                               = Constants.ENEMY_RISK_W_ANCHOR
  local wPath                                 = Constants.ENEMY_RISK_W_PATH
  local riskW                                 = Constants.ENEMY_RISK_WEIGHT
  local bestPairScore, bestPair, bestPairGold = math.huge, nil, 0
  if #allCamps >= 2 then
    for i = 1, #allCamps do
      for j = i + 1, #allCamps do
        local campA, campB = allCamps[i], allCamps[j]
        if selectedSet[campA] or selectedSet[campB] then
          local AB = (campA.pos - campB.pos):Length()
          if (AB * 0.5) <= coverageMax then
            local center        = (campA.pos + campB.pos) / 2
            local distScore     = myPos:Distance(center) / 100.0
            local spreadPenalty = AB / 200.0
            local gold          = (Camp.GetGoldBounty(campA, true) + Camp.GetGoldBounty(campB, true))
            local bountyScore   = (gold / 50.0) * bountyK

            local anchorPos     = Tinker.IntendedKeenTPPos(center)
            local rSpot         = RiskAtPoint(center, enemyPts)
            local rAnchor       = RiskAtPoint(anchorPos, enemyPts)
            local rPath         = PathRisk(anchorPos, center, enemyPts)

            local score         = math.huge
            local riskLimit     = Constants.ENEMY_RISK_HARD_BLOCK
            local blockR        = Constants.ENEMY_RISK_BLOCK_RADIUS
            if (rSpot >= riskLimit) or (rAnchor >= riskLimit) or (rPath >= riskLimit)
                or AnyEnemyWithin(anchorPos, enemyPts, blockR) then
            else
              local riskPenalty = (wSpot * rSpot + wAnchor * rAnchor + wPath * rPath) * riskW
              score             = distScore + spreadPenalty + riskPenalty - bountyScore
            end
            if score < bestPairScore then
              bestPairScore, bestPair, bestPairGold = score, { campA, campB }, gold
            end
          end
        end
      end
    end
  end

  if bestPair then
    return {
      pos = (bestPair[1].pos + bestPair[2].pos) / 2,
      camp1 = bestPair[1],
      camp2 = bestPair[2],
      gold = bestPairGold,
      score = bestPairScore,
      kind = "jungle"
    }
  end
  local bestSingle, bestSingleScore, bestSingleGold = nil, math.huge, 0
  for camp, _ in pairs(selectedSet) do
    local distScore   = myPos:Distance(camp.pos) / 100.0
    local gold        = Camp.GetGoldBounty(camp, true)
    local bountyScore = (gold / 50.0) * bountyK

    local anchorPos   = Tinker.IntendedKeenTPPos(camp.pos)
    local rSpot       = RiskAtPoint(camp.pos, enemyPts)
    local rAnchor     = RiskAtPoint(anchorPos, enemyPts)
    local rPath       = PathRisk(anchorPos, camp.pos, enemyPts)

    local riskLimit   = Constants.ENEMY_RISK_HARD_BLOCK
    local blockR      = Constants.ENEMY_RISK_BLOCK_RADIUS
    local score       = math.huge
    if (rSpot >= riskLimit) or (rAnchor >= riskLimit) or (rPath >= riskLimit)
        or AnyEnemyWithin(anchorPos, enemyPts, blockR) then
    else
      local riskPenalty = (wSpot * rSpot + wAnchor * rAnchor + wPath * rPath) * riskW
      score             = distScore + riskPenalty - bountyScore
    end
    if score < bestSingleScore then
      bestSingleScore, bestSingle, bestSingleGold = score, camp, gold
    end
  end
  if bestSingle then
    return {
      pos = bestSingle.pos,
      camp1 = bestSingle,
      single = true,
      gold = bestSingleGold,
      score = bestSingleScore,
      kind = "jungle"
    }
  end
  return nil
end

local function GetLaneDynamicSpotScore(spot)
  if not spot then return math.huge end
  local score = spot.score or 0
  local creepCount = spot.creepCount or (spot.camp1 and spot.camp1.creepCount) or 0
  local siegeCount = spot.siegeCount or (spot.camp1 and spot.camp1.siegeCount) or 0

  score = score - (Constants.LANE_DYNAMIC_SCORE_BIAS or 0)
  if State.PendingLaneRotate then
    score = score - 2.0
  end
  if creepCount <= 2 and siegeCount <= 0 then
    score = score + 2.5
  end
  return score
end

function Tinker.FindBestFarmSpot(excludeSpotKey)
  local enabledTargets = Config.ToFarm:ListEnabled() or {}
  local wantAncient, wantNonAnc, wantLane = false, false, false
  for _, name in ipairs(enabledTargets) do
    if name == L("target_ancients") then wantAncient = true end
    if name == L("target_non_ancients") then wantNonAnc = true end
    if name == L("target_lane") then wantLane = true end
  end
  if not (wantAncient or wantNonAnc or wantLane) then return nil end

  local laneSpot = wantLane and Tinker.FindBestLaneCreepSpot(excludeSpotKey) or nil
  if not (wantAncient or wantNonAnc) then
    return laneSpot
  end

  -- All enemies dead -> drop the jungle and hard-push lanes.
  if laneSpot and AllEnemiesDead() then return laneSpot end

  local jungleSpot = Tinker.FindBestJungleSpot(wantAncient, wantNonAnc)
  if jungleSpot and excludeSpotKey and SpotKey(jungleSpot) == excludeSpotKey then
    jungleSpot = nil
  end

  if not wantLane then return jungleSpot end
  if not jungleSpot then return laneSpot end
  if not laneSpot then return jungleSpot end

  local useDynamic = Config.Lane and Config.Lane.DynamicMixPriority and Config.Lane.DynamicMixPriority:Get()
  if not useDynamic then
    return jungleSpot or laneSpot
  end

  local laneScore = GetLaneDynamicSpotScore(laneSpot)
  local jungleScore = jungleSpot.score or math.huge
  laneSpot.score = laneScore

  if laneScore < jungleScore then
    return laneSpot
  end
  return jungleSpot
end

function Tinker.GetBestFarmSpotCached()
  local t = GameRules.GetGameTime()
  if State.CachedBestSpot and t - (State.LastSpotScan or 0) < Constants.SPOT_SCAN_INTERVAL then
    return State.CachedBestSpot
  end
  local best = Tinker.FindBestFarmSpot()
  if best and not best.camp2 then best.single = true end
  State.CachedBestSpot = best
  State.LastSpotScan   = t
  return best
end

local function ManaCost(ability) return (ability and Ability.GetManaCost(ability)) or 0 end

function Tinker.GetEscapeManaCost()
  local tpCost     = State.KeenTeleport and Ability.GetManaCost(State.KeenTeleport) or 0
  local keenReady  = State.KeenTeleport and Ability.CanBeExecuted(State.KeenTeleport) == -1
  local rearmCost  = State.Rearm and Ability.GetManaCost(State.Rearm) or 0
  local rearmReady = State.Rearm and Ability.CanBeExecuted(State.Rearm) == -1

  if keenReady then return tpCost end
  if rearmReady then return rearmCost + tpCost end
  return rearmCost + tpCost
end

function Tinker.GetCampCycleManaCost()
  local tp       = ManaCost(State.KeenTeleport)
  local march    = ManaCost(State.March)
  local rearm    = ManaCost(State.Rearm)
  local tpReady  = State.KeenTeleport and Ability.CanBeExecuted(State.KeenTeleport) == -1
  local preRearm = tpReady and 0 or rearm
  return preRearm + tp + march + rearm + march + tp
end

function Tinker.HasManaForFullCampCycle()
  if not State.KeenTeleport or not State.March or not State.Rearm then return true end
  local curMana = NPC.GetMana(State.Hero) or 0
  local maxMana = NPC.GetMaxMana(State.Hero) or 0
  local need    = Tinker.GetCampCycleManaCost()
  if need > maxMana then return curMana >= (maxMana * 0.9) end
  return curMana >= need
end

local function GetLaneRotateManaCost()
  if not (Config.Lane and Config.Lane.RotateAfterClear and Config.Lane.RotateAfterClear:Get()) then
    return 0
  end
  local tpCost = State.KeenTeleport and (Ability.GetManaCost(State.KeenTeleport) or 0) or 0
  if State.KeenTeleport and CanExecuteAbility(State.KeenTeleport) then
    return tpCost
  end
  if State.Rearm and CanExecuteAbility(State.Rearm) then
    return (Ability.GetManaCost(State.Rearm) or 0) + tpCost
  end
  return tpCost
end

function Tinker.HasManaForSpot(spot)
  if not spot or spot.kind ~= "lane" then
    return Tinker.HasManaForFullCampCycle()
  end
  if not State.March then return true end

  -- Require mana for the WHOLE lane burst: 1 laser + N marches (+Rearms) + escape.
  local curMana    = NPC.GetMana(State.Hero) or 0
  local escapeMana = Tinker.GetEscapeManaCost()
  local req        = math.max(1, ComputeRequiredMarchesForSpot(spot))
  local marchCost  = ManaCost(State.March)
  local rearmCost  = ManaCost(State.Rearm)
  local laserCost  = (Config.Lane and Config.Lane.UseLaser and Config.Lane.UseLaser:Get() and ManaCost(State.Laser)) or 0
  local needFull   = laserCost + req * marchCost + req * rearmCost + escapeMana

  return curMana >= needFull
end

function Tinker.NeedsToReturnToFountain()
  if not State.KeenTeleport then return false end
  local escapeMana = Tinker.GetEscapeManaCost()
  return (NPC.GetMana(State.Hero) or 0) < escapeMana
end

function Tinker.ShouldRequestTeleport(pos, force)
  if force then return true end
  local now = GameRules.GetGameTime()
  if now < (State.TeleportLockUntil or 0) then return false end

  local atFountain = HasFountainBuff()
  if not atFountain and now - (State.LastFarmTPAt or 0) < Constants.FARM_TP_MIN_INTERVAL then
    return false
  end

  local intended = Tinker.IntendedKeenTPPos(pos)

  if State.FarmState == "MOVING_TO_SPOT" and State.BlockTPThisSpot and State.LastSpotTelePos then
    if State.LastSpotTelePos:Distance(intended) <= Constants.SAME_SPOT_TP_EPS then return false end
  end

  if State.LastTeleportCastPos and State.LastTeleportCastPos:Distance(intended) <= Constants.SAME_SPOT_TP_EPS then
    if (now - (State.LastTeleportAt or 0)) < Constants.SAME_SPOT_TP_COOLDOWN then return false end
  end

  local myPos = Entity.GetAbsOrigin(State.Hero)
  if myPos:Distance(pos) <= intended:Distance(pos) then
    return false
  end
  if not Tinker.IsTeleportSafe(pos) then
    return false
  end

  return true
end

function Tinker.TryTeleportTo(pos, force)
  if not State.KeenTeleport then return false end
  if Ability.CanBeExecuted(State.KeenTeleport) ~= -1 then return false end
  local now = GameRules.GetGameTime()
  if not force and now < (State.TeleportLockUntil or 0) then return false end

  if not force and not Tinker.IsTeleportSafe(pos) then
    return false
  end

  local res      = Tinker.ResolveKeenTeleport(pos)
  local finalPos = res.finalPos
  local myPos    = Entity.GetAbsOrigin(State.Hero)

  if not force and myPos:Distance(finalPos) <= Constants.TP_MIN_DISTANCE then return false end
  if not force and myPos:Distance(pos) <= finalPos:Distance(pos) then return false end

  local issued = Utils.IssueOrder(res.castOrder, State.KeenTeleport, res.castData)
  if not issued then return false end

  State.LastTeleportAt      = now
  State.TeleportLockUntil   = now + Constants.POST_TP_LOCK_TIME
  State.LastTeleportCastPos = finalPos
  State.LastTeleportAnchor  = res.anchor or nil
  State.MovingAfterTeleport = true
  State.RecalcAfterTP       = true
  return true
end

-- Simulate "Alt+Keen Teleport" to home fountain: cast with no target.
function Tinker.TryTeleportHome(force)
  if not State.KeenTeleport then return false end
  if Ability.CanBeExecuted(State.KeenTeleport) ~= -1 then return false end
  local now = GameRules.GetGameTime()
  if not force and now < (State.TeleportLockUntil or 0) then return false end

  local issued = Utils.IssueOrder(Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET, State.KeenTeleport, nil)
  if not issued then return false end

  State.LastTeleportAt      = now
  State.TeleportLockUntil   = now + Constants.POST_TP_LOCK_TIME
  State.LastTeleportCastPos = Entity.GetAbsOrigin(State.Hero)
  State.LastTeleportAnchor  = nil
  State.MovingAfterTeleport = true
  State.RecalcAfterTP       = true
  return true
end

function Tinker.GetHomeFountainEntity()
  local now = GameRules.GetGameTime()
  if State.HomeFountain and Entity.IsEntity(State.HomeFountain) then
    if Entity.IsAlive(State.HomeFountain) and Entity.GetTeamNum(State.HomeFountain) == State.HeroTeam then
      return State.HomeFountain
    end
  end
  if (State.LastFountainScan or 0) > 0 and (now - (State.LastFountainScan or 0)) < 2.0 then
    return State.HomeFountain
  end
  State.LastFountainScan = now

  local structs = NPCs.GetAll(Enum.UnitTypeFlags.TYPE_STRUCTURE) or {}
  for _, e in ipairs(structs) do
    if e and Entity.IsEntity(e) and Entity.IsAlive(e) and Entity.GetTeamNum(e) == State.HeroTeam then
      local name = Entity.GetUnitName(e) or ""
      if string.find(name, "fountain") then
        State.HomeFountain = e
        return e
      end
    end
  end
  State.HomeFountain = nil
  return nil
end

function Tinker.TryTeleportToFountain(force)
  if not State.KeenTeleport then return false end
  if Ability.CanBeExecuted(State.KeenTeleport) ~= -1 then return false end
  local now = GameRules.GetGameTime()
  if not force and now < (State.TeleportLockUntil or 0) then return false end

  local fountain = Tinker.GetHomeFountainEntity()
  if fountain then
    local issued = Utils.IssueOrder(Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TARGET, State.KeenTeleport, fountain)
    if issued then
      State.LastTeleportAt      = now
      State.TeleportLockUntil   = now + Constants.POST_TP_LOCK_TIME
      State.LastTeleportCastPos = Entity.GetAbsOrigin(fountain)
      State.LastTeleportAnchor  = fountain
      State.MovingAfterTeleport = true
      State.RecalcAfterTP       = true
      return true
    end
  end

  local fountainPos = (State.HeroTeam == 2) and Constants.FOUNTAIN_RADIANT or Constants.FOUNTAIN_DIRE
  return Tinker.TryTeleportTo(fountainPos, force)
end

function Tinker.RequestTeleportToSpot(spot, force)
  if not spot then return false end
  local key        = SpotKey(spot)
  local now        = GameRules.GetGameTime()
  local atFountain = HasFountainBuff()
  local wantForce  = force or atFountain

  if State.TargetSpotKey and key ~= State.TargetSpotKey then
    if not wantForce and now < (State.SpotCommitUntil or 0) then return false end
  end

  if not Tinker.ShouldRequestTeleport(spot.pos, wantForce) and not wantForce then return false end

  if State.KeenTeleport and Ability.CanBeExecuted(State.KeenTeleport) == -1 then
    local started = Tinker.TryTeleportTo(spot.pos, wantForce)
    if started then
      State.TargetSpotKey   = key
      State.SpotCommitUntil = now + Constants.SPOT_COMMIT_TIME
      if State.FarmState == "MOVING_TO_SPOT" then
        State.BlockTPThisSpot = true
        State.LastSpotTelePos = Tinker.IntendedKeenTPPos(spot.pos)
      end
      State.LastFarmTPAt = now
      return true
    else
      State.PendingTPPos   = spot.pos
      State.PendingTPSince = now
      State.PendingTPForce = wantForce
      return true
    end
  end
  if State.Rearm
      and Ability.CanBeExecuted(State.Rearm) == -1
      and State.KeenTeleport
      and Ability.CanBeExecuted(State.KeenTeleport) ~= -1 then
    local needMana = (Ability.GetManaCost(State.Rearm) or 0) + (Ability.GetManaCost(State.KeenTeleport) or 0)
    if (NPC.GetMana(State.Hero) or 0) >= needMana then
      State.PendingTPPos   = spot.pos
      State.PendingTPSince = now
      State.PendingTPForce = wantForce
      if Utils.CastAbility(State.Rearm, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET, nil) then
        MarkRearmIssued(now)
        State.TargetSpotKey   = key
        State.SpotCommitUntil = now + Constants.SPOT_COMMIT_TIME
      end
      return true
    end
  end

  return false
end

local function RequiredManaBeforeCommit(spot)
  spot = spot or State.CurrentFarmSpot
  local escapeMana = Tinker.GetEscapeManaCost()
  if spot and spot.kind == "lane" then
    local req       = math.max(1, ComputeRequiredMarchesForSpot(spot))
    local marchCost = ManaCost(State.March)
    local rearmCost = ManaCost(State.Rearm)
    local laserCost = (Config.Lane and Config.Lane.UseLaser and Config.Lane.UseLaser:Get() and ManaCost(State.Laser)) or 0
    return laserCost + req * marchCost + req * rearmCost + escapeMana
  end
  local marchCost = State.March and (Ability.GetManaCost(State.March) or 0) or 0
  return marchCost + escapeMana
end
function Tinker.HandleAutoBottle()
  if not Config.ItemsToUse:Get(L("item_bottle")) or State.IsChanneling then return end

  local t = GameRules.GetGameTime()
  if t < (State.NextBottleCheck or 0) then return end
  State.NextBottleCheck = t + Constants.BOTTLE_CHECK_COOLDOWN

  local bottle = NPC.GetItem(State.Hero, "item_bottle", true)
  if not bottle or Ability.CanBeExecuted(bottle) ~= -1 or Item.GetCurrentCharges(bottle) <= 0 then return end
  if NPC.HasModifier(State.Hero, "modifier_bottle_regeneration") then return end

  local hpMissing   = Entity.GetMaxHealth(State.Hero) - Entity.GetHealth(State.Hero)
  local manaMissing = NPC.GetMaxMana(State.Hero) - NPC.GetMana(State.Hero)

  if hpMissing >= Constants.BOTTLE_MISSING_THRESHOLD
      or manaMissing >= Constants.BOTTLE_MISSING_THRESHOLD then
    Utils.CastAbility(bottle, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET, nil)
  end
end

local function CountCampAliveCreeps(camp)
  if not camp then return 0 end
  if camp.kind == "lane_wave" then
    return RefreshLaneCamp(camp) or 0
  end

  if type(camp.alive_creeps) == "table" then
    local cnt = 0
    for _, unit in pairs(camp.alive_creeps) do
      if unit and Entity.IsEntity(unit) and Entity.IsAlive(unit) then
        cnt = cnt + 1
      end
    end

    if cnt > 0 then
      return cnt
    end


  end

  return CountCampAliveCreepsByScan(camp)
end

local function GetBlinkCastRangeLimit()
  return Constants.BLINK_CAST_RANGE or Constants.BLINK_MAX_RANGE or 1200
end

local function GetLaneHeroPos()
  return State.Hero and Entity.GetAbsOrigin(State.Hero) or nil
end

local function GetLaneValueUnits(spot)
  if not spot or spot.kind ~= "lane" or not spot.camp1 then
    return {}, { count = 0, siege = 0, ranged = 0, hasSiege = false, hasRanged = false, best = nil }
  end

  RefreshLaneCamp(spot.camp1)

  local rows = {}
  local stats = { count = 0, siege = 0, ranged = 0, hasSiege = false, hasRanged = false, best = nil }
  for _, unit in ipairs(spot.camp1.alive_creeps or {}) do
    if unit and Entity.IsEntity(unit) and Entity.IsAlive(unit) then
      local p = Entity.GetAbsOrigin(unit)
      if p then
        local isSiege = IsSiegeLikeLaneCreep(unit)
        local isRanged = (NPC.IsRanged and NPC.IsRanged(unit)) or false
        local hp = Entity.GetHealth(unit) or 0
        local row = { unit = unit, pos = p, hp = hp, isSiege = isSiege, isRanged = isRanged }
        table.insert(rows, row)
        stats.count = stats.count + 1
        if isSiege then
          stats.siege = stats.siege + 1
          stats.hasSiege = true
        end
        if isRanged then
          stats.ranged = stats.ranged + 1
          stats.hasRanged = true
        end
      end
    end
  end

  local function rank(row)
    if row.isSiege then return 3000 + row.hp end
    if row.isRanged then return 2000 + row.hp end
    return 1000 + row.hp
  end

  for _, row in ipairs(rows) do
    if (not stats.best) or rank(row) > rank(stats.best) then
      stats.best = row
    end
  end

  spot.creepCount = stats.count
  spot.siegeCount = stats.siege
  if spot.camp1 then
    spot.camp1.creepCount = stats.count
    spot.camp1.siegeCount = stats.siege
  end

  return rows, stats
end

local function AbilityTargetRange(ability)
  local base = (ability and Ability.GetCastRange and Ability.GetCastRange(ability)) or 0
  local bonus = (State.Hero and NPC.GetCastRangeBonus and NPC.GetCastRangeBonus(State.Hero)) or 0
  return (base or 0) + (bonus or 0)
end

local function LaneRotateReserveMana()
  local reserve = GetLaneRotateManaCost()
  if reserve <= 0 then return 0 end
  return reserve
end

local function FindNearestEnemyPoint(pt, enemyPts)
  local bestPos, bestDist = nil, math.huge
  for _, ep in ipairs(enemyPts or {}) do
    local d = pt:Distance(ep)
    if d < bestDist then
      bestDist = d
      bestPos = ep
    end
  end
  return bestPos, bestDist
end

local function GetLaneBlinkPreferredDir(castPos, mode, enemyPts)
  local heroPos = GetLaneHeroPos()
  local ref = nil
  local nearestEnemy = FindNearestEnemyPoint(castPos, enemyPts)

  if mode == "retreat" then
    if nearestEnemy then
      ref = castPos - nearestEnemy
    else
      local fountainPos = (State.HeroTeam == 2) and Constants.FOUNTAIN_RADIANT or Constants.FOUNTAIN_DIRE
      ref = fountainPos - castPos
    end
  else
    if nearestEnemy then
      ref = castPos - nearestEnemy
    elseif heroPos then
      ref = heroPos - castPos
    end
  end

  if not ref then return nil end
  local len = ref:Length()
  if len < 1 then return nil end
  return ref:Normalized()
end

local function IsLaneTreeCandidateValid(candidate, castPos, mode, enemyPts)
  if not candidate or not castPos or not State.Hero then return false end
  if not (GridNav and GridNav.IsTraversable and GridNav.IsBlocked and GridNav.IsNearbyTree) then return false end
  if not GridNav.IsTraversable(candidate) then return false end
  if GridNav.IsBlocked(candidate) then return false end
  if not GridNav.IsNearbyTree(candidate, Constants.LANE_TREE_NEARBY_RADIUS or 140) then return false end

  local myPos = Entity.GetAbsOrigin(State.Hero)
  if myPos:Distance(candidate) > (GetBlinkCastRangeLimit() + 24) then return false end

  local dWave = candidate:Distance(castPos)
  local minWave = Constants.LANE_TREE_MIN_WAVE_DIST or 420
  local maxWave = (mode == "retreat") and (Constants.LANE_RETREAT_TREE_SEARCH_RADIUS or 1100) or
      (Constants.LANE_TREE_MAX_WAVE_DIST or 900)
  if dWave < minWave or dWave > maxWave then return false end

  if mode == "approach" and dWave > (Constants.MARCH_CAST_RANGE or 900) then return false end

  local riskLimit = Constants.ENEMY_RISK_HARD_BLOCK or 0.45
  local blockR = Constants.ENEMY_RISK_BLOCK_RADIUS or 1000
  if RiskAtPoint(candidate, enemyPts or {}) >= riskLimit then return false end
  if AnyEnemyWithin(candidate, enemyPts or {}, blockR) then return false end

  return true
end

local function FindLaneTreeBlinkPos(castPos, mode)
  if not castPos or not State.Hero or not State.Blink then return nil end
  if not (GridNav and GridNav.IsTraversable and GridNav.IsBlocked and GridNav.IsNearbyTree) then return nil end

  local now = GameRules.GetGameTime()
  local myPos = Entity.GetAbsOrigin(State.Hero)
  local enemyPts = Tinker.GetEnemyLastKnownPositions()
  local cacheKey = string.format("%s:%s", tostring(mode or "approach"), MakeLaneBucketIndex(castPos))
  State.LaneTreeBlinkCache = State.LaneTreeBlinkCache or {}
  local cached = State.LaneTreeBlinkCache[cacheKey]
  if cached and (now - (cached.at or 0)) <= (Constants.LANE_TREE_CACHE_TTL or 0.20) then
    if cached.pos and IsLaneTreeCandidateValid(cached.pos, castPos, mode, enemyPts) then
      return cached.pos
    end
  end

  local prefDir = GetLaneBlinkPreferredDir(castPos, mode, enemyPts)
  local desiredWaveDist = (mode == "retreat") and 760 or 620
  local blinkRange = GetBlinkCastRangeLimit()
  local rings = Constants.LANE_TREE_CANDIDATE_RINGS or { 460, 600, 760, 880 }
  local stepDeg = Constants.LANE_TREE_CANDIDATE_ANGLE_STEP or 20
  local bestPos, bestScore = nil, math.huge

  for _, r in ipairs(rings) do
    local deg = 0
    while deg < 360 do
      local rad = math.rad(deg)
      local candidate = Vector((castPos.x or 0) + math.cos(rad) * r, (castPos.y or 0) + math.sin(rad) * r, castPos.z or 0)
      if myPos:Distance(candidate) <= (blinkRange + 24)
          and IsLaneTreeCandidateValid(candidate, castPos, mode, enemyPts) then
        local v = candidate - castPos
        local vLen = v:Length()
        local dirPenalty = 0
        if prefDir and vLen > 0 then
          local vd = v / vLen
          local dot = (vd.x or 0) * (prefDir.x or 0) + (vd.y or 0) * (prefDir.y or 0)
          dirPenalty = (1 - dot) * 60
        end
        local risk = RiskAtPoint(candidate, enemyPts)
        local waveDist = candidate:Distance(castPos)
        local score = risk * 1000
            + math.abs(waveDist - desiredWaveDist) * 0.25
            + dirPenalty
            + myPos:Distance(candidate) * (mode == "approach" and -0.03 or 0.02)
        if score < bestScore then
          bestScore = score
          bestPos = candidate
        end
      end
      deg = deg + stepDeg
    end
  end

  State.LastLaneTreeSearchAt = now
  State.LaneTreeBlinkCache[cacheKey] = { at = now, pos = bestPos }
  return bestPos
end

local function TryLaneRetreatBlink(spot, castInfo)
  if not (spot and spot.kind == "lane" and castInfo and castInfo.pos) then return false end
  if not (Config.Lane and Config.Lane.Advanced and Config.Lane.Advanced:Get()) then return false end
  if not (Config.Lane.TreeBlinkRetreat and Config.Lane.TreeBlinkRetreat:Get()) then return false end
  if State.PendingTPPos ~= nil then return false end
  if HasFountainBuff() then return false end

  local holdBlink = IsBlinkLockedNow()
  if holdBlink then return false end
  if not (Config.ItemsToUse:Get(L("item_blink")) and Config.Blink and Config.Blink.Travel and Config.Blink.Travel:Get()) then
    return false
  end
  if not (State.Blink and CanExecuteAbility(State.Blink)) then return false end

  local _, stats = GetLaneValueUnits(spot)
  local nearClear = stats.count <= math.max(2, (Constants.LANE_ROTATE_MIN_CREEPS_LEFT or 1) + 1)
      or (stats.count <= 3 and not stats.hasSiege and not stats.hasRanged)
  if not nearClear then return false end

  local now = GameRules.GetGameTime()
  if (now - (State.LastLaneRetreatBlinkAt or 0)) < 0.45 then return false end

  local pos = FindLaneTreeBlinkPos(castInfo.pos, "retreat")
  if not pos then return false end

  if Utils.CastAbility(State.Blink, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION, pos) then
    State.LastLaneRetreatBlinkAt = now
    return true
  end
  return false
end

local function TryLaneBurstAction(spot, castInfo)
  if not (spot and spot.kind == "lane" and castInfo and castInfo.pos) then return false end
  if not (Config.Lane and Config.Lane.Advanced and Config.Lane.Advanced:Get()) then return false end
  if State.IsChanneling then return false end

  local now = GameRules.GetGameTime()
  if (now - (State.LastLaneBurstAt or 0)) < (Constants.LANE_BURST_GAP or 0.10) then return false end

  local rows, stats = GetLaneValueUnits(spot)
  if stats.count <= 0 then return false end

  local myPos = Entity.GetAbsOrigin(State.Hero)
  local curMana = NPC.GetMana(State.Hero) or 0
  local escapeReserve = Tinker.GetEscapeManaCost()
  local rotateReserve = LaneRotateReserveMana()
  local canMarchNow = State.March and CanExecuteAbility(State.March)

  local wantShiva = Config.ItemsToUse:Get(L("item_shivas_guard"))
  if wantShiva and State.Shiva and CanExecuteAbility(State.Shiva) then
    local shivaRad = (Ability.GetAOERadius and Ability.GetAOERadius(State.Shiva)) or 900
    local shivaCost = Ability.GetManaCost(State.Shiva) or 0
    local canAfford = (curMana - shivaCost) >= escapeReserve
    if canAfford and myPos:Distance(castInfo.pos) <= math.max(700, shivaRad - 60) then
      if Utils.CastAbility(State.Shiva, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET, nil) then
        State.LastLaneBurstAt = now
        return true
      end
    end
  end

  if Config.ItemsToUse:Get(L("item_meteor_hammer"))
    and State.Meteor and CanExecuteAbility(State.Meteor) then
  local meteorCost = Ability.GetManaCost(State.Meteor) or 0
  local meteorRad  = 315
  local canAfford  = (curMana - meteorCost) >= escapeReserve
  if canAfford
      and myPos:Distance(castInfo.pos) <= (meteorRad + 600) then
    if Utils.CastAbility(
        State.Meteor,
        Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION,
        castInfo.pos
    ) then
      State.LastLaneBurstAt = now
      return true
    end
  end
end

  local target = (stats.best and stats.best.unit) or (rows[1] and rows[1].unit) or nil
  local targetPos = target and Entity.GetAbsOrigin(target) or nil

  if Config.Lane.UseLaser and Config.Lane.UseLaser:Get()
      and State.Laser
      and not State.LaneBurstLaserDone
      and CanExecuteAbility(State.Laser) then
    local laserCost  = Ability.GetManaCost(State.Laser) or 0
    local laserRange = math.max(600, AbilityTargetRange(State.Laser))
    -- Best target that is actually IN range (priority, else any creep).
    local bestRow, bestRank = nil, -math.huge
    for _, row in ipairs(rows) do
      if row.unit and row.pos and myPos:Distance(row.pos) <= (laserRange + 32) then
        local r = row.isSiege and (3000 + row.hp) or (row.isRanged and (2000 + row.hp) or (1000 + row.hp))
        if r > bestRank then bestRank, bestRow = r, row end
      end
    end
    if bestRow and bestRow.unit and (curMana - laserCost) >= escapeReserve then
      if Utils.CastAbility(State.Laser, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TARGET, bestRow.unit) then
        State.LastLaneBurstAt = now
        State.LaneBurstLaserDone = true
        return true
      end
    end
  end

  if Config.ItemsToUse:Get(L("item_dagon"))
      and State.Dagon and target and targetPos
      and CanExecuteAbility(State.Dagon) then
    local dagonCost = Ability.GetManaCost(State.Dagon) or 0
    local dagonRange = math.max(600, AbilityTargetRange(State.Dagon))
    local targetDist = myPos:Distance(targetPos)
    local maxCreeps = Constants.LANE_DAGON_USE_MAX_CREEPS or 2
    local needReserve = escapeReserve + (Config.Lane.RotateAfterClear:Get() and
        (rotateReserve + (Constants.LANE_DAGON_MIN_ROTATE_MANA_BUFFER or 35)) or 0)
    if stats.count <= maxCreeps and targetDist <= (dagonRange + 32) and (curMana - dagonCost) >= needReserve then
      if Utils.CastAbility(State.Dagon, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TARGET, target) then
        State.LastLaneBurstAt = now
        return true
      end
    end
  end

  return false
end

local function LaneSpotShouldRotate(spot)
  if not (spot and spot.kind == "lane" and spot.camp1) then return false end
  local alive = CountCampAliveCreeps(spot.camp1)
  if alive <= (Constants.LANE_ROTATE_MIN_CREEPS_LEFT or 1) then
    return true
  end

  local _, stats = GetLaneValueUnits(spot)
  if stats.count <= 0 then return true end
  if stats.count <= 2 and (not stats.hasSiege) and (not stats.hasRanged) then return true end
  return false
end

function Tinker.TryRotateAfterLaneClear(spot)
  if not (Config.Lane and Config.Lane.Advanced and Config.Lane.Advanced:Get()) then return false end
  if not (Config.Lane.RotateAfterClear and Config.Lane.RotateAfterClear:Get()) then return false end

  local curSpot = spot or State.CurrentFarmSpot
  if not (curSpot and curSpot.kind == "lane") then return false end
  if not LaneSpotShouldRotate(curSpot) then return false end

  -- Don't come back to this lane for a while after clearing it.
  if curSpot.pos then
    State.LaneBurstPos   = Vector(curSpot.pos.x, curSpot.pos.y, curSpot.pos.z)
    State.LaneBurstUntil = GameRules.GetGameTime() + 13.0
  end

  local now = GameRules.GetGameTime()
  local curKey = SpotKey(curSpot)
  State.PendingLaneRotate = true
  State.LastLaneSpotKey = curKey
  State.CachedBestSpot = nil
  State.LastSpotScan = 0

  local nextSpot = Tinker.FindBestFarmSpot(curKey)
  State.PendingLaneRotate = false

  if not nextSpot then
    return false
  end

  if not Tinker.HasManaForSpot(nextSpot) then
    State.FarmState                = "RETURNING_TO_FOUNTAIN"
    State.CurrentFarmSpot          = nil
    State.AfterMarchCheck          = nil
    State.TargetSpotKey            = nil
    State.SpotCommitUntil          = 0
    State.CurrentSpotMarchCasts    = 0
    State.CurrentSpotMarchRequired = nil
    return true
  end

  State.CurrentFarmSpot       = nextSpot
  State.TargetSpotKey         = SpotKey(nextSpot)
  State.SpotCommitUntil       = now + Constants.SPOT_COMMIT_TIME
  State.BlockTPThisSpot       = false
  State.LastSpotTelePos       = nil
  State.MovingAfterTeleport   = false
  State.RecalcAfterTP         = false
  State.AfterMarchCheck       = nil
  State.LastMarchCastAt       = 0
  State.CurrentSpotMarchCasts = 0
  State.LaneBurstLaserDone    = false
  if Config.MarchControl.UseCustom:Get() then
    State.CurrentSpotMarchRequired = ComputeRequiredMarchesForSpot(nextSpot)
    if (State.CurrentSpotMarchRequired or 0) <= 0 then
      State.CurrentSpotMarchRequired = nil
      return false
    end
  else
    State.CurrentSpotMarchRequired = nil
  end
  if Constants.LANE_ROTATE_BYPASS_IDLE_DELAY then
    State.JustClearedSpotAt = 0
  else
    State.JustClearedSpotAt = now
  end
  State.FarmState = "MOVING_TO_SPOT"
  return true
end

function Tinker.ProcessAfterMarchCheck()
  local am = State.AfterMarchCheck
  if not am then return end

  local t            = GameRules.GetGameTime()
  local minTime      = Constants.CAMP_CLEAR_DELAY
  local confirmWin   = Constants.CAMP_CLEAR_CONFIRM_DELAY
  local begunConfirm = (t - (am.startedAt or 0)) >= minTime

  if am.camp1 then
    local c1 = CountCampAliveCreeps(am.camp1)
    if c1 > 0 then
      am.zeroSince1 = nil
    else
      if begunConfirm then
        am.zeroSince1 = am.zeroSince1 or t
        if (t - am.zeroSince1) >= confirmWin then
          MarkCampFarmed(am.camp1, t)
        end
      end
    end
  end

  if am.camp2 then
    local c2 = CountCampAliveCreeps(am.camp2)
    if c2 > 0 then
      am.zeroSince2 = nil
    else
      if begunConfirm then
        am.zeroSince2 = am.zeroSince2 or t
        if (t - am.zeroSince2) >= confirmWin then
          MarkCampFarmed(am.camp2, t)
        end
      end
    end
  end

  local cleared = (am.camp1 and am.camp1.farmed or false)
      and ((not am.camp2) or (am.camp2 and am.camp2.farmed))

  if cleared then
    local clearedSpot = State.CurrentFarmSpot
    State.AfterMarchCheck = nil
    if State.FarmState == "FARMING_SPOT" then
      if clearedSpot and clearedSpot.kind == "lane" and Tinker.TryRotateAfterLaneClear(clearedSpot) then
        return
      end
      State.FarmState                = "IDLE"
      State.CurrentFarmSpot          = nil
      State.JustClearedSpotAt        = GameRules.GetGameTime()
      State.CurrentSpotMarchCasts    = 0
      State.CurrentSpotMarchRequired = nil
    end
  end
end

-- TryCastMatrix removed: Defense Matrix auto-cast replaced by Deploy Turrets double-tap (OnKeyEvent).
local function TryCastMatrix(_mode) return false end

function Tinker.HandlePanic()
  if not State.Hero then return false end

  local now    = GameRules.GetGameTime()
  local hp     = Entity.GetHealth(State.Hero) or 0
  local maxHp  = Entity.GetMaxHealth(State.Hero) or 1
  local hpFrac = hp / math.max(1, maxHp)
  if State.LastHP == nil or State.LastHPTime == nil then
    State.LastHP     = hp
    State.LastHPTime = now
    return false
  end

  local lowHP = hpFrac <= Constants.PANIC_HP_FRAC
  if lowHP then
    State.PanicArmingSince = State.PanicArmingSince or now
  else
    State.PanicArmingSince = nil
    return false
  end

  local armed      = State.PanicArmingSince and (now - State.PanicArmingSince) >= Constants.PANIC_ARM_TIME
  local canTrigger = now >= (State.PanicCooldownUntil or 0)
  if not (armed and canTrigger) then return false end

  State.PanicCooldownUntil = now + Constants.PANIC_COOLDOWN
  State.PanicReason        = lowHP and "lowHP" or "hpDPS"
  State.FarmState          = "RETURNING_TO_FOUNTAIN"
  State.AfterMarchCheck    = nil
  State.TargetSpotKey      = nil
  State.SpotCommitUntil    = 0

  -- Team 2 = Radiant, Team 3 = Dire
  local fountainPos        = (State.HeroTeam == 2) and Constants.FOUNTAIN_RADIANT or Constants.FOUNTAIN_DIRE

  if State.IsChanneling then
    State.PendingTPPos   = fountainPos
    State.PendingTPSince = now
    State.PendingTPForce = true
    return true
  end
  TryCastMatrix("panic")

  if Tinker.TryTeleportTo(fountainPos, true) then
    State.LastFarmTPAt = now
    return true
  end

  -- Never блинкаемся, если уже на фонтане (по баффу).
  if not HasFountainBuff()
      and Config.ItemsToUse:Get(L("item_blink"))
      and Config.Blink.Escape:Get()
      and State.Blink
      and Ability.CanBeExecuted(State.Blink) == -1 then
    local myPos      = Entity.GetAbsOrigin(State.Hero)
    local toFountain = (fountainPos - myPos)
    local dist       = toFountain:Length()
    local blinkRange = GetBlinkCastRangeLimit()
    local blinkPos   = dist > blinkRange
        and (myPos + toFountain:Normalized() * blinkRange) or fountainPos
    Utils.CastAbility(State.Blink, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION, blinkPos)
  end

  Utils.MoveTo(fountainPos)
  return true
end

local function ComputeSafeBlinkPos(targetPos)
  if not State.Hero then return nil end
  local myPos = Entity.GetAbsOrigin(State.Hero)
  local dir   = (targetPos - myPos)
  local dist  = dir:Length()
  if dist <= Constants.BLINK_MIN_DISTANCE then return nil end
  local ndir     = dir:Normalized()
  local standOff = Constants.BLINK_SAFE_STANDOFF
  local maxStep  = GetBlinkCastRangeLimit()
  local desired  = math.max(dist - standOff, 0)
  local step     = math.min(maxStep, desired > 0 and desired or dist)
  return myPos + ndir * step
end

-- ── Auto Wisdom Shrine (npc_dota_xp_fountain) ────────────────
-- Spawns at 7:00 and every 7 min; only goes when the shrine is active.
local WISDOM = {
  firstSpawn       = 420,
  interval         = 420,
  postSpawnTimeout = 90,
  discoveryRetry   = 5,
  arrivalRadius    = 250,
  shrineName       = "npc_dota_xp_fountain",
}

local WisdomState = {
  shrine           = nil,
  position         = nil,
  nextDiscoveryAt  = 0,
  spawnAt          = nil,
  phase            = "idle",
  completedSpawnAt = nil,
  sawActive        = false,
}

local function WisdomDotaTime()
  local t = (GameRules.GetDOTATime and GameRules.GetDOTATime()) or nil
  if t == nil then return nil end
  return math.max(0, t)
end

local function WisdomPositionMatchesSide(pos)
  if pos == nil then return false end
  if State.HeroTeam == 2 then return pos.x < 0 end
  if State.HeroTeam == 3 then return pos.x > 0 end
  return false
end

local function WisdomShrineValid(shrine)
  return shrine ~= nil and Entity.IsEntity(shrine)
      and Entity.GetUnitName(shrine) == WISDOM.shrineName
end

local function WisdomDiscoverPosition(now)
  if WisdomShrineValid(WisdomState.shrine) then
    local p = Entity.GetAbsOrigin(WisdomState.shrine)
    if p then
      WisdomState.position = Vector(p.x, p.y, p.z)
      return WisdomState.position
    end
  else
    WisdomState.shrine = nil
  end

  if now >= WisdomState.nextDiscoveryAt then
    WisdomState.nextDiscoveryAt = now + WISDOM.discoveryRetry
    for _, npc in ipairs(NPCs.GetAll() or {}) do
      if npc and Entity.IsEntity(npc) then
        local nm = Entity.GetUnitName(npc)
        if nm == WISDOM.shrineName then
          local p = Entity.GetAbsOrigin(npc)
          if p and WisdomPositionMatchesSide(p) then
            WisdomState.shrine   = npc
            WisdomState.position = Vector(p.x, p.y, p.z)
            break
          end
        end
      end
    end
  end
  return WisdomState.position
end

local function WisdomSpawnForTime(dotaTime)
  if dotaTime < WISDOM.firstSpawn then
    if WisdomState.completedSpawnAt == WISDOM.firstSpawn then
      return WISDOM.firstSpawn + WISDOM.interval
    end
    return WISDOM.firstSpawn
  end
  local elapsed = dotaTime - WISDOM.firstSpawn
  local spawnAt = WISDOM.firstSpawn + math.floor(elapsed / WISDOM.interval) * WISDOM.interval
  if WisdomState.completedSpawnAt == spawnAt or dotaTime > spawnAt + WISDOM.postSpawnTimeout then
    return spawnAt + WISDOM.interval
  end
  return spawnAt
end

local function WisdomShrineActive()
  local shrine = WisdomState.shrine
  if shrine and Entity.IsEntity(shrine) then
    local ok, active = pcall(Entity.GetField, shrine, "m_bActive")
    if ok and type(active) == "boolean" then return active end
    if ok and type(active) == "number" then return active ~= 0 end
  end
  return nil
end

local function WisdomFinish()
  WisdomState.completedSpawnAt = WisdomState.spawnAt or WisdomState.completedSpawnAt
  WisdomState.phase     = "idle"
  WisdomState.spawnAt   = nil
  WisdomState.sawActive = false
end

function Tinker.HandleWisdomRune()
  if not (Config.WisdomRune and Config.WisdomRune:Get()) then
    if WisdomState.phase ~= "idle" then WisdomFinish() end
    return false
  end
  if not State.Hero or not Entity.IsAlive(State.Hero) then return false end
  if State.IsChanneling then return false end

  local now      = GameRules.GetGameTime()
  local dotaTime = WisdomDotaTime()
  if dotaTime == nil then return false end

  if WisdomState.spawnAt ~= nil and dotaTime > WisdomState.spawnAt + WISDOM.postSpawnTimeout then
    WisdomFinish()
    return false
  end

  local spawnAt = WisdomSpawnForTime(dotaTime)

  WisdomDiscoverPosition(now)
  local dest = WisdomState.position

  local active = nil
  if dest ~= nil then
    active = WisdomShrineActive()
    if active == true then WisdomState.sawActive = true end
  end

  local canGo = (active == true) or (active == nil and dotaTime >= spawnAt)
  if not canGo then
    if WisdomState.spawnAt ~= nil then
      WisdomFinish()
    end
    return false
  end

  if dest == nil then return false end

  local enemyPts = Tinker.GetEnemyLastKnownPositions()
  if AnyEnemyWithin(dest, enemyPts, Constants.ENEMY_RISK_BLOCK_RADIUS or 1000) then
    return false
  end

  if WisdomState.spawnAt == nil then
    WisdomState.spawnAt     = spawnAt
    WisdomState.phase       = "approach"
    State.FarmState         = "IDLE"
    State.CurrentFarmSpot   = nil
    State.AfterMarchCheck   = nil
    State.PendingTPPos      = nil
    State.PendingLaneRotate = false
  end

  local myPos = Entity.GetAbsOrigin(State.Hero)
  local dist  = myPos:Distance(dest)

  if dist > WISDOM.arrivalRadius then
    if dist > Constants.TP_MIN_DISTANCE
        and State.KeenTeleport and Ability.CanBeExecuted(State.KeenTeleport) == -1
        and Tinker.IsTeleportSafe(dest) then
      if Tinker.TryTeleportTo(dest, false) then
        State.LastFarmTPAt = now
        return true
      end
    end
    if State.KeenTeleport and Ability.CanBeExecuted(State.KeenTeleport) ~= -1
        and State.Rearm and Ability.CanBeExecuted(State.Rearm) == -1 then
      if Utils.CastAbility(State.Rearm, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET, nil) then
        MarkRearmIssued(now)
        return true
      end
    end
    if State.Blink and Ability.CanBeExecuted(State.Blink) == -1
        and Config.ItemsToUse:Get(L("item_blink"))
        and Config.Blink and Config.Blink.Travel and Config.Blink.Travel:Get()
        and not IsBlinkLockedNow() then
      local bp = ComputeSafeBlinkPos(dest)
      if bp and Utils.CastAbility(State.Blink, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION, bp) then
        return true
      end
    end
    Utils.MoveTo(dest)
    return true
  end

  WisdomState.phase = (active == true) and "claim" or "wait"
  Utils.MoveTo(dest)
  return true
end

-- ── Lane exit: blink toward base / into trees (or away from enemy), then TP ──
local function LaneExitBlinkPos()
  local heroPos  = Entity.GetAbsOrigin(State.Hero)
  local fountain = (State.HeroTeam == 2) and Constants.FOUNTAIN_RADIANT or Constants.FOUNTAIN_DIRE
  local castPos  = (State.CurrentFarmSpot and State.CurrentFarmSpot.pos) or heroPos

  -- Direction: away from a nearby VISIBLE enemy hero; if none -> toward base.
  local dir = nil
  local nearestPos, nearestD = nil, math.huge
  for _, h in ipairs(Heroes.GetAll() or {}) do
    if h and h ~= State.Hero and Entity.IsEntity(h) and Entity.IsAlive(h)
        and Entity.GetTeamNum(h) ~= State.HeroTeam
        and not Entity.IsDormant(h)
        and (not NPC.IsIllusion or not NPC.IsIllusion(h)) then
      local p = Entity.GetAbsOrigin(h)
      if p then
        local d = heroPos:Distance(p)
        if d <= 1600 and d < nearestD then nearestD, nearestPos = d, p end
      end
    end
  end
  if nearestPos then
    local away = heroPos - nearestPos
    if away:Length() > 1 then dir = away:Normalized() end
  end
  -- No enemy hero nearby -> prefer blinking under a nearby friendly tower.
  if not dir then
    local bestT, bestD = nil, math.huge
    for _, tw in ipairs(Towers.GetAll() or {}) do
      if tw and Entity.IsEntity(tw) and Entity.IsAlive(tw)
          and Entity.GetTeamNum(tw) == State.HeroTeam then
        local p = Entity.GetAbsOrigin(tw)
        if p then
          local d = heroPos:Distance(p)
          if d <= 2200 and d < bestD then bestD, bestT = d, p end
        end
      end
    end
    if bestT then
      local toTower = bestT - heroPos
      if toTower:Length() > 1 then dir = toTower:Normalized() end
    end
  end
  if not dir then
    local toFountain = fountain - heroPos
    if toFountain:Length() > 1 then dir = toFountain:Normalized() end
  end
  if not dir then return nil end

  -- Prefer a tree spot that goes in the desired direction.
  local pos = FindLaneTreeBlinkPos(castPos, "retreat")
  if pos then
    local v    = pos - heroPos
    local vLen = v:Length()
    if vLen > 1 and (v / vLen):Dot(dir) > 0.2 then return pos end
  end
  return heroPos + dir * (GetBlinkCastRangeLimit() * 0.9)
end

-- Blink for escapes: bypasses the order throttle so it fires right after marches.
local function EscapeBlink(pos)
  if not (State.Blink and pos) then return false end
  if Ability.CanBeExecuted(State.Blink) ~= -1 then return false end
  State.RearmBlinkHoldPending = false
  State.RearmBlinkChannelSeen = false
  Player.PrepareUnitOrders(
    State.Player, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION, nil, pos, State.Blink,
    Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_HERO_ONLY, State.Hero,
    false, false, false, true, false, false
  )
  return true
end

-- ── Emergency escape: enemy hero near us (or the pack) -> blink away + TP ──
local EMERGENCY_ENEMY_RADIUS = 1250

local function NearestEnemyHeroPos(pos, radius)
  if not pos then return nil end
  local best, bestD = nil, radius or EMERGENCY_ENEMY_RADIUS
  for _, h in ipairs(Heroes.GetAll() or {}) do
    if h and h ~= State.Hero and Entity.IsEntity(h) and Entity.IsAlive(h)
        and Entity.GetTeamNum(h) ~= State.HeroTeam
        and not Entity.IsDormant(h)
        and (not NPC.IsIllusion or not NPC.IsIllusion(h)) then
      local p = Entity.GetAbsOrigin(h)
      if p then
        local d = pos:Distance(p)
        if d <= bestD then bestD, best = d, p end
      end
    end
  end
  return best
end

function Tinker.ProcessEmergencyEscape()
  local enabled = Config.LaneExtras and Config.LaneExtras.BlinkTpNearEnemy
      and Config.LaneExtras.BlinkTpNearEnemy:Get()
  local ex = State.EmergencyEscape

  if not ex then
    if not enabled then return false end
    if not State.Hero or not Entity.IsAlive(State.Hero) then return false end

    local heroPos = Entity.GetAbsOrigin(State.Hero)
    local threat  = NearestEnemyHeroPos(heroPos, EMERGENCY_ENEMY_RADIUS)
    if not threat and State.CurrentFarmSpot and State.CurrentFarmSpot.pos then
      threat = NearestEnemyHeroPos(State.CurrentFarmSpot.pos, EMERGENCY_ENEMY_RADIUS)
    end
    -- Enemy teleporting in (fog too), onto us / the pack / a nearby tower.
    if not threat then
      threat = EnemyTp.Near(heroPos, EMERGENCY_ENEMY_RADIUS)
          or (State.CurrentFarmSpot and State.CurrentFarmSpot.pos
              and EnemyTp.Near(State.CurrentFarmSpot.pos, EMERGENCY_ENEMY_RADIUS)) or nil
    end
    if not threat then return false end

    -- Enemy nearby -> drop EVERYTHING and run.
    State.EmergencyEscape    = { stage = "blink", t = GameRules.GetGameTime(), threat = threat }
    State.FarmState          = "IDLE"
    State.CurrentFarmSpot    = nil
    State.AfterMarchCheck    = nil
    State.PendingTPPos       = nil
    State.PendingLaneRotate  = false
    State.LaneExit           = nil
    State.LaneBurstSpot      = nil
    State.PendingMarchVerify = nil
    ex = State.EmergencyEscape
  end

  if not State.Hero or not Entity.IsAlive(State.Hero) then
    State.EmergencyEscape = nil
    return false
  end

  local now = GameRules.GetGameTime()

  if ex.stage == "blink" then
    if State.Blink and Config.ItemsToUse:Get(L("item_blink"))
        and Ability.CanBeExecuted(State.Blink) == -1 then
      local heroPos = Entity.GetAbsOrigin(State.Hero)
      local dir = nil
      if ex.threat then
        local away = heroPos - ex.threat
        if away:Length() > 1 then dir = away:Normalized() end
      end
      if not dir then
        local fountain = (State.HeroTeam == 2) and Constants.FOUNTAIN_RADIANT or Constants.FOUNTAIN_DIRE
        local toF = fountain - heroPos
        if toF:Length() > 1 then dir = toF:Normalized() end
      end
      if dir then
        local base = (State.CurrentFarmSpot and State.CurrentFarmSpot.pos) or heroPos
        local pos  = FindLaneTreeBlinkPos(base, "retreat")
        local ok   = false
        if pos then
          local v  = pos - heroPos
          local vl = v:Length()
          if vl > 1 and (v / vl):Dot(dir) > 0.2 then ok = true end
        end
        if not ok then pos = heroPos + dir * (GetBlinkCastRangeLimit() * 0.9) end
        if EscapeBlink(pos) then
          ex.stage = "tp"
          ex.t     = now
          return true
        end
      end
    end
    if now - (ex.t or 0) < 0.5 then return true end
    ex.stage = "tp"
    ex.t     = now
    return true
  end

  if now - (ex.t or 0) < 0.25 then return true end

  local fountain = (State.HeroTeam == 2) and Constants.FOUNTAIN_RADIANT or Constants.FOUNTAIN_DIRE
  if State.KeenTeleport and Ability.CanBeExecuted(State.KeenTeleport) == -1 then
    Tinker.TryTeleportTo(fountain, true)
    State.LastFarmTPAt    = now
    State.EmergencyEscape = nil
    State.FarmState       = "IDLE"
    return true
  end

  if State.Rearm and Ability.CanBeExecuted(State.Rearm) == -1
      and State.KeenTeleport and Ability.CanBeExecuted(State.KeenTeleport) ~= -1 then
    if Utils.CastAbility(State.Rearm, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET, nil) then
      MarkRearmIssued(now)
      return true
    end
  end

  return true
end

function Tinker.ProcessLaneExit()
  local ex = State.LaneExit
  if not ex then return false end
  if not State.Hero or not Entity.IsAlive(State.Hero) then
    State.LaneExit = nil
    return false
  end

  local now = GameRules.GetGameTime()

  if ex.stage == "blink" then
    if State.Blink and Config.ItemsToUse:Get(L("item_blink")) then
      local pos = LaneExitBlinkPos()
      if pos and EscapeBlink(pos) then
        ex.stage = "tp"
        ex.t     = now
        return true
      end
    end
    if now - (ex.t or 0) < 0.5 then return true end
    ex.stage = "tp"
    ex.t     = now
    return true
  end

  if now - (ex.t or 0) < 0.25 then return true end

  local nextSpot = Tinker.FindBestFarmSpot(State.TargetSpotKey)
  local dest
  if nextSpot then
    dest = nextSpot.pos
  else
    dest = (State.HeroTeam == 2) and Constants.FOUNTAIN_RADIANT or Constants.FOUNTAIN_DIRE
  end

  if State.KeenTeleport and Ability.CanBeExecuted(State.KeenTeleport) == -1 then
    Tinker.TryTeleportTo(dest, true)
    State.LastFarmTPAt    = now
    State.LaneExit        = nil
    State.FarmState       = "IDLE"
    State.CurrentFarmSpot = nil
    return true
  end

  if State.Rearm and Ability.CanBeExecuted(State.Rearm) == -1
      and State.KeenTeleport and Ability.CanBeExecuted(State.KeenTeleport) ~= -1 then
    if Utils.CastAbility(State.Rearm, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET, nil) then
      MarkRearmIssued(now)
      return true
    end
  end

  return true
end

-- ── Lane burst: on arrival throw 1 laser + items + marches, then leave ──
function Tinker.HandleLaneBurst()
  local spot = State.CurrentFarmSpot
  if not (spot and spot.kind == "lane" and spot.camp1) then return false end

  -- Wait out the teleport so we don't cancel it with another order.
  if State.MovingAfterTeleport and (GameRules.GetGameTime() - (State.LastTeleportAt or 0)) < 0.4 then
    return true
  end

  -- New lane pack (by object identity, NOT SpotKey - the wave moves).
  if State.LaneBurstSpot ~= spot then
    State.LaneBurstSpot            = spot
    State.LaneBurstLaserDone       = false
    State.LaneBurstItemsDone       = false
    State.CurrentSpotMarchCasts    = 0
    State.CurrentSpotMarchRequired = ComputeRequiredMarchesForSpot(spot)
    State.PendingMarchVerify       = nil
  end

  local function LeaveLane()
    MarkLaneBurstCooldown(spot)
    State.LaneBurstSpot            = nil
    State.FarmState                = "IDLE"
    State.CurrentFarmSpot          = nil
    State.AfterMarchCheck          = nil
    State.CurrentSpotMarchCasts    = 0
    State.CurrentSpotMarchRequired = nil
    State.PendingMarchVerify       = nil
    State.JustClearedSpotAt        = GameRules.GetGameTime()
  end

  local castInfo = ComputeMarchCastInfo(spot)
  if not castInfo then
    -- Pack died (or not found). If we are already on the lane and blink-out
    -- is enabled, still do blink + TP instead of a plain teleport.
    local myPos0   = Entity.GetAbsOrigin(State.Hero)
    local nearPack = spot.pos and myPos0:Distance(spot.pos) <= 1200
    if nearPack and Config.LaneExtras and Config.LaneExtras.BlinkTpAfterClear
        and Config.LaneExtras.BlinkTpAfterClear:Get() then
      MarkLaneBurstCooldown(spot)
      State.LaneExit                 = { stage = "blink", t = GameRules.GetGameTime() }
      State.LaneBurstSpot            = nil
      State.FarmState                = "IDLE"
      State.CurrentFarmSpot          = nil
      State.AfterMarchCheck          = nil
      State.CurrentSpotMarchCasts    = 0
      State.CurrentSpotMarchRequired = nil
      State.PendingMarchVerify       = nil
      State.JustClearedSpotAt        = GameRules.GetGameTime()
      return true
    end
    return false   -- no pack found: let MOVING handle approach / teleport
  end

  local myPos   = Entity.GetAbsOrigin(State.Hero)
  local castPos = castInfo.pos

  if myPos:Distance(castInfo.pos) > Constants.MARCH_CAST_RANGE then
    return false   -- too far: let MOVING handle the approach / teleport
  end

  -- "Don't farm if enemy tower nearby": drop this pack.
  if castInfo and Config.LaneExtras and Config.LaneExtras.NoTpNearEnemyTower
      and Config.LaneExtras.NoTpNearEnemyTower:Get()
      and EnemyTowerNear(castInfo.pos) then
    LeaveLane()
    return true
  end

  if not State.CurrentSpotMarchRequired then
    State.CurrentSpotMarchRequired = ComputeRequiredMarchesForSpot(spot)
  end

  -- The march verifier only counts casts while we are in FARMING_SPOT.
  State.FarmState = "FARMING_SPOT"

  local t          = GameRules.GetGameTime()
  local req        = State.CurrentSpotMarchRequired or 1
  local landed     = State.CurrentSpotMarchCasts or 0
  local escapeMana = Tinker.GetEscapeManaCost()
  local curMana    = NPC.GetMana(State.Hero) or 0

  -- 1) Laser ONCE, at the highest-priority creep IN RANGE.
  if Config.Lane.UseLaser:Get() and State.Laser
      and not State.LaneBurstLaserDone
      and Ability.CanBeExecuted(State.Laser) == -1 then
    local lr   = math.max(600, AbilityTargetRange(State.Laser))
    local rows = GetLaneValueUnits(spot)
    local best, bestRank = nil, -math.huge
    for _, row in ipairs(rows) do
      if row.unit and row.pos and myPos:Distance(row.pos) <= (lr + 32) then
        local r = row.isSiege and (3000 + row.hp) or (row.isRanged and (2000 + row.hp) or (1000 + row.hp))
        if r > bestRank then bestRank, best = r, row end
      end
    end
    if best and best.unit and (curMana - (Ability.GetManaCost(State.Laser) or 0)) >= escapeMana then
      if Utils.CastAbility(State.Laser, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TARGET, best.unit) then
        State.LaneBurstLaserDone = true
        return true
      end
    end
  end

  -- 2) Items ONCE (Shiva / Meteor / Dagon) as configured.
  if not State.LaneBurstItemsDone then
    if Config.ItemsToUse:Get(L("item_shivas_guard")) and State.Shiva and Ability.CanBeExecuted(State.Shiva) == -1
        and (curMana - (Ability.GetManaCost(State.Shiva) or 0)) >= escapeMana then
      if Utils.CastAbility(State.Shiva, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET, nil) then
        State.LaneBurstItemsDone = true
        return true
      end
    end
    if Config.ItemsToUse:Get(L("item_meteor_hammer")) and State.Meteor and Ability.CanBeExecuted(State.Meteor) == -1
        and (curMana - (Ability.GetManaCost(State.Meteor) or 0)) >= escapeMana then
      if Utils.CastAbility(State.Meteor, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION, castPos) then
        State.LaneBurstItemsDone = true
        return true
      end
    end
    if Config.ItemsToUse:Get(L("item_dagon")) and State.Dagon and Ability.CanBeExecuted(State.Dagon) == -1
        and (curMana - (Ability.GetManaCost(State.Dagon) or 0)) >= escapeMana then
      local rows = GetLaneValueUnits(spot)
      local tgt  = (rows[1] and rows[1].unit) or nil
      if tgt and Utils.CastAbility(State.Dagon, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TARGET, tgt) then
        State.LaneBurstItemsDone = true
        return true
      end
    end
    State.LaneBurstItemsDone = true
  end

  -- 3) Throw exactly the configured number of marches (Rearm between them).
  if landed >= req then
    -- All marches thrown: give the last one a moment, then leave.
    if (t - (State.LastMarchCastAt or 0)) < 0.35 then return true end
    if Config.LaneExtras and Config.LaneExtras.BlinkTpAfterClear and Config.LaneExtras.BlinkTpAfterClear:Get() then
      -- Blink toward base / into trees (or away from a nearby enemy), then TP out.
      MarkLaneBurstCooldown(spot)
      State.LaneExit                 = { stage = "blink", t = t }
      State.LaneBurstSpot            = nil
      State.FarmState                = "IDLE"
      State.CurrentFarmSpot          = nil
      State.AfterMarchCheck          = nil
      State.CurrentSpotMarchCasts    = 0
      State.CurrentSpotMarchRequired = nil
      State.PendingMarchVerify       = nil
      State.JustClearedSpotAt        = GameRules.GetGameTime()
      return true
    end
    LeaveLane()
    return true
  end

  -- Wait for the in-flight march to be verified before the next action.
  if State.PendingMarchVerify then return true end

  if State.March and Ability.CanBeExecuted(State.March) == -1 then
    if (t - (State.LastMarchCastAt or 0)) >= (Constants.MARCH_MIN_RECAST_GAP or 0)
        and (curMana - (Ability.GetManaCost(State.March) or 0)) >= escapeMana then
      if Utils.CastAbility(State.March, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION, castPos) then
        Tinker.QueueMarchVerify()
      end
    end
    return true
  end

  -- March on cooldown -> Rearm (once) to reset it, then cast the next one.
  if State.Rearm and Ability.CanBeExecuted(State.Rearm) == -1
      and (t - (State.LastMarchCastAt or 0)) >= (Constants.REARM_MIN_GAP_AFTER_MARCH or 0)
      and (curMana - (Ability.GetManaCost(State.Rearm) or 0)) >= escapeMana then
    if Utils.CastAbility(State.Rearm, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET, nil) then
      MarkRearmIssued(t)
    end
  end
  return true
end

function Tinker.HandleFarming()
  Tinker.ProcessMarchVerify()

  if not Config.MarchControl.UseCustom:Get() then
    Tinker.ProcessAfterMarchCheck()
  else
    State.AfterMarchCheck = nil
  end
  if Tinker.HandlePanic() then return end
  if State.IsChanneling then return end
  if Tinker.HandleWisdomRune() then return end
  if Tinker.ProcessEmergencyEscape() then return end
  if State.PendingTPPos then
    local age = GameRules.GetGameTime() - (State.PendingTPSince or 0)
    if age > (Constants.PENDING_TP_MAX_AGE or 2.5) then
      State.PendingTPPos   = nil
      State.PendingTPForce = false
    else
      if State.KeenTeleport and Ability.CanBeExecuted(State.KeenTeleport) == -1 then
        if State.PendingTPForce then
          if Tinker.TryTeleportTo(State.PendingTPPos, true) then
            State.PendingTPPos   = nil
            State.PendingTPForce = false
            return
          end
        else
          if Tinker.ShouldRequestTeleport(State.PendingTPPos, false) then
            if Tinker.TryTeleportTo(State.PendingTPPos, false) then
              State.LastFarmTPAt   = GameRules.GetGameTime()
              State.PendingTPPos   = nil
              State.PendingTPForce = false
              return
            end
          else
            State.PendingTPPos   = nil
            State.PendingTPForce = false
          end
        end
      end
    end
    if State.PendingTPPos then
      -- Do not wander / issue extra orders while we are waiting to finish Rearm->TP or retry TP.
      return
    end
  end

  -- Lane: dedicated burst (marches + items + 1 laser), then leave the lane.
  if Tinker.ProcessLaneExit() then return end
  if Tinker.HandleLaneBurst() then return end

  local usingCustom = Config.MarchControl.UseCustom:Get()
  if State.MarchModeWasCustom ~= usingCustom then
    State.MarchModeWasCustom = usingCustom

    if usingCustom then
      State.AfterMarchCheck = nil
    end

    if State.CurrentFarmSpot and usingCustom then
      State.CurrentSpotMarchCasts = 0
      State.CurrentSpotMarchRequired = ComputeRequiredMarchesForSpot(State.CurrentFarmSpot)
      if (State.CurrentSpotMarchRequired or 0) <= 0 then
        MarkSpotFarmedAndLeave()
        return
      end
    end

    SyncMarchSlidersDisabled()
  end

  if State.FarmState == "FARMING_SPOT" and Tinker.NeedsToReturnToFountain() then
    State.FarmState                = "RETURNING_TO_FOUNTAIN"
    State.CurrentFarmSpot          = nil
    State.AfterMarchCheck          = nil
    State.TargetSpotKey            = nil
    State.SpotCommitUntil          = 0
    State.CurrentSpotMarchCasts    = 0
    State.CurrentSpotMarchRequired = nil
    return
  end

  if State.FarmState == "IDLE" then
    if State.JustClearedSpotAt > 0 and (GameRules.GetGameTime() - State.JustClearedSpotAt) < Constants.IDLE_DECISION_DELAY then
      return
    end

    local bestSpot = Tinker.GetBestFarmSpotCached()
    if bestSpot then
      if not Tinker.HasManaForSpot(bestSpot) then
        State.FarmState       = "RETURNING_TO_FOUNTAIN"
        State.CurrentFarmSpot = nil
        State.AfterMarchCheck = nil
        State.TargetSpotKey   = nil
        State.SpotCommitUntil = 0
        return
      end

      State.CurrentFarmSpot       = bestSpot
      State.TargetSpotKey         = SpotKey(bestSpot)
      State.LastLaneSpotKey       = (bestSpot.kind == "lane") and State.TargetSpotKey or State.LastLaneSpotKey
      State.SpotCommitUntil       = GameRules.GetGameTime() + Constants.SPOT_COMMIT_TIME

      State.BlockTPThisSpot       = false
      State.LastSpotTelePos       = nil
      State.MovingAfterTeleport   = false
      State.RecalcAfterTP         = false
      State.JustClearedSpotAt     = 0
      State.AfterMarchCheck       = nil
      State.LastMarchCastAt       = 0
      State.CurrentSpotMarchCasts = 0
      State.LaneBurstLaserDone    = false
      State.PendingLaneRotate     = false
      if Config.MarchControl.UseCustom:Get() then
        State.CurrentSpotMarchRequired = ComputeRequiredMarchesForSpot(bestSpot)
        if (State.CurrentSpotMarchRequired or 0) <= 0 then
          MarkSpotFarmedAndLeave()
          return
        end
      else
        State.CurrentSpotMarchRequired = nil
      end

      State.FarmState = "MOVING_TO_SPOT"
    else
      -- Nothing to farm right now: go wait at the fountain until creeps/camps spawn.
      State.FarmState       = "RETURNING_TO_FOUNTAIN"
      State.CurrentFarmSpot = nil
      State.AfterMarchCheck = nil
      State.TargetSpotKey   = nil
      State.SpotCommitUntil = 0
    end
  elseif State.FarmState == "MOVING_TO_SPOT" then
    local spot = State.CurrentFarmSpot
    if not spot or not spot.camp1 or spot.camp1.farmed then
      State.FarmState = "IDLE"
      return
    end

    if State.RecalcAfterTP and (GameRules.GetGameTime() - (State.LastTeleportAt or 0)) > 0.2 then
      RecenterSpot(spot)
      State.RecalcAfterTP = false
    end
    if Config.MarchControl.UseCustom:Get() and (State.CurrentSpotMarchRequired or 0) <= 0 then
      MarkSpotFarmedAndLeave()
      return
    end

    if not Tinker.HasManaForSpot(spot) then
      State.FarmState                = "RETURNING_TO_FOUNTAIN"
      State.CurrentFarmSpot          = nil
      State.AfterMarchCheck          = nil
      State.TargetSpotKey            = nil
      State.SpotCommitUntil          = 0
      State.CurrentSpotMarchCasts    = 0
      State.CurrentSpotMarchRequired = nil
      return
    end

    local myPos    = Entity.GetAbsOrigin(State.Hero)
    local castInfo = ComputeMarchCastInfo(spot)
    if not castInfo then
      if spot and spot.kind == "lane" then
        -- Lane pack gone: if blink-out is enabled -> blink + TP, else rotate/idle.
        if Config.LaneExtras and Config.LaneExtras.BlinkTpAfterClear
            and Config.LaneExtras.BlinkTpAfterClear:Get() then
          MarkLaneBurstCooldown(spot)
          State.LaneExit                 = { stage = "blink", t = GameRules.GetGameTime() }
          State.LaneBurstSpot            = nil
          State.FarmState                = "IDLE"
          State.CurrentFarmSpot          = nil
          State.AfterMarchCheck          = nil
          State.CurrentSpotMarchCasts    = 0
          State.CurrentSpotMarchRequired = nil
          State.PendingMarchVerify       = nil
          return
        end
        if Tinker.TryRotateAfterLaneClear(spot) then
          return
        end
      end
      State.FarmState = "IDLE"
      return
    end

    local intended   = Tinker.IntendedKeenTPPos(castInfo.pos)
    local distToLand = myPos:Distance(intended)
    local allowedMax = Constants.MARCH_CAST_RANGE * (spot.single and 1.0 or Constants.MARCH_PAIR_COVERAGE_FRAC)

    if castInfo.maxDist <= allowedMax and myPos:Distance(castInfo.pos) <= Constants.MARCH_CAST_RANGE then
      State.MovingAfterTeleport = false
      State.FarmState           = "FARMING_SPOT"
      if Config.MarchControl.UseCustom:Get() then
        if (State.CurrentSpotMarchRequired or 0) <= (State.CurrentSpotMarchCasts or 0) then
          MarkSpotFarmedAndLeave()
          return
        end
      end
      return
    end

    local requiredMana = RequiredManaBeforeCommit(spot)
    local curMana      = NPC.GetMana(State.Hero) or 0
    local atFountain   = HasFountainBuff()

    if spot.kind == "lane" and not AllEnemiesDead() then
      local ultra = Config.LaneSafety and Config.LaneSafety.UltraSafe and Config.LaneSafety.UltraSafe:Get()
      local safe  = Config.LaneSafety and Config.LaneSafety.Safe and Config.LaneSafety.Safe:Get()
      local bad   = false
      if ultra and not LaneUltraSafe.Ok(spot) then bad = true end
      if safe and not ultra and not LaneUltraSafe.SafeOk(spot) then bad = true end
      local unsafeMode = Config.LaneSafety and Config.LaneSafety.Unsafe and Config.LaneSafety.Unsafe:Get()
      if unsafeMode and not safe and not ultra and not LaneUltraSafe.UnsafeOk(spot) then bad = true end
      -- Safe & Ultra-safe: don't fly to a lane an enemy is already teleporting to.
      if (safe or ultra) and EnemyTp.Near(castInfo.pos, 1500) then bad = true end
      -- Don't fly if an enemy hero was recently seen near the pack.
      local seenSecs = LaneSafetySeconds()
      if seenSecs > 0 and LaneRecentlySeen(castInfo.pos, seenSecs, LANE_SEEN_RADIUS) then bad = true end
      if bad then
        State.FarmState       = "IDLE"
        State.CurrentFarmSpot = nil
        State.TargetSpotKey   = nil
        State.CachedBestSpot  = nil
        return
      end
    end

    if spot.kind == "lane" and distToLand > 1000 then
      -- "Don't TP if enemy tower nearby": skip this spot entirely.
      if Config.LaneExtras and Config.LaneExtras.NoTpNearEnemyTower
          and Config.LaneExtras.NoTpNearEnemyTower:Get()
          and EnemyTowerNear(castInfo.pos) then
        State.FarmState       = "IDLE"
        State.CurrentFarmSpot = nil
        State.TargetSpotKey   = nil
        return
      end
      -- Lane creeps far away: only Keen-TP, never walk on foot.
      if curMana >= requiredMana then
        if Tinker.RequestTeleportToSpot(spot, true) then return end
      else
        State.FarmState                = "RETURNING_TO_FOUNTAIN"
        State.CurrentFarmSpot          = nil
        State.AfterMarchCheck          = nil
        State.TargetSpotKey            = nil
        State.SpotCommitUntil          = 0
        State.CurrentSpotMarchCasts    = 0
        State.CurrentSpotMarchRequired = nil
        return
      end
      return
    end

    if distToLand > Constants.TP_MIN_DISTANCE then
      if curMana >= requiredMana then
        if Tinker.RequestTeleportToSpot(spot, atFountain) then return end
      else
        State.FarmState                = "RETURNING_TO_FOUNTAIN"
        State.CurrentFarmSpot          = nil
        State.AfterMarchCheck          = nil
        State.TargetSpotKey            = nil
        State.SpotCommitUntil          = 0
        State.CurrentSpotMarchCasts    = 0
        State.CurrentSpotMarchRequired = nil
        return
      end
    end
    local holdBlink = (State.PendingTPPos ~= nil) or IsBlinkLockedNow()

    if not holdBlink
        and not HasFountainBuff()
        and Config.ItemsToUse:Get(L("item_blink"))
        and Config.Blink.Travel:Get()
        and State.Blink
        and Ability.CanBeExecuted(State.Blink) == -1 then
      local blinkPos = nil
      if spot.kind == "lane" then
        -- Never blink into the creep pack: only into trees near it.
        blinkPos = FindLaneTreeBlinkPos(castInfo.pos, "approach")
      else
        blinkPos = ComputeSafeBlinkPos(castInfo.pos)
      end
      if blinkPos and Utils.CastAbility(State.Blink, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION, blinkPos) then return end
    end

    Utils.MoveTo(castInfo.pos)
  elseif State.FarmState == "FARMING_SPOT" then
    local spot = State.CurrentFarmSpot
    if not spot or (spot.camp1.farmed and (spot.single or spot.camp2.farmed)) then
      if spot and spot.kind == "lane" and Tinker.TryRotateAfterLaneClear(spot) then
        return
      end
      State.FarmState                = "IDLE"
      State.AfterMarchCheck          = nil
      State.CurrentSpotMarchCasts    = 0
      State.CurrentSpotMarchRequired = nil
      return
    end
    if Config.MarchControl.UseCustom:Get() then
      local req = State.CurrentSpotMarchRequired or 0
      if req > 0 and (State.CurrentSpotMarchCasts or 0) >= req then
        MarkSpotFarmedAndLeave()
        return
      end
    end

    local escapeMana  = Tinker.GetEscapeManaCost()
    local t           = GameRules.GetGameTime()
    local am          = Config.MarchControl.UseCustom:Get() and nil or State.AfterMarchCheck
    local minGap      = Constants.MARCH_MIN_RECAST_GAP
    local rearmGap    = Constants.REARM_MIN_GAP_AFTER_MARCH
    local canMarchNow = State.March and Ability.CanBeExecuted(State.March) == -1
    local canRearmNow = State.Rearm and Ability.CanBeExecuted(State.Rearm) == -1
    local justTPedAgo = t - (State.LastTeleportAt or 0)

    local c1          = spot.camp1 and CountCampAliveCreeps(spot.camp1) or 0
    local c2          = (not spot.single and spot.camp2 and CountCampAliveCreeps(spot.camp2)) or 0
    local anyAlive    = (c1 > 0) or (c2 > 0)

    if spot.kind == "lane" and Config.Lane and Config.Lane.Advanced and Config.Lane.Advanced:Get() then
      local laneCastInfo = ComputeMarchCastInfo(spot)
      if not laneCastInfo then
        if Tinker.TryRotateAfterLaneClear(spot) then return end
        State.FarmState                = "IDLE"
        State.CurrentFarmSpot          = nil
        State.AfterMarchCheck          = nil
        State.TargetSpotKey            = nil
        State.SpotCommitUntil          = 0
        State.CurrentSpotMarchCasts    = 0
        State.CurrentSpotMarchRequired = nil
        return
      else
        if TryLaneRetreatBlink(spot, laneCastInfo) then return end
        if TryLaneBurstAction(spot, laneCastInfo) then return end
        if Tinker.TryRotateAfterLaneClear(spot) then return end
      end
    end

    if am then
      local begunConfirm = (t - (am.startedAt or 0)) >= Constants.CAMP_CLEAR_DELAY
      local zero1        = (not am.camp1) or CountCampAliveCreeps(am.camp1) == 0
      local zero2        = (not am.camp2) or CountCampAliveCreeps(am.camp2) == 0
      local allZero      = zero1 and zero2

      if (Constants.HOLD_ACTIONS_DURING_CONFIRM and begunConfirm and allZero) then
        return
      end

      if anyAlive and canMarchNow then
        local marchCost = Ability.GetManaCost(State.March) or 0
        if (t - (State.LastMarchCastAt or 0)) >= minGap and ((NPC.GetMana(State.Hero) or 0) - marchCost) >= escapeMana then
          Utils.CastAbility(State.March, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION, spot.pos)
        end
        return
      end

      if anyAlive and canRearmNow then
        if justTPedAgo >= Constants.NO_REARM_AFTER_TP and (t - (State.LastMarchCastAt or 0)) >= rearmGap then
          local rearmCost = Ability.GetManaCost(State.Rearm) or 0
          if ((NPC.GetMana(State.Hero) or 0) - rearmCost) >= escapeMana then
            if Utils.CastAbility(State.Rearm, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET, nil) then
              MarkRearmIssued(t)
            end
          else
            State.FarmState                = "RETURNING_TO_FOUNTAIN"
            State.CurrentFarmSpot          = nil
            State.AfterMarchCheck          = nil
            State.TargetSpotKey            = nil
            State.SpotCommitUntil          = 0
            State.CurrentSpotMarchCasts    = 0
            State.CurrentSpotMarchRequired = nil
          end
        end
        return
      end

      return
    end

    if canMarchNow then
      local marchCost = Ability.GetManaCost(State.March) or 0
      if ((NPC.GetMana(State.Hero) or 0) - marchCost) >= escapeMana then
        if Utils.CastAbility(State.March, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION, spot.pos) then
          if not Config.MarchControl.UseCustom:Get() then
            State.AfterMarchCheck = {
              startedAt  = t,
              zeroSince1 = nil,
              zeroSince2 = nil,
              camp1      = spot.camp1,
              camp2      = spot.single and nil or spot.camp2
            }
          end
        end
      else
        State.FarmState                = "RETURNING_TO_FOUNTAIN"
        State.CurrentFarmSpot          = nil
        State.AfterMarchCheck          = nil
        State.TargetSpotKey            = nil
        State.SpotCommitUntil          = 0
        State.CurrentSpotMarchCasts    = 0
        State.CurrentSpotMarchRequired = nil
      end
      return
    end

    if canRearmNow then
      if justTPedAgo >= Constants.NO_REARM_AFTER_TP and (t - (State.LastMarchCastAt or 0)) >= rearmGap then
        local rearmCost = Ability.GetManaCost(State.Rearm) or 0
        if ((NPC.GetMana(State.Hero) or 0) - rearmCost) >= escapeMana then
          if Utils.CastAbility(State.Rearm, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET, nil) then
            MarkRearmIssued(t)
          end
        else
          State.FarmState                = "RETURNING_TO_FOUNTAIN"
          State.CurrentFarmSpot          = nil
          State.AfterMarchCheck          = nil
          State.TargetSpotKey            = nil
          State.SpotCommitUntil          = 0
          State.CurrentSpotMarchCasts    = 0
          State.CurrentSpotMarchRequired = nil
        end
      end
      return
    end
  elseif State.FarmState == "RETURNING_TO_FOUNTAIN" then
    State.TargetSpotKey   = nil
    State.SpotCommitUntil = 0

    if HasFountainBuff() then
      local maxMana     = NPC.GetMaxMana(State.Hero) or 0
      local curMana     = NPC.GetMana(State.Hero) or 0
      local cycleCost   = Tinker.GetCampCycleManaCost()
      local minFracNeed = maxMana * Constants.FOUNTAIN_MIN_MANA_FRAC
      local need        = math.max(minFracNeed, math.min(cycleCost, maxMana * 0.95))
      -- Wait at the fountain until there is actually something to farm.
      if curMana >= need and Tinker.GetBestFarmSpotCached() then
        State.FarmState = "IDLE"
      end
      return
    end

    -- Team 2 = Radiant, Team 3 = Dire
    local fountainPos = (State.HeroTeam == 2) and Constants.FOUNTAIN_RADIANT or Constants.FOUNTAIN_DIRE

    -- Если мы уже недалеко от фонтана, не спамим ТП/Реарм/блинк, просто подбегаем.
    local myPos          = Entity.GetAbsOrigin(State.Hero)
    local distToFountain = myPos:Distance(fountainPos)
    if distToFountain <= 900 then
      Utils.MoveTo(fountainPos)
      return
    end

    if State.IsChanneling then
      State.PendingTPPos   = fountainPos
      State.PendingTPSince = GameRules.GetGameTime()
      State.PendingTPForce = true
      return
    end

    if State.KeenTeleport and Ability.CanBeExecuted(State.KeenTeleport) == -1 then
      if Tinker.TryTeleportTo(fountainPos, true) then
        State.LastFarmTPAt = GameRules.GetGameTime()
        return
      end
    end

    if State.Rearm
        and Ability.CanBeExecuted(State.Rearm) == -1
        and State.KeenTeleport
        and Ability.CanBeExecuted(State.KeenTeleport) ~= -1 then
      local needMana = (Ability.GetManaCost(State.Rearm) or 0) + (Ability.GetManaCost(State.KeenTeleport) or 0)
      if (NPC.GetMana(State.Hero) or 0) >= needMana then
        State.PendingTPPos   = fountainPos
        State.PendingTPSince = GameRules.GetGameTime()
        State.PendingTPForce = true
        if Utils.CastAbility(State.Rearm, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET, nil) then
          MarkRearmIssued(GameRules.GetGameTime())
          return
        end
      end
    end

    local holdBlink = (State.PendingTPPos ~= nil) or IsBlinkLockedNow()
    if not HasFountainBuff()
        and not holdBlink
        and Config.ItemsToUse:Get(L("item_blink"))
        and Config.Blink.Travel:Get()
        and State.Blink
        and Ability.CanBeExecuted(State.Blink) == -1 then
      local myPos      = Entity.GetAbsOrigin(State.Hero)
      local toFountain = (fountainPos - myPos)
      local dist       = toFountain:Length()
      local blinkRange = GetBlinkCastRangeLimit()
      local blinkPos   = dist > blinkRange and
          (myPos + toFountain:Normalized() * blinkRange) or fountainPos
      if Utils.CastAbility(State.Blink, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION, blinkPos) then return end
    end

    Utils.MoveTo(fountainPos)
  end
end

local Theme = {
  bg           = Color(14, 16, 20, 205),
  bg2          = Color(20, 23, 29, 225),
  border       = Color(70, 78, 92, 205),
  shadow       = Color(0, 0, 0, 180),

  text         = Color(230, 235, 245, 255),
  dim          = Color(160, 170, 185, 255),

  good         = Color(120, 255, 180, 255),
  warn         = Color(255, 220, 130, 255),
  bad          = Color(255, 120, 120, 255),

  accent       = Color(120, 220, 255, 255),
  accent2      = Color(120, 255, 180, 255),
  gold         = Color(255, 220, 110, 255),

  ringCast     = Color(120, 255, 120, 165),
  ringPair     = Color(120, 180, 255, 140),
  ringFail     = Color(255, 120, 120, 150),

  campDot      = Color(255, 210, 120, 220),

  tpAnchor     = Color(200, 140, 255, 245),
  tpAnchorRing = Color(200, 140, 255, 155),
  tpAnchorPath = Color(200, 140, 255, 170),
}

local UI = {
  fonts    = { regular = nil, small = nil, bold = nil },
  pad      = 10,
  rowH     = 18,
  rounding = 10,
}

local function EnsureFonts()
  if not UI.fonts.regular then UI.fonts.regular = Render.LoadFont("Tahoma", 0, 500) end
  if not UI.fonts.small then UI.fonts.small = Render.LoadFont("Tahoma", 0, 450) end
  if not UI.fonts.bold then UI.fonts.bold = Render.LoadFont("Tahoma", 0, 700) end
  if not State.DebugFont then State.DebugFont = UI.fonts.regular end
end

local function Lerp(a, b, t) return a + (b - a) * t end
local function Pulse(t, speed, minA, maxA) return Lerp(minA, maxA, 0.5 + 0.5 * math.sin(t * speed)) end
local function W2S(v) return Render.WorldToScreen(v) end

local function Chip(pos, text, colText, colBg)
  EnsureFonts()
  local padX, padY = 6, 3
  local ts         = Render.TextSize(UI.fonts.small, 14, text)
  local s          = Vec2(pos.x, pos.y)
  local e          = Vec2(pos.x + ts.x + padX * 2, pos.y + ts.y + padY * 2)
  Render.FilledRect(s, e, colBg or Theme.bg2, 8)
  Render.Rect(s, e, Theme.border, 8, nil, 1.0)
  Render.Text(UI.fonts.small, 14, text, Vec2(pos.x + padX, pos.y + padY), colText or Theme.text)
end

local function WorldRing(center, radius, color, thickness, segments)
  segments = segments or 56
  local pts = {}
  for i = 0, segments do
    local ang     = (i / segments) * math.pi * 2
    local wp      = Vector(center.x + math.cos(ang) * radius, center.y + math.sin(ang) * radius, center.z)
    local sp, vis = W2S(wp)
    if not vis then return end
    table.insert(pts, sp)
  end
  if #pts > 1 then Render.PolyLine(pts, color, thickness or 1.8) end
end

local function WorldDashed(a, b, color, thickness, dash, gap)
  local sa, va = W2S(a)
  local sb, vb = W2S(b)
  if not (va and vb) then return end
  thickness = thickness or 1.4
  dash      = dash or 8
  gap       = gap or 6
  local d   = sb - sa
  local len = math.sqrt(d.x * d.x + d.y * d.y)
  if len < 1 then return end
  local dir = Vec2(d.x / len, d.y / len)
  local t = 0
  while t < len do
    local seg = math.min(dash, len - t)
    Render.Line(sa + dir * t, sa + dir * (t + seg), color, thickness)
    t = t + dash + gap
  end
end

local function WorldArrow(fromPos, toPos, color, width)
  local s1, v1 = W2S(fromPos)
  local s2, v2 = W2S(toPos)
  if not (v1 and v2) then return end
  width = width or 2.0
  Render.Line(s1, s2, color, width)
  local v = s2 - s1
  local len = math.sqrt(v.x * v.x + v.y * v.y)
  if len <= 0.01 then return end
  local dir  = Vec2(v.x / len, v.y / len)
  local left = Vec2(-dir.y, dir.x)
  local base = s2 - dir * 12
  Render.FilledTriangle({ s2, base + left * 6, base - left * 6 }, color)
end

local function WorldDot(pos, color)
  local sp, vis = W2S(pos)
  if not vis then return end
  Render.FilledCircle(sp, 5.5, color)
  Render.Circle(sp, 8.5, Color(color.r, color.g, color.b, 70), 1.2, 0, 1, false, 28)
end

local function CampTag(pos, txt)
  local s, vis = W2S(pos); if not vis then return end
  Chip(s + Vec2(10, -8), txt, Theme.text, Color(22, 25, 31, 225))
end

local function DrawTPAnchorDebug(targetPos, pathEndPos, tagText)
  local heroPos  = Entity.GetAbsOrigin(State.Hero)
  local res      = Tinker.ResolveKeenTeleport(targetPos)
  local has      = res and res.anchor ~= nil
  local ap       = has and res.anchorPos or targetPos
  local rad      = res and res.landingRadius or 0
  local fp       = res and res.finalPos or targetPos
  local labelCat = has and (res.cat or "anchor") or "raw"
  local dist     = math.floor(heroPos:Distance(fp))
  local label    = (tagText and (tagText .. " • ") or "") .. "TP • " .. labelCat .. " • " .. dist

  if has and rad > 0 then
    WorldRing(ap, rad, Theme.tpAnchorRing, 1.7, 64)
  end

  WorldDot(fp, has and Theme.tpAnchor or Theme.bad)
  WorldArrow(ap, fp, has and Theme.tpAnchor or Theme.bad, 2.0)

  if pathEndPos then
    WorldDashed(ap, pathEndPos, Theme.tpAnchorPath, 1.6, 8, 6)
  end

  WorldDot(ap, Theme.accent2)
  local s, vis = W2S(ap)
  if vis then
    Chip(s + Vec2(12, -22), label, has and Theme.tpAnchor or Theme.bad, Color(20, 22, 28, 230))
  end
end

local function DrawWorldSpotNeo(spot)
  local castPos    = spot.pos
  local heroPos    = Entity.GetAbsOrigin(State.Hero)
  local castInfo   = ComputeMarchCastInfo(spot)
  if castInfo and castInfo.pos then castPos = castInfo.pos end
  local allowedMax = Constants.MARCH_CAST_RANGE * (spot.single and 1.0 or Constants.MARCH_PAIR_COVERAGE_FRAC)
  local now        = GameRules.GetGameTime()

  local s, vis     = W2S(castPos)
  if vis then
    local haloA = math.floor(Pulse(now, 3.0, 0.45, 0.8) * 255)
    Render.CircleGradient(s, 22, Color(0, 0, 0, 0), Color(120, 255, 160, haloA))
  end

  local castAlpha = math.floor(Pulse(now, 3.0, 110, 165))
  WorldRing(castPos, Constants.MARCH_CAST_RANGE, Color(Theme.ringCast.r, Theme.ringCast.g, Theme.ringCast.b, castAlpha),
    2.0, 60)
  if (not spot.single) and castInfo then
    local fit = castInfo.maxDist <= allowedMax
    local col = fit and Theme.ringPair or Theme.ringFail
    WorldRing(castPos, allowedMax, col, 1.6, 56)
  end

  if spot.camp1 and spot.camp1.pos then
    WorldDot(spot.camp1.pos, Theme.campDot)
    WorldDashed(castPos, spot.camp1.pos, Color(255, 255, 255, 80), 1.2, 7, 5)
    if Config.Debug.Pretty:Get() then CampTag(spot.camp1.pos, "A") end
  end
  if spot.camp2 and spot.camp2.pos then
    WorldDot(spot.camp2.pos, Theme.campDot)
    WorldDashed(castPos, spot.camp2.pos, Color(255, 255, 255, 80), 1.2, 7, 5)
    WorldDashed(spot.camp1.pos, spot.camp2.pos, Color(255, 230, 140, 95), 1.4, 8, 5)
    if Config.Debug.Pretty:Get() then CampTag(spot.camp2.pos, "B") end
  end

  WorldArrow(heroPos, castPos, Theme.accent2, 2.0)

  if Config.Debug.Bounty:Get() and vis then
    local typ = spot.single and "Single" or "Pair"
    local g   = FormatGold(spot.gold or 0)
    Chip(s + Vec2(12, -26), string.format("%s • %s", typ, g), Theme.gold, Color(20, 22, 28, 225))
  end

  DrawTPAnchorDebug(castPos, castPos, nil)
end

local function DrawWorldSpotMinimal(spot)
  local castPos    = spot.pos
  local heroPos    = Entity.GetAbsOrigin(State.Hero)
  local castInfo   = ComputeMarchCastInfo(spot)
  if castInfo and castInfo.pos then castPos = castInfo.pos end
  local allowedMax = Constants.MARCH_CAST_RANGE * (spot.single and 1.0 or Constants.MARCH_PAIR_COVERAGE_FRAC)
  WorldRing(castPos, Constants.MARCH_CAST_RANGE, Color(120, 255, 120, 150), 1.6, 48)
  if (not spot.single) and castInfo then
    local fit = castInfo.maxDist <= allowedMax
    WorldRing(castPos, allowedMax, fit and Color(120, 180, 255, 140) or Color(255, 120, 120, 140), 1.4, 48)
  end
  if spot.camp1 and spot.camp1.pos then WorldDot(spot.camp1.pos, Theme.campDot) end
  if spot.camp2 and spot.camp2.pos then WorldDot(spot.camp2.pos, Theme.campDot) end
  WorldArrow(heroPos, castPos, Theme.accent2, 1.8)
  DrawTPAnchorDebug(castPos, castPos, nil)
end

local function DrawDockOverlay()
  EnsureFonts()

  local w        = 360
  local screen   = Render.ScreenSize()
  local x        = screen.x - w - 24
  local y        = 110
  local pad      = UI.pad
  local tNow     = GameRules.GetGameTime()
  local lines    = {}

  local stateCol = Theme.text
  if State.FarmState == "FARMING_SPOT" then
    stateCol = Theme.good
  elseif State.FarmState == "RETURNING_TO_FOUNTAIN" then
    stateCol = Theme.warn
  end

  table.insert(lines,
    { "State", string.format("%s  (channeling: %s)", State.FarmState, tostring(State.IsChanneling)), stateCol })

  local tpLockRemain = math.max(0, (State.TeleportLockUntil or 0) - tNow)
  table.insert(lines, { "TP lock",
    string.format("movingAfterTP=%s  remain=%.1fs  pending=%s",
      tostring(State.MovingAfterTeleport),
      tpLockRemain,
      tostring(State.PendingTPPos ~= nil)),
    (tpLockRemain > 0) and Theme.warn or Theme.dim
  })

  if State.CurrentFarmSpot then
    local spot       = State.CurrentFarmSpot
    local castInfo   = ComputeMarchCastInfo(spot)
    local allowedMax = Constants.MARCH_CAST_RANGE * (spot.single and 1.0 or Constants.MARCH_PAIR_COVERAGE_FRAC)
    local fit        = castInfo and (castInfo.maxDist <= allowedMax) or false

    table.insert(lines, { "Spot",
      string.format("key=%s  commitRem=%.1f  lastFarmTP=%.1f",
        tostring(State.TargetSpotKey),
        math.max(0, (State.SpotCommitUntil or 0) - tNow),
        math.max(0, tNow - (State.LastFarmTPAt or 0))),
      Theme.dim })

    if Config.Debug.Bounty:Get() then
      table.insert(lines, { "Bounty", FormatGold(spot.gold or 0), Theme.gold })
    end

    if Config.Debug.Spot:Get() then
      table.insert(lines, { "Type",
        spot.single and "single" or ("pair (" .. math.floor(Constants.MARCH_PAIR_COVERAGE_FRAC * 100) .. "% cover)"),
        Theme.dim })
      if castInfo then
        table.insert(lines,
          { "Max Camp Dist", string.format("%.0f / %.0f", castInfo.maxDist, allowedMax), fit and Theme.good or Theme.bad })
        table.insert(lines,
          { "Hero->Cast", string.format("%.0f / %d", Entity.GetAbsOrigin(State.Hero):Distance(castInfo.pos),
            Constants.MARCH_CAST_RANGE), Theme.dim })
      else
        table.insert(lines, { "Spot Metrics", "N/A (target moved/despawned)", Theme.warn })
      end
    end
    local mode = Config.MarchControl.UseCustom:Get() and "Custom Count" or "Until Cleared"
    table.insert(lines, { "March Mode", mode, Theme.accent })
    if Config.MarchControl.UseCustom:Get() then
      local req = State.CurrentSpotMarchRequired or 0
      local have = State.CurrentSpotMarchCasts or 0
      table.insert(lines, { "Marches", string.format("%d / %d", have, req), (have >= req and Theme.good or Theme.dim) })
    end
  end

  if Config.Debug.Orders:Get() then
    local nextReady = math.max(0, (State.NextOrderTime or 0) - tNow)
    table.insert(lines,
      { "Orders", string.format("tick=%d  perSec=%d  next=%.2fs", State.OrdersThisUpdate or 0, State.OrdersPerSec or 0,
        nextReady), Theme.dim })
    if State.LastOrderDebug then
      local lod = State.LastOrderDebug
      local tag = lod.allowed and "sent" or ("blocked:" .. (lod.reason or "?"))
      local pos = lod.tpos and (" to(" .. math.floor(lod.tpos.x) .. "," .. math.floor(lod.tpos.y) .. ")") or ""
      table.insert(lines,
        { "Last Order", string.format("%s%s [%s]%s", lod.order or "?", lod.ability and ("(" .. lod.ability .. ")") or "",
          tag, pos), lod.allowed and Theme.good or Theme.bad })
    end
  end

  local labelW = 0
  for _, r in ipairs(lines) do
    local ts = Render.TextSize(UI.fonts.small, 14, r[1])
    if ts.x > labelW then labelW = ts.x end
  end
  labelW         = labelW + 12
  local contentH = #lines * UI.rowH + pad * 2

  local start    = Vec2(x, y)
  local end_     = Vec2(x + w, y + contentH + 10)
  Render.Shadow(start, end_, Theme.shadow, 14, UI.rounding)
  Render.Blur(start, end_, 0.85, 0.9, UI.rounding)
  Render.FilledRect(start, end_, Theme.bg2, UI.rounding)
  Render.Rect(start, end_, Theme.border, UI.rounding, nil, 1.0)

  Chip(Vec2(x + pad, y - 22), "Auto Push&Farm — Debug", Theme.text, Color(18, 20, 26, 230))

  local ry = y + pad + 6
  for _, r in ipairs(lines) do
    Render.Text(UI.fonts.small, 14, r[1], Vec2(x + pad, ry), Theme.dim)
    Render.Text(UI.fonts.small, 14, r[2], Vec2(x + pad + labelW, ry), r[3])
    ry = ry + UI.rowH
  end
end
local function DrawStatusOverlay()
  if not Config.StatusOverlay:Get() then return end
  EnsureFonts()

  local ui = State.StatusUI
  local pos = Vec2(ui.x, ui.y)

  local isOn      = Config.AutoFarm:IsToggled()
  local glimmerOn = Config.AutoGlimmer and Config.AutoGlimmer:Get()

  local rows = {}
  if (not Config.Status.ShowAutoFarm) or Config.Status.ShowAutoFarm:Get() then
    rows[#rows + 1] = { text = isOn and "AutoFarm: ON" or "AutoFarm: OFF",
                        col = isOn and Theme.good or Theme.bad }
  end
  if (not Config.Status.ShowAutoGlimmer) or Config.Status.ShowAutoGlimmer:Get() then
    rows[#rows + 1] = { text = glimmerOn and "AutoGlimmer: ON" or "AutoGlimmer: OFF",
                        col = glimmerOn and Theme.good or Theme.bad }
  end
  if #rows == 0 then return end

  local padX, padY = 10, 7
  local fontSize  = 15
  local barW      = 5
  local rowH      = Render.TextSize(UI.fonts.bold, fontSize, "W").y + padY * 2
  local gap       = 4

  local w = 140
  for _, r in ipairs(rows) do
    local ts = Render.TextSize(UI.fonts.bold, fontSize, r.text)
    if (ts.x + padX * 2 + 6) > w then w = ts.x + padX * 2 + 6 end
  end

  local s = Vec2(ui.x, ui.y)
  local e = Vec2(ui.x + w, ui.y + (#rows * rowH + (#rows - 1) * gap))

  local ry = ui.y
  for _, r in ipairs(rows) do
    local rs = Vec2(ui.x, ry)
    local re = Vec2(ui.x + w, ry + rowH)
    Render.Shadow(rs, re, Theme.shadow, 12, 8)
    Render.Blur(rs, re, 0.7, 0.9, 8)
    Render.FilledRect(rs, re, Theme.bg2, 8)
    Render.Rect(rs, re, Theme.border, 8, nil, 1.0)
    Render.FilledRect(Vec2(rs.x, rs.y), Vec2(rs.x + barW, re.y), r.col, 8)
    Render.Text(UI.fonts.bold, fontSize, r.text, Vec2(rs.x + padX + barW + 4, rs.y + padY), r.col)
    ry = ry + rowH + gap
  end
  if not Config.Status.Lock:Get() and Input and Input.GetCursorPos and Input.IsKeyDown then
    local x, y = Input.GetCursorPos()
    local inside = (x >= s.x and x <= e.x and y >= s.y and y <= e.y)
    local down = Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE1)

    if ui.dragging then
      if down then
        ui.x = x - ui.dragDX
        ui.y = y - ui.dragDY
      else
        ui.dragging = false
      end
    else
      if inside and down and not ui.mousePrevDown then
        ui.dragging = true
        ui.dragDX = x - ui.x
        ui.dragDY = y - ui.y
      end
    end
    ui.mousePrevDown = down
  end
end

-- Helper: camp coordinate logger.
-- Press F6/F7/F8/F9 while standing in a camp to log a ready-to-paste entry:
--   {pos = Vector(x, y, z), team = <2/3>, type = <1..4>, index = <n>},
-- Types: 1 small, 2 medium, 3 large, 4 ancient.
local CampLogger = {
  prev = { f6 = false, f7 = false, f8 = false, f9 = false },
  index = 1,
}

local function LogCampHere(campType)
  if not Engine.IsInGame() then return end
  local hero = Heroes.GetLocal()
  if not hero then return end
  local team = Entity.GetTeamNum(hero)
  if team ~= 2 and team ~= 3 then return end

  local p = Entity.GetAbsOrigin(hero)
  Log.Write(string.format(
    "Camp spot: {pos = Vector(%.1f, %.1f, %.1f), team = %d, type = %d, index = %d},",
    p.x, p.y, p.z, team, campType, CampLogger.index
  ))
  CampLogger.index = CampLogger.index + 1
end

local function HandleCampLoggerHotkeys()
  if not Input or not Input.IsKeyDown then return end

  local d6 = Input.IsKeyDown(Enum.ButtonCode.KEY_F6)
  local d7 = Input.IsKeyDown(Enum.ButtonCode.KEY_F7)
  local d8 = Input.IsKeyDown(Enum.ButtonCode.KEY_F8)
  local d9 = Input.IsKeyDown(Enum.ButtonCode.KEY_F9)

  if d6 and not CampLogger.prev.f6 then LogCampHere(1) end -- small
  if d7 and not CampLogger.prev.f7 then LogCampHere(2) end -- medium
  if d8 and not CampLogger.prev.f8 then LogCampHere(3) end -- large
  if d9 and not CampLogger.prev.f9 then LogCampHere(4) end -- ancient

  CampLogger.prev.f6 = d6
  CampLogger.prev.f7 = d7
  CampLogger.prev.f8 = d8
  CampLogger.prev.f9 = d9
end

local CampMapUI = {
  x = 60, y = 60, w = 440, h = 460,
  mapImage = nil,
  dragging = false, dragDX = 0, dragDY = 0,
  mousePrevDown = false,
}

local MAP_MIN, MAP_MAX = -8500, 8500
local MAP_RANGE = MAP_MAX - MAP_MIN

local function CampMapW2S(wx, wy)
  local ui = CampMapUI
  local mx = ui.x + 10
  local my = ui.y + 30
  local mw = ui.w - 20
  local mh = ui.h - 40
  local nx = (wx - MAP_MIN) / MAP_RANGE
  local ny = 1.0 - (wy - MAP_MIN) / MAP_RANGE
  return mx + nx * mw, my + ny * mh
end

local function DrawCampMapOverlay()
  if Config.ShowCampMapKey and Config.ShowCampMapKey:IsPressed() then
    Config.ShowCampMap:Set(not Config.ShowCampMap:Get())
  end
  if not (Config.ShowCampMap and Config.ShowCampMap:Get()) then return end
  EnsureFonts()

  local ui = CampMapUI
  local s  = Vec2(ui.x, ui.y)
  local e  = Vec2(ui.x + ui.w, ui.y + ui.h)

  local mapX = ui.x + 10
  local mapY = ui.y + 30
  local mapW = ui.w - 20
  local mapH = ui.h - 40
  local ms   = Vec2(mapX, mapY)

  Render.Shadow(s, e, Theme.shadow, 18, UI.rounding)
  Render.Blur(s, e, 0.85, 0.9, UI.rounding)
  Render.FilledRect(s, e, Theme.bg2, UI.rounding)
  Render.Rect(s, e, Theme.border, UI.rounding, nil, 1.0)
  Render.Text(UI.fonts.bold, 14, "Camp Map - click dot to toggle", Vec2(ui.x + 10, ui.y + 8), Theme.text)

  if ui.mapImage and ui.mapImage ~= 0 then
    Render.Image(ui.mapImage, ms, Vec2(mapW, mapH), Color(255, 255, 255, 255))
  else
    Render.FilledRect(ms, Vec2(mapX + mapW, mapY + mapH), Color(18, 38, 18, 240), 4)
    Render.Text(UI.fonts.small, 12, "Map loading...", Vec2(mapX + 10, mapY + 10), Theme.text)
  end

  local curX, curY, mouseDown = 0, 0, false
  if Input and Input.GetCursorPos and Input.IsKeyDown then
    curX, curY = Input.GetCursorPos()
    mouseDown  = Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE1)
  end
  local justClicked = mouseDown and not ui.mousePrevDown

  local TYPE_NAME = { [1] = "Small", [2] = "Medium", [3] = "Large", [4] = "Ancient" }
  local TEAM_NAME = { [2] = "Radiant", [3] = "Dire" }

  local campDefs = {}
  for _, c in ipairs(FALLBACK_JUNGLE_SPOTS) do table.insert(campDefs, c) end
  for _, c in ipairs(CustomJungleSpots) do table.insert(campDefs, c) end

  for _, camp in ipairs(campDefs) do
    local sw      = CampSwitches[camp.index]
    local enabled = CampSwitches[camp.index] == true
    local sx, sy  = CampMapW2S(camp.pos.x, camp.pos.y)
    local dotR    = camp.type == 4 and 11 or 8

    local col
    if not enabled then
      col = Color(70, 70, 70, 160)
    elseif camp.team == 2 then
      col = camp.type == 4 and Color(80, 255, 130, 255) or Color(100, 200, 130, 230)
    else
      col = camp.type == 4 and Color(255, 90, 70, 255) or Color(220, 110, 100, 230)
    end

    if camp.type == 4 then
      Render.Circle(Vec2(sx, sy), dotR + 4,
        Color(255, 200, 50, enabled and 210 or 70), 2.0, 0, 1, false, 36)
    end

    Render.FilledCircle(Vec2(sx, sy), dotR, col)

    local dx, dy  = curX - sx, curY - sy
    local hovered = (dx * dx + dy * dy) <= (dotR + 5) * (dotR + 5)

    if hovered then
      Render.Circle(Vec2(sx, sy), dotR + 3, Color(255, 255, 255, 210), 1.5, 0, 1, false, 28)
      local tip = string.format("#%d  %s %s  [%s]",
        camp.index,
        TEAM_NAME[camp.team] or "?",
        TYPE_NAME[camp.type] or "?",
        enabled and "ON" or "OFF")
      Chip(Vec2(sx + 12, sy - 22), tip,
        enabled and Theme.good or Theme.bad, Color(18, 20, 26, 235))
      if justClicked then
        CampSwitches[camp.index] = not enabled
        IniConfig.WriteInt("tinker_camps", "camp_" .. camp.index, CampSwitches[camp.index] and 1 or 0)
      end
    end

    local numStr = tostring(camp.index)
    local numX = sx - (camp.index >= 10 and 6 or 3)
    local numY = sy - 6
    Render.Text(UI.fonts.bold, 11, numStr, Vec2(numX - 1, numY - 1), Color(0, 0, 0, 255))
    Render.Text(UI.fonts.bold, 11, numStr, Vec2(numX + 1, numY - 1), Color(0, 0, 0, 255))
    Render.Text(UI.fonts.bold, 11, numStr, Vec2(numX - 1, numY + 1), Color(0, 0, 0, 255))
    Render.Text(UI.fonts.bold, 11, numStr, Vec2(numX + 1, numY + 1), Color(0, 0, 0, 255))
    Render.Text(UI.fonts.bold, 11, numStr, Vec2(numX, numY), Color(255, 255, 80, 255))
  end

  local headerHit = (curX >= ui.x and curX <= ui.x + ui.w
                 and curY >= ui.y and curY <= ui.y + 28)
  if ui.dragging then
    if mouseDown then
      ui.x = curX - ui.dragDX
      ui.y = curY - ui.dragDY
    else
      ui.dragging = false
    end
  elseif headerHit and justClicked then
    ui.dragging = true
    ui.dragDX   = curX - ui.x
    ui.dragDY   = curY - ui.y
  end

  ui.mousePrevDown = mouseDown
end

script.OnKeyEvent = function(data)
  if not Engine.IsInGame() then return end

  if data.key ~= Enum.ButtonCode.KEY_E then return end
  if data.event ~= Enum.EKeyEvent.EKeyEvent_KEY_DOWN then return end

  State.Hero = Heroes.GetLocal()
  if not State.Hero or not Entity.IsAlive(State.Hero) then return end
  if Entity.GetUnitName(State.Hero) ~= "npc_dota_hero_tinker" then return end

  local now = GlobalVars.GetCurTime()
  local elapsed = now - lastTapTime

  if elapsed > DOUBLE_TAP_TIME then
    lastTapTime = now
    showIndicator = true
    return
  end

  lastTapTime = 0
  showIndicator = false

  -- Respect the "Deploy Turrets (Double-Tap)" menu toggle
  if not Config.AutoMatrix:Get() then return end

  local march = NPC.GetAbility(State.Hero, "tinker_deploy_turrets")
  if not march then return end
  if Ability.GetLevel(march) < 1 then return end
  if Ability.GetCooldown(march) > 0 then return end
  if not Ability.IsOwnersManaEnough(march) then return end

  local heroPos  = Entity.GetAbsOrigin(State.Hero)
  local mousePos = Input.GetWorldCursorPos()

  local dx = mousePos.x - heroPos.x
  local dy = mousePos.y - heroPos.y
  local len = math.sqrt(dx * dx + dy * dy)

  local castPos
  if len > 1 then
    castPos = Vector(
      heroPos.x + (dx / len) * BOOST_DISTANCE,
      heroPos.y + (dy / len) * BOOST_DISTANCE,
      heroPos.z
    )
  else
    castPos = heroPos
  end

  Ability.CastPosition(march, castPos, false, false, true)
end

-- ══════════════════════════════════════════════════════════════
--  Turret Dodge ("Додж турелями") — ported from tinker_turret_dodge_v1.0.2
-- ══════════════════════════════════════════════════════════════
local TurretDodge = (function()
  local PANEL_CONFIG = "tinker_turret_dodge"

  local TURRET_RADIUS           = 600
  local BLINK_DODGE_RADIUS      = 650
  local INTERRUPT_RADIUS        = 200
  local TURRET_DELAY            = 0.5
  local PREFIRE_LEAD            = 0.12
  local MOVEMENT_PREFIRE_LEAD   = 0.35
  local TECHIES_FLIGHT_DURATION = 0.5
  local TECHIES_BLAST_RADIUS    = 400
  local SPECIAL_TURRET_OFFSET   = 190
  local DEFAULT_MOVE_SPEED      = 550
  local MAGNUS_SKEWER_SPEED     = 904
  local SPEED_SAMPLE_RADIUS     = 1000
  local NETHER_STRIKE_PUSH_DISTANCE     = 162
  local NETHER_STRIKE_DEFAULT_CAST_POINT = 0.1

  local THREAT_NAMES = {
    item_blink = true, item_arcane_blink = true, item_swift_blink = true, item_overwhelming_blink = true,
    enigma_black_hole = true, magnataur_reverse_polarity = true, faceless_void_chronosphere = true,
    leshrac_split_earth = true, lina_light_strike_array = true, lion_impale = true, mars_spear = true,
    sven_storm_bolt = true, earthshaker_fissure = true, nyx_assassin_impale = true,
    slardar_slithereen_crush = true, dragon_knight_dragon_tail = true, chaos_knight_chaos_bolt = true,
    vengefulspirit_magic_missile = true, mirana_arrow = true, tiny_avalanche = true,
    shadow_shaman_hex = true, shadow_shaman_voodoo = true, shadow_shaman_shackles = true,
    bane_fiends_grip = true, witch_doctor_paralyzing_cask = true, beastmaster_primal_roar = true,
    pudge_dismember = true, tidehunter_ravage = true, disruptor_kinetic_field = true,
    disruptor_static_storm = true, centaur_hoof_stomp = true, elder_titan_echo_stomp = true,
    jakiro_ice_path = true, jakiro_macropyre = true,
    techies_suicide = true, techies_blast_off = true, magnataur_skewer = true,
    spirit_breaker_charge_of_darkness = true, spirit_breaker_nether_strike = true,
    earth_spirit_rolling_boulder = true, pangolier_rolling_thunder = true,
    ember_spirit_activate_fire_remnant = true, tusk_walrus_kick = true,
    antimage_blink = true, phantom_assassin_phantom_strike = true,
    kez_raptor_dance = true, nevermore_requiem = true,
  }

  local MOVEMENT_NAMES = {
    techies_suicide = true, techies_blast_off = true, magnataur_skewer = true,
    spirit_breaker_charge_of_darkness = true, earth_spirit_rolling_boulder = true,
    pangolier_rolling_thunder = true,
  }

  local STUN_NAMES = {
    lina_light_strike_array = true, leshrac_split_earth = true, lion_impale = true, mars_spear = true,
    sven_storm_bolt = true, earthshaker_fissure = true, nyx_assassin_impale = true,
    slardar_slithereen_crush = true, dragon_knight_dragon_tail = true, chaos_knight_chaos_bolt = true,
    vengefulspirit_magic_missile = true, mirana_arrow = true, tiny_avalanche = true,
    shadow_shaman_hex = true, shadow_shaman_voodoo = true, shadow_shaman_shackles = true,
    bane_fiends_grip = true, witch_doctor_paralyzing_cask = true, beastmaster_primal_roar = true,
    pudge_dismember = true, tidehunter_ravage = true, disruptor_kinetic_field = true,
    disruptor_static_storm = true, centaur_hoof_stomp = true, elder_titan_echo_stomp = true,
  }

  local MOVEMENT_MODIFIERS = {
    techies_blast_off = { "modifier_techies_suicide", "modifier_techies_blast_off" },
    spirit_breaker_charge_of_darkness = { "modifier_spirit_breaker_charge_of_darkness" },
    magnataur_skewer = { "modifier_magnataur_skewer_movement", "modifier_magnataur_skewer" },
    earth_spirit_rolling_boulder = { "modifier_earth_spirit_rolling_boulder_caster" },
    pangolier_rolling_thunder = { "modifier_pangolier_rolling_thunder" },
  }

  local GLOBAL_THREATS = {
    enigma_black_hole = true, magnataur_reverse_polarity = true, faceless_void_chronosphere = true,
  }

  local BLINK_THREATS = {
    item_blink = true, item_arcane_blink = true, item_swift_blink = true, item_overwhelming_blink = true,
    antimage_blink = true, phantom_assassin_phantom_strike = true,
  }

  local AREA_THREATS = {
    tidehunter_ravage = {},
    centaur_hoof_stomp = { modifier = "hoof_stomp" },
    elder_titan_echo_stomp = {},
    disruptor_kinetic_field = { point = true },
    disruptor_static_storm = { point = true },
    jakiro_ice_path = { point = true, defaultRadius = 400, line = true },
    jakiro_macropyre = { point = true, defaultRadius = 400, line = true, delay = 0.3 },
    kez_raptor_dance = { defaultRadius = 530 },
    nevermore_requiem = { defaultRadius = 400 },
  }
  local AREA_MARGIN = 50

  local pendingLine   = nil
  local lastCastTime  = -100
  local lastThreatKey = ""
  local lastThreatTime = -100
  local lastScanTime  = -100
  local turretAbility = nil
  local statusText    = "waiting"
  local activeMovementThreats = {}
  local movementSpeedSamples  = {}
  local movementKinematics    = {}
  local reversePolarityStates = {}
  local blastOffThreats       = {}
  local techiesFlightStates   = {}
  local meleeAttackStates     = {}
  local runtimeCache = { time = -100, heroes = nil, npcs = nil }
  local movementSampleTime  = -100
  local movementSampleCache = {}
  local turretSearchTime    = -100
  local turretSearchHeroIndex = nil
  local TURRET_SEARCH_INTERVAL = 0.5
  local dodge = { off = {}, phases = {} }

  local abilityCache = {}
  local abilityCacheTime = -100
  local ABILITY_CACHE_DURATION = 2

  local function now() return GameRules.GetGameTime() end

  local function distance2D(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
  end

  local function isLocalTinker(hero)
    return hero and Entity.IsHero(hero) and Entity.GetUnitName(hero) == "npc_dota_hero_tinker" and Entity.IsAlive(hero)
  end

  local function isEnemy(unit, hero)
    return unit and hero and Entity.IsHero(unit)
        and Entity.GetTeamNum(unit) ~= Entity.GetTeamNum(hero)
        and Entity.IsAlive(unit) and not Entity.IsDormant(unit)
  end

  local function abilityName(ability)
    if not ability then return "" end
    local name = Ability.GetName(ability)
    if name and name ~= "" then return name end
    return Ability.GetBaseName(ability) or ""
  end

  local function findTurretAbility(hero)
    if turretAbility and Entity.IsEntity(turretAbility) then return turretAbility end
    local heroIndex = Entity.GetIndex(hero)
    local currentTime = now()
    if turretSearchHeroIndex == heroIndex and currentTime - turretSearchTime < TURRET_SEARCH_INTERVAL then
      return nil
    end
    turretSearchHeroIndex = heroIndex
    turretSearchTime = currentTime
    for index = 0, 23 do
      local ability = NPC.GetAbilityByIndex(hero, index)
      local name = abilityName(ability)
      if ability and name:find("turret", 1, true) then turretAbility = ability; return ability end
    end
    for _, name in ipairs({ "tinker_deploy_turrets", "tinker_turrets" }) do
      local ability = NPC.GetAbility(hero, name)
      if ability then turretAbility = ability; return ability end
    end
    return nil
  end

  local function getRuntimeHeroes()
    if runtimeCache.heroes == nil then runtimeCache.heroes = Heroes.GetAll() end
    return runtimeCache.heroes
  end

  local function getRuntimeNpcs()
    if runtimeCache.npcs == nil then runtimeCache.npcs = NPCs.GetAll() end
    return runtimeCache.npcs
  end

  local function beginRuntimeFrame(currentTime)
    if runtimeCache.time == currentTime then return end
    runtimeCache.time = currentTime
    runtimeCache.heroes = Heroes.GetAll()
    runtimeCache.npcs = NPCs.GetAll()
    movementSampleTime = currentTime
    movementSampleCache = {}
  end

  local function getAreaRadius(ability, threatName)
    local area = AREA_THREATS[threatName]
    if not area then return nil end
    local radius = ability and Ability.GetLevelSpecialValueFor(ability, "radius") or 0
    if radius <= 0 then radius = area.defaultRadius or 0 end
    if radius <= 0 then return 0 end
    return radius + AREA_MARGIN
  end

  local function getAreaSources(caster, threatName)
    local sources = { Entity.GetAbsOrigin(caster) }
    if threatName ~= "elder_titan_echo_stomp" then return sources end
    local team = Entity.GetTeamNum(caster)
    for _, unit in ipairs(getRuntimeNpcs()) do
      local name = Entity.GetUnitName(unit)
      if name and name:find("ancestral_spirit", 1, true)
          and Entity.GetTeamNum(unit) == team and Entity.IsAlive(unit) then
        table.insert(sources, Entity.GetAbsOrigin(unit))
      end
    end
    return sources
  end

  local function getNearestAreaSource(hero, caster, threatName, radius)
    local heroPosition = Entity.GetAbsOrigin(hero)
    local nearest, nearestDistance = nil, radius
    for _, position in ipairs(getAreaSources(caster, threatName)) do
      local distance = distance2D(position, heroPosition)
      if distance <= nearestDistance then nearest = position; nearestDistance = distance end
    end
    return nearest
  end

  local function threatAffectsHero(data, hero, caster, threatName)
    if GLOBAL_THREATS[threatName] then return true end
    local heroPosition   = Entity.GetAbsOrigin(hero)
    local casterPosition = Entity.GetAbsOrigin(caster)
    local casterDistance = distance2D(casterPosition, heroPosition)

    local areaRadius = getAreaRadius(data.ability, threatName)
    if areaRadius then
      if AREA_THREATS[threatName].point then
        local point = data.position or casterPosition
        return distance2D(point, heroPosition) <= areaRadius
      end
      return getNearestAreaSource(hero, caster, threatName, areaRadius) ~= nil
    end

    if BLINK_THREATS[threatName] then
      if not isEnemy(caster, hero) then return false end
      if threatName == "phantom_assassin_phantom_strike" then return data.target == hero end
      return data.position and distance2D(data.position, heroPosition) <= BLINK_DODGE_RADIUS
    end

    if MOVEMENT_NAMES[threatName] then return casterDistance <= TURRET_RADIUS end
    if data.target == hero then return true end
    if data.position and distance2D(data.position, heroPosition) <= TURRET_RADIUS then return true end
    return casterDistance <= TURRET_RADIUS
  end

  local function getBlinkTurretPosition(hero, destination, maxOffset)
    local heroPosition = Entity.GetAbsOrigin(hero)
    local dx = destination.x - heroPosition.x
    local dy = destination.y - heroPosition.y
    local distance = math.sqrt(dx * dx + dy * dy)
    if distance < 0.001 then return heroPosition end
    local offset = math.min(maxOffset, distance)
    return Vector(heroPosition.x + dx / distance * offset, heroPosition.y + dy / distance * offset, heroPosition.z)
  end

  local function getThreatCaster(data)
    if data.ability then
      local owner = Ability.GetOwner(data.ability)
      if owner and Entity.IsNPC(owner) then return owner end
    end
    return data.npc
  end

  local function canCast(ability)
    return ability and Ability.IsReady(ability) and Ability.CanBeExecuted(ability) == -1
  end

  local function sampleMovement(unit)
    local index = Entity.GetIndex(unit)
    if movementSampleTime == now() and movementSampleCache[index] then return movementSampleCache[index] end

    local position = Entity.GetAbsOrigin(unit)
    local currentTime = now()
    local currentSpeed = NPC.GetMoveSpeed(unit)
    local state = movementKinematics[index]

    if not state then
      state = {
        position = position, time = currentTime,
        speed = (currentSpeed and currentSpeed > 0) and currentSpeed or DEFAULT_MOVE_SPEED,
        velocityX = 0, velocityY = 0, directionX = 0, directionY = 0,
      }
      movementKinematics[index] = state
      movementSpeedSamples[index] = state.speed
      movementSampleCache[index] = state
      return state
    end

    local deltaTime = currentTime - state.time
    if deltaTime > 0.005 and deltaTime < 0.25 then
      local velocityX = (position.x - state.position.x) / deltaTime
      local velocityY = (position.y - state.position.y) / deltaTime
      local measuredSpeed = math.sqrt(velocityX * velocityX + velocityY * velocityY)
      if measuredSpeed >= 50 then
        local pvx = state.velocityX or 0
        local pvy = state.velocityY or 0
        local blend = state.hasVelocity and 0.65 or 0
        local bvx = pvx * blend + velocityX * (1 - blend)
        local bvy = pvy * blend + velocityY * (1 - blend)
        local bs  = math.sqrt(bvx * bvx + bvy * bvy)
        if bs >= 50 then
          state.velocityX = bvx
          state.velocityY = bvy
          state.speed = bs
          state.directionX = bvx / bs
          state.directionY = bvy / bs
          state.hasVelocity = true
        end
      end
    end
    if currentSpeed and currentSpeed > state.speed then state.speed = currentSpeed end
    state.position = position
    state.time = currentTime
    movementSpeedSamples[index] = state.speed
    movementSampleCache[index] = state
    return state
  end

  local function getPredictedSpeed(unit)
    local state = sampleMovement(unit)
    local currentSpeed = NPC.GetMoveSpeed(unit)
    local speed = state.speed or DEFAULT_MOVE_SPEED
    if currentSpeed and currentSpeed > speed then speed = currentSpeed end
    return speed
  end

  local function getPredictedThreatPosition(hero, caster, threatName)
    local state = sampleMovement(caster)
    local casterPosition = Entity.GetAbsOrigin(caster)
    local heroPosition   = Entity.GetAbsOrigin(hero)
    local dx = heroPosition.x - casterPosition.x
    local dy = heroPosition.y - casterPosition.y
    local length = math.sqrt(dx * dx + dy * dy)
    local speed = getPredictedSpeed(caster)
    local horizon = TURRET_DELAY + MOVEMENT_PREFIRE_LEAD
    if length < 0.001 then return casterPosition end
    local directionX = dx / length
    local directionY = dy / length
    local movementSpeed = math.sqrt((state.velocityX or 0) * (state.velocityX or 0)
        + (state.velocityY or 0) * (state.velocityY or 0))
    if movementSpeed >= 50 then
      directionX = state.velocityX / movementSpeed
      directionY = state.velocityY / movementSpeed
      speed = movementSpeed
    end
    if threatName == "magnataur_skewer" and speed < MAGNUS_SKEWER_SPEED then speed = MAGNUS_SKEWER_SPEED end
    return Vector(casterPosition.x + directionX * speed * horizon,
                  casterPosition.y + directionY * speed * horizon, casterPosition.z)
  end

  local function getNetherStrikeLandingPosition(hero, caster, ability)
    local heroState   = sampleMovement(hero)
    local casterState = sampleMovement(caster)
    local heroPosition   = Entity.GetAbsOrigin(hero)
    local casterPosition = Entity.GetAbsOrigin(caster)
    local castPoint = Ability.GetCastPoint(ability, true)
    if not castPoint or castPoint < 0 then castPoint = NETHER_STRIKE_DEFAULT_CAST_POINT end
    local impactHeroPosition = Vector(
      heroPosition.x + (heroState.velocityX or 0) * castPoint,
      heroPosition.y + (heroState.velocityY or 0) * castPoint, heroPosition.z)
    local impactCasterPosition = Vector(
      casterPosition.x + (casterState.velocityX or 0) * castPoint,
      casterPosition.y + (casterState.velocityY or 0) * castPoint, casterPosition.z)
    local dx = impactCasterPosition.x - impactHeroPosition.x
    local dy = impactCasterPosition.y - impactHeroPosition.y
    local distance = math.sqrt(dx * dx + dy * dy)
    if distance < 0.001 then return impactHeroPosition end
    return Vector(impactHeroPosition.x + dx / distance * NETHER_STRIKE_PUSH_DISTANCE,
                  impactHeroPosition.y + dy / distance * NETHER_STRIKE_PUSH_DISTANCE, impactHeroPosition.z)
  end

  local function getMovementTurretPosition(hero, caster, predictedPosition, castRange)
    local heroPosition = Entity.GetAbsOrigin(hero)
    local dx = predictedPosition.x - heroPosition.x
    local dy = predictedPosition.y - heroPosition.y
    local distance = math.sqrt(dx * dx + dy * dy)
    if distance < 0.001 then return heroPosition end
    local maxRange = math.min(castRange, TURRET_RADIUS)
    if distance <= maxRange then return predictedPosition end
    local factor = maxRange / distance
    return Vector(heroPosition.x + dx * factor, heroPosition.y + dy * factor, predictedPosition.z)
  end

  local function getPredictedFlightPosition(hero, caster)
    local state = sampleMovement(caster)
    local casterPosition = Entity.GetAbsOrigin(caster)
    local heroPosition   = Entity.GetAbsOrigin(hero)
    local horizon = TURRET_DELAY + PREFIRE_LEAD
    local velocityX = state.velocityX or 0
    local velocityY = state.velocityY or 0
    local speed = math.sqrt(velocityX * velocityX + velocityY * velocityY)
    if speed < 50 then
      local dx = casterPosition.x - heroPosition.x
      local dy = casterPosition.y - heroPosition.y
      local length = math.sqrt(dx * dx + dy * dy)
      if length > 0.001 then
        velocityX = dx / length * (state.speed or DEFAULT_MOVE_SPEED)
        velocityY = dy / length * (state.speed or DEFAULT_MOVE_SPEED)
      end
    end
    return Vector(casterPosition.x + velocityX * horizon, casterPosition.y + velocityY * horizon, casterPosition.z)
  end

  local function getTechiesLandingPosition(hero, caster, modifier)
    local state = techiesFlightStates[Entity.GetIndex(caster)]
    if not state or not modifier or not state.hasVelocity then return nil, nil end
    local currentTime = now()
    local dieTime = Modifier.GetDieTime(modifier)
    local remaining = dieTime and dieTime - currentTime or 0
    if remaining <= 0 then
      local creationTime = Modifier.GetCreationTime(modifier)
      local duration = Modifier.GetDuration(modifier)
      if creationTime and duration and duration > 0 then remaining = creationTime + duration - currentTime end
    end
    if not remaining or remaining <= 0 or remaining > 1.5 then
      remaining = TECHIES_FLIGHT_DURATION - (currentTime - state.startedAt)
    end
    if remaining <= 0 then return nil, remaining end
    local position = Entity.GetAbsOrigin(caster)
    return Vector(position.x + state.velocityX * remaining, position.y + state.velocityY * remaining, position.z), remaining
  end

  local function getTechiesRingCastPosition(hero, centerPosition)
    local heroPosition = Entity.GetAbsOrigin(hero)
    local dx = centerPosition.x - heroPosition.x
    local dy = centerPosition.y - heroPosition.y
    local distance = math.sqrt(dx * dx + dy * dy)
    if distance < 0.001 then return nil end
    local offset = math.min(SPECIAL_TURRET_OFFSET, distance)
    return Vector(heroPosition.x + dx / distance * offset, heroPosition.y + dy / distance * offset, heroPosition.z)
  end

  local function updateTechiesFlightState(caster, modifier)
    local index = Entity.GetIndex(caster)
    local position = Entity.GetAbsOrigin(caster)
    local currentTime = now()
    local state = techiesFlightStates[index]
    local modifierKey = Modifier.GetCreationTime(modifier) or Modifier.GetName(modifier)
    local movementState = movementKinematics[index]
    local launchVelocityX = movementState and movementState.velocityX or 0
    local launchVelocityY = movementState and movementState.velocityY or 0
    local launchSpeed = math.sqrt(launchVelocityX * launchVelocityX + launchVelocityY * launchVelocityY)

    if not state then
      techiesFlightStates[index] = {
        position = position, time = currentTime, modifierKey = modifierKey, startedAt = currentTime,
        velocityX = launchVelocityX, velocityY = launchVelocityY, hasVelocity = launchSpeed >= 50,
      }
      return
    end
    if state.modifierKey ~= modifierKey then
      state.position = position; state.time = currentTime; state.modifierKey = modifierKey
      state.startedAt = currentTime; state.velocityX = launchVelocityX; state.velocityY = launchVelocityY
      state.hasVelocity = launchSpeed >= 50
      return
    end
    local deltaTime = currentTime - state.time
    if deltaTime > 0.005 and deltaTime < 0.25 then
      local velocityX = (position.x - state.position.x) / deltaTime
      local velocityY = (position.y - state.position.y) / deltaTime
      local speed = math.sqrt(velocityX * velocityX + velocityY * velocityY)
      if speed >= 50 then state.velocityX = velocityX; state.velocityY = velocityY; state.hasVelocity = true end
    end
    state.position = position
    state.time = currentTime
  end

  local function getTurretCastPosition(origin, predictedPosition, castRange)
    local dx = predictedPosition.x - origin.x
    local dy = predictedPosition.y - origin.y
    local distance = math.sqrt(dx * dx + dy * dy)
    if distance < 0.001 then return nil end
    local targetRange = distance
    if targetRange > castRange then targetRange = castRange end
    local factor = targetRange / distance
    return Vector(origin.x + dx * factor, origin.y + dy * factor, predictedPosition.z)
  end

  local function getTurretCastRange(ability)
    local range = Ability.GetCastRange(ability)
    if not range or range <= 0 then return TURRET_RADIUS end
    return range
  end

  local function castTurret(hero, caster, threatName, targetPosition)
    if Config.TurretDodge.InvisSafe:Get()
        and NPC.HasState(hero, Enum.ModifierState.MODIFIER_STATE_INVISIBLE) then
      statusText = "invisible"
      return false
    end
    local turret = findTurretAbility(hero)
    if not canCast(turret) then statusText = "turret not ready"; return false end
    local heroPosition = Entity.GetAbsOrigin(hero)
    local castRange = getTurretCastRange(turret)
    local castPosition = targetPosition or getPredictedThreatPosition(hero, caster)
    local predictedDistance = distance2D(heroPosition, castPosition)
    if targetPosition then
      if predictedDistance > castRange then statusText = "reverse polarity out of range"; return false end
    else
      if predictedDistance > castRange + INTERRUPT_RADIUS then statusText = "waiting for cast range"; return false end
      castPosition = getTurretCastPosition(heroPosition, castPosition, castRange)
      if not castPosition then statusText = "invalid cast position"; return false end
    end
    Ability.CastPosition(turret, castPosition, false, false, true, "tinker_turret_dodge")
    lastCastTime = now()
    lastThreatKey = tostring(Entity.GetIndex(caster)) .. ":" .. threatName
    lastThreatTime = lastCastTime
    activeMovementThreats[lastThreatKey] = true
    statusText = "stun: " .. threatName
    return true
  end

  local function isThreatOff(heroName, threatName)
    local key = heroName .. "_" .. threatName
    local value = dodge.off[key]
    if value == nil then
      value = IniConfig.ReadInt(PANEL_CONFIG, "off_" .. key, 0) == 1
      dodge.off[key] = value
    end
    return value
  end

  local function setThreatOff(heroName, threatName, value)
    local key = heroName .. "_" .. threatName
    dodge.off[key] = value
    IniConfig.WriteInt(PANEL_CONFIG, "off_" .. key, value and 1 or 0)
  end

  local function threatKey(threatName)
    if threatName:sub(1, 5) == "item_" then return "blink" end
    return threatName
  end

  local blinkHeroNames = {}

  local function updateBlinkHeroFilter(localHero)
    if not localHero then return end
    local localTeam = Entity.GetTeamNum(localHero)
    local enemyNames, items = {}, {}
    for _, hero in ipairs(Heroes.GetAll()) do
      local unitName = Entity.GetUnitName(hero)
      if unitName and unitName ~= "" and Entity.GetTeamNum(hero) ~= localTeam and not enemyNames[unitName] then
        enemyNames[unitName] = true
        table.insert(items, { unitName, "panorama/images/heroes/icons/" .. unitName .. "_png.vtex_c", true })
      end
    end

    local changed = false
    for name in pairs(enemyNames) do if not blinkHeroNames[name] then changed = true; break end end
    if not changed then
      for name in pairs(blinkHeroNames) do if not enemyNames[name] then changed = true; break end end
    end
    if not changed then return end

    local filter = Config.TurretDodge and Config.TurretDodge.Heroes
    if filter and filter.Update then
      local enabledNames = {}
      for _, name in ipairs(filter:ListEnabled()) do enabledNames[name] = true end
      filter:Update(items, false, true)
      filter:Set({})
      for name in pairs(enemyNames) do filter:Set(name, enabledNames[name] ~= false) end
    end
    blinkHeroNames = enemyNames
  end

  local function isThreatEnabled(caster, threatName)
    local heroName = caster and Entity.GetUnitName(caster)
    if not heroName then return true end
    -- "Dodge Blink from": if the enemy list is populated, dodge only from checked heroes.
    local filter = Config.TurretDodge and Config.TurretDodge.Heroes
    if filter then
      local listed = nil
      if filter.List then listed = filter:List() end
      if listed and #listed > 0 and filter:Get(heroName) == false then return false end
    end
    return not isThreatOff(heroName, threatKey(threatName))
  end

  local function requestTurret(hero, caster, threatName, targetPosition, onSuccess)
    if not isThreatEnabled(caster, threatName) then return end
    if castTurret(hero, caster, threatName, targetPosition) and onSuccess then onSuccess() end
  end

  local function hasMovementThreat(unit, threatName)
    local modifiers = MOVEMENT_MODIFIERS[threatName]
    if not modifiers then return false end
    for _, modifierName in ipairs(modifiers) do
      if NPC.HasModifier(unit, modifierName) then return true end
    end
    return false
  end

  local function getCachedAbility(unit, abilityName_)
    local index = Entity.GetIndex(unit)
    local key = index .. ":" .. abilityName_
    local cached = abilityCache[key]
    if cached ~= nil then
      if cached == false then return nil end
      if Entity.IsEntity(cached) then return cached end
      abilityCache[key] = false
      return nil
    end
    local ability = NPC.GetAbility(unit, abilityName_)
    abilityCache[key] = ability or false
    return ability
  end

  local function clearAbilityCache()
    local currentTime = now()
    if currentTime - abilityCacheTime > ABILITY_CACHE_DURATION then
      abilityCache = {}
      abilityCacheTime = currentTime
    end
  end

  local function hasModifierLike(unit, pattern)
    for _, modifier in ipairs(NPC.GetModifiers(unit) or {}) do
      local name = Modifier.GetName(modifier)
      if name and name:find(pattern, 1, true) then return true end
    end
    return false
  end

  local function scanReversePolaritySingle(hero, enemy, enemyIndex)
    local ability = getCachedAbility(enemy, "magnataur_reverse_polarity")
    if ability then
      local inPhase = Ability.IsInAbilityPhase(ability)
      local state = reversePolarityStates[enemyIndex]
      if not state then
        state = { inPhase = false, cooldown = Ability.GetCooldown(ability) or 0 }
        reversePolarityStates[enemyIndex] = state
      end
      local cooldown = Ability.GetCooldown(ability) or 0
      local phaseStarted = inPhase and not state.inPhase
      local cooldownStarted = cooldown > state.cooldown + 0.05
      if phaseStarted or cooldownStarted then
        requestTurret(hero, enemy, "magnataur_reverse_polarity", Entity.GetAbsOrigin(enemy))
      end
      state.inPhase = inPhase
      state.cooldown = cooldown
    end
  end

  local function scanMovementThreatsSingle(hero, enemy, enemyIndex, heroPosition, enemyPosition,
                                           distance, castRange, seenThreats, seenMovementUnits, sampledUnits)
    for threatName in pairs(MOVEMENT_MODIFIERS) do
      if threatName ~= "techies_blast_off" and hasMovementThreat(enemy, threatName) then
        seenMovementUnits[enemyIndex] = true
        local tKey = tostring(enemyIndex) .. ":" .. threatName
        seenThreats[tKey] = true
        local predictedPosition = getPredictedThreatPosition(hero, enemy, threatName)
        local predictedDistance = distance2D(predictedPosition, heroPosition)
        if predictedDistance <= castRange + INTERRUPT_RADIUS and not activeMovementThreats[tKey] then
          local castPosition = getMovementTurretPosition(hero, enemy, predictedPosition, castRange)
          if castPosition then requestTurret(hero, enemy, threatName, castPosition) end
        end
        break
      end
    end
  end

  local function scanTechiesBlastOffSingle(hero, enemy, enemyIndex, enemyPosition, heroPosition,
                                           distance, turret, castRange, seenThreats, sampledUnits)
    local key = tostring(enemyIndex) .. ":techies_blast_off"
    if not sampledUnits[enemyIndex] then sampleMovement(enemy) end
    local activeModifier, activeModifierObject = nil, nil
    for _, modifier in ipairs(NPC.GetModifiers(enemy) or {}) do
      local modifierName = Modifier.GetName(modifier)
      if modifierName == "modifier_techies_suicide" or modifierName == "modifier_techies_blast_off"
          or modifierName == "modifier_techies_suicide_leap"
          or (string.find(modifierName or "", "techies") and string.find(modifierName or "", "suicide")) then
        activeModifier = modifierName
        activeModifierObject = modifier
        break
      end
    end
    local ability = getCachedAbility(enemy, "techies_suicide") or getCachedAbility(enemy, "techies_blast_off")
    local inPhase = ability and Ability.IsInAbilityPhase(ability) or false
    local active = activeModifier ~= nil
    if active then
      updateTechiesFlightState(enemy, activeModifierObject)
    else
      techiesFlightStates[enemyIndex] = nil
    end
    if inPhase or active then
      seenThreats[key] = true
      if active and not blastOffThreats[key] then
        local predictedPosition = getPredictedFlightPosition(hero, enemy)
        local landingPosition = getTechiesLandingPosition(hero, enemy, activeModifierObject)
        local blastCenter = landingPosition or predictedPosition or enemyPosition
        local blastDistance = distance2D(blastCenter, heroPosition)
        local castPosition = nil
        if blastDistance <= TECHIES_BLAST_RADIUS then
          castPosition = getTechiesRingCastPosition(hero, blastCenter)
        end
        if castPosition then
          requestTurret(hero, enemy, ability and abilityName(ability) or "techies_blast_off",
            castPosition, function() blastOffThreats[key] = true end)
        end
      end
    end
  end

  local deathWardDone = {}

  local function scanDeathWards(hero)
    local heroPosition = Entity.GetAbsOrigin(hero)
    local team = Entity.GetTeamNum(hero)
    local seen = {}
    for _, unit in ipairs(getRuntimeNpcs()) do
      local name = Entity.GetUnitName(unit)
      if name and name:find("death_ward", 1, true)
          and Entity.GetTeamNum(unit) ~= team and Entity.IsAlive(unit) and not Entity.IsDormant(unit) then
        local index = Entity.GetIndex(unit)
        seen[index] = true
        if not deathWardDone[index] then
          local wardPosition = Entity.GetAbsOrigin(unit)
          if distance2D(wardPosition, heroPosition) <= 800 then
            -- One push per ward: knock Tinker away from it.
            deathWardDone[index] = true
            castTurret(hero, unit, "witch_doctor_death_ward",
              getBlinkTurretPosition(hero, wardPosition, SPECIAL_TURRET_OFFSET))
          end
        end
      end
    end
    for index in pairs(deathWardDone) do
      if not seen[index] then deathWardDone[index] = nil end
    end
  end

  local function scanSpiritStomps(hero)
    local heroPosition = Entity.GetAbsOrigin(hero)
    local team = Entity.GetTeamNum(hero)
    for _, unit in ipairs(getRuntimeNpcs()) do
      local name = Entity.GetUnitName(unit)
      if name and name:find("ancestral_spirit", 1, true)
          and Entity.GetTeamNum(unit) ~= team and Entity.IsAlive(unit) and not Entity.IsDormant(unit) then
        local ability = getCachedAbility(unit, "elder_titan_echo_stomp_spirit")
        local key = Entity.GetIndex(unit) .. ":spirit_stomp"
        local active = hasModifierLike(unit, "ancestral_spirit_cast_time")
            or (ability ~= nil and (Ability.IsInAbilityPhase(ability) or Ability.IsChannelling(ability)))
        if active and not dodge.phases[key] then
          local spiritPosition = Entity.GetAbsOrigin(unit)
          local radius = getAreaRadius(ability, "elder_titan_echo_stomp")
          local distance = distance2D(spiritPosition, heroPosition)
          if not isThreatOff("npc_dota_hero_elder_titan", "elder_titan_echo_stomp") and distance <= radius then
            castTurret(hero, unit, "elder_titan_echo_stomp",
              getBlinkTurretPosition(hero, spiritPosition, SPECIAL_TURRET_OFFSET))
          end
        end
        dodge.phases[key] = active
      end
    end
  end

  local handleMeleeAttack, handleThreat

  local function scanAreaPhasesSingle(hero, enemy, enemyIndex)
    for threatName, area in pairs(AREA_THREATS) do
      if not area.point then
        local ability = getCachedAbility(enemy, threatName)
        local key = enemyIndex .. ":" .. threatName
        local active = ability ~= nil
            and (Ability.IsInAbilityPhase(ability) or Ability.IsChannelling(ability)
                 or (area.modifier ~= nil and hasModifierLike(enemy, area.modifier)))
        if active and not dodge.phases[key] then
          handleThreat({ npc = enemy, ability = ability })
        end
        dodge.phases[key] = active
      end
    end
  end

  local raptorDanceStates = {}

  local function scanKezRaptorSingle(hero, enemy, enemyIndex, heroPosition)
    local ability = getCachedAbility(enemy, "kez_raptor_dance")
    if not ability then return end
    local cooldown = Ability.GetCooldown(ability) or 0
    local inPhase = Ability.IsInAbilityPhase(ability) or Ability.IsChannelling(ability)
    local state = raptorDanceStates[enemyIndex]
    if not state then
      raptorDanceStates[enemyIndex] = { cooldown = cooldown, inPhase = inPhase, untilT = nil, fired = false }
      return
    end
    local cast = (inPhase and not state.inPhase) or cooldown > state.cooldown + 0.05
    state.cooldown = cooldown
    state.inPhase = inPhase
    if cast then
      state.untilT = now() + 7
      state.fired = false
    end
    if state.fired then return end
    if not state.untilT or now() > state.untilT then return end
    if not isThreatEnabled(enemy, "kez_raptor_dance") then return end
    local enemyPosition = Entity.GetAbsOrigin(enemy)
    if distance2D(enemyPosition, heroPosition) > 530 + 150 then return end
    requestTurret(hero, enemy, "kez_raptor_dance",
      getBlinkTurretPosition(hero, enemyPosition, SPECIAL_TURRET_OFFSET))
    state.fired = true
  end

  local kezGrappleLastCast = {}

  local function scanKezGrappleSingle(hero, enemy, enemyIndex, heroPosition)
    local name = Entity.GetUnitName(enemy)
    if not name or not name:find("kez", 1, true) then return end
    local charging = false
    for _, modifier in ipairs(NPC.GetModifiers(enemy) or {}) do
      local modifierName = Modifier.GetName(modifier)
      if modifierName and modifierName:find("grappling", 1, true) then
        charging = true
        break
      end
    end
    if not charging then return end
    local lastCast = kezGrappleLastCast[enemyIndex] or 0
    if now() - lastCast < 0.3 then return end
    kezGrappleLastCast[enemyIndex] = now()
    requestTurret(hero, enemy, "kez_grappling_claw",
      getBlinkTurretPosition(hero, Entity.GetAbsOrigin(enemy), SPECIAL_TURRET_OFFSET))
  end

  local function scanAllThreats(hero)
    local heroPosition = Entity.GetAbsOrigin(hero)
    local turret = findTurretAbility(hero)
    local castRange = turret and getTurretCastRange(turret) or TURRET_RADIUS
    local seenMovementThreats, seenBlastOffThreats = {}, {}
    local seenMovementUnits, sampledUnits = {}, {}

    for _, enemy in ipairs(getRuntimeHeroes()) do
      if isEnemy(enemy, hero) then
        local enemyIndex = Entity.GetIndex(enemy)
        local enemyPosition = Entity.GetAbsOrigin(enemy)
        local distance = distance2D(enemyPosition, heroPosition)
        handleMeleeAttack(enemy, hero)
        if distance <= SPEED_SAMPLE_RADIUS then
          sampleMovement(enemy)
          sampledUnits[enemyIndex] = true
        end
        scanReversePolaritySingle(hero, enemy, enemyIndex)
        scanMovementThreatsSingle(hero, enemy, enemyIndex, heroPosition, enemyPosition,
          distance, castRange, seenMovementThreats, seenMovementUnits, sampledUnits)
        scanTechiesBlastOffSingle(hero, enemy, enemyIndex, enemyPosition, heroPosition,
          distance, turret, castRange, seenBlastOffThreats, sampledUnits)
        scanAreaPhasesSingle(hero, enemy, enemyIndex)
        scanKezRaptorSingle(hero, enemy, enemyIndex, heroPosition)
        scanKezGrappleSingle(hero, enemy, enemyIndex, heroPosition)
      end
    end

    for tKey in pairs(activeMovementThreats) do
      if not seenMovementThreats[tKey] then activeMovementThreats[tKey] = nil end
    end
    for key in pairs(blastOffThreats) do
      if not seenBlastOffThreats[key] then blastOffThreats[key] = nil; activeMovementThreats[key] = nil end
    end
    for enemyIndex in pairs(movementSpeedSamples) do
      local enemy = Entity.Get(enemyIndex)
      if not enemy or not Entity.IsAlive(enemy) or not seenMovementUnits[enemyIndex] then
        movementSpeedSamples[enemyIndex] = nil
        movementKinematics[enemyIndex] = nil
        meleeAttackStates[enemyIndex] = nil
      end
    end

    scanSpiritStomps(hero)
    scanDeathWards(hero)
    clearAbilityCache()
  end

  handleMeleeAttack = function(attacker, hero, confirmed)
    if not Config.TurretDodge.MeleeProtect:Get() or not attacker then return end
    if now() < Config.TurretDodge.MeleeMinute:Get() * 60 then return end
    if not NPC.IsHero(attacker) or NPC.IsRanged(attacker)
        or not Entity.IsAlive(attacker) or not isEnemy(attacker, hero) then
      return
    end
    local attackerIndex = Entity.GetIndex(attacker)
    local distance = distance2D(Entity.GetAbsOrigin(attacker), Entity.GetAbsOrigin(hero))
    local attackRange = NPC.GetAttackRange(attacker) or 150
    local attacking = confirmed or (NPC.IsAttacking(attacker) and distance <= attackRange + 100)
    local wasAttacking = meleeAttackStates[attackerIndex] or false
    meleeAttackStates[attackerIndex] = attacking
    if not attacking or wasAttacking then return end
    local currentTime = now()
    local tKey = tostring(Entity.GetIndex(attacker)) .. ":melee_attack"
    if tKey == lastThreatKey and currentTime - lastThreatTime < 0.45 then return end
    local targetPosition = getBlinkTurretPosition(hero, Entity.GetAbsOrigin(attacker), SPECIAL_TURRET_OFFSET)
    castTurret(hero, attacker, "melee_attack", targetPosition)
  end

  local function handleMeleeAttackOrder(data, hero)
    if not data or data.order ~= Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET
        or not data.target or Entity.GetIndex(data.target) ~= Entity.GetIndex(hero) then
      return
    end
    handleMeleeAttack(data.npc, hero)
  end

    -- Turret position for a point-AoE threat.
  -- line (Ice Path) -> perpendicular to the line; circle -> away from centre.
  -- The turret knocks the OPPOSITE way, so place it opposite the escape dir.
  local function areaPointTurretPos(hero, caster, threatName, castPosition)
    local casterPos   = Entity.GetAbsOrigin(caster)
    local heroPosition = Entity.GetAbsOrigin(hero)
    local escapeDir
    if AREA_THREATS[threatName] and AREA_THREATS[threatName].line then
      local castPos = castPosition or heroPosition
      local lineDir = castPos - casterPos
      if lineDir:Length() < 1 then lineDir = heroPosition - casterPos end
      lineDir = lineDir:Normalized()
      local toHero = heroPosition - casterPos
      if (lineDir.x * toHero.y - lineDir.y * toHero.x) < 0 then
        escapeDir = Vector(lineDir.y, -lineDir.x, 0)
      else
        escapeDir = Vector(-lineDir.y, lineDir.x, 0)
      end
    else
      local toCenter = heroPosition - (castPosition or casterPos)
      if toCenter:Length() < 1 then toCenter = heroPosition - casterPos end
      escapeDir = toCenter:Normalized()
    end
    return heroPosition - escapeDir * SPECIAL_TURRET_OFFSET
  end

handleThreat = function(data)
    if not Config.TurretDodge.Enabled:Get() then return end
    local hero = Heroes.GetLocal()
    if not isLocalTinker(hero) then return end
    handleMeleeAttackOrder(data, hero)
    if not data or not data.ability or not isEnemy(data.npc, hero) then return end
    local threatName = abilityName(data.ability)
    if not THREAT_NAMES[threatName] then return end
    if threatName == "techies_blast_off" or threatName == "techies_suicide"
        or threatName == "magnataur_skewer" then
      return
    end
    if MOVEMENT_NAMES[threatName] and not Config.TurretDodge.Interrupt:Get() then return end
    if not threatAffectsHero(data, hero, data.npc, threatName) then return end
    local currentTime = now()
    if currentTime - lastCastTime < 0.08 then return end
    local tKey = tostring(Entity.GetIndex(data.npc)) .. ":" .. threatName
    if MOVEMENT_NAMES[threatName] and activeMovementThreats[tKey] then return end
    if tKey == lastThreatKey and currentTime - lastThreatTime < 0.45 then return end

    local targetPosition = nil
    if threatName == "enigma_black_hole" or threatName == "faceless_void_chronosphere" then
      local heroPosition = Entity.GetAbsOrigin(hero)
      local centerPosition = data.position or Entity.GetAbsOrigin(data.npc)
      local dx = centerPosition.x - heroPosition.x
      local dy = centerPosition.y - heroPosition.y
      local distance = math.sqrt(dx * dx + dy * dy)
      if distance > 0.001 then
        local offset = math.min(190, distance)
        targetPosition = Vector(heroPosition.x + dx / distance * offset,
                                heroPosition.y + dy / distance * offset, heroPosition.z)
      else
        targetPosition = heroPosition
      end
    elseif threatName == "magnataur_reverse_polarity" then
      targetPosition = Entity.GetAbsOrigin(data.npc)
    elseif threatName == "spirit_breaker_nether_strike" then
      targetPosition = getNetherStrikeLandingPosition(hero, data.npc, data.ability)
    elseif threatName == "kez_raptor_dance" then
      -- Circle around Kez: put the turret on his side so Tinker is knocked away.
      targetPosition = getBlinkTurretPosition(hero, Entity.GetAbsOrigin(data.npc), SPECIAL_TURRET_OFFSET)
    elseif threatName == "nevermore_requiem" then
      -- Centred on Shadow Fiend: after 0.15s of his cast, knock Tinker away from him.
      pendingLine = { at = currentTime + 0.25, caster = data.npc, threatName = threatName, under = true }
      return
    elseif BLINK_THREATS[threatName] then
      local destination = data.position
      if threatName == "phantom_assassin_phantom_strike" then destination = Entity.GetAbsOrigin(data.npc) end
      targetPosition = getBlinkTurretPosition(hero, destination or Entity.GetAbsOrigin(data.npc), SPECIAL_TURRET_OFFSET)
    elseif AREA_THREATS[threatName] and AREA_THREATS[threatName].point then
      local area = AREA_THREATS[threatName]
      if area.delay and area.delay > 0 then
        -- Small delay (e.g. Macropyre) -> let a bit of the animation play.
        pendingLine = { at = currentTime + area.delay, caster = data.npc,
                        threatName = threatName, position = data.position }
        return
      end
      -- Point AoE: line (Ice Path) -> perpendicular; circle -> away from centre.
      targetPosition = areaPointTurretPos(hero, data.npc, threatName, data.position)
    elseif STUN_NAMES[threatName] then
      local threatCaster = getThreatCaster(data)
      if threatCaster and Entity.IsNPC(threatCaster) then
        local sourcePosition = Entity.GetAbsOrigin(threatCaster)
        local areaRadius = getAreaRadius(data.ability, threatName)
        if areaRadius then
          if AREA_THREATS[threatName].point and data.position then
            sourcePosition = data.position
          else
            sourcePosition = getNearestAreaSource(hero, threatCaster, threatName, areaRadius) or sourcePosition
          end
        end
        targetPosition = getBlinkTurretPosition(hero, sourcePosition, SPECIAL_TURRET_OFFSET)
      end
    end
    requestTurret(hero, data.npc, threatName, targetPosition)
  end

  local function refreshStatus()
    local gameTime = now()
    if gameTime - lastScanTime < 0.5 then return end
    lastScanTime = gameTime
    local hero = Heroes.GetLocal()
    if not isLocalTinker(hero) then
      statusText = "not on Tinker"
      turretAbility = nil
      return
    end
    local turret = findTurretAbility(hero)
    if turret then
      statusText = canCast(turret) and "ready" or "cooldown"
    else
      statusText = "turret ability not found"
    end
  end

  return {
    OnPrepareOrder = function(data)
      handleThreat(data)
    end,
    OnEntityHurt = function(data)
      if not data or not data.source or not data.target then return end
      local hero = Heroes.GetLocal()
      if isLocalTinker(hero) and Entity.GetIndex(data.target) == Entity.GetIndex(hero) then
        handleMeleeAttack(data.source, hero, true)
      end
    end,
    Update = function()
      local currentTime = now()
      beginRuntimeFrame(currentTime)
      refreshStatus()
      local hero = Heroes.GetLocal()
      if isLocalTinker(hero) then
        updateBlinkHeroFilter(hero)
        if pendingLine and currentTime >= (pendingLine.at or 0) then
          local pl = pendingLine
          pendingLine = nil
          local caster = pl.caster
          if caster and Entity.IsEntity(caster) and Entity.IsAlive(caster)
              and isThreatEnabled(caster, pl.threatName) then
            if pl.under then
              -- Only if the caster is still close (guards against long-range casts).
              if distance2D(Entity.GetAbsOrigin(caster), Entity.GetAbsOrigin(hero)) <= 1000 then
                castTurret(hero, caster, pl.threatName,
                  getBlinkTurretPosition(hero, Entity.GetAbsOrigin(caster), SPECIAL_TURRET_OFFSET))
              end
            else
              castTurret(hero, caster, pl.threatName,
                areaPointTurretPos(hero, caster, pl.threatName, pl.position))
            end
          end
        end
      end
      if Config.TurretDodge.Enabled:Get() then
        if isLocalTinker(hero) then
          scanAllThreats(hero)
        end
      end
    end,
  }
end)()

script.OnDraw = function()
  if not Engine.IsInGame() then return end
  if not State.Hero or not Entity.IsAlive(State.Hero) then return end
  if Entity.GetUnitName(State.Hero) ~= "npc_dota_hero_tinker" then return end

  DrawStatusOverlay()
  DrawCampMapOverlay()

  if Config.Debug.World:Get() and State.CurrentFarmSpot then
    if Config.Debug.Pretty:Get() then
      DrawWorldSpotNeo(State.CurrentFarmSpot)
    else
      DrawWorldSpotMinimal(State.CurrentFarmSpot)
    end
  end

  if Config.Debug.World:Get() and State.PendingTPPos then
    DrawTPAnchorDebug(State.PendingTPPos, State.PendingTPPos, "Pending")
  end

  if Config.Debug.Overlay:Get() then
    DrawDockOverlay()
  end

  if showIndicator then
    local heroPos  = Entity.GetAbsOrigin(State.Hero)
    local mousePos = Input.GetWorldCursorPos()

    local heroScreen, heroVis   = Render.WorldToScreen(heroPos)
    local mouseScreen, mouseVis = Render.WorldToScreen(mousePos)

    if heroVis then
      Render.Circle(heroScreen, 40, Color(0, 255, 255, 255), 2.0)
      Render.FilledCircle(heroScreen, 38, Color(0, 255, 255, 60))
      Render.FilledCircle(heroScreen, 5, Color(255, 255, 255, 255))
    end

    if heroVis and mouseVis then
      Render.Line(heroScreen, mouseScreen, Color(0, 255, 255, 180), 1.5)
      Render.FilledCircle(mouseScreen, 6, Color(0, 255, 255, 200))
    end
  end
end

-- ── Camera follow: native camera lock convar ─────────────────
-- dota_camera_lock 1 = camera follows the hero, 0 = off.
local cameraFollowActive = nil
local cameraFollowSession = nil
local lastCameraFollowAssert = 0

local function SetCameraLock(on)
  local cv = ConVar and ConVar.Find and ConVar.Find("dota_camera_lock")
  if cv and ConVar.SetInt then
    ConVar.SetInt(cv, on and 1 or 0)
  else
    Engine.ExecuteCommand(on and "dota_camera_lock 1" or "dota_camera_lock 0")
  end
end

local function ApplyCameraFollow()
  if not Engine.IsInGame() then return end

  if State.SessionSig ~= cameraFollowSession then
    cameraFollowSession = State.SessionSig
    cameraFollowActive  = nil
  end

  local want = (Config.CameraFollow and Config.CameraFollow:Get())
      and (Config.AutoFarm and Config.AutoFarm:IsToggled()) and true or false
  local now  = GameRules.GetGameTime()

  if want ~= cameraFollowActive then
    cameraFollowActive = want
    SetCameraLock(want)
    lastCameraFollowAssert = now
    return
  end

  if want and (now - lastCameraFollowAssert) > 1.0 then
    local cv = ConVar and ConVar.Find and ConVar.Find("dota_camera_lock")
    if cv and ConVar.GetInt and ConVar.GetInt(cv) == 0 then
      SetCameraLock(true)
      lastCameraFollowAssert = now
    end
  end
end

-- ── Suppress hero auto-attack while autofarming ──────────────
local autoAttackVars = nil
local autoAttackSuppressed = false

local function GetAutoAttackVars()
  if autoAttackVars ~= nil then return autoAttackVars end
  autoAttackVars = false
  if not (ConVar and ConVar.Find and ConVar.GetInt and ConVar.SetInt) then return nil end
  local list = {}
  for _, name in ipairs({ "dota_player_units_auto_attack", "dota_player_units_auto_attack_after_spell" }) do
    local cv = ConVar.Find(name)
    if cv then
      list[#list + 1] = { cv = cv, orig = ConVar.GetInt(cv) }
    end
  end
  if #list > 0 then autoAttackVars = list end
  return autoAttackVars or nil
end

local function ApplyAutoAttackSuppression(on)
  if on == autoAttackSuppressed then return end
  local vars = GetAutoAttackVars()
  if not vars then return end
  autoAttackSuppressed = on
  for _, v in ipairs(vars) do
    ConVar.SetInt(v.cv, on and 0 or (v.orig or 1))
  end
end

-- ── Auto-Glimmer: cast Glimmer Cape on self during Rearm / after Blink ──
local glimmerOrderAt = 0
local lastBlinkCd    = 0
local function UpdateBlinkDetect()
  local blink = State.Blink
  if not blink then return end
  local cd = Ability.GetCooldown(blink) or 0
  if cd > lastBlinkCd + 0.05 and cd > 0 then
    State.LastBlinkAt = GameRules.GetGameTime()
  end
  lastBlinkCd = cd
end

local function HandleAutoGlimmer()
  if not (Config.AutoGlimmer and Config.AutoGlimmer:Get()) then return end
  if not State.Hero or not Entity.IsAlive(State.Hero) then return end

  local t = GameRules.GetGameTime()

  local want = false
  if Config.AutoGlimmerOptions.OnRearm:Get() then
    local rearm = State.Rearm or NPC.GetAbility(State.Hero, "tinker_rearm")
    if rearm then
      local isRearming = Ability.IsChannelling(rearm)
      if not isRearming and NPC.IsChannellingAbility(State.Hero) then
        local chanAb = NPC.GetChannellingAbility(State.Hero)
        if chanAb and chanAb == rearm then isRearming = true end
      end
      if isRearming then want = true end
    end
  end
  if not want and Config.AutoGlimmerOptions.OnBlink:Get() and State.LastBlinkAt
      and (t - State.LastBlinkAt) <= 0.25 then
    want = true
  end
  if not want then return end

  local glimmer = NPC.GetItem(State.Hero, "item_glimmer_cape", true)
  if not glimmer then return end
  if (Ability.GetCooldown(glimmer) or 0) > 0 then return end
  if (NPC.GetMana(State.Hero) or 0) < (Ability.GetManaCost(glimmer) or 0) then return end

  if t - (glimmerOrderAt or 0) < 0.2 then return end
  glimmerOrderAt = t
  Ability.CastTarget(glimmer, State.Hero)
end

script.OnUpdate = function()
  if not Engine.IsInGame() then return end

  -- Camp logger hotkeys (F6..F9)
  HandleCampLoggerHotkeys()

  State.OrdersThisUpdate = 0

  State.Hero   = Heroes.GetLocal()
  State.Player = Players.GetLocal()
  if not State.Hero or not Entity.IsEntity(State.Hero) then return end
  if Entity.GetUnitName(State.Hero) ~= "npc_dota_hero_tinker" then return end

  TurretDodge.Update()

  if Config.AutoFarmSwitch:Get() ~= Config.AutoFarm:IsToggled() then
    Config.AutoFarmSwitch:Set(Config.AutoFarm:IsToggled())
  end
  if Config.AutoGlimmer:Get() ~= Config.AutoGlimmerKey:IsToggled() then
    Config.AutoGlimmer:Set(Config.AutoGlimmerKey:IsToggled())
  end

  if showIndicator and (GlobalVars.GetCurTime() - lastTapTime) > DOUBLE_TAP_TIME then
    showIndicator = false
  end

  if not Entity.IsAlive(State.Hero) then
    State.FarmState                = "IDLE"
    State.CurrentFarmSpot          = nil
    State.AfterMarchCheck          = nil
    State.TargetSpotKey            = nil
    State.SpotCommitUntil          = 0
    State.CurrentSpotMarchCasts    = 0
    State.CurrentSpotMarchRequired = nil
    State.PendingMarchVerify       = nil
    State.CampAliveScanCache       = {}
    State.NeutralSnapshot          = { at = 0, list = {} }
    State.LaneCreepSnapshot        = { at = 0, list = {} }
    State.PendingLaneRotate        = false
    State.LaneTreeBlinkCache       = {}
    State.LaneBurstTargets         = {}
    showIndicator                  = false
    lastTapTime                    = 0
    return
  end

  State.HeroTeam     = Entity.GetTeamNum(State.Hero)
  UpdateCampMirrorForTeam(State.HeroTeam)
  State.IsChanneling = NPC.IsChannellingAbility(State.Hero)
  State.Rearm        = NPC.GetAbility(State.Hero, "tinker_rearm")
  State.March        = NPC.GetAbility(State.Hero, "tinker_march_of_the_machines")
  State.Laser        = NPC.GetAbility(State.Hero, "tinker_laser")
  State.KeenTeleport = NPC.GetAbility(State.Hero, "tinker_keen_teleport")
  State.Blink        = NPC.GetItem(State.Hero, "item_blink", true)
      or NPC.GetItem(State.Hero, "item_overwhelming_blink", true)
      or NPC.GetItem(State.Hero, "item_swift_blink", true)
      or NPC.GetItem(State.Hero, "item_arcane_blink", true)
  State.Shiva        = NPC.GetItem(State.Hero, "item_shivas_guard", true)
  State.Dagon        = Tinker.GetDagonItem()
  State.Meteor = NPC.GetItem(State.Hero, "item_meteor_hammer", true)
  MaybeResetCampStateForSession()
  UpdateRearmBlinkHold()
  ApplyCameraFollow()
  UpdateBlinkDetect()
  HandleAutoGlimmer()
  UpdateEnemySeen()

  local autoOn    = Config.AutoFarm:IsToggled()
  local autoWasOn = State.AutoFarmWasOn

  ApplyAutoAttackSuppression(autoOn)

  -- If автофарм только что выключили биндом – один раз отправляем героя на фонтан и выходим.
  if not autoOn then
    if State.AutoFarmWasOn then
      local fountainPos = (State.HeroTeam == 2) and Constants.FOUNTAIN_RADIANT or Constants.FOUNTAIN_DIRE
      if State.KeenTeleport and Ability.CanBeExecuted(State.KeenTeleport) == -1 then
        Tinker.TryTeleportTo(fountainPos, true)
      else
        Utils.MoveTo(fountainPos)
      end
    end
    State.AutoFarmWasOn = false
    State.PendingLaneRotate = false

    -- Полностью сбрасываем внутреннее состояние фарма
    if State.FarmState ~= "IDLE" then
      State.FarmState                = "IDLE"
      State.CurrentFarmSpot          = nil
      State.AfterMarchCheck          = nil
      State.TargetSpotKey            = nil
      State.SpotCommitUntil          = 0
      State.CurrentSpotMarchCasts    = 0
      State.CurrentSpotMarchRequired = nil
      State.PendingMarchVerify       = nil
      State.PendingLaneRotate        = false
      State.CachedBestSpot           = nil
      State.LaneTreeBlinkCache       = {}
    end
    return
  end

  if not autoWasOn then
    ResetFarmedCampFlags("autofarmToggleOn")
  end
  State.AutoFarmWasOn = true

  if autoOn then
    UpdateFarmedCampRespawns()
    Tinker.HandleAutoBottle()
  end

  TryCastMatrix("precast")
  Tinker.HandleFarming()
end
Config.MarchControl.UseCustom:SetCallback(function()
  SyncMarchSlidersDisabled()
end, true)

script.OnScriptsLoaded = function()
  CampMapUI.mapImage = Render.LoadImage(MAP_URL)
end

script.OnGameEnd = function()
  if cameraFollowActive then
    cameraFollowActive = false
    SetCameraLock(false)
  end
  ApplyAutoAttackSuppression(false)
end

script.OnPrepareUnitOrders = function(data)
  TurretDodge.OnPrepareOrder(data)
  return true
end

script.OnEntityHurt = function(data)
  TurretDodge.OnEntityHurt(data)
end

return script
