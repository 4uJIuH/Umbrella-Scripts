---@diagnostic disable: undefined-global

local script = {}

local localization = qLocalization.new({
    en = {
        menu = {
            main = "Blast Off Catch",
            enabled = "Enabled",
            enabled_tip = "Catches an enemy Techies with Bushwhack in the air, after Blast Off has gone on cooldown and cost mana but before it lands; the net is shifted toward the nearest tree so he gets tied to it",
            branch = "Plant Iron Branch",
            branch_tip = "When a planted Iron Branch gives a clearly better chance than the trees along the leap, it is planted first and the net is thrown at it. Needs a branch in the main slots",
        },
        panel = {
            menu_failed = "Blast Off Catch: menu failed",
        },
    },
    ru = {
        menu = {
            main = "Ловля Blast Off",
            enabled = "Включить",
            enabled_tip = "Ловит вражеского Техиса сеткой в полёте — Blast Off уже ушёл в кд и потратил ману, но ещё не приземлился; сетка сдвигается к ближайшему дереву, чтобы его привязало",
            branch = "Ставить веточку",
            branch_tip = "Если посаженная Iron Branch даёт заметно лучший шанс, чем деревья у линии прыжка, сначала сажается веточка, потом кидается сетка. Веточка нужна в основных слотах",
        },
        panel = {
            menu_failed = "Ловля Blast Off: меню не создалось",
        },
    },
    cn = {
        menu = {
            main = "空中捕捉炸弹人",
            enabled = "启用",
            enabled_tip = "在敌方炸弹人自爆起飞的空中用野地奇袭抓住他：技能已进入冷却并消耗魔法，但尚未落地；网偏向最近的树，把他绑在树上",
            branch = "种铁树枝",
            branch_tip = "当种下铁树枝比跳跃路线附近的树有明显更高的机会时，先种树枝再投网。树枝需放在主物品栏",
        },
        panel = {
            menu_failed = "空中捕捉炸弹人: 菜单创建失败",
        },
    },
})

local Menu = localization.WrapLibrary(Menu)

local HERO = "npc_dota_hero_hoodwink"
local NET = "hoodwink_bushwhack"
local SUICIDE = "techies_suicide"
local LEAP = "modifier_techies_suicide_leap"
local LEAP_TIME = 0.75
local LEAP_REACH = 1000
local NET_SPEED = 1300
local NET_RADIUS = 265
local HERO_MARGIN = 40
local TREE_MARGIN = 40
local ORDER_LAG = 0.1
local MAX_LATENCY = 0.3
local CENTER_STEP = 50
local TAU_ERR = 0.05
local TAU_STEP = 0.02
local TICK = 1 / 30
local BRANCH = "item_branches"
local BRANCH_REACH = 375
local BRANCH_DELAY = 0.05
local BRANCH_PENALTY = 0.2
local BRANCH_CLEAR = 200
local TURN_EPS = 1
local STABLE_TIME = 0.05
local MIN_TAU = 0.12
local FLY_MARGIN = 0.1
local MIN_SAMPLE = 0.03
local STAND_AGE = 0.3

local HAS_ENUM = type(Enum) == "table"
local CAST_READY = HAS_ENUM and type(Enum.AbilityCastResult) == "table" and Enum.AbilityCastResult.READY or -1
local TEMP_TREES = type(TempTrees) == "table" and type(TempTrees.InRadius) == "function" and TempTrees.InRadius or nil
local AVG_LATENCY =type(NetChannel) == "table" and type(NetChannel.GetAvgLatency) == "function" and NetChannel.GetAvgLatency or nil

local ui = {}
local ready = false
local g_menu_error = nil
local S = { stand = {}, phase = {}, done = {}, reason = nil, updateError = nil, font = nil }

local function log(level, message, data)
    if type(ai_bridge) ~= "table" or type(ai_bridge.mcp_log) ~= "function" then return end
    pcall(ai_bridge.mcp_log, level, message, data)
end

local function initialize_menu()
    local side = (HAS_ENUM and Enum.GroupSide) or {}
    local section = Menu.Create("Heroes", "Hero List", "Hoodwink", "Blast Off Catch")
    local group = section:Create("menu.main", side.Left)

    ui.enabled = group:Switch("menu.enabled", true)
    pcall(ui.enabled.Image, ui.enabled, "panorama/images/spellicons/hoodwink_bushwhack_png.vtex_c")
    ui.enabled:ToolTip("menu.enabled_tip")
    ui.branch = group:Switch("menu.branch", true)
    pcall(ui.branch.Image, ui.branch, "panorama/images/items/branches_png.vtex_c")
    ui.branch:ToolTip("menu.branch_tip")
    return true
end

local function castable(h)
    return h ~= nil and Ability.GetLevel(h) > 0 and Ability.IsReady(h) and Ability.CanBeExecuted(h) == CAST_READY
end

local function trees_near(p, r)
    local out = {}
    for _, tree in ipairs(Trees.InRadius(p, r, true)) do out[#out + 1] = { pos = Entity.GetAbsOrigin(tree), temp = false } end
    for _, tree in ipairs(TEMP_TREES and TEMP_TREES(p, r) or {}) do out[#out + 1] = { pos = Entity.GetAbsOrigin(tree), temp = true } end
    return out
end

local function net_center(p, heroMargin)
    local keep = NET_RADIUS - TREE_MARGIN
    local best, bestD = nil, NET_RADIUS - heroMargin + keep
    for _, t in ipairs(trees_near(p, bestD)) do
        local d = (t.pos - p):Length2D()
        if d <= bestD then best, bestD = t, d end
    end
    if best == nil then return nil end
    local shift = math.max(0, bestD - keep) / math.max(bestD, 1)
    return Vector(p.x + (best.pos.x - p.x) * shift, p.y + (best.pos.y - p.y) * shift, p.z), best.temp
end

local function coverage(reach, lo, hi, frac)
    return math.max(0, math.min(reach, hi / frac) - math.max(0, lo / frac)) / reach
end

local function phase_leap(unit, ab, idx, now)
    local rot = Entity.GetRotation(unit)
    local yaw = rot:GetYaw()
    local p = S.phase[idx]
    if p == nil or math.abs((yaw - p.yaw + 180) % 360 - 180) > TURN_EPS then
        S.phase[idx] = { t = now, yaw = yaw, turned = p ~= nil }
        return nil
    end
    p.yaw = yaw
    if now - p.t < STABLE_TIME then return nil end
    local at = p.t + Ability.GetCastPoint(ab)
    p.at = at
    local fwd = rot:GetForward()
    local len = math.max(math.sqrt(fwd.x * fwd.x + fwd.y * fwd.y), 0.001)
    return {
        start = Entity.GetAbsOrigin(unit), dx = fwd.x / len, dy = fwd.y / len, at = at, flight = LEAP_TIME,
        reach = math.max(Ability.GetCastRange(ab) + NPC.GetCastRangeBonus(unit), LEAP_REACH),
    }
end

local function flight_leap(unit, mod, idx, now)
    local stand = S.stand[idx]
    local born = Modifier.GetCreationTime(mod)
    if stand == nil or born - stand.t > STAND_AGE then return nil, "no start position" end
    local p = S.phase[idx]
    if p ~= nil and p.at ~= nil and not p.logged then
        p.logged = true
        log("info", "leap start error", { real_minus_predicted = born - p.at, turned_in_phase = p.turned })
    end
    local elapsed = now - born
    if elapsed < MIN_SAMPLE then return nil, "sampling" end
    local flight = Modifier.GetDieTime(mod) - born
    if flight <= 0 or flight > 2 then flight = LEAP_TIME end
    local pos = Entity.GetAbsOrigin(unit)
    local dx, dy = pos.x - stand.pos.x, pos.y - stand.pos.y
    local dist = math.max(math.sqrt(dx * dx + dy * dy), 0.001)
    return { start = stand.pos, dx = dx / dist, dy = dy / dist, at = born, flight = flight, speed = dist / elapsed }
end

local function latency()
    local v = AVG_LATENCY and AVG_LATENCY() or 0
    if type(v) ~= "number" or v ~= v then return 0 end
    if v > 1 then v = v / 1000 end
    return math.max(0, math.min(v, MAX_LATENCY))
end

local function flight_plan(hero, net, leap, now, lag)
    local origin = Entity.GetAbsOrigin(hero)
    local castPoint = Ability.GetCastPoint(net)
    local range = Ability.GetCastRange(net) + NPC.GetCastRangeBonus(hero)
    local margin = HERO_MARGIN + leap.speed * TAU_ERR
    local last = leap.flight - FLY_MARGIN
    local function point(tau)
        local along = leap.speed * math.max(0, math.min(tau, leap.flight))
        return Vector(leap.start.x + leap.dx * along, leap.start.y + leap.dy * along, leap.start.z)
    end
    local late = nil
    for tau = MIN_TAU, last, TAU_STEP do
        local center, temp = net_center(point(tau), margin)
        if center ~= nil then
            local dist = (center - origin):Length2D()
            local arrive = now + lag + NPC.GetTimeToFacePosition(hero, center) + castPoint + dist / NET_SPEED - leap.at
            if dist <= range and arrive >= MIN_TAU and arrive <= last and (point(arrive) - center):Length2D() <= NET_RADIUS - margin then
                return center, "cast", { lands_after_leap_start = arrive, in_phase = false, speed = leap.speed, dist = dist, lag = lag, temp_tree = temp }
            end
            if dist <= range and (late == nil or arrive - tau < late) then late = arrive - tau end
        end
    end
    return nil, "nothing reachable in flight", { net_late_by = late, speed = leap.speed, turn = NPC.GetTimeToFacePosition(hero, point(last)) }
end

local function phase_plan(hero, net, leap, now, lag, branch)
    local origin = Entity.GetAbsOrigin(hero)
    local r, keep = NET_RADIUS - HERO_MARGIN, NET_RADIUS - TREE_MARGIN
    local range = Ability.GetCastRange(net) + NPC.GetCastRangeBonus(hero)
    local castPoint = Ability.GetCastPoint(net)
    local half = leap.reach / 2
    local mid = Vector(leap.start.x + leap.dx * half, leap.start.y + leap.dy * half, leap.start.z)
    local last = leap.flight - FLY_MARGIN
    local best, bestNext, bestBranch = { score = 0 }, 0, 0
    local function consider(tp, temp, base, planted)
        local tx, ty = tp.x - leap.start.x, tp.y - leap.start.y
        local proj = tx * leap.dx + ty * leap.dy
        if math.abs(ty * leap.dx - tx * leap.dy) > r + keep or proj < -r - keep or proj > leap.reach + r + keep then return end
        local penalty = planted and BRANCH_PENALTY or 0
        for c = math.max(0, proj - r - keep), math.min(leap.reach, proj + r + keep), CENTER_STEP do
            local px, py = leap.start.x + leap.dx * c, leap.start.y + leap.dy * c
            local ox, oy = tp.x - px, tp.y - py
            local d = math.max(math.sqrt(ox * ox + oy * oy), 1)
            local shift = math.max(0, d - keep)
            local side = shift * (oy * leap.dx - ox * leap.dy) / d
            if math.abs(side) < r then
                local center = Vector(px + ox / d * shift, py + oy / d * shift, leap.start.z)
                local dist = (center - origin):Length2D()
                local tau = base + dist / NET_SPEED
                local along = c + shift * (ox * leap.dx + oy * leap.dy) / d
                local w = math.sqrt(r * r - side * side)
                if dist <= range and tau >= MIN_TAU and tau <= last then
                    local s = coverage(leap.reach, along - w, along + w, tau / leap.flight) - penalty
                    if planted and s + penalty > bestBranch then bestBranch = s + penalty end
                    if s > best.score then best = { score = s, center = center, tau = tau, dist = dist, temp = temp, c = c, branch = planted } end
                end
                local fLo, fHi = math.max(tau + TICK, MIN_TAU) / leap.flight, last / leap.flight
                if dist <= range and fLo <= fHi then
                    local peak = math.max(fLo, math.min(fHi, (along + w) / leap.reach))
                    local future = math.max(coverage(leap.reach, along - w, along + w, fLo), coverage(leap.reach, along - w, along + w, peak))
                    bestNext = math.max(bestNext, future - penalty)
                end
            end
        end
    end

    local base = now + lag + NPC.GetTimeToFacePosition(hero, mid) + castPoint - leap.at
    for _, t in ipairs(trees_near(mid, half + r + keep)) do
        consider(t.pos, t.temp, base)
    end
    if branch ~= nil then
        for c = 0, leap.reach, CENTER_STEP do
            local p = Vector(leap.start.x + leap.dx * c, leap.start.y + leap.dy * c, leap.start.z)
            local hd = math.max((p - origin):Length2D(), 1)
            local k = math.min(1, BRANCH_REACH / hd)
            local q = Vector(origin.x + (p.x - origin.x) * k, origin.y + (p.y - origin.y) * k, leap.start.z)
            if (q - p):Length2D() <= keep and (q - leap.start):Length2D() >= BRANCH_CLEAR then
                consider(q, true, now + lag + NPC.GetTimeToFacePosition(hero, q) + BRANCH_DELAY + castPoint - leap.at, q)
            end
        end
    end
    if best.center == nil then return nil, bestNext > 0 and "waiting for leap" or "no tree near the leap" end
    if bestNext > best.score + 0.01 then return nil, "waiting for best chance" end
    return best.center, "cast", { lands_after_leap_start = best.tau, in_phase = true, score = best.score, along = best.c, dist = best.dist, lag = lag, temp_tree = best.temp, branch = best.branch and { x = best.branch.x, y = best.branch.y }, has_branch = branch ~= nil, branch_score = bestBranch }
end

local function nearest_tree(p)
    local best = nil
    for _, list in ipairs({ Trees.InRadius(p, 600, true), TEMP_TREES and TEMP_TREES(p, 600) or {} }) do
        for _, tree in ipairs(list) do
            local d = (Entity.GetAbsOrigin(tree) - p):Length2D()
            if best == nil or d < best then best = d end
        end
    end
    return best
end

local function unit_mods(unit)
    local names = {}
    for _, m in ipairs(NPC.GetModifiers(unit)) do
        local n = Modifier.GetName(m)
        if n:find("hoodwink", 1, true) or n:find("techies", 1, true) then names[#names + 1] = n end
    end
    return table.concat(names, ",")
end

local function watch(net, now)
    local w = S.watch
    if w == nil then return end
    local pos = Entity.GetAbsOrigin(w.unit)
    if not w.launched and Ability.GetCooldown(net) > 0 then
        w.launched = true
        log("info", "net launched", { after_order = now - w.sent, tau = now - w.at, predicted_tau = w.arrive - w.travel - w.at })
    end
    if not w.arrived and now >= w.arrive then
        w.arrived = true
        log("info", "net arrival", { tau = now - w.at, unit_to_center = (pos - w.center):Length2D(), leaping = NPC.HasModifier(w.unit, LEAP), tree_to_center = nearest_tree(w.center), tree_to_unit = nearest_tree(pos) })
    end
    local mods = unit_mods(w.unit)
    if mods ~= w.mods then
        w.mods = mods
        log("info", "watch mods", { tau = now - w.at, mods = mods, unit_to_center = (pos - w.center):Length2D() })
    end
    if now > w.arrive + 1.5 then S.watch = nil end
end

local function update()
    local hero = Heroes.GetLocal()
    if hero == nil or NPC.GetUnitName(hero) ~= HERO or not Entity.IsAlive(hero) then return end
    local net = NPC.GetAbility(hero, NET)
    local now = GameRules.GetGameTime()
    watch(net, now)
    for _, unit in ipairs(Heroes.GetAll()) do
        if not Entity.IsSameTeam(hero, unit) and Entity.IsAlive(unit) and not Entity.IsDormant(unit) then
            local idx = Entity.GetIndex(unit)
            local mod = NPC.GetModifier(unit, LEAP)
            local ab = mod == nil and NPC.GetAbility(unit, SUICIDE) or nil
            local leap, reason
            if mod ~= nil then
                leap, reason = flight_leap(unit, mod, idx, now)
            elseif ab ~= nil and Ability.IsInAbilityPhase(ab) then
                S.stand[idx] = { pos = Entity.GetAbsOrigin(unit), t = now }
                leap = phase_leap(unit, ab, idx, now)
            else
                S.stand[idx] = { pos = Entity.GetAbsOrigin(unit), t = now }
                S.phase[idx] = nil
            end
            local fresh = leap ~= nil and not (S.done[idx] and math.abs(S.done[idx] - leap.at) < 0.3)
            if (fresh or reason ~= nil) and castable(net) then
                local center, info
                local branch = NPC.GetItem(hero, BRANCH, true)
                if not ui.branch:Get() or not castable(branch) then branch = nil end
                if fresh then center, reason, info = (leap.reach and phase_plan or flight_plan)(hero, net, leap, now, ORDER_LAG + latency(), branch) end
                if reason ~= S.reason then
                    S.reason = reason
                    log("info", "leap " .. reason, info)
                end
                if center ~= nil then
                    if info.branch ~= nil then
                        Ability.CastPosition(branch, Vector(info.branch.x, info.branch.y, center.z))
                        Ability.CastPosition(net, center, true)
                    else
                        Ability.CastPosition(net, center)
                    end
                    S.watch = { unit = unit, center = center, sent = now, at = leap.at, arrive = leap.at + info.lands_after_leap_start, travel = info.dist / NET_SPEED, mods = unit_mods(unit) }
                    S.done[idx] = leap.at
                    S.reason = nil
                end
            end
        end
    end
end


function script.OnScriptsLoaded()
    local ok, res = pcall(initialize_menu)
    ready = ok and res == true
    if not ready then g_menu_error = ok and "initialize_menu returned false" or tostring(res) end
    S.font = Render.LoadFont("Arial", 0, 500)
    log("info", "hoodwink_bushwhack_techies loaded", { menu_ready = ready, error = g_menu_error, temp_trees = TEMP_TREES ~= nil })
end

function script.OnUpdate()
    if not ready or not ui.enabled:Get() or not Engine.IsInGame() then return end
    local ok, err = pcall(update)
    if ok then
        S.updateError = nil
        return
    end
    if S.updateError == nil then log("error", "update failed", { error = tostring(err) }) end
    S.updateError = tostring(err)
end

function script.OnGameEnd()
    S.stand, S.phase, S.done, S.reason, S.updateError, S.watch = {}, {}, {}, nil, nil, nil
end

local function draw_error_banner()
    local title = g_menu_error and localization.Get("panel.menu_failed") or "Blast Off Catch"
    local msg = g_menu_error or S.updateError
    Render.FilledRect(Vec2(20, 400), Vec2(760, 446), Color(20, 20, 24, 235), 4)
    Render.Text(S.font, 14, title, Vec2(30, 406), Color(224, 50, 45, 245))
    Render.Text(S.font, 12, msg:sub(1, 150), Vec2(30, 426), Color(220, 220, 225, 240))
end

function script.OnDraw()
    if g_menu_error ~= nil or S.updateError ~= nil then pcall(draw_error_banner) end
end

return script
