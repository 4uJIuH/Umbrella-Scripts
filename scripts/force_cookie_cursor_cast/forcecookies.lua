local cursorCaster = {}

--#region UI
local tab = Menu.Create("Miscellaneous", "In Game", "Использование по курсору")
tab:Icon("\u{f245}") 

local group = tab:Create("Main"):Create("Использование по курсору")

local ui = {}
ui.global_switch = group:Switch("Включить скрипт", true, "\u{f00c}")
ui.force_switch = group:Switch("Force Staff / Hurricane Pike", true)
ui.cookie_switch = group:Switch("Snapfire: Firesnap Cookie", true)
--#endregion UI

--#region Vars
local targetAbilities = {
    ["item_force_staff"] = "force",
    ["item_hurricane_pike"] = "force",
    ["snapfire_firesnap_cookie"] = "cookie"
}

local pendingCast = false
local pendingAbility = nil
local pendingTimeout = 0.0
local pendingTargetPos = Vector(0, 0, 0)
--#endregion Vars

--#region Helpers
local function IsEntityValid(ent)
    return ent ~= nil and type(ent) ~= "number" and not Entity.IsDormant(ent)
end

local function GetFlatDirection(from, to, defaultDir)
    if not from or not to then return defaultDir end
    local dir = Vector(to.x - from.x, to.y - from.y, 0)
    if dir:Length2D() < 1 then return defaultDir end 
    return dir:Normalized()
end

local function GetFlatForward(rotation)
    if not rotation then return Vector(0,0,0) end
    local fwd = rotation:GetForward()
    if not fwd then return Vector(0,0,0) end
    return Vector(fwd.x, fwd.y, 0):Normalized()
end

local function IsChanneling(npc)
    if not IsEntityValid(npc) then return false end
    if NPC.IsChannellingAbility(npc) then return true end
    if NPC.HasModifier(npc, "modifier_teleporting") then return true end
    return false
end
--#endregion

--#region Core Internal Logic
local function SafePrepareUnitOrders(orders)
    if not ui.global_switch:Get() or not orders or not orders.ability or not IsEntityValid(orders.ability) then
        return true
    end

    local me = Heroes.GetLocal()
    if not me or not IsEntityValid(me) or not Entity.IsAlive(me) then return true end

    local abilityName = Ability.GetName(orders.ability)
    if not abilityName then return true end

    local abilityGroup = targetAbilities[abilityName]
    if not abilityGroup then return true end

    if abilityGroup == "force" and not ui.force_switch:Get() then return true end
    if abilityGroup == "cookie" and not ui.cookie_switch:Get() then return true end

    local isSelfCast = false
    if orders.target and IsEntityValid(orders.target) then
        isSelfCast = (orders.target == me) or (orders.target == Entity.GetIndex(me))
    end

    if isSelfCast then
        if pendingCast and orders.ability == pendingAbility then return true end
        if not Ability.IsCastable(orders.ability, NPC.GetMana(me)) then return true end
        if IsChanneling(me) then return false end

        pendingCast = true
        pendingAbility = orders.ability
        pendingTimeout = GlobalVars.GetCurTime() + 0.5 
        
        local cursor = Input.GetWorldCursorPos()
        pendingTargetPos = cursor

        local player = Players.GetLocal()
        if player and cursor then
            if not NPC.IsStunned(me) then
                -- Добавляем начальный STOP, чтобы сбросить текущий вектор движения
                Player.PrepareUnitOrders(
                    player,
                    Enum.UnitOrder.DOTA_UNIT_ORDER_STOP,
                    nil, Vector(0, 0, 0), nil,
                    Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_HERO_ONLY,
                    me,
                    false
                )
                
                Player.PrepareUnitOrders(
                    player,
                    Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_DIRECTION,
                    nil, cursor, nil,
                    Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_HERO_ONLY,
                    me,
                    false
                )
            end
        end
        return false
    end

    return true
end
--#endregion

--#region Callbacks
cursorCaster.OnPrepareUnitOrders = function(orders)
    local status, result = pcall(SafePrepareUnitOrders, orders)
    if not status then
        pendingCast = false
        pendingAbility = nil
        return true
    end
    return result
end

cursorCaster.OnUpdate = function()
    if not ui.global_switch:Get() or not pendingCast or not pendingAbility then return end

    local me = Heroes.GetLocal()
    if not me or not IsEntityValid(me) or not Entity.IsAlive(me) or not IsEntityValid(pendingAbility) then
        pendingCast = false
        pendingAbility = nil
        return
    end

    if NPC.IsStunned(me) then
        pendingTimeout = GlobalVars.GetCurTime() + 0.5
        return
    end

    if IsChanneling(me) or GlobalVars.GetCurTime() > pendingTimeout then
        pendingCast = false
        pendingAbility = nil
        return
    end

    local playerPos = Entity.GetAbsOrigin(me)
    local rotation = Entity.GetRotation(me)
    local player = Players.GetLocal()
    local mousePos = Input.GetWorldCursorPos()
    
    if not playerPos or not rotation or not mousePos or not player then return end

    if (mousePos - pendingTargetPos):Length2D() > 30 then
        pendingTargetPos = mousePos
        Player.PrepareUnitOrders(
            player,
            Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_DIRECTION,
            nil, pendingTargetPos, nil,
            Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_HERO_ONLY,
            me,
            false
        )
    end

    local forwardDir = GetFlatForward(rotation)
    local targetDir = GetFlatDirection(playerPos, pendingTargetPos, forwardDir)
    local dot2D = forwardDir:Dot2D(targetDir)

    -- Порог 0.96 (около 16 градусов), чтобы поймать момент до того, как движок начнет шагать вперед
    if dot2D > 0.96 then
        -- Жестко гасим инерцию шага
        Player.PrepareUnitOrders(
            player,
            Enum.UnitOrder.DOTA_UNIT_ORDER_STOP,
            nil, Vector(0, 0, 0), nil,
            Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_HERO_ONLY,
            me,
            false 
        )
        
        -- Выдаем каст строго в очередь (true), чтобы он сработал в том же тике, без задержек
        Player.PrepareUnitOrders(
            player,
            Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TARGET,
            me, Vector(0, 0, 0), pendingAbility,
            Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_HERO_ONLY,
            me,
            true 
        )
        
        pendingCast = false
        pendingAbility = nil
    end
end
--#endregion

return cursorCaster