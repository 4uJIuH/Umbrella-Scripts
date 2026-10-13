-- Auto Aegis Mover & Inventory Refill
-- Automatically moves the highest priority item from backpack to the slot left by Aegis upon death or loss.
-- Supports drag-and-drop priority ordering with item icons and an optional setting to refill empty slots on death with Aegis.
-- Author: ⚔LegaXye禪 (Discord: legaxye)
local VERSION = "1.0.0"

local menuGroup = Menu.Create("Scripts", "General", "\u{f0ad} Utility", "Inventory", "Auto Aegis Mover")

local uiEnable = menuGroup:Switch("Enable Script", true)
uiEnable:Icon("\u{f021}")

local uiRefillAll = menuGroup:Switch("Refill All Empty Slots on Revive", false)
uiRefillAll:Icon("\u{f01e}")

local DEFAULT_ITEMS = {
    -- Roshan consumables / Super items
    { "item_refresher_shard", "panorama/images/items/refresher_shard_png.vtex_c", true },
    { "item_cheese", "panorama/images/items/cheese_png.vtex_c", true },

    -- Key high-impact and active items
    { "item_black_king_bar", "panorama/images/items/black_king_bar_png.vtex_c", true },
    { "item_refresher", "panorama/images/items/refresher_png.vtex_c", true },
    { "item_blink", "panorama/images/items/blink_png.vtex_c", true },
    { "item_sheepstick", "panorama/images/items/sheepstick_png.vtex_c", true },
    { "item_satanic", "panorama/images/items/satanic_png.vtex_c", true },
    { "item_abyssal_blade", "panorama/images/items/abyssal_blade_png.vtex_c", true },
    { "item_bloodthorn", "panorama/images/items/bloodthorn_png.vtex_c", true },
    { "item_wind_waker", "panorama/images/items/wind_waker_png.vtex_c", true },
    { "item_disperser", "panorama/images/items/disperser_png.vtex_c", true },
    { "item_nullifier", "panorama/images/items/nullifier_png.vtex_c", true },
    { "item_manta", "panorama/images/items/manta_png.vtex_c", true },
    { "item_silver_edge", "panorama/images/items/silver_edge_png.vtex_c", true },
    { "item_sphere", "panorama/images/items/sphere_png.vtex_c", true },
    { "item_shivas_guard", "panorama/images/items/shivas_guard_png.vtex_c", true },
    { "item_lotus_orb", "panorama/images/items/lotus_orb_png.vtex_c", true },
    { "item_hurricane_pike", "panorama/images/items/hurricane_pike_png.vtex_c", true },
    { "item_force_staff", "panorama/images/items/force_staff_png.vtex_c", true },
    { "item_glimmer_cape", "panorama/images/items/glimmer_cape_png.vtex_c", true },
    { "item_ghost", "panorama/images/items/ghost_png.vtex_c", true },
    { "item_ethereal_blade", "panorama/images/items/ethereal_blade_png.vtex_c", true },
    { "item_blade_mail", "panorama/images/items/blade_mail_png.vtex_c", true },
    { "item_harpoon", "panorama/images/items/harpoon_png.vtex_c", true },
    { "item_heavens_halberd", "panorama/images/items/heavens_halberd_png.vtex_c", true },

    -- Major damage, survivability and utility items
    { "item_greater_crit", "panorama/images/items/greater_crit_png.vtex_c", true },
    { "item_butterfly", "panorama/images/items/butterfly_png.vtex_c", true },
    { "item_monkey_king_bar", "panorama/images/items/monkey_king_bar_png.vtex_c", true },
    { "item_mjollnir", "panorama/images/items/mjollnir_png.vtex_c", true },
    { "item_radiance", "panorama/images/items/radiance_png.vtex_c", true },
    { "item_skadi", "panorama/images/items/skadi_png.vtex_c", true },
    { "item_heart", "panorama/images/items/heart_png.vtex_c", true },
    { "item_assault", "panorama/images/items/assault_png.vtex_c", true },
    { "item_octarine_core", "panorama/images/items/octarine_core_png.vtex_c", true },
    { "item_desolator", "panorama/images/items/desolator_png.vtex_c", true },
    { "item_bfury", "panorama/images/items/bfury_png.vtex_c", true },
    { "item_pipe", "panorama/images/items/pipe_png.vtex_c", true },
    { "item_crimson_guard", "panorama/images/items/crimson_guard_png.vtex_c", true },
    { "item_boots", "panorama/images/items/boots_png.vtex_c", true }
}

local uiCustomPriority = menuGroup:MultiSelect("Custom Item Priorities", DEFAULT_ITEMS, true)
uiCustomPriority:Icon("\u{f0c9}")
uiCustomPriority:DragAllowed(true)

local uiMoveDelay = menuGroup:Slider("Move Delay (ms)", 0, 500, 50, "%d ms")
uiMoveDelay:Icon("\u{f1da}")

local ZERO_VECTOR = Vector(0, 0, 0)
local hasAegis = false
local aegisSlot = nil
local needsRefillAegisSlot = nil
local needsRefillAll = false
local lastOrderTime = 0

-- Blacklisted consumable items that should never refill inventory
local GARBAGE_ITEMS = {
    ["item_tango"] = true,
    ["item_tango_single"] = true,
    ["item_clarity"] = true,
    ["item_flask"] = true,
    ["item_enchanted_mango"] = true,
    ["item_faerie_fire"] = true,
    ["item_branches"] = true,
    ["item_ward_observer"] = true,
    ["item_ward_sentry"] = true,
    ["item_smoke_of_deceit"] = true,
    ["item_dust"] = true,
    ["item_blood_grenade"] = true,
    ["item_tome_of_knowledge"] = true,
}

local function IsAegisItem(item)
    if not item then return false end
    local name = Ability.GetName(item)
    return name == "item_aegis" or name == "item_roshan_banner"
end

local function MatchItemName(itemId, itemName)
    if itemId == itemName then return true end
    if itemId == "item_blink" and itemName:find("blink", 1, true) then return true end
    if itemId == "item_boots" and (itemName:find("boots", 1, true) or itemName == "item_power_treads") then return true end
    if itemId == "item_wind_waker" and itemName == "item_cyclone" then return true end
    if itemId == "item_disperser" and itemName == "item_diffusal_blade" then return true end
    if itemId == "item_silver_edge" and itemName == "item_invis_sword" then return true end
    if itemId == "item_bloodthorn" and itemName == "item_orchid" then return true end
    return false
end

local function GetItemImportance(item, enabledItems)
    if not item then return 0 end

    local name = Ability.GetName(item)
    if not name or GARBAGE_ITEMS[name] then return 0 end

    -- Search enabled items list (drag-and-drop order)
    if enabledItems then
        local totalCount = #enabledItems
        for index, itemId in ipairs(enabledItems) do
            if MatchItemName(itemId, name) then
                return (totalCount - index + 1) * 1000
            end
        end
    end

    -- Baseline value for valid unlisted items
    return 1
end

local function FindBestBackpackItem(hero)
    local enabledItems = uiCustomPriority:ListEnabled()
    local bestItem, bestSlot = nil, nil
    local maxImportance = 0

    for slot = 6, 8 do
        local item = NPC.GetItemByIndex(hero, slot)
        if item then
            local importance = GetItemImportance(item, enabledItems)
            if importance > maxImportance then
                maxImportance = importance
                bestItem = item
                bestSlot = slot
            end
        end
    end

    return bestItem, bestSlot, maxImportance
end

local function MoveItemToSlot(hero, item, targetSlot)
    local player = Players.GetLocal()
    if not player or not hero or not item then return end

    Player.PrepareUnitOrders(
        player,
        Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_ITEM,
        targetSlot,
        ZERO_VECTOR,
        item,
        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
        hero,
        false,
        false,
        false,
        true
    )
end

return {
    OnUpdate = function()
        if not uiEnable:Get() then
            hasAegis = false
            aegisSlot = nil
            needsRefillAegisSlot = nil
            needsRefillAll = false
            return
        end

        local hero = Heroes.GetLocal()
        if not hero or Entity.IsDormant(hero) then
            return
        end

        local currentTime = GameRules.GetGameTime()
        local delay = (uiMoveDelay:Get() or 50) / 1000
        local isAlive = Entity.IsAlive(hero)

        -- Trigger immediate refill upon death with Aegis during reincarnation
        if hasAegis and not isAlive then
            needsRefillAegisSlot = aegisSlot
            needsRefillAll = uiRefillAll:Get()
            hasAegis = false
            aegisSlot = nil
        end

        -- Track Aegis in inventory while alive
        if isAlive then
            local currentAegisSlot = nil
            for slot = 0, 5 do
                local item = NPC.GetItemByIndex(hero, slot)
                if item and IsAegisItem(item) then
                    currentAegisSlot = slot
                    break
                end
            end

            if currentAegisSlot ~= nil then
                hasAegis = true
                aegisSlot = currentAegisSlot
                return
            end

            -- Aegis lost or consumed while alive (expiration / Roshan banner)
            if hasAegis and currentAegisSlot == nil then
                needsRefillAegisSlot = aegisSlot
                needsRefillAll = false
                hasAegis = false
                aegisSlot = nil
            end
        end

        -- Exit if dead and no pending Aegis action
        if not isAlive and needsRefillAegisSlot == nil and not needsRefillAll then
            return
        end

        -- Refill the exact slot left by Aegis
        if needsRefillAegisSlot ~= nil then
            if (currentTime - lastOrderTime) >= delay then
                local targetItem = NPC.GetItemByIndex(hero, needsRefillAegisSlot)
                if targetItem == nil then
                    local bestItem = FindBestBackpackItem(hero)
                    if bestItem then
                        MoveItemToSlot(hero, bestItem, needsRefillAegisSlot)
                        lastOrderTime = currentTime
                        needsRefillAegisSlot = nil
                        return
                    end
                end
                needsRefillAegisSlot = nil
            else
                return
            end
        end

        -- Optional: refill remaining empty slots
        if needsRefillAll then
            if (currentTime - lastOrderTime) >= delay then
                local emptySlot = nil
                for slot = 0, 5 do
                    if NPC.GetItemByIndex(hero, slot) == nil then
                        emptySlot = slot
                        break
                    end
                end

                if emptySlot ~= nil then
                    local bestItem = FindBestBackpackItem(hero)
                    if bestItem then
                        MoveItemToSlot(hero, bestItem, emptySlot)
                        lastOrderTime = currentTime
                        return
                    else
                        needsRefillAll = false
                    end
                else
                    needsRefillAll = false
                end
            end
        end
    end
}
