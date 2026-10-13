--by m0rc1 and 

local VERSION = "1.0.0"
local PhoenixCombo = {}

-- ============================================================================
-- Minimalist Menu Setup
-- ============================================================================
local ui_enabled            = nil
local ui_egg_hp             = nil
local ui_enemy_radius       = nil
local ui_debug              = nil

local function SetupMenu()
    if ui_enabled ~= nil then return end

    local function group(name)
        return Menu.Find("Heroes", "Hero List", "Phoenix", "Супернова", name)
            or Menu.Create("Heroes", "Hero List", "Phoenix", "Супернова", name)
            or Menu.Find("Heroes", "Hero List", "Phoenix", name)
            or Menu.Create("Heroes", "Hero List", "Phoenix", name)
    end

    local main_grp = group("Авто-Яйцо и Духи")
    if main_grp then
        ui_enabled          = main_grp:Switch("Включить", true)
        ui_egg_hp           = main_grp:Slider("Порог каста Supernova (HP %)", 15, 35, 22)
        ui_enemy_radius     = main_grp:Slider("Радиус реакции", 1000, 1800, 1500)
    end

    local vis_grp = group("Настройки отладки")
    if vis_grp then
        ui_debug            = vis_grp:Switch("Debug инфо на экране", false)
    end
end

-- ============================================================================
-- Constants & State
-- ============================================================================
local SPIRIT_SPEED          = 900
local MAX_SPIRIT_CAST_RANGE = 1360

local STATE_IDLE            = 0
local STATE_PREPARED        = 1
local STATE_DISPATCHING     = 2
local STATE_WAITING_EGG     = 3

local current_state         = STATE_IDLE
local state_start_time      = 0
local last_launch_time      = 0
local last_egg_cast_time    = 0
local last_spirits_summon_t = 0

local flying_spirits_to     = {}
local hp_history            = {}
local incoming_dps          = 0
local time_to_death         = 99.0

-- Fonts
local font_bold, font_main
pcall(function()
    font_bold = Render.LoadFont("MuseoSansEx", Enum.FontCreate.FONTFLAG_ANTIALIAS, 700)
    font_main = Render.LoadFont("MuseoSansEx", Enum.FontCreate.FONTFLAG_ANTIALIAS, 500)
end)
if not font_bold then
    pcall(function()
        font_bold = Render.LoadFont("Segoe UI", Enum.FontCreate.FONTFLAG_ANTIALIAS, 700)
        font_main = Render.LoadFont("Segoe UI", Enum.FontCreate.FONTFLAG_ANTIALIAS, 400)
    end)
end

-- ============================================================================
-- Helpers
-- ============================================================================
local function GetVal(item)
    if not item or not item.Get then return false end
    return item:Get()
end

local function IsPhoenix(hero)
    if not hero or not Entity.IsAlive(hero) then return false end
    local name = NPC.GetUnitName(hero)
    return name and name == "npc_dota_hero_phoenix"
end

local function ClampPosition(origin, target_pos, max_dist)
    local offset_x = target_pos.x - origin.x
    local offset_y = target_pos.y - origin.y
    local dist_2d = math.sqrt(offset_x * offset_x + offset_y * offset_y)

    if dist_2d > max_dist and dist_2d > 0 then
        local ratio = max_dist / dist_2d
        return Vector(origin.x + offset_x * ratio, origin.y + offset_y * ratio, target_pos.z)
    end
    return target_pos
end

local function IssueOrder(order_type, target, pos, ability, queue)
    local my_hero = Heroes.GetLocal()
    local my_player = Players.GetLocal()
    if not my_hero or not my_player then return false end

    pcall(Player.PrepareUnitOrders,
        my_player,
        order_type,
        target,
        pos or Vector(0, 0, 0),
        ability,
        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
        my_hero,
        queue and true or false,
        false,
        false,
        true
    )
    return true
end

local function GetLaunchAbility(my_hero)
    if not my_hero then return nil end
    local ab = NPC.GetAbility(my_hero, "phoenix_launch_fire_spirit")
    if ab then return ab end

    for i = 0, 24 do
        local a = NPC.GetAbilityByIndex(my_hero, i)
        if a and Ability.GetName(a) == "phoenix_launch_fire_spirit" then
            return a
        end
    end
    return nil
end

local function IsAbilityReady(hero, ability)
    if not ability or not hero then return false end
    if Ability.GetLevel(ability) == 0 then return false end
    if Ability.GetCooldown(ability) > 0 then return false end
    if NPC.GetMana(hero) < (Ability.GetManaCost(ability) or 0) then return false end
    return true
end

local function IsHeroDisabled(hero)
    if not hero then return true end
    if NPC.IsStunned and NPC.IsStunned(hero) then return true end
    if NPC.IsSilenced and NPC.IsSilenced(hero) then return true end

    if NPC.HasModifier then
        if NPC.HasModifier(hero, "modifier_sheepstick_debuff") or
           NPC.HasModifier(hero, "modifier_lion_voodoo") or
           NPC.HasModifier(hero, "modifier_shadow_shaman_voodoo") or
           NPC.HasModifier(hero, "modifier_eul_cyclone") or
           NPC.HasModifier(hero, "modifier_stunned") or
           NPC.HasModifier(hero, "modifier_silence") then
            return true
        end
    end
    return false
end

local function HasSpiritBurnDebuff(enemy)
    if not enemy or not Entity.IsAlive(enemy) then return false end
    if not NPC.HasModifier(enemy, "modifier_phoenix_fire_spirit_burn") then return false end

    local mod = NPC.GetModifier(enemy, "modifier_phoenix_fire_spirit_burn")
    if mod and Modifier.GetDieTime then
        local rem = Modifier.GetDieTime(mod) - GameRules.GetGameTime()
        if rem <= 0.5 then return false end
    end
    return true
end

local function IsDebuffImmune(enemy)
    if not enemy then return false end
    if NPC.IsMagicImmune and NPC.IsMagicImmune(enemy) then return true end
    if NPC.HasModifier then
        return NPC.HasModifier(enemy, "modifier_black_king_bar_immune") or
               NPC.HasModifier(enemy, "modifier_juggernaut_blade_fury") or
               NPC.HasModifier(enemy, "modifier_life_stealer_rage")
    end
    return false
end

-- ============================================================================
-- Dynamic Attack Speed & Threat Evaluator
-- ============================================================================
local function CalculateTrueEggThreat(enemy, dist)
    if not enemy then return 0 end

    -- 1. Базовый расчет реальной скорости атаки
    local as = 100
    if NPC.GetAttackSpeed then
        local ok, val = pcall(NPC.GetAttackSpeed, enemy)
        if ok and type(val) == "number" and val > 0 then
            as = (val < 10) and (val * 100) or val
        end
    end

    -- 2. Активные баффы на мгновенный разгон скорости атаки (Steroids)
    local steroid_bonus = 0
    if NPC.HasModifier then
        -- Мортра под прыжком (Phantom Strike)
        if NPC.HasModifier(enemy, "modifier_phantom_assassin_phantom_strike") then
            steroid_bonus = steroid_bonus + 200
        end
        -- Урса под Overpower
        if NPC.HasModifier(enemy, "modifier_ursa_overpower") then
            steroid_bonus = steroid_bonus + 450
        end
        -- Тролль под ультом
        if NPC.HasModifier(enemy, "modifier_troll_warlord_battle_trance") then
            steroid_bonus = steroid_bonus + 300
        end
        -- Активация Mask of Madness
        if NPC.HasModifier(enemy, "modifier_item_mask_of_madness_active") then
            steroid_bonus = steroid_bonus + 130
        end
        -- Марси Unleash / ВРка Focus Fire
        if NPC.HasModifier(enemy, "modifier_marci_unleash_flurry") or
           NPC.HasModifier(enemy, "modifier_windrunner_focusfire") then
            steroid_bonus = steroid_bonus + 350
        end
    end

    local total_as = math.min(700, as + steroid_bonus)

    -- 3. Фактор дальности (Range Advantage)
    -- Дальники опаснее для яйца, так как бьют без задержки на подход
    local attack_range = (NPC.GetAttackRange and NPC.GetAttackRange(enemy)) or 150
    local range_multiplier = 1.0 + math.min(0.8, (attack_range / 1000) * 0.6)

    -- 4. Штраф за расстояние (милишник в 900 ренджах потратит 3 секунды на бег)
    local distance_penalty = 0
    if attack_range < 300 and dist > 400 then
        distance_penalty = (dist - 400) * 0.25
    end

    -- 5. Статус контроля (дизарм, стан, хекс сводят угрозу к нулю)
    local is_disabled = false
    if (NPC.IsStunned and NPC.IsStunned(enemy)) or (NPC.IsDisarmed and NPC.IsDisarmed(enemy)) then
        is_disabled = true
    end

    local threat = (total_as * range_multiplier) - distance_penalty
    if is_disabled then threat = threat - 300 end

    return math.max(10, threat), total_as
end

local function GetPredictedPosition(enemy, travel_time)
    local pos = Entity.GetAbsOrigin(enemy)
    local is_moving = false

    if NPC.IsRunning then
        local ok, r = pcall(NPC.IsRunning, enemy)
        if ok and r then is_moving = true end
    end

    if is_moving and Entity.GetRotation then
        local ok, rot = pcall(Entity.GetRotation, enemy)
        if ok and rot and rot.y then
            local yaw = math.rad(rot.y)
            local fwd = Vector(math.cos(yaw), math.sin(yaw), 0)
            local ms = (NPC.GetMoveSpeed and NPC.GetMoveSpeed(enemy)) or 300
            return pos + fwd * (ms * travel_time)
        end
    end
    return pos
end

-- ============================================================================
-- Incoming DPS Tracker
-- ============================================================================
local function UpdateIncomingDamageTracker(cur_hp)
    local now = GameRules.GetGameTime()
    table.insert(hp_history, { t = now, hp = cur_hp })

    while #hp_history > 0 and (now - hp_history[1].t > 1.2) do
        table.remove(hp_history, 1)
    end

    if #hp_history >= 2 then
        local dt = now - hp_history[1].t
        local loss = hp_history[1].hp - cur_hp
        if dt > 0.12 and loss > 0 then
            incoming_dps = loss / dt
        else
            incoming_dps = incoming_dps * 0.85
        end
    else
        incoming_dps = 0
    end

    time_to_death = (incoming_dps > 30) and (cur_hp / incoming_dps) or 99.0
end

-- ============================================================================
-- Dynamic Target Scanner
-- ============================================================================
local function GetRankedEnemyTargets(my_hero, scan_radius)
    local now = GameRules.GetGameTime()
    local hero_pos = Entity.GetAbsOrigin(my_hero)
    local my_team  = Entity.GetTeamNum(my_hero)
    local all_heroes = Heroes.GetAll() or {}
    local targets = {}

    for i = 1, #all_heroes do
        local e = all_heroes[i]
        if e and Entity.IsAlive(e) and not Entity.IsDormant(e) and (Entity.GetTeamNum(e) ~= my_team) then
            if not (NPC.IsIllusion and NPC.IsIllusion(e)) then
                local e_pos = Entity.GetAbsOrigin(e)
                local dist = (e_pos - hero_pos):Length2D()

                if dist <= scan_radius then
                    local e_idx = (Entity.GetIndex and Entity.GetIndex(e)) or tostring(e)
                    local name = NPC.GetUnitName(e) or ""

                    local has_burn = HasSpiritBurnDebuff(e)
                    local has_inflight = (flying_spirits_to[e_idx] and flying_spirits_to[e_idx] > now) or false
                    local is_immune = IsDebuffImmune(e)

                    local threat_score, display_as = CalculateTrueEggThreat(e, dist)

                    -- Враг в БКБ не может быть замедлен духом
                    local needs_spirit = (not has_burn) and (not has_inflight) and (not is_immune)

                    table.insert(targets, {
                        ent = e,
                        idx = e_idx,
                        name = name,
                        dist = dist,
                        pos = e_pos,
                        as = display_as,
                        priority = threat_score,
                        needs_spirit = needs_spirit,
                        has_burn = has_burn,
                        has_inflight = has_inflight,
                        is_immune = is_immune
                    })
                end
            end
        end
    end

    table.sort(targets, function(a, b)
        if a.needs_spirit ~= b.needs_spirit then
            return a.needs_spirit
        end
        return a.priority > b.priority
    end)

    return targets
end

-- ============================================================================
-- Main Loop (Zero-Config Engine)
-- ============================================================================
function PhoenixCombo.OnUpdate()
    SetupMenu()

    if not Engine.IsInGame() or not GetVal(ui_enabled) then return end

    local my_hero = Heroes.GetLocal()
    if not IsPhoenix(my_hero) then
        current_state = STATE_IDLE
        flying_spirits_to = {}
        return
    end

    if NPC.HasModifier(my_hero, "modifier_phoenix_supernova_hiding") then
        current_state = STATE_IDLE
        flying_spirits_to = {}
        return
    end

    local now = GameRules.GetGameTime()
    local supernova = NPC.GetAbility(my_hero, "phoenix_supernova")
    local egg_ready = supernova and (Ability.GetLevel(supernova) > 0) and IsAbilityReady(my_hero, supernova)

    local cur_hp = Entity.GetHealth(my_hero)
    local max_hp = Entity.GetMaxHealth(my_hero)
    local hp_pct = (cur_hp / max_hp) * 100

    -- Умный автоматический расчет вспомогательных порогов от базового HP яйца
    local egg_hp_threshold   = GetVal(ui_egg_hp) or 22
    local prep_hp_threshold  = math.min(75, egg_hp_threshold + 22)
    local panic_hp_threshold = math.max(4, math.floor(egg_hp_threshold * 0.35))
    local scan_radius        = GetVal(ui_enemy_radius) or 1500

    UpdateIncomingDamageTracker(cur_hp)

    if IsHeroDisabled(my_hero) then
        current_state = STATE_IDLE
        return
    end

    local ranked_enemies = GetRankedEnemyTargets(my_hero, scan_radius)
    local spirits_base   = NPC.GetAbility(my_hero, "phoenix_fire_spirits")
    local launch_ability = GetLaunchAbility(my_hero)
    local has_spirits    = NPC.HasModifier(my_hero, "modifier_phoenix_fire_spirit_count")
    local can_summon     = spirits_base and IsAbilityReady(my_hero, spirits_base)
    local is_summoning   = (now - last_spirits_summon_t < 0.25)

    -- Главная угроза драки (топ по расчету AS и опасности)
    local top_threat = (#ranked_enemies > 0 and ranked_enemies[1].needs_spirit) and ranked_enemies[1] or nil

    -- ========================================================================
    -- 1. УМНЫЙ АВТО-ДЕБАФФ В БОЮ
    -- Если духи уже кружатся — они работают по самой опасной цели драки
    -- ========================================================================
    if has_spirits and launch_ability and top_threat and (now - last_launch_time >= 0.08) then
        local travel_time = top_threat.dist / SPIRIT_SPEED
        local aim_pos = GetPredictedPosition(top_threat.ent, travel_time)
        aim_pos = ClampPosition(Entity.GetAbsOrigin(my_hero), aim_pos, MAX_SPIRIT_CAST_RANGE)

        IssueOrder(Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION, nil, aim_pos, launch_ability, false)
        last_launch_time = now
        flying_spirits_to[top_threat.idx] = now + travel_time + 0.15

        if current_state ~= STATE_DISPATCHING and current_state ~= STATE_WAITING_EGG then
            return
        end
    end

    if not egg_ready then
        current_state = STATE_IDLE
        return
    end

    -- ========================================================================
    -- 2. ВЫЖИДАНИЕ ВЫЛЕТА СНАРЯДА (80 мс) ПЕРЕД СУПЕРНОВОЙ
    -- ========================================================================
    if current_state == STATE_WAITING_EGG then
        if (now - last_launch_time >= 0.08) then
            if now - last_egg_cast_time >= 0.04 then
                IssueOrder(Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET, nil, nil, supernova, false)
                last_egg_cast_time = now
            end
        end
        if now - state_start_time > 1.2 then
            current_state = STATE_IDLE
        end
        return
    end

    -- ========================================================================
    -- 3. ЭКСТРЕННЫЙ СЕЙВ (PANIC)
    -- ========================================================================
    local is_absolute_critical = (hp_pct <= 3.5) or (time_to_death <= 0.08 and incoming_dps > 250)
    local is_panic = (hp_pct <= panic_hp_threshold) or (time_to_death <= 0.20 and incoming_dps > 200)

    if is_panic then
        if has_spirits and launch_ability and top_threat then
            local travel_time = top_threat.dist / SPIRIT_SPEED
            local aim_pos = GetPredictedPosition(top_threat.ent, travel_time)
            aim_pos = ClampPosition(Entity.GetAbsOrigin(my_hero), aim_pos, MAX_SPIRIT_CAST_RANGE)

            IssueOrder(Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION, nil, aim_pos, launch_ability, false)
            last_launch_time = now
            flying_spirits_to[top_threat.idx] = now + travel_time + 0.15

            current_state = STATE_WAITING_EGG
            state_start_time = now
            return
        end

        if top_threat and can_summon and not is_absolute_critical then
            IssueOrder(Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET, nil, nil, spirits_base, false)
            last_spirits_summon_t = now
            current_state = STATE_DISPATCHING
            state_start_time = now
            return
        end

        IssueOrder(Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET, nil, nil, supernova, false)
        current_state = STATE_WAITING_EGG
        state_start_time = now
        last_egg_cast_time = now
        return
    end

    -- ========================================================================
    -- 4. FSM
    -- ========================================================================
    if current_state == STATE_IDLE then
        if hp_pct <= egg_hp_threshold or time_to_death <= 1.0 then
            current_state = STATE_DISPATCHING
            state_start_time = now
        elseif (hp_pct <= prep_hp_threshold or incoming_dps > 70) and not has_spirits then
            if can_summon then
                IssueOrder(Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET, nil, nil, spirits_base, false)
                last_spirits_summon_t = now
                current_state = STATE_PREPARED
                state_start_time = now
            end
        end

    elseif current_state == STATE_PREPARED then
        if hp_pct <= egg_hp_threshold or time_to_death <= 1.0 then
            current_state = STATE_DISPATCHING
            state_start_time = now
        end

    elseif current_state == STATE_DISPATCHING then
        if not has_spirits and can_summon then
            IssueOrder(Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET, nil, nil, spirits_base, false)
            last_spirits_summon_t = now
            last_launch_time = now
            return
        end

        if is_summoning and not has_spirits then return end

        local time_in_dispatch = now - state_start_time
        local max_window = (top_threat ~= nil) and 1.0 or 0.7

        if (top_threat == nil) or (not has_spirits and not can_summon and not is_summoning) or (time_in_dispatch > max_window) then
            if top_threat and has_spirits and launch_ability then
                local travel_time = top_threat.dist / SPIRIT_SPEED
                local aim_pos = GetPredictedPosition(top_threat.ent, travel_time)
                aim_pos = ClampPosition(Entity.GetAbsOrigin(my_hero), aim_pos, MAX_SPIRIT_CAST_RANGE)

                IssueOrder(Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION, nil, aim_pos, launch_ability, false)
                last_launch_time = now
                flying_spirits_to[top_threat.idx] = now + travel_time + 0.15
            end

            current_state = STATE_WAITING_EGG
            state_start_time = now
            return
        end

        if launch_ability and (now - last_launch_time >= 0.08) then
            local travel_time = top_threat.dist / SPIRIT_SPEED
            local aim_pos = GetPredictedPosition(top_threat.ent, travel_time)
            aim_pos = ClampPosition(Entity.GetAbsOrigin(my_hero), aim_pos, MAX_SPIRIT_CAST_RANGE)

            IssueOrder(Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION, nil, aim_pos, launch_ability, false)
            last_launch_time = now
            flying_spirits_to[top_threat.idx] = now + travel_time + 0.15
        end
    end
end

-- ============================================================================
-- Clean Debug Overlay
-- ============================================================================
function PhoenixCombo.OnDraw()
    if not ui_debug or not GetVal(ui_debug) then return end
    if not Engine.IsInGame() or not GetVal(ui_enabled) then return end

    local my_hero = Heroes.GetLocal()
    if not IsPhoenix(my_hero) then return end

    local hero_pos = Entity.GetAbsOrigin(my_hero)
    local s_pos, vis = hero_pos:ToScreen()
    if not vis or not s_pos then return end

    local font_b = font_bold or Render.LoadFont("Segoe UI", 12, Enum.FontCreate.FONTFLAG_ANTIALIAS, 700)
    local font_m = font_main or Render.LoadFont("Segoe UI", 11, Enum.FontCreate.FONTFLAG_ANTIALIAS, 400)

    local status_text = "AUTO-EGG: READY"
    local status_col  = Color(0, 255, 128, 255)
    if current_state == STATE_PREPARED then
        status_text = "SPIRITS READY"
        status_col  = Color(255, 215, 0, 255)
    elseif current_state == STATE_DISPATCHING then
        status_text = "DISPATCHING SPIRITS"
        status_col  = Color(255, 60, 60, 255)
    elseif current_state == STATE_WAITING_EGG then
        status_text = "CASTING EGG..."
        status_col  = Color(255, 120, 0, 255)
    end

    local dps_str = string.format("DPS: %.0f | TTD: %.1fs", incoming_dps, math.min(9.9, time_to_death))
    Render.FilledRect(s_pos + Vec2(-70, 28), s_pos + Vec2(70, 62), Color(16, 18, 24, 220), 4)
    Render.Rect(s_pos + Vec2(-70, 28), s_pos + Vec2(70, 62), status_col, 4, nil, 1)

    Render.Text(font_b, 11, status_text, s_pos + Vec2(-64, 32), status_col)
    Render.Text(font_m, 11, dps_str, s_pos + Vec2(-64, 46), Color(200, 205, 215, 255))

    local enemies = GetRankedEnemyTargets(my_hero, GetVal(ui_enemy_radius) or 1500)
    for idx = 1, #enemies do
        local node = enemies[idx]
        local e_screen, e_vis = node.pos:ToScreen()
        if e_vis and e_screen then
            local tag = string.format("#%d [%.0f AS]", idx, node.as)
            local tag_col = (idx == 1) and Color(255, 50, 50, 255) or Color(200, 200, 200, 255)

            if node.is_immune then
                tag = tag .. " [BKB/IMMUNE]"
                tag_col = Color(255, 215, 0, 255)
            elseif node.has_burn then
                tag = tag .. " [SLOWED]"
                tag_col = Color(80, 255, 120, 255)
            end

            Render.Text(font_b, 11, tag, e_screen - Vec2(26, 45), tag_col)
        end
    end
end

SetupMenu()

return PhoenixCombo