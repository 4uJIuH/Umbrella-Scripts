local policy = {}
local catalog = require("self_play.catalog")
local archetypes = require("self_play.hero_archetypes")
local spellIntel = require("self_play.spell_intel")
local planner = require("self_play.planner")

local cache = {}

local base = {
	holdDistance = 0.85,
	aggression = 0.5,
	engageRange = 900,
	disengageHealth = 0.4,
	ultWeight = 0.6,
	targetBackline = 0.5,
	preferIsolated = 0.5,
	farmPriority = 0.5,
	joinFights = 0.5,
	initiate = 0.5,
	pushAfterKill = 0.5,
	retreatValue = 0.5,
	spellsPerWindow = 2,
	commitTime = 1.2,
}

local tuning = {
	scaling_carry = {holdDistance = 0.95, aggression = 0.45, targetBackline = 0.75, farmPriority = 0.7,
		engageRange = 800, joinFights = 0.45, disengageHealth = 0.45, pushAfterKill = 0.6},
	tempo_carry = {holdDistance = 0.85, aggression = 0.65, targetBackline = 0.65, farmPriority = 0.6,
		engageRange = 1000, joinFights = 0.6, initiate = 0.6, pushAfterKill = 0.7},
	split_pusher = {holdDistance = 0.95, aggression = 0.5, farmPriority = 0.75, pushAfterKill = 0.85,
		preferIsolated = 0.7, disengageHealth = 0.5, joinFights = 0.35},
	frontline_initiator = {holdDistance = 0.6, aggression = 0.7, initiate = 0.85, engageRange = 800,
		joinFights = 0.75, disengageHealth = 0.35, retreatValue = 0.35, pushAfterKill = 0.6},
	mobile_initiator = {holdDistance = 0.7, aggression = 0.75, initiate = 0.8, engageRange = 1200,
		joinFights = 0.8, disengageHealth = 0.35, retreatValue = 0.5},
	control_initiator = {holdDistance = 0.75, aggression = 0.65, initiate = 0.7, engageRange = 900,
		joinFights = 0.7, disengageHealth = 0.38, ultWeight = 0.75},
	frontline_tank = {holdDistance = 0.5, aggression = 0.55, initiate = 0.5, engageRange = 600,
		joinFights = 0.6, disengageHealth = 0.3, retreatValue = 0.25, spellsPerWindow = 3},
	control_frontline = {holdDistance = 0.65, aggression = 0.6, engageRange = 750, joinFights = 0.65,
		disengageHealth = 0.35, ultWeight = 0.7},
	control_support = {holdDistance = 0.9, aggression = 0.4, engageRange = 700, joinFights = 0.55,
		disengageHealth = 0.45, ultWeight = 0.8, targetBackline = 0.6},
	save_support = {holdDistance = 0.9, aggression = 0.3, engageRange = 600, joinFights = 0.5,
		disengageHealth = 0.45, retreatValue = 0.6, ultWeight = 0.85},
	roaming_support = {holdDistance = 0.8, aggression = 0.5, engageRange = 1000, joinFights = 0.7,
		disengageHealth = 0.4, farmPriority = 0.35},
	mobile_carry = {holdDistance = 0.9, aggression = 0.6, engageRange = 1100, joinFights = 0.6,
		targetBackline = 0.6, disengageHealth = 0.42, retreatValue = 0.6},
	mobile_assassin = {holdDistance = 0.85, aggression = 0.75, engageRange = 1300, joinFights = 0.7,
		targetBackline = 0.85, disengageHealth = 0.38, retreatValue = 0.6, preferIsolated = 0.75},
	pusher_tank = {holdDistance = 0.6, aggression = 0.55, engageRange = 700, farmPriority = 0.6,
		pushAfterKill = 0.85, disengageHealth = 0.35, joinFights = 0.5},
	lane_controller = {holdDistance = 0.75, aggression = 0.6, engageRange = 850, farmPriority = 0.65,
		pushAfterKill = 0.8, disengageHealth = 0.4},
	nuker = {holdDistance = 0.75, aggression = 0.6, engageRange = 900, targetBackline = 0.6,
		disengageHealth = 0.4, joinFights = 0.6},
}

local function merge(entry, source)
	for key, value in pairs(source) do entry[key] = value end
	return entry
end

function policy.of(heroName)
	if cache[heroName] ~= nil then return cache[heroName] or nil end
	local archetype = archetypes.of(heroName)
	if not archetype then
		cache[heroName] = false
		return nil
	end
	local result = merge(merge({}, base), tuning[archetype.archetype] or {})
	result.hero = archetype.hero
	result.name = heroName
	result.archetype = archetype.archetype
	result.tags = archetype.tags
	result.spells = spellIntel.profile(heroName)
	result.registered = false
	result.ultimate = nil
	result.combo = {}
	for _, spell in ipairs(result.spells) do
		if spell.channelTime > 0 then result.combo[#result.combo + 1] = "channel" end
		if spell.summon then result.combo[#result.combo + 1] = "summon" end
		if spell.mobility then result.combo[#result.combo + 1] = "mobility" end
		if spell.save then result.combo[#result.combo + 1] = "save" end
		if spell.disable then result.combo[#result.combo + 1] = "disable" end
	end
	result.hasChannel = result.combo[#result.combo] == "channel" or false
	result.hasSummon = false
	result.hasMobility = false
	result.hasSave = false
	result.hasDisable = false
	for _, name in ipairs(result.combo) do
		if name == "summon" then result.hasSummon = true end
		if name == "mobility" then result.hasMobility = true end
		if name == "save" then result.hasSave = true end
		if name == "disable" then result.hasDisable = true end
	end
	result.offensiveSpells, result.defensiveSpells, result.controlSpells = {}, {}, {}
	for _, spell in ipairs(result.spells) do
		if spell.offensive then result.offensiveSpells[#result.offensiveSpells + 1] = spell.name end
		if spell.defensive then result.defensiveSpells[#result.defensiveSpells + 1] = spell.name end
		if spell.disable then result.controlSpells[#result.controlSpells + 1] = spell.name end
	end
	result.itemPlan = planner.build(catalog, planner.selectGuide(catalog, heroName, 1), 1, 600)
	cache[heroName] = result
	return result
end

function policy.enrich(ctx)
	local result = policy.of(ctx.heroName)
	if not result then return nil end
	result.registered = ctx.heroModule ~= nil
	local unit = ctx.hero
	if Entity.IsEntity(unit) and Entity.IsAlive(unit) then
		archetypes.enrich(archetypes.of(ctx.heroName), unit)
		result.attackRange = NPC.GetAttackRange(unit) + NPC.GetAttackRangeBonus(unit)
		result.moveSpeed = NPC.GetMoveSpeed(unit)
		result.ranged = NPC.IsRanged(unit)
		result.projectileSpeed = NPC.GetAttackProjectileSpeed(unit)
		result.level = NPC.GetCurrentLevel(unit)
	end
	return result
end

function policy.aggression(ctx, policy)
	if not policy then return 0.5 end
	local level = NPC.GetCurrentLevel(ctx.hero)
	local core = ctx.fullBuild and 1 or 0
	return math.min(1, math.max(0, policy.aggression + (level - 6) * 0.012 + core * 0.15))
end

function policy.report()
	local result = {total = 0, byArchetype = {}, noPolicy = {}, registered = 0}
	for name in pairs(catalog.heroes) do
		local entry = policy.of(name)
		if entry then
			result.total = result.total + 1
			result.byArchetype[entry.archetype] = (result.byArchetype[entry.archetype] or 0) + 1
		else
			result.noPolicy[#result.noPolicy + 1] = name
		end
	end
	table.sort(result.noPolicy)
	return result
end

function policy.all()
	local result = {}
	for name in pairs(catalog.heroes) do
		local entry = policy.of(name)
		if entry then result[name] = entry end
	end
	return result
end

return policy