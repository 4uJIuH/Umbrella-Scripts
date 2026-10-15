local m = {}
m.ui = {}

local main_tab = Menu.Create("Heroes", "Hero List", "Meepo", "Meepo", "Saver")
local combo_key = nil
local retreating_meepos = {}
local last_update_time = 0

local last_move_command_time = {}
local last_poof_cast_time = {}
local last_tp_cast_time = {}
local last_return_poof_time = {}

local damage_history = {}

if main_tab then
    m.ui.enable_save = main_tab:Switch("Включить авто-побег", true)
    m.ui.enable_save:ToolTip("Если включено, Meepo с низким HP будут автоматически уходить на базу.")

    m.ui.auto_calc = main_tab:Switch("Авто-расчет по урону (DPS)", false)
    m.ui.auto_calc:ToolTip("Скрипт оценивает реальный урон за последнюю секунду. Слайдеры HP ниже будут игнорироваться.")

    m.ui.hp_slider = main_tab:Slider("HP % для отступления", 0, 100, 30, "%d%%")
    m.ui.hp_slider:ToolTip("Работает только если выключен 'Авто-расчет по урону'.")

    m.ui.return_slider = main_tab:Slider("HP % для возврата", 0, 100, 90, "%d%%")
    m.ui.return_slider:ToolTip("При каком % здоровья возвращать Meepo в комбо и снимать статус беглеца.")

    m.ui.enable_poof_save = main_tab:Switch("Использовать Poof для спасения", true)
    m.ui.enable_poof_save:ToolTip("Если включено, раненый Meepo сделал Poof на дружественного Meepo у фонтана.")

    m.ui.enable_tp_save = main_tab:Switch("Использовать ТП для спасения", true)
    m.ui.enable_tp_save:ToolTip("Если включено, раненый Meepo будет использовать свиток телепортации (TP) на фонтан.")

    m.ui.lock_control_on_save = main_tab:Switch("Блокировать контроль при сейве", true)
    m.ui.lock_control_on_save:ToolTip("Скрипт автоматически снимает выделение с убегающих Meepo, чтобы вы случайно не сбили им движение.")

    m.ui.auto_return_poof = main_tab:Switch("Авто-возврат через Poof", true)
    m.ui.auto_return_poof:ToolTip("Когда Meepo вылечился, он автоматически сделает Poof на активного Meepo в бою.")
end

combo_key = Menu.Find("Heroes", "Hero List", "Meepo", "Main Settings", "Hero Settings", "Combo Key")

local fountain_positions = {
    [Enum.TeamNum.TEAM_RADIANT] = Vector(-7019, -6534, 384),
    [Enum.TeamNum.TEAM_DIRE] = Vector(6846, 6251, 384)
}

local function GetDistance2D(v1, v2)
    if not v1 or not v2 then return 999999 end
    if v1.Length2D then return (v1 - v2):Length2D() end
    local dx = (v1:GetX() or v1.x) - (v2:GetX() or v2.x)
    local dy = (v1:GetY() or v1.y) - (v2:GetY() or v2.y)
    return math.sqrt(dx*dx + dy*dy)
end

local function FindFountainMeepoTarget(all_meepos, self_meepo, fountain_pos)
    local best_target = nil
    local min_dist = 999999

    for _, other in ipairs(all_meepos) do
        if other ~= self_meepo and Entity.IsAlive(other) then
            local pos = Entity.GetAbsOrigin(other)
            if pos and fountain_pos then
                local dist = GetDistance2D(pos, fountain_pos)
                if dist < 3500 and dist < min_dist then
                    min_dist = dist
                    best_target = other
                end
            end
        end
    end
    return best_target
end

local function FindActiveMeepoTarget(all_meepos, self_meepo, fountain_pos)
    local best_target = nil
    local max_dist_from_fountain = -1

    for _, other in ipairs(all_meepos) do
        if other ~= self_meepo and Entity.IsAlive(other) and not retreating_meepos[Entity.GetIndex(other)] then
            local pos = Entity.GetAbsOrigin(other)
            if pos and fountain_pos then
                local dist = GetDistance2D(pos, fountain_pos)
                if dist > max_dist_from_fountain then
                    max_dist_from_fountain = dist
                    best_target = other
                end
            end
        end
    end
    return best_target
end

local function UpdateAndGetDPS(meepo_index, current_hp, current_time)
    if not damage_history[meepo_index] then
        damage_history[meepo_index] = { last_hp = current_hp, history = {} }
    end

    local data = damage_history[meepo_index]
    local damage_taken = data.last_hp - current_hp
    data.last_hp = current_hp

    if damage_taken > 0 then
        table.insert(data.history, { time = current_time, damage = damage_taken })
    end

    local i = 1
    while i <= #data.history do
        if current_time - data.history[i].time > 1.5 then
            table.remove(data.history, i)
        else
            i = i + 1
        end
    end

    local total_damage = 0
    for _, entry in ipairs(data.history) do
        total_damage = total_damage + entry.damage
    end

    return total_damage / 1.5
end

local function IsUnderTowerOrCreeps(meepo, my_team)
    local meepo_pos = Entity.GetAbsOrigin(meepo)
    if not meepo_pos then return false end

    for _, unit in pairs(NPCs.GetAll()) do
        if unit and Entity.IsAlive(unit) and not Entity.IsDormant(unit) and Entity.GetTeamNum(unit) ~= my_team then
            if NPC.IsTower(unit) then
                if GetDistance2D(meepo_pos, Entity.GetAbsOrigin(unit)) <= 900 then
                    return true
                end
            elseif NPC.IsLaneCreep(unit) or (NPC.IsNeutral and NPC.IsNeutral(unit)) then
                if GetDistance2D(meepo_pos, Entity.GetAbsOrigin(unit)) <= 500 then
                    local target = NPC.GetAttackTarget(unit)
                    if target and Entity.GetIndex(target) == Entity.GetIndex(meepo) then
                        return true
                    end
                end
            end
        end
    end
    return false
end

local function IsChannelingCustom(meepo)
    if NPC.HasModifier(meepo, "modifier_teleporting") then return true end
    if NPC.IsActivity and NPC.IsActivity(meepo, Enum.EntityActivity.ACT_DOTA_CHANNEL_ABILITY) then return true end
    return false
end

m.OnUpdate = function()
    if not m.ui.enable_save or not m.ui.enable_save:Get() or not Engine.IsInGame() then
        return
    end

    local current_time = GlobalVars.GetCurTime()
    if current_time < last_update_time then return end
    last_update_time = current_time + 0.05

    local local_hero = Heroes.GetLocal()
    if not local_hero or not Entity.IsAlive(local_hero) or NPC.GetUnitName(local_hero) ~= "npc_dota_hero_meepo" then
        return
    end

    local local_player = Players.GetLocal()
    if not local_player then return end

    local player_id = Player.GetPlayerID(local_player)
    local active_meepos_for_combo = {}

    local use_auto_calc = m.ui.auto_calc and m.ui.auto_calc:Get()
    local retreat_hp_percent = m.ui.hp_slider:Get() / 100.0
    local return_hp_percent = m.ui.return_slider:Get() / 100.0

    local my_team = Entity.GetTeamNum(local_hero)
    local fountain_pos = fountain_positions[my_team]
    local has_shard = NPC.HasShard(local_hero)

    local all_meepos = {}

    for _, npc in pairs(NPCs.GetAll()) do
        if npc and Entity.IsAlive(npc) and NPC.GetUnitName(npc) == "npc_dota_hero_meepo" and not NPC.IsIllusion(npc) and NPC.IsControllableByPlayer(npc, player_id) then
            table.insert(all_meepos, npc)
        end
    end

    if #all_meepos == 0 then return end

    for _, meepo in ipairs(all_meepos) do
        local meepo_index = Entity.GetIndex(meepo)
        local current_hp = Entity.GetHealth(meepo)
        local max_hp = Entity.GetMaxHealth(meepo)
        local current_hp_percent = current_hp / max_hp

        local dps = UpdateAndGetDPS(meepo_index, current_hp, current_time)
        local has_fountain_buff = NPC.HasModifier(meepo, "modifier_fountain_aura_buff")
        local is_megameepo = NPC.HasModifier(meepo, "modifier_meepo_megameepo")
        local petrify_ability = NPC.GetAbility(meepo, "meepo_petrify")
        local can_petrify = has_shard and petrify_ability and Ability.IsReady(petrify_ability)

        if is_megameepo or can_petrify then
            table.insert(active_meepos_for_combo, meepo)
            retreating_meepos[meepo_index] = nil
            goto continue
        end

        local is_dug = NPC.HasModifier(meepo, "modifier_meepo_petrify")
        local is_channeling = IsChannelingCustom(meepo)

        if current_hp_percent >= return_hp_percent then
            if m.ui.auto_return_poof:Get() and has_fountain_buff then
                if is_channeling then
                    goto continue
                end

                local time_since_return_poof = current_time - (last_return_poof_time[meepo_index] or 0)
                if time_since_return_poof > 3.0 then
                    local poof_ability = NPC.GetAbility(meepo, "meepo_poof")
                    if poof_ability and Ability.IsReady(poof_ability) then
                        local poof_target = FindActiveMeepoTarget(all_meepos, meepo, fountain_pos)
                        if poof_target then
                            local target_pos = Entity.GetAbsOrigin(poof_target)
                            if target_pos then
                                Ability.CastPosition(poof_ability, target_pos)
                                last_return_poof_time[meepo_index] = current_time
                                goto continue
                            end
                        end
                    end
                end
            end

            retreating_meepos[meepo_index] = nil
            last_move_command_time[meepo_index] = nil
            last_poof_cast_time[meepo_index] = nil
            last_tp_cast_time[meepo_index] = nil
            last_return_poof_time[meepo_index] = nil
            table.insert(active_meepos_for_combo, meepo)
            goto continue
        end

        if is_dug then
            retreating_meepos[meepo_index] = true
            goto continue
        end

        local trigger_retreat = false
        if retreating_meepos[meepo_index] then
            trigger_retreat = true
        else
            if use_auto_calc then
                local under_pressure = IsUnderTowerOrCreeps(meepo, my_team)
                if dps > 0 then
                    local time_to_die = current_hp / dps
                    local max_time_threshold = under_pressure and 4.5 or 3.5
                    if (time_to_die <= max_time_threshold and current_hp_percent < 0.55) or current_hp_percent < 0.22 then
                        trigger_retreat = true
                    end
                elseif current_hp_percent < 0.22 or (under_pressure and current_hp_percent < 0.35) then
                    trigger_retreat = true
                end
            else
                trigger_retreat = (current_hp_percent < retreat_hp_percent)
            end
        end

        if trigger_retreat then
            retreating_meepos[meepo_index] = true

            if is_channeling then
                goto continue
            end

            local time_since_poof = current_time - (last_poof_cast_time[meepo_index] or 0)
            local time_since_tp = current_time - (last_tp_cast_time[meepo_index] or 0)

            if time_since_poof < 2.5 or time_since_tp < 2.5 then
                goto continue
            end

            local escape_action_taken = false

            if m.ui.enable_poof_save:Get() and not has_fountain_buff then
                local poof_ability = NPC.GetAbility(meepo, "meepo_poof")
                if poof_ability and Ability.IsReady(poof_ability) then
                    local poof_target = FindFountainMeepoTarget(all_meepos, meepo, fountain_pos)
                    if poof_target then
                        local target_pos = Entity.GetAbsOrigin(poof_target)
                        if target_pos then
                            Ability.CastPosition(poof_ability, target_pos)
                            last_poof_cast_time[meepo_index] = current_time
                            escape_action_taken = true
                        end
                    end
                end
            end

            if not escape_action_taken and m.ui.enable_tp_save:Get() and not has_fountain_buff then
                local tp_scroll = NPC.GetItem(meepo, "item_tpscroll", false)
                if tp_scroll and Ability.IsReady(tp_scroll) then
                    Ability.CastPosition(tp_scroll, fountain_pos)
                    last_tp_cast_time[meepo_index] = current_time
                    escape_action_taken = true
                end
            end

            if not escape_action_taken and fountain_pos then
                local last_move_time = last_move_command_time[meepo_index] or 0
                if current_time - last_move_time > 1.0 then
                    NPC.MoveTo(meepo, fountain_pos)
                    last_move_command_time[meepo_index] = current_time
                end
            end
        else
            table.insert(active_meepos_for_combo, meepo)
        end
        ::continue::
    end

    local is_combo_pressed = combo_key and Input.IsKeyDown(combo_key:Get())
    local lock_enabled = m.ui.lock_control_on_save and m.ui.lock_control_on_save:Get()

    if is_combo_pressed then
        Player.ClearSelectedUnits(local_player)
        if #active_meepos_for_combo > 0 then
            for _, meepo in pairs(active_meepos_for_combo) do
                Player.AddSelectedUnit(local_player, meepo)
            end
        end
    elseif lock_enabled then
        local currently_selected = Player.GetSelectedUnits(local_player)
        if currently_selected and #currently_selected > 0 then
            local selected_index_map = {}
            for _, unit in ipairs(currently_selected) do
                selected_index_map[Entity.GetIndex(unit)] = true
            end

            local has_retreating_selected = false
            for _, meepo in ipairs(all_meepos) do
                local meepo_index = Entity.GetIndex(meepo)
                if retreating_meepos[meepo_index] and selected_index_map[meepo_index] then
                    has_retreating_selected = true
                    break
                end
            end

            if has_retreating_selected then
                local safe_selected = {}
                for _, meepo in ipairs(all_meepos) do
                    local meepo_index = Entity.GetIndex(meepo)
                    if not retreating_meepos[meepo_index] and selected_index_map[meepo_index] then
                        table.insert(safe_selected, meepo)
                    end
                end

                Player.ClearSelectedUnits(local_player)
                for _, meepo in ipairs(safe_selected) do
                    Player.AddSelectedUnit(local_player, meepo)
                end
            end
        end
    end
end

m.OnGameEnd = function()
    retreating_meepos = {}
    last_move_command_time = {}
    last_poof_cast_time = {}
    last_tp_cast_time = {}
    last_return_poof_time = {}
    damage_history = {}
    last_update_time = 0
end

return m