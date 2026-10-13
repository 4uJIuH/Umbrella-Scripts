-- INVOKER SUN STRIKE ONLY
-- Invoker SS v138: stricter automatic accuracy gates and reduced prediction/UI work.
-- Active runtime/UI: Sun Strike, landing shots, portrait shots, Roshan/Tormentor steals, Cataclysm + Refresher.
-- Combo, binds, auto-orbs, interrupts and panels are not executed by this standalone module.

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
---@field projectileSpeed number
---@field fixedDelay number
---@field requiresScepter? string

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
---@field fogProjected? boolean
---@field fogAge? number

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


local cfg = {
	heroName = "npc_dota_hero_invoker",
	invokeOrbInterval = 0.035,
	autoOrbInterval = 0.04,
	invokeConfirmWindow = 0.65,
	castConfirmMin = 0.75,
	commandGap = 0.075,
	timingSafety = 0.065,
	sunCommandDelaySampleWindow = 7,
	objectiveHistorySeconds = 0.8,
	objectiveRecentDamageSeconds = 0.6,
	roshanSpawnerScanSeconds = 5,
	manualActionPause = 0.35,
	autoSunResumeDelay = 3.0,
	motionResetDistance = 200,
	teleportMotionQuarantine = 0.55,
	-- v71: ownerless TP origin particles may veto NORMAL Auto-Sun only for recent, spatially compatible enemy origins.
	teleportOwnerResolveRadius = 220,
	teleportOwnerResolveAge = 0.70,
	teleportOwnerResolveGap = 70,
	-- v71: short per-target stat-speed history learns speed regimes from the game instead of hard-coding slow/buff names.
	persistentTraceCheckpointChars = 4096,
	persistentTraceCheckpointSeconds = 0.75,
	persistentTraceRetrySeconds = 2.0,
	persistentTraceFailureBufferChars = 131072,
	persistentTracePath = [[C:\Soft\Umbrella\scripts\invoker_ss_game_log.txt]],
	fogRouteTTL = 1.0,
	sunRadius = 175,
	-- v87: "near lethal" means projected HP is within 20% above the calculated lethal damage threshold.
	autoUseNearLethalFactor = 1.20,
	-- v55 Auto-Sun-only safeguards. v60 extends stationary proof through fog only from already-proven observed samples.
	sunHpLatchFallbackAge = 1.75,
	sunStationaryMinWindow = 0.80,
	sunStationaryRadius = 28,
	sunStationaryPath = 90,
	-- v62 keeps v59 unified visible/fog motion + v60 observed-stationary fog continuation and replaces v58 ray-first correction with topology-first GridNav branches.
	sunTerrainCacheAge = 0.08,
	sunTerrainLookahead = 520,
	sunTerrainMinIntentDistance = 900,
	sunTerrainMaxIntentDistance = 1800,
	sunTerrainClusterRadius = 118,
	sunTerrainMinCoverage = 0.90,
	sunTerrainForkCoverage = 0.95,
	sunTerrainGateConfidence = 0.78,
	sunTerrainBranchMergeRadius = 132,
	sunTerrainLongitudinalSpread = 0.10,
	sunTerrainEntropyGate = 0.74,
	sunTerrainTemporalGate = 0.42,
	sunTerrainTemporalAge = 0.70,
	-- v95: map lookahead may inspect farther, but a forced turn may only own THIS Sun if the
	-- obstacle lies inside the target's reachable decision horizon (+ command-timing reserve).
	sunTerrainDecisionReserve = 220,
	sunCameraGlobalCooldown = 20.0,
	sunCameraReturnDelay = 3.0,
	sunCameraCastWaitTimeout = 8.0,
	sunNotificationHeartbeatTTL = 3.50,
	sunAttentionScanInterval = 0.10,
	sunPortraitPredictionInterval = 0.10,
	sunControlledEscapeRadiusFactor = 0.75,
	sunPostCastTraceInterval = 0.10,
	configName = "invoker_ss_top_v15",
	landingScanInterval = 0.1,
	landingImpactOffset = 0.08,
	tornadoLandingImpactOffset = 0.03, -- v78: normal Tornado Landing Sun aims ~30 ms after landing
	tornadoCataclysmLandingImpactOffset = 0.03, -- v78: Cata landing safety ~30 ms; also extends each +1-target reset window
	landingSplitCohortTolerance = 0.15, -- v100: modifier discovery may stagger same-Tornado victims by a scan/frame
	tornadoLandingSplitCohortTolerance = 0.45, -- v112: one Tornado can release nearby victims several frames apart
	teleportLandingImpactOffset = 0.005, -- legacy TP Cataclysm/non-Sun landing offset
	teleportSunTriggerRemaining = 1.70, -- v57: minimum/base trigger; runtime adds measured Sun command delay
	teleportSunLandingDelay = 0.03, -- v81: TP Sun aims ~30 ms after TP completion
	teleportSunTriggerLateTolerance = 0.12,
	landingMaxLate = 0.25,
	landingOrderTolerance = 0.045,
	landingCataclysmGroupWindow = 0.40,
	landingCataclysmCollectTolerance = 0.05,
	landingCataclysmQueueLead = 0.45,
	teleportParticleLifetime = 10,
	fogTeleportDuration = 3,
	teleportHistorySeconds = 30,
	teleportAmbiguityRadius = 1150,
	landingModifiers = {modifier_teleporting = "teleport", modifier_eul_cyclone = "cyclone", modifier_invoker_tornado = "cyclone"},
}

local menuIcons = {
	hero = "panorama/images/heroes/icons/npc_dota_hero_invoker_png.vtex_c",
	roshan = "panorama/images/hud/icon_roshan_psd.vtex_c",
	tormentor = "panorama/images/control_icons/24px/tormentor_png.vtex_c",
	scepter = "panorama/images/items/ultimate_scepter_png.vtex_c",
}

local fontIcons = {
	bug = "\u{f188}",
	clock = "\u{f017}",
	crosshairs = "\u{f05b}",
	exchange = "\u{f0ec}",
	forward = "\u{f04e}",
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
		["tip.auto_tormentor"] = "Automatically try to finish Tormentor with SS.\nEstimates shield, reflected damage and regeneration.\nFog estimates may drift.",
		["gear.tormentor"] = "Tormentor steal settings",
		["ui.auto_roshan"] = "Steal Roshan with SS",
		["tip.auto_roshan"] = "Automatically try to finish Roshan with SS.\nUses HP, incoming damage, position and impact delay.\nDoes not interrupt a held combo.",
		["gear.roshan"] = "Roshan steal settings",
		["ui.roshan_margin"] = "Damage margin",
		["tip.roshan_margin"] = "Damage reserve for Roshan HP/timing uncertainty.\nHigher value makes Auto SS more conservative.",
		["tip.tormentor_margin"] = "Extra safety reserve for Tormentor shield estimation.\nHigher value makes Auto SS more conservative.",
		["tab.auto"] = "Automatic",
		["tab.extra"] = "Advanced",
		["group.sun_strike"] = "SS",
		["group.cataclysm"] = "Cataclysm & Refresher",
		["group.extra"] = "Diagnostics",
		["title.landing_sun"] = "SS on Landing",
		["gear.sun"] = "SS Conditions",
		["ui.enabled"] = "Enabled",
		["ui.auto_cataclysm"] = "Auto Cataclysm",
		["ui.cataclysm_self_charge"] = "Self-charge Cataclysm",
		["ui.cataclysm_tornado"] = "Cata on Tornado",
		["ui.auto_refresher"] = "Refresher after Cataclysm",
		["tip.cataclysm_tornado"] = "Enable the separate Tornado Cataclysm path.\nCounts confirmed victims of one Invoker Tornado.\nThe latest caught target is the timing anchor.",
		["tip.auto_refresher"] = "After confirmed Cataclysm, use Refresher\nand cast Cataclysm again when mana allows.\nTornado repeats keep the confirmed group.",
		["ui.cataclysm_min_heroes"] = "Minimum Controlled Heroes",
		["title.cataclysm_auto_use"] = "Cataclysm Auto-use",
		["ui.cataclysm_use_mode"] = "Auto-use",
		["ui.cataclysm_min_mana"] = "Minimum Mana %",
		["tip.cataclysm_use_mode"] = "Auto Cataclysm policy after enough targets are found.\nAlways / lethal / near lethal.\nNear lethal = HP up to 120% of projected damage.",
		["tip.cataclysm_min_mana"] = "Mana reserve for Auto Cataclysm.\nAt least this % must remain after the cast.\nRefresher uses the same reserve.",
		["ui.auto_sun_strike"] = "Auto SS",
		["ui.sun_with_scepter"] = "Use SS with Scepter",
		["ui.sun_self_charge"] = "Self-charge SS",
		["ui.landing_sun"] = "SS on Arrival",
		["ui.landing_teleports"] = "Teleport Destinations",
		["title.landing_teleports"] = "SS at Teleport Destination",
		["ui.landing_tp_any_hp"] = "TP: Fire at Any HP",
		["ui.landing_tp_lethal"] = "TP: Lethal Only",
		["tip.landing_tp_any_hp"] = "Fire at TP destination regardless of target HP.\nUses live TP remaining time and the 0.03 s reserve.\nTakes priority over Lethal Only.",
		["tip.landing_tp_lethal"] = "Fire at TP destination only after a lethal check.\nThe decision is latched once for that teleport.\nAny HP takes priority when both are ON.",
		["ui.landing_cyclones"] = "Cyclone / Tornado Landings",
		["ui.landing_lethal"] = "Only Lethal Landings",
		["tip.landing_sun"] = "Auto SS for TP/Cyclone/Tornado landing time.\nUses the nested HP rules and current Landing timing.\nUses the ordinary SS mana reserve.",
		["tip.landing_teleports"] = "Enable Landing SS on enemy teleports.\nAim at the real destination point.\nThe two nested modes decide when it may fire.",
		["tip.landing_cyclones"] = "Enable Landing SS after Eul/Cyclone/Tornado.\nThe shot is synchronized to the real landing time.",
		["tip.landing_lethal"] = "ON: Tornado/Eul Landing SS requires lethal damage.\nTeleport uses its own separate modes.",
		["ui.sun_min_mana"] = "Minimum Mana %",
		["ui.sun_walk_time"] = "Walk Time",
		["ui.sun_idle_time"] = "Idle Time",
		["ui.use_controlled_targets"] = "Use on Disabled Targets",
		["ui.control_use_mode"] = "Auto-use",
		["ui.control_hp_percent"] = "Maximum Controlled Target HP",
		["title.control_targets"] = "Controlled Target SS",
		["mode.use_always"] = "Use always",
		["mode.lethal"] = "If lethal damage",
		["mode.near_lethal"] = "If close to lethal",
		["mode.by_hp"] = "By HP",
		["ui.predict_running_targets"] = "Predict Running Targets",
		["ui.anti_zigzag"] = "Anti-Zigzag",
		["ui.fog_route_sun"] = "SS on Fog Route",
		["ui.quick_sun_buttons"] = "Manual SS by Portrait",
		["ui.moving_sun_block_visual"] = "Hit Indicator",
		["title.moving_sun_block"] = "Hit Indicator",
		["ui.sun_count_misses"] = "Count Misses",
		["ui.moving_sun_block_standing"] = "SS on Standing",
		["group.sun_safe"] = "Safe SS Mode",
		["ui.sun_safe_camera_move"] = "Move Camera",
		["ui.sun_safe_camera_return"] = "Return Camera 3 sec after SS",
		["ui.sun_safe_camera_only"] = "SS Only Inside Camera",
		["ui.sun_safe_dry_run"] = "Calculations Only — Do Not Cast SS",
		["ui.sun_indication"] = "Indication",
		["ui.sun_trajectory"] = "Movement Trajectory",
		["ui.sun_notification"] = "Notification",
		["ui.sun_notification_camera_only"] = "Camera Only via Notification",
		["notify.sun_ready"] = "SS ready",
		["notify.sun_offscreen"] = "SS off-screen — click to view",
		["ui.file_log"] = "File Runtime Log",
		["ui.refresh_log"] = "Refresh Log File",
		["tip.enabled"] = "Enable the whole Invoker SS module.\nOFF: automation and indicators are disabled.",
		["tip.auto_cataclysm"] = "Master switch for Auto Cataclysm.\nOrdinary controlled-target Cataclysm is handled here.\nThe Tornado path is enabled separately below.",
		["tip.cataclysm_self_charge"] = "ON: uses EEE → Invoke when needed.\nOFF: Cataclysm only when Sun is already in D/F.",
		["tip.cataclysm_min_heroes"] = "Minimum enemies required for Auto Cataclysm.\nTornado counts confirmed victims of the same Tornado.\nEach new victim updates the latest anchor.",
		["tip.auto_sun_strike"] = "Ordinary SS: Auto/Landing/Control/Moving.\nAlso Portrait/Roshan/Tormentor.\nCataclysm stays independent.",
		["tip.sun_with_scepter"] = "OFF: Exort Scepter holds ordinary Auto SS.\nON: ordinary Auto SS may fire with Scepter too.\nManual portrait SS is never blocked here.",
		["tip.sun_self_charge"] = "ON: uses EEE → Invoke when needed.\nOFF: SS is used only when already present in D/F.",
		["tip.sun_min_mana"] = "Mana reserve for ordinary Auto SS.\nAt least this % must remain after the cast.\nManual portrait SS ignores this reserve.",
		["tip.sun_walk_time"] = "How long the target must run stably\nbefore moving-target SS is allowed.",
		["tip.sun_idle_time"] = "How long the target must stand still\nbefore ordinary lethal Auto SS is allowed.\nPortrait X also uses SS on Standing.",
		["tip.use_controlled_targets"] = "Allow SS on a visible hard-controlled target.\nControl is required when the target is acquired.\nAfter lock it may end before impact.",
		["tip.control_use_mode"] = "Policy for SS on controlled targets.\nAlways / lethal / near lethal / by HP.\nNear lethal = HP up to 120% of projected damage.",
		["tip.control_hp_percent"] = "Current-HP threshold only for By HP mode.\n100% allows a full-HP controlled target.",
		["tip.predict_running_targets"] = "Allow Auto SS on running targets.\nRequires a sufficiently stable movement direction.",
		["tip.anti_zigzag"] = "Validate the target route through GridNav.\nZig-zag, route forks or weak confidence hold the SS.",
		["tip.fog_route_sun"] = ("After a runner enters fog, keep its confirmed route\nfor up to %g s.\nThen discard that route."):format(cfg.fogRouteTTL),
		["tip.quick_sun_buttons"] = ("Show an SS button under enemy portraits.\nManual shots do not require lethal damage.\nThe target may be retained in fog for up to %g s."):format(cfg.fogRouteTTL),
		["tip.moving_sun_block_visual"] = "Neutral dot → red MISS / yellow HIT / green KILL.\nObserves every real SS/Cataclysm from our Invoker.\nClick the indicator to toggle X.",
		["tip.sun_count_misses"] = "ON: replace the dot with the miss count.\nOnly eligible ordinary Auto-SS misses are counted.\nOFF: misses are not accumulated.",
		["tip.moving_sun_block_standing"] = "Only for heroes with X.\nON: X blocks moving SS; standing SS is allowed.\nOFF: X blocks both moving and standing SS.",
		["tip.sun_safe_camera_move"] = "If Auto SS is off-screen, move the camera first.\nAuto move: once per candidate and no more than once per 20s globally.\nManual SS and Cataclysm are unaffected.",
		["tip.sun_safe_camera_return"] = "Return the camera 3 seconds after Sun Strike impacts.\nManual camera movement cancels the return.",
		["tip.sun_safe_camera_only"] = "Allow Auto SS only inside the current camera.\nWith camera move it waits; without it the cast is held.",
		["tip.sun_safe_dry_run"] = "Keep calculations, indication and notifications active.\nDo not send the physical Sun Strike order.",
		["tip.sun_indication"] = "Show the final calculated Auto-SS point.\nAppears only after normal target and safety checks.",
		["tip.sun_trajectory"] = "Draw target -> calculated SS point.\nKeep the last valid vector for a lethal lock.\nHide it when the target is no longer lethal.",
		["tip.sun_notification"] = "Keep one notice per valid Auto-SS target.\nFog/aim refresh does not reopen it.\nClick one to move the camera there.",
		["tip.sun_notification_camera_only"] = "Disable automatic camera movement.\nMove to the SS point only by clicking its notification.\nSS Only Inside Camera waits for that transition.",
		["tip.file_log"] = "Write runtime data to invoker_ss_game_log.txt.\nTurning it on again clears and restarts the log.",
		["tip.refresh_log"] = "Clear invoker_ss_game_log.txt.\nIf logging is ON, writing continues.\nIf OFF, it stays disabled.",
	},
	ru = {
		["group.auto_steal"] = "Автокража",
		["ui.auto_tormentor"] = "Красть Tormentor",
		["tip.auto_tormentor"] = "Автоматически пытается добить Tormentor через SS.\nОценивает щит, отражённый урон и реген.\nВ тумане возможна погрешность оценки.",
		["gear.tormentor"] = "Настройки кражи Tormentor",
		["ui.auto_roshan"] = "Красть Рошана через SS",
		["tip.auto_roshan"] = "Автоматически пытается добить Roshan через SS.\nУчитывает HP, урон, позицию и задержку попадания.\nНе мешает удерживаемому комбо.",
		["gear.roshan"] = "Настройки кражи Рошана",
		["ui.roshan_margin"] = "Запас урона",
		["tip.roshan_margin"] = "Запас урона на погрешность HP/тайминга Roshan.\nБольше значение → более осторожный Auto SS.",
		["tip.tormentor_margin"] = "Дополнительный запас по щиту Tormentor.\nБольше значение → более осторожный Auto SS.",
		["tab.auto"] = "Автокаст",
		["tab.extra"] = "Дополнительно",
		["group.sun_strike"] = "SS",
		["group.cataclysm"] = "Cataclysm и Refresher",
		["group.extra"] = "Дополнительно",
		["title.landing_sun"] = "SS по приземлению",
		["gear.sun"] = "Условия автокаста",
		["ui.enabled"] = "Включить",
		["ui.auto_cataclysm"] = "Авто Cataclysm",
		["ui.cataclysm_self_charge"] = "Самозарядка Cataclysm",
		["ui.cataclysm_tornado"] = "Cata по Tornado",
		["ui.auto_refresher"] = "Refresher после Cataclysm",
		["tip.cataclysm_tornado"] = "Разрешает отдельный Cataclysm по Tornado.\nСчитает подтверждённые цели одного Tornado.\nЯкорь — последняя пойманная цель.",
		["tip.auto_refresher"] = "После подтверждённого Cataclysm использует Refresher\nи повторяет Cataclysm, если хватает маны.\nДля Tornado сохраняет подтверждённую группу.",
		["ui.cataclysm_min_heroes"] = "Героев под контролем",
		["title.cataclysm_auto_use"] = "Авто-использование Cataclysm",
		["ui.cataclysm_use_mode"] = "Авто-использование",
		["ui.cataclysm_min_mana"] = "Минимум маны",
		["tip.cataclysm_use_mode"] = "Режим Auto Cataclysm после набора целей.\nВсегда / летальный / близко к летальному.\n«Близко» = HP до 120% рассчитанного урона.",
		["tip.cataclysm_min_mana"] = "Резерв маны для Auto Cataclysm.\nПосле каста должно остаться не меньше этого %.\nRefresher использует тот же резерв.",
		["ui.auto_sun_strike"] = "Автокаст SS",
		["ui.sun_with_scepter"] = "Использовать с Скипетром",
		["ui.sun_self_charge"] = "Самозарядка SS",
		["ui.landing_sun"] = "SS при приземлении",
		["ui.landing_teleports"] = "Точки телепортации",
		["title.landing_teleports"] = "SS в точку телепортации",
		["ui.landing_tp_any_hp"] = "TP: стрелять при любом HP",
		["ui.landing_tp_lethal"] = "TP: только летальный",
		["tip.landing_tp_any_hp"] = "Стреляет по TP независимо от HP цели.\nИспользует живой остаток TP и запас 0,03 с.\nИмеет приоритет над «Только летальный».",
		["tip.landing_tp_lethal"] = "Стреляет по TP только при lethal-проверке.\nПроверка фиксируется один раз на этом TP.\n«Любой HP» имеет приоритет.",
		["ui.landing_cyclones"] = "Приземление после Cyclone / Tornado",
		["ui.landing_lethal"] = "Только смертельные приземления",
		["tip.landing_sun"] = "Авто SS к моменту TP/Cyclone/Tornado приземления.\nИспользует вложенные HP-режимы и Landing-тайминг.\nУчитывает отдельный резерв маны SS.",
		["tip.landing_teleports"] = "Разрешает Landing SS по вражеским TP.\nЦелится в реальную точку назначения.\nРежим выбирают два пункта ниже.",
		["tip.landing_cyclones"] = "Разрешает Landing SS после Eul/Cyclone/Tornado.\nВыстрел синхронизируется с реальным приземлением.",
		["tip.landing_lethal"] = "ВКЛ: Tornado/Eul Landing SS только при lethal уроне.\nTP использует свои отдельные режимы.",
		["ui.sun_min_mana"] = "Минимум маны",
		["ui.sun_walk_time"] = "Время движения",
		["ui.sun_idle_time"] = "Время без движения",
		["ui.use_controlled_targets"] = "Цели под контролем",
		["ui.control_use_mode"] = "Авто-использование",
		["ui.control_hp_percent"] = "Макс. HP цели под контролем",
		["title.control_targets"] = "SS по цели под контролем",
		["mode.use_always"] = "Использовать всегда",
		["mode.lethal"] = "Если летальный урон",
		["mode.near_lethal"] = "Если близко к летальному",
		["mode.by_hp"] = "По HP",
		["ui.predict_running_targets"] = "Цели в движении",
		["ui.anti_zigzag"] = "Антизигзаг",
		["ui.fog_route_sun"] = "SS по маршруту в тумане",
		["ui.quick_sun_buttons"] = "Ручной SS по портрету",
		["ui.moving_sun_block_visual"] = "Индикатор попадания",
		["title.moving_sun_block"] = "Индикатор попадания",
		["ui.sun_count_misses"] = "Считать промахи",
		["ui.moving_sun_block_standing"] = "SS по стоящей",
		["group.sun_safe"] = "Безопасный режим SS",
		["ui.sun_safe_camera_move"] = "Перенос камеры",
		["ui.sun_safe_camera_return"] = "Вернуть камеру через 3 сек после SS",
		["ui.sun_safe_camera_only"] = "SS только в пределах камеры",
		["ui.sun_safe_dry_run"] = "Только расчёты — не бросать SS",
		["ui.sun_indication"] = "Индикация",
		["ui.sun_trajectory"] = "Траектория движения",
		["ui.sun_notification"] = "Уведомление",
		["ui.sun_notification_camera_only"] = "Переход только по уведомлению",
		["notify.sun_ready"] = "SS готов",
		["notify.sun_offscreen"] = "SS вне камеры — нажмите",
		["ui.file_log"] = "Файловый лог",
		["ui.refresh_log"] = "Обновить лог",
		["tip.enabled"] = "Включает весь Invoker SS.\nВЫКЛ: автоматика и индикаторы отключены.",
		["tip.auto_cataclysm"] = "Главный переключатель Auto Cataclysm.\nОбычный Control Cataclysm работает здесь.\nTornado-путь включается отдельно ниже.",
		["tip.cataclysm_self_charge"] = "ВКЛ: при необходимости делает EEE → Invoke.\nВЫКЛ: Cataclysm только если Sun уже в D/F.",
		["tip.cataclysm_min_heroes"] = "Минимум врагов для Auto Cataclysm.\nTornado считает подтверждённые цели одного каста.\nКаждая новая цель обновляет последний якорь.",
		["tip.auto_sun_strike"] = "Обычный SS: Auto/Landing/Control/Moving.\nТакже Portrait/Roshan/Tormentor.\nCataclysm работает отдельно.",
		["tip.sun_with_scepter"] = "ВЫКЛ: при Exort-Скипетре Auto SS не расходуется.\nВКЛ: обычный Auto SS разрешён и со Скипетром.\nРучной SS не блокируется.",
		["tip.sun_self_charge"] = "ВКЛ: при необходимости делает EEE → Invoke.\nВЫКЛ: SS используется только если уже есть в D/F.",
		["tip.sun_min_mana"] = "Резерв маны для обычного Auto SS.\nПосле каста должно остаться не меньше этого %.\nРучной SS по портрету резерв не проверяет.",
		["tip.sun_walk_time"] = "Сколько цель должна стабильно бежать,\nпрежде чем разрешится SS по движению.",
		["tip.sun_idle_time"] = "Сколько цель должна стоять,\nпрежде чем разрешится обычный lethal Auto SS.\nДля X действует «SS по стоящей».",
		["tip.use_controlled_targets"] = "Разрешает SS по видимой цели под hard control.\nКонтроль нужен в момент захвата.\nПосле lock он может закончиться раньше попадания.",
		["tip.control_use_mode"] = "Режим SS по контролируемой цели.\nВсегда / летальный / близко / по HP.\n«Близко» = HP до 120% рассчитанного урона.",
		["tip.control_hp_percent"] = "Порог текущего HP только для режима «По HP».\n100% разрешает цель с полным HP.",
		["tip.predict_running_targets"] = "Разрешает Auto SS по бегущим целям.\nТребует стабильного направления движения.",
		["tip.anti_zigzag"] = "Проверяет маршрут цели через GridNav.\nПри зигзаге, развилке или слабой уверенности SS ждёт.",
		["tip.fog_route_sun"] = ("После ухода бегущей цели в туман\nпродолжает последний подтверждённый маршрут до %g с.\nЗатем маршрут забывается."):format(cfg.fogRouteTTL),
		["tip.quick_sun_buttons"] = ("Показывает кнопку SS под портретами врагов.\nРучной выстрел не требует lethal.\nЦель может храниться в тумане до %g с."):format(cfg.fogRouteTTL),
		["tip.moving_sun_block_visual"] = "Шарик: красный MISS / жёлтый HIT / зелёный KILL.\nРаботает для всех реальных SS/Cataclysm нашего Invoker.\nНажатие по индикатору ставит или снимает X.",
		["tip.sun_count_misses"] = "ВКЛ: шарик заменяется числом промахов.\nСчитаются только подходящие промахи обычного Auto SS.\nВЫКЛ: промахи не накапливаются.",
		["tip.moving_sun_block_standing"] = "Только для X на портрете.\nВКЛ: X блокирует движение; стоящая цель разрешена.\nВЫКЛ: X блокирует движение и стоящую цель.",
		["tip.sun_safe_camera_move"] = "Если Auto SS вне камеры — переносит камеру.\nАвтоперенос: один раз на кандидата и не чаще одного раза в 20 с глобально.\nРучной SS и Cataclysm не затрагивает.",
		["tip.sun_safe_camera_return"] = "Возвращает камеру через 3 с после попадания Sun Strike.\nЕсли ты сам сдвинул камеру — возврат отменяется.",
		["tip.sun_safe_camera_only"] = "Auto SS разрешён только внутри текущей камеры.\nС переносом — ждёт камеру; без переноса — не кастует.",
		["tip.sun_safe_dry_run"] = "Расчёты, индикация и уведомления работают.\nФизический приказ Sun Strike не отправляется.",
		["tip.sun_indication"] = "Показывает финальную рассчитанную точку Auto SS.\nПоявляется только после обычных проверок.",
		["tip.sun_trajectory"] = "Рисует линию цель -> рассчитанная точка SS.\nПри lethal-lock держит последний валидный вектор.\nСбрасывает, если цель уже не летальная.",
		["tip.sun_notification"] = "Держит по одному уведомлению для каждой валидной цели Auto SS.\nТуман/обновление aim не создают его заново.\nПо нажатию можно перевести туда камеру.",
		["tip.sun_notification_camera_only"] = "Автоперенос камеры отключается.\nК точке SS камера идёт только по нажатию уведомления.\nС «SS только в пределах камеры» каст ждёт перехода.",
		["tip.file_log"] = "Пишет runtime-лог в invoker_ss_game_log.txt.\nПовторное включение очищает файл и начинает новый лог.",
		["tip.refresh_log"] = "Очищает invoker_ss_game_log.txt.\nЕсли лог ВКЛ — запись продолжится.\nЕсли ВЫКЛ — останется выключен.",
	},
}

local languageControl = Menu.Find("SettingsHidden", "", "", "", "Main", "Language")
local languageCodes = {}
for index, name in ipairs(languageControl and languageControl:List() or {}) do
	local code = name:match("%a+")
	if code and translations[code] then languageCodes[index - 1] = code end
end

local function tr(path)
	local code = languageControl and languageCodes[languageControl:Get()] or "en"
	return translations[code] and translations[code][path] or translations.en[path] or path
end

local localizedObjects = {}
local function translatedItems(items)
	local result = {}
	for index, path in ipairs(items or {}) do result[index] = tr(path) end
	return result
end

local function applyLocalization(record)
	local object = record.object
	if record.label and type(object.ForceLocalization) == "function" then object:ForceLocalization(tr(record.label)) end
	if record.tooltip and type(object.ToolTip) == "function" then object:ToolTip(tr(record.tooltip)) end
	if record.items and type(object.Update) == "function" then
		local value = object:Get()
		object:Update(translatedItems(record.items))
		object:Set(value)
	end
end

local function localized(object, labelPath, tooltip, items)
	local record = {object = object, label = labelPath, tooltip = tooltip, items = items}
	localizedObjects[#localizedObjects + 1] = record
	applyLocalization(record)
	return object
end

if languageControl then
	languageControl:SetCallback(function()
		for _, record in ipairs(localizedObjects) do applyLocalization(record) end
	end, true)
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
	"tornado",
	"sun_strike",
	"cataclysm",
}

local itemIds = {
	"item_refresher",
}

local definitions = {
	tornado = {
		name = "Tornado", short = "Tornado", runtimeNames = {"invoker_tornado"},
		kind = "spell", recipe = {"quas", "wex", "wex"}, targeting = "point",
		projectileSpeed = 1000, fixedDelay = 0, reliability = 0.76,
	},
	sun_strike = {
		name = "Sun Strike", short = "Sun", runtimeNames = {"invoker_sun_strike"},
		kind = "spell", recipe = {"exort", "exort", "exort"}, targeting = "point",
		projectileSpeed = 0, fixedDelay = 1.7, reliability = 0.62,
	},
	cataclysm = {
		name = "Cataclysm", short = "Cata", runtimeNames = {"invoker_sun_strike"},
		kind = "spell", recipe = {"exort", "exort", "exort"}, targeting = "none",
		projectileSpeed = 0, fixedDelay = 1.7, reliability = 0.48, requiresScepter = "exort",
	},
	item_refresher = {
		name = "Refresher Orb", short = "Refresh", runtimeNames = {"item_refresher"},
		kind = "item", targeting = "none", reliability = 1,
	},
}

for _, id in ipairs(spellIds) do
	definitions[id].id = id
	definitions[id].projectileSpeed = definitions[id].projectileSpeed or 0
	definitions[id].fixedDelay = definitions[id].fixedDelay or 0
	definitions[id].icon = id == "cataclysm"
		and "panorama/images/spellicons/invoker/magus_apex/invoker_sun_strike_png.vtex_c"
		or ("panorama/images/spellicons/invoker_%s_png.vtex_c"):format(id)
end

local allActionIds
local ui
local renderCtx
local state

--[[
SUN STRIKE TOP v6 EXECUTION PRIORITY
------------------------------------
Read-only / telemetry scripts are intentionally NOT touched. This priority layer only arbitrates
orders sent to the local Invoker, so data providers may continue to update before/after this script.

IMPORTANT IMPLEMENTATION NOTE:
The donor is already very close to Lua's per-chunk local-variable limit. Keep the whole priority
subsystem behind ONE top-level local table. Adding many top-level `local function ...` declarations
can make the script fail to compile before Menu.Create runs, which makes it disappear from the list.

Execution tiers used by our scripts:
  1000 : read/state providers (no orders; never blocked here)
   900 : this Sun Strike module
  <900 : combo / last-hit / orbwalk / farm / other automation

Own orders use identifier "invoker_ss_top_v18" and always bypass the guard.
Lower-priority Lua automation is blocked at the wrapped command source.  Engine-observed player orders
are never rejected by OnPrepareUnitOrders; real player input owns the final override.
]]
helpers.sunPriority = {
	busKey = "__UCZ_ACTION_PRIORITY_V5",
	guardKey = "__UCZ_ORDER_GUARD_V5",
	owner = "invoker_ss_top_v18",
	identifier = "invoker_ss_top_v18",
	level = 900,
	leaseSeconds = 0.45,
	maxCastAttempts = 4,
	kinds = {
		quick_sun = true,
		sun_strike = true,
		landing_sun = true,
		landing_cataclysm = true,
		roshan_sun = true,
		tormentor_sun = true,
		cataclysm = true,
		cataclysm_refresher = true,
		cataclysm_repeat = true,
	},
}

function helpers.sunPriority.now()
	local ok, value = pcall(GameRules.GetGameTime)
	if ok and type(value) == "number" then return value end
	return state and state.now or 0
end

-- The standalone Invoker SS module must never fight the main Invoker combo/precast script.
-- Resolve the main script's binds directly from its menu and use :IsDown(), which is the
-- reliable UCZone bind-state API. Multiple paths are kept because the donor/current UI
-- has existed with both Invoker/Invoker (Beta) titles and RU/EN labels.
helpers.mainInvokerCombo = {nextResolveAt = 0, targetBind = nil, cursorBind = nil, precastBind = nil, logged = false}

function helpers.mainInvokerCombo.findBind(path)
	local ok, value = pcall(Menu.Find, table.unpack(path))
	if ok and value and type(value.IsDown) == "function" then return true, value end
	-- Some localized menus expose the translated hero-list root as well as leaf labels.
	local translated = {}
	for i, part in ipairs(path) do translated[i] = part end
	translated[1], translated[2] = "Герои", "Список героев"
	ok, value = pcall(Menu.Find, table.unpack(translated))
	return ok, value
end

function helpers.mainInvokerCombo.resolve()
	local link = helpers.mainInvokerCombo
	local now = helpers.sunPriority.now()
	if link.targetBind and link.cursorBind and link.precastBind and now < (link.nextResolveAt or 0) then return end
	if now < (link.nextResolveAt or 0) then return end
	link.nextResolveAt = now + 2.0
	local paths = {
		{"Heroes", "Hero List", "Invoker", "Main Settings", "Hero Settings", "Combo Key"},
		{"Heroes", "Hero List", "Invoker (Beta)", "Main Settings", "Hero Settings", "Combo Key"},
		{"Heroes", "Hero List", "Invoker", "Основные настройки", "Настройки героя", "Клавиша комбо"},
		{"Heroes", "Hero List", "Invoker", "Основные настройки", "Прокаст", "Комбо по цели"},
		{"Heroes", "Hero List", "Invoker", "Main", "Hero Settings", "Combo Key"},
		{"Heroes", "Hero List", "Invoker", "Main", "Combo", "Target Combo"},
		{"Heroes", "Hero List", "Invoker (Beta)", "Основные настройки", "Настройки героя", "Клавиша комбо"},
		{"Heroes", "Hero List", "Invoker (Beta)", "Основные настройки", "Прокаст", "Комбо по цели"},
		{"Heroes", "Hero List", "Invoker (Beta)", "Main", "Hero Settings", "Combo Key"},
		{"Heroes", "Hero List", "Invoker (Beta)", "Main", "Combo", "Target Combo"},
	}
	for _, path in ipairs(paths) do
		local ok, value = helpers.mainInvokerCombo.findBind(path)
		if ok and value and type(value.IsDown) == "function" then
			link.targetBind = value
			break
		end
	end
	local cursorPaths = {
		{"Heroes", "Hero List", "Invoker", "Main Settings", "Hero Settings", "Combo Key [Ground]"},
		{"Heroes", "Hero List", "Invoker (Beta)", "Main Settings", "Hero Settings", "Combo Key [Ground]"},
		{"Heroes", "Hero List", "Invoker", "Основные настройки", "Настройки героя", "Комбо по курсору"},
		{"Heroes", "Hero List", "Invoker", "Основные настройки", "Настройки героя", "Комбо по позиции"},
		{"Heroes", "Hero List", "Invoker", "Основные настройки", "Прокаст", "Комбо по позиции"},
		{"Heroes", "Hero List", "Invoker", "Main", "Hero Settings", "Cursor Combo"},
		{"Heroes", "Hero List", "Invoker", "Main", "Combo", "Cursor Combo"},
		{"Heroes", "Hero List", "Invoker (Beta)", "Основные настройки", "Настройки героя", "Комбо по курсору"},
		{"Heroes", "Hero List", "Invoker (Beta)", "Основные настройки", "Настройки героя", "Комбо по позиции"},
		{"Heroes", "Hero List", "Invoker (Beta)", "Основные настройки", "Прокаст", "Комбо по позиции"},
		{"Heroes", "Hero List", "Invoker (Beta)", "Main", "Hero Settings", "Cursor Combo"},
		{"Heroes", "Hero List", "Invoker (Beta)", "Main", "Combo", "Cursor Combo"},
	}
	for _, path in ipairs(cursorPaths) do
		local ok, value = helpers.mainInvokerCombo.findBind(path)
		if ok and value and type(value.IsDown) == "function" then
			link.cursorBind = value
			break
		end
	end
	local precastPaths = {
		{"Heroes", "Hero List", "Invoker", "Main Settings", "Hero Settings", "Precast Key"},
		{"Heroes", "Hero List", "Invoker (Beta)", "Main Settings", "Hero Settings", "Precast Key"},
		{"Heroes", "Hero List", "Invoker", "Основные настройки", "Настройки героя", "Клавиша предварительного каста"},
		{"Heroes", "Hero List", "Invoker", "Основные настройки", "Настройки героя", "Клавиша предварительного прокаста"},
		{"Heroes", "Hero List", "Invoker", "Main", "Hero Settings", "Precast Key"},
		{"Heroes", "Hero List", "Invoker", "Main", "Hero Settings", "Pre-Cast Key"},
		{"Heroes", "Hero List", "Invoker", "Main", "Hero Settings", "Preparation Key"},
		{"Heroes", "Hero List", "Invoker (Beta)", "Основные настройки", "Настройки героя", "Клавиша предварительного каста"},
		{"Heroes", "Hero List", "Invoker (Beta)", "Основные настройки", "Настройки героя", "Клавиша предварительного прокаста"},
		{"Heroes", "Hero List", "Invoker (Beta)", "Main", "Hero Settings", "Precast Key"},
		{"Heroes", "Hero List", "Invoker (Beta)", "Main", "Hero Settings", "Pre-Cast Key"},
		{"Heroes", "Hero List", "Invoker (Beta)", "Main", "Hero Settings", "Preparation Key"},
	}
	for _, path in ipairs(precastPaths) do
		local ok, value = helpers.mainInvokerCombo.findBind(path)
		if ok and value and type(value.IsDown) == "function" then
			link.precastBind = value
			break
		end
	end
end

function helpers.mainInvokerCombo.active()
	helpers.mainInvokerCombo.resolve()
	local link = helpers.mainInvokerCombo
	local down = false
	if link.targetBind then
		local ok, value = pcall(function() return link.targetBind:IsDown() end)
		down = ok and value == true
	end
	if not down and link.cursorBind then
		local ok, value = pcall(function() return link.cursorBind:IsDown() end)
		down = ok and value == true
	end
	if not down and link.precastBind then
		local ok, value = pcall(function() return link.precastBind:IsDown() end)
		down = ok and value == true
	end
	-- Current main Invoker setup shown by the user uses Mouse4. This fallback only applies
	-- when the menu bind could not be resolved, so remapped binds still win when available.
	if not down and not link.targetBind and not link.cursorBind and not link.precastBind and Enum.ButtonCode.KEY_MOUSE4 then
		local ok, value = pcall(Input.IsKeyDown, Enum.ButtonCode.KEY_MOUSE4, false)
		down = ok and value == true
	end
	-- Order callbacks also observe the binds. Refresh the deadline here, not only
	-- in coreRun: a press/release between core ticks must still leave the safety delay.
	if down then
		state.autoSunSafetyUntil = math.max(state.autoSunSafetyUntil or 0,
			helpers.sunPriority.now() + (cfg.autoSunResumeDelay or 3.0))
		state.autoSunSafetyReason = "main_bind"
	end
	return down
end

function helpers.sunPriority.bus()
	-- Umbrella's Lua sandbox does not expose rawget/rawset. Keep the lease on the
	-- existing helper table instead of touching the global environment.
	local bus = helpers.sunPriority._bus
	if type(bus) ~= "table" then
		bus = {owner = nil, level = -1, expiresAt = 0, blocked = 0}
		helpers.sunPriority._bus = bus
	end
	return bus
end

function helpers.sunPriority.heroIndex()
	local hero = state and state.hero or nil
	if not hero then
		local ok, value = pcall(Heroes.GetLocal)
		if ok then hero = value end
	end
	if not hero then return -1 end
	local ok, index = pcall(Entity.GetIndex, hero)
	return ok and index or -1
end

function helpers.sunPriority.claim(reason, untilAt)
	local now = helpers.sunPriority.now()
	local bus = helpers.sunPriority.bus()
	if bus.owner ~= helpers.sunPriority.owner then
		bus.blocked = 0
		bus.claimedAt = now
	end
	bus.owner = helpers.sunPriority.owner
	bus.level = helpers.sunPriority.level
	bus.identifier = helpers.sunPriority.identifier
	bus.heroIndex = helpers.sunPriority.heroIndex()
	bus.reason = reason or "sun"
	bus.expiresAt = math.max(bus.expiresAt or 0, untilAt or (now + helpers.sunPriority.leaseSeconds))
	if state then state.sunPriorityActive = true end
	return true
end

function helpers.sunPriority.release(reason)
	local bus = helpers.sunPriority.bus()
	if bus.owner == helpers.sunPriority.owner then
		bus.lastOwner = bus.owner
		bus.lastReason = reason or bus.reason
		bus.lastBlocked = bus.blocked or 0
		bus.owner = nil
		bus.level = -1
		bus.identifier = nil
		bus.heroIndex = nil
		bus.reason = nil
		bus.expiresAt = 0
	end
	if state then state.sunPriorityActive = false end
end

function helpers.sunPriority.active()
	local bus = helpers.sunPriority.bus()
	return bus.owner == helpers.sunPriority.owner and (bus.expiresAt or 0) + 0.001 >= helpers.sunPriority.now()
end

function helpers.sunPriority.pending(pending)
	return pending ~= nil and (helpers.sunPriority.kinds[pending.kind] == true
		or pending.actionId == "sun_strike" or pending.actionId == "cataclysm")
end

function helpers.sunPriority.needed()
	if not state then return false end
	if helpers.sunPriority.pending(state.autoPending) then return true end
	if state.invokeSequence and state.invokeSequence.actionId == "sun_strike" then return true end
	return false
end

function helpers.sunPriority.renew(reason)
	if not helpers.sunPriority.needed() then
		helpers.sunPriority.release(reason or "idle")
		return false
	end
	local now = helpers.sunPriority.now()
	local untilAt = now + helpers.sunPriority.leaseSeconds
	local pending = state and state.autoPending or nil
	if pending and pending.cast and pending.cast.deadline then
		untilAt = math.max(untilAt, math.min(pending.cast.deadline + 0.05, now + 0.9))
	end
	helpers.sunPriority.claim(reason or pending and pending.kind or "sun", untilAt)
	return true
end

function helpers.sunPriority.sameHero(value, hero)
	if not value or not hero then return false end
	if type(value) == "table" then
		for _, unit in pairs(value) do
			if helpers.sunPriority.sameHero(unit, hero) then return true end
		end
		return false
	end
	local okA, a = pcall(Entity.GetIndex, value)
	local okB, b = pcall(Entity.GetIndex, hero)
	return okA and okB and a == b
end

function helpers.sunPriority.abilityOwnedByHero(ability, hero)
	if not ability or not hero then return false end
	local ok, owned = pcall(Entity.RecursiveOwnedBy, ability, hero)
	return ok and owned == true
end

function helpers.sunPriority.guardContext(identifier)
	if helpers.mainInvokerCombo and helpers.mainInvokerCombo.active() then
		helpers.sunPriority.release("main Invoker combo/precast bind active")
		return nil
	end
	local bus = helpers.sunPriority._bus
	if type(bus) ~= "table" or bus.owner ~= helpers.sunPriority.owner then return nil end
	local now = helpers.sunPriority.now()
	if (bus.expiresAt or 0) + 0.001 < now then return nil end
	if identifier ~= nil and identifier == bus.identifier then return nil end
	local hero
	if type(bus.heroIndex) == "number" and bus.heroIndex >= 0 then
		local ok, value = pcall(Entity.Get, bus.heroIndex)
		if ok then hero = value end
	end
	if not hero then
		local ok, value = pcall(Heroes.GetLocal)
		if ok then hero = value end
	end
	if not hero then return nil end
	return bus, hero
end

function helpers.sunPriority.countBlock(bus, kind)
	bus.blocked = (bus.blocked or 0) + 1
	bus.lastBlockedAt = helpers.sunPriority.now()
	bus.lastBlockedKind = kind
end

function helpers.sunPriority.installGuards()
	-- Same sandbox rule as the priority bus: no rawget/rawset. The registry only
	-- needs to live for this loaded script instance.
	local registry = helpers.sunPriority._guardRegistry
	if type(registry) ~= "table" then
		registry = {installed = false, originals = {}, status = {}}
		helpers.sunPriority._guardRegistry = registry
	end
	if registry.installed then return registry end

	local function wrap(namespace, name, classifier)
		if type(namespace) ~= "table" or type(namespace[name]) ~= "function" then
			registry.status[name] = "missing"
			return
		end
		local key = tostring(namespace) .. ":" .. name
		if registry.originals[key] then return end
		local original = namespace[name]
		registry.originals[key] = original
		local wrapper = function(...)
			-- Own Sun orders are synchronous inside issueOrder(). Bypass the global guard first so
			-- a missing/stripped identifier in a callback can never make Sun Strike block itself.
			if state and state.issuingOrder then return original(...) end
			local args = table.pack(...)
			local identifier, affectsHero = classifier(args)
			local bus, hero
			if affectsHero ~= false then bus, hero = helpers.sunPriority.guardContext(identifier) end
			if bus and hero and affectsHero(hero) then
				helpers.sunPriority.countBlock(bus, name)
				return nil
			end
			return original(table.unpack(args, 1, args.n))
		end
		local ok = pcall(function() namespace[name] = wrapper end)
		registry.status[name] = ok and "wrapped" or "readonly"
	end

	wrap(Player, "PrepareUnitOrders", function(args)
		local identifier = args[12]
		local issuerNpc, ability = args[7], args[5]
		return identifier, function(hero)
			return helpers.sunPriority.sameHero(issuerNpc, hero) or helpers.sunPriority.abilityOwnedByHero(ability, hero)
		end
	end)

	wrap(Player, "AttackTarget", function(args)
		local identifier, issuerNpc = args[7], args[2]
		return identifier, function(hero) return helpers.sunPriority.sameHero(issuerNpc, hero) end
	end)

	wrap(Player, "HoldPosition", function(args)
		local identifier, issuerNpc = args[6], args[2]
		return identifier, function(hero) return helpers.sunPriority.sameHero(issuerNpc, hero) end
	end)

	wrap(Ability, "CastNoTarget", function(args)
		local identifier, ability = args[5], args[1]
		return identifier, function(hero) return helpers.sunPriority.abilityOwnedByHero(ability, hero) end
	end)
	wrap(Ability, "CastTarget", function(args)
		local identifier, ability = args[6], args[1]
		return identifier, function(hero) return helpers.sunPriority.abilityOwnedByHero(ability, hero) end
	end)
	wrap(Ability, "CastPosition", function(args)
		local identifier, ability = args[6], args[1]
		return identifier, function(hero) return helpers.sunPriority.abilityOwnedByHero(ability, hero) end
	end)

	local function npcOrderClassifier(args)
		local identifier = nil
		for index = args.n, 2, -1 do
			if args[index] == helpers.sunPriority.identifier then identifier = args[index]; break end
		end
		local issuerNpc = args[1]
		return identifier, function(hero) return helpers.sunPriority.sameHero(issuerNpc, hero) end
	end
	for _, name in ipairs({"MoveTo", "AttackTarget", "AttackMove", "Stop", "HoldPosition"}) do
		wrap(NPC, name, npcOrderClassifier)
	end

	registry.installed = true
	return registry
end

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

-- Read the engine's real velocity vector when this UCZone build exposes it.
-- Position-history tracking stays as the fallback and as the long-window route validator.
function helpers.readEntityVelocity(unit)
	local ok, value = pcall(Entity.GetField, unit, "m_vecVelocity")
	if not ok or not value or type(value.x) ~= "number" or type(value.y) ~= "number" then return nil end
	local speed = math.sqrt(value.x * value.x + value.y * value.y)
	if speed ~= speed or speed > 1800 then return nil end
	return {x = value.x, y = value.y, z = type(value.z) == "number" and value.z or 0}
end

function helpers.signedAngle2D(from, to)
	local a, b = normalized2D(from), normalized2D(to)
	if length2D(a) <= 0.0001 or length2D(b) <= 0.0001 then return 0 end
	local dot = clamp(dot2D(a, b), -1, 1)
	local cross = a.x * b.y - a.y * b.x
	local angle = math.acos(dot)
	return cross < 0 and -angle or angle
end

function helpers.rotate2D(value, angle)
	local c, s = math.cos(angle), math.sin(angle)
	return {x = value.x * c - value.y * s, y = value.x * s + value.y * c, z = value.z or 0}
end

function helpers.projectSunScenario(target, horizon, direction, speed, acceleration, turnRate)
	local position = copyPoint(target.position)
	local dir = normalized2D(direction)
	local currentSpeed = math.max(0, speed or 0)
	local duration = math.max(0, horizon or 0)
	local steps = duration > 0.9 and 7 or 4
	local dt = duration / math.max(1, steps)
	local maxSpeed = math.max(40, (target.moveSpeed or currentSpeed) * 1.08)
	for _ = 1, steps do
		dir = helpers.rotate2D(dir, (turnRate or 0) * dt)
		currentSpeed = clamp(currentSpeed + (acceleration or 0) * dt, 0, maxSpeed)
		position = add(position, scale(dir, currentSpeed * dt))
	end
	return position
end

function helpers.scoreSunAim(candidate, cloud, radius)
	local sigma = math.max(70, radius * 0.68)
	local inverseVariance = 0.5 / (sigma * sigma)
	local radiusSquared = radius * radius
	local inverseRadius = 1 / math.max(1, radius)
	local score, covered, margin = 0, 0, 0
	for _, scenario in ipairs(cloud) do
		local dx = candidate.x - scenario.position.x
		local dy = candidate.y - scenario.position.y
		local squared = dx * dx + dy * dy
		local weight = scenario.weight or 0
		score = score + weight * math.exp(-squared * inverseVariance)
		if squared <= radiusSquared then
			covered = covered + weight
			margin = margin + weight * (1 - math.sqrt(squared) * inverseRadius)
		end
	end
	return score + covered * 0.45 + margin * 0.20, covered
end

local function toVector(value)
	return Vector(value.x, value.y, value.z or 0)
end


-- v62 topology-first Sun helpers. GridNav topology is generated before motion evidence weights the branches.
function helpers.sunTerrainTravelDistance(horizon, speed, acceleration, maxSpeed)
	local duration = math.max(0, horizon or 0)
	local steps = duration > 0.9 and 8 or 4
	local dt = duration / math.max(1, steps)
	local currentSpeed = math.max(0, speed or 0)
	local cap = math.max(40, maxSpeed or currentSpeed)
	local distance = 0
	for _ = 1, steps do
		currentSpeed = clamp(currentSpeed + (acceleration or 0) * dt, 0, cap)
		distance = distance + currentSpeed * dt
	end
	return math.max(0, distance), currentSpeed
end

-- Shared by observational UI and combat forecasts. No rounding: nearby but distinct
-- paths must never alias. Entries expire every game tick; combat aim/HP checks still run.
function helpers.sunTerrainQueryKey(kind, a, b, distance)
	return table.concat({kind, string.format("%.17g", a.x), string.format("%.17g", a.y),
		string.format("%.17g", a.z or 0), string.format("%.17g", b.x),
		string.format("%.17g", b.y), string.format("%.17g", b.z or 0),
		string.format("%.17g", distance or 0)}, ":")
end

function helpers.sunTerrainQueries()
	local now = GameRules.GetGameTime()
	local cache = state.sunTerrainQueries
	if not cache or cache.at ~= now then
		cache = {at = now, entries = {}, count = 0}
		state.sunTerrainQueries = cache
	end
	return cache
end

function helpers.sunTerrainBuildPath(startPosition, endpoint)
	local cache = helpers.sunTerrainQueries()
	local key = helpers.sunTerrainQueryKey("path", startPosition, endpoint)
	local entry = cache.entries[key]
	if entry then return true, entry.path end
	local ok, path = pcall(GridNav.BuildPath, toVector(startPosition), toVector(endpoint), false, nil)
	-- Paths are read-only to all callers. Failed API calls are not retained.
	if ok and type(path) == "table" and #path > 0 and cache.count < 256 then
		cache.entries[key] = {path = path}
		cache.count = cache.count + 1
	end
	return ok, path
end

function helpers.sunTerrainRayOpen(startPosition, direction, distance)
	local cache = helpers.sunTerrainQueries()
	local key = helpers.sunTerrainQueryKey("ray", startPosition, direction, distance)
	local entry = cache.entries[key]
	if entry then return entry.open, entry.reason end
	local open, reason = helpers.sunTerrainRayOpenUncached(startPosition, direction, distance)
	if reason ~= "api" and cache.count < 256 then
		cache.entries[key] = {open = open, reason = reason}
		cache.count = cache.count + 1
	end
	return open, reason
end

function helpers.sunTerrainRayOpenUncached(startPosition, direction, distance)
	if not GridNav or not GridNav.IsTraversable then return false, "api" end
	local dir = normalized2D(direction)
	if length2D(dir) < 0.5 then return false, "direction" end
	local total = math.max(0, distance or 0)
	local step = 56
	local probe = step
	while probe < total - 1 do
		local point = add(startPosition, scale(dir, probe))
		local ok, traversable = pcall(GridNav.IsTraversable, toVector(point))
		if not ok then return false, "api" end
		if not traversable then return false, "blocked" end
		probe = probe + step
	end
	if total > 1 then
		local point = add(startPosition, scale(dir, total))
		local ok, traversable = pcall(GridNav.IsTraversable, toVector(point))
		if not ok then return false, "api" end
		if not traversable then return false, "blocked" end
		if GridNav.IsTraversableFromTo then
			local linkedOk, linked = pcall(GridNav.IsTraversableFromTo, toVector(startPosition), toVector(point))
			if not linkedOk then return false, "api" end
			if not linked then return false, "blocked_link" end
		end
	end
	return true, "open"
end

function helpers.sunTerrainPointAlongPath(startPosition, path, distance, fallbackDirection)
	local remaining = math.max(0, distance or 0)
	local previous = copyPoint(startPosition)
	local tangent = normalized2D(fallbackDirection)
	local traversed = 0
	if type(path) ~= "table" then return previous, tangent, traversed, false end
	for i = 1, #path do
		local node = path[i]
		if node then
			local point = {x = node.x, y = node.y, z = node.z or previous.z or 0}
			local segment = subtract(point, previous)
			local segmentDistance = length2D(segment)
			if segmentDistance > 0.5 then
				local segmentDirection = normalized2D(segment)
				if traversed + segmentDistance >= remaining then
					local along = clamp((remaining - traversed) / segmentDistance, 0, 1)
					return add(previous, scale(segment, along)), segmentDirection, remaining, true
				end
				traversed = traversed + segmentDistance
				previous = point
				tangent = segmentDirection
			end
		end
	end
	return previous, tangent, traversed, traversed + 1 >= remaining
end

function helpers.sunTerrainProject(target, direction, travelDistance, lookahead)
	local startPosition = copyPoint(target.position)
	local dir = normalized2D(direction)
	local distance = math.max(0, travelDistance or 0)
	if distance <= 1 or length2D(dir) < 0.5 then
		return {position = startPosition, tangent = dir, mode = "stationary", forcedTurn = false, stretch = 1, complete = true}
	end
	local rayOpen, rayReason = helpers.sunTerrainRayOpen(startPosition, dir, distance)
	if rayOpen then
		return {
			position = add(startPosition, scale(dir, distance)), tangent = dir, mode = "open",
			forcedTurn = false, stretch = 1, complete = true, rayReason = rayReason,
		}
	end
	if not GridNav or not GridNav.BuildPath then
		return {
			position = add(startPosition, scale(dir, distance)), tangent = dir, mode = "fallback",
			forcedTurn = false, stretch = 1, complete = true, rayReason = rayReason, apiMissing = true,
		}
	end
	local intentDistance = clamp(math.max(cfg.sunTerrainMinIntentDistance, distance + (lookahead or cfg.sunTerrainLookahead)),
		cfg.sunTerrainMinIntentDistance, cfg.sunTerrainMaxIntentDistance)
	local endpoint = add(startPosition, scale(dir, intentDistance))
	local ok, path = helpers.sunTerrainBuildPath(startPosition, endpoint)
	if not ok or type(path) ~= "table" or #path == 0 then
		return {
			position = add(startPosition, scale(dir, distance)), tangent = dir, mode = "fallback",
			forcedTurn = false, stretch = 1, complete = true, rayReason = rayReason, pathFailed = true,
		}
	end
	local position, tangent, traversed, complete = helpers.sunTerrainPointAlongPath(startPosition, path, distance, dir)
	if not complete then
		return {
			position = position, tangent = tangent, mode = "path_short", forcedTurn = true,
			stretch = distance / math.max(1, distance2D(startPosition, position)), complete = false,
			pathPoints = #path, rayReason = rayReason,
		}
	end
	local direct = math.max(1, distance2D(startPosition, position))
	return {
		position = position, tangent = tangent, mode = "path", forcedTurn = true,
		stretch = distance / direct, complete = true, pathPoints = #path, rayReason = rayReason,
	}
end

function helpers.sunTerrainTopologyBranches(target, baseDirection, referenceDistance, lookahead)
	local startPosition = copyPoint(target.position)
	local base = normalized2D(baseDirection)
	if length2D(base) < 0.5 then return nil, {reason = "direction", failed = 7, total = 7} end
	if not GridNav or not GridNav.IsTraversable then return nil, {reason = "api", failed = 7, total = 7} end
	local distance = math.max(1, referenceDistance or 1)
	local intentDistance = clamp(math.max(cfg.sunTerrainMinIntentDistance, distance + (lookahead or cfg.sunTerrainLookahead)),
		cfg.sunTerrainMinIntentDistance, cfg.sunTerrainMaxIntentDistance)
	local decisionDistance = math.min(intentDistance, distance + (cfg.sunTerrainDecisionReserve or 220))

	-- v97 root fix: topology may bend the current aim only when the CURRENT measured route is
	-- actually constrained inside this Sun's reachable decision horizon.  The old topology fan
	-- created seven angled "routes" even on fully open ground; terrain-hedge could then compromise
	-- between those artificial branches and pull a straight runner sideways with blocked=0/forced=false.
	-- If the measured/base route is open, the map contributes no turn information: keep exactly one
	-- straight branch.  We still inspect the long ray only for farBlocked diagnostics.
	local baseDecisionOpen, baseDecisionReason = helpers.sunTerrainRayOpen(startPosition, base, decisionDistance)
	if baseDecisionOpen then
		local longOpen, longReason = baseDecisionOpen, baseDecisionReason
		local farBlocked = 0
		-- Only reachable terrain can change this cast. Skip distant diagnostic rays;
		-- they added GridNav calls without contributing to the impact prediction.
		local directPoint = add(startPosition, scale(base, decisionDistance))
		return {{
			index = 1, angle = 0, path = {directPoint}, position = add(startPosition, scale(base, distance)),
			tangent = base, entryTangent = base, probeDirection = base,
			mode = longOpen and "open" or "open_horizon", forcedTurn = false, stretch = 1, complete = true,
			pathPoints = 1, rayReason = baseDecisionReason, traversed = distance,
			decisionDistance = decisionDistance, lookaheadBlocked = not longOpen, lookaheadReason = longReason,
		}}, {reason = "open_base", failed = 0, blocked = 0, farBlocked = farBlocked, total = 1, openBase = true}
	end

	-- The base route is genuinely obstructed inside the reachable horizon.  Only now does the map
	-- own a route family and may GridNav probe plausible detours around the obstruction.
	local probeAngles = {0, -0.16, 0.16, -0.36, 0.36, -0.70, 0.70}
	local branches, failed, blocked, farBlocked = {}, 0, 0, 0
	for probeIndex, angle in ipairs(probeAngles) do
		local probeDirection = helpers.rotate2D(base, angle)
		local endpoint = add(startPosition, scale(probeDirection, intentDistance))
		-- v95 root fix: the old code marked a branch as forced-turn when ANY obstacle existed
		-- anywhere in the long 900+u lookahead ray. GridNav could then start routing around a
		-- tree that the hero cannot even reach before this Sun lands, pulling the aim sideways.
		-- Keep the long endpoint for path construction, but decide whether THIS cast must turn
		-- only from the physically reachable distance plus the bounded command-timing reserve.
		local decisionOpen, decisionReason = helpers.sunTerrainRayOpen(startPosition, probeDirection, decisionDistance)
		local lookaheadOpen, lookaheadReason = decisionOpen, decisionReason
		-- Detours still use the full endpoint when the reachable route is blocked.
		-- Open routes need no second, longer diagnostic ray.
		local path, mode = nil, nil
		if decisionOpen then
			-- An obstacle beyond the current Sun reach is future information, not a reason to bend
			-- the present cast. A direct segment long enough for reachHorizon keeps frontPoint valid.
			path = {add(startPosition, scale(probeDirection, decisionDistance))}
			mode = lookaheadOpen and "open" or "open_horizon"
		else
			blocked = blocked + 1
			if GridNav and GridNav.BuildPath then
				local ok, built = helpers.sunTerrainBuildPath(startPosition, endpoint)
				if ok and type(built) == "table" and #built > 0 then
					path = built
					mode = "path"
				end
			end
		end
		if path then
			local position, tangent, traversed, complete = helpers.sunTerrainPointAlongPath(startPosition, path, distance, probeDirection)
			local entryDistance = clamp(math.min(distance * 0.34 + 52, 190), 72, 190)
			local _, entryTangent = helpers.sunTerrainPointAlongPath(startPosition, path, entryDistance, probeDirection)
			local direct = math.max(1, distance2D(startPosition, position))
			branches[#branches + 1] = {
				index = probeIndex, angle = angle, path = path, position = position, tangent = tangent,
				entryTangent = entryTangent, probeDirection = probeDirection, mode = mode,
				forcedTurn = not decisionOpen, stretch = distance / direct, complete = complete,
				pathPoints = #path, rayReason = decisionReason, traversed = traversed,
				decisionDistance = decisionDistance, lookaheadBlocked = not lookaheadOpen, lookaheadReason = lookaheadReason,
			}
		else
			failed = failed + 1
		end
	end
	return branches, {reason = #branches > 0 and "ok" or "no_paths", failed = failed, blocked = blocked,
		farBlocked = farBlocked, total = #probeAngles}
end

function helpers.sunTerrainTopologyWeight(branch, signals)
	local function alignment(a, b)
		if not a or not b or length2D(a) < 0.5 or length2D(b) < 0.5 then return 0.5 end
		return clamp((dot2D(normalized2D(a), normalized2D(b)) + 1) * 0.5, 0, 1)
	end
	local entry = branch.entryTangent or branch.probeDirection
	local exit = branch.tangent or entry
	local base = alignment(entry, signals.baseDirection)
	local recent = alignment(entry, signals.recentDirection)
	local instant = alignment(entry, signals.instantDirection)
	local long = alignment(entry, signals.longDirection)
	local facing = alignment(entry, signals.facing)
	local expected = alignment(exit, signals.expectedDirection)
	local motionScore = base ^ 3 * 0.40 + recent ^ 2 * 0.18 + instant ^ 2 * 0.10
		+ long ^ 2 * 0.10 + facing ^ 2 * 0.08 + expected ^ 2 * 0.14
	local anglePrior = 0.34 + 0.66 * clamp(1 - math.abs(branch.angle or 0) / 0.82, 0, 1) ^ 2
	local stretchPenalty = clamp(1 / math.max(1, branch.stretch or 1), 0.66, 1)
	if branch.forcedTurn then
		-- A map-forced turn must not be punished simply because the route tangent differs from the old ray.
		motionScore = math.max(motionScore, base * 0.72 + recent * 0.18 + expected * 0.10)
	end
	if branch.complete == false then stretchPenalty = stretchPenalty * 0.62 end
	return math.max(0.004, motionScore * motionScore * anglePrior * stretchPenalty)
end

function helpers.sunTerrainRouteEntropy(clusters)
	if not clusters or #clusters <= 1 then return 0 end
	local entropy, total = 0, 0
	for _, cluster in ipairs(clusters) do total = total + math.max(0, cluster.weight or 0) end
	if total <= 0 then return 1 end
	for _, cluster in ipairs(clusters) do
		local probability = math.max(0, cluster.weight or 0) / total
		if probability > 0.000001 then entropy = entropy - probability * math.log(probability) end
	end
	return clamp(entropy / math.max(0.000001, math.log(#clusters)), 0, 1)
end

function helpers.sunTerrainTemporalStability(previousMeta, dominantPosition, dominantWeight, routeCount, entropy, age, aoe)
	if not previousMeta or not previousMeta.dominantPosition or (age or math.huge) > cfg.sunTerrainTemporalAge then
		return 0.58
	end
	local drift = distance2D(previousMeta.dominantPosition, dominantPosition or previousMeta.dominantPosition)
	local driftScore = clamp(1 - drift / math.max(120, (aoe or cfg.sunRadius) * 1.65), 0, 1)
	local weightScore = clamp(1 - math.abs((previousMeta.dominantWeight or 0) - (dominantWeight or 0)) / 0.55, 0, 1)
	local countScore = clamp(1 - math.abs((previousMeta.routeCount or 0) - (routeCount or 0)) * 0.18, 0, 1)
	local entropyScore = clamp(1 - math.abs((previousMeta.routeEntropy or entropy or 0) - (entropy or 0)) / 0.70, 0, 1)
	return clamp(driftScore * 0.44 + weightScore * 0.24 + countScore * 0.16 + entropyScore * 0.16, 0, 1)
end

function helpers.sunTerrainClusters(cloud, radius)
	local clusters = {}
	local threshold = math.max(70, radius or cfg.sunTerrainClusterRadius)
	for _, scenario in ipairs(cloud or {}) do
		local best, bestDistance = nil, math.huge
		for _, cluster in ipairs(clusters) do
			local currentDistance = distance2D(scenario.position, cluster.position)
			if currentDistance < bestDistance then best, bestDistance = cluster, currentDistance end
		end
		if not best or bestDistance > threshold then
			best = {position = copyPoint(scenario.position), weight = 0, members = 0, names = {}}
			clusters[#clusters + 1] = best
		end
		local oldWeight = best.weight
		local newWeight = oldWeight + (scenario.weight or 0)
		if newWeight > 0 then
			best.position.x = (best.position.x * oldWeight + scenario.position.x * (scenario.weight or 0)) / newWeight
			best.position.y = (best.position.y * oldWeight + scenario.position.y * (scenario.weight or 0)) / newWeight
		end
		best.weight = newWeight
		best.members = best.members + 1
		best.names[#best.names + 1] = scenario.name
		scenario.cluster = best
	end
	table.sort(clusters, function(a, b) return (a.weight or 0) > (b.weight or 0) end)
	return clusters
end

function helpers.sunRecentZigzag(samples)
	local newest = samples[#samples]
	if not newest then return 0, 0 end
	local anchor, heading, sign = nil, nil, 0
	local changes, lastTurn, reversal = 0, -math.huge, false
	for _, sample in ipairs(samples) do
		if sample.at >= newest.at - 0.90 then
			if not anchor then anchor = sample.position else
				local delta = subtract(sample.position, anchor)
				if length2D(delta) >= 24 then
					local direction = normalized2D(delta)
					if heading then
						local dot = clamp(dot2D(heading, direction), -1, 1)
						if dot < math.cos(math.rad(20)) then
							local cross = heading.x * direction.y - heading.y * direction.x
							local nextSign = cross >= 0 and 1 or -1
							if sign ~= 0 and nextSign ~= sign then changes = changes + 1 end
							sign, lastTurn = nextSign, sample.at
							if dot < math.cos(math.rad(100)) then reversal = true end
							heading = direction
						end
					else heading = direction end
					anchor = sample.position
				end
			end
		end
	end
	local decay = clamp(1 - (newest.at - lastTurn) / 0.45, 0, 1)
	return (reversal and 1 or clamp(changes / 2, 0, 1)) * decay, changes
end

function helpers.sunTerrainHistoryScore(result, forcedTurn, antiZigzag)
	if antiZigzag == false then return 1 end
	local straight = clamp(result.straightness or 0, 0, 1)
	local offAxis = clamp(1 - (result.offAxisShare or 1), 0, 1)
	local corridor = math.max(1, result.corridor or 100)
	local lateral = clamp(1 - (result.lateral or corridor) / corridor, 0, 1)
	local recentAngle = clamp(1 - (result.recentLongAngle or 180) / 90, 0, 1)
	local instantAngle = clamp(1 - (result.instantRecentAngle or 180) / 110, 0, 1)
	if forcedTurn then
		recentAngle = math.max(recentAngle, 0.72)
		instantAngle = math.max(instantAngle, 0.72)
	end
	local score = straight * 0.34 + offAxis * 0.22 + lateral * 0.16 + recentAngle * 0.14 + instantAngle * 0.14
	-- A single terrain bend is not alternating evasion. Require a convergent route
	-- with strong AoE coverage before relaxing the old straightness penalty.
	if forcedTurn and (result.terrainCoverage or 0) >= 0.90 and (result.zigzagRisk or 0) < 0.25 then
		score = math.max(score, 0.72)
	end
	return clamp(score - (result.zigzagRisk or 0) * 0.35, 0, 1)
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


local function pushUnique(source, value)
	if not contains(source, value) then source[#source + 1] = value end
end

local function canonicalSpell(id)
	return id == "cataclysm" and "sun_strike" or id
end



local function upgradeChoice(id)
	if id == 1 then return "quas" end
	if id == 2 then return "wex" end
	if id == 3 then return "exort" end
	return nil
end

-- Lua file methods may return nil/error instead of throwing. Always check them,
-- and close the handle even if writing or flushing raises an exception.
function helpers.writeTraceFile(path, mode, payload)
	if type(io) ~= "table" or type(io.open) ~= "function" then error("io.open unavailable") end
	local file, openError = io.open(path, mode)
	if not file then error("open failed: " .. tostring(openError)) end
	local ok, err = pcall(function()
		if payload then
			local written, writeError = file:write(payload)
			if not written then error("write failed: " .. tostring(writeError)) end
		end
		local flushed, flushError = file:flush()
		if not flushed then error("flush failed: " .. tostring(flushError)) end
	end)
	local closeOk, closed, closeError = pcall(file.close, file)
	if not ok then error(err, 0) end
	if not closeOk then error(closed, 0) end
	if not closed then error("close failed: " .. tostring(closeError)) end
end

function helpers.beginTraceSession()
	if not state then return false end
	local now = (GameRules and GameRules.GetGameTime and GameRules.GetGameTime()) or 0
	local enabled = ui and ui.fileLog and ui.fileLog:Get() == true
	state.sessionTrace = {
		pending = {}, pendingChars = 0, totalLines = 0, totalChars = 0,
		dropped = 0, flushed = false, flushing = false, lastCheckpointAt = now,
		writeFailed = false, lastError = nil, enabled = enabled,
	}
	if not enabled then return true end
	local trace = state.sessionTrace
	local path = cfg.persistentTracePath or [[C:\Soft\Umbrella\scripts\invoker_ss_game_log.txt]]
	local ok, err = pcall(function()
		helpers.writeTraceFile(path, "a", ("\n=== INVOKER SESSION v137 START game_time=%.3f ===\n"):format(now))
	end)
	trace.writeFailed = ok ~= true
	trace.lastError = ok and nil or tostring(err)
	return ok == true
end

function helpers.restartFileLog(reason)
	local now = (GameRules and GameRules.GetGameTime and GameRules.GetGameTime()) or 0
	local enabled = ui and ui.fileLog and ui.fileLog:Get() == true
	local path = cfg.persistentTracePath or [[C:\Soft\Umbrella\scripts\invoker_ss_game_log.txt]]
	local ok, err = pcall(function()
		local payload = enabled and ("=== INVOKER LOG v137 RESET reason=%s game_time=%.3f ===\n"):format(tostring(reason or "manual"), now) or nil
		helpers.writeTraceFile(path, "w", payload)
	end)
	if state then
		state.sessionTrace = {
			pending = {}, pendingChars = 0, totalLines = 0, totalChars = 0,
			dropped = 0, flushed = false, flushing = false, lastCheckpointAt = now,
			writeFailed = enabled and ok ~= true or false, lastError = ok and nil or tostring(err), enabled = enabled,
		}
		state.runtimeVersionLogged = false
		if ok then
			state.statusPhase = "ready"
			state.status = enabled and "File log refreshed: scripts\\invoker_ss_game_log.txt" or "File log cleared; logging is disabled."
		else
			state.statusPhase = "aborted"
			state.status = "LOGGER ERROR: cannot write scripts\\invoker_ss_game_log.txt"
		end
	end
	return ok == true
end

function helpers.traceCheckpoint(reason, force)
	if not state or not state.sessionTrace then return false end
	local trace = state.sessionTrace
	if trace.enabled ~= true then return true end
	if not force and not (ui and ui.fileLog and ui.fileLog:Get()) then return true end
	if trace.flushing then return false end
	local now = (GameRules and GameRules.GetGameTime and GameRules.GetGameTime()) or 0
	if not force and trace.writeFailed and now < (trace.nextRetryAt or 0) then return false end
	local pendingChars = trace.pendingChars or 0
	local elapsed = now - (trace.lastCheckpointAt or now)
	if pendingChars <= 0 then
		trace.lastCheckpointAt = now
		-- Initial open/reset failure can leave no buffered lines. Probe the file
		-- on the retry schedule so a restored path can resume automation.
		if trace.writeFailed then
			local ok, err = pcall(helpers.writeTraceFile, cfg.persistentTracePath, "a", nil)
			trace.writeFailed = not ok
			trace.lastError = ok and nil or tostring(err)
			trace.nextRetryAt = not ok and now + (cfg.persistentTraceRetrySeconds or 2.0) or nil
		end
		return trace.writeFailed ~= true
	end
	if not force
		and pendingChars < (cfg.persistentTraceCheckpointChars or 4096)
		and elapsed < (cfg.persistentTraceCheckpointSeconds or 0.75)
	then
		return trace.writeFailed ~= true
	end
	local path = cfg.persistentTracePath or [[C:\Soft\Umbrella\scripts\invoker_ss_game_log.txt]]
	local payload = table.concat(trace.pending or {}, "\n") .. "\n"
	trace.flushing = true
	local ok, err = pcall(helpers.writeTraceFile, path, "a", payload)
	trace.flushing = false
	if ok then
		trace.pending = {}
		trace.pendingChars = 0
		trace.lastCheckpointAt = now
		trace.writeFailed = false
		trace.lastError = nil
		trace.nextRetryAt = nil
	else
		trace.writeFailed = true
		trace.lastError = tostring(err)
		trace.nextRetryAt = now + (cfg.persistentTraceRetrySeconds or 2.0)
	end
	return ok == true
end

function helpers.traceAppend(line)
	if not state or type(line) ~= "string" then return end
	if not (ui and ui.fileLog and ui.fileLog:Get()) then return end
	if not state.sessionTrace then helpers.beginTraceSession() end
	local trace = state.sessionTrace
	if not trace or trace.enabled ~= true or trace.flushing then return end
	local size = #line + 1
	if trace.writeFailed and (trace.pendingChars or 0) + size > (cfg.persistentTraceFailureBufferChars or 131072) then
		trace.dropped = (trace.dropped or 0) + 1
		return
	end
	trace.pending[#trace.pending + 1] = line
	trace.pendingChars = (trace.pendingChars or 0) + size
	trace.totalLines = (trace.totalLines or 0) + 1
	trace.totalChars = (trace.totalChars or 0) + size
	trace.flushed = false
	if trace.pendingChars >= (cfg.persistentTraceCheckpointChars or 4096) then
		helpers.traceCheckpoint("size", false)
	end
end

function helpers.traceFlush(reason)
	if not state or not state.sessionTrace then return false end
	local trace = state.sessionTrace
	if trace.enabled ~= true then return true end
	local ok = helpers.traceCheckpoint(reason or "flush", true)
	local path = cfg.persistentTracePath or [[C:\Soft\Umbrella\scripts\invoker_ss_game_log.txt]]
	if ok then
		local metaOk, err = pcall(function()
			helpers.writeTraceFile(path, "a", ("=== INVOKER SESSION v137 END reason=%s lines=%d chars=%d dropped=%d ===\n"):format(
				tostring(reason or "unknown"), trace.totalLines or 0, trace.totalChars or 0, trace.dropped or 0))
		end)
		ok = metaOk == true
		if not metaOk then trace.lastError = tostring(err) end
	end
	trace.flushed = ok == true
	trace.writeFailed = ok ~= true
	return ok == true
end

local function logDebug(scope, message)
	-- v67: Invoker runtime diagnostics are file-only; the framework console is not used by this module.
	if not (ui and ui.fileLog and ui.fileLog:Get()) then return end
	local line = ("[Invoker][%s] %s"):format(scope, message)
	helpers.traceAppend(line)
	if scope == "TP TRACK" or scope == "TP SUN" or scope == "SUN CAST" or scope == "SUN CAST MOTION" or scope == "LIFECYCLE" then
		helpers.traceCheckpoint("critical:" .. scope, true)
	end
end

local function logChanged(key, scope, message)
	if state.lastDebug[key] == message then return end
	state.lastDebug[key] = message
	logDebug(scope, message)
end

local function setStatus(phase, message)
	state.statusPhase = phase
	state.status = message
	-- Preserve precise UI status; bucket only the repetitive cooldown log to whole seconds.
	local logMessage = message:gsub("Sun Strike cooldown (%d+%.%d+)s", function(seconds)
		return ("Sun Strike cooldown %ds"):format(math.ceil(tonumber(seconds)))
	end)
	logChanged("status", "STATUS", phase .. ": " .. logMessage)
end

---Builds an immutable settings snapshot from the current menu values.
---@return table
local function readSettings()
	if state.settingsCache then return state.settingsCache end
	local sunMasterEnabled = ui.autoSunStrike:Get()
	local landingSunEnabled = sunMasterEnabled and ui.landingSun:Get()
	local settings = {
		auto = {
			sunStrike = sunMasterEnabled,
			sunWithScepter = sunMasterEnabled and ui.sunWithScepter:Get(),
			sunSelfCharge = sunMasterEnabled and ui.sunSelfCharge:Get(),
			landingSun = landingSunEnabled,
			landingTeleports = landingSunEnabled and ui.landingTeleports:Get(),
			landingTeleportAnyHp = landingSunEnabled and ui.landingTeleports:Get() and ui.landingTeleportAnyHp:Get(),
			landingTeleportLethal = landingSunEnabled and ui.landingTeleports:Get() and ui.landingTeleportLethal:Get(),
			landingCyclones = landingSunEnabled and ui.landingCyclones:Get(),
			landingLethal = landingSunEnabled and ui.landingCyclones:Get() and ui.landingLethal:Get(),
			sunMinMana = ui.sunMinMana:Get(),
			sunWalkTime = ui.sunWalkTime:Get() / 10,
			sunIdleTime = ui.sunIdleTime:Get() / 10,
			useControlledTargets = sunMasterEnabled and ui.useControlledTargets:Get(),
			controlUseMode = ui.controlUseMode:Get(),
			controlHpPercent = ui.controlHpPercent:Get(),
			predictRunningTargets = sunMasterEnabled and ui.predictRunningTargets:Get(),
			antiZigzag = sunMasterEnabled and ui.predictRunningTargets:Get() and ui.antiZigzag:Get(),
			fogRouteSun = sunMasterEnabled and ui.predictRunningTargets:Get() and ui.fogRouteSun:Get(),
			quickSunButtons = sunMasterEnabled and ui.quickSunButtons:Get(),
			countSunMisses = ui.movingSunBlockVisual:Get() and ui.sunCountMisses:Get(),
			xStandingSun = sunMasterEnabled and ui.movingSunBlockStanding:Get(),
			sunSafeCameraMove = sunMasterEnabled and ui.sunSafeCameraMove:Get(),
			sunEnemySafetyRadius = ui.sunEnemySafetyRadius:Get(),
			sunSafeCameraReturn = sunMasterEnabled and ui.sunSafeCameraMove:Get() and ui.sunSafeCameraReturn:Get(),
			sunSafeCameraOnly = sunMasterEnabled and ui.sunSafeCameraOnly:Get(),
			sunSafeDryRun = sunMasterEnabled and ui.sunSafeDryRun:Get(),
			sunIndication = sunMasterEnabled and ui.sunIndication:Get(),
			sunNotification = sunMasterEnabled and ui.sunNotification:Get(),
			sunNotificationCameraOnly = sunMasterEnabled and ui.sunNotification:Get() and ui.sunNotificationCameraOnly:Get(),
			cataclysm = ui.autoCataclysm:Get(),
			cataclysmUseMode = math.min(ui.cataclysmUseMode:Get(), 2),
			cataclysmMinMana = ui.cataclysmMinMana:Get(),
			cataclysmSelfCharge = ui.cataclysmSelfCharge:Get(),
			cataclysmTornado = ui.cataclysmTornado:Get(),
			cataclysmRefresher = ui.autoRefresher:Get(),
			roshan = sunMasterEnabled and ui.autoRoshan:Get(),
			roshanMargin = ui.roshanMargin:Get(),
			tormentor = sunMasterEnabled and ui.autoTormentor:Get(),
			tormentorMargin = ui.tormentorMargin:Get(),
			cataclysmMinHeroes = ui.cataclysmMinHeroes:Get(),
		},
	}
	state.settingsCache = settings
	return settings
end

function helpers.resetTransientRuntime(reason)
	helpers.sunPriority.release(reason or "transient runtime reset")
	state.landings = nil
	state.teleportParticles = nil
	state.teleportHistory = nil
	state.nextLandingScanAt = 0
	state.tornadoFlight = nil
	state.tornadoFogControlState = {}
	state.tornadoCataContainers = {}
	state.landingSunLock = nil
	state.roshan = nil
	state.roshanSpawners = nil
	state.nextRoshanSpawnerScanAt = 0
	state.tormentors = nil
	state.hero = nil
	state.player = nil
	state.bindings = nil
	state.snapshot = nil
	state.motion = {}
	state.motionQuarantine = {}
	state.sunTerrainCache = {}
	state.invokeSequence = nil
	state.orbSequence = nil
	state.lastCompletedInvoke = nil
	state.assumedInvoked = {}
	state.status = ""
	state.statusPhase = "idle"
	state.nextAutoActionAt = 0
	state.automaticActionsPausedUntil = 0
	state.autoSunSafetyUntil = 0
	state.autoSunSafetyReason = nil
	state.autoPending = nil
	state.issuingOrder = false
	state.orderGuardUntil = 0
	state.sunHpLatch = nil
	state.sunVisualTargetIndex = nil
	state.sunVisualTargetUntil = 0
	state.safeSunPreview = nil
	state.safeSunVisualHold = nil
	state.safeSunVisuals = {}
	state.safeSunCameraMove = nil
	state.safeSunCameraLastAutoAt = -math.huge
	state.safeSunNotification = {}
	state.safeSunNotificationHitbox = {}
	state.safeSunAttentionScanAt = 0
	state.sunPostCastTrace = nil
	state.sunCastObserver = {
		prevCooldown = nil, prevInPhase = false, readyCooldownLength = 0,
		phasePosition = nil, phaseAt = 0, lastOrderPosition = nil, lastOrderAt = 0, lastOrderKind = nil,
		lastTransitionAt = 0, lastTransitionKind = nil,
	}
	state.sunOutcomeUnbound = nil
	helpers.blockClickHeld = nil
	state.quickSunSplitCache = nil
	state.quickSunHitboxes = {}
	state.quickSunEntries = {}
	state.movingSunBlockHitboxes = {}
	state.movingSunBlockEntityKeys = {}
end

function helpers.finishMatchSession(reason)
	if not state or state.gameEndHandled then
		if state then state.matchActive = false end
		return
	end
	state.gameEndHandled = true
	logDebug("LIFECYCLE", ("match end reason=%s -> preserve trace/timing until next match"):format(tostring(reason or "unknown")))
	helpers.traceFlush(reason or "game_end")
	helpers.resetTransientRuntime("game end")
	state.matchActive = false
	state.heroDead = false
end

local function resetRuntime(reason)
	helpers.sunPriority.release(reason or "runtime reset")
	state.landings = nil
	state.teleportParticles = nil
	state.teleportHistory = nil
	state.nextLandingScanAt = 0
	state.tornadoFlight = nil
	state.tornadoFogControlState = {}
	state.tornadoCataContainers = {}
	state.landingSunLock = nil
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
	state.motionQuarantine = {}
	state.sunTerrainCache = {}
	state.invokeSequence = nil
	state.orbSequence = nil
	state.lastCompletedInvoke = nil
	state.assumedInvoked = {}
	state.status = ""
	state.statusPhase = "idle"
	state.nextAutoActionAt = 0
	state.automaticActionsPausedUntil = 0
	state.autoSunSafetyUntil = 0
	state.autoSunSafetyReason = nil
	state.autoPending = nil
	state.issuingOrder = false
	state.orderGuardUntil = 0
	state.lastDebug = {}
	state.sunTimingProbe = nil
	state.sunCommandDelayObserved = 0
	state.sunCommandDelayMedianObserved = 0
	state.sunCommandDelayFastResidualMin = nil
	state.sunCommandDelayFastSamples = 0
	state.sunCommandDelaySamples = {}
	state.sunCooldownSeenDelay = 0
	state.sunImpactParticleDelay = 0
	state.sunTimingProbeSamples = 0
	state.sunHpLatch = nil
	state.sunVisualTargetIndex = nil
	state.sunVisualTargetUntil = 0
	state.safeSunPreview = nil
	state.safeSunVisualHold = nil
	state.safeSunVisuals = {}
	state.safeSunCameraMove = nil
	state.safeSunCameraLastAutoAt = -math.huge
	state.safeSunNotification = {}
	state.safeSunNotificationHitbox = {}
	state.safeSunAttentionScanAt = 0
	state.sunPostCastTrace = nil
	state.sunPortraitStats = {}
	state.sunOutcomeShot = nil
	state.sunOutcomeCataclysms = {}
	state.sunOutcomeCooldownSeen = false
	state.sunCooldownTracking = false
	state.cataclysmResultReadyAt = 0
	state.cataclysmCooldownProbeUntil = 0
	state.cataclysmCooldownBase = 0
	state.sunCastObserver = {
		prevCooldown = nil, prevInPhase = false, readyCooldownLength = 0,
		phasePosition = nil, phaseAt = 0, lastOrderPosition = nil, lastOrderAt = 0, lastOrderKind = nil,
		lastTransitionAt = 0, lastTransitionKind = nil,
	}
	state.sunOutcomeUnbound = nil
	helpers.blockClickHeld = nil
	state.quickSunSplitCache = nil
	state.quickSunHitboxes = {}
	state.quickSunEntries = {}
	state.movingSunBlockHitboxes = {}
	state.movingSunBlockEntityKeys = {}
	state.heroDead = false
	state.gameEndHandled = false
	helpers.beginTraceSession()
end

-- v90 Safe SS camera/indication module. This module never changes Sun target selection or damage math;
-- it is a final automatic-cast gate plus observational UI. Manual portrait SS and Cataclysm bypass it.
function helpers.safeSunClientCameraPos()
	if Humanizer and Humanizer.GetClientCameraPos then
		local ok, pos = pcall(Humanizer.GetClientCameraPos)
		if ok and pos then return copyPoint(pos) end
	end
	return nil
end

function helpers.safeSunInCamera(position)
	if not position then return false, "no_position" end
	if Humanizer and Humanizer.IsInServerCameraBounds then
		local ok, inside = pcall(Humanizer.IsInServerCameraBounds, toVector(position))
		if ok then return inside == true, "humanizer" end
	end
	local ok, screen, visible = pcall(function() return toVector(position):ToScreen() end)
	if ok then return visible == true and screen ~= nil, "screen" end
	return false, "unavailable"
end

function helpers.safeSunAttentionKey(pending, target)
	local key = target and helpers.movingSunBlockKey(target) or nil
	if not key and pending and pending.targetIndex and state.movingSunBlockEntityKeys then
		key = state.movingSunBlockEntityKeys[pending.targetIndex]
	end
	if not key then
		key = ("objective:%s"):format(tostring(pending and (pending.targetIndex or pending.kind) or "sun"))
	end
	return key
end

-- Umbrella's separate built-in Invoker module can keep its old Number Indication enabled even while
-- this standalone module owns Auto SS. That foreign control draws the Sun icon + damage number above
-- world heroes. Disable only that one control; leave built-in prediction, notifications and Auto Use untouched.
function helpers.disableBuiltinSunNumberIndication()
	if state.builtinSunNumberIndicationDisabled then return true end
	local now = GameRules and GameRules.GetGameTime and GameRules.GetGameTime() or 0
	if now < (state.nextBuiltinSunIndicatorScanAt or 0) then return false end
	state.nextBuiltinSunIndicatorScanAt = now + 1.0
	local paths = {
		{"Heroes", "Hero List", "Invoker", "Auto Usage", "Sun Strike Indication", "Number Indication"},
		{"Герои", "Список героев", "Invoker", "Авто-использование", "Индикация Sun-Strike", "Индикация"},
	}
	for _, path in ipairs(paths) do
		local okFind, control = pcall(Menu.Find, table.unpack(path))
		if okFind and control and type(control.Get) == "function" and type(control.Set) == "function" then
			local okGet, enabled = pcall(function() return control:Get() end)
			if okGet and enabled == true then pcall(function() control:Set(false) end) end
			local okVerify, current = pcall(function() return control:Get() end)
			if okVerify and current == false then
				state.builtinSunNumberIndicationDisabled = true
				logDebug("SUN INDICATION", "built-in Invoker Number Indication disabled -> overhead Sun icon/damage removed")
				return true
			end
		end
	end
	return false
end

function helpers.safeSunMoveCamera(position, snapshot, source, attentionKey)
	if not position or not Engine or not Engine.ExecuteCommand then return false, "unavailable" end
	local isAuto = source == "auto_ss"
	if isAuto then
		-- v99: automatic movement is globally serialized. Per-notice one-shot ownership is checked by
		-- updateSafeSunAutoCamera(); this low-level boundary only enforces the shared 20-second clock.
		if state.safeSunCameraMove then return false, "session_active" end
		local lastGlobal = state.safeSunCameraLastAutoAt or -math.huge
		if snapshot.now - lastGlobal < (cfg.sunCameraGlobalCooldown or 20.0) then
			return false, "global_cooldown"
		end
	end
	local before = helpers.safeSunClientCameraPos()
	local ok = pcall(Engine.ExecuteCommand, ("dota_camera_set_lookatpos %.0f %.0f"):format(position.x, position.y))
	if not ok then return false, "command_failed" end
	if isAuto then state.safeSunCameraLastAutoAt = snapshot.now end
	state.safeSunCameraMove = {
		returnPos = before and copyPoint(before) or nil,
		targetPos = copyPoint(position),
		movedAt = snapshot.now,
		returnAt = nil,
		castWaitUntil = snapshot.now + (cfg.sunCameraCastWaitTimeout or 8.0),
		settled = false,
		source = source or "auto",
		attentionKey = attentionKey,
	}
	logChanged("safe_camera_move", "SUN SAFE CAMERA", ("source=%s key=%s aim=%.0f,%.0f -> CAMERA FIRST"):format(
		tostring(source or "auto"), tostring(attentionKey or "manual"), position.x, position.y))
	return true, "moved"
end

function helpers.updateSafeSunCamera(snapshot, settings)
	local record = state.safeSunCameraMove
	if not record then return end
	-- Camera Move owns every automatic follow-up command, including a scheduled return after a
	-- manual notification click. Turning it off invalidates the session without moving the camera.
	if not settings or not settings.sunSafeCameraMove then
		state.safeSunCameraMove = nil
		return
	end
	local current = helpers.safeSunClientCameraPos()
	if current and record.targetPos then
		local delta = distance2D(current, record.targetPos)
		if delta <= 450 then
			record.settled = true
		elseif record.settled and (not record.returnAt or snapshot.now < record.returnAt) and delta > 700 then
			-- v99: cancelling only the current move/return session never restores the notice's one-shot.
			logDebug("SUN SAFE CAMERA", "manual camera movement detected -> scheduled return cancelled; notice one-shot/global cooldown preserved")
			state.safeSunCameraMove = nil
			return
		end
	end
	if not record.returnAt then
		if snapshot.now < (record.castWaitUntil or math.huge) then return end
		-- A camera move can outlive a candidate that never produced a physical SS order. Do not leave
		-- the camera session stuck forever; restore once after the bounded wait, without pretending SS fired.
		if settings and settings.sunSafeCameraReturn and record.returnPos and Engine and Engine.ExecuteCommand then
			pcall(Engine.ExecuteCommand, ("dota_camera_set_lookatpos %.0f %.0f"):format(record.returnPos.x, record.returnPos.y))
		end
		logDebug("SUN SAFE CAMERA", ("return source=%s reason=no_sun_timeout; notice one-shot/global cooldown preserved"):format(
			tostring(record.source or "auto")))
		state.safeSunCameraMove = nil
		return
	end
	if state.safeSunCameraMove and snapshot.now >= record.returnAt then
		if settings and settings.sunSafeCameraReturn and record.returnPos and Engine and Engine.ExecuteCommand then
			pcall(Engine.ExecuteCommand, ("dota_camera_set_lookatpos %.0f %.0f"):format(record.returnPos.x, record.returnPos.y))
			logDebug("SUN SAFE CAMERA", ("return source=%s pos=%.0f,%.0f after_sun=3.00s; notice one-shot/global cooldown preserved"):format(
				tostring(record.source or "auto"), record.returnPos.x, record.returnPos.y))
		end
		state.safeSunCameraMove = nil
	end
end

function helpers.armSafeSunCameraReturn(pending, target, snapshot, issuedAt)
	local record = state.safeSunCameraMove
	if not record or record.returnAt then return false end
	local attentionKey = helpers.safeSunAttentionKey(pending, target)
	if record.attentionKey and attentionKey and record.attentionKey ~= attentionKey then return false end
	local orderAt = issuedAt or snapshot.now
	local probe = state.sunTimingProbe
	local impactAt = probe and probe.issuedAt == orderAt and probe.expectedImpactAt
		or orderAt + helpers.sunImpactDelay(snapshot, "sun_strike")
	record.sunIssuedAt = orderAt
	record.sunImpactAt = impactAt
	record.returnAt = impactAt + (cfg.sunCameraReturnDelay or 3.0)
	record.castWaitUntil = nil
	logDebug("SUN SAFE CAMERA", ("return armed key=%s impact_in=%.2f return_in=%.2f"):format(
		tostring(attentionKey or "unknown"), math.max(0, impactAt - snapshot.now), math.max(0, record.returnAt - snapshot.now)))
	return true
end

function helpers.clearSafeSunNotification(reason, key)
	state.safeSunNotification = state.safeSunNotification or {}
	state.safeSunNotificationHitbox = state.safeSunNotificationHitbox or {}
	if key then
		local notice = state.safeSunNotification[key]
		if notice then
			logDebug("SUN SAFE NOTIFY", ("close key=%s reason=%s"):format(tostring(key), tostring(reason or "invalid")))
		end
		state.safeSunNotification[key] = nil
		state.safeSunNotificationHitbox[key] = nil
		return
	end
	for noticeKey, notice in pairs(state.safeSunNotification) do
		logDebug("SUN SAFE NOTIFY", ("close key=%s reason=%s"):format(
			tostring(notice and notice.key or noticeKey), tostring(reason or "invalid")))
	end
	state.safeSunNotification = {}
	state.safeSunNotificationHitbox = {}
end

function helpers.updateSafeSunNotification(snapshot, settings)
	state.safeSunNotification = state.safeSunNotification or {}
	if not settings or not (settings.sunNotification or settings.sunSafeCameraMove) then
		helpers.clearSafeSunNotification("disabled")
		return
	end
	local action = snapshot and snapshot.actions and snapshot.actions.sun_strike or nil
	if not action or not action.exists or (action.cooldown or 99) > 0.05 then
		helpers.clearSafeSunNotification("sun_cooldown")
		return
	end
	local closing = {}
	for key, notice in pairs(state.safeSunNotification) do
		local reason = nil
		if notice.targetIndex and Entity and Entity.Get then
			local entity = Entity.Get(notice.targetIndex)
			if entity and Entity.IsAlive and not Entity.IsAlive(entity) then reason = "target_dead" end
		end
		-- v108: do not re-test a moving target against the OLD aim point here.  A turn can make that
		-- point stale for one scan and used to close/reopen the notice.  The 10 Hz candidate UI pass
		-- updates both current aim and HP/split truth without tying notice lifetime to route readiness.
		-- A target that merely stops refreshing (fog/entity reconcile) gets the same 3.5 s grace as v98.
		if not reason and snapshot.now - (notice.updatedAt or notice.openedAt or 0) > (cfg.sunNotificationHeartbeatTTL or 3.50) then
			reason = "candidate_removed"
		end
		if reason then closing[#closing + 1] = {key = key, reason = reason} end
	end
	for _, item in ipairs(closing) do helpers.clearSafeSunNotification(item.reason, item.key) end
end

function helpers.emitSafeSunNotification(pending, target, position, snapshot, settings, inCamera)
	if not position or not settings or not (settings.sunNotification or settings.sunSafeCameraMove) then return nil end
	-- Shared ordinary Sun cooldown owns all per-target notices before any attention bookkeeping.
	local action = snapshot and snapshot.actions and snapshot.actions.sun_strike or nil
	if not action or not action.exists or (action.cooldown or 99) > 0.05 then
		helpers.clearSafeSunNotification("sun_cooldown")
		return nil
	end
	local key = helpers.safeSunAttentionKey(pending, target)
	state.safeSunNotification = state.safeSunNotification or {}
	local active = state.safeSunNotification[key]
	local heroName = active and active.heroName or nil
	if target and target.entity then
		local okName, name = pcall(NPC.GetUnitName, target.entity)
		if okName and name and name ~= "" then heroName = name end
	end
	if active then
		-- Stable key owns one long-lived notice. Fog/reacquire, aim/prediction and kind refresh only mutate
		-- its content; they never reset cameraMoveConsumed or openedAt.
		active.position = copyPoint(position)
		active.targetIndex = pending.targetIndex
		active.kind = pending.kind
		active.heroName = heroName
		active.inCamera = inCamera == true
		active.strictLethal = pending.sunStrictLethal == true
		active.updatedAt = snapshot.now
		return active
	end
	active = {
		key = key, targetIndex = pending.targetIndex, kind = pending.kind, heroName = heroName,
		position = copyPoint(position), inCamera = inCamera == true, strictLethal = pending.sunStrictLethal == true,
		openedAt = snapshot.now, updatedAt = snapshot.now,
		cameraMoveConsumed = false, cameraMovedAt = nil,
	}
	state.safeSunNotification[key] = active
	logDebug("SUN SAFE NOTIFY", ("open key=%s target=%s kind=%s persistent=true hero=%s inCamera=%s aim=%.0f,%.0f"):format(
		tostring(key), tostring(pending.targetIndex or "objective"), tostring(pending.kind), tostring(heroName or "none"),
		tostring(inCamera), position.x, position.y))
	return active
end

function helpers.updateSafeSunAutoCamera(snapshot, settings)
	if not settings or not settings.sunSafeCameraMove or settings.sunNotificationCameraOnly then return end
	if state.safeSunCameraMove then return end
	local selectedKey, selectedNotice
	for key, notice in pairs(state.safeSunNotification or {}) do
		if notice and not notice.cameraMoveConsumed and notice.position then
			-- emitSafeSunNotification owns this per-notice camera result for the current snapshot only.
			-- Reuse it in the immediately following auto-camera pass; any later snapshot rechecks the API.
			local inside
			if notice.updatedAt == snapshot.now then
				inside = notice.inCamera
			else
				inside = select(1, helpers.safeSunInCamera(notice.position))
			end
			notice.inCamera = inside == true
			if not inside then
				local openedAt = notice.openedAt or math.huge
				local selectedAt = selectedNotice and (selectedNotice.openedAt or math.huge) or math.huge
				if not selectedNotice or openedAt < selectedAt
					or openedAt == selectedAt and tostring(key) < tostring(selectedKey)
				then
					selectedKey, selectedNotice = key, notice
				end
			end
		end
	end
	if not selectedNotice then return end
	local lastGlobal = state.safeSunCameraLastAutoAt or -math.huge
	local remaining = (cfg.sunCameraGlobalCooldown or 20.0) - (snapshot.now - lastGlobal)
	if remaining > 0 then
		logChanged("safe_camera_global_wait", "SUN SAFE CAMERA", ("key=%s -> HOLD global 20s (%ds left); notice one-shot still unused"):format(
			tostring(selectedKey), math.max(1, math.ceil(remaining))))
		return
	end
	local moved, reason = helpers.safeSunMoveCamera(selectedNotice.position, snapshot, "auto_ss", selectedKey)
	if moved then
		selectedNotice.cameraMoveConsumed = true
		selectedNotice.cameraMovedAt = snapshot.now
		logDebug("SUN SAFE CAMERA", ("key=%s -> NOTICE ONE-SHOT CONSUMED; next auto move globally >=20s"):format(tostring(selectedKey)))
	else
		logChanged("safe_camera_notice_hold_" .. tostring(selectedKey), "SUN SAFE CAMERA", ("key=%s -> HOLD (%s); one-shot preserved"):format(
			tostring(selectedKey), tostring(reason)))
	end
end

function helpers.handleSafeSunNotificationClick(snapshot, settings)
	local hitboxes = state.safeSunNotificationHitbox or {}
	if Input.IsInputCaptured() then return false end
	local cursorX, cursorY = Input.GetCursorPos()
	local selectedKey = nil
	for key, hitbox in pairs(hitboxes) do
		if cursorX >= hitbox.x and cursorX <= hitbox.x + hitbox.width
			and cursorY >= hitbox.y and cursorY <= hitbox.y + hitbox.height
		then
			selectedKey = key
			break
		end
	end
	if not selectedKey or not Input.IsKeyDownOnce(Enum.ButtonCode.KEY_MOUSE1, false) then return false end
	local notice = state.safeSunNotification and state.safeSunNotification[selectedKey] or nil
	if not notice or not notice.position or not Engine or not Engine.ExecuteCommand then return false end
	local before = helpers.safeSunClientCameraPos()
	local ok = pcall(Engine.ExecuteCommand, ("dota_camera_set_lookatpos %.0f %.0f"):format(notice.position.x, notice.position.y))
	if not ok then return false end
	-- Explicit user click is outside automatic attention ownership: no global 20-second write and no
	-- cameraMoveConsumed change. If Camera Move and Camera Return are both enabled, the return is armed
	-- only after a matching physical Sun order (or the bounded no-cast timeout).
	state.safeSunCameraMove = nil
	if settings and settings.sunSafeCameraReturn then
		state.safeSunCameraMove = {
			returnPos = before and copyPoint(before) or nil,
			targetPos = copyPoint(notice.position), movedAt = snapshot.now, returnAt = nil,
			castWaitUntil = snapshot.now + (cfg.sunCameraCastWaitTimeout or 8.0),
			settled = false, source = "notification", attentionKey = notice.key,
		}
	end
	logDebug("SUN SAFE CAMERA", ("notification click key=%s -> camera moved; auto one-shot/global 20s unchanged"):format(tostring(notice.key)))
	return true
end

function helpers.safeSunGate(pending, target, position, snapshot, settings)
	if not pending or pending.actionId ~= "sun_strike" or pending.kind == "quick_sun" then return true, "bypass" end
	local attentionKey = helpers.safeSunAttentionKey(pending, target)
	local strictVisual = pending.sunStrictLethal == true and target ~= nil
	local visualEligible = true
	if strictVisual and helpers.safeSunCurrentVisualLethal then
		visualEligible = select(1, helpers.safeSunCurrentVisualLethal(pending.targetIndex, position, snapshot, target))
	end
	if strictVisual and not visualEligible then
		helpers.clearSafeSunNotification("not_lethal", attentionKey)
		if state.safeSunVisuals then state.safeSunVisuals[attentionKey] = nil end
		-- v97 invariant preserved for the selected/final-gate legacy preview.
		state.safeSunPreview = nil
		state.safeSunVisualHold = nil
		logChanged("sun_visual_hp_" .. tostring(pending.targetIndex or -1), "SUN VISUAL",
			("target=%s current HP recovered above current Sun damage -> VISUAL SOURCE CLEARED"):format(
				tostring(pending.targetIndex or "none")))
	else
		state.safeSunPreview = {
			position = copyPoint(position), targetPosition = target and target.position and copyPoint(target.position) or nil,
			targetIndex = pending.targetIndex, kind = pending.kind, updatedAt = snapshot.now, expiresAt = snapshot.now + 0.30,
			strictLethal = strictVisual, visualEligible = visualEligible,
		}
	end
	local inCamera, cameraSource = helpers.safeSunInCamera(position)
	if visualEligible then helpers.emitSafeSunNotification(pending, target, position, snapshot, settings, inCamera) end

	-- v99: safeSunGate never owns automatic camera movement. A per-target notice owns exactly one move;
	-- updateSafeSunAutoCamera serializes those moves with one global 20-second clock.
	if settings.sunSafeCameraMove and not settings.sunNotificationCameraOnly and not inCamera then
		local notice = state.safeSunNotification and state.safeSunNotification[attentionKey] or nil
		local reason = notice and notice.cameraMoveConsumed and "notice_consumed"
			or state.safeSunCameraMove and "session_active"
			or snapshot.now - (state.safeSunCameraLastAutoAt or -math.huge) < (cfg.sunCameraGlobalCooldown or 20.0) and "global_cooldown"
			or "notice_wait"
		logChanged("safe_camera_attention_" .. tostring(attentionKey), "SUN SAFE CAMERA",
			("target=%s key=%s -> HOLD (%s); camera is notice-owned, one-shot, global 20s"):format(
				tostring(pending.targetIndex or "objective"), tostring(attentionKey), tostring(reason)))
		return false, "camera_wait"
	end
	if settings.sunSafeCameraOnly and not inCamera then
		logChanged("safe_camera_hold_" .. tostring(pending.targetIndex or pending.kind), "SUN SAFE CAMERA",
			("target=%s kind=%s source=%s -> OFFSCREEN HOLD"):format(
				tostring(pending.targetIndex or "objective"), tostring(pending.kind), tostring(cameraSource)))
		return false, settings.sunNotificationCameraOnly and "notification_camera" or "camera_only"
	end
	if settings.sunSafeDryRun then
		logChanged("safe_dry_run_" .. tostring(pending.targetIndex or pending.kind), "SUN SAFE DRY RUN",
			("target=%s kind=%s aim=%.0f,%.0f -> WOULD CAST, ORDER BLOCKED"):format(
				tostring(pending.targetIndex or "objective"), tostring(pending.kind), position.x, position.y))
		return false, "dry_run"
	end
	return true, "pass"
end

function helpers.safeSunHeroIcon(heroName)
	if not renderCtx or not heroName or heroName == "" then return nil end
	renderCtx.heroIcons = renderCtx.heroIcons or {}
	local cached = renderCtx.heroIcons[heroName]
	if cached ~= nil then return cached ~= false and cached or nil end
	local path = ("panorama/images/heroes/icons/%s_png.vtex_c"):format(heroName)
	local ok, image = pcall(Render.LoadImage, path)
	renderCtx.heroIcons[heroName] = ok and image or false
	return ok and image or nil
end

function helpers.updateSafeSunCandidateUI(snapshot, settings)
	state.safeSunVisuals = state.safeSunVisuals or {}
	if not snapshot or not settings then return end
	local wantsVisual = settings.sunIndication == true
	local wantsAttention = settings.sunNotification == true or settings.sunSafeCameraMove == true
	if not wantsVisual then state.safeSunVisuals = {} end
	if not (wantsVisual or wantsAttention) then return end
	if snapshot.now < (state.safeSunAttentionScanAt or 0) then return end
	state.safeSunAttentionScanAt = snapshot.now + (cfg.sunAttentionScanInterval or 0.10)

	for _, enemy in ipairs(snapshot.enemies or {}) do
		local pending = {actionId = "sun_strike", kind = "sun_strike", targetIndex = enemy.index}
		local key = helpers.safeSunAttentionKey(pending, enemy)
		-- Keep this scan observational. evaluateAutoSun() is the authoritative eligibility function, but
		-- prediction/route evaluation normally writes per-target caches used by the combat selector. Save and
		-- restore those writes so multi-target UI cannot warm/alter the later real selection path.
		local oldCache = state.sunTerrainCache and state.sunTerrainCache[enemy.index] or nil
		local oldAimMeta, oldAimDirection, oldRouteGate = enemy.sunAimMeta, enemy.sunLockedAimDirection, enemy.sunRouteGate
		local track = state.motion and state.motion[enemy.index] or nil
		local oldRoutePass = track and track.lastSunRouteGatePass or nil
		local oldRouteReason = track and track.lastSunRouteGateReason or nil
		local evaluation = helpers.sunPriority.evaluateAutoSun(enemy, snapshot, settings)
		if state.sunTerrainCache then state.sunTerrainCache[enemy.index] = oldCache end
		enemy.sunAimMeta, enemy.sunLockedAimDirection, enemy.sunRouteGate = oldAimMeta, oldAimDirection, oldRouteGate
		if track then track.lastSunRouteGatePass, track.lastSunRouteGateReason = oldRoutePass, oldRouteReason end
		local eligible = evaluation ~= nil
		if eligible and evaluation.strictLethal and helpers.safeSunCurrentVisualLethal then
			eligible = select(1, helpers.safeSunCurrentVisualLethal(enemy.index, evaluation.prediction, snapshot, enemy))
		end
		if eligible then
			pending.sunStrictLethal = evaluation.strictLethal == true
			local inCamera = select(1, helpers.safeSunInCamera(evaluation.prediction))
			if wantsVisual then
				state.safeSunVisuals[key] = {
					key = key, targetIndex = enemy.index, position = copyPoint(evaluation.prediction),
					targetPosition = enemy.position and copyPoint(enemy.position) or nil,
					kind = "sun_strike", strictLethal = evaluation.strictLethal == true, updatedAt = snapshot.now,
				}
			end
			if wantsAttention then helpers.emitSafeSunNotification(pending, enemy, evaluation.prediction, snapshot, settings, inCamera) end
		else
			local notice = state.safeSunNotification and state.safeSunNotification[key] or nil
			local keptByHp = false
			-- v108: an existing lethal notice is owned by target + current HP/split eligibility, not by
			-- RUNNER_ROUTE.  A turn, fork or short route-confidence reset may delay the cast, but it only
			-- refreshes the aim shown by the same notice; it must never close/reopen that notice.
			if notice and notice.kind == "sun_strike" and notice.strictLethal
				and helpers.safeSunNotificationHpEligible
			then
				local hpEligible, trackedTarget, impactHealth, expectedDamage, splitCount, hpAim =
					helpers.safeSunNotificationHpEligible(enemy.index, snapshot, enemy)
				if hpEligible and hpAim then
					keptByHp = true
					notice.position = copyPoint(hpAim)
					notice.targetPosition = trackedTarget and trackedTarget.position and copyPoint(trackedTarget.position) or nil
					notice.inCamera = select(1, helpers.safeSunInCamera(hpAim))
					notice.updatedAt = snapshot.now
					if wantsVisual then
						state.safeSunVisuals[key] = {
							key = key, targetIndex = enemy.index, position = copyPoint(hpAim),
							targetPosition = notice.targetPosition and copyPoint(notice.targetPosition) or nil,
							kind = "sun_strike", strictLethal = true, updatedAt = snapshot.now,
						}
					end
					logChanged("sun_notice_hp_owner_" .. tostring(enemy.index), "SUN SAFE NOTIFY",
						("target=%d route changed/not ready; HP still fits %.0f/%.0f split=%d -> KEEP SAME NOTICE, UPDATE AIM"):format(
							enemy.index, impactHealth or 0, expectedDamage or 0, splitCount or 1))
				end
			end
			if not keptByHp and enemy.visible and not enemy.dormant then
				-- Visible current HP/split truth is authoritative.  Route failure alone was handled above.
				state.safeSunVisuals[key] = nil
				if notice and notice.kind == "sun_strike" then helpers.clearSafeSunNotification("hp_no_longer_eligible", key) end
			end
		end
	end

	for key, visual in pairs(state.safeSunVisuals) do
		if snapshot.now - (visual.updatedAt or 0) > (cfg.sunNotificationHeartbeatTTL or 3.50) then
			state.safeSunVisuals[key] = nil
		end
	end
end

function helpers.drawSafeSunNotification()
	state.safeSunNotificationHitbox = {}
	if not ui or not ui.sunNotification or not ui.sunNotification:Get() or not state or not renderCtx then return end
	local notices = {}
	for key, notice in pairs(state.safeSunNotification or {}) do
		if notice and notice.position then notices[#notices + 1] = {key = key, notice = notice} end
	end
	if #notices == 0 then return end
	table.sort(notices, function(a, b)
		local left = a.notice.openedAt or math.huge
		local right = b.notice.openedAt or math.huge
		if left == right then return tostring(a.key) < tostring(b.key) end
		return left < right
	end)
	local screen = Render.ScreenSize()
	local scaleValue = clamp(screen.y / 1080, 0.72, 1.35)
	local width, height = 292 * scaleValue, 62 * scaleValue
	local x = screen.x - width - 24 * scaleValue
	local baseY = screen.y * 0.235
	local gap = 8 * scaleValue
	for index, item in ipairs(notices) do
		local notice = item.notice
		local y = baseY + (index - 1) * (height + gap)
		local hovered = Input.IsCursorInRect(x, y, width, height)
		Render.FilledRect(Vec2(x, y), Vec2(x + width, y + height),
			hovered and Color(31, 36, 43, 246) or Color(20, 24, 30, 238), 7 * scaleValue)
		Render.Rect(Vec2(x, y), Vec2(x + width, y + height),
			hovered and Color(255, 177, 78, 235) or Color(92, 99, 111, 205), 1.5 * scaleValue, Enum.DrawFlags.None, 1)
		local iconSize = 42 * scaleValue
		local heroIcon = helpers.safeSunHeroIcon(notice.heroName) or renderCtx.icons.sun_strike
		Render.Image(heroIcon, Vec2(x + 10 * scaleValue, y + 10 * scaleValue),
			Vec2(iconSize, iconSize), Color(255, 255, 255, 255), 5 * scaleValue)
		Render.Text(renderCtx.titleFont, 16 * scaleValue, "Sun Strike",
			Vec2(x + 62 * scaleValue, y + 9 * scaleValue), Color(245, 247, 250, 255))
		local secondary = notice.inCamera and tr("notify.sun_ready") or tr("notify.sun_offscreen")
		Render.Text(renderCtx.font, 13 * scaleValue, secondary,
			Vec2(x + 62 * scaleValue, y + 33 * scaleValue), Color(190, 198, 210, 245))
		state.safeSunNotificationHitbox[item.key] = {x = x, y = y, width = width, height = height}
	end
end

function helpers.drawSafeSunIndication()
	if not ui or not ui.sunIndication or not ui.sunIndication:Get() or not state then return end
	local snapshot = state.snapshot
	local now = snapshot and (snapshot.now or GameRules.GetGameTime()) or GameRules.GetGameTime()
	local entries, seenTargets = {}, {}
	for key, preview in pairs(state.safeSunVisuals or {}) do
		if preview and preview.position and now - (preview.updatedAt or 0) <= (cfg.sunNotificationHeartbeatTTL or 3.50) then
			local valid = true
			if preview.strictLethal and snapshot then
				valid = select(1, helpers.safeSunCurrentVisualLethal(preview.targetIndex, preview.position, snapshot))
			end
			if valid then
				entries[#entries + 1] = {key = key, preview = preview}
				if preview.targetIndex then seenTargets[preview.targetIndex] = true end
			else
				state.safeSunVisuals[key] = nil
			end
		end
	end

	-- Keep Landing Sun/objective previews that do not participate in the ordinary multi-target scan.
	local legacy = helpers.safeSunVisualDisplay()
	if legacy and legacy.position and (not legacy.targetIndex or not seenTargets[legacy.targetIndex]) then
		entries[#entries + 1] = {key = "legacy", preview = legacy}
	end
	table.sort(entries, function(a, b)
		local ai = a.preview.targetIndex or math.huge
		local bi = b.preview.targetIndex or math.huge
		if ai == bi then return tostring(a.key) < tostring(b.key) end
		return ai < bi
	end)
	for _, item in ipairs(entries) do
		local preview = item.preview
		local okAim, aimScreen, aimVisible = pcall(function() return toVector(preview.position):ToScreen() end)
		if okAim and aimVisible and aimScreen then
			Render.Circle(aimScreen, 13, Color(255, 72, 72, 235), 2, 0, 1, false, 28)
			Render.FilledCircle(aimScreen, 3, Color(255, 210, 90, 240), 0, 1, 16)
			if ui.sunTrajectory and ui.sunTrajectory:Get() and preview.targetPosition then
				local okTarget, targetScreen, targetVisible = pcall(function() return toVector(preview.targetPosition):ToScreen() end)
				if okTarget and targetVisible and targetScreen then
					Render.Line(targetScreen, aimScreen, Color(255, 155, 70, 220), 2)
				end
			end
		end
	end
end

local specialKeys = {
	tornado = {"travel_speed", "travel_distance", "area_of_effect", "lift_duration", "base_damage", "wex_damage"},
	sun_strike = {"delay", "area_of_effect", "damage", "cataclysm_count", "cataclysm_cooldown"},
	cataclysm = {"delay", "area_of_effect", "damage", "cataclysm_count", "cataclysm_cooldown"},
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
	tornado = {travel_distance = "wex", lift_duration = "quas", wex_damage = "wex"},
	sun_strike = {damage = "exort"},
	cataclysm = {damage = "exort"},
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

local function resolveSlotAbilities(hero)
	local result = {}
	local handles = {}
	local indexes = {}

	-- IMPORTANT: only the two physical Invoker D/F slots count as "invoked".
	-- The hidden master Sun Strike ability can report activated=true even while Sun is NOT in D/F,
	-- so Ability.IsActivated() must never be used as a substitute for D/F presence.
	-- The donor script uses exactly ability indexes 3 and 4 for the displayed invoked slots.
	for _, index in ipairs({3, 4}) do
		local ability = NPC.GetAbilityByIndex(hero, index)
		if ability then
			local okName, name = pcall(Ability.GetName, ability)
			if okName and name then
				for _, id in ipairs(spellIds) do
					if id ~= "cataclysm" and contains(definitions[id].runtimeNames, name) then
						pushUnique(result, id)
						handles[id] = ability
						indexes[id] = index
						break
					end
				end
			end
		end
	end
	return result, handles, indexes
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


function helpers.resetMotionContinuity(track, now, context)
	context = context or {}
	local oldVelocity = copyPoint(track.velocity or {x = 0, y = 0, z = 0})
	local oldRecent = copyPoint(track.recentVelocity or oldVelocity)
	local oldInstant = copyPoint(track.instantVelocity or oldRecent)
	local wasMoving = track.walkingSince ~= math.huge
		or length2D(oldVelocity) >= 20 or length2D(oldRecent) >= 20 or length2D(oldInstant) >= 20
	if wasMoving then
		logDebug("MOTION RESET", ("target=%s reason=%s native=%s delta=%.1f raw=%.1f segment=%.1f long=%.1f recent=%.1f instant=%.1f noDisp=%.2f"):format(
			tostring(context.index or "?"), tostring(context.reason or "unknown"), tostring(context.nativeMoving == true),
			context.deltaPos or 0, context.rawSpeed or 0, context.segmentSpeed or 0,
			length2D(oldVelocity), length2D(oldRecent), length2D(oldInstant),
			context.lastDisplacementAge or 0))
		logDebug("MOTION STATE", ("target=%s RUNNER -> IDLE reason=%s"):format(
			tostring(context.index or "?"), tostring(context.reason or "unknown")))
	end
	track.velocity = {x = 0, y = 0, z = 0}
	track.recentVelocity = {x = 0, y = 0, z = 0}
	track.instantVelocity = {x = 0, y = 0, z = 0}
	track.previousRecentVelocity = {x = 0, y = 0, z = 0}
	track.previousRecentAt = 0
	track.turnRate = 0
	track.acceleration = 0
	track.recentConfidence = 0
	track.confidence = 0.9
	track.walkingSince = math.huge
	track.stableSince = math.huge
	if track.idleSince == math.huge then track.idleSince = now end
	track.lastDirection = {x = 0, y = 0, z = 0}
	track.lastSpeed = 0
	track.lastDisplacementAt = -math.huge
	track.motionState = "idle"
	track.lastMotionResetReason = context.reason or "unknown"
	track.motionBridgeActive = false
	track.rawBridgeActive = false
	-- v24 keeps a separate long route history only for runner qualification.
	-- Do not let a stop/discontinuity inherit old zig-zag evidence or old straight-run proof.
	track.routeSamples = {}
end

function helpers.updateMotionContinuity(track, now, moving, direction, speed, context)
	context = context or {}
	if not moving then
		context.reason = context.reason or "continuity_not_moving"
		helpers.resetMotionContinuity(track, now, context)
		return
	end
	if speed < 20 then
		-- v29: do not destroy an already proven runner from one lagging long-window speed sample.
		-- NPC.IsRunning + recent displacement may still prove motion while the ~1 s aggregate velocity
		-- is temporarily below 20 after a pathing turn / tree detour.  Preserve continuity only for
		-- the existing 0.30 s displacement grace; a real stop still reaches the normal reset path.
		local displacementAge = context.lastDisplacementAge or math.huge
		if track.motionState == "runner" and context.nativeMoving == true and displacementAge <= 0.30 then
			return
		end
		context.reason = context.reason or "continuity_speed_below_20"
		helpers.resetMotionContinuity(track, now, context)
		return
	end
	if track.motionState ~= "runner" then
		logDebug("MOTION STATE", ("target=%s IDLE -> RUNNER native=%s speed=%.1f raw=%.1f segment=%.1f"):format(
			tostring(context.index or "?"), tostring(context.nativeMoving == true), speed,
			context.rawSpeed or 0, context.segmentSpeed or 0))
	end
	track.motionState = "runner"
	track.idleSince = math.huge
	if track.walkingSince == math.huge then track.walkingSince = now end
	if track.stableSince == math.huge then track.stableSince = now end
	if speed <= 0 then return end

	-- Running-target stability must represent a real route change, not frame-to-frame pathing jitter.
	-- v17 reset the 0.8 s timer at ~20 degrees and on modest speed noise, which made a visibly
	-- straight-running hero fail the runner gate over and over.  Keep continuity through ordinary
	-- pathing wobble; reset only on a meaningful turn or a very large speed discontinuity.
	local directionChanged = length2D(track.lastDirection) > 0 and dot2D(track.lastDirection, direction) < 0.82
	local speedRatio = track.lastSpeed > 20 and speed / track.lastSpeed or 1
	if directionChanged or speedRatio < 0.35 or speedRatio > 2.60 then track.stableSince = now end
	track.lastDirection = direction
	track.lastSpeed = speed
end

-- v59: rebuild only the hidden segment when the target reappears away from the fog projection.
-- Walking continuity survives because visibility is not a movement stop.  The hidden segment itself is
-- reconstructed through GridNav when possible so route history remains map-valid instead of becoming
-- one straight chord through cliffs/trees.
function helpers.reconcileFogRouteSamples(track, actualPosition, now)
	local startAt = track.lastObservedAt or -math.huge
	local startPosition = track.lastObservedPosition
	if not startPosition or startAt == -math.huge or now <= startAt then return false, 0 end
	track.routeSamples = track.routeSamples or {}
	while #track.routeSamples > 0 and track.routeSamples[#track.routeSamples].source == "projected" do
		table.remove(track.routeSamples)
	end
	local duration = math.max(0.001, now - startAt)
	local path, pathOk
	if GridNav and GridNav.BuildPath then
		local ok, built = pcall(GridNav.BuildPath, toVector(startPosition), toVector(actualPosition), false, nil)
		if ok and type(built) == "table" and #built > 0 then path, pathOk = built, true end
	end
	local points = {copyPoint(startPosition)}
	if pathOk then
		for _, node in ipairs(path) do
			if node then
				local point = {x = node.x, y = node.y, z = node.z or actualPosition.z or 0}
				if distance2D(points[#points], point) >= 2 then points[#points + 1] = point end
			end
		end
	end
	if distance2D(points[#points], actualPosition) >= 2 then points[#points + 1] = copyPoint(actualPosition)
	else points[#points] = copyPoint(actualPosition) end
	local total = 0
	for i = 2, #points do total = total + distance2D(points[i - 1], points[i]) end
	if total < 1 then
		track.routeSamples[#track.routeSamples + 1] = {at = now, position = copyPoint(actualPosition), source = "observed"}
		return pathOk == true, total
	end
	local traversed = 0
	for i = 2, #points do
		traversed = traversed + distance2D(points[i - 1], points[i])
		local at = startAt + duration * clamp(traversed / total, 0, 1)
		local source = i == #points and "observed" or "reconciled"
		local previous = track.routeSamples[#track.routeSamples]
		if not previous or distance2D(previous.position, points[i]) >= 2 or at - previous.at >= 0.035 then
			track.routeSamples[#track.routeSamples + 1] = {at = at, position = copyPoint(points[i]), source = source}
		end
	end
	return pathOk == true, total
end

function helpers.quarantineTeleportMotion(index, untilAt, reason)
	if not state or not index then return end
	local now = GameRules.GetGameTime()
	local minimumUntil = now + (cfg.teleportMotionQuarantine or 0.55)
	untilAt = math.max(untilAt or minimumUntil, minimumUntil)
	state.motionQuarantine = state.motionQuarantine or {}
	local previous = state.motionQuarantine[index]
	if previous and (previous.untilAt or 0) > untilAt then untilAt = previous.untilAt end
	local changed = not previous or tostring(previous.reason) ~= tostring(reason or "teleport")
		or math.abs((previous.untilAt or 0) - untilAt) >= 0.10
	state.motionQuarantine[index] = {untilAt = untilAt, reason = reason or "teleport"}
	state.motion[index] = nil
	if state.sunTerrainCache then state.sunTerrainCache[index] = nil end
	if changed then
		logDebug("MOTION QUARANTINE", ("target=%d reason=%s until=%.2f"):format(index, tostring(reason or "teleport"), untilAt))
	end
end

local function updateMotion(index, position, now, moveSpeed, nativeMoving, source)
	local quarantine = state.motionQuarantine and state.motionQuarantine[index] or nil
	if quarantine then
		if now <= (quarantine.untilAt or 0) then
			state.motion[index] = nil
			return {x = 0, y = 0, z = 0}
		end
		state.motionQuarantine[index] = nil
		logDebug("MOTION QUARANTINE", ("target=%d release reason=%s"):format(index, tostring(quarantine.reason or "teleport")))
	end
	local track = state.motion[index]
	if not track then
		track = {
			samples = {},
			routeSamples = {},
			velocity = {x = 0, y = 0, z = 0},
			recentVelocity = {x = 0, y = 0, z = 0},
			instantVelocity = {x = 0, y = 0, z = 0},
			previousRecentVelocity = {x = 0, y = 0, z = 0},
			previousRecentAt = 0,
			turnRate = 0,
			acceleration = 0,
			recentConfidence = 0,
			confidence = 0,
			directionChanges = 0,
			walkingSince = math.huge,
			stableSince = math.huge,
			idleSince = math.huge,
			lastDirection = {x = 0, y = 0, z = 0},
			lastSpeed = 0,
			lastDisplacementAt = -math.huge,
			motionState = "unknown",
			lastMotionResetReason = "none",
			motionBridgeActive = false,
			rawBridgeActive = false,
			visibilityState = "unknown",
			lastObservedAt = -math.huge,
			lastObservedPosition = nil,
			projectionStartedAt = -math.huge,
			projectionOriginAt = -math.huge,
			projectionOriginPosition = nil,
			lastProjectedAt = -math.huge,
			lastProjectedPosition = nil,
			lastProjectionTangent = nil,
			lastReconcileResult = "none",
		}
		state.motion[index] = track
	end

	source = source or "observed"
	local projectedInput = source == "projected"
	local wasProjected = track.visibilityState == "projected"
	if projectedInput and not wasProjected then
		track.projectionStartedAt = now
		track.projectionOriginAt = track.lastObservedAt
		track.projectionOriginPosition = track.lastObservedPosition and copyPoint(track.lastObservedPosition) or copyPoint(position)
		logDebug("MOTION VISIBILITY", ("target=%d VISIBLE -> FOG walk=%.2f stable=%.2f"):format(
			index,
			track.walkingSince ~= math.huge and math.max(0, now - track.walkingSince) or 0,
			track.stableSince ~= math.huge and math.max(0, now - track.stableSince) or 0))
	end

	local suppressDiscontinuity, forceDiscontinuity = false, false
	if not projectedInput and wasProjected and #track.samples > 0 then
		local projectedPosition = track.lastProjectedPosition or track.samples[#track.samples].position
		local fogAge = track.lastObservedAt > -math.huge and math.max(0, now - track.lastObservedAt) or 0
		local reconcileError = distance2D(projectedPosition, position)
		local closeTolerance = clamp(math.max(72, (moveSpeed or 0) * 0.35), 72, 140)
		local physicalTolerance = math.max(closeTolerance + 1,
			(moveSpeed or 0) * math.max(0.25, fogAge) * 2.15 + 120)
		if reconcileError <= closeTolerance then
			local sample = track.samples[#track.samples]
			sample.at, sample.position, sample.source = now, copyPoint(position), "observed"
			local routeSample = track.routeSamples and track.routeSamples[#track.routeSamples] or nil
			if routeSample and routeSample.source == "projected" then
				routeSample.at, routeSample.position, routeSample.source = now, copyPoint(position), "observed"
			end
			track.lastDisplacementAt = now
			track.lastReconcileResult = "match"
			suppressDiscontinuity = true
			logDebug("MOTION RECONCILE", ("target=%d result=match fog=%.2f error=%.1f tol=%.1f walk=%.2f stable=%.2f"):format(
				index, fogAge, reconcileError, closeTolerance,
				track.walkingSince ~= math.huge and math.max(0, now - track.walkingSince) or 0,
				track.stableSince ~= math.huge and math.max(0, now - track.stableSince) or 0))
		elseif reconcileError <= physicalTolerance then
			local observedAt = track.lastObservedAt
			local observedPosition = track.lastObservedPosition and copyPoint(track.lastObservedPosition) or nil
			local routeOk, routeDistance = helpers.reconcileFogRouteSamples(track, position, now)
			track.samples = {}
			if observedPosition and observedAt > -math.huge and now > observedAt then
				track.samples[#track.samples + 1] = {at = observedAt, position = observedPosition, source = "observed"}
			end
			track.samples[#track.samples + 1] = {at = now, position = copyPoint(position), source = "observed"}
			track.stableSince = now
			track.directionChanges = math.max(1, track.directionChanges or 0)
			track.turnRate = (track.turnRate or 0) * 0.35
			track.acceleration = (track.acceleration or 0) * 0.35
			track.confidence = math.min(track.confidence or 1, 0.72)
			track.recentConfidence = math.min(track.recentConfidence or 1, 0.58)
			track.lastDisplacementAt = now
			track.lastDirection = {x = 0, y = 0, z = 0}
			track.lastSpeed = 0
			track.lastMotionResetReason = "fog_reconcile_route_change"
			track.lastReconcileResult = "route_change"
			suppressDiscontinuity = true
			logDebug("MOTION RECONCILE", ("target=%d result=route_change fog=%.2f error=%.1f physical=%.1f grid=%s route=%.1f walk=%.2f stable=RESET"):format(
				index, fogAge, reconcileError, physicalTolerance, tostring(routeOk == true), routeDistance or 0,
				track.walkingSince ~= math.huge and math.max(0, now - track.walkingSince) or 0))
		else
			forceDiscontinuity = true
			track.lastReconcileResult = "impossible"
			logDebug("MOTION RECONCILE", ("target=%d result=impossible fog=%.2f error=%.1f physical=%.1f -> HARD RESET"):format(
				index, fogAge, reconcileError, physicalTolerance))
		end
	end

	if projectedInput then
		track.visibilityState = "projected"
		track.lastProjectedAt = now
		track.lastProjectedPosition = copyPoint(position)
	else
		track.visibilityState = "observed"
		track.lastObservedAt = now
		track.lastObservedPosition = copyPoint(position)
		track.projectionStartedAt = -math.huge
		track.projectionOriginAt = -math.huge
		track.projectionOriginPosition = nil
		track.lastProjectedAt = -math.huge
		track.lastProjectedPosition = nil
		track.lastProjectionTangent = nil
	end

	local last = track.samples[#track.samples]
	if last then
		local elapsed = now - last.at
		local discontinuity = forceDiscontinuity or (not suppressDiscontinuity and (elapsed < 0 or elapsed > 0.75
			or distance2D(last.position, position) > math.max(cfg.motionResetDistance, moveSpeed * math.max(0, elapsed) * 1.5)))
		if discontinuity then
			local deltaPos = distance2D(last.position, position)
			track.samples = {{at = now, position = copyPoint(position), source = source}}
			track.directionChanges = 0
			track.idleSince = math.huge
			helpers.resetMotionContinuity(track, now, {
				index = index, reason = forceDiscontinuity and "fog_reconcile_impossible" or "discontinuity",
				nativeMoving = nativeMoving, deltaPos = deltaPos,
				lastDisplacementAge = track.lastDisplacementAt > -math.huge and math.max(0, now - track.lastDisplacementAt) or math.huge,
			})
			track.routeSamples = {{at = now, position = copyPoint(position), source = source}}
			track.confidence = 0
			return copyPoint(track.velocity)
		end
	end
	if last and distance2D(last.position, position) >= 3 then track.lastDisplacementAt = now end
	if not last or now - last.at >= 0.035 or distance2D(last.position, position) >= 8 then
		local sample = {at = now, position = copyPoint(position), source = source}
		track.samples[#track.samples + 1] = sample
		track.routeSamples = track.routeSamples or {}
		track.routeSamples[#track.routeSamples + 1] = {at = sample.at, position = copyPoint(sample.position), source = source}
	end
	-- Keep the old ~1 second history for velocity/aim so v24 does NOT reintroduce the old laggy aim.
	while #track.samples > 2 and (#track.samples > 30 or now - track.samples[1].at > 1.0) do
		table.remove(track.samples, 1)
	end
	-- Runner qualification needs to validate the FULL configured walk time (slider allows up to 4.0 s).
	-- This is deliberately separate from aim history: qualification may look long, aim must stay reactive.
	while #(track.routeSamples or {}) > 2 and (#track.routeSamples > 260 or now - track.routeSamples[1].at > 4.2) do
		table.remove(track.routeSamples, 1)
	end

	-- NPC.IsRunning can flicker briefly around pathing updates. Require a real ~0.30 s stop
	-- before destroying an otherwise continuous measured route.
	if not nativeMoving and now - track.lastDisplacementAt > 0.30 then
		helpers.resetMotionContinuity(track, now, {
			index = index, reason = "native_false_no_displacement", nativeMoving = nativeMoving,
			deltaPos = last and distance2D(last.position, position) or 0,
			lastDisplacementAge = track.lastDisplacementAt > -math.huge and math.max(0, now - track.lastDisplacementAt) or math.huge,
		})
		return copyPoint(track.velocity)
	end
	if #track.samples < 2 then
		track.velocity = {x = 0, y = 0, z = 0}
		track.confidence = nativeMoving and 0.15 or 0.9
		helpers.updateMotionContinuity(track, now, nativeMoving, {x = 0, y = 0, z = 0}, 0, {
			index = index, reason = "insufficient_samples", nativeMoving = nativeMoving,
			deltaPos = last and distance2D(last.position, position) or 0,
			lastDisplacementAge = track.lastDisplacementAt > -math.huge and math.max(0, now - track.lastDisplacementAt) or math.huge,
		})
		return copyPoint(track.velocity)
	end

	local first = track.samples[1]
	local newest = track.samples[#track.samples]
	local elapsed = math.max(0.001, newest.at - first.at)
	local raw = scale(subtract(newest.position, first.position), 1 / elapsed)
	local rawSpeed = length2D(raw)
	local displacementAge = track.lastDisplacementAt > -math.huge and math.max(0, now - track.lastDisplacementAt) or math.huge
	local previousInstant = copyPoint(track.instantVelocity or {x = 0, y = 0, z = 0})
	local previousInstantSpeed = length2D(previousInstant)
	if not nativeMoving and rawSpeed < 20 then
		-- v34 root fix: the v33 live log proved this early branch could destroy a proven runner
		-- while displacementAge was 0.00 and the previous measured segment was still ~244-302 u/s.
		-- Reuse the already-established 0.30 s no-displacement truth instead of letting the lagging
		-- ~1 s raw average bypass v29's fresh-motion bridge before it can run.
		local rawBridge = track.motionState == "runner" and displacementAge <= 0.30
			and math.max(length2D(track.velocity or {x = 0, y = 0, z = 0}),
				length2D(track.recentVelocity or {x = 0, y = 0, z = 0}), previousInstantSpeed) >= 20
		if rawBridge then
			if not track.rawBridgeActive then
				logDebug("MOTION RAW BRIDGE", ("target=%d native=false raw=%.1f long=%.1f recent=%.1f instant=%.1f age=%.2f -> KEEP RUNNER"):format(
					index, rawSpeed, length2D(track.velocity or {x = 0, y = 0, z = 0}),
					length2D(track.recentVelocity or {x = 0, y = 0, z = 0}), previousInstantSpeed, displacementAge))
			end
			track.rawBridgeActive = true
		else
			helpers.resetMotionContinuity(track, now, {
				index = index, reason = "native_false_raw_below_20", nativeMoving = nativeMoving,
				deltaPos = distance2D(first.position, newest.position), rawSpeed = rawSpeed,
				segmentSpeed = previousInstantSpeed, lastDisplacementAge = displacementAge,
			})
			return copyPoint(track.velocity)
		end
	elseif track.rawBridgeActive then
		logDebug("MOTION RAW BRIDGE", ("target=%d release native=%s raw=%.1f age=%.2f"):format(
			index, tostring(nativeMoving == true), rawSpeed, displacementAge))
		track.rawBridgeActive = false
	end

	local capped = raw
	if moveSpeed > 0 and rawSpeed > moveSpeed * 1.35 then
		capped = scale(normalized2D(raw), moveSpeed * 1.35)
	end
	local previousDirection = normalized2D(track.velocity)
	local nextDirection = normalized2D(capped)
	if length2D(previousDirection) > 0 and dot2D(previousDirection, nextDirection) < 0.55 then
		track.directionChanges = track.directionChanges + 1
	else
		track.directionChanges = math.max(0, track.directionChanges - 0.25)
	end
	track.velocity = add(scale(track.velocity, 0.3), scale(capped, 0.7))
	track.confidence = clamp(elapsed / 0.22 - track.directionChanges * 0.12, 0.15, 1)

	-- Aim must react much faster than the 0.8 s route-qualification window.  v18 used the
	-- ~1.0 s aggregate velocity for the actual 1.7 s Sun lead, so a small recent turn/stop
	-- could leave the impact circle ahead of the hero even though the runner gate was valid.
	local recentStart = newest
	for sampleIndex = #track.samples - 1, 1, -1 do
		recentStart = track.samples[sampleIndex]
		if newest.at - recentStart.at >= 0.24 then break end
	end
	local recentElapsed = math.max(0.001, newest.at - recentStart.at)
	local recentRaw = scale(subtract(newest.position, recentStart.position), 1 / recentElapsed)
	local recentSpeed = length2D(recentRaw)
	if moveSpeed > 0 and recentSpeed > moveSpeed * 1.35 then
		recentRaw = scale(normalized2D(recentRaw), moveSpeed * 1.35)
	end
	if recentElapsed >= 0.08 then
		track.recentVelocity = add(scale(track.recentVelocity or {x = 0, y = 0, z = 0}, 0.18), scale(recentRaw, 0.82))
		track.recentConfidence = clamp(recentElapsed / 0.24, 0.2, 1)
	else
		track.recentVelocity = copyPoint(track.velocity)
		track.recentConfidence = math.min(track.confidence, 0.25)
	end

	-- Estimate only slow, persistent curvature/acceleration from new route samples.  The values
	-- are heavily damped because a single pathing correction must not bend a 1.7 s forecast.
	if newest.at > (track.previousRecentAt or 0) then
		local previousVelocity = track.previousRecentVelocity or track.recentVelocity
		local dynamicsDt = track.previousRecentAt and track.previousRecentAt > 0 and newest.at - track.previousRecentAt or 0
		local previousSpeed = length2D(previousVelocity)
		local currentRecentSpeed = length2D(track.recentVelocity)
		if dynamicsDt >= 0.025 and dynamicsDt <= 0.30 and previousSpeed > 35 and currentRecentSpeed > 35 then
			local rawTurn = helpers.signedAngle2D(previousVelocity, track.recentVelocity) / dynamicsDt
			local rawAcceleration = (currentRecentSpeed - previousSpeed) / dynamicsDt
			track.turnRate = (track.turnRate or 0) * 0.72 + clamp(rawTurn, -1.25, 1.25) * 0.28
			track.acceleration = (track.acceleration or 0) * 0.76 + clamp(rawAcceleration, -650, 650) * 0.24
		else
			track.turnRate = (track.turnRate or 0) * 0.88
			track.acceleration = (track.acceleration or 0) * 0.88
		end
		track.previousRecentVelocity = copyPoint(track.recentVelocity)
		track.previousRecentAt = newest.at
	end

	local previousSample = track.samples[#track.samples - 1]
	local segmentElapsed = math.max(0.001, newest.at - previousSample.at)
	local segment = scale(subtract(newest.position, previousSample.position), 1 / segmentElapsed)
	local segmentSpeed = length2D(segment)
	track.instantVelocity = copyPoint(segment)

	-- v29 root fix: runner continuity must not be owned by the laggiest ~1 s aggregate velocity.
	-- v34 extends the same rule to the previous measured segment for the already-existing <=0.30 s
	-- displacement grace. This is not a new grace: it prevents a zero/current sample from erasing the
	-- fresh segment that the v33 runtime log still showed at the premature raw reset.
	local smoothSpeed = length2D(track.velocity)
	local recentMotionSpeed = length2D(track.recentVelocity or track.velocity)
	local segmentMotionSpeed = moveSpeed > 0 and math.min(segmentSpeed, moveSpeed * 1.35) or segmentSpeed
	local priorInstantMotionSpeed = displacementAge <= 0.30
		and (moveSpeed > 0 and math.min(previousInstantSpeed, moveSpeed * 1.35) or previousInstantSpeed) or 0
	local continuitySpeed = math.max(smoothSpeed, recentMotionSpeed, segmentMotionSpeed, priorInstantMotionSpeed)
	local continuityVector = track.velocity
	local continuitySource = "long"
	if priorInstantMotionSpeed >= smoothSpeed and priorInstantMotionSpeed >= recentMotionSpeed and priorInstantMotionSpeed >= segmentMotionSpeed then
		continuityVector = previousInstant
		continuitySource = "instant"
	elseif recentMotionSpeed >= smoothSpeed and recentMotionSpeed >= segmentMotionSpeed then
		continuityVector = track.recentVelocity
		continuitySource = "recent"
	elseif segmentMotionSpeed > smoothSpeed then
		continuityVector = segment
		continuitySource = "segment"
	end
	local bridgeActive = smoothSpeed < 20 and continuitySpeed >= 20
	if bridgeActive and not track.motionBridgeActive then
		logDebug("MOTION BRIDGE", ("target=%d source=%s native=%s smooth=%.1f recent=%.1f segment=%.1f instant=%.1f age=%.2f -> KEEP RUNNER"):format(
			index, continuitySource, tostring(nativeMoving == true), smoothSpeed, recentMotionSpeed, segmentMotionSpeed, priorInstantMotionSpeed, displacementAge))
	elseif not bridgeActive and track.motionBridgeActive then
		logDebug("MOTION BRIDGE", ("target=%d release smooth=%.1f recent=%.1f segment=%.1f instant=%.1f"):format(
			index, smoothSpeed, recentMotionSpeed, segmentMotionSpeed, priorInstantMotionSpeed))
	end
	track.motionBridgeActive = bridgeActive
	helpers.updateMotionContinuity(track, now, nativeMoving or continuitySpeed >= 20,
		normalized2D(continuityVector), continuitySpeed, {
			index = index, nativeMoving = nativeMoving, deltaPos = distance2D(previousSample.position, newest.position),
			rawSpeed = rawSpeed, segmentSpeed = segmentMotionSpeed, lastDisplacementAge = displacementAge,
		})
	return copyPoint(track.velocity)
end

local function modifierRemaining(modifier, now)
	local dieTime = Modifier.GetDieTime(modifier)
	if dieTime > 0 then return math.max(0, dieTime - now) end
	local duration = Modifier.GetDuration(modifier)
	local createdAt = Modifier.GetCreationTime(modifier)
	return duration > 0 and math.max(0, duration - math.max(0, now - createdAt)) or 0
end


-- v81 user rule: normal runner keeps the proven forward-edge aim. If the target currently has a
-- temporary move-speed buff OR slow, use the non-edge coverage center because the effect can end
-- before impact. This detector is isolated and pcall-guarded; any API uncertainty falls back to edge aim.
function helpers.sunTemporaryMoveSpeedEffect(target, now)
	local measured = type(target) == "table" and target.sunSpeedState or nil
	if measured and measured.complete then
		local bestName, bestRemaining
		for _, effect in ipairs(measured.effects) do
			local remaining = effect.expiresAt - now
			local persistentItem = effect.name:find("^modifier_item_") or effect.name:find("^modifier_special_bonus")
			if remaining < math.huge or not persistentItem then
				if not bestName or remaining < bestRemaining then bestName, bestRemaining = effect.name, remaining end
			end
		end
		return bestName ~= nil, bestName, bestName and math.max(0, bestRemaining) or 0
	end
	local entity = target and target.entity or target
	if not entity or not Enum or not Enum.ModifierFunction then return false, nil, 0 end
	local index = nil
	pcall(function() index = Entity.GetIndex(entity) end)
	local track = index and state and state.motion and state.motion[index] or nil
	local cached = track and track.sunTemporaryMoveSpeedCache or nil
	if cached and now - (cached.at or -math.huge) <= 0.10 then
		return cached.active == true, cached.name, cached.remaining or 0
	end
	local keys = {
		"MODIFIER_PROPERTY_MOVESPEED_BONUS_CONSTANT", "MODIFIER_PROPERTY_MOVESPEED_BASE_OVERRIDE",
		"MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE", "MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE_UNIQUE",
		"MODIFIER_PROPERTY_MOVESPEED_BONUS_UNIQUE", "MODIFIER_PROPERTY_MOVESPEED_BONUS_UNIQUE_2",
		"MODIFIER_PROPERTY_MOVESPEED_BONUS_CONSTANT_UNIQUE", "MODIFIER_PROPERTY_MOVESPEED_BONUS_CONSTANT_UNIQUE_2",
		"MODIFIER_PROPERTY_MOVESPEED_ABSOLUTE", "MODIFIER_PROPERTY_MOVESPEED_ABSOLUTE_MIN",
		"MODIFIER_PROPERTY_MOVESPEED_ABSOLUTE_MAX", "MODIFIER_PROPERTY_MOVESPEED_LIMIT",
		"MODIFIER_PROPERTY_MOVESPEED_REDUCTION_PERCENTAGE",
	}
	local seen, bestName, bestRemaining = {}, nil, 0
	for _, key in ipairs(keys) do
		local property = Enum.ModifierFunction[key]
		if property ~= nil then
			local okList, list = pcall(NPC.GetModifiers, entity, property)
			if okList and type(list) == "table" then
				for _, modifier in ipairs(list) do
					local identity = tostring(modifier)
					if not seen[identity] then
						seen[identity] = true
						local okName, name = pcall(Modifier.GetName, modifier)
						name = okName and name or "?"
						local remaining = 0
						pcall(function() remaining = modifierRemaining(modifier, now) end)
						local okDebuff, isDebuff = pcall(Modifier.IsDebuff, modifier)
						local permanentItem = type(name) == "string" and name:find("^modifier_item_") ~= nil and remaining <= 0
						local permanentTalent = type(name) == "string" and name:find("^modifier_special_bonus") ~= nil and remaining <= 0
						local dynamic = remaining > 0.02 or (okDebuff and isDebuff == true)
						if dynamic and not permanentItem and not permanentTalent and (bestName == nil or remaining > bestRemaining) then
							bestName, bestRemaining = name, remaining
						end
					end
				end
			end
		end
	end
	local active = bestName ~= nil
	if track then track.sunTemporaryMoveSpeedCache = {at = now, active = active, name = bestName, remaining = bestRemaining} end
	return active, bestName, bestRemaining
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


-- v73 current-speed rule: do not predict future slow/buff expiry or learn modifier-owned speed regimes.
-- The final visible-target refresh reads NPC.GetMoveSpeed() immediately before CastPosition;
-- prediction treats that measured state as constant for this shot. Anything that changes AFTER the
-- order is a post-decision event, not something the predictor tries to guess.
function helpers.observeSunSpeedState(enemy, now, force)
	if not enemy or not enemy.entity or enemy.fogProjected or not enemy.visible or enemy.dormant then return end
	local track = state.motion and state.motion[enemy.index]
	if not track then return end
	local memory = track.sunSpeedMemory
	if not memory then memory = {samples = {}}; track.sunSpeedMemory = memory end
	if not force and memory.latest and now >= memory.latest.at and now - memory.latest.at < 0.05 then
		enemy.sunSpeedState = memory.latest
		return
	end
	-- Read property-filtered engine lists, not spell names or IsDebuff: haste,
	-- slows, items, limits and absolute overrides enter the same mechanism.
	local contributors, effects, context, complete = {}, {}, {}, true
	local okEnums = pcall(function()
		if not helpers.sunSpeedProperties then
			local properties, seen = {}, {}
			for name, property in pairs(Enum.ModifierFunction) do
				if type(name) == "string" and name:find("MOVESPEED", 1, true) and type(property) == "number" and not seen[property] then
					properties[#properties + 1], seen[property] = property, true
				end
			end
			if #properties == 0 then error("No movement-speed properties exposed") end
			helpers.sunSpeedProperties = properties
		end
		for _, property in ipairs(helpers.sunSpeedProperties) do
			for _, modifier in ipairs(NPC.GetModifiers(enemy.entity, property)) do contributors[tostring(modifier)] = modifier end
		end
	end)
	complete = okEnums
	local ok = pcall(function()
		for _, modifier in ipairs(NPC.GetModifiers(enemy.entity)) do
			local name = Modifier.GetName(modifier)
			local token = name .. ":" .. tostring(Modifier.GetStackCount(modifier))
			local ability = Modifier.GetAbility(modifier)
			if ability then token = token .. ":L" .. tostring(Ability.GetLevel(ability)) end
			local caster = Modifier.GetCaster(modifier)
			if caster then token = token .. ":C" .. tostring(Entity.GetIndex(caster)) end
			if contributors[tostring(modifier)] then
				local remaining = modifierRemaining(modifier, now)
				local aura = Modifier.GetProvidedByAura(modifier) or Modifier.IsAura(modifier)
				effects[#effects + 1] = {token = token, name = name,
					expiresAt = remaining > 0 and now + remaining or math.huge, renewable = aura == true}
			else
				context[#context + 1] = token
			end
		end
		context[#context + 1] = "base:" .. tostring(NPC.GetBaseSpeed(enemy.entity))
	end)
	complete = complete and ok
	if not complete then
		logChanged("sun_speed_api_" .. tostring(enemy.index), "SUN SPEED",
			("target=%d source=incomplete_properties enumOK=%s modifiersOK=%s; using observed-speed fallback"):format(
				enemy.index, tostring(okEnums), tostring(ok)))
	end
	table.sort(context)
	table.sort(effects, function(a, b) return a.token < b.token end)
	local contextKey = table.concat(context, "|")
	local tokens = {}
	for _, effect in ipairs(effects) do tokens[#tokens + 1] = effect.token end
	local key = table.concat(tokens, "|")
	local speed = math.max(0, enemy.moveSpeed or 0)
	local sampleKey = contextKey .. "//" .. key
	local old = memory.samples[sampleKey]
	local changed = old and math.abs(old.speed - speed) > 8
	local variable = old and now - old.at < 0.25 and (changed or now - (old.changedAt or -math.huge) < 0.25)
	memory.samples[sampleKey] = {at = now, speed = speed, context = contextKey,
		changedAt = changed and now or old and old.changedAt or nil,
		minimum = variable and math.min(speed, old.minimum or old.speed) or speed,
		maximum = variable and math.max(speed, old.maximum or old.speed) or speed}
	local count, oldestKey, oldestAt = 0, nil, math.huge
	for sampleId, sample in pairs(memory.samples) do
		if now - sample.at > 8 then memory.samples[sampleId] = nil
		else
			count = count + 1
			if sample.at < oldestAt then oldestKey, oldestAt = sampleId, sample.at end
		end
	end
	if count > 32 and oldestKey then memory.samples[oldestKey] = nil end
	enemy.sunSpeedState = {at = now, speed = speed, effects = effects, context = contextKey,
		complete = complete, samples = memory.samples, key = key}
	memory.latest = enemy.sunSpeedState
end

function helpers.sunProjectedMoveSpeed(index, fallback, now)
	local track = state.motion and state.motion[index]
	local data = track and track.sunSpeedMemory and track.sunSpeedMemory.latest
	if data and now >= data.at and now - data.at <= cfg.fogRouteTTL then
		local profile = helpers.sunSpeedTravelProfile({moveSpeed = data.speed, sunSpeedState = data},
			data.at, now - data.at, data.speed, 0, data.speed)
		return profile.endSpeed
	end
	return math.max(0, fallback or 0)
end

function helpers.sunSpeedTravelProfile(target, now, duration, startSpeed, acceleration, speedCeiling)
	local currentStat = math.max(0, target and target.moveSpeed or 0)
	local speed = math.max(0, startSpeed or currentStat)
	duration = math.max(0, duration or 0)
	local data = target and target.sunSpeedState
	local profile = {distance = 0, minimumDistance = 0, maximumDistance = 0, startSpeed = speed,
		endSpeed = speed, active = false, confidence = 1, modifier = nil, expiresIn = math.huge,
		baselineStat = currentStat, affectedStat = currentStat, unresolved = 0, intervals = {}}
	local boundaries = {0, duration}
	if data then
		for _, effect in ipairs(data.effects) do
			local remaining = effect.expiresAt - now
			if remaining > 0 and remaining < duration then boundaries[#boundaries + 1] = remaining end
			if remaining < profile.expiresIn then profile.expiresIn, profile.modifier = math.max(0, remaining), effect.name end
		end
	end
	table.sort(boundaries)
	local signature = {("speed:%.2f"):format(speed)}
	for i = 1, #boundaries - 1 do
		local from, untilTime = boundaries[i], boundaries[i + 1]
		if untilTime > from then
			local nominal, minimum, maximum, known = speed, speed, speed, not data or data.complete
			local observed = data and data.samples[data.context .. "//" .. data.key]
			if observed and observed.minimum ~= observed.maximum then
				minimum, maximum, known = math.min(speed, observed.minimum), math.max(speed, observed.maximum), false
			end
			local tokens, expired, renewable = {}, false, false
			if data then
				for _, effect in ipairs(data.effects) do
					if effect.expiresAt <= now + from + 0.0001 then
						expired = true
						if effect.renewable then renewable = true end
					else tokens[#tokens + 1] = effect.token end
				end
				if expired then
					local key = data.context .. "//" .. table.concat(tokens, "|")
					local measured = data.samples[key]
					if measured and now - measured.at <= 8 and data.complete then
						nominal, minimum, maximum = measured.speed, measured.minimum, measured.maximum
						known = not renewable and minimum == maximum
						if renewable then minimum, maximum = math.min(minimum, speed), math.max(maximum, speed) end
					else
						-- No invented per-spell coefficient: retain current speed as nominal,
						-- and carry all recently observed compatible speeds as alternatives.
						known = false
						for _, sample in pairs(data.samples) do
							if sample.context == data.context and now - sample.at <= 8 then
								minimum, maximum = math.min(minimum, sample.minimum), math.max(maximum, sample.maximum)
							end
						end
					end
				end
			end
			local dt = untilTime - from
			profile.distance = profile.distance + nominal * dt
			profile.minimumDistance = profile.minimumDistance + minimum * dt
			profile.maximumDistance = profile.maximumDistance + maximum * dt
			profile.endSpeed = nominal
			profile.active = profile.active or expired
			if not known then profile.unresolved = profile.unresolved + 1 end
			profile.intervals[#profile.intervals + 1] = {from = from, untilTime = untilTime, speed = nominal, known = known}
			signature[#signature + 1] = ("%.3f:%.2f:%.2f:%.2f:%s"):format(dt, nominal, minimum, maximum, tostring(known))
		end
	end
	profile.confidence = profile.unresolved == 0 and 1 or 0.5
	profile.baselineStat = profile.endSpeed
	profile.signature = table.concat(signature, ";")
	return profile
end

local function readEnemy(enemy, now, chronoFields)
	local index = Entity.GetIndex(enemy)
	local position = copyPoint(Entity.GetAbsOrigin(enemy))
	local teleportModifier = NPC.GetModifier(enemy, "modifier_teleporting")
	if teleportModifier then
		local teleportRemaining = modifierRemaining(teleportModifier, now)
		if teleportRemaining > 0 then
			helpers.quarantineTeleportMotion(index, now + teleportRemaining + (cfg.teleportMotionQuarantine or 0.55), "teleport_visible")
		end
	end
	local nativeMoving = NPC.IsRunning(enemy)
	local velocity = updateMotion(index, position, now, NPC.GetMoveSpeed(enemy), nativeMoving, "observed")
	local liveVelocity = helpers.readEntityVelocity(enemy)
	local moving = nativeMoving or length2D(velocity) >= 20 or liveVelocity and length2D(liveVelocity) >= 20
	local turningOk, turning = pcall(NPC.IsTurning, enemy)
	turning = turningOk and turning == true
	local modifiers = {}
	local modifierCreatedAt = {}
	local modifierExpiresAt = {}
	local disabledRemaining = helpers.immobileRemaining(enemy)
	local cycloneRemaining = 0
	local teleporting = false
	local teleportRemaining = 0
	for _, modifier in ipairs(NPC.GetModifiers(enemy)) do
		local name = Modifier.GetName(modifier)
		local remaining = modifierRemaining(modifier, now)
		modifiers[name] = remaining
		modifierCreatedAt[name] = Modifier.GetCreationTime(modifier)
		modifierExpiresAt[name] = now + math.max(0, remaining)
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
	local result = {
		entity = enemy,
		index = index,
		alive = Entity.IsAlive(enemy),
		visible = NPC.IsVisible(enemy),
		dormant = Entity.IsDormant(enemy),
		position = position,
		velocity = velocity,
		recentVelocity = track and copyPoint(track.recentVelocity or velocity) or copyPoint(velocity),
		instantVelocity = track and copyPoint(track.instantVelocity or velocity) or copyPoint(velocity),
		liveVelocity = liveVelocity and copyPoint(liveVelocity) or nil,
		recentMotionConfidence = track and track.recentConfidence or 0,
		turnRate = track and track.turnRate or 0,
		acceleration = track and track.acceleration or 0,
		nativeMoving = nativeMoving,
		turning = turning,
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
		modifierCreatedAt = modifierCreatedAt,
		modifierExpiresAt = modifierExpiresAt,
		disabledUntil = now + disabledRemaining,
		controlEndsAt = cycloneRemaining > 0 and now + cycloneRemaining or 0,
		controlPosition = cycloneRemaining > 0 and copyPoint(position) or nil,
		fogProjected = false,
		fogAge = 0,
	}
	-- v71: record stat-speed + modifier state while the target is actually visible.  The predictor
	-- can then model a known slow/buff expiry without hard-coding the modifier name.
	result.sunFlightBlockReason = helpers.sunPriority.flightBlockReason(result)
	result.sunFlightChecked = true
	helpers.observeSunSpeedState(result, now)
	track = state.motion[index]
	-- Keep only the last VISIBLE state. Dormant/live hidden entity values are deliberately ignored.
	if track then
		track.lastVisibleAt = now
		track.lastVisibleEnemy = result
		track.fogExpiredLogged = false
	end
	return result
end

function helpers.fogEnemyFromTrack(enemy, now)
	local index = Entity.GetIndex(enemy)
	local track = state.motion[index]
	local base = track and track.lastVisibleEnemy or nil
	local seenAt = track and track.lastVisibleAt or nil
	if not base or not seenAt then return nil end
	local age = now - seenAt
	if age < 0 or age > cfg.fogRouteTTL then
		if age > cfg.fogRouteTTL and not track.fogExpiredLogged then
			logDebug("FOG TRACK", ("target=%d expired age=%.2f"):format(index, age))
			track.fogExpiredLogged = true
		end
		return nil
	end
	local ghost = {}
	for key, value in pairs(base) do ghost[key] = value end
	ghost.entity = enemy
	ghost.visible = false
	ghost.dormant = true
	ghost.fogProjected = true
	ghost.fogAge = age
	-- v71: modifier remaining times continue to count down in fog; do not freeze last-visible durations.
	ghost.modifiers = {}
	for name, remaining in pairs(base.modifiers or {}) do
		local expiresAt = base.modifierExpiresAt and base.modifierExpiresAt[name] or seenAt + math.max(0, remaining or 0)
		ghost.modifiers[name] = math.max(0, expiresAt - now)
	end
	ghost.modifierCreatedAt = base.modifierCreatedAt
	ghost.modifierExpiresAt = base.modifierExpiresAt
	local tpExpiresAt = base.modifierExpiresAt and base.modifierExpiresAt.modifier_teleporting or nil
	ghost.teleportRemaining = tpExpiresAt and math.max(0, tpExpiresAt - now) or 0
	ghost.teleporting = ghost.teleportRemaining > 0
	ghost.moveSpeed = helpers.sunProjectedMoveSpeed(index, base.moveSpeed or 0, now)

	-- v59: fog is not a second motion system. Advance the SAME state.motion track from its
	-- latest observed/projected point through GridNav, then feed that projected point back into
	-- updateMotion(). walkingSince/stableSince/routeSamples therefore live on one timeline.
	local projectionState = {}
	for key, value in pairs(base) do projectionState[key] = value end
	projectionState.position = track.visibilityState == "projected" and track.lastProjectedPosition
		and copyPoint(track.lastProjectedPosition) or copyPoint(base.position)
	projectionState.velocity = copyPoint(track.velocity or base.velocity)
	projectionState.recentVelocity = copyPoint(track.recentVelocity or projectionState.velocity)
	projectionState.instantVelocity = copyPoint(track.instantVelocity or projectionState.recentVelocity)
	projectionState.liveVelocity = nil
	projectionState.motionConfidence = track.confidence or base.motionConfidence
	projectionState.recentMotionConfidence = track.recentConfidence or base.recentMotionConfidence
	projectionState.turnRate = track.turnRate or base.turnRate or 0
	projectionState.acceleration = track.acceleration or base.acceleration or 0
	projectionState.moving = track.motionState == "runner" or base.moving == true
	projectionState.nativeMoving = projectionState.moving
	projectionState.moveSpeed = ghost.moveSpeed
	if track.lastProjectionTangent and length2D(track.lastProjectionTangent) > 0.5 then
		projectionState.facing = copyPoint(track.lastProjectionTangent)
	end
	local fogDirection = helpers.sunPriority and helpers.sunPriority.currentAimDirection
		and helpers.sunPriority.currentAimDirection(projectionState) or normalized2D(projectionState.velocity)
	local fogSpeed = math.max(length2D(projectionState.recentVelocity), length2D(projectionState.instantVelocity),
		length2D(projectionState.velocity), length2D(base.recentVelocity or base.velocity), length2D(base.instantVelocity or base.velocity))
	if (ghost.moveSpeed or 0) > 20 then fogSpeed = math.min(math.max(fogSpeed, ghost.moveSpeed * 0.92), ghost.moveSpeed * 1.03) end
	local fromAt = track.lastProjectedAt and track.lastProjectedAt > seenAt and track.lastProjectedAt or seenAt
	local stepAge = math.max(0, now - fromAt)
	local projectedMoving = projectionState.moving and fogSpeed > 40 and fogDirection and length2D(fogDirection) > 0.5
	local projection
	if projectedMoving then
		projection = helpers.sunTerrainProject(projectionState, fogDirection, fogSpeed * stepAge, cfg.sunTerrainLookahead)
		ghost.position = projection and projection.position and copyPoint(projection.position)
			or add(projectionState.position, scale(fogDirection, fogSpeed * stepAge))
		if projection and projection.tangent and length2D(projection.tangent) > 0.5 then
			track.lastProjectionTangent = copyPoint(projection.tangent)
			ghost.facing = copyPoint(projection.tangent)
		end
	else
		ghost.position = copyPoint(projectionState.position)
	end
	local projectedVelocity = updateMotion(index, ghost.position, now, ghost.moveSpeed or base.moveSpeed or 0, projectedMoving == true, "projected")
	ghost.velocity = copyPoint(projectedVelocity)
	ghost.recentVelocity = copyPoint(track.recentVelocity or projectedVelocity)
	ghost.instantVelocity = copyPoint(track.instantVelocity or ghost.recentVelocity)
	ghost.liveVelocity = nil
	ghost.nativeMoving = projectedMoving == true
	ghost.moving = track.motionState == "runner" or length2D(projectedVelocity) >= 20
	ghost.turnRate = track.turnRate or 0
	ghost.acceleration = track.acceleration or 0
	ghost.turning = math.abs(ghost.turnRate) > 0.08
	ghost.recentMotionConfidence = track.recentConfidence or 0

	-- v47: position remains a fog projection, but HP is not. This runtime continues to expose
	-- enemy hero HP through the entity/top hero bar while the hero is hidden, including the
	-- immediate Tornado landing change. Prefer that live value whenever it is sane; only
	-- fall back to last-visible HP + regen when the runtime truly withholds health.
	local okHp, liveHp = pcall(Entity.GetHealth, enemy)
	local okMax, liveMax = pcall(Entity.GetMaxHealth, enemy)
	local okRegen, liveRegen = pcall(NPC.GetHealthRegen, enemy)
	if okHp and okMax and type(liveHp) == "number" and type(liveMax) == "number" and liveHp >= 0 and liveMax > 0 then
		ghost.health = math.min(liveMax, liveHp)
		ghost.maxHealth = liveMax
		if okRegen and type(liveRegen) == "number" then ghost.healthRegen = liveRegen end
		ghost.healthSource = "entity_hidden_live"
	else
		ghost.health = math.min(base.maxHealth, base.health + math.max(0, base.healthRegen) * age)
		ghost.healthSource = "last_visible_regen"
	end
	local fogConfidenceScale = clamp(1 - 0.20 * age / math.max(0.01, cfg.fogRouteTTL), 0.72, 1)
	ghost.motionConfidence = math.max(0.45, (track.confidence or base.motionConfidence or 0) * fogConfidenceScale)
	ghost.recentMotionConfidence = math.max(0.25, (track.recentConfidence or 0) * fogConfidenceScale)
	ghost.movementDuration = track.walkingSince ~= math.huge and math.max(0, now - track.walkingSince) or 0
	ghost.stableDuration = track.stableSince ~= math.huge and math.max(0, now - track.stableSince) or 0
	ghost.idleDuration = track.idleSince ~= math.huge and math.max(0, now - track.idleSince) or 0
	return ghost
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
local function buildSnapshot()
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
	local levels = orbLevels(hero)
	local heroState = {
		entity = hero,
		index = Entity.GetIndex(hero),
		alive = Entity.IsAlive(hero),
		mana = NPC.GetMana(hero),
		maxMana = NPC.GetMaxMana(hero),
		position = position,
		silenced = NPC.IsSilenced(hero),
		stunned = NPC.IsStunned(hero),
		channeling = helpers.heroBusy(hero),
		inAbilityPhase = false,
		invisible = NPC.HasState(hero, Enum.ModifierState.MODIFIER_STATE_INVISIBLE),
		orbLevels = levels,
		upgrades = {
			scepterChoice = NPC.HasScepter(hero) and upgradeChoice(NPC.GetScepterUpgradeID(hero)) or nil,
		},
	}

	local observedInvoked, activeInvokedHandles, activeInvokedIndexes = resolveSlotAbilities(hero)
	local actions = {}
	for _, id in ipairs(allActionIds) do
		local canonicalId = canonicalSpell(id)
		local liveHandle = activeInvokedHandles[canonicalId] or bindings.abilities[id]
		actions[id] = readAction(id, liveHandle, hero, levels)
		actions[id].activeSlotIndex = activeInvokedIndexes[canonicalId]
		heroState.inAbilityPhase = heroState.inAbilityPhase or actions[id].inAbilityPhase
	end
	-- Hard truth only: a spell is invoked only when it is physically present in D/F right now.
	-- No assumed/published state is allowed to bypass EEE -> Invoke.
	local invoked = arrayCopy(observedInvoked)
	state.assumedInvoked = arrayCopy(observedInvoked)
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
		local enemyIndex = Entity.GetIndex(enemy)
		if not Entity.IsSameTeam(hero, enemy) and Entity.IsAlive(enemy) and not NPC.IsIllusion(enemy) then
			if not Entity.IsDormant(enemy) and NPC.IsVisible(enemy) then
				enemies[#enemies + 1] = readEnemy(enemy, now, chronoFields)
			else
				local fogEnemy = helpers.fogEnemyFromTrack(enemy, now)
				if fogEnemy then
					enemies[#enemies + 1] = fogEnemy
				elseif state.motion[enemyIndex] and state.motion[enemyIndex].lastVisibleAt
					and now - state.motion[enemyIndex].lastVisibleAt > cfg.fogRouteTTL
				then
					state.motion[enemyIndex] = nil
				end
			end
		else
			state.motion[enemyIndex] = nil
		end
	end
	local sunUnits = {}
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
	for _, unit in ipairs(units) do
		local alive = Entity.IsAlive(unit)
		local name = alive and NPC.GetUnitName(unit) or nil
		if tormentors and name == "npc_dota_miniboss" then
			local tormentor = helpers.readTormentor(unit, now)
			if tormentor then tormentors[#tormentors + 1] = tormentor end
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
			local fieldVelocity = helpers.readEntityVelocity(unit)
			sunUnits[#sunUnits + 1] = {
				index = Entity.GetIndex(unit),
				position = copyPoint(Entity.GetAbsOrigin(unit)),
				velocity = moving and fieldVelocity and length2D(fieldVelocity) >= 20 and fieldVelocity
					or moving and scale(Entity.GetRotation(unit):GetForward(), NPC.GetMoveSpeed(unit)) or {x = 0, y = 0, z = 0},
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
		latency = latency,
		hero = heroState,
		invoke = invokeState,
		actions = actions,
		enemies = enemies,
		sunUnits = sunUnits,
		roshan = roshan,
		tormentors = tormentors,
	}
end


for _, id in ipairs(itemIds) do
	definitions[id].id = id
	definitions[id].projectileSpeed = definitions[id].projectileSpeed or 0
	definitions[id].fixedDelay = definitions[id].fixedDelay or 0
	definitions[id].icon = ("panorama/images/items/%s_png.vtex_c"):format((id:gsub("^item_", "")))
end

allActionIds = {}
for _, id in ipairs(spellIds) do allActionIds[#allActionIds + 1] = id end
for _, id in ipairs(itemIds) do allActionIds[#allActionIds + 1] = id end

function helpers.loadMovingSunBlocks()
	local blocked = {}
	local saved = Config.ReadString(cfg.configName, "moving_sun_blocks", "")
	-- v37 keys are portrait/player specific (team + team slot + hero name). Legacy bare hero-name
	-- entries are intentionally ignored: with duplicate heroes one old key would block every portrait.
	for key in saved:gmatch("[^,%s]+") do
		if key:match("^t%d+s%d+:") then blocked[key] = true end
	end
	return blocked
end

function helpers.saveMovingSunBlocks()
	local keys = {}
	for key, blocked in pairs(state.movingSunBlocks or {}) do
		if blocked then keys[#keys + 1] = key end
	end
	table.sort(keys)
	Config.WriteString(cfg.configName, "moving_sun_blocks", table.concat(keys, ","))
end

function helpers.movingSunPortraitKey(entity, teamSlot, heroName)
	if not entity then return nil end
	local team = Entity.GetTeamNum(entity)
	local name = heroName
	if not name then
		local ok, value = pcall(NPC.GetUnitName, entity)
		if ok and type(value) == "string" and value ~= "" then name = value end
	end
	if teamSlot == nil then
		local entityIndex = Entity.GetIndex(entity)
		for _, player in ipairs(Players.GetAll()) do
			local assigned = Player.GetAssignedHero(player)
			if assigned and Entity.GetIndex(assigned) == entityIndex then
				teamSlot = Player.GetPlayerTeamSlot(player)
				break
			end
		end
	end
	if teamSlot == nil or not name or name == "" then return nil end
	return ("t%ds%d:%s"):format(team or -1, teamSlot, name)
end

function helpers.movingSunBlockKey(enemy)
	if not enemy or not enemy.entity then return nil end
	local cached = state.movingSunBlockEntityKeys and state.movingSunBlockEntityKeys[enemy.index]
	if cached then return cached end
	return helpers.movingSunPortraitKey(enemy.entity, nil, nil)
end

function helpers.movingSunBlockPolicyApplies(enemy, settings)
	if not enemy then return false end
	-- v85: this policy is evaluated ONLY after a portrait X exists for this exact hero/player.
	-- X always blocks ordinary moving Auto SS. The nested positive switch decides only whether
	-- that same X still blocks an ordinary standing Auto SS; without X it has zero effect.
	local recent = enemy.recentVelocity or enemy.velocity or {x = 0, y = 0, z = 0}
	local instant = enemy.instantVelocity or recent
	local live = enemy.liveVelocity or {x = 0, y = 0, z = 0}
	local movingSpeed = math.max(length2D(enemy.velocity or {x = 0, y = 0, z = 0}), length2D(recent), length2D(instant), length2D(live))
	local moving = enemy.nativeMoving == true or enemy.moving == true and movingSpeed >= 20
	if moving then return true end
	return not (settings and settings.xStandingSun == true)
end

function helpers.movingSunBlocked(enemy, settings)
	local blockKey = helpers.movingSunBlockKey(enemy)
	if not blockKey or not state.movingSunBlocks or not state.movingSunBlocks[blockKey] then return false end
	return helpers.movingSunBlockPolicyApplies(enemy, settings)
end


function helpers.sunPortraitStat(blockKey)
	if not blockKey then return nil end
	state.sunPortraitStats = state.sunPortraitStats or {}
	local stat = state.sunPortraitStats[blockKey]
	if not stat then
		stat = {
			misses = 0,
			sunResult = nil, sunResultAt = 0,
			cataResult = nil, cataResultAt = 0, cataReadyAt = 0,
		}
		state.sunPortraitStats[blockKey] = stat
	end
	return stat
end

function helpers.sunPortraitDisplayResult(stat, now)
	if not stat then return nil, nil end
	now = now or GameRules.GetGameTime()
	local sunResult, sunAt = stat.sunResult, stat.sunResultAt or 0
	local cataResult = (stat.cataReadyAt or 0) > now and stat.cataResult or nil
	local cataAt = cataResult and (stat.cataResultAt or 0) or 0
	if cataResult and cataAt >= sunAt then return cataResult, "cataclysm" end
	if sunResult then return sunResult, "sun" end
	return nil, nil
end

function helpers.beginSunPortraitShot(target, snapshot, issuedAt, shotKind, castPosition, autoSettings)
	if not target or not target.index then return nil end
	local blockKey = state.movingSunBlockEntityKeys and state.movingSunBlockEntityKeys[target.index] or nil
	if not blockKey then
		local okKey, value = pcall(helpers.movingSunBlockKey, target)
		if okKey then blockKey = value end
	end
	if not blockKey then
		logDebug("SUN RESULT", ("arm_skipped target=%d reason=no_portrait_key"):format(target.index or -1))
		return nil
	end
	local stat = helpers.sunPortraitStat(blockKey)
	if not stat then return nil end
	local action = snapshot and snapshot.actions and snapshot.actions.sun_strike or nil
	local modeledCommand = math.max(0, action and action.castPoint or 0.05) + math.max(0, snapshot and snapshot.latency or 0)
	local measuredCommand = math.max(0, state.sunCommandDelayMedianObserved or 0)
	local commandDelay = measuredCommand > 0 and measuredCommand or modeledCommand
	local fixedDelay = definitions.sun_strike and definitions.sun_strike.fixedDelay or 1.7
	local impactAt = issuedAt + commandDelay + math.max(0, fixedDelay)
	local recent = target.recentVelocity or target.velocity or {x = 0, y = 0, z = 0}
	local instant = target.instantVelocity or recent
	local live = target.liveVelocity or {x = 0, y = 0, z = 0}
	local movingSpeed = math.max(length2D(target.velocity or {x = 0, y = 0, z = 0}), length2D(recent), length2D(instant), length2D(live))
	local movingAtCast = target.nativeMoving == true or target.moving == true and movingSpeed >= 20
	local xSelected = state.movingSunBlocks and state.movingSunBlocks[blockKey] == true
	local xStandingSun = autoSettings and autoSettings.xStandingSun == true
	local counterEnabled = autoSettings and autoSettings.countSunMisses == true
	local normalAuto = shotKind == "sun_strike"
	local countMiss = counterEnabled and normalAuto and (movingAtCast or not xSelected or xStandingSun)
	state.sunOutcomeShot = {
		targetIndex = target.index, blockKey = blockKey, issuedAt = issuedAt,
		impactAt = impactAt, resolveDeadline = impactAt + 0.45,
		kind = shotKind or "sun_strike",
		position = castPosition and copyPoint(castPosition) or target.position and copyPoint(target.position) or nil,
		movingAtCast = movingAtCast, xSelected = xSelected, xStandingSun = xStandingSun, countMiss = countMiss,
		hit = false, killed = false, invalidated = false,
	}
	state.sunOutcomeCooldownSeen = false
	state.sunCooldownTracking = true
	stat.sunResult = nil
	stat.sunResultAt = 0
	logDebug("SUN RESULT", ("pending target=%d key=%s kind=%s moving=%s xSelected=%s xStandingSun=%s countMiss=%s impact=%.3f"):format(
		target.index, tostring(blockKey), tostring(state.sunOutcomeShot.kind), tostring(movingAtCast),
		tostring(xSelected), tostring(xStandingSun), tostring(countMiss), impactAt))
	return state.sunOutcomeShot
end

function helpers.sunPortraitKeyForEntity(entity)
	if not entity then return nil end
	local index = Entity.GetIndex(entity)
	local cached = state.movingSunBlockEntityKeys and state.movingSunBlockEntityKeys[index] or nil
	if cached then return cached end
	local okKey, key = pcall(helpers.movingSunPortraitKey, entity, nil, nil)
	return okKey and key or nil
end

function helpers.setSunPortraitEntityResult(entity, result, now, kind)
	if not entity then return false end
	local blockKey = helpers.sunPortraitKeyForEntity(entity)
	if not blockKey then return false end
	local stat = helpers.sunPortraitStat(blockKey)
	if not stat then return false end
	if stat.sunResult == "kill" and result ~= "kill" then return true end
	stat.sunResult = result
	stat.sunResultAt = now or GameRules.GetGameTime()
	logDebug("SUN RESULT", ("target=%d result=%s kind=%s countMiss=false misses=%d"):format(
		Entity.GetIndex(entity), tostring(result), tostring(kind or "observed_sun"), stat.misses or 0))
	return true
end

function helpers.setCataclysmPortraitKeyResult(blockKey, result, now, kind)
	if not blockKey then return false end
	local stat = helpers.sunPortraitStat(blockKey)
	if not stat then return false end
	if stat.cataResult == "kill" and result ~= "kill" then return true end
	stat.cataResult = result
	stat.cataResultAt = now or GameRules.GetGameTime()
	stat.cataReadyAt = math.max(stat.cataReadyAt or 0, state.cataclysmResultReadyAt or 0)
	logDebug("CATA RESULT", ("key=%s result=%s kind=%s"):format(tostring(blockKey), tostring(result), tostring(kind or "cataclysm")))
	return true
end

function helpers.cataclysmPortraitTargets()
	local targets = {}
	if not state.hero then return targets end
	for _, player in ipairs(Players.GetAll()) do
		local hero = Player.GetAssignedHero(player)
		if hero and Entity.IsHero(hero) and not Entity.IsSameTeam(state.hero, hero) then
			local index = Entity.GetIndex(hero)
			local key = helpers.sunPortraitKeyForEntity(hero)
			if key and not targets[index] then targets[index] = {index = index, key = key} end
		end
	end
	return targets
end

function helpers.beginCataclysmPortraitWindow(snapshot, issuedAt, shotKind)
	if not snapshot or not state.hero then return nil end
	-- A new real Cataclysm supersedes the previous Cata result set. The new five targets start neutral
	-- and receive MISS/HIT/KILL after this cast resolves.
	if (state.cataclysmResultReadyAt or 0) > 0 then helpers.clearCataclysmPortraitResults("new Cataclysm cast") end
	local action = snapshot.actions and snapshot.actions.cataclysm or nil
	local modeledCommand = math.max(0, action and action.castPoint or 0.05) + math.max(0, snapshot.latency or 0)
	local measuredCommand = math.max(0, state.sunCommandDelayMedianObserved or 0)
	local commandDelay = measuredCommand > 0 and measuredCommand or modeledCommand
	local fixedDelay = definitions.sun_strike and definitions.sun_strike.fixedDelay or 1.7
	local impactAt = issuedAt + commandDelay + math.max(0, fixedDelay)
	local cooldown = action and action.specials and tonumber(action.specials.cataclysm_cooldown) or 0
	if not cooldown or cooldown <= 0 then cooldown = 60 end
	local readyAt = issuedAt + cooldown
	local targets = helpers.cataclysmPortraitTargets()
	local targetCount = 0
	for _, target in pairs(targets) do
		targetCount = targetCount + 1
		local stat = helpers.sunPortraitStat(target.key)
		if stat then
			stat.cataResult = nil
			stat.cataResultAt = 0
			stat.cataReadyAt = readyAt
		end
	end
	state.cataclysmResultReadyAt = readyAt
	state.cataclysmCooldownProbeUntil = issuedAt + 1.25
	state.cataclysmCooldownBase = cooldown
	state.sunOutcomeCataclysms = state.sunOutcomeCataclysms or {}
	local window = {
		issuedAt = issuedAt, impactAt = impactAt, resolveDeadline = impactAt + 0.65,
		kind = shotKind or "cataclysm", hits = {}, results = {}, targets = targets,
		readyAt = readyAt, resolved = false,
	}
	state.sunOutcomeCataclysms[#state.sunOutcomeCataclysms + 1] = window
	logDebug("CATA RESULT", ("pending kind=%s impact=%.3f cooldown=%.2f targets=%d windows=%d"):format(
		tostring(window.kind), impactAt, cooldown, targetCount, #state.sunOutcomeCataclysms))
	return window
end

function helpers.cataclysmPortraitEventWindow(now)
	for i = #(state.sunOutcomeCataclysms or {}), 1, -1 do
		local window = state.sunOutcomeCataclysms[i]
		if not window.resolved and now + 0.12 >= (window.impactAt or now) and now <= (window.resolveDeadline or now) then return window end
	end
	return nil
end

function helpers.observeCataclysmPortraitDamage(data)
	if not data or not data.target or (data.damage or 0) <= 0 or not state.hero then return end
	if not Entity.IsHero(data.target) or Entity.IsSameTeam(state.hero, data.target) then return end
	local now = GameRules.GetGameTime()
	local window = helpers.cataclysmPortraitEventWindow(now)
	if not window then return end
	local ours = false
	if data.ability then
		local okName, abilityName = pcall(Ability.GetName, data.ability)
		if not okName or abilityName ~= "invoker_sun_strike" then return end
		ours = data.source and helpers.sunPriority.sameHero(data.source, state.hero) or false
		if not ours then ours = helpers.sunPriority.abilityOwnedByHero(data.ability, state.hero) end
	else
		ours = data.source and helpers.sunPriority.sameHero(data.source, state.hero) or false
	end
	if not ours then return end
	local index = Entity.GetIndex(data.target)
	local target = window.targets and window.targets[index] or nil
	if not target then return end
	window.hits[index] = now
	local alive = Entity.IsAlive(data.target)
	local health = Entity.GetHealth(data.target)
	local result = (not alive or health <= 0) and "kill" or "hit"
	window.results[index] = result
	helpers.setCataclysmPortraitKeyResult(target.key, result, now, window.kind)
end

function helpers.observeCataclysmPortraitDeath(data)
	if not data or not data.target or not state.hero then return end
	local index = Entity.GetIndex(data.target)
	local now = GameRules.GetGameTime()
	for i = #(state.sunOutcomeCataclysms or {}), 1, -1 do
		local window = state.sunOutcomeCataclysms[i]
		local target = window.targets and window.targets[index] or nil
		if target and now <= (window.resolveDeadline or 0) then
			local ours = false
			if data.ability then
				local okName, abilityName = pcall(Ability.GetName, data.ability)
				if okName and abilityName == "invoker_sun_strike" then
					ours = data.source and helpers.sunPriority.sameHero(data.source, state.hero) or false
					if not ours then ours = helpers.sunPriority.abilityOwnedByHero(data.ability, state.hero) end
				end
			end
			local hitAt = window.hits and window.hits[index] or nil
			if ours or hitAt and math.abs(now - hitAt) <= 0.12 then
				window.results[index] = "kill"
				helpers.setCataclysmPortraitKeyResult(target.key, "kill", now, window.kind)
				return
			end
		end
	end
end

function helpers.finalizeCataclysmPortraitWindow(window, now)
	if not window or window.resolved then return end
	window.resolved = true
	local kills, hits, misses, total = 0, 0, 0, 0
	for index, target in pairs(window.targets or {}) do
		total = total + 1
		local result = window.results and window.results[index] or nil
		if not result then
			result = "miss"
			window.results[index] = result
			helpers.setCataclysmPortraitKeyResult(target.key, result, now, window.kind)
		end
		if result == "kill" then kills = kills + 1
		elseif result == "hit" then hits = hits + 1
		else misses = misses + 1 end
	end
	logDebug("CATA RESULT", ("summary kind=%s total=%d kill=%d hit=%d miss=%d ready_in=%.2f"):format(
		tostring(window.kind), total, kills, hits, misses, math.max(0, (window.readyAt or now) - now)))
end

function helpers.setSunPortraitResult(result, now)
	local shot = state.sunOutcomeShot
	if not shot or not shot.blockKey then return end
	local stat = helpers.sunPortraitStat(shot.blockKey)
	if not stat then return end
	if stat.sunResult == result then return end
	if stat.sunResult == "kill" and result ~= "kill" then return end
	if result == "miss" and shot.countMiss == true and not shot.missCounted then
		stat.misses = (stat.misses or 0) + 1
		shot.missCounted = true
	end
	stat.sunResult = result
	stat.sunResultAt = now or GameRules.GetGameTime()
	logDebug("SUN RESULT", ("target=%d result=%s kind=%s moving=%s countMiss=%s misses=%d"):format(
		shot.targetIndex or -1, tostring(result), tostring(shot.kind), tostring(shot.movingAtCast),
		tostring(shot.countMiss == true), stat.misses or 0))
end

function helpers.sunPortraitFallbackEventMatches(shot, target, source, now)
	if not shot or not target or not shot.position or not state.sunOutcomeCooldownSeen then return false end
	if now + 0.05 < (shot.impactAt or now) or now > (shot.resolveDeadline or now) then return false end
	if source and state.hero and not helpers.sunPriority.sameHero(source, state.hero) then return false end
	local okPos, livePos = pcall(Entity.GetAbsOrigin, target)
	if not okPos or not livePos then return false end
	return distance2D(copyPoint(livePos), shot.position) <= cfg.sunRadius + 24
end

function helpers.observeSunPortraitDamage(data)
	if not data or not data.target or (data.damage or 0) <= 0 then return end
	local now = GameRules.GetGameTime()
	local shot = state.sunOutcomeShot
	if not shot or shot.invalidated then
		local unbound = state.sunOutcomeUnbound
		if not unbound or now + 0.08 < (unbound.impactAt or now) or now > (unbound.resolveDeadline or now) then return end
		local ours = false
		if data.ability then
			local okName, abilityName = pcall(Ability.GetName, data.ability)
			if not okName or abilityName ~= "invoker_sun_strike" then return end
			ours = state.hero and data.source and helpers.sunPriority.sameHero(data.source, state.hero) or false
			if not ours and state.hero then ours = helpers.sunPriority.abilityOwnedByHero(data.ability, state.hero) end
		else
			ours = state.hero and data.source and helpers.sunPriority.sameHero(data.source, state.hero) or false
		end
		if not ours or not Entity.IsHero(data.target) or Entity.IsSameTeam(state.hero, data.target) then return end
		unbound.hit = true
		unbound.targetIndex = Entity.GetIndex(data.target)
		local alive = Entity.IsAlive(data.target)
		local health = Entity.GetHealth(data.target)
		helpers.setSunPortraitEntityResult(data.target, (not alive or health <= 0) and "kill" or "hit", now, "cooldown_observed_sun")
		return
	end
	if Entity.GetIndex(data.target) ~= shot.targetIndex then return end
	local ours = false
	if data.ability then
		local okName, abilityName = pcall(Ability.GetName, data.ability)
		if not okName or abilityName ~= "invoker_sun_strike" then return end
		ours = state.hero and data.source and helpers.sunPriority.sameHero(data.source, state.hero) or false
		if not ours and state.hero then ours = helpers.sunPriority.abilityOwnedByHero(data.ability, state.hero) end
	else
		ours = helpers.sunPortraitFallbackEventMatches(shot, data.target, data.source, now)
		if ours then
			logDebug("SUN RESULT", ("target=%d hit_fallback=ability_nil damage=%.0f"):format(shot.targetIndex or -1, data.damage or 0))
		end
	end
	if not ours then return end
	shot.hit = true
	shot.hitAt = now
	local alive = Entity.IsAlive(data.target)
	local health = Entity.GetHealth(data.target)
	shot.actualDamage = data.damage or 0
	shot.healthAfter = health
	logDebug("SUN DAMAGE", ("target=%d damage=%.0f hpAfter=%.0f alive=%s expectedImpact=%.3f event=%.3f"):format(
		shot.targetIndex or -1, shot.actualDamage, health or -1, tostring(alive), shot.impactAt or now, now))
	if not alive or health <= 0 then
		shot.killed = true
		helpers.setSunPortraitResult("kill", now)
	else
		helpers.setSunPortraitResult("hit", now)
	end
end

function helpers.observeSunPortraitDeath(data)
	local shot = state.sunOutcomeShot
	if not shot or not data or not data.target or Entity.GetIndex(data.target) ~= shot.targetIndex then return end
	local now = GameRules.GetGameTime()
	local ours = false
	if data.ability then
		local okName, abilityName = pcall(Ability.GetName, data.ability)
		if okName and abilityName == "invoker_sun_strike" then
			ours = state.hero and data.source and helpers.sunPriority.sameHero(data.source, state.hero) or false
			if not ours and state.hero then ours = helpers.sunPriority.abilityOwnedByHero(data.ability, state.hero) end
		end
	end
	if not ours and shot.hit and shot.hitAt and math.abs(now - shot.hitAt) <= 0.05 then ours = true end
	if ours or shot.killed then
		shot.hit, shot.killed = true, true
		helpers.setSunPortraitResult("kill", now)
	elseif not shot.hit and now + 0.05 < (shot.impactAt or now) then
		shot.invalidated = true
		logDebug("SUN RESULT", ("target=%d invalidated=death_before_impact"):format(shot.targetIndex or -1))
	elseif shot.hit then
		helpers.setSunPortraitResult("hit", now)
	end
end

function helpers.clearCataclysmPortraitResults(reason)
	for _, stat in pairs(state.sunPortraitStats or {}) do
		stat.cataResult = nil
		stat.cataResultAt = 0
		stat.cataReadyAt = 0
	end
	state.cataclysmResultReadyAt = 0
	state.cataclysmCooldownProbeUntil = 0
	state.cataclysmCooldownBase = 0
	logDebug("CATA RESULT", tostring(reason or "Cataclysm ready") .. " -> Cata portrait colors neutral")
end

function helpers.updateSunPortraitOutcome(snapshot)
	local now = snapshot and snapshot.now or GameRules.GetGameTime()
	if state.sunOutcomeCataclysms then
		local active = {}
		for _, window in ipairs(state.sunOutcomeCataclysms) do
			if not window.resolved and now >= (window.resolveDeadline or math.huge) then
				helpers.finalizeCataclysmPortraitWindow(window, now)
			end
			if not window.resolved then active[#active + 1] = window end
		end
		state.sunOutcomeCataclysms = active
	end
	local unbound = state.sunOutcomeUnbound
	if unbound and now >= (unbound.resolveDeadline or math.huge) then
		if not unbound.hit then
			logDebug("SUN RESULT", ("unbound observed Sun resolved without damage position=%.0f,%.0f -> no portrait guessed"):format(
				unbound.position and unbound.position.x or 0, unbound.position and unbound.position.y or 0))
		end
		state.sunOutcomeUnbound = nil
	end
	local shot = state.sunOutcomeShot
	if shot and now >= (shot.resolveDeadline or math.huge) then
		if not shot.invalidated and not shot.hit then
			if state.sunOutcomeCooldownSeen and shot.impactVisible == true then
				helpers.setSunPortraitResult("miss", now)
			elseif state.sunOutcomeCooldownSeen then
				logDebug("SUN RESULT", ("target=%d result=unknown reason=impact_not_visible -> no miss counted"):format(shot.targetIndex or -1))
			else
				logDebug("SUN RESULT", ("target=%d cancelled=no_confirmed_cooldown"):format(shot.targetIndex or -1))
			end
		end
		state.sunOutcomeShot = nil
	end
	if shot and snapshot and math.abs(now - (shot.impactAt or -math.huge)) <= 0.10 then
		for _, enemy in ipairs(snapshot.enemies or {}) do
			if enemy.index == shot.targetIndex then
				shot.impactVisible = enemy.visible == true and not enemy.dormant and not enemy.fogProjected
				break
			end
		end
	end
	local action = snapshot and snapshot.actions and snapshot.actions.sun_strike or nil
	if state.sunCooldownTracking and action and action.exists then
		if action.cooldown > 0.05 then
			state.sunOutcomeCooldownSeen = true
		elseif state.sunOutcomeCooldownSeen then
			for _, stat in pairs(state.sunPortraitStats or {}) do
				stat.sunResult = nil
				stat.sunResultAt = 0
			end
			state.sunOutcomeCooldownSeen = false
			state.sunCooldownTracking = false
			logDebug("SUN RESULT", "SS ready -> SS portrait colors cleared")
		end
	end
	-- Confirm the Cataclysm color lifetime from the live post-cast cooldown when the runtime exposes the
	-- long Cataclysm cooldown on the shared Sun handle. Reject short ordinary-SS cooldown values and
	-- retain the live cataclysm_cooldown special as the fallback.
	if (state.cataclysmCooldownProbeUntil or 0) >= now and action and action.exists and action.cooldown > 0.05
		and action.cooldown >= math.max(1, (state.cataclysmCooldownBase or 0) * 0.45)
	then
		local confirmedReadyAt = now + action.cooldown
		state.cataclysmResultReadyAt = confirmedReadyAt
		for _, stat in pairs(state.sunPortraitStats or {}) do
			if (stat.cataReadyAt or 0) > 0 then stat.cataReadyAt = confirmedReadyAt end
		end
		state.cataclysmCooldownProbeUntil = 0
		logDebug("CATA RESULT", ("cooldown_confirmed remaining=%.2f"):format(action.cooldown))
	end
	if (state.cataclysmResultReadyAt or 0) > 0 and now >= state.cataclysmResultReadyAt then
		helpers.clearCataclysmPortraitResults("Cataclysm cooldown ready")
	end
end

function helpers.manualSunTargetAt(position, snapshot)
	if not position or not snapshot then return nil end
	local best, bestDistance = nil, math.huge
	for _, enemy in ipairs(snapshot.enemies or {}) do
		if enemy.alive and enemy.position then
			local currentDistance = distance2D(enemy.position, position)
			local predictedDistance = math.huge
			local okPrediction, prediction = pcall(predictIntercept, snapshot, "sun_strike", enemy, snapshot.now, enemy.motionConfidence)
			if okPrediction and prediction and prediction.position then
				predictedDistance = distance2D(prediction.position, position)
			end
			local distance = math.min(currentDistance, predictedDistance)
			if distance < bestDistance then best, bestDistance = enemy, distance end
		end
	end
	-- A manual player can intentionally lead a moving hero. Compare both live and predicted positions,
	-- but keep the association bounded so an empty-ground Sun cannot invent a portrait target.
	if best and bestDistance <= cfg.sunRadius + 180 then return best, bestDistance end
	return nil, bestDistance
end

function helpers.recentSunOutcome(now, position)
	local shot = state.sunOutcomeShot
	if not shot or math.abs((shot.issuedAt or -math.huge) - now) > 0.80 then return false end
	if position and shot.position and distance2D(position, shot.position) > 96 then return false end
	return true
end

function helpers.recentCataclysmOutcome(now)
	for i = #(state.sunOutcomeCataclysms or {}), 1, -1 do
		local window = state.sunOutcomeCataclysms[i]
		if window and math.abs((window.issuedAt or -math.huge) - now) <= 0.80 then return true end
	end
	return false
end

function helpers.sunCastServerCursor()
	if not Humanizer or not Humanizer.GetServerCursorPos then return nil end
	local ok, pos = pcall(Humanizer.GetServerCursorPos)
	if not ok or not pos then return nil end
	return copyPoint(pos)
end

function helpers.observeExternalSunOrder(data, hero, now)
	if not data or not data.ability or not hero or not state.snapshot then return end
	if not Entity.RecursiveOwnedBy(data.ability, hero) then return end
	local okName, abilityName = pcall(Ability.GetName, data.ability)
	if not okName or abilityName ~= "invoker_sun_strike" then return end
	local snapshot = state.snapshot
	local action = snapshot.actions and snapshot.actions.sun_strike or nil
	if not action or not action.exists or action.cooldown > 0.05 then return end
	state.sunCastObserver = state.sunCastObserver or {}
	local observer = state.sunCastObserver
	observer.lastOrderAt = now
	if data.order == Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET then
		if snapshot.hero.upgrades.scepterChoice ~= "exort" then return end
		observer.lastOrderKind = "cataclysm"
		observer.lastOrderPosition = nil
		if helpers.recentCataclysmOutcome(now) then return end
		helpers.beginCataclysmPortraitWindow(snapshot, now, "external_cataclysm")
		logDebug("CATA RESULT", "external/player Cataclysm order observed")
		return
	end
	if data.order ~= Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION or not data.position then return end
	local position = copyPoint(data.position)
	observer.lastOrderKind = "sun"
	observer.lastOrderPosition = position
	if helpers.recentSunOutcome(now, position) then return end
	local target, distance = helpers.manualSunTargetAt(position, snapshot)
	if not target then
		logDebug("SUN RESULT", ("external/player Sun order observed but no portrait target near live/predicted cast point distance=%.0f"):format(distance or -1))
		return
	end
	helpers.beginSunPortraitShot(target, snapshot, now, "external_sun", position, readSettings().auto)
	logDebug("SUN RESULT", ("external/player Sun order observed target=%d distance=%.0f"):format(target.index or -1, distance or -1))
end

function helpers.observeAnySunCastState(snapshot)
	if not snapshot or not snapshot.actions then return end
	local action = snapshot.actions.sun_strike
	state.sunCastObserver = state.sunCastObserver or {}
	local observer = state.sunCastObserver
	if not action or not action.exists then
		observer.prevCooldown = nil
		observer.prevInPhase = false
		return
	end
	local now = snapshot.now or GameRules.GetGameTime()
	local cooldown = math.max(0, action.cooldown or 0)
	local inPhase = action.inAbilityPhase == true
	if cooldown <= 0.05 and (action.cooldownLength or 0) > 0 then
		observer.readyCooldownLength = action.cooldownLength
	end
	if inPhase and not observer.prevInPhase then
		observer.phasePosition = helpers.sunCastServerCursor()
		observer.phaseAt = now
	end
	local previous = observer.prevCooldown
	if previous ~= nil and previous <= 0.05 and cooldown > 0.05 then
		local cataSpecial = tonumber(action.specials and action.specials.cataclysm_cooldown) or 0
		local normalLength = math.max(0, observer.readyCooldownLength or 0)
		local longVsNormal = normalLength > 0 and cooldown > normalLength * 1.30
		local nearCataBase = cataSpecial > 0 and cooldown >= cataSpecial * 0.70
		local isCataclysm = snapshot.hero.upgrades.scepterChoice == "exort" and (longVsNormal or nearCataBase)
		observer.lastTransitionAt = now
		observer.lastTransitionKind = isCataclysm and "cataclysm" or "sun"
		if isCataclysm then
			if not helpers.recentCataclysmOutcome(now) then
				helpers.beginCataclysmPortraitWindow(snapshot, now, "cooldown_observed_cataclysm")
				logDebug("CATA RESULT", ("cooldown transition recovered Cataclysm cooldown=%.2f normal=%.2f cataBase=%.2f"):format(cooldown, normalLength, cataSpecial))
			else
				logDebug("CATA RESULT", ("cooldown transition confirmed tracked Cataclysm cooldown=%.2f"):format(cooldown))
			end
		else
			-- A cooldown transition is authoritative proof that some Sun Strike was really cast. If an order
			-- callback already armed the shot, only confirm its cooldown; otherwise recover the cast point
			-- from the recent order/ability-phase/server cursor and bind the nearest live/predicted hero.
			state.sunOutcomeCooldownSeen = true
			state.sunCooldownTracking = true
			if not helpers.recentSunOutcome(now, nil) then
				local position = nil
				if observer.lastOrderKind == "sun" and now - (observer.lastOrderAt or -math.huge) <= 1.25 then
					position = observer.lastOrderPosition and copyPoint(observer.lastOrderPosition) or nil
				end
				if not position and observer.phasePosition and now - (observer.phaseAt or -math.huge) <= 1.25 then
					position = copyPoint(observer.phasePosition)
				end
				if not position then position = helpers.sunCastServerCursor() end
				local target, distance = helpers.manualSunTargetAt(position, snapshot)
				if target then
					helpers.beginSunPortraitShot(target, snapshot, now, "cooldown_observed_sun", position, readSettings().auto)
					-- beginSunPortraitShot intentionally resets this; the transition we are handling already proves it.
					state.sunOutcomeCooldownSeen = true
					state.sunCooldownTracking = true
					logDebug("SUN RESULT", ("cooldown transition recovered Sun target=%d distance=%.0f cooldown=%.2f"):format(target.index or -1, distance or -1, cooldown))
				else
					local fixedDelay = definitions.sun_strike and definitions.sun_strike.fixedDelay or 1.7
					state.sunOutcomeUnbound = {
						issuedAt = now, impactAt = now + fixedDelay, resolveDeadline = now + fixedDelay + 0.60,
						position = position and copyPoint(position) or nil, hit = false,
					}
					logDebug("SUN RESULT", ("cooldown transition recovered unbound Sun distance=%.0f cooldown=%.2f"):format(distance or -1, cooldown))
				end
			else
				logDebug("SUN RESULT", ("cooldown transition confirmed tracked Sun cooldown=%.2f"):format(cooldown))
			end
		end
	end
	observer.prevCooldown = cooldown
	observer.prevInPhase = inPhase
end

do
	local invokerMenu = Menu.Create("Heroes", "Hero List", "Invoker SS")
	invokerMenu:Image(menuIcons.hero)
	local autoTab = localized(invokerMenu:Create(tr("tab.auto")), "tab.auto")
	local extraTab = localized(invokerMenu:Create(tr("tab.extra")), "tab.extra")
	autoTab:Icon(fontIcons.crosshairs)
	extraTab:Icon(fontIcons.sliders)

	local sunGroup = localized(autoTab:Create(tr("group.sun_strike"), Enum.GroupSide.Left), "group.sun_strike")
	local stealGroup = localized(autoTab:Create(tr("group.auto_steal"), Enum.GroupSide.Left), "group.auto_steal")
	local cataclysmGroup = localized(autoTab:Create(tr("group.cataclysm"), Enum.GroupSide.Right), "group.cataclysm")
	local extraGroup = localized(extraTab:Create(tr("group.extra"), Enum.GroupSide.FullWidth), "group.extra")

	ui = {}
	ui.enabled = localized(sunGroup:Switch(tr("ui.enabled"), true, menuIcons.hero), "ui.enabled", "tip.enabled")
	ui.sunMinMana = localized(sunGroup:Slider(tr("ui.sun_min_mana"), 0, 100, 20, "%d%%"), "ui.sun_min_mana", "tip.sun_min_mana")
	ui.autoSunStrike = localized(sunGroup:Switch(tr("ui.auto_sun_strike"), true, definitions.sun_strike.icon), "ui.auto_sun_strike", "tip.auto_sun_strike")
	ui.sunWithScepter = localized(sunGroup:Switch(tr("ui.sun_with_scepter"), false, menuIcons.scepter), "ui.sun_with_scepter", "tip.sun_with_scepter")
	ui.sunSelfCharge = localized(sunGroup:Switch(tr("ui.sun_self_charge"), true, definitions.sun_strike.icon), "ui.sun_self_charge", "tip.sun_self_charge")
	ui.landingSun = localized(sunGroup:Switch(tr("ui.landing_sun"), true, definitions.tornado.icon), "ui.landing_sun", "tip.landing_sun")
	local landingGear = localized(ui.landingSun:Gear(tr("title.landing_sun")), "title.landing_sun")
	ui.landingTeleports = localized(landingGear:Switch(tr("ui.landing_teleports"), true), "ui.landing_teleports", "tip.landing_teleports")
	local teleportGear = localized(ui.landingTeleports:Gear(tr("title.landing_teleports")), "title.landing_teleports")
	ui.landingTeleportAnyHp = localized(teleportGear:Switch(tr("ui.landing_tp_any_hp"), false), "ui.landing_tp_any_hp", "tip.landing_tp_any_hp")
	ui.landingTeleportLethal = localized(teleportGear:Switch(tr("ui.landing_tp_lethal"), true), "ui.landing_tp_lethal", "tip.landing_tp_lethal")
	ui.landingCyclones = localized(landingGear:Switch(tr("ui.landing_cyclones"), true), "ui.landing_cyclones", "tip.landing_cyclones")
	ui.landingLethal = localized(landingGear:Switch(tr("ui.landing_lethal"), false), "ui.landing_lethal", "tip.landing_lethal")

	local autoSunGear = localized(ui.autoSunStrike:Gear(tr("gear.sun")), "gear.sun")
	ui.sunWalkTime = localized(autoSunGear:Slider(tr("ui.sun_walk_time"), 3, 40, 8, function(value) return ("%.1fs"):format(value / 10) end), "ui.sun_walk_time", "tip.sun_walk_time")
	ui.sunIdleTime = localized(autoSunGear:Slider(tr("ui.sun_idle_time"), 3, 30, 10, function(value) return ("%.1fs"):format(value / 10) end), "ui.sun_idle_time", "tip.sun_idle_time")
	ui.useControlledTargets = localized(sunGroup:Switch(tr("ui.use_controlled_targets"), true), "ui.use_controlled_targets", "tip.use_controlled_targets")
	local controlledTargetsGear = localized(ui.useControlledTargets:Gear(tr("title.control_targets")), "title.control_targets")
	local controlModes = {"mode.use_always", "mode.lethal", "mode.near_lethal", "mode.by_hp"}
	ui.controlUseMode = localized(controlledTargetsGear:Combo(tr("ui.control_use_mode"), translatedItems(controlModes), 1), "ui.control_use_mode", "tip.control_use_mode", controlModes)
	ui.controlHpPercent = localized(controlledTargetsGear:Slider(tr("ui.control_hp_percent"), 1, 100, 100, "%d%%"), "ui.control_hp_percent", "tip.control_hp_percent")
	ui.predictRunningTargets = localized(sunGroup:Switch(tr("ui.predict_running_targets"), true), "ui.predict_running_targets", "tip.predict_running_targets")
	-- v82: route-specific runner controls belong inside the parent "Moving Targets" gear.
	local runningTargetsGear = localized(ui.predictRunningTargets:Gear(tr("ui.predict_running_targets")), "ui.predict_running_targets")
	ui.antiZigzag = localized(runningTargetsGear:Switch(tr("ui.anti_zigzag"), true), "ui.anti_zigzag", "tip.anti_zigzag")
	ui.fogRouteSun = localized(runningTargetsGear:Switch(tr("ui.fog_route_sun"), true), "ui.fog_route_sun", "tip.fog_route_sun")
	ui.quickSunButtons = localized(sunGroup:Switch(tr("ui.quick_sun_buttons"), true), "ui.quick_sun_buttons", "tip.quick_sun_buttons")
	ui.movingSunBlockVisual = localized(sunGroup:Switch(tr("ui.moving_sun_block_visual"), true), "ui.moving_sun_block_visual", "tip.moving_sun_block_visual")
	local movingSunBlockGear = localized(ui.movingSunBlockVisual:Gear(tr("title.moving_sun_block")), "title.moving_sun_block")
	ui.sunCountMisses = localized(movingSunBlockGear:Switch(tr("ui.sun_count_misses"), false), "ui.sun_count_misses", "tip.sun_count_misses")
	ui.movingSunBlockStanding = localized(movingSunBlockGear:Switch(tr("ui.moving_sun_block_standing"), false), "ui.moving_sun_block_standing", "tip.moving_sun_block_standing")
	ui.sunMinMana:Icon(fontIcons.percent)
	ui.sunWalkTime:Icon(fontIcons.forward)
	ui.sunIdleTime:Icon(fontIcons.clock)
	ui.useControlledTargets:Icon(fontIcons.crosshairs)
	ui.controlUseMode:Icon(fontIcons.magic)
	ui.controlHpPercent:Icon(fontIcons.percent)
	ui.predictRunningTargets:Icon(fontIcons.forward)
	ui.antiZigzag:Icon(fontIcons.forward)
	ui.fogRouteSun:Icon(fontIcons.view)
	ui.quickSunButtons:Icon(fontIcons.users)
	ui.movingSunBlockVisual:Icon(fontIcons.users)
	ui.sunCountMisses:Icon(fontIcons.users)
	ui.movingSunBlockStanding:Icon(fontIcons.crosshairs)
	ui.sunSelfCharge:Icon(fontIcons.magic)

	ui.autoRoshan = localized(stealGroup:Switch(tr("ui.auto_roshan"), false, menuIcons.roshan), "ui.auto_roshan", "tip.auto_roshan")
	ui.autoTormentor = localized(stealGroup:Switch(tr("ui.auto_tormentor"), false, menuIcons.tormentor), "ui.auto_tormentor", "tip.auto_tormentor")
	local tormentorGear = localized(ui.autoTormentor:Gear(tr("gear.tormentor")), "gear.tormentor")
	ui.tormentorMargin = localized(tormentorGear:Slider(tr("ui.roshan_margin"), 0, 500, 150, "%d"), "ui.roshan_margin", "tip.tormentor_margin")
	local roshanGear = localized(ui.autoRoshan:Gear(tr("gear.roshan")), "gear.roshan")
	ui.roshanMargin = localized(roshanGear:Slider(tr("ui.roshan_margin"), 0, 200, 25, "%d"), "ui.roshan_margin", "tip.roshan_margin")

	-- Cataclysm is kept because it is the Scepter branch of the same Sun Strike ability/cooldown.
	ui.autoCataclysm = localized(cataclysmGroup:Switch(tr("ui.auto_cataclysm"), true, definitions.cataclysm.icon), "ui.auto_cataclysm", "tip.auto_cataclysm")
	ui.cataclysmMinMana = localized(cataclysmGroup:Slider(tr("ui.cataclysm_min_mana"), 0, 100, 20, "%d%%"), "ui.cataclysm_min_mana", "tip.cataclysm_min_mana")
	ui.cataclysmMinMana:Icon(fontIcons.percent)
	local cataclysmAutoGear = localized(ui.autoCataclysm:Gear(tr("title.cataclysm_auto_use")), "title.cataclysm_auto_use")
	local cataclysmModes = {"mode.use_always", "mode.lethal", "mode.near_lethal"}
	ui.cataclysmUseMode = localized(cataclysmAutoGear:Combo(tr("ui.cataclysm_use_mode"), translatedItems(cataclysmModes), 0), "ui.cataclysm_use_mode", "tip.cataclysm_use_mode", cataclysmModes)
	ui.cataclysmUseMode:Icon(fontIcons.magic)
	ui.cataclysmSelfCharge = localized(cataclysmGroup:Switch(tr("ui.cataclysm_self_charge"), true, definitions.cataclysm.icon), "ui.cataclysm_self_charge", "tip.cataclysm_self_charge")
	ui.cataclysmTornado = localized(cataclysmGroup:Switch(tr("ui.cataclysm_tornado"), true, definitions.tornado.icon), "ui.cataclysm_tornado", "tip.cataclysm_tornado")
	ui.autoRefresher = localized(cataclysmGroup:Switch(tr("ui.auto_refresher"), true, definitions.item_refresher.icon), "ui.auto_refresher", "tip.auto_refresher")
	ui.cataclysmMinHeroes = localized(cataclysmGroup:Slider(tr("ui.cataclysm_min_heroes"), 2, 5, 2, "%d"), "ui.cataclysm_min_heroes", "tip.cataclysm_min_heroes")
	ui.cataclysmMinHeroes:Icon(fontIcons.users)
	ui.cataclysmSelfCharge:Icon(fontIcons.magic)

	-- v90: separate Safe SS and original-style Sun-Strike indication sections. Reuse existing chunk locals
	-- to preserve the Lua top-level-local budget.
	stealGroup = localized(autoTab:Create(tr("group.sun_safe"), Enum.GroupSide.Right), "group.sun_safe")
	ui.sunSafeCameraMove = localized(stealGroup:Switch(tr("ui.sun_safe_camera_move"), false), "ui.sun_safe_camera_move", "tip.sun_safe_camera_move")
	ui.sunEnemySafetyRadius = stealGroup:Slider("Радиус запрета авто-SS (0 — выкл.)", 0, 2000, 600, "%d")
	local safeCameraGear = localized(ui.sunSafeCameraMove:Gear(tr("ui.sun_safe_camera_move")), "ui.sun_safe_camera_move")
	ui.sunSafeCameraReturn = localized(safeCameraGear:Switch(tr("ui.sun_safe_camera_return"), false), "ui.sun_safe_camera_return", "tip.sun_safe_camera_return")
	ui.sunSafeCameraOnly = localized(stealGroup:Switch(tr("ui.sun_safe_camera_only"), false), "ui.sun_safe_camera_only", "tip.sun_safe_camera_only")
	ui.sunNotification = localized(stealGroup:Switch(tr("ui.sun_notification"), false), "ui.sun_notification", "tip.sun_notification")
	local notificationGear = localized(ui.sunNotification:Gear(tr("ui.sun_notification")), "ui.sun_notification")
	ui.sunNotificationCameraOnly = localized(notificationGear:Switch(tr("ui.sun_notification_camera_only"), false), "ui.sun_notification_camera_only", "tip.sun_notification_camera_only")
	ui.sunIndication = localized(stealGroup:Switch(tr("ui.sun_indication"), false), "ui.sun_indication", "tip.sun_indication")
	local indicationGear = localized(ui.sunIndication:Gear(tr("ui.sun_indication")), "ui.sun_indication")
	ui.sunTrajectory = localized(indicationGear:Switch(tr("ui.sun_trajectory"), false), "ui.sun_trajectory", "tip.sun_trajectory")
	ui.sunSafeDryRun = localized(stealGroup:Switch(tr("ui.sun_safe_dry_run"), false), "ui.sun_safe_dry_run", "tip.sun_safe_dry_run")
	ui.sunSafeCameraMove:Icon(fontIcons.view)
	ui.sunSafeCameraReturn:Icon(fontIcons.exchange)
	ui.sunSafeCameraOnly:Icon(fontIcons.view)
	ui.sunNotification:Icon(fontIcons.magic)
	ui.sunNotificationCameraOnly:Icon(fontIcons.view)
	ui.sunIndication:Icon(fontIcons.view)
	ui.sunTrajectory:Icon(fontIcons.forward)
	ui.sunSafeDryRun:Icon(fontIcons.pause)

	ui.fileLog = localized(extraGroup:Switch(tr("ui.file_log"), false), "ui.file_log", "tip.file_log")
	ui.fileLog:Icon(fontIcons.bug)

	local function refreshMenuState()
		local masterDisabled = not ui.enabled:Get()
		local sunDisabled = masterDisabled or not ui.autoSunStrike:Get()
		ui.autoSunStrike:Disabled(masterDisabled)
		autoSunGear:Visible(not masterDisabled and ui.autoSunStrike:Get())
		ui.sunWithScepter:Disabled(sunDisabled)
		ui.sunSelfCharge:Disabled(sunDisabled)
		ui.landingSun:Disabled(sunDisabled)
		landingGear:Visible(not sunDisabled and ui.landingSun:Get())
		ui.landingTeleports:Disabled(sunDisabled or not ui.landingSun:Get())
		teleportGear:Visible(not sunDisabled and ui.landingSun:Get() and ui.landingTeleports:Get())
		ui.landingTeleportAnyHp:Disabled(sunDisabled or not ui.landingSun:Get() or not ui.landingTeleports:Get())
		ui.landingTeleportLethal:Disabled(sunDisabled or not ui.landingSun:Get() or not ui.landingTeleports:Get())
		ui.landingCyclones:Disabled(sunDisabled or not ui.landingSun:Get())
		ui.landingLethal:Disabled(sunDisabled or not ui.landingSun:Get() or not ui.landingCyclones:Get())
		ui.sunMinMana:Disabled(sunDisabled)
		ui.sunWalkTime:Disabled(sunDisabled)
		ui.sunIdleTime:Disabled(sunDisabled)
		ui.useControlledTargets:Disabled(sunDisabled)
		controlledTargetsGear:Visible(not sunDisabled and ui.useControlledTargets:Get())
		ui.controlUseMode:Disabled(sunDisabled or not ui.useControlledTargets:Get())
		ui.controlHpPercent:Disabled(sunDisabled or not ui.useControlledTargets:Get() or ui.controlUseMode:Get() ~= 3)
		ui.predictRunningTargets:Disabled(sunDisabled)
		runningTargetsGear:Visible(not sunDisabled and ui.predictRunningTargets:Get())
		ui.antiZigzag:Disabled(sunDisabled or not ui.predictRunningTargets:Get())
		ui.fogRouteSun:Disabled(sunDisabled or not ui.predictRunningTargets:Get())
		ui.quickSunButtons:Disabled(sunDisabled)
		ui.movingSunBlockVisual:Disabled(masterDisabled)
		movingSunBlockGear:Visible(not masterDisabled and ui.movingSunBlockVisual:Get())
		ui.sunCountMisses:Disabled(masterDisabled or not ui.movingSunBlockVisual:Get())
		ui.movingSunBlockStanding:Disabled(sunDisabled or not ui.movingSunBlockVisual:Get())
		ui.sunSafeCameraMove:Disabled(sunDisabled)
		safeCameraGear:Visible(not sunDisabled and ui.sunSafeCameraMove:Get())
		ui.sunSafeCameraReturn:Disabled(sunDisabled or not ui.sunSafeCameraMove:Get())
		ui.sunSafeCameraOnly:Disabled(sunDisabled)
		ui.sunSafeDryRun:Disabled(sunDisabled)
		ui.sunIndication:Disabled(sunDisabled)
		ui.sunTrajectory:Disabled(sunDisabled or not ui.sunIndication:Get())
		indicationGear:Visible(not sunDisabled and ui.sunIndication:Get())
		ui.sunNotification:Disabled(sunDisabled)
		notificationGear:Visible(not sunDisabled and ui.sunNotification:Get())
		ui.sunNotificationCameraOnly:Disabled(sunDisabled or not ui.sunNotification:Get())
		ui.autoRoshan:Disabled(sunDisabled)
		roshanGear:Visible(not sunDisabled and ui.autoRoshan:Get())
		ui.roshanMargin:Disabled(sunDisabled or not ui.autoRoshan:Get())
		ui.autoTormentor:Disabled(sunDisabled)
		tormentorGear:Visible(not sunDisabled and ui.autoTormentor:Get())
		ui.tormentorMargin:Disabled(sunDisabled or not ui.autoTormentor:Get())
		ui.autoCataclysm:Disabled(masterDisabled)
		cataclysmAutoGear:Visible(not masterDisabled and ui.autoCataclysm:Get())
		ui.cataclysmMinMana:Disabled(masterDisabled or not ui.autoCataclysm:Get())
		ui.cataclysmUseMode:Disabled(masterDisabled or not ui.autoCataclysm:Get())
		ui.cataclysmSelfCharge:Disabled(masterDisabled or not ui.autoCataclysm:Get())
		ui.cataclysmTornado:Disabled(masterDisabled or not ui.autoCataclysm:Get())
		ui.autoRefresher:Disabled(masterDisabled or not ui.autoCataclysm:Get())
		ui.cataclysmMinHeroes:Disabled(masterDisabled or not ui.autoCataclysm:Get())
	end

	for _, control in pairs(ui) do
		control:SetCallback(function()
			if state then state.settingsCache = nil end
			refreshMenuState()
		end)
	end

	ui.fileLog:SetCallback(function(this)
		if this:Get() then
			helpers.restartFileLog("menu_enable")
		elseif state and state.sessionTrace then
			helpers.traceFlush("menu_disable")
			state.sessionTrace.enabled = false
		end
	end)

	local refreshLogButton = localized(extraGroup:Button(tr("ui.refresh_log"), function()
		helpers.restartFileLog("manual_refresh")
	end, true, 1.0), "ui.refresh_log", "tip.refresh_log")

	refreshMenuState()

	renderCtx = {
		font = Render.LoadFont("Arial", Enum.FontCreate.FONTFLAG_ANTIALIAS, 500),
		titleFont = Render.LoadFont("Arial", Enum.FontCreate.FONTFLAG_ANTIALIAS, 700),
		badgeFont = Render.LoadFont("Arial", Enum.FontCreate.FONTFLAG_ANTIALIAS, 700),
		icons = {},
		heroIcons = {},
		controls = {close = Render.LoadImage("panorama/images/control_icons/x_close_png.vtex_c")},
	}
	renderCtx.icons.sun_strike = Render.LoadImage(definitions.sun_strike.icon)

	-- Install the cross-script order guard.  Read-only scripts are unaffected.
	helpers.sunPriority.installGuards()

	-- Keep the donor state that retained Sun Strike prediction/tracking helpers still reference.
	state = {
		hero = nil, player = nil, bindings = nil, now = 0, snapshot = nil, motion = {},
		tornadoFlight = nil, tornadoFogControlState = {}, tornadoCataContainers = {}, landingSunLock = nil,
		invokeSequence = nil, orbSequence = nil, lastCompletedInvoke = nil, assumedInvoked = {},
		status = "", statusPhase = "idle",
		nextAutoActionAt = 0, automaticActionsPausedUntil = 0, autoSunSafetyUntil = 0, autoSunSafetyReason = nil, autoPending = nil,
		issuingOrder = false, orderGuardUntil = 0, lastDebug = {},
		sunPriorityActive = false,
		sunTimingProbe = nil, sunCommandDelayObserved = 0, sunCommandDelayMedianObserved = 0,
		sunCommandDelayFastResidualMin = nil, sunCommandDelayFastSamples = 0,
		sunCommandDelaySamples = {}, sunCooldownSeenDelay = 0,
		sunImpactParticleDelay = 0, sunTimingProbeSamples = 0, sunHpLatch = nil, sunTerrainCache = {},
		sunVisualTargetIndex = nil, sunVisualTargetUntil = 0,
		safeSunPreview = nil, safeSunVisualHold = nil, safeSunVisuals = {}, safeSunCameraMove = nil,
		safeSunCameraLastAutoAt = -math.huge,
		safeSunNotification = {}, safeSunNotificationHitbox = {}, safeSunAttentionScanAt = 0,
		builtinSunNumberIndicationDisabled = false, nextBuiltinSunIndicatorScanAt = 0,
		sunPostCastTrace = nil,
		sunPortraitStats = {}, sunOutcomeShot = nil, sunOutcomeCataclysms = {}, sunOutcomeCooldownSeen = false,
		sunCooldownTracking = false, cataclysmResultReadyAt = 0, cataclysmCooldownProbeUntil = 0, cataclysmCooldownBase = 0,
		sunCastObserver = {prevCooldown = nil, prevInPhase = false, readyCooldownLength = 0, phasePosition = nil, phaseAt = 0, lastOrderPosition = nil, lastOrderAt = 0, lastOrderKind = nil, lastTransitionAt = 0, lastTransitionKind = nil},
		sunOutcomeUnbound = nil,
		motionQuarantine = {}, matchActive = false, heroDead = false, gameEndHandled = false, sessionTrace = nil,
		quickSunHitboxes = {}, quickSunEntries = {},
		movingSunBlocks = helpers.loadMovingSunBlocks(), movingSunBlockHitboxes = {}, movingSunBlockEntityKeys = {},
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
		reliability = definition.reliability,
	}

	if id == "tornado" then
		result.projectileSpeed = liveValue(snapshot, id, "travel_speed", 1000)
		result.duration = liveValue(snapshot, id, "lift_duration", 1 + 0.2 * q)
		result.controlDuration = result.duration
		result.expectedDamage = liveValue(snapshot, id, "base_damage", 50) + liveValue(snapshot, id, "wex_damage", 45 * w)
		result.radius = liveValue(snapshot, id, "area_of_effect", 200)
	elseif id == "sun_strike" or id == "cataclysm" then
		result.fixedDelay = liveValue(snapshot, "sun_strike", "delay", 1.7)
		result.expectedDamage = liveValue(snapshot, "sun_strike", "damage", levelValue(e, {175, 225, 275, 325, 375, 425, 475, 525, 575}))
		if id == "cataclysm" then result.expectedDamage = result.expectedDamage * 1.5 end
		result.radius = liveValue(snapshot, "sun_strike", "area_of_effect", cfg.sunRadius)
	end
	return result
end

-- v21: cooldown observation is useful for confirming a cast, but it is NOT a valid
-- aim-calibration clock.  Keep order/ability-phase/cast-start/cooldown/particle timings
-- separate and diagnostic until a real Sun impact particle is identified and validated.
-- v32: ordinary timing keeps a rolling median of real order -> cast-start observations.
-- v70: countdown/scheduled impacts have asymmetric risk: a slower-than-expected cast lands late,
-- but a faster-than-expected cast can land while Tornado/Eul/TP protection is still active.  Track
-- the fastest observed scheduling residual above the physical castPoint+latency model separately.
-- During warmup the scheduled path trusts only the physical model; after two real samples it may
-- use the match-fast residual envelope.  No extra millisecond fudge is added.
function helpers.recordSunCommandDelaySample(value, modeledCommand)
	if type(value) ~= "number" or value ~= value or value < 0 or value > 0.60 then return nil end
	state.sunCommandDelaySamples = state.sunCommandDelaySamples or {}
	state.sunCommandDelaySamples[#state.sunCommandDelaySamples + 1] = value
	while #state.sunCommandDelaySamples > cfg.sunCommandDelaySampleWindow do
		table.remove(state.sunCommandDelaySamples, 1)
	end
	local ordered = {}
	for i, sample in ipairs(state.sunCommandDelaySamples) do ordered[i] = sample end
	table.sort(ordered)
	local count = #ordered
	local middle = math.floor((count + 1) * 0.5)
	local median = count % 2 == 1 and ordered[middle] or (ordered[count / 2] + ordered[count / 2 + 1]) * 0.5
	state.sunCommandDelayObserved = value
	state.sunCommandDelayMedianObserved = median
	local model = type(modeledCommand) == "number" and math.max(0, modeledCommand) or nil
	local residual = model and math.max(0, value - model) or nil
	if residual then
		state.sunCommandDelayFastSamples = (state.sunCommandDelayFastSamples or 0) + 1
		state.sunCommandDelayFastResidualMin = state.sunCommandDelayFastResidualMin == nil
			and residual or math.min(state.sunCommandDelayFastResidualMin, residual)
	end
	logDebug("SUN TIMING SAMPLE", ("raw=%.3f median=%.3f window=%d model=%s residual=%s fastResidual=%s fastN=%d"):format(
		value, median, count, model and ("%.3f"):format(model) or "?", residual and ("%.3f"):format(residual) or "?",
		state.sunCommandDelayFastResidualMin ~= nil and ("%.3f"):format(state.sunCommandDelayFastResidualMin) or "?",
		state.sunCommandDelayFastSamples or 0))
	return median
end

function helpers.beginSunTimingProbe(snapshot, pending, action, issuedAt, position)
	local mechanics = resolveMechanics("sun_strike", snapshot, 0)
	state.sunCommandDelayObserved = 0
	state.sunCooldownSeenDelay = 0
	state.sunImpactParticleDelay = 0
	state.sunTimingProbe = {
		issuedAt = issuedAt,
		targetIndex = pending and pending.targetIndex or nil,
		kind = pending and pending.kind or "sun_strike",
		castPoint = math.max(0, action and action.castPoint or mechanics.castPoint or 0),
		baseDelay = math.max(0, mechanics.fixedDelay or 1.7),
		latency = math.max(0, snapshot.latency or 0),
		expectedImpactAt = issuedAt + math.max(0, action and action.castPoint or mechanics.castPoint or 0)
			+ math.max(0, mechanics.fixedDelay or 1.7) + math.max(0, snapshot.latency or 0),
		position = position and copyPoint(position) or nil,
		phaseSeenAt = nil,
		castStartAt = nil,
		cooldownSeenAt = nil,
		particles = {},
	}
end

function helpers.updateSunTimingProbe(snapshot, pending)
	local probe = state.sunTimingProbe
	if not probe or not pending or not pending.cast or not pending.cast.issuedAt
		or math.abs(probe.issuedAt - pending.cast.issuedAt) > 0.001
	then
		return nil
	end
	local action = snapshot.actions.sun_strike
	if not action or not action.exists then return probe end

	if action.inAbilityPhase and not probe.phaseSeenAt then
		probe.phaseSeenAt = snapshot.now
		logDebug("SUN PHASE", ("order_to_phase=%.3f"):format(math.max(0, probe.phaseSeenAt - probe.issuedAt)))
	end

	if not probe.castStartAt then
		local ok, castStart = pcall(Ability.GetCastStartTime, action.ability)
		if ok and type(castStart) == "number" and castStart == castStart
			and castStart >= probe.issuedAt - 0.10 and castStart <= snapshot.now + 0.50
		then
			probe.castStartAt = castStart
			local rawCommandDelay = math.max(0, castStart - probe.issuedAt)
			helpers.recordSunCommandDelaySample(rawCommandDelay, math.max(0, probe.castPoint or 0) + math.max(0, probe.latency or 0))
			logDebug("SUN CASTSTART", ("order_to_caststart=%.3f stable=%.3f raw=%.3f"):format(
				rawCommandDelay, state.sunCommandDelayMedianObserved or 0, castStart))
		end
	end

	if not probe.cooldownSeenAt then
		local cooldownNow = Ability.GetCooldown(action.ability)
		if cooldownNow > math.max(0.05, (pending.cast.cooldownBefore or 0) + 0.05) then
			probe.cooldownSeenAt = snapshot.now
			local base = probe.castStartAt or probe.phaseSeenAt or probe.issuedAt
			local subtractCastPoint = (probe.castStartAt or probe.phaseSeenAt) and probe.castPoint or 0
			state.sunCooldownSeenDelay = math.max(0, probe.cooldownSeenAt - base - subtractCastPoint)
			logDebug("SUN COOLDOWN OBS", ("order_to_seen=%.3f post_start_lag=%.3f correction=OFF"):format(
				probe.cooldownSeenAt - probe.issuedAt, state.sunCooldownSeenDelay))
		end
	end
	return probe
end

function helpers.observeSunParticle(data)
	local probe = state and state.sunTimingProbe
	if not probe or not data then return end
	local name = data.fullName or data.name
	if type(name) ~= "string" or not string.find(string.lower(name), "sun_strike", 1, true) then return end
	local now = GameRules.GetGameTime()
	local age = now - probe.issuedAt
	if age < -0.05 or age > 3.20 then return end
	local index = data.index or -1
	if probe.particles[index] then return end
	probe.particles[index] = true
	local expectedDelta = now - (probe.expectedImpactAt or now)
	logDebug("SUN PARTICLE", ("name=%s index=%s order_age=%.3f expected_delta=%+.3f"):format(
		name, tostring(index), age, expectedDelta))
	-- Diagnostic only. Do not feed this value into aim until the exact impact particle name
	-- is proven over several casts. This prevents cast-start/ambient particles from poisoning timing.
	if math.abs(expectedDelta) <= 0.45 then
		state.sunImpactParticleDelay = age
	end
end

local function sunSplitCount(snapshot, position, radius, targetIndex, horizon)
	local count = targetIndex and 1 or 0
	for _, unit in ipairs(snapshot.sunUnits) do
		local predicted = add(unit.position, scale(unit.velocity, horizon or 0))
		if unit.index ~= targetIndex and distance2D(predicted, position) <= radius + 24 then count = count + 1 end
	end
	return math.max(1, count)
end

-- Landing-specific split safety. snapshot.sunUnits intentionally excludes currently invulnerable units,
-- which means Tornado/Eul victims disappear from the ordinary split counter while airborne. For a
-- landing-timed Sun we must also count other confirmed landing records that will be damageable at
-- the impact moment and whose frozen/confirmed landing point is inside the Sun AoE.
function helpers.landingSunSplitCount(snapshot, record, position, radius, impactAt)
	if not snapshot or not record or not position then return 1 end
	local included = {}
	local count = 0
	if record.index then included[record.index] = true; count = 1 end
	local horizon = math.max(0, (impactAt or snapshot.now) - snapshot.now)
	for _, unit in ipairs(snapshot.sunUnits or {}) do
		if not included[unit.index] then
			local predicted = add(unit.position, scale(unit.velocity, horizon))
			if distance2D(predicted, position) <= radius + 24 then
				included[unit.index] = true
				count = count + 1
			end
		end
	end
	for _, other in pairs(state.landings or {}) do
		if other and other.index and not included[other.index] and not other.cancelled and other.endsAt then
			-- v100: records for victims caught by the same Tornado are often discovered one scan/frame apart.
			-- Treat their near-identical landing times as one damage-sharing cohort. The old asymmetric
			-- "must land first/+30 ms" test let the first victim fall back to split=1 while the second
			-- correctly saw split=2.
			local impact = impactAt or snapshot.now
			local cohortTolerance = cfg.landingSplitCohortTolerance or 0.15
			if record.name == "modifier_invoker_tornado" and other.name == "modifier_invoker_tornado" then
				-- Nearby victims from one Tornado do not always receive identical modifier end-times.
				-- Keep them in the same Sun damage-sharing cohort conservatively: a false negative
				-- is preferable to casting a Sun that only looked lethal because split was missed.
				cohortTolerance = math.max(cohortTolerance, cfg.tornadoLandingSplitCohortTolerance or 0.45)
			end
			local sameLandingCohort = math.abs(other.endsAt - impact) <= cohortTolerance
			if sameLandingCohort then
				local otherPosition = other.name == "modifier_invoker_tornado" and other.tornadoLiftPosition or nil
				if not otherPosition and other.kind == "teleport" and helpers.teleportLandingPosition then
					otherPosition = helpers.teleportLandingPosition(other, snapshot)
				end
				otherPosition = otherPosition or other.position
				local unit = Entity.Get(other.index)
				local aliveOrHidden = not unit or Entity.IsAlive(unit)
				if otherPosition and aliveOrHidden and distance2D(otherPosition, position) <= radius + 24 then
					included[other.index] = true
					count = count + 1
				end
			end
		end
	end
	-- A short snapshot transition can temporarily remove airborne heroes from snapshot.sunUnits before
	-- every landing modifier record exists. Once a Tornado landing has observed a higher split count,
	-- never lower it for that same lift/shot; under-counting can create a false lethal cast.
	if record.name == "modifier_invoker_tornado" then
		record.landingSunSplitMax = math.max(record.landingSunSplitMax or 1, count)
		count = record.landingSunSplitMax
	end
	if count > 1 then
		logChanged("landing_split_" .. tostring(record.index), "LANDING SPLIT",
			("target=%d split=%d impact_in=%.3f position=%.0f,%.0f"):format(
				record.index or -1, count, math.max(0, (impactAt or snapshot.now) - snapshot.now), position.x, position.y))
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
		and measuredConfidence >= 0.50
		and agreement >= 0.65
		and target.movementDuration >= 0.65
		and target.stableDuration >= 0.65
	local damping = stableRunner and 1 or 1 - clamp(math.max(0, horizon - 0.65) * 0.1 * uncertainty, 0, 0.24)
	local projected = scale(direction, speed * damping * (stableRunner and 1 or 0.91 + 0.09 * agreement))
	return predictLinear(target.position, projected, horizon, math.max(0, target.moveSpeed) * horizon)
end

-- Sun Strike needs two different time scales: a long window to PROVE a stable route,
-- and a short window to AIM at the route the target is following right now.  Keep those
-- responsibilities separate so qualification history cannot drag the cast point behind a turn.
function helpers.predictSunTarget(snapshot, target, seconds, confidence, immobileSeconds, radius)
	if target.invulnerable or seconds <= (immobileSeconds or 0) then
		target.sunAimMeta = {source = "immobile", horizon = 0, reachHorizon = 0, cloud = 1, score = 1, covered = 1,
			turnRate = 0, acceleration = 0, frontLead = 0, frontReserve = radius or cfg.sunRadius, edgeBias = 0, timingReserve = 0,
			terrainStatus = "immobile", routeCount = 1, dominantWeight = 1, terrainFork = false, terrainForcedTurn = false}
		return copyPoint(target.position)
	end
	local horizon = clamp(seconds - (immobileSeconds or 0), 0, 3.5)
	local longVelocity = target.velocity or {x = 0, y = 0, z = 0}
	local recentVelocity = target.recentVelocity or longVelocity
	local liveVelocity = target.liveVelocity
	local instantVelocity = target.instantVelocity or recentVelocity
	local longSpeed = length2D(longVelocity)
	local recentSpeed = length2D(recentVelocity)
	local liveSpeed = liveVelocity and length2D(liveVelocity) or 0
	local instantSpeed = length2D(instantVelocity)
	if not target.moving or math.max(longSpeed, recentSpeed, liveSpeed, instantSpeed) < 20 then
		target.sunAimMeta = {source = "stopped", horizon = horizon, reachHorizon = horizon, cloud = 1, score = 1, covered = 1,
			turnRate = 0, acceleration = 0, frontLead = 0, frontReserve = radius or cfg.sunRadius, edgeBias = 0, timingReserve = 0,
			terrainStatus = "stopped", routeCount = 1, dominantWeight = 1, terrainFork = false, terrainForcedTurn = false}
		return copyPoint(target.position)
	end
	if not target.fogProjected and target.nativeMoving == false and instantSpeed < 20 and liveSpeed < 20 then
		target.sunAimMeta = {source = "stop-grace", horizon = horizon, reachHorizon = horizon, cloud = 1, score = 1, covered = 1,
			turnRate = 0, acceleration = 0, frontLead = 0, frontReserve = radius or cfg.sunRadius, edgeBias = 0, timingReserve = 0,
			terrainStatus = "stop-grace", routeCount = 1, dominantWeight = 1, terrainFork = false, terrainForcedTurn = false}
		return copyPoint(target.position)
	end

	local facing = normalized2D(target.facing)
	local lockedDirection = target.sunLockedAimDirection and normalized2D(target.sunLockedAimDirection) or nil
	if lockedDirection and length2D(lockedDirection) <= 0.5 then lockedDirection = nil end
	local longDirection = longSpeed > 18 and normalized2D(longVelocity) or facing
	local recentDirection = recentSpeed > 18 and normalized2D(recentVelocity) or longDirection
	local liveDirection = liveSpeed > 18 and normalized2D(liveVelocity) or recentDirection
	local instantDirection = instantSpeed > 18 and normalized2D(instantVelocity) or recentDirection
	local routeConfidence = clamp(math.min(confidence or 1, target.motionConfidence or 0), 0.1, 1)
	local recentConfidence = clamp(target.recentMotionConfidence or 0, 0, 1)
	local liveAgreement = liveSpeed > 18 and clamp((dot2D(liveDirection, recentDirection) + 1) * 0.5, 0, 1) or 1
	local facingAgreement = length2D(facing) > 0.5 and clamp((dot2D(instantDirection, facing) + 1) * 0.5, 0, 1) or 1
	local baseDirection = lockedDirection or helpers.sunPriority.currentAimDirection(target) or recentDirection
	if length2D(baseDirection) < 0.5 then baseDirection = recentDirection end
	-- v73: current speed is sampled at the final cast refresh. Normal running uses the live
	-- NPC.GetMoveSpeed() value, which already contains every slow/buff active RIGHT NOW. A truly
	-- faster immediate displacement (dash/rush) may override it, but stale windows cannot.
	local currentStatSpeed = math.max(0, target.moveSpeed or 0)
	local immediateMeasuredSpeed = math.max(liveSpeed, instantSpeed)
	local speedEffectOk, speedEffectActive, speedEffectName, speedEffectRemaining =
		pcall(helpers.sunTemporaryMoveSpeedEffect, target, snapshot.now)
	local hasSpeedEffect = speedEffectOk and speedEffectActive == true
	local baseSpeed = (target.moving or target.nativeMoving ~= false) and currentStatSpeed > 20 and currentStatSpeed
		or immediateMeasuredSpeed > 18 and immediateMeasuredSpeed
		or recentSpeed > 18 and recentSpeed or longSpeed
	-- A recent displacement sample can still contain pre-slow speed. For an active
	-- speed effect use the freshly read effective stat, not the old faster sample.
	if hasSpeedEffect and target.moving then
		baseSpeed = currentStatSpeed
	elseif immediateMeasuredSpeed > math.max(40, currentStatSpeed * 1.10) then
		baseSpeed = immediateMeasuredSpeed
	end
	local dynamicSpeedCeiling = math.max(40, currentStatSpeed * 1.03, baseSpeed * 1.03)
	baseSpeed = clamp(baseSpeed, 0, dynamicSpeedCeiling)
	local observedTurn = clamp(target.turnRate or 0, -0.75, 0.75) * (target.turning and 0.70 or 0.44)
	-- Do not extrapolate acceleration/deceleration into the future. The shot owns only the speed
	-- observed immediately before the order; later changes are post-decision force majeure.
	local observedAcceleration = 0
	local leadTrust = clamp(0.88 + routeConfidence * 0.06 + recentConfidence * 0.06, 0.88, 1)
	if liveSpeed > 18 then leadTrust = math.min(1, leadTrust + 0.02) end
	if liveAgreement < 0.84 then leadTrust = math.min(leadTrust, 0.94) end
	if facingAgreement < 0.68 then leadTrust = math.min(leadTrust, 0.91) end
	-- Fog reduces permission to cast, not the physical time available for target movement.
	local forecast = horizon * leadTrust
	-- v73: integrate only the speed measured for this final snapshot; no future modifier expiry.
	local speedProfile = helpers.sunSpeedTravelProfile(target, snapshot.now, forecast, baseSpeed, observedAcceleration,
		math.max(dynamicSpeedCeiling * 1.02, baseSpeed * 1.08))
	baseSpeed = speedProfile.startSpeed
	dynamicSpeedCeiling = math.max(dynamicSpeedCeiling, baseSpeed * 1.03, speedProfile.endSpeed * 1.03)

	local cache = state.sunTerrainCache and state.sunTerrainCache[target.index] or nil
	if cache and snapshot.now - (cache.at or -math.huge) <= cfg.sunTerrainCacheAge
		and distance2D(target.position, cache.origin or target.position) <= 0.01
		and math.abs(forecast - (cache.forecast or forecast)) <= 0.001
		and math.abs(baseSpeed - (cache.baseSpeed or baseSpeed)) <= 0.01
		and math.abs(observedTurn - (cache.observedTurn or 0)) <= 0.001
		and math.abs(routeConfidence - (cache.routeConfidence or 0)) <= 0.001
		and math.abs(recentConfidence - (cache.recentConfidence or 0)) <= 0.001
		and math.abs((radius or cfg.sunRadius) - (cache.radius or cfg.sunRadius)) <= 0.001
		and tostring(cache.speedSignature or "steady") == tostring(speedProfile.signature or "steady")
		and dot2D(baseDirection, cache.baseDirection or baseDirection) >= 0.999999
		and math.abs(liveAgreement - (cache.liveAgreement or 1)) <= 0.001
		and math.abs(facingAgreement - (cache.facingAgreement or 1)) <= 0.001
	then
		target.sunAimMeta = cache.meta
		return copyPoint(cache.position)
	end

	-- v62 topology-first remains authoritative; v73 supplies current-snapshot longitudinal distance.
	local referenceDistance = speedProfile.distance
	local branches, topology = helpers.sunTerrainTopologyBranches(target, baseDirection,
		math.max(referenceDistance, speedProfile.maximumDistance), cfg.sunTerrainLookahead)
	if not branches or #branches == 0 then
		local fallback = helpers.projectSunScenario(target, forecast, baseDirection, baseSpeed, observedAcceleration, observedTurn)
		target.sunAimMeta = {source = "topology-fallback", choice = "geometric", horizon = forecast, reachHorizon = horizon,
			cloud = 1, score = 0, covered = 0, cloudBest = "fallback", cloudBestCovered = 0, turnRate = observedTurn,
			acceleration = observedAcceleration, frontLead = distance2D(target.position, fallback), frontReserve = 0,
			frontMargin = 0, edgeBias = 0, timingReserve = 0, frontSpeed = baseSpeed, terrainStatus = "unavailable",
			routeCount = 0, dominantWeight = 0, secondWeight = 0, terrainFork = true, terrainForcedTurn = false,
			terrainFallbackWeight = 1, terrainConfidence = 0, routeEntropy = 1, terrainStability = 0,
			topologyBranches = 0, topologyFailed = topology and topology.failed or 7, topologyBlocked = topology and topology.blocked or 0,
			topologyFarBlocked = topology and topology.farBlocked or 0}
		return fallback
	end

	local expectedDirection = helpers.rotate2D(baseDirection, observedTurn * forecast * 0.52)
	local signals = {
		baseDirection = baseDirection, recentDirection = recentDirection, instantDirection = instantDirection,
		longDirection = longDirection, facing = length2D(facing) > 0.5 and facing or baseDirection, expectedDirection = expectedDirection,
	}
	local branchWeightTotal = 0
	for _, branch in ipairs(branches) do
		branch.weight = helpers.sunTerrainTopologyWeight(branch, signals)
		branchWeightTotal = branchWeightTotal + branch.weight
	end
	if branchWeightTotal <= 0 then branchWeightTotal = 1 end
	for _, branch in ipairs(branches) do branch.weight = branch.weight / branchWeightTotal end

	local longitudinalSpread = clamp(cfg.sunTerrainLongitudinalSpread + (1 - routeConfidence) * 0.10
		+ (target.fogProjected and math.min(0.07, (target.fogAge or 0) * 0.035) or 0), 0.07, 0.22)
	local distanceBands = {
		{name = "slow", multiplier = 1 - longitudinalSpread, weight = 0.22},
		{name = "nominal", multiplier = 1, weight = 0.56},
		{name = "fast", multiplier = 1 + longitudinalSpread, weight = 0.22},
	}
	if speedProfile.active or speedProfile.maximumDistance - speedProfile.minimumDistance > 0.01 then
		distanceBands = {
			{name = "speed_min", distance = speedProfile.minimumDistance * (1 - longitudinalSpread), weight = 0.25},
			{name = "speed_timeline", distance = referenceDistance, weight = 0.50},
			{name = "speed_max", distance = speedProfile.maximumDistance * (1 + longitudinalSpread), weight = 0.25},
		}
	end
	local cloud, rawWeight, fallbackWeight, forcedWeight, maxStretch = {}, 0, 0, 0, 1
	local dominantBranch, dominantBranchWeight = nil, -1
	for branchIndex, branch in ipairs(branches) do
		if branch.weight > dominantBranchWeight then dominantBranch, dominantBranchWeight = branch, branch.weight end
		for _, band in ipairs(distanceBands) do
			local bandDistance = band.distance or referenceDistance * band.multiplier
			local position, tangent, _, complete = helpers.sunTerrainPointAlongPath(target.position, branch.path, bandDistance,
				branch.tangent or branch.probeDirection)
			local weight = branch.weight * band.weight
			local scenario = {
				name = "b" .. tostring(branchIndex) .. "_" .. band.name, branch = branchIndex,
				weight = weight, position = position, direction = branch.entryTangent, tangent = tangent,
				terrainMode = branch.mode, forcedTurn = branch.forcedTurn == true,
				stretch = branch.stretch or 1, travelDistance = bandDistance, complete = complete,
			}
			cloud[#cloud + 1] = scenario
			rawWeight = rawWeight + weight
			if not complete then fallbackWeight = fallbackWeight + weight end
			if branch.forcedTurn then forcedWeight = forcedWeight + weight end
			maxStretch = math.max(maxStretch, branch.stretch or 1)
		end
	end
	if #cloud == 0 or rawWeight <= 0 then
		local fallback = helpers.projectSunScenario(target, forecast, baseDirection, baseSpeed, observedAcceleration, observedTurn)
		target.sunAimMeta = {source = "topology-fallback", choice = "geometric", horizon = forecast, reachHorizon = horizon,
			cloud = 1, score = 0, covered = 0, cloudBest = "fallback", cloudBestCovered = 0, turnRate = observedTurn,
			acceleration = observedAcceleration, frontLead = distance2D(target.position, fallback), frontReserve = 0,
			frontMargin = 0, edgeBias = 0, timingReserve = 0, frontSpeed = baseSpeed, terrainStatus = "unavailable",
			routeCount = 0, dominantWeight = 0, secondWeight = 0, terrainFork = true, terrainForcedTurn = false,
			terrainFallbackWeight = 1, terrainConfidence = 0, routeEntropy = 1, terrainStability = 0,
			topologyBranches = #branches, topologyFailed = topology and topology.failed or 0, topologyBlocked = topology and topology.blocked or 0,
			topologyFarBlocked = topology and topology.farBlocked or 0}
		return fallback
	end
	for _, scenario in ipairs(cloud) do scenario.weight = (scenario.weight or 0) / rawWeight end
	fallbackWeight = clamp((fallbackWeight / rawWeight) + ((topology and topology.failed or 0) / math.max(1, topology and topology.total or 7)) * 0.34, 0, 1)
	forcedWeight = forcedWeight / rawWeight

	local aoe = math.max(80, radius or cfg.sunRadius)
	local clusters = helpers.sunTerrainClusters(cloud, math.min(cfg.sunTerrainBranchMergeRadius or cfg.sunTerrainClusterRadius, aoe * 0.78))
	local dominantWeight = clusters[1] and clusters[1].weight or 0
	local secondWeight = clusters[2] and clusters[2].weight or 0
	local dominantSeparation = clusters[1] and clusters[2] and distance2D(clusters[1].position, clusters[2].position) or 0
	local terrainFork = #clusters >= 2 and secondWeight >= 0.18 and dominantSeparation > aoe * 1.35 and dominantWeight < 0.78
	local terrainForcedTurn = forcedWeight >= 0.18
	local routeEntropy = helpers.sunTerrainRouteEntropy(clusters)
	local previousMeta = cache and cache.meta or nil
	local terrainStability = helpers.sunTerrainTemporalStability(previousMeta, clusters[1] and clusters[1].position or target.position,
		dominantWeight, #clusters, routeEntropy, cache and snapshot.now - (cache.at or -math.huge) or math.huge, aoe)
	local terrainStatus = fallbackWeight >= 0.34 and "fallback"
		or terrainFork and "fork"
		or terrainForcedTurn and dominantWeight >= 0.68 and "converge"
		or terrainForcedTurn and "correct"
		or "open"

	local centroid = {x = 0, y = 0, z = target.position.z or 0}
	for _, scenario in ipairs(cloud) do
		centroid.x = centroid.x + scenario.position.x * scenario.weight
		centroid.y = centroid.y + scenario.position.y * scenario.weight
	end
	local candidates = {{name = "centroid", position = centroid}}
	for _, scenario in ipairs(cloud) do candidates[#candidates + 1] = {name = scenario.name, position = scenario.position} end
	for index, cluster in ipairs(clusters) do candidates[#candidates + 1] = {name = "route" .. tostring(index), position = cluster.position} end
	-- Sample pairs can share one Sun even when neither sample nor the global centroid
	-- covers both. Keep a 10% radius reserve against movement/timing uncertainty.
	if topology and (topology.blocked or 0) > 0 then
		for i = 1, #cloud - 1 do
			for j = i + 1, #cloud do
				local a, b = cloud[i], cloud[j]
				local separation = distance2D(a.position, b.position)
				if a.complete and b.complete and separation > 1 and separation <= aoe * 1.8 then
					candidates[#candidates + 1] = {name = "route-pair", position = add(scale(a.position, 0.5), scale(b.position, 0.5))}
				end
			end
		end
	end
	local cloudBest, cloudBestName, cloudBestScore, cloudBestCovered = centroid, "centroid", -math.huge, 0
	for _, candidate in ipairs(candidates) do
		local score, covered = helpers.scoreSunAim(candidate.position, cloud, aoe)
		if clusters[1] then score = score - distance2D(candidate.position, clusters[1].position) / math.max(1, aoe) * 0.008 end
		if score > cloudBestScore then
			cloudBest, cloudBestName, cloudBestScore, cloudBestCovered = candidate.position, candidate.name, score, covered
		end
	end

	local modeledCommand = math.max(0, snapshot.actions and snapshot.actions.sun_strike and snapshot.actions.sun_strike.castPoint or 0)
		+ math.max(0, snapshot.latency or 0)
	local measuredCommand = (state.sunTimingProbeSamples or 0) > 0 and math.max(0, state.sunCommandDelayObserved or 0) or 0
	local timingReserve = measuredCommand > 0 and clamp(measuredCommand - modeledCommand, 0, 0.32) or 0
	local reachHorizon = clamp(horizon + timingReserve, 0, 3.5)
	local frontSpeed = math.max(baseSpeed, recentSpeed, liveSpeed, longSpeed, instantSpeed, target.moveSpeed or 0)
	local frontSpeedCeiling = math.max((target.moveSpeed or 0) * 1.03, liveSpeed * 1.03, recentSpeed * 1.03, baseSpeed * 1.03)
	if frontSpeedCeiling > 20 then frontSpeed = math.min(frontSpeed, frontSpeedCeiling) end
	frontSpeed = clamp(frontSpeed, 0, 1800)
	local frontProfile = helpers.sunSpeedTravelProfile(target, snapshot.now, reachHorizon, frontSpeed, 0, frontSpeed)
	local frontDistance = frontProfile.maximumDistance
	frontSpeed = math.max(frontSpeed, frontProfile.startSpeed, frontProfile.endSpeed)
	local frontPoint, frontTangent, frontComplete = nil, baseDirection, false
	if dominantBranch then
		local point, tangent, _, complete = helpers.sunTerrainPointAlongPath(
			target.position, dominantBranch.path, frontDistance, dominantBranch.tangent or baseDirection)
		frontPoint, frontTangent, frontComplete = point, tangent, complete
	end
	if type(frontPoint) ~= "table" then
		local frontProjection = helpers.sunTerrainProject(target, baseDirection, frontDistance, cfg.sunTerrainLookahead)
		frontPoint = frontProjection and frontProjection.position or cloudBest
		frontTangent = frontProjection and frontProjection.tangent or baseDirection
		frontComplete = frontProjection and frontProjection.complete ~= false or false
	end
	if not frontComplete and dominantBranch and distance2D(target.position, frontPoint) + 1 < frontDistance then
		fallbackWeight = math.max(fallbackWeight, 0.34)
	end
	if length2D(frontTangent) < 0.5 then frontTangent = baseDirection end
	-- Prefer the centre of the predicted endpoint cloud. Never deliberately back
	-- away from the forward prediction by a fraction of the spell radius.
	local frontMargin = aoe * 0.25
	local speedEffectCenter, speedEffectModifier = hasSpeedEffect, speedEffectOk and speedEffectName or nil
	speedEffectRemaining = speedEffectOk and (speedEffectRemaining or 0) or 0
	local best, bestName, bestScore, bestCovered = cloudBest, "terrain-center", cloudBestScore, cloudBestCovered
	if speedEffectCenter then bestName = "speed-effect-center" end
	local edgeBias = 0
	-- Every selection branch, including speed-effect and coverage fallbacks, must
	-- leave the predicted front position inside 75% of the real Sun radius.
	local maxAimOffset = aoe * 0.75
	local aimOffset = subtract(best, frontPoint)
	local aimDistance = length2D(aimOffset)
	if aimDistance > maxAimOffset then
		best = add(frontPoint, scale(aimOffset, maxAimOffset / aimDistance))
		bestName, edgeBias = "terrain-reserve25", 0
		-- Re-evaluate the moved circle so the route gate sees its actual coverage.
		bestScore, bestCovered = helpers.scoreSunAim(best, cloud, aoe)
	end
	local frontReserve = aoe - distance2D(best, frontPoint)
	local terrainConfidence = clamp(bestCovered * 0.46 + dominantWeight * 0.20 + routeConfidence * 0.14
		+ (1 - routeEntropy) * 0.10 + terrainStability * 0.10 - fallbackWeight * 0.22, 0, 1)
	target.sunAimMeta = {
		source = "topology-first", choice = bestName, horizon = forecast, reachHorizon = reachHorizon, cloud = #cloud,
		score = bestScore, covered = bestCovered, cloudBest = cloudBestName, cloudBestCovered = cloudBestCovered,
		turnRate = observedTurn, acceleration = observedAcceleration, liveAgreement = liveAgreement, facingAgreement = facingAgreement,
		frontLead = distance2D(target.position, frontPoint), frontReserve = frontReserve, frontMargin = frontMargin,
		edgeBias = edgeBias, timingReserve = timingReserve, frontSpeed = frontSpeed, terrainStatus = terrainStatus,
		speedRegime = speedEffectCenter and "temp_effect_center" or "current_snapshot",
		speedModifier = speedEffectCenter and speedEffectModifier or nil,
		speedExpiresIn = speedEffectCenter and speedEffectRemaining or math.huge,
		speedBaselineStat = speedProfile.endSpeed, speedAffectedStat = currentStatSpeed,
		speedTransitionConfidence = speedProfile.confidence, speedTravelDistance = speedProfile.distance,
		speedUnresolvedIntervals = speedProfile.unresolved,
		speedMinimumDistance = speedProfile.minimumDistance, speedMaximumDistance = speedProfile.maximumDistance,
		speedTimeline = speedProfile.intervals,
		routeCount = #clusters, dominantWeight = dominantWeight, secondWeight = secondWeight, terrainFork = terrainFork,
		terrainForcedTurn = terrainForcedTurn, terrainFallbackWeight = fallbackWeight, terrainConfidence = terrainConfidence,
		terrainStretch = maxStretch, terrainSeparation = dominantSeparation, routeEntropy = routeEntropy,
		terrainStability = terrainStability, dominantPosition = clusters[1] and copyPoint(clusters[1].position) or copyPoint(best),
		topologyBranches = #branches, topologyFailed = topology and topology.failed or 0, topologyBlocked = topology and topology.blocked or 0,
		topologyFarBlocked = topology and topology.farBlocked or 0,
	}
	state.sunTerrainCache = state.sunTerrainCache or {}
	state.sunTerrainCache[target.index] = {at = snapshot.now, origin = copyPoint(target.position), forecast = forecast,
		baseSpeed = baseSpeed, speedSignature = speedProfile.signature, baseDirection = copyPoint(baseDirection),
		observedTurn = observedTurn, routeConfidence = routeConfidence, recentConfidence = recentConfidence,
		liveAgreement = liveAgreement, facingAgreement = facingAgreement,
		radius = radius or cfg.sunRadius,
		position = copyPoint(best), meta = target.sunAimMeta}
	return best
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
	-- v21: prediction uses only live castPoint + measured latency. Cooldown-observation lag
	-- is diagnostic and must never push the aim farther ahead.
	local commandDelay = math.max(0, castAt - snapshot.now) + mechanics.castPoint + snapshot.latency
	local immobile = math.max(0, math.max(target.disabledUntil, target.controlEndsAt) - snapshot.now)
	local position = id == "sun_strike" and helpers.predictSunTarget(snapshot, target, commandDelay + mechanics.fixedDelay, confidence, immobile, mechanics.radius)
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


local function isInvoking(id)
	return state.invokeSequence ~= nil
		and (not id or state.invokeSequence.actionId == canonicalSpell(id))
end

local function issueOrder(callback)
	local previousIssuing = state.issuingOrder
	local previousGuard = state.orderGuardUntil
	state.issuingOrder = true
	state.orderGuardUntil = state.now + 0.08
	local ok, err = pcall(callback)
	state.issuingOrder = previousIssuing
	if not ok then
		state.orderGuardUntil = previousGuard
		error(err, 0)
	end
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
		-- Invoke is confirmed only when the requested spell really appears in D/F.
		local active = contains(snapshot.invoke.invoked, sequence.actionId)
		if active then
			logDebug("INVOKE", ("confirmed %s active"):format(sequence.actionId))
			rememberInvoked(sequence.actionId)
			state.invokeSequence = nil
		elseif snapshot.now >= sequence.confirmDeadline then
			logDebug("INVOKE", ("confirmation timed out for %s"):format(sequence.actionId))
			-- Do not poison assumed D/F state after a failed confirmation.
			state.assumedInvoked = {}
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
		issueOrder(function() Ability.CastNoTarget(orb, false, false, true, "invoker_ss_top_v18") end)
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
	issueOrder(function() Ability.CastNoTarget(state.bindings.invoke, false, false, true, "invoker_ss_top_v18") end)
	state.lastCompletedInvoke = {id = sequence.actionId, at = snapshot.now}
	sequence.castIssued = true
	sequence.confirmDeadline = snapshot.now + math.max(cfg.invokeConfirmWindow, snapshot.latency * 2 + 0.45)
	sequence.nextAt = snapshot.now + 0.06
	logDebug("INVOKE", ("cast Invoke for %s"):format(sequence.actionId))
end


local function updateOrbSequence(snapshot)
	local sequence = state.orbSequence
	if not sequence or state.invokeSequence or snapshot.now + 0.001 < sequence.nextAt then return end
	local orb = state.bindings.orbs[sequence.orb]
	if not orb or Ability.GetLevel(orb) <= 0 or not Ability.IsActivated(orb) or sequence.remaining <= 0 then
		state.orbSequence = nil
		return
	end
	issueOrder(function() Ability.CastNoTarget(orb, false, false, true, "invoker_ss_top_v18") end)
	sequence.remaining = sequence.remaining - 1
	sequence.nextAt = snapshot.now + cfg.autoOrbInterval
	if sequence.remaining <= 0 then state.orbSequence = nil end
end

function helpers.sunImpactDelay(snapshot, id)
	local mechanics = resolveMechanics(id, snapshot, 0)
	local action = snapshot.actions[id]
	local preparation = 0
	if action and not action.invoked then
		-- Auto Sun may reserve only the final <=0.35 s of Invoke cooldown. Include that small
		-- real wait in impact timing, then the same fast combo-style EEE -> Invoke sequence.
		local invokeWait = snapshot.invoke and math.max(0, snapshot.invoke.cooldown or 0) or 0
		preparation = math.min(0.35, invokeWait) + math.max(0.16, cfg.invokeOrbInterval * 3 + 0.06 + snapshot.latency)
	end
	-- Cooldown polling delay is deliberately excluded. It is not physical Sun travel time.
	return preparation + mechanics.castPoint + mechanics.fixedDelay + snapshot.latency + cfg.timingSafety
end

-- v32 ordinary landing synchronization used the rolling median of measured order -> cast-start.
-- v70 scheduled-boundary timing separates EXPECTED timing from EARLIEST-CREDIBLE timing.  For a
-- countdown impact the dangerous error is only early arrival, so the scheduler must not subtract a
-- median that can be 100 ms slower than the next real cast.  The physical command floor is the live
-- castPoint+latency model.  After at least two real probes, the fastest non-negative scheduling
-- residual observed in this match may be layered on top.  This is a measured lower envelope, not an
-- added fixed reserve; existing per-mode landing offsets (+Tornado/+TP/etc.) remain unchanged.
function helpers.landingOrderImpactDelay(snapshot, id)
	local mechanics = resolveMechanics(id, snapshot, 0)
	-- v47: Cataclysm has its own order -> damage timer. Runtime video/log comparison showed
	-- that adding the measured ordinary Sun order->cast-start delay (~0.27-0.30 s) makes
	-- Cataclysm detonate that much BEFORE the last Tornado victim lands. Cataclysm's
	-- in-game delay is the live fixed delay (1.7 s in the current build), so do not import
	-- the ordinary point-target Sun command envelope here.
	if id == "cataclysm" then
		return math.max(0, mechanics.fixedDelay or 0), 0, "cataclysm-fixed-delay"
	end
	local action = snapshot.actions and snapshot.actions[id] or nil
	local modeledCommand = math.max(0, action and action.castPoint or mechanics.castPoint or 0)
		+ math.max(0, snapshot.latency or 0)
	local medianCommand = #(state.sunCommandDelaySamples or {}) > 0
		and math.max(0, state.sunCommandDelayMedianObserved or 0) or 0
	local fastSamples = state.sunCommandDelayFastSamples or 0
	local fastResidual = math.max(0, state.sunCommandDelayFastResidualMin or 0)
	local warmup = fastSamples < 2
	local commandDelay = modeledCommand + (warmup and 0 or fastResidual)
	commandDelay = clamp(commandDelay, modeledCommand, modeledCommand + 0.32)
	local timingSource = warmup and "boundary-model-warmup" or "boundary-fast-envelope"
	return math.max(0, mechanics.fixedDelay or 0) + commandDelay, commandDelay, timingSource,
		medianCommand, modeledCommand, fastResidual, fastSamples
end

function helpers.cataclysmHitsControl(enemy, snapshot)
	local impactAt = snapshot.now + helpers.sunImpactDelay(snapshot, "cataclysm")
	if not enemy.alive or not enemy.visible or enemy.dormant then return false end
	if enemy.controlEndsAt > snapshot.now then
		return impactAt >= enemy.controlEndsAt + 0.03 and impactAt <= enemy.controlEndsAt + 0.2
	end
	return not enemy.invulnerable and not enemy.outOfGame and enemy.disabledUntil >= impactAt
end















---Builds a live Dynamic combo from usable actions without fixed templates.
---@param snapshot InvokerSnapshot
---@param settings table
---@return table?

















-- v61 shared control-anchor timing. This is the same equation the combo planner uses for payloads
-- that must land after an untargetable control ends.  Landing Sun/Cataclysm now reuse it instead of
-- maintaining a second independent timing formula.  If the ideal order time is already behind us
-- while the victim is still controlled, NOW is the earliest physically valid best-effort order.
function helpers.controlledLandingCastTime(now, controlEndsAt, payloadDelay, safety)
	local naturalCastAt = (controlEndsAt or now) + (safety or 0) - math.max(0, payloadDelay or 0)
	local controlled = controlEndsAt ~= nil and controlEndsAt > now
	local immediate = controlled and naturalCastAt <= now
	return immediate and now or naturalCastAt, naturalCastAt, immediate, controlled
end














local function findEnemy(snapshot, index)
	if not index then return snapshot.target end
	for _, enemy in ipairs(snapshot.enemies) do
		if enemy.index == index then return enemy end
	end
	return nil
end

-- v95 visual-only low-HP validation. This deliberately does NOT release the combat HP latch and
-- never changes cast permission; it only decides whether the indication/trajectory should be visible.
function helpers.safeSunCurrentVisualLethal(targetIndex, aimPosition, snapshot, targetOverride)
	if not snapshot or not aimPosition or not targetIndex then return false, nil, math.huge, 0, 1 end
	local target = targetOverride or findEnemy(snapshot, targetIndex)
	if not target or not target.alive or target.invulnerable or target.outOfGame then
		return false, target, math.huge, 0, 1
	end
	local tracked = target.visible and not target.dormant
		or target.fogProjected and (target.fogAge or math.huge) <= cfg.fogRouteTTL
	if not tracked then return false, target, math.huge, 0, 1 end
	local mechanics = resolveMechanics("sun_strike", snapshot, 0)
	local impactDelay = helpers.sunImpactDelay(snapshot, "sun_strike")
	local splitCount = sunSplitCount(snapshot, aimPosition, math.max(cfg.sunRadius, mechanics.radius), target.index, impactDelay)
	local expectedDamage = mechanics.expectedDamage / math.max(1, splitCount)
	local impactHealth = math.min(target.maxHealth, target.health + math.max(0, target.healthRegen) * impactDelay)
	return impactHealth <= expectedDamage + 0.001, target, impactHealth, expectedDamage, splitCount
end

-- v108 notification ownership check.  This intentionally ignores route qualification, walk time,
-- anti-zigzag and Invoke readiness: those decide WHEN Auto SS may cast, not whether an already-open
-- low-HP notification still belongs to the target.  HP and live damage sharing are still recalculated
-- at the latest predicted aim, so healing or a new split target closes the notice normally.
function helpers.safeSunNotificationHpEligible(targetIndex, snapshot, targetOverride)
	if not snapshot or not targetIndex then return false, nil, math.huge, 0, 1, nil end
	local target = targetOverride or findEnemy(snapshot, targetIndex)
	if not target or not target.alive or target.invulnerable or target.outOfGame then
		return false, target, math.huge, 0, 1, nil
	end
	local tracked = target.visible and not target.dormant
		or target.fogProjected and (target.fogAge or math.huge) <= cfg.fogRouteTTL
	if not tracked then return false, target, math.huge, 0, 1, nil end

	-- The notification scan is observational.  Produce a current aim without warming the selector's
	-- terrain cache or replacing its locked combat direction/metadata.
	local oldCache = state.sunTerrainCache and state.sunTerrainCache[target.index] or nil
	local oldAimMeta = target.sunAimMeta
	local oldAimDirection = target.sunLockedAimDirection
	target.sunLockedAimDirection = nil
	local prediction = predictIntercept(snapshot, "sun_strike", target, snapshot.now, target.motionConfidence)
	if state.sunTerrainCache then state.sunTerrainCache[target.index] = oldCache end
	target.sunAimMeta = oldAimMeta
	target.sunLockedAimDirection = oldAimDirection

	local aimPosition = prediction and prediction.position and copyPoint(prediction.position) or copyPoint(target.position)
	local mechanics = resolveMechanics("sun_strike", snapshot, 0)
	local impactDelay = helpers.sunImpactDelay(snapshot, "sun_strike")
	local splitCount = sunSplitCount(snapshot, aimPosition, math.max(cfg.sunRadius, mechanics.radius), target.index, impactDelay)
	local expectedDamage = mechanics.expectedDamage / math.max(1, splitCount)
	local impactHealth = math.min(target.maxHealth, target.health + math.max(0, target.healthRegen) * impactDelay)
	return impactHealth <= expectedDamage + 0.001, target, impactHealth, expectedDamage, splitCount, aimPosition
end

function helpers.safeSunVisualDisplay()
	if not state or not state.snapshot then return nil end
	local snapshot = state.snapshot
	local now = snapshot.now or GameRules.GetGameTime()
	local trajectoryOn = ui and ui.sunTrajectory and ui.sunTrajectory:Get() == true
	local preview = state.safeSunPreview

	-- Fresh final-gate preview keeps the old indication behavior. Strict-lethal previews additionally
	-- reflect CURRENT HP so a healed target cannot leave a stale low-HP vector on screen.
	if preview and preview.position and now <= (preview.expiresAt or 0) then
		if preview.strictLethal then
			local lethal, target, impactHealth, expectedDamage = helpers.safeSunCurrentVisualLethal(
				preview.targetIndex, preview.position, snapshot)
			if not lethal then
				state.safeSunPreview = nil
				state.safeSunVisualHold = nil
				logChanged("sun_visual_hp_" .. tostring(preview.targetIndex or -1), "SUN VISUAL",
					("target=%s current HP is no longer lethal -> VISUAL SOURCE CLEARED"):format(
						tostring(preview.targetIndex or "none")))
				return nil
			end
			if target and target.position then preview.targetPosition = copyPoint(target.position) end
			if trajectoryOn and preview.targetIndex then
				state.safeSunVisualHold = {
					targetIndex = preview.targetIndex, position = copyPoint(preview.position),
					targetPosition = preview.targetPosition and copyPoint(preview.targetPosition) or nil,
					kind = preview.kind, strictLethal = true, updatedAt = now,
				}
			end
		end
		return preview
	end

	if not trajectoryOn then
		state.safeSunVisualHold = nil
		return nil
	end

	-- Extended trajectory lifetime is tied to the existing logical HP/target lock, not to an arbitrary TTL.
	-- Use only prediction data the combat path already produced; this renderer never calls the predictor.
	local targetIndex, candidateAim = nil, nil
	local latch = state.sunHpLatch
	if latch and latch.targetIndex then
		targetIndex = latch.targetIndex
		local cache = state.sunTerrainCache and state.sunTerrainCache[targetIndex] or nil
		if cache and cache.position and now - (cache.at or -math.huge) <= 0.30 then
			candidateAim = cache.position
		elseif latch.prediction then
			candidateAim = latch.prediction
		end
	elseif state.autoPending and state.autoPending.actionId == "sun_strike"
		and state.autoPending.kind == "sun_strike" and state.autoPending.sunStrictLethal
	then
		targetIndex = state.autoPending.targetIndex
		candidateAim = state.autoPending.sunResolvedPosition
	end

	if not targetIndex then
		state.safeSunVisualHold = nil
		return nil
	end
	local target = findEnemy(snapshot, targetIndex)
	if not target or not target.alive or target.invulnerable or target.outOfGame then
		state.safeSunVisualHold = nil
		return nil
	end

	local hold = state.safeSunVisualHold
	if candidateAim then
		-- Build a provisional candidate locally.  It becomes persistent visual state only after
		-- CURRENT lethality is proven below, so an old combat HP latch cannot repopulate the renderer.
		hold = {
			targetIndex = targetIndex, position = copyPoint(candidateAim), targetPosition = copyPoint(target.position),
			kind = "sun_strike", strictLethal = true, updatedAt = now,
		}
	elseif not hold or hold.targetIndex ~= targetIndex or not hold.position then
		return nil
	else
		hold.targetPosition = copyPoint(target.position)
	end

	local lethal = helpers.safeSunCurrentVisualLethal(targetIndex, hold.position, snapshot, target)
	if not lethal then
		state.safeSunPreview = nil
		state.safeSunVisualHold = nil
		logChanged("sun_visual_hp_" .. tostring(targetIndex), "SUN VISUAL",
			("target=%d current HP is no longer lethal -> VISUAL SOURCE CLEARED"):format(targetIndex))
		return nil
	end
	state.safeSunVisualHold = hold
	return hold
end

---Issues one cast for the only executable actions retained by this module.
---@param request table
---@param snapshot InvokerSnapshot
---@return "invalid"|"wait"|"move"|"issued", string|table
local function castAction(request, snapshot)
	local action = snapshot.actions[request.actionId]
	local definition = definitions[request.actionId]
	if not action or not action.exists then return "invalid", "Action is not present." end
	if request.actionId == "sun_strike" or request.actionId == "cataclysm" then
		if not action.invoked or action.activeSlotIndex == nil then
			return "wait", definitions[request.actionId].name .. " is not physically present in D/F yet."
		end
	end
	if action.cooldown > 0.05 or not action.activated or not Ability.IsCastable(action.ability, snapshot.hero.mana) then
		return "wait", "Action is not castable yet."
	end
	local castPosition = copyPoint(request.position)
	local cooldownBefore = Ability.GetCooldown(action.ability)
	local secondsBefore = Ability.SecondsSinceLastUse(action.ability)
	if request.actionId == "sun_strike" then
		local slotIndex = action.activeSlotIndex
		local keybind = ""
		local okKey, key = pcall(Ability.GetKeybind, action.ability)
		if okKey and key then keybind = tostring(key) end
		local okCastable, liveCastable = pcall(Ability.IsCastable, action.ability, snapshot.hero.mana)
		logDebug("SUN CAST", ("slot=%s key=%s activated=%s castable=%s cooldown=%.2f pos=%.0f,%.0f"):format(
			tostring(slotIndex or "?"), keybind, tostring(action.activated), tostring(okCastable and liveCastable or false),
			cooldownBefore, castPosition.x, castPosition.y))
	end
	issueOrder(function()
		if request.actionId == "cataclysm" then
			Ability.CastTarget(action.ability, state.hero, false, false, true, "invoker_ss_top_v18")
		elseif request.actionId == "sun_strike" then
			Ability.CastPosition(action.ability, toVector(castPosition))
		else
			Ability.CastNoTarget(action.ability, false, false, true, "invoker_ss_top_v18")
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

	-- Sun Strike must never be confirmed only from SecondsSinceLastUse().
	-- In this Umbrella build that signal produced false positives while cooldown stayed at zero,
	-- which made the script print "Sun confirmed" even though no real Sun Strike was cast.
	if pending.action.actionId == "sun_strike" or pending.action.actionId == "cataclysm" then
		local cooldownNow = Ability.GetCooldown(action.ability)
		return cooldownNow > math.max(0.05, (pending.cooldownBefore or 0) + 0.05)
	end

	local secondsSince = Ability.SecondsSinceLastUse(action.ability)
	return action.cooldown > pending.cooldownBefore + 0.05
		or secondsSince >= 0 and (pending.secondsBefore < 0 or secondsSince + 0.05 < pending.secondsBefore)
end










---Advances the active combo by at most one state transition.
---@param snapshot InvokerSnapshot
---@param settings table





function helpers.hasAutoSunMana(snapshot, settings, id)
	local actionId = id or "sun_strike"
	local manaAfter = snapshot.hero.mana - snapshot.actions[actionId].manaCost
	local reserve = actionId == "cataclysm" and (settings.cataclysmMinMana or 0) or (settings.sunMinMana or 0)
	return manaAfter >= 0 and manaAfter / math.max(1, snapshot.hero.maxMana) * 100 + 0.001 >= reserve
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

function helpers.autoSelfChargeEnabled(id, settings)
	if id == "sun_strike" then return settings and settings.sunSelfCharge == true end
	if id == "cataclysm" then return settings and settings.cataclysmSelfCharge == true end
	return true
end

function helpers.autoSpellReadyOrChargeable(id, snapshot, settings)
	local action = snapshot and snapshot.actions and snapshot.actions[id] or nil
	if not action or not action.exists then return false end
	if id ~= "sun_strike" and id ~= "cataclysm" then return true end
	if action.invoked and action.activeSlotIndex ~= nil then return true end
	return helpers.autoSelfChargeEnabled(id, settings)
		and snapshot.invoke and snapshot.invoke.exists == true
end

function helpers.objectiveSunReady(snapshot, settings)
	local action = snapshot.actions.sun_strike
	if not actionAvailable("sun_strike", snapshot, false)
		or action.cooldown > 0.05
		or not helpers.hasAutoSunMana(snapshot, settings)
		or not helpers.autoSpellReadyOrChargeable("sun_strike", snapshot, settings)
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

-- v25 direction lock: once a runner is accepted, aim from the direction the hero is following
-- RIGHT NOW, not from the older 1.5 s route centroid. Facing + instant motion are strongest when
-- they agree; recent motion remains the stabilizer. This is the user's "point 1, not point 2" rule.
function helpers.sunPriority.currentAimDirection(enemy)
	if not enemy then return nil end
	local facing = normalized2D(enemy.facing or {x = 0, y = 0, z = 0})
	local recent = normalized2D(enemy.recentVelocity or enemy.velocity or {x = 0, y = 0, z = 0})
	local instant = normalized2D(enemy.instantVelocity or enemy.recentVelocity or enemy.velocity or {x = 0, y = 0, z = 0})
	local facingValid = length2D(facing) > 0.5
	local recentValid = length2D(recent) > 0.5
	local instantValid = length2D(instant) > 0.5
	if not facingValid and not recentValid and not instantValid then return nil end
	if not recentValid then recent = instantValid and instant or facing end
	if not instantValid then instant = recent end
	if not facingValid then facing = instant end
	local faceRecent = math.deg(math.acos(clamp(dot2D(facing, recent), -1, 1)))
	local faceInstant = math.deg(math.acos(clamp(dot2D(facing, instant), -1, 1)))
	local recentInstant = math.deg(math.acos(clamp(dot2D(recent, instant), -1, 1)))
	local direction
	if faceRecent <= 30 and faceInstant <= 30 then
		direction = normalized2D(add(add(scale(facing, 0.55), scale(instant, 0.25)), scale(recent, 0.20)))
	elseif faceRecent <= 30 then
		direction = normalized2D(add(scale(facing, 0.70), scale(recent, 0.30)))
	elseif faceInstant <= 30 then
		direction = normalized2D(add(scale(facing, 0.70), scale(instant, 0.30)))
	elseif recentInstant <= 55 then
		direction = normalized2D(add(scale(instant, 0.60), scale(recent, 0.40)))
	else
		direction = recent
	end
	return length2D(direction) > 0.5 and direction or recent
end

-- v95 diagnostic only: record the REAL target route after an automatic runner Sun order until impact.
-- This never feeds back into prediction. It exists so the next video+log can distinguish predictor error
-- from a genuine post-order juke without another blind geometry change.
function helpers.beginSunPostCastTrace(target, pending, position, snapshot, issuedAt)
	if not target or not pending or pending.sunMode ~= "runner" or not position or not snapshot then return end
	local castDirection = pending.sunAimDirection or helpers.sunPriority.currentAimDirection(target)
		or normalized2D(target.instantVelocity or target.recentVelocity or target.velocity or target.facing)
	if not castDirection or length2D(castDirection) < 0.5 then castDirection = normalized2D(target.facing) end
	local startedAt = issuedAt or snapshot.now
	state.sunPostCastTrace = {
		targetIndex = target.index, issuedAt = startedAt,
		impactAt = startedAt + helpers.sunImpactDelay(snapshot, "sun_strike"),
		aim = copyPoint(position), castPosition = copyPoint(target.position),
		castDirection = copyPoint(castDirection), lastPosition = copyPoint(target.position),
		lastSampleAt = startedAt - (cfg.sunPostCastTraceInterval or 0.10),
		maxTurn = 0, samples = 0,
	}
	logDebug("SUN POST TRACE", ("start target=%d pos=%.0f,%.0f aim=%.0f,%.0f dir=%.2f,%.2f impactIn=%.2f"):format(
		target.index, target.position.x, target.position.y, position.x, position.y,
		castDirection.x or 0, castDirection.y or 0, state.sunPostCastTrace.impactAt - startedAt))
end

function helpers.updateSunPostCastTrace(snapshot)
	local trace = state and state.sunPostCastTrace or nil
	if not trace or not snapshot then return end
	local now = snapshot.now or GameRules.GetGameTime()
	local interval = cfg.sunPostCastTraceInterval or 0.10
	if now + 0.001 < (trace.lastSampleAt or -math.huge) + interval and now < (trace.impactAt or now) then return end
	trace.lastSampleAt = now
	local target = findEnemy(snapshot, trace.targetIndex)
	if target and target.position then
		local position = copyPoint(target.position)
		local displacement = subtract(position, trace.lastPosition or position)
		local observedDirection = length2D(displacement) > 2 and normalized2D(displacement)
			or helpers.sunPriority.currentAimDirection(target) or trace.castDirection
		local turnAngle = 0
		if observedDirection and trace.castDirection and length2D(observedDirection) > 0.5 and length2D(trace.castDirection) > 0.5 then
			turnAngle = math.deg(math.acos(clamp(dot2D(normalized2D(trace.castDirection), normalized2D(observedDirection)), -1, 1)))
		end
		trace.maxTurn = math.max(trace.maxTurn or 0, turnAngle)
		trace.samples = (trace.samples or 0) + 1
		local travelled = distance2D(trace.castPosition, position)
		local aimError = distance2D(position, trace.aim)
		local recent = target.recentVelocity or target.velocity or {x = 0, y = 0, z = 0}
		logDebug("SUN POST TRACE", ("target=%d t=%.2f pos=%.0f,%.0f aimDist=%.0f travelled=%.0f turn=%.0f speed=%.0f recent=%.0f,%.0f facing=%.2f,%.2f fog=%s"):format(
			trace.targetIndex, math.max(0, now - trace.issuedAt), position.x, position.y, aimError, travelled, turnAngle,
			math.max(length2D(target.instantVelocity or {x=0,y=0,z=0}), length2D(recent)),
			recent.x or 0, recent.y or 0, target.facing and target.facing.x or 0, target.facing and target.facing.y or 0,
			tostring(target.fogProjected == true)))
		trace.lastPosition = position
	else
		logDebug("SUN POST TRACE", ("target=%d t=%.2f unavailable"):format(
			trace.targetIndex or -1, math.max(0, now - (trace.issuedAt or now))))
	end
	if now >= (trace.impactAt or now) + 0.12 then
		logDebug("SUN POST TRACE", ("end target=%d samples=%d maxTurn=%.0f"):format(
			trace.targetIndex or -1, trace.samples or 0, trace.maxTurn or 0))
		state.sunPostCastTrace = nil
	end
end

-- v65: predicted Sun must use the target motion that exists at the final cast gate, not the
-- speed/direction remembered when the HP/route lock was first acquired.  This helper re-reads the
-- entity immediately before CastPosition and refreshes the shared motion track in-place.
function helpers.sunPriority.refreshCastMotion(enemy, snapshot)
	if not enemy or not enemy.entity or enemy.fogProjected or enemy.dormant or not enemy.visible then return enemy end
	local now = GameRules.GetGameTime()
	enemy.alive = Entity.IsAlive(enemy.entity)
	enemy.visible = NPC.IsVisible(enemy.entity)
	enemy.dormant = Entity.IsDormant(enemy.entity)
	if not enemy.alive or enemy.dormant or not enemy.visible then return enemy end
	enemy.health = Entity.GetHealth(enemy.entity)
	enemy.maxHealth = Entity.GetMaxHealth(enemy.entity)
	enemy.healthRegen = NPC.GetHealthRegen(enemy.entity)
	local modifiers, modifierCreatedAt, modifierExpiresAt = {}, {}, {}
	local teleporting, teleportRemaining, cycloneRemaining = false, 0, 0
	local disabledRemaining = helpers.immobileRemaining(enemy.entity)
	for _, modifier in ipairs(NPC.GetModifiers(enemy.entity)) do
		local name = Modifier.GetName(modifier)
		local remaining = modifierRemaining(modifier, now)
		modifiers[name] = remaining
		modifierCreatedAt[name] = Modifier.GetCreationTime(modifier)
		modifierExpiresAt[name] = now + math.max(0, remaining)
		if name == "modifier_teleporting" and remaining > 0 then
			teleporting = true
			teleportRemaining = math.max(teleportRemaining, remaining)
		end
		if name == "modifier_invoker_tornado" or name == "modifier_eul_cyclone" then
			cycloneRemaining = math.max(cycloneRemaining, remaining)
		end
	end
	if teleporting then
		helpers.quarantineTeleportMotion(enemy.index, now + teleportRemaining + (cfg.teleportMotionQuarantine or 0.55), "teleport_cast_refresh")
	end

	local position = copyPoint(Entity.GetAbsOrigin(enemy.entity))
	local moveSpeed = NPC.GetMoveSpeed(enemy.entity)
	local nativeMoving = NPC.IsRunning(enemy.entity)
	local velocity = updateMotion(enemy.index, position, now, moveSpeed, nativeMoving, "sun_cast_refresh")
	local liveVelocity = helpers.readEntityVelocity(enemy.entity)
	local track = state.motion[enemy.index]
	local turningOk, turning = pcall(NPC.IsTurning, enemy.entity)
	enemy.position = position
	enemy.velocity = velocity
	enemy.recentVelocity = track and copyPoint(track.recentVelocity or velocity) or copyPoint(velocity)
	enemy.instantVelocity = track and copyPoint(track.instantVelocity or velocity) or copyPoint(velocity)
	enemy.liveVelocity = liveVelocity and copyPoint(liveVelocity) or nil
	enemy.recentMotionConfidence = track and track.recentConfidence or 0
	enemy.turnRate = track and track.turnRate or 0
	enemy.acceleration = track and track.acceleration or 0
	enemy.nativeMoving = nativeMoving
	enemy.turning = turningOk and turning == true
	enemy.facing = copyPoint(Entity.GetRotation(enemy.entity):GetForward())
	enemy.moveSpeed = moveSpeed
	enemy.moving = nativeMoving or length2D(velocity) >= 20 or liveVelocity and length2D(liveVelocity) >= 20
	enemy.motionConfidence = track and track.confidence or enemy.motionConfidence or 0
	enemy.movementDuration = track and track.walkingSince ~= math.huge and math.max(0, now - track.walkingSince) or 0
	enemy.stableDuration = track and track.stableSince ~= math.huge and math.max(0, now - track.stableSince) or 0
	enemy.idleDuration = track and track.idleSince ~= math.huge and math.max(0, now - track.idleSince) or 0
	enemy.modifiers = modifiers
	enemy.modifierCreatedAt = modifierCreatedAt
	enemy.modifierExpiresAt = modifierExpiresAt
	enemy.teleporting = teleporting
	enemy.teleportRemaining = teleportRemaining
	enemy.disabledUntil = now + disabledRemaining
	enemy.controlEndsAt = cycloneRemaining > 0 and now + cycloneRemaining or 0
	enemy.controlPosition = cycloneRemaining > 0 and copyPoint(position) or nil
	enemy.stunned = NPC.IsStunned(enemy.entity)
	enemy.rooted = NPC.HasState(enemy.entity, Enum.ModifierState.MODIFIER_STATE_ROOTED)
	enemy.invulnerable = NPC.HasState(enemy.entity, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE)
	enemy.outOfGame = NPC.HasState(enemy.entity, Enum.ModifierState.MODIFIER_STATE_OUT_OF_GAME)
	enemy.debuffImmune = NPC.HasState(enemy.entity, Enum.ModifierState.MODIFIER_STATE_DEBUFF_IMMUNE)
	enemy.magicImmune = NPC.HasState(enemy.entity, Enum.ModifierState.MODIFIER_STATE_MAGIC_IMMUNE)
	enemy.channeling = NPC.IsChannellingAbility(enemy.entity)
	helpers.observeSunSpeedState(enemy, now, true)
	return enemy
end

function helpers.sunPriority.castMotionSpeed(enemy)
	if not enemy then return 0, "none" end
	local live = enemy.liveVelocity and length2D(enemy.liveVelocity) or 0
	local recent = length2D(enemy.recentVelocity or enemy.velocity or {x = 0, y = 0, z = 0})
	local instant = length2D(enemy.instantVelocity or enemy.recentVelocity or enemy.velocity or {x = 0, y = 0, z = 0})
	local long = length2D(enemy.velocity or {x = 0, y = 0, z = 0})
	if live >= 20 then return live, "live" end
	if instant >= 20 then return instant, "instant" end
	if recent >= 20 then return recent, "recent" end
	return long, "long"
end

-- v62 runner gate: topology-first decision. GridNav branches are built before motion weighting;
-- route entropy and temporal stability now prevent broad endpoint coverage from masking an unstable route family.
function helpers.sunPriority.runnerRouteGate(enemy, snapshot, settings)
	local track = enemy and state.motion[enemy.index] or nil
	local required = math.max(0.30, settings and settings.sunWalkTime or 1.5)
	local meta = enemy and enemy.sunAimMeta or {}
	local result = {
		passed = false, reason = "no_history", observed = 0, straightness = 0,
		lateral = 0, corridor = 0, offAxisShare = 1, recentLongAngle = 180, instantRecentAngle = 180,
		terrainStatus = meta.terrainStatus or "unknown", terrainCoverage = meta.covered or 0,
		dominantWeight = meta.dominantWeight or 0, routeCount = meta.routeCount or 0,
		terrainFork = meta.terrainFork == true, terrainForcedTurn = meta.terrainForcedTurn == true,
		historyScore = 0, terrainConfidence = meta.terrainConfidence or 0, routeEntropy = meta.routeEntropy or 0,
		terrainStability = meta.terrainStability or 0, topologyBranches = meta.topologyBranches or 0,
		topologyBlocked = meta.topologyBlocked or 0, topologyFarBlocked = meta.topologyFarBlocked or 0,
	}
	if not track or not track.routeSamples or #track.routeSamples < 3 then
		if enemy then enemy.sunRouteGate = result end
		return result
	end
	local samples = track.routeSamples
	local newest = samples[#samples]
	local cutoff = newest.at - required
	local startIndex = 1
	for i = #samples - 1, 1, -1 do
		startIndex = i
		if samples[i].at <= cutoff then break end
	end
	local first = samples[startIndex]
	result.observed = math.max(0, newest.at - first.at)
	if result.observed < required - 0.08 then
		result.reason = "history"
		enemy.sunRouteGate = result
		return result
	end
	local routeVector = subtract(newest.position, first.position)
	local netDistance = length2D(routeVector)
	if netDistance < 20 then
		result.reason = "no_progress"
		enemy.sunRouteGate = result
		return result
	end
	local routeDirection = normalized2D(routeVector)
	local pathDistance, offAxisDistance, maxLateral = 0, 0, 0
	local offAxisDot = math.cos(math.rad(42))
	for i = startIndex + 1, #samples do
		local segment = subtract(samples[i].position, samples[i - 1].position)
		local segmentDistance = length2D(segment)
		if segmentDistance >= 1 then
			pathDistance = pathDistance + segmentDistance
			if dot2D(routeDirection, normalized2D(segment)) < offAxisDot then offAxisDistance = offAxisDistance + segmentDistance end
		end
		local relative = subtract(samples[i].position, first.position)
		local lateral = math.abs(relative.x * routeDirection.y - relative.y * routeDirection.x)
		if lateral > maxLateral then maxLateral = lateral end
	end
	result.straightness = clamp(netDistance / math.max(1, pathDistance), 0, 1)
	result.offAxisShare = clamp(offAxisDistance / math.max(1, pathDistance), 0, 1)
	result.lateral = maxLateral
	result.corridor = clamp(cfg.sunRadius * 0.58 + math.max(0, enemy.moveSpeed or 0) * 0.025, 92, 118)
	local longSpeed = length2D(enemy.velocity or {x = 0, y = 0, z = 0})
	local recentSpeed = length2D(enemy.recentVelocity or enemy.velocity or {x = 0, y = 0, z = 0})
	local instantSpeed = length2D(enemy.instantVelocity or enemy.recentVelocity or enemy.velocity or {x = 0, y = 0, z = 0})
	local longDirection = longSpeed > 35 and normalized2D(enemy.velocity) or routeDirection
	local recentDirection = recentSpeed > 35 and normalized2D(enemy.recentVelocity) or longDirection
	local instantDirection = instantSpeed > 35 and normalized2D(enemy.instantVelocity) or recentDirection
	result.recentLongAngle = math.deg(math.acos(clamp(dot2D(longDirection, recentDirection), -1, 1)))
	result.instantRecentAngle = math.deg(math.acos(clamp(dot2D(recentDirection, instantDirection), -1, 1)))
	-- Open ground cannot justify a turn: disagreement with facing means the observed
	-- motion may still describe the old route. Wait for fresh motion instead of treating
	-- a one-branch terrain model as evidence of certainty. Forced terrain turns retain
	-- their path-based gate because facing can legitimately lag around corners.
	local facingDirection = normalized2D(enemy.facing or {x = 0, y = 0, z = 0})
	local openDirectionUnsettled = result.topologyBlocked == 0 and not result.terrainForcedTurn
		and instantSpeed > 35 and length2D(facingDirection) > 0.5
		and dot2D(instantDirection, facingDirection) < 0.819152
	result.zigzagRisk, result.zigzagAlternations = helpers.sunRecentZigzag(samples)
	result.historyScore = helpers.sunTerrainHistoryScore(result,
		result.terrainForcedTurn and result.dominantWeight >= 0.62, settings and settings.antiZigzag)
	local coverage = result.terrainCoverage
	local dominant = result.dominantWeight
	local terrainCore = clamp(coverage * 0.48 + dominant * 0.27 + (1 - result.routeEntropy) * 0.15
		+ result.terrainStability * 0.10, 0, 1)
	result.terrainConfidence = clamp(terrainCore * 0.70 + result.historyScore * 0.18
		+ clamp(enemy.motionConfidence or 0, 0, 1) * 0.12, 0, 1)
	if enemy.fogProjected and (enemy.fogAge or math.huge) > cfg.fogRouteTTL then
		result.reason = "fog_speed_stale"
	elseif meta.source == "stop-grace" or (not enemy.fogProjected and enemy.nativeMoving == false and not enemy.moving) then
		-- Historical velocity is not proof that a currently stopped hero will resume.
		-- The independent idle/controlled modes retain their own eligibility rules.
		result.reason = "runner_stop_transition"
	elseif result.terrainStatus == "unavailable" then
		result.reason = "terrain_unavailable"
	elseif openDirectionUnsettled then
		result.reason = "direction_unsettled"
	elseif (meta.terrainFallbackWeight or 0) >= 0.34 then
		result.reason = "terrain_fallback"
	elseif result.terrainFork and coverage < cfg.sunTerrainForkCoverage then
		result.reason = "terrain_fork"
	elseif result.topologyBlocked > 0 and result.routeEntropy >= cfg.sunTerrainEntropyGate and dominant < 0.58 and coverage < 0.98 then
		result.reason = "terrain_entropy"
	elseif result.topologyBlocked > 0 and result.routeCount > 1 and result.terrainStability < cfg.sunTerrainTemporalGate then
		result.reason = "terrain_unstable"
	elseif coverage < cfg.sunTerrainMinCoverage then
		result.reason = "terrain_coverage"
	elseif settings and settings.antiZigzag ~= false and result.zigzagRisk >= 0.65 then
		result.reason = "zigzag_recent_reversal"
	elseif settings and settings.antiZigzag ~= false and result.historyScore < 0.48
		and not (result.terrainForcedTurn and dominant >= 0.68)
	then
		result.reason = "zigzag_unexplained"
	elseif result.terrainConfidence < cfg.sunTerrainGateConfidence then
		result.reason = "terrain_confidence"
	else
		result.passed = true
		result.reason = result.terrainForcedTurn and dominant >= 0.68 and "terrain_forced_turn"
			or result.terrainStatus == "converge" and "terrain_converge"
			or result.terrainStatus == "open" and "terrain_open"
			or "terrain_route"
	end
	enemy.sunRouteGate = result
	if track.lastSunRouteGatePass ~= result.passed or track.lastSunRouteGateReason ~= result.reason then
		track.lastSunRouteGatePass = result.passed
		track.lastSunRouteGateReason = result.reason
		if settings and settings.antiZigzag ~= false then
			logDebug("ZIGZAG", ("target=%d risk=%.2f alternations=%d forced=%s coverage=%.2f reason=%s"):format(
				enemy.index, result.zigzagRisk or 0, result.zigzagAlternations or 0,
				tostring(result.terrainForcedTurn), result.terrainCoverage, result.reason))
		end
		logDebug("ROUTE GATE", ("target=%d pass=%s reason=%s observed=%.2f/%.2f terrain=%s coverage=%.2f dominant=%.2f routes=%d branches=%d blocked=%d farBlocked=%d entropy=%.2f stable=%.2f fork=%s forced=%s tconf=%.2f history=%.2f straight=%.2f lateral=%.0f/%.0f off=%.2f recentLong=%.0f instantRecent=%.0f"):format(
			enemy.index, tostring(result.passed), result.reason, result.observed, required, result.terrainStatus,
			result.terrainCoverage, result.dominantWeight, result.routeCount, result.topologyBranches, result.topologyBlocked, result.topologyFarBlocked, result.routeEntropy, result.terrainStability,
			tostring(result.terrainFork), tostring(result.terrainForcedTurn), result.terrainConfidence, result.historyScore, result.straightness,
			result.lateral, result.corridor, result.offAxisShare, result.recentLongAngle, result.instantRecentAngle))
	end
	return result
end

-- v27 keeps the v26 HP latch: separate "this target is lethal" from "we are allowed to prepare/cast now".
-- A lethal target is remembered immediately while Sun is ready, but this logical latch issues NO orders.
-- Runner route/Anti-Zigzag and Invoke readiness remain a second-stage permission gate.
function helpers.sunPriority.releaseHpLatch(reason)
	local latch = state and state.sunHpLatch or nil
	if not latch then return end
	logDebug("SUN HP LOCK", ("release target=%d reason=%s age=%.2f"):format(
		latch.targetIndex or -1, tostring(reason or "unknown"), math.max(0, (state.now or 0) - (latch.lockedAt or state.now or 0))))
	state.sunHpLatch = nil
end

-- Normal Auto Sun must never keep aiming at a hero's pre-TP/current position once that hero has
-- started teleporting. The landing/TP subsystem owns this target until the channel ends/cancels; if
-- its configured TP mode accepts the target it will aim at the confirmed destination instead.
function helpers.normalAutoSunTeleportBlocked(enemy, snapshot)
	if not enemy then return false, nil end
	local now = snapshot and snapshot.now or state.now or GameRules.GetGameTime()
	local record = state.landings and state.landings[enemy.index] or nil
	local recordActive = record and record.kind == "teleport" and not record.cancelled and not record.fired
		and record.endsAt and record.endsAt > now - cfg.landingMaxLate
	local snapshotActive = enemy.teleporting == true and (enemy.teleportRemaining or 0) > 0
	local particleVeto, particleSource = helpers.pendingTeleportVeto(enemy.index, now)
	if not recordActive and not snapshotActive and not particleVeto then return false, record end
	local source = recordActive and (record.departureOwnerSource or "landing")
		or snapshotActive and "modifier" or particleSource or "particle"
	logChanged("tp_normal_sun_block_" .. tostring(enemy.index), "TP NORMAL SUN VETO",
		("target=%d teleport=true source=%s -> NORMAL AUTO SUN SKIP"):format(enemy.index, tostring(source)))
	return true, record
end

-- v55/v60: independent physical-stationary proof for NORMAL Auto Sun only.  It intentionally does NOT
-- rewrite state.motion, runner history, Anti-Zigzag, prediction, or any combo subsystem.  v60 extends
-- the same proof across a short fog/tree occlusion, but ONLY from contiguous OBSERVED samples that had
-- already proved the stop before vision was lost. Projected/reconciled fog samples can never manufacture
-- stationary evidence. This prevents stale runner momentum from dragging a truly standing hidden target.
function helpers.sunPriority.nativeIdleReady(enemy, settings)
	return enemy ~= nil and not enemy.fogProjected and enemy.nativeMoving ~= true
		and not enemy.moving and length2D(enemy.velocity) < 20
		and (enemy.idleDuration or 0) >= math.max(0.35, settings.sunIdleTime or 0)
end

function helpers.sunPriority.stationaryEvidence(enemy, snapshot, settings)
	local result = {passed = false, reason = "no_history", observed = 0, maxRadius = math.huge, path = math.huge,
		position = nil, fog = false, fogAge = 0}
	if not enemy then return result end
	if not enemy.fogProjected and ((enemy.idleDuration or 0) < math.max(0.35, settings and settings.sunIdleTime or 0)
		or enemy.nativeMoving == true) then
		result.reason = "stop_not_settled"
		return result
	end
	local track = state.motion and state.motion[enemy.index] or nil
	if not track or not track.routeSamples or #track.routeSamples < 2 then return result end
	local samples = track.routeSamples
	local now = snapshot and snapshot.now or state.now or samples[#samples].at
	local fog = enemy.fogProjected == true
	local newestIndex, newest, anchor
	if fog then
		local fogAge = enemy.fogAge or math.huge
		result.fog, result.fogAge = true, fogAge
		if fogAge > cfg.fogRouteTTL or not track.lastObservedPosition or not track.lastObservedAt then
			result.reason = fogAge > cfg.fogRouteTTL and "fog_expired" or "no_observed_anchor"
			return result
		end
		anchor = copyPoint(track.lastObservedPosition)
		for i = #samples, 1, -1 do
			local sample = samples[i]
			if sample.source == "observed" and sample.at <= track.lastObservedAt + 0.08 then
				newestIndex, newest = i, sample
				break
			end
		end
		if not newest or math.abs((track.lastObservedAt or newest.at) - newest.at) > 0.20 then
			result.reason = "stale_observed_history"
			return result
		end
	else
		newestIndex, newest = #samples, samples[#samples]
		anchor = enemy.position and copyPoint(enemy.position) or copyPoint(newest.position)
		if now - newest.at > 0.20 then
			result.reason = "stale_history"
			return result
		end
	end

	local required = math.max(cfg.sunStationaryMinWindow, settings and settings.sunIdleTime or cfg.sunStationaryMinWindow)
	local cutoff = newest.at - required
	local startIndex = nil
	for i = newestIndex - 1, 1, -1 do
		local sample = samples[i]
		if fog and sample.source ~= "observed" then break end
		if sample.at <= cutoff then
			startIndex = i
			break
		end
	end
	if not startIndex then
		result.reason = "history"
		return result
	end
	local first = samples[startIndex]
	result.observed = math.max(0, newest.at - first.at)
	if result.observed < required - 0.08 then
		result.reason = "history"
		return result
	end

	local maxRadius = 0
	local path = 0
	for i = startIndex, newestIndex do
		local sample = samples[i]
		if fog and sample.source ~= "observed" then
			result.reason = "observed_gap"
			return result
		end
		maxRadius = math.max(maxRadius, distance2D(sample.position, anchor))
		if i > startIndex then path = path + distance2D(samples[i - 1].position, sample.position) end
	end
	path = path + distance2D(newest.position, anchor)
	result.maxRadius = maxRadius
	result.path = path
	result.position = copyPoint(anchor)
	if maxRadius <= cfg.sunStationaryRadius and path <= cfg.sunStationaryPath then
		result.passed = true
		result.reason = fog and "observed_stationary_fog" or "physical_stationary"
	elseif maxRadius > cfg.sunStationaryRadius then
		result.reason = "radius"
	else
		result.reason = "path"
	end
	enemy.sunStationaryEvidence = result
	return result
end

function helpers.sunPriority.logWhyHold(enemy, snapshot, reason, detail)
	if not enemy then return end
	local latch = state.sunHpLatch
	if not latch or latch.targetIndex ~= enemy.index then return end
	local age = math.max(0, (snapshot and snapshot.now or state.now or 0) - (latch.lockedAt or snapshot.now or state.now or 0))
	logChanged("sun_why_hold_" .. tostring(enemy.index), "SUN WHY HOLD",
		("target=%d age=%.2f reason=%s%s"):format(enemy.index, age, tostring(reason or "unknown"), detail and (" " .. detail) or ""))
end

function helpers.sunPriority.hpCandidate(enemy, snapshot, settings)
	local fogRoute = settings.fogRouteSun and enemy and enemy.fogProjected and (enemy.fogAge or math.huge) <= cfg.fogRouteTTL
	if not settings.sunStrike or not enemy or not enemy.alive
		or (not fogRoute and (not enemy.visible or enemy.dormant))
		or enemy.invulnerable or enemy.outOfGame
	then
		return nil
	end
	-- v85: portrait X owns only ordinary Auto SS for this exact portrait. A target that is visibly
	-- hard-controlled NOW is evaluated by the dedicated control path and must not be pre-empted by X.
	local controlledNow = helpers.sunPriority.controlValidForOrder(enemy, snapshot, settings)
	if not controlledNow and helpers.movingSunBlocked(enemy, settings) then return nil end
	if helpers.normalAutoSunTeleportBlocked(enemy, snapshot) then return nil end
	local action = snapshot.actions.sun_strike
	if not action or not action.exists or action.cooldown > 0.05
		or not helpers.autoSpellReadyOrChargeable("sun_strike", snapshot, settings)
	then return nil end

	local mechanics = resolveMechanics("sun_strike", snapshot, 0)
	local impactDelay = helpers.sunImpactDelay(snapshot, "sun_strike")
	local stationary = helpers.sunPriority.stationaryEvidence(enemy, snapshot, settings)
	local prediction = predictIntercept(snapshot, "sun_strike", enemy, snapshot.now, enemy.motionConfidence)
	local aimPosition = controlledNow and copyPoint(enemy.position)
		or stationary.passed and stationary.position and copyPoint(stationary.position) or copyPoint(prediction.position)
	local splitCount = sunSplitCount(snapshot, aimPosition, math.max(cfg.sunRadius, mechanics.radius), enemy.index, impactDelay)
	local expectedDamage = mechanics.expectedDamage / splitCount
	local impactHealth = math.min(enemy.maxHealth, enemy.health + math.max(0, enemy.healthRegen) * impactDelay)
	if impactHealth > expectedDamage then return nil end
	return {
		impactHealth = impactHealth,
		expectedDamage = expectedDamage,
		splitCount = splitCount,
		prediction = aimPosition,
		fogRoute = fogRoute == true,
		stationaryForSun = stationary.passed == true,
	}
end

-- Hard safety for automatic lethal Sun Strike. HP may be latched once, but damage sharing is dynamic:
-- creeps/heroes can enter the future Sun AoE while route/Invoke preparation is still pending.
-- Re-evaluate ONLY the current split count against the HP reference that was already accepted; do not
-- re-run the target's HP qualification. This can hold preparation/cast, but never changes target identity.
function helpers.sunPriority.splitSafety(target, snapshot, referenceHp, forcedPosition)
	if not target or not referenceHp then return false, 1, 0, forcedPosition end
	local mechanics = resolveMechanics("sun_strike", snapshot, 0)
	local impactDelay = helpers.sunImpactDelay(snapshot, "sun_strike")
	local position = forcedPosition or predictIntercept(snapshot, "sun_strike", target, snapshot.now, target.motionConfidence).position
	local splitCount = sunSplitCount(snapshot, position, math.max(cfg.sunRadius, mechanics.radius), target.index, impactDelay)
	local expectedDamage = mechanics.expectedDamage / splitCount
	return expectedDamage + 0.001 >= referenceHp, splitCount, expectedDamage, position
end

function helpers.sunPriority.updateHpLatch(snapshot, settings)
	if not state then return nil end
	if not settings.sunStrike then
		helpers.sunPriority.releaseHpLatch("auto Sun disabled")
		return nil
	end
	-- v65: do not acquire/release the same lethal lock every frame while Invoker is invisible.
	-- The higher-level executor may still allow an explicit manual portrait Sun, but normal Auto Sun
	-- has no reason to create a logical HP lock until automatic casting is allowed again.
	if snapshot.hero and snapshot.hero.invisible then
		if state.sunHpLatch then helpers.sunPriority.releaseHpLatch("Invoker invisible") end
		return nil
	end
	local action = snapshot.actions.sun_strike
	if not action or not action.exists or action.cooldown > 0.05 then
		if state.sunHpLatch then helpers.sunPriority.releaseHpLatch("Sun cooldown/not ready") end
		return nil
	end
	if not helpers.autoSpellReadyOrChargeable("sun_strike", snapshot, settings) then
		if state.sunHpLatch then helpers.sunPriority.releaseHpLatch("Sun self-charge disabled and Sun not in D/F") end
		return nil
	end

	local latch = state.sunHpLatch
	if latch then
		local target = findEnemy(snapshot, latch.targetIndex)
		local tracked = target and ((target.visible and not target.dormant)
			or (settings.fogRouteSun and target.fogProjected and (target.fogAge or math.huge) <= cfg.fogRouteTTL))
		if not target or not target.alive or target.invulnerable or target.outOfGame or not tracked then
			helpers.sunPriority.releaseHpLatch(not tracked and "fog track lost" or "target invalid")
		elseif not helpers.sunPriority.controlValidForOrder(target, snapshot, settings) and helpers.movingSunBlocked(target, settings) then
			helpers.sunPriority.logWhyHold(target, snapshot, "X_BLOCK", "portrait X blocks this ordinary Auto SS state")
			helpers.sunPriority.releaseHpLatch("portrait X normal Auto-SS block active")
		elseif helpers.normalAutoSunTeleportBlocked(target, snapshot) then
			helpers.sunPriority.logWhyHold(target, snapshot, "TP_PRIORITY", "landing destination owns target")
			helpers.sunPriority.releaseHpLatch("target started teleport -> TP destination priority")
		else
			target.sunHpLatch = latch
			logChanged("sun_hp_latch_state_" .. tostring(target.index), "SUN HP LOCK",
				("hold target=%d fog=%s age=%.2f hpLock=%.0f/%.0f"):format(target.index,
					tostring(target.fogProjected == true), target.fogAge or 0, latch.impactHealth or 0, latch.expectedDamage or 0))
			return target
		end
	end

	local best, bestCandidate
	for _, enemy in ipairs(snapshot.enemies) do
		local candidate = helpers.sunPriority.hpCandidate(enemy, snapshot, settings)
		if candidate and (not bestCandidate or candidate.impactHealth < bestCandidate.impactHealth) then
			best, bestCandidate = enemy, candidate
		end
	end
	if not best or not bestCandidate then return nil end

	state.sunHpLatch = {
		targetIndex = best.index,
		lockedAt = snapshot.now,
		impactHealth = bestCandidate.impactHealth,
		expectedDamage = bestCandidate.expectedDamage,
		splitCount = bestCandidate.splitCount,
		prediction = copyPoint(bestCandidate.prediction),
		fogAtLock = bestCandidate.fogRoute == true,
	}
	best.sunHpLatch = state.sunHpLatch
	logDebug("SUN HP LOCK", ("acquire target=%d hpImpact=%.0f damage=%.0f split=%d fog=%s -> wait route/Invoke, NO PRECHARGE"):format(
		best.index, bestCandidate.impactHealth, bestCandidate.expectedDamage, bestCandidate.splitCount, tostring(bestCandidate.fogRoute == true)))
	return best
end

---Evaluates a candidate for automatic Sun Strike. Reliability outranks raw low HP.
function helpers.autoUseModePass(mode, projectedHealth, maxHealth, expectedDamage, currentHpPercent, hpLimit)
	mode = clamp(mode or 0, 0, 3)
	projectedHealth = math.max(0, projectedHealth or math.huge)
	maxHealth = math.max(1, maxHealth or 1)
	expectedDamage = math.max(0, expectedDamage or 0)
	currentHpPercent = clamp(currentHpPercent or 100, 0, 100)
	hpLimit = clamp(hpLimit or 100, 1, 100)
	if mode == 0 then return true, "always", expectedDamage end
	if mode == 1 then return projectedHealth <= expectedDamage + 0.001, "lethal", expectedDamage end
	if mode == 2 then
		local threshold = expectedDamage * (cfg.autoUseNearLethalFactor or 1.20)
		return projectedHealth <= threshold + 0.001, "near_lethal", threshold
	end
	return currentHpPercent <= hpLimit + 0.001, "hp", hpLimit
end

function helpers.sunPriority.controlValidForOrder(enemy, snapshot, settings)
	local now = snapshot and snapshot.now or state.now or 0
	local controlEndsAt = enemy and math.max(enemy.disabledUntil or 0, enemy.controlEndsAt or 0) or 0
	local visibleControl = enemy ~= nil and enemy.visible == true and enemy.dormant ~= true and enemy.fogProjected ~= true
	-- A shot aimed at the current position requires control through impact, including a margin.
	local impactDelay = snapshot and helpers.sunImpactDelay(snapshot, "sun_strike") or math.huge
	local allowed = settings and settings.useControlledTargets == true and visibleControl
		and controlEndsAt >= now + impactDelay + 0.10
	return allowed, controlEndsAt, visibleControl
end

---@param enemy EnemyState
---@param snapshot InvokerSnapshot
---@param settings table
---@return table?
local sunFlightRules = {
	npc_dota_hero_mirana = {abilities = {"mirana_leap"}, modifiers = {}},
	npc_dota_hero_slark = {abilities = {"slark_pounce"}, modifiers = {}},
	npc_dota_hero_magnataur = {abilities = {"magnataur_skewer"}, modifiers = {}},
	npc_dota_hero_morphling = {abilities = {"morphling_waveform"}, modifiers = {}},
	npc_dota_hero_storm_spirit = {abilities = {"storm_spirit_ball_lightning"}, modifiers = {}},
	npc_dota_hero_faceless_void = {abilities = {"faceless_void_time_walk"}, modifiers = {}},
	npc_dota_hero_earth_spirit = {abilities = {"earth_spirit_rolling_boulder"}, modifiers = {}},
	npc_dota_hero_spirit_breaker = {abilities = {"spirit_breaker_charge_of_darkness"}, modifiers = {}},
	npc_dota_hero_pangolier = {abilities = {"pangolier_swashbuckle"}, modifiers = {}},
	npc_dota_hero_primal_beast = {abilities = {"primal_beast_onslaught"}, modifiers = {}},
	npc_dota_hero_sand_king = {abilities = {"sandking_burrowstrike"}, modifiers = {}},
	npc_dota_hero_void_spirit = {abilities = {"void_spirit_astral_step"}, modifiers = {}},
	npc_dota_hero_techies = {
		abilities = {"techies_suicide"}, modifiers = {"modifier_techies_suicide_leap"},
	},
	npc_dota_hero_phoenix = {
		abilities = {"phoenix_icarus_dive", "phoenix_sun_ray", "phoenix_supernova"},
		modifiers = {"modifier_phoenix_icarus_dive", "modifier_phoenix_sun_ray", "modifier_phoenix_supernova_hiding"},
	},
}

-- Exact client modifier classes from SteamTracking/GameTracking-Dota2 schemas.
-- Check the affected unit, not its hero name: Force Staff, Skewer victims and
-- friendly Snowball passengers can belong to ANY hero. Buffs/trackers are not motion.
local sunMovementClasses = {}
for _, suffix in ipairs({
	"EarthSpirit_RollingBoulder_Caster", "Earthshaker_EnchantTotem_Leap",
	"FacelessVoid_TimeWalk", "ForceStaff", "Hurricane_Pike_Active", "Hurricane_Pike_Active_Alternate",
	"Magnataur_Skewer_Movement", "Mirana_Leap", "MonkeyKing_BounceLeap", "Morphling_Waveform",
	"Pangolier_Swashbuckle", "Phoenix_IcarusDive", "Phoenix_SunRay",
	"PrimalBeast_Onslaught_Movement", "PrimalBeast_Onslaught_Windup", "PrimalBeast_Onslaught_Knockback",
	"Sand_King_BurrowStrike", "Slark_Pounce", "SpiritBreaker_ChargeOfDarkness",
	"StormSpirit_BallLightning", "Techies_Suicide_Leap", "Tusk_Snowball_Movement",
	"Tusk_Snowball_Movement_Friendly", "VoidSpirit_AstralStep_Caster",
}) do sunMovementClasses["CDOTA_Modifier_" .. suffix] = true end

function helpers.sunPriority.flightBlockReason(enemy, fresh)
	if not enemy or not enemy.entity then return nil end
	if not fresh and enemy.sunFlightChecked then return enemy.sunFlightBlockReason end
	-- Do not infer the end of an observed flight from stale fog data.
	if enemy.fogProjected or enemy.dormant or not enemy.visible then return enemy.sunFlightBlockReason end
	for _, modifier in ipairs(NPC.GetModifiers(enemy.entity)) do
		if sunMovementClasses[Modifier.GetClass(modifier)] then
			return "movement_modifier:" .. Modifier.GetName(modifier)
		end
	end
	local rule = sunFlightRules[NPC.GetUnitName(enemy.entity)]
	if not rule then return nil end
	for _, name in ipairs(rule.modifiers) do
		if NPC.GetModifier(enemy.entity, name) then return "flight_modifier:" .. name end
	end
	for _, name in ipairs(rule.abilities) do
		local ability = NPC.GetAbility(enemy.entity, name)
		if ability and Ability.IsInAbilityPhase(ability) then return "flight_cast_phase:" .. name end
	end
	return nil
end

function helpers.sunPriority.motionTransitionSafe(enemy, snapshot, settings)
	local flightReason = helpers.sunPriority.flightBlockReason(enemy)
	if flightReason then return false, flightReason end
	if helpers.sunPriority.controlValidForOrder(enemy, snapshot, settings) then return true end
	-- A false native order flag is not evidence of a stop while measured motion
	-- still classifies the target as running. Only actual idle candidates settle.
	if not enemy.fogProjected and enemy.nativeMoving == false and not enemy.moving then
		if (enemy.idleDuration or 0) < math.max(0.35, settings.sunIdleTime or 0) then
			return false, "stop_not_settled"
		end
	end
	-- Temporary slows/haste are handled by the live speed/terrain aim calculation.
	-- Their presence or remaining duration alone must never veto a cast.
	return true
end

function helpers.sunPriority.evaluateAutoSun(enemy, snapshot, settings)
	local fogRoute = settings.fogRouteSun and enemy and enemy.fogProjected and (enemy.fogAge or math.huge) <= cfg.fogRouteTTL
	if not settings.sunStrike or not helpers.hasAutoSunMana(snapshot, settings)
		or not enemy or not enemy.alive or (not fogRoute and (not enemy.visible or enemy.dormant))
		or enemy.invulnerable or enemy.outOfGame
	then
		return nil
	end
	-- v87: detect current hard control before X, but defer the X verdict until the selected control
	-- auto-use policy is known. X may be bypassed only by a control shot that actually qualifies.
	local controlled, controlEndsAt = helpers.sunPriority.controlValidForOrder(enemy, snapshot, settings)
	local transitionSafe, transitionReason = helpers.sunPriority.motionTransitionSafe(enemy, snapshot, settings)
	if not transitionSafe then
		helpers.sunPriority.logWhyHold(enemy, snapshot, "TRANSITION", transitionReason)
		return nil
	end
	local xBlocked = helpers.movingSunBlocked(enemy, settings)
	if helpers.normalAutoSunTeleportBlocked(enemy, snapshot) then
		helpers.sunPriority.logWhyHold(enemy, snapshot, "TP_PRIORITY", "landing destination owns target")
		return nil
	end

	local action = snapshot.actions.sun_strike
	if not action or not action.exists or action.cooldown > 0.05
		or not helpers.autoSpellReadyOrChargeable("sun_strike", snapshot, settings)
	then
		helpers.sunPriority.logWhyHold(enemy, snapshot, "SUN_NOT_READY", action and ("cooldown=%.2f"):format(action.cooldown or -1) or "ability_missing")
		return nil
	end

	local hpLatch = state.sunHpLatch and state.sunHpLatch.targetIndex == enemy.index and state.sunHpLatch or nil
	-- Non-runner Auto Sun modes keep the old <=0.35 s bridge. RUNNER is still strict: no reservation,
	-- no EEE and no Invoke until the v58-v60 terrain-first route gate passes and Invoke is ready now.
	local invokeWait = action.invoked and 0 or snapshot.invoke and math.max(0, snapshot.invoke.cooldown or 0) or math.huge
	local invokeReadyNow = action.invoked or snapshot.invoke and snapshot.invoke.exists and snapshot.invoke.ready == true
	local canStartSoon = action.invoked or snapshot.invoke and snapshot.invoke.exists and invokeWait <= 0.35
	if not canStartSoon then
		helpers.sunPriority.logWhyHold(enemy, snapshot, "INVOKE_WAIT", ("remaining=%.2f"):format(invokeWait == math.huge and -1 or invokeWait))
		return nil
	end

	local mechanics = resolveMechanics("sun_strike", snapshot, 0)
	local impactDelay = helpers.sunImpactDelay(snapshot, "sun_strike")
	local impactAt = snapshot.now + impactDelay
	local speed = length2D(enemy.velocity)
	local stationary = helpers.sunPriority.stationaryEvidence(enemy, snapshot, settings)
	local stationaryForSun = stationary.passed == true
	if stationaryForSun and hpLatch then
		logChanged("sun_stationary_" .. tostring(enemy.index), "SUN STATIONARY",
			("target=%d source=%s observed=%.2f radius=%.1f/%d path=%.1f/%d fogAge=%.2f native=%s speed=%.0f aim=%.0f,%.0f -> IDLE OVERRIDE"):format(
				enemy.index, stationary.fog and "fog-observed" or "visible", stationary.observed or 0,
				stationary.maxRadius or 0, cfg.sunStationaryRadius, stationary.path or 0, cfg.sunStationaryPath,
				stationary.fogAge or 0, tostring(enemy.nativeMoving == true), speed,
				stationary.position and stationary.position.x or enemy.position.x,
				stationary.position and stationary.position.y or enemy.position.y))
	end
	local prediction = predictIntercept(snapshot, "sun_strike", enemy, snapshot.now, enemy.motionConfidence)
	local normalPredictionPosition = stationaryForSun and stationary.position and copyPoint(stationary.position) or copyPoint(prediction.position)
	local controlPosition = copyPoint(enemy.position)
	local impactHealth = math.min(enemy.maxHealth, enemy.health + math.max(0, enemy.healthRegen) * impactDelay)
	local hpPercent = enemy.maxHealth > 0 and clamp(enemy.health / enemy.maxHealth * 100, 0, 100) or 100

	-- Evaluate the selected controlled-target policy against CENTER geometry first. Only a policy-qualified
	-- control shot owns the X bypass and center aim; otherwise the candidate falls back to normal Auto-SS rules.
	local controlSplitCount = controlled and sunSplitCount(snapshot, controlPosition, math.max(cfg.sunRadius, mechanics.radius), enemy.index, impactDelay) or 1
	local controlExpectedDamage = mechanics.expectedDamage / math.max(1, controlSplitCount)
	local controlLethal = hpLatch ~= nil or impactHealth <= controlExpectedDamage
	local controlPolicyPass, controlPolicy, controlThreshold = false, "disabled", 0
	if controlled then
		controlPolicyPass, controlPolicy, controlThreshold = helpers.autoUseModePass(settings.controlUseMode or 1,
			impactHealth, enemy.maxHealth, controlExpectedDamage, hpPercent, settings.controlHpPercent or 100)
		-- Lethal mode follows the existing HP latch ownership exactly.
		if (settings.controlUseMode or 1) == 1 and hpLatch ~= nil then controlPolicyPass = true end
		logChanged("sun_control_policy_" .. tostring(enemy.index), "SUN CONTROL POLICY",
			("target=%d mode=%s pass=%s hp=%.0f hpPct=%.1f damage=%.0f threshold=%.0f split=%d"):format(
				enemy.index, tostring(controlPolicy), tostring(controlPolicyPass), impactHealth, hpPercent,
				controlExpectedDamage, controlThreshold or 0, controlSplitCount))
	end

	if xBlocked and not controlPolicyPass then
		logChanged("moving_sun_block_" .. tostring(enemy.index), "PORTRAIT X SS BLOCK",
			("target=%d hero=%s xStandingSun=%s controlPolicy=%s -> NORMAL AUTO SS SKIP"):format(
				enemy.index, helpers.movingSunBlockKey(enemy) or "?", tostring(settings.xStandingSun == true), tostring(controlPolicy)))
		helpers.sunPriority.logWhyHold(enemy, snapshot, "X_BLOCK", "portrait X blocks this ordinary Auto SS state")
		return nil
	end

	local predictionPosition = controlPolicyPass and controlPosition or normalPredictionPosition
	local splitCount = controlPolicyPass and controlSplitCount
		or sunSplitCount(snapshot, predictionPosition, math.max(cfg.sunRadius, mechanics.radius), enemy.index, impactDelay)
	local expectedDamage = mechanics.expectedDamage / splitCount
	-- Once HP entered the lethal window, do not make route/fog latency force the same HP test again.
	-- Split damage is the exception: nearby units may enter the future AoE after HP lock, so a latched
	-- target must still have enough CURRENT per-unit Sun damage to cover the ORIGINAL locked impact HP.
	local splitReferenceHp = hpLatch and hpLatch.impactHealth or impactHealth
	local splitSafe = expectedDamage + 0.001 >= splitReferenceHp
	if hpLatch then
		logChanged("sun_split_gate_" .. tostring(enemy.index), "SUN SPLIT SAFE",
			("target=%d stage=permission split=%d damage=%.0f hpLock=%.0f pass=%s%s"):format(
				enemy.index, splitCount, expectedDamage, splitReferenceHp, tostring(splitSafe), splitSafe and "" or " -> HOLD"))
		if not splitSafe then
			helpers.sunPriority.logWhyHold(enemy, snapshot, "SPLIT", ("split=%d damage=%.0f hpLock=%.0f"):format(splitCount, expectedDamage, splitReferenceHp))
			return nil
		end
	end
	-- The latch remains logical only: it does not bypass route/Anti-Zigzag, split safety or Invoke readiness.
	local strictLethal = hpLatch ~= nil or impactHealth <= expectedDamage
	local controlSpecial = controlPolicyPass and not strictLethal
	local aimDirection = not controlPolicyPass and not stationaryForSun and enemy.moving and speed > 40 and helpers.sunPriority.currentAimDirection(enemy) or nil
	enemy.sunLockedAimDirection = aimDirection and copyPoint(aimDirection) or nil

	local routeGate = nil
	if settings.predictRunningTargets and strictLethal and enemy.moving and speed > 40 and not stationaryForSun then
		routeGate = helpers.sunPriority.runnerRouteGate(enemy, snapshot, settings)
	end
	local runner = settings.predictRunningTargets and strictLethal and enemy.moving and speed > 40 and not stationaryForSun
		and enemy.motionConfidence >= 0.45
		and enemy.movementDuration >= settings.sunWalkTime
		and routeGate and routeGate.passed
		and invokeReadyNow
	if settings.predictRunningTargets and strictLethal and enemy.moving and speed > 40 and not stationaryForSun then
		logChanged("runner_gate_" .. tostring(enemy.index), "RUNNER",
			("target=%d ready=%s walk=%.1f/%.1f route=%s/%s terrain=%s coverage=%.2f dominant=%.2f routes=%d fork=%s forced=%s tconf=%.2f history=%.2f speed=%.0f conf=%.2f invokeNow=%s invokeWait=%.2f"):format(
				enemy.index, tostring(runner), math.floor(enemy.movementDuration * 10) / 10, settings.sunWalkTime,
				tostring(routeGate and routeGate.passed or false), routeGate and routeGate.reason or "none",
				routeGate and routeGate.terrainStatus or "none", routeGate and routeGate.terrainCoverage or 0,
				routeGate and routeGate.dominantWeight or 0, routeGate and routeGate.routeCount or 0,
				tostring(routeGate and routeGate.terrainFork or false), tostring(routeGate and routeGate.terrainForcedTurn or false),
				routeGate and routeGate.terrainConfidence or 0, routeGate and routeGate.historyScore or 0, speed, enemy.motionConfidence,
				tostring(invokeReadyNow), invokeWait == math.huge and -1 or invokeWait))
	end
	local nativeIdle = helpers.sunPriority.nativeIdleReady(enemy, settings)
	-- v85: ordinary standing Auto SS is governed by the normal idle/stationary evidence. The nested
	-- portrait setting has no global authority; it is consulted only when that exact portrait has X.
	local idleTarget = strictLethal and (nativeIdle or stationaryForSun)
	local controlledLethal = strictLethal and controlPolicyPass

	-- Ordinary fog continuation is route-only and lethal-only; never use a stale control state in fog.
	if fogRoute then
		controlSpecial = false
		controlPolicyPass = false
		controlledLethal = false
		-- v60: a stop that was already proven from real observed samples before tree/fog loss is a
		-- legitimate continuation mode. Do not force that target back through the runner route gate.
		if not runner and not stationaryForSun then
			helpers.sunPriority.logWhyHold(enemy, snapshot, "FOG_ROUTE", routeGate and routeGate.reason or "runner_not_ready")
			return nil
		end
	end

	if not (runner or idleTarget or controlledLethal or controlSpecial) then
		local reason, detail = "NO_MODE", nil
		if strictLethal and enemy.moving and speed > 40 and not stationaryForSun then
			if enemy.motionConfidence < 0.45 then
				reason, detail = "MOTION_CONF", ("%.2f<0.45"):format(enemy.motionConfidence)
			elseif enemy.movementDuration < settings.sunWalkTime then
				reason, detail = "RUNNER_WALK", ("%.2f/%.2f"):format(enemy.movementDuration, settings.sunWalkTime)
			elseif not routeGate or not routeGate.passed then
				reason, detail = "RUNNER_ROUTE", routeGate and routeGate.reason or "no_history"
			elseif not invokeReadyNow then
				reason, detail = "INVOKE_NOT_READY", ("wait=%.2f"):format(invokeWait == math.huge and -1 or invokeWait)
			end
		elseif strictLethal then
			reason, detail = "IDLE_WAIT", ("idle=%.2f/%.2f moving=%s speed=%.0f stationary=%s"):format(
				enemy.idleDuration or 0, settings.sunIdleTime or 0, tostring(enemy.moving == true), speed, tostring(stationaryForSun))
		elseif controlled then
			reason, detail = "CONTROL_POLICY", tostring(controlPolicy)
		end
		helpers.sunPriority.logWhyHold(enemy, snapshot, reason, detail)
		return nil
	end

	local mode = controlSpecial and (controlPolicy == "always" and "control_always"
		or controlPolicy == "near_lethal" and "control_near" or "control_hp")
		or controlledLethal and "controlled_lethal"
		or runner and "runner"
		or stationaryForSun and "idle_stationary"
		or "idle"
	local reliability = (controlledLethal or controlSpecial) and 1.0 or idleTarget and 0.97 or clamp(prediction.reliability, 0.15, 1)
	if hpLatch then
		logChanged("sun_why_hold_" .. tostring(enemy.index), "SUN WHY HOLD",
			("target=%d age=%.2f reason=READY mode=%s"):format(enemy.index,
				math.max(0, snapshot.now - (hpLatch.lockedAt or snapshot.now)), mode))
	end
	if fogRoute then
		logDebug("FOG SUN", ("target=%d age=%.2f mode=%s pos=%.0f,%.0f velocity=%.0f,%.0f hp=%.0f confidence=%.2f stationary=%s"):format(
			enemy.index, enemy.fogAge or 0, mode, predictionPosition.x, predictionPosition.y, enemy.velocity.x, enemy.velocity.y,
			impactHealth, enemy.motionConfidence, tostring(stationaryForSun)))
	end
	return {
		prediction = predictionPosition,
		reliability = reliability,
		impactDelay = impactDelay,
		impactHealth = impactHealth,
		expectedDamage = expectedDamage,
		splitCount = splitCount,
		controlled = controlled,
		controlEndsAt = controlEndsAt,
		controlHp = controlSpecial,
		controlShot = controlPolicyPass,
		controlPolicy = controlPolicy,
		hpPercent = hpPercent,
		runner = runner,
		idle = idleTarget,
		stationaryForSun = stationaryForSun,
		strictLethal = strictLethal,
		hpLatched = hpLatch ~= nil,
		hpLatchImpactHealth = hpLatch and hpLatch.impactHealth or nil,
		hpLatchExpectedDamage = hpLatch and hpLatch.expectedDamage or nil,
		mode = mode,
		fogRoute = fogRoute == true,
		aimDirection = aimDirection and copyPoint(aimDirection) or nil,
	}
end

local function isAutoSunTarget(enemy, snapshot, settings)
	local evaluation = helpers.sunPriority.evaluateAutoSun(enemy, snapshot, settings)
	if enemy then enemy.sunEvaluation = evaluation end
	return evaluation ~= nil
end

local function selectAutoSunTarget(snapshot, settings)
	-- v55 preserves first-lethal ownership initially, but prevents an uncastable route from monopolizing
	-- NORMAL Auto Sun forever.  Only a DIFFERENT strict-lethal target that is already fully executable
	-- may take over, and only after the old HP latch has waited for cfg.sunHpLatchFallbackAge.
	if state.sunHpLatch then
		local locked = findEnemy(snapshot, state.sunHpLatch.targetIndex)
		if not locked then return nil end
		local evaluation = helpers.sunPriority.evaluateAutoSun(locked, snapshot, settings)
		locked.sunEvaluation = evaluation
		if evaluation then return locked end

		local latchAge = math.max(0, snapshot.now - (state.sunHpLatch.lockedAt or snapshot.now))
		if latchAge < cfg.sunHpLatchFallbackAge then return nil end

		local alternate, alternateEvaluation, alternateHealth
		for _, enemy in ipairs(snapshot.enemies) do
			if enemy.index ~= locked.index then
				local candidate = helpers.sunPriority.evaluateAutoSun(enemy, snapshot, settings)
				if candidate and candidate.strictLethal
					and (not alternate or candidate.impactHealth < alternateHealth)
				then
					alternate, alternateEvaluation, alternateHealth = enemy, candidate, candidate.impactHealth
				end
			end
		end
		if not alternate or not alternateEvaluation then return nil end

		local oldTarget = state.sunHpLatch.targetIndex
		helpers.sunPriority.releaseHpLatch(("fallback target %d ready now"):format(alternate.index))
		state.sunHpLatch = {
			targetIndex = alternate.index,
			lockedAt = snapshot.now,
			impactHealth = alternateEvaluation.impactHealth,
			expectedDamage = alternateEvaluation.expectedDamage,
			splitCount = alternateEvaluation.splitCount,
			prediction = copyPoint(alternateEvaluation.prediction),
			fogAtLock = alternateEvaluation.fogRoute == true,
		}
		alternate.sunHpLatch = state.sunHpLatch
		alternateEvaluation.hpLatched = true
		alternateEvaluation.hpLatchImpactHealth = state.sunHpLatch.impactHealth
		alternateEvaluation.hpLatchExpectedDamage = state.sunHpLatch.expectedDamage
		alternate.sunEvaluation = alternateEvaluation
		logDebug("SUN LATCH FALLBACK", ("old=%d age=%.2f -> target=%d mode=%s hpImpact=%.0f damage=%.0f split=%d READY NOW"):format(
			oldTarget, latchAge, alternate.index, tostring(alternateEvaluation.mode or "?"),
			alternateEvaluation.impactHealth or 0, alternateEvaluation.expectedDamage or 0, alternateEvaluation.splitCount or 1))
		return alternate
	end
	local lethal, lethalHealth
	local controlled, controlledHealth
	for _, enemy in ipairs(snapshot.enemies) do
		local evaluation = helpers.sunPriority.evaluateAutoSun(enemy, snapshot, settings)
		if evaluation then
			enemy.sunEvaluation = evaluation
			if evaluation.strictLethal then
				if not lethal or enemy.health < lethalHealth then lethal, lethalHealth = enemy, enemy.health end
			elseif evaluation.controlHp then
				if not controlled or enemy.health < controlledHealth then controlled, controlledHealth = enemy, enemy.health end
			end
		end
	end
	-- Preserve kill priority: a normal lethal Sun always beats the optional HP-limited control shot.
	return lethal or controlled
end

function helpers.cataclysmPolicyEvaluation(enemy, snapshot, settings, impactAt, forcedPosition)
	if not enemy or not enemy.alive then return nil end
	local mechanics = resolveMechanics("cataclysm", snapshot, 0, impactAt)
	local delay = impactAt and math.max(0, impactAt - snapshot.now) or helpers.sunImpactDelay(snapshot, "cataclysm")
	local position = forcedPosition or enemy.position
	if not position then return nil end
	local split = sunSplitCount(snapshot, position, math.max(cfg.sunRadius, mechanics.radius), enemy.index, delay)
	local damage = mechanics.expectedDamage / math.max(1, split)
	local projectedHealth = math.min(enemy.maxHealth, enemy.health + math.max(0, enemy.healthRegen) * delay)
	local hpPercent = enemy.maxHealth > 0 and clamp(enemy.health / enemy.maxHealth * 100, 0, 100) or 100
	local pass, policy, threshold = helpers.autoUseModePass(settings.cataclysmUseMode or 0, projectedHealth,
		enemy.maxHealth, damage, hpPercent, 100)
	return {pass = pass, policy = policy, threshold = threshold, projectedHealth = projectedHealth,
		hpPercent = hpPercent, damage = damage, split = split, position = copyPoint(position)}
end

function helpers.cataclysmLandingRecordPolicyEvaluation(record, snapshot, settings, impactAt)
	if not record or not record.index then return nil end
	local enemy = findEnemy(snapshot, record.index)
	local unit = Entity.Get(record.index)
	if not unit and not enemy then return nil end
	local health = enemy and enemy.health or unit and Entity.GetHealth(unit) or 0
	local maxHealth = enemy and enemy.maxHealth or unit and Entity.GetMaxHealth(unit) or 0
	local regen = math.max(0, enemy and enemy.healthRegen or unit and NPC.GetHealthRegen(unit) or 0)
	if maxHealth <= 0 or health <= 0 then return nil end
	local delay = math.max(0, (impactAt or snapshot.now) - snapshot.now)
	local currentHealth = health
	local projectedHealth = math.min(maxHealth, health + regen * delay)
	if record.name == "modifier_invoker_tornado" and record.tornadoPostHitHealth ~= nil then
		local hitAt = record.tornadoHitAt or snapshot.now
		local hitRegen = math.max(0, record.tornadoPreHitRegen or regen)
		maxHealth = record.tornadoPreHitMaxHealth or maxHealth
		currentHealth = math.min(maxHealth, math.max(0, record.tornadoPostHitHealth) + hitRegen * math.max(0, snapshot.now - hitAt))
		projectedHealth = math.min(maxHealth, math.max(0, record.tornadoPostHitHealth) +
			hitRegen * math.max(0, (impactAt or snapshot.now) - hitAt))
	end
	local position = record.tornadoLiftPosition or record.position or enemy and enemy.position or unit and Entity.GetAbsOrigin(unit) or nil
	if not position then return nil end
	local mechanics = resolveMechanics("cataclysm", snapshot, 0, impactAt)
	local split = sunSplitCount(snapshot, position, math.max(cfg.sunRadius, mechanics.radius), record.index, delay)
	local damage = mechanics.expectedDamage / math.max(1, split)
	local hpPercent = maxHealth > 0 and clamp(currentHealth / maxHealth * 100, 0, 100) or 100
	local pass, policy, threshold = helpers.autoUseModePass(settings.cataclysmUseMode or 0, projectedHealth,
		maxHealth, damage, hpPercent, 100)
	return {pass = pass, policy = policy, threshold = threshold, projectedHealth = projectedHealth,
		hpPercent = hpPercent, damage = damage, split = split, targetIndex = record.index}
end

function helpers.cataclysmGroupPolicyPass(records, snapshot, settings, impactAt)
	if (settings.cataclysmUseMode or 0) == 0 then return true, nil end
	local best = nil
	for _, record in ipairs(records or {}) do
		local evaluation = helpers.cataclysmLandingRecordPolicyEvaluation(record, snapshot, settings, impactAt)
		if evaluation and (not best or evaluation.projectedHealth < best.projectedHealth) then best = evaluation end
		if evaluation and evaluation.pass then return true, evaluation end
	end
	return false, best
end

function helpers.isAutoCataclysmTarget(enemy, snapshot, settings)
	if not settings.cataclysm or not helpers.hasAutoSunMana(snapshot, settings, "cataclysm")
		or snapshot.hero.upgrades.scepterChoice ~= "exort"
		or not helpers.autoSpellReadyOrChargeable("cataclysm", snapshot, settings)
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
	local qualified = {}
	for _, enemy in ipairs(controlled) do
		local evaluation = helpers.cataclysmPolicyEvaluation(enemy, snapshot, settings)
		enemy.cataclysmPolicyEvaluation = evaluation
		if evaluation and evaluation.pass then qualified[#qualified + 1] = enemy end
	end
	if #qualified == 0 then
		logChanged("cata_policy_generic", "CATA POLICY", ("mode=%d controlled=%d required=%d -> HOLD"):format(
			settings.cataclysmUseMode or 0, #controlled, settings.cataclysmMinHeroes or 2))
		return nil
	end
	table.sort(qualified, function(left, right)
		local le = left.cataclysmPolicyEvaluation
		local re = right.cataclysmPolicyEvaluation
		return (le and le.projectedHealth or left.health) < (re and re.projectedHealth or right.health)
	end)
	local chosen = qualified[1]
	local ev = chosen.cataclysmPolicyEvaluation
	logChanged("cata_policy_generic", "CATA POLICY", ("mode=%s controlled=%d required=%d target=%d hp=%.0f hpPct=%.1f damage=%.0f threshold=%.0f split=%d -> PASS"):format(
		tostring(ev.policy), #controlled, settings.cataclysmMinHeroes or 2, chosen.index, ev.projectedHealth, ev.hpPercent, ev.damage, ev.threshold or 0, ev.split or 1))
	return chosen
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
			local target = findEnemy(snapshot, hitbox.targetIndex)
			if target and target.moving and length2D(target.velocity) > 40 then
				target.sunQuickAimDirection = helpers.sunPriority.currentAimDirection(target)
			end
			if target then
				logDebug("QUICK SUN", ("target=%d fog=%s age=%.2f moving=%s pos=%.0f,%.0f"):format(
					target.index, tostring(target.fogProjected == true), target.fogAge or 0, tostring(target.moving),
					target.position.x, target.position.y))
			end
			return target
		end
	end
	return nil
end

function helpers.handleMovingSunBlockClick(snapshot)
	if Input.IsInputCaptured() then return false end
	local cursorX, cursorY = Input.GetCursorPos()
	local hovered = nil
	for _, hitbox in ipairs(state.movingSunBlockHitboxes or {}) do
		if cursorX >= hitbox.x and cursorX <= hitbox.x + hitbox.width
			and cursorY >= hitbox.y and cursorY <= hitbox.y + hitbox.height
		then
			hovered = hitbox
			break
		end
	end
	-- Called only for a mouse-down event owned by OnKeyEvent.
	if not hovered then return false end
	state.movingSunBlocks = state.movingSunBlocks or {}
	local enabled = not state.movingSunBlocks[hovered.blockKey]
	state.movingSunBlocks[hovered.blockKey] = enabled or nil
	helpers.saveMovingSunBlocks()
	if enabled and state.sunHpLatch then
		local locked = findEnemy(snapshot, state.sunHpLatch.targetIndex)
		local autoSettings = readSettings().auto
		local controlledNow = locked and helpers.sunPriority.controlValidForOrder(locked, snapshot, autoSettings) or false
		if locked and helpers.movingSunBlockKey(locked) == hovered.blockKey and not controlledNow
			and helpers.movingSunBlocked(locked, autoSettings)
		then
			helpers.sunPriority.releaseHpLatch("portrait counter/X normal Auto-SS block selected")
		end
	end
	logDebug("PORTRAIT SS BLOCK", ("hero=%s slot=%s key=%s enabled=%s xStandingSun=%s"):format(
		tostring(hovered.heroName), tostring(hovered.teamSlot), tostring(hovered.blockKey), tostring(enabled),
		tostring(ui and ui.movingSunBlockStanding and ui.movingSunBlockStanding:Get() == true)))
	return true
end


-- v28: every real Sun Strike request (automatic lethal, portrait, landing, objectives)
-- enters one common execution pipeline. Selection criteria remain mode-specific, but once queued the
-- same resolver owns target validity, position refresh, safety, Invoke, final CastPosition and confirmation.
helpers.sunEngine = helpers.sunEngine or {}

function helpers.sunEngine.isSunKind(kind)
	return kind == "sun_strike" or kind == "quick_sun" or kind == "landing_sun"
		or kind == "roshan_sun" or kind == "tormentor_sun"
end

function helpers.sunEngine.createRequest(target, kind, snapshot)
	local request = {
		kind = kind,
		manual = kind == "quick_sun",
		positionMode = "predicted",
		allowFog = kind == "sun_strike" or kind == "quick_sun",
		createdAt = snapshot.now,
	}
	if kind == "landing_sun" then request.positionMode = "landing"
	elseif kind == "roshan_sun" then request.positionMode = "roshan"
	elseif kind == "tormentor_sun" then request.positionMode = "tormentor"
	end
	return request
end

local function queueAutoAction(id, target, kind, snapshot)
	local action = snapshot.actions[id]
	if not action or not action.exists or action.cooldown > 0.05 or snapshot.hero.mana + 0.001 < action.manaCost then return false end
	if id == "sun_strike" or id == "cataclysm" then
		-- Hidden/master Sun handles never count as charged. With self-charge disabled, automation is
		-- strictly D/F-only. With it enabled, the shared executor may run EEE -> Invoke first.
		local auto = readSettings().auto
		-- v91: ordinary automatic Sun must not spend the shared Sun resource while Exort Scepter/Cataclysm is available,
		-- unless the user explicitly opts in. Manual portrait Quick Sun remains a deliberate manual action.
		if id == "sun_strike" and kind ~= "quick_sun" and snapshot.hero.upgrades.scepterChoice == "exort" and not auto.sunWithScepter then
			logChanged("scepter_auto_sun_gate", "AUTO SUN", "Scepter active + Use SS with Scepter OFF -> ordinary Auto SS blocked")
			return false
		end
		if not action.invoked and (not helpers.autoSelfChargeEnabled(id, auto) or not snapshot.invoke.exists) then return false end
	elseif not (action.invoked or action.activated) and not snapshot.invoke.ready then
		return false
	end
	local lifetime = kind == "quick_sun" and 2.4 or 2.2
	if kind == "sun_strike" and not action.invoked and snapshot.invoke then
		-- v24 runner acquisition only reaches this point when Invoke is ready NOW. Keep the extra
		-- lifetime for non-runner automatic modes that still intentionally use the old short bridge.
		local runnerMode = target and target.sunEvaluation and target.sunEvaluation.mode == "runner"
		if not runnerMode then
			lifetime = math.max(lifetime, math.min(0.35, math.max(0, snapshot.invoke.cooldown or 0)) + 1.2)
		end
	end
	state.autoPending = {
		actionId = id,
		targetIndex = target.index,
		kind = kind,
		expiresAt = snapshot.now + lifetime,
		attempts = 0,
		cast = nil,
	}
	if id == "sun_strike" and helpers.sunEngine.isSunKind(kind) then
		state.autoPending.sunRequest = helpers.sunEngine.createRequest(target, kind, snapshot)
	end
	if id == "sun_strike" then
		state.sunVisualTargetIndex = target.index
		state.sunVisualTargetUntil = snapshot.now + math.max(lifetime, helpers.sunImpactDelay(snapshot, "sun_strike") + 0.35)
		local direction = target.sunEvaluation and target.sunEvaluation.aimDirection or target.sunQuickAimDirection
		if direction and length2D(direction) > 0.5 then state.autoPending.sunAimDirection = copyPoint(direction) end
		state.autoPending.sunFogAtLock = target.fogProjected == true
		state.autoPending.sunLockSpeed = helpers.sunPriority.castMotionSpeed(target)
		state.autoPending.sunLockMoveSpeed = target.moveSpeed or 0
	end
	if kind == "sun_strike" and target.sunEvaluation then
		state.autoPending.sunMode = target.sunEvaluation.mode
		state.autoPending.sunControlled = target.sunEvaluation.controlShot == true
		state.autoPending.sunControlPolicy = target.sunEvaluation.controlPolicy
		state.autoPending.sunLockedAt = snapshot.now
		state.autoPending.sunControlEndsAt = target.sunEvaluation.controlEndsAt
		state.autoPending.sunInitialHpPercent = target.sunEvaluation.hpPercent
		state.autoPending.sunFogRoute = target.sunEvaluation.fogRoute
		state.autoPending.sunStrictLethal = target.sunEvaluation.strictLethal == true
		if state.autoPending.sunStrictLethal then
			state.autoPending.sunSplitReferenceHp = target.sunEvaluation.hpLatched
				and target.sunEvaluation.hpLatchImpactHealth or target.sunEvaluation.impactHealth
			state.autoPending.sunSplitAtLock = target.sunEvaluation.splitCount or 1
		end
	end
	state.invokeSequence = nil
	state.orbSequence = nil
	if helpers.sunPriority.kinds[kind] or id == "sun_strike" or id == "cataclysm" then
		helpers.sunPriority.claim(kind, snapshot.now + helpers.sunPriority.leaseSeconds)
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
	-- v71: NORMAL Auto-Sun also needs TP ownership tracking so an origin/fog race cannot spend Sun at the pre-TP position.
	return settings.sunStrike or settings.landingSun or settings.cataclysm
end

-- v44: lift timing must be established before Tornado landing damage. Visible targets use the real
-- modifier; hidden targets use the airborne invulnerable/out-of-game transition while our Tornado is
-- still travelling. OnEntityHurt arrives at landing and is only a damage confirmation.
function helpers.tornadoStatusFactor(unit)
	if not unit then return 1 end
	local resistance, stacking = 0, 0
	local okResistance, valueResistance = pcall(NPC.GetModifierProperty, unit, Enum.ModifierFunction.MODIFIER_PROPERTY_STATUS_RESISTANCE)
	if okResistance and type(valueResistance) == "number" then resistance = valueResistance end
	local okStacking, valueStacking = pcall(NPC.GetModifierProperty, unit, Enum.ModifierFunction.MODIFIER_PROPERTY_STATUS_RESISTANCE_STACKING)
	if okStacking and type(valueStacking) == "number" then stacking = valueStacking end
	return clamp((1 - resistance / 100) * (1 - stacking / 100), 0.05, 1)
end

function helpers.tornadoCooldownToken(ability, now)
	if not ability then return nil end
	local ok, cooldown = pcall(Ability.GetCooldown, ability)
	if not ok or type(cooldown) ~= "number" then return nil end
	return now + math.max(0, cooldown)
end

function helpers.tornadoHitPosition(unit, index, now)
	-- Once the lift itself is detected, the victim rotates around that axis and lands at the same
	-- world point. Try the live entity origin even while dormant; only fall back to the old fog
	-- route when the runtime does not expose a usable hidden origin.
	local snapshot = state.snapshot
	local enemy = snapshot and findEnemy(snapshot, index) or nil
	local predicted = enemy and enemy.position and copyPoint(enemy.position) or nil
	if unit then
		local okOrigin, origin = pcall(Entity.GetAbsOrigin, unit)
		if okOrigin and origin and type(origin.x) == "number" and type(origin.y) == "number"
			and origin.x == origin.x and origin.y == origin.y
			and math.abs(origin.x) < 50000 and math.abs(origin.y) < 50000
		then
			local point = copyPoint(origin)
			local delta = predicted and distance2D(point, predicted) or 0
			local hidden = Entity.IsDormant(unit) or not NPC.IsVisible(unit)
			return point, hidden and "entity_origin_hidden" or "entity_origin_visible", delta
		end
	end
	if predicted then
		return predicted, enemy.fogProjected and "fog_track_fallback" or "snapshot_fallback", 0
	end
	local ghost = helpers.fogEnemyFromTrack(unit, now)
	if ghost and ghost.position then return copyPoint(ghost.position), "fog_track_fallback", 0 end
	return nil, "unknown", 0
end

function helpers.tornadoExpectedLandingDamage(unit, snapshot)
	local mechanics = snapshot and resolveMechanics("tornado", snapshot, 0) or nil
	local rawDamage = mechanics and mechanics.expectedDamage or 0
	local multiplier = 1
	if unit then
		local okMagic, magic = pcall(NPC.GetMagicalArmorDamageMultiplier, unit)
		if okMagic and type(magic) == "number" then multiplier = clamp(magic, 0, 2) end
	end
	return math.max(0, rawDamage * multiplier), rawDamage, multiplier
end

function helpers.seedTornadoLandingBudget(record, unit, snapshot, source)
	if not record or record.name ~= "modifier_invoker_tornado" or not unit then return end
	if record.tornadoDamage ~= nil and not record.tornadoDamageEstimated then return end
	local enemy = snapshot and findEnemy(snapshot, record.index) or nil
	local liveHealth, liveMaxHealth = Entity.GetHealth(unit), Entity.GetMaxHealth(unit)
	-- v47 runtime evidence: hidden hero HP remains readable and updates on Tornado landing.
	-- Use the live entity HP as the authoritative pre-hit budget even in fog. The fog snapshot
	-- is now only a fallback for runtimes/frames where entity HP is unavailable.
	local health = liveHealth and liveHealth > 0 and liveHealth or enemy and enemy.health or nil
	local maxHealth = liveMaxHealth and liveMaxHealth > 0 and liveMaxHealth or enemy and enemy.maxHealth or nil
	if not health or not maxHealth or health <= 0 or maxHealth <= 0 then return end
	local expectedDamage, rawDamage, magicMultiplier = helpers.tornadoExpectedLandingDamage(unit, snapshot)
	local regen = math.max(0, enemy and enemy.healthRegen or NPC.GetHealthRegen(unit) or 0)
	record.tornadoPreHitHealth = math.min(maxHealth, health)
	record.tornadoPostHitHealth = math.max(0, record.tornadoPreHitHealth - expectedDamage)
	record.tornadoPreHitMaxHealth = maxHealth
	record.tornadoPreHitRegen = regen
	record.tornadoDamage = expectedDamage
	record.tornadoDamageRaw = rawDamage
	record.tornadoMagicMultiplier = magicMultiplier
	record.tornadoDamageEstimated = true
	record.tornadoHealthSource = tostring(source or "lift") .. "_pre_damage_estimate"
	record.tornadoEstimatedPostHealth = record.tornadoPostHitHealth
	record.tornadoEstimatedMaxHealth = maxHealth
	record.tornadoEstimatedRegen = regen
	record.tornadoLethalLastPass = nil
end

function helpers.trackRecentTornadoFlight(snapshot)
	local action = snapshot and snapshot.actions and snapshot.actions.tornado or nil
	if not action or not action.exists or not action.ability then return nil end
	-- A ready Tornado is not an active projectile. This also protects runtimes where
	-- SecondsSinceLastUse() reports zero for an ability that has never been cast.
	if (action.cooldown or 0) <= 0.05 then state.tornadoFlight = nil; return nil end
	local travelDistance = liveValue(snapshot, "tornado", "travel_distance", 1200 + 300 * (snapshot.hero.orbLevels.wex or 0))
	local speed = math.max(1, liveValue(snapshot, "tornado", "travel_speed", 1000))
	local maxAge = math.max(0.5, (action.castPoint or 0) + travelDistance / speed + 0.75)
	local okAge, secondsSince = pcall(Ability.SecondsSinceLastUse, action.ability)
	local cooldownAge = math.max(0, (action.cooldownLength or action.cooldown or 0) - (action.cooldown or 0))
	local age = okAge and type(secondsSince) == "number" and secondsSince >= 0 and secondsSince <= maxAge + 1
		and secondsSince or cooldownAge
	if age > maxAge then
		if state.tornadoFlight and snapshot.now > (state.tornadoFlight.expiresAt or 0) then state.tornadoFlight = nil end
		return nil
	end
	local token = helpers.tornadoCooldownToken(action.ability, snapshot.now)
	local castAt = snapshot.now - age
	local flight = state.tornadoFlight
	if not flight or math.abs((flight.castAt or castAt) - castAt) > 0.35
		or flight.token and token and math.abs(flight.token - token) > 0.25
	then
		flight = {
			castAt = castAt,
			expiresAt = castAt + maxAge,
			token = token,
			casterIndex = state.hero and Entity.GetIndex(state.hero) or -1,
			origin = snapshot.hero and copyPoint(snapshot.hero.position) or nil,
			travelDistance = travelDistance,
		}
		state.tornadoFlight = flight
		logDebug("TORNADO FLIGHT", ("age=%.2f window=%.2f token=%s"):format(age, maxAge, token and ("%.3f"):format(token) or "unknown"))
	else
		flight.expiresAt = math.max(flight.expiresAt or 0, castAt + maxAge)
		if token and not flight.token then flight.token = token end
	end
	return flight
end

function helpers.observeFogTornadoLifts(snapshot, settings)
	state.tornadoFogControlState = state.tornadoFogControlState or {}
	local flight = helpers.trackRecentTornadoFlight(snapshot)
	for _, unit in ipairs(Heroes.GetAll()) do
		if helpers.landingEnemy(unit) and Entity.IsAlive(unit) then
			local index = Entity.GetIndex(unit)
			local dormant, visible = Entity.IsDormant(unit), NPC.IsVisible(unit)
			local hidden = dormant or not visible
			local okOut, outOfGame = pcall(NPC.HasState, unit, Enum.ModifierState.MODIFIER_STATE_OUT_OF_GAME)
			local okInv, invulnerable = pcall(NPC.HasState, unit, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE)
			local liftedState = (okOut and outOfGame == true) or (okInv and invulnerable == true)
			local previous = state.tornadoFogControlState[index] or {}
			local liftedTransition = liftedState and previous.lifted ~= true
			-- In this runtime Tornado can temporarily wake/highlight a victim inside fog without
			-- making normal NPC.IsVisible true. That dormant->awake transition is also an early
			-- catch signal and occurs before the landing-damage OnEntityHurt callback.
			local fogWake = previous.dormant == true and dormant == false and visible == false
			local fogAtLift = hidden or previous.visible == false
			state.tornadoFogControlState[index] = {lifted = liftedState, dormant = dormant, visible = visible}
			if flight and snapshot.now <= (flight.expiresAt or 0) and fogAtLift and (liftedTransition or fogWake) then
				local existing = state.landings and state.landings[index] or nil
				local existingActive = existing and existing.name == "modifier_invoker_tornado"
					and not existing.cancelled and existing.endsAt and existing.endsAt > snapshot.now + 0.05
				if not existingActive then
					local position, positionSource, predictionDelta = helpers.tornadoHitPosition(unit, index, snapshot.now)
					local mechanics = resolveMechanics("tornado", snapshot, 0)
					local statusFactor = helpers.tornadoStatusFactor(unit)
					local lift = math.max(0.05, (mechanics.controlDuration or 1) * statusFactor)
					local withinReach = true
					if flight.origin and position then
						withinReach = distance2D(flight.origin, position) <= (flight.travelDistance or 0) + 500
					end
					if withinReach then
						state.landings = state.landings or {}
						local record = {
							index = index, name = "modifier_invoker_tornado", kind = "cyclone",
							createdAt = snapshot.now, endsAt = snapshot.now + lift, estimated = true,
							fogTornadoLift = true, tornadoHitInFog = true, tornadoHitAt = snapshot.now,
							tornadoLiftAt = snapshot.now, tornadoLiftDuration = lift,
							tornadoQuasLevel = snapshot.hero.orbLevels.quas or 0,
							tornadoCasterIndex = flight.casterIndex or -1, tornadoCooldownEnd = flight.token,
						}
						if position then
							record.position = copyPoint(position)
							record.tornadoLiftPosition = copyPoint(position)
							record.tornadoPositionFrozen = true
							record.tornadoPositionSource = positionSource
							record.tornadoFogPredictionDelta = predictionDelta or 0
						end
						helpers.seedTornadoLandingBudget(record, unit, snapshot, "fog_lift_state")
						state.landings[index] = record
						local anchor = record.tornadoLiftPosition or record.position
						logDebug("LANDING TORNADO LIFT", ("target=%d fog=true source=%s invuln=%s out=%s ends_in=%.2f lift=%.2f quas=%d damageEst=%.0f hpBefore=%.0f anchor=%.0f,%.0f pos=%s"):format(
							index, fogWake and "fog_wake" or "hidden_state", tostring(invulnerable == true), tostring(outOfGame == true), lift, lift,
							record.tornadoQuasLevel or 0, record.tornadoDamage or 0, record.tornadoPreHitHealth or -1,
							anchor and anchor.x or 0, anchor and anchor.y or 0, tostring(positionSource or "unknown")))
					end
				end
			end
		else
			local index = unit and Entity.GetIndex(unit) or nil
			if index then state.tornadoFogControlState[index] = nil end
		end
	end
end

function helpers.observeTornadoHit(data)
	-- v44: OnEntityHurt for Invoker Tornado is LANDING DAMAGE, not the lift/catch event.
	-- Never create a future landing from this callback.  It may only confirm/replace the damage
	-- budget of a landing record that was created earlier by the real modifier or the hidden lift state.
	if not data or not data.target or not data.ability or not state.hero or not helpers.landingTrackingEnabled() then return end
	local okName, abilityName = pcall(Ability.GetName, data.ability)
	if not okName or abilityName ~= "invoker_tornado" then return end
	local okOwned, owned = pcall(Entity.RecursiveOwnedBy, data.ability, state.hero)
	if okOwned and not owned then return end
	if not okOwned and data.source and Entity.GetIndex(data.source) ~= Entity.GetIndex(state.hero) then return end
	local unit = data.target
	if not helpers.landingEnemy(unit) then return end
	local now = GameRules.GetGameTime()
	local index = Entity.GetIndex(unit)
	local record = state.landings and state.landings[index] or nil
	if not record or record.name ~= "modifier_invoker_tornado" then
		logDebug("TORNADO LANDING DAMAGE", ("target=%d untracked=true damage=%.0f -> no late landing created"):format(index, math.max(0, tonumber(data.damage) or 0)))
		return
	end
	local actualDamage = math.max(0, tonumber(data.damage) or 0)
	local hidden = Entity.IsDormant(unit) or not NPC.IsVisible(unit)
	record.tornadoDamage = actualDamage
	record.tornadoDamageEstimated = false
	record.tornadoLandingDamageAt = now
	local enemy = state.snapshot and findEnemy(state.snapshot, index) or nil
	local maxHealth = record.tornadoPreHitMaxHealth or Entity.GetMaxHealth(unit)
	local liveHealth = Entity.GetHealth(unit)
	if liveHealth and maxHealth and liveHealth >= 0 and maxHealth > 0 then
		record.tornadoPostHitHealth = math.min(maxHealth, liveHealth)
		record.tornadoPreHitHealth = math.min(maxHealth, record.tornadoPostHitHealth + actualDamage)
		record.tornadoHealthSource = hidden and "entity_hidden_landing_actual_damage" or "entity_landing_actual_damage"
	elseif record.tornadoPreHitHealth ~= nil then
		record.tornadoPostHitHealth = math.max(0, record.tornadoPreHitHealth - actualDamage)
		record.tornadoHealthSource = "landing_actual_damage_fallback"
	end
	if maxHealth and maxHealth > 0 then record.tornadoPreHitMaxHealth = maxHealth end
	if record.tornadoPreHitRegen == nil then record.tornadoPreHitRegen = math.max(0, enemy and enemy.healthRegen or NPC.GetHealthRegen(unit) or 0) end
	record.tornadoEstimatedPostHealth = record.tornadoPostHitHealth
	record.tornadoLethalLastPass = nil
	logDebug("TORNADO LANDING DAMAGE", ("target=%d fog=%s damage=%.0f scheduled_delta=%+.3f hpAfter=%.0f hpBefore=%.0f source=%s"):format(
		index, tostring(hidden), actualDamage, now - (record.endsAt or now), record.tornadoPostHitHealth or -1,
		record.tornadoPreHitHealth or -1, tostring(record.tornadoHealthSource or "unknown")))
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
	-- v44: a hidden-state lift record may become readable later. Merge the real modifier into the
	-- existing catch record so its frozen position, group identity, pre-damage HP and catch timestamp survive.
	if record and (record.fogTornadoLift or record.fogTornadoHit) and name == "modifier_invoker_tornado" and record.name == name
		and math.abs((record.createdAt or createdAt) - createdAt) <= 0.75
	then
		record.createdAt, record.estimated = createdAt, false
	end
	if record and not record.cancelled and record.name ~= name and record.endsAt > now + remaining then return end
	if not record or record.name ~= name or record.createdAt ~= createdAt then
		record = {index = index, name = name, kind = kind, createdAt = createdAt}
		state.landings[index] = record
	end
	if record.cancelled then
		logDebug("LANDING TRACK", ("target=%d source=%s recovered=true"):format(index, name))
	end
	record.cancelled = false
	if name == "modifier_invoker_tornado" then
		local caster, ability = Modifier.GetCaster(modifier), Modifier.GetAbility(modifier)
		if record.tornadoCasterIndex == nil then record.tornadoCasterIndex = caster and Entity.GetIndex(caster) or -1 end
		if record.tornadoCooldownEnd == nil then record.tornadoCooldownEnd = helpers.tornadoCooldownToken(ability, now) end
		record.tornadoHitAt = record.tornadoHitAt or createdAt
		record.tornadoLiftAt = record.tornadoLiftAt or createdAt
		local mechanics = state.snapshot and resolveMechanics("tornado", state.snapshot, 0) or nil
		local statusFactor = helpers.tornadoStatusFactor(unit)
		record.tornadoLiftDuration = record.tornadoLiftDuration or math.max(0.05, (mechanics and mechanics.controlDuration or remaining) * statusFactor)
		record.tornadoQuasLevel = record.tornadoQuasLevel or (state.snapshot and state.snapshot.hero and state.snapshot.hero.orbLevels.quas or 0)
		record.tornadoHitInFog = record.tornadoHitInFog == true or Entity.IsDormant(unit) or not NPC.IsVisible(unit)
		if not record.tornadoLiftPosition then
			local okOrigin, origin = pcall(Entity.GetAbsOrigin, unit)
			if okOrigin and origin then
				record.tornadoLiftPosition = copyPoint(origin)
				record.position = copyPoint(origin)
				record.tornadoPositionFrozen = true
				record.tornadoPositionSource = record.tornadoHitInFog and "modifier_entity_origin_hidden" or "modifier_entity_origin_visible"
			end
		end
		helpers.seedTornadoLandingBudget(record, unit, state.snapshot, record.tornadoHitInFog and "fog_modifier_lift" or "modifier_lift")
		if not record.tornadoLiftLogged then
			record.tornadoLiftLogged = true
			local anchor = record.tornadoLiftPosition or record.position
			logDebug("LANDING TORNADO LIFT", ("target=%d fog=%s source=modifier ends_in=%.2f lift=%.2f quas=%d damageEst=%.0f hpBefore=%.0f anchor=%.0f,%.0f"):format(
				index, tostring(record.tornadoHitInFog == true), remaining, record.tornadoLiftDuration or remaining,
				record.tornadoQuasLevel or 0, record.tornadoDamage or 0, record.tornadoPreHitHealth or -1,
				anchor and anchor.x or 0, anchor and anchor.y or 0))
		end
	end
	record.endsAt = now + remaining
	if kind == "teleport" then
		helpers.quarantineTeleportMotion(index, record.endsAt + (cfg.teleportMotionQuarantine or 0.55), "teleport_modifier")
	end
	if name == "modifier_invoker_tornado" and record.tornadoPositionFrozen and record.tornadoLiftPosition then
		record.position = copyPoint(record.tornadoLiftPosition)
	elseif kind == "cyclone" and not Entity.IsDormant(unit) and NPC.IsVisible(unit) then
		record.position = copyPoint(Entity.GetAbsOrigin(unit))
	end
end

function helpers.destroyLandingModifier(unit, modifier)
	if not state.landings then return end
	local record = state.landings[Entity.GetIndex(unit)]
	if record and record.name == Modifier.GetName(modifier) and record.createdAt == Modifier.GetCreationTime(modifier) then
		record.cancelled = true
		if record.kind == "teleport" then
			local departureParticle = record.departureParticleIndex and state.teleportParticles
				and state.teleportParticles[record.departureParticleIndex] or nil
			if departureParticle then
				departureParticle.cancelled = true
				departureParticle.provisionalCandidates = nil
			end
			helpers.quarantineTeleportMotion(record.index, GameRules.GetGameTime() + 0.20, "teleport_cancelled")
		end
	end
end


-- v71: departure/origin particles can be ownerless on creation.  Bind them from a recent, spatially
-- compatible enemy origin before NORMAL Auto-Sun is allowed to keep using the pre-TP runner state.
function helpers.seedTeleportRecord(index, particle, now, source)
	if not index or not particle or particle.cancelled then return nil end
	local unit = Entity.Get(index)
	if not helpers.landingEnemy(unit) or not Entity.IsAlive(unit) then return nil end
	state.landings = state.landings or {}
	local duration = cfg.fogTeleportDuration
	local boots = NPC.GetItem(unit, "item_travel_boots_2", true)
	if boots then duration = Ability.GetLevelSpecialValueFor(boots, "tp_channel_time") end
	if duration <= 0 then duration = cfg.fogTeleportDuration end
	particle.ownerIndex = index
	particle.bindSource = source or particle.bindSource or "departure_owner"
	particle.endsAt = particle.endsAt or (particle.createdAt or now) + duration

	local record = state.landings[index]
	if not record or record.kind ~= "teleport" or record.cancelled
		or math.abs((record.createdAt or particle.createdAt or now) - (particle.createdAt or now)) > 0.75
	then
		record = {
			index = index, name = "modifier_teleporting", kind = "teleport",
			createdAt = particle.createdAt or now, endsAt = particle.endsAt,
			estimated = true, departureParticleIndex = particle.index,
			departureOwnerSource = particle.bindSource,
		}
		state.landings[index] = record
	else
		record.departureParticleIndex = record.departureParticleIndex or particle.index
		record.departureOwnerSource = record.departureOwnerSource or particle.bindSource
		if record.estimated then record.endsAt = particle.endsAt or record.endsAt end
	end
	helpers.quarantineTeleportMotion(index, (record.endsAt or particle.endsAt or now) + (cfg.teleportMotionQuarantine or 0.55),
		"teleport_departure")
	logChanged("tp_departure_" .. tostring(index), "TP TRACK",
		("departure target=%d source=%s ends_in=%.2f particle=%d pos=%s"):format(
			index, tostring(particle.bindSource or "unknown"), math.max(0, (record.endsAt or now) - now),
			particle.index or -1, particle.position and ("%.0f,%.0f"):format(particle.position.x, particle.position.y) or "pending"))
	return record
end

function helpers.bindTeleportDeparture(particle, now, explicitOwnerIndex, source)
	if not particle or not particle.departure or particle.cancelled then return nil end
	now = now or GameRules.GetGameTime()
	if explicitOwnerIndex then
		particle.provisionalCandidates = nil
		return helpers.seedTeleportRecord(explicitOwnerIndex, particle, now, source or "particle_owner")
	end
	if particle.ownerIndex then
		particle.provisionalCandidates = nil
		return helpers.seedTeleportRecord(particle.ownerIndex, particle, now, particle.bindSource or source or "particle_owner")
	end
	-- A real modifier_teleporting record is stronger than spatial inference and may appear one callback later.
	local modifierCandidates = {}
	for _, record in pairs(state.landings or {}) do
		if record.kind == "teleport" and not record.cancelled and not record.estimated
			and math.abs((record.createdAt or now) - (particle.createdAt or now)) <= 0.75
		then
			modifierCandidates[#modifierCandidates + 1] = record
		end
	end
	if #modifierCandidates == 1 then
		particle.provisionalCandidates = nil
		return helpers.seedTeleportRecord(modifierCandidates[1].index, particle, now, "modifier_time")
	end

	if not particle.position then return nil end

	local candidates = {}
	for _, unit in ipairs(Heroes.GetAll()) do
		if helpers.landingEnemy(unit) and Entity.IsAlive(unit) then
			local index = Entity.GetIndex(unit)
			local track = state.motion and state.motion[index] or nil
			local lastAt = track and track.lastVisibleAt or -math.huge
			local lastPos = track and track.lastVisiblePosition or nil
			local age = now - lastAt
			if lastPos and age >= -0.05 and age <= cfg.teleportOwnerResolveAge then
				local distance = distance2D(lastPos, particle.position)
				if distance <= cfg.teleportOwnerResolveRadius then
					candidates[#candidates + 1] = {index = index, distance = distance, age = math.max(0, age)}
				end
			end
		end
	end
	table.sort(candidates, function(a, b)
		if math.abs(a.distance - b.distance) > 0.01 then return a.distance < b.distance end
		return a.age < b.age
	end)

	particle.provisionalCandidates = nil
	if #candidates == 0 then return nil end
	if #candidates == 1
		or candidates[1].distance + cfg.teleportOwnerResolveGap < candidates[2].distance
	then
		local chosen = candidates[1]
		logChanged("tp_owner_provisional_" .. tostring(particle.index), "TP OWNER PROVISIONAL",
			("particle=%d target=%d distance=%.1f age=%.2f candidates=%d"):format(
				particle.index or -1, chosen.index, chosen.distance, chosen.age, #candidates))
		return helpers.seedTeleportRecord(chosen.index, particle, now, "provisional_origin")
	end

	particle.provisionalCandidates = {}
	for _, candidate in ipairs(candidates) do particle.provisionalCandidates[candidate.index] = true end
	particle.provisionalUntil = particle.endsAt or (particle.createdAt or now) + cfg.fogTeleportDuration
	logChanged("tp_owner_ambiguous_" .. tostring(particle.index), "TP OWNER PROVISIONAL",
		("particle=%d ambiguous=true candidates=%d best=%.1f second=%.1f -> candidate NORMAL SUN HOLD"):format(
			particle.index or -1, #candidates, candidates[1].distance, candidates[2].distance))
	return nil
end

function helpers.pendingTeleportVeto(index, now)
	now = now or GameRules.GetGameTime()
	for _, particle in pairs(state.teleportParticles or {}) do
		if particle.departure and not particle.cancelled then
			local activeUntil = particle.endsAt or particle.provisionalUntil or ((particle.createdAt or now) + cfg.fogTeleportDuration)
			if now <= activeUntil + cfg.landingMaxLate then
				if particle.ownerIndex == index then return true, particle.bindSource or "owned_departure" end
				if particle.provisionalCandidates and particle.provisionalCandidates[index] then
					return true, "ambiguous_departure"
				end
			end
		end
	end
	return false, nil
end

function helpers.bindTeleportDestination(particle, now)
	if not particle or particle.departure then return nil end
	now = now or GameRules.GetGameTime()
	state.landings = state.landings or {}

	local function attach(record, source)
		if not record or record.kind ~= "teleport" then return nil end
		local function priority(value)
			if value == "particle_owner" then return 3 end
			if value == "nearest_tp_time" then return 2 end
			if value == "single_active_tp" then return 1 end
			return 0
		end
		local existingIndex = record.teleportParticleIndex
		if existingIndex and existingIndex ~= particle.index then
			local existing = state.teleportParticles and state.teleportParticles[existingIndex] or nil
			if existing and not existing.departure then
				local oldSource = record.teleportParticleSource or existing.bindSource or "unknown"
				local sameDestination = existing.position and particle.position
					and distance2D(existing.position, particle.position) <= 96
				if sameDestination then
					particle.ownerIndex = nil
					logChanged("tp_duplicate_" .. tostring(particle.index), "TP TRACK",
						("ignore duplicate destination particle=%d target=%d canonical=%d source=%s"):format(
							particle.index or -1, record.index or -1, existingIndex, tostring(source or "unknown")))
					return record.index
				end
				if priority(source) <= priority(oldSource) then
					particle.ownerIndex = nil
					logChanged("tp_conflict_" .. tostring(particle.index), "TP TRACK",
						("reject destination particle=%d target=%d canonical=%d oldSource=%s newSource=%s pos=%s"):format(
							particle.index or -1, record.index or -1, existingIndex, tostring(oldSource), tostring(source or "unknown"),
							particle.position and ("%.0f,%.0f"):format(particle.position.x, particle.position.y) or "pending"))
					return nil
				end
				existing.ownerIndex = nil
				logDebug("TP TRACK", ("replace destination target=%d oldParticle=%d oldSource=%s newParticle=%d newSource=%s"):format(
					record.index or -1, existingIndex, tostring(oldSource), particle.index or -1, tostring(source or "unknown")))
			end
		end
		particle.ownerIndex = record.index
		particle.bindSource = source
		record.teleportParticleIndex = particle.index
		record.teleportParticleSource = source
		if particle.position then
			record.teleportLastPosition = copyPoint(particle.position)
			record.teleportPositionAt = particle.positionAt or now
		end
		helpers.quarantineTeleportMotion(record.index, (record.endsAt or now) + (cfg.teleportMotionQuarantine or 0.55), "teleport_destination")
		logChanged("tp_bind_" .. tostring(particle.index), "TP TRACK",
			("bind particle=%d target=%d source=%s ends_in=%.2f pos=%s"):format(
				particle.index or -1, record.index or -1, tostring(source or "unknown"),
				math.max(0, (record.endsAt or now) - now),
				particle.position and ("%.0f,%.0f"):format(particle.position.x, particle.position.y) or "pending"))
		return record.index
	end

	if particle.ownerIndex then
		local owned = state.landings[particle.ownerIndex]
		if owned and owned.kind == "teleport" and not owned.cancelled then return attach(owned, "particle_owner") end
	end

	local candidates = {}
	for _, record in pairs(state.landings) do
		if record.kind == "teleport" and not record.cancelled and record.endsAt
			and record.endsAt >= now - cfg.landingMaxLate
			and math.abs((record.createdAt or now) - (particle.createdAt or now)) <= 1.25
		then
			local teamOk = true
			if particle.targetIndex then
				local owner, target = Entity.Get(record.index), Entity.Get(particle.targetIndex)
				if owner and target then teamOk = Entity.IsSameTeam(owner, target) end
			end
			if teamOk then
				candidates[#candidates + 1] = {record = record,
					delta = math.abs((record.createdAt or now) - (particle.createdAt or now))}
			end
		end
	end
	table.sort(candidates, function(a, b) return a.delta < b.delta end)
	if #candidates == 1 or #candidates >= 2 and candidates[1].delta + 0.12 < candidates[2].delta then
		return attach(candidates[1].record, #candidates == 1 and "single_active_tp" or "nearest_tp_time")
	end
	if #candidates > 1 then
		logChanged("tp_ambiguous_" .. tostring(particle.index), "TP TRACK",
			("particle=%d owner=ambiguous candidates=%d best=%.3f second=%.3f"):format(
				particle.index or -1, #candidates, candidates[1].delta, candidates[2].delta))
	end
	return nil
end

function helpers.createTeleportParticle(data)
	local fullName = tostring(data and data.fullName or "")
	local lowerName = string.lower(fullName)
	local departure = string.find(lowerName, "teleport_start", 1, true) ~= nil
		or string.find(lowerName, "teleport_origin", 1, true) ~= nil
	local destination = string.find(lowerName, "teleport_end", 1, true) ~= nil
	if not (departure or destination) then
		if helpers.landingTrackingEnabled() and string.find(lowerName, "teleport", 1, true) then
			logDebug("TP TRACK", ("unclassified particle=%d name=%s"):format(data.index or -1, fullName))
		end
		return
	end
	if not helpers.landingTrackingEnabled() then return end

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

	state.teleportParticles = state.teleportParticles or {}
	local now = GameRules.GetGameTime()
	local particle = {index = data.index, ownerIndex = owner and Entity.GetIndex(owner) or nil, createdAt = now,
		departure = departure == true, destination = destination == true, fullName = fullName}
	state.teleportParticles[data.index] = particle
	logDebug("TP TRACK", ("create particle=%d type=%s owner=%s name=%s"):format(
		data.index or -1, departure and "departure" or "destination", particle.ownerIndex and tostring(particle.ownerIndex) or "pending", fullName))

	if departure then
		if owner then helpers.bindTeleportDeparture(particle, now, Entity.GetIndex(owner), "particle_owner") end
		return
	end

	-- Destination particles are often world particles: OnParticleCreate may have no entity/owner.
	-- Keep them instead of dropping them; modifier_teleporting owns the hero/time and is paired later.
	if owner then
		state.landings = state.landings or {}
		local index = Entity.GetIndex(owner)
		local record = state.landings[index]
		if not record or record.kind ~= "teleport" or math.abs((record.createdAt or now) - now) > 0.75 then
			local duration = cfg.fogTeleportDuration
			local boots = NPC.GetItem(owner, "item_travel_boots_2", true)
			if boots then duration = Ability.GetLevelSpecialValueFor(boots, "tp_channel_time") end
			if duration > 0 then
				state.landings[index] = {index = index, name = "modifier_teleporting", kind = "teleport",
					createdAt = now, endsAt = now + duration, estimated = true, particleIndex = data.index}
			end
		end
	end
	helpers.bindTeleportDestination(particle, now)
end

function helpers.updateTeleportParticle(data)
	local particle = state.teleportParticles and state.teleportParticles[data.index]
	if not particle then return end
	if particle.departure then
		local now = GameRules.GetGameTime()
		if data.controlPoint == 0 and data.position then
			particle.position = copyPoint(data.position)
			particle.positionAt = now
		end
		if data.controlPoint == 7 and data.position and data.position.x > 0 and data.position.x <= cfg.teleportParticleLifetime then
			particle.endsAt = particle.createdAt + data.position.x
		end
		helpers.bindTeleportDeparture(particle, now)
		return
	end
	if data.controlPoint ~= 0 and data.controlPoint ~= 5 or not data.position then return end
	if data.controlPoint == 5 and particle.controlPoint == 0 then return end
	local now = GameRules.GetGameTime()
	if particle.motionPosition and particle.motionAt and now - particle.motionAt >= 0.05 then
		local velocity = scale(subtract(data.position, particle.motionPosition), 1 / math.max(0.001, now - particle.motionAt))
		particle.velocity = length2D(velocity) <= 700 and velocity or nil
		particle.sampledAt = now
		particle.motionPosition, particle.motionAt = copyPoint(data.position), now
	elseif not particle.motionPosition then
		particle.motionPosition, particle.motionAt = copyPoint(data.position), now
	end
	if data.controlPoint == 0 then particle.targetIndex = nil end
	particle.position, particle.positionAt = copyPoint(data.position), now
	particle.controlPoint = data.controlPoint
	helpers.bindTeleportDestination(particle, now)
	local record = particle.ownerIndex and state.landings and state.landings[particle.ownerIndex] or nil
	if record and record.kind == "teleport" then
		record.teleportLastPosition = copyPoint(particle.position)
		record.teleportPositionAt = now
		record.teleportParticleIndex = particle.index
	end
	if not particle.historyAdded and particle.ownerIndex then
		particle.historyAdded = true
		state.teleportHistory = state.teleportHistory or {}
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
	if not particle then return end
	if particle.departure then
		local now = GameRules.GetGameTime()
		local explicit = data.entity and helpers.landingEnemy(data.entity) and Entity.GetIndex(data.entity) or nil
		if data.controlPoint == 0 and data.position then
			particle.position = copyPoint(data.position)
			particle.positionAt = now
		end
		helpers.bindTeleportDeparture(particle, now, explicit, explicit and "particle_entity_update" or nil)
		return
	end
	if data.controlPoint ~= 0 and data.controlPoint ~= 5 then return end
	if data.entity and Entity.IsNPC(data.entity) then particle.targetIndex = Entity.GetIndex(data.entity) end
	if data.position then
		particle.position = copyPoint(data.position)
		particle.positionAt = GameRules.GetGameTime()
	end
	helpers.bindTeleportDestination(particle, GameRules.GetGameTime())
end

function helpers.findTeleportCreep(particle, now)
	if not particle or not particle.ownerIndex or particle.targetIndex or particle.controlPoint ~= 5 or not particle.position
		or now < (particle.nextCreepSearchAt or 0)
	then return end
	particle.nextCreepSearchAt = now + 0.5
	local owner = Entity.Get(particle.ownerIndex)
	if not owner then return end
	local best, nearest, second = nil, math.huge, math.huge
	for _, creep in ipairs(NPCs.GetAll(Enum.UnitTypeFlags.TYPE_LANE_CREEP)) do
		local origin = Entity.GetAbsOrigin(creep)
		if origin and Entity.IsAlive(creep) and Entity.IsSameTeam(owner, creep) and not Entity.IsDormant(creep) and NPC.IsVisible(creep) then
			local distance = distance2D(origin, particle.position)
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
			and (record.teleportParticleIndex == particle.index or math.abs((particle.createdAt or 0) - (record.createdAt or 0)) <= 1.25)
			and (not best or particle.createdAt > best.createdAt)
		then best = particle end
	end
	if best then
		-- Use the destination particle itself as position truth.  Do not invent a hero-facing/move-speed point.
		-- If the destination marker is moving, extrapolate only its measured particle velocity for the tiny remaining horizon.
		if best.velocity and best.sampledAt and snapshot.now - best.sampledAt <= 0.25 and best.positionAt then
			return add(best.position, scale(best.velocity, math.max(0, record.endsAt - best.positionAt)))
		end
		return copyPoint(best.position)
	end
	if record.teleportLastPosition then return copyPoint(record.teleportLastPosition) end
	return nil
end

function helpers.updateLandingTracks(snapshot, settings)
	if not settings.sunStrike and not settings.landingSun and not settings.cataclysm then
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
				-- v44: a hidden lift-state record is stronger evidence than a missing modifier poll.
				-- Keep it alive through its predicted airborne interval; OnEntityHurt is landing damage only.
				local confirmedTornadoActive = record and (record.fogTornadoLift or record.fogTornadoHit)
					and record.name == "modifier_invoker_tornado" and record.endsAt
					and snapshot.now <= record.endsAt + cfg.landingMaxLate
				if record and (not record.estimated or snapshot.now - record.createdAt > 0.2) and not record.cancelled then
					if confirmedTornadoActive then
						logChanged("landing_track_scan_hold_" .. tostring(record.index), "LANDING TRACK",
							("target=%d source=scan_miss ignored=true confirmed_tornado=true ends_in=%.2f"):format(
								record.index, math.max(0, record.endsAt - snapshot.now)))
					else
						record.cancelled = true
						logDebug("LANDING TRACK", ("target=%d source=scan_miss cancelled=true"):format(Entity.GetIndex(unit)))
					end
				end
			end
		end
	end
	for index, record in pairs(state.landings) do
		if snapshot.now > record.endsAt + 1 then state.landings[index] = nil end
	end
	for index, particle in pairs(state.teleportParticles or {}) do
		if snapshot.now - particle.createdAt > cfg.teleportParticleLifetime then
			state.teleportParticles[index] = nil
		elseif particle.departure then
			helpers.bindTeleportDeparture(particle, snapshot.now)
		else
			helpers.bindTeleportDestination(particle, snapshot.now)
			helpers.findTeleportCreep(particle, snapshot.now)
		end
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

	local teleportMode = nil
	if record.kind == "teleport" then
		if settings.landingTeleportAnyHp then teleportMode = "any_hp"
		elseif settings.landingTeleportLethal then teleportMode = "lethal"
		else return nil end
	end

	-- v57: TP still uses a live remaining-time verdict, but the verdict/order schedule now accounts for
	-- the same measured order->cast-start delay used by ordinary Landing Sun. v81 targets +0.03 s
	-- after TP completion. Runtime command delay is accounted for by moving the physical order earlier;
	-- the 30 ms landing safety is the impact target, not an extra post-order wait. Therefore the
	-- one-shot TP verdict also has to move earlier by the measured command delay. The configured
	-- 1.70 s value remains the minimum/base trigger; runtime trigger becomes max(base, impactDelay).
	local delay, commandDelay, timingSource, landingOffset
	local medianCommand, modeledCommand, fastResidual, fastSamples
	local castAt, naturalCastAt, latest, tornadoImmediate, tornadoAirborne
	if record.kind == "teleport" then
		delay, commandDelay, timingSource, medianCommand, modeledCommand, fastResidual, fastSamples = helpers.landingOrderImpactDelay(snapshot, "sun_strike")
		timingSource = "tp-command-aware-" .. tostring(timingSource)
		landingOffset = cfg.teleportSunLandingDelay
		castAt = record.endsAt + landingOffset - delay
		naturalCastAt = castAt
		latest = castAt + cfg.landingMaxLate
	else
		landingOffset = record.name == "modifier_invoker_tornado" and cfg.tornadoLandingImpactOffset or cfg.landingImpactOffset
		if record.name == "modifier_invoker_tornado" then
			delay, commandDelay, timingSource, medianCommand, modeledCommand, fastResidual, fastSamples = helpers.landingOrderImpactDelay(snapshot, "sun_strike")
			castAt, naturalCastAt, tornadoImmediate, tornadoAirborne = helpers.controlledLandingCastTime(
				snapshot.now, record.endsAt, delay, landingOffset)
			latest = tornadoImmediate and (record.endsAt + cfg.landingMaxLate) or (naturalCastAt + cfg.landingMaxLate)
			-- Tornado Landing Sun is a PRE-LANDING control path. Once the lift ended, ordinary Auto-Sun owns the target.
			if not tornadoAirborne then return nil end
		else
			delay, commandDelay, timingSource, medianCommand, modeledCommand, fastResidual, fastSamples = helpers.landingOrderImpactDelay(snapshot, "sun_strike")
			castAt = record.endsAt + landingOffset - delay
			naturalCastAt = castAt
			latest = castAt + cfg.landingMaxLate
		end
	end
	local timingSignature = ("%s|%.3f|%.3f|%.3f|%d|%.3f|%.3f"):format(tostring(timingSource or "?"),
		modeledCommand or 0, medianCommand or 0, fastResidual or 0, fastSamples or 0, commandDelay or 0, landingOffset or 0)
	if record.scheduledSunTimingSignature ~= timingSignature then
		record.scheduledSunTimingSignature = timingSignature
		logDebug("SCHEDULED SUN TIMING", ("target=%d kind=%s source=%s modeled=%.3f median=%.3f fastResidual=%.3f fastN=%d command=%.3f fixed=%.3f offset=%.3f cast_in=%.3f"):format(
			record.index or -1, tostring(record.name or record.kind or "?"), tostring(timingSource or "?"), modeledCommand or 0,
			medianCommand or 0, fastResidual or 0, fastSamples or 0, commandDelay or 0,
			math.max(0, (delay or 0) - (commandDelay or 0)), landingOffset or 0, (castAt or snapshot.now) - snapshot.now))
	end
	if snapshot.now > latest then return nil end

	-- v42 restores the donor landing model: the landing record owns one fixed landing point and one
	-- authoritative endsAt. Tornado only extends the donor's lethal check with its real damage; it does
	-- not create a second reservation/arbitration path. A Tornado victim lands on the frozen lift axis.
	local position
	if record.name == "modifier_invoker_tornado" and record.tornadoLiftPosition then
		position = copyPoint(record.tornadoLiftPosition)
	else
		position = record.kind == "teleport" and helpers.teleportLandingPosition(record, snapshot) or record.position
	end
	if not position then return nil end

	-- v57 TP decision ownership: do not keep re-checking later HP and creating a late shot. The TP mode
	-- is sampled once when live remaining crosses the command-aware trigger (base 1.70 s + physical
	-- order->cast-start contribution). A late-discovered TP beyond one scan-sized tolerance is still
	-- intentionally skipped rather than firing at an arbitrary later point.
	local teleportDecisionNow = false
	local teleportRemaining = nil
	local teleportTriggerRemaining = cfg.teleportSunTriggerRemaining
	local teleportCastRemaining = nil
	if record.kind == "teleport" then
		-- Keep the one-shot TP verdict, but place the physical order from measured command delay so
		-- impact targets TP end + the configured 0.03 s landingOffset.
		teleportTriggerRemaining = math.max(cfg.teleportSunTriggerRemaining, delay)
		teleportCastRemaining = math.max(0, delay - landingOffset)
		if record.teleportSunDecisionMode ~= teleportMode then
			record.teleportSunDecisionMode = teleportMode
			record.teleportSunDecisionMade = nil
			record.teleportSunDecisionPassed = nil
			record.teleportSunDecisionAt = nil
			record.teleportSunDecisionRemaining = nil
		end
		teleportRemaining = math.max(0, record.endsAt - snapshot.now)
		if not record.teleportSunDecisionMade then
			if teleportRemaining > teleportTriggerRemaining then
				-- Preserve the existing self-charge contract while moving the TP verdict only as far earlier as
				-- required by the measured physical command delay. If Sun is not in D/F and self-charge is
				-- allowed, the shared EEE->Invoke preparation may still start before that verdict. HP/Any-HP
				-- is sampled exactly once at the command-aware trigger, and CastPosition remains held to the
				-- safety-adjusted order point (impactDelay - landingOffset remaining).
				local prePreparation, prePreparationSource = helpers.landingPreparationRemaining(snapshot, "sun_strike", settings)
				if not record.teleportSunPrechargeStarted then
					if prePreparation == math.huge or prePreparation <= 0
						or teleportRemaining > teleportTriggerRemaining + prePreparation + 0.4
					then return nil end
					record.teleportSunPrechargeStarted = true
					logDebug("TP SUN", ("target=%d precharge=true remaining=%.2f trigger=%.2f prep=%.3f prepSource=%s destination=%.0f,%.0f -> HOLD CAST"):format(
						record.index, teleportRemaining, teleportTriggerRemaining, prePreparation,
						tostring(prePreparationSource or "?"), position.x, position.y))
				end
				return {position = copyPoint(position), castAt = castAt, latest = latest, impactDelay = delay, landingOffset = landingOffset,
					commandDelay = commandDelay, timingSource = timingSource, preparation = prePreparation,
					preparationSource = prePreparationSource, tornadoCombinedLethal = false,
					queueReady = snapshot.now + prePreparation + 0.4 >= castAt}
			end
			if teleportRemaining < teleportTriggerRemaining - cfg.teleportSunTriggerLateTolerance then
				record.teleportSunDecisionMade = true
				record.teleportSunDecisionPassed = false
				record.teleportSunDecisionAt = snapshot.now
				record.teleportSunDecisionRemaining = teleportRemaining
				logDebug("TP SUN", ("target=%d mode=%s decision=missed remaining=%.2f trigger=%.2f base=%.2f safety=%.2f command=%.3f impactDelay=%.3f cast_remaining=%.2f destination=%.0f,%.0f source=%s -> NO LATE SHOT"):format(
					record.index, tostring(teleportMode), teleportRemaining, teleportTriggerRemaining, cfg.teleportSunTriggerRemaining,
					cfg.teleportSunLandingDelay, commandDelay or 0, delay or 0, teleportCastRemaining or 0,
					position.x, position.y, record.estimated and "estimate" or "modifier"))
				return nil
			end
			teleportDecisionNow = true
		elseif not record.teleportSunDecisionPassed then
			return nil
		end
	end

	local tornadoCombinedLethal = false
	local tornadoProjectedPreHealth, tornadoProjectedPostHealth, tornadoSunDamage, tornadoCombinedDamage
	local requireLethal = record.kind == "teleport" and teleportMode == "lethal" or record.kind ~= "teleport" and settings.landingLethal
	if requireLethal and not (record.kind == "teleport" and record.teleportSunDecisionMade) then
		local impactAt = record.endsAt + landingOffset
		local horizon = math.max(delay, impactAt - snapshot.now)
		local split = helpers.landingSunSplitCount(snapshot, record, position, math.max(cfg.sunRadius, mechanics.radius), impactAt)
		local damage = mechanics.expectedDamage / split

		if record.name == "modifier_invoker_tornado" and record.tornadoDamage ~= nil
			and record.tornadoPostHitHealth ~= nil
		then
			-- Tornado + Sun budget is available BEFORE landing. While airborne it uses live spell damage
			-- plus target magic reduction; the landing OnEntityHurt later replaces that estimate with actual damage.
			-- Reconstruct the pre-hit budget for the exact user-facing rule:
			-- projected pre-hit HP <= actual Tornado damage + split Sun damage.
			-- This is algebraically identical to projected post-Tornado HP <= split Sun damage, so Tornado
			-- is counted exactly once while the log still exposes both payloads explicitly.
			local maxHealth = record.tornadoPreHitMaxHealth or Entity.GetMaxHealth(unit)
			local regen = record.tornadoPreHitRegen or math.max(0, NPC.GetHealthRegen(unit))
			-- v84: scheduled Landing SS deliberately uses the fastest credible command envelope so it cannot
			-- arrive before landing. The same match may have a slower median order->cast-start. For lethal-only
			-- qualification, project regen through that measured late-arrival reserve too; this prevents exact
			-- 525 HP vs 525 damage from being called a guaranteed kill when the real SS can land ~0.1 s later.
			local lateImpactReserve = math.max(0, (medianCommand or 0) - (commandDelay or 0))
			local fromHitToImpact = math.max(0, record.endsAt + landingOffset + lateImpactReserve - (record.tornadoHitAt or snapshot.now))
			tornadoProjectedPostHealth = math.min(maxHealth, record.tornadoPostHitHealth + regen * fromHitToImpact)
			tornadoProjectedPreHealth = math.min(maxHealth,
				(record.tornadoPreHitHealth or (record.tornadoPostHitHealth + record.tornadoDamage)) + regen * fromHitToImpact)
			tornadoSunDamage = damage
			tornadoCombinedDamage = record.tornadoDamage + damage
			tornadoCombinedLethal = tornadoProjectedPreHealth <= tornadoCombinedDamage
			record.tornadoProjectedPostHealth = tornadoProjectedPostHealth
			record.tornadoProjectedPreHealth = tornadoProjectedPreHealth
			record.tornadoSunDamage = tornadoSunDamage
			record.tornadoCombinedDamage = tornadoCombinedDamage
			record.tornadoCombinedLethal = tornadoCombinedLethal
			if record.tornadoLethalLastPass ~= tornadoCombinedLethal then
				record.tornadoLethalLastPass = tornadoCombinedLethal
				logDebug("TORNADO+SUN LETHAL", ("target=%d hpAfter=%.0f hpAtImpact=%.0f preHpAtImpact=%.0f tornado=%.0f damageSource=%s sun=%.0f total=%.0f split=%d lateReserve=%.3f landing=%.0f,%.0f pass=%s"):format(
					record.index, record.tornadoPostHitHealth, tornadoProjectedPostHealth, tornadoProjectedPreHealth,
					record.tornadoDamage, record.tornadoDamageEstimated and "estimated_prelanding" or "actual_landing", damage, tornadoCombinedDamage, split, lateImpactReserve, position.x, position.y,
					tostring(tornadoCombinedLethal)))
			end
			if not tornadoCombinedLethal then return nil end
		else
			-- Original donor rule for Eul / modifier-only fallback: current HP + regen must fit in the split
			-- Sun payload. TP uses the same damage math, but freezes the verdict at the v54 1.70 s decision point.
			local health, maxHealth = Entity.GetHealth(unit), Entity.GetMaxHealth(unit)
			if health <= 0 or maxHealth <= 0 then return nil end
			local projectedHealth = math.min(maxHealth, health + math.max(0, NPC.GetHealthRegen(unit)) * horizon)
			local pass = projectedHealth <= damage
			if record.kind == "teleport" then
				record.teleportSunDecisionMade = true
				record.teleportSunDecisionPassed = pass
				record.teleportSunDecisionAt = snapshot.now
				record.teleportSunDecisionRemaining = teleportRemaining
				record.teleportSunDecisionProjectedHealth = projectedHealth
				record.teleportSunDecisionDamage = damage
				record.teleportSunDecisionSplit = split
				logDebug("TP SUN", ("target=%d mode=lethal decision=%.2f trigger=%.2f base=%.2f safety=%.2f command=%.3f impactDelay=%.3f cast_remaining=%.2f hp=%.0f damage=%.0f split=%d destination=%.0f,%.0f source=%s pass=%s"):format(
					record.index, teleportRemaining or -1, teleportTriggerRemaining, cfg.teleportSunTriggerRemaining, cfg.teleportSunLandingDelay,
					commandDelay or 0, delay or 0, teleportCastRemaining or 0, projectedHealth, damage, split,
					position.x, position.y, record.estimated and "estimate" or "modifier", tostring(pass)))
			end
			if not pass then return nil end
		end
	end
	if record.kind == "teleport" and teleportMode == "any_hp" and teleportDecisionNow then
		record.teleportSunDecisionMade = true
		record.teleportSunDecisionPassed = true
		record.teleportSunDecisionAt = snapshot.now
		record.teleportSunDecisionRemaining = teleportRemaining
		logDebug("TP SUN", ("target=%d mode=any_hp decision=%.2f trigger=%.2f base=%.2f safety=%.2f command=%.3f impactDelay=%.3f cast_remaining=%.2f destination=%.0f,%.0f source=%s pass=true"):format(
			record.index, teleportRemaining or -1, teleportTriggerRemaining, cfg.teleportSunTriggerRemaining, cfg.teleportSunLandingDelay,
			commandDelay or 0, delay or 0, teleportCastRemaining or 0, position.x, position.y,
			record.estimated and "estimate" or "modifier"))
	end
	if record.kind == "teleport" and not record.teleportSunDecisionPassed then return nil end

	-- Preparation feasibility remains strict for TP/Eul. v61 gives an already-airborne Tornado victim
	-- a best-effort immediate path when the ideal landing-synchronised order time has already passed.
	local preparation, preparationSource = helpers.landingPreparationRemaining(snapshot, "sun_strike", settings)
	if preparation == math.huge then return nil end
	if tornadoImmediate then
		-- The ideal order time is already behind us. Start/finish EEE->Invoke immediately, but require
		-- the command chain to become executable no later than the lift end (+ tiny existing tolerance).
		if snapshot.now + preparation > record.endsAt + cfg.landingMaxLate then return nil end
	else
		if snapshot.now + preparation > castAt + cfg.landingOrderTolerance then return nil end
	end
	if tornadoImmediate then
		logChanged("tornado_sun_immediate_" .. tostring(record.index), "TORNADO SUN TIMING",
			("target=%d mode=IMMEDIATE remaining=%.2f impactDelay=%.3f safety=%.3f natural_in=%.2f prep=%.3f -> CAST ASAP"):format(
				record.index, math.max(0, record.endsAt - snapshot.now), delay or 0, landingOffset or 0,
				(naturalCastAt or snapshot.now) - snapshot.now, preparation or 0))
	end
	return {position = copyPoint(position), castAt = castAt, naturalCastAt = naturalCastAt, latest = latest, impactDelay = delay, landingOffset = landingOffset,
		commandDelay = commandDelay, timingSource = timingSource, preparation = preparation,
		preparationSource = preparationSource, tornadoCombinedLethal = tornadoCombinedLethal, tornadoImmediate = tornadoImmediate == true,
		tornadoProjectedPreHealth = tornadoProjectedPreHealth, tornadoProjectedPostHealth = tornadoProjectedPostHealth,
		tornadoSunDamage = tornadoSunDamage, tornadoCombinedDamage = tornadoCombinedDamage,
		queueReady = tornadoImmediate == true or snapshot.now + preparation + 0.4 >= castAt}
end

-- v49: the first Tornado victim that passes the Landing-Sun lethal/feasibility check owns the
-- single-target Sun Strike for that Tornado. Later victims are NOT allowed to replace this target or
-- cancel it merely because their own HP check fails. The lock snapshots the proven landing point/time
-- so transient modifier scan misses cannot erase the already-confirmed shot. Cataclysm remains a
-- separate higher-priority subsystem and may still promote/pre-empt this single-target lock.
function helpers.releaseLandingSunLock(reason)
	local lock = state.landingSunLock
	if not lock then return end
	logDebug("LANDING SUN LOCK", ("release target=%d reason=%s"):format(lock.targetIndex or -1, tostring(reason or "unknown")))
	state.landingSunLock = nil
end

function helpers.copyLandingSunLockRecord(record)
	if not record then return nil end
	return {
		index = record.index, name = record.name, kind = record.kind, createdAt = record.createdAt,
		endsAt = record.endsAt, estimated = record.estimated, ambiguousTiming = record.ambiguousTiming,
		position = record.position and copyPoint(record.position) or nil,
		tornadoLiftPosition = record.tornadoLiftPosition and copyPoint(record.tornadoLiftPosition) or nil,
		tornadoDamage = record.tornadoDamage, tornadoDamageEstimated = record.tornadoDamageEstimated,
		tornadoPostHitHealth = record.tornadoPostHitHealth, tornadoPreHitHealth = record.tornadoPreHitHealth,
		tornadoPreHitMaxHealth = record.tornadoPreHitMaxHealth, tornadoPreHitRegen = record.tornadoPreHitRegen,
		tornadoHitAt = record.tornadoHitAt, tornadoLiftAt = record.tornadoLiftAt,
		tornadoHitInFog = record.tornadoHitInFog, tornadoCasterIndex = record.tornadoCasterIndex,
		tornadoCooldownEnd = record.tornadoCooldownEnd, tornadoLiftDuration = record.tornadoLiftDuration,
		tornadoQuasLevel = record.tornadoQuasLevel, landingSunSplitMax = record.landingSunSplitMax,
		cancelled = false, fired = false, landingSunLocked = true,
	}
end

function helpers.claimLandingSunLock(record, window, snapshot)
	if state.landingSunLock or not record or not window then return state.landingSunLock end
	local frozen = helpers.copyLandingSunLockRecord(record)
	if not frozen then return nil end
	state.landingSunLock = {
		targetIndex = record.index, tornadoToken = record.tornadoCooldownEnd, hitAt = record.tornadoHitAt or record.createdAt or snapshot.now,
		lockedAt = snapshot.now, record = frozen, position = copyPoint(window.position), endsAt = frozen.endsAt,
		castAt = window.castAt, naturalCastAt = window.naturalCastAt or window.castAt, latest = window.latest, impactDelay = window.impactDelay, landingOffset = window.landingOffset,
		commandDelay = window.commandDelay, timingSource = window.timingSource, tornadoImmediate = window.tornadoImmediate == true, fog = record.tornadoHitInFog == true,
	}
	logDebug("LANDING SUN LOCK", ("claim target=%d fog=%s hit=%.3f cast_in=%.2f ends_in=%.2f source=first_lethal_tornado"):format(
		record.index, tostring(record.tornadoHitInFog == true), state.landingSunLock.hitAt,
		window.castAt - snapshot.now, frozen.endsAt - snapshot.now))
	return state.landingSunLock
end

function helpers.landingSunLockedWindow(snapshot, settings, lock)
	lock = lock or state.landingSunLock
	if not lock then return nil end
	if not settings.landingSun or not settings.landingLethal then
		if lock == state.landingSunLock then helpers.releaseLandingSunLock("disabled") end
		return nil
	end
	if lock.record and lock.record.name == "modifier_invoker_tornado" and (lock.endsAt or lock.record.endsAt or -math.huge) <= snapshot.now then
		if lock == state.landingSunLock then helpers.releaseLandingSunLock("Tornado lift ended before order") end
		return nil
	end
	if snapshot.now > (lock.latest or -math.huge) then
		if lock == state.landingSunLock then helpers.releaseLandingSunLock("window expired") end
		return nil
	end
	local unit = Entity.Get(lock.targetIndex)
	if not helpers.landingEnemy(unit) or not Entity.IsAlive(unit) then
		if lock == state.landingSunLock then helpers.releaseLandingSunLock("target dead/invalid") end
		return nil
	end
	if not helpers.hasAutoSunMana(snapshot, settings) then return nil end
	-- v53: a first-lethal Tornado lock keeps target identity, but not an obsolete split=1 assumption.
	-- If another controlled hero will be inside the landing AoE at impact, re-check the per-unit Sun
	-- damage before preserving the lock. This prevents a two-hero lift from being called lethal when
	-- the Sun payload will actually be divided between both heroes.
	if lock.record and lock.record.name == "modifier_invoker_tornado" and lock.record.tornadoDamage ~= nil then
		local mechanics = resolveMechanics("sun_strike", snapshot, 0)
		local impactAt = (lock.endsAt or lock.record.endsAt or snapshot.now) + (lock.landingOffset or 0)
		local split = helpers.landingSunSplitCount(snapshot, lock.record, lock.position,
			math.max(cfg.sunRadius, mechanics.radius), impactAt)
		local sunDamage = mechanics.expectedDamage / split
		local maxHealth = lock.record.tornadoPreHitMaxHealth or Entity.GetMaxHealth(unit)
		local regen = lock.record.tornadoPreHitRegen or math.max(0, NPC.GetHealthRegen(unit))
		local lateImpactReserve = math.max(0, (state.sunCommandDelayMedianObserved or 0) - (lock.commandDelay or 0))
		local fromHitToImpact = math.max(0, impactAt + lateImpactReserve - (lock.record.tornadoHitAt or snapshot.now))
		local projectedPreHealth = math.min(maxHealth,
			(lock.record.tornadoPreHitHealth or ((lock.record.tornadoPostHitHealth or 0) + lock.record.tornadoDamage))
				+ regen * fromHitToImpact)
		local combinedDamage = lock.record.tornadoDamage + sunDamage
		local lethal = projectedPreHealth <= combinedDamage + 0.001
		logChanged("landing_lock_split_" .. tostring(lock.targetIndex), "LANDING LOCK SPLIT",
			("target=%d split=%d hp=%.0f tornado=%.0f sun=%.0f total=%.0f lateReserve=%.3f pass=%s"):format(
				lock.targetIndex or -1, split, projectedPreHealth, lock.record.tornadoDamage or 0,
				sunDamage, combinedDamage, lateImpactReserve, tostring(lethal)))
		if not lethal then
			if lock == state.landingSunLock then helpers.releaseLandingSunLock("landing split no longer lethal") end
			return nil
		end
	end
	local preparation, preparationSource = helpers.landingPreparationRemaining(snapshot, "sun_strike", settings)
	if preparation == math.huge then return nil end
	local naturalCastAt = lock.naturalCastAt or lock.castAt
	local immediate = lock.record and lock.record.name == "modifier_invoker_tornado" and naturalCastAt <= snapshot.now
	local castAt = immediate and snapshot.now or lock.castAt
	if immediate then
		if snapshot.now + preparation > (lock.endsAt or lock.record.endsAt or snapshot.now) + cfg.landingMaxLate then return nil end
	elseif snapshot.now + preparation > castAt + cfg.landingOrderTolerance then
		return nil
	end
	return {
		position = copyPoint(lock.position), castAt = castAt, naturalCastAt = naturalCastAt, latest = lock.latest,
		impactDelay = lock.impactDelay, landingOffset = lock.landingOffset, commandDelay = lock.commandDelay,
		timingSource = lock.timingSource, preparation = preparation, preparationSource = preparationSource,
		tornadoCombinedLethal = true, tornadoImmediate = immediate, queueReady = immediate or snapshot.now + preparation + 0.4 >= castAt,
	}
end

function helpers.selectLandingSun(snapshot, settings)
	if not settings.landingSun or not helpers.objectiveSunReady(snapshot, settings) then return nil end
	local lock = state.landingSunLock
	if lock then
		local window = helpers.landingSunLockedWindow(snapshot, settings, lock)
		if window and window.queueReady then return lock.record end
		-- A confirmed first-lethal Tornado target reserves the single-target Landing Sun. Do not
		-- fall through to a later Tornado victim (or another landing) while this lock is alive.
		if state.landingSunLock then return nil end
	end
	local best, earliest = nil, math.huge
	for _, record in pairs(state.landings or {}) do
		-- Tornado+lethal selection is owned by the explicit first-pass lock below. Other landing
		-- kinds, and Tornado when lethal filtering is disabled, retain the donor selector.
		if not (settings.landingLethal and record.name == "modifier_invoker_tornado") then
			local window = helpers.landingSunWindow(record, snapshot, settings)
			if window and window.queueReady and window.castAt < earliest then best, earliest = record, window.castAt end
		end
	end
	return best
end

-- v49: evaluate Tornado victims in actual catch order. The first victim whose combined Tornado+Sun
-- budget passes and whose preparation is feasible becomes a sticky Landing-Sun lock. Later victims
-- remain diagnostics/Cataclysm inputs only; they cannot replace the locked single-target Sun.
function helpers.evaluateTornadoLandingLethals(snapshot, settings)
	if not settings.landingSun or not settings.landingLethal then
		if state.landingSunLock then helpers.releaseLandingSunLock("lethal mode disabled") end
		return 0, 0
	end
	-- Validate/release an existing lock before considering any new victim.
	if state.landingSunLock then helpers.landingSunLockedWindow(snapshot, settings, state.landingSunLock) end
	local records = {}
	for _, record in pairs(state.landings or {}) do
		if record.name == "modifier_invoker_tornado" and record.tornadoDamage ~= nil
			and not record.cancelled and not record.fired and record.endsAt
			and record.endsAt > snapshot.now - cfg.landingMaxLate
		then records[#records + 1] = record end
	end
	table.sort(records, function(left, right)
		local leftHit = left.tornadoHitAt or left.createdAt or 0
		local rightHit = right.tornadoHitAt or right.createdAt or 0
		if leftHit == rightHit then return left.index < right.index end
		return leftHit < rightHit
	end)
	local activeCount, lethalCount = #records, 0
	for _, record in ipairs(records) do
		local window = helpers.landingSunWindow(record, snapshot, settings)
		if window and window.tornadoCombinedLethal then
			lethalCount = lethalCount + 1
			local box, required, left = helpers.tornadoCataclysmFirstHold(record, snapshot, settings)
			if box then
				logChanged("cata_first_hold_" .. tostring(box.firstIndex or record.index), "CATA FIRST HOLD",
					("target=%d box=%d/%d wait=%.2f -> SINGLE LANDING SUN HELD"):format(
						record.index, #(box.indices or {}), required or 2, left or 0))
			elseif not state.landingSunLock then
				helpers.claimLandingSunLock(record, window, snapshot)
			end
		end
	end
	if activeCount > 0 then
		logChanged("tornado_sun_check", "TORNADO+SUN CHECK",
			("active=%d lethal=%d mode=first_lethal_lock locked=%s"):format(
				activeCount, lethalCount, state.landingSunLock and tostring(state.landingSunLock.targetIndex) or "none"))
	end
	return activeCount, lethalCount
end

function helpers.queueLandingSun(record, snapshot, settings)
	local lock = state.landingSunLock
	local locked = lock and record == lock.record
	local window = locked and helpers.landingSunLockedWindow(snapshot, settings, lock) or helpers.landingSunWindow(record, snapshot, settings)
	if not window or not queueAutoAction("sun_strike", record, "landing_sun", snapshot) then return false end
	state.autoPending.landing = record
	state.autoPending.landingSunLock = locked and lock or nil
	state.autoPending.position = window.position
	state.autoPending.expiresAt = window.latest + 0.01
	state.nextAutoActionAt = snapshot.now
	logDebug("ARRIVAL", ("target=%d source=%s cast_in=%.2f natural_in=%.2f mode=%s prep=%.3f prepSource=%s impactDelay=%.3f offset=%.3f command=%.3f timing=%s aim=%.0f,%.0f lock=%s"):format(
		record.index, record.estimated and "particle estimate" or "modifier", window.castAt - snapshot.now,
		(window.naturalCastAt or window.castAt) - snapshot.now, window.tornadoImmediate and "tornado_immediate" or "scheduled",
		window.preparation or 0, tostring(window.preparationSource or "?"), window.impactDelay or 0, window.landingOffset or 0,
		window.commandDelay or 0, tostring(window.timingSource or "?"), window.position.x, window.position.y, tostring(locked)))
	return true
end

-- Landing Cataclysm owns a simultaneous landing group of controlled heroes. For ordinary Eul/TP
-- groups the timing anchor remains the latest landing. For one travelling Invoker Tornado, v43 uses
-- the LAST HERO ACTUALLY HIT by that Tornado as the timing anchor, per the runtime requirement.
function helpers.landingCataclysmRecordActive(record, snapshot, settings)
	if not record or record.cancelled or record.fired or record.estimated and record.ambiguousTiming then return false end
	-- v47: Invoker Tornado targets belong to the Cataclysm subsystem even when the Auto-Sun
	-- master (and therefore the Landing-Sun cyclone child toggle) is OFF. Other landing kinds
	-- retain their historical Landing-Sun child filters.
	if record.name ~= "modifier_invoker_tornado" then
		if record.kind == "teleport" and not settings.landingTeleports
			or record.kind == "cyclone" and not settings.landingCyclones
		then return false end
	end
	if not record.endsAt or record.endsAt <= snapshot.now - cfg.landingMaxLate then return false end
	local unit = Entity.Get(record.index)
	return helpers.landingEnemy(unit) and Entity.IsAlive(unit)
end

function helpers.landingPreparationRemaining(snapshot, id, settings)
	local action = snapshot.actions and snapshot.actions[id] or nil
	if not action or not action.exists then return math.huge, "no_action" end
	if action.invoked and action.activeSlotIndex ~= nil then return 0, "df_ready" end
	if not helpers.autoSelfChargeEnabled(id, settings) then return math.huge, "self_charge_off" end
	if not snapshot.invoke or not snapshot.invoke.exists then return math.huge, "no_invoke" end

	local sequence = state.invokeSequence
	if sequence and sequence.actionId == canonicalSpell(id) then
		if sequence.castIssued then
			return math.max(0.06, math.max(0, snapshot.latency or 0) + 0.04), "invoke_confirm"
		end
		local waitNext = math.max(0, (sequence.nextAt or snapshot.now) - snapshot.now)
		local recipeCount = #(sequence.recipe or {})
		local remainingOrbs = math.max(0, recipeCount - (sequence.step or 1) + 1)
		local publish = math.max(0.08, math.max(0, snapshot.latency or 0) + 0.06)
		return waitNext + remainingOrbs * cfg.invokeOrbInterval + publish, "invoke_sequence"
	end

	local invokeWait = snapshot.invoke.ready and 0 or math.max(0, snapshot.invoke.cooldown or math.huge)
	local preparation = invokeWait + math.max(0.16, cfg.invokeOrbInterval * 3 + 0.06 + math.max(0, snapshot.latency or 0))
	return preparation, "invoke_wait"
end

function helpers.sameTornadoLanding(left, right)
	if not left or not right or left.name ~= "modifier_invoker_tornado" or right.name ~= "modifier_invoker_tornado" then return false end
	local leftCaster, rightCaster = left.tornadoCasterIndex, right.tornadoCasterIndex
	if leftCaster and rightCaster and leftCaster >= 0 and rightCaster >= 0 and leftCaster ~= rightCaster then return false end
	local leftToken, rightToken = left.tornadoCooldownEnd, right.tornadoCooldownEnd
	if leftToken and rightToken then return math.abs(leftToken - rightToken) <= 0.25 end
	-- Fallback for runtimes where Modifier.GetAbility/Cooldown is unavailable: local Invoker is
	-- the only normal source that can put modifier_invoker_tornado on enemy heroes.
	return true
end

-- v48 sliding Cataclysm confirmation boxes. Identity still comes from the same travelling Tornado,
-- but the confirmation timer now belongs to the NEWEST unique confirmed victim. Every new catch that
-- arrives before the current deadline increments the persistent counter, becomes the new landing anchor,
-- and resets the countdown from that catch. v56 includes the dedicated Cataclysm landing safety in every
-- reset: at Quas 8 this is normally 2.60 + 0.03 - 1.70 = 0.93 s. Earlier victims
-- remain only as +1 confirmations; they no longer own timing. If no new victim arrives before the newest
-- deadline, the qualified Cataclysm is released against the newest anchor. Visible and fog-confirmed lifts
-- use the exact same container. The persistent member set prevents old victims disappearing from state.landings
-- from reducing an already-confirmed count while a later victim owns the active safety-extended countdown.
function helpers.tornadoCataclysmContainers(records, snapshot, impactDelay)
	state.tornadoCataContainers = state.tornadoCataContainers or {}
	local containers = state.tornadoCataContainers
	local keep = {}
	for _, box in ipairs(containers) do
		-- Keep a closed box until its newest Tornado record itself is no longer live. Otherwise the
		-- still-present state.landings records would be re-ingested as a fresh box after pruning.
		local expiresAt = math.max((box.deadline or 0) + cfg.landingMaxLate + 0.50,
			(box.lastEndsAt or 0) + cfg.landingMaxLate + 0.50)
		if snapshot.now <= expiresAt then keep[#keep + 1] = box end
	end
	containers = keep
	state.tornadoCataContainers = containers

	local tornadoRecords = {}
	for _, record in ipairs(records) do
		if record.name == "modifier_invoker_tornado" then tornadoRecords[#tornadoRecords + 1] = record end
	end
	table.sort(tornadoRecords, function(left, right)
		local leftHit = left.tornadoHitAt or left.createdAt or 0
		local rightHit = right.tornadoHitAt or right.createdAt or 0
		if leftHit == rightHit then return left.index < right.index end
		return leftHit < rightHit
	end)

	for _, record in ipairs(tornadoRecords) do
		local hitAt = record.tornadoHitAt or record.createdAt or snapshot.now
		local memberBox = nil
		for i = #containers, 1, -1 do
			local box = containers[i]
			if helpers.sameTornadoLanding(box.firstRecord, record) and box.memberSet and box.memberSet[record.index] then
				memberBox = box
				break
			end
		end

		if memberBox then
			-- Hidden-state detection can later merge into the real modifier for the SAME victim.
			-- Refresh authoritative landing data, but never count or reset the box twice.
			if memberBox.lastRecordIndex == record.index then
				memberBox.lastRecord = record
				memberBox.lastEndsAt = record.endsAt or memberBox.lastEndsAt
				local remainingLift = math.max(0, (memberBox.lastEndsAt or hitAt) - memberBox.lastHitAt)
				memberBox.collectWindow = math.max(0, remainingLift + cfg.tornadoCataclysmLandingImpactOffset - impactDelay)
				memberBox.deadline = memberBox.lastHitAt + memberBox.collectWindow
			end
		else
			local selected = nil
			for i = #containers, 1, -1 do
				local box = containers[i]
				if helpers.sameTornadoLanding(box.firstRecord, record) then
					if hitAt >= (box.lastHitAt or box.startAt or hitAt) - cfg.landingCataclysmCollectTolerance
						and hitAt <= (box.deadline or -math.huge) + cfg.landingCataclysmCollectTolerance
					then selected = box end
					break
				end
			end
			if not selected then
				selected = {
					firstRecord = record, firstIndex = record.index, startAt = hitAt,
					records = {}, indices = {}, memberSet = {}, fogSet = {}, fogCount = 0,
					lastRecord = record, lastRecordIndex = record.index, lastHitAt = hitAt,
				}
				containers[#containers + 1] = selected
			end

			selected.records[#selected.records + 1] = record
			selected.indices[#selected.indices + 1] = record.index
			selected.memberSet[record.index] = true
			if record.tornadoHitInFog and not selected.fogSet[record.index] then
				selected.fogSet[record.index] = true
				selected.fogCount = selected.fogCount + 1
			end
			selected.lastRecord = record
			selected.lastRecordIndex = record.index
			selected.lastHitAt = hitAt
			selected.lastEndsAt = record.endsAt or hitAt
			local remainingLift = math.max(0, selected.lastEndsAt - hitAt)
			selected.collectWindow = math.max(0, remainingLift + cfg.tornadoCataclysmLandingImpactOffset - impactDelay)
			selected.deadline = hitAt + selected.collectWindow
			logDebug("CATA BOX HIT", ("target=%d count=%d fog=%d reset=%.2f first=%d last=%d"):format(
				record.index, #selected.indices, selected.fogCount or 0, selected.collectWindow or 0,
				selected.firstIndex or record.index, selected.lastRecordIndex or record.index))
		end
	end
	return containers
end

-- v53 Cataclysm-first reservation. When Aghanim/Exort Cataclysm is genuinely available and a
-- same-Tornado confirmation box is still open below the configured threshold, single-target Landing
-- Sun must wait. This is the only way to guarantee that a second/third victim caught inside the
-- safety-extended box (normally ~1.00 s at Quas 8 in v56) can become Cataclysm instead of losing the shared Sun cooldown to an earlier single Sun.
function helpers.tornadoCataclysmFirstHold(record, snapshot, settings)
	if not record or record.name ~= "modifier_invoker_tornado" or not snapshot or not settings
		or not settings.cataclysm or not settings.cataclysmTornado
		or snapshot.hero.upgrades.scepterChoice ~= "exort"
		or not helpers.hasAutoSunMana(snapshot, settings, "cataclysm")
		or not helpers.autoSpellReadyOrChargeable("cataclysm", snapshot, settings)
	then return nil end
	local action = snapshot.actions.cataclysm
	if not action or not action.exists or action.cooldown > 0.05 then return nil end
	local required = clamp(settings.cataclysmMinHeroes or 2, 2, 5)
	for i = #(state.tornadoCataContainers or {}), 1, -1 do
		local box = state.tornadoCataContainers[i]
		if box and box.memberSet and box.memberSet[record.index] and helpers.sameTornadoLanding(box.firstRecord, record) then
			local count = #(box.indices or {})
			local open = snapshot.now <= (box.deadline or -math.huge) + cfg.landingCataclysmCollectTolerance
			if open and count < required then
				local preparation = helpers.landingPreparationRemaining(snapshot, "cataclysm", settings)
				if preparation ~= math.huge then
					local cataImpactDelay = helpers.landingOrderImpactDelay(snapshot, "cataclysm")
					local lastEndsAt = box.lastEndsAt or record.endsAt or snapshot.now
					local naturalCastAt = lastEndsAt + cfg.tornadoCataclysmLandingImpactOffset - cataImpactDelay
					local castAt = math.max(naturalCastAt, box.deadline or naturalCastAt)
					if snapshot.now + preparation <= castAt + cfg.landingOrderTolerance then
						return box, required, math.max(0, (box.deadline or snapshot.now) - snapshot.now)
					end
				end
			end
			return nil
		end
	end
	return nil
end

function helpers.pendingLandingSunCataclysmHold(pending, snapshot, settings)
	if not pending or pending.kind ~= "landing_sun" or pending.cast then return nil end
	local record = pending.landingSunLock and pending.landingSunLock.record or pending.landing
	if not record then return nil end
	return helpers.tornadoCataclysmFirstHold(record, snapshot, settings)
end

-- v48: choose the latest feasible Cataclysm group. Tornado uses a persistent sliding confirmation
-- chain whose deadline is reset by every new unique victim; unrelated Eul/TP landings keep the historical
-- narrow time window. During an already-committed Cataclysm, refresh must overlap the committed container
-- so an unrelated landing cannot steal the in-progress cast.
function helpers.landingCataclysmWindow(snapshot, settings, requiredIndices)
	-- v45/v48: Landing Cataclysm is independent from every Sun-Strike master/landing toggle.
	if not settings.cataclysm
		or snapshot.hero.upgrades.scepterChoice ~= "exort"
		or not helpers.hasAutoSunMana(snapshot, settings, "cataclysm")
		or not helpers.autoSpellReadyOrChargeable("cataclysm", snapshot, settings)
	then return nil, "disabled_or_unavailable" end
	local action = snapshot.actions.cataclysm
	if not action or not action.exists or action.cooldown > 0.05 then return nil, "cooldown_or_missing" end

	local minHeroes = clamp(settings.cataclysmMinHeroes or 2, 2, 5)
	local records, fogRecords = {}, 0
	for _, record in pairs(state.landings or {}) do
		if helpers.landingCataclysmRecordActive(record, snapshot, settings) then
			records[#records + 1] = record
			if record.tornadoHitInFog then fogRecords = fogRecords + 1 end
		end
	end
	logChanged("landing_cata_check", "CATA CHECK",
		("targets=%d required=%d fog=%d landingSun=%s cataclysm=%s tornado=%s"):format(
			#records, minHeroes, fogRecords, tostring(settings.landingSun == true), tostring(settings.cataclysm == true),
			tostring(settings.cataclysmTornado == true)))
	local required = nil
	if requiredIndices then
		required = {}
		for _, index in ipairs(requiredIndices) do required[index] = true end
	end
	local preparation, preparationSource = helpers.landingPreparationRemaining(snapshot, "cataclysm", settings)
	if preparation == math.huge then return nil, preparationSource end

	-- Cataclysm uses its own 1.7 s (live fixed-delay) timer; ordinary Sun timing samples are not shared.
	local cataImpactDelay, cataCommandDelay, cataTimingSource = helpers.landingOrderImpactDelay(snapshot, "cataclysm")

	-- First evaluate the persistent sliding Tornado confirmation chain. Every new unique victim inside
	-- the current countdown stays in the same container, increments the old confirmations, becomes the
	-- newest anchor and resets the countdown from itself. Threshold=2 therefore means target1+target2
	-- qualifies, but target3 arriving before target2's reset deadline moves both the timer and anchor to 3.
	local containers = settings.cataclysmTornado and helpers.tornadoCataclysmContainers(records, snapshot, cataImpactDelay) or {}
	for i = #containers, 1, -1 do
		local box = containers[i]
		local overlapsCommitted = required == nil
		if required then
			for _, index in ipairs(box.indices) do if required[index] then overlapsCommitted = true; break end end
		end
		logChanged("cata_box_" .. tostring(box.firstIndex or box.firstRecord.index), "CATA BOX",
			("targets=%d required=%d fog=%d window=%.2f open=%s first=%d last=%d"):format(
				#box.indices, minHeroes, box.fogCount or 0, box.collectWindow or 0,
				tostring(snapshot.now <= box.deadline + cfg.landingCataclysmCollectTolerance),
				box.firstIndex or box.firstRecord.index, box.lastRecordIndex or box.lastRecord.index))
		if #box.indices >= minHeroes and overlapsCommitted then
			local timingAnchor = box.lastRecord
			local landingOffset = cfg.tornadoCataclysmLandingImpactOffset
			local lastEndsAt = box.lastEndsAt or timingAnchor.endsAt
			local policyImpactAt = lastEndsAt + landingOffset
			local policyPass, policyEval = helpers.cataclysmGroupPolicyPass(box.records, snapshot, settings, policyImpactAt)
			logChanged("cata_policy_box_" .. tostring(box.firstIndex or timingAnchor.index), "CATA POLICY",
				("group=tornado mode=%d targets=%d pass=%s target=%s hp=%.0f damage=%.0f threshold=%.0f"):format(
					settings.cataclysmUseMode or 0, #box.indices, tostring(policyPass),
					tostring(policyEval and policyEval.targetIndex or "any"), policyEval and policyEval.projectedHealth or 0,
					policyEval and policyEval.damage or 0, policyEval and policyEval.threshold or 0))
			if policyPass then
			local scheduledCastAt, naturalCastAt, immediate, airborne = helpers.controlledLandingCastTime(
				snapshot.now, lastEndsAt, cataImpactDelay, landingOffset)
			local latest = immediate and (lastEndsAt + cfg.landingMaxLate) or (naturalCastAt + cfg.landingMaxLate)
			-- The sliding box still owns +1-target collection while there is real time before the ideal order.
			-- Once that ideal order time has already passed but the newest victim is still airborne, stop
			-- waiting for a historical deadline and release Cataclysm NOW.
			local castAt = immediate and snapshot.now or math.max(scheduledCastAt, box.deadline)
			local feasible = airborne and (immediate
				and snapshot.now + preparation <= lastEndsAt + cfg.landingMaxLate
				or snapshot.now <= latest and snapshot.now + preparation <= castAt + cfg.landingOrderTolerance)
			if feasible then
				if immediate then
					logChanged("tornado_cata_immediate_" .. tostring(box.firstIndex or timingAnchor.index), "TORNADO CATA TIMING",
						("targets=%d required=%d mode=IMMEDIATE remaining=%.2f impactDelay=%.3f safety=%.3f natural_in=%.2f prep=%.3f -> CAST ASAP"):format(
							#box.indices, minHeroes, math.max(0, lastEndsAt - snapshot.now), cataImpactDelay or 0, landingOffset or 0,
							naturalCastAt - snapshot.now, preparation or 0))
				end
				return {
					records = box.records, indices = box.indices, count = #box.indices, requiredCount = minHeroes,
					anchorIndex = timingAnchor.index, lastEndsAt = lastEndsAt, lastHitAt = box.lastHitAt,
					castAt = castAt, naturalCastAt = naturalCastAt, latest = latest, impactDelay = cataImpactDelay,
					landingOffset = landingOffset, commandDelay = cataCommandDelay, timingSource = cataTimingSource, tornadoImmediate = immediate,
					preparation = preparation, fogCount = box.fogCount or 0, anchorMode = "last_tornado_hit",
					preparationSource = preparationSource, groupMode = "tornado_box_sliding",
					collectStartAt = box.startAt, collectDeadline = box.deadline, collectWindow = box.collectWindow,
					containerFirstIndex = box.firstIndex or box.firstRecord.index, containerLastIndex = box.lastRecordIndex or timingAnchor.index,
					containerOpen = snapshot.now <= box.deadline + cfg.landingCataclysmCollectTolerance,
					queueReady = immediate or snapshot.now + preparation + cfg.landingCataclysmQueueLead >= castAt,
				}, "ok"
			end
			end
		end
	end

	-- Non-Tornado landings keep the historical narrow temporal grouping. Same-Tornado expansion is
	-- intentionally NOT used here anymore; Tornado membership is owned exclusively by the sliding confirmation containers above.
	local other = {}
	for _, record in ipairs(records) do if record.name ~= "modifier_invoker_tornado" then other[#other + 1] = record end end
	table.sort(other, function(left, right) return left.endsAt < right.endsAt end)
	for anchorPos = #other, minHeroes, -1 do
		local anchor = other[anchorPos]
		local group, indices, fogCount = {}, {}, 0
		local overlapsCommitted = required == nil
		for j = anchorPos, 1, -1 do
			local record = other[j]
			if anchor.endsAt - record.endsAt > cfg.landingCataclysmGroupWindow then break end
			group[#group + 1] = record
			indices[#indices + 1] = record.index
			if record.tornadoHitInFog then fogCount = fogCount + 1 end
			if required and required[record.index] then overlapsCommitted = true end
		end
		if #group >= minHeroes and overlapsCommitted then
			local timingAnchor = anchor
			local impactDelay, commandDelay, timingSource = helpers.landingOrderImpactDelay(snapshot, "cataclysm")
			local landingOffset = timingAnchor.kind == "teleport" and cfg.teleportLandingImpactOffset or cfg.landingImpactOffset
			local policyPass, policyEval = helpers.cataclysmGroupPolicyPass(group, snapshot, settings, timingAnchor.endsAt + landingOffset)
			logChanged("cata_policy_time_" .. tostring(timingAnchor.index), "CATA POLICY",
				("group=time mode=%d targets=%d pass=%s target=%s hp=%.0f damage=%.0f threshold=%.0f"):format(
					settings.cataclysmUseMode or 0, #group, tostring(policyPass),
					tostring(policyEval and policyEval.targetIndex or "any"), policyEval and policyEval.projectedHealth or 0,
					policyEval and policyEval.damage or 0, policyEval and policyEval.threshold or 0))
			if policyPass then
			local castAt = timingAnchor.endsAt + landingOffset - impactDelay
			local latest = timingAnchor.endsAt + landingOffset + cfg.landingMaxLate - impactDelay
			if snapshot.now <= latest and snapshot.now + preparation <= castAt + cfg.landingOrderTolerance then
				return {records = group, indices = indices, count = #group, requiredCount = minHeroes, anchorIndex = timingAnchor.index,
					lastEndsAt = timingAnchor.endsAt, lastHitAt = timingAnchor.createdAt or -math.huge, castAt = castAt, latest = latest,
					impactDelay = impactDelay, landingOffset = landingOffset, commandDelay = commandDelay, timingSource = timingSource,
					preparation = preparation, fogCount = fogCount, anchorMode = "last_landing", preparationSource = preparationSource,
					groupMode = "time_window", queueReady = snapshot.now + preparation + cfg.landingCataclysmQueueLead >= castAt}, "ok"
			end
			end
		end
	end
	return nil, "latest_group_cannot_make_cast_time"
end

function helpers.selectLandingCataclysm(snapshot, settings)
	local window = helpers.landingCataclysmWindow(snapshot, settings, nil)
	return window
end

function helpers.refreshLandingCataclysm(pending, snapshot, settings)
	if not pending or pending.kind ~= "landing_cataclysm" or not pending.landingGroupIndices then return false end
	local window, reason = helpers.landingCataclysmWindow(snapshot, settings, pending.landingGroupIndices)
	if not window then
		logChanged("landing_cata_release", "LANDING CATA",
			("release reason=%s -> fallback Landing Sun"):format(tostring(reason or "unknown")))
		return false
	end
	pending.targetIndex = window.anchorIndex
	pending.landingGroupIndices = window.indices
	pending.landingCount = window.count
	pending.landingLastEndsAt = window.lastEndsAt
	pending.landingCastAt = window.castAt
	pending.landingNaturalCastAt = window.naturalCastAt or window.castAt
	pending.landingTornadoImmediate = window.tornadoImmediate == true
	pending.landingLatest = window.latest
	pending.landingPreparation = window.preparation
	pending.landingPreparationSource = window.preparationSource
	pending.landingGroupMode = window.groupMode
	pending.landingFogCount = window.fogCount or 0
	pending.landingCollectStartAt = window.collectStartAt
	pending.landingCollectDeadline = window.collectDeadline
	pending.landingCollectWindow = window.collectWindow
	pending.landingContainerFirstIndex = window.containerFirstIndex
	pending.landingContainerLastIndex = window.containerLastIndex
	pending.expiresAt = window.latest + 0.02
	logChanged("landing_cata_pending", "LANDING CATA",
		("targets=%d required=%d fog=%d group=%s anchor=%s mode=%s box=%.2f last_in=%.2f cast_in=%.2f prep=%.3f prepSource=%s impactDelay=%.3f command=%.3f timing=%s"):format(
			window.count, window.requiredCount or settings.cataclysmMinHeroes or 2, window.fogCount or 0, tostring(window.groupMode or "time_window"), tostring(window.anchorMode or "last_landing"), window.tornadoImmediate and "tornado_immediate" or "scheduled", window.collectWindow or 0, window.lastEndsAt - snapshot.now, window.castAt - snapshot.now, window.preparation,
			tostring(window.preparationSource or "?"), window.impactDelay, window.commandDelay, window.timingSource))
	return true
end

function helpers.queueLandingCataclysm(window, snapshot, settings)
	if not window or not window.queueReady then return false end
	if not queueAutoAction("cataclysm", {index = window.anchorIndex}, "landing_cataclysm", snapshot) then return false end
	state.autoPending.landingGroupIndices = window.indices
	state.autoPending.landingCount = window.count
	state.autoPending.landingLastEndsAt = window.lastEndsAt
	state.autoPending.landingCastAt = window.castAt
	state.autoPending.landingNaturalCastAt = window.naturalCastAt or window.castAt
	state.autoPending.landingTornadoImmediate = window.tornadoImmediate == true
	state.autoPending.landingLatest = window.latest
	state.autoPending.landingPreparation = window.preparation
	state.autoPending.landingPreparationSource = window.preparationSource
	state.autoPending.landingGroupMode = window.groupMode
	state.autoPending.landingFogCount = window.fogCount or 0
	state.autoPending.landingCollectStartAt = window.collectStartAt
	state.autoPending.landingCollectDeadline = window.collectDeadline
	state.autoPending.landingCollectWindow = window.collectWindow
	state.autoPending.landingContainerFirstIndex = window.containerFirstIndex
	state.autoPending.landingContainerLastIndex = window.containerLastIndex
	state.autoPending.expiresAt = window.latest + 0.02
	state.nextAutoActionAt = snapshot.now
	logDebug("LANDING CATA",
		("queue targets=%d required=%d fog=%d group=%s anchor=%s mode=%s box=%.2f last_in=%.2f cast_in=%.2f prep=%.3f prepSource=%s impactDelay=%.3f command=%.3f timing=%s selfCharge=%s"):format(
			window.count, window.requiredCount or settings.cataclysmMinHeroes or 2, window.fogCount or 0, tostring(window.groupMode or "time_window"), tostring(window.anchorMode or "last_landing"), window.tornadoImmediate and "tornado_immediate" or "scheduled", window.collectWindow or 0, window.lastEndsAt - snapshot.now, window.castAt - snapshot.now, window.preparation or 0,
			tostring(window.preparationSource or "?"), window.impactDelay, window.commandDelay, window.timingSource,
			tostring(settings.cataclysmSelfCharge == true)))
	return true
end

-- v43: a queued single Landing Sun must not hide later confirmed victims of the SAME travelling
-- Tornado. Before the Sun order is issued, a newly completed Cataclysm group can promote the pending
-- action in-place. This preserves an in-progress EEE/Invoke sequence (Cataclysm uses the same physical
-- Sun Strike recipe) while letting 3 pre-landing fog Tornado lifts become 3 Cataclysm targets.
function helpers.promoteLandingSunToCataclysm(snapshot, settings)
	local pending = state.autoPending
	if not pending or pending.kind ~= "landing_sun" or pending.cast then return false end
	local window = helpers.selectLandingCataclysm(snapshot, settings)
	if not window then return false end
	pending.actionId = "cataclysm"
	pending.kind = "landing_cataclysm"
	pending.targetIndex = window.anchorIndex
	pending.position = nil
	pending.sunRequest = nil
	pending.landing = nil
	pending.landingSunLock = nil
	helpers.releaseLandingSunLock("promoted to Cataclysm")
	pending.attempts = 0
	pending.landingGroupIndices = window.indices
	pending.landingCount = window.count
	pending.landingLastEndsAt = window.lastEndsAt
	pending.landingCastAt = window.castAt
	pending.landingNaturalCastAt = window.naturalCastAt or window.castAt
	pending.landingTornadoImmediate = window.tornadoImmediate == true
	pending.landingLatest = window.latest
	pending.landingPreparation = window.preparation
	pending.landingPreparationSource = window.preparationSource
	pending.landingGroupMode = window.groupMode
	pending.landingFogCount = window.fogCount or 0
	pending.landingCollectStartAt = window.collectStartAt
	pending.landingCollectDeadline = window.collectDeadline
	pending.landingCollectWindow = window.collectWindow
	pending.landingContainerFirstIndex = window.containerFirstIndex
	pending.landingContainerLastIndex = window.containerLastIndex
	pending.expiresAt = window.latest + 0.02
	state.nextAutoActionAt = snapshot.now
	helpers.sunPriority.releaseHpLatch("landing Sun promoted to Cataclysm")
	helpers.sunPriority.claim("landing_cataclysm", snapshot.now + helpers.sunPriority.leaseSeconds)
	logDebug("LANDING CATA", ("promote from=landing_sun targets=%d required=%d fog=%d group=%s anchor=%s box=%.2f last_in=%.2f cast_in=%.2f"):format(
		window.count, window.requiredCount or settings.cataclysmMinHeroes or 2, window.fogCount or 0,
		tostring(window.groupMode or "tornado_box"), tostring(window.anchorMode or "last_tornado_hit"), window.collectWindow or 0, window.lastEndsAt - snapshot.now, window.castAt - snapshot.now))
	return true
end

function helpers.sunPriority.committedSunValid(pending, target, snapshot, settings)
	local fogRoute = settings.fogRouteSun and target and target.fogProjected and (target.fogAge or math.huge) <= cfg.fogRouteTTL
	if not target or not target.alive or target.invulnerable or target.outOfGame
		or not helpers.hasAutoSunMana(snapshot, settings)
	then
		return false
	end
	-- Portrait X owns ordinary Auto SS; controlled shots additionally require impact-time control.
	local controlMode = pending.sunControlled == true
	if not controlMode and helpers.movingSunBlocked(target, settings) then return false end
	if helpers.normalAutoSunTeleportBlocked(target, snapshot) then
		logDebug("TP PRIORITY", ("cancel committed NORMAL AUTO SUN target=%d -> TP destination owns target"):format(target.index))
		return false
	end
	if not fogRoute and (not target.visible or target.dormant) then return false end
	local transitionSafe, transitionReason = helpers.sunPriority.motionTransitionSafe(target, snapshot, settings)
	if not transitionSafe then
		logChanged("sun_transition_" .. tostring(target.index), "SUN TRANSITION", transitionReason)
		return false
	end
	if not controlMode and (pending.sunMode == "idle" or pending.sunMode == "idle_stationary")
		and not (helpers.sunPriority.nativeIdleReady(target, settings)
			or helpers.sunPriority.stationaryEvidence(target, snapshot, settings).passed) then
		return false
	end

	-- The initial HP/lethal/walk/idle checks are NOT repeated after the target is locked.
	-- Recheck remaining control during preparation and at the cast boundary.
	if controlMode then
		local impactAt = snapshot.now + helpers.sunImpactDelay(snapshot, "sun_strike")
		local controlNow, controlEndsAt, visibleControl = helpers.sunPriority.controlValidForOrder(target, snapshot, settings)
		local carryValid = controlNow == true and visibleControl
		if carryValid then
			local mechanics = resolveMechanics("sun_strike", snapshot, 0)
			local delay = impactAt - snapshot.now
			local split = sunSplitCount(snapshot, target.position, math.max(cfg.sunRadius, mechanics.radius), target.index, delay)
			local hp = math.min(target.maxHealth, target.health + math.max(0, target.healthRegen) * delay)
			local hpPercent = target.maxHealth > 0 and target.health / target.maxHealth * 100 or 100
			carryValid = helpers.autoUseModePass(settings.controlUseMode or 1, hp, target.maxHealth,
				mechanics.expectedDamage / math.max(1, split), hpPercent, settings.controlHpPercent or 100) == true
		end
		logDebug("SUN CONTROL GUARD", ((carryValid and "carry" or "reject") .. " target=%d mode=%s visible=%s fog=%s controlNow=%s controlIn=%.2f impactIn=%.2f policy=active_at_lock"):format(
			target.index, tostring(pending.sunMode), tostring(visibleControl), tostring(target.fogProjected == true),
			tostring(controlNow), controlEndsAt - snapshot.now, impactAt - snapshot.now))
		return carryValid
	end
	if fogRoute then
		return pending.sunFogRoute == true and (target.fogAge or math.huge) <= cfg.fogRouteTTL
			and target.moving and length2D(target.velocity) > 40
	end
	return true
end


-- Common post-selection Sun Strike resolver. Every queued Sun kind passes here on relevance,
-- before preparation and again immediately before the cast. Mode-specific entry conditions are
-- kept as policies, but execution and safety are centralized.
function helpers.controlledSunEscapeDistance(target, now, impactDelay)
	local releaseAt = math.max(target.disabledUntil or now, target.controlEndsAt or now)
	local freeTime = math.max(0, now + math.max(0, impactDelay) - math.max(now, releaseAt))
	return math.max(0, target.moveSpeed or 0) * freeTime
end

function helpers.sunEngine.refresh(pending, target, snapshot, settings, stage, forcedPosition)
	local request = pending and pending.sunRequest
	if not request then return false, false, nil, nil, "no_request" end
	local kind = request.kind
	if kind ~= "quick_sun" then
		local flightReason = helpers.sunPriority.flightBlockReason(target, stage == "cast")
		if flightReason then return false, false, nil, nil, flightReason end
	end
	local relevant, allowed, position, castAt, reason = true, true, nil, nil, "ok"

	if kind == "sun_strike" then
		-- v71: at the physical cast boundary refresh critical target state BEFORE the safety gate.
		-- v70 checked TP/invulnerability from the older snapshot and refreshed only motion afterwards.
		if stage == "cast" and target then helpers.sunPriority.refreshCastMotion(target, snapshot) end
		relevant = helpers.sunPriority.committedSunValid(pending, target, snapshot, settings)
		if relevant and target then
			if stage == "cast" then
				-- Final CastPosition must be computed from THIS tick's refreshed speed/direction, never from
				-- a terrain aim cached before the final NPC.GetMoveSpeed()/motion sample.
				if state.sunTerrainCache then state.sunTerrainCache[target.index] = nil end
				if pending.sunControlled == true then
					local impactAt = snapshot.now + helpers.sunImpactDelay(snapshot, "sun_strike")
					local controlNow, controlEndsAt, visibleControl = helpers.sunPriority.controlValidForOrder(target, snapshot, settings)
					local carryValid = controlNow == true and visibleControl
					logDebug("SUN CONTROL GUARD", ("cast target=%d mode=%s visible=%s fog=%s controlNow=%s controlIn=%.2f impactIn=%.2f pass=%s policy=active_at_lock"):format(
						target.index, tostring(pending.sunMode), tostring(visibleControl), tostring(target.fogProjected == true), tostring(controlNow),
						controlEndsAt - snapshot.now, impactAt - snapshot.now, tostring(carryValid)))
				end
				-- v65: the route lock proves that the target was predictable enough to prepare Sun,
				-- but it must not freeze the old heading.  Final aim follows the current trajectory.
				target.sunLockedAimDirection = nil
			else
				if pending.sunAimDirection then target.sunLockedAimDirection = copyPoint(pending.sunAimDirection) end
			end
			local controlMode = pending.sunControlled == true
			if controlMode and not forcedPosition then
				-- v85 user rule: a hard-controlled target is aimed at its CURRENT CENTER. Do not let the
				-- motion track retain pre-stun velocity and lead this dedicated control shot forward.
				position = copyPoint(target.position)
				local mechanics = resolveMechanics("sun_strike", snapshot, 0)
				local escape = helpers.controlledSunEscapeDistance(target, snapshot.now,
					helpers.sunImpactDelay(snapshot, "sun_strike"))
				if escape > math.max(1, mechanics.radius) * cfg.sunControlledEscapeRadiusFactor then
					allowed, reason = false, "control_expires_before_safe_impact"
				end
				target.sunAimMeta = {source = "controlled_center", terrainStatus = "controlled", routeCount = 1,
					covered = 1, horizon = 0, reachHorizon = 0, frontLead = 0, frontReserve = cfg.sunRadius, timingReserve = 0}
				logChanged("sun_control_aim_" .. tostring(target.index), "SUN CONTROL AIM",
					("target=%d stage=%s center=%.0f,%.0f mode=%s"):format(
						target.index, tostring(stage), position.x, position.y, tostring(pending.sunMode)))
			else
				position = forcedPosition or predictIntercept(snapshot, "sun_strike", target, snapshot.now, target.motionConfidence).position
			end
			if stage == "cast" and pending.sunMode == "runner" and not forcedPosition then
				local currentSpeed = helpers.sunPriority.castMotionSpeed(target)
				local stationary = helpers.sunPriority.stationaryEvidence(target, snapshot, settings)
				if stationary.passed and stationary.position then
					position = copyPoint(stationary.position)
				elseif target.moving and currentSpeed > 40 then
					local routeGate = helpers.sunPriority.runnerRouteGate(target, snapshot, settings)
					if not routeGate or not routeGate.passed then
						allowed = false
						reason = "cast_route_" .. tostring(routeGate and routeGate.reason or "no_history")
					end
				else
					position = copyPoint(target.position)
				end
			end
		end
	elseif kind == "quick_sun" then
		relevant = target ~= nil and target.alive and not target.invulnerable and not target.outOfGame
			and ((target.visible and not target.dormant)
				or (target.fogProjected and (target.fogAge or math.huge) <= cfg.fogRouteTTL))
		if relevant and target then
			if stage == "cast" then
				helpers.sunPriority.refreshCastMotion(target, snapshot)
				if state.sunTerrainCache then state.sunTerrainCache[target.index] = nil end
				target.sunLockedAimDirection = nil
			elseif pending.sunAimDirection then
				target.sunLockedAimDirection = copyPoint(pending.sunAimDirection)
			end
			position = forcedPosition or predictIntercept(snapshot, "sun_strike", target, snapshot.now, target.motionConfidence).position
		end
	elseif kind == "landing_sun" then
		local window
		if pending.landingSunLock then
			window = helpers.landingSunLockedWindow(snapshot, settings, pending.landingSunLock)
		else
			window = pending.landing and helpers.landingSunWindow(pending.landing, snapshot, settings) or nil
		end
		relevant = window ~= nil
		if window then
			position, castAt = copyPoint(window.position), window.castAt
			pending.expiresAt = window.latest + 0.01
		end
	elseif kind == "roshan_sun" then
		relevant = snapshot.roshan and snapshot.roshan.index == pending.targetIndex
			and helpers.isRoshanSunTarget(snapshot, settings) or false
		if relevant then position = copyPoint(snapshot.roshan.position) end
	elseif kind == "tormentor_sun" then
		local objective = helpers.selectTormentorSunTarget(snapshot, settings, pending.targetIndex)
		relevant = objective ~= nil
		if objective then position = copyPoint(objective.position) end
	else
		relevant, reason = false, "unknown_sun_kind"
	end

	if not relevant then
		allowed = false
		reason = reason == "ok" and "mode_invalid" or reason
	elseif kind == "sun_strike" and pending.sunStrictLethal and pending.sunSplitReferenceHp and target
		and (stage == "prepare" or stage == "cast")
	then
		local liveImpactHp = math.min(target.maxHealth, target.health + math.max(0, target.healthRegen) * helpers.sunImpactDelay(snapshot, "sun_strike"))
		local requiredHp = math.max(pending.sunSplitReferenceHp, liveImpactHp)
		local splitSafe, splitCount, splitDamage, splitPosition = helpers.sunPriority.splitSafety(
			target, snapshot, requiredHp, forcedPosition or position)
		position = splitPosition or position
		-- v69: safety gates are monotonic. A later split-safe result must never revive a cast
		-- already rejected by the final route/zigzag gate.
		if not splitSafe then
			allowed = false
			reason = "split_hold"
		elseif allowed then
			reason = "split_safe"
		end
		logChanged("sun_split_" .. stage .. "_" .. tostring(target.index), "SUN SPLIT SAFE",
			("target=%d stage=%s split=%d damage=%.0f hpLock=%.0f pass=%s%s"):format(
				target.index, stage, splitCount, splitDamage, requiredHp,
				tostring(splitSafe), splitSafe and "" or " -> HOLD"))
	end

	pending.sunResolvedPosition = position and copyPoint(position) or nil
	pending.sunCastAt = castAt
	pending.sunGuardAllowed = allowed
	pending.sunGuardReason = reason
	local keyTarget = pending.targetIndex or -1
	logChanged(("sun_pipe_%s_%s_%s"):format(tostring(kind), tostring(stage), tostring(keyTarget)), "SUN PIPE",
		("kind=%s stage=%s relevant=%s allowed=%s source=%s target=%s%s"):format(
			tostring(kind), tostring(stage), tostring(relevant), tostring(allowed), tostring(request.positionMode),
			tostring(pending.targetIndex or "none"),
			castAt and (" castIn=%.2f"):format(castAt - snapshot.now) or ""))
	return relevant, allowed, position, castAt, reason
end

local function autoPendingRelevant(pending, target, snapshot, settings)
	if pending.sunRequest then
		local relevant = helpers.sunEngine.refresh(pending, target, snapshot, settings, "relevant")
		return relevant == true
	end
	if pending.kind == "landing_cataclysm" then
		return helpers.refreshLandingCataclysm(pending, snapshot, settings)
	end
	if pending.kind == "cataclysm_refresher" then return helpers.canAutoRefresh(snapshot, settings, pending) end
	if pending.kind == "cataclysm_repeat" and pending.cataclysmChainSource == "landing_group" then
		return settings.cataclysm and snapshot.hero.upgrades.scepterChoice == "exort"
			and helpers.hasAutoSunMana(snapshot, settings, "cataclysm")
			and helpers.cataclysmConfirmedGroupValid(pending, settings)
	end
	if pending.kind == "cataclysm" or pending.kind == "cataclysm_repeat" then
		return settings.cataclysm and snapshot.hero.upgrades.scepterChoice == "exort"
			and helpers.hasAutoSunMana(snapshot, settings, "cataclysm")
			and selectCataclysmTarget(snapshot, settings) ~= nil
	end
	if not target or not target.alive or not target.visible or target.dormant or target.invulnerable or target.outOfGame then return false end
	return isAutoSunTarget(target, snapshot, settings)
end

-- v50: Refresher after a Landing Cataclysm must preserve the already-confirmed landing group.
-- Tornado victims may be dormant/in fog by the time the Refresher chain starts, so visibility/control
-- are not re-used as membership gates. Only an explicitly dead entity removes one confirmation.
function helpers.cataclysmConfirmedGroupCount(pending)
	local indices = pending and (pending.cataclysmChainIndices or pending.landingGroupIndices) or nil
	if not indices then return 0 end
	local seen, count = {}, 0
	for _, index in ipairs(indices) do
		if not seen[index] then
			seen[index] = true
			local unit = Entity.Get(index)
			if not unit or Entity.IsAlive(unit) then count = count + 1 end
		end
	end
	return count
end

function helpers.cataclysmConfirmedGroupValid(pending, settings)
	if not pending or pending.cataclysmChainSource ~= "landing_group" then return false end
	local groupMode = pending.cataclysmChainGroupMode
	if groupMode == "tornado_box_sliding" and not settings.cataclysmTornado then return false end
	return helpers.cataclysmConfirmedGroupCount(pending) >= clamp(settings.cataclysmMinHeroes or 2, 2, 5)
end

function helpers.copyCataclysmChainContext(source, target)
	if not source or not target then return target end
	local sourceIsLanding = source.kind == "landing_cataclysm" or source.cataclysmChainSource == "landing_group"
	if not sourceIsLanding then return target end
	local indices = source.cataclysmChainIndices or source.landingGroupIndices or {}
	target.cataclysmChainSource = "landing_group"
	target.cataclysmChainIndices = arrayCopy(indices)
	target.cataclysmChainCount = source.cataclysmChainCount or source.landingCount or #indices
	target.cataclysmChainFogCount = source.cataclysmChainFogCount or source.landingFogCount or 0
	target.cataclysmChainGroupMode = source.cataclysmChainGroupMode or source.landingGroupMode or "time_window"
	target.cataclysmChainAnchorIndex = source.cataclysmChainAnchorIndex or source.targetIndex
	return target
end

function helpers.canAutoRefresh(snapshot, settings, pending)
	local refresher = snapshot.actions.item_refresher
	local sun = snapshot.actions.cataclysm
	if not settings.cataclysm or not settings.cataclysmRefresher
		or snapshot.hero.upgrades.scepterChoice ~= "exort"
		or not refresher.exists or not refresher.activated or not refresher.canCast or refresher.cooldown > 0.05
		or not sun.exists or sun.cooldown <= 0.05 or not sun.invoked
		or snapshot.hero.mana - refresher.manaCost - sun.manaCost < snapshot.hero.maxMana * (settings.cataclysmMinMana or 0) / 100
	then
		return false
	end

	-- Landing/Tornado Cataclysm: membership was already confirmed before the first Cata order.
	-- Preserve that group through Refresher instead of throwing fog victims away at a fresh visible/control scan.
	if pending and (pending.kind == "landing_cataclysm" or pending.cataclysmChainSource == "landing_group") then
		local probe = {kind = pending.kind}
		helpers.copyCataclysmChainContext(pending, probe)
		local count = helpers.cataclysmConfirmedGroupCount(probe)
		local required = clamp(settings.cataclysmMinHeroes or 2, 2, 5)
		local tornadoMode = probe.cataclysmChainGroupMode == "tornado_box_sliding"
		local pass = count >= required and (not tornadoMode or settings.cataclysmTornado)
		logChanged("cata_refresh_group_" .. tostring(probe.cataclysmChainAnchorIndex or pending.targetIndex or -1), "CATA REFRESH",
			("source=%s targets=%d required=%d fog=%d tornado=%s pass=%s"):format(
				tostring(probe.cataclysmChainGroupMode or "landing_group"), count, required, probe.cataclysmChainFogCount or 0,
				tostring(settings.cataclysmTornado == true), tostring(pass)))
		return pass
	end

	-- Ordinary Auto Cataclysm keeps its original live-control recheck.
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

function helpers.advanceAutoCataclysm(pending, snapshot, settings)
	local id, kind
	local firstCataclysm = pending.kind == "cataclysm" or pending.kind == "landing_cataclysm"
	if firstCataclysm and helpers.canAutoRefresh(snapshot, settings, pending) then
		id, kind = "item_refresher", "cataclysm_refresher"
	elseif pending.kind == "cataclysm_refresher" and settings.cataclysm and settings.cataclysmRefresher
		and helpers.autoSpellReadyOrChargeable("cataclysm", snapshot, settings)
	then
		id, kind = "cataclysm", "cataclysm_repeat"
	end
	if not id then return false end
	local nextPending = {actionId = id, kind = kind, targetIndex = pending.targetIndex,
		expiresAt = snapshot.now + 2.2, attempts = 0}
	helpers.copyCataclysmChainContext(pending, nextPending)
	state.autoPending = nextPending
	state.nextAutoActionAt = snapshot.now
	if nextPending.cataclysmChainSource == "landing_group" then
		logDebug("CATA REFRESH", ("queue kind=%s source=%s targets=%d fog=%d anchor=%s"):format(
			kind, tostring(nextPending.cataclysmChainGroupMode or "landing_group"),
			helpers.cataclysmConfirmedGroupCount(nextPending), nextPending.cataclysmChainFogCount or 0,
			tostring(nextPending.cataclysmChainAnchorIndex or nextPending.targetIndex or "?")))
	end
	return true
end

local function processAutoPending(snapshot, settings)
	local pending = state.autoPending
	if not pending then
		helpers.sunPriority.release("no pending action")
		return false
	end
	if helpers.sunPriority.pending(pending) then helpers.sunPriority.renew(pending.kind) end
	local id = pending.actionId
	if pending.cast then
		if id == "sun_strike" then helpers.updateSunTimingProbe(snapshot, pending) end
		if castConfirmed(pending.cast, snapshot) then
			if id == "sun_strike" and pending.cast.issuedAt then
				local probe = helpers.updateSunTimingProbe(snapshot, pending)
				state.sunTimingProbeSamples = (state.sunTimingProbeSamples or 0) + 1
				logDebug("SUN TIMING", ("order_to_cd=%.3f phase=%s castStart=%s cdObsLag=%.3f impactParticle=%.3f correction=OFF n=%d"):format(
					math.max(0, snapshot.now - pending.cast.issuedAt),
					probe and probe.phaseSeenAt and ("%.3f"):format(probe.phaseSeenAt - probe.issuedAt) or "none",
					probe and probe.castStartAt and ("%.3f"):format(probe.castStartAt - probe.issuedAt) or "none",
					state.sunCooldownSeenDelay or 0, state.sunImpactParticleDelay or 0, state.sunTimingProbeSamples))
			end
			if pending.kind == "landing_sun" then
				pending.landing.fired = true
				local live = state.landings and state.landings[pending.landing.index] or nil
				if live then live.fired = true end
				helpers.releaseLandingSunLock("cast confirmed")
			end
			if pending.kind == "landing_cataclysm" then
				for _, index in ipairs(pending.landingGroupIndices or {}) do
					local record = state.landings and state.landings[index] or nil
					if record then record.fired = true end
				end
			end
			if helpers.advanceAutoCataclysm(pending, snapshot, settings) then
				helpers.sunPriority.renew("cataclysm chain")
				return true
			end
			state.autoPending = nil
			helpers.sunPriority.release("cast confirmed")
			state.nextAutoActionAt = snapshot.now + 0.18
			setStatus("preparing", definitions[id].short .. " confirmed.")
			return true
		end
		if snapshot.now < pending.cast.deadline then return true end
		if id == "sun_strike" then
			local probe = helpers.updateSunTimingProbe(snapshot, pending)
			local started = probe and (probe.phaseSeenAt ~= nil or probe.castStartAt ~= nil)
			if started and snapshot.now < pending.cast.issuedAt + 1.25 then
				-- A late cooldown observation must not cause a second Sun order on a newly changed
				-- target state. Once the cast actually started, wait for the authoritative cooldown.
				pending.cast.deadline = pending.cast.issuedAt + 1.25
				setStatus("confirming", "Sun cast started; waiting for cooldown confirmation.")
				return true
			end
			if started then
				state.autoPending = nil
				helpers.sunPriority.release("Sun started but cooldown confirmation was unavailable")
				state.nextAutoActionAt = snapshot.now + 0.18
				setStatus("waiting", "Sun cast start was observed; duplicate retry suppressed.")
				return true
			end
		end
		pending.cast = nil
		local retryLimit = helpers.sunPriority.pending(pending) and helpers.sunPriority.maxCastAttempts or 2
		if pending.attempts < retryLimit then
			if helpers.sunPriority.pending(pending) then helpers.sunPriority.renew("retry cast") end
			state.nextAutoActionAt = snapshot.now + (helpers.sunPriority.pending(pending) and 0.02 or 0.04)
			setStatus("waiting", definitions[id].short .. " was not confirmed; retrying.")
			return true
		end
		state.autoPending = nil
		helpers.sunPriority.release("cast confirmation failed")
		state.nextAutoActionAt = snapshot.now + 0.18
		setStatus("waiting", "Skipped " .. definitions[id].short .. ": cast was not confirmed.")
		return true
	end
	local target = findEnemy(snapshot, pending.targetIndex)
	if id == "sun_strike" and pending.kind ~= "quick_sun" then
		local flightReason = helpers.sunPriority.flightBlockReason(target, true)
		if flightReason then
			state.autoPending = nil
			if isInvoking(id) then state.invokeSequence = nil end
			state.orbSequence = nil
			helpers.sunPriority.release("target special movement")
			logChanged("sun_flight_cancel", "SUN FLIGHT BLOCK", flightReason .. " -> cancelled SS preparation")
			return false
		end
	end
	if snapshot.now >= pending.expiresAt or not autoPendingRelevant(pending, target, snapshot, settings) then
		state.autoPending = nil
		if isInvoking(id) then state.invokeSequence = nil end
		helpers.sunPriority.release("pending action no longer relevant")
		return false
	end
	local action = snapshot.actions[id]
	if not action or not action.exists or action.cooldown > 0.05 then
		setStatus("waiting", definitions[id].short .. " is not ready.")
		return true
	end
	-- v28 common PREPARE gate for every real Sun Strike mode. The mode-specific selector only decides
	-- why a shot is allowed; this shared engine decides whether preparation may continue right now.
	if pending.sunRequest then
		local sunRelevant, sunAllowed, _, _, sunReason = helpers.sunEngine.refresh(
			pending, target, snapshot, settings, "prepare")
		if not sunRelevant then
			state.autoPending = nil
			if isInvoking(id) then state.invokeSequence = nil end
			helpers.sunPriority.release("Sun request lost during prepare")
			return false
		end
		if not sunAllowed then
			if isInvoking(id) then state.invokeSequence = nil end
			pending.expiresAt = math.max(pending.expiresAt, snapshot.now + 0.75)
			setStatus("waiting", sunReason == "split_hold"
				and "Sun Strike: split damage is no longer lethal; holding target."
				or "Sun Strike: common safety gate is holding preparation.")
			return true
		end
	end
	local needsInvoke = (id == "sun_strike" or id == "cataclysm") and not action.invoked
	if needsInvoke and (id == "sun_strike" or id == "cataclysm") and not helpers.autoSelfChargeEnabled(id, settings) then
		if isInvoking(id) then state.invokeSequence = nil end
		state.autoPending = nil
		helpers.sunPriority.release(id .. " self-charge disabled")
		setStatus("waiting", definitions[id].name .. " is not in D/F; self-charge is disabled.")
		logDebug("AUTO CHARGE", ("id=%s enabled=false invoked=false -> D/F ONLY, pending released"):format(id))
		return false
	end
	if needsInvoke then
		if isInvoking(id) then
			pending.expiresAt = math.max(pending.expiresAt, snapshot.now + 1.0)
			updateInvokeSequence(snapshot)
		elseif snapshot.invoke.ready and queueInvoke(id, false) then
			pending.expiresAt = math.max(pending.expiresAt, snapshot.now + 1.0)
			if id == "sun_strike" or id == "cataclysm" then
				logDebug("AUTO CHARGE", ("id=%s enabled=true -> EEE/Invoke"):format(id))
			end
			helpers.sunPriority.renew("fast EEE Invoke")
			-- Same immediate preparation path as combo: first Exort is issued this tick,
			-- the remaining EEE -> Invoke steps follow at cfg.invokeOrbInterval.
			logDebug("SUN PREP", ("target=%s immediate EEE->Invoke"):format(tostring(pending.targetIndex or "?")))
			updateInvokeSequence(snapshot)
		elseif pending.sunRequest then
			local invokeRemaining = snapshot.invoke and math.max(0, snapshot.invoke.cooldown or 0) or math.huge
			-- All Sun modes use this same Invoke executor. Normal lethal Auto Sun intentionally keeps
			-- its strict <=0.35 s reservation; manual/landing/objective requests may wait only
			-- inside their already-bounded request lifetime.
			if pending.kind == "sun_strike" then
				if invokeRemaining <= 0.35 then
					pending.expiresAt = math.max(pending.expiresAt, snapshot.now + invokeRemaining + 1.0)
					helpers.sunPriority.renew("short Invoke reservation")
					setStatus("waiting", ("Sun Strike: Invoke ready in %.2fs."):format(invokeRemaining))
					return true
				end
				state.autoPending = nil
				helpers.sunPriority.release("Invoke cooldown outside short Sun window")
				return false
			end
			setStatus("waiting", ("Sun Strike: shared executor waiting for Invoke (%.2fs)."):format(
				invokeRemaining == math.huge and -1 or invokeRemaining))
			return true
		end
		setStatus("preparing", "Automatic " .. pending.kind .. ": preparing " .. definitions[id].name .. ".")
		return true
	end
	if isInvoking(id) then
		pending.expiresAt = math.max(pending.expiresAt, snapshot.now + 1.0)
		updateInvokeSequence(snapshot)
		return true
	end
	-- v53: if a single Tornado Landing Sun was already prepared, keep the recipe ready but do not
	-- spend the shared Sun/Cataclysm cooldown while the same-Tornado Aghanim box is still collecting.
	-- A later victim inside the box can then promote this pending action to Landing Cataclysm.
	if pending.kind == "landing_sun" then
		local box, required, left = helpers.pendingLandingSunCataclysmHold(pending, snapshot, settings)
		if box then
			pending.expiresAt = math.max(pending.expiresAt, (box.deadline or snapshot.now) + 0.12)
			setStatus("waiting", ("Cataclysm first: Tornado box %d/%d; %.2fs left."):format(
				#(box.indices or {}), required or 2, left or 0))
			return true
		end
	end
	if pending.kind == "landing_cataclysm" then
		if not helpers.refreshLandingCataclysm(pending, snapshot, settings) then
			state.autoPending = nil
			helpers.sunPriority.release("landing Cataclysm group lost")
			return false
		end
		if snapshot.now < pending.landingCastAt then
			setStatus("waiting", ("Cataclysm: last landing in %.2fs; cast in %.2fs."):format(
				pending.landingLastEndsAt - snapshot.now, pending.landingCastAt - snapshot.now))
			return true
		end
	end
	if snapshot.now < state.nextAutoActionAt then return true end
	local position = pending.position or target and target.position or snapshot.hero.position
	if pending.sunRequest then
		-- v28 common FINAL gate: refresh the exact point and the mode's live safety immediately before
		-- CastPosition. Every real Sun Strike passes this same resolver regardless of how it was selected.
		local sunRelevant, sunAllowed, sunPosition, sunCastAt, sunReason = helpers.sunEngine.refresh(
			pending, target, snapshot, settings, "cast")
		if not sunRelevant then
			state.autoPending = nil
			helpers.sunPriority.release("Sun request lost at final gate")
			return false
		end
		if sunCastAt and snapshot.now < sunCastAt then
			setStatus("waiting", ("Sun Strike arrival in %.2fs."):format(sunCastAt - snapshot.now))
			return true
		end
		if not sunAllowed then
			pending.expiresAt = math.max(pending.expiresAt, snapshot.now + 0.75)
			setStatus("waiting", sunReason == "split_hold"
				and "Sun Strike: final split damage is no longer lethal; cast held."
				or string.sub(tostring(sunReason or ""), 1, 11) == "cast_route_"
					and "Sun Strike: target route changed during preparation; recalculating before cast."
					or "Sun Strike: common final safety gate is holding cast.")
			return true
		end
		position = sunPosition or position
		if (pending.kind == "sun_strike" or pending.kind == "quick_sun") and target then
			local castSpeed, castSpeedSource = helpers.sunPriority.castMotionSpeed(target)
			local recent = target.recentVelocity or target.velocity or {x = 0, y = 0, z = 0}
			local instant = target.instantVelocity or recent
			local live = target.liveVelocity or {x = 0, y = 0, z = 0}
			logDebug("SUN CAST MOTION", ("target=%d lockSpeed=%.0f castSpeed=%.0f source=%s moveSpeed=%.0f delta=%+.0f pos=%.0f,%.0f aim=%.0f,%.0f long=%.0f recent=%.0f live=%.0f instant=%.0f"):format(
				target.index, pending.sunLockSpeed or 0, castSpeed, tostring(castSpeedSource), target.moveSpeed or 0,
				castSpeed - (pending.sunLockSpeed or 0), target.position.x, target.position.y,
				position.x, position.y, length2D(target.velocity or {x = 0, y = 0, z = 0}),
				length2D(recent), length2D(live), length2D(instant)))
		end
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
		local recent = target.recentVelocity or target.velocity
		local instant = target.instantVelocity or recent
		local live = target.liveVelocity or {x = 0, y = 0, z = 0}
		local aim = target.sunAimMeta or {}
		logDebug("SUN AIM", ("target=%d mode=%s lead=%.0f current=%.0f,%.0f aim=%.0f,%.0f source=%s choice=%s terrain=%s routes=%d branches=%d blocked=%d farBlocked=%d dominant=%.2f second=%.2f entropy=%.2f stable=%.2f fork=%s forced=%s tconf=%.2f stretch=%.2f fallback=%.2f horizon=%.2f reach=%.2f frontLead=%.0f frontReserve=%.0f frontMargin=%.0f edgeBias=%.2f timingReserve=%+.3f speed=%s speedMod=%s speedIn=%.2f stat=%.0f>%.0f speedConf=%.2f covered=%.2f cloudBest=%s/%.2f turn=%+.3f accel=%+.0f native=%s turning=%s longVel=%.0f,%.0f recentVel=%.0f,%.0f liveVel=%.0f,%.0f instantVel=%.0f,%.0f recentConf=%.2f facing=%.2f,%.2f"):format(
			target.index, tostring(pending.sunMode or pending.kind), distance2D(target.position, position),
			target.position.x, target.position.y, position.x, position.y, tostring(aim.source or "?"), tostring(aim.choice or "?"),
			tostring(aim.terrainStatus or "?"), aim.routeCount or 0, aim.topologyBranches or 0, aim.topologyBlocked or 0, aim.topologyFarBlocked or 0, aim.dominantWeight or 0, aim.secondWeight or 0,
			aim.routeEntropy or 0, aim.terrainStability or 0, tostring(aim.terrainFork == true), tostring(aim.terrainForcedTurn == true), aim.terrainConfidence or 0, aim.terrainStretch or 1,
			aim.terrainFallbackWeight or 0, aim.horizon or 0, aim.reachHorizon or aim.horizon or 0, aim.frontLead or 0, aim.frontReserve or 0, aim.frontMargin or 0,
			aim.edgeBias or 0, aim.timingReserve or 0, tostring(aim.speedRegime or "steady"), tostring(aim.speedModifier or "none"),
			aim.speedExpiresIn or 0, aim.speedAffectedStat or 0, aim.speedBaselineStat or 0, aim.speedTransitionConfidence or 0,
			aim.covered or 0, tostring(aim.cloudBest or "?"), aim.cloudBestCovered or 0,
			aim.turnRate or 0, aim.acceleration or 0, tostring(target.nativeMoving), tostring(target.turning), target.velocity.x, target.velocity.y,
			recent.x, recent.y, live.x, live.y, instant.x, instant.y, target.recentMotionConfidence or 0, target.facing.x, target.facing.y))
	end
	-- v90: Safe SS is the LAST automatic gate before the unchanged physical CastPosition path.
	-- It never applies to manual portrait SS and never applies to Cataclysm.
	if id == "sun_strike" and pending.kind ~= "quick_sun"
		and snapshot.hero.upgrades.scepterChoice == "exort" and not settings.sunWithScepter
	then
		logDebug("AUTO SUN", ("kind=%s cancelled=scepter_gate"):format(tostring(pending.kind)))
		state.autoPending = nil
		helpers.sunPriority.release("Scepter Auto-SS gate")
		setStatus("waiting", "Sun Strike held: Scepter/Cataclysm is active.")
		return false
	end
	if id == "sun_strike" and pending.kind ~= "quick_sun" then
		local safeAllowed, safeReason = helpers.safeSunGate(pending, target, position, snapshot, settings)
		if not safeAllowed then
			pending.expiresAt = math.max(pending.expiresAt, snapshot.now + (safeReason == "dry_run" and 0.40 or 0.90))
			if safeReason == "dry_run" then
				setStatus("waiting", "Safe SS: calculations complete; physical Sun Strike order is blocked.")
			elseif safeReason == "notification_camera" then
				setStatus("waiting", "Safe SS: off-screen target; click the Sun Strike notification to inspect it.")
			elseif safeReason == "camera_move" then
				setStatus("waiting", "Safe SS: camera moved to the final aim; waiting for camera confirmation.")
			else
				setStatus("waiting", "Safe SS: final Sun Strike point is outside the current camera.")
			end
			return true
		end
	end

	-- v82 root safety: the physical Sun order ALWAYS happens before portrait bookkeeping.
	-- Counter/color tracking is post-order and pcall-isolated, so it can never block CastPosition.
	local kind, result = castAction({actionId = id, targetIndex = not pending.position and target and target.index or nil,
		position = position, exactPosition = pending.sunRequest and pending.sunRequest.positionMode ~= "predicted"}, snapshot)
	local portraitShotArmed = nil
	if kind == "issued" then
		if id == "sun_strike" and target then
			local speedMeta = target.sunAimMeta
			if speedMeta and ui.fileLog:Get() then
				local intervals = {}
				for _, interval in ipairs(speedMeta.speedTimeline or {}) do
					intervals[#intervals + 1] = ("%.2f-%.2f:%.0f/%s"):format(interval.from, interval.untilTime,
						interval.speed, interval.known and "observed" or "uncertain")
				end
				logDebug("SUN SPEED", ("own_order target=%d point=%.0f,%.0f distance=%.0f observedRange=%.0f..%.0f unresolved=%d intervals=%s"):format(
					target.index, position and position.x or 0, position and position.y or 0,
					speedMeta.speedTravelDistance or 0, speedMeta.speedMinimumDistance or 0, speedMeta.speedMaximumDistance or 0,
					speedMeta.speedUnresolvedIntervals or 0, table.concat(intervals, ";")))
			end
			state.sunVisualTargetIndex = target.index
			state.sunVisualTargetUntil = 0
			-- v95: the extended low-HP trajectory ends at the real order boundary. Post-cast route
			-- observation is logged separately and never reuses the visual hold as cast permission.
			state.safeSunVisualHold = nil
			state.safeSunPreview = nil
			helpers.beginSunPostCastTrace(target, pending, position, snapshot, result.issuedAt or snapshot.now)
			if helpers.sunEngine.isSunKind(pending.kind) then
				local okArm, armedOrError = pcall(helpers.beginSunPortraitShot, target, snapshot, result.issuedAt or snapshot.now, pending.kind, position, settings)
				if okArm then
					portraitShotArmed = armedOrError
				else
					logDebug("SUN RESULT", ("arm_error target=%d kind=%s error=%s -> CAST ALREADY ISSUED"):format(
						target.index or -1, tostring(pending.kind), tostring(armedOrError)))
				end
			end
		end
		if id == "cataclysm" then
			local okCata, cataError = pcall(helpers.beginCataclysmPortraitWindow, snapshot, result.issuedAt or snapshot.now, pending.kind)
			if not okCata then logDebug("SUN RESULT", "cataclysm_arm_error=" .. tostring(cataError) .. " -> CAST ALREADY ISSUED") end
		end
		pending.attempts = pending.attempts + 1
		pending.cast = {
			action = {actionId = id},
			issuedAt = result.issuedAt,
			cooldownBefore = result.cooldownBefore,
			secondsBefore = result.secondsBefore,
			deadline = result.issuedAt + (id == "sun_strike"
				and math.max(0.85, action.castPoint + snapshot.latency * 2 + 0.65)
				or math.max(cfg.castConfirmMin, action.castPoint + snapshot.latency * 2 + 0.35)),
		}
		if id == "sun_strike" then
			helpers.beginSunTimingProbe(snapshot, pending, action, result.issuedAt, position)
			if pending.kind ~= "quick_sun" then
				helpers.armSafeSunCameraReturn(pending, target, snapshot, result.issuedAt)
			end
		end
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


























---Runs one gameplay update for input, automation, planning, and execution.


































local function coreRun()
	helpers.disableBuiltinSunNumberIndication()
	if not ui.enabled:Get() then
		helpers.sunPriority.release("module disabled")
		state.landings, state.teleportParticles, state.teleportHistory = nil, nil, nil
		state.tornadoCataContainers = {}
		state.landingSunLock = nil
		state.snapshot = nil
		state.roshan = nil
		state.tormentors = nil
		state.invokeSequence = nil
		state.orbSequence = nil
		state.autoPending = nil
		helpers.sunPriority.releaseHpLatch("module disabled")
		state.quickSunHitboxes = {}
		state.quickSunEntries = {}
		state.movingSunBlockHitboxes = {}
		helpers.clearSafeSunNotification("module_disabled")
		state.safeSunVisuals = {}
		-- Never let a pending automatic camera return survive the master switch.
		state.safeSunCameraMove = nil
		return
	end

	local snapshot = buildSnapshot()
	if not snapshot or not snapshot.activeGame then
		if state.matchActive then helpers.finishMatchSession("active_game_false") end
		state.snapshot = nil
		return
	end
	if not state.matchActive then
		resetRuntime("new match")
		state.matchActive = true
		state.gameEndHandled = false
		snapshot = buildSnapshot()
		if not snapshot or not snapshot.activeGame then
			helpers.finishMatchSession("snapshot_lost_during_reset")
			return
		end
	end
	state.snapshot = snapshot
	-- v95 diagnostics continue through the post-order flight window even while normal automation is waiting.
	helpers.updateSunPostCastTrace(snapshot)
	-- v92: observe the actual shared Sun/Cataclysm ability state before resolving portrait outcomes.
	-- This catches player/manual and foreign-script casts even if their order callback was suppressed.
	local castObserveOk, castObserveError = pcall(helpers.observeAnySunCastState, snapshot)
	if not castObserveOk then logDebug("SUN RESULT", "cast_state_observer_error=" .. tostring(castObserveError) .. " -> CORE CONTINUES") end
	-- Portrait statistics are observational only. Any tracker error must not stop core Auto-Sun.
	local outcomeOk, outcomeError = pcall(helpers.updateSunPortraitOutcome, snapshot)
	if not outcomeOk then logDebug("SUN RESULT", "update_error=" .. tostring(outcomeError) .. " -> CORE CONTINUES") end
	local settings = readSettings()
	helpers.updateSafeSunCamera(snapshot, settings.auto)
	helpers.updateSafeSunNotification(snapshot, settings.auto)
	helpers.handleSafeSunNotificationClick(snapshot, settings.auto)
	if ui.fileLog:Get() and state.sessionTrace and state.sessionTrace.writeFailed then
		state.autoPending = nil
		state.invokeSequence = nil
		state.orbSequence = nil
		helpers.sunPriority.releaseHpLatch("runtime log unavailable")
		helpers.sunPriority.release("runtime log unavailable")
		state.statusPhase = "aborted"
		state.status = "LOGGER ERROR: cannot write C:\\Soft\\Umbrella\\scripts\\invoker_ss_game_log.txt; automation stopped."
		return
	end
	if not state.runtimeVersionLogged then
		state.runtimeVersionLogged = true
		logDebug("VERSION", "v138 stricter accuracy and reduced prediction work; file=C:\\Soft\\Umbrella\\scripts\\invoker_ss_game_log.txt")
	end

	-- MAIN INVOKER BINDS OWN INVOKER COMPLETELY. While combo, cursor-combo or precast is held,
	-- this standalone module may observe state but must issue no Sun/Cataclysm/orb orders
	-- and must release its order guard immediately.
	if helpers.mainInvokerCombo.active() then
		state.autoSunSafetyUntil = math.max(state.autoSunSafetyUntil or 0, snapshot.now + (cfg.autoSunResumeDelay or 3.0))
		state.autoSunSafetyReason = "main_bind"
		if state.autoPending or state.invokeSequence or state.orbSequence or helpers.sunPriority.active() then
			logDebug("COMBO GUARD", "main Invoker combo/precast bind active -> standalone Sun cancelled/paused")
		end
		state.autoPending = nil
		state.invokeSequence = nil
		state.orbSequence = nil
		helpers.sunPriority.releaseHpLatch("main Invoker combo/precast bind active")
		state.quickSunHitboxes = {}
		state.quickSunEntries = {}
		state.movingSunBlockHitboxes = {}
		helpers.sunPriority.release("main Invoker combo/precast bind active")
		setStatus("idle", "Main Invoker combo/precast bind active: standalone Sun paused.")
		return
	end

	if helpers.sunPriority.needed() then helpers.sunPriority.renew("core tick") else helpers.sunPriority.release("core idle") end
	helpers.updateQuickSunData(snapshot)
	if not snapshot.hero.alive then
		if not state.heroDead then
			state.heroDead = true
			logDebug("LIFECYCLE", ("hero death -> transient reset only; preserve Sun timing samples=%d commandMedian=%.3f"):format(
				#(state.sunCommandDelaySamples or {}), state.sunCommandDelayMedianObserved or 0))
			helpers.resetTransientRuntime("hero death")
		end
		return
	elseif state.heroDead then
		state.heroDead = false
		logDebug("LIFECYCLE", ("hero respawn -> diagnostics/timing preserved commandMedian=%.3f samples=%d"):format(
			state.sunCommandDelayMedianObserved or 0, #(state.sunCommandDelaySamples or {})))
	end
	if snapshot.paused then return end
	-- v111: invisibility refreshes the same safety deadline every frame.  The last invisible frame
	-- therefore leaves a full three-second no-auto window after the hero becomes visible again.
	if snapshot.hero.invisible then
		state.autoSunSafetyUntil = math.max(state.autoSunSafetyUntil or 0, snapshot.now + (cfg.autoSunResumeDelay or 3.0))
		state.autoSunSafetyReason = "invisibility"
	end
	local autoSunSafetyActive = snapshot.now < (state.autoSunSafetyUntil or 0)
	local nearbyEnemy = nil
	local safetyRadius = settings.auto.sunEnemySafetyRadius or 0
	if safetyRadius > 0 then
		for _, enemy in ipairs(snapshot.enemies or {}) do
			if enemy.alive and (enemy.visible and not enemy.dormant or enemy.fogProjected and (enemy.fogAge or math.huge) <= cfg.fogRouteTTL)
				and distance2D(snapshot.hero.position, enemy.position) <= safetyRadius then
				nearbyEnemy = enemy.index
				break
			end
		end
	end
	if nearbyEnemy then autoSunSafetyActive = true end
	-- v44: detect hidden Tornado victims at LIFT time, before Tornado landing damage exists.
	-- This lets lethal Tornado+Sun and fog Cataclysm schedule while victims are still airborne.
	helpers.observeFogTornadoLifts(snapshot, settings.auto)
	helpers.updateLandingTracks(snapshot, settings.auto)
	-- HP acquisition is intentionally earlier than route qualification. This only remembers the lethal
	-- hero; it cannot press EEE/Invoke or issue Sun until the normal readiness gate later in coreRun.
	-- Once any action is already pending/invoking, do not acquire a second logical HP target in parallel.
	if not autoSunSafetyActive and not state.autoPending and not state.invokeSequence and not state.orbSequence then
		helpers.sunPriority.updateHpLatch(snapshot, settings.auto)
	elseif autoSunSafetyActive and state.sunHpLatch then
		helpers.sunPriority.releaseHpLatch("3-second combo/precast/invisibility safety")
	end
	-- v99 observational attention/UI scan: evaluates every current ordinary Auto-SS candidate without
	-- changing selectAutoSunTarget(), HP-latch ownership, queue priority, or physical cast selection.
	helpers.updateSafeSunCandidateUI(snapshot, settings.auto)
	helpers.updateSafeSunAutoCamera(snapshot, settings.auto)

	-- Do not stop automatic Sun Strike acquisition just because the cheat menu is open.
	-- Manual portrait clicks still use their own Input.IsInputCaptured() guard.
	if snapshot.hero.channeling or snapshot.hero.inAbilityPhase then return end
	if snapshot.hero.stunned or snapshot.hero.silenced then
		state.invokeSequence = nil
		state.orbSequence = nil
		setStatus("waiting", "Invoker is disabled or silenced.")
		return
	end

	-- A cast that has already been issued must finish confirmation first.
	if state.autoPending and state.autoPending.cast and processAutoPending(snapshot, settings.auto) then return end
	if snapshot.now < state.automaticActionsPausedUntil then
		if state.sunHpLatch then
			local pausedTarget = findEnemy(snapshot, state.sunHpLatch.targetIndex)
			if pausedTarget then
				helpers.sunPriority.logWhyHold(pausedTarget, snapshot, "MANUAL_PAUSE",
					("remaining=%.2f"):format(math.max(0, state.automaticActionsPausedUntil - snapshot.now)))
			end
		end
		return
	end

	-- As in the donor, a portrait click may replace an automatic action that is only being prepared.
	local quickSunTarget = clickedQuickSunTarget(snapshot, settings.auto)
	local manualSun = state.autoPending and state.autoPending.kind == "quick_sun"
	if (snapshot.hero.invisible or autoSunSafetyActive) and not quickSunTarget and not manualSun then
		state.autoPending = nil
		state.invokeSequence = nil
		state.orbSequence = nil
		helpers.sunPriority.releaseHpLatch(snapshot.hero.invisible and "Invoker invisible" or "3-second safety")
		helpers.sunPriority.release(snapshot.hero.invisible and "invisible idle" or "post combo/precast/invisibility safety")
		logChanged("auto_sun_safety", "AUTO SUN SAFETY",
			nearbyEnemy and ("reason=nearby_enemy target=%d radius=%d -> NO AUTO SS/ORB/INVOKE"):format(nearbyEnemy, safetyRadius)
				or ("reason=%s delay=3.00 -> NO AUTO SS/ORB/INVOKE"):format(tostring(state.autoSunSafetyReason or "unknown")))
		return
	end

	-- Portrait button is the highest priority path and intentionally bypasses lethality.
	if quickSunTarget then
		if not queueAutoAction("sun_strike", quickSunTarget, "quick_sun", snapshot) then
			setStatus("aborted", "Quick Sun Strike is unavailable.")
		else
			helpers.sunPriority.releaseHpLatch("manual portrait Sun took priority")
			processAutoPending(snapshot, settings.auto)
		end
		return
	end

	-- Continue a queued automatic action that has not cast yet (Invoke/preparation/timed wait).
	-- v43: first let newly observed Tornado lift-events promote a still-unfired Landing Sun into
	-- Landing Cataclysm. This is what allows 3 confirmed fog lifts to become 3/3 targets even while
	-- the first single-target Sun was already being prepared.
	if state.autoPending and state.autoPending.kind == "landing_sun" and not state.autoPending.cast then
		helpers.promoteLandingSunToCataclysm(snapshot, settings.auto)
	end
	if state.autoPending and processAutoPending(snapshot, settings.auto) then return end


	updateInvokeSequence(snapshot)
	updateOrbSequence(snapshot)
	if state.invokeSequence or state.orbSequence then return end

	if snapshot.now < state.nextAutoActionAt or state.autoPending then return end

	-- v49 preserves the first Tornado victim that passes the Landing-Sun lethal check. This lock is
	-- acquired in actual Tornado catch order and reserves the single-target Sun while Cataclysm keeps
	-- its independent higher-priority group logic. Later Tornado victims cannot replace the locked Sun.
	-- v53: Aghanim Cataclysm gets the first Tornado-group check. The selector also updates the
	-- persistent safety-extended confirmation box (normally ~1.00 s at Quas 8 in v56) even before the configured threshold is reached; only
	-- after that first check may the single-target Tornado Landing-Sun evaluator claim a target.
	local landingCataclysm = helpers.selectLandingCataclysm(snapshot, settings.auto)
	if not landingCataclysm then helpers.evaluateTornadoLandingLethals(snapshot, settings.auto) end
	local cataclysmTarget = not landingCataclysm and selectCataclysmTarget(snapshot, settings.auto) or nil
	local landingTarget = not landingCataclysm and not cataclysmTarget and helpers.selectLandingSun(snapshot, settings.auto) or nil
	local landingSunLockWindow = not landingCataclysm and not cataclysmTarget and state.landingSunLock
		and helpers.landingSunLockedWindow(snapshot, settings.auto, state.landingSunLock) or nil
	local landingSunLockActive = not landingCataclysm and not cataclysmTarget and state.landingSunLock ~= nil
	local sunTarget = not landingCataclysm and not cataclysmTarget and not landingTarget and not landingSunLockActive
		and selectAutoSunTarget(snapshot, settings.auto) or nil
	local hpLatchActive = state.sunHpLatch ~= nil

	-- v106: discovery/calculation must happen before the physical Sun cooldown gate. Airborne Tornado
	-- victims are invulnerable/out-of-game and therefore cannot use the ordinary Auto-SS evaluator;
	-- returning above the Landing evaluators made them look completely uncalculated while Sun was cooling
	-- down, and also prevented the independent Cataclysm route from being considered. The cooldown still
	-- blocks every single-target Sun order below; it no longer blocks observation, split/lethal accounting,
	-- or a ready Cataclysm action.
	local sunAction = snapshot.actions.sun_strike
	if not landingCataclysm and not cataclysmTarget
		and settings.auto.sunStrike and sunAction and sunAction.exists and sunAction.cooldown > 0.05
	then
		setStatus("waiting", ("Sun Strike cooldown %.2fs; Tornado landing calculation remains active."):format(sunAction.cooldown))
		return
	end

	if landingCataclysm then
		if landingCataclysm.queueReady and helpers.queueLandingCataclysm(landingCataclysm, snapshot, settings.auto) then
			helpers.releaseLandingSunLock("Landing Cataclysm queued")
			helpers.sunPriority.releaseHpLatch("landing Cataclysm priority")
			setStatus("preparing", "Cataclysm: preparing for the last of multiple landings.")
		else
			helpers.sunPriority.releaseHpLatch("landing Cataclysm reservation")
			setStatus("waiting", ("Cataclysm: %d landing targets; waiting for last-landing cast window."):format(
				landingCataclysm.count or 2))
		end
	elseif cataclysmTarget and queueAutoAction("cataclysm", cataclysmTarget, "cataclysm", snapshot) then
		helpers.releaseLandingSunLock("generic Cataclysm queued")
		helpers.sunPriority.releaseHpLatch("Cataclysm priority consumed Sun")
		setStatus("preparing", "Automatic Cataclysm took priority.")
	elseif landingTarget and helpers.queueLandingSun(landingTarget, snapshot, settings.auto) then
		helpers.sunPriority.releaseHpLatch("arrival Sun priority")
		setStatus("preparing", "Sun Strike: preparing for arrival.")
	elseif landingSunLockActive and state.landingSunLock then
		helpers.sunPriority.releaseHpLatch("first lethal Tornado Landing Sun reserved")
		if landingSunLockWindow then
			setStatus("waiting", ("Landing Sun locked on target %d; cast in %.2fs."):format(
				state.landingSunLock.targetIndex, math.max(0, landingSunLockWindow.castAt - snapshot.now)))
		else
			setStatus("waiting", ("Landing Sun locked on target %d; waiting for execution readiness."):format(
				state.landingSunLock.targetIndex))
		end
	elseif sunTarget and queueAutoAction("sun_strike", sunTarget, "sun_strike", snapshot) then
		logDebug("SUN FLOW", ("cooldown=%.2f target=%d invoked=%s slot=%s -> prepare/cast"):format(
			snapshot.actions.sun_strike.cooldown, sunTarget.index, tostring(snapshot.actions.sun_strike.invoked),
			tostring(snapshot.actions.sun_strike.activeSlotIndex or "none")))
		local evaluation = sunTarget.sunEvaluation
		if evaluation then
			logDebug("SUN LOCK", ("target=%d mode=%s reliability=%.2f hpImpact=%.0f damage=%.0f split=%d hpLatched=%s hpLock=%.0f/%.0f controlShot=%s policy=%s"):format(
				sunTarget.index, tostring(evaluation.mode or "?"), evaluation.reliability or 0, evaluation.impactHealth or 0,
				evaluation.expectedDamage or 0, evaluation.splitCount or 1, tostring(evaluation.hpLatched == true),
				evaluation.hpLatchImpactHealth or 0, evaluation.hpLatchExpectedDamage or 0,
				tostring(evaluation.controlShot == true), tostring(evaluation.controlPolicy or "none")))
		end
		if state.sunHpLatch and state.sunHpLatch.targetIndex == sunTarget.index then
			logDebug("SUN HP LOCK", ("promote target=%d -> CAST LOCK after route/Invoke permission"):format(sunTarget.index))
			state.sunHpLatch = nil
		end
		setStatus("preparing", "Automatic Sun Strike took priority.")
	elseif hpLatchActive then
		setStatus("waiting", "Lethal Sun target locked: waiting for route / Invoke readiness.")
	elseif not sunTarget and helpers.isRoshanSunTarget(snapshot, settings.auto)
		and queueAutoAction("sun_strike", snapshot.roshan, "roshan_sun", snapshot)
	then
		state.autoPending.position = copyPoint(snapshot.roshan.position)
		state.nextAutoActionAt = snapshot.now
	else
		local objective = helpers.selectTormentorSunTarget(snapshot, settings.auto)
		if objective and queueAutoAction("sun_strike", objective, "tormentor_sun", snapshot) then
			state.autoPending.position = copyPoint(objective.position)
			state.nextAutoActionAt = snapshot.now
		end
	end

	if state.autoPending then processAutoPending(snapshot, settings.auto) end
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

local function quickSunReady(snapshot, target, settings)
	local action = snapshot.actions.sun_strike
	local tracked = target and ((target.visible and not target.dormant)
		or (target.fogProjected and (target.fogAge or math.huge) <= cfg.fogRouteTTL))
	return target
		and target.alive
		and tracked
		and not target.invulnerable
		and action
		and action.exists
		and action.learned
		and action.cooldown <= 0.05
		and snapshot.hero.mana + 0.001 >= action.manaCost
		and (action.invoked or settings.sunSelfCharge and snapshot.invoke.ready)
end

function helpers.updateQuickSunData(snapshot)
	state.quickSunEntries = {}
	state.movingSunBlockEntityKeys = {}
	if not snapshot.hero.alive then return end
	local settings = readSettings().auto
	local showButtons = ui.autoSunStrike:Get() and ui.quickSunButtons:Get()
	if not showButtons and not ui.movingSunBlockVisual:Get() then return end
	local targetByIndex = {}
	for _, enemy in ipairs(snapshot.enemies) do targetByIndex[enemy.index] = enemy end
	local previousSplitCache = state.quickSunSplitCache or {}
	local splitCache = {}
	state.quickSunSplitCache = splitCache
	local enemyPlayers = {}
	-- Snapshot-owned invariants: resolve once for every portrait target in this update. No value survives
	-- the frame, so ability/timing changes are naturally invalidated by the next snapshot.
	local sunMechanics, sunImpactDelay, sunImpactRadius
	for _, player in ipairs(Players.GetAll()) do
		local assignedHero = Player.GetAssignedHero(player)
		if assignedHero and not Entity.IsSameTeam(snapshot.hero.entity, assignedHero) then
			local targetIndex = Entity.GetIndex(assignedHero)
			local target = targetByIndex[targetIndex]
			local split = 1
			if target and showButtons then
				local cached = previousSplitCache[targetIndex]
				if cached and snapshot.now >= cached.at
					and snapshot.now - cached.at < cfg.sunPortraitPredictionInterval then
					split = cached.split
					splitCache[targetIndex] = cached
				else
				if not sunMechanics then
					sunMechanics = resolveMechanics("sun_strike", snapshot, 0)
					sunImpactDelay = helpers.sunImpactDelay(snapshot, "sun_strike")
					sunImpactRadius = math.max(cfg.sunRadius, sunMechanics.radius)
				end
				local prediction = predictIntercept(snapshot, "sun_strike", target, snapshot.now, target.motionConfidence).position
				split = sunSplitCount(snapshot, prediction, sunImpactRadius, targetIndex, sunImpactDelay)
				splitCache[targetIndex] = {at = snapshot.now, split = split}
				end
			end
			local heroName = NPC.GetUnitName(assignedHero)
			local teamSlot = Player.GetPlayerTeamSlot(player)
			local blockKey = helpers.movingSunPortraitKey(assignedHero, teamSlot, heroName)
			if blockKey then state.movingSunBlockEntityKeys[targetIndex] = blockKey end
			enemyPlayers[#enemyPlayers + 1] = {
				targetIndex = targetIndex,
				heroName = heroName,
				blockKey = blockKey,
				ready = showButtons and quickSunReady(snapshot, target, settings) or false,
				split = split,
				movingBlocked = blockKey and state.movingSunBlocks and state.movingSunBlocks[blockKey] == true or false,
				teamSlot = teamSlot,
			}
		end
	end
	table.sort(enemyPlayers, function(left, right) return left.teamSlot < right.teamSlot end)
	state.quickSunEntries = enemyPlayers
end

local function drawQuickSunButtons()
	state.quickSunHitboxes = {}
	state.movingSunBlockHitboxes = {}
	local snapshot = state.snapshot
	if not ui.enabled:Get() or not snapshot
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
	local blockSize = 14 * scaleValue
	local edgeOffset = 37 * scaleValue
	local teamWidth = portraitWidth * 5 + portraitGap * 4
	local enemyTeamOnRight = Entity.GetTeamNum(snapshot.hero.entity) == Enum.TeamNum.TEAM_RADIANT
	local teamStart = enemyTeamOnRight
		and screen.x * 0.5 + centerGap * 0.5
		or screen.x * 0.5 - centerGap * 0.5 - teamWidth
	local y = portraitHeight + 51 * scaleValue

	local sunMasterActive = ui.autoSunStrike:Get()
	for index, entry in ipairs(state.quickSunEntries) do
		if index > 5 then break end
		local portraitX = teamStart + (index - 1) * (portraitWidth + portraitGap)
		local x = enemyTeamOnRight
			and portraitX + portraitWidth - buttonSize + edgeOffset
			or portraitX - edgeOffset
		local targetIndex = entry.targetIndex
		local ready = entry.ready
		local borderStart = Vec2(x - 2 * scaleValue, y - 2 * scaleValue)
		local borderEnd = Vec2(x + buttonSize + 2 * scaleValue, y + buttonSize + 2 * scaleValue)
		if sunMasterActive and ui.quickSunButtons:Get() then
			local hovered = ready and Input.IsCursorInRect(x - 2 * scaleValue, y - 2 * scaleValue, buttonSize + 4 * scaleValue, buttonSize + 4 * scaleValue)
			local background = ready
				and (hovered and Color(255, 142, 56, 245) or Color(222, 74, 45, 245))
				or Color(55, 60, 65, 165)
			Render.FilledRect(borderStart, borderEnd, background, 5 * scaleValue)
			Render.Image(
				renderCtx.icons.sun_strike,
				Vec2(x, y),
				Vec2(buttonSize, buttonSize),
				ready and Color(255, 255, 255, 255) or Color(155, 155, 155, 90),
				4 * scaleValue
			)
		end

		if sunMasterActive and ui.quickSunButtons:Get() and entry.split > 1 then
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

		if sunMasterActive and ui.quickSunButtons:Get() and ready then
			state.quickSunHitboxes[#state.quickSunHitboxes + 1] = {
				x = borderStart.x,
				y = borderStart.y,
				width = buttonSize + 4 * scaleValue,
				height = buttonSize + 4 * scaleValue,
				targetIndex = targetIndex,
			}
		end

		-- v83: same calibrated portrait anchor. X remains a moving-target block marker, while
		-- v91: SS and Cataclysm keep independent result/cooldown state; the portrait shows the latest active result.
		local overlayStat = entry.blockKey and helpers.sunPortraitStat(entry.blockKey) or nil
		local overlayResult = overlayStat and helpers.sunPortraitDisplayResult(overlayStat, state.snapshot and state.snapshot.now or GameRules.GetGameTime()) or nil
		if ui.movingSunBlockVisual:Get() and entry.blockKey then
			local heroBarPortraitX = x + buttonSize * 0.5 - portraitWidth * 0.5
			local blockX = heroBarPortraitX + 3 * scaleValue
			local blockY = 3 * scaleValue
			local blockPad = 1.5 * scaleValue
			local blockRectX = blockX - blockPad
			local blockRectY = blockY - blockPad
			local blockRectSize = blockSize + blockPad * 2
			local blockSelected = state.movingSunBlocks and state.movingSunBlocks[entry.blockKey] == true
			local blockHover = Input.IsCursorInRect(blockRectX, blockRectY, blockRectSize, blockRectSize)
			local stat = overlayStat
			local displayResult = overlayResult
			local resultColor = displayResult == "miss" and Color(255, 64, 64, 255)
				or displayResult == "hit" and Color(255, 219, 112, 255)
				or displayResult == "kill" and Color(79, 219, 154, 255)
				or nil
			local xColor = resultColor or Color(205, 210, 220, 235)
			local xBackground = displayResult == "miss" and Color(148, 38, 38, 232)
				or displayResult == "hit" and Color(110, 88, 30, 232)
				or displayResult == "kill" and Color(31, 101, 72, 232)
				or Color(20, 24, 30, 205)
			Render.FilledRect(
				Vec2(blockRectX, blockRectY), Vec2(blockRectX + blockRectSize, blockRectY + blockRectSize),
				blockSelected and xBackground
					or (blockHover and Color(72, 79, 90, 232) or Color(20, 24, 30, 205)), 2 * scaleValue)
			Render.Rect(
				Vec2(blockRectX, blockRectY), Vec2(blockRectX + blockRectSize, blockRectY + blockRectSize),
				blockSelected and xColor
					or (blockHover and Color(168, 177, 192, 230) or Color(92, 99, 111, 190)),
				2 * scaleValue, Enum.DrawFlags.None, blockSelected and 2 or 1)
			if blockSelected then
				-- The block marker always owns this slot; counting remains independent.
				Render.Image(renderCtx.controls.close, Vec2(blockX, blockY), Vec2(blockSize, blockSize), xColor, 2 * scaleValue)
			elseif ui.sunCountMisses:Get() then
				local counterText = tostring(stat and stat.misses or 0)
				local counterSize = Render.TextSize(renderCtx.badgeFont, 12 * scaleValue, counterText)
				local counterColor = resultColor or Color(205, 210, 220, 235)
				Render.Text(renderCtx.badgeFont, 12 * scaleValue, counterText,
					Vec2(blockRectX + (blockRectSize - counterSize.x) * 0.5, blockRectY + (blockRectSize - counterSize.y) * 0.5), counterColor)
			else
				local dotColor = resultColor or Color(205, 210, 220, 235)
				Render.FilledCircle(Vec2(blockRectX + blockRectSize * 0.5, blockRectY + blockRectSize * 0.5), 4.2 * scaleValue, dotColor, 0, 1, 20)
			end
			state.movingSunBlockHitboxes[#state.movingSunBlockHitboxes + 1] = {
				x = blockRectX, y = blockRectY, width = blockRectSize, height = blockRectSize,
				targetIndex = targetIndex, heroName = entry.heroName, teamSlot = entry.teamSlot, blockKey = entry.blockKey,
			}
		end
	end
end













function invoker.OnUpdate()
	coreRun()
	helpers.traceCheckpoint("periodic", false)
end

function invoker.OnDraw()
	drawQuickSunButtons()
	helpers.drawSafeSunNotification()
	helpers.drawSafeSunIndication()
end

function invoker.OnKeyEvent(data)
	if not data or data.key ~= Enum.ButtonCode.KEY_MOUSE1 then return true end
	if data.event == Enum.EKeyEvent.EKeyEvent_KEY_UP then
		if helpers.blockClickHeld then
			helpers.blockClickHeld = nil
			return false
		end
		return true
	end
	if data.event ~= Enum.EKeyEvent.EKeyEvent_KEY_DOWN then return true end
	if helpers.blockClickHeld then return false end
	if not state.snapshot or not ui.enabled or not ui.enabled:Get()
		or not ui.movingSunBlockVisual:Get() or Input.IsInputCaptured() then return true end
	if helpers.handleMovingSunBlockClick(state.snapshot) then
		helpers.blockClickHeld = true
		return false
	end
	return true
end

function invoker.OnPrepareUnitOrders(data)
	if not data then return true end
	local now = GameRules.GetGameTime()
	if helpers.mainInvokerCombo and helpers.mainInvokerCombo.active() then
		helpers.sunPriority.release("main Invoker combo/precast order")
		return true
	end
	-- Own orders must bypass first. Some builds/callback paths do not preserve identifier reliably,
	-- while issueOrder() is guaranteed to wrap only this module's synchronous command emission.
	if state.issuingOrder then return true end
	if data and data.identifier == helpers.sunPriority.identifier then return true end
	local hero = Heroes.GetLocal()
	if not hero or NPC.GetUnitName(hero) ~= cfg.heroName then return true end

	-- v97 root fix: NEVER reject an already-observed engine order here.  OnPrepareUnitOrders does not
	-- provide a trustworthy provenance signal that can distinguish a real player button press from every
	-- foreign automation path.  Blocking at this boundary therefore blocked the player's own D/F Sun.
	-- Lower-priority Lua automation is still arbitrated at its command SOURCE by installGuards() above;
	-- once an order reaches this callback, real player control wins and the order is allowed through.

	-- The short order guard remains only a self-echo suppressor for an asynchronously observed own order.
	if now <= state.orderGuardUntil then return true end

	-- v92 observational outcome tracker: every accepted external/player Sun/Cataclysm order uses the same result system.
	-- Orders issued by this module are armed after their physical cast; callback-suppressed orders are recovered by cooldown transition.
	local trackOk, trackError = pcall(helpers.observeExternalSunOrder, data, hero, now)
	if not trackOk then logDebug("SUN RESULT", "external_order_tracker_error=" .. tostring(trackError) .. " -> INPUT CONTINUES") end

	-- Outside the critical Sun window, preserve the donor behavior: a real manual ability order pauses
	-- automation instead of fighting the player.
	if data.ability and Entity.RecursiveOwnedBy(data.ability, hero) then
		state.automaticActionsPausedUntil = now + cfg.manualActionPause
		state.autoPending = nil
		state.invokeSequence = nil
		state.orbSequence = nil
		helpers.sunPriority.releaseHpLatch("manual ability order")
		helpers.sunPriority.release("manual ability order")
		logDebug("INPUT", "manual ability order released standalone Sun priority; PLAYER ORDER PASSED")
	end
	return true
end

function invoker.OnEntityDestroy(entity)
	if not entity then return end
	local index = Entity.GetIndex(entity)
	if state.landings then state.landings[index] = nil end
	state.motion[index] = nil
	if state.sunTerrainCache then state.sunTerrainCache[index] = nil end
	if state.motionQuarantine then state.motionQuarantine[index] = nil end
	if state.roshan and state.roshan.index == index then state.roshan = nil end
	if state.tormentors then state.tormentors[index] = nil end
end

function invoker.OnEntityKilled(data)
	if not data then return end
	if not data.target then return end
	-- v82: result-color bookkeeping is isolated from all existing death cleanup.
	local portraitOk, portraitError = pcall(helpers.observeSunPortraitDeath, data)
	if not portraitOk then logDebug("SUN RESULT", "death_observer_error=" .. tostring(portraitError) .. " -> CALLBACK CONTINUES") end
	local cataOk, cataError = pcall(helpers.observeCataclysmPortraitDeath, data)
	if not cataOk then logDebug("SUN RESULT", "cataclysm_death_error=" .. tostring(cataError) .. " -> CALLBACK CONTINUES") end
	local index = Entity.GetIndex(data.target)
	if state.landings then state.landings[index] = nil end
	if state.tormentors then state.tormentors[index] = nil end
	state.motion[index] = nil
	if state.sunTerrainCache then state.sunTerrainCache[index] = nil end
	if state.motionQuarantine then state.motionQuarantine[index] = nil end
end

function invoker.OnEntityHurt(data)
	if not data or type(data.damage) ~= "number" then return end
	-- v82: result-color bookkeeping is isolated from Tornado/Roshan/Tormentor damage observers.
	local portraitOk, portraitError = pcall(helpers.observeSunPortraitDamage, data)
	if not portraitOk then logDebug("SUN RESULT", "damage_observer_error=" .. tostring(portraitError) .. " -> CALLBACK CONTINUES") end
	local cataOk, cataError = pcall(helpers.observeCataclysmPortraitDamage, data)
	if not cataOk then logDebug("SUN RESULT", "cataclysm_damage_error=" .. tostring(cataError) .. " -> CALLBACK CONTINUES") end
	-- v44: Tornado OnEntityHurt is landing-damage confirmation only. Lift/catch records must already
	-- exist from the modifier or hidden lift-state detector; this callback must never add another lift duration.
	helpers.observeTornadoHit(data)
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
	if not entity or not modifier then return end
	helpers.recordLandingModifier(entity, modifier)
end

function invoker.OnModifierUpdate(entity, modifier)
	if not entity or not modifier then return end
	helpers.recordLandingModifier(entity, modifier)
end

function invoker.OnModifierDestroy(entity, modifier)
	if not entity or not modifier then return end
	helpers.destroyLandingModifier(entity, modifier)
end

function invoker.OnParticleCreate(data)
	if not data or data.index == nil then return end
	helpers.observeSunParticle(data)
	helpers.createTeleportParticle(data)
end

function invoker.OnParticleUpdate(data)
	if not data or data.index == nil then return end
	helpers.updateTeleportParticle(data)
end

function invoker.OnParticleUpdateFallback(data)
	if not data or data.index == nil then return end
	helpers.updateTeleportParticle(data)
end

function invoker.OnParticleUpdateEntity(data)
	if not data or data.index == nil then return end
	helpers.attachTeleportTarget(data)
end

function invoker.OnParticleDestroy(data)
	if not data or data.index == nil then return end
	if state.teleportParticles then state.teleportParticles[data.index] = nil end
end

function invoker.OnGameEnd()
	helpers.finishMatchSession("OnGameEnd")
	state.sunOutcomeShot = nil
	state.sunOutcomeCataclysms = {}
	state.sunOutcomeCooldownSeen = false
	state.sunCooldownTracking = false
	state.cataclysmResultReadyAt = 0
	state.cataclysmCooldownProbeUntil = 0
	state.cataclysmCooldownBase = 0
end

return invoker
