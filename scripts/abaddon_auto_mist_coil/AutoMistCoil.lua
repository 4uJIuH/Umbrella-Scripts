--[[
    Auto Mist Coil
    Abaddon Q: heal allies with HP thresholds and an ally panel.
    Script by 花曇り hanagumori
--]]

local Script = {}

--#region Constants
local NAME = "AutoMistCoil"
local HERO_NAME = "npc_dota_hero_abaddon"
local ABILITY_MIST_COIL = "abaddon_death_coil"
local ORDER_ID = "AutoMistCoil"
local UPDATE_INTERVAL = 0.10
local CONFIG_FILE = "auto_mist_coil"
local ALLY_SYNC_INTERVAL = 0.50

local MENU_FIRST = "Heroes"
local MENU_SECTION = "Hero List"
local MENU_SECOND = "Abaddon"
local MENU_THIRD = "Auto Usage"
local MENU_GROUP = "AutoMistCoil"

local ICON_ENABLE = "\u{f00c}"
local ICON_GEAR = "\u{f013}"
local ICON_PANEL = "\u{f108}"
local ICON_HEART = "\u{f004}"
local ICON_HEARTBEAT = "\u{f21e}"
local ICON_SORT = "\u{f0dc}"
local ICON_SHIELD = "\u{f3ed}"
local ICON_MIST_COIL = "panorama/images/spellicons/abaddon_death_coil_png.vtex_c"
local COLOR_WHITE = Color(255, 255, 255, 255)

local PRIORITY_HP_PCT = 0
local PRIORITY_HP = 1
local PRIORITY_MISSING = 2

local Locale = {
    group_name = {
        en = "AutoMistCoil",
        ru = "AutoMistCoil",
        cn = "AutoMistCoil",
    },
    gear_settings = {
        en = "Settings",
        ru = "Настройки",
        cn = "设置",
    },
    panel_title = {
        en = "AutoMistCoil",
        ru = "AutoMistCoil",
        cn = "AutoMistCoil",
    },
    ui_enabled = {
        en = "Enable",
        ru = "Включить",
        cn = "启用",
    },
    ui_auto_heal = {
        en = "Auto Heal",
        ru = "Автолечение",
        cn = "自动治疗",
    },
    ui_show_panel = {
        en = "Show Panel",
        ru = "Показать панель",
        cn = "显示面板",
    },
    ui_heal_below = {
        en = "Heal Below HP %",
        ru = "Лечить ниже HP %",
        cn = "低于HP%治疗",
    },
    ui_stop_above = {
        en = "Stop Above HP %",
        ru = "Стоп выше HP %",
        cn = "高于HP%停止",
    },
    ui_heal_priority = {
        en = "Heal Priority",
        ru = "Приоритет лечения",
        cn = "治疗优先级",
    },
    ui_min_self = {
        en = "Min Self HP %",
        ru = "Мин. своё HP %",
        cn = "自身最低HP%",
    },
    priority_hp_pct = {
        en = "Lowest HP %",
        ru = "Наименьший HP %",
        cn = "最低生命%",
    },
    priority_hp = {
        en = "Lowest HP",
        ru = "Наименьший HP",
        cn = "最低生命值",
    },
    priority_missing = {
        en = "Most missing HP",
        ru = "Больше всего недостающего HP",
        cn = "缺口最大HP",
    },
    tip_enabled = {
        en = "Master switch for Auto Mist Coil on Abaddon.",
        ru = "Главный переключатель Auto Mist Coil для Abaddon.",
        cn = "Abaddon Auto Mist Coil 脚本总开关。",
    },
    tip_auto_heal = {
        en = "Cast Mist Coil on allies at or below Heal Below HP %. Keeps healing until Stop Above. Never casts Q on yourself.",
        ru = "Кастует Mist Coil по союзникам при HP % ≤ «Лечить ниже». Держит цель до «Стоп выше». На себя Q не кастует.",
        cn = "当友军生命%≤「低于HP%治疗」时对其施放 Mist Coil，持续到「高于HP%停止」。不会对自己释放Q。",
    },
    tip_show_panel = {
        en = "Ally toggle HUD. Click a hero chip to allow or deny auto-heal for that ally. Drag the header to move the panel.",
        ru = "Панель союзников. Клик по иконке героя — разрешить/запретить автолечение. Перетаскивай за заголовок.",
        cn = "友军开关面板。点击英雄图标允许/禁止对其自动治疗。拖动标题栏可移动面板。",
    },
    tip_heal_below = {
        en = "Start healing when an ally's HP % is at or below this value.",
        ru = "Начинать лечение, когда HP % союзника на этом значении или ниже.",
        cn = "友军生命%达到或低于此值时开始治疗。",
    },
    tip_stop_above = {
        en = "Stop sticky heal when the ally's HP % rises above this value.",
        ru = "Снять «липкую» цель лечения, когда HP % союзника выше этого значения.",
        cn = "友军生命%高于此值时停止对该目标的粘性治疗。",
    },
    tip_heal_priority = {
        en = "How to choose among allies who need a heal.",
        ru = "Как выбирать союзника среди подходящих по порогу лечения.",
        cn = "在符合治疗条件的友军中如何选择目标。",
    },
    tip_min_self = {
        en = "Do not cast if your own HP % is below this. Mist Coil still damages you when cast on others; Q is never cast on yourself.",
        ru = "Не кастовать, если своё HP % ниже. Mist Coil всё равно бьёт тебя при касте по другим; на себя Q не кастуется.",
        cn = "自身生命%低于此值时不施放。对他人施放 Mist Coil 时仍会自伤；不会对自己释放Q。",
    },
}
local PANEL_HEADER_HEIGHT = 28
local PANEL_HEADER_PAD_X = 8
local PANEL_HEADER_TEXT_SIZE = 14
local PANEL_HEADER_ICON_SIZE = 14
local PANEL_HEADER_ICON_GAP = 6
local PANEL_HEADER_RADIUS = 5
local PANEL_BODY_PAD_Y = 6
local PANEL_CELL_W = 44
local PANEL_CELL_H = 26
local PANEL_CELL_SPACING = 6
local PANEL_CELL_RADIUS = 3
local PANEL_CHIP_ENABLED_ALPHA = 255
local PANEL_CHIP_DISABLED_ALPHA = 105
local PANEL_CHIP_MIN_BORDER_LUMA = 90
local PANEL_MIN_WIDTH = 110
local PANEL_BLUR_BASE_STRENGTH = 2.5
local PANEL_SHADOW_THICKNESS = 14
local PANEL_CHIP_TOGGLE_SPEED = 10

local STYLE_KEYS = {
    "active_widgets_text", "additional_background", "button_active_background",
    "button_background", "combo_frame", "combo_item", "combo_item_active",
    "disabled_switch_background", "disabled_switch_circle", "enabled_switch_background",
    "group_background", "group_outline", "healthbar_ally", "healthbar_enemy",
    "healthbar_roshan", "healthbar_self", "hero_tab_filter_background",
    "hero_tab_filter_separator", "indication_active", "indication_inactive",
    "input_text_bg", "keybind_background", "keybind_background_active",
    "left_tabs_background", "main_background", "manabar", "multiselect_item",
    "multiselect_item_selected", "outline", "popup_background", "popup_border",
    "primary", "primary_first_tab_text", "primary_second_tab_text",
    "primary_widgets_text", "scrollbar_bg", "search_outline", "search_text",
    "section_group_text", "selected_tabs_background", "separator", "shadow",
    "slider_background", "slider_background_active", "slider_grab",
    "slider_grab_active", "text_shadow", "third_tab_text", "widgets_shadow",
}
--#endregion

--#region State
---@class AutoMistCoilUI
---@field enabled CMenuSwitch|nil
---@field autoHeal CMenuSwitch|nil
---@field healGear CMenuGearAttachment|nil
---@field healStartHpPct CMenuSliderInt|nil
---@field healStopHpPct CMenuSliderInt|nil
---@field healPriority CMenuComboBox|nil
---@field minSelfHpPct CMenuSliderInt|nil
---@field showPanel CMenuSwitch|nil
local UI = {
    enabled = nil,
    autoHeal = nil,
    healGear = nil,
    healStartHpPct = nil,
    healStopHpPct = nil,
    healPriority = nil,
    minSelfHpPct = nil,
    showPanel = nil,
}

local Persistent = {
    ---@type Logger|nil
    logger = nil,
    ---@type integer|nil
    font = nil,
    ---@type integer|nil
    mistCoilIcon = nil,
    ---@type table<string, integer>
    heroIcons = {},
    ---@type CMenuSliderInt|CMenuSliderFloat|nil
    blurFactor = nil,
    ---@type CMenuGroup|nil
    menuGroup = nil,
    languageWidget = nil,
    languageLookupAt = 0,
    lastLanguage = nil,
    languageCallbackSet = false,
}

local Style = {}

local Colors = {
    HeaderBg = Color(18, 18, 22, 255),
    TextHeader = Color(245, 247, 250, 255),
    TextShadow = Color(0, 0, 0, 140),
    BorderEnabled = Color(180, 180, 190, 255),
    CellBg = Color(12, 12, 16, 255),
    Shadow = Color(0, 0, 0, 160),
}

local PanelConfig = { X = 200, Y = 200 }
local PanelDrag = { IsDragging = false, OffsetX = 0, OffsetY = 0 }

local Runtime = {
    lastUpdateAt = -math.huge,
    lastAllySyncAt = -math.huge,
    lastPanelDrawAt = -math.huge,
    wasMousePressed = false,
    ---@type table<string, boolean>
    healEnabled = {},
    ---@type table<string, number>
    chipVisual = {},
    ---@type string[]
    allyNames = {},
    ---@type table<string, string>
    allyUnitNames = {},
    ---@type integer|nil
    stickyHealIndex = nil,
}
--#endregion

--#region Helpers
local function GetLanguageWidget()
    local now = os.clock()
    if Persistent.languageWidget and now < Persistent.languageLookupAt then
        return Persistent.languageWidget
    end

    Persistent.languageLookupAt = now + 1.0
    Persistent.languageWidget = Menu.Find("SettingsHidden", "", "", "", "Main", "Language")
    return Persistent.languageWidget
end

local function GetLanguageCode()
    local widget = GetLanguageWidget()
    local value = widget and widget:Get() or "en"

    if type(value) == "number" then
        if value == 1 then
            return "ru"
        end
        if value == 2 then
            return "cn"
        end
        return "en"
    end

    value = tostring(value or "en"):lower()
    if value == "ru" or value:find("рус", 1, true) or value:find("russian", 1, true) then
        return "ru"
    end
    if value == "cn"
        or value == "zh"
        or value:find("chinese", 1, true)
        or value:find("中文", 1, true)
        or value:find("中国", 1, true)
        or value:find("简体", 1, true) then
        return "cn"
    end
    return "en"
end

local function L(key)
    local entry = Locale[key]
    if not entry then
        return tostring(key)
    end
    local lang = GetLanguageCode()
    return entry[lang] or entry.en or tostring(key)
end

local function PriorityItems()
    return {
        L("priority_hp_pct"),
        L("priority_hp"),
        L("priority_missing"),
    }
end

local function MenuLabel(widget, key)
    if widget then
        widget:ForceLocalization(L(key))
    end
end

local function MenuTip(widget, key)
    if widget then
        widget:ToolTip(L(key))
    end
end

local function ApplyLocalization(force)
    local lang = GetLanguageCode()
    if not force and Persistent.lastLanguage == lang then
        return
    end
    Persistent.lastLanguage = lang

    MenuLabel(Persistent.menuGroup, "group_name")
    MenuLabel(UI.healGear, "gear_settings")

    MenuLabel(UI.enabled, "ui_enabled")
    MenuTip(UI.enabled, "tip_enabled")

    MenuLabel(UI.autoHeal, "ui_auto_heal")
    MenuTip(UI.autoHeal, "tip_auto_heal")

    MenuLabel(UI.showPanel, "ui_show_panel")
    MenuTip(UI.showPanel, "tip_show_panel")

    MenuLabel(UI.healStartHpPct, "ui_heal_below")
    MenuTip(UI.healStartHpPct, "tip_heal_below")

    MenuLabel(UI.healStopHpPct, "ui_stop_above")
    MenuTip(UI.healStopHpPct, "tip_stop_above")

    MenuLabel(UI.healPriority, "ui_heal_priority")
    MenuTip(UI.healPriority, "tip_heal_priority")
    if UI.healPriority then
        local selected = UI.healPriority:Get() or PRIORITY_HP_PCT
        UI.healPriority:Update(PriorityItems(), selected)
    end

    MenuLabel(UI.minSelfHpPct, "ui_min_self")
    MenuTip(UI.minSelfHpPct, "tip_min_self")
end

local function SetupLanguageCallback()
    if Persistent.languageCallbackSet then
        return
    end

    local widget = GetLanguageWidget()
    if not widget then
        return
    end

    Persistent.languageCallbackSet = true
    local previous = widget:Get()
    widget:SetCallback(function(ctrl)
        local current = (ctrl or widget):Get()
        if current == previous then
            return
        end
        previous = current
        Persistent.lastLanguage = nil
        ApplyLocalization(true)
    end)
end

local function ResetRuntime()
    Runtime.lastUpdateAt = -math.huge
    Runtime.lastAllySyncAt = -math.huge
    Runtime.lastPanelDrawAt = -math.huge
    Runtime.wasMousePressed = false
    Runtime.healEnabled = {}
    Runtime.chipVisual = {}
    Runtime.allyNames = {}
    Runtime.allyUnitNames = {}
    Runtime.stickyHealIndex = nil
    PanelDrag.IsDragging = false
end

local function ChannelByte(value)
    if type(value) ~= "number" then
        return nil
    end
    if value <= 1 then
        return math.floor(value * 255 + 0.5)
    end
    return math.floor(value + 0.5)
end

local function NormalizeThemeColor(value)
    if value == nil then
        return nil
    end
    local r = ChannelByte(value.r)
    local g = ChannelByte(value.g)
    local b = ChannelByte(value.b)
    local a = ChannelByte(value.a)
    if not r or not g or not b then
        return nil
    end
    return Color(r, g, b, a or 255)
end

local function TryGetThemeColor(key, all)
    local normalized = NormalizeThemeColor(Menu.Style(key))
    if normalized then
        return normalized
    end
    if type(all) == "table" then
        return NormalizeThemeColor(all[key])
    end
    return nil
end

local function PickAccent(candidates)
    local best, bestScore = nil, -1
    for i = 1, #candidates do
        local c = candidates[i]
        if c then
            local score = (c.a or 0) * 3 + (c.r or 0) + (c.g or 0) + (c.b or 0)
            if score > bestScore then
                bestScore = score
                best = c
            end
        end
    end
    return best
end

local function ColorLuminance(color)
    if not color then
        return 0
    end
    return 0.299 * (color.r or 0) + 0.587 * (color.g or 0) + 0.114 * (color.b or 0)
end

local function SyncColors()
    local all = Menu.Style()
    for i = 1, #STYLE_KEYS do
        local key = STYLE_KEYS[i]
        Style[key] = TryGetThemeColor(key, all)
    end
    if type(all) == "table" then
        for key, _ in pairs(all) do
            if Style[key] == nil then
                Style[key] = TryGetThemeColor(key, all)
            end
        end
    end

    Colors.HeaderBg = Style.additional_background
        or Style.popup_background
        or Style.main_background
        or Style.group_background
        or Colors.HeaderBg
    Colors.TextHeader = Style.primary_widgets_text
        or Style.active_widgets_text
        or Colors.TextHeader

    local border = PickAccent({
        Style.enabled_switch_background,
        Style.combo_item_active,
        Style.primary,
        Style.indication_active,
        Style.multiselect_item_selected,
        Style.button_active_background,
        Style.slider_grab_active,
    })
    if border then
        Colors.BorderEnabled = border
    end

    local cellBg = Style.group_background
        or Style.button_background
        or Style.combo_frame
        or Style.input_text_bg
    if cellBg then
        Colors.CellBg = Color(cellBg.r, cellBg.g, cellBg.b, 255)
    end

    if Style.shadow and (Style.shadow.a or 0) > 0 then
        Colors.Shadow = Style.shadow
    else
        Colors.Shadow = Color(0, 0, 0, 0)
    end

    if Style.text_shadow and (Style.text_shadow.a or 0) > 0 then
        Colors.TextShadow = Style.text_shadow
    else
        Colors.TextShadow = Color(0, 0, 0, 140)
    end
end

local function GetChipBorderColor()
    local accent = Colors.BorderEnabled
    if ColorLuminance(accent) >= PANEL_CHIP_MIN_BORDER_LUMA then
        return Color(accent.r, accent.g, accent.b, 255)
    end
    local text = Colors.TextHeader
    return Color(text.r, text.g, text.b, 255)
end

local function ResolveFont()
    local candidates = {
        { "Segoe UI", Enum.FontCreate.FONTFLAG_ANTIALIAS, 600 },
        { "Tahoma", Enum.FontCreate.FONTFLAG_ANTIALIAS, 500 },
        { "Arial", Enum.FontCreate.FONTFLAG_ANTIALIAS, 400 },
    }
    for i = 1, #candidates do
        local c = candidates[i]
        local font = Render.LoadFont(c[1], c[2], c[3])
        if font and font ~= 0 then
            local size = Render.TextSize(font, PANEL_HEADER_TEXT_SIZE, L("panel_title"))
            if size and (size.x or 0) > 0 and (size.y or 0) > 0 then
                return font
            end
        end
    end
    return nil
end

local function MeasureText(font, fontSize, text)
    if not font or font == 0 then
        return Vec2(#text * fontSize * 0.55, fontSize)
    end
    local size = Render.TextSize(font, fontSize, text)
    if size and type(size.x) == "number" and type(size.y) == "number" then
        return size
    end
    return Vec2(#text * fontSize * 0.55, fontSize)
end

local function LoadPanelPosition()
    PanelConfig.X = Config.ReadInt(CONFIG_FILE, "panel_x", 200)
    PanelConfig.Y = Config.ReadInt(CONFIG_FILE, "panel_y", 200)
end

local function SavePanelPosition()
    Config.WriteInt(CONFIG_FILE, "panel_x", math.floor(PanelConfig.X + 0.5))
    Config.WriteInt(CONFIG_FILE, "panel_y", math.floor(PanelConfig.Y + 0.5))
end

local function GetBlurStrength()
    local widget = Persistent.blurFactor
    if not widget then
        return PANEL_BLUR_BASE_STRENGTH
    end
    local factor = widget:Get()
    if type(factor) ~= "number" or factor <= 0 then
        return nil
    end
    if factor > 1 then
        factor = factor / 100
    end
    return math.max(0.1, factor * PANEL_BLUR_BASE_STRENGTH)
end

local function SyncOptionDisabled()
    local masterOff = UI.enabled == nil or UI.enabled:Get() ~= true
    local healOff = masterOff or UI.autoHeal == nil or UI.autoHeal:Get() ~= true

    if UI.autoHeal then UI.autoHeal:Disabled(masterOff) end
    if UI.showPanel then UI.showPanel:Disabled(masterOff) end
    if UI.healGear then UI.healGear:Disabled(healOff) end
    if UI.healStartHpPct then UI.healStartHpPct:Disabled(healOff) end
    if UI.healStopHpPct then UI.healStopHpPct:Disabled(healOff) end
    if UI.healPriority then UI.healPriority:Disabled(healOff) end
    if UI.minSelfHpPct then UI.minSelfHpPct:Disabled(healOff) end
end

local function GetHealThresholds()
    local startPct = UI.healStartHpPct and UI.healStartHpPct:Get() or 45
    local stopPct = UI.healStopHpPct and UI.healStopHpPct:Get() or 70
    if stopPct < startPct then
        stopPct = startPct
    end
    return startPct, stopPct
end

local function OnEnabledChanged(widget)
    SyncOptionDisabled()
    if not widget:Get() then
        ResetRuntime()
    end
end

local function CleanHeroName(unitName)
    if not unitName or unitName == "" then
        return ""
    end
    return (unitName:gsub("^npc_dota_hero_", ""))
end

local function HpPercent(unit)
    local maxHp = Entity.GetMaxHealth(unit)
    if not maxHp or maxHp <= 0 then
        return 100
    end
    return ((Entity.GetHealth(unit) or 0) / maxHp) * 100
end

local function IsHealEnabled(cleanName)
    if cleanName == "" then
        return false
    end
    local enabled = Runtime.healEnabled[cleanName]
    if enabled == nil then
        return true
    end
    return enabled == true
end

local function SetHealEnabled(cleanName, enabled)
    if cleanName ~= "" then
        Runtime.healEnabled[cleanName] = enabled == true
    end
end

local function UpdateChipVisual(cleanName, enabled, dt)
    local target = enabled and 1 or 0
    local cur = Runtime.chipVisual[cleanName]
    if cur == nil then
        Runtime.chipVisual[cleanName] = target
        return target
    end
    if dt <= 0 then
        return cur
    end
    local step = dt * PANEL_CHIP_TOGGLE_SPEED
    if cur < target then
        cur = math.min(target, cur + step)
    elseif cur > target then
        cur = math.max(target, cur - step)
    end
    Runtime.chipVisual[cleanName] = cur
    return cur
end

local function EaseChipVisual(t)
    return t * t * (3 - 2 * t)
end

local function GetHeroIcon(unitName)
    if not unitName or unitName == "" then
        return nil
    end
    local cached = Persistent.heroIcons[unitName]
    if cached then
        return cached
    end
    local handle = Render.LoadImage("panorama/images/heroes/" .. unitName .. "_png.vtex_c")
    if handle and handle ~= 0 then
        Persistent.heroIcons[unitName] = handle
        return handle
    end
    return nil
end

local function IsValidUnit(unit)
    return unit
        and Entity.IsAlive(unit) == true
        and Entity.IsDormant(unit) ~= true
        and NPC.IsVisible(unit) == true
        and NPC.IsIllusion(unit) ~= true
end

local function CanAffordSelfDamage(me, ability)
    local heal = Ability.GetLevelSpecialValueFor(ability, "damage_heal") or 0
    local pct = Ability.GetLevelSpecialValueFor(ability, "self_damage") or 0
    local selfHit = heal * (pct / 100)
    if (Entity.GetHealth(me) or 0) <= selfHit then
        return false
    end
    local minPct = UI.minSelfHpPct and UI.minSelfHpPct:Get() or 0
    return HpPercent(me) >= minPct
end

local function ScoreHealTarget(hero, priority)
    local hp = Entity.GetHealth(hero) or 0
    local maxHp = Entity.GetMaxHealth(hero) or 1
    if priority == PRIORITY_HP then
        return hp
    end
    if priority == PRIORITY_MISSING then
        return -(maxHp - hp)
    end
    return (hp / maxHp) * 100
end

local function StickyStillValid(me, sticky, range, stopPct)
    if not IsValidUnit(sticky) or sticky == me then
        return false
    end
    if Entity.GetTeamNum(sticky) ~= Entity.GetTeamNum(me) then
        return false
    end
    if not IsHealEnabled(CleanHeroName(NPC.GetUnitName(sticky))) then
        return false
    end
    if HpPercent(sticky) > stopPct then
        return false
    end
    local origin = Entity.GetAbsOrigin(me)
    local targetPos = Entity.GetAbsOrigin(sticky)
    if not origin or not targetPos then
        return false
    end
    return origin:Distance(targetPos) <= range
end

local function FindHealTarget(me, range)
    if not UI.autoHeal or UI.autoHeal:Get() ~= true then
        return nil
    end

    local startPct, stopPct = GetHealThresholds()
    local priority = UI.healPriority and UI.healPriority:Get() or PRIORITY_HP_PCT

    if Runtime.stickyHealIndex then
        local sticky = Entity.Get(Runtime.stickyHealIndex)
        if StickyStillValid(me, sticky, range, stopPct) then
            return sticky
        end
        Runtime.stickyHealIndex = nil
    end

    local best, bestScore = nil, math.huge
    local allies = Entity.GetHeroesInRadius(me, range, Enum.TeamType.TEAM_FRIEND, true, true)
    if allies then
        for i = 1, #allies do
            local ally = allies[i]
            if ally ~= me
                and IsValidUnit(ally)
                and IsHealEnabled(CleanHeroName(NPC.GetUnitName(ally)))
                and HpPercent(ally) <= startPct
            then
                local score = ScoreHealTarget(ally, priority)
                if score < bestScore then
                    bestScore = score
                    best = ally
                end
            end
        end
    end

    if best then
        Runtime.stickyHealIndex = Entity.GetIndex(best)
    end
    return best
end

local function UpdateMistCoil(me)
    if NPC.GetUnitName(me) ~= HERO_NAME then
        return
    end
    if NPC.IsSilenced(me) == true or NPC.IsStunned(me) == true then
        return
    end
    if NPC.IsChannellingAbility(me) == true then
        return
    end

    local ability = NPC.GetAbility(me, ABILITY_MIST_COIL)
    if not ability then
        return
    end
    if Ability.IsReady(ability) ~= true then
        return
    end
    if Ability.IsCastable(ability, NPC.GetMana(me)) ~= true then
        return
    end
    if Ability.IsInAbilityPhase(ability) == true then
        return
    end
    if not CanAffordSelfDamage(me, ability) then
        return
    end

    local range = (Ability.GetCastRange(ability) or 0) + (NPC.GetCastRangeBonus(me) or 0)
    local healTarget = FindHealTarget(me, range)
    if healTarget then
        Ability.CastTarget(ability, healTarget, false, true, false, ORDER_ID)
    end
end

local function SyncAllyRoster(me, now)
    if now - Runtime.lastAllySyncAt < ALLY_SYNC_INTERVAL then
        return
    end
    Runtime.lastAllySyncAt = now

    local myTeam = Entity.GetTeamNum(me)
    local names, unitNames = {}, {}
    local all = Heroes.GetAll()
    if all then
        for i = 1, #all do
            local hero = all[i]
            if hero
                and hero ~= me
                and Entity.GetTeamNum(hero) == myTeam
                and NPC.IsIllusion(hero) ~= true
            then
                local unitName = NPC.GetUnitName(hero) or ""
                local cleanName = CleanHeroName(unitName)
                if cleanName ~= "" then
                    names[#names + 1] = cleanName
                    unitNames[cleanName] = unitName
                    if Runtime.healEnabled[cleanName] == nil then
                        Runtime.healEnabled[cleanName] = true
                    end
                end
            end
        end
    end
    table.sort(names)
    Runtime.allyNames = names
    Runtime.allyUnitNames = unitNames
end

local function DrawPanelText(font, size, text, pos, color)
    if not font or font == 0 then
        return
    end
    local shadow = Colors.TextShadow
    if shadow and (shadow.a or 0) > 0 then
        Render.Text(font, size, text, Vec2(pos.x + 1, pos.y + 1), shadow)
    end
    Render.Text(font, size, text, pos, color)
end

local function GetPanelLayout(scale, numAllies, screenSize)
    local cellW = PANEL_CELL_W * scale
    local cellH = PANEL_CELL_H * scale
    local cellSpacing = PANEL_CELL_SPACING * scale
    local titleH = PANEL_HEADER_HEIGHT * scale
    local padX = PANEL_HEADER_PAD_X * scale
    local padY = PANEL_BODY_PAD_Y * scale
    local titleFontSize = PANEL_HEADER_TEXT_SIZE * scale
    local titleText = L("panel_title")
    local titleSize = MeasureText(Persistent.font, titleFontSize, titleText)
    local titleIconSize = PANEL_HEADER_ICON_SIZE * scale
    local titleIconGap = PANEL_HEADER_ICON_GAP * scale
    local hasSpellIcon = Persistent.mistCoilIcon and Persistent.mistCoilIcon ~= 0
    local titleIconW = hasSpellIcon and titleIconSize or 0
    local titleIconH = hasSpellIcon and titleIconSize or 0
    local gap = hasSpellIcon and titleIconGap or 0
    local titleContentW = titleIconW + gap + (titleSize.x or 0)
    local cellsTotalW = numAllies * cellW + math.max(0, numAllies - 1) * cellSpacing
    local width = math.max(padX + titleContentW + padX, padX + cellsTotalW + padX, PANEL_MIN_WIDTH * scale)
    local height = titleH + padY + cellH + padY
    local x = math.max(0, math.min(screenSize.x - width, PanelConfig.X))
    local y = math.max(0, math.min(screenSize.y - height, PanelConfig.Y))

    return {
        cellW = cellW,
        cellH = cellH,
        cellSpacing = cellSpacing,
        titleH = titleH,
        padX = padX,
        titleText = titleText,
        titleIconSize = titleIconSize,
        titleIconGap = gap,
        hasSpellIcon = hasSpellIcon,
        titleSize = titleSize,
        titleFontSize = titleFontSize,
        width = width,
        height = height,
        x = x,
        y = y,
        rowY = y + titleH + padY,
        cellsStartX = x + math.floor((width - cellsTotalW) * 0.5 + 0.5),
    }
end

local function DrawPanelHeaderShadow(layout, scale)
    local shadow = Colors.Shadow
    if not shadow or (shadow.a or 0) <= 0 then
        return
    end
    local thickness = math.max(6, PANEL_SHADOW_THICKNESS * scale * (0.55 + (shadow.a or 0) / 255))
    Render.Shadow(
        Vec2(layout.x, layout.y),
        Vec2(layout.x + layout.width, layout.y + layout.titleH),
        shadow,
        thickness,
        PANEL_HEADER_RADIUS * scale,
        Enum.DrawFlags.ShadowCutOutShapeBackground)
end

local function DrawPanelBlur(layout, scale)
    local headerA = Colors.HeaderBg.a or 255
    if headerA >= 255 then
        return
    end
    local strength = GetBlurStrength()
    if not strength then
        return
    end
    Render.Blur(
        Vec2(layout.x, layout.y),
        Vec2(layout.x + layout.width, layout.y + layout.titleH),
        strength,
        1.0,
        PANEL_HEADER_RADIUS * scale,
        Enum.DrawFlags.None)
end

local function DrawPanel(me)
    if not UI.showPanel or UI.showPanel:Get() ~= true then
        return
    end
    if Menu.VisualsIsEnabled() ~= true then
        return
    end
    if not Persistent.font then
        Persistent.font = ResolveFont()
    end

    SyncAllyRoster(me, GameRules.GetGameTime())
    local numAllies = #Runtime.allyNames
    if numAllies == 0 then
        return
    end

    local scale = (Menu.Scale() or 100) / 100
    local screenSize = Render.ScreenSize()
    if not screenSize or (screenSize.x or 0) <= 1 or (screenSize.y or 0) <= 1 then
        return
    end

    local layout = GetPanelLayout(scale, numAllies, screenSize)
    local mx, my = Input.GetCursorPos()
    local isDown = Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE1, true) == true
    local isClicked = isDown and not Runtime.wasMousePressed
    local isCursorValid = mx ~= nil and my ~= nil
    local isOverHeader = isCursorValid
        and mx >= layout.x and mx <= layout.x + layout.width
        and my >= layout.y and my <= layout.y + layout.titleH

    if isClicked and isOverHeader then
        PanelDrag.IsDragging = true
        PanelDrag.OffsetX = mx - layout.x
        PanelDrag.OffsetY = my - layout.y
    elseif not isDown then
        if PanelDrag.IsDragging then
            SavePanelPosition()
        end
        PanelDrag.IsDragging = false
    end

    if PanelDrag.IsDragging and mx and my then
        PanelConfig.X = math.max(0, math.min(screenSize.x - layout.width, mx - PanelDrag.OffsetX))
        PanelConfig.Y = math.max(0, math.min(screenSize.y - layout.height, my - PanelDrag.OffsetY))
        layout = GetPanelLayout(scale, numAllies, screenSize)
    end

    local clickTriggered = isClicked and Input.IsInputCaptured() ~= true
    Runtime.wasMousePressed = isDown

    local titleFontSize = layout.titleFontSize
    local titleSizeY = layout.titleSize.y or titleFontSize
    local titleIconSize = layout.titleIconSize or 0
    local titleContentH = math.max(titleSizeY, titleIconSize)
    local titleContentY = layout.y + math.floor((layout.titleH - titleContentH) * 0.5 + 0.5)
    local textX = layout.x + layout.padX
    local textY = titleContentY + math.floor((titleContentH - titleSizeY) * 0.5 + 0.5)
    local cellRadius = PANEL_CELL_RADIUS * scale

    DrawPanelBlur(layout, scale)
    DrawPanelHeaderShadow(layout, scale)
    Render.FilledRect(
        Vec2(layout.x, layout.y),
        Vec2(layout.x + layout.width, layout.y + layout.titleH),
        Colors.HeaderBg,
        PANEL_HEADER_RADIUS * scale)

    if layout.hasSpellIcon then
        local iconY = titleContentY + math.floor((titleContentH - titleIconSize) * 0.5 + 0.5)
        Render.Image(
            Persistent.mistCoilIcon,
            Vec2(textX, iconY),
            Vec2(titleIconSize, titleIconSize),
            COLOR_WHITE)
        textX = textX + titleIconSize + layout.titleIconGap
    end
    DrawPanelText(Persistent.font, titleFontSize, layout.titleText, Vec2(textX, textY), Colors.TextHeader)

    local borderColor = GetChipBorderColor()
    local nowClock = os.clock()
    local dt = 0
    if Runtime.lastPanelDrawAt > 0 then
        dt = math.max(0, math.min(0.05, nowClock - Runtime.lastPanelDrawAt))
    end
    Runtime.lastPanelDrawAt = nowClock

    for i = 1, numAllies do
        local cleanName = Runtime.allyNames[i]
        local cellX = layout.cellsStartX + (i - 1) * (layout.cellW + layout.cellSpacing)
        local enabled = IsHealEnabled(cleanName)
        local visual = EaseChipVisual(UpdateChipVisual(cleanName, enabled, dt))
        local imgAlpha = math.floor(
            PANEL_CHIP_DISABLED_ALPHA
                + (PANEL_CHIP_ENABLED_ALPHA - PANEL_CHIP_DISABLED_ALPHA) * visual
                + 0.5)
        local imgHandle = GetHeroIcon(Runtime.allyUnitNames[cleanName] or "")
        local isCellHovered = isCursorValid
            and mx >= cellX and mx <= cellX + layout.cellW
            and my >= layout.rowY and my <= layout.rowY + layout.cellH

        Render.FilledRect(
            Vec2(cellX, layout.rowY),
            Vec2(cellX + layout.cellW, layout.rowY + layout.cellH),
            Colors.CellBg,
            cellRadius)

        if imgHandle then
            Render.Image(
                imgHandle,
                Vec2(cellX, layout.rowY),
                Vec2(layout.cellW, layout.cellH),
                Color(255, 255, 255, imgAlpha),
                cellRadius,
                Enum.DrawFlags.None,
                Vec2(0, 0),
                Vec2(1, 1),
                1.0 - visual)
        end

        if visual > 0.01 then
            Render.Rect(
                Vec2(cellX, layout.rowY),
                Vec2(cellX + layout.cellW, layout.rowY + layout.cellH),
                Color(borderColor.r, borderColor.g, borderColor.b, math.floor(255 * visual + 0.5)),
                cellRadius,
                Enum.DrawFlags.None,
                1.1)
        end

        if isCellHovered and clickTriggered and not PanelDrag.IsDragging then
            SetHealEnabled(cleanName, not enabled)
        end
    end
end
--#endregion

--#region Lifecycle
function Script.OnScriptsLoaded()
    Persistent.logger = Logger(NAME)
    Persistent.font = ResolveFont()
    Persistent.mistCoilIcon = Render.LoadImage(ICON_MIST_COIL)
    Persistent.blurFactor = Menu.Find("SettingsHidden", "", "", "", "Visual", "Menu Blur Factor")
    LoadPanelPosition()
    SyncColors()

    local group = Menu.Create(MENU_FIRST, MENU_SECTION, MENU_SECOND, MENU_THIRD, MENU_GROUP)
    Persistent.menuGroup = group
    UI.enabled = group:Switch("Enable", true, ICON_ENABLE)
    UI.autoHeal = group:Switch("Auto Heal", true, ICON_MIST_COIL)
    UI.healGear = UI.autoHeal:Gear("Settings", ICON_GEAR, true)
    UI.healStartHpPct = UI.healGear:Slider("Heal Below HP %", 1, 100, 45)
    UI.healStartHpPct:Icon(ICON_HEARTBEAT)
    UI.healStopHpPct = UI.healGear:Slider("Stop Above HP %", 1, 100, 70)
    UI.healStopHpPct:Icon(ICON_HEART)
    UI.healPriority = UI.healGear:Combo("Heal Priority", PriorityItems(), PRIORITY_HP_PCT)
    UI.healPriority:Icon(ICON_SORT)
    UI.minSelfHpPct = UI.healGear:Slider("Min Self HP %", 0, 100, 25)
    UI.minSelfHpPct:Icon(ICON_SHIELD)

    UI.showPanel = group:Switch("Show Panel", true, ICON_PANEL)

    UI.enabled:SetCallback(OnEnabledChanged, true)
    UI.autoHeal:SetCallback(SyncOptionDisabled, true)

    ApplyLocalization(true)
    SetupLanguageCallback()

    Persistent.logger:info("loaded")
end

function Script.OnThemeUpdate()
    SyncColors()
end

function Script.OnUpdate()
    if not Engine.IsInGame() then
        return
    end
    if not UI.enabled or UI.enabled:Get() ~= true then
        return
    end
    if Input.IsInputCaptured() then
        return
    end

    local now = GameRules.GetGameTime()
    if now - Runtime.lastUpdateAt < UPDATE_INTERVAL then
        return
    end
    Runtime.lastUpdateAt = now

    local me = Heroes.GetLocal()
    if not me or Entity.IsAlive(me) ~= true then
        return
    end
    UpdateMistCoil(me)
end

function Script.OnDraw()
    if not Engine.IsInGame() then
        return
    end
    if not UI.enabled or UI.enabled:Get() ~= true then
        return
    end

    local me = Heroes.GetLocal()
    if not me or Entity.IsAlive(me) ~= true then
        return
    end
    if NPC.GetUnitName(me) ~= HERO_NAME then
        return
    end
    DrawPanel(me)
end

function Script.OnGameEnd()
    ResetRuntime()
end
--#endregion

return Script
