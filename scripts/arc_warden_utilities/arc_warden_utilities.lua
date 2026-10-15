local VERSION = "1.1.0"

local script = {}

local HERO = "npc_dota_hero_arc_warden"

local T_MENU = "Утилиты"

local UtilitiesTab = Menu.Create("Heroes", "Hero List", "Arc Warden", T_MENU,
    "Утилиты")

local AutoInventory = UtilitiesTab:Switch(
    "Предметы из ранца", true, "\u{f290}")
local AutoInventoryGear = AutoInventory:Gear("Settings")
local MoveBottle = AutoInventoryGear:Switch(
    "Перекладывать Bottle", true,
    "panorama/images/items/bottle_png.vtex_c")
local MoveMjollnir = AutoInventoryGear:Switch(
    "Перекладывать Mjollnir в ранец при Moon Shard", true,
    "panorama/images/items/mjollnir_png.vtex_c")
local MoveBKB = AutoInventoryGear:Switch(
    "Перекладывать Black King Bar в ранец при Moon Shard (Если в кд)", true,
    "panorama/images/items/black_king_bar_png.vtex_c")

local CooldownSwap = AutoInventoryGear:MultiSelect(
    "Перекладывать при КД (по приоритету)",
    {
        { "item_black_king_bar", "panorama/images/items/black_king_bar_png.vtex_c", true },
        { "item_bloodthorn",     "panorama/images/items/bloodthorn_png.vtex_c",     true },
        { "item_sheepstick",     "panorama/images/items/sheepstick_png.vtex_c",     true },
        { "item_manta",          "panorama/images/items/manta_png.vtex_c",          true },
        { "item_satanic",        "panorama/images/items/satanic_png.vtex_c",        true },
        { "item_mjollnir",       "panorama/images/items/mjollnir_png.vtex_c",       true },
        { "item_nullifier",      "panorama/images/items/nullifier_png.vtex_c",      true },
        { "item_swift_blink",    "panorama/images/items/swift_blink_png.vtex_c",    true },
        { "item_hurricane_pike", "panorama/images/items/hurricane_pike_png.vtex_c", true },
        { "item_silver_edge",    "panorama/images/items/silver_edge_png.vtex_c",    true },
        { "item_disperser",      "panorama/images/items/disperser_png.vtex_c",      true },
    },
    true
)
CooldownSwap:ToolTip("Перекладывает предметы из инвентаря в ранец, пока они на кулдауне. Возвращает обратно, когда КД закончился. Приоритет — сверху вниз.")

AutoInventory:ToolTip("Перекладывает дорогие предметы из ранца в инвентарь, заменяя дешёвые (Branches, Slippers и т.д.).")
MoveBottle:ToolTip("Разрешает перенос Bottle из ранца в инвентарь. Bottle в инвентаре всё равно не будет выброшен.")
MoveMjollnir:ToolTip("Когда Moon Shard попадает к вам и BKB НЕ в кд — перекладывает Mjollnir в ранец. Когда Moon Shard исчезает — возвращает Mjollnir обратно.")
MoveBKB:ToolTip("Когда Moon Shard попадает к вам и BKB в кд — перекладывает ТОЛЬКО BKB в ранец. Когда Moon Shard исчезает — возвращает BKB обратно.")

local HookBlock = UtilitiesTab:Switch(
    "Блок Meat Hook", true,
    "panorama/images/spellicons/pudge_meat_hook_png.vtex_c")
local HookGear = HookBlock:Gear("Settings")

local hook_enabled      = HookGear:Switch("Блокировать хук", true)
local hook_cast_tempest = HookGear:Switch("Призывать клона (Tempest)", true)
local hook_use_clone    = HookGear:Switch("Двигать живого клона", true)
local hook_save_allies  = HookGear:Switch("Спасать союзников", true)
local hook_priority     = HookGear:Combo("Приоритет спасения",
    {"Сначала себя", "Сначала союзника"}, 0)
local hook_draw         = HookGear:Switch("Рисовать траекторию хука", true)

HookBlock:ToolTip("Автоматически ставит клона Arc Warden на пути хука Пуджа.")

local RollBlock = UtilitiesTab:Switch(
    "Блок Rolling Boulder", true,
    "panorama/images/spellicons/earth_spirit_rolling_boulder_png.vtex_c")
local RollGear = RollBlock:Gear("Settings")

local roll_enabled      = RollGear:Switch("Блокировать перекат", true)
local roll_cast_tempest = RollGear:Switch("Призывать клона (Tempest)", true)
local roll_use_clone    = RollGear:Switch("Двигать живого клона", true)
local roll_mode         = RollGear:Combo("Режим блокировки",
    {"Когда катится НА меня", "Когда укатывается (ОТ меня)", "Всегда (и на меня и от меня)"}, 0)
local roll_draw         = RollGear:Switch("Рисовать точку блока", true)

RollBlock:ToolTip("Автоматически ставит клона Arc Warden на пути переката Earth Spirit.")

local SparkBlock = UtilitiesTab:Switch(
    "Авто Spark Wraith", false,
    "panorama/images/spellicons/arc_warden_spark_wraith_png.vtex_c")
local SparkGear = SparkBlock:Gear("Settings")

local spark_mode        = SparkGear:Combo("Режим работы",
    {"Автоматический", "Механический"}, 0)
local spark_cast_key    = SparkGear:Bind("Клавиша каста", Enum.ButtonCode.KEY_NONE)
local spark_dir_var     = SparkGear:Slider("Отклонение направления", 0, 50, 30, "%d%%")
local spark_creep_rad   = SparkGear:Slider("Радиус исключения крипов", 375, 600, 375, "%d")

local spark_stun_only   = SparkGear:Switch("Кастовать ТОЛЬКО под стан", false)
local spark_stun_margin = SparkGear:Slider("Запас радиуса стана", 0, 200, 80, "%d")

SparkBlock:ToolTip("Автоматически кастует Spark Wraith по движущимся или стоящим врагам.")
spark_stun_only:ToolTip("Если включено — Spark Wraith кастуется ТОЛЬКО под врагов в стане (Frostbite, Earth Spike, Shackles, Blast Off). Обычная логика отключается.")
spark_stun_margin:ToolTip("Дополнительный запас радиуса к радиусу способности при касте под стан.")

local state_inv = { lastMove = 0, pendingItem = nil }
local state_mjollnir = { lastMove = 0, pendingItem = nil, lastMoonShardActive = false }
local state_bkb = { pendingItem = nil }
local state_cdswap = { lastMove = 0, pendingItem = nil }

local my_hero = nil
local tempest_double = nil

local active_hooks = {}
local active_rolls = {}
local pudge_last_cd = {}
local enemy_pos_history = {}

local last_hook_order_time = 0
local last_roll_order_time = 0
local last_order_target_pos = nil

local spark_state = {
    next_update = 0,
    next_cast = 0,
    target_history = {},
    next_cleanup = 0,
}

local function localArcWarden()
    local hero = Heroes.GetLocal()
    if not hero then return nil end
    if NPC.GetUnitName(hero) ~= HERO then return nil end
    return hero
end

local function itemAt(unit, slot)
    local ok, item = pcall(NPC.GetItemByIndex, unit, slot)
    return ok and item or nil
end

local function itemCost(item)
    if not item then return 0 end
    local ok, cost = pcall(Item.GetCost, item)
    return ok and math.max(0, cost or 0) or 0
end

local function getItemNameSafe(item)
    if not item then return nil end
    local ok, n = pcall(Ability.GetName, item)
    if ok and n then return n end
    return nil
end

local function getItemDisplayName(item)
    if not item then return nil end
    local ok, n = pcall(Item.GetName, item)
    if ok and n and n ~= "" then return n end
    return getItemNameSafe(item)
end

local function itemIconPath(itemName)
    if not itemName then return nil end
    local short = itemName:gsub("^item_", "")
    return "panorama/images/items/" .. short .. "_png.vtex_c"
end

local function isCourier(npc)
    if not npc then return false end
    local name = NPC.GetUnitName(npc) or ""
    return name == "npc_dota_courier"
        or name == "npc_dota_flying_courier"
        or name == "npc_dota_courier_unknown"
end

local function findItemInInventory(hero, itemName)
    for slot = 0, 5 do
        local item = itemAt(hero, slot)
        if item and getItemNameSafe(item) == itemName then
            return item, slot
        end
    end
    return nil, nil
end

local function findItemInBackpack(hero, itemName)
    for slot = 6, 8 do
        local item = itemAt(hero, slot)
        if item and getItemNameSafe(item) == itemName then
            return item, slot
        end
    end
    return nil, nil
end

local CHEAP_REPLACEABLE_ITEMS = {
    item_branches = true, item_slippers = true, item_mantle = true,
    item_gauntlets = true, item_circlet = true,
}

local NEVER_MOVE_FROM_BACKPACK = {
    item_flask = true, item_tango = true, item_tango_single = true,
    item_clarity = true, item_enchanted_mango = true, item_faerie_fire = true,
    item_magic_stick = true, item_magic_wand = true, item_dust = true,
    item_smoke_of_deceit = true, item_ward_observer = true,
    item_ward_sentry = true, item_ward_dispenser = true,
    item_mjollnir = true,
    item_black_king_bar = true,
    item_swift_blink = true,
    item_sheepstick = true,
}

local NEVER_REPLACE_IN_INVENTORY = {
    item_flask = true, item_tango = true, item_tango_single = true,
    item_clarity = true, item_enchanted_mango = true, item_faerie_fire = true,
    item_bottle = true, item_magic_stick = true, item_magic_wand = true,
    item_dust = true, item_smoke_of_deceit = true, item_ward_observer = true,
    item_ward_sentry = true, item_ward_dispenser = true,
}

local function bestInventoryMove(hero)
    local destination, destinationCost, emptySlot = nil, math.huge, nil
    for slot = 0, 5 do
        local item = itemAt(hero, slot)
        if not item then
            emptySlot = emptySlot or slot
        else
            local name = getItemNameSafe(item) or ""
            local cost = itemCost(item)
            if CHEAP_REPLACEABLE_ITEMS[name] and cost < destinationCost then
                destination, destinationCost = slot, cost
            end
        end
    end
    if destination == nil then
        destination, destinationCost = emptySlot, 0
    end
    if destination == nil then return nil, nil end

    local best, bestCost = nil, destinationCost
    for slot = 6, 8 do
        local item = itemAt(hero, slot)
        local name = getItemNameSafe(item) or ""
        local cost = itemCost(item)
        if item and not NEVER_MOVE_FROM_BACKPACK[name] and cost > bestCost then
            if name == "item_bottle" and not MoveBottle:Get() then
            else
                best, bestCost = item, cost
            end
        end
    end
    return best, destination
end

local function updateInventory(player, hero, now)
    if not AutoInventory:Get() then return end
    if now - state_inv.lastMove < 0.2 then return end

    local item, destination = bestInventoryMove(hero)
    if not item or destination == nil then return end

    local displaced = itemAt(hero, destination)
    local displacedName = displaced and getItemNameSafe(displaced) or nil
    if displaced and (NEVER_REPLACE_IN_INVENTORY[displacedName]
        or not CHEAP_REPLACEABLE_ITEMS[displacedName]) then return end

    local index = Entity.GetIndex(item)
    if state_inv.pendingItem == index then
        local stillInBackpack = false
        for s = 6, 8 do
            local it = itemAt(hero, s)
            if it and Entity.GetIndex(it) == index then
                stillInBackpack = true
                break
            end
        end
        if stillInBackpack then
            state_inv.pendingItem = nil
        else
            return
        end
    end

    state_inv.scriptOrder = true
    local ok, result = pcall(Player.PrepareUnitOrders, player,
        Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_ITEM, destination,
        Vector(0, 0, 0), item,
        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, hero,
        false, false, false, true, "arc_warden_utilities_inventory", false)
    state_inv.scriptOrder = false

    if ok and result ~= false then
        state_inv.lastMove = now
        state_inv.pendingItem = index
    end
end

local function findMoonShardInInventory(hero)
    return findItemInInventory(hero, "item_moon_shard")
end

local function findCourierWithMoonShardNearHero(hero, max_distance)
    local hero_pos = Entity.GetAbsOrigin(hero)
    if not hero_pos then return nil end

    max_distance = max_distance or 600

    for _, courier in ipairs(NPCs.GetAll()) do
        if courier and Entity.IsAlive(courier)
            and isCourier(courier)
            and Entity.IsSameTeam(courier, hero) then
            local courier_pos = Entity.GetAbsOrigin(courier)
            if courier_pos and hero_pos:Distance2D(courier_pos) <= max_distance then
                for slot = 0, 8 do
                    local item = itemAt(courier, slot)
                    if item and getItemNameSafe(item) == "item_moon_shard" then
                        return item, slot, courier
                    end
                end
            end
        end
    end
    return nil, nil, nil
end

local function findEmptyBackpackSlot(hero)
    for slot = 6, 8 do
        if not itemAt(hero, slot) then
            return slot
        end
    end
    return nil
end

local function findEmptyInventorySlot(hero)
    for slot = 0, 5 do
        if not itemAt(hero, slot) then
            return slot
        end
    end
    return nil
end

local function hasMoonShardNearby(hero)
    if findMoonShardInInventory(hero) then return true end
    if findCourierWithMoonShardNearHero(hero, 600) then return true end
    return false
end

local function isItemOnCooldown(item)
    if not item then return false end
    local ok, cd = pcall(Ability.GetCooldownTimeRemaining, item)
    if ok and cd and cd > 0.1 then return true end
    ok, cd = pcall(Ability.GetCooldown, item)
    if ok and cd and cd > 0.1 then return true end
    return false
end

local function moveItemToSlot(player, hero, item, toSlot, orderName, state, now)
    local index = Entity.GetIndex(item)
    if state.pendingItem == index then
        for s = 0, 8 do
            local it = itemAt(hero, s)
            if it and Entity.GetIndex(it) == index then
                if s == toSlot then
                    state.pendingItem = nil
                end
                break
            end
        end
    end

    state_inv.scriptOrder = true
    local ok, result = pcall(Player.PrepareUnitOrders, player,
        Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_ITEM, toSlot,
        Vector(0, 0, 0), item,
        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, hero,
        false, false, false, true, orderName, false)
    state_inv.scriptOrder = false

    if ok and result ~= false then
        state.pendingItem = index
        state_mjollnir.lastMove = now
        return true
    end
    return false
end

local function moveBKBToBackpack(player, hero, now)
    local bkb = findItemInInventory(hero, "item_black_king_bar")
    if not bkb then return false end
    local toSlot = findEmptyBackpackSlot(hero)
    if not toSlot then return false end
    return moveItemToSlot(player, hero, bkb, toSlot, "arc_warden_bkb_backpack", state_bkb, now)
end

local function moveBKBToInventory(player, hero, now)
    local bkb = findItemInBackpack(hero, "item_black_king_bar")
    if not bkb then return false end
    local toSlot = findEmptyInventorySlot(hero)
    if not toSlot then return false end
    return moveItemToSlot(player, hero, bkb, toSlot, "arc_warden_bkb_inventory", state_bkb, now)
end

local function moveMjollnirToBackpack(player, hero, now)
    local mjollnir = findItemInInventory(hero, "item_mjollnir")
    if not mjollnir then return false end
    local toSlot = findEmptyBackpackSlot(hero)
    if not toSlot then return false end
    return moveItemToSlot(player, hero, mjollnir, toSlot, "arc_warden_mjollnir_backpack", state_mjollnir, now)
end

local function moveMjollnirToInventory(player, hero, now)
    local mjollnir = findItemInBackpack(hero, "item_mjollnir")
    if not mjollnir then return false end
    local toSlot = findEmptyInventorySlot(hero)
    if not toSlot then return false end
    return moveItemToSlot(player, hero, mjollnir, toSlot, "arc_warden_mjollnir_inventory", state_mjollnir, now)
end

local function updateMjollnirMove(player, hero, now)
    if not AutoInventory:Get() then return end
    if not MoveMjollnir:Get() and not MoveBKB:Get() then return end

    local moonNearby = hasMoonShardNearby(hero)
    local wasActive = state_mjollnir.lastMoonShardActive
    state_mjollnir.lastMoonShardActive = moonNearby

    if now - state_mjollnir.lastMove < 0.5 then return end

    local bkbInv = findItemInInventory(hero, "item_black_king_bar")
    local bkbBp = findItemInBackpack(hero, "item_black_king_bar")
    local hasBKB = (bkbInv ~= nil) or (bkbBp ~= nil)
    local bkbOnCooldown = bkbInv and isItemOnCooldown(bkbInv) or false

    if bkbBp then bkbOnCooldown = true end

    local useBKB = hasBKB and bkbOnCooldown

    if moonNearby then
        if useBKB then
            moveBKBToBackpack(player, hero, now)
        else
            moveMjollnirToBackpack(player, hero, now)
        end
    elseif wasActive then
        if useBKB then
            moveBKBToInventory(player, hero, now)
        else
            moveMjollnirToInventory(player, hero, now)
        end
    end
end

local function updateCooldownSwap(player, hero, now)
    if not AutoInventory:Get() then return end
    if now - state_cdswap.lastMove < 0.2 then return end

    for _, itemName in ipairs(CooldownSwap:ListEnabled()) do
        local bpItem = findItemInBackpack(hero, itemName)
        if bpItem then
            if not isItemOnCooldown(bpItem) then
                local toSlot = findEmptyInventorySlot(hero)
                if toSlot then
                    local index = Entity.GetIndex(bpItem)
                    if state_cdswap.pendingItem == index then
                        state_cdswap.pendingItem = nil
                    end
                    state_inv.scriptOrder = true
                    local ok, result = pcall(Player.PrepareUnitOrders, player,
                        Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_ITEM, toSlot,
                        Vector(0, 0, 0), bpItem,
                        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, hero,
                        false, false, false, true, "arc_warden_cdswap_restore", false)
                    state_inv.scriptOrder = false
                    if ok and result ~= false then
                        state_cdswap.lastMove = now
                        state_cdswap.pendingItem = index
                        return
                    end
                end
            end
        end

        local invItem = findItemInInventory(hero, itemName)
        if invItem and isItemOnCooldown(invItem) then
            local toSlot = findEmptyBackpackSlot(hero)
            if toSlot then
                local index = Entity.GetIndex(invItem)
                if state_cdswap.pendingItem == index then
                    state_cdswap.pendingItem = nil
                end
                state_inv.scriptOrder = true
                local ok, result = pcall(Player.PrepareUnitOrders, player,
                    Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_ITEM, toSlot,
                    Vector(0, 0, 0), invItem,
                    Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, hero,
                    false, false, false, true, "arc_warden_cdswap_move", false)
                state_inv.scriptOrder = false
                if ok and result ~= false then
                    state_cdswap.lastMove = now
                    state_cdswap.pendingItem = index
                    return
                end
            end
        end
    end
end

local function IsActiveGameCondition()
    local local_h = Heroes.GetLocal()
    if not local_h or NPC.GetUnitName(local_h) ~= HERO then
        return false, nil, false, false
    end

    local has_pudge, has_es = false, false
    for _, h in ipairs(Heroes.GetAll()) do
        if not Entity.IsSameTeam(local_h, h) then
            local uname = NPC.GetUnitName(h)
            if uname == "npc_dota_hero_pudge" then has_pudge = true
            elseif uname == "npc_dota_hero_earth_spirit" then has_es = true end
        end
    end
    if not has_pudge and not has_es then return false, nil, false, false end
    return true, local_h, has_pudge, has_es
end

local function GetExistingClone(main_arc)
    if not main_arc then return nil end
    local tempest_ab = NPC.GetAbility(main_arc, "arc_warden_tempest_double")
    if tempest_ab and CustomEntities and CustomEntities.GetTempestDouble then
        local c = CustomEntities.GetTempestDouble(tempest_ab)
        if c and Entity.IsAlive(c) and not Entity.IsDormant(c) then return c end
    end
    for _, h in ipairs(Heroes.GetAll()) do
        if h ~= main_arc and Entity.IsSameTeam(main_arc, h)
            and Entity.IsAlive(h) and not Entity.IsDormant(h)
            and NPC.GetUnitName(h) == HERO then
            return h
        end
    end
    return nil
end

local function CanCastTempest(hero)
    if not hero or not tempest_double or not Entity.IsAlive(hero) then return false end
    if not Ability.IsCastable(tempest_double, NPC.GetMana(hero)) then return false end
    if NPC.IsStunned(hero) or NPC.IsSilenced(hero) then return false end
    return true
end

local function CanOrderUnit(unit)
    if not unit or not Entity.IsAlive(unit) or Entity.IsDormant(unit) then return false end
    if NPC.IsStunned(unit) then return false end
    if NPC.HasState(unit, Enum.ModifierState.MODIFIER_STATE_ROOTED) then return false end
    return true
end

local function MoveCloneTo(clone, pos)
    if not clone or not pos then return end
    NPC.MoveTo(clone, pos, false, false, nil, true, "ArcBlockerCloneMove")
    local player = Players.GetLocal()
    if player then
        Player.PrepareUnitOrders(player,
            Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION, nil, pos, nil,
            Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
            clone, false, false, nil, true)
    end
end

local function CastTempestAt(hero, pos)
    if not tempest_double or not hero then return end
    local beh = Ability.GetBehavior(tempest_double) or 0
    local is_point = (beh % 32) >= 16
    local player = Players.GetLocal()
    if is_point and pos then
        Ability.CastPosition(tempest_double, pos, false, false, true, "ArcBlockerTempest")
        if player then
            Player.PrepareUnitOrders(player,
                Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION, nil, pos, tempest_double,
                Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                hero, false, false, nil, true)
        end
    else
        Ability.CastNoTarget(tempest_double, false, false, true, "ArcBlockerTempest")
        if player then
            Player.PrepareUnitOrders(player,
                Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET, nil, Vector(0, 0, 0), tempest_double,
                Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                hero, false, false, nil, true)
        end
    end
end

local function ClampToCastRange(center, target, cast_range)
    local offset = target - center
    local dist = offset:Length2D()
    if dist <= cast_range then return target end
    if dist < 0.001 then return center end
    return center + offset:Normalized() * cast_range
end

local function GetClosestPointOnSegment(point, seg_a, seg_b)
    local ab = seg_b - seg_a
    local ab_len2 = ab:Dot(ab)
    if ab_len2 < 1.0 then return seg_a, 0 end
    local ap = point - seg_a
    local t = math.max(0.0, math.min(1.0, ap:Dot(ab) / ab_len2))
    return seg_a + ab * t, t
end

local function FindPudge()
    for _, h in ipairs(Heroes.GetAll()) do
        if NPC.GetUnitName(h) == "npc_dota_hero_pudge"
            and Entity.IsAlive(h) and not Entity.IsDormant(h) then
            return h
        end
    end
    for _, h in ipairs(Heroes.GetAll()) do
        if NPC.GetUnitName(h) == "npc_dota_hero_pudge" then return h end
    end
    return nil
end

function script.OnPrepareUnitOrders(data)
    if not data or not data.ability then return true end
    if not IsActiveGameCondition() then return true end
    local aname = Ability.GetName(data.ability)
    local cur_time = GameRules.GetGameTime()

    if aname == "pudge_meat_hook" and data.npc then
        local p_pos = Entity.GetAbsOrigin(data.npc)
        local target_pos = data.position or (data.target and Entity.GetAbsOrigin(data.target))
        if p_pos and target_pos then
            local diff = target_pos - p_pos
            if diff:Length2D() > 10 then
                local dir = diff:Normalized()
                local hook_range = Ability.GetCastRange(data.ability) or 1300
                if hook_range < 500 then hook_range = 1300 end
                local p_idx = Entity.GetIndex(data.npc)
                active_hooks[p_idx] = {
                    origin = p_pos, dir = dir, speed = 1450, max_dist = hook_range,
                    created_time = cur_time,
                    expire_time = cur_time + (hook_range / 1450) + 0.4,
                    source_idx = p_idx
                }
            end
        end
    elseif aname == "earth_spirit_rolling_boulder" and data.npc then
        local es_pos = Entity.GetAbsOrigin(data.npc)
        local target_pos = data.position or (data.target and Entity.GetAbsOrigin(data.target))
        if es_pos and target_pos then
            local diff = target_pos - es_pos
            if diff:Length2D() > 10 then
                local dir = diff:Normalized()
                local e_idx = Entity.GetIndex(data.npc)
                active_rolls[e_idx] = {
                    enemy = data.npc, dir = dir,
                    block_pos = es_pos + dir * 300,
                    expire_time = cur_time + 1.2
                }
            end
        end
    end
    return true
end

function script.OnLinearProjectileCreate(data)
    if not data then return end
    local name = string.lower(data.fullName or data.name or "")
    local is_hook = string.find(name, "hook") or string.find(name, "meat_hook")
    if not is_hook and data.source
        and NPC.GetUnitName(data.source) == "npc_dota_hero_pudge" then
        is_hook = true
    end
    if not is_hook then return end

    local pudge = data.source or FindPudge()
    local p_idx = pudge and Entity.GetIndex(pudge) or 1
    local origin = data.origin or (pudge and Entity.GetAbsOrigin(pudge))
    local vel = data.velocity
    local speed = data.maxSpeed or (vel and vel:Length2D()) or 1450
    local dist = data.distance or 1300
    if dist < 400 then dist = 1300 end
    local dir = nil
    if vel and vel:Length2D() > 10 then dir = vel:Normalized() end
    if not dir and pudge then
        local rot = Entity.GetRotation(pudge)
        if rot then
            local rad = rot:GetYaw() * math.pi / 180
            dir = Vector(math.cos(rad), math.sin(rad), 0)
        end
    end
    origin = origin or Vector(0, 0, 0)
    dir = dir or Vector(1, 0, 0)
    local cur_time = GameRules.GetGameTime()
    active_hooks[p_idx] = {
        origin = origin, dir = dir, speed = speed, max_dist = dist,
        created_time = cur_time,
        expire_time = cur_time + (dist / speed) + 0.3,
        source_idx = p_idx
    }
end

function script.OnLinearProjectileDestroy(data)
    if not data then return end
    local pudge = FindPudge()
    if pudge then active_hooks[Entity.GetIndex(pudge)] = nil end
end

function script.OnParticleCreate(data)
    if not data then return end
    local name = string.lower(data.fullName or data.name or "")
    if string.find(name, "hook") then
        local pudge = (data.entity and NPC.GetUnitName(data.entity) == "npc_dota_hero_pudge" and data.entity) or FindPudge()
        local p_idx = pudge and Entity.GetIndex(pudge) or 1
        local origin = (data.entity and Entity.GetAbsOrigin(data.entity)) or (pudge and Entity.GetAbsOrigin(pudge))
        local cur_time = GameRules.GetGameTime()
        if not active_hooks[p_idx] or (cur_time - active_hooks[p_idx].created_time > 0.4) then
            active_hooks[p_idx] = {
                particle_index = data.index, origin = origin, target_pos = nil,
                speed = 1450, max_dist = 1300,
                created_time = cur_time, expire_time = cur_time + 1.4,
                source_idx = p_idx
            }
        else
            active_hooks[p_idx].particle_index = data.index
        end
    end
end

function script.OnParticleUpdate(data)
    if not data then return end
    for p_idx, hook in pairs(active_hooks) do
        if hook.particle_index == data.index then
            if data.controlPoint == 0 then
                hook.origin = data.position
            elseif data.controlPoint == 1 then
                hook.target_pos = data.position
                if hook.origin and hook.target_pos then
                    local diff = hook.target_pos - hook.origin
                    local len = diff:Length2D()
                    if len > 50 then
                        hook.dir = diff:Normalized()
                        hook.max_dist = math.min(1450, len)
                    end
                end
            end
            break
        end
    end
end

function script.OnParticleUpdateFallback(data)
    if not data then return end
    script.OnParticleUpdate(data)
end

function script.OnParticleDestroy(data)
    if not data then return end
    for p_idx, hook in pairs(active_hooks) do
        if hook.particle_index == data.index then
            active_hooks[p_idx] = nil
            break
        end
    end
end

function script.OnModifierCreate(entity, modifier)
    if not entity or not modifier then return end
    if NPC.GetUnitName(entity) == "npc_dota_hero_earth_spirit" then
        local mname = string.lower(Modifier.GetName(modifier) or "")
        if string.find(mname, "rolling_boulder") or string.find(mname, "earth_spirit_roll") then
            local rot = Entity.GetRotation(entity)
            local dir = nil
            if rot then
                local rad = rot:GetYaw() * math.pi / 180
                dir = Vector(math.cos(rad), math.sin(rad), 0)
            end
            local es_pos = Entity.GetAbsOrigin(entity)
            if dir and es_pos then
                local cur_time = GameRules.GetGameTime()
                local e_idx = Entity.GetIndex(entity)
                active_rolls[e_idx] = {
                    enemy = entity, dir = dir,
                    block_pos = es_pos + dir * 300,
                    expire_time = cur_time + 1.2
                }
            end
        end
    end
end

function script.OnModifierDestroy(entity, modifier)
    if not entity or not modifier then return end
    if NPC.GetUnitName(entity) == "npc_dota_hero_earth_spirit" then
        local mname = string.lower(Modifier.GetName(modifier) or "")
        if string.find(mname, "rolling_boulder") or string.find(mname, "earth_spirit_roll") then
            active_rolls[Entity.GetIndex(entity)] = nil
        end
    end
end

function script.OnUnitAnimation(data)
    if not data or not data.unit then return end
    local uname = NPC.GetUnitName(data.unit)
    local cur_time = GameRules.GetGameTime()

    if uname == "npc_dota_hero_pudge" then
        local seq = string.lower(data.sequenceName or "")
        if string.find(seq, "hook") or string.find(seq, "cast1") then
            local p_idx = Entity.GetIndex(data.unit)
            if not active_hooks[p_idx] or (cur_time - active_hooks[p_idx].created_time > 0.4) then
                local rot = Entity.GetRotation(data.unit)
                if rot then
                    local rad = rot:GetYaw() * math.pi / 180
                    local dir = Vector(math.cos(rad), math.sin(rad), 0)
                    local p_pos = Entity.GetAbsOrigin(data.unit)
                    active_hooks[p_idx] = {
                        origin = p_pos, dir = dir, speed = 1450, max_dist = 1300,
                        created_time = cur_time, expire_time = cur_time + 1.3,
                        source_idx = p_idx
                    }
                end
            end
        end
    elseif uname == "npc_dota_hero_earth_spirit" then
        local seq = string.lower(data.sequenceName or "")
        if string.find(seq, "roll") or string.find(seq, "boulder") then
            local rot = Entity.GetRotation(data.unit)
            if rot then
                local rad = rot:GetYaw() * math.pi / 180
                local dir = Vector(math.cos(rad), math.sin(rad), 0)
                local es_pos = Entity.GetAbsOrigin(data.unit)
                local e_idx = Entity.GetIndex(data.unit)
                active_rolls[e_idx] = {
                    enemy = data.unit, dir = dir,
                    block_pos = es_pos + dir * 300,
                    expire_time = cur_time + 1.2
                }
            end
        end
    end
end

local function CleanStaleTrackers(cur_time)
    for k, hook in pairs(active_hooks) do
        if cur_time > hook.expire_time then active_hooks[k] = nil end
    end
    for k, roll in pairs(active_rolls) do
        if cur_time > roll.expire_time then active_rolls[k] = nil end
    end
end

local function TrackProjectilesInUpdate(cur_time)
    if LinearProjectiles and LinearProjectiles.GetAll then
        local projectiles = LinearProjectiles.GetAll()
        if projectiles then
            for _, proj in pairs(projectiles) do
                local src = proj.source
                if src and NPC.GetUnitName(src) == "npc_dota_hero_pudge" then
                    local vel = proj.velocity
                    if vel and vel:Length2D() > 100 then
                        local dir = vel:Normalized()
                        local origin = proj.start_position or proj.position
                        local p_idx = Entity.GetIndex(src)
                        active_hooks[p_idx] = {
                            origin = origin, dir = dir,
                            speed = proj.max_speed or vel:Length2D(),
                            max_dist = proj.max_dist or 1300,
                            created_time = cur_time, expire_time = cur_time + 1.2,
                            source_idx = p_idx
                        }
                    end
                end
            end
        end
    end

    for _, pudge in ipairs(Heroes.GetAll()) do
        if NPC.GetUnitName(pudge) == "npc_dota_hero_pudge"
            and Entity.IsAlive(pudge) and not Entity.IsDormant(pudge) then
            local hook_ab = NPC.GetAbility(pudge, "pudge_meat_hook")
            if hook_ab then
                local p_idx = Entity.GetIndex(pudge)
                local cd = Ability.GetCooldown(hook_ab) or 0
                local prev_cd = pudge_last_cd[p_idx] or 0
                pudge_last_cd[p_idx] = cd
                local in_phase = Ability.IsInAbilityPhase(hook_ab)
                local just_cast = (prev_cd == 0 and cd > 0) or (cd > prev_cd + 1.0)

                if in_phase or just_cast then
                    if not active_hooks[p_idx] or (cur_time - active_hooks[p_idx].created_time > 0.4) then
                        local p_pos = Entity.GetAbsOrigin(pudge)
                        local rot = Entity.GetRotation(pudge)
                        local dir = nil
                        if rot then
                            local rad = rot:GetYaw() * math.pi / 180
                            dir = Vector(math.cos(rad), math.sin(rad), 0)
                        end
                        if dir and p_pos then
                            local hook_range = Ability.GetCastRange(hook_ab) or 1300
                            if hook_range < 500 then hook_range = 1300 end
                            active_hooks[p_idx] = {
                                origin = p_pos, dir = dir, speed = 1450,
                                max_dist = hook_range,
                                created_time = cur_time,
                                expire_time = cur_time + (hook_range / 1450) + 0.3,
                                source_idx = p_idx
                            }
                        end
                    end
                end
            end
        end
    end
end

local function GetHookCurrentPos(hook, cur_time)
    local elapsed = math.max(0, cur_time - hook.created_time)
    local dist = math.min(hook.max_dist, hook.speed * elapsed)
    return hook.origin + hook.dir * dist, dist
end

local function ProcessHookInterceptions(cur_time)
    if not hook_enabled:Get() then return end
    if not my_hero or not Entity.IsAlive(my_hero) then return end

    local cast_range = Ability.GetCastRange(tempest_double) or 700
    if cast_range < 100 then cast_range = 700 end
    local my_pos = Entity.GetAbsOrigin(my_hero)
    local clone = GetExistingClone(my_hero)
    local can_use_clone = hook_use_clone:Get() and CanOrderUnit(clone)
    local can_cast = hook_cast_tempest:Get() and CanCastTempest(my_hero)
    if not can_use_clone and not can_cast then return end

    local targets = {}
    targets[#targets + 1] = { hero = my_hero, is_me = true, pos = my_pos }

    local local_p = Heroes.GetLocal()
    if local_p and local_p ~= my_hero and Entity.IsAlive(local_p) then
        targets[#targets + 1] = { hero = local_p, is_me = true, pos = Entity.GetAbsOrigin(local_p) }
    end

    if hook_save_allies:Get() then
        for _, ally in ipairs(Heroes.GetAll()) do
            if ally ~= my_hero and ally ~= local_p
                and Entity.IsSameTeam(my_hero, ally)
                and Entity.IsAlive(ally) and not Entity.IsDormant(ally)
                and not NPC.IsIllusion(ally) then
                if clone == nil or ally ~= clone then
                    targets[#targets + 1] = { hero = ally, is_me = false, pos = Entity.GetAbsOrigin(ally) }
                end
            end
        end
    end

    local priority_mode = hook_priority:Get()

    for _, hook in pairs(active_hooks) do
        if hook.origin and hook.dir then
            local current_pos, dist_traveled = GetHookCurrentPos(hook, cur_time)
            local rem_dist = hook.max_dist - dist_traveled
            if rem_dist > 20 then
                local threats = {}
                for _, candidate in ipairs(targets) do
                    local h_pos = candidate.pos
                    local v_to_hero = h_pos - current_pos
                    local t_proj = v_to_hero:Dot(hook.dir)
                    if t_proj > -30 and t_proj <= rem_dist + 50 then
                        local p_closest = current_pos + hook.dir * math.max(0, t_proj)
                        local lateral_dist = (h_pos - p_closest):Length2D()
                        if lateral_dist <= 175 then
                            local time_to_hit = math.max(0, t_proj) / hook.speed
                            local dist_tip = t_proj
                            local lead = math.min(220, math.max(70, dist_tip * 0.45))
                            local intercept_pos = p_closest - hook.dir * lead
                            local can_intercept, intercept_type, spawn_point = false, nil, nil

                            if can_use_clone then
                                local clone_pos = Entity.GetAbsOrigin(clone)
                                local clone_speed = NPC.GetMoveSpeed(clone)
                                local dist_to_intercept = (intercept_pos - clone_pos):Length2D()
                                if (dist_to_intercept / math.max(1, clone_speed)) <= time_to_hit + 0.35 then
                                    can_intercept, intercept_type = true, "clone"
                                end
                            end

                            if not can_intercept and can_cast then
                                local dist_me = (intercept_pos - my_pos):Length2D()
                                if dist_me <= cast_range then
                                    can_intercept, intercept_type, spawn_point = true, "cast", intercept_pos
                                else
                                    local pt_on_ray = GetClosestPointOnSegment(my_pos, current_pos, p_closest)
                                    if (pt_on_ray - my_pos):Length2D() <= cast_range
                                        and (pt_on_ray - current_pos):Length2D() >= 50 then
                                        can_intercept, intercept_type, spawn_point = true, "cast", pt_on_ray
                                    end
                                end
                            end

                            if can_intercept then
                                threats[#threats + 1] = {
                                    candidate = candidate, time_to_hit = time_to_hit,
                                    intercept_pos = intercept_pos,
                                    intercept_type = intercept_type, spawn_point = spawn_point
                                }
                            end
                        end
                    end
                end

                if #threats > 0 then
                    table.sort(threats, function(a, b)
                        if priority_mode == 0 then
                            if a.candidate.is_me ~= b.candidate.is_me then return a.candidate.is_me end
                        else
                            if a.candidate.is_me ~= b.candidate.is_me then return not a.candidate.is_me end
                        end
                        return a.time_to_hit < b.time_to_hit
                    end)

                    local best_threat = threats[1]
                    if cur_time - last_hook_order_time > 0.08
                        or (last_order_target_pos
                            and (best_threat.intercept_pos - last_order_target_pos):Length2D() > 50) then
                        if best_threat.intercept_type == "clone" then
                            MoveCloneTo(clone, best_threat.intercept_pos)
                            last_hook_order_time = cur_time
                            last_order_target_pos = best_threat.intercept_pos
                        elseif best_threat.intercept_type == "cast" and best_threat.spawn_point then
                            CastTempestAt(my_hero, best_threat.spawn_point)
                            last_hook_order_time = cur_time
                            last_order_target_pos = best_threat.spawn_point
                        end
                    end
                end
            end
        end
    end
end

local function IsEarthSpiritRolling(enemy, cur_time)
    if not enemy or not Entity.IsAlive(enemy) or Entity.IsDormant(enemy) then return false, nil, 0 end
    local e_idx = Entity.GetIndex(enemy)
    local cur_pos = Entity.GetAbsOrigin(enemy)
    local dir, speed = nil, 0

    local hist = enemy_pos_history[e_idx]
    if hist and cur_pos then
        local dt = cur_time - hist.time
        if dt > 0.005 and dt < 0.5 then
            local delta = cur_pos - hist.pos
            speed = delta:Length2D() / dt
            if speed > 200 then dir = delta:Normalized() end
        end
    end
    if cur_pos then enemy_pos_history[e_idx] = { pos = cur_pos, time = cur_time } end

    local rot = Entity.GetRotation(enemy)
    if not dir and rot then
        local rad = rot:GetYaw() * math.pi / 180
        dir = Vector(math.cos(rad), math.sin(rad), 0)
    end

    local roll_ab = NPC.GetAbility(enemy, "earth_spirit_rolling_boulder")
    local is_charging = roll_ab and Ability.IsInAbilityPhase(roll_ab)
    local has_mod = false
    for _, mod in ipairs(NPC.GetModifiers(enemy)) do
        local mname = string.lower(Modifier.GetName(mod) or "")
        if string.find(mname, "rolling_boulder") or string.find(mname, "earth_spirit_roll") then
            has_mod = true
            break
        end
    end
    local is_speed_rolling = (speed > 450) and (roll_ab and (Ability.GetCooldown(roll_ab) or 0) > 0)
    if not has_mod and not is_charging and not is_speed_rolling then return false, nil, 0 end
    return true, dir, math.max(800, speed)
end

local function ProcessEarthSpiritRolls(cur_time)
    if not roll_enabled:Get() then return end
    if not my_hero or not Entity.IsAlive(my_hero) then return end

    local cast_range = Ability.GetCastRange(tempest_double) or 700
    if cast_range < 100 then cast_range = 700 end
    local my_pos = Entity.GetAbsOrigin(my_hero)
    local clone = GetExistingClone(my_hero)
    local can_use_clone = roll_use_clone:Get() and CanOrderUnit(clone)
    local can_cast = roll_cast_tempest:Get() and CanCastTempest(my_hero)
    if not can_use_clone and not can_cast then return end

    local mode = roll_mode:Get()

    for _, enemy in ipairs(Heroes.GetAll()) do
        if enemy and not Entity.IsSameTeam(my_hero, enemy)
            and Entity.IsAlive(enemy) and not Entity.IsDormant(enemy)
            and NPC.GetUnitName(enemy) == "npc_dota_hero_earth_spirit" then
            local is_rolling, dir, roll_speed = IsEarthSpiritRolling(enemy, cur_time)
            local e_idx = Entity.GetIndex(enemy)

            if is_rolling and dir then
                local es_pos = Entity.GetAbsOrigin(enemy)
                local to_me = my_pos - es_pos
                local dist_to_me = to_me:Length2D()

                local is_towards_me = false
                local t_proj_me = to_me:Dot(dir)
                if t_proj_me > 0 and t_proj_me <= 1600 then
                    if (my_pos - (es_pos + dir * t_proj_me)):Length2D() <= 220 then
                        is_towards_me = true
                    end
                end

                local is_towards_clone = false
                if clone and Entity.IsAlive(clone) then
                    local clone_pos = Entity.GetAbsOrigin(clone)
                    local to_clone = clone_pos - es_pos
                    local t_proj_c = to_clone:Dot(dir)
                    if t_proj_c > 0 and t_proj_c <= 1600 then
                        if (clone_pos - (es_pos + dir * t_proj_c)):Length2D() <= 220 then
                            is_towards_clone = true
                        end
                    end
                end

                local is_away_from_me = false
                if dist_to_me <= 1100 then
                    local to_me_norm = dist_to_me > 1 and (to_me / dist_to_me) or dir
                    if dir:Dot(to_me_norm) < -0.2 then is_away_from_me = true end
                end

                local trigger = false
                if mode == 0 then trigger = is_towards_me or is_towards_clone
                elseif mode == 1 then trigger = is_away_from_me
                else trigger = is_towards_me or is_towards_clone or is_away_from_me or (dist_to_me <= (cast_range + 250)) end

                if trigger then
                    local lead = math.min(360, math.max(160, roll_speed * 0.18 + 40))
                    local block_pos = es_pos + dir * lead
                    active_rolls[e_idx] = { block_pos = block_pos, dir = dir, expire_time = cur_time + 0.35 }

                    if cur_time - last_roll_order_time > 0.10
                        or (last_order_target_pos and (block_pos - last_order_target_pos):Length2D() > 50) then
                        local handled = false
                        if can_use_clone then
                            local clone_pos = Entity.GetAbsOrigin(clone)
                            local dist_clone = (block_pos - clone_pos):Length2D()
                            local clone_speed = NPC.GetMoveSpeed(clone)
                            local time_to_block = lead / math.max(1, roll_speed)
                            if (dist_clone / math.max(1, clone_speed)) <= (time_to_block + 0.15) then
                                MoveCloneTo(clone, block_pos)
                                last_roll_order_time = cur_time
                                last_order_target_pos = block_pos
                                handled = true
                            end
                        end
                        if not handled and can_cast then
                            local dist_to_block = (block_pos - my_pos):Length2D()
                            if dist_to_block <= (cast_range + 25) then
                                local spawn_pos = ClampToCastRange(my_pos, block_pos, cast_range)
                                CastTempestAt(my_hero, spawn_pos)
                                last_roll_order_time = cur_time
                                last_order_target_pos = spawn_pos
                            end
                        end
                    end
                else
                    active_rolls[e_idx] = nil
                end
            else
                active_rolls[e_idx] = nil
            end
        end
    end
end

local K = {
    ABILITY_NAME = "arc_warden_spark_wraith",
    DEFAULT_ACTIVATION_DELAY = 1.5,
    DEFAULT_RADIUS = 375.0,
    SAFETY_MARGIN = 50.0,
    UPDATE_INTERVAL = 0.08,
    CAST_LOCK = 0.25,
    HISTORY_CLEANUP = 5.0,
    WORK_UNTIL_MINUTE = 10,
    MIN_MOVE_DIST = 40,
    STABLE_TIME = 0.35,
    STAND_TIME = 0.35,
}

local STUN_MODIFIERS = {
    "modifier_crystal_maiden_frostbite",
    "modifier_crystal_maiden_frostbite_freeze",
    "modifier_lion_impale",
    "modifier_lion_impale_stun",
    "modifier_shadow_shaman_shackles",
    "modifier_techies_blast_off",
    "modifier_techies_blast_off_leap",
    "modifier_stunned",
}

local function isHeroUnderStun(hero)
    if not hero then return false end
    for _, mod in ipairs(STUN_MODIFIERS) do
        local ok, has = pcall(NPC.HasModifier, hero, mod)
        if ok and has then return true end
    end
    return false
end

local function spark_get_game_time()
    return math.max(0, GameRules.GetDOTATime(false, false))
end

local function spark_is_local_arc_warden(hero)
    return hero and Entity.IsAlive(hero) and NPC.GetUnitName(hero) == HERO
end

local function spark_get_special_value(ability, name, fallback)
    local value = Ability.GetLevelSpecialValueFor(ability, name)
    if value and value > 0 then return value end
    return fallback
end

local function spark_is_valid_enemy(hero, local_hero)
    return hero and hero ~= local_hero
        and Entity.IsAlive(hero) and not Entity.IsDormant(hero)
        and NPC.IsHero(hero) and not NPC.IsIllusion(hero)
        and NPC.IsVisible(hero) and not Entity.IsSameTeam(hero, local_hero)
end

local function spark_has_nearby_enemy_creep(local_hero, position, radius)
    local check_radius = math.max(radius, spark_creep_rad:Get())
    for _, npc in ipairs(NPCs.GetAll()) do
        if npc and Entity.IsAlive(npc) and not Entity.IsDormant(npc)
            and NPC.IsCreep(npc) and not Entity.IsSameTeam(npc, local_hero)
            and Entity.GetAbsOrigin(npc):Distance2D(position) <= check_radius then
            return true
        end
    end
    return false
end

local function spark_find_stunned_target(local_hero, ability)
    local local_pos = Entity.GetAbsOrigin(local_hero)
    if not local_pos then return nil, nil end

    local cast_range = Ability.GetCastRange(ability)
    if not cast_range or cast_range < 100 then return nil, nil end

    local radius = spark_get_special_value(ability, "radius", K.DEFAULT_RADIUS)
    local margin = spark_stun_margin:Get() or 0
    local effective_radius = radius + margin

    local best_target, best_pos, best_dist = nil, nil, math.huge

    for _, hero in ipairs(Heroes.GetAll()) do
        if spark_is_valid_enemy(hero, local_hero) and isHeroUnderStun(hero) then
            local h_pos = Entity.GetAbsOrigin(hero)
            if h_pos then
                local dist = local_pos:Distance2D(h_pos)
                if dist <= cast_range and dist < best_dist then
                    if not spark_has_nearby_enemy_creep(local_hero, h_pos, effective_radius) then
                        best_target = hero
                        best_pos = h_pos
                        best_dist = dist
                    end
                end
            end
        end
    end

    return best_target, best_pos
end

local function spark_update_target_history(target, now)
    local target_id = Entity.GetIndex(target)
    local pos = Entity.GetAbsOrigin(target)
    local history = spark_state.target_history[target_id]
    if not history then
        history = { positions = {}, times = {}, last_update = now }
        spark_state.target_history[target_id] = history
    end
    table.insert(history.positions, pos)
    table.insert(history.times, now)
    history.last_update = now
    while #history.positions > 15 do
        table.remove(history.positions, 1)
        table.remove(history.times, 1)
    end
end

local function spark_is_stable_movement(target, now)
    local target_id = Entity.GetIndex(target)
    local history = spark_state.target_history[target_id]
    if not history or #history.positions < 3 then return false end
    if now - history.times[1] < K.STABLE_TIME then return false end

    local oldest_pos = history.positions[1]
    local current_pos = history.positions[#history.positions]
    if oldest_pos:Distance2D(current_pos) < K.MIN_MOVE_DIST then return false end

    local directions = {}
    for i = 1, #history.positions - 1 do
        table.insert(directions, (history.positions[i + 1] - history.positions[i]):Normalized())
    end
    if #directions < 2 then return false end

    local avg_direction = Vector(0, 0, 0)
    for _, dir in ipairs(directions) do avg_direction = avg_direction + dir end
    avg_direction = avg_direction:Scaled(1.0 / #directions):Normalized()

    for _, dir in ipairs(directions) do
        if dir:Dot2D(avg_direction) < (1.0 - spark_dir_var:Get() / 100.0) then return false end
    end
    return true, avg_direction
end

local function spark_is_stationary(target, now)
    local target_id = Entity.GetIndex(target)
    local history = spark_state.target_history[target_id]
    if not history or #history.positions < 3 then return false end
    if now - history.times[1] < K.STAND_TIME then return false end
    return history.positions[1]:Distance2D(history.positions[#history.positions]) < K.MIN_MOVE_DIST
end

local function spark_get_target_position(local_hero, target, ability, now)
    local local_pos = Entity.GetAbsOrigin(local_hero)
    local target_pos = Entity.GetAbsOrigin(target)
    local cast_range = Ability.GetCastRange(ability)
    local activation_delay = spark_get_special_value(ability, "base_activation_delay", K.DEFAULT_ACTIVATION_DELAY)
    local radius = spark_get_special_value(ability, "radius", K.DEFAULT_RADIUS)
    local total_delay = math.max(0, Ability.GetCastPoint(ability)) + activation_delay
    local target_speed = math.max(0, NPC.GetMoveSpeed(target))

    local is_stable, stable_direction = spark_is_stable_movement(target, now)
    if is_stable and stable_direction and target_speed > 0 then
        local cast_position = target_pos + stable_direction:Scaled(target_speed * total_delay)
        local prediction_error = target_speed * 0.08
        return prediction_error + K.SAFETY_MARGIN <= radius
            and local_pos:Distance2D(cast_position) <= cast_range
            and cast_position
    end
    if spark_is_stationary(target, now) then
        return local_pos:Distance2D(target_pos) <= cast_range and target_pos
    end
    return nil
end

local function spark_find_target(local_hero, ability, now)
    local best_target, best_target_position, best_distance = nil, nil, math.huge
    local local_pos = Entity.GetAbsOrigin(local_hero)
    local radius = spark_get_special_value(ability, "radius", K.DEFAULT_RADIUS)

    for _, hero in ipairs(Heroes.GetAll()) do
        if spark_is_valid_enemy(hero, local_hero) then
            spark_update_target_history(hero, now)
            local cast_position = spark_get_target_position(local_hero, hero, ability, now)
            local distance = cast_position and local_pos:Distance2D(cast_position) or math.huge
            if cast_position
                and not spark_has_nearby_enemy_creep(local_hero, cast_position, radius)
                and distance < best_distance then
                best_target, best_distance, best_target_position = hero, distance, cast_position
            end
        end
    end
    return best_target, best_target_position
end

local function updateSparkWraith(now)
    if not SparkBlock:Get() then return end

    if spark_mode:Get() == 1
        and (not spark_cast_key:IsDown() or Input.IsInputCaptured() or Input.IsPopupOpen()) then
        return
    end

    local dota_time = spark_get_game_time()
    if dota_time < spark_state.next_update then return end
    spark_state.next_update = dota_time + K.UPDATE_INTERVAL
    if dota_time >= K.WORK_UNTIL_MINUTE * 60 or dota_time < 0 or GameRules.IsPaused() then return end

    if dota_time >= spark_state.next_cleanup then
        for target_id, history in pairs(spark_state.target_history) do
            if dota_time - history.last_update > K.HISTORY_CLEANUP then
                spark_state.target_history[target_id] = nil
            end
        end
        spark_state.next_cleanup = dota_time + K.HISTORY_CLEANUP
    end

    local local_hero = Heroes.GetLocal()
    if not spark_is_local_arc_warden(local_hero) or dota_time < spark_state.next_cast then return end

    local ability = NPC.GetAbility(local_hero, K.ABILITY_NAME)
    if not ability or not Ability.IsReady(ability)
        or not Ability.IsCastable(ability, NPC.GetMana(local_hero)) then
        return
    end

    if spark_stun_only:Get() then
        local stun_target, stun_pos = spark_find_stunned_target(local_hero, ability)
        if stun_target and stun_pos then
            Ability.CastPosition(ability, stun_pos, false, false, true, "arc_warden_spark_wraith_stun")
            spark_state.next_cast = dota_time + K.CAST_LOCK
        end
        return
    end

    local target, cast_position = spark_find_target(local_hero, ability, dota_time)
    if target and cast_position then
        Ability.CastPosition(ability, cast_position, false, false, true, "arc_warden_spark_wraith")
        spark_state.next_cast = dota_time + K.CAST_LOCK
    end
end

function script.OnUpdate()
    local hero = localArcWarden()
    if not hero or not Entity.IsAlive(hero) then return end
    local player = Players.GetLocal()
    if not player then return end

    local now = GameRules.GetGameTime()

    updateInventory(player, hero, now)
    updateMjollnirMove(player, hero, now)
    updateCooldownSwap(player, hero, now)

    local is_active, _, has_pudge, has_es = IsActiveGameCondition()
    if is_active then
        my_hero = hero
        tempest_double = NPC.GetAbility(my_hero, "arc_warden_tempest_double")
        if tempest_double then
            CleanStaleTrackers(now)
            if has_pudge then
                TrackProjectilesInUpdate(now)
                ProcessHookInterceptions(now)
            end
            if has_es then
                ProcessEarthSpiritRolls(now)
            end
        end
    end

    updateSparkWraith(now)
end

function script.OnDraw()
    if not my_hero or not Entity.IsAlive(my_hero) then return end

    if hook_draw:Get() then
        local cur_time = GameRules.GetGameTime()
        for _, hook in pairs(active_hooks) do
            if hook.origin and hook.dir then
                local cur_p = GetHookCurrentPos(hook, cur_time)
                local end_p = hook.origin + hook.dir * hook.max_dist
                local s_cur, v_cur = Render.WorldToScreen(cur_p)
                local s_end, v_end = Render.WorldToScreen(end_p)
                if v_cur and v_end then
                    Render.Line(s_cur, s_end, Color(255, 80, 80, 200), 2)
                    Render.Circle(s_cur, 8, Color(255, 220, 50, 255), 2)
                end
            end
        end
    end

    if roll_draw:Get() then
        for _, roll in pairs(active_rolls) do
            if roll.block_pos and roll.dir then
                local s_pos, vis = Render.WorldToScreen(roll.block_pos)
                if vis then
                    Render.Circle(s_pos, 14, Color(255, 140, 0, 220), 2)
                end
            end
        end
    end
end

local RuneDraw = UtilitiesTab:Switch(
    "Радиус притягивания рун", false,
    "panorama/images/spellicons/arc_warden_magnetic_field_png.vtex_c")
RuneDraw:ToolTip("Рисует круг вокруг Arc Warden радиусом притягивания рун от Magnetic Field. Радиус зависит от уровня W (800/1200/1600/2000).")

local RUNE_DRAW_COLOR = Color(0, 200, 255, 180)
local RUNE_DRAW_THICKNESS = 2
local RUNE_DRAW_SEGMENTS = 64

local function DrawWorldCircle(center, radius, color, thickness, segments)
    segments = segments or RUNE_DRAW_SEGMENTS
    local prevScreen = nil
    local firstScreen = nil

    for i = 0, segments do
        local angle = (i / segments) * math.pi * 2
        local worldPoint = center + Vector(math.cos(angle) * radius, math.sin(angle) * radius, 0)
        local screenPos, visible = Render.WorldToScreen(worldPoint)

        if visible then
            if prevScreen then
                Render.Line(prevScreen, screenPos, color, thickness)
            else
                firstScreen = screenPos
            end
            prevScreen = screenPos
        else
            prevScreen = nil
        end
    end

    if firstScreen and prevScreen then
        Render.Line(prevScreen, firstScreen, color, thickness)
    end
end

local function DrawRunePullRadius()
    if not RuneDraw:Get() then return end

    local hero = my_hero
    if not hero or not Entity.IsAlive(hero) then
        hero = localArcWarden()
        if not hero or not Entity.IsAlive(hero) then return end
    end

    local mf = NPC.GetAbility(hero, "arc_warden_magnetic_field")
    if not mf then return end

    local pullRadius = Ability.GetLevelSpecialValueFor(mf, "rune_pull_radius")
    if not pullRadius or pullRadius <= 0 then return end

    local heroPos = Entity.GetAbsOrigin(hero)
    if not heroPos then return end

    DrawWorldCircle(heroPos, pullRadius, RUNE_DRAW_COLOR, RUNE_DRAW_THICKNESS)
end

local _originalOnDraw = script.OnDraw
script.OnDraw = function()
    if _originalOnDraw then _originalOnDraw() end
    DrawRunePullRadius()
end

function script.OnGameEnd()
    state_inv.lastMove = 0
    state_inv.pendingItem = nil
    state_mjollnir.lastMove = 0
    state_mjollnir.pendingItem = nil
    state_mjollnir.lastMoonShardActive = false
    state_bkb.pendingItem = nil
    state_cdswap.lastMove = 0
    state_cdswap.pendingItem = nil
    my_hero = nil
    tempest_double = nil
    active_hooks = {}
    active_rolls = {}
    enemy_pos_history = {}
    pudge_last_cd = {}
    last_hook_order_time = 0
    last_roll_order_time = 0
    last_order_target_pos = nil
    spark_state.next_update = 0
    spark_state.next_cast = 0
    spark_state.target_history = {}
    spark_state.next_cleanup = 0
end

return script