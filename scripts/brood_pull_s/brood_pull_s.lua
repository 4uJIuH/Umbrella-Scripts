--[[
            ~ broodmother creep puller - uczone.gitbook.io/api-v2.0/
        ~ t.me/windguild
    ~ первый скрипт в 2026 епта
]]

local brood_pull = {}

local function Dist2D(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

local function Normalize2D(v)
    local len = math.sqrt(v.x * v.x + v.y * v.y)
    if len < 0.001 then return Vector(1, 0, 0) end
    return Vector(v.x / len, v.y / len, 0)
end

local function IsBroodmother()
    local myHero = Heroes.GetLocal()
    return myHero and NPC.GetUnitName(myHero) == "npc_dota_hero_broodmother"
end

local function GetClockData()
    local realNow = GameRules.GetGameTime()
    local startTime = (GameRules.GetGameStartTime and GameRules.GetGameStartTime()) or 0
    local clockNow = realNow - startTime
    if clockNow < 0 then clockNow = 0 end
    return realNow, clockNow
end

local LanePoints = {
    radiant = {
        { pos = Vector(2266.9, 5839.9, 136.0), name = "Top" },
        { pos = Vector(3503.1, 2892.1, 136.0), name = "Mid" },
        { pos = Vector(6344.7, 1852.7, 136.0), name = "Bot" },
    },
    dire = {
        { pos = Vector(-6599.8, -2183.7, 128.0), name = "Top" },
        { pos = Vector(-3945.1, -3491.4, 136.8), name = "Mid" },
        { pos = Vector(-2440.2, -6167.0, 128.0), name = "Bot" },
    },
}

local CreepTravelTime = {
    radiant = { Top = 25, Mid = 20, Bot = 25 },
    dire    = { Top = 25, Mid = 20, Bot = 25 },
}

local Fonts = {
    Main = Render.LoadFont("Verdana", Enum.FontCreate.FONTFLAG_ANTIALIAS)
}

local function InitializeUI()
    local tab = Menu.Create("General", "Lane Pull", "lane_pull")
    tab:Icon("\u{f111}")

    local mainGroup = tab:Create("Pull settings"):Create("Main")
    local visualsGroup = tab:Create("Visuals"):Create("Main")

    return {
        Enabled = mainGroup:Switch("Enable", true),
        Key = mainGroup:Bind("Pull key", Enum.ButtonCode.KEY_NONE, "\u{f0c1}"),
        Mode = mainGroup:Combo("Mode", {"Hold", "Toggle"}, 0),
        Count = mainGroup:Slider("lane count", 1, 3, 2, "%d"),

        _debuglines = visualsGroup:Switch("lines", true),
        _pulltext = visualsGroup:Switch("'pulling' text near hero", true),
    }
end

local UI = InitializeUI()

local State = {
    pullToggled = false,
    assignments = {},
    cachedTowers = nil,
    cachedTowersTime = 0,
    cachedCamps = nil,
    lastDispatchClock = -999,
}

local function GetAllSpiders()
    local myHero = Heroes.GetLocal()
    if not myHero then return {} end
    local playerId = Hero.GetPlayerID(myHero)
    local allNPCs = NPCs.GetAll()
    local result = {}
    for _, npc in ipairs(allNPCs) do
        if Entity.IsAlive(npc) and Entity.IsControllableByPlayer(npc, playerId) then
            if NPC.GetUnitName(npc) == "npc_dota_broodmother_spiderling" then
                table.insert(result, npc)
            end
        end
    end
    return result
end

local function GetSpiderRemainingLife(spider)
    if not spider then return 0 end
    local mods = NPC.GetModifiers(spider)
    if not mods or #mods == 0 then return 0 end
    local now = GameRules.GetGameTime()
    local best = 0
    for _, m in ipairs(mods) do
        local die = Modifier.GetDieTime(m)
        if die and die > 0 then
            local rem = die - now
            if rem > best then best = rem end
        end
    end
    return best
end

local function IsSpiderAssigned(spider)
    for _, asg in ipairs(State.assignments) do
        if asg.spider == spider then return true end
    end
    return false
end

local function GetAvailableSpiders()
    local spiders = GetAllSpiders()
    local available = {}
    for _, s in ipairs(spiders) do
        if not IsSpiderAssigned(s) then
            table.insert(available, s)
        end
    end
    table.sort(available, function(a, b)
        local lifeA = GetSpiderRemainingLife(a)
        local lifeB = GetSpiderRemainingLife(b)

        if math.abs(lifeA - lifeB) > 3 then
            return lifeA > lifeB
        end

        local hpA = Entity.GetHealth(a) or 0
        local hpB = Entity.GetHealth(b) or 0
        return hpA > hpB
    end)
    return available
end

local function GetEnemyTowers()
    local now = GameRules.GetGameTime()

    if State.cachedTowers and (now - State.cachedTowersTime) < 2 then
        return State.cachedTowers
    end

    local myHero = Heroes.GetLocal()
    if not myHero then return {} end

    State.cachedTowers = {}
    local allNPCs = NPCs.GetAll()
    for _, npc in ipairs(allNPCs) do
        if Entity.IsAlive(npc) and not Entity.IsSameTeam(npc, myHero) and NPC.IsTower(npc) then
            table.insert(State.cachedTowers, {
                entity = npc,
                pos = Entity.GetAbsOrigin(npc),
                name = NPC.GetUnitName(npc),
            })
        end
    end
    State.cachedTowersTime = now
    return State.cachedTowers
end

local function IsPathNearTower(from, to, safeRadius)
    local towers = GetEnemyTowers()
    for _, tower in ipairs(towers) do
        local tp = tower.pos

        local dx, dy = to.x - from.x, to.y - from.y
        local lenSq = dx * dx + dy * dy
        if lenSq > 0 then
            local t = math.max(0, math.min(1,
                ((tp.x - from.x) * dx + (tp.y - from.y) * dy) / lenSq
            ))
            local closestX = from.x + t * dx
            local closestY = from.y + t * dy
            local dist = math.sqrt((tp.x - closestX)^2 + (tp.y - closestY)^2)
            if dist < safeRadius then
                return true, tower
            end
        end
    end
    return false, nil
end

local function GetSafeRetreatPos(lanePoint, heroPos, safeRadius)
    local dangerous, tower = IsPathNearTower(lanePoint, heroPos, safeRadius)

    if not dangerous then

        return heroPos
    end

    local tp = tower.pos

    local midX = (lanePoint.x + heroPos.x) / 2
    local midY = (lanePoint.y + heroPos.y) / 2

    local dx, dy = heroPos.x - lanePoint.x, heroPos.y - lanePoint.y
    local perpX, perpY = -dy, dx
    local perpLen = math.sqrt(perpX * perpX + perpY * perpY)
    if perpLen > 0 then perpX, perpY = perpX / perpLen, perpY / perpLen end

    local side1X = midX + perpX * (safeRadius + 200)
    local side1Y = midY + perpY * (safeRadius + 200)
    local side2X = midX - perpX * (safeRadius + 200)
    local side2Y = midY - perpY * (safeRadius + 200)

    local dist1 = math.sqrt((tp.x - side1X)^2 + (tp.y - side1Y)^2)
    local dist2 = math.sqrt((tp.x - side2X)^2 + (tp.y - side2Y)^2)

    local waypointX, waypointY
    if dist1 > dist2 then
        waypointX, waypointY = side1X, side1Y
    else
        waypointX, waypointY = side2X, side2Y
    end

    return Vector(waypointX, waypointY, lanePoint.z)
end

local function GetTeamLanes()
    local myHero = Heroes.GetLocal()
    if not myHero then return nil end
    local team = Entity.GetTeamNum(myHero)
    if team == Enum.TeamNum.TEAM_RADIANT then
        return LanePoints.radiant, "radiant"
    elseif team == Enum.TeamNum.TEAM_DIRE then
        return LanePoints.dire, "dire"
    end
    return nil, nil
end

local function GetClosestLanes(heroPos, count)
    local lanes, teamKey = GetTeamLanes()
    if not lanes then return {} end

    local sorted = {}
    for i, lane in ipairs(lanes) do
        table.insert(sorted, {
            idx = i,
            lane = lane,
            dist = Dist2D(heroPos, lane.pos),
            teamKey = teamKey,
        })
    end

    table.sort(sorted, function(a, b) return a.dist < b.dist end)

    local result = {}
    for i = 1, math.min(count, #sorted) do
        table.insert(result, sorted[i])
    end
    return result
end

local function GetNextCreepSpawnClock(clockNow)
    local interval = 30
    local next = math.ceil(clockNow / interval) * interval
    if next <= clockNow then next = next + interval end
    return next
end

local function GetTimeUntilCreepsArrive(clockNow, teamKey, laneName)
    local nextSpawn = GetNextCreepSpawnClock(clockNow)
    local timeUntilSpawn = nextSpawn - clockNow
    local travelTime = 0
    if CreepTravelTime[teamKey] and CreepTravelTime[teamKey][laneName] then
        travelTime = CreepTravelTime[teamKey][laneName]
    end

    return timeUntilSpawn + travelTime, nextSpawn
end

local function GetSpiderTravelTime(spider, targetPos)
    local spiderPos = Entity.GetAbsOrigin(spider)
    local dist = Dist2D(spiderPos, targetPos)
    local speed = NPC.GetMoveSpeed(spider) or 350
    return dist / speed
end

local function CanSpiderReachInTime(spider, lanePos, timeAvailable)
    local travelTime = GetSpiderTravelTime(spider, lanePos)
    return travelTime <= timeAvailable, travelTime
end

local function GetCampPositions()
    if State.cachedCamps then return State.cachedCamps end
    State.cachedCamps = {}
    local camps = Camps.GetAll()
    if camps then
        for _, camp in ipairs(camps) do
            local pos = Entity.GetAbsOrigin(camp)
            if pos then table.insert(State.cachedCamps, pos) end
        end
    end
    return State.cachedCamps
end

local function BuildGridNavPath(spider, startPos, goalPos)
    local npcMap = GridNav.CreateNpcMap({ spider }, true)
    local path = GridNav.BuildPath(startPos, goalPos, false, npcMap)
    GridNav.ReleaseNpcMap(npcMap)
    return path
end

local function DispatchPull()
    local myHero = Heroes.GetLocal()
    if not myHero then return end
    local myPlayer = Players.GetLocal()
    if not myPlayer then return end

    local heroPos = Entity.GetAbsOrigin(myHero)
    local _, clockNow = GetClockData()
    local Count = UI.Count:Get()
    local safeRadius = 900

    local closestLanes = GetClosestLanes(heroPos, Count)
    if #closestLanes == 0 then return end

    local available = GetAvailableSpiders()
    if #available == 0 then return end

    local now = GameRules.GetGameTime()
    local spiderIdx = 1

    for _, laneInfo in ipairs(closestLanes) do
        if spiderIdx > #available then break end

        local lane = laneInfo.lane
        local lanePos = lane.pos
        local teamKey = laneInfo.teamKey

        local retreatPos = GetSafeRetreatPos(lanePos, heroPos, safeRadius)

        local spider = available[spiderIdx]
        local travelTime = GetSpiderTravelTime(spider, lanePos)
        local remainLife = GetSpiderRemainingLife(spider)

        local totalNeeded = travelTime + 1.25 + 5
        if remainLife > 0 and remainLife < totalNeeded then

            local found = false
            for j = spiderIdx + 1, #available do
                local alt = available[j]
                local altLife = GetSpiderRemainingLife(alt)
                local altTravel = GetSpiderTravelTime(alt, lanePos)
                if altLife == 0 or altLife >= (altTravel + 1.25 + 5) then

                    available[spiderIdx], available[j] = available[j], available[spiderIdx]
                    spider = available[spiderIdx]
                    travelTime = altTravel
                    found = true
                    break
                end
            end
            if not found then
                spiderIdx = spiderIdx + 1
                goto nextLane
            end
        end

        local creepArrivalTime, _ = GetTimeUntilCreepsArrive(clockNow, teamKey, lane.name)

        local spiderStartPos = Entity.GetAbsOrigin(spider)
        local dangerous, _ = IsPathNearTower(spiderStartPos, lanePos, safeRadius)
        local towerWaypoint = nil

        if dangerous then
            towerWaypoint = GetSafeRetreatPos(spiderStartPos, lanePos, safeRadius)
        end

        local firstTarget = towerWaypoint or lanePos

        Player.PrepareUnitOrders(
            myPlayer,
            Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION,
            nil,
            firstTarget,
            nil,
            Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
            spider,
            false, false, false, false,
            "brood_pull_travel"
        )

        table.insert(State.assignments, {
            spider = spider,
            lanePos = lanePos,
            retreatPos = retreatPos,
            laneName = lane.name,
            teamKey = teamKey,
            phase = "travel",
            phaseTime = now,
            travelTime = travelTime,
            creepArrivalTime = creepArrivalTime,
            dispatchTime = now,
            towerWaypoint = towerWaypoint,
            towerWPReached = not towerWaypoint,
            lastSteerTime = now,
        })

        spiderIdx = spiderIdx + 1
        ::nextLane::
    end

    State.lastDispatchClock = clockNow
end

local function HasEnemyCreepsNear(pos, radius)
    local myHero = Heroes.GetLocal()
    if not myHero then return false end

    local heroPos = Entity.GetAbsOrigin(myHero)
    local heroToPos = Dist2D(heroPos, pos)
    local searchRadius = heroToPos + radius + 500
    local units = Entity.GetUnitsInRadius(myHero, searchRadius, Enum.TeamType.TEAM_ENEMY)
    for _, npc in ipairs(units) do
        if Entity.IsAlive(npc) and not Entity.IsDormant(npc) and NPC.IsLaneCreep(npc) then
            local creepPos = Entity.GetAbsOrigin(npc)
            if Dist2D(pos, creepPos) < radius then
                return true
            end
        end
    end
    return false
end

local function UpdateAssignments()
    local myPlayer = Players.GetLocal()
    if not myPlayer then return end
    local myHero = Heroes.GetLocal()

    local now = GameRules.GetGameTime()
    local aggroDuration = 1.25
    local safeRadius = 900

    for i = #State.assignments, 1, -1 do
        local asg = State.assignments[i]
        local spider = asg.spider

        if not spider or not Entity.IsAlive(spider) then
            table.remove(State.assignments, i)
            goto continue
        end

        local spiderPos = Entity.GetAbsOrigin(spider)

        if asg.phase == "travel" then
            local distToLane = Dist2D(spiderPos, asg.lanePos)

            if distToLane < 250 then
                asg.phase = "wait"
                asg.phaseTime = now
            elseif now - asg.phaseTime > 30 then
                table.remove(State.assignments, i)
            else

                if not asg.towerWPReached and asg.towerWaypoint then
                    if Dist2D(spiderPos, asg.towerWaypoint) < 200 then
                        asg.towerWPReached = true
                    end
                end

                if now - asg.lastSteerTime >= 0.5 then
                    local target
                    if not asg.towerWPReached and asg.towerWaypoint then
                        target = asg.towerWaypoint
                    else
                        target = asg.lanePos
                    end
                    Player.PrepareUnitOrders(
                        myPlayer,
                        Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION,
                        nil,
                        target,
                        nil,
                        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                        spider,
                        false, false, false, false,
                        "brood_pull_travel"
                    )
                    asg.lastSteerTime = now
                end
            end

        elseif asg.phase == "wait" then

            local creepsHere = HasEnemyCreepsNear(asg.lanePos, 500)

            if creepsHere then

                asg.phase = "aggro"
                asg.phaseTime = now

                Player.PrepareUnitOrders(
                    myPlayer,
                    Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_MOVE,
                    nil,
                    asg.lanePos,
                    nil,
                    Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                    spider,
                    false, false, false, false,
                    "brood_pull_aggro"
                )
            elseif now - asg.phaseTime > 35 then

                table.remove(State.assignments, i)
            end

        elseif asg.phase == "aggro" then
            if now - asg.phaseTime >= aggroDuration then
                asg.phase = "retreat"
                asg.phaseTime = now
                asg.lastSteerTime = 0
            end

        elseif asg.phase == "retreat" then
            local heroPos = myHero and Entity.GetAbsOrigin(myHero) or asg.retreatPos
            local distToHero = Dist2D(spiderPos, heroPos)

            if not asg.gridPath or not asg.gridPathTime or (now - asg.gridPathTime > 3) then
                local safeTarget = GetSafeRetreatPos(spiderPos, heroPos, 900)
                asg.gridPath = BuildGridNavPath(spider, spiderPos, safeTarget)
                asg.gridPathIdx = 1
                asg.gridPathTime = now
            end

            if not asg.reaggroUntil then asg.reaggroUntil = 0 end
            if not asg.reaggroCooldown then asg.reaggroCooldown = 0 end
            if not asg.lastTraversableCheck then asg.lastTraversableCheck = 0 end

            if now - asg.lastTraversableCheck >= 0.5 and now > asg.reaggroUntil and now > asg.reaggroCooldown then
                asg.lastTraversableCheck = now

                local lp = asg.lanePos or spiderPos
                local backDx, backDy = lp.x - spiderPos.x, lp.y - spiderPos.y
                local backDist = math.sqrt(backDx * backDx + backDy * backDy)
                if backDist > 50 then
                    local backPos = Vector(
                        spiderPos.x + backDx / backDist * 400,
                        spiderPos.y + backDy / backDist * 400,
                        spiderPos.z
                    )

                    local canPass = GridNav.IsTraversableFromTo(spiderPos, backPos, true)
                    if not canPass then

                        asg.reaggroUntil = now + 1.2
                        asg.reaggroCooldown = now + 5.0
                    end
                end
            end

            local wp = asg.gridPath and asg.gridPath[asg.gridPathIdx]
            if wp and Dist2D(spiderPos, wp) < 150 then
                asg.gridPathIdx = asg.gridPathIdx + 1
                wp = asg.gridPath[asg.gridPathIdx]
            end
            if not wp then wp = heroPos end

            if distToHero < 300 or (now - asg.phaseTime > 25) then
                table.remove(State.assignments, i)
            elseif now < asg.reaggroUntil then

                if now - asg.lastSteerTime >= 0.4 then
                    Player.PrepareUnitOrders(
                        myPlayer,
                        Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_MOVE,
                        nil,
                        spiderPos,
                        nil,
                        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                        spider,
                        false, false, false, false,
                        "brood_pull_reaggro"
                    )
                    asg.lastSteerTime = now
                end
            else

                local creepsAggroed = false
                local myHeroEnt = Heroes.GetLocal()
                local teamNum = myHeroEnt and Entity.GetTeamNum(myHeroEnt) or 0
                local nearCreeps = NPCs.InRadius(spiderPos, 700, teamNum, Enum.TeamType.TEAM_ENEMY)
                if nearCreeps then
                    for _, creep in ipairs(nearCreeps) do
                        if Entity.IsAlive(creep) and NPC.IsLaneCreep(creep) then
                            if NPC.IsRunning(creep) or NPC.IsAttacking(creep) then
                                creepsAggroed = true
                                break
                            end
                        end
                    end
                end

                if creepsAggroed then

                    if now - asg.lastSteerTime >= 0.5 then
                        Player.PrepareUnitOrders(
                            myPlayer,
                            Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION,
                            nil,
                            wp,
                            nil,
                            Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                            spider,
                            false, false, false, false,
                            "brood_pull_retreat"
                        )
                        asg.lastSteerTime = now
                    end
                else

                    if now - asg.lastSteerTime >= 0.5 then
                        Player.PrepareUnitOrders(
                            myPlayer,
                            Enum.UnitOrder.DOTA_UNIT_ORDER_STOP,
                            nil, nil, nil,
                            Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                            spider,
                            false, false, false, false,
                            "brood_pull_retreat"
                        )
                        asg.lastSteerTime = now
                    end
                end
            end
        end

        ::continue::
    end
end

local function drwawpulltxt()
    if not UI._pulltext:Get() then return end
    if #State.assignments == 0 then return end

    local myHero = Heroes.GetLocal()
    if not myHero then return end

    local heroPos = Entity.GetAbsOrigin(myHero)
    local abovePos = Vector(heroPos.x, heroPos.y, heroPos.z + 200)
    local sp, vis = Render.WorldToScreen(abovePos)
    if not vis then return end

    local txt = "Pulling..."
    local tSize = Render.TextSize(Fonts.Main, 14, txt)
    local tx = sp.x - tSize.x / 2
    local ty = sp.y - tSize.y / 2
    Render.Text(Fonts.Main, 14, txt, Vec2(tx + 1, ty + 1), Color(0, 0, 0, 180))
    Render.Text(Fonts.Main, 14, txt, Vec2(tx, ty), Color(255, 200, 100, 255))
end

local function lineshit()
    if not UI._debuglines:Get() then return end

    for _, asg in ipairs(State.assignments) do
        local spider = asg.spider
        if not spider or not Entity.IsAlive(spider) then goto cont end

        local spiderPos = Entity.GetAbsOrigin(spider)
        local sSp, sOk = Render.WorldToScreen(spiderPos)
        local lSp, lOk = Render.WorldToScreen(asg.lanePos)
        local rSp, rOk = Render.WorldToScreen(asg.retreatPos)

        local phaseCol
        if asg.phase == "travel" then
            phaseCol = Color(100, 180, 255, 200)
        elseif asg.phase == "wait" then
            phaseCol = Color(200, 200, 100, 200)
        elseif asg.phase == "aggro" then
            phaseCol = Color(255, 50, 50, 200)
        elseif asg.phase == "retreat" then
            phaseCol = Color(255, 120, 60, 200)
        end

        if asg.phase == "travel" or asg.phase == "wait" or asg.phase == "aggro" then
            if sOk and lOk then Render.Line(sSp, lSp, phaseCol, 2) end
        elseif asg.phase == "retreat" and asg.gridPath then

            local prevSp, prevOk = sSp, sOk
            for wi = (asg.gridPathIdx or 1), #asg.gridPath do
                local wpSp, wpOk = Render.WorldToScreen(asg.gridPath[wi])
                if prevOk and wpOk then
                    Render.Line(prevSp, wpSp, phaseCol, 2)
                end
                prevSp, prevOk = wpSp, wpOk
            end
        end

        ::cont::
    end
end

brood_pull.OnUpdate = function()
    if not IsBroodmother() or not UI.Enabled:Get() then return end

    if #State.assignments > 0 then
        local player = Players.GetLocal()
        if player then
            local selected = Player.GetSelectedUnits(player) or {}
            if #selected > 0 then
                local clean = {}
                local dirty = false
                for _, u in ipairs(selected) do
                    if IsSpiderAssigned(u) then
                        dirty = true
                    else
                        table.insert(clean, u)
                    end
                end
                if dirty then
                    Player.ClearSelectedUnits(player)
                    for _, u in ipairs(clean) do
                        Player.AddSelectedUnit(player, u)
                    end
                end
            end
        end
    end

    local mode = UI.Mode:Get()

    if mode == 0 then

        if UI.Key:IsDown() then
            if #State.assignments == 0 then
                DispatchPull()
            end
        end
    else

        if UI.Key:IsPressed() then
            State.pullToggled = not State.pullToggled
            if State.pullToggled then
                DispatchPull()
            else
                State.assignments = {}
            end
        end
    end

    UpdateAssignments()

    if mode == 1 and State.pullToggled and #State.assignments == 0 then
        State.pullToggled = false
    end
end

brood_pull.OnDraw = function()
    if not IsBroodmother() or not UI.Enabled:Get() then return end

    lineshit()
    drwawpulltxt()
end

brood_pull.OnPrepareUnitOrders = function(data)
    if not IsBroodmother() or not UI.Enabled:Get() then return true end
    if #State.assignments == 0 then return true end

    if data.identifier == "brood_pull_travel"
    or data.identifier == "brood_pull_aggro"
    or data.identifier == "brood_pull_retreat"
    or data.identifier == "brood_pull_reaggro"
    or data.identifier == "brood_pull_relay" then
        return true
    end

    if data.npc and IsSpiderAssigned(data.npc) then
        return false
    end

    if data.orderIssuer == Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_SELECTED_UNITS then
        local player = Players.GetLocal()
        if player then
            local selected = Player.GetSelectedUnits(player) or {}
            local allowed = {}
            local hasLocked = false

            for _, u in ipairs(selected) do
                if IsSpiderAssigned(u) then
                    hasLocked = true
                else
                    table.insert(allowed, u)
                end
            end

            if hasLocked then
                if #allowed > 0 then

                    Player.PrepareUnitOrders(
                        player,
                        data.order,
                        data.target,
                        data.position,
                        data.ability,
                        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                        allowed,
                        data.queue or false,
                        data.showEffects or false,
                        false, false,
                        "brood_pull_relay"
                    )
                end
                return false
            end
        end
    end

    return true
end

brood_pull.OnGameEnd = function()
    State.assignments = {}
    State.pullToggled = false
    State.cachedCamps = nil
    State.cachedTowers = nil
end

return brood_pull
