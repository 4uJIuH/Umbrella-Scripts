local PTabs = {}
local menu = Menu.Create("Scripts", "Combat", "PTabs")
menu:Icon("\u{e500}")
local main_tab = menu:Create("PTabs")
local cfg_grp = main_tab:Create("Настройки")

local options = {
    on = cfg_grp:Switch("Включить", true),
    main_stat = cfg_grp:Combo("Основной стат", {"Авто", "Сила", "Ловкость", "Интеллект"}, 0),
    switch_atk = cfg_grp:Switch("Абуз при атаке", true),
    hp_low = cfg_grp:Slider("Порог HP %", 5, 50, 25),
    db = cfg_grp:Switch("Дебаг", false),
}

local me = nil
local last_tick = 0
local last_sw = 0
local auto_stat = -1
local threats = {}
local function get_pt_mode(pt)
    if not pt then return -1 end
    if PowerTreads and PowerTreads.GetStats then
        local success, result = pcall(PowerTreads.GetStats, pt)
        return success and result or -1
    end
    return -1
end

local function check_danger()
    if not me then return false end
    local time = os.clock()

    local has_threat = false
    for k, v in pairs(threats) do
        if time > v then
            threats[k] = nil
        else
            has_threat = true
        end
    end
    if has_threat then return true end

    if options.switch_atk:Get() then
        local pos = Entity.GetAbsOrigin(me)
        local enemies = Heroes.GetAll()
        for i, ent in pairs(enemies) do
            if ent and ent ~= me and Entity.IsAlive(ent) and not Entity.IsDormant(ent) and not Entity.IsSameTeam(me, ent) then
                if (Entity.GetAbsOrigin(ent) - pos):Length() <= 550 and NPC.IsAttacking(ent) then
                    return true
                end
            end
        end
    end

    return false
end

local function do_switch(pt, target)
    if not pt or target == -1 then return end
    local t = os.clock()

    if t < last_sw + 0.12 then return end -- можете уменьшить, но мне в падлу искать идеальное время, мб в некст апдейте чет сделаю

    local curr = get_pt_mode(pt)
    if curr == -1 or curr == target then return end

    Ability.CastNoTarget(pt)
    last_sw = t

    if options.db:Get() then
        Log.Write("[pt]: sw" .. curr .. " -> " .. target)
    end
end

function PTabs.OnUpdate()
    if not options.on:Get() then return end

    local time = os.clock()
    if time < last_tick + 0.05 then return end
    last_tick = time

    if not me then me = Heroes.GetLocal() end
    if not me or not Entity.IsAlive(me) then return end

    local pt = NPC.GetItem(me, "item_power_treads", true)
    if not pt then return end

    local hp_per = (Entity.GetHealth(me) / Entity.GetMaxHealth(me)) * 100
    local cur_mode = get_pt_mode(pt)
    local is_danger = check_danger()

    local target = -1
    local set = options.main_stat:Get()

    local home = -1
    if set == 1 then home = 0
    elseif set == 2 then home = 1
    elseif set == 3 then home = 2
    else
        if cur_mode ~= -1 and cur_mode ~= 0 then
            auto_stat = cur_mode --недоделал, немного впадлу, так же в апдейте займусь
        end
        home = auto_stat
    end

    if hp_per <= options.hp_low:Get() or is_danger then
        target = 0
    else
        target = home
    end

    if target ~= -1 and cur_mode ~= target then
        do_switch(pt, target)
    end
end

function PTabs.OnProjectile(obj)
    if not options.on:Get() or not options.switch_atk:Get() or not me then return end
    if obj.target == me and obj.isAttack then
        threats[obj.handle or "id"] = os.clock() + 1.8
    end
end

function PTabs.OnProjectileDestroy(obj)
    if threats[obj.handle] then
        threats[obj.handle] = nil
    end
end

return PTabs