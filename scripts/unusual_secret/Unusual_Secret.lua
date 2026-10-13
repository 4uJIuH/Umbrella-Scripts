local unusuallite = {}
unusuallite.VERSION = "2.1"

local tab = Menu.Create("Scripts", "Визуал", "Секретные эффекты")
tab:Icon("\u{f0c3}")
local grp = tab:Create("Эффекты"):Create("Настройки")

local FX_LIST = {
    { "Aphotic Shield", "particles/units/heroes/hero_abaddon/abaddon_aphotic_shield.vpcf" },
    { "Sandstorm", "particles/units/heroes/hero_sandking/sandking_sandstorm.vpcf" },
    { "Rot", "particles/units/heroes/hero_pudge/pudge_rot.vpcf" },
    { "Windrun", "particles/units/heroes/hero_windrunner/windrunner_windrun.vpcf" },
    { "Static Remnant", "particles/units/heroes/hero_stormspirit/stormspirit_static_remnant.vpcf" },
    { "Guardian", "particles/econ/items/wisp/io_carnival/io_carnival_guardian.vpcf" },
    { "Unripe", "particles/econ/items/oracle/oracle_ti10_immortal/oracle_ti10_immortal_purifyingflames_glow.vpcf" },
    { "Spirit Trail", "particles/econ/courier/courier_trail_spirit/courier_trail_spirit.vpcf" },
    { "Oculopus", "particles/econ/courier/courier_oculopus/courier_oculopus_ambient.vpcf" },
}
local SIZES = {
    ["Aphotic Shield"] = 21,
    ["Sandstorm"] = 35,
    ["Rot"] = 125,
    ["Windrun"] = 150,
    ["Static Remnant"] = 50,
}
local ATTACHS = {
    { "Оружие 1", "attach_attack1" },
    { "Оружие 2", "attach_attack2" },
    { "Голова", "attach_eyes" },
    { "Тело", "attach_hitloc" },
    { "Макушка", "attach_head" },
    { "Ноги", "attach_origin" },
}
local FX_NAMES = {}
for i, e in ipairs(FX_LIST) do FX_NAMES[i] = e[1] end
local ATTACH_NAMES = {}
for i, e in ipairs(ATTACHS) do ATTACH_NAMES[i] = e[1] end

local MAX_SLOTS = 4
local ui = {}
ui.enable = grp:Switch("Включить", false, "\u{f005}")
ui.enable:Icon("\u{f005}")

ui.target = grp:Combo("Цель", {
    "Свой герой",
    "Ближайший враг",
}, 0)
ui.target:Icon("\u{f007}")

local slots = {}
for i = 1, MAX_SLOTS do
    local s = {}
    s.fx = grp:Combo("Эффект " .. i, FX_NAMES, 0)
    s.fx:Icon("\u{f00b}")
    s.attach = grp:Combo("Место " .. i, ATTACH_NAMES, 0)
    s.attach:Icon("\u{f0b0}")
    s.p = nil
    s.key = nil
    slots[i] = s
end

local ok_add, btn_add = pcall(function() return grp:Button("+ Добавить эффект") end)
local ok_del, btn_del = pcall(function() return grp:Button("- Убрать эффект") end)
local has_buttons = ok_add and btn_add ~= nil and ok_del and btn_del ~= nil
if has_buttons then
    pcall(function() btn_add:Icon("\u{f067}") end)
    pcall(function() btn_del:Icon("\u{f068}") end)
end

ui.status = grp:Label("Статус: выкл", "\u{f05a}")

local CFG = "Unusual_Secret"
local visible_slots = 1
if not has_buttons then visible_slots = MAX_SLOTS end

local function cfg_save()
    pcall(Config.WriteInt, CFG, "enable", ui.enable:Get() and 1 or 0)
    pcall(Config.WriteInt, CFG, "target", ui.target:Get() or 0)
    pcall(Config.WriteInt, CFG, "slots", visible_slots)
    for i, s in ipairs(slots) do
        pcall(Config.WriteInt, CFG, "fx" .. i, s.fx:Get() or 0)
        pcall(Config.WriteInt, CFG, "attach" .. i, s.attach:Get() or 0)
    end
end

local function cfg_load()
    local ok_e, en = pcall(Config.ReadInt, CFG, "enable", 0)
    if ok_e and en == 1 then pcall(function() ui.enable:Set(true) end) end
    local ok_t, tg = pcall(Config.ReadInt, CFG, "target", 0)
    if ok_t and (tg == 0 or tg == 1) then pcall(function() ui.target:Set(tg) end) end
    local ok_s, sl = pcall(Config.ReadInt, CFG, "slots", 1)
    if ok_s and sl >= 1 and sl <= MAX_SLOTS then visible_slots = sl end
    for i, s in ipairs(slots) do
        local ok_f, fv = pcall(Config.ReadInt, CFG, "fx" .. i, 0)
        if ok_f and fv >= 0 and fv < #FX_NAMES then pcall(function() s.fx:Set(fv) end) end
        local ok_a, av = pcall(Config.ReadInt, CFG, "attach" .. i, 0)
        if ok_a and av >= 0 and av < #ATTACH_NAMES then pcall(function() s.attach:Set(av) end) end
    end
end

local function target_key(u)
    local ok, i = pcall(Entity.GetIndex, u)
    if ok and i then return i end
    return tostring(u)
end

local function find_target()
    if (ui.target:Get() or 0) == 0 then
        local ok, h = pcall(Heroes.GetLocal)
        if ok and h then
            local ok_a, alive = pcall(Entity.IsAlive, h)
            if ok_a and alive then return h end
        end
        return nil
    end
    local me = nil
    pcall(function() me = Heroes.GetLocal() end)
    local my_team = 2
    if me then
        pcall(function()
            local t = Entity.GetTeamNum(me)
            if t then my_team = t end
        end)
    end
    local best, best_d = nil, 999999
    local ok, list = pcall(Heroes.GetAll)
    if ok and list then
        for _, u in pairs(list) do
            if u ~= me then
                local ok1, h = pcall(NPC.IsHero, u)
                local ok2, t = pcall(Entity.GetTeamNum, u)
                local ok3, ill = pcall(NPC.IsIllusion, u)
                local ok4, al = pcall(Entity.IsAlive, u)
                local ok5, vis = pcall(NPC.IsVisible, u)
                if ok1 and h and ok2 and t ~= my_team and not (ok3 and ill) and ok4 and al and ok5 and vis then
                    local d = 999999
                    if me then
                        local ok_p, pa = pcall(Entity.GetAbsOrigin, me)
                        local ok_q, pb = pcall(Entity.GetAbsOrigin, u)
                        if ok_p and ok_q and pa and pb then
                            local dx, dy = pa.x - pb.x, pa.y - pb.y
                            d = math.sqrt(dx * dx + dy * dy)
                        end
                    else
                        d = 0
                    end
                    if d < best_d then best, best_d = u, d end
                end
            end
        end
    end
    return best
end

local function drop_slot(s)
    if s.p then
        pcall(Particle.Destroy, s.p)
        s.p = nil
    end
    s.key = nil
end

local function slot_path(s)
    local entry = FX_LIST[(s.fx:Get() or 0) + 1] or FX_LIST[1]
    return entry[1], entry[2]
end

local function slot_attach(s)
    local e = ATTACHS[(s.attach:Get() or 0) + 1] or ATTACHS[1]
    return e[1], e[2]
end

local function ensure_slot(s, u)
    local nm, path = slot_path(s)
    local _, att = slot_attach(s)
    local key = target_key(u) .. "||" .. path .. "||" .. att
    if s.p and s.key == key then return true end
    drop_slot(s)
    local idx = nil
    local ok_c, res = pcall(Particle.Create, path, Enum.ParticleAttachment.PATTACH_POINT_FOLLOW, u)
    if ok_c and res then idx = res end
    if not idx then
        print("[unusuallite] не создался: " .. tostring(path))
        return false
    end
    local ok_s = pcall(Particle.SetControlPointEnt, idx, 0, u,
        Enum.ParticleAttachment.PATTACH_POINT_FOLLOW, att, Vector(0, 0, 0), false)
    if not ok_s then
        pcall(Particle.Destroy, idx)
        print("[unusuallite] не встал на точку: " .. tostring(att))
        return false
    end
    local sz = SIZES[nm] or 0
    if sz > 0 then
        pcall(Particle.SetControlPoint, idx, 1, Vector(sz, sz, sz))
    end
    s.p = idx
    s.key = key
    return true
end

local function refresh_slots()
    for i, s in ipairs(slots) do
        local vis = i <= visible_slots
        pcall(function() s.fx:Visible(vis) end)
        pcall(function() s.attach:Visible(vis) end)
        if not vis then drop_slot(s) end
    end
end

if has_buttons then
    pcall(function()
        btn_add:SetCallback(function()
            if visible_slots < MAX_SLOTS then
                visible_slots = visible_slots + 1
                refresh_slots()
                cfg_save()
            end
        end)
    end)
    pcall(function()
        btn_del:SetCallback(function()
            if visible_slots > 1 then
                visible_slots = visible_slots - 1
                refresh_slots()
                cfg_save()
            end
        end)
    end)
end

cfg_load()

pcall(function()
    ui.enable:SetCallback(function() cfg_save() end)
end)
pcall(function()
    ui.target:SetCallback(function() cfg_save() end)
end)
for _, s in ipairs(slots) do
    pcall(function()
        s.fx:SetCallback(function() cfg_save() end)
    end)
    pcall(function()
        s.attach:SetCallback(function() cfg_save() end)
    end)
end

refresh_slots()

pcall(function()
    local ok_f, second = pcall(Menu.Find, "Scripts", "Визуал", "Секретные эффекты")
    if ok_f and second and second.Icon then
        second:Icon("\u{f0c3}")
        print("[unusuallite] icon ok")
        return
    end
    local o = grp
    for _ = 1, 5 do
        if not o then break end
        if o.Icon then
            o:Icon("\u{f0c3}")
            break
        end
        local ok, p = pcall(function() return o:Parent() end)
        if not ok or not p then break end
        o = p
    end
end)

unusuallite._ts = -10
unusuallite._status_ts = -10

function unusuallite.OnUpdate()
    if not ui.enable:Get() then
        for _, s in ipairs(slots) do
            if s.p then drop_slot(s) end
        end
        return
    end
    local ok_g, ing = pcall(Engine.IsInGame)
    if not ok_g or not ing then
        for _, s in ipairs(slots) do
            if s.p then drop_slot(s) end
        end
        return
    end
    local t = 0
    if os and os.clock then
        local ok_c, tc = pcall(os.clock)
        if ok_c and type(tc) == "number" and tc > 0 then t = tc end
    end
    if t - unusuallite._ts < 0.5 then return end
    unusuallite._ts = t
    local u = find_target()
    if not u then
        for _, s in ipairs(slots) do
            if s.p then drop_slot(s) end
        end
        return
    end
    local n = 0
    for i, s in ipairs(slots) do
        if i <= visible_slots then
            if ensure_slot(s, u) then n = n + 1 end
        end
    end
    if t - unusuallite._status_ts >= 2 then
        unusuallite._status_ts = t
        pcall(function()
            local nm = ""
            pcall(function() nm = NPC.GetUnitName(u) or "" end)
            nm = string.gsub(nm, "^npc_dota_hero_", "")
            ui.status:ForceLocalization(("Активно: %d | %s"):format(n, nm))
        end)
    end
end

function unusuallite.OnGameEnd()
    for _, s in ipairs(slots) do drop_slot(s) end
end

pcall(function()
    print("[unusuallite] v2.0 загружен")
end)

return unusuallite
