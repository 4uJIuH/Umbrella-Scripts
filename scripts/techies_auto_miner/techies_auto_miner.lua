--[[
    ~ Techies Auto Mine Placer
    ~ Platform: Umbrella Dota 2
    ~ Version: v1.1
    ~ Features:
      - Automatically mines selected territories without skipping any valid placement spots
      - Interactive Dota 2 minimap overlay to select territories (Own/Enemy Base, Triangle/Outpost, Jungle, Secret Shop)
      - Correct territory positions: Triangle is between Base and Secret Shop, anchored to Outposts
      - Full bilingual localization (Russian / English) using qLocalization
      - Smart grid generation respecting placement radius (350+ units) and GridNav.IsTraversable
      - Automatic mana management: Arcane Boots, Magic Wand/Stick/Holy Locket, Enchanted Mango
      - Automatic cooldown & charge recovery waiting
      - Instant cancellation on player screen click / RMB movement command (with script order protection)
      - In-world ESP: mine coverage circles, unmined spots, target tracer, status HUD
]]

local script = {}

if Log and Log.Write then
    pcall(Log.Write, "[techies_auto_miner] SCRIPT LOAD STARTED v1.1")
end

-- ============================================================================
-- Localization Setup (qLocalization)
-- ============================================================================
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

local translations = {
    en = {
        techies_am = {
            tab = "Techies",
            group_main = "Auto Mine Placer",
            group_map = "Interactive Map & Zones",
            group_esp = "World ESP & Visuals",
            group_mana = "Mana & Item Recovery",

            enabled = "Enable Auto Miner",
            enabled_tip = "Master switch for Techies Auto Mine Placer script.",
            toggle_mining = "Start / Stop Mining Hotkey",
            toggle_mining_tip = "Press this key to start or stop the auto-mining process.",

            map_key = "Open Map Key",
            map_key_tip = "Hotkey to open/close the interactive minimap window for territory selection.",
            show_map = "Show Interactive Map",
            show_map_tip = "Toggles the interactive minimap window on screen.",

            panel_scale = "Map Panel Scale",
            panel_scale_tip = "Scale factor for the interactive map window.",

            use_arcane = "Auto Arcane Boots",
            use_arcane_tip = "Automatically activate Arcane Boots if mana is insufficient for a mine.",
            use_stick = "Auto Magic Stick / Wand",
            use_stick_tip = "Automatically use Magic Stick, Magic Wand, or Holy Locket if mana is insufficient.",
            use_mango = "Auto Enchanted Mango",
            use_mango_tip = "Automatically consume Enchanted Mango if mana is insufficient for a mine.",

            mine_spacing = "Mine Spacing",
            mine_spacing_tip = "Distance between placed mines (minimum in Dota is 350, recommended 370-390).",

            world_esp = "Show World ESP",
            world_esp_tip = "Draws circles for existing mines, planned spots, and zone boundaries in the world.",
            draw_tracers = "Draw Target Tracer",
            draw_tracers_tip = "Draws a line connecting Techies to the current target mining position.",
            draw_status_hud = "Draw Status HUD",
            draw_status_hud_tip = "Displays status banner above Techies with current mining progress.",

            -- UI In-Panel Texts
            panel_title = "TECHIES AUTO MINER",
            btn_start = "START MINING",
            btn_stop = "STOP MINING",
            btn_my_team = "My Side",
            btn_enemy_team = "Enemy Side",
            btn_select_all = "All Zones",
            btn_clear_all = "Clear All",

            status_active = "MINING",
            status_idle = "IDLE",
            status_waiting_mana = "WAITING MANA",
            status_waiting_cd = "WAITING CD",
            status_completed = "COMPLETED",
            status_interrupted = "INTERRUPTED",
            status_not_techies = "NOT TECHIES",
            status_no_ability = "MINES NOT LEARNED",

            -- Territories
            zone_radiant_base = "Radiant Base",
            zone_radiant_triangle = "Radiant Triangle (Outpost)",
            zone_radiant_jungle = "Radiant Main Jungle",
            zone_radiant_secret_shop = "Radiant Secret Shop",

            zone_dire_base = "Dire Base",
            zone_dire_triangle = "Dire Triangle (Outpost)",
            zone_dire_jungle = "Dire Main Jungle",
            zone_dire_secret_shop = "Dire Secret Shop",

            tip_selected = "Zone: SELECTED (Click to toggle)",
            tip_unselected = "Zone: UNSELECTED (Click to toggle)",
            tip_spots_info = "Spots: %d total, %d mined, %d left",
            tip_status_line = "Status: %s",
            tip_interrupt_hint = "Right-click anywhere in game to cancel"
        }
    },
    ru = {
        techies_am = {
            tab = "Techies",
            group_main = "Авто-минирование",
            group_map = "Интерактивная карта и зоны",
            group_esp = "ESP и визуализация в мире",
            group_mana = "Восстановление маны и предметы",

            enabled = "Включить авто-минирование",
            enabled_tip = "Главный переключатель скрипта авто-минирования за Techies.",
            toggle_mining = "Клавиша Старт / Стоп",
            toggle_mining_tip = "Горячая клавиша для немедленного запуска или остановки процесса минирования.",

            map_key = "Клавиша открытия карты",
            map_key_tip = "Клавиша для открытия/закрытия интерактивной карты выбора территорий.",
            show_map = "Показать карту территорий",
            show_map_tip = "Отображает окно с интерактивной картой для клика по территориям.",

            panel_scale = "Масштаб окна карты",
            panel_scale_tip = "Масштаб интерактивного окна карты.",

            use_arcane = "Авто Arcane Boots",
            use_arcane_tip = "Автоматически использовать Arcane Boots при нехватке маны на мину.",
            use_stick = "Авто Стики / Magic Wand",
            use_stick_tip = "Автоматически прожимать Magic Stick, Wand или Holy Locket при нехватке маны.",
            use_mango = "Авто Enchanted Mango",
            use_mango_tip = "Автоматически съедать Mango при нехватке маны на мину.",

            mine_spacing = "Расстояние между минами",
            mine_spacing_tip = "Расстояние между минами (в Доте минимум 350, рекомендуется 370-390).",

            world_esp = "Отображение ESP в мире",
            world_esp_tip = "Отображает круги установленных мин, не заминированные точки и границы зон.",
            draw_tracers = "Линия к текущей точке",
            draw_tracers_tip = "Рисует трассирующую линию от Течиса к текущей целевой точке минирования.",
            draw_status_hud = "Информационный статус в HUD",
            draw_status_hud_tip = "Отображает плашку со статусом минирования над Течисом.",

            -- UI In-Panel Texts
            panel_title = "ТЕЧИС: АВТО-МИНИРОВАНИЕ",
            btn_start = "СТАРТ МИНИРОВАНИЯ",
            btn_stop = "ОСТАНОВИТЬ",
            btn_my_team = "Своя сторона",
            btn_enemy_team = "Вражеская",
            btn_select_all = "Все зоны",
            btn_clear_all = "Сброс",

            status_active = "МИНИРОВАНИЕ",
            status_idle = "ОЖИДАНИЕ",
            status_waiting_mana = "ЖДЕМ МАНУ",
            status_waiting_cd = "ЖДЕМ КД / ЗАРЯД",
            status_completed = "ЗАВЕРШЕНО",
            status_interrupted = "ПРЕРВАНО ИГРОКОМ",
            status_not_techies = "ВЫ НЕ TECHIES",
            status_no_ability = "МИНЫ НЕ ПРОКАЧАНЫ",

            -- Territories
            zone_radiant_base = "Своя база Radiant",
            zone_radiant_triangle = "Тройка Radiant (Аванпост)",
            zone_radiant_jungle = "Лес Radiant (Основной)",
            zone_radiant_secret_shop = "Потайной магазин Radiant",

            zone_dire_base = "База Dire",
            zone_dire_triangle = "Тройка Dire (Аванпост)",
            zone_dire_jungle = "Лес Dire (Основной)",
            zone_dire_secret_shop = "Потайной магазин Dire",

            tip_selected = "Зона: ВЫБРАНА (Клик для переключения)",
            tip_unselected = "Зона: НЕ ВЫБРАНА (Клик для переключения)",
            tip_spots_info = "Точки: всего %d, готово %d, осталось %d",
            tip_status_line = "Статус: %s",
            tip_interrupt_hint = "Нажмите ПКМ в игре для отмены"
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
        local path = key:gsub("^techies_am%.", "")
        res = dict.techies_am and dict.techies_am[path]
        if res == nil then
            res = translations.en.techies_am and translations.en.techies_am[path] or key
        end
    end
    if ... then
        return string.format(res, ...)
    end
    return res
end

-- ============================================================================
-- Constants
-- ============================================================================
local C = {
    HERO_NAME = "npc_dota_hero_techies",
    MINE_ABILITY = "techies_land_mines",
    MINE_UNIT = "npc_dota_techies_land_mine",
    MINE_PROXIMITY_RADIUS = 350.0, -- Dota 2 land mine placement exclusion radius
    MINE_TRIGGER_RADIUS = 500.0,
    ORDER_IDENTIFIER = "techies_auto_miner",
    CONFIG_NAME = "techies_auto_miner",

    ITEMS = {
        arcane_boots = "item_arcane_boots",
        magic_wand = "item_magic_wand",
        magic_stick = "item_magic_stick",
        holy_locket = "item_holy_locket",
        mango = "item_enchanted_mango"
    },

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
      <stop offset="0" stop-color="#2a3826"/>
      <stop offset="0.48" stop-color="#18221c"/>
      <stop offset="0.52" stop-color="#202428"/>
      <stop offset="1" stop-color="#34383c"/>
    </linearGradient>
  </defs>
  <rect width="512" height="512" rx="12" fill="#101412"/>
  <path d="M0 512V214L64 180l70 18 72-46 57 30 64-42 74 16 111-72v428z" fill="url(#g)"/>
  <path d="M-16 352C88 306 120 262 192 248s114 30 184-8 98-81 152-96" fill="none" stroke="#121e26" stroke-width="36" opacity=".95"/>
  <path d="M-16 352C88 306 120 262 192 248s114 30 184-8 98-81 152-96" fill="none" stroke="#223d4c" stroke-width="16" opacity=".75"/>
  <circle cx="50" cy="462" r="28" fill="#4d853e" opacity=".8"/>
  <circle cx="462" cy="50" r="28" fill="#8f352f" opacity=".8"/>
</svg>
]],

    COLORS = {
        bg = Color(18, 22, 26, 245),
        header = Color(26, 32, 38, 255),
        border = Color(52, 62, 72, 220),
        plate = Color(12, 16, 20, 230),

        accent = Color(255, 140, 30, 255),
        accent_bright = Color(255, 175, 45, 255),
        success = Color(65, 215, 105, 255),
        warning = Color(250, 185, 45, 255),
        danger = Color(245, 65, 65, 255),
        info = Color(65, 185, 245, 255),

        text = Color(235, 242, 248, 255),
        text_muted = Color(140, 150, 162, 255),

        btn_bg = Color(32, 40, 48, 220),
        btn_hover = Color(48, 58, 70, 240),
        btn_border = Color(65, 78, 92, 220),

        -- Zone colors
        zone_radiant = Color(70, 210, 130, 255),
        zone_dire = Color(245, 75, 75, 255),
        zone_triangle = Color(255, 195, 50, 255),
        zone_shop = Color(85, 185, 255, 255)
    }
}

-- ============================================================================
-- Runtime State & Variables
-- ============================================================================
local opt = {}
local ui = {
    font = nil,
    fontBold = nil,
    iconFont = nil,
    mapImage = nil,
    fallbackImage = nil,

    panelX = nil,
    panelY = nil,
    width = 410,
    height = 550,
    headerHeight = 34,

    dragging = false,
    dragOffsetX = 0,
    dragOffsetY = 0,

    hoveredZone = nil,
    buttons = {},
    markers = {},
    closeBounds = nil,
    startBtnBounds = nil
}

local state = {
    isMining = false,
    statusText = "IDLE",
    statusDetail = "",
    lastStatusUpdate = 0,

    currentZone = nil,
    currentTargetSpot = nil,
    miningPath = {},
    lastMoveOrderTime = 0,
    lastCastOrderTime = 0,
    lastItemUseTime = 0,
    lastScanTime = 0,

    zones = {},
    existingMines = {},
    recentlyPlacedMines = {},

    landmarksAnchored = false,
    isScriptIssuingOrder = false,
    toggleKeyHeld = false
}

-- ============================================================================
-- Territory & Zone Definitions
-- Territory order is logically arranged: Base -> Triangle (Outpost) -> Secret Shop -> Main Jungle
-- ============================================================================
local ZONE_CONFIG = {
    {
        id = "radiant_base",
        nameKey = "techies_am.zone_radiant_base",
        team = Enum.TeamNum.TEAM_RADIANT,
        side = "radiant",
        center = Vector(-5800, -5600, 384),
        radius = 1650,
        color = Color(65, 215, 120, 255),
        glyph = "\u{f015}" -- Home
    },
    {
        id = "radiant_triangle",
        nameKey = "techies_am.zone_radiant_triangle",
        team = Enum.TeamNum.TEAM_RADIANT,
        side = "radiant",
        center = Vector(-4000, -2200, 384), -- Between Base and Secret Shop, around Outpost
        radius = 1700,
        color = Color(255, 195, 50, 255),
        glyph = "\u{f6ff}" -- Mountain / Outpost
    },
    {
        id = "radiant_secret_shop",
        nameKey = "techies_am.zone_radiant_secret_shop",
        team = Enum.TeamNum.TEAM_RADIANT,
        side = "radiant",
        center = Vector(-4600, 1250, 384),
        radius = 950,
        color = Color(65, 180, 255, 255),
        glyph = "\u{f290}" -- Shopping bag
    },
    {
        id = "radiant_jungle",
        nameKey = "techies_am.zone_radiant_jungle",
        team = Enum.TeamNum.TEAM_RADIANT,
        side = "radiant",
        center = Vector(1500, -4200, 384),
        radius = 2300,
        color = Color(55, 205, 175, 255),
        glyph = "\u{f1bb}" -- Tree
    },
    {
        id = "dire_base",
        nameKey = "techies_am.zone_dire_base",
        team = Enum.TeamNum.TEAM_DIRE,
        side = "dire",
        center = Vector(5800, 5600, 384),
        radius = 1650,
        color = Color(245, 65, 65, 255),
        glyph = "\u{f015}" -- Home
    },
    {
        id = "dire_triangle",
        nameKey = "techies_am.zone_dire_triangle",
        team = Enum.TeamNum.TEAM_DIRE,
        side = "dire",
        center = Vector(4000, 2200, 384), -- Between Base and Secret Shop, around Outpost
        radius = 1700,
        color = Color(255, 145, 45, 255),
        glyph = "\u{f6ff}" -- Mountain / Outpost
    },
    {
        id = "dire_secret_shop",
        nameKey = "techies_am.zone_dire_secret_shop",
        team = Enum.TeamNum.TEAM_DIRE,
        side = "dire",
        center = Vector(4600, -1250, 384),
        radius = 950,
        color = Color(195, 120, 255, 255),
        glyph = "\u{f290}" -- Shopping bag
    },
    {
        id = "dire_jungle",
        nameKey = "techies_am.zone_dire_jungle",
        team = Enum.TeamNum.TEAM_DIRE,
        side = "dire",
        center = Vector(-1500, 4200, 384),
        radius = 2300,
        color = Color(225, 95, 220, 255),
        glyph = "\u{f1bb}" -- Tree
    }
}

-- ============================================================================
-- Math & Helper Functions
-- ============================================================================
local function clamp(val, min, max)
    if val < min then return min end
    if val > max then return max end
    return val
end

local function dist2D(v1, v2)
    if v1 == nil or v2 == nil then return 99999 end
    local dx = v1.x - v2.x
    local dy = v1.y - v2.y
    return math.sqrt(dx * dx + dy * dy)
end

local function isPlayingTechies()
    local hero = Heroes.GetLocal()
    if hero == nil then return false, nil end
    local name = NPC.GetUnitName(hero)
    if name == C.HERO_NAME then
        return true, hero
    end
    return false, hero
end

-- Convert 3D world coordinates to 2D interactive minimap panel coordinates
local function worldToMapCoords(worldX, worldY, mapX, mapY, mapSize)
    local span = C.WORLD_MAX - C.WORLD_MIN
    local normX = clamp((worldX - C.WORLD_MIN) / span, 0, 1)
    local normY = clamp(1.0 - (worldY - C.WORLD_MIN) / span, 0, 1)

    local inset = math.max(2, math.floor(mapSize * 0.015))
    local usableSize = mapSize - inset * 2
    return mapX + inset + normX * usableSize,
           mapY + inset + normY * usableSize
end

-- ============================================================================
-- Territory Grid Generation & Mine Spot Analysis
-- ============================================================================
local function generateZoneGridSpots(zone, spacing)
    local spots = {}
    local cx, cy = zone.center.x, zone.center.y
    local cz = zone.center.z or 384
    local radius = zone.radius
    local rowStep = spacing * 0.866 -- Hexagonal lattice row step
    local rowIndex = 0

    for y = -radius, radius, rowStep do
        rowIndex = rowIndex + 1
        local rowOffset = (rowIndex % 2 == 0) and (spacing * 0.5) or 0
        for x = -radius, radius, spacing do
            local px = cx + x + rowOffset
            local py = cy + y
            local dFromCenter = math.sqrt((px - cx) ^ 2 + (py - cy) ^ 2)

            if dFromCenter <= radius then
                local candPos = Vector(px, py, cz)
                -- Traversability test via GridNav
                local ok, traversable = pcall(GridNav.IsTraversable, candPos)
                if ok and traversable then
                    table.insert(spots, {
                        pos = candPos,
                        zoneId = zone.id,
                        mined = false
                    })
                end
            end
        end
    end

    return spots
end

-- Dynamic Landmark Anchoring (Outposts, Forts, Ancients)
local function anchorLandmarksToWorld()
    if state.landmarksAnchored then return end

    local npcs = NPCs.GetAll()
    if npcs == nil or #npcs == 0 then return end

    local spacing = (opt.mineSpacing and opt.mineSpacing:Get()) or 380
    local foundAnyOutpost = false

    for i = 1, #npcs do
        local npc = npcs[i]
        if npc ~= nil then
            local uName = NPC.GetUnitName(npc)
            local pos = Entity.GetAbsOrigin(npc)

            if pos ~= nil then
                if uName == "npc_dota_goodguys_fort" then
                    for z = 1, #state.zones do
                        if state.zones[z].id == "radiant_base" then
                            state.zones[z].center = Vector(pos.x, pos.y, pos.z)
                        end
                    end
                elseif uName == "npc_dota_badguys_fort" then
                    for z = 1, #state.zones do
                        if state.zones[z].id == "dire_base" then
                            state.zones[z].center = Vector(pos.x, pos.y, pos.z)
                        end
                    end
                elseif uName == "npc_dota_watch_tower" then
                    -- Radiant Outpost is in negative X, between Base and Secret Shop
                    if pos.x < 0 and pos.y < 500 then
                        for z = 1, #state.zones do
                            if state.zones[z].id == "radiant_triangle" then
                                state.zones[z].center = Vector(pos.x, pos.y, pos.z)
                                state.zones[z].spots = generateZoneGridSpots(state.zones[z], spacing)
                                foundAnyOutpost = true
                            end
                        end
                    elseif pos.x > 0 and pos.y > -500 then
                        -- Dire Outpost
                        for z = 1, #state.zones do
                            if state.zones[z].id == "dire_triangle" then
                                state.zones[z].center = Vector(pos.x, pos.y, pos.z)
                                state.zones[z].spots = generateZoneGridSpots(state.zones[z], spacing)
                                foundAnyOutpost = true
                            end
                        end
                    end
                end
            end
        end
    end

    if foundAnyOutpost then
        state.landmarksAnchored = true
    end
end

local function initializeZones()
    local hero = Heroes.GetLocal()
    local heroTeam = hero and Entity.GetTeamNum(hero) or Enum.TeamNum.TEAM_RADIANT
    state.zones = {}

    for i = 1, #ZONE_CONFIG do
        local cfg = ZONE_CONFIG[i]
        local isOwn = (cfg.team == heroTeam)
        -- Read saved state or default: own side zones enabled by default
        local saved = Config.ReadInt(C.CONFIG_NAME, "zone_" .. cfg.id, isOwn and 1 or 0) == 1

        local zoneObj = {
            id = cfg.id,
            nameKey = cfg.nameKey,
            team = cfg.team,
            side = cfg.side,
            isOwn = isOwn,
            center = cfg.center,
            radius = cfg.radius,
            color = cfg.color,
            glyph = cfg.glyph,
            enabled = saved,
            spots = {},
            unminedCount = 0,
            minedCount = 0
        }

        local spacing = (opt.mineSpacing and opt.mineSpacing:Get()) or 380
        zoneObj.spots = generateZoneGridSpots(zoneObj, spacing)
        table.insert(state.zones, zoneObj)
    end
end

-- Refresh and scan all live land mines placed on the map
local function updateExistingMines(hero)
    state.existingMines = {}
    local npcs = NPCs.GetAll()
    if npcs == nil then return end

    local now = GameRules.GetGameTime()

    -- Clean up temporary recently placed mines older than 5s
    local cleanRecent = {}
    for r = 1, #state.recentlyPlacedMines do
        local item = state.recentlyPlacedMines[r]
        if now - item.time < 5.0 then
            table.insert(cleanRecent, item)
            table.insert(state.existingMines, item.pos)
        end
    end
    state.recentlyPlacedMines = cleanRecent

    -- Scan live mine NPCs
    for i = 1, #npcs do
        local npc = npcs[i]
        if npc ~= nil and Entity.IsAlive(npc) and not Entity.IsDormant(npc) then
            local uName = NPC.GetUnitName(npc)
            if uName == C.MINE_UNIT or uName == "npc_dota_techies_mines" then
                if Entity.IsSameTeam(npc, hero) then
                    table.insert(state.existingMines, Entity.GetAbsOrigin(npc))
                end
            end
        end
    end

    -- Update mined/unmined status for all zone spots
    for z = 1, #state.zones do
        local zone = state.zones[z]
        local mined = 0
        local unmined = 0

        for s = 1, #zone.spots do
            local spot = zone.spots[s]
            local hasMine = false

            for m = 1, #state.existingMines do
                local mPos = state.existingMines[m]
                if dist2D(spot.pos, mPos) < (C.MINE_PROXIMITY_RADIUS - 10) then
                    hasMine = true
                    break
                end
            end

            spot.mined = hasMine
            if hasMine then
                mined = mined + 1
            else
                unmined = unmined + 1
            end
        end

        zone.minedCount = mined
        zone.unminedCount = unmined
    end
end

-- Stop Auto-Mining and return control to player
local function stopAutoMining(reason)
    if state.isMining then
        state.isMining = false
        state.currentTargetSpot = nil
        state.miningPath = {}
        state.statusText = "IDLE"
        state.statusDetail = reason or tr("techies_am.status_interrupted")

        if Log and Log.Write then
            pcall(Log.Write, "[techies_auto_miner] Mining stopped: " .. tostring(reason))
        end
    end
end

-- Start Auto-Mining sequence
local function startAutoMining()
    local isTechies, hero = isPlayingTechies()
    if not isTechies or hero == nil then
        state.statusText = "NOT_TECHIES"
        return
    end

    local landMines = NPC.GetAbility(hero, C.MINE_ABILITY)
    if landMines == nil or Ability.GetLevel(landMines) <= 0 then
        state.isMining = false
        state.statusText = "NO_ABILITY"
        state.statusDetail = tr("techies_am.status_no_ability")
        return
    end

    updateExistingMines(hero)

    -- Collect all unmined spots from currently enabled zones
    local unminedPool = {}
    for z = 1, #state.zones do
        local zone = state.zones[z]
        if zone.enabled then
            for s = 1, #zone.spots do
                local sp = zone.spots[s]
                if not sp.mined then
                    table.insert(unminedPool, sp)
                end
            end
        end
    end

    if #unminedPool == 0 then
        state.isMining = false
        state.statusText = "COMPLETED"
        state.statusDetail = "All selected zones already fully mined!"
        return
    end

    state.isMining = true
    state.statusText = "ACTIVE"
    state.statusDetail = string.format("%d spots to mine", #unminedPool)
    state.currentTargetSpot = nil
    state.lastMoveOrderTime = 0
    state.lastCastOrderTime = 0
end

-- Find the optimal next spot using Greedy Nearest-Neighbor from current hero position
local function getNextTargetSpot(hero)
    local heroPos = Entity.GetAbsOrigin(hero)
    local bestSpot = nil
    local bestDist = 999999

    for z = 1, #state.zones do
        local zone = state.zones[z]
        if zone.enabled then
            for s = 1, #zone.spots do
                local spot = zone.spots[s]
                if not spot.mined then
                    -- Verify no mine was recently placed nearby
                    local occupied = false
                    for m = 1, #state.existingMines do
                        if dist2D(spot.pos, state.existingMines[m]) < (C.MINE_PROXIMITY_RADIUS - 10) then
                            occupied = true
                            spot.mined = true
                            break
                        end
                    end

                    if not occupied then
                        local d = dist2D(heroPos, spot.pos)
                        if d < bestDist then
                            bestDist = d
                            bestSpot = spot
                        end
                    end
                end
            end
        end
    end

    return bestSpot
end

-- ============================================================================
-- Core Automation Execution Logic
-- ============================================================================
local function executeAutoMiningLogic(hero, now)
    if not state.isMining then return end

    if not Entity.IsAlive(hero) or Entity.IsDormant(hero) then
        stopAutoMining("Hero died or dormant")
        return
    end

    local isChanneling = false
    if type(NPC.IsChannellingAbility) == "function" then
        isChanneling = NPC.IsChannellingAbility(hero)
    end

    if NPC.IsStunned(hero) or NPC.IsSilenced(hero) or isChanneling then
        return
    end

    local landMines = NPC.GetAbility(hero, C.MINE_ABILITY)
    if landMines == nil or Ability.GetLevel(landMines) <= 0 then
        stopAutoMining(tr("techies_am.status_no_ability"))
        return
    end

    -- Periodically re-scan mines and landmarks
    if now - state.lastScanTime > 1.5 then
        state.lastScanTime = now
        anchorLandmarksToWorld()
        updateExistingMines(hero)
    end

    -- Validate or select current target spot
    if state.currentTargetSpot == nil or state.currentTargetSpot.mined then
        state.currentTargetSpot = getNextTargetSpot(hero)
        if state.currentTargetSpot == nil then
            state.isMining = false
            state.statusText = "COMPLETED"
            state.statusDetail = "All selected territories successfully mined!"
            return
        end
    end

    local targetPos = state.currentTargetSpot.pos
    local heroPos = Entity.GetAbsOrigin(hero)
    local dist = dist2D(heroPos, targetPos)

    local castRange = Ability.GetCastRange(landMines) + NPC.GetCastRangeBonus(hero)
    local effectiveRange = math.max(300, castRange - 40)

    local player = Players.GetLocal()

    -- Phase 1: Movement to target spot
    if dist > effectiveRange then
        state.statusText = "ACTIVE"
        state.statusDetail = string.format("Moving to spot (dist: %.0f)", dist)

        if now - state.lastMoveOrderTime > 0.30 then
            state.lastMoveOrderTime = now
            state.isScriptIssuingOrder = true

            -- Primary movement via NPC.MoveTo
            NPC.MoveTo(hero, targetPos, false, false, false, false, C.ORDER_IDENTIFIER, true)

            -- Backup movement via Player.PrepareUnitOrders if player is present
            if player ~= nil then
                Player.PrepareUnitOrders(
                    player,
                    Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION,
                    nil,
                    targetPos,
                    nil,
                    Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                    hero,
                    false, false, false, true,
                    C.ORDER_IDENTIFIER,
                    false
                )
            end

            state.isScriptIssuingOrder = false
        end
        return
    end

    -- Phase 2: In cast range -> Check Mana & Item Recovery
    local currentMana = NPC.GetMana(hero)
    local manaCost = Ability.GetManaCost(landMines)

    if currentMana < manaCost then
        state.statusText = "WAITING_MANA"
        state.statusDetail = string.format("Mana: %.0f / %d", currentMana, manaCost)

        -- 1. Try Arcane Boots
        if opt.useArcane:Get() and (now - state.lastItemUseTime > 0.4) then
            local boots = NPC.GetItem(hero, C.ITEMS.arcane_boots, true)
            if boots ~= nil and Ability.CanBeExecuted(boots) == Enum.AbilityCastResult.READY then
                state.lastItemUseTime = now
                state.isScriptIssuingOrder = true
                Ability.CastNoTarget(boots, false, false, true, C.ORDER_IDENTIFIER)
                state.isScriptIssuingOrder = false
                return
            end
        end

        -- 2. Try Magic Wand / Stick / Holy Locket
        if opt.useStick:Get() and (now - state.lastItemUseTime > 0.4) then
            local stickNames = { C.ITEMS.magic_wand, C.ITEMS.magic_stick, C.ITEMS.holy_locket }
            for s = 1, #stickNames do
                local stick = NPC.GetItem(hero, stickNames[s], true)
                if stick ~= nil and Item.GetCurrentCharges(stick) > 0 and Ability.CanBeExecuted(stick) == Enum.AbilityCastResult.READY then
                    state.lastItemUseTime = now
                    state.isScriptIssuingOrder = true
                    Ability.CastNoTarget(stick, false, false, true, C.ORDER_IDENTIFIER)
                    state.isScriptIssuingOrder = false
                    return
                end
            end
        end

        -- 3. Try Enchanted Mango
        if opt.useMango:Get() and (now - state.lastItemUseTime > 0.4) then
            local mango = NPC.GetItem(hero, C.ITEMS.mango, true)
            if mango ~= nil and Ability.CanBeExecuted(mango) == Enum.AbilityCastResult.READY then
                state.lastItemUseTime = now
                state.isScriptIssuingOrder = true
                pcall(Ability.CastTarget, mango, hero, false, false, true, C.ORDER_IDENTIFIER)
                state.isScriptIssuingOrder = false
                return
            end
        end

        -- Hold position while waiting for mana regeneration
        if NPC.IsMoving(hero) and now - state.lastMoveOrderTime > 0.5 then
            state.lastMoveOrderTime = now
            state.isScriptIssuingOrder = true
            if player ~= nil then
                Player.HoldPosition(player, hero, false, false, false, C.ORDER_IDENTIFIER)
            end
            state.isScriptIssuingOrder = false
        end
        return
    end

    -- Phase 3: Check Cooldown & Charges
    local charges = Ability.GetCurrentCharges(landMines)
    local cd = Ability.GetCooldown(landMines)
    local canExec = Ability.CanBeExecuted(landMines)

    if charges == 0 or cd > 0 or canExec ~= Enum.AbilityCastResult.READY then
        state.statusText = "WAITING_COOLDOWN"
        local restoreTime = 0
        if type(Ability.ChargeRestoreTimeRemaining) == "function" then
            restoreTime = Ability.ChargeRestoreTimeRemaining(landMines)
        end
        if restoreTime <= 0 then restoreTime = cd end
        state.statusDetail = string.format("Charge ready in %.1fs", math.max(0.1, restoreTime))

        -- Hold position while waiting for cooldown
        if NPC.IsMoving(hero) and now - state.lastMoveOrderTime > 0.5 then
            state.lastMoveOrderTime = now
            state.isScriptIssuingOrder = true
            if player ~= nil then
                Player.HoldPosition(player, hero, false, false, false, C.ORDER_IDENTIFIER)
            end
            state.isScriptIssuingOrder = false
        end
        return
    end

    -- Phase 4: Cast Proximity Mine!
    if now - state.lastCastOrderTime > 0.35 then
        state.lastCastOrderTime = now
        state.statusText = "ACTIVE"
        state.statusDetail = "Placing Proximity Mine..."

        state.isScriptIssuingOrder = true
        Ability.CastPosition(landMines, targetPos, false, false, true, C.ORDER_IDENTIFIER, false)
        state.isScriptIssuingOrder = false

        -- Record recently placed mine position
        table.insert(state.recentlyPlacedMines, { pos = targetPos, time = now })
        table.insert(state.existingMines, targetPos)
        state.currentTargetSpot.mined = true
        state.currentTargetSpot = nil
    end
end

-- ============================================================================
-- Menu Setup
-- ============================================================================
local function initializeMenu()
    if opt.ready then return true end

    local techiesTab = nil
    local ok1, res1 = pcall(Menu.Find, "Heroes", "Hero List", "Techies")
    if ok1 and res1 ~= nil then
        techiesTab = res1
    else
        local ok2, res2 = pcall(Menu.Find, "Герои", "Список героев", "Techies")
        if ok2 and res2 ~= nil then
            techiesTab = res2
        end
    end

    local autoMinerTab = nil
    if techiesTab ~= nil then
        local okTab, newTab = pcall(function() return techiesTab:Create("Авто-минирование") end)
        if okTab and newTab ~= nil then
            autoMinerTab = newTab
            if type(autoMinerTab.Icon) == "function" then
                pcall(autoMinerTab.Icon, autoMinerTab, "\u{f1e2}")
            end
        end
    end

    if autoMinerTab == nil then
        local okFb, fbTab = pcall(Menu.Create, "Heroes", "Hero List", "Techies (Авто-минирование)")
        if okFb and fbTab ~= nil then
            local okSub, sub = pcall(function() return fbTab:Create("Авто-минирование") end)
            autoMinerTab = (okSub and sub ~= nil) and sub or fbTab
        else
            local okFb2, fbTab2 = pcall(Menu.Create, "Герои", "Список героев", "Techies (Авто-минирование)")
            if okFb2 and fbTab2 ~= nil then
                local okSub, sub = pcall(function() return fbTab2:Create("Авто-минирование") end)
                autoMinerTab = (okSub and sub ~= nil) and sub or fbTab2
            end
        end
    end

    if autoMinerTab == nil then
        return false
    end

    local mainGroup = autoMinerTab:Create("Главные настройки", Enum.GroupSide.Left)
    local mapGroup = autoMinerTab:Create("Карта и зоны", Enum.GroupSide.Right)
    local manaGroup = autoMinerTab:Create("Контроль маны", Enum.GroupSide.Left)
    local espGroup = autoMinerTab:Create("ESP в мире", Enum.GroupSide.Right)

    -- Main Settings
    opt.enabled = mainGroup:Switch("Включить авто-минирование", true, "\u{f011}")
    opt.enabled:ToolTip("Главный переключатель работы скрипта.")

    opt.toggleMiningKey = mainGroup:Bind("Клавиша Старт / Стоп", Enum.ButtonCode.BUTTON_CODE_INVALID, "\u{f04b}")
    opt.toggleMiningKey:ToolTip("Горячая клавиша для немедленного запуска или остановки минирования.")

    opt.mineSpacing = mainGroup:Slider("Расстояние между минами", 360, 450, 380, "%d")
    opt.mineSpacing:ToolTip("Расстояние между минами (минимум в игре 350, рекомендуется 370-390).")

    -- Map Settings
    opt.mapKey = mapGroup:Bind("Клавиша карты", Enum.ButtonCode.KEY_F6, "\u{f279}")
    opt.mapKey:ToolTip("Клавиша открытия/закрытия интерактивной карты выбора зон.")

    opt.showMap = mapGroup:Switch("Показать карту зон", true, "\u{f279}")
    opt.showMap:ToolTip("Отображает интерактивное окно с миникартой.")

    opt.panelScale = mapGroup:Slider("Масштаб окна карты", 70, 150, 100, "%d%%")
    opt.panelScale:ToolTip("Размер окна интерактивной карты.")

    -- Mana & Items
    opt.useArcane = manaGroup:Switch("Использовать Arcane Boots", true, "\u{f1fe}")
    opt.useArcane:ToolTip("Автоматически жать Arcane Boots при нехватке маны на мину.")

    opt.useStick = manaGroup:Switch("Использовать Стики / Wand", true, "\u{f0e7}")
    opt.useStick:ToolTip("Автоматически жать стики при нехватке маны.")

    opt.useMango = manaGroup:Switch("Кушать Enchanted Mango", true, "\u{f188}")
    opt.useMango:ToolTip("Автоматически съедать Mango при нехватке маны на мину.")

    -- ESP
    opt.worldEsp = espGroup:Switch("Отображать зоны и мины в мире", true, "\u{f06e}")
    opt.worldEsp:ToolTip("Рисует на земле существующие мины, зоны и плановые точки.")

    opt.drawTracers = espGroup:Switch("Линия к текущей точке", true, "\u{f1fe}")
    opt.drawTracers:ToolTip("Рисует линию от Течиса к следующей точке установки мины.")

    opt.drawStatusHud = espGroup:Switch("Статус над героем", true, "\u{f05a}")
    opt.drawStatusHud:ToolTip("Отображает плашку со статусом минирования над Течисом.")

    opt.ready = true
    return true
end

-- ============================================================================
-- UI Assets Initialization
-- ============================================================================
local function initializeUiAssets()
    ui.font = Render.LoadFont("MuseoSansEx", Enum.FontCreate.FONTFLAG_ANTIALIAS, 500)
    ui.fontBold = Render.LoadFont("MuseoSansEx", Enum.FontCreate.FONTFLAG_ANTIALIAS, 700)
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
        "techies_auto_miner_fallback_map"
    )
    if okSvg and svgHandle ~= nil then
        ui.fallbackImage = svgHandle
    end
end

-- ============================================================================
-- Interactive Map Panel Drawing & Input
-- ============================================================================
local function drawMapPanel(hero, now)
    if not opt.showMap:Get() or ui.font == nil then
        ui.dragging = false
        ui.hoveredZone = nil
        return
    end

    local screen = Render.ScreenSize()
    local scale = (opt.panelScale and opt.panelScale:Get() or 100) / 100.0

    local panelW = math.floor(410 * scale)
    local panelH = math.floor(550 * scale)
    local headerH = math.floor(34 * scale)
    local padding = math.floor(10 * scale)
    local mapSize = panelW - padding * 2

    ui.width = panelW
    ui.height = panelH
    ui.headerHeight = headerH

    if ui.panelX == nil or ui.panelY == nil then
        ui.panelX = Config.ReadInt(C.CONFIG_NAME, "panel_x", -1)
        ui.panelY = Config.ReadInt(C.CONFIG_NAME, "panel_y", -1)
        if ui.panelX < 0 or ui.panelY < 0 then
            ui.panelX = math.floor(screen.x * 0.02)
            ui.panelY = math.floor(screen.y * 0.12)
        end
    end

    local cursorX, cursorY = Input.GetCursorPos()

    -- Dragging handling
    if ui.dragging then
        if Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE1, true) then
            ui.panelX = clamp(cursorX - ui.dragOffsetX, 0, screen.x - panelW)
            ui.panelY = clamp(cursorY - ui.dragOffsetY, 0, screen.y - panelH)
        else
            ui.dragging = false
            Config.WriteInt(C.CONFIG_NAME, "panel_x", ui.panelX)
            Config.WriteInt(C.CONFIG_NAME, "panel_y", ui.panelY)
        end
    end

    local x = ui.panelX
    local y = ui.panelY

    -- Panel Background & Border
    Render.Shadow(Vec2(x, y), Vec2(x + panelW, y + panelH), Color(0, 0, 0, 195), 18, 8)
    Render.FilledRect(Vec2(x, y), Vec2(x + panelW, y + panelH), C.COLORS.bg, 8)
    Render.Rect(Vec2(x, y), Vec2(x + panelW, y + panelH), C.COLORS.border, 8, Enum.DrawFlags.None, 1)

    -- Header Bar
    Render.FilledRect(Vec2(x, y), Vec2(x + panelW, y + headerH), C.COLORS.header, 8)
    Render.Line(Vec2(x, y + headerH), Vec2(x + panelW, y + headerH), C.COLORS.border, 1)

    -- Header Title & Bomb Glyph
    Render.Text(ui.iconFont, math.floor(14 * scale), "\u{f1e2}", Vec2(x + 10 * scale, y + 9 * scale), C.COLORS.accent)
    Render.Text(ui.fontBold or ui.font, math.floor(12 * scale), tr("techies_am.panel_title"), Vec2(x + 32 * scale, y + 9 * scale), C.COLORS.text)

    -- Status Badge in Header
    local statusText = tr("techies_am.status_idle")
    local statusColor = C.COLORS.text_muted
    if state.isMining then
        if state.statusText == "WAITING_MANA" then
            statusText = tr("techies_am.status_waiting_mana")
            statusColor = C.COLORS.info
        elseif state.statusText == "WAITING_COOLDOWN" then
            statusText = tr("techies_am.status_waiting_cd")
            statusColor = C.COLORS.warning
        else
            statusText = tr("techies_am.status_active")
            statusColor = C.COLORS.success
        end
    elseif state.statusText == "COMPLETED" then
        statusText = tr("techies_am.status_completed")
        statusColor = C.COLORS.success
    elseif state.statusText == "NO_ABILITY" then
        statusText = tr("techies_am.status_no_ability")
        statusColor = C.COLORS.danger
    end

    local statusSz = Render.TextSize(ui.font, math.floor(10 * scale), statusText)
    local statusX = x + panelW - statusSz.x - 36 * scale
    Render.FilledRect(Vec2(statusX - 5, y + 7 * scale), Vec2(statusX + statusSz.x + 5, y + headerH - 7 * scale), Color(statusColor.r, statusColor.g, statusColor.b, 45), 4)
    Render.Text(ui.font, math.floor(10 * scale), statusText, Vec2(statusX, y + 9 * scale), statusColor)

    -- Close Button [X]
    local closeX = x + panelW - 22 * scale
    local closeY = y + 9 * scale
    local closeHover = cursorX >= closeX - 4 and cursorX <= closeX + 16 and cursorY >= y and cursorY <= y + headerH
    Render.Text(ui.iconFont, math.floor(12 * scale), "\u{f00d}", Vec2(closeX, closeY), closeHover and C.COLORS.danger or C.COLORS.text_muted)
    ui.closeBounds = { x = closeX - 4, y = y, w = 24 * scale, h = headerH }

    -- Quick Filter Buttons
    local btnY = y + headerH + 6 * scale
    local btnH = math.floor(22 * scale)
    local btnW = math.floor((panelW - padding * 2 - 12 * scale) / 4)

    ui.buttons = {
        { id = "my_side", text = tr("techies_am.btn_my_team"), x = x + padding, y = btnY, w = btnW, h = btnH },
        { id = "enemy_side", text = tr("techies_am.btn_enemy_team"), x = x + padding + btnW + 4 * scale, y = btnY, w = btnW, h = btnH },
        { id = "all", text = tr("techies_am.btn_select_all"), x = x + padding + (btnW + 4 * scale) * 2, y = btnY, w = btnW, h = btnH },
        { id = "clear", text = tr("techies_am.btn_clear_all"), x = x + padding + (btnW + 4 * scale) * 3, y = btnY, w = btnW, h = btnH }
    }

    for b = 1, #ui.buttons do
        local btn = ui.buttons[b]
        local isHover = cursorX >= btn.x and cursorX <= btn.x + btn.w and cursorY >= btn.y and cursorY <= btn.y + btn.h
        Render.FilledRect(Vec2(btn.x, btn.y), Vec2(btn.x + btn.w, btn.y + btn.h), isHover and C.COLORS.btn_hover or C.COLORS.btn_bg, 4)
        Render.Rect(Vec2(btn.x, btn.y), Vec2(btn.x + btn.w, btn.y + btn.h), C.COLORS.btn_border, 4, Enum.DrawFlags.None, 1)

        local tSz = Render.TextSize(ui.font, math.floor(9 * scale), btn.text)
        local tx = btn.x + (btn.w - tSz.x) * 0.5
        local ty = btn.y + (btn.h - tSz.y) * 0.5
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

    -- Draw Territory Markers on Map
    ui.markers = {}
    ui.hoveredZone = nil
    local nodeRadius = math.max(8, math.floor(13 * scale))

    for i = 1, #state.zones do
        local zone = state.zones[i]
        local mx, my = worldToMapCoords(zone.center.x, zone.center.y, mapX, mapY, mapSize)
        local center2D = Vec2(mx, my)

        local isHit = (cursorX - mx) ^ 2 + (cursorY - my) ^ 2 <= (nodeRadius + 4) ^ 2
        if isHit then
            ui.hoveredZone = zone
        end

        -- Base Zone Circle
        if zone.enabled then
            -- Selected: Bright filled circle with colored rim & checkmark
            Render.FilledCircle(center2D, nodeRadius + (isHit and 2 or 0), zone.color)
            Render.Circle(center2D, nodeRadius + (isHit and 4 or 2), C.COLORS.text, 1.5)

            local chkSz = Render.TextSize(ui.iconFont, math.floor(9 * scale), "\u{f00c}")
            Render.Text(ui.iconFont, math.floor(9 * scale), "\u{f00c}", Vec2(mx - chkSz.x * 0.5, my - chkSz.y * 0.5), Color(20, 24, 28, 255))
        else
            -- Unselected: Dark disc with colored rim and glyph
            Render.FilledCircle(center2D, nodeRadius - 1, Color(24, 30, 36, 220))
            Render.Circle(center2D, nodeRadius - 1, zone.color, 1.5)

            local gSz = Render.TextSize(ui.iconFont, math.floor(8 * scale), zone.glyph or "\u{f1e2}")
            Render.Text(ui.iconFont, math.floor(8 * scale), zone.glyph or "\u{f1e2}", Vec2(mx - gSz.x * 0.5, my - gSz.y * 0.5), zone.color)
        end

        table.insert(ui.markers, {
            zone = zone,
            x = mx,
            y = my,
            radius = nodeRadius + 4
        })
    end

    -- Start / Stop Action Button Below Map
    local actionBtnY = mapY + mapSize + 8 * scale
    local actionBtnH = math.floor(32 * scale)
    local actionBtnW = mapSize

    local startHover = cursorX >= mapX and cursorX <= mapX + actionBtnW and cursorY >= actionBtnY and cursorY <= actionBtnY + actionBtnH
    local actionBtnBg = state.isMining and (startHover and Color(255, 75, 75, 255) or Color(225, 55, 55, 230))
                                       or (startHover and Color(75, 225, 115, 255) or Color(55, 195, 95, 230))

    Render.FilledRect(Vec2(mapX, actionBtnY), Vec2(mapX + actionBtnW, actionBtnY + actionBtnH), actionBtnBg, 6)
    Render.Rect(Vec2(mapX, actionBtnY), Vec2(mapX + actionBtnW, actionBtnY + actionBtnH), C.COLORS.border, 6, Enum.DrawFlags.None, 1)

    local actionText = state.isMining and tr("techies_am.btn_stop") or tr("techies_am.btn_start")
    local actionGlyph = state.isMining and "\u{f04d} " or "\u{f04b} "
    local fullActionText = actionGlyph .. actionText
    local actSz = Render.TextSize(ui.fontBold or ui.font, math.floor(11 * scale), fullActionText)
    Render.Text(ui.fontBold or ui.font, math.floor(11 * scale), fullActionText, Vec2(mapX + (actionBtnW - actSz.x) * 0.5, actionBtnY + (actionBtnH - actSz.y) * 0.5), Color(255, 255, 255, 255))

    ui.startBtnBounds = { x = mapX, y = actionBtnY, w = actionBtnW, h = actionBtnH }

    -- Footer Status & Interrupt Hint
    local footerY = actionBtnY + actionBtnH + 6 * scale
    local totalEnabledSpots = 0
    local totalMinedSpots = 0
    for z = 1, #state.zones do
        if state.zones[z].enabled then
            totalEnabledSpots = totalEnabledSpots + #state.zones[z].spots
            totalMinedSpots = totalMinedSpots + state.zones[z].minedCount
        end
    end

    local progressText = string.format("Mines: %d / %d placed", totalMinedSpots, totalEnabledSpots)
    Render.Text(ui.font, math.floor(10 * scale), progressText, Vec2(x + padding, footerY), C.COLORS.text)

    if state.statusDetail and #state.statusDetail > 0 then
        Render.Text(ui.font, math.floor(9 * scale), state.statusDetail, Vec2(x + padding, footerY + 15 * scale), C.COLORS.accent_bright)
    end

    local hintText = tr("techies_am.tip_interrupt_hint")
    Render.Text(ui.font, math.floor(9 * scale), hintText, Vec2(x + padding, footerY + 30 * scale), C.COLORS.text_muted)

    -- Tooltip on Zone Hover
    if ui.hoveredZone ~= nil then
        local z = ui.hoveredZone
        local tipLines = {
            tr(z.nameKey),
            z.enabled and tr("techies_am.tip_selected") or tr("techies_am.tip_unselected"),
            string.format(tr("techies_am.tip_spots_info"), #z.spots, z.minedCount, z.unminedCount)
        }

        local tipW = 0
        local lineHeights = 16 * scale
        for l = 1, #tipLines do
            local sz = Render.TextSize(ui.font, math.floor(10 * scale), tipLines[l])
            if sz.x > tipW then tipW = sz.x end
        end
        tipW = tipW + 18 * scale
        local tipH = #tipLines * lineHeights + 8 * scale

        local tipX = clamp(cursorX + 12, 0, screen.x - tipW)
        local tipY = clamp(cursorY - tipH - 8, 0, screen.y - tipH)

        Render.Shadow(Vec2(tipX, tipY), Vec2(tipX + tipW, tipY + tipH), Color(0, 0, 0, 210), 12, 4)
        Render.FilledRect(Vec2(tipX, tipY), Vec2(tipX + tipW, tipY + tipH), Color(24, 28, 34, 250), 4)
        Render.Rect(Vec2(tipX, tipY), Vec2(tipX + tipW, tipY + tipH), z.color, 4, Enum.DrawFlags.None, 1)

        for l = 1, #tipLines do
            local tColor = (l == 1) and z.color or (l == 2 and (z.enabled and C.COLORS.success or C.COLORS.text_muted) or C.COLORS.text)
            Render.Text(ui.font, math.floor(10 * scale), tipLines[l], Vec2(tipX + 8 * scale, tipY + 4 * scale + (l - 1) * lineHeights), tColor)
        end
    end
end

-- ============================================================================
-- World ESP & Visuals
-- ============================================================================
local function drawWorldEsp(hero, now)
    if not opt.worldEsp:Get() then return end

    -- Draw Land Mines in World
    for m = 1, #state.existingMines do
        local mPos = state.existingMines[m]
        local sPos, onScreen = Render.WorldToScreen(mPos)
        if onScreen and sPos ~= nil then
            Render.FilledCircle(sPos, 7, Color(255, 140, 30, 200))
            Render.Circle(sPos, 12, Color(255, 180, 50, 255), 1.5)
        end
    end

    -- Draw Target Spot & Line Tracer
    if state.isMining and state.currentTargetSpot ~= nil then
        local tPos = state.currentTargetSpot.pos
        local sPos, onScreen = Render.WorldToScreen(tPos)

        if onScreen and sPos ~= nil then
            -- Pulsing target ring
            local pulse = math.sin(now * 6) * 3
            Render.FilledCircle(sPos, 9 + pulse, Color(65, 215, 105, 150))
            Render.Circle(sPos, 16 + pulse, Color(75, 255, 125, 255), 2.0)

            local txt = "NEXT MINE"
            local sz = Render.TextSize(ui.font, 11, txt)
            Render.FilledRect(Vec2(sPos.x - sz.x * 0.5 - 4, sPos.y - sz.y - 18), Vec2(sPos.x + sz.x * 0.5 + 4, sPos.y - 14), Color(15, 20, 25, 210), 3)
            Render.Text(ui.font, 11, txt, Vec2(sPos.x - sz.x * 0.5, sPos.y - sz.y - 16), Color(75, 255, 125, 255))
        end

        -- Tracer line from Techies to target spot
        if opt.drawTracers:Get() then
            local heroPos = Entity.GetAbsOrigin(hero)
            local sHero, heroVisible = Render.WorldToScreen(heroPos)
            if heroVisible and onScreen and sHero ~= nil and sPos ~= nil then
                Render.Line(sHero, sPos, Color(255, 195, 45, 220), 2.0)
            end
        end
    end

    -- Draw Status HUD Above Techies
    if opt.drawStatusHud:Get() and state.isMining then
        local heroPos = Entity.GetAbsOrigin(hero)
        local headPos = Vector(heroPos.x, heroPos.y, heroPos.z + 160)
        local sHead, headVis = Render.WorldToScreen(headPos)

        if headVis and sHead ~= nil then
            local bannerText = string.format("[%s] %s", state.statusText, state.statusDetail or "")
            local bSz = Render.TextSize(ui.fontBold or ui.font, 12, bannerText)
            local bx = sHead.x - bSz.x * 0.5
            local by = sHead.y - bSz.y - 6

            Render.FilledRect(Vec2(bx - 6, by - 4), Vec2(bx + bSz.x + 6, by + bSz.y + 4), Color(18, 24, 30, 230), 4)
            Render.Rect(Vec2(bx - 6, by - 4), Vec2(bx + bSz.x + 6, by + bSz.y + 4), C.COLORS.accent, 4, Enum.DrawFlags.None, 1)
            Render.Text(ui.fontBold or ui.font, 12, bannerText, Vec2(bx, by), Color(255, 255, 255, 255))
        end
    end
end

-- ============================================================================
-- Callbacks & Event Handlers
-- ============================================================================
function script.OnScriptsLoaded()
    initializeUiAssets()
    initializeMenu()
    initializeZones()
end

function script.OnUpdate()
    if not opt.ready then
        initializeMenu()
        if not opt.ready then return end
    end

    -- Hotkey: Toggle Start/Stop Mining (Debounced to prevent multiple triggers while key is down)
    if opt.toggleMiningKey and opt.toggleMiningKey:Get() ~= Enum.ButtonCode.BUTTON_CODE_INVALID then
        local isPressed = opt.toggleMiningKey:IsPressed()
        if isPressed and not state.toggleKeyHeld then
            state.toggleKeyHeld = true
            if state.isMining then
                stopAutoMining("Остановлено горячей клавишей")
            else
                startAutoMining()
            end
        elseif not isPressed then
            state.toggleKeyHeld = false
        end
    end

    -- Hotkey: Toggle Map Panel
    if opt.mapKey and opt.mapKey:IsPressed() then
        opt.showMap:Set(not opt.showMap:Get())
    end

    local isTechies, hero = isPlayingTechies()
    if not isTechies or hero == nil then return end

    local now = GameRules.GetGameTime()

    -- Ensure zones are initialized and anchored to landmarks
    if #state.zones == 0 then
        initializeZones()
    end
    if not state.landmarksAnchored then
        anchorLandmarksToWorld()
    end

    -- Run auto-mining automation
    if opt.enabled:Get() and state.isMining then
        executeAutoMiningLogic(hero, now)
    end
end

function script.OnDraw()
    if not opt.ready then
        initializeMenu()
        if not opt.ready then return end
    end

    local isTechies, hero = isPlayingTechies()
    local now = GameRules.GetGameTime()

    if isTechies and hero ~= nil then
        drawWorldEsp(hero, now)
    end

    drawMapPanel(hero, now)
end

-- Handle mouse clicks for UI panel interaction and player right-click cancellation
function script.OnKeyEvent(data)
    if not opt.ready or data == nil then
        return true
    end

    local cursorX, cursorY = Input.GetCursorPos()
    local insidePanel = opt.showMap:Get() and ui.panelX ~= nil and ui.panelY ~= nil
                    and cursorX >= ui.panelX and cursorX <= ui.panelX + ui.width
                    and cursorY >= ui.panelY and cursorY <= ui.panelY + ui.height

    -- INTERRUPT: Player right-click anywhere on the game world cancels auto-mining!
    if data.key == Enum.ButtonCode.KEY_MOUSE2 and data.event == Enum.EKeyEvent.EKeyEvent_KEY_DOWN then
        if not insidePanel and state.isMining then
            stopAutoMining("Прервано кликом ПКМ по экрану")
            return true -- Allow move order to execute naturally
        end
    end

    if data.key ~= Enum.ButtonCode.KEY_MOUSE1 then
        return true
    end

    local isDown = (data.event == Enum.EKeyEvent.EKeyEvent_KEY_DOWN)
    local isUp = (data.event == Enum.EKeyEvent.EKeyEvent_KEY_UP)

    if isUp then
        ui.dragging = false
        return true
    end

    if not isDown or not insidePanel then
        return true
    end

    -- 1. Check Close Button
    if ui.closeBounds ~= nil then
        if cursorX >= ui.closeBounds.x and cursorX <= ui.closeBounds.x + ui.closeBounds.w
           and cursorY >= ui.closeBounds.y and cursorY <= ui.closeBounds.y + ui.closeBounds.h
        then
            opt.showMap:Set(false)
            return false
        end
    end

    -- 2. Check Start / Stop Button
    if ui.startBtnBounds ~= nil then
        if cursorX >= ui.startBtnBounds.x and cursorX <= ui.startBtnBounds.x + ui.startBtnBounds.w
           and cursorY >= ui.startBtnBounds.y and cursorY <= ui.startBtnBounds.y + ui.startBtnBounds.h
        then
            if state.isMining then
                stopAutoMining("Остановлено кнопкой на панели")
            else
                startAutoMining()
            end
            return false
        end
    end

    -- 3. Check Toolbar Quick Buttons
    if ui.buttons ~= nil then
        for b = 1, #ui.buttons do
            local btn = ui.buttons[b]
            if cursorX >= btn.x and cursorX <= btn.x + btn.w and cursorY >= btn.y and cursorY <= btn.y + btn.h then
                local isTech, hero = isPlayingTechies()
                local heroTeam = hero and Entity.GetTeamNum(hero) or Enum.TeamNum.TEAM_RADIANT

                if btn.id == "my_side" then
                    for z = 1, #state.zones do
                        state.zones[z].enabled = (state.zones[z].team == heroTeam)
                        Config.WriteInt(C.CONFIG_NAME, "zone_" .. state.zones[z].id, state.zones[z].enabled and 1 or 0)
                    end
                elseif btn.id == "enemy_side" then
                    for z = 1, #state.zones do
                        state.zones[z].enabled = (state.zones[z].team ~= heroTeam)
                        Config.WriteInt(C.CONFIG_NAME, "zone_" .. state.zones[z].id, state.zones[z].enabled and 1 or 0)
                    end
                elseif btn.id == "all" then
                    for z = 1, #state.zones do
                        state.zones[z].enabled = true
                        Config.WriteInt(C.CONFIG_NAME, "zone_" .. state.zones[z].id, 1)
                    end
                elseif btn.id == "clear" then
                    for z = 1, #state.zones do
                        state.zones[z].enabled = false
                        Config.WriteInt(C.CONFIG_NAME, "zone_" .. state.zones[z].id, 0)
                    end
                end
                return false
            end
        end
    end

    -- 4. Check Zone Markers Click
    if ui.markers ~= nil then
        for m = 1, #ui.markers do
            local mark = ui.markers[m]
            local d2 = (cursorX - mark.x) ^ 2 + (cursorY - mark.y) ^ 2
            if d2 <= mark.radius ^ 2 then
                mark.zone.enabled = not mark.zone.enabled
                Config.WriteInt(C.CONFIG_NAME, "zone_" .. mark.zone.id, mark.zone.enabled and 1 or 0)
                return false
            end
        end
    end

    -- 5. Check Header Dragging
    if cursorY <= ui.panelY + ui.headerHeight then
        ui.dragging = true
        ui.dragOffsetX = cursorX - ui.panelX
        ui.dragOffsetY = cursorY - ui.panelY
        return false
    end

    -- Block mouse click from falling through to the game world
    return false
end

-- INTERRUPT: Catch any manual unit orders issued by the player
function script.OnPrepareUnitOrders(data)
    if not opt.ready or not opt.enabled or not opt.enabled:Get() or data == nil then
        return true
    end

    -- Ignore orders originating from our own script
    if state.isScriptIssuingOrder or data.identifier == C.ORDER_IDENTIFIER then
        return true
    end

    -- If auto-mining is currently running and player gives ANY manual order to the hero:
    if state.isMining then
        local isTech, hero = isPlayingTechies()
        if isTech and hero ~= nil then
            local issuer = data.orderIssuer
            local order = data.order

            -- Check if the order affects our hero
            local affectsHero = false
            if issuer == Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_HERO_ONLY then
                affectsHero = true
            elseif issuer == Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_SELECTED_UNITS or
                   issuer == Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_CURRENT_UNIT_ONLY then
                affectsHero = true
            elseif issuer == Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY then
                if data.npc == hero or (type(data.npc) == "table" and data.npc[1] == hero) then
                    affectsHero = true
                end
            end

            -- If player manually commanded movement, attack, or ability cast:
            if affectsHero then
                local manualOrders = {
                    [Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION] = true,
                    [Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_TARGET] = true,
                    [Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_MOVE] = true,
                    [Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET] = true,
                    [Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION] = true,
                    [Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TARGET] = true,
                    [Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET] = true,
                    [Enum.UnitOrder.DOTA_UNIT_ORDER_HOLD_POSITION] = true,
                    [Enum.UnitOrder.DOTA_UNIT_ORDER_STOP] = true
                }

                if manualOrders[order] then
                    stopAutoMining("Прервано ручным действием игрока")
                end
            end
        end
    end

    return true
end

function script.OnGameEnd()
    state.isMining = false
    state.currentTargetSpot = nil
    state.miningPath = {}
    state.zones = {}
    state.existingMines = {}
    state.recentlyPlacedMines = {}
    state.landmarksAnchored = false
    state.isScriptIssuingOrder = false
    state.toggleKeyHeld = false
end

return script
