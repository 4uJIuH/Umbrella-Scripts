-- Anti-Rubick Spell Cover v1: protects selected spells with prioritized covers.
-- Author: ⚔LegaXye禪 (Discord: legaxye)
-- Standalone Umbrella script with saved per-hero selections and priorities.
-- Casts require engine confirmation and preserve channeling.

local VERSION = "1.0.0"

local group = Menu.Create("Scripts", "General", "\u{f0ad} Utility", "Anti-Rubick", "Spell Cover")
local uiEnable = group:Switch("Enable Script", true)
local uiDistance = group:Slider("Max Rubick Distance", 1000, 4000, 2000, "%d")
local uiHiddenRubick = group:Switch("Assume Hidden Rubick In Range", true)
local uiAlwaysCover = group:Switch("Always Cover Against Living Rubick", false)
local uiLinkens = group:Switch("Ignore If Linken's Sphere Ready", true)
local uiDelay = group:Slider("Cast Delay (ms)", 0, 300, 20, "%d ms")
uiEnable:Icon("\u{f021}")
uiEnable:ForceLocalization("Enable")
uiDistance:Icon("\u{f124}")
uiDistance:ForceLocalization("Rubick Range")
uiDistance:ToolTip("Cover when Rubick is within this distance.")
uiHiddenRubick:ForceLocalization("Cover Unseen Rubick")
uiHiddenRubick:ToolTip("Treat unseen Rubick as nearby. May use covers while he is far away.")
uiAlwaysCover:ForceLocalization("Always Cover")
uiAlwaysCover:ToolTip("Requires a living enemy Rubick. Ignores range and unseen settings.")
uiLinkens:Icon("\u{f132}")
uiLinkens:ForceLocalization("Skip Spell Block")
uiLinkens:ToolTip("Skip covers while Linken's Sphere or Mirror Shield is ready.")
uiDelay:Icon("\u{f1da}")
uiDelay:ForceLocalization("Cover Delay")
uiDelay:ToolTip("Wait this long before casting a cover.")

local CONFIG = "AntiRubickCover_v2"
local REFRESH_INTERVAL, RETRY_INTERVAL, RETRY_WINDOW = 0.5, 0.1, 2.0
local MAX_ABILITY_SLOTS = 32
local ZERO = Vector(0, 0, 0)
local ISSUER = Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY
local ORDER = Enum.UnitOrder
local BEHAVIOR = Enum.AbilityBehavior
local FLAG = Enum.TargetFlags
local TYPE = Enum.TargetType
local TEAM = Enum.TargetTeam
local STATE = Enum.ModifierState
local logs = {}
local hero, heroName, matchId, lastTime
local entries, byName, observations = {}, {}, {}
local profiles = {}
local profile, protectedWidget, coverWidget, statusWidget
local widgetProfile
local widgetMaps = { protected = {}, covers = {} }
local updatingWidgets, nextRefresh, fingerprint = false, 0, nil
local phase, action, attempt = "OBSERVING", nil, nil
local lastSpell, nextWatch, manualPauseUntil = nil, 0, 0
local castSerial = 0
local nextAttempt, lastOrderTime = 0, -math.huge
local cachedRubicks, lastRubickScan = {}, -math.huge
local submitting = false
local legacyImported = false
local updateContext, statusText

local EXCLUDED = {
    generic_hidden = "Placeholder",
    attribute_bonus = "Attributes",
    invoker_invoke = "Invoke is not a stealable spell",
    invoker_quas = "Invoker orb control",
    invoker_wex = "Invoker orb control",
    invoker_exort = "Invoker orb control",
    invoker_empty1 = "Placeholder", invoker_empty2 = "Placeholder",
    rubick_spell_steal = "Spell Steal cannot itself be stolen",
    morphling_morph_agi = "Attribute shift control",
    morphling_morph_str = "Attribute shift control",
    ancient_apparition_ice_blast_release = "Release control",
    hoodwink_sharpshooter_release = "Release control",
    primal_beast_onslaught_release = "Release control",
    keeper_of_the_light_illuminate_end = "Channel end control",
    keeper_of_the_light_spirit_form_illuminate_end = "Channel end control",
    crystal_maiden_freezing_field_stop = "Channel stop control",
    phoenix_icarus_dive_stop = "Stop control",
    phoenix_sun_ray_stop = "Stop control",
    pangolier_gyroshell_stop = "Stop control",
    pangolier_rollup_stop = "Stop control",
    naga_siren_song_of_the_siren_cancel = "Cancel control",
    brewmaster_primal_split_cancel = "Cancel control",
    windrunner_focusfire_cancel = "Cancel control",
    dazzle_nothl_projection_end = "Return control",
    kunkka_return = "Return control",
    grimstroke_return = "Return control",
    faceless_void_time_walk_reverse = "Return control",
    dawnbreaker_converge = "Return control",
    muerta_pierce_the_veil_cancel = "Cancel control",
    kez_shodo_sai_parry_cancel = "Cancel control",
}

local ALIASES = {
    sand_king_epicenter = "sandking_epicenter",
    sand_king_sand_storm = "sandking_sand_storm",
    sand_king_burrowstrike = "sandking_burrowstrike",
    dawnbreaker_starbreaker = "dawnbreaker_fire_wreath",
    bounty_hunter_shadow_walk = "bounty_hunter_wind_walk",
    omniknight_repel = "omniknight_martyr",
    ringmaster_wheel_of_wonder = "ringmaster_wheel",
    ringmaster_impalement_arts = "ringmaster_impalement",
    ringmaster_escape_act = "ringmaster_the_box",
    beastmaster_call_of_the_wild_boar = "beastmaster_summon_razorback",
    beastmaster_call_of_the_wild_hawk = "beastmaster_summon_raptor",
}

local COOLDOWN_EVIDENCE = {
    doom_bringer_doom = true,
    doom_bringer_scorched_earth = true,
    doom_bringer_devour = true,
    doom_bringer_infernal_blade = true,
}

local function LogOnce(key, message)
    local now = lastTime or 0
    if logs[key] and now - logs[key] < 10 then return end
    logs[key] = now
    if type(print) == "function" then print("[AntiRubickCover] " .. message) end
end

local function TryRead(module, method, ...)
    local fn = module and module[method]
    if type(fn) ~= "function" then return nil, false end
    local ok, value = pcall(fn, ...)
    if ok then return value, true end
    LogOnce(method, method .. " failed; skipping the unavailable check.")
    return nil, false
end

local function Read(module, method, ...)
    local value = TryRead(module, method, ...)
    return value
end

local function Number(value)
    if type(value) == "number" and value == value and math.abs(value) < math.huge then return value end
end

local function Position(value)
    local kind = type(value)
    if kind ~= "table" and kind ~= "userdata" then return nil end
    return Number(value.x) and Number(value.y) and Number(value.z) and value or nil
end

local function Distance(a, b)
    if not Position(a) or not Position(b) then return nil end
    return Number((a - b):Length2D())
end

local function Has(bits, flag)

    return Number(bits) ~= nil and Number(flag) ~= nil and flag > 0
        and math.floor(bits / flag) % 2 == 1
end

local function Visible(widget, value)
    if widget then widget:Visible(value) end
end

local function SetStatus(text)
    if not statusWidget then statusWidget = group:Label(text) end
    if statusText ~= text then
        if type(statusWidget.ForceLocalization) == "function" then statusWidget:ForceLocalization(text) end
        statusText = text
    end
    Visible(statusWidget, true)
end

local function ResetAction()
    phase, action, attempt = "OBSERVING", nil, nil
    nextAttempt = 0
end

local function ResetSession()
    updateContext = nil
    ResetAction()
    lastSpell, nextWatch, manualPauseUntil = nil, 0, 0
    castSerial = 0
    hero, heroName, profile = nil, nil, nil
    widgetProfile = nil
    entries, byName, observations = {}, {}, {}
    nextRefresh, fingerprint = 0, nil
    lastOrderTime = -math.huge
    cachedRubicks, lastRubickScan = {}, -math.huge
    logs = {}
    Visible(protectedWidget, false)
    Visible(coverWidget, false)
    Visible(statusWidget, false)
end

local function HeroChannel()
    if updateContext and updateContext.channelRead then
        return updateContext.channel, updateContext.channelKnown
    end
    local channel, known = TryRead(NPC, "GetChannellingAbility", hero)
    if updateContext then
        updateContext.channelRead, updateContext.channel, updateContext.channelKnown = true, channel, known
    end
    return channel, known
end

local function Channelling(ab)
    local value = Read(Ability, "IsChannelling", ab)
    if value == true then return true end
    local channel, known = HeroChannel()
    if known then return channel == ab end
    if value == false then return false end
end

local function Snapshot(ab, fresh)
    if not fresh and updateContext and updateContext.snapshots[ab] then return updateContext.snapshots[ab] end
    local snapshot = {
        cooldown = Number(Read(Ability, "GetCooldown", ab)),
        charges = Number(Read(Ability, "GetCurrentCharges", ab)),
        toggle = Read(Ability, "GetToggleState", ab),
        channel = Channelling(ab),
        inPhase = Read(Ability, "IsInAbilityPhase", ab),
        level = Number(Read(Ability, "GetLevel", ab)),
        sinceUse = Number(Read(Ability, "SecondsSinceLastUse", ab)),
    }
    if not fresh and updateContext then updateContext.snapshots[ab] = snapshot end
    return snapshot
end

local function CooldownIncreased(before, after)
    return before and before.cooldown ~= nil and after.cooldown ~= nil and after.cooldown > before.cooldown + 0.05
end

local function Used(before, after, started, now)
    if not before or before.level == nil or before.level ~= after.level then return false end
    if before.channel == false and after.channel == true then return true end

    if before.toggle == false and after.toggle == true then return true end
    if before.charges ~= nil and after.charges ~= nil and after.charges < before.charges then return true end
    if CooldownIncreased(before, after) then

        local age = started and now and math.max(0, now - started) + 0.05 or 0.25
        return after.sinceUse ~= nil and after.sinceUse >= 0 and after.sinceUse <= age
    end
    return false
end

local function Special(ab, key)

    local value = Read(Ability, "GetSpecialValueFor", ab, key)
    if value == nil then value = Read(Ability, "GetLevelSpecialValueFor", ab, key) end
    return Number(value) or 0
end

local function IsConfirmable(ab, bits, name)
    if Has(bits, BEHAVIOR.DOTA_ABILITY_BEHAVIOR_CHANNELLED)
        or Has(bits, BEHAVIOR.DOTA_ABILITY_BEHAVIOR_TOGGLE)
        or (Number(Read(Ability, "GetCooldownLength", ab)) or 0) > 0
        or (Number(Read(Ability, "GetCurrentCharges", ab)) or 0) > 0 then return true end

    if Special(ab, "AbilityCooldown") > 0 then return true end
    if not COOLDOWN_EVIDENCE[name] then return false end
    if name == "doom_bringer_devour" then

        return Read(NPC, "HasShard", hero) == false
    end
    return true
end

local function DescribeAbility(ab, index)
    local name = Read(Ability, "GetName", ab)
    if not name or name == "" then return nil end
    local bits = Read(Ability, "GetBehavior", ab, false)
    local reason = EXCLUDED[name]
    if name:match("^special_bonus_") or Read(Ability, "IsAttributes", ab) then reason = "Talent or attributes" end
    if Read(Ability, "IsPassive", ab) or Has(bits, BEHAVIOR.DOTA_ABILITY_BEHAVIOR_PASSIVE) then reason = "Passive" end
    local castableType = Has(bits, BEHAVIOR.DOTA_ABILITY_BEHAVIOR_NO_TARGET)
        or Has(bits, BEHAVIOR.DOTA_ABILITY_BEHAVIOR_UNIT_TARGET)
        or Has(bits, BEHAVIOR.DOTA_ABILITY_BEHAVIOR_POINT)
        or Has(bits, BEHAVIOR.DOTA_ABILITY_BEHAVIOR_TOGGLE)
        or Has(bits, BEHAVIOR.DOTA_ABILITY_BEHAVIOR_OPTIONAL_UNIT_TARGET)
        or Has(bits, BEHAVIOR.DOTA_ABILITY_BEHAVIOR_OPTIONAL_POINT)
        or Has(bits, BEHAVIOR.DOTA_ABILITY_BEHAVIOR_OPTIONAL_NO_TARGET)
    if not castableType then reason = reason or "No supported casting behavior" end
    local stealable = Read(Entity, "GetField", ab, "m_bStealable", false)
    if stealable == 0 then stealable = false elseif stealable == 1 then stealable = true end
    if stealable == false then reason = reason or "Engine marks this ability as not stealable" end
    local confirmable = IsConfirmable(ab, bits, name)
    local verified = stealable == true and confirmable and not reason
    local label = Read(GameLocalizer, "FindAbility", name)
    if not label or label == "" then label = name end
    return {
        ability = ab, index = index, name = name, label = label, bits = bits,
        ultimate = Read(Ability, "IsUltimate", ab) == true,
        hidden = Read(Ability, "IsHidden", ab) == true,
        activated = Read(Ability, "IsActivated", ab) ~= false,
        reason = reason,
        verified = verified,
        verification = reason or (stealable ~= true and "Spell Steal validation unavailable")
            or (not confirmable and "No reliable cast confirmation signal") or "Engine eligibility checked; demo validation pending",
    }
end

local function LoadSelection(key)
    local selection = { order = {}, enabled = {}, known = {} }
    local raw = Read(Config, "ReadString", CONFIG, key, "") or ""
    for enabled, name in raw:gmatch("([01]):([%w_]+)") do
        if not selection.known[name] then
            selection.order[#selection.order + 1] = name
            selection.known[name] = true
            selection.enabled[name] = enabled == "1"
        end
    end
    selection.serialized = raw
    return selection
end

local function Serialize(selection)
    local values = {}
    for _, name in ipairs(selection.order) do
        values[#values + 1] = (selection.enabled[name] and "1:" or "0:") .. name
    end
    return table.concat(values, ",")
end

local function SaveProfile()
    if not profile or not heroName then return end
    for _, kind in ipairs({ "protected", "covers" }) do
        local selection = profile[kind]
        local raw = Serialize(selection)
        if raw ~= selection.serialized then
            if type(Config and Config.WriteString) == "function" then
                local ok = pcall(Config.WriteString, CONFIG, heroName .. "." .. kind, raw)
                if ok then selection.serialized = raw
                else LogOnce("config", "Unable to save per-hero selections.") end
            end
        end
    end
end

local function CaptureWidget(kind, widget)

    if not widget or not profile or widgetProfile ~= profile or updatingWidgets then return end
    local selection, map = profile[kind], widgetMaps[kind]
    local visibleOrder, visibleNames = {}, {}
    for _, id in ipairs(widget:List()) do
        local name = map[id]
        if name then
            visibleOrder[#visibleOrder + 1] = name
            visibleNames[name] = true
            local enabled = widget:Get(id) == true
            if kind == "protected" and selection.enabled[name] ~= enabled then

                observations[name] = nil
                if not enabled and action and action.entry.name == name then ResetAction() end
                if not enabled and lastSpell and lastSpell.entry.name == name then lastSpell.needsCover = false end
            end
            selection.enabled[name] = enabled
        end
    end

    local cursor, newOrder = 1, {}
    for _, name in ipairs(selection.order) do
        if visibleNames[name] then
            newOrder[#newOrder + 1] = visibleOrder[cursor]
            cursor = cursor + 1
        else newOrder[#newOrder + 1] = name end
    end
    while cursor <= #visibleOrder do
        newOrder[#newOrder + 1] = visibleOrder[cursor]
        cursor = cursor + 1
    end
    selection.order = newOrder
end

local function CaptureSelections()
    CaptureWidget("protected", protectedWidget)
    CaptureWidget("covers", coverWidget)
    SaveProfile()
end

local function WidgetItems(kind)
    local selection = profile[kind]
    local items, map, tips, usedLabels = {}, {}, {}, {}
    for _, name in ipairs(selection.order) do
        local entry = byName[name]
        if entry and not entry.reason and not entry.hidden then
            local label = entry.label
            if usedLabels[label] then label = label .. " (" .. name .. ")" end
            usedLabels[label] = true
            map[label] = name
            tips[label] = name .. "\n" .. entry.verification
            local base = Read(Ability, "GetBaseName", entry.ability)
            if not base or base == "" then base = name end
            items[#items + 1] = { label, "panorama/images/spellicons/" .. base .. "_png.vtex_c", selection.enabled[name] == true }
        end
    end
    widgetMaps[kind] = map
    return items, tips
end

local function ImportLegacy()
    if legacyImported then return end
    legacyImported = true
    if #profile.covers.order == 0 then return end
    local legacy = {}
    for _, entry in ipairs(entries) do
        if not entry.reason then
            legacy[#legacy + 1] = { entry.name, "", false }
            for old, current in pairs(ALIASES) do
                if current == entry.name then legacy[#legacy + 1] = { old, "", false } end
            end
        end
    end

    coverWidget = group:MultiSelect("Cover Spells (Drag to Prioritize)", legacy, true)
    if not profile.initialized then
        local imported, seen = {}, {}
        for _, id in ipairs(coverWidget:List()) do
            local name = ALIASES[id] or id
            if byName[name] and not byName[name].reason and not seen[name] then
                imported[#imported + 1] = name
                seen[name] = true
                profile.covers.enabled[name] = coverWidget:Get(id) == true
            end
        end
        for _, name in ipairs(profile.covers.order) do
            if not seen[name] then imported[#imported + 1] = name end
        end
        profile.covers.order = imported
    end
end

local function UpdateWidgets()
    updatingWidgets = true
    ImportLegacy()
    local protectedItems, protectedTips = WidgetItems("protected")
    local coverItems, coverTips = WidgetItems("covers")
    if not protectedWidget then
        protectedWidget = group:MultiSelect("Spells to Protect", protectedItems, true)
        protectedWidget:Icon("\u{f132}")
        protectedWidget:SetCallback(function()
            if updatingWidgets then return end
            CaptureSelections()
        end)
    else protectedWidget:Update(protectedItems, true, false) end
    if not coverWidget then coverWidget = group:MultiSelect("Cover Spells (Drag to Prioritize)", coverItems, true)
    else coverWidget:Update(coverItems, true, false) end
    protectedWidget:UpdateToolTips(protectedTips)
    coverWidget:UpdateToolTips(coverTips)

    protectedWidget:ForceLocalization("Protect Spells")
    coverWidget:ForceLocalization("Cover Spells")
    protectedWidget:ToolTip("Choose spells to protect. Drag to set priority.")
    coverWidget:ToolTip("Choose spells to cast afterward. Drag to set cast order.")
    protectedWidget:DragAllowed(true)
    coverWidget:DragAllowed(true)
    coverWidget:Icon("\u{f0c9}")
    widgetProfile = profile
    updatingWidgets = false
    Visible(protectedWidget, true)
    Visible(coverWidget, true)
    local usable, unverified = 0, 0
    for _, entry in ipairs(entries) do
        if not entry.reason and not entry.hidden then
            if entry.verified then usable = usable + 1 else unverified = unverified + 1 end
        end
    end
    local displayHero = Read(GameLocalizer, "FindNPC", heroName) or heroName
    if displayHero == "" then displayHero = heroName end
    if #protectedItems == 0 then SetStatus(displayHero .. ": No usable spells.")
    elseif usable == 0 then SetStatus(displayHero .. ": Cannot verify spells.")
    else SetStatus(displayHero .. ": " .. usable .. " supported, " .. unverified .. " unavailable.") end
    SaveProfile()
end

local coverCallbackAttached = false
local function RefreshAbilities(now)
    CaptureSelections()
    local nextEntries, nextByName, parts = {}, {}, {}
    for index = 0, MAX_ABILITY_SLOTS - 1 do
        local ab = Read(NPC, "GetAbilityByIndex", hero, index)
        if ab then
            local entry = DescribeAbility(ab, index)
            if entry and not nextByName[entry.name] then
                nextEntries[#nextEntries + 1] = entry
                nextByName[entry.name] = entry
                parts[#parts + 1] = table.concat({ entry.name, tostring(ab), tostring(entry.bits), entry.label,
                    tostring(entry.hidden), tostring(entry.activated), tostring(entry.verified), entry.verification }, "|")
            end
        end
    end
    entries, byName = nextEntries, nextByName
    local nextFingerprint = table.concat(parts, ";")
    if fingerprint ~= nextFingerprint then
        local firstDiscovery = not profile.initialized
        for _, entry in ipairs(entries) do
            if not entry.reason then
                for _, kind in ipairs({ "protected", "covers" }) do
                    local selection = profile[kind]
                    if not selection.known[entry.name] then
                        selection.known[entry.name] = true
                        selection.order[#selection.order + 1] = entry.name
                        selection.enabled[entry.name] = kind == "protected" and firstDiscovery and entry.ultimate or false
                    end
                end
            end
        end
        fingerprint = nextFingerprint
        UpdateWidgets()
        if #entries > 0 then profile.initialized = true end
        if coverWidget and not coverCallbackAttached then
            coverWidget:SetCallback(function() if not updatingWidgets then CaptureSelections() end end)
            coverCallbackAttached = true
        end
    end
    nextRefresh = now + REFRESH_INTERVAL
end

local function HasState(unit, name)
    local state = STATE and STATE[name]
    return state and Read(NPC, "HasState", unit, state) == true
end

local function Incapacitated()
    return Read(NPC, "IsSilenced", hero) == true or Read(NPC, "IsStunned", hero) == true
        or HasState(hero, "MODIFIER_STATE_HEXED") or HasState(hero, "MODIFIER_STATE_COMMAND_RESTRICTED")
        or HasState(hero, "MODIFIER_STATE_OUT_OF_GAME")
end

local function HasModifier(name)
    return Read(NPC, "HasModifier", hero, name) == true
end

local function ItemProtected(itemName, nativeMethod, buff, cooldown)
    local native = Read(NPC, nativeMethod, hero)
    if type(native) == "boolean" then return native end
    if HasState(hero, "MODIFIER_STATE_MUTED") then return false end
    if HasModifier(cooldown) then return false end

    local modifiers = Read(NPC, "GetModifiers", hero)
    if not modifiers and type(NPC.GetModifierByIndex) == "function" then
        modifiers = {}
        for index = 1, 256 do
            local modifier = Read(NPC, "GetModifierByIndex", hero, index)
            if not modifier then break end
            modifiers[#modifiers + 1] = modifier
        end
    end
    for _, modifier in ipairs(modifiers or {}) do
        if Read(Modifier, "GetName", modifier) == cooldown then return false end
    end
    if HasModifier(buff) then return true end
    for slot = 0, 16 do

        if slot <= 5 or slot == 16 then
            local item = Read(NPC, "GetItemByIndex", hero, slot)
            if item and Read(Ability, "GetName", item) == itemName and (Number(Read(Ability, "GetCooldown", item)) or 1) <= 0 then
                return true
            end
        end
    end
    return false
end

local function IsProtected()
    return ItemProtected("item_sphere", "IsLinkensProtected", "modifier_item_sphere_target", "modifier_item_sphere_cooldown")
        or ItemProtected("item_mirror_shield", "IsMirrorProtected", "modifier_item_mirror_shield", "modifier_item_mirror_shield_cooldown")
end

local function RubickThreat(now)
    local heroTeam = Number(Read(Entity, "GetTeamNum", hero))
    if not heroTeam then return false end
    if now - lastRubickScan >= 2 then
        cachedRubicks = {}
        for _, unit in ipairs(Read(Heroes, "GetAll") or {}) do
            local team = Number(Read(Entity, "GetTeamNum", unit))
            if Read(NPC, "GetUnitName", unit) == "npc_dota_hero_rubick"
                and team ~= nil and team ~= heroTeam
                and Read(NPC, "IsIllusion", unit) ~= true then cachedRubicks[#cachedRubicks + 1] = unit end
        end
        lastRubickScan = now
    end
    for _, unit in ipairs(cachedRubicks) do
        local team = Number(Read(Entity, "GetTeamNum", unit))
        if Read(Entity, "IsEntity", unit) ~= false and Read(Entity, "IsAlive", unit) == true
            and Read(NPC, "GetUnitName", unit) == "npc_dota_hero_rubick"
            and team ~= nil and team ~= heroTeam
            and Read(NPC, "IsIllusion", unit) ~= true then

            if uiAlwaysCover:Get() then return true end
            local dormant = Read(Entity, "IsDormant", unit)
            local visible = Read(NPC, "IsVisible", unit)

            local hidden = dormant == true or visible == false
                or (dormant ~= false and visible ~= true)
            if hidden then
                if uiHiddenRubick:Get() then return true end
            else
                local position = Read(Entity, "GetAbsOrigin", unit)
                local origin = Read(Entity, "GetAbsOrigin", hero)
                local distance = Distance(position, origin)
                if distance and distance <= uiDistance:Get() then return true end
            end
        end
    end
    return false
end

local function EffectiveRange(ab)
    local base = Number(Read(Ability, "GetCastRange", ab)) or 0
    if base <= 0 then
        for _, key in ipairs({ "range", "cast_range", "spear_range", "fissure_range", "distance" }) do
            base = math.max(base, Special(ab, key))
        end
    end

    return math.max(0, base + (Number(Read(NPC, "GetCastRangeBonus", hero)) or 0))
end

local function TargetRestrictions(entry, targetType)
    local ab = entry.ability
    local team = Number(Read(Ability, "GetTargetTeam", ab, false))
    local types = targetType or Number(Read(Ability, "GetTargetType", ab, false))
    local flags = Number(Read(Ability, "GetTargetFlags", ab))
    if team == nil or types == nil or flags == nil then return nil end
    local remainingFlags = flags
    for _, value in pairs(FLAG) do
        if Has(remainingFlags, value) then remainingFlags = remainingFlags - value end
    end
    if remainingFlags ~= 0 then
        LogOnce("flags:" .. entry.name, "Unknown target restrictions for " .. entry.name .. "; skipping unit targets.")
        return nil
    end
    return { team = team, types = types, flags = flags,
        immunity = Read(Ability, "GetImmunityType", ab, false),
        creepLevel = entry.name == "doom_bringer_devour" and Special(ab, "creep_level") or nil,
        ancient = entry.name == "doom_bringer_devour" and Special(ab, "can_target_ancient") or nil }
end

local function ValidateTarget(entry, unit, range, restrictions)
    if not unit or Read(Entity, "IsEntity", unit) == false or Read(Entity, "IsAlive", unit) ~= true
        or Read(Entity, "IsDormant", unit) ~= false then return false end
    if HasState(unit, "MODIFIER_STATE_OUT_OF_GAME") then return false end
    local rules = restrictions or TargetRestrictions(entry)
    if not rules then return false end
    local team, types, flags = rules.team, rules.types, rules.flags
    local unitTeam, heroTeam = Number(Read(Entity, "GetTeamNum", unit)), Number(Read(Entity, "GetTeamNum", hero))
    if not unitTeam or not heroTeam then return false end
    local enemy = unitTeam ~= heroTeam
    if entry.name == "doom_bringer_devour" then
        if not enemy or Read(NPC, "IsCreep", unit) ~= true or Read(NPC, "IsHero", unit) == true then return false end
        if Read(NPC, "IsRoshan", unit) == true or Read(NPC, "IsCreepHero", unit) == true then return false end
        local level, limit = Number(Read(NPC, "GetCurrentLevel", unit)), rules.creepLevel
        if not level or limit <= 0 or level > limit then return false end
        if Read(NPC, "IsAncient", unit) == true and rules.ancient <= 0 then return false end
    else
        if enemy and not Has(team, TEAM.DOTA_UNIT_TARGET_TEAM_ENEMY) then return false end
        if not enemy and not Has(team, TEAM.DOTA_UNIT_TARGET_TEAM_FRIENDLY) then return false end
        if Has(team, TEAM.DOTA_UNIT_TARGET_TEAM_CUSTOM) or Has(types, TYPE.DOTA_UNIT_TARGET_CUSTOM) then return false end
        local isHero = Read(NPC, "IsHero", unit) == true
        local isStructure = Read(NPC, "IsStructure", unit) == true
        if unit == hero and Has(types, TYPE.DOTA_UNIT_TARGET_SELF) then

        elseif isHero then
            if not Has(types, TYPE.DOTA_UNIT_TARGET_HERO) then return false end
        elseif isStructure then
            if not Has(types, TYPE.DOTA_UNIT_TARGET_BUILDING) then return false end
        elseif Read(NPC, "IsCourier", unit) == true then
            if not Has(types, TYPE.DOTA_UNIT_TARGET_COURIER) then return false end
        elseif Read(NPC, "IsCreep", unit) == true then
            if not Has(types, TYPE.DOTA_UNIT_TARGET_CREEP) then return false end
        else

            if not Has(types, TYPE.DOTA_UNIT_TARGET_OTHER) then return false end
        end
    end
    local invulnerable = Read(NPC, "IsInvulnerable", unit) == true or HasState(unit, "MODIFIER_STATE_INVULNERABLE")
    if invulnerable and not Has(flags, FLAG.DOTA_UNIT_TARGET_FLAG_INVULNERABLE) then return false end
    if Has(flags, FLAG.DOTA_UNIT_TARGET_FLAG_NOT_ILLUSIONS) and Read(NPC, "IsIllusion", unit) then return false end
    if Has(flags, FLAG.DOTA_UNIT_TARGET_FLAG_NOT_ANCIENTS) and Read(NPC, "IsAncient", unit) then return false end
    for _, check in ipairs({
        { FLAG.DOTA_UNIT_TARGET_FLAG_NOT_SUMMONED, "IsSummoned" },
        { FLAG.DOTA_UNIT_TARGET_FLAG_NOT_CREEP_HERO, "IsCreepHero" },
        { FLAG.DOTA_UNIT_TARGET_FLAG_NOT_DOMINATED, "IsDominated" },
    }) do
        if Has(flags, check[1]) then

            if Read(NPC, check[2], unit) ~= false then return false end
        end
    end
    if Has(flags, FLAG.DOTA_UNIT_TARGET_FLAG_RANGED_ONLY) and Read(NPC, "IsRanged", unit) ~= true then return false end
    if Has(flags, FLAG.DOTA_UNIT_TARGET_FLAG_MELEE_ONLY) and Read(NPC, "IsRanged", unit) ~= false then return false end
    if Has(flags, FLAG.DOTA_UNIT_TARGET_FLAG_NOT_ATTACK_IMMUNE) and HasState(unit, "MODIFIER_STATE_ATTACK_IMMUNE") then return false end
    if Has(flags, FLAG.DOTA_UNIT_TARGET_FLAG_MANA_ONLY) and (Number(Read(NPC, "GetMaxMana", unit)) or 0) <= 0 then return false end
    if Has(flags, FLAG.DOTA_UNIT_TARGET_FLAG_NOT_NIGHTMARED) and Read(NPC, "HasModifier", unit, "modifier_bane_nightmare") == true then return false end

    if Has(flags, FLAG.DOTA_UNIT_TARGET_FLAG_CHECK_DISABLE_HELP)
        or Has(flags, FLAG.DOTA_UNIT_TARGET_FLAG_RESPECT_OBSTRUCTIONS)
        or Has(flags, FLAG.DOTA_UNIT_TARGET_FLAG_PLAYER_CONTROLLED) then return false end
    if enemy and Read(NPC, "IsVisible", unit) ~= true then return false end
    if Has(flags, FLAG.DOTA_UNIT_TARGET_FLAG_FOW_VISIBLE) and Read(NPC, "IsVisible", unit) ~= true then return false end
    if Has(flags, FLAG.DOTA_UNIT_TARGET_FLAG_NO_INVIS) and HasState(unit, "MODIFIER_STATE_INVISIBLE") then return false end
    if enemy and HasState(unit, "MODIFIER_STATE_INVISIBLE") then return false end
    local immune = Read(NPC, "IsMagicImmune", unit) == true or HasState(unit, "MODIFIER_STATE_MAGIC_IMMUNE")
        or HasState(unit, "MODIFIER_STATE_DEBUFF_IMMUNE")
    if immune then
        local immunity = rules.immunity
        if enemy and not Has(flags, FLAG.DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES)
            and immunity ~= Enum.ImmunityTypes.SPELL_IMMUNITY_ENEMIES_YES then return false end
        if not enemy and Has(flags, FLAG.DOTA_UNIT_TARGET_FLAG_NOT_MAGIC_IMMUNE_ALLIES) then return false end
    end
    local distance = Distance(Read(Entity, "GetAbsOrigin", unit), Read(Entity, "GetAbsOrigin", hero))
    return distance ~= nil and distance <= range
end

local function FindTarget(entry, range, restrictions)
    local rules = restrictions == nil and TargetRestrictions(entry) or restrictions
    if not rules then return nil end
    if ValidateTarget(entry, hero, range, rules) then return hero end
    local bestEnemy, bestAlly, enemyDistance, allyDistance = nil, nil, math.huge, math.huge
    local origin = Position(Read(Entity, "GetAbsOrigin", hero))
    local heroTeam = Number(Read(Entity, "GetTeamNum", hero))
    if not origin or not heroTeam then return nil end
    for _, unit in ipairs(Read(NPCs, "InRadius", origin, range, heroTeam, Enum.TeamType.TEAM_BOTH) or {}) do
        if ValidateTarget(entry, unit, range, rules) then
            local distance = Distance(Read(Entity, "GetAbsOrigin", unit), origin)
            local unitTeam = Number(Read(Entity, "GetTeamNum", unit))
            if distance and unitTeam and unitTeam ~= heroTeam then
                if distance < enemyDistance then bestEnemy, enemyDistance = unit, distance end
            elseif distance and unitTeam == heroTeam and distance < allyDistance then bestAlly, allyDistance = unit, distance end
        end
    end
    return bestEnemy or bestAlly
end

local function CursorPosition(range)
    local origin = Position(Read(Entity, "GetAbsOrigin", hero))
    if not origin then return nil end
    local rawCursor = Read(Input, "GetWorldCursorPos")
    local cursor = rawCursor == nil and origin or Position(rawCursor)
    if not cursor then return nil end
    local delta = cursor - origin
    local distance = Number(delta:Length2D())
    if not distance then return nil end
    if distance <= range or distance == 0 then return cursor end

    return Vector(origin.x + delta.x * range / distance, origin.y + delta.y * range / distance, cursor.z)
end

local function FindTree(range)
    local cursor = CursorPosition(range)
    local origin = Position(Read(Entity, "GetAbsOrigin", hero))
    if not cursor or not origin then return nil end
    local nearest, distance = nil, math.huge
    local trees = Read(Entity, "GetTreesInRadius", hero, range, true) or {}
    local candidates = {}
    for _, tree in ipairs(trees) do candidates[#candidates + 1] = tree end
    for _, tree in ipairs(Read(Entity, "GetTempTreesInRadius", hero, range, true) or {}) do candidates[#candidates + 1] = tree end
    for _, tree in ipairs(candidates) do
        local position = Read(Entity, "GetAbsOrigin", tree)
        local inRange = Distance(position, origin)
        if inRange and Read(Entity, "IsEntity", tree) ~= false and inRange <= range then
            local current = Distance(position, cursor)
            if current and current < distance then nearest, distance = tree, current end
        end
    end
    return nearest
end

local function BuildOrder(entry)
    local bits, ab = entry.bits, entry.ability
    if Has(bits, BEHAVIOR.DOTA_ABILITY_BEHAVIOR_TOGGLE) then
        if Read(Ability, "GetToggleState", ab) ~= false then return nil end
        return { order = ORDER.DOTA_UNIT_ORDER_CAST_TOGGLE, position = ZERO }
    end
    if Has(bits, BEHAVIOR.DOTA_ABILITY_BEHAVIOR_NO_TARGET)
        or Has(bits, BEHAVIOR.DOTA_ABILITY_BEHAVIOR_OPTIONAL_NO_TARGET) then
        return { order = ORDER.DOTA_UNIT_ORDER_CAST_NO_TARGET, position = ZERO }
    end
    local range = EffectiveRange(ab)
    local types = Number(Read(Ability, "GetTargetType", ab, false)) or 0

    local rules = TargetRestrictions(entry, types) or false
    local result
    if Has(bits, BEHAVIOR.DOTA_ABILITY_BEHAVIOR_UNIT_TARGET)
        or Has(bits, BEHAVIOR.DOTA_ABILITY_BEHAVIOR_OPTIONAL_UNIT_TARGET) then
        local target = FindTarget(entry, range, rules)
        if target then result = { order = ORDER.DOTA_UNIT_ORDER_CAST_TARGET, target = target, position = ZERO }
        elseif Has(types, TYPE.DOTA_UNIT_TARGET_TREE) then
            local tree = FindTree(range)
            if tree then result = { order = ORDER.DOTA_UNIT_ORDER_CAST_TARGET_TREE, target = tree, position = ZERO } end
        end
    end
    if not result and (Has(bits, BEHAVIOR.DOTA_ABILITY_BEHAVIOR_POINT) or Has(bits, BEHAVIOR.DOTA_ABILITY_BEHAVIOR_OPTIONAL_POINT)) then
        if range <= 0 then return nil end
        local target = FindTarget(entry, range, rules)
        result = { order = ORDER.DOTA_UNIT_ORDER_CAST_POSITION,
            position = target and Position(Read(Entity, "GetAbsOrigin", target)) or CursorPosition(range) }
    end
    if not result then return nil end
    if not Position(result.position) then return nil end
    if Has(bits, BEHAVIOR.DOTA_ABILITY_BEHAVIOR_VECTOR_TARGETING) then
        if not ORDER.DOTA_UNIT_ORDER_VECTOR_TARGET_POSITION then return nil end
        local origin = result.target and Position(Read(Entity, "GetAbsOrigin", result.target)) or result.position
        local rawCursor = Read(Input, "GetWorldCursorPos")
        local cursor = rawCursor == nil and origin or Position(rawCursor)
        if not origin or not cursor then return nil end
        local delta = cursor - origin
        local length = Number(delta:Length2D())
        if not length then return nil end
        if length < 1 then
            local forward = Position(Read(Entity, "GetForwardPosition", hero, 100))
            local heroOrigin = Position(Read(Entity, "GetAbsOrigin", hero))
            if not forward or not heroOrigin then return nil end
            delta = forward - heroOrigin
            length = Number(delta:Length2D())
        end
        if not length or length < 1 then return nil end
        result.vector = Vector(origin.x + delta.x / length * 100, origin.y + delta.y / length * 100, origin.z)
        if not Position(result.vector) then return nil end
    end
    return result
end

local function Ready(entry, duringChannel)
    local ab = entry.ability
    if not entry.verified then return false, entry.verification, "unverified" end
    if entry.hidden then return false, "hidden", "hidden" end
    if not entry.activated then return false, "not activated", "inactive" end
    local current = Snapshot(ab)
    local level = current.level
    if (level or 0) <= 0 then return false, "not learned (level=" .. tostring(level) .. ")", "level" end
    if current.inPhase ~= false then return false, "casting phase active or unavailable", "phase" end
    if current.channel ~= false then return false, "cover channelling or channel unavailable", "channel" end
    if duringChannel and (not Has(entry.bits, BEHAVIOR.DOTA_ABILITY_BEHAVIOR_IGNORE_CHANNEL)
        or not Has(entry.bits, BEHAVIOR.DOTA_ABILITY_BEHAVIOR_IMMEDIATE)) then
        return false, "waiting for protected channel to finish", "protected-channel"
    end
    if HasState(hero, "MODIFIER_STATE_ROOTED") and Has(entry.bits, BEHAVIOR.DOTA_ABILITY_BEHAVIOR_ROOT_DISABLES) then
        return false, "root prevents casting", "rooted"
    end
    local mana = Number(Read(NPC, "GetMana", hero)) or 0
    local function resources()
        return "mana=" .. tostring(mana) .. ", manaCost=" .. tostring(Read(Ability, "GetManaCost", ab))
            .. ", cooldown=" .. tostring(Read(Ability, "GetCooldown", ab))
            .. ", charges=" .. tostring(Read(Ability, "GetCurrentCharges", ab))
    end
    local castable = Read(Ability, "IsCastable", ab, mana)
    if castable ~= true then
        return false, "IsCastable=" .. tostring(castable) .. " (" .. resources() .. ")", "castable"
    end
    local executable = Read(Ability, "CanBeExecuted", ab)
    local results = Enum.AbilityCastResult
    local ready = results and results.READY or -1
    if executable ~= nil and executable ~= ready then
        local label = "unknown"
        for name, value in pairs(results or {}) do if value == executable then label = name; break end end

        LogOnce("execute-conflict:" .. entry.name .. ":" .. tostring(executable), entry.name
            .. ": IsCastable=true but CanBeExecuted=" .. label .. "(" .. tostring(executable)
            .. ") (" .. resources() .. "); awaiting actual cast confirmation.")
    end

    return true
end

local function CancelVector(entry)
    local player = Read(Players, "GetLocal")
    if not player or not ORDER.DOTA_UNIT_ORDER_VECTOR_TARGET_CANCELED then return false end
    submitting = true
    local ok = pcall(Player.PrepareUnitOrders, player, ORDER.DOTA_UNIT_ORDER_VECTOR_TARGET_CANCELED,
        nil, ZERO, entry.ability, ISSUER, hero, false, false, false, true, "AntiRubickCover_v2", false)
    submitting = false
    if not ok then LogOnce("vector-cancel:" .. entry.name, "Vector cancellation failed for " .. entry.name) end
    return ok
end

local function Submit(entry, order, now)
    local player = Read(Players, "GetLocal")
    if not player then return false end
    local before = Snapshot(entry.ability, true)
    submitting = true
    local function send(kind, target, position)
        return pcall(Player.PrepareUnitOrders, player, kind, target, position, entry.ability, ISSUER,
            hero, false, false, false, true, "AntiRubickCover_v2", false)
    end
    local ok = true

    if order.vector then ok = send(ORDER.DOTA_UNIT_ORDER_VECTOR_TARGET_POSITION, nil, order.vector) end
    if ok then ok = send(order.order, order.target, order.position) end
    if not ok and order.vector and ORDER.DOTA_UNIT_ORDER_VECTOR_TARGET_CANCELED then
        send(ORDER.DOTA_UNIT_ORDER_VECTOR_TARGET_CANCELED, nil, ZERO)
    end
    submitting = false
    if not ok then LogOnce(entry.name, "Order submission failed for " .. entry.name); return false end
    attempt = {
        entry = entry, before = before, started = now,
        timeout = now + (Number(Read(Ability, "GetCastPoint", entry.ability, true)) or 0) + 0.25,
        sawPhase = false, vector = order.vector ~= nil,
    }
    phase = "WAIT_CONFIRM"
    lastOrderTime = now
    return true
end

local function BeginAction(entry, now, channel)
    action = { entry = entry, confirmedAt = now, expires = channel and math.huge or now + RETRY_WINDOW,
        tried = {}, channel = channel, channelCovered = false }
    attempt = nil
    phase = channel and "CHANNELING" or "PENDING"
    nextAttempt = now + uiDelay:Get() / 1000
end

local function RememberSpell(entry, now, needsCover)

    lastSpell = { entry = entry, confirmedAt = now, needsCover = needsCover, wasThreat = false }
    nextWatch, manualPauseUntil = now, 0
end

local function ObserveSpells(now)
    local chosen, chosenChannel, other
    local protectedSerial, otherSerial = -1, -1
    for _, name in ipairs(profile.protected.order) do
        local entry = byName[name]
        if entry and entry.verified and not entry.hidden then
            local current = Snapshot(entry.ability)
            local previous = observations[entry.name]
            local selfCast = attempt and attempt.entry.ability == entry.ability
            if previous and previous.ability == entry.ability and not selfCast then
                local confirmed = Used(previous.snapshot, current, previous.intentAt or previous.phaseAt, now)
                local intentMatches = previous.intent and (previous.intent > now
                    or (current.sinceUse and now - current.sinceUse <= previous.intent))
                if CooldownIncreased(previous.snapshot, current)
                    and not current.channel and current.charges == previous.snapshot.charges
                    and current.toggle == previous.snapshot.toggle then

                    confirmed = confirmed and (previous.sawPhase
                        or intentMatches)
                end

                if not confirmed and CooldownIncreased(previous.snapshot, current)
                    and current.level ~= nil and current.level == previous.snapshot.level and intentMatches
                    and previous.sawPhase then confirmed = true end
                if confirmed then
                    if profile.protected.enabled[name] then
                        if not chosen then chosen, chosenChannel = entry, current.channel end
                        protectedSerial = math.max(protectedSerial, previous.intentSerial or 0)
                    elseif (previous.intentSerial or 0) >= otherSerial then
                        other, otherSerial = entry, previous.intentSerial or 0
                    end
                end
            end
            local record = previous or {}
            if record.ability ~= entry.ability then record.phaseAt = nil end
            if record.ability ~= entry.ability or not record.intent or record.intent <= now then
                record.intent, record.intentAt, record.intentSerial = nil, nil, nil
            end
            record.phaseAt = current.inPhase == true and (record.phaseAt or now) or nil
            record.ability, record.snapshot, record.sawPhase = entry.ability, current, current.inPhase == true
            observations[entry.name] = record
        else observations[name] = nil end
    end

    if chosen and otherSerial <= protectedSerial then
        RememberSpell(chosen, now, true)
        BeginAction(chosen, now, chosenChannel)
    elseif other then
        RememberSpell(other, now, false)
        ResetAction()
    end
end

local function HasSelectedCover(originName)
    for _, name in ipairs(profile.covers.order) do
        local entry = byName[name]
        if entry and entry.verified and profile.covers.enabled[name] and name ~= originName then return true end
    end
    return false
end

local function SourceChannel(entry)

    local current, known = HeroChannel()
    if not known then return nil end
    if not current then return false end
    local name = Read(Ability, "GetName", current)
    if type(name) ~= "string" then return nil end
    return name == entry.name
end

local function WatchLastSpell(now)
    if action or not lastSpell or not lastSpell.needsCover or now < nextWatch or now < manualPauseUntil then return end
    nextWatch = now + RETRY_INTERVAL
    local entry = lastSpell.entry
    if not profile.protected.enabled[entry.name] then
        lastSpell.needsCover = false
        return
    end
    if not HasSelectedCover(entry.name) then return end
    local channel = SourceChannel(entry)
    if channel == nil then return end
    local threat = RubickThreat(now)
    local entered = threat and not lastSpell.wasThreat
    lastSpell.wasThreat = threat

    if entered then BeginAction(entry, now, channel) end
end

local function ProcessAction(now)
    if not action then return end
    if not profile.protected.enabled[action.entry.name] then ResetAction(); return end
    local channel = SourceChannel(action.entry)
    if channel == nil then
        action.suspendedAt = action.suspendedAt or now
        return
    end
    if action.suspendedAt then
        action.expires = action.expires + now - action.suspendedAt
        action.suspendedAt = nil
    end
    if action.channel and not channel then
        action.channel = false
        if action.channelCovered then ResetAction(); return end
        action.expires = now + RETRY_WINDOW
        nextAttempt = now + uiDelay:Get() / 1000
        if not attempt then phase = "PENDING" end
    end
    if action.expires <= now and not attempt then ResetAction(); return end
    if attempt then
        local current = Snapshot(attempt.entry.ability)
        if Used(attempt.before, current, attempt.started, now) or (CooldownIncreased(attempt.before, current)
            and current.level ~= nil and current.level == attempt.before.level and attempt.sawPhase) then
            RememberSpell(attempt.entry, now, false)
            if channel then
                action.channelCovered = true
                attempt = nil
                phase = "CHANNELING"
            else ResetAction() end
            return
        end
        attempt.sawPhase = attempt.sawPhase or current.inPhase == true
        if current.inPhase ~= false or now < attempt.timeout then return end
        if attempt.vector and not CancelVector(attempt.entry) then return end
        action.tried[attempt.entry.name] = true
        LogOnce("reject:" .. attempt.entry.name, "No cast confirmation for " .. attempt.entry.name .. "; trying another cover.")
        attempt = nil
        phase = channel and "CHANNELING" or "PENDING"
        nextAttempt = now
    end
    if action.channelCovered or now < nextAttempt or now - lastOrderTime < RETRY_INTERVAL then return end
    nextAttempt = now + RETRY_INTERVAL
    if not HasSelectedCover(action.entry.name) then return end
    local threat = RubickThreat(now)
    if lastSpell and lastSpell.entry.name == action.entry.name then lastSpell.wasThreat = threat end
    if Incapacitated() or (uiLinkens:Get() and IsProtected()) or not threat or now < manualPauseUntil then return end

    local currentChannel = HeroChannel()
    if currentChannel and not channel then return end
    for _, entry in ipairs(entries) do
        if Snapshot(entry.ability).inPhase ~= false then return end
    end
    local blockers, blockerKeys = {}, {}
    local function blocked(name, reason, key)
        blockers[#blockers + 1] = name .. ": " .. reason
        blockerKeys[#blockerKeys + 1] = name .. ":" .. key
    end
    for _, name in ipairs(profile.covers.order) do
        local entry = byName[name]
        if profile.covers.enabled[name] and name ~= action.entry.name then
            if not entry then blocked(name, "not in current hero inventory", "missing")
            elseif action.tried[name] then blocked(name, "previous order was not confirmed", "rejected")
            else
                local ready, reason, key = Ready(entry, channel)
                if not ready then blocked(name, reason, key)
                else
                    local order = BuildOrder(entry)
                    if not order then
                        blocked(name, "no valid target/order (behavior=" .. tostring(entry.bits)
                            .. ", targetType=" .. tostring(Read(Ability, "GetTargetType", entry.ability, false))
                            .. ", range=" .. tostring(EffectiveRange(entry.ability)) .. ")", "target")
                    elseif Submit(entry, order, now) then return
                    else blocked(name, "order submission failed or local player unavailable", "submit") end
                end
            end
        end
    end

    LogOnce("no-cover:" .. action.entry.name .. ":" .. table.concat(blockerKeys, "|"),
        "No valid enabled cover for " .. action.entry.name .. "; " .. table.concat(blockers, "; ")
            .. "; retaining the retry window.")
end

local script = {}

function script.OnUpdate()
    updateContext = nil
    local now = Read(GameRules, "GetGameTime")
    if not Number(now) then return end
    local newMatch = Read(GameRules, "GetMatchID")
    if (lastTime and now < lastTime) or (matchId and newMatch and matchId ~= newMatch) then
        CaptureSelections()
        ResetSession()
    end
    matchId, lastTime = newMatch, now
    if not uiEnable:Get() then
        if hero then CaptureSelections(); ResetSession() end
        return
    end
    local localHero = Read(Heroes, "GetLocal")
    local alive = localHero and Read(Entity, "IsAlive", localHero)
    if not localHero or alive == false then
        if hero then CaptureSelections(); ResetSession() end
        return
    end
    if Read(Entity, "IsDormant", localHero) ~= false or alive ~= true then return end
    local name = Read(NPC, "GetUnitName", localHero)
    if type(name) ~= "string" or name == "" then return end
    if localHero ~= hero or name ~= heroName then
        CaptureSelections()
        ResetSession()
        hero, heroName = localHero, name
        if not profiles[name] then
            local protected = LoadSelection(name .. ".protected")
            local covers = LoadSelection(name .. ".covers")
            profiles[name] = { protected = protected, covers = covers,
                initialized = #protected.order > 0 or #covers.order > 0 }
        end
        profile = profiles[name]
    end
    updateContext = { snapshots = {} }
    if now >= nextRefresh then RefreshAbilities(now) end
    if profile then
        ObserveSpells(now)
        WatchLastSpell(now)
        ProcessAction(now)
    end
    updateContext = nil
end

function script.OnPrepareUnitOrders(order)
    if submitting or not hero or not uiEnable:Get() or order.npc ~= hero then return true end
    if order.identifier == "AntiRubickCover_v2" then return true end
    if order.order == ORDER.DOTA_UNIT_ORDER_STOP or order.order == ORDER.DOTA_UNIT_ORDER_HOLD_POSITION then
        ResetAction()
        if lastSpell then lastSpell.needsCover = false end
        manualPauseUntil = 0
        observations = {}
        return true
    end
    local ab = order.ability
    local castOrder = order.order == ORDER.DOTA_UNIT_ORDER_CAST_POSITION
        or order.order == ORDER.DOTA_UNIT_ORDER_CAST_TARGET
        or order.order == ORDER.DOTA_UNIT_ORDER_CAST_TARGET_TREE
        or order.order == ORDER.DOTA_UNIT_ORDER_CAST_NO_TARGET
        or order.order == ORDER.DOTA_UNIT_ORDER_CAST_TOGGLE
    if ab and castOrder then
        castSerial = castSerial + 1
        local orderTime = Read(GameRules, "GetGameTime")
        if not Number(orderTime) then orderTime = lastTime or 0 end
        local castPoint = Number(Read(Ability, "GetCastPoint", ab, true)) or 0
        local name = Read(Ability, "GetName", ab)
        local observation = observations[name]
        if observation then
            observation.intent = orderTime + castPoint + 0.5
            observation.intentAt = orderTime
            observation.intentSerial = castSerial
        end

        if not order.queue then
            if action then ResetAction() end
            manualPauseUntil = orderTime + castPoint + 0.5
            if lastSpell and lastSpell.needsCover then lastSpell.wasThreat = false end
        end
    end
    return true
end

function script.OnGameEnd()
    CaptureSelections()
    ResetSession()
    matchId, lastTime, logs = nil, nil, {}
end

return script
