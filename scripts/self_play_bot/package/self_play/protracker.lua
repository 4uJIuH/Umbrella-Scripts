local protracker = {}
local JSON = require("assets.JSON")
local json = JSON:new({assert = function() end})

protracker.roles = {
	{1, 2, 3, 4, 5},
	{2, 1, 3, 4, 5},
	{3, 2, 1, 4, 5},
	{4, 5, 3, 2, 1},
	{5, 4, 3, 2, 1},
}
protracker.userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36"

function protracker.parse(body, heroId, role)
	if type(body) ~= "string" or #body > 1000000 or not body:match("^%s*%[") then return nil, "Invalid build response" end
	local rows = json:decode(body)
	if type(rows) ~= "table" then return nil, "Invalid build JSON" end
	if next(rows) == nil then return nil, "empty" end
	local best
	for _, row in ipairs(rows) do
		if type(row) == "table" and row.hero_id == heroId and row.position == "pos " .. role
			and type(row.build_data) == "table" and type(row.num_matches) == "number" and row.num_matches > 0
			and (not best or row.num_matches > best.num_matches) then best = row end
	end
	if not best then return nil, "No matching hero/role data" end
	local anchor = best.build_data.anchor_build
	if type(anchor) ~= "table" or type(anchor[1]) ~= "table" or #anchor[1] == 0 then return nil, "empty" end
	return best
end

function protracker.guide(ctx, row)
	local data, byId = row.build_data, {}
	for name, item in pairs(ctx.shop.items) do byId[item.id] = name end
	local function names(ids)
		local result, seen = {}, {}
		for _, id in ipairs(ids) do
			local name = type(id) == "number" and byId[id]
			local item = name and ctx.shop.items[name]
			if item and item.cost > 0 and not item.neutral and not name:find("^recipe_") and not seen[name]
				and ctx.planner.missing(ctx.shop.items, name, {}) then
				result[#result + 1], seen[name] = name, true
			end
		end
		return result
	end
	local core = names(data.anchor_build[1])
	if #core < 3 then return nil end
	local guide = {hero = ctx.heroName, support = ctx.role >= 4, title = "Dota2ProTracker " .. row.position,
		provider = "protracker", role = row.position, groups = {}, skills = {}, talents = {}}
	local starts = data.anchor_start_items_new or data.starting_items_new
	local best, count
	if type(starts) == "table" then
		for _, bundle in ipairs(starts) do
			if type(bundle) == "table" and type(bundle[1]) == "table" and type(bundle[2]) == "table"
				and type(bundle[2].count) == "number" and (not count or bundle[2].count > count) then best, count = bundle[1], bundle[2].count end
		end
	end
	if best then guide.groups[#guide.groups + 1] = {title = "Starting Items", items = names(best)} end
	guide.groups[#guide.groups + 1] = {title = "Core", items = core}
	if type(data.abilities) == "table" then
		for level, ability in ipairs(data.abilities) do
			if level <= 30 and type(ability) == "table" and type(ability.name) == "string"
				and ability.name:match("^[a-z0-9_]+$") then guide.skills[level] = ability.name end
		end
	end
	if type(data.talents) == "table" then
		for _, talent in ipairs(data.talents) do
			if type(talent) == "table" then
				local choice = talent.choice == "lt" and talent.left or talent.choice == "rt" and talent.right
				if type(choice) == "table" and type(choice.name) == "string" and choice.name:match("^special_bonus_[a-z0-9_]+$")
					and (talent.lvl == 10 or talent.lvl == 15 or talent.lvl == 20 or talent.lvl == 25) then guide.talents[talent.lvl] = choice.name end
			end
		end
	end
	return guide
end

function protracker.plan(ctx, guide)
	local result, seen = {}, {}
	for _, group in ipairs(guide.groups) do
		if group.title ~= "Starting Items" or ctx.clock < 120 then
			for _, name in ipairs(group.items) do
				if not seen[name] then result[#result + 1], seen[name] = name, true end
			end
		end
	end
	return result
end

function protracker.source(role, requested, cached)
	return (cached and "Cached Dota2ProTracker: pos " or "Dota2ProTracker: pos ") .. role
		.. (role ~= requested and " (fallback for pos " .. requested .. ")" or "")
end

return protracker
