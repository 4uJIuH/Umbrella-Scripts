-- Bloodrage AutoCast v1.0.0
-- Author: zвeзdы уnaлu v лужу (Discord: rarimember)

local VERSION = "1.0.0"

local script = {}

local tab = Menu.Create("Scripts", "Scripts", "Bloodrage")
local page = tab:Create("Settings")
local group = page:Create("General")

local ui = {}

ui.enabled = group:Switch("Включить", true)

-- Нормальный Umbrella/UCZone bind:
-- в меню появится поле, где можно назначить любую клавишу.
ui.toggle_bind = group:Bind(
    "Бинд автокаста",
    Enum.ButtonCode.KEY_F
)

ui.only_bloodseeker = group:Switch("Только Bloodseeker", true)
ui.status = group:Switch("Статус работы", true)

-- Отображение бинда в Bind List / Bind Island как toggle.
ui.toggle_bind:Properties("Bloodrage AutoCast", nil, true)

local CONFIG = {
    ABILITY_NAME = "bloodseeker_bloodrage",
    ORDER_THROTTLE = 0.10,
}

local state = {
    last_cast = -math.huge,
    status = "boot",
}

local font = Render.LoadFont("Arial", 0, 500)

local function is_bloodseeker(hero)
    if not hero then
        return false
    end

    return NPC.GetUnitName(hero) == "npc_dota_hero_bloodseeker"
end

function script.OnUpdate()
    local hero = Heroes.GetLocal()

    if not hero then
        state.status = "no hero"
        return
    end

    -- Bind сам хранит toggle-состояние.
    -- Нажатие назначенной клавиши переключает автокаст.
    if ui.toggle_bind:IsToggled() then
        if not ui.enabled:Get() then
            ui.enabled:Set(true)
        end
    else
        if ui.enabled:Get() then
            ui.enabled:Set(false)
        end
    end

    if not ui.enabled:Get() then
        state.status = "off"
        return
    end

    if ui.only_bloodseeker:Get() and not is_bloodseeker(hero) then
        state.status = "not bloodseeker"
        return
    end

    if not Entity.IsAlive(hero) then
        state.status = "dead"
        return
    end

    local ability = NPC.GetAbility(hero, CONFIG.ABILITY_NAME)

    if not ability then
        state.status = "no ability"
        return
    end

    if not Ability.IsReady(ability) then
        state.status = "on cd"
        return
    end

    if not Ability.IsCastable(ability, NPC.GetMana(hero)) then
        state.status = "not castable"
        return
    end

    local now = GameRules.GetGameTime()

    if now - state.last_cast < CONFIG.ORDER_THROTTLE then
        return
    end

    Ability.CastNoTarget(ability)

    state.last_cast = now
    state.status = "active"
end

function script.OnDraw()
    if not ui.status:Get() then
        return
    end

    Render.Text(
        font,
        16,
        "Bloodrage | " .. state.status,
        Vec2(10, 220),
        Color(255, 255, 0, 255)
    )
end

return script