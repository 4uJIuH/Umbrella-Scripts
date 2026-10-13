--[[
    ~ Broodmother Auto Camp Blocker
    ~ Version: v1.6
    ~ Features:
      - Automatically manages Broodmother spiderlings/spiderites to block selected neutral creep camps
      - In-game interactive Dota 2 map overlay to toggle camps with a single click (open via hotkey or menu)
      - Conservative timing engine: sends only spiders that can arrive by the configured second and survive through :00
      - Holds position during :00 spawn check, then automatically retreats spiders back to Broodmother
      - Selects spiders based on longest remaining lifetime and highest HP (1 spider per camp)
      - Quick filters: "Enemy Camps", "Ancients", "Clear All"
      - Full bilingual localization (English / Russian) using qLocalization
      - Hero validation: activates only when playing Broodmother
      - Optional world ESP: ground camp circles, timers, and line tracers from spiders to camps
]]

local script = {}

if Log and Log.Write then
    pcall(Log.Write, "[brood_camp_blocker] SCRIPT LOAD STARTED")
end
local qLoc = nil
local okLoc, resLoc = pcall(function() return qLocalization end)
if okLoc and type(resLoc) == "table" then
    qLoc = resLoc
else
    local okReq, resReq = pcall(require, "!_qLocalizer")
    if okReq and type(resReq) == "table" then
        qLoc = resReq
    end
end

-- Localization data dictionary
local translations = {
    en = {
        brood_cb = {
            tab = "Broodmother",
            group_main = "Auto Camp Blocker",
            group_map = "Interactive Map & Camps",
            group_esp = "World ESP & Visuals",
            
            enabled = "Enable Camp Blocker",
            enabled_tip = "Automatically dispatches individual spiderlings/spiderites to block selected creep camps at :00 every minute.",
            toggle_bind = "Toggle Blocker Key",
            toggle_bind_tip = "Hotkey to toggle the auto camp blocker on/off.",
            
            map_key = "Open Map Key",
            map_key_tip = "Hotkey to open/close the interactive Dota 2 minimap for selecting camps to block.",
            show_map = "Show Interactive Map",
            show_map_tip = "Toggles the interactive map window where you can click camps to select them.",
            
            spider_type = "Spider Type",
            spider_type_tip = "Which spider units to dispatch for camp blocking.",
            spider_type_all = "All Spiders (Spiderlings & Spiderites)",
            spider_type_ling = "Spiderlings Only (Higher HP)",
            spider_type_ite = "Spiderites Only",
            
            return_to_hero = "Retreat To Hero After Block",
            return_to_hero_tip = "After blocking at :00.5, orders the spider to run back to Broodmother immediately.",
            
            arrival_second = "Arrival Target Second",
            arrival_second_tip = "The second of the minute by which the spider must already be stationary in the camp (default: 53s, so they are ready before 55s).",
            safety_margin = "Travel Time Safety Margin",
            safety_margin_tip = "Safety margin in seconds (1-5s) to dispatch spiders earlier and ensure they never arrive late.",
            double_spiders = "Send 2 Spiders on Far Camps",
            double_spiders_tip = "Dispatches 2 spiders at once to distant camps or camps with risk of not reaching.",
            
            world_esp = "Show World ESP",
            world_esp_tip = "Draws indicators and timers on the ground over selected camps.",
            spider_tracers = "Draw Spider Tracers",
            spider_tracers_tip = "Draws lines connecting assigned spiders to their target camps.",
            
            panel_scale = "Map Panel Scale",
            panel_scale_tip = "Scale factor for the interactive map window.",
            
            -- In-panel texts
            panel_title = "BROODMOTHER CAMP BLOCKER",
            btn_enemy = "Enemy Camps",
            btn_ancients = "Ancients",
            btn_clear = "Clear All",
            btn_all = "Select All",
            
            status_active = "ACTIVE",
            status_disabled = "DISABLED",
            status_not_brood = "NOT BROODMOTHER",
            
            next_spawn_in = "Next spawn: %02d:%02d (in %ds)",
            spiders_pool = "Spiders: %d ready (%d assigned)",
            
            camp_small = "Small",
            camp_medium = "Medium",
            camp_large = "Large",
            camp_ancient = "Ancient",
            camp_radiant = "Radiant",
            camp_dire = "Dire",
            
            state_idle = "Idle",
            state_moving = "Moving (ETA %02d:%02d)",
            state_at_camp = "At Camp (Blocking)",
            state_blocked = "Blocked! Retreating",
            
            tip_selected = "Block: YES",
            tip_unselected = "Block: NO (Click to select)",
            tip_spider = "Spider: HP %d/%d, Life: %.0fs",
            tip_eta = "Arrival: %02d:%02d (%s)"
        }
    },
    ru = {
        brood_cb = {
            tab = "Broodmother",
            group_main = "Авто-блок кемпов",
            group_map = "Интерактивная карта кемпов",
            group_esp = "ESP и визуализация в мире",
            
            enabled = "Включить авто-блок",
            enabled_tip = "Каждую минуту к ровно :00 отправляет по одному паучку на выбранные кемпы для блокировки спавна крипов.",
            toggle_bind = "Клавиша включения/выключения",
            toggle_bind_tip = "Клавиша для быстрого включения или отключения работы скрипта.",
            
            map_key = "Клавиша открытия карты",
            map_key_tip = "Назначьте клавишу для быстрого открытия/закрытия интерактивной карты доты для выбора кемпов.",
            show_map = "Открыть интерактивную карту",
            show_map_tip = "Отображает окно с картой, где можно кликом выбирать нужные кемпы.",
            
            spider_type = "Тип пауков для блокировки",
            spider_type_tip = "Каких пауков отправлять на блокировку кемпов.",
            spider_type_all = "Все пауки (Пауки и Паучата)",
            spider_type_ling = "Только Большие Пауки (Spiderlings)",
            spider_type_ite = "Только Паучата (Spiderites)",
            
            return_to_hero = "Возвращать пауков после блока",
            return_to_hero_tip = "Сразу после блокировки кемпа в :00.5 отправляет паука обратно к Брудмазер.",
            
            arrival_second = "Тайминг прибытия",
            arrival_second_tip = "Секунда минуты, к которой паучок уже должен стоять внутри кемпа (по умолчанию 53 сек, чтобы к 55 сек они гарантированно заняли позиции).",
            safety_margin = "Запас времени (буфер)",
            safety_margin_tip = "Запас времени в секундах (1-5 сек), чтобы паучки выходили заранее и гарантированно успевали добежать до кемпа.",
            double_spiders = "Отправлять 2 паука на дальние кемпы",
            double_spiders_tip = "Отправлять сразу 2 паучка на дальние кемпы или при риске не успеть/погибнуть.",
            
            world_esp = "Отображать кемпы на земле (ESP)",
            world_esp_tip = "Рисует метки и таймеры над выбранными кемпами прямо в игре.",
            spider_tracers = "Линии от пауков к кемпам",
            spider_tracers_tip = "Рисует трассирующие линии от пауков к назначенным кемпам.",
            
            panel_scale = "Масштаб карты кемпов",
            panel_scale_tip = "Размер интерактивного окна карты.",
            
            panel_title = "БЛОКЕР КЕМПОВ BROODMOTHER",
            btn_enemy = "Вражеские",
            btn_ancients = "Древние",
            btn_clear = "Сброс",
            btn_all = "Выбрать все",
            
            status_active = "АКТИВЕН",
            status_disabled = "ОТКЛЮЧЕН",
            status_not_brood = "ВЫ НЕ BROODMOTHER",
            
            next_spawn_in = "Спавн крипов: %02d:%02d (через %dс)",
            spiders_pool = "Пауки: %d готово (%d на кемпах)",
            
            camp_small = "Малый",
            camp_medium = "Средний",
            camp_large = "Большой",
            camp_ancient = "Древний",
            camp_radiant = "Radiant",
            camp_dire = "Dire",
            
            state_idle = "Ожидание",
            state_moving = "Бежит (ETA %02d:%02d)",
            state_at_camp = "На кемпе (Блокирует)",
            state_blocked = "Заблокирован! Отход",
            
            tip_selected = "Блок: ДА",
            tip_unselected = "Блок: НЕТ (Клик для выбора)",
            tip_spider = "Паук: ХП %d/%d, Жить: %.0fс",
            tip_eta = "Прибытие: %02d:%02d (%s)"
        }
    }
}

local localization = qLoc and qLoc.new(translations) or nil
local MenuLib = localization and localization.WrapLibrary and localization.WrapLibrary(Menu) or Menu

local function tr(key, ...)
    local res = nil
    if localization and type(localization.Localize) == "function" then
        res = localization.Localize(key)
    end
    if res == nil or res == key then
        local lang = (localization and type(localization.GetLanguage) == "function" and localization.GetLanguage()) or "ru"
        local dict = translations[lang] or translations.en
        local path = key:gsub("^brood_cb%.", "")
        res = dict.brood_cb and dict.brood_cb[path]
        if res == nil then
            res = translations.en.brood_cb and translations.en.brood_cb[path] or key
        end
    end
    if ... then
        return string.format(res, ...)
    end
    return res
end

-- Constants
local C = {
    HERO_NAME = "npc_dota_hero_broodmother",
    SPIDERLING_NAME = "npc_dota_broodmother_spiderling",
    SPIDERITE_NAME = "npc_dota_broodmother_spiderite",
    ORDER_IDENTIFIER = "brood_camp_blocker",
    CONFIG_NAME = "brood_camp_blocker",
    
    WORLD_MIN = -8800,
    WORLD_MAX = 8800,
    
    MAP_IMAGE_PATHS = {
        "panorama/images/minimap/dotamap_psd.vtex_c",
        "panorama/images/textures/minimap_game_png.vtex_c"
    },
    
    FALLBACK_SVG = [[
<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
  <defs>
    <linearGradient id="g" x1="0" y1="1" x2="1" y2="0">
      <stop offset="0" stop-color="#3d5a37"/>
      <stop offset="0.46" stop-color="#223028"/>
      <stop offset="0.54" stop-color="#2d373a"/>
      <stop offset="1" stop-color="#454c4f"/>
    </linearGradient>
  </defs>
  <rect width="512" height="512" rx="12" fill="#141a18"/>
  <path d="M0 512V214L64 180l70 18 72-46 57 30 64-42 74 16 111-72v428z" fill="url(#g)"/>
  <path d="M-16 352C88 306 120 262 192 248s114 30 184-8 98-81 152-96" fill="none" stroke="#16252f" stroke-width="36" opacity=".95"/>
  <path d="M-16 352C88 306 120 262 192 248s114 30 184-8 98-81 152-96" fill="none" stroke="#2c4d5e" stroke-width="16" opacity=".75"/>
  <path d="M32 470L470 32M22 418L418 22" stroke="#8fa18b" stroke-width="8" opacity=".2"/>
  <circle cx="50" cy="462" r="28" fill="#689f53" opacity=".8"/>
  <circle cx="462" cy="50" r="28" fill="#a8433d" opacity=".8"/>
</svg>
]],
    
    TARGET_ARRIVAL_SECOND = 53.0,
    DEFAULT_SAFETY_MARGIN = 3.0,
    -- NPC.GetMoveSpeed includes the Spin Web bonus.  A route to a remote camp
    -- usually leaves the web, so never plan the whole trip using that value.
    SPIDER_BASE_SPEED = 350,
    SPIDER_SPEED_MARGIN = 1.12,
    SPIDER_TURN_BUFFER = 1.0,
    LIFE_AT_SPAWN_MARGIN = 1.5,
    LATEST_ARRIVAL_MARGIN = 1.5,
    ORDER_REFRESH_INTERVAL = 0.65,
    SPAWN_PASS_SECOND = 0.5,
    
    COLORS = {
        bg = Color(20, 24, 28, 240),
        header = Color(28, 33, 38, 255),
        border = Color(55, 65, 75, 200),
        plate = Color(14, 18, 22, 230),
        accent = Color(235, 75, 60, 255),
        accent_bright = Color(255, 95, 80, 255),
        success = Color(75, 210, 110, 255),
        warning = Color(245, 175, 45, 255),
        info = Color(65, 185, 245, 255),
        text = Color(235, 240, 245, 255),
        text_muted = Color(140, 150, 160, 255),
        
        camp_small = Color(75, 215, 210, 255),
        camp_medium = Color(250, 195, 55, 255),
        camp_large = Color(255, 125, 70, 255),
        camp_ancient = Color(215, 90, 235, 255),
        
        btn_bg = Color(35, 42, 50, 220),
        btn_hover = Color(50, 60, 72, 240),
        btn_border = Color(70, 80, 95, 220),
        
        node_unselected = Color(30, 36, 42, 210),
        node_selected = Color(50, 205, 90, 255),
        node_moving = Color(250, 175, 40, 255),
        node_blocked = Color(70, 220, 120, 255)
    }
}

-- Runtime State
local opt = {}
local ui = {
    font = nil,
    iconFont = nil,
    mapImage = nil,
    fallbackImage = nil,
    
    panelX = nil,
    panelY = nil,
    width = 390,
    height = 500,
    headerHeight = 32,
    
    dragging = false,
    dragOffsetX = 0,
    dragOffsetY = 0,
    
    hoveredCamp = nil,
    mouseHeld = false,
    capturingMouse = false,
    lastClickTime = 0,
    
    buttons = {},
    markers = {}
}

local state = {
    camps = {},
    campsCount = 0,
    campsInitialized = false,
    
    lastMatchTime = -1,
    lastMinuteCycle = -1,
    lastOrderTime = {},
    
    assignedSpiders = {},
    returningSpiders = {},
    dyingSpiders = {},
    spiderFirstSeen = {},
    nextDispatchEvaluation = 0,
    blockerWasEnabled = false,
    heroPosHistory = { pos = nil, time = 0, prevPos = nil, prevTime = 0 },
    
    issuingOrder = false
}

-- Check if spider is currently assigned to block or returning from camp
local function isSpiderLocked(entity)
    if entity == nil then return false end
    return state.assignedSpiders[entity] ~= nil 
        or state.returningSpiders[entity] ~= nil 
        or state.dyingSpiders[entity] ~= nil
end

local function removeManagedSpidersFromSelection(hero)
    local player = Players.GetLocal()
    if player == nil then return end

    local selected = Player.GetSelectedUnits(player)
    if selected == nil or #selected == 0 then return end

    local clean = {}
    local removedLockedSpider = false
    for i = 1, #selected do
        local unit = selected[i]
        if isSpiderLocked(unit) then
            removedLockedSpider = true
        else
            table.insert(clean, unit)
        end
    end
    if not removedLockedSpider then return end

    -- Never leave the player with an empty selection: "select all units" may
    -- temporarily contain only dispatched spiders, in which case control goes
    -- straight back to Broodmother.
    if #clean == 0 and hero ~= nil and Entity.IsAlive(hero) then
        table.insert(clean, hero)
    end

    Player.ClearSelectedUnits(player)
    for i = 1, #clean do
        Player.AddSelectedUnit(player, clean[i])
    end
end

-- Helper Math & Geometry
local function clamp(val, min, max)
    if val < min then return min end
    if val > max then return max end
    return val
end

local function pointInBox(pos, box)
    if pos == nil or box == nil or box.min == nil or box.max == nil then
        return false
    end
    return pos.x >= box.min.x and pos.x <= box.max.x
       and pos.y >= box.min.y and pos.y <= box.max.y
end

local function dist2D(v1, v2)
    local dx = v1.x - v2.x
    local dy = v1.y - v2.y
    return math.sqrt(dx * dx + dy * dy)
end

-- Camp center and bounding box
local function extractCampGeometry(camp)
    local box = Camp.GetCampBox(camp)
    local origin = Entity.GetAbsOrigin(camp)
    local center = nil
    if box ~= nil and box.min ~= nil and box.max ~= nil then
        center = (box.min + box.max) / 2
        if origin ~= nil then
            center.z = origin.z
        end
    else
        center = origin
    end
    return center, box
end

-- Determine Radiant vs Dire camp ownership based on world coordinates
local function getCampTerritory(center)
    local dRadiant = (center.x - (-7200)) ^ 2 + (center.y - (-7200)) ^ 2
    local dDire = (center.x - 7200) ^ 2 + (center.y - 7200) ^ 2
    if dRadiant < dDire then
        return Enum.TeamNum.TEAM_RADIANT, "radiant"
    else
        return Enum.TeamNum.TEAM_DIRE, "dire"
    end
end

-- Camp Color By Type
local function getCampTypeColor(campType)
    if campType == Enum.ECampType.ECampType_SMALL then
        return C.COLORS.camp_small
    elseif campType == Enum.ECampType.ECampType_MEDIUM then
        return C.COLORS.camp_medium
    elseif campType == Enum.ECampType.ECampType_LARGE then
        return C.COLORS.camp_large
    elseif campType == Enum.ECampType.ECampType_ANCIENT then
        return C.COLORS.camp_ancient
    end
    return C.COLORS.camp_medium
end

local function getCampTypeName(campType)
    if campType == Enum.ECampType.ECampType_SMALL then
        return tr("brood_cb.camp_small")
    elseif campType == Enum.ECampType.ECampType_MEDIUM then
        return tr("brood_cb.camp_medium")
    elseif campType == Enum.ECampType.ECampType_LARGE then
        return tr("brood_cb.camp_large")
    elseif campType == Enum.ECampType.ECampType_ANCIENT then
        return tr("brood_cb.camp_ancient")
    end
    return tr("brood_cb.camp_medium")
end

-- Broodmother check
local function isPlayingBroodmother()
    local hero = Heroes.GetLocal()
    if hero == nil then return false, nil end
    local name = NPC.GetUnitName(hero)
    if name == C.HERO_NAME then
        return true, hero
    end
    return false, hero
end

-- Spider remaining lifetime calculation via modifiers
local function getSpiderLifetime(npc, now)
    local exactDieTime = 0
    local fallbackDieTime = 0
    local modifiers = NPC.GetModifiers(npc)
    if modifiers ~= nil then
        for i = 1, #modifiers do
            local mod = modifiers[i]
            if mod ~= nil then
                local dieTime = Modifier.GetDieTime(mod)
                if dieTime ~= nil and dieTime > now then
                    local modName = Modifier.GetName(mod) or ""
                    -- Timed summons are normally killed by modifier_kill.  Do
                    -- not confuse a long buff with the summon lifetime.
                    if modName == "modifier_kill" or modName:find("spiderling_duration", 1, true) then
                        exactDieTime = dieTime
                        break
                    end
                    -- Spiderlings/spiderites live for 40 seconds.  Keep only
                    -- plausible expiry timestamps as a compatibility fallback.
                    if dieTime <= now + 40.5 and dieTime > fallbackDieTime then
                        fallbackDieTime = dieTime
                    end
                end
            end
        end
    end
    if exactDieTime > 0 then
        return math.max(0, exactDieTime - now)
    end
    if fallbackDieTime > 0 then
        return math.max(0, fallbackDieTime - now)
    end

    -- Conservative last resort: time since this entity was first observed.
    -- Returning 999 here used to select old spiders as if they were immortal.
    state.spiderFirstSeen[npc] = state.spiderFirstSeen[npc] or now
    return math.max(0, 40.0 - (now - state.spiderFirstSeen[npc]))
end

local function buildPathDistance(fromPos, toPos)
    return dist2D(fromPos, toPos) * 1.25
end

local function getCampTarget(camp, fromPos)
    return camp.center, buildPathDistance(fromPos, camp.center)
end

local function estimateSpiderTravel(spider, camp, resolveTarget)
    local target, routeDistance = camp.center, nil
    if resolveTarget then
        target, routeDistance = getCampTarget(camp, spider.pos)
    else
        routeDistance = buildPathDistance(spider.pos, target)
    end
    local observedSpeed = spider.speed or C.SPIDER_BASE_SPEED
    local outsideWebSpeed = math.min(C.SPIDER_BASE_SPEED, observedSpeed)
    local effectiveSpeed = math.max(180, outsideWebSpeed / C.SPIDER_SPEED_MARGIN)
    local travelTime = (routeDistance / effectiveSpeed) + C.SPIDER_TURN_BUFFER
    return travelTime, target, routeDistance
end

-- Get all available Broodmother spiders controlled by local player
local function getAvailableSpiders(hero, now)
    local player = Players.GetLocal()
    local playerId = player and Player.GetPlayerID(player) or 0
    local filterMode = opt.spiderType and opt.spiderType:Get() or 0
    
    local spiders = {}
    local npcs = NPCs.GetAll()
    for i = 1, #npcs do
        local npc = npcs[i]
        if npc ~= nil and Entity.IsAlive(npc) and not Entity.IsDormant(npc) and not NPC.IsWaitingToSpawn(npc) then
            if Entity.IsSameTeam(npc, hero) then
                local unitName = NPC.GetUnitName(npc)
                local isLing = (unitName == C.SPIDERLING_NAME)
                local isIte = (unitName == C.SPIDERITE_NAME)
                
                local passType = false
                if filterMode == 0 then
                    passType = isLing or isIte
                elseif filterMode == 1 then
                    passType = isLing
                elseif filterMode == 2 then
                    passType = isIte
                end
                
                if passType then
                    local controllable = false
                    if type(NPC.IsControllableByPlayer) == "function" then
                        controllable = NPC.IsControllableByPlayer(npc, playerId)
                    end
                    if not controllable and type(Entity.IsControllableByPlayer) == "function" then
                        controllable = Entity.IsControllableByPlayer(npc, playerId)
                    end
                    if not controllable and type(Entity.GetOwner) == "function" then
                        local owner = Entity.GetOwner(npc)
                        controllable = (owner == hero or owner == player)
                    end
                    if not controllable then
                        controllable = true
                    end
                    
                    if controllable then
                        local hp = Entity.GetHealth(npc)
                        local maxHp = Entity.GetMaxHealth(npc)
                        local life = getSpiderLifetime(npc, now)
                        table.insert(spiders, {
                            entity = npc,
                            name = unitName,
                            isLing = isLing,
                            hp = hp,
                            maxHp = maxHp,
                            life = life,
                            speed = math.max(100, NPC.GetMoveSpeed(npc)),
                            pos = Entity.GetAbsOrigin(npc)
                        })
                    end
                end
            end
        end
    end
    return spiders
end

-- Find the freshest available spider (with maximum remaining lifetime) that will live past :00.0
local function getBestFreshSpider(hero, now, timeUntil00, camp)
    local all = getAvailableSpiders(hero, now)
    local best = nil
    for i = 1, #all do
        local sp = all[i]
        if not isSpiderLocked(sp.entity) then
            local travelTime, target, routeDistance = 0, camp and camp.center or sp.pos, nil
            if camp ~= nil then
                travelTime, target, routeDistance = estimateSpiderTravel(sp, camp, true)
            end
            local survivesSpawn = sp.life >= (timeUntil00 + C.LIFE_AT_SPAWN_MARGIN)
            local canArrive = travelTime <= math.max(0, timeUntil00 - C.LATEST_ARRIVAL_MARGIN)
            if survivesSpawn and canArrive then
                sp.travelTime = travelTime
                sp.target = target
                if best == nil then
                    best = sp
                elseif sp.travelTime < best.travelTime - 0.35 then
                    best = sp
                elseif math.abs(sp.travelTime - best.travelTime) <= 0.35 and sp.life > best.life + 1.0 then
                    best = sp
                elseif math.abs(sp.travelTime - best.travelTime) <= 0.35 and math.abs(sp.life - best.life) <= 1.0 and sp.isLing and not best.isLing then
                    best = sp
                end
            end
        end
    end
    return best
end

-- Discover and initialize camps
local function initializeCamps(hero)
    local allCamps = Camps.GetAll()
    if allCamps == nil or #allCamps == 0 then
        return false
    end
    
    local heroTeam = Entity.GetTeamNum(hero)
    state.camps = {}
    state.campsCount = #allCamps
    
    for i = 1, #allCamps do
        local campHandle = allCamps[i]
        local center, box = extractCampGeometry(campHandle)
        if center ~= nil then
            local teamOwner, sideStr = getCampTerritory(center)
            local isEnemy = (teamOwner ~= heroTeam)
            local campType = Camp.GetType(campHandle)
            local campId = string.format("camp_%.0f_%.0f", center.x, center.y)
            
            -- Read saved selection or default: enemy camps enabled by default
            local savedEnabled = Config.ReadInt(C.CONFIG_NAME, campId, isEnemy and 1 or 0) == 1
            
            local campData = {
                index = i,
                id = campId,
                handle = campHandle,
                center = center,
                box = box,
                campType = campType,
                typeName = getCampTypeName(campType),
                team = teamOwner,
                side = sideStr,
                isEnemy = isEnemy,
                enabled = savedEnabled,
                
                -- State machine
                state = "idle",
                assignedSpiders = {},
                assignedSpider = nil,
                assignedSpiderData = nil,
                spiderProgress = {},
                target = center,
                eta = 0,
                lastBlockedMinute = -1,
                lastOrderTime = 0
            }
            table.insert(state.camps, campData)
        end
    end
    
    state.campsInitialized = true
    return true
end

-- Convert 3D world coords to 2D panel minimap coords
local function worldToMapCoords(worldX, worldY, mapX, mapY, mapSize)
    local span = C.WORLD_MAX - C.WORLD_MIN
    local normX = clamp((worldX - C.WORLD_MIN) / span, 0, 1)
    local normY = clamp(1.0 - (worldY - C.WORLD_MIN) / span, 0, 1)
    
    local inset = math.max(2, math.floor(mapSize * 0.015))
    local usableSize = mapSize - inset * 2
    return mapX + inset + normX * usableSize,
           mapY + inset + normY * usableSize
end

-- Setup Umbrella Menu
local function initializeMenu()
    if opt.ready then return true end
    
    local f_log = nil
    pcall(function() f_log = io.open("c:\\Umbrella\\scripts\\brood_debug.log", "a") end)
    local function dlog(msg)
        if f_log then pcall(function() f_log:write(tostring(msg) .. "\n") f_log:flush() end) end
        if Log and Log.Write then pcall(Log.Write, "[brood_cb] " .. tostring(msg)) end
    end
    
    dlog("--- initializeMenu called ---")
    
    -- Try finding Broodmother hero tab in Umbrella
    local broodTab = nil
    local ok1, res1 = pcall(Menu.Find, "Heroes", "Hero List", "Broodmother")
    if ok1 and res1 ~= nil then
        broodTab = res1
        dlog("Found Broodmother via ('Heroes', 'Hero List', 'Broodmother')")
    else
        local ok2, res2 = pcall(Menu.Find, "Герои", "Список героев", "Broodmother")
        if ok2 and res2 ~= nil then
            broodTab = res2
            dlog("Found Broodmother via ('Герои', 'Список героев', 'Broodmother')")
        else
            dlog("Menu.Find for Broodmother failed. res1=" .. tostring(res1) .. ", res2=" .. tostring(res2))
        end
    end
    
    local campBlockerTab = nil
    if broodTab ~= nil then
        -- Create a third tab named "Авто-блок кемпов" inside the Broodmother hero page
        local okTab, newTab = pcall(function() return broodTab:Create("Авто-блок кемпов") end)
        if okTab and newTab ~= nil then
            campBlockerTab = newTab
            dlog("SUCCESS: Created tab 'Авто-блок кемпов' inside Broodmother hero page!")
            if type(campBlockerTab.Icon) == "function" then
                pcall(campBlockerTab.Icon, campBlockerTab, "\u{f188}")
            end
        else
            dlog("Failed to create tab on broodTab: " .. tostring(newTab))
        end
    end
    
    -- Fallback: If cannot attach directly to Broodmother tab, create a separate entry in Hero List
    if campBlockerTab == nil then
        dlog("Attempting fallback: Menu.Create in Hero List...")
        local okFb, fbTab = pcall(Menu.Create, "Heroes", "Hero List", "Broodmother (Авто-блок)")
        if okFb and fbTab ~= nil then
            dlog("Created fallback Hero List entry: 'Broodmother (Авто-блок)'")
            local okSub, sub = pcall(function() return fbTab:Create("Авто-блок кемпов") end)
            campBlockerTab = (okSub and sub ~= nil) and sub or fbTab
        else
            -- Russian path fallback
            local okFb2, fbTab2 = pcall(Menu.Create, "Герои", "Список героев", "Broodmother (Авто-блок)")
            if okFb2 and fbTab2 ~= nil then
                dlog("Created fallback Hero List entry via Russian path")
                local okSub, sub = pcall(function() return fbTab2:Create("Авто-блок кемпов") end)
                campBlockerTab = (okSub and sub ~= nil) and sub or fbTab2
            end
        end
    end
    
    if campBlockerTab == nil then
        dlog("CRITICAL ERROR: Failed to create or find any menu root!")
        if f_log then f_log:close() end
        return false
    end
    
    -- Create groups inside the tab
    local mainGroup = campBlockerTab:Create("Авто-блок кемпов", Enum.GroupSide.Left)
    local mapGroup = campBlockerTab:Create("Карта и кемпы", Enum.GroupSide.Right)
    local espGroup = campBlockerTab:Create("ESP в мире", Enum.GroupSide.Left)
    
    -- Main options
    opt.enabled = mainGroup:Switch("Включить авто-блок", true, "\u{f011}")
    opt.enabled:ToolTip("Каждую минуту к ровно :00 отправляет паучков на выбранные кемпы для блокировки спавна крипов.")
    
    opt.toggleBind = mainGroup:Bind("Клавиша вкл/выкл", Enum.ButtonCode.BUTTON_CODE_INVALID, "\u{f11c}")
    opt.toggleBind:ToolTip("Клавиша для быстрого включения или отключения работы скрипта.")
    
    opt.spiderType = mainGroup:Combo("Тип пауков", {
        "Все пауки",
        "Только Spiderlings",
        "Только Spiderites"
    }, 0)
    opt.spiderType:ToolTip("Каких пауков отправлять на блокировку кемпов.")
    
    opt.returnToHero = mainGroup:Switch("Возврат после блока", true, "\u{f060}")
    opt.returnToHero:ToolTip("Сразу после блокировки кемпа отправляет паука обратно к Брудмазер.")
    
    opt.arrivalSecond = mainGroup:Slider("Тайминг прибытия", 48, 56, 53, "%d сек")
    opt.arrivalSecond:ToolTip("Секунда минуты, к которой паучок уже должен стоять внутри кемпа (по умолчанию 53 сек, чтобы к 55 сек они гарантированно заняли позиции).")
    
    opt.safetyMargin = mainGroup:Slider("Запас времени (буфер)", 1, 5, 3, "%d сек")
    opt.safetyMargin:ToolTip("Запас времени в секундах (1-5 сек), чтобы паучки выходили заранее и гарантированно успевали добежать до кемпа.")
    
    opt.doubleSpiders = mainGroup:Switch("Дублировать на дальние кемпы", true, "\u{f0c0}")
    opt.doubleSpiders:ToolTip("Отправлять сразу 2 паучка на дальние кемпы или при риске не успеть/погибнуть.")
    
    -- Map Window options
    opt.mapKey = mapGroup:Bind("Клавиша карты", Enum.ButtonCode.KEY_F6, "\u{f279}")
    opt.mapKey:ToolTip("Клавиша для открытия/закрытия интерактивной карты выбора кемпов.")
    
    opt.showMap = mapGroup:Switch("Показать карту", true, "\u{f279}")
    opt.showMap:ToolTip("Отображает окно с картой, где кликом выбираются кемпы для блокировки.")
    
    opt.panelScale = mapGroup:Slider("Масштаб карты", 70, 150, 100, "%d%%")
    opt.panelScale:ToolTip("Размер интерактивного окна карты.")
    
    -- Visuals / ESP options
    opt.worldEsp = espGroup:Switch("ESP кемпов", true, "\u{f06e}")
    opt.worldEsp:ToolTip("Рисует метки и таймеры над выбранными кемпами прямо в игре.")
    
    opt.spiderTracers = espGroup:Switch("Линии к кемпам", true, "\u{f1fe}")
    opt.spiderTracers:ToolTip("Рисует линии от назначенных пауков к целевым кемпам.")
    
    opt.ready = true
    dlog("Menu initialized successfully! opt.ready is TRUE")
    if f_log then f_log:close() end
    return true
end

-- Try initial load immediately
pcall(initializeMenu)

-- Initialize UI assets
local function initializeUiAssets()
    ui.font = Render.LoadFont("MuseoSansEx", Enum.FontCreate.FONTFLAG_ANTIALIAS, 500)
    ui.iconFont = Render.LoadFont("FontAwesomeEx", Enum.FontCreate.FONTFLAG_ANTIALIAS, 400)
    
    for i = 1, #C.MAP_IMAGE_PATHS do
        local ok, handle = pcall(Render.LoadImage, C.MAP_IMAGE_PATHS[i])
        if ok and handle ~= nil then
            local okSize, size = pcall(Render.ImageSize, handle)
            if okSize and size ~= nil and size.x > 8 and size.y > 8 then
                ui.mapImage = handle
                break
            end
        end
    end
    
    local okSvg, svgHandle = pcall(
        Render.LoadSvgString,
        C.FALLBACK_SVG,
        Vec2(512, 512),
        "brood_camp_blocker_map_fallback"
    )
    if okSvg and svgHandle ~= nil then
        ui.fallbackImage = svgHandle
    end
end

local function releaseAllManagedSpiders()
    state.assignedSpiders = {}
    state.returningSpiders = {}
    state.dyingSpiders = {}
    for i = 1, #state.camps do
        local camp = state.camps[i]
        camp.assignedSpiders = {}
        camp.assignedSpider = nil
        camp.assignedSpiderData = nil
        camp.spiderProgress = {}
        camp.state = "idle"
    end
end

-- Use unit-bound APIs for automation. Unlike a generic selected-units order,
-- these calls can never spill onto Broodmother even if the player's selection
-- changes during the same frame.
local function orderManagedSpiderMove(spider, position)
    if spider == nil or position == nil then return false end
    state.issuingOrder = true
    local ok = pcall(
        NPC.MoveTo,
        spider,
        position,
        false,
        false,
        nil,
        true,
        C.ORDER_IDENTIFIER,
        false
    )
    state.issuingOrder = false
    return ok
end

-- Core Automation Engine
local function executeCampBlockingLogic(hero, now)
    local startTime = GameRules.GetGameStartTime()
    if startTime <= 0 then return end
    
    local elapsed = now - startTime
    if elapsed < 0 then return end
    
    local gameMinute = math.floor(elapsed / 60)
    local gameSecond = elapsed % 60
    local timeUntil00 = 60.0 - gameSecond
    
    local player = Players.GetLocal()
    if player == nil then return end

    -- A camp can be deselected while spiders are already on the way. Release
    -- them immediately so stale assignments do not consume the pool later.
    for i = 1, #state.camps do
        local camp = state.camps[i]
        if not camp.enabled and ((camp.assignedSpiders and #camp.assignedSpiders > 0) or camp.assignedSpider ~= nil) then
            local assigned = camp.assignedSpiders or { camp.assignedSpider }
            for s = 1, #assigned do
                state.assignedSpiders[assigned[s]] = nil
            end
            camp.assignedSpiders = {}
            camp.assignedSpider = nil
            camp.assignedSpiderData = nil
            camp.spiderProgress = {}
            camp.state = "idle"
        end
    end
    
    -- Track hero position to determine movement direction and velocity relative to camps
    local currentHeroPos = Entity.GetAbsOrigin(hero)
    if state.heroPosHistory.pos == nil then
        state.heroPosHistory.pos = currentHeroPos
        state.heroPosHistory.time = now
    else
        local dt = now - state.heroPosHistory.time
        if dt >= 0.20 then
            state.heroPosHistory.prevPos = state.heroPosHistory.pos
            state.heroPosHistory.prevTime = state.heroPosHistory.time
            state.heroPosHistory.pos = currentHeroPos
            state.heroPosHistory.time = now
        end
    end
    
    -- After the :00 spawn check, always prepare every camp for the NEXT
    -- minute. lastBlockedMinute is only a record of the completed check; it
    -- must never prevent scheduling the following cycle.
    if gameSecond >= 2.0 then
        if state.lastMinuteCycle ~= gameMinute then
            state.lastMinuteCycle = gameMinute
            for i = 1, #state.camps do
                local c = state.camps[i]
                c.state = "idle"
                if c.assignedSpiders ~= nil then
                    for sIdx = 1, #c.assignedSpiders do
                        state.assignedSpiders[c.assignedSpiders[sIdx]] = nil
                    end
                end
                if c.assignedSpider ~= nil then
                    state.assignedSpiders[c.assignedSpider] = nil
                end
                c.assignedSpiders = {}
                c.assignedSpider = nil
                c.assignedSpiderData = nil
                c.spiderProgress = {}
            end
        end
    end
    
    -- Post-spawn block trigger & retreat phase: from :00.2 to :01.5
    if gameSecond >= 0.2 and gameSecond <= 1.5 then
        for i = 1, #state.camps do
            local c = state.camps[i]
            if c.enabled and c.lastBlockedMinute ~= gameMinute then
                local spList = c.assignedSpiders or (c.assignedSpider and { c.assignedSpider } or {})
                local blocked = false
                local aliveSpiders = {}
                
                for sIdx = 1, #spList do
                    local spEnt = spList[sIdx]
                    if spEnt ~= nil and Entity.IsAlive(spEnt) and not Entity.IsDormant(spEnt) then
                        table.insert(aliveSpiders, spEnt)
                        local sPos = Entity.GetAbsOrigin(spEnt)
                        local inBox = (c.box ~= nil and pointInBox(sPos, c.box)) or (dist2D(sPos, c.center) < 500)
                        if inBox or c.state == "at_camp" then
                            blocked = true
                        end
                    end
                end
                
                if blocked then
                    -- Successful block!
                    c.lastBlockedMinute = gameMinute
                    c.state = "blocked"
                    
                    -- Retreat orders back to Broodmother
                    for sIdx = 1, #aliveSpiders do
                        local spEnt = aliveSpiders[sIdx]
                        if opt.returnToHero:Get() then
                            state.returningSpiders[spEnt] = { lastOrderTime = now }
                            orderManagedSpiderMove(spEnt, Entity.GetAbsOrigin(hero))
                        else
                            state.assignedSpiders[spEnt] = nil
                        end
                    end
                    c.assignedSpiders = {}
                    c.assignedSpider = nil
                    c.assignedSpiderData = nil
                    c.spiderProgress = {}
                end
            end
        end
    end
    
    -- Guide returning spiders back to Broodmother until they arrive (dist <= 280)
    for spiderEntity, rData in pairs(state.returningSpiders) do
        if not Entity.IsAlive(spiderEntity) or Entity.IsDormant(spiderEntity) then
            state.returningSpiders[spiderEntity] = nil
            state.assignedSpiders[spiderEntity] = nil
        else
            local sPos = Entity.GetAbsOrigin(spiderEntity)
            local hPos = Entity.GetAbsOrigin(hero)
            local dHero = dist2D(sPos, hPos)
            
            if dHero <= 280 then
                -- Arrived back near Broodmother: release spider back to player control!
                state.returningSpiders[spiderEntity] = nil
                state.assignedSpiders[spiderEntity] = nil
            else
                -- Continuously refresh move order to follow Broodmother if she moves
                if now - (rData.lastOrderTime or 0) > 1.2 then
                    rData.lastOrderTime = now
                    orderManagedSpiderMove(spiderEntity, hPos)
                end
            end
        end
    end
    
    -- Expiring spiders are released without any further automated orders.
    for spiderEntity, dData in pairs(state.dyingSpiders) do
        if not Entity.IsAlive(spiderEntity) or Entity.IsDormant(spiderEntity) then
            state.dyingSpiders[spiderEntity] = nil
        end
    end
    
    -- Ongoing camp management & holding
    for i = 1, #state.camps do
        local c = state.camps[i]
        if c.enabled then
            local spList = c.assignedSpiders or (c.assignedSpider and { c.assignedSpider } or {})
            if #spList > 0 then
                local aliveList = {}
                for sIdx = 1, #spList do
                    local spEnt = spList[sIdx]
                    if spEnt ~= nil and Entity.IsAlive(spEnt) and not Entity.IsDormant(spEnt) then
                        table.insert(aliveList, spEnt)
                    else
                        state.assignedSpiders[spEnt] = nil
                        c.spiderProgress[spEnt] = nil
                    end
                end
                
                -- Check if any assigned spider will survive until :00 (creep spawn)
                local hasSurviving = false
                for sIdx = 1, #aliveList do
                    local spLife = getSpiderLifetime(aliveList[sIdx], now)
                    if spLife >= (timeUntil00 + C.LIFE_AT_SPAWN_MARGIN) then
                        hasSurviving = true
                        break
                    end
                end
                
                -- If NO assigned spider will survive until :00 (soon to die), replace with the newest/freshest spider!
                if #aliveList > 0 and not hasSurviving and timeUntil00 > 3.0 then
                    local freshSp = getBestFreshSpider(hero, now, timeUntil00, c)
                    if freshSp ~= nil then
                        -- Expiring spiders are released and receive no more orders.
                        for sIdx = 1, #aliveList do
                            local expEnt = aliveList[sIdx]
                            state.assignedSpiders[expEnt] = nil
                            c.spiderProgress[expEnt] = nil
                            state.dyingSpiders[expEnt] = { lastOrderTime = now }
                        end
                        
                        -- Fresh replacement spider takes over the camp
                        aliveList = { freshSp.entity }
                        c.assignedSpiderData = freshSp
                        c.target = freshSp.target or c.center
                        c.spiderProgress[freshSp.entity] = {
                            target = c.target,
                            finalTarget = c.target,
                            lastDistance = dist2D(freshSp.pos, c.target),
                            lastProgressTime = now,
                            lastOrderTime = now
                        }
                        state.assignedSpiders[freshSp.entity] = c
                        
                        -- Dispatch replacement spider immediately to camp center
                        orderManagedSpiderMove(freshSp.entity, c.target)
                        c.state = "moving"
                        c.lastOrderTime = now
                    end
                end
                
                c.assignedSpiders = aliveList
                c.assignedSpider = aliveList[1]
                
                if #aliveList == 0 then
                    -- All assigned spiders died; reset camp to re-assign if time allows
                    c.assignedSpider = nil
                    c.assignedSpiderData = nil
                    c.spiderProgress = {}
                    c.state = "idle"
                else
                    local anyInBox = false
                    for sIdx = 1, #aliveList do
                        local spEnt = aliveList[sIdx]
                        local sPos = Entity.GetAbsOrigin(spEnt)
                        local progress = c.spiderProgress[spEnt]
                        if progress == nil then
                            local finalTarget = c.target or c.center
                            local target = finalTarget
                            progress = {
                                target = target,
                                finalTarget = finalTarget,
                                lastDistance = dist2D(sPos, target),
                                lastProgressTime = now,
                                lastOrderTime = 0
                            }
                            c.spiderProgress[spEnt] = progress
                        end
                        local target = progress.target or c.target or c.center
                        local distance = dist2D(sPos, target)
                        local inBox = (c.box ~= nil and pointInBox(sPos, c.box)) or (c.box == nil and dist2D(sPos, c.center) < 300)

                        if inBox then
                            anyInBox = true
                            progress.lastDistance = 0
                            progress.lastProgressTime = now
                        else
                            if distance < (progress.lastDistance or math.huge) - 35 then
                                progress.lastDistance = distance
                                progress.lastProgressTime = now
                            end

                            if now - (progress.lastOrderTime or 0) > C.ORDER_REFRESH_INTERVAL then
                                orderManagedSpiderMove(spEnt, target)
                                progress.lastOrderTime = now
                            end
                        end
                    end
                    c.state = anyInBox and "at_camp" or "moving"
                end
            end
        end
    end
    
    -- Dispatch phase for unassigned enabled camps
    local allSpiders = getAvailableSpiders(hero, now)
    local unassignedCamps = {}
    for i = 1, #state.camps do
        local c = state.camps[i]
        local hasSpiders = (c.assignedSpiders ~= nil and #c.assignedSpiders > 0) or (c.assignedSpider ~= nil)
        if c.enabled and not hasSpiders then
            table.insert(unassignedCamps, c)
        end
    end
    
    if #unassignedCamps > 0 and #allSpiders > 0 and now >= (state.nextDispatchEvaluation or 0) then
        state.nextDispatchEvaluation = now + 0.25
        -- Find free candidates that aren't already booked or returning
        local freeSpiders = {}
        for s = 1, #allSpiders do
            local sp = allSpiders[s]
            if not isSpiderLocked(sp.entity) then
                table.insert(freeSpiders, sp)
            end
        end
        
        -- Sort unassigned camps: FURTHEST camp first so the furthest camp gets the longest-living spiders
        local heroPos = Entity.GetAbsOrigin(hero)
        table.sort(unassignedCamps, function(a, b)
            return dist2D(heroPos, a.center) > dist2D(heroPos, b.center)
        end)
        
        local targetArrival = (opt.arrivalSecond and opt.arrivalSecond:Get()) or C.TARGET_ARRIVAL_SECOND
        local safetyMargin = (opt.safetyMargin and opt.safetyMargin:Get()) or C.DEFAULT_SAFETY_MARGIN
        
        for i = 1, #unassignedCamps do
            local camp = unassignedCamps[i]
            if #freeSpiders == 0 then break end
            
            -- Detect if hero (and the spiders moving with her) is moving away from this camp
            local isMovingAway = false
            local distRate = 0
            if state.heroPosHistory.prevPos ~= nil and state.heroPosHistory.prevTime > 0 then
                local dt = state.heroPosHistory.time - state.heroPosHistory.prevTime
                if dt > 0.05 then
                    local prevD = dist2D(state.heroPosHistory.prevPos, camp.center)
                    local currD = dist2D(state.heroPosHistory.pos, camp.center)
                    distRate = (currD - prevD) / dt
                    if distRate > 50 then
                        isMovingAway = true
                    end
                end
            end
            
            -- Pick a spider for this camp, not merely the first spider in a
            -- global list.  It must both reach the box and still be alive at
            -- the actual neutral-spawn check.
            local candidate, candidateIndex = nil, nil
            for s = 1, #freeSpiders do
                local sp = freeSpiders[s]
                local travelTime = estimateSpiderTravel(sp, camp, false)
                local departureSecond = targetArrival - travelTime - safetyMargin
                if isMovingAway and distRate > 50 then
                    departureSecond = departureSecond - math.min(12.0, (distRate / C.SPIDER_BASE_SPEED) * 3.5)
                end
                departureSecond = math.max(5.0, departureSecond)

                local survivesSpawn = sp.life >= (timeUntil00 + C.LIFE_AT_SPAWN_MARGIN)
                local canArrive = travelTime <= math.max(0, timeUntil00 - C.LATEST_ARRIVAL_MARGIN)
                local shouldDepart = gameSecond >= departureSecond
                if survivesSpawn and canArrive and shouldDepart then
                    sp.travelTime = travelTime
                    if candidate == nil
                        or sp.travelTime < candidate.travelTime - 0.35
                        or (math.abs(sp.travelTime - candidate.travelTime) <= 0.35 and sp.life > candidate.life)
                    then
                        candidate, candidateIndex = sp, s
                    end
                end
            end

            if candidate ~= nil then
                -- Resolve a traversable point safely inside the box only for
                -- spiders that are actually going to be dispatched.
                candidate.travelTime, candidate.target, candidate.routeDistance = estimateSpiderTravel(candidate, camp, true)

                -- Determine if we should send 2 spiders:
                -- Distant camps, long travel times, or tight lifetimes get 2 spiders for reliability!
                local allowDouble = (opt.doubleSpiders == nil or opt.doubleSpiders:Get())
                local isFarOrRisky = (candidate.routeDistance > 2600) or (candidate.travelTime >= 10.0)
                    or (candidate.life < timeUntil00 + 7.0) or (candidate.hp < candidate.maxHp * 0.65)
                
                local spidersToAssign = {}
                table.insert(spidersToAssign, candidate)
                table.remove(freeSpiders, candidateIndex)
                
                -- Never spend the backup spider if that would leave a later
                -- selected camp without even one blocker.
                local campsStillWaiting = #unassignedCamps - i
                if allowDouble and isFarOrRisky and #freeSpiders > campsStillWaiting then
                    local secondCandidate, secondIndex = nil, nil
                    for s = 1, #freeSpiders do
                        local sp = freeSpiders[s]
                        local travelTime = estimateSpiderTravel(sp, camp, false)
                        if sp.life >= (timeUntil00 + C.LIFE_AT_SPAWN_MARGIN)
                            and travelTime <= math.max(0, timeUntil00 - C.LATEST_ARRIVAL_MARGIN)
                            and (secondCandidate == nil or travelTime < secondCandidate.travelTime)
                        then
                            sp.travelTime = travelTime
                            secondCandidate, secondIndex = sp, s
                        end
                    end
                    if secondCandidate ~= nil then
                        secondCandidate.travelTime, secondCandidate.target, secondCandidate.routeDistance = estimateSpiderTravel(secondCandidate, camp, true)
                        table.insert(spidersToAssign, secondCandidate)
                        table.remove(freeSpiders, secondIndex)
                    end
                end
                
                camp.assignedSpiders = {}
                camp.spiderProgress = {}
                for sIdx = 1, #spidersToAssign do
                    local spObj = spidersToAssign[sIdx]
                    table.insert(camp.assignedSpiders, spObj.entity)
                    state.assignedSpiders[spObj.entity] = camp
                    camp.spiderProgress[spObj.entity] = {
                        target = spObj.target,
                        finalTarget = spObj.target,
                        lastDistance = dist2D(spObj.pos, spObj.target),
                        lastProgressTime = now,
                        lastOrderTime = now
                    }
                    
                    orderManagedSpiderMove(spObj.entity, spObj.target)
                end
                
                camp.assignedSpider = spidersToAssign[1].entity
                camp.assignedSpiderData = spidersToAssign[1]
                camp.target = spidersToAssign[1].target
                camp.state = "moving"
                camp.eta = now + spidersToAssign[1].travelTime
                camp.lastOrderTime = now
            end
        end
    end
end

-- World ESP rendering
local function drawWorldEsp(hero, now)
    if not opt.worldEsp:Get() then return end
    
    local startTime = GameRules.GetGameStartTime()
    local gameSecond = 0
    if startTime > 0 and now >= startTime then
        gameSecond = (now - startTime) % 60
    end
    local timeUntil00 = math.max(0, math.floor(60.0 - gameSecond))
    
    for i = 1, #state.camps do
        local camp = state.camps[i]
        if camp.enabled then
            local center = camp.center
            local screenPos, onScreen = Render.WorldToScreen(center)
            
            if onScreen and screenPos ~= nil then
                local color = getCampTypeColor(camp.campType)
                local radius = (camp.state == "blocked") and 16 or 12
                
                -- Ground circle representation
                Render.FilledCircle(screenPos, radius + 4, Color(10, 15, 20, 180))
                Render.Circle(screenPos, radius + 4, color, 2)
                
                -- Status text badge
                local spList = camp.assignedSpiders or (camp.assignedSpider and { camp.assignedSpider } or {})
                local tag = string.format("%s (%ds)", camp.typeName, timeUntil00)
                if camp.state == "at_camp" then
                    tag = #spList > 1 and string.format("BLOCKING! [00] (x%d)", #spList) or "BLOCKING! [00]"
                elseif camp.state == "blocked" then
                    tag = "BLOCKED!"
                elseif camp.state == "moving" and #spList > 0 then
                    tag = #spList > 1 and string.format("SPIDERS ETA (x%d)", #spList) or "SPIDER ETA"
                end
                
                local tagSize = Render.TextSize(ui.font, 12, tag)
                local tagPos = Vec2(screenPos.x - tagSize.x * 0.5, screenPos.y - tagSize.y - radius - 6)
                
                Render.FilledRect(
                    Vec2(tagPos.x - 4, tagPos.y - 2),
                    Vec2(tagPos.x + tagSize.x + 4, tagPos.y + tagSize.y + 2),
                    Color(15, 20, 25, 220),
                    4
                )
                Render.Text(ui.font, 12, tag, tagPos, color)
            end
            
            -- Spider Tracer line
            if opt.spiderTracers:Get() then
                local spList = camp.assignedSpiders or (camp.assignedSpider and { camp.assignedSpider } or {})
                for sIdx = 1, #spList do
                    local spEnt = spList[sIdx]
                    if spEnt ~= nil and Entity.IsAlive(spEnt) then
                        local sPos = Entity.GetAbsOrigin(spEnt)
                        local screenSpider, spiderVisible = Render.WorldToScreen(sPos)
                        if onScreen and spiderVisible and screenPos ~= nil and screenSpider ~= nil then
                            Render.Line(screenSpider, screenPos, Color(255, 200, 60, 200), 1.5)
                        end
                    end
                end
            end
        end
    end
end

-- Interactive Map Panel UI
local function drawMapPanel(hero, now)
    if not opt.showMap:Get() or ui.font == nil then
        ui.dragging = false
        ui.hoveredCamp = nil
        return
    end
    
    local screen = Render.ScreenSize()
    local scale = (opt.panelScale and opt.panelScale:Get() or 100) / 100.0
    
    local panelW = math.floor(390 * scale)
    local panelH = math.floor(520 * scale)
    local headerH = math.floor(32 * scale)
    local padding = math.floor(10 * scale)
    local mapSize = panelW - padding * 2
    local footerH = math.floor(44 * scale)
    
    ui.width = panelW
    ui.height = panelH
    ui.headerHeight = headerH
    
    if ui.panelX == nil or ui.panelY == nil then
        ui.panelX = Config.ReadInt(C.CONFIG_NAME, "panel_x", -1)
        ui.panelY = Config.ReadInt(C.CONFIG_NAME, "panel_y", -1)
        if ui.panelX < 0 or ui.panelY < 0 then
            ui.panelX = math.floor(screen.x * 0.02)
            ui.panelY = math.floor(screen.y * 0.10)
        end
    end
    
    local cursorX, cursorY = Input.GetCursorPos()
    if ui.dragging then
        if Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE1, true) then
            ui.panelX = clamp(cursorX - ui.dragOffsetX, 0, screen.x - panelW)
            ui.panelY = clamp(cursorY - ui.dragOffsetY, 0, screen.y - panelH)
        else
            ui.dragging = false
        end
    end
    
    local x = ui.panelX
    local y = ui.panelY
    
    -- Panel Body with shadow and blur
    Render.Shadow(Vec2(x, y), Vec2(x + panelW, y + panelH), Color(0, 0, 0, 190), 16, 8)
    Render.FilledRect(Vec2(x, y), Vec2(x + panelW, y + panelH), C.COLORS.bg, 8)
    Render.Rect(Vec2(x, y), Vec2(x + panelW, y + panelH), C.COLORS.border, 8, Enum.DrawFlags.None, 1)
    
    -- Header Bar
    Render.FilledRect(Vec2(x, y), Vec2(x + panelW, y + headerH), C.COLORS.header, 8)
    Render.Line(Vec2(x, y + headerH), Vec2(x + panelW, y + headerH), C.COLORS.border, 1)
    
    -- Header Title & Icon
    local spiderGlyph = "\u{f717}"
    Render.Text(ui.iconFont, math.floor(14 * scale), spiderGlyph, Vec2(x + 10 * scale, y + 8 * scale), C.COLORS.accent)
    Render.Text(ui.font, math.floor(12 * scale), tr("brood_cb.panel_title"), Vec2(x + 32 * scale, y + 8 * scale), C.COLORS.text)
    
    -- Status Badge in Header
    local isBrood, localHero = isPlayingBroodmother()
    local statusText = isBrood and (opt.enabled:Get() and tr("brood_cb.status_active") or tr("brood_cb.status_disabled")) or tr("brood_cb.status_not_brood")
    local statusColor = isBrood and (opt.enabled:Get() and C.COLORS.success or C.COLORS.warning) or C.COLORS.accent
    local statusSize = Render.TextSize(ui.font, math.floor(10 * scale), statusText)
    local statusX = x + panelW - statusSize.x - 36 * scale
    Render.FilledRect(Vec2(statusX - 4, y + 6 * scale), Vec2(statusX + statusSize.x + 4, y + headerH - 6 * scale), Color(statusColor.r, statusColor.g, statusColor.b, 40), 4)
    Render.Text(ui.font, math.floor(10 * scale), statusText, Vec2(statusX, y + 8 * scale), statusColor)
    
    -- Close button (X)
    local closeX = x + panelW - 22 * scale
    local closeY = y + 8 * scale
    local closeHover = cursorX >= closeX - 4 and cursorX <= closeX + 16 and cursorY >= y and cursorY <= y + headerH
    Render.Text(ui.iconFont, math.floor(12 * scale), "\u{f00d}", Vec2(closeX, closeY), closeHover and C.COLORS.accent_bright or C.COLORS.text_muted)
    ui.closeBounds = { x = closeX - 4, y = y, w = 24 * scale, h = headerH }
    
    -- Toolbar Buttons: [Enemy] [Ancients] [Clear All] [Select All]
    local btnY = y + headerH + 6 * scale
    local btnH = math.floor(22 * scale)
    local btnW = math.floor((panelW - padding * 2 - 12 * scale) / 4)
    ui.buttons = {
        { id = "enemy", text = tr("brood_cb.btn_enemy"), x = x + padding, y = btnY, w = btnW, h = btnH },
        { id = "ancients", text = tr("brood_cb.btn_ancients"), x = x + padding + btnW + 4 * scale, y = btnY, w = btnW, h = btnH },
        { id = "all", text = tr("brood_cb.btn_all"), x = x + padding + (btnW + 4 * scale) * 2, y = btnY, w = btnW, h = btnH },
        { id = "clear", text = tr("brood_cb.btn_clear"), x = x + padding + (btnW + 4 * scale) * 3, y = btnY, w = btnW, h = btnH }
    }
    
    for b = 1, #ui.buttons do
        local btn = ui.buttons[b]
        local isHover = cursorX >= btn.x and cursorX <= btn.x + btn.w and cursorY >= btn.y and cursorY <= btn.y + btn.h
        Render.FilledRect(Vec2(btn.x, btn.y), Vec2(btn.x + btn.w, btn.y + btn.h), isHover and C.COLORS.btn_hover or C.COLORS.btn_bg, 4)
        Render.Rect(Vec2(btn.x, btn.y), Vec2(btn.x + btn.w, btn.y + btn.h), C.COLORS.btn_border, 4, Enum.DrawFlags.None, 1)
        
        local txtSize = Render.TextSize(ui.font, math.floor(9 * scale), btn.text)
        local tx = btn.x + (btn.w - txtSize.x) * 0.5
        local ty = btn.y + (btn.h - txtSize.y) * 0.5
        Render.Text(ui.font, math.floor(9 * scale), btn.text, Vec2(tx, ty), isHover and C.COLORS.text or C.COLORS.text_muted)
    end
    
    -- Minimap Display Box
    local mapX = x + padding
    local mapY = btnY + btnH + 8 * scale
    Render.FilledRect(Vec2(mapX, mapY), Vec2(mapX + mapSize, mapY + mapSize), C.COLORS.plate, 6)
    
    local mapHandle = ui.mapImage or ui.fallbackImage
    if mapHandle ~= nil then
        Render.Image(mapHandle, Vec2(mapX, mapY), Vec2(mapSize, mapSize), Color(255, 255, 255, 240), 6)
    end
    Render.Rect(Vec2(mapX, mapY), Vec2(mapX + mapSize, mapY + mapSize), C.COLORS.border, 6, Enum.DrawFlags.None, 1)
    
    -- Draw Camp Markers on Map
    ui.markers = {}
    ui.hoveredCamp = nil
    local nodeRadius = math.max(6, math.floor(9 * scale))
    
    for i = 1, #state.camps do
        local camp = state.camps[i]
        local mx, my = worldToMapCoords(camp.center.x, camp.center.y, mapX, mapY, mapSize)
        local center2D = Vec2(mx, my)
        
        local typeColor = getCampTypeColor(camp.campType)
        local isHit = (cursorX - mx) ^ 2 + (cursorY - my) ^ 2 <= (nodeRadius + 4) ^ 2
        if isHit then
            ui.hoveredCamp = camp
        end
        
        -- Base node circle
        if camp.enabled then
            -- Selected: Bright filled circle with type accent & glowing ring
            local ringColor = camp.state == "at_camp" and C.COLORS.node_blocked or (camp.state == "moving" and C.COLORS.node_moving or typeColor)
            Render.FilledCircle(center2D, nodeRadius + (isHit and 2 or 0), ringColor)
            Render.Circle(center2D, nodeRadius + (isHit and 4 or 2), C.COLORS.text, 1.5)
            
            -- Checkmark inside
            local chkSize = Render.TextSize(ui.iconFont, math.floor(7 * scale), "\u{f00c}")
            Render.Text(ui.iconFont, math.floor(7 * scale), "\u{f00c}", Vec2(mx - chkSize.x * 0.5, my - chkSize.y * 0.5), Color(20, 24, 28, 255))
        else
            -- Unselected: Dark disc with colored rim
            Render.FilledCircle(center2D, nodeRadius - 1, C.COLORS.node_unselected)
            Render.Circle(center2D, nodeRadius - 1, typeColor, 1.2)
        end
        
        table.insert(ui.markers, {
            camp = camp,
            x = mx,
            y = my,
            radius = nodeRadius + 4
        })
    end
    
    -- Footer Status Bar
    local footerY = mapY + mapSize + 8 * scale
    local startTime = GameRules.GetGameStartTime()
    local gameSec = 0
    local gameMin = 0
    if startTime > 0 and now >= startTime then
        local el = now - startTime
        gameMin = math.floor(el / 60)
        gameSec = el % 60
    end
    local timeUntil00 = math.max(0, math.floor(60.0 - gameSec))
    local nextSpawnSec = (gameMin + 1) * 60
    
    local pool = getAvailableSpiders(hero, now)
    local assignedCount = 0
    for spiderEnt, cCamp in pairs(state.assignedSpiders) do
        if spiderEnt ~= nil and Entity.IsAlive(spiderEnt) then
            assignedCount = assignedCount + 1
        end
    end
    
    local spawnLine = string.format(tr("brood_cb.next_spawn_in"), math.floor(nextSpawnSec / 60), nextSpawnSec % 60, timeUntil00)
    local spidersLine = string.format(tr("brood_cb.spiders_pool"), #pool, assignedCount)
    
    Render.Text(ui.font, math.floor(10 * scale), spawnLine, Vec2(x + padding, footerY), C.COLORS.text)
    Render.Text(ui.font, math.floor(10 * scale), spidersLine, Vec2(x + padding, footerY + 16 * scale), C.COLORS.accent_bright)
    
    -- Tooltip on Marker Hover
    if ui.hoveredCamp ~= nil then
        local c = ui.hoveredCamp
        local tipLines = {
            string.format("%s %s Camp", c.side:upper(), c.typeName),
            c.enabled and tr("brood_cb.tip_selected") or tr("brood_cb.tip_unselected")
        }
        
        local spList = c.assignedSpiders or (c.assignedSpider and { c.assignedSpider } or {})
        local aliveCount = 0
        for sIdx = 1, #spList do
            local spEnt = spList[sIdx]
            if spEnt ~= nil and Entity.IsAlive(spEnt) then
                aliveCount = aliveCount + 1
                local hp = Entity.GetHealth(spEnt)
                local maxHp = Entity.GetMaxHealth(spEnt)
                local life = getSpiderLifetime(spEnt, now)
                table.insert(tipLines, string.format("Spider #%d: HP %d/%d, Life: %.0fs", aliveCount, hp, maxHp, life))
            end
        end
        if aliveCount > 0 then
            table.insert(tipLines, string.format("State: %s (%d assigned)", c.state, aliveCount))
        end
        
        local tipW = 0
        local lineHeights = 15 * scale
        for l = 1, #tipLines do
            local sz = Render.TextSize(ui.font, math.floor(10 * scale), tipLines[l])
            if sz.x > tipW then tipW = sz.x end
        end
        tipW = tipW + 16 * scale
        local tipH = #tipLines * lineHeights + 8 * scale
        
        local tipX = clamp(cursorX + 12, 0, screen.x - tipW)
        local tipY = clamp(cursorY - tipH - 8, 0, screen.y - tipH)
        
        Render.Shadow(Vec2(tipX, tipY), Vec2(tipX + tipW, tipY + tipH), Color(0, 0, 0, 200), 10, 4)
        Render.FilledRect(Vec2(tipX, tipY), Vec2(tipX + tipW, tipY + tipH), Color(25, 30, 36, 250), 4)
        Render.Rect(Vec2(tipX, tipY), Vec2(tipX + tipW, tipY + tipH), getCampTypeColor(c.campType), 4, Enum.DrawFlags.None, 1)
        
        for l = 1, #tipLines do
            local tColor = (l == 1) and getCampTypeColor(c.campType) or (l == 2 and (c.enabled and C.COLORS.success or C.COLORS.text_muted) or C.COLORS.text)
            Render.Text(ui.font, math.floor(10 * scale), tipLines[l], Vec2(tipX + 8 * scale, tipY + 4 * scale + (l - 1) * lineHeights), tColor)
        end
    end
end

-- Callbacks implementation
function script.OnScriptsLoaded()
    initializeUiAssets()
    initializeMenu()
end

function script.OnUpdate()
    if not opt.ready then
        initializeMenu()
        if not opt.ready then return end
    end
    
    -- Hotkey checks
    if opt.toggleBind:IsPressed() then
        opt.enabled:Set(not opt.enabled:Get())
    end
    
    if opt.mapKey:IsPressed() then
        opt.showMap:Set(not opt.showMap:Get())
    end
    
    local isBrood, hero = isPlayingBroodmother()
    if not isBrood or hero == nil then
        return
    end

    if opt.enabled:Get() then
        removeManagedSpidersFromSelection(hero)
    end
    
    local now = GameRules.GetGameTime()
    -- Rebuild only on first load or when the game clock moves backwards into a
    -- new match.  The old 120-second refresh silently discarded live routes.
    if not state.campsInitialized or (state.lastMatchTime >= 0 and now + 1.0 < state.lastMatchTime) then
        initializeCamps(hero)
    end
    state.lastMatchTime = now
    
    local blockerEnabled = opt.enabled:Get()
    if state.blockerWasEnabled and not blockerEnabled then
        releaseAllManagedSpiders()
    end
    state.blockerWasEnabled = blockerEnabled

    if blockerEnabled then
        executeCampBlockingLogic(hero, now)
    end
end

function script.OnDraw()
    if not opt.ready then
        initializeMenu()
        if not opt.ready then return end
    end
    
    local isBrood, hero = isPlayingBroodmother()
    local now = GameRules.GetGameTime()
    
    if isBrood and hero ~= nil then
        drawWorldEsp(hero, now)
    end
    
    drawMapPanel(hero, now)
end

function script.OnKeyEvent(data)
    if not opt.ready or data == nil or data.key ~= Enum.ButtonCode.KEY_MOUSE1 then
        return true
    end
    
    local isDown = (data.event == Enum.EKeyEvent.EKeyEvent_KEY_DOWN)
    local isUp = (data.event == Enum.EKeyEvent.EKeyEvent_KEY_UP)
    
    if isUp then
        local captured = ui.capturingMouse or ui.dragging
        ui.mouseHeld = false
        ui.capturingMouse = false
        ui.dragging = false
        return not captured
    end
    
    if not isDown then
        return true
    end
    
    if not opt.showMap:Get() or ui.panelX == nil or ui.panelY == nil then
        return true
    end
    
    local cursorX, cursorY = Input.GetCursorPos()
    local insidePanel = cursorX >= ui.panelX and cursorX <= ui.panelX + ui.width
                    and cursorY >= ui.panelY and cursorY <= ui.panelY + ui.height
    
    if not insidePanel then
        return true
    end
    
    ui.capturingMouse = true
    ui.mouseHeld = true
    
    -- Check Close Button
    if ui.closeBounds ~= nil then
        if cursorX >= ui.closeBounds.x and cursorX <= ui.closeBounds.x + ui.closeBounds.w
           and cursorY >= ui.closeBounds.y and cursorY <= ui.closeBounds.y + ui.closeBounds.h
        then
            opt.showMap:Set(false)
            return false
        end
    end
    
    -- Check Toolbar Buttons
    if ui.buttons ~= nil then
        for b = 1, #ui.buttons do
            local btn = ui.buttons[b]
            if cursorX >= btn.x and cursorX <= btn.x + btn.w and cursorY >= btn.y and cursorY <= btn.y + btn.h then
                local isBrood, hero = isPlayingBroodmother()
                local heroTeam = hero and Entity.GetTeamNum(hero) or Enum.TeamNum.TEAM_RADIANT
                
                if btn.id == "enemy" then
                    for i = 1, #state.camps do
                        local c = state.camps[i]
                        c.enabled = (c.team ~= heroTeam)
                        Config.WriteInt(C.CONFIG_NAME, c.id, c.enabled and 1 or 0)
                    end
                elseif btn.id == "ancients" then
                    for i = 1, #state.camps do
                        local c = state.camps[i]
                        if c.campType == Enum.ECampType.ECampType_ANCIENT then
                            c.enabled = not c.enabled
                            Config.WriteInt(C.CONFIG_NAME, c.id, c.enabled and 1 or 0)
                        end
                    end
                elseif btn.id == "all" then
                    for i = 1, #state.camps do
                        local c = state.camps[i]
                        c.enabled = true
                        Config.WriteInt(C.CONFIG_NAME, c.id, 1)
                    end
                elseif btn.id == "clear" then
                    for i = 1, #state.camps do
                        local c = state.camps[i]
                        c.enabled = false
                        Config.WriteInt(C.CONFIG_NAME, c.id, 0)
                    end
                end
                return false
            end
        end
    end
    
    -- Check Camp Markers Click
    if ui.markers ~= nil then
        for m = 1, #ui.markers do
            local mark = ui.markers[m]
            local d2 = (cursorX - mark.x) ^ 2 + (cursorY - mark.y) ^ 2
            if d2 <= mark.radius ^ 2 then
                mark.camp.enabled = not mark.camp.enabled
                Config.WriteInt(C.CONFIG_NAME, mark.camp.id, mark.camp.enabled and 1 or 0)
                return false
            end
        end
    end
    
    -- Check Header Dragging
    if cursorY <= ui.panelY + ui.headerHeight then
        ui.dragging = true
        ui.dragOffsetX = cursorX - ui.panelX
        ui.dragOffsetY = cursorY - ui.panelY
        return false
    end
    
    -- Intercept clicks on panel body so they don't click ground in game
    return false
end

-- Intercept player unit orders to prevent commands to active blocker / returning spiders
function script.OnPrepareUnitOrders(data)
    if not opt.ready or not opt.enabled or not opt.enabled:Get() or data == nil then
        return true
    end
    
    -- Never block orders issued by this script itself
    if data.identifier == C.ORDER_IDENTIFIER or state.issuingOrder then
        return true
    end
    
    local isBrood, hero = isPlayingBroodmother()
    if not isBrood or hero == nil then
        return true
    end
    
    local issuer = data.orderIssuer
    
    -- Hero only order -> always allow
    if issuer == Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_HERO_ONLY then
        return true
    end
    
    -- Direct order to a specific unit (or group of units)
    if issuer == Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY then
        if data.npc ~= nil then
            if type(data.npc) == "table" then
                local hasLocked = false
                local freeUnits = {}
                for idx = 1, #data.npc do
                    local u = data.npc[idx]
                    if isSpiderLocked(u) then
                        hasLocked = true
                    else
                        table.insert(freeUnits, u)
                    end
                end
                if hasLocked then
                    if #freeUnits == 0 then
                        return false -- All units are locked, completely block order!
                    end
                    -- Re-issue only to clean units
                    state.issuingOrder = true
                    Player.PrepareUnitOrders(
                        data.player or Players.GetLocal(),
                        data.order,
                        data.target,
                        data.position,
                        data.ability,
                        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                        #freeUnits == 1 and freeUnits[1] or freeUnits,
                        data.queue or false,
                        data.showEffects or false,
                        false,
                        true,
                        C.ORDER_IDENTIFIER,
                        false
                    )
                    state.issuingOrder = false
                    return false
                end
            elseif isSpiderLocked(data.npc) then
                -- Block the order entirely
                return false
            end
        end
        return true
    end
    
    -- Never rebuild or redirect a selected-units order. Some engine-generated
    -- spider orders arrive through this issuer without preserving identifier;
    -- forwarding such an order to the remaining selection can make Broodmother
    -- walk to a camp. Selection cleanup in OnUpdate removes managed spiders,
    -- while their frequent route refresh corrects any one-frame stray command.
    if issuer == Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_SELECTED_UNITS or
       issuer == Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_CURRENT_UNIT_ONLY then
        return true
    end
    
    return true
end

function script.OnGameEnd()
    state.campsInitialized = false
    state.camps = {}
    state.lastMatchTime = -1
    state.lastMinuteCycle = -1
    state.nextDispatchEvaluation = 0
    state.assignedSpiders = {}
    state.returningSpiders = {}
    state.dyingSpiders = {}
    state.spiderFirstSeen = {}
    state.blockerWasEnabled = false
end

return script
