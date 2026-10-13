local script = {}

local HERO = "npc_dota_hero_arc_warden"
local WIND_WAKER = "item_wind_waker"
local EULS = "item_cyclone"
local GLIMMER = "item_glimmer_cape"
local CRIMSON = "item_crimson_guard"
local HURRICANE_PIKE = "item_hurricane_pike"

local CAST_RANGE = 600
local CAST_RANGE_SAFE = 500

local AutoSafeMe = Menu.Create("Heroes", "Hero List", "Arc Warden", "Main Settings",
    "Utility"):Switch(
    "Клон, спасай меня!", false, "panorama/images/heroes/icons/npc_dota_hero_arc_warden_png.vtex_c")

local AutoSafeMeGear = AutoSafeMe:Gear("Settings")

local AutoPike = AutoSafeMeGear:Switch(
    "Авто Hurricane Pike", false, "panorama/images/items/hurricane_pike_png.vtex_c")

local PikeDangerRadius = AutoSafeMeGear:Slider("Радиус отталкивания", 100, 800, 400, "%d")
local PikeCloneRadius = AutoSafeMeGear:Slider("Радиус клона", 100, 800, 350, "%d")

AutoPike:ToolTip("Использует Hurricane Pike на врага, если он подошёл слишком близко. Если клон рядом — клон отталкивает героя.")
PikeDangerRadius:ToolTip("Если вражеский герой ближе этого расстояния — срабатывает отталкивание пикой.")
PikeCloneRadius:ToolTip("Радиус, в котором клон считается 'рядом' для отталкивания героя.")

local state = {
    lastCastTime = 0,
    lastMoveTime = 0,
    lastStatus = "Ожидание",
    lastBushwhackTime = 0,
    lastStunParticleTime = 0,
    lastBlinkTime = 0,
    lastFrostbiteParticleTime = 0,
    lastChaosBoltParticleTime = 0,
    lastBrambleMazeParticleTime = 0,
    lastDragonTailParticleTime = 0,
    lastEchoStompParticleTime = 0,
    lastPikeTime = 0,
    lastTurnTime = 0,
}

local function findClone(player, hero)
    local playerId = Player.GetPlayerID(player)
    if not playerId then return nil end
    local units = NPCs.GetAll() or {}
    for i = 1, #units do
        local unit = units[i]
        if unit and unit ~= hero and Entity.IsAlive(unit)
            and not Entity.IsDormant(unit) then
            local ok, hasMod = pcall(NPC.HasModifier, unit, "modifier_arc_warden_tempest_double")
            if ok and hasMod and Entity.IsControllableByPlayer(unit, playerId) then
                return unit
            end
        end
    end
    for i = 1, #units do
        local unit = units[i]
        if unit and unit ~= hero and Entity.IsAlive(unit)
            and not Entity.IsDormant(unit) and not NPC.IsHero(unit) then
            local name = NPC.GetUnitName(unit) or ""
            if name == HERO and Entity.IsControllableByPlayer(unit, playerId) then
                return unit
            end
        end
    end
    return nil
end

local function findClosestEnemyHero(hero, maxDist)
    if not hero then return nil end
    local team = Entity.GetTeamNum(hero)
    local heroPos = Entity.GetAbsOrigin(hero)
    if not heroPos then return nil end

    local heroes = Heroes.GetAll() or {}
    local best, bestDist = nil, maxDist or 999999

    for i = 1, #heroes do
        local h = heroes[i]
        if h and h ~= hero and Entity.GetTeamNum(h) ~= team
            and Entity.IsAlive(h) and not NPC.IsIllusion(h) then
            local hPos = Entity.GetAbsOrigin(h)
            if hPos then
                local d = heroPos:Distance2D(hPos)
                if d < bestDist then
                    bestDist = d
                    best = h
                end
            end
        end
    end
    return best, bestDist
end

local function findEnemyAxe(hero)
    if not hero then return nil end
    local team = Entity.GetTeamNum(hero)
    local heroes = Heroes.GetAll() or {}
    for i = 1, #heroes do
        local h = heroes[i]
        if h and Entity.GetTeamNum(h) ~= team and Entity.IsAlive(h) and not NPC.IsIllusion(h) then
            local name = NPC.GetUnitName(h) or ""
            if name == "npc_dota_hero_axe" then
                return h
            end
        end
    end
    return nil
end

local function isProjectileFlyingToHero(hero, keyword)
    if not hero or not keyword then return false end
    if not GetIncomingTrackingProjectiles then return false end

    local ok, projectiles = pcall(GetIncomingTrackingProjectiles, hero)
    if not ok or not projectiles or type(projectiles) ~= "table" then
        return false
    end

    for _, proj in pairs(projectiles) do
        if proj and proj.ability then
            local abilityName = Ability.GetName(proj.ability) or ""
            abilityName = abilityName:lower()
            if abilityName:find(keyword:lower(), 1, true) then
                return true
            end
        end
    end
    return false
end

local function isConcoctionFlyingToHero(hero)
    return isProjectileFlyingToHero(hero, "unstable_concoction")
end

local function isFrostbiteFlyingToHero(hero)
    return isProjectileFlyingToHero(hero, "frostbite")
end

local function isChaosBoltFlyingToHero(hero)
    return isProjectileFlyingToHero(hero, "chaos_bolt")
end

local function isDragonTailFlyingToHero(hero)
    return isProjectileFlyingToHero(hero, "dragon_tail")
end

local function getItemNameSafe(item)
    if not item then return nil end
    if Ability.GetName then
        local ok, n = pcall(Ability.GetName, item)
        if ok and n and n ~= "" then return n end
    end
    if Entity.GetUnitName then
        local ok, n = pcall(Entity.GetUnitName, item)
        if ok and n and n ~= "" then return n end
    end
    if NPC.GetUnitName then
        local ok, n = pcall(NPC.GetUnitName, item)
        if ok and n and n ~= "" then return n end
    end
    if Entity.GetClassName then
        local ok, n = pcall(Entity.GetClassName, item)
        if ok and n and n ~= "" then return n end
    end
    return nil
end

local function matchItemName(name, target)
    if not name or not target then return false end
    name = name:lower()
    target = target:lower()
    if name == target then return true end
    if name:find(target, 1, true) then return true end
    return false
end

local function getItemByName(unit, itemName)
    if not unit or not itemName then return nil end
    local item = NPC.GetItem(unit, itemName, true)
    if item then return item end
    for slot = 0, 8 do
        local it = NPC.GetItemByIndex(unit, slot)
        if it then
            local n = getItemNameSafe(it)
            if matchItemName(n, itemName) then return it end
        end
    end
    return nil
end

local function getWindWaker(clone)
    return getItemByName(clone, WIND_WAKER)
end

local function getEuls(clone)
    return getItemByName(clone, EULS)
end

local function getGlimmer(clone)
    return getItemByName(clone, GLIMMER)
end

local function getCrimson(clone)
    return getItemByName(clone, CRIMSON)
end

local function getHurricanePike(unit)
    return getItemByName(unit, HURRICANE_PIKE)
end

local function isReady(item)
    if not item then return false end
    if Ability.CanBeExecuted and Ability.CanBeExecuted(item) ~= -1 then
        return false
    end
    if Ability.GetCooldownTimeRemaining then
        local ok, cd = pcall(Ability.GetCooldownTimeRemaining, item)
        if ok and (cd or 0) > 0.1 then return false end
    end
    return true
end

local function hasAnyModifier(hero, mods)
    if not hero then return false end
    for _, name in ipairs(mods) do
        local ok, has = pcall(NPC.HasModifier, hero, name)
        if ok and has then return true end
    end
    return false
end

local function isHeroInBlackHole(hero)
    return hasAnyModifier(hero, {
        "modifier_enigma_black_hole_pull",
        "modifier_enigma_black_hole_pull_scepter",
        "modifier_enigma_black_hole_pull_aura",
    })
end

local function isHeroInBushwhack(hero)
    return hasAnyModifier(hero, {
        "modifier_hoodwink_bushwhack",
        "modifier_hoodwink_bushwhack_tracker",
        "modifier_hoodwink_bushwhack_stun",
        "modifier_hoodwink_bushwhack_slow",
        "modifier_hoodwink_bushwhack_root",
        "modifier_hoodwink_sharpshooter_stun",
        "modifier_stunned",
        "modifier_bashed",
        "modifier_rooted",
        "modifier_rooted_root",
    })
end

local function isHeroInFrostbite(hero)
    return hasAnyModifier(hero, {
        "modifier_crystal_maiden_frostbite",
        "modifier_crystal_maiden_frostbite_freeze",
        "modifier_crystal_maiden_frostbite_root",
    })
end

local function isHeroInBerserkersCall(hero)
    return hasAnyModifier(hero, {
        "modifier_axe_berserkers_call",
        "modifier_axe_berserkers_call_aura",
    })
end

local function isAxeCastingCall(axe)
    return hasAnyModifier(axe, {
        "modifier_axe_berserkers_call",
    })
end

local function isHeroInChaosBolt(hero)
    return hasAnyModifier(hero, {
        "modifier_chaos_knight_chaos_bolt",
        "modifier_stunned",
        "modifier_bashed",
    })
end

local function isHeroInBrambleMaze(hero)
    return hasAnyModifier(hero, {
        "modifier_dark_willow_bramble_maze",
        "modifier_dark_willow_bramble_maze_root",
        "modifier_rooted",
        "modifier_rooted_root",
    })
end

local function isHeroInDragonTail(hero)
    return hasAnyModifier(hero, {
        "modifier_dragon_knight_dragon_tail",
        "modifier_stunned",
        "modifier_bashed",
    })
end

local function isHeroInEchoStomp(hero)
    return hasAnyModifier(hero, {
        "modifier_elder_titan_echo_stomp",
        "modifier_elder_titan_echo_stomp_sleep",
        "modifier_sleep",
    })
end

local function moveCloneToHero(player, clone, hero, now)
    if now - state.lastMoveTime < 0.2 then return end
    local heroPos = Entity.GetAbsOrigin(hero)
    if not heroPos then return end
    Player.PrepareUnitOrders(player,
        Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION,
        nil, heroPos, nil,
        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
        clone, false, false, false, true)
    state.lastMoveTime = now
end

local function castItemOnTarget(player, caster, target, item)
    if not item or not target then return false end
    Player.PrepareUnitOrders(player,
        Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TARGET,
        target, nil, item,
        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
        caster, false, false, false, true)
    return true
end

local function tryApplyItem(player, clone, hero, item, now)
    if not item or not isReady(item) then return false end
    local clonePos = Entity.GetAbsOrigin(clone)
    local heroPos = Entity.GetAbsOrigin(hero)
    if not clonePos or not heroPos then return false end

    local dist = clonePos:Distance2D(heroPos)
    if dist > CAST_RANGE_SAFE then
        moveCloneToHero(player, clone, hero, now)
        return true
    else
        if castItemOnTarget(player, clone, hero, item) then
            state.lastCastTime = now
            return true
        end
    end
    return false
end

local function tryApplyDefensiveSet(player, clone, hero, now)
    local glimmer = getGlimmer(clone)
    if glimmer and isReady(glimmer) then
        if tryApplyItem(player, clone, hero, glimmer, now) then return true end
    end

    local euls = getEuls(clone)
    if euls and isReady(euls) then
        if tryApplyItem(player, clone, hero, euls, now) then return true end
    end

    local windwaker = getWindWaker(clone)
    if windwaker and isReady(windwaker) then
        if tryApplyItem(player, clone, hero, windwaker, now) then return true end
    end

    return false
end

local function turnHeroAwayFromEnemy(player, hero, enemy, now)
    if not hero or not enemy then return end
    if now - state.lastTurnTime < 0.15 then return end

    local heroPos = Entity.GetAbsOrigin(hero)
    local enemyPos = Entity.GetAbsOrigin(enemy)
    if not heroPos or not enemyPos then return end

    local dx = heroPos.x - enemyPos.x
    local dy = heroPos.y - enemyPos.y
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 0.001 then return end

    local nx = dx / len
    local ny = dy / len
    local awayPos = Vector(heroPos.x + nx * 200, heroPos.y + ny * 200, heroPos.z)

    state.lastTurnTime = now
    Player.PrepareUnitOrders(player,
        Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION,
        nil, awayPos, nil,
        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
        hero, false, false, false, true)
end

local function tryHurricanePike(player, hero, clone, now)
    if not AutoPike:Get() then return false end
    if now - state.lastPikeTime < 0.5 then return false end

    local dangerRadius = PikeDangerRadius:Get()
    local cloneRadius = PikeCloneRadius:Get()

    local enemy, dist = findClosestEnemyHero(hero, dangerRadius)
    if not enemy then return false end

    local cloneNear = false
    if clone then
        local heroPos = Entity.GetAbsOrigin(hero)
        local clonePos = Entity.GetAbsOrigin(clone)
        if heroPos and clonePos then
            cloneNear = heroPos:Distance2D(clonePos) <= cloneRadius
        end
    end

    if cloneNear then
        local clonePike = getHurricanePike(clone)
        if clonePike and isReady(clonePike) then
            turnHeroAwayFromEnemy(player, hero, enemy, now)
            if castItemOnTarget(player, clone, hero, clonePike) then
                state.lastPikeTime = now
                return true
            end
        end
    end

    local heroPike = getHurricanePike(hero)
    if heroPike and isReady(heroPike) then
        if castItemOnTarget(player, hero, enemy, heroPike) then
            state.lastPikeTime = now
            return true
        end
    end

    return false
end

local function update()
    if not AutoSafeMe:Get() then return end

    local hero = Heroes.GetLocal()
    if not hero or NPC.GetUnitName(hero) ~= HERO then return end
    local player = Players.GetLocal()
    if not player then return end

    local now = GameRules.GetGameTime()

    local clone = findClone(player, hero)

    if AutoPike:Get() then
        if tryHurricanePike(player, hero, clone, now) then return end
    end

    if now - state.lastCastTime < 0.3 then return end
    if not clone then return end

    local frostbiteParticleTime = state.lastFrostbiteParticleTime or 0
    local frostbiteRecent = (now - frostbiteParticleTime) < 1.0
    if isFrostbiteFlyingToHero(hero) or frostbiteRecent or isHeroInFrostbite(hero) then
        if tryApplyDefensiveSet(player, clone, hero, now) then return end
        return
    end

    local chaosBoltParticleTime = state.lastChaosBoltParticleTime or 0
    local chaosBoltRecent = (now - chaosBoltParticleTime) < 1.0
    if isChaosBoltFlyingToHero(hero) or chaosBoltRecent or isHeroInChaosBolt(hero) then
        if tryApplyDefensiveSet(player, clone, hero, now) then return end
        return
    end

    local brambleParticleTime = state.lastBrambleMazeParticleTime or 0
    local brambleRecent = (now - brambleParticleTime) < 1.0
    if brambleRecent or isHeroInBrambleMaze(hero) then
        if tryApplyDefensiveSet(player, clone, hero, now) then return end
        return
    end

    local dragonTailParticleTime = state.lastDragonTailParticleTime or 0
    local dragonTailRecent = (now - dragonTailParticleTime) < 1.0
    if isDragonTailFlyingToHero(hero) or dragonTailRecent or isHeroInDragonTail(hero) then
        if tryApplyDefensiveSet(player, clone, hero, now) then return end
        return
    end

    local echoStompParticleTime = state.lastEchoStompParticleTime or 0
    local echoStompRecent = (now - echoStompParticleTime) < 1.0
    if echoStompRecent or isHeroInEchoStomp(hero) then
        if tryApplyDefensiveSet(player, clone, hero, now) then return end
        return
    end

    local axe = findEnemyAxe(hero)
    if axe then
        local axeCasting = isAxeCastingCall(axe)
        local heroCalled = isHeroInBerserkersCall(hero)
        local blinkRecently = (now - (state.lastBlinkTime or 0)) < 1.0
        local axeNear = Entity.GetAbsOrigin(hero):Distance2D(Entity.GetAbsOrigin(axe)) < 700

        if axeCasting or heroCalled or (blinkRecently and axeNear) then
            local windwaker = getWindWaker(clone)
            if windwaker and isReady(windwaker) then
                if tryApplyItem(player, clone, hero, windwaker, now) then return end
            end

            local euls = getEuls(clone)
            if euls and isReady(euls) then
                if tryApplyItem(player, clone, hero, euls, now) then return end
            end
            return
        end
    end

    if isConcoctionFlyingToHero(hero) then
        local glimmer = getGlimmer(clone)
        if glimmer and isReady(glimmer) then
            if tryApplyItem(player, clone, hero, glimmer, now) then return end
        end

        local crimson = getCrimson(clone)
        if crimson and isReady(crimson) then
            if tryApplyItem(player, clone, hero, crimson, now) then return end
        end
        return
    end

    local bushwhackTime = state.lastBushwhackTime or 0
    local stunParticleTime = state.lastStunParticleTime or 0
    local underStun = (now - bushwhackTime) < 3.0
        or (now - stunParticleTime) < 3.0
        or isHeroInBushwhack(hero)

    if underStun then
        if tryApplyDefensiveSet(player, clone, hero, now) then return end

        local crimson = getCrimson(clone)
        if crimson and isReady(crimson) then
            if tryApplyItem(player, clone, hero, crimson, now) then return end
        end
        return
    end

    if isHeroInBlackHole(hero) then
        if tryApplyDefensiveSet(player, clone, hero, now) then return end
        return
    end
end

function script.OnParticleCreate(data)
    if not AutoSafeMe:Get() then return end
    if not data then return end

    local name = (data.name or ""):lower()

    if name:find("hoodwink_bushwhack", 1, true)
        or name:find("bushwhack_target", 1, true) then
        state.lastBushwhackTime = GameRules.GetGameTime()
    end

    if name:find("frostbite", 1, true)
        or name:find("crystal_maiden_frostbite", 1, true) then
        state.lastFrostbiteParticleTime = GameRules.GetGameTime()
    end

    if name:find("chaos_bolt", 1, true)
        or name:find("chaos_knight_chaos_bolt", 1, true) then
        state.lastChaosBoltParticleTime = GameRules.GetGameTime()
    end

    if name:find("bramble_maze", 1, true)
        or name:find("dark_willow_bramble", 1, true) then
        state.lastBrambleMazeParticleTime = GameRules.GetGameTime()
    end

    if name:find("dragon_tail", 1, true)
        or name:find("dragon_knight_dragon_tail", 1, true) then
        state.lastDragonTailParticleTime = GameRules.GetGameTime()
    end

    if name:find("echo_stomp", 1, true)
        or name:find("elder_titan_echo_stomp", 1, true) then
        state.lastEchoStompParticleTime = GameRules.GetGameTime()
    end

    if name:find("generic_stun", 1, true)
        or (name:find("stun", 1, true) and not name:find("stun_immune", 1, true)) then
        state.lastStunParticleTime = GameRules.GetGameTime()
    end

    if name:find("blink_dagger_start", 1, true)
        or name:find("blink_dagger_end", 1, true)
        or name:find("blink_start", 1, true)
        or name:find("blink_end", 1, true) then
        state.lastBlinkTime = GameRules.GetGameTime()
    end
end

function script.OnUpdate()
    update()
end

function script.OnGameEnd()
    state.lastCastTime = 0
    state.lastMoveTime = 0
    state.lastStatus = "Ожидание"
    state.lastBushwhackTime = 0
    state.lastStunParticleTime = 0
    state.lastBlinkTime = 0
    state.lastFrostbiteParticleTime = 0
    state.lastChaosBoltParticleTime = 0
    state.lastBrambleMazeParticleTime = 0
    state.lastDragonTailParticleTime = 0
    state.lastEchoStompParticleTime = 0
    state.lastPikeTime = 0
    state.lastTurnTime = 0
end

return script