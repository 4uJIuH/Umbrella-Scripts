local script = {}
local menu = Menu.Create("Heroes", "Hero List", "Witch Doctor", "Main Settings", "Ward Settings")
local switch = menu:Switch("Control Death Wards", true, "\u{e1ec}")

local hero, player = nil, nil
local ward_targets = {}
local ward_last_order = {}
local deathWard = "npc_dota_witch_doctor_death_ward"

local function GetDeathWards()
    local wards = {}
    for _, entity in pairs(Entities.GetAll()) do
        if
            Entity.IsAlive(entity) and Entity.GetUnitName(entity) == deathWard and
                Entity.IsControllableByPlayer(entity, Player.GetPlayerID(player))
         then
            table.insert(wards, entity)
        end
    end
    return wards
end

local function FindBestTarget(ward)
    local enemies = Entity.GetUnitsInRadius(ward, 650, Enum.TeamType.TEAM_ENEMY)
    local lowest_hp_hero, lowest_hp = nil, math.huge

    for _, enemy in ipairs(enemies) do
        if not NPC.IsKillable(enemy) then
            return
        end
        local name = NPC.GetUnitName(enemy)
        if name == "npc_dota_juggernaut_healing_ward" then
            return enemy -- always prioritize healing ward
        elseif NPC.IsHero(enemy) and not NPC.IsIllusion(enemy) and Entity.IsAlive(enemy) then
            local hp = Entity.GetHealth(enemy)
            if hp < lowest_hp then
                lowest_hp = hp
                lowest_hp_hero = enemy
            end
        end
    end
    return lowest_hp_hero
end

script.OnUpdate = function()
    if not switch:Get() then
        return
    end

    if not hero or not player then
        hero = Heroes.GetLocal()
        player = Players.GetLocal()
        if not hero or not player then
            return
        end
    end

    local wards = GetDeathWards()
    local alive_wards = {}
    local healing_ward_targeted = false
    local now = os.clock()
    local wardRange = 600
    if Hero.TalentIsLearned(hero, Enum.TalentTypes.TALENT_5) then
        wardRange = wardRange + 75
    end

    for _, ward in ipairs(wards) do
        alive_wards[ward] = true
        local prev_target = ward_targets[ward]
        local new_target = FindBestTarget(ward)

        local need_new_order = false

        if new_target then
            if prev_target ~= new_target then
                need_new_order = true
            elseif not Entity.IsAlive(prev_target) then
                need_new_order = true
            elseif Entity.GetAbsOrigin(ward):Distance(Entity.GetAbsOrigin(prev_target)) > wardRange then
                need_new_order = true
            end
        end

        local name = new_target and NPC.GetUnitName(new_target) or nil
        if name == "npc_dota_juggernaut_healing_ward" then
            if not healing_ward_targeted then
                if not ward_last_order[ward] or (now - ward_last_order[ward]) > 1.0 then
                    Player.AttackTarget(player, ward, new_target, false, false, false, "", false)
                    ward_targets[ward] = new_target
                    ward_last_order[ward] = now
                end
                healing_ward_targeted = true
            else
                ward_targets[ward] = nil
            end
        elseif need_new_order and new_target then
            if not ward_last_order[ward] or (now - ward_last_order[ward]) > 1.0 then
                Player.AttackTarget(player, ward, new_target, false, false, false, "", false)
                ward_targets[ward] = new_target
                ward_last_order[ward] = now
            end
        elseif not new_target then
            ward_targets[ward] = nil
            ward_last_order[ward] = nil
        end
    end

    -- Clean up dead or missing wards
    for ward in pairs(ward_targets) do
        if not alive_wards[ward] or not Entity.IsAlive(ward) then
            ward_targets[ward] = nil
            ward_last_order[ward] = nil
        end
    end
end

script.OnGameEnd = function()
    hero, player = nil, nil
    ward_targets = {}
    ward_last_order = {}
end

return script
