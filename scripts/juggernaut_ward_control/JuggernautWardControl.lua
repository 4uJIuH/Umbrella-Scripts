--[[
    Juggernaut Ward Control
    Soft-micro for Healing Ward: heal follow, threat flee, GridNav pathing.
    Script by 花曇り hanagumori
--]]

local Script = {}

--#region Constants
local NAME = "JuggernautWardControl"
local HERO = "npc_dota_hero_juggernaut"
local WARD_UNIT = "npc_dota_juggernaut_healing_ward"
local ABILITY_WARD = "juggernaut_healing_ward"
local ORDER_MOVE = "jugg.ward_control.move"
local ICON_ENABLE = "\u{f00c}" -- check
local ICON_HEAL_ALLIES = "\u{f4b7}" -- hand-holding-medical
local ICON_ALLY_HP = "\u{f21e}" -- heartbeat
local ICON_FEAR_CREEPS = "\u{f700}" -- rabbit
local ICON_DEBUG = "\u{f188}" -- bug

local UPDATE_INTERVAL = 0.06
local MOVE_INTERVAL_HEAL = 0.38
local MOVE_INTERVAL_FLEE = 0.16
local HEAL_RADIUS_FALLBACK = 400
local FOLLOW_DIST = 220
local FOLLOW_DIST_MIN = 150
local SEARCH_RADIUS = 1600
local THREAT_SCAN = 2000
local ARRIVE_EPS = 55
local HOLD_EPS_HEAL = 155
local HOLD_EPS_FLEE = 60
local REISSUE_HEAL = 170
local REISSUE_FLEE = 75
local FLEE_STEP = 480
local SAFE_HOLD = 0.4
local MANUAL_PAUSE = 2.0
local SELF_SCORE_BONUS = 0.18
local WARD_HULL = 32
local HIT_PAD = 90
local REACT_TIME = 0.8
local RETURN_EXTRA = 120
local WARD_MS_FALLBACK = 325
local PATH_STEP = 300
local STUCK_TIME = 0.55
local SAMPLE_DISTS = { 160, 220, 280, 340 }
local SAMPLE_ANGLES = 12
local WALK_SEARCH_RINGS = { 0, 64, 128, 192, 256 }
local WALK_SEARCH_ANGLES = 8

-- Values from Enums.lua Enum.modifierState (do not index Enum.modifierState at runtime).
local STATE_OUT_OF_GAME = 33 -- MODIFIER_STATE_OUT_OF_GAME
--#endregion

--#region State
---@class JuggernautWardControlUI
---@field enabled CMenuSwitch|nil
---@field healAllies CMenuSwitch|nil
---@field allyHp CMenuSliderInt|nil
---@field fearCreeps CMenuSwitch|nil
---@field debug CMenuSwitch|nil
local UI = {
    enabled = nil,
    healAllies = nil,
    allyHp = nil,
    fearCreeps = nil,
    debug = nil,
}

local Persistent = {
    ---@type Logger|nil
    logger = nil,
    ---@type integer|nil
    font = nil,
    ---@type integer|nil
    fontSmall = nil,
}

---@class JuggernautWardThreat
---@field unit userdata
---@field pos Vector
---@field hit number
---@field keep number
---@field dist number
---@field ms number
---@field ar number
---@field arBonus number
---@field hull number
---@field ranged boolean
---@field name string
---@field isHero boolean

---@class JuggernautWardDebugThreat
---@field pos Vector
---@field hit number
---@field keep number
---@field dist number
---@field ar number
---@field arBonus number
---@field hull number
---@field ms number
---@field ranged boolean
---@field name string
---@field isHero boolean
---@field margin number
---@field keepMargin number

---@class JuggernautWardDebugSnap
---@field mode string
---@field mustFlee boolean
---@field pressured boolean
---@field planSafe boolean
---@field planMargin number
---@field wardDistToDest number
---@field wardMs number
---@field healRadius number
---@field threatCount integer
---@field threats JuggernautWardDebugThreat[]
---@field dest Vector
---@field wardPos Vector
---@field scan string

local Runtime = {
    mode = "heal",
    ---@type userdata|nil
    ward = nil,
    ---@type Vector|nil
    dest = nil,
    ---@type Vector|nil
    goal = nil,
    safeSince = -math.huge,
    manualUntil = -math.huge,
    lastOrderAt = -math.huge,
    stuckSince = -math.huge,
    lastProgressDist = math.huge,
    lastUpdateAt = -math.huge,
    lastMoveHealAt = -math.huge,
    lastMoveFleeAt = -math.huge,
    lastDbgLogAt = -math.huge,
    ---@type userdata|nil
    drawWard = nil,
    ---@type JuggernautWardDebugSnap|nil
    debugSnap = nil,
    scanHeroes = 0,
    scanEnemies = 0,
    scanInRange = 0,
    scanAdded = 0,
    scanSkipDead = 0,
    scanSkipTeam = 0,
    scanSkipIllusion = 0,
    scanSkipDormant = 0,
    scanSkipFar = 0,
    scanSkipState = 0,
}
--#endregion

--#region Helpers
local function ResetRuntime()
    Runtime.mode = "heal"
    Runtime.ward = nil
    Runtime.dest = nil
    Runtime.goal = nil
    Runtime.safeSince = -math.huge
    Runtime.manualUntil = -math.huge
    Runtime.lastOrderAt = -math.huge
    Runtime.stuckSince = -math.huge
    Runtime.lastProgressDist = math.huge
    Runtime.lastUpdateAt = -math.huge
    Runtime.lastMoveHealAt = -math.huge
    Runtime.lastMoveFleeAt = -math.huge
    Runtime.lastDbgLogAt = -math.huge
    Runtime.drawWard = nil
    Runtime.debugSnap = nil
end

local function SyncDepsDisabled()
    local off = not UI.enabled or UI.enabled:Get() ~= true
    if UI.healAllies then
        UI.healAllies:Disabled(off)
    end
    if UI.allyHp then
        UI.allyHp:Disabled(off)
    end
    if UI.fearCreeps then
        UI.fearCreeps:Disabled(off)
    end
    if UI.debug then
        UI.debug:Disabled(off)
    end
end

local function OnEnabledChanged()
    SyncDepsDisabled()
    if not UI.enabled or UI.enabled:Get() ~= true then
        ResetRuntime()
    end
end

local function OnDebugChanged()
    if not UI.debug or UI.debug:Get() ~= true then
        Runtime.debugSnap = nil
    end
end

local function EnsureFonts()
    if not Persistent.font then
        Persistent.font = Render.LoadFont("Tahoma", Enum.FontCreate.FONTFLAG_NONE, Enum.FontWeight.BOLD)
    end
    if not Persistent.fontSmall then
        Persistent.fontSmall = Render.LoadFont("Tahoma", Enum.FontCreate.FONTFLAG_NONE, Enum.FontWeight.MEDIUM)
    end
end

local function Dist2(a, b)
    return a:Distance2D(b)
end

local function AwayFrom(from, threat, distance)
    local dx = from.x - threat.x
    local dy = from.y - threat.y
    local len = math.sqrt(dx * dx + dy * dy)
    if len <= 1 then
        return Vector(from.x + distance, from.y, from.z)
    end
    local scale = distance / len
    return Vector(from.x + dx * scale, from.y + dy * scale, from.z)
end

local function IsWalkable(pos)
    local ok = GridNav.IsTraversable(pos)
    return ok == true
end

local function FindNearbyWalkable(want, from)
    if IsWalkable(want) then
        return want
    end
    local best = nil
    local bestScore = math.huge
    for r = 2, #WALK_SEARCH_RINGS do
        local rad = WALK_SEARCH_RINGS[r]
        for a = 0, WALK_SEARCH_ANGLES - 1 do
            local ang = (math.pi * 2 * a) / WALK_SEARCH_ANGLES
            local p = Vector(want.x + math.cos(ang) * rad, want.y + math.sin(ang) * rad, want.z)
            if IsWalkable(p) then
                local score = Dist2(want, p) * 2 + Dist2(from, p) * 0.35
                if score < bestScore then
                    bestScore = score
                    best = p
                end
            end
        end
        if best then
            return best
        end
    end
    return nil
end

local function PickPathWaypoint(from, path, finalWant)
    local best = finalWant
    local bestScore = math.huge
    for i = 1, #path do
        local p = path[i]
        local d = Dist2(from, p)
        if d >= 70 then
            local score = math.abs(d - PATH_STEP)
            if score < bestScore then
                bestScore = score
                best = p
            end
            if d >= PATH_STEP and d <= PATH_STEP + 180 then
                return p
            end
        end
    end
    if #path > 0 then
        local last = path[#path]
        if Dist2(from, last) > 70 then
            return last
        end
    end
    return best
end

local function ResolveWalkDest(from, want, ward)
    local grounded = FindNearbyWalkable(want, from)
    if not grounded then
        grounded = want
    end
    local npcMap = GridNav.CreateNpcMap({ ward }, true)
    local path = GridNav.BuildPath(from, grounded, false, npcMap)
    GridNav.ReleaseNpcMap(npcMap)
    if path and #path > 0 then
        return PickPathWaypoint(from, path, grounded)
    end
    return grounded
end

local function HpPct(unit)
    local maxHp = Entity.GetMaxHealth(unit)
    if not maxHp or maxHp <= 0 then
        maxHp = 1
    end
    return (Entity.GetHealth(unit) / maxHp) * 100
end

local function HealRadius(me)
    local ab = NPC.GetAbility(me, ABILITY_WARD)
    if not ab then
        return HEAL_RADIUS_FALLBACK
    end
    local r = Ability.GetLevelSpecialValueFor(ab, "healing_ward_aura_radius")
    if r and r > 0 then
        return r
    end
    local r2 = Ability.GetLevelSpecialValueFor(ab, "radius")
    if r2 and r2 > 0 then
        return r2
    end
    return HEAL_RADIUS_FALLBACK
end

local function IsOurWard(unit, me, player)
    if not unit or Entity.IsAlive(unit) ~= true then
        return false
    end
    if NPC.GetUnitName(unit) ~= WARD_UNIT then
        return false
    end
    if Entity.IsSameTeam(unit, me) ~= true then
        return false
    end
    local playerId = Player.GetPlayerID(player)
    if playerId >= 0 and Entity.IsControllableByPlayer(unit, playerId) == true then
        return true
    end
    if Entity.RecursiveOwnedBy(unit, me) == true or Entity.OwnedBy(unit, me) == true then
        return true
    end
    return false
end

local function FindWard(me, player)
    local cached = Runtime.ward
    if cached and IsOurWard(cached, me, player) then
        return cached
    end
    local list = NPCs.GetAll()
    for i = 1, #list do
        local u = list[i]
        if IsOurWard(u, me, player) then
            Runtime.ward = u
            return u
        end
    end
    Runtime.ward = nil
    return nil
end

local function CanThreaten(unit)
    if not unit or Entity.IsAlive(unit) ~= true then
        return false
    end
    if NPC.HasState(unit, STATE_OUT_OF_GAME) == true then
        return false
    end
    return true
end

local function UnitHull(unit)
    local hull = NPC.GetHullRadius(unit)
    if hull and hull > 0 then
        return hull
    end
    return 24
end

local function UnitMoveSpeed(unit)
    local ms = NPC.GetMoveSpeed(unit)
    if ms and ms > 1 then
        return ms
    end
    return 300
end

local function WardMoveSpeed(ward)
    local ms = NPC.GetMoveSpeed(ward)
    if ms and ms > 1 then
        return ms
    end
    return WARD_MS_FALLBACK
end

local function HitReach(ar, hull)
    return ar + hull + WARD_HULL + HIT_PAD
end

local function KeepOutFromHit(hit, enemyMs, wardMs)
    local closeMs = math.max(enemyMs * 0.35, enemyMs - wardMs * 0.65)
    return hit + closeMs * REACT_TIME
end

local function ShortUnitName(unit)
    local name = NPC.GetUnitName(unit) or "?"
    name = string.gsub(name, "^npc_dota_hero_", "")
    name = string.gsub(name, "^npc_dota_", "")
    if #name > 14 then
        name = string.sub(name, 1, 14)
    end
    return name
end

local function PushThreat(out, seen, unit, fromPos, wardMs)
    local idx = Entity.GetIndex(unit)
    if seen[idx] then
        return false
    end
    seen[idx] = true
    local pos = Entity.GetAbsOrigin(unit)
    local arBase = NPC.GetAttackRange(unit) or 0
    local arBonus = arBase + (NPC.GetAttackRangeBonus(unit) or 0)
    if arBonus <= 0 then
        arBonus = 150
    end
    local hull = UnitHull(unit)
    local hit = HitReach(arBonus, hull)
    local ms = UnitMoveSpeed(unit)
    local ranged = NPC.IsRanged(unit) == true
    if not ranged and arBonus > 200 then
        ranged = true
    end
    out[#out + 1] = {
        unit = unit,
        pos = pos,
        hit = hit,
        keep = KeepOutFromHit(hit, ms, wardMs),
        dist = Dist2(fromPos, pos),
        ms = ms,
        ar = arBase,
        arBonus = arBonus,
        hull = hull,
        ranged = ranged,
        name = ShortUnitName(unit),
        isHero = NPC.IsHero(unit) == true,
    }
    return true
end

local function FormatScanStats()
    return string.format(
        "h=%d enem=%d near=%d add=%d dead=%d team=%d illu=%d dorm=%d far=%d state=%d",
        Runtime.scanHeroes,
        Runtime.scanEnemies,
        Runtime.scanInRange,
        Runtime.scanAdded,
        Runtime.scanSkipDead,
        Runtime.scanSkipTeam,
        Runtime.scanSkipIllusion,
        Runtime.scanSkipDormant,
        Runtime.scanSkipFar,
        Runtime.scanSkipState
    )
end

local function CollectThreats(ward, me)
    local out = {}
    local seen = {}
    local wPos = Entity.GetAbsOrigin(ward)
    local wardMs = WardMoveSpeed(ward)
    Runtime.scanHeroes = 0
    Runtime.scanEnemies = 0
    Runtime.scanInRange = 0
    Runtime.scanAdded = 0
    Runtime.scanSkipDead = 0
    Runtime.scanSkipTeam = 0
    Runtime.scanSkipIllusion = 0
    Runtime.scanSkipDormant = 0
    Runtime.scanSkipFar = 0
    Runtime.scanSkipState = 0

    local heroes = Heroes.GetAll()
    Runtime.scanHeroes = #heroes
    for i = 1, #heroes do
        local h = heroes[i]
        if not h or Entity.IsAlive(h) ~= true then
            Runtime.scanSkipDead = Runtime.scanSkipDead + 1
        elseif Entity.IsSameTeam(h, me) == true then
            Runtime.scanSkipTeam = Runtime.scanSkipTeam + 1
        else
            Runtime.scanEnemies = Runtime.scanEnemies + 1
            if NPC.IsIllusion(h) == true then
                Runtime.scanSkipIllusion = Runtime.scanSkipIllusion + 1
            elseif Entity.IsDormant(h) == true then
                Runtime.scanSkipDormant = Runtime.scanSkipDormant + 1
            elseif not CanThreaten(h) then
                Runtime.scanSkipState = Runtime.scanSkipState + 1
            elseif Dist2(wPos, Entity.GetAbsOrigin(h)) > THREAT_SCAN then
                Runtime.scanSkipFar = Runtime.scanSkipFar + 1
            else
                Runtime.scanInRange = Runtime.scanInRange + 1
                if PushThreat(out, seen, h, wPos, wardMs) then
                    Runtime.scanAdded = Runtime.scanAdded + 1
                end
            end
        end
    end

    if UI.fearCreeps and UI.fearCreeps:Get() == true then
        local units = Entity.GetUnitsInRadius(ward, THREAT_SCAN, Enum.TeamType.TEAM_ENEMY, true, true)
        local creepAdded = 0
        for i = 1, #units do
            local u = units[i]
            if u
                and Entity.IsAlive(u) == true
                and NPC.IsHero(u) ~= true
                and NPC.IsCreep(u) == true
                and CanThreaten(u)
                and Dist2(wPos, Entity.GetAbsOrigin(u)) <= THREAT_SCAN
            then
                if PushThreat(out, seen, u, wPos, wardMs) then
                    creepAdded = creepAdded + 1
                end
            end
        end
        if creepAdded == 0 then
            local npcs = NPCs.GetAll(Enum.UnitTypeFlags.TYPE_CREEP)
            local farLimit = math.min(THREAT_SCAN, 900)
            for i = 1, #npcs do
                local u = npcs[i]
                if u
                    and Entity.IsAlive(u) == true
                    and NPC.IsHero(u) ~= true
                    and NPC.IsCreep(u) == true
                    and Entity.IsSameTeam(u, me) ~= true
                    and Entity.IsDormant(u) ~= true
                    and CanThreaten(u)
                    and Dist2(wPos, Entity.GetAbsOrigin(u)) <= farLimit
                then
                    PushThreat(out, seen, u, wPos, wardMs)
                end
            end
        end
    end

    for i = 1, #out do
        out[i].pos = Entity.GetAbsOrigin(out[i].unit)
        out[i].dist = Dist2(wPos, out[i].pos)
    end
    return out
end

local function MarginAt(pos, threats)
    if #threats == 0 then
        return 9999
    end
    local worst = math.huge
    for i = 1, #threats do
        local m = Dist2(pos, threats[i].pos) - threats[i].hit
        if m < worst then
            worst = m
        end
    end
    return worst
end

local function KeepMarginAt(pos, threats)
    if #threats == 0 then
        return 9999
    end
    local worst = math.huge
    for i = 1, #threats do
        local m = Dist2(pos, threats[i].pos) - threats[i].keep
        if m < worst then
            worst = m
        end
    end
    return worst
end

local function IsPressured(wardPos, threats)
    return KeepMarginAt(wardPos, threats) <= 0
end

local function IsComfortablySafe(wardPos, threats)
    for i = 1, #threats do
        if Dist2(wardPos, threats[i].pos) <= threats[i].keep + RETURN_EXTRA then
            return false
        end
    end
    return true
end

local function PickHealTarget(me)
    local pickHero = me
    local pickScore = -math.huge
    local allyHpPct = 92
    if UI.allyHp then
        allyHpPct = UI.allyHp:Get()
    end

    local function consider(h, isSelf)
        if not h or Entity.IsAlive(h) ~= true then
            return
        end
        local pct = HpPct(h)
        if not isSelf and pct > allyHpPct then
            return
        end
        local score = (100 - pct) / 100
        if isSelf then
            score = score + SELF_SCORE_BONUS
        end
        if score > pickScore then
            pickScore = score
            pickHero = h
        end
    end

    consider(me, true)
    if UI.healAllies and UI.healAllies:Get() == true then
        local allies = Entity.GetHeroesInRadius(me, SEARCH_RADIUS, Enum.TeamType.TEAM_FRIEND, true, true)
        local meIndex = Entity.GetIndex(me)
        for i = 1, #allies do
            local a = allies[i]
            if a and Entity.GetIndex(a) ~= meIndex then
                consider(a, false)
            end
        end
    end
    return pickHero
end

local function BehindDir(target)
    local rot = Entity.GetRotation(target)
    if not rot then
        return 0, -1
    end
    local fwd = rot:GetForward()
    local fl = math.sqrt(fwd.x * fwd.x + fwd.y * fwd.y)
    if fl <= 0 then
        fl = 1
    end
    return -fwd.x / fl, -fwd.y / fl
end

local function AwayDirFromThreats(origin, threats)
    if #threats == 0 then
        return nil, nil
    end
    local rx, ry = 0, 0
    for i = 1, #threats do
        local t = threats[i]
        local dx = origin.x - t.pos.x
        local dy = origin.y - t.pos.y
        local len = math.sqrt(dx * dx + dy * dy)
        if len <= 0 then
            len = 1
        end
        local weight = (1 + t.hit / 400) / math.max(80, Dist2(origin, t.pos))
        rx = rx + (dx / len) * weight
        ry = ry + (dy / len) * weight
    end
    local rLen = math.sqrt(rx * rx + ry * ry)
    if rLen < 0.01 then
        return nil, nil
    end
    return rx / rLen, ry / rLen
end

local function ComputeFleeDest(ward, me, threats)
    local wPos = Entity.GetAbsOrigin(ward)
    local tx, ty = 0, 0
    local best = nil
    for i = 1, #threats do
        local t = threats[i]
        local inside = math.max(1, t.keep + 40 - t.dist)
        local dx = wPos.x - t.pos.x
        local dy = wPos.y - t.pos.y
        local len = math.sqrt(dx * dx + dy * dy)
        if len <= 0 then
            len = 1
        end
        tx = tx + (dx / len) * inside
        ty = ty + (dy / len) * inside
        if not best or (t.dist - t.hit) < (best.dist - best.hit) then
            best = t
        end
    end

    local step = FLEE_STEP
    if best then
        step = math.max(FLEE_STEP, best.keep - best.dist + 200)
    end

    local dest
    local tLen = math.sqrt(tx * tx + ty * ty)
    if tLen > 0.01 then
        dest = Vector(wPos.x + (tx / tLen) * step, wPos.y + (ty / tLen) * step, wPos.z)
    elseif best then
        dest = AwayFrom(wPos, best.pos, step)
    else
        dest = AwayFrom(wPos, Entity.GetAbsOrigin(me), step)
    end

    local walk = FindNearbyWalkable(dest, wPos)
    if walk then
        return walk
    end
    return dest
end

local function ComputeHealPlan(me, ward, threats, radius)
    local target = PickHealTarget(me)
    local origin = Entity.GetAbsOrigin(target)
    local wPos = Entity.GetAbsOrigin(ward)
    local z = wPos.z
    local maxHeal = math.min(radius * 0.85, 360)
    local candidates = {}
    local bx, by = BehindDir(target)
    candidates[#candidates + 1] = Vector(origin.x + bx * FOLLOW_DIST, origin.y + by * FOLLOW_DIST, z)

    local ax, ay = AwayDirFromThreats(origin, threats)
    if ax then
        for i = 1, #SAMPLE_DISTS do
            local d = math.min(SAMPLE_DISTS[i], maxHeal)
            candidates[#candidates + 1] = Vector(origin.x + ax * d, origin.y + ay * d, z)
        end
    end

    for a = 0, SAMPLE_ANGLES - 1 do
        local ang = (math.pi * 2 * a) / SAMPLE_ANGLES
        local cx = math.cos(ang)
        local cy = math.sin(ang)
        for i = 1, #SAMPLE_DISTS do
            local d = math.min(SAMPLE_DISTS[i], maxHeal)
            candidates[#candidates + 1] = Vector(origin.x + cx * d, origin.y + cy * d, z)
        end
    end

    local bestSafe = nil
    local bestSafeScore = -math.huge
    local bestAny = candidates[1]
    local bestAnyMargin = -math.huge
    local bestAnyScore = -math.huge

    for i = 1, #candidates do
        local raw = candidates[i]
        local toTargetRaw = Dist2(raw, origin)
        if toTargetRaw <= maxHeal and toTargetRaw >= FOLLOW_DIST_MIN * 0.6 then
            local c = FindNearbyWalkable(raw, wPos)
            if c and IsWalkable(c) then
                local toTarget = Dist2(c, origin)
                if toTarget <= maxHeal + 40 and toTarget >= FOLLOW_DIST_MIN * 0.45 then
                    local hitMargin = MarginAt(c, threats)
                    local keepM = KeepMarginAt(c, threats)
                    local score = hitMargin * 3 + keepM + 80
                    if toTarget > FOLLOW_DIST_MIN then
                        score = score + 20
                    end
                    if score > bestAnyScore or (score == bestAnyScore and hitMargin > bestAnyMargin) then
                        bestAnyScore = score
                        bestAnyMargin = hitMargin
                        bestAny = c
                    end
                    if hitMargin >= 0 and keepM >= 0 and score > bestSafeScore then
                        bestSafeScore = score
                        bestSafe = c
                    end
                end
            end
        end
    end

    if bestSafe then
        return bestSafe, true, MarginAt(bestSafe, threats)
    end
    return bestAny, bestAnyMargin >= 0, bestAnyMargin
end

local function IssueMove(ward, goal, urgentMove, force)
    local now = GameRules.GetGameTime()
    local wPos = Entity.GetAbsOrigin(ward)
    local hold = urgentMove and HOLD_EPS_FLEE or HOLD_EPS_HEAL
    local reissue = urgentMove and REISSUE_FLEE or REISSUE_HEAL
    local interval = urgentMove and MOVE_INTERVAL_FLEE or MOVE_INTERVAL_HEAL
    local lastKey = urgentMove and "lastMoveFleeAt" or "lastMoveHealAt"
    local dest = ResolveWalkDest(wPos, goal, ward)

    if Dist2(wPos, dest) <= hold then
        Runtime.goal = goal
        Runtime.dest = dest
        Runtime.stuckSince = -math.huge
        return
    end

    if not force and Runtime.dest then
        local destShift = Dist2(Runtime.dest, dest)
        local towardOld = Dist2(wPos, Runtime.dest)
        if destShift < reissue then
            if now - Runtime.lastOrderAt < interval * 2.5 then
                return
            end
            if NPC.GetActivity(ward) == Enum.GameActivity.ACT_DOTA_RUN and towardOld > hold then
                return
            end
        elseif not urgentMove and destShift < reissue * 1.6 and now - Runtime.lastOrderAt < interval then
            return
        end
    end

    if not force and now - Runtime[lastKey] < interval then
        return
    end

    NPC.MoveTo(ward, dest, false, false, false, false, ORDER_MOVE, false)
    Runtime.goal = goal
    Runtime.dest = dest
    Runtime.lastOrderAt = now
    Runtime[lastKey] = now
    Runtime.lastProgressDist = Dist2(wPos, dest)
    Runtime.stuckSince = -math.huge
end

local function UpdateStuck(ward, now)
    local dest = Runtime.dest
    if not dest then
        Runtime.stuckSince = -math.huge
        return false
    end
    local wPos = Entity.GetAbsOrigin(ward)
    local dist = Dist2(wPos, dest)
    local hold = Runtime.mode == "flee" and HOLD_EPS_FLEE or HOLD_EPS_HEAL
    if dist <= hold then
        Runtime.stuckSince = -math.huge
        Runtime.lastProgressDist = dist
        return false
    end

    local moving = NPC.GetActivity(ward) == Enum.GameActivity.ACT_DOTA_RUN
    local progressed = dist < Runtime.lastProgressDist - 25
    if progressed then
        Runtime.lastProgressDist = dist
    end
    if moving or progressed then
        Runtime.stuckSince = -math.huge
        return false
    end
    if Runtime.stuckSince < 0 then
        Runtime.stuckSince = now
    end
    return now - Runtime.stuckSince >= STUCK_TIME
end

local function UnstickDest(wPos, dest, threats, now)
    local pivot = Runtime.goal or dest
    local bestAlt = nil
    local bestScore = -math.huge
    for r = 2, #WALK_SEARCH_RINGS do
        local rad = math.max(96, WALK_SEARCH_RINGS[r])
        for a = 0, WALK_SEARCH_ANGLES - 1 do
            local ang = (math.pi * 2 * a) / WALK_SEARCH_ANGLES + now * 0.7
            local p = Vector(wPos.x + math.cos(ang) * rad, wPos.y + math.sin(ang) * rad, wPos.z)
            if IsWalkable(p) then
                local score = -Dist2(p, pivot) + MarginAt(p, threats) * 0.5 + rad * 0.05
                if score > bestScore then
                    bestScore = score
                    bestAlt = p
                end
            end
        end
        if bestAlt then
            break
        end
    end
    if bestAlt then
        return bestAlt
    end
    local near = FindNearbyWalkable(pivot, wPos)
    if near then
        return near
    end
    return dest
end

local function Tick()
    if not UI.enabled or UI.enabled:Get() ~= true then
        return
    end

    local me = Heroes.GetLocal()
    local player = Players.GetLocal()
    if not me or not player or Entity.IsAlive(me) ~= true then
        ResetRuntime()
        return
    end
    if NPC.GetUnitName(me) ~= HERO then
        ResetRuntime()
        return
    end

    local now = GameRules.GetGameTime()
    if now - Runtime.lastUpdateAt < UPDATE_INTERVAL then
        return
    end
    Runtime.lastUpdateAt = now

    local ward = FindWard(me, player)
    if not ward then
        Runtime.mode = "heal"
        Runtime.dest = nil
        Runtime.goal = nil
        Runtime.stuckSince = -math.huge
        Runtime.drawWard = nil
        Runtime.debugSnap = nil
        return
    end

    Runtime.drawWard = ward
    if now < Runtime.manualUntil then
        return
    end

    local radius = HealRadius(me)
    local threats = CollectThreats(ward, me)
    local wPos = Entity.GetAbsOrigin(ward)
    local pressured = IsPressured(wPos, threats)
    local planDest, planSafe, planMargin = ComputeHealPlan(me, ward, threats, radius)
    local mustFlee = pressured or not planSafe
    local safe = IsComfortablySafe(wPos, threats) and planSafe

    if mustFlee then
        Runtime.mode = "flee"
        Runtime.safeSince = -math.huge
    elseif Runtime.mode == "flee" then
        if safe then
            if Runtime.safeSince < 0 then
                Runtime.safeSince = now
            end
            if now - Runtime.safeSince >= SAFE_HOLD then
                Runtime.mode = "return"
            end
        else
            Runtime.safeSince = -math.huge
        end
    elseif Runtime.mode == "return" then
        if Dist2(wPos, planDest) <= ARRIVE_EPS * 1.6 then
            Runtime.mode = "heal"
        end
    else
        Runtime.mode = "heal"
    end

    local dest = planDest
    if Runtime.mode == "flee" then
        dest = ComputeFleeDest(ward, me, threats)
    end

    local stuck = UpdateStuck(ward, now)
    if stuck then
        dest = UnstickDest(wPos, dest, threats, now)
        Runtime.stuckSince = -math.huge
    end

    if UI.debug and UI.debug:Get() == true then
        local dbgThreats = {}
        for i = 1, #threats do
            local t = threats[i]
            dbgThreats[#dbgThreats + 1] = {
                pos = t.pos,
                hit = t.hit,
                keep = t.keep,
                dist = t.dist,
                ar = t.ar,
                arBonus = t.arBonus,
                hull = t.hull,
                ms = t.ms,
                ranged = t.ranged,
                name = t.name,
                isHero = t.isHero,
                margin = t.dist - t.hit,
                keepMargin = t.dist - t.keep,
            }
        end
        table.sort(dbgThreats, function(a, b)
            return a.margin < b.margin
        end)
        Runtime.debugSnap = {
            mode = Runtime.mode,
            mustFlee = mustFlee,
            pressured = pressured,
            planSafe = planSafe,
            planMargin = planMargin,
            wardDistToDest = Dist2(wPos, dest),
            wardMs = WardMoveSpeed(ward),
            healRadius = radius,
            threatCount = #threats,
            threats = dbgThreats,
            dest = dest,
            wardPos = wPos,
            scan = FormatScanStats(),
        }
        if now - Runtime.lastDbgLogAt >= 1.25 and Persistent.logger then
            Runtime.lastDbgLogAt = now
            local parts = {}
            for i = 1, math.min(#dbgThreats, 5) do
                local t = dbgThreats[i]
                parts[#parts + 1] = string.format(
                    "%s[%s] AR=%d/%d hit=%d keep=%d dist=%d m=%d",
                    t.name,
                    t.ranged and "R" or "M",
                    t.ar,
                    math.floor(t.arBonus),
                    math.floor(t.hit),
                    math.floor(t.keep),
                    math.floor(t.dist),
                    math.floor(t.margin)
                )
            end
            Persistent.logger:debug(
                string.format(
                    "mode=%s flee=%s threats=%d scan{%s} :: %s",
                    Runtime.mode,
                    tostring(mustFlee),
                    #threats,
                    FormatScanStats(),
                    (#parts > 0) and table.concat(parts, " | ") or "none"
                )
            )
        end
    else
        Runtime.debugSnap = nil
    end

    local settle = Runtime.mode == "flee" and HOLD_EPS_FLEE or HOLD_EPS_HEAL
    if stuck or Dist2(wPos, dest) > settle then
        IssueMove(ward, dest, Runtime.mode == "flee" or mustFlee or stuck, stuck)
    end
end

local function DrawWorldCircle(center, radius, segments, color, thickness)
    if radius <= 1 then
        return
    end
    local points = {}
    local step = (math.pi * 2) / segments
    for i = 0, segments do
        local a = i * step
        local world = Vector(center.x + math.cos(a) * radius, center.y + math.sin(a) * radius, center.z)
        local screen, visible = Render.WorldToScreen(world)
        if visible then
            points[#points + 1] = screen
        end
    end
    if #points >= 2 then
        Render.PolyLine(points, color, thickness)
    end
end
--#endregion

--#region Lifecycle
function Script.OnScriptsLoaded()
    Persistent.logger = Logger(NAME)

    local main = Menu.Find("Heroes", "Hero List", "Juggernaut", "Main Settings")
    if not main then
        main = Menu.Create("Heroes", "Hero List", "Juggernaut", "Main Settings")
        if Persistent.logger then
            Persistent.logger:warning("Main Settings not found; created Heroes/Hero List/Juggernaut/Main Settings")
        end
    end

    local group = main:Find("Ward Control")
    if not group then
        group = main:Create("Ward Control")
    end

    UI.enabled = group:Switch("Enable", true, ICON_ENABLE)
    UI.enabled:ToolTip(
        "Controls an existing Healing Ward: heals you/allies, flees by each enemy attack range, uses GridNav pathing, soft MoveTo so hero control stays free. Manual ward orders pause auto ~2s."
    )

    UI.healAllies = group:Switch("Heal allies", true, ICON_HEAL_ALLIES)
    UI.healAllies:ToolTip(
        "Also cover nearby allied heroes inside the aura. Off = prioritize only you. Ward stays ~220 behind the heal target, never on the model."
    )

    UI.allyHp = group:Slider("Ally HP %", 1, 100, 92)
    UI.allyHp:Icon(ICON_ALLY_HP)
    UI.allyHp:ToolTip(
        "Allies at/below this HP% get heal priority. You always count. Lower = only seriously wounded allies."
    )

    UI.fearCreeps = group:Switch("Fear creeps", true, ICON_FEAR_CREEPS)
    UI.fearCreeps:ToolTip("Treat lane creeps (and similar) as threats — they one-shot the ward. Off = only enemy heroes.")

    UI.debug = group:Switch("Debug", false, ICON_DEBUG)
    UI.debug:ToolTip(
        "Red ring = hit range (AR+hull+pad). Yellow = early flee keep-out. Panel: mode, threats, AR/hit/dist/margin."
    )

    UI.enabled:SetCallback(OnEnabledChanged, true)
    UI.debug:SetCallback(OnDebugChanged, true)

    if Persistent.logger then
        Persistent.logger:info("loaded")
    end
end

function Script.OnUpdate()
    if not Engine.IsInGame() then
        return
    end
    if GameRules.IsPaused() then
        return
    end
    if Input.IsInputCaptured() then
        return
    end
    Tick()
end

function Script.OnPrepareUnitOrders(data, _player, order, _target, _position, _ability, _orderIssuer, npc, _queue, _showEffects)
    if data and data.identifier == ORDER_MOVE then
        return true
    end
    if not UI.enabled or UI.enabled:Get() ~= true then
        return true
    end
    local me = Heroes.GetLocal()
    if not me or Entity.IsAlive(me) ~= true or NPC.GetUnitName(me) ~= HERO then
        return true
    end
    if not npc or NPC.GetUnitName(npc) ~= WARD_UNIT then
        return true
    end
    local player = Players.GetLocal()
    if not player or not IsOurWard(npc, me, player) then
        return true
    end

    if order == Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION
        or order == Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_TARGET
        or order == Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET
        or order == Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_MOVE
        or order == Enum.UnitOrder.DOTA_UNIT_ORDER_HOLD_POSITION
        or order == Enum.UnitOrder.DOTA_UNIT_ORDER_STOP
    then
        Runtime.manualUntil = GameRules.GetGameTime() + MANUAL_PAUSE
    end
    return true
end

function Script.OnDraw()
    if not UI.enabled or UI.enabled:Get() ~= true then
        return
    end
    if not UI.debug or UI.debug:Get() ~= true then
        return
    end

    local snap = Runtime.debugSnap
    local ward = Runtime.drawWard
    if not ward or Entity.IsAlive(ward) ~= true or not snap then
        return
    end

    EnsureFonts()
    local font = Persistent.font
    local fontSmall = Persistent.fontSmall
    if not font or not fontSmall then
        return
    end

    if snap.dest and snap.wardPos then
        local lineColor = snap.mode == "flee" and Color(255, 60, 60, 255) or Color(60, 220, 90, 255)
        local fromScreen, fromVis = Render.WorldToScreen(snap.wardPos)
        local toScreen, toVis = Render.WorldToScreen(snap.dest)
        if fromVis and toVis then
            Render.Line(fromScreen, toScreen, lineColor, 2)
            Render.FilledRect(
                Vec2(toScreen.x - 5, toScreen.y - 5),
                Vec2(toScreen.x + 5, toScreen.y + 5),
                lineColor
            )
        end
    end

    local maxDraw = math.min(#snap.threats, 8)
    for i = 1, maxDraw do
        local t = snap.threats[i]
        DrawWorldCircle(t.pos, t.hit, 28, Color(255, 40, 40, 200), 2)
        DrawWorldCircle(t.pos, t.keep, 28, Color(255, 220, 40, 160), 1.5)
        local hx, hon = t.pos:ToScreen()
        if hon then
            local labelColor = t.margin < 0 and Color(255, 70, 70, 255) or Color(255, 255, 255, 255)
            Render.Text(
                fontSmall,
                12,
                string.format("%s %s", t.name, t.ranged and "RANGED" or "MELEE"),
                Vec2(hx.x - 40, hx.y - 36),
                labelColor
            )
            Render.Text(
                fontSmall,
                12,
                string.format("AR %d->%d hit %d keep %d", t.ar, math.floor(t.arBonus), math.floor(t.hit), math.floor(t.keep)),
                Vec2(hx.x - 40, hx.y - 22),
                labelColor
            )
            Render.Text(
                fontSmall,
                12,
                string.format("dist %d m %d km %d", math.floor(t.dist), math.floor(t.margin), math.floor(t.keepMargin)),
                Vec2(hx.x - 40, hx.y - 8),
                labelColor
            )
        end
        if snap.wardPos then
            local linkColor = t.margin < 0 and Color(255, 60, 60, 200) or Color(40, 220, 255, 180)
            local a, av = Render.WorldToScreen(snap.wardPos)
            local b, bv = Render.WorldToScreen(t.pos)
            if av and bv then
                Render.Line(a, b, linkColor, 1)
            end
        end
    end

    local wx, won = Entity.GetAbsOrigin(ward):ToScreen()
    if not won then
        return
    end

    local lines = {
        string.format("mode=%s flee=%d pressured=%d", snap.mode, snap.mustFlee and 1 or 0, snap.pressured and 1 or 0),
        string.format(
            "planSafe=%d planM=%d dDest=%d",
            snap.planSafe and 1 or 0,
            math.floor(snap.planMargin),
            math.floor(snap.wardDistToDest)
        ),
        string.format(
            "wardMS=%d healR=%d threats=%d",
            math.floor(snap.wardMs),
            math.floor(snap.healRadius),
            snap.threatCount
        ),
        "scan " .. snap.scan,
        string.format("pad=%d react=%.1fs wardHull=%d", HIT_PAD, REACT_TIME, WARD_HULL),
    }
    for i = 1, math.min(#snap.threats, 5) do
        local t = snap.threats[i]
        lines[#lines + 1] = string.format(
            "#%d %s %s AR=%d hit=%d d=%d m=%d",
            i,
            t.name,
            t.ranged and "R" or "M",
            math.floor(t.arBonus),
            math.floor(t.hit),
            math.floor(t.dist),
            math.floor(t.margin)
        )
    end

    local lineH = 14
    local panelW = 340
    local panelH = #lines * lineH + 8
    local panelX = wx.x + 12
    local panelY = wx.y - 18 - panelH
    Render.FilledRect(Vec2(panelX, panelY), Vec2(panelX + panelW, panelY + panelH), Color(0, 0, 0, 160))
    for i = 1, #lines do
        local useFont = (i == 1) and font or fontSmall
        local size = (i == 1) and 13 or 12
        Render.Text(
            useFont,
            size,
            lines[i],
            Vec2(panelX + 4, panelY + 4 + (i - 1) * lineH),
            Color(255, 255, 255, 255)
        )
    end
end

function Script.OnEntityDestroy(entity)
    if Runtime.ward and entity == Runtime.ward then
        Runtime.ward = nil
        Runtime.drawWard = nil
        Runtime.debugSnap = nil
        Runtime.dest = nil
        Runtime.goal = nil
    end
end

function Script.OnGameEnd()
    ResetRuntime()
end
--#endregion

return Script
