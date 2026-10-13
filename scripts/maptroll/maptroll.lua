---@diagnostic disable: undefined-global, param-type-mismatch, inject-field

local mapdraw = {}

--#region UI

local tab = Menu.Create("Scripts", "Other", "Map Chat Troll")
tab:Icon("\u{f075}")
local main_group = tab:Create("Main"):Create("Group")
local troll_group = tab:Create("Troll"):Create("Group")

local ui = {}

ui.global_switch = main_group:Switch("Enabled", false, "\u{f00c}")
ui.text_input = main_group:Input("Text to draw", "", "\u{f040}")
ui.draw_button = main_group:Button("Draw on map", function(this)
    if ui.global_switch:Get() and ui.text_input:Get() ~= "" then
        mapdraw.DrawTextOnMinimap(ui.text_input:Get())
    end
end, false, 1.0)

ui.delay = main_group:Slider("Draw delay, ms", 10, 300, 50, "%d")
ui.scale = main_group:Slider("Letter scale", 50, 400, 200, "%d")
ui.max_chars = main_group:Slider("Max chars per line", 3, 14, 7, "%d")

ui.pos_x = main_group:Slider("Position X", -8000, 8000, -8000, "%d")
ui.pos_y = main_group:Slider("Position Y", -8000, 8000, -8000, "%d")

-- Troll settings
ui.troll_enabled = troll_group:Switch("Enable Troll Mode", false, "\u{f21b}")
ui.troll_text = troll_group:Input("Troll text", "NOOB", "\u{f118}")
ui.troll_interval = troll_group:Slider("Interval, sec", 1, 30, 5, "%d")
ui.troll_target = troll_group:Combo("Target hero", { "Auto (all allies)", "Player 1", "Player 2", "Player 3", "Player 4", "Player 5" }, 0)

ui.global_switch:SetCallback(function ()
    ui.text_input:Disabled(not ui.global_switch:Get())
    ui.draw_button:Disabled(not ui.global_switch:Get())
    ui.delay:Disabled(not ui.global_switch:Get())
    ui.scale:Disabled(not ui.global_switch:Get())
    ui.max_chars:Disabled(not ui.global_switch:Get())
    ui.pos_x:Disabled(not ui.global_switch:Get())
    ui.pos_y:Disabled(not ui.global_switch:Get())
end, true)

ui.troll_enabled:SetCallback(function ()
    ui.troll_text:Disabled(not ui.troll_enabled:Get())
    ui.troll_interval:Disabled(not ui.troll_enabled:Get())
    ui.troll_target:Disabled(not ui.troll_enabled:Get())
end, true)

--#endregion UI

--#region Vars

local my_hero = nil
local drawing_queue = {}
local last_draw_time = 0
local draw_delay = 0.05

local troll_last_time = 0
local troll_heroes = {}

--#endregion Vars

--#region Letter patterns

local letter_patterns = {
    A = {{1,10,5,0},{5,0,9,10},{3,6,7,6}},
    B = {{1,0,1,10},{1,0,7,0},{1,5,7,5},{1,10,7,10},{7,0,8,2},{8,2,7,5},{7,5,8,8},{8,8,7,10}},
    C = {{8,2,7,0},{7,0,3,0},{3,0,1,2},{1,2,1,8},{1,8,3,10},{3,10,7,10},{7,10,8,8}},
    D = {{1,0,1,10},{1,0,6,0},{1,10,6,10},{6,0,8,2},{8,2,8,8},{8,8,6,10}},
    E = {{1,0,1,10},{1,0,8,0},{1,5,6,5},{1,10,8,10}},
    F = {{1,0,1,10},{1,0,8,0},{1,5,6,5}},
    G = {{8,2,7,0},{7,0,3,0},{3,0,1,2},{1,2,1,8},{1,8,3,10},{3,10,7,10},{7,10,8,8},{8,8,8,6},{8,6,6,6}},
    H = {{1,0,1,10},{9,0,9,10},{1,5,9,5}},
    I = {{3,0,7,0},{5,0,5,10},{3,10,7,10}},
    J = {{2,0,8,0},{5,0,5,8},{5,8,4,10},{4,10,2,10},{2,10,1,8}},
    K = {{1,0,1,10},{1,5,9,0},{1,5,9,10}},
    L = {{1,0,1,10},{1,10,8,10}},
    M = {{1,10,1,0},{1,0,5,4},{5,4,9,0},{9,0,9,10}},
    N = {{1,10,1,0},{1,0,9,10},{9,10,9,0}},
    O = {{3,0,7,0},{7,0,9,2},{9,2,9,8},{9,8,7,10},{7,10,3,10},{3,10,1,8},{1,8,1,2},{1,2,3,0}},
    P = {{1,10,1,0},{1,0,7,0},{7,0,8,2},{8,2,7,5},{7,5,1,5}},
    Q = {{3,0,7,0},{7,0,9,2},{9,2,9,8},{9,8,7,10},{7,10,3,10},{3,10,1,8},{1,8,1,2},{1,2,3,0},{6,7,9,10}},
    R = {{1,10,1,0},{1,0,7,0},{7,0,8,2},{8,2,7,5},{7,5,1,5},{5,5,9,10}},
    S = {{8,2,7,0},{7,0,2,0},{2,0,1,2},{1,2,2,4},{2,4,7,4},{7,4,8,6},{8,6,7,8},{7,8,2,8},{2,8,1,10}},
    T = {{1,0,9,0},{5,0,5,10}},
    U = {{1,0,1,8},{1,8,3,10},{3,10,7,10},{7,10,9,8},{9,8,9,0}},
    V = {{1,0,5,10},{5,10,9,0}},
    W = {{1,0,2,10},{2,10,5,6},{5,6,8,10},{8,10,9,0}},
    X = {{1,0,9,10},{9,0,1,10}},
    Y = {{1,0,5,5},{9,0,5,5},{5,5,5,10}},
    Z = {{1,0,9,0},{9,0,1,10},{1,10,9,10}},

    ["А"] = {{1,10,5,0},{5,0,9,10},{3,6,7,6}},
    ["Б"] = {{1,0,1,10},{1,0,8,0},{1,5,6,5},{6,5,8,7},{8,7,8,10},{8,10,1,10}},
    ["В"] = {{1,0,1,10},{1,0,7,0},{1,5,7,5},{1,10,7,10},{7,0,8,2},{8,2,7,5},{7,5,8,8},{8,8,7,10}},
    ["Г"] = {{1,0,1,10},{1,0,8,0}},
    ["Д"] = {{3,0,7,0},{7,0,7,8},{7,8,9,8},{9,8,9,10},{1,10,1,8},{1,8,3,8},{3,8,3,0},{2,8,8,8}},
    ["Е"] = {{1,0,1,10},{1,0,8,0},{1,5,6,5},{1,10,8,10}},
    ["Ё"] = {{1,0,1,10},{1,0,8,0},{1,5,6,5},{1,10,8,10},{3,-2,3,-1},{6,-2,6,-1}},
    ["Ж"] = {{1,0,5,5},{9,0,5,5},{5,5,5,10},{1,10,5,5},{9,10,5,5}},
    ["З"] = {{1,2,3,0},{3,0,7,0},{7,0,8,2},{8,2,6,5},{6,5,8,8},{8,8,7,10},{7,10,3,10},{3,10,1,8}},
    ["И"] = {{1,10,1,0},{9,10,9,0},{1,10,9,0}},
    ["Й"] = {{1,10,1,0},{9,10,9,0},{1,10,9,0},{3,-2,5,-1},{5,-1,7,-2}},
    ["К"] = {{1,0,1,10},{1,5,9,0},{1,5,9,10}},
    ["Л"] = {{2,10,5,0},{5,0,8,10}},
    ["М"] = {{1,10,1,0},{1,0,5,4},{5,4,9,0},{9,0,9,10}},
    ["Н"] = {{1,0,1,10},{9,0,9,10},{1,5,9,5}},
    ["О"] = {{3,0,7,0},{7,0,9,2},{9,2,9,8},{9,8,7,10},{7,10,3,10},{3,10,1,8},{1,8,1,2},{1,2,3,0}},
    ["П"] = {{1,10,1,0},{1,0,9,0},{9,0,9,10}},
    ["Р"] = {{1,10,1,0},{1,0,7,0},{7,0,8,2},{8,2,7,5},{7,5,1,5}},
    ["С"] = {{8,2,7,0},{7,0,3,0},{3,0,1,2},{1,2,1,8},{1,8,3,10},{3,10,7,10},{7,10,8,8}},
    ["Т"] = {{1,0,9,0},{5,0,5,10}},
    ["У"] = {{1,0,5,5},{9,0,5,5},{5,5,3,10},{3,10,1,10},{1,10,0,8}},
    ["Ф"] = {{5,0,5,10},{3,2,7,2},{7,2,8,3},{8,3,8,7},{8,7,7,8},{7,8,3,8},{3,8,2,7},{2,7,2,3},{2,3,3,2}},
    ["Х"] = {{1,0,9,10},{9,0,1,10}},
    ["Ц"] = {{1,0,1,10},{7,0,7,10},{1,10,7,10},{7,10,8,12},{8,12,9,12}},
    ["Ч"] = {{1,0,1,5},{1,5,7,5},{7,0,7,10}},
    ["Ш"] = {{1,0,1,10},{5,0,5,10},{9,0,9,10},{1,10,9,10}},
    ["Щ"] = {{1,0,1,10},{5,0,5,10},{9,0,9,10},{1,10,9,10},{9,10,10,12},{10,12,11,12}},
    ["Ъ"] = {{1,0,4,0},{4,0,4,5},{4,5,8,5},{8,5,9,6},{9,6,9,9},{9,9,8,10},{8,10,4,10},{4,10,4,10}},
    ["Ы"] = {{1,0,1,10},{1,5,5,5},{5,5,6,6},{6,6,6,9},{6,9,5,10},{5,10,1,10},{8,0,8,10}},
    ["Ь"] = {{1,0,1,10},{1,5,7,5},{7,5,8,6},{8,6,8,9},{8,9,7,10},{7,10,1,10}},
    ["Э"] = {{8,2,7,0},{7,0,3,0},{3,0,1,2},{1,2,1,8},{1,8,3,10},{3,10,7,10},{7,10,8,8},{4,5,7,5}},
    ["Ю"] = {{1,0,1,10},{1,5,5,5},{7,0,9,2},{9,2,9,8},{9,8,7,10},{7,10,5,10},{5,10,5,0},{5,0,7,0}},
    ["Я"] = {{9,10,9,0},{9,0,3,0},{3,0,2,2},{2,2,3,5},{3,5,9,5},{5,5,1,10}},

    ["0"] = {{3,0,7,0},{7,0,9,2},{9,2,9,8},{9,8,7,10},{7,10,3,10},{3,10,1,8},{1,8,1,2},{1,2,3,0}},
    ["1"] = {{4,0,5,0},{5,0,5,10},{5,10,5,10}},
    ["2"] = {{1,2,3,0},{3,0,7,0},{7,0,9,2},{9,2,9,4},{9,4,1,10},{1,10,9,10}},
    ["3"] = {{1,2,3,0},{3,0,7,0},{7,0,9,2},{9,2,7,5},{7,5,9,8},{9,8,7,10},{7,10,3,10},{3,10,1,8}},
    ["4"] = {{1,0,1,6},{1,6,8,6},{8,0,8,10}},
    ["5"] = {{9,0,1,0},{1,0,1,5},{1,5,7,5},{7,5,9,7},{9,7,9,8},{9,8,7,10},{7,10,2,10},{2,10,1,8}},
    ["6"] = {{7,0,3,0},{3,0,1,2},{1,2,1,8},{1,8,3,10},{3,10,7,10},{7,10,9,8},{9,8,9,6},{9,6,7,5},{7,5,3,5}},
    ["7"] = {{1,0,9,0},{9,0,3,10}},
    ["8"] = {{3,0,7,0},{7,0,8,1},{8,1,8,4},{8,4,7,5},{7,5,3,5},{3,5,2,4},{2,4,2,1},{2,1,3,0},{3,5,7,5},{7,5,8,6},{8,6,8,9},{8,9,7,10},{7,10,3,10},{3,10,2,9},{2,9,2,6},{2,6,3,5}},
    ["9"] = {{7,5,3,5},{3,5,1,4},{1,4,1,2},{1,2,3,0},{3,0,7,0},{7,0,9,2},{9,2,9,8},{9,8,7,10},{7,10,3,10}},
    [" "] = {}
}

local cyrillic_upper = {
    ["а"] = "А", ["б"] = "Б", ["в"] = "В", ["г"] = "Г", ["д"] = "Д", ["е"] = "Е", ["ё"] = "Ё",
    ["ж"] = "Ж", ["з"] = "З", ["и"] = "И", ["й"] = "Й", ["к"] = "К", ["л"] = "Л", ["м"] = "М",
    ["н"] = "Н", ["о"] = "О", ["п"] = "П", ["р"] = "Р", ["с"] = "С", ["т"] = "Т", ["у"] = "У",
    ["ф"] = "Ф", ["х"] = "Х", ["ц"] = "Ц", ["ч"] = "Ч", ["ш"] = "Ш", ["щ"] = "Щ", ["ъ"] = "Ъ",
    ["ы"] = "Ы", ["ь"] = "Ь", ["э"] = "Э", ["ю"] = "Ю", ["я"] = "Я"
}

--#endregion Letter patterns

--#region Core functions

local function utf8_chars(str)
    local chars = {}
    local i = 1
    while i <= #str do
        local byte = string.byte(str, i)
        local char_len = 1
        if byte >= 240 then char_len = 4
        elseif byte >= 224 then char_len = 3
        elseif byte >= 192 then char_len = 2 end
        chars[#chars + 1] = string.sub(str, i, i + char_len - 1)
        i = i + char_len
    end
    return chars
end

local function trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

function mapdraw.DrawTextOnMinimap(text, override_x, override_y)
    local chars = utf8_chars(text)
    local upper_chars = {}
    for _, char in ipairs(chars) do
        upper_chars[#upper_chars + 1] = cyrillic_upper[char] or string.upper(char)
    end
    local upper_text = table.concat(upper_chars)

    local scale = ui.scale:Get()
    local letter_spacing = 12 * scale
    local line_spacing = 18 * scale
    local max_chars_per_line = ui.max_chars:Get()
    local start_x = override_x or ui.pos_x:Get()
    local start_y = override_y or ui.pos_y:Get()

    local lines = {}
    local current_line_chars = {}
    local processed_chars = utf8_chars(upper_text)

    for i = 1, #processed_chars do
        current_line_chars[#current_line_chars + 1] = processed_chars[i]
        if #current_line_chars >= max_chars_per_line then
            lines[#lines + 1] = current_line_chars
            current_line_chars = {}
        end
    end

    if #current_line_chars > 0 then
        lines[#lines + 1] = current_line_chars
    end

    for line_num = 1, #lines do
        local line_chars = lines[line_num]
        for char_position = 1, #line_chars do
            local char = line_chars[char_position]
            local pattern = letter_patterns[char]
            if pattern then
                local letter_x = start_x + (char_position - 1) * letter_spacing
                local letter_y = start_y + (line_num - 1) * line_spacing
                for j = 1, #pattern do
                    local line_data = pattern[j]
                    local x1 = letter_x + line_data[1] * scale
                    local y1 = letter_y + (10 - line_data[2]) * scale
                    local x2 = letter_x + line_data[3] * scale
                    local y2 = letter_y + (10 - line_data[4]) * scale
                    drawing_queue[#drawing_queue + 1] = {
                        start_pos = Vector(x1, y1, 0),
                        end_pos = Vector(x2, y2, 0)
                    }
                end
            end
        end
    end
end

--#endregion Core functions

--#region Troll functions

local function getHeroIconPath(hero_name)
    if not hero_name then return nil end
    -- Convert npc_dota_hero_xxx to panorama icon path
    local name = hero_name:gsub("npc_dota_hero_", "")
    return "panorama/images/heroes/" .. name .. "_png.vtex_c"
end

local function getHeroDisplayName(hero_name)
    if not hero_name then return "Unknown" end
    -- Convert npc_dota_hero_xxx to readable name
    local name = hero_name:gsub("npc_dota_hero_", "")
    -- Capitalize first letter
    return name:sub(1,1):upper() .. name:sub(2)
end

local function updateHeroList()
    if not my_hero then return end

    local all = Heroes.GetAll()
    local my_team = Entity.GetTeamNum(my_hero)
    local local_hero = Heroes.GetLocal()

    local hero_names = { "Auto (all allies)" }
    troll_heroes = {}

    for i = 1, #all do
        local hero = all[i]
        if hero ~= local_hero and Entity.GetTeamNum(hero) == my_team then
            local hero_name = NPC.GetUnitName(hero)
            local display_name = getHeroDisplayName(hero_name)
            table.insert(hero_names, display_name)
            table.insert(troll_heroes, hero)
        end
    end

    -- Update combo with hero names
    if ui.troll_target then
        local current = ui.troll_target:Get()
        ui.troll_target:Update(hero_names)
        -- Try to keep previous selection
        if current < #hero_names then
            ui.troll_target:Set(current)
        end
    end
end

local function getAllyHeroes()
    local heroes = {}
    local all = Heroes.GetAll()
    local local_hero = Heroes.GetLocal()
    if not local_hero then return heroes end

    local my_team = Entity.GetTeamNum(local_hero)

    for i = 1, #all do
        local hero = all[i]
        if hero ~= local_hero and Entity.GetTeamNum(hero) == my_team and Entity.IsAlive(hero) then
            heroes[#heroes + 1] = hero
        end
    end

    return heroes
end

local function getHeroScreenPos(hero)
    local origin = Entity.GetAbsOrigin(hero)
    if not origin then return nil end

    local screen, visible = Render.WorldToScreen(origin)
    if not visible then return nil end

    return screen:GetX(), screen:GetY()
end

local function updateTrollTargets()
    if not ui.troll_enabled:Get() then return end
    if not my_hero then return end

    local now = GameRules.GetGameTime()
    local interval = ui.troll_interval:Get()

    if now - troll_last_time < interval then return end
    troll_last_time = now

    local allies = getAllyHeroes()
    if #allies == 0 then return end

    local text = ui.troll_text:Get()
    if text == "" then return end

    local target_idx = ui.troll_target:Get()

    if target_idx == 0 then
        -- Auto: troll all allies
        for _, ally in ipairs(allies) do
            local sx, sy = getHeroScreenPos(ally)
            if sx and sy then
                -- Convert screen pos to world pos for minimap drawing
                -- We'll draw at a fixed offset from hero position
                local origin = Entity.GetAbsOrigin(ally)
                if origin then
                    mapdraw.DrawTextOnMinimap(text, origin.x - 200, origin.y - 200)
                end
            end
        end
    else
        -- Specific slot
        local ally = allies[target_idx]
        if ally then
            local origin = Entity.GetAbsOrigin(ally)
            if origin then
                mapdraw.DrawTextOnMinimap(text, origin.x - 200, origin.y - 200)
            end
        end
    end
end

--#endregion Troll functions

--#region Callbacks

function mapdraw.OnUpdate()
    if not ui.global_switch:Get() then return end
    if not my_hero then
        my_hero = Heroes.GetLocal()
        if my_hero then
            updateHeroList()
        end
        return
    end

    -- Normal drawing
    local current_time = os.clock()
    local delay = ui.delay:Get() / 1000
    if #drawing_queue > 0 and (current_time - last_draw_time) >= delay then
        local line_data = table.remove(drawing_queue, 1)
        MiniMap.SendLine(line_data.start_pos, true, false)
        MiniMap.SendLine(line_data.end_pos, false, false)
        last_draw_time = current_time
    end

    -- Troll mode
    updateTrollTargets()
end

function mapdraw.OnGameEnd()
    my_hero = nil
    drawing_queue = {}
    troll_heroes = {}
    troll_last_time = 0
end

--#endregion Callbacks

return mapdraw
