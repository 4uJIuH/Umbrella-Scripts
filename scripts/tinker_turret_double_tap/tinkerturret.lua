-- tinker_deploy_turrets_doubletap.lua
local ABILITY_INDEX   = 2
local DOUBLE_TAP_TIME = 0.4
local HERO_NAME       = "npc_dota_hero_tinker"
local BOOST_DISTANCE  = 300  -- how far ahead in the mouse direction to cast

local lastTapTime   = 0
local showIndicator = false

return {
    OnKeyEvent = function(data)
        if data.key   ~= Enum.ButtonCode.KEY_E             then return true end
        if data.event ~= Enum.EKeyEvent.EKeyEvent_KEY_DOWN then return true end

        local hero = Heroes.GetLocal()
        if not hero or not Entity.IsAlive(hero) then return true end

        if NPC.GetUnitName(hero) ~= HERO_NAME then return true end

        local now     = GlobalVars.GetCurTime()
        local elapsed = now - lastTapTime

        if elapsed > DOUBLE_TAP_TIME then
            lastTapTime   = now
            showIndicator = true
            return true
        end

        lastTapTime   = 0
        showIndicator = false

        local ability = NPC.GetAbilityByIndex(hero, ABILITY_INDEX)
        if not ability then return true end
        if Ability.GetLevel(ability) < 1 then return true end
        if Ability.GetCooldown(ability) > 0 then return true end
        if not Ability.IsOwnersManaEnough(ability) then return true end

        -- Compute a cast position offset toward the mouse cursor
        local heroPos   = Entity.GetAbsOrigin(hero)
        local mousePos  = Input.GetWorldCursorPos()

        local dx = mousePos.x - heroPos.x
        local dy = mousePos.y - heroPos.y
        local len = math.sqrt(dx * dx + dy * dy)

        local castPos
        if len > 1 then
            -- Normalize and scale by BOOST_DISTANCE
            castPos = Vector(
                heroPos.x + (dx / len) * BOOST_DISTANCE,
                heroPos.y + (dy / len) * BOOST_DISTANCE,
                heroPos.z
            )
        else
            -- Cursor is basically on top of the hero, fall back to self-cast
            castPos = heroPos
        end

        Ability.CastPosition(ability, castPos, false, false, true)
        return false
    end,

    OnUpdate = function()
        if not showIndicator then return end
        if (GlobalVars.GetCurTime() - lastTapTime) > DOUBLE_TAP_TIME then
            showIndicator = false
        end
    end,

    OnDraw = function()
        if not showIndicator then return end

        local hero = Heroes.GetLocal()
        if not hero or not Entity.IsAlive(hero) then return end

        local heroPos  = Entity.GetAbsOrigin(hero)
        local mousePos = Input.GetWorldCursorPos()

        -- Draw the directional arrow indicator
        local heroScreen,  heroVis  = Render.WorldToScreen(heroPos)
        local mouseScreen, mouseVis = Render.WorldToScreen(mousePos)

        if heroVis then
            Render.Circle(heroScreen, 40, Color(0, 255, 255, 255), 2.0)
            Render.FilledCircle(heroScreen, 38, Color(0, 255, 255, 60))
            Render.FilledCircle(heroScreen, 5, Color(255, 255, 255, 255))
        end

        -- Draw a line toward the mouse so you can see the boost direction
        if heroVis and mouseVis then
            Render.Line(heroScreen, mouseScreen, Color(0, 255, 255, 180), 1.5)
            Render.FilledCircle(mouseScreen, 6, Color(0, 255, 255, 200))
        end
    end
}