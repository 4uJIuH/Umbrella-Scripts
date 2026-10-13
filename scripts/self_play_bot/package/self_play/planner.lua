local planner = {}

local fallback = {
	{"magic_wand", "power_treads", "maelstrom", "black_king_bar", "manta", "greater_crit", "satanic"},
	{"magic_wand", "arcane_boots", "witch_blade", "black_king_bar", "shivas_guard", "sheepstick"},
	{"magic_wand", "phase_boots", "blink", "pipe", "black_king_bar", "assault"},
	{"magic_wand", "arcane_boots", "force_staff", "glimmer_cape", "lotus_orb", "sheepstick"},
	{"magic_wand", "tranquil_boots", "glimmer_cape", "force_staff", "ghost", "lotus_orb"},
}

function planner.hasFlag(mask, flag)

	return flag > 0 and math.floor(mask / flag) % 2 == 1
end

function planner.levelValue(values, level)
	if not values or #values == 0 then return 0 end
	return values[math.max(1, math.min(level, #values))]
end

function planner.contains(items, parent, child, visited)
	if parent == child then return true end
	local record = items[parent]
	if not record then return false end
	visited = visited or {}
	if visited[parent] then return false end
	visited[parent] = true
	for _, part in ipairs(record.components) do
		if planner.contains(items, part, child, visited) then return true end
	end
	return false
end

function planner.owns(items, inventory, name)
	for owned, count in pairs(inventory) do
		if count > 0 and planner.contains(items, owned, name) then return true end
	end
	return false
end

function planner.componentCount(items, inventory, name)
	local function count(key, visiting)
		if key == name then return 1 end
		if visiting[key] or not items[key] then return 0 end
		visiting[key] = true
		local total = 0
		for _, part in ipairs(items[key].components) do total = total + count(part, visiting) end
		visiting[key] = nil
		return total
	end
	local total = 0
	for key, quantity in pairs(inventory) do total = total + quantity * count(key, {}) end
	return total
end

function planner.missing(items, name, inventory)
	local available, leaves, visiting = {}, {}, {}
	for key, count in pairs(inventory) do available[key] = count end
	local function expand(key)
		if (available[key] or 0) > 0 then
			available[key] = available[key] - 1
			return true
		end
		local record = items[key]
		if not record or record.neutral or visiting[key] then return false end
		if #record.components == 0 then
			if record.cost <= 0 then return false end
			leaves[#leaves + 1] = key
			return true
		end
		visiting[key] = true
		for _, component in ipairs(record.components) do
			if not expand(component) then return false end
		end
		visiting[key] = nil
		return true
	end
	if not expand(name) then return nil end
	return leaves
end

function planner.gameItems(items, kv)
	local result = {}
	for name, record in pairs(items) do
		local copy = {}
		for key, value in pairs(record) do copy[key] = value end
		local current = kv["item_" .. name]
		if current then
			copy.id = tonumber(current.ID) or copy.id
			local kvCost = tonumber(current.ItemCost or "0") or 0
			if kvCost > 0 then copy.cost = kvCost end
			copy.purchasable = current.ItemPurchasable == nil or tonumber(current.ItemPurchasable) > 0
			copy.limit = tonumber(current.ItemStockMax or "0") or 0
		end
		result[name] = copy
	end
	for name, current in pairs(kv) do
		local key = name:gsub("^item_", "")
		if result[key] == nil and type(current) == "table" and tonumber(current.ID or "0") > 0 then
			result[key] = {id = tonumber(current.ID), cost = tonumber(current.ItemCost or "0"),
				components = {}, secret = false, neutral = false, consumable = false, effects = {},
				purchasable = current.ItemPurchasable == nil or tonumber(current.ItemPurchasable) > 0,
				recipe = tonumber(current.ItemRecipe or "0") == 1,
				limit = tonumber(current.ItemStockMax or "0") or 0}
		end
	end
	for name, recipe in pairs(kv) do
		local parent = type(recipe) == "table" and recipe.ItemResult and recipe.ItemResult:gsub("^item_", "")
		local requirement = type(recipe) == "table" and recipe.ItemRequirements and recipe.ItemRequirements["01"]
		if parent and result[parent] and type(requirement) == "string" then
			local parts, valid = {}, true
			for part in requirement:gmatch("[^;]+") do
				local trimmed = part:match("^%s*(.-)%s*$")
				local key = trimmed:match("^item_([%w_]+)%*?$")
				if not key or not result[key] then valid = false; break end
				parts[#parts + 1] = key
			end
			local recipeName = name:gsub("^item_", "")
			if valid and #parts > 0 then
				if tonumber(recipe.ItemCost or "0") > 0 and result[recipeName] then parts[#parts + 1] = recipeName end
				result[parent].components = parts
			end
		end
	end
	return result
end

function planner.selectGuide(catalog, heroName, role)
	local best, bestScore, bestKey = nil, -math.huge, nil
	local heroTitle = heroName:gsub("^npc_dota_hero_", ""):gsub("_", " ")
	for _, guide in ipairs(catalog.guides) do
		if guide.hero == heroName and guide.support == (role >= 4) then
			local title = guide.title:lower():match("^%s*(.-)%s*$")
			local score = title:gsub("^nerds%s+", "") == heroTitle and 20 or 0
			local mid = title:find("%f[%a]mid%f[%A]") ~= nil
			local offlane = title:find("offlane", 1, true) ~= nil
			local carry = title:find("%f[%a]carry%f[%A]") ~= nil
			local hardSupport = title:find("hard support", 1, true) ~= nil
			local matched = role == 2 and mid or role == 3 and offlane or role == 1 and carry or role == 5 and hardSupport
			if matched then score = score + 45
			elseif mid or offlane or carry or hardSupport then score = score - 45 end
			for _, word in ipairs({"experimental", "wip", "untitled"}) do
				if title:find("%f[%a]" .. word .. "%f[%A]") then score = score - 90 end
			end
			for _, word in ipairs({"caster", "magic", "magical", "utility", "ion cannon"}) do
				if title:find("%f[%a]" .. word .. "%f[%A]") then score = score - 30 end
			end
			local key = title .. "|" .. (guide.url or "")
			if score > bestScore or score == bestScore and key < bestKey then
				best, bestScore, bestKey = guide, score, key
			end
		end
	end
	return best
end

function planner.parseGuide(body, heroName)
	if type(body) ~= "string" or #body > 300000 then return nil end
	local name = body:match('"Hero"%s*"([a-z0-9_]+)"')
	if not name or "npc_dota_hero_" .. name ~= heroName then return nil end
	local guide = {groups = {}, skills = {}, title = body:match('"Title"%s*"([^"]+)"') or "",
		patch = body:match('"GameplayVersion"%s*"([^"]+)"') or "unknown"}
	for title, contents in body:gmatch('"([^"\r\n]+)"%s*{([^{}]*)}') do
		local lower = title:lower()
		if title:find("Starting", 1, true) or lower == "early" or lower == "core" or lower == "lategame" or lower == "late game"
			or lower:find("bear", 1, true) or lower:find("druid", 1, true) then
			local names = {}
			for item in contents:gmatch('"item"%s*"item_([a-z0-9_]+)"') do names[#names + 1] = item end
			guide.groups[#guide.groups + 1] = {title = title, items = names}
		elseif title == "AbilityOrder" then
			for level, skill in contents:gmatch('"(%d+)"%s*"([a-z0-9_]+)"') do
				local number = tonumber(level)
				if number >= 1 and number <= 30 then guide.skills[number] = skill end
			end
		end
	end
	if #guide.groups == 0 then return nil end
	return guide
end

function planner.build(catalog, guide, role, clock)
	local result, seen = {}, {}
	local function append(name)
		local item = catalog.items[name]
		if seen[name] or not item or item.neutral or item.cost <= 0 then return end
		if not planner.missing(catalog.items, name, {}) then return end
		seen[name] = true
		result[#result + 1] = name
	end
	if guide then
		for _, group in ipairs(guide.groups) do
			local start = group.title:find("Starting", 1, true)
			if not start or clock < 120 then
				local limit = group.title:lower():find("late", 1, true) and 2 or 8
				for index, name in ipairs(group.items) do
					if index <= limit then append(name) end
				end
			end
		end
	end
	if #result == 0 then
		if clock < 120 then append("tango") end
		for _, name in ipairs(fallback[role]) do append(name) end
	end
	return result
end

function planner.parsePopularity(body)


	if type(body) ~= "string" or #body > 200000 then return nil end
	local cursor, failed = 1, false
	local function whitespace()
		local _, finish = body:find("^%s*", cursor)
		cursor = (finish or cursor - 1) + 1
	end
	local function object(depth)
		whitespace()
		if depth > 3 or body:sub(cursor, cursor) ~= "{" then failed = true; return nil end
		cursor = cursor + 1
		local result = {}
		whitespace()
		if body:sub(cursor, cursor) == "}" then cursor = cursor + 1; return result end
		while not failed do
			whitespace()
			local first, finish, key = body:find('"([%w_]+)"', cursor)
			if first ~= cursor or result[key] ~= nil then failed = true; return nil end
			cursor = finish + 1
			whitespace()
			if body:sub(cursor, cursor) ~= ":" then failed = true; return nil end
			cursor = cursor + 1
			whitespace()
			if body:sub(cursor, cursor) == "{" then
				result[key] = object(depth + 1)
			else
				local start, stop, number = body:find("(%d+)", cursor)
				if start ~= cursor or #number > 15 then failed = true; return nil end
				result[key], cursor = tonumber(number), stop + 1
			end
			whitespace()
			local token = body:sub(cursor, cursor)
			cursor = cursor + 1
			if token == "}" then return result end
			if token ~= "," then failed = true; return nil end
		end
		return nil
	end
	local result = object(1)
	whitespace()
	if failed or cursor <= #body or not result then return nil end
	for _, name in ipairs({"start_game_items", "early_game_items", "mid_game_items", "late_game_items"}) do
		if type(result[name]) ~= "table" then return nil end
		for key, count in pairs(result[name]) do
			if not key:match("^%d+$") or type(count) ~= "number" then return nil end
		end
	end
	return result
end

function planner.popularityBuild(catalog, data, role, clock)
	local byId, selected, seen = {}, {}, {}
	for name, record in pairs(catalog.items) do byId[tostring(record.id)] = name end
	local utility = {force_staff = true, glimmer_cape = true, lotus_orb = true, pavise = true,
		solar_crest = true, aether_lens = true, arcane_boots = true, tranquil_boots = true,
		guardian_greaves = true, pipe = true, boots_of_bearing = true}
	local farming = {bfury = true, hand_of_midas = true, radiance = true, maelstrom = true,
		mjollnir = true, butterfly = true, greater_crit = true, rapier = true, bottle = true, quelling_blade = true}
	local ingredient = {}
	for _, record in pairs(catalog.items) do
		for _, component in ipairs(record.components) do ingredient[component] = true end
	end
	local stages = {{"start_game_items", 4}, {"early_game_items", 3}, {"mid_game_items", 2}, {"late_game_items", 2}}
	local bootsChosen = false
	for stageIndex, stage in ipairs(stages) do
		local ranked = {}
		if stageIndex ~= 1 or clock < 120 then
			for id, count in pairs(data[stage[1]]) do
				local name = byId[id]
				local item = name and catalog.items[name]
				if item and count > 0 and item.cost > 0 and not item.neutral and not name:find("^recipe_")
					and not (role >= 4 and farming[name]) and (stageIndex == 1 or not item.consumable)
					and (stageIndex <= 2 or #item.components > 0 or item.cost >= 2000 and not ingredient[name]) then
					local score = count * (role >= 4 and utility[name] and 1.15 or 1)
					ranked[#ranked + 1] = {name = name, score = score}
				end
			end
		end
		table.sort(ranked, function(a, b) return a.score == b.score and a.name < b.name or a.score > b.score end)
		local added = 0
		for _, candidate in ipairs(ranked) do
			local name = candidate.name
			local covered, isBoots = false, planner.contains(catalog.items, name, "boots") and name ~= "boots"
			for _, previous in ipairs(selected) do
				if planner.contains(catalog.items, previous, name) then covered = true; break end
			end
			if not seen[name] and not covered and not (isBoots and bootsChosen)
				and planner.missing(catalog.items, name, {}) then
				selected[#selected + 1], seen[name] = name, true
				bootsChosen = bootsChosen or isBoots
				added = added + 1
				if added >= stage[2] then break end
			end
		end
	end
	return #selected >= 3 and selected or nil
end

function planner.lastHit(health, incoming, damage, allied, maxHealth)
	if allied and health > maxHealth * 0.5 then return false end
	local predicted = health - incoming
	return predicted > 0 and predicted <= damage
end

function planner.closestApproach(dx, dy, vx, vy, horizon)
	local speedSquared = vx * vx + vy * vy
	if speedSquared < 1 then return 0, math.sqrt(dx * dx + dy * dy) end
	local time = math.max(0, math.min(horizon, -(dx * vx + dy * vy) / speedSquared))
	local x, y = dx + vx * time, dy + vy * time
	return time, math.sqrt(x * x + y * y)
end

function planner.pullWindow(clock, second, travel)
	if clock < 60 then return false end
	local remaining = (second - clock % 60 + 60) % 60
	return remaining <= travel + 3 and remaining >= math.max(0, travel - 2), remaining
end

function planner.roleScores(hero)
	local tags = {}
	for _, name in ipairs(hero and hero.roles or {}) do tags[name] = true end
	local support = tags.Support and not tags.Carry
	return {
		(tags.Carry and 8 or 0) + (hero and hero.attribute == "agi" and 2 or 0) - (support and 6 or 0),
		(tags.Nuker and 5 or 0) + (tags.Escape and 2 or 0) + (tags.Nuker and tags.Carry and 4 or 0)
			+ (hero and hero.attribute == "int" and not tags.Support and 3 or 0) - (support and 6 or 0),
		(tags.Durable and 6 or 0) + (tags.Initiator and 4 or 0),
		(tags.Support and 5 or 0) + (tags.Disabler and 4 or 0) + (tags.Initiator and 2 or 0) + (tags.Escape and 1 or 0),
		(tags.Support and 8 or 0) + (support and 3 or 0) - (tags.Carry and 3 or 0)
			- (tags.Initiator and 1 or 0) - (tags.Escape and 1 or 0),
	}
end

function planner.assignRoles(heroes)

	table.sort(heroes, function(a, b) return a.id < b.id end)
	local best, bestScore, selected, used = {}, -math.huge, {}, {}
	local function search(index, score)
		if index > #heroes then
			if score > bestScore then
				bestScore = score
				for key, value in pairs(selected) do best[key] = value end
			end
			return
		end
		for role = 1, 5 do
			if not used[role] then
				used[role], selected[heroes[index].id] = true, role
				search(index + 1, score + heroes[index].scores[role])
				used[role] = nil
			end
		end
	end
	search(1, 0)
	return best
end

return planner
