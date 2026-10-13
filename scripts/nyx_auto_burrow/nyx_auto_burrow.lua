---@diagnostic disable: undefined-global
--[[
    Nyx Assassin - Auto Burrow (Umbrella API v2.0)
    Burrow available with Aghanim's Scepter. Cast time 1.5s, unburrow instant.
--]]

local script = {}

local HERO     = "npc_dota_hero_nyx_assassin"
local VENDETTA = "modifier_nyx_assassin_vendetta"
local IMPALE   = "modifier_nyx_assassin_impale"
local HEXED    = Enum.ModifierState.MODIFIER_STATE_HEXED

local UI = { ready = false }
local last_user_order = 0
local last_cast = 0

local function InitMenu()
    if UI.ready then return end

    local tab = Menu.Create("Heroes", "Hero List", "Nyx Assassin", "Auto Burrow")
    if not tab then return end
    local grp = tab:Create("Main")
    if not grp then return end

    UI.enable      = grp:Switch("Enable Auto Burrow", true)
    UI.idle        = grp:Switch("Burrow on Idle", true)
    UI.idle_time   = grp:Slider("Idle Delay (sec*10)", 5, 50, 20, function(v) return string.format("%.1f s", v / 10) end)

    UI.low         = grp:Switch("Burrow on Low HP/Mana", true)
    UI.low_hp      = grp:Slider("Low HP Threshold", 0, 90, 40, "%d%%")
    UI.low_mana    = grp:Slider("Low Mana Threshold (0 = disabled)", 0, 90, 0, "%d%%")

    UI.safe_radius = grp:Slider("Safe Distance from Enemies", 300, 2000, 900, "%d")

    UI.fight       = grp:Switch("Burrow in Fight (when enemies disabled)", true)
    UI.fight_rad   = grp:Slider("Fight Radius", 300, 1200, 700, "%d")
    UI.fight_free  = grp:Slider("Allowed Unstunned Enemies", 0, 3, 0, "%d")
    UI.impale_left = grp:Slider("Min Impale Duration Left (sec*10)", 0, 20, 12, function(v) return string.format("%.1f s", v / 10) end)

    UI.vendetta    = grp:Switch("Do not burrow during Vendetta", true)

    UI.fight_free:ToolTip("0 = only when ALL enemies in radius are stunned. 1+ = allows burrow even if some enemies free (cast is 1.5s).")
    UI.impale_left:ToolTip("Impaled enemy counts as disabled only if remaining stun is >= this value. Burrow cast is 1.5s.")

    UI.ready = true
end

local function Pct(cur, max) return max > 0 and cur / max * 100 or 100 end

local function EnemiesIn(me, radius)
    return Heroes.InRadius(Entity.GetAbsOrigin(me), radius, Entity.GetTeamNum(me), Enum.TeamType.TEAM_ENEMY, true, true) or {}
end

local function IsDisabled(enemy, now)
    local impale = NPC.GetModifier(enemy, IMPALE)
    if impale then
        return Modifier.GetDieTime(impale) - now >= UI.impale_left:Get() / 10
    end
    return NPC.IsStunned(enemy) or NPC.HasState(enemy, HEXED)
end

local function ShouldBurrow(me, now, quiet)
    if NPC.IsRunning(me) then return false end

    if UI.fight:Get() and quiet >= 0.3 then
        local enemies = EnemiesIn(me, UI.fight_rad:Get())
        if #enemies > 0 then
            local free = 0
            for _, e in ipairs(enemies) do
                if not IsDisabled(e, now) then free = free + 1 end
            end
            if free <= UI.fight_free:Get() then return true end
        end
    end

    local safe = #EnemiesIn(me, UI.safe_radius:Get()) == 0
    if not safe then return false end

    if UI.low:Get() and quiet >= 0.5 then
        local mana_thr = UI.low_mana:Get()
        if Pct(Entity.GetHealth(me), Entity.GetMaxHealth(me)) <= UI.low_hp:Get()
        or (mana_thr > 0 and Pct(NPC.GetMana(me), NPC.GetMaxMana(me)) <= mana_thr) then
            return true
        end
    end

    if UI.idle:Get() and quiet >= UI.idle_time:Get() / 10 and not NPC.IsAttacking(me) then
        return true
    end

    return false
end

function script.OnScriptsLoaded()
    InitMenu()
end

function script.OnUpdate()
    if not UI.ready then
        InitMenu()
    end
    if not UI.ready or not UI.enable:Get() then return end

    local me = Heroes.GetLocal()
    if not me or NPC.GetUnitName(me) ~= HERO or not Entity.IsAlive(me) then return end

    local burrow = NPC.GetAbility(me, "nyx_assassin_burrow")
    if not burrow or Ability.IsHidden(burrow) or Ability.IsInAbilityPhase(burrow) then return end
    if not Ability.IsCastable(burrow, NPC.GetMana(me)) then return end
    if NPC.IsStunned(me) or NPC.IsSilenced(me) or NPC.IsChannellingAbility(me) then return end
    if UI.vendetta:Get() and NPC.HasModifier(me, VENDETTA) then return end

    local now = GameRules.GetGameTime()
    if now - last_cast < 0.5 then return end

    if ShouldBurrow(me, now, now - last_user_order) then
        Ability.CastNoTarget(burrow, false, false, true)
        last_cast = now
    end
end

function script.OnPrepareUnitOrders(data)
    local me = Heroes.GetLocal()
    if me and data and data.npc == me then
        local ab = data.ability
        if not ab or Ability.GetName(ab) ~= "nyx_assassin_burrow" then
            last_user_order = GameRules.GetGameTime()
        end
    end
    return true
end

return script