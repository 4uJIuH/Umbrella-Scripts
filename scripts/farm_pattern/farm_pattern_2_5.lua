local FarmPattern = {};
local localHero = nil;
local localTeam = nil;
local displayAlpha = 0;
local alphaStep = 10;
local easingFactor = 0.2;
local smoothCheckpoints = {};
local segmentCheckpoints = {};
local smoothRouteNodes = {};
local timelineCursorX = 0;
local panelFont = nil;
local baseFontSize = 16;
local lastPanelFontSize = 0;
local menuRoot = Menu.Create("Scripts", "User Scripts", "Farm Pattern");
local menuOptions = menuRoot:Create("Options");
local menuMain = menuOptions:Create("Main");
local menuAlgo = menuOptions:Create("Algorithm");
local menuVis = menuOptions:Create("Visualization");
local menuAdv = menuOptions:Create("Advanced");
local menuPresets = menuOptions:Create("Presets");
local opt = {};
opt.enabled = menuMain:Switch("Show Farm Route", true);
opt.ctrlToDrag = menuMain:Switch("Ctrl-Drag Stats Text", true);
opt.optimized = menuAlgo:Switch("Show Optimal Path", true);
opt.algorithm = menuAlgo:Combo("Algorithm", {"Greedy","Optimal (Advanced)","Beam Search"}, 1);
opt.searchRadius = menuAlgo:Slider("Search Radius", 500, 6000, 1500);
opt.allyRadius = menuAlgo:Slider("Ally Exclusion Radius", 300, 1000, 600);
opt.pointsCount = menuAlgo:Slider("Points to Calculate", 2, 10, 4);
opt.minEfficiency = menuAlgo:Slider("Min Efficiency (g/s)", 0, 50, 10);
opt.goldWeight = menuAlgo:Slider("Gold Weight", 0.5, 2, 1);
opt.xpWeight = menuAlgo:Slider("XP Weight", 0, 2, 0.7);
opt.dynamicUpdate = menuAlgo:Switch("Dynamic Route Updates", true);
opt.checkpointCount = menuAlgo:Slider("Checkpoints per Path", 1, 10, 5);
opt.beamWidth = menuAlgo:Slider("Beam Width", 1, 10, 3);
opt.maxBeamNodes = menuAlgo:Slider("Max Beam Nodes", 10, 200, 60);
opt.stackBias = menuAlgo:Slider("Jungle Stacking Bias", 0, 2, 0.5);
opt.showVisualization = menuVis:Switch("Toggle Visualization", true);
opt.visualColor = menuVis:ColorPicker("Visual Color", Color(0, 255, 128));
opt.circleSize = menuVis:Slider("Point Size", 5, 30, 10);
opt.lineThickness = menuVis:Slider("Line Thickness", 1, 6, 2);
opt.futureOpacity = menuVis:Slider("Future Segment Opacity (%)", 0, 100, 50);
opt.showPointIndex = menuVis:Switch("Show Point Index", true);
opt.showGold = menuVis:Switch("Show Gold Values", true);
opt.panelScale = menuVis:Slider("HUD Scale (%)", 60, 160, 100);
opt.farmTimePerCreep = menuAdv:Slider("Farm Time/Creep (s)", 0.5, 3, 1);
opt.easingFactor = menuAdv:Slider("Smoothing Factor", 0.05, 0.5, 0.2);
opt.alphaStep = menuAdv:Slider("Fade Step", 1, 25, 10);
opt.advanceDistance = menuAdv:Slider("Advance Segment Distance", 50, 500, 220);
opt.debugNearestCamp = menuAdv:Switch("Debug Nearest Camp", false);
opt.showProfile = menuAdv:Switch("Show Performance", false);
db.farmRouteSettings = db.farmRouteSettings or {};
local presetStore = db.farmRouteSettings;
presetStore.last = presetStore.last or "";
opt.presetData = menuPresets:Input("Settings String", presetStore.last, "");
db.farmRouteIndicator = db.farmRouteIndicator or {};
local hud = db.farmRouteIndicator;
hud.x = hud.x or 10;
hud.y = hud.y or 320;
local dragging = false;
local dragDelta = Vec2(0, 0);
local spots = {};
local route = {};
local lastTick = 0;
local currentSegmentIndex = 1;
local lastHeroPos = nil;
local debugNearestCampInfo = nil;
local campClearHistory = {};
local lastHeroCacheTime = 0;
local cachedHasAoE = false;
local cachedAllyPositions = {};
local profileUpdate = 0;
local profileRoute = 0;
local profileDraw = 0;
local function getCampStackCount(camp)
	if not camp or not camp.stacks_cache then
		return 0;
	end
	local count = tonumber(camp.stacks_cache.count) or 0;
	return math.max(0, math.floor(count + 0.5));
end
local function campNeedsStack(camp)
	if not camp then
		return false;
	end
	return getCampStackCount(camp) == 0;
end
local fontMain = Render.LoadFont("Tahoma", Enum.FontCreate.FONTFLAG_ANTIALIAS, 500);
local fontBold = Render.LoadFont("Tahoma", Enum.FontCreate.FONTFLAG_ANTIALIAS, 700);
local function isGameStarted()
	-- Проверяем что игра началась (не pre-game/picking phase)
	if not GameRules then return false; end
	local state = GameRules.GetGameState();
	if not state then return false; end
	-- DOTA_GAMERULES_STATE_PRE_GAME = 4, DOTA_GAMERULES_STATE_GAME_IN_PROGRESS = 5
	return state >= Enum.GameState.DOTA_GAMERULES_STATE_GAME_IN_PROGRESS;
end

local function timeSinceStart()
	-- Если игра не началась, возвращаем 0
	if not isGameStarted() then
		return 0;
	end
	local t = GameRules.GetGameTime() - GameRules.GetGameStartTime();
	if (t < 0) then
		t = 0;
	end
	return t;
end
local function getLocalHero()
	local now = (GameRules and GameRules.GetGameTime()) or 0;
	if not localHero or (now - lastHeroCacheTime > 5) then
		localHero = Heroes.GetLocal();
		lastHeroCacheTime = now;
	end
	return localHero;
end
local function getLocalTeam()
	if not localTeam then
		local p = Players.GetLocal();
		local slot = Player.GetPlayerSlot(p);
		localTeam = ((slot < 5) and Enum.TeamNum.TEAM_RADIANT) or Enum.TeamNum.TEAM_DIRE;
	end
	return localTeam;
end
local function logPreset(msg)
	local text = "[FarmPattern] " .. tostring(msg);
	if Log and Log.Write then
		Log.Write(text);
	else
		print(text);
	end
end
local function safeNumber(v, fallback)
	local n = tonumber(v);
	if not n or (n ~= n) or (n == math.huge) or (n == -math.huge) then
		return fallback;
	end
	return n;
end
local function safeInt(v, fallback)
	local n = safeNumber(v, fallback);
	if n >= 0 then
		return math.floor(n + 0.5);
	end
	return math.ceil(n - 0.5);
end
local function boolToStr(v)
	return v and "1" or "0";
end
local function strToBool(v)
	if v == nil then
		return nil;
	end
	local s = tostring(v):lower();
	if s == "1" or s == "true" then
		return true;
	end
	if s == "0" or s == "false" then
		return false;
	end
	return nil;
end
local function menuSet(control, value)
	if (not control) or (not control.Set) then
		return false;
	end
	local ok = pcall(control.Set, control, value);
	return ok;
end
local function presetInputGet()
	if (not opt.presetData) or (not opt.presetData.Get) then
		return "";
	end
	local ok, value = pcall(opt.presetData.Get, opt.presetData);
	if not ok then
		return "";
	end
	return tostring(value or "");
end
local function presetInputSet(value)
	local text = tostring(value or "");
	if opt.presetData and opt.presetData.Set then
		pcall(opt.presetData.Set, opt.presetData, text);
	end
end
local function exportSettingsString()
	local parts = {"FP2V1"};
	local boolFields = {
		{"enabled", opt.enabled},
		{"ctrlToDrag", opt.ctrlToDrag},
		{"optimized", opt.optimized},
		{"dynamicUpdate", opt.dynamicUpdate},
		{"showVisualization", opt.showVisualization},
		{"showPointIndex", opt.showPointIndex},
		{"showGold", opt.showGold},
		{"debugNearestCamp", opt.debugNearestCamp}
	};
	local numFields = {
		{"algorithm", opt.algorithm},
		{"searchRadius", opt.searchRadius},
		{"allyRadius", opt.allyRadius},
		{"pointsCount", opt.pointsCount},
		{"minEfficiency", opt.minEfficiency},
		{"goldWeight", opt.goldWeight},
		{"xpWeight", opt.xpWeight},
		{"checkpointCount", opt.checkpointCount},
		{"beamWidth", opt.beamWidth},
		{"maxBeamNodes", opt.maxBeamNodes},
		{"stackBias", opt.stackBias},
		{"circleSize", opt.circleSize},
		{"lineThickness", opt.lineThickness},
		{"futureOpacity", opt.futureOpacity},
		{"panelScale", opt.panelScale},
		{"farmTimePerCreep", opt.farmTimePerCreep},
		{"easingFactor", opt.easingFactor},
		{"alphaStep", opt.alphaStep},
		{"advanceDistance", opt.advanceDistance}
	};
	for _, item in ipairs(boolFields) do
		local key = item[1];
		local control = item[2];
		parts[#parts + 1] = key .. "=" .. boolToStr(control:Get());
	end
	for _, item in ipairs(numFields) do
		local key = item[1];
		local control = item[2];
		parts[#parts + 1] = key .. "=" .. tostring(control:Get());
	end
	local color = opt.visualColor:Get();
	local cr = safeInt(color and color.r, 0);
	local cg = safeInt(color and color.g, 255);
	local cb = safeInt(color and color.b, 128);
	local ca = safeInt(color and color.a, 255);
	parts[#parts + 1] = string.format("visualColor=%d,%d,%d,%d", cr, cg, cb, ca);
	parts[#parts + 1] = string.format("hud=%d,%d", safeInt(hud.x, 10), safeInt(hud.y, 320));
	return table.concat(parts, "|");
end
local function importSettingsString(raw)
	local text = tostring(raw or ""):gsub("^%s+", ""):gsub("%s+$", "");
	if text == "" then
		return false, "empty input";
	end
	local map = {};
	for token in text:gmatch("[^|]+") do
		local k, v = token:match("^([^=]+)=(.*)$");
		if k and v then
			map[k] = v;
		end
	end
	if not next(map) then
		return false, "invalid format";
	end
	local applied = 0;
	local function applyBool(key, control)
		local b = strToBool(map[key]);
		if b == nil then
			return;
		end
		if menuSet(control, b) then
			applied = applied + 1;
		end
	end
	local function applyNum(key, control)
		local n = safeNumber(map[key], nil);
		if n == nil then
			return;
		end
		if menuSet(control, n) then
			applied = applied + 1;
		end
	end
	applyBool("enabled", opt.enabled);
	applyBool("ctrlToDrag", opt.ctrlToDrag);
	applyBool("optimized", opt.optimized);
	applyBool("dynamicUpdate", opt.dynamicUpdate);
	applyBool("showVisualization", opt.showVisualization);
	applyBool("showPointIndex", opt.showPointIndex);
	applyBool("showGold", opt.showGold);
	applyBool("debugNearestCamp", opt.debugNearestCamp);
	applyNum("algorithm", opt.algorithm);
	applyNum("searchRadius", opt.searchRadius);
	applyNum("allyRadius", opt.allyRadius);
	applyNum("pointsCount", opt.pointsCount);
	applyNum("minEfficiency", opt.minEfficiency);
	applyNum("goldWeight", opt.goldWeight);
	applyNum("xpWeight", opt.xpWeight);
	applyNum("checkpointCount", opt.checkpointCount);
	applyNum("beamWidth", opt.beamWidth);
	applyNum("maxBeamNodes", opt.maxBeamNodes);
	applyNum("stackBias", opt.stackBias);
	applyNum("circleSize", opt.circleSize);
	applyNum("lineThickness", opt.lineThickness);
	applyNum("futureOpacity", opt.futureOpacity);
	applyNum("panelScale", opt.panelScale);
	applyNum("farmTimePerCreep", opt.farmTimePerCreep);
	applyNum("easingFactor", opt.easingFactor);
	applyNum("alphaStep", opt.alphaStep);
	applyNum("advanceDistance", opt.advanceDistance);
	if map.visualColor then
		local r, g, b, a = map.visualColor:match("^([^,]+),([^,]+),([^,]+),([^,]+)$");
		if r and g and b and a then
			local ok = menuSet(opt.visualColor, Color(
				safeInt(r, 0),
				safeInt(g, 255),
				safeInt(b, 128),
				safeInt(a, 255)
			));
			if ok then
				applied = applied + 1;
			end
		end
	end
	if map.hud then
		local x, y = map.hud:match("^([^,]+),([^,]+)$");
		if x and y then
			hud.x = safeInt(x, hud.x or 10);
			hud.y = safeInt(y, hud.y or 320);
			applied = applied + 1;
		end
	end
	if applied <= 0 then
		return false, "nothing applied";
	end
	return true, applied;
end
menuPresets:Button("Export Settings", function()
	local preset = exportSettingsString();
	presetStore.last = preset;
	presetInputSet(preset);
	logPreset("Settings exported (" .. tostring(#preset) .. " chars)");
end);
menuPresets:Button("Import Settings", function()
	local preset = presetInputGet();
	local ok, info = importSettingsString(preset);
	if ok then
		presetStore.last = preset;
		logPreset("Settings imported (applied: " .. tostring(info) .. ")");
	else
		logPreset("Import failed: " .. tostring(info));
	end
end);
menuPresets:Button("Load Last Saved", function()
	local preset = tostring(presetStore.last or "");
	if preset == "" then
		logPreset("No saved preset found");
		return;
	end
	presetInputSet(preset);
	local ok, info = importSettingsString(preset);
	if ok then
		logPreset("Loaded saved preset (applied: " .. tostring(info) .. ")");
	else
		logPreset("Load failed: " .. tostring(info));
	end
end);
local function estimateClearSeconds(spot)
	local hero = getLocalHero();
	if not hero then
		return opt.farmTimePerCreep:Get();
	end
	local creepCount = spot.creepCount or 0;
	if (creepCount == 0) then
		if (spot.gold > 150) then
			creepCount = 5;
		elseif (spot.gold > 100) then
			creepCount = 4;
		else
			creepCount = 3;
		end
	end
	local trueDps = NPC.GetTrueDamage(hero) * NPC.GetAttackSpeed(hero);
	local baselineHp = 300;
	local dpsFactor = baselineHp / math.max(50, trueDps);
	local seconds = creepCount * dpsFactor;
	if cachedHasAoE then
		seconds = seconds * 0.6;
	end
	return math.max(seconds, creepCount * opt.farmTimePerCreep:Get());
end
local function stackBiasWeight(isJungle)
	if not isJungle then
		return 1;
	end
	local sec = math.floor(timeSinceStart() % 60);
	if ((sec < 40) or (sec > 56)) then
		return 1;
	end
	local peak = 50;
	local dist = math.abs(sec - peak);
	local norm = math.max(0, 1 - (dist / 10));
	return 1 + (opt.stackBias:Get() * norm);
end
local function interpolatePoints(a, b, count)
	local pts = {};
	for i = 1, count do
		local t = i / (count + 1);
		local x = a.x + ((b.x - a.x) * t);
		local y = a.y + ((b.y - a.y) * t);
		local z = a.z + ((b.z - a.z) * t);
		table.insert(pts, Vector(x, y, z));
	end
	return pts;
end
local function smoothRouteNodesTowards()
	if (#route == 0) then
		smoothRouteNodes = {};
		return;
	end
	for i = 1, #route do
		local target = route[i].pos;
		local cur = smoothRouteNodes[i] or Vector(target.x, target.y, target.z);
		cur.x = cur.x + ((target.x - cur.x) * easingFactor);
		cur.y = cur.y + ((target.y - cur.y) * easingFactor);
		cur.z = cur.z + ((target.z - cur.z) * easingFactor);
		smoothRouteNodes[i] = cur;
	end
	for i = #route + 1, #smoothRouteNodes do
		smoothRouteNodes[i] = nil;
	end
end
-- ensurePanelFont removed (unused)
local function allyNear(pos, radius)
	local r2 = radius * radius;
	for _, allyPos in ipairs(cachedAllyPositions) do
		local dx = pos.x - allyPos.x;
		local dy = pos.y - allyPos.y;
		if (dx * dx + dy * dy) <= r2 then
			return true;
		end
	end
	return false;
end
local function buildSegmentCheckpoints(unit, points, perSegment)
	local segments = {};
	local origin = Entity.GetAbsOrigin(unit);
	if (#points > 0) then
		table.insert(segments, interpolatePoints(origin, points[1].pos, perSegment));
	end
	for i = 1, #points - 1 do
		table.insert(segments, interpolatePoints(points[i].pos, points[i + 1].pos, perSegment));
	end
	return segments;
end
local function smoothTowards()
	for si, seg in ipairs(segmentCheckpoints) do
		smoothCheckpoints[si] = smoothCheckpoints[si] or {};
		for pi, pos in ipairs(seg) do
			local cur = smoothCheckpoints[si][pi] or Vector(pos.x, pos.y, pos.z);
			cur.x = cur.x + ((pos.x - cur.x) * easingFactor);
			cur.y = cur.y + ((pos.y - cur.y) * easingFactor);
			cur.z = cur.z + ((pos.z - cur.z) * easingFactor);
			smoothCheckpoints[si][pi] = cur;
		end
	end
end
local function greedyRoute()
	local hero = getLocalHero();
	if not hero then
		return {};
	end
	local heroPos = Entity.GetAbsOrigin(hero);
	local ms = NPC.GetMoveSpeed(hero);
	local pool = {};
	for _, s in ipairs(spots) do
		local xp = s.gold * 0.8;
		table.insert(pool, {pos=s.pos,gold=s.gold,xp=xp,creepCount=s.creepCount,isJungle=s.isJungle,camp=s.camp,campIndex=s.campIndex});
	end
	local chosen = {};
	local current = heroPos;
	local minEff = opt.minEfficiency:Get();
	local maxPoints = opt.pointsCount:Get();
	local gw = opt.goldWeight:Get();
	local xw = opt.xpWeight:Get();
	while (#pool > 0) and (#chosen < maxPoints) do
		local bestIdx = nil;
		local bestScore = 0;
		for i, c in ipairs(pool) do
			local travel = GridNav.GetTravelTime(current, c.pos, false, nil, ms);
			local clear = estimateClearSeconds(c);
			local value = ((c.gold * gw) + (c.xp * xw)) * stackBiasWeight(c.isJungle);
			local eff = value / (travel + clear);
			if ((eff >= minEff) and (eff > bestScore)) then
				bestScore = eff;
				bestIdx = i;
			end
		end
		if not bestIdx then
			break;
		end
		table.insert(chosen, pool[bestIdx]);
		current = pool[bestIdx].pos;
		table.remove(pool, bestIdx);
	end
	return chosen;
end
local function rankCandidatesFrom(pos, cands, ms, gw, xw, minEff)
	local ranked = {};
	for _, c in ipairs(cands) do
		local travel = GridNav.GetTravelTime(pos, c.pos, false, nil, ms);
		local clear = estimateClearSeconds(c);
		local eff = ((c.gold * gw) + (c.gold * 0.8 * xw)) / (travel + clear);
		eff = eff * stackBiasWeight(c.isJungle);
		if (eff >= minEff) then
			table.insert(ranked, {pos=c.pos,gold=c.gold,xp=(c.gold * 0.8),creepCount=c.creepCount,isJungle=c.isJungle,camp=c.camp,campIndex=c.campIndex,eff=eff});
		end
	end
	table.sort(ranked, function(a, b)
		return a.eff > b.eff;
	end);
	return ranked;
end
local function scorePath(path, totalTime, gw, xw)
	if (totalTime <= 0) then
		return 0;
	end
	local g, xp = 0, 0;
	for _, p in ipairs(path) do
		g = g + p.gold;
		xp = xp + (p.xp or p.gold * 0.8);
	end
	local base = ((g * gw) + (xp * xw)) / totalTime;
	for _, p in ipairs(path) do
		if p.isJungle then
			base = base * stackBiasWeight(true);
			break;
		end
	end
	return base;
end
local function optimalRoute()
	local hero = getLocalHero();
	if not hero then
		return {};
	end
	local heroPos = Entity.GetAbsOrigin(hero);
	local ms = NPC.GetMoveSpeed(hero);
	local gw = opt.goldWeight:Get();
	local xw = opt.xpWeight:Get();
	local minEff = opt.minEfficiency:Get();
	local candidates = rankCandidatesFrom(heroPos, spots, ms, gw, xw, minEff);
	local limit = math.min(6, #candidates);
	if (#candidates > limit) then
		local trimmed = {};
		for i = 1, limit do
			trimmed[i] = candidates[i];
		end
		candidates = trimmed;
	end
	local n = #candidates;
	if (n == 0) then
		return {};
	end

	-- Предвычисляем матрицу travel time: O(n²) вызовов GridNav вместо O(n!) в DFS
	-- Индекс 0 = heroPos, 1..n = candidates
	local travelMatrix = {};
	for i = 0, n do
		travelMatrix[i] = {};
		local fromPos = (i == 0) and heroPos or candidates[i].pos;
		for j = 1, n do
			if (i ~= j) then
				travelMatrix[i][j] = GridNav.GetTravelTime(fromPos, candidates[j].pos, false, nil, ms);
			end
		end
	end

	-- Предвычисляем clear seconds для каждого кандидата
	local clearCache = {};
	for i = 1, n do
		clearCache[i] = estimateClearSeconds(candidates[i]);
	end

	-- Предвычисляем value для каждого кандидата
	local valueCache = {};
	for i = 1, n do
		local c = candidates[i];
		valueCache[i] = (c.gold * gw) + ((c.xp or c.gold * 0.8) * xw);
	end

	local maxDepth = opt.pointsCount:Get();
	local bestPath, bestScore = {}, 0;

	-- DFS с индексами вместо позиций: все lookups — O(1) таблица
	local function dfs(usedMask, fromIdx, pathSoFar, valueSoFar, timeSoFar, depth)
		if (depth >= maxDepth) or (usedMask == (2^n - 1)) then
			local s = (timeSoFar > 0) and (valueSoFar / timeSoFar) or 0;
			if (s > bestScore) then
				bestPath = {table.unpack(pathSoFar)};
				bestScore = s;
			end
			return;
		end

		-- Pruning: верхняя оценка
		if (bestScore > 0) and (timeSoFar > 0) then
			local maxRemaining = 0;
			for i = 1, n do
				local bit = 2^(i-1);
				if (usedMask % (bit * 2)) < bit then
					maxRemaining = maxRemaining + valueCache[i];
				end
			end
			if ((valueSoFar + maxRemaining) / timeSoFar) <= bestScore then
				return;
			end
		end

		for i = 1, n do
			local bit = 2^(i-1);
			if (usedMask % (bit * 2)) < bit then
				local travel = travelMatrix[fromIdx][i];
				local t = timeSoFar + travel + clearCache[i];
				pathSoFar[depth + 1] = candidates[i];
				dfs(usedMask + bit, i, pathSoFar, valueSoFar + valueCache[i], t, depth + 1);
				pathSoFar[depth + 1] = nil;
			end
		end
	end
	dfs(0, 0, {}, 0, 0, 0);
	return bestPath;
end
local function beamSearchRoute()
	local hero = getLocalHero();
	if not hero then
		return {};
	end
	local heroPos = Entity.GetAbsOrigin(hero);
	local ms = NPC.GetMoveSpeed(hero);
	local gw = opt.goldWeight:Get();
	local xw = opt.xpWeight:Get();
	local minEff = opt.minEfficiency:Get();
	local beamW = opt.beamWidth:Get();
	local maxNodes = opt.maxBeamNodes:Get();
	local initialRank = rankCandidatesFrom(heroPos, spots, ms, gw, xw, minEff);
	local frontier = {};
	for i = 1, math.min(beamW, #initialRank) do
		local n = initialRank[i];
		local initialTravel = GridNav.GetTravelTime(heroPos, n.pos, false, nil, ms);
		table.insert(frontier, {path={n},pos=n.pos,time=initialTravel + estimateClearSeconds(n)});
	end
	local best = {path={},score=0};
	local expansions = 0;
	while (#frontier > 0) and (expansions < maxNodes) do
		local newFrontier = {};
		for _, state in ipairs(frontier) do
			if (#state.path >= opt.pointsCount:Get()) then
				local s = scorePath(state.path, state.time, gw, xw);
				if (s > best.score) then
					best.path = state.path;
					best.score = s;
				end
			else
				local remaining = {};
				for _, c in ipairs(spots) do
					local used = false;
					for _, u in ipairs(state.path) do
						if (u.pos == c.pos) then
							used = true;
							break;
						end
					end
					if not used then
						table.insert(remaining, c);
					end
				end
				local ranked = rankCandidatesFrom(state.pos, remaining, ms, gw, xw, minEff);
				for i = 1, math.min(beamW, #ranked) do
					local nxt = ranked[i];
					local travel = GridNav.GetTravelTime(state.pos, nxt.pos, false, nil, ms);
					local clear = estimateClearSeconds(nxt);
					local newTime = state.time + travel + clear;
					local newPath = {table.unpack(state.path)};
					table.insert(newPath, nxt);
					table.insert(newFrontier, {path=newPath,pos=nxt.pos,time=newTime});
					expansions = expansions + 1;
				end
			end
		end
		for _, state in ipairs(newFrontier) do
			state.score = scorePath(state.path, state.time, gw, xw);
		end
		table.sort(newFrontier, function(a, b)
			return a.score > b.score;
		end);
		if (#newFrontier > beamW) then
			local trimmed = {};
			for i = 1, beamW do
				trimmed[i] = newFrontier[i];
			end
			frontier = trimmed;
		else
			frontier = newFrontier;
		end
	end
	if ((#best.path == 0) and (#frontier > 0)) then
		best.path = frontier[1].path;
	end
	return best.path;
end
local function selectRoute()
	local algo = opt.algorithm:Get();
	-- Combo index is 0-based: 0=Greedy, 1=Optimal, 2=Beam
	if (algo == 0) then
		return greedyRoute();
	elseif (algo == 1) then
		return optimalRoute();
	else
		return beamSearchRoute();
	end
end
local KEY_CTRL = Enum.ButtonCode.KEY_LCONTROL;
local KEY_MOUSE1 = Enum.ButtonCode.KEY_MOUSE1;
FarmPattern.OnUpdate = function()
	if not opt.enabled:Get() then
		return;
	end
	-- Не обрабатываем ничего пока игра не началась (pre-game/picking phase)
	if not isGameStarted() then
		return;
	end
	local hero = getLocalHero();
	if (not hero or not Entity.IsAlive(hero)) then
		return;
	end
	local now = GameRules.GetGameTime();
	local heroPos = Entity.GetAbsOrigin(hero);
	easingFactor = opt.easingFactor:Get();
	alphaStep = opt.alphaStep:Get();
	if ((now - lastTick) >= 0.1) then
		local tickStart = os.clock();
		lastTick = now;
		spots = {};
		local seen = {};
		local searchR = opt.searchRadius:Get();
		local allyR = opt.allyRadius:Get();

		-- Кэш AoE способностей (1 раз за тик вместо ~240)
		cachedHasAoE = false;
		local abilityIds = {"juggernaut_blade_fury","axe_counter_helix","antimage_blink","phantom_assassin_stifling_dagger","luna_moon_glaive","sven_great_cleave"};
		for _, name in ipairs(abilityIds) do
			local a = NPC.GetAbility(hero, name);
			if (a and Ability.IsReady(a)) then
				cachedHasAoE = true;
				break;
			end
		end

		-- Кэш позиций союзников (1 раз за тик вместо per-spot)
		cachedAllyPositions = {};
		local team = getLocalTeam();
		local allies = Heroes.InRadius(heroPos, searchR + allyR, team, Enum.TeamType.TEAM_FRIEND);
		for _, ally in ipairs(allies) do
			if (ally ~= hero) and Entity.IsAlive(ally) then
				table.insert(cachedAllyPositions, Entity.GetAbsOrigin(ally));
			end
		end
		local debugCampEnabled = opt.debugNearestCamp:Get();
		local debugNearestCamp = nil;
		debugNearestCampInfo = nil;
		if debugCampEnabled then
			if JungleCampsManager and JungleCampsManager.camps then
				local nearestDist = math.huge;
				for _, camp in pairs(JungleCampsManager.camps) do
					local cp = camp.position_;
					if cp then
						local dist = (cp - heroPos):Length2D();
						if dist < nearestDist then
							nearestDist = dist;
							debugNearestCamp = camp;
						end
					end
				end
				if debugNearestCamp then
					debugNearestCampInfo = {index=(debugNearestCamp.index_ or -1), reason="not_processed"};
				else
					debugNearestCampInfo = {index=-1, reason="no_camp_position"};
				end
			else
				debugNearestCampInfo = {index=-1, reason="no_camps_manager"};
			end
		end

		-- LaneGroupsManager.groups_enemy — вражеские лейн крипы
		if LaneGroupsManager and LaneGroupsManager.groups_enemy then
			for _, grp in pairs(LaneGroupsManager.groups_enemy) do
				local p = grp.position_;
				if p and ((p - heroPos):Length2D() <= searchR) then
					local g = 0;
					local creepCount = 0;
					-- Считаем золото с крипов (используем .ref для получения реального Entity)
					if grp.creeps then
						for _, creepWrapper in pairs(grp.creeps) do
							-- creepWrapper это таблица-обёртка, реальный Entity в .ref
							local creep = creepWrapper.ref or creepWrapper;
							if creep and Entity.IsAlive(creep) then
								g = g + (NPC.GetGoldBounty(creep) or 0);
								creepCount = creepCount + 1;
							end
						end
					end
					-- Альтернативно можно использовать кэш
					if g == 0 and grp.get_gold_bounty_cache then
						for _, cached in pairs(grp.get_gold_bounty_cache) do
							if type(cached) == "number" then
								g = g + cached;
							end
						end
					end
					local key = tostring(p);
					if (g > 0) and not seen[key] and not allyNear(p, allyR) then
						seen[key] = true;
						table.insert(spots, {pos=p, gold=g, isJungle=false, creepCount=creepCount});
					end
				end
			end
		end
		-- JungleCampsManager.camps — лесные кемпы (с трекингом зачистки)
		if JungleCampsManager and JungleCampsManager.camps then
			local gameSeconds = timeSinceStart();
			local secondsInMinute = gameSeconds % 60;

			for _, camp in pairs(JungleCampsManager.camps) do
				local p = camp.position_;
				local dist = p and (p - heroPos):Length2D() or nil;
				local isDebugTarget = debugCampEnabled and debugNearestCamp and (camp == debugNearestCamp);
				if isDebugTarget then
					debugNearestCampInfo = debugNearestCampInfo or {};
					debugNearestCampInfo.index = camp.index_ or -1;
					debugNearestCampInfo.pos = p;
					debugNearestCampInfo.dist = dist;
					debugNearestCampInfo.searchR = searchR;
					debugNearestCampInfo.inSearch = (p and dist and (dist <= searchR)) and true or false;
					debugNearestCampInfo.sec = math.floor(timeSinceStart() % 60);
				end
				if p and dist and (dist <= searchR) then
					local g = 0;
					local creepCount = 0;
					local hasVision = false;
					local debugShouldHaveCreeps = false;
					local debugUsedFallback = false;

					-- Считаем золото с живых крипов (используем .ref для получения реального Entity)
					if camp.creeps_alive then
						for _, creepWrapper in pairs(camp.creeps_alive) do
							local creep = creepWrapper.ref or creepWrapper;
							if creep and Entity.IsAlive(creep) then
								g = g + (NPC.GetGoldBounty(creep) or 0);
								creepCount = creepCount + 1;
								hasVision = true;
							end
						end
					end

					-- Альтернативно используем кэш
					if g == 0 and camp.get_gold_bounty_cache then
						for _, cached in pairs(camp.get_gold_bounty_cache) do
							if type(cached) == "number" then
								g = g + cached;
							end
						end
						if g > 0 then hasVision = true; end
					end

					-- Проверяем видимость позиции кемпа через FogOfWar
					local canSeePosition = false;
					if FogOfWar and FogOfWar.IsPointVisible then
						local ok, result = pcall(FogOfWar.IsPointVisible, p);
						if ok then
							canSeePosition = result;
						end
					end

					-- Camp tracking: запоминаем видимое состояние кемпа
					local campKey = tostring(camp.index_ or "") .. "_" .. tostring(p);
					if canSeePosition then
						if g > 0 and hasVision then
							-- Видим кемп с крипами — очищаем историю зачистки
							campClearHistory[campKey] = nil;
						elseif g == 0 then
							-- Видим пустой кемп — записываем минуту зачистки
							campClearHistory[campKey] = math.floor(gameSeconds / 60);
						end
					end

					-- Fallback: нет vision — оцениваем по истории зачистки
					if g == 0 and not hasVision and not canSeePosition then
						-- Проверяем, должен ли кемп быть с крипами
						-- Используем поля camp для определения типа/статуса
						local shouldHaveCreeps = false;
						debugShouldHaveCreeps = false;
						local estimatedGold = 0;
						local estimatedCreepCount = 0;

						-- Пробуем определить тип кемпа для оценки золота
						-- Типичные значения: small ~70-90, medium ~120-150, hard ~180-220, ancient ~300+
						local campType = camp.type_ or camp.camp_type or camp.tier or nil;

						-- Определяем золото по типу кемпа
						if campType then
							if campType == 0 or tostring(campType):lower():find("small") then
								estimatedGold = 50;
								estimatedCreepCount = 3;
							elseif campType == 1 or tostring(campType):lower():find("medium") then
								estimatedGold = 70;
								estimatedCreepCount = 3;
							elseif campType == 2 or tostring(campType):lower():find("hard") or tostring(campType):lower():find("large") then
								estimatedGold = 110;
								estimatedCreepCount = 4;
							elseif campType == 3 or tostring(campType):lower():find("ancient") then
								estimatedGold = 210;
								estimatedCreepCount = 3;
							else
								estimatedGold = 150; -- default medium estimate
								estimatedCreepCount = 3;
							end
						else
							-- Если тип неизвестен, используем среднее значение
							estimatedGold = 150;
							estimatedCreepCount = 3;
						end

						-- Проверяем историю зачистки кемпа
						local clearedMinute = campClearHistory[campKey];
						local currentMinute = math.floor(gameSeconds / 60);

						if clearedMinute then
							-- Видели этот кемп пустым в минуту clearedMinute
							-- Кемпы респавнятся на :00 следующей минуты
							if currentMinute > clearedMinute and secondsInMinute > 5 then
								shouldHaveCreeps = true;
							end
						else
							-- Никогда не видели пустым — используем API поля или дефолт
							if camp.is_empty ~= nil then
								shouldHaveCreeps = not camp.is_empty;
							elseif camp.is_alive ~= nil then
								shouldHaveCreeps = camp.is_alive;
							elseif camp.spawned ~= nil then
								shouldHaveCreeps = camp.spawned;
							elseif gameSeconds > 60 and secondsInMinute > 5 then
								shouldHaveCreeps = true;
							end
						end

						debugShouldHaveCreeps = shouldHaveCreeps;
						if shouldHaveCreeps then
							g = estimatedGold;
							creepCount = estimatedCreepCount;
							debugUsedFallback = true;
						end
					end

					local key = tostring(p);
					local duplicateSpot = (seen[key] ~= nil);
					local blockedByAlly = allyNear(p, allyR);
					local addedToSpots = (g > 0) and not duplicateSpot and not blockedByAlly;
					if addedToSpots then
						seen[key] = true;
						table.insert(spots, {pos=p, gold=g, isJungle=true, creepCount=creepCount, camp=camp, campIndex=camp.index_});
					end
					if isDebugTarget then
						local msDbg = NPC.GetMoveSpeed(hero);
						local gwDbg = opt.goldWeight:Get();
						local xwDbg = opt.xpWeight:Get();
						local minEffDbg = opt.minEfficiency:Get();
						local travelDbg = GridNav.GetTravelTime(heroPos, p, false, nil, msDbg);
						local clearDbg = estimateClearSeconds({gold=g, creepCount=creepCount, isJungle=true});
						local totalDbg = travelDbg + clearDbg;
						local effDbg = 0;
						if totalDbg > 0 then
							effDbg = (((g * gwDbg) + (g * 0.8 * xwDbg)) / totalDbg) * stackBiasWeight(true);
						end
						debugNearestCampInfo.gold = g;
						debugNearestCampInfo.creepCount = creepCount;
						debugNearestCampInfo.hasVision = hasVision;
						debugNearestCampInfo.canSeePosition = canSeePosition;
						debugNearestCampInfo.shouldHaveCreeps = debugShouldHaveCreeps;
						debugNearestCampInfo.usedFallback = debugUsedFallback;
						debugNearestCampInfo.duplicateSpot = duplicateSpot;
						debugNearestCampInfo.blockedByAlly = blockedByAlly;
						debugNearestCampInfo.addedToSpots = addedToSpots;
						debugNearestCampInfo.eff = effDbg;
						debugNearestCampInfo.minEff = minEffDbg;
						debugNearestCampInfo.stackBiasNow = stackBiasWeight(true);
						debugNearestCampInfo.passMinEff = (effDbg >= minEffDbg);
						if g <= 0 then
							debugNearestCampInfo.reason = "g_zero";
						elseif blockedByAlly then
							debugNearestCampInfo.reason = "ally_near";
						elseif duplicateSpot then
							debugNearestCampInfo.reason = "duplicate_spot";
						elseif not (effDbg >= minEffDbg) then
							debugNearestCampInfo.reason = "below_min_eff";
						else
							debugNearestCampInfo.reason = "added_to_spots";
						end
					end
				elseif isDebugTarget then
					if p then
						debugNearestCampInfo.reason = "out_of_search_radius";
					else
						debugNearestCampInfo.reason = "no_position";
					end
				end
			end
		end

		if debugCampEnabled and debugNearestCampInfo and debugNearestCampInfo.addedToSpots and debugNearestCampInfo.pos then
			local msDbg = NPC.GetMoveSpeed(hero);
			local gwDbg = opt.goldWeight:Get();
			local xwDbg = opt.xpWeight:Get();
			local minEffDbg = opt.minEfficiency:Get();
			local rankedDbg = rankCandidatesFrom(heroPos, spots, msDbg, gwDbg, xwDbg, minEffDbg);
			local rankIndex = 0;
			for i, node in ipairs(rankedDbg) do
				if node.pos and ((node.pos - debugNearestCampInfo.pos):Length2D() < 1) then
					rankIndex = i;
					break;
				end
			end
			debugNearestCampInfo.rankIndex = rankIndex;
			debugNearestCampInfo.inRanked = (rankIndex > 0);
			if (opt.algorithm:Get() == 1) and (rankIndex > 8) then
				debugNearestCampInfo.reason = "cut_by_top8_optimal";
			elseif rankIndex == 0 then
				debugNearestCampInfo.reason = "below_min_eff";
			end
		end

		if opt.optimized:Get() then
			local routeStart = os.clock();
			local newRoute = selectRoute();
			profileRoute = os.clock() - routeStart;
			route = newRoute;
			if debugCampEnabled and debugNearestCampInfo and debugNearestCampInfo.pos then
				local inRoute = false;
				local routeIndex = 0;
				for i, node in ipairs(route) do
					if node.pos and ((node.pos - debugNearestCampInfo.pos):Length2D() < 1) then
						inRoute = true;
						routeIndex = i;
						break;
					end
				end
				debugNearestCampInfo.inRoute = inRoute;
				debugNearestCampInfo.routeIndex = routeIndex;
				if inRoute then
					debugNearestCampInfo.reason = "in_route";
				elseif debugNearestCampInfo.addedToSpots and debugNearestCampInfo.inRanked then
					debugNearestCampInfo.reason = "not_selected_by_algorithm";
				end
			end
			segmentCheckpoints = buildSegmentCheckpoints(hero, route, opt.checkpointCount:Get());
			if (#smoothCheckpoints ~= #segmentCheckpoints) then
				smoothCheckpoints = {};
				for i, seg in ipairs(segmentCheckpoints) do
					smoothCheckpoints[i] = {};
					for j, pt in ipairs(seg) do
						smoothCheckpoints[i][j] = Vector(pt.x, pt.y, pt.z);
					end
				end
			end
			if (#segmentCheckpoints > 0) then
				currentSegmentIndex = math.max(1, math.min(currentSegmentIndex, #segmentCheckpoints));
				local seg = segmentCheckpoints[currentSegmentIndex];
				if (seg and (#seg > 0)) then
					local lastPt = seg[#seg];
					if ((lastPt - heroPos):Length2D() <= opt.advanceDistance:Get()) then
						currentSegmentIndex = math.min(currentSegmentIndex + 1, #segmentCheckpoints);
					end
				end
			end
			if (lastHeroPos and ((heroPos - lastHeroPos):Length2D() > 2000)) then
				currentSegmentIndex = 1;
			end
			lastHeroPos = heroPos;
			for i = 1, #route do
				if not smoothRouteNodes[i] then
					local p = route[i].pos;
					smoothRouteNodes[i] = Vector(p.x, p.y, p.z);
				end
			end
		else
			route = {};
			segmentCheckpoints = {};
			smoothCheckpoints = {};
			smoothRouteNodes = {};
			currentSegmentIndex = 1;
			if debugCampEnabled and debugNearestCampInfo then
				debugNearestCampInfo.reason = "optimized_disabled";
			end
		end
		profileUpdate = os.clock() - tickStart;
	end
end;
FarmPattern.OnDraw = function()
	-- Проверка наличия Render API
	if not Render then
		return;
	end
	if not opt.enabled:Get() then
		return;
	end
	-- Не рисуем ничего пока игра не началась
	if not isGameStarted() then
		return;
	end
	local hero = getLocalHero();
	if (not hero or not Entity.IsAlive(hero)) then
		return;
	end
	if (not opt.optimized:Get() or (#route == 0)) then
		return;
	end
	local drawStart = os.clock();
	smoothTowards();
	smoothRouteNodesTowards();
	local seconds = timeSinceStart();
	local sec = math.floor(seconds % 60);
	local minuteSec = seconds % 60;
	local heroPos = Entity.GetAbsOrigin(hero);
	local firstStackStartSec = 54;
	local hero2D, okHero = Render.WorldToScreen(heroPos);
	local targetAlpha = (opt.showVisualization:Get() and 255) or 0;
	if (displayAlpha < targetAlpha) then
		displayAlpha = math.min(displayAlpha + alphaStep, targetAlpha);
	elseif (displayAlpha > targetAlpha) then
		displayAlpha = math.max(displayAlpha - alphaStep, targetAlpha);
	end
	if (displayAlpha <= 0) then
		return;
	end
	local a = math.floor(displayAlpha);
	Render.SetGlobalAlpha(a / 255);
	local maxPoints = math.min(opt.pointsCount:Get(), #route);
	local totalGold = 0;
	for i = 1, maxPoints do
		totalGold = totalGold + route[i].gold;
	end
	local header = string.format("Farm Path: %d point(s), ~%d gold", maxPoints, math.floor(totalGold));
	local algoIdx = opt.algorithm:Get();
	local algoName = ((algoIdx == 0) and "Greedy") or ((algoIdx == 1) and "Optimal") or "Beam";
	local scale = ((opt.panelScale and opt.panelScale:Get()) or 100) / 100;
	local fontScale = scale;
	local fontSize = math.max(10, math.floor(baseFontSize * scale));

	-- Хелперы
	local function ts(text, size)
		local s = Render.TextSize(fontMain, size or fontSize, text);
		return s.x, s.y;
	end
	local function drawText(x, y, text, r, g, b, alpha)
		Render.Text(fontMain, fontSize, text, Vec2(x + 1, y + 1), Color(0, 0, 0, math.min(alpha or 255, 150)));
		Render.Text(fontMain, fontSize, text, Vec2(x, y), Color(r or 255, g or 255, b or 255, alpha or 255));
	end
	local function drawArrow(from, to, color, size)
		local adx, ady = to.x - from.x, to.y - from.y;
		local len = math.sqrt(adx * adx + ady * ady);
		if len < 30 then return; end
		adx, ady = adx / len, ady / len;
		local nx, ny = -ady, adx;
		local mx, my = (from.x + to.x) * 0.5, (from.y + to.y) * 0.5;
		Render.FilledTriangle({
			Vec2(mx + adx * size, my + ady * size),
			Vec2(mx - adx * size * 0.4 + nx * size * 0.5, my - ady * size * 0.4 + ny * size * 0.5),
			Vec2(mx - adx * size * 0.4 - nx * size * 0.5, my - ady * size * 0.4 - ny * size * 0.5),
		}, color);
	end

	local line1 = header;
	local l1w, l1h = ts(line1);
	local pad = 8;
	local gap = 8;
	local segBlockW = 10;
	local segBlockH = 6;
	local segGap = 2;
	local segW = ((maxPoints > 0) and ((maxPoints * (segBlockW + segGap)) - segGap)) or 0;
	local segH = segBlockH;

	local function badgeSize(text)
		local tw, th = ts(text);
		return tw + 14, math.max(16, th + 6);
	end
	local badge1 = string.format("Algo: %s", algoName);
	local badge2 = (opt.dynamicUpdate:Get() and "Live") or "Static";
	local badge3 = string.format("Pts: %d", maxPoints);
	local b1w, b1h = badgeSize(badge1);
	local b2w, b2h = badgeSize(badge2);
	local b3w, b3h = badgeSize(badge3);
	local badgesW = b1w + 6 + b2w + 6 + b3w;
	local badgesH = math.max(b1h, b2h, b3h);
	local effBarW = math.max(260, l1w);
	local effBarH = 6;
	local timeBarW = effBarW;
	local timeBarH = 6;
	local effTextH = 16;
	local contentW = math.max(l1w, segW, badgesW, effBarW);
	local contentH = l1h + gap + segH + gap + badgesH + gap + effBarH + 4 + effTextH + gap + timeBarH;
	local panelW = math.floor((contentW + (pad * 2)) * scale);
	local panelH = math.floor((contentH + (pad * 2)) * scale);
	local tl = Vec2(hud.x, hud.y);
	local br = Vec2(hud.x + panelW, hud.y + panelH);

	-- Драг панели
	local cx, cy = Input.GetCursorPos();
	local cursor = Vec2(cx, cy);
	if (opt.ctrlToDrag:Get() and Input.IsKeyDown(KEY_CTRL) and Input.IsKeyDownOnce(KEY_MOUSE1) and (cursor.x >= tl.x) and (cursor.x <= br.x) and (cursor.y >= tl.y) and (cursor.y <= br.y)) then
		dragging = true;
		dragDelta = tl - cursor;
	end
	if (dragging and Input.IsKeyDown(KEY_MOUSE1)) then
		local mx, my = Input.GetCursorPos();
		hud.x = mx + dragDelta.x;
		hud.y = my + dragDelta.y;
	end
	if (dragging and not Input.IsKeyDown(KEY_MOUSE1)) then
		dragging = false;
	end

	-- Панель HUD
	local vc = opt.visualColor:Get();
	local vcr, vcg, vcb = math.floor(vc.r), math.floor(vc.g), math.floor(vc.b);
	Render.Blur(tl, br, 1.0, 1.0, 8);
	Render.FilledRect(tl, br, Color(12, 12, 20, 140), 8);
	-- Тонкая акцентная линия сверху (gradient fade)
	Render.Gradient(
		Vec2(tl.x + 8, tl.y), Vec2(tl.x + math.floor(panelW * 0.6), tl.y + 2),
		Color(vcr, vcg, vcb, 200), Color(vcr, vcg, vcb, 0),
		Color(vcr, vcg, vcb, 200), Color(vcr, vcg, vcb, 0), 1);

	local tx = tl.x + math.floor(pad * scale);
	local ty = tl.y + math.floor(pad * scale);

	-- Заголовок
	drawText(tx, ty, line1, 255, 255, 255, 255);
	local sepAlpha = 35;
	local sepX2 = br.x - math.floor(pad * scale);
	Render.Line(Vec2(tx, ty + l1h + math.floor(gap * 0.4 * scale)), Vec2(sepX2, ty + l1h + math.floor(gap * 0.4 * scale)), Color(vcr, vcg, vcb, sepAlpha), 1);

	-- Сегменты маршрута
	local segY = ty + math.floor(l1h + (gap * scale));
	local col = opt.visualColor:Get();
	local cr, cg, cb = math.floor(col.r), math.floor(col.g), math.floor(col.b);
	for i = 1, maxPoints do
		local node = route[i];
		local isJ = node and node.isJungle;
		local x1 = tx + math.floor((i - 1) * (segBlockW + segGap) * scale);
		local x2 = x1 + math.floor(segBlockW * scale);
		local y1 = segY;
		local y2 = segY + math.floor(segBlockH * scale);
		local rr, gg, bb = cr, cg, cb;
		if isJ then
			rr, gg, bb = 255, 165, 0;
		end
		Render.FilledRect(Vec2(x1, y1), Vec2(x2, y2), Color(0, 0, 0, 160), 2);
		Render.FilledRect(Vec2(x1 + 1, y1 + 1), Vec2(x2 - 1, y2 - 1), Color(rr, gg, bb, 220), 2);
	end

	-- Бейджи
	local by = ty + math.floor(l1h + (gap * scale) + (segH * scale) + (gap * scale));
	local function drawBadge(text, x, y, colArr, alpha)
		local tw, th = ts(text);
		local bx1, by1 = x, y;
		local bx2, by2 = x + tw + 14, y + th + 6;
		Render.FilledRect(Vec2(bx1, by1), Vec2(bx2, by2), Color(colArr[1], colArr[2], colArr[3], 210), 6);
		drawText(x + 8, y + 3, text, 255, 255, 255, 255);
		return bx2;
	end
	local xBadge = tx;
	local colAlgo = {52,152,219};
	local colLive = (opt.dynamicUpdate:Get() and {46,204,113}) or {127,140,141};
	local colPts = {52,73,94};
	xBadge = drawBadge(badge1, xBadge, by, colAlgo, 255) + 6;
	xBadge = drawBadge(badge2, xBadge, by, colLive, 255) + 6;
	_ = drawBadge(badge3, xBadge, by, colPts, 255);
	Render.Line(Vec2(tx, by + badgesH + math.floor(gap * 0.4 * scale)), Vec2(sepX2, by + badgesH + math.floor(gap * 0.4 * scale)), Color(vcr, vcg, vcb, sepAlpha), 1);

	-- Efficiency bar
	local effY = by + math.floor(badgesH + (gap * scale));
	local barX1, barY1 = tx, effY;
	local barX2, barY2 = tx + math.floor(effBarW * scale), effY + math.floor(effBarH * scale);
	Render.FilledRect(Vec2(barX1, barY1), Vec2(barX2, barY2), Color(20, 20, 20, 160), 4);

	local ms = NPC.GetMoveSpeed(hero);
	local totalTime = 0;
	local totalG = 0;
	local curPos = heroPos;
	for i = 1, maxPoints do
		local node = route[i];
		if node then
			totalG = totalG + (node.gold or 0);
			local travel = GridNav.GetTravelTime(curPos, node.pos, false, nil, ms);
			local clear = estimateClearSeconds(node);
			totalTime = totalTime + travel + clear;
			curPos = node.pos;
		end
	end
	local eff = ((totalTime > 0) and (totalG / totalTime)) or 0;
	local effMin = opt.minEfficiency:Get();
	local effMax = math.max(effMin + 10, effMin * 2);
	local tEff = 0;
	if (effMax > effMin) then
		tEff = (eff - effMin) / (effMax - effMin);
	end
	tEff = math.max(0, math.min(1, tEff));

	local function mix(a0, b0, t0)
		return a0 + ((b0 - a0) * t0);
	end
	local rEff = math.floor(mix(231, 46, tEff));
	local gEff = math.floor(mix(76, 204, tEff));
	local bEff = math.floor(mix(60, 113, tEff));
	local fillW = math.floor(effBarW * scale * tEff);
	Render.FilledRect(Vec2(barX1, barY1), Vec2(barX1 + fillW, barY2), Color(rEff, gEff, bEff, 220), 4);

	local effText = string.format("%.1f g/s (min %.1f)", eff, effMin);
	local etw, eth = ts(effText);
	local etx = barX1 + math.floor((math.floor(effBarW * scale) - etw) * 0.5);
	local ety = barY2 + math.floor(2 * scale);
	drawText(etx, ety, effText, 255, 255, 255, 255);

	-- Time bar (stack timing)
	local tbarY = ety + math.max(eth, math.floor(effTextH * fontScale)) + math.floor(6 * scale);
	local tbX1, tbY1 = tx, tbarY;
	local tbX2, tbY2 = tx + math.floor(timeBarW * scale), tbarY + math.floor(timeBarH * scale);
	Render.FilledRect(Vec2(tbX1, tbY1), Vec2(tbX2, tbY2), Color(20, 20, 20, 160), 4);

	local scaledTBW = math.floor(timeBarW * scale);
	local stackStart = math.floor(((firstStackStartSec or 60) / 60) * scaledTBW);
	local stackEnd = math.floor((59 / 60) * scaledTBW);
	Render.FilledRect(Vec2(tbX1 + stackStart, tbY1), Vec2(tbX1 + stackEnd, tbY2), Color(255, 165, 0, 160), 4);
	for _, m in ipairs({0, 15, 30, 45, 60}) do
		local mpos = tbX1 + math.floor((m / 60) * scaledTBW);
		Render.Line(Vec2(mpos, tbY1 - 1), Vec2(mpos, tbY2 + 1), Color(255, 255, 255, 40), 1);
	end

	local targetCursorX = (sec / 60) * scaledTBW;
	timelineCursorX = timelineCursorX + ((targetCursorX - timelineCursorX) * 0.25);
	local cursorHalf = math.max(1, math.floor(1 * scale));
	Render.FilledRect(Vec2((tbX1 + math.floor(timelineCursorX)) - cursorHalf, tbY1 - 2), Vec2(tbX1 + math.floor(timelineCursorX) + cursorHalf, tbY2 + 2), Color(255, 255, 255, 200), 3);

	if opt.debugNearestCamp:Get() then
		local function yn(v)
			return v and "Y" or "N";
		end
		local dbgX = tx;
		local dbgY = tbY2 + math.floor(8 * scale);
		local lineStep = math.max(12, math.floor(fontSize * 0.95));
		if debugNearestCampInfo then
			local dbgReason = tostring(debugNearestCampInfo.reason or "n/a");
			local dbgIndex = tostring(debugNearestCampInfo.index or -1);
			local dbgDist = safeNumber(debugNearestCampInfo.dist, -1);
			local dbgSec = safeInt(debugNearestCampInfo.sec, sec);
			local dbgGold = safeInt(debugNearestCampInfo.gold, 0);
			local dbgCreeps = safeInt(debugNearestCampInfo.creepCount, 0);
			local dbgEff = safeNumber(debugNearestCampInfo.eff, 0);
			local dbgMinEff = safeNumber(debugNearestCampInfo.minEff, opt.minEfficiency:Get());
			local dbgBias = safeNumber(debugNearestCampInfo.stackBiasNow, stackBiasWeight(true));
			local dbgRank = safeInt(debugNearestCampInfo.rankIndex, 0);
			local dbgRouteIndex = safeInt(debugNearestCampInfo.routeIndex, 0);
			drawText(dbgX, dbgY, string.format("CampDbg #%s d=%.0f sec=%d reason=%s", dbgIndex, dbgDist, dbgSec, dbgReason), 255, 220, 180, 255);
			dbgY = dbgY + lineStep;
			drawText(dbgX, dbgY, string.format("g=%d creeps=%d eff=%.2f min=%.2f bias=%.2f", dbgGold, dbgCreeps, dbgEff, dbgMinEff, dbgBias), 230, 230, 230, 255);
			dbgY = dbgY + lineStep;
			drawText(dbgX, dbgY, string.format("search=%s ally=%s add=%s ranked=%s rank=%d route=%s idx=%d", yn(debugNearestCampInfo.inSearch), yn(debugNearestCampInfo.blockedByAlly), yn(debugNearestCampInfo.addedToSpots), yn(debugNearestCampInfo.inRanked), dbgRank, yn(debugNearestCampInfo.inRoute), dbgRouteIndex), 200, 220, 255, 255);
			dbgY = dbgY + lineStep;
			drawText(dbgX, dbgY, string.format("vision=%s fow=%s fallback=%s should=%s dup=%s", yn(debugNearestCampInfo.hasVision), yn(debugNearestCampInfo.canSeePosition), yn(debugNearestCampInfo.usedFallback), yn(debugNearestCampInfo.shouldHaveCreeps), yn(debugNearestCampInfo.duplicateSpot)), 180, 255, 210, 255);
		else
			drawText(dbgX, dbgY, "CampDbg: no data", 255, 220, 180, 255);
		end
	end

	-- Dynamic checkpoints
	if opt.dynamicUpdate:Get() then
		local segs = smoothCheckpoints;
		if (currentSegmentIndex <= #segs) then
			for _, p in ipairs(segs[currentSegmentIndex]) do
				local s2d, ok = Render.WorldToScreen(p);
				if ok then
					Render.FilledCircle(s2d, 4, Color(255, 165, 0, 200));
				end
			end
		end
		for si = currentSegmentIndex + 1, #segs do
			for _, p in ipairs(segs[si]) do
				local s2d, ok = Render.WorldToScreen(p);
				local fo = math.floor(255 * (opt.futureOpacity:Get() / 100));
				if ok then
					Render.FilledCircle(s2d, 3, Color(255, 165, 0, fo));
				end
			end
		end
	end

	-- Route visualization
	local prev2D = nil;
	local prevOk = false;
	local thickness = opt.lineThickness:Get();
	local circleSize = opt.circleSize:Get();

	for i = 1, maxPoints do
		local node = route[i];
		local nodePos = smoothRouteNodes[i] or node.pos;
		local nodeStackStartSec = 54;
		local p2d, ok = Render.WorldToScreen(nodePos);
		local t = ((maxPoints > 1) and ((i - 1) / (maxPoints - 1))) or 0;
		local r = math.floor(cr + ((255 - cr) * 0.25 * t));
		local g = math.floor(cg + ((255 - cg) * 0.25 * t));
		local b = math.floor(cb + ((255 - cb) * 0.25 * t));
		local nodeColor = Color(r, g, b, 255);
		local darkColor = Color(math.floor(r * 0.6), math.floor(g * 0.6), math.floor(b * 0.6), 255);

		local showStack = false;
						if (node.isJungle and nodeStackStartSec and (minuteSec >= nodeStackStartSec) and (minuteSec < 60)) then
			showStack = true;
			r = 255 - cr;
			g = 255 - cg;
			b = 255 - cb;
			nodeColor = Color(r, g, b, 255);
		end

		-- Lines with direction arrows
		if (i == 1) then
			if okHero or ok then
				Render.Line(hero2D, p2d, nodeColor, thickness);
				drawArrow(hero2D, p2d, nodeColor, 7);
			end
		else
			if (prevOk or ok) and prev2D then
				Render.Line(prev2D, p2d, nodeColor, thickness);
				drawArrow(prev2D, p2d, nodeColor, 7);
			end
		end

		-- Route point rendering
		if ok then
			if (i == 1) then
				local pulse = math.sin(os.clock() * 4) * 0.3 + 0.7;
				Render.CircleGradient(p2d, math.floor(circleSize * 2.2), Color(r, g, b, 0), Color(r, g, b, math.floor(60 * pulse)));
			end
			Render.FilledCircle(p2d, circleSize + 1, darkColor);
			Render.FilledCircle(p2d, circleSize - 1, nodeColor);

			if opt.showPointIndex:Get() then
				local label = tostring(i);
				local lsz = Render.TextSize(fontBold, 13, label);
				Render.Text(fontBold, 13, label, Vec2(p2d.x - lsz.x * 0.5 + 1, p2d.y - lsz.y * 0.5 + 1), Color(0, 0, 0, 180));
				Render.Text(fontBold, 13, label, Vec2(p2d.x - lsz.x * 0.5, p2d.y - lsz.y * 0.5), Color(255, 255, 255, 255));
			end

			if showStack then
				local text = "STACK!";
				local ssz = Render.TextSize(fontBold, 13, text);
				local stx = p2d.x - ssz.x * 0.5;
				local sty = p2d.y - circleSize - ssz.y - 6;
				local stackPulse = math.sin(os.clock() * 6) * 0.15 + 0.85;
				Render.FilledRect(Vec2(stx - 4, sty - 2), Vec2(stx + ssz.x + 4, sty + ssz.y + 2), Color(200, 60, 0, math.floor(220 * stackPulse)), 4);
				Render.Text(fontBold, 13, text, Vec2(stx + 1, sty + 1), Color(0, 0, 0, 150));
				Render.Text(fontBold, 13, text, Vec2(stx, sty), Color(255, 255, 255, 255));
			end

			if opt.showGold:Get() then
				local value = tostring(math.floor(node.gold));
				local gsz = Render.TextSize(fontMain, 12, value);
				local gx = p2d.x - gsz.x * 0.5;
				local gy = p2d.y + circleSize + 3;
				Render.FilledRect(Vec2(gx - 3, gy - 1), Vec2(gx + gsz.x + 3, gy + gsz.y + 1), Color(0, 0, 0, 140), 3);
				Render.Text(fontMain, 12, value, Vec2(gx + 1, gy + 1), Color(0, 0, 0, 150));
				Render.Text(fontMain, 12, value, Vec2(gx, gy), Color(255, 215, 0, 255));
			end
		end

		prev2D, prevOk = p2d, ok;
	end

	Render.ResetGlobalAlpha();
	profileDraw = os.clock() - drawStart;

	-- Performance profiler
	if opt.showProfile:Get() then
		local algoIdx = opt.algorithm:Get();
		local algoLabel = ((algoIdx == 0) and "Greedy") or ((algoIdx == 1) and "Optimal") or "Beam";
		local profY = hud.y + panelH + 4;
		local profLines = {
			string.format("Update: %.2fms  Route(%s): %.2fms  Draw: %.2fms",
				profileUpdate * 1000, algoLabel, profileRoute * 1000, profileDraw * 1000),
			string.format("Spots: %d  Allies cached: %d  AoE: %s",
				#spots, #cachedAllyPositions, cachedHasAoE and "Y" or "N"),
		};
		for pi, line in ipairs(profLines) do
			drawText(hud.x + 6, profY + (pi - 1) * 14, line, 255, 200, 100, 255);
		end
	end
end;
return {OnUpdate=FarmPattern.OnUpdate,OnDraw=FarmPattern.OnDraw};
