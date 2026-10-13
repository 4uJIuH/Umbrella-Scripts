-- made by m0rc1

local VERSION = "1.0.0"
local script = {}

Menu.Create("Changer", "Main", "Погода"):Icon("\u{f0c2}")

local group = Menu.Create("Changer", "Main", "Погода", "Main", "Погода")

local weather_list = {
    "По умолчанию",
    "1. Зима",
    "2. Дождь",
    "3. Сакура",
    "4. Болото",
    "5. Осень",
    "6. Пустыня",
    "7. Весна",
    "8. Ад",
    "9. Северное сияние"
}

local ui_weather = nil
if group.Combo then
    ui_weather = group:Combo("Эффект погоды", weather_list, 0)
elseif group.ComboBox then
    ui_weather = group:ComboBox("Эффект погоды", weather_list, 0)
end

local cvar_weather = ConVar.Find("cl_weather")
local last_weather_val = -1

function script.OnUpdate()
    if not Engine.IsInGame() then return end

    if cvar_weather and ui_weather then
        local current_weather = ui_weather:Get()
        if current_weather ~= last_weather_val then
            ConVar.SetInt(cvar_weather, current_weather)
            last_weather_val = current_weather
        end
    end
end

return script
