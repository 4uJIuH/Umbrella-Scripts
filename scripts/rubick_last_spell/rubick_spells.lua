local CFG = {
    enabled        = true,
    showItems      = false,
    persist        = false,
    duration       = 6,
    iconSize       = 48,
    maxDistance    = 0,
    bgColor        = nil,
    offsetX        = 0,
    offsetY        = 40,
}

local function safe(fn, ...)
    local ok, a, b, c = pcall(fn, ...)
    if ok then return a, b, c end
    return nil
end

local function isIllusion(npc)
    if NPC.IsIllusion then return NPC.IsIllusion(npc) == true end
    return false
end

local iconCache = {}

local function getIconPath(abilityName)

    local defaultName = safe(Ability.GetDefaultName, abilityName)
    local iconBase = defaultName or abilityName

    if abilityName:sub(1, 5) == "item_" then

        return "panorama/images/items/" .. iconBase .. "_png.vtex_c"
    else
        return "panorama/images/spellicons/" .. iconBase .. "_png.vtex_c"
    end
end

local function getIconHandle(abilityName)
    local cached = iconCache[abilityName]
    if cached ~= nil then

        return cached ~= false and cached or nil
    end

    local path   = getIconPath(abilityName)
    local handle = safe(Render.LoadImage, path)

    if handle and handle ~= 0 then
        iconCache[abilityName] = handle
        return handle
    else

        iconCache[abilityName] = false
        return nil
    end
end

local state = {}

local function getState(hero)
    local s = state[hero]
    if not s then
        s = { cd = {}, last = nil, wasVisible = false }
        state[hero] = s
    end
    return s
end

local dragState = {
    dragging = false,
    startMouseX = 0,
    startMouseY = 0,
    startOffsetX = 0,
    startOffsetY = 0,
}

local M = {}

local function buildMenu()
    if not Menu or not Menu.Create then return end

    local grp = Menu.Create("Heroes", "Rubick", "Last Spell ESP", "Main", "Settings")
    if not grp then return end

    M.enabled  = grp:Switch("Enabled", CFG.enabled, "\u{f06e}")
    M.showItem = grp:Switch("Track items too", CFG.showItems)
    M.persist  = grp:Switch("Keep until next cast", CFG.persist)
    M.duration = grp:Slider("Show duration", 1, 20, CFG.duration, "%ds")
    M.iconSize = grp:Slider("Icon size", 16, 128, CFG.iconSize, "%dpx")
    M.maxDist  = grp:Slider("Max distance (0=all)", 0, 6000, CFG.maxDistance, "%d")
    M.bgColor  = grp:ColorPicker("Background", CFG.bgColor)
    M.offsetX  = grp:Slider("Horizontal offset", -500, 500, CFG.offsetX, "%d")
    M.offsetY  = grp:Slider("Vertical offset", -200, 200, CFG.offsetY, "%d")
end

local function cEnabled()   if M.enabled  then return M.enabled:Get()  end return CFG.enabled      end
local function cShowItems() if M.showItem then return M.showItem:Get() end return CFG.showItems    end
local function cPersist()   if M.persist  then return M.persist:Get()  end return CFG.persist      end
local function cDuration()  if M.duration then return M.duration:Get() end return CFG.duration     end
local function cIconSize()  if M.iconSize then return M.iconSize:Get() end return CFG.iconSize     end
local function cMaxDist()   if M.maxDist  then return M.maxDist:Get()  end return CFG.maxDistance  end
local function cBgColor()   if M.bgColor  then return M.bgColor:Get()  end return CFG.bgColor      end
local function cOffsetX()   if M.offsetX  then return M.offsetX:Get()  end return CFG.offsetX      end
local function cOffsetY()   if M.offsetY  then return M.offsetY:Get()  end return CFG.offsetY      end

local function isValidEnemy(localHero, hero)
    if not hero or hero == localHero then return false end
    if not Entity.IsAlive(hero) then return false end
    if isIllusion(hero) then return false end
    if Entity.IsSameTeam(hero, localHero) then return false end
    return true
end

local function OnUpdate()
    if not cEnabled() then return end

    local localHero = Heroes.GetLocal()
    if not localHero then return end

    local now      = GameRules.GetGameTime()
    local showItem = cShowItems()

    for _, hero in pairs(Heroes.GetAll()) do
        if isValidEnemy(localHero, hero) then
            local s       = getState(hero)
            local dormant = Entity.IsDormant(hero)

            if dormant then

                s.wasVisible = false
            else
                local hadData = s.wasVisible

                for i = 0, 30 do
                    local ab = NPC.GetAbilityByIndex(hero, i)
                    if ab then
                        local name = Ability.GetName(ab)
                        local isItem = name:sub(1, 5) == "item_"
                        local skip =
                            name == "" or
                            name:sub(1, 14) == "special_bonus_" or
                            (isItem and not showItem)

                        if not skip then
                            local curCd = Ability.GetCooldown(ab) or 0
                            local prev  = s.cd[name]

                            if hadData and prev ~= nil and curCd > prev + 0.1 then
                                local slu = Ability.SecondsSinceLastUse(ab) or -1

                                if slu >= 0 and slu < 1.5 then
                                    s.last = { name = name, time = now,
                                               item = isItem,
                                               unit = NPC.GetUnitName(hero) }
                                end
                            end

                            s.cd[name] = curCd
                        end
                    end
                end

                s.wasVisible = true
            end
        end
    end
end

local function isMenuOpen()
    if Menu and Menu.IsOpen then
        return Menu.IsOpen()
    end
    return false
end

local function isMouseOver(mx, my, x1, y1, x2, y2)
    return mx >= x1 and mx <= x2 and my >= y1 and my <= y2
end

local function OnDraw()
    if not cEnabled() then return end
    if not Render or not Render.WorldToScreen then return end

    local localHero = Heroes.GetLocal()
    if not localHero then return end

    local now      = GameRules.GetGameTime()
    local persist  = cPersist()
    local dur      = cDuration()
    local iconSize = cIconSize()
    local maxDist  = cMaxDist()
    local bgCol    = cBgColor()
    local offsetX  = cOffsetX()
    local offsetY  = cOffsetY()

    local localPos = Entity.GetAbsOrigin(localHero)
    local menuOpen = isMenuOpen()

    local mouseX, mouseY = 0, 0
    local mouseDown = false
    if menuOpen and Input then
        mouseX = safe(Input.GetCursorPos) and Input.GetCursorPos().x or 0
        mouseY = safe(Input.GetCursorPos) and Input.GetCursorPos().y or 0
        mouseDown = safe(Input.IsKeyDown, 1) or false
    end

    if menuOpen and dragState.dragging then
        if mouseDown then
            local deltaX = mouseX - dragState.startMouseX
            local deltaY = mouseY - dragState.startMouseY

            if M.offsetX then M.offsetX:Set(dragState.startOffsetX + deltaX) end
            if M.offsetY then M.offsetY:Set(dragState.startOffsetY + deltaY) end

            offsetX = dragState.startOffsetX + deltaX
            offsetY = dragState.startOffsetY + deltaY
        else

            dragState.dragging = false
        end
    end

    for _, hero in pairs(Heroes.GetAll()) do
        if isValidEnemy(localHero, hero) and not Entity.IsDormant(hero) then
            local s = state[hero]
            if s and s.last then
                local age  = now - s.last.time
                local show = persist or age <= dur

                if show and maxDist > 0 then
                    local d = (Entity.GetAbsOrigin(hero) - localPos):Length()
                    if d > maxDist then show = false end
                end

                if show then

                    local alpha = 255
                    if not persist then
                        local remain = dur - age
                        if remain < 1.0 then
                            alpha = math.max(0, math.floor(255 * remain))
                        end
                    end

                    local offset = safe(NPC.GetHealthBarOffset, hero) or 200
                    local origin = Entity.GetAbsOrigin(hero)
                    local worldPos = Vector(origin.x, origin.y, origin.z + offset)

                    local sp, visible = Render.WorldToScreen(worldPos)
                    if visible then

                        local half = iconSize / 2
                        local ix = sp.x - half + offsetX
                        local iy = sp.y - iconSize + offsetY

                        local boxX1 = ix - 4
                        local boxY1 = iy - 4
                        local boxX2 = ix + iconSize + 4
                        local boxY2 = iy + iconSize + 4

                        if menuOpen then
                            local isHovered = isMouseOver(mouseX, mouseY, boxX1, boxY1, boxX2, boxY2)

                            if mouseDown and not dragState.dragging and isHovered then
                                dragState.dragging = true
                                dragState.startMouseX = mouseX
                                dragState.startMouseY = mouseY
                                dragState.startOffsetX = cOffsetX()
                                dragState.startOffsetY = cOffsetY()
                            end

                            if isHovered or dragState.dragging then
                                local hoverCol = Color(100, 150, 255, 100)
                                Render.FilledRect(
                                    Vec2(boxX1 - 2, boxY1 - 2),
                                    Vec2(boxX2 + 2, boxY2 + 2),
                                    hoverCol, 4)
                            end
                        end

                        local bg = bgCol or Color(0, 0, 0, 160)
                        bg = Color(bg.r, bg.g, bg.b, math.floor((bg.a or 160) * alpha / 255))
                        Render.FilledRect(
                            Vec2(boxX1, boxY1),
                            Vec2(boxX2, boxY2),
                            bg, 4)

                        local handle = getIconHandle(s.last.name)
                        if handle then
                            local tint = Color(255, 255, 255, alpha)
                            Render.Image(
                                handle,
                                Vec2(ix, iy),
                                Vec2(iconSize, iconSize),
                                tint,
                                4)
                        else

                            local fallback = Color(255, 80, 80, alpha)
                            Render.FilledRect(
                                Vec2(ix, iy),
                                Vec2(ix + iconSize, iy + iconSize),
                                fallback, 4)
                        end

                        Render.Rect(
                            Vec2(ix - 1, iy - 1),
                            Vec2(ix + iconSize + 1, iy + iconSize + 1),
                            Color(0, 0, 0, alpha),
                            4, 1.5)
                    end
                end
            end
        end
    end
end

local function init()

    CFG.bgColor = Color(0, 0, 0, 160)
    pcall(buildMenu)
end

init()

return {
    OnUpdate = OnUpdate,
    OnDraw   = OnDraw,
}