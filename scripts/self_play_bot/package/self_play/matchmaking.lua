local matchmaking = {}
local JSON = require("assets.JSON")
local protobuf = require("protobuf")
local chronos = require("chronos")
local account = require("self_play.queue_account")
local localization = require("self_play.localization")

local modes = {"All Pick", "Ranked All Pick", "Single Draft", "Turbo", "Random Draft"}
local modeIDs = {1, 22, 4, 23, 3}
local modeDefaults = {"All Pick"}
local rotationLabels = {"Off", "1 game", "2 games", "3 games", "5 games"}
local rotationCounts = {0, 1, 2, 3, 5}
local regions = {"US West", "US East", "EU West", "SE Asia", "Brazil", "Argentina", "Russia", "EU East", "Australia", "South Africa", "Dubai", "Chile", "Peru", "India", "Japan"}
local regionBits = {0, 1, 2, 3, 5, 6, 7, 8, 9, 10, 13, 14, 15, 16, 19}
local roleFlags = {[0] = 31, 1, 4, 2, 8, 16}
local queueConfig = "self_play_queue"
local state = {now = 0, nextTick = 0, nextQueue = 0, nextAccept = 0, enabled = false, status = "Disabled",
	index = 0, games = 0, rotation = 0}

local function send(name, id, body)
	local request = protobuf.encodeFromJSON(name, next(body) == nil and "{}" or JSON:encode(body))
	GC.SendMessage(request.binary, id, request.size)
	protobuf.free(request.binary)
end

function matchmaking.create(group)
	return {
		enabled = group:Switch("Auto queue and accept", false),
		mode = group:MultiCombo("Queue mode", modes, modeDefaults),
		rotation = group:Combo("Queue rotation", rotationLabels, 0),
		regions = group:MultiCombo("Queue regions", regions, {}),
		status = group:Label("Auto queue: disabled"),
	}
end

local function selectedModes(ui)
	local selected = {}
	for _, name in ipairs(ui.mode:ListEnabled()) do
		for index, mode in ipairs(modes) do if name == mode then selected[#selected + 1] = index; break end end
	end
	return selected
end

function matchmaking.request(ui, role, lowPriority)
	local selected = selectedModes(ui)
	local mask = 0
	for _, name in ipairs(ui.regions:ListEnabled()) do
		for index, region in ipairs(regions) do if name == region then mask = mask + 2 ^ regionBits[index]; break end end
	end
	if mask == 0 or #selected == 0 then return nil end
	local active = selected
	if state.rotation > 0 and #selected > 1 then active = {selected[state.index % #selected + 1]} end
	if lowPriority then active = {3} end
	local gameModes = 0
	for _, index in ipairs(active) do gameModes = gameModes + 2 ^ modeIDs[index] end
	local ranked = not lowPriority and #active == 1 and active[1] == 2
	return {matchgroups = mask, game_modes = gameModes,
		match_type = ranked and 4 or 0, lane_selection_flags = ranked and (roleFlags[role] or 31) or 0,
		client_version = account.clientVersion()}, #active == 1 and modes[active[1]] or "several modes"
end

function matchmaking.message(data)
	state.now = chronos.nanotime()
	account.message(data)
	local id = data.msg_type % 2147483648
	if id == 7033 and data.binary_buffer_send and not state.enabled then
		state.cancel = nil
	elseif id == 7036 and data.binary_buffer_send then
		if not state.cancel and (state.pending or state.ownedSearch) then state.cancel = {started = state.now, nextSend = state.now + 0.25} end
		state.pending, state.searching = nil, false
		state.ownedSearch = false
		state.nextQueue, state.status = state.now + 30, "Search stopped; retry"
	elseif id == 8055 and data.binary_buffer_recv and state.pending then
		local result = JSON:decode(protobuf.decodeToJSON("CMsgStartFindingMatchResult", data.binary_buffer_recv, data.size))
		state.pending = nil
		local code = result.result
		local lowPriorityError = (result.error_token or ""):lower():gsub("_", ""):find("lowpriority", 1, true) ~= nil
		Log.Write("[SelfPlay queue] GC result: " .. tostring(code) .. " " .. (result.error_token or ""))
		if code == 1 or code == 2 or code == "k_EStartFindingMatchResult_OK" or code == "k_EStartFindingMatchResult_AlreadySearching" then
			state.searching, state.status = true, "Searching"
			if code == 2 or code == "k_EStartFindingMatchResult_AlreadySearching" then state.ownedSearch = false end
			state.searchGrace = state.now + 15
		elseif code == 106 or code == "k_EStartFindingMatchResult_CompetitiveNoLowPriority" or lowPriorityError then
			state.forcedSingleDraft, state.nextQueue, state.status = true, state.now + 5, "Low priority: switching to Single Draft"
			account.refresh()
		elseif code == 105 or code == "k_EStartFindingMatchResult_ClientOutOfDate" then
			account.refresh(true)
			state.searching, state.nextQueue, state.status = false, state.now + 15, "Refreshing client version; retry"
		else
			state.searching, state.nextQueue = false, state.now + 60
			state.status = "Queue rejected: " .. tostring(result.error_token or code) .. "; retry"
		end
	end
	return true
end

local function cancelSearch()
	state.now = chronos.nanotime()
	local cancel = state.cancel
	if not cancel then return false end
	local play = Panorama.GetPanelByName("DOTAPlay", true)
	local searching = account.searching() == true or play and play:HasClass("FindingMatch")
	if Engine.IsInGame() or Engine.IsInLobby() or not searching and state.now >= cancel.started + 1.5 then
		state.cancel = nil
		state.status = state.enabled and "Waiting to queue" or "Disabled"
		return false
	end
	if state.now >= cancel.nextSend then
		send("CMsgStopFindingMatch", 7036, {})
		cancel.nextSend = state.now + 0.75
		if state.now >= (cancel.nextRefresh or cancel.started + 3) then
			account.refresh()
			cancel.nextRefresh = state.now + 3
		end
	end
	state.status = "Stopping search"
	return true
end

local function step(ui, role)
	if Engine.CanAcceptMatch() then
		if state.now >= state.nextAccept then Engine.AcceptMatch(1); state.nextAccept = state.now + 3 end
		state.acceptedUntil = state.now + 60
		state.status, state.nextQueue = "Match accepted; waiting to connect", state.now + 15
		state.blocked = true
		return state.now
	end
	local play = Panorama.GetPanelByName("DOTAPlay", true)
	if Engine.IsInGame() or Players.GetLocal() or Heroes.GetLocal() then
		state.pending, state.searching, state.ownedSearch = nil, false, false
		state.acceptedUntil = nil
		state.status, state.nextQueue = "Match in progress", state.now + 10
		state.blocked = true
		return state.now
	end
	local blocked = not play and "Waiting for play menu"
		or play:HasClass("Connecting") and "Connecting to match"
		or (play:HasClass("CanReconnect") or play:HasClass("CanDisconnect")) and "Waiting for current match to finish"
		or Engine.IsInLobby() and "In lobby or hero selection"
	if blocked then
		state.status, state.nextQueue = blocked, state.now + 10
		state.blocked = true
		return state.now
	end
	if state.acceptedUntil then
		if state.now < state.acceptedUntil then
			state.status, state.nextQueue = "Match accepted; waiting to connect", state.now + 10
			state.blocked = true
			return state.now
		end
		state.acceptedUntil = nil
		Log.Write("[SelfPlay queue] Accepted match did not launch within 60s; re-queueing")
	end
	if state.blocked then state.blocked, state.status = false, "Waiting to queue" end
	if state.now >= (state.nextRefresh or 0) then
		account.refresh()
		state.nextRefresh = state.now + 20
	end
	local partySearching = account.searching()
	if partySearching == true or play:HasClass("FindingMatch") then
		state.pending, state.searching, state.status = nil, true, "Searching"
		state.searchGrace = state.now + 3
		return state.now
	end
	if state.pending then
		if state.now < state.pending + 15 then return state.now end
		account.refresh()
		state.pending, state.nextQueue, state.status = nil, state.now + 45, "No queue confirmation; retry"
		return state.now
	end
	if state.searching then
		if state.now < state.searchGrace then return state.now end
		state.searching, state.ownedSearch, state.nextQueue = false, false, state.now + 15
		state.status = "Search ended"
	end
	local lowPriority = account.lowPriority() or state.forcedSingleDraft or play:HasClass("MatchDenied_LowPriorityLocal") or play:HasClass("MatchDenied_LowPriorityParty")
	local request, activeMode = matchmaking.request(ui, role, lowPriority)
	if not request then
		state.status = #selectedModes(ui) == 0 and "Select at least one queue mode" or "Select at least one queue region"
		return state.now
	end
	if not account.canLead() then state.status = "Waiting for party leader"; return state.now end
	local cooldown = account.cooldown()
	if cooldown > 0 then state.status = "Matchmaking cooldown (" .. math.ceil(cooldown) .. "s)"; return state.now end
	if not account.clientVersion() or not account.ready() and state.now < (state.syncUntil or 0) then
		state.status = "Waiting for account and queue data"
		return state.now
	end
	if state.status == "Waiting for party leader" or state.status == "Waiting for account and queue data"
		or state.status:find("Matchmaking cooldown", 1, true) or state.status:find("Select at least one queue", 1, true)
		then state.status = "Waiting to queue" end
	if state.now < state.nextQueue then return state.now end
	state.pending, state.ownedSearch, state.nextQueue = state.now, true, state.now + 30
	state.status = lowPriority and "Requesting Single Draft (low priority)" or "Requesting " .. activeMode
	Log.Write("[SelfPlay queue] " .. state.status .. " modes=" .. request.game_modes
		.. " regions=" .. request.matchgroups .. " version=" .. tostring(request.client_version))
	send("CMsgStartFindingMatch", 7033, request)
	return state.now
end

function matchmaking.update(ui, role)
	state.now = chronos.nanotime()
	local enabled = ui.enabled:Get()
	local rotation = rotationCounts[(ui.rotation:Get() or 0) + 1] or 0
	if rotation ~= state.rotation then
		state.rotation = rotation
		if rotation == 0 then
			state.index, state.games = 0, 0
		else
			state.index = math.max(0, Config.ReadInt(queueConfig, "rotationIndex", 0))
			state.games = math.max(0, Config.ReadInt(queueConfig, "gamesInCurrent", 0))
		end
		Config.WriteInt(queueConfig, "rotationIndex", state.index)
		Config.WriteInt(queueConfig, "gamesInCurrent", state.games)
	end
	if enabled ~= state.enabled then
		state.enabled, state.nextTick = enabled, 0
		if not enabled then
			local stop = state.pending or state.ownedSearch
			state.pending, state.searching, state.ownedSearch, state.forcedSingleDraft = nil, false, false, false
			state.acceptedUntil = nil
			if stop then
				state.cancel = {started = state.now, nextSend = state.now + 0.25}
				send("CMsgStopFindingMatch", 7036, {})
			end
			state.status = "Disabled"
		else
			account.refresh(true)
			state.syncUntil, state.nextRefresh = state.now + 8, state.now + 20
			state.nextQueue, state.status = state.now + 3, "Waiting to queue"
		end
	end
	if state.now < state.nextTick then return state.now end
	state.nextTick = state.now + 0.5
	if not cancelSearch() then
		if enabled then step(ui, role) else state.status = "Disabled" end
	end
	local status = state.status
	if enabled and not state.pending and not state.searching and state.now < state.nextQueue
		and (status == "Waiting to queue" or status == "Search ended" or status:find("retry", 1, true)
			or status:find("switching", 1, true) or status:find("Game ended", 1, true)) then
		status = status .. " (" .. math.ceil(state.nextQueue - state.now) .. "s)"
	end
	local displayed = localization.text("Auto queue: ") .. localization.queue(status)
	if state.displayed ~= displayed then
		ui.status:ForceLocalization(displayed)
		state.displayed = displayed
	end
	return state.now
end

function matchmaking.gameEnd()
	state.now = chronos.nanotime()
	state.cancel = nil
	state.pending, state.searching, state.ownedSearch, state.forcedSingleDraft = nil, false, false, false
	state.acceptedUntil = nil
	state.nextQueue, state.status = state.now + 10, "Game ended; waiting for client to return"
	if state.rotation > 0 then
		state.games = state.games + 1
		if state.games >= state.rotation then
			state.games, state.index = 0, state.index + 1
		end
		Config.WriteInt(queueConfig, "rotationIndex", state.index)
		Config.WriteInt(queueConfig, "gamesInCurrent", state.games)
	end
end

return matchmaking
