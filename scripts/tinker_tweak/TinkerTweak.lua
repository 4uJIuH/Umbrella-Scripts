local script = {}

-- ============ MENU STRUCTURE ============
local comboTab = Menu.Create("Heroes", "Hero List", "Tinker", "Tinker Misc Functions")
local Comb = comboTab:Create("Твики Tinker")
local BlinkTab = comboTab:Create("Blink radius")
local EulBlinkTab = comboTab:Create("Eul Blink")
local AegisTab = comboTab:Create("Aegis Blink")

local player = Players.GetLocal()
local me = Heroes.GetLocal()

-- abilities
local q = NPC.GetAbilityByIndex(me, 0) -- Laser
local d = NPC.GetAbilityByIndex(me, 3) -- Warp Flare

-- ============ UI НАСТРОЙКИ ============
local ui = {}
ui.Comb = {}
ui.Blink = {}
ui.EulBlink = {}
ui.Aegis = {}

-- НАСТРОЙКИ ПОМОЩНИКА РАДИУСА
ui.Comb.global_switch = Comb:Switch("Помощник радиуса", false)
ui.Comb.laser_color = Comb:ColorPicker("Цвет Laser", Color(255, 80, 80, 180))
ui.Comb.warp_color = Comb:ColorPicker("Цвет Warp Flare", Color(80, 180, 255, 180))

local effectTypes = {
    "Сплошной (Solid)",
    "Пунктир (Dashed)",
    "Свечение (Glow)",
}
ui.Comb.radius_effect = Comb:Combo("Тип радиуса", effectTypes, 0)
ui.Comb.glow_intensity = Comb:Slider("Интенсивность свечения", 1, 10, 3)

-- ============ НАСТРОЙКИ BLINK RADIUS ============
BlinkTab:Label("Показывает радиус Blink вокруг Tinker")
ui.Blink.enabled = BlinkTab:Switch("Включить Blink radius", false)
ui.Blink.color = BlinkTab:ColorPicker("Цвет радиуса", Color(0, 255, 100, 180))
ui.Blink.blink_effect = BlinkTab:Combo("Тип радиуса", effectTypes, 0)
ui.Blink.blink_intensity = BlinkTab:Slider("Интенсивность свечения", 1, 10, 3)

-- ============ НАСТРОЙКИ EUL BLINK ============
EulBlinkTab:Label("Помощник Blink после Eul / Wind Waker")
ui.EulBlink.enabled = EulBlinkTab:Switch("Включить помощник", true)
ui.EulBlink.show_cone = EulBlinkTab:Switch("Показывать конус", true)
ui.EulBlink.show_cursor = EulBlinkTab:Switch("Показывать линию курсора", true)
ui.EulBlink.instant_half_angle = EulBlinkTab:Slider("Полуугол конуса", 5, 60, 45)
ui.EulBlink.cone_color = EulBlinkTab:ColorPicker("Цвет конуса", Color(90, 220, 255, 230))
ui.EulBlink.valid_color = EulBlinkTab:ColorPicker("Цвет доступного курсора", Color(80, 255, 140, 255))
ui.EulBlink.invalid_color = EulBlinkTab:ColorPicker("Цвет недоступного курсора", Color(255, 80, 80, 255))
ui.EulBlink.thickness = EulBlinkTab:Slider("Толщина линии", 1, 6, 2)

-- ============ НАСТРОЙКИ AEGIS BLINK ============
AegisTab:Label("Конус блинка после возрождения от Aegis")
ui.Aegis.enabled = AegisTab:Switch("Включить", true)
ui.Aegis.coneAngle = AegisTab:Slider("Угол конуса", 5, 90, 22.5)
ui.Aegis.postRespawnTime = AegisTab:Slider("Показывать после возрождения", 0, 3, 0.75)
ui.Aegis.useBlinkRange = AegisTab:Switch("Использовать дальность Blink", true)
ui.Aegis.fallbackRange = AegisTab:Slider("Резервная дальность", 100, 2000, 1200)
ui.Aegis.onlyWithBlink = AegisTab:Switch("Только при наличии Blink", true)
ui.Aegis.showCenterLine = AegisTab:Switch("Показывать центральную линию", true)
ui.Aegis.showBorders = AegisTab:Switch("Показывать границы", true)
ui.Aegis.borderColor = AegisTab:ColorPicker("Цвет границ", Color(85, 190, 255, 235))
ui.Aegis.spamBlink = AegisTab:Switch("Спам блинком по курсору", true)
ui.Aegis.preRespawnSpamTime = AegisTab:Slider("Начинать спам до возрождения", 0, 1, 0.30)
ui.Aegis.spamBlinkBind = AegisTab:Bind("Клавиша спама Blink", Enum.ButtonCode.BUTTON_CODE_NONE)

-- ============ FOG OF WAR CHECK ============
local function IsInFog(entity)
    if not entity then return true end
    return Entity.IsDormant(entity)
end

-- ============ ПОИСК БЛИНКА ============
local function FindBlink()
    local blink = NPC.GetItem(me, "item_blink", true)
    if blink then return blink end
    local arcane_blink = NPC.GetItem(me, "item_arcane_blink", true)
    if arcane_blink then return arcane_blink end
    return nil
end

-- ============ РАЗНЫЕ ТИПЫ ОТРИСОВКИ РАДИУСА ============

function DrawSolidCircle(worldPos, radius, color, segments)
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

function DrawDashedCircle(worldPos, radius, color, segments)
    segments = segments or 60
    local prevPoint, prevVisible = nil, false
    local dashLength = 5
    local gapLength = 5
    local counter = 0
    for i = 0, segments do
        local angle = (i / segments) * math.pi * 2
        local px = worldPos.x + math.cos(angle) * radius
        local py = worldPos.y + math.sin(angle) * radius
        local worldPoint = Vector(px, py, worldPos.z)
        local screenPoint, visible = Render.WorldToScreen(worldPoint)
        counter = counter + 1
        if visible and prevVisible and counter % (dashLength + gapLength) < dashLength then
            Render.Line(prevPoint, screenPoint, color, 2)
        end
        prevPoint = screenPoint
        prevVisible = visible
    end
end

function DrawGlowCircle(worldPos, radius, color, segments, intensity)
    intensity = intensity or 3
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
    for j = 1, intensity do
        local glowRadius = radius + j * 3
        local glowColor = Color(color.r, color.g, color.b, color.a / (j * 2))
        local prevPoint2, prevVisible2 = nil, false
        for i = 0, segments do
            local angle = (i / segments) * math.pi * 2
            local px = worldPos.x + math.cos(angle) * glowRadius
            local py = worldPos.y + math.sin(angle) * glowRadius
            local worldPoint = Vector(px, py, worldPos.z)
            local screenPoint, visible = Render.WorldToScreen(worldPoint)
            if visible and prevVisible2 then
                Render.Line(prevPoint2, screenPoint, glowColor, 1)
            end
            prevPoint2 = screenPoint
            prevVisible2 = visible
        end
    end
end

function DrawRadiusWithEffect(worldPos, radius, color, effectType, intensity)
    if effectType == 0 then
        DrawSolidCircle(worldPos, radius, color)
    elseif effectType == 1 then
        DrawDashedCircle(worldPos, radius, color)
    elseif effectType == 2 then
        DrawGlowCircle(worldPos, radius, color, 40, intensity)
    else
        DrawSolidCircle(worldPos, radius, color)
    end
end

-- ============ EUL BLINK HELPER (УПРОЩЁННЫЙ) ============
local eulState = {
    inCyclone = false,
    startTime = 0,
    landing = nil,
    forward = nil,
}

local function eulGameTime()
    if GameRules and GameRules.GetGameTime then
        return GameRules.GetGameTime()
    end
    return os.clock()
end

local function eulHeroForward(hero)
    local rotation = Entity.GetRotation(hero)
    if rotation then
        local yaw = rotation.yaw or 0
        local r = math.rad(yaw)
        return { x = math.cos(r), y = math.sin(r) }
    end
    return nil
end

local function eulPointAt(origin, direction, distance)
    return Vector(origin.x + direction.x * distance, origin.y + direction.y * distance, origin.z)
end

local function eulRotateDirection(direction, degrees)
    local r = math.rad(degrees)
    local c, s = math.cos(r), math.sin(r)
    return { x = direction.x * c - direction.y * s, y = direction.x * s + direction.y * c }
end

local function eulDrawCone(origin, direction, range, halfAngle, color, thickness)
    if not origin or not direction then return end
    
    local segments = {}
    local left = eulRotateDirection(direction, -halfAngle)
    local right = eulRotateDirection(direction, halfAngle)
    table.insert(segments, { from = origin, to = eulPointAt(origin, left, range) })
    table.insert(segments, { from = origin, to = eulPointAt(origin, right, range) })
    
    for i = 0, 16 do
        local pct = i / 16
        local angle = -halfAngle + halfAngle * 2 * pct
        local dir = eulRotateDirection(direction, angle)
        local point = eulPointAt(origin, dir, range)
        if i > 0 then
            local prev = eulPointAt(origin, eulRotateDirection(direction, -halfAngle + halfAngle * 2 * ((i-1)/16)), range)
            table.insert(segments, { from = prev, to = point })
        end
    end
    
    for _, seg in ipairs(segments) do
        if Render and Render.WorldToScreen then
            local from = Render.WorldToScreen(seg.from)
            local to = Render.WorldToScreen(seg.to)
            if from and to then
                Render.Line(from, to, color, thickness)
            end
        end
    end
end

local function eulDrawLine(from, to, color, thickness)
    if not from or not to then return end
    if Render and Render.WorldToScreen then
        local f = Render.WorldToScreen(from)
        local t = Render.WorldToScreen(to)
        if f and t then
            Render.Line(f, t, color, thickness)
        end
    end
end

function script.OnPrepareUnitOrders(order)
    -- Eul Blink
    if ui.EulBlink.enabled:Get() then
        local hero = me
        if hero then
            local orderType = order.order or order.orderType
            if orderType == 6 and order.target == hero then -- DOTA_UNIT_ORDER_CAST_TARGET
                local abilityName = Ability.GetName(order.ability)
                if abilityName == "item_cyclone" or abilityName == "item_wind_waker" then
                    local forward = eulHeroForward(hero)
                    local pos = Entity.GetAbsOrigin(hero)
                    if forward and pos then
                        eulState.inCyclone = true
                        eulState.startTime = eulGameTime()
                        eulState.landing = Vector(pos.x, pos.y, pos.z + 24)
                        eulState.forward = forward
                    end
                end
            end
        end
    end
    return true
end

-- ============ AEGIS BLINK HELPER (УПРОЩЁННЫЙ) ============
local aegisState = {
    hasAegis = false,
    wasAlive = true,
    cone = nil,
    respawnTime = 0,
}

local function aegisPointAt(origin, direction, distance)
    return Vector(origin.x + direction.x * distance, origin.y + direction.y * distance, origin.z)
end

local function aegisRotateDirection(direction, degrees)
    local r = math.rad(degrees)
    local c, s = math.cos(r), math.sin(r)
    return { x = direction.x * c - direction.y * s, y = direction.x * s + direction.y * c }
end

local function aegisDrawCone(cone)
    if not cone or not cone.position or not cone.direction then return end
    
    local color = ui.Aegis.borderColor:Get()
    local thickness = 2
    local range = cone.range or 1200
    local halfAngle = (ui.Aegis.coneAngle:Get() or 22.5) * 0.5
    
    local points = {}
    for i = 0, 24 do
        local pct = i / 24
        local angle = -halfAngle + halfAngle * 2 * pct
        local dir = aegisRotateDirection(cone.direction, angle)
        local point = aegisPointAt(cone.position, dir, range)
        table.insert(points, point)
    end
    
    if ui.Aegis.showBorders:Get() then
        eulDrawLine(cone.position, points[1], color, thickness)
        eulDrawLine(cone.position, points[#points], color, thickness)
        for i = 1, #points - 1 do
            eulDrawLine(points[i], points[i + 1], color, thickness)
        end
    end
    
    if ui.Aegis.showCenterLine:Get() then
        local center = aegisPointAt(cone.position, cone.direction, range)
        eulDrawLine(cone.position, center, color, thickness)
    end
end

-- ============ ОСНОВНАЯ ФУНКЦИЯ ОТРИСОВКИ ============
function script.OnDraw()
    -- ===== ПОМОЩНИК РАДИУСА =====
    if ui.Comb.global_switch:Get() then
        local laserRange = Ability.GetCastRange(q)
        local warpFlareRange = Ability.GetCastRange(d)
        local laserColor = ui.Comb.laser_color:Get()
        local warpColor = ui.Comb.warp_color:Get()
        local effectType = ui.Comb.radius_effect:Get()
        local intensity = ui.Comb.glow_intensity:Get()

        local enemies = Heroes.GetAll()
        if enemies then
            for _, enemy in ipairs(enemies) do
                if enemy and Entity.GetTeamNum(enemy) ~= Entity.GetTeamNum(me) and Entity.IsAlive(enemy) and not IsInFog(enemy) then
                    local enemyPos = Entity.GetAbsOrigin(enemy)
                    DrawRadiusWithEffect(enemyPos, laserRange, laserColor, effectType, intensity)
                    DrawRadiusWithEffect(enemyPos, warpFlareRange, warpColor, effectType, intensity)
                end
            end
        end
    end
    
    -- ===== BLINK RADIUS =====
    if ui.Blink.enabled:Get() then
        local blink = FindBlink()
        if blink then
            local blinkRange = Ability.GetCastRange(blink)
            local myPos = Entity.GetAbsOrigin(me)
            local color = ui.Blink.color:Get()
            local effectType = ui.Blink.blink_effect:Get()
            local intensity = ui.Blink.blink_intensity:Get()
            if blinkRange > 0 then
                DrawRadiusWithEffect(myPos, blinkRange, color, effectType, intensity)
            end
        end
    end

    -- ===== EUL BLINK =====
    if ui.EulBlink.enabled:Get() and eulState.inCyclone then
        local now = eulGameTime()
        local elapsed = now - eulState.startTime
        if elapsed < 2.5 and eulState.landing and eulState.forward then
            local blink = FindBlink()
            local range = blink and Ability.GetCastRange(blink) or 1200
            local halfAngle = ui.EulBlink.instant_half_angle:Get()
            local color = ui.EulBlink.cone_color:Get()
            local thickness = ui.EulBlink.thickness:Get()
            
            eulDrawCone(eulState.landing, eulState.forward, range, halfAngle, color, thickness)
            
            if ui.EulBlink.show_cursor:Get() then
                local cursor = Humanizer and Humanizer.GetServerCursorPos()
                if cursor then
                    local cursorPos = Vector(cursor.x, cursor.y, cursor.z + 24)
                    local dir = { x = cursorPos.x - eulState.landing.x, y = cursorPos.y - eulState.landing.y }
                    local len = math.sqrt(dir.x * dir.x + dir.y * dir.y)
                    if len > 0 then
                        dir.x = dir.x / len
                        dir.y = dir.y / len
                    end
                    local angle = math.deg(math.acos(eulState.forward.x * dir.x + eulState.forward.y * dir.y))
                    local cursorColor = angle <= halfAngle and ui.EulBlink.valid_color:Get() or ui.EulBlink.invalid_color:Get()
                    eulDrawLine(eulState.landing, cursorPos, cursorColor, thickness)
                end
            end
        else
            eulState.inCyclone = false
        end
    end

    -- ===== AEGIS BLINK =====
    if ui.Aegis.enabled:Get() then
        local alive = Entity.IsAlive(me)
        local now = eulGameTime()
        
        -- Проверяем наличие Aegis
        local aegis = NPC.GetItem(me, "item_aegis", true)
        
        -- Если герой жив и есть Aegis
        if alive and aegis then
            aegisState.hasAegis = true
            aegisState.wasAlive = true
            -- Сохраняем позицию и направление
            local pos = Entity.GetAbsOrigin(me)
            local forward = eulHeroForward(me)
            if pos and forward then
                aegisState.cone = {
                    position = Vector(pos.x, pos.y, pos.z + 20),
                    direction = forward,
                    range = ui.Aegis.fallbackRange:Get(),
                }
            end
        end
        
        -- Если герой умер и у него был Aegis
        if not alive and aegisState.hasAegis and aegisState.wasAlive then
            aegisState.wasAlive = false
            aegisState.respawnTime = now + 5.0 -- Aegis респавн 5 секунд
        end
        
        -- Если герой воскрес
        if alive and not aegisState.wasAlive and aegisState.respawnTime > 0 then
            aegisState.wasAlive = true
            aegisState.hasAegis = false
            -- Показываем конус ещё некоторое время
            aegisState.cone = aegisState.cone or {
                position = Entity.GetAbsOrigin(me),
                direction = eulHeroForward(me),
                range = ui.Aegis.fallbackRange:Get(),
            }
            aegisState.respawnTime = now + ui.Aegis.postRespawnTime:Get()
        end
        
        -- Рисуем конус
        if aegisState.cone then
            -- Проверяем, не истекло ли время
            local expireTime = aegisState.respawnTime
            if expireTime > 0 and now > expireTime then
                aegisState.cone = nil
            else
                aegisDrawCone(aegisState.cone)
            end
        end
    end
end

return script