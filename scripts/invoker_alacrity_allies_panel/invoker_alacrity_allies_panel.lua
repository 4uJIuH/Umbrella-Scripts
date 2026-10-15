local alacrityPanel = {}

local tab = Menu.Create("Heroes", "Hero List", "Invoker", "Alacrity Allies Panel")
local main = tab:Create("Main")
local ui = {}

ui.enabled = main:Switch("Enable", true, "panorama/images/spellicons/invoker_alacrity_png.vtex_c")
ui.iconSize = main:Slider("Icon Size", 24, 72, 42, "%d")
ui.iconSize:Icon("\u{f03e}")
ui.searchRange = main:Slider("Alacrity Ally Range", 250, 1200, 700, "%d")
ui.searchRange:Icon("\u{f124}")
ui.searchRange:ToolTip("Distance around Invoker for choosing enabled allies.")

db.invokerAlacrityAlliesPanel = db.invokerAlacrityAlliesPanel or {}
local saved = db.invokerAlacrityAlliesPanel

local state = {
    panelPos = Vec2(saved.x or 120, saved.y or 260),
    draggingPanel = false,
    dragOffset = Vec2(0, 0),
    mouseWasDown = false,
    hoverAlpha = 0,
    allies = {},
    images = {},
    lastGameTime = -1
}

local colors = {
    panelBg = Color(0, 0, 0, 180),
    panelHover = Color(18, 24, 26, 205),
    shadow = Color(0, 0, 0, 95),
    text = Color(205, 218, 214, 255),
    muted = Color(120, 132, 130, 255),
    enabled = Color(0, 255, 96, 255),
    disabled = Color(95, 95, 95, 230),
    hover = Color(255, 255, 255, 35),
    inner = Color(20, 24, 26, 220)
}

local function approach(current, target, step)
    if current < target then
        return math.min(current + step, target)
    elseif current > target then
        return math.max(current - step, target)
    end
    return current
end

local function getMyHero()
    return Heroes.GetLocal()
end

local function isInvoker(hero)
    return hero and NPC.GetUnitName(hero) == "npc_dota_hero_invoker"
end

local function getHeroName(hero)
    return hero and NPC.GetUnitName(hero) or nil
end

local function getAllies()
    local me = getMyHero()
    if not me then
        return {}
    end

    local allies = {}
    for _, hero in pairs(Heroes.GetAll()) do
        if hero
            and hero ~= me
            and Entity.IsSameTeam(hero, me)
            and not NPC.IsIllusion(hero)
        then
            table.insert(allies, hero)
        end
    end

    table.sort(allies, function(a, b)
        return (getHeroName(a) or "") < (getHeroName(b) or "")
    end)

    return allies
end

local function ensureAllyState(hero)
    local name = getHeroName(hero)
    if not name then
        return nil
    end

    if not state.allies[name] then
        state.allies[name] = {
            enabled = false,
            hoverAlpha = 0,
            flashUntil = 0
        }
    end

    return state.allies[name]
end

local function getHeroImage(heroName)
    if not heroName then
        return nil
    end

    if state.images[heroName] == false then
        return nil
    end

    if not state.images[heroName] then
        local ok, image = pcall(function()
            return Render.LoadImage("panorama/images/heroes/" .. heroName .. "_png.vtex_c")
        end)
        state.images[heroName] = ok and image or false
    end

    return state.images[heroName]
end

local function pointInRect(pos, rect)
    return pos.x >= rect.x
        and pos.x <= rect.x + rect.w
        and pos.y >= rect.y
        and pos.y <= rect.y + rect.h
end

local function findBestEnabledAlly(hero, alacrity)
    if not hero or not alacrity then
        return nil
    end

    local configuredRange = ui.searchRange:Get()
    local castRange = (Ability.GetCastRange(alacrity) or configuredRange) + (NPC.GetCastRangeBonus(hero) or 0)
    local searchRange = math.min(configuredRange, math.max(castRange + 75, 250))
    local heroPos = Entity.GetAbsOrigin(hero)
    local bestAlly = nil
    local bestDistance = searchRange + 1

    for _, ally in ipairs(getAllies()) do
        local allyState = ensureAllyState(ally)
        if allyState
            and allyState.enabled
            and Entity.IsAlive(ally)
            and not Entity.IsDormant(ally)
        then
            local distance = (Entity.GetAbsOrigin(ally) - heroPos):Length2D()
            if distance <= searchRange and distance < bestDistance then
                bestDistance = distance
                bestAlly = ally
            end
        end
    end

    return bestAlly
end

local function drawPanel()
    if not ui.enabled:Get() then
        return
    end

    local me = getMyHero()
    if not isInvoker(me) then
        return
    end

    local allies = getAllies()
    if #allies == 0 then
        return
    end

    local mx, my = Input.GetCursorPos()
    local mouse = Vec2(mx, my)
    local mouseDown = Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE1)
    local mouseReleased = state.mouseWasDown and not mouseDown
    state.mouseWasDown = mouseDown

    local iconH = ui.iconSize:Get()
    local iconW = math.floor(iconH * 1.58)
    local gap = 4
    local padding = 6
    local headerH = 15
    local totalIconsW = (#allies * iconW) + ((#allies - 1) * gap)
    local panelW = math.max(132, totalIconsW + padding * 2)
    local panelH = headerH + iconH + padding * 2 + 2
    local panelRect = { x = state.panelPos.x, y = state.panelPos.y, w = panelW, h = panelH }
    local panelHovered = pointInRect(mouse, panelRect)

    if panelHovered and Input.IsKeyDown(Enum.ButtonCode.KEY_LCONTROL) and Input.IsKeyDownOnce(Enum.ButtonCode.KEY_MOUSE1) then
        state.draggingPanel = true
        state.dragOffset = state.panelPos - mouse
    end

    if state.draggingPanel and mouseDown then
        state.panelPos = mouse + state.dragOffset
        saved.x = state.panelPos.x
        saved.y = state.panelPos.y
    elseif state.draggingPanel and not mouseDown then
        state.draggingPanel = false
    end

    state.hoverAlpha = approach(state.hoverAlpha, panelHovered and 1 or 0, 0.08)
    local bg = state.hoverAlpha > 0.01 and colors.panelHover or colors.panelBg

    Render.FilledRect(state.panelPos + Vec2(2, 2), state.panelPos + Vec2(panelW + 2, panelH + 2), colors.shadow, 5, Enum.DrawFlags.RoundCornersAll)
    Render.FilledRect(state.panelPos, state.panelPos + Vec2(panelW, panelH), bg, 5, Enum.DrawFlags.RoundCornersAll)
    Render.Text(1, 10, "Alacrity", state.panelPos + Vec2(padding, 4), colors.text)
    Render.Text(1, 9, "Ctrl+drag", state.panelPos + Vec2(panelW - 52, 5), colors.muted)

    local startX = state.panelPos.x + ((panelW - totalIconsW) / 2)
    local startY = state.panelPos.y + headerH + padding
    local now = GameRules.GetGameTime() or 0

    for i, ally in ipairs(allies) do
        local heroName = getHeroName(ally)
        local allyState = ensureAllyState(ally)
        local x = startX + (i - 1) * (iconW + gap)
        local y = startY
        local rect = { x = x, y = y, w = iconW, h = iconH }
        local hovered = pointInRect(mouse, rect)

        if hovered and mouseReleased and not state.draggingPanel and not Input.IsKeyDown(Enum.ButtonCode.KEY_LCONTROL) then
            allyState.enabled = not allyState.enabled
        end

        allyState.hoverAlpha = approach(allyState.hoverAlpha, hovered and 1 or 0, 0.12)

        local border = allyState.enabled and colors.enabled or colors.disabled
        if allyState.flashUntil and allyState.flashUntil > now then
            border = Color(120, 255, 160, 255)
        end

        Render.FilledRect(Vec2(x, y), Vec2(x + iconW, y + iconH), border, 4, Enum.DrawFlags.RoundCornersAll)
        Render.FilledRect(Vec2(x + 2, y + 2), Vec2(x + iconW - 2, y + iconH - 2), colors.inner, 3, Enum.DrawFlags.RoundCornersAll)

        local image = getHeroImage(heroName)
        if image then
            local alpha = allyState.enabled and 255 or 115
            if not Entity.IsAlive(ally) then
                alpha = 75
            end
            Render.ImageCentered(image, Vec2(x + iconW / 2, y + iconH / 2), Vec2(iconW - 5, iconH - 5), Color(255, 255, 255, alpha), 3, Enum.DrawFlags.RoundCornersAll)
        end

        if allyState.hoverAlpha > 0.01 then
            Render.FilledRect(Vec2(x + 2, y + 2), Vec2(x + iconW - 2, y + iconH - 2), Color(colors.hover.r, colors.hover.g, colors.hover.b, math.floor(colors.hover.a * allyState.hoverAlpha)), 3, Enum.DrawFlags.RoundCornersAll)
        end
    end
end

function alacrityPanel.OnPrepareUnitOrders(order)
    if not ui.enabled:Get() then
        return true
    end

    local localPlayer = Players.GetLocal()
    if not localPlayer or order.player ~= localPlayer then
        return true
    end

    local hero = getMyHero()
    if not isInvoker(hero) or order.npc ~= hero then
        return true
    end

    local ability = order.ability
    if not ability or Ability.GetName(ability) ~= "invoker_alacrity" then
        return true
    end

    if not Ability.IsCastable(ability, NPC.GetMana(hero)) then
        return true
    end

    local target = findBestEnabledAlly(hero, ability)
    if not target then
        return true
    end

    local targetState = ensureAllyState(target)
    if targetState then
        targetState.flashUntil = (GameRules.GetGameTime() or 0) + 0.35
    end

    Ability.CastTarget(ability, target, false, false, true, "invoker_alacrity_green_ally")
    return false
end

function alacrityPanel.OnDraw()
    drawPanel()
end

function alacrityPanel.OnGameEnd()
    state.allies = {}
    state.images = {}
    state.mouseWasDown = false
    state.draggingPanel = false
end

return alacrityPanel
