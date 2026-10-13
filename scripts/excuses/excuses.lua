-- отмазки. умер - на экране отмазка и кнопка, которая кидает ее в чат.
-- счетчик растет только за те отмазки, которые реально ушли в чат

---@diagnostic disable: undefined-global

local VERSION = "1.0.0"
local script = {}

local CFG = "excuses"

local GENERIC = {
    "пинг 300", "мышка залипла", "это был не я, это кот", "саппорт не пришел", "я так и хотел",
    "лаги", "монитор погас", "мама позвала кушать", "брат сел поиграть", "клава залипла",
    "солнце в глаза", "я смотрел на миникарту", "это стратегия", "у них читы", "я тестил билд",
    "надо было больше вардов", "где тп, саппорт?", "я был афк", "случайно нажал", "у меня 30 фпс",
    "интернет моргнул", "это был размен", "я верил в команду", "хотел посмотреть на серый экран",
    "я отвлекал их на себя", "меня тут вообще не должно было быть", "мне звонили",
    "курьер загородил", "это все дизбаланс", "гейб меня ненавидит", "я проверял, работает ли байбек",
    "я на ноутбуке", "играю одной рукой", "а мид где был?", "это не смерть, это отдых",
}

local BY = {
    ["#tower"]    = { "вышка вообще-то била не меня", "думал вышка на моей стороне", "у вышки читы" },
    ["#roshan"]   = { "я просто хотел погладить рошана", "рош первый начал" },
    ["#neutral"]  = { "лесные с читами", "это был очень злой кобольд" },
    ["#creep"]    = { "крипы в сговоре", "меня окружила волна" },
    ["#fountain"] = { "фонтан играет не по правилам" },
    ["#ally"]     = { "свои убили, я ни при чем" },
}

local VS_HERO = { "%s с читами", "%s контрпик, что вы хотели", "%s абьюзит", "опять этот %s", "%s в лоу приоритете учился" }

local ui = {}
local font = nil
local excuse = nil
local killer = nil
local wasAlive = true
local respawnedAt = nil
local sentThisGame, sentTotal = 0, 0
local lastSend = -99
local lastClick = -99
local buttons = {}
local matchId = nil
local okChronos, chronos = pcall(require, "chronos")

local function real()
    if okChronos and chronos and chronos.nanotime then return chronos.nanotime() end
    return os.clock()
end

local function try(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a = pcall(fn, ...)
    if ok then return a end
end

local function pick(list) return list[math.random(#list)] end

local function heroTitle(name)
    local loc = try(GameLocalizer and GameLocalizer.FindNPC, name)
    if loc and loc ~= "" then return loc end
    return (name:gsub("^npc_dota_hero_", ""):gsub("_", " "))
end

local function whoKilled(src, hero)
    if src == nil or not try(Entity.IsEntity, src) then return nil end
    local h = try(Entity.IsHero, src) and (try(Hero.GetReplicatingOtherHeroModel, src) or src) or try(NPC.GetOwnerNPC, src)
    if h and try(Entity.IsHero, h) then
        if h == hero or try(Entity.IsSameTeam, h, hero) then return "#ally" end
        return try(NPC.GetUnitName, h)
    end
    if try(NPC.IsTower, src) then return "#tower" end
    if try(NPC.IsRoshan, src) then return "#roshan" end
    if try(NPC.IsNeutral, src) then return "#neutral" end
    if try(Entity.IsSameTeam, src, hero) then return "#ally" end
    if try(NPC.IsCreep, src) then return "#creep" end
    if (try(NPC.GetUnitName, src) or ""):find("fountain") then return "#fountain" end
    return nil
end

local function newExcuse()
    local text
    if killer and ui.situational:Get() and math.random() < 0.5 then
        if BY[killer] then text = pick(BY[killer])
        elseif killer:sub(1, 1) ~= "#" then text = pick(VS_HERO):format(heroTitle(killer)) end
    end
    text = text or pick(GENERIC)
    if excuse and text == excuse.text and #GENERIC > 1 then return newExcuse() end
    excuse = { text = text, sent = false, t = real() }
end

local function send()
    if not excuse or excuse.sent or real() - lastSend < 3 then return end
    local clean = excuse.text:gsub("[\";]", "")
    local cmd = ui.channel:Get() == 1 and "say" or "say_team"
    Engine.ExecuteCommand(cmd .. ' "' .. clean .. '"')
    excuse.sent = true
    lastSend = real()
    sentThisGame = sentThisGame + 1
    sentTotal = sentTotal + 1
    Config.WriteInt(CFG, "total", sentTotal)
end

-- меню

local function buildMenu()
    local tab = Menu.Create("Scripts", "Utility", "Отмазки", "Main")
    if not tab or not tab.Create then return end
    local g = tab:Create("Основное", Enum.GroupSide.Left)

    ui.enabled = g:Switch("Включить", true, "\u{f4ad}")
    ui.channel = g:Combo("Куда писать", { "Команде", "Всем" }, 0)
    ui.channel:ToolTip("Команде - say_team, всем - say.")
    ui.situational = g:Switch("Отмазки под ситуацию", true)
    ui.situational:ToolTip("Иногда отмазка зависит от того, кто убил: вышка, рошан, крипы или конкретный герой.")
    ui.sendKey = g:Bind("Отправить отмазку", Enum.ButtonCode.KEY_NONE, "\u{f1d8}")
    ui.sendKey:ToolTip("То же самое, что кнопка под отмазкой.")
end

function script.OnScriptsLoaded()
    sentTotal = Config.ReadInt(CFG, "total", 0)
    buildMenu()
end

-- логика

function script.OnEntityKilled(data)
    if type(data) ~= "table" then return end
    local hero = Heroes.GetLocal()
    if not hero or data.target ~= hero then return end
    killer = whoKilled(data.source, hero)
end

function script.OnUpdate()
    if not ui.enabled or not ui.enabled:Get() then return end
    local hero = Heroes.GetLocal()
    if not hero then return end

    local id = try(GameRules.GetMatchID) or 0
    if matchId ~= id then
        matchId, sentThisGame, excuse, killer = id, 0, nil, nil
    end

    local alive = Entity.IsAlive(hero)
    if wasAlive and not alive then
        newExcuse()
        respawnedAt = nil
    elseif alive and not wasAlive then
        respawnedAt = real()
        killer = nil
    end
    wasAlive = alive

    if excuse and respawnedAt and real() - respawnedAt > 4 then excuse = nil end
    if excuse and ui.sendKey:IsPressed() then send() end
end

function script.OnGameEnd()
    excuse, killer, sentThisGame = nil, nil, 0
end

local function clickAt(x, y)
    for name, b in pairs(buttons) do
        if x >= b[1] and x <= b[1] + b[3] and y >= b[2] and y <= b[2] + b[4] then
            lastClick = real()
            if name == "send" then send() else newExcuse() end
            return true
        end
    end
    return false
end

function script.OnKeyEvent(data)
    if not excuse or type(data) ~= "table" or data.key ~= Enum.ButtonCode.KEY_MOUSE1 then return true end
    local x, y = Input.GetCursorPos()
    if not x then return true end
    local over = false
    for _, b in pairs(buttons) do
        if x >= b[1] and x <= b[1] + b[3] and y >= b[2] and y <= b[2] + b[4] then over = true end
    end
    if not over then return true end
    if data.event == Enum.EKeyEvent.EKeyEvent_KEY_DOWN then clickAt(x, y) end
    return false
end

-- рисуем

local function text(size, s, x, y, col)
    Render.Text(font, size, s, Vec2(x + 1, y + 1), Color(0, 0, 0, math.floor(col.a * 0.7)))
    Render.Text(font, size, s, Vec2(x, y), col)
end

local function button(name, label, x, y, w, h, col, disabled)
    buttons[name] = { x, y, w, h }
    local hovered = not disabled and Input.IsCursorInRect(x, y, w, h)
    local fill = disabled and Color(60, 60, 66, 200) or hovered and Color(col.r, col.g, col.b, 255) or col
    Render.FilledRect(Vec2(x, y), Vec2(x + w, y + h), fill, 8)
    local tw = Render.TextSize(font, 15, label).x
    text(15, label, x + (w - tw) / 2, y + (h - 17) / 2, disabled and Color(170, 170, 170, 220) or Color(255, 255, 255, 255))
end

function script.OnDraw()
    buttons = {}
    if not excuse or not ui.enabled:Get() then return end
    if not font then
        font = Render.LoadFont("MuseoSansEx", Enum.FontCreate.FONTFLAG_ANTIALIAS, 600)
            or Render.LoadFont("Tahoma", Enum.FontCreate.FONTFLAG_ANTIALIAS, 600)
    end

    local alpha = 1
    if respawnedAt then alpha = math.max(0, 1 - (real() - respawnedAt) / 4) end
    local pop = math.min(1, (real() - excuse.t) / 0.15)

    local screen = Render.ScreenSize()
    local quote = "\"" .. excuse.text .. "\""
    local qw = Render.TextSize(font, 28, quote).x
    local W = math.max(qw + 70, 440)
    local H = 158
    local x, y = (screen.x - W) / 2, screen.y * 0.26 - (1 - pop) * 20

    Render.SetGlobalAlpha(alpha * pop)
    Render.FilledRect(Vec2(x, y), Vec2(x + W, y + H), Color(14, 14, 18, 225), 12)
    Render.Rect(Vec2(x, y), Vec2(x + W, y + H), Color(255, 255, 255, 30), 12, Enum.DrawFlags.None, 1)

    local label = "ТВОЯ ОТМАЗКА"
    text(12, label, x + (W - Render.TextSize(font, 12, label).x) / 2, y + 14, Color(170, 170, 185, 220))
    text(28, quote, x + (W - qw) / 2, y + 34, Color(255, 255, 255, 255))

    local bw, bh, gap = 190, 36, 12
    local bx = x + (W - bw * 2 - gap) / 2
    local by = y + 82
    local sendLabel = excuse.sent and "Отправлено" or "Отправить в чат"
    button("send", sendLabel, bx, by, bw, bh, Color(70, 140, 255, 230), excuse.sent)
    button("reroll", "Другая", bx + bw + gap, by, bw, bh, Color(90, 90, 110, 230), false)

    local stats = "в чате за игру: " .. sentThisGame .. "   всего: " .. sentTotal
    text(12, stats, x + (W - Render.TextSize(font, 12, stats).x) / 2, y + H - 26, Color(170, 170, 185, 200))
    Render.ResetGlobalAlpha()

    if Input.IsKeyDownOnce(Enum.ButtonCode.KEY_MOUSE1, true) and real() - lastClick > 0.25 then
        local cx, cy = Input.GetCursorPos()
        if cx then clickAt(cx, cy) end
    end
end

return script
