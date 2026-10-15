local script = {}

-- ============ MENU STRUCTURE ============
local comboTab = Menu.Create("Heroes", "Hero List", "Tinker", "Tinker Misc Functions")
local Comb = comboTab:Create("Настройки комбо с глимером")
local Escape = comboTab:Create("Настройки побега")

local player = Players.GetLocal()
local me = Heroes.GetLocal()

-- abilities
local q = NPC.GetAbilityByIndex(me, 0) -- Laser
local w = NPC.GetAbilityByIndex(me, 1) -- March of the Machines
local e = NPC.GetAbilityByIndex(me, 2) -- Deploy Turrets (позиционный скилл)
local d = NPC.GetAbilityByIndex(me, 3) -- Warp Flare
local f = NPC.GetAbilityByIndex(me, 4)
local r = NPC.GetAbilityByIndex(me, 5) -- Rearm

local ui = {}
ui.Comb = {}

-- order_delay
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

--escapeTab
ui.Escape = {}
Escape:Label("Модуль побега")

local escapeItemsWidget = Escape:MultiSelect("Предметы для побега", {
    { "item_blink", "panorama/images/items/blink_png.vtex_c", true },
    { "item_cyclone", "panorama/images/items/cyclone_png.vtex_c", true },
    { "item_glimmer_cape", "panorama/images/items/glimmer_cape_png.vtex_c", true },
    { "item_wind_waker", "panorama/images/items/wind_waker_png.vtex_c", true },
}, true)

local escapeRadiusSlider = Escape:Slider("Радиус при побеге от врага", 100, 1625, 900)
local escapeUseTurrets = Escape:Switch("Использовать турельки при побеге", false)
local escapeModeCombo = Escape:Combo("Направление побега", { "На фонтан", "На курсор" }, 0)
local escapebind = Escape:Bind("Escape Key", Enum.ButtonCode.BUTTON_CODE_NONE)

local function IsEscapeItemEnabled(itemName)
    return escapeItemsWidget:Get(itemName)
end

-- ============ ПОИСК ПРЕДМЕТОВ ПОБЕГА ============
local function FindEscapeBlink() return NPC.GetItem(me, "item_blink", true) end
local function FindEscapeArcaneBlink() return NPC.GetItem(me, "item_arcane_blink", true) end
local function FindEscapeGlimmer() return NPC.GetItem(me, "item_glimmer_cape", true) end

-- "ветра" - любой из двух предметов, что первый найдётся и включён
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
        return Vector(-7189, -6591, 384) -- уточнить точные координаты
    else
        return Vector(7375, 6625, 384) -- уточнить точные координаты
    end
end

local function GetEscapeDestination()
    local mode = escapeModeCombo:Get() -- 0 = На фонтан, 1 = На курсор
    if mode == 1 then
        return Input.GetWorldCursorPos()
    else
        return GetFountainPosition()
    end
end

-- позиция для блинка: от героя в сторону цели побега, но с учётом ближайшего врага и заданного радиуса
local function GetEscapeBlinkPosition(destination)
    local myPos = Entity.GetAbsOrigin(me)
    local dirX = destination.x - myPos.x
    local dirY = destination.y - myPos.y
    local dist = math.sqrt(dirX * dirX + dirY * dirY)

    if dist <= 0 then
        return myPos
    end

    local radius = escapeRadiusSlider:Get()
    local blinkDist = dist

    local nx = dirX / dist
    local ny = dirY / dist

    return Vector(myPos.x + nx * blinkDist, myPos.y + ny * blinkDist, myPos.z)
end

-- ============ ESCAPE STEP MACHINE ============
local escapeStep = 1
local ESCAPE_STEP_COUNT = 4 -- glimmer -> winds -> blink -> turrets(опционально)

local escapePendingConfirm = false
local escapePendingAbility = nil
local escapePendingStartTime = 0
local ESCAPE_CONFIRM_TIMEOUT = 1.0

local function ResetEscape()
    escapeStep = 1
    escapePendingConfirm = false
    escapePendingAbility = nil
    escapePendingStartTime = 0
end

local function tryEscapeStep(n, mana, destination)
    if n == 1 then
        -- glimmer
        if IsEscapeItemEnabled("item_glimmer_cape") then
            local glimer = FindEscapeGlimmer()
            if glimer and Ability.GetCooldown(glimer) <= 0 and CanOrder("escape_glimmer") then
                Ability.CastTarget(glimer, me)
                print("[escape] Glimmer cast")
                return true
            end
        end
        return false

    elseif n == 2 then
        -- ветра (cyclone/wind waker) на себя
        local winds = FindEscapeWinds()
        if winds and Ability.IsCastable(winds, mana) and CanOrder("escape_winds") then
            Ability.CastTarget(winds, me)
            print("[escape] Winds cast on self")
            return true
        end
        return false

    elseif n == 3 then
        -- blink в сторону цели побега, ограниченный радиусом
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

    elseif n == 4 then
        -- турельки для прикрытия отхода (опционально)
        if escapeUseTurrets:Get() then
            local enemyTarget = Input.GetNearestHeroToCursor(Entity.GetTeamNum(me), Enum.TeamType.TEAM_ENEMY)
            if enemyTarget and e and Ability.IsCastable(e, mana) and CanOrder("escape_turrets") then
                local turretPos = Entity.GetAbsOrigin(enemyTarget)
                Ability.CastPosition(e, turretPos)
                print("[escape] Turrets cast while escaping")
                return true
            end
        end
        return false
    end
    return false
end

-- ============ ОТСЛЕЖИВАНИЕ ПОСЛЕДНЕЙ ПОЗИЦИИ ВРАГОВ ============
-- храним последнюю ВИДИМУЮ позицию каждого врага, даже если он ушёл в туман
local enemyLastKnownPos = {}

local function UpdateEnemyLastKnownPositions()
    local enemies = Heroes.GetAll()
    if not enemies then return end

    for _, enemy in ipairs(enemies) do
        if enemy
        and Entity.GetTeamNum(enemy) ~= Entity.GetTeamNum(me)
        and Entity.IsAlive(enemy)
        and not Entity.IsDormant(enemy) then
            -- враг видим сейчас - обновляем его позицию
            enemyLastKnownPos[enemy] = Entity.GetAbsOrigin(enemy)
        end
        -- если враг в тумане (IsDormant == true) - НЕ обновляем,
        -- сохранённая позиция остаётся последней известной
    end
end

-- ============ ОБХОД ВРАГОВ ПО РАДИУСУ (только для режима "На фонтан") ============
-- метод потенциальных полей: к направлению на цель добавляются векторы отталкивания
-- от врагов, чья последняя известная позиция ближе заданного радиуса
local function GetAvoidanceDestination(rawDestination)
    local myPos = Entity.GetAbsOrigin(me)
    local avoidRadius = escapeRadiusSlider:Get()

    local dirX = rawDestination.x - myPos.x
    local dirY = rawDestination.y - myPos.y
    local dist = math.sqrt(dirX * dirX + dirY * dirY)

    if dist <= 0 then
        return rawDestination
    end

    -- нормализованный вектор к цели (базовое притяжение)
    local attractX = dirX / dist
    local attractY = dirY / dist

    local repelX, repelY = 0, 0

    for enemy, lastPos in pairs(enemyLastKnownPos) do
        local ex = lastPos.x - myPos.x
        local ey = lastPos.y - myPos.y
        local edist = math.sqrt(ex * ex + ey * ey)

        if edist > 0 and edist < avoidRadius then
            -- сила отталкивания сильнее, чем ближе враг
            local strength = (avoidRadius - edist) / avoidRadius
            -- вектор ОТ врага (обратное направление)
            repelX = repelX - (ex / edist) * strength
            repelY = repelY - (ey / edist) * strength
        end
    end

    -- комбинируем притяжение к цели и отталкивание от врагов
    local combinedX = attractX + repelX
    local combinedY = attractY + repelY
    local combinedDist = math.sqrt(combinedX * combinedX + combinedY * combinedY)

    if combinedDist <= 0 then
        return rawDestination
    end

    local nx = combinedX / combinedDist
    local ny = combinedY / combinedDist

    -- новая точка движения - в направлении обхода, на исходную дистанцию до цели
    return Vector(myPos.x + nx * dist, myPos.y + ny * dist, myPos.z)
end

-- возвращает финальную точку назначения с учётом режима и обхода врагов
local function GetEscapeDestination()
    local mode = escapeModeCombo:Get() -- 0 = На фонтан, 1 = На курсор

    if mode == 1 then
        -- курсор: без обхода врагов, прямая точка
        return Input.GetWorldCursorPos()
    else
        -- фонтан: с обходом врагов по радиусу
        local fountainPos = GetFountainPosition()
        return GetAvoidanceDestination(fountainPos)
    end
end

-- ============ ДЕБАГ ПЕРЕКЛЮЧАТЕЛЬ ЗОН ОБХОДА ============

-- ============ ТРОТТЛИНГ ПРИКАЗОВ ДВИЖЕНИЯ ПРИ ПОБЕГЕ ============
local last_escape_move_order = 0
local escape_move_order_delay = 0.15 -- пауза между приказами движения, чтобы не спамить

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
    
    -- обновляем последние известные позиции врагов каждый тик, независимо от нажатия кнопки
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
        Player.PrepareUnitOrders(player, Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION, nil, destination, nil, Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, me)
    end
    if escapePendingConfirm then
        if Ability.GetCooldown(escapePendingAbility) > 0 then
            print("[escape] Cast confirmed, moving to next step")
            escapePendingConfirm = false
            escapePendingAbility = nil
            escapeStep = escapeStep + 1
            if escapeStep > ESCAPE_STEP_COUNT then escapeStep = 1 end
        elseif GameRules.GetGameTime() - escapePendingStartTime > ESCAPE_CONFIRM_TIMEOUT then
            escapePendingConfirm = false
            escapePendingAbility = nil
        end
        return
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


-- проверка, включён ли конкретный предмет в выборе
local function IsEscapeItemEnabled(itemName)
    return escapeItemsWidget:Get(itemName)
end
----------------------------------------- end escapeTab
-- comboTab
ui.Comb.gotocursor = Comb:Switch("Идти к курсору (плохо работает не включать)", false)
local combobind = Comb:Bind("Combo Key", Enum.ButtonCode.BUTTON_CODE_NONE)
ui.Comb.global_switch = Comb:Switch("Помощник радиуса", false)
ui.Comb.useTurrets = Comb:Switch("Использовать турельки", false)

-- ============ ДИНАМИЧЕСКИЙ ПОИСК ПРЕДМЕТОВ ============
local function FindBlink() return NPC.GetItem(me, "item_blink", true) end
local function FindArcaneBlink() return NPC.GetItem(me, "item_arcane_blink", true) end
local function FindGlimmer() return NPC.GetItem(me, "item_glimmer_cape", true) end
local function FindEthereal() return NPC.GetItem(me, "item_ethereal_blade", true) end

local dagon_names = {
    "item_dagon", "item_dagon_2", "item_dagon_3", "item_dagon_4", "item_dagon_5",
}
local function FindDagon()
    for _, name in ipairs(dagon_names) do
        local item = NPC.GetItem(me, name, true)
        if item then return item end
    end
    return nil
end

-- ============ FOG OF WAR CHECK ============
local function IsInFog(entity)
    if not entity then return true end
    return Entity.IsDormant(entity)
end

-- ============ STEP MACHINE ============
-- шаги: glimmer -> blink -> warp flare -> ethereal -> dagon -> laser -> turrets -> rearm
local step = 1
local STEP_COUNT = 8

local pendingConfirm = false
local pendingAbility = nil
local pendingStartTime = 0
local CONFIRM_TIMEOUT = 1.0

local pendingRetries = 0
local MAX_PENDING_RETRIES = 3

-- шаги, требующие подтверждения кулдауном: warp flare, laser, turrets
local CONFIRM_STEPS = { [3] = true, [6] = true, [7] = true }

local function ResetCombo()
    step = 1
    pendingConfirm = false
    pendingAbility = nil
    pendingStartTime = 0
    pendingRetries = 0
end

local function tryStep(n, mana, pos, enemyTarget)
    if n == 1 then
        local glimer = FindGlimmer()
        if glimer and Ability.GetCooldown(glimer) <= 0 and CanOrder("glimmer") then
            Ability.CastTarget(glimer, me)
            print("[combo] Glimmer cast")
            return true
        end
        return false

    elseif n == 2 then
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
        return false

    elseif n == 3 then
        if enemyTarget and d and Ability.IsCastable(d, mana) and CanOrder("warp_flare") then
            Ability.CastTarget(d, enemyTarget)
            print("[combo] Warp Flare cast attempt (" .. pendingRetries .. ")")
            pendingConfirm = true
            pendingAbility = d
            pendingStartTime = GameRules.GetGameTime()
            return true
        end
        return false

    elseif n == 4 then
        local ethereal = FindEthereal()
        if ethereal and enemyTarget and Ability.IsCastable(ethereal, mana) and CanOrder("ethereal") then
            Ability.CastTarget(ethereal, enemyTarget)
            print("[combo] Ethereal Blade cast")
            return true
        end
        return false

    elseif n == 5 then
        local dagon = FindDagon()
        if dagon and enemyTarget and Ability.IsCastable(dagon, mana) and CanOrder("dagon") then
            Ability.CastTarget(dagon, enemyTarget)
            print("[combo] Dagon cast")
            return true
        end
        return false

    elseif n == 6 then
        if enemyTarget and q and Ability.IsCastable(q, mana) and CanOrder("laser") then
            Ability.CastTarget(q, enemyTarget)
            print("[combo] Laser cast attempt (" .. pendingRetries .. ")")
            pendingConfirm = true
            pendingAbility = q
            pendingStartTime = GameRules.GetGameTime()
            return true
        end
        return false

    elseif n == 7 then
        -- турельки кастуются только если переключатель включён
        if not ui.Comb.useTurrets:Get() then
            return false
        end
        if enemyTarget and e and Ability.IsCastable(e, mana) and CanOrder("turrets") then
            local turretPos = Entity.GetAbsOrigin(enemyTarget)
            Ability.CastPosition(e, turretPos)
            print("[combo] Turrets cast attempt (" .. pendingRetries .. ")")
            pendingConfirm = true
            pendingAbility = e
            pendingStartTime = GameRules.GetGameTime()
            return true
        end
        return false

    elseif n == 8 then
        if r and Ability.IsCastable(r, mana) and CanOrder("rearm") then
            Ability.CastNoTarget(r)
            print("[combo] Rearm cast")
            return true
        end
        return false
    end
    return false
end

function script.OnDraw()
    if combobind:IsDown() then
        local x, y = Input.GetCursorPos()
        Render.Circle(Vec2(x, y), 25, Color(255, 255, 255, 255), 2)
    end

    if ui.Comb.global_switch:Get() then
        local laserRange = Ability.GetCastRange(q)
        local warpFlareRange = Ability.GetCastRange(d)

        local enemies = Heroes.GetAll()
        if enemies then
            for _, enemy in ipairs(enemies) do
                if enemy
                and Entity.GetTeamNum(enemy) ~= Entity.GetTeamNum(me)
                and Entity.IsAlive(enemy)
                and not IsInFog(enemy) then

                    local enemyPos = Entity.GetAbsOrigin(enemy)

                    DrawWorldCircle(enemyPos, laserRange, Color(255, 80, 80, 180), 40)
                    DrawWorldCircle(enemyPos, warpFlareRange, Color(80, 180, 255, 180), 40)
                end
            end
        end
    end
end

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

local wasComboDown = false

function script.OnUpdate()
    EscapeUpdate() -- обновление модуля побега каждый тик
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

    if ui.Comb.gotocursor:Get() then
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