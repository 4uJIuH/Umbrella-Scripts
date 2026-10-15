-- ============================================================
--  Earth Spirit - Rolling Boulder Helper
--  UCZone API v2.0
-- ============================================================

-- ───────────────────────── CONSTANTS ─────────────────────────

local ABILITY_NAME        = "earth_spirit_rolling_boulder"
local REMNANT_NAME        = "npc_dota_earth_spirit_stone"

local BOULDER_RADIUS      = 90
local BOULDER_RANGE       = 1200
local REMNANT_BONUS       = 1200
local REMNANT_HIT_RADIUS  = BOULDER_RADIUS + 96

-- ──────────────────────── MODULE STATE ───────────────────────

local g_font = nil

-- Menu widget handles
local m_enable      = nil   -- CMenuSwitch  – master on/off
local m_showRemnant = nil   -- CMenuSwitch  – show remnant markers
local m_showStatus  = nil   -- CMenuSwitch  – show Ready/CD label
local m_lineColor   = nil   -- CMenuColorPicker – normal path colour
local m_extColor    = nil   -- CMenuColorPicker – remnant-extended colour
local m_holdKey     = nil   -- CMenuBind    – hold to show (optional)

-- ──────────────────────── MENU SETUP ─────────────────────────

local function BuildMenu()
    -- Menu.Create(firstTab, section, secondTab, thirdTab, group)
    local group = Menu.Create(
        "Scripts",
        "HEROES",
        "Earth Spirit",
        "Boulder Helper",
        "Settings"
    )

    m_enable      = group:Switch("Enable",               true)
    m_showRemnant = group:Switch("Show Remnant Markers", true)
    m_showStatus  = group:Switch("Show Status Label",    true)

    group:Label("")   -- spacer

    m_lineColor   = group:ColorPicker("Path Color",     Color(255, 145, 30, 210))
    m_extColor    = group:ColorPicker("Extended Color", Color(255, 240, 50, 220))

    group:Label("")   -- spacer

    m_holdKey     = group:Bind("Toggle Key",
        Enum.ButtonCode.BUTTON_CODE_INVALID)  -- unbound by default = always show
    m_holdKey:ToolTip("If bound, press to toggle overlay on/off")
    m_holdKey:UpdateBindList({ markAsToggle = true })
end

-- ───────────────────────── HELPERS ───────────────────────────

local function GetBoulderAbility(hero)
    for i = 0, 24 do
        local ab = NPC.GetAbilityByIndex(hero, i)
        if ab == nil then break end
        if Ability.GetName(ab) == ABILITY_NAME then return ab end
    end
    return nil
end

local function GetOwnRemnants()
    local result = {}
    for _, npc in ipairs(NPCs.GetAll()) do
        if NPC.GetUnitName(npc) == REMNANT_NAME then
            if not Entity.IsDormant(npc) and Entity.IsAlive(npc) then
                result[#result + 1] = npc
            end
        end
    end
    return result
end

local function W2S(worldPos)
    local screen, visible = Render.WorldToScreen(worldPos)
    if visible and screen then return screen end
    return nil
end

local function ClosestPointOnSegment(ax, ay, bx, by, px, py)
    local dx, dy = bx - ax, by - ay
    local len2 = dx*dx + dy*dy
    if len2 < 0.0001 then return ax, ay, 0 end
    local t = ((px - ax)*dx + (py - ay)*dy) / len2
    t = math.max(0, math.min(1, t))
    return ax + t*dx, ay + t*dy, t
end

local function IsInBoulderPath(origin, dirX, dirY, range, pos, hitRadius)
    local ex = origin.x + dirX * range
    local ey = origin.y + dirY * range
    local cx, cy, t = ClosestPointOnSegment(
        origin.x, origin.y, ex, ey, pos.x, pos.y)
    local dist = math.sqrt((pos.x-cx)^2 + (pos.y-cy)^2)
    return dist <= hitRadius, t
end

-- Build a colour from a picker value with a custom alpha override
local function WithAlpha(color, a)
    return Color(color.r, color.g, color.b, a)
end

local function DrawTunnel(startW, endW, dirX, dirY, cLine, cEdge, thick)
    local sS = W2S(startW)
    local eS = W2S(endW)
    if sS == nil and eS == nil then return end

    local perpX = -dirY * BOULDER_RADIUS
    local perpY =  dirX * BOULDER_RADIUS

    local sL = W2S(Vector(startW.x + perpX, startW.y + perpY, startW.z))
    local sR = W2S(Vector(startW.x - perpX, startW.y - perpY, startW.z))
    local eL = W2S(Vector(endW.x   + perpX, endW.y   + perpY, endW.z  ))
    local eR = W2S(Vector(endW.x   - perpX, endW.y   - perpY, endW.z  ))

    if sS and eS then Render.Line(sS, eS, cLine, thick) end
    if sL and eL then Render.Line(sL, eL, cEdge, 1.5) end
    if sR and eR then Render.Line(sR, eR, cEdge, 1.5) end
    if sL and sR then Render.Line(sL, sR, cEdge, 1.5) end
    if eL and eR then Render.Line(eL, eR, cEdge, 1.5) end
end

local function DrawImpact(worldPos, cOutline, cFill, radius)
    local s = W2S(worldPos)
    if s == nil then return end
    Render.FilledCircle(s, radius + 2, cFill)
    Render.Circle(s, radius,     cOutline, 2.5)
    Render.Circle(s, radius + 4, WithAlpha(cOutline, 60), 1.0)
end

local function DrawLabel(screenPos, text, color, offsetY)
    if g_font == nil then return end
    local sz = Render.TextSize(g_font, 13, text)
    Render.Text(g_font, 13, text,
        Vec2(screenPos.x - sz.x * 0.5, screenPos.y + (offsetY or -22)),
        color)
end

-- ─────────────────────────── MAIN ────────────────────────────

return {

    OnScriptsLoaded = function()
        g_font = Render.LoadFont("Arial", Enum.FontCreate.FONTFLAG_NONE, 400)
        BuildMenu()
    end,

    OnDraw = function()
        -- ── 1. Menu guards ───────────────────────────────────────────
        if not m_enable:Get() then return end

        -- If a toggle-key is bound, only draw when toggled on
        local boundKey = m_holdKey:Get()
        if boundKey ~= Enum.ButtonCode.BUTTON_CODE_INVALID then
            if not m_holdKey:IsToggled() then return end
        end

        -- ── 2. Hero guard ────────────────────────────────────────────
        local hero = Heroes.GetLocal()
        if hero == nil then return end
        if NPC.GetUnitName(hero) ~= "npc_dota_hero_earth_spirit" then return end

        -- ── 3. Ability guard ─────────────────────────────────────────
        local ability = GetBoulderAbility(hero)
        if ability == nil then return end
        if Ability.GetLevel(ability) == 0 then return end

        -- ── 4. Direction hero → cursor ───────────────────────────────
        local heroPos   = Entity.GetAbsOrigin(hero)
        local cursorPos = Input.GetWorldCursorPos()

        local dx    = cursorPos.x - heroPos.x
        local dy    = cursorPos.y - heroPos.y
        local dist2D = math.sqrt(dx*dx + dy*dy)
        if dist2D < 1 then return end

        local dirX = dx / dist2D
        local dirY = dy / dist2D

        -- ── 5. Read menu colours ─────────────────────────────────────
        local baseCol = m_lineColor:Get()
        local extCol  = m_extColor:Get()

        local C_LINE_NORMAL     = baseCol
        local C_EDGE_NORMAL     = WithAlpha(baseCol, 80)
        local C_IMPACT_NORMAL   = WithAlpha(baseCol, 200)
        local C_IMPACT_FILL     = WithAlpha(baseCol, 60)

        local C_LINE_EXT        = extCol
        local C_EDGE_EXT        = WithAlpha(extCol, 80)
        local C_IMPACT_EXT      = WithAlpha(extCol, 200)
        local C_IMPACT_FILL_EXT = WithAlpha(extCol, 60)

        -- ── 6. Find first remnant in path ────────────────────────────
        local remnants      = GetOwnRemnants()
        local firstRemnant  = nil
        local firstT        = math.huge

        for _, rem in ipairs(remnants) do
            local remPos = Entity.GetAbsOrigin(rem)
            local inPath, t = IsInBoulderPath(
                heroPos, dirX, dirY, BOULDER_RANGE, remPos, REMNANT_HIT_RADIUS)
            if inPath and t < firstT then
                firstRemnant = rem
                firstT       = t
            end
        end

        -- ── 7. Compute end positions ─────────────────────────────────
        local normalEndPos = Vector(
            heroPos.x + dirX * BOULDER_RANGE,
            heroPos.y + dirY * BOULDER_RANGE,
            heroPos.z)
        normalEndPos.z = World.GetGroundZ(normalEndPos.x, normalEndPos.y)

        local hasRemnant     = firstRemnant ~= nil
        local remPos         = hasRemnant and Entity.GetAbsOrigin(firstRemnant) or nil
        local extendedEndPos = nil

        if hasRemnant then
            extendedEndPos = Vector(
                remPos.x + dirX * REMNANT_BONUS,
                remPos.y + dirY * REMNANT_BONUS,
                remPos.z)
            extendedEndPos.z = World.GetGroundZ(extendedEndPos.x, extendedEndPos.y)
        end

        -- ── 8. Draw tunnels ──────────────────────────────────────────
        if hasRemnant then
            DrawTunnel(heroPos, remPos,
                dirX, dirY, C_LINE_NORMAL, C_EDGE_NORMAL, 2.5)
            DrawTunnel(remPos, extendedEndPos,
                dirX, dirY, C_LINE_EXT, C_EDGE_EXT, 2.5)
        else
            DrawTunnel(heroPos, normalEndPos,
                dirX, dirY, C_LINE_NORMAL, C_EDGE_NORMAL, 2.5)
        end

        -- ── 9. Draw impact markers ───────────────────────────────────
        if hasRemnant then
            local ghostEnd = W2S(normalEndPos)
            if ghostEnd then
                Render.Circle(ghostEnd, 10, WithAlpha(baseCol, 80), 1.5)
            end
            DrawImpact(extendedEndPos, C_IMPACT_EXT, C_IMPACT_FILL_EXT, 14)
        else
            DrawImpact(normalEndPos, C_IMPACT_NORMAL, C_IMPACT_FILL, 12)
        end

        -- ── 10. Draw remnant markers (if enabled) ────────────────────
        if m_showRemnant:Get() then
            for _, rem in ipairs(remnants) do
                local rPos    = Entity.GetAbsOrigin(rem)
                local rScreen = W2S(rPos)
                if rScreen then
                    local isHit = (firstRemnant ~= nil and firstRemnant == rem)
                    if isHit then
                        Render.FilledCircle(rScreen, 10, WithAlpha(extCol, 60))
                        Render.Circle(rScreen, 10, extCol, 2.5)
                        Render.Circle(rScreen, 15, WithAlpha(extCol, 80), 1.0)
                        DrawLabel(rScreen, "REMNANT", extCol, -20)
                    else
                        local grey = Color(160, 160, 160, 160)
                        Render.Circle(rScreen, 8, grey, 1.5)
                        Render.FilledCircle(rScreen, 5, WithAlpha(grey, 60))
                    end
                end
            end
        end

        -- ── 11. Status label (if enabled) ────────────────────────────
        if m_showStatus:Get() then
            local labelWorldPos = hasRemnant and extendedEndPos or normalEndPos
            local labelScreen   = W2S(labelWorldPos)
            if labelScreen and g_font then
                local cd       = Ability.GetCooldown(ability)
                local castable = Ability.IsCastable(ability)

                local statusText  = castable
                    and "W  READY"
                    or  string.format("W  %.1f s", cd)
                local statusColor = castable
                    and Color(80, 255, 120, 230)
                    or  Color(255, 80, 80, 230)

                DrawLabel(labelScreen, statusText, statusColor, -28)

                if hasRemnant then
                    DrawLabel(labelScreen, "+REMNANT EXTEND", extCol, -44)
                end
            end
        end
    end,
}