--[[
    AutoFocus
    Auto-attack high-value enemy summons: Tombstone, wards, Phoenix egg, Lifestealer Infest host.
    Script by 花曇り hanagumori
--]]

local Script = {}

--#region Constants
local UPDATE_INTERVAL = 0.12
local UNIT_ORDER_GAP = 1.10
local HERO_ORDER_GAP = 1.25
local ABILITY_ORDER_GAP = 0.35
local HERO_OVERRIDE_PAUSE = 2.0
local ORDER_ID = "autofocus.attack"
local ORDER_CAST_ID = "autofocus.cast"
local DEFAULT_RADIUS = 1200
local ABILITY_SLOT_MAX = 24

local STATE_DISARMED = 1 -- MODIFIER_STATE_DISARMED
local STATE_ATTACK_IMMUNE = 2 -- MODIFIER_STATE_ATTACK_IMMUNE
local STATE_NIGHTMARED = 11 -- MODIFIER_STATE_NIGHTMARED

local BEHAVIOR_PASSIVE = 2 -- Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_PASSIVE
local BEHAVIOR_UNIT_TARGET = 8 -- Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_UNIT_TARGET
local BEHAVIOR_POINT = 16 -- Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_POINT
local BEHAVIOR_CHANNELLED = 128 -- Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_CHANNELLED
local BEHAVIOR_TOGGLE = 512 -- Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_TOGGLE
local BEHAVIOR_VECTOR = 1073741824 -- Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_VECTOR_TARGETING

local TARGET_TEAM_FRIENDLY = 1 -- Enum.TargetTeam.DOTA_UNIT_TARGET_TEAM_FRIENDLY
local CAST_READY = -1 -- Enum.AbilityCastResult.READY

local ICON_ENABLE = "\u{e4bf}"
local ICON_HERO = "\u{f6eb}"
local ICON_UNITS = "\u{f0c0}"
local ICON_RADIUS = "\u{f689}"
local ICON_TARGETS = "\u{e4bf}"

---@type {id: string, priority: integer, icon: string, tip: string, exact?: string, nameHas?: string, classHas?: string, modifier?: string}[]
local TARGET_DEFS = {
    {
        id = "tombstone",
        priority = 100,
        icon = "panorama/images/spellicons/undying_tombstone_png.vtex_c",
        tip = "tip_tombstone",
        nameHas = "tombstone",
        classHas = "Undying_Tombstone",
    },
    {
        id = "infest",
        priority = 95,
        icon = "panorama/images/spellicons/life_stealer_infest_png.vtex_c",
        tip = "tip_infest",
        modifier = "modifier_life_stealer_infest_creep",
    },
    {
        id = "phoenix",
        priority = 90,
        icon = "panorama/images/spellicons/phoenix_supernova_png.vtex_c",
        tip = "tip_phoenix",
        exact = "npc_dota_phoenix_sun",
        classHas = "Phoenix_Sun",
    },
    {
        id = "nether_ward",
        priority = 88,
        icon = "panorama/images/spellicons/pugna_nether_ward_png.vtex_c",
        tip = "tip_nether",
        exact = "npc_dota_pugna_nether_ward",
        nameHas = "nether_ward",
    },
    {
        id = "healing_ward",
        priority = 85,
        icon = "panorama/images/spellicons/juggernaut_healing_ward_png.vtex_c",
        tip = "tip_healing",
        exact = "npc_dota_juggernaut_healing_ward",
    },
    {
        id = "serpent",
        priority = 70,
        icon = "panorama/images/spellicons/shadow_shaman_mass_serpent_ward_png.vtex_c",
        tip = "tip_serpent",
        nameHas = "shadow_shaman_ward",
    },
    {
        id = "plague",
        priority = 40,
        icon = "panorama/images/spellicons/venomancer_plague_ward_png.vtex_c",
        tip = "tip_plague",
        nameHas = "venomancer_plague_ward",
    },
}

--#endregion

--#region Locale
local Locale = {
    ui_enabled = { en = "AutoFocus", ru = "AutoFocus", cn = "AutoFocus" },
    tip_enabled = {
        en = "Automatically attack high-value enemy summons (wards, Tombstone, Phoenix egg, Infest host). Hero stays soft; controllable units clear the rest.",
        ru = "Автоматически атакует важные вражеские саммоны (варды, Tombstone, яйцо Phoenix, крип с Infest). Герой атакует мягко; подконтрольные юниты добивают остальное.",
        cn = "自动攻击高价值敌方召唤物（守卫、墓碑、凤凰蛋、感染宿主）。英雄攻击较克制；可控单位负责清理其余目标。",
    },
    gear_settings = { en = "Settings", ru = "Настройки", cn = "设置" },
    ui_hero = { en = "Hero Attack", ru = "Атака героем", cn = "英雄攻击" },
    tip_hero = {
        en = "Your hero focuses one best target and yields for 2s after any manual order, so you can freely attack heroes.",
        ru = "Герой бьёт одну лучшую цель и на 2 сек. уступает после любого ручного приказа — можно спокойно бить героев.",
        cn = "英雄专注单一最优目标；手动下令后暂停 2 秒，方便你自由攻击敌方英雄。",
    },
    ui_units = { en = "Controllable Units", ru = "Подконтрольные юниты", cn = "可控单位" },
    tip_units = {
        en = "All controllable non-hero units spread across enabled targets and keep breaking them. On Infest host they also cast their offensive spells.",
        ru = "Все подконтрольные не-герои распределяются по включённым целям и продолжают их ломать. По крипу с Infest ещё жгут свои боевые способности.",
        cn = "所有可控非英雄单位会分摊到已启用的目标上并持续拆除；对感染宿主还会释放攻击技能。",
    },
    ui_radius = { en = "Search Radius", ru = "Радиус поиска", cn = "搜索半径" },
    tip_radius = {
        en = "How far from your hero to look for focus targets.",
        ru = "На каком расстоянии от героя искать цели для фокуса.",
        cn = "从英雄周围多远范围内搜索优先目标。",
    },
    ui_targets = { en = "Targets", ru = "Цели", cn = "目标" },
    tip_targets = {
        en = "Choose which summon types AutoFocus should attack. Hover an icon for details.",
        ru = "Выберите типы саммонов, которые AutoFocus должен атаковать. Наведите на иконку для подсказки.",
        cn = "选择 AutoFocus 要攻击的召唤物类型。悬停图标可查看说明。",
    },
    tip_tombstone = {
        en = "Undying Tombstone — high priority, destroy ASAP.",
        ru = "Tombstone Undying — высокий приоритет, ломать сразу.",
        cn = "尸王墓碑 — 高优先级，尽快拆除。",
    },
    tip_phoenix = {
        en = "Phoenix Supernova egg — attackable hit-count unit.",
        ru = "Яйцо Phoenix (Supernova) — бьётся по числу ударов.",
        cn = "凤凰超级新星蛋 — 按攻击次数拆除。",
    },
    tip_nether = {
        en = "Pugna Nether Ward — drains mana from casters nearby.",
        ru = "Nether Ward Pugna — жрёт ману кастерам рядом.",
        cn = "帕格纳幽冥守卫 — 吸取附近施法者魔法。",
    },
    tip_healing = {
        en = "Juggernaut Healing Ward — stop the aura heal.",
        ru = "Healing Ward Juggernaut — сбить ауру лечения.",
        cn = "主宰治疗守卫 — 打断治疗光环。",
    },
    tip_serpent = {
        en = "Shadow Shaman Serpent Wards — spread units across them.",
        ru = "Serpent Wards Shadow Shaman — распределять юнитов по змейкам.",
        cn = "暗影萨满蛇棒 — 让单位分摊清理。",
    },
    tip_plague = {
        en = "Venomancer Plague Wards — usually many; enable if you want them cleared.",
        ru = "Plague Wards Venomancer — обычно много; включай, если нужно зачищать.",
        cn = "剧毒术士瘟疫守卫 — 通常数量多；需要清理时再开启。",
    },
    tip_infest = {
        en = "Lifestealer Infest host creep — kill the body to force him out.",
        ru = "Крип с Infest Lifestealer — ломай носителя, чтобы выгнать Naix.",
        cn = "噬魂鬼感染宿主小兵 — 打掉宿主逼他出来。",
    },
}
--#endregion

--#region State
---@class AutoFocusUI
---@field enabled CMenuSwitch|nil
---@field useHero CMenuSwitch|nil
---@field useUnits CMenuSwitch|nil
---@field searchRadius CMenuSliderInt|nil
---@field targets CMenuMultiSelect|nil
local UI = {
    enabled = nil,
    useHero = nil,
    useUnits = nil,
    searchRadius = nil,
    targets = nil,
}

local Persistent = {
    menuGear = nil,
    languageWidget = nil,
    languageLookupAt = 0,
    languageCallbackSet = false,
    lastLanguage = nil,
}

local Runtime = {
    lastUpdateAt = -math.huge,
    heroOverrideUntil = -math.huge,
    heroTargetIndex = nil,
    ---@type table<integer, number>
    issuedAt = {},
    ---@type table<integer, number>
    castIssuedAt = {},
    ---@type table<integer, integer>
    unitTargetIndex = {},
}
--#endregion

--#region Localization
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
        or value:find("简体", 1, true)
    then
        return "cn"
    end
    return "en"
end

local function L(key)
    local entry = Locale[key]
    if not entry then
        return tostring(key)
    end
    return entry[GetLanguageCode()] or entry.en or tostring(key)
end

local function ApplyLocalization(force)
    local lang = GetLanguageCode()
    if not force and Persistent.lastLanguage == lang then
        return
    end
    Persistent.lastLanguage = lang

    if Persistent.menuGear then
        Persistent.menuGear:ForceLocalization(L("gear_settings"))
    end

    UI.enabled:ForceLocalization(L("ui_enabled"))
    UI.enabled:ToolTip(L("tip_enabled"))
    UI.useHero:ForceLocalization(L("ui_hero"))
    UI.useHero:ToolTip(L("tip_hero"))
    UI.useUnits:ForceLocalization(L("ui_units"))
    UI.useUnits:ToolTip(L("tip_units"))
    UI.searchRadius:ForceLocalization(L("ui_radius"))
    UI.searchRadius:ToolTip(L("tip_radius"))
    UI.targets:ForceLocalization(L("ui_targets"))
    UI.targets:ToolTip(L("tip_targets"))

    local tips = {}
    for i = 1, #TARGET_DEFS do
        local def = TARGET_DEFS[i]
        tips[def.id] = L(def.tip)
    end
    UI.targets:UpdateToolTips(tips)
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
--#endregion

--#region Helpers
local function ResetRuntime()
    Runtime.lastUpdateAt = -math.huge
    Runtime.heroOverrideUntil = -math.huge
    Runtime.heroTargetIndex = nil
    Runtime.issuedAt = {}
    Runtime.castIssuedAt = {}
    Runtime.unitTargetIndex = {}
end

local function OnEnabledChanged(widget)
    if widget:Get() ~= true then
        ResetRuntime()
    end
end

local function HasPlain(haystack, needle)
    return haystack ~= nil and haystack ~= "" and needle ~= nil
        and string.find(haystack, needle, 1, true) ~= nil
end

local function ClassifyNpc(npc)
    local name = NPC.GetUnitName(npc)
    if not name or name == "" then
        name = Entity.GetUnitName(npc)
    end
    local className = Entity.GetClassName(npc)

    for i = 1, #TARGET_DEFS do
        local def = TARGET_DEFS[i]
        if def.modifier and NPC.GetModifier(npc, def.modifier) then
            return def
        end
        if (def.exact and name == def.exact)
            or HasPlain(name, def.nameHas)
            or HasPlain(className, def.classHas)
        then
            return def
        end
    end
    return nil
end

local function IsAttackableTarget(npc)
    return Entity.IsAlive(npc) == true
        and NPC.IsWaitingToSpawn(npc) ~= true
        and NPC.IsVisible(npc) == true
        and NPC.HasState(npc, STATE_ATTACK_IMMUNE) ~= true
end

local function CanAttackerIssue(npc)
    return Entity.IsAlive(npc) == true
        and NPC.HasState(npc, STATE_DISARMED) ~= true
        and NPC.IsStunned(npc) ~= true
        and NPC.HasState(npc, STATE_NIGHTMARED) ~= true
end

local function CollectTargets(myTeam, origin, radius)
    local radiusSqr = radius * radius
    local units = NPCs.GetAll()
    ---@type {npc: userdata, def: table, priority: integer, pos: Vector, index: integer, distSqr: number}[]
    local targets = {}

    for i = 1, #units do
        local npc = units[i]
        if Entity.GetTeamNum(npc) ~= myTeam and IsAttackableTarget(npc) then
            local pos = Entity.GetAbsOrigin(npc)
            local distSqr = pos:DistanceSqr2D(origin)
            if distSqr <= radiusSqr then
                local def = ClassifyNpc(npc)
                if def and UI.targets:Get(def.id) == true then
                    targets[#targets + 1] = {
                        npc = npc,
                        def = def,
                        priority = def.priority,
                        pos = pos,
                        index = Entity.GetIndex(npc),
                        distSqr = distSqr,
                    }
                end
            end
        end
    end

    table.sort(targets, function(a, b)
        if a.priority ~= b.priority then
            return a.priority > b.priority
        end
        return a.distSqr < b.distSqr
    end)

    return targets
end

local function FindTargetByIndex(targets, entityIndex)
    if not entityIndex then
        return nil
    end
    for i = 1, #targets do
        if targets[i].index == entityIndex then
            return i
        end
    end
    return nil
end

local function CanCasterIssue(npc)
    return Entity.IsAlive(npc) == true
        and NPC.IsStunned(npc) ~= true
        and NPC.IsSilenced(npc) ~= true
        and NPC.HasState(npc, STATE_NIGHTMARED) ~= true
end

local function HasBehaviorFlag(behavior, flag)
    return type(behavior) == "number" and (behavior & flag) ~= 0
end

local function IsOffensiveUnitSpell(ability)
    if not ability then
        return false
    end
    if Ability.GetLevel(ability) < 1 then
        return false
    end
    if Ability.IsHidden(ability) == true then
        return false
    end
    if Ability.IsPassive(ability) == true or Ability.IsAttributes(ability) == true then
        return false
    end
    if Ability.IsInnatePassive(ability) == true then
        return false
    end

    local behavior = Ability.GetBehavior(ability)
    if HasBehaviorFlag(behavior, BEHAVIOR_PASSIVE)
        or HasBehaviorFlag(behavior, BEHAVIOR_TOGGLE)
        or HasBehaviorFlag(behavior, BEHAVIOR_CHANNELLED)
        or HasBehaviorFlag(behavior, BEHAVIOR_VECTOR)
    then
        return false
    end

    local isUnit = HasBehaviorFlag(behavior, BEHAVIOR_UNIT_TARGET)
    local isPoint = HasBehaviorFlag(behavior, BEHAVIOR_POINT)
    if not isUnit and not isPoint then
        return false
    end

    local team = Ability.GetTargetTeam(ability)
    if team == TARGET_TEAM_FRIENDLY then
        return false
    end

    return true, isUnit, isPoint
end

local function TryCastOnInfestHost(caster, target, now)
    if not CanCasterIssue(caster) then
        return false
    end

    local casterIndex = Entity.GetIndex(caster)
    local lastCast = Runtime.castIssuedAt[casterIndex]
    if lastCast and now - lastCast < ABILITY_ORDER_GAP then
        return false
    end

    local mana = NPC.GetMana(caster)
    local castBonus = NPC.GetCastRangeBonus(caster)

    for slot = 0, ABILITY_SLOT_MAX do
        local ability = NPC.GetAbilityByIndex(caster, slot)
        if ability then
            local ok, isUnit, isPoint = IsOffensiveUnitSpell(ability)
            if ok
                and Ability.IsReady(ability) == true
                and Ability.IsOwnersManaEnough(ability) == true
                and Ability.IsCastable(ability, mana) == true
                and Ability.CanBeExecuted(ability) == CAST_READY
                and Ability.IsInAbilityPhase(ability) ~= true
            then
                local castRange = Ability.GetCastRange(ability) + castBonus
                if castRange < 0 then
                    castRange = 0
                end
                if NPC.IsEntityInRange(caster, target, castRange + 80) == true then
                    if isUnit then
                        Ability.CastTarget(ability, target, false, true, true, ORDER_CAST_ID)
                    else
                        Ability.CastPosition(
                            ability,
                            Entity.GetAbsOrigin(target),
                            false,
                            true,
                            true,
                            ORDER_CAST_ID,
                            false
                        )
                    end
                    Runtime.castIssuedAt[casterIndex] = now
                    return true
                end
            end
        end
    end

    return false
end

local function CollectUnitAttackers(playerId, me, origin, radius)
    local radiusSqr = radius * radius
    local units = NPCs.GetAll()
    ---@type userdata[]
    local attackers = {}

    for i = 1, #units do
        local npc = units[i]
        if npc ~= me
            and NPC.IsControllableByPlayer(npc, playerId) == true
            and CanAttackerIssue(npc)
            and NPC.IsCourier(npc) ~= true
            and NPC.IsHero(npc) ~= true
            and Entity.GetAbsOrigin(npc):DistanceSqr2D(origin) <= radiusSqr
        then
            attackers[#attackers + 1] = npc
        end
    end

    return attackers
end

local function PickTargetForUnit(attacker, targets, assignedCounts)
    local stickySlot = FindTargetByIndex(targets, Runtime.unitTargetIndex[Entity.GetIndex(attacker)])
    if stickySlot then
        return stickySlot
    end

    local attackerPos = Entity.GetAbsOrigin(attacker)
    local minAssigned = math.huge
    for i = 1, #targets do
        local count = assignedCounts[i] or 0
        if count < minAssigned then
            minAssigned = count
        end
    end

    local bestIndex = nil
    local bestPriority = -math.huge
    local bestDist = math.huge

    for i = 1, #targets do
        if (assignedCounts[i] or 0) == minAssigned then
            local entry = targets[i]
            local distSqr = attackerPos:DistanceSqr2D(entry.pos)
            if entry.priority > bestPriority
                or (entry.priority == bestPriority and distSqr < bestDist)
            then
                bestPriority = entry.priority
                bestDist = distSqr
                bestIndex = i
            end
        end
    end

    return bestIndex
end

local function IssueAttack(player, attacker, target, now, gap)
    local index = Entity.GetIndex(attacker)
    local lastIssued = Runtime.issuedAt[index]
    if lastIssued and now - lastIssued < gap then
        return
    end
    Player.AttackTarget(player, attacker, target, false, true, false, ORDER_ID, false)
    Runtime.issuedAt[index] = now
end

local function UpdateHeroFocus(player, me, targets, now)
    if UI.useHero:Get() ~= true or now < Runtime.heroOverrideUntil or not CanAttackerIssue(me) then
        if UI.useHero:Get() ~= true then
            Runtime.heroTargetIndex = nil
        end
        return
    end

    local slot = FindTargetByIndex(targets, Runtime.heroTargetIndex)
    if not slot then
        slot = 1
        Runtime.heroTargetIndex = targets[1].index
    end

    IssueAttack(player, me, targets[slot].npc, now, HERO_ORDER_GAP)
end

local function UpdateUnitFocus(player, playerId, me, targets, origin, radius, now)
    if UI.useUnits:Get() ~= true then
        return
    end

    local attackers = CollectUnitAttackers(playerId, me, origin, radius)
    ---@type table<integer, integer>
    local assignedCounts = {}

    for i = 1, #attackers do
        local attacker = attackers[i]
        local targetIndex = PickTargetForUnit(attacker, targets, assignedCounts)
        if targetIndex then
            local entry = targets[targetIndex]
            local attackerIndex = Entity.GetIndex(attacker)
            local sameTarget = Runtime.unitTargetIndex[attackerIndex] == entry.index

            assignedCounts[targetIndex] = (assignedCounts[targetIndex] or 0) + 1
            Runtime.unitTargetIndex[attackerIndex] = entry.index

            if entry.def.id == "infest" then
                TryCastOnInfestHost(attacker, entry.npc, now)
            end

            -- Already chopping the sticky target — don't refresh the order.
            if not (sameTarget and NPC.IsAttacking(attacker) == true) then
                IssueAttack(player, attacker, entry.npc, now, UNIT_ORDER_GAP)
            end
        end
    end
end

local function UpdateFeature(me, now)
    if UI.useHero:Get() ~= true and UI.useUnits:Get() ~= true then
        return
    end
    if not UI.targets or #(UI.targets:ListEnabled() or {}) == 0 then
        return
    end

    local player = Players.GetLocal()
    if not player then
        return
    end
    local playerId = Player.GetPlayerID(player)
    if playerId < 0 then
        return
    end

    local radius = UI.searchRadius:Get()
    local targets = CollectTargets(Entity.GetTeamNum(me), Entity.GetAbsOrigin(me), radius)
    if #targets == 0 then
        Runtime.heroTargetIndex = nil
        return
    end

    local origin = Entity.GetAbsOrigin(me)
    UpdateHeroFocus(player, me, targets, now)
    UpdateUnitFocus(player, playerId, me, targets, origin, radius, now)
end
--#endregion

--#region Lifecycle
function Script.OnScriptsLoaded()
    local group = Menu.Create("Heroes", "", "Settings", "General", "Units Controller")
    UI.enabled = group:Switch("AutoFocus", true, ICON_ENABLE)
    UI.enabled:SetCallback(OnEnabledChanged, false)

    local gear = UI.enabled:Gear("Settings")
    Persistent.menuGear = gear
    UI.useHero = gear:Switch("Hero Attack", true, ICON_HERO)
    UI.useUnits = gear:Switch("Controllable Units", true, ICON_UNITS)
    UI.searchRadius = gear:Slider("Search Radius", 400, 2500, DEFAULT_RADIUS)
    UI.searchRadius:Icon(ICON_RADIUS)

    local items = {}
    for i = 1, #TARGET_DEFS do
        local def = TARGET_DEFS[i]
        items[i] = { def.id, def.icon, def.id ~= "plague" }
    end
    UI.targets = gear:MultiSelect("Targets", items, true)
    UI.targets:Icon(ICON_TARGETS)

    ApplyLocalization(true)
    SetupLanguageCallback()
end

function Script.OnPrepareUnitOrders(data, player, order, target, position, ability, orderIssuer, npc, queue, showEffects)
    if data and (data.identifier == ORDER_ID or data.identifier == ORDER_CAST_ID) then
        return true
    end

    local me = Heroes.GetLocal()
    if me and npc == me then
        Runtime.heroOverrideUntil = GameRules.GetGameTime() + HERO_OVERRIDE_PAUSE
        Runtime.heroTargetIndex = nil
    end
    return true
end

function Script.OnUpdate()
    ApplyLocalization(false)
    SetupLanguageCallback()

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

    UpdateFeature(me, now)
end

function Script.OnGameEnd()
    ResetRuntime()
end
--#endregion

return Script
