local VERSION = "1.0.0"

local bear_pull = {}

local localization = qLocalization.new({
    en = {
        ui = {
            tab = "Spirit Bear Pull",
            settings = "Pull settings",
            visuals = "Visuals",
            enable = "Enable",
            key = "Pull bear key",
            mode = "Mode",
            hold = "Hold",
            toggle = "Toggle",
            lines = "Lines",
            pullText = "Pulling text near hero",
            pulling = "Pulling...",
        },
    },
    ru = {
        ui = {
            tab = "Отвод медведя",
            settings = "Настройки отвода",
            visuals = "Визуализация",
            enable = "Включить",
            key = "Клавиша отвода медведя",
            mode = "Режим",
            hold = "Удержание",
            toggle = "Переключатель",
            lines = "Линии",
            pullText = "Текст отвода возле героя",
            pulling = "Отвод...",
        },
    },
})

local Menu = localization.WrapLibrary(Menu)

local function Dist2D(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

local function Normalize2D(v)
    local len = math.sqrt(v.x * v.x + v.y * v.y)
    if len < 0.001 then return Vector(1, 0, 0) end
    return Vector(v.x / len, v.y / len, 0)
end

local function IsLoneDruid()
    local myHero = Heroes.GetLocal()
    return myHero and NPC.GetUnitName(myHero) == "npc_dota_hero_lone_druid"
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

local Fonts = {
    Main = Render.LoadFont("Verdana", Enum.FontCreate.FONTFLAG_ANTIALIAS)
}

local function InitializeUI()
    local tab = Menu.Create("General", "Main", "Spirit Bear Pull")
    tab:Icon("\u{f111}")

    local mainGroup = tab:Create("Settings"):Create("Main")
    local visualsGroup = tab:Create("Visuals"):Create("Main")

    return {
        Enabled = mainGroup:Switch("ui.enable", true),
        Key = mainGroup:Bind("ui.key", Enum.ButtonCode.KEY_NONE, "\u{f0c1}"),
        Mode = mainGroup:Combo("ui.mode", {"ui.hold", "ui.toggle"}, 0),

        _debuglines = visualsGroup:Switch("ui.lines", true),
        _pulltext = visualsGroup:Switch("ui.pullText", true),
    }
end

local UI = InitializeUI()

local State = {
    pullToggled = false,
    assignments = {},
    cachedTowers = nil,
    cachedTowersTime = 0,
}

local function GetAllBears()
    local myHero = Heroes.GetLocal()
    if not myHero then return {} end
    local playerId = Hero.GetPlayerID(myHero)
    local heroTeam = Entity.GetTeamNum(myHero)
    local allNPCs = NPCs.GetAll()
    local result = {}
    for _, npc in ipairs(allNPCs) do
        if Entity.IsAlive(npc) then
            local unitName = NPC.GetUnitName(npc)
            local sameTeam = heroTeam == nil or Entity.GetTeamNum(npc) == heroTeam
            local controlled = playerId == nil or Entity.IsControllableByPlayer(npc, playerId)
            if unitName == "npc_dota_lone_druid_bear1" and (controlled or sameTeam) then
                table.insert(result, npc)
            end
        end
    end
    return result
end

local function GetBearRemainingLife(bear)
    if not bear then return 0 end
    local mods = NPC.GetModifiers(bear)
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

local function IsBearAssigned(bear)
    for _, asg in ipairs(State.assignments) do
        if asg.bear == bear then return true end
    end
    return false
end

local function GetAvailableBears()
    local bears = GetAllBears()
    local available = {}
    for _, s in ipairs(bears) do
        if not IsBearAssigned(s) then
            table.insert(available, s)
        end
    end
    table.sort(available, function(a, b)
        local lifeA = GetBearRemainingLife(a)
        local lifeB = GetBearRemainingLife(b)

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

local function GetTowerTierForLane(towerName, laneName)
    if not towerName or not laneName then return nil end

    local tier, suffix = string.match(towerName, "_tower([123])_([%w]+)$")
    if suffix ~= string.lower(laneName) then return nil end
    return tonumber(tier)
end

local function GetLanePullTarget(laneInfo, heroPos)
    local fallback = laneInfo.lane.pos
    local selectedTower = nil
    local selectedTier = nil

    for _, tower in ipairs(GetEnemyTowers()) do
        local tier = GetTowerTierForLane(tower.name, laneInfo.lane.name)
        if tier and tier <= 2 and (not selectedTier or tier < selectedTier) then
            selectedTower = tower
            selectedTier = tier
        end
    end

    if not selectedTower then
        return fallback, nil, nil
    end

    local towerPos = selectedTower.pos
    local lanePos = laneInfo.lane.pos
    local dx = lanePos.x - towerPos.x
    local dy = lanePos.y - towerPos.y
    if math.abs(dx) < 0.001 and math.abs(dy) < 0.001 then
        dx = heroPos.x - towerPos.x
        dy = heroPos.y - towerPos.y
    end
    local direction = Normalize2D(Vector(dx, dy, 0))

    local towardHero = Vector(heroPos.x - towerPos.x, heroPos.y - towerPos.y, 0)
    if direction.x * towardHero.x + direction.y * towardHero.y < 0 then
        direction = Vector(-direction.x, -direction.y, 0)
    end

    local towerAttackRange = 700
    if NPC.GetAttackRange then
        local ok, range = pcall(NPC.GetAttackRange, selectedTower.entity)
        if ok and type(range) == "number" and range > 0 then
            towerAttackRange = range
        end
    end

    local standDistance = towerAttackRange + 200
    local pullPos = Vector(
        towerPos.x + direction.x * standDistance,
        towerPos.y + direction.y * standDistance,
        towerPos.z
    )

    return pullPos, selectedTower, selectedTier
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

local function GetClosestLane(heroPos)
    local lanes = GetTeamLanes()
    if not lanes then return {} end

    local sorted = {}
    for i, lane in ipairs(lanes) do
        table.insert(sorted, {
            idx = i,
            lane = lane,
            dist = Dist2D(heroPos, lane.pos),
        })
    end

    table.sort(sorted, function(a, b) return a.dist < b.dist end)

    if #sorted == 0 then return {} end
    return { sorted[1] }
end

local function GetBearTravelTime(bear, targetPos)
    local bearPos = Entity.GetAbsOrigin(bear)
    local dist = Dist2D(bearPos, targetPos)
    local speed = NPC.GetMoveSpeed(bear) or 350
    return dist / speed
end

local function BuildGridNavPath(bear, startPos, goalPos)
    local npcMap = GridNav.CreateNpcMap({ bear }, true)
    local path = GridNav.BuildPath(startPos, goalPos, false, npcMap)
    GridNav.ReleaseNpcMap(npcMap)
    return path
end

local function DispatchPull()
    local myHero = Heroes.GetLocal()
    if not myHero then return end
    local myPlayer = Players.GetLocal()
    if not myPlayer then return     end

    local heroPos = Entity.GetAbsOrigin(myHero)
    local safeRadius = 900

    local closestLanes = GetClosestLane(heroPos)
    if #closestLanes == 0 then return end

    local available = GetAvailableBears()
    if #available == 0 then return end

    local now = GameRules.GetGameTime()
    local bearIdx = 1

    for _, laneInfo in ipairs(closestLanes) do
        if bearIdx > #available then break end

        local lane = laneInfo.lane
        local lanePos = lane.pos
        local pullPos, pullTower = GetLanePullTarget(laneInfo, heroPos)

        local retreatPos = GetSafeRetreatPos(lanePos, heroPos, safeRadius)

        local bear = available[bearIdx]
        local travelTime = GetBearTravelTime(bear, pullPos)
        local remainLife = GetBearRemainingLife(bear)

        local totalNeeded = travelTime + 1.25 + 5
        if remainLife > 0 and remainLife < totalNeeded then

            local found = false
            for j = bearIdx + 1, #available do
                local alt = available[j]
                local altLife = GetBearRemainingLife(alt)
                local altTravel = GetBearTravelTime(alt, pullPos)
                if altLife == 0 or altLife >= (altTravel + 1.25 + 5) then

                    available[bearIdx], available[j] = available[j], available[bearIdx]
                    bear = available[bearIdx]
                    travelTime = altTravel
                    found = true
                    break
                end
            end
            if not found then
                bearIdx = bearIdx + 1
                goto nextLane
            end
        end

        local bearStartPos = Entity.GetAbsOrigin(bear)
        local dangerous, _ = IsPathNearTower(bearStartPos, pullPos, safeRadius)
        local towerWaypoint = nil

        if dangerous and not pullTower then
            towerWaypoint = GetSafeRetreatPos(bearStartPos, pullPos, safeRadius)
        end

        local firstTarget = towerWaypoint or pullPos

        Player.PrepareUnitOrders(
            myPlayer,
            Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION,
            nil,
            firstTarget,
            nil,
            Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
            bear,
            false, false, false, false,
            "bear_pull_travel"
        )

        table.insert(State.assignments, {
            bear = bear,
            lanePos = lanePos,
            pullPos = pullPos,
            pullTower = pullTower,
            retreatPos = retreatPos,
            phase = "travel",
            phaseTime = now,
            towerWaypoint = towerWaypoint,
            towerWPReached = not towerWaypoint,
            lastSteerTime = now,
        })

        bearIdx = bearIdx + 1
        ::nextLane::
    end

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
        local bear = asg.bear

        if not bear or not Entity.IsAlive(bear) then
            table.remove(State.assignments, i)
            goto continue
        end

        local bearPos = Entity.GetAbsOrigin(bear)

        if asg.phase == "travel" then
            local targetPos = asg.pullPos or asg.lanePos
            local distToLane = Dist2D(bearPos, targetPos)

            if distToLane < 250 then
                asg.phase = "wait"
                asg.phaseTime = now
            elseif now - asg.phaseTime > 30 then
                table.remove(State.assignments, i)
            else

                if not asg.towerWPReached and asg.towerWaypoint then
                    if Dist2D(bearPos, asg.towerWaypoint) < 200 then
                        asg.towerWPReached = true
                    end
                end

                if now - asg.lastSteerTime >= 0.5 then
                    local target
                    if not asg.towerWPReached and asg.towerWaypoint then
                        target = asg.towerWaypoint
                    else
                        target = targetPos
                    end
                    Player.PrepareUnitOrders(
                        myPlayer,
                        Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION,
                        nil,
                        target,
                        nil,
                        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                        bear,
                        false, false, false, false,
                        "bear_pull_travel"
                    )
                    asg.lastSteerTime = now
                end
            end

        elseif asg.phase == "wait" then

            local creepsHere = HasEnemyCreepsNear(asg.pullPos or asg.lanePos, 500)

            if creepsHere then

                asg.phase = "aggro"
                asg.phaseTime = now

                Player.PrepareUnitOrders(
                    myPlayer,
                    Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_MOVE,
                    nil,
                    asg.pullPos or asg.lanePos,
                    nil,
                    Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                    bear,
                    false, false, false, false,
                    "bear_pull_aggro"
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
            local distToHero = Dist2D(bearPos, heroPos)

            if not asg.gridPath or not asg.gridPathTime or (now - asg.gridPathTime > 3) then
                local safeTarget = GetSafeRetreatPos(bearPos, heroPos, 900)
                asg.gridPath = BuildGridNavPath(bear, bearPos, safeTarget)
                asg.gridPathIdx = 1
                asg.gridPathTime = now
            end

            if not asg.reaggroUntil then asg.reaggroUntil = 0 end
            if not asg.reaggroCooldown then asg.reaggroCooldown = 0 end
            if not asg.lastTraversableCheck then asg.lastTraversableCheck = 0 end

            if now - asg.lastTraversableCheck >= 0.5 and now > asg.reaggroUntil and now > asg.reaggroCooldown then
                asg.lastTraversableCheck = now

                local lp = asg.lanePos or bearPos
                local backDx, backDy = lp.x - bearPos.x, lp.y - bearPos.y
                local backDist = math.sqrt(backDx * backDx + backDy * backDy)
                if backDist > 50 then
                    local backPos = Vector(
                        bearPos.x + backDx / backDist * 400,
                        bearPos.y + backDy / backDist * 400,
                        bearPos.z
                    )

                    local canPass = GridNav.IsTraversableFromTo(bearPos, backPos, true)
                    if not canPass then

                        asg.reaggroUntil = now + 1.2
                        asg.reaggroCooldown = now + 5.0
                    end
                end
            end

            local wp = asg.gridPath and asg.gridPath[asg.gridPathIdx]
            if wp and Dist2D(bearPos, wp) < 150 then
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
                        bearPos,
                        nil,
                        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                        bear,
                        false, false, false, false,
                        "bear_pull_reaggro"
                    )
                    asg.lastSteerTime = now
                end
            else

                local creepsAggroed = false
                local myHeroEnt = Heroes.GetLocal()
                local teamNum = myHeroEnt and Entity.GetTeamNum(myHeroEnt) or 0
                local nearCreeps = NPCs.InRadius(bearPos, 700, teamNum, Enum.TeamType.TEAM_ENEMY)
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
                            bear,
                            false, false, false, false,
                            "bear_pull_retreat"
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
                            bear,
                            false, false, false, false,
                            "bear_pull_retreat"
                        )
                        asg.lastSteerTime = now
                    end
                end
            end
        end

        ::continue::
    end
end

local function StopAssignments()
    local player = Players.GetLocal()
    if player then
        for _, asg in ipairs(State.assignments) do
            if asg.bear and Entity.IsAlive(asg.bear) then
                Player.PrepareUnitOrders(
                    player,
                    Enum.UnitOrder.DOTA_UNIT_ORDER_STOP,
                    nil,
                    nil,
                    nil,
                    Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                    asg.bear,
                    false, false, false, false,
                    "bear_pull_stop"
                )
            end
        end
    end
    State.assignments = {}
end

local function drawPullText()
    if not UI._pulltext:Get() then return end
    if #State.assignments == 0 then return end

    local myHero = Heroes.GetLocal()
    if not myHero then return end

    local heroPos = Entity.GetAbsOrigin(myHero)
    local abovePos = Vector(heroPos.x, heroPos.y, heroPos.z + 200)
    local sp, vis = Render.WorldToScreen(abovePos)
    if not vis then return end

    local txt = localization.Get("ui.pulling")
    local tSize = Render.TextSize(Fonts.Main, 14, txt)
    local tx = sp.x - tSize.x / 2
    local ty = sp.y - tSize.y / 2
    Render.Text(Fonts.Main, 14, txt, Vec2(tx + 1, ty + 1), Color(0, 0, 0, 180))
    Render.Text(Fonts.Main, 14, txt, Vec2(tx, ty), Color(255, 200, 100, 255))
end

local function drawLines()
    if not UI._debuglines:Get() then return end

    for _, asg in ipairs(State.assignments) do
        local bear = asg.bear
        if not bear or not Entity.IsAlive(bear) then goto cont end

        local bearPos = Entity.GetAbsOrigin(bear)
        local sSp, sOk = Render.WorldToScreen(bearPos)
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

bear_pull.OnUpdate = function()
    if not IsLoneDruid() or not UI.Enabled:Get() then return end

    if #State.assignments > 0 then
        local player = Players.GetLocal()
        if player then
            local selected = Player.GetSelectedUnits(player) or {}
            if #selected > 0 then
                local clean = {}
                local dirty = false
                for _, u in ipairs(selected) do
                    if IsBearAssigned(u) then
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
        elseif #State.assignments > 0 then
            StopAssignments()
        end
    else
        if UI.Key:IsPressed() then
            State.pullToggled = not State.pullToggled
            if State.pullToggled then
                DispatchPull()
            else
                StopAssignments()
            end
        end
    end

    UpdateAssignments()

end

bear_pull.OnDraw = function()
    if not IsLoneDruid() or not UI.Enabled:Get() then return end

    drawLines()
    drawPullText()
end

bear_pull.OnPrepareUnitOrders = function(data)
    if not IsLoneDruid() or not UI.Enabled:Get() then return true end
    if #State.assignments == 0 then return true end

    if data.identifier == "bear_pull_travel"
    or data.identifier == "bear_pull_aggro"
    or data.identifier == "bear_pull_retreat"
    or data.identifier == "bear_pull_reaggro"
    or data.identifier == "bear_pull_relay"
    or data.identifier == "bear_pull_stop" then
        return true
    end

    if data.npc and IsBearAssigned(data.npc) then
        return false
    end

    if data.orderIssuer == Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_SELECTED_UNITS then
        local player = Players.GetLocal()
        if player then
            local selected = Player.GetSelectedUnits(player) or {}
            local allowed = {}
            local hasLocked = false

            for _, u in ipairs(selected) do
                if IsBearAssigned(u) then
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
                        "bear_pull_relay"
                    )
                end
                return false
            end
        end
    end

    return true
end

bear_pull.OnGameEnd = function()
    State.assignments = {}
    State.pullToggled = false
    State.cachedTowers = nil
end

return bear_pull
