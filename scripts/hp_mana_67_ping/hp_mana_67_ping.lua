local VERSION = "1.0.1"

local script = {}

local JSON = require("assets.JSON")

local localization = qLocalization.new({
    en = {
        ui = {
            tab = "HP/Mana value ping",
            settings = "Settings",
            enable = "Enable",
            key = "Track HP/Mana values until 67 appears",
            percentKey = "Track HP/Mana until 67%",
            healthMessage = "Custom HP message",
            manaMessage = "Custom mana message",
            healthPrefix = "I have ",
            healthSuffix = " HP!",
            manaPrefix = "I have ",
            manaSuffix = " mana!",
        },
    },
    ru = {
        ui = {
            tab = "Пинг значения HP/маны",
            settings = "Настройки",
            enable = "Включить",
            key = "Отслеживать значения HP/маны до появления 67",
            percentKey = "Отслеживать HP/ману до появления 67%",
            healthMessage = "Своё сообщение о HP",
            manaMessage = "Своё сообщение о мане",
            healthPrefix = "У меня ",
            healthSuffix = " хп!",
            manaPrefix = "У меня ",
            manaSuffix = " маны!",
        },
    },
})

local Menu = localization.WrapLibrary(Menu)
local tab = Menu.Create("General", "Main", "HP/Mana 67 Ping")
tab:Icon("\u{f0c1}")

local settings = tab:Create("ui.settings"):Create("Main")
local enabled = settings:Switch("ui.enable", true)
local key = settings:Bind("ui.key", Enum.ButtonCode.KEY_NONE, "\u{f0c1}")
local percentKey = settings:Bind("ui.percentKey", Enum.ButtonCode.KEY_NONE, "\u{f0c1}")
local healthMessage = settings:Input("ui.healthMessage", "")
local manaMessage = settings:Input("ui.manaMessage", "")

local waiting = false
local waitingForPercent = false

local function Has67(number)
    return number >= 67
        and number <= 6767
        and number % 100 == 67
end

local function DisplayValue(value)
    return math.floor(tonumber(value) + 0.5)
end

local function BuildMessage(input, value, prefixKey, suffixKey)
    local custom = input:Get()
    if type(custom) == "string" and custom ~= "" then
        return custom
    end

    return localization.Get(prefixKey) .. value .. localization.Get(suffixKey)
end

local function Find67Value(value)
    value = tonumber(value)
    if value == nil then return nil end

    local current = DisplayValue(value)
    if Has67(current) then return current end
    return nil
end

local function Is67Percent(value, maxValue)
    value = tonumber(value)
    maxValue = tonumber(maxValue)
    if value == nil or maxValue == nil or maxValue <= 0 then return false end
    return math.floor((value / maxValue) * 100 + 0.5) == 67
end

local function SendChatMessage(message)
    local safeMessage = string.gsub(message, '"', '\\"')
    Engine.ExecuteCommand('say "' .. safeMessage .. '"')
end

local function SendStatusMessage()
    local hero = Heroes.GetLocal()
    if not hero then return end

    NetChannel.SendNetMessage(
        "CDOTAClientMsg_HPManaAlert",
        JSON:encode({
            target_entindex = Entity.GetIndex(hero),
            show_raw_values = false,
        })
    )
end

function script.OnUpdate()
    if not enabled:Get() then return end

    local hero = Heroes.GetLocal()
    if not hero then return end

    if key:IsPressed() then
        waiting = true
    end

    if percentKey:IsPressed() then
        waitingForPercent = true
    end

    if not waiting and not waitingForPercent then return end

    local health = Entity.GetHealth(hero)
    local maxHealth = Entity.GetMaxHealth(hero)
    local mana = NPC.GetMana(hero)
    local maxMana = NPC.GetMaxMana(hero)
    if waitingForPercent and (Is67Percent(health, maxHealth) or Is67Percent(mana, maxMana)) then
        SendStatusMessage()
        waitingForPercent = false
    end

    if not waiting then return end

    local health67 = Find67Value(health)
    local mana67 = Find67Value(mana)

    if health67 ~= nil then
        local value = health67
        local message = BuildMessage(
            healthMessage,
            value,
            "ui.healthPrefix",
            "ui.healthSuffix"
        )
        SendChatMessage(message)
        waiting = false
    elseif mana67 ~= nil then
        local value = mana67
        local message = BuildMessage(
            manaMessage,
            value,
            "ui.manaPrefix",
            "ui.manaSuffix"
        )
        SendChatMessage(message)
        waiting = false
    end
end

function script.OnGameEnd()
    waiting = false
    waitingForPercent = false
end

return script
