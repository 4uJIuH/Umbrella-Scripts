local script = {}

local function clamp(val, min_val, max_val)
    return math.max(min_val, math.min(max_val, val))
end

-- ============================================================================
-- 1. МЕНЮ НАСТРОЕК UMBRELLA
-- ============================================================================
local tab = Menu.Create("General", "Main", "Illusion Tracker Pro")

local sec_gen = tab:Create("General")
local group_gen = sec_gen:Create("Settings")

local ui = {
    enabled = group_gen:Switch("Enable Script", true),
    mode = group_gen:Combo("Display Style", { "Minimalist Dot", "Text Label Only", "Dot + Text Label" }, 2),
    show_duration = group_gen:Switch("Show Lifetime Bar & Timer", true),
    dot_radius = group_gen:Slider("Badge Radius", 6, 25, 13),
    y_offset = group_gen:Slider("Height Offset above HP Bar", 10, 100, 35),
}

local sec_naga = tab:Create("Naga Siren (Q)")
local group_naga_lines = sec_naga:Create("Movement Lines")
local group_naga_colors = sec_naga:Create("Q Illusions Colors")

local ui_naga = {
    draw_lines = group_naga_lines:Switch("Draw Target Lines", true),
    line_thickness = group_naga_lines:Slider("Line Thickness", 1, 4, 2),
    color_default = group_naga_colors:ColorPicker("Unassigned Naga (?)", Color(255, 255, 255, 255)), -- Белый
    color_q5 = group_naga_colors:ColorPicker("Bind [5] Color", Color(255, 255, 255, 255)),            -- Белый
    color_q6 = group_naga_colors:ColorPicker("Bind [6] Color", Color(20, 20, 20, 255)),               -- Черный
    color_q7 = group_naga_colors:ColorPicker("Bind [7] Color", Color(255, 105, 180, 255)),           -- Розовый
    color_q8 = group_naga_colors:ColorPicker("Bind [8] Color", Color(255, 30, 30, 255)),              -- Красный
}

local sec_manta = tab:Create("Manta Style")
local group_manta = sec_manta:Create("Manta Illusions Colors")

local ui_manta = {
    color_m_default = group_manta:ColorPicker("Unassigned Manta (M)", Color(0, 200, 255, 255)),     -- Голубой
    color_m1 = group_manta:ColorPicker("Manta [T]", Color(0, 255, 255, 255)),                      -- Бирюзовый
    color_m2 = group_manta:ColorPicker("Manta [Y]", Color(255, 140, 0, 255)),                      -- Оранжевый
}

local font = nil
local target_positions = {}
local assigned_q_slots = {}
local assigned_manta_slots = {}
local illusion_types = {}
local spawn_tracker = {}

-- ============================================================================
-- 2. ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
-- ============================================================================
local function GetEntIndex(u)
    if not u then return nil end
    if type(u) == "number" then return u end
    if Entity and Entity.GetIndex then
        local ok, res = pcall(Entity.GetIndex, u)
        if ok and res then return res end
    end
    return nil
end

local function IsMyIllusion(npc, my_hero)
    if not npc or not my_hero then return false end
    local owner = Entity.GetOwner(npc)
    if not owner then return false end

    local my_player = Entity.GetOwner(my_hero)
    if Entity.IsPlayer(owner) then
        return owner == my_player
    elseif Entity.IsNPC(owner) then
        return (owner == my_hero) or (Entity.GetOwner(owner) == my_player)
    end
    return false
end

local function IsUnitSelected(npc)
    if not npc then return false end
    if Entity and Entity.IsSelected then
        local ok, res = pcall(Entity.IsSelected, npc)
        if ok and res then return res end
    end
    local lp = Players and Players.GetLocal and Players.GetLocal()
    if lp and Player and Player.GetSelectedUnits then
        local ok, units = pcall(Player.GetSelectedUnits, lp)
        if ok and type(units) == "table" then
            local idx = GetEntIndex(npc)
            for _, u in pairs(units) do
                if GetEntIndex(u) == idx then return true end
            end
        end
    end
    return false
end

-- ============================================================================
-- 3. ПЕРЕХВАТ ПРИКАЗОВ (ЛЮБЫЕ КОМАНДЫ)
-- ============================================================================
function script.OnPrepareUnitOrders(order)
    pcall(function()
        if not ui.enabled:Get() or not order then return end

        local my_hero = Heroes.GetLocal()
        if not my_hero then return end

        local ordered_units = {}
        if order.units and type(order.units) == "table" then
            for _, u in pairs(order.units) do
                local idx = GetEntIndex(u)
                if idx then table.insert(ordered_units, idx) end
            end
        elseif order.npc then
            local idx = GetEntIndex(order.npc)
            if idx then table.insert(ordered_units, idx) end
        end

        local target_pos = nil
        if order.position and type(order.position) == "userdata" then
            target_pos = order.position
        elseif order.target and type(order.target) == "number" then
            target_pos = Entity.GetAbsOrigin(order.target)
        end

        if target_pos then
            for _, idx in ipairs(ordered_units) do
                target_positions[idx] = target_pos
            end
        end

        -- Проверка нажатой клавиши в момент любого приказа
        local k5 = Input.IsKeyDown(Enum.ButtonCode.KEY_5)
        local k6 = Input.IsKeyDown(Enum.ButtonCode.KEY_6)
        local k7 = Input.IsKeyDown(Enum.ButtonCode.KEY_7)
        local k8 = Input.IsKeyDown(Enum.ButtonCode.KEY_8)
        local kT = Input.IsKeyDown(Enum.ButtonCode.KEY_T)
        local kY = Input.IsKeyDown(Enum.ButtonCode.KEY_Y)

        for _, idx in ipairs(ordered_units) do
            local ent = Entity.Get(idx)
            if ent and NPC.IsIllusion(ent) and IsMyIllusion(ent, my_hero) then
                local itype = illusion_types[idx] or "naga_q"
                if itype == "naga_q" then
                    if k5 then assigned_q_slots[idx] = 5 end
                    if k6 then assigned_q_slots[idx] = 6 end
                    if k7 then assigned_q_slots[idx] = 7 end
                    if k8 then assigned_q_slots[idx] = 8 end
                elseif itype == "manta" then
                    if kT then assigned_manta_slots[idx] = "T" end
                    if kY then assigned_manta_slots[idx] = "Y" end
                end
            end
        end
    end)
end

script.OnUnitOrder = script.OnPrepareUnitOrders

-- ============================================================================
-- 4. ОСНОВНОЙ ЦИКЛ ОБРАБОТКИ И ОТРИСОВКИ
-- ============================================================================
function script.OnDraw()
    pcall(function()
        if not ui.enabled:Get() then return end

        if not font then
            font = Render.LoadFont("Arial", 16)
        end

        local my_hero = Heroes.GetLocal()
        if not my_hero or not Entity.IsAlive(my_hero) then return end

        local now_tick = math.floor(GameRules.GetGameTime() * 10)
        local npcs = NPCs.GetAll()
        local active_map = {}

        -- 1. Сбор активных иллюзий и авто-детекция типа (Спавн-группы)
        for _, npc in pairs(npcs) do
            if npc and NPC.IsIllusion(npc) and Entity.IsAlive(npc) and not Entity.IsDormant(npc) then
                if IsMyIllusion(npc, my_hero) then
                    local idx = GetEntIndex(npc)
                    if idx then
                        active_map[idx] = true

                        if not illusion_types[idx] then
                            spawn_tracker[now_tick] = spawn_tracker[now_tick] or {}
                            table.insert(spawn_tracker[now_tick], idx)
                        end
                    end
                end
            end
        end

        -- Классификация иллюзий по размерам группы спавна
        for t, idx_list in pairs(spawn_tracker) do
            local count = #idx_list
            local detected_type = "naga_q"
            if count == 2 then
                detected_type = "manta"
            elseif count >= 3 then
                detected_type = "naga_q"
            end

            for _, idx in ipairs(idx_list) do
                if not illusion_types[idx] then
                    illusion_types[idx] = detected_type
                end
            end
            spawn_tracker[t] = nil
        end

        -- 2. Очистка dead/despawned
        for idx in pairs(illusion_types) do
            if not active_map[idx] then
                illusion_types[idx] = nil
                assigned_q_slots[idx] = nil
                assigned_manta_slots[idx] = nil
                target_positions[idx] = nil
            end
        end

        -- 3. МГНОВЕННОЕ НАЗНАЧЕНИЕ ПО НАЖАТИЮ КЛАВИШИ (БЕЗ КЛИКОВ И ПРИКАЗОВ)
        local k5 = Input.IsKeyDown(Enum.ButtonCode.KEY_5)
        local k6 = Input.IsKeyDown(Enum.ButtonCode.KEY_6)
        local k7 = Input.IsKeyDown(Enum.ButtonCode.KEY_7)
        local k8 = Input.IsKeyDown(Enum.ButtonCode.KEY_8)
        local kT = Input.IsKeyDown(Enum.ButtonCode.KEY_T)
        local kY = Input.IsKeyDown(Enum.ButtonCode.KEY_Y)

        if k5 or k6 or k7 or k8 or kT or kY then
            for _, npc in pairs(npcs) do
                if npc and NPC.IsIllusion(npc) and Entity.IsAlive(npc) and not Entity.IsDormant(npc) then
                    if IsMyIllusion(npc, my_hero) and IsUnitSelected(npc) then
                        local idx = GetEntIndex(npc)
                        local itype = illusion_types[idx] or "naga_q"

                        if itype == "naga_q" then
                            if k5 then assigned_q_slots[idx] = 5 end
                            if k6 then assigned_q_slots[idx] = 6 end
                            if k7 then assigned_q_slots[idx] = 7 end
                            if k8 then assigned_q_slots[idx] = 8 end
                        elseif itype == "manta" then
                            if kT then assigned_manta_slots[idx] = "T" end
                            if kY then assigned_manta_slots[idx] = "Y" end
                        end
                    end
                end
            end
        end

        -- 4. Отрисовка
        for _, npc in pairs(npcs) do
            if npc and NPC.IsIllusion(npc) and Entity.IsAlive(npc) and not Entity.IsDormant(npc) then
                if IsMyIllusion(npc, my_hero) then
                    local idx = GetEntIndex(npc)
                    local itype = illusion_types[idx] or "naga_q"
                    local color, label = nil, ""

                    if itype == "naga_q" then
                        local slot = assigned_q_slots[idx]
                        if slot == 5 then color, label = ui_naga.color_q5:Get(), "5"
                        elseif slot == 6 then color, label = ui_naga.color_q6:Get(), "6"
                        elseif slot == 7 then color, label = ui_naga.color_q7:Get(), "7"
                        elseif slot == 8 then color, label = ui_naga.color_q8:Get(), "8"
                        else color, label = ui_naga.color_default:Get(), "?" end
                    elseif itype == "manta" then
                        local slot = assigned_manta_slots[idx]
                        if slot == "T" then color, label = ui_manta.color_m1:Get(), "T"
                        elseif slot == "Y" then color, label = ui_manta.color_m2:Get(), "Y"
                        else color, label = ui_manta.color_m_default:Get(), "M" end
                    end

                    if color then
                        local origin = Entity.GetAbsOrigin(npc)
                        local hp_offset = NPC.GetHealthBarOffset(npc)
                        local world_pos = origin + Vector(0, 0, hp_offset + ui.y_offset:Get())
                        local screen_pos, is_visible = Render.WorldToScreen(world_pos)

                        -- Отрисовка линий приказа
                        if ui_naga.draw_lines:Get() and idx then
                            local target_pos = target_positions[idx]
                            if target_pos then
                                local dist = (origin - target_pos):Length2D()
                                if dist > 60 then
                                    local start_scr, v1 = Render.WorldToScreen(origin)
                                    local end_scr, v2 = Render.WorldToScreen(target_pos)
                                    if v1 and v2 and start_scr and end_scr then
                                        Render.Line(start_scr, end_scr, color, ui_naga.line_thickness:Get())
                                        Render.Circle(end_scr, 5, color, 1.5)
                                    end
                                else
                                    target_positions[idx] = nil
                                end
                            end
                        end

                        -- Отрисовка значка и текста
                        if is_visible and screen_pos then
                            local mode = ui.mode:Get()
                            local radius = ui.dot_radius:Get()

                            -- Определение зрительной яркости фона (Luminance)
                            local brightness = (color.r * 299 + color.g * 587 + color.b * 114) / 1000
                            local is_dark = brightness < 140
                            local text_col = is_dark and Color(255, 255, 255, 255) or Color(0, 0, 0, 255)
                            local stroke_col = is_dark and Color(0, 0, 0, 255) or Color(255, 255, 255, 255)
                            local bg_border = is_dark and Color(255, 255, 255, 220) or Color(0, 0, 0, 220)

                            if mode == 0 then
                                Render.FilledCircle(screen_pos, radius + 2, bg_border)
                                Render.FilledCircle(screen_pos, radius, color)
                            elseif mode == 1 then
                                local font_size = 18
                                local sz = Render.TextSize(font, font_size, label)
                                local text_pos = screen_pos - Vec2(sz.x / 2, sz.y / 2)

                                -- Контур для чистого текста
                                Render.Text(font, font_size, label, text_pos + Vec2(1, 1), Color(0, 0, 0, 255))
                                Render.Text(font, font_size, label, text_pos + Vec2(-1, -1), Color(0, 0, 0, 255))
                                Render.Text(font, font_size, label, text_pos, color)
                            elseif mode == 2 then
                                Render.FilledCircle(screen_pos, radius + 2, bg_border)
                                Render.FilledCircle(screen_pos, radius, color)

                                local font_size = math.max(14, math.floor(radius * 1.2))
                                local sz = Render.TextSize(font, font_size, label)
                                local text_pos = screen_pos - Vec2(sz.x / 2, sz.y / 2)

                                -- Контур текста в 4 стороны для высокой читаемости
                                Render.Text(font, font_size, label, text_pos + Vec2(1, 0), stroke_col)
                                Render.Text(font, font_size, label, text_pos + Vec2(-1, 0), stroke_col)
                                Render.Text(font, font_size, label, text_pos + Vec2(0, 1), stroke_col)
                                Render.Text(font, font_size, label, text_pos + Vec2(0, -1), stroke_col)

                                -- Основной текст
                                Render.Text(font, font_size, label, text_pos, text_col)
                            end
                        end
                    end
                end
            end
        end
    end)
end

return script