
local script = {}

local state = {}
local utilities = {}
local ui = {}

state.orderStamps = {}
state.mineTasks = {}
state.scanNPCs = { list = {}, at = -100 }
state.scanEntities = { list = {}, at = -100 }
state.roster = { at = -100, any = false, list = {} }
state.sparks = {}
state.sparkKeys = {}
state.sparkIndices = {}
state.escortUntil = 0
state.arcChaser = nil
state.arcLastCenter = nil
state.arcBusy = {}

state.wraithSeenAt = nil

utilities.now = function()
    local time = GameRules.GetGameTime()
    if time then return time end
    local clock = GlobalVars.GetCurTime()
    if clock then return clock end
    return os.clock()
end

utilities.clamp = function(value, minimum, maximum)
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

utilities.unitName = function(unit)
    if not unit or not Entity.IsEntity(unit) or not Entity.IsNPC(unit) then return "" end
    if (NPC.GetUnitNameIndex(unit) or 0) <= 0 then return "" end
    return string.lower(NPC.GetUnitName(unit) or "")
end

utilities.matches = function(text, patterns)
    for index = 1, #patterns do
        if string.find(text, patterns[index], 1, true) then return true end
    end
    return false
end

utilities.point = function(unit)
    if not unit or not Entity.IsEntity(unit) then return nil end
    return Entity.GetAbsOrigin(unit)
end

utilities.distance = function(first, second)
    local a = utilities.point(first)
    local b = utilities.point(second)
    if not a or not b then return 999999 end
    local dx = a.x - b.x
    local dy = a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

utilities.index = function(unit)
    return Entity.GetIndex(unit) or -1
end

utilities.alive = function(unit)
    return Entity.IsAlive(unit) == true
end

utilities.friendly = function(first, second)
    return Entity.IsSameTeam(first, second) == true
end

utilities.healthPercent = function(unit)
    local health = Entity.GetHealth(unit) or 0
    local maximum = Entity.GetMaxHealth(unit) or 0
    if maximum <= 0 then return 100 end
    return (health / maximum) * 100
end

utilities.invisible = function(unit)
    if not unit or not Entity.IsNPC(unit) then return false end
    return NPC.HasState(unit, Enum.ModifierState.MODIFIER_STATE_INVISIBLE)
end

utilities.npcs = function()
    local time = utilities.now()
    if time - state.scanNPCs.at < 0.1 then return state.scanNPCs.list end
    state.scanNPCs.at = time
    state.scanNPCs.list = NPCs.GetAll() or {}
    return state.scanNPCs.list
end

utilities.entities = function()
    local time = utilities.now()
    if time - state.scanEntities.at < 0.1 then return state.scanEntities.list end
    state.scanEntities.at = time
    state.scanEntities.list = Entities.GetAll() or {}
    return state.scanEntities.list
end

utilities.rosterOf = function(hero, force)
    local time = utilities.now()
    if not force and time - state.roster.at < 0.5 then return state.roster end
    state.roster.at = time
    state.roster.ponosnoy = nil
    state.roster.tehniksnayba = nil
    state.roster.jopaarcwarden = nil
    state.roster.list = {}
    local heroes = Heroes.GetAll() or {}
    for index = 1, #heroes do
        local enemy = heroes[index]
        if enemy and utilities.alive(enemy) and not utilities.friendly(enemy, hero) then
            local name = utilities.unitName(enemy)
            if string.find(name, "hero_bane", 1, true) then state.roster.ponosnoy = enemy end
            if string.find(name, "hero_techies", 1, true) then state.roster.tehniksnayba = enemy end
            if string.find(name, "hero_arc_warden", 1, true) then state.roster.jopaarcwarden = enemy end
            state.roster.list[#state.roster.list + 1] = name
        end
    end
    state.roster.any = (state.roster.ponosnoy ~= nil) or (state.roster.tehniksnayba ~= nil) or (state.roster.jopaarcwarden ~= nil)
    return state.roster
end

utilities.pruneStamps = function(now)
    local count = 0
    for _ in pairs(state.orderStamps) do count = count + 1 end
    if count < 64 then return end
    for key, stamp in pairs(state.orderStamps) do
        if now - stamp.at > 5 then state.orderStamps[key] = nil end
    end
end

utilities.collect = function(hero, patterns, radius, includeDormant, enemyOnly, anchors)
    local found = {}
    local heroPoint = utilities.point(hero)
    if not heroPoint then return found end
    local seen = {}
    local points = {}
    if anchors then
        for index = 1, #anchors do
            local anchorPoint = utilities.point(anchors[index])
            if anchorPoint then points[#points + 1] = anchorPoint end
        end
    end
    if #points == 0 then points[1] = heroPoint end
    local lists = { utilities.npcs() }
    if includeDormant then lists[#lists + 1] = utilities.entities() end
    for listIndex = 1, #lists do
        local list = lists[listIndex]
        for index = 1, #list do
            local unit = list[index]
            if not unit or not Entity.IsEntity(unit) or Entity.IsNPC(unit) ~= true then
                unit = nil
            end
            if unit then
                local name = utilities.unitName(unit)
                if name ~= "" and utilities.matches(name, patterns) then
                    local key = utilities.index(unit)
                    if not seen[key] and utilities.alive(unit) then
                        if not enemyOnly or not utilities.friendly(unit, hero) then
                            local point = utilities.point(unit)
                            if point then
                                local distance = nil
                                for anchorIndex = 1, #points do
                                    local dx = point.x - points[anchorIndex].x
                                    local dy = point.y - points[anchorIndex].y
                                    local current = math.sqrt(dx * dx + dy * dy)
                                    if not distance or current < distance then distance = current end
                                end
                                if distance and distance <= radius then
                                    seen[key] = true
                                    found[#found + 1] = {
                                        unit = unit,
                                        index = key,
                                        name = name,
                                        distance = distance,
                                        point = point,
                                        dormant = Entity.IsDormant(unit) == true
                                    }
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    table.sort(found, function(first, second) return first.distance < second.distance end)
    return found
end

utilities.mines = function(hero, radius, includeDormant, extra)
    local patterns = { "techies_mines", "techies_land_mine", "proximity_mine" }
    local anchors = { hero }
    if extra then
        for index = 1, #extra do anchors[#anchors + 1] = extra[index] end
    end
    local found = utilities.collect(hero, patterns, radius, includeDormant, true, anchors)
    local visible = {}
    for index = 1, #found do
        if not found[index].dormant then visible[#visible + 1] = found[index] end
    end
    for index = 1, #visible do
        visible[index].threat = utilities.distance(visible[index].unit, hero)
    end
    table.sort(visible, function(first, second) return first.threat < second.threat end)
    return visible
end

utilities.wraiths = function(hero, radius)
    local found = {}
    local heroPoint = utilities.point(hero)
    if not heroPoint then return found end
    local now = utilities.now()
    for key, entry in pairs(state.sparkKeys) do
        if now - entry.at > 4 then state.sparkKeys[key] = nil end
    end
    for key, entry in pairs(state.sparkKeys) do
        local point = entry.point
        if point and point.x and point.y then
            local dx = point.x - heroPoint.x
            local dy = point.y - heroPoint.y
            local distance = math.sqrt(dx * dx + dy * dy)
            if distance <= radius then
                found[#found + 1] = { key = key, name = entry.name, point = point, position = point, distance = distance, radius = 375, fow_radius = 375 }
            end
        end
    end
    table.sort(found, function(first, second) return first.distance < second.distance end)
    state.sparks = found
    return found
end

utilities.catchSpark = function(data)
    if not data then return end
    local name = string.lower(tostring(data.fullName or data.name or ""))
    if name == "" then return end
    if not string.find(name, "arc_warden_wraith", 1, true) then return end
    if string.find(name, "_cast", 1, true) then return end
    local key = tostring(data.index or "")
    if key == "" then return end
    state.sparkIndices[key] = { at = utilities.now(), name = name }
end

utilities.trackSpark = function(data)
    if not data or not data.index then return end
    local key = tostring(data.index)
    if not state.sparkIndices[key] then return end
    if (data.controlPoint or 0) ~= 0 then return end
    local point = data.position
    if point and point.x and point.y then
        state.sparkKeys[key] = { point = point, at = utilities.now(), name = state.sparkIndices[key].name, radius = 375 }
    end
end

utilities.ownedByLocal = function(unit, hero)
    local owner = Entity.GetOwner(unit)
    if not owner then owner = Entity.RecursiveGetOwner(unit) end
    if not owner then return false end
    local ownerIndex = utilities.index(owner)
    if ownerIndex == utilities.index(hero) then return true end
    local heroOwner = Entity.RecursiveGetOwner(hero)
    if heroOwner and utilities.index(heroOwner) == ownerIndex then return true end
    return false
end

utilities.forges = function(hero)
    local found = {}
    local seen = {}
    local lists = { utilities.npcs(), utilities.entities() }
    for listIndex = 1, #lists do
        local list = lists[listIndex]
        for index = 1, #list do
            local unit = list[index]
            if unit and Entity.IsEntity(unit) and Entity.IsNPC(unit) == true then
                local name = utilities.unitName(unit)
                if name ~= "" and utilities.matches(name, { "forged_spirit", "forge_spirit" }) then
                    local key = utilities.index(unit)
                    if not seen[key] and utilities.alive(unit) then
                        if utilities.ownedByLocal(unit, hero) and NPC.IsIllusion(unit) ~= true then
                            seen[key] = true
                            found[#found + 1] = unit
                        end
                    end
                end
            end
        end
    end
    table.sort(found, function(first, second) return utilities.index(first) < utilities.index(second) end)
    return found
end

utilities.sleepAge = function(unit)
    if not unit then return nil end
    local modifiers = NPC.GetModifiers(unit)
    if not modifiers then return nil end
    local time = utilities.now()
    for index = 1, #modifiers do
        local modifier = modifiers[index]
        local name = Modifier.GetName(modifier)
        if name then
            name = string.lower(name)
            if string.find(name, "nightmare", 1, true) and not string.find(name, "_end", 1, true) then
                local created = Modifier.GetCreationTime(modifier)
                if created then return time - created, name end
            end
        end
    end
    return nil
end

utilities.abilityInSlots = function(hero, patterns, lowest, highest)
    for index = lowest, highest do
        local ability = NPC.GetAbilityByIndex(hero, index)
        if ability then
            local name = string.lower(Ability.GetName(ability) or "")
            if name ~= "" and utilities.matches(name, patterns) then
                if Ability.IsHidden(ability) ~= true then return ability end
            end
        end
    end
    return nil
end

utilities.findAbility = function(hero, patterns)
    for index = 1, #patterns do
        local ability = NPC.GetAbility(hero, patterns[index])
        if ability then
            local name = Ability.GetName(ability)
            if name and name ~= "" and Ability.IsHidden(ability) ~= true then return ability end
        end
    end
    return utilities.abilityInSlots(hero, patterns, 0, 31)
end

utilities.forgeInSlots = function(hero)
    local time = utilities.now()
    local cached = state.forgeCache
    if cached and time - cached.at < 0.1 then
        if not cached.ability then return nil end
        if Entity.IsAbility(cached.ability) then
            local name = string.lower(Ability.GetName(cached.ability) or "")
            if string.find(name, "forge_spirit", 1, true) then return cached.ability end
        end
    end
    local ability = utilities.abilityInSlots(hero, { "forge_spirit" }, 3, 4)
    state.forgeCache = { ability = ability, at = time }
    return ability
end

utilities.orbs = function(hero)
    local heroIndex = utilities.index(hero)
    local cached = state.orbs
    if cached and cached.heroIndex == heroIndex and cached.invoke and Entity.IsAbility(cached.invoke) then
        return cached
    end
    cached = {
        heroIndex = heroIndex,
        invoke = utilities.findAbility(hero, { "invoker_invoke" }),
        quas = utilities.findAbility(hero, { "invoker_quas" }),
        wex = utilities.findAbility(hero, { "invoker_wex" }),
        exort = utilities.findAbility(hero, { "invoker_exort" })
    }
    state.orbs = cached
    return cached
end

utilities.level = function(ability)
    return Ability.GetLevel(ability) or 0
end

utilities.cooldown = function(ability)
    return Ability.GetCooldown(ability) or 0
end

utilities.ready = function(ability)
    return Ability.IsReady(ability) == true
end

utilities.usable = function(ability)
    if not ability then return false end
    if utilities.level(ability) <= 0 then return false end
    if Ability.IsActivated(ability) == false then return false end
    return true
end

utilities.forgeCooldown = function(hero)
    local ability = utilities.forgeInSlots(hero)
    if ability then return utilities.cooldown(ability) end
    local remaining = (state.forgeReadyAt or 0) - utilities.now()
    if remaining < 0 then remaining = 0 end
    return remaining
end

utilities.summon = function(hero)
    local time = utilities.now()
    if #utilities.forges(hero) >= 2 then return false end
    local forge = utilities.forgeInSlots(hero)
    if forge then
        if utilities.ready(forge) then
            Ability.CastNoTarget(forge, false, false, true, "forge_helper")
            state.forgeReadyAt = time + (Ability.GetCooldownLength(forge) or 30)
            return true
        end
        return false
    end
    if state.sequence then return false end
    if (state.forgeReadyAt or 0) > time then
        return false
    end
    local orbs = utilities.orbs(hero)
    if not orbs.invoke then return false end
    if not utilities.usable(orbs.exort) or not utilities.usable(orbs.quas) then
        return false
    end
    if not utilities.ready(orbs.invoke) then return false end
    if (NPC.GetMana(hero) or 0) < 140 then
        return false
    end
    state.sequence = {
        index = 1,
        nextAt = time,
        startedAt = time,
        steps = { orbs.exort, orbs.exort, orbs.quas, orbs.invoke, "cast" }
    }
    return true
end

utilities.updateSequence = function(hero, now)
    local sequence = state.sequence
    if not sequence then return end
    if now - sequence.startedAt > 1.6 then
        state.sequence = nil
        return
    end
    if now < sequence.nextAt then return end
    local orbs = utilities.orbs(hero)
    local step = sequence.steps[sequence.index]
    if step == nil then
        state.sequence = nil
        return
    end
    if step == "cast" then
        local forge = utilities.forgeInSlots(hero)
        if forge and utilities.ready(forge) then
            Ability.CastNoTarget(forge, false, false, true, "forge_helper")
            state.forgeReadyAt = now + (Ability.GetCooldownLength(forge) or 30)
            state.sequence = nil
            return
        end
        sequence.nextAt = now + 0.05
        return
    end
    local isInvoke = (step == orbs.invoke)
    if isInvoke and utilities.cooldown(step) > 0 then
        state.sequence = nil
        return
    end
    if utilities.ready(step) and (isInvoke or utilities.usable(step)) then
        Ability.CastNoTarget(step, false, false, true, "forge_helper")
        sequence.index = sequence.index + 1
        if isInvoke then
            sequence.nextAt = now + 0.12
        else
            sequence.nextAt = now + 0.04
        end
        return
    end
    sequence.nextAt = now + 0.02
end

utilities.keepAttack = function(forge, target, key, now, inRange)
    local stamp = state.orderStamps[key]
    local stampTime = stamp and stamp.at or -100
    local interval = 0.2
    if inRange and NPC.IsAttacking(forge) == true then interval = 0.75 end
    if now - stampTime < interval then return end
    Player.PrepareUnitOrders(state.player, Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET, target, nil, nil,
        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, forge, false, false, false, false, "forge_helper", false)
    state.orderStamps[key] = { at = now }
end

utilities.keepMove = function(forge, target, key, now, interval)
    local stamp = state.orderStamps[key]
    if stamp and now - stamp.at < interval then return end
    local forgePoint = utilities.point(forge)
    if forgePoint and target.x and forgePoint.x then
        local dx = target.x - forgePoint.x
        local dy = target.y - forgePoint.y
        if math.sqrt(dx * dx + dy * dy) < 30 then return end
    end
    Player.PrepareUnitOrders(state.player, Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION, nil, target, nil,
        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, forge, false, false, false, false, "forge_helper", false)
    state.orderStamps[key] = { at = now }
end

utilities.attackRange = function(forge)
    return (NPC.GetAttackRange(forge) or 300) + 150
end

utilities.forgeRange = function(forge, hero)
    local measured = NPC.GetAttackRange(forge) or 0
    if measured > 200 then return measured end
    local level = 1
    if hero then
        level = utilities.level(utilities.orbs(hero).quas)
    end
    if level < 1 then level = 1 end
    if level > 8 then level = 8 end
    return 300 + 65 * (level - 1)
end

utilities.standoffAttack = function(forge, target, key, now, hero)
    local range = utilities.forgeRange(forge, hero)
    local point = utilities.point(target)
    local forgePoint = utilities.point(forge)
    if not point or not forgePoint then return end
    local dx = forgePoint.x - point.x
    local dy = forgePoint.y - point.y
    local distance = math.sqrt(dx * dx + dy * dy)
    if distance > range + 80 and distance > 1 then
        local standoff = range - 120
        if standoff < 150 then standoff = 150 end
        local destination = Vector(point.x + (dx / distance) * standoff, point.y + (dy / distance) * standoff, point.z)
        utilities.keepMove(forge, destination, key .. "_approach", now, 0.2)
        return
    end
    utilities.keepAttack(forge, target, key, now, true)
end

local menuRoot = Menu.Create("Heroes", "Hero List", "Invoker", "Main Settings")
local tabMain = menuRoot:Create("Forge Spirit Helper")

ui.main = {}
ui.main.enabled = tabMain:Switch("Включить", true, "\u{f14a}")
local gearSettings = ui.main.enabled:Gear("Настройки")

ui.main.invisible = gearSettings:Switch("В невидимости", false, "\u{f070}")
ui.main.minLevel = gearSettings:Slider("Минимальный уровень", 2, 10, 7, "%d")
ui.main.minLevel:Icon("\u{f007}")

ui.techies = {}
ui.techies.enabled = tabMain:Switch("Techies", true, "panorama/images/heroes/icons/npc_dota_hero_techies_png.vtex_c")
ui.bane = {}
ui.bane.enabled = tabMain:Switch("Bane", true, "panorama/images/heroes/icons/npc_dota_hero_bane_png.vtex_c")
ui.arc = {}
ui.arc.enabled = tabMain:Switch("Arc Warden", true, "panorama/images/heroes/icons/npc_dota_hero_arc_warden_png.vtex_c")
local arcGear = ui.arc.enabled:Gear("Настройки")
ui.main.health = arcGear:Slider("Порог ХП (%)", 5, 90, 30)
ui.main.health:Icon("\u{f004}")

utilities.bindToggle = function(master, controls)
    master:SetCallback(function()
        local enabled = master:Get()
        for index = 1, #controls do
            controls[index]:Disabled(not enabled)
        end
    end, true)
end

utilities.updateTechies = function(hero, forges, now, busy)
    if not ui.techies.enabled:Get() then return false end
    local roster = utilities.rosterOf(hero)
    if not roster.tehniksnayba then return false end
    local miny = utilities.mines(hero, 700, true, forges)
    if #miny == 0 then
        state.mineTasks = {}
        return false
    end
    local porog = #miny >= 1
    if #forges == 0 then return porog end
    local zadaniya = {}
    local zanyaty = {}
    for minyIndex = 1, #miny do
        local odnaminy = miny[minyIndex]
        if not zanyaty[odnaminy.index] then
            local bestforge = nil
            local bestrazstoyanie = nil
            for index = 1, #forges do
                local nomer = utilities.index(forges[index])
                if not zadaniya[nomer] and not busy[nomer] then
                    local tekushhee = utilities.distance(forges[index], odnaminy.unit)
                    if not bestrazstoyanie or tekushhee < bestrazstoyanie then
                        bestrazstoyanie = tekushhee
                        bestforge = index
                    end
                end
            end
            if bestforge then
                zadaniya[utilities.index(forges[bestforge])] = odnaminy
                zanyaty[odnaminy.index] = true
            end
        end
    end
    for index = 1, #forges do
        local kto = forges[index]
        local nomer = utilities.index(kto)
        local cel = zadaniya[nomer]
        if cel then
            busy[nomer] = true
            utilities.standoffAttack(kto, cel.unit, "minak_" .. nomer, now, hero)
        end
    end
    return porog
end


utilities.updateBane = function(hero, forges, now, busy)
    if not ui.bane.enabled:Get() then return false end
    local roster = utilities.rosterOf(hero)
    if not roster.ponosnoy then return false end
    local nadodox = false
    local pomo = 750
    local polzovany = {}
    local vozrast = utilities.sleepAge(hero)
    if vozrast then
        nadodox = true
        for index = 1, #forges do
            local kto = forges[index]
            local nomer = utilities.index(kto)
            if not busy[nomer] and not polzovany[nomer] and utilities.distance(kto, hero) <= pomo then
                busy[nomer] = true
                polzovany[nomer] = true
                utilities.keepAttack(kto, hero, "sebja_" .. nomer, now, utilities.distance(kto, hero) <= utilities.forgeRange(kto, hero))
                break
            end
        end
end
    local vsegeroi = Heroes.GetAll() or {}
    local moyIndex = utilities.index(hero)
    for index = 1, #vsegeroi do
        local soyuznik = vsegeroi[index]
        if soyuznik then
            local soyuznikIndex = utilities.index(soyuznik)
            if soyuznikIndex ~= moyIndex and utilities.alive(soyuznik) and utilities.friendly(soyuznik, hero) then
                if utilities.sleepAge(soyuznik) then
                    nadodox = true
                    for fIndex = 1, #forges do
                        local kto = forges[fIndex]
                        local nomer = utilities.index(kto)
                        if not busy[nomer] and not polzovany[nomer] and utilities.distance(kto, soyuznik) <= pomo then
                            busy[nomer] = true
                            polzovany[nomer] = true
                            utilities.keepAttack(kto, soyuznik, "druga_" .. soyuznikIndex, now, utilities.distance(kto, soyuznik) <= utilities.forgeRange(kto, hero))
                            break
                        end
                    end
                end
            end
    end
end
    local ponos = roster.ponosnoy
    local tekushcheerast = utilities.distance(ponos, hero)
    local bylo = state.baneLast
    local radius = 750
    local priblizhaetsa = false
    if bylo then
        local raznica = bylo.distance - tekushcheerast
        if raznica > 250 then priblizhaetsa = true end
        if now - bylo.at > 0.01 then
            local skorost = raznica / (now - bylo.at)
            if skorost > 250 and tekushcheerast <= radius + 400 then priblizhaetsa = true end
        end
    end
    state.baneLast = { distance = tekushcheerast, at = now }
    if priblizhaetsa or (NPC.IsRunning(ponos) == true and tekushcheerast <= radius) then
        nadodox = true
    end
    return nadodox
end


utilities.updateArc = function(hero, controlled, forges, now, busy)
    if not ui.arc.enabled:Get() then return false end
    if utilities.healthPercent(hero) >= ui.main.health:Get() then
        state.arcChaser = nil
        state.arcLastCenter = nil
        state.escortUntil = 0
        return false
    end
    local roster = utilities.rosterOf(hero)
    local harakotka = utilities.wraiths(hero, 1500)
    for key, kaktak in pairs(state.sparkKeys) do
        if now - kaktak.at > 4 then state.sparkKeys[key] = nil end
    end
    for key, kaktak in pairs(state.sparkIndices) do
        if now - kaktak.at > 4 then state.sparkIndices[key] = nil end
    end
    if not roster.jopaarcwarden and #harakotka == 0 then return false end
    local vseforzhi = forges or controlled
    local nadorigod = false
    if #harakotka > 0 then
        state.wraithSeenAt = now
        state.escortUntil = 0
        local ostalnie = {}
        for index = 1, #vseforzhi do
            local kto = vseforzhi[index]
            local nomer = utilities.index(kto)
            if not busy[nomer] then ostalnie[#ostalnie + 1] = kto end
        end
        local hvatit = 0
        for sparksIndex = 1, #harakotka do
            local centr = harakotka[sparksIndex].point
            local bestforge = nil
            local bestfusion = nil
            local bestrazstoyanie = nil
            for index = 1, #ostalnie do
                local kto = ostalnie[index]
                local tochka = utilities.point(kto)
                if tochka and centr and centr.x then
                    local otstupanie = tochka.x - centr.x
                    local smezhenie = tochka.y - centr.y
                    local tekushhee = math.sqrt(otstupanie * otstupanie + smezhenie * smezhenie)
                    if not bestrazstoyanie or tekushhee < bestrazstoyanie then
                        bestrazstoyanie = tekushhee
                        bestforge = kto
                    end
                end
            end
            if bestforge then
                local nomer = utilities.index(bestforge)
                busy[nomer] = true
                hvatit = hvatit + 1
                utilities.keepMove(bestforge, centr, "sparek_" .. nomer, now, 0.15)
                for remIndex = #ostalnie, 1, -1 do
                    if utilities.index(ostalnie[remIndex]) == nomer then
                        table.remove(ostalnie, remIndex)
                        break
                    end
                end
            end
        end
        nadorigod = #vseforzhi == 0 or hvatit < #harakotka
    end
    if nadorigod then return true end
    if not state.wraithSeenAt or now - state.wraithSeenAt > 1.5 then
        state.escortUntil = 0
        state.arcChaser = nil
        state.arcLastCenter = nil
        return false
    end
    if state.escortUntil == 0 then state.escortUntil = now + 2 end
    if now >= state.escortUntil then
        state.escortUntil = 0
        state.arcChaser = nil
        state.arcLastCenter = nil
        return false
    end
    local tochkaigroya = utilities.point(hero)
    if not tochkaigroya then return false end
    local proshliy = state.arcLastCenter
    local sx, sy = 0, 0
    if proshliy and proshliy.x then
        sx = proshliy.x - tochkaigroya.x
        sy = proshliy.y - tochkaigroya.y
        local dlina = math.sqrt(sx * sx + sy * sy)
        if dlina > 1 then
            sx = sx / dlina
            sy = sy / dlina
        else
            sx, sy = 0, 0
        end
    end
    state.arcLastCenter = { x = tochkaigroya.x, y = tochkaigroya.y, at = now }
    local svobodniye = {}
    for index = 1, #vseforzhi do
        local nomer = utilities.index(vseforzhi[index])
        if not busy[nomer] then svobodniye[#svobodniye + 1] = vseforzhi[index] end
    end
    if #svobodniye == 0 then return false end
    for index = 1, #svobodniye do
        local kto = svobodniye[index]
        local nomer = utilities.index(kto)
        busy[nomer] = true
        if #vseforzhi >= 2 and state.arcChaser == nil then state.arcChaser = nomer end
        local cel
        if nomer == state.arcChaser then
            cel = Vector(tochkaigroya.x + sx * 150, tochkaigroya.y + sy * 150, tochkaigroya.z)
        else
            cel = Vector(tochkaigroya.x - sx * 150, tochkaigroya.y - sy * 150, tochkaigroya.z)
        end
        utilities.keepMove(kto, cel, "eskort_" .. nomer, now, 0.15)
    end
    return false
end


function script.OnParticleCreate(data)
    utilities.catchSpark(data)
end

function script.OnParticleUpdate(data)
    utilities.trackSpark(data)
end

function script.OnParticleUpdateFallback(data)
    utilities.trackSpark(data)
end

function script.OnScriptsLoaded()
    utilities.bindToggle(ui.main.enabled, { ui.main.health, ui.main.invisible, ui.main.minLevel })
end

function script.OnUpdate()
    if not ui.main.enabled:Get() then return end
    if not Engine.IsInGame() then return end
    local hero = Heroes.GetLocal()
    if not hero then return end
    if not string.find(utilities.unitName(hero), "hero_invoker", 1, true) then
        state.sequence = nil
        state.mineTasks = {}
        return
    end
    local heroIndex = utilities.index(hero)
    if state.playerIndex ~= heroIndex then
        state.player = Players.GetLocal()
        state.playerIndex = heroIndex
    end
    if not state.player then return end
    if NPC.GetCurrentLevel(hero) < ui.main.minLevel:Get() then
        state.sequence = nil
        return
    end
    if not ui.main.invisible:Get() and utilities.invisible(hero) then
        state.sequence = nil
        return
    end
    local now = utilities.now()
    if now - (state.prunedAt or -100) > 2 then
        state.prunedAt = now
        utilities.pruneStamps(now)
    end
    utilities.updateSequence(hero, now)
    local roster = utilities.rosterOf(hero)
    if not roster.any then return end
    local forges = utilities.forges(hero)
    local controlled = {}
    for index = 1, #forges do
        if utilities.distance(forges[index], hero) <= 1200 then
            controlled[#controlled + 1] = forges[index]
        end
    end
    local cooldown = utilities.forgeCooldown(hero)
    local busy = {}
    local nadodox = false
    if utilities.updateBane(hero, controlled, now, busy) then nadodox = true end
    if utilities.updateTechies(hero, controlled, now, busy) then nadodox = true end
    if utilities.updateArc(hero, controlled, forges, now, busy) then nadodox = true end
    if not nadodox then return end
    if cooldown > 0 then return end
    if state.sequence then return end
    if now - (state.lastSummonAt or -100) < 0.40 then return end
    state.lastSummonAt = now
    utilities.summon(hero)
end

return script
