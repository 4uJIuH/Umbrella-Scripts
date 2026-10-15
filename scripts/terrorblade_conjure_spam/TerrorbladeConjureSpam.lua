local script = {}

local HERO_NAME = "npc_dota_hero_terrorblade"
local ABILITY_NAME = "terrorblade_conjure_image"
local SPELL_ICON = "panorama/images/spellicons/terrorblade_conjure_image_png.vtex_c"
local ENEMY_BLOCK_RADIUS = 500

local LOG_PREFIX = "[TB-ConjureSpam] "

local state = {
    spamActive = false,
    wasToggleKeyDown = false,
    lastReason = "",
    lastReasonTick = 0,
    tick = 0,
    iconHandle = nil,
    iconX = nil,
    iconY = nil,
    mouseWasDown = false,
    mouseDownOnIcon = false,
    dragging = false,
    dragOffsetX = 0,
    dragOffsetY = 0,
    dragStartCursorX = 0,
    dragStartCursorY = 0,
}

local DRAG_THRESHOLD = 4

local UI = nil

local function log(msg)
    if UI and UI.DebugLog and UI.DebugLog:Get() then
        print(LOG_PREFIX .. tostring(msg))
    end
end

local function logOnce(reasonKey, msg)
    if state.lastReason == reasonKey and (state.tick - state.lastReasonTick) < 120 then
        return
    end
    state.lastReason = reasonKey
    state.lastReasonTick = state.tick
    log(msg)
end

local function initializeUI()
    local mainSettings = Menu.Find("Heroes", "Hero List", "Terrorblade", "Main Settings")
    local group = nil

    if mainSettings and mainSettings.Create then
        group = mainSettings:Create("Conjure Image")
    end

    if not group then
        group = Menu.Create("General", "Terrorblade", "Conjure Image", "Settings", "Conjure Spam")
    end

    local ui = {}

    ui.Enabled = group:Switch("Conjure Spam", false)
    ui.Enabled:Image(SPELL_ICON)

    local gear = ui.Enabled:Gear("Settings")
    ui.ToggleKey = gear:Bind("Toggle Key", Enum.ButtonCode.BUTTON_CODE_INVALID)
    ui.ToggleKey:Image(SPELL_ICON)
    ui.BlockIfEnemyNearby = gear:Switch("Don't spam if enemy nearby", false)
    ui.ShowHudIcon = gear:Switch("Show HUD Icon", true)
    ui.HudIconSize = gear:Slider("HUD Icon Size", 24, 96, 48)
    ui.DebugLog = gear:Switch("Debug Log", false)

    local function updateControls()
        local enabled = ui.Enabled:Get()
        ui.ToggleKey:Disabled(not enabled)
        ui.BlockIfEnemyNearby:Disabled(not enabled)
        ui.ShowHudIcon:Disabled(not enabled)
        ui.HudIconSize:Disabled(not enabled)
        ui.DebugLog:Disabled(not enabled)
    end

    ui.Enabled:SetCallback(updateControls, true)

    return ui
end

UI = initializeUI()

local function isLocalTerrorblade(hero)
    return hero and NPC.GetUnitName(hero) == HERO_NAME
end

local function isToggleKeyPressed(bind)
    if not bind then
        return false
    end

    if bind.IsPressed then
        return bind:IsPressed()
    end

    if not bind.Buttons then
        return false
    end

    local key1, key2 = bind:Buttons()
    local invalid = Enum and Enum.ButtonCode and Enum.ButtonCode.BUTTON_CODE_INVALID or -1
    local none = Enum and Enum.ButtonCode and Enum.ButtonCode.KEY_NONE or 0

    local downNow = false
    if key1 and key1 ~= invalid and key1 ~= none and Input.IsKeyDown(key1) then
        downNow = true
    elseif key2 and key2 ~= invalid and key2 ~= none and Input.IsKeyDown(key2) then
        downNow = true
    end

    if downNow and not state.wasToggleKeyDown then
        state.wasToggleKeyDown = true
        return true
    end

    if not downNow then
        state.wasToggleKeyDown = false
    end

    return false
end

local function toggleSpam(source)
    state.spamActive = not state.spamActive
    log("Toggled via " .. source .. " -> spamActive=" .. tostring(state.spamActive))
    if Render and Render.CenteredNotification then
        if state.spamActive then
            Render.CenteredNotification("Conjure Spam: ON", 1.5)
        else
            Render.CenteredNotification("Conjure Spam: OFF", 1.5)
        end
    end
end

local function processToggle()
    if isToggleKeyPressed(UI.ToggleKey) then
        toggleSpam("key")
    end
end

local function getScreenSize()
    if Render and Render.ScreenSize then
        local screen = Render.ScreenSize()
        if screen then
            return screen.x or 1920, screen.y or 1080
        end
    end
    return 1920, 1080
end

local function getIconSize()
    if UI and UI.HudIconSize and UI.HudIconSize.Get then
        return UI.HudIconSize:Get()
    end
    return 48
end

local function ensureIconPosition()
    if state.iconX and state.iconY then return end
    local _, screenH = getScreenSize()
    state.iconX = 12
    state.iconY = screenH - getIconSize() - 12 - 180
end

local function clampIconPosition()
    local screenW, screenH = getScreenSize()
    local size = getIconSize()
    if state.iconX < 0 then state.iconX = 0 end
    if state.iconY < 0 then state.iconY = 0 end
    if state.iconX + size > screenW then state.iconX = screenW - size end
    if state.iconY + size > screenH then state.iconY = screenH - size end
end

local function getIconRect()
    ensureIconPosition()
    local size = getIconSize()
    return state.iconX, state.iconY, size, size
end

local function processHudInput()
    if not UI.ShowHudIcon or not UI.ShowHudIcon:Get() then
        state.mouseWasDown = false
        state.mouseDownOnIcon = false
        state.dragging = false
        return
    end

    if not Input or not Input.IsCursorInRect or not Input.IsKeyDown or not Input.GetCursorPos then
        return
    end

    local mouseKey = Enum and Enum.ButtonCode and Enum.ButtonCode.KEY_MOUSE1
    if not mouseKey then return end

    local down = Input.IsKeyDown(mouseKey)
    local cursorX, cursorY = Input.GetCursorPos()
    local x, y, w, h = getIconRect()

    if down and not state.mouseWasDown then
        if Input.IsCursorInRect(x, y, w, h) then
            state.mouseDownOnIcon = true
            state.dragging = false
            state.dragOffsetX = cursorX - x
            state.dragOffsetY = cursorY - y
            state.dragStartCursorX = cursorX
            state.dragStartCursorY = cursorY
        else
            state.mouseDownOnIcon = false
        end
    elseif down and state.mouseDownOnIcon then
        local dx = cursorX - state.dragStartCursorX
        local dy = cursorY - state.dragStartCursorY
        if not state.dragging and (dx * dx + dy * dy) > (DRAG_THRESHOLD * DRAG_THRESHOLD) then
            state.dragging = true
            log("HUD drag started")
        end
        if state.dragging then
            state.iconX = cursorX - state.dragOffsetX
            state.iconY = cursorY - state.dragOffsetY
            clampIconPosition()
        end
    elseif not down and state.mouseWasDown then
        if state.mouseDownOnIcon and not state.dragging then
            toggleSpam("hud_click")
        elseif state.dragging then
            log("HUD drag ended at x=" .. tostring(state.iconX) .. " y=" .. tostring(state.iconY))
        end
        state.mouseDownOnIcon = false
        state.dragging = false
    end

    state.mouseWasDown = down
end

local function isEnemyNearby(hero, radius)
    local heroes = Heroes and Heroes.GetAll and Heroes.GetAll() or nil
    if not heroes then
        return false
    end

    local heroPos = Entity.GetAbsOrigin(hero)
    for i = 1, #heroes do
        local enemy = heroes[i]
        if enemy
            and enemy ~= hero
            and Entity.IsAlive(enemy)
            and not Entity.IsDormant(enemy)
            and not NPC.IsIllusion(enemy)
            and not Entity.IsSameTeam(enemy, hero)
        then
            if heroPos:Distance2D(Entity.GetAbsOrigin(enemy)) <= radius then
                return true
            end
        end
    end

    return false
end

function script.OnUpdate()
    state.tick = state.tick + 1

    if not UI.Enabled:Get() then
        state.wasToggleKeyDown = false
        state.spamActive = false
        return
    end

    if not Engine.IsInGame() then
        logOnce("not_in_game", "Skip: Engine.IsInGame() false")
        state.wasToggleKeyDown = false
        state.spamActive = false
        return
    end

    local hero = Heroes.GetLocal()
    if not hero then
        logOnce("no_local_hero", "Skip: Heroes.GetLocal() returned nil")
        return
    end

    if not isLocalTerrorblade(hero) then
        logOnce("not_terrorblade", "Skip: local hero is not Terrorblade (got " .. tostring(NPC.GetUnitName(hero)) .. ")")
        state.wasToggleKeyDown = false
        state.spamActive = false
        return
    end

    processToggle()
    processHudInput()

    if not state.spamActive then
        logOnce("spam_off", "Idle: spam toggled OFF (press toggle key to enable)")
        return
    end

    if not Entity.IsAlive(hero) or Entity.IsDormant(hero) then
        logOnce("hero_dead_or_dormant", "Skip: hero dead or dormant")
        return
    end

    if UI.BlockIfEnemyNearby:Get() and isEnemyNearby(hero, ENEMY_BLOCK_RADIUS) then
        logOnce("enemy_nearby", "Skip: enemy within " .. ENEMY_BLOCK_RADIUS .. " range")
        return
    end

    local ability = NPC.GetAbility(hero, ABILITY_NAME)
    if not ability then
        logOnce("no_ability", "Skip: NPC.GetAbility returned nil for " .. ABILITY_NAME)
        return
    end

    local level = Ability.GetLevel(ability)
    if level <= 0 then
        logOnce("not_leveled", "Skip: ability level=" .. tostring(level))
        return
    end

    if not Ability.IsReady(ability) then
        logOnce("not_ready", "Skip: Ability.IsReady=false (cooldown)")
        return
    end

    local mana = NPC.GetMana(hero)
    if not Ability.IsCastable(ability, mana) then
        logOnce("not_castable", "Skip: Ability.IsCastable=false (mana=" .. tostring(mana) .. ")")
        return
    end

    log("Casting " .. ABILITY_NAME .. " (level=" .. tostring(level) .. ", mana=" .. tostring(mana) .. ")")
    state.lastReason = "casting"
    state.lastReasonTick = state.tick
    Ability.CastNoTarget(ability, false, false, true, "tb_conjure_image_spam")
end

local function ensureIconLoaded()
    if state.iconHandle then
        return state.iconHandle
    end
    if Render and Render.LoadImage then
        state.iconHandle = Render.LoadImage(SPELL_ICON)
    end
    return state.iconHandle
end

local function ensureFontLoaded()
    if state.fontHandle ~= nil then
        return state.fontHandle
    end
    if Render and Render.LoadFont then
        local ok, handle = pcall(Render.LoadFont, "Arial", 0, 600)
        if ok and handle then
            state.fontHandle = handle
        else
            state.fontHandle = false
        end
    else
        state.fontHandle = false
    end
    return state.fontHandle
end

function script.OnDraw()
    if not UI or not UI.Enabled or not UI.Enabled:Get() then return end
    if not UI.ShowHudIcon or not UI.ShowHudIcon:Get() then return end
    if not Engine or not Engine.IsInGame or not Engine.IsInGame() then return end

    local hero = Heroes and Heroes.GetLocal and Heroes.GetLocal()
    if not isLocalTerrorblade(hero) then return end

    if not Render or not Render.Image then return end

    local handle = ensureIconLoaded()
    if not handle then return end

    local x, y, w, h = getIconRect()
    local pos = Vec2(x, y)
    local size = Vec2(w, h)

    local hovered = Input and Input.IsCursorInRect and Input.IsCursorInRect(x, y, w, h)

    local tint
    if state.spamActive then
        tint = hovered and Color(180, 255, 180, 255) or Color(120, 255, 120, 230)
    else
        tint = hovered and Color(220, 220, 220, 220) or Color(160, 160, 160, 180)
    end

    local grayscale = state.spamActive and 0.0 or 0.6
    Render.Image(handle, pos, size, tint, 8, 0, Vec2(0, 0), Vec2(1, 1), grayscale)

    if Render.Rect then
        local borderColor = state.spamActive and Color(80, 255, 80, 255) or Color(120, 120, 120, 200)
        Render.Rect(pos, Vec2(x + w, y + h), borderColor, 8)
    end

    local font = ensureFontLoaded()
    if Render.Text and font then
        local label = state.spamActive and "ON" or "OFF"
        local labelColor = state.spamActive and Color(80, 255, 80, 255) or Color(200, 80, 80, 230)
        Render.Text(font, 14, label, Vec2(x, y + h + 2), labelColor)
    end
end

function script.OnGameEnd()
    state.spamActive = false
    state.wasToggleKeyDown = false
    state.wasMouseDownOnIcon = false
    state.lastReason = ""
    state.tick = 0
end

return script
