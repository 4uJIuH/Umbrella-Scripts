local m = {}
m.ui = {}

local main_tab = Menu.Create("General", "Utility", "kotl_illuminate")
local font = Render.LoadFont("Arial", 0, 700)

local channel_start_time = nil
local was_channeling     = false
local last_update_time   = 0
local kill_triggered     = false
local last_fire_time     = -10
local FIRE_COOLDOWN      = 3.5

-- Spirit Form channel tracking (IsChannellingAbility returns false in SF,
-- detect via ill_rdy transition true→false when player presses Q)
local sf_channel_start = nil
local sf_was_ill_rdy   = true

local ILLUMINATE = "keeper_of_the_light_illuminate"

-- ═══════════════════════════════════════════════════════════════════
-- Все значения взяты из pak01_dir.vpk:
-- scripts/npc/heroes/npc_dota_hero_keeper_of_the_light.txt
-- scripts/npc/items.txt
-- ═══════════════════════════════════════════════════════════════════

-- Illuminate ("speed" "900", "range" "1550", "radius" "400", "max_channel_time" "3")
local BEAM_SPEED       = 900
local BEAM_RADIUS      = 400
local BEAM_RANGE       = 1550
local MAX_CHANNEL       = 3.0

-- "total_damage" { "value" "185 290 395 500" }
local TOTAL_DMG = { 185, 290, 395, 500 }

-- Dagon: "damage" "400 500 600 700 800", "AbilityCastRange" "640", "cast_range_bonus" "60 90 120 150 180"
local DAGON_DMG   = { 400, 500, 600, 700, 800 }
local DAGON_BONUS = {  60,  90, 120, 150, 180 }
local DAGON_BASE_RANGE = 640

-- Kaya items: "spell_amp" из items.txt
-- item_kaya = 10, item_kaya_and_sange = 12, item_yasha_and_kaya = 12
local SPELL_AMP_ITEMS = {
    item_kaya           = 0.10,
    item_kaya_and_sange = 0.12,
    item_yasha_and_kaya = 0.12,
}

-- Spirit Vessel: "enemy_hp_drain" "4" (% HP/сек), "duration" "8.0"
-- Алли-бафф: modifier_item_spirit_vessel_heal (подтверждено GhostyPowa.lua)
-- Enemy-дебафф: modifier_item_spirit_vessel_damage (паттерн по аналогии с modifier_item_urn_of_shadows_damage)
-- ПРОВЕРИТЬ в игре через дамп модификаторов если не работает
local VESSEL_DRAIN_PCT  = 0.04
local VESSEL_DURATION   = 8.0
local VESSEL_ENEMY_MOD  = "modifier_item_spirit_vessel_damage"

-- Ethereal Blade debuff: modifier_item_ethereal_blade_ethereal (подтверждено GhostyPowa.lua line 572)
-- Amp: +40% к магическому урону — стандартное значение движка Dota 2
-- ethereal_damage_bonus "-30" в items.txt относится к физ. урону (цель теряет -30 физ. брони)
local ETHEREAL_MOD       = "modifier_item_ethereal_blade_ethereal"
local ETHEREAL_MAGIC_AMP = 0.40

-- Veil of Discord: снижает магосопру цели на 25% на 16 сек
-- modifier name из items.txt pattern
local VEIL_MOD          = "modifier_item_veil_of_discord_debuff"
local VEIL_MAGIC_SHRED  = 0.25  -- снижение магосопру = урон растёт

-- Radiant Bind: второй дамажащий скилл КОТЛА (КД отслеживается KS системой)
local RADIANT_BIND = "keeper_of_the_light_radiant_bind"

local g = main_tab and main_tab:Create("KOTL"):Create("Auto Illuminate")
if g then
    m.ui.enable       = g:Switch("Авто-отпуск Illuminate", true)
    m.ui.use_dagon    = g:Switch("Учитывать Dagon", true)
    m.ui.use_vessel   = g:Switch("Учитывать Vessel", true)
    m.ui.use_ethereal     = g:Switch("Учитывать Ethereal Blade", true)
    m.ui.use_veil         = g:Switch("Учитывать Veil of Discord", true)
    m.ui.use_radiant_bind = g:Switch("Учитывать Radiant Bind", true)
    m.ui.buffer           = g:Slider("Запас урона (%)", 0, 50, 0, "%d%%")
    m.ui.min_channel      = g:Slider("Мин. канал (мс)", 0, 2000, 200, "%d мс")
end

-- ─── helpers ─────────────────────────────────────────────────────────────────

-- Перпендикуляр от точки до луча + дистанция вдоль луча
local function PointToRay(point, origin, ray_dir)
    local dx = point.x - origin.x
    local dy = point.y - origin.y
    local fwd  = dx * ray_dir.x + dy * ray_dir.y
    local perp = math.abs(dx * ray_dir.y - dy * ray_dir.x)
    return perp, fwd
end

local function GetFacingDir(hero)
    if Entity.GetForward then
        local fwd = Entity.GetForward(hero)
        if fwd then
            return { x = fwd.x, y = fwd.y }
        end
    end
    if Entity.GetAngles then
        local ang = Entity.GetAngles(hero)
        if ang then
            local yaw = ang.y * math.pi / 180.0
            return { x = math.cos(yaw), y = math.sin(yaw) }
        end
    end
    return { x = 1, y = 0 }
end

-- ─── расчёт урона ─────────────────────────────────────────────────────────────

-- Illuminate: total_damage * (elapsed / max_channel_time)
-- Талант special_bonus_unique_keeper_of_the_light: +200 к total_damage
local function GetIlluminateDamage(hero, elapsed)
    local ability = NPC.GetAbility(hero, ILLUMINATE)
    if not ability then return 0 end

    elapsed = math.min(elapsed, MAX_CHANNEL)

    local total = Ability.GetLevelSpecialValueFor(ability, "total_damage")
    if not total or total <= 0 then
        local lvl = math.max(1, math.min(Ability.GetLevel(ability) or 1, 4))
        total = TOTAL_DMG[lvl]
    end

    local talent = NPC.GetAbility(hero, "special_bonus_unique_keeper_of_the_light")
    if talent and Ability.GetLevel(talent) > 0 then
        total = total + 200
    end

    return total * (elapsed / MAX_CHANNEL)
end

-- Dagon: возвращает (item, dmg) если готов и цель в радиусе, иначе (nil, 0)
local function FindDagon(hero, target)
    if m.ui.use_dagon and not m.ui.use_dagon:Get() then return nil, 0 end

    local hero_pos = Entity.GetAbsOrigin(hero)
    local tgt_pos  = Entity.GetAbsOrigin(target)
    if not hero_pos or not tgt_pos then return nil, 0 end
    local dist = (hero_pos - tgt_pos):Length2D()

    for lv = 5, 1, -1 do
        local name = lv == 1 and "item_dagon" or ("item_dagon_" .. lv)
        local item = NPC.GetItem(hero, name, false)
        if item and Ability.IsReady(item) then
            local range = DAGON_BASE_RANGE + DAGON_BONUS[lv]
            if dist <= range then
                return item, DAGON_DMG[lv]
            end
        end
    end
    return nil, 0
end

-- Radiant Bind: возвращает (ability, dmg) если готов и цель в радиусе
local function FindRadiantBind(hero, target)
    if m.ui.use_radiant_bind and not m.ui.use_radiant_bind:Get() then return nil, 0 end

    local rb = NPC.GetAbility(hero, RADIANT_BIND)
    if not rb or Ability.GetLevel(rb) == 0 then return nil, 0 end
    if not Ability.IsReady(rb) then return nil, 0 end

    local hero_pos = Entity.GetAbsOrigin(hero)
    local tgt_pos  = Entity.GetAbsOrigin(target)
    if not hero_pos or not tgt_pos then return nil, 0 end
    local dist = (hero_pos - tgt_pos):Length2D()

    local cast_range = Ability.GetCastRange(rb) or 900
    if dist > cast_range then return nil, 0 end

    -- Пробуем разные ключи для урона
    local dmg = Ability.GetLevelSpecialValueFor(rb, "damage") or 0
    if dmg <= 0 then dmg = Ability.GetLevelSpecialValueFor(rb, "bind_damage") or 0 end
    if dmg <= 0 then dmg = Ability.GetLevelSpecialValueFor(rb, "max_damage") or 0 end

    return rb, dmg
end

-- Spell amp от Kaya и аналогов (пассивный, просто умножитель)
local function GetSpellAmp(hero)
    local amp = 1.0
    for item_name, bonus in pairs(SPELL_AMP_ITEMS) do
        if NPC.GetItem(hero, item_name, false) then
            amp = amp + bonus
        end
    end
    return amp
end

-- Magic resist multiplier с учётом ethereal blade и veil of discord на цели
local function GetMagicMult(target)
    local resist = NPC.GetMagicalArmorValue(target) or 0.25

    -- Veil снижает магосопру: resist уменьшается, значит урон больше
    if (not m.ui.use_veil or m.ui.use_veil:Get()) and NPC.HasModifier(target, VEIL_MOD) then
        resist = math.max(0, resist - VEIL_MAGIC_SHRED)
    end

    local base = 1.0 - resist

    if (not m.ui.use_ethereal or m.ui.use_ethereal:Get()) and NPC.HasModifier(target, ETHEREAL_MOD) then
        base = base * (1.0 + ETHEREAL_MAGIC_AMP)
    end

    return base
end

-- Эффективное HP цели: текущее HP + реген за время полёта - vessel drain за время полёта
local function GetEffectiveHP(target, travel_time)
    local hp    = Entity.GetHealth(target)
    local regen = (NPC.GetHealthRegen and NPC.GetHealthRegen(target)) or 0

    hp = hp + regen * travel_time

    if not m.ui.use_vessel or m.ui.use_vessel:Get() then
        if NPC.HasModifier(target, VESSEL_ENEMY_MOD) then
            -- 4% текущего HP/сек за время полёта
            local drain = hp * VESSEL_DRAIN_PCT * travel_time
            hp = hp - drain
        end
    end

    return math.max(hp, 1)
end

-- Итоговый урон: (illuminate + dagon + bind) × spell_amp × magic_mult
local function CalcTotalDamage(hero, target, elapsed, dagon_dmg, bind_dmg)
    local raw = GetIlluminateDamage(hero, elapsed) + (dagon_dmg or 0) + (bind_dmg or 0)
    return raw * GetSpellAmp(hero) * GetMagicMult(target)
end

-- ─── main loop ────────────────────────────────────────────────────────────────

m.OnUpdate = function()
    if m.ui.enable and not m.ui.enable:Get() then return end
    if not Engine.IsInGame() then return end

    local now = GameRules.GetGameTime()
    if now - last_update_time < 0.05 then return end
    last_update_time = now

    local hero = Heroes.GetLocal()
    if not hero or not Entity.IsAlive(hero) then return end
    if NPC.GetUnitName(hero) ~= "npc_dota_hero_keeper_of_the_light" then return end

    local ill_ab = NPC.GetAbility(hero, ILLUMINATE)
    if not ill_ab then return end
    if Ability.GetLevel(ill_ab) == 0 then return end


    -- ── Spirit Form: detect channel via ill_rdy true→false transition ──────────
    local sf    = NPC.GetAbility(hero, "keeper_of_the_light_spirit_form")
    local in_sf = sf and not Ability.IsReady(sf) and Ability.GetCooldown(sf) > 0
    if in_sf then
        was_channeling     = false
        channel_start_time = nil
        kill_triggered     = false

        local ill_rdy = Ability.IsReady(ill_ab)

        -- Детект нажатия Q: ill_rdy перешёл true→false
        if sf_was_ill_rdy and not ill_rdy then
            sf_channel_start = now
            Log.Write(string.format("[KOTL] SF channel start t=%.2f", now))
        end
        sf_was_ill_rdy = ill_rdy

        -- Сброс если illuminate снова готов (предыдущий КД кончился)
        if ill_rdy then sf_channel_start = nil end

        if sf_channel_start then
            local elapsed = now - sf_channel_start
            if elapsed > MAX_CHANNEL then
                -- канал закончился сам
                sf_channel_start = nil
            elseif (now - last_fire_time) >= FIRE_COOLDOWN then
                local min_ch = m.ui.min_channel and m.ui.min_channel:Get() or 200
                if elapsed >= (min_ch / 1000.0) then
                    local hero_pos = Entity.GetAbsOrigin(hero)
                    if hero_pos then
                        local buffer   = 1.0 + ((m.ui.buffer and m.ui.buffer:Get() or 0) / 100.0)
                        local enemies  = Entity.GetHeroesInRadius(hero, BEAM_RANGE, Enum.TeamType.TEAM_ENEMY)
                        if enemies then
                            for _, unit in ipairs(enemies) do
                                if unit and Entity.IsAlive(unit) and not Entity.IsDormant(unit) and not NPC.IsIllusion(unit) then
                                    local unit_pos = Entity.GetAbsOrigin(unit)
                                    if unit_pos then
                                        local dx   = unit_pos.x - hero_pos.x
                                        local dy   = unit_pos.y - hero_pos.y
                                        local dist = math.sqrt(dx*dx + dy*dy)
                                        if dist > 0 and dist <= BEAM_RANGE then
                                            local travel_time           = dist / BEAM_SPEED
                                            local dagon_item, dagon_dmg = FindDagon(hero, unit)
                                            local bind_item,  bind_dmg  = FindRadiantBind(hero, unit)
                                            local dealt  = CalcTotalDamage(hero, unit, elapsed, dagon_dmg, bind_dmg)
                                            local eff_hp = GetEffectiveHP(unit, travel_time)
                                            Log.Write(string.format("[KOTL] SF t=%.2f dmg=%.0f hp=%.0f", elapsed, dealt, eff_hp))
                                            if dealt >= eff_hp * buffer then
                                                last_fire_time   = now
                                                sf_channel_start = nil
                                                Log.Write(string.format("[KOTL] SF_FIRE t=%.2f dmg=%.0f hp=%.0f", elapsed, dealt, eff_hp))
                                                local ill_end = NPC.GetAbility(hero, "keeper_of_the_light_illuminate_end")
                                                if ill_end and Ability.IsReady(ill_end) then
                                                    Ability.CastNoTarget(ill_end)
                                                else
                                                    Ability.CastNoTarget(ill_ab)
                                                end
                                                if dagon_item and dagon_dmg > 0 then
                                                    NPC.CastAbilityOnTarget(hero, dagon_item, unit)
                                                end
                                                if bind_item and bind_dmg > 0 then
                                                    Ability.CastOnTarget(bind_item, unit)
                                                end
                                                return
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        return
    end
    -- Сброс SF-состояния при выходе из Spirit Form
    sf_channel_start = nil
    sf_was_ill_rdy   = true

    -- ── Regular channel detection ─────────────────────────────────────────────
    local channeling = NPC.IsChannellingAbility(hero)

    if channeling and not was_channeling then
        channel_start_time = now
        kill_triggered     = false
        Log.Write(string.format("[KOTL] Channel started (cooldown=%.1f)", now - last_fire_time))
    end
    was_channeling = channeling

    if not channeling then
        channel_start_time = nil
        kill_triggered     = false
        return
    end

    if kill_triggered then return end
    -- блокируем новые выстрелы на FIRE_COOLDOWN после последнего
    if (now - last_fire_time) < FIRE_COOLDOWN then return end

    local elapsed = channel_start_time and (now - channel_start_time) or 0
    local min_ch  = m.ui.min_channel and m.ui.min_channel:Get() or 200
    if elapsed < (min_ch / 1000.0) then return end

    local hero_pos = Entity.GetAbsOrigin(hero)
    if not hero_pos then return end

    local face_dir = GetFacingDir(hero)
    local buffer   = 1.0 + ((m.ui.buffer and m.ui.buffer:Get() or 0) / 100.0)

    local enemies = Entity.GetHeroesInRadius(hero, BEAM_RANGE, Enum.TeamType.TEAM_ENEMY)
    if not enemies then return end

    for _, unit in ipairs(enemies) do
        if unit and Entity.IsAlive(unit) and not Entity.IsDormant(unit) and not NPC.IsIllusion(unit) then
            local unit_pos = Entity.GetAbsOrigin(unit)
            if unit_pos then
                local dx   = unit_pos.x - hero_pos.x
                local dy   = unit_pos.y - hero_pos.y
                local dist = math.sqrt(dx * dx + dy * dy)

                if dist > 0 and dist <= BEAM_RANGE then
                    local travel_time           = dist / BEAM_SPEED
                    local dagon_item, dagon_dmg = FindDagon(hero, unit)
                    local bind_item,  bind_dmg  = FindRadiantBind(hero, unit)
                    local dealt  = CalcTotalDamage(hero, unit, elapsed, dagon_dmg, bind_dmg)
                    local eff_hp = GetEffectiveHP(unit, travel_time)

                    Log.Write(string.format("[KOTL] t=%.2f dmg=%.0f hp=%.0f dist=%.0f", elapsed, dealt, eff_hp, dist))

                    if dealt >= eff_hp * buffer then
                        kill_triggered = true
                        last_fire_time = now
                        Log.Write(string.format("[KOTL] FIRE t=%.2f dmg=%.0f hp=%.0f", elapsed, dealt, eff_hp))
                        local ill_end = NPC.GetAbility(hero, "keeper_of_the_light_illuminate_end")
                        if Ability.CastNoTarget then
                            if ill_end and Ability.IsReady(ill_end) then
                                Ability.CastNoTarget(ill_end)
                            else
                                Ability.CastNoTarget(ill_ab)
                            end
                        end
                        if dagon_item and dagon_dmg > 0 then
                            NPC.CastAbilityOnTarget(hero, dagon_item, unit)
                        end
                        if bind_item and bind_dmg > 0 then
                            Ability.CastOnTarget(bind_item, unit)
                        end
                        return
                    end
                end
            end
        end
    end
end

m.OnDraw = function()
    if not Engine.IsInGame() then return end

    local hero = Heroes.GetLocal()
    if not hero or not Entity.IsAlive(hero) then return end
    if NPC.GetUnitName(hero) ~= "npc_dota_hero_keeper_of_the_light" then return end

    local now     = GameRules.GetGameTime()
    local elapsed
    if sf_channel_start then
        elapsed = math.min(now - sf_channel_start, MAX_CHANNEL)
    else
        elapsed = channel_start_time and (now - channel_start_time) or MAX_CHANNEL
    end
    local hero_pos   = Entity.GetAbsOrigin(hero)
    if not hero_pos then return end

    local buffer     = 1.0 + ((m.ui.buffer and m.ui.buffer:Get() or 0) / 100.0)
    local enemies    = Entity.GetHeroesInRadius(hero, BEAM_RANGE, Enum.TeamType.TEAM_ENEMY)
    if not enemies then return end

    for _, unit in ipairs(enemies) do
        if unit and Entity.IsAlive(unit) and not Entity.IsDormant(unit) and not NPC.IsIllusion(unit) then
            local unit_pos = Entity.GetAbsOrigin(unit)
            if unit_pos then
                local dx   = unit_pos.x - hero_pos.x
                local dy   = unit_pos.y - hero_pos.y
                local dist = math.sqrt(dx * dx + dy * dy)
                local in_beam = dist <= BEAM_RANGE

                local _, dagon_dmg = FindDagon(hero, unit)
                local _, bind_dmg  = FindRadiantBind(hero, unit)
                local travel_time  = dist / BEAM_SPEED
                local dealt   = CalcTotalDamage(hero, unit, elapsed, dagon_dmg, bind_dmg)
                local eff_hp  = GetEffectiveHP(unit, travel_time)
                local can_kill = dealt >= eff_hp * buffer

                -- Минимальное время канала для убийства (тот же CalcTotalDamage что в OnUpdate)
                local need_txt
                local max_dealt = CalcTotalDamage(hero, unit, MAX_CHANNEL, dagon_dmg, bind_dmg)
                if max_dealt < eff_hp * buffer then
                    need_txt = "too tanky"
                else
                    local t_min = MAX_CHANNEL
                    for t = 0.05, MAX_CHANNEL, 0.05 do
                        if CalcTotalDamage(hero, unit, t, dagon_dmg, bind_dmg) >= eff_hp * buffer then
                            t_min = t
                            break
                        end
                    end
                    if dagon_dmg > 0 then
                        need_txt = string.format("Need: %.1fs+Dag", t_min)
                    else
                        need_txt = string.format("Need: %.1fs", t_min)
                    end
                end

                local world_pos = Vector(unit_pos.x, unit_pos.y, unit_pos.z + 200)
                local screen, visible = Render.WorldToScreen(world_pos)
                if visible then
                    local txt = string.format("DMG: %d / HP: %d", math.floor(dealt), math.floor(eff_hp))
                    local txt_size  = Render.TextSize(font, 14, txt)
                    local need_size = Render.TextSize(font, 13, need_txt)
                    local x = screen.x - txt_size.x * 0.5
                    local y = screen.y

                    local clr
                    if can_kill and in_beam then
                        clr = Color(50, 255, 50, 255)
                    elseif can_kill then
                        clr = Color(255, 200, 0, 255)
                    else
                        clr = Color(255, 80, 80, 255)
                    end

                    Render.Text(font, 14, txt, Vec2(x + 1, y + 1), Color(0, 0, 0, 200))
                    Render.Text(font, 14, txt, Vec2(x, y), clr)

                    -- строка ниже: оптимальное время
                    local nx = screen.x - need_size.x * 0.5
                    local ny = y + 18
                    local nclr = can_kill and Color(150, 255, 150, 220) or Color(200, 200, 200, 180)
                    Render.Text(font, 13, need_txt, Vec2(nx + 1, ny + 1), Color(0, 0, 0, 180))
                    Render.Text(font, 13, need_txt, Vec2(nx, ny), nclr)
                end
            end
        end
    end
end

m.OnGameEnd = function()
    last_update_time   = 0
    channel_start_time = nil
    was_channeling     = false
    kill_triggered     = false
    last_fire_time     = -10
    sf_channel_start   = nil
    sf_was_ill_rdy     = true
end

return m
