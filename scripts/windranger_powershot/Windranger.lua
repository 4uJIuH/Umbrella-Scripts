--[[ ====================================================================
     WIND RANGER  -  POWERSHOT (2-й скилл): ДОБИВАНИЕ / СТИЛ УБИЙСТВ
     Один файл, Umbrella Lua API. Меню во вкладке героя:
         Heroes -> Hero List -> Windranger -> Main Settings
     --------------------------------------------------------------------
     * считает урон Powershot (броня/магсопр, реген, юниты на линии)
     * УПРЕЖДАЕТ движение цели (в т.ч. при беге по кривой траектории)
     * РАННИЙ ВЫПУСК: заряжает стрелу ровно столько, сколько нужно для
       убийства -> короткое время полёта -> точный выстрел по бегущим
     * СТИЛ У СОЮЗНИКОВ: прогнозирует потерю здоровья цели от урона
       союзников и выпускает стрелу так, чтобы забрать убийство
     * не даёт своим кликами сбить заряд (можно отключить)
     * две темы: синяя (Аркана) и зелёная (Wind Ranger)
==================================================================== ]]

local script = {}

------------------------------------------------------------------------
--  НАСТРОЙКИ
------------------------------------------------------------------------
local HERO_NAME    = "npc_dota_hero_windrunner"
local ABILITY_NAME = "windrunner_powershot"
local HERO_TAB     = "Windranger"
local ICON         = "panorama/images/spellicons/windrunner_powershot_png.vtex_c"

local CAST_DELAY = 0.35     -- анимация каста + поворот (сек)
local MIN_CHARGE = 0.35     -- минимальный заряд при раннем выпуске (сек)
local EVAL_STEP  = 0.05     -- частота пересчёта целей
local CAST_LOCK  = 0.6      -- пауза между кастами

local FALLBACK = { range = 2600, speed = 3000, width = 125, reduction = 0.20 }

local PROTECT_MODS = {
    "modifier_dazzle_shallow_grave", "modifier_oracle_false_promise_timer",
    "modifier_abaddon_borrowed_time", "modifier_item_aeon_disk_buff",
    "modifier_templar_assassin_refraction_absorb",
    "modifier_skeleton_king_reincarnation_scepter_active",
}

-- Свой арт для тем (путь к PNG). Пусто = стандартный арт / эмблема Аркана
local CUSTOM_ART = { blue = "", green = "" }
local GREEN_ART = {
    "panorama/images/heroes/selection/npc_dota_hero_windrunner_png.vtex_c",
    "panorama/images/heroes/npc_dota_hero_windrunner_png.vtex_c",
}

------------------------------------------------------------------------
--  ХЕЛПЕРЫ
------------------------------------------------------------------------
local unpack = table.unpack or unpack

local function try(fn, ...)
    local ok, a, b, c = pcall(fn, ...)
    if ok then return a, b, c end
    return nil
end

local function hyp(x, y) return math.sqrt(x * x + y * y) end
local function d2(a, b) return hyp(a.x - b.x, a.y - b.y) end
local function now() return GameRules.GetGameTime() end
local function clock() if os and os.clock then return os.clock() end return now() end
local function C(r, g, b, a) return Color(math.floor(r), math.floor(g), math.floor(b), math.floor(a or 255)) end
local function CG(c, a) return C(c[1], c[2], c[3], a or 255) end
local function ulen(s) return select(2, s:gsub("[^\128-\191]", "")) end

local logged = {}
local function logOnce(tag, err)
    local key = tag .. tostring(err)
    if logged[key] then return end
    logged[key] = true
    print("[WR Powershot] " .. tag .. ": " .. tostring(err))
end

local function hasState(npc, name)
    local st = Enum.ModifierState and Enum.ModifierState[name]
    if not st then return false end
    return try(NPC.HasState, npc, st) and true or false
end

------------------------------------------------------------------------
--  МЕНЮ (внутри вкладки Windranger)
------------------------------------------------------------------------
local ui = {}
do
    local grp
    local function build(a, b, c)
        local tab = Menu.Create(a, b, c)
        local sec = tab:Create("Main Settings")
        return sec:Create("Powershot: добивание и стил")
    end
    if not pcall(function() grp = build("Heroes", "Hero List", HERO_TAB) end) or not grp then
        pcall(function() grp = build("Scripts", "User Scripts", "Windranger Powershot") end)
    end

    local function fake(def)
        local v = def
        return { Get = function() return v end, Set = function(_, x) v = x end }
    end

    local function mk(kind, def, args, iconArgs, tip)
        if grp then
            for _, a in ipairs({ iconArgs or false, args }) do
                if a then
                    local ok, w = pcall(function() return grp[kind](grp, unpack(a)) end)
                    if ok and w then
                        if tip then pcall(function() w:ToolTip(tip) end) end
                        return w
                    end
                end
            end
        end
        return fake(def)
    end

    local N1 = "Добивать героев Powershot (W)"
    ui.enable  = mk("Switch", true,  { N1, true }, { N1, true, ICON },
                    "Автоматически кастует Powershot, если урона хватает, чтобы убить вражеского героя")
    ui.key     = mk("Bind",   Enum.ButtonCode.KEY_NONE, { "Клавиша (пусто = всегда активно)", Enum.ButtonCode.KEY_NONE })
    ui.margin  = mk("Slider", 8,     { "Запас урона, %", 0, 50, 8, "%d" }, nil,
                    "Насколько урон должен превышать здоровье цели")
    ui.predictMode = mk("Combo", 2,  { "Упреждение цели", { "Выкл (только стоящие/CC)", "Только по прямой", "Любая траектория" }, 2 })
    ui.early   = mk("Switch", true,  { "Умный ранний выпуск", true }, nil,
                    "Постоянно проверяет цель во время заряда и отпускает стрелу в первый момент, когда урона ТОЧНО хватает - не раньше")
    ui.steal   = mk("Switch", true,  { "Стилить убийства у союзников", true }, nil,
                    "Слегка учитывает недавний урон союзников по цели при отпускании стрелы (безопасно, короткое окно)")
    ui.skipDef = mk("Switch", true,  { "Пропускать BKB / Aeon / Grave и т.п.", true })
    ui.pierce  = mk("Switch", true,  { "Учитывать снижение урона от юнитов на линии", true })
    ui.safe    = mk("Slider", 0,     { "Не кастовать, если враг ближе (0 = выкл)", 0, 1200, 0, "%d" })
    ui.guard   = mk("Switch", true,  { "Не сбивать заряд своими кликами", true }, nil,
                    "Пока идёт заряд Powershot, скрипт блокирует твои приказы движения/атаки. Stop и Hold проходят")
    ui.channel = mk("Slider", 1.0,   { "Время заряда, сек (если не читается)", 0.5, 3.0, 1.0, "%.1f" })
    ui.manual  = mk("Slider", 0,     { "Урон Powershot вручную (0 = авто)", 0, 2000, 0, "%d" })
    ui.theme   = mk("Combo",  0,     { "Тема оформления", { "Синяя (Аркана)", "Зелёная (Wind Ranger)" }, 0 })
    ui.draw    = mk("Switch", true,  { "Индикаторы и панель на экране", true })
    ui.debug   = mk("Switch", false, { "Отладка (панель + консоль)", false })
end

------------------------------------------------------------------------
--  СОСТОЯНИЕ
------------------------------------------------------------------------
local S = {
    hero = nil, player = nil, active = false, own = false,
    track = {}, units = {}, evals = {}, best = nil,
    status = { text = "Ожидание", kind = "info" },
    info = nil, infoT = -10,
    lastTrack = -10, lastEval = -10, lastCast = -10, lastDebug = -10,
    cast = nil, ready = false, cd = 0,
    panelX = 80, panelY = 92, drag = false, dragOx = 0, dragOy = 0,
    font = nil, fontB = nil, icon = nil, artBlue = nil, artGreen = nil, loaded = false,
}

------------------------------------------------------------------------
--  ТРЕКИНГ ВРАГОВ (позиция + здоровье)
------------------------------------------------------------------------
local function trackEnemies(hero, t)
    if t - S.lastTrack < 0.04 then return end
    S.lastTrack = t
    local seen = {}
    for _, e in ipairs(Heroes.GetAll()) do
        if e ~= hero and not Entity.IsSameTeam(hero, e) and Entity.IsAlive(e)
            and not Entity.IsDormant(e) and not NPC.IsIllusion(e) then
            local idx = Entity.GetIndex(e)
            local p = Entity.GetAbsOrigin(e)
            local tr = S.track[idx]
            if not tr then tr = {}; S.track[idx] = tr end
            local last = tr[#tr]
            if last and d2(p, last) > 600 then         -- блинк/телепорт: история недействительна
                for i = #tr, 1, -1 do tr[i] = nil end
            end
            tr[#tr + 1] = { t = t, x = p.x, y = p.y, hp = Entity.GetHealth(e) or 0 }
            while #tr > 0 and t - tr[1].t > 1.8 do table.remove(tr, 1) end
            seen[idx] = true
        end
    end
    for idx in pairs(S.track) do
        if not seen[idx] then S.track[idx] = nil end
    end
end

local function windowVel(tr, tEnd, span)
    local first, last
    for i = 1, #tr do
        local s = tr[i]
        if s.t >= tEnd - span and s.t <= tEnd + 0.001 then
            if not first then first = s end
            last = s
        end
    end
    if not first or first == last or (last.t - first.t) < span * 0.5 then return nil end
    local dt = last.t - first.t
    return (last.x - first.x) / dt, (last.y - first.y) / dt
end

-- {vx, vy, sp, stable} или nil
local function motion(idx, t)
    local tr = S.track[idx]
    if not tr or #tr < 4 then return nil end
    local ax, ay = windowVel(tr, t, 0.4)
    if not ax then ax, ay = windowVel(tr, t, 0.8) end
    if not ax then return nil end
    local sp = hyp(ax, ay)
    if sp < 35 then return { vx = 0, vy = 0, sp = 0, stable = true } end
    local stable = false
    local bx, by = windowVel(tr, t - 0.4, 0.4)
    if bx then
        local sb = hyp(bx, by)
        if sb > 35 then
            local dot = (ax * bx + ay * by) / (sp * sb)
            local ratio = sp / sb
            stable = dot > 0.93 and ratio > 0.7 and ratio < 1.4
        end
    end
    local vx, vy = ax, ay
    if not stable then
        local cx, cy = windowVel(tr, t, 0.9)         -- сглаживаем длинным окном
        if cx then vx, vy = (ax + cx) / 2, (ay + cy) / 2 end
    end
    return { vx = vx, vy = vy, sp = hyp(vx, vy), stable = stable }
end

-- скорость потери здоровья (hp/сек) за последнюю секунду
local function hpLoss(idx)
    local tr = S.track[idx]
    if not tr or #tr < 3 then return 0 end
    local last, ref = tr[#tr], nil
    for i = #tr, 1, -1 do
        if last.t - tr[i].t >= 0.9 then ref = tr[i]; break end
    end
    ref = ref or tr[1]
    local dt = last.t - ref.t
    if dt < 0.3 then return 0 end
    local loss = (ref.hp - last.hp) / dt
    return loss > 0 and loss or 0
end

------------------------------------------------------------------------
--  СПОСОБНОСТЬ И ЦЕЛИ
------------------------------------------------------------------------
local function sv(ab, names)
    for _, n in ipairs(names) do
        local v = try(Ability.GetLevelSpecialValueFor, ab, n)
        if type(v) == "number" and v > 0 then return v end
    end
    return nil
end

local function abilityInfo(ab, t)
    if S.info and t - S.infoT < 0.5 then return S.info end
    local info = { ab = ab }
    local manual = ui.manual:Get() or 0
    if manual > 0 then
        info.dmg = manual
    else
        info.dmg = sv(ab, { "powershot_damage", "damage", "AbilityDamage" })
        if not info.dmg then
            local v = try(Ability.GetDamage, ab)
            if type(v) == "number" and v > 0 then info.dmg = v end
        end
    end
    local arrowRange = sv(ab, { "arrow_range", "tooltip_range", "range" }) or FALLBACK.range
    local castRange = try(Ability.GetCastRange, ab)
    if type(castRange) == "number" and castRange > 300 then arrowRange = math.min(arrowRange, castRange) end
    info.range = arrowRange - 60
    info.speed = sv(ab, { "arrow_speed", "speed" }) or FALLBACK.speed
    info.width = sv(ab, { "arrow_width", "width" }) or FALLBACK.width
    local red = sv(ab, { "damage_reduction", "damage_reduction_pct" }) or FALLBACK.reduction
    if red > 1 then red = red / 100 end
    info.reduction = math.min(red, 0.9)
    info.channel = sv(ab, { "channel_time", "max_channel_time", "powershot_channel_time" }) or ui.channel:Get()
    if info.channel > 5 then info.channel = ui.channel:Get() end
    S.info, S.infoT = info, t
    return info
end

local function dmgMult(target, ab)
    local D = Enum.DamageTypes
    local dt = try(Ability.GetDamageType, ab)
    if D and dt == D.DAMAGE_TYPE_PURE then return 1 end
    if D and dt == D.DAMAGE_TYPE_MAGICAL then
        return try(NPC.GetMagicalArmorDamageMultiplier, target) or 0.75
    end
    return try(NPC.GetArmorDamageMultiplier, target) or 0.8
end

local function isProtected(target)
    for _, m in ipairs(PROTECT_MODS) do
        if try(NPC.HasModifier, target, m) then return true end
    end
    local aeon = try(NPC.GetItem, target, "item_aeon_disk", true)
    if aeon and try(Ability.IsReady, aeon) then return true end
    return false
end

local function disableInfo(target)
    local dis = false
    for _, name in ipairs({ "MODIFIER_STATE_STUNNED", "MODIFIER_STATE_ROOTED",
                            "MODIFIER_STATE_HEXED", "MODIFIER_STATE_FROZEN" }) do
        if hasState(target, name) then dis = true; break end
    end
    if not dis and try(NPC.IsStunned, target) then dis = true end
    if not dis then return { disabled = false } end
    local left
    local mods = try(NPC.GetModifiers, target)
    if mods then
        for _, m in ipairs(mods) do
            if try(Modifier.IsStunDebuff, m) then
                local die = try(Modifier.GetDieTime, m)
                if type(die) == "number" then
                    local l = die - now()
                    if not left or l > left then left = l end
                end
            end
        end
    end
    return { disabled = true, left = left }
end

local function collectUnits(hero)
    local list = {}
    for _, u in ipairs(NPCs.GetAll()) do
        if Entity.IsAlive(u) and not Entity.IsDormant(u) and not Entity.IsSameTeam(hero, u)
            and not try(NPC.IsStructure, u) then
            list[#list + 1] = u
        end
    end
    S.units = list
end

local function countInLine(hpos, pred, targetIdx, width)
    local dx, dy = pred.x - hpos.x, pred.y - hpos.y
    local L = hyp(dx, dy)
    if L < 1 then return 0 end
    local ux, uy = dx / L, dy / L
    local n = 0
    for _, u in ipairs(S.units) do
        if Entity.GetIndex(u) ~= targetIdx then
            local up = Entity.GetAbsOrigin(u)
            local rx, ry = up.x - hpos.x, up.y - hpos.y
            local proj = rx * ux + ry * uy
            if proj > 0 and proj < L and math.abs(rx * uy - ry * ux) <= width + 20 then n = n + 1 end
        end
    end
    return n
end

------------------------------------------------------------------------
--  ОЦЕНКА ЦЕЛИ (упреждение + ранний выпуск + стил)
------------------------------------------------------------------------
local function evaluate(hpos, e, info, t)
    local r = { ent = e, idx = Entity.GetIndex(e), ok = false, kill = false, reason = "" }
    local pos = Entity.GetAbsOrigin(e)
    r.pos = pos
    r.hp = Entity.GetHealth(e) or 0
    r.dist0 = d2(hpos, pos)
    if r.dist0 > info.range + 700 then r.skip = true; return r end

    local margin = 1 + (ui.margin:Get() or 0) / 100
    local full = info.dmg * dmgMult(e, info.ab)
    r.potential = full
    local regen = math.max(0, try(NPC.GetHealthRegen, e) or 0)
    local loss = 0
    if ui.steal:Get() then loss = hpLoss(r.idx) * 0.6 end
    r.loss = loss
    r.candidate = full >= (r.hp - loss * 1.2) * margin * 0.999

    if hasState(e, "MODIFIER_STATE_INVULNERABLE") or hasState(e, "MODIFIER_STATE_OUT_OF_GAME") then
        r.reason = "неуязвим"; return r
    end
    if ui.skipDef:Get() and (hasState(e, "MODIFIER_STATE_MAGIC_IMMUNE") or isProtected(e)) then
        r.reason = "защита/BKB"; return r
    end

    -- движение цели
    local dinfo = disableInfo(e)
    local mv = motion(r.idx, t)
    local fixed, vx, vy = false, 0, 0
    if dinfo.disabled and dinfo.left then
        fixed = true
    elseif mv == nil then
        r.reason = "мало данных"; return r
    elseif mv.sp < 35 then
        fixed = true
    else
        local pmode = ui.predictMode:Get() or 2
        if pmode == 0 then r.reason = "бежит"; return r end
        if not mv.stable and pmode < 2 then r.reason = "бежит не по прямой"; return r end
        vx, vy = mv.vx, mv.vy
        local sp = hyp(vx, vy)
        if not mv.stable then                         -- бегство от нас: подмешиваем направление "прочь"
            local ax, ay = pos.x - hpos.x, pos.y - hpos.y
            local al = math.max(hyp(ax, ay), 1)
            ax, ay = ax / al, ay / al
            if (vx * ax + vy * ay) / sp > 0.2 then
                local nx, ny = vx / sp * 0.65 + ax * 0.35, vy / sp * 0.65 + ay * 0.35
                local nl = math.max(hyp(nx, ny), 0.01)
                vx, vy = nx / nl * sp, ny / nl * sp
            end
        end
        local ms = try(NPC.GetMoveSpeed, e)
        if type(ms) == "number" and ms > 0 and sp > ms * 1.25 then
            local k = ms * 1.25 / sp
            vx, vy = vx * k, vy * k
        end
        r.moving, r.stable = true, mv.stable
    end

    -- подбор времени заряда (ранний выпуск) и точки прицеливания
    local chargeFull = info.channel
    local early = ui.early:Get()
    local charge = early and MIN_CHARGE or chargeFull
    local T, pred, dist, red = 0, pos, r.dist0, 1
    local hpAt, need = r.hp, r.hp * margin
    for _ = 1, 4 do
        T = CAST_DELAY + charge + dist / info.speed
        pred = fixed and pos or Vector(pos.x + vx * T, pos.y + vy * T, pos.z)
        dist = hyp(pred.x - hpos.x, pred.y - hpos.y)
        T = CAST_DELAY + charge + dist / info.speed
        if ui.pierce:Get() then red = (1 - info.reduction) ^ countInLine(hpos, pred, r.idx, info.width) end
        hpAt = r.hp + regen * T - loss * T
        need = hpAt * margin
        if early then
            local f = need / math.max(full * red, 1)
            charge = math.max(MIN_CHARGE, math.min(chargeFull, f * chargeFull * 1.1))
        else
            charge = chargeFull
        end
    end
    T = CAST_DELAY + charge + dist / info.speed
    pred = fixed and pos or Vector(pos.x + vx * T, pos.y + vy * T, pos.z)
    dist = hyp(pred.x - hpos.x, pred.y - hpos.y)
    T = CAST_DELAY + charge + dist / info.speed
    hpAt = r.hp + regen * T - loss * T
    need = hpAt * margin

    if loss > 0 and (r.hp - loss * T) <= 0 then r.reason = "союзники убьют раньше"; return r end
    if r.moving and hyp(vx, vy) * T > 2200 then r.reason = "слишком далеко убежит"; return r end
    if dist > info.range then r.reason = "вне дальности"; return r end
    if dist < 60 then r.reason = "слишком близко"; return r end
    if dinfo.disabled and dinfo.left and T > dinfo.left + 0.05 then r.reason = "контроль кончится"; return r end

    local scale = early and math.min(1, charge / chargeFull) or 1
    r.dmg = full * red * scale
    r.hpImpact, r.T, r.pred, r.dist, r.charge = hpAt, T, pred, dist, charge
    r.early = charge < chargeFull - 0.05
    r.ok = true
    r.kill = hpAt > 0 and r.dmg >= need
    r.steal = r.kill and loss > 0 and (r.hp * margin > r.dmg * 0.999)
    if not r.kill then r.reason = "не хватает урона" end
    return r
end

------------------------------------------------------------------------
--  КАСТ / ВЫПУСК / ЗАЩИТА ЗАРЯДА
------------------------------------------------------------------------
local function ownOrder(fn, ...)
    S.own = true
    local ok, res = pcall(fn, ...)
    S.own = false
    return ok, res
end

local function castAt(hero, ab, pos)
    local ok = ownOrder(Player.PrepareUnitOrders, S.player,
        Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION, nil, pos, ab,
        Enum.PlayerOrderIssuer.DOTA_ORDERISSUER_HERO_ONLY, hero, false, false)
    if not ok then ok = ownOrder(Ability.CastPosition, ab, pos) end
    return ok
end

local function entByIdx(idx)
    for _, e in ipairs(Heroes.GetAll()) do
        if Entity.GetIndex(e) == idx then return e end
    end
    return nil
end

-- живая проверка "можно ли отпускать стрелу ПРЯМО СЕЙЧАС": пересчитывает всё
-- заново по текущим данным цели, а не по расчёту, сделанному в момент каста
local function tryEarlyRelease(hero, c, t)
    local target = entByIdx(c.idx)
    if not target or not Entity.IsAlive(target) or Entity.IsDormant(target) then return true end

    local elapsed = t - c.chanStart
    local info = abilityInfo(c.ab, t)
    local hpos = Entity.GetAbsOrigin(hero)
    local pos = Entity.GetAbsOrigin(target)
    local mv = motion(c.idx, t)
    local dinfo = disableInfo(target)
    local fixed = (dinfo.disabled and dinfo.left) or not mv or mv.sp < 35
    local vx, vy = 0, 0
    if not fixed and mv then vx, vy = mv.vx, mv.vy end

    local dist, pred = d2(hpos, pos), pos
    for _ = 1, 3 do
        local A = dist / info.speed
        pred = fixed and pos or Vector(pos.x + vx * A, pos.y + vy * A, pos.z)
        dist = hyp(pred.x - hpos.x, pred.y - hpos.y)
    end
    if dist > info.range + 150 then return false end   -- уже не долетит - ждём, вдруг подойдёт ближе

    local A = dist / info.speed
    local red = 1
    if ui.pierce:Get() then red = (1 - info.reduction) ^ countInLine(hpos, pred, c.idx, info.width) end
    local full = info.dmg * dmgMult(target, c.ab)
    local scale = math.min(1, elapsed / c.chargeFull)
    local dmgNow = full * red * scale

    local regen = math.max(0, try(NPC.GetHealthRegen, target) or 0)
    local hp = Entity.GetHealth(target) or 0
    local loss = ui.steal:Get() and hpLoss(c.idx) * 0.6 or 0
    local hpImpact = hp + regen * A - loss * A
    local margin = 1 + (ui.margin:Get() or 0) / 100

    return dmgNow >= hpImpact * margin
end

local function releaseManager(hero, t)
    local c = S.cast
    if not c or c.released then return end
    if try(NPC.IsChannellingAbility, hero) then
        if not c.chanStart then c.chanStart = t end
        local elapsed = t - c.chanStart
        local release = elapsed >= c.chargeFull
        if not release and ui.early:Get() and elapsed >= MIN_CHARGE then
            release = try(tryEarlyRelease, hero, c, t) and true or false
        end
        if release then
            ownOrder(Player.PrepareUnitOrders, S.player, Enum.UnitOrder.DOTA_UNIT_ORDER_STOP, nil,
                Entity.GetAbsOrigin(hero), nil, Enum.PlayerOrderIssuer.DOTA_ORDERISSUER_HERO_ONLY,
                hero, false, false)
            c.released, c.releaseElapsed = true, elapsed
        end
    else
        if c.chanStart then c.released = true
        elseif t - c.t0 > 0.8 then S.cast = nil end
    end
end

function script.OnPrepareUnitOrders(data)
    local ok, block = pcall(function()
        if S.own or not S.active or not ui.guard:Get() then return false end
        local c = S.cast
        if not c or c.released then return false end
        local t = now()
        if c.chanStart then
            if t > c.chanStart + c.chargeFull + 0.3 then return false end
        elseif t - c.t0 > 0.6 then
            return false
        end
        local UO = Enum.UnitOrder
        local o = data.order
        if o == UO.DOTA_UNIT_ORDER_MOVE_TO_POSITION or o == UO.DOTA_UNIT_ORDER_MOVE_TO_TARGET
            or o == UO.DOTA_UNIT_ORDER_ATTACK_TARGET or o == UO.DOTA_UNIT_ORDER_ATTACK_MOVE then
            return data.npc == nil or data.npc == S.hero
        end
        return false
    end)
    if ok and block then return false end
    return true
end

local function setStatus(text, kind) S.status = { text = text, kind = kind or "info" } end

local function keyHeld()
    local k = ui.key:Get()
    if not k or k == Enum.ButtonCode.KEY_NONE then return true end
    return try(Input.IsKeyDown, k) and true or false
end

local function shortName(n)
    n = tostring(n or "?")
    n = (n:gsub("^npc_dota_hero_", ""))
    n = (n:gsub("_", " "))
    n = (n:gsub("(%a)([%w]*)", function(a, b) return a:upper() .. b end))
    return n
end

------------------------------------------------------------------------
--  ГЛАВНЫЙ ЦИКЛ
------------------------------------------------------------------------
local function update()
    S.active = false
    S.best = nil
    local hero = Heroes.GetLocal()
    if not hero or NPC.GetUnitName(hero) ~= HERO_NAME then return end
    S.hero, S.player = hero, Players.GetLocal()
    S.active = true

    local t = now()
    trackEnemies(hero, t)
    releaseManager(hero, t)

    if not ui.enable:Get() then setStatus("Выключено в меню", "off"); S.evals = {}; return end
    if t - S.lastEval < EVAL_STEP then return end
    S.lastEval = t

    if not Entity.IsAlive(hero) then setStatus("Герой мёртв", "off"); S.evals = {}; return end

    local ab = NPC.GetAbility(hero, ABILITY_NAME)
    if not ab or (try(Ability.GetLevel, ab) or 0) < 1 then
        setStatus("Powershot не изучен", "warn"); S.evals = {}; return
    end

    if try(NPC.IsChannellingAbility, hero) then
        setStatus("Заряд Powershot...", "kill")
        return
    end

    local info = abilityInfo(ab, t)
    if not info.dmg then
        setStatus("Не удалось узнать урон - введи вручную", "warn"); S.evals = {}; return
    end

    local ready = try(Ability.IsReady, ab)
    local castable = try(Ability.IsCastable, ab, NPC.GetMana(hero))
    S.ready = ready and castable and true or false
    S.cd = try(Ability.GetCooldown, ab) or 0

    if ui.pierce:Get() then collectUnits(hero) else S.units = {} end
    local hpos = Entity.GetAbsOrigin(hero)
    local evals, best = {}, nil
    for _, e in ipairs(Heroes.GetAll()) do
        if e ~= hero and not Entity.IsSameTeam(hero, e) and Entity.IsAlive(e)
            and not Entity.IsDormant(e) and not NPC.IsIllusion(e) then
            local r = evaluate(hpos, e, info, t)
            if not r.skip then
                evals[#evals + 1] = r
                if r.ok and r.kill and (not best or r.T < best.T) then best = r end
            end
        end
    end
    S.evals = evals

    if try(NPC.IsStunned, hero) or try(NPC.IsSilenced, hero) or hasState(hero, "MODIFIER_STATE_HEXED") then
        setStatus("Нельзя кастовать (контроль/silence)", "warn"); return
    end
    if not ready then setStatus(string.format("Перезарядка %.1f с", S.cd), "info"); return end
    if not castable then setStatus("Не хватает маны", "warn"); return end

    if not best then
        setStatus(#evals > 0 and "Ищу цель для добивания" or "Ищу цель", "info")
        return
    end
    S.best = best

    if not keyHeld() then
        setStatus("Цель есть: " .. shortName(NPC.GetUnitName(best.ent)) .. " (жми клавишу)", "kill")
        return
    end

    local safeR = ui.safe:Get() or 0
    if safeR > 0 then
        for _, r in ipairs(evals) do
            if r.idx ~= best.idx and r.dist0 <= safeR then
                setStatus("Рядом враг - не кастую", "warn"); return
            end
        end
    end

    if t - S.lastCast < CAST_LOCK then return end

    if castAt(hero, ab, best.pred) then
        S.lastCast = t
        S.cast = { idx = best.idx, ab = ab, t0 = t, tEnd = t + best.T, chargeFull = info.channel,
                   charge = best.charge, early = best.early, name = NPC.GetUnitName(best.ent) }
        setStatus(best.steal and "Стил убийства!" or "Каст Powershot!", "kill")
        if ui.debug:Get() then
            print(string.format("[WR Powershot] CAST -> %s | hp=%.0f dmg~=%.0f T~=%.2f dist=%.0f loss=%.0f steal=%s (отпуск адаптивный)",
                tostring(S.cast.name), best.hp, best.dmg, best.T, best.dist,
                best.loss or 0, tostring(best.steal)))
        end
    else
        logOnce("cast", "не удалось отправить приказ")
    end

    if ui.debug:Get() and t - S.lastDebug > 3 then
        S.lastDebug = t
        print(string.format("[WR Powershot] dmg=%.0f range=%.0f speed=%.0f width=%.0f red=%.2f channel=%.2f targets=%d",
            info.dmg, info.range, info.speed, info.width, info.reduction, info.channel, #evals))
    end
end

function script.OnUpdate()
    local ok, err = pcall(update)
    if not ok then logOnce("update", err) end
end

------------------------------------------------------------------------
--  ТЕМЫ
------------------------------------------------------------------------
local THEMES = {
    blue = {
        badge = "ARCANA", sub = "Compass of the Rising Gale  |  Powershot", art = "arcana",
        bg = { 3, 10, 24 }, card = { 2, 9, 20 }, acc = { 70, 170, 255 }, hi = { 155, 232, 255 },
        soft = { 130, 210, 255 }, dim = { 140, 175, 210 }, subc = { 170, 205, 235 },
        line = { 205, 225, 245 }, streak = { 150, 215, 255 }, leaf = { 170, 225, 255 },
        tint = { 60, 140, 230 }, bar = { 8, 20, 40 }, shadow = { 0, 6, 16 },
        info = { 130, 210, 255 }, kill = { 165, 240, 255 }, warn = { 255, 205, 95 }, off = { 130, 150, 178 },
    },
    green = {
        badge = nil, sub = "Powershot  |  добивание героев", art = "hero",
        bg = { 3, 17, 13 }, card = { 2, 14, 11 }, acc = { 60, 230, 140 }, hi = { 170, 255, 110 },
        soft = { 140, 255, 200 }, dim = { 140, 200, 172 }, subc = { 170, 230, 200 },
        line = { 205, 240, 222 }, streak = { 150, 255, 190 }, leaf = { 170, 255, 130 },
        tint = { 40, 200, 120 }, bar = { 8, 30, 20 }, shadow = { 0, 10, 6 },
        info = { 140, 255, 200 }, kill = { 170, 255, 110 }, warn = { 255, 205, 95 }, off = { 130, 165, 150 },
    },
}
local TH = THEMES.blue
local function applyTheme()
    local v = ui.theme:Get()
    TH = (v == 1) and THEMES.green or THEMES.blue
end

------------------------------------------------------------------------
--  ОТРИСОВКА
------------------------------------------------------------------------
local function loadImg(path)
    if not path or path == "" then return nil end
    local h = try(Render.LoadImage, path)
    if not h then return nil end
    local art = { h = h, aspect = 0.9 }
    local sz = try(Render.ImageSize, h)
    if sz and type(sz) ~= "number" and sz.y and sz.y > 0 then art.aspect = sz.x / sz.y end
    return art
end

local function loadAssets()
    if S.loaded then return end
    S.loaded = true
    local flag = (Enum.FontCreate and Enum.FontCreate.FONTFLAG_ANTIALIAS) or 0
    S.font  = try(Render.LoadFont, "Verdana", flag, 500) or try(Render.LoadFont, "Arial", flag, 500) or 0
    S.fontB = try(Render.LoadFont, "Verdana", flag, 800) or S.font
    S.icon  = try(Render.LoadImage, ICON)

    S.artBlue = loadImg(CUSTOM_ART.blue)
    S.artGreen = loadImg(CUSTOM_ART.green)
    if not S.artGreen then
        for _, p in ipairs(GREEN_ART) do
            S.artGreen = loadImg(p)
            if S.artGreen then break end
        end
    end
end

local function rect(x, y, w, h, c, r) Render.FilledRect(Vec2(x, y), Vec2(x + w, y + h), c, r or 0) end
local function line(x1, y1, x2, y2, c, th) Render.Line(Vec2(x1, y1), Vec2(x2, y2), c, th or 1) end

local function tw(str, size, bold)
    local sz = try(Render.TextSize, bold and S.fontB or S.font, size, str)
    if sz and type(sz) ~= "number" and sz.x then return sz.x end
    return ulen(str) * size * 0.58
end

local function text(str, x, y, size, c, center, bold, shadow)
    local f = bold and S.fontB or S.font
    if center then x = x - tw(str, size, bold) / 2 end
    if shadow then Render.Text(f, size, str, Vec2(x + 1, y + 1), CG(TH.shadow, 210)) end
    Render.Text(f, size, str, Vec2(x, y), c)
end

local function image(h, x, y, w, hh, c)
    if h then pcall(Render.Image, h, Vec2(x, y), Vec2(w, hh), c) end
end

local function screen()
    local sz = try(Render.ScreenSize)
    if sz and type(sz) ~= "number" and sz.x then return sz.x, sz.y end
    return 1920, 1080
end

-- перетаскивание панели мышью за шапку
local function cursor()
    local a, b = try(Input.GetCursorPos)
    if type(a) == "number" then return a, b end
    if a then return a.x, a.y end
    return 0, 0
end

local function inRect(mx, my, x, y, w, h) return mx >= x and mx <= x + w and my >= y and my <= y + h end

local function dragPanel(x, y, w)
    local mx, my = cursor()
    local down = try(Input.IsKeyDown, Enum.ButtonCode.KEY_MOUSE1)
    local once = try(Input.IsKeyDownOnce, Enum.ButtonCode.KEY_MOUSE1)
    if once and inRect(mx, my, x, y, w, 52) then
        S.drag, S.dragOx, S.dragOy = true, mx - x, my - y
    end
    if S.drag then
        if down then
            S.panelX, S.panelY = mx - S.dragOx, my - S.dragOy
        else
            S.drag = false
        end
    end
end

local function windStreaks(x, y, w, h, t, alpha)
    for i = 1, 6 do
        local yy = y + 10 + i * (h - 20) / 7
        local off = (t * (38 + i * 9) + i * 53) % (w + 140) - 70
        local len = 70 + (i % 3) * 30
        local px, py
        for k = 0, 8 do
            local sx = off + k * (len / 8)
            local sy = yy + math.sin(sx * 0.055 + t * 2 + i) * 4
            if sx > 0 and sx < w then
                if px then line(x + px, py, x + sx, sy, CG(TH.streak, alpha * (1 - math.abs(k - 4) / 5)), 1) end
                px, py = sx, sy
            else
                px = nil
            end
        end
    end
end

local function leaves(x, y, w, h, t)
    for i = 1, 9 do
        local lx = x + ((t * (10 + i * 3) + i * 41) % (w + 20)) - 10
        local ly = y + h - ((t * (7 + i * 2) + i * 29) % (h - 6))
        try(Render.FilledCircle, Vec2(lx, ly + math.sin(t * 2 + i) * 4), 1.4 + (i % 3) * 0.8, CG(TH.leaf, 70))
    end
end

-- Аркана: вращающийся компас с вихрем
local function arcanaEmblem(x, y, w, h, t)
    local cx, cy = x + w - 84, y + h / 2
    local pulse = 0.6 + 0.4 * math.sin(t * 2)
    for i = 4, 1, -1 do
        try(Render.FilledCircle, Vec2(cx, cy), 18 + i * 13, CG(TH.acc, 8 + 5 * pulse))
    end
    for i = 1, 3 do try(Render.Circle, Vec2(cx, cy), 22 + i * 14, CG(TH.soft, 70 - i * 12), 1) end
    local R = 22 + 3 * 14
    for k = 0, 35 do
        local a = k * math.pi / 18
        local r2 = R + (k % 3 == 0 and 9 or 5)
        line(cx + math.cos(a) * (R + 2), cy + math.sin(a) * (R + 2),
             cx + math.cos(a) * r2, cy + math.sin(a) * r2, CG(TH.hi, k % 3 == 0 and 150 or 70), 1)
    end
    local rot = t * 0.25
    local function spike(a, len, wid, col)
        local ca, sa = math.cos(a), math.sin(a)
        local tx, ty = cx + ca * len, cy + sa * len
        line(cx - sa * wid, cy + ca * wid, tx, ty, col, 2)
        line(cx + sa * wid, cy - ca * wid, tx, ty, col, 2)
    end
    for k = 0, 3 do spike(rot + k * math.pi / 2, 58, 7, CG(TH.hi, 210)) end
    for k = 0, 3 do spike(rot + math.pi / 4 + k * math.pi / 2, 36, 5, CG(TH.soft, 160)) end
    for arm = 0, 2 do
        local px, py
        for k = 0, 16 do
            local f = k / 16
            local a = t * 0.8 + arm * 2.094 + f * 3.4
            local rr = 10 + f * 48
            local sx, sy = cx + math.cos(a) * rr, cy + math.sin(a) * rr
            if px then line(px, py, sx, sy, CG(TH.hi, 40 + 120 * f), 1) end
            px, py = sx, sy
        end
    end
    try(Render.FilledCircle, Vec2(cx, cy), 5, CG(TH.line, 200 + 55 * pulse))
end

-- запасной арт зелёной темы: стрела
local function arrowFallback(x, y, w, h, t)
    local pulse = 0.6 + 0.4 * math.sin(t * 2)
    local x1, y1, x2, y2 = x + w - 170, y + h - 18, x + w - 22, y + 24
    local c = CG(TH.hi, 90 + 50 * pulse)
    line(x1, y1, x2, y2, c, 3)
    local L = hyp(x2 - x1, y2 - y1)
    local ux, uy = (x2 - x1) / L, (y2 - y1) / L
    local nx, ny = -uy, ux
    line(x2, y2, x2 - ux * 22 + nx * 11, y2 - uy * 22 + ny * 11, c, 3)
    line(x2, y2, x2 - ux * 22 - nx * 11, y2 - uy * 22 - ny * 11, c, 3)
    for k = 0, 3 do
        local bx, by = x1 + ux * (10 + k * 9), y1 + uy * (10 + k * 9)
        line(bx, by, bx - ux * 10 + nx * 9, by - uy * 10 + ny * 9, c, 2)
        line(bx, by, bx - ux * 10 - nx * 9, by - uy * 10 - ny * 9, c, 2)
    end
    for i = 1, 3 do
        try(Render.Circle, Vec2(x + w - 90, y + h / 2), 30 + i * 18 + math.sin(t * 1.4 + i) * 3, CG(TH.acc, 34), 1)
    end
end

local function frame(x, y, w, h, on)
    local fc = CG(TH.acc, on and 215 or 120)
    line(x, y, x + w, y, fc); line(x, y + h, x + w, y + h, fc)
    line(x, y, x, y + h, fc); line(x + w, y, x + w, y + h, fc)
    local cc = CG(TH.hi, 255)
    line(x, y, x + 16, y, cc, 2);         line(x, y, x, y + 16, cc, 2)
    line(x + w, y, x + w - 16, y, cc, 2); line(x + w, y, x + w, y + 16, cc, 2)
    line(x, y + h, x + 16, y + h, cc, 2); line(x, y + h, x, y + h - 16, cc, 2)
    line(x + w, y + h, x + w - 16, y + h, cc, 2); line(x + w, y + h, x + w, y + h - 16, cc, 2)
end

local function drawHud()
    local sw = screen()
    local w, h = 390, 158
    if not S.panelX then S.panelX, S.panelY = sw / 2 - w / 2, 92 end
    dragPanel(S.panelX, S.panelY, w)
    local x, y = S.panelX, S.panelY
    local t = clock()
    local kc = TH[S.status.kind] or TH.info
    local on = S.status.kind ~= "off"

    for i = 4, 1, -1 do rect(x - i * 2, y - i * 2, w + i * 4, h + i * 4, CG(TH.acc, on and 12 or 6)) end
    rect(x, y, w, h, CG(TH.bg, 246))

    -- арт темы (справа, на всю высоту)
    local art = (TH.art == "arcana") and S.artBlue or S.artGreen
    if not art then
        if TH.art == "arcana" then arcanaEmblem(x, y, w, h, t) else arrowFallback(x, y, w, h, t) end
    end
    local aw = art and math.min(h * art.aspect, w * 0.52) or 0
    local ax = x + w - aw
    if art then image(art.h, ax, y, aw, h, C(255, 255, 255, 242)) end

    local n, sf = 32, art and (ax - x) / w or 0.55
    for i = 0, n - 1 do
        local f0 = i / n
        local a
        if f0 <= sf then
            a = 244
        else
            local k = (f0 - sf) / (1 - sf)
            a = 244 - 176 * (k * k * (3 - 2 * k))
        end
        rect(x + w * f0, y, w / n + 1, h, C(TH.bg[1], TH.bg[2], TH.bg[3], a))
    end
    if art then rect(ax, y, aw, h, CG(TH.tint, 30)) end

    windStreaks(x, y, w, h, t, on and 46 or 22)
    leaves(x, y, w, h, t)
    for i = 0, 11 do rect(x, y + i * 4, w, 4, CG(TH.acc, 62 * (1 - i / 12))) end
    frame(x, y, w, h, on)

    -- шапка
    image(S.icon, x + 14, y + 11, 36, 36, C(255, 255, 255, 255))
    text("WIND RANGER", x + 60, y + 8, 20, CG(TH.hi), false, true, true)
    if TH.badge then
        local bx = x + 60 + tw("WIND RANGER", 20, true) + 10
        rect(bx, y + 12, 58, 17, CG(TH.acc, 60), 8)
        text(TH.badge, bx + 29, y + 15, 10, CG(TH.hi), true, true)
    end
    text(TH.sub, x + 60, y + 33, 11, CG(TH.subc, 240), false, false, true)

    line(x + 12, y + 52, x + w - 12, y + 52, CG(TH.acc, 90), 1)
    local sx = x + ((t * 110) % (w + 90)) - 90
    local x1, x2 = math.max(x + 12, sx), math.min(x + w - 12, sx + 90)
    if x2 > x1 then rect(x1, y + 51, x2 - x1, 2, CG(TH.hi, 210)) end

    -- чип статуса
    local label = S.status.text
    local cw = math.min(tw(label, 12, true) + 34, w - 28)
    rect(x + 14, y + 59, cw, 25, CG(kc, 38), 12)
    local pulse = 0.55 + 0.45 * math.sin(t * 4)
    try(Render.FilledCircle, Vec2(x + 27, y + 71.5), 4, CG(kc, 90 + 150 * pulse))
    text(label, x + 38, y + 65, 12, CG(kc), false, true, true)

    -- карточки
    local info = S.info
    local function stat(sx2, cap, value, col)
        rect(sx2, y + 92, 82, 42, CG(TH.card, 195), 8)
        rect(sx2 + 8, y + 92, 66, 1, CG(TH.acc, 160))
        text(cap, sx2 + 10, y + 98, 10, CG(TH.dim), false, true)
        text(value, sx2 + 10, y + 113, 16, col, false, true, true)
    end
    local cd = S.cd or 0
    stat(x + 14,  "УРОН",  info and info.dmg and tostring(math.floor(info.dmg + 0.5)) or "-", CG(TH.hi))
    stat(x + 102, "ДАЛЬН.", info and tostring(math.floor(info.range + 60)) or "-", CG(TH.soft))
    stat(x + 190, "ЦЕЛИ",  tostring(#S.evals), CG(TH.soft))
    stat(x + 278, "КД",    S.ready and "ГОТОВ" or (cd > 0 and string.format("%.1f", cd) or "-"),
         S.ready and CG(TH.hi) or CG(TH.warn))

    -- строка цели
    local tline
    local b = S.best
    if b then
        tline = string.format("Цель: %s  урон %d / хп %d  %.1f с%s%s",
            shortName(NPC.GetUnitName(b.ent)), math.floor(b.dmg + 0.5), math.floor(b.hpImpact + 0.5), b.T,
            b.early and string.format("  заряд %.1f", b.charge) or "", b.steal and "  СТИЛ" or "")
    elseif S.cast and now() < S.cast.tEnd then
        tline = "Стрела летит в: " .. shortName(S.cast.name)
    else
        tline = "Авто-добивание: цель появится, когда урона хватит"
    end
    text(tline, x + 14, y + 140, 11, CG(TH.line, 240), false, false, true)

    local c = S.cast
    if c and now() < c.tEnd then
        local f = math.max(0, math.min(1, (now() - c.t0) / (c.tEnd - c.t0)))
        rect(x + 8, y + h - 5, w - 16, 3, CG(TH.bar, 235))
        rect(x + 8, y + h - 5, (w - 16) * f, 3, CG(TH.hi, 255))
    end

    -- ОТЛАДКА
    if ui.debug:Get() then
        local dy = y + h + 8
        local lines = {}
        if info then
            lines[#lines + 1] = string.format("Урон: %d   Дальность: %d   Скорость: %d   Ширина: %d",
                info.dmg or 0, info.range or 0, info.speed or 0, info.width or 0)
            lines[#lines + 1] = string.format("Снижение за юнит: %d%%   Полный заряд: %.2f с   Каст: %.2f с",
                math.floor((info.reduction or 0) * 100 + 0.5), info.channel or 0, CAST_DELAY)
        else
            lines[#lines + 1] = "Данные способности ещё не прочитаны"
        end
        local tracked = 0
        for _ in pairs(S.track) do tracked = tracked + 1 end
        lines[#lines + 1] = string.format("Готов: %s   КД: %.1f   Целей: %d   Трекинг: %d   Юнитов: %d",
            S.ready and "да" or "нет", cd, #S.evals, tracked, #S.units)
        local shown = 0
        for _, r in ipairs(S.evals) do
            if shown >= 3 then break end
            local st = (r.ok and r.kill) and ("УБЬЁТ" .. (r.steal and " (стил)" or ""))
                or (r.reason ~= "" and r.reason or "ок")
            lines[#lines + 1] = string.format("%s: хп %d  урон %d  -%d/с  %s%s",
                shortName(NPC.GetUnitName(r.ent)), math.floor(r.hp + 0.5),
                math.floor((r.dmg or r.potential or 0) + 0.5), math.floor((r.loss or 0) + 0.5), st,
                r.charge and string.format("  заряд %.1f", r.charge) or "")
            shown = shown + 1
        end
        local dh = 30 + #lines * 15
        for i = 3, 1, -1 do rect(x - i * 2, dy - i * 2, w + i * 4, dh + i * 4, CG(TH.acc, 8)) end
        rect(x, dy, w, dh, CG(TH.bg, 238))
        for i = 0, 5 do rect(x, dy + i * 4, w, 4, CG(TH.acc, 44 * (1 - i / 6))) end
        frame(x, dy, w, dh, true)
        text("ОТЛАДКА", x + 14, dy + 8, 12, CG(TH.hi), false, true, true)
        line(x + 12, dy + 26, x + w - 12, dy + 26, CG(TH.acc, 90), 1)
        for i, s in ipairs(lines) do
            text(s, x + 14, dy + 30 + (i - 1) * 15, 11, CG(TH.line, 245), false, false, true)
        end
    end
end

local function drawWorld()
    if S.status.kind == "off" then return end
    local showAll = S.ready or (S.cd or 0) <= 2
    local t = clock()
    for _, r in ipairs(S.evals) do
        if not r.skip and r.pos and showAll then
            local label, kc
            if r.ok and r.kill then
                label = string.format("%s  %d / %d", r.steal and "POWERSHOT: СТИЛ" or "POWERSHOT: УБЬЁТ",
                    math.floor(r.dmg + 0.5), math.floor(r.hpImpact + 0.5))
                kc = TH.kill
            elseif r.candidate and r.reason ~= "" then
                label, kc = "PS: " .. r.reason, TH.warn
            end
            if label then
                local sp, vis = Render.WorldToScreen(Vector(r.pos.x, r.pos.y, r.pos.z - 10))
                if sp and vis ~= false then
                    local lw = tw(label, 11, true) + 22
                    rect(sp.x - lw / 2 - 1, sp.y + 3, lw + 2, 22, CG(kc, 40), 9)
                    rect(sp.x - lw / 2, sp.y + 4, lw, 20, CG(TH.bg, 232), 8)
                    rect(sp.x - lw / 2 + 6, sp.y + 23, lw - 12, 1, CG(kc, 255))
                    try(Render.FilledCircle, Vec2(sp.x - lw / 2 + 9, sp.y + 14), 3,
                        CG(kc, 140 + 100 * (0.5 + 0.5 * math.sin(t * 5))))
                    text(label, sp.x + 5, sp.y + 8, 11, CG(kc), true, true)
                end
            end
        end
    end

    local b, hero = S.best, S.hero
    if b and b.pred and hero and Entity.IsAlive(hero) then
        local a, av = Render.WorldToScreen(Entity.GetAbsOrigin(hero))
        local e, ev = Render.WorldToScreen(b.pred)
        if a and e and av ~= false and ev ~= false then
            Render.Line(Vec2(a.x, a.y), Vec2(e.x, e.y), CG(TH.acc, 55), 7)
            Render.Line(Vec2(a.x, a.y), Vec2(e.x, e.y), CG(TH.hi, 220), 2)
            local pr = 14 + 3 * math.sin(t * 6)
            try(Render.Circle, Vec2(e.x, e.y), pr, CG(TH.hi, 230), 2)
            try(Render.Circle, Vec2(e.x, e.y), pr + 8, CG(TH.hi, 90), 1)
        end
    end
end

function script.OnDraw()
    local ok, err = pcall(function()
        if not S.active or not ui.draw:Get() then return end
        applyTheme()
        loadAssets()
        drawWorld()
        drawHud()
    end)
    if not ok then logOnce("draw", err) end
end

function script.OnGameEnd()
    S.track, S.evals, S.best, S.cast, S.info = {}, {}, nil, nil, nil
end

print("[WR Powershot] loaded")
return script
