---@diagnostic disable: undefined-global, param-type-mismatch, inject-field
--[[
    Kez Combo Slots
    Панель-конструктор связок для Кеза.

    Скрипт НИЧЕГО НЕ КАСТУЕТ. Скиллы жмёт штатный модуль Кеза от Umbrella
    по своей клавише комбо. Панель только собирает связку и записывает её
    в настройки модуля — состав, порядок и стойку.

    Пути виджетов модуля взяты из gui.json:
        Heroes / Hero List / Kez / Main Settings / Hero Settings /
            Aghanim Combo Abilities / No Aghanim Combo Abilities
            Aghanim Stance / No Aghanim Stance

    Рядом с этими списками в конфиге лежит ключ _internal_order — значит
    модуль уважает очерёдность, и порядок из панели уходит как есть.
]]

local script = {}

--#region ============================== ДАННЫЕ ==============================

local KEZ_PATH <const> = { "Heroes", "Hero List", "Kez", "Main Settings", "Hero Settings" }

local W_AGHS_ABILITIES    <const> = "Aghanim Combo Abilities"
local W_NO_AGHS_ABILITIES <const> = "No Aghanim Combo Abilities"
local W_AGHS_STANCE       <const> = "Aghanim Stance"
local W_NO_AGHS_STANCE    <const> = "No Aghanim Stance"

local ABILITIES <const> = {
    "kez_echo_slash",
    "kez_falcon_rush",
    "kez_grappling_claw",
    "kez_talon_toss",
    "kez_kazurai_katana",
    "kez_shodo_sai",
    "kez_raptor_dance",
    "kez_ravens_veil",
}

local TITLE <const> = {
    kez_echo_slash     = "Echo Slash",
    kez_falcon_rush    = "Falcon Rush",
    kez_grappling_claw = "Grappling Claw",
    kez_talon_toss     = "Talon Toss",
    kez_kazurai_katana = "Kazurai Katana",
    kez_shodo_sai      = "Shodo Sai",
    kez_raptor_dance   = "Raptor Dance",
    kez_ravens_veil    = "Raven's Veil",
}

local ICON_PATH <const> = "panorama/images/spellicons/%s_png.vtex_c"
local STANCES <const> = { "Katana", "Sai" }

local SLOT_COUNT <const> = 5
local MAX_STEPS <const> = 8
local CONFIG_NAME <const> = "kez_combo"

--#endregion

--#region ============================== MENU ==============================

-- Вкладка внутри страницы Кеза, рядом с "Основные настройки" и
-- "Индивидуальная настройка": те лежат по путям Main Settings и
-- Extra Settings, значит третий уровень здесь и есть вкладки страницы.
local tab = Menu.Create("Heroes", "Hero List", "Kez", "Слоты комбо")
tab:Icon("\u{f71c}")

local g_main = tab:Create("Основное")
local g_binds = tab:Create("Клавиши")
local g_view = tab:Create("Панель", 1)

local ui = {}

ui.enable = g_main:Switch("Включить", true, "\u{f00c}")

ui.panel_bind = g_binds:Bind("Открыть панель", Enum.ButtonCode.BUTTON_CODE_INVALID)
ui.slot_binds = {}
for i = 1, SLOT_COUNT do
    ui.slot_binds[i] = g_binds:Bind("Включить слот " .. i, Enum.ButtonCode.BUTTON_CODE_INVALID)
end

ui.scale = g_view:Slider("Масштаб", 60, 200, 100, "%d%%")
ui.bg_alpha = g_view:Slider("Заливка фона", 0, 255, 235, "%d")
ui.block_clicks = g_view:Switch("Не пускать клики в игру", true)

-- Shadow это размытие, оно считается каждый кадр на всю площадь окна
-- и заметно роняет FPS. По умолчанию выключено.
ui.shadow = g_view:Switch("Тень", false)
ui.show_cd = g_view:Switch("Показывать кулдауны", true, "\u{f017}")
ui.cd_rate = g_view:Slider("Обновлять кулдауны раз в, мс", 50, 1000, 200, "%d")

ui.c_bg = g_view:ColorPicker("Фон", Color(16, 18, 23, 255))
ui.c_active = g_view:ColorPicker("Активный слот", Color(226, 74, 62, 255))
ui.c_text = g_view:ColorPicker("Текст", Color(238, 242, 247, 255))
ui.c_dim = g_view:ColorPicker("Текст тусклый", Color(146, 155, 168, 255))

--#endregion

--#region ============================== STATE ==============================

local FONT_BOLD = Render.LoadFont("Tahoma", Enum.FontCreate.FONTFLAG_ANTIALIAS, 700)
local FONT_REG  = Render.LoadFont("Tahoma", Enum.FontCreate.FONTFLAG_ANTIALIAS, 400)

local panel = {
    open = false,
    x = Config.ReadInt(CONFIG_NAME, "x", -1),
    y = Config.ReadInt(CONFIG_NAME, "y", -1),
}

-- слоты: каждый это упорядоченный список имён способностей
local slots = {}
local slot_stance = {}      -- { aghs = 0|1, plain = 0|1 }
local active_slot = 1

local icons = {}
local widget_cache = {}

local mouse = { down = false, was_down = false, x = 0, y = 0 }
local drag = { active = false, dx = 0, dy = 0 }

-- прямоугольники, по которым кликаем: заполняются при отрисовке
local hitboxes = {}

-- кулдауны способностей: имя -> секунды. Обновляем не каждый кадр,
-- иначе перебор способностей героя тянет FPS вниз без всякой пользы.
local cooldowns = {}
local cd_next_scan = 0

--#endregion

--#region ============================== ХРАНЕНИЕ ==============================

local function save_slots()
    for i = 1, SLOT_COUNT do
        Config.WriteString(CONFIG_NAME, "slot" .. i, table.concat(slots[i] or {}, ","))
        Config.WriteInt(CONFIG_NAME, "aghs" .. i, (slot_stance[i] or {}).aghs or 1)
        Config.WriteInt(CONFIG_NAME, "plain" .. i, (slot_stance[i] or {}).plain or 0)
    end
    Config.WriteInt(CONFIG_NAME, "x", math.floor(panel.x))
    Config.WriteInt(CONFIG_NAME, "y", math.floor(panel.y))
end

local function load_slots()
    for i = 1, SLOT_COUNT do
        slots[i] = {}
        local raw = Config.ReadString(CONFIG_NAME, "slot" .. i, "")
        for name in raw:gmatch("[^,]+") do
            if TITLE[name] then slots[i][#slots[i] + 1] = name end
        end
        slot_stance[i] = {
            aghs = Config.ReadInt(CONFIG_NAME, "aghs" .. i, 1),
            plain = Config.ReadInt(CONFIG_NAME, "plain" .. i, 0),
        }
    end
end

load_slots()

--#endregion

--#region ============================== ПРИМЕНЕНИЕ ==============================


local function kez_widget(name)
    if widget_cache[name] ~= nil then return widget_cache[name] or nil end

    local ok, found = pcall(Menu.Find,
        KEZ_PATH[1], KEZ_PATH[2], KEZ_PATH[3], KEZ_PATH[4], KEZ_PATH[5], name)

    -- в конфиге встречаются дубли с пробелом на конце
    if not ok or not found then
        ok, found = pcall(Menu.Find,
            KEZ_PATH[1], KEZ_PATH[2], KEZ_PATH[3], KEZ_PATH[4], KEZ_PATH[5], name .. " ")
    end

    widget_cache[name] = (ok and found) and found or false
    return widget_cache[name] or nil
end

--- Выбранные шаги идут первыми и включёнными, остальные — выключенными.
local function build_items(order)
    local items, used = {}, {}

    for i = 1, #order do
        used[order[i]] = true
        items[#items + 1] = { order[i], ICON_PATH:format(order[i]), true }
    end
    for _, name in ipairs(ABILITIES) do
        if not used[name] then
            items[#items + 1] = { name, ICON_PATH:format(name), false }
        end
    end
    return items, used
end

--[[
    Update перестраивает список и задаёт порядок, но состояние галочек
    берёт из сохранённого конфига виджета, а не из переданных значений —
    поэтому лишние способности оставались включёнными и модуль продолжал
    их жать. Поэтому после Update проходим по каждой явно через Set.
]]
local function push_abilities(widget_name, items, enabled_set)
    local widget = kez_widget(widget_name)
    if not widget then return false end

    local applied = false

    if widget.Update then
        applied = pcall(widget.Update, widget, items, true, true)
    end

    if widget.Set then
        -- сначала пробуем разом: перегрузка Set(enabledItems)
        local list = {}
        for _, name in ipairs(ABILITIES) do
            if enabled_set[name] then list[#list + 1] = name end
        end
        if pcall(widget.Set, widget, list) then applied = true end

        -- затем поимённо: так не остаётся ничего лишнего
        for _, name in ipairs(ABILITIES) do
            if pcall(widget.Set, widget, name, enabled_set[name] and true or false) then
                applied = true
            end
        end
    end

    return applied
end

local function push_stance(widget_name, index)
    local widget = kez_widget(widget_name)
    if widget and widget.Set then pcall(widget.Set, widget, index) end
end

local function apply_slot(slot)
    local order = slots[slot]
    if not order or #order == 0 then
        return
    end

    local items, enabled_set = build_items(order)
    push_abilities(W_AGHS_ABILITIES, items, enabled_set)
    push_abilities(W_NO_AGHS_ABILITIES, items, enabled_set)

    local st = slot_stance[slot] or {}
    push_stance(W_AGHS_STANCE, st.aghs or 1)
    push_stance(W_NO_AGHS_STANCE, st.plain or 0)

    active_slot = slot
end

--#endregion

--#region ============================== ПАНЕЛЬ ==============================

--- Собирает остаток кулдауна по всем способностям Кеза.
--- Скиллы неактивной стойки тоже видны, поэтому их КД читается заранее.
local function refresh_cooldowns()
    local now = os.clock()
    if now < cd_next_scan then return end
    cd_next_scan = now + ui.cd_rate:Get() / 1000.0

    for k in pairs(cooldowns) do cooldowns[k] = nil end

    local me = Heroes.GetLocal()
    if not me then return end

    for i = 0, 30 do
        local ab = NPC.GetAbilityByIndex(me, i)
        if ab then
            local ok, name = pcall(Ability.GetName, ab)
            if ok and TITLE[name] then
                local got, cd = pcall(Ability.GetCooldown, ab)
                cooldowns[name] = (got and type(cd) == "number" and cd > 0) and cd or 0
            end
        end
    end
end

local function icon(name)
    if icons[name] ~= nil then return icons[name] or nil end
    local handle = Render.LoadImage(ICON_PATH:format(name))
    icons[name] = (handle and handle ~= 0) and handle or false
    return icons[name] or nil
end

local function hit(x, y, w, h, action, arg)
    hitboxes[#hitboxes + 1] = { x = x, y = y, w = w, h = h, action = action, arg = arg }
end

local function cursor_in(x, y, w, h)
    return mouse.x >= x and mouse.x <= x + w and mouse.y >= y and mouse.y <= y + h
end

--[[
    Компактная раскладка в духе панели Инвокера.

    Вместо длинной строки из восьми иконок — сетка 4 в ряд, ячейки мельче,
    подписи убраны: их роль играют разделитель и подсветка. Способность,
    уже стоящая в связке, обведена зелёным — видно, что набрано, не глядя
    на нижний ряд.
]]
local COLS <const> = 4

local function draw_panel()
    local s = ui.scale:Get() / 100.0
    local cell = 28 * s
    local gap = 4 * s
    local pad = 7 * s

    local grid_w = cell * COLS + gap * (COLS - 1)
    local w = pad * 2 + grid_w

    local head = 20 * s
    local tabs = 20 * s
    local rows = math.ceil(#ABILITIES / COLS)
    local grid_h = cell * rows + gap * (rows - 1)
    local combo_rows = math.ceil(MAX_STEPS / COLS)
    local combo_h = cell * combo_rows + gap * (combo_rows - 1)
    local divider = 7 * s

    local h = head + tabs + grid_h + divider + combo_h + pad

    local screen = Render.ScreenSize()
    if panel.x < 0 or panel.y < 0 then
        panel.x = (screen.x - w) * 0.5
        panel.y = screen.y * 0.35
    end
    panel.x = math.max(0, math.min(panel.x, screen.x - w))
    panel.y = math.max(0, math.min(panel.y, screen.y - h))

    local x, y = math.floor(panel.x), math.floor(panel.y)

    for i = #hitboxes, 1, -1 do hitboxes[i] = nil end

    local bgc = ui.c_bg:Get()
    local bg = Color(bgc.r, bgc.g, bgc.b, ui.bg_alpha:Get())
    local c_text, c_dim = ui.c_text:Get(), ui.c_dim:Get()
    local accent = ui.c_active:Get()
    local round = 5 * s

    if ui.shadow:Get() then
        Render.Shadow(Vec2(x, y), Vec2(x + w, y + h), Color(0, 0, 0, 150), 14 * s, round)
    end

    Render.FilledRect(Vec2(x, y), Vec2(x + w, y + h), bg, round)
    Render.Rect(Vec2(x, y), Vec2(x + w, y + h), Color(255, 255, 255, 28), round)

    -- шапка: имя активного слота, за неё же таскаем
    Render.FilledRect(Vec2(x, y), Vec2(x + w, y + head), Color(255, 255, 255, 14), round,
        Enum.DrawFlags.RoundCornersTop)

    local title = "Слот " .. active_slot
    Render.Text(FONT_BOLD, 11 * s, title, Vec2(x + pad, y + 4 * s), c_text)

    local steps_text = ("%d/%d"):format(#(slots[active_slot] or {}), MAX_STEPS)
    local st = Render.TextSize(FONT_REG, 10 * s, steps_text)
    Render.Text(FONT_REG, 10 * s, steps_text,
        Vec2(x + w - pad - st.x, y + 5 * s), c_dim)

    hit(x, y, w, head, "drag")

    -- вкладки слотов: мелкие квадраты во всю ширину
    local ty = y + head
    local tw = (grid_w - gap * (SLOT_COUNT - 1)) / SLOT_COUNT
    for i = 1, SLOT_COUNT do
        local tx = x + pad + (tw + gap) * (i - 1)
        local on = (i == active_slot)
        local hover = cursor_in(tx, ty + 2 * s, tw, tabs - 5 * s)

        Render.FilledRect(Vec2(tx, ty + 2 * s), Vec2(tx + tw, ty + tabs - 3 * s),
            on and accent or Color(255, 255, 255, hover and 34 or 18), 3 * s)

        local label = tostring(i)
        local ls = Render.TextSize(FONT_BOLD, 10 * s, label)
        Render.Text(FONT_BOLD, 10 * s, label,
            Vec2(tx + (tw - ls.x) * 0.5, ty + 4 * s),
            on and Color(255, 255, 255) or c_dim)

        hit(tx, ty + 2 * s, tw, tabs - 5 * s, "slot", i)
    end

    -- какие способности уже в связке: подсветим их в верхней сетке
    local order = slots[active_slot] or {}
    local picked = {}
    for i = 1, #order do picked[order[i]] = true end

    -- сетка способностей
    local ay = ty + tabs
    for i, name in ipairs(ABILITIES) do
        local col = (i - 1) % COLS
        local row = math.floor((i - 1) / COLS)
        local ax = x + pad + (cell + gap) * col
        local ay2 = ay + (cell + gap) * row

        local handle = icon(name)
        if handle then
            Render.Image(handle, Vec2(ax, ay2), Vec2(cell, cell), Color(255, 255, 255), 3 * s)
        else
            Render.FilledRect(Vec2(ax, ay2), Vec2(ax + cell, ay2 + cell),
                Color(255, 255, 255, 30), 3 * s)
        end

        if picked[name] then
            Render.Rect(Vec2(ax, ay2), Vec2(ax + cell, ay2 + cell),
                Color(90, 214, 120, 255), 3 * s, Enum.DrawFlags.None, 2 * s)
        elseif cursor_in(ax, ay2, cell, cell) then
            Render.Rect(Vec2(ax, ay2), Vec2(ax + cell, ay2 + cell),
                Color(255, 255, 255, 140), 3 * s, Enum.DrawFlags.None, 1.5 * s)
        end

        hit(ax, ay2, cell, cell, "add", name)
    end

    -- тонкий разделитель вместо подписи
    local dy = ay + grid_h + divider * 0.5
    Render.Line(Vec2(x + pad, dy), Vec2(x + w - pad, dy), Color(255, 255, 255, 26), 1.0)

    -- связка
    local cy = ay + grid_h + divider
    for i = 1, MAX_STEPS do
        local col = (i - 1) % COLS
        local row = math.floor((i - 1) / COLS)
        local sx = x + pad + (cell + gap) * col
        local sy = cy + (cell + gap) * row
        local name = order[i]

        if name then
            local cd = ui.show_cd:Get() and (cooldowns[name] or 0) or 0
            local on_cd = cd > 0
            local tint = on_cd and Color(120, 120, 130, 255) or Color(255, 255, 255)

            local handle = icon(name)
            if handle then
                Render.Image(handle, Vec2(sx, sy), Vec2(cell, cell), tint, 3 * s)
            else
                Render.FilledRect(Vec2(sx, sy), Vec2(sx + cell, sy + cell),
                    Color(255, 255, 255, 30), 3 * s)
            end

            if on_cd then
                Render.FilledRect(Vec2(sx, sy), Vec2(sx + cell, sy + cell),
                    Color(0, 0, 0, 125), 3 * s)

                local cdText = cd >= 10 and tostring(math.floor(cd)) or ("%.1f"):format(cd)
                local cs = Render.TextSize(FONT_BOLD, 12 * s, cdText)
                local tx2 = sx + (cell - cs.x) * 0.5
                local ty2 = sy + (cell - cs.y) * 0.5

                Render.Text(FONT_BOLD, 12 * s, cdText,
                    Vec2(tx2 + 1, ty2 + 1), Color(0, 0, 0, 220))
                Render.Text(FONT_BOLD, 12 * s, cdText, Vec2(tx2, ty2), Color(255, 235, 180))
            end

            -- номер шага в углу, мелко
            Render.Text(FONT_BOLD, 9 * s, tostring(i),
                Vec2(sx + 2 * s, sy + 1 * s), Color(255, 255, 255, 210))

            if cursor_in(sx, sy, cell, cell) then
                Render.Rect(Vec2(sx, sy), Vec2(sx + cell, sy + cell),
                    Color(224, 78, 72, 255), 3 * s, Enum.DrawFlags.None, 2 * s)
            end

            hit(sx, sy, cell, cell, "remove", i)
        else
            Render.FilledRect(Vec2(sx, sy), Vec2(sx + cell, sy + cell),
                Color(255, 255, 255, 10), 3 * s)
        end
    end
end

--- Разбор клика по собранным прямоугольникам.
local function handle_click()
    for i = #hitboxes, 1, -1 do
        local box = hitboxes[i]
        if cursor_in(box.x, box.y, box.w, box.h) then
            if box.action == "drag" then
                drag.active = true
                drag.dx = mouse.x - panel.x
                drag.dy = mouse.y - panel.y

            elseif box.action == "slot" then
                active_slot = box.arg
                apply_slot(active_slot)

            elseif box.action == "add" then
                local order = slots[active_slot]
                if #order < MAX_STEPS then
                    order[#order + 1] = box.arg
                    save_slots()
                    apply_slot(active_slot)
                end

            elseif box.action == "remove" then
                table.remove(slots[active_slot], box.arg)
                save_slots()
                apply_slot(active_slot)
            end
            return true
        end
    end
    return false
end

--#endregion


--#region ============================== CALLBACKS ==============================

function script.OnUpdate()
    if not ui.enable:Get() then return end

    -- открытие панели
    if ui.panel_bind:Get() ~= Enum.ButtonCode.BUTTON_CODE_INVALID then
        local ok, pressed = pcall(ui.panel_bind.IsPressed, ui.panel_bind)
        if ok and pressed then
            panel.open = not panel.open
            if not panel.open then save_slots() end
        end
    end

    -- быстрые клавиши слотов работают и с закрытой панелью
    for i = 1, SLOT_COUNT do
        local bind = ui.slot_binds[i]
        if bind:Get() ~= Enum.ButtonCode.BUTTON_CODE_INVALID then
            local ok, pressed = pcall(bind.IsPressed, bind)
            if ok and pressed then
                apply_slot(i)
                break
            end
        end
    end

    if ui.show_cd:Get() and panel.open then refresh_cooldowns() end

    if not panel.open then
        drag.active = false
        return
    end

    mouse.x, mouse.y = Input.GetCursorPos()
    mouse.was_down = mouse.down
    mouse.down = Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE1)

    if drag.active then
        if mouse.down then
            panel.x = mouse.x - drag.dx
            panel.y = mouse.y - drag.dy
        else
            drag.active = false
            save_slots()
        end
        return
    end

    if mouse.down and not mouse.was_down then
        handle_click()
    end
end

--- Пока курсор над открытой панелью, клик в игру не пускаем.
function script.OnKeyEvent(data)
    if not ui.enable:Get() or not panel.open then return end
    if not ui.block_clicks:Get() then return end
    if not data or data.key ~= Enum.ButtonCode.KEY_MOUSE1 then return end

    for i = 1, #hitboxes do
        local box = hitboxes[i]
        if cursor_in(box.x, box.y, box.w, box.h) then return false end
    end
end

function script.OnDraw()
    if not ui.enable:Get() then return end

    if panel.open then draw_panel() end

end

return script
