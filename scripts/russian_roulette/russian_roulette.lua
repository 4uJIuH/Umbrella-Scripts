local VERSION = "1.0.0"
local Roulette = {}

--#region Меню Umbrella
local tab = Menu.Create("General", "Fun", "Russian Roulette")
local group = tab:Create("Roulette Settings")

local ui = {
    enabled = group:Switch("Enable Roulette", true),
    trigger_button = group:Button("Спустить курок (Крутить)"),
    trigger_key = group:KeyBind("Trigger Hotkey", Enum.ButtonCode.KEY_NONE),
    bullets_count = group:Slider("Пуль в барабане (из 6)", 1, 5, 1),
    auto_smash = group:Switch("Разбивать шмотку (атаковать после дропа)", true),
    show_hud = group:Switch("Отображать барабан на экране", true),
    hud_x = group:Slider("HUD X", 50, 3840, 1500),
    hud_y = group:Slider("HUD Y", 50, 2160, 250)
}
--#endregion

-- Константы и шрифты
local font_title = Render.LoadFont("Arial", 15, 700)
local font_sub = Render.LoadFont("Arial", 12, 500)

local ORDER_DROP = Enum.UnitOrder.DOTA_UNIT_ORDER_DROP_ITEM or 13
local ORDER_ATTACK = Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET or 4
local ORDER_ISSUER = Enum.PlayerOrderIssuer and Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY or 3

-- Состояние
local last_result_text = "Готов к выстрелу..."
local last_result_color = Color(200, 200, 200, 255)
local key_was_down = false
local pending_smash_time = 0

-- Безопасная отрисовка прямоугольников
local function draw_rect_filled(p1, p2, col, round)
    if Render.BoxFilled then Render.BoxFilled(p1, p2, col, round or 4)
    elseif Render.FilledRect then Render.FilledRect(p1, p2, col, round or 4)
    elseif Render.RectFilled then Render.RectFilled(p1, p2, col, round or 4) end
end

local function draw_rect_outline(p1, p2, col, round)
    if Render.Box then Render.Box(p1, p2, col, round or 4)
    elseif Render.Rect then Render.Rect(p1, p2, col, round or 4) end
end

-- Основная логика выстрела
local function pull_trigger()
    local my_hero = Heroes.GetLocal()
    if not my_hero or not Entity.IsAlive(my_hero) then
        last_result_text = "Герой мертв или не найден"
        last_result_color = Color(255, 100, 100, 255)
        return
    end

    local bullets = ui.bullets_count:Get()
    local roll = math.random(1, 6)

    -- Проверка: попала ли пуля (1..bullets = выстрел, остальное = щелчок)
    if roll > bullets then
        -- ЩЕЛЧОК (Повезло)
        last_result_text = " *ЩЕЛЧОК* — Пусто! Ты выжил."
        last_result_color = Color(80, 255, 120, 255)

        -- Звук щелчка курка
        Audio.PlayRaw("sounds/ui/menu_click_01.vsnd_c", 0.9)
        return
    end

    -- ВЫСТРЕЛ (БАХ!)
    -- Собираем все непустые слоты из основного инвентаря (слоты 0-5)
    local items = {}
    for i = 0, 5 do
        local item = NPC.GetItemByIndex(my_hero, i)
        if item then
            local name = Ability.GetName(item)
            -- Не дропаем свитки телепорта и неразрушаемые квестовые предметы
            if name ~= "item_tpscroll" and name ~= "item_aegis" then
                table.insert(items, { item = item, name = name })
            end
        end
    end

    if #items == 0 then
        last_result_text = " 💥 БАХ! Но инвентарь пуст."
        last_result_color = Color(255, 180, 0, 255)
        return
    end

    -- Выбираем случайный предмет
    local selected = items[math.random(1, #items)]
    local hero_pos = Entity.GetAbsOrigin(my_hero)
    local player = Players.GetLocal()

    -- Дропаем предмет на землю под ноги
    Player.PrepareUnitOrders(player, ORDER_DROP, nil, hero_pos, selected.item, ORDER_ISSUER, my_hero)

    -- Эффект выстрела/крови на герое
    local p = Particle.Create("particles/units/heroes/hero_sniper/sniper_assassinate_impact_blood.vpcf", Enum.ParticleAttachment.PATTACH_ABSORIGIN, my_hero)
    Particle.SetControlPoint(p, 0, hero_pos)

    -- Звук выстрела
    Audio.PlayRaw("sounds/weapons/hero/sniper/assassinate.vsnd_c", 1.0)

    last_result_text = " 💥 БАХ! Выбит: " .. selected.name:gsub("item_", "")
    last_result_color = Color(255, 50, 50, 255)

    -- Если включено авто-уничтожение — заводим таймер на разбивание
    if ui.auto_smash:Get() then
        pending_smash_time = os.clock() + 0.35
    end
end

-- Обработка нажатия кнопки в меню чита
ui.trigger_button:SetCallback(function()
    pull_trigger()
end)

function Roulette.OnUpdate()
    if not ui.enabled:Get() then return end

    -- Проверка бинда клавиши
    local key = ui.trigger_key:Get()
    if key and key ~= Enum.ButtonCode.KEY_NONE then
        local is_down = Input.IsKeyDown(key)
        if is_down and not key_was_down then
            pull_trigger()
        end
        key_was_down = is_down
    end

    -- Логика добивания/разбивания сброшенной шмотки
    if pending_smash_time > 0 and os.clock() >= pending_smash_time then
        pending_smash_time = 0
        local my_hero = Heroes.GetLocal()
        if not my_hero or not Entity.IsAlive(my_hero) then return end

        local hero_pos = Entity.GetAbsOrigin(my_hero)
        local physical_items = PhysicalItems and PhysicalItems.GetAll() or {}

        -- Ищем ближайший упавший предмет рядом с героем
        for _, phys_item in pairs(physical_items) do
            if phys_item then
                local item_pos = Entity.GetAbsOrigin(phys_item)
                local dist = (hero_pos - item_pos):Length2D()
                if dist < 250 then
                    -- Отдаем приказ атаковать и уничтожить предмет
                    local player = Players.GetLocal()
                    Player.PrepareUnitOrders(player, ORDER_ATTACK, phys_item, Vector(), nil, ORDER_ISSUER, my_hero)
                    break
                end
            end
        end
    end
end

function Roulette.OnDraw()
    if not ui.enabled:Get() or not ui.show_hud:Get() then return end

    local x = ui.hud_x:Get()
    local y = ui.hud_y:Get()
    local w, h = 260, 90

    -- Фон плашки
    draw_rect_filled(Vec2(x, y), Vec2(x + w, y + h), Color(16, 16, 20, 235), 6)
    draw_rect_outline(Vec2(x, y), Vec2(x + w, y + h), Color(70, 70, 85, 200), 6)

    -- Заголовок
    Render.Text(font_title, 14, "RUSSIAN ROULETTE", Vec2(x + 12, y + 8), Color(255, 215, 0, 255))

    -- Отрисовка 6 камор револьвера
    local bullets = ui.bullets_count:Get()
    local start_cx = x + 16
    local cy = y + 38
    local radius = 6

    for i = 1, 6 do
        local center = Vec2(start_cx + (i - 1) * 20, cy)
        local is_bullet = (i <= bullets)
        local chamber_col = is_bullet and Color(255, 60, 60, 255) or Color(60, 60, 75, 255)

        -- Круг каморы
        if Render.CircleFilled then
            Render.CircleFilled(center, radius, chamber_col)
        else
            draw_rect_filled(Vec2(center.x - radius, center.y - radius), Vec2(center.x + radius, center.y + radius), chamber_col, radius)
        end
    end

    -- Статус/Исход последнего действия
    Render.Text(font_sub, 12, last_result_text, Vec2(x + 12, y + 60), last_result_color)
end

return Roulette
