local intel = {}
local catalog = require("self_play.catalog")
local abilityKV = XHelpers.xkv:GetKV("npc_abilities").DOTAAbilities

local cache = {}

local function behavior(value)
	if type(value) ~= "table" then return {} end
	return value
end

local function hasBehavior(list, name)
	for _, entry in pairs(list) do
		if type(entry) == "string" and entry:upper():find(name, 1, true) then return true end
	end
	return false
end

local function maxLevel(values)
	if type(values) ~= "table" then return 0 end
	local best = 0
	for _, entry in ipairs(values) do
		local value = tonumber(entry) or 0
		if value > best then best = value end
	end
	return best
end

local function pick(raw, level)
	if type(raw) == "table" then raw = raw.value end
	if type(raw) == "number" then return raw end
	if type(raw) ~= "string" then return 0 end
	local result, index = 0, 0
	for part in raw:gmatch("%-?%d+%.?%d*") do
		result, index = tonumber(part) or 0, index + 1
		if index >= math.max(1, level or 1) then break end
	end
	return result
end

function intel.static(name)
	if cache[name] ~= nil then return cache[name] or nil end
	local meta = catalog.abilities[name] or {}
	local kv = abilityKV[name] or {}
	local values = type(kv.AbilityValues) == "table" and kv.AbilityValues or {}
	local flags = behavior(kv.AbilityBehavior)
	local level = 1
	local result = {
		name = name,
		damage = meta.damage ~= nil or kv.abilitydamage ~= nil,
		heal = meta.heal == true,
		save = meta.save == true,
		disable = meta.disable == true,
		buff = meta.buff == true,
		summon = meta.summon == true,
		mobility = meta.mobility == true,
		pierces = meta.pierces == true,
		steal = meta.steal == true,
		unsafe = meta.unsafe == true,
		aoe = hasBehavior(flags, "AOE"),
		point = hasBehavior(flags, "POINT"),
		unitTarget = hasBehavior(flags, "UNIT TARGET"),
		noTarget = hasBehavior(flags, "NO TARGET"),
		channel = hasBehavior(flags, "CHANNEL"),
		toggled = hasBehavior(flags, "TOGGLE"),
		passive = hasBehavior(flags, "PASSIVE"),
		hidden = hasBehavior(flags, "HIDDEN"),
		aura = hasBehavior(flags, "AURA"),
		vector = hasBehavior(flags, "VECTOR"),
		radius = maxLevel(meta.radius),
		castRange = math.max(pick(kv.abilitycastrange or values.abilitycastrange, level), 0),
		castPoint = pick(kv.abilitycastpoint or values.abilitycastpoint, level),
		channelTime = pick(kv.AbilityChannelTime, level),
		healthCost = pick(kv.AbilityHealthCost, level),
		mana = pick(kv.mc, level),
		cooldown = pick(kv.cd, level),
		duration = maxLevel(values.duration),
		speed = pick(values.projectile_speed, level),
	}
	result.projectile = result.speed > 0
	result.harmful = result.damage and not result.heal
	result.worth = (result.save and 4 or 0) + (result.disable and 3 or 0) + (result.damage and 2 or 0)
		+ (result.mobility and 3 or 0) + (result.aoe and 2 or 0) + (result.summon and 1 or 0)
	result.offensive = result.damage or result.disable
	result.defensive = result.save or result.heal or result.buff or result.mobility
	cache[name] = result
	return result
end

function intel.live(ability)
	if not ability or not Entity.IsAbility(ability) then return nil end
	local name = Ability.GetName(ability)
	local base = intel.static(name) or {name = name, damage = false, heal = false, disable = false, save = false,
		buff = false, radius = 0, castRange = 0, castPoint = 0, channelTime = 0, mana = 0, cooldown = 0, duration = 0, speed = 0}
	local result = {}
	for key, value in pairs(base) do result[key] = value end
	result.level = Ability.GetLevel(ability)
	result.ultimate = Ability.IsUltimate(ability)
	result.active = Ability.IsActivated(ability)
	result.passive = Ability.IsPassive(ability, true)
	result.hidden = Ability.IsHidden(ability)
	result.ready = Ability.IsReady(ability)
	result.castRange = Ability.GetCastRange(ability)
	result.castPoint = Ability.GetCastPoint(ability)
	result.mana = Ability.GetManaCost(ability)
	result.health = Ability.GetHealthCost(ability)
	result.damageValue = Ability.GetDamage(ability)
	result.executable = Ability.CanBeExecuted(ability)
	result.secondsSinceUse = Ability.SecondsSinceLastUse(ability)
	result.cooldownRemaining = Ability.GetCooldown(ability)
	result.channeling = Ability.IsChannelling(ability)
	result.damageType = Ability.GetDamageType(ability)
	result.dispellable = Ability.GetDispellableType(ability)
	result.immunity = Ability.GetImmunityType(ability, true)
	result.targetTeam = Ability.GetTargetTeam(ability, true)
	result.targetType = Ability.GetTargetType(ability, true)
	result.targetFlags = Ability.GetTargetFlags(ability)
	result.owner = Ability.GetOwner(ability)
	return result
end

function intel.castable(ctx, ability)
	local entry = intel.live(ability)
	if not entry or not entry.active or entry.passive or entry.hidden then return nil end
	if not ctx.settings.spells or NPC.IsSilenced(ctx.hero) then return nil end
	if entry.level < 1 or not entry.ready then return nil end
	if entry.mana > 0 and entry.mana > NPC.GetMana(ctx.hero) then return nil end
	if ctx.now < (ctx.abilityAttempts[entry.name] or 0) then return nil end
	return entry
end

function intel.stats()
	local totals = {total = 0, damage = 0, heal = 0, save = 0, disable = 0, buff = 0, summon = 0,
		mobility = 0, projectile = 0, channel = 0, passive = 0, auras = 0}
	for name in pairs(catalog.abilities) do
		local entry = intel.static(name)
		if entry then
			totals.total = totals.total + 1
			for _, key in ipairs({"damage", "heal", "save", "disable", "buff", "summon", "mobility",
				"projectile", "channel", "passive", "aura"}) do
				if entry[key] then totals[key] = totals[key] + 1 end
			end
		end
	end
	return totals
end

function intel.profile(heroName)
	if not heroName then return {} end
	local prefix = heroName:gsub("^npc_dota_hero_", "") .. "_"
	local result = {}
	for name in pairs(catalog.abilities) do
		if name:sub(1, #prefix) == prefix then
			local entry = intel.static(name)
			if entry and (entry.damage or entry.heal or entry.disable or entry.save or entry.summon or entry.buff) then
				result[#result + 1] = entry
			end
		end
	end
	table.sort(result, function(a, b)
		if a.worth ~= b.worth then return a.worth > b.worth end
		return a.name < b.name
	end)
	return result
end

return intel