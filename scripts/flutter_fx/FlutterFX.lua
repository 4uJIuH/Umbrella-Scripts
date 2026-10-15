local App = {}

local TAU = math.pi * 2

local function clock()
    if GlobalVars and GlobalVars.GetCurTime then return GlobalVars.GetCurTime() end
    if GameRules and GameRules.GetGameTime then return GameRules.GetGameTime() end
    return os.clock()
end

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function clamp01(value)
    return clamp(value, 0, 1)
end

local function lerp(a, b, amount)
    return a + (b - a) * amount
end

local function smooth(amount)
    amount = clamp01(amount)
    return amount * amount * (3 - 2 * amount)
end

local function ease_out(amount)
    amount = clamp01(amount)
    return 1 - (1 - amount) ^ 3
end

local function seeded(seed, index)
    local value = math.sin(seed * 12.9898 + index * 78.233) * 43758.5453
    return value - math.floor(value)
end

local function safe_call(fn, ...)
    if not fn then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if ok then return a, b, c end
    return nil
end

local function alpha(color, opacity)
    return Color(
        color.r or 255,
        color.g or 255,
        color.b or 255,
        math.floor(clamp(opacity or 255, 0, 255))
    )
end

local function mix(a, b, amount, opacity)
    amount = clamp01(amount)
    return Color(
        math.floor(lerp(a.r or 0, b.r or 0, amount)),
        math.floor(lerp(a.g or 0, b.g or 0, amount)),
        math.floor(lerp(a.b or 0, b.b or 0, amount)),
        math.floor(clamp(opacity or 255, 0, 255))
    )
end

local function hsv(hue, saturation, value, opacity)
    hue = hue % 360
    local chroma = value * saturation
    local intermediate = chroma * (1 - math.abs((hue / 60) % 2 - 1))
    local minimum = value - chroma
    local red, green, blue = 0, 0, 0
    if hue < 60 then red, green = chroma, intermediate
    elseif hue < 120 then red, green = intermediate, chroma
    elseif hue < 180 then green, blue = chroma, intermediate
    elseif hue < 240 then green, blue = intermediate, chroma
    elseif hue < 300 then red, blue = intermediate, chroma
    else red, blue = chroma, intermediate end
    return Color(
        math.floor((red + minimum) * 255),
        math.floor((green + minimum) * 255),
        math.floor((blue + minimum) * 255),
        math.floor(clamp(opacity or 255, 0, 255))
    )
end

local function entity_index(entity)
    return safe_call(Entity.GetIndex, entity) or -1
end

local function entity_origin(entity)
    return safe_call(Entity.GetAbsOrigin, entity)
end

local function same_entity(a, b)
    return a and b and entity_index(a) == entity_index(b)
end

local function world_to_screen(position)
    if not position then return nil, false end
    return Render.WorldToScreen(position)
end

local function silk_line(start_point, end_point, color, highlight, opacity, width, quality)
    if not start_point or not end_point or opacity <= 0 or width <= 0 then return end
    quality = clamp(math.floor(quality or 1), 1, 4)
    if quality >= 4 then
        Render.Line(start_point, end_point, alpha(color, opacity * 0.025), width * 9)
        Render.Line(start_point, end_point, alpha(highlight, opacity * 0.04), width * 6)
    end
    if quality >= 3 then Render.Line(start_point, end_point, alpha(color, opacity * 0.08), width * 4) end
    if quality >= 2 then Render.Line(start_point, end_point, alpha(color, opacity * 0.2), width * 2.35) end
    Render.Line(start_point, end_point, alpha(mix(color, highlight, 0.25), opacity * 0.64), width * 1.25)
    Render.Line(start_point, end_point, alpha(mix(highlight, Color(255, 255, 255), 0.65), opacity), math.max(0.65, width * 0.42))
end

local function soft_aura(point, radius, color, opacity, quality)
    if not point or radius <= 0 or opacity <= 0 then return end
    quality = clamp(math.floor(quality or 1), 1, 6)
    for layer = quality, 1, -1 do
        local factor = layer / quality
        Render.FilledCircle(point, radius * (1 + factor * 2.7), alpha(color, opacity * (0.012 + (1 - factor) * 0.021)), 0, 1, 28)
    end
    Render.FilledCircle(point, radius, alpha(color, opacity * 0.09), 0, 1, 24)
end

local function glow_dot(point, radius, color, opacity, quality)
    if not point or opacity <= 0 then return end
    if quality >= 3 then Render.FilledCircle(point, radius * 3.4, alpha(color, opacity * 0.035), 0, 1, 18) end
    if quality >= 2 then Render.FilledCircle(point, radius * 2, alpha(color, opacity * 0.11), 0, 1, 16) end
    Render.FilledCircle(point, radius, alpha(color, opacity * 0.62), 0, 1, 14)
    Render.FilledCircle(point, math.max(0.7, radius * 0.32), alpha(Color(255, 255, 255), opacity), 0, 1, 10)
end

local function glint(point, radius, color, opacity, quality)
    silk_line(Vec2(point.x - radius, point.y), Vec2(point.x + radius, point.y), color, Color(255, 255, 255), opacity, math.max(0.55, radius * 0.05), quality)
    silk_line(Vec2(point.x, point.y - radius * 0.62), Vec2(point.x, point.y + radius * 0.62), color, Color(255, 255, 255), opacity, math.max(0.55, radius * 0.05), quality)
end

local function ellipse_arc(center, radius_x, radius_y, start_angle, span, segments, rotation, color, highlight, opacity, width, quality)
    local previous
    local cosine = math.cos(rotation or 0)
    local sine = math.sin(rotation or 0)
    for segment = 0, segments do
        local angle = start_angle + span * segment / segments
        local local_x = math.cos(angle) * radius_x
        local local_y = math.sin(angle) * radius_y
        local point = Vec2(
            center.x + local_x * cosine - local_y * sine,
            center.y + local_x * sine + local_y * cosine
        )
        if previous then silk_line(previous, point, color, highlight, opacity, width, quality) end
        previous = point
    end
end

local QUALITY_NAMES = { "Картошка", "Средничек", "Высокое", "GG" }
local QUALITY = {
    { quality = 1, scan = 0.11, maximum = 34, outline = 4, echoes = 0, material_particles = 5, crit_shards = 5, signature = 5, kill_particles = 20, kill_segments = 28, engine = false },
    { quality = 2, scan = 0.06, maximum = 70, outline = 8, echoes = 1, material_particles = 14, crit_shards = 10, signature = 10, kill_particles = 52, kill_segments = 52, engine = true },
    { quality = 3, scan = 0.032, maximum = 130, outline = 12, echoes = 2, material_particles = 32, crit_shards = 20, signature = 22, kill_particles = 120, kill_segments = 96, engine = true },
    { quality = 4, scan = 0.016, maximum = 220, outline = 16, echoes = 4, material_particles = 72, crit_shards = 38, signature = 48, kill_particles = 260, kill_segments = 180, engine = true },
}

local MATERIAL_NAMES = {
    "Плазменный неон",
    "Жидкое золото",
    "Обсидиан",
    "Голограмма",
    "Морозное стекло",
    "Кровавые чернила",
    "Аркан-кристалл",
    "Жидкий хром",
    "Свой материал",
}

local MATERIAL_COLORS = {
    { Color(60, 215, 255), Color(225, 70, 255), Color(245, 252, 255) },
    { Color(255, 174, 34), Color(255, 235, 128), Color(255, 255, 226) },
    { Color(24, 20, 38), Color(178, 45, 82), Color(232, 224, 255) },
    { Color(48, 232, 255), Color(255, 54, 202), Color(238, 255, 255) },
    { Color(118, 213, 255), Color(220, 250, 255), Color(255, 255, 255) },
    { Color(190, 22, 48), Color(92, 3, 26), Color(255, 182, 170) },
    { Color(126, 72, 255), Color(54, 238, 255), Color(255, 225, 255) },
    { Color(128, 145, 170), Color(226, 236, 246), Color(255, 255, 255) },
    { Color(90, 210, 255), Color(210, 90, 255), Color(255, 255, 255) },
}

local FONT_NAMES = {
    "SF Pro Display",
    "MuseoSansEx",
    "SF Pro Text",
    "Arial",
    "Tahoma",
    "Verdana",
    "Impact",
    "Courier New",
}

local FONT_WEIGHT_NAMES = { "Обычный", "Полужирный", "Жирный", "Black" }
local FONT_WEIGHTS = { 400, 600, 800, 950 }
local ANIMATION_NAMES = { "Шёлковый подъём", "Кинетический удар", "Баллистика", "Спираль", "Глитч-рывок", "Кинематографичный" }
local SOURCE_NAMES = { "Весь видимый урон", "Мой урон и входящий", "Только мой урон" }
local KILL_STYLE_NAMES = { "Чернильный приговор", "Хроно-экзекуция", "Клетка душ", "Небесный приговор", "Терновый трибунал", "Случайный" }

local menu = Menu.Create("General", "Combat Text FX", "Flutter Combat")
menu:Icon("\u{f06d}")

local main_tab = menu:Create("Главное")
local main_group = main_tab:Create("Управление")
local filter_group = main_tab:Create("Фильтры")
local surface_tab = menu:Create("Материал и шрифт")
local material_group = surface_tab:Create("Материал")
local font_group = surface_tab:Create("Шрифт")
local motion_tab = menu:Create("Анимация")
local motion_group = motion_tab:Create("Движение")
local accent_group = motion_tab:Create("Акценты")
local kill_tab = menu:Create("Эффекты убийства")
local kill_group = kill_tab:Create("Основное")
local kill_style_group = kill_tab:Create("Оформление")

main_group:Label("Автор: Flutter", "\u{f007}")

local UI = {
    master = main_group:Switch("Включить Combat Text FX", true, "\u{f06e}"),
    quality = main_group:Combo("Качество", QUALITY_NAMES, 2),
    source = main_group:Combo("Источник урона", SOURCE_NAMES, 1),
    self = main_group:Switch("Урон и лечение на себе", true, "\u{f007}"),
    allies = main_group:Switch("Союзные герои", false, "\u{f0c0}"),
    enemies = main_group:Switch("Вражеские герои", true, "\u{f54c}"),
    creeps = main_group:Switch("Крипы и нейтралы", true, "\u{f6d5}"),
    illusions = main_group:Switch("Иллюзии", false, "\u{f503}"),

    damage = filter_group:Switch("Показывать урон", true, "\u{f714}"),
    healing = filter_group:Switch("Показывать лечение", true, "\u{f004}"),
    misses = filter_group:Switch("Показывать промахи", true, "\u{f05e}"),
    critical = filter_group:Switch("Критические акценты", true, "\u{f06d}"),
    critical_threshold = filter_group:Slider("Порог мощного акцента", 50, 3000, 350, "%d"),
    filter_small = filter_group:Switch("Фильтровать мелкие тики", true, "\u{f0b0}"),
    minimum = filter_group:Slider("Минимальное значение", 1, 500, 8, "%d"),
    merge = filter_group:Switch("Объединять частые тики", true, "\u{f067}"),
    merge_window = filter_group:Slider("Окно объединения", 30, 800, 170, "%d мс"),
    maximum = filter_group:Slider("Максимум цифр", 10, 240, 120, "%d"),
    abbreviate = filter_group:Switch("Сокращать большие числа", false, "\u{f292}"),
    type_badge = filter_group:Switch("Подпись типа урона", true, "\u{f02b}"),
    hit_combo = filter_group:Switch("Счётчик серии попаданий", true, "\u{f0e7}"),
    combo_window = filter_group:Slider("Окно серии", 200, 3000, 900, "%d мс"),

    material = material_group:Combo("Материал", MATERIAL_NAMES, 0),
    material_auto = material_group:Switch("Цвет зависит от типа урона", true, "\u{f53f}"),
    material_mix = material_group:Slider("Влияние материала", 0, 100, 58, "%d%%"),
    material_intensity = material_group:Slider("Интенсивность материала", 0, 250, 125, "%d%%"),
    bloom = material_group:Slider("Свечение", 0, 250, 115, "%d%%"),
    gloss = material_group:Slider("Блик поверхности", 0, 250, 120, "%d%%"),
    outline = material_group:Slider("Толщина контура", 0, 8, 2, "%d px"),
    shadow = material_group:Switch("Объёмная тень", true, "\u{f1b2}"),
    custom_primary = material_group:ColorPicker("Свой основной цвет", Color(75, 220, 255, 255)),
    custom_secondary = material_group:ColorPicker("Свой второй цвет", Color(215, 80, 255, 255)),
    custom_highlight = material_group:ColorPicker("Свой цвет блика", Color(255, 255, 255, 255)),
    physical = material_group:ColorPicker("Физический урон", Color(236, 224, 204, 255)),
    magical = material_group:ColorPicker("Магический урон", Color(82, 176, 255, 255)),
    pure = material_group:ColorPicker("Чистый урон", Color(255, 92, 221, 255)),
    heal = material_group:ColorPicker("Лечение", Color(80, 255, 142, 255)),
    miss = material_group:ColorPicker("Промах", Color(205, 216, 232, 255)),
    crit = material_group:ColorPicker("Критический удар", Color(255, 55, 92, 255)),

    font = font_group:Combo("Шрифт", FONT_NAMES, 0),
    font_weight = font_group:Combo("Толщина шрифта", FONT_WEIGHT_NAMES, 2),
    font_size = font_group:Slider("Размер", 11, 72, 27, "%d px"),
    font_scale_crit = font_group:Slider("Размер критического урона", 100, 220, 145, "%d%%"),
    opacity = font_group:Slider("Прозрачность", 10, 100, 100, "%d%%"),
    symbols = font_group:Switch("Символы урона", true, "\u{f12a}"),

    animation = motion_group:Combo("Анимация", ANIMATION_NAMES, 0),
    duration = motion_group:Slider("Длительность", 250, 3500, 1050, "%d мс"),
    rise = motion_group:Slider("Высота движения", 5, 220, 72, "%d px"),
    spread = motion_group:Slider("Горизонтальный разброс", 0, 120, 22, "%d px"),
    speed = motion_group:Slider("Скорость анимации", 25, 250, 100, "%d%%"),
    echo = motion_group:Switch("Шлейф числа", true, "\u{f1d8}"),
    shake = motion_group:Slider("Тряска критов", 0, 20, 4, "%d px"),

    hero_signature = accent_group:Switch("Сигнатура выбранного героя", true, "\u{f508}"),
    signature_threshold = accent_group:Slider("Порог сигнатуры", 1, 2000, 180, "%d урона"),
    signature_intensity = accent_group:Slider("Интенсивность сигнатуры", 10, 250, 125, "%d%%"),
    fracture = accent_group:Slider("Осколки критического удара", 0, 200, 100, "%d%%"),
    critical_ring = accent_group:Switch("Ударная волна крита", true, "\u{f111}"),

    kill_enable = kill_group:Switch("Эффект убийства героя", true, "\u{f54c}"),
    kill_style = kill_group:Combo("Стиль", KILL_STYLE_NAMES, 0),
    kill_engine = kill_group:Switch("Трёхмерный VPCF-эффект", true, "\u{f5d0}"),
    kill_controlled = kill_group:Switch("Убийства подконтрольными юнитами", true, "\u{f0c0}"),
    kill_creeps = kill_group:Switch("Также при убийстве крипов", false, "\u{f6d5}"),
    kill_illusions = kill_group:Switch("Убийства иллюзий", false, "\u{f503}"),
    kill_label = kill_group:Switch("Надпись об убийстве", true, "\u{f031}"),
    kill_name = kill_group:Switch("Имя убитого героя", true, "\u{f2bd}"),
    kill_streak = kill_group:Switch("Локальная серия убийств", true, "\u{f201}"),
    kill_streak_window = kill_group:Slider("Окно серии убийств", 3, 30, 12, "%d сек"),
    kill_maximum = kill_group:Slider("Одновременные эффекты", 1, 12, 5, "%d"),

    kill_duration = kill_style_group:Slider("Длительность", 500, 6000, 2200, "%d мс"),
    kill_scale = kill_style_group:Slider("Масштаб", 40, 260, 115, "%d%%"),
    kill_density = kill_style_group:Slider("Плотность частиц", 10, 250, 125, "%d%%"),
    kill_opacity = kill_style_group:Slider("Прозрачность", 10, 100, 100, "%d%%"),
    kill_speed = kill_style_group:Slider("Скорость", 25, 250, 100, "%d%%"),
    kill_auto_colors = kill_style_group:Switch("Цвета выбранного стиля", true, "\u{f53f}"),
    kill_primary = kill_style_group:ColorPicker("Свой основной цвет", Color(255, 52, 94, 255)),
    kill_secondary = kill_style_group:ColorPicker("Свой второй цвет", Color(112, 210, 255, 255)),
}

UI.quality:Icon("\u{f1b3}")
UI.source:Icon("\u{f0ec}")
UI.material:Icon("\u{f5aa}")
UI.font:Icon("\u{f031}")
UI.font_weight:Icon("\u{f550}")
UI.animation:Icon("\u{f135}")
UI.kill_style:Icon("\u{f714}")

local STATE = {
    entries = {},
    health = {},
    exact = {},
    hit_chains = {},
    kills = {},
    particles = {},
    font_cache = {},
    next_scan = 0,
    kill_count = 0,
    last_kill = -100,
    master_was_enabled = true,
}

local KILL_PARTICLES = {
    "particles/units/heroes/hero_grimstroke/grimstroke_death.vpcf",
    "particles/econ/items/earthshaker/earthshaker_arcana/earthshaker_arcana_target_death.vpcf",
    "particles/econ/items/terrorblade/terrorblade_horns_arcana/terrorblade_arcana_enemy_death.vpcf",
    "particles/econ/items/windrunner/windranger_arcana/windranger_arcana_tgt_death.vpcf",
    "particles/units/heroes/hero_treant/treant_overgrowth_vines_death.vpcf",
}

local KILL_COLORS = {
    { Color(238, 236, 220), Color(42, 225, 190), Color(4, 5, 9) },
    { Color(72, 225, 255), Color(255, 198, 72), Color(30, 42, 78) },
    { Color(114, 152, 214), Color(224, 230, 244), Color(12, 15, 28) },
    { Color(98, 232, 255), Color(245, 250, 255), Color(88, 112, 255) },
    { Color(68, 192, 94), Color(211, 225, 142), Color(13, 38, 22) },
}

local HERO_SIGNATURE_COLORS = {
    npc_dota_hero_axe = { Color(255, 40, 62), Color(255, 184, 98) },
    npc_dota_hero_juggernaut = { Color(255, 238, 214), Color(255, 64, 48) },
    npc_dota_hero_phantom_assassin = { Color(170, 74, 255), Color(92, 210, 255) },
    npc_dota_hero_zuus = { Color(78, 180, 255), Color(242, 251, 255) },
    npc_dota_hero_lina = { Color(255, 68, 24), Color(255, 218, 92) },
    npc_dota_hero_pudge = { Color(126, 218, 74), Color(208, 92, 74) },
    npc_dota_hero_invoker = { Color(80, 196, 255), Color(255, 104, 38) },
    npc_dota_hero_nevermore = { Color(204, 32, 42), Color(74, 18, 86) },
    npc_dota_hero_sniper = { Color(255, 170, 48), Color(232, 246, 255) },
    npc_dota_hero_templar_assassin = { Color(222, 66, 255), Color(90, 195, 255) },
    npc_dota_hero_rubick = { Color(64, 255, 142), Color(124, 74, 255) },
    npc_dota_hero_queenofpain = { Color(255, 38, 126), Color(118, 42, 255) },
}

local function config()
    local index = clamp(math.floor(UI.quality:Get() or 0) + 1, 1, #QUALITY)
    return QUALITY[index]
end

local function font_handle()
    local font_index = clamp(math.floor(UI.font:Get() or 0) + 1, 1, #FONT_NAMES)
    local weight_index = clamp(math.floor(UI.font_weight:Get() or 0) + 1, 1, #FONT_WEIGHTS)
    local key = tostring(font_index) .. ":" .. tostring(weight_index)
    local cached = STATE.font_cache[key]
    if cached then return cached end
    local handle = safe_call(Render.LoadFont, FONT_NAMES[font_index], Enum.FontCreate.FONTFLAG_ANTIALIAS, FONT_WEIGHTS[weight_index])
    if not handle then
        handle = safe_call(Render.LoadFont, "SF Pro Display", Enum.FontCreate.FONTFLAG_ANTIALIAS, 800) or 0
    end
    STATE.font_cache[key] = handle
    return handle
end

local function hero_name(hero)
    local name = safe_call(NPC.GetUnitName, hero)
    if type(name) == "string" then return name end
    return ""
end

local function owner_id(unit)
    local value = safe_call(NPC.GetPlayerOwnerID, unit)
    if type(value) == "number" then return value end
    return nil
end

local function source_is_local(source, me)
    if not source or not me then return false end
    if same_entity(source, me) then return true end
    local source_owner = owner_id(source)
    local my_owner = owner_id(me)
    return source_owner ~= nil and my_owner ~= nil and source_owner >= 0 and source_owner == my_owner
end

local function target_allowed(target)
    if not target or not safe_call(Entity.IsNPC, target) then return false end
    local me = Heroes.GetLocal()
    if not me then return false end
    if safe_call(NPC.IsIllusion, target) and not UI.illusions:Get() then return false end
    if safe_call(NPC.IsHero, target) then
        if same_entity(target, me) then return UI.self:Get() end
        if safe_call(Entity.IsSameTeam, me, target) then return UI.allies:Get() end
        return UI.enemies:Get()
    end
    return UI.creeps:Get()
end

local function source_allowed(source, target)
    local mode = math.floor(UI.source:Get() or 0)
    if mode == 0 then return true end
    local me = Heroes.GetLocal()
    if not me then return false end
    local mine = source_is_local(source, me)
    if mode == 1 then return mine or same_entity(target, me) end
    return mine
end

local function combat_position(target)
    local origin = entity_origin(target)
    if not origin then return nil end
    local offset = safe_call(NPC.GetHealthBarOffset, target) or 110
    return Vector(origin.x, origin.y, origin.z + offset + 20)
end

local function damage_color(kind, critical)
    if critical then return UI.crit:Get() end
    if kind == "magical" then return UI.magical:Get() end
    if kind == "pure" then return UI.pure:Get() end
    if kind == "heal" then return UI.heal:Get() end
    if kind == "miss" then return UI.miss:Get() end
    return UI.physical:Get()
end

local function material_colors(kind, critical)
    local index = clamp(math.floor(UI.material:Get() or 0) + 1, 1, #MATERIAL_COLORS)
    if index == #MATERIAL_COLORS then
        return UI.custom_primary:Get(), UI.custom_secondary:Get(), UI.custom_highlight:Get()
    end
    local palette = MATERIAL_COLORS[index]
    if not UI.material_auto:Get() then
        return UI.custom_primary:Get(), UI.custom_secondary:Get(), UI.custom_highlight:Get()
    end
    local base = damage_color(kind, critical)
    local influence = UI.material_mix:Get() / 100
    return mix(base, palette[1], influence), mix(base, palette[2], influence * 0.82), mix(palette[3], Color(255, 255, 255), 0.35)
end

local function trim_entries()
    local maximum = math.min(UI.maximum:Get(), config().maximum)
    while #STATE.entries > maximum do table.remove(STATE.entries, 1) end
end

local function chain_for(target, mine)
    if not mine or not UI.hit_combo:Get() then return 0 end
    local now = clock()
    local index = entity_index(target)
    local previous = STATE.hit_chains[index]
    local window = UI.combo_window:Get() / 1000
    local count = previous and now - previous.time <= window and previous.count + 1 or 1
    STATE.hit_chains[index] = { time = now, count = count }
    return count
end

local function add_combat(target, value, kind, critical, custom_text, source)
    if not UI.master:Get() or not target_allowed(target) or not source_allowed(source, target) then return end
    if kind == "heal" and not UI.healing:Get() then return end
    if kind == "miss" and not UI.misses:Get() then return end
    if kind ~= "heal" and kind ~= "miss" and not UI.damage:Get() then return end
    value = math.abs(tonumber(value) or 0)
    if kind ~= "miss" and UI.filter_small:Get() and value < UI.minimum:Get() then return end

    local now = clock()
    local index = entity_index(target)
    local me = Heroes.GetLocal()
    local mine = source_is_local(source, me)
    critical = critical or (UI.critical:Get() and kind ~= "heal" and kind ~= "miss" and value >= UI.critical_threshold:Get())
    local chain = chain_for(target, mine)

    if UI.merge:Get() and kind ~= "miss" then
        local window = UI.merge_window:Get() / 1000
        for i = #STATE.entries, 1, -1 do
            local entry = STATE.entries[i]
            if now - entry.t0 > window then break end
            if entry.index == index and entry.kind == kind and entry.mine == mine then
                entry.value = entry.value + value
                entry.critical = entry.critical or critical or (UI.critical:Get() and entry.value >= UI.critical_threshold:Get())
                entry.chain = math.max(entry.chain or 0, chain)
                entry.t0 = now
                entry.pos = combat_position(target) or entry.pos
                return
            end
        end
    end

    local position = combat_position(target)
    if not position then return end
    STATE.entries[#STATE.entries + 1] = {
        t0 = now,
        pos = position,
        index = index,
        value = value,
        kind = kind,
        critical = critical,
        text = custom_text,
        seed = index * 17.13 + now * 71.7,
        chain = chain,
        mine = mine,
        hero = mine and hero_name(me) or "",
    }
    trim_entries()
end

local function formatted_value(entry)
    if entry.text then return entry.text end
    local value = entry.value
    local text
    if UI.abbreviate:Get() and value >= 1000000 then
        text = string.format("%.2fM", value / 1000000)
    elseif UI.abbreviate:Get() and value >= 1000 then
        text = string.format("%.1fK", value / 1000)
    else
        text = tostring(math.floor(value + 0.5))
    end
    if entry.kind == "heal" then text = "+" .. text end
    if entry.kind == "miss" then text = "MISS" end
    if UI.symbols:Get() then
        if entry.kind == "magical" then text = "✦ " .. text
        elseif entry.kind == "pure" then text = "◆ " .. text
        elseif entry.critical then text = text .. " !" end
    end
    return text
end

local function text_motion(entry, progress)
    local animation = math.floor(UI.animation:Get() or 0)
    local speed = UI.speed:Get() / 100
    local rise = UI.rise:Get()
    local spread = UI.spread:Get()
    local fixed_spread = (seeded(entry.seed, 2) - 0.5) * spread * 2
    local x, y, scale = fixed_spread, -ease_out(progress) * rise, 1
    if animation == 1 then
        local impact = 1 - ease_out(clamp01(progress / 0.22))
        scale = 1 + impact * (entry.critical and 0.58 or 0.3)
        x = fixed_spread * (0.35 + progress * 0.65)
        y = -rise * smooth(progress) + math.sin(progress * math.pi) * 10
    elseif animation == 2 then
        local direction = seeded(entry.seed, 8) > 0.5 and 1 or -1
        x = direction * spread * (0.28 + progress * 0.95)
        y = -rise * progress + rise * 0.42 * progress * progress
        scale = 1 + math.sin(progress * math.pi) * 0.12
    elseif animation == 3 then
        local radius = spread * (1 - progress) * 0.75
        local angle = progress * TAU * speed * 1.4 + entry.seed
        x = math.cos(angle) * radius
        y = -ease_out(progress) * rise + math.sin(angle) * radius * 0.45
        scale = 1 + (1 - progress) * 0.18
    elseif animation == 4 then
        local step = math.floor(progress * (8 + speed * 8))
        x = fixed_spread + (seeded(entry.seed, step + 50) - 0.5) * spread * 0.55 * (1 - progress)
        y = -ease_out(progress) * rise + (seeded(entry.seed, step + 90) - 0.5) * 10
        scale = 1 + (step % 3 == 0 and 0.14 or 0)
    elseif animation == 5 then
        x = fixed_spread * 0.45 + math.sin(progress * math.pi * 2) * 3
        y = -rise * smooth(progress) * 0.62
        scale = 0.84 + ease_out(clamp01(progress / 0.18)) * 0.16
    end
    return x, y, scale
end

local function outline_text(font, size, text, position, color, opacity, thickness, count)
    if thickness <= 0 then return end
    local radius = math.max(0.7, thickness)
    for direction = 1, count do
        local angle = direction / count * TAU
        Render.Text(font, size, text, Vec2(position.x + math.cos(angle) * radius, position.y + math.sin(angle) * radius), alpha(color, opacity))
    end
end

local function draw_material(entry, font, size, text, position, text_size, opacity, cfg, center)
    local material = clamp(math.floor(UI.material:Get() or 0), 0, #MATERIAL_NAMES - 1)
    local primary, secondary, highlight = material_colors(entry.kind, entry.critical)
    local intensity = UI.material_intensity:Get() / 100
    local bloom = UI.bloom:Get() / 100
    local gloss = UI.gloss:Get() / 100
    local outline = UI.outline:Get()
    local time = clock()

    if UI.shadow:Get() then
        Render.Text(font, size, text, Vec2(position.x + 2 + outline * 0.35, position.y + 3 + outline * 0.45), alpha(Color(0, 0, 0), opacity * 0.72))
    end

    if material == 0 then
        if bloom > 0 and cfg.quality >= 2 then soft_aura(center, math.max(text_size.x, text_size.y) * 0.34 * bloom, primary, opacity * 0.38 * intensity, cfg.quality + 1) end
        outline_text(font, size, text, position, mix(primary, secondary, 0.5), opacity * 0.18 * bloom, outline + 2.4, cfg.outline)
        if cfg.quality >= 3 then
            Render.Text(font, size, text, Vec2(position.x - 1.2, position.y), alpha(secondary, opacity * 0.38 * intensity))
            Render.Text(font, size, text, Vec2(position.x + 1.2, position.y), alpha(primary, opacity * 0.38 * intensity))
        end
        Render.Text(font, size, text, position, alpha(mix(primary, highlight, 0.42 * gloss), opacity))
        silk_line(Vec2(position.x + 2, position.y + text_size.y + 1), Vec2(position.x + text_size.x - 2, position.y + text_size.y + 1), primary, secondary, opacity * 0.66 * intensity, math.max(0.65, size * 0.045), cfg.quality)
    elseif material == 1 then
        outline_text(font, size, text, position, Color(62, 30, 4), opacity * 0.84, outline + 1.8, cfg.outline)
        if bloom > 0 then soft_aura(center, text_size.x * 0.24 * bloom, primary, opacity * 0.3 * intensity, cfg.quality) end
        Render.Text(font, size, text, Vec2(position.x, position.y + 1), alpha(mix(primary, secondary, 0.32), opacity))
        Render.Text(font, size, text, Vec2(position.x, position.y - 1), alpha(mix(secondary, highlight, 0.48 * gloss), opacity * 0.72))
        local sweep = (time * 0.9 + entry.seed) % 1
        glint(Vec2(position.x + text_size.x * sweep, center.y), 4 + size * 0.18 * gloss, highlight, opacity * intensity * (1 - math.abs(sweep - 0.5) * 1.4), cfg.quality)
    elseif material == 2 then
        outline_text(font, size, text, position, Color(0, 0, 0), opacity, outline + 2.8, cfg.outline)
        Render.Text(font, size, text, position, alpha(mix(primary, Color(8, 8, 13), 0.58), opacity))
        Render.Text(font, size, text, Vec2(position.x, position.y - 1), alpha(mix(secondary, highlight, 0.42 * gloss), opacity * 0.76))
        silk_line(Vec2(position.x - 3, position.y + text_size.y * 0.18), Vec2(position.x + text_size.x + 3, position.y + text_size.y * 0.82), secondary, highlight, opacity * 0.56 * intensity, math.max(0.7, size * 0.035), cfg.quality)
    elseif material == 3 then
        outline_text(font, size, text, position, Color(7, 20, 32), opacity * 0.7, outline + 1.3, cfg.outline)
        Render.Text(font, size, text, Vec2(position.x - 1.8, position.y), alpha(primary, opacity * 0.58))
        Render.Text(font, size, text, Vec2(position.x + 1.8, position.y), alpha(secondary, opacity * 0.58))
        Render.Text(font, size, text, position, alpha(highlight, opacity * 0.86))
        local scan_count = 1 + cfg.quality
        for scan = 1, scan_count do
            local phase = (time * (0.55 + scan * 0.11) + seeded(entry.seed, scan + 800)) % 1
            local y = position.y + phase * text_size.y
            local length = text_size.x * (0.18 + seeded(entry.seed, scan + 840) * 0.38)
            local x = position.x + seeded(entry.seed, scan + 880) * math.max(1, text_size.x - length)
            silk_line(Vec2(x, y), Vec2(x + length, y), scan % 2 == 0 and primary or secondary, highlight, opacity * 0.4 * intensity, math.max(0.55, size * 0.022), cfg.quality)
        end
    elseif material == 4 then
        if bloom > 0 then soft_aura(center, text_size.x * 0.2 * bloom, primary, opacity * 0.28 * intensity, cfg.quality) end
        outline_text(font, size, text, position, mix(primary, Color(26, 68, 105), 0.55), opacity * 0.82, outline + 1.5, cfg.outline)
        Render.Text(font, size, text, position, alpha(mix(primary, highlight, 0.64), opacity))
        Render.Text(font, size, text, Vec2(position.x, position.y - 1), alpha(highlight, opacity * 0.62 * gloss))
        for particle = 1, cfg.material_particles do
            local phase = (time * (0.13 + seeded(entry.seed, particle + 900) * 0.24) + seeded(entry.seed, particle + 940)) % 1
            local x = position.x + seeded(entry.seed, particle + 980) * text_size.x
            local y = position.y - 5 + phase * (text_size.y + 10)
            glow_dot(Vec2(x, y), 0.6 + seeded(entry.seed, particle + 1020) * 1.2, mix(primary, highlight, seeded(entry.seed, particle + 1060)), opacity * (1 - phase) * 0.52 * intensity, math.min(3, cfg.quality))
        end
    elseif material == 5 then
        outline_text(font, size, text, position, Color(34, 0, 9), opacity * 0.9, outline + 1.8, cfg.outline)
        Render.Text(font, size, text, Vec2(position.x - 1, position.y + 1), alpha(secondary, opacity * 0.72))
        Render.Text(font, size, text, position, alpha(mix(primary, highlight, 0.18 * gloss), opacity))
        local drips = math.max(2, math.floor(cfg.material_particles * 0.34))
        for drip = 1, drips do
            local x = position.x + seeded(entry.seed, drip + 1100) * text_size.x
            local length = (3 + seeded(entry.seed, drip + 1140) * 15) * intensity
            silk_line(Vec2(x, position.y + text_size.y * 0.66), Vec2(x + (seeded(entry.seed, drip + 1180) - 0.5) * 3, position.y + text_size.y + length), primary, secondary, opacity * intensity * (0.22 + seeded(entry.seed, drip + 1220) * 0.42), 0.55 + seeded(entry.seed, drip + 1260) * 0.7, cfg.quality)
        end
    elseif material == 6 then
        if bloom > 0 then soft_aura(center, text_size.x * 0.26 * bloom, mix(primary, secondary, 0.5), opacity * 0.32 * intensity, cfg.quality) end
        outline_text(font, size, text, position, mix(primary, Color(12, 2, 28), 0.62), opacity * 0.78, outline + 1.5, cfg.outline)
        Render.Text(font, size, text, position, alpha(mix(primary, highlight, 0.4 * gloss), opacity))
        local facets = math.max(3, math.floor(cfg.material_particles * 0.42))
        for facet = 1, facets do
            local angle = seeded(entry.seed, facet + 1300) * TAU
            local inner = text_size.x * 0.36
            local outer = inner + (4 + seeded(entry.seed, facet + 1340) * 18) * intensity
            silk_line(
                Vec2(center.x + math.cos(angle) * inner, center.y + math.sin(angle) * inner * 0.45),
                Vec2(center.x + math.cos(angle) * outer, center.y + math.sin(angle) * outer * 0.55),
                facet % 2 == 0 and primary or secondary,
                highlight,
                opacity * intensity * (0.18 + seeded(entry.seed, facet + 1380) * 0.32),
                0.55 + seeded(entry.seed, facet + 1420) * 0.6,
                cfg.quality
            )
        end
    elseif material == 7 then
        outline_text(font, size, text, position, Color(20, 26, 36), opacity * 0.9, outline + 1.8, cfg.outline)
        Render.Text(font, size, text, Vec2(position.x, position.y + 1), alpha(mix(primary, Color(35, 42, 54), 0.5), opacity))
        Render.Text(font, size, text, position, alpha(mix(secondary, highlight, 0.34), opacity))
        local sweep = (time * 0.72 + entry.seed) % 1
        local sweep_x = position.x + sweep * text_size.x
        silk_line(Vec2(sweep_x - 2, position.y), Vec2(sweep_x + 2, position.y + text_size.y), highlight, secondary, opacity * intensity * gloss * (1 - math.abs(sweep - 0.5) * 0.8), math.max(0.6, size * 0.055), cfg.quality)
        if bloom > 0 and cfg.quality >= 3 then soft_aura(Vec2(sweep_x, center.y), size * 0.32 * bloom, highlight, opacity * 0.23, cfg.quality) end
    else
        if bloom > 0 then soft_aura(center, text_size.x * 0.22 * bloom, primary, opacity * 0.3 * intensity, cfg.quality) end
        outline_text(font, size, text, position, mix(primary, Color(0, 0, 0), 0.75), opacity * 0.84, outline + 1.5, cfg.outline)
        Render.Text(font, size, text, position, alpha(mix(primary, highlight, 0.24 * gloss), opacity))
        silk_line(Vec2(position.x, position.y + text_size.y + 1), Vec2(position.x + text_size.x, position.y + text_size.y + 1), primary, secondary, opacity * 0.64 * intensity, math.max(0.6, size * 0.04), cfg.quality)
    end

    return primary, secondary, highlight
end

local function draw_critical(entry, center, text_size, opacity, cfg, primary, secondary)
    if not entry.critical or not UI.critical:Get() then return end
    local progress = clamp01((clock() - entry.t0) / (UI.duration:Get() / 1000))
    if UI.critical_ring:Get() then
        local radius = text_size.x * (0.42 + ease_out(progress) * 0.72)
        Render.Circle(center, radius, alpha(primary, opacity * (1 - progress) * 0.26), math.max(1, text_size.y * 0.1), clock() * 95 % 360, 0.78, true, 56 + cfg.quality * 12)
        Render.Circle(center, radius + 3, alpha(secondary, opacity * (1 - progress) * 0.68), math.max(0.8, text_size.y * 0.028), -clock() * 120 % 360, 0.66, true, 56 + cfg.quality * 12)
    end
    local shard_count = math.floor(cfg.crit_shards * UI.fracture:Get() / 100)
    for shard = 1, shard_count do
        local angle = seeded(entry.seed, shard + 1500) * TAU
        local inner = text_size.x * (0.48 + progress * 0.2)
        local outer = inner + (8 + seeded(entry.seed, shard + 1540) * 28) * (1 - progress)
        silk_line(
            Vec2(center.x + math.cos(angle) * inner, center.y + math.sin(angle) * inner * 0.52),
            Vec2(center.x + math.cos(angle) * outer, center.y + math.sin(angle) * outer * 0.62),
            shard % 2 == 0 and primary or secondary,
            Color(255, 255, 255),
            opacity * (1 - progress) * (0.35 + seeded(entry.seed, shard + 1580) * 0.55),
            0.6 + seeded(entry.seed, shard + 1620) * 0.8,
            cfg.quality
        )
    end
end

local function signature_palette(name, fallback_primary, fallback_secondary)
    local palette = HERO_SIGNATURE_COLORS[name]
    if palette then return palette[1], palette[2] end
    return fallback_primary, fallback_secondary
end

local function lightning_branch(start_point, angle, length, segments, seed, primary, secondary, opacity, width, quality)
    local previous = start_point
    for segment = 1, segments do
        local progress = segment / segments
        local distance = length * progress
        local jitter = (seeded(seed, segment + 1700) - 0.5) * length * 0.16 * (1 - progress * 0.45)
        local point = Vec2(
            start_point.x + math.cos(angle) * distance - math.sin(angle) * jitter,
            start_point.y + math.sin(angle) * distance + math.cos(angle) * jitter
        )
        silk_line(previous, point, primary, secondary, opacity * (1 - progress * 0.32), width * (1 - progress * 0.45), quality)
        previous = point
    end
end

local function draw_hero_signature(name, center, radius, opacity, cfg, fallback_primary, fallback_secondary, seed)
    if not UI.hero_signature:Get() or name == "" then return end
    local primary, secondary = signature_palette(name, fallback_primary, fallback_secondary)
    local intensity = UI.signature_intensity:Get() / 100
    opacity = opacity * intensity
    radius = radius * (0.82 + math.sqrt(intensity) * 0.18)
    local time = clock()
    local detail = cfg.signature

    if name == "npc_dota_hero_axe" then
        for slash = 1, math.max(2, math.floor(detail * 0.24)) do
            local offset = (slash - 1) * 5 - detail * 0.5
            silk_line(Vec2(center.x - radius - offset, center.y - radius * 0.45), Vec2(center.x + radius + offset, center.y + radius * 0.42), primary, secondary, opacity * (0.48 + slash * 0.07), 1.1 + slash * 0.16, cfg.quality)
        end
    elseif name == "npc_dota_hero_juggernaut" then
        for arc = 1, math.max(2, math.floor(detail * 0.18)) do
            ellipse_arc(center, radius * (0.66 + arc * 0.08), radius * (0.32 + arc * 0.04), time * 1.8 + arc, math.pi * 1.18, 12 + cfg.quality * 5, -0.22, primary, secondary, opacity * (0.3 + arc * 0.07), 0.75 + arc * 0.08, cfg.quality)
        end
    elseif name == "npc_dota_hero_phantom_assassin" then
        for blade = 1, detail do
            local angle = seeded(seed, blade + 1800) * TAU
            local length = radius * (0.3 + seeded(seed, blade + 1840) * 0.72)
            local point = Vec2(center.x + math.cos(angle) * radius * 0.42, center.y + math.sin(angle) * radius * 0.28)
            silk_line(point, Vec2(point.x + math.cos(angle) * length, point.y + math.sin(angle) * length * 0.55), primary, secondary, opacity * (0.12 + seeded(seed, blade + 1880) * 0.46), 0.5 + seeded(seed, blade + 1920) * 0.8, cfg.quality)
        end
    elseif name == "npc_dota_hero_zuus" then
        local branches = math.max(2, math.floor(detail * 0.18))
        for branch = 1, branches do
            local angle = -math.pi * 0.78 + branch / (branches + 1) * math.pi * 0.56
            lightning_branch(center, angle, radius * (0.85 + branch * 0.08), 5 + cfg.quality, seed + branch * 13, primary, secondary, opacity * 0.74, 1.2, cfg.quality)
        end
    elseif name == "npc_dota_hero_lina" then
        for flame = 1, detail do
            local angle = seeded(seed, flame + 1960) * TAU
            local phase = (time * (0.42 + seeded(seed, flame + 2000)) + seeded(seed, flame + 2040)) % 1
            local start_point = Vec2(center.x + math.cos(angle) * radius * 0.44, center.y + math.sin(angle) * radius * 0.24)
            local end_point = Vec2(start_point.x + math.sin(time * 3 + flame) * radius * 0.16, start_point.y - radius * (0.24 + phase * 0.54))
            silk_line(start_point, end_point, primary, secondary, opacity * (1 - phase) * 0.52, 0.6 + seeded(seed, flame + 2080) * 0.8, cfg.quality)
        end
    elseif name == "npc_dota_hero_pudge" then
        local links = math.max(5, math.floor(detail * 0.55))
        for link = 1, links do
            local progress = link / links
            local angle = progress * math.pi * 1.25 + time * 0.55
            local point = Vec2(center.x + math.cos(angle) * radius * progress, center.y + math.sin(angle) * radius * progress * 0.5)
            Render.Circle(point, 2.3 + cfg.quality * 0.34, alpha(link % 2 == 0 and primary or secondary, opacity * (0.3 + progress * 0.5)), 0.7, angle * 57.3, 0.72, true, 14)
        end
    elseif name == "npc_dota_hero_invoker" then
        local colors = { Color(90, 205, 255), Color(170, 110, 255), Color(255, 112, 38) }
        for orb = 1, 3 do
            local angle = time * (0.8 + orb * 0.12) + orb / 3 * TAU
            local point = Vec2(center.x + math.cos(angle) * radius * 0.72, center.y + math.sin(angle) * radius * 0.38)
            glow_dot(point, 2.8 + cfg.quality * 0.7, colors[orb], opacity * 0.82, cfg.quality)
        end
    elseif name == "npc_dota_hero_nevermore" then
        for soul = 1, detail do
            local angle = seeded(seed, soul + 2120) * TAU + time * 0.24
            local orbit = radius * (0.35 + seeded(seed, soul + 2160) * 0.62)
            local point = Vec2(center.x + math.cos(angle) * orbit, center.y + math.sin(angle) * orbit * 0.48)
            silk_line(point, center, primary, secondary, opacity * (0.08 + seeded(seed, soul + 2200) * 0.22), 0.45 + seeded(seed, soul + 2240) * 0.42, cfg.quality)
            if soul % 3 == 0 then glow_dot(point, 1.1 + seeded(seed, soul + 2280) * 1.8, primary, opacity * 0.5, cfg.quality) end
        end
    elseif name == "npc_dota_hero_sniper" then
        Render.Circle(center, radius * 0.74, alpha(primary, opacity * 0.62), 1.2, time * 42 % 360, 0.76, true, 48)
        local gap = radius * 0.26
        silk_line(Vec2(center.x - radius, center.y), Vec2(center.x - gap, center.y), primary, secondary, opacity * 0.82, 0.9, cfg.quality)
        silk_line(Vec2(center.x + gap, center.y), Vec2(center.x + radius, center.y), primary, secondary, opacity * 0.82, 0.9, cfg.quality)
        silk_line(Vec2(center.x, center.y - radius * 0.62), Vec2(center.x, center.y - gap * 0.62), secondary, primary, opacity * 0.72, 0.8, cfg.quality)
    elseif name == "npc_dota_hero_templar_assassin" then
        for psi = 1, math.max(4, math.floor(detail * 0.35)) do
            local angle = psi / math.max(4, math.floor(detail * 0.35)) * TAU + time * 0.42
            local start_point = Vec2(center.x + math.cos(angle) * radius * 0.42, center.y + math.sin(angle) * radius * 0.3)
            local end_point = Vec2(center.x + math.cos(angle) * radius, center.y + math.sin(angle) * radius * 0.56)
            silk_line(start_point, end_point, psi % 2 == 0 and primary or secondary, Color(255, 255, 255), opacity * 0.5, 0.75, cfg.quality)
        end
    elseif name == "npc_dota_hero_rubick" then
        for arc = 1, math.max(2, math.floor(detail * 0.12)) do
            ellipse_arc(center, radius * (0.42 + arc * 0.12), radius * (0.25 + arc * 0.07), time * (0.52 + arc * 0.08), math.pi * (0.6 + arc * 0.18), 10 + cfg.quality * 4, arc * 0.22, primary, secondary, opacity * (0.26 + arc * 0.08), 0.72, cfg.quality)
        end
    elseif name == "npc_dota_hero_queenofpain" then
        for wave = 1, math.max(2, math.floor(detail * 0.14)) do
            local radius_x = radius * (0.46 + wave * 0.14)
            ellipse_arc(center, radius_x, radius_x * 0.34, -math.pi * 0.84, math.pi * 1.68, 12 + cfg.quality * 4, 0, wave % 2 == 0 and primary or secondary, Color(255, 220, 245), opacity * (0.24 + wave * 0.07), 0.8, cfg.quality)
        end
    end
end

local function draw_type_badge(entry, center, text_size, opacity, primary, font)
    if not UI.type_badge:Get() then return end
    local labels = { physical = "PHYS", magical = "MAGIC", pure = "PURE", heal = "HEAL", miss = "EVADE" }
    local label = labels[entry.kind] or "HIT"
    local size = clamp(math.floor(text_size.y * 0.34), 8, 14)
    local measure = Render.TextSize(font, size, label)
    local position = Vec2(center.x - measure.x * 0.5, center.y + text_size.y * 0.66)
    Render.FilledRect(Vec2(position.x - 5, position.y - 2), Vec2(position.x + measure.x + 5, position.y + measure.y + 2), alpha(Color(5, 8, 16), opacity * 0.56), 5)
    Render.Text(font, size, label, position, alpha(mix(primary, Color(255, 255, 255), 0.42), opacity * 0.76))
end

local function draw_combo(entry, center, text_size, opacity, secondary, font)
    if not UI.hit_combo:Get() or not entry.chain or entry.chain < 2 then return end
    local label = "×" .. tostring(entry.chain)
    local size = clamp(math.floor(text_size.y * 0.48), 10, 20)
    local measure = Render.TextSize(font, size, label)
    local position = Vec2(center.x + text_size.x * 0.55, center.y - text_size.y * 0.55)
    soft_aura(Vec2(position.x + measure.x * 0.5, position.y + measure.y * 0.5), measure.x * 0.45, secondary, opacity * 0.28, 2)
    Render.Text(font, size, label, position, alpha(secondary, opacity))
end

local function draw_combat()
    local now = clock()
    local duration = UI.duration:Get() / 1000 / math.max(0.25, UI.speed:Get() / 100)
    local cfg = config()
    local font = font_handle()
    local base_opacity = UI.opacity:Get() / 100
    for i = #STATE.entries, 1, -1 do
        local entry = STATE.entries[i]
        local age = now - entry.t0
        if age >= duration then
            table.remove(STATE.entries, i)
        else
            local progress = clamp01(age / duration)
            local screen, visible = world_to_screen(entry.pos)
            if visible then
                local enter = ease_out(clamp01(progress / 0.12))
                local fade = 1 - smooth(clamp01((progress - 0.58) / 0.42))
                local opacity = 255 * enter * fade * base_opacity
                local offset_x, offset_y, motion_scale = text_motion(entry, progress)
                if entry.critical then
                    local shake = UI.shake:Get() * (1 - progress)
                    offset_x = offset_x + math.sin(now * 97 + entry.seed) * shake
                    offset_y = offset_y + math.cos(now * 83 + entry.seed) * shake * 0.72
                end
                local critical_scale = entry.critical and UI.font_scale_crit:Get() / 100 or 1
                local size = math.floor(UI.font_size:Get() * motion_scale * critical_scale + 0.5)
                local text = formatted_value(entry)
                local text_size = Render.TextSize(font, size, text)
                local center = Vec2(screen.x + offset_x, screen.y + offset_y)
                local position = Vec2(center.x - text_size.x * 0.5, center.y - text_size.y * 0.5)

                if UI.echo:Get() and cfg.echoes > 0 then
                    for echo = cfg.echoes, 1, -1 do
                        local distance = echo * (2.2 + UI.speed:Get() / 85)
                        local echo_position = Vec2(position.x - offset_x * 0.025 * echo, position.y + distance)
                        local echo_primary = damage_color(entry.kind, entry.critical)
                        Render.Text(font, size, text, echo_position, alpha(echo_primary, opacity * (0.055 + echo * 0.025)))
                    end
                end

                local primary, secondary = draw_material(entry, font, size, text, position, text_size, opacity, cfg, center)
                draw_type_badge(entry, center, text_size, opacity, primary, font)
                draw_combo(entry, center, text_size, opacity, secondary, font)
                draw_critical(entry, center, text_size, opacity, cfg, primary, secondary)
                if entry.mine and (entry.critical or entry.value >= UI.signature_threshold:Get()) then
                    draw_hero_signature(entry.hero, center, math.max(text_size.x, text_size.y) * 0.78, opacity * (1 - progress * 0.42), cfg, primary, secondary, entry.seed)
                end
            end
        end
    end
end

local function damage_kind(data)
    local raw = data and (data.damage_type or data.damageType)
    if raw == Enum.DamageTypes.DAMAGE_TYPE_MAGICAL then return "magical" end
    if raw == Enum.DamageTypes.DAMAGE_TYPE_PURE then return "pure" end
    if data and data.ability then
        local value = safe_call(Ability.GetDamageType, data.ability)
        if value == Enum.DamageTypes.DAMAGE_TYPE_MAGICAL then return "magical" end
        if value == Enum.DamageTypes.DAMAGE_TYPE_PURE then return "pure" end
    end
    return "physical"
end

local function scan_health()
    local now = clock()
    if now < STATE.next_scan then return end
    STATE.next_scan = now + config().scan
    local list = NPCs.GetInScreen and NPCs.GetInScreen(nil, true) or {}
    for _, item in pairs(list) do
        local target = item.entity or item
        if target and safe_call(Entity.IsNPC, target) then
            local index = entity_index(target)
            local health = safe_call(Entity.GetHealth, target)
            if index >= 0 and type(health) == "number" then
                local cached = STATE.health[index]
                if cached and target_allowed(target) then
                    local difference = health - cached.health
                    if difference < 0 then
                        local amount = -difference
                        local exact = STATE.exact[index]
                        local duplicate = exact and now - exact.time < 0.2 and math.abs(exact.value - amount) <= math.max(3, amount * 0.18)
                        if not duplicate then add_combat(target, amount, "physical", false, nil, nil) end
                    elseif difference > 0 then
                        add_combat(target, difference, "heal", false, nil, nil)
                    end
                end
                STATE.health[index] = { health = health, seen = now }
            end
        end
    end
    for index, cached in pairs(STATE.health) do
        if now - cached.seen > 3 then
            STATE.health[index] = nil
            STATE.exact[index] = nil
            STATE.hit_chains[index] = nil
        end
    end
end

local function kill_colors(style)
    local palette = KILL_COLORS[style + 1] or KILL_COLORS[1]
    if UI.kill_auto_colors:Get() then return palette[1], palette[2], palette[3] end
    return UI.kill_primary:Get(), UI.kill_secondary:Get(), mix(UI.kill_primary:Get(), Color(0, 0, 0), 0.78)
end

local function victim_label(name)
    if type(name) ~= "string" or name == "" then return "ENEMY HERO" end
    name = name:gsub("^npc_dota_hero_", ""):gsub("^npc_dota_", ""):gsub("_", " ")
    return name:upper()
end

local function valid_particle(id)
    return type(id) == "number" and id >= 0
end

local function spawn_kill_particle(style, victim)
    local cfg = config()
    if not UI.kill_engine:Get() or not cfg.engine or not Particle or not Particle.Create then return end
    local path = KILL_PARTICLES[style + 1]
    if not path then return end
    local id = safe_call(Particle.Create, path, Enum.ParticleAttachment.PATTACH_ABSORIGIN_FOLLOW, victim)
    if valid_particle(id) then
        STATE.particles[#STATE.particles + 1] = { id = id, die = clock() + 4.5 }
    end
end

local function add_kill(victim)
    local now = clock()
    if now - STATE.last_kill <= UI.kill_streak_window:Get() then
        STATE.kill_count = STATE.kill_count + 1
    else
        STATE.kill_count = 1
    end
    STATE.last_kill = now
    local selected = clamp(math.floor(UI.kill_style:Get() or 0), 0, 5)
    local style = selected == 5 and math.floor(seeded(now * 91 + entity_index(victim), 1) * 5) or selected
    style = clamp(style, 0, 4)
    local origin = entity_origin(victim)
    if not origin then return end
    local offset = safe_call(NPC.GetHealthBarOffset, victim) or 120
    local me = Heroes.GetLocal()
    STATE.kills[#STATE.kills + 1] = {
        t0 = now,
        pos = Vector(origin.x, origin.y, origin.z + offset * 0.48),
        style = style,
        seed = now * 617 + entity_index(victim) * 37,
        streak = STATE.kill_count,
        victim = victim_label(hero_name(victim)),
        hero = hero_name(me),
    }
    while #STATE.kills > UI.kill_maximum:Get() do table.remove(STATE.kills, 1) end
    spawn_kill_particle(style, victim)
end

local function draw_ink_verdict(effect, center, progress, opacity, scale, cfg, primary, secondary, dark)
    local reveal = ease_out(clamp01(progress / 0.28))
    local fade = 1 - smooth(clamp01((progress - 0.66) / 0.34))
    local radius = 82 * scale * (0.68 + reveal * 0.32)
    soft_aura(center, radius * 0.72, dark, opacity * fade * 0.86, cfg.quality + 1)
    local strokes = 3 + cfg.quality
    for stroke = 1, strokes do
        local factor = stroke / strokes
        local rotation = -0.58 + factor * 1.14 + math.sin(effect.seed + stroke) * 0.08
        local start_angle = -math.pi * (0.88 + factor * 0.12)
        local span = math.pi * (0.92 + factor * 0.36) * reveal
        ellipse_arc(
            center,
            radius * (0.46 + factor * 0.52),
            radius * (0.16 + factor * 0.18),
            start_angle,
            span,
            10 + cfg.quality * 5,
            rotation,
            stroke % 2 == 0 and primary or secondary,
            Color(255, 255, 245),
            opacity * fade * (0.24 + factor * 0.48),
            (0.65 + factor * 1.35) * scale,
            cfg.quality
        )
    end
    local vertical_top = Vec2(center.x + radius * 0.08, center.y - radius * 0.72 * reveal)
    local vertical_bottom = Vec2(center.x - radius * 0.12, center.y + radius * 0.68 * reveal)
    Render.Line(vertical_top, vertical_bottom, alpha(dark, opacity * fade * 0.82), 7 * scale)
    silk_line(vertical_top, vertical_bottom, primary, secondary, opacity * fade * 0.78, 1.25 * scale, cfg.quality)
    local cross_left = Vec2(center.x - radius * 0.62 * reveal, center.y + radius * 0.1)
    local cross_right = Vec2(center.x + radius * 0.58 * reveal, center.y - radius * 0.16)
    Render.Line(cross_left, cross_right, alpha(dark, opacity * fade * 0.74), 5.5 * scale)
    silk_line(cross_left, cross_right, secondary, primary, opacity * fade * 0.7, 1.05 * scale, cfg.quality)
    local count = math.floor(cfg.kill_particles * UI.kill_density:Get() / 100)
    for particle = 1, count do
        local born = seeded(effect.seed, particle + 2300) * 0.22
        local life = 0.52 + seeded(effect.seed, particle + 2340) * 0.42
        local phase = (progress - born) / life
        if phase >= 0 and phase < 1 then
            local angle = seeded(effect.seed, particle + 2380) * TAU
            local distance = radius * (0.22 + seeded(effect.seed, particle + 2420) * 0.9) * ease_out(phase)
            local x = center.x + math.cos(angle) * distance
            local y = center.y + math.sin(angle) * distance * 0.46 + radius * phase * phase * 0.24
            local previous_phase = math.max(0, phase - 0.05)
            local previous_distance = radius * (0.22 + seeded(effect.seed, particle + 2420) * 0.9) * ease_out(previous_phase)
            local previous = Vec2(center.x + math.cos(angle) * previous_distance, center.y + math.sin(angle) * previous_distance * 0.46 + radius * previous_phase * previous_phase * 0.24)
            local color = particle % 3 == 0 and secondary or dark
            Render.Line(previous, Vec2(x, y), alpha(color, opacity * fade * (1 - phase) * 0.58), (0.8 + seeded(effect.seed, particle + 2460) * 1.9) * scale)
            if particle % 7 == 0 then
                Render.FilledCircle(Vec2(x, y), (0.8 + seeded(effect.seed, particle + 2480) * 2.3) * scale, alpha(primary, opacity * fade * (1 - phase) * 0.62), 0, 1, 12)
            end
        end
    end
end

local function draw_chrono_execution(effect, center, progress, opacity, scale, cfg, primary, secondary, dark)
    local reveal = ease_out(clamp01(progress / 0.28))
    local fade = 1 - smooth(clamp01((progress - 0.68) / 0.32))
    local radius = 82 * scale * (0.76 + reveal * 0.24)
    soft_aura(center, radius * 0.5, dark, opacity * fade * 0.62, cfg.quality)
    for echo = 1, 1 + cfg.quality do
        local echo_progress = clamp01(progress - (echo - 1) * 0.055)
        local echo_radius = radius * (0.5 + ease_out(echo_progress) * (0.42 + echo * 0.07))
        Render.Circle(center, echo_radius, alpha(echo % 2 == 0 and primary or secondary, opacity * fade * (0.2 + echo * 0.08)), math.max(0.7, scale * (2.2 - echo * 0.22)), clock() * (echo % 2 == 0 and -38 or 54) % 360, 0.72, true, cfg.kill_segments)
    end
    for tick = 1, 12 do
        local angle = tick / 12 * TAU - math.pi * 0.5
        local inner = radius * (tick % 3 == 0 and 0.72 or 0.78)
        local outer = radius * 0.92
        silk_line(
            Vec2(center.x + math.cos(angle) * inner, center.y + math.sin(angle) * inner),
            Vec2(center.x + math.cos(angle) * outer, center.y + math.sin(angle) * outer),
            tick % 3 == 0 and secondary or primary,
            Color(255, 255, 255),
            opacity * fade * (tick % 3 == 0 and 0.86 or 0.5),
            (tick % 3 == 0 and 1.2 or 0.7) * scale,
            cfg.quality
        )
    end
    local reverse = 1 - smooth(progress)
    local minute_angle = -math.pi * 0.5 + reverse * TAU * 1.8
    local hour_angle = -math.pi * 0.5 - reverse * TAU * 0.72
    silk_line(center, Vec2(center.x + math.cos(minute_angle) * radius * 0.63, center.y + math.sin(minute_angle) * radius * 0.63), primary, Color(255, 255, 255), opacity * fade, 1.5 * scale, cfg.quality)
    silk_line(center, Vec2(center.x + math.cos(hour_angle) * radius * 0.43, center.y + math.sin(hour_angle) * radius * 0.43), secondary, Color(255, 255, 255), opacity * fade, 2.1 * scale, cfg.quality)
    glow_dot(center, 3.5 * scale, secondary, opacity * fade, cfg.quality)
    local count = math.floor(cfg.kill_particles * UI.kill_density:Get() / 100)
    for particle = 1, count do
        local angle = seeded(effect.seed, particle + 2500) * TAU + clock() * (0.2 + seeded(effect.seed, particle + 2540) * 0.45)
        local orbit = radius * (0.22 + seeded(effect.seed, particle + 2580) * 0.88)
        local point = Vec2(center.x + math.cos(angle) * orbit, center.y + math.sin(angle) * orbit * 0.62)
        glow_dot(point, 0.7 + seeded(effect.seed, particle + 2620) * 1.3, particle % 2 == 0 and primary or secondary, opacity * fade * 0.42, math.min(3, cfg.quality))
    end
end

local function draw_soul_cage(effect, center, progress, opacity, scale, cfg, primary, secondary, dark)
    local reveal = ease_out(clamp01(progress / 0.3))
    local fracture = ease_out(clamp01((progress - 0.42) / 0.34))
    local fade = 1 - smooth(clamp01((progress - 0.68) / 0.32))
    local radius = 86 * scale
    soft_aura(center, radius * 0.66, dark, opacity * fade * 0.86, cfg.quality + 1)
    local bars = 5 + cfg.quality * 2
    for bar = 1, bars do
        local angle = bar / bars * TAU + effect.seed
        local depth = 0.72 + math.sin(angle) * 0.18
        local outward = fracture * radius * (0.08 + seeded(effect.seed, bar + 2660) * 0.32)
        local x = center.x + math.cos(angle) * (radius * 0.66 + outward)
        local height = radius * depth * reveal
        local top = Vec2(x, center.y - height * 0.72)
        local bottom = Vec2(x + math.sin(angle) * radius * 0.14, center.y + height * 0.72)
        silk_line(top, bottom, bar % 2 == 0 and primary or secondary, Color(255, 255, 255), opacity * fade * (0.34 + depth * 0.42), (0.65 + depth * 0.45) * scale, cfg.quality)
    end
    local links = 12 + cfg.quality * 6
    for link = 1, links do
        local angle = link / links * TAU - clock() * 0.34
        local break_offset = fracture * radius * (link % 4 == 0 and 0.28 or 0.06)
        local point = Vec2(
            center.x + math.cos(angle) * (radius * 0.78 + break_offset),
            center.y + math.sin(angle) * (radius * 0.42 + break_offset * 0.45)
        )
        Render.Circle(point, (2.6 + cfg.quality * 0.42) * scale, alpha(link % 2 == 0 and primary or secondary, opacity * fade * 0.68), 0.75 * scale, angle * 57.3, 0.7, true, 14)
    end
    local count = math.floor(cfg.kill_particles * UI.kill_density:Get() / 100)
    for particle = 1, count do
        local born = seeded(effect.seed, particle + 2740) * 0.22
        local phase = (progress - born) / (0.5 + seeded(effect.seed, particle + 2780) * 0.4)
        if phase >= 0 and phase < 1 then
            local angle = seeded(effect.seed, particle + 2820) * TAU
            local start_distance = radius * (0.72 + seeded(effect.seed, particle + 2860) * 0.48)
            local end_distance = radius * (0.08 + seeded(effect.seed, particle + 2900) * 0.28)
            local distance = lerp(start_distance, end_distance, smooth(clamp01(phase * 1.45)))
            if phase > 0.68 then distance = distance + radius * (phase - 0.68) * seeded(effect.seed, particle + 2940) end
            local x = center.x + math.cos(angle + phase * 0.6) * distance
            local y = center.y + math.sin(angle + phase * 0.6) * distance * 0.52
            local color = particle % 2 == 0 and primary or secondary
            silk_line(Vec2(x - math.cos(angle) * 4 * scale, y - math.sin(angle) * 3 * scale), Vec2(x, y), color, Color(255, 255, 255), opacity * fade * (1 - phase) * 0.62, 0.55 + seeded(effect.seed, particle + 2980) * 0.65, cfg.quality)
            if particle % 8 == 0 then glow_dot(Vec2(x, y), 1 + seeded(effect.seed, particle + 3020) * 1.8, color, opacity * fade * (1 - phase) * 0.72, math.min(3, cfg.quality)) end
        end
    end
end

local function draw_celestial_verdict(effect, center, progress, opacity, scale, cfg, primary, secondary, dark)
    local reveal = ease_out(clamp01(progress / 0.32))
    local fade = 1 - smooth(clamp01((progress - 0.7) / 0.3))
    local radius = 82 * scale
    soft_aura(center, radius * 0.62, primary, opacity * fade * 0.3, cfg.quality + 1)
    ellipse_arc(Vec2(center.x, center.y - radius * 0.4), radius * 0.34, radius * 0.12, 0, TAU, 22 + cfg.quality * 7, 0, secondary, Color(255, 255, 255), opacity * fade * 0.68, 1.1 * scale, cfg.quality)
    local feathers = 5 + cfg.quality * 3
    for side = -1, 1, 2 do
        for feather = 1, feathers do
            local factor = feather / feathers
            local root = Vec2(center.x + side * radius * 0.12, center.y + radius * (0.1 + factor * 0.18))
            local middle = Vec2(center.x + side * radius * (0.32 + factor * 0.36) * reveal, center.y - radius * (0.08 + factor * 0.44) * reveal)
            local tip = Vec2(center.x + side * radius * (0.44 + factor * 0.54) * reveal, center.y - radius * (0.32 - factor * 0.12) * reveal)
            silk_line(root, middle, primary, secondary, opacity * fade * (0.28 + factor * 0.42), (0.55 + factor * 0.55) * scale, cfg.quality)
            silk_line(middle, tip, secondary, Color(255, 255, 255), opacity * fade * (0.22 + factor * 0.38), (0.45 + factor * 0.42) * scale, cfg.quality)
        end
    end
    local count = math.floor(cfg.kill_particles * UI.kill_density:Get() / 100)
    for particle = 1, count do
        local phase = (progress * (0.65 + seeded(effect.seed, particle + 3020) * 0.75) + seeded(effect.seed, particle + 3060)) % 1
        local x = center.x + (seeded(effect.seed, particle + 3100) - 0.5) * radius * (0.4 + phase)
        local y = center.y + radius * 0.55 - phase * radius * 1.45
        local previous = Vec2(x - math.sin(clock() * 2 + particle) * 2, y + 5 * scale)
        silk_line(previous, Vec2(x, y), primary, secondary, opacity * fade * (1 - phase) * 0.55, 0.5 + seeded(effect.seed, particle + 3140) * 0.7, cfg.quality)
        if particle % 9 == 0 then glow_dot(Vec2(x, y), 1 + seeded(effect.seed, particle + 3180) * 2, secondary, opacity * fade * (1 - phase), cfg.quality) end
    end
end

local function draw_thorn_tribunal(effect, center, progress, opacity, scale, cfg, primary, secondary, dark)
    local reveal = ease_out(clamp01(progress / 0.34))
    local release = smooth(clamp01((progress - 0.52) / 0.3))
    local fade = 1 - smooth(clamp01((progress - 0.7) / 0.3))
    local radius = 88 * scale
    soft_aura(center, radius * 0.68, dark, opacity * fade * 0.82, cfg.quality + 1)
    local vines = 3 + cfg.quality
    for vine = 1, vines do
        local side = vine % 2 == 0 and 1 or -1
        local offset = (vine - 1) / math.max(1, vines - 1)
        local previous = Vec2(
            center.x + side * radius * (0.82 - offset * 0.18),
            center.y + radius * (0.58 + offset * 0.08)
        )
        local segments = 7 + cfg.quality * 2
        for segment = 1, segments do
            local phase = segment / segments
            local curl = math.sin(phase * math.pi * (1.65 + offset * 0.45) + vine * 0.8)
            local bind = 1 - release * (0.12 + offset * 0.14)
            local point = Vec2(
                center.x + side * radius * (0.76 * (1 - phase) + curl * (0.18 + phase * 0.13)) * reveal * bind,
                center.y + radius * (0.58 - phase * 1.24 + math.sin(phase * TAU + vine) * 0.07) * reveal
            )
            silk_line(previous, point, vine % 3 == 0 and secondary or primary, mix(primary, Color(220, 244, 176), 0.48), opacity * fade * (0.42 + phase * 0.38), (0.85 + offset * 0.55) * scale, cfg.quality)
            if segment > 1 and segment < segments and (segment + vine) % 2 == 0 then
                local dx = point.x - previous.x
                local dy = point.y - previous.y
                local length = math.sqrt(dx * dx + dy * dy)
                if length > 0 then
                    local thorn_length = radius * (0.055 + seeded(effect.seed, vine * 40 + segment + 3220) * 0.045)
                    local direction = (segment + vine) % 4 < 2 and 1 or -1
                    local thorn = Vec2(point.x - dy / length * thorn_length * direction, point.y + dx / length * thorn_length * direction)
                    silk_line(point, thorn, secondary, Color(232, 255, 190), opacity * fade * 0.72, 0.55 * scale, cfg.quality)
                end
            end
            previous = point
        end
    end
    local wreaths = 2 + cfg.quality
    for wreath = 1, wreaths do
        local rotation = effect.seed * 0.37 + wreath * 1.71 - clock() * (0.08 + wreath * 0.025)
        local arc_radius = radius * (0.44 + wreath * 0.095 + release * wreath * 0.035)
        ellipse_arc(center, arc_radius, arc_radius * (0.58 + wreath * 0.025), rotation, rotation + math.pi * (1.26 + reveal * 0.5), 18 + cfg.quality * 7, 0, wreath % 2 == 0 and primary or secondary, Color(224, 250, 178), opacity * fade * (0.24 + wreath * 0.09), (0.65 + wreath * 0.1) * scale, cfg.quality)
    end
    local leaves = 5 + cfg.quality * 4
    for leaf = 1, leaves do
        local angle = seeded(effect.seed, leaf + 3340) * TAU + release * (seeded(effect.seed, leaf + 3380) - 0.5)
        local distance = radius * (0.28 + seeded(effect.seed, leaf + 3420) * (0.52 + release * 0.28))
        local point = Vec2(center.x + math.cos(angle) * distance, center.y + math.sin(angle) * distance * 0.62)
        local leaf_size = radius * (0.035 + seeded(effect.seed, leaf + 3460) * 0.035)
        local tangent = angle + math.pi * 0.5
        local tip = Vec2(point.x + math.cos(angle) * leaf_size * 1.7, point.y + math.sin(angle) * leaf_size)
        local left = Vec2(point.x + math.cos(tangent) * leaf_size, point.y + math.sin(tangent) * leaf_size * 0.65)
        local right = Vec2(point.x - math.cos(tangent) * leaf_size, point.y - math.sin(tangent) * leaf_size * 0.65)
        silk_line(left, tip, primary, secondary, opacity * fade * 0.68, 0.48 * scale, cfg.quality)
        silk_line(tip, right, secondary, Color(232, 255, 196), opacity * fade * 0.62, 0.48 * scale, cfg.quality)
        silk_line(right, left, dark, primary, opacity * fade * 0.46, 0.42 * scale, cfg.quality)
    end
    local count = math.floor(cfg.kill_particles * UI.kill_density:Get() / 100)
    for particle = 1, count do
        local born = seeded(effect.seed, particle + 3500) * 0.24
        local phase = (progress - born) / (0.48 + seeded(effect.seed, particle + 3540) * 0.46)
        if phase >= 0 and phase < 1 then
            local angle = seeded(effect.seed, particle + 3580) * TAU + phase * (seeded(effect.seed, particle + 3620) - 0.5) * 1.2
            local distance = radius * (0.16 + seeded(effect.seed, particle + 3660) * 0.7) * (0.72 + ease_out(phase) * 0.48)
            local point = Vec2(center.x + math.cos(angle) * distance, center.y + math.sin(angle) * distance * 0.58 + phase * radius * 0.16)
            local color = particle % 3 == 0 and secondary or primary
            glow_dot(point, 0.65 + seeded(effect.seed, particle + 3700) * 1.15, color, opacity * fade * (1 - phase) * 0.56, math.min(3, cfg.quality))
        end
    end
end

local KILL_DRAWERS = { draw_ink_verdict, draw_chrono_execution, draw_soul_cage, draw_celestial_verdict, draw_thorn_tribunal }

local function draw_kill_label(effect, center, progress, opacity, scale, cfg, primary, secondary)
    if not UI.kill_label:Get() then return end
    local font = font_handle()
    local label = effect.streak >= 2 and UI.kill_streak:Get() and ("EXECUTION  ×" .. tostring(effect.streak)) or "ELIMINATED"
    local size = math.floor(18 * scale)
    local measure = Render.TextSize(font, size, label)
    local y = center.y - 105 * scale - ease_out(progress) * 18
    local position = Vec2(center.x - measure.x * 0.5, y)
    soft_aura(Vec2(center.x, y + measure.y * 0.5), measure.x * 0.32, primary, opacity * 0.28, cfg.quality)
    outline_text(font, size, label, position, Color(0, 0, 0), opacity * 0.82, 2, math.min(8, cfg.outline))
    Render.Text(font, size, label, position, alpha(mix(primary, Color(255, 255, 255), 0.36), opacity))
    if UI.kill_name:Get() then
        local victim_size = math.max(10, math.floor(11 * scale))
        local victim_measure = Render.TextSize(font, victim_size, effect.victim)
        local victim_position = Vec2(center.x - victim_measure.x * 0.5, y + measure.y + 3)
        Render.Text(font, victim_size, effect.victim, victim_position, alpha(secondary, opacity * 0.76))
    end
end

local function draw_kills()
    if not UI.kill_enable:Get() then return end
    local now = clock()
    local speed = math.max(0.25, UI.kill_speed:Get() / 100)
    local duration = UI.kill_duration:Get() / 1000 / speed
    local cfg = config()
    local scale = UI.kill_scale:Get() / 100
    local base_opacity = UI.kill_opacity:Get() / 100
    for i = #STATE.kills, 1, -1 do
        local effect = STATE.kills[i]
        local age = now - effect.t0
        if age >= duration then
            table.remove(STATE.kills, i)
        else
            local progress = clamp01(age / duration)
            local fade = 1 - smooth(clamp01((progress - 0.68) / 0.32))
            local opacity = 255 * base_opacity * fade
            local center, visible = world_to_screen(effect.pos)
            if visible then
                local primary, secondary, dark = kill_colors(effect.style)
                local drawer = KILL_DRAWERS[effect.style + 1]
                if drawer then drawer(effect, center, progress, opacity, scale, cfg, primary, secondary, dark) end
                draw_hero_signature(effect.hero, center, 98 * scale, opacity * 0.52, cfg, primary, secondary, effect.seed + 500)
                draw_kill_label(effect, center, progress, opacity, scale, cfg, primary, secondary)
            end
        end
    end
end

local function clean_particles(force)
    local now = clock()
    for i = #STATE.particles, 1, -1 do
        local particle = STATE.particles[i]
        if force or now >= particle.die then
            table.remove(STATE.particles, i)
            safe_call(Particle.SetShouldDraw, particle.id, false)
            safe_call(Particle.Destroy, particle.id)
        end
    end
end

local function reset_runtime(clear_fonts)
    clean_particles(true)
    STATE.entries = {}
    STATE.health = {}
    STATE.exact = {}
    STATE.hit_chains = {}
    STATE.kills = {}
    STATE.particles = {}
    STATE.next_scan = 0
    STATE.kill_count = 0
    STATE.last_kill = -100
    if clear_fonts then STATE.font_cache = {} end
end

App.OnEntityHurt = function(data)
    if not UI.master:Get() or not data or not data.target or data.damage == nil then return end
    local value = math.abs(tonumber(data.damage) or 0)
    local critical_value = data.critical
    if critical_value == nil then critical_value = data.is_critical end
    if critical_value == nil then critical_value = data.isCritical end
    local critical = critical_value == true or tonumber(critical_value) == 1
    add_combat(data.target, value, damage_kind(data), critical, nil, data.source or data.attacker)
    local index = entity_index(data.target)
    STATE.exact[index] = { time = clock(), value = value }
    local health = safe_call(Entity.GetHealth, data.target)
    if type(health) == "number" then STATE.health[index] = { health = health, seen = clock() } end
end

App.OnOverHeadEvent = function(data)
    if not UI.master:Get() or not data then return end
    local target = data.target_npc or data.target
    if not target then return end
    local alert = data.alert or data.alert_type or data.type or data.event_type or data.message_type
    local value = math.abs(tonumber(data.value) or 0)
    if alert == Enum.OverHeadAlert.OVERHEAD_ALERT_HEAL then
        add_combat(target, value, "heal", false, nil, data.source)
        local health = safe_call(Entity.GetHealth, target)
        if type(health) == "number" then STATE.health[entity_index(target)] = { health = health, seen = clock() } end
    elseif alert == Enum.OverHeadAlert.OVERHEAD_ALERT_MISS or alert == Enum.OverHeadAlert.OVERHEAD_ALERT_EVADE then
        add_combat(target, 0, "miss", false, "MISS", data.source)
    elseif alert == Enum.OverHeadAlert.OVERHEAD_ALERT_CRITICAL then
        local index = entity_index(target)
        local now = clock()
        for i = #STATE.entries, 1, -1 do
            local entry = STATE.entries[i]
            if now - entry.t0 > 0.24 then break end
            if entry.index == index then
                entry.critical = true
                return
            end
        end
        add_combat(target, value, "physical", true, nil, data.source)
    end
end

App.OnEntityKilled = function(data)
    if not UI.master:Get() or not UI.kill_enable:Get() or not data or not data.source or not data.target then return end
    local me = Heroes.GetLocal()
    if not me or not source_is_local(data.source, me) then return end
    if not UI.kill_controlled:Get() and not same_entity(data.source, me) then return end
    local victim = data.target
    local hero_victim = safe_call(NPC.IsHero, victim) == true
    if not hero_victim and not UI.kill_creeps:Get() then return end
    if safe_call(NPC.IsBuilding, victim) then return end
    if safe_call(NPC.IsIllusion, victim) and not UI.kill_illusions:Get() then return end
    if safe_call(Entity.IsSameTeam, me, victim) then return end
    add_kill(victim)
end

App.OnParticleDestroy = function(data)
    if not data then return end
    local id = tonumber(data.index or data.particleIndex)
    if not id then return end
    for i = #STATE.particles, 1, -1 do
        if STATE.particles[i].id == id then table.remove(STATE.particles, i) end
    end
end

App.OnUpdate = function()
    if not UI.master:Get() then
        if STATE.master_was_enabled then reset_runtime(false) end
        STATE.master_was_enabled = false
        return
    end
    STATE.master_was_enabled = true
    clean_particles(false)
    scan_health()
end

App.OnDraw = function()
    if not UI.master:Get() then return end
    draw_kills()
    draw_combat()
end

App.OnGameEnd = function()
    reset_runtime(false)
    STATE.master_was_enabled = UI.master:Get()
end

App.OnScriptUnload = function()
    reset_runtime(true)
end

return App
