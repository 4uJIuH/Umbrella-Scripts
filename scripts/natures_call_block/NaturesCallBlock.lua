---@diagnostic disable: undefined-global, param-type-mismatch, inject-field

local script                          = {}

--#region Localized API
local Entity_IsAlive                  = Entity.IsAlive
local Entity_IsDormant                = Entity.IsDormant
local Entity_GetTeamNum               = Entity.GetTeamNum
local Entity_GetAbsOrigin             = Entity.GetAbsOrigin
local Entity_GetRotation              = Entity.GetRotation

local NPC_GetAbility                  = NPC.GetAbility
local NPC_GetMana                     = NPC.GetMana

local Ability_GetName                 = Ability.GetName
local Ability_GetCooldown             = Ability.GetCooldown
local Ability_GetManaCost             = Ability.GetManaCost
local Ability_CastPosition            = Ability.CastPosition

local GameRules_GetGameTime           = GameRules.GetGameTime
local Heroes_GetLocal                 = Heroes.GetLocal
local Input_IsKeyDown                 = Input.IsKeyDown
local Input_GetNearestHeroToCursor    = Input.GetNearestHeroToCursor
--#endregion

local cfg                             = {}

local State                           = {
    step          = "IDLE",
    targetNPC     = nil,
    targetPos     = nil,
    lastCastTime  = 0,
    isScriptCast  = false,
}

--#region Menu
local function InitMenu()
    if not Menu.Create then return end

    local tab = Menu.Create("Heroes", "Hero List", "Nature's Prophet")
    if not (tab and tab.Create) then return end

    local section = tab:Create("Nature Call Block")
    if not (section and section.Create) then return end

    local general   = section:Create("Settings")

    cfg.enabled     = general:Switch("Enabled", false, "\u{f00c}")
    cfg.mode        = general:Combo("Nature's Call Mode", {"Automatic", "By Hotkey"}, 0)
    cfg.hotkey      = general:Bind("Cast Hotkey", Enum.ButtonCode.BUTTON_CODE_INVALID)
    cfg.offsetX     = general:Slider("Offset X (Right/Left)", -100, 100, 0)
    cfg.offsetZ     = general:Slider("Offset Z (Forward/Back)", -100, 100, 20)

    local function updateVisibility()
        local isHotkey = (cfg.mode:Get() == 1)
        cfg.hotkey:Visible(isHotkey)
    end
    cfg.mode:SetCallback(updateVisibility, true)
    updateVisibility()
end
--#endregion

--#region Helpers
local function GetTargetPos()
    local target = State.targetNPC
    if target then
        if not Entity_IsAlive(target) or Entity_IsDormant(target) then
            return nil, true
        end
        return Entity_GetAbsOrigin(target), false
    end
    return State.targetPos, false
end
--#endregion

--#region Callbacks
function script.OnPrepareUnitOrders(order)
    if not cfg.enabled:Get() then return true end
    if not order.ability then return true end

    -- If the cast originates from our script, skip it
    if State.isScriptCast then return true end

    if Ability_GetName(order.ability) == "furion_force_of_nature" and cfg.mode:Get() == 0 then
        local myHero = Heroes_GetLocal()
        -- Ignore orders from other controlled units (e.g., illusions)
        -- Rubick (when casting a stolen spell) will successfully pass this check!
        if not myHero or order.npc ~= myHero then return true end

        local orderPos
        if order.order == Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION then
            orderPos = order.position
        elseif order.order == Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TARGET and order.target then
            orderPos = Entity_GetAbsOrigin(order.target)
        end

        if not orderPos then return true end

        local myTeam = Entity_GetTeamNum(myHero)
        local enemy = Input_GetNearestHeroToCursor(myTeam, Enum.TeamType.TEAM_ENEMY)

        if enemy and Entity_IsAlive(enemy) and not Entity_IsDormant(enemy) then
            local enemyPos = Entity_GetAbsOrigin(enemy)

            -- Use the built-in API function; it's faster than Lua math
            -- If we cast Nature's Call within 800 units of the enemy, intercept and center it on them
            if enemyPos:Distance2D(orderPos) < 800 then
                State.targetNPC = enemy
                State.targetPos = nil
                State.step = "CAST_TREANT_NOW"
                return false -- Block the original cast
            end
            -- If the enemy is too far, allow the normal cast
        end
    end

    return true
end

function script.OnUpdate()
    if not cfg.enabled:Get() then
        if State.step ~= "IDLE" then State.step = "IDLE" end
        return
    end

    local myHero = Heroes_GetLocal()
    if not myHero then return end

    local force = NPC_GetAbility(myHero, "furion_force_of_nature")
    if not force then return end

    local opMode = cfg.mode:Get()

    if opMode == 1 then
        local btn1 = cfg.hotkey:Buttons()
        if btn1 ~= Enum.ButtonCode.BUTTON_CODE_INVALID and Input_IsKeyDown(btn1) then
            local now = GameRules_GetGameTime()
            if (now - State.lastCastTime) > 0.3 then
                local myTeam = Entity_GetTeamNum(myHero)
                local enemy = Input_GetNearestHeroToCursor(myTeam, Enum.TeamType.TEAM_ENEMY)
                if enemy and Entity_IsAlive(enemy) and not Entity_IsDormant(enemy) then
                    State.targetNPC = enemy
                    State.targetPos = nil
                    State.step = "CAST_TREANT_NOW"
                end
            end
        end
    end

    if State.step == "CAST_TREANT_NOW" then
        if Ability_GetCooldown(force) > 0.0 or Ability_GetManaCost(force) > NPC_GetMana(myHero) then
            State.step = "IDLE"
            return
        end

        local pos, gone = GetTargetPos()
        if gone or not pos then
            State.step = "IDLE"
            return
        end

        local castPos = Vector(pos.x, pos.y, pos.z)
        local offX = cfg.offsetX:Get()
        local offZ = cfg.offsetZ:Get()

        if offX ~= 0 or offZ ~= 0 then
            local targetRot = Entity_GetRotation(State.targetNPC or myHero)

            local fwdPos = pos:MoveForward(targetRot, 1)
            -- Determine direction and normalize the vector
            local fwdDir = (fwdPos - pos):Normalized()
            local rightDir = Vector(fwdDir.y, -fwdDir.x, 0)

            -- Use operator overloading for Umbrella vectors
            castPos = castPos + (fwdDir * offZ) + (rightDir * offX)
        end

        State.isScriptCast = true
        Ability_CastPosition(force, castPos, false, false, true)
        State.isScriptCast = false

        State.lastCastTime = GameRules_GetGameTime()
        State.step = "IDLE"
    end
end
--#endregion

InitMenu()

return script
