--[[
    Arc Warden Clone Wave Pusher Addon (Умный пуш пачек для клона Арк Вардена)

    Новая логика: УМНЫЙ КАЛЬКУЛЯТОР УРОНА И РАСПРЕДЕЛЕННЫЙ ПУШ
    1. Калькулятор урона от Спарка:
       - Рассчитывает точный чистый урон Spark Wraith по крипу с учетом уровня,
         таланта 25-го уровня (+240 урона), Spell Amplification и маг. резиста крипа (25%).
    2. Умное распределение тычек (Damage Accounting):
       - Считает, сколько ХП останется у дальника после взрыва Спарка.
       - Если Спарк ваншотит дальника (ХП <= урон спарка) — клон ставит спарк и дает 0 ТЫЧЕК!
       - Если не хватает урона — клон делает РОВНО столько тычек (обычно 1), сколько нужно,
         чтобы суммарный урон (тычка + Спарк) гарантированно убил дальника.
       - Как только нужная тычка выпущена, крип помечается как «гарантированно труп».
         Клон НЕ ЖДЕТ взрыва и НЕ ДЕЛАЕТ лишних тычек, а мгновенно переключается дальше!
    3. Жесткая отмена атак по милишникам:
       - В OnPrepareUnitOrders приказы базового скрипта бить милишников жестко отменяются
         через return false (а не просто data.target), с мгновенной переотдачей в приоритетную цель.
    4. Очередь целей:
       - Дальник №1 ➔ Дальник №2 (если дабл-пачка) ➔ Знаменосец ➔ Остальные милишники.
--]]

local SCRIPT_NAME = "ArcWardenWavePusher"
local ORDER_IDENTIFIER = "AW_Wave_Pusher"

--#region Localization
local STR = {
    ru = {
        enable = "Умный пуш пачек",
        enable_tip = "Умное дополнение для пуша копией: расчет урона Спарка, минимум тычек по дальникам, купол и ластхит знаменосца",
        smart_pos = "Умная позиция и Magnetic Field",
        smart_pos_tip = "Подходит в точку, откуда достает до дальников и знаменосца, и только потом ставит купол Magnetic Field",
        spark_ranged = "Спарк под дальника",
        spark_ranged_tip = "Ставит Spark Wraith строго под крипа-дальника с точным расчетом урона",
        priority_flag = "Приоритет знаменосца",
        priority_flag_tip = "После дальников переключается на крипа-знаменосца и гарантированно забирает золото",
        attack_lead = "Упреждение ластхита (мс)",
        attack_lead_tip = "Временной буфер (в миллисекундах) для компенсации урона от летящих снарядов союзных крипов",
        draw_target = "Отображать цель в мире",
        draw_target_tip = "Отображает цветное кольцо под текущей целью пуша клона (голубое - дальник, золотое - знаменосец)",
    },
    en = {
        enable = "Smart Wave Pusher",
        enable_tip = "Smart clone pushing: calculates Spark damage, minimum attacks on ranged creeps, Magnetic Field positioning, and flagbearer last-hitting",
        smart_pos = "Smart Position & Magnetic Field",
        smart_pos_tip = "Positions clone to reach both ranged creeps and flagbearer before deploying Magnetic Field",
        spark_ranged = "Spark on Ranged Creep",
        spark_ranged_tip = "Casts Spark Wraith directly on ranged creep with exact damage calculation",
        priority_flag = "Prioritize Flagbearer",
        priority_flag_tip = "Switches to flagbearer creep after ranged creeps to guarantee bounty gold",
        attack_lead = "Last-hit Attack Lead (ms)",
        attack_lead_tip = "Time buffer (in milliseconds) to compensate for ally creep projectile damage",
        draw_target = "Draw Target in World",
        draw_target_tip = "Renders a colored ring under clone's current focus target (cyan - ranged, gold - flagbearer)",
    }
}

local function cheat_lang_code()
    local code = nil
    pcall(function()
        local w = Menu.Find("SettingsHidden", "", "", "", "Main", "Language")
        if w then
            local list = w:List()
            local idx = w:Get() or 0
            local name = list and list[idx + 1]
            if name then
                local s = string.upper(tostring(name))
                if s:find("RU", 1, true) then
                    code = "ru"
                elseif s:find("EN", 1, true) then
                    code = "en"
                end
            end
        end
    end)
    return code
end

local function cur_lang()
    local code = cheat_lang_code()
    if code then return code end
    local ok, g = pcall(function()
        if Steam and Steam.GetGameLanguage then return Steam.GetGameLanguage() end
    end)
    if ok and g then
        local s = string.lower(tostring(g))
        if s:sub(1, 2) == "ru" then return "ru" end
    end
    return "en"
end
--#endregion

local ui = {}

--#region Menu Setup
local auto_play_group = Menu.Create("Heroes", "Hero List", "Arc Warden", "Clone Settings", "Auto Play Settings")

local init_lang = cur_lang()
local init_T = STR[init_lang] or STR.en

-- Главный переключатель
ui.enable = auto_play_group:Switch(init_T.enable, true, "\u{f0e7}")
ui.enable:ToolTip(init_T.enable_tip)

-- Поднастройки
ui.smart_position = auto_play_group:Switch(init_T.smart_pos, true, "\u{f0c8}")
ui.smart_position:ToolTip(init_T.smart_pos_tip)

ui.spark_ranged = auto_play_group:Switch(init_T.spark_ranged, true, "\u{f06d}")
ui.spark_ranged:ToolTip(init_T.spark_ranged_tip)

ui.priority_flagbearer = auto_play_group:Switch(init_T.priority_flag, true, "\u{f024}")
ui.priority_flagbearer:ToolTip(init_T.priority_flag_tip)

ui.attack_lead = auto_play_group:Slider(init_T.attack_lead, 0, 150, 40, (init_lang == "ru" and "%d мс" or "%d ms"))
ui.attack_lead:ToolTip(init_T.attack_lead_tip)

ui.draw_target = auto_play_group:Switch(init_T.draw_target, true, "\u{f5a9}")
ui.draw_target:ToolTip(init_T.draw_target_tip)

-- Привязка видимости поднастроек к главному переключателю
local function update_visibility(widget)
    local enabled = widget:Get()
    ui.smart_position:Visible(enabled)
    ui.spark_ranged:Visible(enabled)
    ui.priority_flagbearer:Visible(enabled)
    ui.attack_lead:Visible(enabled)
    ui.draw_target:Visible(enabled)
end

ui.enable:SetCallback(update_visibility, true)

-- Динамическое обновление локализации при смене языка
local last_applied_lang = init_lang

local function apply_lang()
    local lang = cur_lang()
    if lang == last_applied_lang then return end
    last_applied_lang = lang

    local T = STR[lang] or STR.en
    pcall(function()
        ui.enable:ForceLocalization(T.enable)
        ui.enable:ToolTip(T.enable_tip)
        ui.smart_position:ForceLocalization(T.smart_pos)
        ui.smart_position:ToolTip(T.smart_pos_tip)
        ui.spark_ranged:ForceLocalization(T.spark_ranged)
        ui.spark_ranged:ToolTip(T.spark_ranged_tip)
        ui.priority_flagbearer:ForceLocalization(T.priority_flag)
        ui.priority_flagbearer:ToolTip(T.priority_flag_tip)
        ui.attack_lead:ForceLocalization(T.attack_lead)
        ui.attack_lead:ToolTip(T.attack_lead_tip)
        ui.draw_target:ForceLocalization(T.draw_target)
        ui.draw_target:ToolTip(T.draw_target_tip)
    end)
end

pcall(function()
    local lang_w = Menu.Find("SettingsHidden", "", "", "", "Main", "Language")
    if lang_w then
        lang_w:SetCallback(function()
            last_applied_lang = nil
            apply_lang()
        end)
    end
end)
--#endregion

--#region Runtime State
local last_spark_time = 0
local last_field_time = 0
local last_attack_time = 0
local last_move_time = 0
local last_spell_cast_time = 0
local last_ordered_target = nil
local last_hero_action_time = 0
local is_holding_fire = false
local is_in_attack_position = false
local active_priority_target = nil

-- Таблицы отслеживания плана урона по крипам
local spark_placed_time = {}   -- [creep] = timestamp
local attacks_delivered = {}   -- [creep] = count
local attack_in_progress = nil -- { target = creep, start_time = timestamp, swing_time = number }

local creep_health_cache = {}
local active_particle = nil
local last_particle_target = nil
--#endregion

--#region Helper Functions
--- Находит живого клона Арк Вардена
---@param my_hero CHero
---@return CNPC?
local function GetClone(my_hero)
    if not my_hero then return nil end

    local tempest_double_ability = NPC.GetAbility(my_hero, "arc_warden_tempest_double")
    if tempest_double_ability then
        local clone = CustomEntities.GetTempestDouble(tempest_double_ability)
        if clone and Entity.IsAlive(clone) and not Entity.IsDormant(clone) then
            return clone
        end
    end

    local heroes = Heroes.GetAll()
    if heroes then
        for _, hero in ipairs(heroes) do
            if hero ~= my_hero
                and NPC.GetUnitName(hero) == "npc_dota_hero_arc_warden"
                and Entity.GetOwner(hero) == my_hero
                and Entity.IsAlive(hero)
                and not Entity.IsDormant(hero)
                and not NPC.IsIllusion(hero) then
                return hero
            end
        end
    end

    return nil
end

--- Сканирует пачку вражеских крипов на широкой дистанции (до 1800)
---@param clone CNPC
---@param my_team integer
---@return CNPC[] ranged_creeps, CNPC? flagbearer_creep, boolean any_lane_creep
local function GetWaveCreeps(clone, my_team)
    local clone_origin = Entity.GetAbsOrigin(clone)
    local search_radius = 1800

    local ranged_creeps = {}
    local flagbearer_creep = nil
    local any_lane_creep = false
    local min_dist_flag = 999999

    local creeps = NPCs.GetAll(Enum.UnitTypeFlags.TYPE_LANE_CREEP)
    if not creeps then return ranged_creeps, nil, false end

    for _, c in ipairs(creeps) do
        if c and Entity.IsAlive(c) and not Entity.IsDormant(c) and not NPC.IsWaitingToSpawn(c) then
            if Entity.GetTeamNum(c) ~= my_team and NPC.IsLaneCreep(c) then
                local c_pos = Entity.GetAbsOrigin(c)
                local dist = (c_pos - clone_origin):Length2D()

                if dist <= search_radius then
                    any_lane_creep = true
                    local name = NPC.GetUnitName(c) or ""
                    local is_siege = string.find(name, "siege") ~= nil or NPC.IsAncient(c)

                    -- Проверка на дальника
                    local is_ranged = (string.find(name, "ranged") ~= nil or (NPC.IsRanged(c) and not is_siege))
                    if is_ranged then
                        table.insert(ranged_creeps, c)
                    end

                    -- Проверка на знаменосца
                    local is_flagbearer = NPC.HasModifier(c, "modifier_creep_flagbearer")
                        or (string.find(name, "flagbearer") ~= nil)
                    if is_flagbearer and dist < min_dist_flag then
                        flagbearer_creep = c
                        min_dist_flag = dist
                    end
                end
            end
        end
    end

    table.sort(ranged_creeps, function(a, b)
        local d1 = (Entity.GetAbsOrigin(a) - clone_origin):Length2D()
        local d2 = (Entity.GetAbsOrigin(b) - clone_origin):Length2D()
        return d1 < d2
    end)

    return ranged_creeps, flagbearer_creep, any_lane_creep
end

--- Калькулятор чистого магического урона Spark Wraith
---@param clone CNPC
---@param spark CAbility
---@param creep CNPC
---@return number effective_spark_damage
local function CalculateSparkDamageOnCreep(clone, spark, creep)
    if not clone or not spark or not creep then return 0 end

    local lvl = Ability.GetLevel(spark) or 1
    if lvl == 0 then return 0 end

    -- 1. Базовый урон способности
    -- В KV Dota 2 это AbilityValues.spark_damage_base или spark_damage
    local base_damage = Ability.GetLevelSpecialValueFor(spark, "spark_damage_base", lvl) or 0
    if base_damage == 0 then
        base_damage = Ability.GetLevelSpecialValueFor(spark, "spark_damage", lvl) or 0
    end
    if base_damage == 0 then
        base_damage = Ability.GetDamage(spark) or 0
    end
    if base_damage == 0 then
        local damages = { 100, 170, 240, 310 }
        base_damage = damages[lvl] or 310
    end

    -- 2. Проверка таланта 25 уровня (+240 Spark Wraith Damage)
    local talent = NPC.GetAbility(clone, "special_bonus_unique_arc_warden_4")
        or NPC.GetAbility(clone, "special_bonus_unique_arc_warden")
        or NPC.GetAbility(clone, "special_bonus_unique_arc_warden_spark_wraith_damage")
    if talent and Ability.GetLevel(talent) > 0 and base_damage <= 310 then
        local bonus = Ability.GetLevelSpecialValueFor(talent, "value") or 240
        base_damage = base_damage + bonus
    end

    -- 3. Spell Amplification (усиление магии)
    local spell_amp = 1.0
    if NPC.GetBaseSpellAmp then
        spell_amp = 1.0 + (NPC.GetBaseSpellAmp(clone) or 0)
    end

    -- 4. Магическое сопротивление крипа
    -- У линейных крипов 0% базового резиста магии (множитель 1.0).
    local magic_mult = 1.0
    if NPC.GetMagicalArmorDamageMultiplier then
        magic_mult = NPC.GetMagicalArmorDamageMultiplier(creep) or 1.0
    end

    return base_damage * spell_amp * magic_mult
end

--- Рассчитывает план убийства крипа (сколько тычек нужно в дополнение к спарку)
---@param clone CNPC
---@param spark CAbility?
---@param creep CNPC
---@param has_spark boolean?
---@return table plan
local function GetCreepKillPlan(clone, spark, creep, has_spark)
    local current_hp = Entity.GetHealth(creep)
    local spark_dmg = spark and CalculateSparkDamageOnCreep(clone, spark, creep) or 0

    local min_damage = NPC.GetTrueDamage(clone) or 0
    local armor_mult = NPC.GetArmorDamageMultiplier(creep) or 1.0
    local attack_dmg = min_damage * armor_mult
    if attack_dmg <= 0 then attack_dmg = 50 end

    -- Урон Спарка учитываем только если он уже поставлен или реально готов к применению
    local can_use_spark = has_spark or (spark and Ability.IsCastable(spark, NPC.GetMana(clone)))
    local planned_spark_dmg = can_use_spark and spark_dmg or 0

    local remaining_after_spark = current_hp - planned_spark_dmg
    local attacks_needed = 0
    if remaining_after_spark > 0 then
        attacks_needed = math.ceil(remaining_after_spark / attack_dmg)
    end

    return {
        current_hp = current_hp,
        spark_dmg = spark_dmg,
        attack_dmg = attack_dmg,
        remaining_after_spark = remaining_after_spark,
        attacks_needed = attacks_needed,
        spark_only_kills = has_spark and (remaining_after_spark <= 0),
    }
end

--- Рассчитывает точные параметры атаки и ластхита
---@param clone CNPC
---@param target CNPC
---@return table?
local function CalculateLastHit(clone, target)
    if not clone or not target or not Entity.IsAlive(target) then
        return nil
    end

    local min_damage = NPC.GetTrueDamage(clone) or 0
    local armor_mult = NPC.GetArmorDamageMultiplier(target) or 1.0
    local true_damage = min_damage * armor_mult

    local anim_point = NPC.GetAttackAnimPoint(clone) or 0.3
    local attack_speed = NPC.GetAttackSpeed(clone) or 1.0
    if attack_speed <= 0 then attack_speed = 1.0 end

    local swing_time = anim_point / attack_speed
    local proj_speed = NPC.GetAttackProjectileSpeed(clone) or 900
    if proj_speed <= 0 then proj_speed = 900 end

    local clone_pos = Entity.GetAbsOrigin(clone)
    local target_pos = Entity.GetAbsOrigin(target)
    local distance = (target_pos - clone_pos):Length2D()
    local flight_time = distance / proj_speed

    local latency = 0.03
    if NetChannel and NetChannel.GetAvgLatency then
        latency = NetChannel.GetAvgLatency(Enum.Flow.FLOW_OUTGOING) or 0.03
    end

    local total_time = swing_time + flight_time + latency
    local current_hp = Entity.GetHealth(target)

    return {
        damage = true_damage,
        current_hp = current_hp,
        total_time = total_time,
        swing_time = swing_time,
        distance = distance,
        is_lethal = current_hp <= true_damage,
    }
end

--- Отслеживает динамику снижения HP крипа от союзных крипов (DPS входящего урона)
---@param target CNPC
---@param cur_time number
---@return number dps
local function UpdateCreepDPS(target, cur_time)
    local hp = Entity.GetHealth(target)
    local record = creep_health_cache[target]
    if not record then
        creep_health_cache[target] = { last_hp = hp, last_time = cur_time, dps = 0 }
        return 0
    end

    local dt = cur_time - record.last_time
    if dt >= 0.05 then
        local dhp = record.last_hp - hp
        if dhp > 0 then
            local instant_dps = dhp / dt
            record.dps = record.dps * 0.4 + instant_dps * 0.6
        elseif dhp < 0 then
            record.dps = 0
        else
            record.dps = record.dps * 0.8
        end
        record.last_hp = hp
        record.last_time = cur_time
    end
    return record.dps
end

--- Отдает приказ клону атаковать цель без сбития анимации
---@param clone CNPC
---@param player CPlayer
---@param target CNPC
---@param cur_time number
local function IssueCloneAttack(clone, player, target, cur_time)
    if not target or not Entity.IsAlive(target) then return end

    is_holding_fire = false

    if NPC.IsAttacking(clone) and last_ordered_target == target then
        return
    end

    if last_ordered_target == target and (cur_time - last_attack_time) < 0.12 then
        return
    end

    local anim_point = NPC.GetAttackAnimPoint(clone) or 0.3
    local attack_speed = NPC.GetAttackSpeed(clone) or 1.0
    if attack_speed <= 0 then attack_speed = 1.0 end
    local swing_time = anim_point / attack_speed

    attack_in_progress = {
        target = target,
        start_time = cur_time,
        swing_time = swing_time
    }

    Player.PrepareUnitOrders(
        player,
        Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET,
        target,
        Vector(0, 0, 0),
        nil,
        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
        clone,
        false,
        false,
        false,
        true,
        ORDER_IDENTIFIER
    )

    last_ordered_target = target
    last_attack_time = cur_time
end

--- Задерживает атаку клона в опасной зоне (Hold Position), чтобы не сбить ХП до стила союзниками
---@param clone CNPC
---@param player CPlayer
---@param cur_time number
local function HoldCloneAttack(clone, player, cur_time)
    if is_holding_fire then return end

    Player.PrepareUnitOrders(
        player,
        Enum.UnitOrder.DOTA_UNIT_ORDER_HOLD_POSITION,
        nil,
        Vector(0, 0, 0),
        nil,
        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
        clone,
        false,
        false,
        false,
        true,
        ORDER_IDENTIFIER
    )
    is_holding_fire = true
    last_attack_time = cur_time
end

--- Плавно ведет клона на дистанцию атаки к цели
---@param clone CNPC
---@param player CPlayer
---@param move_to_pos Vector
---@param cur_time number
local function MoveCloneTowards(clone, player, move_to_pos, cur_time)
    if (cur_time - last_move_time) < 0.22 then return end

    Player.PrepareUnitOrders(
        player,
        Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION,
        nil,
        move_to_pos,
        nil,
        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
        clone,
        false,
        false,
        false,
        true,
        ORDER_IDENTIFIER
    )
    is_holding_fire = false
    last_move_time = cur_time
end

--- Управляет отрисовкой круга под фокус-целью
---@param target CNPC?
local function UpdateVisualRing(target)
    if not ui.draw_target:Get() or not target or not Entity.IsAlive(target) then
        if active_particle then
            Particle.Destroy(active_particle)
            active_particle = nil
            last_particle_target = nil
        end
        return
    end

    if last_particle_target ~= target then
        if active_particle then
            Particle.Destroy(active_particle)
            active_particle = nil
        end

        active_particle = Particle.Create("particles/ui_mouseactions/drag_selected_ring.vpcf", Enum.ParticleAttachment.PATTACH_ABSORIGIN_FOLLOW, target)
        local is_flag = NPC.HasModifier(target, "modifier_creep_flagbearer")
        local color = is_flag and Vector(255, 205, 30) or Vector(0, 190, 255)
        Particle.SetControlPoint(active_particle, 1, color)
        Particle.SetControlPoint(active_particle, 2, Vector(65, 255, 255))
        last_particle_target = target
    end
end
--#endregion

local WavePusher = {}

---@param data table
function WavePusher.OnPrepareUnitOrders(data)
    if not ui.enable:Get() then return true end
    if not data or not data.npc then return true end

    local my_hero = Heroes.GetLocal()
    if not my_hero or NPC.GetUnitName(my_hero) ~= "npc_dota_hero_arc_warden" then return true end

    local clone = GetClone(my_hero)
    if not clone or data.npc ~= clone then return true end

    local cur_time = os.clock()

    -- 1. Если приказ отдан нашим аддоном — безоговорочно разрешаем
    if data.identifier == ORDER_IDENTIFIER then
        return true
    end

    -- 2. Если игрок вручную управляет клоном (выделил и кликнул) — не блокируем!
    if data.orderIssuer == Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_SELECTED_UNITS then
        last_hero_action_time = cur_time
        return true
    end

    -- 3. Если базовый скрипт атакует или кастует в героя — это геройское комбо!
    if data.target and NPC.IsHero(data.target) then
        last_hero_action_time = cur_time
        return true
    end

    -- 4. Если недавно велся бой с героем, не вмешиваемся
    if (cur_time - last_hero_action_time) < 1.8 then
        return true
    end

    -- 5. Текущая приоритетная цель аддона
    local target = (active_priority_target and Entity.IsAlive(active_priority_target)) and active_priority_target or nil
    -- Если активной цели нет (все дальники и знаменосец зачищены) — полностью разрешаем базовый пуш!
    if not target then
        return true
    end

    -- 6. Перехват способностей пуша
    if data.ability then
        local ab_name = Ability.GetName(data.ability) or ""

        -- SPARK WRAITH: ПРИНУДИТЕЛЬНО отменяем спарки под милишников и ставим строго под цель!
        if ab_name == "arc_warden_spark_wraith" or ab_name == "arc_warden_spark_wraith_tempest" then
            if ui.spark_ranged:Get() and target and Entity.IsAlive(target) then
                if is_in_attack_position then
                    Player.PrepareUnitOrders(
                        Players.GetLocal(),
                        Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION,
                        nil,
                        Entity.GetAbsOrigin(target),
                        data.ability,
                        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                        clone,
                        false,
                        false,
                        false,
                        true,
                        ORDER_IDENTIFIER
                    )
                    last_spark_time = cur_time
                    last_spell_cast_time = cur_time
                    spark_placed_time[target] = cur_time
                end
                -- Полностью отменяем спарк базового чита не туда
                return false
            end
            return true
        end

        -- MAGNETIC FIELD: не даем ставить купол на бегу, а в позиции ставим строго под клон!
        if ab_name == "arc_warden_magnetic_field" or ab_name == "arc_warden_magnetic_field_tempest" then
            if ui.smart_position:Get() and target then
                if is_in_attack_position then
                    Player.PrepareUnitOrders(
                        Players.GetLocal(),
                        Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION,
                        nil,
                        Entity.GetAbsOrigin(clone),
                        data.ability,
                        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                        clone,
                        false,
                        false,
                        false,
                        true,
                        ORDER_IDENTIFIER
                    )
                    last_field_time = cur_time
                    last_spell_cast_time = cur_time
                end
                -- Полностью отменяем базовый купол, чтобы он не ставился мимо клона!
                return false
            end
            return true
        end

        last_hero_action_time = cur_time
        return true
    end

    -- 7. БЛОКИРОВКА ПЕРЕДВИЖЕНИЙ БАЗОВОГО ЧИТА
    -- Не даем базовому чита сбивать наш подход к дальнику или выводить клон из купола!
    if data.order == Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION or data.order == Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_TARGET then
        return false
    end

    -- 8. БЛОКИРОВКА ATTACK_MOVE
    -- Атака по площади заставит клон остановиться и бить первого встречного милишника
    if data.order == Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_MOVE then
        return false
    end

    -- 9. БЛОКИРОВКА АТАК ПО МИЛИШНИКАМ
    -- Приказ базового скрипта бить милишника жестко ОТМЕНЯЕТСЯ (return false)
    if data.order == Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET and data.target and NPC.IsLaneCreep(data.target) then
        if data.target ~= target then
            return false
        end
    end

    return true
end

function WavePusher.OnUpdate()
    apply_lang()

    if not ui.enable:Get() then
        UpdateVisualRing(nil)
        active_priority_target = nil
        is_in_attack_position = false
        return
    end

    local my_hero = Heroes.GetLocal()
    if not my_hero or NPC.GetUnitName(my_hero) ~= "npc_dota_hero_arc_warden" then
        UpdateVisualRing(nil)
        return
    end

    local clone = GetClone(my_hero)
    if not clone or not Entity.IsAlive(clone) or Entity.IsDormant(clone) then
        UpdateVisualRing(nil)
        active_priority_target = nil
        is_in_attack_position = false
        return
    end

    local is_channeling = false
    if NPC.IsChannellingAbility then
        is_channeling = NPC.IsChannellingAbility(clone)
    end

    if NPC.IsStunned(clone) or is_channeling then
        UpdateVisualRing(nil)
        return
    end

    local cur_time = os.clock()

    -- Очистка кэша от умерших крипов (защита от переиспользования entity index движком)
    for c, _ in pairs(spark_placed_time) do
        if not c or not Entity.IsAlive(c) then
            spark_placed_time[c] = nil
        end
    end
    for c, _ in pairs(attacks_delivered) do
        if not c or not Entity.IsAlive(c) then
            attacks_delivered[c] = nil
        end
    end
    for c, _ in pairs(creep_health_cache) do
        if not c or not Entity.IsAlive(c) then
            creep_health_cache[c] = nil
        end
    end

    -- Не перебиваем каст способности новыми приказами (каст-поинт Arc Warden = 0.3с),
    -- иначе следующий приказ атаки или движения мгновенно прервет создание Спарка или Купола!
    if (cur_time - last_spell_cast_time) < 0.35 then
        return
    end

    -- Проверяем завершение замаха тычки (выпуск снаряда в воздух)
    if attack_in_progress then
        if not Entity.IsAlive(attack_in_progress.target) then
            attack_in_progress = nil
        elseif (cur_time - attack_in_progress.start_time) >= attack_in_progress.swing_time then
            local tgt = attack_in_progress.target
            attacks_delivered[tgt] = (attacks_delivered[tgt] or 0) + 1
            attack_in_progress = nil
        end
    end

    -- Уступаем герою при комбо
    if (cur_time - last_hero_action_time) < 1.8 then
        UpdateVisualRing(nil)
        return
    end

    local my_player = Players.GetLocal()
    local my_team = Entity.GetTeamNum(my_hero)
    local clone_origin = Entity.GetAbsOrigin(clone)
    local attack_range = NPC.GetAttackRange(clone) or 625
    local safe_attack_range = attack_range - 50

    local spark_ability = NPC.GetAbility(clone, "arc_warden_spark_wraith")
        or NPC.GetAbility(clone, "arc_warden_spark_wraith_tempest")

    -- 1. Сканируем пачку на широкой дистанции (1800)
    local ranged_creeps, flagbearer_creep, any_lane_creep = GetWaveCreeps(clone, my_team)

    if not any_lane_creep then
        UpdateVisualRing(nil)
        active_priority_target = nil
        is_in_attack_position = false
        return
    end

    -- =========================================================================
    -- ШАГ 1: Поиск незавершенного дальника по калькулятору урона
    -- =========================================================================
    local active_ranged = nil
    for _, r in ipairs(ranged_creeps) do
        if Entity.IsAlive(r) then
            local has_spark = spark_placed_time[r] and (cur_time - spark_placed_time[r]) < 3.5
            local plan = GetCreepKillPlan(clone, spark_ability, r, has_spark)
            local hits_done = attacks_delivered[r] or 0

            -- Крип считается гарантированно мертвым, если:
            -- 1. Спарк уже поставлен
            -- 2. Сделано нужное количество тычек (hits_done >= plan.attacks_needed)
            local is_guaranteed_kill = has_spark and (hits_done >= plan.attacks_needed)

            if not is_guaranteed_kill then
                active_ranged = r
                break
            end
        end
    end

    local active_flag = (flagbearer_creep and Entity.IsAlive(flagbearer_creep) and ui.priority_flagbearer:Get()) and flagbearer_creep or nil

    -- Текущая главная цель: сначала неразобранный дальник, затем знаменосец
    active_priority_target = active_ranged or active_flag

    -- Если дальники и знаменосец гарантированно убиты/разобраны — уступаем допушивать милишников
    if not active_priority_target then
        UpdateVisualRing(nil)
        is_in_attack_position = true
        return
    end

    UpdateVisualRing(active_priority_target)

    local target_pos = Entity.GetAbsOrigin(active_priority_target)
    local dist_to_target = (target_pos - clone_origin):Length2D()

    -- Проверяем, достает ли клон также до знаменосца (если знаменосец в пачке и включен)
    local can_reach_flag = true
    local flag_pos = nil
    if active_flag and active_flag ~= active_priority_target then
        flag_pos = Entity.GetAbsOrigin(active_flag)
        local dist_to_flag = (flag_pos - clone_origin):Length2D()
        if dist_to_flag > safe_attack_range then
            can_reach_flag = false
        end
    end

    -- =========================================================================
    -- ШАГ 2: ПОДХОД НА ДИСТАНЦИЮ АТАКИ К ЦЕЛЯМ (не останавливаясь на милишниках)
    -- =========================================================================
    if dist_to_target > safe_attack_range or not can_reach_flag then
        is_in_attack_position = false

        -- Если есть и дальник, и знаменосец — целимся в центр между ними, чтобы доставать до обоих
        local move_focus_pos = target_pos
        if flag_pos then
            move_focus_pos = (target_pos + flag_pos) * 0.5
        end

        local dir = clone_origin - move_focus_pos
        dir.z = 0
        local dir_len = dir:Length2D()
        if dir_len > 1 then
            dir = dir:Normalized()
        else
            dir = Vector(0, -1, 0)
        end

        local walk_to = move_focus_pos + dir * (safe_attack_range - 70)
        walk_to.z = clone_origin.z

        MoveCloneTowards(clone, my_player, walk_to, cur_time)
        return
    end

    -- Клон подошел и достает до приоритетных целей!
    is_in_attack_position = true

    -- =========================================================================
    -- ШАГ 3: СТАВИМ MAGNETIC FIELD (купол прямо под себя, только войдя в радиус!)
    -- =========================================================================
    if ui.smart_position:Get() and not NPC.IsSilenced(clone) then
        local field = NPC.GetAbility(clone, "arc_warden_magnetic_field")
            or NPC.GetAbility(clone, "arc_warden_magnetic_field_tempest")

        if field and Ability.IsCastable(field, NPC.GetMana(clone)) then
            if (cur_time - last_field_time) > 2.0 then
                Player.PrepareUnitOrders(
                    my_player,
                    Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION,
                    nil,
                    clone_origin, -- Ставим купол строго под свои ноги!
                    field,
                    Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                    clone,
                    false,
                    false,
                    false,
                    true,
                    ORDER_IDENTIFIER
                )
                last_field_time = cur_time
                last_spell_cast_time = cur_time
                return
            end
        end
    end

    local is_disarmed = NPC.HasState(clone, Enum.ModifierState.MODIFIER_STATE_DISARMED)

    -- =========================================================================
    -- ШАГ 4: ОБРАБОТКА ДАЛЬНИКА (Спарк + рассчитанное число тычек)
    -- =========================================================================
    if active_ranged then
        local has_spark = spark_placed_time[active_ranged] and (cur_time - spark_placed_time[active_ranged]) < 3.5

        -- 4.1 Ставим Спарк строго под дальника, если еще не поставили
        if not has_spark and ui.spark_ranged:Get() and not NPC.IsSilenced(clone) and spark_ability then
            if Ability.IsCastable(spark_ability, NPC.GetMana(clone)) and (cur_time - last_spark_time) > 1.2 then
                Player.PrepareUnitOrders(
                    my_player,
                    Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION,
                    nil,
                    target_pos,
                    spark_ability,
                    Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                    clone,
                    false,
                    false,
                    false,
                    true,
                    ORDER_IDENTIFIER
                )
                last_spark_time = cur_time
                last_spell_cast_time = cur_time
                spark_placed_time[active_ranged] = cur_time
                return
            end
        end

        -- 4.2 Калькулятор тычек
        local plan = GetCreepKillPlan(clone, spark_ability, active_ranged, has_spark)
        local hits_done = attacks_delivered[active_ranged] or 0

        -- Если чисто урона Спарка хватает — 0 ТЫЧЕК! Дальник уже труп
        if plan.spark_only_kills and has_spark then
            -- Мгновенно переключаемся на следующую цель
            attacks_delivered[active_ranged] = 999
            return
        end

        -- Если нужно дать тычку (или несколько):
        if not is_disarmed then
            if hits_done < plan.attacks_needed then
                -- Даем ровно столько тычек, сколько нужно
                IssueCloneAttack(clone, my_player, active_ranged, cur_time)
                return
            else
                -- Все нужные тычки уже даны! Дальник гарантированно умрет от тычек + Спарка
                -- Больше не бьем его, переходим к следующему
                return
            end
        end
        return
    end

    -- =========================================================================
    -- ШАГ 5: ОБРАБОТКА ЗНАМЕНОСЦА (все дальники уже запечатаны)
    -- =========================================================================
    if active_flag and not is_disarmed then
        local lh_data = CalculateLastHit(clone, active_flag)
        if lh_data then
            local dps = UpdateCreepDPS(active_flag, cur_time)
            local lead_sec = (ui.attack_lead:Get() or 40) / 1000.0
            local predicted_hp = lh_data.current_hp - (dps * (lh_data.total_time + lead_sec))

            -- А: Летальный порог — выстрел на поражение
            if lh_data.is_lethal or predicted_hp <= lh_data.damage then
                IssueCloneAttack(clone, my_player, active_flag, cur_time)
                return
            -- Б: Много ХП (> 2.0 тычек) — безопасно наносим урон
            elseif lh_data.current_hp > (lh_data.damage * 2.0) and predicted_hp > (lh_data.damage * 1.8) then
                IssueCloneAttack(clone, my_player, active_flag, cur_time)
                return
            -- В: Опасная зона — пауза перед ластхитом
            else
                HoldCloneAttack(clone, my_player, cur_time)
                return
            end
        end
        return
    end
end

return WavePusher
