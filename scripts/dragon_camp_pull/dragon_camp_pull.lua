---@diagnostic disable: undefined-global

local script = {}

local C = {
    SCRIPT_ID = "dragon_camp_pull",
    VERSION = "1.0",
    DRAGON = "npc_dota_neutral_black_dragon",
    NUKE = "black_dragon_fireball",
    TICK = 0.10,
    REISSUE_TTL = 1.0,
    POS_EPS = 100.0,
    CREEP_SPEED = 325.0,
    TOWER_MARGIN = 200.0,
    ROUTE_MARGIN = 130.0,
    DETOUR_EXTRA = 160.0,
    DETOUR_RADII = { 0.0, 250.0, 500.0 },
    DETOUR_TURNS = { 0.0, 0.25, 0.5, 0.75 },
    DETOUR_MIN_STEP = 300.0,
    DETOUR_PROGRESS = 40.0,
    DETOUR_STUCK = 2.5,
    LANE_GIVEUP = 30.0,
    OBSERVE_RADIUS = 3000.0,
    WAYPOINT_REACHED = 150.0,
    TOWER_VISION_DAY = 1900.0,
    TOWER_VISION_NIGHT_T1 = 800.0,
    TOWER_VISION_NIGHT = 1100.0,
    VISION_MARGIN = 150.0,
    BEHIND_MARGIN = 1000.0,
    STEP_BACK = 300.0,
    STEP_TRIES = 8,
    WATCH_OFFSETS = { 250.0, 150.0, 0.0 },
    STRUCTURE_SCAN = 5.0,
    WATCH_REFRESH = 1.0,
    CAMP_SCAN = 0.5,
    PATTERN_CAMPS = 2,
    RESPAWN_WAIT = 60.0,
    FIRST_SPAWN = 60.0,
    SPAWN_WAIT_MAX = 5.0,
    CAMP_NEUTRAL_SLACK = 150.0,
    WAVE_JOIN_WINDOW = 1.5,
    IGNORE_TIME = 30.0,
    CAMP_PULL_MAX = 2500.0,
    CAMP_SWITCH_MAX = 2000.0,
    CAMP_RADIUS_MIN = 420.0,
    CAMP_RADIUS_MAX = 620.0,
    CAMP_BLOCK_MARGIN = 150.0,
    SPAWN_GUARD = 52.0,
    CAMP_EMPTY_VIEWS = 4,
    CAMP_EMPTY_VIEW = 250.0,
    DETECT_RADIUS = 1000.0,
    AGGRO_APPROACH = 130.0,
    KEEP_AWAY = 80.0,
    STEP_AWAY_RANGE = 400.0,
    BAIT_CONFIRM = 0.8,
    APPROACH_SLACK = 40.0,
    LEAD_HOLD = 250.0,
    LEAD_RESUME = 80.0,
    FOLLOW_RADIUS = 1300.0,
    ENGAGE_MARGIN = 150.0,
    AGGRO_SAMPLE = 0.35,
    AGGRO_MEMORY = 1.2,
    AGGRO_CONFIRM = 2,
    FACING_PROBE = 200.0,
    FACING_COS = 0.7,
    FACING_CLOSE = 50.0,
    MOVE_MIN = 25.0,
    CLOSE_MIN = 20.0,
    MELEE_SLACK = 150.0,
    CHASE_RADIUS = 900.0,
    AGGRO_WINDOW = 6.0,
    ALLY_TOLERANCE = 100.0,
    ALLY_COS = 0.9,
    HIT_LOCK = 0.6,
    SWING_POINT = 0.45,
    ACTION_DEADLINE = 2.5,
    CAST_DEADLINE = 1.5,
    MANUAL_HOLD = 2.5,
    TIME_JUMP = 5.0,
    BLOCK_TIME = 10.0,
    BLOCK_RADIUS = 300.0,
    AGGRO_ATTACKERS = 2,
    PULL_LEAD = 280.0,
    PULL_RANGE_SLACK = 150.0,
    PULL_LOST = 2.0,
    PULL_NO_AGGRO = 3.0,
    REBAIT_MIN_PACK = 2,
    PULL_MAX = 18.0,
    ARRIVE_CHASERS = 700.0,
    MERGE_ARRIVE = 300.0,
    MERGE_EXIT = 450.0,
    MERGE_EXIT_REACHED = 120.0,
    MERGE_MAX = 8.0,
    CONTACT_DIST = 300.0,
    FIREBALL_RADIUS = 300.0,
    FARM_SCAN = 900.0,
    FARM_MAX = 25.0,
    CLUMP_SETTLE = 0.8,
    CLUMP_MAX = 4.0,
    PULL_LOG = 3.0,
    AGGRO_FIREBALL_MIN = 2,
    RETREAT_HP = 0.35,
    RESUME_HP = 0.75,
    HERO_FLEE = 1000.0,
    FLEE_TIME = 3.0,
    TOWER_WATCH = 250.0,
    TOWER_ESCAPE = 250.0,
    FOUNTAIN_STAND = 325.0,
    CAST_RANGE_FALLBACK = 1000.0,
    WAIT_LOG = 30.0,
    SKIP_LOG = 5.0,
    FONT_SIZE = 14,
}

local function enumValue(group, key, fallback)
    local ok, value = pcall(function()
        return Enum[group][key]
    end)
    if ok and type(value) == "number" then
        return value
    end
    return fallback
end

local E = {
    ORDER_ATTACK_TARGET = enumValue("UnitOrder", "DOTA_UNIT_ORDER_ATTACK_TARGET", 4),
    ORDER_CAST_POSITION = enumValue("UnitOrder", "DOTA_UNIT_ORDER_CAST_POSITION", 5),
    ISSUER_PASSED_UNIT = enumValue("PlayerOrderIssuer", "DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY", 3),
    TEAM_ENEMY = enumValue("TeamType", "TEAM_ENEMY", 0),
    TEAM_FRIEND = enumValue("TeamType", "TEAM_FRIEND", 1),
    TEAM_BOTH = enumValue("TeamType", "TEAM_BOTH", 2),
    TEAM_RADIANT = enumValue("TeamNum", "TEAM_RADIANT", 2),
    TEAM_DIRE = enumValue("TeamNum", "TEAM_DIRE", 3),
    TEAM_NEUTRAL = enumValue("TeamNum", "TEAM_NEUTRAL", 4),
    TYPE_BARRACKS = enumValue("UnitTypeFlags", "TYPE_BARRACKS", 64),
    GROUP_LEFT = enumValue("GroupSide", "Left", 1),
    GROUP_RIGHT = enumValue("GroupSide", "Right", 2),
    FONT_ANTIALIAS = enumValue("FontCreate", "FONTFLAG_ANTIALIAS", 16),
}

local localization = qLocalization.new({
    en = {
        dcp = {
            groups = {
                main = "Dragon camp pull",
                fireball = "Fireball",
            },
            menu = {
                enabled = "Enable",
                enabled_tip = "Controls the Black Dragon dominated with Helm of the Overlord.\n\nThe dragon waits next to the lane behind the outermost enemy tower, walks up to the passing enemy wave without attacking it, and once the creeps switch to him leads them to one of the two camps behind that tower, alternating camps wave after wave. It walks through the camp and waits: lane creeps and neutrals engage each other on their own. Only when they touch does it Fireball the pile and finish it with attacks.\n\nIt never attacks lane creeps or neutrals before that, stays out of tower range, retreats from enemy heroes and to the fountain when low, and never orders your hero.",
                overlay = "Debug overlay",
                overlay_tip = "Draws the current phase, its reason, chasers out of the pack, the watch spot and the target camp. Creeps confirmed as chasing the dragon get a CHASE mark.",
                fireball = "Fireball on the merged pile",
                fireball_tip = "Waits until the merged pile is at its densest, then Fireballs it. A lane creep and a neutral must be inside the same 300 radius.",
                fireball_aggro = "Fireball to aggro",
                fireball_aggro_tip = "Off by default. Casts Fireball on a passing wave only when at least two creeps would reach their tower before the dragon could get to them at all. Once per wave.",
                min_targets = "Minimum Fireball targets",
                min_targets_tip = "The merged pile must contain at least this many units inside the Fireball radius.",
            },
            overlay = {
                stats = "chase %d/%d | lane %s",
                chase = "CHASE",
                watch = "WATCH",
                watch_seen = "WATCH (tower sees)",
                camp = "CAMP",
            },
        },
    },
    ru = {
        dcp = {
            groups = {
                main = "Дракон: пул в лагерь",
                fireball = "Фаербол",
            },
            menu = {
                enabled = "Включить",
                enabled_tip = "Управляет Чёрным драконом, прирученным Helm of the Overlord.\n\nДракон ждёт у линии за крайней вражеской вышкой, подходит к проходящей пачке не атакуя её, и как только крипы переключились на него — уводит их в один из двух лагерей за этой вышкой, чередуя лагеря от пачки к пачке. Проходит лагерь насквозь и ждёт: лайновые крипы и нейтралы сцепляются сами. И только когда они соприкоснулись, кидает фаербол в кучу и добивает атаками.\n\nДо этого он не бьёт ни лайновых крипов, ни нейтралов, держится вне радиуса вышек, уходит от вражеских героев и отступает к фонтану на низком HP. Твоего героя скрипт не трогает.",
                overlay = "Отладочный оверлей",
                overlay_tip = "Рисует текущую фазу и её причину, сколько крипов пачки бегут за драконом, точку ожидания и выбранный лагерь. Крипы, у которых подтверждено преследование, помечаются CHASE.",
                fireball = "Фаербол по сведённой куче",
                fireball_tip = "Ждёт, пока сведённая куча соберётся плотнее всего, и бьёт по ней фаерболом. В радиусе 300 должны быть и лайновый крип, и нейтрал.",
                fireball_aggro = "Фаербол для агро",
                fireball_aggro_tip = "По умолчанию выключен. Кастует фаербол по проходящей пачке только если минимум два крипа уйдут под свою вышку раньше, чем дракон вообще успеет до них дойти. Не больше одного раза на пачку.",
                min_targets = "Минимум целей фаербола",
                min_targets_tip = "В радиусе фаербола на сведённой куче должно быть не меньше этого числа юнитов.",
            },
            overlay = {
                stats = "бегут %d/%d | линия %s",
                chase = "БЕЖИТ",
                watch = "ЖДЁТ",
                watch_seen = "ЖДЁТ (видно вышке)",
                camp = "ЛАГЕРЬ",
            },
        },
    },
})

local Menu = localization.WrapLibrary(Menu)

local T = {
    groupMain = "dcp.groups.main",
    groupFireball = "dcp.groups.fireball",
    enabled = "dcp.menu.enabled",
    enabledTip = "dcp.menu.enabled_tip",
    overlay = "dcp.menu.overlay",
    overlayTip = "dcp.menu.overlay_tip",
    fireball = "dcp.menu.fireball",
    fireballTip = "dcp.menu.fireball_tip",
    fireballAggro = "dcp.menu.fireball_aggro",
    fireballAggroTip = "dcp.menu.fireball_aggro_tip",
    minTargets = "dcp.menu.min_targets",
    minTargetsTip = "dcp.menu.min_targets_tip",
    overlayStats = "dcp.overlay.stats",
    overlayChase = "dcp.overlay.chase",
    overlayWatch = "dcp.overlay.watch",
    overlayWatchSeen = "dcp.overlay.watch_seen",
    overlayCamp = "dcp.overlay.camp",
}

local options = { ready = false }

local CampsApi = Camps

local S = {
    player = nil,
    team = 0,
    playerId = -1,
    pet = nil,
    petPos = nil,
    phase = "wait",
    phaseAt = 0,
    cycle = 0,
    reason = "-",
    lane = nil,
    watch = nil,
    camp = nil,
    wave = {},
    waveAggroCast = false,
    track = {},
    ignored = {},
    chasers = {},
    chaserMarks = {},
    packCount = 0,
    action = nil,
    manualUntil = 0,
    lastNow = 0,
    lastOrder = nil,
    lostSince = 0,
    noAggroSince = 0,
    leadHold = false,
    baitAt = 0,
    clumpBest = 0,
    clumpAt = 0,
    nextPullLog = 0,
    pullDeadline = 0,
    lastCamp = nil,
    fightTarget = nil,
    engaged = false,
    exitPoint = nil,
    fighting = false,
    detour = nil,
    blocked = {},
    laneMap = {},
    campList = nil,
    homePos = nil,
    retreating = false,
    fleeUntil = 0,
    towerEscapeUntil = 0,
    towerEscapePos = nil,
    towerEscapeKey = nil,
    towerEscapePlanAt = 0,
    night = false,
    nextTick = 0,
    nextStructureScan = 0,
    nextWatchRefresh = 0,
    nextCampScan = 0,
    lastMinute = nil,
    lastTickNow = nil,
    tickDt = 0.1,
    lastScanAt = nil,
    laneFailSince = 0,
    patternFrom = nil,
    nextWaitLog = 0,
    nextSkipLog = 0,
    font = nil,
    errorFont = nil,
    loadError = nil,
    drawError = nil,
}

local Trace = {}
local U = {}
local World = {}
local CampData = {}
local Dragon = {}
local Orders = {}
local Nav = {}
local Aggro = {}
local Phase = {}
local Draw = {}
local Life = {}

function Trace.write(message, data)
    if type(ai_bridge) == "table" and type(ai_bridge.mcp_log) == "function" then
        pcall(ai_bridge.mcp_log, "info", message, data)
    end
end

function U.nearestOf(list, pos)
    local best, bestD = nil, math.huge
    for i = 1, #list do
        local d = Entity.GetAbsOrigin(list[i]):DistanceSqr2D(pos)
        if d < bestD then
            best, bestD = list[i], d
        end
    end
    return best, math.sqrt(bestD)
end

function U.isRanged(npc)
    return NPC.IsRanged(npc) == true
end

function U.centroid(list)
    if #list == 0 then
        return nil
    end
    local sx, sy, sz = 0, 0, 0
    for i = 1, #list do
        local p = list[i]
        sx, sy, sz = sx + p:GetX(), sy + p:GetY(), sz + p:GetZ()
    end
    return Vector(sx / #list, sy / #list, sz / #list)
end

function U.away(from, pivot, distance)
    local dx, dy = pivot:GetX() - from:GetX(), pivot:GetY() - from:GetY()
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 1 then
        return pivot
    end
    return Vector(pivot:GetX() + dx / len * distance, pivot:GetY() + dy / len * distance, pivot:GetZ())
end

function U.circleCandidates(points, radius)
    local candidates = {}
    local r = radius - 5
    for i = 1, #points do
        local a = points[i]
        candidates[#candidates + 1] = a
        for k = i + 1, #points do
            local b = points[k]
            local dx, dy = b:GetX() - a:GetX(), b:GetY() - a:GetY()
            local d = math.sqrt(dx * dx + dy * dy)
            if d <= r * 2 then
                local mx, my = a:GetX() + dx * 0.5, a:GetY() + dy * 0.5
                if d < 1 then
                    candidates[#candidates + 1] = Vector(mx, my, a:GetZ())
                else
                    local h = math.sqrt(math.max(0, r * r - d * d * 0.25))
                    local px, py = -dy / d * h, dx / d * h
                    candidates[#candidates + 1] = Vector(mx + px, my + py, a:GetZ())
                    candidates[#candidates + 1] = Vector(mx - px, my - py, a:GetZ())
                end
            end
        end
    end
    return candidates
end

function U.clock()
    return GameRules.GetGameTime() - GameRules.GetGameStartTime()
end

function U.spawnWindow()
    local second = U.clock() % 60
    return second >= C.SPAWN_GUARD or second < 1
end

function U.enemyTeam()
    if S.team == E.TEAM_RADIANT then
        return E.TEAM_DIRE
    end
    return E.TEAM_RADIANT
end

function U.traversable(pos)
    if not GridNav or not GridNav.IsTraversable then
        return true
    end
    local ok, result = pcall(GridNav.IsTraversable, pos)
    if not ok or result == nil then
        return true
    end
    return result ~= false
end

function World.towers()
    local list = {}
    local enemy = U.enemyTeam()
    local towers = Towers.GetAll()
    for i = 1, #towers do
        local tower = towers[i]
        if Entity.GetTeamNum(tower) == enemy and Entity.IsAlive(tower) then
            local name = NPC.GetUnitName(tower) or ""
            list[#list + 1] = {
                tower = tower,
                pos = Entity.GetAbsOrigin(tower),
                threat = (NPC.GetAttackRange(tower) or 700.0) + C.TOWER_MARGIN,
                tier = tonumber(name:match("_tower(%d)") or "") or 4,
                lane = name:match("_tower%d_(%a+)"),
            }
        end
    end
    return list
end

function World.insideTowers(pos, towers, extra)
    for i = 1, #towers do
        local r = towers[i].threat + (extra or 0)
        if towers[i].pos:DistanceSqr2D(pos) < r * r then
            return towers[i]
        end
    end
    return nil
end

function World.isNight()
    local function call(fn)
        if type(fn) ~= "function" then
            return nil
        end
        local ok, value = pcall(fn)
        if ok then
            return value
        end
        return nil
    end
    if call(GameRules.IsTemporaryNight) == true or call(GameRules.IsNightstalkerNight) == true then
        return true
    end
    if call(GameRules.IsTemporaryDay) == true then
        return false
    end
    local tod = call(GameRules.GetTimeOfDay)
    local dayStart = call(GameRules.GetDaytimeStart)
    local nightStart = call(GameRules.GetNighttimeStart)
    if type(tod) ~= "number" or type(dayStart) ~= "number" or type(nightStart) ~= "number" then
        return false
    end
    if dayStart < nightStart then
        return not (tod >= dayStart and tod < nightStart)
    end
    return tod >= nightStart and tod < dayStart
end

function World.seenByTowers(pos, towers)
    for i = 1, #towers do
        local vision = C.TOWER_VISION_DAY
        if S.night then
            vision = towers[i].tier == 1 and C.TOWER_VISION_NIGHT_T1 or C.TOWER_VISION_NIGHT
        end
        vision = vision + C.VISION_MARGIN
        if towers[i].pos:DistanceSqr2D(pos) < vision * vision then
            return true
        end
    end
    return false
end

function World.enemyHeroNear(pos, radius)
    local r2 = radius * radius
    local heroes = Heroes.GetAll()
    for i = 1, #heroes do
        local hero = heroes[i]
        if Entity.GetTeamNum(hero) ~= S.team
            and Entity.IsAlive(hero)
            and not Entity.IsDormant(hero)
            and (not NPC.IsIllusion(hero) or NPC.HasModifier(hero, "modifier_arc_warden_tempest_double"))
            and Entity.GetAbsOrigin(hero):DistanceSqr2D(pos) <= r2
        then
            return hero
        end
    end
    return nil
end

function World.home()
    local fort = nil
    for _, npc in pairs(NPCs.GetAll()) do
        if NPC.IsFort(npc) and Entity.GetTeamNum(npc) == S.team then
            fort = Entity.GetAbsOrigin(npc)
            break
        end
    end
    local wanted = S.team == E.TEAM_RADIANT and "ent_dota_fountain_good" or "ent_dota_fountain_bad"
    local entities = Entities.GetAll()
    for i = 1, #entities do
        local entity = entities[i]
        if Entity.GetClassName(entity) == "C_DOTA_Unit_Fountain" and Entity.GetUnitName(entity) == wanted then
            local fountain = Entity.GetAbsOrigin(entity)
            if fort ~= nil then
                return fountain:Extend2D(fort, C.FOUNTAIN_STAND)
            end
            return fountain
        end
    end
    return fort
end

function World.scanStructures(now)
    if now < S.nextStructureScan and S.nextStructureScan - now <= C.STRUCTURE_SCAN * 2 then
        return
    end
    S.nextStructureScan = now + C.STRUCTURE_SCAN
    local enemy = U.enemyTeam()

    local function lane(name)
        local entry = S.laneMap[name]
        if entry == nil then
            entry = { name = name, spawn = nil, towers = {} }
            S.laneMap[name] = entry
        end
        return entry
    end

    local towers = Towers.GetAll()
    for i = 1, #towers do
        local tower = towers[i]
        if Entity.GetTeamNum(tower) == enemy then
            local name = NPC.GetUnitName(tower) or ""
            local tier = tonumber(name:match("_tower(%d)_") or "")
            local laneName = name:match("_tower%d_(%a+)")
            if tier ~= nil and laneName ~= nil and tier <= 3 then
                local entry = lane(laneName)
                entry.towers[tier] = entry.towers[tier] or Entity.GetAbsOrigin(tower)
            end
        end
    end

    local raxes = NPCs.GetAll(E.TYPE_BARRACKS)
    for i = 1, #raxes do
        local rax = raxes[i]
        if Entity.GetTeamNum(rax) == enemy then
            local name = NPC.GetUnitName(rax) or ""
            local laneName = name:match("_rax_(%a+)")
            if laneName ~= nil and name:find("melee", 1, true) ~= nil then
                local entry = lane(laneName)
                entry.spawn = entry.spawn or Entity.GetAbsOrigin(rax)
            end
        end
    end
end

function World.lanePath(entry)
    local pts, tierAt = {}, {}
    if entry.spawn ~= nil then
        pts[#pts + 1] = entry.spawn
    end
    for tier = 3, 1, -1 do
        if entry.towers[tier] ~= nil then
            pts[#pts + 1] = entry.towers[tier]
            tierAt[tier] = #pts
        end
    end
    if #pts < 2 then
        return nil
    end
    local cum = { 0 }
    for i = 2, #pts do
        cum[i] = cum[i - 1] + pts[i]:Distance2D(pts[i - 1])
    end
    return { pts = pts, cum = cum, tierAt = tierAt }
end

function World.pointAt(path, s)
    local pts, cum = path.pts, path.cum
    if s <= 0 then
        return pts[1]
    end
    for i = 2, #pts do
        if s <= cum[i] then
            local seg = cum[i] - cum[i - 1]
            local t = seg > 0 and (s - cum[i - 1]) / seg or 0
            local a, b = pts[i - 1], pts[i]
            return Vector(
                a:GetX() + (b:GetX() - a:GetX()) * t,
                a:GetY() + (b:GetY() - a:GetY()) * t,
                a:GetZ() + (b:GetZ() - a:GetZ()) * t
            )
        end
    end
    return pts[#pts]
end

function CampData.build()
    if S.campList ~= nil and #S.campList > 0 then
        return S.campList
    end
    local list = {}
    for _, handle in pairs(CampsApi.GetAll()) do
        local box = Camp.GetCampBox(handle)
        if box and box.min and box.max then
            local extent = math.max(
                math.abs(box.max:GetX() - box.min:GetX()),
                math.abs(box.max:GetY() - box.min:GetY())
            ) * 0.5
            list[#list + 1] = {
                pos = Vector(
                    (box.min:GetX() + box.max:GetX()) * 0.5,
                    (box.min:GetY() + box.max:GetY()) * 0.5,
                    (box.min:GetZ() + box.max:GetZ()) * 0.5
                ),
                radius = math.min(C.CAMP_RADIUS_MAX, math.max(C.CAMP_RADIUS_MIN, extent + 200.0)),
                minX = math.min(box.min:GetX(), box.max:GetX()),
                maxX = math.max(box.min:GetX(), box.max:GetX()),
                minY = math.min(box.min:GetY(), box.max:GetY()),
                maxY = math.max(box.min:GetY(), box.max:GetY()),
                seenAt = nil,
                emptyViews = 0,
                emptyUntil = nil,
            }
        end
    end
    local clock = U.clock()
    if clock < C.FIRST_SPAWN then
        for i = 1, #list do
            list[i].emptyUntil = GameRules.GetGameTime() + C.FIRST_SPAWN - clock + 1
        end
    end
    S.campList = list
    return list
end

function CampData.neutrals(pos, radius)
    local found = {}
    local list = NPCs.InRadius(pos, radius, S.team, E.TEAM_BOTH, true, true)
    for i = 1, #list do
        local n = list[i]
        if NPC.IsNeutral(n)
            and Entity.GetTeamNum(n) == E.TEAM_NEUTRAL
            and Entity.IsAlive(n)
            and not NPC.IsRoshan(n)
        then
            found[#found + 1] = n
        end
    end
    return found
end

function CampData.nextMinute(now)
    local clock = U.clock()
    return now + (math.floor(clock / 60) + 1) * 60 - clock + 1
end

function CampData.observe(petPos, now)
    if now < S.nextCampScan and S.nextCampScan - now <= C.CAMP_SCAN * 2 then
        return
    end
    S.nextCampScan = now + C.CAMP_SCAN
    local list = CampData.build()
    local minute = math.floor(U.clock() / 60)
    local missed = S.lastScanAt == nil or now - S.lastScanAt > C.CAMP_SCAN * 4
    if S.lastMinute == nil or minute ~= S.lastMinute then
        for i = 1, #list do
            local camp = list[i]
            if camp.emptyUntil ~= nil and camp.emptyUntil <= now + 3 then
                if CampData.occupied(camp) then
                    CampData.markRespawn(camp, now)
                    Trace.write("dcp spawn blocked", { x = camp.pos:GetX(), y = camp.pos:GetY() })
                elseif missed then
                    camp.emptyUntil = CampData.nextMinute(now)
                else
                    camp.emptyUntil = nil
                end
            end
        end
    end
    S.lastMinute = minute
    S.lastScanAt = now
    for i = 1, #list do
        local camp = list[i]
        if petPos ~= nil and camp.pos:Distance2D(petPos) > C.OBSERVE_RADIUS then
            camp.emptyViews = 0
        elseif #CampData.neutrals(camp.pos, camp.radius + C.CAMP_NEUTRAL_SLACK) > 0 then
            if camp.seenAt == nil then
                Trace.write("dcp camp seen", { x = camp.pos:GetX(), y = camp.pos:GetY() })
                camp.seenAt = now
            end
            camp.emptyViews = 0
            camp.emptyUntil = nil
        elseif petPos ~= nil and camp.pos:Distance2D(petPos) <= C.CAMP_EMPTY_VIEW
            and (camp.emptyUntil or -math.huge) <= now
        then
            camp.emptyViews = camp.emptyViews + 1
            if camp.emptyViews >= C.CAMP_EMPTY_VIEWS then
                CampData.markRespawn(camp, now)
                Trace.write("dcp camp empty", { x = camp.pos:GetX(), y = camp.pos:GetY() })
            end
        else
            camp.emptyViews = 0
        end
    end
end

function CampData.occupied(camp)
    local units = NPCs.InRadius(camp.pos, camp.radius + C.CAMP_BLOCK_MARGIN, S.team, E.TEAM_BOTH, false, true)
    for i = 1, #units do
        local unit = units[i]
        local p = Entity.GetAbsOrigin(unit)
        if Entity.IsAlive(unit) and Entity.GetTeamNum(unit) ~= E.TEAM_NEUTRAL
            and p:GetX() >= camp.minX and p:GetX() <= camp.maxX and p:GetY() >= camp.minY and p:GetY() <= camp.maxY
        then
            return true
        end
    end
    return false
end

function CampData.readyBy(camp, from, now)
    return (camp.emptyUntil or -math.huge) <= now + camp.pos:Distance2D(from) / C.CREEP_SPEED + C.SPAWN_WAIT_MAX
end

function CampData.markRespawn(camp, now)
    camp.emptyUntil = CampData.nextMinute(now)
    camp.emptyViews = 0
end

function CampData.pattern(from, towers, now, soon, exclude)
    local list = CampData.build()
    local near = {}
    for i = 1, #list do
        local camp = list[i]
        local d = camp.pos:Distance2D(from)
        if d <= C.CAMP_PULL_MAX and World.insideTowers(camp.pos, towers, C.ROUTE_MARGIN) == nil
            and Nav.segmentClear(from, camp.pos, towers)
        then
            near[#near + 1] = { camp = camp, d = d }
        end
    end
    table.sort(near, function(a, b)
        return a.d < b.d
    end)
    local alive, aliveOther, later, laterOther, seen = nil, nil, nil, nil, 0
    for i = 1, #near do
        local camp = near[i].camp
        if camp ~= exclude then
            seen = seen + 1
        end
        if seen > C.PATTERN_CAMPS then
            break
        end
        if camp ~= exclude then
            local live = (camp.emptyUntil or -math.huge) <= now
            local ready = live or (soon and (camp.emptyUntil or -math.huge) <= now + C.RESPAWN_WAIT)
                or (not soon and CampData.readyBy(camp, from, now))
            if live then
                alive = alive or camp
                if camp ~= S.lastCamp then
                    aliveOther = aliveOther or camp
                end
            elseif ready then
                later = later or camp
                if camp ~= S.lastCamp then
                    laterOther = laterOther or camp
                end
            end
        end
    end
    return aliveOther or alive or laterOther or later
end

function CampData.boxAt(pos)
    local list = CampData.build()
    local x, y, m = pos:GetX(), pos:GetY(), C.CAMP_BLOCK_MARGIN
    for i = 1, #list do
        local camp = list[i]
        if x > camp.minX - m and x < camp.maxX + m and y > camp.minY - m and y < camp.maxY + m then
            return camp
        end
    end
    return nil
end

function CampData.boxExit(camp, pos, towers)
    local x, y, m = pos:GetX(), pos:GetY(), C.CAMP_BLOCK_MARGIN + 100
    local exits = {
        { camp.minX - m - x, 0 },
        { camp.maxX + m - x, 0 },
        { 0, camp.minY - m - y },
        { 0, camp.maxY + m - y },
    }
    local best, bestD = nil, math.huge
    for i = 1, #exits do
        local point = Vector(x + exits[i][1], y + exits[i][2], pos:GetZ())
        local d = math.abs(exits[i][1]) + math.abs(exits[i][2])
        if not U.traversable(point) or World.insideTowers(point, towers, C.ROUTE_MARGIN) ~= nil then
            d = d + 100000
        end
        if d < bestD then
            best, bestD = point, d
        end
    end
    return best
end

function CampData.inAnyBox(pos)
    local list = CampData.build()
    for i = 1, #list do
        local r = list[i].radius + C.CAMP_BLOCK_MARGIN
        if list[i].pos:DistanceSqr2D(pos) < r * r then
            return true
        end
    end
    return false
end

function Dragon.find()
    if S.pet ~= nil then
        local ok, alive = pcall(Entity.IsAlive, S.pet)
        if ok and alive and Entity.GetTeamNum(S.pet) == S.team and NPC.IsControllableByPlayer(S.pet, S.playerId) then
            return S.pet
        end
    end
    for _, npc in pairs(NPCs.GetAll()) do
        if NPC.GetUnitName(npc) == C.DRAGON
            and Entity.IsAlive(npc)
            and Entity.GetTeamNum(npc) == S.team
            and NPC.IsControllableByPlayer(npc, S.playerId)
        then
            return npc
        end
    end
    return nil
end

function Dragon.fireball(pet)
    local ability = NPC.GetAbility(pet, C.NUKE)
    if ability == nil or Ability.GetLevel(ability) < 1 or not Ability.IsReady(ability) then
        return nil
    end
    if NPC.GetMana(pet) < Ability.GetManaCost(ability) then
        return nil
    end
    return ability
end

function Dragon.castRange(pet, ability)
    local range = Ability.GetCastRange(ability) or 0
    if range <= 0 then
        range = C.CAST_RANGE_FALLBACK
    end
    return range + (NPC.GetCastRangeBonus(pet) or 0)
end

function Dragon.laneCreeps(pet, teamType, radius)
    local found = {}
    local list = Entity.GetUnitsInRadius(pet, radius, teamType, true, true)
    for i = 1, #list do
        local n = list[i]
        if NPC.IsLaneCreep(n) and Entity.IsAlive(n) then
            found[#found + 1] = n
        end
    end
    return found
end

function Orders.begin(kind, now, target)
    S.action = { kind = kind, begunAt = now, deadline = now + C.ACTION_DEADLINE, swungAt = nil, armed = false, target = target, cycle = S.cycle }
end

function Orders.finish(failed)
    local action = S.action
    S.action = nil
    S.lastOrder = nil
    if not failed or action == nil then
        return
    end
    Trace.write("dcp action failed", { kind = action.kind, aggro = action.aggro })
    if action.cycle ~= S.cycle then
        return
    end
    if action.kind == "engage" then
        S.engaged = false
    elseif action.kind == "cast" and action.aggro then
        S.waveAggroCast = false
    end
end

function Orders.updateAction(pet, now)
    local action = S.action
    if action == nil then
        return
    end
    if action.kind == "cast" then
        local ok, ready = pcall(Ability.IsReady, action.ability)
        local onCd, cooldown = pcall(Ability.GetCooldown, action.ability)
        local phased, casting = pcall(Ability.IsInAbilityPhase, action.ability)
        if (ok and ready == false) or (onCd and type(cooldown) == "number" and cooldown > 0) then
            Orders.finish(false)
        elseif now >= action.deadline and not (phased and casting) then
            Orders.finish(true)
        end
        return
    end
    if action.swungAt == nil then
        local attacking = NPC.IsAttacking(pet)
        if not attacking then
            action.armed = true
        elseif not action.armed and now - action.begunAt >= C.HIT_LOCK * 0.5 then
            local okPos, targetPos = pcall(Entity.GetAbsOrigin, action.target)
            local petPos = Entity.GetAbsOrigin(pet)
            action.armed = okPos and targetPos ~= nil
                and petPos:Distance2D(targetPos) <= (NPC.GetAttackRange(pet) or 300) + C.MELEE_SLACK
                and Aggro.faces(pet, petPos, targetPos)
        end
        if attacking and action.armed then
            action.swungAt = now
        end
    end
    if action.swungAt ~= nil then
        if now - action.swungAt >= C.SWING_POINT then
            Orders.finish(false)
        end
        return
    end
    local ok, alive = pcall(Entity.IsAlive, action.target)
    if now >= action.deadline or not ok or not alive then
        Orders.finish(true)
    end
end

function Orders.cancel()
    if S.action ~= nil then
        Orders.finish(true)
    end
    S.lastOrder = nil
    S.detour = nil
end

function Orders.allowed(now, mode, pos, key, force)
    if not force and S.action ~= nil then
        return false
    end
    local prev = S.lastOrder
    if force or prev == nil then
        return true
    end
    if prev.mode ~= mode or prev.key ~= key then
        return true
    end
    if pos ~= nil and prev.pos ~= nil and prev.pos:Distance2D(pos) > C.POS_EPS then
        return true
    end
    return now - prev.at >= C.REISSUE_TTL
end

function Orders.remember(now, mode, pos, key)
    S.lastOrder = { mode = mode, pos = pos, key = key, at = now }
end

function Orders.move(pet, pos, now, force)
    if not Orders.allowed(now, "move", pos, nil, force) then
        return false
    end
    NPC.MoveTo(pet, pos)
    Orders.remember(now, "move", pos, nil)
    return true
end

function Orders.attack(pet, target, now, force)
    local key = Entity.GetIndex(target)
    local prev = S.lastOrder
    if not force and prev ~= nil and prev.mode == "attack" and prev.key == key
        and (NPC.IsAttacking(pet) or NPC.IsTurning(pet))
    then
        return false
    end
    if not Orders.allowed(now, "attack", nil, key, force) then
        return false
    end
    Player.PrepareUnitOrders(S.player, E.ORDER_ATTACK_TARGET, target, nil, nil, E.ISSUER_PASSED_UNIT, pet)
    Orders.remember(now, "attack", nil, key)
    return true
end

function Orders.cast(pet, ability, pos, now, aggro)
    Player.PrepareUnitOrders(S.player, E.ORDER_CAST_POSITION, nil, pos, ability, E.ISSUER_PASSED_UNIT, pet)
    S.action = {
        kind = "cast",
        ability = ability,
        aggro = aggro,
        cycle = S.cycle,
        deadline = now + (Ability.GetCastPoint(ability) or 0.3) + C.CAST_DEADLINE,
    }
    S.lastOrder = nil
end

function Nav.blocker(a, b, towers)
    local ax, ay = a:GetX(), a:GetY()
    local dx, dy = b:GetX() - ax, b:GetY() - ay
    local len = math.sqrt(dx * dx + dy * dy)
    local steps = math.max(1, math.ceil(len / 100))
    local best, bestStep = nil, math.huge
    for k = 1, #towers do
        local entry = towers[k]
        local r = entry.threat + C.ROUTE_MARGIN
        local cx, cy = entry.pos:GetX(), entry.pos:GetY()
        local start = math.sqrt((ax - cx) ^ 2 + (ay - cy) ^ 2)
        for i = 0, math.min(steps, bestStep - 1) do
            local t = i / steps
            local dist = math.sqrt((ax + dx * t - cx) ^ 2 + (ay + dy * t - cy) ^ 2)
            if dist < r and not (start < r and dist >= start - 1) then
                best, bestStep = entry, i
                break
            end
        end
    end
    return best
end

function Nav.segmentClear(a, b, towers)
    return Nav.blocker(a, b, towers) == nil
end

function Nav.tangent(origin, entry, side)
    local cx, cy = entry.pos:GetX(), entry.pos:GetY()
    local radius = entry.threat + C.ROUTE_MARGIN + C.DETOUR_EXTRA
    local ox, oy = origin:GetX() - cx, origin:GetY() - cy
    local d = math.sqrt(ox * ox + oy * oy)
    local base = (math.atan2 or math.atan)(oy, ox)
    local angle
    if d > radius then
        angle = base + math.acos(math.min(1, radius / d)) * side
    else
        angle = base + side * 0.3
        radius = radius * 1.1
    end
    return Vector(cx + math.cos(angle) * radius, cy + math.sin(angle) * radius, origin:GetZ())
end

function Nav.go(pet, origin, dest, towers, now)
    local entry = Nav.blocker(origin, dest, towers)
    if entry == nil then
        S.detour = nil
        return Orders.move(pet, dest, now, false)
    end
    local key = Entity.GetIndex(entry.tower)
    local detour = S.detour
    if detour ~= nil and detour.key == key and detour.dest:Distance2D(dest) < 400
        and origin:Distance2D(detour.point) > C.WAYPOINT_REACHED
    then
        local d = origin:Distance2D(detour.point)
        if d < detour.bestD - C.DETOUR_PROGRESS then
            detour.bestD = d
            detour.progressAt = now
        elseif now - detour.progressAt >= C.DETOUR_STUCK then
            Nav.block(detour.point, now)
            S.detour = nil
            detour = nil
        end
        if detour ~= nil then
            return Orders.move(pet, detour.point, now, false)
        end
    end
    local best, bestCost, bestSide = nil, math.huge, nil
    local cx, cy = entry.pos:GetX(), entry.pos:GetY()
    for _, side in ipairs({ 1, -1 }) do
        local tangent = Nav.tangent(origin, entry, side)
        local angle = (math.atan2 or math.atan)(tangent:GetY() - cy, tangent:GetX() - cx)
        local radius = tangent:Distance2D(entry.pos)
        for _, extra in ipairs(C.DETOUR_RADII) do
            for _, turn in ipairs(C.DETOUR_TURNS) do
                local a = angle + side * turn
                local point = Vector(cx + math.cos(a) * (radius + extra), cy + math.sin(a) * (radius + extra), origin:GetZ())
                if origin:Distance2D(point) >= C.DETOUR_MIN_STEP and not Nav.isBlocked(point, now) and U.traversable(point)
                    and World.insideTowers(point, towers, C.ROUTE_MARGIN) == nil and Nav.segmentClear(origin, point, towers)
                then
                    local cost = origin:Distance2D(point) + point:Distance2D(dest)
                    if detour ~= nil and detour.key == key and detour.side == side then
                        cost = cost - 300
                    end
                    if cost < bestCost then
                        best, bestCost, bestSide = point, cost, side
                    end
                end
            end
        end
    end
    if best == nil then
        S.detour = nil
        S.reason = "no_path"
        return false, true
    end
    S.detour = { key = key, side = bestSide, point = best, dest = dest, bestD = origin:Distance2D(best), progressAt = now }
    return Orders.move(pet, best, now, false)
end

function Nav.block(pos, now)
    S.blocked[#S.blocked + 1] = { pos = pos, untilAt = now + C.BLOCK_TIME }
    Trace.write("dcp no_path", { x = pos:GetX(), y = pos:GetY() })
end

function Nav.isBlocked(pos, now)
    local r2 = C.BLOCK_RADIUS * C.BLOCK_RADIUS
    for i = #S.blocked, 1, -1 do
        local entry = S.blocked[i]
        if entry.untilAt <= now then
            table.remove(S.blocked, i)
        elseif entry.pos:DistanceSqr2D(pos) < r2 then
            return true
        end
    end
    return false
end

function Aggro.faces(npc, origin, target)
    local ok, rotation = pcall(Entity.GetRotation, npc)
    if not ok or rotation == nil then
        return true
    end
    local moved, ahead = pcall(origin.MoveForward, origin, rotation, C.FACING_PROBE)
    if not moved or ahead == nil then
        return true
    end
    local tx, ty = target:GetX() - origin:GetX(), target:GetY() - origin:GetY()
    local length = math.sqrt(tx * tx + ty * ty)
    if length < C.FACING_CLOSE then
        return true
    end
    local fx, fy = ahead:GetX() - origin:GetX(), ahead:GetY() - origin:GetY()
    return (fx * tx + fy * ty) / (C.FACING_PROBE * length) >= C.FACING_COS
end

function Aggro.update(pet, creeps, allies, now)
    local petPos = Entity.GetAbsOrigin(pet)
    local seen, chasers, marks = {}, {}, {}
    for i = 1, #creeps do
        local npc = creeps[i]
        local key = Entity.GetIndex(npc)
        local pos = Entity.GetAbsOrigin(npc)
        local sample = S.track[key]
        if sample == nil then
            sample = { pos = pos, at = now, streak = 0, lastAt = -math.huge }
            S.track[key] = sample
        end
        seen[key] = true

        sample.masked = Aggro.allyShields(npc, pos, petPos, allies)
        if sample.masked then
            sample.attackAt = nil
            sample.streak = 0
            sample.pos = pos
            sample.at = now
        elseif Aggro.hitsPet(npc, pos, petPos) then
            sample.attackAt = now
        end

        if now - sample.at >= C.AGGRO_SAMPLE then
            local distance = pos:Distance2D(petPos)
            local chasing = false
            if distance <= C.CHASE_RADIUS and not sample.masked and Aggro.faces(npc, pos, petPos) then
                local closerAlly = false
                for k = 1, #allies do
                    if allies[k]:DistanceSqr2D(pos) < distance * distance then
                        closerAlly = true
                        break
                    end
                end
                if not closerAlly then
                    if distance <= NPC.GetAttackRange(npc) + C.MELEE_SLACK and NPC.IsAttacking(npc) then
                        chasing = true
                    elseif sample.pos:Distance2D(pos) >= C.MOVE_MIN
                        and sample.pos:Distance2D(petPos) - distance >= C.CLOSE_MIN
                    then
                        chasing = true
                    end
                end
            end
            sample.vx = (pos:GetX() - sample.pos:GetX()) / (now - sample.at)
            sample.vy = (pos:GetY() - sample.pos:GetY()) / (now - sample.at)
            sample.pos = pos
            sample.at = now
            if chasing then
                sample.streak = sample.streak + 1
                sample.lastAt = now
            else
                sample.streak = 0
            end
        end

        if sample.streak >= C.AGGRO_CONFIRM and now - sample.lastAt <= C.AGGRO_MEMORY then
            chasers[#chasers + 1] = npc
            marks[#marks + 1] = pos
        end
    end
    for key in pairs(S.track) do
        if not seen[key] then
            S.track[key] = nil
        end
    end
    S.chasers = chasers
    S.chaserMarks = marks
    return chasers
end

function Aggro.hitsPet(npc, pos, petPos)
    return NPC.IsAttacking(npc) and pos:Distance2D(petPos) <= (NPC.GetAttackRange(npc) or 100) + C.MELEE_SLACK
        and Aggro.faces(npc, pos, petPos)
end

function Aggro.allyShields(npc, pos, petPos, allies)
    local distance = pos:Distance2D(petPos)
    if distance <= 1 then
        return false
    end
    local reachAlly = (NPC.GetAttackRange(npc) or 100) + C.MELEE_SLACK
    local px, py = petPos:GetX() - pos:GetX(), petPos:GetY() - pos:GetY()
    for k = 1, #allies do
        local allyD = allies[k]:Distance2D(pos)
        if allyD > 1 and allyD <= reachAlly and allyD < distance + C.ALLY_TOLERANCE then
            local ax, ay = allies[k]:GetX() - pos:GetX(), allies[k]:GetY() - pos:GetY()
            if (ax * px + ay * py) / (allyD * distance) >= C.ALLY_COS then
                return true
            end
        end
    end
    return false
end

function Aggro.isAttacking(npc, now)
    local sample = S.track[Entity.GetIndex(npc)]
    return sample ~= nil and not sample.masked and sample.attackAt ~= nil
        and now - sample.attackAt <= C.AGGRO_MEMORY
end

function Aggro.follows(npc, origin, now)
    local pos = Entity.GetAbsOrigin(npc)
    local sample = S.track[Entity.GetIndex(npc)]
    if pos:Distance2D(origin) > C.FOLLOW_RADIUS or (sample ~= nil and sample.masked) then
        return false
    end
    return Aggro.isAttacking(npc, now) or Aggro.faces(npc, pos, origin)
end

function Aggro.isChasing(npc)
    local sample = S.track[Entity.GetIndex(npc)]
    return sample ~= nil and not sample.masked and sample.streak >= C.AGGRO_CONFIRM
end

function Phase.set(phase, reason, now, data)
    local payload = data or {}
    payload.from = S.phase
    payload.to = phase
    payload.reason = reason
    payload.lane = S.lane
    if S.camp ~= nil then
        payload.camp_x = S.camp.pos:GetX()
        payload.camp_y = S.camp.pos:GetY()
    end
    Trace.write("dcp phase", payload)
    if phase == "wait" and S.phase ~= "wait" then
        for key in pairs(S.wave) do
            S.ignored[key] = now + C.IGNORE_TIME
        end
        S.cycle = S.cycle + 1
    end
    S.phase = phase
    S.phaseAt = now
    S.reason = reason
    S.fighting = false
    S.lostSince = 0
    S.noAggroSince = 0
    S.leadHold = false
    S.baitAt = 0
    S.clumpBest = 0
    S.clumpAt = 0
    S.nextPullLog = 0
    S.fightTarget = nil
    S.engaged = false
    S.exitPoint = nil
    if phase == "wait" then
        S.wave = {}
        S.pullDeadline = 0
        S.camp = nil
        S.waveAggroCast = false
        for key, untilAt in pairs(S.ignored) do
            if untilAt <= now then
                S.ignored[key] = nil
            end
        end
    end
end

function Phase.safeTarget(pos, towers, pet)
    local origin = Entity.GetAbsOrigin(pet)
    local range = math.min(NPC.GetAttackRange(pet) or 300, pos:Distance2D(origin))
    return World.insideTowers(pos:Extend2D(origin, range), towers, 0) == nil
end

function Phase.stepAway(pet, origin, enemies, towers, now, anchor)
    local keep = Phase.keepAway(pet)
    local close, closeD = nil, keep
    for i = 1, #enemies do
        local pos = Entity.GetAbsOrigin(enemies[i])
        local d = pos:Distance2D(origin)
        if d < closeD then
            close, closeD = pos, d
        end
    end
    if close == nil then
        return false
    end
    local point = close:Extend2D(origin, keep)
    if anchor ~= nil and point:Distance2D(anchor) > C.STEP_AWAY_RANGE then
        point = anchor:Extend2D(point, C.STEP_AWAY_RANGE)
    end
    S.reason = "step_away"
    Nav.go(pet, origin, point, towers, now)
    return true
end

function Phase.keepAway(pet)
    return (NPC.GetAttackRange(pet) or 300) + C.KEEP_AWAY
end

function Phase.safeBait(pos, towers, origin)
    local point = origin
    if pos:Distance2D(origin) > C.AGGRO_APPROACH + C.APPROACH_SLACK then
        point = pos:Extend2D(origin, C.AGGRO_APPROACH)
    end
    return World.insideTowers(point, towers, 0) == nil
end

function Phase.pickWatch(towers, origin, now, onlyLane)
    local best, bestD, reason = nil, math.huge, "no_lane"
    for name, entry in pairs(S.laneMap) do
        local path = (onlyLane == nil or name == onlyLane) and World.lanePath(entry) or nil
        if path ~= nil then
            local outerTier, threats = nil, {}
            for i = 1, #towers do
                if towers[i].lane == name and towers[i].tier <= 3 and path.tierAt[towers[i].tier] ~= nil then
                    threats[towers[i].tier] = towers[i].threat
                    if outerTier == nil or towers[i].tier < outerTier then
                        outerTier = towers[i].tier
                    end
                end
            end
            local sLow, sHigh, sPref = 0, path.cum[#path.cum], path.cum[#path.cum]
            if outerTier ~= nil then
                local sOuter = path.cum[path.tierAt[outerTier]]
                sHigh = sOuter - threats[outerTier] - C.ROUTE_MARGIN - 50
                sPref = sOuter - threats[outerTier] - C.BEHIND_MARGIN
                local inner = outerTier + 1
                if threats[inner] ~= nil then
                    sLow = path.cum[path.tierAt[inner]] + threats[inner] + C.ROUTE_MARGIN + 50
                end
            end
            if sLow > sHigh then
                sLow = (sLow + sHigh) * 0.5
                sHigh = sLow
            end
            sPref = math.max(sLow, math.min(sHigh, sPref))
            for try = 0, C.STEP_TRIES do
                local step = math.floor((try + 1) / 2) * C.STEP_BACK * 0.5
                local s = try % 2 == 1 and sPref - step or sPref + step
                local point = World.pointAt(path, s)
                if s >= sLow - 1 and s <= sHigh + 1
                    and World.insideTowers(point, towers, C.ROUTE_MARGIN) == nil and not CampData.inAnyBox(point)
                then
                    if World.enemyHeroNear(point, C.HERO_FLEE * 1.5) then
                        reason = "hero"
                    else
                        local camp = CampData.pattern(point, towers, now, true)
                        if camp == nil then
                            reason = "no_camp"
                        else
                            local spot, hidden = point, false
                            for k = 1, #C.WATCH_OFFSETS do
                                local candidate = point:Extend2D(camp.pos, C.WATCH_OFFSETS[k])
                                if World.insideTowers(candidate, towers, C.ROUTE_MARGIN) == nil
                                    and not CampData.inAnyBox(candidate)
                                    and U.traversable(candidate)
                                then
                                    if not World.seenByTowers(candidate, towers) then
                                        spot, hidden = candidate, true
                                        break
                                    end
                                end
                            end
                            if Nav.isBlocked(spot, now) then
                                reason = "no_path"
                            else
                                local d = origin:Distance2D(spot)
                                if d < bestD then
                                    best, bestD = { lane = name, tier = outerTier or 0, point = point, pos = spot, camp = camp, hidden = hidden }, d
                                end
                                break
                            end
                        end
                    end
                end
            end
        end
    end
    return best, reason
end

function Phase.safety(pet, origin, towers, now)
    local maxHealth = Entity.GetMaxHealth(pet) or 0
    local ratio = maxHealth > 0 and (Entity.GetHealth(pet) or 0) / maxHealth or 1
    if S.retreating and ratio >= C.RESUME_HP then
        S.retreating = false
    elseif not S.retreating and ratio <= C.RETREAT_HP then
        S.retreating = true
        Trace.write("dcp safety", { reason = "low_hp", hp = ratio })
    end

    if World.enemyHeroNear(origin, C.HERO_FLEE) ~= nil then
        if now >= S.fleeUntil then
            Trace.write("dcp safety", { reason = "hero" })
        end
        S.fleeUntil = now + C.FLEE_TIME
    end

    local shooter, shooterD = nil, math.huge
    for i = 1, #towers do
        local entry = towers[i]
        local watch = entry.threat + C.TOWER_WATCH
        local d = entry.pos:Distance2D(origin)
        if d < watch and Tower.GetAttackTarget(entry.tower) == pet then
            if Entity.GetIndex(entry.tower) == S.towerEscapeKey then
                d = -1
            end
            if d < shooterD then
                shooter, shooterD = entry, d
            end
        end
    end
    if shooter ~= nil then
        local key = Entity.GetIndex(shooter.tower)
        if now >= S.towerEscapeUntil then
            Trace.write("dcp safety", { reason = "tower" })
        end
        if now >= S.towerEscapeUntil or key ~= S.towerEscapeKey or now - S.towerEscapePlanAt >= 1.0 then
            S.towerEscapeKey = key
            S.towerEscapePlanAt = now
            local cx, cy = shooter.pos:GetX(), shooter.pos:GetY()
            local base = (math.atan2 or math.atan)(origin:GetY() - cy, origin:GetX() - cx)
            S.towerEscapePos = nil
            for _, extra in ipairs({ C.TOWER_ESCAPE, C.TOWER_ESCAPE * 2 }) do
                local radius = shooter.threat + extra
                for _, turn in ipairs({ 0, 0.5, -0.5, 1.0, -1.0, 1.5, -1.5 }) do
                    local point = Vector(cx + math.cos(base + turn) * radius, cy + math.sin(base + turn) * radius, origin:GetZ())
                    if World.insideTowers(point, towers, C.ROUTE_MARGIN) == nil and U.traversable(point)
                        and Nav.segmentClear(origin, point, towers)
                    then
                        S.towerEscapePos = point
                        break
                    end
                end
                if S.towerEscapePos ~= nil then
                    break
                end
            end
            if S.towerEscapePos == nil then
                S.towerEscapePos = shooter.pos:Extend2D(origin, shooter.threat + C.TOWER_ESCAPE)
            end
        end
        S.towerEscapeUntil = now + 1.0
    end

    if now < S.towerEscapeUntil and S.towerEscapePos ~= nil then
        if S.reason ~= "tower_escape" or S.action ~= nil then
            Orders.cancel()
        end
        S.reason = "tower_escape"
        local _, noPath = Nav.go(pet, origin, S.towerEscapePos, towers, now)
        if noPath then
            Orders.move(pet, S.towerEscapePos, now, false)
        end
        return true
    end

    if S.retreating or now < S.fleeUntil then
        if S.action ~= nil then
            Orders.cancel()
        end
        if S.phase ~= "wait" then
            Phase.set("wait", S.retreating and "low_hp" or "hero", now)
        end
        S.reason = S.retreating and "retreat" or "flee"
        if S.homePos == nil then
            S.homePos = World.home()
        end
        if S.homePos ~= nil then
            Nav.go(pet, origin, S.homePos, towers, now)
        end
        return true
    end
    return false
end

function Phase.wait(pet, origin, towers, enemies, now)
    local fresh, near, ignored, unsafe = {}, 0, 0, 0
    for i = 1, #enemies do
        local pos = Entity.GetAbsOrigin(enemies[i])
        if pos:Distance2D(origin) <= C.DETECT_RADIUS then
            near = near + 1
            local ignoredUntil = S.ignored[Entity.GetIndex(enemies[i])]
            if ignoredUntil ~= nil and ignoredUntil > now then
                ignored = ignored + 1
            elseif not Phase.safeTarget(pos, towers, pet) then
                unsafe = unsafe + 1
            else
                fresh[#fresh + 1] = enemies[i]
            end
        end
    end
    if #fresh >= 2 then
        local from = S.watch ~= nil and S.watch.point or origin
        local camp = CampData.pattern(from, towers, now, false)
        if camp ~= nil then
            S.wave = {}
            for i = 1, #fresh do
                S.wave[Entity.GetIndex(fresh[i])] = true
            end
            S.camp = camp
            S.patternFrom = from
            Phase.set("aggro", "wave_seen", now, { creeps = #fresh })
            return
        end
    end

    if now >= S.nextWatchRefresh or S.watch == nil then
        S.nextWatchRefresh = now + C.WATCH_REFRESH
        local watch, reason = Phase.pickWatch(towers, origin, now, S.lane)
        if watch == nil and S.lane ~= nil then
            if S.laneFailSince == 0 then
                S.laneFailSince = now
            elseif now - S.laneFailSince >= C.LANE_GIVEUP then
                watch, reason = Phase.pickWatch(towers, origin, now, nil)
            end
        else
            S.laneFailSince = 0
        end
        S.watch = watch
        if watch ~= nil then
            if S.lane ~= watch.lane then
                Trace.write("dcp lane", { lane = watch.lane, tier = watch.tier, hidden = watch.hidden })
            end
            S.lane = watch.lane
            S.reason = "watch"
        else
            S.reason = reason
        end
    end

    if now >= S.nextWaitLog or (near >= 2 and now >= S.nextSkipLog) then
        S.nextWaitLog = now + C.WAIT_LOG
        S.nextSkipLog = now + C.SKIP_LOG
        Trace.write("dcp wait", {
            reason = S.reason,
            lane = S.lane,
            near = near,
            fresh = #fresh,
            ignored = ignored,
            unsafe = unsafe,
            enemies = #enemies,
            watch_dist = S.watch ~= nil and math.floor(origin:Distance2D(S.watch.pos)) or nil,
            hidden = S.watch ~= nil and S.watch.hidden or false,
            camp_x = S.watch ~= nil and S.watch.camp.pos:GetX() or nil,
            camp_y = S.watch ~= nil and S.watch.camp.pos:GetY() or nil,
        })
    end

    if S.watch ~= nil and Phase.stepAway(pet, origin, enemies, towers, now, S.watch.pos) then
        return
    end

    if S.watch ~= nil then
        if origin:Distance2D(S.watch.pos) > C.WAYPOINT_REACHED then
            local _, noPath = Nav.go(pet, origin, S.watch.pos, towers, now)
            if noPath then
                Nav.block(S.watch.pos, now)
                S.watch = nil
                S.nextWatchRefresh = 0
            end
        end
    end
end

function Phase.stickyTarget(units, origin)
    local current = S.fightTarget
    if current ~= nil then
        for i = 1, #units do
            if units[i] == current then
                return current
            end
        end
    end
    S.fightTarget = U.nearestOf(units, origin)
    return S.fightTarget
end

function Phase.aggroFireball(pet, origin, towers, pack, now)
    if S.waveAggroCast or not options.fireballAggro:Get() or S.action ~= nil then
        return false
    end
    local ability = Dragon.fireball(pet)
    if ability == nil then
        return false
    end
    local range = Dragon.castRange(pet, ability)
    local attackRange = NPC.GetAttackRange(pet) or 300
    local speed = math.max(NPC.GetMoveSpeed(pet) or 0, 150)
    local petSpeed = math.max(NPC.GetMoveSpeed(pet) or 380, 200)
    local urgent = {}
    for i = 1, #pack do
        local npc = pack[i]
        if not Aggro.isAttacking(npc, now) then
            local pos = Entity.GetAbsOrigin(npc)
            local distance = pos:Distance2D(origin)
            if distance <= range then
                local sample = S.track[Entity.GetIndex(npc)]
                local away = 0
                if sample ~= nil and sample.vx ~= nil and distance > 1 then
                    away = (sample.vx * (pos:GetX() - origin:GetX()) + sample.vy * (pos:GetY() - origin:GetY())) / distance
                end
                local closing = speed - math.max(0, away)
                local gap = math.max(0, distance - attackRange)
                local reach = gap <= 0 and C.HIT_LOCK or (closing > 40 and gap / closing + C.HIT_LOCK or math.huge)
                local escape = math.huge
                for k = 1, #towers do
                    local edge = towers[k].threat - attackRange + C.ENGAGE_MARGIN
                    escape = math.min(escape, math.max(0, towers[k].pos:Distance2D(pos) - edge) / C.CREEP_SPEED)
                end
                local walk = math.max(0, distance - attackRange) / petSpeed + C.HIT_LOCK
                if escape > 0 and reach > escape and walk > escape then
                    urgent[#urgent + 1] = pos
                end
            end
        end
    end
    if #urgent < C.AGGRO_FIREBALL_MIN then
        return false
    end
    local r2 = C.FIREBALL_RADIUS * C.FIREBALL_RADIUS
    local aim, covered = nil, 0
    local candidates = U.circleCandidates(urgent, C.FIREBALL_RADIUS)
    for i = 1, #candidates do
        local c = candidates[i]
        if c:Distance2D(origin) <= range then
            local count = 0
            for k = 1, #urgent do
                if urgent[k]:DistanceSqr2D(c) <= r2 then
                    count = count + 1
                end
            end
            if count > covered then
                aim, covered = c, count
            end
        end
    end
    if aim == nil or covered < C.AGGRO_FIREBALL_MIN then
        return false
    end
    Orders.cast(pet, ability, aim, now, true)
    S.waveAggroCast = true
    Trace.write("dcp fireball", { purpose = "aggro", creeps = covered })
    return true
end

function Phase.packOf(enemies)
    local pack = {}
    for i = 1, #enemies do
        if S.wave[Entity.GetIndex(enemies[i])] then
            pack[#pack + 1] = enemies[i]
        end
    end
    return pack
end

function Phase.aggro(pet, origin, towers, enemies, now)
    local pack = Phase.packOf(enemies)
    if now - S.phaseAt <= C.WAVE_JOIN_WINDOW then
        for i = 1, #enemies do
            local key = Entity.GetIndex(enemies[i])
            if not S.wave[key] and (S.ignored[key] or 0) <= now
                and Entity.GetAbsOrigin(enemies[i]):Distance2D(origin) <= C.DETECT_RADIUS
            then
                S.wave[key] = true
                pack[#pack + 1] = enemies[i]
            end
        end
    end
    S.packCount = #pack

    if #pack == 0 then
        if S.lostSince == 0 then
            S.lostSince = now
        elseif now - S.lostSince >= C.PULL_LOST then
            Phase.set("wait", "wave_lost", now)
        end
        return
    end
    S.lostSince = 0

    local chasers, attackers = 0, 0
    for i = 1, #pack do
        if Aggro.isChasing(pack[i]) then
            chasers = chasers + 1
        end
        if Aggro.isAttacking(pack[i], now)
            and Entity.GetAbsOrigin(pack[i]):Distance2D(origin) <= (NPC.GetAttackRange(pack[i]) or 100) + C.MELEE_SLACK
        then
            attackers = attackers + 1
        end
    end

    if now - S.phaseAt > C.AGGRO_WINDOW then
        Phase.set("wait", "aggro_failed", now, { chasers = chasers, attackers = attackers, pack = #pack })
        return
    end

    local need = math.min(C.AGGRO_ATTACKERS, #pack)
    if attackers >= need or (chasers >= need and S.baitAt > 0 and now - S.baitAt >= C.BAIT_CONFIRM) then
        local camp = S.camp
        if camp == nil or not CampData.readyBy(camp, origin, now) then
            camp = CampData.pattern(S.patternFrom or origin, towers, now, false)
        end
        if camp == nil then
            Phase.set("wait", "no_camp", now, { chasers = chasers, pack = #pack })
            return
        end
        S.camp = camp
        S.lastCamp = camp
        Phase.set("pull", "aggro_ok", now, { chasers = chasers, attackers = attackers, pack = #pack })
        return
    end

    if Phase.aggroFireball(pet, origin, towers, pack, now) then
        return
    end

    if S.action ~= nil then
        return
    end

    local candidates = {}
    for i = 1, #pack do
        local pos = Entity.GetAbsOrigin(pack[i])
        if not Aggro.isAttacking(pack[i], now) and not U.isRanged(pack[i])
            and Phase.safeTarget(pos, towers, pet) and Phase.safeBait(pos, towers, origin)
        then
            candidates[#candidates + 1] = pack[i]
        end
    end
    if #candidates == 0 then
        for i = 1, #pack do
            local pos = Entity.GetAbsOrigin(pack[i])
            if Phase.safeTarget(pos, towers, pet) and Phase.safeBait(pos, towers, origin) then
                candidates[#candidates + 1] = pack[i]
            end
        end
    end
    local target, targetD = U.nearestOf(candidates, origin)
    if target == nil then
        return
    end
    if targetD > C.AGGRO_APPROACH + C.APPROACH_SLACK then
        S.reason = "approach"
        S.baitAt = 0
        Nav.go(pet, origin, Entity.GetAbsOrigin(target):Extend2D(origin, C.AGGRO_APPROACH), towers, now)
        return
    end
    S.reason = "baiting"
    if S.baitAt == 0 then
        S.baitAt = now
    end
    local away = S.camp ~= nil and S.camp.pos or Entity.GetAbsOrigin(target):Extend2D(origin, Phase.keepAway(pet))
    Nav.go(pet, origin, away, towers, now)
end

function Phase.pull(pet, origin, towers, enemies, now)
    local camp = S.camp
    local pack = Phase.packOf(enemies)
    S.packCount = #pack
    if S.pullDeadline == 0 then
        S.pullDeadline = now + C.PULL_MAX
        S.nextPullLog = now
    end
    if now > S.pullDeadline and (S.noAggroSince == 0 or now - S.noAggroSince >= C.PULL_NO_AGGRO) then
        Phase.set("wait", "pull_timeout", now, { pack = #pack })
        return
    end

    if #pack == 0 then
        if S.lostSince == 0 then
            S.lostSince = now
        elseif now - S.lostSince >= C.PULL_LOST then
            Phase.set("wait", "pack_lost", now)
            return
        end
        S.reason = "pack_gone"
        if S.action ~= nil then
            Orders.cancel()
        end
        Nav.go(pet, origin, camp.pos, towers, now)
        return
    end
    S.lostSince = 0

    local chasers = {}
    for i = 1, #pack do
        if Aggro.follows(pack[i], origin, now) then
            chasers[#chasers + 1] = pack[i]
        end
    end
    if #chasers == 0 and S.noAggroSince == 0 then
        S.noAggroSince = now
    end

    if #chasers == 0 then
        if #pack < C.REBAIT_MIN_PACK then
            Phase.set("wait", "pack_thin", now, { pack = #pack })
            return
        end
        if now - S.noAggroSince < C.PULL_NO_AGGRO then
            S.reason = "rebait"
            local safe = {}
            for i = 1, #pack do
                local pos = Entity.GetAbsOrigin(pack[i])
                if Phase.safeTarget(pos, towers, pet) and Phase.safeBait(pos, towers, origin) then
                    safe[#safe + 1] = pack[i]
                end
            end
            local back, backD = U.nearestOf(safe, origin)
            if S.action == nil and back ~= nil then
                local keep = backD > C.AGGRO_APPROACH + C.APPROACH_SLACK and C.AGGRO_APPROACH or Phase.keepAway(pet)
                Nav.go(pet, origin, Entity.GetAbsOrigin(back):Extend2D(origin, keep), towers, now)
            end
            return
        end
        Phase.set("wait", "aggro_dropped", now, { pack = #pack })
        return
    end
    S.noAggroSince = 0

    local neutrals = CampData.neutrals(camp.pos, camp.radius + C.CAMP_NEUTRAL_SLACK)
    local target = camp.pos
    if #neutrals > 0 then
        local positions = {}
        for i = 1, #neutrals do
            positions[i] = Entity.GetAbsOrigin(neutrals[i])
        end
        target = U.centroid(positions)
    end

    if #neutrals == 0 and U.spawnWindow() then
        target = camp.pos:Extend2D(origin, camp.radius + C.CAMP_BLOCK_MARGIN)
    end

    if #neutrals == 0 and not CampData.readyBy(camp, origin, now) then
        local nextCamp = CampData.pattern(S.patternFrom or origin, towers, now, false, camp)
        if nextCamp ~= nil and nextCamp.pos:Distance2D(origin) > C.CAMP_SWITCH_MAX then
            nextCamp = nil
        end
        Trace.write("dcp camp switch", { x = camp.pos:GetX(), y = camp.pos:GetY(), found = nextCamp ~= nil })
        if nextCamp ~= nil then
            S.camp = nextCamp
            S.lastCamp = nextCamp
            return
        end
        Phase.set("wait", "camp_empty", now, { pack = #pack })
        return
    end

    local nearChasers = 0
    for i = 1, #chasers do
        if Entity.GetAbsOrigin(chasers[i]):Distance2D(origin) <= C.ARRIVE_CHASERS then
            nearChasers = nearChasers + 1
        end
    end

    if origin:Distance2D(target) <= C.MERGE_ARRIVE and nearChasers >= 1 then
        if #neutrals == 0 then
            S.reason = "confirm_camp"
            if U.spawnWindow() then
                S.pullDeadline = S.pullDeadline + S.tickDt
            end
            if S.action == nil then
                if origin:Distance2D(target) > C.WAYPOINT_REACHED then
                    Orders.move(pet, target, now, false)
                else
                    Phase.stepAway(pet, origin, enemies, towers, now, camp.pos)
                end
            end
            return
        end
        Phase.set("merge", "arrived", now, { neutrals = #neutrals, chasers = #chasers, pack = #pack })
        return
    end

    if S.action ~= nil then
        return
    end

    local slack = -math.huge
    for i = 1, #chasers do
        local lead = math.max(C.PULL_LEAD, (NPC.GetAttackRange(chasers[i]) or 100) + C.PULL_RANGE_SLACK)
        slack = math.max(slack, Entity.GetAbsOrigin(chasers[i]):Distance2D(origin) - lead)
    end
    if S.leadHold then
        S.leadHold = slack > C.LEAD_RESUME
    else
        S.leadHold = #chasers > 0 and slack > C.LEAD_HOLD
    end
    if S.leadHold then
        S.reason = "lead_wait"
        local straggler, worst = nil, -math.huge
        for i = 1, #chasers do
            local pos = Entity.GetAbsOrigin(chasers[i])
            local lead = math.max(C.PULL_LEAD, (NPC.GetAttackRange(chasers[i]) or 100) + C.PULL_RANGE_SLACK)
            local gap = pos:Distance2D(origin) - lead
            if gap > worst then
                straggler, worst = { pos = pos, lead = lead }, gap
            end
        end
        if straggler ~= nil then
            Nav.go(pet, origin, straggler.pos:Extend2D(target, straggler.lead + C.KEEP_AWAY), towers, now)
        end
        return
    end
    S.reason = "lead"
    if now >= S.nextPullLog then
        S.nextPullLog = now + C.PULL_LOG
        local near, far = math.huge, 0
        for i = 1, #chasers do
            local d = Entity.GetAbsOrigin(chasers[i]):Distance2D(origin)
            near = math.min(near, d)
            far = math.max(far, d)
        end
        Trace.write("dcp lead", {
            camp_d = math.floor(origin:Distance2D(camp.pos)),
            target_d = math.floor(origin:Distance2D(target)),
            pack = #pack,
            chasers = #chasers,
            near = math.floor(near),
            far = math.floor(far),
            slack = math.floor(slack),
            neutrals = #neutrals,
        })
    end
    Nav.go(pet, origin, target, towers, now)
end

function Phase.contact(lanes, neutrals)
    local best, bestD = nil, math.huge
    for i = 1, #lanes do
        local a = Entity.GetAbsOrigin(lanes[i])
        for k = 1, #neutrals do
            local d = a:Distance2D(Entity.GetAbsOrigin(neutrals[k]))
            if d < bestD then
                best, bestD = true, d
            end
        end
    end
    return best ~= nil and bestD <= C.CONTACT_DIST, bestD
end

function Phase.merge(pet, origin, towers, enemies, now)
    local camp = S.camp
    local neutrals = CampData.neutrals(camp.pos, camp.radius + 300)
    local lanes = {}
    for i = 1, #enemies do
        if Entity.GetAbsOrigin(enemies[i]):Distance2D(origin) <= C.FOLLOW_RADIUS then
            lanes[#lanes + 1] = enemies[i]
        end
    end
    S.packCount = #lanes

    local touching, gap = Phase.contact(lanes, neutrals)
    if touching then
        Phase.set("farm", "contact", now, { neutrals = #neutrals, lane = #lanes, gap = gap })
        return
    end

    if #neutrals == 0 then
        Phase.set("wait", "neutrals_gone", now, { lane = #lanes })
        return
    end
    if #lanes == 0 then
        Phase.set("wait", "lane_gone", now, { neutrals = #neutrals })
        return
    end
    if now - S.phaseAt > C.MERGE_MAX then
        Phase.set("wait", "merge_timeout", now, { neutrals = #neutrals, lane = #lanes, gap = gap })
        return
    end

    if S.action ~= nil then
        return
    end

    local neutralPositions = {}
    for i = 1, #neutrals do
        neutralPositions[i] = Entity.GetAbsOrigin(neutrals[i])
    end
    local center = U.centroid(neutralPositions)

    if not S.engaged then
        S.engaged = true
        local lanePositions = {}
        for i = 1, #lanes do
            lanePositions[i] = Entity.GetAbsOrigin(lanes[i])
        end
        local from = U.centroid(lanePositions) or origin
        local exit = U.away(from, center, C.MERGE_EXIT)
        if World.insideTowers(exit, towers, C.ROUTE_MARGIN) ~= nil or not U.traversable(exit)
            or not Nav.segmentClear(origin, exit, towers)
        then
            exit = U.away(origin, center, C.MERGE_EXIT * 0.5)
            if World.insideTowers(exit, towers, C.ROUTE_MARGIN) ~= nil or not U.traversable(exit)
                or not Nav.segmentClear(origin, exit, towers)
            then
                exit = nil
            end
        end
        S.exitPoint = exit
        Trace.write("dcp merge walk", { neutrals = #neutrals, lane = #lanes, gap = gap })
    end

    if S.exitPoint ~= nil and origin:Distance2D(S.exitPoint) > C.MERGE_EXIT_REACHED then
        Orders.move(pet, S.exitPoint, now, false)
        return
    end
    Phase.stepAway(pet, origin, neutrals, towers, now, camp.pos)
end

function Phase.farm(pet, origin, towers, enemies, now)
    local camp = S.camp
    local neutrals = CampData.neutrals(origin, C.FARM_SCAN)
    local lanes = {}
    for i = 1, #enemies do
        if Entity.GetAbsOrigin(enemies[i]):Distance2D(origin) <= C.FARM_SCAN then
            lanes[#lanes + 1] = enemies[i]
        end
    end
    S.packCount = #lanes

    if #neutrals == 0 and #lanes == 0 then
        if camp ~= nil then
            CampData.markRespawn(camp, now)
        end
        Phase.set("wait", "farm_done", now)
        return
    end
    if now - S.phaseAt > C.FARM_MAX then
        Phase.set("wait", "farm_timeout", now, { neutrals = #neutrals, lane = #lanes })
        return
    end

    if options.fireball:Get() and S.action == nil and #neutrals > 0 and #lanes > 0 then
        local ability = Dragon.fireball(pet)
        if ability ~= nil then
            local range = Dragon.castRange(pet, ability)
            local points, isLane = {}, {}
            for i = 1, #lanes do
                points[#points + 1] = Entity.GetAbsOrigin(lanes[i])
                isLane[#points] = true
            end
            for i = 1, #neutrals do
                points[#points + 1] = Entity.GetAbsOrigin(neutrals[i])
                isLane[#points] = false
            end
            local r2 = C.FIREBALL_RADIUS * C.FIREBALL_RADIUS
            local candidates = U.circleCandidates(points, C.FIREBALL_RADIUS)
            local best, bestTotal, bestLane, bestNeutral = nil, 0, 0, 0
            for i = 1, #candidates do
                local c = candidates[i]
                if c:Distance2D(origin) <= range then
                    local laneCount, neutralCount = 0, 0
                    for k = 1, #points do
                        if points[k]:DistanceSqr2D(c) <= r2 then
                            if isLane[k] then
                                laneCount = laneCount + 1
                            else
                                neutralCount = neutralCount + 1
                            end
                        end
                    end
                    local total = laneCount + neutralCount
                    if laneCount > 0 and neutralCount > 0 and total > bestTotal then
                        best, bestTotal, bestLane, bestNeutral = c, total, laneCount, neutralCount
                    end
                end
            end
            if best ~= nil and bestTotal >= options.minTargets:Get() then
                if bestTotal > S.clumpBest then
                    S.clumpBest = bestTotal
                    S.clumpAt = now
                end
                local settled = now - S.clumpAt >= C.CLUMP_SETTLE
                local timeUp = now - S.phaseAt >= C.CLUMP_MAX
                if bestTotal >= #points or settled or timeUp then
                    Orders.cast(pet, ability, best, now)
                    Trace.write("dcp fireball", {
                        purpose = "farm",
                        lane = bestLane,
                        neutrals = bestNeutral,
                        waited = math.floor((now - S.phaseAt) * 10) / 10,
                    })
                    return
                end
                S.reason = "clump"
                local hold = U.nearestOf(lanes, origin)
                if hold ~= nil then
                    Nav.go(pet, origin, Entity.GetAbsOrigin(hold):Extend2D(origin, Phase.keepAway(pet)), towers, now)
                end
                return
            end
        end
    end

    local units = {}
    for i = 1, #lanes do
        units[#units + 1] = lanes[i]
    end
    for i = 1, #neutrals do
        units[#units + 1] = neutrals[i]
    end
    local target = Phase.stickyTarget(units, origin)
    if target ~= nil then
        Orders.attack(pet, target, now, false)
    end
end

function Phase.tick(now)
    World.scanStructures(now)
    local pet = Dragon.find()
    S.pet = pet
    if pet == nil then
        S.petPos = nil
        if S.phase ~= "wait" then
            Phase.set("wait", "no_dragon", now)
        end
        S.reason = "no_dragon"
        return
    end

    local origin = Entity.GetAbsOrigin(pet)
    S.petPos = origin
    local dt = S.lastTickNow ~= nil and math.min(math.max(now - S.lastTickNow, 0), C.TICK * 5) or C.TICK
    S.lastTickNow = now
    S.tickDt = dt
    Orders.updateAction(pet, now)
    S.night = World.isNight()

    local towers = World.towers()
    CampData.observe(origin, now)

    local enemies = Dragon.laneCreeps(pet, E.TEAM_ENEMY, C.FARM_SCAN * 1.5)
    local alliedCreeps = Dragon.laneCreeps(pet, E.TEAM_FRIEND, C.CHASE_RADIUS * 1.5)
    local allies = {}
    for i = 1, #alliedCreeps do
        allies[i] = Entity.GetAbsOrigin(alliedCreeps[i])
    end
    Aggro.update(pet, enemies, allies, now)

    if now < S.manualUntil then
        S.reason = "manual"
        Orders.cancel()
        return
    end

    if Phase.safety(pet, origin, towers, now) then
        return
    end

    if S.phase == "wait" or S.phase == "pull" then
        local box = U.spawnWindow() and CampData.boxAt(origin) or nil
        if box ~= nil and #CampData.neutrals(box.pos, box.radius + C.CAMP_NEUTRAL_SLACK) == 0 then
            if S.phase == "wait" then
                S.reason = "leave_box"
            end
            S.phaseAt = S.phaseAt + dt
            if S.phase == "pull" and S.pullDeadline > 0 then
                S.pullDeadline = S.pullDeadline + dt
            end
            if S.lostSince > 0 then
                S.lostSince = S.lostSince + dt
            end
            if S.noAggroSince > 0 then
                S.noAggroSince = S.noAggroSince + dt
            end
            Nav.go(pet, origin, CampData.boxExit(box, origin, towers), towers, now)
            return
        end
    end

    if S.phase == "wait" then
        Phase.wait(pet, origin, towers, enemies, now)
    elseif S.phase == "aggro" then
        Phase.aggro(pet, origin, towers, enemies, now)
    elseif S.phase == "pull" then
        Phase.pull(pet, origin, towers, enemies, now)
    elseif S.phase == "merge" then
        Phase.merge(pet, origin, towers, enemies, now)
    elseif S.phase == "farm" then
        Phase.farm(pet, origin, towers, enemies, now)
    end
end

function Draw.text(pos, text, dy, color)
    local screen, visible = Render.WorldToScreen(pos)
    if visible then
        Render.Text(S.font, C.FONT_SIZE, text, Vec2(screen:GetX() - 60, screen:GetY() + dy), color)
    end
end

function Draw.overlay()
    if not options.ready or not options.enabled:Get() or not options.overlay:Get() then
        return
    end
    if S.font == nil or S.petPos == nil then
        return
    end
    Draw.text(S.petPos, string.format("%s | %s", S.phase, S.reason), -44, Color(120, 255, 160, 255))
    Draw.text(S.petPos, string.format(localization.Get(T.overlayStats), #S.chasers, S.packCount, S.lane or "-"), -26, Color(140, 200, 255, 255))
    local chaseLabel = localization.Get(T.overlayChase)
    for i = 1, #S.chaserMarks do
        Draw.text(S.chaserMarks[i], chaseLabel, -30, Color(255, 90, 90, 255))
    end
    if S.watch ~= nil and S.phase == "wait" then
        Draw.text(S.watch.pos, localization.Get(S.watch.hidden and T.overlayWatch or T.overlayWatchSeen), -8, Color(140, 200, 255, 255))
    end
    local camp = S.camp or (S.watch ~= nil and S.watch.camp or nil)
    if camp ~= nil then
        Draw.text(camp.pos, localization.Get(T.overlayCamp), -8, Color(255, 210, 110, 255))
    end
end

function Draw.error(message)
    if S.errorFont == nil then
        S.errorFont = Render.LoadFont("MuseoSansEx", E.FONT_ANTIALIAS, 500)
    end
    Render.FilledRect(Vec2(20, 120), Vec2(900, 150), Color(120, 20, 20, 220))
    Render.Text(S.errorFont, 14, C.SCRIPT_ID .. ": " .. message, Vec2(28, 127), Color(255, 255, 255, 255))
end

function Life.menu()
    local root = Menu.Create("Scripts", "Dragon", "Dragon camp pull")
    if root == nil then
        return false
    end
    local tab = root:Create("Main")
    local main = tab:Create(T.groupMain, E.GROUP_LEFT)
    local fire = tab:Create(T.groupFireball, E.GROUP_RIGHT)

    options.enabled = main:Switch(T.enabled, false, "\u{f1bb}")
    options.enabled:ToolTip(T.enabledTip)
    options.enabled:SetCallback(function()
        if not options.enabled:Get() and S.player ~= nil and S.pet ~= nil then
            pcall(Player.HoldPosition, S.player, S.pet, false, false, false, "dcp_disabled")
        end
        Life.reset(true)
    end)

    options.overlay = main:Switch(T.overlay, true, "\u{f188}")
    options.overlay:ToolTip(T.overlayTip)

    options.fireball = fire:Switch(T.fireball, true, "\u{f06d}")
    options.fireball:ToolTip(T.fireballTip)

    options.fireballAggro = fire:Switch(T.fireballAggro, false, "\u{f0e7}")
    options.fireballAggro:ToolTip(T.fireballAggroTip)

    options.minTargets = fire:Slider(T.minTargets, 2, 8, 3, "%d")
    options.minTargets:ToolTip(T.minTargetsTip)

    return true
end

function Life.loaded()
    S.font = Render.LoadFont("MuseoSansEx", E.FONT_ANTIALIAS, 500)
    options.ready = Life.menu()
    if not options.ready then
        S.loadError = "Menu.Create returned nil"
    end
    Trace.write("dcp loaded", { version = C.VERSION, menu_ready = options.ready })
end

function Life.update()
    if not options.ready or not options.enabled:Get() then
        return
    end
    local hero = Heroes.GetLocal()
    local player = Players.GetLocal()
    if hero == nil or player == nil then
        return
    end
    local now = GameRules.GetGameTime()
    if now + C.TIME_JUMP < S.lastNow then
        Life.reset(false)
    end
    S.lastNow = now
    if now < S.nextTick and S.nextTick - now <= C.TICK * 2 then
        return
    end
    S.nextTick = now + C.TICK
    S.player = player
    S.team = Entity.GetTeamNum(hero)
    S.playerId = Hero.GetPlayerID(hero)
    Phase.tick(now)
end

function Life.reset(keepWorld)
    S.pet = nil
    S.petPos = nil
    S.player = nil
    S.team = 0
    S.playerId = -1
    S.blocked = {}
    S.drawError = nil
    S.cycle = S.cycle + 1
    S.phase = "wait"
    S.phaseAt = 0
    S.reason = "-"
    S.lane = nil
    S.watch = nil
    S.camp = nil
    S.wave = {}
    S.waveAggroCast = false
    S.track = {}
    S.ignored = {}
    S.chasers = {}
    S.chaserMarks = {}
    S.packCount = 0
    S.pullDeadline = 0
    S.action = nil
    S.manualUntil = 0
    S.lastOrder = nil
    S.lostSince = 0
    S.noAggroSince = 0
    S.leadHold = false
    S.baitAt = 0
    S.clumpBest = 0
    S.clumpAt = 0
    S.nextPullLog = 0
    S.fightTarget = nil
    S.engaged = false
    S.exitPoint = nil
    S.fighting = false
    S.detour = nil
    S.lastCamp = nil
    S.retreating = false
    S.fleeUntil = 0
    S.towerEscapeUntil = 0
    S.towerEscapePos = nil
    S.towerEscapeKey = nil
    S.towerEscapePlanAt = 0
    S.nextTick = 0
    S.nextStructureScan = 0
    S.nextWatchRefresh = 0
    S.nextCampScan = 0
    S.lastMinute = nil
    S.lastTickNow = nil
    S.lastScanAt = nil
    S.laneFailSince = 0
    S.patternFrom = nil
    S.nextWaitLog = 0
    S.nextSkipLog = 0
    S.lastNow = 0
    if not keepWorld then
        S.laneMap = {}
        S.campList = nil
        S.homePos = nil
    end
end

function Life.gameEnd()
    Life.reset(false)
end

function Life.orders(data)
    if not options.ready or not options.enabled:Get() or data == nil or S.pet == nil then
        return true
    end
    local manual = data.npc == S.pet
    if not manual and data.orderIssuer ~= E.ISSUER_PASSED_UNIT and data.player ~= nil and type(Player.GetSelectedUnits) == "function" then
        local ok, selected = pcall(Player.GetSelectedUnits, data.player)
        if ok and type(selected) == "table" then
            for i = 1, #selected do
                if selected[i] == S.pet then
                    manual = true
                    break
                end
            end
        end
    end
    if manual then
        S.manualUntil = GameRules.GetGameTime() + C.MANUAL_HOLD
    end
    return true
end

function script.OnScriptsLoaded()
    local ok, err = pcall(Life.loaded)
    if not ok then
        S.loadError = tostring(err)
    end
end

function script.OnUpdate()
    return Life.update()
end

function script.OnDraw()
    local ok, err = pcall(Draw.overlay)
    S.drawError = not ok and tostring(err) or nil
    local message = S.loadError or S.drawError
    if message ~= nil then
        Draw.error(message)
    end
end

function script.OnPrepareUnitOrders(data)
    return Life.orders(data)
end

function script.OnGameEnd()
    return Life.gameEnd()
end

return script
