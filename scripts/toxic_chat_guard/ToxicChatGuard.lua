local script = {}

local protobuf = require("protobuf")
local JSON = require("assets.JSON")

local cfg = {}

local state = {
    nextNotifyTime = 0,
    uiDirty = true,
    uiNextUpdateTime = 0,
    lastPlayersSyncTime = -1,
    players = {}, -- [playerId] = { player, team, name, heroShort, heroUnit }
    teamOrder = { [2] = {}, [3] = {} }, -- [team] = {playerId...}
    stats = {}, -- [playerId] = {total, hard, soft, masked, words, history, last...}
    history = {}, -- global history entries
    ui = { built = false },
    toasts = {},
    toastSeq = 0,
    renderOverlay = {
        enabled = true,
        open = false,
        dragging = false,
        dragOffX = 0,
        dragOffY = 0,
        x = nil,
        y = nil,
        w = 980,
        h = 560,
        selectedPid = nil,
        font = nil,
    },
}

local hardWords = {
    "даун", "долбоеб", "долбаеб", "дебил", "идиот", "ублюдок", "мразь", "кончен", "тварь",
    "уебище", "уебок", "мудак", "гандон", "гондон", "чмо", "шлюха", "шалава", "проститутка",
    "петух", "подонок", "урод", "убогий", "тупорыл", "тварина", "падаль", "сволочь", "тупица",
    "pidor", "pidoras", "dolbaeb", "debil", "idiot", "retard", "moron",
    "сука", "сучара", "блять", "блядь", "блядина", "ебан", "ебал", "ебуч", "ебло", "хуес", "хуй",
    "хуя", "хуе", "хуйн", "хер", "пидор", "пидорас", "пидарас", "пидр", "мразота", "уебан",
    "чурк", "чурбан", "хач", "хачик", "узкоглаз", "черножоп", "нигер", "ниггер", "негр", "макак",
    "обезьян", "джамшут", "хохол", "кацап", "жид", "жидов", "цыганва", "черномаз",
    "blyat", "suka", "eban", "ebal", "huy",
}

local softWords = {
    "туп", "слаб", "мусор", "рак", "trash", "dog", "bot", "noob", "useless",
}

local function findFirstStringByKeys(obj, keys, depth)
    if type(obj) ~= "table" or depth <= 0 then
        return nil
    end

    for i = 1, #keys do
        local v = obj[keys[i]]
        if type(v) == "string" and v ~= "" then
            return v
        end
    end

    for _, v in pairs(obj) do
        if type(v) == "table" then
            local nested = findFirstStringByKeys(v, keys, depth - 1)
            if nested then
                return nested
            end
        end
    end

    return nil
end

local function findFirstNumberByKeys(obj, keys, depth)
    if type(obj) ~= "table" or depth <= 0 then
        return nil
    end

    for i = 1, #keys do
        local v = obj[keys[i]]
        if type(v) == "number" and v >= 0 then
            return v
        end
    end

    for _, v in pairs(obj) do
        if type(v) == "table" then
            local nested = findFirstNumberByKeys(v, keys, depth - 1)
            if nested ~= nil then
                return nested
            end
        end
    end

    return nil
end

local function normalizeText(text)
    local s = string.lower(tostring(text or ""))
    s = s:gsub("ё", "е")
    s = s:gsub("3", "з")
    s = s:gsub("4", "ч")
    s = s:gsub("0", "о")
    s = s:gsub("1", "i")
    s = s:gsub("@", "а")
    s = s:gsub("%$","с")
    s = s:gsub("[^%w%sа-я_]", " ")
    s = s:gsub("%s+", " ")
    return s
end

local function containsAny(text, list)
    for i = 1, #list do
        if text:find(list[i], 1, true) then
            return true, list[i]
        end
    end
    return false, nil
end

local function scoreToxicity(rawText)
    local raw = tostring(rawText or "")
    if raw:find("%*%*%*+") or raw:find("•••+") then
        return 2, "***"
    end

    local rawLower = string.lower(raw)
    local hardRaw, hardRawHit = containsAny(rawLower, hardWords)
    if hardRaw then
        return 3, hardRawHit
    end

    local softRaw, softRawHit = containsAny(rawLower, softWords)
    if softRaw then
        return 1, softRawHit
    end

    local txt = normalizeText(rawText)
    if txt == "" then
        return 0, nil
    end

    local hard, hardHit = containsAny(txt, hardWords)
    if hard then
        return 3, hardHit
    end

    local soft, softHit = containsAny(txt, softWords)
    if soft then
        return 1, softHit
    end

    return 0, nil
end

local function getPlayerIdFromDecodedMessage(obj)
    return findFirstNumberByKeys(obj, {
        "player_id",
        "playerid",
        "playerid_1",
        "player_id_1",
        "playerid_2",
        "player_id_2",
        "value",
        "source_player_id",
    }, 4)
end

local function getHeroNameByPlayerId(playerId)
    if type(playerId) ~= "number" or playerId < 0 then
        return nil, nil
    end

    local heroes = Heroes and Heroes.GetAll and Heroes.GetAll() or nil
    if not heroes then
        return nil, nil
    end

    for i = 1, #heroes do
        local hero = heroes[i]
        if hero and Hero and Hero.GetPlayerID and Hero.GetPlayerID(hero) == playerId then
            local unitName = NPC and NPC.GetUnitName and NPC.GetUnitName(hero) or nil
            if type(unitName) ~= "string" or unitName == "" then
                return nil, nil
            end

            local short = unitName:gsub("^npc_dota_hero_", "")
            short = short:gsub("^npc_dota_", "")
            return short, unitName
        end
    end

    return nil, nil
end

local function getGameTime()
    if GameRules and GameRules.GetGameTime then
        return GameRules.GetGameTime()
    end
    return os.clock()
end

local function formatGameTime(t)
    if type(t) ~= "number" or t < 0 then
        return "--:--"
    end
    local m = math.floor(t / 60)
    local s = math.floor(t % 60)
    return string.format("%02d:%02d", m, s)
end

local function truncateText(s, maxLen)
    local str = tostring(s or "")
    if maxLen and #str > maxLen then
        return str:sub(1, maxLen - 1) .. "…"
    end
    return str
end

local function clamp(x, minV, maxV)
    if x < minV then return minV end
    if x > maxV then return maxV end
    return x
end

local function getWidgetValue(widget, default)
    if widget and widget.Get then
        local ok, v = pcall(widget.Get, widget)
        if ok and v ~= nil then
            return v
        end
    end
    return default
end

local function getPlayerDisplayName(player)
    if Player and Player.GetName then
        local nick, proname = Player.GetName(player)
        if type(nick) == "string" and nick ~= "" then
            if type(proname) == "string" and proname ~= "" and proname ~= nick then
                return nick .. " (" .. proname .. ")"
            end
            return nick
        end
    end
    return "Unknown"
end

local function heroIconPath(heroUnitName)
    if type(heroUnitName) ~= "string" or heroUnitName == "" then
        return nil
    end
    return "panorama/images/heroes/icons/" .. heroUnitName .. "_png.vtex_c"
end

local function titleCaseWords(s)
    local str = tostring(s or "")
    str = str:gsub("_", " ")
    str = str:gsub("^%s+", ""):gsub("%s+$", "")
    str = str:gsub("%s+", " ")
    str = str:gsub("(%a)([%w']*)", function(a, b)
        return string.upper(a) .. string.lower(b)
    end)
    return str
end

local function getHeroDisplayName(heroUnitName, heroShort)
    if type(heroUnitName) == "string" and heroUnitName ~= "" then
        if GameLocalizer and GameLocalizer.FindNPC then
            local ok, v = pcall(GameLocalizer.FindNPC, heroUnitName)
            if ok and type(v) == "string" and v ~= "" then
                return v
            end
        end
        if Engine and Engine.GetDisplayNameByUnitName then
            local ok, v = pcall(Engine.GetDisplayNameByUnitName, heroUnitName)
            if ok and type(v) == "string" and v ~= "" then
                return v
            end
        end
    end

    local short = heroShort
    if type(short) ~= "string" or short == "" then
        short = tostring(heroUnitName or "?")
        short = short:gsub("^npc_dota_hero_", "")
        short = short:gsub("^npc_dota_", "")
    end
    return titleCaseWords(short)
end

local function ensurePlayerStat(playerId)
    if type(playerId) ~= "number" or playerId < 0 then
        return nil
    end
    local st = state.stats[playerId]
    if not st then
        st = {
            total = 0,
            hard = 0,
            soft = 0,
            masked = 0,
            words = {},
            history = {},
            lastTime = nil,
            lastScore = nil,
            lastHit = nil,
            lastText = nil,
        }
        state.stats[playerId] = st
    end
    return st
end

local function pushBounded(list, item, maxSize)
    list[#list + 1] = item
    local maxN = tonumber(maxSize) or 0
    if maxN > 0 then
        while #list > maxN do
            table.remove(list, 1)
        end
    end
end

local function clearAllStats()
    state.stats = {}
    state.history = {}
    state.uiDirty = true
end

local function clearPlayerStats(playerId)
    if type(playerId) ~= "number" then
        return
    end
    state.stats[playerId] = nil
    state.uiDirty = true
end

local function syncPlayers(force)
    local now = getGameTime()
    local last = state.lastPlayersSyncTime or -1
    if not force and now - last < 2.0 then
        return
    end
    state.lastPlayersSyncTime = now

    if Engine and Engine.IsInGame and not Engine.IsInGame() then
        state.players = {}
        state.teamOrder[2] = {}
        state.teamOrder[3] = {}
        state.uiDirty = true
        return
    end

    if not (Players and Players.Count and Players.Get and Player and Player.GetPlayerID) then
        return
    end

    local playersMap = {}
    local rad = {}
    local dire = {}

    local count = Players.Count() or -1
    for i = 0, count do
        local p = Players.Get(i)
        if p then
            local pid = Player.GetPlayerID(p)
            if type(pid) == "number" and pid >= 0 then
                local team = Entity and Entity.GetTeamNum and Entity.GetTeamNum(p) or nil
                local heroShort, heroUnit = getHeroNameByPlayerId(pid)
                local heroDisplay = getHeroDisplayName(heroUnit, heroShort)
                playersMap[pid] = {
                    player = p,
                    team = team,
                    name = getPlayerDisplayName(p),
                    heroShort = heroShort,
                    heroUnit = heroUnit,
                    heroDisplay = heroDisplay,
                }
                if team == 2 then
                    rad[#rad + 1] = pid
                elseif team == 3 then
                    dire[#dire + 1] = pid
                end
            end
        end
    end

    table.sort(rad)
    table.sort(dire)

    state.players = playersMap
    state.teamOrder[2] = rad
    state.teamOrder[3] = dire
    state.uiDirty = true
end

local function recordDetection(playerId, score, hit, text)
    local st = ensurePlayerStat(playerId)
    if not st then
        return
    end

    local now = getGameTime()
    local pinfo = state.players[playerId] or {}
    local heroShort = pinfo.heroShort or (select(1, getHeroNameByPlayerId(playerId)))
    local heroUnit = pinfo.heroUnit or (select(2, getHeroNameByPlayerId(playerId)))
    local heroDisplay = pinfo.heroDisplay or getHeroDisplayName(heroUnit, heroShort)

    st.total = (st.total or 0) + 1
    if score == 3 then
        st.hard = (st.hard or 0) + 1
    elseif score == 2 then
        st.masked = (st.masked or 0) + 1
    elseif score == 1 then
        st.soft = (st.soft or 0) + 1
    end

    if type(hit) == "string" and hit ~= "" then
        st.words[hit] = (st.words[hit] or 0) + 1
    end

    st.lastTime = now
    st.lastScore = score
    st.lastHit = hit
    st.lastText = text

    local evt = {
        time = now,
        playerId = playerId,
        hero = heroDisplay,
        score = score,
        hit = hit,
        text = text,
    }

    pushBounded(state.history, evt, getWidgetValue(cfg.maxGlobalLog, 60))
    pushBounded(st.history, evt, getWidgetValue(cfg.maxPerPlayerLog, 15))

    state.uiDirty = true
end

local function ensureRenderOverlay()
    local o = state.renderOverlay
    if not o then return false end

    if not (Render and Render.ScreenSize and Render.LoadFont and Render.Text and Render.FilledRect) then
        return false
    end

    local ss = Render.ScreenSize()
    if not ss or type(ss.x) ~= "number" or type(ss.y) ~= "number" or ss.x <= 0 or ss.y <= 0 then
        return false
    end

    local function tryLoadFont(name, flags, weight)
        local ok, f = pcall(Render.LoadFont, name, flags, weight)
        if ok and type(f) == "number" then
            return f
        end
        return nil
    end

    if not (o.fontTitle and o.fontBody and o.fontSmall) then
        local flags = 0
        local fc = Enum and Enum.FontCreate or nil
        if fc then
            local aa = fc.FONTFLAG_ANTIALIAS or 0
            local ds = fc.FONTFLAG_DROPSHADOW or 0
            flags = aa | ds
        end

        o.fontTitle = o.fontTitle or tryLoadFont("MuseoSansEx", flags, 600) or tryLoadFont("Arial", flags, 600)
        o.fontBody = o.fontBody or tryLoadFont("MuseoSansEx", flags, 500) or tryLoadFont("Arial", flags, 500)
        o.fontSmall = o.fontSmall or tryLoadFont("MuseoSansEx", flags, 450) or tryLoadFont("Arial", flags, 450)
    end

    if o.x == nil or o.y == nil then
        o.x = math.floor((ss.x - o.w) * 0.5)
        o.y = math.floor((ss.y - o.h) * 0.5)
    end

    return true
end

local function getCursorPos()
    if Input and Input.GetCursorPos then
        local ok, x, y = pcall(Input.GetCursorPos)
        if ok and type(x) == "number" and type(y) == "number" then
            return x, y
        end
    end
    return nil, nil
end

local function cursorInRect(x, y, w, h)
    if Input and Input.IsCursorInRect then
        local ok, inside = pcall(Input.IsCursorInRect, x, y, w, h)
        if ok then
            return inside and true or false
        end
    end
    local mx, my = getCursorPos()
    if mx == nil then return false end
    return (mx >= x and mx <= x + w and my >= y and my <= y + h)
end

local function mouseKey()
    local bc = Enum and Enum.ButtonCode or nil
    return bc and bc.KEY_MOUSE1 or nil
end

local function mouseDownOnce()
    local key = mouseKey()
    if not key then return false end
    if not (Input and Input.IsKeyDownOnce) then return false end
    local ok, v = pcall(Input.IsKeyDownOnce, key)
    return ok and v and true or false
end

local function mouseDown()
    local key = mouseKey()
    if not key then return false end
    if not (Input and Input.IsKeyDown) then return false end
    local ok, v = pcall(Input.IsKeyDown, key)
    return ok and v and true or false
end

local function toggleOverlay()
    state.renderOverlay.open = not state.renderOverlay.open
    state.renderOverlay.dragging = false
end

local function closeOverlay()
    state.renderOverlay.open = false
    state.renderOverlay.dragging = false
end

local function drawOverlay()
    local o = state.renderOverlay
    if not (o and o.enabled) then return end
    if not ensureRenderOverlay() then return end
    if Engine and Engine.IsInGame and (not Engine.IsInGame()) then
        closeOverlay()
        return
    end
    if Input and Input.IsInputCaptured and Input.IsInputCaptured() then
        -- don't eat clicks while chat/console/shop is open
    end

    local ss = Render.ScreenSize()
    local iconX, iconY, iconW, iconH = 18, 64, 34, 34
    local fontTitle = o.fontTitle or o.fontBody or o.fontSmall
    local fontBody = o.fontBody or o.fontSmall or o.fontTitle
    local fontSmall = o.fontSmall or o.fontBody or o.fontTitle

    -- icon
    if Render.Shadow then
        Render.Shadow(Vec2(iconX, iconY), Vec2(iconX + iconW, iconY + iconH), Color(0, 0, 0, 180), 14, 8)
    end
    if Render.Gradient then
        Render.Gradient(
            Vec2(iconX, iconY),
            Vec2(iconX + iconW, iconY + iconH),
            Color(45, 107, 255, 230),
            Color(30, 80, 220, 230),
            Color(11, 27, 61, 230),
            Color(11, 27, 61, 230),
            8
        )
    else
        Render.FilledRect(Vec2(iconX, iconY), Vec2(iconX + iconW, iconY + iconH), Color(45, 107, 255, 230), 8)
    end
    if Render.Rect then
        Render.Rect(Vec2(iconX, iconY), Vec2(iconX + iconW, iconY + iconH), Color(255, 255, 255, 30), 8)
    end
    if fontBody and Render.Text then
        local label = "TG"
        local tx, ty = iconX + 9, iconY + 7
        if Render.TextSize then
            local ts = Render.TextSize(fontBody, 16, label)
            if ts and ts.x and ts.y then
                tx = iconX + (iconW - ts.x) * 0.5
                ty = iconY + (iconH - ts.y) * 0.5 - 1
            end
        end
        Render.Text(fontBody, 16, label, Vec2(math.floor(tx + 0.5), math.floor(ty + 0.5)), Color(255, 255, 255, 255))
    end

    -- toggle by click
    if (not (Input and Input.IsInputCaptured and Input.IsInputCaptured()))
        and mouseDownOnce()
        and cursorInRect(iconX, iconY, iconW, iconH) then
        toggleOverlay()
    end

    if not o.open then
        return
    end

    -- backdrop
    if Render.Blur then
        Render.Blur(Vec2(0, 0), Vec2(ss.x, ss.y), 1.0, 0.85)
    end
    Render.FilledRect(Vec2(0, 0), Vec2(ss.x, ss.y), Color(0, 0, 0, 120))

    local x, y, w, h = o.x, o.y, o.w, o.h
    local headerH = 44
    local pad = 12

    -- drag header
    local mx, my = getCursorPos()
    if not (Input and Input.IsInputCaptured and Input.IsInputCaptured()) then
        if not o.dragging and mouseDown() and cursorInRect(x, y, w, headerH) then
            o.dragging = true
            o.dragOffX = (mx or x) - x
            o.dragOffY = (my or y) - y
        end
        if o.dragging then
            if mouseDown() and mx ~= nil and my ~= nil then
                o.x = clamp(mx - o.dragOffX, 0, math.max(0, ss.x - w))
                o.y = clamp(my - o.dragOffY, 0, math.max(0, ss.y - h))
                x, y = o.x, o.y
            else
                o.dragging = false
            end
        end
    end

    -- window shadow + body
    if Render.Shadow then
        Render.Shadow(Vec2(x, y), Vec2(x + w, y + h), Color(0, 0, 0, 220), 24, 12)
    end
    Render.FilledRect(Vec2(x, y), Vec2(x + w, y + h), Color(11, 13, 17, 245), 12)
    if Render.Rect then
        Render.Rect(Vec2(x, y), Vec2(x + w, y + h), Color(255, 255, 255, 28), 12)
    end

    -- header
    if Render.Gradient then
        Render.Gradient(
            Vec2(x, y),
            Vec2(x + w, y + headerH),
            Color(28, 37, 64, 255),
            Color(18, 24, 40, 255),
            Color(11, 13, 17, 255),
            Color(11, 13, 17, 255),
            12
        )
    else
        Render.FilledRect(Vec2(x, y), Vec2(x + w, y + headerH), Color(28, 37, 64, 255), 12)
    end
    if Render.Line then
        Render.Line(Vec2(x, y + headerH), Vec2(x + w, y + headerH), Color(255, 255, 255, 18), 1.0)
    end

    -- close button
    local closeW, closeH = 34, 30
    local closeX, closeY = x + w - closeW - 10, y + 7
    Render.FilledRect(Vec2(closeX, closeY), Vec2(closeX + closeW, closeY + closeH), Color(255, 255, 255, 20), 8)
    if Render.Rect then
        Render.Rect(Vec2(closeX, closeY), Vec2(closeX + closeW, closeY + closeH), Color(255, 255, 255, 30), 8)
    end
    if fontTitle then
        Render.Text(fontTitle, 18, "×", Vec2(closeX + 12, closeY + 4), Color(255, 255, 255, 220))
    end
    if (not (Input and Input.IsInputCaptured and Input.IsInputCaptured()))
        and mouseDownOnce()
        and cursorInRect(closeX, closeY, closeW, closeH) then
        closeOverlay()
        return
    end

    -- header title
    if fontTitle and fontBody and fontSmall then
        local totalEvents = #state.history
        Render.Text(fontTitle, 20, "Токсичность чата", Vec2(x + 14, y + 10), Color(255, 255, 255, 255))
        Render.Text(fontBody, 16, "Срабатываний: " .. tostring(totalEvents), Vec2(x + 248, y + 13), Color(170, 185, 255, 230))
        Render.Text(fontSmall, 14, "Ж — жёсткие, М — мягкие, З — замазанные", Vec2(x + 470, y + 15), Color(255, 255, 255, 140))
    end

    -- table area
    local tableY = y + headerH + pad
    local tableH = h - headerH - pad - 130
    local colGap = 10
    local colW = math.floor((w - pad * 2 - colGap) * 0.5)
    local colH = tableH
    local radX = x + pad
    local direX = radX + colW + colGap

    local function drawTeam(team, title, accent, colX)
        Render.FilledRect(Vec2(colX, tableY), Vec2(colX + colW, tableY + colH), Color(255, 255, 255, 10), 10)
        if Render.Rect then
            Render.Rect(Vec2(colX, tableY), Vec2(colX + colW, tableY + colH), Color(255, 255, 255, 16), 10)
        end
        if fontTitle then
            Render.Text(fontTitle, 18, title, Vec2(colX + 10, tableY + 8), accent)
        end
        if Render.Line then
            Render.Line(Vec2(colX + 10, tableY + 30), Vec2(colX + colW - 10, tableY + 30), Color(255, 255, 255, 14), 1.0)
        end

        local rowY = tableY + 38
        local rowH = 36
        local order = state.teamOrder[team] or {}

        local leftX = colX + 12
        local rightX = colX + colW - 12
        local lastW = 172
        local statsW = 162
        local lastX = rightX - lastW
        local statsX = lastX - statsW - 10
        local nameX = leftX
        local nameClipEndX = statsX - 6

        for i = 1, 5 do
            local pid = order[i]
            local ry = rowY + (i - 1) * rowH
            local hovered = (not (Input and Input.IsInputCaptured and Input.IsInputCaptured())) and cursorInRect(colX + 6, ry, colW - 12, rowH - 2)
            local selected = (pid ~= nil and pid == o.selectedPid)

            local bgA = selected and 40 or (hovered and 26 or 0)
            if bgA > 0 then
                Render.FilledRect(Vec2(colX + 6, ry), Vec2(colX + colW - 6, ry + rowH - 2), Color(255, 255, 255, bgA), 8)
            end

            if pid and hovered and mouseDownOnce() and (not (Input and Input.IsInputCaptured and Input.IsInputCaptured())) then
                o.selectedPid = pid
            end

            if fontBody and fontSmall then
                if pid then
                    local info = state.players[pid] or {}
                    local st = state.stats[pid] or { hard = 0, soft = 0, masked = 0 }
                    local heroName = info.heroDisplay or info.heroShort or "?"

                    if Render.PushClip then
                        Render.PushClip(Vec2(nameX, ry), Vec2(nameClipEndX, ry + rowH))
                    end
                    Render.Text(fontBody, 16, truncateText(heroName, 28), Vec2(nameX, ry + 8), Color(255, 255, 255, 245))
                    if Render.PopClip then
                        Render.PopClip()
                    end

                    local hard = "Ж:" .. tostring(st.hard or 0)
                    local soft = "М:" .. tostring(st.soft or 0)
                    local mask = "З:" .. tostring(st.masked or 0)

                    local sx = statsX
                    Render.Text(fontBody, 16, hard, Vec2(sx, ry + 8), Color(255, 102, 102, 240))
                    if Render.TextSize then
                        local ts = Render.TextSize(fontBody, 16, hard)
                        if ts and ts.x then sx = sx + math.floor(ts.x + 0.5) + 10 else sx = sx + 52 end
                    else
                        sx = sx + 52
                    end
                    Render.Text(fontBody, 16, soft, Vec2(sx, ry + 8), Color(255, 211, 107, 240))
                    if Render.TextSize then
                        local ts = Render.TextSize(fontBody, 16, soft)
                        if ts and ts.x then sx = sx + math.floor(ts.x + 0.5) + 10 else sx = sx + 52 end
                    else
                        sx = sx + 52
                    end
                    Render.Text(fontBody, 16, mask, Vec2(sx, ry + 8), Color(181, 139, 255, 240))

                    local lastWord = st.lastHit or "-"
                    local lastTime = formatGameTime(st.lastTime)
                    local lastText = lastTime .. "  " .. truncateText(lastWord, 14)
                    if Render.PushClip then
                        Render.PushClip(Vec2(lastX, ry), Vec2(rightX, ry + rowH))
                    end
                    Render.Text(fontSmall, 14, lastText, Vec2(lastX, ry + 10), Color(201, 209, 255, 220))
                    if Render.PopClip then
                        Render.PopClip()
                    end
                else
                    Render.Text(fontBody, 16, "—", Vec2(nameX, ry + 8), Color(255, 255, 255, 120))
                end
            end
        end
    end

    drawTeam(2, "СВЕТ", Color(139, 255, 216, 255), radX)
    drawTeam(3, "ТЬМА", Color(255, 139, 139, 255), direX)

    -- bottom: global history + selected details
    local bottomY = y + h - 120
    Render.FilledRect(Vec2(x + pad, bottomY), Vec2(x + w - pad, y + h - pad), Color(0, 0, 0, 40), 10)
    if Render.Line then
        Render.Line(Vec2(x + pad, bottomY), Vec2(x + w - pad, bottomY), Color(255, 255, 255, 14), 1.0)
    end

    if fontBody then
        Render.Text(fontBody, 16, "Последние срабатывания:", Vec2(x + pad + 10, bottomY + 8), Color(255, 255, 255, 200))
    end

    local hist = state.history
    local total = #hist
    for i = 1, 6 do
        local evt = hist[total - 6 + i]
        local ly = bottomY + 26 + (i - 1) * 14
        if fontSmall then
            if evt then
                local t = formatGameTime(evt.time)
                local hero = evt.hero or "?"
                local wHit = evt.hit or "-"
                local msg = truncateText(evt.text, 70)
                Render.Text(fontSmall, 14, string.format("[%s] %s: %s — %s", t, hero, wHit, msg), Vec2(x + pad + 10, ly), Color(205, 215, 255, 220))
            else
                Render.Text(fontSmall, 14, "—", Vec2(x + pad + 10, ly), Color(255, 255, 255, 120))
            end
        end
    end

    -- right-bottom details
    if o.selectedPid and fontBody and fontSmall then
        local info = state.players[o.selectedPid] or {}
        local st = state.stats[o.selectedPid] or { words = {}, history = {} }
        local hero = info.heroDisplay or info.heroShort or "?"
        local detailsX = x + math.floor(w * 0.62 + 0.5)
        Render.Text(fontBody, 16, "Детали: " .. truncateText(hero, 30), Vec2(detailsX, bottomY + 8), Color(255, 255, 255, 200))
        local top = buildTopWords(st.words or {}, 5)
        for i = 1, #top do
            Render.Text(fontSmall, 14, "- " .. top[i].w .. " ×" .. tostring(top[i].c), Vec2(detailsX, bottomY + 26 + (i - 1) * 14), Color(255, 255, 255, 180))
        end
    end
end

local function buildTopWords(wordsMap, maxItems)
    local arr = {}
    for w, c in pairs(wordsMap or {}) do
        if type(w) == "string" and w ~= "" and type(c) == "number" then
            arr[#arr + 1] = { w = w, c = c }
        end
    end
    table.sort(arr, function(a, b)
        if a.c == b.c then
            return a.w < b.w
        end
        return a.c > b.c
    end)
    local out = {}
    local n = math.min(tonumber(maxItems) or 0, #arr)
    for i = 1, n do
        out[#out + 1] = arr[i]
    end
    return out
end

local function updateUi(force)
    if not state.ui or not state.ui.built then
        return
    end

    local now = getGameTime()
    local nextT = state.uiNextUpdateTime or 0
    if not force then
        if not state.uiDirty and now < nextT then
            return
        end
        if now < nextT then
            return
        end
    end
    state.uiNextUpdateTime = now + 0.25
    state.uiDirty = false

    local inGame = (Engine and Engine.IsInGame and Engine.IsInGame()) or nil
    if state.ui.statusLabel and state.ui.statusLabel.ForceLocalization then
        local totalEvents = #state.history
        local status = "Статус: " .. (inGame and "в игре" or "не в игре") .. " | событий: " .. tostring(totalEvents)
        state.ui.statusLabel:ForceLocalization(status)
    end

    local function updateSlot(slot, playerId)
        slot.playerId = playerId
        if not playerId then
            slot.label:ForceLocalization("—")
            slot.label:ToolTip("Нет данных")
            slot.label:Unsafe(false)
            slot.label:Disabled(true)
            return
        end

        slot.label:Disabled(false)
        local info = state.players[playerId] or {}
        local st = state.stats[playerId] or { total = 0, hard = 0, soft = 0, masked = 0, words = {}, history = {} }
        local hero = info.heroShort or "?"
        local name = info.name or ("Player " .. tostring(playerId))
        local lastWord = st.lastHit or "-"
        local lastTime = formatGameTime(st.lastTime)

        local row = string.format("%s (%s) | H:%d S:%d M:%d | %s %s", name, hero, st.hard or 0, st.soft or 0, st.masked or 0, lastTime, lastWord)
        slot.label:ForceLocalization(truncateText(row, 120))

        local icon = heroIconPath(info.heroUnit)
        if icon and slot.label.Image then
            pcall(slot.label.Image, slot.label, icon)
        end

        slot.label:Unsafe((st.hard or 0) > 0 or (st.masked or 0) > 0)

        local top = buildTopWords(st.words or {}, 8)
        local topLines = {}
        for i = 1, #top do
            topLines[#topLines + 1] = "- " .. top[i].w .. " x" .. tostring(top[i].c)
        end

        local tip = {
            name .. " (" .. hero .. ")",
            "Всего: " .. tostring(st.total or 0) .. " | Hard: " .. tostring(st.hard or 0) .. " | Soft: " .. tostring(st.soft or 0) .. " | Mask: " .. tostring(st.masked or 0),
        }
        if #topLines > 0 then
            tip[#tip + 1] = ""
            tip[#tip + 1] = "Топ слова:"
            for i = 1, #topLines do
                tip[#tip + 1] = topLines[i]
            end
        end
        if type(st.lastText) == "string" and st.lastText ~= "" then
            tip[#tip + 1] = ""
            tip[#tip + 1] = "Последнее:"
            tip[#tip + 1] = truncateText(st.lastText, 200)
        end
        slot.label:ToolTip(table.concat(tip, "\n"))

        if slot.details then
            slot.details.stats:ForceLocalization(string.format("Всего: %d | H:%d S:%d M:%d", st.total or 0, st.hard or 0, st.soft or 0, st.masked or 0))

            local words = buildTopWords(st.words or {}, #slot.details.words)
            for i = 1, #slot.details.words do
                local w = words[i]
                if w then
                    slot.details.words[i]:ForceLocalization(w.w .. " x" .. tostring(w.c))
                else
                    slot.details.words[i]:ForceLocalization("—")
                end
            end

            local hist = st.history or {}
            local showN = #slot.details.events
            for i = 1, showN do
                local evt = hist[#hist - showN + i]
                if evt then
                    local t = formatGameTime(evt.time)
                    local w = evt.hit or "-"
                    local msg = truncateText(evt.text, 140)
                    slot.details.events[i]:ForceLocalization(string.format("[%s] %s: %s", t, w, msg))
                else
                    slot.details.events[i]:ForceLocalization("—")
                end
            end
        end
    end

    for team, slots in pairs(state.ui.teamSlots or {}) do
        local order = state.teamOrder[team] or {}
        for i = 1, #slots do
            updateSlot(slots[i], order[i])
        end
    end

    if state.ui.logLines then
        local hist = state.history
        local total = #hist
        for i = 1, #state.ui.logLines do
            local lbl = state.ui.logLines[i]
            local evt = hist[total - #state.ui.logLines + i]
            if evt then
                local hero = evt.hero or "?"
                local t = formatGameTime(evt.time)
                local w = evt.hit or "-"
                local msg = truncateText(evt.text, 140)
                lbl:ForceLocalization(string.format("[%s] %s: %s", t, hero, w))
                lbl:ToolTip(msg)
                lbl:Unsafe((evt.score or 0) >= 3)
                lbl:Disabled(false)
            else
                lbl:ForceLocalization("—")
                lbl:ToolTip("")
                lbl:Unsafe(false)
                lbl:Disabled(true)
            end
        end
    end
end

local function toastAccentColor(score)
    if score == 3 then
        return { r = 255, g = 102, b = 102 } -- hard
    end
    if score == 2 then
        return { r = 181, g = 139, b = 255 } -- masked
    end
    return { r = 255, g = 211, b = 107 } -- soft
end

local function toastAdd(title, subtitle, score, duration)
    if type(title) ~= "string" or title == "" then
        return
    end
    state.toastSeq = (state.toastSeq or 0) + 1
    local t = {
        id = state.toastSeq,
        t0 = getGameTime(),
        duration = tonumber(duration) or 3.5,
        title = title,
        subtitle = tostring(subtitle or ""),
        score = tonumber(score) or 0,
        accent = toastAccentColor(score),
    }
    state.toasts[#state.toasts + 1] = t
    while #state.toasts > 4 do
        table.remove(state.toasts, 1)
    end
end

local function toastAlpha(life, dur)
    if dur <= 0 then return 0 end
    local inT = math.max(0.12, math.min(0.18, dur * 0.18))
    local outT = math.max(0.18, math.min(0.28, dur * 0.22))
    if life < 0 then return 0 end
    if life < inT then
        return life / inT
    end
    if life > dur - outT then
        return math.max(0, (dur - life) / outT)
    end
    return 1
end

local function drawToasts()
    if not (Render and Render.ScreenSize and Render.Text and Render.FilledRect) then
        return
    end
    if not state.toasts or #state.toasts == 0 then
        return
    end

    -- Ensure fonts are available (reuse overlay font loader).
    ensureRenderOverlay()
    local o = state.renderOverlay or {}
    local fontTitle = o.fontBody or o.fontTitle or o.fontSmall
    local fontBody = o.fontSmall or o.fontBody or o.fontTitle
    if not fontTitle or not fontBody then
        return
    end

    local now = getGameTime()
    local ss = Render.ScreenSize()
    local sw, sh = ss.x or 0, ss.y or 0

    local w = 420
    local h = 64
    local gap = 10
    local margin = 16
    local top = 92

    -- remove expired
    for i = #state.toasts, 1, -1 do
        local t = state.toasts[i]
        local dur = tonumber(t.duration) or 3.5
        if (now - (t.t0 or now)) >= dur then
            table.remove(state.toasts, i)
        end
    end
    if #state.toasts == 0 then
        return
    end

    local startX = math.max(margin, sw - margin - w)

    -- newest on top
    local idx = 0
    for i = #state.toasts, 1, -1 do
        local t = state.toasts[i]
        local dur = tonumber(t.duration) or 3.5
        local life = now - (t.t0 or now)
        local a = toastAlpha(life, dur)
        if a > 0 then
            local a255 = math.floor(255 * a + 0.5)
            local slide = math.floor((1 - a) * 42 + 0.5)
            local x = startX + slide
            local y = top + idx * (h + gap)
            idx = idx + 1

            -- background (small blur looks like "push")
            if Render.Blur then
                Render.Blur(Vec2(x, y), Vec2(x + w, y + h), 1.0, 0.85 * a, 12)
            end
            if Render.Shadow then
                Render.Shadow(Vec2(x, y), Vec2(x + w, y + h), Color(0, 0, 0, math.floor(170 * a + 0.5)), 16, 12)
            end
            Render.FilledRect(Vec2(x, y), Vec2(x + w, y + h), Color(14, 16, 22, math.floor(220 * a + 0.5)), 12)
            if Render.Rect then
                Render.Rect(Vec2(x, y), Vec2(x + w, y + h), Color(255, 255, 255, math.floor(26 * a + 0.5)), 12)
            end

            -- accent bar
            local ac = t.accent or { r = 255, g = 211, b = 107 }
            Render.FilledRect(Vec2(x, y), Vec2(x + 5, y + h), Color(ac.r, ac.g, ac.b, math.floor(255 * a + 0.5)), 12)

            -- content
            local tx = x + 14
            local clipL = tx
            local clipR = x + w - 12
            if Render.PushClip then
                Render.PushClip(Vec2(clipL, y), Vec2(clipR, y + h))
            end
            Render.Text(fontTitle, 16, t.title or "", Vec2(math.floor(tx + 0.5), math.floor(y + 10 + 0.5)), Color(255, 255, 255, a255))
            local sub = t.subtitle or ""
            if sub ~= "" then
                Render.Text(fontBody, 14, truncateText(sub, 90), Vec2(math.floor(tx + 0.5), math.floor(y + 34 + 0.5)), Color(205, 215, 255, math.floor(220 * a + 0.5)))
            end
            if Render.PopClip then
                Render.PopClip()
            end

            if idx >= 4 then
                break
            end
        end
    end
end

local function notifyToxic(playerId, score, text, word)
    local now = getGameTime()
    if now < state.nextNotifyTime then
        return
    end

    local duration = 4.0
    if cfg.notifyDuration and cfg.notifyDuration.Get then
        duration = (cfg.notifyDuration:Get() or 25) * 0.1
    end
    state.nextNotifyTime = now + math.max(1.0, duration)

    local info = (type(playerId) == "number") and (state.players[playerId] or {}) or {}
    local heroDisplay = info.heroDisplay or info.heroShort or "Неизвестно"

    local title = heroDisplay .. " — токсичность"
    local sub = ""
    if type(word) == "string" and word ~= "" then
        sub = "Слово: " .. word
    end
    if type(text) == "string" and text ~= "" then
        if sub ~= "" then
            sub = sub .. " | " .. truncateText(text, 70)
        else
            sub = truncateText(text, 70)
        end
    end

    local useToast = getWidgetValue(cfg.toastEnabled, true)
    if useToast then
        toastAdd(title, sub, score, duration)
    elseif Render and Render.CenteredNotification then
        Render.CenteredNotification(title, duration)
    end
    if cfg.soundEnabled and cfg.soundEnabled.Get and cfg.soundEnabled:Get() then
        local vol = 0.25
        if cfg.soundVolume and cfg.soundVolume.Get then
            vol = (cfg.soundVolume:Get() or 25) * 0.01
        end
        if Engine and Engine.PlayVol then
            Engine.PlayVol("sounds/npc/courier/courier_acknowledge.vsnd_c", vol)
        end
    end
end

local function extractMessageTextFromObject(msgObject)
    if not (protobuf and protobuf.decodeToJSONfromObject and JSON and JSON.decode) then
        return nil
    end

    local okDecode, jsonRaw = pcall(protobuf.decodeToJSONfromObject, msgObject)
    if not okDecode or not jsonRaw then
        return nil
    end

    local okParse, obj = pcall(JSON.decode, JSON, jsonRaw)
    if not okParse or type(obj) ~= "table" then
        return nil
    end

    local text = findFirstStringByKeys(obj, {
        "message_text",
        "text",
        "message",
        "chat_text",
        "raw_text",
    }, 5)

    local playerId = getPlayerIdFromDecodedMessage(obj)
    if type(text) ~= "string" or text == "" then
        return nil, playerId, jsonRaw, obj
    end

    return text, playerId, jsonRaw, obj
end

local function initMenu()
    local root = Menu and Menu.Create and Menu.Create("Scripts", "Utility") or nil
    if not root then
        return
    end

    local tab = root:Create("Toxic Chat Guard")
    if not tab or not tab.Create then
        return
    end

    local main = tab:Create("Основное")
    if not main or not main.Create then
        return
    end

    local group = main:Create("Настройки")
    if not group then
        return
    end

    local function makeSliderInt(container, name, min, max, default, fmt)
        if container and container.SliderInt then
            return container:SliderInt(name, min, max, default)
        end
        if container and container.Slider then
            return container:Slider(name, min, max, default, fmt)
        end
        if container and container.SliderFloat then
            return container:SliderFloat(name, min, max, default)
        end
        return nil
    end

    cfg.enabled = group.Switch and group:Switch("Включить", true) or nil
    cfg.notifyEnabled = group.Switch and group:Switch("Уведомления", true) or nil
    cfg.toastEnabled = group.Switch and group:Switch("Пуш-уведомления", true) or nil
    cfg.soundEnabled = group.Switch and group:Switch("Звуковое оповещение", true) or nil
    cfg.soundVolume = makeSliderInt(group, "Громкость", 1, 100, 25, "%d")
    cfg.notifyDuration = makeSliderInt(group, "Длительность уведомления", 10, 100, 25, "%d")
    cfg.minScore = makeSliderInt(group, "Порог (1-3)", 1, 3, 1, "%d")
    cfg.includeSoft = group.Switch and group:Switch("Учитывать soft-слова", true) or nil
    cfg.includeMasked = group.Switch and group:Switch("Учитывать замазанные (***,•••)", true) or nil
    cfg.maxGlobalLog = makeSliderInt(group, "Макс событий (общий лог)", 10, 200, 60, "%d")
    cfg.maxPerPlayerLog = makeSliderInt(group, "Макс событий (на игрока)", 5, 60, 15, "%d")
    cfg.autoClearOnGameEnd = group.Switch and group:Switch("Очищать лог в конце игры", false) or nil
    cfg.overlayEnabled = group.Switch and group:Switch("Оверлей (иконка в HUD)", true) or nil
    cfg.overlayBind = nil
    if group and group.Bind then
        local defKey = -1
        local bc = Enum and Enum.ButtonCode or nil
        if bc then
            defKey = bc.BUTTON_CODE_INVALID or bc.BUTTON_CODE_NONE or defKey
        end
        local ok, w = pcall(function()
            return group:Bind("Оверлей: показать/скрыть", defKey)
        end)
        if ok then
            cfg.overlayBind = w
        end
    end

    if cfg.enabled and cfg.enabled.SetCallback then
        cfg.enabled:SetCallback(function()
            local enabled = cfg.enabled:Get()
            if cfg.notifyEnabled and cfg.notifyEnabled.Disabled then
                cfg.notifyEnabled:Disabled(not enabled)
            end
            if cfg.toastEnabled and cfg.toastEnabled.Disabled then
                cfg.toastEnabled:Disabled(not enabled)
            end
            if cfg.soundEnabled and cfg.soundEnabled.Disabled then
                cfg.soundEnabled:Disabled(not enabled)
            end
            if cfg.soundVolume and cfg.soundVolume.Disabled then
                cfg.soundVolume:Disabled(not enabled or (cfg.soundEnabled and not cfg.soundEnabled:Get()))
            end
            if cfg.notifyDuration and cfg.notifyDuration.Disabled then
                cfg.notifyDuration:Disabled(not enabled)
            end
            if cfg.minScore and cfg.minScore.Disabled then
                cfg.minScore:Disabled(not enabled)
            end
            if cfg.includeSoft and cfg.includeSoft.Disabled then
                cfg.includeSoft:Disabled(not enabled)
            end
            if cfg.includeMasked and cfg.includeMasked.Disabled then
                cfg.includeMasked:Disabled(not enabled)
            end
            if cfg.maxGlobalLog and cfg.maxGlobalLog.Disabled then
                cfg.maxGlobalLog:Disabled(not enabled)
            end
            if cfg.maxPerPlayerLog and cfg.maxPerPlayerLog.Disabled then
                cfg.maxPerPlayerLog:Disabled(not enabled)
            end
            if cfg.autoClearOnGameEnd and cfg.autoClearOnGameEnd.Disabled then
                cfg.autoClearOnGameEnd:Disabled(not enabled)
            end
            if cfg.overlayEnabled and cfg.overlayEnabled.Disabled then
                cfg.overlayEnabled:Disabled(not enabled)
            end
            if cfg.overlayBind and cfg.overlayBind.Disabled then
                cfg.overlayBind:Disabled(not enabled or (cfg.overlayEnabled and not cfg.overlayEnabled:Get()))
            end
        end, true)
    end

    if cfg.soundEnabled and cfg.soundEnabled.SetCallback then
        cfg.soundEnabled:SetCallback(function()
            local enabled = cfg.enabled and cfg.enabled.Get and cfg.enabled:Get() or false
            if cfg.soundVolume and cfg.soundVolume.Disabled then
                cfg.soundVolume:Disabled((not enabled) or (not cfg.soundEnabled:Get()))
            end
        end, true)
    end

    local monitor = tab:Create("Монитор")
    if monitor and monitor.Create then
        local groupSide = Enum and Enum.GroupSide or nil
        local SIDE_LEFT = groupSide and groupSide.Left or 1
        local SIDE_RIGHT = groupSide and groupSide.Right or 2
        local SIDE_FULL = groupSide and groupSide.FullWidth or 3

        local function createGroup(thirdTab, name, side)
            if not thirdTab or not thirdTab.Create then
                return nil
            end
            if side ~= nil then
                local ok, grp = pcall(function()
                    return thirdTab:Create(name, side)
                end)
                if ok and grp then
                    return grp
                end
            end
            local ok, grp = pcall(function()
                return thirdTab:Create(name)
            end)
            if ok then
                return grp
            end
            return nil
        end

        local actions = createGroup(monitor, "Управление", SIDE_FULL) or createGroup(monitor, "Управление", nil)
        local radGroup = createGroup(monitor, "Radiant", SIDE_LEFT)
        local direGroup = createGroup(monitor, "Dire", SIDE_RIGHT)
        local logGroup = createGroup(monitor, "Лог", SIDE_FULL) or createGroup(monitor, "Лог", nil)

        state.ui.teamSlots = { [2] = {}, [3] = {} }
        state.ui.logLines = {}

        if actions then
            state.ui.statusLabel = actions:Label("Статус: —")
            actions:Button("Синхронизировать игроков", function()
                syncPlayers(true)
                updateUi(true)
            end)
            actions:Button("Очистить всё (лог + счётчики)", function()
                clearAllStats()
                updateUi(true)
            end)
            actions:Button("Оверлей: открыть/закрыть", function()
                state.renderOverlay.open = not state.renderOverlay.open
                state.renderOverlay.dragging = false
            end)
        end

        local function buildTeamUi(team, groupObj)
            if not groupObj then
                return
            end
            groupObj:Label("Игрок | Счёт | Последнее слово")
            for i = 1, 5 do
                local lbl = groupObj:Label("—")
                local slot = { label = lbl, playerId = nil }

                local gear = lbl:Gear("Детали")
                local details = {
                    stats = gear:Label("—"),
                    words = {},
                    events = {},
                }
                gear:Label("Топ слова:")
                for wi = 1, 6 do
                    details.words[wi] = gear:Label("—")
                end
                gear:Label("Последние события:")
                for ei = 1, 6 do
                    details.events[ei] = gear:Label("—")
                end
                gear:Button("Очистить игрока", function()
                    if slot.playerId ~= nil then
                        clearPlayerStats(slot.playerId)
                        updateUi(true)
                    end
                end)

                slot.details = details
                state.ui.teamSlots[team][i] = slot
            end
        end

        buildTeamUi(2, radGroup)
        buildTeamUi(3, direGroup)

        if logGroup then
            logGroup:Label("Последние детекты (наведите мышь для текста)")
            for i = 1, 12 do
                state.ui.logLines[i] = logGroup:Label("—")
            end
            logGroup:Button("Очистить лог", function()
                state.history = {}
                state.uiDirty = true
                updateUi(true)
            end)
        end

        state.ui.built = true
        state.uiDirty = true
        updateUi(true)
    end

end

function script.OnPostReceivedNetMessage(msg)
    if not cfg.enabled or not cfg.enabled:Get() then
        return true
    end

    if not msg or not msg.msg_object then
        return true
    end

    local text, playerId = extractMessageTextFromObject(msg.msg_object)
    local msgId = msg.message_id or -1

    if not text then
        return true
    end

    if msgId == 394 then
        return true
    end

    if playerId == nil then
        return true
    end

    local score, hit = scoreToxicity(text)
    local includeSoft = getWidgetValue(cfg.includeSoft, true)
    local includeMasked = getWidgetValue(cfg.includeMasked, true)
    if score == 1 and not includeSoft then
        score = 0
    end
    if score == 2 and not includeMasked then
        score = 0
    end

    local minScore = getWidgetValue(cfg.minScore, 1)
    if score >= minScore then
        syncPlayers(false)
        recordDetection(playerId, score, hit, text)
        if cfg.notifyEnabled and cfg.notifyEnabled.Get and cfg.notifyEnabled:Get() then
            notifyToxic(playerId, score, text, hit)
        end
    end

    return true
end

function script.OnUpdate()
    if cfg.enabled and cfg.enabled.Get and not cfg.enabled:Get() then
        return
    end
    syncPlayers(false)
    updateUi(false)

    local overlayEnabled = getWidgetValue(cfg.overlayEnabled, true)
    state.renderOverlay.enabled = overlayEnabled and true or false
    if not overlayEnabled then
        closeOverlay()
        return
    end

    if cfg.overlayBind and cfg.overlayBind.Get and Input and Input.IsKeyDownOnce and (not (Input.IsInputCaptured and Input.IsInputCaptured())) then
        local key = cfg.overlayBind:Get()
        if key ~= nil then
            local ok, pressed = pcall(Input.IsKeyDownOnce, key)
            if ok and pressed then
                toggleOverlay()
            end
        end
    end
end

function script.OnDraw()
    if cfg.enabled and cfg.enabled.Get and not cfg.enabled:Get() then
        return
    end
    drawToasts()
    if getWidgetValue(cfg.overlayEnabled, true) then
        drawOverlay()
    end
end

function script.OnGameEnd()
    state.nextNotifyTime = 0
    state.toasts = {}
    if cfg.autoClearOnGameEnd and cfg.autoClearOnGameEnd.Get and cfg.autoClearOnGameEnd:Get() then
        clearAllStats()
    end
    state.uiDirty = true
    closeOverlay()
end

initMenu()

return script
