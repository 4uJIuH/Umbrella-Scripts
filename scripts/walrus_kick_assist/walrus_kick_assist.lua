local script = {}

local HERO_NAME = "npc_dota_hero_tusk"
local ABILITY_KICK = "tusk_walrus_kick"
local ABILITY_SNOWBALL = "tusk_snowball"
local SPELL_ICON = "panorama/images/spellicons/tusk_walrus_kick_png.vtex_c"
local SNOWBALL_ICON = "panorama/images/spellicons/tusk_snowball_png.vtex_c"
local LINKEN_ICON = "panorama/images/items/sphere_png.vtex_c"

local MODE_NEAREST = 0
local MODE_CLUSTER = 1
local MODE_CURSOR = 2
local MODE_SELECTED = 3

local MODE_ITEMS = {
    "Ближайший союзник",
    "Скопление союзников",
    "По курсору",
    "Приоритет (Выбор)",
}

local LINKEN_BREAKERS = {
    { name = "item_force_staff", altName = "item_hurricane_pike", label = "Force Staff / Pike", icon = "panorama/images/items/force_staff_png.vtex_c" },
    { name = "item_cyclone", altName = "item_wind_waker", label = "Eul's / Wind Waker", icon = "panorama/images/items/cyclone_png.vtex_c" },
    { name = "item_rod_of_atos", altName = "item_gleipnir", label = "Rod of Atos / Gleipnir", icon = "panorama/images/items/rod_of_atos_png.vtex_c" },
    { name = "item_orchid", altName = "item_bloodthorn", label = "Orchid / Bloodthorn", icon = "panorama/images/items/orchid_png.vtex_c" },
    { name = "item_diffusal_blade", altName = "item_disperser", label = "Diffusal / Disperser", icon = "panorama/images/items/diffusal_blade_png.vtex_c" },
    { name = "item_abyssal_blade", altName = nil, label = "Abyssal Blade", icon = "panorama/images/items/abyssal_blade_png.vtex_c" },
    { name = "item_nullifier", altName = nil, label = "Nullifier", icon = "panorama/images/items/nullifier_png.vtex_c" },
    { name = "item_sheepstick", altName = nil, label = "Scythe of Vyse (Hex)", icon = "panorama/images/items/sheepstick_png.vtex_c" },
    { name = "item_dagon", altName = nil, label = "Dagon 1-5", icon = "panorama/images/items/dagon_5_png.vtex_c" },
    { name = "item_heavens_halberd", altName = nil, label = "Heaven's Halberd", icon = "panorama/images/items/heavens_halberd_png.vtex_c" },
}

local VECTOR_HINT_DISTANCE = 350
local CAST_THROTTLE = 0.30

local HUD_FIXED_WIDTH = 230
local HUD_PAD = 12
local HUD_HEADER_H = 24
local HUD_ROW_H = 19
local HUD_PAD_BOTTOM = 10

local HUD_TITLE = "Walrus Kick Assist"
local HUD_FONT_ROW = 12
local HUD_FONT_TITLE = 13

local COLOR_HUD_BG_TOP = Color(22, 25, 32, 235)
local COLOR_HUD_HEADER_BG = Color(48, 112, 178, 235)
local COLOR_HUD_HEADER_TEXT = Color(240, 245, 255, 255)
local COLOR_HUD_LABEL = Color(190, 195, 205, 255)
local COLOR_HUD_GOOD = Color(105, 214, 140, 255)
local COLOR_HUD_BAD = Color(235, 99, 99, 255)
local COLOR_HUD_DIM = Color(140, 144, 155, 255)
local COLOR_HUD_WARN = Color(235, 175, 80, 255)
local COLOR_HUD_BORDER = Color(255, 255, 255, 20)
local COLOR_HUD_ROW_HOVER = Color(255, 255, 255, 16)

local UI = {}
local State = {
    lastCastTime = 0,
    pendingVectorTarget = nil,
    pendingVectorStepTime = 0,
    pendingSnowballTarget = nil,
    pendingSnowballTime = 0,
    pendingSnowballLaunchStartTime = 0,
    pendingSnowballLaunchEndTime = 0,
    hudDragging = false,
    hudDragOffset = { x = 0, y = 0 },
    lastMouse1State = false,
    lastMouse2State = false,
    lastToggleKeyBindState = false,
    hudVisibleState = true,
    
    allyPriority = {},
    iconRects = {},
    draggingIconIndex = nil,
    iconDragOffset = { x = 0, y = 0 },
    iconDragPos = { x = 0, y = 0 },
    
    HeroImages = {}
}

local hudClickableRows = {}
local hudFont = nil
local uiInitialized = false
local lastMenuAttemptTime = 0
local fontAttemptTime = 0

--#region Utils

local function SafeGet(element, default)
    if element and type(element.Get) == "function" then
        local status, val = pcall(function() return element:Get() end)
        if status and val ~= nil then return val end
    end
    return default
end

local function GetHudPos()
    local x, y = 200, 200
    if UI.HudPosX and type(UI.HudPosX.Get) == "function" then
        local ok, val = pcall(function() return UI.HudPosX:Get() end)
        if ok and val ~= nil then x = val end
    end
    if UI.HudPosY and type(UI.HudPosY.Get) == "function" then
        local ok, val = pcall(function() return UI.HudPosY:Get() end)
        if ok and val ~= nil then y = val end
    end

    local sw, sh = 1920, 1080
    if type(Render.ScreenSize) == "function" then
        local ok, size = pcall(Render.ScreenSize)
        if ok and size and size.x then
            sw, sh = size.x, size.y
        end
    end

    if x > sw - 100 then x = sw - 300 end
    if y > sh - 50 then y = sh - 200 end

    return math.max(0, x), math.max(0, y)
end

local function SetHudPos(x, y)
    if UI.HudPosX and type(UI.HudPosX.Set) == "function" then
        pcall(function() UI.HudPosX:Set(math.floor(x)) end)
    end
    if UI.HudPosY and type(UI.HudPosY.Set) == "function" then
        pcall(function() UI.HudPosY:Set(math.floor(y)) end)
    end
end

local function EnsureHeroImage(heroName)
    if not State.HeroImages[heroName] and type(Render) == "table" and type(Render.LoadImage) == "function" then
        local path = "panorama/images/heroes/" .. heroName .. "_png.vtex_c"
        local ok, handle = pcall(Render.LoadImage, path)
        if ok and handle then
            State.HeroImages[heroName] = handle
        end
    end
    return State.HeroImages[heroName]
end

--#endregion

--#region Logic: Targeting & Allies

local function CollectUnits(hero)
    local allies = {}
    local enemies = {}
    local allHeroes = Heroes.GetAll()

    if not allHeroes then return allies, enemies end

    for i = 1, #allHeroes do
        local other = allHeroes[i]
        if other and other ~= hero and Entity.IsAlive(other) and not Entity.IsDormant(other) then
            if not NPC.IsIllusion(other) and not (NPC.IsInvulnerable and NPC.IsInvulnerable(other)) then
                if Entity.IsSameTeam(other, hero) then
                    allies[#allies + 1] = { hero = other, pos = Entity.GetAbsOrigin(other) }
                else
                    enemies[#enemies + 1] = { hero = other, pos = Entity.GetAbsOrigin(other) }
                end
            end
        end
    end

    return allies, enemies
end

local function UpdateAllyPriorityList(hero)
    local allies, _ = CollectUnits(hero)
    
    for i = #State.allyPriority, 1, -1 do
        local found = false
        for _, a in ipairs(allies) do
            if a.hero == State.allyPriority[i].hero then found = true; break end
        end
        if not found then table.remove(State.allyPriority, i) end
    end
    
    for _, a in ipairs(allies) do
        local found = false
        for _, p in ipairs(State.allyPriority) do
            if p.hero == a.hero then found = true; break end
        end
        if not found then
            table.insert(State.allyPriority, { hero = a.hero, enabled = true })
        end
    end
end

--#endregion

--#region Menu & Theme

local function InitializeUIUnsafe()
    local heroSettings = Menu.Find("Heroes", "Hero List", "Tusk")
    local tab = heroSettings and heroSettings.Create and heroSettings:Create("Walrus Kick Assist") or Menu.Create("General", "Tusk", "Walrus Kick Assist", "Settings")

    local mainGroup = tab:Create("Основное", Enum.GroupSide.Left)
    UI.Enabled = mainGroup:Switch("Включить", false)
    UI.Enabled:Image(SPELL_ICON)
    UI.Bind = mainGroup:Bind("Клавиша", Enum.ButtonCode.KEY_X)
    UI.Mode = mainGroup:Combo("Режим пинка", MODE_ITEMS, MODE_NEAREST)
    UI.Mode:Image(SPELL_ICON)
    
    UI.PriorityLogic = mainGroup:Combo("Логика приоритета", {"По панели HUD (ЛКМ/ПКМ)", "Ближайший к Туску", "Дальний от врага", "Меньше всего ХП (Сейв)"}, 0)

    local comboGroup = tab:Create("Комбо", Enum.GroupSide.Right)
    UI.UseBlink = comboGroup:Switch("Использовать Blink", true)
    UI.MinBlinkDist = comboGroup:Slider("Мин. дистанция для Blink", 0, 600, 250, "%d")

    UI.AutoSnowball = comboGroup:Switch("Авто-снежок в цель", true)
    UI.AutoSnowball:Image(SNOWBALL_ICON)
    UI.InstantSnowball = comboGroup:Switch("Моментальный запуск", false)
    UI.SnowballDelay = comboGroup:Slider("Задержка запуска (мс)", 0, 1500, 400, "%d")

    local radiusGroup = tab:Create("Радиус захвата", Enum.GroupSide.Left)
    UI.AssistRadius = radiusGroup:Slider("Радиус захвата", 0, 3000, 2000, "%d")
    UI.MaxAllyDistance = radiusGroup:Slider("Макс. дистанция союзника", 200, 3000, 2500, "%d")
    UI.ClusterRadius = radiusGroup:Slider("Радиус группы союзников", 120, 1200, 500, "%d")
    UI.MinClusterCount = radiusGroup:Slider("Мин. союзников в группе", 2, 5, 2, "%d")

    local hudGroup = tab:Create("HUD", Enum.GroupSide.Right)
    UI.DrawRadius = hudGroup:Switch("Радиус на экране", false)
    UI.HudVisibleToggle = hudGroup:Bind("Бинд видимости HUD", Enum.ButtonCode.KEY_NONE)
    
    UI.HudPosX = hudGroup:Slider("HUD X", 0, 4000, 200, "%d")
    UI.HudPosX:Visible(false)
    UI.HudPosY = hudGroup:Slider("HUD Y", 0, 3000, 200, "%d")
    UI.HudPosY:Visible(false)

    local linkenGroup = tab:Create("Линкен", Enum.GroupSide.FullWidth)
    UI.CustomLinkenBreak = linkenGroup:Switch("Сбитие Линки предметами", true)
    UI.CustomLinkenBreak:Image(LINKEN_ICON)

    UI.LinkenSwitches = {}
    UI.LinkenSliders = {}
    
    for i, breaker in ipairs(LINKEN_BREAKERS) do
        local sw = linkenGroup:Switch("   ↳ " .. breaker.label, true)
        if sw and sw.Image then
            sw:Image(breaker.icon)
        end
        UI.LinkenSwitches[breaker.name] = sw

        local slider = linkenGroup:Slider("      Приоритет: " .. breaker.label, 1, 10, i, "%d")
        UI.LinkenSliders[breaker.name] = slider
    end

    UI.LinkenInfo = linkenGroup:Label("Сбив линкена: —")
    
    UI.Enabled:SetCallback(UpdateControls, true)
    UI.Mode:SetCallback(UpdateControls, true)
    UI.UseBlink:SetCallback(UpdateControls, true)
    UI.AutoSnowball:SetCallback(UpdateControls, true)
    UI.InstantSnowball:SetCallback(UpdateControls, true)
    UI.CustomLinkenBreak:SetCallback(UpdateControls, true)
end

local function UpdateControlsUnsafe()
    local enabled = SafeGet(UI.Enabled, false)
    local mode = SafeGet(UI.Mode, MODE_NEAREST)
    local isCluster = (mode == MODE_CLUSTER)
    local isCursor = (mode == MODE_CURSOR)
    local isSelected = (mode == MODE_SELECTED)
    local useBlink = SafeGet(UI.UseBlink, true)
    local useAutoSnowball = SafeGet(UI.AutoSnowball, true)
    local useInstantSnowball = SafeGet(UI.InstantSnowball, false)
    local useLinkenBreak = SafeGet(UI.CustomLinkenBreak, true)

    if UI.Bind then UI.Bind:Disabled(not enabled) end
    if UI.Mode then UI.Mode:Disabled(not enabled) end
    
    if UI.PriorityLogic then 
        UI.PriorityLogic:Visible(enabled and isSelected) 
    end
    
    if UI.DrawRadius then UI.DrawRadius:Disabled(not enabled) end
    if UI.UseBlink then UI.UseBlink:Disabled(not enabled) end
    if UI.MinBlinkDist then UI.MinBlinkDist:Disabled(not enabled or not useBlink) end
    
    if UI.AutoSnowball then UI.AutoSnowball:Disabled(not enabled) end
    if UI.InstantSnowball then UI.InstantSnowball:Disabled(not enabled or not useAutoSnowball) end
    if UI.SnowballDelay then UI.SnowballDelay:Disabled(not enabled or not useAutoSnowball or not useInstantSnowball) end
    
    if UI.HudVisibleToggle then UI.HudVisibleToggle:Disabled(not enabled) end
    if UI.CustomLinkenBreak then UI.CustomLinkenBreak:Disabled(not enabled) end

    if UI.LinkenSwitches then
        for _, switch in pairs(UI.LinkenSwitches) do
            if switch and type(switch.Visible) == "function" then switch:Visible(enabled and useLinkenBreak) end
        end
    end
    if UI.LinkenSliders then
        for _, slider in pairs(UI.LinkenSliders) do
            if slider and type(slider.Visible) == "function" then slider:Visible(enabled and useLinkenBreak) end
        end
    end

    if UI.AssistRadius then UI.AssistRadius:Disabled(not enabled) end
    if UI.MaxAllyDistance then UI.MaxAllyDistance:Disabled(not enabled or isCursor) end
    if UI.ClusterRadius then UI.ClusterRadius:Disabled(not enabled or not isCluster) end
    if UI.MinClusterCount then UI.MinClusterCount:Disabled(not enabled or not isCluster) end
end

function UpdateControls()
    if type(Menu) ~= "table" then return end
    pcall(UpdateControlsUnsafe)
end

local function EnsureUI()
    if uiInitialized then return true end

    if type(Menu) ~= "table" or type(Menu.Create) ~= "function" then
        return false
    end

    local now = os.clock()
    if now - lastMenuAttemptTime < 5.0 then return false end
    lastMenuAttemptTime = now

    pcall(InitializeUIUnsafe)
    uiInitialized = true 
    
    return uiInitialized
end

local function EnsureFont()
    if hudFont then return true end
    
    if type(Render) ~= "table" or type(Render.LoadFont) ~= "function" then 
        return false 
    end

    local now = os.clock()
    if now - fontAttemptTime < 2.0 then return false end
    fontAttemptTime = now

    pcall(function()
        local fontFlags = Enum.FontCreate.FONTFLAG_ANTIALIAS + Enum.FontCreate.FONTFLAG_OUTLINE
        hudFont = Render.LoadFont("Arial", fontFlags, 600)
    end)

    return hudFont ~= nil
end

local THEME_EXACT_CANDIDATES = {
    accent = { "primary" },
    background = { "background", "panel", "window" },
    good = { "toggleOn", "switchOn", "checked", "on", "enabled", "active", "success", "positive", "green" },
    bad = { "toggleOff", "switchOff", "unchecked", "off", "disabled", "inactive", "danger", "negative", "red" },
}

local THEME_ROLE_KEYWORDS = {
    { role = "accent", words = { "primary", "accent", "highlight" } },
    { role = "background", words = { "background", "panel", "window", "surface" } },
    { role = "border", words = { "border", "outline", "stroke", "separator", "divider" } },
    { role = "good", words = { "toggleon", "switchon", "checked", "active", "enabled", "success", "positive", "green" } },
    { role = "bad", words = { "toggleoff", "switchoff", "unchecked", "inactive", "disabled", "danger", "negative", "red" } },
    { role = "warn", words = { "warn", "orange", "yellow", "caution" } },
}

local Theme = {
    dirty = true,
    accent = COLOR_HUD_HEADER_BG,
    background = COLOR_HUD_BG_TOP,
    border = COLOR_HUD_BORDER,
    good = COLOR_HUD_GOOD,
    bad = COLOR_HUD_BAD,
    warn = COLOR_HUD_WARN,
}

local function IsColorLike(value)
    if value == nil then return false end
    local ok, r, g, b, a = pcall(function() return value.r, value.g, value.b, value.a end)
    if not ok then return false end
    if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then return false end
    if type(a) == "number" and a <= 0 then return false end
    return true
end

local function ResolveThemeRole(styleTable, usedKeys, words)
    for _, word in ipairs(words) do
        for key, value in pairs(styleTable) do
            if type(key) == "string" and not usedKeys[key] and IsColorLike(value) then
                if key:lower():find(word, 1, true) then
                    usedKeys[key] = true
                    return value
                end
            end
        end
    end
    return nil
end

local function RefreshTheme()
    if type(Menu) ~= "table" or type(Menu.Style) ~= "function" then return end
    Theme.dirty = false

    local resolved = {}
    for role, candidates in pairs(THEME_EXACT_CANDIDATES) do
        for _, name in ipairs(candidates) do
            local ok, value = pcall(Menu.Style, name)
            if ok and IsColorLike(value) then
                Theme[role] = value
                resolved[role] = true
                break
            end
        end
    end

    local okAll, styleTable = pcall(Menu.Style)
    if okAll and type(styleTable) == "table" then
        local usedKeys = {}
        for _, entry in ipairs(THEME_ROLE_KEYWORDS) do
            if not resolved[entry.role] then
                local value = ResolveThemeRole(styleTable, usedKeys, entry.words)
                if value then
                    Theme[entry.role] = value
                end
            end
        end
    end
end

local function EnsureTheme()
    if Theme.dirty then
        RefreshTheme()
    end
end

--#endregion

--#region Mechanics

local function UpdateHudDrag()
    if not State.hudVisibleState or not SafeGet(UI.Enabled, false) then 
        State.hudDragging = false
        State.draggingIconIndex = nil
        return 
    end
    
    if Input.IsInputCaptured() then 
        State.hudDragging = false
        State.draggingIconIndex = nil
        return 
    end

    local cx, cy = Input.GetCursorPos()
    if not cx or not cy then return end

    local isM1 = Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE1)
    local isM2 = Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE2)
    local mode = SafeGet(UI.Mode, MODE_NEAREST)
    local pLogic = SafeGet(UI.PriorityLogic, 0)

    if mode == MODE_SELECTED and pLogic == 0 and State.iconRects then
        if not State.lastMouse2State and isM2 then
            for i, rect in ipairs(State.iconRects) do
                if cx >= rect.x and cx <= rect.x + rect.w and cy >= rect.y and cy <= rect.y + rect.h then
                    if State.allyPriority[i] then
                        State.allyPriority[i].enabled = not State.allyPriority[i].enabled
                    end
                    break
                end
            end
        end

        if State.draggingIconIndex then
            if isM1 then
                State.iconDragPos = { x = cx - State.iconDragOffset.x, y = cy - State.iconDragOffset.y }
                
                for i, rect in ipairs(State.iconRects) do
                    if i ~= State.draggingIconIndex then
                        if cx >= rect.x + 10 and cx <= rect.x + rect.w - 10 and cy >= rect.y and cy <= rect.y + rect.h then
                            local item = table.remove(State.allyPriority, State.draggingIconIndex)
                            table.insert(State.allyPriority, i, item)
                            State.draggingIconIndex = i
                            break
                        end
                    end
                end
            else
                State.draggingIconIndex = nil
            end
            
            State.lastMouse1State = isM1
            State.lastMouse2State = isM2
            return 
        end

        if not State.hudDragging and not State.lastMouse1State and isM1 then
            for i, rect in ipairs(State.iconRects) do
                if cx >= rect.x and cx <= rect.x + rect.w and cy >= rect.y and cy <= rect.y + rect.h then
                    State.draggingIconIndex = i
                    State.iconDragOffset = { x = cx - rect.x, y = cy - rect.y }
                    State.iconDragPos = { x = rect.x, y = rect.y }
                    State.lastMouse1State = true
                    State.lastMouse2State = isM2
                    return
                end
            end
        end
    end

    local curX, curY = GetHudPos()

    if State.hudDragging then
        if isM1 then
            local newX = cx - State.hudDragOffset.x
            local newY = cy - State.hudDragOffset.y
            SetHudPos(newX, newY)
        else
            State.hudDragging = false
        end
        State.lastMouse1State = isM1
        State.lastMouse2State = isM2
        return
    end

    if not State.hudDragging and not State.lastMouse1State and isM1 then
        if Input.IsCursorInRect(curX, curY, HUD_FIXED_WIDTH, HUD_HEADER_H) then
            State.hudDragging = true
            State.hudDragOffset.x = cx - curX
            State.hudDragOffset.y = cy - curY
            State.lastMouse1State = isM1
            State.lastMouse2State = isM2
            return
        end

        for _, btn in ipairs(hudClickableRows) do
            local r = btn.rect
            if cx >= r.x1 and cx <= r.x2 and cy >= r.y1 and cy <= r.y2 then
                if type(btn.onClick) == "function" then
                    btn.onClick()
                end
                break
            end
        end
    end

    State.lastMouse1State = isM1
    State.lastMouse2State = isM2
end

local function IsValidTusk(hero)
    if not hero or NPC.GetUnitName(hero) ~= HERO_NAME then
        return false
    end
    if not Entity.IsAlive(hero) or Entity.IsDormant(hero) then
        return false
    end
    return true
end

local function HasAghanimInInventory(hero)
    if not hero then return false end
    
    local kick = NPC.GetAbility(hero, ABILITY_KICK)
    if kick and not Ability.IsHidden(kick) and Ability.GetLevel(kick) > 0 then
        return true
    end

    if NPC.HasModifier(hero, "modifier_item_ultimate_scepter_consumed") or 
       NPC.HasModifier(hero, "modifier_item_ultimate_scepter_consumed_alchemist") then
        return true
    end

    local ok1, item1 = pcall(function() return NPC.GetItem(hero, "item_ultimate_scepter", true) end)
    return (ok1 and item1 ~= nil)
end

local function HasSpellReflection(enemy)
    if not enemy or not NPC.GetModifiers then return false end
    local status, mods = pcall(function() return NPC.GetModifiers(enemy) end)
    
    if not status or not mods then return true end
    
    for _, mod in ipairs(mods) do
        local name = Modifier.GetName(mod)
        if name then
            if name == "modifier_item_lotus_orb_active" or 
               name == "modifier_item_lotus_orb_echo" or 
               name == "modifier_reflect" or
               name == "modifier_antimage_counterspell" or
               name == "modifier_item_mirror_shield" then
                return true
            end
        end
    end
    return false
end

local function FindBlink(hero)
    local items = { "item_blink", "item_arcane_blink", "item_overwhelming_blink", "item_swift_blink" }
    for i = 1, #items do
        local ok, item = pcall(function() return NPC.GetItem(hero, items[i], true) end)
        if ok and item then
            return item
        end
    end
    return nil
end

local function CanBreakLinken(ability, hero)
    if not ability then return false end
    if not Ability.IsReady(ability) or not Ability.IsCastable(ability, NPC.GetMana(hero)) then
        return false
    end
    return true
end

local function FindLinkenBreaker(hero, ownKick, ownSnowball)
    if not SafeGet(UI.CustomLinkenBreak, true) then return nil end

    local activeBreakers = {}
    for _, breaker in ipairs(LINKEN_BREAKERS) do
        local switch = UI.LinkenSwitches[breaker.name]
        if not switch or SafeGet(switch, true) then
            local priority = 5
            if UI.LinkenSliders and UI.LinkenSliders[breaker.name] then
                priority = SafeGet(UI.LinkenSliders[breaker.name], 5)
            end
            table.insert(activeBreakers, { breaker = breaker, priority = priority })
        end
    end

    table.sort(activeBreakers, function(a, b)
        return a.priority < b.priority
    end)

    for _, entry in ipairs(activeBreakers) do
        local breaker = entry.breaker
        local testNames = { breaker.name }
        if breaker.altName then
            table.insert(testNames, breaker.altName)
        end
        if breaker.name == "item_dagon" then
            testNames = { "item_dagon", "item_dagon_2", "item_dagon_3", "item_dagon_4", "item_dagon_5" }
        end

        for _, dName in ipairs(testNames) do
            local ok, item = pcall(function() return NPC.GetItem(hero, dName, true) end)
            if ok and item and item ~= ownKick and item ~= ownSnowball and CanBreakLinken(item, hero) then
                return item
            end
        end
    end

    return nil
end

local function MakeGroundPosition(pos)
    if not pos then return nil end
    return Vector(pos.x, pos.y, World.GetGroundZ(pos.x, pos.y))
end

local function MakeDirection2D(fromPos, toPos)
    local delta = Vector(toPos.x - fromPos.x, toPos.y - fromPos.y, 0)
    local length = delta:Length2D()
    if length < 0.001 then
        return nil, 0
    end
    return Vector(delta.x / length, delta.y / length, 0), length
end

local function MoveTowards2D(startPos, direction, distance)
    return Vector(
        startPos.x + direction.x * distance,
        startPos.y + direction.y * distance,
        startPos.z
    )
end

local function GetLinkenStatus(hero)
    local assistRadius = SafeGet(UI.AssistRadius, 2000)
    local heroPos = Entity.GetAbsOrigin(hero)
    local _, enemies = CollectUnits(hero)

    local nearestEnemy, nearestDist = nil, math.huge
    for i = 1, #enemies do
        local enemyData = enemies[i]
        if enemyData and enemyData.pos then
            local dist = heroPos:Distance2D(enemyData.pos)
            if dist <= assistRadius and dist < nearestDist then
                nearestDist = dist
                nearestEnemy = enemyData.hero
            end
        end
    end

    if not nearestEnemy then
        return "нет цели", COLOR_HUD_DIM
    end

    if HasSpellReflection(nearestEnemy) then
        return "отражение", COLOR_HUD_BAD
    end

    if not NPC.IsLinkensProtected(nearestEnemy) then
        return "не активен", COLOR_HUD_DIM
    end

    local kick = NPC.GetAbility(hero, ABILITY_KICK)
    local snowball = NPC.GetAbility(hero, ABILITY_SNOWBALL)
    local breaker = FindLinkenBreaker(hero, kick, snowball)

    if breaker then
        return Ability.GetName(breaker), COLOR_HUD_GOOD
    end

    return "нечем сбить", COLOR_HUD_BAD
end

local function UpdateLinkenLabel(hero)
    if not UI.LinkenInfo then return end
    local statusText = GetLinkenStatus(hero)
    UI.LinkenInfo:Name("Сбив линкена: " .. statusText)
end

local function CalculatePlan(hero, mode)
    local heroPos = Entity.GetAbsOrigin(hero)
    if not heroPos then return nil end

    local assistRadius = SafeGet(UI.AssistRadius, 2000)
    local maxAllyDist = SafeGet(UI.MaxAllyDistance, 2500)
    local clusterRadius = SafeGet(UI.ClusterRadius, 500)
    local minClusterCount = SafeGet(UI.MinClusterCount, 2)

    local allies, enemies = CollectUnits(hero)
    if #enemies == 0 then return nil end

    local bestEnemyData = nil
    local minHeroDist = math.huge

    for i = 1, #enemies do
        local enemyData = enemies[i]
        if enemyData and enemyData.pos then
            local dist = heroPos:Distance2D(enemyData.pos)
            if dist <= assistRadius and dist < minHeroDist then
                minHeroDist = dist
                bestEnemyData = enemyData
            end
        end
    end

    if not bestEnemyData then return nil end

    local enemyPos = bestEnemyData.pos
    local targetPos = nil

    if mode == MODE_CURSOR then
        local cursorWorldPos = Input.GetWorldCursorPos and Input.GetWorldCursorPos() or nil
        if cursorWorldPos then
            targetPos = cursorWorldPos
        else
            local fallbackDir = MakeDirection2D(heroPos, enemyPos)
            targetPos = fallbackDir and MoveTowards2D(enemyPos, fallbackDir, 200) or enemyPos
        end

    elseif mode == MODE_NEAREST then
        local nearestAllyPos = nil
        local minAllyDistToEnemy = math.huge

        for i = 1, #allies do
            local ally = allies[i]
            if ally and ally.pos then
                local distToEnemy = enemyPos:Distance2D(ally.pos)
                local distToHero = heroPos:Distance2D(ally.pos)

                if distToHero <= assistRadius and distToEnemy <= maxAllyDist and distToEnemy < minAllyDistToEnemy then
                    minAllyDistToEnemy = distToEnemy
                    nearestAllyPos = ally.pos
                end
            end
        end

        targetPos = nearestAllyPos or heroPos

    elseif mode == MODE_CLUSTER then
        local validAllies = {}
        for i = 1, #allies do
            local ally = allies[i]
            if ally and ally.pos then
                if heroPos:Distance2D(ally.pos) <= assistRadius and enemyPos:Distance2D(ally.pos) <= maxAllyDist then
                    validAllies[#validAllies + 1] = ally.pos
                end
            end
        end

        if #validAllies > 0 then
            local bestCenter = nil
            local maxCount = 0

            for i = 1, #validAllies do
                local anchor = validAllies[i]
                local sumX, sumY, sumZ, count = 0, 0, 0, 0

                for j = 1, #validAllies do
                    local pos = validAllies[j]
                    if anchor:Distance2D(pos) <= clusterRadius then
                        count = count + 1
                        sumX = sumX + pos.x
                        sumY = sumY + pos.y
                        sumZ = sumZ + pos.z
                    end
                end

                if count >= minClusterCount and count > maxCount then
                    maxCount = count
                    bestCenter = Vector(sumX / count, sumY / count, sumZ / count)
                end
            end

            targetPos = bestCenter
        end

        targetPos = targetPos or heroPos

    elseif mode == MODE_SELECTED then
        local logic = SafeGet(UI.PriorityLogic, 0)
        local validTarget = nil
        local bestScore = nil
        
        if logic == 0 then
            for _, p in ipairs(State.allyPriority) do
                if p.enabled and p.hero and Entity.IsAlive(p.hero) and not Entity.IsDormant(p.hero) then
                    local distToHero = heroPos:Distance2D(Entity.GetAbsOrigin(p.hero))
                    local distToEnemy = enemyPos:Distance2D(Entity.GetAbsOrigin(p.hero))
                    
                    if distToHero <= assistRadius and distToEnemy <= maxAllyDist then
                        validTarget = p.hero
                        break
                    end
                end
            end
        else
            for _, allyData in ipairs(allies) do
                local aHero = allyData.hero
                local aPos = allyData.pos
                local distToHero = heroPos:Distance2D(aPos)
                local distToEnemy = enemyPos:Distance2D(aPos)

                if distToHero <= assistRadius and distToEnemy <= maxAllyDist then
                    local score = 0
                    
                    if logic == 1 then
                        score = -distToHero
                    elseif logic == 2 then
                        score = distToEnemy
                    elseif logic == 3 then
                        score = -Entity.GetHealth(aHero)
                    end

                    if bestScore == nil or score > bestScore then
                        bestScore = score
                        validTarget = aHero
                    end
                end
            end
        end
        
        if validTarget then
            targetPos = Entity.GetAbsOrigin(validTarget)
        else
            targetPos = heroPos
        end
    end

    if not targetPos then return nil end

    local direction, _ = MakeDirection2D(enemyPos, targetPos)
    if not direction then
        direction, _ = MakeDirection2D(heroPos, enemyPos)
        if not direction then return nil end
    end

    local vectorPos = MoveTowards2D(enemyPos, direction, VECTOR_HINT_DISTANCE)

    return {
        enemy = bestEnemyData.hero,
        enemyPos = MakeGroundPosition(enemyPos),
        vectorPos = MakeGroundPosition(vectorPos),
        vectorDirection = direction,
        enemyDistance = heroPos:Distance2D(enemyPos),
    }
end

--#endregion

--#region Engine Callbacks

script.OnUpdate = function()
    if not Engine.IsInGame() then return end
    if not EnsureUI() then return end

    if UI.HudVisibleToggle and UI.HudVisibleToggle.IsPressed then
        local isPressed = UI.HudVisibleToggle:IsPressed()
        if isPressed and not State.lastToggleKeyBindState then
            State.hudVisibleState = not State.hudVisibleState
        end
        State.lastToggleKeyBindState = isPressed
    end

    local hero = Heroes.GetLocal()
    
    if not IsValidTusk(hero) then 
        State.hudDragging = false
        State.draggingIconIndex = nil
        hudClickableRows = {}
        return 
    end

    if SafeGet(UI.Enabled, false) then
        UpdateAllyPriorityList(hero)
    end

    UpdateHudDrag()

    if not HasAghanimInInventory(hero) then
        State.hudDragging = false
        return
    end

    if SafeGet(UI.Enabled, false) then
        UpdateLinkenLabel(hero)
    end

    local player = Players.GetLocal()
    local now = GameRules.GetGameTime()

    if State.pendingSnowballTarget and player then
        if now >= State.pendingSnowballTime then
            local autoSnowballEnabled = SafeGet(UI.AutoSnowball, true)
            local target = State.pendingSnowballTarget
            
            if autoSnowballEnabled and target and Entity.IsAlive(target) and not Entity.IsDormant(target) then
                if not HasSpellReflection(target) and not NPC.IsLinkensProtected(target) then
                    local snowball = NPC.GetAbility(hero, ABILITY_SNOWBALL)
                    if snowball and Ability.GetLevel(snowball) > 0 then
                        local ok = pcall(Player.PrepareUnitOrders, player, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TARGET, target, Vector(0, 0, 0), snowball, Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, hero, false, false, false, false, "tusk_auto_snowball_target")
                        
                        -- ЛОГИКА ЗАДЕРЖКИ
                        if ok and SafeGet(UI.InstantSnowball, false) then
                            local delayMs = SafeGet(UI.SnowballDelay, 400)
                            State.pendingSnowballLaunchStartTime = now + (delayMs / 1000.0)
                            State.pendingSnowballLaunchEndTime = now + (delayMs / 1000.0) + 1.5
                        end
                    end
                end
            end
            State.pendingSnowballTarget = nil
        end
    end

    -- ЗАПУСК СНЕЖКА С УЧЕТОМ ЗАДЕРЖКИ
    if State.pendingSnowballLaunchEndTime > 0 and player then
        if now > State.pendingSnowballLaunchEndTime then
            State.pendingSnowballLaunchEndTime = 0
            State.pendingSnowballLaunchStartTime = 0
        elseif now >= State.pendingSnowballLaunchStartTime then
            local launchAbility = NPC.GetAbility(hero, "tusk_launch_snowball")
            if launchAbility and not Ability.IsHidden(launchAbility) then
                local ok = pcall(Player.PrepareUnitOrders, player, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET, nil, Vector(0,0,0), launchAbility, Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, hero, false, false, false, false, "tusk_auto_snowball_launch")
                if ok then
                    State.pendingSnowballLaunchEndTime = 0
                    State.pendingSnowballLaunchStartTime = 0
                end
            end
        end
    end

    if State.pendingVectorTarget and player then
        if now >= State.pendingVectorStepTime then
            local kick = NPC.GetAbility(hero, ABILITY_KICK)
            if kick and Ability.GetLevel(kick) > 0 then
                pcall(Player.PrepareUnitOrders, player, Enum.UnitOrder.DOTA_UNIT_ORDER_VECTOR_TARGET_POSITION, nil, State.pendingVectorTarget, kick, Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, hero, false, false, false, false, "tusk_vector_step")
            end
            State.pendingVectorTarget = nil
        end
        return
    end

    if not SafeGet(UI.Enabled, false) or not UI.Bind or UI.Bind:IsDown() ~= true then
        return
    end

    if Input.IsInputCaptured() then return end

    local kick = NPC.GetAbility(hero, ABILITY_KICK)
    if not kick or Ability.GetLevel(kick) <= 0 or not Ability.IsReady(kick) or not Ability.IsCastable(kick, NPC.GetMana(hero)) then
        return
    end

    if now - State.lastCastTime < CAST_THROTTLE then return end

    local mode = SafeGet(UI.Mode, MODE_NEAREST)
    local plan = CalculatePlan(hero, mode)
    if not plan then return end

    local heroPos = Entity.GetAbsOrigin(hero)
    local distToEnemy = plan.enemyDistance
    local castRange = Ability.GetCastRange(kick) or 250
    local minBlinkDist = SafeGet(UI.MinBlinkDist, 250)

    if distToEnemy > castRange + 25 then
        local canBlink = false
        local blink = nil

        if SafeGet(UI.UseBlink, true) and distToEnemy >= minBlinkDist then
            blink = FindBlink(hero)
            if blink and Ability.IsReady(blink) and Ability.IsCastable(blink, NPC.GetMana(hero)) then
                canBlink = true
            end
        end

        if canBlink then
            local dir, _ = MakeDirection2D(heroPos, plan.enemyPos)
            local jumpPos = MoveTowards2D(plan.enemyPos, Vector(-dir.x, -dir.y, 0), math.min(150, distToEnemy - 50))
            jumpPos = MakeGroundPosition(jumpPos)

            if player then
                local ok = pcall(Player.PrepareUnitOrders, player, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION, nil, jumpPos, blink, Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, hero, false, false, false, false, "tusk_clean_blink_pos")
                if ok then
                    State.lastCastTime = now
                end
                return
            end
        else
            if player then
                pcall(Player.PrepareUnitOrders, player, Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION, nil, plan.enemyPos, nil, Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, hero, false, false, false, false, "tusk_clean_move")
            end
            return
        end
    end

    if distToEnemy <= castRange + 25 and player then
        if HasSpellReflection(plan.enemy) then
            return
        end

        if NPC.IsLinkensProtected(plan.enemy) then
            local snowball = NPC.GetAbility(hero, ABILITY_SNOWBALL)
            local breaker = FindLinkenBreaker(hero, kick, snowball)
            if breaker then
                if not HasSpellReflection(plan.enemy) then
                    local ok = pcall(Player.PrepareUnitOrders, player, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TARGET, plan.enemy, Vector(0, 0, 0), breaker, Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, hero, false, false, false, false, "tusk_linken_break")
                    if ok then
                        State.lastCastTime = now
                    end
                    return
                end
            else
                return
            end
        end

        local lookAheadPos = MoveTowards2D(heroPos, plan.vectorDirection, 200)
        pcall(Player.PrepareUnitOrders, player, Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION, nil, lookAheadPos, nil, Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, hero, false, false, false, false, "tusk_preload_facing")

        local okCast = pcall(Player.PrepareUnitOrders, player, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TARGET, plan.enemy, Vector(0, 0, 0), kick, Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, hero, false, false, false, false, "tusk_clean_kick_target")

        if okCast then
            State.pendingVectorTarget = plan.vectorPos
            State.pendingVectorStepTime = now + 0.05
            
            State.pendingSnowballTarget = plan.enemy
            State.pendingSnowballTime = now + 0.03

            State.lastCastTime = now
        end
    end
end

local function DrawHudPanel(rows, showIcons)
    if not hudFont then return end

    EnsureTheme()
    hudClickableRows = {}

    local cx, cy = Input.GetCursorPos()

    local iconAreaHeight = showIcons and 36 or 0
    local panelHeight = HUD_HEADER_H + 8 + (#rows * HUD_ROW_H) + iconAreaHeight + HUD_PAD_BOTTOM
    local panelWidth = HUD_FIXED_WIDTH
    local ox, oy = GetHudPos()

    Render.Shadow(Vec2(ox, oy), Vec2(ox + panelWidth, oy + panelHeight), Color(0, 0, 0, 150), 18, 8)

    Render.FilledRect(Vec2(ox, oy), Vec2(ox + panelWidth, oy + panelHeight), Theme.background, 8)
    Render.Rect(Vec2(ox, oy), Vec2(ox + panelWidth, oy + panelHeight), Theme.border, 8, Enum.DrawFlags.None, 1)

    Render.FilledRect(Vec2(ox, oy), Vec2(ox + panelWidth, oy + HUD_HEADER_H), Theme.accent, 8, Enum.DrawFlags.RoundCornersTop)

    local titleX = ox + HUD_PAD
    local titleY = oy + (HUD_HEADER_H - HUD_FONT_TITLE) / 2 - 1
    Render.Text(hudFont, HUD_FONT_TITLE, HUD_TITLE, Vec2(titleX, titleY), COLOR_HUD_HEADER_TEXT)

    local y = oy + HUD_HEADER_H + 6

    for i = 1, #rows do
        local row = rows[i]

        local hovered = row.onClick and cx and cy and cx >= ox and cx <= ox + panelWidth and cy >= y and cy <= y + HUD_ROW_H
        if hovered then
            Render.FilledRect(Vec2(ox + 4, y), Vec2(ox + panelWidth - 4, y + HUD_ROW_H), COLOR_HUD_ROW_HOVER, 4)
        end

        if row.onClick then
            table.insert(hudClickableRows, {
                rect = { x1 = ox, y1 = y, x2 = ox + panelWidth, y2 = y + HUD_ROW_H },
                onClick = row.onClick,
            })
        end

        local textY = y + (HUD_ROW_H - HUD_FONT_ROW) / 2
        local labelX = ox + HUD_PAD

        Render.Text(hudFont, HUD_FONT_ROW, row.label, Vec2(labelX, textY), COLOR_HUD_LABEL)

        local valueSize = Render.TextSize(hudFont, HUD_FONT_ROW, row.value)
        local valueX = ox + panelWidth - HUD_PAD - valueSize.x
        Render.Text(hudFont, HUD_FONT_ROW, row.value, Vec2(valueX, textY), row.valueColor)

        y = y + HUD_ROW_H
    end

    if showIcons then
        local startX = ox + HUD_PAD
        local iconY = y + 4
        State.iconRects = {}
        
        for i, p in ipairs(State.allyPriority) do
            local drawX = startX + (i - 1) * 48
            local drawY = iconY
            
            State.iconRects[i] = { x = drawX, y = drawY, w = 42, h = 24 }
            
            if State.draggingIconIndex ~= i then
                if p.hero then
                    local heroName = NPC.GetUnitName(p.hero)
                    local imgHandle = EnsureHeroImage(heroName)
                    
                    if imgHandle then
                        pcall(Render.Image, imgHandle, Vec2(drawX, drawY), Vec2(42, 24))
                    end
                    
                    if not p.enabled then
                        Render.FilledRect(Vec2(drawX, drawY), Vec2(drawX + 42, drawY + 24), Color(0, 0, 0, 190))
                        Render.Line(Vec2(drawX, drawY), Vec2(drawX + 42, drawY + 24), Color(255, 60, 60, 220), 2)
                        Render.Line(Vec2(drawX + 42, drawY), Vec2(drawX, drawY + 24), Color(255, 60, 60, 220), 2)
                    end
                    Render.Rect(Vec2(drawX, drawY), Vec2(drawX + 42, drawY + 24), Theme.border, 0, Enum.DrawFlags.None, 1)
                end
            end
        end
        
        if State.draggingIconIndex then
            local dragP = State.allyPriority[State.draggingIconIndex]
            if dragP and dragP.hero then
                local heroName = NPC.GetUnitName(dragP.hero)
                local imgHandle = EnsureHeroImage(heroName)
                local dX, dY = State.iconDragPos.x, State.iconDragPos.y
                
                if imgHandle then
                    pcall(Render.Image, imgHandle, Vec2(dX, dY), Vec2(42, 24))
                end
                
                if not dragP.enabled then
                    Render.FilledRect(Vec2(dX, dY), Vec2(dX + 42, dY + 24), Color(0, 0, 0, 190))
                    Render.Line(Vec2(dX, dY), Vec2(dX + 42, dY + 24), Color(255, 60, 60, 220), 2)
                    Render.Line(Vec2(dX + 42, dY), Vec2(dX, dY + 24), Color(255, 60, 60, 220), 2)
                end
                Render.Rect(Vec2(dX, dY), Vec2(dX + 42, dY + 24), Theme.accent, 0, Enum.DrawFlags.None, 2)
            end
        end
    end
end

local function DrawAssistRadius(hero)
    if type(Render) ~= "table" or type(Render.WorldToScreen) ~= "function" then return end

    local assistRadius = SafeGet(UI.AssistRadius, 2000)
    local heroPos = Entity.GetAbsOrigin(hero)
    if not heroPos then return end

    local segments = 48
    local pulse = 0.55 + 0.45 * math.sin(GameRules.GetGameTime() * 2.4)
    local edgeAlpha = 140 + math.floor(pulse * 90)

    local points, visibleFlags = {}, {}
    for i = 0, segments do
        local angle = (i / segments) * math.pi * 2
        local px = heroPos.x + math.cos(angle) * assistRadius
        local py = heroPos.y + math.sin(angle) * assistRadius
        local screenPoint, visible = Render.WorldToScreen(Vector(px, py, heroPos.z))
        points[i + 1] = screenPoint
        visibleFlags[i + 1] = visible
    end

    for i = 1, segments do
        if visibleFlags[i] and visibleFlags[i + 1] then
            Render.Line(points[i], points[i + 1], Color(90, 220, 255, edgeAlpha), 2)
        end
    end
end

script.OnDraw = function()
    if not Engine.IsInGame() then return end
    
    if not uiInitialized then return end
    if not EnsureFont() then return end
    
    if not State.hudVisibleState then return end

    local hero = Heroes.GetLocal()
    if not IsValidTusk(hero) then 
        hudClickableRows = {}
        return 
    end

    if SafeGet(UI.Enabled, false) then
        EnsureTheme()

        if not HasAghanimInInventory(hero) then
            DrawHudPanel({
                { label = "Статус:", value = "НУЖЕН АГАНИМ", valueColor = Theme.bad }
            }, false)
            return
        end

        local currentMode = SafeGet(UI.Mode, MODE_NEAREST)
        local modeText = MODE_ITEMS[currentMode + 1] or "—"
        local snowballOn = SafeGet(UI.AutoSnowball, true)
        local instantOn = SafeGet(UI.InstantSnowball, false)
        local blinkOn = SafeGet(UI.UseBlink, true)
        
        local pLogic = SafeGet(UI.PriorityLogic, 0)
        local showIcons = (currentMode == MODE_SELECTED and pLogic == 0)

        local hudRows = {
            {
                label = "Пинок",
                value = modeText,
                valueColor = Theme.accent,
                onClick = function()
                    if UI.Mode then
                        local nextMode = (currentMode + 1) % #MODE_ITEMS
                        UI.Mode:Set(nextMode)
                    end
                end
            },
            {
                label = "Снежок",
                value = snowballOn and "ВКЛ" or "ВЫКЛ",
                valueColor = snowballOn and Theme.good or Theme.bad,
                onClick = function()
                    if UI.AutoSnowball then
                        UI.AutoSnowball:Set(not snowballOn)
                    end
                end
            },
            {
                label = "Запуск снежка",
                value = instantOn and "ВКЛ" or "ВЫКЛ",
                valueColor = instantOn and Theme.good or Theme.bad,
                onClick = function()
                    if UI.InstantSnowball then
                        UI.InstantSnowball:Set(not instantOn)
                    end
                end
            },
            {
                label = "Блинк",
                value = blinkOn and "ВКЛ" or "ВЫКЛ",
                valueColor = blinkOn and Theme.good or Theme.bad,
                onClick = function()
                    if UI.UseBlink then
                        UI.UseBlink:Set(not blinkOn)
                    end
                end
            }
        }

        DrawHudPanel(hudRows, showIcons)
    end

    if not SafeGet(UI.DrawRadius, false) then return end

    if HasAghanimInInventory(hero) then
        DrawAssistRadius(hero)
    end
end

script.OnThemeUpdate = function()
    Theme.dirty = true
end

script.OnGameEnd = function()
    State.lastCastTime = 0
    State.pendingVectorTarget = nil
    State.pendingVectorStepTime = 0
    State.pendingSnowballTarget = nil
    State.pendingSnowballTime = 0
    State.pendingSnowballLaunchStartTime = 0
    State.pendingSnowballLaunchEndTime = 0
    State.hudDragging = false
    State.draggingIconIndex = nil
    State.allyPriority = {}
    State.HeroImages = {}
end

--#endregion

return script