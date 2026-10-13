local userBuilds = {}

local JSON = require("assets.JSON")
local catalog = require("self_play.catalog")

local config = "self_play_builds"
local legacy = "self_play_shop"

local state = {data = nil}

local function decode(raw)
	if type(raw) ~= "string" or raw == "" then return nil end
	local ok, data = pcall(JSON.decode, raw)
	if not ok or type(data) ~= "table" then return nil end
	return data
end

local function blank()
	return {version = 2, nextId = 1, builds = {}}
end

local function newId(data)
	local id = data.nextId or 1
	data.nextId = id + 1
	return "b" .. id
end

local function parseItems(raw)
	local items = {}
	if type(raw) == "string" then
		for entry in raw:gmatch("[^,]+") do
			local item = entry:gsub("%s", "")
			if item ~= "" then items[#items + 1] = item end
		end
	end
	return items
end

local function serialize(items)
	local clean = {}
	for _, name in ipairs(items or {}) do
		if type(name) == "string" and name ~= "" then clean[#clean + 1] = name end
	end
	return table.concat(clean, ",")
end

local function hasItems(raw)
	return #parseItems(raw) > 0
end

local function migrateLegacy(data)
	local migrated = blank()
	local records = {}
	for _, entry in ipairs(type(data) == "table" and data or {}) do
		if type(entry) == "table" and type(entry.hero) == "string" and catalog.heroes[entry.hero]
			and type(entry.items) == "string" and hasItems(entry.items) then
			records[#records + 1] = {hero = entry.hero, name = type(entry.name) == "string" and entry.name or "Custom",
				items = entry.items, updated = tonumber(entry.updated) or 0, active = entry.active == true}
		end
	end
	table.sort(records, function(a, b) return a.hero == b.hero and a.name < b.name or a.hero < b.hero end)
	for _, record in ipairs(records) do
		migrated.builds[#migrated.builds + 1] = {id = newId(migrated), hero = record.hero, name = record.name,
			items = record.items, updated = record.updated, active = record.active}
	end
	return migrated
end

local function migrateHeroMap(data)
	local migrated = blank()
	for hero, record in pairs(data.heroes or {}) do
		if type(record) == "table" then
			for name, items in pairs(record.builds or {}) do
				if type(items) == "string" and hasItems(items) then
					local active = record.active == name
					migrated.builds[#migrated.builds + 1] = {id = newId(migrated), hero = hero, name = name,
						items = items, updated = tonumber(record.updated) or 0, active = active}
				end
			end
		end
	end
	return migrated
end

function userBuilds.save()
	if not state.data then return end
	Config.WriteString(config, "data", JSON:encode(state.data))
end

function userBuilds.load()
	if state.data then return state.data end
	local decoded = decode(Config.ReadString(config, "data", ""))
	if not decoded then
		state.data = blank()
	elseif type(decoded.builds) == "table" then
		state.data = decoded.version == 2 and decoded or migrateHeroMap(decoded)
		state.data.nextId = tonumber(state.data.nextId) or (#state.data.builds + 1)
	else
		state.data = migrateHeroMap(decoded)
		state.data.nextId = tonumber(state.data.nextId) or (#state.data.builds + 1)
	end
	local name = Config.ReadString(legacy, "customHero", "")
	local items = Config.ReadString(legacy, "customItems", "")
	if Config.ReadInt(legacy, "customMigrated", 0) ~= 1 then
		Config.WriteInt(legacy, "customMigrated", 1)
		local short = name:lower():gsub("^npc_dota_hero_", ""):gsub("%s", "_")
		local hero = "npc_dota_hero_" .. short
		if items ~= "" and catalog.heroes[hero] then
			local found = false
			for _, build in ipairs(state.data.builds) do
				if build.hero == hero and build.items == items then found = true; break end
			end
			if not found then
				state.data.builds[#state.data.builds + 1] = {id = newId(state.data), hero = hero, name = "Custom",
					items = items, updated = os.time(), active = true}
			end
		end
	end
	userBuilds.save()
	return state.data
end

local function sorted(list)
	table.sort(list, function(a, b)
		if a.hero ~= b.hero then return a.hero < b.hero end
		if a.name ~= b.name then return a.name < b.name end
		return a.id < b.id
	end)
	return list
end

function userBuilds.all()
	return sorted(userBuilds.load().builds)
end

function userBuilds.heroes()
	local seen, list = {}, {}
	for _, build in ipairs(userBuilds.all()) do
		if not seen[build.hero] then seen[build.hero] = true; list[#list + 1] = build.hero end
	end
	return list
end

function userBuilds.forHero(hero)
	local list = {}
	for _, build in ipairs(userBuilds.all()) do
		if build.hero == hero then list[#list + 1] = build end
	end
	return list
end

function userBuilds.get(id)
	if not id then return nil end
	for _, build in ipairs(userBuilds.load().builds) do
		if build.id == id then return build end
	end
	return nil
end

function userBuilds.has(hero)
	for _, build in ipairs(userBuilds.all()) do
		if build.hero == hero then return true end
	end
	return false
end

function userBuilds.items(id)
	local build = userBuilds.get(id)
	return build and parseItems(build.items) or {}
end

function userBuilds.count(id)
	return #userBuilds.items(id)
end

function userBuilds.create(hero, name, items)
	if not hero or not catalog.heroes[hero] or not name or name == "" then return nil end
	local data = userBuilds.load()
	local build = {id = newId(data), hero = hero, name = name, items = serialize(items), updated = os.time()}
	data.builds[#data.builds + 1] = build
	userBuilds.save()
	return build.id
end

function userBuilds.update(id, items)
	local build = userBuilds.get(id)
	if not build then return false end
	build.items, build.updated = serialize(items), os.time()
	userBuilds.save()
	return true
end

function userBuilds.rename(id, name)
	local build = userBuilds.get(id)
	if not build or not name or name == "" then return false end
	build.name, build.updated = name, os.time()
	userBuilds.save()
	return true
end

function userBuilds.copy(id, name)
	local build = userBuilds.get(id)
	if not build then return nil end
	local data = userBuilds.load()
	local copy = {id = newId(data), hero = build.hero, name = name or (build.name .. " copy"), items = build.items, updated = os.time()}
	data.builds[#data.builds + 1] = copy
	userBuilds.save()
	return copy.id
end

function userBuilds.remove(id)
	local build = userBuilds.get(id)
	if not build then return false end
	local data = userBuilds.load()
	for index, entry in ipairs(data.builds) do
		if entry.id == id then table.remove(data.builds, index); break end
	end
	userBuilds.save()
	return true
end

function userBuilds.active(hero)
	if not hero then return nil end
	for _, build in ipairs(userBuilds.load().builds) do
		if build.hero == hero and build.active then return build.id end
	end
	return nil
end

function userBuilds.setActive(hero, id)
	local build = userBuilds.get(id)
	if not build or build.hero ~= hero then return false end
	for _, entry in ipairs(userBuilds.load().builds) do
		entry.active = entry.id == id and true or nil
	end
	userBuilds.save()
	return true
end

function userBuilds.plan(hero)
	local id = userBuilds.active(hero)
	if not id then return nil end
	return userBuilds.items(id)
end

function userBuilds.export()
	return Config.ReadString(config, "data", "")
end

function userBuilds.import(raw)
	local decoded = decode(raw)
	if not decoded then return false end
	local data = type(decoded.builds) == "table" and decoded.version == 2 and decoded or migrateLegacy(decoded)
	if #data.builds == 0 then return false end
	local known, merged, index = {}, {}, tonumber(data.nextId) or (#data.builds + 1)
	for _, build in ipairs(userBuilds.load().builds) do
		known[build.id], merged[#merged + 1] = true, build
	end
	for _, build in ipairs(data.builds) do
		if type(build) == "table" and type(build.id) == "string"
			and type(build.hero) == "string" and catalog.heroes[build.hero] and type(build.items) == "string"
			and type(build.name) == "string" and build.name ~= "" then
			local id = build.id
			while known[id] do id = id .. "_" .. index; index = index + 1 end
			known[id] = true
			merged[#merged + 1] = {id = id, hero = build.hero, name = build.name, items = build.items,
				updated = tonumber(build.updated) or os.time(), active = build.active == true}
		end
	end
	state.data = {version = 2, nextId = index, builds = merged}
	userBuilds.save()
	return true
end

function userBuilds.stamp(id)
	local build = userBuilds.get(id)
	if not build or not build.updated or build.updated <= 0 then return "" end
	return tostring(os.date("%d.%m.%Y", build.updated))
end

return userBuilds