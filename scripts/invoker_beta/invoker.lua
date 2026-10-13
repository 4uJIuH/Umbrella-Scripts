---@diagnostic disable: undefined-global, param-type-mismatch

local invoker = {}
local helpers = {}

---@class Point3
---@field x number
---@field y number
---@field z number

---@class ActionDefinition
---@field id string
---@field name string
---@field short string
---@field runtimeNames string[]
---@field kind "spell"|"item"
---@field recipe? string[]
---@field targeting "none"|"self"|"ally"|"enemy"|"point"|"directional"
---@field damageType string
---@field projectileSpeed number
---@field fixedDelay number
---@field sharedCooldown string
---@field requiresScepter? string
---@field resetsWithRefresher boolean
---@field tags table<string, boolean>

---@class ActionState
---@field id string
---@field ability any?
---@field exists boolean
---@field learned boolean
---@field invoked boolean
---@field activated boolean
---@field canCast boolean
---@field inAbilityPhase boolean
---@field cooldown number
---@field cooldownLength number
---@field manaCost number
---@field castPoint number
---@field castRange number
---@field specials table<string, number>

---@class EnemyState
---@field entity any
---@field index integer
---@field alive boolean
---@field dormant boolean
---@field position Point3
---@field velocity Point3
---@field health number
---@field maxHealth number
---@field mana number
---@field magicMultiplier number
---@field disabledUntil number
---@field controlEndsAt number
---@field idleDuration number
---@field movementDuration number
---@field stableDuration number
---@field motionConfidence number

---@class InvokerSnapshot
---@field now number
---@field paused boolean
---@field activeGame boolean
---@field latency number
---@field hero table
---@field invoke table
---@field actions table<string, ActionState>
---@field target EnemyState?
---@field enemies EnemyState[]
---@field sunUnits table[]
---@field cursor Point3
---@field targetMode "normal"|"cursor"

---@class PlannedAction
---@field uid string
---@field actionId string
---@field sequenceIndex integer
---@field commandIndex integer
---@field prepareAt number
---@field readyAt number
---@field castAt number
---@field impactAt number
---@field effectEndAt number
---@field targetIndex integer?
---@field targetPosition Point3
---@field status string
---@field attempts integer
---@field movingForRange boolean

local cfg = {
	heroName = "npc_dota_hero_invoker",
	invokeOrbInterval = 0.035,
	autoOrbInterval = 0.04,
	invokeConfirmWindow = 0.65,
	castConfirmMin = 0.75,
	commandGap = 0.075,
	latencyOffset = 0.02,
	timingSafety = 0.065,
	planRecalcInterval = 0.12,
	floeMoveTimeout = 3,
	objectiveHistorySeconds = 0.8,
	objectiveRecentDamageSeconds = 0.6,
	roshanSpawnerScanSeconds = 5,
	targetReplanDistance = 85,
	groundAimReplanDistance = 55,
	groundAimSpeedDelta = 85,
	targetRadius = 1200,
	groundTargetRadius = 500,
	manualActionPause = 0.35,
	motionResetDistance = 200,
	sunRadius = 175,
	configName = "invoker_beta",
	maxComboActions = 16,
	panelPosition = Vec2(38, 245),
	bindSpellIds = {"cold_snap", "ice_wall", "emp", "tornado", "alacrity", "deafening_blast", "sun_strike", "chaos_meteor", "forge_spirit"},
	selfBindIds = {{"bindSelfGhost", "ghost_walk"}, {"bindSelfAlacrity", "alacrity"}},
	campScanInterval = 0.25,
	farmAimInterval = 0.1,
	campSearchRadius = 1600,
	stackPreparationWindow = 8,
	stackSpawnMargin = 0.15,
	stackLiftHeight = 450,
	stackLiftTransition = 0.35,
	farmPullTimeout = 12,
	farmAcquireRadius = 650,
	landingScanInterval = 0.1,
	landingImpactOffset = 0.08,
	landingMaxLate = 0.25,
	teleportParticleLifetime = 10,
	fogTeleportDuration = 3,
	teleportHistorySeconds = 30,
	teleportAmbiguityRadius = 1150,
	landingModifiers = {modifier_teleporting = "teleport", modifier_eul_cyclone = "cyclone", modifier_invoker_tornado = "cyclone"},
}

local menuIcons = {
	hero = "panorama/images/heroes/icons/npc_dota_hero_invoker_png.vtex_c",
	invoke = "panorama/images/spellicons/invoker_invoke_png.vtex_c",
	quas = "panorama/images/spellicons/invoker_quas_png.vtex_c",
	wex = "panorama/images/spellicons/invoker_wex_png.vtex_c",
	exort = "panorama/images/spellicons/invoker_exort_png.vtex_c",
	roshan = "panorama/images/hud/icon_roshan_psd.vtex_c",
	tormentor = "panorama/images/control_icons/24px/tormentor_png.vtex_c",
	fountain = "panorama/images/spellicons/fountain_heal_png.vtex_c",
}

local fontIcons = {
	bug = "\u{f188}",
	clock = "\u{f017}",
	compress = "\u{f066}",
	crosshairs = "\u{f05b}",
	exchange = "\u{f0ec}",
	forward = "\u{f04e}",
	list = "\u{f03a}",
	magic = "\u{f0d0}",
	pause = "\u{f04c}",
	percent = "\u{f295}",
	sliders = "\u{f1de}",
	users = "\u{f0c0}",
	view = "\u{f06e}",
}

local translations = {
	en = {
		["group.auto_steal"] = "Auto steal",
		["ui.auto_tormentor"] = "Steal Tormentor",
		["tip.auto_tormentor"] = "Estimates the shield from reflected damage and regeneration, including under fog. Resynchronizes when the actual barrier is available. Skips allied attempts. Hidden resistance changes or blocked reflections can make the estimate drift.",
		["gear.tormentor"] = "Tormentor steal settings",
		["ui.auto_roshan"] = "Steal Roshan with Sun Strike",
		["tip.auto_roshan"] = "Uses Roshan health, position and incoming damage, including under fog. Skips allied attempts and movement during Sun Strike's delay. Does not interrupt a held combo.",
		["gear.roshan"] = "Roshan steal settings",
		["ui.roshan_margin"] = "Damage margin",
		["tip.roshan_margin"] = "Reserve this much Sun Strike damage for health/timing uncertainty.",
		["tab.main"] = "Main",
		["tab.panels"] = "Panels",
		["tab.auto"] = "Automatic",
		["tab.extra"] = "Advanced",
		["tab.binds"] = "Binds",
		["group.automation"] = "Automation",
		["group.combo_selection"] = "Combo Selection",
		["ui.select_dynamic"] = "Select Dynamic",
		["ui.select_combo_1"] = "Select Combo 1",
		["ui.select_combo_2"] = "Select Combo 2",
		["ui.select_combo_3"] = "Select Combo 3",
		["ui.select_combo_4"] = "Select Combo 4",
		["ui.select_combo_5"] = "Select Combo 5",
		["tip.select_combo"] = "Select this combo without casting. Works with the combo panel hidden. If the combo key is held, the executor switches to the selected combo.",
		["group.self_cast"] = "Self cast",
		["group.prepare_binds"] = "Prepare spell",
		["ui.meteor_farm"] = "Ice Wall Farm",
		["gear.farm"] = "Ice Wall Farm",
		["ui.farm_hammer"] = "Use Meteor Hammer",
		["tip.farm_hammer"] = "After Ice Wall, use Meteor Hammer on the largest reachable creep group when the item is available and ready. Without it, continue farming with Ice Wall.",
		["ui.tornado_stack"] = "Tornado Stack",
		["ui.bind_quick_cast"] = "Quick cast after Craft",
		["ui.bind_aim_wall"] = "Aim Ice Wall at cursor",
		["tip.meteor_farm"] = "Hold to farm a nearby pair of camps. Prefers known occupied camps and scouts unseen camps when needed. Invoker prepares Ice Wall, aggros both camps and aims through their current spread. Optional Meteor Hammer predicts the largest group at impact. Failed pulls retry while held. Release or issue a manual order to cancel; an active channel is preserved.",
		["tip.tornado_stack"] = "Hold near a camp shortly before the minute. Chooses the closest eligible camp, including camps under fog. Times Tornado using known creep positions or the camp centre if no entities are available. Blind timing cannot verify every creep or hidden spawn blockers. Accounts for travel, lift duration and Invoke preparation. Release or issue a manual order to cancel.",
		["tip.bind_quick_cast"] = "After Invoke is confirmed, cast once at the cursor position captured on key press. Cold Snap targets the nearest valid enemy to that point; Alacrity targets Invoker. Otherwise only prepare the spell in the first slot.",
		["tip.bind_aim_wall"] = "Position and turn to place Ice Wall through the captured cursor position. With Ice Floe, aim the vector cast there instead.",
		["group.hero"] = "Combo",
		["group.movement"] = "Movement",
		["group.items"] = "Dynamic Items",
		["group.switcher"] = "Auto Orbs",
		["group.combo_panel"] = "Combo Builder",
		["group.spell_panel"] = "Spell Bar",
		["group.execution"] = "Execution",
		["group.sun_strike"] = "Sun Strike",
		["group.cataclysm"] = "Cataclysm & Refresher",
		["group.interrupts"] = "Interrupts",
		["group.extra"] = "Diagnostics",
		["gear.precast"] = "Preparation",
		["title.ready_spells"] = "Ready Spells",
		["title.landing_sun"] = "Sun Strike on Arrival",
		["title.bind_prepare"] = "Spell Preparation",
		["gear.items"] = "Allowed Items",
		["gear.linkens"] = "Linken Breakers",
		["gear.orbs"] = "Orb Conditions",
		["gear.sun"] = "Sun Strike Conditions",
		["ui.enabled"] = "Enabled",
		["ui.combo_key"] = "Target Combo",
		["ui.cursor_key"] = "Cursor Combo",
		["ui.auto_prepare"] = "Prepare Spells",
		["ui.precast_mode"] = "Prepare For",
		["ui.precast_hold"] = "Only While Holding Bind",
		["ui.precast_bind"] = "Preparation Bind",
		["tip.precast_hold"] = "Idle spell preparation runs only while the assigned bind is held. Active combos still invoke the spells they need.",
		["panel.strict_order"] = "Strict order",
		["panel.strict_hint"] = "No impact timing; unavailable actions are skipped.",
		["ui.continue_dynamic"] = "Continue with Dynamic Combo",
		["ui.cast_crafted_first"] = "Use Ready Spells First",
		["ui.prepared_outside_combo"] = "Use Spells Outside Combo",
		["tip.prepared_outside_combo"] = "Also use suitable spells already in D/F even if absent from the selected combo. Never invokes extra spells. Excludes Ghost Walk.",
		["ui.kiting"] = "Hit&Run",
		["tip.kiting"] = "While holding the target combo, move between attacks after the projectile launches. Spell casts take priority.",
		["ui.move_direction"] = "Combo Movement",
		["tip.move_direction"] = "Enemy approaches cast range and retreats between attacks with Hit and Run. Cursor moves toward your cursor instead of chasing the enemy.",
		["move.enemy"] = "Enemy",
		["move.cursor"] = "Cursor",
		["ui.preserve_control"] = "Preserve Existing Disables",
		["ui.use_cataclysm"] = "Cataclysm in Dynamic Combo",
		["ui.auto_cataclysm"] = "Auto Cataclysm",
		["ui.auto_refresher"] = "Refresher after Auto Cataclysm",
		["ui.fountain_sun"] = "Opening Sun Strike at enemy fountain",
		["tip.auto_refresher"] = "After a confirmed Auto Cataclysm, refresh and cast again if enough enemies remain controlled and mana covers both actions.",
		["tip.fountain_sun"] = "Once during pregame: learn level-one Exort with an available point, invoke Sun Strike, and cast at the enemy fountain position.",
		["ui.cataclysm_min_heroes"] = "Minimum Controlled Heroes",
		["ui.use_refresher"] = "Refresher in Dynamic Combo",
		["ui.items"] = "Items",
		["ui.items_picker"] = "Allowed Items",
		["ui.linken_priority"] = "Break Linken's Sphere",
		["ui.linken_picker"] = "Priority",
		["ui.auto_orbs"] = "Auto Orbs",
		["ui.orb_mode"] = "During Combos",
		["ui.allowed_orbs"] = "Allowed Orbs",
		["ui.quas_health"] = "Use Quas Below",
		["ui.wex_walk"] = "Walk Time for Wex",
		["ui.manual_order_pause"] = "Pause After Manual Order",
		["ui.auto_interrupt"] = "Auto Interrupt",
		["ui.interrupt_spells"] = "Abilities",
		["ui.interrupt_teleports"] = "Cancel Teleports",
		["ui.interrupt_fog_teleports"] = "Tornado Teleports in Fog",
		["ui.auto_sun_strike"] = "Auto Sun Strike",
		["ui.landing_sun"] = "Sun Strike on Arrival",
		["ui.landing_teleports"] = "Teleport Destinations",
		["ui.landing_cyclones"] = "Cyclone / Tornado Landings",
		["ui.landing_lethal"] = "Only Lethal Cyclone Landings",
		["tip.landing_sun"] = "Time Sun Strike for teleport arrival or Cyclone/Tornado landing. Uses actual modifier expiry when available. Under fog, owned TP particles supply the destination with estimated base timing; closely repeated nearby TPs are skipped without real timing. Hidden moving destinations need fresh motion data. Fixed cyclone positions must first be observed. Respects mana reserve and manual combos.",
		["tip.landing_lethal"] = "Require lethal split damage for cyclone landings too. Teleport arrivals always require lethal damage, using current or last reported health under fog.",
		["ui.sun_min_mana"] = "Minimum Mana %",
		["ui.sun_walk_time"] = "Walk Time",
		["ui.sun_idle_time"] = "Idle Time",
		["ui.use_controlled_targets"] = "Use on Disabled Targets",
		["ui.predict_running_targets"] = "Predict Running Targets",
		["ui.quick_sun_buttons"] = "Enemy Portrait Buttons",
		["ui.debug_logs"] = "Detailed Debug Logs",
		["ui.show_panel"] = "Combo Panel",
		["ui.panel_scale"] = "Panel Size",
		["ui.panel_orientation"] = "Orientation",
		["ui.compact_panel"] = "Compact Format",
		["ui.show_execution"] = "Execution Indicator",
		["ui.status_text"] = "Show Status Text",
		["ui.indicator_scale"] = "Status Size",
		["ui.show_spell_bar"] = "Spell Bar",
		["ui.spell_bar_scale"] = "Spell Bar Size",
		["ui.spell_bar_layout"] = "Layout",
		["orientation.horizontal"] = "Horizontal",
		["orientation.vertical"] = "Vertical",
		["spell_layout.horizontal"] = "Horizontal",
		["spell_layout.grid"] = "3 per row",
		["panel.title"] = "Invoker Combo Builder",
		["panel.slot"] = "Slot",
		["panel.dynamic_toggle"] = "Click icons to allow / block Dynamic",
		["panel.palette"] = "Abilities & items",
		["panel.dynamic_preview"] = "Dynamic preview",
		["panel.combo_slot"] = "Combo Slot",
		["panel.dynamic_empty"] = "Dynamic sequence is generated on cast",
		["panel.combo_empty"] = "Empty combo",
		["panel.dynamic_hint"] = "Generated from live hero and target state",
		["panel.combo_hint"] = "Click an icon above to add the first action",
		["precast.custom"] = "Custom",
		["precast.always"] = "Always",
		["orb_mode.outside"] = "Outside Combo",
		["orb_mode.always"] = "Always",
		["tip.enabled"] = "Master switch for every Invoker feature and overlay.",
		["tip.combo_key"] = "Hold to execute the selected combo and attack between casts.",
		["tip.cursor_key"] = "Hold to lock one ground point under the cursor; point and directional actions use it, while unit-target actions are skipped.",
		["tip.auto_prepare"] = "Keeps useful spells from the selected combo ready in the two Invoke slots during safe idle time.",
		["tip.precast_mode"] = "Custom prepares user-made slots 1-5 only; Always also prepares the Dynamic slot.",
		["tip.continue_dynamic"] = "After a non-Dynamic combo finishes, continue with useful Dynamic actions while the key is held.",
		["tip.cast_crafted_first"] = "Prefer usable spells already present in D/F before invoking follow-ups.",
		["tip.preserve_control"] = "Dynamic avoids Tornado and Eul's while the target is already immobilized, so allies can keep dealing damage.",
		["tip.use_cataclysm"] = "Let Dynamic use Cataclysm when it catches enough controlled heroes or its extra damage secures the target.",
		["tip.auto_cataclysm"] = "Automatically cast Cataclysm when enough enemy heroes will remain controlled until impact.",
		["tip.cataclysm_min_heroes"] = "Enemy heroes that must remain controlled through Cataclysm's full delay. Dynamic may also use it when the extra damage secures its target.",
		["tip.use_refresher"] = "Let Dynamic add Refresher only when the repeated spells are affordable and meaningfully improve the combo or secure a kill.",
		["tip.items"] = "Choose which owned items Dynamic may use. Meteor Hammer requires live lockdown and protects its channel from other orders.",
		["tip.linken_priority"] = "Drag to reorder; click an icon to enable or disable that Linken breaker.",
		["tip.auto_orbs"] = "Automatically maintain Quas, Wex, or Exort from health, movement, and attacks.",
		["tip.orb_mode"] = "Outside Combo avoids orb changes during execution; Always may switch between combo orders.",
		["tip.allowed_orbs"] = "Choose which learned orbs automatic selection may use.",
		["tip.quas_health"] = "Use three Quas orbs below this health percentage.",
		["tip.wex_walk"] = "Continuous measured movement required before using three Wex orbs.",
		["tip.manual_order_pause"] = "Stops Auto Orbs for this long after your own ability order. The default is 1.5 seconds.",
		["tip.auto_interrupt"] = "Interrupt nearby channels and teleports with the fastest allowed Invoker spell.",
		["tip.interrupt_spells"] = "Choose Cold Snap and/or Tornado for automatic interrupts.",
		["tip.interrupt_teleports"] = "Treat teleport channel modifiers as interrupt targets.",
		["tip.interrupt_fog_teleports"] = "Use an enemy teleport's departure particle to aim Tornado under fog. Requires a known source position and enough time to invoke, turn and hit before the channel ends. Destination particles alone are not used for interrupts.",
		["tip.auto_sun_strike"] = "Automatically use lethal Sun Strike on targets whose position can be predicted reliably.",
		["tip.sun_min_mana"] = "Mana percentage to keep after automatic Sun Strike or Cataclysm. Manual portrait shots ignore this reserve.",
		["tip.sun_walk_time"] = "How long a target must run in one predictable direction before an automatic shot.",
		["tip.sun_idle_time"] = "How long a target must stay idle before an automatic shot.",
		["tip.use_controlled_targets"] = "Allow lethal shots on targets disabled through impact and multi-target Cataclysm.",
		["tip.predict_running_targets"] = "Predict lethal Sun Strikes on targets that keep running in a stable direction.",
		["tip.quick_sun_buttons"] = "Show clickable Sun Strike buttons beneath enemy portraits; these shots bypass the lethality check.",
		["tip.debug_logs"] = "Write planning, prediction, Invoke, casting, and automatic-use diagnostics to the log.",
		["tip.show_panel"] = "Shows the draggable in-game combo builder while playing Invoker.",
		["tip.panel_scale"] = "Scales the in-game combo builder.",
		["tip.panel_orientation"] = "Changes how combo action icons are arranged in the compact panel.",
		["tip.compact_panel"] = "Leaves room for status text in the compact panel.",
		["tip.show_execution"] = "Highlights the active slot and current action while a combo is running.",
		["tip.status_text"] = "Shows the current execution reason inside the combo panel.",
		["tip.indicator_scale"] = "Scales the active execution indicator in the panel header.",
		["tip.show_spell_bar"] = "Shows every normal Invoker spell above the HUD; click a learned recipe to Invoke it.",
		["tip.spell_bar_scale"] = "Scales the bottom-center spell-crafting bar.",
		["tip.spell_bar_layout"] = "Uses one horizontal row or a compact three-column grid.",
	},
	ru = {
		["group.auto_steal"] = "Автокража",
		["ui.auto_tormentor"] = "Красть Tormentor",
		["tip.auto_tormentor"] = "Оценивает барьер по отражённому урону и регенерации, в том числе в тумане. Сверяется с реальным барьером, когда он доступен. Скрытые изменения сопротивлений и поглощение отражения могут вносить погрешность.",
		["gear.tormentor"] = "Настройки кражи Tormentor",
		["ui.auto_roshan"] = "Красть Рошана через Sun Strike",
		["tip.auto_roshan"] = "Пытается добить по текущему здоровью с учётом задержки Sun Strike. Не прерывает удерживаемое комбо. Использует общий порог маны.",
		["gear.roshan"] = "Настройки кражи Рошана",
		["ui.roshan_margin"] = "Запас урона",
		["tip.roshan_margin"] = "Резерв урона Sun Strike на погрешность здоровья и времени попадания.",
		["tab.main"] = "Комбо",
		["tab.panels"] = "Панели",
		["tab.auto"] = "Автокаст",
		["tab.extra"] = "Дополнительно",
		["tab.binds"] = "Бинды",
		["group.automation"] = "Автоматизация",
		["group.combo_selection"] = "Выбор комбо",
		["ui.select_dynamic"] = "Выбрать Dynamic",
		["ui.select_combo_1"] = "Выбрать комбо 1",
		["ui.select_combo_2"] = "Выбрать комбо 2",
		["ui.select_combo_3"] = "Выбрать комбо 3",
		["ui.select_combo_4"] = "Выбрать комбо 4",
		["ui.select_combo_5"] = "Выбрать комбо 5",
		["tip.select_combo"] = "Выбирает комбо без каста. Работает при скрытой панели. Если удерживать клавишу комбо, выполнение переключится на выбранное комбо.",
		["group.self_cast"] = "Применение на себя",
		["group.prepare_binds"] = "Предварительный каст",
		["ui.meteor_farm"] = "Ice Wall Farm",
		["gear.farm"] = "Ice Wall Farm",
		["ui.farm_hammer"] = "Использовать Meteor Hammer",
		["tip.farm_hammer"] = "После Ice Wall применяет готовый Meteor Hammer по наибольшей доступной группе крипов. Если предмета нет или он не готов, продолжает фарм с Ice Wall.",
		["ui.tornado_stack"] = "Tornado Stack",
		["ui.bind_quick_cast"] = "Быстрый каст после Invoke",
		["ui.bind_aim_wall"] = "Направлять Ice Wall к курсору",
		["tip.meteor_farm"] = "Удерживайте для фарма пары ближайших подходящих лагерей. Приоритет у известных занятых лагерей; неизвестные проверяются при подходе. Invoker подготовит Ice Wall, спровоцирует оба лагеря и направит стену по текущему расположению крипов. Опциональный Meteor Hammer учитывает движение до момента падения. Неудачный заход повторяется при удержании. Отпустите клавишу или отдайте ручной приказ для отмены. Начатый канал не прерывается.",
		["tip.tornado_stack"] = "Удерживайте рядом с лагерем перед началом минуты. Выбирается ближайший подходящий лагерь, включая туман войны. Расчёт использует известные позиции крипов или центр лагеря, если сущности недоступны. В тумане нельзя проверить всех крипов и скрытых блокировщиков. Учитываются полёт, подъём и подготовка Invoke. Отпустите клавишу или отдайте ручной приказ для отмены.",
		["tip.bind_quick_cast"] = "После подтверждения Invoke один раз применяет способность в точку курсора при нажатии. Cold Snap выбирает ближайшего допустимого врага к этой точке, Alacrity — Invoker. Если выключено, только подготавливает способность в первом слоте.",
		["tip.bind_aim_wall"] = "Выбирает позицию и направление Ice Wall через точку курсора при нажатии. Для Ice Floe направляет туда векторный каст.",
		["group.hero"] = "Прокаст",
		["group.movement"] = "Движение",
		["group.items"] = "Предметы в динамическом комбо",
		["group.switcher"] = "Автосферы",
		["group.combo_panel"] = "Редактор комбо",
		["group.spell_panel"] = "Панель перезарядок",
		["group.execution"] = "Индикатор комбо",
		["group.sun_strike"] = "Sun Strike",
		["group.cataclysm"] = "Cataclysm и Refresher",
		["group.interrupts"] = "Сбивание кастов",
		["group.extra"] = "Дополнительно",
		["gear.precast"] = "Какие комбо готовить",
		["title.ready_spells"] = "Готовые спеллы",
		["title.landing_sun"] = "Sun Strike по прибытии",
		["title.bind_prepare"] = "Подготовка спелла",
		["gear.items"] = "Разрешённые предметы",
		["gear.linkens"] = "Чем сбивать Linken's Sphere",
		["gear.orbs"] = "Условия переключения",
		["gear.sun"] = "Условия автокаста",
		["ui.enabled"] = "Включить",
		["ui.combo_key"] = "Комбо по цели",
		["ui.cursor_key"] = "Комбо по позиции",
		["ui.auto_prepare"] = "Заранее готовить спеллы",
		["ui.precast_mode"] = "Готовить для",
		["ui.precast_hold"] = "Только при удержании бинда",
		["ui.precast_bind"] = "Бинд подготовки",
		["tip.precast_hold"] = "Подготовка вне комбо работает только при удержании бинда. Активное комбо по-прежнему вызывает нужные заклинания.",
		["panel.strict_order"] = "Строгий порядок",
		["panel.strict_hint"] = "Без тайминга попаданий. Недоступные действия пропускаются.",
		["ui.continue_dynamic"] = "Переключить на динамическое",
		["ui.cast_crafted_first"] = "Сначала готовые спеллы",
		["ui.prepared_outside_combo"] = "Использовать спеллы вне комбо",
		["tip.prepared_outside_combo"] = "Использует подходящие готовые спеллы из D/F, даже если их нет в выбранном комбо. Не инвокает дополнительные спеллы. Кроме Ghost Walk.",
		["ui.kiting"] = "Hit&Run",
		["tip.kiting"] = "При удержании комбо по цели двигается между атаками после вылета снаряда. Спеллы имеют приоритет.",
		["ui.move_direction"] = "Движение в комбо",
		["tip.move_direction"] = "К врагу: подходит на дальность каста, с атакой и отходом отступает между атаками. К курсору: двигается к курсору вместо преследования врага.",
		["move.enemy"] = "К врагу",
		["move.cursor"] = "К курсору",
		["ui.preserve_control"] = "Сохранять текущий контроль",
		["ui.use_cataclysm"] = "Cataclysm в динамическом комбо",
		["ui.auto_cataclysm"] = "Авто Cataclysm",
		["ui.auto_refresher"] = "Refresher после авто Cataclysm",
		["ui.fountain_sun"] = "Стартовый Sun Strike на фонтан врага",
		["tip.auto_refresher"] = "После подтверждённого авто Cataclysm использует Refresher и повторяет каст, если хватает маны и враги остаются под контролем.",
		["tip.fountain_sun"] = "Один раз до начала матча: изучает первый Exort за свободное очко и кастует Sun Strike на позицию вражеского фонтана.",
		["ui.cataclysm_min_heroes"] = "Героев под контролем",
		["ui.use_refresher"] = "Refresher в динамическом комбо",
		["ui.items"] = "Предметы",
		["ui.items_picker"] = "Разрешённые предметы",
		["ui.linken_priority"] = "Сбивание Linken's Sphere",
		["ui.linken_picker"] = "Порядок предметов",
		["ui.auto_orbs"] = "Автосферы",
		["ui.orb_mode"] = "Во время комбо",
		["ui.allowed_orbs"] = "Разрешённые сферы",
		["ui.quas_health"] = "Включать Quas при здоровье ниже",
		["ui.wex_walk"] = "Время ходьбы для Wex",
		["ui.manual_order_pause"] = "Пауза после ручной команды",
		["ui.auto_interrupt"] = "Автоматически сбивать касты",
		["ui.interrupt_spells"] = "Способности",
		["ui.interrupt_teleports"] = "Сбивать телепорты",
		["ui.interrupt_fog_teleports"] = "Tornado по телепортам в тумане",
		["ui.auto_sun_strike"] = "Автокаст Sun Strike",
		["ui.landing_sun"] = "Sun Strike при приземлении",
		["ui.landing_teleports"] = "Точки телепортации",
		["ui.landing_cyclones"] = "Приземление после Cyclone / Tornado",
		["ui.landing_lethal"] = "Смертельный урон после циклона",
		["tip.landing_sun"] = "Sun Strike к завершению телепортации или Cyclone/Tornado. При наличии модификатора использует его точное время. В тумане позиция берётся из частиц TP, время оценивается по базовой длительности. Повторные TP рядом пропускаются без точного времени. Движущаяся точка требует свежих данных; позицию подъёма нужно сначала увидеть. Учитывает запас маны и ручные комбо.",
		["tip.landing_lethal"] = "Требовать смертельный урон и при приземлении после циклона. Для телепортов проверка обязательна: используется текущее или последнее известное здоровье в тумане.",
		["ui.sun_min_mana"] = "Минимум маны",
		["ui.sun_walk_time"] = "Время движения",
		["ui.sun_idle_time"] = "Время без движения",
		["ui.use_controlled_targets"] = "Цели под контролем",
		["ui.predict_running_targets"] = "Цели в движении",
		["ui.quick_sun_buttons"] = "Кнопки под портретами",
		["ui.debug_logs"] = "Подробные логи",
		["ui.show_panel"] = "Панель комбо",
		["ui.panel_scale"] = "Размер панели",
		["ui.panel_orientation"] = "Ориентация",
		["ui.compact_panel"] = "Компактная панель",
		["ui.show_execution"] = "Показывать текущий спелл",
		["ui.status_text"] = "Причина задержки",
		["ui.indicator_scale"] = "Размер индикатора",
		["ui.show_spell_bar"] = "Панель заклинаний",
		["ui.spell_bar_scale"] = "Размер панели заклинаний",
		["ui.spell_bar_layout"] = "Вид панели",
		["orientation.horizontal"] = "Горизонтально",
		["orientation.vertical"] = "Вертикально",
		["spell_layout.horizontal"] = "Горизонтально",
		["spell_layout.grid"] = "По 3 в ряд",
		["panel.title"] = "Редактор комбо Invoker",
		["panel.slot"] = "Слот",
		["panel.dynamic_toggle"] = "Нажмите на иконку, чтобы разрешить или запретить её в динамическом комбо",
		["panel.palette"] = "Способности и предметы",
		["panel.dynamic_preview"] = "Текущий план динамического комбо",
		["panel.combo_slot"] = "Слот комбо",
		["panel.dynamic_empty"] = "Динамическое комбо соберётся при нажатии клавиши",
		["panel.combo_empty"] = "Пустое комбо",
		["panel.dynamic_hint"] = "Учитываются спеллы, предметы, мана и состояние цели",
		["panel.combo_hint"] = "Нажмите на иконку выше, чтобы добавить действие",
		["precast.custom"] = "Только слоты 1–5",
		["precast.always"] = "Всегда",
		["orb_mode.outside"] = "Не менять",
		["orb_mode.always"] = "Можно менять",
		["tip.enabled"] = "Включает скрипт и все его панели.",
		["tip.combo_key"] = "Удерживайте клавишу: скрипт выполнит выбранное комбо и будет атаковать в паузах между спеллами.",
		["tip.cursor_key"] = "Точка под курсором фиксируется в начале комбо. Все спеллы по точке и направлению кастуются туда, а спеллы и предметы по выбранной цели пропускаются.",
		["tip.auto_prepare"] = "Заранее держит первые нужные спеллы в слотах D/F, пока вы не заняты.",
		["tip.precast_mode"] = "Можно готовить только ваши комбо 1–5 либо ещё и динамическое комбо D.",
		["tip.continue_dynamic"] = "Если ваше комбо закончилось, но клавиша всё ещё зажата, скрипт подберёт полезное продолжение.",
		["tip.cast_crafted_first"] = "Динамическое комбо сначала использует подходящие спеллы, которые уже находятся в D/F.",
		["tip.preserve_control"] = "Dynamic не использует Tornado и Eul's, пока цель обездвижена, чтобы союзники продолжали наносить урон.",
		["tip.use_cataclysm"] = "Динамическое комбо использует Cataclysm, если он накроет достаточно героев под контролем или его дополнительного урона хватит для убийства цели.",
		["tip.auto_cataclysm"] = "Самостоятельно кастует Cataclysm, когда выбранное число вражеских героев не сможет выйти из контроля до попадания.",
		["tip.cataclysm_min_heroes"] = "Сколько вражеских героев должно оставаться обездвиженными до попадания. Хекс сам по себе не удерживает цель на месте. В комбо Cataclysm также может сработать ради добивания цели.",
		["tip.use_refresher"] = "Dynamic добавит Refresher, только если хватит маны, повтор заметно усилит комбо или позволит добить цель.",
		["tip.items"] = "Отметьте предметы для Dynamic. Meteor Hammer требует контроля цели; во время его канала скрипт не отдаёт другие команды.",
		["tip.linken_priority"] = "Перетащите предметы в нужном порядке. Нажатие на иконку включает или выключает её.",
		["tip.auto_orbs"] = "Автоматически ставит три Quas при низком здоровье, три Wex во время ходьбы и три Exort во время атаки.",
		["tip.orb_mode"] = "Разрешает или запрещает автосферам менять орбы между действиями активного комбо.",
		["tip.allowed_orbs"] = "Выберите сферы, которые можно переключать автоматически.",
		["tip.quas_health"] = "Три Quas включатся, когда здоровье опустится ниже этого значения.",
		["tip.wex_walk"] = "Сколько нужно непрерывно идти, прежде чем включатся три Wex.",
		["tip.manual_order_pause"] = "После вашей команды автосферы не вмешиваются указанное время. По умолчанию — 1,5 секунды.",
		["tip.auto_interrupt"] = "Сбивает каналы и телепорты ближайшего врага самым быстрым доступным спеллом.",
		["tip.interrupt_spells"] = "Выберите Cold Snap и/или Tornado для автоматического сбивания.",
		["tip.interrupt_teleports"] = "Разрешает автоматически сбивать телепорты.",
		["tip.interrupt_fog_teleports"] = "Наводит Tornado по частице отправления вражеского телепорта в тумане. Нужны известная исходная позиция и время на Invoke, поворот и попадание до конца канала. Одна лишь частица назначения не используется для сбивания.",
		["tip.auto_sun_strike"] = "Автоматически кастует смертельный Sun Strike по цели, в которую можно надёжно попасть.",
		["tip.sun_min_mana"] = "Автокаст Sun Strike и Cataclysm не сработает, если маны останется меньше указанного процента.",
		["tip.sun_walk_time"] = "Сколько цель должна бежать без резких поворотов, чтобы скрипт начал предсказывать её позицию.",
		["tip.sun_idle_time"] = "Сколько цель должна простоять на месте перед автоматическим Sun Strike.",
		["tip.use_controlled_targets"] = "Разрешает Sun Strike по цели, которая останется под контролем до попадания.",
		["tip.predict_running_targets"] = "Разрешает Sun Strike по бегущей цели, если направление движения достаточно стабильное.",
		["tip.quick_sun_buttons"] = "Добавляет кнопку Sun Strike под каждым вражеским портретом. Ручная кнопка не проверяет, хватит ли урона для убийства.",
		["tip.debug_logs"] = "Пишет в лог решения планировщика, предикт, Invoke и подтверждение кастов.",
		["tip.show_panel"] = "Показывает перетаскиваемый редактор комбо во время игры за Invoker.",
		["tip.panel_scale"] = "Меняет размер редактора комбо.",
		["tip.panel_orientation"] = "Располагает иконки горизонтально или вертикально в свёрнутой панели.",
		["tip.compact_panel"] = "Оставляет в свёрнутой панели строку для текущего статуса.",
		["tip.show_execution"] = "Подсвечивает активный слот и действие, которое сейчас выполняется.",
		["tip.status_text"] = "Показывает, чего скрипт сейчас ждёт: Invoke, дистанцию, задержку или подтверждение каста.",
		["tip.indicator_scale"] = "Меняет размер индикатора активного комбо.",
		["tip.show_spell_bar"] = "Показывает панель всех спеллов Invoker. Нажмите на изученный спелл, чтобы вызвать его через Invoke.",
		["tip.spell_bar_scale"] = "Меняет размер панели спеллов.",
		["tip.spell_bar_layout"] = "Один длинный ряд или компактная сетка по три иконки.",
	},
}

local qLocalization = {}

local localizationState = {
	language = Menu.Find("SettingsHidden", "", "", "", "Main", "Language"),
	instances = {},
}

local localizationSetters = {
	ToolTip = "tooltip",
}

local localizationHelpers = {}

function localizationHelpers.resolve(root, path)
	if type(root) ~= "table" then return nil end
	if root[path] ~= nil then return root[path] end
	for key in path:gmatch("[^.]+") do
		if type(root) ~= "table" then return nil end
		root = root[key]
	end
	return root
end

function localizationHelpers.isObject(value)
	return type(value) == "table" or type(value) == "userdata"
end

function localizationHelpers.hasMethod(object, name)
	return localizationHelpers.isObject(object) and type(object[name]) == "function"
end

function localizationHelpers.isMenuObject(value)
	return localizationHelpers.hasMethod(value, "Name") and localizationHelpers.hasMethod(value, "Type")
end

function localizationHelpers.isList(value)
	if type(value) ~= "table" or #value == 0 then return false end
	for index = 1, #value do
		if type(value[index]) ~= "string" then return false end
	end
	return true
end

function localizationHelpers.isIndexedList(object)
	return localizationHelpers.hasMethod(object, "List")
		and not localizationHelpers.hasMethod(object, "ListEnabled")
end

---Creates a new localization instance.
---@param translationData table<string, table>
---@return table
function qLocalization.new(translationData)
	local languages = {}
	for index, name in ipairs(localizationState.language and localizationState.language:List() or {}) do
		local code = name:match("%a+")
		if code and translationData[code] then languages[index - 1] = code end
	end

	local instance = {
		translations = translationData,
		languages = languages,
		objects = {},
		proxies = {},
		targets = {},
	}
	local methods = {}

	function methods.getLanguage(languageIndex)
		if languageIndex == nil and localizationState.language then
			languageIndex = localizationState.language:Get()
		end
		return instance.languages[languageIndex] or "en"
	end

	function methods.localize(path, languageIndex)
		if type(path) ~= "string" then return path end
		local language = methods.getLanguage(languageIndex)
		return localizationHelpers.resolve(instance.translations[language], path)
			or localizationHelpers.resolve(instance.translations.en, path)
			or path
	end

	function methods.has(path)
		if type(path) ~= "string" then return false end
		return localizationHelpers.resolve(instance.translations.en, path) ~= nil
			or localizationHelpers.resolve(instance.translations[methods.getLanguage()], path) ~= nil
	end

	function methods.localizeItems(items, languageIndex)
		local result, didLocalize = {}, false
		for index = 1, #items do
			local value = items[index]
			if methods.has(value) then
				result[index] = methods.localize(value, languageIndex)
				didLocalize = true
			else
				result[index] = value
			end
		end
		return result, didLocalize
	end

	function methods.apply(object, kind, path, languageIndex)
		if kind == "label" then
			object:ForceLocalization(methods.localize(path, languageIndex))
		elseif kind == "tooltip" then
			object:ToolTip(methods.localize(path, languageIndex))
		elseif kind == "items" then
			local value = object:Get()
			object:Update((methods.localizeItems(path, languageIndex)))
			object:Set(value)
		end
	end

	function methods.track(object, kind, path, applyNow)
		local record = instance.objects[object]
		if record == nil then
			record = {}
			instance.objects[object] = record
		end
		record[kind] = path
		if applyNow then methods.apply(object, kind, path) end
	end

	function methods.register(object, path)
		if not methods.has(path) or not localizationHelpers.hasMethod(object, "ForceLocalization") then return end
		methods.track(object, "label", path, true)
	end

	function methods.update(languageIndex)
		for object, record in pairs(instance.objects) do
			for kind, path in pairs(record) do methods.apply(object, kind, path, languageIndex) end
		end
	end

	function methods.wrap(target, bindSelf)
		if not localizationHelpers.isObject(target) then return target end
		if instance.targets[target] then return target end
		if instance.proxies[target] then return instance.proxies[target] end
		local members = {}
		local proxy
		proxy = setmetatable({}, {
			__index = function(_, key)
				if members[key] then return members[key] end
				local member = target[key]
				if type(member) ~= "function" then return member end
				if key == "Get" or key == "IsDown" or key == "List" or key == "ListEnabled"
					or key == "Type" or key == "Name"
				then
					local read = function(...)
						if not bindSelf then return member(...) end
						if select(1, ...) == proxy then return member(target, select(2, ...)) end
						return member(target, ...)
					end
					members[key] = read
					return read
				end
				local call = function(...)
					local args = table.pack(...)
					if bindSelf and args[1] == proxy then
						table.remove(args, 1)
						args.n = args.n - 1
					end
					if key == "Switch" and args.n < 2 then
						args[2] = false
						args.n = 2
					end

					local namePath, itemPaths
					if localizationSetters[key] then
						if methods.has(args[1]) then
							methods.track(target, localizationSetters[key], args[1], false)
							args[1] = methods.localize(args[1])
						end
					else
						local nameIndex = bindSelf and 1 or args.n
						if methods.has(args[nameIndex]) then
							namePath = args[nameIndex]
							args[nameIndex] = methods.localize(namePath)
						end
						local itemsIndex
						if key == "Combo" then
							itemsIndex = 2
						elseif key == "Update" and localizationHelpers.isIndexedList(target) then
							itemsIndex = 1
						end
						if itemsIndex and localizationHelpers.isList(args[itemsIndex]) then
							local values, localizedItems = methods.localizeItems(args[itemsIndex])
							if localizedItems then
								itemPaths = args[itemsIndex]
								args[itemsIndex] = values
							end
						end
					end

					local results = bindSelf
						and table.pack(member(target, table.unpack(args, 1, args.n)))
						or table.pack(member(table.unpack(args, 1, args.n)))
					for index = 1, results.n do
						local result = results[index]
						if localizationHelpers.isMenuObject(result) then
							if namePath then methods.register(result, namePath) end
							if itemPaths then
								methods.track(result, "items", itemPaths, false)
								itemPaths = nil
							end
							results[index] = methods.wrap(result, true)
						end
					end
					if itemPaths then methods.track(target, "items", itemPaths, false) end
					return table.unpack(results, 1, results.n)
				end
				members[key] = call
				return call
			end,
			__newindex = function(_, key, value)
				members[key] = nil
				target[key] = value
			end,
		})
		instance.proxies[target] = proxy
		instance.targets[proxy] = target
		return proxy
	end

	localizationState.instances[methods] = true
	return {
		getLanguage = methods.getLanguage,
		get = methods.localize,
		localize = methods.localize,
		update = methods.update,
		register = methods.register,
		wrap = methods.wrap,
		wrapLibrary = function(library)
			return methods.wrap(library, false)
		end,
	}
end

if localizationState.language then
	localizationState.language:SetCallback(function(this)
		local languageIndex = this:Get()
		for methods in pairs(localizationState.instances) do methods.update(languageIndex) end
	end, true)
else
	Log.Write("[qLocalization] Language widget not found; using English fallback.")
end

local localization = qLocalization.new(translations)
local tr = localization.get

---Registers a menu control and its tooltip/options with qLocalization.
---@param object table
---@param labelPath string
---@param tooltip? string
---@param items? string[]
---@return table
local function localized(object, labelPath, tooltip, items)
	local wrapped = localization.wrap(object, true)
	localization.register(object, labelPath)
	if tooltip then wrapped:ToolTip(tooltip) end
	if items then wrapped:Update(items) end
	return wrapped
end

local orbNames = {
	quas = "invoker_quas",
	wex = "invoker_wex",
	exort = "invoker_exort",
}

local orbModifiers = {
	quas = "modifier_invoker_quas_instance",
	wex = "modifier_invoker_wex_instance",
	exort = "modifier_invoker_exort_instance",
}

local spellIds = {
	"cold_snap",
	"ghost_walk",
	"ice_wall",
	"tornado",
	"emp",
	"alacrity",
	"chaos_meteor",
	"sun_strike",
	"cataclysm",
	"forge_spirit",
	"deafening_blast",
}

local itemIds = {
	"item_meteor_hammer",
	"item_cyclone",
	"item_sheepstick",
	"item_orchid",
	"item_bloodthorn",
	"item_rod_of_atos",
	"item_gungir",
	"item_ethereal_blade",
	"item_nullifier",
	"item_dagon",
	"item_shivas_guard",
	"item_abyssal_blade",
	"item_heavens_halberd",
	"item_diffusal_blade",
	"item_disperser",
	"item_spirit_vessel",
	"item_urn_of_shadows",
	"item_harpoon",
	"item_force_staff",
	"item_hurricane_pike",
	"item_refresher",
}

local definitions = {
	item_meteor_hammer = {
		name = "Meteor Hammer", short = "Hammer", runtimeNames = {"item_meteor_hammer"},
		kind = "item", targeting = "point", damageType = "magical", fixedDelay = 2.5,
		setup = 4, control = 3, reliability = 0.9,
		tags = {area = true, delayed = true, damage = true, channel = true},
	},
	cold_snap = {
		name = "Cold Snap", short = "Snap", runtimeNames = {"invoker_cold_snap"},
		kind = "spell", recipe = {"quas", "quas", "quas"}, targeting = "enemy",
		damageType = "magical", projectileSpeed = 0, fixedDelay = 0,
		setup = 3.5, control = 5.5, reliability = 0.96,
		tags = {control = true, debuff = true, damage = true},
	},
	ghost_walk = {
		name = "Ghost Walk", short = "Ghost", runtimeNames = {"invoker_ghost_walk"},
		kind = "spell", recipe = {"quas", "quas", "wex"}, targeting = "none",
		damageType = "none", projectileSpeed = 0, fixedDelay = 0,
		setup = 1.5, control = 1, reliability = 1,
		tags = {escape = true, utility = true},
	},
	ice_wall = {
		name = "Ice Wall", short = "Wall", runtimeNames = {"invoker_ice_wall"},
		kind = "spell", recipe = {"quas", "quas", "exort"}, targeting = "directional",
		damageType = "magical", projectileSpeed = 0, fixedDelay = 0,
		setup = 5, control = 6, reliability = 0.62,
		tags = {area = true, control = true, damage = true},
	},
	tornado = {
		name = "Tornado", short = "Tornado", runtimeNames = {"invoker_tornado"},
		kind = "spell", recipe = {"quas", "wex", "wex"}, targeting = "point",
		damageType = "magical", projectileSpeed = 1000, fixedDelay = 0,
		setup = 10, control = 9, reliability = 0.76,
		tags = {projectile = true, setup = true, control = true, delayed = true},
	},
	emp = {
		name = "E.M.P.", short = "EMP", runtimeNames = {"invoker_emp"},
		kind = "spell", recipe = {"wex", "wex", "wex"}, targeting = "point",
		damageType = "magical", projectileSpeed = 0, fixedDelay = 2.9,
		setup = 4, control = 3, reliability = 0.72,
		tags = {area = true, delayed = true, damage = true},
	},
	alacrity = {
		name = "Alacrity", short = "Alacrity", runtimeNames = {"invoker_alacrity"},
		kind = "spell", recipe = {"wex", "wex", "exort"}, targeting = "self",
		damageType = "physical", projectileSpeed = 0, fixedDelay = 0,
		setup = 2, control = 0, reliability = 1,
		tags = {buff = true, sustained = true},
	},
	chaos_meteor = {
		name = "Chaos Meteor", short = "Meteor", runtimeNames = {"invoker_chaos_meteor"},
		kind = "spell", recipe = {"wex", "exort", "exort"}, targeting = "point",
		damageType = "magical", projectileSpeed = 0, fixedDelay = 1.3,
		setup = 6, control = 2, reliability = 0.75,
		tags = {area = true, delayed = true, damage = true},
	},
	sun_strike = {
		name = "Sun Strike", short = "Sun", runtimeNames = {"invoker_sun_strike"},
		kind = "spell", recipe = {"exort", "exort", "exort"}, targeting = "point",
		damageType = "pure", projectileSpeed = 0, fixedDelay = 1.7,
		setup = 3, control = 0, reliability = 0.62,
		tags = {global = true, delayed = true, damage = true},
	},
	cataclysm = {
		name = "Cataclysm", short = "Cata", runtimeNames = {"invoker_sun_strike"},
		kind = "spell", recipe = {"exort", "exort", "exort"}, targeting = "none",
		damageType = "pure", projectileSpeed = 0, fixedDelay = 1.7,
		setup = 5, control = 0, reliability = 0.48, requiresScepter = "exort",
		tags = {global = true, delayed = true, damage = true},
	},
	forge_spirit = {
		name = "Forge Spirit", short = "Forge", runtimeNames = {"invoker_forge_spirit"},
		kind = "spell", recipe = {"quas", "exort", "exort"}, targeting = "none",
		damageType = "physical", projectileSpeed = 0, fixedDelay = 0,
		setup = 4, control = 1, reliability = 0.88,
		tags = {summon = true, sustained = true},
	},
	deafening_blast = {
		name = "Deafening Blast", short = "Blast", runtimeNames = {"invoker_deafening_blast"},
		kind = "spell", recipe = {"quas", "wex", "exort"}, targeting = "point",
		damageType = "magical", projectileSpeed = 1100, fixedDelay = 0,
		setup = 7, control = 7, reliability = 0.83,
		tags = {projectile = true, control = true, damage = true},
	},
	item_cyclone = {
		name = "Eul's Scepter", short = "Euls", runtimeNames = {"item_cyclone"},
		kind = "item", targeting = "enemy", damageType = "none",
		setup = 8, control = 8, reliability = 0.97, tags = {setup = true, control = true},
	},
	item_sheepstick = {
		name = "Scythe of Vyse", short = "Hex", runtimeNames = {"item_sheepstick"},
		kind = "item", targeting = "enemy", damageType = "none",
		setup = 8, control = 10, reliability = 0.98, tags = {control = true},
	},
	item_orchid = {
		name = "Orchid", short = "Orchid", runtimeNames = {"item_orchid"},
		kind = "item", targeting = "enemy", damageType = "none",
		setup = 5, control = 5, reliability = 0.95, tags = {silence = true, debuff = true},
	},
	item_bloodthorn = {
		name = "Bloodthorn", short = "Blood", runtimeNames = {"item_bloodthorn"},
		kind = "item", targeting = "enemy", damageType = "none",
		setup = 7, control = 6, reliability = 0.95, tags = {silence = true, debuff = true},
	},
	item_rod_of_atos = {
		name = "Rod of Atos", short = "Atos", runtimeNames = {"item_rod_of_atos"},
		kind = "item", targeting = "enemy", damageType = "none", projectileSpeed = 1500,
		setup = 6, control = 7, reliability = 0.91, tags = {control = true},
	},
	item_gungir = {
		name = "Gleipnir", short = "Gleipnir", runtimeNames = {"item_gungir"},
		kind = "item", targeting = "point", damageType = "none",
		setup = 7, control = 7, reliability = 0.9, tags = {area = true, control = true},
	},
	item_ethereal_blade = {
		name = "Ethereal Blade", short = "Eblade", runtimeNames = {"item_ethereal_blade"},
		kind = "item", targeting = "enemy", damageType = "magical", projectileSpeed = 1200,
		setup = 6, control = 3, reliability = 0.94, tags = {damage = true, debuff = true},
	},
	item_nullifier = {
		name = "Nullifier", short = "Null", runtimeNames = {"item_nullifier"},
		kind = "item", targeting = "enemy", damageType = "none", projectileSpeed = 1100,
		setup = 5, control = 3, reliability = 0.92, tags = {debuff = true},
	},
	item_dagon = {
		name = "Dagon", short = "Dagon", runtimeNames = {"item_dagon_5", "item_dagon_4", "item_dagon_3", "item_dagon_2", "item_dagon"},
		kind = "item", targeting = "enemy", damageType = "magical",
		setup = 1, control = 0, reliability = 0.98, tags = {damage = true},
	},
	item_shivas_guard = {
		name = "Shiva's Guard", short = "Shiva", runtimeNames = {"item_shivas_guard"},
		kind = "item", targeting = "none", damageType = "magical",
		setup = 5, control = 3, reliability = 0.9, tags = {area = true, damage = true, control = true},
	},
	item_abyssal_blade = {
		name = "Abyssal Blade", short = "Abyssal", runtimeNames = {"item_abyssal_blade"},
		kind = "item", targeting = "enemy", damageType = "none",
		setup = 8, control = 10, reliability = 0.98, tags = {control = true},
	},
	item_heavens_halberd = {
		name = "Heaven's Halberd", short = "Halberd", runtimeNames = {"item_heavens_halberd"},
		kind = "item", targeting = "enemy", damageType = "none",
		setup = 4, control = 5, reliability = 0.97, tags = {control = true, debuff = true},
	},
	item_diffusal_blade = {
		name = "Diffusal Blade", short = "Diffusal", runtimeNames = {"item_diffusal_blade"},
		kind = "item", targeting = "enemy", damageType = "none",
		setup = 4, control = 3, reliability = 0.96, tags = {control = true, debuff = true},
	},
	item_disperser = {
		name = "Disperser", short = "Disperser", runtimeNames = {"item_disperser"},
		kind = "item", targeting = "enemy", damageType = "none",
		setup = 5, control = 3, reliability = 0.97, tags = {control = true, debuff = true},
	},
	item_spirit_vessel = {
		name = "Spirit Vessel", short = "Vessel", runtimeNames = {"item_spirit_vessel"},
		kind = "item", targeting = "enemy", damageType = "none",
		setup = 5, control = 1, reliability = 0.97, tags = {damage = true, debuff = true},
	},
	item_urn_of_shadows = {
		name = "Urn of Shadows", short = "Urn", runtimeNames = {"item_urn_of_shadows"},
		kind = "item", targeting = "enemy", damageType = "none",
		setup = 3, control = 0, reliability = 0.97, tags = {damage = true, debuff = true},
	},
	item_harpoon = {
		name = "Harpoon", short = "Harpoon", runtimeNames = {"item_harpoon"},
		kind = "item", targeting = "enemy", damageType = "none",
		setup = 6, control = 3, reliability = 0.94, tags = {control = true},
	},
	item_force_staff = {
		name = "Force Staff", short = "Force", runtimeNames = {"item_force_staff"},
		kind = "item", targeting = "enemy", damageType = "none",
		setup = 4, control = 1, reliability = 0.94, tags = {control = true},
	},
	item_hurricane_pike = {
		name = "Hurricane Pike", short = "Pike", runtimeNames = {"item_hurricane_pike"},
		kind = "item", targeting = "enemy", damageType = "none",
		setup = 5, control = 2, reliability = 0.95, tags = {control = true},
	},
	item_refresher = {
		name = "Refresher Orb", short = "Refresh", runtimeNames = {"item_refresher"},
		kind = "item", targeting = "none", damageType = "none",
		setup = 0, control = 0, reliability = 1, tags = {reset = true},
	},
}

for _, id in ipairs(spellIds) do
	definitions[id].id = id
	definitions[id].sharedCooldown = id == "cataclysm" and "sun_strike" or id
	definitions[id].projectileSpeed = definitions[id].projectileSpeed or 0
	definitions[id].fixedDelay = definitions[id].fixedDelay or 0
	definitions[id].resetsWithRefresher = true
	definitions[id].icon = id == "cataclysm"
		and "panorama/images/spellicons/invoker/magus_apex/invoker_sun_strike_png.vtex_c"
		or ("panorama/images/spellicons/invoker_%s_png.vtex_c"):format(id)
end

local allActionIds
local ui
local renderCtx
local state

local function clamp(value, minimum, maximum)
	return math.max(minimum, math.min(maximum, value))
end

local function copyPoint(value)
	return {x = value.x, y = value.y, z = value.z or 0}
end

local function add(a, b)
	return {x = a.x + b.x, y = a.y + b.y, z = (a.z or 0) + (b.z or 0)}
end

local function subtract(a, b)
	return {x = a.x - b.x, y = a.y - b.y, z = (a.z or 0) - (b.z or 0)}
end

local function scale(value, factor)
	return {x = value.x * factor, y = value.y * factor, z = (value.z or 0) * factor}
end

local function length2D(value)
	return math.sqrt(value.x * value.x + value.y * value.y)
end

local function distance2D(a, b)
	return length2D(subtract(a, b))
end

local function normalized2D(value)
	local length = length2D(value)
	if length <= 0.0001 then return {x = 0, y = 0, z = 0} end
	return {x = value.x / length, y = value.y / length, z = 0}
end

local function dot2D(a, b)
	return a.x * b.x + a.y * b.y
end

local function toVector(value)
	return Vector(value.x, value.y, value.z or 0)
end

local function arrayCopy(source)
	local result = {}
	for index, value in ipairs(source) do result[index] = value end
	return result
end

local function contains(source, value)
	for _, current in ipairs(source) do
		if current == value then return true end
	end
	return false
end

local function containsAction(source, id)
	for _, action in ipairs(source) do
		if action.actionId == id then return true end
	end
	return false
end

local function pushUnique(source, value)
	if not contains(source, value) then source[#source + 1] = value end
end

local function canonicalSpell(id)
	return id == "cataclysm" and "sun_strike" or id
end

local function isSpell(id)
	return definitions[id].kind == "spell"
end

local function isUnitTarget(id)
	local targeting = definitions[id].targeting
	return targeting == "enemy" or targeting == "ally"
end

local function canBreakSpellBlock(id)
	return id == "cold_snap" or definitions[id].targeting == "enemy"
end

local function upgradeChoice(id)
	if id == 1 then return "quas" end
	if id == 2 then return "wex" end
	if id == 3 then return "exort" end
	return nil
end

local function logDebug(scope, message)
	if not ui.debugLogs:Get() then return end
	Log.Write(("[Invoker][%s] %s"):format(scope, message))
end

local function logChanged(key, scope, message)
	if state.lastDebug[key] == message then return end
	state.lastDebug[key] = message
	logDebug(scope, message)
end

local function setStatus(phase, message)
	state.statusPhase = phase
	state.status = message
	logChanged("status", "STATUS", phase .. ": " .. message)
end

---Builds an immutable settings snapshot from the current menu values.
---@return table
local function readSettings()
	if state.settingsCache and state.settingsCache.slot == state.panel.selectedSlot then
		return state.settingsCache
	end
	local enabledSpells = {}
	for _, id in ipairs(spellIds) do
		if id ~= "ghost_walk" and state.dynamicSpells[id] then
			enabledSpells[#enabledSpells + 1] = id
		end
	end

	local enabledItems = {}
	for _, id in ipairs(itemIds) do
		if ui.items:Get(id) then enabledItems[#enabledItems + 1] = id end
	end
	local enabledLinkenBreakers = ui.linkenPriority:ListEnabled()

	local settings = {
		slot = state.panel.selectedSlot,
		autoPrepare = ui.autoPrepare:Get(),
		precastMode = ui.precastMode:Get() == 1 and "always" or "custom",
		precastHold = ui.precastHold:Get(),
		continueDynamic = ui.continueDynamic:Get(),
		kiting = ui.kiting:Get(),
		moveDirection = ui.moveDirection:Get() == 1 and "cursor" or "enemy",
		panel = {
			show = ui.showPanel:Get(),
			scale = ui.panelScale:Get() / 100,
			orientation = ui.panelOrientation:Get() == 1 and "vertical" or "horizontal",
			compact = ui.compactPanel:Get(),
			showExecution = ui.showExecution:Get(),
			statusText = ui.statusText:Get(),
			indicatorScale = ui.indicatorScale:Get() / 100,
		},
		spellBar = {
			show = ui.showSpellBar:Get(),
			scale = ui.spellBarScale:Get() / 100,
			layout = ui.spellBarLayout:Get() == 1 and "grid" or "horizontal",
		},
		dynamic = {
			enabled = true,
			enabledSpells = enabledSpells,
			castCraftedFirst = ui.castCraftedFirst:Get(),
			preparedOutsideCombo = ui.preparedOutsideCombo:Get(),
			preserveControl = ui.preserveControl:Get(),
			useItems = #enabledItems > 0,
			enabledItems = enabledItems,
			breakLinkens = #enabledLinkenBreakers > 0,
			linkenPriority = enabledLinkenBreakers,
			useCataclysm = ui.useCataclysm:Get(),
			cataclysmMinHeroes = ui.cataclysmMinHeroes:Get(),
			useRefresher = ui.useRefresher:Get(),
		},
		auto = {
			orbs = ui.autoOrbs:Get(),
			orbMode = ui.orbMode:Get() == 1 and "always" or "outside_combo",
			quas = ui.allowedOrbs:Get("quas"),
			wex = ui.allowedOrbs:Get("wex"),
			exort = ui.allowedOrbs:Get("exort"),
			quasHealth = ui.quasHealth:Get(),
			wexWalkTime = ui.wexWalkTime:Get() / 10,
			manualOrderPause = ui.manualOrderPause:Get() / 10,
			interrupt = ui.autoInterrupt:Get(),
			interruptTornado = ui.interruptSpells:Get("tornado"),
			interruptSnap = ui.interruptSpells:Get("cold_snap"),
			interruptTeleports = ui.interruptTeleports:Get(),
			interruptFogTeleports = ui.interruptFogTeleports:Get(),
			sunStrike = ui.autoSunStrike:Get(),
			landingSun = ui.landingSun:Get(),
			landingTeleports = ui.landingTeleports:Get(),
			landingCyclones = ui.landingCyclones:Get(),
			landingLethal = ui.landingLethal:Get(),
			sunMinMana = ui.sunMinMana:Get(),
			sunWalkTime = ui.sunWalkTime:Get() / 10,
			sunIdleTime = ui.sunIdleTime:Get() / 10,
			useControlledTargets = ui.useControlledTargets:Get(),
			predictRunningTargets = ui.predictRunningTargets:Get(),
			quickSunButtons = ui.quickSunButtons:Get(),
			cataclysm = ui.autoCataclysm:Get(),
			cataclysmRefresher = ui.autoRefresher:Get(),
			fountainSun = ui.fountainSun:Get(),
			roshan = ui.autoRoshan:Get(),
			roshanMargin = ui.roshanMargin:Get(),
			tormentor = ui.autoTormentor:Get(),
			tormentorMargin = ui.tormentorMargin:Get(),
			cataclysmMinHeroes = ui.cataclysmMinHeroes:Get(),
		},
	}
	state.settingsCache = settings
	return settings
end

local function resetRuntime()
	state.comboSelectionKeys = {}
	state.landings = nil
	state.teleportParticles = nil
	state.teleportHistory = nil
	state.nextLandingScanAt = 0
	state.bindKeys = {}
	state.bindBlocked = {}
	state.bindJob = nil
	state.bindPreparedSpell = nil
	state.nextCampScanAt = 0
	state.settingsCache = nil
	state.roshan = nil
	state.roshanSpawners = nil
	state.nextRoshanSpawnerScanAt = 0
	state.tormentors = nil
	state.hero = nil
	state.player = nil
	state.bindings = nil
	state.snapshot = nil
	state.motion = {}
	state.invokeSequence = nil
	state.orbSequence = nil
	state.lastCompletedInvoke = nil
	state.assumedInvoked = {}
	state.plan = nil
	state.pendingCast = nil
	state.status = ""
	state.statusPhase = "idle"
	state.lastHeldMode = nil
	state.lastHeldSlot = nil
	state.nextPlanAt = 0
	state.nextAttackAt = 0
	state.moveOrder = nil
	state.kiteAttack = nil
	state.nextKiteAttackAt = 0
	state.nextIdlePrepareAt = 0
	state.nextAutoActionAt = 0
	state.nextAutoOrbAt = 0
	state.lastPlanCheck = 0
	state.lastTargetPosition = {x = 0, y = 0, z = 0}
	state.lastTargetVelocity = {x = 0, y = 0, z = 0}
	state.lastTargetMoving = false
	state.nextInvokeAttempt = 0
	state.nextDynamicReplanAt = 0
	state.nextFaceAttempt = 0
	state.nextIceWallMoveAt = 0
	state.walkingSince = math.huge
	state.automaticActionsPausedUntil = 0
	state.autoOrbsPausedUntil = 0
	state.autoPending = nil
	state.manualCraft = nil
	state.issuingOrder = false
	state.orderGuardUntil = 0
	state.lastDebug = {}
	state.debugTimes = {}
	state.lastHeroPosition = nil
	state.lastHeroPositionAt = 0
	state.measuredHeroSpeed = 0
	state.dynamicPreview = {}
	state.dynamicContinue = false
	state.quickSunHitboxes = {}
	state.quickSunEntries = {}
	state.panel.dragging = false
	state.panel.dragFrom = nil
	state.panel.leftWasDown = false
	state.panel.header = nil
	state.panel.expand = nil
	state.panel.clear = nil
	state.panel.slotHitboxes = {}
	state.panel.paletteHitboxes = {}
	state.panel.comboHitboxes = {}
	state.spellBar.dragging = false
	state.spellBar.leftWasDown = false
	state.spellBar.panelRect = nil
	state.spellBar.gripRect = nil
	state.spellBar.hitboxes = {}
end

local specialKeys = {
	item_meteor_hammer = {"max_duration", "land_time", "impact_radius", "impact_damage_units", "burn_dps_units", "burn_duration", "stun_duration"},
	cold_snap = {"duration", "freeze_duration", "freeze_cooldown", "freeze_damage"},
	ghost_walk = {"duration"},
	ice_wall = {"duration", "slow", "slow_duration", "tick_interval", "damage_per_second", "wall_width", "wall_place_distance", "wall_total_length", "vector_cast_range", "glacier_formation_delay", "glacier_formation_speed", "root_delay", "root_duration", "root_damage"},
	tornado = {"travel_speed", "travel_distance", "area_of_effect", "lift_duration", "base_damage", "wex_damage"},
	emp = {"delay", "area_of_effect", "mana_burned", "damage_per_mana_pct"},
	alacrity = {"duration", "bonus_damage"},
	chaos_meteor = {"land_time", "area_of_effect", "travel_distance", "travel_speed", "damage_interval", "main_damage", "burn_duration", "burn_dps"},
	sun_strike = {"delay", "area_of_effect", "damage", "cataclysm_count", "cataclysm_cooldown"},
	cataclysm = {"delay", "area_of_effect", "damage", "cataclysm_count", "cataclysm_cooldown"},
	forge_spirit = {"spirit_damage", "spirit_duration"},
	deafening_blast = {"travel_speed", "travel_distance", "radius_end", "damage", "knockback_duration", "disarm_duration"},
	item_cyclone = {"cyclone_duration"},
	item_sheepstick = {"sheep_duration"},
	item_orchid = {"silence_duration", "duration"},
	item_bloodthorn = {"silence_duration", "duration"},
	item_rod_of_atos = {"duration"},
	item_gungir = {"duration", "radius"},
	item_ethereal_blade = {"duration", "blast_damage_base", "blast_stat_multiplier", "projectile_speed"},
	item_nullifier = {"mute_duration", "projectile_speed"},
	item_dagon = {"damage"},
	item_shivas_guard = {"blast_damage", "blast_speed", "blast_radius"},
	item_abyssal_blade = {"stun_duration"},
	item_heavens_halberd = {"disarm_melee", "disarm_range"},
	item_diffusal_blade = {"purge_slow_duration"},
	item_disperser = {"enemy_effect_duration"},
	item_spirit_vessel = {"duration", "soul_damage_amount"},
	item_urn_of_shadows = {"duration", "soul_damage_amount"},
	item_harpoon = {"slow_duration", "cast_range_enemy", "projectile_speed"},
	item_force_staff = {"push_length", "enemy_cast_range"},
	item_hurricane_pike = {"enemy_length", "range_duration", "cast_range_enemy"},
	item_refresher = {},
}

local function findRuntimeEntity(hero, definition)
	for _, name in ipairs(definition.runtimeNames) do
		local entity
		if definition.kind == "spell" then
			entity = NPC.GetAbility(hero, name)
		else
			entity = NPC.GetItem(hero, name, true)
		end
		if entity then return entity end
	end
	return nil
end

local specialOrbs = {
	cold_snap = {duration = "quas", freeze_cooldown = "quas", freeze_damage = "quas"},
	ice_wall = {duration = "quas", slow = "quas", damage_per_second = "exort"},
	tornado = {travel_distance = "wex", lift_duration = "quas", wex_damage = "wex"},
	emp = {mana_burned = "wex"},
	alacrity = {bonus_damage = "exort"},
	chaos_meteor = {travel_distance = "wex", main_damage = "exort", burn_dps = "exort"},
	sun_strike = {damage = "exort"},
	cataclysm = {damage = "exort"},
	forge_spirit = {spirit_damage = "exort", spirit_duration = "quas"},
	deafening_blast = {damage = "exort", knockback_duration = "quas", disarm_duration = "wex"},
}

local function readAction(id, ability, hero, levels)
	local definition = definitions[id]
	local action = {
		id = id,
		ability = ability,
		exists = ability ~= nil,
		learned = false,
		invoked = false,
		activated = false,
		canCast = false,
		piercesDebuffImmunity = false,
		inAbilityPhase = false,
		cooldown = 99,
		cooldownLength = 0,
		manaCost = 0,
		castPoint = definition.kind == "spell" and 0.05 or 0,
		castRange = 0,
		specials = {},
	}
	if not ability then return action end

	action.learned = definition.kind == "item" or Ability.GetLevel(ability) > 0
	action.activated = Ability.IsActivated(ability)
	action.canCast = Ability.IsCastable(ability, NPC.GetMana(hero))
	action.piercesDebuffImmunity = Ability.GetImmunityType(ability) == Enum.ImmunityTypes.SPELL_IMMUNITY_ENEMIES_YES
	action.inAbilityPhase = Ability.IsInAbilityPhase(ability)
	action.cooldown = Ability.GetCooldown(ability)
	action.cooldownLength = Ability.GetCooldownLength(ability)
	action.manaCost = Ability.GetManaCost(ability)
	action.castPoint = Ability.GetCastPoint(ability, true)
	action.castRange = Ability.GetCastRange(ability) + NPC.GetCastRangeBonus(hero)
	for _, key in ipairs(specialKeys[id]) do
		local orb = specialOrbs[id] and specialOrbs[id][key]
		-- Explicit special-value indexes are zero-based; learned orb levels are one-based.
		local levelIndex = orb and math.max(0, levels[orb] - 1) or -1
		action.specials[key] = Ability.GetLevelSpecialValueFor(ability, key, levelIndex)
	end
	local enemyRange = action.specials.cast_range_enemy or action.specials.enemy_cast_range
	if enemyRange and enemyRange > 0 then action.castRange = enemyRange + NPC.GetCastRangeBonus(hero) end
	return action
end

local function orbLevels(hero)
	local result = {quas = 0, wex = 0, exort = 0}
	for orb, name in pairs(orbNames) do
		local ability = NPC.GetAbility(hero, name)
		if ability then result[orb] = Ability.GetLevel(ability) end
	end
	return result
end

local function resolveBindings(hero, player)
	local abilities = {}
	for _, id in ipairs(allActionIds) do
		abilities[id] = findRuntimeEntity(hero, definitions[id])
	end
	abilities.cataclysm = abilities.sun_strike
	return {
		hero = hero,
		player = player,
		abilities = abilities,
		invoke = NPC.GetAbility(hero, "invoker_invoke"),
		orbs = {
			quas = NPC.GetAbility(hero, orbNames.quas),
			wex = NPC.GetAbility(hero, orbNames.wex),
			exort = NPC.GetAbility(hero, orbNames.exort),
		},
	}
end

local function resolveSlotNames(hero)
	local result = {}
	for _, index in ipairs({3, 4}) do
		local ability = NPC.GetAbilityByIndex(hero, index)
		if ability then
			local name = Ability.GetName(ability)
			for _, id in ipairs(spellIds) do
				if id ~= "cataclysm" and contains(definitions[id].runtimeNames, name) then
					pushUnique(result, id)
				end
			end
		end
	end
	return result
end

local function detectActiveOrbs(hero)
	local found = {}
	for _, modifier in ipairs(NPC.GetModifiers(hero)) do
		local name = Modifier.GetName(modifier)
		for orb, modifierName in pairs(orbModifiers) do
			if name == modifierName then
				found[#found + 1] = {orb = orb, createdAt = Modifier.GetCreationTime(modifier)}
			end
		end
	end
	table.sort(found, function(left, right) return left.createdAt < right.createdAt end)
	local result = {}
	local first = math.max(1, #found - 2)
	for index = first, #found do result[#result + 1] = found[index].orb end
	return result
end

local function rememberInvoked(id)
	id = canonicalSpell(id)
	local nextSlots = {id}
	for _, current in ipairs(state.assumedInvoked) do
		if current ~= id and #nextSlots < 2 then nextSlots[#nextSlots + 1] = current end
	end
	state.assumedInvoked = nextSlots
end

local function reconcileInvoked(observed, invokePublishing)
	local result = {}
	for _, id in ipairs(observed) do pushUnique(result, canonicalSpell(id)) end
	if invokePublishing and #result < 2 then
		for _, id in ipairs(state.assumedInvoked) do
			if #result < 2 then pushUnique(result, canonicalSpell(id)) end
		end
	end
	state.assumedInvoked = arrayCopy(result)
	return result
end

function helpers.resetMotionContinuity(track, now)
	track.velocity = {x = 0, y = 0, z = 0}
	track.confidence = 0.9
	track.walkingSince = math.huge
	track.stableSince = math.huge
	if track.idleSince == math.huge then track.idleSince = now end
	track.lastDirection = {x = 0, y = 0, z = 0}
	track.lastSpeed = 0
	track.lastDisplacementAt = -math.huge
end

function helpers.updateMotionContinuity(track, now, moving, direction, speed)
	if not moving or speed < 20 then
		helpers.resetMotionContinuity(track, now)
		return
	end
	track.idleSince = math.huge
	if track.walkingSince == math.huge then track.walkingSince = now end
	if track.stableSince == math.huge then track.stableSince = now end
	if speed <= 0 then return end
	local directionChanged = length2D(track.lastDirection) > 0 and dot2D(track.lastDirection, direction) < 0.94
	local speedRatio = track.lastSpeed > 20 and speed / track.lastSpeed or 1
	if directionChanged or speedRatio < 0.55 or speedRatio > 1.65 then track.stableSince = now end
	track.lastDirection = direction
	track.lastSpeed = speed
end

local function updateMotion(index, position, now, moveSpeed, nativeMoving)
	local track = state.motion[index]
	if not track then
		track = {
			samples = {},
			velocity = {x = 0, y = 0, z = 0},
			confidence = 0,
			directionChanges = 0,
			walkingSince = math.huge,
			stableSince = math.huge,
			idleSince = math.huge,
			lastDirection = {x = 0, y = 0, z = 0},
			lastSpeed = 0,
			lastDisplacementAt = -math.huge,
		}
		state.motion[index] = track
	end

	local last = track.samples[#track.samples]
	if last then
		local elapsed = now - last.at
		local discontinuity = elapsed < 0 or elapsed > 0.75
			or distance2D(last.position, position) > math.max(cfg.motionResetDistance, moveSpeed * math.max(0, elapsed) * 1.5)
		if discontinuity then
			track.samples = {{at = now, position = copyPoint(position)}}
			track.directionChanges = 0
			track.idleSince = math.huge
			helpers.resetMotionContinuity(track, now)
			track.confidence = 0
			return copyPoint(track.velocity)
		end
	end
	if last and distance2D(last.position, position) >= 3 then track.lastDisplacementAt = now end
	if not last or now - last.at >= 0.035 or distance2D(last.position, position) >= 8 then
		track.samples[#track.samples + 1] = {at = now, position = copyPoint(position)}
	end
	while #track.samples > 2 and (#track.samples > 18 or now - track.samples[1].at > 0.7) do
		table.remove(track.samples, 1)
	end

	if not nativeMoving and now - track.lastDisplacementAt > 0.16 then
		helpers.resetMotionContinuity(track, now)
		return copyPoint(track.velocity)
	end
	if #track.samples < 2 then
		track.velocity = {x = 0, y = 0, z = 0}
		track.confidence = nativeMoving and 0.15 or 0.9
		helpers.updateMotionContinuity(track, now, nativeMoving, {x = 0, y = 0, z = 0}, 0)
		return copyPoint(track.velocity)
	end

	local first = track.samples[1]
	local newest = track.samples[#track.samples]
	local elapsed = math.max(0.001, newest.at - first.at)
	local raw = scale(subtract(newest.position, first.position), 1 / elapsed)
	local rawSpeed = length2D(raw)
	if not nativeMoving and rawSpeed < 20 then
		helpers.resetMotionContinuity(track, now)
		return copyPoint(track.velocity)
	end

	local capped = raw
	if moveSpeed > 0 and rawSpeed > moveSpeed * 1.35 then
		capped = scale(normalized2D(raw), moveSpeed * 1.35)
	end
	local previousDirection = normalized2D(track.velocity)
	local nextDirection = normalized2D(capped)
	if length2D(previousDirection) > 0 and dot2D(previousDirection, nextDirection) < 0.72 then
		track.directionChanges = track.directionChanges + 1
	else
		track.directionChanges = math.max(0, track.directionChanges - 0.25)
	end
	track.velocity = add(scale(track.velocity, 0.3), scale(capped, 0.7))
	track.confidence = clamp(elapsed / 0.25 - track.directionChanges * 0.16, 0.12, 1)

	local previousSample = track.samples[#track.samples - 1]
	local segmentElapsed = math.max(0.001, newest.at - previousSample.at)
	local segment = scale(subtract(newest.position, previousSample.position), 1 / segmentElapsed)
	local segmentSpeed = length2D(segment)
	helpers.updateMotionContinuity(track, now, nativeMoving or segmentSpeed >= 20, normalized2D(segment), segmentSpeed)
	return copyPoint(track.velocity)
end

local function modifierRemaining(modifier, now)
	local dieTime = Modifier.GetDieTime(modifier)
	if dieTime > 0 then return math.max(0, dieTime - now) end
	local duration = Modifier.GetDuration(modifier)
	local createdAt = Modifier.GetCreationTime(modifier)
	return duration > 0 and math.max(0, duration - math.max(0, now - createdAt)) or 0
end

local immobileStates = {
	[Enum.ModifierState.MODIFIER_STATE_STUNNED] = true,
	[Enum.ModifierState.MODIFIER_STATE_ROOTED] = true,
	[Enum.ModifierState.MODIFIER_STATE_FROZEN] = true,
}

function helpers.immobileRemaining(unit)
	local remaining = 0
	for _, duration in pairs(NPC.GetStatesDuration(unit, immobileStates, true)) do
		remaining = math.max(remaining, duration)
	end
	return remaining
end

function helpers.chronosphereFields(units, now)
	local fields = {}
	for _, unit in ipairs(units) do
		if NPC.GetUnitName(unit) == "npc_dota_thinker" then
			local modifier = NPC.GetModifier(unit, "modifier_faceless_void_chronosphere")
			if modifier then
				local remaining = modifierRemaining(modifier, now)
				local ability, caster = Modifier.GetAbility(modifier), Modifier.GetCaster(modifier)
				if remaining > 0 and ability and caster then
					local radius = Ability.GetLevelSpecialValueFor(ability, "radius")
					local bonus = NPC.GetModifierProperty(caster, Enum.ModifierFunction.MODIFIER_PROPERTY_AOE_BONUS_CONSTANT)
						+ NPC.GetModifierProperty(caster, Enum.ModifierFunction.MODIFIER_PROPERTY_AOE_BONUS_CONSTANT_STACKING)
					local percent = NPC.GetModifierProperty(caster, Enum.ModifierFunction.MODIFIER_PROPERTY_AOE_BONUS_PERCENTAGE)
					fields[#fields + 1] = {caster = caster, ability = ability, position = copyPoint(Entity.GetAbsOrigin(unit)),
						radius = (radius + bonus) * (1 + percent / 100), endsAt = now + remaining}
				end
			end
		end
	end
	return fields
end

function helpers.chronosphereRemaining(freeze, position, fields, now)
	local caster, ability = Modifier.GetCaster(freeze), Modifier.GetAbility(freeze)
	local remaining = 0
	for _, field in ipairs(fields) do
		if caster == field.caster and ability == field.ability
			and distance2D(position, field.position) <= field.radius + 24
		then
			remaining = math.max(remaining, field.endsAt - now)
		end
	end
	return remaining
end

function helpers.heroBusy(hero)
	if NPC.IsChannellingAbility(hero) then return true end
	for index = 0, 16 do
		local item = NPC.GetItemByIndex(hero, index)
		if item and (Ability.IsChannelling(item) or Ability.IsInAbilityPhase(item)) then return true end
	end
	return false
end

local function readEnemy(enemy, now, chronoFields)
	local index = Entity.GetIndex(enemy)
	local position = copyPoint(Entity.GetAbsOrigin(enemy))
	local nativeMoving = NPC.IsRunning(enemy)
	local velocity = updateMotion(index, position, now, NPC.GetMoveSpeed(enemy), nativeMoving)
	local moving = nativeMoving or length2D(velocity) >= 20
	local modifiers = {}
	local disabledRemaining = helpers.immobileRemaining(enemy)
	local cycloneRemaining = 0
	local teleporting = false
	local teleportRemaining = 0
	for _, modifier in ipairs(NPC.GetModifiers(enemy)) do
		local name = Modifier.GetName(modifier)
		local remaining = modifierRemaining(modifier, now)
		modifiers[name] = remaining
		if name == "modifier_faceless_void_chronosphere_freeze" then
			disabledRemaining = math.max(disabledRemaining, helpers.chronosphereRemaining(modifier, position, chronoFields, now))
		end
		if name == "modifier_invoker_tornado" or name == "modifier_eul_cyclone" then
			cycloneRemaining = math.max(cycloneRemaining, remaining)
		end
		if name == "modifier_teleporting" then
			teleporting = true
			teleportRemaining = math.max(teleportRemaining, remaining)
		end
	end
	local track = state.motion[index]
	return {
		entity = enemy,
		index = index,
		alive = Entity.IsAlive(enemy),
		visible = NPC.IsVisible(enemy),
		dormant = Entity.IsDormant(enemy),
		position = position,
		velocity = velocity,
		facing = copyPoint(Entity.GetRotation(enemy):GetForward()),
		moveSpeed = NPC.GetMoveSpeed(enemy),
		moving = moving,
		motionConfidence = track and track.confidence or 0,
		movementDuration = track and track.walkingSince ~= math.huge and math.max(0, now - track.walkingSince) or 0,
		stableDuration = track and track.stableSince ~= math.huge and math.max(0, now - track.stableSince) or 0,
		idleDuration = track and track.idleSince ~= math.huge and math.max(0, now - track.idleSince) or 0,
		health = Entity.GetHealth(enemy),
		healthRegen = NPC.GetHealthRegen(enemy),
		maxHealth = Entity.GetMaxHealth(enemy),
		mana = NPC.GetMana(enemy),
		maxMana = NPC.GetMaxMana(enemy),
		magicMultiplier = clamp(NPC.GetMagicalArmorDamageMultiplier(enemy), 0, 2),
		stunned = NPC.IsStunned(enemy),
		rooted = NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_ROOTED),
		silenced = NPC.IsSilenced(enemy),
		attacking = NPC.IsAttacking(enemy),
		disarmed = NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_DISARMED),
		hexed = NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_HEXED),
		invulnerable = NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE),
		magicImmune = NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_MAGIC_IMMUNE),
		debuffImmune = NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_DEBUFF_IMMUNE),
		spellBlocked = NPC.IsLinkensProtected(enemy),
		outOfGame = NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_OUT_OF_GAME),
		channeling = NPC.IsChannellingAbility(enemy),
		teleporting = teleporting,
		teleportRemaining = teleportRemaining,
		modifiers = modifiers,
		disabledUntil = now + disabledRemaining,
		controlEndsAt = cycloneRemaining > 0 and now + cycloneRemaining or 0,
		controlPosition = cycloneRemaining > 0 and copyPoint(position) or nil,
	}
end

---Selects a live enemy around the cursor, preserving an active plan's target lock.
---@param enemies EnemyState[]
---@param cursor table
---@param lockedIndex? integer
---@param searchRadius? number
---@param prioritizeControl? boolean
---@return EnemyState?
local function selectTarget(enemies, cursor, lockedIndex, searchRadius, prioritizeControl)
	if lockedIndex then
		for _, enemy in ipairs(enemies) do
			if enemy.index == lockedIndex and enemy.alive and enemy.visible and not enemy.dormant then return enemy end
		end
		return nil
	end

	local candidates = {}
	local radius = searchRadius or cfg.targetRadius
	for _, enemy in ipairs(enemies) do
		local position = enemy.controlPosition or enemy.position
		if enemy.alive and enemy.visible and not enemy.dormant and distance2D(cursor, position) <= radius then
			candidates[#candidates + 1] = enemy
		end
	end
	table.sort(candidates, function(left, right)
		if prioritizeControl then
			local leftControlled = left.controlEndsAt > state.now + 0.05
			local rightControlled = right.controlEndsAt > state.now + 0.05
			if leftControlled ~= rightControlled then return leftControlled end
		end
		return distance2D(cursor, left.controlPosition or left.position)
			< distance2D(cursor, right.controlPosition or right.position)
	end)
	return candidates[1]
end

function helpers.sampleObjectiveHealth(track, health, now)
	local previous = track.samples[#track.samples]
	if previous and (now < previous.at or now - previous.at > 1 or health <= 0
		or health - previous.health > 500)
	then
		track.samples = {}
		track.lastDamageAt = -math.huge
		previous = nil
	end
	if previous and health < previous.health - 0.5 then track.lastDamageAt = now end
	if not previous or now > previous.at then
		track.samples[#track.samples + 1] = {at = now, health = health}
	end
	while #track.samples > 2 and (#track.samples > 32 or now - track.samples[1].at > cfg.objectiveHistorySeconds) do
		table.remove(track.samples, 1)
	end
	local first = track.samples[1]
	local elapsed = now - first.at
	return elapsed >= 0.2 and math.max(0, (first.health - health) / elapsed) or 0
end

function helpers.roshanPitPosition(now)
	if not state.roshanSpawners or now >= state.nextRoshanSpawnerScanAt then
		state.roshanSpawners = {}
		state.nextRoshanSpawnerScanAt = now + cfg.roshanSpawnerScanSeconds
		for _, entity in ipairs(Entities.GetAll()) do
			if Entity.GetClassName(entity) == "C_DOTA_RoshanSpawner" then
				state.roshanSpawners[#state.roshanSpawners + 1] = copyPoint(Entity.GetAbsOrigin(entity))
			end
		end
	end
	if #state.roshanSpawners == 1 then return state.roshanSpawners[1] end
	return nil
end

function helpers.readRoshan(now)
	if not Roshan:is_alive() then state.roshan = nil; return nil end
	local unit = Roshan:get_entity()
	local index = unit and Entity.GetIndex(unit) or 0
	local track = state.roshan
	if not track then
		track = {lastAlliedDamageAt = -math.huge, healthRegen = 0, damageMultiplier = 1, samples = {}}
		state.roshan = track
	end
	track.index = index
	local visible = Roshan:is_visible()
	if unit and visible then
		track.healthRegen = math.max(0, NPC.GetHealthRegen(unit))
		track.damageMultiplier = clamp(1 + NPC.GetModifierProperty(unit,
			Enum.ModifierFunction.MODIFIER_PROPERTY_INCOMING_DAMAGE_PERCENTAGE) / 100, 0, 1)
	end
	local position = Roshan:get_position()
	local pitAim = false
	if not position or length2D(position) < 1 then
		position = helpers.roshanPitPosition(now)
		pitAim = position ~= nil
	end
	local health = Roshan:get_hp()
	-- Sample the global HP feed: its slope already includes regeneration, even under fog.
	local netDps = helpers.sampleObjectiveHealth(track, health, now)
	return {index = index, entity = unit, health = health, visible = visible,
		position = position and copyPoint(position), pitAim = pitAim,
		underAttack = Roshan:is_under_attack(), moving = Roshan:is_moving(),
		nextMoveIn = Roshan:get_time_till_next_move(), damagePerSecond = netDps, damageIsNet = true,
		healthRegen = track.healthRegen, damageMultiplier = track.damageMultiplier,
		lastAlliedDamageAt = track.lastAlliedDamageAt}
end

function helpers.tormentorValues(stats, time)
	local minutes = math.max(0, time) / 60
	return stats.capacity + stats.capacityGrowth * minutes, stats.regen + stats.regenGrowth * minutes,
		(stats.reflect + stats.reflectGrowth * (minutes + 1)) / 100
end

function helpers.advanceTormentorShield(track, time)
	local capacity, regen = helpers.tormentorValues(track.stats, time)
	local elapsed = math.max(0, time - track.updatedAt)
	if time < track.updatedAt then track.shield = capacity end
	local healing = regen * elapsed - track.stats.regenGrowth * elapsed * elapsed / 120
	track.shield = clamp(track.shield + math.max(0, healing), 0, capacity)
	track.updatedAt = time
	return capacity, regen
end

function helpers.tormentorReflectedLoss(reflections, damageType, fraction, armor, magic)
	local physical = damageType == Enum.DamageTypes.DAMAGE_TYPE_PHYSICAL
	local magical = damageType == Enum.DamageTypes.DAMAGE_TYPE_MAGICAL
	if fraction <= 0 or not physical and not magical and damageType ~= Enum.DamageTypes.DAMAGE_TYPE_PURE then return 0 end
	local reflected = 0
	for _, hit in ipairs(reflections) do
		local multiplier = (physical and hit.armor or magical and hit.magic or 1) * hit.incoming
		if multiplier > 0 then
			reflected = reflected + math.max(0, hit.damage - 1) / multiplier
		end
	end
	return reflected / fraction * (physical and armor or magical and magic or 1)
end

function helpers.readTormentor(unit, now)
	local index = Entity.GetIndex(unit)
	local time = GameRules.GetDOTATime()
	local track = state.tormentors[index]
	if not track then
		local shield = NPC.GetAbility(unit, "miniboss_unyielding_shield")
		local reflect = NPC.GetAbility(unit, "miniboss_reflect")
		if not shield or not reflect then return nil end
		track = {index = index, entity = unit, updatedAt = time, samples = {}, reflections = {},
			lastDamageAt = -math.huge, lastAlliedDamageAt = -math.huge, lastReflectionAt = -math.huge,
			lastPairedAt = -math.huge, lastMeasuredAt = -math.huge,
			stats = {
				capacity = Ability.GetLevelSpecialValueFor(shield, "damage_absorb"),
				capacityGrowth = Ability.GetLevelSpecialValueFor(shield, "absorb_bonus_per_interval"),
				regen = Ability.GetLevelSpecialValueFor(shield, "regen_per_second"),
				regenGrowth = Ability.GetLevelSpecialValueFor(shield, "regen_bonus_per_interval"),
				reflect = Ability.GetLevelSpecialValueFor(reflect, "passive_reflection_pct"),
				reflectGrowth = Ability.GetLevelSpecialValueFor(reflect, "passive_reflection_bonus_per_interval"),
			}}
		track.shield = helpers.tormentorValues(track.stats, time)
		state.tormentors[index] = track
	end
	local capacity, regen = helpers.advanceTormentorShield(track, time)
	local visible = not Entity.IsDormant(unit) and NPC.IsVisible(unit)
	local barriers = visible and NPC.GetBarriers(unit) or nil
	if barriers and barriers.all.total <= 0 then barriers = nil end
	local measured = barriers ~= nil
	if track.measured ~= measured then
		track.samples, track.lastDamageAt = {}, -math.huge
		track.measured = measured
	end
	if barriers then
		capacity = barriers.all.total
		track.shield = clamp(barriers.all.current, 0, capacity)
		track.lastMeasuredAt = now
	end
	track.position = copyPoint(Entity.GetAbsOrigin(unit))
	track.armor = NPC.GetArmorDamageMultiplier(unit)
	track.magic = NPC.GetMagicalArmorDamageMultiplier(unit)
	local health = track.shield + 1
	local dps = helpers.sampleObjectiveHealth(track, health, now)
	local dataStatus = helpers.tormentorDataStatus(measured, now, track.lastPairedAt, track.lastMeasuredAt)
	return {index = index, entity = unit, health = health, capacity = capacity, position = track.position,
		visible = visible, estimated = not barriers,
		dataStatus = dataStatus,
		underAttack = now - track.lastDamageAt <= cfg.objectiveRecentDamageSeconds,
		damagePerSecond = dps, damageIsNet = true, healthRegen = regen, damageMultiplier = 1,
		lastDamageAt = track.lastDamageAt, lastAlliedDamageAt = track.lastAlliedDamageAt}
end

function helpers.tormentorDataStatus(measured, now, pairedAt, measuredAt)
	if measured then return "live" end
	if now - pairedAt <= 2.5 then return "estimated" end
	if pairedAt > -math.huge or measuredAt > -math.huge then return "stale" end
	return "unknown"
end

function helpers.onTormentorDamage(data)
	if not state.tormentors or not data.source or not data.target then return end
	local source = state.tormentors[Entity.GetIndex(data.source)]
	local target = state.tormentors[Entity.GetIndex(data.target)]
	if not source and not target then return end
	local now = GameRules.GetGameTime()
	if source then
		if not data.ability or Ability.GetName(data.ability) ~= "miniboss_reflect" then return end
		if now - source.lastReflectionAt > 0.1 then source.reflections = {} end
		source.lastReflectionAt = now
		if data.damage <= 0 or not Entity.IsNPC(data.target) or NPC.IsIllusion(data.target) then return end
		if #source.reflections >= 32 then return end
		source.reflections[#source.reflections + 1] = {damage = data.damage,
			armor = NPC.GetArmorDamageMultiplier(data.target), magic = NPC.GetMagicalArmorDamageMultiplier(data.target),
			incoming = math.max(0, 1 + NPC.GetModifierProperty(data.target,
				Enum.ModifierFunction.MODIFIER_PROPERTY_INCOMING_DAMAGE_PERCENTAGE) / 100)}
		return
	end
	local reflections = target.reflections
	target.reflections = {}
	if now - target.lastReflectionAt > 0.1 or #reflections == 0 then return end
	local time = GameRules.GetDOTATime()
	local _, _, fraction = helpers.tormentorValues(target.stats, time)
	local damageType = data.ability and Ability.GetDamageType(data.ability) or Enum.DamageTypes.DAMAGE_TYPE_PHYSICAL
	local loss = helpers.tormentorReflectedLoss(reflections, damageType, fraction, target.armor, target.magic)
	helpers.advanceTormentorShield(target, time)
	target.shield = math.max(0, target.shield - loss)
	if loss > 0 then
		target.lastPairedAt = now
		target.lastDamageAt = now
		if state.hero and Entity.IsSameTeam(state.hero, data.source) then target.lastAlliedDamageAt = now end
	end
end

---Captures all hero, target, ability, and timing data used for one update.
---@param mode "normal"|"cursor"
---@param lockedIndex? integer
---@return InvokerSnapshot?
local function buildSnapshot(mode, lockedIndex)
	local hero = Heroes.GetLocal()
	if not hero or NPC.GetUnitName(hero) ~= cfg.heroName then return nil end
	local player = Players.GetLocal()
	if not player then return nil end

	local now = GameRules.GetGameTime()
	state.now = now
	local bindings = resolveBindings(hero, player)
	state.hero = hero
	state.player = player
	state.bindings = bindings

	local position = copyPoint(Entity.GetAbsOrigin(hero))
	local elapsed = now - state.lastHeroPositionAt
	if state.lastHeroPosition and elapsed >= 0.03 then
		local rawSpeed = distance2D(position, state.lastHeroPosition) / math.max(0.001, elapsed)
		state.measuredHeroSpeed = rawSpeed >= 20 and math.min(rawSpeed, NPC.GetMoveSpeed(hero) * 1.5) or 0
		state.lastHeroPosition = copyPoint(position)
		state.lastHeroPositionAt = now
	elseif not state.lastHeroPosition then
		state.lastHeroPosition = copyPoint(position)
		state.lastHeroPositionAt = now
	end

	local levels = orbLevels(hero)
	local heroState = {
		entity = hero,
		index = Entity.GetIndex(hero),
		alive = Entity.IsAlive(hero),
		level = NPC.GetCurrentLevel(hero),
		abilityPoints = Hero.GetAbilityPoints(hero),
		totalAttributes = Hero.GetStrengthTotal(hero) + Hero.GetAgilityTotal(hero) + Hero.GetIntellectTotal(hero),
		health = Entity.GetHealth(hero),
		maxHealth = Entity.GetMaxHealth(hero),
		mana = NPC.GetMana(hero),
		maxMana = NPC.GetMaxMana(hero),
		position = position,
		facing = copyPoint(Entity.GetRotation(hero):GetForward()),
		moveSpeed = NPC.GetMoveSpeed(hero),
		moving = NPC.IsRunning(hero) or state.measuredHeroSpeed >= 20,
		movementSpeed = state.measuredHeroSpeed,
		attacking = NPC.IsAttacking(hero),
		silenced = NPC.IsSilenced(hero),
		stunned = NPC.IsStunned(hero),
		channeling = helpers.heroBusy(hero),
		inAbilityPhase = false,
		attackRange = NPC.GetAttackRange(hero) + NPC.GetAttackRangeBonus(hero),
		alacrityActive = NPC.HasModifier(hero, "modifier_invoker_alacrity"),
		invisible = NPC.HasState(hero, Enum.ModifierState.MODIFIER_STATE_INVISIBLE),
		ghostWalk = NPC.HasModifier(hero, "modifier_invoker_ghost_walk_self"),
		orbLevels = levels,
		upgrades = {
			hasScepter = NPC.HasScepter(hero),
			hasShard = NPC.HasShard(hero),
			scepterChoice = NPC.HasScepter(hero) and upgradeChoice(NPC.GetScepterUpgradeID(hero)) or nil,
			shardChoice = NPC.HasShard(hero) and upgradeChoice(NPC.GetShardUpgradeID(hero)) or nil,
		},
	}

	local actions = {}
	for _, id in ipairs(allActionIds) do
		actions[id] = readAction(id, bindings.abilities[id], hero, levels)
		heroState.inAbilityPhase = heroState.inAbilityPhase or actions[id].inAbilityPhase
	end
	local observedInvoked = resolveSlotNames(hero)
	local invokeSeconds = bindings.invoke and Ability.SecondsSinceLastUse(bindings.invoke) or -1
	local invokePublishing = invokeSeconds >= 0 and invokeSeconds < 0.4
		or state.invokeSequence and state.invokeSequence.confirmDeadline > 0 and now <= state.invokeSequence.confirmDeadline
		or state.lastCompletedInvoke and now - state.lastCompletedInvoke.at <= 0.75
	local invoked = reconcileInvoked(observedInvoked, invokePublishing)
	for _, id in ipairs(spellIds) do actions[id].invoked = contains(invoked, canonicalSpell(id)) end

	local invokeCooldown = bindings.invoke and Ability.GetCooldown(bindings.invoke) or 99
	local invokeState = {
		exists = bindings.invoke ~= nil,
		ready = bindings.invoke ~= nil and Ability.IsCastable(bindings.invoke, heroState.mana) and invokeCooldown <= 0.05,
		cooldown = invokeCooldown,
		cooldownLength = bindings.invoke and Ability.GetCooldownLength(bindings.invoke) or 7,
		invoked = invoked,
		activeOrbs = detectActiveOrbs(hero),
	}

	local units = NPCs.GetAll()
	local chronoFields = helpers.chronosphereFields(units, now)
	local enemies = {}
	for _, enemy in ipairs(Heroes.GetAll()) do
		if not Entity.IsSameTeam(hero, enemy) and Entity.IsAlive(enemy) and not NPC.IsIllusion(enemy)
			and not Entity.IsDormant(enemy) and NPC.IsVisible(enemy)
		then
			enemies[#enemies + 1] = readEnemy(enemy, now, chronoFields)
		else
			state.motion[Entity.GetIndex(enemy)] = nil
		end
	end
	local cursor = copyPoint(Input.GetWorldCursorPos())
	local target = selectTarget(
		enemies,
		cursor,
		lockedIndex,
		mode == "cursor" and cfg.groundTargetRadius or cfg.targetRadius,
		mode ~= "cursor"
	)

	local sunUnits = {}
	local forgeSpirits = {}
	local roshan
	local objectiveSettings = readSettings().auto
	local roshanEnabled = objectiveSettings.roshan
	if not roshanEnabled then state.roshan = nil end
	local tormentors
	if objectiveSettings.tormentor then
		state.tormentors = state.tormentors or {}
		tormentors = {}
	else
		state.tormentors = nil
	end
	local playerId = Player.GetPlayerID(player)
	for _, unit in ipairs(units) do
		local alive = Entity.IsAlive(unit)
		local name = alive and NPC.GetUnitName(unit) or nil
		if tormentors and name == "npc_dota_miniboss" then
			local tormentor = helpers.readTormentor(unit, now)
			if tormentor then tormentors[#tormentors + 1] = tormentor end
		end
		if alive and name == "npc_dota_invoker_forged_spirit"
			and NPC.IsControllableByPlayer(unit, playerId)
		then
			forgeSpirits[#forgeSpirits + 1] = unit
		end
		if alive
			and not Entity.IsSameTeam(hero, unit)
			and not Entity.IsDormant(unit)
			and NPC.IsVisible(unit)
			and not NPC.IsStructure(unit)
			and not NPC.IsCourier(unit)
			and not NPC.IsWard(unit)
			and not NPC.HasState(unit, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE)
		then
			local moving = NPC.IsRunning(unit) and not NPC.IsStunned(unit)
				and not NPC.HasState(unit, Enum.ModifierState.MODIFIER_STATE_ROOTED)
			sunUnits[#sunUnits + 1] = {
				index = Entity.GetIndex(unit),
				position = copyPoint(Entity.GetAbsOrigin(unit)),
				velocity = moving and scale(Entity.GetRotation(unit):GetForward(), NPC.GetMoveSpeed(unit)) or {x = 0, y = 0, z = 0},
			}
		end
	end

	if roshanEnabled then roshan = helpers.readRoshan(now) end
	local currentLatency = NetChannel.GetLatency(Enum.Flow.FLOW_OUTGOING)
	local averageLatency = NetChannel.GetAvgLatency(Enum.Flow.FLOW_OUTGOING)
	local latency = clamp(math.max(currentLatency, averageLatency), 0, 0.35)
	return {
		now = now,
		paused = GameRules.IsPaused(),
		activeGame = Engine.IsInGame(),
		gameState = GameRules.GetGameState(),
		latency = latency,
		latencyJitter = clamp(math.abs(currentLatency - averageLatency), 0, 0.1),
		hero = heroState,
		invoke = invokeState,
		actions = actions,
		target = target,
		enemies = enemies,
		sunUnits = sunUnits,
		roshan = roshan,
		tormentors = tormentors,
		forgeSpirits = forgeSpirits,
		cursor = cursor,
		targetMode = mode,
	}
end


for _, id in ipairs(itemIds) do
	definitions[id].id = id
	definitions[id].sharedCooldown = id
	definitions[id].projectileSpeed = definitions[id].projectileSpeed or 0
	definitions[id].fixedDelay = definitions[id].fixedDelay or 0
	definitions[id].resetsWithRefresher = false
	definitions[id].icon = ("panorama/images/items/%s_png.vtex_c"):format((id:gsub("^item_", "")))
end

allActionIds = {}
for _, id in ipairs(spellIds) do allActionIds[#allActionIds + 1] = id end
for _, id in ipairs(itemIds) do allActionIds[#allActionIds + 1] = id end

local panelSlots = {"D", "1", "2", "3", "4", "5"}

local comboDefaults = {
	["1"] = {"tornado", "chaos_meteor", "emp", "sun_strike", "deafening_blast"},
	["2"] = {"cold_snap", "tornado", "emp", "deafening_blast"},
	["3"] = {"tornado", "chaos_meteor", "sun_strike", "deafening_blast", "item_refresher", "chaos_meteor", "sun_strike"},
	["4"] = {"cold_snap", "forge_spirit", "ice_wall", "chaos_meteor", "deafening_blast"},
	["5"] = {},
}

local function comboSequenceValid(actions)
	local cooling = {}
	local refresherSeen = false
	for _, id in ipairs(actions) do
		local definition = definitions[id]
		if not definition or cooling[definition.sharedCooldown] then return false end
		if id == "item_refresher" then
			if refresherSeen then return false end
			refresherSeen = true
			for group, priorId in pairs(cooling) do
				if definitions[priorId].resetsWithRefresher then cooling[group] = nil end
			end
		else
			cooling[definition.sharedCooldown] = id
		end
	end
	return true
end

local function decodeCombo(value)
	local result = {}
	for id in value:gmatch("[^,%s]+") do
		if definitions[id] and #result < cfg.maxComboActions then
			local proposed = arrayCopy(result)
			proposed[#proposed + 1] = id
			if comboSequenceValid(proposed) then result = proposed end
		end
	end
	return result
end

local function loadComboStore()
	local combos = {}
	for slot = 1, 5 do
		local key = tostring(slot)
		local fallback = table.concat(comboDefaults[key], ",")
		combos[key] = decodeCombo(Config.ReadString(cfg.configName, "combo_" .. key, fallback))
	end
	return combos
end

function helpers.loadComboStrict()
	local strict = {}
	for slot = 1, 5 do
		local key = tostring(slot)
		strict[key] = Config.ReadInt(cfg.configName, "combo_strict_" .. key, 0) == 1
	end
	return strict
end

local function loadDynamicSpells()
	local enabled = {}
	local saved = Config.ReadString(cfg.configName, "dynamic_spells", "__unset__")
	if saved == "__unset__" then
		for _, id in ipairs(spellIds) do
			if id ~= "ghost_walk" then enabled[id] = id ~= "tornado" end
		end
		return enabled
	end
	for id in saved:gmatch("[^,%s]+") do
		if definitions[id] and definitions[id].kind == "spell" and id ~= "ghost_walk" then enabled[id] = true end
	end
	return enabled
end

local function saveDynamicSpells()
	local enabled = {}
	for _, id in ipairs(spellIds) do
		if id ~= "ghost_walk" and state.dynamicSpells[id] then enabled[#enabled + 1] = id end
	end
	Config.WriteString(cfg.configName, "dynamic_spells", table.concat(enabled, ","))
end

local function loadPanelState()
	local selectedSlot = Config.ReadString(cfg.configName, "panel_selected", "D")
	if not contains(panelSlots, selectedSlot) then selectedSlot = "D" end
	return {
		x = Config.ReadFloat(cfg.configName, "panel_x", cfg.panelPosition.x),
		y = Config.ReadFloat(cfg.configName, "panel_y", cfg.panelPosition.y),
		expanded = Config.ReadInt(cfg.configName, "panel_expanded", 0) == 1,
		selectedSlot = selectedSlot,
		dragging = false,
		dragOffsetX = 0,
		dragOffsetY = 0,
		dragFrom = nil,
		leftWasDown = false,
		header = nil,
		expand = nil,
		clear = nil,
		slotHitboxes = {},
		paletteHitboxes = {},
		comboHitboxes = {},
	}
end

local function savePanelState()
	local panel = state.panel
	Config.WriteFloat(cfg.configName, "panel_x", panel.anchorX or panel.x)
	Config.WriteFloat(cfg.configName, "panel_y", panel.anchorY or panel.y)
	Config.WriteInt(cfg.configName, "panel_expanded", panel.expanded and 1 or 0)
	Config.WriteString(cfg.configName, "panel_selected", panel.selectedSlot)
end

local function saveComboSlot(slot)
	Config.WriteString(cfg.configName, "combo_" .. slot, table.concat(state.combos[slot], ","))
end

local function loadSpellBarState()
	return {
		x = Config.ReadFloat(cfg.configName, "spell_bar_x", 0),
		y = Config.ReadFloat(cfg.configName, "spell_bar_y", 0),
		positioned = Config.ReadInt(cfg.configName, "spell_bar_positioned", 0) == 1,
		dragging = false,
		dragOffsetX = 0,
		dragOffsetY = 0,
		leftWasDown = false,
		panelRect = nil,
		gripRect = nil,
		hitboxes = {},
	}
end

local function saveSpellBarState()
	local spellBar = state.spellBar
	Config.WriteFloat(cfg.configName, "spell_bar_x", spellBar.x)
	Config.WriteFloat(cfg.configName, "spell_bar_y", spellBar.y)
	Config.WriteInt(cfg.configName, "spell_bar_positioned", spellBar.positioned and 1 or 0)
end

local linkenBreakers = {
	"item_diffusal_blade", "item_disperser", "item_urn_of_shadows", "item_spirit_vessel",
	"item_force_staff", "item_harpoon", "item_orchid", "item_bloodthorn", "item_nullifier",
	"item_dagon", "item_rod_of_atos", "item_ethereal_blade", "item_cyclone", "cold_snap",
	"item_sheepstick", "item_abyssal_blade", "item_heavens_halberd", "item_hurricane_pike",
}

do
	local localizedMenu = localization.wrapLibrary(Menu)
	local invokerMenu = localizedMenu.Create("Heroes", "Hero List", "Invoker (Beta)")
	local mainTab = invokerMenu:Create("tab.main")
	local panelsTab = invokerMenu:Create("tab.panels")
	local autoTab = invokerMenu:Create("tab.auto")
	local bindsTab = invokerMenu:Create("tab.binds")
	local extraTab = invokerMenu:Create("tab.extra")

	mainTab:Icon(fontIcons.magic)
	panelsTab:Icon(fontIcons.view)
	autoTab:Icon(fontIcons.crosshairs)
	bindsTab:Icon(fontIcons.magic)
	extraTab:Icon(fontIcons.sliders)

	local heroGroup = mainTab:Create("group.hero", Enum.GroupSide.Left)
	local movementGroup = mainTab:Create("group.movement", Enum.GroupSide.Left)
	local itemsGroup = mainTab:Create("group.items", Enum.GroupSide.Right)
	local switcherGroup = mainTab:Create("group.switcher", Enum.GroupSide.Right)
	local comboPanelGroup = panelsTab:Create("group.combo_panel", Enum.GroupSide.Left)
	local spellPanelGroup = panelsTab:Create("group.spell_panel", Enum.GroupSide.Right)
	local executionGroup = panelsTab:Create("group.execution", Enum.GroupSide.Right)
	local sunGroup = autoTab:Create("group.sun_strike", Enum.GroupSide.Left)
	local stealGroup = autoTab:Create("group.auto_steal", Enum.GroupSide.Left)
	local cataclysmGroup = autoTab:Create("group.cataclysm", Enum.GroupSide.Right)
	local interruptGroup = autoTab:Create("group.interrupts", Enum.GroupSide.Right)
	local extraGroup = extraTab:Create("group.extra", Enum.GroupSide.FullWidth)

	local itemOptions = {}
	for _, id in ipairs(itemIds) do itemOptions[#itemOptions + 1] = {id, definitions[id].icon, true} end
	local breakerOptions = {}
	for _, id in ipairs(linkenBreakers) do breakerOptions[#breakerOptions + 1] = {id, definitions[id].icon, true} end
	local orbOptions = {
		{"quas", menuIcons.quas, true},
		{"wex", menuIcons.wex, true},
		{"exort", menuIcons.exort, true},
	}
	local interruptOptions = {
		{"tornado", definitions.tornado.icon, true},
		{"cold_snap", definitions.cold_snap.icon, true},
	}

	ui = {}
	local automationGroup = bindsTab:Create("group.automation", Enum.GroupSide.Left)
	local comboSelectionGroup = bindsTab:Create("group.combo_selection", Enum.GroupSide.Left)
	local selfCastGroup = bindsTab:Create("group.self_cast", Enum.GroupSide.Right)
	local prepareGroup = bindsTab:Create("group.prepare_binds", Enum.GroupSide.Right)
	ui.meteorFarm = localized(automationGroup:Bind("Meteor Farm", Enum.ButtonCode.KEY_NONE, definitions.ice_wall.icon), "ui.meteor_farm", "tip.meteor_farm")
	local farmGear = ui.meteorFarm:Gear("gear.farm")
	ui.farmHammer = localized(farmGear:Switch(tr("ui.farm_hammer"), true, definitions.item_meteor_hammer.icon), "ui.farm_hammer", "tip.farm_hammer")
	ui.tornadoStack = localized(automationGroup:Bind(tr("ui.tornado_stack"), Enum.ButtonCode.KEY_NONE, definitions.tornado.icon), "ui.tornado_stack", "tip.tornado_stack")
	ui.bindSelfGhost = selfCastGroup:Bind(definitions.ghost_walk.name, Enum.ButtonCode.KEY_NONE, definitions.ghost_walk.icon)
	ui.bindSelfAlacrity = selfCastGroup:Bind(definitions.alacrity.name, Enum.ButtonCode.KEY_NONE, definitions.alacrity.icon)
	for _, id in ipairs(cfg.bindSpellIds) do
		local bind = prepareGroup:Bind(definitions[id].name, Enum.ButtonCode.KEY_NONE, definitions[id].icon)
		ui["bindPrepare_" .. id] = bind
		local gear = localized(bind:Gear("prepare_" .. id), "title.bind_prepare")
		ui["bindQuick_" .. id] = localized(gear:Switch(tr("ui.bind_quick_cast"), false), "ui.bind_quick_cast", "tip.bind_quick_cast")
		if id == "ice_wall" then
			ui.bindAimWall = localized(gear:Switch(tr("ui.bind_aim_wall"), true), "ui.bind_aim_wall", "tip.bind_aim_wall")
		end
	end
	ui.enabled = localized(heroGroup:Switch(tr("ui.enabled"), true, menuIcons.hero), "ui.enabled", "tip.enabled")
	ui.comboKey = localized(heroGroup:Bind(tr("ui.combo_key"), Enum.ButtonCode.KEY_NONE, menuIcons.invoke), "ui.combo_key", "tip.combo_key")
	ui.cursorKey = localized(heroGroup:Bind(tr("ui.cursor_key"), Enum.ButtonCode.KEY_NONE, definitions.tornado.icon), "ui.cursor_key", "tip.cursor_key")
	helpers.bindControls = {ui.comboKey, ui.cursorKey, ui.meteorFarm, ui.tornadoStack, ui.bindSelfGhost, ui.bindSelfAlacrity}
	for _, id in ipairs(cfg.bindSpellIds) do helpers.bindControls[#helpers.bindControls + 1] = ui["bindPrepare_" .. id] end
	for _, slot in ipairs(panelSlots) do
		local label = slot == "D" and "ui.select_dynamic" or "ui.select_combo_" .. slot
		local bind = localized(comboSelectionGroup:Bind(tr(label), Enum.ButtonCode.KEY_NONE, menuIcons.invoke), label, "tip.select_combo")
		ui["bindSelect_" .. slot] = bind
		helpers.bindControls[#helpers.bindControls + 1] = bind
	end
	for _, bind in ipairs(helpers.bindControls) do bind:ShowInBindIsland(false) end
	ui.autoPrepare = localized(heroGroup:Switch(tr("ui.auto_prepare"), true, menuIcons.invoke), "ui.auto_prepare", "tip.auto_prepare")
	local precastGear = ui.autoPrepare:Gear("gear.precast")
	ui.precastHold = localized(precastGear:Switch(tr("ui.precast_hold"), false), "ui.precast_hold", "tip.precast_hold")
	ui.precastBind = localized(precastGear:Bind(tr("ui.precast_bind"), Enum.ButtonCode.KEY_NONE, menuIcons.invoke), "ui.precast_bind", "tip.precast_hold")
	ui.precastBind:ShowInBindIsland(false)
	helpers.bindControls[#helpers.bindControls + 1] = ui.precastBind
	ui.precastMode = localized(
		precastGear:Combo(tr("ui.precast_mode"), {"Custom", "Always"}, 1),
		"ui.precast_mode",
		"tip.precast_mode",
		{"precast.custom", "precast.always"}
	)
	ui.castCraftedFirst = localized(heroGroup:Switch(tr("ui.cast_crafted_first"), true, menuIcons.invoke), "ui.cast_crafted_first", "tip.cast_crafted_first")
	local readyGear = localized(ui.castCraftedFirst:Gear("gear.ready_spells"), "title.ready_spells")
	ui.preparedOutsideCombo = localized(readyGear:Switch(tr("ui.prepared_outside_combo"), false), "ui.prepared_outside_combo", "tip.prepared_outside_combo")
	ui.kiting = localized(movementGroup:Switch(tr("ui.kiting"), false), "ui.kiting", "tip.kiting")
	ui.moveDirection = localized(movementGroup:Combo(tr("ui.move_direction"), {"Enemy", "Cursor"}, 0), "ui.move_direction", "tip.move_direction", {"move.enemy", "move.cursor"})
	ui.preserveControl = localized(heroGroup:Switch(tr("ui.preserve_control"), true, definitions.tornado.icon), "ui.preserve_control", "tip.preserve_control")
	ui.continueDynamic = localized(heroGroup:Switch(tr("ui.continue_dynamic"), true, definitions.chaos_meteor.icon), "ui.continue_dynamic", "tip.continue_dynamic")

	ui.itemsLabel = localized(itemsGroup:Label(tr("ui.items"), "\u{f1b3}"), "ui.items", "tip.items")
	local itemGear = ui.itemsLabel:Gear("gear.items", "\u{f141}")
	ui.items = localized(itemGear:MultiSelect(tr("ui.items_picker"), itemOptions, true), "ui.items_picker", "tip.items")
	ui.linkenLabel = localized(itemsGroup:Label(tr("ui.linken_priority"), "\u{f132}"), "ui.linken_priority", "tip.linken_priority")
	local linkenGear = ui.linkenLabel:Gear("gear.linkens", "\u{f141}")
	ui.linkenPriority = localized(linkenGear:MultiSelect(tr("ui.linken_picker"), breakerOptions, true), "ui.linken_picker", "tip.linken_priority")
	ui.linkenPriority:DragAllowed(true)

	ui.autoOrbs = localized(switcherGroup:Switch(tr("ui.auto_orbs"), false, menuIcons.quas), "ui.auto_orbs", "tip.auto_orbs")
	ui.orbMode = localized(
		switcherGroup:Combo(tr("ui.orb_mode"), {"Outside Combo", "Always"}, 0),
		"ui.orb_mode",
		"tip.orb_mode",
		{"orb_mode.outside", "orb_mode.always"}
	)
	ui.allowedOrbs = localized(switcherGroup:MultiSelect(tr("ui.allowed_orbs"), orbOptions, true), "ui.allowed_orbs", "tip.allowed_orbs")
	local orbGear = ui.autoOrbs:Gear("gear.orbs")
	ui.quasHealth = localized(orbGear:Slider(tr("ui.quas_health"), 10, 90, 40, "%d%%"), "ui.quas_health", "tip.quas_health")
	ui.wexWalkTime = localized(orbGear:Slider(tr("ui.wex_walk"), 5, 50, 15, function(value) return ("%.1fs"):format(value / 10) end), "ui.wex_walk", "tip.wex_walk")
	ui.manualOrderPause = localized(orbGear:Slider(tr("ui.manual_order_pause"), 5, 50, 15, function(value) return ("%.1fs"):format(value / 10) end), "ui.manual_order_pause", "tip.manual_order_pause")
	ui.orbMode:Icon(fontIcons.exchange)
	ui.allowedOrbs:Icon(fontIcons.magic)
	ui.quasHealth:Icon(fontIcons.percent)
	ui.wexWalkTime:Icon(fontIcons.forward)
	ui.manualOrderPause:Icon(fontIcons.pause)

	ui.autoInterrupt = localized(interruptGroup:Switch(tr("ui.auto_interrupt"), true, definitions.tornado.icon), "ui.auto_interrupt", "tip.auto_interrupt")
	ui.interruptSpells = localized(interruptGroup:MultiSelect(tr("ui.interrupt_spells"), interruptOptions, true), "ui.interrupt_spells", "tip.interrupt_spells")
	ui.interruptTeleports = localized(interruptGroup:Switch(tr("ui.interrupt_teleports"), true, fontIcons.pause), "ui.interrupt_teleports", "tip.interrupt_teleports")
	ui.interruptFogTeleports = localized(interruptGroup:Switch(tr("ui.interrupt_fog_teleports"), true, definitions.tornado.icon), "ui.interrupt_fog_teleports", "tip.interrupt_fog_teleports")

	ui.autoSunStrike = localized(sunGroup:Switch(tr("ui.auto_sun_strike"), true, definitions.sun_strike.icon), "ui.auto_sun_strike", "tip.auto_sun_strike")
	ui.landingSun = localized(sunGroup:Switch(tr("ui.landing_sun"), true, definitions.sun_strike.icon), "ui.landing_sun", "tip.landing_sun")
	local landingGear = localized(ui.landingSun:Gear("gear.landing_sun"), "title.landing_sun")
	ui.landingTeleports = localized(landingGear:Switch(tr("ui.landing_teleports"), true), "ui.landing_teleports")
	ui.landingCyclones = localized(landingGear:Switch(tr("ui.landing_cyclones"), true), "ui.landing_cyclones")
	ui.landingLethal = localized(landingGear:Switch(tr("ui.landing_lethal"), false), "ui.landing_lethal", "tip.landing_lethal")
	ui.fountainSun = localized(stealGroup:Switch(tr("ui.fountain_sun"), true, menuIcons.fountain), "ui.fountain_sun", "tip.fountain_sun")
	ui.autoRoshan = localized(stealGroup:Switch(tr("ui.auto_roshan"), false, menuIcons.roshan), "ui.auto_roshan", "tip.auto_roshan")
	ui.autoTormentor = localized(stealGroup:Switch(tr("ui.auto_tormentor"), false, menuIcons.tormentor), "ui.auto_tormentor", "tip.auto_tormentor")
	local tormentorGear = ui.autoTormentor:Gear("gear.tormentor")
	ui.tormentorMargin = localized(tormentorGear:Slider(tr("ui.roshan_margin"), 0, 500, 150, "%d"), "ui.roshan_margin")
	local roshanGear = ui.autoRoshan:Gear("gear.roshan")
	ui.roshanMargin = localized(roshanGear:Slider(tr("ui.roshan_margin"), 0, 200, 25, "%d"), "ui.roshan_margin", "tip.roshan_margin")
	local sunGear = ui.autoSunStrike:Gear("gear.sun")
	ui.sunMinMana = localized(sunGear:Slider(tr("ui.sun_min_mana"), 0, 100, 20, "%d%%"), "ui.sun_min_mana", "tip.sun_min_mana")
	ui.sunWalkTime = localized(sunGear:Slider(tr("ui.sun_walk_time"), 5, 40, 15, function(value) return ("%.1fs"):format(value / 10) end), "ui.sun_walk_time", "tip.sun_walk_time")
	ui.sunIdleTime = localized(sunGear:Slider(tr("ui.sun_idle_time"), 3, 30, 10, function(value) return ("%.1fs"):format(value / 10) end), "ui.sun_idle_time", "tip.sun_idle_time")
	ui.useControlledTargets = localized(sunGroup:Switch(tr("ui.use_controlled_targets"), true), "ui.use_controlled_targets", "tip.use_controlled_targets")
	ui.predictRunningTargets = localized(sunGroup:Switch(tr("ui.predict_running_targets"), true), "ui.predict_running_targets", "tip.predict_running_targets")
	ui.quickSunButtons = localized(sunGroup:Switch(tr("ui.quick_sun_buttons"), true), "ui.quick_sun_buttons", "tip.quick_sun_buttons")
	ui.sunMinMana:Icon(fontIcons.percent)
	ui.sunWalkTime:Icon(fontIcons.forward)
	ui.sunIdleTime:Icon(fontIcons.clock)
	ui.useControlledTargets:Icon(fontIcons.crosshairs)
	ui.predictRunningTargets:Icon(fontIcons.forward)
	ui.quickSunButtons:Icon(fontIcons.users)

	ui.useCataclysm = localized(cataclysmGroup:Switch(tr("ui.use_cataclysm"), true, definitions.cataclysm.icon), "ui.use_cataclysm", "tip.use_cataclysm")
	ui.autoCataclysm = localized(cataclysmGroup:Switch(tr("ui.auto_cataclysm"), true, definitions.cataclysm.icon), "ui.auto_cataclysm", "tip.auto_cataclysm")
	ui.autoRefresher = localized(cataclysmGroup:Switch(tr("ui.auto_refresher"), true, definitions.item_refresher.icon), "ui.auto_refresher", "tip.auto_refresher")
	ui.cataclysmMinHeroes = localized(cataclysmGroup:Slider(tr("ui.cataclysm_min_heroes"), 2, 5, 2, "%d"), "ui.cataclysm_min_heroes", "tip.cataclysm_min_heroes")
	ui.useRefresher = localized(cataclysmGroup:Switch(tr("ui.use_refresher"), true, definitions.item_refresher.icon), "ui.use_refresher", "tip.use_refresher")
	ui.cataclysmMinHeroes:Icon(fontIcons.users)

	ui.showPanel = localized(comboPanelGroup:Switch(tr("ui.show_panel"), true, menuIcons.invoke), "ui.show_panel", "tip.show_panel")
	ui.panelScale = localized(comboPanelGroup:Slider(tr("ui.panel_scale"), 60, 150, 100, "%d%%"), "ui.panel_scale", "tip.panel_scale")
	ui.panelOrientation = localized(
		comboPanelGroup:Combo(tr("ui.panel_orientation"), {"Horizontal", "Vertical"}, 0),
		"ui.panel_orientation",
		"tip.panel_orientation",
		{"orientation.horizontal", "orientation.vertical"}
	)
	ui.compactPanel = localized(comboPanelGroup:Switch(tr("ui.compact_panel"), true), "ui.compact_panel", "tip.compact_panel")
	ui.panelScale:Icon(fontIcons.sliders)
	ui.panelOrientation:Icon(fontIcons.exchange)
	ui.compactPanel:Icon(fontIcons.compress)

	ui.showSpellBar = localized(spellPanelGroup:Switch(tr("ui.show_spell_bar"), true, menuIcons.invoke), "ui.show_spell_bar", "tip.show_spell_bar")
	ui.spellBarScale = localized(spellPanelGroup:Slider(tr("ui.spell_bar_scale"), 50, 140, 70, "%d%%"), "ui.spell_bar_scale", "tip.spell_bar_scale")
	ui.spellBarLayout = localized(
		spellPanelGroup:Combo(tr("ui.spell_bar_layout"), {"Horizontal", "3 per row"}, 0),
		"ui.spell_bar_layout",
		"tip.spell_bar_layout",
		{"spell_layout.horizontal", "spell_layout.grid"}
	)
	ui.spellBarScale:Icon(fontIcons.sliders)
	ui.spellBarLayout:Icon(fontIcons.exchange)

	ui.showExecution = localized(executionGroup:Switch(tr("ui.show_execution"), true, definitions.chaos_meteor.icon), "ui.show_execution", "tip.show_execution")
	ui.statusText = localized(executionGroup:Switch(tr("ui.status_text"), true), "ui.status_text", "tip.status_text")
	ui.indicatorScale = localized(executionGroup:Slider(tr("ui.indicator_scale"), 60, 150, 100, "%d%%"), "ui.indicator_scale", "tip.indicator_scale")
	ui.debugLogs = localized(extraGroup:Switch(tr("ui.debug_logs"), false), "ui.debug_logs", "tip.debug_logs")
	ui.statusText:Icon(fontIcons.list)
	ui.indicatorScale:Icon(fontIcons.sliders)
	ui.debugLogs:Icon(fontIcons.bug)

	local function refreshMenuState()
		local masterDisabled = not ui.enabled:Get()
		ui.meteorFarm:Disabled(masterDisabled)
		ui.farmHammer:Disabled(masterDisabled)
		ui.tornadoStack:Disabled(masterDisabled)
		ui.bindSelfGhost:Disabled(masterDisabled)
		ui.bindSelfAlacrity:Disabled(masterDisabled)
		for _, id in ipairs(cfg.bindSpellIds) do
			ui["bindPrepare_" .. id]:Disabled(masterDisabled)
			ui["bindQuick_" .. id]:Disabled(masterDisabled)
		end
		ui.bindAimWall:Disabled(masterDisabled or not ui.bindQuick_ice_wall:Get())
		ui.comboKey:Disabled(masterDisabled)
		ui.cursorKey:Disabled(masterDisabled)
		for _, slot in ipairs(panelSlots) do ui["bindSelect_" .. slot]:Disabled(masterDisabled) end
		ui.autoPrepare:Disabled(masterDisabled)
		ui.precastMode:Disabled(masterDisabled or not ui.autoPrepare:Get())
		ui.precastHold:Disabled(masterDisabled or not ui.autoPrepare:Get())
		ui.precastBind:Disabled(masterDisabled or not ui.autoPrepare:Get() or not ui.precastHold:Get())
		ui.castCraftedFirst:Disabled(masterDisabled)
		ui.preparedOutsideCombo:Disabled(masterDisabled or not ui.castCraftedFirst:Get())
		ui.kiting:Disabled(masterDisabled)
		ui.moveDirection:Disabled(masterDisabled)
		ui.preserveControl:Disabled(masterDisabled)
		ui.continueDynamic:Disabled(masterDisabled)
		ui.useCataclysm:Disabled(masterDisabled)
		ui.autoCataclysm:Disabled(masterDisabled)
		ui.autoRefresher:Disabled(masterDisabled or not ui.autoCataclysm:Get())
		ui.fountainSun:Disabled(masterDisabled)
		ui.cataclysmMinHeroes:Disabled(masterDisabled or not ui.useCataclysm:Get() and not ui.autoCataclysm:Get())
		ui.useRefresher:Disabled(masterDisabled)

		ui.itemsLabel:Disabled(masterDisabled)
		ui.items:Disabled(masterDisabled)
		ui.linkenLabel:Disabled(masterDisabled)
		ui.linkenPriority:Disabled(masterDisabled)

		local orbsDisabled = masterDisabled or not ui.autoOrbs:Get()
		ui.autoOrbs:Disabled(masterDisabled)
		ui.orbMode:Disabled(orbsDisabled)
		ui.allowedOrbs:Disabled(orbsDisabled)
		ui.quasHealth:Disabled(orbsDisabled)
		ui.wexWalkTime:Disabled(orbsDisabled)
		ui.manualOrderPause:Disabled(orbsDisabled)

		local interruptsDisabled = masterDisabled or not ui.autoInterrupt:Get()
		ui.autoInterrupt:Disabled(masterDisabled)
		ui.interruptSpells:Disabled(interruptsDisabled)
		ui.interruptTeleports:Disabled(interruptsDisabled)
		ui.interruptFogTeleports:Disabled(interruptsDisabled or not ui.interruptTeleports:Get() or not ui.interruptSpells:Get("tornado"))

		local sunDisabled = masterDisabled or not ui.autoSunStrike:Get()
		ui.autoSunStrike:Disabled(masterDisabled)
		ui.landingSun:Disabled(masterDisabled)
		ui.landingTeleports:Disabled(masterDisabled or not ui.landingSun:Get())
		ui.landingCyclones:Disabled(masterDisabled or not ui.landingSun:Get())
		ui.landingLethal:Disabled(masterDisabled or not ui.landingSun:Get())
		ui.sunMinMana:Disabled(masterDisabled or not ui.autoSunStrike:Get() and not ui.autoCataclysm:Get()
			and not ui.autoRoshan:Get() and not ui.autoTormentor:Get() and not ui.landingSun:Get())
		ui.sunWalkTime:Disabled(sunDisabled)
		ui.sunIdleTime:Disabled(sunDisabled)
		ui.useControlledTargets:Disabled(sunDisabled)
		ui.predictRunningTargets:Disabled(sunDisabled)
		ui.quickSunButtons:Disabled(sunDisabled)
		local roshanDisabled = masterDisabled or not ui.autoRoshan:Get()
		ui.autoRoshan:Disabled(masterDisabled)
		ui.roshanMargin:Disabled(roshanDisabled)
		local tormentorDisabled = masterDisabled or not ui.autoTormentor:Get()
		ui.autoTormentor:Disabled(masterDisabled)
		ui.tormentorMargin:Disabled(tormentorDisabled)

		local panelDisabled = masterDisabled or not ui.showPanel:Get()
		ui.showPanel:Disabled(masterDisabled)
		ui.panelScale:Disabled(panelDisabled)
		ui.panelOrientation:Disabled(panelDisabled)
		ui.compactPanel:Disabled(panelDisabled)

		local spellBarDisabled = masterDisabled or not ui.showSpellBar:Get()
		ui.showSpellBar:Disabled(masterDisabled)
		ui.spellBarScale:Disabled(spellBarDisabled)
		ui.spellBarLayout:Disabled(spellBarDisabled)

		local executionDisabled = masterDisabled or not ui.showExecution:Get()
		ui.showExecution:Disabled(masterDisabled)
		ui.statusText:Disabled(executionDisabled)
		ui.indicatorScale:Disabled(executionDisabled)
	end

	for name, control in pairs(ui) do
		if name ~= "itemsLabel" and name ~= "linkenLabel" then
			control:SetCallback(function()
				state.settingsCache = nil
				refreshMenuState()
			end)
		end
	end
	refreshMenuState()

	renderCtx = {
		font = Render.LoadFont("Arial", Enum.FontCreate.FONTFLAG_ANTIALIAS, 500),
		titleFont = Render.LoadFont("Arial", Enum.FontCreate.FONTFLAG_ANTIALIAS, 700),
		badgeFont = Render.LoadFont("Arial", Enum.FontCreate.FONTFLAG_ANTIALIAS, 700),
		cooldownFont = Render.LoadFont("Arial", Enum.FontCreate.FONTFLAG_ANTIALIAS, 700),
		icons = {},
		controls = {
			arrowRight = Render.LoadImage("panorama/images/control_icons/arrow_solid_right_png.vtex_c"),
			arrowLeft = Render.LoadImage("panorama/images/control_icons/arrow_solid_left_png.vtex_c"),
			close = Render.LoadImage("panorama/images/control_icons/x_close_png.vtex_c"),
		},
		craftIds = {},
	}
	for _, id in ipairs(spellIds) do
		if id ~= "cataclysm" then renderCtx.craftIds[#renderCtx.craftIds + 1] = id end
	end
	for _, id in ipairs(allActionIds) do renderCtx.icons[id] = Render.LoadImage(definitions[id].icon) end

	state = {
		combos = loadComboStore(),
		comboStrict = helpers.loadComboStrict(),
		dynamicSpells = loadDynamicSpells(),
		panel = loadPanelState(),
		spellBar = loadSpellBarState(),
		hero = nil,
		player = nil,
		bindings = nil,
		now = 0,
		snapshot = nil,
		motion = {},
		invokeSequence = nil,
		orbSequence = nil,
		lastCompletedInvoke = nil,
		assumedInvoked = {},
		plan = nil,
		pendingCast = nil,
		status = "",
		statusPhase = "idle",
		lastHeldMode = nil,
		lastHeldSlot = nil,
		nextPlanAt = 0,
		nextAttackAt = 0,
		nextIdlePrepareAt = 0,
		nextAutoActionAt = 0,
		nextAutoOrbAt = 0,
		lastPlanCheck = 0,
		lastTargetPosition = {x = 0, y = 0, z = 0},
		lastTargetVelocity = {x = 0, y = 0, z = 0},
		lastTargetMoving = false,
		nextInvokeAttempt = 0,
		nextDynamicReplanAt = 0,
		nextFaceAttempt = 0,
		nextIceWallMoveAt = 0,
		walkingSince = math.huge,
		automaticActionsPausedUntil = 0,
		autoOrbsPausedUntil = 0,
		autoPending = nil,
		manualCraft = nil,
		issuingOrder = false,
		orderGuardUntil = 0,
		lastDebug = {},
		debugTimes = {},
		lastHeroPosition = nil,
		lastHeroPositionAt = 0,
		measuredHeroSpeed = 0,
		dynamicPreview = {},
		dynamicContinue = false,
		quickSunHitboxes = {},
		quickSunEntries = {},
		fountain = {done = false, queued = false, nextTrainAt = 0, trainAttempts = 0},
	}

end

local function recipeAvailable(recipe, levels)
	if not recipe then return true end
	for _, orb in ipairs(recipe) do
		if levels[orb] <= 0 then return false end
	end
	return true
end

local function levelValue(level, values)
	local index = clamp(math.floor(level), 1, #values)
	return values[index] or values[1] or 0
end

local function liveValue(snapshot, id, key, fallback)
	local action = snapshot.actions[id]
	local value = action and action.specials[key]
	if type(value) == "number" then return value end
	return fallback
end

---Resolves live timing, range, control, and damage for an action.
---@param id string
---@param snapshot InvokerSnapshot
---@param distance? number
---@param impactAt? number
---@return table
local function resolveMechanics(id, snapshot, distance, impactAt)
	local definition = definitions[id]
	local action = snapshot.actions[id]
	local q = snapshot.hero.orbLevels.quas
	local w = snapshot.hero.orbLevels.wex
	local e = snapshot.hero.orbLevels.exort
	local result = {
		castPoint = action and action.castPoint or (definition.kind == "spell" and 0.05 or 0),
		castRange = action and action.castRange or 0,
		radius = 0,
		projectileSpeed = definition.projectileSpeed,
		fixedDelay = definition.fixedDelay,
		channelTime = 0,
		duration = 0,
		controlDuration = 0,
		manaCost = action and action.manaCost or (id == "item_refresher" and 325 or 0),
		expectedDamage = 0,
		setup = definition.setup,
		control = definition.control,
		reliability = definition.reliability,
	}

	if id == "item_meteor_hammer" then
		result.channelTime = liveValue(snapshot, id, "max_duration", 2)
		result.fixedDelay = result.channelTime + liveValue(snapshot, id, "land_time", 0.5)
		result.radius = liveValue(snapshot, id, "impact_radius", 400)
		result.duration = liveValue(snapshot, id, "burn_duration", 6)
		result.controlDuration = liveValue(snapshot, id, "stun_duration", 0.75)
		result.expectedDamage = liveValue(snapshot, id, "impact_damage_units", 130)
			+ liveValue(snapshot, id, "burn_dps_units", 50) * result.duration
	elseif id == "cold_snap" then
		result.duration = liveValue(snapshot, id, "duration", 2.6 + 0.4 * q)
		local triggers = math.max(1, math.floor(result.duration / math.max(0.1, liveValue(snapshot, id, "freeze_cooldown", 0.83 - 0.03 * q))))
		result.controlDuration = math.min(result.duration, 0.4 * triggers)
		result.expectedDamage = liveValue(snapshot, id, "freeze_damage", 20 + 8 * q) * triggers
	elseif id == "ghost_walk" then
		result.duration = liveValue(snapshot, id, "duration", 50)
	elseif id == "ice_wall" then
		result.duration = liveValue(snapshot, id, "duration", 2 + q)
		local wallControl = liveValue(snapshot, id, "slow_duration", 2)
		if snapshot.hero.upgrades.scepterChoice == "quas" then
			wallControl = math.max(wallControl, liveValue(snapshot, id, "root_duration", 2.5))
			result.fixedDelay = liveValue(snapshot, id, "glacier_formation_delay", 1.3)
		end
		result.controlDuration = math.min(result.duration, wallControl)
		result.radius = liveValue(snapshot, id, "wall_width", 105)
		local interval = math.max(0.1, liveValue(snapshot, id, "tick_interval", 0.5))
		local landingAt = impactAt or snapshot.now + result.castPoint + result.fixedDelay + snapshot.latency
		local exposure = snapshot.target and helpers.wallExposure(snapshot, snapshot.target, {impactAt = landingAt}, result) or interval
		result.expectedDamage = liveValue(snapshot, id, "damage_per_second", 24 + 6 * e) * interval * math.floor(exposure / interval + 0.0001)
		local rootDelay = liveValue(snapshot, id, "root_delay", 0)
		if snapshot.hero.upgrades.scepterChoice == "quas" and rootDelay > 0 and exposure >= rootDelay then
			result.expectedDamage = result.expectedDamage + liveValue(snapshot, id, "root_damage", 0)
		end
	elseif id == "tornado" then
		result.projectileSpeed = liveValue(snapshot, id, "travel_speed", 1000)
		result.duration = 1 + 0.2 * q
		result.controlDuration = result.duration
		result.expectedDamage = liveValue(snapshot, id, "base_damage", 50) + liveValue(snapshot, id, "wex_damage", 45 * w)
		result.radius = liveValue(snapshot, id, "area_of_effect", 200)
	elseif id == "emp" then
		result.fixedDelay = liveValue(snapshot, id, "delay", 2.9)
		local targetMana = snapshot.target and snapshot.target.mana or 0
		result.expectedDamage = math.min(targetMana, liveValue(snapshot, id, "mana_burned", 25 + 75 * w)) * liveValue(snapshot, id, "damage_per_mana_pct", 60) / 100
		result.radius = liveValue(snapshot, id, "area_of_effect", 675)
		result.control = snapshot.hero.upgrades.shardChoice == "wex" and definition.control or 0
	elseif id == "alacrity" then
		result.duration = liveValue(snapshot, id, "duration", 9)
		result.expectedDamage = liveValue(snapshot, id, "bonus_damage", math.max(0, -2 + 12 * e)) * math.min(8, result.duration)
	elseif id == "chaos_meteor" then
		result.fixedDelay = liveValue(snapshot, id, "land_time", 1.3)
		result.radius = liveValue(snapshot, id, "area_of_effect", 275)
		local interval = math.max(0.05, liveValue(snapshot, id, "damage_interval", 0.5))
		local speed = math.max(1, liveValue(snapshot, id, "travel_speed", 300))
		local rollDuration = liveValue(snapshot, id, "travel_distance", 465 + 150 * w) / speed
		local target = snapshot.target
		local landingAt = impactAt or snapshot.now + result.castPoint + result.fixedDelay + snapshot.latency
		local lockedFor = target and not target.invulnerable and not target.outOfGame
			and math.max(0, target.disabledUntil - landingAt - cfg.timingSafety) or 0
		local contactTime = math.min(lockedFor, rollDuration, math.max(0, result.radius - 40) / speed)
		local contacts = 1 + math.floor(contactTime / interval)
		local contact = liveValue(snapshot, id, "main_damage", levelValue(e + 1, {55, 75, 95, 115, 135, 155, 175, 195, 215}))
		local burnDuration = liveValue(snapshot, id, "burn_duration", 3)
		local burn = liveValue(snapshot, id, "burn_dps", levelValue(e + 1, {10, 15, 20, 25, 30, 35, 40, 45, 50})) * burnDuration
		result.expectedDamage = contacts * (contact + burn)
		result.contactCount = contacts
		result.duration = (contacts - 1) * interval + burnDuration
	elseif id == "sun_strike" or id == "cataclysm" then
		result.fixedDelay = liveValue(snapshot, "sun_strike", "delay", 1.7)
		result.expectedDamage = liveValue(snapshot, "sun_strike", "damage", levelValue(e, {175, 225, 275, 325, 375, 425, 475, 525, 575}))
		if id == "cataclysm" then result.expectedDamage = result.expectedDamage * 1.5 end
		result.radius = liveValue(snapshot, "sun_strike", "area_of_effect", cfg.sunRadius)
	elseif id == "forge_spirit" then
		result.duration = 18 + 6 * q
		result.expectedDamage = liveValue(snapshot, id, "spirit_damage", 10 + 10 * e) * clamp(result.duration / 2, 2, 8)
	elseif id == "deafening_blast" then
		result.projectileSpeed = liveValue(snapshot, id, "travel_speed", 1100)
		result.controlDuration = liveValue(snapshot, id, "knockback_duration", 1 + 0.1 * q)
		result.duration = result.controlDuration + liveValue(snapshot, id, "disarm_duration", 1 + 0.5 * w)
		result.expectedDamage = liveValue(snapshot, id, "damage", levelValue(e, {70, 110, 150, 190, 230, 270, 310, 350, 390}))
		result.radius = liveValue(snapshot, id, "radius_end", 225)
	elseif id == "item_cyclone" then
		result.controlDuration = liveValue(snapshot, id, "cyclone_duration", 2.5)
		result.duration = result.controlDuration
	elseif id == "item_sheepstick" then
		result.controlDuration = liveValue(snapshot, id, "sheep_duration", 2.8)
		result.duration = result.controlDuration
	elseif id == "item_orchid" or id == "item_bloodthorn" then
		result.duration = liveValue(snapshot, id, "silence_duration", 5)
	elseif id == "item_abyssal_blade" then
		result.controlDuration = liveValue(snapshot, id, "stun_duration", 1.6)
		result.duration = result.controlDuration
	elseif id == "item_rod_of_atos" or id == "item_gungir" then
		result.controlDuration = liveValue(snapshot, id, "duration", 2)
		result.duration = result.controlDuration
		if id == "item_gungir" then result.radius = liveValue(snapshot, id, "radius", 275) end
	elseif id == "item_heavens_halberd" then
		result.controlDuration = liveValue(snapshot, id, "disarm_range", 3)
		result.duration = result.controlDuration
	elseif id == "item_spirit_vessel" or id == "item_urn_of_shadows" then
		result.duration = liveValue(snapshot, id, "duration", 8)
		result.expectedDamage = liveValue(snapshot, id, "soul_damage_amount", 25) * result.duration
	elseif id == "item_dagon" then
		result.expectedDamage = liveValue(snapshot, id, "damage", 400)
	elseif id == "item_ethereal_blade" then
		result.expectedDamage = liveValue(snapshot, id, "blast_damage_base", 50)
			+ snapshot.hero.totalAttributes * liveValue(snapshot, id, "blast_stat_multiplier", 1)
		result.duration = liveValue(snapshot, id, "duration", 4)
		result.projectileSpeed = liveValue(snapshot, id, "projectile_speed", 1400)
	elseif id == "item_nullifier" then
		result.duration = liveValue(snapshot, id, "mute_duration", 4)
		result.projectileSpeed = liveValue(snapshot, id, "projectile_speed", 1800)
	elseif id == "item_shivas_guard" then
		result.expectedDamage = liveValue(snapshot, id, "blast_damage", 260)
		result.fixedDelay = (distance or 0) / math.max(1, liveValue(snapshot, id, "blast_speed", 400))
		result.radius = liveValue(snapshot, id, "blast_radius", 825)
	elseif id == "item_diffusal_blade" then
		result.duration = liveValue(snapshot, id, "purge_slow_duration", 4)
	elseif id == "item_disperser" then
		result.duration = liveValue(snapshot, id, "enemy_effect_duration", 5)
	elseif id == "item_harpoon" then
		result.duration = liveValue(snapshot, id, "slow_duration", 1)
		result.projectileSpeed = liveValue(snapshot, id, "projectile_speed", 2000)
	end
	return result
end

local function sunSplitCount(snapshot, position, radius, targetIndex, horizon)
	local count = targetIndex and 1 or 0
	for _, unit in ipairs(snapshot.sunUnits) do
		local predicted = add(unit.position, scale(unit.velocity, horizon or 0))
		if unit.index ~= targetIndex and distance2D(predicted, position) <= radius + 24 then count = count + 1 end
	end
	return math.max(1, count)
end

local function actionAvailable(id, snapshot, requireReady)
	local definition = definitions[id]
	if not recipeAvailable(definition.recipe, snapshot.hero.orbLevels) then return false end
	if definition.requiresScepter and snapshot.hero.upgrades.scepterChoice ~= definition.requiresScepter then return false end
	local action = snapshot.actions[id]
	if not action or not action.exists then return false end
	if definition.kind == "item" and (not action.learned or not action.activated) then return false end
	if not requireReady then return true end
	if action.cooldown > 0.05 or snapshot.hero.mana + 0.001 < action.manaCost then return false end
	if definition.kind == "item" then return action.canCast end
	return action.invoked or snapshot.invoke.ready
end

local function predictLinear(position, velocity, seconds, maximumDistance)
	local duration = math.max(0, seconds)
	local delta = scale(velocity, duration)
	local distance = length2D(delta)
	if not maximumDistance or distance <= maximumDistance then return add(position, delta) end
	return add(position, scale(normalized2D(delta), maximumDistance))
end

local function predictTarget(target, seconds, confidence, immobileSeconds)
	if target.invulnerable or seconds <= (immobileSeconds or 0) then return copyPoint(target.position) end
	local horizon = clamp(seconds - (immobileSeconds or 0), 0, 3.5)
	local measuredConfidence = clamp(math.min(confidence or 1, target.motionConfidence), 0.1, 1)
	local measuredSpeed = target.movementDuration >= 0.12 and length2D(target.velocity) or 0
	local facing = normalized2D(target.facing)
	local measuredDirection = measuredSpeed > 18 and normalized2D(target.velocity) or facing
	local agreement = measuredSpeed > 18 and length2D(facing) > 0
		and clamp((dot2D(measuredDirection, facing) + 1) * 0.5, 0, 1)
		or 0.55
	local direction = normalized2D(add(
		scale(measuredDirection, 0.55 + measuredConfidence * 0.35),
		scale(facing, (1 - measuredConfidence) * 0.45)
	))
	local speed = clamp(measuredSpeed > 18 and measuredSpeed or 0, 0, math.max(0, target.moveSpeed) * 1.08)
	local uncertainty = 1 - measuredConfidence * agreement
	local stableRunner = measuredSpeed > 40
		and measuredConfidence >= 0.62
		and agreement >= 0.72
		and target.movementDuration >= 1.2
		and target.stableDuration >= 1.2
	local damping = stableRunner and 1 or 1 - clamp(math.max(0, horizon - 0.65) * 0.1 * uncertainty, 0, 0.24)
	local projected = scale(direction, speed * damping * (stableRunner and 1 or 0.91 + 0.09 * agreement))
	return predictLinear(target.position, projected, horizon, math.max(0, target.moveSpeed) * horizon)
end

function helpers.predictEMP(snapshot, target, seconds)
	local immobile = math.max(0, math.max(target.disabledUntil, target.controlEndsAt) - snapshot.now)
	local freeTime = math.max(0, seconds - immobile)
	-- EMP covers a large area: preserve room for a stop/turn instead of leading the full delay.
	local stable = math.min(target.movementDuration, target.stableDuration)
	local horizon = math.min(freeTime, 0.35 + math.min(0.65, stable * 0.5))
	if (target.modifiers.modifier_invoker_cold_snap or 0) > 0 then horizon = math.min(horizon, 0.35) end
	local predicted = predictTarget(target, horizon, target.motionConfidence, 0)
	local delta = subtract(predicted, target.position)
	local maximum = resolveMechanics("emp", snapshot, 0).radius * 0.45
	if length2D(delta) > maximum then delta = scale(normalized2D(delta), maximum) end
	return add(target.position, delta)
end

---Predicts where a delayed or projectile action will meet its target.
---@param snapshot InvokerSnapshot
---@param id string
---@param target EnemyState
---@param castAt number
---@param confidence number
---@return table
local function predictIntercept(snapshot, id, target, castAt, confidence)
	local initialDistance = distance2D(snapshot.hero.position, target.position)
	local mechanics = resolveMechanics(id, snapshot, initialDistance)
	local commandDelay = math.max(0, castAt - snapshot.now) + mechanics.castPoint + snapshot.latency
	local immobile = math.max(0, math.max(target.disabledUntil, target.controlEndsAt) - snapshot.now)
	local position = id == "emp" and helpers.predictEMP(snapshot, target, commandDelay + mechanics.fixedDelay)
		or predictTarget(target, commandDelay + mechanics.fixedDelay, confidence, immobile)
	local travelTime = mechanics.fixedDelay
	if mechanics.projectileSpeed > 0 then
		for _ = 1, 4 do
			local projectileTime = distance2D(snapshot.hero.position, position) / mechanics.projectileSpeed
			travelTime = mechanics.fixedDelay + projectileTime
			position = predictTarget(target, commandDelay + travelTime, confidence, immobile)
		end
	end
	local movement = length2D(target.velocity)
	local uncertainty = movement * (commandDelay + travelTime) * (1 - clamp(confidence, 0, 1))
	local radius = math.max(80, mechanics.radius)
	return {
		position = position,
		travelTime = travelTime,
		reliability = clamp(mechanics.reliability * (1 - uncertainty / (radius * 2.5)), 0.15, 1),
	}
end

local function predictMeteor(snapshot, target, castAt)
	local impact = predictIntercept(snapshot, "chaos_meteor", target, castAt, target.motionConfidence).position
	local roll = normalized2D(subtract(impact, snapshot.hero.position))
	return add(impact, scale(roll, -math.min(110, 35 + length2D(target.velocity) * 0.18)))
end

local function isInvoking(id)
	return state.invokeSequence ~= nil
		and (not id or state.invokeSequence.actionId == canonicalSpell(id))
end

local function issueOrder(callback)
	state.issuingOrder = true
	state.orderGuardUntil = state.now + 0.08
	callback()
	state.issuingOrder = false
end

---Queues the three-orb recipe and Invoke order for one spell.
---@param id string
---@param forceReinvoke? boolean
---@return boolean
local function queueInvoke(id, forceReinvoke)
	local snapshot = state.snapshot
	id = canonicalSpell(id)
	if not snapshot or id == "cataclysm" then return false end
	local definition = definitions[id]
	if not definition or not recipeAvailable(definition.recipe, snapshot.hero.orbLevels) then return false end
	if not snapshot.invoke.exists then return false end
	if state.invokeSequence and state.invokeSequence.actionId ~= id then return false end
	if state.invokeSequence then return true end
	state.orbSequence = nil
	state.invokeSequence = {
		actionId = id,
		recipe = arrayCopy(definition.recipe),
		step = 1,
		nextAt = snapshot.now,
		forceReinvoke = forceReinvoke == true,
		castIssued = false,
		confirmDeadline = 0,
	}
	logDebug("INVOKE", ("queued %s"):format(id))
	return true
end

local function updateInvokeSequence(snapshot)
	local sequence = state.invokeSequence
	if not sequence or snapshot.now + 0.001 < sequence.nextAt then return end
	if sequence.castIssued then
		if snapshot.invoke.invoked[1] == sequence.actionId then
			logDebug("INVOKE", ("confirmed %s in first slot"):format(sequence.actionId))
			state.invokeSequence = nil
		elseif snapshot.now >= sequence.confirmDeadline then
			logDebug("INVOKE", ("confirmation timed out for %s"):format(sequence.actionId))
			state.invokeSequence = nil
		end
		return
	end

	if sequence.step <= #sequence.recipe then
		local orbName = sequence.recipe[sequence.step]
		local orb = state.bindings.orbs[orbName]
		if not orb or not Ability.IsActivated(orb) or Ability.GetLevel(orb) <= 0 then
			state.invokeSequence = nil
			setStatus("aborted", ("%s is not learned"):format(orbName))
			return
		end
		issueOrder(function() Ability.CastNoTarget(orb, false, false, true, "invoker_auto") end)
		sequence.step = sequence.step + 1
		sequence.nextAt = snapshot.now + cfg.invokeOrbInterval
		return
	end

	if not sequence.forceReinvoke and contains(snapshot.invoke.invoked, sequence.actionId) then
		rememberInvoked(sequence.actionId)
		state.invokeSequence = nil
		return
	end
	if not snapshot.invoke.ready then return end
	issueOrder(function() Ability.CastNoTarget(state.bindings.invoke, false, false, true, "invoker_auto") end)
	rememberInvoked(sequence.actionId)
	state.lastCompletedInvoke = {id = sequence.actionId, at = snapshot.now}
	sequence.castIssued = true
	sequence.confirmDeadline = snapshot.now + cfg.invokeConfirmWindow
	sequence.nextAt = snapshot.now + 0.06
	logDebug("INVOKE", ("cast Invoke for %s"):format(sequence.actionId))
end

local function queueOrbSwitch(orb)
	local snapshot = state.snapshot
	local ability = state.bindings and state.bindings.orbs[orb]
	if not snapshot or isInvoking() or not ability or Ability.GetLevel(ability) <= 0 or not Ability.IsActivated(ability) then
		return false
	end
	if #snapshot.invoke.activeOrbs == 3 then
		local same = true
		for _, current in ipairs(snapshot.invoke.activeOrbs) do
			if current ~= orb then
				same = false
				break
			end
		end
		if same then return false end
	end
	if state.orbSequence and state.orbSequence.orb == orb then return false end
	state.orbSequence = {orb = orb, remaining = 3, nextAt = snapshot.now}
	return true
end

local function updateOrbSequence(snapshot)
	local sequence = state.orbSequence
	if not sequence or state.invokeSequence or snapshot.now + 0.001 < sequence.nextAt then return end
	local orb = state.bindings.orbs[sequence.orb]
	if not orb or Ability.GetLevel(orb) <= 0 or not Ability.IsActivated(orb) or sequence.remaining <= 0 then
		state.orbSequence = nil
		return
	end
	issueOrder(function() Ability.CastNoTarget(orb, false, false, true, "invoker_auto") end)
	sequence.remaining = sequence.remaining - 1
	sequence.nextAt = snapshot.now + cfg.autoOrbInterval
	if sequence.remaining <= 0 then state.orbSequence = nil end
end

function helpers.sunImpactDelay(snapshot, id)
	local mechanics = resolveMechanics(id, snapshot, 0)
	local preparation = snapshot.actions[id].invoked and 0
		or math.max(0.16, cfg.invokeOrbInterval * 3 + 0.06 + snapshot.latency)
	return preparation + mechanics.castPoint + mechanics.fixedDelay + snapshot.latency + cfg.timingSafety
end

function helpers.cataclysmHitsControl(enemy, snapshot)
	local impactAt = snapshot.now + helpers.sunImpactDelay(snapshot, "cataclysm")
	if not enemy.alive or not enemy.visible or enemy.dormant then return false end
	if enemy.controlEndsAt > snapshot.now then
		return impactAt >= enemy.controlEndsAt + 0.03 and impactAt <= enemy.controlEndsAt + 0.2
	end
	return not enemy.invulnerable and not enemy.outOfGame and enemy.disabledUntil >= impactAt
end

local function cataclysmTargetCount(snapshot)
	local count = 0
	for _, enemy in ipairs(snapshot.enemies) do
		if helpers.cataclysmHitsControl(enemy, snapshot) then
			count = count + 1
		end
	end
	return count
end

local function resolveSunAction(id, snapshot, settings, accepted)
	if id ~= "sun_strike"
		or not settings.useCataclysm
		or snapshot.hero.upgrades.scepterChoice ~= "exort"
	then
		return id
	end
	if not contains(settings.enabledSpells, "cataclysm") then return id end
	if not contains(settings.enabledSpells, "sun_strike") then return "cataclysm" end
	local controlledHeroes = cataclysmTargetCount(snapshot)
	local target = snapshot.target
	local securesTarget = false
	if target and target.alive and not target.dormant and (not target.invulnerable or target.controlEndsAt > snapshot.now) then
		local sunMechanics = resolveMechanics("sun_strike", snapshot, 0)
		local impactDelay = helpers.sunImpactDelay(snapshot, "sun_strike")
		local impactAt = snapshot.now + impactDelay
		if math.max(target.disabledUntil, target.controlEndsAt) >= impactAt
			or contains(accepted or {}, "tornado") or contains(accepted or {}, "item_cyclone")
		then
			local prediction = predictIntercept(snapshot, "sun_strike", target, snapshot.now, target.motionConfidence).position
			local splitCount = sunSplitCount(snapshot, prediction, math.max(cfg.sunRadius, sunMechanics.radius), target.index, impactDelay)
			local normalDamage = sunMechanics.expectedDamage / splitCount
			local cataclysmDamage = resolveMechanics("cataclysm", snapshot, 0).expectedDamage / splitCount
			securesTarget = target.health > normalDamage + 1 and target.health <= cataclysmDamage + 1
		end
	end
	return (controlledHeroes >= settings.cataclysmMinHeroes or securesTarget) and "cataclysm" or id
end

local function dynamicActionEnabled(id, snapshot, settings)
	local definition = definitions[id]
	if snapshot.targetMode == "cursor" and isUnitTarget(id) and id ~= "cold_snap" then return false end
	if definition.kind == "spell" then
		return contains(settings.enabledSpells, id)
			or settings.castCraftedFirst and settings.preparedOutsideCombo and id ~= "ghost_walk" and id ~= "cataclysm"
				and contains(snapshot.invoke.invoked, canonicalSpell(id))
			or id == "sun_strike" and snapshot.hero.upgrades.scepterChoice ~= "exort" and contains(settings.enabledSpells, "cataclysm")
	end
	return settings.useItems and contains(settings.enabledItems, id)
end

function helpers.tornadoCatchTarget(snapshot)
	local direction = normalized2D(subtract(snapshot.cursor, snapshot.hero.position))
	local range = liveValue(snapshot, "tornado", "travel_distance", 1200 + 300 * snapshot.hero.orbLevels.wex)
	local radius = liveValue(snapshot, "tornado", "area_of_effect", 200)
	local best, nearest = nil, math.huge
	for _, enemy in ipairs(snapshot.enemies) do
		local offset = subtract(enemy.position, snapshot.hero.position)
		local along = dot2D(offset, direction)
		local across = length2D(subtract(offset, scale(direction, along)))
		local distance = distance2D(enemy.position, snapshot.cursor)
		if enemy.alive and enemy.visible and not enemy.dormant and not enemy.invulnerable and not enemy.debuffImmune
			and along > 0 and along <= range and across <= radius * 0.8
			and length2D(offset) <= snapshot.actions.cold_snap.castRange and distance < nearest
		then best, nearest = enemy, distance end
	end
	return best
end

function helpers.orderTornadoCatch(actions, snapshot)
	local result = arrayCopy(actions)
	if not contains(result, "tornado") or not contains(result, "cold_snap") then return result end
	local snapIndex, tornadoIndex
	for index, id in ipairs(result) do
		if id == "cold_snap" and not snapIndex then snapIndex = index end
		if id == "tornado" and not tornadoIndex then tornadoIndex = index end
	end
	-- An earlier Snap belongs to the opener; do not delay it past other setup spells.
	if snapIndex < tornadoIndex - 1 then return result end
	for index = math.min(snapIndex, tornadoIndex) + 1, math.max(snapIndex, tornadoIndex) - 1 do
		if result[index] == "item_refresher" then return result end
	end
	local target = snapshot.targetMode == "cursor" and helpers.tornadoCatchTarget(snapshot) or snapshot.target
	local after = target and helpers.canCatchTornado(snapshot, target)
	for index, id in ipairs(result) do if id == "cold_snap" then table.remove(result, index); break end end
	for index, id in ipairs(result) do if id == "tornado" then table.insert(result, index + (after and 1 or 0), "cold_snap"); break end end
	return result
end

function helpers.tornadoCatchTime(snapshot, origin, aim, commandAt, target)
	local direction = normalized2D(subtract(aim, origin))
	local offset = subtract(target.position, origin)
	local along = dot2D(offset, direction)
	local across = length2D(subtract(offset, scale(direction, along)))
	local radius = liveValue(snapshot, "tornado", "area_of_effect", 200) + NPC.GetHullRadius(target.entity)
	local distance = math.max(0, along - math.sqrt(math.max(0, radius * radius - across * across)))
	local tornado = resolveMechanics("tornado", snapshot, distance)
	local approach = math.max(0, -dot2D(target.velocity, direction))
	local hitAt = commandAt + tornado.castPoint + distance / math.max(1, tornado.projectileSpeed + approach) + snapshot.latency
	local freeze = liveValue(snapshot, "cold_snap", "freeze_duration", 0.4)
	local snapLead = snapshot.actions.cold_snap.castPoint + snapshot.latency
	local margin = cfg.timingSafety + snapshot.latencyJitter
	return math.max(commandAt + tornado.castPoint + cfg.commandGap, hitAt - freeze * 0.65 - snapLead), hitAt - snapLead - margin
end

function helpers.canCatchTornado(snapshot, target)
	local snap = snapshot.actions.cold_snap
	if not target or not target.alive or not target.visible or target.dormant or target.invulnerable
		or target.debuffImmune or distance2D(snapshot.hero.position, target.position) > snap.castRange
	then return false end
	-- Both spells must be in D/F: invoking either can evict the other or consume the entire flight window.
	if not contains(snapshot.invoke.invoked, "cold_snap") or not contains(snapshot.invoke.invoked, "tornado") then return false end
	local aim = snapshot.targetMode == "cursor" and snapshot.cursor or target.position
	local castAt, deadline = helpers.tornadoCatchTime(snapshot, snapshot.hero.position, aim, snapshot.now, target)
	local confirmation = snapshot.actions.tornado.castPoint + snapshot.latency * 2 + snapshot.latencyJitter + cfg.commandGap
	local turn = NPC.GetTimeToFace(snapshot.hero.entity, target.entity)
	return math.max(castAt, snapshot.now + confirmation) + turn <= deadline
end

local function targetNeedsNullifier(target)
	if target.spellBlocked then return true end
	local needles = {"aeon", "ghost", "glimmer", "windrun", "surge", "decrep", "lotus", "eul", "cyclone", "force", "pike", "flame_guard", "aphotic", "guardian_angel", "omniknight", "false_promise"}
	for name in pairs(target.modifiers) do
		for _, needle in ipairs(needles) do
			if name:find(needle, 1, true) then return true end
		end
	end
	return false
end

local function tacticalActions(source, snapshot, target, settings)
	local result = arrayCopy(source)
	if not settings.useItems or snapshot.targetMode == "cursor" then return result end
	if source[1] == "item_meteor_hammer" then return result end
	local function ready(id)
		local action = snapshot.actions[id]
		return contains(settings.enabledItems, id)
			and action and action.exists and action.learned and action.activated
			and action.canCast and action.cooldown <= 0.05
			and (action.castRange <= 0 or distance2D(snapshot.hero.position, target.position) <= action.castRange)
	end
	local insertion = 1
	local magicalPayload, groundPayload = ready("item_dagon"), false
	for index, id in ipairs(source) do
		local usable = dynamicActionEnabled(id, snapshot, settings) and actionAvailable(id, snapshot, false)
			and snapshot.actions[id].cooldown <= 0.05
		if usable then
			if id == "tornado" or id == "item_cyclone" or id == "cold_snap" then insertion = index + 1 end
			if contains({"chaos_meteor", "emp", "deafening_blast"}, id) then magicalPayload = true end
			if contains({"chaos_meteor", "emp", "sun_strike", "ice_wall", "item_meteor_hammer"}, id) then groundPayload = true end
		end
	end
	local function insert(id)
		if ready(id) and not contains(result, id) then
			table.insert(result, insertion, id)
			insertion = insertion + 1
		end
	end
	local distance = distance2D(snapshot.hero.position, target.position)
	if targetNeedsNullifier(target) then insert("item_nullifier") end
	local silence = ready("item_bloodthorn") and "item_bloodthorn" or "item_orchid"
	if not target.silenced and not target.modifiers.modifier_bloodthorn_debuff
		and not target.modifiers.modifier_orchid_malevolence_debuff
	then
		insert(silence)
	end
	local attacking = distance <= snapshot.hero.attackRange + 100
		and (snapshot.hero.alacrityActive or #snapshot.forgeSpirits > 0)
	if magicalPayload and not attacking and not contains(result, "item_bloodthorn")
		and not target.modifiers.modifier_bloodthorn_debuff
		and not target.modifiers.modifier_item_ethereal_blade_ethereal
	then
		insert("item_ethereal_blade")
	end
	if distance <= liveValue(snapshot, "item_shivas_guard", "blast_radius", 825) then insert("item_shivas_guard") end
	insert("item_dagon")
	if contains(result, "cold_snap") or target.healthRegen > 10 then
		local dot = ready("item_spirit_vessel") and "item_spirit_vessel"
			or ready("item_urn_of_shadows") and "item_urn_of_shadows" or nil
		if dot and not target.modifiers.modifier_item_spirit_vessel_damage
			and not target.modifiers.modifier_item_urn_damage
		then
			insert(dot)
		end
	end
	if target.attacking and not target.disarmed and target.disabledUntil <= snapshot.now then insert("item_heavens_halberd") end
	if target.moving and target.disabledUntil <= snapshot.now and distance > snapshot.hero.attackRange * 0.75 then
		insert(ready("item_disperser") and "item_disperser" or "item_diffusal_blade")
	end
	if not groundPayload then
		if ready("item_hurricane_pike") and (snapshot.hero.attacking or target.attacking) then
			insert("item_hurricane_pike")
		elseif ready("item_harpoon") and distance > snapshot.hero.attackRange * 0.8 then
			insert("item_harpoon")
		elseif distance > snapshot.hero.attackRange + 100
			and dot2D(normalized2D(target.facing), normalized2D(subtract(snapshot.hero.position, target.position))) > 0.7
		then
			insert("item_force_staff")
		end
	end
	return result
end

function helpers.hammerSetupAvailable(snapshot, target, actions)
	local mechanics = resolveMechanics("item_meteor_hammer", snapshot, 0)
	local required = mechanics.castPoint + mechanics.fixedDelay + snapshot.latency + cfg.timingSafety
	if target.disabledUntil - snapshot.now >= required then return true end
	if target.controlEndsAt - snapshot.now >= required - 0.09 then return true end
	for _, id in ipairs(actions) do
		if id == "tornado" or id == "item_cyclone" then
			if resolveMechanics(id, snapshot, 0).controlDuration >= required + cfg.commandGap - 0.09 then return true end
		end
	end
	return false
end

function helpers.dynamicActionUseful(id, snapshot, target, settings, accepted)
	local distance = distance2D(snapshot.hero.position, target.position)
	local tags = definitions[id].tags
	if target.debuffImmune and (tags.control or tags.debuff or tags.silence or definitions[id].damageType == "pure")
		and not snapshot.actions[id].piercesDebuffImmunity
	then
		return false
	end
	if settings.preserveControl and (id == "tornado" or id == "item_cyclone")
		and (contains(accepted, "tornado") or contains(accepted, "item_cyclone"))
	then
		return false
	end
	if settings.preserveControl and (id == "tornado" or id == "item_cyclone")
		and math.max(target.disabledUntil, target.controlEndsAt) > snapshot.now + 0.2
	then
		return false
	end
	if id == "item_meteor_hammer" then
		return snapshot.targetMode ~= "cursor" and not target.debuffImmune
			and distance <= snapshot.actions[id].castRange
			and helpers.hammerSetupAvailable(snapshot, target, accepted)
	end
	if id == "item_sheepstick" then return not target.hexed and target.disabledUntil <= snapshot.now + 0.2 end
	if id == "item_rod_of_atos" or id == "item_gungir" or id == "item_abyssal_blade" then
		return target.disabledUntil <= snapshot.now + 0.2
	end
	if id == "item_bloodthorn" or id == "item_orchid" then
		return not target.silenced and not target.modifiers.modifier_bloodthorn_debuff
			and not target.modifiers.modifier_orchid_malevolence_debuff
	end
	if id == "item_heavens_halberd" then return target.attacking and not target.disarmed end
	if id == "item_shivas_guard" then return distance <= liveValue(snapshot, id, "blast_radius", 825) end
	if id == "cold_snap" then return not target.modifiers.modifier_invoker_cold_snap and target.controlEndsAt <= snapshot.now end
	if id == "forge_spirit" then return #snapshot.forgeSpirits == 0 and distance <= snapshot.hero.attackRange + 250 end
	if id == "alacrity" then return not snapshot.hero.alacrityActive and distance <= snapshot.hero.attackRange + 100 end
	if id == "ice_wall" then return distance <= 550 or snapshot.hero.upgrades.scepterChoice == "quas" end
	return true
end

local function selectLinkenBreaker(snapshot, target, settings, mana, craftedOnly)
	for _, id in ipairs(settings.linkenPriority) do
		if dynamicActionEnabled(id, snapshot, settings) and canBreakSpellBlock(id) then
			local action = snapshot.actions[id]
			if action and action.exists and action.learned and action.activated and action.cooldown <= 0.05
				and mana + 0.001 >= action.manaCost
				and (definitions[id].kind ~= "item" or action.canCast)
				and (not craftedOnly or definitions[id].kind ~= "spell" or action.invoked)
			then
				return id
			end
		end
	end
	return nil
end

local function coherence(actions)
	local score = 0
	local function has(id) return contains(actions, id) end
	if has("cold_snap") and has("tornado") then score = score + 8 end
	if has("tornado") and (has("chaos_meteor") or has("emp") or has("sun_strike")) then score = score + 12 end
	if has("chaos_meteor") and has("deafening_blast") then score = score + 10 end
	if has("cold_snap") and (has("chaos_meteor") or has("forge_spirit")) then score = score + 8 end
	if has("item_ethereal_blade") and (has("item_dagon") or has("chaos_meteor") or has("deafening_blast")) then score = score + 11 end
	if has("item_shivas_guard") and (has("emp") or has("ice_wall") or has("cold_snap")) then score = score + 7 end
	if has("item_nullifier") and has("cold_snap") then score = score + 6 end
	if actions[1] and contains({"item_cyclone", "item_sheepstick", "item_rod_of_atos", "item_gungir"}, actions[1]) then score = score + 10 end
	return score
end

local function evaluateDynamicActions(source, snapshot, settings, craftedOnly)
	local target = snapshot.target
	if not target then
		target = {
			index = -1, alive = true, position = copyPoint(snapshot.cursor), velocity = {x = 0, y = 0, z = 0},
			facing = {x = 1, y = 0, z = 0}, moveSpeed = 0, motionConfidence = 1,
			movementDuration = 0, stableDuration = 0, idleDuration = math.huge,
			health = 2000, maxHealth = 2000, healthRegen = 0, mana = 1000, magicMultiplier = 0.75,
			invulnerable = false, magicImmune = false, debuffImmune = false,
			spellBlocked = false, disabledUntil = 0, controlEndsAt = 0, modifiers = {},
		}
	end
	local evalSnapshot = {}
	for key, value in pairs(snapshot) do evalSnapshot[key] = value end
	evalSnapshot.target = target
	local actions = {}
	local used = {}
	local mana = snapshot.hero.mana
	local damage, control, setup, reliabilitySum = 0, 0, 0, 0
	local spellBlockBroken = not target.spellBlocked
	local listed = tacticalActions(source, snapshot, target, settings)
	local needsUnitTarget = false
	for _, listedId in ipairs(listed) do
		if isUnitTarget(resolveSunAction(listedId, snapshot, settings)) then
			needsUnitTarget = true
			break
		end
	end
	if not spellBlockBroken and settings.breakLinkens and needsUnitTarget then
		local breaker = selectLinkenBreaker(snapshot, target, settings, mana, craftedOnly)
		if breaker then
			local mechanics = resolveMechanics(breaker, evalSnapshot, distance2D(snapshot.hero.position, target.position))
			actions[#actions + 1] = breaker
			used[definitions[breaker].sharedCooldown] = true
			mana = mana - mechanics.manaCost
			spellBlockBroken = true
			reliabilitySum = reliabilitySum + definitions[breaker].reliability
		end
	end

	for _, listedId in ipairs(listed) do
		local id = resolveSunAction(listedId, snapshot, settings, actions)
		local definition = definitions[id]
		local action = snapshot.actions[id]
		if dynamicActionEnabled(id, snapshot, settings)
			and not (snapshot.targetMode == "cursor" and id == "cold_snap" and not contains(listed, "tornado"))
			and not used[definition.sharedCooldown]
			and action and action.exists and action.cooldown <= 0.25
			and actionAvailable(id, snapshot, false)
			and helpers.dynamicActionUseful(id, snapshot, target, settings, actions)
			and (definition.kind ~= "item" or action.canCast)
			and (not craftedOnly or definition.kind ~= "spell" or action.invoked
				or id == "cold_snap" and contains(listed, "tornado")
				or id == "tornado" and contains(actions, "cold_snap"))
			and not (definition.targeting == "enemy" and not spellBlockBroken)
			and not (target.invulnerable and definition.targeting == "enemy" and target.controlEndsAt <= snapshot.now + 0.05)
			and not (target.magicImmune and definition.damageType == "magical")
			and not (target.debuffImmune and not action.piercesDebuffImmunity
				and (definition.tags.control or definition.tags.debuff or definition.tags.silence or definition.damageType == "pure"))
		then
			local mechanics = resolveMechanics(id, evalSnapshot, distance2D(snapshot.hero.position, target.position))
			if mana + 0.001 >= mechanics.manaCost then
				mana = mana - mechanics.manaCost
				actions[#actions + 1] = id
				used[definition.sharedCooldown] = true
				if canBreakSpellBlock(id) then spellBlockBroken = true end
				local effectiveDamage = mechanics.expectedDamage * (definition.damageType == "magical" and target.magicMultiplier or 1)
				damage = damage + effectiveDamage
				control = control + mechanics.controlDuration
				setup = setup + mechanics.setup
				local reliability = definition.reliability
				if definition.tags.delayed and control > 0.05 then reliability = reliability + 0.22 end
				reliabilitySum = reliabilitySum + clamp(reliability, 0.15, 1)
			end
		end
	end
	if #actions == 0 then return nil end
	local reliability = reliabilitySum / #actions
	local lethal = damage >= target.health and 22 or 0
	local score = coherence(actions) + lethal
		+ damage / math.max(80, target.maxHealth * 0.1)
		+ control * 5 + setup * 1.4 + reliability * 8 - math.max(0, #actions - 6) * 2
	return {
		actions = actions,
		score = score,
		expectedDamage = damage,
		control = control,
		manaRemaining = mana,
		name = "Dynamic combo",
	}
end

local function maybeAddRefresher(candidate, snapshot, settings)
	if not settings.useRefresher or not dynamicActionEnabled("item_refresher", snapshot, settings) then return candidate end
	local refresher = snapshot.actions.item_refresher
	local target = snapshot.target
	if not target or not refresher or not refresher.exists or not refresher.canCast
		or refresher.cooldown > 0.05 or #candidate.actions < 3 or candidate.expectedDamage >= target.health
	then
		return candidate
	end
	local payloads = {}
	for index, id in ipairs(candidate.actions) do
		if contains({"chaos_meteor", "sun_strike", "cataclysm", "deafening_blast", "emp"}, id) then
			local mechanics = resolveMechanics(id, snapshot, distance2D(snapshot.hero.position, target.position))
			local multiplier = definitions[id].damageType == "magical" and target.magicMultiplier or 1
			payloads[#payloads + 1] = {id = id, index = index, damage = mechanics.expectedDamage * multiplier}
		end
	end
	table.sort(payloads, function(left, right)
		if left.damage == right.damage then return left.index < right.index end
		return left.damage > right.damage
	end)
	local selected = {}
	for index = 1, math.min(2, #payloads) do selected[payloads[index].id] = true end
	local repeatActions = {}
	for _, id in ipairs(candidate.actions) do
		if selected[id] then repeatActions[#repeatActions + 1] = id end
	end
	if #repeatActions < 2 then return candidate end
	local extraMana = math.max(325, refresher.manaCost)
	local repeatDamage = 0
	for _, id in ipairs(repeatActions) do
		extraMana = extraMana + snapshot.actions[id].manaCost
		local definition = definitions[id]
		local mechanics = resolveMechanics(id, snapshot, distance2D(snapshot.hero.position, target.position))
		repeatDamage = repeatDamage + mechanics.expectedDamage
			* (definition.damageType == "magical" and target.magicMultiplier or 1)
	end
	local securesKill = candidate.expectedDamage < target.health
		and candidate.expectedDamage + repeatDamage >= target.health
	local highValue = candidate.control >= 1
		and target.health >= math.max(900, target.maxHealth * 0.4)
		and repeatDamage >= math.max(350, target.maxHealth * 0.2)
	if candidate.manaRemaining < extraMana or not securesKill and not highValue then
		return candidate
	end
	local result = {
		actions = arrayCopy(candidate.actions), score = candidate.score + 12,
		expectedDamage = candidate.expectedDamage + repeatDamage, control = candidate.control,
		manaRemaining = candidate.manaRemaining - extraMana, name = candidate.name,
	}
	result.actions[#result.actions + 1] = "item_refresher"
	for _, id in ipairs(repeatActions) do result.actions[#result.actions + 1] = id end
	return result
end

---Builds a live Dynamic combo from usable actions without fixed templates.
---@param snapshot InvokerSnapshot
---@param settings table
---@return table?
local function dynamicPlan(snapshot, settings)
	if not settings.enabled or snapshot.targetMode ~= "cursor" and not snapshot.target then return nil end
	local actions = {}
	local function add(id)
		if not contains(actions, id) then actions[#actions + 1] = id end
	end
	local function addFirstUsable(ids)
		for _, id in ipairs(ids) do
			if dynamicActionEnabled(id, snapshot, settings)
				and actionAvailable(id, snapshot, true)
				and (not snapshot.target or helpers.dynamicActionUseful(id, snapshot, snapshot.target, settings, actions))
				and (snapshot.targetMode == "cursor" or not snapshot.target
					or snapshot.actions[id].castRange <= 0
					or distance2D(snapshot.hero.position, snapshot.target.position) <= snapshot.actions[id].castRange)
			then
				add(id)
				return
			end
		end
	end

	if snapshot.targetMode == "cursor" then
		addFirstUsable({"item_gungir"})
		for _, id in ipairs({"tornado", "chaos_meteor", "sun_strike", "emp", "deafening_blast", "ice_wall"}) do add(id) end
		if helpers.tornadoCatchTarget(snapshot) then add("cold_snap"); actions = helpers.orderTornadoCatch(actions, snapshot) end
	else
		local target = snapshot.target
		if dynamicActionEnabled("item_meteor_hammer", snapshot, settings)
			and actionAvailable("item_meteor_hammer", snapshot, true)
			and helpers.dynamicActionUseful("item_meteor_hammer", snapshot, target, settings, {})
		then
			add("item_meteor_hammer")
		end
		if targetNeedsNullifier(target) then add("item_nullifier") end
		addFirstUsable({"item_sheepstick", "item_rod_of_atos", "item_gungir", "item_cyclone", "item_abyssal_blade"})
		for _, id in ipairs({"cold_snap", "tornado", "item_meteor_hammer", "forge_spirit", "alacrity", "chaos_meteor", "sun_strike", "emp", "deafening_blast", "ice_wall"}) do add(id) end
		actions = helpers.orderTornadoCatch(actions, snapshot)
	end

	local candidate = evaluateDynamicActions(actions, snapshot, settings, settings.castCraftedFirst)
	if not candidate and settings.castCraftedFirst then
		candidate = evaluateDynamicActions(actions, snapshot, settings, false)
	end
	return candidate and maybeAddRefresher(candidate, snapshot, settings) or nil
end

local function selectedComboActions(snapshot, settings, forceDynamic)
	if forceDynamic or settings.slot == "D" then
		if snapshot.targetMode ~= "cursor" and not snapshot.target then return nil, "No living visible target selected." end
		local candidate = dynamicPlan(snapshot, settings.dynamic)
		if not candidate then return nil, "No legal Dynamic sequence is available." end
		state.dynamicPreview = arrayCopy(candidate.actions)
		return candidate.actions, candidate.name
	end
	local custom = state.combos[settings.slot]
	if not custom or #custom == 0 then return nil, "Combo " .. settings.slot .. " is empty." end
	return arrayCopy(custom), "Combo " .. settings.slot
end

local function filterCombo(actions, snapshot)
	local result = {}
	local cooling = {}
	for _, listedId in ipairs(actions) do
		local id = listedId == "cataclysm" and snapshot.hero.upgrades.scepterChoice ~= "exort" and "sun_strike" or listedId
		local definition = definitions[id]
		local action = snapshot.actions[id]
		if action and action.exists
			and recipeAvailable(definition.recipe, snapshot.hero.orbLevels)
			and (not definition.requiresScepter or snapshot.hero.upgrades.scepterChoice == definition.requiresScepter)
			and action.cooldown <= 0.05
			and not cooling[definition.sharedCooldown]
			and (definition.kind ~= "item" or action.learned and action.activated and action.canCast)
		then
			result[#result + 1] = id
			if id == "item_refresher" then
				for group, priorId in pairs(cooling) do
					if definitions[priorId].resetsWithRefresher then cooling[group] = nil end
				end
			else
				cooling[definition.sharedCooldown] = id
			end
		end
	end
	return result
end

local function optimizeCustomSequence(actions)
	local result, segment = {}, {}
	local function flush()
		local setupIndex
		for index, id in ipairs(segment) do
			if id == "tornado" or id == "item_cyclone" then
				setupIndex = index
				break
			end
		end
		if setupIndex and setupIndex > 1 then
			local before, payload = {}, {}
			for index = 1, setupIndex - 1 do
				local id = segment[index]
				if contains({"chaos_meteor", "sun_strike", "cataclysm", "emp", "deafening_blast"}, id) then
					payload[#payload + 1] = id
				else
					before[#before + 1] = id
				end
			end
			local reordered = before
			reordered[#reordered + 1] = segment[setupIndex]
			for _, id in ipairs(payload) do reordered[#reordered + 1] = id end
			for index = setupIndex + 1, #segment do reordered[#reordered + 1] = segment[index] end
			segment = reordered
		end
		for _, id in ipairs(segment) do result[#result + 1] = id end
		segment = {}
	end
	for _, id in ipairs(actions) do
		if id == "item_refresher" then flush(); result[#result + 1] = id else segment[#segment + 1] = id end
	end
	flush()
	return result
end

local function resumeAfterLiveControl(actions, snapshot)
	if snapshot.targetMode == "cursor"
		or not snapshot.target
		or snapshot.target.controlEndsAt <= snapshot.now + 0.05
	then
		return actions
	end
	local result = {}
	for _, id in ipairs(actions) do
		if id ~= "tornado" and id ~= "item_cyclone" then result[#result + 1] = id end
	end
	return result
end

local function baseTargetPosition(snapshot, target, id, castAt)
	if snapshot.targetMode == "cursor" or not target then return copyPoint(snapshot.cursor) end
	if id == "chaos_meteor" then return predictMeteor(snapshot, target, castAt) end
	return predictIntercept(snapshot, id, target, castAt, target.motionConfidence).position
end

local function effectTravel(id, snapshot, position)
	local mechanics = resolveMechanics(id, snapshot, distance2D(snapshot.hero.position, position))
	local projectile = mechanics.projectileSpeed > 0
		and distance2D(snapshot.hero.position, position) / mechanics.projectileSpeed
		or 0
	return mechanics.fixedDelay + projectile
end

local function latencyLead(snapshot)
	return math.max(0, snapshot.latency + cfg.latencyOffset + cfg.timingSafety)
end

local function isDelayed(id)
	return definitions[id].tags.delayed or definitions[id].projectileSpeed > 0
end

local function isUntargetableAnchor(anchor)
	return anchor.actionId == "tornado" or anchor.actionId == "item_cyclone"
end

local function isImmobileControl(id)
	return id == "tornado"
		or id == "item_cyclone"
		or id == "item_rod_of_atos"
		or id == "item_gungir"
		or id == "item_abyssal_blade"
end

local function setupCommandDependency(id)
	return id == "tornado"
		or id == "item_cyclone"
		or id == "item_sheepstick"
		or id == "item_rod_of_atos"
		or id == "item_gungir"
end

local function canUseControlAnchor(id)
	if not isDelayed(id) then return id == "deafening_blast" or id == "ice_wall" end
	return id ~= "tornado" and id ~= "item_cyclone"
end

local function nextControlAnchor(anchors, sequenceIndex)
	local latestTargetable
	for index = #anchors, 1, -1 do
		local anchor = anchors[index]
		if anchor.sequenceIndex < sequenceIndex then
			if isUntargetableAnchor(anchor) then return anchor end
			if not latestTargetable then latestTargetable = anchor end
		end
	end
	return latestTargetable
end

local function isLandingPayload(id)
	return id == "chaos_meteor"
		or id == "sun_strike"
		or id == "cataclysm"
		or id == "emp"
		or id == "deafening_blast"
end

local function isSynchronizedPayload(id)
	return id == "chaos_meteor" or id == "sun_strike" or id == "cataclysm" or id == "emp"
end

local function landingSafety(id)
	if id == "emp" then return math.max(0.1, cfg.timingSafety + 0.04) end
	if id == "chaos_meteor" or id == "sun_strike" or id == "deafening_blast" then
		return math.max(0.09, cfg.timingSafety + 0.025)
	end
	return math.max(0.05, cfg.timingSafety * 0.8)
end

local function shiftPlannedAction(action, delta)
	if delta <= 0 then return end
	action.castAt = action.castAt + delta
	action.launchAt = action.launchAt + delta
	action.impactAt = action.impactAt + delta
	action.effectEndAt = action.effectEndAt + delta
end

local function assignSequenceOrder(actions)
	local ordered = arrayCopy(actions)
	table.sort(ordered, function(left, right) return left.sequenceIndex < right.sequenceIndex end)
	for index, action in ipairs(ordered) do action.commandIndex = index end
end

local function assignCommandOrder(actions)
	local commandIndex = 1
	local segment = {}
	local function flush()
		table.sort(segment, function(left, right)
			if left.castAt == right.castAt then return left.sequenceIndex < right.sequenceIndex end
			return left.castAt < right.castAt
		end)
		for index = #segment, 1, -1 do
			local action = segment[index]
			if action.catchTornado then
				for anchorIndex = 1, index - 1 do
					if segment[anchorIndex].uid == action.anchorUid then
						table.remove(segment, index)
						table.insert(segment, anchorIndex + 1, action)
						break
					end
				end
			end
		end
		for _, action in ipairs(segment) do
			action.commandIndex = commandIndex
			commandIndex = commandIndex + 1
		end
		segment = {}
	end
	for _, action in ipairs(actions) do
		if action.actionId == "item_refresher" or definitions[action.actionId].tags.channel then
			flush()
			action.commandIndex = commandIndex
			commandIndex = commandIndex + 1
		else
			segment[#segment + 1] = action
		end
	end
	flush()
end

local function applyInvokeConstraints(actions, snapshot, strict)
	local ordered = arrayCopy(actions)
	table.sort(ordered, function(left, right) return left.commandIndex < right.commandIndex end)
	local held = {}
	for _, id in ipairs(snapshot.invoke.invoked) do
		if #held < 2 then pushUnique(held, canonicalSpell(id)) end
	end
	local invokeReadyAt = snapshot.now + math.max(0, snapshot.invoke.cooldown)
	local invokeCycle = math.max(0.1, snapshot.invoke.cooldownLength)
	local invokeOrderDuration = math.max(0.16, snapshot.latency + snapshot.latencyJitter + 0.14)
	local commandReadyAt = snapshot.now
	local adjusted = false
	for _, action in ipairs(actions) do
		action.prepareAt = snapshot.now
		action.readyAt = snapshot.now
	end
	for index = 1, #ordered do
		local action = ordered[index]
		if not strict and isSynchronizedPayload(action.actionId) and not contains(held, canonicalSpell(action.actionId)) then
			local readyAt = math.max(commandReadyAt, invokeReadyAt) + invokeOrderDuration
			for futureIndex = index + 1, #ordered do
				local future = ordered[futureIndex]
				if not isSynchronizedPayload(future.actionId) or future.anchorUid ~= action.anchorUid then break end
				local spell = canonicalSpell(future.actionId)
				if contains(held, spell) and (spell == held[2] or future.castAt <= readyAt) then
					table.remove(ordered, futureIndex)
					table.insert(ordered, index, future)
					action = future
					break
				end
			end
		end
		action.commandIndex = index
		if action.actionId == "item_refresher" then
			local delta = math.max(0, commandReadyAt - action.castAt)
			if delta > 0 then
				shiftPlannedAction(action, delta)
				adjusted = true
			end
			commandReadyAt = action.castAt + math.max(cfg.commandGap, action.launchAt - action.castAt)
			invokeReadyAt = math.min(invokeReadyAt, commandReadyAt)
		else
			if isSpell(action.actionId) then
				local spell = canonicalSpell(action.actionId)
				if not contains(held, spell) then
					local prepareAt = math.max(commandReadyAt, invokeReadyAt)
					local readyAt = prepareAt + invokeOrderDuration
					action.prepareAt = prepareAt
					action.readyAt = readyAt
					if action.castAt < readyAt then
						shiftPlannedAction(action, readyAt - action.castAt)
						adjusted = true
					end
					local nextHeld = {spell}
					for _, current in ipairs(held) do
						if current ~= spell and #nextHeld < 2 then nextHeld[#nextHeld + 1] = current end
					end
					held = nextHeld
					invokeReadyAt = readyAt + invokeCycle
					commandReadyAt = readyAt
				end
			end
			if action.castAt < commandReadyAt then
				shiftPlannedAction(action, commandReadyAt - action.castAt)
				adjusted = true
			end
			commandReadyAt = action.castAt + math.max(cfg.commandGap, action.launchAt - action.castAt + action.channelTime)
		end
	end
	return adjusted
end

local function applySpatialSynergy(actions, snapshot)
	if snapshot.targetMode == "cursor" then return end
	local meteor, blast, wall
	for _, action in ipairs(actions) do
		if action.status ~= "skipped" and action.status ~= "failed" then
			if action.actionId == "chaos_meteor" and not meteor then meteor = action end
			if action.actionId == "deafening_blast" and not blast then blast = action end
			if action.actionId == "ice_wall" and not wall then wall = action end
		end
	end
	local blastForward = blast and normalized2D(subtract(blast.targetPosition, snapshot.hero.position)) or {x = 0, y = 0, z = 0}
	local blastDirection = length2D(blastForward) > 0.001 and blastForward or normalized2D(snapshot.hero.facing)
	local knockback = 172 + (clamp(snapshot.hero.orbLevels.quas, 1, 9) - 1) * 12.5
	local blastEndpoint = blast and add(blast.targetPosition, scale(blastDirection, knockback)) or nil
	if not wall or wall.anchored then return end
	if snapshot.hero.upgrades.scepterChoice == "quas" then return end
	if blast and blastEndpoint then
		wall.targetPosition = add(blastEndpoint, scale(blastDirection, 70))
	elseif meteor then
		local roll = normalized2D(subtract(meteor.targetPosition, snapshot.hero.position))
		wall.targetPosition = add(meteor.targetPosition, scale(roll, 190))
	end
end

local function applyPayloadSafety(actions, snapshot)
	local changed = false
	local ordered = arrayCopy(actions)
	table.sort(ordered, function(left, right) return left.sequenceIndex < right.sequenceIndex end)
	local segment = {}
	local function alignMeteorBlast()
		local meteors = {}
		for _, action in ipairs(segment) do
			if action.actionId == "chaos_meteor" then meteors[#meteors + 1] = action end
		end
		if #meteors == 0 then return end
		for _, blast in ipairs(segment) do
			if blast.actionId == "deafening_blast" then
				local meteor = meteors[1]
				for _, candidate in ipairs(meteors) do
					if math.abs(candidate.sequenceIndex - blast.sequenceIndex) < math.abs(meteor.sequenceIndex - blast.sequenceIndex) then
						meteor = candidate
					end
				end
				local enterRollAt = meteor.impactAt + math.max(0.055, cfg.timingSafety * 0.75)
				if blast.impactAt + 0.001 < enterRollAt then
					shiftPlannedAction(blast, enterRollAt - blast.impactAt)
					changed = true
				end
				blast.desiredImpactAt = math.max(blast.desiredImpactAt, enterRollAt)
				local roll = normalized2D(subtract(meteor.targetPosition, snapshot.hero.position))
				if length2D(roll) > 0.001 then
					local blastDistance = distance2D(snapshot.hero.position, blast.targetPosition)
					blast.targetPosition = add(snapshot.hero.position, scale(roll, blastDistance))
				end
			end
		end
	end
	for _, action in ipairs(ordered) do
		if action.actionId == "item_refresher" then
			alignMeteorBlast()
			segment = {}
		else
			segment[#segment + 1] = action
		end
	end
	alignMeteorBlast()

	local ethereal, nullifier
	for _, action in ipairs(ordered) do
		local definition = definitions[action.actionId]
		if action.actionId == "item_refresher" then ethereal, nullifier = nil, nil end
		local dependency = not definition.tags.setup and definition.damageType == "magical" and ethereal
			or definition.targeting == "enemy" and nullifier
			or nil
		if dependency and dependency ~= action then
			local safeImpact = dependency.impactAt + 0.025
			if action.impactAt + 0.001 < safeImpact then
				shiftPlannedAction(action, safeImpact - action.impactAt)
				action.desiredImpactAt = math.max(action.desiredImpactAt, action.impactAt)
				changed = true
			end
		end
		if action.actionId == "item_ethereal_blade" then ethereal = action end
		if action.actionId == "item_nullifier" then nullifier = action end
	end
	return changed
end

local function recomputeUnanchoredPositions(actions, snapshot)
	if snapshot.targetMode == "cursor" or not snapshot.target then return end
	for _, action in ipairs(actions) do
		local definition = definitions[action.actionId]
		if not action.anchorUid
			and action.status ~= "confirmed"
			and action.status ~= "skipped"
			and action.status ~= "failed"
			and (definition.targeting == "point" or definition.targeting == "directional")
		then
			action.targetPosition = baseTargetPosition(snapshot, snapshot.target, action.actionId, action.castAt)
		end
	end
end

local function findActionByUid(actions, uid)
	for _, action in ipairs(actions) do
		if action.uid == uid then return action end
	end
	return nil
end

local function findAnchorByUid(anchors, uid)
	for _, anchor in ipairs(anchors) do
		if anchor.uid == uid then return anchor end
	end
	return nil
end

local function recomputeAnchoredTimings(actions, anchors, snapshot)
	local lead = latencyLead(snapshot)
	local ordered = arrayCopy(actions)
	table.sort(ordered, function(left, right) return left.commandIndex < right.commandIndex end)
	for _, action in ipairs(ordered) do
		if action.anchorUid then
			local anchorAction = findActionByUid(actions, action.anchorUid)
			local seededAnchor = findAnchorByUid(anchors, action.anchorUid)
			local liveAnchor = not anchorAction
				and action.anchorUid:sub(1, 13) == "live-control:"
				and snapshot.target
				and snapshot.target.controlEndsAt > snapshot.now
				and {
					effectEndAt = snapshot.target.controlEndsAt,
					targetPosition = snapshot.target.controlPosition or snapshot.target.position,
				}
				or nil
			local anchorEnd = anchorAction and anchorAction.effectEndAt
				or seededAnchor and seededAnchor.endAt
				or liveAnchor and liveAnchor.effectEndAt
			local anchorPosition = anchorAction and anchorAction.targetPosition
				or seededAnchor and seededAnchor.position
				or liveAnchor and liveAnchor.targetPosition
			if snapshot.targetMode == "cursor" and anchorPosition then anchorPosition = snapshot.cursor end
			if anchorEnd and anchorPosition then
				local mechanics = resolveMechanics(action.actionId, snapshot, distance2D(snapshot.hero.position, anchorPosition))
				local travel = effectTravel(action.actionId, snapshot, anchorPosition)
				local desiredImpact = anchorEnd + landingSafety(action.actionId)
				local untargetable = anchorAction and (anchorAction.actionId == "tornado" or anchorAction.actionId == "item_cyclone")
					or seededAnchor and isUntargetableAnchor(seededAnchor)
					or liveAnchor ~= nil
				local desiredCast = untargetable
					and desiredImpact - mechanics.castPoint - travel - lead
					or (anchorAction and anchorAction.castAt or snapshot.now) + cfg.commandGap
				if action.actionId == "ice_wall" and untargetable then
					desiredCast = (anchorAction and anchorAction.castAt or snapshot.now) + cfg.commandGap
				end
				local afterAnchorOrder = anchorAction and setupCommandDependency(anchorAction.actionId)
					and anchorAction.castAt + cfg.commandGap
					or snapshot.now
				local targetableCast = untargetable and definitions[action.actionId].targeting == "enemy"
					and anchorEnd + math.max(0.045, cfg.timingSafety)
					or math.max(afterAnchorOrder, desiredCast)
				if action.catchTornado and anchorAction then
					for _, enemy in ipairs(snapshot.enemies) do
						if enemy.index == action.targetIndex then
							targetableCast, action.catchDeadline = helpers.tornadoCatchTime(snapshot,
								anchorAction.castOrigin, anchorAction.targetPosition, anchorAction.castAt, enemy)
							break
						end
					end
				end
				if targetableCast + action.tolerance >= action.readyAt and targetableCast + action.tolerance >= snapshot.now then
					local duration = action.effectEndAt - action.impactAt
					action.castAt = math.max(action.readyAt, targetableCast)
					action.launchAt = action.castAt + mechanics.castPoint
					action.impactAt = action.castAt + mechanics.castPoint + travel + lead
					action.effectEndAt = action.impactAt + duration
					action.desiredImpactAt = untargetable and desiredImpact or action.impactAt
					action.targetPosition = copyPoint(anchorPosition)
				else
					action.desiredImpactAt = desiredImpact
				end
			end
		end
	end
end

local function scheduleSignature(actions)
	local ordered = arrayCopy(actions)
	table.sort(ordered, function(left, right) return left.sequenceIndex < right.sequenceIndex end)
	local parts = {}
	for _, action in ipairs(ordered) do
		parts[#parts + 1] = ("%s:%d:%.4f:%.4f:%.4f:%.4f"):format(
			action.uid,
			action.commandIndex,
			action.prepareAt,
			action.readyAt,
			action.castAt,
			action.effectEndAt
		)
	end
	return table.concat(parts, "|")
end

local function stabilizeSchedule(actions, anchors, snapshot)
	local maxPasses = math.max(2, #actions + 2)
	for _ = 1, maxPasses do
		assignCommandOrder(actions)
		local before = scheduleSignature(actions)
		local invokeAdjusted = applyInvokeConstraints(actions, snapshot)
		recomputeUnanchoredPositions(actions, snapshot)
		if invokeAdjusted then recomputeAnchoredTimings(actions, anchors, snapshot) end
		local synergyAdjusted = applyPayloadSafety(actions, snapshot)
		applySpatialSynergy(actions, snapshot)
		assignCommandOrder(actions)
		if not synergyAdjusted and scheduleSignature(actions) == before then break end
	end
	applyInvokeConstraints(actions, snapshot)
	recomputeUnanchoredPositions(actions, snapshot)
	recomputeAnchoredTimings(actions, anchors, snapshot)
	local payloadAdjusted = applyPayloadSafety(actions, snapshot)
	applySpatialSynergy(actions, snapshot)
	if payloadAdjusted then
		assignCommandOrder(actions)
		applyInvokeConstraints(actions, snapshot)
		recomputeUnanchoredPositions(actions, snapshot)
		recomputeAnchoredTimings(actions, anchors, snapshot)
		applyPayloadSafety(actions, snapshot)
		applySpatialSynergy(actions, snapshot)
	end
	applyInvokeConstraints(actions, snapshot)
	recomputeUnanchoredPositions(actions, snapshot)
	recomputeAnchoredTimings(actions, anchors, snapshot)
	applyPayloadSafety(actions, snapshot)
	applySpatialSynergy(actions, snapshot)
	applyInvokeConstraints(actions, snapshot)
end

local function impactPosition(snapshot, target, id, seconds, fallback, anchor)
	if snapshot.targetMode == "cursor" then return copyPoint(snapshot.cursor) end
	if anchor then
		if id == "chaos_meteor" and target then
			local roll = normalized2D(subtract(anchor.position, snapshot.hero.position))
			local fallbackRoll = length2D(roll) > 0 and roll or normalized2D(target.facing)
			return add(anchor.position, scale(fallbackRoll, -math.min(110, 35 + length2D(target.velocity) * 0.18)))
		end
		return copyPoint(anchor.position)
	end
	if not target then return copyPoint(fallback) end
	if target.invulnerable then return copyPoint(target.position) end
	if id == "emp" then return helpers.predictEMP(snapshot, target, seconds) end
	if id == "chaos_meteor" then
		return predictMeteor(snapshot, target, snapshot.now + math.max(0, seconds - effectTravel(id, snapshot, fallback)))
	end
	return predictTarget(target, seconds, target.motionConfidence, math.max(0, target.disabledUntil - snapshot.now))
end

---Schedules a combo into ordered Invoke, cast, impact, and control timings.
---@param actions string[]
---@param snapshot InvokerSnapshot
---@param source "custom"|"dynamic"
---@param slot string
---@param seedControls? PlannedAction[]
---@return table
local function buildPlan(actions, snapshot, source, slot, seedControls)
	local planned = {}
	local anchors = {}
	local strict = source == "custom" and state.comboStrict and state.comboStrict[slot] == true

	local target = snapshot.target
	if snapshot.targetMode == "cursor" then target = nil end
	local catchTarget = snapshot.targetMode == "cursor" and contains(actions, "tornado") and contains(actions, "cold_snap")
		and helpers.tornadoCatchTarget(snapshot) or target
	local commandCursor = snapshot.now + 0.02
	local lead = latencyLead(snapshot)
	local synchronized = {}
	for _, id in ipairs(actions) do
		if isSynchronizedPayload(id) then synchronized[#synchronized + 1] = id end
	end
	local payloadImpactAt
	if not strict and target and #synchronized >= 2 then
		local maximum = 0
		for index, id in ipairs(synchronized) do
			local offset = (index - 1) * cfg.commandGap
			local provisional = baseTargetPosition(snapshot, target, id, snapshot.now + offset)
			local mechanics = resolveMechanics(id, snapshot, distance2D(snapshot.hero.position, provisional))
			maximum = math.max(maximum, offset + mechanics.castPoint + effectTravel(id, snapshot, provisional))
		end
		payloadImpactAt = snapshot.now + 0.02 + lead + maximum
	end
	for _, seed in ipairs(seedControls or {}) do
		if seed.status == "confirmed"
			and seed.effectEndAt > snapshot.now + 0.05
			and isImmobileControl(seed.actionId)
		then
			anchors[#anchors + 1] = {
				uid = seed.uid,
				actionId = seed.actionId,
				impactAt = seed.impactAt,
				endAt = seed.effectEndAt,
				position = copyPoint(seed.targetPosition),
				sequenceIndex = 0,
				commandAt = seed.castAt,
			}
		end
	end
	if target and target.controlEndsAt > snapshot.now + 0.05 then
		anchors[#anchors + 1] = {
			uid = ("live-control:%d:%.3f"):format(target.index, target.controlEndsAt),
			actionId = target.modifiers.modifier_invoker_tornado and "tornado" or "item_cyclone",
			impactAt = snapshot.now,
			endAt = target.controlEndsAt,
			position = copyPoint(target.controlPosition or target.position),
			sequenceIndex = -1,
			commandAt = nil,
		}
	end

	for sequenceIndex, id in ipairs(actions) do
		local definition = definitions[id]
		local targetPosition = baseTargetPosition(snapshot, target, id, commandCursor)
		local mechanics = resolveMechanics(id, snapshot, distance2D(snapshot.hero.position, targetPosition))
		local travel = effectTravel(id, snapshot, targetPosition)
		local uid = ("%d:%s:%.3f"):format(sequenceIndex, id, snapshot.now)
		local desiredImpactAt = commandCursor + mechanics.castPoint + travel + lead
		local castAt = commandCursor
		local anchorUid
		local precedingControl = not strict and (target or id == "cold_snap" and catchTarget) and nextControlAnchor(anchors, sequenceIndex) or nil
		local anchor = precedingControl
			and (canUseControlAnchor(id) or definition.targeting == "enemy" and isUntargetableAnchor(precedingControl))
			and precedingControl
			or nil
		local catchTornado = id == "cold_snap" and anchor and anchor.actionId == "tornado"
			and anchor.commandAt ~= nil and catchTarget ~= nil
		local catchDeadline
		if anchor then
			local epsilon = landingSafety(id)
			local afterAnchorOrder = anchor.commandAt and anchor.commandAt + cfg.commandGap or snapshot.now + 0.01
			anchorUid = anchor.uid
			if isUntargetableAnchor(anchor) then
				desiredImpactAt = anchor.endAt + epsilon
				castAt = math.max(afterAnchorOrder, desiredImpactAt - mechanics.castPoint - travel - lead)
				if id == "ice_wall" then castAt = afterAnchorOrder end
			else
				castAt = math.max(commandCursor, afterAnchorOrder)
				desiredImpactAt = castAt + mechanics.castPoint + travel + lead
			end
		end
		if not anchor and payloadImpactAt and isSynchronizedPayload(id) then
			desiredImpactAt = payloadImpactAt
			castAt = math.max(snapshot.now + 0.02, desiredImpactAt - mechanics.castPoint - travel - lead)
		end
		if anchor and isUntargetableAnchor(anchor) and definition.targeting == "enemy" then
			castAt = math.max(castAt, anchor.endAt + math.max(0.045, cfg.timingSafety))
			desiredImpactAt = castAt + mechanics.castPoint + travel + lead
		end
		if catchTornado then
			castAt, catchDeadline = helpers.tornadoCatchTime(snapshot, snapshot.hero.position, anchor.position, anchor.commandAt, catchTarget)
			desiredImpactAt = castAt + mechanics.castPoint + lead
		end
		local amplifier, nullifier
		for index = #planned, 1, -1 do
			local prior = planned[index]
			if not amplifier and prior.actionId == "item_ethereal_blade" then amplifier = prior end
			if not nullifier and prior.actionId == "item_nullifier" then nullifier = prior end
		end
		if not strict and amplifier and definition.damageType == "magical" and not definition.tags.setup then
			castAt = math.max(castAt, amplifier.impactAt + 0.035 - mechanics.castPoint - travel - lead)
			desiredImpactAt = math.max(desiredImpactAt, castAt + mechanics.castPoint + travel + lead)
		end
		if not strict and nullifier and definition.targeting == "enemy" and id ~= "item_nullifier" then
			castAt = math.max(castAt, nullifier.impactAt + 0.025)
			desiredImpactAt = math.max(desiredImpactAt, castAt + mechanics.castPoint + travel + lead)
		end
		local impactAt = castAt + mechanics.castPoint + travel + lead
		if not strict and precedingControl and (id == "forge_spirit" or id == "alacrity") then
			castAt = math.max(snapshot.now + 0.02, (precedingControl.commandAt or snapshot.now) + cfg.commandGap)
			impactAt = castAt + mechanics.castPoint + travel + lead
			desiredImpactAt = impactAt
		end
		local predictedPosition = impactPosition(snapshot, target, id, impactAt - snapshot.now, targetPosition, anchor)
		local prepareLead = definition.kind == "spell" and not snapshot.actions[id].invoked
			and math.max(0.12, snapshot.invoke.cooldown) + 0.2
			or 0
		local unitTarget = id == "cold_snap" and catchTarget or target
		local entry = {
			uid = uid,
			actionId = id,
			sequenceIndex = sequenceIndex,
			commandIndex = sequenceIndex,
			prepareAt = math.max(snapshot.now, castAt - prepareLead),
			readyAt = snapshot.now,
			castAt = castAt,
			launchAt = castAt + mechanics.castPoint,
			channelTime = mechanics.channelTime,
			impactAt = impactAt,
			effectEndAt = impactAt + math.max(mechanics.controlDuration, mechanics.duration),
			desiredImpactAt = desiredImpactAt,
			tolerance = (id == "sun_strike" or id == "emp") and 0.16 or 0.12,
			targetIndex = definition.targeting == "enemy" and unitTarget and unitTarget.index or nil,
			catchTornado = catchTornado,
			snapBeforeTornado = not strict and id == "cold_snap" and actions[sequenceIndex + 1] == "tornado",
			catchDeadline = catchDeadline,
			castOrigin = copyPoint(snapshot.hero.position),
			targetPosition = predictedPosition,
			anchorUid = anchorUid,
			anchored = anchor ~= nil,
			status = "pending",
			attempts = 0,
			movingForRange = false,
		}
		planned[#planned + 1] = entry
		if mechanics.controlDuration > 0.05
			and isImmobileControl(id)
		then
			anchors[#anchors + 1] = {
				uid = uid,
				actionId = id,
				impactAt = impactAt,
				endAt = impactAt + mechanics.controlDuration,
				position = copyPoint(predictedPosition),
				sequenceIndex = sequenceIndex,
				commandAt = castAt,
			}
		end
		commandCursor = math.max(commandCursor + cfg.commandGap, castAt + mechanics.castPoint + mechanics.channelTime + cfg.commandGap)
	end
	if strict then
		applyInvokeConstraints(planned, snapshot, true)
		recomputeUnanchoredPositions(planned, snapshot)
	else
		applySpatialSynergy(planned, snapshot)
		stabilizeSchedule(planned, anchors, snapshot)
	end
	return {
		source = source,
		strict = strict,
		slot = slot,
		targetMode = snapshot.targetMode,
		targetIndex = target and target.index or nil,
		cursor = copyPoint(snapshot.cursor),
		actions = planned,
		startedAt = snapshot.now,
		revision = 0,
	}
end

local function abortPlan(reason)
	state.plan = nil
	state.pendingCast = nil
	state.invokeSequence = nil
	state.orbSequence = nil
	setStatus("aborted", reason)
end

function helpers.wallExposure(snapshot, target, action, mechanics)
	local slow = math.abs(liveValue(snapshot, "ice_wall", "slow", -20 * snapshot.hero.orbLevels.quas)) / 100
	local alreadySlowed = target.modifiers.modifier_invoker_ice_wall_slow_debuff ~= nil
	local speed = math.max(100, target.moveSpeed * (alreadySlowed and 1 or math.max(0, 1 - slow)))
	local locked = math.max(0, target.disabledUntil - action.impactAt)
	local crossingTime = mechanics.radius / speed
	local exposure = locked + crossingTime
	local rootDelay = liveValue(snapshot, "ice_wall", "root_delay", 0)
	if snapshot.hero.upgrades.scepterChoice == "quas" and rootDelay > 0 and exposure >= rootDelay then
		exposure = exposure + liveValue(snapshot, "ice_wall", "root_duration", 2.5)
	end
	return math.min(mechanics.duration, exposure)
end

local function nextPlanAction()
	if not state.plan then return nil end
	local nextAction
	for _, action in ipairs(state.plan.actions) do
		if action.status == "pending" or action.status == "preparing" or action.status == "ready" then
			if not nextAction or action.commandIndex < nextAction.commandIndex then nextAction = action end
		end
	end
	return nextAction
end

local function captureAimReference(snapshot)
	local cursorMode = snapshot.targetMode == "cursor"
	state.lastTargetPosition = copyPoint(not cursorMode and snapshot.target and snapshot.target.position or snapshot.cursor)
	state.lastTargetVelocity = not cursorMode and snapshot.target and copyPoint(snapshot.target.velocity) or {x = 0, y = 0, z = 0}
	state.lastTargetMoving = not cursorMode and snapshot.target ~= nil
		and snapshot.target.movementDuration > 0.05
		and length2D(snapshot.target.velocity) > 18
end

local function replanCurrentPlan(snapshot)
	local plan = state.plan
	if not plan then return false end
	local ordered = arrayCopy(plan.actions)
	table.sort(ordered, function(left, right) return left.sequenceIndex < right.sequenceIndex end)
	local pending, completed = {}, {}
	for _, action in ipairs(ordered) do
		if action.status == "pending" or action.status == "preparing" or action.status == "ready" then
			pending[#pending + 1] = action
		elseif action.status == "confirmed" or action.status == "skipped" then
			completed[#completed + 1] = action
		end
	end
	if #pending == 0 then return false end
	local ids = {}
	for _, action in ipairs(pending) do ids[#ids + 1] = action.actionId end
	local rebuilt = buildPlan(ids, snapshot, plan.source, plan.slot, completed)
	local uidMap = {}
	for index, action in ipairs(rebuilt.actions) do
		local original = pending[index]
		if original then uidMap[action.uid] = original.uid end
	end
	for index, action in ipairs(rebuilt.actions) do
		local original = pending[index]
		if original then
			action.sequenceIndex = original.sequenceIndex
			action.uid = original.uid
			action.attempts = original.attempts
			action.moveDeadline = original.moveDeadline
			action.waitDeadline = original.waitDeadline
			action.preparedOnly = original.preparedOnly
		end
		if action.anchorUid and uidMap[action.anchorUid] then action.anchorUid = uidMap[action.anchorUid] end
	end
	for _, action in ipairs(completed) do rebuilt.actions[#rebuilt.actions + 1] = action end
	table.sort(rebuilt.actions, function(left, right) return left.sequenceIndex < right.sequenceIndex end)
	if rebuilt.strict then assignSequenceOrder(rebuilt.actions) else assignCommandOrder(rebuilt.actions) end
	rebuilt.revision = plan.revision + 1
	state.plan = rebuilt
	captureAimReference(snapshot)
	return true
end

local function tryDynamicReplacement(snapshot, settings)
	local plan = state.plan
	if not plan or plan.source ~= "dynamic" or snapshot.now < state.nextDynamicReplanAt then return false end
	state.nextDynamicReplanAt = snapshot.now + 0.18
	local replacement = dynamicPlan(snapshot, settings.dynamic)
	if not replacement or #replacement.actions == 0 then return false end

	local completed, confirmed = {}, {}
	for _, action in ipairs(plan.actions) do
		if action.status == "confirmed" or action.status == "skipped" then
			completed[#completed + 1] = action
			if action.status == "confirmed" then confirmed[#confirmed + 1] = action end
		end
	end
	local blocked = {}
	for _, action in ipairs(confirmed) do
		if action.actionId == "item_refresher" then
			blocked = {}
		else
			blocked[definitions[action.actionId].sharedCooldown] = action.actionId
		end
	end
	local filtered = {}
	for _, id in ipairs(replacement.actions) do
		if id == "item_refresher" then
			filtered[#filtered + 1] = id
			for group, priorId in pairs(blocked) do
				if definitions[priorId].resetsWithRefresher then blocked[group] = nil end
			end
		else
			local group = definitions[id].sharedCooldown
			if not blocked[group] then
				filtered[#filtered + 1] = id
				blocked[group] = id
			end
		end
	end
	if #filtered == 0 then return false end

	local rebuilt = buildPlan(filtered, snapshot, "dynamic", "D", completed)
	helpers.markPreparedExtras(rebuilt, settings)
	local completedOffset = #completed
	for _, action in ipairs(rebuilt.actions) do
		action.sequenceIndex = action.sequenceIndex + completedOffset
		action.commandIndex = action.commandIndex + completedOffset
	end
	for _, action in ipairs(completed) do rebuilt.actions[#rebuilt.actions + 1] = action end
	table.sort(rebuilt.actions, function(left, right) return left.sequenceIndex < right.sequenceIndex end)
	rebuilt.revision = plan.revision + 1
	state.plan = rebuilt
	state.dynamicPreview = arrayCopy(filtered)
	captureAimReference(snapshot)
	setStatus("preparing", "Dynamic sequence recalculated from the current combat state.")
	logDebug("PLAN", "Dynamic replacement: " .. table.concat(filtered, " -> "))
	return true
end

local function replanAfterSkip(snapshot)
	if state.plan and nextPlanAction() then replanCurrentPlan(snapshot) end
end

local function shouldRefreshGroundAim(action, snapshot)
	if not action or action.anchorUid or snapshot.targetMode == "cursor" or not snapshot.target then return false end
	local targeting = definitions[action.actionId].targeting
	if targeting ~= "point" and targeting ~= "directional" then return false end
	if distance2D(snapshot.target.position, state.lastTargetPosition) >= cfg.groundAimReplanDistance then return true end
	local speed = length2D(snapshot.target.velocity)
	local moving = snapshot.target.movementDuration > 0.05 and speed > 18
	if moving ~= state.lastTargetMoving then return true end
	if not moving then return false end
	local referenceSpeed = length2D(state.lastTargetVelocity)
	if math.abs(speed - referenceSpeed) >= cfg.groundAimSpeedDelta then return true end
	return referenceSpeed > 18
		and dot2D(normalized2D(snapshot.target.velocity), normalized2D(state.lastTargetVelocity)) < math.cos(math.pi / 6)
end

local function reactivePlanCheck(snapshot, settings)
	if not state.plan or snapshot.now - state.lastPlanCheck < cfg.planRecalcInterval then return end
	state.lastPlanCheck = snapshot.now
	local targetPosition = snapshot.targetMode ~= "cursor" and snapshot.target and snapshot.target.position or snapshot.cursor
	local moved = distance2D(targetPosition, state.lastTargetPosition)
	local nextAction = nextPlanAction()
	if nextAction and nextAction.movingForRange then
		captureAimReference(snapshot)
		return
	end
	local timingDrift = nextAction ~= nil
		and snapshot.now > nextAction.castAt + nextAction.tolerance
		and nextAction.status ~= "issued"
	local observedControl = snapshot.target ~= nil and snapshot.target.controlEndsAt > snapshot.now + 0.05
	local anchorUid = nextAction and nextAction.anchorUid or nil
	local snapToObserved = observedControl and anchorUid ~= nil and anchorUid:sub(1, 13) ~= "live-control:"
	local predictedAnchor = false
	for _, action in ipairs(state.plan.actions) do
		if action.status == "confirmed"
			and action.effectEndAt > snapshot.now
			and (action.actionId == "tornado" or action.actionId == "item_cyclone")
		then
			predictedAnchor = true
			break
		end
	end
	if not predictedAnchor and shouldRefreshGroundAim(nextAction, snapshot) then
		if replanCurrentPlan(snapshot) then
			setStatus("preparing", "Target movement changed; delayed ground aim refreshed before cast.")
		end
		return
	end
	local movementInvalid = moved >= cfg.targetReplanDistance
		and not predictedAnchor
		and nextAction ~= nil
		and nextAction.anchorUid == nil
	local needsReplan = movementInvalid or timingDrift and not predictedAnchor or snapToObserved
	if movementInvalid and not isInvoking() and not (nextAction and (nextAction.catchTornado or nextAction.snapBeforeTornado))
		and tryDynamicReplacement(snapshot, settings) then return end
	if needsReplan and replanCurrentPlan(snapshot) then
		local reason = snapToObserved and "Observed control duration replaced the predicted landing time."
			or movementInvalid and "Target movement changed the plan."
			or "Timing drift corrected."
		setStatus("preparing", reason)
	end
end

local function findEnemy(snapshot, index)
	if not index then return snapshot.target end
	for _, enemy in ipairs(snapshot.enemies) do
		if enemy.index == index then return enemy end
	end
	return nil
end

local function moveTo(position)
	local now = state.now
	local previous = state.moveOrder
	if previous and now >= previous.at and (now - previous.at < 0.25
		or now - previous.at < 1 and distance2D(previous.position, position) < 45)
	then return false end
	state.moveOrder = {position = copyPoint(position), at = now}
	issueOrder(function()
		NPC.MoveTo(state.hero, toVector(position), false, false, false, true, "invoker_auto", false)
	end)
	return true
end

local function attackTarget(target, includeHero)
	if not Entity.IsAlive(target) or Entity.IsDormant(target) or not NPC.IsVisible(target)
		or NPC.HasState(target, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE)
		or NPC.HasState(target, Enum.ModifierState.MODIFIER_STATE_ATTACK_IMMUNE)
	then
		return
	end
	issueOrder(function()
		if includeHero then
			state.moveOrder = nil
			Player.AttackTarget(state.player, state.hero, target, false, false, true, "invoker_auto", false)
		end
		for _, unit in ipairs(state.snapshot.forgeSpirits) do
			if Entity.IsAlive(unit) then
				Player.AttackTarget(state.player, unit, target, false, false, true, "invoker_auto", false)
			end
		end
	end)
end

function helpers.comboMovePosition(snapshot, direction)
	if direction == "cursor" then return snapshot.cursor end
	local target = snapshot.target
	local distance = distance2D(snapshot.hero.position, target.position)
	local desired = math.max(100, snapshot.hero.attackRange - 50)
	if distance >= desired - 40 and distance <= snapshot.hero.attackRange then return nil end
	local away = normalized2D(subtract(snapshot.hero.position, target.position))
	if length2D(away) < 0.01 then away = scale(snapshot.hero.facing, -1) end
	return add(target.position, scale(away, desired))
end

function helpers.updateComboCombat(snapshot, settings)
	local target = snapshot.target
	local allowed = helpers.comboAttackAllowed(snapshot)
	if not settings.kiting and settings.moveDirection ~= "cursor" then
		state.kiteAttack = nil
		if snapshot.now >= state.nextAttackAt then
			attackTarget(target.entity, allowed)
			state.nextAttackAt = snapshot.now + 0.32
		end
		return
	end
	if snapshot.now >= state.nextAttackAt then
		attackTarget(target.entity, false)
		state.nextAttackAt = snapshot.now + 0.32
	end
	if not allowed or snapshot.hero.channeling or snapshot.hero.stunned then return end
	if not target.alive or target.dormant or not target.visible then state.kiteAttack = nil; return end
	local attack = state.kiteAttack
	if attack and (attack.targetIndex ~= target.index or snapshot.now >= attack.deadline) then
		state.kiteAttack = nil
		attack = nil
	end
	-- Wait for the projectile, not an assumed windup duration. A missing launch has a bounded retry.
	if attack and not attack.launched then return end
	local distance = distance2D(snapshot.hero.position, target.position)
	if not target.invulnerable and not NPC.HasState(target.entity, Enum.ModifierState.MODIFIER_STATE_ATTACK_IMMUNE)
		and not NPC.HasState(snapshot.hero.entity, Enum.ModifierState.MODIFIER_STATE_DISARMED)
		and distance <= snapshot.hero.attackRange
		and snapshot.now >= (state.nextKiteAttackAt or 0)
	then
		local windup = NPC.GetAttackAnimPoint(snapshot.hero.entity) or 0.4
		local turn = NPC.GetTimeToFacePosition(snapshot.hero.entity, toVector(target.position))
		state.kiteAttack = {targetIndex = target.index, windup = windup,
			deadline = snapshot.now + turn + windup + snapshot.latency * 2 + 0.6}
		state.nextKiteAttackAt = snapshot.now + math.max(0.1, NPC.GetAttackTime(snapshot.hero.entity))
		attackTarget(target.entity, true)
		return
	end
	local destination = helpers.comboMovePosition(snapshot, settings.moveDirection)
	if destination and distance2D(snapshot.hero.position, destination) > 45 then moveTo(destination) end
end

function helpers.onComboProjectile(data)
	local attack = state.kiteAttack
	if not attack or not data.isAttack or not data.source or not data.target or not state.hero
		or Entity.GetIndex(data.source) ~= Entity.GetIndex(state.hero)
		or Entity.GetIndex(data.target) ~= attack.targetIndex
	then return end
	local now = GameRules.GetGameTime()
	attack.launched = true
	state.nextKiteAttackAt = math.max(state.nextKiteAttackAt or now,
		now + math.max(0.05, NPC.GetAttackTime(state.hero) - attack.windup))
	attack.deadline = state.nextKiteAttackAt + 0.5
end

local function iceWallStats(snapshot)
	local specials = snapshot.actions.ice_wall.specials
	local totalLength = specials.wall_total_length > 0 and specials.wall_total_length or 1200
	local vectorRange = specials.vector_cast_range >= 0 and specials.vector_cast_range or 0
	return {
		placeDistance = specials.wall_place_distance > 0 and specials.wall_place_distance or 200,
		totalLength = totalLength,
		vectorRange = vectorRange,
		floeLength = math.min(vectorRange > 0 and vectorRange or totalLength * 0.5, totalLength * 0.25),
	}
end

local function normalizedForward(value)
	local normalized = normalized2D(value)
	if math.abs(normalized.x) + math.abs(normalized.y) <= 0.0001 then return {x = 1, y = 0, z = 0} end
	return normalized
end

local function rotate2D(value, radians)
	local cosine, sine = math.cos(radians), math.sin(radians)
	return {x = value.x * cosine - value.y * sine, y = value.x * sine + value.y * cosine, z = 0}
end

local function planIceWall(heroPosition, heroFacing, targetPosition, stats)
	local currentForward = normalizedForward(heroFacing)
	local delta = subtract(targetPosition, heroPosition)
	local distance = distance2D(heroPosition, targetPosition)
	local halfLength = stats.totalLength * 0.5
	local origin, forward, standPosition = heroPosition, nil, nil
	if distance >= stats.placeDistance then
		local lateral = math.sqrt(math.max(0, distance * distance - stats.placeDistance * stats.placeDistance))
		if lateral <= halfLength then
			local direction = normalized2D(delta)
			local angle = math.acos(clamp(stats.placeDistance / math.max(stats.placeDistance, distance), -1, 1))
			local left, right = rotate2D(direction, angle), rotate2D(direction, -angle)
			forward = dot2D(currentForward, left) >= dot2D(currentForward, right) and left or right
		end
	end
	if not forward then
		local toward = distance > 1 and normalized2D(delta) or currentForward
		standPosition = add(targetPosition, scale(toward, -stats.placeDistance))
		origin = standPosition
		forward = normalizedForward(subtract(targetPosition, standPosition))
	end
	return {forward = forward, standPosition = standPosition, origin = origin}
end

local function planIceFloe(heroPosition, targetPosition, targetVelocity, stats, forcedPath)
	local moving = length2D(targetVelocity) > 20
	local travel = normalizedForward(moving and targetVelocity or subtract(targetPosition, heroPosition))
	local side = {x = -travel.y, y = travel.x, z = 0}
	local segment = forcedPath and side or travel
	local half = stats.floeLength * 0.5
	local first = add(targetPosition, scale(segment, -half))
	local second = add(targetPosition, scale(segment, half))
	if distance2D(heroPosition, first) < distance2D(heroPosition, second) then first, second = second, first end
	return {vectorStart = first, vectorEnd = second}
end

---Issues one cast or moves into effective range when the cast cannot start yet.
---@param request table
---@param snapshot InvokerSnapshot
---@return "invalid"|"wait"|"move"|"issued", string|table
local function castAction(request, snapshot)
	local action = snapshot.actions[request.actionId]
	local definition = definitions[request.actionId]
	if not action or not action.exists then return "invalid", "Action is not present." end
	if isSpell(request.actionId) and not contains(snapshot.invoke.invoked, canonicalSpell(request.actionId)) then
		return "wait", "Invoked ability is not active in D/F yet."
	end
	if action.cooldown > 0.05 or not action.activated or not Ability.IsCastable(action.ability, snapshot.hero.mana) then
		return "wait", "Action is not castable yet."
	end
	local target = request.targetIndex and Entity.Get(request.targetIndex) or nil
	if definition.targeting == "enemy" and not target then return "invalid", "Target disappeared before cast." end

	local castPosition = copyPoint(request.position)
	local castRange = action.castRange
	local actionRange = castRange
	local exactGroundAim = request.exactPosition == true or snapshot.targetMode == "cursor"
	local vectorCast = request.vectorStart ~= nil and request.vectorEnd ~= nil
	if request.actionId == "tornado" then
		local travelDistance = 1200 + 300 * snapshot.hero.orbLevels.wex
		local radius = math.max(100, liveValue(snapshot, "tornado", "area_of_effect", 200))
		actionRange = exactGroundAim and castRange or travelDistance + radius * 0.65
		local desiredDistance = distance2D(snapshot.hero.position, castPosition)
		if not exactGroundAim and desiredDistance > castRange and castRange > 0
			and desiredDistance <= actionRange
		then
			local direction = normalized2D(subtract(castPosition, snapshot.hero.position))
			castPosition = add(snapshot.hero.position, scale(direction, math.max(80, castRange - 25)))
		end
	elseif definition.targeting == "point" and castRange > 0 then
		local desiredDistance = distance2D(snapshot.hero.position, castPosition)
		local mechanics = resolveMechanics(request.actionId, snapshot, desiredDistance)
		actionRange = exactGroundAim and castRange or castRange + math.max(0, mechanics.radius - 40)
		if not exactGroundAim and desiredDistance > castRange
			and desiredDistance <= actionRange
		then
			local direction = normalized2D(subtract(castPosition, snapshot.hero.position))
			castPosition = add(snapshot.hero.position, scale(direction, math.max(80, castRange - 25)))
		end
	end
	if castRange > 0 and definition.targeting ~= "self" and definition.targeting ~= "none"
		and (definition.targeting ~= "directional" or vectorCast)
	then
		local destination = vectorCast and request.vectorEnd or target and copyPoint(Entity.GetAbsOrigin(target)) or castPosition
		local distance = distance2D(snapshot.hero.position, destination)
		if distance > actionRange + (vectorCast and 0 or 40) then
			local direction = normalized2D(subtract(destination, snapshot.hero.position))
			moveTo(request.moveToCursor and snapshot.cursor or add(destination, scale(direction, -math.max(40, actionRange - 60))))
			return "move", request.moveToCursor and "Moving toward cursor." or "Moving into cast range."
		end
	end
	local cooldownBefore = Ability.GetCooldown(action.ability)
	local secondsBefore = Ability.SecondsSinceLastUse(action.ability)
	state.moveOrder = nil
	state.kiteAttack = nil
	issueOrder(function()
		if request.actionId == "cataclysm" then
			Ability.CastTarget(action.ability, state.hero, false, false, true, "invoker_auto")
		elseif definition.targeting == "enemy" then
			Ability.CastTarget(action.ability, target, false, false, true, "invoker_auto")
		elseif definition.targeting == "self" or definition.targeting == "ally" then
			Ability.CastTarget(action.ability, state.hero, false, false, true, "invoker_auto")
		elseif definition.targeting == "point" then
			Ability.CastPosition(action.ability, toVector(castPosition), false, false, true, "invoker_auto", false)
		elseif definition.targeting == "directional" and request.vectorStart and request.vectorEnd then
			Player.PrepareUnitOrders(state.player, Enum.UnitOrder.DOTA_UNIT_ORDER_VECTOR_TARGET_POSITION, nil, toVector(request.vectorStart), action.ability, Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, state.hero, false, true, false, true, "invoker_auto", false)
			Player.PrepareUnitOrders(state.player, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION, nil, toVector(request.vectorEnd), action.ability, Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, state.hero, false, true, false, true, "invoker_auto", false)
		else
			Ability.CastNoTarget(action.ability, false, false, true, "invoker_auto")
		end
	end)
	return "issued", {
		issuedAt = snapshot.now,
		cooldownBefore = cooldownBefore,
		secondsBefore = secondsBefore,
	}
end

local function castConfirmed(pending, snapshot)
	local action = snapshot.actions[pending.action.actionId]
	if not action or not action.exists then return false end
	if action.inAbilityPhase then return false end
	local secondsSince = Ability.SecondsSinceLastUse(action.ability)
	return action.cooldown > pending.cooldownBefore + 0.05
		or secondsSince >= 0 and (pending.secondsBefore < 0 or secondsSince + 0.05 < pending.secondsBefore)
end

local function updatePendingCast(snapshot)
	local pending = state.pendingCast
	if not pending then return false end
	if pending.action.actionId == "item_meteor_hammer" then
		local runtime = snapshot.actions.item_meteor_hammer
		local mechanics = resolveMechanics("item_meteor_hammer", snapshot, 0)
		if runtime.exists and Ability.IsChannelling(runtime.ability) then
			pending.channelStartedAt = pending.channelStartedAt or snapshot.now
			setStatus("channeling", "Meteor Hammer channeling.")
			return true
		end
		if pending.channelStartedAt then
			local completed = snapshot.now - pending.channelStartedAt >= mechanics.channelTime - 0.12
			pending.action.status = completed and "confirmed" or "skipped"
			state.pendingCast = nil
			if completed then
				pending.action.impactAt = snapshot.now + mechanics.fixedDelay - mechanics.channelTime
				pending.action.effectEndAt = pending.action.impactAt + mechanics.controlDuration
			end
			setStatus(completed and "preparing" or "waiting", completed and "Meteor Hammer released." or "Meteor Hammer interrupted; replanning follow-up.")
			replanAfterSkip(snapshot)
			return true
		end
		if snapshot.now < pending.deadline then return true end
		pending.action.status = "skipped"
		state.pendingCast = nil
		setStatus("waiting", "Meteor Hammer channel was not observed; skipped.")
		replanAfterSkip(snapshot)
		return true
	end
	if castConfirmed(pending, snapshot) then
		local refreshed = pending.action.actionId == "item_refresher"
		pending.action.status = "confirmed"
		state.pendingCast = nil
		setStatus("preparing", definitions[pending.action.actionId].short .. " confirmed.")
		return refreshed
	end
	if snapshot.now < pending.deadline then return true end
	state.pendingCast = nil
	if pending.action.attempts < 2 then
		pending.action.status = "ready"
		pending.action.castAt = snapshot.now + 0.04
		setStatus("waiting", "Cast was not confirmed; retrying once.")
	else
		pending.action.status = "skipped"
		setStatus("waiting", "Skipped " .. definitions[pending.action.actionId].short .. ": cast was not confirmed.")
		replanAfterSkip(snapshot)
	end
	return false
end

local function targetValid(action, snapshot)
	local definition = definitions[action.actionId]
	if definition.targeting == "none" or definition.targeting == "self" then return true end
	local target = findEnemy(snapshot, action.targetIndex)
	if definition.targeting == "point" or definition.targeting == "directional" then
		return snapshot.targetMode == "cursor" or target and target.alive and not target.dormant
	end
	return target and target.alive and not target.dormant and not target.invulnerable
		and (not target.spellBlocked or canBreakSpellBlock(action.actionId))
		and not (target.debuffImmune and not snapshot.actions[action.actionId].piercesDebuffImmunity
			and (definition.tags.control or definition.tags.debuff or definition.tags.silence))
end

local function nextSafePreparation(snapshot)
	if not state.plan or not snapshot.invoke.ready or snapshot.hero.silenced or snapshot.hero.stunned then return nil end
	local current = nextPlanAction()
	if not current then return nil end
	if current.preparedOnly then return nil end
	if current.catchTornado or current.snapBeforeTornado then return nil end
	if current.actionId == "tornado" then
		for _, action in ipairs(state.plan.actions) do
			if action.catchTornado and action.anchorUid == current.uid and action.status == "pending" then return nil end
		end
	end
	local pending = {}
	for _, action in ipairs(state.plan.actions) do
		if (action.status == "pending" or action.status == "preparing" or action.status == "ready")
			and isSpell(action.actionId)
		then
			pending[#pending + 1] = action
		end
	end
	table.sort(pending, function(left, right)
		if left.castAt == right.castAt then return left.sequenceIndex < right.sequenceIndex end
		return left.castAt < right.castAt
	end)
	local held = {}
	for _, id in ipairs(snapshot.invoke.invoked) do pushUnique(held, canonicalSpell(id)) end
	local queue = {}
	for _, action in ipairs(pending) do
		local id = canonicalSpell(action.actionId)
		if not contains(held, id) and not action.preparedOnly then
			queue[#queue + 1] = {
				actionId = id,
				prepareAt = action.prepareAt,
				castAt = action.castAt,
			}
			held[#held + 1] = id
			if #held > 2 then
				local selected, selectedAt
				for _, heldId in ipairs(held) do
					local nextAt = math.huge
					for _, future in ipairs(pending) do
						if future.sequenceIndex > action.sequenceIndex
							and canonicalSpell(future.actionId) == heldId
						then
							nextAt = math.min(nextAt, future.castAt)
						end
					end
					if selectedAt == nil or nextAt > selectedAt then selected, selectedAt = heldId, nextAt end
				end
				for index, heldId in ipairs(held) do
					if heldId == selected then table.remove(held, index); break end
				end
			end
		end
	end
	local candidate
	for _, request in ipairs(queue) do
		if request.prepareAt <= snapshot.now + 0.04 and request.castAt - snapshot.now <= 4 then
			candidate = request
			break
		end
	end
	if not candidate then return nil end
	local currentSpell = isSpell(current.actionId) and canonicalSpell(current.actionId) or nil
	if currentSpell
		and snapshot.actions[current.actionId].invoked
		and current.castAt - snapshot.now <= math.max(0.15, snapshot.invoke.cooldownLength + 0.1)
	then
		return nil
	end
	if currentSpell and snapshot.invoke.invoked[1] == currentSpell and candidate.actionId ~= currentSpell then
		return currentSpell, true
	end
	return candidate.actionId, false
end

local function prepareFuture(snapshot)
	if snapshot.now < state.nextInvokeAttempt or isInvoking() then return false end
	local actionId, reorder = nextSafePreparation(snapshot)
	if not actionId or not queueInvoke(actionId, reorder) then return false end
	state.nextInvokeAttempt = snapshot.now + math.max(0.16, snapshot.latency * 2 + 0.08)
	return true
end

function helpers.actionBlockedByDefense(action, snapshot)
	local definition = definitions[action.actionId]
	if definition.targeting == "none" or definition.targeting == "self" or definition.targeting == "ally" then return false end
	if snapshot.targetMode == "cursor" and not action.targetIndex then return false end
	local target = findEnemy(snapshot, action.targetIndex)
	if not target then return false end
	local runtime = snapshot.actions[action.actionId]
	if not runtime or not runtime.exists then return false end
	return target.debuffImmune and not runtime.piercesDebuffImmunity
			and (definition.tags.control or definition.tags.debuff or definition.tags.silence or definition.damageType == "pure")
		or target.magicImmune and definition.damageType == "magical"
		or (target.invulnerable or target.outOfGame) and target.controlEndsAt <= snapshot.now
end

function helpers.skipBlockedActions(snapshot)
	local changed = false
	for _, action in ipairs(state.plan.actions) do
		if action.status == "pending" or action.status == "ready" or action.status == "preparing" then
			local anchor = action.catchTornado and findActionByUid(state.plan.actions, action.anchorUid)
			local target = action.catchTornado and findEnemy(snapshot, action.targetIndex)
			local missedCatch = action.catchTornado and (target and target.controlEndsAt > snapshot.now
				or anchor and anchor.status == "confirmed" and snapshot.now > action.catchDeadline)
			if missedCatch or helpers.actionBlockedByDefense(action, snapshot) then
				action.status = "skipped"
				changed = true
				if isInvoking(action.actionId) then state.invokeSequence = nil end
			end
		end
	end
	if changed then
		replanAfterSkip(snapshot)
		setStatus("preparing", "Skipped blocked spells; continuing with usable actions and attacks.")
	end
end

function helpers.comboAttackAllowed(snapshot)
	local action = nextPlanAction()
	if not action then return true end
	if action.movingForRange then return false end
	local readyAt = action.castAt
	if isSpell(action.actionId) and not snapshot.actions[action.actionId].invoked then
		readyAt = math.max(readyAt, snapshot.now + snapshot.invoke.cooldown)
	end
	return snapshot.now + 0.35 < readyAt
end

function helpers.recheckTornadoCatch(snapshot)
	if state.plan.strict then return false end
	local tornado = nextPlanAction()
	if not tornado or tornado.actionId ~= "tornado" then return false end
	for _, snap in ipairs(state.plan.actions) do
		if snap.catchTornado and snap.anchorUid == tornado.uid
			and (snap.status == "pending" or snap.status == "ready" or snap.status == "preparing")
		then
			local target = findEnemy(snapshot, snap.targetIndex)
			if target and not helpers.canCatchTornado(snapshot, target) then
				tornado.sequenceIndex, snap.sequenceIndex = snap.sequenceIndex, tornado.sequenceIndex
				replanCurrentPlan(snapshot)
				setStatus("preparing", "Tornado flight is too short; using Cold Snap first.")
				return true
			end
		end
	end
	return false
end

function helpers.prepareSnapOpener(action, snapshot)
	if action.preparedOnly or not action.snapBeforeTornado or not contains(snapshot.invoke.invoked, "cold_snap")
		or contains(snapshot.invoke.invoked, "tornado")
	then return false end
	local pendingTornado = false
	for _, nextAction in ipairs(state.plan.actions) do
		if nextAction.sequenceIndex == action.sequenceIndex + 1 and nextAction.actionId == "tornado"
			and (nextAction.status == "pending" or nextAction.status == "ready" or nextAction.status == "preparing")
		then pendingTornado = true; break end
	end
	if not pendingTornado then return false end
	if snapshot.invoke.ready and not isInvoking() and snapshot.now >= state.nextInvokeAttempt then
		local preserve = snapshot.invoke.invoked[2] == "cold_snap"
		if queueInvoke(preserve and "cold_snap" or "tornado", preserve) then
			state.nextInvokeAttempt = snapshot.now + math.max(0.16, snapshot.latency * 2 + 0.08)
		end
	end
	setStatus("preparing", "Preparing Tornado before the Cold Snap opener.")
	return true
end

---Advances the active combo by at most one state transition.
---@param snapshot InvokerSnapshot
---@param settings table
local function updateExecutor(snapshot, settings)
	if not state.plan then return end
	if not snapshot.activeGame or snapshot.paused then setStatus("waiting", "Game is paused."); return end
	if not snapshot.hero.alive then abortPlan("Invoker died."); return end
	if snapshot.hero.stunned then setStatus("waiting", "Invoker is disabled."); return end
	if snapshot.hero.silenced then setStatus("waiting", "Invoker is silenced."); return end
	if state.plan.targetMode == "normal" and (not snapshot.target or not snapshot.target.alive or snapshot.target.dormant) then
		abortPlan("Target died or disappeared.")
		return
	end
	if updatePendingCast(snapshot) then return end
	helpers.skipBlockedActions(snapshot)
	reactivePlanCheck(snapshot, settings)
	if not state.plan then return end
	if helpers.recheckTornadoCatch(snapshot) then return end

	local action = nextPlanAction()
	if not action then
		local source = state.plan.source
		state.plan = nil
		state.invokeSequence = nil
		setStatus("complete", "All planned actions completed or safely skipped.")
		state.dynamicContinue = state.dynamicContinue
			or source == "custom" and settings.continueDynamic
			or source == "dynamic" and settings.slot == "D"
		state.nextPlanAt = state.dynamicContinue and snapshot.now + 0.2 or math.huge
		return
	end
	local runtimeAction = snapshot.actions[action.actionId]
	if action.preparedOnly and not contains(snapshot.invoke.invoked, canonicalSpell(action.actionId)) then
		action.status = "skipped"
		replanAfterSkip(snapshot)
		return
	end
	if not runtimeAction or not runtimeAction.exists then
		if tryDynamicReplacement(snapshot, settings) then return end
		action.status = "skipped"
		setStatus("waiting", "Skipped " .. definitions[action.actionId].short .. ": action disappeared.")
		replanAfterSkip(snapshot)
		return
	end
	if runtimeAction.cooldown > 0.05 or snapshot.hero.mana + 0.001 < runtimeAction.manaCost then
		if tryDynamicReplacement(snapshot, settings) then return end
		if runtimeAction.cooldown > 0.05 and runtimeAction.cooldown <= 0.25
			and snapshot.hero.mana + 0.001 >= runtimeAction.manaCost
		then
			setStatus("waiting", ("%s ready in %.2fs."):format(definitions[action.actionId].short, runtimeAction.cooldown))
			return
		end
		action.status = "skipped"
		setStatus("waiting", "Skipped " .. definitions[action.actionId].short .. ": cooldown or mana changed.")
		replanAfterSkip(snapshot)
		return
	end

	if helpers.prepareSnapOpener(action, snapshot) then return end
	if isSpell(action.actionId) and not runtimeAction.invoked then
		action.status = "preparing"
		if isInvoking(action.actionId) then
			setStatus("preparing", definitions[action.actionId].short .. " is being invoked into D/F.")
			return
		end
		if snapshot.now + 0.001 < action.prepareAt then
			setStatus("waiting", ("%s preparation starts in %.2fs."):format(definitions[action.actionId].short, action.prepareAt - snapshot.now))
			if settings.autoPrepare then prepareFuture(snapshot) end
			return
		end
		if snapshot.invoke.ready and snapshot.now >= state.nextInvokeAttempt and not isInvoking() then
			if queueInvoke(action.actionId, false) then
				state.nextInvokeAttempt = snapshot.now + math.max(0.16, snapshot.latency * 2 + 0.08)
			end
			setStatus("preparing", "Preparing " .. definitions[action.actionId].name .. ".")
		else
			setStatus("waiting", ("Invoke cooldown %.2fs."):format(snapshot.invoke.cooldown))
		end
		return
	end
	action.status = "ready"
	if snapshot.now + 0.001 < action.castAt then
		setStatus("waiting", ("%s scheduled in %.2fs."):format(definitions[action.actionId].short, action.castAt - snapshot.now))
		if settings.autoPrepare then prepareFuture(snapshot) end
		return
	end
	if not targetValid(action, snapshot) then
		if tryDynamicReplacement(snapshot, settings) then return end
		action.status = "skipped"
		setStatus("waiting", "Skipped " .. definitions[action.actionId].short .. ": target is invalid.")
		replanAfterSkip(snapshot)
		return
	end

	local target = findEnemy(snapshot, action.targetIndex)
	if action.actionId == "item_meteor_hammer" and state.plan.source == "dynamic" then
		local mechanics = resolveMechanics(action.actionId, snapshot, 0)
		if not target or target.debuffImmune or target.outOfGame
			or distance2D(snapshot.hero.position, target.position) > runtimeAction.castRange
			or not helpers.hammerSetupAvailable(snapshot, target, {})
		then
			action.status = "skipped"
			setStatus("waiting", "Skipped Hammer: insufficient live lockdown or target left cast range.")
			replanAfterSkip(snapshot)
			return
		end
		if target.controlEndsAt > snapshot.now then
			local startAt = target.controlEndsAt + landingSafety(action.actionId)
				- mechanics.castPoint - mechanics.fixedDelay - latencyLead(snapshot)
			if snapshot.now + 0.001 < startAt then
				action.castAt = startAt
				setStatus("waiting", "Timing Hammer for cyclone landing.")
				return
			end
		end
		action.targetPosition = copyPoint(target.controlPosition or target.position)
	end
	if (not action.anchored or action.actionId == "ice_wall") and snapshot.targetMode ~= "cursor" and target
		and (definitions[action.actionId].targeting == "point" or definitions[action.actionId].targeting == "directional")
	then
		action.targetPosition = baseTargetPosition(snapshot, target, action.actionId, snapshot.now)
	end
	local request = {
		actionId = action.actionId,
		targetIndex = action.targetIndex,
		position = action.targetPosition,
		moveToCursor = settings.moveDirection == "cursor",
	}
	if action.actionId == "ice_wall" then
		local stats = iceWallStats(snapshot)
		local iceFloe = snapshot.hero.upgrades.scepterChoice == "quas"
		if iceFloe then
			local plannedBlast = false
			for _, prior in ipairs(state.plan.actions) do
				if prior.actionId == "deafening_blast" and prior.status == "confirmed"
					and prior.impactAt <= snapshot.now and prior.effectEndAt > snapshot.now
				then plannedBlast = true; break end
			end
			local targetVelocity = target and target.velocity or {x = 0, y = 0, z = 0}
			local floe = planIceFloe(snapshot.hero.position, action.targetPosition, targetVelocity, stats, plannedBlast)
			request.vectorStart = floe.vectorStart
			request.vectorEnd = floe.vectorEnd
		else
			local wall = planIceWall(snapshot.hero.position, snapshot.hero.facing, action.targetPosition, stats)
			if wall.standPosition and distance2D(snapshot.hero.position, wall.standPosition) > 55 then
				action.movingForRange = true
				state.orbSequence = nil
				if snapshot.now >= state.nextIceWallMoveAt then
					moveTo(request.moveToCursor and snapshot.cursor or wall.standPosition)
					state.nextIceWallMoveAt = snapshot.now + 0.12
				end
				setStatus("moving", request.moveToCursor and "Moving toward cursor." or "Moving to place Ice Wall through the target.")
				return
			end
			local heroForward = normalizedForward(snapshot.hero.facing)
			local wallForward = normalizedForward(wall.forward)
			local facingAlignment = dot2D(heroForward, wallForward)
			if facingAlignment < math.cos(0.08) then
				action.movingForRange = true
				state.orbSequence = nil
				if snapshot.now >= state.nextFaceAttempt then
					local facePosition = add(snapshot.hero.position, scale(wall.forward, 180))
					issueOrder(function()
						Player.PrepareUnitOrders(state.player, Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_DIRECTION, nil, toVector(facePosition), nil, Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, state.hero, false, false, false, true, "invoker_auto", false)
					end)
					state.nextFaceAttempt = snapshot.now + 0.08
				end
				setStatus("moving", "Facing Ice Wall across the target path.")
				return
			end
		end
	end

	action.movingForRange = false
	state.orbSequence = nil
	local kind, result = castAction(request, snapshot)
	if kind == "issued" then
		action.status = "issued"
		action.attempts = action.attempts + 1
		local mechanics = resolveMechanics(action.actionId, snapshot, distance2D(snapshot.hero.position, action.targetPosition))
		state.pendingCast = {
			action = action,
			issuedAt = result.issuedAt,
			cooldownBefore = result.cooldownBefore,
			secondsBefore = result.secondsBefore,
			deadline = result.issuedAt + mechanics.channelTime + math.max(cfg.castConfirmMin, mechanics.castPoint + snapshot.latency * 2 + 0.35),
		}
		setStatus("confirming", definitions[action.actionId].short .. " order issued.")
	elseif kind == "move" then
		action.movingForRange = true
		state.orbSequence = nil
		if action.actionId == "ice_wall" and snapshot.hero.upgrades.scepterChoice == "quas" then
			action.moveDeadline = action.moveDeadline or snapshot.now + cfg.floeMoveTimeout
			if snapshot.now >= action.moveDeadline then
				action.status = "skipped"
				setStatus("waiting", "Skipped Ice Floe: could not reach its cast position.")
				replanAfterSkip(snapshot)
				return
			end
		end
		setStatus("moving", result)
	elseif kind == "wait" then
		action.waitDeadline = action.waitDeadline or snapshot.now + 1
		if snapshot.now >= action.waitDeadline then
			action.status = "skipped"
			replanAfterSkip(snapshot)
			setStatus("waiting", "Skipped " .. definitions[action.actionId].short .. ": cast remained unavailable.")
			return
		end
		setStatus("waiting", result)
	else
		action.attempts = action.attempts + 1
		if action.attempts < 2 then
			action.status = "ready"
			action.castAt = snapshot.now + 0.05
			setStatus("waiting", result .. " Retrying once.")
		else
			action.status = "skipped"
			setStatus("waiting", "Skipped " .. definitions[action.actionId].short .. ": " .. result)
			replanAfterSkip(snapshot)
		end
	end
end

local function addCustomLinkenBreaker(actions, snapshot, settings)
	if snapshot.targetMode == "cursor"
		or not snapshot.target
		or not snapshot.target.spellBlocked
		or not settings.dynamic.breakLinkens
	then
		return actions
	end
	local needsTarget = false
	for _, id in ipairs(actions) do
		if isUnitTarget(id) then
			needsTarget = true
			break
		end
	end
	if not needsTarget then return actions end
	local firstTarget
	for _, id in ipairs(actions) do
		if isUnitTarget(id) then
			firstTarget = id
			break
		end
	end
	if firstTarget and canBreakSpellBlock(firstTarget) and contains(settings.dynamic.linkenPriority, firstTarget) then return actions end
	local breaker = selectLinkenBreaker(snapshot, snapshot.target, settings.dynamic, snapshot.hero.mana, false)
	if not breaker then return actions end
	local result = {breaker}
	for _, id in ipairs(actions) do
		if id ~= breaker then result[#result + 1] = id end
	end
	return result
end

function helpers.addPreparedExtras(actions, snapshot, settings)
	if not settings.castCraftedFirst or not settings.preparedOutsideCombo then return actions end
	local result, seen = {}, {}
	for _, id in ipairs(actions) do seen[canonicalSpell(id)] = true end
	local mana = snapshot.hero.mana
	for _, id in ipairs(snapshot.invoke.invoked) do
		if definitions[id] and id ~= "ghost_walk" and not seen[id] and actionAvailable(id, snapshot, true)
			and mana >= snapshot.actions[id].manaCost
			and (snapshot.targetMode ~= "cursor" or not isUnitTarget(id))
			and (not snapshot.target or helpers.dynamicActionUseful(id, snapshot, snapshot.target, settings, result))
		then
			result[#result + 1] = id
			seen[id] = true
			mana = mana - snapshot.actions[id].manaCost
		end
	end
	for _, id in ipairs(actions) do result[#result + 1] = id end
	return result
end

function helpers.markPreparedExtras(plan, settings)
	if not settings.dynamic.castCraftedFirst or not settings.dynamic.preparedOutsideCombo then return end
	local listed = plan.source == "dynamic" and settings.dynamic.enabledSpells or state.combos[plan.slot] or {}
	for _, action in ipairs(plan.actions) do
		local id = canonicalSpell(action.actionId)
		if isSpell(id) then
			local included = false
			for _, selected in ipairs(listed) do
				if canonicalSpell(selected) == id then included = true; break end
			end
			action.preparedOnly = not included
		end
	end
end

local function startCombo(snapshot, settings, forceDynamic)
	local dynamicRequest = forceDynamic or settings.slot == "D"
	local actions, name = selectedComboActions(snapshot, settings, forceDynamic)
	if not actions then
		if dynamicRequest then
			local message = "Waiting for the next usable Dynamic action."
			state.statusPhase = "waiting"
			state.status = message
			logChanged("dynamicWait", "STATUS", "waiting: " .. message)
			logChanged("dynamicReason", "DYNAMIC", name)
		else
			setStatus("aborted", name)
		end
		return false
	end
	if not dynamicRequest then actions = helpers.addPreparedExtras(actions, snapshot, settings.dynamic) end
	if snapshot.targetMode == "cursor" then
		local cursorActions = {}
		local catch = contains(actions, "tornado") and helpers.tornadoCatchTarget(snapshot)
		for _, id in ipairs(actions) do
			if not isUnitTarget(id) or id == "cold_snap" and catch then cursorActions[#cursorActions + 1] = id end
		end
		actions = cursorActions
	end
	local strict = not dynamicRequest and state.comboStrict and state.comboStrict[settings.slot]
	if not strict then actions = addCustomLinkenBreaker(actions, snapshot, settings) end
	actions = filterCombo(actions, snapshot)
	if not strict then
		actions = optimizeCustomSequence(actions)
		actions = helpers.orderTornadoCatch(actions, snapshot)
		actions = resumeAfterLiveControl(actions, snapshot)
	end
	if #actions == 0 then
		if dynamicRequest then
			local message = "Waiting for the next usable Dynamic action."
			state.statusPhase = "waiting"
			state.status = message
			logChanged("dynamicWait", "STATUS", "waiting: " .. message)
		else
			setStatus("aborted", "The selected combo has no currently usable actions.")
		end
		return false
	end
	state.invokeSequence = nil
	state.orbSequence = nil
	local source = (forceDynamic or settings.slot == "D") and "dynamic" or "custom"
	local slot = forceDynamic and "D" or settings.slot
	if source == "dynamic" then
		state.dynamicPreview = arrayCopy(actions)
		state.lastDebug.dynamicWait = nil
		state.lastDebug.dynamicReason = nil
	end
	state.plan = buildPlan(actions, snapshot, source, slot)
	helpers.markPreparedExtras(state.plan, settings)
	state.pendingCast = nil
	state.lastPlanCheck = snapshot.now
	captureAimReference(snapshot)
	setStatus("preparing", name .. " started.")
	logDebug("PLAN", name .. ": " .. table.concat(actions, " -> "))
	return true
end

local function interruptInRange(id, target, snapshot)
	local action = snapshot.actions[id]
	if not action or not action.exists or not actionAvailable(id, snapshot, false) then return false end
	local distance = distance2D(snapshot.hero.position, target.position)
	if id == "cold_snap" then return distance <= math.max(0, action.castRange) + 40 end
	if id == "tornado" then
		local mechanics = resolveMechanics(id, snapshot, distance)
		local travelDistance = liveValue(snapshot, id, "travel_distance", 1200 + 300 * math.max(0, snapshot.hero.orbLevels.wex))
		return distance <= travelDistance + math.max(100, mechanics.radius) * 0.65 + 40
	end
	return false
end

local function interruptArrival(id, target, snapshot)
	local action = snapshot.actions[id]
	if id == "cold_snap" and target.spellBlocked then return math.huge end
	if not action or action.cooldown > 0.05 or snapshot.hero.mana + 0.001 < action.manaCost or not interruptInRange(id, target, snapshot) then
		return math.huge
	end
	if not action.invoked and not snapshot.invoke.ready and not isInvoking(id) then return math.huge end
	local invokeDelay = action.invoked and 0 or math.max(0.16, snapshot.latency * 2 + 0.08)
	local result = invokeDelay + math.max(0.05, action.castPoint) + snapshot.latency
	if target.fogTeleport then
		result = result + NPC.GetTimeToFacePosition(snapshot.hero.entity, toVector(target.position)) + snapshot.latencyJitter
	end
	if id == "tornado" then
		result = result + distance2D(snapshot.hero.position, target.position) / math.max(1, resolveMechanics(id, snapshot, 0).projectileSpeed)
	end
	if target.teleporting and target.teleportRemaining > 0 and result + cfg.timingSafety >= target.teleportRemaining then
		return math.huge
	end
	return result
end

local function selectInterruptTarget(snapshot, settings)
	if not settings.interrupt then return nil, nil end
	local bestTarget, bestSpell, bestDistance
	local allowed = {}
	if settings.interruptTornado then allowed[#allowed + 1] = "tornado" end
	if settings.interruptSnap then allowed[#allowed + 1] = "cold_snap" end
	for _, enemy in ipairs(snapshot.enemies) do
		if enemy.alive and not enemy.dormant and not enemy.invulnerable and not enemy.debuffImmune
			and (enemy.channeling or settings.interruptTeleports and enemy.teleporting)
		then
			local ordered = arrayCopy(allowed)
			table.sort(ordered, function(left, right)
				return interruptArrival(left, enemy, snapshot) < interruptArrival(right, enemy, snapshot)
			end)
			if ordered[1] and interruptArrival(ordered[1], enemy, snapshot) < math.huge then
				local distance = distance2D(snapshot.hero.position, enemy.position)
				if not bestTarget or distance < bestDistance then
					bestTarget, bestSpell, bestDistance = enemy, ordered[1], distance
				end
			end
		end
	end
	if settings.interruptTeleports and settings.interruptFogTeleports and settings.interruptTornado then
		for _, particle in pairs(state.teleportParticles or {}) do
			local target = helpers.fogTeleportTarget(particle, snapshot, settings)
			if target and interruptArrival("tornado", target, snapshot) < math.huge then
				local distance = distance2D(snapshot.hero.position, target.position)
				if not bestTarget or distance < bestDistance then bestTarget, bestSpell, bestDistance = target, "tornado", distance end
			end
		end
	end
	return bestTarget, bestSpell
end

function helpers.hasAutoSunMana(snapshot, settings, id)
	local manaAfter = snapshot.hero.mana - snapshot.actions[id or "sun_strike"].manaCost
	return manaAfter >= 0 and manaAfter / math.max(1, snapshot.hero.maxMana) * 100 + 0.001 >= settings.sunMinMana
end

function helpers.objectiveKillWindow(objective, now, delay, damage, margin)
	if not objective or objective.health <= 0 or not objective.position or not objective.underAttack
		or now - objective.lastAlliedDamageAt <= 1.5
	then
		return false
	end
	-- Health/barrier slopes include regen. Raw incoming damage feeds do not.
	local incomingDps = objective.damagePerSecond
	if objective.damageIsNet and incomingDps > 0 then incomingDps = incomingDps + objective.healthRegen end
	local expectedHealth = objective.health + (objective.healthRegen - incomingDps) * delay
	if expectedHealth <= 0 then return false end
	return expectedHealth <= math.max(0, damage * objective.damageMultiplier - margin)
end

function helpers.objectiveSunReady(snapshot, settings)
	local action = snapshot.actions.sun_strike
	if not actionAvailable("sun_strike", snapshot, false)
		or action.cooldown > 0.05
		or not helpers.hasAutoSunMana(snapshot, settings)
		or not action.invoked and not snapshot.invoke.ready and not isInvoking("sun_strike")
	then
		return false
	end
	return true
end

function helpers.objectiveSunDamage(snapshot, objective)
	local mechanics = resolveMechanics("sun_strike", snapshot, 0)
	local delay = helpers.sunImpactDelay(snapshot, "sun_strike")
	local damage = mechanics.expectedDamage / sunSplitCount(snapshot, objective.position,
		math.max(cfg.sunRadius, mechanics.radius), objective.index, delay)
	local amplification = NPC.GetModifierProperty(snapshot.hero.entity, Enum.ModifierFunction.MODIFIER_PROPERTY_SPELL_AMPLIFY_PERCENTAGE)
		+ NPC.GetModifierProperty(snapshot.hero.entity, Enum.ModifierFunction.MODIFIER_PROPERTY_SPELL_AMPLIFY_PERCENTAGE_UNIQUE)
	local outgoing = NPC.GetModifierProperty(snapshot.hero.entity, Enum.ModifierFunction.MODIFIER_PROPERTY_TOTALDAMAGEOUTGOING_PERCENTAGE)

	damage = damage * clamp(1 + amplification / 100, 0, 1) * clamp(1 + outgoing / 100, 0, 1)
	return delay, damage
end

function helpers.isRoshanSunTarget(snapshot, settings)
	local roshan = snapshot.roshan
	if not settings.roshan or not roshan or not roshan.position or not helpers.objectiveSunReady(snapshot, settings) then return false end
	local delay, damage = helpers.objectiveSunDamage(snapshot, roshan)
	if roshan.moving or roshan.nextMoveIn >= 0 and roshan.nextMoveIn <= delay then return false end
	return helpers.objectiveKillWindow(roshan, snapshot.now, delay, damage, settings.roshanMargin)
end

function helpers.selectTormentorSunTarget(snapshot, settings, lockedIndex)
	if not settings.tormentor or not snapshot.tormentors or not helpers.objectiveSunReady(snapshot, settings) then return nil end
	local best
	for _, objective in ipairs(snapshot.tormentors) do
		if (not lockedIndex or objective.index == lockedIndex)
			and (not objective.estimated or objective.dataStatus == "estimated")
		then
			local delay, damage = helpers.objectiveSunDamage(snapshot, objective)
			if helpers.objectiveKillWindow(objective, snapshot.now, delay, damage, settings.tormentorMargin)
				and (not best or objective.health < best.health)
			then
				best = objective
			end
		end
	end
	return best
end

---Checks split damage, control duration, and movement reliability for Auto Sun Strike.
---@param enemy EnemyState
---@param snapshot InvokerSnapshot
---@param settings table
---@return boolean
local function isAutoSunTarget(enemy, snapshot, settings)
	if not settings.sunStrike or not helpers.hasAutoSunMana(snapshot, settings)
		or not enemy.alive or not enemy.visible or enemy.dormant or enemy.invulnerable or enemy.outOfGame
	then
		return false
	end
	local mechanics = resolveMechanics("sun_strike", snapshot, 0)
	local impactDelay = helpers.sunImpactDelay(snapshot, "sun_strike")
	local impactAt = snapshot.now + impactDelay
	local controlled = math.max(enemy.disabledUntil, enemy.controlEndsAt) >= impactAt + 0.03
	local prediction = predictIntercept(snapshot, "sun_strike", enemy, snapshot.now, enemy.motionConfidence).position
	local expectedDamage = mechanics.expectedDamage / sunSplitCount(snapshot, prediction, math.max(cfg.sunRadius, mechanics.radius), enemy.index, impactDelay)
	local impactHealth = math.min(enemy.maxHealth, enemy.health + math.max(0, enemy.healthRegen) * impactDelay)
	local lethal = impactHealth <= expectedDamage
	local runner = settings.predictRunningTargets and lethal and enemy.moving and length2D(enemy.velocity) > 40
		and enemy.motionConfidence >= 0.58
		and enemy.movementDuration >= settings.sunWalkTime
		and enemy.stableDuration >= settings.sunWalkTime
	local idleTarget = lethal and not enemy.moving and length2D(enemy.velocity) < 20
		and enemy.idleDuration >= settings.sunIdleTime
	return lethal and (runner or idleTarget or settings.useControlledTargets and controlled)
end

local function selectAutoSunTarget(snapshot, settings)
	local candidates = {}
	for _, enemy in ipairs(snapshot.enemies) do
		if isAutoSunTarget(enemy, snapshot, settings) then candidates[#candidates + 1] = enemy end
	end
	table.sort(candidates, function(left, right) return left.health < right.health end)
	return candidates[1]
end

function helpers.isAutoCataclysmTarget(enemy, snapshot, settings)
	if not settings.cataclysm or not helpers.hasAutoSunMana(snapshot, settings, "cataclysm")
		or snapshot.hero.upgrades.scepterChoice ~= "exort"
	then
		return false
	end
	return helpers.cataclysmHitsControl(enemy, snapshot)
end

local function selectCataclysmTarget(snapshot, settings)
	local controlled = {}
	for _, enemy in ipairs(snapshot.enemies) do
		if helpers.isAutoCataclysmTarget(enemy, snapshot, settings) then controlled[#controlled + 1] = enemy end
	end
	if #controlled < settings.cataclysmMinHeroes then return nil end
	table.sort(controlled, function(left, right) return left.health < right.health end)
	return controlled[1]
end

local function clickedQuickSunTarget(snapshot, settings)
	if not settings.quickSunButtons
		or Input.IsInputCaptured()
		or not Input.IsKeyDownOnce(Enum.ButtonCode.KEY_MOUSE1, false)
	then
		return nil
	end
	local cursorX, cursorY = Input.GetCursorPos()
	for _, hitbox in ipairs(state.quickSunHitboxes) do
		if cursorX >= hitbox.x and cursorX <= hitbox.x + hitbox.width
			and cursorY >= hitbox.y and cursorY <= hitbox.y + hitbox.height
		then
			return findEnemy(snapshot, hitbox.targetIndex)
		end
	end
	return nil
end

local function queueAutoAction(id, target, kind, snapshot)
	local action = snapshot.actions[id]
	if not action or not action.exists or action.cooldown > 0.05 or snapshot.hero.mana + 0.001 < action.manaCost then return false end
	if not action.invoked and not snapshot.invoke.ready then return false end
	local lifetime = kind == "interrupt" and 1.5 or kind == "quick_sun" and 2.4 or 2.2
	local fogTeleport = kind == "interrupt" and id == "tornado" and target.fogTeleport or nil
	state.autoPending = {
		actionId = id,
		targetIndex = target.index,
		kind = fogTeleport and "fog_interrupt" or kind,
		teleportParticle = fogTeleport,
		position = fogTeleport and copyPoint(target.position) or nil,
		expiresAt = snapshot.now + lifetime,
		attempts = 0,
		cast = nil,
	}
	state.invokeSequence = nil
	state.orbSequence = nil
	if fogTeleport then
		setStatus("preparing", "Tornado: interrupting teleport in fog.")
		logDebug("INTERRUPT", ("fog target=%d source=%.0f,%.0f remaining=%.2f"):format(target.index,
			target.position.x, target.position.y, target.teleportRemaining))
	end
	if kind == "quick_sun" then state.nextAutoActionAt = snapshot.now end
	return true
end

function helpers.landingEnemy(unit)
	return unit and state.hero and Entity.IsHero(unit) and not Entity.IsSameTeam(state.hero, unit)
		and not NPC.IsIllusion(unit)
end

function helpers.landingTrackingEnabled()
	if not state.hero or not ui.enabled:Get() then return false end
	local settings = readSettings().auto
	return settings.landingSun or settings.interrupt and settings.interruptTeleports and settings.interruptFogTeleports and settings.interruptTornado
end

function helpers.recordLandingModifier(unit, modifier)
	local name = Modifier.GetName(modifier)
	local kind = cfg.landingModifiers[name]
	if not kind or not helpers.landingTrackingEnabled() or not helpers.landingEnemy(unit) then return end
	local now = GameRules.GetGameTime()
	local remaining = modifierRemaining(modifier, now)
	if remaining <= 0 then return end
	local createdAt, index = Modifier.GetCreationTime(modifier), Entity.GetIndex(unit)
	state.landings = state.landings or {}
	local record = state.landings[index]
	if record and record.estimated and kind == "teleport" and math.abs(record.createdAt - createdAt) <= 0.75 then
		record.createdAt, record.estimated = createdAt, false
	end
	if record and not record.cancelled and record.name ~= name and record.endsAt > now + remaining then return end
	if not record or record.name ~= name or record.createdAt ~= createdAt then
		record = {index = index, name = name, kind = kind, createdAt = createdAt}
		state.landings[index] = record
	end
	record.endsAt = now + remaining
	if kind == "cyclone" and not Entity.IsDormant(unit) and NPC.IsVisible(unit) then
		record.position = copyPoint(Entity.GetAbsOrigin(unit))
	end
end

function helpers.destroyLandingModifier(unit, modifier)
	if not state.landings then return end
	local record = state.landings[Entity.GetIndex(unit)]
	if record and record.name == Modifier.GetName(modifier) and record.createdAt == Modifier.GetCreationTime(modifier) then
		record.cancelled = true
	end
end

function helpers.createTeleportParticle(data)
	local departure = string.find(data.fullName, "teleport_start", 1, true) ~= nil
		or string.find(data.fullName, "teleport_origin", 1, true) ~= nil
	if not (departure or string.find(data.fullName, "teleport_end", 1, true)) or not helpers.landingTrackingEnabled() then return end
	local owner = helpers.landingEnemy(data.entityForModifiers) and data.entityForModifiers
		or helpers.landingEnemy(data.entity) and data.entity or nil
	if not owner and data.entity_for_modifiers_id and data.entity_for_modifiers_id >= 0 then
		local candidate = Entity.Get(data.entity_for_modifiers_id)
		if helpers.landingEnemy(candidate) then owner = candidate end
	end
	if not owner and data.entity_id and data.entity_id >= 0 then
		local candidate = Entity.Get(data.entity_id)
		if helpers.landingEnemy(candidate) then owner = candidate end
	end
	if not owner then return end
	state.teleportParticles = state.teleportParticles or {}
	local now, index = GameRules.GetGameTime(), Entity.GetIndex(owner)
	state.teleportParticles[data.index] = {index = data.index, ownerIndex = index, createdAt = now}
	if departure then
		local particle = state.teleportParticles[data.index]
		particle.departure = true
		local boots = NPC.GetItem(owner, "item_travel_boots_2", true)
		particle.endsAt = now + (boots and Ability.GetLevelSpecialValueFor(boots, "tp_channel_time") or cfg.fogTeleportDuration)
		return
	end
	state.landings = state.landings or {}
	local record = state.landings[index]
	if not record or record.kind ~= "teleport" or math.abs(record.createdAt - now) > 0.75 then
		local duration = cfg.fogTeleportDuration
		local boots = NPC.GetItem(owner, "item_travel_boots_2", true)
		if boots then duration = Ability.GetLevelSpecialValueFor(boots, "tp_channel_time") end
		if duration <= 0 then return end
		state.landings[index] = {index = index, name = "modifier_teleporting", kind = "teleport",
			createdAt = now, endsAt = now + duration, estimated = true, particleIndex = data.index}
	end
end

function helpers.updateTeleportParticle(data)
	local particle = state.teleportParticles and state.teleportParticles[data.index]
	if particle and particle.departure then
		if data.controlPoint == 0 then particle.position = copyPoint(data.position) end
		if data.controlPoint == 7 and data.position.x > 0 and data.position.x <= cfg.teleportParticleLifetime then
			particle.endsAt = particle.createdAt + data.position.x
		end
		return
	end
	if not particle or data.controlPoint ~= 0 and data.controlPoint ~= 5 then return end
	if data.controlPoint == 5 and particle.controlPoint == 0 then return end
	local now = GameRules.GetGameTime()
	if particle.motionPosition and now - particle.motionAt >= 0.05 then
		local velocity = scale(subtract(data.position, particle.motionPosition), 1 / (now - particle.motionAt))
		particle.velocity = length2D(velocity) <= 700 and velocity or nil
		particle.sampledAt = now
		particle.motionPosition, particle.motionAt = copyPoint(data.position), now
	elseif not particle.motionPosition then
		particle.motionPosition, particle.motionAt = copyPoint(data.position), now
	end
	if data.controlPoint == 0 then particle.targetIndex = nil end
	particle.position, particle.positionAt = copyPoint(data.position), now
	particle.controlPoint = data.controlPoint
	if not particle.historyAdded then
		particle.historyAdded = true
		state.teleportHistory = state.teleportHistory or {}
		local record = state.landings and state.landings[particle.ownerIndex]
		for _, previous in ipairs(state.teleportHistory) do
			if now - previous.at <= cfg.teleportHistorySeconds
				and distance2D(previous.position, particle.position) <= cfg.teleportAmbiguityRadius
				and record and record.estimated and record.particleIndex == particle.index
			then record.ambiguousTiming = true end
		end
		state.teleportHistory[#state.teleportHistory + 1] = {at = now, position = copyPoint(particle.position)}
	end
end

function helpers.attachTeleportTarget(data)
	local particle = state.teleportParticles and state.teleportParticles[data.index]
	if particle and particle.departure then
		if data.controlPoint == 0 and data.entity and Entity.GetIndex(data.entity) == particle.ownerIndex then
			particle.position = copyPoint(data.position)
		end
		return
	end
	if not particle or particle.departure or data.controlPoint ~= 5 or particle.controlPoint == 0 then return end
	local owner, target = Entity.Get(particle.ownerIndex), data.entity
	if not owner or not target or not Entity.IsNPC(target) or Entity.GetIndex(target) == particle.ownerIndex
		or not Entity.IsSameTeam(owner, target)
	then return end
	particle.targetIndex = Entity.GetIndex(target)
end

function helpers.findTeleportCreep(particle, now)
	if particle.targetIndex or particle.controlPoint ~= 5 or not particle.position
		or now < (particle.nextCreepSearchAt or 0)
	then return end
	particle.nextCreepSearchAt = now + 0.5
	local owner = Entity.Get(particle.ownerIndex)
	if not owner then return end
	local best, nearest, second = nil, math.huge, math.huge
	for _, creep in ipairs(NPCs.GetAll(Enum.UnitTypeFlags.TYPE_LANE_CREEP)) do
		if Entity.IsAlive(creep) and Entity.IsSameTeam(owner, creep) and not Entity.IsDormant(creep) and NPC.IsVisible(creep) then
			local distance = distance2D(Entity.GetAbsOrigin(creep), particle.position)
			if distance < nearest then best, second, nearest = creep, nearest, distance
			elseif distance < second then second = distance end
		end
	end
	if best and nearest <= 220 and (nearest <= 35 or second - nearest >= 40) then particle.targetIndex = Entity.GetIndex(best) end
end

function helpers.teleportLandingPosition(record, snapshot)
	local best
	for _, particle in pairs(state.teleportParticles or {}) do
		if not particle.departure and particle.ownerIndex == record.index and particle.position
			and math.abs(particle.createdAt - record.createdAt) <= 0.75
			and (not best or particle.createdAt > best.createdAt)
		then best = particle end
	end
	if not best then return nil end
	if best.controlPoint == 0 and not best.targetIndex then return best.position end
	if best.targetIndex then
		local target = Entity.Get(best.targetIndex)
		if not target or not Entity.IsAlive(target) then return nil end
		if not Entity.IsDormant(target) and NPC.IsVisible(target) then
			local position = copyPoint(Entity.GetAbsOrigin(target))
			if NPC.IsRunning(target) then
				local horizon = math.max(0, record.endsAt - snapshot.now)
				position = add(position, scale(normalizedForward(Entity.GetRotation(target):GetForward()), NPC.GetMoveSpeed(target) * horizon))
			end
			return position
		end
	end
	if best.velocity and best.sampledAt and snapshot.now - best.sampledAt <= 0.25 then
		return add(best.position, scale(best.velocity, math.max(0, record.endsAt - best.positionAt)))
	end
	return nil
end

function helpers.fogTeleportTarget(particle, snapshot, settings)
	if not settings.interrupt or not settings.interruptTeleports or not settings.interruptFogTeleports or not settings.interruptTornado
		or not particle or not particle.departure or not particle.position or particle.fired
		or not state.teleportParticles or state.teleportParticles[particle.index] ~= particle
	then return nil end
	local owner = Entity.Get(particle.ownerIndex)
	if not helpers.landingEnemy(owner) or not Entity.IsAlive(owner)
		or not Entity.IsDormant(owner) and NPC.IsVisible(owner)
		or NPC.HasState(owner, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE)
		or NPC.HasState(owner, Enum.ModifierState.MODIFIER_STATE_DEBUFF_IMMUNE)
		or NPC.HasState(owner, Enum.ModifierState.MODIFIER_STATE_OUT_OF_GAME)
	then return nil end
	local endsAt = particle.endsAt
	local record = state.landings and state.landings[particle.ownerIndex]
	if record and record.kind == "teleport" and math.abs(record.createdAt - particle.createdAt) <= 0.75 then
		if record.cancelled then return nil end
		if not record.estimated then endsAt = record.endsAt end
	end
	if endsAt <= snapshot.now then return nil end
	return {index = particle.ownerIndex, position = copyPoint(particle.position), fogTeleport = particle,
		teleporting = true, teleportRemaining = endsAt - snapshot.now}
end

function helpers.updateLandingTracks(snapshot, settings)
	if not settings.landingSun and not (settings.interrupt and settings.interruptTeleports and settings.interruptFogTeleports and settings.interruptTornado) then
		state.landings, state.teleportParticles, state.teleportHistory = nil, nil, nil
		return
	end
	if snapshot.now < (state.nextLandingScanAt or 0) then return end
	state.nextLandingScanAt = snapshot.now + cfg.landingScanInterval
	state.landings = state.landings or {}
	for _, unit in ipairs(Heroes.GetAll()) do
		if helpers.landingEnemy(unit) then
			local found = false
			for name in pairs(cfg.landingModifiers) do
				local modifier = NPC.GetModifier(unit, name)
				if modifier then helpers.recordLandingModifier(unit, modifier); found = true end
			end
			if not found and not Entity.IsDormant(unit) then
				local record = state.landings[Entity.GetIndex(unit)]
				if record and (not record.estimated or snapshot.now - record.createdAt > 0.2) then record.cancelled = true end
			end
		end
	end
	for index, record in pairs(state.landings) do
		if snapshot.now > record.endsAt + 1 then state.landings[index] = nil end
	end
	for index, particle in pairs(state.teleportParticles or {}) do
		if snapshot.now - particle.createdAt > cfg.teleportParticleLifetime then state.teleportParticles[index] = nil
		elseif not particle.departure then helpers.findTeleportCreep(particle, snapshot.now) end
	end
	for i = #(state.teleportHistory or {}), 1, -1 do
		if snapshot.now - state.teleportHistory[i].at > cfg.teleportHistorySeconds then table.remove(state.teleportHistory, i) end
	end
end

function helpers.landingSunWindow(record, snapshot, settings)
	if not settings.landingSun or not record or record.cancelled or record.fired
		or record.estimated and record.ambiguousTiming
		or record.kind == "teleport" and not settings.landingTeleports
		or record.kind == "cyclone" and not settings.landingCyclones
		or not helpers.hasAutoSunMana(snapshot, settings)
	then return nil end
	local unit = Entity.Get(record.index)
	if not helpers.landingEnemy(unit) or not Entity.IsAlive(unit) then return nil end
	local mechanics = resolveMechanics("sun_strike", snapshot, 0)
	local delay = mechanics.castPoint + mechanics.fixedDelay + snapshot.latency
	local castAt = record.endsAt + cfg.landingImpactOffset - delay
	local latest = record.endsAt + cfg.landingMaxLate - delay
	if snapshot.now > latest then return nil end
	local position = record.kind == "teleport" and helpers.teleportLandingPosition(record, snapshot) or record.position
	if not position then return nil end
	if record.kind == "teleport" or settings.landingLethal then
		local health, maxHealth = Entity.GetHealth(unit), Entity.GetMaxHealth(unit)
		if health <= 0 or maxHealth <= 0 then return nil end
		local horizon = math.max(delay, record.endsAt + cfg.landingImpactOffset - snapshot.now)
		local damage = mechanics.expectedDamage / sunSplitCount(snapshot, position, math.max(cfg.sunRadius, mechanics.radius), record.index, horizon)
		if math.min(maxHealth, health + math.max(0, NPC.GetHealthRegen(unit)) * horizon) > damage then return nil end
	end
	return {position = copyPoint(position), castAt = castAt, latest = latest}
end

function helpers.selectLandingSun(snapshot, settings)
	if not settings.landingSun or not helpers.objectiveSunReady(snapshot, settings) then return nil end
	local best, earliest = nil, math.huge
	for _, record in pairs(state.landings or {}) do
		local window = helpers.landingSunWindow(record, snapshot, settings)
		local preparation = snapshot.actions.sun_strike.invoked and 0 or math.max(0.16, cfg.invokeOrbInterval * 3 + 0.06 + snapshot.latency)
		if window and snapshot.now + preparation <= window.latest and window.castAt < earliest
			and snapshot.now + preparation + 0.4 >= window.castAt
		then best, earliest = record, window.castAt end
	end
	return best
end

function helpers.queueLandingSun(record, snapshot, settings)
	local window = helpers.landingSunWindow(record, snapshot, settings)
	if not window or not queueAutoAction("sun_strike", record, "landing_sun", snapshot) then return false end
	state.autoPending.landing = record
	state.autoPending.position = window.position
	state.autoPending.expiresAt = window.latest + 0.01
	state.nextAutoActionAt = snapshot.now
	logDebug("ARRIVAL", ("target=%d source=%s cast_in=%.2f aim=%.0f,%.0f"):format(record.index,
		record.estimated and "particle estimate" or "modifier", window.castAt - snapshot.now, window.position.x, window.position.y))
	return true
end

local function autoPendingRelevant(pending, target, snapshot, settings)
	if pending.kind == "fog_interrupt" then
		local source = helpers.fogTeleportTarget(pending.teleportParticle, snapshot, settings)
		return source ~= nil and interruptArrival("tornado", source, snapshot) < math.huge
	end
	if pending.kind == "landing_sun" then
		return state.landings and state.landings[pending.targetIndex] == pending.landing
			and helpers.landingSunWindow(pending.landing, snapshot, settings) ~= nil
	end
	if pending.kind == "tormentor_sun" then
		return helpers.selectTormentorSunTarget(snapshot, settings, pending.targetIndex) ~= nil
	end
	if pending.kind == "roshan_sun" then
		return snapshot.roshan and snapshot.roshan.index == pending.targetIndex
			and helpers.isRoshanSunTarget(snapshot, settings)
	end
	if pending.kind == "fountain_sun" then
		return settings.fountainSun and snapshot.gameState == Enum.GameState.DOTA_GAMERULES_STATE_PRE_GAME
			and not state.fountain.done
	end
	if pending.kind == "cataclysm_refresher" then return helpers.canAutoRefresh(snapshot, settings) end
	if pending.kind == "cataclysm" or pending.kind == "cataclysm_repeat" then
		return settings.cataclysm and snapshot.hero.upgrades.scepterChoice == "exort"
			and helpers.hasAutoSunMana(snapshot, settings, "cataclysm")
			and cataclysmTargetCount(snapshot) >= settings.cataclysmMinHeroes
	end
	if not target or not target.alive or not target.visible or target.dormant or target.invulnerable or target.outOfGame then return false end
	if pending.kind == "interrupt" then
		return settings.interrupt and not target.debuffImmune
			and (target.channeling or settings.interruptTeleports and target.teleporting)
			and interruptArrival(pending.actionId, target, snapshot) < math.huge
	end
	if pending.kind == "quick_sun" then return true end
	return isAutoSunTarget(target, snapshot, settings)
end

function helpers.canAutoRefresh(snapshot, settings)
	local refresher = snapshot.actions.item_refresher
	local sun = snapshot.actions.cataclysm
	if not settings.cataclysm or not settings.cataclysmRefresher
		or snapshot.hero.upgrades.scepterChoice ~= "exort"
		or not refresher.exists or not refresher.activated or not refresher.canCast or refresher.cooldown > 0.05
		or not sun.exists or sun.cooldown <= 0.05 or not sun.invoked
		or snapshot.hero.mana - refresher.manaCost - sun.manaCost < snapshot.hero.maxMana * settings.sunMinMana / 100
	then
		return false
	end
	local impactAt = snapshot.now + helpers.sunImpactDelay(snapshot, "cataclysm")
		+ refresher.castPoint + snapshot.latency * 2 + cfg.commandGap
	local count = 0
	for _, enemy in ipairs(snapshot.enemies) do
		if enemy.alive and enemy.visible and not enemy.dormant and not enemy.invulnerable and not enemy.outOfGame
			and math.max(enemy.disabledUntil, enemy.controlEndsAt) >= impactAt
		then
			count = count + 1
		end
	end
	return count >= settings.cataclysmMinHeroes
end

function helpers.findEnemyFountain()
    local enemy = LIB_HEROES_DATA.fountains.enemy
    local my = LIB_HEROES_DATA.fountains.my

    if not enemy or not enemy.pos or not my or not my.pos then
        return nil
    end

    local direction = enemy.pos:DirectionTo(my.pos)

    local spawn_pos = enemy.pos - direction:Scaled(-600)

    return copyPoint(spawn_pos)
end

function helpers.processFountainOpener(snapshot, settings)
	local opener = state.fountain
	if not settings.fountainSun or opener.done or opener.queued
		or snapshot.gameState ~= Enum.GameState.DOTA_GAMERULES_STATE_PRE_GAME
		or snapshot.hero.level ~= 1
	then
		return false
	end
	if not opener.position then
		opener.position = helpers.findEnemyFountain(snapshot.hero.entity)
		if not opener.position then return false end
	end
	if snapshot.hero.orbLevels.exort == 0 then
		if snapshot.hero.abilityPoints <= 0 then return false end
		if snapshot.now < opener.nextTrainAt then return true end
		if opener.trainAttempts >= 2 then
			opener.done = true
			setStatus("aborted", "Fountain opener: Exort training was not confirmed.")
			return false
		end
		local exort = state.bindings.orbs.exort
		if not exort then return false end
		issueOrder(function()
			Player.PrepareUnitOrders(state.player, Enum.UnitOrder.DOTA_UNIT_ORDER_TRAIN_ABILITY, nil, Vector(0, 0, 0), exort,
				Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, state.hero, false, true, false, true, "invoker_auto", false)
		end)
		opener.trainAttempts = opener.trainAttempts + 1
		opener.nextTrainAt = snapshot.now + 0.75
		setStatus("preparing", "Fountain opener: learning Exort.")
		return true
	end
	if queueAutoAction("sun_strike", {}, "fountain_sun", snapshot) then
		state.autoPending.position = copyPoint(opener.position)
		state.autoPending.expiresAt = snapshot.now + 4
		state.nextAutoActionAt = snapshot.now
		opener.queued = true
		return true
	end
	return false
end

function helpers.advanceAutoCataclysm(pending, snapshot, settings)
	local id, kind
	if pending.kind == "cataclysm" and helpers.canAutoRefresh(snapshot, settings) then
		id, kind = "item_refresher", "cataclysm_refresher"
	elseif pending.kind == "cataclysm_refresher" and settings.cataclysm and settings.cataclysmRefresher then
		id, kind = "cataclysm", "cataclysm_repeat"
	end
	if not id then return false end
	state.autoPending = {actionId = id, kind = kind, targetIndex = pending.targetIndex,
		expiresAt = snapshot.now + 2.2, attempts = 0}
	state.nextAutoActionAt = snapshot.now
	return true
end

local function processAutoPending(snapshot, settings)
	local pending = state.autoPending
	if not pending then return false end
	local id = pending.actionId
	if pending.cast then
		if castConfirmed(pending.cast, snapshot) then
			if pending.kind == "fog_interrupt" then
				for _, particle in pairs(state.teleportParticles or {}) do
					if particle.departure and particle.ownerIndex == pending.targetIndex
						and math.abs(particle.createdAt - pending.teleportParticle.createdAt) <= 0.75
					then particle.fired = true end
				end
			end
			if pending.kind == "landing_sun" then pending.landing.fired = true end
			if helpers.advanceAutoCataclysm(pending, snapshot, settings) then return true end
			if pending.kind == "fountain_sun" then state.fountain.done = true end
			state.autoPending = nil
			state.nextAutoActionAt = snapshot.now + 0.18
			setStatus("preparing", definitions[id].short .. " confirmed.")
			if id == "cold_snap" then
				local target = findEnemy(snapshot, pending.targetIndex)
				if target then attackTarget(target.entity, false) end
			end
			return true
		end
		if snapshot.now < pending.cast.deadline then return true end
		pending.cast = nil
		if pending.attempts < 2 then
			state.nextAutoActionAt = snapshot.now + 0.04
			setStatus("waiting", definitions[id].short .. " was not confirmed; retrying once.")
			return true
		end
		state.autoPending = nil
		state.nextAutoActionAt = snapshot.now + 0.18
		setStatus("waiting", "Skipped " .. definitions[id].short .. ": cast was not confirmed.")
		return true
	end
	local target = findEnemy(snapshot, pending.targetIndex)
	if pending.kind == "landing_sun" then
		local window = helpers.landingSunWindow(pending.landing, snapshot, settings)
		if window then pending.expiresAt = window.latest + 0.01 end
	end
	if snapshot.now >= pending.expiresAt or not autoPendingRelevant(pending, target, snapshot, settings) then
		state.autoPending = nil
		if isInvoking(id) then state.invokeSequence = nil end
		return false
	end
	if pending.kind == "roshan_sun" then pending.position = copyPoint(snapshot.roshan.position) end
	if pending.kind == "fog_interrupt" then
		pending.position = copyPoint(pending.teleportParticle.position)
	end
	if pending.kind == "tormentor_sun" then
		for _, objective in ipairs(snapshot.tormentors) do
			if objective.index == pending.targetIndex then pending.position = copyPoint(objective.position); break end
		end
	end
	local action = snapshot.actions[id]
	if not action or not action.exists or action.cooldown > 0.05 then
		setStatus("waiting", definitions[id].short .. " is not ready.")
		return true
	end
	if isSpell(id) and not action.invoked then
		if not isInvoking(id) and snapshot.invoke.ready and queueInvoke(id, false) then
			state.nextAutoActionAt = snapshot.now + math.max(0.18, snapshot.latency * 2 + 0.08)
		end
		setStatus("preparing", "Automatic " .. pending.kind .. ": preparing " .. definitions[id].name .. ".")
		return true
	end
	if isInvoking(id) then return true end
	if snapshot.now < state.nextAutoActionAt then return true end
	if pending.kind == "landing_sun" then
		local window = helpers.landingSunWindow(pending.landing, snapshot, settings)
		if not window then state.autoPending = nil; return false end
		pending.position = window.position
		if snapshot.now < window.castAt then
			setStatus("waiting", ("Sun Strike arrival in %.2fs."):format(window.castAt - snapshot.now))
			return true
		end
	end
	local position = pending.position or target and target.position or snapshot.hero.position
	if pending.kind == "fog_interrupt" then
		position = add(snapshot.hero.position, scale(normalized2D(subtract(position, snapshot.hero.position)), 100))
	end
	if not pending.position and (id == "tornado" or id == "sun_strike") then
		position = predictIntercept(snapshot, id, target, snapshot.now, target.motionConfidence).position
	end
	if id == "sun_strike" and not pending.position then
		local mechanics = resolveMechanics("sun_strike", snapshot, 0)
		local splitCount = sunSplitCount(snapshot, position, math.max(cfg.sunRadius, mechanics.radius), target.index, helpers.sunImpactDelay(snapshot, id))
		local expectedDamage = mechanics.expectedDamage / splitCount
		logDebug("AUTO SUN", ("target=%d health=%.0f damage=%.0f split=%d position=%.0f,%.0f aim=%.0f,%.0f velocity=%.0f,%.0f walking=%.2f stable=%.2f idle=%.2f confidence=%.2f"):format(
			target.index,
			target.health,
			expectedDamage,
			splitCount,
			target.position.x,
			target.position.y,
			position.x,
			position.y,
			target.velocity.x,
			target.velocity.y,
			target.movementDuration,
			target.stableDuration,
			target.idleDuration,
			target.motionConfidence
		))
	end
	local kind, result = castAction({actionId = id, targetIndex = not pending.position and target and target.index or nil,
		position = position, exactPosition = pending.kind == "landing_sun" or pending.kind == "fog_interrupt"}, snapshot)
	if kind == "issued" then
		pending.attempts = pending.attempts + 1
		pending.cast = {
			action = {actionId = id},
			issuedAt = result.issuedAt,
			cooldownBefore = result.cooldownBefore,
			secondsBefore = result.secondsBefore,
			deadline = result.issuedAt + math.max(cfg.castConfirmMin, action.castPoint + snapshot.latency * 2 + 0.35),
		}
		state.nextAutoActionAt = snapshot.now + 0.18
		setStatus("confirming", ("%s: %s order issued."):format(pending.kind, definitions[id].name))
	elseif kind == "move" or kind == "wait" then
		setStatus(kind == "move" and "moving" or "waiting", result)
		state.nextAutoActionAt = snapshot.now + 0.06
	else
		setStatus("waiting", result)
		state.nextAutoActionAt = snapshot.now + 0.06
	end
	return true
end

---Selects Quas, Wex, or Exort while respecting the manual-order pause.
---@param snapshot InvokerSnapshot
---@param settings table
---@param comboActive boolean
---@return boolean
local function updateAutoOrbs(snapshot, settings, comboActive)
	if not settings.orbs or snapshot.now < state.autoOrbsPausedUntil or isInvoking() then return false end
	local nextAction = comboActive and nextPlanAction() or nil
	if comboActive and (state.pendingCast
		or state.statusPhase == "confirming"
		or state.statusPhase == "moving"
		or nextAction and nextAction.movingForRange)
	then
		state.orbSequence = nil
		return false
	end
	if not snapshot.hero.moving then
		state.walkingSince = math.huge
	elseif state.walkingSince == math.huge then
		state.walkingSince = snapshot.now
	end
	local levels = snapshot.hero.orbLevels
	local desired
	if settings.quas and levels.quas > 0 and snapshot.hero.health / math.max(1, snapshot.hero.maxHealth) <= settings.quasHealth / 100 then
		desired = "quas"
	elseif settings.wex and levels.wex > 0 and snapshot.hero.moving and snapshot.now - state.walkingSince >= settings.wexWalkTime then
		desired = "wex"
	elseif settings.exort and levels.exort > 0 and snapshot.hero.attacking then
		desired = "exort"
	end
	local maySwitch = not comboActive or settings.orbMode == "always"
	if desired and maySwitch and snapshot.now >= state.nextAutoOrbAt and queueOrbSwitch(desired) then
		state.nextAutoOrbAt = snapshot.now + 0.75
		setStatus("preparing", "Auto Orbs: " .. desired .. ".")
		return true
	end
	return false
end

local function processManualCraft(snapshot)
	local id = state.manualCraft
	if not id then return false end
	state.manualCraft = nil
	if not recipeAvailable(definitions[id].recipe, snapshot.hero.orbLevels) then
		setStatus("aborted", definitions[id].name .. ": required orb is not learned.")
		return true
	end
	if snapshot.invoke.invoked[1] == id then
		setStatus("complete", definitions[id].name .. " is already in the first slot.")
		return true
	end
	if not snapshot.invoke.ready then
		setStatus("waiting", ("Invoke is on cooldown for %.1fs."):format(snapshot.invoke.cooldown))
		return true
	end
	if state.plan then abortPlan("Manual spell crafting took priority.") end
	state.autoPending = nil
	state.automaticActionsPausedUntil = snapshot.now + cfg.manualActionPause
	state.autoOrbsPausedUntil = snapshot.now + ui.manualOrderPause:Get() / 10
	state.invokeSequence = nil
	local reorder = contains(snapshot.invoke.invoked, id)
	if queueInvoke(id, reorder) then
		state.invokeSequence.manual = true
		setStatus(
			"preparing",
			reorder and "Moving " .. definitions[id].name .. " to the first slot."
				or "Preparing " .. definitions[id].name .. "."
		)
	else
		setStatus("aborted", definitions[id].name .. " could not be prepared.")
	end
	return true
end

function helpers.idlePreparationAllowed(settings)
	return settings.autoPrepare and (not settings.precastHold or ui.precastBind:IsDown())
end

function helpers.cancelIdlePreparation(settings)
	if state.invokeSequence and state.invokeSequence.idlePreparation and not helpers.idlePreparationAllowed(settings) then
		state.invokeSequence = nil
	end
end

function helpers.idleComboActions(snapshot, settings)
	if settings.slot ~= "D" then return selectedComboActions(snapshot, settings, false) end
	if snapshot.target or snapshot.targetMode == "cursor" then
		local dynamic = {}
		for key, value in pairs(settings.dynamic) do dynamic[key] = value end
		dynamic.castCraftedFirst = false
		local candidate = dynamicPlan(snapshot, dynamic)
		if candidate then return candidate.actions end
	end
	local actions = {}
	for _, id in ipairs({"cold_snap", "tornado", "emp", "chaos_meteor", "sun_strike", "deafening_blast", "forge_spirit", "alacrity", "ice_wall"}) do
		if dynamicActionEnabled(id, snapshot, settings.dynamic) and actionAvailable(id, snapshot, true) then
			actions[#actions + 1] = id
		end
	end
	return actions
end

local function idlePrepare(snapshot, settings)
	if state.bindPreparedSpell then
		local action = snapshot.actions[state.bindPreparedSpell]
		if contains(snapshot.invoke.invoked, state.bindPreparedSpell) and action.cooldown <= 0.05 then return false end
		state.bindPreparedSpell = nil
	end
	if not helpers.idlePreparationAllowed(settings)
		or settings.slot == "D" and settings.precastMode ~= "always"
		or snapshot.paused or not snapshot.activeGame or not snapshot.hero.alive
		or snapshot.hero.silenced or snapshot.hero.stunned or snapshot.hero.channeling
		or snapshot.hero.invisible and not snapshot.hero.ghostWalk
		or snapshot.now < state.automaticActionsPausedUntil or isInvoking()
		or snapshot.now < state.nextIdlePrepareAt or not snapshot.invoke.ready
	then
		return
	end
	local actions = helpers.idleComboActions(snapshot, settings)
	if not actions then return end
	local desired = {}
	for _, actionId in ipairs(actions) do
		if isSpell(actionId) and (snapshot.targetMode ~= "cursor" or not isUnitTarget(actionId)
			or actionId == "cold_snap" and contains(actions, "tornado"))
		then
			local id = canonicalSpell(actionId)
			local action = snapshot.actions[id]
			if action and action.exists and action.learned and action.cooldown <= 0.05
				and recipeAvailable(definitions[id].recipe, snapshot.hero.orbLevels)
			then
				pushUnique(desired, id)
			end
			if #desired == 2 then break end
		end
	end
	for _, id in ipairs(desired) do
		if not contains(snapshot.invoke.invoked, id) then
			local preserve = snapshot.invoke.invoked[2]
			local reorder = preserve ~= nil and contains(desired, preserve)
			local prepare = reorder and preserve or id
			if not queueInvoke(prepare, reorder) then return end
			state.invokeSequence.idlePreparation = true
			state.nextIdlePrepareAt = snapshot.now + math.max(1.25, snapshot.invoke.cooldownLength + 0.25)
			setStatus("preparing", "Idle preparation: " .. definitions[prepare].name .. ".")
			return
		end
	end
end

local function rectContains(rect, x, y)
	return rect
		and x >= rect.x
		and y >= rect.y
		and x <= rect.x + rect.width
		and y <= rect.y + rect.height
end

local function panelActions()
	if state.panel.selectedSlot == "D" then return state.dynamicPreview end
	return state.combos[state.panel.selectedSlot] or {}
end

local function comboPanelSize(settings)
	local scaleValue = settings.panel.scale
	local actions = panelActions()
	if state.panel.expanded then
		return {
			width = 420 * scaleValue,
			height = (246 + math.ceil(#allActionIds / 10) * 40) * scaleValue,
		}
	end
	if settings.panel.orientation == "vertical" then
		return {
			width = 205 * scaleValue,
			height = ((settings.panel.compact and 62 or 41) + math.max(1, math.min(8, #actions)) * 34) * scaleValue,
		}
	end
	return {
		width = 292 * scaleValue,
		height = (settings.panel.compact and 96 or 75) * scaleValue,
	}
end

local function selectPanelSlot(slot)
	if state.panel.selectedSlot == slot then return end
	state.panel.selectedSlot = slot
	savePanelState()
end

function helpers.updateComboSelectionBinds(snapshot)
	state.comboSelectionKeys = state.comboSelectionKeys or {}
	local blocked = snapshot.paused or Input.IsInputCaptured()
	for _, slot in ipairs(panelSlots) do
		local down = ui["bindSelect_" .. slot]:IsDown()
		if down and not state.comboSelectionKeys[slot] and not blocked then selectPanelSlot(slot) end
		state.comboSelectionKeys[slot] = down
	end
end

function helpers.toggleComboStrict()
	local slot = state.panel.selectedSlot
	if slot == "D" then return end
	state.comboStrict[slot] = not state.comboStrict[slot]
	Config.WriteInt(cfg.configName, "combo_strict_" .. slot, state.comboStrict[slot] and 1 or 0)
end

function helpers.setBindIslandVisible(visible)
	if state.bindIslandVisible == visible then return end
	state.bindIslandVisible = visible
	for _, bind in ipairs(helpers.bindControls) do bind:ShowInBindIsland(visible) end
end

function helpers.updateBindIsland()
	local hero = Engine.IsInGame() and Heroes.GetLocal() or nil
	helpers.setBindIslandVisible(hero ~= nil and NPC.GetUnitName(hero) == cfg.heroName and ui.enabled:Get())
end

function helpers.positionComboPanel(panel, size, screen)
	panel.anchorX = panel.anchorX or panel.x
	panel.anchorY = panel.anchorY or panel.y
	panel.x = clamp(panel.anchorX, 4, math.max(4, screen.x - size.width - 4))
	panel.y = clamp(panel.anchorY, 4, math.max(4, screen.y - size.height - 4))
end

local function panelDynamicActionEnabled(id)
	if definitions[id].kind == "spell" then
		return id ~= "ghost_walk" and state.dynamicSpells[id] == true
	end
	return ui.items:Get(id)
end

local function toggleDynamicAction(id)
	state.settingsCache = nil
	if definitions[id].kind == "spell" then
		if id == "ghost_walk" then return end
		state.dynamicSpells[id] = not state.dynamicSpells[id]
		saveDynamicSpells()
	else
		ui.items:Set(id, not ui.items:Get(id))
	end
	if not panelDynamicActionEnabled(id) then
		local filtered = {}
		for _, actionId in ipairs(state.dynamicPreview) do
			if actionId ~= id then filtered[#filtered + 1] = actionId end
		end
		state.dynamicPreview = filtered
	end
end

local function addComboAction(slot, id)
	local actions = state.combos[slot]
	if not actions or #actions >= cfg.maxComboActions then return end
	local proposed = arrayCopy(actions)
	proposed[#proposed + 1] = id
	if not comboSequenceValid(proposed) then return end
	state.combos[slot] = proposed
	saveComboSlot(slot)
end

local function removeComboAction(slot, index)
	local actions = state.combos[slot]
	if not actions or not actions[index] then return end
	table.remove(actions, index)
	saveComboSlot(slot)
end

local function moveComboAction(slot, from, to)
	local actions = state.combos[slot]
	if not actions or from == to or not actions[from] or not actions[to] then return end
	local proposed = arrayCopy(actions)
	local action = table.remove(proposed, from)
	table.insert(proposed, to, action)
	if not comboSequenceValid(proposed) then return end
	state.combos[slot] = proposed
	saveComboSlot(slot)
end

local function clearComboSlot(slot)
	if slot == "D" then return end
	state.combos[slot] = {}
	saveComboSlot(slot)
end

local function findPanelHitbox(hitboxes, x, y)
	for _, hitbox in ipairs(hitboxes) do
		local rect = hitbox.rect or hitbox
		if rectContains(rect, x, y) then return hitbox end
	end
	return nil
end

local function updateComboPanelInput(settings)
	local panel = state.panel
	local leftDown = Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE1, false)
	if not settings.panel.show or Input.IsInputCaptured() then
		panel.leftWasDown = leftDown
		panel.dragging = false
		panel.dragFrom = nil
		return
	end

	local pressed = leftDown and not panel.leftWasDown
	local released = not leftDown and panel.leftWasDown
	local cursorX, cursorY = Input.GetCursorPos()
	if pressed then
		local slot = findPanelHitbox(panel.slotHitboxes, cursorX, cursorY)
		if slot then
			selectPanelSlot(slot.slot)
		elseif rectContains(panel.expand, cursorX, cursorY) then
			panel.expanded = not panel.expanded
			savePanelState()
		elseif panel.expanded and rectContains(panel.clear, cursorX, cursorY) then
			clearComboSlot(panel.selectedSlot)
		elseif panel.expanded and rectContains(panel.strict, cursorX, cursorY) then
			helpers.toggleComboStrict()
		elseif panel.expanded then
			local palette = findPanelHitbox(panel.paletteHitboxes, cursorX, cursorY)
			local combo = findPanelHitbox(panel.comboHitboxes, cursorX, cursorY)
			if palette and panel.selectedSlot == "D" then
				toggleDynamicAction(palette.id)
			elseif palette then
				addComboAction(panel.selectedSlot, palette.id)
			elseif combo and panel.selectedSlot ~= "D" then
				panel.dragFrom = combo.index
			elseif rectContains(panel.header, cursorX, cursorY) then
				panel.dragging = true
				panel.dragOffsetX = cursorX - panel.x
				panel.dragOffsetY = cursorY - panel.y
			end
		elseif rectContains(panel.header, cursorX, cursorY) then
			panel.dragging = true
			panel.dragOffsetX = cursorX - panel.x
			panel.dragOffsetY = cursorY - panel.y
		end
	end

	if leftDown and panel.dragging then
		local screen = Render.ScreenSize()
		local size = comboPanelSize(settings)
		panel.x = math.floor(clamp(cursorX - panel.dragOffsetX, 4, math.max(4, screen.x - size.width - 4)) + 0.5)
		panel.y = math.floor(clamp(cursorY - panel.dragOffsetY, 4, math.max(4, screen.y - size.height - 4)) + 0.5)
	end

	if panel.dragging then panel.anchorX, panel.anchorY = panel.x, panel.y end
	if released then
		if panel.dragging then
			panel.dragging = false
			savePanelState()
		end
		if panel.dragFrom and panel.selectedSlot ~= "D" then
			local destination = findPanelHitbox(panel.comboHitboxes, cursorX, cursorY)
			if destination and destination.index ~= panel.dragFrom then
				moveComboAction(panel.selectedSlot, panel.dragFrom, destination.index)
			else
				local origin
				for _, hitbox in ipairs(panel.comboHitboxes) do
					if hitbox.index == panel.dragFrom then origin = hitbox; break end
				end
				if rectContains(origin, cursorX, cursorY) then
					removeComboAction(panel.selectedSlot, panel.dragFrom)
				end
			end
			panel.dragFrom = nil
		end
	end
	panel.leftWasDown = leftDown
end

local function spellBarGeometry(settings)
	local spellBar = state.spellBar
	local screen = Render.ScreenSize()
	local cached = spellBar.geometryCache
	if cached and cached.screenX == screen.x and cached.screenY == screen.y
		and cached.x == spellBar.x and cached.y == spellBar.y
		and cached.scale == settings.spellBar.scale and cached.layout == settings.spellBar.layout
		and cached.positioned == spellBar.positioned
	then
		return cached.geometry
	end
	local resolutionScale = clamp(screen.y / 1080, 0.72, 1.35)
	local scaleValue = settings.spellBar.scale * resolutionScale
	local iconSize = 42 * scaleValue
	local gap = 5 * scaleValue
	local padding = 8 * scaleValue
	local gripHeight = 8 * scaleValue
	local columns = settings.spellBar.layout == "grid" and 3 or #renderCtx.craftIds
	local rows = math.ceil(#renderCtx.craftIds / columns)
	local width = padding * 2 + columns * iconSize + math.max(0, columns - 1) * gap
	local height = padding * 2 + gripHeight + rows * iconSize + math.max(0, rows - 1) * gap
	if not spellBar.positioned then
		spellBar.x = math.floor((screen.x - width) * 0.5 + 0.5)
		spellBar.y = math.floor(screen.y - 300 * resolutionScale - height + 0.5)
	end
	spellBar.x = clamp(spellBar.x, 4, math.max(4, screen.x - width - 4))
	spellBar.y = clamp(spellBar.y, 4, math.max(4, screen.y - height - 4))
	local geometry = {
		scale = scaleValue,
		panel = {x = spellBar.x, y = spellBar.y, width = width, height = height},
		grip = {x = spellBar.x + padding, y = spellBar.y, width = width - padding * 2, height = padding + gripHeight},
		icons = {},
	}
	for index, id in ipairs(renderCtx.craftIds) do
		local column = (index - 1) % columns
		local row = math.floor((index - 1) / columns)
		geometry.icons[#geometry.icons + 1] = {
			id = id,
			x = spellBar.x + padding + column * (iconSize + gap),
			y = spellBar.y + padding + gripHeight + row * (iconSize + gap),
			width = iconSize,
			height = iconSize,
		}
	end
	spellBar.geometryCache = {screenX = screen.x, screenY = screen.y, x = spellBar.x, y = spellBar.y,
		scale = settings.spellBar.scale, layout = settings.spellBar.layout, positioned = spellBar.positioned, geometry = geometry}
	return geometry
end

local function applySpellBarGeometry(geometry)
	state.spellBar.panelRect = geometry.panel
	state.spellBar.gripRect = geometry.grip
	state.spellBar.hitboxes = geometry.icons
end

local function updateSpellBarInput(snapshot, settings)
	local spellBar = state.spellBar
	local leftDown = Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE1, false)
	local pressed = leftDown and not spellBar.leftWasDown
	local released = not leftDown and spellBar.leftWasDown
	spellBar.leftWasDown = leftDown
	if not settings.spellBar.show or not snapshot.activeGame or not snapshot.hero.alive or Input.IsInputCaptured() then
		if spellBar.dragging and released then saveSpellBarState() end
		spellBar.dragging = false
		return
	end

	local geometry = spellBarGeometry(settings)
	applySpellBarGeometry(geometry)
	local cursorX, cursorY = Input.GetCursorPos()
	if spellBar.dragging then
		if leftDown then
			local screen = Render.ScreenSize()
			spellBar.x = clamp(cursorX - spellBar.dragOffsetX, 4, math.max(4, screen.x - geometry.panel.width - 4))
			spellBar.y = clamp(cursorY - spellBar.dragOffsetY, 4, math.max(4, screen.y - geometry.panel.height - 4))
			spellBar.positioned = true
			applySpellBarGeometry(spellBarGeometry(settings))
		else
			spellBar.dragging = false
			saveSpellBarState()
		end
		return
	end
	if not pressed then return end
	if rectContains(spellBar.gripRect, cursorX, cursorY) then
		spellBar.dragging = true
		spellBar.dragOffsetX = cursorX - spellBar.x
		spellBar.dragOffsetY = cursorY - spellBar.y
		return
	end
	local spell = findPanelHitbox(spellBar.hitboxes, cursorX, cursorY)
	if spell then state.manualCraft = spell.id end
end

---Runs one gameplay update for input, automation, planning, and execution.
function helpers.cancelBind(reason, stop, retry)
	local job = state.bindJob
	if not job then return end
	state.bindJob = nil
	if job.kind ~= "spell" then state.bindBlocked[job.kind] = retry and GameRules.GetGameTime() + 2 or true end
	if state.invokeSequence and state.invokeSequence.owner == "bind" then state.invokeSequence = nil end
	if stop and job.moving and state.snapshot and not state.snapshot.hero.channeling
		and not state.snapshot.hero.inAbilityPhase
	then
		state.moveOrder = nil
		issueOrder(function()
			Player.PrepareUnitOrders(state.player, Enum.UnitOrder.DOTA_UNIT_ORDER_STOP, nil, nil, nil,
				Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, state.hero,
				false, false, false, true, "invoker_auto", false)
		end)
	end
	state.nextIdlePrepareAt = GameRules.GetGameTime() + 0.5
	setStatus("idle", reason)
end

function helpers.startBind(job, snapshot)
	helpers.cancelBind("Another bind took priority.", false)
	if state.plan then abortPlan("Bind took priority.") end
	state.autoPending = nil
	state.invokeSequence = nil
	state.orbSequence = nil
	state.bindPreparedSpell = nil
	state.bindJob = job
	job.expiresAt = snapshot.now + (job.kind == "farm" and 35 or 10)
	job.nextOrderAt = 0
end

function helpers.bindMove(job, point, snapshot)
	if snapshot.now < job.nextOrderAt then return end
	moveTo(point)
	job.attackIndex = nil
	job.nextOrderAt = snapshot.now + 0.2
	job.moving = true
end

function helpers.bindStop(job)
	if not job.moving then return end
	state.moveOrder = nil
	issueOrder(function()
		Player.PrepareUnitOrders(state.player, Enum.UnitOrder.DOTA_UNIT_ORDER_STOP, nil, nil, nil,
			Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, state.hero,
			false, false, false, true, "invoker_auto", false)
	end)
	job.moving = false
	job.attackIndex = nil
end

function helpers.bindFace(job, direction, snapshot)
	if dot2D(normalizedForward(snapshot.hero.facing), direction) >= math.cos(0.10) then
		helpers.bindStop(job)
		job.faceStartedAt = nil
		return true
	end
	job.faceStartedAt = job.faceStartedAt or snapshot.now
	if snapshot.now - job.faceStartedAt > 1.5 then
		helpers.cancelBind("Ice Wall aim could not align in time.", true)
		return false
	end
	if snapshot.now >= job.nextOrderAt then
		issueOrder(function()
			Player.PrepareUnitOrders(state.player, Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_DIRECTION, nil,
				toVector(add(snapshot.hero.position, scale(direction, 100))), nil,
				Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, state.hero,
				false, false, false, true, "invoker_auto", false)
		end)
		job.nextOrderAt = snapshot.now + 0.25
		job.moving = true
		setStatus("moving", "Aiming Ice Wall.")
	end
	return false
end

function helpers.bindPrepare(id, firstSlot, snapshot)
	if state.invokeSequence then
		updateInvokeSequence(snapshot)
		return false
	end
	if firstSlot and snapshot.invoke.invoked[1] == id
		or not firstSlot and contains(snapshot.invoke.invoked, id)
	then
		return true
	end
	if not recipeAvailable(definitions[id].recipe, snapshot.hero.orbLevels) then
		helpers.cancelBind("Required orbs are not learned.", true)
		return false
	end
	if queueInvoke(id, firstSlot and contains(snapshot.invoke.invoked, id)) then
		state.invokeSequence.owner = "bind"
		state.invokeSequence.manual = true
	end
	setStatus("preparing", "Preparing " .. definitions[id].name .. ".")
	return false
end

function helpers.bindCast(job, request, snapshot)
	if job.pending then
		if castConfirmed(job.pending, snapshot) then job.pending = nil; return true end
		if snapshot.now - job.pending.issuedAt > cfg.castConfirmMin + snapshot.latency then
			helpers.cancelBind("Bind cast was not confirmed.", true)
		end
		return false
	end
	if snapshot.now < job.nextOrderAt then return false end
	local result, detail = castAction(request, snapshot)
	job.nextOrderAt = snapshot.now + 0.15
	if result == "issued" then
		detail.action = {actionId = request.actionId}
		job.pending = detail
		job.moving = false
	elseif result == "move" then
		job.moving = true
	elseif result == "invalid" then
		helpers.cancelBind(detail, true)
	end
	return false
end

function helpers.bindWallRequest(job, snapshot, point, forward)
	local stats = iceWallStats(snapshot)
	local request = {actionId = "ice_wall", position = point, exactPosition = true}
	if snapshot.hero.upgrades.scepterChoice == "quas" then
		local wall = planIceFloe(snapshot.hero.position, point, {x = 0, y = 0, z = 0}, stats, false)
		if forward then
			local side = {x = -forward.y, y = forward.x, z = 0}
			wall.vectorStart = add(point, scale(side, stats.floeLength * 0.5))
			wall.vectorEnd = add(point, scale(side, -stats.floeLength * 0.5))
			if distance2D(snapshot.hero.position, wall.vectorStart) < distance2D(snapshot.hero.position, wall.vectorEnd) then
				wall.vectorStart, wall.vectorEnd = wall.vectorEnd, wall.vectorStart
			end
		end
		request.vectorStart, request.vectorEnd = wall.vectorStart, wall.vectorEnd
		return request
	end
	local wall = job.wallAim
	if not wall or distance2D(wall.position, point) > 80 then
		wall = forward and {forward = copyPoint(forward)} or planIceWall(snapshot.hero.position, snapshot.hero.facing, point, stats)
		wall.position = copyPoint(point)
		job.wallAim = wall
		job.faceStartedAt = nil
	end
	if not wall.positioned and wall.standPosition and distance2D(snapshot.hero.position, wall.standPosition) > 30 then
		helpers.bindMove(job, wall.standPosition, snapshot)
		setStatus("moving", "Moving to place Ice Wall through the target.")
		return nil
	end
	if not wall.positioned then
		wall.positioned = true
		if job.moving or snapshot.hero.moving then
			job.moving = true
			helpers.bindStop(job)
			return nil
		end
	end
	if not helpers.bindFace(job, wall.forward, snapshot) then return nil end
	local delta = subtract(point, snapshot.hero.position)
	local facing = normalizedForward(snapshot.hero.facing)
	if math.abs(dot2D(delta, facing) - stats.placeDistance) > 65
		or math.abs(delta.x * facing.y - delta.y * facing.x) > stats.totalLength * 0.5
	then
		job.wallAim = nil
		job.wallAimRetries = (job.wallAimRetries or 0) + 1
		if job.wallAimRetries >= 3 then helpers.cancelBind("Ice Wall target left the placement area.", true) end
		return nil
	end
	job.nextOrderAt = snapshot.now
	return request
end

function helpers.updateSpellBind(job, snapshot)
	if job.pending then
		if helpers.bindCast(job, {actionId = job.id}, snapshot) then helpers.cancelBind("Bind cast confirmed.", false) end
		return
	end
	if not helpers.bindPrepare(job.id, not job.quick, snapshot) then return end
	if not job.quick then
		state.bindPreparedSpell = job.id
		helpers.cancelBind("Spell prepared.", false)
		return
	end
	local request = {actionId = job.id, position = job.position, targetIndex = job.targetIndex, exactPosition = true}
	if job.targetIndex then
		local target = Entity.Get(job.targetIndex)
		if not target or not Entity.IsAlive(target) or Entity.IsDormant(target) or not NPC.IsVisible(target)
			or NPC.HasState(target, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE)
			or NPC.HasState(target, Enum.ModifierState.MODIFIER_STATE_DEBUFF_IMMUNE)
		then
			helpers.cancelBind("Bind target is no longer available.", true)
			return
		end
	end
	if job.id == "ice_wall" and (job.aimWall or snapshot.hero.upgrades.scepterChoice == "quas") then
		local facing = not job.aimWall and normalizedForward(snapshot.hero.facing) or nil
		local point = facing and add(snapshot.hero.position, scale(facing, iceWallStats(snapshot).placeDistance)) or job.position
		request = helpers.bindWallRequest(job, snapshot, point, facing)
		if not request then return end
	end
	helpers.bindCast(job, request, snapshot)
end

function helpers.closestBindTarget(snapshot, position)
	local target, best = nil, cfg.targetRadius
	for _, enemy in ipairs(snapshot.enemies) do
		if enemy.alive and enemy.visible and not enemy.dormant and not enemy.invulnerable
			and not enemy.outOfGame and not enemy.magicImmune and not enemy.debuffImmune
		then
			local distance = distance2D(position, enemy.position)
			if distance < best then target, best = enemy, distance end
		end
	end
	return target
end

function helpers.insideCamp(point, camp, margin)
	return point.x >= camp.box.min.x - margin and point.x <= camp.box.max.x + margin
		and point.y >= camp.box.min.y - margin and point.y <= camp.box.max.y + margin
end

function helpers.campCreep(unit)
	local resistance = NPC.GetModifierProperty(unit, Enum.ModifierFunction.MODIFIER_PROPERTY_STATUS_RESISTANCE)
	local stacking = NPC.GetModifierProperty(unit, Enum.ModifierFunction.MODIFIER_PROPERTY_STATUS_RESISTANCE_STACKING)
	return {
		index = Entity.GetIndex(unit), position = copyPoint(Entity.GetAbsOrigin(unit)),
		hull = NPC.GetHullRadius(unit), attackRange = NPC.GetAttackRange(unit) + NPC.GetAttackRangeBonus(unit),
		moving = NPC.IsRunning(unit), moveSpeed = NPC.GetMoveSpeed(unit),
		forward = copyPoint(Entity.GetRotation(unit):GetForward()),
		liftFactor = clamp((1 - resistance / 100) * (1 - stacking / 100), 0, 1),
		immune = NPC.HasState(unit, Enum.ModifierState.MODIFIER_STATE_DEBUFF_IMMUNE)
			or NPC.HasState(unit, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE),
	}
end

function helpers.nearbyCamps(snapshot, allowUnseen)
	local camps = {}
	for index, camp in pairs(JungleCampsManager.camps) do
		local distance = distance2D(snapshot.hero.position, camp.position_)
		if distance <= cfg.campSearchRadius and (allowUnseen or camp.stacks_cache.invisible_count == 0) then
			local record = {index = index, position = copyPoint(camp.position_), box = camp.box, farmed = camp.is_farmed_,
				distance = distance, creeps = {}, members = {}, blockers = {}, incomplete = camp.stacks_cache.invisible_count > 0}
			for _, creep in pairs(camp.creeps_alive) do
				local unit = Entity.Get(creep.index_)
				if unit and Entity.IsAlive(unit) then
					if Entity.IsSameTeam(snapshot.hero.entity, unit) then
						record.blockers[#record.blockers + 1] = creep.index_
					else
						local hidden = Entity.IsDormant(unit) or not NPC.IsVisible(unit)
						if hidden then record.incomplete = true end
						if not hidden or allowUnseen then
							record.members[creep.index_] = true
							local member = helpers.campCreep(unit)
							member.hidden = hidden
							record.creeps[#record.creeps + 1] = member
						end
					end
				end
			end
			if allowUnseen or not record.incomplete then camps[#camps + 1] = record end
		end
	end
	if #camps == 0 then return camps end
	for _, unit in ipairs(NPCs.GetAll()) do
		if Entity.IsAlive(unit) and not Entity.IsDormant(unit) then
			local point = copyPoint(Entity.GetAbsOrigin(unit))
			for _, camp in ipairs(camps) do
				if helpers.insideCamp(point, camp, 0) then
					if NPC.IsNeutral(unit) and NPC.IsCreep(unit) and NPC.IsVisible(unit)
						and not Entity.IsSameTeam(snapshot.hero.entity, unit)
					then
						local index = Entity.GetIndex(unit)
						if not camp.members[index] then
							camp.members[index] = true
							camp.creeps[#camp.creeps + 1] = helpers.campCreep(unit)
						end
					elseif Entity.GetIndex(unit) ~= snapshot.hero.index then
						camp.blockers[#camp.blockers + 1] = Entity.GetIndex(unit)
					end
				end
			end
		end
	end
	local occupied = {}
	for _, camp in ipairs(camps) do
		if allowUnseen or #camp.creeps > 0 then occupied[#occupied + 1] = camp end
	end
	table.sort(occupied, function(a, b) return a.distance < b.distance end)
	return occupied
end

function helpers.refreshCampCreeps(job, allowUnseen)
	local creeps = {}
	for _, original in ipairs(job.creeps) do
		local unit = Entity.Get(original.index)
		if unit and Entity.IsAlive(unit) then
			local hidden = Entity.IsDormant(unit) or not NPC.IsVisible(unit)
			if hidden and not allowUnseen then return nil end
			local creep = hidden and original or helpers.campCreep(unit)
			creep.hidden = hidden
			creeps[#creeps + 1] = creep
		end
	end
	return creeps
end

function helpers.creepCenter(creeps)
	local center = {x = 0, y = 0, z = 0}
	for _, creep in ipairs(creeps) do center = add(center, creep.position) end
	return scale(center, 1 / #creeps)
end

function helpers.stackWindow(position, direction, creeps, snapshot, spawnAt, camp, turnTime)
	local mechanics = resolveMechanics("tornado", snapshot, 0)
	local lift = liveValue(snapshot, "tornado", "lift_duration", mechanics.controlDuration)
	local range = liveValue(snapshot, "tornado", "travel_distance", 1200 + 300 * snapshot.hero.orbLevels.wex)
	local radius = liveValue(snapshot, "tornado", "area_of_effect", 200)
	local speed = liveValue(snapshot, "tornado", "travel_speed", 1000)
	local lower, upper = -math.huge, math.huge
	if #creeps == 0 or speed <= 0 then return nil end
	for _, creep in ipairs(creeps) do
		-- Airborne units still block while rising/falling through the top of the spawn box.
		if camp and creep.position.z + cfg.stackLiftHeight <= camp.box.max.z + creep.hull + 20 then return nil end
		local delta = subtract(creep.position, position)
		local along = dot2D(delta, direction)
		local across = math.abs(delta.x * direction.y - delta.y * direction.x)
		if creep.immune or along <= 0 or along > range - creep.hull
			or across > radius - creep.hull - 20
		then return nil end
		local edge = math.sqrt(math.max(0, (radius + creep.hull)^2 - across^2))
		local arrival = (turnTime or 0) + snapshot.actions.tornado.castPoint + snapshot.latency + math.max(0, along - edge) / speed
		local transition = cfg.stackLiftTransition
		lower = math.max(lower, spawnAt + cfg.stackSpawnMargin - arrival - lift * creep.liftFactor + transition)
		upper = math.min(upper, spawnAt - cfg.stackSpawnMargin - arrival - transition)
	end
	if lower > upper then return nil end
	return {earliest = lower, latest = upper, castAt = (lower + upper) * 0.5, direction = direction}
end

function helpers.stackCampCreeps(camp)
	if #camp.creeps > 0 then return camp.creeps end
	return {{position = copyPoint(camp.position), hull = 24, liftFactor = 1, hidden = true}}
end

function helpers.selectStack(snapshot, camps)
	if not actionAvailable("tornado", snapshot, false) or snapshot.actions.tornado.cooldown > 0.05
		or snapshot.hero.mana < snapshot.actions.tornado.manaCost
	then return nil end
	local dotaTime = GameRules.GetDOTATime(false, false)
	local spawnAt = snapshot.now + math.max(60, (math.floor(dotaTime / 60) + 1) * 60) - dotaTime
	if spawnAt - snapshot.now > cfg.stackPreparationWindow then return nil end
	for _, camp in ipairs(camps) do
		if #camp.blockers == 0 then
			local creeps = helpers.stackCampCreeps(camp)
			local away = normalizedForward(subtract(snapshot.hero.position, camp.position))
			local candidates = {snapshot.hero.position}
			for i = 0, 7 do
				candidates[#candidates + 1] = add(camp.position, scale(rotate2D(away, i * math.pi / 4), 650))
			end
			for _, stand in ipairs(candidates) do
				local travel = distance2D(snapshot.hero.position, stand)
				if travel < 800 and not helpers.insideCamp(stand, camp, NPC.GetHullRadius(snapshot.hero.entity) + 35) then
					local direction = normalizedForward(subtract(helpers.creepCenter(creeps), stand))
					local window = helpers.stackWindow(stand, direction, creeps, snapshot, spawnAt, camp)
					local prepareTime = contains(snapshot.invoke.invoked, "tornado") and 0 or snapshot.invoke.cooldown + 0.3
					if window and snapshot.now + travel / math.max(1, snapshot.hero.moveSpeed) + prepareTime + 0.2 < window.latest
						and GridNav.IsTraversableFromTo(toVector(snapshot.hero.position), toVector(stand))
					then
						return {kind = "stack", camp = camp, creeps = creeps, stand = copyPoint(stand), spawnAt = spawnAt}
					end
				end
			end
		end
	end
	return nil
end

function helpers.updateStack(job, snapshot)
	if job.castDone then
		if snapshot.now >= job.spawnAt + 0.25 then helpers.cancelBind("Tornado stack cast complete.", true) end
		return
	end
	if job.pending then
		if helpers.bindCast(job, {actionId = "tornado"}, snapshot) then job.castDone = true end
		return
	end
	if snapshot.now >= job.spawnAt - cfg.stackSpawnMargin then
		helpers.cancelBind("Tornado stack window expired before the cast.", true)
		return
	end
	if not helpers.bindPrepare("tornado", false, snapshot) then return end
	if snapshot.now >= (job.nextCampRefreshAt or 0) then
		job.nextCampRefreshAt = snapshot.now + cfg.campScanInterval
		for _, camp in ipairs(helpers.nearbyCamps(snapshot, true)) do
			if camp.index == job.camp.index then job.camp = camp; job.creeps = helpers.stackCampCreeps(camp); break end
		end
	end
	local creeps = job.creeps
	local standDistance = distance2D(snapshot.hero.position, job.stand)
	if standDistance > (job.atStand and 100 or 40) then
		job.atStand = false
		helpers.bindMove(job, job.stand, snapshot)
		setStatus("moving", ("Tornado stack: positioning, %.2fs until spawn."):format(job.spawnAt - snapshot.now))
		return
	end
	if helpers.insideCamp(snapshot.hero.position, job.camp, NPC.GetHullRadius(snapshot.hero.entity) + 15) then
		helpers.cancelBind("Invoker would block the camp spawn.", true)
		return
	end
	if not job.atStand then
		job.atStand = true
		job.stand = copyPoint(snapshot.hero.position)
		job.moving = job.moving or snapshot.hero.moving
		if job.moving then helpers.bindStop(job); return end
	end
	local direction = normalizedForward(subtract(helpers.creepCenter(creeps), snapshot.hero.position))
	local aim = add(snapshot.hero.position, scale(direction, 100))
	local turnTime = NPC.GetTimeToFacePosition(snapshot.hero.entity, toVector(aim))
	local window = helpers.stackWindow(snapshot.hero.position, direction, creeps, snapshot, job.spawnAt, job.camp, turnTime)
	if not window or snapshot.now > window.latest then helpers.cancelBind("No safe Tornado stack window.", true); return end
	job.castAt = clamp(job.castAt or window.castAt, window.earliest, window.latest)
	setStatus("waiting", ("Tornado stack in %.2fs."):format(math.max(0, job.castAt - snapshot.now)))
	if snapshot.now >= job.castAt then
		local currentCamp
		for _, camp in ipairs(helpers.nearbyCamps(snapshot, true)) do
			if camp.index == job.camp.index then currentCamp = camp; break end
		end
		if not currentCamp or #currentCamp.blockers > 0 then
			helpers.cancelBind("The camp is no longer clear for stacking.", true)
			return
		end
		local finalCreeps = helpers.stackCampCreeps(currentCamp)
		local finalWindow = helpers.stackWindow(snapshot.hero.position, direction, finalCreeps, snapshot, job.spawnAt, currentCamp, turnTime)
		if not finalWindow or snapshot.now < finalWindow.earliest or snapshot.now > finalWindow.latest then
			helpers.cancelBind("Camp timing changed before Tornado.", true)
			return
		end
		helpers.bindCast(job, {actionId = "tornado", position = aim, exactPosition = true}, snapshot)
	end
end

function helpers.farmGeometry(snapshot, first, second)
	local wall = iceWallStats(snapshot)
	local midpoint = scale(add(first.position, second.position), 0.5)
	local axis = normalizedForward(subtract(second.position, first.position))
	local normal = {x = -axis.y, y = axis.x, z = 0}
	local stand = add(midpoint, scale(normal, -wall.placeDistance))
	local other = add(midpoint, scale(normal, wall.placeDistance))
	if distance2D(snapshot.hero.position, other) < distance2D(snapshot.hero.position, stand) then stand = other; normal = scale(normal, -1) end
	local creeps, members = {}, {}
	for campNumber, camp in ipairs({first, second}) do
		for _, creep in ipairs(camp.creeps) do
			if not creep.hidden and creep.attackRange > wall.totalLength * 0.5 + 100 then return nil end
			creeps[#creeps + 1] = creep
			members[creep.index] = campNumber
		end
	end
	local route = math.max(0, distance2D(first.position, second.position) - snapshot.hero.attackRange)
		+ math.max(0, distance2D(second.position, stand) - snapshot.hero.attackRange)
	if route / math.max(1, snapshot.hero.moveSpeed) + NPC.GetAttackTime(snapshot.hero.entity) > cfg.farmPullTimeout - 1 then return nil end
	if not GridNav.IsTraversableFromTo(toVector(snapshot.hero.position), toVector(stand)) then
		stand = add(midpoint, scale(normal, wall.placeDistance))
		normal = scale(normal, -1)
		if not GridNav.IsTraversableFromTo(toVector(snapshot.hero.position), toVector(stand)) then return nil end
	end
	return {kind = "farm", phase = "prepare", camps = {first, second}, creeps = creeps,
		members = members, position = midpoint, stand = stand, forward = normal, tag = 1}
end

function helpers.selectFarm(snapshot, camps)
	if #camps < 2 then return nil, "Ice Wall Farm: move closer to two camps." end
	if not actionAvailable("ice_wall", snapshot, false) or snapshot.actions.ice_wall.cooldown > 0.05
		or snapshot.hero.mana < snapshot.actions.ice_wall.manaCost
	then return nil, "Ice Wall Farm: waiting for Ice Wall and mana." end
	local best, bestScore = nil, math.huge
	for i = 1, math.min(#camps, 6) do
		for j = i + 1, math.min(#camps, 6) do
			local first, second = camps[i], camps[j]
			if not (#first.creeps == 0 and first.farmed) and not (#second.creeps == 0 and second.farmed) then
				local job = helpers.farmGeometry(snapshot, first, second)
				local score = distance2D(snapshot.hero.position, first.position) + distance2D(first.position, second.position)
					+ (#first.creeps == 0 and cfg.campSearchRadius or 0) + (#second.creeps == 0 and cfg.campSearchRadius or 0)
				if job and score < bestScore then best, bestScore = job, score end
			end
		end
	end
	if best then best.useHammer = ui.farmHammer:Get() end
	return best, "Ice Wall Farm: no reachable pair within pull distance."
end

function helpers.farmWallCoverage(job, snapshot, creeps, center, forward)
	local stats = iceWallStats(snapshot)
	local halfLength = (snapshot.hero.upgrades.scepterChoice == "quas" and stats.floeLength or stats.totalLength) * 0.5
	local width = liveValue(snapshot, "ice_wall", "wall_width", 105)
	local hit, visible, first, second = 0, 0, false, false
	for _, creep in ipairs(creeps) do
		if not creep.hidden and not creep.immune then
			visible = visible + 1
			local delta = subtract(creep.position, center)
			if math.abs(dot2D(delta, forward)) <= width + creep.hull - 15
				and math.abs(delta.x * forward.y - delta.y * forward.x) <= halfLength + creep.hull - 15
			then
				hit = hit + 1
				first = first or job.members[creep.index] == 1
				second = second or job.members[creep.index] == 2
			end
		end
	end
	return first and second and hit >= math.ceil(visible * 0.6), hit
end

function helpers.planFarmWall(job, snapshot, creeps)
	local centers = {{x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0}}
	local counts = {0, 0}
	for _, creep in ipairs(creeps) do
		local camp = job.members[creep.index]
		if camp and not creep.hidden then
			centers[camp] = add(centers[camp], creep.position)
			counts[camp] = counts[camp] + 1
		end
	end
	if counts[1] == 0 or counts[2] == 0 then return false end
	local center = scale(add(scale(centers[1], 1 / counts[1]), scale(centers[2], 1 / counts[2])), 0.5)
	local axis = normalizedForward(subtract(scale(centers[2], 1 / counts[2]), scale(centers[1], 1 / counts[1])))
	local normal = {x = -axis.y, y = axis.x, z = 0}
	local best, bestCount, bestDistance = nil, 0, math.huge
	for i = 0, 31 do
		local angle = i * math.pi / 32
		local forward = rotate2D(normal, angle)
		local fits, count = helpers.farmWallCoverage(job, snapshot, creeps, center, forward)
		if fits then
			for _, side in ipairs({1, -1}) do
				local facing = scale(forward, side)
				local stand = add(center, scale(facing, -iceWallStats(snapshot).placeDistance))
				local distance = distance2D(snapshot.hero.position, stand)
				if (count > bestCount or count == bestCount and distance < bestDistance)
					and GridNav.IsTraversableFromTo(toVector(snapshot.hero.position), toVector(stand))
				then
					best, bestCount, bestDistance = {forward = facing, stand = stand}, count, distance
				end
			end
		end
	end
	if not best then return false end
	job.position, job.stand, job.forward = center, best.stand, best.forward
	return true
end

function helpers.aimFarmWall(job, snapshot, creeps)
	local stats = iceWallStats(snapshot)
	local preferred = normalizedForward(subtract(job.position, snapshot.hero.position))
	local best, bestPosition, bestCount, bestTurn = nil, nil, 0, -math.huge
	for i = 0, 64 do
		local forward = i == 64 and normalizedForward(snapshot.hero.facing) or rotate2D(preferred, i * math.pi / 32)
		local position = snapshot.hero.upgrades.scepterChoice == "quas" and job.position
			or add(snapshot.hero.position, scale(forward, stats.placeDistance))
		local fits, count = helpers.farmWallCoverage(job, snapshot, creeps, position, forward)
		local turn = dot2D(forward, normalizedForward(snapshot.hero.facing))
		if fits and (count > bestCount or count == bestCount and turn > bestTurn) then
			best, bestPosition, bestCount, bestTurn = forward, position, count, turn
		end
	end
	if not best then return false end
	job.forward, job.wallPosition = best, bestPosition
	return true
end

function helpers.farmImpactPosition(creep, snapshot, delay)
	if not creep.moving then return creep.position end
	local toward = subtract(snapshot.hero.position, creep.position)
	local distance = length2D(toward)
	local forward = normalizedForward(creep.forward)
	local travel = creep.moveSpeed * delay
	if dot2D(forward, normalizedForward(toward)) > 0.6 then
		travel = math.min(travel, math.max(0, distance - creep.attackRange - creep.hull - NPC.GetHullRadius(snapshot.hero.entity)))
		forward = normalizedForward(toward)
	end
	return add(creep.position, scale(forward, travel))
end

function helpers.circleIntersections(a, ar, b, br, points)
	local delta = subtract(b, a)
	local distance = length2D(delta)
	if distance < 0.01 or distance > ar + br or distance < math.abs(ar - br) then return end
	local along = (ar * ar - br * br + distance * distance) / (2 * distance)
	local height = math.sqrt(math.max(0, ar * ar - along * along))
	local axis = scale(delta, 1 / distance)
	local center = add(a, scale(axis, along))
	local side = scale({x = -axis.y, y = axis.x, z = 0}, height)
	points[#points + 1] = add(center, side)
	points[#points + 1] = subtract(center, side)
end

function helpers.farmHammerPosition(snapshot, creeps)
	local runtime = snapshot.actions.item_meteor_hammer
	if not actionAvailable("item_meteor_hammer", snapshot, true) then return nil end
	local mechanics = resolveMechanics("item_meteor_hammer", snapshot, 0)
	local points, targets = {}, {}
	local center = {x = 0, y = 0, z = 0}
	for _, creep in ipairs(creeps) do
		if not creep.hidden and not creep.immune then
			local point = helpers.farmImpactPosition(creep, snapshot, mechanics.fixedDelay + snapshot.latency)
			local radius = math.max(1, mechanics.radius - creep.hull - 25)
			if distance2D(point, snapshot.hero.position) <= runtime.castRange + radius then
				targets[#targets + 1] = {position = point, radius = radius}
				points[#points + 1] = point
				center = add(center, point)
			end
		end
	end
	if #targets == 0 then return nil end
	points[#points + 1] = scale(center, 1 / #targets)
	for i, target in ipairs(targets) do
		local fromHero = subtract(target.position, snapshot.hero.position)
		if length2D(fromHero) > runtime.castRange then
			points[#points + 1] = add(snapshot.hero.position, scale(normalizedForward(fromHero), runtime.castRange))
		end
		helpers.circleIntersections(target.position, target.radius, snapshot.hero.position, runtime.castRange, points)
		for j = i + 1, #targets do
			local other = targets[j]
			if distance2D(target.position, other.position) <= target.radius + other.radius then
				points[#points + 1] = scale(add(target.position, other.position), 0.5)
				helpers.circleIntersections(target.position, target.radius, other.position, other.radius, points)
			end
		end
	end
	local best, bestCount, bestMargin = nil, 0, -math.huge
	for _, point in ipairs(points) do
		if distance2D(snapshot.hero.position, point) <= runtime.castRange + 0.001 then
			local count, margin = 0, 0
			for _, target in ipairs(targets) do
				local slack = target.radius - distance2D(target.position, point)
				if slack >= -0.001 then count, margin = count + 1, margin + slack end
			end
			if count > bestCount or count == bestCount and margin > bestMargin then
				best, bestCount, bestMargin = point, count, margin
			end
		end
	end
	if bestCount == 0 then return nil end
	local delta = subtract(best, snapshot.hero.position)
	if length2D(delta) > runtime.castRange then best = add(snapshot.hero.position, scale(normalizedForward(delta), runtime.castRange)) end
	return best
end

function helpers.bindAttack(job, index, snapshot)
	local unit = Entity.Get(index)
	if not unit or not Entity.IsAlive(unit) or Entity.IsDormant(unit) then return false end
	if job.attackIndex ~= index or not snapshot.hero.attacking and not snapshot.hero.moving
		and snapshot.now - (job.lastAttackOrderAt or 0) >= 0.6
	then
		issueOrder(function() Player.AttackTarget(state.player, state.hero, unit, false, false, true, "invoker_auto", false) end)
		if job.attackIndex ~= index then
			job.attackHealth = Entity.GetHealth(unit)
			job.attackIssuedAt = snapshot.now
		end
		job.attackIndex = index
		job.lastAttackOrderAt = snapshot.now
		job.moving = true
	end
	return true
end

function helpers.farmTagConfirmed(job)
	if job.tagged then return true end
	if not job.attackIndex then return false end
	local target = Entity.Get(job.attackIndex)
	if not target or not Entity.IsAlive(target) then return true end
	return not Entity.IsDormant(target) and NPC.IsVisible(target)
		and Entity.GetHealth(target) < job.attackHealth
end

function helpers.refreshFarmMembers(job, snapshot)
	local known = {}
	for _, creep in ipairs(job.creeps) do known[creep.index] = true end
	for _, camp in ipairs(helpers.nearbyCamps(snapshot, true)) do
		for campNumber, selected in ipairs(job.camps) do
			if camp.index == selected.index then
				selected.creeps = camp.creeps
				for _, creep in ipairs(camp.creeps) do
					job.members[creep.index] = campNumber
					if not known[creep.index] then
						known[creep.index] = true
						job.creeps[#job.creeps + 1] = creep
					end
				end
			end
		end
	end
end

function helpers.farmAggroTarget(job, camp, snapshot)
	local target, nearest = nil, math.huge
	local function consider(index)
		if job.failedTargets and job.failedTargets[index] then return end
		local unit = Entity.Get(index)
		if not unit or not Entity.IsAlive(unit) or Entity.IsDormant(unit) or not NPC.IsVisible(unit)
			or Entity.IsSameTeam(snapshot.hero.entity, unit) or not NPC.IsNeutral(unit) or not NPC.IsCreep(unit)
			or NPC.HasState(unit, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE)
		then return end
		local distance = distance2D(snapshot.hero.position, Entity.GetAbsOrigin(unit))
		if index == job.attackIndex or ((not target or target ~= job.attackIndex) and distance < nearest) then
			target, nearest = index, distance
		end
	end
	for _, creep in ipairs(camp.creeps) do consider(creep.index) end
	for _, visible in ipairs(snapshot.sunUnits) do
		local member = job.members[visible.index]
		if member == job.tag then
			consider(visible.index)
		elseif not member then
			local closest, distance = nil, cfg.farmAcquireRadius
			for number, selected in ipairs(job.camps) do
				local separation = distance2D(visible.position, selected.position)
				if separation < distance then closest, distance = number, separation end
			end
			if closest == job.tag then consider(visible.index) end
		end
	end
	if target and not job.members[target] then
		local creep = helpers.campCreep(Entity.Get(target))
		job.members[target] = job.tag
		job.creeps[#job.creeps + 1] = creep
		camp.creeps[#camp.creeps + 1] = creep
	end
	return target
end

function helpers.farmScoutPoint(job, camp, snapshot)
	local focus, distance = camp.position, math.huge
	for _, creep in ipairs(camp.creeps) do
		local separation = distance2D(snapshot.hero.position, creep.position)
		if separation < distance then focus, distance = creep.position, separation end
	end
	local away = normalizedForward(subtract(snapshot.hero.position, focus))
	distance = distance2D(snapshot.hero.position, focus)
	local attackDistance = math.max(150, snapshot.hero.attackRange - 40)
	local minimumDistance = math.max(100, snapshot.hero.attackRange * 0.5)
	if distance > attackDistance + 30 then return add(focus, scale(away, attackDistance)) end
	if distance > minimumDistance + 40 then return add(focus, scale(away, math.max(minimumDistance, distance - 100))) end
	if job.scoutPoint and job.scoutTag == job.tag and distance2D(snapshot.hero.position, job.scoutPoint) > 35 then return job.scoutPoint end
	job.scoutTag = job.tag
	job.scoutPoint = add(focus, scale(rotate2D(away, math.pi / 4), minimumDistance))
	return job.scoutPoint
end

function helpers.updateFarm(job, snapshot)
	local hammer = snapshot.actions.item_meteor_hammer
	if job.phase == "channel" then
		local mechanics = resolveMechanics("item_meteor_hammer", snapshot, 0)
		if hammer.exists and Ability.IsChannelling(hammer.ability) then
			job.channelStartedAt = job.channelStartedAt or snapshot.now
			setStatus("channeling", "Ice Wall Farm: Meteor Hammer channeling.")
			return
		end
		if job.channelStartedAt then
			if snapshot.now - job.channelStartedAt < mechanics.channelTime - 0.2 then
				helpers.cancelBind("Meteor Hammer channel interrupted.", false)
				return
			end
			job.phase, job.pending = "finish", nil
			job.landAt = snapshot.now + math.max(0, mechanics.fixedDelay - mechanics.channelTime)
		elseif job.pending and snapshot.now - job.pending.issuedAt > 1 then
			helpers.cancelBind("Meteor Hammer channel did not start.", false)
		end
		return
	end
	if not job.pending and (job.phase == "gather" or job.phase == "wall_position" or job.phase == "wall") then
		if snapshot.now < (job.nextAimAt or 0) then return end
		job.nextAimAt = snapshot.now + cfg.farmAimInterval
	end
	if (job.phase == "prepare" or job.phase == "tag") and snapshot.now >= (job.nextMemberScanAt or 0) then
		job.nextMemberScanAt = snapshot.now + cfg.campScanInterval
		helpers.refreshFarmMembers(job, snapshot)
	end
	local creeps = helpers.refreshCampCreeps(job, true)
	if #creeps == 0 and job.phase ~= "prepare" and job.phase ~= "tag" then
		helpers.cancelBind("Ice Wall Farm complete.", true)
		return
	end
	if job.phase ~= "finish" and job.phase ~= "hammer" and not job.pending
		and job.pullStartedAt and snapshot.now - job.pullStartedAt > cfg.farmPullTimeout
	then
		helpers.cancelBind("Camps could not be gathered in time; retrying shortly.", true, true)
		return
	end
	if job.phase == "prepare" then
		if not helpers.bindPrepare("ice_wall", false, snapshot) then return end
		job.phase = "tag"
		job.tagDeadlineAt = snapshot.now + 8
	end
	if job.phase == "tag" then
		if snapshot.now > job.tagDeadlineAt then helpers.cancelBind("Could not aggro the camp; retrying shortly.", true, true); return end
		local camp = job.camps[job.tag]
		if helpers.farmTagConfirmed(job) then
			helpers.refreshFarmMembers(job, snapshot)
			job.tagged, job.attackIndex = nil, nil
			job.failedTargets = nil
			job.pullStartedAt = job.pullStartedAt or snapshot.now
			job.tag = job.tag + 1
			job.tagDeadlineAt = snapshot.now + 8
			if job.tag > 2 then job.phase = "gather" end
		else
			if job.attackIndex and not snapshot.hero.attacking and not snapshot.hero.moving
				and snapshot.now - job.attackIssuedAt > 1.5
			then
				job.failedTargets = job.failedTargets or {}
				job.failedTargets[job.attackIndex] = true
				job.attackIndex = nil
			end
			local target = helpers.farmAggroTarget(job, camp, snapshot)
			if not target then
				helpers.bindMove(job, helpers.farmScoutPoint(job, camp, snapshot), snapshot)
				setStatus("moving", "Ice Wall Farm: scouting camp " .. job.tag .. ".")
				return
			end
			if not helpers.bindAttack(job, target, snapshot) then
				helpers.cancelBind("Camp changed before aggro.", true, true)
				return
			end
			if job.attackIssuedAt and snapshot.now - job.attackIssuedAt > 6 then
				helpers.cancelBind("Could not aggro the camp; retrying shortly.", true, true)
				return
			end
			setStatus("moving", "Ice Wall Farm: aggro camp " .. job.tag .. ".")
		end
	end
	if job.phase == "gather" then
		if snapshot.now < (job.nextWallPlanAt or 0) then return end
		job.nextWallPlanAt = snapshot.now + cfg.campScanInterval
		if not helpers.planFarmWall(job, snapshot, creeps) then
			if distance2D(snapshot.hero.position, job.position) > 45 then helpers.bindMove(job, job.position, snapshot)
			else helpers.bindStop(job) end
			setStatus("waiting", "Ice Wall Farm: waiting for both camps to enter wall reach.")
			return
		end
		job.phase = "wall_position"
	end
	if job.phase == "wall_position" then
		if not helpers.aimFarmWall(job, snapshot, creeps) then
			if snapshot.now >= (job.nextWallPlanAt or 0) then
				job.nextWallPlanAt = snapshot.now + cfg.campScanInterval
				if not helpers.planFarmWall(job, snapshot, creeps) then job.phase = "gather"; return end
			end
			if distance2D(snapshot.hero.position, job.stand) > 25 then helpers.bindMove(job, job.stand, snapshot)
			else helpers.bindStop(job) end
			setStatus("waiting", "Ice Wall Farm: lining up Ice Wall through both camps.")
			return
		end
		job.phase = "wall"
	end
	if job.phase == "wall" then
		if job.pending then
			if helpers.bindCast(job, {actionId = "ice_wall"}, snapshot) then job.phase = "hammer" end
			return
		end
		if not helpers.aimFarmWall(job, snapshot, creeps) then job.phase = "wall_position"; return end
		local request = helpers.bindWallRequest(job, snapshot, job.wallPosition, job.forward)
		if request then helpers.bindCast(job, request, snapshot) end
	elseif job.phase == "hammer" then
		if snapshot.now < job.nextOrderAt then return end
		local position = job.useHammer and helpers.farmHammerPosition(snapshot, creeps) or nil
		if not position then
			job.phase, job.landAt = "finish", snapshot.now
			return
		end
		helpers.bindCast(job, {actionId = "item_meteor_hammer", position = position, exactPosition = true}, snapshot)
		if job.pending then job.phase = "channel" end
	elseif job.phase == "finish" and snapshot.now >= job.landAt then
		local target = creeps[1]
		for _, creep in ipairs(creeps) do
			if distance2D(creep.position, snapshot.hero.position) < distance2D(target.position, snapshot.hero.position) then target = creep end
		end
		helpers.bindAttack(job, target.index, snapshot)
	end
end

function helpers.updateBinds(snapshot, heldMode)
	state.bindKeys = state.bindKeys or {}
	state.bindBlocked = state.bindBlocked or {}
	for kind, blocked in pairs(state.bindBlocked) do
		if type(blocked) == "number" and snapshot.now >= blocked then state.bindBlocked[kind] = nil end
	end
	local farmDown, stackDown = ui.meteorFarm:IsDown(), ui.tornadoStack:IsDown()
	if not farmDown then state.bindBlocked.farm = nil end
	if not stackDown then state.bindBlocked.stack = nil end
	local job = state.bindJob
	if job and (job.kind == "farm" and not farmDown or job.kind == "stack" and not stackDown) then
		helpers.cancelBind("Automation bind released.", true)
		return false
	end
	local pressed
	for _, id in ipairs(cfg.bindSpellIds) do
		local down = ui["bindPrepare_" .. id]:IsDown()
		if down and not state.bindKeys[id] then
			pressed = {kind = "spell", id = id, quick = ui["bindQuick_" .. id]:Get(), aimWall = id == "ice_wall" and ui.bindAimWall:Get()}
		end
		state.bindKeys[id] = down
	end
	for _, pair in ipairs(cfg.selfBindIds) do
		local down = ui[pair[1]]:IsDown()
		if down and not state.bindKeys[pair[1]] then pressed = {kind = "spell", id = pair[2], quick = true} end
		state.bindKeys[pair[1]] = down
	end
	if heldMode or state.manualCraft or state.pendingCast or state.autoPending and state.autoPending.cast then
		if heldMode or state.manualCraft then state.bindPreparedSpell = nil end
		helpers.cancelBind("Manual combo or active cast took priority.", false)
		return false
	end
	if pressed then
		pressed.position = copyPoint(snapshot.cursor)
		if pressed.id == "cold_snap" and pressed.quick then
			local target = helpers.closestBindTarget(snapshot, pressed.position)
			if not target then setStatus("idle", "No enemy near the cursor for Cold Snap."); return false end
			pressed.targetIndex = target.index
		end
		helpers.startBind(pressed, snapshot)
	end
	job = state.bindJob
	if not job and not snapshot.hero.channeling and not snapshot.hero.inAbilityPhase
		and not snapshot.hero.stunned and not snapshot.hero.silenced
		and snapshot.now >= state.automaticActionsPausedUntil
		and (farmDown and not state.bindBlocked.farm or stackDown and not state.bindBlocked.stack)
		and snapshot.now >= (state.nextCampScanAt or 0)
	then
		state.nextCampScanAt = snapshot.now + cfg.campScanInterval
		local camps = helpers.nearbyCamps(snapshot, true)
		job = stackDown and not state.bindBlocked.stack and helpers.selectStack(snapshot, camps) or nil
		if not job and farmDown and not state.bindBlocked.farm then
			local reason
			job, reason = helpers.selectFarm(snapshot, camps)
			if not job then setStatus("waiting", reason) end
		end
		if job then helpers.startBind(job, snapshot) end
	end
	if not job then return false end
	if snapshot.now > job.expiresAt then helpers.cancelBind("Bind action timed out.", true, job.kind == "farm"); return true end
	if job.kind == "farm" and job.phase == "channel" then helpers.updateFarm(job, snapshot); return true end
	if snapshot.hero.channeling or snapshot.hero.inAbilityPhase or snapshot.hero.stunned or snapshot.hero.silenced then return true end
	if job.kind == "spell" then helpers.updateSpellBind(job, snapshot)
	elseif job.kind == "stack" then helpers.updateStack(job, snapshot)
	else helpers.updateFarm(job, snapshot) end
	return true
end

local function coreRun()
	if not ui.enabled:Get() then
		state.landings, state.teleportParticles, state.teleportHistory = nil, nil, nil
		helpers.cancelBind("Invoker automation disabled.", true)
		if state.plan then abortPlan("Invoker automation disabled.") end
		state.snapshot = nil
		state.roshan = nil
		state.tormentors = nil
		state.invokeSequence = nil
		state.orbSequence = nil
		state.autoPending = nil
		state.lastHeldMode = nil
		state.lastHeldSlot = nil
		state.panel.dragging = false
		state.panel.dragFrom = nil
		state.spellBar.dragging = false
		local leftDown = Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE1, false)
		state.panel.leftWasDown = leftDown
		state.spellBar.leftWasDown = leftDown
		return
	end

	local heldMode
	if not Input.IsInputCaptured() then
		heldMode = ui.cursorKey:IsDown() and "cursor" or ui.comboKey:IsDown() and "normal" or nil
	end
	local activeMode = heldMode or state.plan and state.plan.targetMode or "normal"
	local lockedIndex = state.plan and state.plan.targetIndex or nil
	local snapshot = buildSnapshot(activeMode, lockedIndex)
	if snapshot and state.plan and state.plan.targetMode == "cursor" then
		snapshot.cursor = copyPoint(state.plan.cursor)
		snapshot.target = selectTarget(snapshot.enemies, snapshot.cursor, nil, cfg.groundTargetRadius, false)
	end
	state.snapshot = snapshot
	if not snapshot or not snapshot.activeGame then
		resetRuntime()
		return
	end
	local settings = readSettings()
	helpers.cancelIdlePreparation(settings)
	helpers.updateComboSelectionBinds(snapshot)
	helpers.updateQuickSunData(snapshot)
	updateComboPanelInput(settings)
	settings = readSettings()
	updateSpellBarInput(snapshot, settings)
	if not snapshot.hero.alive then
		resetRuntime()
		return
	end
	if not heldMode and state.lastHeldMode then
		if state.plan then abortPlan("Combo key released.") end
		state.dynamicContinue = false
		state.lastHeldMode = nil
		state.nextPlanAt = 0
	end
	if snapshot.paused then return end
	helpers.updateLandingTracks(snapshot, settings.auto)
	if Input.IsInputCaptured() then
		helpers.cancelBind("Input captured.", true)
		state.autoPending = nil
		state.invokeSequence = nil
		state.orbSequence = nil
		return
	end
	if heldMode and state.autoPending and state.autoPending.kind == "landing_sun" and not state.autoPending.cast then
		state.autoPending = nil
		if isInvoking("sun_strike") and not state.invokeSequence.manual then state.invokeSequence = nil end
	end
	if helpers.updateBinds(snapshot, heldMode) then return end
	if snapshot.hero.channeling or snapshot.hero.inAbilityPhase then
		if state.pendingCast then updatePendingCast(snapshot) end
		return
	end
	if state.pendingCast and updatePendingCast(snapshot) then return end
	if snapshot.hero.stunned or snapshot.hero.silenced then
		state.invokeSequence = nil
		state.orbSequence = nil
		setStatus("waiting", "Invoker is disabled or silenced.")
		return
	end
	if state.autoPending and state.autoPending.cast then
		processAutoPending(snapshot, settings.auto)
		return
	end
	if snapshot.now < state.automaticActionsPausedUntil and not state.manualCraft then return end
	local quickSunTarget = clickedQuickSunTarget(snapshot, settings.auto)
	local manualPreparation = state.invokeSequence and state.invokeSequence.manual
	local manualSun = state.autoPending and state.autoPending.kind == "quick_sun"
	if snapshot.hero.invisible and not heldMode and not state.manualCraft and not quickSunTarget
		and not manualPreparation and not manualSun
	then
		state.autoPending = nil
		if snapshot.hero.ghostWalk then
			updateInvokeSequence(snapshot)
			updateOrbSequence(snapshot)
			idlePrepare(snapshot, settings)
		else
			state.invokeSequence = nil
			state.orbSequence = nil
		end
		return
	end
	if not heldMode and not state.plan and not state.autoPending and not state.manualCraft and not quickSunTarget
		and helpers.processFountainOpener(snapshot, settings.auto)
	then
		return
	end
	updateInvokeSequence(snapshot)
	updateOrbSequence(snapshot)
	if processManualCraft(snapshot) then return end

	if quickSunTarget then
		if state.plan then abortPlan("Quick Sun Strike took priority.") end
		if not queueAutoAction("sun_strike", quickSunTarget, "quick_sun", snapshot) then
			setStatus("aborted", "Quick Sun Strike is unavailable.")
		end
	end

	if heldMode and state.lastHeldSlot and settings.slot ~= state.lastHeldSlot then
		state.dynamicContinue = false
		if state.plan then abortPlan("Selected combo changed.") end
		local started = startCombo(snapshot, settings, false)
		state.nextPlanAt = (started or settings.slot == "D") and snapshot.now + 0.25 or math.huge
	elseif heldMode and heldMode ~= state.lastHeldMode then
		state.dynamicContinue = false
		if state.plan then abortPlan("Combo key changed.") end
		local started = startCombo(snapshot, settings, false)
		state.nextPlanAt = (started or settings.slot == "D") and snapshot.now + 0.25 or math.huge
	elseif not heldMode and state.lastHeldMode then
		if state.plan then abortPlan("Combo key released.") end
		state.dynamicContinue = false
		state.nextPlanAt = 0
	end
	state.lastHeldMode = heldMode
	state.lastHeldSlot = settings.slot

	if snapshot.now >= state.automaticActionsPausedUntil
		and snapshot.now >= state.nextAutoActionAt
		and not state.autoPending
		and not state.pendingCast
	then
		local interruptTarget, interruptSpell = selectInterruptTarget(snapshot, settings.auto)
		local manualComboActive = heldMode ~= nil or state.plan ~= nil
		local cataclysmTarget = not interruptTarget and not manualComboActive
			and selectCataclysmTarget(snapshot, settings.auto) or nil
		local landingTarget = not interruptTarget and not manualComboActive and not cataclysmTarget
			and helpers.selectLandingSun(snapshot, settings.auto) or nil
		local sunTarget = not interruptTarget and not manualComboActive and not cataclysmTarget and not landingTarget
			and selectAutoSunTarget(snapshot, settings.auto) or nil
		if interruptTarget and queueAutoAction(interruptSpell, interruptTarget, "interrupt", snapshot) then
			if state.plan then abortPlan("Automatic interrupt took priority.") end
		elseif cataclysmTarget and queueAutoAction("cataclysm", cataclysmTarget, "cataclysm", snapshot) then
			if state.plan then abortPlan("Automatic Cataclysm took priority.") end
		elseif landingTarget and helpers.queueLandingSun(landingTarget, snapshot, settings.auto) then
			setStatus("preparing", "Sun Strike: preparing for arrival.")
		elseif sunTarget and queueAutoAction("sun_strike", sunTarget, "sun_strike", snapshot) then
			if state.plan then abortPlan("Automatic Sun Strike took priority.") end
		elseif not manualComboActive and not interruptTarget and not cataclysmTarget and not sunTarget
			and helpers.isRoshanSunTarget(snapshot, settings.auto)
			and queueAutoAction("sun_strike", snapshot.roshan, "roshan_sun", snapshot)
		then
			state.autoPending.position = copyPoint(snapshot.roshan.position)
			state.nextAutoActionAt = snapshot.now
		elseif not manualComboActive and not interruptTarget and not cataclysmTarget and not sunTarget then
			local objective = helpers.selectTormentorSunTarget(snapshot, settings.auto)
			if objective and queueAutoAction("sun_strike", objective, "tormentor_sun", snapshot) then
				state.autoPending.position = copyPoint(objective.position)
				state.nextAutoActionAt = snapshot.now
			end
		end
	end

	local automatic = processAutoPending(snapshot, settings.auto)
	if not automatic then updateExecutor(snapshot, settings) end
	if not automatic and not state.autoPending then updateAutoOrbs(snapshot, settings.auto, state.plan ~= nil) end

	if heldMode and not automatic and not state.plan and not isInvoking() and snapshot.now >= state.nextPlanAt then
		local forceDynamic = settings.slot == "D" or state.dynamicContinue == true
		local started = startCombo(snapshot, settings, forceDynamic)
		state.nextPlanAt = (started or forceDynamic) and snapshot.now + 0.25 or math.huge
	end

	if heldMode == "normal" and not automatic and not state.pendingCast and snapshot.target
	then
		helpers.updateComboCombat(snapshot, settings)
	elseif not heldMode then
		state.kiteAttack = nil
	end
	if not state.plan and not automatic and not state.autoPending then idlePrepare(snapshot, settings) end
end

local phaseColors = {
	idle = Color(158, 164, 176, 230),
	preparing = Color(102, 181, 255, 240),
	waiting = Color(255, 197, 92, 240),
	moving = Color(255, 151, 91, 240),
	confirming = Color(79, 219, 154, 240),
	channeling = Color(79, 219, 154, 240),
	complete = Color(79, 219, 154, 240),
	aborted = Color(255, 88, 74, 240),
}

local function quickSunReady(snapshot, target)
	local action = snapshot.actions.sun_strike
	return target
		and target.alive
		and not target.dormant
		and not target.invulnerable
		and action
		and action.exists
		and action.learned
		and action.activated
		and action.cooldown <= 0.05
		and snapshot.hero.mana + 0.001 >= action.manaCost
		and (action.invoked or snapshot.invoke.ready)
end

function helpers.updateQuickSunData(snapshot)
	state.quickSunEntries = {}
	if not ui.quickSunButtons:Get() or not snapshot.hero.alive then return end
	local targetByIndex = {}
	for _, enemy in ipairs(snapshot.enemies) do targetByIndex[enemy.index] = enemy end
	local enemyPlayers = {}
	for _, player in ipairs(Players.GetAll()) do
		local assignedHero = Player.GetAssignedHero(player)
		if assignedHero and not Entity.IsSameTeam(snapshot.hero.entity, assignedHero) then
			local targetIndex = Entity.GetIndex(assignedHero)
			local target = targetByIndex[targetIndex]
			local split = 1
			if target then
				local mechanics = resolveMechanics("sun_strike", snapshot, 0)
				local prediction = predictIntercept(snapshot, "sun_strike", target, snapshot.now, target.motionConfidence).position
				split = sunSplitCount(snapshot, prediction, math.max(cfg.sunRadius, mechanics.radius), targetIndex, helpers.sunImpactDelay(snapshot, "sun_strike"))
			end
			enemyPlayers[#enemyPlayers + 1] = {
				targetIndex = targetIndex,
				ready = quickSunReady(snapshot, target),
				split = split,
				teamSlot = Player.GetPlayerTeamSlot(player),
			}
		end
	end
	table.sort(enemyPlayers, function(left, right) return left.teamSlot < right.teamSlot end)
	state.quickSunEntries = enemyPlayers
end

local function drawQuickSunButtons()
	state.quickSunHitboxes = {}
	local snapshot = state.snapshot
	if not ui.enabled:Get() or not ui.quickSunButtons:Get() or not snapshot
		or not snapshot.activeGame or not snapshot.hero.alive
	then
		return
	end

	local screen = Render.ScreenSize()
	local scaleValue = clamp(screen.y / 1080, 0.72, 1.35)
	local portraitWidth = 60 * scaleValue
	local portraitGap = 2 * scaleValue
	local centerGap = 90 * scaleValue
	local portraitHeight = 52 * scaleValue
	local buttonSize = 22 * scaleValue
	local edgeOffset = 37 * scaleValue
	local teamWidth = portraitWidth * 5 + portraitGap * 4
	local enemyTeamOnRight = Entity.GetTeamNum(snapshot.hero.entity) == Enum.TeamNum.TEAM_RADIANT
	local teamStart = enemyTeamOnRight
		and screen.x * 0.5 + centerGap * 0.5
		or screen.x * 0.5 - centerGap * 0.5 - teamWidth
	local y = portraitHeight + 51 * scaleValue

	for index, entry in ipairs(state.quickSunEntries) do
		if index > 5 then break end
		local portraitX = teamStart + (index - 1) * (portraitWidth + portraitGap)
		local x = enemyTeamOnRight
			and portraitX + portraitWidth - buttonSize + edgeOffset
			or portraitX - edgeOffset
		local targetIndex = entry.targetIndex
		local ready = entry.ready
		local hovered = ready and Input.IsCursorInRect(x - 2 * scaleValue, y - 2 * scaleValue, buttonSize + 4 * scaleValue, buttonSize + 4 * scaleValue)
		local background = ready
			and (hovered and Color(255, 142, 56, 245) or Color(222, 74, 45, 245))
			or Color(55, 60, 65, 165)
		local borderStart = Vec2(x - 2 * scaleValue, y - 2 * scaleValue)
		local borderEnd = Vec2(x + buttonSize + 2 * scaleValue, y + buttonSize + 2 * scaleValue)
		Render.FilledRect(borderStart, borderEnd, background, 5 * scaleValue)
		Render.Image(
			renderCtx.icons.sun_strike,
			Vec2(x, y),
			Vec2(buttonSize, buttonSize),
			ready and Color(255, 255, 255, 255) or Color(155, 155, 155, 90),
			4 * scaleValue
		)

		if entry.split > 1 then
			local badgeCenter = Vec2(x + buttonSize - 2 * scaleValue, y + 3 * scaleValue)
			local badgeText = tostring(entry.split)
			local badgeSize = Render.TextSize(renderCtx.badgeFont, 10 * scaleValue, badgeText)
			Render.FilledCircle(badgeCenter, 6 * scaleValue, Color(8, 10, 14, 225), 0, 1, 16)
			Render.Text(
				renderCtx.badgeFont,
				10 * scaleValue,
				badgeText,
				Vec2(badgeCenter.x - badgeSize.x * 0.5, badgeCenter.y - badgeSize.y * 0.5),
				Color(255, 219, 112, 255)
			)
		end

		if ready then
			state.quickSunHitboxes[#state.quickSunHitboxes + 1] = {
				x = borderStart.x,
				y = borderStart.y,
				width = buttonSize + 4 * scaleValue,
				height = buttonSize + 4 * scaleValue,
				targetIndex = targetIndex,
			}
		end
	end
end

local function panelExecution()
	local execution = {active = state.plan ~= nil, slot = state.plan and state.plan.slot or nil, actionIndex = nil}
	if not state.plan then return execution end
	for index, action in ipairs(state.plan.actions) do
		if action.status ~= "confirmed" and action.status ~= "skipped" then
			execution.actionIndex = index
			break
		end
	end
	return execution
end

local function rebuildComboPanelHitboxes(settings, size)
	local panel = state.panel
	local scaleValue = settings.panel.scale
	local actionCount = #panelActions()
	local cached = panel.geometryCache
	if cached and panel.header and cached.x == panel.x and cached.y == panel.y
		and cached.width == size.width and cached.height == size.height and cached.scale == scaleValue
		and cached.expanded == panel.expanded and cached.actionCount == actionCount
	then
		return
	end
	panel.geometryCache = {x = panel.x, y = panel.y, width = size.width, height = size.height,
		scale = scaleValue, expanded = panel.expanded, actionCount = actionCount}
	panel.header = {x = panel.x, y = panel.y, width = size.width, height = 31 * scaleValue}
	panel.expand = {
		x = panel.x + size.width - 23 * scaleValue,
		y = panel.y + 8 * scaleValue,
		width = 14 * scaleValue,
		height = 14 * scaleValue,
	}
	panel.slotHitboxes = {}
	local tabY = panel.y + 33 * scaleValue
	local tabWidth = 24 * scaleValue
	for index, slot in ipairs(panelSlots) do
		panel.slotHitboxes[#panel.slotHitboxes + 1] = {
			slot = slot,
			rect = {
				x = panel.x + 8 * scaleValue + (index - 1) * (tabWidth + 3 * scaleValue),
				y = tabY,
				width = tabWidth,
				height = 20 * scaleValue,
			},
		}
	end

	panel.paletteHitboxes = {}
	panel.comboHitboxes = {}
	panel.clear = nil
	panel.strict = nil
	if not panel.expanded then return end
	local iconSize = 35 * scaleValue
	local gap = 5 * scaleValue
	for index, id in ipairs(allActionIds) do
		local row = math.floor((index - 1) / 10)
		local column = (index - 1) % 10
		panel.paletteHitboxes[#panel.paletteHitboxes + 1] = {
			id = id,
			rect = {
				x = panel.x + 10 * scaleValue + column * (iconSize + gap),
				y = panel.y + 80 * scaleValue + row * (iconSize + gap),
				width = iconSize,
				height = iconSize,
			},
		}
	end
	local paletteRows = math.ceil(#allActionIds / 10)
	local sectionY = panel.y + (92 + paletteRows * 40) * scaleValue
	for index = 1, actionCount do
		local row = math.floor((index - 1) / 8)
		local column = (index - 1) % 8
		panel.comboHitboxes[#panel.comboHitboxes + 1] = {
			index = index,
			x = panel.x + 10 * scaleValue + column * (iconSize + gap),
			y = sectionY + 24 * scaleValue + row * (iconSize + gap),
			width = iconSize,
			height = iconSize,
		}
	end
	panel.clear = {
		x = panel.x + size.width - 26 * scaleValue,
		y = sectionY,
		width = 14 * scaleValue,
		height = 14 * scaleValue,
	}
	panel.strict = {
		x = panel.x + 125 * scaleValue,
		y = sectionY - 2 * scaleValue,
		width = size.width - 165 * scaleValue,
		height = 19 * scaleValue,
	}
end

local function drawPanelControl(image, rect, hovered, alpha)
	if hovered then
		Render.FilledRect(
			Vec2(rect.x - 2, rect.y - 2),
			Vec2(rect.x + rect.width + 2, rect.y + rect.height + 2),
			Color(48, 54, 65, alpha),
			3
		)
	end
	local color = hovered and Color(255, 255, 255, alpha) or Color(188, 194, 204, alpha)
	Render.Image(image, Vec2(rect.x, rect.y), Vec2(rect.width, rect.height), color)
end

local function panelActionUnavailable(id)
	local snapshot = state.snapshot
	local definition = definitions[id]
	local action = snapshot and snapshot.actions[id] or nil
	if not snapshot or not definition or not action or not action.exists then return true, 0 end
	local cooldown = math.max(0, action.cooldown)
	local unavailable = not action.learned
		or not recipeAvailable(definition.recipe, snapshot.hero.orbLevels)
		or definition.requiresScepter and snapshot.hero.upgrades.scepterChoice ~= definition.requiresScepter
		or cooldown > 0.05
		or snapshot.hero.mana + 0.001 < action.manaCost
		or definition.kind == "item" and (not action.activated or not action.canCast)
	return unavailable, cooldown
end

local function drawPanelAction(id, rect, active, hovered, disabled, alpha, cooldown)
	local tint = disabled and Color(255, 255, 255, math.min(65, alpha)) or Color(255, 255, 255, alpha)
	Render.Image(renderCtx.icons[id], Vec2(rect.x, rect.y), Vec2(rect.width, rect.height), tint, 4)
	if disabled then
		Render.FilledRect(
			Vec2(rect.x, rect.y),
			Vec2(rect.x + rect.width, rect.y + rect.height),
			Color(5, 6, 9, 145),
			4
		)
	end
	if cooldown and cooldown > 0.05 then
		local text = cooldown < 10 and ("%.1f"):format(cooldown) or tostring(math.ceil(cooldown))
		local fontSize = clamp(rect.height * 0.42, 10, 18)
		local textSize = Render.TextSize(renderCtx.cooldownFont, fontSize, text)
		Render.Text(
			renderCtx.cooldownFont,
			fontSize,
			text,
			Vec2(rect.x + (rect.width - textSize.x) * 0.5, rect.y + (rect.height - textSize.y) * 0.5),
			Color(255, 255, 255, alpha)
		)
	end
	if active or hovered then
		local color = active and Color(255, 76, 56, 255) or Color(165, 174, 194, 255)
		Render.Rect(
			Vec2(rect.x - 1, rect.y - 1),
			Vec2(rect.x + rect.width + 1, rect.y + rect.height + 1),
			color,
			5,
			Enum.DrawFlags.None,
			active and 2 or 1
		)
	end
	if state.panel.dragFrom and state.panel.comboHitboxes[state.panel.dragFrom] == rect then
		Render.FilledRect(
			Vec2(rect.x, rect.y),
			Vec2(rect.x + rect.width, rect.y + rect.height),
			Color(255, 255, 255, 110),
			4
		)
	end
end

local function drawPanelSlots(settings, execution, cursorX, cursorY, alpha)
	local scaleValue = settings.panel.scale
	for _, entry in ipairs(state.panel.slotHitboxes) do
		local selected = entry.slot == state.panel.selectedSlot
		local active = settings.panel.showExecution and execution.active and execution.slot == entry.slot
		local hovered = rectContains(entry.rect, cursorX, cursorY)
		if selected or active or hovered then
			local background = active and Color(199, 57, 43, alpha) or Color(44, 49, 60, alpha)
			Render.FilledRect(
				Vec2(entry.rect.x, entry.rect.y),
				Vec2(entry.rect.x + entry.rect.width, entry.rect.y + entry.rect.height),
				background,
				3 * scaleValue
			)
		end
		local color = Color(173, 180, 190, alpha)
		if selected or active then color = Color(255, 88, 65, alpha) end
		local textSize = Render.TextSize(renderCtx.font, 14 * scaleValue, entry.slot)
		Render.Text(
			renderCtx.font,
			14 * scaleValue,
			entry.slot,
			Vec2(entry.rect.x + (entry.rect.width - textSize.x) * 0.5, entry.rect.y + 3 * scaleValue),
			color
		)
	end
end

local function drawCompactPanel(settings, execution, cursorX, cursorY, panelHovered, alpha)
	local panel = state.panel
	local scaleValue = settings.panel.scale
	local actions = panelActions()
	local iconSize = 31 * scaleValue
	local startX = panel.x + 9 * scaleValue
	local startY = panel.y + (panelHovered and 55 or 34) * scaleValue
	if #actions == 0 then
		local text = panel.selectedSlot == "D" and tr("panel.dynamic_empty") or tr("panel.combo_empty")
		Render.Text(renderCtx.font, 14 * scaleValue, text, Vec2(startX, startY + 7 * scaleValue), Color(128, 135, 148, alpha))
	else
		for index, id in ipairs(actions) do
			if index > 8 then break end
			local vertical = settings.panel.orientation == "vertical"
			local rect = {
				x = vertical and startX or startX + (index - 1) * (iconSize + 3 * scaleValue),
				y = vertical and startY + (index - 1) * (iconSize + 3 * scaleValue) or startY,
				width = iconSize,
				height = iconSize,
			}
			local active = settings.panel.showExecution
				and execution.active
				and execution.slot == panel.selectedSlot
				and execution.actionIndex == index
			local disabled, cooldown = false, 0
			if panel.selectedSlot ~= "D" then disabled, cooldown = panelActionUnavailable(id) end
			drawPanelAction(id, rect, active, false, disabled, alpha, cooldown)
		end
	end
	if settings.panel.statusText and state.status ~= "" then
		local statusText = tostring(state.status)
		local text = #statusText > 42 and statusText:sub(1, 39) .. "..." or statusText
		local size = comboPanelSize(settings)
		Render.Text(
			renderCtx.font,
			12 * scaleValue,
			text,
			Vec2(panel.x + 9 * scaleValue, panel.y + size.height - 16 * scaleValue),
			phaseColors[state.statusPhase] or phaseColors.idle
		)
	end
end

local function drawExpandedPanel(settings, execution, cursorX, cursorY, alpha)
	local panel = state.panel
	local scaleValue = settings.panel.scale
	local heading = panel.selectedSlot == "D" and tr("panel.dynamic_toggle") or tr("panel.palette")
	if panel.selectedSlot ~= "D" and rectContains(panel.strict, cursorX, cursorY) then heading = tr("panel.strict_hint") end
	local headingSize = panel.selectedSlot ~= "D" and rectContains(panel.strict, cursorX, cursorY) and 11 or 14
	Render.Text(renderCtx.font, headingSize * scaleValue, heading, Vec2(panel.x + 10 * scaleValue, panel.y + 58 * scaleValue), Color(172, 178, 189, alpha))
	for _, entry in ipairs(panel.paletteHitboxes) do
		local disabled, cooldown = false, 0
		if panel.selectedSlot == "D" then
			disabled = not panelDynamicActionEnabled(entry.id)
		else
			disabled, cooldown = panelActionUnavailable(entry.id)
		end
		drawPanelAction(entry.id, entry.rect, false, rectContains(entry.rect, cursorX, cursorY), disabled, alpha, cooldown)
	end

	local paletteRows = math.ceil(#allActionIds / 10)
	local sectionY = panel.y + (92 + paletteRows * 40) * scaleValue
	local section = panel.selectedSlot == "D"
		and tr("panel.dynamic_preview")
		or tr("panel.combo_slot") .. " " .. panel.selectedSlot
	Render.Text(renderCtx.font, 14 * scaleValue, section, Vec2(panel.x + 10 * scaleValue, sectionY), Color(172, 178, 189, alpha))
	if panel.selectedSlot ~= "D" then
		drawPanelControl(renderCtx.controls.close, panel.clear, rectContains(panel.clear, cursorX, cursorY), alpha)
		local strict = state.comboStrict[panel.selectedSlot]
		local rect = panel.strict
		Render.FilledRect(Vec2(rect.x, rect.y), Vec2(rect.x + rect.width, rect.y + rect.height),
			strict and Color(42, 92, 74, alpha) or Color(38, 43, 52, alpha), 3)
		Render.Text(renderCtx.font, 12 * scaleValue, (strict and "[x] " or "[ ] ") .. tr("panel.strict_order"),
			Vec2(rect.x + 5 * scaleValue, rect.y + 2 * scaleValue), Color(220, 226, 235, alpha))
	end

	local actions = panelActions()
	if #actions == 0 then
		local hint = panel.selectedSlot == "D" and tr("panel.dynamic_hint") or tr("panel.combo_hint")
		Render.Text(renderCtx.font, 14 * scaleValue, hint, Vec2(panel.x + 12 * scaleValue, sectionY + 35 * scaleValue), Color(104, 110, 122, alpha))
	end
	for index, id in ipairs(actions) do
		local rect = panel.comboHitboxes[index]
		if rect then
			local active = settings.panel.showExecution
				and execution.active
				and execution.slot == panel.selectedSlot
				and execution.actionIndex == index
			local disabled, cooldown = panelActionUnavailable(id)
			if panel.selectedSlot == "D" then disabled, cooldown = false, 0 end
			drawPanelAction(id, rect, active, rectContains(rect, cursorX, cursorY), disabled, alpha, cooldown)
			if index < #actions then
				local arrowStart = Vec2(rect.x + rect.width + 2 * scaleValue, rect.y + rect.height * 0.5)
				Render.Line(arrowStart, Vec2(arrowStart.x + 5 * scaleValue, arrowStart.y), Color(94, 101, 113, alpha), 1.5 * scaleValue)
			end
		end
	end
	if settings.panel.statusText and state.status ~= "" then
		local statusText = tostring(state.status)
		local text = #statusText > 62 and statusText:sub(1, 59) .. "..." or statusText
		local size = comboPanelSize(settings)
		Render.Text(
			renderCtx.font,
			12 * scaleValue,
			text,
			Vec2(panel.x + 10 * scaleValue, panel.y + size.height - 24 * scaleValue),
			phaseColors[state.statusPhase] or phaseColors.idle
		)
	end
end

function helpers.drawComboPanel()
	local panel = state.panel
	if not ui.enabled:Get()
		or not ui.showPanel:Get()
		or not state.snapshot
		or not state.snapshot.activeGame
		or not state.snapshot.hero.alive
	then
		panel.header = nil
		panel.expand = nil
		panel.clear = nil
		panel.slotHitboxes = {}
		panel.paletteHitboxes = {}
		panel.comboHitboxes = {}
		return
	end

	local settings = readSettings()
	local size = comboPanelSize(settings)
	local screen = Render.ScreenSize()
	helpers.positionComboPanel(panel, size, screen)
	rebuildComboPanelHitboxes(settings, size)

	local cursorX, cursorY = Input.GetCursorPos()
	local panelHovered = rectContains({x = panel.x, y = panel.y, width = size.width, height = size.height}, cursorX, cursorY)
	local alpha = math.floor(255 * 0.94 + 0.5)
	local scaleValue = settings.panel.scale
	Render.FilledRect(Vec2(panel.x, panel.y), Vec2(panel.x + size.width, panel.y + size.height), Color(7, 9, 13, alpha), 6 * scaleValue)
	Render.Rect(
		Vec2(panel.x, panel.y),
		Vec2(panel.x + size.width, panel.y + size.height),
		Color(72, 78, 91, math.min(210, alpha)),
		6 * scaleValue,
		Enum.DrawFlags.None,
		1
	)

	local headerHovered = rectContains(panel.header, cursorX, cursorY)
	local headerColor = headerHovered and Color(24, 28, 36, alpha) or Color(18, 22, 29, alpha)
	Render.FilledRect(
		Vec2(panel.header.x, panel.header.y),
		Vec2(panel.header.x + panel.header.width, panel.header.y + panel.header.height),
		headerColor,
		6 * scaleValue
	)
	local title = panel.expanded and tr("panel.title") or tr("panel.slot") .. " " .. panel.selectedSlot
	Render.Text(renderCtx.titleFont, 16 * scaleValue, title, Vec2(panel.x + 10 * scaleValue, panel.y + 6 * scaleValue), Color(232, 235, 240, alpha))
	local arrow = panel.expanded and renderCtx.controls.arrowLeft or renderCtx.controls.arrowRight
	drawPanelControl(arrow, panel.expand, rectContains(panel.expand, cursorX, cursorY), alpha)

	local execution = panelExecution()
	if settings.panel.showExecution and execution.active then
		Render.FilledCircle(
			Vec2(panel.x + panel.header.width - 55 * scaleValue, panel.y + 14 * scaleValue),
			3.5 * settings.panel.indicatorScale,
			Color(255, 77, 58, alpha),
			0,
			1,
			12
		)
	end
	if panel.expanded or panelHovered then drawPanelSlots(settings, execution, cursorX, cursorY, alpha) end
	if panel.expanded then
		drawExpandedPanel(settings, execution, cursorX, cursorY, alpha)
	else
		drawCompactPanel(settings, execution, cursorX, cursorY, panelHovered, alpha)
	end
end

function helpers.spellCraftStatus(id, snapshot)
	local definition = definitions[id]
	local learned = recipeAvailable(definition.recipe, snapshot.hero.orbLevels)
	local invokedIndex
	for index, invokedId in ipairs(snapshot.invoke.invoked) do
		if invokedId == id then invokedIndex = index; break end
	end
	local invoked = invokedIndex ~= nil
	local action = snapshot.actions[id]
	return {
		learned = learned,
		invoked = invoked,
		frontSlot = invokedIndex == 1,
		craftableNow = learned and (invokedIndex == 1 or snapshot.invoke.ready),
		cooldown = math.max(0, action and action.cooldown or 0),
	}
end

function helpers.drawSpellBarAction(rect, status, hovered, scaleValue)
	Render.FilledRect(
		Vec2(rect.x - 2 * scaleValue, rect.y - 2 * scaleValue),
		Vec2(rect.x + rect.width + 2 * scaleValue, rect.y + rect.height + 2 * scaleValue),
		Color(22, 26, 34, 250),
		6 * scaleValue
	)
	local brightness = 120
	if not status.learned then
		brightness = 55
	elseif status.craftableNow or status.invoked then
		brightness = 255
	end
	Render.Image(
		renderCtx.icons[rect.id],
		Vec2(rect.x, rect.y),
		Vec2(rect.width, rect.height),
		Color(brightness, brightness, brightness, status.learned and 255 or 115),
		5 * scaleValue
	)
	if not status.learned then
		Render.FilledRect(
			Vec2(rect.x, rect.y),
			Vec2(rect.x + rect.width, rect.y + rect.height),
			Color(8, 10, 14, 170),
			5 * scaleValue
		)
	elseif not status.craftableNow and not status.invoked then
		Render.FilledRect(
			Vec2(rect.x, rect.y),
			Vec2(rect.x + rect.width, rect.y + rect.height),
			Color(8, 10, 14, 105),
			5 * scaleValue
		)
	end
	if status.cooldown > 0.05 then
		Render.FilledRect(
			Vec2(rect.x, rect.y),
			Vec2(rect.x + rect.width, rect.y + rect.height),
			Color(4, 5, 8, 145),
			5 * scaleValue
		)
		local text = status.cooldown < 10 and ("%.1f"):format(status.cooldown) or tostring(math.ceil(status.cooldown))
		local textSize = Render.TextSize(renderCtx.cooldownFont, 15 * scaleValue, text)
		Render.Text(
			renderCtx.cooldownFont,
			15 * scaleValue,
			text,
			Vec2(rect.x + (rect.width - textSize.x) * 0.5, rect.y + (rect.height - textSize.y) * 0.5),
			Color(255, 255, 255, 250)
		)
	end
	if status.invoked or status.craftableNow or hovered then
		local color = status.frontSlot and Color(79, 219, 154, 255)
			or status.invoked and Color(102, 181, 255, 255)
			or hovered and Color(255, 151, 91, 255)
			or Color(224, 228, 235, 255)
		Render.Rect(
			Vec2(rect.x - 2 * scaleValue, rect.y - 2 * scaleValue),
			Vec2(rect.x + rect.width + 2 * scaleValue, rect.y + rect.height + 2 * scaleValue),
			color,
			6 * scaleValue,
			Enum.DrawFlags.None,
			status.invoked and 2 or 1
		)
	end
end

function helpers.drawSpellBar()
	local spellBar = state.spellBar
	local snapshot = state.snapshot
	if not ui.enabled:Get()
		or not ui.showSpellBar:Get()
		or not snapshot
		or not snapshot.activeGame
		or not snapshot.hero.alive
	then
		spellBar.panelRect = nil
		spellBar.gripRect = nil
		spellBar.hitboxes = {}
		return
	end

	local settings = readSettings()
	local geometry = spellBarGeometry(settings)
	applySpellBarGeometry(geometry)
	local cursorX, cursorY = Input.GetCursorPos()
	Render.FilledRect(
		Vec2(geometry.panel.x, geometry.panel.y),
		Vec2(geometry.panel.x + geometry.panel.width, geometry.panel.y + geometry.panel.height),
		Color(7, 9, 13, 222),
		6 * geometry.scale
	)
	Render.Rect(
		Vec2(geometry.panel.x, geometry.panel.y),
		Vec2(geometry.panel.x + geometry.panel.width, geometry.panel.y + geometry.panel.height),
		Color(75, 81, 94, 215),
		6 * geometry.scale,
		Enum.DrawFlags.None,
		1
	)
	local gripWidth = math.min(26 * geometry.scale, geometry.grip.width - 6 * geometry.scale)
	local gripHeight = math.max(2, 2 * geometry.scale)
	Render.FilledRect(
		Vec2(geometry.grip.x + (geometry.grip.width - gripWidth) * 0.5, geometry.grip.y + geometry.grip.height * 0.5 - math.max(1, geometry.scale)),
		Vec2(geometry.grip.x + (geometry.grip.width + gripWidth) * 0.5, geometry.grip.y + geometry.grip.height * 0.5 - math.max(1, geometry.scale) + gripHeight),
		spellBar.dragging and Color(255, 151, 91, 230) or Color(126, 133, 148, 230),
		geometry.scale
	)
	for _, rect in ipairs(geometry.icons) do
		helpers.drawSpellBarAction(
			rect,
			helpers.spellCraftStatus(rect.id, snapshot),
			rectContains(rect, cursorX, cursorY),
			geometry.scale
		)
	end
end

function invoker.OnUpdate()
	coreRun()
end

function invoker.OnUpdateEx()
	helpers.updateBindIsland()
end

function invoker.OnDraw()
	helpers.drawComboPanel()
	helpers.drawSpellBar()
	drawQuickSunButtons()
end

function invoker.OnPrepareUnitOrders(data)
	if state.issuingOrder or GameRules.GetGameTime() <= state.orderGuardUntil then return true end
	local hero = Heroes.GetLocal()
	if not hero or NPC.GetUnitName(hero) ~= cfg.heroName then return true end
	if data.npc and Entity.GetIndex(data.npc) == Entity.GetIndex(hero) then
		state.moveOrder = nil
		state.kiteAttack = nil
	end
	if state.bindJob and (data.npc and Entity.GetIndex(data.npc) == Entity.GetIndex(hero)
		or data.ability and Entity.RecursiveOwnedBy(data.ability, hero))
	then
		helpers.cancelBind("Manual order took priority.", false)
		state.automaticActionsPausedUntil = GameRules.GetGameTime() + cfg.manualActionPause
	end
	if data.ability and Entity.RecursiveOwnedBy(data.ability, hero) then
		state.bindPreparedSpell = nil
		local now = GameRules.GetGameTime()
		state.automaticActionsPausedUntil = now + cfg.manualActionPause
		state.autoOrbsPausedUntil = now + ui.manualOrderPause:Get() / 10
		state.autoPending = nil
		state.invokeSequence = nil
		state.orbSequence = nil
		if state.plan then abortPlan("Manual ability order took priority.") end
		logDebug("INPUT", "manual ability order paused automatic actions")
	end
	return true
end

function invoker.OnProjectile(data)
	helpers.onComboProjectile(data)
end

function invoker.OnEntityDestroy(entity)
	local index = Entity.GetIndex(entity)
	if state.landings then state.landings[index] = nil end
	state.motion[index] = nil
	if state.roshan and state.roshan.index == index then state.roshan = nil end
	if state.tormentors then state.tormentors[index] = nil end
end

function invoker.OnEntityKilled(data)
	if data.target and state.landings then state.landings[Entity.GetIndex(data.target)] = nil end
	if data.target and state.tormentors then state.tormentors[Entity.GetIndex(data.target)] = nil end
end

function invoker.OnEntityHurt(data)
	local job = state.bindJob
	if job and job.kind == "farm" and job.phase == "tag" and data.source and state.hero
		and Entity.GetIndex(data.source) == Entity.GetIndex(state.hero)
		and data.target and Entity.GetIndex(data.target) == job.attackIndex and data.damage > 0
	then
		job.tagged = true
	end
	helpers.onTormentorDamage(data)
	local track = state.roshan
	if not track or not data.target or not data.source or data.damage <= 0
		or Entity.GetIndex(data.target) ~= track.index
	then
		return
	end
	if state.hero and Entity.IsSameTeam(state.hero, data.source) then
		track.lastAlliedDamageAt = GameRules.GetGameTime()
	end
end

function invoker.OnModifierCreate(entity, modifier)
	helpers.recordLandingModifier(entity, modifier)
end

function invoker.OnModifierUpdate(entity, modifier)
	helpers.recordLandingModifier(entity, modifier)
end

function invoker.OnModifierDestroy(entity, modifier)
	helpers.destroyLandingModifier(entity, modifier)
end

function invoker.OnParticleCreate(data)
	helpers.createTeleportParticle(data)
end

function invoker.OnParticleUpdate(data)
	helpers.updateTeleportParticle(data)
end

function invoker.OnParticleUpdateFallback(data)
	helpers.updateTeleportParticle(data)
end

function invoker.OnParticleUpdateEntity(data)
	helpers.attachTeleportTarget(data)
end

function invoker.OnParticleDestroy(data)
	if state.teleportParticles then state.teleportParticles[data.index] = nil end
end

function invoker.OnGameEnd()
	helpers.setBindIslandVisible(false)
	resetRuntime()
	state.fountain = {done = false, queued = false, nextTrainAt = 0, trainAttempts = 0}
end

return invoker
