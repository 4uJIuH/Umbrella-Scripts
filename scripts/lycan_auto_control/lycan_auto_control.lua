--[[
    Lycan Auto Control
    Wolves push the nearest lane from the local hero; Dominator units farm own jungle with abilities.
    Script by 花曇り hanagumori
--]]

local Script = {}

--#region Constants
local NAME = "LycanAutoControl"
local UPDATE_INTERVAL = 0.15
local ORDER_THROTTLE = 0.90
local OVERRIDE_PAUSE = 2.5
local CAMP_BOX_PAD = 120
local CAMP_ARRIVE_DIST_SQR = 320 * 320
local CAMP_SPAWN_INTERVAL = 60
local CAMP_EMPTY_CONFIRM = 2
local WOLF_CREEP_SCAN = 1800
local WOLF_STRUCTURE_SCAN = 700
local DOM_MIN_MANA_PCT = 0.25
local ABILITY_INDEX_MAX = 24
local MID_LANE_DIFF = 1800

local ORDER_PREFIX = "lycan.ac."
local ID_WOLF_PUSH = ORDER_PREFIX .. "wolf.push"
local ID_DOM_ATTACK = ORDER_PREFIX .. "dom.attack"
local ID_DOM_CAST = ORDER_PREFIX .. "dom.cast"

local STATE_DOMINATED = 31

local LANE_TOP = 1
local LANE_MID = 2
local LANE_BOT = 3

local TEAM_RADIANT = Enum.TeamNum.TEAM_RADIANT
local TEAM_ENEMY = Enum.TeamType.TEAM_ENEMY
local ISSUER_UNIT = Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY
local ORDER_ATTACK_MOVE = Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_MOVE
local CAST_READY = Enum.AbilityCastResult.READY

local BEHAVIOR_NO_TARGET = Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_NO_TARGET
local BEHAVIOR_UNIT_TARGET = Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_UNIT_TARGET
local BEHAVIOR_POINT = Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_POINT
local BEHAVIOR_ITEM = Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_ITEM
local BEHAVIOR_TOGGLE = Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_TOGGLE
local BEHAVIOR_VECTOR = Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_VECTOR_TARGETING

local FOUNTAIN_RADIANT = Vector(-7200, -6666, 384)
local FOUNTAIN_DIRE = Vector(7200, 6666, 384)

local HERO_NAME = "npc_dota_hero_lycan"
local STATUS_LABEL = "Auto Control"
local STATUS_FONT_SIZE = 13
local STATUS_LINE_HALF_WIDTH = 48
local STATUS_LINE_HEIGHT = 2.5
local STATUS_ABOVE_BAR = 52
local STATUS_TEXT_ABOVE_LINE = 6
--#endregion

--#region State
---@class LycanAutoControlUI
---@field enabled CMenuSwitch|nil
---@field control CMenuBind|nil
---@field wolvesPush CMenuSwitch|nil
---@field dominatorFarm CMenuSwitch|nil
local UI = {
    enabled = nil,
    control = nil,
    wolvesPush = nil,
    dominatorFarm = nil,
}

local Persistent = {
    ---@type Logger|nil
    logger = nil,
    ---@type integer|nil
    font = nil,
}

---@class LycanLaneChain
---@field lane integer
---@field structures userdata[]

local Runtime = {
    lastUpdateAt = -math.huge,
    ---@type table<integer, number>
    lastOrderAt = {},
    ---@type table<integer, number>
    overrideUntil = {},
    ---@type table<integer, boolean>
    managed = {},
    ---@type table<integer, string>
    domCampKey = {},
    ---@type table<integer, boolean>
    domEverAssigned = {},
    ---@type table<string, number>
    domClearedAt = {},
    ---@type table<string, integer>
    domEmptyStreak = {},
    ---@type LycanLaneChain[]|nil
    laneChains = nil,
    ownTeam = nil,
    ownFountain = nil,
    enemyFountain = nil,
    enemyFortPos = nil,
}
--#endregion

--#region Helpers
local function ResetRuntime()
    Runtime.lastUpdateAt = -math.huge
    Runtime.lastOrderAt = {}
    Runtime.overrideUntil = {}
    Runtime.managed = {}
    Runtime.domCampKey = {}
    Runtime.domEverAssigned = {}
    Runtime.domClearedAt = {}
    Runtime.domEmptyStreak = {}
    Runtime.laneChains = nil
    Runtime.ownTeam = nil
    Runtime.ownFountain = nil
    Runtime.enemyFountain = nil
    Runtime.enemyFortPos = nil
end

local function IsFeatureActive()
    return UI.enabled ~= nil
        and UI.enabled:Get() == true
        and UI.control ~= nil
        and UI.control:IsToggled() == true
end

local function NeonColor(hue, alpha)
    local h = hue % 1.0
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local q = 1.0 - f
    local r, g, b
    if i == 0 then
        r, g, b = 1.0, f, 0.0
    elseif i == 1 then
        r, g, b = q, 1.0, 0.0
    elseif i == 2 then
        r, g, b = 0.0, 1.0, f
    elseif i == 3 then
        r, g, b = 0.0, q, 1.0
    elseif i == 4 then
        r, g, b = f, 0.0, 1.0
    else
        r, g, b = 1.0, 0.0, q
    end
    return Color(math.floor(r * 255), math.floor(g * 255), math.floor(b * 255), alpha)
end

local function DrawStatusOverlay(me)
    local font = Persistent.font
    if font == nil then
        return
    end

    local x, y, z = Entity.GetAbsOriginXYZ(me)
    local barOffset = NPC.GetHealthBarOffset(me)
    local screen, visible = Render.WorldToScreen(Vector(x, y, z + barOffset))
    if visible ~= true then
        return
    end

    local textSize = Render.TextSize(font, STATUS_FONT_SIZE, STATUS_LABEL)
    local halfW = math.max(STATUS_LINE_HALF_WIDTH, textSize.x * 0.55)
    local lineY = screen.y - STATUS_ABOVE_BAR
    local textPos = Vec2(
        screen.x - textSize.x * 0.5,
        lineY - textSize.y - STATUS_TEXT_ABOVE_LINE
    )

    Render.Text(font, STATUS_FONT_SIZE, STATUS_LABEL, Vec2(textPos.x + 1, textPos.y + 1), Color(0, 0, 0, 180))
    Render.Text(font, STATUS_FONT_SIZE, STATUS_LABEL, textPos, Color(255, 255, 255, 245))

    local pulse = GameRules.GetGameTime() * 1.1
    local hue = pulse * 0.18
    local cL = NeonColor(hue, 255)
    local cR = NeonColor(hue + 0.42, 255)
    local lineStart = Vec2(screen.x - halfW, lineY)
    local lineEnd = Vec2(screen.x + halfW, lineY + STATUS_LINE_HEIGHT)

    Render.Shadow(
        Vec2(screen.x - halfW - 2, lineY - 2),
        Vec2(screen.x + halfW + 2, lineY + STATUS_LINE_HEIGHT + 2),
        NeonColor(hue + 0.15, 100),
        16,
        2
    )
    Render.Gradient(lineStart, lineEnd, cL, cR, cL, cR, 1.5)

    local coreY = lineY + STATUS_LINE_HEIGHT * 0.35
    Render.Gradient(
        Vec2(screen.x - halfW, coreY),
        Vec2(screen.x + halfW, coreY + 1.0),
        Color(255, 255, 255, 70),
        Color(255, 255, 255, 70),
        Color(255, 255, 255, 40),
        Color(255, 255, 255, 40),
        1.0
    )

    local shimmer = 0.5 + 0.5 * math.sin(pulse * 5.0)
    local shimmerHalf = halfW * (0.22 + 0.08 * shimmer)
    local shimmerX = screen.x + math.sin(pulse * 2.4) * (halfW * 0.55)
    Render.Gradient(
        Vec2(shimmerX - shimmerHalf, lineY),
        Vec2(shimmerX + shimmerHalf, lineY + STATUS_LINE_HEIGHT),
        Color(255, 255, 255, 0),
        Color(255, 255, 255, math.floor(140 * shimmer)),
        Color(255, 255, 255, 0),
        Color(255, 255, 255, math.floor(90 * shimmer)),
        1.0
    )
end

local function SyncOptionDisabled()
    local disabled = not UI.enabled or UI.enabled:Get() ~= true
    if UI.control then
        UI.control:Disabled(disabled)
    end
    if UI.wolvesPush then
        UI.wolvesPush:Disabled(disabled)
    end
    if UI.dominatorFarm then
        UI.dominatorFarm:Disabled(disabled)
    end
end

local function OnEnabledChanged()
    SyncOptionDisabled()
    if not UI.enabled or UI.enabled:Get() ~= true then
        if UI.control then
            UI.control:SetToggled(false)
        end
        ResetRuntime()
    end
end

local function GameClock()
    local start = GameRules.GetGameStartTime()
    if start == nil then
        return GameRules.GetGameTime()
    end
    return GameRules.GetGameTime() - start
end

local function IsCampCoolingDown(key, clockNow)
    local clearedAt = Runtime.domClearedAt[key]
    if clearedAt == nil then
        return false
    end
    local respawnAt = math.floor(clearedAt / CAMP_SPAWN_INTERVAL) * CAMP_SPAWN_INTERVAL + CAMP_SPAWN_INTERVAL
    return clockNow < respawnAt
end

local function MarkCampCleared(key, clockNow)
    Runtime.domClearedAt[key] = clockNow
    Runtime.domEmptyStreak[key] = 0
end

local function NoteCampAlive(key)
    Runtime.domClearedAt[key] = nil
    Runtime.domEmptyStreak[key] = 0
end

local function IsLocalLycan(me)
    local name = NPC.GetUnitName(me)
    return name == HERO_NAME
end

local function DistSqr2D(a, b)
    return a:DistanceSqr2D(b)
end

local function ClassifyLane(pos)
    local diff = pos.x - pos.y
    if math.abs(diff) < MID_LANE_DIFF then
        return LANE_MID
    end
    if pos.y > pos.x then
        return LANE_TOP
    end
    return LANE_BOT
end

local function LaneChainsHaveObjectives()
    local chains = Runtime.laneChains
    if chains == nil then
        return false
    end
    for i = 1, #chains do
        if #chains[i].structures > 0 then
            return true
        end
    end
    return Runtime.enemyFortPos ~= nil
end

local function FindEnemyFortPos(me)
    local npcs = NPCs.GetAll()
    for i = 1, #npcs do
        local npc = npcs[i]
        if npc
            and Entity.IsAlive(npc) == true
            and Entity.IsSameTeam(npc, me) ~= true
            and NPC.IsFort(npc) == true
        then
            return Entity.GetAbsOrigin(npc)
        end
    end
    return nil
end

local function EnsureMatchAnchors(me)
    local team = Entity.GetTeamNum(me)
    if Runtime.ownTeam == team and LaneChainsHaveObjectives() then
        return
    end

    Runtime.ownTeam = team
    if team == TEAM_RADIANT then
        Runtime.ownFountain = FOUNTAIN_RADIANT
        Runtime.enemyFountain = FOUNTAIN_DIRE
    else
        Runtime.ownFountain = FOUNTAIN_DIRE
        Runtime.enemyFountain = FOUNTAIN_RADIANT
    end

    ---@type table<integer, userdata[]>
    local buckets = {
        [LANE_TOP] = {},
        [LANE_MID] = {},
        [LANE_BOT] = {},
    }

    local towers = Towers.GetAll()
    for i = 1, #towers do
        local tower = towers[i]
        if tower
            and Entity.IsAlive(tower) == true
            and Entity.IsSameTeam(tower, me) ~= true
        then
            local lane = ClassifyLane(Entity.GetAbsOrigin(tower))
            buckets[lane][#buckets[lane] + 1] = tower
        end
    end

    local npcs = NPCs.GetAll()
    for i = 1, #npcs do
        local npc = npcs[i]
        if npc
            and Entity.IsAlive(npc) == true
            and Entity.IsSameTeam(npc, me) ~= true
            and NPC.IsBarracks(npc) == true
        then
            local lane = ClassifyLane(Entity.GetAbsOrigin(npc))
            buckets[lane][#buckets[lane] + 1] = npc
        end
    end

    local ownFountain = Runtime.ownFountain
    local function SortByPushProgress(list)
        table.sort(list, function(a, b)
            return DistSqr2D(Entity.GetAbsOrigin(a), ownFountain)
                < DistSqr2D(Entity.GetAbsOrigin(b), ownFountain)
        end)
    end

    SortByPushProgress(buckets[LANE_TOP])
    SortByPushProgress(buckets[LANE_MID])
    SortByPushProgress(buckets[LANE_BOT])

    Runtime.enemyFortPos = FindEnemyFortPos(me)
    Runtime.laneChains = {
        { lane = LANE_TOP, structures = buckets[LANE_TOP] },
        { lane = LANE_MID, structures = buckets[LANE_MID] },
        { lane = LANE_BOT, structures = buckets[LANE_BOT] },
    }
end

local function RefreshLaneChains(me)
    if Runtime.laneChains == nil then
        EnsureMatchAnchors(me)
        return
    end

    for ci = 1, #Runtime.laneChains do
        local chain = Runtime.laneChains[ci]
        local alive = {}
        for i = 1, #chain.structures do
            local structure = chain.structures[i]
            if structure and Entity.IsAlive(structure) == true then
                alive[#alive + 1] = structure
            end
        end
        chain.structures = alive
    end

    if Runtime.enemyFortPos == nil then
        Runtime.enemyFortPos = FindEnemyFortPos(me)
    end
end

local function NearestLaneChain(heroPos)
    local chains = Runtime.laneChains
    if chains == nil then
        return nil
    end

    local bestChain = nil
    local bestDist = math.huge
    for i = 1, #chains do
        local chain = chains[i]
        local structures = chain.structures
        if #structures == 0 then
            local endPos = Runtime.enemyFortPos or Runtime.enemyFountain
            if endPos then
                local d = DistSqr2D(heroPos, endPos)
                if d < bestDist then
                    bestDist = d
                    bestChain = chain
                end
            end
        else
            for s = 1, #structures do
                local d = DistSqr2D(heroPos, Entity.GetAbsOrigin(structures[s]))
                if d < bestDist then
                    bestDist = d
                    bestChain = chain
                end
            end
        end
    end
    return bestChain
end

local function LaneObjectivePos(chain)
    if chain == nil then
        return Runtime.enemyFortPos or Runtime.enemyFountain
    end
    local structures = chain.structures
    for i = 1, #structures do
        local structure = structures[i]
        if structure and Entity.IsAlive(structure) == true then
            return Entity.GetAbsOrigin(structure)
        end
    end
    return Runtime.enemyFortPos or Runtime.enemyFountain
end

local function UnitIndex(unit)
    return Entity.GetIndex(unit)
end

local function IsOverridden(index, now)
    local untilAt = Runtime.overrideUntil[index]
    return untilAt ~= nil and now < untilAt
end

local function CanOrder(index, now)
    if IsOverridden(index, now) then
        return false
    end
    local last = Runtime.lastOrderAt[index]
    if last ~= nil and now - last < ORDER_THROTTLE then
        return false
    end
    return true
end

local function MarkOrdered(index, now)
    Runtime.lastOrderAt[index] = now
end

local function IsLycanWolf(unit)
    local name = NPC.GetUnitName(unit)
    return type(name) == "string" and string.find(name, "lycan_wolf", 1, true) ~= nil
end

local function IsDominatedUnit(unit)
    return NPC.HasState(unit, STATE_DOMINATED) == true
end

local function CollectUnits(me, playerId)
    ---@type userdata[]
    local wolves = {}
    ---@type userdata[]
    local dominated = {}
    Runtime.managed = {}

    local npcs = NPCs.GetAll()
    for i = 1, #npcs do
        local npc = npcs[i]
        if npc
            and npc ~= me
            and Entity.IsAlive(npc) == true
            and Entity.IsControllableByPlayer(npc, playerId) == true
            and NPC.IsCourier(npc) ~= true
            and NPC.IsHero(npc) ~= true
        then
            local index = UnitIndex(npc)
            if IsLycanWolf(npc) then
                wolves[#wolves + 1] = npc
                Runtime.managed[index] = true
            elseif IsDominatedUnit(npc) then
                dominated[#dominated + 1] = npc
                Runtime.managed[index] = true
            end
        end
    end

    return wolves, dominated
end

local function ManaPercent(unit)
    local maxMana = NPC.GetMaxMana(unit)
    if maxMana == nil or maxMana <= 0 then
        return 1.0
    end
    return NPC.GetMana(unit) / maxMana
end

local function IsPushStructure(enemy)
    return NPC.IsTower(enemy) == true
        or NPC.IsBarracks(enemy) == true
        or NPC.IsFort(enemy) == true
end

local function FindEnemyLaneCreep(unit, teamNum, lane)
    local origin = Entity.GetAbsOrigin(unit)
    local units = NPCs.InRadius(origin, WOLF_CREEP_SCAN, teamNum, TEAM_ENEMY, true, true)
    local best = nil
    local bestScore = math.huge

    for i = 1, #units do
        local enemy = units[i]
        if enemy
            and Entity.IsAlive(enemy) == true
            and NPC.IsLaneCreep(enemy) == true
            and NPC.IsWaitingToSpawn(enemy) ~= true
        then
            local pos = Entity.GetAbsOrigin(enemy)
            if lane == nil or ClassifyLane(pos) == lane then
                local d = DistSqr2D(origin, pos)
                -- Prefer nearby creeps; slight bias to lower HP so waves get finished
                local score = d + Entity.GetHealth(enemy) * 35
                if score < bestScore then
                    bestScore = score
                    best = enemy
                end
            end
        end
    end

    return best
end

local function FindNearbyStructure(unit, teamNum)
    local origin = Entity.GetAbsOrigin(unit)
    local units = NPCs.InRadius(origin, WOLF_STRUCTURE_SCAN, teamNum, TEAM_ENEMY, true, true)
    local best = nil
    local bestDist = math.huge
    for i = 1, #units do
        local enemy = units[i]
        if enemy
            and Entity.IsAlive(enemy) == true
            and IsPushStructure(enemy)
        then
            local d = DistSqr2D(origin, Entity.GetAbsOrigin(enemy))
            if d < bestDist then
                bestDist = d
                best = enemy
            end
        end
    end
    return best
end

local function IssueAttackMove(player, unit, pos, identifier, forceMinimap)
    Player.PrepareUnitOrders(
        player,
        ORDER_ATTACK_MOVE,
        nil,
        pos,
        nil,
        ISSUER_UNIT,
        unit,
        false,
        false,
        true,
        false,
        identifier,
        forceMinimap
    )
end

local function IssueAttackTarget(player, unit, target, identifier)
    Player.AttackTarget(player, unit, target, false, true, false, identifier, false)
end

local function UpdateWolves(me, player, wolves, now)
    if UI.wolvesPush == nil or UI.wolvesPush:Get() ~= true then
        return
    end
    if #wolves == 0 then
        return
    end

    RefreshLaneChains(me)
    local heroPos = Entity.GetAbsOrigin(me)
    local chain = NearestLaneChain(heroPos)
    local objective = LaneObjectivePos(chain)
    if objective == nil then
        return
    end

    local teamNum = Entity.GetTeamNum(me)
    local lane = chain and chain.lane or nil

    for i = 1, #wolves do
        local wolf = wolves[i]
        local index = UnitIndex(wolf)
        if CanOrder(index, now) then
            local attackRange = NPC.GetAttackRange(wolf) + NPC.GetAttackRangeBonus(wolf) + 100
            local attackRangeSqr = attackRange * attackRange
            local creep = FindEnemyLaneCreep(wolf, teamNum, lane)

            if creep ~= nil then
                local creepPos = Entity.GetAbsOrigin(creep)
                if DistSqr2D(Entity.GetAbsOrigin(wolf), creepPos) <= attackRangeSqr then
                    IssueAttackTarget(player, wolf, creep, ID_WOLF_PUSH)
                else
                    IssueAttackMove(player, wolf, creepPos, ID_WOLF_PUSH, false)
                end
            else
                local structure = FindNearbyStructure(wolf, teamNum)
                if structure ~= nil
                    and DistSqr2D(Entity.GetAbsOrigin(wolf), Entity.GetAbsOrigin(structure)) <= attackRangeSqr
                then
                    IssueAttackTarget(player, wolf, structure, ID_WOLF_PUSH)
                else
                    IssueAttackMove(player, wolf, objective, ID_WOLF_PUSH, true)
                end
            end
            MarkOrdered(index, now)
        end
    end
end

local function CampCenter(camp)
    local box = Camp.GetCampBox(camp)
    if not box or not box.min or not box.max then
        return nil
    end
    local min = box.min
    local max = box.max
    return Vector((min.x + max.x) * 0.5, (min.y + max.y) * 0.5, (min.z + max.z) * 0.5)
end

local function CampKey(center)
    return string.format("%.0f_%.0f", center.x, center.y)
end

local function IsOwnCamp(center)
    local own = Runtime.ownFountain
    local enemy = Runtime.enemyFountain
    if own == nil or enemy == nil then
        return false
    end
    return DistSqr2D(center, own) <= DistSqr2D(center, enemy)
end

---@class LycanCampInfo
---@field camp userdata
---@field center Vector
---@field key string

local function BuildOwnCamps()
    ---@type LycanCampInfo[]
    local result = {}
    local camps = Camps.GetAll()
    for i = 1, #camps do
        local camp = camps[i]
        if camp then
            local center = CampCenter(camp)
            if center ~= nil and IsOwnCamp(center) then
                result[#result + 1] = {
                    camp = camp,
                    center = center,
                    key = CampKey(center),
                }
            end
        end
    end
    return result
end

local function CampScanRadius(info)
    local box = Camp.GetCampBox(info.camp)
    if not box or not box.min or not box.max then
        return 450
    end
    local radius = math.max(
        (box.max.x - box.min.x) * 0.5 + CAMP_BOX_PAD,
        (box.max.y - box.min.y) * 0.5 + CAMP_BOX_PAD
    )
    return math.min(650, math.max(300, radius))
end

local function NeutralsAtCamp(info, teamNum)
    local radius = CampScanRadius(info)
    local units = NPCs.InRadius(info.center, radius, teamNum, TEAM_ENEMY, true, true)
    ---@type userdata[]
    local neutrals = {}
    for i = 1, #units do
        local enemy = units[i]
        if enemy
            and Entity.IsAlive(enemy) == true
            and NPC.IsNeutral(enemy) == true
            and NPC.IsLaneCreep(enemy) ~= true
            and NPC.IsWaitingToSpawn(enemy) ~= true
        then
            neutrals[#neutrals + 1] = enemy
        end
    end
    return neutrals
end

local function BestNeutral(unit, neutrals)
    local origin = Entity.GetAbsOrigin(unit)
    local best = nil
    local bestDist = math.huge
    for i = 1, #neutrals do
        local enemy = neutrals[i]
        if enemy and Entity.IsAlive(enemy) == true then
            local d = DistSqr2D(origin, Entity.GetAbsOrigin(enemy))
            if d < bestDist then
                bestDist = d
                best = enemy
            end
        end
    end
    return best
end

local function FindCampByKey(camps, key)
    for i = 1, #camps do
        if camps[i].key == key then
            return camps[i]
        end
    end
    return nil
end

local function IsCampVisible(center)
    return FogOfWar.IsPointVisible(center) == true
end

local function FindNearestFarmCamp(origin, camps, teamNum, claimed, clockNow)
    local bestVisible = nil
    local bestVisibleDist = math.huge
    local bestUnknown = nil
    local bestUnknownDist = math.huge

    for i = 1, #camps do
        local info = camps[i]
        if claimed[info.key] ~= true and IsCampCoolingDown(info.key, clockNow) ~= true then
            local d = DistSqr2D(origin, info.center)
            local neutrals = NeutralsAtCamp(info, teamNum)
            if #neutrals > 0 then
                NoteCampAlive(info.key)
                if d < bestVisibleDist then
                    bestVisibleDist = d
                    bestVisible = info
                end
            elseif IsCampVisible(info.center) ~= true then
                -- FOW: neutrals unknown — still a valid farm target
                if d < bestUnknownDist then
                    bestUnknownDist = d
                    bestUnknown = info
                end
            end
        end
    end

    return bestVisible or bestUnknown
end

local function AssignCamp(unitIndex, info, claimed)
    Runtime.domCampKey[unitIndex] = info.key
    Runtime.domEverAssigned[unitIndex] = true
    claimed[info.key] = true
    Runtime.domEmptyStreak[info.key] = 0
end

local function TryCastCreepAbility(unit, target)
    if ManaPercent(unit) < DOM_MIN_MANA_PCT then
        return false
    end

    local mana = NPC.GetMana(unit)
    for slot = 0, ABILITY_INDEX_MAX do
        local ability = NPC.GetAbilityByIndex(unit, slot)
        if ability
            and Ability.IsHidden(ability) ~= true
            and Ability.IsPassive(ability) ~= true
            and Ability.GetLevel(ability) > 0
        then
            local behavior = Ability.GetBehavior(ability)
            if (behavior & BEHAVIOR_ITEM) == 0
                and (behavior & BEHAVIOR_TOGGLE) == 0
                and (behavior & BEHAVIOR_VECTOR) == 0
                and Ability.CanBeExecuted(ability) == CAST_READY
                and Ability.IsCastable(ability, mana) == true
            then
                local castRange = Ability.GetCastRange(ability)
                if castRange <= 0 then
                    castRange = 300
                end

                if (behavior & BEHAVIOR_NO_TARGET) ~= 0 then
                    if target ~= nil then
                        local d = DistSqr2D(Entity.GetAbsOrigin(unit), Entity.GetAbsOrigin(target))
                        if d <= (castRange + 150) * (castRange + 150) then
                            Ability.CastNoTarget(ability, false, true, false, ID_DOM_CAST)
                            return true
                        end
                    end
                elseif (behavior & BEHAVIOR_UNIT_TARGET) ~= 0 then
                    if target ~= nil then
                        local d = DistSqr2D(Entity.GetAbsOrigin(unit), Entity.GetAbsOrigin(target))
                        if d <= (castRange + 50) * (castRange + 50) then
                            Ability.CastTarget(ability, target, false, true, false, ID_DOM_CAST)
                            return true
                        end
                    end
                elseif (behavior & BEHAVIOR_POINT) ~= 0 then
                    if target ~= nil then
                        local d = DistSqr2D(Entity.GetAbsOrigin(unit), Entity.GetAbsOrigin(target))
                        if d <= (castRange + 50) * (castRange + 50) then
                            Ability.CastPosition(
                                ability,
                                Entity.GetAbsOrigin(target),
                                false,
                                true,
                                false,
                                ID_DOM_CAST,
                                false
                            )
                            return true
                        end
                    end
                end
            end
        end
    end
    return false
end

local function UpdateDominator(me, player, dominated, now)
    if UI.dominatorFarm == nil or UI.dominatorFarm:Get() ~= true then
        return
    end
    if #dominated == 0 then
        return
    end

    EnsureMatchAnchors(me)
    local camps = BuildOwnCamps()
    if #camps == 0 then
        return
    end

    local teamNum = Entity.GetTeamNum(me)
    local clockNow = GameClock()
    local heroPos = Entity.GetAbsOrigin(me)
    ---@type table<string, boolean>
    local claimed = {}

    for i = 1, #dominated do
        local unit = dominated[i]
        local index = UnitIndex(unit)
        local stickyKey = Runtime.domCampKey[index]
        if stickyKey ~= nil then
            claimed[stickyKey] = true
        end
    end

    for i = 1, #dominated do
        local unit = dominated[i]
        local index = UnitIndex(unit)
        local unitPos = Entity.GetAbsOrigin(unit)
        local campInfo = nil
        local stickyKey = Runtime.domCampKey[index]

        if stickyKey ~= nil then
            campInfo = FindCampByKey(camps, stickyKey)
            if campInfo == nil then
                Runtime.domCampKey[index] = nil
                claimed[stickyKey] = nil
            end
        end

        if campInfo ~= nil then
            local neutrals = NeutralsAtCamp(campInfo, teamNum)
            local campVisible = IsCampVisible(campInfo.center)
            local nearCamp = DistSqr2D(unitPos, campInfo.center) <= CAMP_ARRIVE_DIST_SQR

            if #neutrals > 0 then
                NoteCampAlive(campInfo.key)
                if CanOrder(index, now) then
                    local target = BestNeutral(unit, neutrals)
                    if TryCastCreepAbility(unit, target) then
                        MarkOrdered(index, now)
                    elseif target ~= nil then
                        IssueAttackTarget(player, unit, target, ID_DOM_ATTACK)
                        MarkOrdered(index, now)
                    else
                        IssueAttackMove(player, unit, campInfo.center, ID_DOM_ATTACK, false)
                        MarkOrdered(index, now)
                    end
                end
            elseif campVisible ~= true or nearCamp ~= true then
                -- Fog or still traveling: never treat as cleared
                Runtime.domEmptyStreak[campInfo.key] = 0
                if CanOrder(index, now) then
                    IssueAttackMove(player, unit, campInfo.center, ID_DOM_ATTACK, false)
                    MarkOrdered(index, now)
                end
            else
                local streak = (Runtime.domEmptyStreak[campInfo.key] or 0) + 1
                Runtime.domEmptyStreak[campInfo.key] = streak
                if streak >= CAMP_EMPTY_CONFIRM then
                    MarkCampCleared(campInfo.key, clockNow)
                    Runtime.domCampKey[index] = nil
                    claimed[campInfo.key] = nil
                    campInfo = nil
                elseif CanOrder(index, now) then
                    Player.HoldPosition(player, unit, false, true, false, ID_DOM_ATTACK)
                    MarkOrdered(index, now)
                end
            end
        end

        if campInfo == nil then
            local searchFrom = heroPos
            if Runtime.domEverAssigned[index] == true then
                searchFrom = unitPos
            end

            local nextCamp = FindNearestFarmCamp(searchFrom, camps, teamNum, claimed, clockNow)
            if nextCamp ~= nil then
                AssignCamp(index, nextCamp, claimed)
                if CanOrder(index, now) then
                    local neutrals = NeutralsAtCamp(nextCamp, teamNum)
                    local target = BestNeutral(unit, neutrals)
                    if target ~= nil then
                        if TryCastCreepAbility(unit, target) then
                            MarkOrdered(index, now)
                        else
                            IssueAttackTarget(player, unit, target, ID_DOM_ATTACK)
                            MarkOrdered(index, now)
                        end
                    else
                        IssueAttackMove(player, unit, nextCamp.center, ID_DOM_ATTACK, false)
                        MarkOrdered(index, now)
                    end
                end
            end
        end
    end
end

local function StampOverrideForNpc(npc, now)
    if npc == nil then
        return
    end
    if type(npc) == "table" then
        for i = 1, #npc do
            StampOverrideForNpc(npc[i], now)
        end
        return
    end
    local index = UnitIndex(npc)
    if Runtime.managed[index] ~= nil then
        Runtime.overrideUntil[index] = now + OVERRIDE_PAUSE
    end
end

local function UpdateFeature(me)
    local player = Players.GetLocal()
    if player == nil then
        return
    end

    local playerId = Player.GetPlayerID(player)
    if playerId < 0 then
        return
    end

    EnsureMatchAnchors(me)
    local now = GameRules.GetGameTime()
    local wolves, dominated = CollectUnits(me, playerId)

    UpdateWolves(me, player, wolves, now)
    UpdateDominator(me, player, dominated, now)
end
--#endregion

--#region Lifecycle
function Script.OnScriptsLoaded()
    Persistent.logger = Logger(NAME)
    Persistent.font = Render.LoadFont(
        "Segoe UI",
        Enum.FontCreate.FONTFLAG_ANTIALIAS,
        Enum.FontWeight.BOLD
    )

    local group = Menu.Create("Heroes", "Hero List", "Lycan", "Main Settings", "Auto Control")
    UI.enabled = group:Switch("Enable", true, "\u{f00c}")
    UI.control = group:Bind("Control", Enum.ButtonCode.BUTTON_CODE_INVALID, "\u{e1c1}")
    UI.control:Properties(nil, nil, true)
    local gear = UI.control:Gear("Settings")
    UI.wolvesPush = gear:Switch(
        "Wolves Push",
        true,
        "panorama/images/spellicons/lycan_summon_wolves_png.vtex_c"
    )
    UI.dominatorFarm = gear:Switch(
        "Dominator Farm",
        true,
        "panorama/images/items/helm_of_the_dominator_png.vtex_c"
    )

    UI.enabled:SetCallback(OnEnabledChanged, true)

    Persistent.logger:info("loaded")
end

function Script.OnDraw()
    if not Engine.IsInGame() then
        return
    end
    if Menu.VisualsIsEnabled() ~= true then
        return
    end
    if IsFeatureActive() ~= true then
        return
    end

    local me = Heroes.GetLocal()
    if not me or Entity.IsAlive(me) ~= true then
        return
    end
    if IsLocalLycan(me) ~= true then
        return
    end

    DrawStatusOverlay(me)
end

function Script.OnUpdate()
    if not Engine.IsInGame() then
        return
    end
    if IsFeatureActive() ~= true then
        return
    end
    if Input.IsInputCaptured() then
        return
    end

    local now = GameRules.GetGameTime()
    if now - Runtime.lastUpdateAt < UPDATE_INTERVAL then
        return
    end
    Runtime.lastUpdateAt = now

    local me = Heroes.GetLocal()
    if not me or Entity.IsAlive(me) ~= true then
        return
    end
    if IsLocalLycan(me) ~= true then
        return
    end

    UpdateFeature(me)
end

function Script.OnPrepareUnitOrders(data, player, order, target, position, ability, orderIssuer, npc, queue, showEffects)
    local identifier = data and data.identifier
    if type(identifier) == "string" and string.sub(identifier, 1, #ORDER_PREFIX) == ORDER_PREFIX then
        return true
    end

    local localPlayer = Players.GetLocal()
    if localPlayer == nil or player ~= localPlayer then
        return true
    end

    StampOverrideForNpc(npc, GameRules.GetGameTime())
    return true
end

function Script.OnGameEnd()
    ResetRuntime()
end
--#endregion

return Script
