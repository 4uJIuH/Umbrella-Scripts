local script = {}

local Heroes, NPC, Ability = Heroes, NPC, Ability
local Entity, Modifier, GameRules = Entity, Modifier, GameRules
local Menu, Enum = Menu, Enum
local type, pcall = type, pcall

local INVOKER = "npc_dota_hero_invoker"
local SUN_STRIKE = "invoker_sun_strike"
local EXORT = "invoker_exort"
local INVOKE = "invoker_invoke"
local TELEPORTING = "modifier_teleporting"

local DEFAULT_SS_DELAY = 1.7
local INVOKE_STEP_DELAY = 0.05
local EXORT_BASE_DAMAGE = 100
local EXORT_DAMAGE_PER_LEVEL = 62.5

local hero = nil
local is_invoker = false
local teleports = {}
local invoke_sequence = nil
local next_invoke_step = 0
local enabled = nil

local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if ok then return a, b, c end
    return nil
end

local function build_menu()
    if type(Menu) ~= "table" or type(Menu.Create) ~= "function" then return false end
    local ok = pcall(function()
        local tab = Menu.Create("Heroes", "Hero List", "Invoker")
        local group = tab:Create("Auto Usage"):Create("Sun Strike Settings")
        enabled = group:Switch("Санстрайк в тп", false)
    end)
    return ok and enabled ~= nil
end

local function is_enabled()
    if not enabled or type(enabled.Get) ~= "function" then return false end
    local ok, value = pcall(enabled.Get, enabled)
    return ok and value == true
end

local function game_time()
    local value = call(GameRules and GameRules.GetGameTime)
    return type(value) == "number" and value or 0
end

local function unit_name(unit)
    local value = call(NPC and NPC.GetUnitName, unit)
    return type(value) == "string" and value or nil
end

local function entity_index(unit)
    local value = call(Entity and Entity.GetIndex, unit)
    return type(value) == "number" and value or nil
end

local function team(unit)
    local value = call(Entity and Entity.GetTeamNum, unit)
    return type(value) == "number" and value or nil
end

local function alive(unit)
    return unit ~= nil and call(Entity and Entity.IsAlive, unit) == true
end

local function illusion(unit)
    return call(NPC and NPC.IsIllusion, unit) == true
end

local function enemy_hero(unit)
    if not hero or not unit or not alive(unit) or illusion(unit) then return false end
    local own_team, unit_team = team(hero), team(unit)
    if own_team == nil or unit_team == nil or own_team == unit_team then return false end
    local name = unit_name(unit)
    return name ~= nil and name:match("^npc_dota_hero_") ~= nil
end

local function position(unit)
    local value = call(NPC and NPC.GetAbsOrigin, unit)
    if value then return value end
    return call(Entity and Entity.GetAbsOrigin, unit)
end

local function ability(name)
    if not hero then return nil end
    return call(NPC and NPC.GetAbility, hero, name)
end

local function ability_level(value)
    local level = call(Ability and Ability.GetLevel, value)
    return type(level) == "number" and level or 0
end

local function mana()
    local value = call(NPC and NPC.GetMana, hero)
    return type(value) == "number" and value or 0
end

local function mana_cost(value)
    local cost = call(Ability and Ability.GetManaCost, value)
    return type(cost) == "number" and cost or 0
end

local function cooldown(value)
    local remaining = call(Ability and Ability.GetCooldownTimeRemaining, value)
    return type(remaining) == "number" and remaining or 0
end

local function can_cast(value)
    if not value or cooldown(value) > 0 then return false end
    if Ability and Ability.IsCastable then
        local result = call(Ability.IsCastable, value, mana())
        if type(result) == "boolean" then return result end
    end
    return mana() >= mana_cost(value)
end

local function special(value, name)
    local result = call(Ability and Ability.GetSpecialValueFor, value, name)
    if type(result) == "number" then return result end
    result = call(Ability and Ability.GetLevelSpecialValueFor, value, name, -1)
    return type(result) == "number" and result or nil
end

local function modifier(unit, name)
    local value = call(NPC and NPC.GetModifier, unit, name)
    if value then return value end

    local modifiers = call(NPC and NPC.GetModifiers, unit)
    if type(modifiers) ~= "table" then return nil end
    for _, current in pairs(modifiers) do
        if call(Modifier and Modifier.GetName, current) == name then return current end
    end
    return nil
end

local function modifier_state(unit, name)
    local states = Enum and Enum.ModifierState
    local state = states and states[name]
    if state == nil then return false end
    return call(NPC and NPC.HasState, unit, state) == true
end

local function cast_blocked()
    if not alive(hero) then return true end
    if call(NPC and NPC.IsStunned, hero) == true then return true end
    if call(NPC and NPC.IsSilenced, hero) == true then return true end
    if modifier_state(hero, "MODIFIER_STATE_HEXED") then return true end
    if modifier_state(hero, "MODIFIER_STATE_NIGHTMARED") then return true end
    if modifier_state(hero, "MODIFIER_STATE_FROZEN") then return true end
    if modifier_state(hero, "MODIFIER_STATE_COMMAND_RESTRICTED") then return true end
    if modifier_state(hero, "MODIFIER_STATE_OUT_OF_GAME") then return true end
    return false
end

local function invoked_sun_strike()
    if not (NPC and NPC.GetAbilityByIndex and Ability and Ability.GetName) then
        return ability(SUN_STRIKE)
    end
    for slot = 3, 4 do
        local value = call(NPC.GetAbilityByIndex, hero, slot)
        if value and call(Ability.GetName, value) == SUN_STRIKE then return value end
    end
    return nil
end

local function sun_strike_delay()
    local value = ability(SUN_STRIKE)
    local delay = special(value, "delay") or DEFAULT_SS_DELAY
    local cast_point = call(Ability and Ability.GetCastPoint, value)
    if type(cast_point) ~= "number" then cast_point = 0 end
    return delay + cast_point
end

local function sun_strike_damage()
    local value = ability(SUN_STRIKE)
    local damage = special(value, "damage")
    if (not damage or damage <= 0) and Ability and Ability.GetDamage then
        damage = call(Ability.GetDamage, value)
    end

    local exort_level = ability_level(ability(EXORT))
    if exort_level < 1 then exort_level = 1 end
    local fallback = EXORT_BASE_DAMAGE + (exort_level - 1) * EXORT_DAMAGE_PER_LEVEL
    if type(damage) ~= "number" or damage < fallback then damage = fallback end
    return damage
end

local function effective_health(unit)
    local health = call(Entity and Entity.GetHealth, unit)
    if type(health) ~= "number" or health <= 0 then return 0 end

    -- This deliberately stays conservative: an exposed barrier is counted as
    -- extra health so the script does not waste Sun Strike on a non-lethal hit.
    local barriers = call(NPC and NPC.GetBarriers, unit)
    if type(barriers) == "table" then
        local barrier = barriers.all or barriers.magic
        if type(barrier) == "table" and type(barrier.current) == "number" then
            health = health + barrier.current
        end
    end
    return health
end

local function lethal(unit)
    if not enemy_hero(unit) then return false end
    if modifier_state(unit, "MODIFIER_STATE_INVULNERABLE") then return false end

    local health = effective_health(unit)
    if health <= 0 then return false end
    local regen = call(NPC and NPC.GetHealthRegen, unit)
    if type(regen) ~= "number" or regen < 0 then regen = 0 end
    return sun_strike_damage() >= health + regen * sun_strike_delay()
end

local function teleport_ends_at(tp_modifier)
    local value = call(Modifier and Modifier.GetDieTime, tp_modifier)
    return type(value) == "number" and value or nil
end

local function cast_no_target(value)
    if not value or not (Ability and Ability.CastNoTarget) then return false end
    local ok, result = pcall(Ability.CastNoTarget, value, false, false, true)
    return ok and result ~= false
end

local function cast_at(value, target_position)
    if not value or not target_position or not (Ability and Ability.CastPosition) then return false end
    local ok, result = pcall(Ability.CastPosition, value, target_position)
    return ok and result ~= false
end

local function drive_invoke(now)
    if invoked_sun_strike() then
        invoke_sequence = nil
        return
    end
    if cast_blocked() then return end

    if not invoke_sequence then
        local exort, invoke = ability(EXORT), ability(INVOKE)
        if ability_level(exort) < 1 or ability_level(invoke) < 1 then return end
        invoke_sequence = { exort, exort, exort, invoke, step = 1 }
        next_invoke_step = 0
    end

    if now < next_invoke_step then return end
    local current = invoke_sequence[invoke_sequence.step]
    if not current then
        invoke_sequence = nil
        return
    end
    if can_cast(current) and cast_no_target(current) then
        invoke_sequence.step = invoke_sequence.step + 1
        next_invoke_step = now + INVOKE_STEP_DELAY
    end
end

local function scan_teleports(now)
    local active = {}
    local candidates = {}
    local heroes = call(Heroes and Heroes.GetAll)
    if type(heroes) ~= "table" then return candidates end

    for _, unit in ipairs(heroes) do
        if enemy_hero(unit) then
            local index = entity_index(unit)
            local tp_modifier = modifier(unit, TELEPORTING)
            if index and tp_modifier then
                active[index] = true
                local record = teleports[index]
                if not record then
                    record = { unit = unit, position = position(unit), fired = false }
                    teleports[index] = record
                end

                local current_position = position(unit)
                if current_position then record.position = current_position end
                record.ends_at = teleport_ends_at(tp_modifier) or record.ends_at

                local enough_channel = not record.ends_at
                    or (record.ends_at - now) >= sun_strike_delay()
                if not record.fired and enough_channel and lethal(unit) then
                    candidates[#candidates + 1] = record
                end
            end
        end
    end

    for index in pairs(teleports) do
        if not active[index] then teleports[index] = nil end
    end
    return candidates
end

local function update()
    if not is_enabled() then
        teleports = {}
        invoke_sequence = nil
        return
    end

    if not hero then
        hero = call(Heroes and Heroes.GetLocal)
        is_invoker = hero ~= nil and unit_name(hero) == INVOKER
    end
    if not is_invoker or not alive(hero) then return end

    local now = game_time()
    local candidates = scan_teleports(now)
    if #candidates == 0 then
        invoke_sequence = nil
        return
    end

    local sun_strike = invoked_sun_strike()
    if sun_strike and can_cast(sun_strike) and not cast_blocked() then
        local target = candidates[1]
        local target_position = position(target.unit) or target.position
        if cast_at(sun_strike, target_position) then target.fired = true end
        return
    end

    if not sun_strike then drive_invoke(now) end
end

function script.OnUpdate()
    pcall(update)
end

local function reset()
    hero = nil
    is_invoker = false
    teleports = {}
    invoke_sequence = nil
    next_invoke_step = 0
end

function script.OnGameStart()
    reset()
end

function script.OnGameEnd()
    reset()
end

build_menu()

return script
