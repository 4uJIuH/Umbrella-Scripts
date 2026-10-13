local SENTRY_RADIUS = 1050
local RING_TOL_BASE = 50
local RING_TOL_PER_SPEED = 0.05
local RING_TOL_MIN = 40
local RING_TOL_MAX = 150
local DISK_TOL = 80
local DISK_SAMPLE_INT = 0.1

local RANGE_REMOVE_TIME = 5.0
local RANGE_REMOVE_MARGIN = 150
local RANGE_CHECK_INT = 0.25

local TOWER_RADIUS = 700
local GEM_RADIUS = 900
local OUTPOST_RADIUS = 500
local NECRO_RADIUS = 900
local LINGER_TIME = 0.5
local LINGER_FUZZ = 50
local WARD_LIFETIME_MAX = 600
local WARD_LIFETIME_DEFAULT = 420
local CLUSTER_MERGE_DIST = 300
local LOCATED_TOLERANCE = 120
local SAMPLE_SEED_COUNT = 800
local RESEED_FLOOR = 50
local SOURCE_REBUILD_INT = 0.25
local HISTORY_RING_SIZE = 24
local HISTORY_SAMPLE_INT = 0.033
local UPDATE_THROTTLE_INT = 0.2
local WARD_SCAN_INT = 0.25

local ALLIED_TOWER_VISION = 1500
local ALLIED_OBS_VISION = 1400
local ALLIED_OUTPOST_VIS = 700
local ALLIED_FOUNTAIN_VIS = 2200
local WARD_DESTROY_RADIUS = 400
local REMOVE_CLICK_RADIUS = 220

local SOUND_REMOVED = "sounds/ui/click_simple.vsnd_c"
local SOUND_LOCATED = "sounds/ui/contract_objective_complete.vsnd_c"
local SOUND_VOLUME = 0.4

local KNOWN_TRUESIGHT_UNITS = {
    npc_dota_watch_tower = OUTPOST_RADIUS,
    npc_dota_necronomicon_warrior_1 = NECRO_RADIUS,
    npc_dota_necronomicon_warrior_2 = NECRO_RADIUS,
    npc_dota_necronomicon_warrior_3 = NECRO_RADIUS,
    npc_dota_necronomicon_warrior_4 = NECRO_RADIUS,
    npc_dota_necronomicon_warrior_5 = NECRO_RADIUS,
}

local mainGrp  = Menu.Create("Scripts", "Other", "Ward Triangulator", "Settings", "Main")
local detectGrp= Menu.Create("Scripts", "Other", "Ward Triangulator", "Settings", "Detection")
local perfGrp  = Menu.Create("Scripts", "Other", "Ward Triangulator", "Settings", "Performance")
local debugGrp = Menu.Create("Scripts", "Other", "Ward Triangulator", "Settings", "Debug")

local M = {}
M.enable      = mainGrp:Switch("Enable", true, "\u{f00c}")
M.showApprox  = mainGrp:Switch("Show approximate region", true, "\u{f192}")
M.showLocated = mainGrp:Switch("Show located wards", true, "\u{f06e}")
M.showIcon    = mainGrp:Switch("Show approx icon", true, "\u{f3c5}")
M.playSound   = mainGrp:Switch("Play ding on locate", true, "\u{f028}")
M.clickRemove = mainGrp:Switch("Ctrl+LMB removes ward", true, "\u{f1f8}")
M.iconSize    = mainGrp:Slider("Approx icon size", 16, 64, 28, "%dpx")
M.colorLoc    = mainGrp:ColorPicker("Located color", Color(80, 220, 255, 230))
M.colorAppr   = mainGrp:ColorPicker("Approx color", Color(80, 220, 255, 160))
M.expire      = mainGrp:Slider("Auto-expire (s)", 60, WARD_LIFETIME_MAX, WARD_LIFETIME_DEFAULT, "%ds")

M.holdMode    = detectGrp:Switch("Hold-key only mode", false, "\u{f11c}")
M.holdKey     = detectGrp:Bind("Detection key", Enum.ButtonCode.KEY_NONE, "\u{f11c}")
M.detectSelf  = detectGrp:Switch("Detect from your hero", true, "\u{f007}")
M.detectMates = detectGrp:Switch("Detect from teammates", true, "\u{f0c0}")
M.detectCreep = detectGrp:Switch("Detect from creeps/illusions", false, "\u{f111}")
M.rangeRemove = detectGrp:Switch("Auto-remove when proven absent", true, "\u{f00d}")

M.lowFps      = perfGrp:Switch("Lite render (fewer segments)", false, "\u{f0e7}")

M.dbgCentroid = debugGrp:Switch("Draw centroid + id label", false, "\u{f05b}")
M.dbgRings    = debugGrp:Switch("Draw constraint rings", false, "\u{f111}")

local function dist2(ax, ay, bx, by)
    local dx, dy = ax - bx, ay - by
    return dx*dx + dy*dy
end

local function try(fn, ...)
    local ok, a, b, c, d = pcall(fn, ...)
    if ok then return a, b, c, d end
    return nil
end

local function tbool(...)
    local v = try(...)
    return v == true
end

local function gameTime()
    return try(GameRules.GetGameTime) or 0
end

local function readCfg()
    return {
        enable = M.enable:Get(),
        showLocated = M.showLocated:Get(),
        showApprox = M.showApprox:Get(),
        showIcon = M.showIcon:Get(),
        playSound = M.playSound:Get(),
        clickRemove = M.clickRemove:Get(),
        iconSize = M.iconSize:Get(),
        colorLoc = M.colorLoc:Get(),
        colorAppr = M.colorAppr:Get(),
        dbgCentroid = M.dbgCentroid:Get(),
        dbgRings = M.dbgRings:Get(),
        expire = M.expire:Get(),
        holdMode = M.holdMode:Get(),
        holdKey = M.holdKey:Get(),
        detectSelf = M.detectSelf:Get(),
        detectMates = M.detectMates:Get(),
        detectCreep = M.detectCreep:Get(),
        rangeRemove = M.rangeRemove:Get(),
        lowFps = M.lowFps:Get(),
    }
end

local _cn, _ct, _ch, _cht
local function getNpcs()
    local t = gameTime()
    if t ~= _ct then _cn = try(NPCs.GetAll) or {}; _ct = t end
    return _cn
end
local function getHeroes()
    local t = gameTime()
    if t ~= _cht then _ch = try(Heroes.GetAll) or {}; _cht = t end
    return _ch
end

local function shouldTrack(u, me, cfg)
    if not u or not me then return false end
    if u == me then return cfg.detectSelf end
    if tbool(NPC.IsIllusion, u) then return cfg.detectCreep end
    if tbool(NPC.IsHero, u) then return cfg.detectMates end
    return cfg.detectCreep
end

local function detectionGated(cfg)
    if not cfg.holdMode then return false end
    local k = cfg.holdKey
    if not k or k == 0 then return true end
    return not tbool(Input.IsKeyDown, k)
end

local sentryIcon, dbgFont
local ICON_PATHS = {
    "panorama/images/items/ward_sentry_png.vtex_c",
    "panorama/images/hud/reborn/wards/sentry_psd.vtex_c",
    "panorama/images/items/ward_sentry.vtex_c",
}
local function getIcon()
    if sentryIcon == nil then
        for _, p in ipairs(ICON_PATHS) do
            local h = try(Render.LoadImage, p)
            if h then sentryIcon = h; break end
        end
        if sentryIcon == nil then sentryIcon = false end
    end
    return sentryIcon or nil
end
local function getFont()
    if dbgFont == nil then
        local flags = (Enum and Enum.FontCreate and Enum.FontCreate.FONTFLAG_ANTIALIAS) or 0
        dbgFont = try(Render.LoadFont, "Arial", flags, 400) or false
    end
    return dbgFont or nil
end

local knownSources = {}
local lastSourceRebuild = -math.huge

local function addSource(out, ent, radius, kind)
    local pos = try(Entity.GetAbsOrigin, ent)
    if not pos then return end
    out[#out+1] = { entity = ent, pos = pos, radius = radius, kind = kind }
end

local function isEnemy(ent, me)
    return try(Entity.IsSameTeam, ent, me) == false
end

local function rebuildSources(now, me)
    if now - lastSourceRebuild < SOURCE_REBUILD_INT then return end
    lastSourceRebuild = now
    local out = {}
    if not me then knownSources = out; return end

    for _, h in ipairs(getHeroes()) do
        if h ~= me
           and not tbool(Entity.IsDormant, h)
           and tbool(Entity.IsAlive, h)
           and isEnemy(h, me)
           and tbool(NPC.HasModifier, h, "modifier_item_gem") then
            addSource(out, h, GEM_RADIUS, "gem")
        end
    end

    for _, n in ipairs(getNpcs()) do
        if n and not tbool(Entity.IsDormant, n)
           and tbool(Entity.IsAlive, n) and isEnemy(n, me) then
            if tbool(NPC.IsTower, n) then
                addSource(out, n, TOWER_RADIUS, "tower")
            else
                local uname = try(NPC.GetUnitName, n)
                local r = uname and KNOWN_TRUESIGHT_UNITS[uname]
                if r then addSource(out, n, r, "npc:"..uname) end
            end
        end
    end

    knownSources = out
end

local alliedZones = {}
local lastAlliedRebuild = -math.huge

local function rebuildAlliedZones(now, me)
    if now - lastAlliedRebuild < SOURCE_REBUILD_INT then return end
    lastAlliedRebuild = now
    local out = {}
    if not me then alliedZones = out; return end

    for _, n in ipairs(getNpcs()) do
        if n and not tbool(Entity.IsDormant, n)
           and tbool(Entity.IsAlive, n)
           and tbool(Entity.IsSameTeam, n, me) then
            local pos = try(Entity.GetAbsOrigin, n)
            if pos then
                if tbool(NPC.IsTower, n) then
                    out[#out+1] = { pos = pos, radius = ALLIED_TOWER_VISION }
                else
                    local uname = try(NPC.GetUnitName, n) or ""
                    if uname == "npc_dota_observer_wards" then
                        out[#out+1] = { pos = pos, radius = ALLIED_OBS_VISION }
                    elseif uname == "npc_dota_watch_tower" then
                        out[#out+1] = { pos = pos, radius = ALLIED_OUTPOST_VIS }
                    elseif uname == "npc_dota_fountain" then
                        out[#out+1] = { pos = pos, radius = ALLIED_FOUNTAIN_VIS }
                    end
                end
            end
        end
    end

    alliedZones = out
end

local candidates = {}
local nextId = 1
local unitState = {}

local function newCandidate()
    local c = {
        id = nextId,
        eventRings = {},
        diskConstraints = {},
        candidatePoints = {},
        centroid = nil,
        uncertainty = math.huge,
        located = false,
        firstSeen = gameTime(),
        lastConfirmed = gameTime(),
        phasedParticle = nil,
        phasedAt = nil,
        phasedSpawnedAt = nil,
        dead = false,
        soundPlayed = false,
        knownLocated = false,
        wardEnt = nil,
        insideSince = nil,
    }
    nextId = nextId + 1
    candidates[#candidates+1] = c
    return c
end

local function killCandidate(c)
    if c.phasedParticle then
        try(Particle.Destroy, c.phasedParticle)
        c.phasedParticle = nil
        c.phasedAt = nil
    end
end

local function getOrMakeUnitState(idx)
    local s = unitState[idx]
    if not s then
        s = { posHistory = {}, head = 1, lastSampleTime = -math.huge }
        unitState[idx] = s
    end
    return s
end

local function pushHist(s, t, pos)
    if t - s.lastSampleTime < HISTORY_SAMPLE_INT then return end
    s.lastSampleTime = t
    s.posHistory[s.head] = { t = t, pos = pos }
    s.head = (s.head % HISTORY_RING_SIZE) + 1
end

local function lookupHistLerp(s, target)
    local before, after, bDt, aDt = nil, nil, math.huge, math.huge
    for i = 1, HISTORY_RING_SIZE do
        local e = s.posHistory[i]
        if e then
            local dt = e.t - target
            if dt <= 0 then
                if -dt < bDt then before = e; bDt = -dt end
            else
                if dt < aDt then after = e; aDt = dt end
            end
        end
    end
    if before and after and (bDt + aDt) > 1e-6 then
        local f = bDt / (bDt + aDt)
        local b, a = before.pos, after.pos
        return Vector(
            b.x + (a.x - b.x) * f,
            b.y + (a.y - b.y) * f,
            (b.z or 0) + ((a.z or 0) - (b.z or 0)) * f
        )
    end
    return (before and before.pos) or (after and after.pos) or nil
end

local function seedAnnulus(c, pos, r, tol)
    local pts = c.candidatePoints
    local rO, rI = r + tol, r - tol
    local rO2, rI2 = rO * rO, rI * rI
    local tries = 0
    while #pts < SAMPLE_SEED_COUNT and tries < SAMPLE_SEED_COUNT * 12 do
        tries = tries + 1
        local rx = (math.random() * 2 - 1) * rO
        local ry = (math.random() * 2 - 1) * rO
        local d2 = rx*rx + ry*ry
        if d2 <= rO2 and d2 >= rI2 then
            pts[#pts+1] = Vector(pos.x + rx, pos.y + ry, pos.z or 0)
        end
    end
end

local function pruneRing(c, pos, r, tol)
    local pts = c.candidatePoints
    local rO2 = (r + tol) * (r + tol)
    local rI2 = (r - tol) * (r - tol)
    for i = #pts, 1, -1 do
        local d2 = dist2(pts[i].x, pts[i].y, pos.x, pos.y)
        if d2 > rO2 or d2 < rI2 then
            pts[i] = pts[#pts]
            pts[#pts] = nil
        end
    end
end

local function pruneAlliedVision(c)
    local pts = c.candidatePoints
    for _, z in ipairs(alliedZones) do
        local r2 = z.radius * z.radius
        local zx, zy = z.pos.x, z.pos.y
        for i = #pts, 1, -1 do
            if dist2(pts[i].x, pts[i].y, zx, zy) <= r2 then
                pts[i] = pts[#pts]
                pts[#pts] = nil
            end
        end
    end
end

local function ringTolFor(witness)
    if not witness then return RING_TOL_BASE + 20 end
    local speed = try(NPC.GetMoveSpeed, witness) or 320
    return math.max(RING_TOL_MIN,
                    math.min(RING_TOL_MAX,
                             RING_TOL_BASE + speed * RING_TOL_PER_SPEED))
end

local function pruneInsideDisk(c, pos, r)
    local pts = c.candidatePoints
    local r2 = r * r
    for i = #pts, 1, -1 do
        if dist2(pts[i].x, pts[i].y, pos.x, pos.y) > r2 then
            pts[i] = pts[#pts]
            pts[#pts] = nil
        end
    end
end

local function reapplyAll(c)
    for _, ring in ipairs(c.eventRings) do
        pruneRing(c, ring.pos, SENTRY_RADIUS, ring.tol or RING_TOL_BASE + 50)
    end
    for _, d in ipairs(c.diskConstraints) do
        pruneInsideDisk(c, d.pos, SENTRY_RADIUS + DISK_TOL)
    end
    pruneAlliedVision(c)
end

local function recompute(c)
    local pts = c.candidatePoints
    if #pts == 0 then c.dead = true; return end
    local sx, sy, sz = 0, 0, 0
    for i = 1, #pts do
        sx = sx + pts[i].x
        sy = sy + pts[i].y
        sz = sz + (pts[i].z or 0)
    end
    local n = #pts
    c.centroid = Vector(sx/n, sy/n, sz/n)
    local maxd2 = 0
    for i = 1, n do
        local d2 = dist2(pts[i].x, pts[i].y, c.centroid.x, c.centroid.y)
        if d2 > maxd2 then maxd2 = d2 end
    end
    c.uncertainty = math.sqrt(maxd2)
    c.located = c.uncertainty <= LOCATED_TOLERANCE
end

local function reseedIfSparse(c)
    if c.knownLocated then return end
    if #c.candidatePoints >= RESEED_FLOOR then return end
    if c.uncertainty <= LOCATED_TOLERANCE then return end
    if #c.candidatePoints == 0 then return end
    local survivors = c.candidatePoints
    local fresh = {}
    local jitter = math.max(40, c.uncertainty * 0.4)
    local i = 1
    while #fresh < SAMPLE_SEED_COUNT do
        local p = survivors[i]
        if not p then i = 1; p = survivors[1] end
        local rx = (math.random() * 2 - 1) * jitter
        local ry = (math.random() * 2 - 1) * jitter
        fresh[#fresh+1] = Vector(p.x + rx, p.y + ry, p.z or 0)
        i = i + 1
    end
    c.candidatePoints = fresh
    reapplyAll(c)
end

local function plausible(c, pos)
    if #c.eventRings == 0 then return true end
    local d2max = (SENTRY_RADIUS * 2 + RING_TOL_MAX) ^ 2
    for _, ring in ipairs(c.eventRings) do
        if dist2(ring.pos.x, ring.pos.y, pos.x, pos.y) <= d2max then
            return true
        end
    end
    return false
end

local function ingestRing(pos, t, widx, kind, witness)
    local tol = ringTolFor(witness)

    for _, c in ipairs(candidates) do
        if not c.dead and (c.located or c.knownLocated) and c.centroid then
            local d2 = dist2(c.centroid.x, c.centroid.y, pos.x, pos.y)
            local rO = SENTRY_RADIUS + tol + (c.uncertainty or 0)
            local rI = SENTRY_RADIUS - tol - (c.uncertainty or 0)
            if d2 <= rO * rO and d2 >= rI * rI then
                c.lastConfirmed = t
                return
            end
        end
    end

    local hits = {}
    for _, c in ipairs(candidates) do
        if not c.dead and not c.located and not c.knownLocated and plausible(c, pos) then
            hits[#hits+1] = c
        end
    end

    if #hits == 0 then
        local c = newCandidate()
        seedAnnulus(c, pos, SENTRY_RADIUS, tol)
        c.eventRings[#c.eventRings+1] = { pos = pos, t = t, witness = widx, kind = kind, tol = tol }
        pruneAlliedVision(c)
        recompute(c)
        c.firstSeen = t
        c.lastConfirmed = t
        return
    end

    for _, c in ipairs(hits) do
        c.eventRings[#c.eventRings+1] = { pos = pos, t = t, witness = widx, kind = kind, tol = tol }
        pruneRing(c, pos, SENTRY_RADIUS, tol)
        pruneAlliedVision(c)
        recompute(c)
        reseedIfSparse(c)
        c.lastConfirmed = t
    end
end

local function ingestDisk(pos, t, widx)
    local r = SENTRY_RADIUS + DISK_TOL

    for _, c in ipairs(candidates) do
        if not c.dead and (c.located or c.knownLocated) and c.centroid then
            local reach = r + (c.uncertainty or 0)
            if dist2(c.centroid.x, c.centroid.y, pos.x, pos.y) <= reach * reach then
                c.lastConfirmed = t
                return
            end
        end
    end

    for _, c in ipairs(candidates) do
        if not c.dead and not c.located and not c.knownLocated and plausible(c, pos) then
            c.diskConstraints[#c.diskConstraints+1] = { pos = pos, t = t, witness = widx }
            pruneInsideDisk(c, pos, r)
            pruneAlliedVision(c)
            recompute(c)
            reseedIfSparse(c)
            c.lastConfirmed = t
        end
    end
end

local function registerKnownSentry(wardEnt, t)
    local pos = try(Entity.GetAbsOrigin, wardEnt)
    if not pos then return end
    for _, c in ipairs(candidates) do
        if c.centroid and not c.dead
           and dist2(c.centroid.x, c.centroid.y, pos.x, pos.y) < 800*800 then
            c.centroid = pos
            c.uncertainty = 0
            c.located = true
            c.knownLocated = true
            c.wardEnt = wardEnt
            c.lastConfirmed = t
            return
        end
    end
    local c = newCandidate()
    c.centroid = pos
    c.uncertainty = 0
    c.located = true
    c.knownLocated = true
    c.wardEnt = wardEnt
    c.firstSeen = t
    c.lastConfirmed = t
end

local function mergeNearby()
    local d2tight = CLUSTER_MERGE_DIST * CLUSTER_MERGE_DIST
    for i = 1, #candidates do
        local a = candidates[i]
        if a and not a.dead and a.centroid then
            for j = i + 1, #candidates do
                local b = candidates[j]
                if b and not b.dead and b.centroid then
                    local d2 = dist2(a.centroid.x, a.centroid.y, b.centroid.x, b.centroid.y)
                    local merge = false
                    if d2 <= d2tight then
                        merge = true
                    else
                        local au = (a.uncertainty or 0) * 0.8
                        local bu = (b.uncertainty or 0) * 0.8
                        if (not a.located and d2 <= au * au)
                           or (not b.located and d2 <= bu * bu) then
                            merge = true
                        end
                    end
                    if a.knownLocated and b.knownLocated then merge = false end

                    if merge then
                        local keep, drop = a, b
                        if #b.eventRings > #a.eventRings then
                            keep, drop = b, a
                        elseif #b.eventRings == #a.eventRings
                               and b.firstSeen < a.firstSeen then
                            keep, drop = b, a
                        end
                        if drop.knownLocated and not keep.knownLocated then
                            keep, drop = drop, keep
                        end
                        keep.lastConfirmed = math.max(keep.lastConfirmed, drop.lastConfirmed)
                        drop.dead = true
                    end
                end
            end
        end
    end
end

local lastWardScan = -math.huge
local lastSeenWards = {}

local function scanVisibleSentries(now, me)
    if now - lastWardScan < WARD_SCAN_INT then return end
    lastWardScan = now
    if not me then return end

    local visible = {}
    for _, n in ipairs(getNpcs()) do
        if n and not tbool(Entity.IsDormant, n)
           and tbool(Entity.IsAlive, n) and isEnemy(n, me) then
            local uname = try(NPC.GetUnitName, n) or ""
            local cname = try(Entity.GetClassName, n) or ""
            if uname == "npc_dota_sentry_wards" or cname == "CDOTA_NPC_TrueSight_Ward" then
                local pos = try(Entity.GetAbsOrigin, n)
                local idx = try(Entity.GetIndex, n)
                if pos and idx then
                    lastSeenWards[idx] = pos
                    visible[#visible+1] = { ent = n, idx = idx, pos = pos }
                end
            end
        end
    end

    for _, v in ipairs(visible) do
        local bound
        for _, c in ipairs(candidates) do
            if not c.dead and c.wardEnt == v.ent then bound = c; break end
        end
        if bound then
            bound.centroid = v.pos
            bound.uncertainty = 0
            bound.located = true
            bound.knownLocated = true
            bound.lastConfirmed = now
        else
            local bestC, bestD2 = nil, 800 * 800
            for _, c in ipairs(candidates) do
                if not c.dead and not c.wardEnt and c.centroid then
                    local d2 = dist2(c.centroid.x, c.centroid.y, v.pos.x, v.pos.y)
                    if d2 < bestD2 then bestD2 = d2; bestC = c end
                end
            end
            if bestC then
                bestC.centroid = v.pos
                bestC.uncertainty = 0
                bestC.located = true
                bestC.knownLocated = true
                bestC.wardEnt = v.ent
                bestC.lastConfirmed = now
            else
                local c = newCandidate()
                c.centroid = v.pos
                c.uncertainty = 0
                c.located = true
                c.knownLocated = true
                c.wardEnt = v.ent
                c.firstSeen = now
                c.lastConfirmed = now
            end
        end
    end
end

local lastSweep = -math.huge

local function lifetimeSweep(now, expire)
    if now - lastSweep < UPDATE_THROTTLE_INT then return end
    lastSweep = now
    for i = #candidates, 1, -1 do
        local c = candidates[i]
        local age = now - (c.firstSeen or now)
        if c.dead or age > expire then
            killCandidate(c)
            table.remove(candidates, i)
        end
    end
end

local function isFriendly(npc, me)
    if not me then return false end
    return tbool(Entity.IsSameTeam, npc, me)
end

local function casterExplained(caster, me)
    if not caster then return false end
    if tbool(Entity.IsDormant, caster) then return false end
    if tbool(Entity.IsSameTeam, caster, me) then return true end
    if tbool(NPC.IsTower, caster) then return true end
    local uname = try(NPC.GetUnitName, caster) or ""
    if KNOWN_TRUESIGHT_UNITS[uname] then return true end
    if uname:find("necronomicon") then return true end
    if uname:find("zuus") or uname:find("lightning_bolt") then return true end
    if uname:find("thinker") then return true end
    if tbool(NPC.HasModifier, caster, "modifier_item_gem") then return true end
    return false
end

local function casterIsSentry(caster)
    if not caster then return false end
    if tbool(Entity.IsDormant, caster) then return false end
    local uname = try(NPC.GetUnitName, caster) or ""
    if uname == "npc_dota_sentry_wards" then return true end
    local cname = try(Entity.GetClassName, caster) or ""
    return cname == "CDOTA_NPC_TrueSight_Ward"
end

local function knownSourceCovers(pos, me, now)
    rebuildSources(now, me)
    for i = 1, #knownSources do
        local s = knownSources[i]
        if dist2(pos.x, pos.y, s.pos.x, s.pos.y) <= (s.radius + LINGER_FUZZ)^2 then
            return true
        end
    end
    return false
end

local function onModCreate(npc, modifier, me, cfg)
    if try(Modifier.GetName, modifier) ~= "modifier_truesight" then return end
    if detectionGated(cfg) then return end
    if not isFriendly(npc, me) then return end
    if not shouldTrack(npc, me, cfg) then return end
    if not tbool(Entity.IsAlive, npc) then return end
    if tbool(Entity.IsDormant, npc) then return end
    if tbool(NPC.HasModifier, npc, "modifier_zuus_lightning_bolt") then return end

    local now = gameTime()
    local caster = try(Modifier.GetCaster, modifier)

    if casterIsSentry(caster) then
        registerKnownSentry(caster, now)
        return
    end
    if casterExplained(caster, me) then return end

    local pos = try(Entity.GetAbsOrigin, npc)
    if not pos then return end
    if knownSourceCovers(pos, me, now) then return end

    ingestRing(pos, now, try(Entity.GetIndex, npc) or -1, "enter", npc)
    mergeNearby()
end

local function onModDestroy(npc, modifier, me, cfg)
    if try(Modifier.GetName, modifier) ~= "modifier_truesight" then return end
    if detectionGated(cfg) then return end
    if not isFriendly(npc, me) then return end
    if not shouldTrack(npc, me, cfg) then return end

    local idx = try(Entity.GetIndex, npc)
    if not idx then return end

    local now = gameTime()
    local pos
    local s = unitState[idx]
    if s then pos = lookupHistLerp(s, now - LINGER_TIME) end
    if not pos then
        if tbool(Entity.IsAlive, npc) and not tbool(Entity.IsDormant, npc) then
            pos = try(Entity.GetAbsOrigin, npc)
        end
    end
    if not pos then return end

    local caster = try(Modifier.GetCaster, modifier)
    if casterExplained(caster, me) then return end
    if knownSourceCovers(pos, me, now - LINGER_TIME) then return end

    ingestRing(pos, now, idx, "exit", npc)
    mergeNearby()
end

local function onEntDestroy(entity)
    local idx = try(Entity.GetIndex, entity)
    if idx then
        unitState[idx] = nil
        lastSeenWards[idx] = nil
    end

    local cname = try(Entity.GetClassName, entity) or ""
    local uname = try(NPC.GetUnitName, entity) or ""
    if uname == "npc_dota_sentry_wards" or cname == "CDOTA_NPC_TrueSight_Ward" then
        for _, c in ipairs(candidates) do
            if not c.dead and c.wardEnt == entity then c.dead = true end
        end
        local pos = try(Entity.GetAbsOrigin, entity)
        if pos then
            local r2 = WARD_DESTROY_RADIUS * WARD_DESTROY_RADIUS
            for _, c in ipairs(candidates) do
                if not c.dead and c.centroid then
                    local d2 = dist2(c.centroid.x, c.centroid.y, pos.x, pos.y)
                    if d2 < r2 then c.dead = true end
                end
            end
        end
    end
end

local function onNpcSpawned(npc)
    local idx = try(Entity.GetIndex, npc)
    if idx then unitState[idx] = nil end
end

local CIRCLE_SEGMENTS_HIGH = 36
local CIRCLE_SEGMENTS_LOW  = 20

local function drawGroundCircle(center, radius, color, thickness, lite)
    if not center or not radius or radius <= 0 then return end
    thickness = thickness or 2
    local segs = lite and CIRCLE_SEGMENTS_LOW or CIRCLE_SEGMENTS_HIGH
    local step = (math.pi * 2) / segs
    local cx, cy, cz = center.x, center.y, center.z or 0
    local prevS, prevOk
    for i = 0, segs do
        local a = i * step
        local p = Vector(cx + radius * math.cos(a), cy + radius * math.sin(a), cz)
        local s, ok = try(Render.WorldToScreen, p)
        if i > 0 and prevOk and ok and prevS and s then
            try(Render.Line, prevS, s, color, thickness)
        end
        prevS, prevOk = s, ok
    end
end

local PHASED_PATHS = {
    "particles/items_fx/ward_sentry_creation.vpcf",
    "particles/items3_fx/ward_sentry_creation.vpcf",
    "particles/items_fx/ward_sentry_active.vpcf",
    "particles/items3_fx/ward_sentry_active.vpcf",
    "particles/items_fx/ward_sentry.vpcf",
    "particles/items3_fx/ward_sentry.vpcf",
    "particles/items3_fx/ward_sentry_active_aoe.vpcf",
    "particles/items_fx/ward_sentry_truesight_aura.vpcf",
    "particles/items_fx/sentry_truesight_aura.vpcf",
    "particles/items2_fx/ward_truesight_aura.vpcf",
}
local PATTACH_WORLDORIGIN  = (Enum and Enum.ParticleAttachment and Enum.ParticleAttachment.PATTACH_WORLDORIGIN) or 9
local PATTACH_CUSTOMORIGIN = (Enum and Enum.ParticleAttachment and Enum.ParticleAttachment.PATTACH_CUSTOMORIGIN) or 3

local goodPath, goodAttach

local function spawnPhased(pos)
    if goodPath then
        local p = try(Particle.Create, goodPath, goodAttach, nil)
        if p then
            try(Particle.SetControlPoint, p, 0, pos)
            try(Particle.SetControlPoint, p, 1, pos)
            try(Particle.SetControlPoint, p, 3, Vector(0.5, 0.5, 0.5))
            return p
        end
        goodPath = nil
    end
    for _, path in ipairs(PHASED_PATHS) do
        for _, attach in ipairs({ PATTACH_WORLDORIGIN, PATTACH_CUSTOMORIGIN }) do
            local p = try(Particle.Create, path, attach, nil)
            if p then
                goodPath = path
                goodAttach = attach
                try(Particle.SetControlPoint, p, 0, pos)
                try(Particle.SetControlPoint, p, 1, pos)
                try(Particle.SetControlPoint, p, 3, Vector(0.5, 0.5, 0.5))
                return p
            end
        end
    end
    return nil
end

local PHASED_RESPAWN_INT = 1.5

local function ensurePhased(c, now)
    if c.phasedParticle and (now - (c.phasedSpawnedAt or 0)) < PHASED_RESPAWN_INT then
        return
    end
    if c.phasedParticle then
        try(Particle.Destroy, c.phasedParticle)
        c.phasedParticle = nil
    end
    c.phasedParticle = spawnPhased(c.centroid)
    c.phasedAt = c.centroid
    c.phasedSpawnedAt = now
end

local function killPhased(c)
    if c.phasedParticle then
        try(Particle.Destroy, c.phasedParticle)
        c.phasedParticle = nil
        c.phasedAt = nil
        c.phasedSpawnedAt = nil
    end
end

local function drawIcon(c, cfg, color, mul)
    if not cfg.showIcon then return end
    local screen, ok = try(Render.WorldToScreen, c.centroid)
    if not screen or not ok then return end
    local size = cfg.iconSize * (mul or 1)
    local img = getIcon()
    if img then
        try(Render.Image, img,
            Vec2(screen.x - size/2, screen.y - size/2),
            Vec2(size, size), color)
    else
        try(Render.Circle, Vec2(screen.x, screen.y), size/2, color, 2)
    end
    if cfg.dbgCentroid then
        local font = getFont()
        if font then
            local label = string.format("#%d %d rings ±%du %ds",
                c.id, #c.eventRings, math.floor(c.uncertainty),
                math.floor(gameTime() - c.firstSeen))
            try(Render.Text, font, 12, label,
                Vec2(screen.x + size/2 + 4, screen.y - 6),
                Color(255, 255, 255, 220))
        end
    end
end

local function drawCandidate(c, cfg)
    local color, drawIt
    if c.located then
        color, drawIt = cfg.colorLoc, cfg.showLocated
    else
        color, drawIt = cfg.colorAppr, cfg.showApprox
    end
    if not drawIt then killPhased(c); return end

    local centerScreen, centerVis = try(Render.WorldToScreen, c.centroid)
    if not centerVis then killPhased(c); return end

    local now = gameTime()
    local lite = cfg.lowFps

    if c.located then
        if c.phasedAt and c.centroid
           and dist2(c.phasedAt.x, c.phasedAt.y, c.centroid.x, c.centroid.y) > 100*100 then
            killPhased(c)
        end
        ensurePhased(c, now)

        local pulse = 0.75 + 0.25 * math.sin(now * 4.0)
        local pulsed = Color(color.r, color.g, color.b, math.floor(color.a * pulse))
        drawGroundCircle(c.centroid, 80, pulsed, 2, lite)

        if cfg.dbgCentroid then
            local font = getFont()
            if centerScreen and font then
                local label = string.format("#%d %d rings ±%du %ds",
                    c.id, #c.eventRings, math.floor(c.uncertainty),
                    math.floor(now - c.firstSeen))
                try(Render.Text, font, 12, label,
                    Vec2(centerScreen.x + 16, centerScreen.y - 6),
                    Color(255, 255, 255, 220))
            end
        end
    else
        killPhased(c)
        local r = math.max(c.uncertainty, 60)
        drawGroundCircle(c.centroid, r, color, 2, lite)
        drawGroundCircle(c.centroid, math.min(r * 0.15, 40),
            Color(color.r, color.g, color.b, math.floor(color.a * 0.6)), 1, lite)
        drawIcon(c, cfg, color, 1.0)
    end
end

local function maybeDing(c, cfg)
    if c.soundPlayed or not c.located or not cfg.playSound then return end
    try(Engine.PlayVol, SOUND_LOCATED, SOUND_VOLUME)
    c.soundPlayed = true
end

local DEBUG_RING_SEGMENTS_HIGH = 28
local DEBUG_RING_SEGMENTS_LOW  = 16

local function drawConstraints(c, lite)
    local segs = lite and DEBUG_RING_SEGMENTS_LOW or DEBUG_RING_SEGMENTS_HIGH
    local function ring(center, radius, color)
        if not center or radius <= 0 then return end
        local cx, cy, cz = center.x, center.y, center.z or 0
        local step = (math.pi * 2) / segs
        local prevS, prevOk
        for i = 0, segs do
            local a = i * step
            local p = Vector(cx + radius * math.cos(a), cy + radius * math.sin(a), cz)
            local s, ok = try(Render.WorldToScreen, p)
            if i > 0 and prevOk and ok and prevS and s then
                try(Render.Line, prevS, s, color, 1)
            end
            prevS, prevOk = s, ok
        end
    end
    for _, r in ipairs(c.eventRings) do
        local color = (r.kind == "exit") and Color(255, 80, 80, 130)
                                         or  Color(80, 255, 120, 130)
        ring(r.pos, SENTRY_RADIUS, color)
    end
    local diskColor = Color(120, 180, 255, 90)
    for _, d in ipairs(c.diskConstraints) do
        ring(d.pos, SENTRY_RADIUS, diskColor)
    end
end

local lastDiskScan = -math.huge

local function sampleDisks(now, me, cfg)
    if (now - lastDiskScan) < DISK_SAMPLE_INT then return end
    lastDiskScan = now
    if not me then return end
    if detectionGated(cfg) then return end

    local function check(u)
        if not u then return end
        if not shouldTrack(u, me, cfg) then return end
        if not tbool(Entity.IsAlive, u) then return end
        if tbool(Entity.IsDormant, u) then return end
        if not tbool(Entity.IsSameTeam, u, me) then return end
        if not tbool(NPC.HasModifier, u, "modifier_truesight") then return end
        if tbool(NPC.HasModifier, u, "modifier_zuus_lightning_bolt") then return end

        local mod = try(NPC.GetModifier, u, "modifier_truesight")
        if mod then
            local caster = try(Modifier.GetCaster, mod)
            if casterExplained(caster, me) then return end
        end
        local pos = try(Entity.GetAbsOrigin, u)
        if not pos then return end
        if knownSourceCovers(pos, me, now) then return end

        ingestDisk(pos, now, try(Entity.GetIndex, u) or -1)
    end

    for _, h in ipairs(getHeroes()) do check(h) end
    if cfg.detectCreep then
        for _, n in ipairs(getNpcs()) do
            if n and not tbool(NPC.IsTower, n) and not tbool(NPC.IsStructure, n)
               and not tbool(NPC.IsHero, n) then
                check(n)
            end
        end
    end
end

local function checkClickRemove(cfg)
    if not cfg.clickRemove then return end
    if not Enum or not Enum.ButtonCode then return end
    if not tbool(Input.IsKeyDown, Enum.ButtonCode.KEY_LCONTROL) then return end
    if not tbool(Input.IsKeyDownOnce, Enum.ButtonCode.KEY_MOUSE1) then return end
    local worldPos = try(Input.GetWorldCursorPos)
    if not worldPos then return end

    local bestC, bestD2 = nil, REMOVE_CLICK_RADIUS * REMOVE_CLICK_RADIUS
    for _, c in ipairs(candidates) do
        if not c.dead and c.centroid then
            local d2 = dist2(c.centroid.x, c.centroid.y, worldPos.x, worldPos.y)
            if d2 < bestD2 then bestD2 = d2; bestC = c end
        end
    end
    if bestC then
        bestC.dead = true
        try(Engine.PlayVol, SOUND_REMOVED, 0.3)
    end
end

local lastHistScan = -math.huge

local function trackHistory(now, me, cfg)
    if not me then return end
    if now - lastHistScan < HISTORY_SAMPLE_INT then return end
    lastHistScan = now

    local function record(ent)
        if not ent then return end
        if not tbool(Entity.IsAlive, ent) then return end
        if tbool(Entity.IsDormant, ent) then return end
        if not tbool(Entity.IsSameTeam, ent, me) then return end
        local idx = try(Entity.GetIndex, ent)
        local pos = try(Entity.GetAbsOrigin, ent)
        if idx and pos then
            pushHist(getOrMakeUnitState(idx), now, pos)
        end
    end

    for _, h in ipairs(getHeroes()) do record(h) end
    if not cfg.detectCreep then return end
    for _, n in ipairs(getNpcs()) do
        if n and not tbool(NPC.IsTower, n) and not tbool(NPC.IsStructure, n)
           and not tbool(NPC.IsHero, n) then
            record(n)
        end
    end
end

local lastRangeCheck = -math.huge

local function checkRangeRemoval(now, me, cfg)
    if not cfg.rangeRemove then return end
    if not me then return end
    if now - lastRangeCheck < RANGE_CHECK_INT then return end
    lastRangeCheck = now

    local mePos = try(Entity.GetAbsOrigin, me)
    if not mePos then return end
    local hasTrue = tbool(NPC.HasModifier, me, "modifier_truesight")

    for _, c in ipairs(candidates) do
        if not c.dead and not c.knownLocated and c.centroid then
            local u = c.uncertainty or 0
            local r = SENTRY_RADIUS - RANGE_REMOVE_MARGIN - u
            if r > 100 then
                local d2 = dist2(mePos.x, mePos.y, c.centroid.x, c.centroid.y)
                if d2 <= r * r and not hasTrue then
                    if not c.insideSince then c.insideSince = now end
                    if (now - c.insideSince) >= RANGE_REMOVE_TIME then
                        c.dead = true
                    end
                else
                    c.insideSince = nil
                end
            else
                c.insideSince = nil
            end
        end
    end
end

local function OnUpdate()
    local cfg = readCfg()
    if not cfg.enable then
        for i = #candidates, 1, -1 do
            killCandidate(candidates[i])
            candidates[i] = nil
        end
        return
    end
    local me = try(Heroes.GetLocal)
    local now = gameTime()
    trackHistory(now, me, cfg)
    rebuildSources(now, me)
    rebuildAlliedZones(now, me)
    scanVisibleSentries(now, me)
    sampleDisks(now, me, cfg)
    checkRangeRemoval(now, me, cfg)
    mergeNearby()
    lifetimeSweep(now, cfg.expire)
    checkClickRemove(cfg)
end

local function OnDraw()
    local cfg = readCfg()
    if not cfg.enable then return end
    if #candidates == 0 then return end
    for _, c in ipairs(candidates) do
        if c.centroid and not c.dead then
            drawCandidate(c, cfg)
            maybeDing(c, cfg)
            if cfg.dbgRings then drawConstraints(c, cfg.lowFps) end
        end
    end
end

local function OnModifierCreate(npc, modifier)
    local cfg = readCfg()
    if not cfg.enable then return end
    local me = try(Heroes.GetLocal)
    if not me then return end
    onModCreate(npc, modifier, me, cfg)
end

local function OnModifierDestroy(npc, modifier)
    local cfg = readCfg()
    if not cfg.enable then return end
    local me = try(Heroes.GetLocal)
    if not me then return end
    onModDestroy(npc, modifier, me, cfg)
end

local function OnNpcSpawned(npc)
    onNpcSpawned(npc)
end

local function OnEntityDestroy(entity)
    onEntDestroy(entity)
end

local function guard(fn, name)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok and Log and Log.Write then
            pcall(Log.Write, "[WardTriangulator/"..name.."] "..tostring(err))
        end
    end
end

return {
    OnUpdate          = guard(OnUpdate,          "OnUpdate"),
    OnDraw            = guard(OnDraw,            "OnDraw"),
    OnModifierCreate  = guard(OnModifierCreate,  "OnModifierCreate"),
    OnModifierDestroy = guard(OnModifierDestroy, "OnModifierDestroy"),
    OnNpcSpawned      = guard(OnNpcSpawned,      "OnNpcSpawned"),
    OnEntityDestroy   = guard(OnEntityDestroy,   "OnEntityDestroy"),
}
