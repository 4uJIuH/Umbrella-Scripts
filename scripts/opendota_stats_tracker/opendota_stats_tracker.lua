local chronos = require("chronos")
local JSON = require("assets.JSON")

local function time_now()
	return chronos and chronos.nanotime and chronos.nanotime()
end

local function to_num(value, default)
	return type(value) == "number" and value or (default or 0)
end

local function format_val(value)
	if value == nil then
		return "-"
	end

	return tostring(math.floor(value + 0.5))
end

local function lerp(a, b, t)
	if a == nil and b == nil then
		return nil
	end

	if a == nil then
		return b
	end

	if b == nil then
		return a
	end

	return a + (b - a) * t
end

local function count_keys(tbl)
	local n = 0
	for _ in pairs(tbl or {}) do
		n = n + 1
	end

	return n
end

local Tracker = {
	cache_dir = Engine.GetCheatDirectory() .. "/scripts",
	cache_version = 1,
	minute_cap = 60,
	min_duration = 900,
	target_matches = 20,
	page_size = 10,
	page_delay = 1.0,
	refresh_interval = 6 * 3600,
	update_interval = 0.5,
	api_base = "https://api.opendota.com/api",
	user_agent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36",
	explorer_sql = "SELECT pm.match_id, pm.kills, pm.deaths, pm.assists, pm.gold_t, pm.xp_t, pm.lh_t, pm.dn_t, m.duration, m.game_mode FROM player_matches pm JOIN matches m ON pm.match_id = m.match_id WHERE pm.hero_id = %d AND pm.gold_t IS NOT NULL AND pm.leaver_status = 0 AND m.duration >= %d AND m.game_mode IN (1,2,3,4,5,12,16,22) ORDER BY pm.match_id DESC LIMIT %d OFFSET %d",
	panorama_targets = {
		"QuickStats",
		"quickstats",
		"QuickStatsContainer",
		"quickstats_container",
		"DOTAQuickStats",
		"TopBarStats",
		"LHContainer",
	},
}

function Tracker:Init()
	local main = Menu.Create("Info Screen", "Main")

	self.tab = main:Create("Tracker")
	self.tab:Icon("\u{f201}")

	self.menu = self.tab:Create("Main"):Create("Settings")

	self.enable = self.menu:Switch("Enable", true, "\u{f201}")
	self.enable:ToolTip("Enables HUD and auto-update of OpenDota benchmarks")

	self.status = self.menu:Label("OpenDota: waiting for game", "\u{f1c0}")

	self.customization = self.menu:Label("Customization")
	self.customization_gear = self.customization:Gear("Settings")

	self.hud_x = self.customization_gear:Slider("HUD X", -10, 1200, 0, "%d")
	self.hud_y = self.customization_gear:Slider("HUD Y", -5, 800, 120, "%d")
	self.hud_scale = self.customization_gear:Slider("Scale", 70, 200, 100, "%d%%")
	self.show_kda = self.customization_gear:Switch("Show K/D/A", true)
	self.show_cs = self.customization_gear:Switch("Show LH/DN", true)
	self.show_nw = self.customization_gear:Switch("Show NETWORTH", true)
	self.show_gpm = self.customization_gear:Switch("Show GPM", true)
	self.show_xpm = self.customization_gear:Switch("Show XPM", true)
	self.show_perf = self.customization_gear:Switch("Show performance", false)
	self.show_shadow = self.customization_gear:Switch("Text shadow", true)
	self.show_glow = self.customization_gear:Switch("Glow effect", true)
	self.debug = self.customization_gear:Switch("Debug logging", true)

	self.font = Render.LoadFont("Arial", 0, 400)
	self.font_bold = Render.LoadFont("Arial", 0, 700)

	self.colors = {
		text = Color(240, 246, 255, 255),
		dim = Color(140, 165, 195, 255),
		label = Color(180, 205, 230, 255),
		accent = Color(100, 180, 255, 255),
		accent_soft = Color(80, 140, 220, 200),
		current = Color(255, 130, 100, 255),
		green = Color(80, 230, 150, 255),
		red = Color(250, 90, 110, 255),
		gray = Color(140, 150, 170, 255),
		background = Color(10, 15, 25, 140),
		outline = Color(0, 0, 0, 220),
	}

	self.heroes = {}
	self.benchmarks = {}
	self.storage_ready = nil
	self.current_patch = nil
	self.patch_tried = false

	self.dl = {
		in_flight = false,
		next_at = 0,
		hero_name = nil,
		failures = 0,
		note = nil,
		build = nil,
	}

	self.state = {
		current = nil,
		bench = nil,
		diff = nil,
		last_update = 0,
		pan_scans = 0,
		last_pan_scan = 0,
	}

	self.perf = {
		avg = 0,
		min = 9999,
		max = 0,
		samples = 0,
		pending_ms = 0,
		last_total = 0,
		text = "script 0.000 ms | avg 0.000 | min 0.000 | max 0.000",
		next_update = 0,
	}
end

function Tracker:SetStatus(text)
	self.status:Name(text)
end

function Tracker:Log(fmt, ...)
	if self.debug and not self.debug:Get() then
		return
	end

	local ok, line = pcall(string.format, fmt, ...)
	if not ok then
		line = tostring(fmt)
	end

	line = string.format("[%s] %s", os.date("%H:%M:%S"), line)

	print("[dotaplus] " .. line)
end

function Tracker:ReadFile(path)
	local ok, data = pcall(function()
		local file = io.open(path, "r")
		if not file then
			return nil
		end

		local content = file:read("*a")
		file:close()
		return content
	end)

	return ok and data or nil
end

function Tracker:WriteFile(path, data)
	local ok, written = pcall(function()
		local file = io.open(path, "w")
		if not file then
			return false
		end

		file:write(data)
		file:close()
		return true
	end)

	return ok and written or false
end

function Tracker:InitStorage()
	if self.storage_ready ~= nil then
		return self.storage_ready
	end

	local probe = self.cache_dir .. "/probe.tmp"

	if self:WriteFile(probe, "ok") then
		pcall(os.remove, probe)
		self.storage_ready = true
		return true
	end

	if self:WriteFile(probe, "ok") then
		pcall(os.remove, probe)
		self.storage_ready = true
		return true
	end

	self.storage_ready = false
	return false
end

function Tracker:HeroFile(hero_name)
	return self.cache_dir .. "/" .. tostring(hero_name):gsub("[^%w_]", "") .. ".json"
end

function Tracker:GetHeroEntry(hero_name)
	local entry = self.heroes[hero_name]
	if entry then
		return entry
	end

	local raw
	if self:InitStorage() then
		raw = self:ReadFile(self:HeroFile(hero_name))
	end

	if JSON and raw and raw ~= "" then
		local ok, decoded = pcall(function() return JSON:decode(raw) end)
		if ok and type(decoded) == "table" and to_num(decoded.version) == self.cache_version then
			entry = decoded
		end
	end

	if not entry then
		entry = {
			acc = {},
			sample_count = 0,
			updated_at = 0,
			checked_at = 0,
		}
	end

	entry.acc = entry.acc or {}
	self.heroes[hero_name] = entry
	return entry
end

function Tracker:SaveHeroEntry(hero_name)
	local entry = self.heroes[hero_name]
	if not entry or not JSON then
		return
	end

	entry.version = self.cache_version

	local ok, encoded = pcall(function() return JSON:encode(entry) end)
	if not ok or not encoded then
		return
	end

	if self:InitStorage() then
		self:WriteFile(self:HeroFile(hero_name), encoded)
	end
end

function Tracker:IsEntryFresh(entry)
	if os.time() - to_num(entry.checked_at) >= self.refresh_interval then
		return false
	end

	if self.current_patch and entry.patch ~= self.current_patch then
		return false
	end

	return true
end

function Tracker:RebuildBenchmark(hero_name)
	local entry = self.heroes[hero_name]
	if not entry or not entry.acc then
		self.benchmarks[hero_name] = nil
		return
	end

	local bench = {}
	for minute, bucket in pairs(entry.acc) do
		local n = to_num(bucket.n)
		if n > 0 then
			bench[minute] = {
				sample = n,
				k = to_num(bucket.k) / n,
				d = to_num(bucket.d) / n,
				a = to_num(bucket.a) / n,
				lh = to_num(bucket.lh) / n,
				dn = to_num(bucket.dn) / n,
				gold = to_num(bucket.gold) / n,
				xp = to_num(bucket.xp) / n,
			}
		end
	end

	self.benchmarks[hero_name] = count_keys(bench) > 0 and bench or nil
end

function Tracker:IngestRow(acc, row)
	if type(row) ~= "table" then
		return false
	end

	local gold_t, xp_t, lh_t, dn_t = row.gold_t, row.xp_t, row.lh_t, row.dn_t
	if type(gold_t) ~= "table" or type(xp_t) ~= "table" or type(lh_t) ~= "table" then
		return false
	end

	local duration_min = to_num(row.duration) / 60.0
	local max_minute = math.min(math.floor(duration_min), self.minute_cap)
	if max_minute < 15 or #gold_t < max_minute then
		return false
	end

	local kills, deaths, assists = to_num(row.kills), to_num(row.deaths), to_num(row.assists)
	local ingested = false

	for minute = 0, max_minute do
		local gold, xp, lh = gold_t[minute + 1], xp_t[minute + 1], lh_t[minute + 1]
		if type(gold) == "number" and type(xp) == "number" and type(lh) == "number" then
			local key = tostring(minute)
			local bucket = acc[key]
			if not bucket then
				bucket = { n = 0, k = 0, d = 0, a = 0, lh = 0, dn = 0, gold = 0, xp = 0 }
				acc[key] = bucket
			end

			local progress = duration_min > 0 and math.min(1, minute / duration_min) or 0
			bucket.n = bucket.n + 1
			bucket.k = bucket.k + kills * progress
			bucket.d = bucket.d + deaths * progress
			bucket.a = bucket.a + assists * progress
			bucket.lh = bucket.lh + lh
			bucket.dn = bucket.dn + to_num(type(dn_t) == "table" and dn_t[minute + 1] or nil, 0)
			bucket.gold = bucket.gold + gold
			bucket.xp = bucket.xp + xp
			ingested = true
		end
	end

	return ingested
end

function Tracker:Backoff(message)
	self.dl.failures = math.min(self.dl.failures + 1, 6)
	self.dl.next_at = os.clock() + math.min(300, 10 * 2 ^ self.dl.failures)
	self.dl.note = message
end

function Tracker:UrlEncode(value)
	return (tostring(value):gsub("[^%w%-%_%.%~]", function(char)
		return string.format("%%%02X", string.byte(char))
	end))
end

function Tracker:DecodeResponse(raw)
	if type(raw) ~= "string" or raw == "" then
		return nil, "empty response"
	end

	if raw:find("<!DOC") or raw:find("<html") then
		return nil, "html response"
	end

	local ok, decoded = pcall(function() return JSON:decode(raw) end)
	if not ok or type(decoded) ~= "table" then
		return nil, "invalid json"
	end

	if decoded.error then
		return nil, tostring(decoded.error):sub(1, 40)
	end

	if decoded.err then
		return nil, tostring(decoded.err):sub(1, 40)
	end

	return decoded, nil
end

function Tracker:HttpGet(url, tag, handler)
	self.dl.in_flight = true
	self:Log("%s request, url %d chars", tag, #url)

	HTTP.Request("GET", url, {
		headers = {
			["User-Agent"] = self.user_agent,
		},
		timeout = 60,
	}, function(response)
		self.dl.in_flight = false

		local raw = response and response.response or ""
		local meta = {}
		if type(response) == "table" then
			for key, value in pairs(response) do
				if key ~= "response" then
					meta[#meta + 1] = tostring(key) .. "=" .. tostring(value):sub(1, 60)
				end
			end
		end

		self:Log("%s response, body %d bytes%s%s", tag, #raw, #meta > 0 and (", " .. table.concat(meta, ", ")) or "", #raw > 0 and (", head: " .. raw:sub(1, 80):gsub("%s+", " ")) or "")

		handler(raw)
	end, tag)
end

function Tracker:FetchPatch()
	self.patch_tried = true
	self.dl.note = "checking patch"

	self:HttpGet(self.api_base .. "/constants/patch", "od_patch", function(raw)
		local decoded, err = self:DecodeResponse(raw)
		if not decoded or #decoded == 0 then
			self:Backoff("patch error: " .. tostring(err or "empty"))
			return
		end

		self.dl.failures = 0
		self.dl.note = nil

		local latest = decoded[#decoded]
		if type(latest) == "table" and latest.name then
			self.current_patch = tostring(latest.name)
		end

		self:Log("patch resolved: %s", tostring(self.current_patch))
	end)
end

function Tracker:StartBuild(hero_name, hero_id)
	self.dl.build = {
		hero_name = hero_name,
		hero_id = hero_id,
		page = 0,
		pages = math.ceil(self.target_matches / self.page_size),
		acc = {},
		ingested = 0,
		retries = 0,
	}

	self:Log("build start: %s (id %d), %d pages of %d", hero_name, hero_id, self.dl.build.pages, self.page_size)
	self:FetchPage()
end

function Tracker:FinishBuild(failed)
	local build = self.dl.build
	if not build then
		return
	end

	self.dl.build = nil

	local entry = self:GetHeroEntry(build.hero_name)
	entry.checked_at = os.time()
	entry.patch = self.current_patch or entry.patch

	if build.ingested > 0 then
		entry.acc = build.acc
		entry.sample_count = build.ingested
		entry.updated_at = os.time()
		self:RebuildBenchmark(build.hero_name)
		self.dl.note = failed and "partial bench" or nil
	else
		self.dl.note = failed and "dl failed" or "no valid matches"
	end

	self:SaveHeroEntry(build.hero_name)
	self:Log("build done: %s, %d matches ingested%s", build.hero_name, build.ingested, failed and " (with errors)" or "")
end

function Tracker:FetchPage()
	local build = self.dl.build
	if not build then
		return
	end

	self.dl.note = string.format("updating %d/%d", build.page + 1, build.pages)

	local sql = string.format(self.explorer_sql, build.hero_id, self.min_duration, self.page_size, build.page * self.page_size)

	self:HttpGet(self.api_base .. "/explorer?sql=" .. self:UrlEncode(sql), "od_page" .. build.page, function(raw)
		local decoded, err = self:DecodeResponse(raw)

		if not decoded or type(decoded.rows) ~= "table" then
			err = tostring(err or "no rows")
			build.retries = build.retries + 1
			self:Log("page %d failed (%s), retry %d/3", build.page, err, build.retries)

			if build.retries >= 3 then
				self:FinishBuild(true)
				self:Backoff("dl error: " .. err)
			else
				self.dl.next_at = os.clock() + 5 * build.retries
				self.dl.note = "retrying: " .. err
			end

			return
		end

		self.dl.failures = 0
		build.retries = 0

		local page_rows = 0
		for _, row in ipairs(decoded.rows) do
			page_rows = page_rows + 1
			if self:IngestRow(build.acc, row) then
				build.ingested = build.ingested + 1
			end
		end

		build.page = build.page + 1
		self:Log("page %d ok: %d rows, %d total ingested", build.page, page_rows, build.ingested)

		if build.page >= build.pages or page_rows < self.page_size then
			self:FinishBuild(false)
		else
			self.dl.next_at = os.clock() + self.page_delay
		end
	end)
end

function Tracker:DownloaderStep(hero_name, hero_id)
	if not JSON or not HTTP or not HTTP.Request then
		return
	end

	if not hero_name or hero_id <= 0 then
		return
	end

	if self.dl.in_flight or os.clock() < self.dl.next_at then
		return
	end

	if self.dl.hero_name ~= hero_name then
		self.dl.hero_name = hero_name
		self.dl.failures = 0
		self.dl.note = nil

		if self.dl.build and self.dl.build.hero_name ~= hero_name then
			self:Log("hero changed, dropping build for %s", self.dl.build.hero_name)
			self.dl.build = nil
		end
	end

	if self.dl.build then
		self:FetchPage()
		return
	end

	if not self.current_patch and not self.patch_tried then
		self:FetchPatch()
		return
	end

	if self:IsEntryFresh(self:GetHeroEntry(hero_name)) then
		return
	end

	self:StartBuild(hero_name, hero_id)
end

function Tracker:GetLocalHero()
	local hero = Heroes.GetLocal()
	if not hero or not Entity.IsNPC(hero) then
		return nil, 0
	end

	local name = NPC.GetUnitName(hero)
	return name, Engine.GetHeroIDByName(name) or 0
end

function Tracker:CollectLiveData(hero_name, hero_id)
	if not Engine.IsInGame() then
		return nil
	end

	local player = Players.GetLocal()
	local hero = Heroes.GetLocal()
	if not player or not hero then
		return nil
	end

	local game_time = to_num(GameRules.GetGameTime())
	local pre_start = to_num(GameRules.GetPreGameStartTime())
	if pre_start <= 0 then
		pre_start = game_time
	end

	local minutes = math.max(1.0, game_time - pre_start) / 60.0

	local team_data = Player.GetTeamData(player) or {}
	local team_player = Player.GetTeamPlayer(player) or {}

	hero_name = hero_name or NPC.GetUnitName(hero) or "unknown"
	hero_id = hero_id or Engine.GetHeroIDByName(hero_name) or 0

	local total_gold = to_num(team_player.totalearned_gold)
	if total_gold <= 0 then
		total_gold = to_num(Player.GetTotalGold(player))
	end

	local networth = to_num(team_player.networth)
	local gold = networth > 0 and networth or total_gold
	local xp = to_num(team_player.totalearned_xp)

	return {
		hero_name = hero_name,
		hero_id = hero_id,
		game_time = game_time,
		mins = minutes,
		k = to_num(team_data.kills),
		d = to_num(team_data.deaths),
		a = to_num(team_data.assists),
		lh = to_num(team_player.lasthit_count),
		dn = to_num(team_player.deny_count),
		gold = gold,
		gpm = gold / minutes,
		xp = xp,
		xpm = xp / minutes,
	}
end

function Tracker:Interpolate(bench, current)
	if not bench or not current then
		return nil
	end

	local lo = math.floor(current.mins)
	local hi = lo + 1
	local point_a = bench[tostring(lo)]
	local point_b = bench[tostring(hi)]

	if not point_a and not point_b then
		for minute = lo, 0, -1 do
			if bench[tostring(minute)] then
				return bench[tostring(minute)]
			end
		end

		return nil
	end

	if not point_a then
		point_a = point_b
	end

	if not point_b then
		point_b = point_a
	end

	local fraction = current.mins - lo
	local point = {
		sample = point_a.sample or point_b.sample,
		k = lerp(point_a.k, point_b.k, fraction),
		d = lerp(point_a.d, point_b.d, fraction),
		a = lerp(point_a.a, point_b.a, fraction),
		lh = lerp(point_a.lh, point_b.lh, fraction),
		dn = lerp(point_a.dn, point_b.dn, fraction),
		gold = lerp(point_a.gold, point_b.gold, fraction),
		xp = lerp(point_a.xp, point_b.xp, fraction),
	}

	point.gpm = point.gold and (point.gold / current.mins) or nil
	point.xpm = point.xp and (point.xp / current.mins) or nil

	return point
end

function Tracker:GetBenchmark(current)
	if not self.benchmarks[current.hero_name] and self.heroes[current.hero_name] then
		self:RebuildBenchmark(current.hero_name)
	end

	return self:Interpolate(self.benchmarks[current.hero_name], current)
end

function Tracker:CalcDiff(current, bench)
	if not bench then
		return {}
	end

	return {
		usp = (bench.k and bench.d and bench.a) and (current.k + current.a - current.d) - (to_num(bench.k) + to_num(bench.a) - to_num(bench.d)) or nil,
		lh = (bench.lh and bench.dn) and (current.lh + current.dn) - (to_num(bench.lh) + to_num(bench.dn)) or nil,
		gold = bench.gold and (current.gold - to_num(bench.gold)) or nil,
		gpm = bench.gpm and (current.gpm - to_num(bench.gpm)) or nil,
		xpm = bench.xpm and (current.xpm - to_num(bench.xpm)) or nil,
	}
end

function Tracker:HidePanorama()
	if not Panorama or not Panorama.GetPanelByName then
		return
	end

	if self.state.pan_scans >= 6 or os.clock() - self.state.last_pan_scan < 2 then
		return
	end

	self.state.last_pan_scan = os.clock()
	self.state.pan_scans = self.state.pan_scans + 1

	for _, id in ipairs(self.panorama_targets) do
		local panel = Panorama.GetPanelByName(id, false)
		if panel and panel.IsValid and panel:IsValid() then
			panel:SetVisible(false)
		end
	end
end

function Tracker:FillTriangle(x1, y1, x2, y2, x3, y3, color)
	local ok = pcall(function()
		Render.FilledTriangle(x1, y1, x2, y2, x3, y3, color)
	end)

	if not ok then
		pcall(function()
			Render.FilledTriangle({ Vec2(x1, y1), Vec2(x2, y2), Vec2(x3, y3) }, color)
		end)
	end
end

function Tracker:FillRect(x1, y1, x2, y2, color)
	self:FillTriangle(x1, y1, x2, y1, x1, y2, color)
	self:FillTriangle(x2, y1, x2, y2, x1, y2, color)
end

function Tracker:DrawArrow(x, y, is_up, color, size)
	if is_up then
		self:FillTriangle(x, y + size, x + size * 0.5, y, x + size, y + size, color)
	else
		self:FillTriangle(x, y, x + size, y, x + size * 0.5, y + size, color)
	end
end

function Tracker:DrawTextOutlined(font, size, text, pos, color)
	local outline = self.colors.outline

	Render.Text(font, size, text, Vec2(pos.x - 1, pos.y), outline)
	Render.Text(font, size, text, Vec2(pos.x + 1, pos.y), outline)
	Render.Text(font, size, text, Vec2(pos.x, pos.y - 1), outline)
	Render.Text(font, size, text, Vec2(pos.x, pos.y + 1), outline)
	Render.Text(font, size, text, Vec2(pos.x - 1, pos.y - 1), outline)
	Render.Text(font, size, text, Vec2(pos.x + 1, pos.y - 1), outline)
	Render.Text(font, size, text, Vec2(pos.x - 1, pos.y + 1), outline)
	Render.Text(font, size, text, Vec2(pos.x + 1, pos.y + 1), outline)
	Render.Text(font, size, text, pos, color)
end

function Tracker:ParseDisplayNumber(text)
	text = tostring(text):gsub(",", ""):gsub("%s", "")

	local mult = 1
	if text:sub(-1) == "k" then
		mult = 1000
		text = text:sub(1, -2)
	end

	if text:sub(-1) == "m" then
		mult = 1000000
		text = text:sub(1, -2)
	end

	return tonumber(text) and tonumber(text) * mult or nil
end

function Tracker:DrawHud(current, bench, diff)
	local scale = self.hud_scale:Get() / 100
	local x, y = self.hud_x:Get(), self.hud_y:Get()

	local label_x = x + 16 * scale
	local val_x = x + 90 * scale
	local goal_x = x + 170 * scale
	local arrow_x = x + 255 * scale
	local row_height = 23 * scale
	local cursor_y = y + 18 * scale

	local pad = 6 * scale
	local row_count = 0

	if self.show_kda:Get() then
		row_count = row_count + 1
	end

	if self.show_cs:Get() then
		row_count = row_count + 1
	end

	if self.show_nw:Get() then
		row_count = row_count + 1
	end

	if self.show_gpm:Get() then
		row_count = row_count + 1
	end

	if self.show_xpm:Get() then
		row_count = row_count + 1
	end

	local bg_x = x - pad
	local bg_y = y - 4 * scale
	local bg_w = 270 * scale + pad * 2
	local bg_h = row_count * 23 * scale + 22 * scale + pad * 2

	if self.show_perf:Get() then
		bg_h = bg_h + 14 * scale
	end

	self:FillRect(bg_x, bg_y, bg_x + bg_w, bg_y + bg_h, self.colors.background)
	self:FillRect(bg_x, bg_y, bg_x + bg_w, bg_y + 2 * scale, self.colors.accent)
	self:FillRect(bg_x, bg_y + bg_h - 1 * scale, bg_x + bg_w, bg_y + bg_h, self.colors.accent_soft)

	if row_count > 0 then
		self:DrawTextOutlined(self.font_bold, 12 * scale, "CURRENT", Vec2(val_x, y + 1 * scale), self.colors.current)
		self:DrawTextOutlined(self.font_bold, 12 * scale, "GOAL", Vec2(goal_x, y + 1 * scale), self.colors.accent)
	end

	local function draw_row(label, val, goal, row_diff)
		Render.Text(self.font_bold, 17 * scale, label, Vec2(label_x, cursor_y), self.colors.label)

		local val_color = self.colors.text
		local is_good

		if goal and goal ~= "" and goal ~= "-" and val and val ~= "" then
			local val_num = self:ParseDisplayNumber(val)
			local goal_num = self:ParseDisplayNumber(goal)

			if val_num and goal_num then
				is_good = val_num >= goal_num
				val_color = is_good and self.colors.green or self.colors.red
			end
		end

		Render.Text(self.font_bold, 17 * scale, val, Vec2(val_x, cursor_y), val_color)
		Render.Text(self.font_bold, 16 * scale, goal, Vec2(goal_x, cursor_y + 1 * scale), self.colors.text)

		local arrow_color = row_diff == nil and (val == goal and self.colors.green or self.colors.gray) or (is_good and self.colors.green or self.colors.red)
		self:DrawArrow(arrow_x, cursor_y + 6 * scale, is_good, arrow_color, 16 * scale)

		cursor_y = cursor_y + row_height
	end

	if self.show_kda:Get() then
		local goal = bench and string.format("%s/%s/%s", format_val(bench.k), format_val(bench.d), format_val(bench.a)) or "-/-/-"
		draw_row("K/D/A", string.format("%d/%d/%d", current.k, current.d, current.a), goal, diff.usp)
	end

	if self.show_cs:Get() then
		local goal = bench and (format_val(bench.lh) .. "/" .. format_val(bench.dn)) or "-/-"
		draw_row("LH/DN", string.format("%d/%d", current.lh, current.dn), goal, diff.lh)
	end

	if self.show_nw:Get() then
		draw_row("NET", format_val(current.gold), bench and format_val(bench.gold) or "-", diff.gold)
	end

	if self.show_gpm:Get() then
		draw_row("GPM", format_val(current.gpm), bench and format_val(bench.gpm) or "-", diff.gpm)
	end

	if self.show_xpm:Get() then
		draw_row("XPM", format_val(current.xpm), bench and format_val(bench.xpm) or "-", diff.xpm)
	end

	if self.show_perf:Get() then
		self:DrawTextOutlined(self.font, 10 * scale, self.perf.text, Vec2(label_x, cursor_y + 4 * scale), self.colors.dim)
	end
end

function Tracker:PerfPush(ms)
	ms = math.max(0, to_num(ms))
	self.perf.samples = self.perf.samples + 1

	if self.perf.samples == 1 then
		self.perf.avg, self.perf.min, self.perf.max = ms, ms, ms
	else
		self.perf.avg = self.perf.avg * 0.96 + ms * 0.04

		if ms < self.perf.min then
			self.perf.min = ms
		end

		if ms > self.perf.max then
			self.perf.max = ms
		end
	end

	if self.perf.samples > 1800 then
		self.perf.samples = 1
		self.perf.min, self.perf.max, self.perf.avg = ms, ms, ms
	end
end

function Tracker:OnUpdate()
	local t0 = time_now()

	if not self.enable:Get() then
		self.state.current, self.state.bench, self.state.diff = nil, nil, nil
		return
	end

	self:HidePanorama()

	local now = os.clock()
	if now - self.state.last_update < self.update_interval then
		self.perf.pending_ms = self.perf.pending_ms + (time_now() - t0) * 1000
		return
	end

	self.state.last_update = now

	local hero_name, hero_id = self:GetLocalHero()
	local live = self:CollectLiveData(hero_name, hero_id)

	if not live then
		self:SetStatus("waiting for game")
		self.state.current, self.state.bench, self.state.diff = nil, nil, nil
		self.perf.pending_ms = self.perf.pending_ms + (time_now() - t0) * 1000
		return
	end

	local entry = self:GetHeroEntry(live.hero_name)
	self:SetStatus(string.format("live %.1f min | bench %d matches%s", live.mins, to_num(entry.sample_count), self.dl.note and (" | " .. self.dl.note) or ""))

	self:DownloaderStep(live.hero_name, live.hero_id)

	self.state.current = live
	self.state.bench = self:GetBenchmark(live)
	self.state.diff = self:CalcDiff(live, self.state.bench)

	self.perf.pending_ms = self.perf.pending_ms + (time_now() - t0) * 1000
end

function Tracker:OnDraw()
	local t0 = time_now()

	if not self.enable:Get() or not self.state.current then
		return
	end

	self:DrawHud(self.state.current, self.state.bench, self.state.diff or {})

	local total = (time_now() - t0) * 1000 + self.perf.pending_ms
	self.perf.pending_ms = 0
	self.perf.last_total = total
	self:PerfPush(total)

	local now = os.clock()
	if now >= self.perf.next_update then
		self.perf.next_update = now + 0.25
		self.perf.text = string.format("script %.3f ms | avg %.3f | min %.3f | max %.3f", self.perf.last_total, self.perf.avg, self.perf.min, self.perf.max)
	end
end

function Tracker:OnGameEnd()
	self.state.current, self.state.bench, self.state.diff = nil, nil, nil
	self.state.pan_scans = 0

	self.perf.avg, self.perf.min, self.perf.max = 0, 9999, 0
	self.perf.samples, self.perf.pending_ms, self.perf.last_total = 0, 0, 0
	self.perf.text = "script 0.000 ms | avg 0.000 | min 0.000 | max 0.000"
	self.perf.next_update = 0
end

return (XHelpers.WrapCallbacks or XHelpers.BaseScript)(Tracker)
