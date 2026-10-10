local script = {}

local localization = qLocalization.new({
    en = {
        ui = {
            tab = "Earth Spirit Kick Combo",
            settings = "Settings",
            enable = "Enable",
            key = "Combo key",
            panelKey = "Open ally panel",
            selected = "Selected allies",
            targetMode = "Kick direction",
            adaptive = "Adaptive",
            nearestSelected = "Nearest selected ally",
        },
    },
    ru = {
        ui = {
            tab = "Комбо Earth Spirit",
            settings = "Настройки",
            enable = "Включить",
            key = "Клавиша комбо",
            panelKey = "Открыть панель союзников",
            selected = "Выбрано союзников",
            targetMode = "Направление кика",
            adaptive = "Адаптивный",
            nearestSelected = "Ближайший выбранный союзник",
        },
    },
})

local Menu = localization.WrapLibrary(Menu)
local tab = Menu.Create("General", "Main", "Earth Spirit Kick Combo")
tab:Icon("\u{f0c1}")

local settings = tab:Create("ui.settings"):Create("Main")
local enabled = settings:Switch("ui.enable", true)
local key = settings:Bind("ui.key", Enum.ButtonCode.KEY_NONE, "\u{f0c1}")
local panelKey = settings:Bind("ui.panelKey", Enum.ButtonCode.KEY_NONE, "\u{f0c1}")
local targetMode = settings:Combo(
    "ui.targetMode",
    { "ui.adaptive", "ui.nearestSelected" },
    0
)

local allies = {}
local allyUpdateTime = 0
local combo = nil
local panelOpen = false
local selectedAllies = {}
local heroImages = {}
local panelFont = Render.LoadFont("Verdana", Enum.FontCreate.FONTFLAG_ANTIALIAS)

local function Distance2D(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

local function Normalize2D(v)
    local length = math.sqrt(v.x * v.x + v.y * v.y)
    if length < 0.001 then return Vector(1, 0, 0) end
    return Vector(v.x / length, v.y / length, 0)
end

local function Add(a, b)
    return Vector(a.x + b.x, a.y + b.y, a.z or 0)
end

local function Sub(a, b)
    return Vector(a.x - b.x, a.y - b.y, (a.z or 0) - (b.z or 0))
end

local function Scale(v, value)
    return Vector(v.x * value, v.y * value, (v.z or 0) * value)
end

local function GetAllies(hero)
    local result = {}
    local team = Entity.GetTeamNum(hero)

    for _, ally in ipairs(Heroes.GetAll()) do
        if ally ~= hero
            and Entity.GetTeamNum(ally) == team
            and Entity.IsAlive(ally)
            and not Entity.IsDormant(ally)
        then
            table.insert(result, ally)
        end
    end

    table.sort(result, function(a, b)
        return Hero.GetPlayerID(a) < Hero.GetPlayerID(b)
    end)

    return result
end

local function UpdateAllySelector(hero, now)
    if now - allyUpdateTime < 1 then return end
    allyUpdateTime = now

    allies = GetAllies(hero)
end

local function GetNearestAlly(hero, candidates)
    local heroPos = Entity.GetAbsOrigin(hero)
    local nearest
    local nearestDistance

    for _, ally in ipairs(candidates) do
        if Entity.IsAlive(ally) then
            local distance = Distance2D(heroPos, Entity.GetAbsOrigin(ally))
            if not nearestDistance or distance < nearestDistance then
                nearest = ally
                nearestDistance = distance
            end
        end
    end

    return nearest
end

local function GetSelectedAlly(hero)
    local selected = {}
    for _, ally in ipairs(allies) do
        if selectedAllies[Entity.GetIndex(ally)] and Entity.IsAlive(ally) then
            table.insert(selected, ally)
        end
    end

    return GetNearestAlly(hero, selected)
end

local function GetNearestTowerPosition(hero)
    local heroPos = Entity.GetAbsOrigin(hero)
    local team = Entity.GetTeamNum(hero)
    local nearest
    local nearestDistance

    for _, unit in pairs(NPCs.GetAll()) do
        if unit
            and Entity.IsAlive(unit)
            and Entity.GetTeamNum(unit) == team
            and NPC.IsTower(unit)
        then
            local distance = Distance2D(heroPos, Entity.GetAbsOrigin(unit))
            if distance <= 1000 and (not nearestDistance or distance < nearestDistance) then
                nearest = Entity.GetAbsOrigin(unit)
                nearestDistance = distance
            end
        end
    end

    return nearest
end

local function GetBasePosition(hero)
    local team = Entity.GetTeamNum(hero)

    for _, unit in pairs(NPCs.GetAll()) do
        if unit
            and Entity.IsAlive(unit)
            and Entity.GetTeamNum(unit) == team
            and Entity.GetUnitName(unit) == "npc_dota_fountain"
        then
            return Entity.GetAbsOrigin(unit)
        end
    end
end

local function GetKickTarget(hero)
    local selected = GetSelectedAlly(hero)
    if selected then
        return Entity.GetAbsOrigin(selected)
    end

    local nearest = GetNearestAlly(hero, allies)
    if nearest then
        return Entity.GetAbsOrigin(nearest)
    end

    if targetMode:Get() == 0 then
        local towerPosition = GetNearestTowerPosition(hero)
        if towerPosition then
            return towerPosition
        end

        return GetBasePosition(hero)
    end
end

local function GetHeroImage(hero)
    local name = Entity.GetUnitName(hero)
    if not heroImages[name] then
        heroImages[name] = Render.LoadImage(
            "panorama/images/heroes/icons/" .. name .. "_png.vtex_c"
        )
    end
    return heroImages[name]
end

local function ToggleAllySelection(ally)
    local index = Entity.GetIndex(ally)
    selectedAllies[index] = not selectedAllies[index]
end

local function DrawAllyPanel()
    if not panelOpen then return end

    local screen = Render.ScreenSize()
    local width = math.max(240, #allies * 58 + 24)
    local x = (screen.x - width) / 2
    local y = 80
    local height = 92
    Render.FilledRect(Vec2(x, y), Vec2(x + width, y + height), Color(20, 20, 20, 235), 6)
    Render.Text(panelFont, 14, localization.Get("ui.selected"), Vec2(x + 12, y + 8), Color(255, 255, 255, 255))

    for i, ally in ipairs(allies) do
        local itemX = x + 12 + (i - 1) * 58
        local itemY = y + 28
        local selected = selectedAllies[Entity.GetIndex(ally)] == true
        local image = GetHeroImage(ally)

        Render.FilledRect(
            Vec2(itemX, itemY),
            Vec2(itemX + 50, itemY + 50),
            selected and Color(70, 150, 70, 255) or Color(55, 55, 55, 255),
            4
        )
        if image then
            Render.Image(image, Vec2(itemX + 3, itemY + 3), Vec2(44, 44), Color(255, 255, 255, 255), 3)
        end

        if Input.IsCursorInRect(itemX, itemY, 50, 50)
            and Input.IsKeyDownOnce(Enum.ButtonCode.KEY_MOUSE1, true)
        then
            ToggleAllySelection(ally)
        end
    end
end

local function GetComboAbilities(hero)
    local blink = NPC.GetItem(hero, "item_blink", true)
    local smash = NPC.GetAbility(hero, "earth_spirit_boulder_smash")
    if not blink or not smash then return nil, nil end
    return blink, smash
end

local function StartCombo(hero)
    local enemy = Input.GetNearestHeroToCursor(
        Entity.GetTeamNum(hero),
        Enum.TeamType.TEAM_ENEMY
    )
    local kickTarget = GetKickTarget(hero)
    local blink, smash = GetComboAbilities(hero)

    if not enemy or not kickTarget or not blink or not smash then
        return
    end

    if not Entity.IsAlive(enemy) then
        return
    end

    if not Ability.IsReady(blink) or not Ability.IsReady(smash) then
        return
    end

    local enemyPos = Entity.GetAbsOrigin(enemy)
    local direction = Normalize2D(Sub(kickTarget, enemyPos))
    local smashRange = Ability.GetCastRange(smash)
    local behindDistance = 150
    local blinkPos = Add(enemyPos, Scale(direction, -behindDistance))

    Ability.CastPosition(blink, blinkPos, false, false, true, "earth_spirit_blink")

    combo = {
        enemy = enemy,
        smash = smash,
        blinkPosition = blinkPos,
        smashRange = smashRange,
        startedAt = GameRules.GetGameTime(),
    }
end

function script.OnUpdate()
    if not enabled:Get() then
        combo = nil
        return
    end

    local hero = Heroes.GetLocal()
    if not hero or Entity.GetUnitName(hero) ~= "npc_dota_hero_earth_spirit" then
        combo = nil
        return
    end

    local now = GameRules.GetGameTime()
    UpdateAllySelector(hero, now)

    if panelKey:IsPressed() then
        panelOpen = not panelOpen
    end

    if key:IsPressed() and not combo then
        StartCombo(hero)
    end

    if not combo then return end

    local heroPos = Entity.GetAbsOrigin(hero)
    local enemyPos = Entity.GetAbsOrigin(combo.enemy)
    local blinkFinished = Distance2D(heroPos, combo.blinkPosition) <= 180
    if not blinkFinished and now - combo.startedAt < 0.8 then return end

    if Entity.IsAlive(combo.enemy)
        and Ability.IsReady(combo.smash)
        and Distance2D(heroPos, enemyPos) <= combo.smashRange + 75
    then
        Ability.CastTarget(combo.smash, combo.enemy, false, false, true, "earth_spirit_boulder_smash")
    end

    combo = nil
end

function script.OnGameEnd()
    combo = nil
    allies = {}
    selectedAllies = {}
    panelOpen = false
end

function script.OnDraw()
    DrawAllyPanel()
end

return script
