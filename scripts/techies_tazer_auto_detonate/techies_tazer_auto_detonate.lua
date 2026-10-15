--[[
    Techies Tazer Dispel
    Detonate Reactive Tazer only when already active and an enemy in radius
    has a selected buff. Never casts W.
    Script by 花曇り hanagumori
--]]

local Script = {}

--#region Constants
local NAME = "TechiesTazerDispel"
local ORDER_ID = "techies.tazer_dispel"
local UPDATE_INTERVAL = 0.03
local ORDER_SETTLE = 0.15
local RADIUS_FALLBACK = 400
local HERO_NAME = "npc_dota_hero_techies"
local ABILITY_TAZER = "techies_reactive_tazer"
local ABILITY_STOP = "techies_reactive_tazer_stop"
local MOD_TAZER = "modifier_techies_reactive_tazer"
local CAST_READY = -1

local STATE_MUTED = 4
local STATE_HEXED = 6
local STATE_COMMAND_RESTRICTED = 20
local STATE_OUT_OF_GAME = 33
local STATE_MAGIC_IMMUNE = 9
local STATE_DEBUFF_IMMUNE = 56

local DISPEL_TARGETS = {
    {
        id = "force_pike",
        mods = {
            "modifier_item_forcestaff_active",
            "modifier_item_hurricane_pike_active",
            "modifier_item_hurricane_pike_active_alternate",
        },
    },
    {
        id = "ghost",
        mods = { "modifier_ghost_state" },
    },
    {
        id = "eblade",
        mods = { "modifier_item_ethereal_blade_ethereal" },
    },
}
--#endregion

--#region State
---@class TechiesTazerDispelUI
---@field enabled CMenuSwitch|nil
---@field targets CMenuMultiSelect|nil
local UI = {
    enabled = nil,
    targets = nil,
}

local Persistent = {
    ---@type Logger|nil
    logger = nil,
}

---@type table<string, boolean>
local EnabledMods = {}

local Runtime = {
    lastUpdateAt = -math.huge,
    lastDetonateAt = -math.huge,
}
--#endregion

--#region Helpers
local function ResetRuntime()
    Runtime.lastUpdateAt = -math.huge
    Runtime.lastDetonateAt = -math.huge
end

local function RebuildEnabledMods()
    for k in pairs(EnabledMods) do
        EnabledMods[k] = nil
    end
    if not UI.targets then
        return
    end
    for i = 1, #DISPEL_TARGETS do
        local entry = DISPEL_TARGETS[i]
        if UI.targets:Get(entry.id) == true then
            local mods = entry.mods
            for j = 1, #mods do
                EnabledMods[mods[j]] = true
            end
        end
    end
end

local function OnEnabledChanged(widget)
    if UI.targets then
        UI.targets:Disabled(widget:Get() ~= true)
    end
    if widget:Get() ~= true then
        ResetRuntime()
    end
end

local function EnemyHasEnabledBuff(enemy)
    for modName in pairs(EnabledMods) do
        if NPC.GetModifier(enemy, modName) ~= nil then
            return true
        end
    end
    return false
end

local function ModifierIsWatched(modifier)
    local name = Modifier.GetName(modifier)
    if name and EnabledMods[name] == true then
        return true
    end
    local className = Modifier.GetClass(modifier)
    return className ~= nil and EnabledMods[className] == true
end

local function CanAct(me)
    if NPC.IsSilenced(me) == true or NPC.IsStunned(me) == true then
        return false
    end
    if NPC.HasState(me, STATE_MUTED) == true then
        return false
    end
    if NPC.HasState(me, STATE_HEXED) == true then
        return false
    end
    if NPC.HasState(me, STATE_COMMAND_RESTRICTED) == true then
        return false
    end
    return true
end

local function IsValidEnemy(enemy, me)
    if not enemy or Entity.IsAlive(enemy) ~= true then
        return false
    end
    if NPC.IsIllusion(enemy) == true or Entity.IsSameTeam(enemy, me) == true then
        return false
    end
    if NPC.IsVisible(enemy) ~= true then
        return false
    end
    if NPC.HasState(enemy, STATE_MAGIC_IMMUNE) == true then
        return false
    end
    if NPC.HasState(enemy, STATE_DEBUFF_IMMUNE) == true then
        return false
    end
    if NPC.HasState(enemy, STATE_OUT_OF_GAME) == true then
        return false
    end
    return true
end

local function FindTazerCarrier(me)
    if NPC.GetModifier(me, MOD_TAZER) ~= nil then
        return me
    end

    local heroes = Heroes.GetAll()
    for i = 1, #heroes do
        local ally = heroes[i]
        if ally
            and Entity.IsAlive(ally) == true
            and Entity.IsSameTeam(ally, me) == true
            and NPC.IsIllusion(ally) ~= true
        then
            local mod = NPC.GetModifier(ally, MOD_TAZER)
            if mod ~= nil then
                local ab = Modifier.GetAbility(mod)
                if ab and Ability.GetOwner(ab) == me then
                    return ally
                end
            end
        end
    end
    return nil
end

local function ExplosionRadius(me)
    local tazer = NPC.GetAbility(me, ABILITY_TAZER)
    if tazer then
        local radius = Ability.GetLevelSpecialValueFor(tazer, "explosion_radius")
        if radius and radius > 0 then
            return radius
        end
    end
    return RADIUS_FALLBACK
end

-- Stop is often hidden / level 0; CanBeExecuted may fail even when usable.
local function GetDetonate(me)
    local stop = NPC.GetAbility(me, ABILITY_STOP)
    if not stop then
        return nil
    end
    if Ability.CanBeExecuted(stop) == CAST_READY then
        return stop
    end
    if Ability.IsCastable(stop, NPC.GetMana(me)) == true then
        return stop
    end
    if Ability.GetCooldown(stop) <= 0.05 then
        return stop
    end
    return nil
end

local function CastDetonate(stop, now)
    if now - Runtime.lastDetonateAt < ORDER_SETTLE then
        return false
    end
    Ability.CastNoTarget(stop, false, false, false, ORDER_ID)
    Runtime.lastDetonateAt = now
    return true
end

local function TryDispelNearCarrier(me, carrier, now)
    local stop = GetDetonate(me)
    if not stop then
        return false
    end

    local radius = ExplosionRadius(me)
    local pos = Entity.GetAbsOrigin(carrier)
    if not pos then
        return false
    end

    local enemies = Heroes.InRadius(
        pos,
        radius,
        Entity.GetTeamNum(me),
        Enum.TeamType.TEAM_ENEMY,
        true,
        true
    )
    for i = 1, #enemies do
        local enemy = enemies[i]
        if IsValidEnemy(enemy, me) and EnemyHasEnabledBuff(enemy) then
            return CastDetonate(stop, now)
        end
    end
    return false
end

local function TryDispel(me, now)
    if NPC.GetUnitName(me) ~= HERO_NAME or CanAct(me) ~= true then
        return
    end
    if next(EnabledMods) == nil then
        return
    end
    local carrier = FindTazerCarrier(me)
    if not carrier then
        return
    end
    TryDispelNearCarrier(me, carrier, now)
end
--#endregion

--#region Lifecycle
function Script.OnScriptsLoaded()
    Persistent.logger = Logger(NAME)

    local group = Menu.Find("Heroes", "Hero List", "Techies", "Main Settings", "Auto Dispel")
    if not group then
        local main = Menu.Find("Heroes", "Hero List", "Techies", "Main Settings")
        if not main then
            Persistent.logger:error("Menu.Find Heroes/Hero List/Techies/Main Settings returned nil")
            return
        end
        group = main:Create("Auto Dispel", Enum.GroupSide.Left)
    end

    UI.enabled = group:Switch("Enable", true, "\u{f00c}")
    UI.enabled:ToolTip("Detonate only when Reactive Tazer is already active.")

    UI.targets = group:MultiSelect("Dispel targets", {
        { "force_pike", "panorama/images/items/force_staff_png.vtex_c", true },
        { "ghost", "panorama/images/items/ghost_png.vtex_c", false },
        { "eblade", "panorama/images/items/ethereal_blade_png.vtex_c", false },
    }, false)
    UI.targets:Icon("\u{f03a}")
    UI.targets:ToolTip("Enemy buffs that trigger Detonate Tazer.")
    UI.targets:SetCallback(RebuildEnabledMods, true)
    UI.enabled:SetCallback(OnEnabledChanged, true)

    Persistent.logger:info("loaded")
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

    TryDispel(me, now)
end

function Script.OnModifierCreate(entity, modifier)
    if not Engine.IsInGame() then
        return
    end
    if not UI.enabled or UI.enabled:Get() ~= true then
        return
    end
    if not entity or Entity.IsHero(entity) ~= true then
        return
    end
    if ModifierIsWatched(modifier) ~= true then
        return
    end

    local me = Heroes.GetLocal()
    if not me or Entity.IsAlive(me) ~= true then
        return
    end
    if IsValidEnemy(entity, me) ~= true or EnemyHasEnabledBuff(entity) ~= true then
        return
    end

    TryDispel(me, GameRules.GetGameTime())
end

function Script.OnGameEnd()
    ResetRuntime()
end
--#endregion

return Script
