local persist = {}
local JSON = require("assets.JSON")

local section = "self_play_profile"
local historyMax = 8

function persist.load()
	local role = Config.ReadInt(section, "role", 0)
	local lane = Config.ReadInt(section, "lane", 0)
	local hero = Config.ReadString(section, "hero", "")
	if role < 0 or role > 5 then role = 0 end
	if lane < 0 or lane > 3 then lane = 0 end
	if hero == "" then hero = nil end
	return { role = role, lane = lane, hero = hero }
end

function persist.save(role, lane, hero)
	if role ~= nil then Config.WriteInt(section, "role", role) end
	if lane ~= nil then Config.WriteInt(section, "lane", lane) end
	if hero ~= nil then Config.WriteString(section, "hero", hero) end
end

function persist.history()
	local raw = Config.ReadString(section, "history", "")
	if raw == "" then return {} end
	local ok, list = pcall(function() return JSON:decode(raw) end)
	if not ok or type(list) ~= "table" then return {} end
	return list
end

function persist.pushHistory(hero, role)
	if not hero or hero == "" then return end
	local list = persist.history()
	local trimmed = {}
	for _, entry in ipairs(list) do
		if type(entry) == "table" and entry.hero ~= hero then trimmed[#trimmed + 1] = entry end
	end
	table.insert(trimmed, 1, { hero = hero, role = role or 0 })
	while #trimmed > historyMax do table.remove(trimmed) end
	Config.WriteString(section, "history", JSON:encode(trimmed))
end

return persist
