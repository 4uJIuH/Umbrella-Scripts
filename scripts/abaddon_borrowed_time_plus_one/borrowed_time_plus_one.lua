--[[
    abaddon // borrowed time +1
    ~ v1beta
    -@-
    ~ я на самом деле не знаю это слоп ебаный или все таки полезно будет, я каток 5 сыграл оно збс работает я прост всю ноч не спал и кароч такой ебать скрипт под себя написать надо это ваще кул идея а потом я такой бля спать хочу,
    ~ выпил белый адреналин включил кодекс. закинул ноги на стол.. и написал этудичь
    ~ @sediksss
]]

local script = {}

local chronos = require("chronos")
local JSON = require("assets.JSON")

--#region Constants
local HERO_NAME = "npc_dota_hero_abaddon"
local ULT_NAME = "abaddon_borrowed_time"

local SCYTHE_MODIFIER = "modifier_necrolyte_reapers_scythe"
local NECRO_NAME = "npc_dota_hero_necrolyte"
local SCYTHE_NAME = "necrolyte_reapers_scythe"
local SCYTHE_MULT = { [1] = 0.6, [2] = 0.75, [3] = 0.9 }
local SCYTHE_SCEPTER_BONUS = 0.15
local SCYTHE_PREARM_RANGE = 650
local SCYTHE_LETHAL_BUFFER = 50

local DUEL_MODIFIER = "modifier_legion_commander_duel"

local AXE_NAME = "npc_dota_hero_axe"
local CULLING_NAME = "axe_culling_blade"
local CULLING_THRESHOLD = { [1] = 250, [2] = 325, [3] = 400 }
local CULLING_WATCH_RANGE = 1100
local CULLING_BUFFER = 60

local AA_NAME = "npc_dota_hero_ancient_apparition"
local ICE_BLAST_MODIFIER = "modifier_ice_blast"
local ICE_BLAST_NAME = "ancient_apparition_ice_blast"
local SHATTER_PERCENT = { [1] = 10, [2] = 11, [3] = 12 }
local SHATTER_BUFFER = 3

local ATTACK_RADIUS = 1300
local ATTACK_RANGE_BUFFER = 80
local NUKE_RADIUS = 1400
local NUKE_RANGE_BUFFER = 125
local LINEAR_HIT_RADIUS = 130
local ATTACK_HITS_CAP = 3
local CAST_ANIM_MIN_CASTPOINT = 0.1
local LINEAR_LIFETIME = 5

local LEARN_RESEND_DELAY = 0.35
local LEARN_ATTEMPTS_CAP = 5
local DIAG_INTERVAL = 15
local ASSESS_INTERVAL = 0.03
local THEME_RELOAD_DELAY = 0.2
local ABILITY_SLOT_MAX = 23

local DAMAGE_SPECIAL_KEYS = {
    "damage",
    "magic_missile_damage",
    "impale_damage",
    "dragon_slave_damage",
    "nova_damage",
    "fissure_damage",
    "powershot_damage",
    "damage_heal",
    "hit_damage",
    "max_damage",
}

local LINEAR_ABILITY_ALIASES = {
    mirana_spell_arrow = { "mirana_arrow" },
    pudge_meathook = { "pudge_meat_hook" },
    windrunner_spell_powershot = { "windrunner_powershot" },
    lion_spell_impale = { "lion_impale" },
    impale = { "lion_impale", "nyx_assassin_impale" },
    dragon_slave = { "lina_dragon_slave" },
    lina_spell_dragon_slave = { "lina_dragon_slave" },
    necrolyte_pulse_enemy = { "necrolyte_death_pulse" },
}

local AUTO_TAB_CANDIDATES = {
    "Автоиспользование",
    "Авто-использование",
    "автоиспользование",
    "Auto Usage",
    "Auto usage",
    "AutoUsage",
}
--#endregion

--#region Menu
local heroes_page = Menu.Find("Heroes", "Hero List", "Abaddon")
local auto_tab = nil
local auto_tab_source = "fallback"

if heroes_page then
    for _, name in ipairs(AUTO_TAB_CANDIDATES) do
        local found = heroes_page:Find(name)
        if found then
            auto_tab = found
            auto_tab_source = name
            break
        end
    end
    if not auto_tab then
        auto_tab = heroes_page:Create("borrowed time")
        auto_tab_source = "created"
    end
else
    auto_tab = Menu.Create("uc.zone", "Quality of Life", "Abaddon", "borrowed time")
    auto_tab_source = "fallback"
end

local group_main = auto_tab:Create("borrowed time")
local group_visual = auto_tab:Create("визуал")
local group_info = auto_tab:Create("информация")

local ui = {
    enabled = group_main:Switch("включить скрипт", true),
    hp_floor = group_main:Slider("аварийный порог hp (%)", 5, 30, 12, "%d%%"),
    safety = group_main:Slider("порог урона (% хп)", 60, 99, 85, "%d%%"),
    horizon_ms = group_main:Slider("окно предсказания (мс)", 400, 1500, 800, "%d"),

    draw_overlay = group_visual:Switch("дебаг", false),
}

group_info:Label("~v1beta")
group_info:Label("dev @sediksss")
--#endregion

--#region Theme
local theme = {
    bg_base      = Color(10, 12, 16, 235),
    bg_plate     = Color(24, 26, 32, 240),
    border_muted = Color(45, 48, 56, 180),
    text_active  = Color(245, 245, 250, 255),
    text_muted   = Color(135, 140, 150, 255),
}

local function parse_color(arr, default_col)
    if type(arr) ~= "table" or #arr < 3 then
        return default_col
    end
    local r = math.max(0, math.min(255, math.floor(arr[1] * 255)))
    local g = math.max(0, math.min(255, math.floor(arr[2] * 255)))
    local b = math.max(0, math.min(255, math.floor(arr[3] * 255)))
    local a = (#arr >= 4) and math.max(0, math.min(255, math.floor(arr[4] * 255))) or 255
    return Color(r, g, b, a)
end

local function with_alpha(c, factor)
    return Color(c.r, c.g, c.b, math.floor(c.a * math.max(0, math.min(1, factor))))
end

local function reload_theme()
    local ok, cheat_dir = pcall(Engine.GetCheatDirectory)
    if not ok or not cheat_dir then
        return
    end
    local file = io.open(cheat_dir:gsub("[\\/]+$", "") .. "/gui.json", "r")
    if not file then
        return
    end
    local content = file:read("*a")
    file:close()
    local ok_json, data = pcall(function() return JSON:decode(content) end)
    if not ok_json or type(data) ~= "table" then
        return
    end
    if data["Colors/active_widgets_text"] then
        theme.text_active = parse_color(data["Colors/active_widgets_text"], theme.text_active)
    end
    if data["Colors/main_background"] then
        theme.bg_base = parse_color(data["Colors/main_background"], theme.bg_base)
    elseif data["Colors/additional_background"] then
        theme.bg_base = parse_color(data["Colors/additional_background"], theme.bg_base)
    end
    if data["Colors/button_background"] then
        theme.bg_plate = parse_color(data["Colors/button_background"], theme.bg_plate)
    end
    if data["Colors/group_outline"] then
        theme.border_muted = parse_color(data["Colors/group_outline"], theme.border_muted)
    end
    if data["Colors/primary_widgets_text"] then
        theme.text_muted = parse_color(data["Colors/primary_widgets_text"], theme.text_muted)
    end
end

reload_theme()

local theme_reload_due = nil

function script.OnThemeUpdate()
    theme_reload_due = chronos.nanotime() + THEME_RELOAD_DELAY
end

function script.OnUpdateEx()
    if theme_reload_due and chronos.nanotime() >= theme_reload_due then
        theme_reload_due = nil
        reload_theme()
    end
end
--#endregion

--#region Fonts & State
local font = Render.LoadFont("Arial", Enum.FontCreate.FONTFLAG_ANTIALIAS | Enum.FontCreate.FONTFLAG_DROPSHADOW, 600)
local font_bold = Render.LoadFont("Arial", Enum.FontCreate.FONTFLAG_ANTIALIAS | Enum.FontCreate.FONTFLAG_DROPSHADOW, 800)

local state = {
    projectiles = {},
    known_projectiles = nil,
    pending_learn_since = nil,
    learn_attempts = 0,
    learn_failed_logged = false,
    learn_confirmed = false,
    last_learn_at = nil,
    doom_logged = false,
    last_diag = 0,
    last_assess = -1,
    damage_specials = {},
    damage_misses = {},
}
--#endregion

--#region Logging
local function log(level, msg, data)
    if ai_bridge and ai_bridge.mcp_log then
        ai_bridge.mcp_log(level, "[abbt] " .. msg, data)
    end
end
--#endregion

--#region Ability Damage
local special_value_getter = Ability.GetSpecialValueFor or Ability.GetLevelSpecialValueFor

local function read_damage_special(ability, key)
    if not special_value_getter then
        return 0
    end
    local ok, value = pcall(special_value_getter, ability, key, -1)
    if not ok then
        return 0
    end
    return tonumber(value) or 0
end

local function get_ability_damage(ability)
    local damage = tonumber(Ability.GetDamage(ability)) or 0
    if damage > 0 then
        return damage
    end

    local name = Ability.GetName(ability) or "unknown"
    local cached_key = state.damage_specials[name]
    if cached_key then
        damage = read_damage_special(ability, cached_key)
        if damage > 0 then
            return damage
        end
    end

    local level = Ability.GetLevel(ability)
    local miss_key = name .. ":" .. tostring(level)
    if state.damage_misses[miss_key] then
        return 0
    end

    for i = 1, #DAMAGE_SPECIAL_KEYS do
        local key = DAMAGE_SPECIAL_KEYS[i]
        damage = read_damage_special(ability, key)
        if damage > 0 then
            state.damage_specials[name] = key
            return damage
        end
    end

    state.damage_misses[miss_key] = true
    return 0
end

local function ability_damage_after_resist(ability, damage, armor_mult, magic_mult)
    local dtype = math.floor(Ability.GetDamageType(ability) or 0)
    if dtype & Enum.DamageTypes.DAMAGE_TYPE_PHYSICAL ~= 0 then
        return damage * armor_mult
    end
    if dtype & Enum.DamageTypes.DAMAGE_TYPE_MAGICAL ~= 0 then
        return damage * magic_mult
    end
    return damage
end

local function log_ignored_projectile(short_name, full_name)
    local key = short_name
    if (not key or key == "") and full_name then
        key = full_name:gsub("^.*/", ""):gsub("%.[^.]*$", "")
    end
    key = key or "unknown"
    if not state.known_projectiles then
        state.known_projectiles = {}
    end
    if not state.known_projectiles[key] then
        state.known_projectiles[key] = true
        log("debug", "ignored projectile without damaging ability", { short = short_name, full = full_name })
    end
end
--#endregion

--#region Enemy Scan (single pass)
local ctx = {
    my_pos = nil,
    mx = 0, my = 0,
    my_team = 0,
    hp = 0, max_hp = 0,
    armor_mult = 1, magic_mult = 1,
    horizon = 0.8,
}

local scan_result = {
    damage = 0,
    culling = false,
    scythe = false,
    aa_ready = false,
}

local function count_ability_damage(caster, ox, oy, target_x, target_y, armor_mult, magic_mult)
    local total = 0
    for slot = 0, ABILITY_SLOT_MAX do
        local ability = NPC.GetAbilityByIndex(caster, slot)
        if ability
            and Ability.GetLevel(ability) > 0
            and not Ability.IsHidden(ability)
            and not Ability.IsPassive(ability)
            and Ability.IsReady(ability) then
            local behavior = math.floor(Ability.GetBehavior(ability) or 0)
            if behavior & Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_ITEM == 0 then
                local damage = get_ability_damage(ability)
                if damage > 0 then
                    local cast_range = Ability.GetCastRange(ability) + NPC.GetCastRangeBonus(caster) + NUKE_RANGE_BUFFER
                    local dx, dy = ox - target_x, oy - target_y
                    if dx * dx + dy * dy <= cast_range * cast_range then
                        total = total + ability_damage_after_resist(ability, damage, armor_mult, magic_mult)
                    end
                end
            end
        end
    end
    return total
end

local function scan_enemies()
    local r = scan_result
    r.damage = 0
    r.culling = false
    r.scythe = false
    r.aa_ready = false

    local enemies = Heroes.InRadius(ctx.my_pos, NUKE_RADIUS, ctx.my_team, Enum.TeamType.TEAM_ENEMY, true, true)
    if not enemies then
        return r
    end

    for i = 1, #enemies do
        local enemy = enemies[i]
        local ex, ey, _ = Entity.GetAbsOriginXYZ(enemy)
        local dx, dy = ex - ctx.mx, ey - ctx.my
        local dist_sq = dx * dx + dy * dy
        local dist = math.sqrt(dist_sq)
        local name = NPC.GetUnitName(enemy)

        local range = NPC.GetAttackRange(enemy) + NPC.GetAttackRangeBonus(enemy) + ATTACK_RANGE_BUFFER
        if dist <= range then
            local aps = NPC.GetAttacksPerSecond(enemy)
            local hits = 1
            local proj_speed = NPC.GetAttackProjectileSpeed(enemy)
            if proj_speed and proj_speed > 0 then
                local flight = dist / proj_speed
                hits = hits + math.floor(math.max(ctx.horizon - flight, 0) * aps)
            else
                hits = hits + math.floor(ctx.horizon * aps)
            end
            if hits > ATTACK_HITS_CAP then
                hits = ATTACK_HITS_CAP
            end
            r.damage = r.damage + NPC.GetTrueDamage(enemy) * hits * ctx.armor_mult
        end

        r.damage = r.damage + count_ability_damage(
            enemy,
            ex,
            ey,
            ctx.mx,
            ctx.my,
            ctx.armor_mult,
            ctx.magic_mult
        )

        if not r.culling and name == AXE_NAME and dist <= CULLING_WATCH_RANGE then
            local culling = NPC.GetAbility(enemy, CULLING_NAME)
            if culling and Ability.GetLevel(culling) > 0 and Ability.IsReady(culling) then
                local threshold = CULLING_THRESHOLD[math.min(Ability.GetLevel(culling), 3)]
                if threshold and ctx.hp <= threshold + CULLING_BUFFER then
                    r.culling = true
                end
            end
        end

        if not r.scythe and name == NECRO_NAME and dist <= SCYTHE_PREARM_RANGE then
            local scythe = NPC.GetAbility(enemy, SCYTHE_NAME)
            if scythe and Ability.GetLevel(scythe) > 0 and Ability.IsReady(scythe) then
                local mult = SCYTHE_MULT[math.min(Ability.GetLevel(scythe), 3)]
                if NPC.HasScepter(enemy) then
                    mult = mult + SCYTHE_SCEPTER_BONUS
                end
                if mult * (ctx.max_hp - ctx.hp) + SCYTHE_LETHAL_BUFFER >= ctx.hp then
                    r.scythe = true
                end
            end
        end

        if not r.aa_ready and name == AA_NAME then
            local ice_blast = NPC.GetAbility(enemy, ICE_BLAST_NAME)
            if ice_blast and Ability.GetLevel(ice_blast) > 0
                and (Ability.IsReady(ice_blast) or Ability.IsInAbilityPhase(ice_blast)) then
                local shatter = SHATTER_PERCENT[math.min(Ability.GetLevel(ice_blast), 3)]
                if ctx.hp / ctx.max_hp * 100 <= shatter + SHATTER_BUFFER then
                    r.aa_ready = true
                end
            end
        end
    end

    return r
end
--#endregion

--#region Projectiles
local function clear_projectile_state()
    if #state.projectiles > 0 then
        state.projectiles = {}
    end
    state.known_projectiles = nil
end

local function prune_projectiles(now)
    local list = state.projectiles
    local write = 1
    for read = 1, #list do
        local p = list[read]
        local alive = (p.kind == "linear" and now - p.born < LINEAR_LIFETIME)
            or (p.kind ~= "linear" and p.deadline > now)
        if alive then
            list[write] = p
            write = write + 1
        end
    end
    for i = #list, write, -1 do
        list[i] = nil
    end
end

local function live_linear_projectiles()
    if not LinearProjectiles or not LinearProjectiles.GetAll then
        return nil
    end
    local all = LinearProjectiles.GetAll()
    if not all then
        return nil
    end
    local by_handle = {}
    for _, projectile in pairs(all) do
        if projectile and projectile.handle ~= nil then
            by_handle[projectile.handle] = projectile
        end
    end
    return by_handle
end

local function projectile_pressure(now, horizon, mx, my)
    local total = 0
    local list = state.projectiles
    local has_linear = false
    for i = 1, #list do
        if list[i].kind == "linear" then
            has_linear = true
            break
        end
    end
    local live_linears = has_linear and live_linear_projectiles() or nil

    for i = 1, #list do
        local p = list[i]
        if p.kind == "linear" then
            local live = live_linears and live_linears[p.handle]
            if live and live.position and live.velocity then
                local vx = tonumber(live.velocity.x) or 0
                local vy = tonumber(live.velocity.y) or 0
                local speed = math.sqrt(vx * vx + vy * vy)
                if speed > 0.001 then
                    local dirx, diry = vx / speed, vy / speed
                    local px = tonumber(live.position.x) or 0
                    local py = tonumber(live.position.y) or 0
                    local relx, rely = mx - px, my - py
                    local along = relx * dirx + rely * diry
                    local cx, cy = px + dirx * along, py + diry * along
                    local ddx, ddy = mx - cx, my - cy
                    local radius = p.radius or LINEAR_HIT_RADIUS
                    local remaining = nil
                    local max_dist = tonumber(live.max_dist)
                    if max_dist and max_dist > 0 and live.start_position then
                        local sx = tonumber(live.start_position.x) or px
                        local sy = tonumber(live.start_position.y) or py
                        local travelled_x, travelled_y = px - sx, py - sy
                        remaining = math.max(0, max_dist - math.sqrt(travelled_x * travelled_x + travelled_y * travelled_y))
                    end
                    if along >= 0
                        and (not remaining or along <= remaining + radius)
                        and along / speed <= horizon
                        and ddx * ddx + ddy * ddy <= radius * radius then
                        total = total + p.damage
                    end
                end
            end
        else
            if p.deadline - now <= horizon then
                total = total + p.damage
            end
        end
    end
    return total
end

local function projectile_ability_is_usable(ability)
    if not ability
        or Ability.GetLevel(ability) <= 0
        or Ability.IsHidden(ability)
        or Ability.IsPassive(ability) then
        return false
    end
    local behavior = math.floor(Ability.GetBehavior(ability) or 0)
    return behavior & Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_ITEM == 0
end

local function try_projectile_ability_name(source, name)
    if not name or name == "" then
        return nil
    end
    local ability = NPC.GetAbility(source, name)
    if projectile_ability_is_usable(ability) then
        return ability
    end
    local aliases = LINEAR_ABILITY_ALIASES[name]
    if aliases then
        for i = 1, #aliases do
            ability = NPC.GetAbility(source, aliases[i])
            if projectile_ability_is_usable(ability) then
                return ability
            end
        end
    end
    return nil
end

local function resolve_linear_ability(source, short_name, full_name)
    local names = {}
    if short_name and short_name ~= "" then
        names[#names + 1] = short_name
    end
    if full_name and full_name ~= "" then
        names[#names + 1] = full_name:gsub("^.*/", ""):gsub("%.[^.]*$", "")
    end

    for i = 1, #names do
        local ability = try_projectile_ability_name(source, names[i])
        if ability then
            return ability
        end
    end

    for slot = 0, ABILITY_SLOT_MAX do
        local ability = NPC.GetAbilityByIndex(source, slot)
        if projectile_ability_is_usable(ability) then
            local ability_name = Ability.GetName(ability)
            if ability_name and ability_name ~= "" then
                for i = 1, #names do
                    if names[i]:find(ability_name, 1, true) then
                        return ability
                    end
                end
            end
        end
    end
    return nil
end

local function tracking_hero()
    if not ui.enabled:Get() or not Engine.IsInGame() then
        return nil
    end
    local hero = Heroes.GetLocal()
    if not hero
        or NPC.GetUnitName(hero) ~= HERO_NAME
        or not Entity.IsAlive(hero)
        or NPC.IsWaitingToSpawn(hero) then
        return nil
    end
    local ult = NPC.GetAbility(hero, ULT_NAME)
    if not ult
        or Ability.GetLevel(ult) > 0
        or NPC.GetCurrentLevel(hero) < 6
        or Hero.GetAbilityPoints(hero) < 1 then
        return nil
    end
    return hero
end

local function enemy_projectile_source(source, hero)
    return source and Entity.IsNPC(source) and not Entity.IsSameTeam(source, hero)
end

local function targeted_projectile_deadline(data, hero, now)
    local speed = tonumber(data.moveSpeed) or tonumber(data.original_move_speed)
    if speed and speed > 0 and data.source then
        local sx, sy, _ = Entity.GetAbsOriginXYZ(data.source)
        local hx, hy, _ = Entity.GetAbsOriginXYZ(hero)
        local dx, dy = sx - hx, sy - hy
        local flight = math.sqrt(dx * dx + dy * dy) / speed
        return now + math.max(0.01, math.min(flight, 10))
    end

    local max_impact = tonumber(data.maxImpactTime)
    if max_impact and max_impact > now and max_impact <= now + 10 then
        return max_impact
    end
    local expire = tonumber(data.expireTime)
    if expire and expire > now and expire <= now + 10 then
        return expire
    end
    return now + 3
end
--#endregion

--#region Assessment
local assessment = {
    danger = 0,
    limit = 0,
    trigger = false,
    forced = false,
    doomed = false,
}

local function assess(hero, game_now)
    local mx, my, _ = Entity.GetAbsOriginXYZ(hero)
    local hp = Entity.GetHealth(hero)
    local max_hp = Entity.GetMaxHealth(hero)
    local horizon = ui.horizon_ms:Get() / 1000

    ctx.mx, ctx.my = mx, my
    ctx.my_pos = Entity.GetAbsOrigin(hero)
    ctx.my_team = Entity.GetTeamNum(hero)
    ctx.hp, ctx.max_hp = hp, max_hp
    ctx.armor_mult = NPC.GetArmorDamageMultiplier(hero)
    ctx.magic_mult = NPC.GetMagicalArmorDamageMultiplier(hero)
    ctx.horizon = horizon

    local pool = hp + NPC.GetHealthRegen(hero) * horizon
    local barriers = NPC.GetBarriers(hero)
    if barriers and barriers.all then
        pool = pool + (tonumber(barriers.all.current) or 0)
    end
    local limit = pool * ui.safety:Get() / 100

    local scan = scan_enemies()
    local total = scan.damage
    total = total + projectile_pressure(game_now, horizon, mx, my)

    local forced = scan.scythe
        or scan.culling
        or NPC.HasModifier(hero, SCYTHE_MODIFIER)
        or NPC.HasModifier(hero, DUEL_MODIFIER)

    local doomed = scan.aa_ready or NPC.HasModifier(hero, ICE_BLAST_MODIFIER)

    assessment.danger = total
    assessment.limit = limit
    assessment.trigger = total >= limit or hp <= max_hp * ui.hp_floor:Get() / 100 or forced
    assessment.forced = forced
    assessment.doomed = doomed
    return assessment
end
--#endregion

--#region Learn Order
local function send_learn_order(player, hero, ult)
    Player.PrepareUnitOrders(
        player,
        Enum.UnitOrder.DOTA_UNIT_ORDER_TRAIN_ABILITY,
        ult,
        Vector(0, 0, 0),
        ult,
        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_HERO_ONLY,
        hero
    )
end
--#endregion

--#region Callbacks
function script.OnScriptsLoaded()
    log("info", "loaded", { menu = auto_tab_source })
end

function script.OnUpdate()
    if not ui.enabled:Get() or not Engine.IsInGame() then
        clear_projectile_state()
        return
    end
    local hero = Heroes.GetLocal()
    if not hero or NPC.GetUnitName(hero) ~= HERO_NAME or not Entity.IsAlive(hero) or NPC.IsWaitingToSpawn(hero) then
        clear_projectile_state()
        return
    end

    local ult = NPC.GetAbility(hero, ULT_NAME)
    if not ult then
        clear_projectile_state()
        return
    end

    if Ability.GetLevel(ult) > 0 then
        clear_projectile_state()
        if not state.learn_confirmed then
            state.learn_confirmed = true
            log("info", "borrowed time learned", { hp = Entity.GetHealth(hero) })
        end
        return
    end

    if Hero.GetAbilityPoints(hero) < 1 then
        clear_projectile_state()
        return
    end

    if NPC.GetCurrentLevel(hero) < 6 then
        clear_projectile_state()
        state.learn_attempts = 0
        state.pending_learn_since = nil
        return
    end

    local game_now = GameRules.GetGameTime()
    prune_projectiles(game_now)

    if game_now - state.last_assess < ASSESS_INTERVAL then
        return
    end
    state.last_assess = game_now

    local danger = assess(hero, game_now)

    local now = chronos.nanotime()
    if ui.draw_overlay:Get() and now - state.last_diag >= DIAG_INTERVAL then
        state.last_diag = now
        log("info", "state", {
            hp = Entity.GetHealth(hero),
            points = Hero.GetAbilityPoints(hero),
            ult_level = Ability.GetLevel(ult),
            danger = math.floor(danger.danger),
            limit = math.floor(danger.limit),
            trigger = danger.trigger,
            forced = danger.forced,
            projectiles = #state.projectiles,
        })
    end

    if danger.doomed then
        if not state.doom_logged then
            state.doom_logged = true
            log("warn", "ice blast doom, point stays banked", { hp = Entity.GetHealth(hero) })
        end
        state.pending_learn_since = nil
        state.learn_attempts = 0
        return
    end
    state.doom_logged = false

    if not (danger.trigger or danger.forced) then
        state.learn_attempts = 0
        state.pending_learn_since = nil
        return
    end

    if state.learn_attempts >= LEARN_ATTEMPTS_CAP then
        if not state.learn_failed_logged then
            state.learn_failed_logged = true
            log("error", "learn rejected repeatedly, waiting for next episode", {
                hero_level = NPC.GetCurrentLevel(hero),
                points = Hero.GetAbilityPoints(hero),
                can_upgrade = tostring(Ability.CanBeUpgraded(ult)),
            })
        end
        return
    end

    if state.pending_learn_since and now - state.pending_learn_since < LEARN_RESEND_DELAY then
        return
    end

    state.pending_learn_since = now
    state.learn_attempts = state.learn_attempts + 1
    state.last_learn_at = now
    log("info", "danger trigger, learning ult", {
        hp = Entity.GetHealth(hero),
        danger = math.floor(danger.danger),
        limit = math.floor(danger.limit),
        forced = danger.forced,
        attempt = state.learn_attempts,
    })
    send_learn_order(Players.GetLocal(), hero, ult)
end

function script.OnUnitAnimation(data)
    if not Engine.IsInGame() or not data or not data.unit then
        return
    end
    if not Entity.IsHero(data.unit) then
        return
    end
    local hero = tracking_hero()
    if not hero or Entity.IsSameTeam(data.unit, hero) or NPC.IsIllusion(data.unit) or not Entity.IsAlive(data.unit) then
        return
    end
    local activity = data.activity
    if activity == Enum.GameActivity.ACT_DOTA_ATTACK
        or activity == Enum.GameActivity.ACT_DOTA_ATTACK2
        or activity == Enum.GameActivity.ACT_DOTA_ATTACK_EVENT then
        return
    end
    local castpoint = tonumber(data.castpoint) or 0
    if castpoint < CAST_ANIM_MIN_CASTPOINT then
        return
    end
    local mx, my, _ = Entity.GetAbsOriginXYZ(hero)
    local ex, ey, _ = Entity.GetAbsOriginXYZ(data.unit)
    local dx, dy = ex - mx, ey - my
    if dx * dx + dy * dy > NUKE_RADIUS * NUKE_RADIUS then
        return
    end
    local ability = NPC.GetAbilityByActivity and NPC.GetAbilityByActivity(data.unit, activity) or nil
    if not projectile_ability_is_usable(ability) then
        return
    end
    local damage = get_ability_damage(ability)
    if damage <= 0 then
        return
    end
    damage = ability_damage_after_resist(
        ability,
        damage,
        NPC.GetArmorDamageMultiplier(hero),
        NPC.GetMagicalArmorDamageMultiplier(hero)
    )
    local now = GameRules.GetGameTime()
    state.projectiles[#state.projectiles + 1] = {
        kind = "cast",
        born = now,
        deadline = now + castpoint,
        damage = damage,
    }
end

function script.OnProjectile(data)
    if not Engine.IsInGame() or not data or not data.target or data.isAttack then
        return
    end
    local hero = tracking_hero()
    if not hero or data.target ~= hero or not enemy_projectile_source(data.source, hero) then
        return
    end
    local ability = data.ability
    if not projectile_ability_is_usable(ability) then
        log_ignored_projectile(data.name, data.fullName)
        return
    end
    local damage = get_ability_damage(ability)
    if damage <= 0 then
        log_ignored_projectile(data.name, data.fullName)
        return
    end
    damage = ability_damage_after_resist(
        ability,
        damage,
        NPC.GetArmorDamageMultiplier(hero),
        NPC.GetMagicalArmorDamageMultiplier(hero)
    )
    local now = GameRules.GetGameTime()
    state.projectiles[#state.projectiles + 1] = {
        kind = "targeted",
        born = now,
        deadline = targeted_projectile_deadline(data, hero, now),
        damage = damage,
    }
end

function script.OnLinearProjectileCreate(data)
    if not Engine.IsInGame() or not data or data.handle == nil then
        return
    end
    local hero = tracking_hero()
    if not hero or not enemy_projectile_source(data.source, hero) then
        return
    end
    local ability = resolve_linear_ability(data.source, data.name, data.fullName)
    if not ability then
        log_ignored_projectile(data.name, data.fullName)
        return
    end
    local damage = get_ability_damage(ability)
    if damage <= 0 then
        log_ignored_projectile(data.name, data.fullName)
        return
    end
    damage = ability_damage_after_resist(
        ability,
        damage,
        NPC.GetArmorDamageMultiplier(hero),
        NPC.GetMagicalArmorDamageMultiplier(hero)
    )
    local now = GameRules.GetGameTime()
    state.projectiles[#state.projectiles + 1] = {
        kind = "linear",
        handle = data.handle,
        born = now,
        radius = LINEAR_HIT_RADIUS,
        damage = damage,
    }
end

function script.OnLinearProjectileDestroy(data)
    if not data then
        return
    end
    table.RemoveElement(state.projectiles, function(p)
        return p.kind == "linear" and p.handle == data.handle
    end)
end
--#endregion

--#region Overlay
function script.OnDraw()
    if not ui.draw_overlay:Get() or not Engine.IsInGame() then
        return
    end
    local hero = Heroes.GetLocal()
    if not hero or NPC.GetUnitName(hero) ~= HERO_NAME or not Entity.IsAlive(hero) then
        return
    end

    local ult = NPC.GetAbility(hero, ULT_NAME)
    if not ult then
        return
    end

    local spos, visible = Render.WorldToScreen(Entity.GetAbsOrigin(hero))
    if not visible then
        return
    end
    local sx, sy = spos.x, spos.y

    local armed = Ability.GetLevel(ult) > 0
    local text
    local col
    if armed then
        text = "bt: armed"
        col = with_alpha(theme.text_active, 1)
    elseif assessment.forced then
        text = string.format("bt: force %.0f/%.0f", assessment.danger, assessment.limit)
        col = Color(255, 70, 70, 255)
    elseif assessment.trigger then
        text = string.format("bt: %.0f/%.0f", assessment.danger, assessment.limit)
        col = Color(255, 120, 70, 255)
    else
        text = string.format("bt: %.0f/%.0f", assessment.danger, assessment.limit)
        col = with_alpha(theme.text_muted, 1)
    end

    local pad_x, pad_y = 7, 3
    local tsize = Render.TextSize(font_bold, 13, text)
    local w, h = tsize.x + pad_x * 2, tsize.y + pad_y * 2
    local x1, y1 = sx + 22, sy - h - 26
    Render.FilledRect(Vec2(x1, y1), Vec2(x1 + w, y1 + h), with_alpha(theme.bg_base, 0.92), 4)
    Render.Rect(Vec2(x1, y1), Vec2(x1 + w, y1 + h), with_alpha(theme.border_muted, 0.9), 4, Enum.DrawFlags.None, 1)
    Render.Text(font_bold, 13, text, Vec2(x1 + pad_x, y1 + pad_y), col)

    if state.last_learn_at and chronos.nanotime() - state.last_learn_at < 1.2 then
        local screen = Render.ScreenSize()
        local alert = "bt learning +"
        Render.Text(font_bold, 26, alert, Vec2(screen.x / 2 - 84, screen.y * 0.62), Color(255, 50, 50, 255))
    end
end
--#endregion

--#region Reset
function script.OnGameEnd()
    state.projectiles = {}
    state.known_projectiles = nil
    state.pending_learn_since = nil
    state.learn_attempts = 0
    state.learn_failed_logged = false
    state.learn_confirmed = false
    state.last_learn_at = nil
    state.doom_logged = false
    state.last_assess = -1
    state.damage_specials = {}
    state.damage_misses = {}
end
--#endregion

return script
