local IlluminateVisualizer = {}

local KOTL_UNIT_NAME = "npc_dota_hero_keeper_of_the_light"
local ILLUMINATE_NAME = "keeper_of_the_light_illuminate"
local SPIRIT_FORM_ILLUMINATE_NAME = "keeper_of_the_light_spirit_form_illuminate"
local ILLUMINATE_ABILITY_NAMES = {
    SPIRIT_FORM_ILLUMINATE_NAME,
    ILLUMINATE_NAME,
}
local ILLUMINATE_ABILITY_NAME_SET = {
    [ILLUMINATE_NAME] = true,
    [SPIRIT_FORM_ILLUMINATE_NAME] = true,
}
local ILLUMINATE_MODIFIER_NAMES = {
    "modifier_keeper_of_the_light_spirit_form_illuminate",
    "modifier_keeper_of_the_light_illuminate",
}

local FALLBACK_TRAVEL_RANGE = 1550
local FALLBACK_RADIUS = 400
local FALLBACK_MAX_CHANNEL_TIME = 3.0
local ILLUMINATE_CAST_RANGE_BUFFER = 250
local MIN_DIRECTION_LENGTH_SQR = 0.0001
local DEFAULT_GEOMETRY_Z_OFFSET = 64
local END_CAP_SEGMENTS = 14

local MENU_FIRST_TAB = "General"
local MENU_SECTION = "Main"
local MENU_SECOND_TAB = "Illuminate Visualizer"
local MENU_THIRD_TAB = "Settings"
local MENU_GROUP = "Main"

local ui = {}
local state = {}
local font = nil

local function safeCall(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end

    local ok, result, result2, result3 = pcall(fn, ...)
    if not ok then
        return nil
    end

    return result, result2, result3
end

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end

    if value > maxValue then
        return maxValue
    end

    return value
end

local function color(r, g, b, a)
    if type(Color) == "function" then
        return Color(r, g, b, a)
    end

    return { r = r, g = g, b = b, a = a }
end

local function colorComponent(source, key, fallback)
    return source and source[key] or fallback
end

local function withAlpha(source, alpha)
    return color(
        colorComponent(source, "r", 255),
        colorComponent(source, "g", 255),
        colorComponent(source, "b", 255),
        alpha
    )
end

local function brighten(source, factor, alpha)
    local r = math.min(255, math.floor(colorComponent(source, "r", 255) * factor))
    local g = math.min(255, math.floor(colorComponent(source, "g", 255) * factor))
    local b = math.min(255, math.floor(colorComponent(source, "b", 255) * factor))
    return color(r, g, b, alpha or colorComponent(source, "a", 255))
end

local function widgetValue(widget, defaultValue)
    if widget and type(widget.Get) == "function" then
        local value = safeCall(widget.Get, widget)
        if value ~= nil then
            return value
        end
    end

    return defaultValue
end

local function widgetNumber(widget, defaultValue, minValue, maxValue)
    local value = widgetValue(widget, defaultValue)
    if type(value) ~= "number" then
        return defaultValue
    end

    if minValue and maxValue then
        return clamp(value, minValue, maxValue)
    end

    return value
end

local function createWidget(group, methodName, ...)
    if group and type(group[methodName]) == "function" then
        return safeCall(group[methodName], group, ...)
    end

    return nil
end

local function setupMenu()
    if ui.initialized or type(Menu) ~= "table" or type(Menu.Create) ~= "function" then
        return
    end

    local group = safeCall(Menu.Create, MENU_FIRST_TAB, MENU_SECTION, MENU_SECOND_TAB, MENU_THIRD_TAB, MENU_GROUP)
    if not group then
        return
    end

    ui.initialized = true
    ui.enabled = createWidget(group, "Switch", "Enable Illuminate Visualizer", true)
    ui.showLocal = createWidget(group, "Switch", "Show Local KoTL", true)
    ui.showAlly = createWidget(group, "Switch", "Show Ally KoTL", true)
    ui.showEnemy = createWidget(group, "Switch", "Show Enemy KoTL", true)
    ui.preferExact = createWidget(group, "Switch", "Prefer exact cast data", true)
    ui.useFallback = createWidget(group, "Switch", "Use fallback values", true)
    ui.showEstimateLabel = createWidget(group, "Switch", "Show estimate label", true)
    ui.showOuterCorridor = createWidget(group, "Switch", "Show outer corridor", true)
    ui.showAnimatedFill = createWidget(group, "Switch", "Show animated fill", true)
    ui.showProgressText = createWidget(group, "Switch", "Show charge progress text", true)
    ui.progressFillWidth = createWidget(group, "Slider", "Progress fill width multiplier", 0.5, 1.0, 1.0, "%.2f")
    ui.showMaxRangeEndCap = createWidget(group, "Switch", "Show max range end cap", true)
    ui.showMaxRangeLabel = createWidget(group, "Switch", "Show max range marker label", false)
    ui.showCenterLine = createWidget(group, "Switch", "Show center line", true)
    ui.showSideLines = createWidget(group, "Switch", "Show side lines", true)
    ui.showFill = createWidget(group, "Switch", "Show filled corridor if supported", true)
    ui.showFrontEdge = createWidget(group, "Switch", "Front edge enabled", true)
    ui.showEndpoint = createWidget(group, "Switch", "Show endpoint marker", true)
    ui.thickness = createWidget(group, "Slider", "Line thickness", 1.0, 6.0, 2.0, "%.1f")
    ui.fillOpacity = createWidget(group, "Slider", "Progress fill opacity", 20, 180, 95, "%d")
    ui.frontEdgeThickness = createWidget(group, "Slider", "Front edge thickness", 1.0, 8.0, 2.0, "%.1f")
    ui.maxRangeEndCapThickness = createWidget(group, "Slider", "Max range end cap thickness", 1.0, 10.0, 3.0, "%.1f")
    ui.progressBrightnessScaling = createWidget(group, "Slider", "Progress brightness scaling", 0.0, 0.75, 0.28, "%.2f")
    ui.progressOpacityScaling = createWidget(group, "Slider", "Progress opacity scaling", 0.0, 0.75, 0.25, "%.2f")
    ui.zOffset = createWidget(group, "Slider", "Geometry z offset", 0.0, 160.0, DEFAULT_GEOMETRY_Z_OFFSET, "%.0f")
    ui.outerCorridorColor = createWidget(group, "ColorPicker", "Local outer corridor color", color(255, 92, 42, 230))
    ui.progressFillColor = createWidget(group, "ColorPicker", "Local progress fill color", color(255, 184, 48, 220))
    ui.frontEdgeColor = createWidget(group, "ColorPicker", "Local front edge color", color(255, 242, 150, 255))
    ui.allyOuterCorridorColor = createWidget(group, "ColorPicker", "Ally outer corridor color", color(65, 220, 120, 220))
    ui.allyProgressFillColor = createWidget(group, "ColorPicker", "Ally progress fill color", color(95, 255, 170, 225))
    ui.allyFrontEdgeColor = createWidget(group, "ColorPicker", "Ally front edge color", color(190, 255, 215, 255))
    ui.enemyOuterCorridorColor = createWidget(group, "ColorPicker", "Enemy outer corridor color", color(255, 74, 42, 235))
    ui.enemyProgressFillColor = createWidget(group, "ColorPicker", "Enemy progress fill color", color(255, 168, 42, 225))
    ui.enemyFrontEdgeColor = createWidget(group, "ColorPicker", "Enemy front edge color", color(255, 238, 126, 255))
    ui.maxRangeEndCapColor = createWidget(group, "ColorPicker", "Max range end cap color", color(255, 214, 104, 255))
    ui.localColor = createWidget(group, "ColorPicker", "Local color", color(120, 210, 255, 230))
    ui.allyColor = createWidget(group, "ColorPicker", "Ally color", color(100, 255, 150, 220))
    ui.enemyColor = createWidget(group, "ColorPicker", "Enemy color", color(255, 75, 75, 245))
end

local function entityIndex(entity)
    return safeCall(Entity.GetIndex, entity) or tostring(entity)
end

local function isValidKotl(hero)
    if not hero then
        return false
    end

    if safeCall(Entity.IsAlive, hero) == false then
        return false
    end

    if safeCall(Entity.IsDormant, hero) == true then
        return false
    end

    if safeCall(NPC.IsVisible, hero) == false then
        return false
    end

    if safeCall(NPC.IsIllusion, hero) == true then
        return false
    end

    return safeCall(NPC.GetUnitName, hero) == KOTL_UNIT_NAME
end

local function getTeamKind(hero, localHero)
    if localHero and hero == localHero then
        return "local"
    end

    if localHero and safeCall(Entity.IsSameTeam, hero, localHero) then
        return "ally"
    end

    return "enemy"
end

local function shouldDrawKind(kind)
    if kind == "local" then
        return widgetValue(ui.showLocal, true)
    end

    if kind == "ally" then
        return widgetValue(ui.showAlly, true)
    end

    return widgetValue(ui.showEnemy, true)
end

local function getKindColor(kind)
    if kind == "local" then
        return widgetValue(ui.localColor, color(120, 210, 255, 230))
    end

    if kind == "ally" then
        return widgetValue(ui.allyColor, color(100, 255, 150, 220))
    end

    return widgetValue(ui.enemyColor, color(255, 75, 75, 245))
end

local function getOuterCorridorColor(kind)
    if kind == "ally" then
        return widgetValue(ui.allyOuterCorridorColor, color(65, 220, 120, 220))
    end

    if kind == "enemy" then
        return widgetValue(ui.enemyOuterCorridorColor, color(255, 74, 42, 235))
    end

    return widgetValue(ui.outerCorridorColor, color(255, 92, 42, 230))
end

local function getProgressFillColor(kind)
    if kind == "ally" then
        return widgetValue(ui.allyProgressFillColor, color(95, 255, 170, 225))
    end

    if kind == "enemy" then
        return widgetValue(ui.enemyProgressFillColor, color(255, 168, 42, 225))
    end

    return widgetValue(ui.progressFillColor, color(255, 184, 48, 220))
end

local function getFrontEdgeColor(kind)
    if kind == "ally" then
        return widgetValue(ui.allyFrontEdgeColor, color(190, 255, 215, 255))
    end

    if kind == "enemy" then
        return widgetValue(ui.enemyFrontEdgeColor, color(255, 238, 126, 255))
    end

    return widgetValue(ui.frontEdgeColor, color(255, 242, 150, 255))
end

local function getMaxRangeEndCapColor(kind)
    if kind == "ally" then
        return widgetValue(ui.allyFrontEdgeColor, color(190, 255, 215, 255))
    end

    return widgetValue(ui.maxRangeEndCapColor, color(255, 214, 104, 255))
end

local function isPositiveNumber(value)
    return type(value) == "number" and value > 0
end

local function getSpecial(ability, names)
    if not ability then
        return nil
    end

    for _, name in ipairs(names) do
        local value = safeCall(Ability.GetLevelSpecialValueFor, ability, name, -1)
        if isPositiveNumber(value) then
            return value
        end

        value = safeCall(Ability.GetLevelSpecialValueFor, ability, name)
        if isPositiveNumber(value) then
            return value
        end
    end

    return nil
end

local function getIlluminateValues(ability)
    local estimated = false

    local travelRange = getSpecial(ability, { "range", "travel_distance", "distance", "max_distance" })
    if not travelRange then
        local castRange = safeCall(Ability.GetCastRange, ability)
        if isPositiveNumber(castRange) and castRange > ILLUMINATE_CAST_RANGE_BUFFER then
            travelRange = castRange - ILLUMINATE_CAST_RANGE_BUFFER
            estimated = true
        end
    end

    local radius = getSpecial(ability, { "width", "radius", "hit_radius", "end_radius" })
    local maxChannelTime = getSpecial(ability, { "max_channel_time", "channel_time", "max_channel_duration", "duration" })

    if not travelRange or not radius or not maxChannelTime then
        if not widgetValue(ui.useFallback, true) then
            return nil
        end

        estimated = true
        travelRange = travelRange or FALLBACK_TRAVEL_RANGE
        radius = radius or FALLBACK_RADIUS
        maxChannelTime = maxChannelTime or FALLBACK_MAX_CHANNEL_TIME
    end

    return {
        range = travelRange,
        travelRange = travelRange,
        maxReach = travelRange + radius,
        radius = radius,
        maxChannelTime = maxChannelTime,
        estimated = estimated,
    }
end

local function getAbilityName(ability)
    return safeCall(Ability.GetName, ability)
end

local function isIlluminateAbility(ability)
    return ability and ILLUMINATE_ABILITY_NAME_SET[getAbilityName(ability)] == true
end

local function getIlluminateModifier(hero)
    if not hero then
        return nil
    end

    for _, modifierName in ipairs(ILLUMINATE_MODIFIER_NAMES) do
        local modifier = safeCall(NPC.GetModifier, hero, modifierName)
        if modifier then
            return modifier, modifierName
        end

        if safeCall(NPC.HasModifier, hero, modifierName) == true then
            return true, modifierName
        end
    end

    if type(NPC.HasAnyModifier) == "function" and safeCall(NPC.HasAnyModifier, hero, ILLUMINATE_MODIFIER_NAMES) == true then
        return true, nil
    end

    return nil
end

local function validKotlOrOwner(npc)
    if isValidKotl(npc) then
        return npc
    end

    local owner = safeCall(NPC.GetOwnerNPC, npc)
    if isValidKotl(owner) then
        return owner
    end

    return nil
end

local function distance2DSqr(a, b)
    if not a or not b then
        return math.huge
    end

    local dx = (a.x or 0) - (b.x or 0)
    local dy = (a.y or 0) - (b.y or 0)
    return dx * dx + dy * dy
end

local function findNearbyKotlOwner(caster)
    local casterOrigin = safeCall(Entity.GetAbsOrigin, caster)
    local heroes = safeCall(Heroes.GetAll)
    if not casterOrigin or not heroes then
        return nil
    end

    local bestHero = nil
    local bestDistance = 3500 * 3500

    for _, hero in pairs(heroes) do
        if isValidKotl(hero) and safeCall(Entity.IsSameTeam, caster, hero) ~= false then
            local distance = distance2DSqr(casterOrigin, safeCall(Entity.GetAbsOrigin, hero))
            if distance < bestDistance then
                bestDistance = distance
                bestHero = hero
            end
        end
    end

    return bestHero
end

local function getKotlOwnerForCaster(caster, ability)
    local owner = validKotlOrOwner(caster)
    if owner then
        return owner
    end

    local abilityOwner = safeCall(Ability.GetOwner, ability)
    owner = validKotlOrOwner(abilityOwner)
    if owner then
        return owner
    end

    local modifier = getIlluminateModifier(caster)
    if modifier and modifier ~= true then
        owner = validKotlOrOwner(safeCall(Modifier and Modifier.GetCaster, modifier))
        if owner then
            return owner
        end

        owner = validKotlOrOwner(safeCall(Modifier and Modifier.GetParent, modifier))
        if owner then
            return owner
        end
    end

    return findNearbyKotlOwner(caster)
end

local function addIlluminateAbility(abilities, seen, ability)
    if not isIlluminateAbility(ability) then
        return
    end

    local key = tostring(ability)
    if seen[key] then
        return
    end

    seen[key] = true
    abilities[#abilities + 1] = ability
end

local function getIlluminateAbilities(hero)
    local abilities = {}
    local seen = {}

    addIlluminateAbility(abilities, seen, safeCall(NPC.GetChannellingAbility, hero))

    local modifier = getIlluminateModifier(hero)
    if modifier and modifier ~= true then
        addIlluminateAbility(abilities, seen, safeCall(Modifier and Modifier.GetAbility, modifier))
    end

    for _, abilityName in ipairs(ILLUMINATE_ABILITY_NAMES) do
        addIlluminateAbility(abilities, seen, safeCall(NPC.GetAbility, hero, abilityName))
    end

    for i = 0, 23 do
        addIlluminateAbility(abilities, seen, safeCall(NPC.GetAbilityByIndex, hero, i))
    end

    return abilities
end

local function getActiveIlluminateAbility(hero)
    local channeling = safeCall(NPC.GetChannellingAbility, hero)
    if isIlluminateAbility(channeling) then
        return channeling, "channeling"
    end

    local abilities = getIlluminateAbilities(hero)
    for _, ability in ipairs(abilities) do
        if safeCall(Ability.IsChannelling, ability) == true then
            return ability, "channeling"
        end
    end

    for _, ability in ipairs(abilities) do
        if safeCall(Ability.IsInAbilityPhase, ability) == true then
            return ability, "phase"
        end
    end

    local modifier = getIlluminateModifier(hero)
    if modifier then
        if modifier ~= true then
            local modifierAbility = safeCall(Modifier and Modifier.GetAbility, modifier)
            if isIlluminateAbility(modifierAbility) then
                return modifierAbility, "modifier"
            end
        end

        return abilities[1], "modifier"
    end

    return nil, nil
end

local function getIlluminateAbility(hero)
    local activeAbility = getActiveIlluminateAbility(hero)
    if activeAbility then
        return activeAbility
    end

    local abilities = getIlluminateAbilities(hero)
    for _, ability in ipairs(abilities) do
        if safeCall(Ability.GetLevel, ability) ~= 0 then
            return ability
        end
    end

    return abilities[1]
end

local function isIlluminateChanneling(hero, ability)
    local activeAbility, source = getActiveIlluminateAbility(hero)
    if source == "channeling" or source == "modifier" then
        return true
    end

    if ability and safeCall(Ability.IsChannelling, ability) == true then
        return true
    end

    return activeAbility == ability and source == "channeling"
end

local function isIlluminateActive(hero, ability)
    local activeAbility, source = getActiveIlluminateAbility(hero)
    if activeAbility or source == "modifier" then
        return true
    end

    if safeCall(Ability.IsInAbilityPhase, ability) == true then
        return true
    end

    return isIlluminateChanneling(hero, ability)
end

local function normalized2D(direction)
    if not direction then
        return nil
    end

    local x = direction.x or 0
    local y = direction.y or 0
    local lengthSqr = x * x + y * y
    if lengthSqr <= MIN_DIRECTION_LENGTH_SQR then
        return nil
    end

    local length = math.sqrt(lengthSqr)
    return Vector(x / length, y / length, 0)
end

local function directionFromHeroFacing(hero)
    local rotation = safeCall(Entity.GetRotation, hero)
    if rotation and type(rotation.GetForward) == "function" then
        return normalized2D(rotation:GetForward())
    end

    local origin = safeCall(Entity.GetAbsOrigin, hero)
    local forward = safeCall(Entity.GetForwardPosition, hero, 100)
    if origin and forward and type(origin.DirectionTo) == "function" then
        return normalized2D(origin:DirectionTo(forward))
    end

    return nil
end

local function directionFromCastPosition(hero, pos)
    local origin = safeCall(Entity.GetAbsOrigin, hero)
    if not origin or not pos or type(origin.DirectionTo) ~= "function" then
        return nil
    end

    return normalized2D(origin:DirectionTo(pos))
end

local function getOrderField(order, names)
    for _, name in ipairs(names) do
        local value = order[name]
        if value ~= nil then
            return value
        end
    end

    return nil
end

local function orderAbilityName(order, ability)
    if ability then
        local name = safeCall(Ability.GetName, ability)
        if name then
            return name
        end
    end

    return getOrderField(order, { "ability_name", "[m]ability_name", "AbilityName" })
end

local function rememberExactOrder(order)
    if not order or not widgetValue(ui.preferExact, true) then
        return
    end

    local orderType = getOrderField(order, { "order", "type", "order_type", "OrderType" })
    local castPositionOrder = Enum and Enum.UnitOrder and Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION
    if castPositionOrder and orderType and orderType ~= castPositionOrder then
        return
    end

    local ability = getOrderField(order, { "ability", "Ability" })
    local abilityName = orderAbilityName(order, ability)
    if not ILLUMINATE_ABILITY_NAME_SET[abilityName] then
        return
    end

    local hero = getOrderField(order, { "npc", "issuer_npc", "unit", "source", "hero" })
    if type(hero) == "table" then
        hero = hero[1]
    end

    if not isValidKotl(hero) then
        return
    end

    local pos = getOrderField(order, { "pos", "position", "target_position", "cast_position", "targetPos" })
    local direction = directionFromCastPosition(hero, pos)
    if not direction then
        return
    end

    state[entityIndex(hero)] = {
        active = false,
        exact = true,
        estimatedDirection = false,
        direction = direction,
        orderPosition = pos,
        pending = true,
        abilityName = abilityName,
        seenActive = false,
        seenChanneling = false,
        progress = 0,
    }
end

local function startChannelProgress(entry, ability, values)
    if entry.channelStartClock then
        return
    end

    entry.abilityName = getAbilityName(ability) or entry.abilityName
    entry.channelStartClock = os.clock()
    entry.maxChannelTime = values and values.maxChannelTime or FALLBACK_MAX_CHANNEL_TIME
    entry.channelStartGameTime = safeCall(Ability.GetChannelStartTime, ability)
    entry.progress = 0
end

local function updateProgress(entry, isChanneling)
    if not isChanneling or not entry.channelStartClock then
        entry.progress = 0
        return
    end

    local maxChannelTime = entry.maxChannelTime or FALLBACK_MAX_CHANNEL_TIME
    if maxChannelTime <= 0 then
        entry.progress = 1
        return
    end

    entry.progress = clamp((os.clock() - entry.channelStartClock) / maxChannelTime, 0, 1)
end

local function updateState(hero, ability, values)
    local id = entityIndex(hero)
    local entry = state[id]
    local abilityName = getAbilityName(ability)
    local active = isIlluminateActive(hero, ability)
    local channeling = isIlluminateChanneling(hero, ability)

    if not active then
        if entry and entry.pending and not entry.seenActive then
            return nil
        end

        state[id] = nil
        return nil
    end

    if entry and entry.abilityName and abilityName and entry.abilityName ~= abilityName then
        state[id] = nil
        entry = nil
    end

    if entry and entry.direction then
        entry.active = true
        entry.pending = false
        entry.abilityName = abilityName or entry.abilityName
        entry.seenActive = true

        if channeling then
            entry.seenChanneling = true
            startChannelProgress(entry, ability, values)
        end

        updateProgress(entry, channeling)
        return entry
    end

    local direction = directionFromHeroFacing(hero)
    if not direction then
        return nil
    end

    entry = {
        active = true,
        exact = false,
        estimatedDirection = true,
        direction = direction,
        abilityName = abilityName,
        seenActive = true,
        seenChanneling = false,
        progress = 0,
    }

    if channeling then
        entry.seenChanneling = true
        startChannelProgress(entry, ability, values)
    end

    updateProgress(entry, channeling)
    state[id] = entry

    return entry
end

local function addScaled(a, b, scale)
    return Vector(a.x + b.x * scale, a.y + b.y * scale, (a.z or 0) + (b.z or 0) * scale)
end

local function withZOffset(pos, offset)
    if not offset or offset == 0 then
        return pos
    end

    return Vector(pos.x, pos.y, (pos.z or 0) + offset)
end

local function isFinite(value)
    return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function vec2ToPoint(vec, visible)
    if not vec then
        return nil
    end

    local x = vec.x
    local y = vec.y

    if not isFinite(x) and type(vec.GetX) == "function" then
        x = safeCall(vec.GetX, vec)
    end

    if not isFinite(y) and type(vec.GetY) == "function" then
        y = safeCall(vec.GetY, vec)
    end

    if not isFinite(x) or not isFinite(y) then
        return nil
    end

    return { x = x, y = y, visible = visible == true }
end

local function pointToVec2(point)
    return Vec2(point.x, point.y)
end

local function projectWorld(pos)
    if Render and type(Render.WorldToScreen) == "function" then
        local screen, visible = safeCall(Render.WorldToScreen, pos)
        local point = vec2ToPoint(screen, visible)
        if point then
            return point
        end
    end

    if Renderer and type(Renderer.WorldToScreen) == "function" then
        local x, y, visible = safeCall(Renderer.WorldToScreen, pos)
        if isFinite(x) and isFinite(y) then
            return { x = x, y = y, visible = visible == true }
        end
    end

    if pos and type(pos.ToScreen) == "function" then
        local screen, visible = safeCall(pos.ToScreen, pos)
        return vec2ToPoint(screen, visible)
    end

    return nil
end

local function getViewport()
    if Render and type(Render.ScreenSize) == "function" then
        local size = safeCall(Render.ScreenSize)
        if size and isFinite(size.x) and isFinite(size.y) and size.x > 0 and size.y > 0 then
            return { minX = 0, minY = 0, maxX = size.x, maxY = size.y }
        end
    end

    if Renderer and type(Renderer.GetScreenSize) == "function" then
        local width, height = safeCall(Renderer.GetScreenSize)
        if isFinite(width) and isFinite(height) and width > 0 and height > 0 then
            return { minX = 0, minY = 0, maxX = width, maxY = height }
        end
    end

    return nil
end

local function pointInViewport(point, viewport)
    if not point or not viewport then
        return false
    end

    return point.x >= viewport.minX and point.x <= viewport.maxX
        and point.y >= viewport.minY and point.y <= viewport.maxY
end

local function clipLineToViewport(a, b, viewport)
    local x0, y0 = a.x, a.y
    local x1, y1 = b.x, b.y
    local dx, dy = x1 - x0, y1 - y0
    local u1, u2 = 0, 1
    local p = { -dx, dx, -dy, dy }
    local q = { x0 - viewport.minX, viewport.maxX - x0, y0 - viewport.minY, viewport.maxY - y0 }

    for i = 1, 4 do
        if p[i] == 0 then
            if q[i] < 0 then
                return nil, nil
            end
        else
            local r = q[i] / p[i]
            if p[i] < 0 then
                if r > u2 then
                    return nil, nil
                end

                if r > u1 then
                    u1 = r
                end
            else
                if r < u1 then
                    return nil, nil
                end

                if r < u2 then
                    u2 = r
                end
            end
        end
    end

    return {
        x = x0 + u1 * dx,
        y = y0 + u1 * dy,
        visible = true,
    }, {
        x = x0 + u2 * dx,
        y = y0 + u2 * dy,
        visible = true,
    }
end

local function polygonIntersection(a, b, viewport, edge)
    local dx, dy = b.x - a.x, b.y - a.y
    local t = 0

    if edge == "left" then
        if dx == 0 then return { x = a.x, y = a.y, visible = true } end
        t = (viewport.minX - a.x) / dx
    elseif edge == "right" then
        if dx == 0 then return { x = a.x, y = a.y, visible = true } end
        t = (viewport.maxX - a.x) / dx
    elseif edge == "top" then
        if dy == 0 then return { x = a.x, y = a.y, visible = true } end
        t = (viewport.minY - a.y) / dy
    else
        if dy == 0 then return { x = a.x, y = a.y, visible = true } end
        t = (viewport.maxY - a.y) / dy
    end

    return { x = a.x + dx * t, y = a.y + dy * t, visible = true }
end

local function polygonInside(point, viewport, edge)
    if edge == "left" then
        return point.x >= viewport.minX
    elseif edge == "right" then
        return point.x <= viewport.maxX
    elseif edge == "top" then
        return point.y >= viewport.minY
    end

    return point.y <= viewport.maxY
end

local function clipPolygonToViewport(points, viewport)
    local output = points
    local edges = { "left", "right", "top", "bottom" }

    for _, edge in ipairs(edges) do
        local input = output
        output = {}

        if #input == 0 then
            return nil
        end

        local previous = input[#input]
        local previousInside = polygonInside(previous, viewport, edge)

        for _, current in ipairs(input) do
            local currentInside = polygonInside(current, viewport, edge)

            if currentInside then
                if not previousInside then
                    output[#output + 1] = polygonIntersection(previous, current, viewport, edge)
                end

                output[#output + 1] = current
            elseif previousInside then
                output[#output + 1] = polygonIntersection(previous, current, viewport, edge)
            end

            previous = current
            previousInside = currentInside
        end
    end

    if #output < 3 then
        return nil
    end

    return output
end

local function drawScreenLine(a, b, drawColor, thickness)
    if Render and type(Render.Line) == "function" then
        Render.Line(pointToVec2(a), pointToVec2(b), drawColor, thickness)
        return
    end

    if Renderer and type(Renderer.SetDrawColor) == "function" and type(Renderer.DrawLine) == "function" then
        Renderer.SetDrawColor(colorComponent(drawColor, "r", 255), colorComponent(drawColor, "g", 255), colorComponent(drawColor, "b", 255), colorComponent(drawColor, "a", 255))
        Renderer.DrawLine(math.floor(a.x + 0.5), math.floor(a.y + 0.5), math.floor(b.x + 0.5), math.floor(b.y + 0.5))
    end
end

local function drawLine(a, b, drawColor, thickness)
    local sa = projectWorld(a)
    local sb = projectWorld(b)
    if not sa or not sb then
        return
    end

    local viewport = getViewport()
    if viewport then
        local clippedA, clippedB = clipLineToViewport(sa, sb, viewport)
        if clippedA and clippedB then
            drawScreenLine(clippedA, clippedB, drawColor, thickness)
        end
    elseif sa.visible or sb.visible then
        drawScreenLine(sa, sb, drawColor, thickness)
    end
end

local function drawScreenPolygon(points, drawColor)
    if Render and type(Render.FilledTriangle) == "function" then
        for i = 2, #points - 1 do
            Render.FilledTriangle({
                pointToVec2(points[1]),
                pointToVec2(points[i]),
                pointToVec2(points[i + 1]),
            }, drawColor)
        end

        return
    end

    if Renderer and type(Renderer.SetDrawColor) == "function" then
        Renderer.SetDrawColor(colorComponent(drawColor, "r", 255), colorComponent(drawColor, "g", 255), colorComponent(drawColor, "b", 255), colorComponent(drawColor, "a", 255))

        local vecPoints = {}
        for i, point in ipairs(points) do
            vecPoints[i] = pointToVec2(point)
        end

        if type(Renderer.DrawPolyLineFilled) == "function" then
            Renderer.DrawPolyLineFilled(vecPoints)
        elseif type(Renderer.DrawFilledTriangle) == "function" then
            for i = 2, #vecPoints - 1 do
                Renderer.DrawFilledTriangle({ vecPoints[1], vecPoints[i], vecPoints[i + 1] })
            end
        end
    end
end

local function drawFill(quad, drawColor)
    local canDraw = (Render and type(Render.FilledTriangle) == "function")
        or (Renderer and (type(Renderer.DrawPolyLineFilled) == "function" or type(Renderer.DrawFilledTriangle) == "function"))
    if not canDraw then
        return
    end

    local points = {}
    local anyVisible = false

    for i, point in ipairs(quad) do
        local screenPoint = projectWorld(point)
        if not screenPoint then
            return
        end

        anyVisible = anyVisible or screenPoint.visible
        points[i] = screenPoint
    end

    local viewport = getViewport()
    if viewport then
        points = clipPolygonToViewport(points, viewport)
    elseif not anyVisible then
        points = nil
    end

    if points and #points >= 3 then
        drawScreenPolygon(points, drawColor)
    end
end

local function drawEndpoint(pos, drawColor, thickness)
    local point = projectWorld(pos)
    local viewport = getViewport()
    if not point or not (point.visible or pointInViewport(point, viewport)) then
        return
    end

    local screen = pointToVec2(point)
    if Render and type(Render.FilledCircle) == "function" then
        Render.FilledCircle(screen, math.max(4, thickness * 2.5), drawColor)
    elseif Renderer and type(Renderer.SetDrawColor) == "function" and type(Renderer.DrawFilledCircle) == "function" then
        Renderer.SetDrawColor(colorComponent(drawColor, "r", 255), colorComponent(drawColor, "g", 255), colorComponent(drawColor, "b", 255), colorComponent(drawColor, "a", 255))
        Renderer.DrawFilledCircle(screen.x, screen.y, math.max(4, thickness * 2.5))
    end
end

local function ensureFont()
    if font or not (Render and type(Render.LoadFont) == "function") then
        return font
    end

    local fontFlag = 0
    if Enum and Enum.FontCreate and Enum.FontCreate.FONTFLAG_ANTIALIAS then
        fontFlag = Enum.FontCreate.FONTFLAG_ANTIALIAS
    end

    font = Render.LoadFont("MuseoSansEx", fontFlag, 500)
    return font
end

local function drawLabel(pos, text, drawColor)
    if not (Render and type(Render.Text) == "function") or not ensureFont() then
        return
    end

    local point = projectWorld(pos)
    local viewport = getViewport()
    if point and (point.visible or pointInViewport(point, viewport)) then
        Render.Text(font, 13, text, pointToVec2(point), drawColor)
    end
end

local function corridorPoints(startPos, direction, perpendicular, length, radius)
    local front = addScaled(startPos, direction, length)
    return {
        leftStart = addScaled(startPos, perpendicular, radius),
        rightStart = addScaled(startPos, perpendicular, -radius),
        leftEnd = addScaled(front, perpendicular, radius),
        rightEnd = addScaled(front, perpendicular, -radius),
        front = front,
    }
end

local function roundedEndCapPoints(center, direction, perpendicular, radius)
    local points = {}

    for i = 0, END_CAP_SEGMENTS do
        local t = i / END_CAP_SEGMENTS
        local angle = math.pi * t
        local sideScale = math.cos(angle) * radius
        local forwardScale = math.sin(angle) * radius
        local point = addScaled(addScaled(center, perpendicular, sideScale), direction, forwardScale)
        points[#points + 1] = point
    end

    return points
end

local function drawPolyline(points, drawColor, thickness)
    for i = 1, #points - 1 do
        drawLine(points[i], points[i + 1], drawColor, thickness)
    end
end

local function drawProgressText(front, progress, elapsed, maxTime, drawColor)
    if not widgetValue(ui.showProgressText, true) then
        return
    end

    local percent = math.floor(progress * 100 + 0.5)
    local text = string.format("%d%%  %.1fs / %.1fs", percent, math.min(elapsed, maxTime), maxTime)
    drawLabel(front, text, brighten(drawColor, 1.25, 235))
end

local function drawTravelEndCap(fullShape, capColor, thickness, kind)
    if not widgetValue(ui.showMaxRangeEndCap, true) then
        return
    end

    local capThickness = widgetNumber(ui.maxRangeEndCapThickness, 3.0, 1.0, 10.0)
    if kind == "enemy" then
        capThickness = capThickness + 0.75
    end

    local brightCapColor = brighten(capColor, kind == "enemy" and 1.12 or 1.0, 255)
    local glowColor = withAlpha(brightCapColor, kind == "enemy" and 150 or 110)
    drawLine(fullShape.leftEnd, fullShape.rightEnd, glowColor, thickness + capThickness + 2.0)
    drawLine(fullShape.leftEnd, fullShape.rightEnd, brightCapColor, capThickness)
end

local function drawRoundedHitEndCap(fullShape, direction, perpendicular, radius, capColor, thickness, kind, progress)
    if not widgetValue(ui.showMaxRangeEndCap, true) then
        return
    end

    local capPoints = roundedEndCapPoints(fullShape.front, direction, perpendicular, radius)
    local capThickness = widgetNumber(ui.maxRangeEndCapThickness, 3.0, 1.0, 10.0)
    if kind == "enemy" then
        capThickness = capThickness + 0.75
    end

    local capProgress = clamp(progress or 0, 0, 1)
    local fullyCharged = capProgress >= 0.98
    local brightCapColor = brighten(capColor, fullyCharged and 1.22 or 1.0, 255)
    local fillAlpha = fullyCharged and (kind == "enemy" and 62 or 46) or (kind == "enemy" and 38 or 28)
    drawFill(capPoints, withAlpha(capColor, fillAlpha))

    local glowColor = withAlpha(brightCapColor, fullyCharged and 150 or 95)
    drawPolyline(capPoints, glowColor, math.max(1.0, thickness + capThickness * 0.35))
    drawPolyline(capPoints, brightCapColor, math.max(1.0, capThickness * 0.65))

    local cornerLength = 72
    local cornerColor = withAlpha(brightCapColor, kind == "enemy" and 230 or 205)
    local leftCorner = addScaled(fullShape.leftEnd, direction, -cornerLength)
    local rightCorner = addScaled(fullShape.rightEnd, direction, -cornerLength)
    drawLine(fullShape.leftEnd, leftCorner, cornerColor, math.max(1.0, capThickness * 0.65))
    drawLine(fullShape.rightEnd, rightCorner, cornerColor, math.max(1.0, capThickness * 0.65))

    if widgetValue(ui.showMaxRangeLabel, false) then
        drawLabel(addScaled(fullShape.front, direction, radius + 44), "Max reach", withAlpha(brightCapColor, 230))
    end
end

local function drawAnimatedFill(drawOrigin, direction, perpendicular, values, entry, progressColor, frontEdgeColor, thickness, kind)
    if not widgetValue(ui.showAnimatedFill, true) then
        return
    end

    local progress = clamp(entry.progress or 0, 0, 1)
    local maxTime = entry.maxChannelTime or values.maxChannelTime or FALLBACK_MAX_CHANNEL_TIME
    local elapsed = entry.channelStartClock and (os.clock() - entry.channelStartClock) or 0

    if progress <= 0 then
        drawProgressText(drawOrigin, 0, 0, maxTime, frontEdgeColor)
        return
    end

    local widthMultiplier = widgetNumber(ui.progressFillWidth, 1.0, 0.5, 1.0)
    local progressRadius = values.radius * widthMultiplier
    local progressLength = (values.travelRange or values.range) * progress
    local progressShape = corridorPoints(drawOrigin, direction, perpendicular, progressLength, progressRadius)
    local baseFillOpacity = widgetNumber(ui.fillOpacity, 95, 20, 180)
    local brightnessScaling = widgetNumber(ui.progressBrightnessScaling, 0.28, 0.0, 0.75)
    local opacityScaling = widgetNumber(ui.progressOpacityScaling, 0.25, 0.0, 0.75)
    local brightnessFactor = 1.0 + brightnessScaling * progress
    local opacityFactor = 1.0 + opacityScaling * progress

    if kind == "enemy" then
        brightnessFactor = brightnessFactor + 0.05
    end

    local fillOpacity = math.floor(clamp(baseFillOpacity * opacityFactor, 10, 210) + 0.5)
    local fillColor = withAlpha(brighten(progressColor, brightnessFactor, fillOpacity), fillOpacity)

    drawFill({
        progressShape.leftStart,
        progressShape.leftEnd,
        progressShape.rightEnd,
        progressShape.rightStart,
    }, fillColor)

    local sideColor = withAlpha(brighten(progressColor, brightnessFactor + 0.08, 230), math.floor(fillOpacity * 0.74))
    local sideThickness = math.max(1.0, thickness * 0.55)
    drawLine(progressShape.leftStart, progressShape.leftEnd, sideColor, sideThickness)
    drawLine(progressShape.rightStart, progressShape.rightEnd, sideColor, sideThickness)

    if widgetValue(ui.showFrontEdge, true) then
        local frontThickness = widgetNumber(ui.frontEdgeThickness, 2.0, 1.0, 8.0)
        local edgeBrightness = 1.0 + brightnessScaling * progress * 1.15
        if kind == "enemy" then
            edgeBrightness = edgeBrightness + 0.05
        end

        local edgeColor = brighten(frontEdgeColor, edgeBrightness, 255)
        local glowAlpha = math.floor(clamp((kind == "enemy" and 130 or 105) + 55 * progress, 80, 190) + 0.5)
        local glowColor = withAlpha(edgeColor, glowAlpha)
        drawLine(progressShape.leftEnd, progressShape.rightEnd, glowColor, thickness + frontThickness + 3.0)
        drawLine(progressShape.leftEnd, progressShape.rightEnd, edgeColor, frontThickness)
    end

    drawProgressText(progressShape.front, progress, elapsed, maxTime, frontEdgeColor)
end

local function drawIlluminate(hero, kind, ability, entry, values)
    local origin = safeCall(Entity.GetAbsOrigin, hero)
    if not origin or not entry or not entry.direction or not values then
        return
    end

    local direction = entry.direction
    local perpendicular = Vector(-(direction.y or 0), direction.x or 0, 0)
    local zOffset = widgetValue(ui.zOffset, DEFAULT_GEOMETRY_Z_OFFSET)
    local drawOrigin = withZOffset(origin, zOffset)
    local travelRange = values.travelRange or values.range
    local fullShape = corridorPoints(drawOrigin, direction, perpendicular, travelRange, values.radius)
    local maxReachPoint = addScaled(drawOrigin, direction, values.maxReach or (travelRange + values.radius))

    local roleColor = getKindColor(kind)
    local outerColor = getOuterCorridorColor(kind)
    local progressColor = getProgressFillColor(kind)
    local frontEdgeColor = getFrontEdgeColor(kind)
    local endCapColor = getMaxRangeEndCapColor(kind)
    local thickness = widgetValue(ui.thickness, 2.0)
    if kind == "enemy" then
        thickness = thickness + 1.0
    end

    if widgetValue(ui.showOuterCorridor, true) then
        if widgetValue(ui.showFill, true) then
            local fillAlpha = kind == "enemy" and 58 or 34
            drawFill({
                fullShape.leftStart,
                fullShape.leftEnd,
                fullShape.rightEnd,
                fullShape.rightStart,
            }, withAlpha(outerColor, fillAlpha))
        end

        if widgetValue(ui.showCenterLine, true) then
            drawLine(drawOrigin, fullShape.front, withAlpha(roleColor, kind == "enemy" and 210 or 170), thickness)
        end

        if widgetValue(ui.showSideLines, true) then
            drawLine(fullShape.leftStart, fullShape.leftEnd, withAlpha(outerColor, kind == "enemy" and 230 or 190), math.max(1.0, thickness - 0.5))
            drawLine(fullShape.rightStart, fullShape.rightEnd, withAlpha(outerColor, kind == "enemy" and 230 or 190), math.max(1.0, thickness - 0.5))
        end
    end

    drawAnimatedFill(drawOrigin, direction, perpendicular, values, entry, progressColor, frontEdgeColor, thickness, kind)
    drawTravelEndCap(fullShape, endCapColor, thickness, kind)
    drawRoundedHitEndCap(fullShape, direction, perpendicular, values.radius, endCapColor, thickness, kind, entry.progress)

    if widgetValue(ui.showEndpoint, true) then
        drawEndpoint(maxReachPoint, roleColor, thickness)
    end

    local estimated = values.estimated or entry.estimatedDirection or not entry.exact
    if estimated and widgetValue(ui.showEstimateLabel, true) then
        drawLabel(maxReachPoint, "Illuminate estimate", withAlpha(roleColor, 230))
    else
        drawLabel(maxReachPoint, "Illuminate", withAlpha(roleColor, 230))
    end
end

local function inheritPendingStateFromOwner(caster, owner)
    if not caster or not owner or caster == owner then
        return
    end

    local casterId = entityIndex(caster)
    if state[casterId] then
        return
    end

    local ownerId = entityIndex(owner)
    local ownerEntry = state[ownerId]
    if ownerEntry and ownerEntry.pending then
        state[casterId] = ownerEntry
        state[ownerId] = nil
    end
end

local function drawIlluminateForCaster(caster, owner, localHero, drawn, forcedAbility)
    if not caster or not owner then
        return
    end

    local kind = getTeamKind(owner, localHero)
    if not shouldDrawKind(kind) then
        return
    end

    local id = entityIndex(caster)
    if drawn and drawn[id] then
        return
    end

    local ability = forcedAbility or getIlluminateAbility(caster)
    if not ability then
        ability = getIlluminateAbility(owner)
    end

    local values = getIlluminateValues(ability)
    inheritPendingStateFromOwner(caster, owner)

    local entry = updateState(caster, ability, values)
    if entry and values then
        drawIlluminate(caster, kind, ability, entry, values)
        if drawn then
            drawn[id] = true
        end
    end
end

local function drawHeroIlluminate(localHero, drawn)
    local heroes = safeCall(Heroes.GetAll)
    if not heroes then
        return
    end

    for _, hero in pairs(heroes) do
        if isValidKotl(hero) then
            drawIlluminateForCaster(hero, hero, localHero, drawn)
        end
    end
end

local function isActiveIlluminateCaster(npc)
    if not npc then
        return false
    end

    local ability, source = getActiveIlluminateAbility(npc)
    return ability ~= nil or source == "modifier"
end

local function drawNpcIlluminateCasters(localHero, drawn)
    if type(NPCs) ~= "table" or type(NPCs.GetAll) ~= "function" then
        return
    end

    local npcs = safeCall(NPCs.GetAll)
    if not npcs then
        return
    end

    for _, npc in pairs(npcs) do
        local id = entityIndex(npc)
        if not (drawn and drawn[id]) and isActiveIlluminateCaster(npc) then
            local ability = getIlluminateAbility(npc)
            local owner = getKotlOwnerForCaster(npc, ability)
            if owner then
                drawIlluminateForCaster(npc, owner, localHero, drawn, ability)
            end
        end
    end
end

local function drawAbilityIlluminateCasters(localHero, drawn)
    if type(Abilities) ~= "table" or type(Abilities.GetAll) ~= "function" then
        return
    end

    local abilities = safeCall(Abilities.GetAll)
    if not abilities then
        return
    end

    for _, ability in pairs(abilities) do
        if isIlluminateAbility(ability)
            and (safeCall(Ability.IsChannelling, ability) == true or safeCall(Ability.IsInAbilityPhase, ability) == true)
        then
            local caster = safeCall(Ability.GetOwner, ability)
            local owner = getKotlOwnerForCaster(caster, ability)
            if owner then
                drawIlluminateForCaster(caster or owner, owner, localHero, drawn, ability)
            end
        end
    end
end

function IlluminateVisualizer.OnPrepareUnitOrders(order)
    setupMenu()
    rememberExactOrder(order)
    return true
end

function IlluminateVisualizer.OnDraw()
    setupMenu()

    if not widgetValue(ui.enabled, true) then
        return
    end

    local localHero = safeCall(Heroes.GetLocal)
    local drawn = {}
    drawHeroIlluminate(localHero, drawn)
    drawNpcIlluminateCasters(localHero, drawn)
    drawAbilityIlluminateCasters(localHero, drawn)
end

function IlluminateVisualizer.OnGameEnd()
    state = {}
end

return IlluminateVisualizer
