local AutoSummons = {}

local BOAR_NAME = "npc_dota_beastmaster_boar"
local FORGE_SPIRIT_NAME = "npc_dota_invoker_forged_spirit"
local SUMMON_NAMES = { [BOAR_NAME] = true, [FORGE_SPIRIT_NAME] = true }

local SAFETY_MARGIN = 200
local SAFE_DIST_MARGIN = 25
local AUTO_DISABLE_AT_SECONDS = 8 * 60
local THREAT_SEARCH_RADIUS = 1200
local RESEED_INTERVAL = 1.0
local ORDER_COOLDOWN = 0.5
local PROJECTILE_ATTACK_EXPIRE = 2.0
local TARGET_EPSILON = 30

local CONVAR_SUMMONED_AUTOATTACK = "dota_summoned_units_auto_attack_mode_2"
local SUMMONED_AUTOATTACK_STANDARD = 0
local SUMMONED_AUTOATTACK_FALLBACK = 2

local ORDER_ATTACK_TARGET = Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET
local ORDER_MOVE = Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION
local ORDER_HOLD = Enum.UnitOrder.DOTA_UNIT_ORDER_HOLD_POSITION
local ORDER_STOP = Enum.UnitOrder.DOTA_UNIT_ORDER_STOP
local TEAM_ENEMY = Enum.TeamType.TEAM_ENEMY

local HERO_MENU_NAMES = {
    ["npc_dota_hero_beastmaster"] = "Beastmaster",
    ["npc_dota_hero_invoker"] = "Invoker"
}

local g_main = Menu.Create("Scripts", "Other", "Auto Summons", "Main", "Main")
g_main:Parent():Parent():Icon("\u{f06e}")
local s_enable = g_main:Switch("Boar kiting (enemy attack range)", false)
local s_only_when_attacking = g_main:Switch("Only when enemy is attacking", true)
local s_enemy_target_check = g_main:Switch("Retreat only if enemy targets this summon", true)
local s_melee_fallback = g_main:Switch("Melee fallback (closest summon when no projectile)", false)
local s_hitrun = g_main:Switch("Hit-and-run on attack/combo (attack once then retreat)", true)
local s_order_cooldown = g_main:Slider("Order cooldown (x0.1 sec)", 2, 15, 5, "%d")

local summons = {}
local last_issued = {}
local last_order_time = {}
local summon_attack_order = {}
local summon_was_attacking = {}
local projectile_attacks = {}

local hero_combo_widget = nil
local summoned_autoattack_convar_ref = nil
local saved_summoned_autoattack_value = nil
local prev_enabled = false
local last_reseed = 0

local function get_attack_range(npc)
    return (NPC.GetAttackRange(npc) or 0) + (NPC.GetAttackRangeBonus(npc) or 0)
end

local function is_our_summon(npc, my_hero)
    if not npc or not Entity.IsNPC(npc) or not SUMMON_NAMES[NPC.GetUnitName(npc)] then return false end
    my_hero = my_hero or Heroes.GetLocal()
    if not my_hero then return false end
    if NPC.GetOwnerNPC(npc) == my_hero then return true end
    return Entity.GetTeamNum(npc) == Entity.GetTeamNum(my_hero)
        and NPC.IsControllableByPlayer(npc, Hero.GetPlayerID(my_hero))
end

local function clear_summon_state(index)
    last_issued[index] = nil
    last_order_time[index] = nil
    summon_attack_order[index] = nil
    summon_was_attacking[index] = nil
    projectile_attacks[index] = nil
end

local function reseed_summons(my_hero)
    local list = NPCs.GetAll()
    local present = {}
    if list then
        for _, npc in pairs(list) do
            if is_our_summon(npc, my_hero) then
                present[Entity.GetIndex(npc)] = npc
            end
        end
    end
    for index in pairs(summons) do
        if not present[index] then
            summons[index] = nil
            clear_summon_state(index)
        end
    end
    for index, npc in pairs(present) do
        summons[index] = npc
    end
end

local function get_nearby_enemies(pos, radius, my_team)
    return NPCs.InRadius(pos, radius, my_team, TEAM_ENEMY, false, true) or {}
end

local function retreat_position(unit_pos, enemy_pos, enemy_range, margin)
    local dx = unit_pos.x - enemy_pos.x
    local dy = unit_pos.y - enemy_pos.y
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 1 then return unit_pos.x, unit_pos.y end
    local target_dist = enemy_range + margin
    return enemy_pos.x + dx / len * target_dist, enemy_pos.y + dy / len * target_dist
end

local function record_projectile_attack(source, target, expire_at)
    local ti = Entity.GetIndex(target)
    local bucket = projectile_attacks[ti]
    if not bucket then
        bucket = {}
        projectile_attacks[ti] = bucket
    end
    bucket[Entity.GetIndex(source)] = expire_at
end

local function enemy_hit_summon_recently(enemy, unit, now)
    local bucket = projectile_attacks[Entity.GetIndex(unit)]
    if not bucket then return false end
    local exp = bucket[Entity.GetIndex(enemy)]
    return exp ~= nil and exp >= now
end

local function cleanup_expired_projectile_attacks(now)
    for ti, enemies in pairs(projectile_attacks) do
        local any = false
        for si, exp in pairs(enemies) do
            if exp < now then
                enemies[si] = nil
            else
                any = true
            end
        end
        if not any then projectile_attacks[ti] = nil end
    end
end

local function enemy_attacking_our_summon(enemy, unit, unit_pos, now, melee_fallback)
    if enemy_hit_summon_recently(enemy, unit, now) then return true end
    if not melee_fallback or NPC.IsRanged(enemy) or not NPC.IsAttacking(enemy) then return false end
    local enemy_pos = Entity.GetAbsOrigin(enemy)
    local unit_dist = unit_pos:Distance2D(enemy_pos)
    for _, s in pairs(summons) do
        if s ~= unit and Entity.IsAlive(s) and Entity.GetAbsOrigin(s):Distance2D(enemy_pos) < unit_dist then
            return false
        end
    end
    return true
end

local function combo_key_down()
    if not hero_combo_widget then return false end
    local ok, key = pcall(function() return hero_combo_widget:Get() end)
    if not ok or not key or key == Enum.ButtonCode.KEY_NONE then return false end
    return Input.IsKeyDown(key)
end

local function resolve_combo_widget(my_hero)
    if hero_combo_widget then return end
    local menu_name = HERO_MENU_NAMES[NPC.GetUnitName(my_hero)]
    if menu_name then
        hero_combo_widget = Menu.Find("Heroes", "Hero List", menu_name, "Main Settings", "Hero Settings", "Combo Key")
    end
end

local function apply_convar(enabled)
    if summoned_autoattack_convar_ref == nil then
        local ok, ref = pcall(ConVar.Find, CONVAR_SUMMONED_AUTOATTACK)
        if ok then summoned_autoattack_convar_ref = ref end
    end
    if summoned_autoattack_convar_ref == nil then return end
    if enabled and not prev_enabled then
        pcall(function()
            local v = ConVar.GetInt(summoned_autoattack_convar_ref)
            if v ~= nil then saved_summoned_autoattack_value = v end
            ConVar.SetInt(summoned_autoattack_convar_ref, SUMMONED_AUTOATTACK_STANDARD)
        end)
    elseif not enabled and prev_enabled then
        pcall(function()
            ConVar.SetInt(summoned_autoattack_convar_ref, saved_summoned_autoattack_value or SUMMONED_AUTOATTACK_FALLBACK)
            saved_summoned_autoattack_value = nil
        end)
    end
end

function AutoSummons.OnNpcSpawned(npc)
    if is_our_summon(npc) then
        summons[Entity.GetIndex(npc)] = npc
    end
end

function AutoSummons.OnEntityDestroy(entity)
    if not entity then return end
    local index = Entity.GetIndex(entity)
    if summons[index] then
        summons[index] = nil
        clear_summon_state(index)
    end
end

function AutoSummons.OnProjectile(proj)
    if not proj or not proj.isAttack then return end
    local source, target = proj.source, proj.target
    if not source or not target then return end
    if not Entity.IsNPC(source) or not NPC.IsHero(source) then return end
    local my_hero = Heroes.GetLocal()
    if not my_hero or not is_our_summon(target, my_hero) then return end
    if Entity.GetTeamNum(source) == Entity.GetTeamNum(my_hero) then return end
    record_projectile_attack(source, target, GameRules.GetGameTime() + PROJECTILE_ATTACK_EXPIRE)
end

function AutoSummons.OnPrepareUnitOrders(order)
    if not order or not order.npc then return true end
    local my_hero = Heroes.GetLocal()
    if not my_hero then return true end
    local my_team = Entity.GetTeamNum(my_hero)
    local ord = order.order
    local units = type(order.npc) == "table" and order.npc or { order.npc }
    for _, npc in pairs(units) do
        if is_our_summon(npc, my_hero) then
            local index = Entity.GetIndex(npc)
            if ord == ORDER_ATTACK_TARGET and order.target and Entity.IsNPC(order.target)
                and NPC.IsHero(order.target) and Entity.GetTeamNum(order.target) ~= my_team then
                summon_attack_order[index] = true
            elseif ord == ORDER_MOVE or ord == ORDER_HOLD or ord == ORDER_STOP then
                summon_attack_order[index] = nil
            end
        end
    end
    return true
end

function AutoSummons.OnUpdate()
    local now = GameRules.GetGameTime()
    local game_start = GameRules.GetGameStartTime()
    if game_start > 0 and s_enable:Get() and (now - game_start) >= AUTO_DISABLE_AT_SECONDS then
        s_enable:Set(false)
    end

    local enabled = s_enable:Get()
    apply_convar(enabled)
    prev_enabled = enabled
    if not enabled then return end

    local my_hero = Heroes.GetLocal()
    if not my_hero then return end
    local my_team = Entity.GetTeamNum(my_hero)

    if now - last_reseed >= RESEED_INTERVAL then
        last_reseed = now
        reseed_summons(my_hero)
    end
    if next(summons) == nil then return end

    resolve_combo_widget(my_hero)
    cleanup_expired_projectile_attacks(now)

    local hitrun_enabled = s_hitrun:Get()
    local only_when_attacking = s_only_when_attacking:Get()
    local target_check = s_enemy_target_check:Get()
    local melee_fallback = s_melee_fallback:Get()
    local combo_down = hitrun_enabled and combo_key_down()
    local cooldown = math.max((s_order_cooldown:Get() or 5) / 10.0, ORDER_COOLDOWN)

    for index, unit in pairs(summons) do
        if not Entity.IsEntity(unit) then
            summons[index] = nil
            clear_summon_state(index)
            goto continue
        end
        if not Entity.IsAlive(unit) or not NPC.IsKillable(unit) then goto continue end

        local attacking_now = NPC.IsAttacking(unit)
        if hitrun_enabled then
            if attacking_now then
                summon_was_attacking[index] = true
            elseif summon_was_attacking[index] then
                summon_was_attacking[index] = nil
                summon_attack_order[index] = nil
            end
        else
            summon_was_attacking[index] = nil
        end

        local hitrun_mode = hitrun_enabled and (summon_attack_order[index] or combo_down)
        if hitrun_mode and attacking_now then goto continue end
        if not hitrun_mode and summon_attack_order[index] then goto continue end

        local unit_pos = Entity.GetAbsOrigin(unit)
        local best_enemy, best_range = nil, 0
        for _, enemy in pairs(get_nearby_enemies(unit_pos, THREAT_SEARCH_RADIUS, my_team)) do
            if NPC.IsHero(enemy) and NPC.IsKillable(enemy) then
                local attack_range = get_attack_range(enemy)
                if attack_range > 0 and attack_range > best_range then
                    local enemy_pos = Entity.GetAbsOrigin(enemy)
                    if unit_pos:Distance2D(enemy_pos) < attack_range + SAFETY_MARGIN + SAFE_DIST_MARGIN then
                        local threatening = not only_when_attacking or NPC.IsAttacking(enemy)
                        if threatening and (not target_check or enemy_attacking_our_summon(enemy, unit, unit_pos, now, melee_fallback)) then
                            best_range = attack_range
                            best_enemy = enemy
                        end
                    end
                end
            end
        end

        if not best_enemy then
            last_issued[index] = nil
            last_order_time[index] = nil
            goto continue
        end

        local last_time = last_order_time[index]
        if last_time and (now - last_time) < cooldown then goto continue end

        local tx, ty = retreat_position(unit_pos, Entity.GetAbsOrigin(best_enemy), best_range, SAFETY_MARGIN)
        local last = last_issued[index]
        if not last or math.abs(last.x - tx) > TARGET_EPSILON or math.abs(last.y - ty) > TARGET_EPSILON then
            last_issued[index] = { x = tx, y = ty }
            last_order_time[index] = now
            NPC.MoveTo(unit, Vector(tx, ty, unit_pos.z), false, false, false, true)
        end

        ::continue::
    end
end

return AutoSummons
