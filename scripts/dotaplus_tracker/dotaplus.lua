local STRATZ_TOKEN = "API HERE"

local script = {}

local chronos
pcall(function() chronos = require("chronos") end)
local JSON
pcall(function() JSON = require("assets.JSON") end)

local function timeNow() return chronos and chronos.nanotime and chronos.nanotime() or os.clock() end
local function unixNow() return os and os.time and os.time() or math.floor(os.clock()) end

local function toNum(v, def) return type(v) == "number" and v or (def or 0) end
local function formatVal(v, digits)
    if v == nil then return "-" end
    if digits and digits > 0 then return string.format("%." .. digits .. "f", v) end
    return tostring(math.floor(v + 0.5))
end

local function formatShort(v)
    if v == nil then return "-" end
    v = toNum(v)
    local absVal = math.abs(v)
    if absVal >= 1000000 then return string.format("%.1fm", v / 1000000) end
    if absVal >= 10000 then return string.format("%.1fk", v / 1000) end
    return tostring(math.floor(v + 0.5))
end

local function lerp(a, b, t)
    if a == nil and b == nil then return nil end
    if a == nil then return b end
    if b == nil then return a end
    return a + (b - a) * t
end

local mainMenu = Menu.Create("Info Screen", "Main")
local trackerTab = mainMenu:Create("Tracker")
trackerTab:Icon("\u{f201}")
local mainPage = trackerTab:Create("Main")
local settings = mainPage:Create("Settings")

local cfg = {}
cfg.enabled = settings:Switch("Enable", true, "\u{f201}")
cfg.enabled:ToolTip("Enables HUD and auto-update of STRATZ cache")

local rankNames = { "All ranks", "Herald/Guardian", "Crusader/Archon", "Legend/Ancient", "Divine/Immortal" }
local rankKeys = { "ALL", "HERALD_GUARDIAN", "CRUSADER_ARCHON", "LEGEND_ANCIENT", "DIVINE_IMMORTAL" }
cfg.rank = settings:Combo("Filter by rank", rankNames, 4)

cfg.useRole = settings:Switch("Filter by position", false)
local roleNames = { "Carry (Pos 1)", "Mid (Pos 2)", "Offlane (Pos 3)", "Soft Support (Pos 4)", "Hard Support (Pos 5)" }
local roleKeys = { "POSITION_1", "POSITION_2", "POSITION_3", "POSITION_4", "POSITION_5" }
cfg.role = settings:Combo("Filter by role", roleNames, 1)

cfg.statusLabel = settings:Label("STRATZ: waiting for game", "\u{f1c0}")

cfg.custom = settings:Label("Customization")
cfg.gear = cfg.custom:Gear("Settings")
cfg.x = cfg.gear:Slider("HUD X", -10, 1200, 0, "%d")
cfg.y = cfg.gear:Slider("HUD Y", -5, 800, 120, "%d")
cfg.scale = cfg.gear:Slider("Scale", 70, 200, 100, "%d%%")
cfg.showKda = cfg.gear:Switch("Show K/D/A", true)
cfg.showCs = cfg.gear:Switch("Show LH/DN", true)
cfg.showNw = cfg.gear:Switch("Show NETWORTH", true)
cfg.showGpm = cfg.gear:Switch("Show GPM", true)
cfg.showXpm = cfg.gear:Switch("Show XPM", true)
cfg.showPerf = cfg.gear:Switch("Show performance", false)
cfg.showShadow = cfg.gear:Switch("Text shadow", true)
cfg.glow = cfg.gear:Switch("Glow effect", true)

local function updateMenuVis() pcall(function() cfg.role:Visible(cfg.useRole:Get()) end) end

local fontReg  = Render.LoadFont("Arial", 0, 400)
local fontBold = Render.LoadFont("Arial", 0, 700)
local fontMini = Render.LoadFont("Arial", 0, 500)
local fontBig  = Render.LoadFont("Arial", 0, 900)

local colors = {
    text       = Color(240, 246, 255, 255),
    dim        = Color(140, 165, 195, 255),
    label      = Color(180, 205, 230, 255),
    accent     = Color(100, 180, 255, 255),
    accentSoft = Color(80, 140, 220, 200),
    green      = Color(80, 230, 150, 255),
    greenSoft  = Color(50, 180, 110, 255),
    red        = Color(250, 90, 110, 255),
    redSoft    = Color(200, 60, 80, 255),
    gray       = Color(140, 150, 170, 255),
    shadow     = Color(0, 0, 0, 180),
    shadowSoft = Color(0, 0, 0, 100),
    glow       = Color(100, 180, 255, 90),
    stateGood  = Color(80, 230, 150, 255),
    stateBad   = Color(250, 90, 110, 255),
    stateMid   = Color(255, 200, 80, 255),
    bar        = Color(60, 130, 220, 255),
    barBg      = Color(40, 50, 70, 255),
    hero       = Color(255, 200, 100, 255),
    time       = Color(180, 220, 255, 255),
}


local cacheName = "tracker_stratz_v2"
local cacheTTL = 100000
local appCache = { hero = {}, meta = {} }
local isCacheLoaded = false
local requestInFlight = false
local activeKey = nil
local nextRetryTime = 0

local function setStatus(txt) pcall(function() cfg.statusLabel:Name(txt) end) end
local function getSelectedRank() return rankKeys[cfg.rank:Get() + 1] or "DIVINE_IMMORTAL" end
local function getSelectedRole() return cfg.useRole:Get() and (roleKeys[cfg.role:Get() + 1] or "ALL") or "ALL" end
local function getToken() return tostring(STRATZ_TOKEN or ""):gsub("^%s+", ""):gsub("%s+$", "") end

local function loadCache()
    if isCacheLoaded then return end
    isCacheLoaded = true
    if not JSON or not Config then setStatus("err json/cfg") return end

    local raw = Config.ReadString(cacheName, "data", "")
    if raw and raw ~= "" then
        local ok, decoded = pcall(function() return JSON:decode(raw) end)
        if ok and decoded then
            appCache.hero = decoded.hero or {}
            appCache.meta = decoded.meta or {}
            setStatus("cache loaded")
            return
        end
    end
    setStatus("cache empty")
end

local function saveCache()
    if not JSON or not Config then return end
    local ok, encoded = pcall(function() return JSON:encode(appCache) end)
    if ok and encoded then Config.WriteString(cacheName, "data", encoded) end
end

local function makeCacheKey(heroName, rank, role)
    return tostring(heroName or "unknown") .. "|" .. tostring(rank or "ALL") .. "|" .. tostring(role or "ALL")
end

local function getLocalHero()
    local hero = Heroes.GetLocal()
    if not hero or not Entity.IsNPC(hero) then return nil, 0 end
    local name = NPC.GetUnitName(hero)
    return name, Engine.GetHeroIDByName(name) or 0
end

local function countKeys(tbl)
    local n = 0
    for _ in pairs(tbl or {}) do n = n + 1 end
    return n
end

local state = { current = nil, bench = nil, diff = nil, lastUpdate = 0, lastPanScan = 0, panScanCount = 0 }
local perf = { avg = 0, min = 9999, max = 0, samples = 0, pendingMs = 0, lastTotal = 0, text = "s 0 ms | a 0 | m 0 | x 0", nextUpdate = 0 }

local function perfPush(ms)
    ms = math.max(0, toNum(ms))
    perf.samples = perf.samples + 1
    if perf.samples == 1 then
        perf.avg, perf.min, perf.max = ms, ms, ms
    else
        perf.avg = perf.avg * 0.96 + ms * 0.04
        if ms < perf.min then perf.min = ms end
        if ms > perf.max then perf.max = ms end
    end
    if perf.samples > 1800 then
        perf.samples = 1
        perf.min, perf.max, perf.avg = ms, ms, ms
    end
end

local function collectLiveData(heroName, heroId)
    if not Engine.IsInGame() then return nil end
    local player = Players.GetLocal()
    local hero = Heroes.GetLocal()
    if not player or not hero then return nil end

    local gameTime = toNum(GameRules.GetGameTime())
    local preStart = toNum(GameRules.GetPreGameStartTime())

    if preStart <= 0 then preStart = gameTime end

    local totalDuration = math.max(1.0, gameTime - preStart) / 60.0

    local teamData = Player.GetTeamData(player) or {}
    local teamPlayer = Player.GetTeamPlayer(player) or {}
    heroName = heroName or NPC.GetUnitName(hero) or "unknown"
    heroId = heroId or Engine.GetHeroIDByName(heroName) or 0

    local totalGold = toNum(teamPlayer.totalearned_gold)
    if totalGold <= 0 then totalGold = toNum(Player.GetTotalGold(player)) end
    local networth = toNum(teamPlayer.networth)
    local safeGold = networth > 0 and networth or totalGold
    local totalXp = toNum(teamPlayer.totalearned_xp)

    return {
        heroName = heroName, heroId = heroId, gameTime = gameTime,
        stratzMins = totalDuration,
        gameMins = totalDuration,
        k = toNum(teamData.kills), d = toNum(teamData.deaths), a = toNum(teamData.assists),
        lh = toNum(teamPlayer.lasthit_count), dn = toNum(teamPlayer.deny_count),
        gold = safeGold, gpm = safeGold / totalDuration,
        xp = totalXp, xpm = totalXp / totalDuration,
        rank = getSelectedRank(), role = getSelectedRole()
    }
end

local function isCacheFresh(heroName, rank, role)
    local targetKey = rank .. "_" .. role
    local heroCache = appCache.hero[heroName] and appCache.hero[heroName][targetKey]
    if not heroCache then return false end

    local meta = appCache.meta[makeCacheKey(heroName, rank, role)]
    if not meta or not meta.updatedAt then return false end
    if unixNow() - toNum(meta.updatedAt) > cacheTTL then return false end

    return countKeys(heroCache) >= 5
end

local function buildQuery(heroId, rank, role)
    local args = string.format("heroIds: [%d]", heroId)

    if not rank or rank == "ALL" then
        args = args .. ", bracketBasicIds: [HERALD_GUARDIAN, CRUSADER_ARCHON, LEGEND_ANCIENT, DIVINE_IMMORTAL]"
    else
        args = args .. string.format(", bracketBasicIds: [%s]", rank)
    end

    if role and role ~= "ALL" then
        args = args .. string.format(", positionIds: [%s]", role)
    end

    args = args .. ", groupByTime: true, minTime: 0, maxTime: 60"

    return string.format([[query {
  heroStats {
    stats(%s) {
      time
      matchCount
      kills
      deaths
      assists
      cs
      dn
      networth
      xp
      goldPerMinute
    }
  }
}]], args)
end

local function fetchStratz(heroName, heroId, rank, role)
    if requestInFlight then return end
    if not JSON or not HTTP or not HTTP.Request then setStatus("no http") return end
    local token = getToken()
    if token == "" then setStatus("no tok") return end
    if not heroName or heroId <= 0 or os.clock() < nextRetryTime then return end

    requestInFlight = true
    setStatus("downloading " .. role)

    HTTP.Request("POST", "https://api.stratz.com/graphql", {
        headers = {
            ["Authorization"] = "Bearer " .. token,
            ["Content-Type"] = "application/json",
            ["Accept"] = "application/json",
            ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36"
        },
        data = JSON:encode({ query = buildQuery(heroId, rank, role) }),
        timeout = 60
    }, function(res)
        requestInFlight = false
        local raw = res and res.response or ""

        if raw:find("cloudflare") or raw:find("<!DOC") then
            nextRetryTime = os.clock() + 60
            setStatus("cf block")
            return
        end

        local ok, decoded = pcall(function() return JSON:decode(raw) end)
        if not ok or not decoded then
            nextRetryTime = os.clock() + 60
            setStatus("json error")
            return
        end

        if decoded.errors then
            nextRetryTime = os.clock() + 60
            local msg = decoded.errors[1] and decoded.errors[1].message or "GraphQL error"
            setStatus("err: " .. msg:sub(1, 40))
            return
        end

        local rows = decoded.data and decoded.data.heroStats and decoded.data.heroStats.stats or {}
        if #rows == 0 then
            nextRetryTime = os.clock() + 60
            setStatus("check api key in 1st line of script")
            return
        end

        appCache.hero[heroName] = appCache.hero[heroName] or {}
        local targetKey = rank .. "_" .. role
        appCache.hero[heroName][targetKey] = {}
        local target = appCache.hero[heroName][targetKey]

        for _, r in ipairs(rows) do
            local m = toNum(r.time)
            if m > 100 then m = math.floor(m / 60) else m = math.floor(m) end
            target[tostring(m)] = {
                sample = toNum(r.matchCount),
                k = r.kills, d = r.deaths, a = r.assists,
                lh = r.cs, dn = r.dn,
                gold = r.networth,
                xp = r.xp and toNum(r.xp) or nil
            }
        end

        appCache.meta[makeCacheKey(heroName, rank, role)] = { updatedAt = unixNow(), src = "stratz" }
        saveCache()
        setStatus("min: " .. #rows)
    end, "stratz_req")
end

local function checkCache(heroName, heroId, rank, role)
    loadCache()
    if not heroName or heroId <= 0 then return end

    local key = makeCacheKey(heroName, rank, role)
    if not isCacheFresh(heroName, rank, role) then
        fetchStratz(heroName, heroId, rank, role)
    elseif activeKey ~= key then
        setStatus("cache fresh " .. role)
    end
    activeKey = key
end

local function interpolatePoint(tbl, cur)
    if not tbl or not cur then return nil end
    local lo = math.floor(cur.stratzMins)
    local hi = lo + 1
    local pA = tbl[tostring(lo)]
    local pB = tbl[tostring(hi)]

    if not pA and not pB then
        for i = lo, 0, -1 do
            if tbl[tostring(i)] then return tbl[tostring(i)] end
        end
        return nil
    end

    if not pA then pA = pB end
    if not pB then pB = pA end

    local fraction = cur.stratzMins - lo
    local out = {
        sample = pA.sample or pB.sample,
        k = lerp(pA.k, pB.k, fraction), d = lerp(pA.d, pB.d, fraction), a = lerp(pA.a, pB.a, fraction),
        lh = lerp(pA.lh, pB.lh, fraction), dn = lerp(pA.dn, pB.dn, fraction),
        gold = lerp(pA.gold, pB.gold, fraction),
        xp = lerp(pA.xp, pB.xp, fraction)
    }

    out.gpm = out.gold and (out.gold / cur.gameMins) or nil
    out.xpm = out.xp and (out.xp / cur.gameMins) or nil

    return out
end

local function getBenchmark(cur)
    local byHero = appCache.hero[cur.heroName]
    return interpolatePoint(byHero and byHero[cur.rank .. "_" .. cur.role], cur)
end

local function calcDiff(cur, bench)
    if not bench then return {} end
    return {
        usp = (bench.k and bench.d and bench.a) and (cur.k + cur.a - cur.d) - (toNum(bench.k) + toNum(bench.a) - toNum(bench.d)) or nil,
        lh = (bench.lh and bench.dn) and (cur.lh + cur.dn) - (toNum(bench.lh) + toNum(bench.dn)) or nil,
        gold = bench.gold and (cur.gold - toNum(bench.gold)) or nil,
        gpm = bench.gpm and (cur.gpm - toNum(bench.gpm)) or nil,
        xpm = bench.xpm and (cur.xpm - toNum(bench.xpm)) or nil,
    }
end

local panoramaTargets = { "QuickStats", "quickstats", "QuickStatsContainer", "quickstats_container", "DOTAQuickStats", "TopBarStats", "LHContainer" }
local function hidePanorama()
    if not Panorama or not Panorama.GetPanelByName then return end
    if state.panScanCount >= 6 or os.clock() - state.lastPanScan < 2 then return end

    state.lastPanScan = os.clock()
    state.panScanCount = state.panScanCount + 1

    for _, id in ipairs(panoramaTargets) do
        local p = Panorama.GetPanelByName(id, false)
        if p and p.IsValid and p:IsValid() then p:SetVisible(false) end
    end
end

-- Vẽ tam giác — thử 7 tham số trước, fallback mảng Vec2
local function fillTri(x1, y1, x2, y2, x3, y3, color)
    local ok = pcall(function()
        Render.FilledTriangle(x1, y1, x2, y2, x3, y3, color)
    end)
    if not ok then
        pcall(function()
            Render.FilledTriangle({ Vec2(x1, y1), Vec2(x2, y2), Vec2(x3, y3) }, color)
        end)
    end
end

local function drawTriangle(x, y, isUp, color, size)
    if isUp then
        fillTri(x,           y + size,
                x + size * 0.5, y,
                x + size,       y + size, color)
    else
        fillTri(x,           y,
                x + size,       y,
                x + size * 0.5, y + size, color)
    end
end


-- Vẽ text có viền đen (4 hướng) + shadow nhẹ
local function textOutlined(font, size, str, pos, color)
    local oc = Color(0, 0, 0, 220)
    -- 4 hướng outline
    Render.Text(font, size, str, Vec2(pos.x - 1, pos.y),     oc)
    Render.Text(font, size, str, Vec2(pos.x + 1, pos.y),     oc)
    Render.Text(font, size, str, Vec2(pos.x,     pos.y - 1), oc)
    Render.Text(font, size, str, Vec2(pos.x,     pos.y + 1), oc)
    -- 4 góc cho dày hơn
    Render.Text(font, size, str, Vec2(pos.x - 1, pos.y - 1), oc)
    Render.Text(font, size, str, Vec2(pos.x + 1, pos.y - 1), oc)
    Render.Text(font, size, str, Vec2(pos.x - 1, pos.y + 1), oc)
    Render.Text(font, size, str, Vec2(pos.x + 1, pos.y + 1), oc)
    -- text chính vẽ cuối (đè lên trên)
    Render.Text(font, size, str, pos, color)
end

local function drawHud(cur, bench, diff)
    local s = cfg.scale:Get() / 100
    local x, y = cfg.x:Get(), cfg.y:Get()
    -- Tăng khoảng cách giữa các cột để value & goal không đè mũi tên
    local labelX = x + 16 * s      -- lùi vào 2px
    local valX   = x + 90 * s
    local goalX  = x + 170 * s     -- xa hơn 10px (160 → 170)
    local arrowX = x + 255 * s     -- xa hơn 25px (220 → 285) - chắc chắn không đè
    local rowH   = 23 * s
    local curY   = y + 18 * s      -- lùi xuống 16px để chừa chỗ cho "Goal" header

    -- ===== NỀN TỐI =====
    local pad = 6 * s

    -- đếm số dòng hiển thị
    local rowCount = 0
    if cfg.showKda:Get() then rowCount = rowCount + 1 end
    if cfg.showCs:Get()  then rowCount = rowCount + 1 end
    if cfg.showNw:Get()  then rowCount = rowCount + 1 end
    if cfg.showGpm:Get() then rowCount = rowCount + 1 end
    if cfg.showXpm:Get() then rowCount = rowCount + 1 end

    local bgX = x - pad
    local bgY = y - 4 * s             -- thu nhỏ padding trên vì curY đã lùi xuống
    local bgW = 270 * s + pad * 2    -- khớp arrowX mới (285 + size arrow ~14)            -- phải khớp arrowX = x + 260 + size arrow
    local bgH = rowCount * 23 * s + 22 * s + pad * 2   -- giảm 8 vì curY đã +18
    if cfg.showPerf:Get() then bgH = bgH + 14 * s end

    -- Lớp nền tối (1 hình chữ nhật = 2 tam giác)
    local bgColor = Color(10, 15, 25, 140)
    fillTri(bgX,        bgY,
            bgX + bgW,  bgY,
            bgX,        bgY + bgH, bgColor)
    fillTri(bgX + bgW,  bgY,
            bgX + bgW,  bgY + bgH,
            bgX,        bgY + bgH, bgColor)

    -- Viền trên accent (1 hình chữ nhật nhỏ = 2 tam giác)
    fillTri(bgX,        bgY,
            bgX + bgW,  bgY,
            bgX + bgW,  bgY + 2 * s, colors.accent)
    fillTri(bgX,        bgY,
            bgX + bgW,  bgY + 2 * s,
            bgX,        bgY + 2 * s, colors.accent)

    -- Viền dưới mờ (cho cân)
    fillTri(bgX,        bgY + bgH - 1 * s,
            bgX + bgW,  bgY + bgH - 1 * s,
            bgX + bgW,  bgY + bgH, colors.accentSoft)
    fillTri(bgX,        bgY + bgH - 1 * s,
            bgX + bgW,  bgY + bgH,
            bgX,        bgY + bgH, colors.accentSoft)


    if cfg.showKda:Get() or cfg.showCs:Get() or cfg.showNw:Get() or cfg.showGpm:Get() or cfg.showXpm:Get() then
        -- Header 2 cột: "current" trên cột value, "GOAL" trên cột goal
        textOutlined(fontBold, 12 * s, "CURRENT",
            Vec2(valX, y + 1 * s),
            Color(255, 130, 100, 255))   -- cam/đỏ nhạt
        textOutlined(fontBold, 12 * s, "GOAL",
            Vec2(goalX, y + 1 * s),
            colors.accent)                  -- xanh dương
    end


    local function drawRow(label, val, goal, rowDiff)
        Render.Text(fontBold, 17 * s, label, Vec2(labelX, curY), colors.label)

        -- Tính màu value dựa trên so sánh val vs goal (parse thành số)
        local valColor = colors.text   -- mặc định trắng
        local isGood
        if goal and goal ~= "" and goal ~= "-" and val and val ~= "" then
            -- Parse số từ string (bỏ dấu phẩy, k, m)
            local function parseNum(s)
                s = tostring(s):gsub(",", ""):gsub("%s", "")
                local mult = 1
                if s:sub(-1) == "k" then mult = 1000; s = s:sub(1, -2) end
                if s:sub(-1) == "m" then mult = 1000000; s = s:sub(1, -2) end
                return tonumber(s) and tonumber(s) * mult or nil
            end
            local vNum = parseNum(val)
            local gNum = parseNum(goal)
            if vNum and gNum then
                if vNum >= gNum then
                    valColor = colors.green
                    isGood = true
                else
                    valColor = colors.red
                    isGood = false
                end
            end
        end

        -- Vẽ value với màu mới
        Render.Text(fontBold, 17 * s, val, Vec2(valX, curY), valColor)
        Render.Text(fontBold, 16 * s, goal, Vec2(goalX, curY + 1 * s), colors.text)

        -- Mũi tên giữ logic cũ (vẫn dùng rowDiff)
        local arrowColor = rowDiff == nil and (val == goal and colors.green or colors.gray) or (isGood and colors.green or colors.red)

        drawTriangle(arrowX, curY + 6 * s, isGood, arrowColor, 16 * s)
        curY = curY + rowH
    end


    if cfg.showKda:Get() then
        local goalStr = bench and string.format("%s/%s/%s", formatVal(bench.k, 0), formatVal(bench.d, 0), formatVal(bench.a, 0)) or "-/-/-"
        drawRow("K/D/A", string.format("%d/%d/%d", cur.k, cur.d, cur.a), goalStr, diff.usp)
    end
    if cfg.showCs:Get() then
        local goalStr = bench and (formatVal(bench.lh, 0) .. "/" .. formatVal(bench.dn, 0)) or "-/-"
        drawRow("LH/DN", string.format("%d/%d", cur.lh, cur.dn), goalStr, diff.lh)
    end
    if cfg.showNw:Get() then drawRow("NET", formatVal(cur.gold, 0), bench and formatVal(bench.gold, 0) or "-", diff.gold) end
    if cfg.showGpm:Get() then drawRow("GPM", formatVal(cur.gpm, 0), bench and formatVal(bench.gpm, 0) or "-", diff.gpm) end
    if cfg.showXpm:Get() then drawRow("XPM", formatVal(cur.xpm, 0), bench and formatVal(bench.xpm, 0) or "-", diff.xpm) end

    if cfg.showPerf:Get() then
        textOutlined(fontReg, 10 * s, perf.text, Vec2(labelX, curY + 4 * s), colors.dim)
    end
end

function script.OnUpdate()
    local t0 = timeNow()
    loadCache()

    if not cfg.enabled:Get() then
        state.current, state.bench, state.diff = nil, nil, nil
        return
    end

    updateMenuVis()
    hidePanorama()

    local function finishUpdate()
        perf.pendingMs = perf.pendingMs + (timeNow() - t0) * 1000
    end

    local now = os.clock()
    if now - state.lastUpdate < 0.5 then
        finishUpdate()
        return
    end
    state.lastUpdate = now

    local heroName, heroId = getLocalHero()
    local liveData = collectLiveData(heroName, heroId)

    if not liveData then
        state.current, state.bench, state.diff = nil, nil, nil
        finishUpdate()
        return
    end

    checkCache(liveData.heroName, liveData.heroId, liveData.rank, liveData.role)
    local benchData = getBenchmark(liveData)

    state.current = liveData
    state.bench = benchData
    state.diff = calcDiff(liveData, benchData)

    finishUpdate()
end

function script.OnDraw()
    local t0 = timeNow()
    if not cfg.enabled:Get() or not state.current then return end

    drawHud(state.current, state.bench, state.diff or {})

    local drawTime = (timeNow() - t0) * 1000
    local totalTime = drawTime + perf.pendingMs
    perf.pendingMs = 0
    perf.lastTotal = totalTime
    perfPush(totalTime)

    local now = os.clock()
    if now >= perf.nextUpdate then
        perf.nextUpdate = now + 0.25
        perf.text = string.format("script %.3f ms | avg %.3f | min %.3f | max %.3f", perf.lastTotal, perf.avg, perf.min, perf.max)
    end
end

function script.OnGameEnd()
    state.current, state.bench, state.diff = nil, nil, nil
    state.panScanCount = 0
    perf.avg, perf.min, perf.max, perf.samples, perf.pendingMs, perf.lastTotal = 0, 9999, 0, 0, 0, 0
    perf.text = "script 0.000 ms | avg 0.000 | min 0.000 | max 0.000"
    perf.nextUpdate = 0
end

return script
