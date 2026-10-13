---@diagnostic disable: undefined-global, lowercase-global
-- SF Feast of Souls Abuse — v4.0

local script = {}

local menu_root = Menu.Create("Heroes", "Hero List", "Shadow Fiend", "Feast of Souls Abuse")
local general = menu_root:Create("General settings")
local groupKeeper = menu_root:Create("Keeper of the Light synergy")
local groupItems = menu_root:Create("Item safety")
local groupStructures = menu_root:Create("Structure channeling safety")

local ui = {}

ui.enabled = general:Switch("Enable", true)
ui.cancel_for_feast = general:Switch("Block other orders", false)
ui.require_lingering = general:Switch("Only cast while lingering", false)
ui.use_kotl_chakra_magic = groupKeeper:Switch("Allow cast after ally chakra magic", false)

ui.prevent_mom = groupItems:Switch("Prevent mask of madness use", false)
ui.prevent_mom:Image("panorama/images/items/mask_of_madness_png.vtex_c")

ui.prevent_tp = groupItems:Switch("Prevent teleport use", false)
ui.prevent_tp:Image("panorama/images/items/tpscroll_png.vtex_c")

ui.prevent_invis = groupItems:Switch("Prevent shadow blade / silver edge use", false)
ui.prevent_invis:Icon("\u{f070}")

ui.prevent_watcher = groupStructures:Switch("Prevent watcher activation", false)
ui.prevent_watcher:Icon("\u{f06e}")

ui.prevent_gate = groupStructures:Switch("Prevent gate activation", false)
ui.prevent_gate:Icon("\u{f0e2}")

ui.prevent_outpost = groupStructures:Switch("Prevent outpost capture", false)
ui.prevent_outpost:Icon("\u{f024}")

local last_cast = 0
local cached_ability = nil

local ABILITY_NAME = {
    "nevermore_feast_of_souls"
}

local FEAST_COLLECTION_MODIFIER = "modifier_nevermore_feast_of_souls_collection"
local FEAST_LINGER_MODIFIER     = "modifier_nevermore_feast_of_souls_linger"
local CHAKRA_MAGIC_ABILITY      = "keeper_of_the_light_chakra_magic"
local MASK_OF_MADNESS_ITEM      = "item_mask_of_madness"
local WATCHER_ABILITY           = "ability_lamp_use"
local GATE_ABILITY              = "twin_gate_portal_warp"
local OUTPOST_ABILITY           = "ability_capture"

local TELEPORT_ITEMS = {
    item_tpscroll       = true,
    item_travel_boots   = true,
    item_travel_boots_2 = true,
}

local INVIS_ITEMS = {
    item_shadow_blade = true,
    item_silver_edge  = true,
}

local function localChat(message)
    log(message)
    if Chat and Chat.Print then
        Chat.Print("ConsoleChat", "[Feast of Souls Abuse] " .. tostring(message))
    end
end

local function now_ms()
    if GlobalVars and GlobalVars.GetCurTime then
        return math.floor(GlobalVars.GetCurTime() * 1000)
    end
    return math.floor(os.clock() * 1000)
end

local function is_shadow_fiend(hero)
    if not hero then return false end
    return NPC.GetUnitName(hero) == "npc_dota_hero_nevermore"
end

local function has_octarine(hero)
    if not hero then return false end
    return NPC.HasItem(hero, "item_octarine_core", true)
end

local function has_modifier(hero, modifier_name)
    if not hero then return false end
    return NPC.HasModifier(hero, modifier_name)
end

local function is_lingering(hero)
    return has_modifier(hero, FEAST_LINGER_MODIFIER)
end

local function is_collecting(hero)
    return has_modifier(hero, FEAST_COLLECTION_MODIFIER)
end

local function ability_name_matches(ability)
    if not ability then return false end
    local name = Ability.GetName(ability)
    if not name or name == "" then return false end
    for _, expected in ipairs(ABILITY_NAME) do
        if name == expected then
            return true
        end
    end
    local lower = string.lower(name)
    return string.find(lower, "feast") or string.find(lower, "frenzy")
end

local function find_feast(hero)
    if cached_ability and Entity.IsAbility(cached_ability) and ability_name_matches(cached_ability) then
        return cached_ability
    end
    cached_ability = nil
    for _, name in ipairs(ABILITY_NAME) do
        local ability = NPC.GetAbility(hero, name)
        if ability then
            cached_ability = ability
            return ability
        end
    end
    for i = 0, 31 do
        local ability = NPC.GetAbilityByIndex(hero, i)
        if ability and ability_name_matches(ability) then
            cached_ability = ability
            return ability
        end
    end
    return nil
end

local function is_same_entity(a, b)
    if not a or not b then return false end
    if a == b then return true end
    local ok_a, index_a = pcall(Entity.GetIndex, a)
    local ok_b, index_b = pcall(Entity.GetIndex, b)
    return ok_a and ok_b and index_a == index_b
end

local function is_in_ability_phase(ability)
    if not ability then return false end
    local ok, result = pcall(Ability.IsInAbilityPhase, ability)
    return ok and result == true
end

local function get_blocking_order(hero, feast)
    if NPC.IsChannellingAbility(hero) then
        local channelling = NPC.GetChannellingAbility(hero)
        if not is_same_entity(channelling, feast) then
            return channelling or true
        end
    end
    for i = 0, 31 do
        local ability = NPC.GetAbilityByIndex(hero, i)
        if ability and not is_same_entity(ability, feast) and is_in_ability_phase(ability) then
            return ability
        end
    end

    for i = 0, 17 do
        local item = NPC.GetItemByIndex(hero, i)
        if item and not is_same_entity(item, feast) and is_in_ability_phase(item) then
            return item
        end
    end

    local player = Players.GetLocal()
    if player then
        local active = Player.GetActiveAbility(player)
        if active and not is_same_entity(active, feast) and is_in_ability_phase(active) then
            return active
        end
    end

    return nil
end

local chakra_pending = false

local MOM_SILENCE_DURATION = 6.0 -- Mask of Madness silences spellcasting for 6s once activated
local TP_CHANNEL_DURATION  = 3.0 -- TP Scroll / Boots of Travel channel is roughly 3s
local INVIS_ITEM_WINDOW    = 3.0 -- Shadow Blade / Silver Edge: protect Feast for 3s before use
local WATCHER_CHANNEL_WINDOW = 1.0 -- Watcher activation 1s
local GATE_CHANNEL_WINDOW = 4.0 -- Gate channeling 4s
local OUTPOST_CHANNEL_WINDOW = 6.0 -- Outpost capturing 6s

local function get_tp_window(ability)
    local ok, cp = pcall(Ability.GetCastPoint, ability, true)
    if ok and cp and cp > 0 then
        return cp
    end
    return TP_CHANNEL_DURATION
end

-- True if: Feast is currently lingering, an eligibility path exists (Octarine or
-- Chakra), and Feast's remaining cooldown is within the given window
local function feast_needs_protection(hero, feast, window)
    if not feast then return false end
    if not is_lingering(hero) then return false end

    local eligible = has_octarine(hero) or (ui.use_kotl_chakra_magic:Get() and chakra_pending)
    if not eligible then return false end

    local cd_remaining = Ability.GetCooldown(feast) or 0
    if cd_remaining < 0 then cd_remaining = 0 end
    return cd_remaining <= window
end

local function can_cast(hero, ability)
    if not hero or not ability then return false end
    if not Entity.IsAlive(hero) then return false end
    if NPC.IsStunned(hero) or NPC.IsSilenced(hero) then return false end
    if is_collecting(hero) then return false end

    local blocker = get_blocking_order(hero, ability)
    if blocker and not ui.cancel_for_feast:Get() then return false end
    if Ability.GetLevel(ability) <= 0 then return false end
    if not Ability.IsReady(ability) then return false end
    if not Ability.IsCastable(ability, NPC.GetMana(hero)) then return false end

    return true
end

local function evaluate_trigger(hero, ability)
    if not can_cast(hero, ability) then
        return nil
    end

    local require_linger = ui.require_lingering:Get()

    if has_octarine(hero) then
        if not require_linger or is_lingering(hero) then
            return "octarine"
        end
    end

    if ui.use_kotl_chakra_magic:Get() and chakra_pending then
        if not require_linger or is_lingering(hero) then
            return "chakra"
        end
    end

    return nil
end

function script.OnPrepareUnitOrders(order)
    if not order.ability then return end

    local cast_name = Ability.GetName(order.ability)

    if cast_name == CHAKRA_MAGIC_ABILITY then
        local hero = Heroes.GetLocal()
        if not hero or not order.target then return end
        if not is_same_entity(order.target, hero) then return end

        chakra_pending = true
        return
    end

    if cast_name == MASK_OF_MADNESS_ITEM and ui.prevent_mom:Get() then
        local hero = Heroes.GetLocal()
        local owner = Ability.GetOwner(order.ability)
        if hero and owner and is_same_entity(owner, hero) then
            local feast = find_feast(hero)
            if feast_needs_protection(hero, feast, MOM_SILENCE_DURATION) then
                localChat("Blocked Mask of Madness: Feast would need to be cast within its 6s silence")
                return false
            end
        end
        return
    end

    if TELEPORT_ITEMS[cast_name] and ui.prevent_tp:Get() then
        local hero = Heroes.GetLocal()
        local owner = Ability.GetOwner(order.ability)
        if hero and owner and is_same_entity(owner, hero) then
            local feast = find_feast(hero)
            if feast_needs_protection(hero, feast, get_tp_window(order.ability)) then
                localChat("Blocked Teleport: Feast would need to be cast during the channel")
                return false
            end
        end
        return
    end

    if INVIS_ITEMS[cast_name] and ui.prevent_invis:Get() then
        local hero = Heroes.GetLocal()
        local owner = Ability.GetOwner(order.ability)
        if hero and owner and is_same_entity(owner, hero) then
            local feast = find_feast(hero)
            if feast_needs_protection(hero, feast, INVIS_ITEM_WINDOW) then
                localChat("Blocked Shadow Blade/Silver Edge: Feast would need to be cast within 3s")
                return false
            end
        end
        return
    end

    if cast_name == WATCHER_ABILITY and ui.prevent_watcher:Get() then
        local hero = Heroes.GetLocal()
        local owner = Ability.GetOwner(order.ability)
        if hero and owner and is_same_entity(owner, hero) then
            local feast = find_feast(hero)
            if feast_needs_protection(hero, feast, WATCHER_CHANNEL_WINDOW) then
                localChat("Blocked Watcher activation: Feast would need to be cast during the channel")
                return false
            end
        end
        return
    end

    if cast_name == GATE_ABILITY and ui.prevent_gate:Get() then
        local hero = Heroes.GetLocal()
        local owner = Ability.GetOwner(order.ability)
        if hero and owner and is_same_entity(owner, hero) then
            local feast = find_feast(hero)
            if feast_needs_protection(hero, feast, GATE_CHANNEL_WINDOW) then
                localChat("Blocked Gate activation: Feast would need to be cast during the channel")
                return false
            end
        end
        return
    end

    if cast_name == OUTPOST_ABILITY and ui.prevent_outpost:Get() then
        local hero = Heroes.GetLocal()
        local owner = Ability.GetOwner(order.ability)
        if hero and owner and is_same_entity(owner, hero) then
            local feast = find_feast(hero)
            if feast_needs_protection(hero, feast, OUTPOST_CHANNEL_WINDOW) then
                localChat("Blocked Outpost capture: Feast would need to be cast during the channel")
                return false
            end
        end
    end
end

function script.OnUpdate()
    if not ui.enabled:Get() then return end
    if not Engine.IsInGame() then return end
    local hero = Heroes.GetLocal()
    if not is_shadow_fiend(hero) then return end
    local feast = find_feast(hero)

    local trigger = evaluate_trigger(hero, feast)
    if not trigger then return end

    local t = now_ms()
    if t - last_cast < 50 then return end
    last_cast = t

    local blocker = get_blocking_order(hero, feast)
    if ui.cancel_for_feast:Get() and blocker then
        local player = Players.GetLocal()
        if player then
            Player.HoldPosition(player, hero, false, false, true, "sf_auto_feast_cancel")
        end
    end

    if trigger == "chakra" then
        chakra_pending = false
    end

    Ability.CastNoTarget(feast, false, false, true, "sf_auto_feast")
end

return script
