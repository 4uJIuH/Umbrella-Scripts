--[[
    Void Spirit Escape
    Hold KeyBind to flee to the allied fountain using mobility and defensive tools in priority order.
    Script by 花曇り hanagumori
--]]

local Script = {}

--#region Constants
local NAME = "VoidSpiritEscape"
local UPDATE_INTERVAL = 0.05
local MOVE_INTERVAL = 0.20
local BUSY_PAD = 0.05
local ARRIVED_RADIUS = 650
local ENEMY_DANGER_RADIUS = 900
local HERO_NAME = "npc_dota_hero_void_spirit"

local ABILITY_PULSE = "void_spirit_resonant_pulse"
local ABILITY_STEP = "void_spirit_astral_step"
local ABILITY_DISSIMILATE = "void_spirit_dissimilate"
local ABILITY_REMNANT = "void_spirit_aether_remnant"

local ORDER_MOVE = "vs.escape.move"
local ORDER_CAST = "vs.escape.cast"
local ORDER_VECTOR = "vs.escape.vector"

-- Enums.lua Enum.ModifierState integers (do not index Enum.ModifierState at runtime).
local STATE_ROOTED = 0
local STATE_HEXED = 6
local STATE_INVISIBLE = 7

local FOUNTAIN_FALLBACK = {
    [Enum.TeamNum.TEAM_RADIANT] = Vector(-7200, -6660, 256),
    [Enum.TeamNum.TEAM_DIRE] = Vector(7130, 6550, 256),
}

local BLINK_ITEMS = {
    "item_blink",
    "item_arcane_blink",
    "item_overwhelming_blink",
    "item_swift_blink",
}

-- menuId -> dota item name + panorama fallback (Shadow Blade = invis_sword).
local ESCAPE_ITEM_DEFS = {
    { id = "glimmer", item = "item_glimmer_cape", fallback = "panorama/images/items/glimmer_cape_png.vtex_c" },
    { id = "ghost", item = "item_ghost", fallback = "panorama/images/items/ghost_png.vtex_c" },
    { id = "shadow_blade", item = "item_invis_sword", fallback = "panorama/images/items/invis_sword_png.vtex_c" },
    { id = "silver_edge", item = "item_silver_edge", fallback = "panorama/images/items/silver_edge_png.vtex_c" },
    { id = "bkb", item = "item_black_king_bar", fallback = "panorama/images/items/black_king_bar_png.vtex_c" },
    { id = "blink", item = "item_blink", fallback = "panorama/images/items/blink_png.vtex_c" },
    { id = "force", item = "item_force_staff", fallback = "panorama/images/items/force_staff_png.vtex_c" },
    { id = "hurricane", item = "item_hurricane_pike", fallback = "panorama/images/items/hurricane_pike_png.vtex_c" },
    { id = "lotus", item = "item_lotus_orb", fallback = "panorama/images/items/lotus_orb_png.vtex_c" },
    { id = "manta", item = "item_manta", fallback = "panorama/images/items/manta_png.vtex_c" },
    { id = "eul", item = "item_cyclone", fallback = "panorama/images/items/cyclone_png.vtex_c" },
    { id = "wind_waker", item = "item_wind_waker", fallback = "panorama/images/items/wind_waker_png.vtex_c" },
}
--#endregion

--#region State
---@class VoidSpiritEscapeUI
---@field enabled CMenuSwitch|nil
---@field bind CMenuBind|nil
---@field items CMenuMultiSelect|nil
local UI = {
    enabled = nil,
    bind = nil,
    items = nil,
}

local Runtime = {
    lastUpdateAt = -math.huge,
    lastMoveAt = -math.huge,
    busyUntil = -math.huge,
    dissimilateUntil = -math.huge,
    ---@type userdata|nil
    lastAbility = nil,
    ---@type userdata|nil
    fountain = nil,
    ---@type Vector|nil
    fountainPos = nil,
    wasHeld = false,
}
--#endregion

--#region Helpers
local function ResolveItemIcon(itemName, fallback)
    if type(LIB_RENDER) == "table" and type(LIB_RENDER.get_ability_icon_path) == "function" then
        local path = LIB_RENDER.get_ability_icon_path(itemName)
        if type(path) == "string" and path ~= "" then
            return path
        end
    end
    return fallback
end

local function BuildMultiSelectItems()
    local out = {}
    for i = 1, #ESCAPE_ITEM_DEFS do
        local def = ESCAPE_ITEM_DEFS[i]
        out[i] = { def.id, ResolveItemIcon(def.item, def.fallback), true }
    end
    return out
end

local function ResetRuntime()
    Runtime.lastUpdateAt = -math.huge
    Runtime.lastMoveAt = -math.huge
    Runtime.busyUntil = -math.huge
    Runtime.dissimilateUntil = -math.huge
    Runtime.lastAbility = nil
    Runtime.fountain = nil
    Runtime.fountainPos = nil
    Runtime.wasHeld = false
end

local function SyncDisabled()
    local off = not UI.enabled or UI.enabled:Get() ~= true
    if UI.bind then
        UI.bind:Disabled(off)
    end
    if UI.items then
        UI.items:Disabled(off)
    end
end

local function OnEnabledChanged()
    SyncDisabled()
    if not UI.enabled or UI.enabled:Get() ~= true then
        ResetRuntime()
    end
end

local function ItemEnabled(id)
    return not UI.items or UI.items:Get(id) == true
end

local function MarkBusy(ability, now)
    Runtime.lastAbility = ability
    Runtime.busyUntil = now + (Ability.GetCastPoint(ability) or 0.0) + BUSY_PAD
end

local function IsBusy(npc, now)
    if now < Runtime.busyUntil or NPC.IsChannellingAbility(npc) == true then
        return true
    end
    local ability = Runtime.lastAbility
    return ability ~= nil and Ability.IsInAbilityPhase(ability) == true
end

local function CanCast(ability, mana)
    return Ability.IsCastable(ability, mana) == true
end

local function IsHardCc(npc)
    return NPC.IsStunned(npc) == true
        or NPC.HasState(npc, STATE_ROOTED) == true
        or NPC.HasState(npc, STATE_HEXED) == true
end

local function IsStealthed(npc)
    return NPC.HasState(npc, STATE_INVISIBLE) == true
end

-- Invisible and not revealed (no dust/sentry/true sight): keep stealth — only move.
local function ShouldPreserveInvis(npc)
    return IsStealthed(npc) and NPC.IsVisibleToEnemies(npc) ~= true
end

local function IsFountainUnit(npc)
    local name = NPC.GetUnitName(npc)
    if not name or name == "" then
        return false
    end
    if name == "npc_dota_fountain" or name == "dota_fountain" then
        return true
    end
    return string.find(name, "fountain", 1, true) ~= nil
        and string.find(name, "xp_fountain", 1, true) == nil
end

local function ResolveFountain(me)
    local cached = Runtime.fountain
    if cached and Entity.IsAlive(cached) == true then
        Runtime.fountainPos = Entity.GetAbsOrigin(cached)
        return Runtime.fountainPos
    end

    local myTeam = Entity.GetTeamNum(me)
    local all = NPCs.GetAll()
    for i = 1, #all do
        local npc = all[i]
        if npc
            and Entity.IsAlive(npc) == true
            and Entity.GetTeamNum(npc) == myTeam
            and IsFountainUnit(npc)
        then
            Runtime.fountain = npc
            Runtime.fountainPos = Entity.GetAbsOrigin(npc)
            return Runtime.fountainPos
        end
    end

    local fallback = FOUNTAIN_FALLBACK[myTeam]
    Runtime.fountain = nil
    Runtime.fountainPos = fallback
    return fallback
end

local function EnemiesNearby(me, radius)
    local heroes = Entity.GetHeroesInRadius(me, radius, Enum.TeamType.TEAM_ENEMY, true, true)
    return heroes ~= nil and #heroes > 0, heroes
end

local function TowardFountain(mePos, fountainPos, distance)
    local travel = (mePos - fountainPos):Length2D()
    if travel <= 1.0 then
        return mePos
    end
    if distance >= travel then
        return fountainPos
    end
    return mePos:Extend2D(fountainPos, distance)
end

local function AwayFromFountain(mePos, fountainPos, distance)
    local dir = mePos - fountainPos
    if dir:Length2D() <= 1.0 then
        return mePos
    end
    return mePos:Extrapolate(dir:Normalized(), distance)
end

local function IssueMove(me, pos, now)
    if now - Runtime.lastMoveAt < MOVE_INTERVAL then
        return
    end
    Runtime.lastMoveAt = now
    NPC.MoveTo(me, pos, false, false, false, false, ORDER_MOVE, false)
end

local function FirstReadyItem(me, names, mana)
    for i = 1, #names do
        local item = NPC.GetItem(me, names[i], true)
        if item and CanCast(item, mana) then
            return item
        end
    end
    return nil
end

local function CastNoTarget(ability, now)
    Ability.CastNoTarget(ability, false, false, false, ORDER_CAST)
    MarkBusy(ability, now)
    return true
end

local function CastSelf(ability, me, now)
    Ability.CastTarget(ability, me, false, false, false, ORDER_CAST)
    MarkBusy(ability, now)
    return true
end

local function CastPos(ability, pos, now)
    Ability.CastPosition(ability, pos, false, false, false, ORDER_CAST, false)
    MarkBusy(ability, now)
    return true
end

local function CastAetherRemnant(me, ability, mePos, fountainPos, enemies, now)
    local player = Players.GetLocal()
    if not player then
        return false
    end

    local watch = Ability.GetLevelSpecialValueFor(ability, "remnant_watch_distance") or 450
    local placeDist = math.min(350, Ability.GetCastRange(ability) or 850)
    local placePos
    local facePos
    if enemies and enemies[1] then
        local enemyPos = Entity.GetAbsOrigin(enemies[1])
        placePos = mePos:Extend2D(enemyPos, placeDist)
        facePos = placePos:Extend2D(enemyPos, watch)
    else
        placePos = AwayFromFountain(mePos, fountainPos, placeDist)
        facePos = AwayFromFountain(placePos, fountainPos, watch)
    end

    Player.PrepareUnitOrders(
        player,
        Enum.UnitOrder.DOTA_UNIT_ORDER_VECTOR_TARGET_POSITION,
        nil,
        facePos,
        ability,
        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_HERO_ONLY,
        me,
        false,
        false,
        false,
        false,
        ORDER_VECTOR,
        false
    )
    Player.PrepareUnitOrders(
        player,
        Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION,
        nil,
        placePos,
        ability,
        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_HERO_ONLY,
        me,
        false,
        false,
        false,
        false,
        ORDER_CAST,
        false
    )
    MarkBusy(ability, now)
    return true
end

local function TryItemNoTarget(me, menuId, itemName, mana, now)
    if not ItemEnabled(menuId) then
        return false
    end
    local item = NPC.GetItem(me, itemName, true)
    if not item or not CanCast(item, mana) then
        return false
    end
    return CastNoTarget(item, now)
end

local function TryItemSelf(me, menuId, itemName, mana, now)
    if not ItemEnabled(menuId) then
        return false
    end
    local item = NPC.GetItem(me, itemName, true)
    if not item or not CanCast(item, mana) then
        return false
    end
    return CastSelf(item, me, now)
end

local function TrySoftDefense(me, mana, now, visibleToEnemies)
    if visibleToEnemies ~= true or NPC.HasState(me, STATE_INVISIBLE) == true then
        return false
    end
    if TryItemSelf(me, "glimmer", "item_glimmer_cape", mana, now) then
        return true
    end
    if TryItemNoTarget(me, "ghost", "item_ghost", mana, now) then
        return true
    end
    if TryItemNoTarget(me, "silver_edge", "item_silver_edge", mana, now) then
        return true
    end
    return TryItemNoTarget(me, "shadow_blade", "item_invis_sword", mana, now)
end

local function TryBkb(me, mana, now, dangerNearby)
    if not dangerNearby and not IsHardCc(me) then
        return false
    end
    return TryItemNoTarget(me, "bkb", "item_black_king_bar", mana, now)
end

local function TryPulse(me, mana, now, silenced)
    if silenced then
        return false
    end
    local pulse = NPC.GetAbility(me, ABILITY_PULSE)
    if not pulse or not CanCast(pulse, mana) then
        return false
    end
    return CastNoTarget(pulse, now)
end

local function TryBlink(me, mana, mePos, fountainPos, now, rooted)
    if rooted or not ItemEnabled("blink") then
        return false
    end
    local blink = FirstReadyItem(me, BLINK_ITEMS, mana)
    if not blink then
        return false
    end
    local range = Ability.GetLevelSpecialValueFor(blink, "blink_range")
    if not range or range <= 0 then
        range = Ability.GetCastRange(blink) or 1200
    end
    return CastPos(blink, TowardFountain(mePos, fountainPos, range), now)
end

local function TryForce(me, mana, now, rooted)
    if rooted then
        return false
    end
    if TryItemSelf(me, "hurricane", "item_hurricane_pike", mana, now) then
        return true
    end
    return TryItemSelf(me, "force", "item_force_staff", mana, now)
end

local function TryAstralStep(me, mana, mePos, fountainPos, now, silenced, rooted)
    if silenced or rooted then
        return false
    end
    local step = NPC.GetAbility(me, ABILITY_STEP)
    if not step or not CanCast(step, mana) then
        return false
    end
    if (Ability.GetCurrentCharges(step) or 0) <= 0 then
        return false
    end
    local maxTravel = Ability.GetLevelSpecialValueFor(step, "max_travel_distance") or 800
    local minTravel = Ability.GetLevelSpecialValueFor(step, "min_travel_distance") or 200
    if (mePos - fountainPos):Length2D() < minTravel then
        return false
    end
    return CastPos(step, TowardFountain(mePos, fountainPos, maxTravel), now)
end

local function TryDissimilate(me, mana, now, silenced, rooted)
    if silenced or rooted then
        return false
    end
    local ability = NPC.GetAbility(me, ABILITY_DISSIMILATE)
    if not ability or not CanCast(ability, mana) then
        return false
    end
    local phaseDuration = Ability.GetLevelSpecialValueFor(ability, "phase_duration") or 1.1
    Ability.CastNoTarget(ability, false, false, false, ORDER_CAST)
    MarkBusy(ability, now)
    Runtime.dissimilateUntil = now + phaseDuration
    return true
end

local function TryLotusOrManta(me, mana, now, dangerNearby, silenced)
    if dangerNearby and TryItemSelf(me, "lotus", "item_lotus_orb", mana, now) then
        return true
    end
    if silenced or IsHardCc(me) or dangerNearby then
        return TryItemNoTarget(me, "manta", "item_manta", mana, now)
    end
    return false
end

local function TryEulSelf(me, mana, now, rooted)
    if not IsHardCc(me) then
        return false
    end
    if not rooted then
        local forceReady = ItemEnabled("force") and NPC.GetItem(me, "item_force_staff", true)
        local hurricaneReady = ItemEnabled("hurricane") and NPC.GetItem(me, "item_hurricane_pike", true)
        local blinkReady = ItemEnabled("blink") and FirstReadyItem(me, BLINK_ITEMS, mana)
        if (forceReady and CanCast(forceReady, mana))
            or (hurricaneReady and CanCast(hurricaneReady, mana))
            or blinkReady
        then
            return false
        end
    end
    if TryItemSelf(me, "wind_waker", "item_wind_waker", mana, now) then
        return true
    end
    return TryItemSelf(me, "eul", "item_cyclone", mana, now)
end

local function TryRemnant(me, mana, mePos, fountainPos, enemies, now, silenced, rooted)
    if silenced or rooted or not enemies or #enemies == 0 then
        return false
    end
    local remnant = NPC.GetAbility(me, ABILITY_REMNANT)
    if not remnant or not CanCast(remnant, mana) then
        return false
    end
    return CastAetherRemnant(me, remnant, mePos, fountainPos, enemies, now)
end

local function TryEscapeCast(me, mePos, fountainPos, now)
    local mana = NPC.GetMana(me)
    local silenced = NPC.IsSilenced(me) == true
    local rooted = NPC.HasState(me, STATE_ROOTED) == true
    local visibleToEnemies = NPC.IsVisibleToEnemies(me) == true
    local dangerNearby, enemies = EnemiesNearby(me, ENEMY_DANGER_RADIUS)

    -- Stealthed and not revealed: do not cast (would break invis).
    if ShouldPreserveInvis(me) then
        return false
    end

    return TrySoftDefense(me, mana, now, visibleToEnemies)
        or TryBkb(me, mana, now, dangerNearby)
        or TryPulse(me, mana, now, silenced)
        or TryBlink(me, mana, mePos, fountainPos, now, rooted)
        or TryForce(me, mana, now, rooted)
        or TryAstralStep(me, mana, mePos, fountainPos, now, silenced, rooted)
        or TryDissimilate(me, mana, now, silenced, rooted)
        or TryLotusOrManta(me, mana, now, dangerNearby, silenced)
        or TryEulSelf(me, mana, now, rooted)
        or TryRemnant(me, mana, mePos, fountainPos, enemies, now, silenced, rooted)
end

local function UpdateEscape(me)
    local now = GameRules.GetGameTime()
    local fountainPos = ResolveFountain(me)
    if not fountainPos then
        return
    end

    local mePos = Entity.GetAbsOrigin(me)
    IssueMove(me, fountainPos, now)

    if now < Runtime.dissimilateUntil then
        return
    end
    if (mePos - fountainPos):Length2D() <= ARRIVED_RADIUS then
        return
    end
    if IsBusy(me, now) then
        return
    end

    TryEscapeCast(me, mePos, fountainPos, now)
end
--#endregion

--#region Lifecycle
function Script.OnScriptsLoaded()
    local group = Menu.Create("Heroes", "Hero List", "Void Spirit", "Main Settings", "Escape Module")
    UI.enabled = group:Switch("Enable", true, "\u{f00c}")
    UI.bind = group:Bind("Escape", Enum.ButtonCode.BUTTON_CODE_INVALID, "\u{e5ff}")
    UI.bind:MouseBinding(true)

    -- MultiSelect alone (no Label/Gear nest) — one open to pick icons.
    UI.items = group:MultiSelect("Items", BuildMultiSelectItems(), false)
    UI.items:Icon("\u{f03a}")

    UI.enabled:SetCallback(OnEnabledChanged, true)
end

function Script.OnUpdate()
    if not Engine.IsInGame() then
        return
    end
    if not UI.enabled or UI.enabled:Get() ~= true or not UI.bind then
        return
    end

    if UI.bind:IsDown() ~= true then
        if Runtime.wasHeld then
            ResetRuntime()
        end
        return
    end
    Runtime.wasHeld = true

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
    if NPC.GetUnitName(me) ~= HERO_NAME then
        return
    end

    UpdateEscape(me)
end

function Script.OnGameEnd()
    ResetRuntime()
end
--#endregion

return Script
