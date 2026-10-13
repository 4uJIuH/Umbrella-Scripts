local neutral = {}

local JSON = require("assets.JSON")
local tiers = XHelpers.xkv:GetKV("neutral_items").neutral_items.neutral_tiers
local items = XHelpers.xkv:GetKV("items").DOTAAbilities
local names = {}
for name, data in pairs(items) do
	if type(data) == "table" and data.ID then names[tonumber(data.ID)] = name end
end

local profiles = {
	occult_bracelet = {0, 7, 3, 2}, kobold_cup = {2, 1, 2, 7}, chipped_vest = {4, 0, 7, 0},
	polliwog_charm = {2, 2, 3, 7}, dormant_curio = {3, 3, 3, 3}, duelist_gloves = {9, 0, 1, 0},
	weighted_dice = {8, 0, 1, 0}, ash_legion_shield = {2, 0, 7, 4}, dagger_of_ristul = {8, 0, 2, 0},
	stonefeather_satchel = {3, 2, 6, 3}, possessed_mask = {7, 0, 4, 0}, foragers_kit = {1, 2, 1, 6},
	essence_ring = {1, 3, 7, 1}, mana_draught = {0, 9, 1, 5}, poor_mans_shield = {3, 0, 8, 0},
	searing_signet = {0, 10, 0, 1}, pogo_stick = {2, 4, 2, 5}, defiant_shell = {6, 0, 7, 0},
	crippling_crossbow = {7, 2, 1, 4}, medallion_of_courage = {5, 1, 4, 7}, seeds_of_serenity = {0, 2, 4, 9},
	serrated_shiv = {10, 0, 2, 0}, gunpowder_gauntlets = {9, 0, 3, 0}, jidi_pollen_bag = {2, 4, 6, 4},
	psychic_headband = {1, 5, 2, 8}, unrelenting_eye = {4, 2, 8, 2}, cloak_of_flames = {3, 2, 8, 1},
	spellslinger = {0, 10, 0, 3}, stormcrafter = {2, 6, 4, 3}, partisans_brand = {10, 0, 0, 0},
	giant_maul = {9, 0, 3, 0}, rattlecage = {1, 2, 10, 1}, idol_of_screeauk = {5, 2, 7, 2},
	flayers_bota = {9, 0, 3, 0}, metamorphic_mandible = {0, 5, 3, 4}, dandelion_amulet = {1, 3, 8, 3},
	enchanters_bauble = {5, 5, 5, 5}, prophets_pendulum = {2, 3, 7, 2}, conjurers_catalyst = {0, 10, 1, 2},
	desolator_2 = {12, 0, 1, 0}, fallen_sky = {2, 6, 5, 3}, demonicon = {3, 2, 2, 7},
	minotaur_horn = {4, 4, 8, 3}, spider_legs = {3, 3, 5, 6}, riftshadow_prism = {9, 3, 2, 1},
	dezun_bloodrite = {0, 9, 0, 3}, divine_regalia = {6, 6, 0, 0}, harmonizer = {0, 11, 0, 3}, heavy_blade = {10, 0, 3, 0},
}

local function value(raw, level)
	if type(raw) == "table" then raw = raw.value end
	if type(raw) == "number" then return raw end
	if type(raw) ~= "string" then return 0 end
	local result, index = 0, 0
	for number in raw:gmatch("%-?%d+%.?%d*") do
		index, result = index + 1, tonumber(number)
		if index >= level then break end
	end
	return result
end

local function weights(ctx)
	local hero = ctx.catalog.heroes[ctx.heroName]
	local attack = ctx.role == 1 and 1.4 or ctx.role <= 3 and 0.8 or 0.3
	local caster = 0.5
	if hero then
		if hero.attribute == "agi" then attack = attack + 0.4 end
		if hero.attribute == "int" then caster = caster + 0.5 end
		for _, role in ipairs(hero.roles) do if role == "Nuker" then caster = caster + 0.4 end end
	end
	return {attack, caster, (NPC.IsRanged(ctx.hero) and 0.4 or 0.8) + (ctx.role == 3 and 0.5 or 0), ctx.role >= 4 and 1.3 or 0.45}
end

function neutral.score(ctx, name, level)
	local w = weights(ctx)
	local profile = profiles[name:gsub("^item_", "")]
	if profile then
		local score = 0
		for index, weight in ipairs(w) do score = score + weight * profile[index] end
		return score
	end
	local data = items[name]
	if not data then return nil end
	local score = 0
	for key, raw in pairs(data.AbilityValues or {}) do
		local amount = value(raw, level)
		if key:find("attack_speed", 1, true) or key == "bat_reduce" then score = score + amount * w[1] * 0.35
		elseif key:find("damage", 1, true) and key ~= "incoming_damage" then score = score + amount * w[1] * 0.45
		elseif key:find("mana_regen", 1, true) then score = score + amount * w[2] * 7
		elseif key:find("mana", 1, true) and not key:find("cost", 1, true) then score = score + amount * w[2] * 0.025
		elseif key:find("cast_range", 1, true) then score = score + amount * (w[2] + w[4]) * 0.025
		elseif key:find("spell_amp", 1, true) or key == "cooldown_reduction" or key == "manacost_reduction" then score = score + amount * w[2] * 0.9
		elseif key:find("health_regen", 1, true) or key == "bonus_hp_regen" then score = score + amount * (ctx.clock < 900 and 4 or 2)
		elseif key:find("health", 1, true) then score = score + amount * (1 + w[3]) * 0.035
		elseif key:find("armor", 1, true) or key:find("magic_res", 1, true) or key == "status_resistance" then score = score + amount * (0.5 + w[3]) * 0.75
		elseif key:find("move", 1, true) then score = score + amount * (1 + w[4]) * 0.18
		elseif key:find("attack_range", 1, true) then score = score + amount * w[1] * 0.03
		elseif key == "spell_lifesteal" then score = score + amount * w[2] * 0.4
		elseif key == "attack_lifesteal" then score = score + amount * w[1] * 0.5
		elseif key == "bonus_gpm" then score = score + amount * (ctx.role >= 4 and 0.12 or 0.05)
		elseif key:find("primary_stat", 1, true) then score = score + amount * 0.5
		elseif key == "incoming_damage" or key == "cost_increase" or key == "hp_regen_reduce" then score = score - amount * 0.5 end
	end
	return score
end

local function enchantLevel(ctx, tier, name)
	local data = tiers[tostring(tier)]
	local hero = ctx.catalog.heroes[ctx.heroName]
	local attribute = hero and ({str = "strength", agi = "agility", int = "intelligence", all = "universal"})[hero.attribute]
	return tonumber(data.enhancements.global[name] or attribute and data.enhancements[attribute][name] or "1")
end

function neutral.choose(ctx, info, tier, enhancement)
	local choices = enhancement and info.enhancement_choices or info.trinket_choices
	local stride = math.floor(#choices / #info.times_crafted)
	local count = tonumber(tiers[tostring(tier)][enhancement and "enhancement_options" or "trinket_options"])
	local best, bestScore, bestName
	for index = 0, math.min(stride, count) - 1 do
		local id = choices[(tier - 1) * stride + index + 1]
		local name = names[id]
		if name then
			local score = neutral.score(ctx, name, enhancement and enchantLevel(ctx, tier, name) or 1)
			if score and (not bestScore or score > bestScore) then best, bestScore, bestName = index, score, name end
		end
	end
	return best, bestName
end

function neutral.run(ctx)
	if not ctx.settings.buy or ctx.clock < 0 then return end
	ctx.neutralItems = ctx.neutralItems or {nextCheck = 0, attempts = {}}
	local state = ctx.neutralItems
	if ctx.now < state.nextCheck then return end
	state.nextCheck = ctx.now + 1
	local info = Player.GetPlayerNeutralInfo(ctx.player)
	if not info or #info.times_crafted == 0 then return end
	state.madstones = info.current_madstone
	local pending = state.pending
	if pending then
		local acknowledged = pending.kind == "craft" and info.times_crafted[pending.tier] > pending.crafted
			or pending.kind == "choose" and info.selected_trinkets[pending.tier] >= 0 and info.selected_enhancements[pending.tier] >= 0
		if acknowledged then
			state.status, state.pending = pending.kind == "craft" and "Neutral choices ready" or "Neutral selection confirmed", nil
		elseif ctx.now < pending.expires then return
		else state.pending = nil; state.status = "Neutral selection awaiting server" end
	end
	for tier = #info.times_crafted, 1, -1 do
		if info.times_crafted[tier] > 0 and (info.selected_trinkets[tier] < 0 or info.selected_enhancements[tier] < 0) then
			local item, itemName = neutral.choose(ctx, info, tier, false)
			local enchantment, enchantName = neutral.choose(ctx, info, tier, true)
			local key = "choose" .. tier
			if item == nil or enchantment == nil or (state.attempts[key] or 0) >= 3 then return end
			local sent = NetChannel.SendNetMessage("CDOTAClientMsg_ChooseCraftedNeutralItem", JSON:encode({
				neutral_item_index = item, item_tier = tier - 1, enhancement_index = enchantment,
			}))
			state.attempts[key] = (state.attempts[key] or 0) + 1
			state.nextCheck = ctx.now + 2
			if sent then
				state.pending = {kind = "choose", tier = tier, expires = ctx.now + 8}
				state.status = "Select " .. itemName .. " / " .. enchantName
			end
			return
		end
	end
	local available
	for tier, data in pairs(tiers) do
		local minutes, seconds = data.start_time:match("(%d+):(%d+)")
		local number = tonumber(tier)
		if ctx.clock >= tonumber(minutes) * 60 + tonumber(seconds) and (not available or number > available) then available = number end
	end
	if not available or info.times_crafted[available] > 0 then return end
	local cost = tonumber(tiers[tostring(available)].craft_cost)
	local key = "craft" .. available
	if info.current_madstone < cost or (state.attempts[key] or 0) >= 3 then return end
	local sent = NetChannel.SendNetMessage("CDOTAClientMsg_CraftNeutralItem", "{}")
	state.attempts[key] = (state.attempts[key] or 0) + 1
	if sent then
		state.pending = {kind = "craft", tier = available, crafted = info.times_crafted[available], expires = ctx.now + 8}
		state.status = "Craft neutral tier " .. available
	end
end

function neutral.use(ctx, api)
	if not ctx.settings.spells or NPC.IsChannellingAbility(ctx.hero) or NPC.HasModifier(ctx.hero, "modifier_fountain_aura_buff") or ctx.now < ctx.busyUntil
		or ctx.intent and ctx.intent.followAttack or ctx.farmCandidate and ctx.farmCandidate.start <= ctx.now + 0.4 then return false end
	local item = NPC.GetItemByIndex(ctx.hero, 16)
	if not item or not api.ready(ctx, item, true) then return false end
	local name = Ability.GetName(item)
	if (ctx.abilityAttempts[name] or 0) > ctx.now then return false end
	local range = Ability.GetCastRange(item)
	local enemy = ctx.target
	if enemy and (not Entity.IsEntity(enemy) or not Entity.IsAlive(enemy) or Entity.IsDormant(enemy) or not NPC.IsVisible(enemy)) then enemy = nil end
	local distance = enemy and ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy)) or math.huge
	local fighting = ctx.intent and ctx.intent.kind == "hero" and enemy == ctx.intent.target
	local attacked = ctx.laneThreat and ctx.laneThreat.attacked or (ctx.creepPressure or 0) > 0
	local kind, target, point
	if name == "item_polliwog_charm" or name == "item_seeds_of_serenity" then
		for _, ally in ipairs(ctx.allies) do
			if Entity.IsEntity(ally) and Entity.IsAlive(ally) and not Entity.IsDormant(ally)
				and Entity.GetMaxHealth(ally) - Entity.GetHealth(ally) >= 180
				and ctx.distance(ctx.position, Entity.GetAbsOrigin(ally)) <= range then
				if name == "item_polliwog_charm" and api.allowed(ctx, item, ally) then kind, target = "target", ally; break end
				if name == "item_seeds_of_serenity" and not NPC.IsRunning(ally) and distance > 650 then kind, point = "point", Entity.GetAbsOrigin(ally); break end
			end
		end
	elseif name == "item_mana_draught" then
		if NPC.GetMaxMana(ctx.hero) - NPC.GetMana(ctx.hero) > 150 then kind = "none" end
	elseif name == "item_essence_ring" then
		if ctx.health < 0.65 and (attacked or ctx.retreating or fighting) then kind = "none" end
	elseif name == "item_ash_legion_shield" then
		if attacked and ctx.health < 0.85 then kind = "none" end
	elseif name == "item_kobold_cup" or name == "item_spider_legs" then
		if ctx.retreating and distance < 1000 or fighting and distance > NPC.GetAttackRange(ctx.hero) + 100 then kind = "none" end
	elseif name == "item_dagger_of_ristul" or name == "item_flayers_bota" or name == "item_riftshadow_prism" then
		if fighting and NPC.IsAttacking(ctx.hero) and distance < NPC.GetAttackRange(ctx.hero) + 150 and ctx.health > 0.55 then kind = "none" end
	elseif name == "item_minotaur_horn" or name == "item_idol_of_screeauk" then
		if distance < 800 and (ctx.retreating or ctx.health < 0.6 and attacked) then kind = "none" end
	elseif name == "item_jidi_pollen_bag" then
		if fighting and distance < 600 then kind = "none" end
	elseif name == "item_demonicon" then
		if fighting or ctx.intent and ctx.intent.kind == "structure" then kind = "none" end
	elseif name == "item_crippling_crossbow" or name == "item_medallion_of_courage" then
		if fighting and distance <= range and api.allowed(ctx, item, enemy) then kind, target = "target", enemy end
	elseif name == "item_psychic_headband" then
		if ctx.retreating and distance < math.min(range, 400) and api.allowed(ctx, item, enemy) then kind, target = "target", enemy end
	end
	if not kind then return false end
	local previous = ctx.defensiveCast
	ctx.defensiveCast = not fighting
	local cast = api.cast(ctx, item, kind, target, point)
	ctx.defensiveCast = previous
	if cast then ctx.mode = "Use neutral item: " .. name:gsub("^item_", "") end
	return cast
end

return neutral
