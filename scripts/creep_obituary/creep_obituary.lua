-- некрологи. у каждого крипа есть имя и возраст, а когда ты его добиваешь
-- на экране вылезает некролог. денай тоже считается

---@diagnostic disable: undefined-global

local VERSION = "1.0.0"
local script = {}

local NAMES = {
    "Геннадий", "Валера", "Толик", "Серега", "Виталик", "Эдуард", "Аркадий", "Борис", "Жора", "Колян",
    "Петрович", "Семен", "Юрий", "Олег", "Вадим", "Стас", "Игорек", "Михалыч", "Рома", "Женек",
    "Анатолий", "Владлен", "Гоша", "Денчик", "Лёха", "Максимка", "Никита", "Паша", "Руслан", "Тимоха",
}

local LAST_WORDS = {
    "У него остались жена и ипотека.",
    "Он просто шел на работу.",
    "До пенсии оставалось два года.",
    "Он мечтал хоть раз дойти до вышки.",
    "Сегодня был его первый день.",
    "Он так и не узнал, чем кончился сериал.",
    "У него остались три кредита и хомяк.",
    "Он единственный кормил кота в подъезде.",
    "Он копил на новый щит.",
    "Мама ждала его к ужину.",
    "Он даже не успел поставить лайк.",
    "Его вклад в экономику: примерно 40 золота.",
    "Он вышел из казармы всего минуту назад.",
    "На прошлой неделе у него родилась дочь.",
    "Он всегда говорил, что это последняя волна.",
    "Он хотел открыть шаурмичную.",
    "Он был душой волны.",
    "Коллеги запомнят его как тихого и неконфликтного.",
    "Он успел ударить вышку один раз. Этого хватило.",
    "Он верил, что в этот раз все будет иначе.",
}

local DENY_WORDS = {
    "Его убили свои. Следствие ведется.",
    "Предан тем, кому доверял.",
    "Свои. Всегда свои.",
    "Друзья, называется.",
    "Враг его даже не тронул.",
}

local FOREST_WORDS = {
    "Он просто жил в лесу и никого не трогал.",
    "Лес не забудет.",
    "Он охранял этот лагерь 12 лет.",
    "Его детеныши остались одни.",
}

local ui = {}
local people = {}
local obituary = nil
local buried = 0
local font = nil
local okChronos, chronos = pcall(require, "chronos")

local function real()
    if okChronos and chronos and chronos.nanotime then return chronos.nanotime() end
    return os.clock()
end

local function pick(list) return list[math.random(#list)] end

local function isCreep(npc)
    return NPC.IsLaneCreep(npc) or NPC.IsNeutral(npc)
end

local function person(npc)
    local id = Entity.GetIndex(npc)
    local p = people[id]
    if not p then
        p = { name = pick(NAMES), age = math.random(17, 64) }
        people[id] = p
    end
    return p
end

local function owner(e)
    if e == nil then return nil end
    if Entity.IsHero(e) then return Hero.GetReplicatingOtherHeroModel(e) or e end
    return NPC.GetOwnerNPC(e)
end

-- меню

local function buildMenu()
    local tab = Menu.Create("Scripts", "Utility", "Некрологи", "Main")
    if not tab or not tab.Create then return end
    local g = tab:Create("Основное", Enum.GroupSide.Left)

    ui.enabled = g:Switch("Включить", true, "\u{f54c}")
    ui.names = g:Switch("Имена над крипами", true)
    ui.names:ToolTip("У каждого крипа имя и возраст. Когда он при смерти, имя краснеет.")
    ui.range = g:Slider("Дальность имен", 400, 3000, 1400, "%d")
    ui.obit = g:Switch("Некролог на экране", true)
    ui.obit:ToolTip("Когда добиваешь или денаишь крипа.")
    ui.counter = g:Switch("Счетчик похорон", true)
end

function script.OnScriptsLoaded()
    buildMenu()
end

-- логика

function script.OnEntityKilled(data)
    if type(data) ~= "table" or not data.target then return end
    local target = data.target
    if not Entity.IsEntity(target) or not isCreep(target) then return end

    local id = Entity.GetIndex(target)
    local p = people[id] or person(target)
    people[id] = nil

    local hero = Heroes.GetLocal()
    if not hero or owner(data.source) ~= hero then return end

    local line
    if Entity.IsSameTeam(target, hero) then
        line = p.name .. " погиб от рук своих."
        p.words = pick(DENY_WORDS)
    elseif NPC.IsNeutral(target) then
        line = p.name .. ", " .. p.age .. ", скончался в лесу."
        p.words = pick(FOREST_WORDS)
    else
        line = p.name .. ", " .. p.age .. ", погиб."
        p.words = pick(LAST_WORDS)
    end

    buried = buried + 1
    obituary = { title = line, words = p.words, t = real() }
end

function script.OnGameEnd()
    people, obituary, buried = {}, nil, 0
end

-- рисуем

local function text(size, s, x, y, col)
    Render.Text(font, size, s, Vec2(x + 1, y + 1), Color(0, 0, 0, math.floor(col.a * 0.7)))
    Render.Text(font, size, s, Vec2(x, y), col)
end

local function drawNames(hero)
    local range = ui.range:Get()
    local list = NPCs.InRadius(Entity.GetAbsOrigin(hero), range, Entity.GetTeamNum(hero), Enum.TeamType.TEAM_BOTH, true, true)
    for _, npc in pairs(list or {}) do
        if Entity.IsAlive(npc) and isCreep(npc) and NPC.IsVisible(npc) then
            local p = person(npc)
            local head = Entity.GetAbsOrigin(npc) + Vector(0, 0, (NPC.GetHealthBarOffset(npc) or 140) + 20)
            local pos, visible = Render.WorldToScreen(head)
            if visible then
                local label = p.name .. ", " .. p.age
                local w = Render.TextSize(font, 12, label).x
                local hp = Entity.GetHealth(npc) / math.max(1, Entity.GetMaxHealth(npc))
                local col = hp < 0.3 and Color(255, 90, 90, 240) or Color(235, 235, 235, 200)
                text(12, label, pos.x - w / 2, pos.y, col)
            end
        end
    end
end

local function drawObituary()
    local age = real() - obituary.t
    if age > 3.5 then obituary = nil return end
    local alpha = age < 0.2 and age / 0.2 or (age > 2.8 and (3.5 - age) / 0.7 or 1)

    local screen = Render.ScreenSize()
    local w1 = Render.TextSize(font, 24, obituary.title).x
    local w2 = Render.TextSize(font, 15, obituary.words).x
    local W = math.max(w1, w2) + 60
    local x, y = (screen.x - W) / 2, screen.y * 0.2

    Render.SetGlobalAlpha(math.max(0, math.min(1, alpha)))
    Render.FilledRect(Vec2(x, y), Vec2(x + W, y + 78), Color(10, 10, 12, 215), 8)
    Render.FilledRect(Vec2(x, y), Vec2(x + W, y + 3), Color(255, 255, 255, 120), 2)
    local cx = x + W / 2
    Render.FilledRect(Vec2(x + 18, y + 20), Vec2(x + 22, y + 46), Color(220, 220, 220, 230))
    Render.FilledRect(Vec2(x + 12, y + 27), Vec2(x + 28, y + 31), Color(220, 220, 220, 230))
    text(24, obituary.title, cx - w1 / 2, y + 12, Color(245, 245, 245, 255))
    text(15, obituary.words, cx - w2 / 2, y + 46, Color(190, 190, 190, 240))
    Render.ResetGlobalAlpha()
end

function script.OnDraw()
    if not ui.enabled or not ui.enabled:Get() then return end
    local hero = Heroes.GetLocal()
    if not hero then return end
    if not font then
        font = Render.LoadFont("MuseoSansEx", Enum.FontCreate.FONTFLAG_ANTIALIAS, 600)
            or Render.LoadFont("Tahoma", Enum.FontCreate.FONTFLAG_ANTIALIAS, 600)
    end

    if ui.names:Get() then drawNames(hero) end
    if obituary and ui.obit:Get() then drawObituary() end
    if ui.counter:Get() and buried > 0 then
        local s = "похоронено: " .. buried
        text(13, s, 20, Render.ScreenSize().y * 0.72, Color(220, 220, 220, 180))
    end
end

return script
