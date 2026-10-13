-- SD Poison 5 v1.1 - UCZone / Umbrella API v2.0
-- Copy this file to %cheat_dir%/scripts, then enable it in the menu.
-- Menu: General > Main > SD Poison 5 > Main > Settings
-- Set Combo key to the same HOLD key used by your existing hero combo.
-- This is a Release-only companion, not a replacement for that combo.
-- Release detonates ALL of your poisoned enemies, not just the trigger hero.
-- Tested with API mocks; not tested inside a running UCZone client.

---@diagnostic disable: undefined-global
local script = {}

local HERO_NAME = "npc_dota_hero_shadow_demon"
local TALENT_NAME = "special_bonus_unique_shadow_demon_purge_poison"
local RELEASE_NAME = "shadow_demon_shadow_poison_release"
local POISON_MODIFIER = "modifier_shadow_demon_shadow_poison"
local STACK_THRESHOLD = 5
local SCAN_INTERVAL = 0.03
local MIN_ORDER_INTERVAL = 0.60

local tab = Menu.Create("General", "Main", "SD Poison 5")
local group = tab:Create("Main"):Create("Settings")
local ui = {
    enabled = group:Switch("Enable", false),
    combo_only = group:Switch("Only while combo key is held", true),
    combo_key = group:Bind("Combo key", Enum.ButtonCode.KEY_SPACE),
    debug = group:Switch("Debug log", false),
}

local state = {}
local function reset(hero)
    state.hero = hero
    state.last_time = nil
    state.next_scan = -math.huge
    state.next_order = -math.huge
    state.next_log = -math.huge
    state.last_status = nil
end
reset(nil)

local function valid(entity)
    return entity ~= nil and Entity.IsEntity(entity)
end

-- Only a changed status is logged; no more than twice per second.
local function report(message, now)
    if not ui.debug:Get() then return end
    if state.last_status == message or now < state.next_log then return end
    print("[SD Poison 5] " .. message)
    state.last_status = message
    state.next_log = now + 0.50
end

local function is_our_modifier(modifier, hero_index)
    local caster = Modifier.GetCaster(modifier)
    if valid(caster) then
        return Entity.GetIndex(caster) == hero_index
    end

    -- Some modifiers expose the source ability before they expose a caster.
    local source = Modifier.GetAbility(modifier)
    if valid(source) then
        local owner = Ability.GetOwner(source)
        return valid(owner) and Entity.GetIndex(owner) == hero_index
    end

    -- Unknown ownership must not be confused with our own poison.
    return false
end

---@return integer
local function our_poison_stacks(enemy, hero_index)
    local best = 0
    -- Iterate all modifiers: another caster may have a same-named modifier.
    for _, modifier in pairs(NPC.GetModifiers(enemy) or {}) do
        if Modifier.GetName(modifier) == POISON_MODIFIER
            and is_our_modifier(modifier, hero_index) then
            best = math.max(best, Modifier.GetStackCount(modifier) or 0)
        end
    end
    return best
end

local function find_trigger(hero)
    local hero_index = Entity.GetIndex(hero)
    local our_team = Entity.GetTeamNum(hero)
    local trigger, best_stacks = nil, STACK_THRESHOLD - 1

    for _, enemy in pairs(Heroes.GetAll() or {}) do
        if valid(enemy)
            and Entity.IsAlive(enemy)
            and not Entity.IsDormant(enemy)
            and Entity.GetTeamNum(enemy) ~= our_team
            and NPC.IsHero(enemy)
            and not NPC.IsIllusion(enemy) then
            local stacks = our_poison_stacks(enemy, hero_index)
            -- Trigger at 5 OR MORE stacks, not only at exactly 5.
            if stacks >= STACK_THRESHOLD and stacks > best_stacks then
                trigger, best_stacks = enemy, stacks
            end
        end
    end

    return trigger, best_stacks
end

local function ability_busy(ability)
    return valid(ability)
        and (Ability.IsInAbilityPhase(ability) or Ability.IsChannelling(ability))
end

local function hero_busy(hero)
    -- Do not interrupt an existing cast or channel, including our own Release.
    for index = 0, 25 do
        if ability_busy(NPC.GetAbilityByIndex(hero, index)) then return true end
    end
    -- Items must be checked separately (including the teleport slot).
    for index = 0, 20 do
        if ability_busy(NPC.GetItemByIndex(hero, index)) then return true end
    end
    -- Do NOT block merely because the hero is attacking: that would prevent
    -- Release during a continuous attacking combo. Release has its own cast.
    return false
end

function script.OnUpdate()
    local hero = Heroes.GetLocal()
    if not valid(hero) or NPC.GetUnitName(hero) ~= HERO_NAME then
        reset(nil)
        return
    end

    local now = GameRules.GetGameTime()
    if state.hero ~= hero or (state.last_time and now < state.last_time) then
        reset(hero)
    end
    state.last_time = now

    if not ui.enabled:Get() then return end
    if now < state.next_scan then return end
    state.next_scan = now + SCAN_INTERVAL

    if GameRules.IsPaused() then
        report("Paused.", now)
        return
    end
    if Menu.Opened() or Input.IsInputCaptured() then return end
    if not Entity.IsAlive(hero) then
        report("Hero is dead.", now)
        return
    end
    if NPC.GetCurrentLevel(hero) < 25 then
        report("Waiting for hero level 25 or higher.", now)
        return
    end

    -- A level-25 hero does not necessarily have this talent learned.
    local talent = NPC.GetAbility(hero, TALENT_NAME)
    if not valid(talent) or Ability.GetLevel(talent) < 1 then
        report("Required talent is missing or not learned: " .. TALENT_NAME, now)
        return
    end
    if ui.combo_only:Get() and not ui.combo_key:IsDown() then
        report("Waiting for the combo HOLD key.", now)
        return
    end

    local release = NPC.GetAbility(hero, RELEASE_NAME)
    if not valid(release) then
        report("Shadow Poison Release ability was not found.", now)
        return
    end
    if now < state.next_order then return end
    if not Ability.IsCastable(release, NPC.GetMana(hero)) then
        report("Release is not ready (cooldown / level / mana).", now)
        return
    end

    local enemy, stacks = find_trigger(hero)
    if not enemy then
        report("Waiting for 5+ confirmed own stacks on a visible enemy hero.", now)
        return
    end
    if hero_busy(hero) then
        report("Waiting for the current spell / item cast or channel.", now)
        return
    end

    -- UCZone returns an enum: -1 means success. It is NOT a boolean.
    local cast_result = Ability.CanBeExecuted(release)
    if cast_result ~= -1 then
        report("Release blocked; CanBeExecuted = " .. tostring(cast_result), now)
        return
    end

    -- A retry must not cancel the same cast before its cast point completes.
    local cast_point = Ability.GetCastPoint(release) or 0
    state.next_order = now + math.max(MIN_ORDER_INTERVAL, cast_point + 0.25)

    -- No target, no order queue and no changes to other scripts' orders.
    -- This API call returns nil: sending an order is not cast confirmation.
    Ability.CastNoTarget(release)
    if ui.debug:Get() then
        print(string.format(
            "[SD Poison 5] Release REQUESTED: %s, %d stacks (not cast confirmation).",
            NPC.GetUnitName(enemy), stacks
        ))
    end
end

function script.OnGameEnd()
    reset(nil)
end

return script
