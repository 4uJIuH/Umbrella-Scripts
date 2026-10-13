local account = {}
local JSON = require("assets.JSON")
local protobuf = require("protobuf")

local state = {}
local version = tonumber(Config.ReadString("self_play_queue", "client_version", ""))
local names = {[2002] = "CSODOTAGameAccountClient", [2003] = "CSODOTAParty"}

local function clearParty()
	state.partyID, state.partyGames, state.partyState, state.partyOwner, state.leaderID, state.partyDisabled = nil, nil, nil, nil, nil, nil
end

local function rememberVersion(value)
	if not value or value <= 0 or value == version then return end
	version = value
	Config.WriteString("self_play_queue", "client_version", tostring(value))
end

local function object(typeID, blob, owner, removed)
	local name = names[typeID]
	if not name or not blob then return end
	local steamID = GC.GetSteamID()
	if typeID == 2002 and (not owner or owner.type ~= 1 or owner.id ~= steamID) then return end
	local data = JSON:decode(protobuf.decodeToJSONfromString(name, blob))
	if typeID == 2002 then
		state.games = not removed and (data.low_priority_games_remaining or 0) or nil
		state.untilDate = not removed and (data.low_priority_until_date or 0) or nil
		state.disabled = not removed and math.max(data.match_disabled_until_date or 0, data.account_disabled_until_date or 0) or nil
	elseif removed then
		if state.partyID == data.party_id then clearParty() end
	else
		local member = data.member_ids == nil and state.partyID == data.party_id
		for _, id in ipairs(data.member_ids or {}) do if id == steamID then member = true; break end end
		if not member then
			if state.partyID == data.party_id then clearParty() end
			return
		end
		state.partyID, state.partyGames, state.partyState = data.party_id, data.low_priority_games_remaining or 0, data.state or 0
		state.partyOwner, state.leaderID, state.partyDisabled = owner, data.leader_id, data.match_disabled_until_date or 0
	end
end

local function cache(data)
	for _, entry in ipairs(data.objects or {}) do
		for _, blob in ipairs(entry.object_data or {}) do object(entry.type_id, blob, data.owner_soid, false) end
	end
end

function account.message(data)
	local id = data.msg_type % 2147483648
	if id == 7033 and data.binary_buffer_send then
		local value = JSON:decode(protobuf.decodeToJSON("CMsgStartFindingMatch", data.binary_buffer_send, data.size))
		rememberVersion(value.client_version)
		return
	end
	if not data.binary_buffer_recv then return end
	local name = (id == 21 or id == 22 or id == 23) and "CMsgSOSingleObject"
		or id == 24 and "CMsgSOCacheSubscribed" or id == 25 and "CMsgSOCacheUnsubscribed"
		or id == 26 and "CMsgSOMultipleObjects" or id == 4004 and "CMsgClientWelcome"
	if not name then return end
	local value = JSON:decode(protobuf.decodeToJSON(name, data.binary_buffer_recv, data.size))
	if id == 24 then
		cache(value)
	elseif id == 4004 then
		rememberVersion(value.version)
		for _, entry in ipairs(value.outofdate_subscribed_caches or {}) do cache(entry) end
	elseif id == 26 then
		for _, key in ipairs({"objects_added", "objects_modified", "objects_removed"}) do
			for _, entry in ipairs(value[key] or {}) do object(entry.type_id, entry.object_data, value.owner_soid, key == "objects_removed") end
		end
	elseif id == 25 then
		local owner = value.owner_soid
		if owner and owner.type == 1 and owner.id == GC.GetSteamID() then state = {} end
		if owner and owner.id == state.partyID then clearParty() end
	else
		object(value.type_id, value.object_data, value.owner_soid, id == 23)
	end
end

function account.refresh(session)
	local steamID = GC.GetSteamID()
	if steamID == "" or steamID == "0" then return end
	if session or not version then
		local hello = protobuf.encodeFromJSON("CMsgClientHello", JSON:encode({engine = 1}))
		GC.SendMessage(hello.binary, 4006, hello.size)
		protobuf.free(hello.binary)
	end
	local request = protobuf.encodeFromJSON("CMsgSOCacheSubscriptionRefresh", JSON:encode({owner_soid = {type = 1, id = steamID}}))
	GC.SendMessage(request.binary, 28, request.size)
	protobuf.free(request.binary)
	local owner = state.partyOwner
	if owner and (owner.type ~= 1 or owner.id ~= steamID) then
		request = protobuf.encodeFromJSON("CMsgSOCacheSubscriptionRefresh", JSON:encode({owner_soid = owner}))
		GC.SendMessage(request.binary, 28, request.size)
		protobuf.free(request.binary)
	end
end

function account.ready()
	return state.games ~= nil and version ~= nil
end

function account.canLead()
	return state.leaderID == nil or state.leaderID == GC.GetSteamID()
end

function account.cooldown()
	return math.max(0, math.max(state.disabled or 0, state.partyDisabled or 0) - os.time())
end

function account.lowPriority()
	if (state.games or 0) > 0 or (state.partyGames or 0) > 0 then return true end
	return state.untilDate ~= nil and state.untilDate > os.time()
end

function account.searching()
	if state.partyState == nil then return nil end
	return state.partyState == 1 or state.partyState == "FINDING_MATCH"
end

function account.clientVersion()
	return version
end

return account
