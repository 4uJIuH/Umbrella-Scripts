local script = {}

-- ============ VARIABLES ============
local player = Players.GetLocal()
local me = Heroes.GetLocal()

-- ability (СТАРЫЙ ПАТЧ, до реворка Тинкера)
local q = NPC.GetAbilityByIndex(me, 0) -- Laser (не менялся)
local w = NPC.GetAbilityByIndex(me, 1) -- Heat-Seeking Missile (таргетный урон, НЕ March of the Machines)
local e = NPC.GetAbilityByIndex(me, 2) -- Defense Matrix (таргетный щит на себя/союзника, НЕ турельки на позицию)
local d = NPC.GetAbilityByIndex(me, 3) -- Warp Flare (не менялся)
local f = NPC.GetAbilityByIndex(me, 4) -- TP Scroll / доп. слот
local r = NPC.GetAbilityByIndex(me, 5) -- Rearm (не менялся)

-- order_delay (в вашем втором скрипте это использовалось, но не было объявлено — почини'но)
local last_orders = {}
local order_delay = 0.2
function CanOrder(name)
    local time = GameRules.GetGameTime()
    if not last_orders[name] or time - last_orders[name] > order_delay then
        last_orders[name] = time
        return true
    end
    return false
end

-- ============ MENU STRUCTURE ============
local TinkerCombsettings = Menu.Create("Heroes", "Hero List", "Tinker", "Tinker Fear of God Combo")

-- Combo Settings
local TinkerComboSettings = TinkerCombsettings:Create("Combo Settings")
local comboEnable = TinkerComboSettings:Switch("Включить комбо", false) -- на будущее, если нужен глобальный тумблер
local combobind = TinkerComboSettings:Bind("Клавиша комбо по курсору", Enum.ButtonCode.BUTTON_CODE_NONE)
local gotocursor = TinkerComboSettings:Switch("Идти к курсору (плохо работает не включать)", false)
local useMatrix = TinkerComboSettings:Switch("Использовать Defense Matrix на себя в комбо", true)
local useShivas = TinkerComboSettings:Switch("Использовать Shiva's Guard в начале комбо", true)
local useSoulRing = TinkerComboSettings:Switch("Использовать Soul Ring в начале комбо", true)
local useLaser = TinkerComboSettings:Switch("Использовать Laser в комбо", true)

-- Item Settings
local TinkerComboItemSettings = TinkerCombsettings:Create("Item Settings")
local itemsEnable = TinkerComboItemSettings:MultiSelect("Используемые предметы", {
    { "item_blink",          "panorama/images/items/blink_png.vtex_c",          true },
    { "item_ethereal_blade", "panorama/images/items/ethereal_blade_png.vtex_c", true },
    { "item_dagon",          "panorama/images/items/dagon_5_png.vtex_c",        true },
    { "item_soul_ring",      "panorama/images/items/soul_ring_png.vtex_c",      true },
    { "item_shivas_guard",   "panorama/images/items/shivas_guard_png.vtex_c",   true },
}, true)

local function IsComboItemEnabled(itemName)
    return itemsEnable:Get(itemName)
end

-- Утилиты
local Utilitessettings = TinkerCombsettings:Create("Утилиты")
Utilitessettings:Label("Здесь пока ничего нет")

-- Escape Settings (перенесено почти без изменений — работает на обычных предметах,
-- от геройских скиллов не зависит, поэтому переносится 1-в-1)
local Escape = TinkerCombsettings:Create("Настройки побега")
local escapeItemsWidget = Escape:MultiSelect("Предметы для побега", {
    { "item_blink",       "panorama/images/items/blink_png.vtex_c",       true },
    { "item_cyclone",     "panorama/images/items/cyclone_png.vtex_c",     true },
    { "item_wind_waker",  "panorama/images/items/wind_waker_png.vtex_c",  true },
}, true)
-- глиммер кейпа в списке старого патча не было в исходном втором скрипте — если он у вас
-- всё же есть в кастомке, просто добавьте строку { "item_glimmer_cape", ..., true } сюда.

local escapeRadiusSlider = Escape:Slider("Радиус при побеге от врага", 100, 1625, 900)
local escapeUseMatrix = Escape:Switch("Использовать Defense Matrix на себя при побеге", false)
local escapeModeCombo = Escape:Combo("Направление побега", { "На фонтан", "На курсор" }, 0)
local escapebind = Escape:Bind("Escape Key", Enum.ButtonCode.BUTTON_CODE_NONE)

local function IsEscapeItemEnabled(itemName)
    return escapeItemsWidget:Get(itemName)
end

-- ============ ПОИСК ПРЕДМЕТОВ (комбо) ============
local function FindBlink() return NPC.GetItem(me, "item_blink", true) end
local function FindArcaneBlink() return NPC.GetItem(me, "item_arcane_blink", true) end
local function FindEtherealBlade() return NPC.GetItem(me, "item_ethereal_blade", true) end
local function FindSoulRing() return NPC.GetItem(me, "item_soul_ring", true) end
local function FindShivasGuard() return NPC.GetItem(me, "item_shivas_guard", true) end
local dagon_names = { "item_dagon", "item_dagon_2", "item_dagon_3", "item_dagon_4", "item_dagon_5" }
local function FindDagon()
    for _, name in ipairs(dagon_names) do
        local item = NPC.GetItem(me, name, true)
        if item then return item end
    end
    return nil
end

-- ============ ПОИСК ПРЕДМЕТОВ (побег) ============
local function FindEscapeBlink() return NPC.GetItem(me, "item_blink", true) end
local function FindEscapeArcaneBlink() return NPC.GetItem(me, "item_arcane_blink", true) end
local function FindEscapeWinds()
    if IsEscapeItemEnabled("item_cyclone") then
        local item = NPC.GetItem(me, "item_cyclone", true)
        if item then return item end
    end
    if IsEscapeItemEnabled("item_wind_waker") then
        local item = NPC.GetItem(me, "item_wind_waker", true)
        if item then return item end
    end
    return nil
end

-- ============ ЦЕЛЬ ПОБЕГА ============
local function GetFountainPosition()
    local myTeam = Entity.GetTeamNum(me)
    if myTeam == Enum.TeamNum.TEAM_RADIANT then
        return Vector(-7189, -6591, 384) -- уточнить точные координаты под вашу кастомку
    else
        return Vector(7375, 6625, 384) -- уточнить точные координаты под вашу кастомку
    end
end

-- ============ ОТСЛЕЖИВАНИЕ ПОСЛЕДНЕЙ ПОЗИЦИИ ВРАГОВ ============
local enemyLastKnownPos = {}

local function UpdateEnemyLastKnownPositions()
    local enemies = Heroes.GetAll()
    if not enemies then return end

    for _, enemy in ipairs(enemies) do
        if enemy
        and Entity.GetTeamNum(enemy) ~= Entity.GetTeamNum(me)
        and Entity.IsAlive(enemy)
        and not Entity.IsDormant(enemy) then
            enemyLastKnownPos[enemy] = Entity.GetAbsOrigin(enemy)
        end
    end
end

-- ============ ОБХОД ВРАГОВ ПО РАДИУСУ (только для режима "На фонтан") ============
local function GetAvoidanceDestination(rawDestination)
    local myPos = Entity.GetAbsOrigin(me)
    local avoidRadius = escapeRadiusSlider:Get()

    local dirX = rawDestination.x - myPos.x
    local dirY = rawDestination.y - myPos.y
    local dist = math.sqrt(dirX * dirX + dirY * dirY)

    if dist <= 0 then
        return rawDestination
    end

    local attractX = dirX / dist
    local attractY = dirY / dist

    local repelX, repelY = 0, 0

    for enemy, lastPos in pairs(enemyLastKnownPos) do
        local ex = lastPos.x - myPos.x
        local ey = lastPos.y - myPos.y
        local edist = math.sqrt(ex * ex + ey * ey)

        if edist > 0 and edist < avoidRadius then
            local strength = (avoidRadius - edist) / avoidRadius
            repelX = repelX - (ex / edist) * strength
            repelY = repelY - (ey / edist) * strength
        end
    end

    local combinedX = attractX + repelX
    local combinedY = attractY + repelY
    local combinedDist = math.sqrt(combinedX * combinedX + combinedY * combinedY)

    if combinedDist <= 0 then
        return rawDestination
    end

    local nx = combinedX / combinedDist
    local ny = combinedY / combinedDist

    return Vector(myPos.x + nx * dist, myPos.y + ny * dist, myPos.z)
end

local function GetEscapeDestination()
    local mode = escapeModeCombo:Get() -- 0 = На фонтан, 1 = На курсор

    if mode == 1 then
        return Input.GetWorldCursorPos()
    else
        local fountainPos = GetFountainPosition()
        return GetAvoidanceDestination(fountainPos)
    end
end

-- позиция для блинка при побеге: от героя в сторону цели, но с учётом радиуса
local function GetEscapeBlinkPosition(destination)
    local myPos = Entity.GetAbsOrigin(me)
    local dirX = destination.x - myPos.x
    local dirY = destination.y - myPos.y
    local dist = math.sqrt(dirX * dirX + dirY * dirY)

    if dist <= 0 then
        return myPos
    end

    local nx = dirX / dist
    local ny = dirY / dist

    return Vector(myPos.x + nx * dist, myPos.y + ny * dist, myPos.z)
end

-- ============ ESCAPE STEP MACHINE ============
-- шаги: winds -> blink -> Defense Matrix(опционально)
local escapeStep = 1
local ESCAPE_STEP_COUNT = 3

local function ResetEscape()
    escapeStep = 1
end

local function tryEscapeStep(n, mana, destination)
    if n == 1 then
        -- ветра (cyclone/wind waker) на себя
        local winds = FindEscapeWinds()
        if winds and Ability.IsCastable(winds, mana) and CanOrder("escape_winds") then
            Ability.CastTarget(winds, me)
            print("[escape] Winds cast on self")
            return true
        end
        return false

    elseif n == 2 then
        -- blink в сторону цели побега
        if IsEscapeItemEnabled("item_blink") then
            local blink = FindEscapeBlink()
            local arcane_blink = FindEscapeArcaneBlink()
            local blinkPos = GetEscapeBlinkPosition(destination)

            if blink and Ability.IsCastable(blink, mana) and CanOrder("escape_blink") then
                Ability.CastPosition(blink, blinkPos)
                print("[escape] Blink cast toward destination")
                return true
            end
            if arcane_blink and Ability.IsCastable(arcane_blink, mana) and CanOrder("escape_arcane_blink") then
                Ability.CastPosition(arcane_blink, blinkPos)
                print("[escape] Arcane Blink cast toward destination")
                return true
            end
        end
        return false

    elseif n == 3 then
        -- Defense Matrix на себя вместо турелек (у старого Тинкера нет позиционного скилла прикрытия)
        if escapeUseMatrix:Get() then
            if e and Ability.IsCastable(e, mana) and CanOrder("escape_matrix") then
                Ability.CastTarget(e, me)
                print("[escape] Defense Matrix cast on self while escaping")
                return true
            end
        end
        return false
    end
    return false
end

local last_escape_move_order = 0
local escape_move_order_delay = 0.15

local function CanIssueEscapeMoveOrder()
    local time = GameRules.GetGameTime()
    if time - last_escape_move_order > escape_move_order_delay then
        last_escape_move_order = time
        return true
    end
    return false
end

local wasEscapeDown = false

local function EscapeUpdate()
    UpdateEnemyLastKnownPositions()

    local isDown = escapebind:IsDown()

    if wasEscapeDown and not isDown then
        ResetEscape()
        print("[escape] Reset (key released)")
    end
    wasEscapeDown = isDown

    if not isDown then
        return
    end

    local currentMana = NPC.GetMana(me)
    local destination = GetEscapeDestination()

    if CanIssueEscapeMoveOrder() then
        Player.PrepareUnitOrders(player, Enum.UnitOrder.mygame_UNIT_ORDER_MOVE_TO_POSITION, nil, destination, nil, Enum.PlayerOrderIssuer.mygame_ORDER_ISSUER_PASSED_UNIT_ONLY, me)
    end

    local attempts = 0
    while attempts < ESCAPE_STEP_COUNT do
        local casted = tryEscapeStep(escapeStep, currentMana, destination)

        if casted then
            escapeStep = escapeStep + 1
            if escapeStep > ESCAPE_STEP_COUNT then escapeStep = 1 end
            break
        else
            escapeStep = escapeStep + 1
            if escapeStep > ESCAPE_STEP_COUNT then
                escapeStep = 1
                break
            end
            attempts = attempts + 1
        end
    end
end

-- ============ COMBO STEP MACHINE (старый патч) ============
-- шаги: Shiva's Guard -> Blink -> Soul Ring -> Defense Matrix -> Heat-Seeking Missile ->
--       Warp Flare -> Ethereal Blade -> Dagon -> Laser -> Rearm
-- ракетки теперь кастуются РАНЬШЕ лазера: подтверждение лазера по кулдауну идёт долго
-- (иногда до ~0.5-1с до обновления кулдауна в API), и если он в начале очереди — это
-- тормозит остальную часть комбо. Поставив его последним перед Rearm, эта задержка
-- больше не блокирует остальные касты.
local step = 1
local STEP_COUNT = 10

local pendingConfirm = false
local pendingAbility = nil
local pendingStartTime = 0
local CONFIRM_TIMEOUT = 0.3

local pendingRetries = 0
local MAX_PENDING_RETRIES = 3

-- шаги, требующие подтверждения кулдауном: Heat-Seeking Missile(5), Warp Flare(6), Laser(9)
local CONFIRM_STEPS = { [5] = true, [6] = true, [9] = true }

local function ResetCombo()
    step = 1
    pendingConfirm = false
    pendingAbility = nil
    pendingStartTime = 0
    pendingRetries = 0
end

local function tryStep(n, mana, pos, enemyTarget)
    if n == 1 then
        -- Shiva's Guard (инициация/замедление)
        if useShivas:Get() and IsComboItemEnabled("item_shivas_guard") then
            local shivas = FindShivasGuard()
            if shivas and Ability.GetCooldown(shivas) <= 0 and CanOrder("shivas") then
                Ability.CastNoTarget(shivas)
                print("[combo] Shiva's Guard cast")
                return true
            end
        end
        return false

    elseif n == 2 then
        -- Blink к позиции/врагу
        if IsComboItemEnabled("item_blink") then
            local blink = FindBlink()
            local arcane_blink = FindArcaneBlink()

            if blink and Ability.IsCastable(blink, mana) and CanOrder("blink") then
                Ability.CastPosition(blink, pos)
                print("[combo] Blink cast")
                return true
            end
            if arcane_blink and Ability.IsCastable(arcane_blink, mana) and CanOrder("arcane_blink") then
                Ability.CastPosition(arcane_blink, pos)
                print("[combo] Arcane Blink cast")
                return true
            end
        end
        return false

    elseif n == 3 then
        -- Soul Ring (мана)
        if useSoulRing:Get() and IsComboItemEnabled("item_soul_ring") then
            local soulring = FindSoulRing()
            if soulring and Ability.GetCooldown(soulring) <= 0 and CanOrder("soul_ring") then
                Ability.CastNoTarget(soulring)
                print("[combo] Soul Ring cast")
                return true
            end
        end
        return false

    elseif n == 4 then
        -- Defense Matrix на себя (замена турелькам, у старого кита нет позиционного скилла)
        if useMatrix:Get() then
            if e and Ability.IsCastable(e, mana) and CanOrder("matrix") then
                Ability.CastTarget(e, me)
                print("[combo] Defense Matrix cast on self")
                return true
            end
        end
        return false

    elseif n == 5 then
        -- Heat-Seeking Missile [CONFIRM] — теперь кастуется ПЕРВЫМ из ударных скиллов
        if enemyTarget and w and Ability.IsCastable(w, mana) and CanOrder("missile") then
            Ability.CastNoTarget(w)
            print("[combo] Heat-Seeking Missile cast attempt (" .. pendingRetries .. ")")
            pendingConfirm = true
            pendingAbility = w
            pendingStartTime = GameRules.GetGameTime()
            return true
        end
        return false

    elseif n == 6 then
        -- Warp Flare на врага [CONFIRM]
        if enemyTarget and d and Ability.IsCastable(d, mana) and CanOrder("warp_flare") then
            Ability.CastTarget(d, enemyTarget)
            print("[combo] Warp Flare cast attempt (" .. pendingRetries .. ")")
            pendingConfirm = true
            pendingAbility = d
            pendingStartTime = GameRules.GetGameTime()
            return true
        end
        return false

    elseif n == 7 then
        -- Ethereal Blade на врага
        if IsComboItemEnabled("item_ethereal_blade") then
            local ethereal = FindEtherealBlade()
            if ethereal and enemyTarget and Ability.IsCastable(ethereal, mana) and CanOrder("ethereal") then
                Ability.CastTarget(ethereal, enemyTarget)
                print("[combo] Ethereal Blade cast")
                return true
            end
        end
        return false

    elseif n == 8 then
        -- Dagon на врага
        if IsComboItemEnabled("item_dagon") then
            local dagon = FindDagon()
            if dagon and enemyTarget and Ability.IsCastable(dagon, mana) and CanOrder("dagon") then
                Ability.CastTarget(dagon, enemyTarget)
                print("[combo] Dagon cast")
                return true
            end
        end
        return false

    elseif n == 9 then
        -- Laser на врага [CONFIRM] — теперь кастуется ПОСЛЕДНИМ из ударных скиллов
        -- (подтверждение по кулдауну самое долгое, поэтому не должно задерживать остальные)
        if useLaser:Get() and enemyTarget and q and Ability.IsCastable(q, mana) and CanOrder("laser") then
            Ability.CastTarget(q, enemyTarget)
            print("[combo] Laser cast attempt (" .. pendingRetries .. ")")
            pendingConfirm = true
            pendingAbility = q
            pendingStartTime = GameRules.GetGameTime()
            return true
        end
        return false

    elseif n == 10 then
        -- Rearm
        if r and Ability.IsCastable(r, mana) and CanOrder("rearm") then
            Ability.CastNoTarget(r)
            print("[combo] Rearm cast")
            return true
        end
        return false
    end
    return false
end

-- ============ DRAW ============
function DrawWorldCircle(worldPos, radius, color, segments)
    segments = segments or 40
    local prevPoint, prevVisible = nil, false

    for i = 0, segments do
        local angle = (i / segments) * math.pi * 2
        local px = worldPos.x + math.cos(angle) * radius
        local py = worldPos.y + math.sin(angle) * radius
        local worldPoint = Vector(px, py, worldPos.z)

        local screenPoint, visible = Render.WorldToScreen(worldPoint)

        if visible and prevVisible then
            Render.Line(prevPoint, screenPoint, color, 2)
        end

        prevPoint = screenPoint
        prevVisible = visible
    end
end

function script.OnDraw()
    if combobind:IsDown() then
        local x, y = Input.GetCursorPos()
        Render.Circle(Vec2(x, y), 25, Color(255, 255, 255, 255), 2)
    end
end

-- ============ UPDATE ============
local wasComboDown = false

function script.OnUpdate()
    EscapeUpdate()

    local isDown = combobind:IsDown()

    if wasComboDown and not isDown then
        ResetCombo()
        print("[combo] Reset (key released)")
    end
    wasComboDown = isDown

    if not isDown then
        return
    end

    local currentMana = NPC.GetMana(me)
    local pos = Input.GetWorldCursorPos()
    local enemyTarget = Input.GetNearestHeroToCursor(Entity.GetTeamNum(me), Enum.TeamType.TEAM_ENEMY)

    if gotocursor:Get() then
        Player.PrepareUnitOrders(player, Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION, nil, pos, nil, Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, me)
    end

    if pendingConfirm then
        if Ability.GetCooldown(pendingAbility) > 0 then
            print("[combo] Cast confirmed, moving to next step")
            pendingConfirm = false
            pendingAbility = nil
            pendingRetries = 0
            step = step + 1
            if step > STEP_COUNT then step = 1 end
        elseif GameRules.GetGameTime() - pendingStartTime > CONFIRM_TIMEOUT then
            pendingConfirm = false
            pendingAbility = nil
            pendingRetries = pendingRetries + 1

            if pendingRetries >= MAX_PENDING_RETRIES then
                print("[combo] Step " .. step .. " failed " .. pendingRetries .. " times, skipping")
                pendingRetries = 0
                step = step + 1
                if step > STEP_COUNT then step = 1 end
            else
                print("[combo] Cast not confirmed (" .. pendingRetries .. "/" .. MAX_PENDING_RETRIES .. "), retrying same step")
            end
        end
        return
    end

    local attempts = 0
    while attempts < STEP_COUNT do
        local casted = tryStep(step, currentMana, pos, enemyTarget)

        if casted then
            if not CONFIRM_STEPS[step] then
                step = step + 1
                if step > STEP_COUNT then step = 1 end
            end
            break
        else
            step = step + 1
            if step > STEP_COUNT then
                step = 1
                break
            end
            attempts = attempts + 1
        end
    end
end

return script