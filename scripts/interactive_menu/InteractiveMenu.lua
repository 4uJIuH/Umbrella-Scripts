local script = {}
local K = {
    TAU = math.pi * 2,
    DT = 0.016,
    DT_MIN = 0.001,
    DT_MAX = 0.05,
    FADE = 0.8,
    SCREEN_REFRESH = 2.0,
}

local S = {
    time = 0,
    fade = 0,
    wasOpen = false,
    lastReal = nil,
    lastScreenRefresh = -10,
    screen = Vec2(1920, 1080),
    particles = {},
    trail = {},
    cursor = nil,
    lastCursor = nil,
    smoothCursor = nil,
    cursorDx = 0,
    cursorDy = 0,
    cursorSpeed = 0,
    clickBursts = {},
    dotaPieces = {},
    dotaImpacts = {},
}

local DEFAULT_A = Color(70, 220, 255, 225)
local DEFAULT_B = Color(178, 92, 255, 220)
local DEFAULT_C = Color(255, 112, 190, 215)

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function round(v)
    if v >= 0 then return math.floor(v + 0.5) end
    return math.ceil(v - 0.5)
end

local function atan2(y,x)
    if math.atan2 then return math.atan2(y,x) end
    if x>0 then return math.atan(y/x) end
    if x<0 and y>=0 then return math.atan(y/x)+math.pi end
    if x<0 and y<0 then return math.atan(y/x)-math.pi end
    if y>0 then return math.pi*0.5 end
    if y<0 then return -math.pi*0.5 end
    return 0
end

local function get(widget,fallback)
    if not widget or not widget.Get then return fallback end
    local value=widget:Get()
    if value==nil then return fallback end
    return value
end

local function rgba(color,alpha)
    if not color then return Color(255,255,255,clamp(round(alpha or 255),0,255)) end
    return Color(color.r or 255,color.g or 255,color.b or 255,clamp(round(alpha or color.a or 255),0,255))
end

local function mix(first,second,t,alpha)
    t=clamp(t or 0,0,1)
    return Color(
        round((first.r or 255)+((second.r or 255)-(first.r or 255))*t),
        round((first.g or 255)+((second.g or 255)-(first.g or 255))*t),
        round((first.b or 255)+((second.b or 255)-(first.b or 255))*t),
        clamp(round(alpha or ((first.a or 255)+((second.a or 255)-(first.a or 255))*t)),0,255)
    )
end

local function hsvColor(h, s, v, alpha)
    h = h % 1
    s = clamp(s, 0, 1)
    v = clamp(v, 0, 1)
    local sector = math.floor(h * 6)
    local fraction = h * 6 - sector
    local p = v * (1 - s)
    local q = v * (1 - fraction * s)
    local t = v * (1 - (1 - fraction) * s)
    local r, g, b
    sector = sector % 6
    if sector == 0 then r,g,b=v,t,p
    elseif sector == 1 then r,g,b=q,v,p
    elseif sector == 2 then r,g,b=p,v,t
    elseif sector == 3 then r,g,b=p,q,v
    elseif sector == 4 then r,g,b=t,p,v
    else r,g,b=v,p,q end
    return Color(round(r*255),round(g*255),round(b*255),clamp(round(alpha),0,255))
end

local function globalNumber(name)
    if not GlobalVars or not GlobalVars[name] then return nil end
    local ok, value = pcall(GlobalVars[name], GlobalVars)
    if ok and type(value) == "number" then return value end
    return nil
end

local function deltaTime()
    local real = globalNumber("GetRealTime")
    if real then
        if S.lastReal then
            local dt = real - S.lastReal
            S.lastReal = real
            if dt > 0 then return clamp(dt, K.DT_MIN, K.DT_MAX) end
        else
            S.lastReal = real
        end
    else
        S.lastReal = nil
    end
    local dt = globalNumber("GetAbsFrameTime") or globalNumber("GetFrameTime") or K.DT
    if dt <= 0 then dt = K.DT end
    return clamp(dt, K.DT_MIN, K.DT_MAX)
end

local function screenSize()
    if Render and Render.ScreenSize then
        local size=Render.ScreenSize()
        if size then return size end
    end
    return Vec2(1920,1080)
end

local function cursorPosition()
    if Input and Input.GetCursorPos then
        local x,y=Input.GetCursorPos()
        if type(x)=="number" and type(y)=="number" then return Vec2(x,y) end
    end
    return nil
end

local function menuOpen()
    return Menu and Menu.Opened and Menu.Opened() == true
end

local function line(x1, y1, x2, y2, color, width)
    Render.Line(Vec2(x1, y1), Vec2(x2, y2), color, width or 1)
end

local function rect(x1, y1, x2, y2, color, rounding)
    Render.FilledRect(Vec2(x1, y1), Vec2(x2, y2), color, rounding or 0)
end

local function paletteCycle(a,b,c,t,alpha)
    local position=(t%1)*3
    if position<1 then return mix(a,b,position,alpha) end
    if position<2 then return mix(b,c,position-1,alpha) end
    return mix(c,a,position-2,alpha)
end

local function tuneRgbColor(color,saturation,brightness,alpha)
    local gray=color.r*0.299+color.g*0.587+color.b*0.114
    return Color(
        clamp(round((gray+(color.r-gray)*saturation)*brightness),0,255),
        clamp(round((gray+(color.g-gray)*saturation)*brightness),0,255),
        clamp(round((gray+(color.b-gray)*saturation)*brightness),0,255),
        clamp(round(alpha),0,255)
    )
end

local function palette()
    local a=get(script.colorA,DEFAULT_A)
    local b=get(script.colorB,DEFAULT_B)
    local c=get(script.colorC,DEFAULT_C)
    if not get(script.linkRgbMode,false) then return a,b,c end

    local source=clamp(round(get(script.rgbSource,1)),0,1)
    local speed=get(script.linkRgbSpeed,100)*0.01
    local spread=get(script.linkRgbSpread,85)*0.01
    local saturation=get(script.rgbSaturation,92)*0.01
    local brightness=get(script.rgbBrightness,100)*0.01
    local direction=get(script.rgbReverse,false) and -1 or 1
    local phase=(S.time*0.10*speed*direction)%1
    local offset=0.12+spread*0.32

    local function at(t,alpha)
        local color
        if source==1 then
            color=hsvColor(t,saturation,brightness,alpha)
        else
            color=paletteCycle(a,b,c,t,alpha)
            color=tuneRgbColor(color,saturation,brightness,alpha)
        end
        return color
    end
    return at(phase,a.a or 255),at(phase+offset,b.a or 255),at(phase+offset*2,c.a or 255)
end

local function resetParticle(p, i)
    p.x = math.random(0, math.floor(S.screen.x))
    p.y = math.random(0, math.floor(S.screen.y))
    local angle = math.random() * K.TAU
    local speed = math.random(16, 55)
    p.vx = math.cos(angle) * speed
    p.vy = math.sin(angle) * speed
    p.ix = 0
    p.iy = 0
    p.radius = math.random(10, 32) / 10
    p.depth = math.random(60, 125) / 100
    p.phase = (i * 1.618 + math.random()) % K.TAU
    p.tint = math.random()
end

local function ensure(pool, count, reset)
    while #pool < count do
        local item = {}
        pool[#pool + 1] = item
        reset(item, #pool)
    end
end

local updateMenuVisibility, applyLanguage

local function createMenu()

    local general = Menu.Create("General", "Main", "InteractiveMenu RU", "⚙ General / Общее", "Основные настройки")
    local generalPage = general:Parent()
    local tab = generalPage:Parent()
    if tab and tab.Icon then tab:Icon("\u{f6ff}") end
    script.language = general:Combo("Язык / Language", {"Русский", "English"}, 0)
    script.enabled = general:Switch("Включить InteractiveMenu", true, "\u{f011}")
    script.darkness = general:Slider("Затемнение фона", 0, 100, 34, "%d%%")
    script.masterOpacity = general:Slider("Общая прозрачность", 20, 150, 100, "%d%%")
    script.masterSpeed = general:Slider("Скорость анимации", 20, 220, 100, "%d%%")
    script.compactMenu = general:Switch("Скрывать неактивные функции", true, "\u{f070}")
    script.smoothOpening = general:Switch("Плавное открытие", true, "\u{f110}")
    local openingGear = script.smoothOpening:Gear("Открытие")
    script.openDuration = openingGear:Slider("Длительность", 20, 200, 80, "%d%%")
    script.smoothClosing = general:Switch("Плавное закрытие", true, "\u{f2f5}")
    local closingGear = script.smoothClosing:Gear("Закрытие")
    script.closeDuration = closingGear:Slider("Длительность", 20, 250, 95, "%d%%")
    script.blur = general:Switch("Размытие фона", false, "\u{f0c9}")
    local blurGear = script.blur:Gear("Размытие")
    script.blurStrength = blurGear:Slider("Сила", 1, 18, 4, "%d")
    local palettePage = tab:Create("◈ Palette / Палитра")
    local paletteGroup = palettePage:Create("Цвета и RGB")
    script.colorA = paletteGroup:ColorPicker("Основной цвет", DEFAULT_A)
    script.colorB = paletteGroup:ColorPicker("Второй цвет", DEFAULT_B)
    script.colorC = paletteGroup:ColorPicker("Акцентный цвет", DEFAULT_C)
    script.linkRgbMode = paletteGroup:Switch("RGB-переливание палитры", false, "\u{f53f}")
    local rgbGear = script.linkRgbMode:Gear("Настройка RGB")
    script.rgbSource = rgbGear:Combo("Набор цветов RGB", {"Выбранная палитра", "Полный спектр"}, 1)
    script.linkRgbSpeed = rgbGear:Slider("Скорость RGB", 10, 400, 100, "%d%%")
    script.linkRgbSpread = rgbGear:Slider("Разброс оттенков", 0, 200, 85, "%d%%")
    script.rgbSaturation = rgbGear:Slider("Насыщенность RGB", 20, 100, 92, "%d%%")
    script.rgbBrightness = rgbGear:Slider("Яркость RGB", 20, 100, 100, "%d%%")
    script.rgbReverse = rgbGear:Switch("Обратное направление RGB", false, "\u{f2f1}")

    local particlesPage = tab:Create("✦ Particles / Частицы")
    local particles = particlesPage:Create("Настройки")
    script.web = particles:Switch("Включить частицы", true, "\u{f6ff}")
    script.particleStyle = particles:Combo("Стиль", {
        "Мягкие шарики", "Неоновые точки", "Призматические кристаллы", "Орбитальные ядра"
    }, 0)
    script.particleCount = particles:Slider("Количество", 20, 220, 105, "%d")
    script.particleSize = particles:Slider("Размер", 35, 220, 100, "%d%%")
    script.particleSpeed = particles:Slider("Скорость", 10, 250, 85, "%d%%")
    script.particleDrift = particles:Slider("Плавное отклонение", 0, 200, 48, "%d%%")
    script.particleDepth = particles:Slider("Разница глубины", 0, 100, 62, "%d%%")
    script.particleGlow = particles:Slider("Свечение", 0, 100, 46, "%d%%")
    script.particleOpacity = particles:Slider("Прозрачность", 5, 100, 72, "%d%%")
    script.particlePulse = particles:Slider("Пульсация размера", 0, 100, 28, "%d%%")
    script.particleTwinkle = particles:Slider("Мерцание", 0, 100, 24, "%d%%")

    local webPage = tab:Create("⌘ Web / Паутинка")
    local web = webPage:Create("Настройки")
    script.links = web:Switch("Включить соединения", true, "\u{f0c1}")
    script.linkStyle = web:Combo("Архитектура соединений", {
        "Голографические нити", "Энергетические дуги", "Живой спектр",
        "Квантовый пунктир", "Нейронная сеть"
    }, 0)
    script.linkDistance = web:Slider("Дистанция соединения", 40, 380, 165, "%d")
    script.linkOpacity = web:Slider("Общая прозрачность", 5, 100, 48, "%d%%")
    script.linkWidth = web:Slider("Базовая толщина", 1, 4, 1, "%d")
    script.maxLinks = web:Slider("Связей на частицу", 1, 10, 4, "%d")
    script.linkBudget = web:Slider("Лимит соединений", 20, 700, 280, "%d")
    script.linkCursorBoost = web:Slider("Реакция на курсор", 0, 100, 54, "%d%%")
    script.linkNodeGlow = web:Slider("Свечение узлов", 0, 100, 52, "%d%%")
    local linkGear = script.links:Gear("Параметры выбранной архитектуры")
    script.linkHoloLayers = linkGear:Slider("Голограмма · слои", 1, 5, 3, "%d")
    script.linkHoloShift = linkGear:Slider("Голограмма · преломление", 0, 100, 42, "%d%%")
    script.linkArcSegments = linkGear:Slider("Дуги · детализация", 4, 18, 10, "%d")
    script.linkArcJitter = linkGear:Slider("Дуги · электрический излом", 0, 100, 38, "%d%%")
    script.linkSpectrumBands = linkGear:Slider("Спектр · цветовые полосы", 2, 5, 3, "%d")
    script.linkSpectrumSpeed = linkGear:Slider("Спектр · скорость волны", 10, 300, 100, "%d%%")
    script.linkDashLength = linkGear:Slider("Пунктир · длина", 2, 28, 10, "%d")
    script.linkDashGap = linkGear:Slider("Пунктир · промежуток", 1, 22, 7, "%d")
    script.linkDashSpeed = linkGear:Slider("Пунктир · скорость", 0, 300, 90, "%d%%")
    script.linkNeuronPulse = linkGear:Slider("Нейросеть · импульсов", 1, 6, 3, "%d")
    script.linkNeuronBranch = linkGear:Slider("Нейросеть · ветвление", 0, 100, 58, "%d%%")
    script.webExtra = web:Switch("Дополнительный эффект", true, "\u{f5aa}")
    local extraGear = script.webExtra:Gear("Эффект паутинки")
    script.webExtraStyle = extraGear:Combo("Стиль", {
        "Плексус-сетка", "Поток данных", "Электрическая паутина",
        "Сеть курсора", "Метаболлы", "Эластичные нити"
    }, 0)
    script.webExtraRange = extraGear:Slider("Радиус", 60, 360, 175, "%d")
    script.webExtraIntensity = extraGear:Slider("Интенсивность", 5, 100, 48, "%d%%")
    script.webExtraSpeed = extraGear:Slider("Скорость", 10, 250, 100, "%d%%")
    script.webExtraBudget = extraGear:Slider("Лимит элементов", 10, 180, 55, "%d")

    local cursorPage = tab:Create("◎ Cursor / Курсор")
    local cursor = cursorPage:Create("Настройки")
    script.mousePhysics = cursor:Switch("Физика курсора", true, "\u{f245}")
    local mouseGear = script.mousePhysics:Gear("Физика")
    script.mouseMode = mouseGear:Combo("Взаимодействие", {
        "Отталкивание", "Притяжение", "Вихрь", "Толчок движением"
    }, 0)
    script.mouseRadius = mouseGear:Slider("Радиус", 50, 600, 220, "%d")
    script.mouseForce = mouseGear:Slider("Сила", 100, 12000, 3600, "%d")
    script.mouseFalloff = mouseGear:Slider("Мягкость", 20, 300, 115, "%d%%")
    script.mouseSwirl = mouseGear:Slider("Сила вихря", 10, 250, 100, "%d%%")
    script.mouseDamping = mouseGear:Slider("Затухание", 10, 300, 95, "%d%%")
    local trailPage = tab:Create("➤ Trail / След")
    local trail = trailPage:Create("Непрерывность и стиль")
    script.mouseTrail = trail:Switch("След мыши", true, "\u{f135}")
    local trailGear = script.mouseTrail:Gear("След")
    script.trailMode = trailGear:Combo("Стиль", {
        "Комета", "Плавная лента", "Неоновый поток", "Искры",
        "Цепочка шариков", "Жидкая плазма", "Двойная спираль", "Северное сияние",
        "Крылья феникса", "Портальный разлом", "Электроимпульс", "Глитч-поток"
    }, 1)
    script.trailAlwaysVisible = trailGear:Switch("Показывать вне меню", true, "\u{f06e}")
    script.trailOutsideOpacity = trailGear:Slider("Яркость вне меню", 10, 150, 100, "%d%%")
    script.trailLength = trailGear:Slider("Длина", 6, 100, 42, "%d")
    script.trailLifetime = trailGear:Slider("Время жизни", 20, 250, 110, "%d%%")
    script.trailSize = trailGear:Slider("Размер", 20, 260, 120, "%d%%")
    script.trailSmoothing = trailGear:Slider("Плавность", 1, 10, 7, "%d")
    script.trailPointSpacing = trailGear:Slider("Шаг точек", 1, 8, 2, "%d px")
    script.trailContinuity = trailGear:Slider("Заполнение разрывов", 0, 100, 92, "%d%%")
    script.trailSpeedWidth = trailGear:Slider("Толщина от скорости", 0, 100, 38, "%d%%")
    script.trailEcho = trailGear:Switch("Эхо-слой", false, "\u{f534}")
    script.trailEchoOffset = trailGear:Slider("Эхо · смещение", 1, 18, 6, "%d")
    script.trailEchoOpacity = trailGear:Slider("Эхо · прозрачность", 5, 80, 28, "%d%%")
    script.trailRibbonLayers = trailGear:Slider("Ленты · количество слоёв", 1, 5, 2, "%d")
    script.trailSparkDensity = trailGear:Slider("Искры · плотность", 10, 100, 62, "%d%%")
    script.trailHelixSpread = trailGear:Slider("Спираль · размах", 20, 200, 100, "%d%%")
    script.trailGlitchStrength = trailGear:Slider("Глитч · сила искажения", 0, 200, 100, "%d%%")
    script.trailGlow = trailGear:Slider("Свечение", 0, 100, 65, "%d%%")
    script.trailMotion = trailGear:Slider("Живость", 0, 100, 45, "%d%%")
    script.trailDetail = trailGear:Slider("Детализация", 0, 100, 62, "%d%%")
    script.trailOpacity = trailGear:Slider("Прозрачность", 5, 100, 88, "%d%%")
    local lightningGroup = cursorPage:Create("Молнии")
    script.lightning = lightningGroup:Switch("Молнии курсора", true, "\u{f0e7}")
    local lightningGear = script.lightning:Gear("Молнии")
    script.lightningStyle = lightningGear:Combo("Стиль", {
        "Электрический разряд", "Плавный луч", "Двойная дуга"
    }, 0)
    script.lightningRange = lightningGear:Slider("Дальность", 50, 500, 245, "%d")
    script.lightningCount = lightningGear:Slider("Количество", 1, 8, 3, "%d")
    script.lightningJitter = lightningGear:Slider("Излом", 0, 40, 13, "%d")
    script.lightningOpacity = lightningGear:Slider("Прозрачность", 5, 100, 48, "%d%%")
    local artifactGroup = cursorPage:Create("Артефакт")
    script.cursorArtifact = artifactGroup:Switch("Призматический артефакт", true, "\u{f3a5}")
    local artifactGear = script.cursorArtifact:Gear("Артефакт курсора")
    script.artifactStyle = artifactGear:Combo("Форма", {
        "Кристалл-навигация", "Плазменный мотылёк", "Портальные осколки",
        "Квантовый глаз", "Рунный компас"
    }, 0)
    script.artifactSize = artifactGear:Slider("Размер", 8, 100, 30, "%d")
    script.artifactIntensity = artifactGear:Slider("Яркость", 5, 100, 62, "%d%%")
    script.artifactSpeed = artifactGear:Slider("Живость", 10, 300, 100, "%d%%")
    script.artifactFacets = artifactGear:Slider("Кристалл · количество граней", 3, 10, 6, "%d")
    script.artifactWingSpan = artifactGear:Slider("Мотылёк · размах крыльев", 30, 200, 100, "%d%%")
    script.artifactShardCount = artifactGear:Slider("Осколки · количество", 3, 14, 7, "%d")
    script.artifactEyePulse = artifactGear:Slider("Глаз · сила пульсации", 0, 100, 64, "%d%%")
    script.artifactRuneCount = artifactGear:Slider("Компас · количество рун", 4, 12, 8, "%d")
    local clickGroup = cursorPage:Create("Эффекты клика")
    script.clickEffect = clickGroup:Switch("Взрыв при нажатии ЛКМ", true, "\u{f8cc}")
    local clickGear = script.clickEffect:Gear("Эффект нажатия")
    script.clickEffectStyle = clickGear:Combo("Стиль", {
        "Кинематографичные искры", "Объёмная ударная волна", "Лепестки сакуры", "Неоновая пыль"
    }, 0)
    script.clickEffectArea = clickGear:Combo("Область разлёта", {
        "Возле курсора", "Большой радиус", "На весь экран"
    }, 0)
    script.clickEffectRadius = clickGear:Slider("Радиус возле курсора", 80, 900, 260, "%d")
    script.clickEffectCount = clickGear:Slider("Количество частиц", 12, 120, 48, "%d")
    script.clickEffectPower = clickGear:Slider("Сила разлёта", 20, 240, 115, "%d%%")
    script.clickEffectSize = clickGear:Slider("Размер", 20, 220, 100, "%d%%")
    script.clickEffectLifetime = clickGear:Slider("Время жизни", 20, 250, 100, "%d%%")
    script.clickEffectGlow = clickGear:Slider("Свечение", 0, 100, 68, "%d%%")
    script.clickSparkTail = clickGear:Slider("Искры · длина хвоста", 20, 220, 100, "%d%%")
    script.clickSparkBranches = clickGear:Slider("Искры · вторичные осколки", 0, 100, 56, "%d%%")
    script.clickShockwaveRings = clickGear:Slider("Волна · количество колец", 1, 8, 5, "%d")
    script.clickShockwaveSpokes = clickGear:Slider("Волна · детализация лучей", 8, 48, 28, "%d")
    script.clickShockwaveDust = clickGear:Slider("Волна · объём пыли", 0, 100, 52, "%d%%")
    script.clickSakuraWind = clickGear:Slider("Сакура · сила ветра", 0, 200, 100, "%d%%")
    script.clickSakuraPetal = clickGear:Slider("Сакура · размер лепестков", 40, 180, 100, "%d%%")
    script.clickSakuraLayers = clickGear:Slider("Сакура · слои лепестков", 1, 4, 2, "%d")
    script.clickDustTwinkle = clickGear:Slider("Пыль · мерцание", 0, 100, 72, "%d%%")
    script.clickDustOrbit = clickGear:Slider("Пыль · закручивание", 0, 200, 100, "%d%%")
    script.clickDustBloom = clickGear:Slider("Пыль · мягкое свечение", 0, 100, 68, "%d%%")
    script.clickAlwaysVisible = clickGear:Switch("Показывать вне меню", true, "\u{f06e}")

    local testPage = tab:Create("◆ Test")
    local testGroup = testPage:Create("Dota 2")
    script.dotaTest = testGroup:Switch("Летающие половинки Dota 2", true, "\u{f1e2}")
    local dotaGear = script.dotaTest:Gear("Dota 2")
    script.dotaPieceCount = dotaGear:Slider("Количество половинок", 8, 60, 26, "%d")
    script.dotaPieceSize = dotaGear:Slider("Размер логотипов", 18, 84, 42, "%d px")
    script.dotaPieceSpeed = dotaGear:Slider("Скорость полёта", 20, 260, 105, "%d%%")
    script.dotaMergeRadius = dotaGear:Slider("Радиус реакции", 30, 160, 88, "%d%%")
    script.dotaTrails = dotaGear:Switch("Следы движения", true, "\u{f70b}")
    script.dotaGlow = dotaGear:Slider("Свечение логотипов", 0, 100, 42, "%d%%")
    script.dotaAnimation = dotaGear:Slider("Живость анимации", 0, 100, 68, "%d%%")
    script.dotaImpact = dotaGear:Slider("Энергия столкновений", 0, 100, 72, "%d%%")

    local atmospherePage = tab:Create("★ Atmosphere / Атмосфера")
    local atmosphere = atmospherePage:Create("Звёздная пыль")
    script.atmosphere = atmosphere:Switch("Включить звёздную пыль", true, "\u{f005}")
    local starGear = script.atmosphere:Gear("Звёздная пыль")
    script.starStyle = starGear:Combo("Режим звёздной пыли", {"Глубокий космос", "Космический снег", "Метеорный поток"}, 0)
    script.starColorMode = starGear:Combo("Цвет звёзд", {"Палитра", "Белый свет", "RGB"}, 0)
    script.starCount = starGear:Slider("Количество звёзд", 30, 420, 150, "%d")
    script.starSize = starGear:Slider("Размер", 20, 220, 100, "%d%%")
    script.starSpeed = starGear:Slider("Скорость движения", 0, 250, 65, "%d%%")
    script.starOpacity = starGear:Slider("Прозрачность", 5, 100, 58, "%d%%")
    script.starTwinkle = starGear:Slider("Сила мерцания", 0, 100, 72, "%d%%")
    script.starTwinkleSpeed = starGear:Slider("Скорость мерцания", 10, 300, 100, "%d%%")
    script.starDrift = starGear:Slider("Сила дрейфа", 0, 200, 48, "%d%%")
    script.starDriftDirection = starGear:Combo("Направление дрейфа", {"Вправо", "Влево", "Вверх", "Вниз", "Диагональ"}, 0)
    script.starDriftSmooth = starGear:Slider("Плавность дрейфа", 0, 100, 72, "%d%%")
    script.starDepth = starGear:Slider("Эффект глубины", 0, 100, 68, "%d%%")
    script.starCursorParallax = starGear:Slider("Параллакс от курсора", 0, 100, 24, "%d%%")
    script.starCrossGlints = starGear:Switch("Крестообразные блики", true, "\u{f0eb}")
    script.starTrails = starGear:Switch("Следы ярких звёзд", true, "\u{f70b}")
    script.starGlow = starGear:Slider("Мягкое свечение звёзд", 0, 100, 48, "%d%%")
    script.starConstellation = starGear:Slider("Космос · линии созвездий", 0, 100, 24, "%d%%")
    script.starSnowWind = starGear:Slider("Снег · боковой ветер", 0, 200, 72, "%d%%")
    script.starMeteorCount = starGear:Slider("Метеоры · количество", 1, 12, 5, "%d")
    script.starMeteorLength = starGear:Slider("Метеоры · длина следа", 20, 240, 110, "%d%%")

    script._uiContainers = {{general,"Основные настройки","General settings"},{paletteGroup,"Палитра и RGB","Palette & RGB"},{particles,"Настройки частиц","Particle settings"},{web,"Соединения и эффекты","Connections & effects"},{cursor,"Физика курсора","Cursor physics"},
        {artifactGroup,"Артефакт","Artifact"},{lightningGroup,"Молнии","Lightning"},{trail,"Настройки следа","Trail settings"},
        {clickGroup,"Эффекты клика","Click effects"},{testGroup,"Dota 2","Dota 2"},{atmosphere,"Звёздная пыль","Star dust"},
        {openingGear,"Открытие","Opening"},{closingGear,"Закрытие","Closing"},{blurGear,"Размытие","Blur"},
        {rgbGear,"Настройка RGB","RGB settings"},{linkGear,"Настройки соединений","Connection settings"},
        {extraGear,"Дополнительный эффект","Additional effect"},{mouseGear,"Физика курсора","Cursor physics"},
        {trailGear,"След мыши","Mouse trail"},{lightningGear,"Молнии","Lightning"},
        {artifactGear,"Артефакт","Artifact"},{clickGear,"Эффект нажатия","Click effect"},
        {starGear,"Звёздная пыль","Star dust"},{dotaGear,"Dota 2","Dota 2"}
    }

    local function bindVisibility(widget)
        if widget and widget.SetCallback then
            widget:SetCallback(function() if updateMenuVisibility then updateMenuVisibility() end end, true)
        end
    end
    bindVisibility(script.language)
    bindVisibility(script.compactMenu)
    bindVisibility(script.links)
    bindVisibility(script.webExtra)
    bindVisibility(script.mousePhysics)
    bindVisibility(script.mouseTrail)
    bindVisibility(script.lightning)
    bindVisibility(script.cursorArtifact)
    bindVisibility(script.clickEffect)
    bindVisibility(script.atmosphere)
    bindVisibility(script.dotaTest)
    bindVisibility(script.linkStyle)
    bindVisibility(script.linkRgbMode)
    bindVisibility(script.rgbSource)
    bindVisibility(script.starStyle)
    bindVisibility(script.starColorMode)
    bindVisibility(script.trailMode)
    bindVisibility(script.trailEcho)
    bindVisibility(script.artifactStyle)
    bindVisibility(script.clickEffectStyle)
    bindVisibility(script.clickEffectArea)
    if script.language and script.language.SetCallback then
        script.language:SetCallback(function()
            if applyLanguage then applyLanguage() end
            if updateMenuVisibility then updateMenuVisibility() end
        end,true)
    end
end

local UI_EN = {
["Летающие половинки Dota 2"]="Flying Dota 2 halves",["Количество половинок"]="Half count",["Размер логотипов"]="Logo size",
["Скорость полёта"]="Flight speed",["Радиус реакции"]="Reaction radius",["Следы движения"]="Motion trails",["Свечение логотипов"]="Logo glow",
["Живость анимации"]="Animation energy",["Энергия столкновений"]="Impact energy",
["Набор цветов RGB"]="RGB color set",["Насыщенность RGB"]="RGB saturation",["Яркость RGB"]="RGB brightness",["Обратное направление RGB"]="Reverse RGB direction",
["Направление дрейфа"]="Drift direction",["Плавность дрейфа"]="Drift smoothness",
["Режим звёздной пыли"]="Star dust mode",["Цвет звёзд"]="Star color",["Мягкое свечение звёзд"]="Soft star glow",
["Космос · линии созвездий"]="Space · constellation lines",["Снег · боковой ветер"]="Snow · side wind",
["Метеоры · количество"]="Meteors · count",["Метеоры · длина следа"]="Meteors · trail length",
["Включить InteractiveMenu"]="Enable InteractiveMenu",["Затемнение фона"]="Background darkness",["Общая прозрачность"]="Master opacity",
["Скорость анимации"]="Animation speed",
["Скрывать неактивные функции"]="Hide inactive functions",["Плавное открытие"]="Smooth opening",
["Длительность"]="Duration",["Плавное закрытие"]="Smooth closing",["Размытие фона"]="Background blur",["Сила"]="Strength",
["Основной цвет"]="Primary color",["Второй цвет"]="Secondary color",["Акцентный цвет"]="Accent color",
["RGB-переливание палитры"]="Palette RGB flow",
["Скорость RGB"]="RGB speed",["Разброс оттенков"]="Hue spread",
["Скорость"]="Speed",["Включить частицы"]="Enable particles",["Стиль"]="Style",
["Количество"]="Count",["Размер"]="Size",["Плавное отклонение"]="Smooth drift",["Разница глубины"]="Depth variation",["Свечение"]="Glow",
["Прозрачность"]="Opacity",["Пульсация размера"]="Size pulse",["Мерцание"]="Twinkle",["Включить соединения"]="Enable connections",
["Архитектура соединений"]="Connection architecture",["Дистанция соединения"]="Connection distance",["Общая прозрачность"]="Master opacity",
["Базовая толщина"]="Base thickness",["Связей на частицу"]="Links per particle",["Лимит соединений"]="Connection budget",
["Реакция на курсор"]="Cursor response",["Свечение узлов"]="Node glow",["Голограмма · слои"]="Hologram · layers",
["Голограмма · преломление"]="Hologram · refraction",["Дуги · детализация"]="Arcs · detail",["Дуги · электрический излом"]="Arcs · electric jitter",
["Спектр · цветовые полосы"]="Spectrum · color bands",["Спектр · скорость волны"]="Spectrum · wave speed",["Пунктир · длина"]="Dashes · length",
["Пунктир · промежуток"]="Dashes · gap",["Пунктир · скорость"]="Dashes · speed",["Нейросеть · импульсов"]="Neural · pulses",
["Нейросеть · ветвление"]="Neural · branching",["Дополнительный эффект"]="Additional web effect",["Радиус"]="Radius",
["Интенсивность"]="Intensity",["Лимит элементов"]="Element budget",["Физика курсора"]="Cursor physics",["Взаимодействие"]="Interaction",
["Мягкость"]="Falloff softness",["Сила вихря"]="Vortex strength",["Затухание"]="Damping",["След мыши"]="Mouse trail",
["Показывать вне меню"]="Show outside menu",["Яркость вне меню"]="Outside-menu brightness",["Длина"]="Length",["Время жизни"]="Lifetime",
["Плавность"]="Smoothing",["Шаг точек"]="Point spacing",["Заполнение разрывов"]="Gap filling",["Толщина от скорости"]="Speed-based width",
["Эхо-слой"]="Echo layer",["Эхо · смещение"]="Echo · offset",["Эхо · прозрачность"]="Echo · opacity",
["Ленты · количество слоёв"]="Ribbons · layer count",["Искры · плотность"]="Sparks · density",["Спираль · размах"]="Helix · spread",
["Глитч · сила искажения"]="Glitch · distortion",["Живость"]="Motion",["Детализация"]="Detail",["Молнии курсора"]="Cursor lightning",
["Дальность"]="Range",["Излом"]="Jitter",["Призматический артефакт"]="Prismatic artifact",["Форма"]="Form",["Яркость"]="Brightness",
["Кристалл · количество граней"]="Crystal · facets",["Мотылёк · размах крыльев"]="Moth · wing span",["Осколки · количество"]="Shards · count",
["Глаз · сила пульсации"]="Eye · pulse strength",["Компас · количество рун"]="Compass · rune count",["Взрыв при нажатии ЛКМ"]="Left-click burst",
["Область разлёта"]="Burst area",["Радиус возле курсора"]="Cursor-local radius",["Количество частиц"]="Particle count",["Сила разлёта"]="Burst force",
["Искры · длина хвоста"]="Sparks · tail length",["Искры · вторичные осколки"]="Sparks · secondary fragments",
["Волна · количество колец"]="Wave · ring count",["Волна · детализация лучей"]="Wave · ray detail",["Волна · объём пыли"]="Wave · dust volume",
["Сакура · сила ветра"]="Sakura · wind force",["Сакура · размер лепестков"]="Sakura · petal size",["Сакура · слои лепестков"]="Sakura · petal layers",
["Пыль · мерцание"]="Dust · twinkle",["Пыль · закручивание"]="Dust · swirl",["Пыль · мягкое свечение"]="Dust · soft bloom",
["Включить звёздную пыль"]="Enable star dust",["Количество звёзд"]="Star count",["Скорость движения"]="Movement speed",
["Сила мерцания"]="Twinkle strength",["Скорость мерцания"]="Twinkle speed",["Боковой дрейф"]="Side drift",["Эффект глубины"]="Depth effect",
["Параллакс от курсора"]="Cursor parallax",["Крестообразные блики"]="Cross-shaped glints",["Следы ярких звёзд"]="Bright-star trails",

}

local UI_TIPS_RU = {
["Язык / Language"]="Меняет язык настроек и списков.",
["Включить InteractiveMenu"]="Включает все визуальные эффекты.",
["Затемнение фона"]="Регулирует затемнение за эффектами.",
["Общая прозрачность"]="Меняет прозрачность всей сцены.",
["Скорость анимации"]="Меняет скорость всех анимаций.",
["Скрывать неактивные функции"]="Скрывает настройки выключенных модулей.",
["Плавное открытие"]="Плавно показывает эффекты при открытии меню.",
["Плавное закрытие"]="Плавно скрывает эффекты при закрытии меню.",
["Размытие фона"]="Размывает фон за визуальными эффектами.",
["Основной цвет"]="Основной цвет эффектов.",
["Второй цвет"]="Второй цвет градиентов.",
["Акцентный цвет"]="Цвет ярких деталей.",
["RGB-переливание палитры"]="Включает плавную смену цветов.",
["Набор цветов RGB"]="Выбирает палитру или полный спектр.",
["Разброс оттенков"]="Разносит цвета по фазе анимации.",
["Включить частицы"]="Показывает фоновые частицы.",
["Плавное отклонение"]="Добавляет мягкое движение траектории.",
["Разница глубины"]="Разделяет частицы по глубине и скорости.",
["Включить соединения"]="Соединяет ближайшие частицы линиями.",
["Архитектура соединений"]="Выбирает форму и анимацию связей.",
["Дистанция соединения"]="Максимальная дальность между узлами.",
["Лимит соединений"]="Ограничивает число линий на экране.",
["Дополнительный эффект"]="Добавляет второй эффект паутинки.",
["Физика курсора"]="Управляет частицами и объектами Dota 2 курсором.",
["Взаимодействие"]="Выбирает притяжение, отталкивание или вихрь.",
["След мыши"]="Показывает анимированный след курсора.",
["Заполнение разрывов"]="Уплотняет след при быстром движении.",
["Толщина от скорости"]="Увеличивает ширину следа при ускорении.",
["Эхо-слой"]="Добавляет смещённую копию следа.",
["Молнии курсора"]="Создаёт разряды до ближайших частиц.",
["Призматический артефакт"]="Показывает анимированную форму курсора.",
["Взрыв при нажатии ЛКМ"]="Запускает эффект в точке клика.",
["Область разлёта"]="Выбирает локальный или полноэкранный масштаб.",
["Летающие половинки Dota 2"]="Запускает слияние и раскол логотипов.",
["Количество половинок"]="Задаёт число физических объектов.",
["Радиус реакции"]="Дистанция слияния и раскола.",
["Живость анимации"]="Усиливает движение и пульсацию логотипов.",
["Энергия столкновений"]="Меняет размер вспышек при столкновении.",
["Включить звёздную пыль"]="Показывает звёздную атмосферу.",
["Режим звёздной пыли"]="Выбирает космос, снег или метеоры.",
["Цвет звёзд"]="Выбирает палитру звёзд.",
["Сила дрейфа"]="Меняет скорость направленного движения.",
["Направление дрейфа"]="Задаёт направление движения звёзд.",
["Плавность дрейфа"]="Уменьшает боковые колебания.",
["Параллакс от курсора"]="Смещает слои вслед за курсором."
}

local UI_TIPS_EN = {
["Язык / Language"]="Changes the settings and list language.",
["Включить InteractiveMenu"]="Enables all visual effects.",
["Затемнение фона"]="Adjusts darkness behind the effects.",
["Общая прозрачность"]="Changes opacity of the whole scene.",
["Скорость анимации"]="Changes the speed of all animations.",
["Скрывать неактивные функции"]="Hides settings of disabled modules.",
["Плавное открытие"]="Fades effects in when the menu opens.",
["Плавное закрытие"]="Fades effects out when the menu closes.",
["Размытие фона"]="Blurs the background behind effects.",
["Основной цвет"]="Primary effect color.",
["Второй цвет"]="Secondary gradient color.",
["Акцентный цвет"]="Color of bright details.",
["RGB-переливание палитры"]="Enables smooth color cycling.",
["Набор цветов RGB"]="Selects the palette or full spectrum.",
["Разброс оттенков"]="Offsets colors across the animation phase.",
["Включить частицы"]="Shows background particles.",
["Плавное отклонение"]="Adds smooth trajectory movement.",
["Разница глубины"]="Separates particles by depth and speed.",
["Включить соединения"]="Connects nearby particles with lines.",
["Архитектура соединений"]="Selects connection form and animation.",
["Дистанция соединения"]="Maximum distance between nodes.",
["Лимит соединений"]="Limits the number of visible lines.",
["Дополнительный эффект"]="Adds a second web effect.",
["Физика курсора"]="Makes particles and Dota 2 objects react to the cursor.",
["Взаимодействие"]="Selects attraction, repulsion or vortex.",
["След мыши"]="Shows an animated cursor trail.",
["Заполнение разрывов"]="Fills trail gaps during fast movement.",
["Толщина от скорости"]="Widens the trail as speed increases.",
["Эхо-слой"]="Adds an offset copy of the trail.",
["Молнии курсора"]="Creates discharges to nearby particles.",
["Призматический артефакт"]="Shows an animated cursor form.",
["Взрыв при нажатии ЛКМ"]="Launches an effect at the click point.",
["Область разлёта"]="Selects local or full-screen range.",
["Летающие половинки Dota 2"]="Starts logo merging and splitting.",
["Количество половинок"]="Sets the number of physical objects.",
["Радиус реакции"]="Sets merge and split distance.",
["Живость анимации"]="Increases logo motion and pulsing.",
["Энергия столкновений"]="Changes collision flash size.",
["Включить звёздную пыль"]="Shows the star atmosphere.",
["Режим звёздной пыли"]="Selects space, snow or meteors.",
["Цвет звёзд"]="Selects the star palette.",
["Сила дрейфа"]="Changes directional movement speed.",
["Направление дрейфа"]="Sets the star movement direction.",
["Плавность дрейфа"]="Reduces sideways movement wobble.",
["Параллакс от курсора"]="Moves depth layers with the cursor."
}

local UI_COMBOS = nil
local languageGuard = false

applyLanguage = function()
    if languageGuard or not script.language then return end
    languageGuard = true
    local english=get(script.language,0)==1
    script._originalNames=script._originalNames or {}
    for _,widget in pairs(script) do
        if type(widget)=="userdata" or type(widget)=="table" then
            local name=widget.Name and widget:Name() or nil
            if type(name)=="string" and widget.ForceLocalization then
                local original=script._originalNames[widget] or name
                script._originalNames[widget]=original
                widget:ForceLocalization(english and (UI_EN[original] or original) or original)
                if widget.ToolTip then
                    local tip=english and UI_TIPS_EN[original] or UI_TIPS_RU[original]
                    if tip then widget:ToolTip(tip) end
                end
            end
        end
    end
    if script._uiContainers then
        for _,entry in ipairs(script._uiContainers) do
            if entry[1] and entry[1].ForceLocalization then
                entry[1]:ForceLocalization(english and entry[3] or entry[2])
            end
        end
    end
    UI_COMBOS={
        {script.starDriftDirection,{"Вправо","Влево","Вверх","Вниз","Диагональ"},{"Right","Left","Up","Down","Diagonal"}},
        {script.rgbSource,{"Выбранная палитра","Полный спектр"},{"Selected palette","Full spectrum"}},
        {script.starStyle,{"Глубокий космос","Космический снег","Метеорный поток"},{"Deep space","Cosmic snow","Meteor stream"}},
        {script.starColorMode,{"Палитра","Белый свет","RGB"},{"Palette","White light","RGB"}},
        {script.particleStyle,{"Мягкие шарики","Неоновые точки","Призматические кристаллы","Орбитальные ядра"},{"Soft orbs","Neon dots","Prismatic crystals","Orbital cores"}},
        {script.linkStyle,{"Голографические нити","Энергетические дуги","Живой спектр","Квантовый пунктир","Нейронная сеть"},{"Holographic strands","Energy arcs","Living spectrum","Quantum dashes","Neural network"}},
        {script.webExtraStyle,{"Плексус-сетка","Поток данных","Электрическая паутина","Сеть курсора","Метаболлы","Эластичные нити"},{"Plexus mesh","Data flow","Electric web","Cursor network","Metaballs","Elastic threads"}},
        {script.mouseMode,{"Отталкивание","Притяжение","Вихрь","Толчок движением"},{"Repulsion","Attraction","Vortex","Motion push"}},
        {script.trailMode,{"Комета","Плавная лента","Неоновый поток","Искры","Цепочка шариков","Жидкая плазма","Двойная спираль","Северное сияние","Крылья феникса","Портальный разлом","Электроимпульс","Глитч-поток"},{"Comet","Smooth ribbon","Neon flow","Sparks","Orb chain","Liquid plasma","Double helix","Aurora","Phoenix wings","Portal rift","Electric impulse","Glitch flow"}},
        {script.lightningStyle,{"Электрический разряд","Плавный луч","Двойная дуга"},{"Electric discharge","Smooth beam","Double arc"}},
        {script.artifactStyle,{"Кристалл-навигация","Плазменный мотылёк","Портальные осколки","Квантовый глаз","Рунный компас"},{"Navigation crystal","Plasma moth","Portal shards","Quantum eye","Runic compass"}},
        {script.clickEffectStyle,{"Кинематографичные искры","Объёмная ударная волна","Лепестки сакуры","Неоновая пыль"},{"Cinematic sparks","Volumetric shockwave","Sakura petals","Neon dust"}},
        {script.clickEffectArea,{"Возле курсора","Большой радиус","На весь экран"},{"Near cursor","Large radius","Full screen"}}
    }
    for _,entry in ipairs(UI_COMBOS) do
        if entry[1] and entry[1].Update then
            local current=get(entry[1],0)
            entry[1]:Update(english and entry[3] or entry[2],current)
        end
    end
    languageGuard=false
end

local function setVisible(widget, visible)
    if widget and widget.Visible then widget:Visible(visible==true) end
end

updateMenuVisibility = function()
    local compact=get(script.compactMenu,true)
    local linkActive=not compact or get(script.links,true)
    local trailActive=not compact or get(script.mouseTrail,true)
    local artifactActive=not compact or get(script.cursorArtifact,true)
    local clickActive=not compact or get(script.clickEffect,true)
    local physicsActive=not compact or get(script.mousePhysics,true)
    local lightningActive=not compact or get(script.lightning,true)
    local atmosphereActive=not compact or get(script.atmosphere,true)
    local extraActive=not compact or get(script.webExtra,true)
    local dotaActive=not compact or get(script.dotaTest,true)
    for _,widget in ipairs({script.linkStyle,script.linkDistance,script.linkOpacity,script.linkWidth,script.maxLinks,script.linkBudget,script.linkCursorBoost,script.linkNodeGlow}) do setVisible(widget,linkActive) end
    for _,widget in ipairs({script.trailMode,script.trailAlwaysVisible,script.trailOutsideOpacity,script.trailLength,script.trailLifetime,script.trailSize,script.trailSmoothing,script.trailPointSpacing,script.trailContinuity,script.trailSpeedWidth,script.trailEcho,script.trailGlow,script.trailMotion,script.trailDetail,script.trailOpacity}) do setVisible(widget,trailActive) end
    for _,widget in ipairs({script.artifactStyle,script.artifactSize,script.artifactIntensity,script.artifactSpeed}) do setVisible(widget,artifactActive) end
    for _,widget in ipairs({script.clickEffectStyle,script.clickEffectArea,script.clickEffectCount,script.clickEffectPower,script.clickEffectSize,script.clickEffectLifetime,script.clickEffectGlow,script.clickAlwaysVisible}) do setVisible(widget,clickActive) end
    for _,widget in ipairs({script.mouseMode,script.mouseRadius,script.mouseForce,script.mouseFalloff,script.mouseSwirl,script.mouseDamping}) do setVisible(widget,physicsActive) end
    for _,widget in ipairs({script.lightningStyle,script.lightningRange,script.lightningCount,script.lightningJitter,script.lightningOpacity}) do setVisible(widget,lightningActive) end
    for _,widget in ipairs({script.starStyle,script.starColorMode,script.starCount,script.starSize,script.starSpeed,script.starOpacity,script.starTwinkle,script.starTwinkleSpeed,script.starDrift,script.starDriftDirection,script.starDriftSmooth,script.starDepth,script.starCursorParallax,script.starCrossGlints,script.starTrails,script.starGlow}) do setVisible(widget,atmosphereActive) end
    local starStyle=clamp(round(get(script.starStyle,0))+1,1,3)
    setVisible(script.starConstellation,atmosphereActive and starStyle==1)
    setVisible(script.starSnowWind,atmosphereActive and starStyle==2)
    setVisible(script.starMeteorCount,atmosphereActive and starStyle==3)
    setVisible(script.starMeteorLength,atmosphereActive and starStyle==3)
    for _,widget in ipairs({script.webExtraStyle,script.webExtraRange,script.webExtraIntensity,script.webExtraSpeed,script.webExtraBudget}) do setVisible(widget,extraActive) end
    for _,widget in ipairs({script.dotaPieceCount,script.dotaPieceSize,script.dotaPieceSpeed,script.dotaMergeRadius,script.dotaTrails,script.dotaGlow,script.dotaAnimation,script.dotaImpact}) do setVisible(widget,dotaActive) end

    local linkStyle=clamp(round(get(script.linkStyle,0))+1,1,5)
    setVisible(script.linkHoloLayers,linkActive and linkStyle==1)
    setVisible(script.linkHoloShift,linkActive and linkStyle==1)
    setVisible(script.linkArcSegments,linkActive and linkStyle==2)
    setVisible(script.linkArcJitter,linkActive and linkStyle==2)
    setVisible(script.linkSpectrumBands,linkActive and linkStyle==3)
    setVisible(script.linkSpectrumSpeed,linkActive and linkStyle==3)
    setVisible(script.linkDashLength,linkActive and linkStyle==4)
    setVisible(script.linkDashGap,linkActive and linkStyle==4)
    setVisible(script.linkDashSpeed,linkActive and linkStyle==4)
    setVisible(script.linkNeuronPulse,linkActive and linkStyle==5)
    setVisible(script.linkNeuronBranch,linkActive and linkStyle==5)

    local rgb=get(script.linkRgbMode,false)
    setVisible(script.rgbSource,rgb)
    setVisible(script.linkRgbSpeed,rgb)
    setVisible(script.linkRgbSpread,rgb)
    setVisible(script.rgbSaturation,rgb)
    setVisible(script.rgbBrightness,rgb)
    setVisible(script.rgbReverse,rgb)

    local trailMode=clamp(round(get(script.trailMode,1))+1,1,12)
    local echo=get(script.trailEcho,false)
    setVisible(script.trailEchoOffset,echo)
    setVisible(script.trailEchoOpacity,echo)
    setVisible(script.trailRibbonLayers,trailActive and (trailMode==2 or trailMode==3 or trailMode==6 or trailMode==8))
    setVisible(script.trailSparkDensity,trailActive and (trailMode==1 or trailMode==4 or trailMode==5 or trailMode==9 or trailMode==11))
    setVisible(script.trailHelixSpread,trailActive and trailMode==7)
    setVisible(script.trailGlitchStrength,trailActive and trailMode==12)

    local artifactStyle=clamp(round(get(script.artifactStyle,0))+1,1,5)
    setVisible(script.artifactFacets,artifactActive and artifactStyle==1)
    setVisible(script.artifactWingSpan,artifactActive and artifactStyle==2)
    setVisible(script.artifactShardCount,artifactActive and artifactStyle==3)
    setVisible(script.artifactEyePulse,artifactActive and artifactStyle==4)
    setVisible(script.artifactRuneCount,artifactActive and artifactStyle==5)

    local clickStyle=clamp(round(get(script.clickEffectStyle,0))+1,1,4)
    setVisible(script.clickSparkTail,clickActive and clickStyle==1)
    setVisible(script.clickSparkBranches,clickActive and clickStyle==1)
    setVisible(script.clickShockwaveRings,clickActive and clickStyle==2)
    setVisible(script.clickShockwaveSpokes,clickActive and clickStyle==2)
    setVisible(script.clickShockwaveDust,clickActive and clickStyle==2)
    setVisible(script.clickSakuraWind,clickActive and clickStyle==3)
    setVisible(script.clickSakuraPetal,clickActive and clickStyle==3)
    setVisible(script.clickSakuraLayers,clickActive and clickStyle==3)
    setVisible(script.clickDustTwinkle,clickActive and clickStyle==4)
    setVisible(script.clickDustOrbit,clickActive and clickStyle==4)
    setVisible(script.clickDustBloom,clickActive and clickStyle==4)
    local clickArea=clamp(round(get(script.clickEffectArea,0))+1,1,3)
    setVisible(script.clickEffectRadius,clickActive and clickArea==1)
end

local function updateCursor(dt, allowInput)
    local rawCursor=allowInput and cursorPosition() or nil
    local cursor=nil
    S.cursorDx,S.cursorDy,S.cursorSpeed=0,0,0

    if rawCursor then
        if S.smoothCursor then
            local jumpX,jumpY=rawCursor.x-S.smoothCursor.x,rawCursor.y-S.smoothCursor.y
            local jump=math.sqrt(jumpX*jumpX+jumpY*jumpY)
            local jumpLimit=math.max(320,math.min(S.screen.x,S.screen.y)*0.48)
            if jump>jumpLimit then
                S.trail={}
                S.lastCursor=nil
                S.smoothCursor=Vec2(rawCursor.x,rawCursor.y)
            end
        end

        if not S.smoothCursor then S.smoothCursor=Vec2(rawCursor.x,rawCursor.y) end
        local smoothSetting=get(script.mouseTrail,true) and get(script.trailSmoothing,7) or 7
        local follow=clamp(dt*(16+smoothSetting*5),0.08,1)
        S.smoothCursor.x=S.smoothCursor.x+(rawCursor.x-S.smoothCursor.x)*follow
        S.smoothCursor.y=S.smoothCursor.y+(rawCursor.y-S.smoothCursor.y)*follow
        cursor=Vec2(S.smoothCursor.x,S.smoothCursor.y)
    else
        S.smoothCursor=nil
    end
    S.cursor=cursor

    if cursor and S.lastCursor then
        S.cursorDx=cursor.x-S.lastCursor.x
        S.cursorDy=cursor.y-S.lastCursor.y
        S.cursorSpeed=math.sqrt(S.cursorDx*S.cursorDx+S.cursorDy*S.cursorDy)
    end

    if cursor and get(script.mouseTrail, true) then
        local baseSpacing = get(script.trailPointSpacing, 2)
        local continuity = get(script.trailContinuity, 92) * 0.01
        local speedFactor = clamp(S.cursorSpeed / 55, 0, 1)
        local spacing = math.max(0.75, baseSpacing * (1 - continuity * speedFactor * 0.68))
        local shouldAdd = true
        local distance = spacing
        if #S.trail > 0 then
            local last = S.trail[#S.trail]
            local dx,dy=cursor.x-last.x,cursor.y-last.y
            distance=math.sqrt(dx*dx+dy*dy)
            shouldAdd=distance>=spacing
        end
        if shouldAdd then
            local smoothing=get(script.trailSmoothing,7)
            local maxSteps=round(10+smoothing*4+continuity*42)
            local subdivisions=clamp(math.ceil(distance/math.max(0.75,spacing)),1,maxSteps)
            local from=#S.trail>0 and S.trail[#S.trail] or {x=cursor.x,y=cursor.y,angle=0}
            local angle=math.atan(cursor.y-from.y,cursor.x-from.x)
            local previousAngle=from.angle or angle
            for step=1,subdivisions do

                local t=step/subdivisions
                S.trail[#S.trail+1]={
                    x=from.x+(cursor.x-from.x)*t,
                    y=from.y+(cursor.y-from.y)*t,
                    life=1,
                    speed=S.cursorSpeed,
                    angle=angle,
                    curvature=math.abs(math.sin(angle-previousAngle)),
                    phase=S.time+step*0.11,
                }
            end
        end
        local maxTrail=math.min(1400,get(script.trailLength,42)*(8+get(script.trailSmoothing,7)*3))
        while #S.trail > maxTrail do table.remove(S.trail, 1) end
    end

    local lifetime = math.max(0.15, get(script.trailLifetime, 110) * 0.01)
    for i = #S.trail, 1, -1 do
        local point = S.trail[i]
        point.life = point.life - dt / lifetime
        if point.life <= 0 then
            table.remove(S.trail, i)
        end
    end

    S.lastCursor = cursor and Vec2(cursor.x, cursor.y) or nil
end

local function updateParticles(dt, speedScale)
    local count = math.max(18,round(get(script.particleCount,105)))
    ensure(S.particles, count, resetParticle)
    local w, h = S.screen.x, S.screen.y
    local baseSpeed = get(script.particleSpeed, 85) * 0.01 * speedScale
    local damping = clamp(1 - get(script.mouseDamping, 95) * 0.01 * 3.6 * dt, 0, 1)
    local useMouse = get(script.mousePhysics, true) and S.cursor ~= nil
    local mouseRadius = get(script.mouseRadius, 220)
    local mouseRadiusSq = mouseRadius * mouseRadius
    local force = get(script.mouseForce, 3600)
    local falloffPower = math.max(0.1, get(script.mouseFalloff, 115) * 0.01)
    local mode = clamp(round(get(script.mouseMode, 0)) + 1, 1, 4)
    local swirl = get(script.mouseSwirl, 100) * 0.01

    for i = 1, count do
        local p = S.particles[i]
        p.ix = (p.ix or 0) * damping
        p.iy = (p.iy or 0) * damping

        if useMouse then
            local dx, dy = p.x - S.cursor.x, p.y - S.cursor.y
            local distSq = dx * dx + dy * dy
            if distSq < mouseRadiusSq then
                local dist = math.sqrt(math.max(0.001, distSq))
                local nx, ny = dx / dist, dy / dist
                local amount = (1 - dist / mouseRadius) ^ falloffPower
                local f = force * amount
                local fx, fy = 0, 0
                if mode == 1 then
                    fx, fy = nx * f, ny * f
                elseif mode == 2 then
                    fx, fy = -nx * f, -ny * f
                elseif mode == 3 then
                    fx = -ny * f * swirl + nx * f * 0.12
                    fy = nx * f * swirl + ny * f * 0.12
                else
                    if S.cursorSpeed > 0.1 then
                        fx = (S.cursorDx / S.cursorSpeed) * f * clamp(S.cursorSpeed / 18, 0.25, 2.5)
                        fy = (S.cursorDy / S.cursorSpeed) * f * clamp(S.cursorSpeed / 18, 0.25, 2.5)
                    end
                end
                p.ix = p.ix + fx * dt
                p.iy = p.iy + fy * dt
            end
        end

        local drift = get(script.particleDrift, 48) * 0.01
        local depthAmount = get(script.particleDepth, 62) * 0.01
        local depthSpeed = 1 + ((p.depth or 1) - 1) * depthAmount
        local curveX = math.sin(S.time * 0.72 + p.phase) * 12 * drift
        local curveY = math.cos(S.time * 0.57 + p.phase) * 9 * drift
        p.x = p.x + ((p.vx * baseSpeed + curveX) * depthSpeed + p.ix) * dt
        p.y = p.y + ((p.vy * baseSpeed + curveY) * depthSpeed + p.iy) * dt

        local margin = 35
        if p.x < -margin then p.x = w + margin elseif p.x > w + margin then p.x = -margin end
        if p.y < -margin then p.y = h + margin elseif p.y > h + margin then p.y = -margin end
    end
end

local function leftMousePressed()
    if not Input or not Input.IsKeyDownOnce then return false end
    local key = 119
    if Enum and Enum.ButtonCode and Enum.ButtonCode.KEY_MOUSE1 then
        key = Enum.ButtonCode.KEY_MOUSE1
    end
    return Input.IsKeyDownOnce(key,true)==true
end

local function spawnClickBurst(x, y)
    local style = clamp(round(get(script.clickEffectStyle, 0)) + 1, 1, 4)
    local area = clamp(round(get(script.clickEffectArea, 0)) + 1, 1, 3)
    local count = math.max(8,round(get(script.clickEffectCount,48)))
    local power = get(script.clickEffectPower, 115) * 0.01
    local life = math.max(0.25, get(script.clickEffectLifetime, 100) * 0.01)
    local radius = get(script.clickEffectRadius, 260)
    if area == 2 then
        radius = math.max(radius, math.min(S.screen.x, S.screen.y) * 0.58)
    elseif area == 3 then
        radius = math.sqrt(S.screen.x * S.screen.x + S.screen.y * S.screen.y) * 0.78
        count = math.min(150, math.floor(count * 1.2))
    end

    local burst = {x=x, y=y, age=0, life=life, style=style, area=area, radius=radius, particles={}}
    for i = 1, count do
        local angle = (i / count) * K.TAU + (math.random() - 0.5) * (style == 2 and 0.1 or 0.44)
        local velocitySpread = 0.55 + math.random() * 0.62
        local speed = radius / life * velocitySpread * power
        if style == 1 then speed = speed * (0.82 + (i % 5) * 0.08) end
        if style == 2 then speed = speed * 1.08 end
        if style == 3 then speed = speed * (0.42 + (i % 7) * 0.065) end
        if style == 4 then speed = speed * (0.28 + math.random() * 0.52) end
        burst.particles[i] = {
            x=x, y=y,
            vx=math.cos(angle) * speed,
            vy=math.sin(angle) * speed,
            spin=(math.random() - 0.5) * (style == 3 and 14 or 9),
            phase=math.random() * K.TAU,
            size=math.random(8, 23) * 0.1,
            tint=math.random(),
            layer=1 + (i % 3),
        }
    end
    S.clickBursts[#S.clickBursts + 1] = burst
    while #S.clickBursts > 6 do table.remove(S.clickBursts, 1) end
end

local function updateClickBursts(dt, allowInput)
    if allowInput and S.cursor and get(script.clickEffect, true) and leftMousePressed() then
        spawnClickBurst(S.cursor.x, S.cursor.y)
    end
    for burstIndex = #S.clickBursts, 1, -1 do
        local burst = S.clickBursts[burstIndex]
        burst.age = burst.age + dt
        local dragRate = burst.style == 2 and 0.42 or (burst.style == 4 and 1.25 or 0.82)
        local drag = math.max(0, 1 - dt * dragRate)
        for _, particle in ipairs(burst.particles) do
            particle.vx = particle.vx * drag
            particle.vy = particle.vy * drag
            if burst.style == 1 then
                particle.vy = particle.vy + 125 * dt
            elseif burst.style == 2 then
                particle.vx = particle.vx * (1 + dt * 0.18)
                particle.vy = particle.vy * (1 + dt * 0.18)
            elseif burst.style == 3 then
                local wind = get(script.clickSakuraWind, 100) * 0.01
                particle.vx = particle.vx + math.sin(S.time * 2.4 + particle.phase) * 34 * dt * wind
                particle.vy = particle.vy + (75 + particle.layer * 18) * dt * (0.55 + wind * 0.45)
            else
                local orbit = get(script.clickDustOrbit, 100) * 0.01
                local dx, dy = particle.x - burst.x, particle.y - burst.y
                local distance = math.sqrt(dx * dx + dy * dy)
                if distance > 0.01 then
                    particle.vx = particle.vx - dy / distance * 95 * dt * orbit
                    particle.vy = particle.vy + dx / distance * 95 * dt * orbit
                end
                particle.vx = particle.vx + math.sin(S.time * 4 + particle.phase) * 24 * dt
            end
            particle.x = particle.x + particle.vx * dt
            particle.y = particle.y + particle.vy * dt
            particle.phase = particle.phase + particle.spin * dt
        end
        if burst.age >= burst.life then table.remove(S.clickBursts, burstIndex) end
    end
end

local function newDotaPiece(kind,x,y,vx,vy,cooldown)
    local size=get(script.dotaPieceSize,42)
    local margin=size*0.7
    return {
        kind=kind,
        x=x or (margin+math.random()*math.max(1,S.screen.x-margin*2)),
        y=y or (margin+math.random()*math.max(1,S.screen.y-margin*2)),
        vx=vx or ((math.random()*2-1)*95),
        vy=vy or ((math.random()*2-1)*95),
        oldX=x or 0,oldY=y or 0,
        cooldown=cooldown or (0.25+math.random()*0.45),
        phase=math.random()*K.TAU,
        scale=0.15,
        rotation=(math.random()*2-1)*0.35,
        angular=(math.random()*2-1)*1.8,
        cursorVx=0,
        cursorVy=0,
    }
end

local function addDotaHalf(kind,x,y,angle,speed,cooldown,list)
    list[#list+1]=newDotaPiece(kind,x,y,math.cos(angle)*speed,math.sin(angle)*speed,cooldown)
end

local function updateDotaPieces(dt)
    if not get(script.dotaTest,true) then S.dotaPieces={} S.dotaImpacts={} return end
    local pieces=S.dotaPieces
    local target=math.max(8,round(get(script.dotaPieceCount,26)))
    local speedScale=get(script.dotaPieceSpeed,105)*0.01
    local size=get(script.dotaPieceSize,42)
    local margin=size*0.58
    local reaction=size*get(script.dotaMergeRadius,88)*0.01
    local reactionSq=reaction*reaction

    while #pieces<target do
        local kind=(#pieces%2==0) and "left" or "right"
        local angle=math.random()*K.TAU
        local speed=(48+math.random()*72)*speedScale
        pieces[#pieces+1]=newDotaPiece(kind,nil,nil,math.cos(angle)*speed,math.sin(angle)*speed,0.35+math.random()*0.5)
    end

    local animation=get(script.dotaAnimation,68)*0.01
    local useCursorPhysics=get(script.mousePhysics,true) and S.cursor~=nil
    local cursorRadius=get(script.mouseRadius,220)
    local cursorRadiusSq=cursorRadius*cursorRadius
    local cursorForce=get(script.mouseForce,3600)*0.62
    local cursorFalloff=math.max(0.1,get(script.mouseFalloff,115)*0.01)
    local cursorMode=clamp(round(get(script.mouseMode,0))+1,1,4)
    local cursorSwirl=get(script.mouseSwirl,100)*0.01
    local cursorDamping=clamp(1-get(script.mouseDamping,95)*0.01*3.6*dt,0,1)
    for _,piece in ipairs(pieces) do
        piece.oldX,piece.oldY=piece.x,piece.y
        piece.cooldown=math.max(0,(piece.cooldown or 0)-dt)
        piece.phase=piece.phase+dt*(piece.kind=="full" and 1.4 or 2.2)*(0.55+animation)
        piece.scale=piece.scale+(1-piece.scale)*clamp(dt*(7+animation*6),0,1)
        piece.vx=piece.vx+math.sin(piece.phase*0.73)*dt*9*animation
        piece.vy=piece.vy+math.cos(piece.phase*0.61)*dt*9*animation
        piece.cursorVx=(piece.cursorVx or 0)*cursorDamping
        piece.cursorVy=(piece.cursorVy or 0)*cursorDamping
        if useCursorPhysics then
            local dx,dy=piece.x-S.cursor.x,piece.y-S.cursor.y
            local distSq=dx*dx+dy*dy
            if distSq<cursorRadiusSq then
                local dist=math.sqrt(math.max(0.001,distSq))
                local nx,ny=dx/dist,dy/dist
                local amount=(1-dist/cursorRadius)^cursorFalloff
                local force=cursorForce*amount
                local fx,fy=0,0
                if cursorMode==1 then
                    fx,fy=nx*force,ny*force
                elseif cursorMode==2 then
                    fx,fy=-nx*force,-ny*force
                elseif cursorMode==3 then
                    fx=-ny*force*cursorSwirl+nx*force*0.12
                    fy=nx*force*cursorSwirl+ny*force*0.12
                elseif S.cursorSpeed>0.1 then
                    local motion=force*clamp(S.cursorSpeed/18,0.25,2.5)
                    fx=(S.cursorDx/S.cursorSpeed)*motion
                    fy=(S.cursorDy/S.cursorSpeed)*motion
                end
                piece.cursorVx=clamp(piece.cursorVx+fx*dt,-520,520)
                piece.cursorVy=clamp(piece.cursorVy+fy*dt,-520,520)
                local torque=(-ny*fx+nx*fy)/math.max(1,cursorForce)
                piece.angular=clamp(piece.angular+torque*dt*3.2,-5.5,5.5)
            end
        end
    end

    local steps=3
    local stepDt=dt/steps
    local collisionRadius=size*0.62
    local collisionSq=collisionRadius*collisionRadius
    for _=1,steps do
        for _,piece in ipairs(pieces) do
            piece.rotation=piece.rotation+piece.angular*stepDt*(0.35+animation*0.8)
            piece.angular=piece.angular*math.max(0,1-stepDt*0.34)
            piece.x=piece.x+(piece.vx+(piece.cursorVx or 0))*stepDt
            piece.y=piece.y+(piece.vy+(piece.cursorVy or 0))*stepDt
            if piece.x<margin then
                piece.x=margin
                local incidence=piece.vy/math.max(1,math.abs(piece.vx)+math.abs(piece.vy))
                piece.vx=math.abs(piece.vx)*0.96
                piece.cursorVx=math.abs(piece.cursorVx or 0)*0.28
                piece.angular=clamp(piece.angular+incidence*4.2,-5.5,5.5)
            elseif piece.x>S.screen.x-margin then
                piece.x=S.screen.x-margin
                local incidence=piece.vy/math.max(1,math.abs(piece.vx)+math.abs(piece.vy))
                piece.vx=-math.abs(piece.vx)*0.96
                piece.cursorVx=-math.abs(piece.cursorVx or 0)*0.28
                piece.angular=clamp(piece.angular-incidence*4.2,-5.5,5.5)
            end
            if piece.y<margin then
                piece.y=margin
                local incidence=piece.vx/math.max(1,math.abs(piece.vx)+math.abs(piece.vy))
                piece.vy=math.abs(piece.vy)*0.96
                piece.cursorVy=math.abs(piece.cursorVy or 0)*0.28
                piece.angular=clamp(piece.angular-incidence*4.2,-5.5,5.5)
            elseif piece.y>S.screen.y-margin then
                piece.y=S.screen.y-margin
                local incidence=piece.vx/math.max(1,math.abs(piece.vx)+math.abs(piece.vy))
                piece.vy=-math.abs(piece.vy)*0.96
                piece.cursorVy=-math.abs(piece.cursorVy or 0)*0.28
                piece.angular=clamp(piece.angular+incidence*4.2,-5.5,5.5)
            end
        end
        for i=1,#pieces-1 do
            local first=pieces[i]
            for j=i+1,#pieces do
                local second=pieces[j]
                local dx,dy=second.x-first.x,second.y-first.y
                local distSq=dx*dx+dy*dy
                if distSq<collisionSq then
                    local reactive=((first.kind=="left" and second.kind=="right") or (first.kind=="right" and second.kind=="left") or (first.kind=="full" and second.kind=="full")) and first.cooldown<=0 and second.cooldown<=0 and distSq<=reactionSq
                    if not reactive then
                        local distance=math.sqrt(math.max(0.0001,distSq))
                        local nx,ny=dx/distance,dy/distance
                        local overlap=collisionRadius-distance
                        first.x,first.y=first.x-nx*overlap*0.5,first.y-ny*overlap*0.5
                        second.x,second.y=second.x+nx*overlap*0.5,second.y+ny*overlap*0.5
                        local rvx=(second.vx+(second.cursorVx or 0))-(first.vx+(first.cursorVx or 0))
                        local rvy=(second.vy+(second.cursorVy or 0))-(first.vy+(first.cursorVy or 0))
                        local normalSpeed=rvx*nx+rvy*ny
                        if normalSpeed<0 then
                            local impulse=-(1+0.88)*normalSpeed*0.5
                            first.vx,first.vy=first.vx-impulse*nx,first.vy-impulse*ny
                            second.vx,second.vy=second.vx+impulse*nx,second.vy+impulse*ny
                            local tangentSpeed=rvx*(-ny)+rvy*nx
                            local spin=clamp(tangentSpeed/math.max(20,size)*0.62,-2.8,2.8)
                            first.angular=clamp(first.angular-spin,-5.5,5.5)
                            second.angular=clamp(second.angular+spin,-5.5,5.5)
                        end
                    end
                end
            end
        end
    end

    local used,additions={},{ }
    for i=1,#pieces-1 do
        local first=pieces[i]
        if not used[i] and first.cooldown<=0 then
            for j=i+1,#pieces do
                local second=pieces[j]
                if not used[j] and second.cooldown<=0 then
                    local halves=(first.kind=="left" and second.kind=="right") or (first.kind=="right" and second.kind=="left")
                    local logos=first.kind=="full" and second.kind=="full"
                    if halves or logos then
                        local dx,dy=second.x-first.x,second.y-first.y
                        if dx*dx+dy*dy<=reactionSq then
                            used[i],used[j]=true,true
                            local mx,my=(first.x+second.x)*0.5,(first.y+second.y)*0.5
                            local baseVx,baseVy=(first.vx+second.vx)*0.5,(first.vy+second.vy)*0.5
                            local impactPower=get(script.dotaImpact,72)*0.01
                            S.dotaImpacts[#S.dotaImpacts+1]={x=mx,y=my,age=0,life=0.48+impactPower*0.42,split=logos,phase=math.random()*K.TAU}
                            if halves then
                                local merged=newDotaPiece("full",mx,my,baseVx,baseVy,0.72)
                                merged.scale=0.18
                                merged.angular=(first.angular+second.angular)*0.45
                                merged.rotation=(first.rotation+second.rotation)*0.5
                                additions[#additions+1]=merged
                            else
                                local baseAngle=atan2(baseVy,baseVx)
                                local splitSpeed=(78+math.random()*42)*speedScale
                                addDotaHalf("left",first.x-size*0.18,first.y,baseAngle+2.25,splitSpeed,0.72,additions)
                                addDotaHalf("right",first.x+size*0.18,first.y,baseAngle-0.75,splitSpeed,0.72,additions)
                                addDotaHalf("left",second.x-size*0.18,second.y,baseAngle+0.75,splitSpeed,0.72,additions)
                                addDotaHalf("right",second.x+size*0.18,second.y,baseAngle-2.25,splitSpeed,0.72,additions)
                            end
                            break
                        end
                    end
                end
            end
        end
    end
    for index=#pieces,1,-1 do if used[index] then table.remove(pieces,index) end end
    local cap=math.max(target+8,target*2)
    for _,piece in ipairs(additions) do
        if #pieces>=cap then break end
        pieces[#pieces+1]=piece
    end
    while #pieces>cap do table.remove(pieces,1) end
    for index=#S.dotaImpacts,1,-1 do
        local impact=S.dotaImpacts[index]
        impact.age=impact.age+dt
        if impact.age>=impact.life then table.remove(S.dotaImpacts,index) end
    end
    while #S.dotaImpacts>18 do table.remove(S.dotaImpacts,1) end
end

local function drawDotaPiece(piece,alpha)
    local animation=get(script.dotaAnimation,68)*0.01
    local pulse=1+math.sin(piece.phase*1.7)*0.035*animation
    local size=get(script.dotaPieceSize,42)*1.12*(piece.scale or 1)*pulse
    local half=size*0.5
    local angle=(piece.rotation or 0)*0.38
    local ca,sa=math.cos(angle),math.sin(angle)
    local orbitAngle=piece.phase+(piece.rotation or 0)
    local x=piece.x+math.sin(orbitAngle)*1.2*animation
    local y=piece.y+math.cos(orbitAngle*0.83)*1.2*animation
    local red=Color(218+round(math.sin(piece.phase)*9),27,35,245*alpha)
    local redDark=Color(126,12,22,225*alpha)
    local redGhost=Color(112,14,22,36*alpha)
    local black=Color(5,5,7,250*alpha)
    local shadow=Color(0,0,0,95*alpha)
    local glow=get(script.dotaGlow,42)*0.01

    local function point(lx,ly)
        return Vec2(x+lx*ca-ly*sa,y+lx*sa+ly*ca)
    end
    local function tri(a1,a2,a3,color)
        Render.FilledTriangle({point(a1[1],a1[2]),point(a2[1],a2[2]),point(a3[1],a3[2])},color)
    end
    local function quad(l,t,r,b,color)
        local p1,p2,p3,p4=point(l,t),point(r,t),point(r,b),point(l,b)
        Render.FilledTriangle({p1,p2,p3},color)
        Render.FilledTriangle({p1,p3,p4},color)
    end
    local function localLine(x1,y1,x2,y2,color,width)
        local p1,p2=point(x1,y1),point(x2,y2)
        line(p1.x,p1.y,p2.x,p2.y,color,width)
    end

    if get(script.dotaTrails,true) and piece.oldX and (piece.oldX~=0 or piece.oldY~=0) then
        line(piece.oldX,piece.oldY,x,y,Color(190,20,31,22*alpha),math.max(3,size*0.22))
        line(piece.oldX,piece.oldY,x,y,Color(255,62,69,76*alpha),math.max(1,size*0.05))
    end
    if glow>0 then
        Render.FilledCircle(Vec2(x,y),size*(0.78+glow*0.34),Color(230,22,35,12*alpha*glow),0,1,16)
        Render.FilledCircle(Vec2(x,y),size*(0.60+glow*0.18),Color(255,45,52,18*alpha*glow),0,1,14)
    end

    quad(-half-2,-half-2,half+2,half+2,shadow)
    if piece.kind~="full" then quad(-half,-half,half,half,redGhost) end

    if piece.kind=="full" then
        quad(-half,-half,half,half,redDark)
        quad(-half+2,-half+2,half-2,half-2,red)
    elseif piece.kind=="left" then
        quad(-half,-half,1,half,redDark)
        quad(-half+2,-half+2,-1,half-2,red)
    else
        quad(-1,-half,half,half,redDark)
        quad(1,-half+2,half-2,half-2,red)
    end

    local slashWidth=math.max(4,size*0.185)
    if piece.kind=="full" then
        localLine(-half*0.62,-half*0.63,half*0.62,half*0.63,black,slashWidth)
    elseif piece.kind=="left" then
        localLine(-half*0.62,-half*0.63,0,0,black,slashWidth)
    else
        localLine(0,0,half*0.62,half*0.63,black,slashWidth)
    end

    if piece.kind=="left" or piece.kind=="full" then
        tri({-half*0.66,half*0.20},{-half*0.28,half*0.68},{-half*0.76,half*0.62},black)
    end
    if piece.kind=="right" or piece.kind=="full" then
        tri({half*0.20,-half*0.58},{half*0.68,-half*0.72},{half*0.63,-half*0.20},black)
    end

    if piece.kind=="full" or piece.kind=="left" then
        tri({-half,-half*0.18},{-half+size*0.08,-half*0.08},{-half,-half*0.01},black)
        tri({-half*0.24,half},{-half*0.10,half-size*0.055},{half*0.02,half},redDark)
    end
    if piece.kind=="full" or piece.kind=="right" then
        tri({half,half*0.12},{half-size*0.07,half*0.24},{half,half*0.34},black)
        tri({half*0.18,-half},{half*0.30,-half+size*0.06},{half*0.42,-half},redDark)
    end

    if piece.kind=="full" or piece.kind=="left" then
        localLine(-half+2,-half+2,-2,-half+2,Color(255,92,92,72*alpha),1)
        localLine(-half+2,-half+2,-half+2,half-2,Color(255,76,80,55*alpha),1)
    end
    if piece.kind=="full" or piece.kind=="right" then
        localLine(2,-half+2,half-2,-half+2,Color(255,92,92,72*alpha),1)
    end

    if piece.kind~="full" then
        local seamX=piece.kind=="left" and -1 or 1

        localLine(seamX,-half*0.90,seamX-2, -half*0.34,Color(62,4,9,210*alpha),2)
        localLine(seamX-2,-half*0.34,seamX+2,half*0.18,Color(62,4,9,210*alpha),2)
        localLine(seamX+2,half*0.18,seamX,half*0.90,Color(62,4,9,210*alpha),2)
        local spark=point(seamX,math.sin(piece.phase*2.1)*half*0.64)
        Render.FilledCircle(spark,math.max(1,size*0.038),Color(255,124,108,190*alpha),0,1,8)
    end

    local orbit=size*(0.59+glow*0.10)
    Render.FilledCircle(Vec2(x+math.cos(orbitAngle)*orbit,y+math.sin(orbitAngle)*orbit),math.max(0.8,size*0.03),Color(255,118,104,125*alpha*animation),0,1,8)
    if piece.kind=="full" then
        Render.Circle(Vec2(x,y),size*0.65,Color(255,58,66,48*alpha*animation),1,orbitAngle*57,0.36,true,28)
    end
end

local function drawDotaTest(alpha)
    if not get(script.dotaTest,true) then return end
    local impactPower=get(script.dotaImpact,72)*0.01
    for _,impact in ipairs(S.dotaImpacts) do
        local t=clamp(impact.age/impact.life,0,1)
        local fade=(1-t)*alpha
        local radius=(10+t*(impact.split and 82 or 58))*impactPower
        Render.Circle(Vec2(impact.x,impact.y),radius,Color(255,52,60,175*fade),math.max(1,3*(1-t)),impact.phase*57+t*80,0.72,true,42)
        Render.Circle(Vec2(impact.x,impact.y),radius*0.68,Color(255,164,125,105*fade),1,-impact.phase*43-t*120,0.48,true,32)
        local rays=impact.split and 10 or 7
        for ray=1,rays do
            local angle=impact.phase+ray/rays*K.TAU
            local inner=radius*0.26
            local outer=radius*(0.65+0.22*math.sin(ray*2.7))
            line(impact.x+math.cos(angle)*inner,impact.y+math.sin(angle)*inner,impact.x+math.cos(angle)*outer,impact.y+math.sin(angle)*outer,Color(255,84,70,90*fade),1)
        end
    end
    for _,piece in ipairs(S.dotaPieces) do drawDotaPiece(piece,alpha) end
end

local function update(dt, allowInput, updateScene)
    local speed = get(script.masterSpeed, 100) * 0.01
    S.time = S.time + dt * speed
    updateCursor(dt, allowInput)
    updateClickBursts(dt, allowInput)
    if updateScene then
        updateParticles(dt,speed)
        updateDotaPieces(dt)
    end
end

local function drawBackdrop(alpha, a, b)
    local w, h = S.screen.x, S.screen.y
    local darkness = get(script.darkness, 34) * 0.01
    rect(0, 0, w, h, Color(2, 4, 14, 255 * darkness * alpha), 0)
    rect(0, 0, w, h * 0.46, rgba(a, 8 * alpha), 0)
    rect(0, h * 0.5, w, h, rgba(b, 7 * alpha), 0)
    local sweep=(S.time*34)%(w+320)-160
    rect(sweep-90,0,sweep+90,h,rgba(a,4*alpha),0)
    rect(w-sweep-55,0,w-sweep+55,h,rgba(b,3*alpha),0)
    for layer=1,3 do
        local phase=S.time*(0.16+layer*0.035)+layer*2.1
        local x=w*(0.5+math.sin(phase)*0.42)
        local y=h*(0.5+math.cos(phase*0.73)*0.34)
        Render.FilledCircle(Vec2(x,y),70+layer*38,rgba(layer==2 and b or a,(5-layer)*alpha),0,1,22)
    end
    if get(script.blur, false) and Render.Blur then
        Render.Blur(Vec2(0, 0), S.screen, get(script.blurStrength, 4) * 0.18, clamp(alpha, 0, 1), 0)
    end
end

local function drawAtmosphere(alpha,a,b,c)
    if not get(script.atmosphere,true) then return end
    local style=clamp(round(get(script.starStyle,0))+1,1,3)
    local colorMode=clamp(round(get(script.starColorMode,0))+1,1,3)
    local count=math.max(20,round(get(script.starCount,150)))
    local sizeScale=get(script.starSize,100)*0.01
    local speed=get(script.starSpeed,65)*0.01
    local opacity=get(script.starOpacity,58)*0.01
    local twinkleAmount=get(script.starTwinkle,72)*0.01
    local twinkleSpeed=get(script.starTwinkleSpeed,100)*0.01
    local drift=get(script.starDrift,48)*0.01
    local driftDirection=clamp(round(get(script.starDriftDirection,0))+1,1,5)
    local driftSmooth=get(script.starDriftSmooth,72)*0.01
    local driftVectors={{1,0},{-1,0},{0,-1},{0,1},{0.78,0.52}}
    local driftX,driftY=driftVectors[driftDirection][1],driftVectors[driftDirection][2]
    local depthAmount=get(script.starDepth,68)*0.01
    local parallax=get(script.starCursorParallax,24)*0.01
    local glow=get(script.starGlow,48)*0.01
    local w,h=S.screen.x,S.screen.y
    local cursorX,cursorY=0,0
    if S.cursor then
        cursorX=(S.cursor.x/w-0.5)*38*parallax
        cursorY=(S.cursor.y/h-0.5)*30*parallax
    end

    local function starColor(i,t,amount)
        if colorMode==2 then return Color(240,247,255,clamp(round(amount),0,255)) end
        if colorMode==3 then
            local rgbSpeed=get(script.linkRgbSpeed,100)*0.01
            local saturation=get(script.rgbSaturation,92)*0.01
            local brightness=get(script.rgbBrightness,100)*0.01
            local direction=get(script.rgbReverse,false) and -1 or 1
            return hsvColor((S.time*0.11*rgbSpeed*direction+t+i*0.037)%1,saturation,brightness,amount)
        end
        if i%11==0 then return rgba(c,amount) end
        if i%4==0 then return rgba(b,amount) end
        return rgba(a,amount)
    end

    local constellationStrength=get(script.starConstellation,24)*0.01
    local positions=(style==1 and constellationStrength>0.02) and {} or nil
    for i=1,count do
        local rawDepth=((i*47)%101)/100
        local depth=1-depthAmount*0.72+rawDepth*depthAmount*0.92
        local baseX=i*197.31+math.sin(i*2.17)*83
        local baseY=i*91.73+math.cos(i*1.37)*61
        local x,y
        local layerSpeed=(4+(i%7)*1.45)*speed*depth
        local travel=S.time*layerSpeed*(0.3+drift*1.7)
        local wobble=(1-driftSmooth)*math.sin(S.time*(0.7+rawDepth)+i*0.31)*18*drift
        if style==1 then
            x=(baseX+driftX*travel+wobble*driftY-cursorX*depth)%w
            y=(baseY+driftY*travel-wobble*driftX-cursorY*depth)%h
        elseif style==2 then
            local wind=get(script.starSnowWind,72)*0.01
            x=(baseX+driftX*travel+S.time*(8+rawDepth*18)*wind+wobble-cursorX*depth)%w
            y=(baseY+math.abs(driftY+0.65)*S.time*(18+rawDepth*42)*speed-cursorY*depth)%h
        else
            x=(baseX+driftX*travel*0.72+wobble*0.35-cursorX*depth)%w
            y=(baseY+driftY*travel*0.72-cursorY*depth)%h
        end
        local wave=(math.sin(S.time*twinkleSpeed*(2.1+rawDepth)+i*1.73)+1)*0.5
        local twinkle=1-twinkleAmount*0.72+wave*twinkleAmount*0.92
        local size=(0.5+(i%4)*0.3)*sizeScale*(0.5+depth*0.72)
        if style==2 then size=size*(0.72+rawDepth*0.72) end
        local amount=168*opacity*alpha*twinkle*(0.42+depth*0.58)
        local color=starColor(i,rawDepth,amount)
        if positions then positions[i]={x=x,y=y,color=color,depth=depth} end

        if glow>0 and depth>0.58 then
            Render.FilledCircle(Vec2(x,y),size*(2.4+glow*3.2),rgba(color,amount*0.09*glow),0,1,10)
        end
        Render.FilledCircle(Vec2(x,y),math.max(0.5,size),color,0,1,8)
        local glintStep=19
        if get(script.starCrossGlints,true) and i%glintStep==0 and wave>0.42 then
            local ray=size*(3+wave*2.6)
            line(x-ray,y,x+ray,y,rgba(color,amount*0.52),1)
            line(x,y-ray,x,y+ray,Color(255,255,255,amount*0.44),1)
        end
        if get(script.starTrails,true) and style~=3 and i%19==0 and speed>0.05 then
            local length=(8+depth*24)*speed*sizeScale
            line(x,y,x-length,y-length*(style==2 and 0.7 or 0.12),rgba(color,amount*0.32),math.max(0.8,size*0.5))
        end
    end

    if style==1 and positions then
        for i=23,count-17,29 do
            local p1,p2=positions[i],positions[i+17]
            local dx,dy=p2.x-p1.x,p2.y-p1.y
            if dx*dx+dy*dy<(math.min(w,h)*0.23)^2 then
                line(p1.x,p1.y,p2.x,p2.y,rgba(p1.color,42*alpha*constellationStrength),1)
                local mid=positions[math.min(count,i+7)]
                line(p1.x,p1.y,mid.x,mid.y,rgba(p2.color,28*alpha*constellationStrength),1)
            end
        end
    elseif style==3 then
        local meteorCount=math.max(1,round(get(script.starMeteorCount,5)))
        local meteorLength=get(script.starMeteorLength,110)*0.01
        for meteor=1,meteorCount do
            local cycle=(S.time*speed*(0.16+meteor*0.008)+meteor*0.173)%1
            local startX=(meteor*347.13)%w+w*0.18
            local startY=(meteor*131.71)%h-h*0.22
            local x=(startX-cycle*(w*0.72+h*0.28))%w
            local y=(startY+cycle*h*1.18)%h
            local length=(55+meteor*9)*meteorLength
            local color=starColor(meteor,cycle,225*opacity*alpha)
            line(x,y,x+length,y-length*0.58,rgba(color,26*alpha*glow),7+glow*6)
            line(x,y,x+length,y-length*0.58,rgba(color,112*opacity*alpha),2.2)
            line(x,y,x+length*0.42,y-length*0.24,Color(255,255,255,205*opacity*alpha),1)
            Render.FilledCircle(Vec2(x,y),2.2+glow*1.8,Color(255,255,255,225*opacity*alpha),0,1,10)
        end
    end
end

local function particleColor(p, a, b, c, alpha)
    if p.tint > 0.84 then return rgba(c, alpha) end
    return mix(a, b, p.tint, alpha)
end

local function drawConnections(alpha,a,b,c)
    if not get(script.web,true) or not get(script.links,true) then return end
    local count=math.min(#S.particles,math.max(18,round(get(script.particleCount,105))))
    local range=get(script.linkDistance,165)
    local opacity=get(script.linkOpacity,48)*0.01
    local width=get(script.linkWidth,1)
    local maxLinks=get(script.maxLinks,4)
    local budget=math.max(20,round(get(script.linkBudget,280)))
    local cursorBoost=get(script.linkCursorBoost,54)*0.01
    local nodeGlow=get(script.linkNodeGlow,52)*0.01
    local style=clamp(round(get(script.linkStyle,0))+1,1,5)
    local spectrumQuality=1
    if style==3 then budget=math.min(budget,85) end
    local rgb=get(script.linkRgbMode,false)
    local rgbSpeed=get(script.linkRgbSpeed,100)*0.01
    local rgbSpread=get(script.linkRgbSpread,85)*0.01
    local palette3={a,b,c,a}
    local edges,degree={},{}

    local function dynamicColor(t,seed,amount)
        local phase=t+seed*0.021
        if rgb then phase=phase*rgbSpread+S.time*0.08*rgbSpeed end
        local pos=(phase%1)*3
        local index=math.floor(pos)
        return mix(palette3[index+1],palette3[index+2],pos-index,amount)
    end

    local grid={}
    local cellSize=math.max(40,range)
    for i=1,count do
        degree[i]=0
        local p=S.particles[i]
        local cx,cy=math.floor(p.x/cellSize),math.floor(p.y/cellSize)
        local key=cx..":"..cy
        local bucket=grid[key]
        if not bucket then bucket={} grid[key]=bucket end
        bucket[#bucket+1]=i
    end

    local candidateLimit=math.max(60,budget*3)
    local rangeSq=range*range
    for i=1,count do
        if #edges>=candidateLimit then break end
        local p1=S.particles[i]
        local cx,cy=math.floor(p1.x/cellSize),math.floor(p1.y/cellSize)
        local nearest={}
        for ox=-1,1 do
            for oy=-1,1 do
                local bucket=grid[(cx+ox)..":"..(cy+oy)]
                if bucket then
                    for _,j in ipairs(bucket) do
                        if j>i then
                            local p2=S.particles[j]
                            local dx,dy=p2.x-p1.x,p2.y-p1.y
                            local ds=dx*dx+dy*dy
                            if ds<rangeSq then nearest[#nearest+1]={i=i,j=j,d=ds} end
                        end
                    end
                end
            end
        end
        table.sort(nearest,function(x,y)return x.d<y.d end)
        local keep=math.min(#nearest,maxLinks*3)
        for n=1,keep do
            edges[#edges+1]=nearest[n]
            if #edges>=candidateLimit then break end
        end
    end
    table.sort(edges,function(x,y)return x.d<y.d end)

    local drawn=0
    for _,edge in ipairs(edges) do
        if drawn>=budget then break end
        if degree[edge.i]<maxLinks and degree[edge.j]<maxLinks then
            local p1,p2=S.particles[edge.i],S.particles[edge.j]
            local dx,dy=p2.x-p1.x,p2.y-p1.y
            local distance=math.sqrt(edge.d)
            local nx,ny=-dy/math.max(distance,0.001),dx/math.max(distance,0.001)
            local fade=(1-distance/range)^2
            if S.cursor and cursorBoost>0 then
                local mx,my=(p1.x+p2.x)*0.5,(p1.y+p2.y)*0.5
                local cx,cy=mx-S.cursor.x,my-S.cursor.y
                fade=fade*(1+(1-clamp(math.sqrt(cx*cx+cy*cy)/(range*2.3),0,1))*cursorBoost*1.85)
            end
            local edgeAlpha=150*opacity*alpha*fade
            local seed=edge.i*1.37+edge.j*0.73
            local bow=math.sin(seed)*distance*0.075
            local function point(t,bend,offset)
                local side=math.sin(t*math.pi)*(bend or 0)+(offset or 0)
                return p1.x+dx*t+nx*side,p1.y+dy*t+ny*side
            end
            local function stroke(t1,t2,bend,offset,color,w)
                local x1,y1=point(t1,bend,offset)
                local x2,y2=point(t2,bend,offset)
                line(x1,y1,x2,y2,color,w)
            end

            if style==1 then
                local layers=get(script.linkHoloLayers,3)
                local shift=get(script.linkHoloShift,42)*0.01
                for layer=1,layers do
                    local offset=(layer-(layers+1)*0.5)*(1.4+shift*4.2)
                    for part=1,10 do
                        local t1,t2=(part-1)/10,part/10
                        stroke(t1,t2,bow*shift,offset,dynamicColor((t1+t2)*0.5+layer*0.05,seed,edgeAlpha*(0.48+0.52/layers)),math.max(0.7,width*0.82))
                    end
                end
                stroke(0,1,bow*shift,0,Color(255,255,255,edgeAlpha*0.25),math.max(0.6,width*0.34))
            elseif style==2 then
                local parts=get(script.linkArcSegments,10)
                local jitter=get(script.linkArcJitter,38)*0.01*math.min(18,distance*0.09)
                local px,py=p1.x,p1.y
                for part=1,parts do
                    local t=part/parts
                    local x,y=point(t,bow*0.2,0)
                    if part<parts then
                        local noise=math.sin(S.time*19+part*7.13+seed)*jitter
                        x,y=x+nx*noise,y+ny*noise
                    end
                    local color=dynamicColor(t,seed,edgeAlpha)
                    line(px,py,x,y,rgba(color,edgeAlpha*0.10),width*7)
                    line(px,py,x,y,rgba(color,edgeAlpha*0.28),width*3.2)
                    line(px,py,x,y,color,math.max(1,width*1.15))
                    line(px,py,x,y,Color(255,255,255,edgeAlpha*0.34),math.max(0.6,width*0.34))
                    px,py=x,y
                end
            elseif style==3 then
                local bands=math.min(get(script.linkSpectrumBands,3),spectrumQuality==0 and 2 or (spectrumQuality==1 and 3 or 5))
                local speed=get(script.linkSpectrumSpeed,100)*0.01
                local segmentOptions={4,6,9}
                local segments=segmentOptions[spectrumQuality+1]
                for band=1,bands do
                    local center=band-(bands+1)*0.5
                    local phase=S.time*speed*2.0+band*1.31+seed
                    local px,py=point(0,bow*0.24,center*1.65)
                    for part=1,segments do
                        local t=part/segments
                        local wave=math.sin(t*math.pi*2.2+phase)*distance*0.018+center*1.65
                        local x,y=point(t,bow*0.24,wave)
                        local color=dynamicColor(t+band/bands*0.17,seed,edgeAlpha*(0.68+0.32/bands))
                        if spectrumQuality==2 and (band==1 or band==bands) then
                            line(px,py,x,y,rgba(color,edgeAlpha*0.12),width*2.6)
                        end
                        line(px,py,x,y,color,math.max(0.75,width*0.78))
                        px,py=x,y
                    end
                end
            elseif style==4 then
                local dash=get(script.linkDashLength,10)
                local gap=get(script.linkDashGap,7)
                local speed=get(script.linkDashSpeed,90)*0.01
                local cycle=math.max(2,dash+gap)
                local startPx=-((S.time*speed*34+seed*3)%cycle)
                while startPx<distance do
                    local finish=math.min(distance,startPx+dash)
                    if finish>0 then
                        local t1,t2=clamp(startPx/distance,0,1),clamp(finish/distance,0,1)
                        local color=dynamicColor((t1+t2)*0.5,seed,edgeAlpha)
                        stroke(t1,t2,bow*0.22,0,rgba(color,edgeAlpha*0.18),width*3.5)
                        stroke(t1,t2,bow*0.22,0,color,math.max(0.9,width))
                    end
                    startPx=startPx+cycle
                end
            else
                local branch=get(script.linkNeuronBranch,58)*0.01
                local pulses=get(script.linkNeuronPulse,3)
                for part=1,12 do
                    local t1,t2=(part-1)/12,part/12
                    local color=dynamicColor((t1+t2)*0.5,seed,edgeAlpha*0.82)
                    stroke(t1,t2,bow*(0.7+branch),0,rgba(color,edgeAlpha*0.13),width*4.2)
                    stroke(t1,t2,bow*(0.7+branch),0,color,math.max(0.8,width*0.8))
                    if branch>0.08 and part%3==0 then
                        local x,y=point(t2,bow*(0.7+branch),0)
                        local side=part%2==0 and 1 or -1
                        local length=(5+distance*0.045)*branch
                        line(x,y,x+nx*length*side+dx/distance*length*0.35,y+ny*length*side+dy/distance*length*0.35,rgba(color,edgeAlpha*0.58),math.max(0.7,width*0.65))
                    end
                end
                for pulse=1,pulses do
                    local t=(S.time*0.44+pulse/pulses+seed*0.013)%1
                    local x,y=point(t,bow*(0.7+branch),0)
                    local color=dynamicColor(t,seed,235*opacity*alpha*fade)
                    Render.FilledCircle(Vec2(x,y),4+width,rgba(color,26*alpha),0,1,10)
                    Render.FilledCircle(Vec2(x,y),math.max(1,width*0.82),color,0,1,8)
                end
            end

            if drawn<110 and (edge.i+edge.j)%4==0 then
                local travel=(S.time*0.42+seed*0.013)%1
                local tx,ty=point(travel,bow*0.25,0)
                local pulseColor=dynamicColor(travel,seed,185*opacity*alpha*fade)
                Render.FilledCircle(Vec2(tx,ty),2.8+width,rgba(pulseColor,28*alpha),0,1,10)
                Render.FilledCircle(Vec2(tx,ty),math.max(0.7,width*0.65),pulseColor,0,1,8)
            end
            degree[edge.i],degree[edge.j]=degree[edge.i]+1,degree[edge.j]+1
            drawn=drawn+1
        end
    end

    if nodeGlow>0 then
        for i=1,count do
            if degree[i] and degree[i]>=2 then
                local p=S.particles[i]
                local amount=clamp((degree[i]-1)*26,24,120)*opacity*alpha*nodeGlow
                local color=dynamicColor(p.tint,i,amount)
                Render.FilledCircle(Vec2(p.x,p.y),3.4+degree[i]*0.35,rgba(color,amount*0.14),0,1,10)
                Render.FilledCircle(Vec2(p.x,p.y),1.1+degree[i]*0.14,color,0,1,8)
            end
        end
    end
end

local function drawWebExtra(alpha,a,b,c)
    if not get(script.webExtra,true) or not get(script.web,true) then return end
    local style=clamp(round(get(script.webExtraStyle,0))+1,1,6)
    local count=math.min(#S.particles,math.max(18,round(get(script.particleCount,105))))
    local range=get(script.webExtraRange,175)
    local rangeSq=range*range
    local intensity=get(script.webExtraIntensity,48)*0.01
    local speed=get(script.webExtraSpeed,100)*0.01
    local budget=math.max(8,round(get(script.webExtraBudget,55)))

    if style==1 then
        local triangles=0
        for i=1,count do
            if triangles>=budget then break end
            local p=S.particles[i]
            local first,second=nil,nil
            local d1,d2=rangeSq,rangeSq
            for j=1,count do
                if j~=i then
                    local q=S.particles[j]
                    local dx,dy=p.x-q.x,p.y-q.y
                    local ds=dx*dx+dy*dy
                    if ds<d1 then
                        second,d2=first,d1
                        first,d1=j,ds
                    elseif ds<d2 then
                        second,d2=j,ds
                    end
                end
            end
            if first and second and i<first and i<second then
                local p1,p2=S.particles[first],S.particles[second]
                local pulse=0.72+math.sin(S.time*1.7+i*0.31)*0.28
                local fill=mix(a,b,(p.tint+p1.tint+p2.tint)/3,28*intensity*alpha*pulse)
                local points={Vec2(p.x,p.y),Vec2(p1.x,p1.y),Vec2(p2.x,p2.y)}
                Render.FilledTriangle(points,fill)
                Render.Triangle(points,rgba(fill,78*intensity*alpha*pulse),1)
                local cx=(p.x+p1.x+p2.x)/3
                local cy=(p.y+p1.y+p2.y)/3
                Render.FilledCircle(Vec2(cx,cy),1.2,rgba(c,105*intensity*alpha*pulse),0,1,8)
                triangles=triangles+1
            end
        end
    elseif style==2 then
        local edges={}
        for i=1,count do
            local p1=S.particles[i]
            for j=i+1,count do
                local p2=S.particles[j]
                local dx,dy=p1.x-p2.x,p1.y-p2.y
                local ds=dx*dx+dy*dy
                if ds<rangeSq then edges[#edges+1]={i=i,j=j,d=ds} end
            end
        end
        table.sort(edges,function(x,y)return x.d<y.d end)
        for index=1,math.min(budget,#edges) do
            local edge=edges[index]
            local p1,p2=S.particles[edge.i],S.particles[edge.j]
            local phase=(S.time*speed*0.72+index*0.137)%1
            local x=p1.x+(p2.x-p1.x)*phase
            local y=p1.y+(p2.y-p1.y)*phase
            local fade=1-math.sqrt(edge.d)/range
            local color=mix(a,c,phase,225*intensity*alpha*fade)
            Render.FilledCircle(Vec2(x,y),5.2,rgba(color,34*intensity*alpha*fade),0,1,12)
            Render.FilledCircle(Vec2(x,y),1.8,color,0,1,8)
        end
    elseif style==3 then
        local edges={}
        for i=1,count do
            local p1=S.particles[i]
            for j=i+1,count do
                local p2=S.particles[j]
                local dx,dy=p2.x-p1.x,p2.y-p1.y
                local ds=dx*dx+dy*dy
                if ds<rangeSq then edges[#edges+1]={i=i,j=j,d=ds} end
            end
        end
        table.sort(edges,function(x,y)return x.d<y.d end)
        for index=1,math.min(budget,#edges) do
            local edge=edges[index]
            local p1,p2=S.particles[edge.i],S.particles[edge.j]
            local segments=6
            local prevX,prevY=p1.x,p1.y
            local fade=1-math.sqrt(edge.d)/range
            local color=mix(a,c,(math.sin(S.time*2+index)+1)*0.5,195*intensity*alpha*fade)
            for segment=1,segments do
                local t=segment/segments
                local x=p1.x+(p2.x-p1.x)*t
                local y=p1.y+(p2.y-p1.y)*t
                if segment<segments then
                    local jitter=math.sin(S.time*25+index*3.7+segment*8.1)*7*intensity
                    local dx,dy=p2.x-p1.x,p2.y-p1.y
                    local len=math.sqrt(dx*dx+dy*dy)
                    if len>0.001 then x=x-dy/len*jitter y=y+dx/len*jitter end
                end
                line(prevX,prevY,x,y,rgba(color,25*intensity*alpha*fade),3.5)
                line(prevX,prevY,x,y,color,1)
                prevX,prevY=x,y
            end
            if index%5==0 then
                local pulse=(S.time*speed*1.2+index*0.11)%1
                local px=p1.x+(p2.x-p1.x)*pulse
                local py=p1.y+(p2.y-p1.y)*pulse
                Render.FilledCircle(Vec2(px,py),2.2,Color(255,255,255,220*intensity*alpha*fade),0,1,8)
            end
        end
    elseif style==4 then
        if not S.cursor then return end
        local nearby={}
        for i=1,count do
            local p=S.particles[i]
            local dx,dy=p.x-S.cursor.x,p.y-S.cursor.y
            local ds=dx*dx+dy*dy
            if ds<rangeSq then nearby[#nearby+1]={p=p,d=ds,i=i} end
        end
        table.sort(nearby,function(x,y)return x.d<y.d end)
        local visible=math.min(budget,#nearby,18)
        Render.FilledCircle(S.cursor,18+intensity*12,rgba(a,18*intensity*alpha),0,1,18)
        Render.Circle(S.cursor,10+intensity*5,rgba(c,135*intensity*alpha),1.4,S.time*42,0.76,true,28)
        for i=1,visible do
            local node=nearby[i]
            local fade=1-math.sqrt(node.d)/range
            local color=particleColor(node.p,a,b,c,190*intensity*alpha*fade)
            line(S.cursor.x,S.cursor.y,node.p.x,node.p.y,rgba(color,52*intensity*alpha*fade),5)
            line(S.cursor.x,S.cursor.y,node.p.x,node.p.y,color,1.35)
            Render.Circle(Vec2(node.p.x,node.p.y),3.5+i*0.08,rgba(color,135*intensity*alpha*fade),1,0,1,false,14)
            for pulseIndex=0,1 do
                local t=(S.time*speed*(0.72+pulseIndex*0.18)+i*0.09+pulseIndex*0.5)%1
                local x=S.cursor.x+(node.p.x-S.cursor.x)*t
                local y=S.cursor.y+(node.p.y-S.cursor.y)*t
                Render.FilledCircle(Vec2(x,y),pulseIndex==0 and 2.2 or 1.4,rgba(pulseIndex==0 and c or a,230*intensity*alpha*fade),0,1,8)
            end
        end
    elseif style==5 then
        local visible=math.min(count,budget)
        for i=1,visible do
            local p=S.particles[i]
            local radius=(9+p.radius*3.2)*(0.72+intensity*0.85)*(0.92+math.sin(S.time*1.8+p.phase)*0.08)
            local color=particleColor(p,a,b,c,255)
            if Render.CircleGradient then
                Render.CircleGradient(Vec2(p.x,p.y),radius*2.2,rgba(color,0),rgba(color,62*intensity*alpha),0,1)
            end
            Render.FilledCircle(Vec2(p.x,p.y),radius,rgba(color,48*intensity*alpha),0,1,22)
        end
        local links=0
        for i=1,visible do
            if links>=budget then break end
            local p1=S.particles[i]
            for j=i+1,math.min(visible,i+18) do
                if links>=budget then break end
                local p2=S.particles[j]
                local dx,dy=p2.x-p1.x,p2.y-p1.y
                local distance=math.sqrt(dx*dx+dy*dy)
                local mergeRange=(22+p1.radius*3+p2.radius*3)*(0.8+intensity)
                if distance<mergeRange then
                    local merge=1-distance/mergeRange
                    local color=mix(a,c,(p1.tint+p2.tint)*0.5,54*intensity*alpha*merge)
                    line(p1.x,p1.y,p2.x,p2.y,color,6+merge*18*intensity)
                    links=links+1
                end
            end
        end
    else
        local edges={}
        for i=1,count do
            local p1=S.particles[i]
            for j=i+1,count do
                local p2=S.particles[j]
                local dx,dy=p2.x-p1.x,p2.y-p1.y
                local ds=dx*dx+dy*dy
                if ds<rangeSq then edges[#edges+1]={i=i,j=j,d=ds} end
            end
        end
        table.sort(edges,function(x,y)return x.d<y.d end)
        for index=1,math.min(budget,#edges) do
            local edge=edges[index]
            local p1,p2=S.particles[edge.i],S.particles[edge.j]
            local dx,dy=p2.x-p1.x,p2.y-p1.y
            local length=math.sqrt(dx*dx+dy*dy)
            local nx,ny=0,0
            if length>0.001 then nx=-dy/length ny=dx/length end
            local segments=8
            local prevX,prevY=p1.x,p1.y
            local fade=1-length/range
            local color=mix(a,b,(p1.tint+p2.tint)*0.5,145*intensity*alpha*fade)
            for segment=1,segments do
                local t=segment/segments
                local bow=math.sin(t*math.pi)*math.sin(S.time*speed*2+index*0.6)*18*intensity
                local x=p1.x+dx*t+nx*bow
                local y=p1.y+dy*t+ny*bow
                line(prevX,prevY,x,y,rgba(color,24*intensity*alpha*fade),3)
                line(prevX,prevY,x,y,color,1)
                prevX,prevY=x,y
            end
        end
    end
end

local function drawParticles(alpha, a, b, c)
    if not get(script.web, true) then return end
    local count = math.min(#S.particles,math.max(18,round(get(script.particleCount,105))))
    local sizeScale = get(script.particleSize, 100) * 0.01
    local baseOpacity = get(script.particleOpacity, 72) * 0.01
    local glow = get(script.particleGlow, 46) * 0.01
    local style = clamp(round(get(script.particleStyle, 0)) + 1, 1, 4)
    local pulseAmount = get(script.particlePulse, 28) * 0.01
    local twinkleAmount = get(script.particleTwinkle, 24) * 0.01

    for i = 1, count do
        local p = S.particles[i]
        local wave = math.sin(S.time * (1.3 + p.depth) + p.phase)
        local pulse = 1 + wave * 0.28 * pulseAmount
        local twinkle = 1 - twinkleAmount * 0.45 + ((math.sin(S.time * 3.1 + p.phase * 2) + 1) * 0.5) * twinkleAmount * 0.45
        local radius = p.radius * sizeScale * p.depth * pulse
        local color = particleColor(p, a, b, c, 255)
        local opacity = clamp(baseOpacity * twinkle, 0.02, 1.5)
        if i%13==0 then
            local corona=radius*(2.5+0.35*math.sin(S.time*2+p.phase))
            Render.Circle(Vec2(p.x,p.y),corona,rgba(color,48*opacity*alpha),1,S.time*28+i*17,0.36,true,20)
            local angle=S.time*(0.8+p.depth*0.35)+p.phase
            Render.FilledCircle(Vec2(p.x+math.cos(angle)*corona,p.y+math.sin(angle)*corona),math.max(0.55,radius*0.18),rgba(c,145*opacity*alpha),0,1,8)
        end
        if glow > 0 then
            Render.FilledCircle(Vec2(p.x,p.y),radius*(2.2+glow*2.5),rgba(color,30*opacity*alpha*glow),0,1,16)
        end
        if style == 1 then
            Render.FilledCircle(Vec2(p.x,p.y),radius*1.65,rgba(color,52*opacity*alpha),0,1,12)
            Render.FilledCircle(Vec2(p.x,p.y),radius,rgba(color,205*opacity*alpha),0,1,10)
            Render.FilledCircle(Vec2(p.x-radius*0.22,p.y-radius*0.22),math.max(0.55,radius*0.32),Color(255,255,255,145*opacity*alpha),0,1,8)
        elseif style == 2 then
            Render.Circle(Vec2(p.x,p.y),radius*1.55,rgba(color,95*opacity*alpha),1,0,1,false,18)
            Render.FilledCircle(Vec2(p.x,p.y),math.max(0.8,radius*0.72),rgba(color,225*opacity*alpha),0,1,8)
            Render.FilledCircle(Vec2(p.x,p.y),math.max(0.45,radius*0.25),Color(255,255,255,180*opacity*alpha),0,1,8)
        elseif style == 3 then
            local rotation=S.time*(0.45+p.depth*0.18)+p.phase
            local ux,uy=math.cos(rotation),math.sin(rotation)
            local vx,vy=-uy,ux
            local long=radius*(1.8+pulse*0.35)
            local wide=radius*(0.85+pulse*0.18)
            local top=Vec2(p.x+ux*long,p.y+uy*long)
            local bottom=Vec2(p.x-ux*long,p.y-uy*long)
            local left=Vec2(p.x-vx*wide,p.y-vy*wide)
            local right=Vec2(p.x+vx*wide,p.y+vy*wide)
            local upper={top,left,right}
            local lower={bottom,left,right}
            Render.FilledTriangle(upper,rgba(color,52*opacity*alpha))
            Render.FilledTriangle(lower,rgba(c,34*opacity*alpha))
            Render.Triangle(upper,rgba(color,185*opacity*alpha),1)
            Render.Triangle(lower,rgba(c,145*opacity*alpha),1)
            line(top.x,top.y,bottom.x,bottom.y,rgba(Color(255,255,255,255),72*opacity*alpha),1)
            Render.FilledCircle(Vec2(p.x,p.y),math.max(0.7,radius*0.42),Color(255,255,255,205*opacity*alpha),0,1,8)
        else
            local center=Vec2(p.x,p.y)
            local orbit=radius*(1.7+pulse*0.28)
            Render.FilledCircle(center,radius*1.7,rgba(color,38*opacity*alpha),0,1,14)
            Render.FilledCircle(center,math.max(0.8,radius*0.72),rgba(color,215*opacity*alpha),0,1,10)
            Render.FilledCircle(center,math.max(0.45,radius*0.25),Color(255,255,255,220*opacity*alpha),0,1,8)
            Render.Circle(center,orbit,rgba(color,125*opacity*alpha),1,S.time*34+i*13,0.68,true,24)
            Render.Circle(center,orbit*0.72,rgba(c,90*opacity*alpha),1,-S.time*42+i*9,0.48,true,20)
            for satellite=1,3 do
                local angle=S.time*(1.2+satellite*0.17)+p.phase+satellite*K.TAU/3
                local distance=orbit*(satellite==2 and 0.72 or 1)
                local sx=p.x+math.cos(angle)*distance
                local sy=p.y+math.sin(angle)*distance
                local satelliteColor=satellite==2 and c or color
                Render.FilledCircle(Vec2(sx,sy),math.max(0.65,radius*(0.18+satellite*0.035)),rgba(satelliteColor,190*opacity*alpha),0,1,8)
            end
        end
    end
end

local function trailColor(t, a, b, c, alpha)
    if t < 0.55 then return mix(b, a, t / 0.55, alpha) end
    return mix(a, c, (t - 0.55) / 0.45, alpha)
end

local function drawMouseTrail(alpha, a, b, c)
    if not get(script.mouseTrail, true) then return end
    local opacity=get(script.trailOpacity,88)*0.01
    local scale=get(script.trailSize,120)*0.01
    local glow=get(script.trailGlow,65)*0.01
    local motion=get(script.trailMotion,45)*0.01
    local detail=get(script.trailDetail,62)*0.01
    local continuity=get(script.trailContinuity,92)*0.01
    local mode=clamp(round(get(script.trailMode,1))+1,1,12)
    local n=#S.trail
    if n==0 then return end

    local function widthAt(t,life,speed)
        local speedControl=get(script.trailSpeedWidth,38)*0.01
        local rawSpeed=clamp((speed or 0)/28,0.78,1.75)
        local speedBoost=1+(rawSpeed-1)*speedControl
        local taper=0.12+t*0.88
        return (1+t*4.4)*scale*life*speedBoost*taper
    end

    if mode==2 or mode==3 or mode==5 or mode==6 or mode==7 or mode==8 or mode==9 or mode==10 or mode==11 or mode==12 then
        for i=2,n do
            local p1,p2=S.trail[i-1],S.trail[i]
            local t=i/n
            local life=math.min(p1.life,p2.life)
            local width=widthAt(t,life,p2.speed)*(1+clamp(p2.curvature or 0,0,1)*0.22*detail)
            local color=trailColor(t,a,b,c,185*opacity*alpha*life)
            local dx,dy=p2.x-p1.x,p2.y-p1.y
            local length=math.sqrt(dx*dx+dy*dy)
            local nx,ny=0,0
            if length>0.001 then nx=-dy/length ny=dx/length end

            if continuity>0.05 then
                Render.FilledCircle(Vec2(p2.x,p2.y),math.max(0.7,width*(0.28+continuity*0.22)),
                    rgba(color,118*opacity*alpha*life*continuity),0,1,10)
            end
            if get(script.trailEcho,false) then
                local echoOffset=get(script.trailEchoOffset,6)
                local echoOpacity=get(script.trailEchoOpacity,28)*0.01
                line(p1.x+nx*echoOffset,p1.y+ny*echoOffset,p2.x+nx*echoOffset,p2.y+ny*echoOffset,
                    rgba(b,125*opacity*alpha*life*echoOpacity),math.max(0.8,width*0.46))
            end
            local ribbonLayers=get(script.trailRibbonLayers,2)
            if ribbonLayers>1 and (mode==2 or mode==3 or mode==6 or mode==8) then
                for layer=2,ribbonLayers do
                    local offset=(layer-1)*width*0.34*(layer%2==0 and 1 or -1)
                    local layerColor=layer%2==0 and b or c
                    line(p1.x+nx*offset,p1.y+ny*offset,p2.x+nx*offset,p2.y+ny*offset,
                        rgba(layerColor,52*opacity*alpha*life),math.max(0.7,width*(0.42-layer*0.035)))
                end
            end

            if mode==2 then
                if glow>0 then line(p1.x,p1.y,p2.x,p2.y,rgba(color,30*opacity*alpha*life*glow),width*(3+glow*2.2)) end
                line(p1.x,p1.y,p2.x,p2.y,color,width)
                line(p1.x,p1.y,p2.x,p2.y,Color(250,252,255,128*opacity*alpha*life),math.max(0.7,width*0.25))
            elseif mode==3 then
                if glow>0 then line(p1.x,p1.y,p2.x,p2.y,rgba(color,38*opacity*alpha*life*glow),width*(3.4+glow*2.6)) end
                line(p1.x,p1.y,p2.x,p2.y,color,width*1.45)
                line(p1.x,p1.y,p2.x,p2.y,Color(255,255,255,175*opacity*alpha*life),math.max(0.8,width*0.22))
                if i%4==0 then Render.FilledCircle(Vec2(p2.x,p2.y),width*0.9,rgba(c,60*opacity*alpha*life),0,1,12) end
            elseif mode==5 then
                line(p1.x,p1.y,p2.x,p2.y,rgba(color,75*opacity*alpha*life),math.max(1,width*0.18))
                if i%3==0 then
                    Render.FilledCircle(Vec2(p2.x,p2.y),width*1.8,rgba(color,25*opacity*alpha*life*glow),0,1,12)
                    Render.FilledCircle(Vec2(p2.x,p2.y),width*0.72,rgba(color,195*opacity*alpha*life),0,1,10)
                    Render.FilledCircle(Vec2(p2.x,p2.y),math.max(0.6,width*0.2),Color(255,255,255,170*opacity*alpha*life),0,1,8)
                end
            elseif mode==6 then
                local wave=math.sin(S.time*(4+motion*5)+i*0.42)*width*(0.22+motion*0.75)
                line(p1.x+nx*wave,p1.y+ny*wave,p2.x+nx*wave,p2.y+ny*wave,rgba(a,45*opacity*alpha*life),width*(3+glow*2))
                line(p1.x+nx*wave,p1.y+ny*wave,p2.x+nx*wave,p2.y+ny*wave,color,width*1.45)
                line(p1.x-nx*wave*0.65,p1.y-ny*wave*0.65,p2.x-nx*wave*0.65,p2.y-ny*wave*0.65,rgba(c,105*opacity*alpha*life),width*0.62)
            elseif mode==7 then
                local helixSpread=get(script.trailHelixSpread,100)*0.01
                local helix=math.sin(S.time*(5+motion*4)+i*(0.38+motion*0.25))*width*(0.55+motion)*helixSpread
                local x1a,y1a=p1.x+nx*helix,p1.y+ny*helix
                local x2a,y2a=p2.x+nx*helix,p2.y+ny*helix
                local x1b,y1b=p1.x-nx*helix,p1.y-ny*helix
                local x2b,y2b=p2.x-nx*helix,p2.y-ny*helix
                line(x1a,y1a,x2a,y2a,rgba(a,185*opacity*alpha*life),math.max(1,width*0.42))
                line(x1b,y1b,x2b,y2b,rgba(c,185*opacity*alpha*life),math.max(1,width*0.42))
                if i%4==0 and detail>0.2 then line(x2a,y2a,x2b,y2b,rgba(b,95*opacity*alpha*life*detail),1) end
                Render.FilledCircle(Vec2(x2a,y2a),math.max(0.8,width*0.25),rgba(a,210*opacity*alpha*life),0,1,8)
                Render.FilledCircle(Vec2(x2b,y2b),math.max(0.8,width*0.25),rgba(c,210*opacity*alpha*life),0,1,8)
            elseif mode==8 then
                for layer=1,3 do
                    local phase=S.time*(1.8+layer*0.35)+i*0.22+layer*1.7
                    local wave=math.sin(phase)*width*(0.35+motion*0.9)*layer*0.42
                    local lc=layer==1 and a or (layer==2 and b or c)
                    local lw=width*(1.65-layer*0.28)
                    line(p1.x+nx*wave,p1.y+ny*wave,p2.x+nx*wave,p2.y+ny*wave,rgba(lc,32*opacity*alpha*life*glow),lw*(2.4+glow*1.8))
                    line(p1.x+nx*wave,p1.y+ny*wave,p2.x+nx*wave,p2.y+ny*wave,rgba(lc,(115-layer*12)*opacity*alpha*life),lw)
                end
            elseif mode==9 then
                local flap=0.72+math.sin(S.time*(4+motion*4)+i*0.32)*0.28
                local span=width*(1.4+detail*1.8)*flap
                local back=width*(1.2+detail)
                local lx=p2.x-dx/math.max(length,0.001)*back+nx*span
                local ly=p2.y-dy/math.max(length,0.001)*back+ny*span
                local rx=p2.x-dx/math.max(length,0.001)*back-nx*span
                local ry=p2.y-dy/math.max(length,0.001)*back-ny*span
                line(p2.x,p2.y,lx,ly,rgba(c,165*opacity*alpha*life),math.max(1,width*0.34))
                line(p2.x,p2.y,rx,ry,rgba(a,165*opacity*alpha*life),math.max(1,width*0.34))
                if i%3==0 then
                    line(p2.x,p2.y,lx+nx*span*0.35,ly+ny*span*0.35,rgba(Color(255,205,105,255),110*opacity*alpha*life),1)
                    line(p2.x,p2.y,rx-nx*span*0.35,ry-ny*span*0.35,rgba(Color(255,205,105,255),110*opacity*alpha*life),1)
                end
                Render.FilledCircle(Vec2(p2.x,p2.y),math.max(0.8,width*0.35),rgba(c,205*opacity*alpha*life),0,1,8)
            elseif mode==10 then
                local crack=math.sin(S.time*13+i*1.73)*width*(0.3+motion)
                local left=width*(0.7+detail*0.8)+crack
                local right=-width*(0.7+detail*0.8)+crack*0.45
                line(p1.x+nx*left,p1.y+ny*left,p2.x+nx*left,p2.y+ny*left,rgba(a,38*opacity*alpha*life*glow),width*(2.2+glow*2))
                line(p1.x+nx*left,p1.y+ny*left,p2.x+nx*left,p2.y+ny*left,rgba(a,190*opacity*alpha*life),math.max(1,width*0.42))
                line(p1.x+nx*right,p1.y+ny*right,p2.x+nx*right,p2.y+ny*right,rgba(c,190*opacity*alpha*life),math.max(1,width*0.42))
                line(p1.x,p1.y,p2.x,p2.y,Color(2,2,10,145*opacity*alpha*life),math.max(1,width*0.8))
                if i%4==0 then line(p2.x+nx*left,p2.y+ny*left,p2.x+nx*right,p2.y+ny*right,rgba(b,105*opacity*alpha*life),1) end
            elseif mode==11 then
                local jitter=math.sin(S.time*30+i*5.21)*width*(0.35+detail)
                local j1x,j1y=p1.x+nx*jitter,p1.y+ny*jitter
                local j2x,j2y=p2.x-nx*jitter*0.7,p2.y-ny*jitter*0.7
                line(j1x,j1y,j2x,j2y,rgba(a,42*opacity*alpha*life*glow),width*(2.6+glow*2.2))
                line(j1x,j1y,j2x,j2y,rgba(Color(210,245,255,255),215*opacity*alpha*life),math.max(1,width*0.35))
                if i%5==0 then
                    local branch=width*(2+detail*2)
                    line(j2x,j2y,j2x+nx*branch,j2y+ny*branch,rgba(c,125*opacity*alpha*life),1)
                    Render.FilledCircle(Vec2(j2x,j2y),math.max(0.8,width*0.3),Color(255,255,255,220*opacity*alpha*life),0,1,8)
                end
            else
                local glitchStrength=get(script.trailGlitchStrength,100)*0.01
                local snap=round(math.sin(S.time*18+i*2.7)*3)*width*(0.25+motion)*glitchStrength
                local segment=(i%4)~=0
                if segment then
                    line(p1.x+snap,p1.y-2,p2.x+snap,p2.y-2,rgba(a,155*opacity*alpha*life),math.max(1,width*0.32))
                    line(p1.x-snap*0.6,p1.y+2,p2.x-snap*0.6,p2.y+2,rgba(c,145*opacity*alpha*life),math.max(1,width*0.32))
                    line(p1.x,p1.y,p2.x,p2.y,Color(245,250,255,150*opacity*alpha*life),math.max(1,width*0.18))
                elseif detail>0.35 then
                    local bar=width*(2+detail*3)
                    line(p2.x-bar,p2.y,p2.x+bar,p2.y,rgba(b,130*opacity*alpha*life),math.max(1,width*0.28))
                end
            end

            local sparkDensity=get(script.trailSparkDensity,62)*0.01
            if detail>0.35 and sparkDensity>0.05 and i%math.max(2,round(12-detail*5-sparkDensity*5))==0 and mode~=7 then
                local spark=math.max(0.8,width*0.22*detail)
                local drift=math.sin(S.time*7+i)*width*(0.4+motion)
                Render.FilledCircle(Vec2(p2.x+nx*drift,p2.y+ny*drift),spark,rgba(c,125*opacity*alpha*life),0,1,8)
            end
        end
    else
        for i=1,n do
            local p=S.trail[i]
            local t=i/n
            local life=p.life
            local size=widthAt(t,life,p.speed)*(1+clamp(p.curvature or 0,0,1)*0.2*detail)
            local color=trailColor(t,a,b,c,255)
            if mode==1 then
                Render.FilledCircle(Vec2(p.x,p.y),size*(2.8+glow*2.4),rgba(color,27*opacity*alpha*life*glow),0,1,14)
                Render.FilledCircle(Vec2(p.x,p.y),size,rgba(color,175*opacity*alpha*life),0,1,10)
                Render.FilledCircle(Vec2(p.x,p.y),math.max(0.7,size*0.32),Color(255,255,255,185*opacity*alpha*life),0,1,8)
            else
                local pulse=0.72+math.sin(S.time*(7+motion*5)+(p.phase or 0))*0.28
                local ray=size*(2+pulse+detail)
                line(p.x-ray,p.y,p.x+ray,p.y,rgba(color,145*opacity*alpha*life),1)
                line(p.x,p.y-ray,p.x,p.y+ray,rgba(color,145*opacity*alpha*life),1)
                if detail>0.55 then
                    line(p.x-ray*0.5,p.y-ray*0.5,p.x+ray*0.5,p.y+ray*0.5,rgba(c,70*opacity*alpha*life),1)
                end
                Render.FilledCircle(Vec2(p.x,p.y),math.max(0.8,size*0.48),rgba(color,220*opacity*alpha*life),0,1,8)
            end
        end
    end

end

local function drawClickBursts(alpha, a, b, c)
    if not get(script.clickEffect, true) then return end
    local sizeScale = get(script.clickEffectSize, 100) * 0.01
    local glow = get(script.clickEffectGlow, 68) * 0.01
    for _, burst in ipairs(S.clickBursts) do
        local progress = clamp(burst.age / burst.life, 0, 1)
        local fade = (1 - progress) * (1 - progress)
        local waveRadius = burst.radius * (1 - (1 - progress) * (1 - progress))
        local ignition=math.max(0,1-progress*3.4)
        if ignition>0 then
            Render.Circle(Vec2(burst.x,burst.y),(9+waveRadius*0.08)*sizeScale,rgba(c,150*alpha*ignition),2.2,burst.age*120,0.62,true,28)
            Render.FilledCircle(Vec2(burst.x,burst.y),(3+waveRadius*0.018)*sizeScale,Color(255,255,255,155*alpha*ignition),0,1,12)
        end

        if burst.style == 1 then
            local blastFade = math.max(0, 1 - progress * 4.2)
            if blastFade > 0 then
                Render.FilledCircle(Vec2(burst.x, burst.y), (20 + waveRadius * 0.16) * sizeScale,
                    rgba(c, 34 * alpha * blastFade * glow), 0, 1, 28)
                Render.FilledCircle(Vec2(burst.x, burst.y), (7 + waveRadius * 0.055) * sizeScale,
                    Color(255, 245, 225, 175 * alpha * blastFade), 0, 1, 20)
                for ray = 1, 18 do
                    local angle = ray / 18 * K.TAU + burst.age * 0.7
                    local inner = 12 * sizeScale
                    local outer = (34 + waveRadius * (0.09 + (ray % 4) * 0.018)) * sizeScale
                    line(burst.x + math.cos(angle) * inner, burst.y + math.sin(angle) * inner,
                        burst.x + math.cos(angle) * outer, burst.y + math.sin(angle) * outer,
                        rgba(ray % 3 == 0 and c or a, 125 * alpha * blastFade), ray % 4 == 0 and 2 or 1)
                end
            end
        elseif burst.style == 2 then

            local ringCount = get(script.clickShockwaveRings, 5)
            for ring = 0, ringCount - 1 do
                local ringProgress = clamp(progress * 1.18 - ring * (0.36 / math.max(1, ringCount - 1)), 0, 1)
                if ringProgress > 0 then
                    local ringRadius = burst.radius * (1 - (1 - ringProgress) * (1 - ringProgress))
                    local ringFade = (1 - ringProgress) * fade
                    local color = ring == 2 and c or (ring % 2 == 0 and a or b)
                    Render.Circle(Vec2(burst.x, burst.y), ringRadius,
                        rgba(color, (190 - ring * 22) * alpha * ringFade),
                        1 + (1 - ringProgress) * (3.6 - ring * 0.35), 0, 1, false, 64)
                    if glow > 0 and ring < 3 then
                        Render.Circle(Vec2(burst.x, burst.y), ringRadius + 3 + ring * 2,
                            rgba(color, 38 * alpha * ringFade * glow), 5 + glow * 4, 0, 1, false, 64)
                    end
                end
            end
            if progress < 0.72 then
                local spokeFade = (1 - progress / 0.72) * alpha
                local spokeCount = get(script.clickShockwaveSpokes, 28)
                for spoke = 1, spokeCount do
                    local angle = spoke / spokeCount * K.TAU + math.sin(spoke * 2.17) * 0.05
                    local variation = 0.88 + (spoke % 5) * 0.032
                    local inner = waveRadius * 0.68
                    local outer = waveRadius * variation
                    line(burst.x + math.cos(angle) * inner, burst.y + math.sin(angle) * inner,
                        burst.x + math.cos(angle) * outer, burst.y + math.sin(angle) * outer,
                        rgba(spoke % 4 == 0 and c or a, 74 * spokeFade), spoke % 7 == 0 and 2 or 1)
                end
            end
        end

        for i, particle in ipairs(burst.particles) do
            local color = particle.tint > 0.82 and c or mix(a, b, particle.tint, 255)
            local size = particle.size * sizeScale * (0.62 + fade * 0.95)
            local velocity = math.sqrt(particle.vx * particle.vx + particle.vy * particle.vy)
            local nx, ny = 0, 0
            if velocity > 0.01 then nx, ny = particle.vx / velocity, particle.vy / velocity end

            if burst.style == 1 then
                local tailScale = get(script.clickSparkTail, 100) * 0.01
                local tail = math.min(burst.radius * 0.075, 12 + velocity * 0.08) * sizeScale * tailScale
                if glow > 0 then
                    line(particle.x, particle.y, particle.x - nx * tail * 1.45, particle.y - ny * tail * 1.45,
                        rgba(color, 35 * alpha * fade * glow), math.max(2, size * 3.1))
                end
                line(particle.x, particle.y, particle.x - nx * tail, particle.y - ny * tail,
                    rgba(color, 190 * alpha * fade), math.max(1, size * 0.8))
                line(particle.x, particle.y, particle.x - nx * tail * 0.42, particle.y - ny * tail * 0.42,
                    Color(255, 250, 235, 190 * alpha * fade), math.max(0.8, size * 0.3))
                Render.FilledCircle(Vec2(particle.x, particle.y), size * 1.1,
                    rgba(color, 235 * alpha * fade), 0, 1, 9)
                local branches=get(script.clickSparkBranches,56)*0.01
                if branches>0.05 and i%math.max(2,round(7-branches*4))==0 then
                    local sideX,sideY=-ny*size*(2.4+branches*3),nx*size*(2.4+branches*3)
                    line(particle.x,particle.y,particle.x+sideX,particle.y+sideY,
                        rgba(c,145*alpha*fade*branches),1)
                    line(particle.x,particle.y,particle.x-sideX*0.72,particle.y-sideY*0.72,
                        rgba(a,112*alpha*fade*branches),1)
                    Render.FilledCircle(Vec2(particle.x+sideX,particle.y+sideY),math.max(0.6,size*0.32),
                        Color(255,248,225,155*alpha*fade*branches),0,1,8)
                end
            elseif burst.style == 2 then
                local dust=get(script.clickShockwaveDust,52)*0.01
                if dust>0.02 and i%math.max(1,round(3-dust*2))==0 then
                    Render.FilledCircle(Vec2(particle.x,particle.y),size*(2.8+dust*3.5),
                        rgba(color,18*alpha*fade*dust*glow),0,1,11)
                    Render.FilledCircle(Vec2(particle.x, particle.y), size * (0.7 + particle.layer * 0.18),
                        rgba(color, 155 * alpha * fade * dust), 0, 1, 9)
                    if i % 6 == 0 then
                        line(particle.x - size * 3, particle.y, particle.x + size * 3, particle.y,
                            rgba(color, 85 * alpha * fade), 1)
                    end
                end
            elseif burst.style == 3 then

                local ux, uy = math.cos(particle.phase), math.sin(particle.phase)
                local vx, vy = -uy, ux
                local petalScale = get(script.clickSakuraPetal, 100) * 0.01
                local petalLength = size * 4.2 * petalScale
                local petalWidth = size * 1.65 * petalScale
                local tip = Vec2(particle.x + ux * petalLength, particle.y + uy * petalLength)
                local left = Vec2(particle.x - ux * petalLength * 0.28 + vx * petalWidth, particle.y - uy * petalLength * 0.28 + vy * petalWidth)
                local right = Vec2(particle.x - ux * petalLength * 0.28 - vx * petalWidth, particle.y - uy * petalLength * 0.28 - vy * petalWidth)
                Render.FilledCircle(Vec2(particle.x - ux * size * 0.45, particle.y - uy * size * 0.45),
                    petalWidth, rgba(Color(255, 155, 205, 255), 78 * alpha * fade), 0, 1, 10)
                Render.FilledTriangle({tip, left, right},
                    mix(Color(255, 215, 235, 255), c, particle.tint * 0.55, 190 * alpha * fade))
                local petalLayers=get(script.clickSakuraLayers,2)
                for layer=2,petalLayers do
                    local offset=(layer-1)*petalWidth*0.42
                    local layerTip=Vec2(tip.x-vx*offset,tip.y-vy*offset)
                    local layerLeft=Vec2(left.x-vx*offset,left.y-vy*offset)
                    local layerRight=Vec2(right.x-vx*offset,right.y-vy*offset)
                    Render.FilledTriangle({layerTip,layerLeft,layerRight},
                        rgba(layer%2==0 and a or c,65*alpha*fade/layer))
                end
                line(tip.x, tip.y, particle.x - ux * size, particle.y - uy * size,
                    Color(255, 245, 250, 105 * alpha * fade), 1)
            else

                local dustTwinkle = get(script.clickDustTwinkle, 72) * 0.01
                local pulse = 1 - dustTwinkle * 0.55 + (math.sin(S.time * 7 + particle.phase) + 1) * 0.275 * dustTwinkle
                local bloom=get(script.clickDustBloom,68)*0.01
                Render.FilledCircle(Vec2(particle.x, particle.y), size * (2.2 + bloom * 4 + glow * 2),
                    rgba(color, (9+bloom*20) * alpha * fade * glow * pulse), 0, 1, 12)
                Render.FilledCircle(Vec2(particle.x, particle.y), size * 0.72,
                    rgba(color, 215 * alpha * fade * pulse), 0, 1, 8)
                if i % 4 == 0 then
                    local ray = size * (3 + particle.layer)
                    line(particle.x - ray, particle.y, particle.x + ray, particle.y,
                        rgba(color, 125 * alpha * fade * pulse), 1)
                    line(particle.x, particle.y - ray, particle.x, particle.y + ray,
                        Color(255, 255, 255, 105 * alpha * fade * pulse), 1)
                end
            end
        end

        local flash = math.max(0, 1 - progress * 8)
        if flash > 0 then
            Render.FilledCircle(Vec2(burst.x, burst.y), (5 + flash * 22) * sizeScale,
                Color(255, 255, 255, 155 * alpha * flash), 0, 1, 18)
        end
    end
end

local function drawPersistentClickBursts(alpha)
    local a, b, c = palette()
    drawClickBursts(alpha, a, b, c)
end

local function drawCursorArtifact(alpha,a,b,c)
    if not get(script.cursorArtifact,true) or not S.cursor then return end
    local style=clamp(round(get(script.artifactStyle,0))+1,1,5)
    local size=get(script.artifactSize,30)
    local intensity=get(script.artifactIntensity,62)*0.01
    local speed=get(script.artifactSpeed,100)*0.01
    local motion=clamp(S.cursorSpeed/28,0,1)
    local angle=math.atan(S.cursorDy,S.cursorDx)
    if S.cursorSpeed<0.05 then angle=S.time*speed*0.45 end
    local ux,uy=math.cos(angle),math.sin(angle)
    local vx,vy=-uy,ux

    if style==1 then
        local facets=get(script.artifactFacets,6)
        local tip=Vec2(S.cursor.x+ux*size*(0.72+motion*0.38),S.cursor.y+uy*size*(0.72+motion*0.38))
        local back=Vec2(S.cursor.x-ux*size*0.48,S.cursor.y-uy*size*0.48)
        for facet=1,facets do
            local side=facet%2==0 and 1 or -1
            local spread=size*(0.18+facet/facets*0.28)
            local middle=Vec2(S.cursor.x+ux*size*(0.08-facet/facets*0.22)+vx*spread*side,S.cursor.y+uy*size*(0.08-facet/facets*0.22)+vy*spread*side)
            local color=facet%3==0 and c or (facet%2==0 and b or a)
            Render.FilledTriangle({tip,middle,back},rgba(color,(36+facet*9)*intensity*alpha))
            line(tip.x,tip.y,middle.x,middle.y,rgba(color,145*intensity*alpha),1)
        end
    elseif style==2 then

        local span=get(script.artifactWingSpan,100)*0.01
        local flap=0.72+math.sin(S.time*speed*7)*0.28
        for side=-1,1,2 do
            for wing=1,2 do
                local length=size*(0.62+wing*0.28)*span
                local spread=size*(0.25+wing*0.3)*flap*span*side
                local root=Vec2(S.cursor.x-ux*size*0.08,S.cursor.y-uy*size*0.08)
                local outer=Vec2(root.x-ux*length*0.35+vx*spread,root.y-uy*length*0.35+vy*spread)
                local tip=Vec2(root.x+ux*length+vx*spread*0.62,root.y+uy*length+vy*spread*0.62)
                local color=wing==1 and a or c
                Render.FilledTriangle({root,outer,tip},rgba(color,(34+wing*18)*intensity*alpha))
                line(root.x,root.y,tip.x,tip.y,rgba(color,165*intensity*alpha),1)
            end
        end
        line(S.cursor.x,S.cursor.y,S.cursor.x-ux*size*(0.8+motion),S.cursor.y-uy*size*(0.8+motion),rgba(b,115*intensity*alpha),2)
    elseif style==3 then

        local shards=get(script.artifactShardCount,7)
        for shard=1,shards do
            local phase=S.time*speed*(1.15+shard*0.025)+shard*K.TAU/shards
            local distance=size*(0.28+(shard%3)*0.14)
            local x=S.cursor.x+math.cos(phase)*distance
            local y=S.cursor.y+math.sin(phase*1.07)*distance
            local tx,ty=math.cos(phase+1.1),math.sin(phase+1.1)
            local px,py=-ty,tx
            local length=size*(0.13+(shard%4)*0.035)
            local color=shard%3==0 and c or (shard%2==0 and b or a)
            local top=Vec2(x+tx*length,y+ty*length)
            local left=Vec2(x-tx*length*0.55+px*length*0.48,y-ty*length*0.55+py*length*0.48)
            local right=Vec2(x-tx*length*0.55-px*length*0.48,y-ty*length*0.55-py*length*0.48)
            Render.FilledTriangle({top,left,right},rgba(color,145*intensity*alpha))
            line(top.x,top.y,left.x,left.y,rgba(Color(255,255,255,255),105*intensity*alpha),1)
        end
    elseif style==4 then

        local pulse=get(script.artifactEyePulse,64)*0.01
        local breathe=1+math.sin(S.time*speed*4)*0.14*pulse
        local left=Vec2(S.cursor.x-vx*size*0.72,S.cursor.y-vy*size*0.72)
        local right=Vec2(S.cursor.x+vx*size*0.72,S.cursor.y+vy*size*0.72)
        local upper=Vec2(S.cursor.x+ux*size*0.34*breathe,S.cursor.y+uy*size*0.34*breathe)
        local lower=Vec2(S.cursor.x-ux*size*0.34*breathe,S.cursor.y-uy*size*0.34*breathe)
        Render.FilledTriangle({left,upper,right},rgba(a,42*intensity*alpha))
        Render.FilledTriangle({left,lower,right},rgba(c,42*intensity*alpha))
        line(left.x,left.y,upper.x,upper.y,rgba(a,165*intensity*alpha),1)
        line(upper.x,upper.y,right.x,right.y,rgba(b,145*intensity*alpha),1)
        line(right.x,right.y,lower.x,lower.y,rgba(c,165*intensity*alpha),1)
        line(lower.x,lower.y,left.x,left.y,rgba(b,145*intensity*alpha),1)
        Render.FilledCircle(Vec2(S.cursor.x+ux*motion*size*0.16,S.cursor.y+uy*motion*size*0.16),size*0.13*breathe,rgba(b,205*intensity*alpha),0,1,12)
        Render.FilledCircle(S.cursor,math.max(1.4,size*0.045),Color(255,255,255,220*intensity*alpha),0,1,8)
    else

        local runes=get(script.artifactRuneCount,8)
        for rune=1,runes do
            local phase=S.time*speed*0.45+rune*K.TAU/runes
            local distance=size*(0.42+0.05*math.sin(S.time*speed*2+rune))
            local x=S.cursor.x+math.cos(phase)*distance
            local y=S.cursor.y+math.sin(phase)*distance
            local tx,ty=-math.sin(phase),math.cos(phase)
            local color=rune%3==0 and c or (rune%2==0 and b or a)
            line(x-tx*size*0.09,y-ty*size*0.09,x+tx*size*0.09,y+ty*size*0.09,rgba(color,155*intensity*alpha),1)
            line(x,y,x+math.cos(phase)*size*0.08,y+math.sin(phase)*size*0.08,rgba(color,105*intensity*alpha),1)
        end
        local tip=Vec2(S.cursor.x+ux*size*0.48,S.cursor.y+uy*size*0.48)
        local left=Vec2(S.cursor.x-ux*size*0.18+vx*size*0.15,S.cursor.y-uy*size*0.18+vy*size*0.15)
        local right=Vec2(S.cursor.x-ux*size*0.18-vx*size*0.15,S.cursor.y-uy*size*0.18-vy*size*0.15)
        Render.FilledTriangle({tip,left,right},rgba(c,148*intensity*alpha))
        line(tip.x,tip.y,S.cursor.x,S.cursor.y,Color(255,255,255,180*intensity*alpha),1)
    end
    Render.FilledCircle(S.cursor,math.max(1.4,size*0.06),Color(255,255,255,205*intensity*alpha),0,1,8)
end

local function drawLightningSegment(x1, y1, x2, y2, jitter, color, glow)
    local segments = 7
    local prevX, prevY = x1, y1
    for s = 1, segments do
        local t = s / segments
        local x = x1 + (x2 - x1) * t
        local y = y1 + (y2 - y1) * t
        if s < segments then
            local seed = math.sin(S.time * 32 + s * 9.17 + x2 * 0.013 + y2 * 0.021)
            x = x + seed * jitter
            y = y + math.cos(S.time * 27 + s * 7.31 + x2 * 0.02) * jitter
        end
        line(prevX, prevY, x, y, glow, 3)
        line(prevX, prevY, x, y, color, 1)
        prevX, prevY = x, y
    end
end

local function drawLightning(alpha, a, b, c)
    if not get(script.lightning, true) or not S.cursor then return end
    local count = math.min(#S.particles,math.max(18,round(get(script.particleCount,105))))
    local range = get(script.lightningRange, 245)
    local rangeSq = range * range
    local maxArcs = get(script.lightningCount, 3)
    local jitter = get(script.lightningJitter, 13)
    local opacity = get(script.lightningOpacity, 48) * 0.01
    local nearest = {}

    for i = 1, count do
        local p = S.particles[i]
        local dx, dy = p.x - S.cursor.x, p.y - S.cursor.y
        local distSq = dx * dx + dy * dy
        if distSq <= rangeSq then
            nearest[#nearest + 1] = {p = p, d = distSq}
        end
    end
    table.sort(nearest, function(x, y) return x.d < y.d end)

    for i = 1, math.min(maxArcs, #nearest) do
        local p = nearest[i].p
        local fade = 1 - math.sqrt(nearest[i].d) / range
        local color = particleColor(p, a, b, c, 170 * opacity * alpha * fade)
        local glow = rgba(color, 28 * opacity * alpha * fade)
        local style = clamp(round(get(script.lightningStyle, 0)) + 1, 1, 3)
        if style == 1 then
            drawLightningSegment(S.cursor.x,S.cursor.y,p.x,p.y,jitter,color,glow)
        elseif style == 2 then
            line(S.cursor.x,S.cursor.y,p.x,p.y,glow,5)
            line(S.cursor.x,S.cursor.y,p.x,p.y,color,1.5)
        else
            drawLightningSegment(S.cursor.x,S.cursor.y,p.x,p.y,jitter,color,glow)
            drawLightningSegment(S.cursor.x+3,S.cursor.y-2,p.x-3,p.y+2,jitter*0.65,rgba(c,color.a*0.75),glow)
        end
        local contact=3.5+math.sin(S.time*7+i)*1.2
        Render.FilledCircle(Vec2(p.x,p.y),contact*2.1,rgba(color,22*alpha*fade),0,1,10)
        Render.FilledCircle(Vec2(p.x,p.y),contact*0.46,Color(255,255,255,175*alpha*fade),0,1,8)
        Render.Circle(Vec2(p.x,p.y),contact*1.4,rgba(color,95*alpha*fade),1,S.time*90+i*31,0.5,true,18)
    end
end

local function drawPersistentTrail(alpha)
    local a,b,c=palette()
    local outside=get(script.trailOutsideOpacity,100)*0.01
    drawMouseTrail(alpha*outside,a,b,c)
end

local function drawGlobalPolish(alpha,a,b,c)
    if not S.cursor then return end
    local x,y=S.cursor.x,S.cursor.y
    local speedPulse=clamp(S.cursorSpeed/900,0,1)
    if get(script.cursorArtifact,true) or get(script.lightning,true) then
        local radius=14+speedPulse*18+math.sin(S.time*2.8)*2
        Render.Circle(Vec2(x,y),radius,rgba(a,34*alpha),1,S.time*38,0.28,true,28)
        Render.Circle(Vec2(x,y),radius*0.72,rgba(c,42*alpha),1,-S.time*52,0.22,true,24)
        for spark=1,3 do
            local angle=S.time*(1.2+spark*0.18)+spark*K.TAU/3
            local distance=radius*(0.72+spark*0.08)
            Render.FilledCircle(Vec2(x+math.cos(angle)*distance,y+math.sin(angle)*distance),1+speedPulse,rgba(spark==2 and b or c,125*alpha),0,1,8)
        end
    end
end

local function draw(alpha,includeTrail,includeClick)
    alpha=alpha*get(script.masterOpacity,100)*0.01
    local a,b,c=palette()
    drawBackdrop(clamp(alpha,0,1.35),a,b)
    drawAtmosphere(alpha,a,b,c)
    drawDotaTest(alpha)
    drawConnections(alpha,a,b,c)
    drawWebExtra(alpha,a,b,c)
    drawParticles(alpha,a,b,c)
    if includeTrail~=false then drawMouseTrail(alpha,a,b,c) end
    if includeClick~=false then drawClickBursts(alpha,a,b,c) end
    drawCursorArtifact(alpha,a,b,c)
    drawLightning(alpha,a,b,c)
    drawGlobalPolish(alpha,a,b,c)
end

script.OnScriptsLoaded = function()
    math.randomseed(os.time())
    S.screen = screenSize()
    createMenu()
    if applyLanguage then applyLanguage() end
    if updateMenuVisibility then updateMenuVisibility() end
    ensure(S.particles, 105, resetParticle)
end

script.OnFrame = function()
    if not script.enabled or not get(script.enabled, true) then return end
    local dt = deltaTime()
    local open = menuOpen()
    local persistentTrail = get(script.mouseTrail, true) and get(script.trailAlwaysVisible, true)
    local persistentClick = get(script.clickEffect, true) and get(script.clickAlwaysVisible, true)
    local justOpened = open and not S.wasOpen

    if justOpened then
        S.screen = screenSize()
        S.smoothCursor=nil
        S.lastCursor=nil
        S.lastScreenRefresh = S.time
        if get(script.smoothOpening, true) then S.fade = 0 else S.fade = 1 end
    end

    if open then
        if get(script.smoothOpening, true) then
            local duration = K.FADE * get(script.openDuration, 80) * 0.01
            S.fade = math.min(1, S.fade + dt / math.max(0.05, duration))
        else
            S.fade = 1
        end
    else
        if get(script.smoothClosing, true) then
            local duration = K.FADE * get(script.closeDuration, 95) * 0.01
            S.fade = math.max(0, S.fade - dt / math.max(0.05, duration))
        else
            S.fade = 0
        end
    end

    S.wasOpen = open
    if not open and S.fade <= 0 and not persistentTrail and not persistentClick and #S.clickBursts == 0 then
        S.lastReal = nil
        S.lastCursor = nil
        S.cursor = nil
        S.trail = {}
        return
    end

    if S.time - S.lastScreenRefresh >= K.SCREEN_REFRESH then
        S.screen = screenSize()
        S.lastScreenRefresh = S.time
    end

    local acceptCursor = open or persistentTrail or persistentClick
    local updateScene = open or S.fade > 0
    update(dt, acceptCursor, updateScene)

    if updateScene then draw(clamp(S.fade,0,1), open, open or not persistentClick) end
    if not open and persistentTrail then drawPersistentTrail(1) end
    if not open and persistentClick and #S.clickBursts > 0 then drawPersistentClickBursts(1) end
end

script.OnGameEnd = function()
    S.time = 0
    S.fade = 0
    S.wasOpen = false
    S.lastReal = nil
    S.lastCursor = nil
    S.smoothCursor = nil
    S.cursor = nil
    S.trail = {}
    S.clickBursts = {}
    S.dotaPieces = {}
    S.dotaImpacts = {}
end

return script
