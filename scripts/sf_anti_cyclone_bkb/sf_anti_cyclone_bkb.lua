---@diagnostic disable: undefined-global, lowercase-global
-- Anti-Cyclone BKB — v2.0
-- Detects an enemy's Eul's Scepter (Cyclone) or Wind Waker order targeting you the
-- moment it's prepared, and immediately follows up with your own Black King Bar.

local script = {}
local menu_root = Menu.Create("Heroes", "Hero List", "Shadow Fiend", "Feast of Souls Abuse")
local general = menu_root:Create("Anti-Cyclone BKB")
local ui = {}

ui.enabled = general:Switch("Enable", false)
ui.enabled:Icon("\u{f3ed}")
local CYCLONE_ITEMS = {
    item_cyclone    = true,
    item_wind_waker = true,
}
local BKB_ITEM = "item_black_king_bar"
local pending = false
local function is_shadow_fiend(hero)
    if not hero then return false end
    return NPC.GetUnitName(hero) == "npc_dota_hero_nevermore"
end
local function is_same_entity(a, b)
    if not a or not b then return false end
    if a == b then return true end
    local ok_a, index_a = pcall(Entity.GetIndex, a)
    local ok_b, index_b = pcall(Entity.GetIndex, b)
    return ok_a and ok_b and index_a == index_b
end
local function find_item(hero, item_name)
    if not hero then return nil end
    for i = 0, 5 do
        local item = NPC.GetItemByIndex(hero, i)
        if item and Ability.GetName(item) == item_name then
            return item
        end
    end
    return nil
end
local function can_cast_item(hero, item)
    if not hero or not item then return false end
    if not Entity.IsAlive(hero) then return false end
    if Ability.GetLevel(item) <= 0 then return false end
    if not Ability.IsReady(item) then return false end
    if not Ability.IsCastable(item, NPC.GetMana(hero)) then return false end
    return true
end
function script.OnPrepareUnitOrders(order)
    if not ui.enabled:Get() then return end
    if not order.ability then return end
    if not CYCLONE_ITEMS[Ability.GetName(order.ability)] then return end
    local hero = Heroes.GetLocal()
    if not hero then return end
    if not is_shadow_fiend(hero) then return end
    if not order.target then return end
    if not is_same_entity(order.target, hero) then return end
    local bkb = find_item(hero, BKB_ITEM)
    if bkb and can_cast_item(hero, bkb) then
        Ability.CastNoTarget(bkb, false, false, true, "anti_cyclone_bkb")
    else
        pending = true
    end
end
function script.OnUpdate()
    if not ui.enabled:Get() then return end
    if not Engine.IsInGame() then return end
    if not pending then return end
    local hero = Heroes.GetLocal()
    if not hero or not Entity.IsAlive(hero) or not is_shadow_fiend(hero) then
        pending = false
        return
    end
    local bkb = find_item(hero, BKB_ITEM)
    if not bkb then
        pending = false
        return
    end
    if not can_cast_item(hero, bkb) then
        pending = false
        return
    end
    Ability.CastNoTarget(bkb, false, false, true, "anti_cyclone_bkb")
    pending = false
end
return script
