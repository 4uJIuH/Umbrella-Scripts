--[[ Creep Aggro — Umbrella API v2.0 ]]--

local M = {}

-- ===== Localization (qLocalization) =====
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
        creep_aggro = {
            name = "Re-Aggro V2",
            icon = "\u{f188}",

            settings = {
                title = "Settings",
                enable = "Enable Script",
                aggro_key = "Aggro Key",
                reaggro_units = "Re-Aggro via Controlled Units",
                auto_disable = "Disable Visuals After X Minutes",
                auto_disable_min = "Disable Visuals at Minute",
            },
            hero_visuals = {
                title = "Hero Visuals",
                show_radius = "Show Aggro Radius",
                radius_color = "Aggro Radius Color",
                radius_particle = "Radius Particle",
                cd_show = "Show Aggro Cooldown",
                cd_height = "Indicator Height (3D)",
                cd_offset_x = "Indicator Offset X",
                cd_offset_y = "Indicator Offset Y",
                cd_size = "Cooldown Indicator Size",
                cd_thickness = "Cooldown Ring Thickness",
                cd_fill = "Indicator Background Fill",
            },
            unit_visuals = {
                title = "Unit Visuals",
                show_radius = "Show Aggro Radius",
                radius_color = "Aggro Radius Color",
                radius_particle = "Radius Particle",
                cd_show = "Show Aggro Cooldown",
                cd_height = "Indicator Height (3D)",
                cd_offset_x = "Indicator Offset X",
                cd_offset_y = "Indicator Offset Y",
                cd_size = "Cooldown Indicator Size",
                cd_thickness = "Cooldown Ring Thickness",
                cd_fill = "Indicator Background Fill",
            },
        }
    },
    ru = {
        creep_aggro = {
            name = "Переагр V2",
            icon = "\u{f188}",

            settings = {
                title = "Настройки",
                enable = "Включить скрипт",
                aggro_key = "Клавиша агра",
                reaggro_units = "Переагр через подконтрольных существ",
                auto_disable = "Отключать визуалы после X минуты",
                auto_disable_min = "Отключать визуалы на минуте",
            },
            hero_visuals = {
                title = "Визуал героя",
                show_radius = "Показывать радиус переагра",
                radius_color = "Цвет радиуса переагра",
                radius_particle = "Партикл радиуса",
                cd_show = "Показывать кулдаун переагра",
                cd_height = "Высота индикатора (3D)",
                cd_offset_x = "Смещение X индикатора",
                cd_offset_y = "Смещение Y индикатора",
                cd_size = "Размер индикатора кулдауна",
                cd_thickness = "Толщина кольца кулдауна",
                cd_fill = "Заливка фона индикатора",
            },
            unit_visuals = {
                title = "Визуал юнитов",
                show_radius = "Показывать радиус переагра",
                radius_color = "Цвет радиуса переагра",
                radius_particle = "Партикл радиуса",
                cd_show = "Показывать кулдаун переагра",
                cd_height = "Высота индикатора (3D)",
                cd_offset_x = "Смещение X индикатора",
                cd_offset_y = "Смещение Y индикатора",
                cd_size = "Размер индикатора кулдауна",
                cd_thickness = "Толщина кольца кулдауна",
                cd_fill = "Заливка фона индикатора",
            },
        }
    }
}

local localization = qLoc and qLoc.new(translations) or nil
local Menu = localization and localization.WrapLibrary and localization.WrapLibrary(Menu) or Menu

local function T(key, ...)
    local res = nil
    if localization and type(localization.Localize) == "function" then
        res = localization.Localize(key)
    end
    if res == nil or res == key then
        local lang = (localization and type(localization.GetLanguage) == "function" and localization.GetLanguage()) or "ru"
        local dict = translations[lang] or translations.en
        local path = key:gsub("^creep_aggro%.", "")
        res = dict.creep_aggro and dict.creep_aggro[path]
        if res == nil then
            res = translations.en.creep_aggro and translations.en.creep_aggro[path] or key
        end
    end
    if ... then
        return string.format(res, ...)
    end
    return res
end

-- ===== Config =====
local CFG = {
    menu = { tab = "Creeps", id = "creep_aggro", icon = "\u{f188}" },
    aggro_cd = 2.0,
    stop_delay = 0.20,
    draw_range = 3000,
    fx_size = 500,
    ring_segs = 36,
    colors = {
        bg = Color(16, 18, 24, 210),
        ring = Color(40, 44, 55, 180),
        ready = Color(46, 213, 115, 255),
        low = Color(255, 60, 50, 255),
        mid = Color(255, 200, 50, 255),
        text = Color(255, 255, 255, 240),
    },
}

-- ===== State =====
local ui, state
local fx = { active = {}, paths = {} }
local text_cache = {}

-- ===== Helpers =====
local function hero_player()
    local h = Heroes.GetLocal()
    return h and Entity.IsAlive(h) and h, h and Entity.GetOwner(h) or nil
end

local function key_down()
    return ui.aggro_key:IsDown()
end

local function find_target(hero)
    for _, e in pairs(Heroes.GetAll()) do
        if e ~= hero and Entity.IsAlive(e) and not Entity.IsSameTeam(hero, e)
           and not NPC.IsIllusion(e) and (NPC.IsVisible(e) or not Entity.IsDormant(e)) then
            return e
        end
    end
end

local function get_units(player, hero, range)
    if not player or not hero then return {} end
    local hero_pos = range and Entity.GetAbsOrigin(hero)
    local range_sq = range and range * range
    local units, seen = {}, {}

    local function add(u)
        if not u or seen[u] then return end
        if not (Entity.IsAlive(u) and not Entity.IsDormant(u)) then return end
        if hero_pos and u ~= hero then
            local p = Entity.GetAbsOrigin(u)
            if not p then return end
            local dx, dy = hero_pos.x - p.x, hero_pos.y - p.y
            if dx*dx + dy*dy > range_sq then return end
        end
        seen[u] = true
        units[#units+1] = u
    end

    add(hero)
    for _, u in pairs(Player.GetSelectedUnits(player) or {}) do add(u) end
    for _, npc in pairs(NPCs.GetAll()) do
        if npc ~= hero and NPC.IsControllableByPlayer(npc, player) then add(npc) end
    end
    return units
end

local function particle_path(combo)
    local name = state.particle_names[combo:Get() + 1]
    if not name or name == "None" then return nil end
    local lib = LIB_HEROES_DATA or {}
    return (lib.particles_path_for_radius or {})[name] or name
end

local function text_size(font, size, str)
    local k = font .. "|" .. size .. "|" .. str
    if not text_cache[k] then text_cache[k] = Render.TextSize(font, size, str) end
    return text_cache[k]
end

-- ===== FX =====
local function ensure_fx(unit, pos, color, path)
    if not path then return end
    local idx = Entity.GetIndex(unit)
    local p = fx.active[idx]
    if p and fx.paths[idx] ~= path then Particle.Destroy(p); p = nil; fx.active[idx] = nil end
    if not p then
        p = Particle.Create(path, Enum.ParticleAttachment.PATTACH_WORLDORIGIN)
        Particle.SetControlPoint(p, 3, Vector(1, 0, 0))
        fx.active[idx] = p
        fx.paths[idx] = path
    end
    Particle.SetControlPoint(p, 0, pos)
    Particle.SetControlPoint(p, 1, Vector(color.r, color.g, color.b))
    Particle.SetControlPoint(p, 2, Vector(CFG.fx_size, color.a, 0))
end

local function destroy_fx()
    for _, p in pairs(fx.active) do Particle.Destroy(p) end
    fx.active, fx.paths = {}, {}
end

-- ===== Orders =====
local function order_stop(player, unit)
    Player.PrepareUnitOrders(player, Enum.UnitOrder.DOTA_UNIT_ORDER_STOP, nil, Vector(), nil,
        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, unit, false, false, false, true, "ca_stop")
end

local function order_attack(player, unit, target)
    Player.PrepareUnitOrders(player, Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET, target, Vector(), nil,
        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, unit, false, false, false, true, "ca_atk")
end

local function do_aggro(player, unit, target, now)
    local idx = Entity.GetIndex(unit)
    order_attack(player, unit, target)
    state.pending[idx] = { unit = unit, at = now + CFG.stop_delay }
    state.cd[idx] = now
end

-- ===== Core =====
local function process_stops(player, now)
    for idx, p in pairs(state.pending) do
        if now >= p.at then
            if p.unit and Entity.IsAlive(p.unit) then order_stop(player, p.unit) end
            state.pending[idx] = nil
        end
    end
end

local function update_key()
    local d = key_down()
    if d then
        if not state.key_down then state.hero_done = false end
        state.key_down = true
    else
        state.key_down = false
        state.hero_done = false
    end
    return d
end

local function update_auto_off(now)
    if not ui.auto_disable:Get() then state.visuals_off = false; return end
    local off = math.floor(now/60) >= ui.auto_disable_min:Get()
    if off and not state.visuals_off then destroy_fx() end
    state.visuals_off = off
end

function M.OnUpdate()
    if not Engine.IsInGame() then return end
    if not ui.enable:Get() then destroy_fx(); state.cd = {}; return end

    local now = GameRules.GetGameTime()
    update_auto_off(now)

    local hero, player = hero_player()
    if not hero then return end

    get_units(player, hero)
    process_stops(player, now)
    if not update_key() then return end

    local target = find_target(hero)
    if not target or NPC.IsChannellingAbility(hero) then return end

    local hidx = Entity.GetIndex(hero)
    local hero_ready = (now - (state.cd[hidx] or 0)) >= CFG.aggro_cd

    if hero_ready then
        do_aggro(player, hero, target, now)
        state.hero_done = true
    end

    if ui.reaggro:Get() and not hero_ready and not state.hero_done then
        for _, u in ipairs(get_units(player, hero)) do
            if u ~= hero and Entity.IsAlive(u) and not NPC.IsChannellingAbility(u) then
                local idx = Entity.GetIndex(u)
                if (now - (state.cd[idx] or 0)) >= CFG.aggro_cd then
                    do_aggro(player, u, target, now)
                end
            end
        end
    end
end

-- ===== Drawing =====
local function arc(cx, cy, r, start, prog, col, th)
    local n = CFG.ring_segs
    local last = math.floor(prog * n)
    for i = 0, last do
        local a1 = start + state.ring_angles[i]
        local a2 = start + state.ring_angles[i+1]
        Render.Line(Vec2(cx + r*math.cos(a1), cy + r*math.sin(a1)),
                    Vec2(cx + r*math.cos(a2), cy + r*math.sin(a2)), col, th)
    end
end

local function draw_ring(cx, cy, last_t, r, th, fill)
    local c = CFG.colors
    local elapsed = GameRules.GetGameTime() - (last_t or 0)
    local prog = math.min(1, math.max(0, elapsed / CFG.aggro_cd))

    if fill then Render.FilledCircle(Vec2(cx, cy), r, c.bg, nil, nil, CFG.ring_segs) end
    Render.Circle(Vec2(cx, cy), r, c.ring, th, nil, nil, nil, CFG.ring_segs)

    if prog < 1 then
        local t = prog * 2
        local lo, hi = c.low, (t <= 1) and c.mid or c.ready
        if t > 1 then t = t - 1 end
        local col = Color(lo.r + (hi.r-lo.r)*t, lo.g + (hi.g-lo.g)*t, lo.b + (hi.b-lo.b)*t, 255)
        arc(cx, cy, r, -math.pi/2, prog, col, th)

        local txt = string.format("%.1f", CFG.aggro_cd - elapsed)
        local fs = math.floor(r * 0.85)
        local sz = text_size(state.font, fs, txt)
        Render.Text(state.font, fs, txt, Vec2(cx - sz.x/2, cy - sz.y/2), c.text)
    else
        Render.Circle(Vec2(cx, cy), r, c.ready, th, nil, nil, nil, CFG.ring_segs)
    end
end

local function draw_radius(units, hero)
    local player = Players.GetLocal()
    local live = {}

    if not state.visuals_off then
        for _, u in ipairs(units) do
            local is_h = u == hero
            if not is_h then
                if not ui.reaggro:Get() then goto skip end
                if player and not NPC.IsControllableByPlayer(u, player) then goto skip end
            end

            local show = is_h and ui.hero_show_radius:Get() or ui.unit_show_radius:Get()
            if is_h then show = ui.hero_show_radius:Get() else show = ui.unit_show_radius:Get() end
            if not show then goto skip end

            local p = Entity.GetAbsOrigin(u)
            if not p then goto skip end

            local color, combo
            if is_h then
                color = ui.hero_radius_color:Get()
                combo = ui.hero_radius_particle
            else
                color = ui.unit_radius_color:Get()
                combo = ui.unit_radius_particle
            end

            ensure_fx(u, p, color, particle_path(combo))
            live[Entity.GetIndex(u)] = true
            ::skip::
        end
    end

    for idx, p in pairs(fx.active) do
        if not live[idx] then Particle.Destroy(p); fx.active[idx] = nil; fx.paths[idx] = nil end
    end
end

local function draw_cds(units, hero)
    if state.visuals_off then return end
    local player = Players.GetLocal()

    for _, u in ipairs(units) do
        local is_h = u == hero
        if not is_h then
            if not ui.reaggro:Get() then goto skip end
            if player and not NPC.IsControllableByPlayer(u, player) then goto skip end
        end

        local show = is_h and ui.hero_cd_show:Get() or ui.unit_cd_show:Get()
        if is_h then show = ui.hero_cd_show:Get() else show = ui.unit_cd_show:Get() end
        if not show then goto skip end

        local o = Entity.GetAbsOrigin(u)
        if not o then goto skip end

        local hb = NPC.GetHealthBarOffset(u, true) or 0
        local height, ox, oy, sz, th, fill
        if is_h then
            height = ui.hero_cd_height:Get()
            ox = ui.hero_cd_offset_x:Get()
            oy = ui.hero_cd_offset_y:Get()
            sz = ui.hero_cd_size:Get()
            th = ui.hero_cd_thickness:Get()
            fill = ui.hero_cd_fill:Get()
        else
            height = ui.unit_cd_height:Get()
            ox = ui.unit_cd_offset_x:Get()
            oy = ui.unit_cd_offset_y:Get()
            sz = ui.unit_cd_size:Get()
            th = ui.unit_cd_thickness:Get()
            fill = ui.unit_cd_fill:Get()
        end

        local wp = o + Vector(0, 0, hb + height)
        local sp, vis = Render.WorldToScreen(wp)
        if not vis or not sp then goto skip end

        draw_ring(sp.x + ox, sp.y - 70 + oy, state.cd[Entity.GetIndex(u)], sz, th, fill)
        ::skip::
    end
end

function M.OnDraw()
    if not Engine.IsInGame() then return end
    if not ui.enable:Get() then destroy_fx(); return end

    local hero = Heroes.GetLocal()
    if not hero or not Entity.IsAlive(hero) then destroy_fx(); return end

    local units = get_units(Players.GetLocal(), hero, CFG.draw_range)
    draw_radius(units, hero)
    draw_cds(units, hero)
end

-- ===== Menu =====
do
    local tab = Menu.Create(CFG.menu.tab, T("creep_aggro.name"), CFG.menu.id)
    tab:Icon(T("creep_aggro.icon"))

    local main = tab:Create(T("creep_aggro.settings.title")):Create(T("creep_aggro.settings.title"))
    local hv = tab:Create(T("creep_aggro.hero_visuals.title")):Create(T("creep_aggro.hero_visuals.title"))
    local uv = tab:Create(T("creep_aggro.unit_visuals.title")):Create(T("creep_aggro.unit_visuals.title"))

    local ring_angles = {}
    for i = 0, CFG.ring_segs do ring_angles[i] = i * 2 * math.pi / CFG.ring_segs end

    local parts = { "None" }
    if (LIB_HEROES_DATA or {}).particles_for_radius then
        for _, n in ipairs(LIB_HEROES_DATA.particles_for_radius) do parts[#parts+1] = n end
    end
    local def_part = #parts >= 3 and 2 or 0

    state = {
        cd = {}, pending = {},
        font = Render.LoadFont("SF Pro Text", Enum.FontCreate.FONTFLAG_ANTIALIAS),
        ring_angles = ring_angles,
        visuals_off = false, key_down = false, hero_done = false,
        particle_names = parts,
    }

    ui = {
        enable = main:Switch("creep_aggro.settings.enable", true, CFG.menu.icon),
        aggro_key = main:Bind("creep_aggro.settings.aggro_key", Enum.ButtonCode.KEY_NONE, "\u{f11c}"),
        reaggro = main:Switch("creep_aggro.settings.reaggro_units", true, "\u{f0c0}"),
        auto_disable = main:Switch("creep_aggro.settings.auto_disable", false, "\u{f2f2}"),
        auto_disable_min = main:Slider("creep_aggro.settings.auto_disable_min", 1, 120, 12, 1),

        hero_show_radius = hv:Switch("creep_aggro.hero_visuals.show_radius", true, "\u{f1cd}"),
        hero_radius_color = hv:ColorPicker("creep_aggro.hero_visuals.radius_color", Color(255, 165, 0, 200), "\u{f1cd}"),
        hero_radius_particle = hv:Combo("creep_aggro.hero_visuals.radius_particle", parts, def_part),
        hero_cd_show = hv:Switch("creep_aggro.hero_visuals.cd_show", true, "\u{f017}"),
        hero_cd_height = hv:Slider("creep_aggro.hero_visuals.cd_height", 0, 300, 0, 5),
        hero_cd_offset_x = hv:Slider("creep_aggro.hero_visuals.cd_offset_x", -200, 200, 0, 1),
        hero_cd_offset_y = hv:Slider("creep_aggro.hero_visuals.cd_offset_y", -200, 200, 0, 1),
        hero_cd_size = hv:Slider("creep_aggro.hero_visuals.cd_size", 8, 40, 18, 1),
        hero_cd_thickness = hv:Slider("creep_aggro.hero_visuals.cd_thickness", 1, 6, 3, 0.5),
        hero_cd_fill = hv:Switch("creep_aggro.hero_visuals.cd_fill", true, "\u{f06e}"),

        unit_show_radius = uv:Switch("creep_aggro.unit_visuals.show_radius", true, "\u{f1cd}"),
        unit_radius_color = uv:ColorPicker("creep_aggro.unit_visuals.radius_color", Color(80, 200, 255, 200), "\u{f1cd}"),
        unit_radius_particle = uv:Combo("creep_aggro.unit_visuals.radius_particle", parts, def_part),
        unit_cd_show = uv:Switch("creep_aggro.unit_visuals.cd_show", true, "\u{f017}"),
        unit_cd_height = uv:Slider("creep_aggro.unit_visuals.cd_height", 0, 300, 0, 5),
        unit_cd_offset_x = uv:Slider("creep_aggro.unit_visuals.cd_offset_x", -200, 200, 0, 1),
        unit_cd_offset_y = uv:Slider("creep_aggro.unit_visuals.cd_offset_y", -200, 200, 0, 1),
        unit_cd_size = uv:Slider("creep_aggro.unit_visuals.cd_size", 8, 40, 13, 1),
        unit_cd_thickness = uv:Slider("creep_aggro.unit_visuals.cd_thickness", 1, 6, 2, 0.5),
        unit_cd_fill = uv:Switch("creep_aggro.unit_visuals.cd_fill", true, "\u{f06e}"),
    }
end

function M.OnGameEnd()
    destroy_fx()
    state.cd, state.pending = {}, {}
    text_cache = {}
end

return M