---@diagnostic disable: undefined-global

local script = {}

local C = {
    SCRIPT_ID = "marci_dust_delivery",
    VERSION = "1.5",
    HERO_NAME = "npc_dota_hero_marci",
    DUST_NAME = "item_dust",
    DUST_ITEM_ID = 40,
    DUST_COST = 80,
    DUST_MODIFIER = "modifier_item_dustofappearance",
    SPECIAL_DELIVERY = "marci_special_delivery",
    COURIER_DELIVER = "courier_take_stash_and_transfer_items",
    COURIER_TAKE_STASH = "courier_take_stash_items",
    MAIN_FIRST = 0,
    MAIN_LAST = 5,
    BACKPACK_FIRST = 6,
    BACKPACK_LAST = 8,
    STASH_FIRST = 9,
    STASH_LAST = 14,
    COURIER_LAST = 8,
    BUY_CONFIRM_WINDOW = 0.50,
    STEP_TIMEOUT = 6.0,
    TRANSFER_TIMEOUT = 6.0,
    ORDER_GAP = 0.03,
    AUTO_RESTOCK_GAP = 20.0,
    SCAN_INTERVAL = 0.10,
    DUST_RECAST_GAP = 1.0,
    INVIS_MEMORY = 3.0,
    DEBUG_INTERVAL = 1.0,
}

local INVIS_MODIFIERS = {
    modifier_invisible = true,
    modifier_riki_permanent_invisibility = true,
    modifier_bounty_hunter_wind_walk = true,
    modifier_clinkz_skeleton_walk = true,
    modifier_nyx_assassin_vendetta = true,
    modifier_templar_assassin_meld = true,
    modifier_mirana_moonlight_shadow = true,
    modifier_slark_shadow_dance = true,
    modifier_weaver_shukuchi = true,
    modifier_sand_king_sand_storm = true,
    modifier_invoker_ghost_walk_self = true,
    modifier_treant_natures_guise_invis = true,
    modifier_item_glimmer_cape_fade = true,
    modifier_smoke_of_deceit = true,
}

local KEEP_ITEMS = {
    ["item_tpscroll"] = true,
    ["item_travel_boots"] = true,
    ["item_travel_boots_2"] = true,
    ["item_black_king_bar"] = true,
    ["item_aegis"] = true,
    ["item_cheese"] = true,
    ["item_gem"] = true,
    ["item_ward_observer"] = true,
    ["item_ward_sentry"] = true,
    ["item_ward_dispenser"] = true,
    ["item_dust"] = true,
}

local localization = qLocalization.new({
    en = {
        mdd = {
            groups = {
                auto = "Auto dust",
                chain = "Restock chain",
            },
            menu = {
                auto_use = "Auto use dust",
                auto_use_tip = "Casts Dust of Appearance from the main inventory when an invisible enemy hero is inside the radius.\n\nSkips targets that are immune to true sight and targets that are already dusted.",
                radius = "Trigger radius",
                radius_tip = "Dust reveals in 1050 units. Lower this if you want to hold the charge for point-blank fights only.",
                skip_truesight_immune = "Skip true-sight-immune",
                skip_truesight_immune_tip = "Do not spend a charge on units that ignore true sight, for example Slark under Shadow Dance.",
                debug_log = "Debug log",
                debug_log_tip = "Writes one scan report per second to the log: where the dust is, whether it is ready, and for every enemy hero its dormant/visible flags, invisibility state and full modifier list. Turn it on only while diagnosing, then off.",
                mode = "Trigger mode",
                mode_tip = "Bind: the chain runs only when you press the bind.\n\nAuto: the chain also starts on its own the moment an invisible enemy is seen inside the trigger radius and you are carrying no dust. The bind keeps working in both modes.",
                mode_bind = "Bind only",
                mode_auto = "Bind + auto",
                restock_bind = "Restock bind",
                restock_bind_tip = "Runs the whole chain: buy dust, free an inventory slot, send the courier, then cast Special Delivery so the courier lands on you instantly.",
                require_courier_base = "Courier must be at base",
                require_courier_base_tip = "Only start the chain while the courier is idle at the fountain. Off means the chain will also grab a courier that is already flying.",
                free_slot = "Free a slot first",
                free_slot_tip = "Moves the cheapest non-protected item into the backpack before delivery, so the dust lands in a castable main slot. Dust cannot be used from the backpack.",
            },
        },
    },
    ru = {
        mdd = {
            groups = {
                auto = "Авто-дуст",
                chain = "Цепочка закупки",
            },
            menu = {
                auto_use = "Авто-использование дуста",
                auto_use_tip = "Кастует Dust of Appearance из основного инвентаря, когда невидимый вражеский герой попадает в радиус.\n\nПропускает цели с иммунитетом к тру-сайту и уже задастованные цели.",
                radius = "Радиус срабатывания",
                radius_tip = "Дуст раскрывает в 1050 юнитах. Снижай, если хочешь тратить заряд только в упор.",
                skip_truesight_immune = "Пропускать иммунных к тру-сайту",
                skip_truesight_immune_tip = "Не тратить заряд на тех, кто игнорирует тру-сайт, например Slark под Shadow Dance.",
                debug_log = "Отладочный лог",
                debug_log_tip = "Раз в секунду пишет в лог отчёт скана: где лежит дуст, готов ли он, и по каждому вражескому герою его флаги dormant/visible, состояние невидимости и полный список модификаторов. Включай только на время диагностики, потом выключай.",
                mode = "Режим запуска",
                mode_tip = "По бинду: цепочка идёт только по нажатию.\n\nАвтоматически: цепочка стартует сама, как только в радиусе замечен невидимый враг, а дуста на руках нет. Бинд работает в обоих режимах.",
                mode_bind = "Только бинд",
                mode_auto = "Бинд + авто",
                restock_bind = "Бинд закупки",
                restock_bind_tip = "Запускает всю цепочку: покупка дуста, освобождение слота, приказ курьеру, затем Special Delivery, и курьер телепортируется к тебе мгновенно.",
                require_courier_base = "Курьер должен быть на базе",
                require_courier_base_tip = "Запускать цепочку только пока курьер стоит на фонтане. Выключено означает, что цепочка заберёт и уже летящего курьера.",
                free_slot = "Сначала освободить слот",
                free_slot_tip = "Перекладывает самый дешёвый незащищённый предмет в бэкпак перед доставкой, чтобы дуст лёг в кастуемый основной слот. Из бэкпака дуст не кастуется.",
            },
        },
    },
})

local Menu = localization.WrapLibrary(Menu)

local T = {
    groupAuto = "mdd.groups.auto",
    groupChain = "mdd.groups.chain",
    autoUse = "mdd.menu.auto_use",
    autoUseTip = "mdd.menu.auto_use_tip",
    radius = "mdd.menu.radius",
    radiusTip = "mdd.menu.radius_tip",
    skipImmune = "mdd.menu.skip_truesight_immune",
    skipImmuneTip = "mdd.menu.skip_truesight_immune_tip",
    debugLog = "mdd.menu.debug_log",
    debugLogTip = "mdd.menu.debug_log_tip",
    mode = "mdd.menu.mode",
    modeTip = "mdd.menu.mode_tip",
    modeBind = "mdd.menu.mode_bind",
    modeAuto = "mdd.menu.mode_auto",
    restockBind = "mdd.menu.restock_bind",
    restockBindTip = "mdd.menu.restock_bind_tip",
    requireCourierBase = "mdd.menu.require_courier_base",
    requireCourierBaseTip = "mdd.menu.require_courier_base_tip",
    freeSlot = "mdd.menu.free_slot",
    freeSlotTip = "mdd.menu.free_slot_tip",
}

local options = { ready = false }

local state = {
    hero = nil,
    player = nil,
    team = nil,
    step = "idle",
    stepAt = 0,
    nextScanAt = 0,
    nextDustAt = 0,
    nextDebugAt = 0,
    nextAutoAt = 0,
    trigger = "bind",
    invisMemory = {},
    goldBefore = 0,
    routeTried = nil,
}

local Log = {}
local Util = {}
local Buy = {}
local Chain = {}
local AutoDust = {}
local Lifecycle = {}

function Log.write(level, message, data)
    if ai_bridge ~= nil and ai_bridge.mcp_log ~= nil then
        ai_bridge.mcp_log(level, message, data)
    end
end

function Util.itemName(item)
    if item == nil then
        return nil
    end
    local ok, name = pcall(Ability.GetName, item)
    if ok then
        return name
    end
    return nil
end

function Util.findItem(unit, from, to, name)
    if unit == nil then
        return nil, nil
    end
    for slot = from, to do
        local item = NPC.GetItemByIndex(unit, slot)
        if item ~= nil and Util.itemName(item) == name then
            return item, slot
        end
    end
    return nil, nil
end

function Util.freeBackpackSlot(hero)
    for slot = C.BACKPACK_FIRST, C.BACKPACK_LAST do
        if NPC.GetItemByIndex(hero, slot) == nil then
            return slot
        end
    end
    return nil
end

function Util.cheapestMainItem(hero)
    local best, bestCost = nil, nil
    for slot = C.MAIN_FIRST, C.MAIN_LAST do
        local item = NPC.GetItemByIndex(hero, slot)
        if item ~= nil then
            local name = Util.itemName(item)
            if name ~= nil and not KEEP_ITEMS[name] then
                local cost = Item.GetCost(item) or 0
                if bestCost == nil or cost < bestCost then
                    best, bestCost = item, cost
                end
            end
        end
    end
    return best
end

function Util.carriesDust(hero)
    return Util.findItem(hero, C.MAIN_FIRST, C.BACKPACK_LAST, C.DUST_NAME) ~= nil
end

function Util.dustPending(hero, courier)
    if Util.findItem(hero, C.STASH_FIRST, C.STASH_LAST, C.DUST_NAME) ~= nil then
        return true
    end
    if courier ~= nil and Util.findItem(courier, 0, C.COURIER_LAST, C.DUST_NAME) ~= nil then
        return true
    end
    return false
end

function Util.courier()
    local courier = Couriers.GetLocal()
    if courier == nil
        or not Couriers.Contains(courier)
        or not Entity.IsAlive(courier)
        or NPC.IsWaitingToSpawn(courier)
    then
        return nil
    end
    return courier
end

function Util.courierAtBase(courier)
    local courierState = Courier.GetCourierState(courier)
    return courierState == Enum.CourierState.COURIER_STATE_AT_BASE
        or courierState == Enum.CourierState.COURIER_STATE_IDLE
end

function Util.specialDelivery(hero)
    return NPC.GetAbility(hero, C.SPECIAL_DELIVERY)
end

function Buy.itemId(player)
    if Engine ~= nil and Engine.SetQuickBuy ~= nil then
        pcall(Engine.SetQuickBuy, C.DUST_NAME, true)
    end
    if player ~= nil and Player.GetQuickBuyInfo ~= nil then
        local ok, info = pcall(Player.GetQuickBuyInfo, player)
        if ok and info ~= nil and info.m_quickBuyItems ~= nil then
            local id = info.m_quickBuyItems[1]
            if type(id) == "number" and id > 0 then
                return id
            end
        end
    end
    return C.DUST_ITEM_ID
end

function Buy.routeA(player, hero, id)
    return pcall(
        Player.PrepareUnitOrders,
        player,
        Enum.UnitOrder.DOTA_UNIT_ORDER_PURCHASE_ITEM,
        id,
        Vector(0, 0, 0),
        nil,
        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_HERO_ONLY,
        hero,
        false,
        false,
        false,
        false,
        "mdd_buy_a",
        false
    )
end

function Buy.routeB(id)
    if Engine == nil or Engine.RunScript == nil then
        return false
    end
    local js = string.format(
        "Game.PrepareUnitOrders({OrderType: 16, AbilityIndex: %d, ShowEffects: false, Queue: false})",
        id
    )
    local ok, result = pcall(Engine.RunScript, js, "Hud")
    return ok and result ~= false
end

function Chain.stop(reason, level, data)
    state.step = "idle"
    Log.write(level or "info", C.SCRIPT_ID .. ": " .. reason, data)
end

function Chain.enter(step, now)
    state.step = step
    state.stepAt = now
end

function Chain.freeSlot()
    if not options.freeSlot:Get() or NPC.HasInventorySlotFree(state.hero, true) then
        return true
    end

    local target = Util.freeBackpackSlot(state.hero)
    local item = Util.cheapestMainItem(state.hero)
    if target == nil or item == nil then
        return false
    end

    Player.PrepareUnitOrders(
        state.player,
        Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_ITEM,
        target,
        Vector(0, 0, 0),
        item,
        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
        state.hero,
        false,
        false,
        false,
        false,
        "mdd_free_slot",
        false
    )
    return true
end

function Chain.start(now, trigger)
    if state.hero == nil or NPC.GetUnitName(state.hero) ~= C.HERO_NAME then
        Chain.stop("no_hero")
        return
    end

    local ability = Util.specialDelivery(state.hero)
    if ability == nil then
        Chain.stop("no_ability", "warn")
        return
    end
    if not Ability.IsReady(ability) then
        Chain.stop("ability_cd")
        return
    end

    local courier = Util.courier()
    if courier == nil then
        Chain.stop("no_courier")
        return
    end
    if options.requireCourierBase:Get() and not Util.courierAtBase(courier) then
        Chain.stop("courier_busy")
        return
    end

    if Util.carriesDust(state.hero) then
        Chain.stop("have_dust")
        return
    end

    state.trigger = trigger or "bind"

    if not Chain.freeSlot() then
        Chain.stop("no_space", "warn")
        return
    end

    if Util.dustPending(state.hero, courier) then
        Chain.enter("courier", now)
        return
    end

    if (Player.GetTotalGold(state.player) or 0) < C.DUST_COST then
        Chain.stop("no_gold")
        return
    end

    Chain.enter("buy", now)
end

function Chain.stepBuy(now)
    state.goldBefore = Player.GetTotalGold(state.player) or 0
    state.routeTried = "A"
    Buy.routeA(state.player, state.hero, Buy.itemId(state.player))
    Chain.enter("confirm_buy", now)
end

function Chain.buyLanded()
    return Util.dustPending(state.hero, Util.courier()) or Util.carriesDust(state.hero)
end

function Chain.stepConfirmBuy(now)
    if Chain.buyLanded() then
        Log.write("info", C.SCRIPT_ID .. ": purchase succeeded", {
            route = state.routeTried,
            trigger = state.trigger,
            elapsed = now - state.stepAt,
            gold_before = state.goldBefore,
            gold_after = Player.GetTotalGold(state.player) or 0,
        })
        Chain.enter("courier", now)
        return
    end

    if now - state.stepAt < C.BUY_CONFIRM_WINDOW then
        return
    end

    if state.routeTried == "A" then
        state.routeTried = "B"
        Buy.routeB(Buy.itemId(state.player))
        Chain.enter("confirm_buy", now)
        return
    end

    Chain.stop("buy_failed", "warn", { route = "A+B" })
end

function Chain.stepCourier(now)
    local courier = Util.courier()
    if courier == nil then
        Chain.stop("no_courier", "warn")
        return
    end

    local deliver = NPC.GetAbility(courier, C.COURIER_DELIVER)
    if deliver ~= nil and Ability.IsReady(deliver) then
        Player.PrepareUnitOrders(
            state.player,
            Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TARGET,
            state.hero,
            Entity.GetAbsOrigin(state.hero),
            deliver,
            Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
            courier,
            false,
            false,
            false,
            true,
            "mdd_courier_deliver",
            false
        )
    else
        local takeStash = NPC.GetAbility(courier, C.COURIER_TAKE_STASH)
        if takeStash ~= nil then
            Ability.CastNoTarget(takeStash, false, false, true, "mdd_courier_stash")
        end
    end

    Chain.enter("delivery", now)
end

function Chain.stepDelivery(now)
    if now - state.stepAt < C.ORDER_GAP then
        return
    end

    local ability = Util.specialDelivery(state.hero)
    if ability == nil then
        Chain.stop("no_ability", "warn")
        return
    end
    if not Ability.IsReady(ability) then
        Chain.stop("ability_cd", "warn")
        return
    end

    Ability.CastNoTarget(ability, false, false, true, "mdd_special_delivery")
    Chain.enter("wait_items", now)
end

function Chain.stepWaitItems(now)
    if Util.carriesDust(state.hero) then
        Chain.stop("delivered", "info", {
            trigger = state.trigger,
            elapsed = now - state.stepAt,
        })
        return
    end
    if now - state.stepAt > C.TRANSFER_TIMEOUT then
        Chain.stop("timeout", "warn", { step = "wait_items" })
    end
end

function Chain.update(now)
    if state.step == "idle" then
        return
    end

    if state.step ~= "wait_items" and now - state.stepAt > C.STEP_TIMEOUT then
        Chain.stop("timeout", "warn", { step = state.step })
        return
    end

    if state.step == "buy" then
        Chain.stepBuy(now)
    elseif state.step == "confirm_buy" then
        Chain.stepConfirmBuy(now)
    elseif state.step == "courier" then
        Chain.stepCourier(now)
    elseif state.step == "delivery" then
        Chain.stepDelivery(now)
    elseif state.step == "wait_items" then
        Chain.stepWaitItems(now)
    end
end

function AutoDust.isInvisible(enemy)
    if NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_INVISIBLE) then
        return true, "state"
    end
    if NPC.HasAnyModifier(enemy, INVIS_MODIFIERS) then
        return true, "modifier"
    end
    return false, nil
end

function AutoDust.trackInvisible(enemy, now)
    local invis, source = AutoDust.isInvisible(enemy)
    local record = state.invisMemory[enemy]

    if invis then
        if record == nil then
            record = {}
            state.invisMemory[enemy] = record
        end
        record.at = now
        record.pos = Entity.GetAbsOrigin(enemy)
        record.source = source
        return true, record.pos, source
    end

    if record ~= nil then
        if now - record.at <= C.INVIS_MEMORY then
            return true, record.pos, record.source .. "+memory"
        end
        state.invisMemory[enemy] = nil
    end

    return false, nil, nil
end

function AutoDust.dustReady(dust)
    if dust == nil then
        return false
    end
    if Item.IsItemEnabled ~= nil and not Item.IsItemEnabled(dust) then
        return false
    end
    return Ability.IsReady(dust)
end

function AutoDust.shouldReveal(enemy, radius, origin, now)
    if enemy == nil or not Entity.IsAlive(enemy) then
        return false, nil
    end
    if NPC.IsIllusion(enemy) or NPC.IsMeepoClone(enemy) then
        return false, nil
    end

    local invis, pos, source = AutoDust.trackInvisible(enemy, now)
    if not invis or pos == nil then
        return false, nil
    end

    if options.skipImmune:Get()
        and NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_TRUESIGHT_IMMUNE)
    then
        return false, nil
    end
    if NPC.HasModifier(enemy, C.DUST_MODIFIER) then
        return false, nil
    end

    if pos:Distance2D(origin) > radius then
        return false, nil
    end

    return true, source
end

function AutoDust.debugDump(now, dust, dustSlot, origin, radius)
    if now < state.nextDebugAt then
        return
    end
    state.nextDebugAt = now + C.DEBUG_INTERVAL

    local anywhere, anywhereSlot = Util.findItem(state.hero, C.MAIN_FIRST, C.STASH_LAST, C.DUST_NAME)

    Log.write("info", C.SCRIPT_ID .. ": scan", {
        dust_main_slot = dustSlot,
        dust_any_slot = anywhereSlot,
        dust_anywhere = anywhere ~= nil,
        dust_is_ready = dust ~= nil and Ability.IsReady(dust) or false,
        dust_enabled = dust ~= nil and Item.IsItemEnabled(dust) or false,
        dust_can_be_executed = dust ~= nil and Ability.CanBeExecuted(dust) or nil,
        radius = radius,
    })

    for _, enemy in pairs(Heroes.GetAll()) do
        if Entity.GetTeamNum(enemy) ~= state.team and not NPC.IsIllusion(enemy) then
            local pos = Entity.GetAbsOrigin(enemy)
            local names = {}
            for _, modifier in pairs(NPC.GetModifiers(enemy)) do
                names[#names + 1] = Modifier.GetName(modifier)
            end

            Log.write("info", C.SCRIPT_ID .. ": enemy", {
                name = NPC.GetUnitName(enemy),
                alive = Entity.IsAlive(enemy),
                dormant = Entity.IsDormant(enemy),
                visible = NPC.IsVisible(enemy),
                state_invisible = NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_INVISIBLE),
                modifier_invisible = NPC.HasAnyModifier(enemy, INVIS_MODIFIERS),
                truesight_immune = NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_TRUESIGHT_IMMUNE),
                dusted = NPC.HasModifier(enemy, C.DUST_MODIFIER),
                distance = pos ~= nil and math.floor(pos:Distance2D(origin)) or nil,
                modifiers = table.concat(names, ","),
            })
        end
    end
end

function AutoDust.findInvisible(now, radius, origin)
    for _, enemy in pairs(Heroes.GetAll()) do
        if Entity.GetTeamNum(enemy) ~= state.team then
            local reveal, source = AutoDust.shouldReveal(enemy, radius, origin, now)
            if reveal then
                return enemy, source
            end
        end
    end
    return nil, nil
end

function AutoDust.update(now)
    if now < state.nextScanAt then
        return
    end
    state.nextScanAt = now + C.SCAN_INTERVAL

    local origin = Entity.GetAbsOrigin(state.hero)
    if origin == nil then
        return
    end

    local radius = options.radius:Get() or 1050
    local dust, dustSlot = Util.findItem(state.hero, C.MAIN_FIRST, C.MAIN_LAST, C.DUST_NAME)

    if options.debugLog:Get() then
        AutoDust.debugDump(now, dust, dustSlot, origin, radius)
    end

    local enemy, source = AutoDust.findInvisible(now, radius, origin)
    if enemy == nil then
        return
    end

    if options.autoUse:Get() and now >= state.nextDustAt and AutoDust.dustReady(dust) then
        Ability.CastNoTarget(dust, false, false, true, "mdd_auto_dust")
        state.nextDustAt = now + C.DUST_RECAST_GAP
        Log.write("info", C.SCRIPT_ID .. ": dust cast", {
            target = NPC.GetUnitName(enemy),
            source = source,
            slot = dustSlot,
        })
        return
    end

    if options.mode:Get() == 1
        and state.step == "idle"
        and now >= state.nextAutoAt
        and not Util.carriesDust(state.hero)
    then
        state.nextAutoAt = now + C.AUTO_RESTOCK_GAP
        Log.write("info", C.SCRIPT_ID .. ": auto restock triggered", {
            target = NPC.GetUnitName(enemy),
            source = source,
        })
        Chain.start(now, "auto")
    end
end

function Lifecycle.initializeMenu()
    local root = Menu.Find("Heroes", "Hero List", "Marci")
    if root == nil then
        root = Menu.Create("Scripts", "Marci", "Marci")
    end
    if root == nil then
        return false
    end

    local tab = root:Create("Dusts")
    local autoGroup = tab:Create(T.groupAuto, Enum.GroupSide.Left)
    local chainGroup = tab:Create(T.groupChain, Enum.GroupSide.Right)

    options.autoUse = autoGroup:Switch(T.autoUse, true, "\u{f06e}")
    options.autoUse:ToolTip(T.autoUseTip)

    options.radius = autoGroup:Slider(T.radius, 400, 1050, 1050, "%d")
    options.radius:ToolTip(T.radiusTip)
    options.radius:Icon("\u{f140}")

    options.skipImmune = autoGroup:Switch(T.skipImmune, true, "\u{f05e}")
    options.skipImmune:ToolTip(T.skipImmuneTip)

    options.debugLog = autoGroup:Switch(T.debugLog, false, "\u{f188}")
    options.debugLog:ToolTip(T.debugLogTip)

    options.mode = chainGroup:Combo(T.mode, { T.modeBind, T.modeAuto }, 0)
    options.mode:ToolTip(T.modeTip)

    options.restockBind = chainGroup:Bind(
        T.restockBind,
        Enum.ButtonCode.BUTTON_CODE_INVALID,
        "\u{f11c}"
    )
    options.restockBind:ToolTip(T.restockBindTip)

    options.requireCourierBase = chainGroup:Switch(T.requireCourierBase, true, "\u{f015}")
    options.requireCourierBase:ToolTip(T.requireCourierBaseTip)

    options.freeSlot = chainGroup:Switch(T.freeSlot, true, "\u{f0b1}")
    options.freeSlot:ToolTip(T.freeSlotTip)

    return true
end

function Lifecycle.onScriptsLoaded()
    options.ready = Lifecycle.initializeMenu()
    Log.write("info", C.SCRIPT_ID .. " loaded", {
        version = C.VERSION,
        menu_ready = options.ready,
        purchase_verified = false,
    })
end

function Lifecycle.onUpdate()
    if not options.ready then
        return
    end

    local hero = Heroes.GetLocal()
    if hero == nil or not Entity.IsAlive(hero) then
        return
    end

    local player = Players.GetLocal()
    if player == nil then
        return
    end

    state.hero = hero
    state.player = player
    state.team = Entity.GetTeamNum(hero)

    local now = GameRules.GetGameTime()

    if options.restockBind:IsPressed() and state.step == "idle" then
        Chain.start(now, "bind")
    end

    Chain.update(now)
    AutoDust.update(now)
end

function script.OnScriptsLoaded()
    return Lifecycle.onScriptsLoaded()
end

function script.OnUpdate()
    return Lifecycle.onUpdate()
end

return script
