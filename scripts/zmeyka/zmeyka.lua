---@diagnostic disable: undefined-global, param-type-mismatch, inject-field
local snake = {}

local lang = {
    en = {
        tab_name = "Snake Game",
        group_name = "Game Settings",
        enable = "Enable Snake",
        start = "Start New Game",
        reset = "Reset Game",
        speed = "Speed",
        grid_size = "Grid Size",
        food_mode = "Food Mode",
        food_modes = {"Classic", "Bonus", "Custom"},
        custom_count = "Food Count (Custom)",
        auto_open = "Auto Open on Death",
        wall_mode = "Wall Mode",
        wall_modes = {"Classic (Death)", "Wrap Around"},
        score = "SCORE",
        best = "BEST",
        speed_label = "SPEED",
        food_label = "FOOD",
        playing = "PLAYING",
        game_over = "GAME OVER",
        restart = "Press R to restart",
        controls = "WASD / Arrows  •  R to restart",
        start_prompt = "Press 'Start New Game' to begin!",
        game_over_title = "GAME OVER",
        score_text = "Score: ",
        restart_btn = "Press R to restart",
        lang_label = "Language",
        lang_values = {"English", "Русский"},
    },
    ru = {
        tab_name = "Змейка",
        group_name = "Настройки игры",
        enable = "Включить змейку",
        start = "Начать новую игру",
        reset = "Сбросить игру",
        speed = "Скорость",
        grid_size = "Размер поля",
        food_mode = "Режим еды",
        food_modes = {"Классический", "Бонус", "Пользовательский"},
        custom_count = "Кол-во еды (польз.)",
        auto_open = "Автооткрытие при смерти",
        wall_mode = "Режим стен",
        wall_modes = {"Классический (смерть)", "Сквозь стены"},
        score = "СЧЁТ",
        best = "РЕКОРД",
        speed_label = "СКОРОСТЬ",
        food_label = "ЕДА",
        playing = "ИГРА",
        game_over = "ИГРА ОКОНЧЕНА",
        restart = "Нажмите R для рестарта",
        controls = "WASD / Стрелки  •  R для рестарта",
        start_prompt = "Нажмите 'Начать новую игру'!",
        game_over_title = "ИГРА ОКОНЧЕНА",
        score_text = "Счёт: ",
        restart_btn = "Нажмите R для рестарта",
        lang_label = "Язык",
        lang_values = {"English", "Русский"},
    }
}

local current_lang = "en"

local function L(key)
    return lang[current_lang][key] or key
end

local tab = Menu.Create("General", L("tab_name"), L("tab_name"))
tab:Icon("\u{f200}")
local group = tab:Create("Main"):Create(L("group_name"))

local ui = {}

ui.enabled = group:Switch(L("enable"), false, "\u{f00c}")
ui.start = group:Button(L("start"))
ui.reset = group:Button(L("reset"))
ui.speed = group:Slider(L("speed"), 1, 3, 2)
ui.grid_size = group:Slider(L("grid_size"), 10, 25, 15)
ui.food_mode = group:Combo(L("food_mode"), L("food_modes"), 0)
ui.custom_food_count = group:Slider(L("custom_count"), 1, 10, 3)
ui.wall_mode = group:Combo(L("wall_mode"), L("wall_modes"), 0)
ui.auto_open = group:Switch(L("auto_open"), true, "\u{f06e}")
ui.lang_selector = group:Combo(L("lang_label"), L("lang_values"), 0)

ui.start:Disabled(true)
ui.reset:Disabled(true)

local function updateLanguage()
    tab:ForceLocalization(L("tab_name"))
    group:ForceLocalization(L("group_name"))
    
    ui.enabled:ForceLocalization(L("enable"))
    ui.start:ForceLocalization(L("start"))
    ui.reset:ForceLocalization(L("reset"))
    ui.auto_open:ForceLocalization(L("auto_open"))
    
    ui.food_mode:ForceLocalization(L("food_mode"))
    ui.wall_mode:ForceLocalization(L("wall_mode"))
    ui.lang_selector:ForceLocalization(L("lang_label"))
    
    ui.speed:ForceLocalization(L("speed"))
    ui.grid_size:ForceLocalization(L("grid_size"))
    ui.custom_food_count:ForceLocalization(L("custom_count"))
end

ui.lang_selector:SetCallback(function()
    local idx = ui.lang_selector:Get()
    if idx == 0 then
        current_lang = "en"
    else
        current_lang = "ru"
    end
    updateLanguage()
    print("Language changed to: " .. current_lang)
end)

local snake_parts = {}
local food_pos = {x = 0, y = 0}
local food_list = {}
local direction = {x = 0, y = 0}
local next_direction = {x = 0, y = 0}
local game_over = false
local game_started = false
local score = 0
local high_score = 0
local grid_size = 15
local move_interval = 0.15
local speed_names = {"Easy", "Medium", "Hard"}
local move_counter = 0

local bonus_food = nil
local bonus_timer = 0
local bonus_max_timer = 10

local anim_progress = 0
local prev_snake_parts = {}
local is_waiting_for_next_move = false
local was_alive = true

local r_pressed_prev = false
local w_pressed_prev = false
local a_pressed_prev = false
local s_pressed_prev = false
local d_pressed_prev = false
local up_pressed_prev = false
local down_pressed_prev = false
local left_pressed_prev = false
local right_pressed_prev = false

local field_x = 0
local field_y = 0
local cell_size = 30
local field_size = 0

local font = Render.LoadFont("Arial", 0, 500)
local font_big = Render.LoadFont("Arial", 0, 500)

local colors = {
    background = Color(60, 60, 65, 255),
    grid = Color(80, 80, 85, 255),
    border = Color(150, 150, 160, 255),
    body_start = Color(200, 30, 30, 255),
    body_end = Color(120, 10, 10, 255),
    text_bright = Color(0, 255, 100, 255),
    text_dim = Color(200, 200, 200, 255),
    text_status_playing = Color(0, 255, 100, 255),
    text_status_gameover = Color(255, 80, 80, 255),
    snake_face = Color(200, 30, 30, 255),
    snake_eye_white = Color(255, 255, 255, 255),
    snake_eye_black = Color(30, 30, 30, 255),
    snake_mouth = Color(200, 50, 50, 255),
    snake_tongue = Color(255, 80, 80, 255),
    melonity_pink = Color(255, 100, 150, 255),
    melonity_white = Color(255, 255, 255, 255),
    melonity_glow = Color(255, 150, 200, 80),
    game_over_overlay = Color(0, 0, 0, 200),
}

local function getFreeCells()
    local free_cells = {}
    for x = 0, grid_size - 1 do
        for y = 0, grid_size - 1 do
            local is_occupied = false
            for _, part in ipairs(snake_parts) do
                if part.x == x and part.y == y then
                    is_occupied = true
                    break
                end
            end
            if not is_occupied and food_pos and food_pos.x == x and food_pos.y == y then
                is_occupied = true
            end
            if not is_occupied and bonus_food and bonus_food.x == x and bonus_food.y == y then
                is_occupied = true
            end
            if not is_occupied then
                for _, f in ipairs(food_list) do
                    if f.x == x and f.y == y then
                        is_occupied = true
                        break
                    end
                end
            end
            if not is_occupied then
                table.insert(free_cells, {x = x, y = y})
            end
        end
    end
    return free_cells
end

local function spawnFood()
    local free_cells = getFreeCells()
    if #free_cells > 0 then
        local index = math.random(1, #free_cells)
        food_pos = free_cells[index]
    else
        game_over = true
    end
end

local function spawnCustomFood()
    food_list = {}
    local count = ui.custom_food_count:Get()
    local free_cells = getFreeCells()
    for i = 1, math.min(count, #free_cells) do
        if #free_cells > 0 then
            local index = math.random(1, #free_cells)
            table.insert(food_list, free_cells[index])
            table.remove(free_cells, index)
        end
    end
end

local function spawnBonusFood()
    local free_cells = getFreeCells()
    if #free_cells > 0 then
        local index = math.random(1, #free_cells)
        bonus_food = free_cells[index]
        bonus_timer = 0
    else
        bonus_food = nil
    end
end

local function initGame()
    grid_size = ui.grid_size:Get()
    cell_size = 30
    field_size = grid_size * cell_size
    
    local screen_w, screen_h = 1920, 1080
    field_x = (screen_w - field_size) / 2
    field_y = (screen_h - field_size) / 2 - 30
    
    local center_x = math.floor(grid_size / 2)
    local center_y = math.floor(grid_size / 2)
    snake_parts = {
        {x = center_x, y = center_y},
        {x = center_x - 1, y = center_y},
        {x = center_x - 2, y = center_y}
    }
    prev_snake_parts = {}
    for _, part in ipairs(snake_parts) do
        table.insert(prev_snake_parts, {x = part.x, y = part.y})
    end
    direction = {x = 1, y = 0}
    next_direction = {x = 1, y = 0}
    game_over = false
    game_started = true
    score = 0
    move_counter = 0
    anim_progress = 0
    is_waiting_for_next_move = false
    bonus_food = nil
    bonus_timer = 0
    food_list = {}
    
    local mode = ui.food_mode:Get()
    if mode == 2 then
        spawnCustomFood()
    else
        spawnFood()
    end
    
    ui.start:Disabled(true)
    ui.reset:Disabled(false)
    ui.grid_size:Disabled(true)
end

local function resetGame()
    if not game_started then
        return
    end
    
    if score > high_score then
        high_score = score
    end
    
    snake_parts = {}
    prev_snake_parts = {}
    game_over = true
    game_started = false
    score = 0
    move_counter = 0
    bonus_food = nil
    bonus_timer = 0
    food_list = {}
    
    ui.start:Disabled(false)
    ui.reset:Disabled(true)
    ui.grid_size:Disabled(false)
end

local function getMoveInterval()
    local speed = ui.speed:Get()
    if speed == 1 then
        return 0.15
    elseif speed == 2 then
        return 0.09
    else
        return 0.05
    end
end

local function handleInput()
    local r_pressed = Input.IsKeyDown(Enum.ButtonCode.KEY_R)
    if r_pressed and not r_pressed_prev then
        if game_started then
            if score > high_score then
                high_score = score
            end
            snake_parts = {}
            prev_snake_parts = {}
            game_over = true
            game_started = false
            score = 0
            move_counter = 0
            bonus_food = nil
            bonus_timer = 0
            food_list = {}
            if ui.enabled:Get() then
                move_interval = getMoveInterval()
                initGame()
            end
        elseif not game_started and game_over then
            if ui.enabled:Get() then
                move_interval = getMoveInterval()
                initGame()
            end
        end
    end
    r_pressed_prev = r_pressed
    
    if not game_started or game_over then
        return
    end
    
    local new_dir = nil
    
    local w_pressed = Input.IsKeyDown(Enum.ButtonCode.KEY_W)
    local up_pressed = Input.IsKeyDown(Enum.ButtonCode.KEY_UP)
    if (w_pressed or up_pressed) and not (w_pressed_prev or up_pressed_prev) then
        if direction.y ~= 1 then
            new_dir = {x = 0, y = -1}
        end
    end
    w_pressed_prev = w_pressed
    up_pressed_prev = up_pressed
    
    local s_pressed = Input.IsKeyDown(Enum.ButtonCode.KEY_S)
    local down_pressed = Input.IsKeyDown(Enum.ButtonCode.KEY_DOWN)
    if (s_pressed or down_pressed) and not (s_pressed_prev or down_pressed_prev) then
        if direction.y ~= -1 then
            new_dir = {x = 0, y = 1}
        end
    end
    s_pressed_prev = s_pressed
    down_pressed_prev = down_pressed
    
    local a_pressed = Input.IsKeyDown(Enum.ButtonCode.KEY_A)
    local left_pressed = Input.IsKeyDown(Enum.ButtonCode.KEY_LEFT)
    if (a_pressed or left_pressed) and not (a_pressed_prev or left_pressed_prev) then
        if direction.x ~= 1 then
            new_dir = {x = -1, y = 0}
        end
    end
    a_pressed_prev = a_pressed
    left_pressed_prev = left_pressed
    
    local d_pressed = Input.IsKeyDown(Enum.ButtonCode.KEY_D)
    local right_pressed = Input.IsKeyDown(Enum.ButtonCode.KEY_RIGHT)
    if (d_pressed or right_pressed) and not (d_pressed_prev or right_pressed_prev) then
        if direction.x ~= -1 then
            new_dir = {x = 1, y = 0}
        end
    end
    d_pressed_prev = d_pressed
    right_pressed_prev = right_pressed
    
    if new_dir then
        next_direction = new_dir
    end
end

local function updateGame()
    if not ui.enabled:Get() or not game_started or game_over or #snake_parts == 0 then
        return
    end
    
    prev_snake_parts = {}
    for _, part in ipairs(snake_parts) do
        table.insert(prev_snake_parts, {x = part.x, y = part.y})
    end
    
    if not (next_direction.x == 0 and next_direction.y == 0) then
        if not (direction.x == -next_direction.x and direction.y == -next_direction.y) then
            direction = next_direction
        end
    end
    
    local head = snake_parts[1]
    local new_head = {
        x = head.x + direction.x,
        y = head.y + direction.y
    }
    
    local wall_mode = ui.wall_mode:Get()
    
    if new_head.x < 0 then
        if wall_mode == 1 then
            new_head.x = grid_size - 1
        else
            game_over = true
            ui.start:Disabled(false)
            ui.grid_size:Disabled(false)
            if score > high_score then
                high_score = score
            end
            return
        end
    elseif new_head.x >= grid_size then
        if wall_mode == 1 then
            new_head.x = 0
        else
            game_over = true
            ui.start:Disabled(false)
            ui.grid_size:Disabled(false)
            if score > high_score then
                high_score = score
            end
            return
        end
    end
    
    if new_head.y < 0 then
        if wall_mode == 1 then
            new_head.y = grid_size - 1
        else
            game_over = true
            ui.start:Disabled(false)
            ui.grid_size:Disabled(false)
            if score > high_score then
                high_score = score
            end
            return
        end
    elseif new_head.y >= grid_size then
        if wall_mode == 1 then
            new_head.y = 0
        else
            game_over = true
            ui.start:Disabled(false)
            ui.grid_size:Disabled(false)
            if score > high_score then
                high_score = score
            end
            return
        end
    end
    
    for i, part in ipairs(snake_parts) do
        if part.x == new_head.x and part.y == new_head.y then
            game_over = true
            ui.start:Disabled(false)
            ui.grid_size:Disabled(false)
            if score > high_score then
                high_score = score
            end
            return
        end
    end
    
    table.insert(snake_parts, 1, new_head)
    
    local ate = false
    local mode = ui.food_mode:Get()
    
    if food_pos and new_head.x == food_pos.x and new_head.y == food_pos.y then
        score = score + 1
        ate = true
        food_pos = nil
        if mode == 2 then
            spawnCustomFood()
        else
            spawnFood()
        end
    end
    
    if mode == 2 then
        for i, f in ipairs(food_list) do
            if new_head.x == f.x and new_head.y == f.y then
                score = score + 1
                ate = true
                table.remove(food_list, i)
                local free_cells = getFreeCells()
                if #free_cells > 0 then
                    local idx = math.random(1, #free_cells)
                    table.insert(food_list, free_cells[idx])
                end
                break
            end
        end
    end
    
    if bonus_food and new_head.x == bonus_food.x and new_head.y == bonus_food.y then
        score = score + 3
        ate = true
        bonus_food = nil
        bonus_timer = 0
    end
    
    if not ate then
        table.remove(snake_parts)
    end
    
    move_counter = move_counter + 1
    anim_progress = 0
    is_waiting_for_next_move = false
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function drawCustomRoundedRect(x, y, w, h, color, corners, radius)
    if radius <= 0 then
        Render.FilledRect(Vec2(x, y), Vec2(x + w, y + h), color, 0)
        return
    end
    
    local left = x + (corners.tl and radius or 0)
    local right = x + w - (corners.tr and radius or 0)
    local top = y + (corners.tl and radius or 0)
    local bottom = y + h - (corners.bl and radius or 0)
    
    Render.FilledRect(Vec2(left, y), Vec2(right, y + h), color, 0)
    Render.FilledRect(Vec2(x, top), Vec2(x + w, bottom), color, 0)
    
    if corners.tl then
        Render.FilledCircle(Vec2(x + radius, y + radius), radius, color)
    end
    if corners.tr then
        Render.FilledCircle(Vec2(x + w - radius, y + radius), radius, color)
    end
    if corners.bl then
        Render.FilledCircle(Vec2(x + radius, y + h - radius), radius, color)
    end
    if corners.br then
        Render.FilledCircle(Vec2(x + w - radius, y + h - radius), radius, color)
    end
end

local function checkHeroDeath()
    if not ui.enabled:Get() or not ui.auto_open:Get() then
        return
    end
    
    local hero = Heroes.GetLocal()
    if not hero then
        return
    end
    
    local is_alive = Entity.IsAlive(hero)
    
    if was_alive and not is_alive then
        if not game_started then
            move_interval = getMoveInterval()
            initGame()
        end
    end
    
    was_alive = is_alive
end

ui.enabled:SetCallback(function()
    if ui.enabled:Get() then
        ui.start:Disabled(false)
        ui.speed:Disabled(false)
        ui.grid_size:Disabled(false)
        ui.food_mode:Disabled(false)
        ui.custom_food_count:Disabled(ui.food_mode:Get() ~= 2)
        ui.wall_mode:Disabled(false)
        ui.auto_open:Disabled(false)
        ui.lang_selector:Disabled(false)
        if not game_started then
            ui.reset:Disabled(true)
        end
    else
        ui.start:Disabled(true)
        ui.speed:Disabled(true)
        ui.grid_size:Disabled(false)
        ui.food_mode:Disabled(true)
        ui.custom_food_count:Disabled(true)
        ui.wall_mode:Disabled(true)
        ui.auto_open:Disabled(true)
        ui.lang_selector:Disabled(true)
        ui.reset:Disabled(true)
        game_started = false
        game_over = true
        bonus_food = nil
        bonus_timer = 0
        food_list = {}
    end
end)

ui.start:SetCallback(function()
    if ui.enabled:Get() then
        move_interval = getMoveInterval()
        initGame()
    end
end)

ui.reset:SetCallback(function()
    resetGame()
end)

ui.speed:SetCallback(function()
    if game_started and not game_over then
        move_interval = getMoveInterval()
    end
end)

ui.grid_size:SetCallback(function()
    if not game_started then
        grid_size = ui.grid_size:Get()
    end
end)

ui.food_mode:SetCallback(function()
    ui.custom_food_count:Disabled(ui.food_mode:Get() ~= 2)
end)

local function getRoundedCornersForDirection(dir)
    local corners = {tl = false, tr = false, bl = false, br = false}
    
    if dir.x == 1 then
        corners.tr = true
        corners.br = true
    elseif dir.x == -1 then
        corners.tl = true
        corners.bl = true
    elseif dir.y == -1 then
        corners.tl = true
        corners.tr = true
    elseif dir.y == 1 then
        corners.bl = true
        corners.br = true
    end
    
    return corners
end

local function drawCuteSnakeHead(x, y, size, dir, is_dead)
    local radius = size * 0.3
    local color = colors.snake_face
    local corners = getRoundedCornersForDirection(dir)
    
    drawCustomRoundedRect(x, y, size, size, color, corners, radius)
    
    local center_x = x + size / 2
    local center_y = y + size / 2
    
    if is_dead then
        local eye_offset = size * 0.22
        local eye_size = size * 0.12
        local eye_y_offset = size * 0.05
        
        local ex1 = center_x - eye_offset
        local ey1 = center_y - eye_y_offset
        Render.Line(Vec2(ex1 - eye_size, ey1 - eye_size), Vec2(ex1 + eye_size, ey1 + eye_size), Color(0, 0, 0, 255), 2)
        Render.Line(Vec2(ex1 + eye_size, ey1 - eye_size), Vec2(ex1 - eye_size, ey1 + eye_size), Color(0, 0, 0, 255), 2)
        
        local ex2 = center_x + eye_offset
        local ey2 = center_y - eye_y_offset
        Render.Line(Vec2(ex2 - eye_size, ey2 - eye_size), Vec2(ex2 + eye_size, ey2 + eye_size), Color(0, 0, 0, 255), 2)
        Render.Line(Vec2(ex2 + eye_size, ey2 - eye_size), Vec2(ex2 - eye_size, ey2 + eye_size), Color(0, 0, 0, 255), 2)
    else
        local eye_offset = size * 0.22
        local eye_radius = size * 0.13
        local pupil_radius = size * 0.07
        local eye_y_offset = size * 0.05
        
        local eye1_x = center_x - eye_offset
        local eye1_y = center_y - eye_y_offset
        Render.FilledCircle(Vec2(eye1_x, eye1_y), eye_radius, colors.snake_eye_white)
        Render.FilledCircle(Vec2(eye1_x, eye1_y), pupil_radius, colors.snake_eye_black)
        Render.FilledCircle(Vec2(eye1_x + pupil_radius * 0.4, eye1_y - pupil_radius * 0.4), pupil_radius * 0.4, Color(255, 255, 255, 200))
        
        local eye2_x = center_x + eye_offset
        local eye2_y = center_y - eye_y_offset
        Render.FilledCircle(Vec2(eye2_x, eye2_y), eye_radius, colors.snake_eye_white)
        Render.FilledCircle(Vec2(eye2_x, eye2_y), pupil_radius, colors.snake_eye_black)
        Render.FilledCircle(Vec2(eye2_x + pupil_radius * 0.4, eye2_y - pupil_radius * 0.4), pupil_radius * 0.4, Color(255, 255, 255, 200))
        
        local smile_radius = size * 0.18
        local smile_center_x = center_x
        local smile_center_y = center_y + size * 0.25
        for i = 0, 15 do
            local t = i / 15
            local angle = 0.15 * math.pi + (0.85 * math.pi - 0.15 * math.pi) * t
            local sx = smile_center_x + math.cos(angle) * smile_radius
            local sy = smile_center_y + math.sin(angle) * smile_radius
            Render.FilledCircle(Vec2(sx, sy), 1.5, colors.snake_mouth)
        end
        
        local tongue_len = size * 0.2
        if dir.x == 1 or dir.x == -1 then
            local base_x = center_x + dir.x * (size / 2 - 6)
            local tongue_y = center_y + size * 0.25
            Render.Line(Vec2(base_x, tongue_y), Vec2(base_x + dir.x * tongue_len, tongue_y), colors.snake_tongue, 2)
            Render.Line(Vec2(base_x + dir.x * tongue_len, tongue_y), Vec2(base_x + dir.x * (tongue_len + 4), tongue_y - 3), colors.snake_tongue, 1.5)
            Render.Line(Vec2(base_x + dir.x * tongue_len, tongue_y), Vec2(base_x + dir.x * (tongue_len + 4), tongue_y + 3), colors.snake_tongue, 1.5)
        else
            local base_y = center_y + dir.y * (size / 2 - 6)
            local tongue_x = center_x
            Render.Line(Vec2(tongue_x, base_y), Vec2(tongue_x, base_y + dir.y * tongue_len), colors.snake_tongue, 2)
            Render.Line(Vec2(tongue_x, base_y + dir.y * tongue_len), Vec2(tongue_x - 3, base_y + dir.y * (tongue_len + 4)), colors.snake_tongue, 1.5)
            Render.Line(Vec2(tongue_x, base_y + dir.y * tongue_len), Vec2(tongue_x + 3, base_y + dir.y * (tongue_len + 4)), colors.snake_tongue, 1.5)
        end
        
        local blush_radius = size * 0.07
        Render.FilledCircle(Vec2(center_x - size * 0.28, center_y + size * 0.2), blush_radius, Color(255, 150, 150, 120))
        Render.FilledCircle(Vec2(center_x + size * 0.28, center_y + size * 0.2), blush_radius, Color(255, 150, 150, 120))
    end
end

local function drawSnakeTail(x, y, size, tail_dir)
    local radius = size * 0.3
    local color = colors.body_end
    local corners = getRoundedCornersForDirection(tail_dir)
    
    drawCustomRoundedRect(x, y, size, size, color, corners, radius)
end

local function drawBonusFood(cx, cy, radius, progress)
    local r = radius * 1.2
    local pulse = math.sin(progress * 4) * 0.1 + 0.9
    
    for i = 1, 5 do
        local glow_alpha = 80 - i * 12
        local glow_radius = r * pulse + i * 8
        Render.FilledCircle(Vec2(cx, cy), glow_radius, Color(255, 50, 150, glow_alpha))
    end
    
    Render.FilledCircle(Vec2(cx, cy), r * pulse, Color(255, 80, 180, 255))
    Render.FilledCircle(Vec2(cx, cy), r * 0.4 * pulse, Color(255, 255, 255, 220))
    
    for i = 0, 7 do
        local angle = i * math.pi / 4 + progress * 2
        local lx = cx + math.cos(angle) * r * 0.7 * pulse
        local ly = cy + math.sin(angle) * r * 0.7 * pulse
        Render.FilledCircle(Vec2(lx, ly), 3, Color(255, 255, 255, 180))
    end
end

local function drawMelonityLogo(cx, cy, radius)
    local r = radius * 0.85
    
    Render.FilledCircle(Vec2(cx, cy), r, colors.melonity_pink)
    
    local m_r = r * 0.5
    local w = m_r * 0.3
    
    Render.FilledRect(Vec2(cx - m_r, cy - m_r), Vec2(cx - m_r + w, cy + m_r), colors.melonity_white)
    Render.FilledRect(Vec2(cx + m_r - w, cy - m_r), Vec2(cx + m_r, cy + m_r), colors.melonity_white)
    
    for i = 0, 30 do
        local t = i / 30
        local px = (cx - m_r + w) + (cx - (cx - m_r + w)) * t
        local py = (cy - m_r) + (cy + m_r * 0.2 - (cy - m_r)) * t
        Render.FilledCircle(Vec2(px, py), w * 0.6, colors.melonity_white)
    end
    
    for i = 0, 30 do
        local t = i / 30
        local px = cx + (cx + m_r - w - cx) * t
        local py = (cy + m_r * 0.2) + (cy - m_r - (cy + m_r * 0.2)) * t
        Render.FilledCircle(Vec2(px, py), w * 0.6, colors.melonity_white)
    end
    
    Render.FilledRect(Vec2(cx - w * 0.4, cy + m_r * 0.15), Vec2(cx + w * 0.4, cy + m_r * 0.3), colors.melonity_white)
    
    Render.Circle(Vec2(cx, cy), r, colors.melonity_white, 2)
end

local function drawGame()
    if not ui.enabled:Get() then
        return
    end
    
    if not game_started then
        return
    end
    
    local delta = 0.025
    if move_interval < 0.08 then
        delta = 0.05
    elseif move_interval < 0.15 then
        delta = 0.035
    else
        delta = 0.025
    end
    
    anim_progress = anim_progress + delta
    
    if anim_progress >= 1 then
        anim_progress = 1
        is_waiting_for_next_move = true
    end
    
    local food_mode = ui.food_mode:Get()
    if food_mode == 1 and game_started and not game_over then
        bonus_timer = bonus_timer + delta
        if not bonus_food and bonus_timer > 3 then
            spawnBonusFood()
            bonus_timer = 0
        end
        if bonus_food and bonus_timer > bonus_max_timer then
            bonus_food = nil
            bonus_timer = 0
        end
    elseif food_mode ~= 1 then
        bonus_food = nil
        bonus_timer = 0
    end
    
    field_size = grid_size * cell_size
    local screen_w, screen_h = 1920, 1080
    field_x = (screen_w - field_size) / 2
    field_y = (screen_h - field_size) / 2 - 30
    
    Render.FilledRect(Vec2(field_x, field_y), Vec2(field_x + field_size, field_y + field_size), colors.background, 8)
    
    for x = 0, grid_size do
        local pos_x = field_x + x * cell_size
        if pos_x > field_x + 5 and pos_x < field_x + field_size - 5 then
            Render.Rect(Vec2(pos_x, field_y + 5), Vec2(pos_x, field_y + field_size - 5), colors.grid, 0, 0, 1)
        end
    end
    for y = 0, grid_size do
        local pos_y = field_y + y * cell_size
        if pos_y > field_y + 5 and pos_y < field_y + field_size - 5 then
            Render.Rect(Vec2(field_x + 5, pos_y), Vec2(field_x + field_size - 5, pos_y), colors.grid, 0, 0, 1)
        end
    end
    
    Render.Rect(Vec2(field_x + 2, field_y + 2), Vec2(field_x + field_size - 2, field_y + field_size - 2), colors.border, 6, 0, 2)
    
    if food_mode ~= 2 and food_pos then
        local fx = field_x + food_pos.x * cell_size + cell_size / 2
        local fy = field_y + food_pos.y * cell_size + cell_size / 2
        local food_radius = cell_size / 2 - 3
        
        local min_x = field_x + food_radius + 5
        local max_x = field_x + field_size - food_radius - 5
        local min_y = field_y + food_radius + 5
        local max_y = field_y + field_size - food_radius - 5
        
        fx = math.max(min_x, math.min(max_x, fx))
        fy = math.max(min_y, math.min(max_y, fy))
        
        for i = 1, 3 do
            local glow_alpha = 60 - i * 15
            Render.FilledCircle(Vec2(fx, fy), food_radius + i * 4, Color(255, 150, 200, glow_alpha))
        end
        
        drawMelonityLogo(fx, fy, food_radius)
    end
    
    if food_mode == 2 then
        for _, f in ipairs(food_list) do
            local fx = field_x + f.x * cell_size + cell_size / 2
            local fy = field_y + f.y * cell_size + cell_size / 2
            local food_radius = cell_size / 2 - 3
            
            local min_x = field_x + food_radius + 5
            local max_x = field_x + field_size - food_radius - 5
            local min_y = field_y + food_radius + 5
            local max_y = field_y + field_size - food_radius - 5
            
            fx = math.max(min_x, math.min(max_x, fx))
            fy = math.max(min_y, math.min(max_y, fy))
            
            for i = 1, 3 do
                local glow_alpha = 60 - i * 15
                Render.FilledCircle(Vec2(fx, fy), food_radius + i * 4, Color(255, 150, 200, glow_alpha))
            end
            
            drawMelonityLogo(fx, fy, food_radius)
        end
    end
    
    if bonus_food and food_mode == 1 then
        local fx = field_x + bonus_food.x * cell_size + cell_size / 2
        local fy = field_y + bonus_food.y * cell_size + cell_size / 2
        local food_radius = cell_size / 2 - 3
        
        local min_x = field_x + food_radius + 5
        local max_x = field_x + field_size - food_radius - 5
        local min_y = field_y + food_radius + 5
        local max_y = field_y + field_size - food_radius - 5
        
        fx = math.max(min_x, math.min(max_x, fx))
        fy = math.max(min_y, math.min(max_y, fy))
        
        drawBonusFood(fx, fy, food_radius, bonus_timer)
    end
    
    local total_parts = #snake_parts
    local progress = anim_progress
    if is_waiting_for_next_move then
        progress = 1
    end
    
    for i, part in ipairs(snake_parts) do
        local x = field_x + part.x * cell_size
        local y = field_y + part.y * cell_size
        
        local smooth_x, smooth_y = x, y
        if i <= #prev_snake_parts and not is_waiting_for_next_move then
            local prev_part = prev_snake_parts[i]
            if prev_part then
                local ease = progress
                smooth_x = field_x + lerp(prev_part.x, part.x, ease) * cell_size
                smooth_y = field_y + lerp(prev_part.y, part.y, ease) * cell_size
            end
        end
        
        smooth_x = math.max(field_x, math.min(field_x + field_size - cell_size, smooth_x))
        smooth_y = math.max(field_y, math.min(field_y + field_size - cell_size, smooth_y))
        
        if i == 1 then
            drawCuteSnakeHead(smooth_x, smooth_y, cell_size, direction, game_over)
        elseif i == total_parts then
            local tail_dir = {x = 0, y = 0}
            if total_parts >= 2 then
                local prev_part = snake_parts[i-1]
                local tail_part = snake_parts[i]
                tail_dir.x = tail_part.x - prev_part.x
                tail_dir.y = tail_part.y - prev_part.y
            else
                tail_dir = direction
            end
            drawSnakeTail(smooth_x, smooth_y, cell_size, tail_dir)
        else
            local progress2 = (i - 1) / total_parts
            local r = 200 - progress2 * 80
            local g = 30 - progress2 * 20
            local b = 30 - progress2 * 20
            local body_color = Color(math.max(r, 120), math.max(g, 10), math.max(b, 10), 255)
            Render.FilledRect(Vec2(smooth_x, smooth_y), Vec2(smooth_x + cell_size, smooth_y + cell_size), body_color, 0)
        end
    end
    
    local y_offset = field_y + field_size + 25
    local info_height = 70
    local info_width = field_size
    
    Render.FilledRect(Vec2(field_x, y_offset), Vec2(field_x + info_width, y_offset + info_height), colors.background, 8)
    Render.Rect(Vec2(field_x, y_offset), Vec2(field_x + info_width, y_offset + info_height), colors.border, 8, 0, 1)
    
    if game_over then
        Render.FilledRect(Vec2(field_x, y_offset), Vec2(field_x + info_width, y_offset + info_height), colors.game_over_overlay, 8)
    end
    
    local fs_main = 18
    local fs_small = 13
    local fs_status = 18
    local fs_controls = 11
    
    local best_offset = 150
    local speed_offset = 230
    
    if grid_size <= 13 then
        fs_main = 15
        fs_small = 11
        fs_status = 16
        fs_controls = 10
        best_offset = 130
        speed_offset = 190
    elseif grid_size <= 15 then
        fs_main = 16
        fs_small = 12
        fs_status = 17
        fs_controls = 11
        best_offset = 140
        speed_offset = 210
    end
    
    local y1 = y_offset + 6
    Render.Text(font, fs_main, L("score") .. ": " .. score, Vec2(field_x + 10, y1), colors.text_bright)
    Render.Text(font, fs_small, L("best") .. ": " .. high_score, Vec2(field_x + best_offset, y1 + 1), colors.text_dim)
    
    local speed_text = speed_names[ui.speed:Get()]
    Render.Text(font, fs_small, L("speed_label") .. ": " .. speed_text, Vec2(field_x + speed_offset, y1 + 1), colors.text_dim)
    
    local y2 = y_offset + 34
    local status_text = game_over and L("game_over") or L("playing")
    local status_color = game_over and colors.text_status_gameover or colors.text_status_playing
    
    local text_size2 = Render.TextSize(font, fs_status, status_text)
    local status_x = field_x + (info_width - text_size2.x) / 2
    Render.Text(font, fs_status, status_text, Vec2(status_x, y2), status_color)
    
    local y3 = y_offset + info_height - 16
    
    local mode_text = L("food_modes")[ui.food_mode:Get() + 1] or "Classic"
    if ui.food_mode:Get() == 2 then
        mode_text = "Custom(" .. ui.custom_food_count:Get() .. ")"
    end
    local food_text = L("food_label") .. ": " .. mode_text
    local food_size = Render.TextSize(font, fs_controls, food_text)
    local food_x = field_x + info_width - food_size.x - 10
    
    Render.Text(font, fs_controls, food_text, Vec2(food_x, y3), Color(150, 150, 160, 200))
    Render.Text(font, fs_controls, L("controls"), Vec2(field_x + 10, y3), Color(150, 150, 160, 200))
    
    if game_over then
        Render.FilledRect(Vec2(field_x, field_y), Vec2(field_x + field_size, field_y + field_size), colors.game_over_overlay, 8)
        
        local text1 = L("game_over_title")
        local text_size1 = Render.TextSize(font_big, 52, text1)
        local text1_x = field_x + (field_size - text_size1.x) / 2
        local text1_y = field_y + field_size / 2 - 50
        Render.Text(font_big, 52, text1, Vec2(text1_x, text1_y), Color(255, 80, 80, 255))
        
        local text2 = L("score_text") .. score
        local text_size2 = Render.TextSize(font, 26, text2)
        local text2_x = field_x + (field_size - text_size2.x) / 2
        local text2_y = field_y + field_size / 2 + 20
        Render.Text(font, 26, text2, Vec2(text2_x, text2_y), Color(255, 255, 255, 255))
        
        local text3 = L("restart_btn")
        local text_size3 = Render.TextSize(font, 18, text3)
        local text3_x = field_x + (field_size - text_size3.x) / 2
        local text3_y = field_y + field_size / 2 + 60
        Render.Text(font, 18, text3, Vec2(text3_x, text3_y), Color(200, 200, 200, 255))
    end
end

snake.OnUpdate = function()
    if not ui.enabled:Get() then
        return
    end
    
    checkHeroDeath()
    handleInput()
    
    if not game_started then
        return
    end
    
    if anim_progress >= 1 then
        if not is_waiting_for_next_move then
            is_waiting_for_next_move = true
        end
        updateGame()
    end
end

snake.OnDraw = function()
    drawGame()
end

game_started = false
game_over = true
ui.start:Disabled(true)
ui.reset:Disabled(true)
grid_size = ui.grid_size:Get()
bonus_food = nil
bonus_timer = 0
food_list = {}
was_alive = true

print("========================================")
print("SNAKE GAME LOADED")
print("Language: " .. current_lang)
print("Modes: Classic, Bonus (+3 points), Custom")
print("Wall Modes: Classic (Death), Wrap Around")
print("Auto Open on Death: " .. tostring(ui.auto_open:Get()))
print("Controls: WASD / Arrows to move")
print("Press R to restart")
print("========================================")

return snake