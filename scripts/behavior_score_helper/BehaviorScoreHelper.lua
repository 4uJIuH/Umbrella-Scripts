local SCRIPT_VERSION = "1.0.0"
local test = {}

local protobuf = require('protobuf')
local JSON = require('assets.JSON')

local cyrillic_lower_map = {
    ["А"]="а", ["Б"]="б", ["В"]="в", ["Г"]="г", ["Д"]="д", ["Е"]="е", ["Ё"]="ё", ["Ж"]="ж",
    ["З"]="з", ["И"]="и", ["Й"]="й", ["К"]="к", ["Л"]="л", ["М"]="м", ["Н"]="н", ["О"]="о",
    ["П"]="п", ["Р"]="р", ["С"]="с", ["Т"]="т", ["У"]="у", ["Ф"]="ф", ["Х"]="х", ["Ц"]="ц",
    ["Ч"]="ч", ["Ш"]="ш", ["Щ"]="щ", ["Ъ"]="ъ", ["Ы"]="ы", ["Ь"]="ь", ["Э"]="э", ["Ю"]="ю", ["Я"]="я"
}

local function utf8_lower(str)
    if not str then return str end
    local res = string.lower(str)
    for upper, lower in pairs(cyrillic_lower_map) do
        res = string.gsub(res, upper, lower)
    end
    return res
end

local mainMenu = Menu.Create("Scripts", "Utility")
local mainTab = mainMenu:Create("Порядочность")
mainTab:Icon("\u{f164}")

local tabGG = mainTab:Create("Авто GG")
local tabReport = mainTab:Create("Авто Репорт")
local tabFeed = mainTab:Create("Авто Репорт (Фид)")
local tabLike = mainTab:Create("Авто Лайк")

local ggSection = tabGG:Create("Настройки")
local ggEnabled = ggSection:Switch("Включено", false, "\u{f00c}")
local ggMessages = {
    "спс за игру",
    "спасибо за игру, лайк всем",
    "gg киньте лайк пж",
    "киньте лайк пж",
    "спасибо за игру, лайкосик всем",
    "gl next лайк не забудьте",
    "Своё сообщение (из поля ниже)"
}
local ggMessageSelect = ggSection:Combo("Сообщение при победе/лузе", ggMessages)
local ggCustomMessage = ggSection:Input("Своё сообщение", "gg wp")
local ggDelay = ggSection:Slider("Задержка после разрушения трона (сек)", 0, 5, 0)
local ggAllChat = ggSection:Switch("Общий чат", true)

local greetEnabled = ggSection:Switch("Приветствие в начале игры", false, "\u{f0a1}")
local greetAllChat = ggSection:Switch("Приветствие в общий чат", false)
local greetMessage = ggSection:Input("Текст приветствия", "gl hf!")

local reportSection = tabReport:Create("Настройки")
local reportEnabled = reportSection:Switch("Включено", false, "\u{f00c}")
local reportTargetMode = reportSection:Combo("Цель", {"Только враги", "Только союзники", "Все"})
local reportAutoUnmute = reportSection:Switch("Авто-размут после репорта", true, "\u{f028}")
local reportNotify = reportSection:Switch("Логировать в консоль", true)
local reportMatchMode = reportSection:Combo("Режим поиска", {"Точное слово", "Содержит подстроку", "Оба"})
reportMatchMode:Icon("\u{f002}")
local reportLogToFile = reportSection:Switch("Писать репорты в файл", true, "\u{f15c}")
local reportStreamMode = reportSection:Switch("Тихий режим (скрыть баннер)", false, "\u{f070}")

local feedSection = tabFeed:Create("Настройки")
local feedEnabled = feedSection:Switch("Включено", false, "\u{f00c}")
local feedMinutes = feedSection:Slider("Минута байбека (до)", 1, 20, 10)

local likeSettings = tabLike:Create("Настройки")
local likes_enabled = likeSettings:Switch("Включено", true, "\u{f00c}")
local switcherLikeRefresh = likeSettings:Switch("Обновить лайк", false)
switcherLikeRefresh:Icon("\u{f2f9}")
local alliesOnlySwitch = likeSettings:Switch("Только союзники", false)
alliesOnlySwitch:Icon("\u{f2b5}")

local likeTeams = tabLike:Create("Выбор героев")
local likeRad = likeTeams:MultiSelect("Лайк", {}, true)
likeRad:Icon("\u{e5d2}")
local likeDir = likeTeams:MultiSelect("Лайк", {}, true)
likeDir:Icon("\u{e037}")

local whitelistSubstrings = {
    "ребят", "хлеб", "себя", "тебя", "небе", "небо", "небу", "неба", "мебел", "дебат", 
    "стебел", "гребен", "гребн", "грест", "греб", "требова", "требу", "колеб", "лебед", 
    "серебр", "жереб", "амеб", "плацеб", "небылиц", "требует", "плацебо",
    "наход", "монас", "монах", "альманах", "внахлест", "нахлыну", "нахрап"
}

local function resolveScriptDir()
    if GetScriptDir then
        local ok, dir = pcall(GetScriptDir)
        if ok and type(dir) == "string" and dir ~= "" then return (dir:gsub("[/\\]+$", "")) end
    end
    local ok, base = pcall(function() return Engine and Engine.GetCheatDirectory and Engine.GetCheatDirectory() end)
    if ok and type(base) == "string" and base ~= "" then return (base:gsub("[/\\]+$", "")) .. "/scripts" end
    return "scripts"
end

local SCRIPT_DIR = resolveScriptDir()
local REPORT_LOG_PATH = SCRIPT_DIR .. "/bh_helper_reports_log.txt"

local function logReportToFile(line)
    if not reportLogToFile:Get() then return end
    local file = io.open(REPORT_LOG_PATH, "a")
    if not file then return end
    file:write(line .. "\n")
    file:close()
end

local function loadWordsFromFile(filename)
    local words = {}
    local file = io.open(SCRIPT_DIR .. "/filters/" .. filename, "r")
    if not file then file = io.open("scripts/filters/" .. filename, "r") end
    if not file then return words end
    for rawLine in file:lines() do
        local trimmed = rawLine:match("^%s*(.-)%s*$")
        if trimmed and #trimmed > 0 and not trimmed:match("^#") then
            table.insert(words, utf8_lower(trimmed))
        end
    end
    file:close()
    print("[bh_helper] загружено слов: " .. #words .. " из " .. filename)
    return words
end

local filterBannedRussian = loadWordsFromFile("filter_banned_russian_cached.txt")
local filterProfanityRussian = loadWordsFromFile("filter_profanity_russian_cached.txt")
local filterProfanityEnglish = loadWordsFromFile("filter_profanity_english_cached.txt")
local filterBannedEnglish = loadWordsFromFile("filter_banned_english_cached.txt")

local fallbackProfanity = {
    "пидор", "пидр", "хуй", "хуя", "хуе", "пизд", "еблан", "ебл", "еба", "сука", 
    "гондон", "гандон", "мудак", "шлюх", "бля", "уеб", "заеб", "охуе", "ахуе", "cunt", "fuck", "kys"
}

if #filterProfanityRussian == 0 then
    filterProfanityRussian = fallbackProfanity
    print("[bh_helper] файлы фильтров пустые или не найдены, взял дефолт список")
end

local function wordsToHashSet(wordList)
    local set = {}
    for _, word in ipairs(wordList) do
        set[word] = true
    end
    return set
end

local bannedRussianSet = wordsToHashSet(filterBannedRussian)
local profanityRussianSet = wordsToHashSet(filterProfanityRussian)
local profanityEnglishSet = wordsToHashSet(filterProfanityEnglish)
local bannedEnglishSet = wordsToHashSet(filterBannedEnglish)

local init = false
local localPlayerTeam = nil
local lastProcessTime = 0
local PROCESS_INTERVAL = 0.5
local ggSent = false
local throneBroken = false
local ggScheduledTime = nil
local ancientRad = nil
local ancientDir = nil
local gameend = false
local radiant, dire = {}, {}

local m_players = {}
local accountIdCache = {}
local reportedPlayers = {}
local reportQueue = {}
local lastReportSendTime = 0
local lastPlayersSyncTime = 0

local function getLobbyIdString()
    if not GameRules or not GameRules.GetLobbyObjectJson then return nil end
    local ok, jsonStr = pcall(GameRules.GetLobbyObjectJson)
    if ok and jsonStr and jsonStr ~= "" then
        local lobbyId = string.match(jsonStr, '"lobby_id"%s*:%s*"(%d+)"')
            or string.match(jsonStr, '"lobby_id"%s*:%s*(%d+)')
            or string.match(jsonStr, '"lobbyid"%s*:%s*"(%d+)"')
            or string.match(jsonStr, '"lobbyid"%s*:%s*(%d+)')
        if lobbyId then return lobbyId end
    end
    if GameRules.GetLobbyID then
        local ok2, val = pcall(GameRules.GetLobbyID)
        if ok2 and val then return string.format("%.0f", val) end
    end
    return nil
end

local function resolveAccountId(playerEnt)
    if not playerEnt then return 0 end
    local ok_pd, pd = pcall(Player.GetPlayerData, playerEnt)
    if ok_pd and pd then
        local acc = pd.account_id or pd.accountid or pd.AccountID
        if acc and acc > 0 then return math.floor(acc) end
        local steam = pd.steamid or pd.steam_id or pd.SteamID
        if steam then
            local steamNum = tonumber(steam)
            if steamNum and steamNum > 76561197960265728 then
                return math.floor(steamNum - 76561197960265728)
            end
        end
    end
    local ok_td, td = pcall(Player.GetTeamData, playerEnt)
    if ok_td and td then
        local acc = td.account_id or td.accountid or td.AccountID or td.m_iAccountID or td.m_unAccountID
        if acc and acc > 0 then return math.floor(acc) end
    end
    return 0
end

local function syncPlayers(force)
    local curTime = os.clock()
    if not force and (curTime - lastPlayersSyncTime < 2.0) then return end
    lastPlayersSyncTime = curTime
    if not Players or not Players.Count or not Players.Get then return end
    local count = Players.Count()
    for i = 0, count do
        local p = Players.Get(i)
        if p and Entity.IsPlayer(p) then
            local pid = Player.GetPlayerID(p)
            if pid and pid >= 0 then
                local name = Player.GetName(p) or "Player"
                local accId = resolveAccountId(p)
                local slot = Player.GetPlayerSlot(p) or i
                m_players[pid] = {
                    entity = p,
                    name = name,
                    accountId = accId,
                    slot = slot,
                    team = Entity.GetTeamNum(p)
                }
                if accId > 0 then accountIdCache[pid] = accId end
            end
        end
    end
end

local function getActiveWordSets()
    return {
        { hash = profanityEnglishSet, list = filterProfanityEnglish, name = "en_mat" },
        { hash = bannedEnglishSet,    list = filterBannedEnglish,    name = "en_ban" },
        { hash = profanityRussianSet, list = filterProfanityRussian, name = "ru_mat" },
        { hash = bannedRussianSet,    list = filterBannedRussian,    name = "ru_ban" }
    }
end

local function splitWords(str)
    local words = {}
    for word in str:gmatch("[%w%a\128-\255]+") do
        table.insert(words, utf8_lower(word))
    end
    return words
end

local function checkToxic(message)
    if not message or #message == 0 then return false, nil end
    local lowerMsg = utf8_lower(message)
    local msgWords = splitWords(lowerMsg)
    local matchMode = reportMatchMode:Get() or 0
    local activeSets = getActiveWordSets()
    for _, word in ipairs(msgWords) do
        local isWhitelisted = false
        for _, wl in ipairs(whitelistSubstrings) do
            if string.find(word, wl, 1, true) then
                isWhitelisted = true
                break
            end
        end
        if not isWhitelisted then
            if matchMode == 0 or matchMode == 2 then
                for _, setData in ipairs(activeSets) do
                    if setData.hash[word] then
                        return true, word .. " (" .. setData.name .. ")"
                    end
                end
            end
            if matchMode == 1 or matchMode == 2 then
                for _, setData in ipairs(activeSets) do
                    for _, filterWord in ipairs(setData.list) do
                        if #filterWord <= 3 then
                            if word == filterWord then
                                return true, filterWord .. " (короткое в " .. setData.name .. ")"
                            end
                        else
                            if string.find(word, filterWord, 1, true) then
                                return true, filterWord .. " (подстрока в " .. word .. ")"
                            end
                        end
                    end
                end
            end
        end
    end
    if matchMode == 1 or matchMode == 2 then
        for _, setData in ipairs(activeSets) do
            for _, filterWord in ipairs(setData.list) do
                if #filterWord >= 5 then
                    if string.find(lowerMsg, filterWord, 1, true) then
                        return true, filterWord .. " (фраза)"
                    end
                end
            end
        end
    end
    return false, nil
end

local function resolvePlayerHeroName(playerInfo)
    if not playerInfo or not playerInfo.entity then return nil end
    local ok, td = pcall(Player.GetTeamData, playerInfo.entity)
    if ok and td and td.selected_hero_id and td.selected_hero_id > 0 then
        local okName, heroName = pcall(Engine.GetHeroNameByID, td.selected_hero_id)
        if okName and heroName and heroName ~= "" then return heroName end
    end
    return nil
end

local function showReportNotification(title, subtitle, heroName, duration)
    local shown = false
    if Notification then
        shown = pcall(Notification, {
            duration = duration,
            timer = duration,
            hero = heroName,
            primary_text = title,
            secondary_text = subtitle
        })
    end
    if not shown and Render and Render.CenteredNotification then
        pcall(Render.CenteredNotification, title .. ": " .. subtitle, duration)
    end
end


local heroIconCache = {}
local bannerTitleFont = nil
local bannerSubFont = nil
local reportBannerQueue = {}
local activeReportBanner = nil

local function getHeroIconHandle(heroName)
    if not heroName or not Render or not Render.LoadImage then return nil end
    local cached = heroIconCache[heroName]
    if cached ~= nil then
        if cached == false then return nil end
        return cached
    end
    local path = "panorama/images/heroes/icons/" .. heroName .. "_png.vtex_c"
    local ok, handle = pcall(Render.LoadImage, path)
    if ok and handle then
        heroIconCache[heroName] = handle
        return handle
    end
    heroIconCache[heroName] = false
    return nil
end

local function queueReportBanner(title, subtitle, heroName, duration)
    if reportStreamMode:Get() then return end
    table.insert(reportBannerQueue, {
        title = title,
        subtitle = subtitle,
        heroName = heroName,
        duration = duration or 4.0
    })
end

local function drawReportBanner()
    if reportStreamMode:Get() then
        reportBannerQueue = {}
        activeReportBanner = nil
        return
    end
    if not Render or not Render.FilledRect or not Render.ScreenSize then return end
    local curTime = os.clock()

    if not activeReportBanner then
        if #reportBannerQueue == 0 then return end
        local nextBanner = table.remove(reportBannerQueue, 1)
        nextBanner.startTime = curTime
        activeReportBanner = nextBanner
    end

    local b = activeReportBanner
    local elapsed = curTime - b.startTime
    if elapsed >= b.duration then
        activeReportBanner = nil
        return
    end

    if not bannerTitleFont then
        local okT, fT = pcall(Render.LoadFont, "Arial", 0, 800)
        local okS, fS = pcall(Render.LoadFont, "Arial", 0, 500)
        bannerTitleFont = okT and fT or nil
        bannerSubFont = okS and fS or nil
    end
    if not bannerTitleFont then return end

    local fadeIn, fadeOut = 0.25, 0.45
    local alpha = 255
    if elapsed < fadeIn then
        alpha = math.floor(255 * (elapsed / fadeIn))
    elseif elapsed > b.duration - fadeOut then
        alpha = math.floor(255 * ((b.duration - elapsed) / fadeOut))
    end
    if alpha < 0 then alpha = 0 elseif alpha > 255 then alpha = 255 end

    local slideOffset = 0
    if elapsed < fadeIn then
        slideOffset = (1 - (elapsed / fadeIn)) * -25
    end

    local screenSize = Render.ScreenSize()
    local boxW, boxH = 440, 68
    local iconSize = 48
    local padding = 14
    local x = (screenSize.x - boxW) / 2
    local y = 90 + slideOffset

    local startPos = Vec2(x, y)
    local endPos = Vec2(x + boxW, y + boxH)

    pcall(Render.Shadow, startPos, endPos, Color(255, 40, 40, math.floor(alpha * 0.55)), 20, 10)
    pcall(Render.Gradient, startPos, endPos,
        Color(45, 12, 12, math.floor(alpha * 0.93)),
        Color(45, 12, 12, math.floor(alpha * 0.93)),
        Color(18, 18, 18, math.floor(alpha * 0.93)),
        Color(18, 18, 18, math.floor(alpha * 0.93)),
        10)
    pcall(Render.FilledRect, Vec2(x, y), Vec2(x + 5, y + boxH), Color(235, 55, 55, alpha), 2)
    pcall(Render.Rect, startPos, endPos, Color(235, 55, 55, alpha), 10, nil, 1.5)

    local textX = x + padding + 4
    local iconHandle = getHeroIconHandle(b.heroName)
    if iconHandle then
        pcall(Render.Image, iconHandle, Vec2(x + padding, y + (boxH - iconSize) / 2), Vec2(iconSize, iconSize), Color(255, 255, 255, alpha))
        textX = x + padding + iconSize + 12
    end

    pcall(Render.Text, bannerTitleFont, 17, b.title, Vec2(textX, y + 12), Color(255, 95, 95, alpha))
    pcall(Render.Text, bannerSubFont, 14, b.subtitle, Vec2(textX, y + 37), Color(235, 235, 235, alpha))
end

local function sendReport(playerID, accountID, triggerWord, messageText)
    if not accountID or accountID == 0 then
        print("[bh_helper] ошибка: нет accountid для pid " .. tostring(playerID))
        return false
    end
    local localPlayer = Players.GetLocal()
    local mySlot = localPlayer and Player.GetPlayerSlot(localPlayer) or 0
    local lobbyIdStr = getLobbyIdString() or "0"
    local gameTime = GameRules and GameRules.GetGameTime() or 0.0
    local hud = Panorama.GetPanelByName("DotaHud", false)
             or Panorama.GetPanelByName("Hud", false)
             or Panorama.GetPanelByName("HUDElements", false)
             or Panorama.GetPanelByName("scoreboard", false)
                  
    if hud then
        local autoUnmuteVal = reportAutoUnmute:Get() and "true" or "false"
        local jsCode = [[
            (function() {
                var targetPid = %d;
                var autoUnmute = %s;
                function findAndClickMute(root, targetPid) {
                    if (!root) return false;
                    var id = root.id || "";
                    var isTargetRow = false;
                    if (targetPid >= 0 && targetPid <= 4 && id === "RadiantPlayer" + targetPid) {
                        isTargetRow = true;
                    } else if (targetPid >= 5 && targetPid <= 9 && id === "DirePlayer" + (targetPid - 5)) {
                        isTargetRow = true;
                    }
                    if (isTargetRow) {
                        var btn = root.FindChildTraverse("PlayerMuteButton");
                        if (btn) {
                            if (btn.Click) { btn.Click(); } else { $.DispatchEvent('Activated', btn, 'mouse'); }
                            if (autoUnmute) {
                                $.Schedule(0.1, function() {
                                    if (Game && Game.SetPlayerMuted) { Game.SetPlayerMuted(targetPid, false); }
                                    if (Game && Game.SetPlayerMutedVoice) { Game.SetPlayerMutedVoice(targetPid, false); }
                                });
                            }
                            return true;
                        }
                    }
                    var count = root.GetChildCount();
                    for (var i = 0; i < count; i++) {
                        if (findAndClickMute(root.GetChild(i), targetPid)) return true;
                    }
                    return false;
                }
                var rootPanel = $.GetContextPanel();
                while (rootPanel.GetParent()) { rootPanel = rootPanel.GetParent(); }
                findAndClickMute(rootPanel, targetPid);
            })();
        ]]
        
        local formattedJs = string.format(jsCode, playerID, autoUnmuteVal)
        pcall(Engine.RunScript, formattedJs, hud)
    end
    local reportTable = {
        target_account_id = accountID,
        report_reason = { 2 },
        lobby_id = lobbyIdStr,
        game_time = gameTime,
        debug_slot = mySlot,
        debug_match_id = "0"
    }
    local successJson, jsonStr = pcall(JSON.encode, JSON, reportTable)
    if successJson and jsonStr then
        local successProto, protoData = pcall(protobuf.encodeFromJSON, "CMsgDOTASubmitPlayerReportV2", jsonStr)
        if successProto and protoData and protoData.binary and protoData.size then
            GC.SendMessage(protoData.binary, 7082, protoData.size)
            if protobuf.free then pcall(protobuf.free, protoData.binary) end
        end
    end
    local playerInfo = m_players[playerID] or {}
    local pName = playerInfo.name or ("Игрок #" .. tostring(playerID))
    if reportNotify:Get() then
        print("[bh_helper] кинул репорт на " .. tostring(pName))
    end
    local heroName = resolvePlayerHeroName(playerInfo)
    showReportNotification("АВТО-РЕПОРТ ОТПРАВЛЕН", pName .. " — за '" .. tostring(triggerWord) .. "'", heroName, 4.0)
    queueReportBanner("АВТО-РЕПОРТ ОТПРАВЛЕН", pName .. " — за '" .. tostring(triggerWord) .. "'", heroName, 4.0)
    logReportToFile(string.format(
        "[%s] TOXIC | %s (accid %s) | триггер: '%s' | сообщение: \"%s\" | lobby=%s | game_time=%.0f",
        os.date("%Y-%m-%d %H:%M:%S"), pName, tostring(accountID), tostring(triggerWord), tostring(messageText), tostring(lobbyIdStr), gameTime
    ))
    return true
end

local function sendFeedReport(playerID, accountID, minutes)
    if not accountID or accountID == 0 then return false end
    local localPlayer = Players.GetLocal()
    local mySlot = localPlayer and Player.GetPlayerSlot(localPlayer) or 0
    local lobbyIdStr = getLobbyIdString() or "0"
    local gameTime = GameRules and GameRules.GetGameTime() or 0.0

    local reportTable = {
        target_account_id = accountID,
        report_reason = { 5 },
        lobby_id = lobbyIdStr,
        game_time = gameTime,
        debug_slot = mySlot,
        debug_match_id = "0"
    }
    local successJson, jsonStr = pcall(JSON.encode, JSON, reportTable)
    if successJson and jsonStr then
        local successProto, protoData = pcall(protobuf.encodeFromJSON, "CMsgDOTASubmitPlayerReportV2", jsonStr)
        if successProto and protoData and protoData.binary and protoData.size then
            GC.SendMessage(protoData.binary, 7082, protoData.size)
            if protobuf.free then pcall(protobuf.free, protoData.binary) end
        end
    end

    local playerInfo = m_players[playerID] or {}
    local pName = playerInfo.name or ("Игрок #" .. tostring(playerID))
    if reportNotify:Get() then
        print("[bh_helper] кинул репорт за фид: " .. tostring(pName))
    end
    local heroName = resolvePlayerHeroName(playerInfo)
    showReportNotification("РЕПОРТ ЗА ФИД", pName .. " (байбек на " .. tostring(minutes) .. " мин)", heroName, 4.0)
    queueReportBanner("РЕПОРТ ЗА ФИД", pName .. " (байбек на " .. tostring(minutes) .. " мин)", heroName, 4.0)
    logReportToFile(string.format(
        "[%s] FEED | %s (accid %s) | байбек на %s мин | lobby=%s | game_time=%.0f",
        os.date("%Y-%m-%d %H:%M:%S"), pName, tostring(accountID), tostring(minutes), tostring(lobbyIdStr), gameTime
    ))
    return true
end

local function recursiveFindString(tbl, keys, maxDepth)
    if type(tbl) ~= "table" or maxDepth <= 0 then return nil end
    for _, key in ipairs(keys) do
        local val = tbl[key]
        if type(val) == "string" and val ~= "" then return val end
    end
    for _, sub in pairs(tbl) do
        if type(sub) == "table" then
            local res = recursiveFindString(sub, keys, maxDepth - 1)
            if res then return res end
        end
    end
    return nil
end

local function recursiveFindNumber(tbl, keys, maxDepth)
    if type(tbl) ~= "table" or maxDepth <= 0 then return nil end
    for _, key in ipairs(keys) do
        local val = tbl[key]
        if val then
            local num = tonumber(val)
            if num and num >= 0 then return math.floor(num) end
        end
    end
    for _, sub in pairs(tbl) do
        if type(sub) == "table" then
            local res = recursiveFindNumber(sub, keys, maxDepth - 1)
            if res then return res end
        end
    end
    return nil
end

local function handleChatMessage(pid, message)
    if not reportEnabled:Get() then return end
    if not message or message == "" then return end
    local localPlayer = Players.GetLocal()
    local myPid = localPlayer and Player.GetPlayerID(localPlayer) or -1
    if pid == myPid then return end
    
    local playerInfo = m_players[pid] or {}
    local name = playerInfo.name or ("Игрок #" .. tostring(pid))
    local accountID = playerInfo.accountId or resolveAccountId(playerInfo.entity)
    
    if accountID == 0 and playerInfo.entity then
        accountID = resolveAccountId(playerInfo.entity)
        playerInfo.accountId = accountID
    end
    
    local targetMode = reportTargetMode:Get() or 0
    local localPlayerTeam = localPlayer and Entity.GetTeamNum(localPlayer) or nil
    if localPlayerTeam and playerInfo.team then
        if targetMode == 0 and playerInfo.team == localPlayerTeam then return end
        if targetMode == 1 and playerInfo.team ~= localPlayerTeam then return end
    end
    
    local isToxic, triggerWord = checkToxic(message)
    if isToxic then
        if reportNotify:Get() then
            print("[bh_helper] токсик: " .. name .. " | триггер: '" .. tostring(triggerWord) .. "'")
        end
        if not reportedPlayers[pid] then
            table.insert(reportQueue, {
                playerID = pid,
                accountID = accountID,
                trigger = triggerWord,
                message = message,
                isFeed = false
            })
            reportedPlayers[pid] = true
        end
    end
end

local function handlePlayerBuyback(pid)
    if not feedEnabled:Get() then return end
    local gameTime = GameRules and GameRules.GetGameTime() or 0
    local gameTimeMinutes = gameTime / 60
    local maxMinutes = feedMinutes:Get() or 10
    if gameTimeMinutes <= maxMinutes then
        syncPlayers(false)
        local playerInfo = m_players[pid]
        if playerInfo then
            local localPlayer = Players.GetLocal()
            local myPid = localPlayer and Player.GetPlayerID(localPlayer) or -1
            if pid == myPid then return end
            local targetMode = reportTargetMode:Get() or 0
            local localPlayerTeam = localPlayer and Entity.GetTeamNum(localPlayer) or nil
            if localPlayerTeam and playerInfo.team then
                if targetMode == 0 and playerInfo.team == localPlayerTeam then return end
                if targetMode == 1 and playerInfo.team ~= localPlayerTeam then return end
            end
            local accountID = playerInfo.accountId or resolveAccountId(playerInfo.entity)
            if accountID and accountID > 0 then
                if not reportedPlayers[pid] then
                    table.insert(reportQueue, {
                        playerID = pid,
                        accountID = accountID,
                        trigger = string.format("байбек на %d мин", math.floor(gameTimeMinutes)),
                        message = "ранний байбек",
                        isFeed = true
                    })
                    reportedPlayers[pid] = true
                end
            end
        end
    end
end

local function processReportQueue()
    if #reportQueue == 0 then return end
    local curTime = os.clock()
    if curTime - lastReportSendTime < 2.0 then return end

    local report = reportQueue[1]
    if report.accountID == 0 then
        report.accountID = resolveAccountId(m_players[report.playerID] and m_players[report.playerID].entity)
    end

    if report.accountID == 0 then
        table.remove(reportQueue, 1)
        return
    end

    local success = false
    if report.isFeed then
        success = sendFeedReport(report.playerID, report.accountID, report.trigger)
    else
        success = sendReport(report.playerID, report.accountID, report.trigger, report.message)
    end

    table.remove(reportQueue, 1)
    if success then lastReportSendTime = curTime end
end

local function extractHeroName(src)
    if not src then return nil end
    local heroName = string.match(src, "npc_dota_hero_([^%.]+)")
        or string.match(src, "heroes/([^%._]+)arcana")
        or string.match(src, "heroes/([^%.]+)_persona")
        or string.match(src, "heroes/icons/([^%.]+)")
        or string.match(src, "/([^/]+)_png%.vtex")
    if heroName and not string.match(heroName, "^npc_dota_hero_") then
        heroName = "npc_dota_hero_" .. heroName
    end
    return heroName
end

local function processChildren(container, likeEnabled)
    if not container then return false end
    local commended = false
    for i = 0, container:GetChildCount() - 1 do
        local child = container:GetChild(i)
        if child then
            local HeroBackground = child:GetChild(1)
            if not HeroBackground then goto continue end
            local hero = HeroBackground:FindChildTraverse("MainHeroImage")
            if not hero then goto continue end
            local heroName = extractHeroName(hero:GetImageSrc())
            if not heroName then goto continue end
            local baseHeroName = heroName
            baseHeroName = string.gsub(baseHeroName, "_alt%d+$", "")
            baseHeroName = string.gsub(baseHeroName, "_persona%d*$", "")
            baseHeroName = string.gsub(baseHeroName, "_arcana%d*$", "")
            local isLike = likeEnabled[heroName] or likeEnabled[baseHeroName]
            if isLike then
                local button = child:FindChildTraverse("ButtonDrawer")
                if button then
                    Engine.RunScript("$.DispatchEvent('OverviewHeroCommendPlayer')", button)
                    commended = true
                end
            end
        end
        ::continue::
    end
    return commended
end

local function processLikeDislike()
    if not (gameend or switcherLikeRefresh:Get()) then return end
    if not likes_enabled:Get() then return end
    local parent = Panorama.GetPanelByName("OverviewHeroes", false)
    if not parent then
        gameend = false
        switcherLikeRefresh:Set(false)
        return
    end
    local leftHeroes = parent:FindChildTraverse("LeftHeroes")
    local rightHeroes = parent:FindChildTraverse("RightHeroes")
    if not (leftHeroes and rightHeroes) then return end
    local likeEnabled = {}
    if likeRad and likeDir then
        local radList, dirList = likeRad:ListEnabled(), likeDir:ListEnabled()
        if alliesOnlySwitch:Get() then
            if localPlayerTeam == 2 then
                for _, h in pairs(radList) do likeEnabled[h] = true end
            else
                for _, h in pairs(dirList) do likeEnabled[h] = true end
            end
        else
            for _, h in pairs(radList) do likeEnabled[h] = true end
            for _, h in pairs(dirList) do likeEnabled[h] = true end
        end
    end
    local leftCommended = processChildren(leftHeroes, likeEnabled)
    local rightCommended = processChildren(rightHeroes, likeEnabled)
    if leftCommended or rightCommended then switcherLikeRefresh:Set(false) end
    if leftCommended or rightCommended then gameend = false end
end

function test.updateTeamSettings()
    if not init or not localPlayerTeam then return end
    local function createTeamOptions(teamHeroes, isAllyTeam, isLikeMode)
        local options = {}
        for _, heroId in ipairs(teamHeroes) do
            local name = Engine.GetHeroNameByID(heroId)
            local heroIcon = "panorama/images/heroes/icons/" .. name .. "_png.vtex_c"
            local defaultValue = isLikeMode and (not alliesOnlySwitch:Get() or isAllyTeam) or false
            table.insert(options, { name, heroIcon, defaultValue })
        end
        return options
    end
    if localPlayerTeam == 2 then
        likeRad:Update(createTeamOptions(radiant, true, true), true)
        likeDir:Update(createTeamOptions(dire, false, true), true)
    else
        likeRad:Update(createTeamOptions(radiant, false, true), true)
        likeDir:Update(createTeamOptions(dire, true, true), true)
    end
end

alliesOnlySwitch:SetCallback(function() test.updateTeamSettings() end)
likes_enabled:SetCallback(function()
    local disabled = not likes_enabled:Get()
    switcherLikeRefresh:Disabled(disabled)
    likeRad:Disabled(disabled)
    alliesOnlySwitch:Disabled(disabled)
    likeDir:Disabled(disabled)
end, true)

ggMessageSelect:SetCallback(function()
    local isCustom = (ggMessageSelect:Get() == #ggMessages - 1)
    ggCustomMessage:Disabled(not isCustom)
end, true)

function test.OnPostReceivedNetMessage(msg)
    if not msg or not msg.msg_object then return end
    if not reportEnabled:Get() then return end
    local chatMsgIds = { [612] = true, [615] = true, [118] = true, [119] = true, [120] = true }
    if not chatMsgIds[msg.message_id] then return end
    local successProto, jsonStr = pcall(protobuf.decodeToJSONfromObject, msg.msg_object)
    if not successProto or not jsonStr or jsonStr == "" then return end
    local successJson, data = pcall(JSON.decode, JSON, jsonStr)
    if not successJson or type(data) ~= "table" then return end
    local message = recursiveFindString(data, {"message_text", "text", "message", "chat_text", "raw_text"}, 5)
    local pid = recursiveFindNumber(data, {"player_id", "playerid", "playerid_1", "player_id_1", "playerid_2", "player_id_2", "value", "source_player_id", "ent_idx"}, 5)
    if message and message ~= "" and pid then
        syncPlayers(false)
        handleChatMessage(pid, message)
    end
end

function test.OnFireEventClient(data)
    if not data or not data.event then return end
    if data.name == "dota_buyback" then
        local pid = Event.GetInt(data.event, "player_id")
        if pid and pid >= 0 then handlePlayerBuyback(pid) end
    end
end

function test.OnDraw()
    drawReportBanner()
end

function test.OnUpdateEx()
    processReportQueue()
    
    if os.clock() - lastProcessTime >= PROCESS_INTERVAL then
        lastProcessTime = os.clock()
        processLikeDislike()
    end
    
    if ggEnabled:Get() and not ggSent then
        if not ancientRad or not ancientDir then
            local localHero = Heroes.GetLocal()
            if localHero then
                local ok_units, units = pcall(Entity.GetUnitsInRadius, localHero, 99999, Enum.TeamType.TEAM_BOTH)
                if ok_units and units then
                    for _, ent in pairs(units) do
                        local ok_class, class_name = pcall(Entity.GetClassName, ent)
                        if ok_class and class_name == "C_DOTA_BaseNPC_Fort" then
                            local ok_team, team_num = pcall(Entity.GetTeamNum, ent)
                            if ok_team then
                                if team_num == 2 then ancientRad = ent
                                elseif team_num == 3 then ancientDir = ent end
                            end
                        end
                    end
                end
            end
        end
        
        local radDead = false
        if ancientRad then
            local ok_ent, is_ent = pcall(Entity.IsEntity, ancientRad)
            if ok_ent and is_ent then
                local ok_alive, alive = pcall(Entity.IsAlive, ancientRad)
                if ok_alive and alive then
                    local ok_hp, hp = pcall(Entity.GetHealth, ancientRad)
                    if ok_hp and hp then radDead = (hp <= 0) end
                else
                    radDead = true
                end
            else
                ancientRad = nil
            end
        end
        
        local dirDead = false
        if ancientDir then
            local ok_ent, is_ent = pcall(Entity.IsEntity, ancientDir)
            if ok_ent and is_ent then
                local ok_alive, alive = pcall(Entity.IsAlive, ancientDir)
                if ok_alive and alive then
                    local ok_hp, hp = pcall(Entity.GetHealth, ancientDir)
                    if ok_hp and hp then dirDead = (hp <= 0) end
                else
                    dirDead = true
                end
            else
                ancientDir = nil
            end
        end
        
        if (radDead or dirDead) and not throneBroken then
            throneBroken = true
            ggScheduledTime = os.clock() + (ggDelay:Get() or 0)
        end
        if throneBroken and ggScheduledTime and os.clock() >= ggScheduledTime then
            local selectedIndex = ggMessageSelect:Get() or 0
            local ggMsg = ""
            if selectedIndex == #ggMessages - 1 then
                ggMsg = ggCustomMessage:Get() or "gg wp"
            else
                ggMsg = ggMessages[selectedIndex + 1]
            end
            
            local cmd = ggAllChat:Get() and "say " or "say_team "
            Engine.ExecuteCommand(cmd .. ggMsg)
            ggSent = true
        end
    end
end

function test.OnUpdate()
    local hero = Heroes.GetLocal()
    if not hero or init then return end
    init = true
    
    local localPlayer = Players.GetLocal()
    if localPlayer then
        localPlayerTeam = Entity.GetTeamNum(localPlayer)
    end
    
    print("[bh_helper] запуск инициализации")
    syncPlayers(true)
    
    pcall(Event.AddListener, "dota_buyback")

    if greetEnabled:Get() then
        local msg = greetMessage:Get() or "gl hf!"
        local cmd = greetAllChat:Get() and "say " or "say_team "
        Engine.ExecuteCommand(cmd .. msg)
    end
    
    for pid, pInfo in pairs(m_players) do
        local data = Player.GetTeamData(pInfo.entity)
        if data and data.selected_hero_id then
            if pInfo.team == 2 then 
                table.insert(radiant, data.selected_hero_id)
            elseif pInfo.team == 3 then 
                table.insert(dire, data.selected_hero_id) 
            end
        end
    end
    
    test.updateTeamSettings()
    print("[bh_helper] скрипт готов")
    
    local isCustom = (ggMessageSelect:Get() == #ggMessages - 1)
    ggCustomMessage:Disabled(not isCustom)
end

function test.OnGameEnd()
    gameend = true
    ancientRad = nil
    ancientDir = nil
    throneBroken = false
    ggSent = false
end

function test.OnScriptUnload()
    init = false
    ancientRad, ancientDir = nil, nil
    ggSent = false
    throneBroken = false
    gameend = false
    reportBannerQueue = {}
    activeReportBanner = nil
    radiant, dire = {}, {}
    reportedPlayers = {}
    reportQueue = {}
    accountIdCache = {}
    m_players = {}
end

return test