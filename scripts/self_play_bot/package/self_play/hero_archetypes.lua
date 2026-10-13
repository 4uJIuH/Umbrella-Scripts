local archetypes = {}
local catalog = require("self_play.catalog")

local cache = {}

local function has(hero, tag)
	for _, name in ipairs(hero.roles or {}) do if name == tag then return true end end
	return false
end

local function count(hero, tag)
	local total = 0
	for _, name in ipairs(hero.roles or {}) do if name == tag then total = total + 1 end end
	return total
end

function archetypes.primary(hero)
	if not hero then return "unknown" end
	if has(hero, "Support") and has(hero, "Disabler") then
		if has(hero, "Initiator") then return "save_support" end
		return "control_support"
	end
	if has(hero, "Support") then
		if has(hero, "Escape") then return "roaming_support" end
		return "save_support"
	end
	if has(hero, "Initiator") and has(hero, "Durable") then return "frontline_initiator" end
	if has(hero, "Initiator") then
		if has(hero, "Escape") then return "mobile_initiator" end
		return "control_initiator"
	end
	if has(hero, "Escape") and has(hero, "Carry") and has(hero, "Disabler") then return "mobile_carry" end
	if has(hero, "Escape") and has(hero, "Nuker") and has(hero, "Disabler") then return "mobile_assassin" end
	if has(hero, "Carry") then
		if has(hero, "Pusher") then return "split_pusher" end
		if has(hero, "Disabler") then return "tempo_carry" end
		return "scaling_carry"
	end
	if has(hero, "Pusher") and has(hero, "Durable") then return "pusher_tank" end
	if has(hero, "Pusher") then return "lane_controller" end
	if has(hero, "Durable") then return "frontline_tank" end
	if has(hero, "Disabler") then return "control_frontline" end
	return "nuker"
end

function archetypes.tags(hero)
	if not hero then return {} end
	local result = {}
	local function add(tag, flag) result[tag] = flag end
	add("carry", has(hero, "Carry"))
	add("support", has(hero, "Support"))
	add("initiator", has(hero, "Initiator"))
	add("disabler", has(hero, "Disabler"))
	add("durable", has(hero, "Durable"))
	add("escape", has(hero, "Escape"))
	add("nuker", has(hero, "Nuker"))
	add("pusher", has(hero, "Pusher"))
	add("strength", hero.attribute == "str")
	add("agility", hero.attribute == "agi")
	add("intelligence", hero.attribute == "int")
	add("universal", hero.attribute == "all")
	return result
end

function archetypes.enrich(entry, unit)
	if not entry or not unit then return entry end
	entry.attackRange = NPC.GetAttackRange(unit) + NPC.GetAttackRangeBonus(unit)
	entry.projectileSpeed = NPC.GetAttackProjectileSpeed(unit)
	entry.moveSpeed = NPC.GetMoveSpeed(unit)
	entry.ranged = NPC.IsRanged(unit)
	entry.melee = not entry.ranged
	entry.tags = entry.tags or {}
	entry.tags.ranged, entry.tags.melee = entry.ranged, entry.melee
	return entry
end

function archetypes.of(name)
	if cache[name] then return cache[name] end
	local hero = catalog.heroes[name]
	local result = nil
	if hero then result = {hero = hero, name = name, archetype = archetypes.primary(hero), tags = archetypes.tags(hero),
		roleCount = count(hero, "Carry") + count(hero, "Support") + count(hero, "Initiator") + count(hero, "Disabler")
			+ count(hero, "Durable") + count(hero, "Escape") + count(hero, "Nuker") + count(hero, "Pusher")} end
	cache[name] = result or false
	return result
end

function archetypes.build()
	local result = {}
	for name in pairs(catalog.heroes) do
		local entry = archetypes.of(name)
		result[name] = entry.archetype
	end
	return result
end

function archetypes.count()
	local totals = {}
	for name in pairs(catalog.heroes) do
		local archetype = archetypes.of(name).archetype
		totals[archetype] = (totals[archetype] or 0) + 1
	end
	return totals
end

function archetypes.coverage()
	local result = {}
	for name in pairs(catalog.heroes) do
		local entry = archetypes.of(name)
		if not entry or entry.archetype == "unknown" then result[#result + 1] = name end
	end
	table.sort(result)
	return result
end

return archetypes