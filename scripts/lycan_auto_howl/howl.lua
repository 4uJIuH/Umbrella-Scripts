---@diagnostic disable: undefined-global, param-type-mismatch, inject-field
local M = {}
local HOWL_NAME = "lycan_howl"
local HOWL_MODS = { "modifier_lycan_howl", "modifier_lycan_howl_debuff" }

local function first_ok(cands, ...)
    for i = 1, #cands do
        local ok, v = pcall(cands[i], ...)
        if ok and v ~= nil then return v end
    end
    return nil
end
local function now()
    local ok, t = pcall(function() return GameRules.GetGameTime() end)
    if ok and type(t) == "number" then return t end
    return os.clock()
end
local function clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi end return v end
local function ease(t) t = clamp(t, 0, 1) return 1 - (1 - t) * (1 - t) * (1 - t) end

local function local_hero()
    return first_ok({
        function() return Heroes.GetLocal() end,
        function() return Players.GetLocal() and Player.GetAssignedHero(Players.GetLocal()) end,
        function() return Entity.GetLocalPlayer and Player.GetAssignedHero(Entity.GetLocalPlayer()) end,
    })
end
local function all_heroes()
    local v = first_ok({ function() return Heroes.GetAll() end, function() return NPC.GetHeroes() end })
    return type(v) == "table" and v or {}
end
local function all_npcs()
    local v = first_ok({
        function() return NPCs.GetAll() end,
        function() return NPC.GetAll() end,
        function() return Units.GetAll() end,
        function() return Entity.GetAllByClass and Entity.GetAllByClass("CDOTA_BaseNPC") end,
        function() return Entity.GetAll() end,
    })
    return type(v) == "table" and v or {}
end
local function team_of(e) return first_ok({ function() return Entity.GetTeamNum(e) end, function() return NPC.GetTeamNum(e) end }, e) end
local function npc_name(e) return first_ok({ function() return NPC.GetUnitName(e) end, function() return Entity.GetUnitName(e) end, function() return NPC.GetName(e) end }, e) end
local function get_ability(npc, i) return first_ok({ function() return NPC.GetAbilityByIndex(npc, i) end, function() return NPC.GetAbility(npc, i) end }, npc, i) end
local function ability_name(ab) return first_ok({ function() return Ability.GetName(ab) end, function() return Ability.GetAbilityName(ab) end }, ab) end
local function is_illusion(e) local ok, v = pcall(NPC.IsIllusion, e) return ok and v end
local function is_hero(e) local ok, v = pcall(NPC.IsHero, e) if ok then return v end return true end
local function is_enemy(e) local ok, v = pcall(NPC.IsEnemy, e) if ok and type(v) == "boolean" then return v end return nil end
local function is_visible(e)
    local v = first_ok({ function() return NPC.IsVisible(e) end, function() return Entity.IsVisible(e) end })
    if type(v) == "boolean" then return v end
    return true
end
local function is_controllable(e)
    local v = first_ok({
        function() return NPC.IsControllableByPlayer(e, local_hero and nil) end,
        function() return Entity.IsControllableByPlayer(e) end,
    })
    if type(v) == "boolean" then return v end
    return nil
end
local function hp(e) return first_ok({ function() return NPC.GetHealth(e) end, function() return Entity.GetHealth(e) end }, e) or 0 end
local function maxhp(e) return first_ok({ function() return NPC.GetMaxHealth(e) end, function() return Entity.GetMaxHealth(e) end }, e) or 1 end
local function npc_mana(e) return first_ok({ function() return NPC.GetMana(e) end }, e) or 999999 end
local function ab_mana(ab) return first_ok({ function() return Ability.GetManaCost(ab) end }, ab) or 0 end
local function is_alive(e)
    local ok, v = pcall(function() return Entity.IsAlive(e) end)
    if ok and type(v) == "boolean" then return v end
    return hp(e) > 0
end
local function is_invuln(e)
    local v = first_ok({ function() return NPC.IsInvulnerable(e) end, function() return Entity.IsInvulnerable(e) end })
    return type(v) == "boolean" and v or false
end
local function has_mod(e, name) local ok, v = pcall(function() return NPC.HasModifier(e, name) end) return ok and v end
local function has_howl_mod(e) for i = 1, #HOWL_MODS do if has_mod(e, HOWL_MODS[i]) then return true end end return false end
local function owner_id(e) return first_ok({ function() return NPC.GetPlayerOwnerID(e) end, function() return Entity.GetOwnerPlayerID(e) end }, e) end
local function local_id() return first_ok({ function() return Player.GetLocalID() end, function() return Players.GetLocalID() end }) end

local function ab_ready(ab)
    local v = first_ok({ function() return Ability.IsReady(ab) end, function() return Ability.IsCastable(ab, 0) end })
    if type(v) == "boolean" then return v end
    local cd = first_ok({ function() return Ability.GetCooldownTimeRemaining(ab) end, function() return Ability.GetCooldown(ab) end })
    if type(cd) == "number" then return cd <= 0 end
    return true
end
local function ab_level(ab) return first_ok({ function() return Ability.GetLevel(ab) end }, ab) or 0 end
local function cd_remain(ab) local v = first_ok({ function() return Ability.GetCooldownTimeRemaining(ab) end, function() return Ability.GetCooldown(ab) end }) return type(v) == "number" and math.max(v, 0) or 0 end
local function cd_total(ab) local v = first_ok({ function() return Ability.GetCooldownLength(ab) end, function() return Ability.GetCooldownTime(ab) end }) return type(v) == "number" and v or 0 end

local function origin_xy(e)
    local v = first_ok({ function() return Entity.GetAbsOrigin(e) end, function() return NPC.GetAbsOrigin(e) end }, e)
    if not v then return nil end
    local t = type(v)
    if t ~= "table" and t ~= "userdata" then return nil end
    local x, y = v.x, v.y
    if x == nil then local ok, gx = pcall(function() return v:GetX() end) if ok then x = gx end end
    if y == nil then local ok, gy = pcall(function() return v:GetY() end) if ok then y = gy end end
    if x == nil or y == nil then return nil end
    return x, y
end
local function dist2d(ax, ay, bx, by) local dx, dy = ax - bx, ay - by return math.sqrt(dx * dx + dy * dy) end

local function is_night()
    local v = first_ok({ function() return GameRules.IsNight() end, function() return GameRules.IsNightTime() end })
    if type(v) == "boolean" then return v end
    local d = first_ok({ function() return GameRules.IsDaytime() end, function() return GameRules.IsDay() end })
    if type(d) == "boolean" then return not d end
    local f = first_ok({ function() return GameRules.GetTimeOfDay() end })
    if type(f) == "number" then return not (f >= 0.25 and f < 0.75) end
    return false
end

local function get_howl(me)
    for i = 0, 30 do
        local ab = get_ability(me, i)
        if ab and ability_name(ab) == HOWL_NAME then return ab end
    end
    return nil
end
local function cast_no_target(me, ab)
    if type(Ability) == "table" and type(Ability.CastNoTarget) == "function" then pcall(Ability.CastNoTarget, ab) return end
    if type(Ability) == "table" and type(Ability.Cast) == "function" then pcall(Ability.Cast, ab) return end
    if type(NPC) == "table" and type(NPC.CastNoTarget) == "function" then pcall(NPC.CastNoTarget, me, ab) return end
    pcall(function()
        local order = Enum and Enum.UnitOrder and Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET
        Player.PrepareUnitOrders(Players.GetLocal(), order, nil, nil, ab, 1, me)
    end)
end
local function howl_radius(ab, fallback)
    local r = first_ok({
        function() return Ability.GetSpecialValueFor(ab, "radius") end,
        function() return Ability.GetLevelSpecialValueFor(ab, "radius", ab_level(ab) - 1) end,
        function() return Ability.GetSpecialValueFor(ab, "aoe") end,
    })
    if type(r) == "number" and r > 0 then return r end
    return fallback
end

local ui = {}
local function el(fn) local ok, h = pcall(fn) if ok then return h end return nil end
do
    local ok = pcall(function()
        local tab = Menu.Create("General", "Main", "Lycan Auto Howl")
        pcall(function() tab:Icon("") end)
        local g  = tab:Create("Auto Howl"):Create("Основное")
        local gd = tab:Create("Auto Howl"):Create("День / Ночь")
        local gt = tab:Create("Auto Howl"):Create("Детект")
        local gp = tab:Create("Auto Howl"):Create("Панель")

        ui.enabled  = el(function() return g:Switch("Включить Auto Howl", true, "") end)
        ui.manasafe = el(function() return g:Switch("Проверять ману", true) end)
        ui.manares  = el(function() return g:Slider("Резерв маны", 0, 400, 0) end)
        ui.skipmod  = el(function() return g:Switch("Не кастовать повторно на цель", true) end)
        ui.gap      = el(function() return g:Slider("Пауза между кастами, мс", 100, 3000, 500) end)

        ui.night    = el(function() return gd:Switch("Ночью — вся карта (global)", true) end)
        ui.dayrange = el(function() return gd:Switch("Днём — только в радиусе Howl", true) end)
        ui.wolves   = el(function() return gd:Switch("Учитывать радиус волков", true) end)
        ui.wolfrad  = el(function() return gd:Slider("Радиус вокруг волка", 400, 2000, 900) end)
        ui.radius   = el(function() return gd:Slider("Дневной радиус Howl", 800, 2000, 2000) end)
        ui.autorad  = el(function() return gd:Switch("Брать радиус из абилки", true) end)

        ui.byhp     = el(function() return gt:Switch("Триггер по порогу HP", true) end)
        ui.hppct    = el(function() return gt:Slider("Порог HP, %", 1, 100, 22) end)
        ui.bydrop   = el(function() return gt:Switch("Триггер по скорости урона", true) end)
        ui.droppct  = el(function() return gt:Slider("Просадка HP за окно, %", 5, 90, 20) end)
        ui.dropwin  = el(function() return gt:Slider("Окно анализа, мс", 100, 1000, 400) end)

        ui.hud      = el(function() return gp:Switch("Показывать панель", true) end)
        ui.drag     = el(function() return gp:Switch("Перетаскивание", true) end)
        ui.scale    = el(function() return gp:Slider("Масштаб, %", 70, 170, 100) end)
        ui.opacity  = el(function() return gp:Slider("Прозрачность фона, %", 30, 100, 92) end)
        ui.posx     = el(function() return gp:Slider("Позиция X", 0, 3840, 40) end)
        ui.posy     = el(function() return gp:Slider("Позиция Y", 0, 2160, 320) end)
    end)
    if not ok then print("[Lycan Auto Howl] ошибка создания меню") end
end
local function mget(h, d) if not h then return d end local ok, v = pcall(function() return h:Get() end) if ok and v ~= nil then return v end return d end
local function mset(h, v) if h then pcall(function() h:Set(v) end) end end

local hist = {}
local function push_hp(idx, cur)
    local h = hist[idx]
    if not h then h = {} hist[idx] = h end
    local t = now()
    h[#h + 1] = { t = t, hp = cur }
    local keep = mget(ui.dropwin, 400) / 1000 + 0.5
    while h[1] and (t - h[1].t) > keep do table.remove(h, 1) end
end
local function hp_at_window(idx)
    local h = hist[idx]
    if not h or #h == 0 then return nil end
    local t, win = now(), mget(ui.dropwin, 400) / 1000
    for i = 1, #h do if (t - h[i].t) <= win then return h[i].hp end end
    return h[1].hp
end

local function is_wolf_name(nm)
    if type(nm) ~= "string" then return false end
    nm = nm:lower()
    return nm:find("wolf", 1, true) ~= nil or nm:find("lycan", 1, true) ~= nil
end
local function mine(u, mid)
    if is_controllable(u) == true then return true end
    if mid == nil then return true end
    local oid = owner_id(u)
    if oid == nil then return true end
    return oid == mid
end
local function get_wolves(me, myteam)
    local out = {}
    local mid = local_id()
    local list = all_npcs()
    for i = 1, #list do
        local u = list[i]
        if u and u ~= me and is_alive(u) and not is_hero(u)
           and team_of(u) == myteam and is_wolf_name(npc_name(u)) and mine(u, mid) then
            out[#out + 1] = u
        end
    end
    return out
end

local function reach(mx, my, wolves, hx, hy, night, radius)
    if night and mget(ui.night, true) then return "GLOBAL" end
    if not mget(ui.dayrange, true) then return "ALL" end
    if not hx then return nil end
    if dist2d(mx, my, hx, hy) <= radius then return "HERO" end
    if mget(ui.wolves, true) then
        local wr = mget(ui.wolfrad, 900)
        for i = 1, #wolves do
            local wx, wy = origin_xy(wolves[i])
            if wx and dist2d(wx, wy, hx, hy) <= wr then return "WOLF" end
        end
    end
    return nil
end

local function should_trigger(idx, cur, mx)
    if mx <= 0 or cur <= 0 then return false end
    local pct = cur / mx * 100
    if mget(ui.byhp, true) and pct <= mget(ui.hppct, 22) then return true end
    if mget(ui.bydrop, true) then
        local prev = hp_at_window(idx)
        if prev and ((prev - cur) / mx * 100) >= mget(ui.droppct, 20) then return true end
    end
    return false
end

local function enemy_of(me, myteam, h)
    if h == me or not is_hero(h) or not is_alive(h) then return false end
    if is_illusion(h) then return false end
    if not is_visible(h) or is_invuln(h) then return false end
    local flag = is_enemy(h)
    if flag ~= nil then return flag end
    return team_of(h) ~= myteam
end

local stats = { casts = 0, wolves = 0, src = "-" }
local last_cast = -999

function M.OnUpdate()
    if not mget(ui.enabled, true) then return end
    local me = local_hero()
    if not me or not is_alive(me) then return end
    local myteam = team_of(me)
    if not myteam then return end
    local mx, my = origin_xy(me)
    if not mx then return end

    local howl = get_howl(me)
    local night = is_night()
    local radius = (howl and mget(ui.autorad, true)) and howl_radius(howl, mget(ui.radius, 2000)) or mget(ui.radius, 2000)
    local wolves = get_wolves(me, myteam)
    stats.wolves = #wolves

    if not howl or not ab_ready(howl) then return end
    if mget(ui.manasafe, true) and npc_mana(me) < (ab_mana(howl) + mget(ui.manares, 0)) then return end
    if (now() - last_cast) < (mget(ui.gap, 500) / 1000) then return end

    local list = all_heroes()
    for i = 1, #list do
        local h = list[i]
        if enemy_of(me, myteam, h) then
            local idx = first_ok({ function() return Entity.GetIndex(h) end }, h) or i
            local cur, mxhp = hp(h), maxhp(h)
            push_hp(idx, cur)
            if should_trigger(idx, cur, mxhp)
               and not (mget(ui.skipmod, true) and has_howl_mod(h)) then
                local hx, hy = origin_xy(h)
                local src = reach(mx, my, wolves, hx, hy, night, radius)
                if src then
                    cast_no_target(me, howl)
                    last_cast = now()
                    stats.casts = stats.casts + 1
                    stats.src = src
                    return
                end
            end
        end
    end
end

local NEON = Color(0, 240, 255, 255)
local INK  = Color(224, 236, 244, 255)
local DIM  = Color(120, 138, 150, 255)
local REDN = Color(255, 60, 90, 255)
local WARN = Color(240, 170, 70, 255)

local FONTS, FONTS_READY = {}, false
local function load_fonts()
    if FONTS_READY then return end
    FONTS_READY = true
    local flag = Enum and Enum.FontCreate and Enum.FontCreate.FONTFLAG_ANTIALIAS or 0
    local function try(w) local ok, f = pcall(function() return Render.LoadFont("Arial", flag, w) end) return ok and f or nil end
    FONTS.reg = try(400)
    FONTS.med = try(600) or FONTS.reg
    FONTS.bold = try(800) or FONTS.reg
end
local function read_xy(fn, ...)
    local r = { pcall(fn, ...) }
    if not r[1] then return 0, 0 end
    local a, b = r[2], r[3]
    if type(a) == "number" then return a, (type(b) == "number" and b or 0) end
    if type(a) == "table" or type(a) == "userdata" then
        local x, y = a.x, a.y
        if x == nil then local ok, gx = pcall(function() return a:GetX() end) if ok then x = gx end end
        if y == nil then local ok, gy = pcall(function() return a:GetY() end) if ok then y = gy end end
        return x or 0, y or 0
    end
    return 0, 0
end
local function col(c, a) return Color(c.r, c.g, c.b, a or 255) end
local function V(x, y) return Vec2(x, y) end
local R = {}
function R.rect(x, y, w, h, c, rnd) pcall(Render.FilledRect, V(x, y), V(x + w, y + h), c, rnd or 0) end
function R.outline(x, y, w, h, c, rnd, th) pcall(Render.Rect, V(x, y), V(x + w, y + h), c, rnd or 0, nil, th or 1) end
function R.grad(x, y, w, h, tl, tr, bl, br, rnd)
    if pcall(Render.Gradient, V(x, y), V(x + w, y + h), tl, tr, bl, br, rnd or 0) then return end
    pcall(Render.FilledRect, V(x, y), V(x + w, y + h), tl, rnd or 0)
end
function R.shadow(x, y, w, h, c, th, rnd, ox, oy) pcall(Render.Shadow, V(x, y), V(x + w, y + h), c, th or 30, rnd or 0, nil, V(ox or 0, oy or 0)) end
function R.blur(x, y, w, h, s, a, rnd) pcall(Render.Blur, V(x, y), V(x + w, y + h), s or 4, a or 255, rnd or 0) end
function R.line(x1, y1, x2, y2, c, th) pcall(Render.Line, V(x1, y1), V(x2, y2), c, th or 1) end
function R.fcircle(x, y, r, c) pcall(Render.FilledCircle, V(x, y), r, c, 0, 1, 40) end
local function text(f, sz, s, x, y, c) if f then pcall(Render.Text, f, sz, s, V(x, y), c) end end
local function text_w(f, sz, s) local w = read_xy(Render.TextSize, f, sz, s) if w > 0 then return w end return #s * sz * 0.5 end
local function text_r(f, sz, s, x, y, c) text(f, sz, s, x - text_w(f, sz, s), y, c) end

local function corner(x, y, w, h, len, c, th)
    R.line(x, y, x + len, y, c, th) R.line(x, y, x, y + len, c, th)
    R.line(x + w, y, x + w - len, y, c, th) R.line(x + w, y, x + w, y + len, c, th)
    R.line(x, y + h, x + len, y + h, c, th) R.line(x, y + h, x, y + h - len, c, th)
    R.line(x + w, y + h, x + w - len, y + h, c, th) R.line(x + w, y + h, x + w, y + h - len, c, th)
end
local function stat(x, y, s, label, value, vcol)
    text(FONTS.med, 10 * s, label, x, y, DIM)
    text(FONTS.bold, 14 * s, value, x, y + 12 * s, vcol or INK)
end

local mouse = { x = 0, y = 0, down = false, prev = false, clicked = false }
local MBTN = {}
do
    if Enum and Enum.ButtonCode then MBTN[#MBTN + 1] = Enum.ButtonCode.MOUSE_LEFT MBTN[#MBTN + 1] = Enum.ButtonCode.KEY_MOUSE1 end
    MBTN[#MBTN + 1] = 0x01
end
local function read_mouse()
    mouse.x, mouse.y = read_xy(Input.GetCursorPos)
    local d = false
    for i = 1, #MBTN do local ok, v = pcall(Input.IsKeyDown, MBTN[i]) if ok and v then d = true break end end
    mouse.prev = mouse.down
    mouse.down = d
    mouse.clicked = (d and not mouse.prev)
end
local function hovered(x, y, w, h) return mouse.x >= x and mouse.x <= x + w and mouse.y >= y and mouse.y <= y + h end

local drag = { active = false, gx = 0, gy = 0, x = 0, y = 0 }
local anim = { open = 0 }
local DREW = false

function M.OnDraw()
    if not mget(ui.hud, true) then DREW = false return end
    load_fonts()
    read_mouse()
    if not DREW then DREW = true anim.open = 0 end

    local me = local_hero()
    local howl = me and get_howl(me) or nil
    local ready = howl and ab_ready(howl)
    local active = mget(ui.enabled, true)
    local night = is_night()
    local remain = howl and cd_remain(howl) or 0
    local total = howl and cd_total(howl) or 0
    local radius = math.floor(howl and howl_radius(howl, mget(ui.radius, 2000)) or mget(ui.radius, 2000))
    local accent = (not active) and REDN or (ready and NEON or WARN)
    local status = (not active) and "OFFLINE" or (ready and "ONLINE" or "COOLDOWN")

    anim.open = anim.open + (1 - anim.open) * 0.16
    local e = ease(anim.open)
    local s = (mget(ui.scale, 100) / 100) * (0.96 + 0.04 * e)
    local PW, PH = 272 * s, 232 * s
    local HEADER = 30 * s

    local scrw, scrh = read_xy(Render.ScreenSize)
    if scrw == 0 then scrw = 1920 end
    if scrh == 0 then scrh = 1080 end

    local px, py
    if drag.active then px, py = drag.x, drag.y else px, py = mget(ui.posx, 40), mget(ui.posy, 320) end
    px = clamp(px, 0, scrw - PW)
    py = clamp(py, 0, scrh - PH)
    local op = clamp(mget(ui.opacity, 92) / 100, 0.3, 1)
    local a = math.floor(255 * op)
    py = py + (1 - e) * -12
    local pad = 14 * s

    pcall(function()
        R.shadow(px, py + 6, PW, PH, Color(0, 0, 0, 150), 46, 0, 0, 10)
        R.blur(px, py, PW, PH, 6, 255, 0)
        R.grad(px, py, PW, PH, Color(10, 12, 18, a), Color(14, 16, 24, a), Color(8, 9, 13, a), Color(10, 12, 18, a), 0)
        R.grad(px, py, PW, HEADER, col(accent, math.floor(70 * op)), Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0)
        R.rect(px, py + HEADER, PW, 2 * s, accent, 0)
        corner(px, py, PW, PH, 12 * s, accent, 1.6)
        R.outline(px, py, PW, PH, Color(255, 255, 255, 20), 0, 1)

        text(FONTS.bold, 15 * s, "LYCAN", px + pad, py + 8 * s, INK)
        text(FONTS.bold, 15 * s, "// AUTO HOWL", px + pad + text_w(FONTS.bold, 15 * s, "LYCAN "), py + 8 * s, accent)
        R.fcircle(px + PW - pad - 4 * s, py + HEADER * 0.5, 4 * s, accent)

        local y = py + HEADER + 14 * s
        text(FONTS.med, 11 * s, "STATUS", px + pad, y, DIM)
        text_r(FONTS.bold, 16 * s, status, px + PW - pad, y - 3 * s, accent)
        y = y + 22 * s
        text(FONTS.med, 11 * s, "MODE", px + pad, y, DIM)
        text_r(FONTS.bold, 13 * s, night and "NIGHT / GLOBAL" or ("DAY / " .. radius), px + PW - pad, y - 1 * s, accent)
        y = y + 22 * s

        local bx, bw, bh = px + pad, PW - pad * 2, 7 * s
        R.rect(bx, y, bw, bh, Color(255, 255, 255, 26), 0)
        local frac = (remain > 0 and total > 0) and clamp(1 - remain / total, 0, 1) or 1
        R.grad(bx, y, bw * frac, bh, accent, col(accent, 150), accent, col(accent, 150), 0)
        R.outline(bx, y, bw, bh, col(accent, 120), 0, 1)
        y = y + bh + 4 * s
        text(FONTS.reg, 11 * s, remain > 0 and string.format("CD %.1fs", remain) or "READY TO CAST", bx, y, DIM)
        text_r(FONTS.reg, 11 * s, "WOLVES " .. stats.wolves, px + PW - pad, y, stats.wolves > 0 and NEON or DIM)
        y = y + 20 * s

        R.line(px + pad, y, px + PW - pad, y, Color(255, 255, 255, 24), 1)
        text(FONTS.med, 10 * s, "SETTINGS", px + pad, y + 5 * s, col(accent, 180))
        y = y + 22 * s

        local colw = (PW - pad * 2) / 3
        stat(px + pad, y, s, "HP <=", mget(ui.hppct, 22) .. "%", INK)
        stat(px + pad + colw, y, s, "DROP", mget(ui.droppct, 20) .. "%", INK)
        stat(px + pad + colw * 2, y, s, "RADIUS", tostring(radius), NEON)
        y = y + 34 * s
        stat(px + pad, y, s, "WOLF R", tostring(mget(ui.wolfrad, 900)), NEON)
        stat(px + pad + colw, y, s, "DELAY", mget(ui.gap, 500) .. "ms", INK)
        stat(px + pad + colw * 2, y, s, "WINDOW", mget(ui.dropwin, 400) .. "ms", INK)
        y = y + 34 * s
        text(FONTS.reg, 11 * s, "CASTS " .. stats.casts, px + pad, y, DIM)
        text_r(FONTS.reg, 11 * s, "SRC " .. stats.src, px + PW - pad, y, stats.src == "WOLF" and NEON or DIM)
    end)

    if mget(ui.drag, true) then
        if drag.active then
            if mouse.down then
                drag.x = clamp(mouse.x - drag.gx, 0, scrw - PW)
                drag.y = clamp(mouse.y - drag.gy, 0, scrh - PH)
            else
                drag.active = false
                mset(ui.posx, math.floor(drag.x + 0.5))
                mset(ui.posy, math.floor(drag.y + 0.5))
            end
        elseif mouse.clicked and hovered(px, py, PW, HEADER) then
            drag.active = true
            drag.gx = mouse.x - px
            drag.gy = mouse.y - py
            drag.x, drag.y = px, py
        end
    end
end

function M.OnGameEnd()
    hist = {} last_cast = -999 stats.casts = 0 stats.wolves = 0 stats.src = "-"
end

do
    local cbs = {
        { M.OnUpdate,  { "Update", "OnUpdate", "update", "Tick", "OnTick" } },
        { M.OnDraw,    { "Draw", "OnDraw", "draw", "Render", "OnRender", "Present" } },
        { M.OnGameEnd, { "GameEnd", "OnGameEnd", "game_end" } },
    }
    local regs = {
        function(n, fn) return Cheat.RegisterCallback(n, fn) end,
        function(n, fn) return Cheat.AddCallback(n, fn) end,
        function(n, fn) return Callbacks.Register(n, fn) end,
        function(n, fn) return Callbacks.Add(n, fn) end,
        function(n, fn) return Engine.RegisterLoopCallback(n, fn) end,
        function(n, fn) return Events.RegisterCallback(n, fn) end,
        function(n, fn) return RegisterCallback(n, fn) end,
    }
    for _, c in ipairs(cbs) do
        if c[1] then for _, nm in ipairs(c[2]) do for _, r in ipairs(regs) do pcall(r, nm, c[1]) end end end
    end
    pcall(function() if OnUpdate == nil then OnUpdate = M.OnUpdate end end)
    pcall(function() if OnDraw == nil then OnDraw = M.OnDraw end end)
    pcall(function() if OnGameEnd == nil then OnGameEnd = M.OnGameEnd end end)
end

print("[Lycan Auto Howl] loaded")
return M
