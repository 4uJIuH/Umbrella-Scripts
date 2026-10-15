local script = {}

-- Переменные
local config_interval = 16.0
local last_laugh_time = 0

-- Ссылка на переключатель
script.enable_laugh = nil

function script.OnInitialize()
    -- Создаем меню
    script.menu = Menu.Create("Miscellaneous", "In Game", "ULTRASHIZOFRENIA laugh")
    script.menu:Icon("\u{e1a7}")

    script.menu_main = script.menu:Create("Main")
    script.menu_general = script.menu_main:Create("General")

    -- Только один переключатель для смеха
    script.enable_laugh = script.menu_general:Switch("  Auto Laugh (/laugh)", true, "KD 16")
end

function script.OnUpdate()
    -- Если мы не в игре или меню еще не прогрузилось — выходим
    if not Engine.IsInGame() or not script.enable_laugh then
        return
    end

    -- Если смех выключен в меню — выходим
    if not script.enable_laugh:Get() then
        return
    end

    local me = Heroes.GetLocal()
    if not me or not Entity.IsAlive(me) then return end

    local now = os.clock()

    -- Логика смеха
    if now > last_laugh_time + config_interval then
        Engine.ExecuteCommand("say /laugh")
        last_laugh_time = now
        print("[ULTRASHIZOFRENIA] Ха-ха! (Смех отправлен)")
    end
end

-- Инициализация
script.OnInitialize()

return script