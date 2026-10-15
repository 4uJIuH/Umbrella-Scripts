local iceWallFarm = {}

local tab = Menu.Create("Heroes", "Hero List", "Invoker", "Ice Wall Farm")
local main = tab:Create("Main")
local ui = {}

ui.enabled = main:Switch("Enable", true, "panorama/images/spellicons/invoker_ice_wall_png.vtex_c")
ui.autoCast = main:Switch("Auto Cast Ice Wall", false)
ui.showSpot = main:Switch("Show Farm Spot", true)

-- Ice Wall Indicator settings
ui.lineLength = main:Slider("Line Length", 50, 400, 200, "%d")
ui.distance = main:Slider("Distance from Hero", 20, 150, 70, "%d")
ui.lineAlpha = main:Slider("Line Alpha", 50, 255, 200, "%d")
ui.dotAlpha = main:Slider("Dots Alpha", 50, 255, 255, "%d")
ui.lineThickness = main:Slider("Line Thickness", 1, 6, 3, "%d")
ui.dotSize = main:Slider("Dots Size", 2, 10, 5, "%d")
ui.color = main:ColorPicker("Color", Color(0, 150, 255, 255))

local farmSpots = {
    {
        pos = Vector(-1548, -4365, 128),
        yaw = 153.3
    },
    {
        pos = Vector(1511, 2988, 128),
        yaw = 165
    }
}

function iceWallFarm.OnUpdate()
    if not ui.enabled:Get() then return end

    local me = Heroes.GetLocal()

    if not me or NPC.GetUnitName(me) ~= "npc_dota_hero_invoker" then
        return
    end

    local myPos = Entity.GetAbsOrigin(me)

    local currentSpot = nil
    local closestDist = 999999

    for _, spot in pairs(farmSpots) do
        local dist = (spot.pos - myPos):Length2D()

        if dist < closestDist then
            closestDist = dist
            currentSpot = spot
        end
    end

    if not currentSpot then return end

    local farmSpot = currentSpot.pos
    local targetYaw = currentSpot.yaw

    local distToSpot = (farmSpot - myPos):Length2D()

    local rotation = Entity.GetRotation(me)
    local yaw = rotation.yaw or 0

    local angleDiff = math.abs(yaw - targetYaw)

    if angleDiff > 180 then
        angleDiff = 360 - angleDiff
    end

    if ui.autoCast:Get() and distToSpot < 100 and angleDiff < 5 then
        local iceWall = NPC.GetAbility(me, "invoker_ice_wall")

        if iceWall and Ability.IsCastable(iceWall, NPC.GetMana(me)) then
            Ability.CastNoTarget(iceWall)
        end
    end
end

function iceWallFarm.OnDraw()
    if not ui.enabled:Get() then return end

    local me = Heroes.GetLocal()

    if not me or NPC.GetUnitName(me) ~= "npc_dota_hero_invoker" then
        return
    end

    local myPos = Entity.GetAbsOrigin(me)

    local currentSpot = nil
    local closestDist = 999999

    for _, spot in pairs(farmSpots) do
        local dist = (spot.pos - myPos):Length2D()

        if dist < closestDist then
            closestDist = dist
            currentSpot = spot
        end
    end

    if not currentSpot then return end

    local farmSpot = currentSpot.pos
    local targetYaw = currentSpot.yaw

    local rotation = Entity.GetRotation(me)
    local yaw = rotation.yaw or 0

    local distToSpot = math.floor((farmSpot - myPos):Length2D())

    local angleDiff = math.floor(math.abs(yaw - targetYaw))

    if angleDiff > 180 then
        angleDiff = 360 - angleDiff
    end

    -- MOVE HERE spot
    if ui.showSpot:Get() then
        local spotScreen, spotVis = Render.WorldToScreen(farmSpot)

        if spotVis then
            local spotColor =
                distToSpot > 100 and Color(255, 0, 0, 255)
                or Color(0, 255, 0, 255)

            Render.FilledCircle(Vec2(spotScreen.x, spotScreen.y), 10, spotColor)

            local font = Render.LoadFont("Arial", 0, 12)

            if font and distToSpot > 100 then
                Render.Text(
                    font,
                    12,
                    "MOVE HERE",
                    Vec2(spotScreen.x + 15, spotScreen.y - 5),
                    Color(255, 0, 0, 255)
                )
            end
        end
    end

    local screenPos, visible = Render.WorldToScreen(myPos)

    if not visible then
        return
    end

    local x = screenPos.x
    local y = screenPos.y

    -- TURN indicator
    if distToSpot < 150 and angleDiff > 10 then
        local angleRad = targetYaw * math.pi / 180

        local cosA = math.cos(angleRad)
        local sinA = math.sin(angleRad)

        local turnX = x + cosA * 30
        local turnY = y - sinA * 30

        Render.FilledCircle(Vec2(turnX, turnY), 8, Color(255, 165, 0, 200))

        local font = Render.LoadFont("Arial", 0, 12)

        if font then
            Render.Text(
                font,
                12,
                "TURN",
                Vec2(turnX + 10, turnY - 5),
                Color(255, 165, 0, 255)
            )
        end
    end

    -- Ice Wall line indicator
    local halfLength = ui.lineLength:Get() / 2
    local offsetY = ui.distance:Get()

    local baseColor = ui.color:Get()

    local lineColor = Color(
        baseColor.r,
        baseColor.g,
        baseColor.b,
        ui.lineAlpha:Get()
    )

    local dotColor = Color(
        baseColor.r,
        baseColor.g,
        baseColor.b,
        ui.dotAlpha:Get()
    )

    local thickness = ui.lineThickness:Get()
    local dotSize = ui.dotSize:Get()

    local angleRad = yaw * math.pi / 180

    local cosA = math.cos(angleRad)
    local sinA = math.sin(angleRad)

    local centerX = x + cosA * offsetY
    local centerY = y - sinA * offsetY

    local leftX = centerX - sinA * halfLength
    local leftY = centerY - cosA * halfLength

    local rightX = centerX + sinA * halfLength
    local rightY = centerY + cosA * halfLength

    Render.Line(
        Vec2(leftX, leftY),
        Vec2(rightX, rightY),
        lineColor,
        thickness
    )

    Render.FilledCircle(
        Vec2(leftX, leftY),
        dotSize,
        dotColor
    )

    Render.FilledCircle(
        Vec2(rightX, rightY),
        dotSize,
        dotColor
    )
end

return iceWallFarm