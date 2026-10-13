local script = {}

local cfg = {}

local state = {
    nextThink = 0,
    lastTargetIndex = -1,
    lastPickupOrderTime = 0,
    lastReturnOrderTime = 0,
    awaitingGemAfterPickup = false,
    pendingPickupTargetIndex = -1,
}

local function resolveEnumValue(container, names)
    if not container then
        return nil
    end
    for i = 1, #names do
        local value = container[names[i]]
        if value ~= nil then
            return value
        end
    end
    return nil
end

local function getTurboModeValue()
    return resolveEnumValue(Enum and Enum.GameMode or nil, {
        "DOTA_GAMEMODE_TURBO",
        "GAMEMODE_TURBO",
        "TURBO",
    })
end

local function isTurboMode()
    if not (GameRules and GameRules.GetGameMode) then
        return false
    end

    local current = GameRules.GetGameMode()
    local turbo = getTurboModeValue()
    if turbo ~= nil then
        return current == turbo
    end

    if Enum and Enum.GameMode then
        for name, value in pairs(Enum.GameMode) do
            if value == current and type(name) == "string" and string.find(string.upper(name), "TURBO", 1, true) then
                return true
            end
        end
    end

    return false
end

local function resolvePickupOrder()
    return resolveEnumValue(Enum and Enum.UnitOrder or nil, {
        "DOTA_UNIT_ORDER_PICKUP_ITEM",
        "PICKUP_ITEM",
    })
end

local function resolveIssuer()
    return resolveEnumValue(Enum and Enum.PlayerOrderIssuer or nil, {
        "DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY",
        "PLAYER_ORDER_ISSUER_PASSED_UNIT_ONLY",
        "DOTA_ORDER_ISSUER_HERO_ONLY",
        "PLAYER_ORDER_ISSUER_HERO_ONLY",
    })
end

local function getLocalPlayer(hero)
    if Players and Players.GetLocal then
        local player = Players.GetLocal()
        if player then
            return player
        end
    end

    if Hero and Hero.GetPlayer and hero then
        local ok, player = pcall(Hero.GetPlayer, hero)
        if ok and player then
            return player
        end
    end

    return nil
end

local function getGemPhysical(courierPos, maxDistance)
    local list = PhysicalItems and PhysicalItems.GetAll and PhysicalItems.GetAll() or nil
    if not list then
        return nil
    end

    local bestPhysical = nil
    local bestDistance = math.huge

    for i = 1, #list do
        local physical = list[i]
        if physical then
            local item = PhysicalItem.GetItem(physical)
            if item and Ability.GetName(item) == "item_gem" then
                local pos = Entity.GetAbsOrigin(physical)
                local dist = courierPos:Distance2D(pos)
                if dist <= maxDistance and dist < bestDistance then
                    bestDistance = dist
                    bestPhysical = physical
                end
            end
        end
    end

    return bestPhysical
end

local function courierHasGem(courier)
    if NPC.GetItem then
        local itemReal = NPC.GetItem(courier, "item_gem", true)
        if itemReal then
            return true
        end

        local itemAny = NPC.GetItem(courier, "item_gem", false)
        if itemAny then
            return true
        end
    end

    if NPC.GetItemByIndex then
        for i = 0, 20 do
            local item = NPC.GetItemByIndex(courier, i)
            if item and Ability.GetName(item) == "item_gem" then
                return true
            end
        end
    end

    return false
end

local function hasPhysicalItemByIndex(targetIndex)
    if targetIndex == nil or targetIndex < 0 then
        return false
    end

    local list = PhysicalItems and PhysicalItems.GetAll and PhysicalItems.GetAll() or nil
    if not list then
        return false
    end

    for i = 1, #list do
        local physical = list[i]
        if physical and Entity.GetIndex(physical) == targetIndex then
            return true
        end
    end

    return false
end

local function issuePickupOrder(player, orderType, target, pos, issuer, courier)
    Player.PrepareUnitOrders(
        player,
        orderType,
        target,
        pos,
        nil,
        issuer,
        courier,
        false,
        false,
        false,
        false,
        "auto_courier_pick_gem",
        true
    )
end

local function issueReturnToStash(courier, now, minDelay)
    if now - state.lastReturnOrderTime < math.max(minDelay, 0.6) then
        return
    end

    if not (NPC and NPC.GetAbility and Ability and Ability.CastNoTarget) then
        return
    end

    local returnAbility = NPC.GetAbility(courier, "courier_return_stash_items")
    if not returnAbility then
        return
    end

    Ability.CastNoTarget(returnAbility, false, false, true, "auto_courier_return_stash")
    state.lastReturnOrderTime = now
end

local function initMenu()
    local root = Menu and Menu.Create and Menu.Create("Scripts", "Utility") or nil
    if not root then
        return
    end

    local tab = root:Create("Курьер Gem")
    if not tab or not tab.Create then
        return
    end

    local main = tab:Create("Основное")
    if not main or not main.Create then
        return
    end

    local group = main:Create("Настройки")
    if not group then
        return
    end

    local function makeSliderInt(container, name, min, max, default, fmt)
        if container and container.SliderInt then
            return container:SliderInt(name, min, max, default)
        end
        if container and container.Slider then
            return container:Slider(name, min, max, default, fmt)
        end
        if container and container.SliderFloat then
            return container:SliderFloat(name, min, max, default)
        end
        return nil
    end

    cfg.enabled = group.Switch and group:Switch("Включить", false) or nil
    cfg.anyMode = group.Switch and group:Switch("Работать в любом режиме", false) or nil
    cfg.maxDistance = makeSliderInt(group, "Дистанция поиска", 1000, 20000, 18000, "%d")

    if not cfg.enabled or not cfg.anyMode or not cfg.maxDistance then
        return
    end

    local function updateControls()
        local enabled = cfg.enabled:Get()
        if cfg.anyMode.Disabled then
            cfg.anyMode:Disabled(not enabled)
        end
        if cfg.maxDistance.Disabled then
            cfg.maxDistance:Disabled(not enabled)
        end
    end

    if cfg.enabled.SetCallback then
        cfg.enabled:SetCallback(updateControls, true)
    end
end

function script.OnUpdate()
    if not cfg.enabled or not cfg.anyMode or not cfg.maxDistance then
        return
    end

    local now = GameRules.GetGameTime()
    if now < state.nextThink then
        return
    end
    state.nextThink = now + 0.10

    if not cfg.enabled:Get() then
        state.lastTargetIndex = -1
        state.awaitingGemAfterPickup = false
        state.pendingPickupTargetIndex = -1
        return
    end

    if not Engine.IsInGame() then
        state.lastTargetIndex = -1
        state.awaitingGemAfterPickup = false
        state.pendingPickupTargetIndex = -1
        return
    end

    if not cfg.anyMode:Get() and not isTurboMode() then
        state.lastTargetIndex = -1
        state.awaitingGemAfterPickup = false
        state.pendingPickupTargetIndex = -1
        return
    end

    local hero = Heroes.GetLocal()
    if not hero or not Entity.IsAlive(hero) then
        return
    end

    local courier = Couriers.GetLocal and Couriers.GetLocal() or nil
    if not courier or not Entity.IsAlive(courier) then
        return
    end

    local minDelay = 0.8

    if state.awaitingGemAfterPickup then
        -- Если курьер успел подобрать гем
        if courierHasGem(courier) then
            issueReturnToStash(courier, now, minDelay)
            state.awaitingGemAfterPickup = false
            state.pendingPickupTargetIndex = -1
            return
        end

        -- Если предмет пропал с земли до того, как курьер его взял (кто-то другой забрал)
        if not hasPhysicalItemByIndex(state.pendingPickupTargetIndex) then
            -- Форсируем команду на возврат домой, игнорируя таймер спама (minDelay)
            if NPC and NPC.GetAbility and Ability and Ability.CastNoTarget then
                local returnAbility = NPC.GetAbility(courier, "courier_return_stash_items")
                if returnAbility then
                    Ability.CastNoTarget(returnAbility, false, false, true, "auto_courier_return_canceled")
                    state.lastReturnOrderTime = now
                end
            end

            -- Сбрасываем стейт ожидания только после отправки приказа
            state.awaitingGemAfterPickup = false
            state.pendingPickupTargetIndex = -1
        end

        return
    end

    local player = getLocalPlayer(hero)
    if not player then
        return
    end

    local orderType = resolvePickupOrder()
    local issuer = resolveIssuer()
    if orderType == nil or issuer == nil then
        return
    end

    local gemPhysical = getGemPhysical(Entity.GetAbsOrigin(courier), cfg.maxDistance:Get())
    if not gemPhysical then
        state.lastTargetIndex = -1
        return
    end

    local targetIndex = Entity.GetIndex(gemPhysical)
    if state.lastTargetIndex == targetIndex and (now - state.lastPickupOrderTime) < minDelay then
        return
    end

    issuePickupOrder(player, orderType, gemPhysical, Entity.GetAbsOrigin(gemPhysical), issuer, courier)
    state.lastTargetIndex = targetIndex
    state.lastPickupOrderTime = now
    state.awaitingGemAfterPickup = true
    state.pendingPickupTargetIndex = targetIndex
end

function script.OnGameEnd()
    state.nextThink = 0
    state.lastTargetIndex = -1
    state.lastPickupOrderTime = 0
    state.lastReturnOrderTime = 0
    state.awaitingGemAfterPickup = false
    state.pendingPickupTargetIndex = -1
end

initMenu()

return script
