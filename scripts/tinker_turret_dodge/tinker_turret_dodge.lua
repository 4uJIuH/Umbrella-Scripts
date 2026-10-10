local localization = qLocalization.new({
    en = {
        ttd_group = "Turret Dodger",
        ttd_group_standalone = "Turret Dodger",
        ttd_enable = "Enable",
        ttd_enable_tip = "Places a turret against enemy\nBlinks, stuns and charges",
        ttd_blink_panel_key = "Dodge panel",
        ttd_blink_panel_key_tip = "Opens a panel where you pick\nwhich enemy spells to dodge",
        ttd_bind_name = "Tinker dodge panel",
        ttd_invis_safe = "Don't cast in invisibility",
        ttd_invis_safe_tip = "Turret is not placed\nwhile you are invisible",
        ttd_melee_attack = "Melee attack protection",
        ttd_melee_attack_tip = "Places a turret 190 units from Tinker\ntoward an enemy melee hero attacking you",
        ttd_melee_attack_minute = "Works from minute",
        ttd_melee_attack_minute_tip = "Melee attack protection starts\nfrom this game minute",
        ttd_panel_title = "Dodge",
    },
    ru = {
        ttd_group = "Доджер Турелями",
        ttd_group_standalone = "Доджер Турелями",
        ttd_enable = "Включить",
        ttd_enable_tip = "Ставит турель против Блинка,\nстанов и рывков врагов",
        ttd_blink_panel_key = "Панель доджа",
        ttd_blink_panel_key_tip = "Открывает панель, где выбираются\nспеллы врагов для доджа",
        ttd_bind_name = "Панель доджа Тинкера",
        ttd_invis_safe = "Не кастовать в инвизе",
        ttd_invis_safe_tip = "Турель не ставится,\nпока вы в невидимости",
        ttd_melee_attack = "Защита от атак мили-героев",
        ttd_melee_attack_tip = "Ставит турель в 190 единицах от Тинкера\nв сторону вражеского мили-героя, атакующего вас",
        ttd_melee_attack_minute = "Работает с минуты",
        ttd_melee_attack_minute_tip = "Защита от атак мили-героев начинает работать\nс указанной минуты игры",
        ttd_panel_title = "Додж",
    },
})

local Menu = localization.WrapLibrary(Menu)
local logger = Logger("TurretDodger")
local tab = Menu.Create("Scripts", "Scripts", "Tinker")
tab:Icon("\u{f0e7}")

local page = tab:Create("Settings")
local oldMain = page:Find("ttd_group_main")
local oldBehavior = page:Find("ttd_group_behavior")
local farmGroup = page:Find("menu_farm")
local existingGroup = page:Find("ttd_group")
local groupName = farmGroup and "ttd_group" or "ttd_group_standalone"
local group = page:Find(groupName)
local migrateGroupSettings = group == nil
if not group then
    group = farmGroup
        and page:Create(groupName, Enum.GroupSide.Right)
        or page:Create(groupName)
end

local function migrateValue(oldGroup, newWidget, name)
    local oldWidget = oldGroup and oldGroup:Find(name)
    if oldWidget then newWidget:Set(oldWidget:Get()) end
end

local enabled = group:Switch("ttd_enable", true, "\u{f011}")
enabled:ToolTip("ttd_enable_tip")
local blinkPanelKey = group:Bind(
    "ttd_blink_panel_key",
    Enum.ButtonCode.KEY_NONE,
    "\u{f11c}"
)
blinkPanelKey:ToolTip("ttd_blink_panel_key_tip")
blinkPanelKey:Properties(localization.Get("ttd_bind_name"))

local invisSafe = group:Switch("ttd_invis_safe", true, "\u{f070}")
invisSafe:ToolTip("ttd_invis_safe_tip")
local meleeAttackProtection = group:Switch(
    "ttd_melee_attack",
    true,
    "\u{f05b}"
)
meleeAttackProtection:ToolTip("ttd_melee_attack_tip")
local meleeAttackStartMinute = group:Slider(
    "ttd_melee_attack_minute",
    0,
    60,
    0,
    "%d"
)
meleeAttackStartMinute:ToolTip("ttd_melee_attack_minute_tip")

if migrateGroupSettings then
    local sourceGroup = existingGroup or oldMain
    migrateValue(sourceGroup, enabled, "ttd_enable")
    migrateValue(sourceGroup, blinkPanelKey, "ttd_blink_panel_key")
    migrateValue(existingGroup or oldBehavior, invisSafe, "ttd_invis_safe")
    migrateValue(existingGroup or oldBehavior, meleeAttackProtection, "ttd_melee_attack")
    migrateValue(existingGroup or oldBehavior, meleeAttackStartMinute, "ttd_melee_attack_minute")
end
if oldMain then oldMain:Visible(false) end
if oldBehavior then oldBehavior:Visible(false) end
if existingGroup and existingGroup ~= group and not farmGroup then
    existingGroup:Visible(false)
end

enabled:SetCallback(function(this)
    local on = this:Get()
    blinkPanelKey:Disabled(not on)
    invisSafe:Disabled(not on)
    meleeAttackProtection:Disabled(not on)
    meleeAttackStartMinute:Disabled(not on)
end, true)
local blinkPanelOpen = false
local PANEL_CONFIG = "tinker_turret_dodge"
local function easeOutCubic(t)
    local inverse = 1 - t
    return 1 - inverse * inverse * inverse
end

local panel = {
    anim = 0,
    progress = 0,
    drag = false,
    dragX = 0,
    dragY = 0,
    time = 0,
    shown = false,
    rows = {},
    scroll = 0,
    lastDrawErrorTime = -10000,
    rect = nil,
    pendingClick = false,
    fx = {},
    mouseDown = false,
}
local dodge = {
    off = {},
    abilities = {},
    enemyEntities = {},
    abilitiesTime = -100,
    images = {},
    phases = {},
}
local blinkPanelFont = Render.LoadFont(
    "Segoe UI",
    Enum.FontCreate.FONTFLAG_ANTIALIAS,
    Enum.FontWeight.SEMIBOLD
)
local blinkItemImage = Render.LoadImage("panorama/images/items/blink_png.vtex_c")

local TURRET_RADIUS = 600
local BLINK_DODGE_RADIUS = 650
local INTERRUPT_RADIUS = 200
local TURRET_DELAY = 0.5
local PREFIRE_LEAD = 0.12
local MOVEMENT_PREFIRE_LEAD = 0.35
local TECHIES_FLIGHT_DURATION = 0.5
local TECHIES_BLAST_RADIUS = 400
local SPECIAL_TURRET_OFFSET = 190
local DEFAULT_MOVE_SPEED = 550
local MAGNUS_SKEWER_SPEED = 904
local SPEED_SAMPLE_RADIUS = 1000
local NETHER_STRIKE_PUSH_DISTANCE = 162
local NETHER_STRIKE_DEFAULT_CAST_POINT = 0.1

local THREAT_NAMES = {
    item_blink = true,
    item_arcane_blink = true,
    item_swift_blink = true,
    item_overwhelming_blink = true,
    enigma_black_hole = true,
    magnataur_reverse_polarity = true,
    faceless_void_chronosphere = true,
    leshrac_split_earth = true,
    lina_light_strike_array = true,
    lion_impale = true,
    mars_spear = true,
    sven_storm_bolt = true,
    earthshaker_fissure = true,
    nyx_assassin_impale = true,
    slardar_slithereen_crush = true,
    dragon_knight_dragon_tail = true,
    chaos_knight_chaos_bolt = true,
    vengefulspirit_magic_missile = true,
    mirana_arrow = true,
    tiny_avalanche = true,
    shadow_shaman_hex = true,
    shadow_shaman_voodoo = true,
    shadow_shaman_shackles = true,
    bane_fiends_grip = true,
    witch_doctor_paralyzing_cask = true,
    beastmaster_primal_roar = true,
    pudge_dismember = true,
    tidehunter_ravage = true,
    disruptor_kinetic_field = true,
    disruptor_static_storm = true,
    centaur_hoof_stomp = true,
    elder_titan_echo_stomp = true,
    techies_suicide = true,
    techies_blast_off = true,
    magnataur_skewer = true,
    spirit_breaker_charge_of_darkness = true,
    spirit_breaker_nether_strike = true,
    earth_spirit_rolling_boulder = true,
    pangolier_rolling_thunder = true,
    ember_spirit_activate_fire_remnant = true,
    tusk_walrus_kick = true,
    antimage_blink = true,
    phantom_assassin_phantom_strike = true,
}

local MOVEMENT_NAMES = {
    techies_suicide = true,
    techies_blast_off = true,
    magnataur_skewer = true,
    spirit_breaker_charge_of_darkness = true,
    earth_spirit_rolling_boulder = true,
    pangolier_rolling_thunder = true,
}

local STUN_NAMES = {
    lina_light_strike_array = true,
    leshrac_split_earth = true,
    lion_impale = true,
    mars_spear = true,
    sven_storm_bolt = true,
    earthshaker_fissure = true,
    nyx_assassin_impale = true,
    slardar_slithereen_crush = true,
    dragon_knight_dragon_tail = true,
    chaos_knight_chaos_bolt = true,
    vengefulspirit_magic_missile = true,
    mirana_arrow = true,
    tiny_avalanche = true,
    shadow_shaman_hex = true,
    shadow_shaman_voodoo = true,
    shadow_shaman_shackles = true,
    bane_fiends_grip = true,
    witch_doctor_paralyzing_cask = true,
    beastmaster_primal_roar = true,
    pudge_dismember = true,
    tidehunter_ravage = true,
    disruptor_kinetic_field = true,
    disruptor_static_storm = true,
    centaur_hoof_stomp = true,
    elder_titan_echo_stomp = true,
}

local MOVEMENT_MODIFIERS = {
    techies_blast_off = {
        "modifier_techies_suicide",
        "modifier_techies_blast_off",
    },
    spirit_breaker_charge_of_darkness = {
        "modifier_spirit_breaker_charge_of_darkness",
    },
    magnataur_skewer = {
        "modifier_magnataur_skewer_movement",
        "modifier_magnataur_skewer",
    },
    earth_spirit_rolling_boulder = {
        "modifier_earth_spirit_rolling_boulder_caster",
    },
    pangolier_rolling_thunder = {
        "modifier_pangolier_rolling_thunder",
    },
}

local GLOBAL_THREATS = {
    enigma_black_hole = true,
    magnataur_reverse_polarity = true,
    faceless_void_chronosphere = true,
}

local BLINK_THREATS = {
    item_blink = true,
    item_arcane_blink = true,
    item_swift_blink = true,
    item_overwhelming_blink = true,
    antimage_blink = true,
    phantom_assassin_phantom_strike = true,
}

local AREA_THREATS = {
    tidehunter_ravage = {},
    centaur_hoof_stomp = { modifier = "hoof_stomp" },
    elder_titan_echo_stomp = {},
    disruptor_kinetic_field = { point = true },
    disruptor_static_storm = { point = true },
}
local AREA_MARGIN = 50

local lastCastTime = -100
local lastThreatKey = ""
local lastThreatTime = -100
local turretAbility = nil
local activeMovementThreats = {}
local movementKinematics = {}
local reversePolarityStates = {}
local blastOffThreats = {}
local techiesFlightStates = {}
local meleeAttackStates = {}
local runtimeCache = {
    time = -100,
    heroes = nil,
    npcs = nil,
}
local movementSampleTime = -100
local movementSampleCache = {}
local turretSearchTime = -100
local turretSearchHeroIndex = nil
local TURRET_SEARCH_INTERVAL = 0.5

local function now()
    return GameRules.GetGameTime()
end

local function distance2D(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

local function isLocalTinker(hero)
    return hero
        and Entity.IsHero(hero)
        and Entity.GetUnitName(hero) == "npc_dota_hero_tinker"
        and Entity.IsAlive(hero)
end

local function isEnemy(unit, hero)
    return unit
        and hero
        and Entity.IsHero(unit)
        and Entity.GetTeamNum(unit) ~= Entity.GetTeamNum(hero)
        and Entity.IsAlive(unit)
        and not Entity.IsDormant(unit)
end

local function abilityName(ability)
    if not ability then
        return ""
    end

    local name = Ability.GetName(ability)
    if name and name ~= "" then
        return name
    end

    return Ability.GetBaseName(ability) or ""
end

local function findTurretAbility(hero)
    if turretAbility and Entity.IsEntity(turretAbility) then
        return turretAbility
    end

    local heroIndex = Entity.GetIndex(hero)
    local currentTime = now()
    if turretSearchHeroIndex == heroIndex
        and currentTime - turretSearchTime < TURRET_SEARCH_INTERVAL
    then
        return nil
    end
    turretSearchHeroIndex = heroIndex
    turretSearchTime = currentTime

    for index = 0, 23 do
        local ability = NPC.GetAbilityByIndex(hero, index)
        local name = abilityName(ability)
        if ability and name:find("turret", 1, true) then
            turretAbility = ability
            return ability
        end
    end

    local candidates = {
        "tinker_deploy_turrets",
        "tinker_turrets",
    }
    for _, name in ipairs(candidates) do
        local ability = NPC.GetAbility(hero, name)
        if ability then
            turretAbility = ability
            return ability
        end
    end

    return nil
end

local function getRuntimeHeroes()
    if runtimeCache.heroes == nil then
        runtimeCache.heroes = Heroes.GetAll()
    end
    return runtimeCache.heroes
end

local function getRuntimeNpcs()
    if runtimeCache.npcs == nil then
        runtimeCache.npcs = NPCs.GetAll()
    end
    return runtimeCache.npcs
end

local function beginRuntimeFrame(currentTime)
    if runtimeCache.time == currentTime then
        return
    end

    runtimeCache.time = currentTime
    runtimeCache.heroes = Heroes.GetAll()
    runtimeCache.npcs = NPCs.GetAll()
    movementSampleTime = currentTime
    movementSampleCache = {}
end

local function getAreaRadius(ability, threatName)
    if not AREA_THREATS[threatName] then
        return nil
    end
    local radius = ability and Ability.GetLevelSpecialValueFor(ability, "radius") or 0
    if radius <= 0 then
        return 0
    end
    return radius + AREA_MARGIN
end

local function getAreaSources(caster, threatName)
    local sources = { Entity.GetAbsOrigin(caster) }
    if threatName ~= "elder_titan_echo_stomp" then
        return sources
    end
    local team = Entity.GetTeamNum(caster)
    for _, unit in ipairs(getRuntimeNpcs()) do
        local name = Entity.GetUnitName(unit)
        if name
            and name:find("ancestral_spirit", 1, true)
            and Entity.GetTeamNum(unit) == team
            and Entity.IsAlive(unit)
        then
            table.insert(sources, Entity.GetAbsOrigin(unit))
        end
    end
    return sources
end

local function getNearestAreaSource(hero, caster, threatName, radius)
    local heroPosition = Entity.GetAbsOrigin(hero)
    local nearest = nil
    local nearestDistance = radius
    for _, position in ipairs(getAreaSources(caster, threatName)) do
        local distance = distance2D(position, heroPosition)
        if distance <= nearestDistance then
            nearest = position
            nearestDistance = distance
        end
    end
    return nearest
end

local function threatAffectsHero(data, hero, caster, threatName)
    if GLOBAL_THREATS[threatName] then
        return true
    end

    local heroPosition = Entity.GetAbsOrigin(hero)
    local casterPosition = Entity.GetAbsOrigin(caster)
    local casterDistance = distance2D(casterPosition, heroPosition)

    local areaRadius = getAreaRadius(data.ability, threatName)
    if areaRadius then
        if AREA_THREATS[threatName].point then
            return data.position ~= nil
                and distance2D(data.position, heroPosition) <= areaRadius
        end
        return getNearestAreaSource(hero, caster, threatName, areaRadius) ~= nil
    end

    if BLINK_THREATS[threatName] then
        if not isEnemy(caster, hero) then
            return false
        end
        if threatName == "phantom_assassin_phantom_strike" then
            return data.target == hero
        end
        return data.position
            and distance2D(data.position, heroPosition) <= BLINK_DODGE_RADIUS
    end

    if MOVEMENT_NAMES[threatName] then
        return casterDistance <= TURRET_RADIUS
    end

    if data.target == hero then
        return true
    end

    if data.position and distance2D(data.position, heroPosition) <= TURRET_RADIUS then
        return true
    end

    return casterDistance <= TURRET_RADIUS
end

local function getBlinkTurretPosition(hero, destination, maxOffset)
    local heroPosition = Entity.GetAbsOrigin(hero)
    local dx = destination.x - heroPosition.x
    local dy = destination.y - heroPosition.y
    local distance = math.sqrt(dx * dx + dy * dy)
    if distance < 0.001 then
        return heroPosition
    end

    local offset = math.min(maxOffset, distance)
    return Vector(
        heroPosition.x + dx / distance * offset,
        heroPosition.y + dy / distance * offset,
        heroPosition.z
    )
end

local function getThreatCaster(data)
    if data.ability then
        local owner = Ability.GetOwner(data.ability)
        if owner and Entity.IsNPC(owner) then
            return owner
        end
    end

    return data.npc
end

local function canCast(ability)
    return ability
        and Ability.IsReady(ability)
        and Ability.CanBeExecuted(ability) == -1
end

local function sampleMovement(unit)
    local index = Entity.GetIndex(unit)
    if movementSampleTime == now() and movementSampleCache[index] then
        return movementSampleCache[index]
    end

    local position = Entity.GetAbsOrigin(unit)
    local currentTime = now()
    local currentSpeed = NPC.GetMoveSpeed(unit)
    local state = movementKinematics[index]

    if not state then
        state = {
            position = position,
            time = currentTime,
            speed = currentSpeed and currentSpeed > 0
                and currentSpeed
                or DEFAULT_MOVE_SPEED,
            velocityX = 0,
            velocityY = 0,
            directionX = 0,
            directionY = 0,
        }
        movementKinematics[index] = state
        movementSampleCache[index] = state
        return state
    end

    local deltaTime = currentTime - state.time
    if deltaTime > 0.005 and deltaTime < 0.25 then
        local velocityX = (position.x - state.position.x) / deltaTime
        local velocityY = (position.y - state.position.y) / deltaTime
        local measuredSpeed = math.sqrt(
            velocityX * velocityX + velocityY * velocityY
        )

        if measuredSpeed >= 50 then
            local previousVelocityX = state.velocityX or 0
            local previousVelocityY = state.velocityY or 0
            local velocityBlend = state.hasVelocity and 0.65 or 0
            local blendedVelocityX = previousVelocityX * velocityBlend
                + velocityX * (1 - velocityBlend)
            local blendedVelocityY = previousVelocityY * velocityBlend
                + velocityY * (1 - velocityBlend)
            local blendedSpeed = math.sqrt(
                blendedVelocityX * blendedVelocityX
                    + blendedVelocityY * blendedVelocityY
            )

            if blendedSpeed >= 50 then
                state.velocityX = blendedVelocityX
                state.velocityY = blendedVelocityY
                state.speed = blendedSpeed
                state.directionX = blendedVelocityX / blendedSpeed
                state.directionY = blendedVelocityY / blendedSpeed
                state.hasVelocity = true
            end
        end
    end

    if currentSpeed and currentSpeed > state.speed then
        state.speed = currentSpeed
    end

    state.position = position
    state.time = currentTime
    movementSampleCache[index] = state
    return state
end

local function getPredictedSpeed(unit)
    local state = sampleMovement(unit)
    local currentSpeed = NPC.GetMoveSpeed(unit)
    local speed = state.speed or DEFAULT_MOVE_SPEED

    if currentSpeed and currentSpeed > speed then
        speed = currentSpeed
    end

    return speed
end

local function getPredictedThreatPosition(hero, caster, threatName)
    local state = sampleMovement(caster)
    local casterPosition = Entity.GetAbsOrigin(caster)
    local heroPosition = Entity.GetAbsOrigin(hero)
    local dx = heroPosition.x - casterPosition.x
    local dy = heroPosition.y - casterPosition.y
    local length = math.sqrt(dx * dx + dy * dy)
    local speed = getPredictedSpeed(caster)
    local horizon = TURRET_DELAY + MOVEMENT_PREFIRE_LEAD

    if length < 0.001 then
        return casterPosition
    end

    local directionX = dx / length
    local directionY = dy / length
    local movementSpeed = math.sqrt(
        (state.velocityX or 0) * (state.velocityX or 0)
            + (state.velocityY or 0) * (state.velocityY or 0)
    )

    if movementSpeed >= 50 then
        directionX = state.velocityX / movementSpeed
        directionY = state.velocityY / movementSpeed
        speed = movementSpeed
    end

    if threatName == "magnataur_skewer" and speed < MAGNUS_SKEWER_SPEED then
        speed = MAGNUS_SKEWER_SPEED
    end

    return Vector(
        casterPosition.x + directionX * speed * horizon,
        casterPosition.y + directionY * speed * horizon,
        casterPosition.z
    )
end

local function getNetherStrikeLandingPosition(hero, caster, ability)
    local heroState = sampleMovement(hero)
    local casterState = sampleMovement(caster)
    local heroPosition = Entity.GetAbsOrigin(hero)
    local casterPosition = Entity.GetAbsOrigin(caster)
    local castPoint = Ability.GetCastPoint(ability, true)

    if not castPoint or castPoint < 0 then
        castPoint = NETHER_STRIKE_DEFAULT_CAST_POINT
    end

    local heroVelocityX = heroState.velocityX or 0
    local heroVelocityY = heroState.velocityY or 0
    local casterVelocityX = casterState.velocityX or 0
    local casterVelocityY = casterState.velocityY or 0
    local impactHeroPosition = Vector(
        heroPosition.x + heroVelocityX * castPoint,
        heroPosition.y + heroVelocityY * castPoint,
        heroPosition.z
    )
    local impactCasterPosition = Vector(
        casterPosition.x + casterVelocityX * castPoint,
        casterPosition.y + casterVelocityY * castPoint,
        casterPosition.z
    )
    local dx = impactCasterPosition.x - impactHeroPosition.x
    local dy = impactCasterPosition.y - impactHeroPosition.y
    local distance = math.sqrt(dx * dx + dy * dy)

    if distance < 0.001 then
        return impactHeroPosition
    end

    return Vector(
        impactHeroPosition.x + dx / distance * NETHER_STRIKE_PUSH_DISTANCE,
        impactHeroPosition.y + dy / distance * NETHER_STRIKE_PUSH_DISTANCE,
        impactHeroPosition.z
    )
end

local function getMovementTurretPosition(hero, caster, predictedPosition, castRange)
    local heroPosition = Entity.GetAbsOrigin(hero)
    local dx = predictedPosition.x - heroPosition.x
    local dy = predictedPosition.y - heroPosition.y
    local distance = math.sqrt(dx * dx + dy * dy)

    if distance < 0.001 then
        return heroPosition
    end

    local maxRange = math.min(castRange, TURRET_RADIUS)
    if distance <= maxRange then
        return predictedPosition
    end

    local factor = maxRange / distance
    return Vector(
        heroPosition.x + dx * factor,
        heroPosition.y + dy * factor,
        predictedPosition.z
    )
end

local function getPredictedFlightPosition(hero, caster)
    local state = sampleMovement(caster)
    local casterPosition = Entity.GetAbsOrigin(caster)
    local heroPosition = Entity.GetAbsOrigin(hero)
    local horizon = TURRET_DELAY + PREFIRE_LEAD
    local velocityX = state.velocityX or 0
    local velocityY = state.velocityY or 0
    local speed = math.sqrt(velocityX * velocityX + velocityY * velocityY)

    if speed < 50 then
        local dx = casterPosition.x - heroPosition.x
        local dy = casterPosition.y - heroPosition.y
        local length = math.sqrt(dx * dx + dy * dy)
        if length > 0.001 then
            velocityX = dx / length * (state.speed or DEFAULT_MOVE_SPEED)
            velocityY = dy / length * (state.speed or DEFAULT_MOVE_SPEED)
        end

    end

    return Vector(
        casterPosition.x + velocityX * horizon,
        casterPosition.y + velocityY * horizon,
        casterPosition.z
    )
end

local function getTechiesLandingPosition(caster, modifier)
    local state = techiesFlightStates[Entity.GetIndex(caster)]
    if not state or not modifier or not state.hasVelocity then
        return nil
    end

    local currentTime = now()
    local dieTime = Modifier.GetDieTime(modifier)
    local remaining = dieTime and dieTime - currentTime or 0
    if remaining <= 0 then
        local creationTime = Modifier.GetCreationTime(modifier)
        local duration = Modifier.GetDuration(modifier)
        if creationTime and duration and duration > 0 then
            remaining = creationTime + duration - currentTime
        end
    end
    if not remaining or remaining <= 0 or remaining > 1.5 then
        remaining = TECHIES_FLIGHT_DURATION
            - (currentTime - state.startedAt)
    end
    if remaining <= 0 then
        return nil
    end

    local position = Entity.GetAbsOrigin(caster)
    return Vector(
        position.x + state.velocityX * remaining,
        position.y + state.velocityY * remaining,
        position.z
    )
end

local function getTechiesRingCastPosition(hero, centerPosition)
    local heroPosition = Entity.GetAbsOrigin(hero)
    local dx = centerPosition.x - heroPosition.x
    local dy = centerPosition.y - heroPosition.y
    local distance = math.sqrt(dx * dx + dy * dy)
    if distance < 0.001 then
        return nil
    end

    local offset = math.min(SPECIAL_TURRET_OFFSET, distance)
    return Vector(
        heroPosition.x + dx / distance * offset,
        heroPosition.y + dy / distance * offset,
        heroPosition.z
    )
end

local function updateTechiesFlightState(caster, modifier)
    local index = Entity.GetIndex(caster)
    local position = Entity.GetAbsOrigin(caster)
    local currentTime = now()
    local state = techiesFlightStates[index]
    local modifierKey = Modifier.GetCreationTime(modifier)
        or Modifier.GetName(modifier)
    local movementState = movementKinematics[index]
    local launchVelocityX = movementState
        and movementState.velocityX
        or 0
    local launchVelocityY = movementState
        and movementState.velocityY
        or 0
    local launchSpeed = math.sqrt(
        launchVelocityX * launchVelocityX
            + launchVelocityY * launchVelocityY
    )

    if not state then
        techiesFlightStates[index] = {
            position = position,
            time = currentTime,
            modifierKey = modifierKey,
            startedAt = currentTime,
            velocityX = launchVelocityX,
            velocityY = launchVelocityY,
            hasVelocity = launchSpeed >= 50,
        }
        return
    end

    if state.modifierKey ~= modifierKey then
        state.position = position
        state.time = currentTime
        state.modifierKey = modifierKey
        state.startedAt = currentTime
        state.velocityX = launchVelocityX
        state.velocityY = launchVelocityY
        state.hasVelocity = launchSpeed >= 50
        return
    end

    local deltaTime = currentTime - state.time
    if deltaTime > 0.005 and deltaTime < 0.25 then
        local velocityX = (position.x - state.position.x) / deltaTime
        local velocityY = (position.y - state.position.y) / deltaTime
        local speed = math.sqrt(velocityX * velocityX + velocityY * velocityY)
        if speed >= 50 then
            state.velocityX = velocityX
            state.velocityY = velocityY
            state.hasVelocity = true
        end
    end

    state.position = position
    state.time = currentTime
end

local function getTurretCastPosition(origin, predictedPosition, castRange)
    local dx = predictedPosition.x - origin.x
    local dy = predictedPosition.y - origin.y
    local distance = math.sqrt(dx * dx + dy * dy)

    if distance < 0.001 then
        return nil
    end

    local targetRange = distance
    if targetRange > castRange then
        targetRange = castRange
    end

    local factor = targetRange / distance
    return Vector(
        origin.x + dx * factor,
        origin.y + dy * factor,
        predictedPosition.z
    )
end

local function getTurretCastRange(ability)
    local range = Ability.GetCastRange(ability)
    if not range or range <= 0 then
        return TURRET_RADIUS
    end

    return range
end

local function castTurret(hero, caster, threatName, targetPosition)
    if invisSafe:Get()
        and NPC.HasState(hero, Enum.ModifierState.MODIFIER_STATE_INVISIBLE)
    then
        return false
    end

    local turret = findTurretAbility(hero)
    if not canCast(turret) then
        return false
    end

    local heroPosition = Entity.GetAbsOrigin(hero)
    local castRange = getTurretCastRange(turret)
    local castPosition = targetPosition
        or getPredictedThreatPosition(hero, caster)
    local predictedDistance = distance2D(heroPosition, castPosition)
    if targetPosition then
        if predictedDistance > castRange then
            return false
        end
    else
        if predictedDistance > castRange + INTERRUPT_RADIUS
        then
            return false
        end

        castPosition = getTurretCastPosition(
            heroPosition,
            castPosition,
            castRange
        )
        if not castPosition then
            return false
        end
    end

    Ability.CastPosition(turret, castPosition, false, false, true, "tinker_turret_dodge")
    lastCastTime = now()
    lastThreatKey = tostring(Entity.GetIndex(caster)) .. ":" .. threatName
    lastThreatTime = lastCastTime
    activeMovementThreats[lastThreatKey] = true

    return true
end

local function isThreatOff(heroName, threatName)
    local key = heroName .. "_" .. threatName
    local value = dodge.off[key]
    if value == nil then
        value = Config.ReadInt(PANEL_CONFIG, "off_" .. key, 0) == 1
        dodge.off[key] = value
    end
    return value
end

local function setThreatOff(heroName, threatName, value)
    local key = heroName .. "_" .. threatName
    dodge.off[key] = value
    Config.WriteInt(PANEL_CONFIG, "off_" .. key, value and 1 or 0)
end

local function threatKey(threatName)
    if threatName:sub(1, 5) == "item_" then
        return "blink"
    end
    return threatName
end

local function isThreatEnabled(caster, threatName)
    local heroName = caster and Entity.GetUnitName(caster)
    if not heroName then
        return true
    end
    return not isThreatOff(heroName, threatKey(threatName))
end

local function requestTurret(hero, caster, threatName, targetPosition, onSuccess)
    if not isThreatEnabled(caster, threatName) then
        return
    end
    if castTurret(hero, caster, threatName, targetPosition) and onSuccess then
        onSuccess()
    end
end

local function hasMovementThreat(unit, threatName)
    local modifiers = MOVEMENT_MODIFIERS[threatName]
    if not modifiers then
        return false
    end

    for _, modifierName in ipairs(modifiers) do
        if NPC.HasModifier(unit, modifierName) then
            return true
        end
    end

    return false
end

local abilityCache = {}
local abilityCacheTime = -100
local ABILITY_CACHE_DURATION = 2

local function getCachedAbility(unit, abilityName)
    local index = Entity.GetIndex(unit)
    local key = index .. ":" .. abilityName
    local cached = abilityCache[key]

    if cached ~= nil then
        if cached == false then
            return nil
        end
        if Entity.IsEntity(cached) then
            return cached
        end
        abilityCache[key] = false
        return nil
    end

    local ability = NPC.GetAbility(unit, abilityName)
    abilityCache[key] = ability or false

    return ability
end

local function clearAbilityCache()
    local currentTime = now()
    if currentTime - abilityCacheTime > ABILITY_CACHE_DURATION then
        abilityCache = {}
        abilityCacheTime = currentTime
    end
end

local function hasModifierLike(unit, pattern)
    for _, modifier in ipairs(NPC.GetModifiers(unit) or {}) do
        local name = Modifier.GetName(modifier)
        if name and name:find(pattern, 1, true) then
            return true
        end
    end
    return false
end

local function scanReversePolaritySingle(hero, enemy, enemyIndex)
    local ability = getCachedAbility(enemy, "magnataur_reverse_polarity")
    if ability then
        local inPhase = Ability.IsInAbilityPhase(ability)
        local state = reversePolarityStates[enemyIndex]
        if not state then
            state = {
                inPhase = false,
                cooldown = Ability.GetCooldown(ability) or 0,
            }
            reversePolarityStates[enemyIndex] = state
        end

        local cooldown = Ability.GetCooldown(ability) or 0
        local phaseStarted = inPhase and not state.inPhase
        local cooldownStarted = cooldown > state.cooldown + 0.05
        if phaseStarted or cooldownStarted then
            requestTurret(
                hero,
                enemy,
                "magnataur_reverse_polarity",
                Entity.GetAbsOrigin(enemy)
            )
        end

        state.inPhase = inPhase
        state.cooldown = cooldown
    end
end

local function scanMovementThreatsSingle(
    hero,
    enemy,
    enemyIndex,
    heroPosition,
    castRange,
    seenThreats,
    seenMovementUnits
)
    for threatName in pairs(MOVEMENT_MODIFIERS) do
        if threatName ~= "techies_blast_off"
            and hasMovementThreat(enemy, threatName)
        then
            seenMovementUnits[enemyIndex] = true

            local threatKey = tostring(enemyIndex) .. ":" .. threatName
            seenThreats[threatKey] = true

            local predictedPosition = getPredictedThreatPosition(
                hero,
                enemy,
                threatName
            )
            local predictedDistance = distance2D(
                predictedPosition,
                heroPosition
            )
            local canImpactInRing = predictedDistance
                <= castRange + INTERRUPT_RADIUS

            if canImpactInRing and not activeMovementThreats[threatKey] then
                local castPosition = getMovementTurretPosition(
                    hero,
                    enemy,
                    predictedPosition,
                    castRange
                )
                if castPosition then
                    requestTurret(
                        hero,
                        enemy,
                        threatName,
                        castPosition
                    )
                end
            end
            break
        end
    end
end

local function scanTechiesBlastOffSingle(
    hero,
    enemy,
    enemyIndex,
    enemyPosition,
    heroPosition,
    seenThreats,
    sampledUnits
)
    local key = tostring(enemyIndex) .. ":techies_blast_off"

    if not sampledUnits[enemyIndex] then
        sampleMovement(enemy)
    end

    local activeModifier = nil
    local activeModifierObject = nil
    local modifiers = NPC.GetModifiers(enemy)

    for _, modifier in ipairs(modifiers or {}) do
        local modifierName = Modifier.GetName(modifier)
        if modifierName == "modifier_techies_suicide"
            or modifierName == "modifier_techies_blast_off"
            or modifierName == "modifier_techies_suicide_leap"
            or string.find(modifierName or "", "techies")
                and string.find(modifierName or "", "suicide")
        then
            activeModifier = modifierName
            activeModifierObject = modifier
            break
        end
    end

    local ability = getCachedAbility(enemy, "techies_suicide")
        or getCachedAbility(enemy, "techies_blast_off")
    local inPhase = ability and Ability.IsInAbilityPhase(ability) or false

    local active = activeModifier ~= nil
    local startedOrFlying = inPhase or active
    if active then
        updateTechiesFlightState(enemy, activeModifierObject)
    else
        techiesFlightStates[enemyIndex] = nil
    end
    if startedOrFlying then
        seenThreats[key] = true
        if active and not blastOffThreats[key] then
            local predictedPosition = getPredictedFlightPosition(
                hero,
                enemy
            )
            local landingPosition = getTechiesLandingPosition(
                enemy,
                activeModifierObject
            )
            local castPosition = nil
            local blastCenter = landingPosition
                or predictedPosition
                or enemyPosition
            local blastDistance = distance2D(blastCenter, heroPosition)
            if blastDistance <= TECHIES_BLAST_RADIUS then
                castPosition = getTechiesRingCastPosition(
                    hero,
                    blastCenter
                )
            end
            if castPosition then
                requestTurret(
                    hero,
                    enemy,
                    ability and abilityName(ability) or "techies_blast_off",
                    castPosition,
                    function()
                        blastOffThreats[key] = true
                    end
                )
            end
        end
    end
end

local function scanSpiritStomps(hero)
    local heroPosition = Entity.GetAbsOrigin(hero)
    local team = Entity.GetTeamNum(hero)
    for _, unit in ipairs(getRuntimeNpcs()) do
        local name = Entity.GetUnitName(unit)
        if name
            and name:find("ancestral_spirit", 1, true)
            and Entity.GetTeamNum(unit) ~= team
            and Entity.IsAlive(unit)
            and not Entity.IsDormant(unit)
        then
            local ability = getCachedAbility(
                unit,
                "elder_titan_echo_stomp_spirit"
            )
            local key = Entity.GetIndex(unit) .. ":spirit_stomp"
            local active = hasModifierLike(unit, "ancestral_spirit_cast_time")
                or (ability ~= nil
                    and (Ability.IsInAbilityPhase(ability) or Ability.IsChannelling(ability)))
            if active and not dodge.phases[key] then
                local spiritPosition = Entity.GetAbsOrigin(unit)
                local radius = getAreaRadius(ability, "elder_titan_echo_stomp")
                local distance = distance2D(spiritPosition, heroPosition)
                if not isThreatOff("npc_dota_hero_elder_titan", "elder_titan_echo_stomp")
                    and distance <= radius
                then
                    castTurret(
                        hero,
                        unit,
                        "elder_titan_echo_stomp",
                        getBlinkTurretPosition(hero, spiritPosition, SPECIAL_TURRET_OFFSET)
                    )
                end
            end
            dodge.phases[key] = active
        end
    end
end

local handleMeleeAttack
local handleThreat

local function scanAreaPhasesSingle(hero, enemy, enemyIndex)
    for threatName, area in pairs(AREA_THREATS) do
        if not area.point then
            local ability = getCachedAbility(enemy, threatName)
            local key = enemyIndex .. ":" .. threatName
            local active = ability ~= nil
                and (
                    Ability.IsInAbilityPhase(ability)
                    or Ability.IsChannelling(ability)
                    or (area.modifier ~= nil and hasModifierLike(enemy, area.modifier))
                )
            if active and not dodge.phases[key] then
                handleThreat({
                    npc = enemy,
                    ability = ability,
                })
            end
            dodge.phases[key] = active
        end
    end
end

local function scanAllThreats(hero)
    local heroPosition = Entity.GetAbsOrigin(hero)
    local turret = findTurretAbility(hero)
    local castRange = turret and getTurretCastRange(turret) or TURRET_RADIUS
    local seenMovementThreats = {}
    local seenBlastOffThreats = {}
    local seenMovementUnits = {}
    local sampledUnits = {}

    for _, enemy in ipairs(getRuntimeHeroes()) do
        if isEnemy(enemy, hero) then
            local enemyIndex = Entity.GetIndex(enemy)
            local enemyPosition = Entity.GetAbsOrigin(enemy)
            local distance = distance2D(enemyPosition, heroPosition)

            handleMeleeAttack(enemy, hero)
            if distance <= SPEED_SAMPLE_RADIUS then
                sampleMovement(enemy)
                sampledUnits[enemyIndex] = true
            end

            scanReversePolaritySingle(hero, enemy, enemyIndex)
            scanMovementThreatsSingle(
                hero,
                enemy,
                enemyIndex,
                heroPosition,
                castRange,
                seenMovementThreats,
                seenMovementUnits
            )
            scanTechiesBlastOffSingle(
                hero,
                enemy,
                enemyIndex,
                enemyPosition,
                heroPosition,
                seenBlastOffThreats,
                sampledUnits
            )
            scanAreaPhasesSingle(hero, enemy, enemyIndex)
        end
    end

    for threatKey in pairs(activeMovementThreats) do
        if not seenMovementThreats[threatKey] then
            activeMovementThreats[threatKey] = nil
        end
    end

    for key in pairs(blastOffThreats) do
        if not seenBlastOffThreats[key] then
            blastOffThreats[key] = nil
            activeMovementThreats[key] = nil
        end
    end

    for enemyIndex in pairs(movementKinematics) do
        local enemy = Entity.Get(enemyIndex)
        if not enemy
            or not Entity.IsAlive(enemy)
            or not seenMovementUnits[enemyIndex]
        then
            movementKinematics[enemyIndex] = nil
            meleeAttackStates[enemyIndex] = nil
        end
    end

    scanSpiritStomps(hero)
    clearAbilityCache()
end

handleMeleeAttack = function(attacker, hero, confirmed)
    if not meleeAttackProtection:Get()
        or not attacker
    then
        return
    end

    if now() < meleeAttackStartMinute:Get() * 60 then
        return
    end

    if not NPC.IsHero(attacker)
        or NPC.IsRanged(attacker)
        or not Entity.IsAlive(attacker)
        or not isEnemy(attacker, hero)
    then
        return
    end

    local attackerIndex = Entity.GetIndex(attacker)
    local distance = distance2D(
        Entity.GetAbsOrigin(attacker),
        Entity.GetAbsOrigin(hero)
    )
    local attackRange = NPC.GetAttackRange(attacker) or 150
    local attacking = confirmed or (
        NPC.IsAttacking(attacker)
        and distance <= attackRange + 100
    )
    local wasAttacking = meleeAttackStates[attackerIndex] or false
    meleeAttackStates[attackerIndex] = attacking
    if not attacking or wasAttacking then
        return
    end

    local currentTime = now()
    local threatKey = tostring(Entity.GetIndex(attacker)) .. ":melee_attack"
    if threatKey == lastThreatKey and currentTime - lastThreatTime < 0.45 then
        return
    end

    local attackerPosition = Entity.GetAbsOrigin(attacker)
    local targetPosition = getBlinkTurretPosition(
        hero,
        attackerPosition,
        SPECIAL_TURRET_OFFSET
    )
    castTurret(hero, attacker, "melee_attack", targetPosition)
end

local function handleMeleeAttackOrder(data, hero)
    if not data
        or data.order ~= Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET
        or not data.target
        or Entity.GetIndex(data.target) ~= Entity.GetIndex(hero)
    then
        return
    end
    handleMeleeAttack(data.npc, hero)
end

handleThreat = function(data)
    if not enabled:Get() then
        return
    end

    local hero = Heroes.GetLocal()
    if not isLocalTinker(hero) then
        return
    end

    handleMeleeAttackOrder(data, hero)
    if not data or not data.ability or not isEnemy(data.npc, hero) then
        return
    end

    local threatName = abilityName(data.ability)
    if not THREAT_NAMES[threatName] then
        return
    end

    if threatName == "techies_blast_off"
        or threatName == "techies_suicide"
        or threatName == "magnataur_skewer"
    then
        return
    end

    if not threatAffectsHero(data, hero, data.npc, threatName) then
        return
    end

    local currentTime = now()
    if currentTime - lastCastTime < 0.08 then
        return
    end
    local threatKey = tostring(Entity.GetIndex(data.npc)) .. ":" .. threatName
    if MOVEMENT_NAMES[threatName] and activeMovementThreats[threatKey] then
        return
    end
    if threatKey == lastThreatKey and currentTime - lastThreatTime < 0.45 then
        return
    end

    local targetPosition = nil
    if threatName == "enigma_black_hole"
        or threatName == "faceless_void_chronosphere"
    then
        local heroPosition = Entity.GetAbsOrigin(hero)
        local centerPosition = data.position
            or Entity.GetAbsOrigin(data.npc)
        local dx = centerPosition.x - heroPosition.x
        local dy = centerPosition.y - heroPosition.y
        local distance = math.sqrt(dx * dx + dy * dy)
        if distance > 0.001 then
            local offset = math.min(190, distance)
            targetPosition = Vector(
                heroPosition.x + dx / distance * offset,
                heroPosition.y + dy / distance * offset,
                heroPosition.z
            )
        else
            targetPosition = heroPosition
        end
    elseif threatName == "magnataur_reverse_polarity" then
        targetPosition = Entity.GetAbsOrigin(data.npc)
    elseif threatName == "spirit_breaker_nether_strike" then
        targetPosition = getNetherStrikeLandingPosition(
            hero,
            data.npc,
            data.ability
        )
    elseif BLINK_THREATS[threatName] then
        local destination = data.position
        if threatName == "phantom_assassin_phantom_strike" then
            destination = Entity.GetAbsOrigin(data.npc)
        end
        targetPosition = getBlinkTurretPosition(
            hero,
            destination or Entity.GetAbsOrigin(data.npc),
            SPECIAL_TURRET_OFFSET
        )
    elseif STUN_NAMES[threatName] then
        local threatCaster = getThreatCaster(data)
        if threatCaster and Entity.IsNPC(threatCaster) then
            local sourcePosition = Entity.GetAbsOrigin(threatCaster)
            local areaRadius = getAreaRadius(data.ability, threatName)
            if areaRadius then
                if AREA_THREATS[threatName].point and data.position then
                    sourcePosition = data.position
                else
                    sourcePosition = getNearestAreaSource(
                        hero,
                        threatCaster,
                        threatName,
                        areaRadius
                    ) or sourcePosition
                end
            end
            targetPosition = getBlinkTurretPosition(
                hero,
                sourcePosition,
                SPECIAL_TURRET_OFFSET
            )
        end
    end

    requestTurret(hero, data.npc, threatName, targetPosition)
end

local function pixel(value)
    return math.floor(value + 0.5)
end

local function getPanelImage(key, path)
    local image = dodge.images[key]
    if not image then
        image = Render.LoadImage(path)
        dodge.images[key] = image
    end
    return image
end

local function getPanelEnemies(hero)
    local enemies = {}
    for _, enemy in ipairs(getRuntimeHeroes()) do
        local name = Entity.GetUnitName(enemy)
        if name
            and name ~= ""
            and isEnemy(enemy, hero)
            and not NPC.IsIllusion(enemy)
            and not enemies[name]
        then
            enemies[name] = enemy
        end
    end
    return enemies
end

local function clearPanelEnemyCache(name)
    dodge.abilities[name] = nil
    dodge.enemyEntities[name] = nil
    panel.rows[name] = nil
    dodge.images["hero_" .. name] = nil
    panel.fx["hero|" .. name] = nil
    for key in pairs(panel.fx) do
        if key:sub(1, #name + 1) == name .. "|" then
            panel.fx[key] = nil
        end
    end
end

local function refreshPanelAbilities(enemies, force)
    local gameTime = now()
    local identityChanged = false

    for name in pairs(dodge.enemyEntities) do
        if not enemies[name] then
            clearPanelEnemyCache(name)
        end
    end
    for name in pairs(dodge.abilities) do
        if not enemies[name] then
            clearPanelEnemyCache(name)
        end
    end
    for name, enemy in pairs(enemies) do
        local entityIndex = Entity.GetIndex(enemy)
        if dodge.enemyEntities[name] ~= entityIndex then
            clearPanelEnemyCache(name)
            dodge.enemyEntities[name] = entityIndex
            identityChanged = true
        end
    end

    if not force
        and not identityChanged
        and gameTime - dodge.abilitiesTime < 2
    then
        return
    end
    dodge.abilitiesTime = gameTime
    for name, enemy in pairs(enemies) do
        local list = {}
        local seen = {}
        for index = 0, 23 do
            local ability = NPC.GetAbilityByIndex(enemy, index)
            local threatName = ability and abilityName(ability) or ""
            if THREAT_NAMES[threatName]
                and threatName:sub(1, 5) ~= "item_"
                and not seen[threatName]
            then
                seen[threatName] = true
                table.insert(list, threatName)
            end
        end
        dodge.abilities[name] = list
    end
end

local function getPanelRows(enemies)
    local rows = {}
    for name in pairs(enemies) do
        table.insert(rows, name)
    end
    table.sort(rows)
    return rows
end

local function getRowItems(name)
    local items = {}
    for _, threatName in ipairs(dodge.abilities[name] or {}) do
        table.insert(items, threatName)
    end
    table.insert(items, "blink")
    return items
end

local function isRowEnabled(name)
    for _, key in ipairs(getRowItems(name)) do
        if not isThreatOff(name, key) then
            return true
        end
    end
    return false
end

local function setRowEnabled(name, value)
    for _, key in ipairs(getRowItems(name)) do
        setThreatOff(name, key, not value)
    end
end

local function approach(value, target, step)
    if value < target then
        return math.min(target, value + step)
    end
    return math.max(target, value - step)
end

local function drawIcon(image, id, x, y, w, h, enabled, alpha, hoverable, dt)
    local fx = panel.fx[id]
    if not fx then
        fx = { on = enabled and 1 or 0, hover = 0 }
        panel.fx[id] = fx
    end
    local hovered = hoverable and Input.IsCursorInRect(x, y, w, h)
    fx.on = approach(fx.on, enabled and 1 or 0, dt / 0.15)
    fx.hover = approach(fx.hover, hovered and 1 or 0, dt / 0.1)
    if not image then
        return
    end

    local on = fx.on * fx.on * (3 - 2 * fx.on)
    local imageAlpha = 97 + 158 * on + (1 - on) * 60 * fx.hover
    Render.Image(
        image,
        Vec2(x, y),
        Vec2(w, h),
        Color(255, 255, 255, math.floor(imageAlpha * alpha)),
        5,
        Enum.DrawFlags.None,
        Vec2(0, 0),
        Vec2(1, 1),
        1 - on
    )
    if fx.hover > 0 then
        Render.FilledRect(
            Vec2(x, y),
            Vec2(x + w, y + h),
            Color(255, 255, 255, math.floor(28 * fx.hover * alpha)),
            5
        )
    end
end

local function drawDodgePanel()
    local hero = Heroes.GetLocal()
    local visible = blinkPanelOpen and isLocalTinker(hero)
    local inputCaptured = Input.IsInputCaptured() or Input.IsPopupOpen()
    local dt = math.min(0.1, GlobalVars.GetAbsFrameTime())
    local step = dt / (visible and 0.1 or 0.07)
    panel.progress = math.max(0, math.min(1, panel.progress + (visible and step or -step)))
    panel.anim = easeOutCubic(panel.progress)
    panel.time = panel.time + dt
    local justShown = false
    if visible and not panel.shown then
        panel.shown = true
        panel.rows = {}
        panel.scroll = 0
        justShown = true
    end
    if not visible and panel.progress <= 0 then
        panel.anim = 0
        panel.drag = false
        panel.shown = false
        panel.rect = nil
        panel.pendingClick = false
        panel.mouseDown = false
        return
    end
    if not hero then
        refreshPanelAbilities({}, false)
        panel.rows = {}
        panel.fx = {}
        panel.rect = nil
        panel.pendingClick = false
        panel.mouseDown = false
        panel.drag = false
        return
    end

    local enemies = getPanelEnemies(hero)
    refreshPanelAbilities(enemies, justShown)
    local rows = getPanelRows(enemies)
    local activeFx = {}
    for _, name in ipairs(rows) do
        activeFx["hero|" .. name] = true
        for _, key in ipairs(getRowItems(name)) do
            activeFx[name .. "|" .. key] = true
        end
    end
    for key in pairs(panel.fx) do
        if not activeFx[key] then
            panel.fx[key] = nil
        end
    end

    local screen = Render.ScreenSize()
    local padding = 8
    local headerHeight = 24
    local rowHeight = 32
    local rowGap = 2
    local portraitSize = 26
    local iconSize = 24
    local iconGap = 6
    local blinkSize = Render.ImageSize(blinkItemImage)
    local blinkAspect = 1
    local blinkWidth = iconSize
    if blinkSize and blinkSize.y > 0 then
        blinkAspect = blinkSize.x / blinkSize.y
        blinkWidth = pixel(iconSize * blinkAspect)
    end

    local maxSpellCount = 0
    for _, name in ipairs(rows) do
        maxSpellCount = math.max(maxSpellCount, #getRowItems(name) - 1)
    end
    local availableContentWidth = math.max(1, screen.x - 32)
    if maxSpellCount > 0 then
        local rowChrome = portraitSize + 8 + 1 + 8
        local maxIconSize = math.floor(
            (availableContentWidth - rowChrome - blinkWidth
                - maxSpellCount * iconGap) / maxSpellCount
        )
        iconSize = math.max(12, math.min(iconSize, maxIconSize))
        blinkWidth = pixel(iconSize * blinkAspect)
    end

    local title = localization.Get("ttd_panel_title")
    local total = 0
    local enabledCount = 0
    local contentWidth = 0
    for _, name in ipairs(rows) do
        local items = getRowItems(name)
        local rowWidth = portraitSize + 8 + 1 + 8
            + (#items - 1) * (iconSize + iconGap) + blinkWidth
        contentWidth = math.max(contentWidth, rowWidth)
        total = total + #items
        for _, key in ipairs(items) do
            if not isThreatOff(name, key) then
                enabledCount = enabledCount + 1
            end
        end
    end
    local countText = enabledCount .. " / " .. total
    local titleSize = Render.TextSize(blinkPanelFont, 12, title)
    local countSize = Render.TextSize(blinkPanelFont, 11, countText)
    contentWidth = math.max(contentWidth, titleSize.x + 8 + countSize.x, 160)

    local width = pixel(math.min(padding * 2 + contentWidth, screen.x - 16))
    local rowStep = rowHeight + rowGap
    local maxVisibleRows = math.max(
        1,
        math.floor(
            (screen.y - 16 - padding * 2 - headerHeight + rowGap) / rowStep
        )
    )
    local visibleRowCount = math.min(#rows, maxVisibleRows)
    local maxScroll = math.max(0, #rows - visibleRowCount)
    panel.scroll = math.max(0, math.min(panel.scroll, maxScroll))
    local height = pixel(
        padding * 2 + headerHeight
            + math.max(0, visibleRowCount * rowStep - rowGap)
    )

    if not panel.x then
        panel.x = Config.ReadFloat(PANEL_CONFIG, "full_center", 0.5)
        panel.y = Config.ReadInt(PANEL_CONFIG, "full_y", 120)
    end

    local cursorX, cursorY = Input.GetCursorPos()
    local x = pixel(math.max(
        8,
        math.min(screen.x - width - 8, panel.x * screen.x - width / 2)
    ))
    local y = pixel(math.max(8, math.min(screen.y - height - 8, panel.y)))
    local interactive = visible and panel.anim > 0.9 and not inputCaptured
    local pressed = interactive and panel.pendingClick
    panel.pendingClick = false

    if inputCaptured then
        panel.drag = false
        panel.mouseDown = false
    end
    if panel.drag then
        if panel.mouseDown and interactive then
            x = pixel(math.max(8, math.min(
                screen.x - width - 8,
                cursorX - panel.dragX
            )))
            y = pixel(math.max(8, math.min(
                screen.y - height - 8,
                cursorY - panel.dragY
            )))
            panel.x = (x + width / 2) / screen.x
            panel.y = y
        else
            panel.drag = false
            Config.WriteFloat(PANEL_CONFIG, "full_center", panel.x)
            Config.WriteInt(PANEL_CONFIG, "full_y", panel.y)
        end
    end

    local alpha = panel.anim
    y = pixel(y - (1 - alpha) * 8)
    panel.rect = interactive and { x, y, width, height } or nil
    local contentTop = y + padding + headerHeight

    Render.FilledRect(
        Vec2(x, y),
        Vec2(x + width, y + height),
        Color(16, 18, 20, math.floor(255 * alpha)),
        10
    )
    Render.Text(
        blinkPanelFont,
        12,
        title,
        Vec2(x + padding + 4, y + padding + pixel((headerHeight - 6 - titleSize.y) / 2)),
        Color(232, 232, 232, math.floor(255 * alpha))
    )
    Render.Text(
        blinkPanelFont,
        11,
        countText,
        Vec2(
            x + padding + 4 + titleSize.x + 8,
            y + padding + pixel((headerHeight - 6 - countSize.y) / 2)
        ),
        Color(141, 147, 153, math.floor(255 * alpha))
    )

    local hits = {}
    local hoverable = interactive and not panel.drag
    local seen = {}
    for index, name in ipairs(rows) do
        seen[name] = true
        local visibleIndex = index - panel.scroll
        if visibleIndex >= 1 and visibleIndex <= visibleRowCount then
            local state = panel.rows[name]
            local targetY = (visibleIndex - 1) * rowStep
            if not state then
                state = {
                    y = targetY,
                    anim = 0,
                    progress = 0,
                    start = panel.time + 0.03 + (visibleIndex - 1) * 0.02,
                }
                panel.rows[name] = state
            end
            if panel.time >= state.start then
                state.progress = math.min(1, state.progress + dt / 0.12)
                state.anim = easeOutCubic(state.progress)
            end

            state.y = state.y + (targetY - state.y) * (1 - math.exp(-dt * 22))
            local rowY = pixel(contentTop + state.y + (1 - state.anim) * 4)
            local rowAlpha = alpha * state.anim
            local rowX = x + padding

            local portraitX = rowX
            local portraitY = rowY + pixel((rowHeight - portraitSize) / 2)
            drawIcon(
                getPanelImage(
                    "hero_" .. name,
                    "panorama/images/heroes/icons/" .. name .. "_png.vtex_c"
                ),
                "hero|" .. name,
                portraitX,
                portraitY,
                portraitSize,
                portraitSize,
                isRowEnabled(name),
                rowAlpha,
                hoverable,
                dt
            )
            table.insert(hits, {
                portraitX, portraitY, portraitSize, portraitSize,
                kind = "row", name = name,
            })

            local separatorX = portraitX + portraitSize + 8
            Render.FilledRect(
                Vec2(separatorX, rowY + 8),
                Vec2(separatorX + 1, rowY + rowHeight - 8),
                Color(255, 255, 255, math.floor(36 * rowAlpha))
            )

            local iconX = separatorX + 1 + 8
            local iconY = rowY + pixel((rowHeight - iconSize) / 2)
            for _, key in ipairs(getRowItems(name)) do
                local keyWidth = key == "blink" and blinkWidth or iconSize
                local image = key == "blink" and blinkItemImage
                    or getPanelImage(
                        key,
                        "panorama/images/spellicons/" .. key .. "_png.vtex_c"
                    )
                drawIcon(
                    image,
                    name .. "|" .. key,
                    iconX,
                    iconY,
                    keyWidth,
                    iconSize,
                    not isThreatOff(name, key),
                    rowAlpha,
                    hoverable,
                    dt
                )
                table.insert(hits, {
                    iconX, iconY, keyWidth, iconSize,
                    kind = "icon", name = name, key = key,
                })
                iconX = iconX + keyWidth + iconGap
            end
        end
    end
    for name in pairs(panel.rows) do
        if not seen[name] then
            panel.rows[name] = nil
        end
    end

    if maxScroll > 0 and visibleRowCount > 0 then
        local trackTop = contentTop
        local trackHeight = visibleRowCount * rowStep - rowGap
        local trackX = x + width - 4
        local thumbHeight = math.max(
            12,
            trackHeight * visibleRowCount / #rows
        )
        local thumbTravel = trackHeight - thumbHeight
        local thumbY = trackTop
            + thumbTravel * panel.scroll / maxScroll
        Render.FilledRect(
            Vec2(trackX, trackTop),
            Vec2(trackX + 2, trackTop + trackHeight),
            Color(255, 255, 255, math.floor(36 * alpha)),
            1
        )
        Render.FilledRect(
            Vec2(trackX, thumbY),
            Vec2(trackX + 2, thumbY + thumbHeight),
            Color(190, 196, 202, math.floor(170 * alpha)),
            1
        )
    end

    if not pressed or panel.drag then
        return
    end
    for _, hit in ipairs(hits) do
        if Input.IsCursorInRect(hit[1], hit[2], hit[3], hit[4]) then
            if hit.kind == "row" then
                setRowEnabled(hit.name, not isRowEnabled(hit.name))
            else
                setThreatOff(hit.name, hit.key, not isThreatOff(hit.name, hit.key))
            end
            return
        end
    end
    if Input.IsCursorInRect(x, y, width, height) then
        panel.drag = true
        panel.dragX = cursorX - x
        panel.dragY = cursorY - y
    end
end

return {
    OnEntityHurt = function(data)
        if not data or not data.source or not data.target then
            return
        end

        local hero = Heroes.GetLocal()
        if isLocalTinker(hero)
            and Entity.GetIndex(data.target) == Entity.GetIndex(hero)
        then
            handleMeleeAttack(data.source, hero, true)
        end
    end,

    OnPrepareUnitOrders = function(data)
        handleThreat(data)
        return true
    end,

    OnKeyEvent = function(data)
        if Input.IsInputCaptured() or Input.IsPopupOpen() then
            panel.pendingClick = false
            panel.mouseDown = false
            panel.drag = false
            return true
        end

        local key = data.key
        local rect = panel.rect
        local over = rect
            and Input.IsCursorInRect(rect[1], rect[2], rect[3], rect[4])
        if over
            and data.event == Enum.EKeyEvent.EKeyEvent_SCROLL_DOWN
        then
            panel.scroll = panel.scroll + 1
            return false
        end
        if over
            and data.event == Enum.EKeyEvent.EKeyEvent_SCROLL_UP
        then
            panel.scroll = math.max(0, panel.scroll - 1)
            return false
        end
        if key ~= Enum.ButtonCode.KEY_MOUSE1
            and key ~= Enum.ButtonCode.KEY_MOUSE2
        then
            return true
        end

        if data.event == Enum.EKeyEvent.EKeyEvent_KEY_DOWN and over then
            if key == Enum.ButtonCode.KEY_MOUSE1 and not panel.mouseDown then
                panel.pendingClick = true
                panel.mouseDown = true
            end
            return false
        end
        if data.event == Enum.EKeyEvent.EKeyEvent_KEY_UP
            and key == Enum.ButtonCode.KEY_MOUSE1
            and panel.mouseDown
        then
            panel.mouseDown = false
            return false
        end
        return true
    end,

    OnUpdate = function()
        local currentTime = now()
        beginRuntimeFrame(currentTime)
        if not enabled:Get() then
            blinkPanelOpen = false
        elseif blinkPanelKey:IsPressed()
            and not Input.IsInputCaptured()
            and not Input.IsPopupOpen()
        then
            blinkPanelOpen = not blinkPanelOpen
        end
        if enabled:Get() then
            local hero = Heroes.GetLocal()
            if isLocalTinker(hero) then
                scanAllThreats(hero)
            end
        end
    end,

    OnDraw = function()
        local ok, err = pcall(drawDodgePanel)
        if not ok then
            panel.rect = nil
            panel.pendingClick = false
            panel.mouseDown = false
            panel.drag = false

            local errorTime = now()
            if errorTime - panel.lastDrawErrorTime >= 5 then
                logger:error("Dodge panel drawing failed:", err)
                panel.lastDrawErrorTime = errorTime
            end
        end
    end,

}
