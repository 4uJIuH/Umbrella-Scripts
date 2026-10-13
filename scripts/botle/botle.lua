-- Bottle Abuse
-- Intercepts Bottle orders, cycles stat-bearing items through the backpack so
-- Dota applies their item cooldown, restores the original slots, then casts
-- Bottle.  The script deliberately limits itself to the six main slots.

local VERSION = "1.0.0"
local script = {}

local tab = Menu.Create("Scripts", "Other", "Абуз ботла")
tab:Icon("\u{f291}")
local group = tab:Create("Основные"):Create("Абуз ботла")
local enabled = group:Switch("Включено", false, "\u{f011}")
local function item_icon(item)
    return "panorama/images/items/" .. item:gsub("^item_", "") .. "_png.vtex_c"
end

-- Keep the complete exclusion lists expanded in the menu.  The MultiSelect
-- widget renders the item icons themselves and each icon is directly
-- clickable; no separate text list is needed.
local main_exclusions = {
    { "item_black_king_bar", true }, { "item_satanic", true },
    { "item_butterfly", false }, { "item_heart", false },
    { "item_skadi", false }, { "item_manta", false },
}
local other_exclusions = {
    { "item_branches", false },
    { "item_circlet", false }, { "item_gauntlets", false },
    { "item_slippers", false }, { "item_mantle", false },
    { "item_belt_of_strength", false }, { "item_band_of_elvenskin", false },
    { "item_robe", false },
    { "item_bracer", false }, { "item_wraith_band", false },
    { "item_null_talisman", false }, { "item_power_treads", false },
    { "item_ultimate_orb", false }, { "item_point_booster", false },
    { "item_ogre_axe", false }, { "item_blade_of_alacrity", false },
    { "item_staff_of_wizardry", false }, { "item_sange", false },
    { "item_yasha", false }, { "item_kaya", false },
    { "item_sange_and_yasha", false }, { "item_yasha_and_kaya", false },
    { "item_aghanims_scepter", false },
}
local function multi_items(list)
    local items = {}
    for _, entry in ipairs(list) do
        items[#items + 1] = { entry[1], item_icon(entry[1]), entry[2] }
    end
    return items
end
group:Label("Не перекладывать")
local excluded_main = group:MultiSelect("Главные предметы", multi_items(main_exclusions), true)
local excluded_other = group:MultiSelect("Остальные предметы", multi_items(other_exclusions), true)

local state = {
    phase = "idle",
    entries = {},
    move_index = 1,
    next_action = 0,
    bottle = nil,
    hero = nil,
    reason = nil,
}

local MOVE_DELAY = 0.01
local RESTORE_DELAY = 0.01

-- These are the normal Dota items whose primary purpose includes a permanent
-- attribute/stat bonus.  Damage-only items (for example battle-fury-style
-- items) are intentionally not included.
local stat_items = {
    item_branches = true, item_iron_branch = true, item_circlet = true,
    item_gauntlets = true, item_slippers = true, item_mantle = true,
    item_belt_of_strength = true, item_boots_of_elves = true,
    item_band_of_elvenskin = true, item_robe = true,
    item_bracer = true, item_wraith_band = true, item_null_talisman = true,
    item_power_treads = true,
    item_ultimate_orb = true, item_point_booster = true,
    item_ogre_axe = true, item_blade_of_alacrity = true,
    item_staff_of_wizardry = true, item_broadsword = false,
    item_sange = true, item_yasha = true, item_kaya = true,
    item_sange_and_yasha = true, item_yasha_and_kaya = true,
    item_kaya_and_sange = true, item_manta = true, item_skadi = true,
    item_heart = true, item_satanic = true, item_butterfly = true,
    item_ethereal_blade = true, item_shivas_guard = true,
    item_aghanims_scepter = true, item_aghanims_shard = true,
    item_eye_of_skadi = true, item_dispersion = true,
}

local function now()
    if GlobalVars and type(GlobalVars.GetRealTime) == "function" then
        local ok, value = pcall(GlobalVars.GetRealTime)
        if ok and tonumber(value) then return tonumber(value) end
    end
    return os.clock()
end

local function safe_get(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok then return value end
    return nil
end

local function game_time()
    if GameRules and type(GameRules.GetGameTime) == "function" then
        return safe_get(GameRules.GetGameTime) or 0
    end
    return now()
end

-- Status is intentionally not rendered in the menu.  Keep this hook as a
-- no-op because the state machine still calls it at phase transitions.
local function set_status(_text) end

local function hero()
    return Heroes and type(Heroes.GetLocal) == "function" and Heroes.GetLocal() or nil
end

local function item_name(item)
    return item and Ability and type(Ability.GetName) == "function" and safe_get(Ability.GetName, item) or ""
end

local function is_stat_item(item)
    local name = item_name(item)
    if not name or name == "" then return false end
    for _, control in ipairs({ excluded_main, excluded_other }) do
        if control and type(control.ListEnabled) == "function" then
            for _, excluded in pairs(control:ListEnabled() or {}) do
                if tostring(excluded) == name then return false end
            end
        end
    end
    if stat_items[name] == true then return true end
    return name:find("_strength") ~= nil
        or name:find("_agility") ~= nil
        or name:find("_intelligence") ~= nil
        or name:find("_attribute") ~= nil
end

local function get_item(h, slot)
    if not h or not NPC or type(NPC.GetItemByIndex) ~= "function" then return nil end
    return safe_get(NPC.GetItemByIndex, h, slot)
end

local function same_entity(a, b)
    if a == b then return true end
    if not a or not b or not Entity or type(Entity.GetIndex) ~= "function" then return false end
    return safe_get(Entity.GetIndex, a) == safe_get(Entity.GetIndex, b)
end

local function clear_state(reason)
    state.phase, state.reason = "idle", reason
    state.entries, state.move_index, state.bottle, state.hero = {}, 1, nil, nil
    set_status(reason or "idle")
end

local function find_item_slot(h, wanted)
    for slot = 0, 11 do
        local item = get_item(h, slot)
        if item == wanted then return slot end
    end
    return nil
end

local function move_item(h, item, target_slot)
    local src = find_item_slot(h, item)
    if not src or src == target_slot then return src == target_slot end

    -- Inventory movement is exposed directly by NPC.SwapItems on current
    -- qMCP builds.  PrepareUnitOrders(MOVE_ITEM) only queues a visual order
    -- in some local clients and does not actually change the inventory.
    local issued = false
    if NPC and type(NPC.SwapItems) == "function" then
        local attempts = {
            function() return NPC.SwapItems(h, src, target_slot) end,
            function() return NPC.SwapItems(h, src + 1, target_slot + 1) end,
            function() return NPC.SwapItems(h, src - 1, target_slot - 1) end,
            function() return NPC.SwapItems(src, target_slot) end,
            function() return NPC.SwapItems(src + 1, target_slot + 1) end,
            function() return NPC.SwapItems(h, item, get_item(h, target_slot)) end,
            function() return NPC.SwapItems(h, item, target_slot) end,
        }
        for _, attempt in ipairs(attempts) do
            local ok = pcall(attempt)
            issued = issued or ok
        end
    end
    if Item and type(Item.MoveToSlot) == "function" then
        local attempts = {
            function() return Item.MoveToSlot(item, target_slot) end,
            function() return Item.MoveToSlot(item, target_slot, false) end,
            function() return Item.MoveToSlot(item, h, target_slot) end,
            function() return Item.MoveToSlot(item, h, target_slot, false) end,
        }
        for _, attempt in ipairs(attempts) do
            local ok = pcall(attempt)
            issued = issued or ok
        end
    end
    if not issued and Player and type(Player.PrepareUnitOrders) == "function" then
        local p = Players and type(Players.GetLocal) == "function" and Players.GetLocal() or nil
        local order = Enum and Enum.UnitOrder and Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_ITEM or 19
        local issuer = Enum and Enum.PlayerOrderIssuer and Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY or 3
        -- MOVE_ITEM takes the destination slot as `target`; position is not
        -- used.  Passing the slot in Vector (the old implementation) caused
        -- the order to be accepted but no inventory movement to occur.
        local pos = Vector(0, 0, 0)
        if p then
            local ok = pcall(Player.PrepareUnitOrders, p, order, target_slot, pos, item, issuer, h, false, true)
            issued = issued or ok
        end
    end
    if not issued then
        return false
    end
    -- Inventory updates are applied on the next game tick, so verify on the
    -- following state-machine pass instead of rejecting a valid async order.
    return true
end

local function begin_bottle(bottle, h)
    if state.phase ~= "idle" then return false end
    if not h or (Entity and Entity.IsAlive and not safe_get(Entity.IsAlive, h)) then
        clear_state("hero is not alive")
        return false
    end
    if not bottle or (Ability and Ability.IsCastable and safe_get(Ability.IsCastable, bottle, 0) ~= true) then
        clear_state("Bottle is not ready")
        return false
    end
    if Item and type(Item.GetCurrentCharges) == "function" and (safe_get(Item.GetCurrentCharges, bottle) or 0) <= 0 then
        clear_state("Bottle has no charges")
        return false
    end
    state.hero, state.bottle, state.entries = h, bottle, {}
    for slot = 0, 5 do
        local item = get_item(h, slot)
        if item and is_stat_item(item) then
            -- Cycle one item through slot 6 at a time.  This also works when
            -- the backpack is full: the displaced backpack item swaps into
            -- the stat item's old main slot and is restored on the way back.
            state.entries[#state.entries + 1] = { item = item, from = slot, temp = 6 }
        end
    end

    if #state.entries == 0 then
        state.phase = "cast"
        set_status("casting Bottle")
        return true
    end
    state.phase, state.move_index, state.next_action = "move_out", 1, 0
    set_status("moving stat items")
    return true
end

local function cast_bottle()
    local bottle = state.bottle
    if not bottle or not Ability or type(Ability.CastNoTarget) ~= "function" then
        clear_state("Bottle unavailable")
        return
    end
    pcall(Ability.CastNoTarget, bottle, false, false, true, "botle_abuse_cast")
    clear_state("Bottle used")
end

function script.OnPrepareUnitOrders(data, player, order, target, position, ability, orderIssuer, npc, queue, show_effects, identifier)
    if type(data) == "table" then
        player, order, target, position, ability, orderIssuer, npc, identifier = data.player, data.order, data.target, data.position, data.ability, data.orderIssuer, data.npc, data.identifier
    end
    if identifier == "botle_abuse_cast" then return true end
    if not enabled:Get() or not ability then return true end
    local h = hero()
    if not h or (npc and not same_entity(npc, h)) then return true end
    local name = item_name(ability)
    local no_target = Enum and Enum.UnitOrder and Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET or 8
    local target_order = Enum and Enum.UnitOrder and Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TARGET or 6
    if name == "item_bottle" and (order == no_target or order == target_order) then
        if state.phase == "idle" then begin_bottle(ability, h) end
        return false
    end
    return true
end

function script.OnUpdate()
    if not enabled:Get() or state.phase == "idle" then return end
    local t = now()
    if t < state.next_action then return end

    if state.phase == "cast" then
        cast_bottle(); return
    end

    if state.phase == "move_out" then
        local entry = state.entries[state.move_index]
        if not entry then
            state.phase, state.next_action = "cast", t + 0.12
            set_status("casting Bottle")
            return
        end
        if move_item(state.hero, entry.item, entry.temp) then
            -- The abuse does not wait for the six-second cooldown to end.
            -- Return the item immediately: it remains disabled in the main
            -- inventory, so its attributes do not affect the Bottle heal.
            state.phase, state.next_action = "wait_cooldown", t + MOVE_DELAY
        else
            clear_state("could not move stat item")
        end
        return
    end

    if state.phase == "wait_cooldown" then
        local entry = state.entries[state.move_index]
        state.phase, state.next_action = "move_back", t
        set_status("returning disabled stat item")
        return
    end

    if state.phase == "move_back" then
        local entry = state.entries[state.move_index]
        if not entry then state.phase, state.next_action = "cast", t + 0.15; set_status("casting Bottle"); return end
        if move_item(state.hero, entry.item, entry.from) then
            state.move_index, state.phase, state.next_action = state.move_index + 1, "move_out", t + RESTORE_DELAY
        else
            clear_state("could not restore stat item")
        end
    end
end

local function register_qmcp()
    if not ai_bridge or type(ai_bridge.tool) ~= "function" then return end
    ai_bridge.tool("botle_abuse_state", "Возвращает состояние абуза ботла и список предметов.", {}, function()
        local entries = {}
        for _, e in ipairs(state.entries) do entries[#entries + 1] = { from = e.from, temp = e.temp, name = item_name(e.item) } end
        local inventory = {}
        local h = hero()
        for slot = 0, 8 do
            local item = get_item(h, slot)
            inventory[#inventory + 1] = { slot = slot, name = item and item_name(item) or nil }
        end
        return {
            enabled = enabled:Get(), phase = state.phase, reason = state.reason,
            entries = entries, inventory = inventory,
            api = {
                npc_swap_items = NPC and type(NPC.SwapItems) == "function" or false,
                item_move_to_slot = Item and type(Item.MoveToSlot) == "function" or false,
                prepare_unit_orders = Player and type(Player.PrepareUnitOrders) == "function" or false,
            },
        }
    end)
    ai_bridge.tool("botle_abuse_trigger", "Запускает абуз ботла на локальном герое.", {}, function()
        local h = hero(); local bottle = h and NPC and NPC.GetItem and safe_get(NPC.GetItem, h, "item_bottle", true) or nil
        if not h or not bottle then return { ok = false, error = "local hero or Bottle not found" } end
        return { ok = begin_bottle(bottle, h), phase = state.phase, entries = #state.entries }
    end)
    ai_bridge.tool("botle_abuse_cancel", "Отменяет текущий цикл абуза ботла.", {}, function() clear_state("отменено"); return { ok = true } end)
    ai_bridge.mcp_log("info", "Botle Abuse qMCP tools registered", { tools = 3 })
end

local function recover_orphaned_stat_items()
    local h = hero()
    if not h then return end
    for slot = 6, 8 do
        local item = get_item(h, slot)
        if item and is_stat_item(item) then
            for main = 0, 5 do
                if not get_item(h, main) then
                    move_item(h, item, main)
                    break
                end
            end
        end
    end
end

function script.OnScriptsLoaded()
    register_qmcp()
    recover_orphaned_stat_items()
end

return script
