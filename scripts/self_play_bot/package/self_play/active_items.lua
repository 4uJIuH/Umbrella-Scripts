local items = {}
local awareness = require("self_play.awareness")
local domination = require("self_play.domination")
local kv = XHelpers.xkv:GetKV("items").DOTAAbilities

items.managed = {}
for _, name in ipairs({"glimmer_cape", "soul_ring", "force_staff", "hurricane_pike", "lotus_orb", "sphere",
	"pipe", "crimson_guard", "ancient_janggo", "boots_of_bearing", "phase_boots", "blade_mail", "black_king_bar",
	"manta", "satanic", "bloodstone", "shivas_guard", "urn_of_shadows", "spirit_vessel", "diffusal_blade", "disperser", "nullifier", "dust",
	"invis_sword", "silver_edge", "ghost", "ethereal_blade", "refresher", "refresher_shard", "mask_of_madness", "armlet",
	"sheepstick", "abyssal_blade", "orchid", "bloodthorn", "rod_of_atos", "gungir",
	"dagon", "dagon_2", "dagon_3", "dagon_4", "dagon_5", "helm_of_the_dominator", "helm_of_the_overlord"}) do
	items.managed["item_" .. name] = true
end

local function value(name, key, fallback)
	local record = kv[name]
	local result = record and record.AbilityValues and record.AbilityValues[key]
	if type(result) == "table" then result = result.value end
	return tonumber(result) or fallback
end

local function live(unit)
	return unit and Entity.IsEntity(unit) and Entity.IsAlive(unit) and not Entity.IsDormant(unit) and NPC.IsVisible(unit)
end

local function get(ctx, api, name)
	local item = NPC.GetItem(ctx.hero, name, true)
	if item and api.ready(ctx, item, true) and (ctx.abilityAttempts[name] or 0) <= ctx.now then return item end
end

local function targetCast(ctx, api, item, target)
	return live(target) and ctx.distance(ctx.position, Entity.GetAbsOrigin(target)) <= Ability.GetCastRange(item)
		and api.allowed(ctx, item, target) and api.cast(ctx, item, "target", target)
end

local function controlThreat(ctx)
	for _, enemy in ipairs(ctx.enemies) do
		if live(enemy) and not NPC.IsIllusion(enemy) and ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy)) < 1100 then
			for index = 0, 31 do
				local ability = NPC.GetAbilityByIndex(enemy, index)
				local effect = ability and ctx.catalog.abilities[Ability.GetName(ability)] or nil
				if effect and effect.disable and Ability.IsActivated(ability) and Ability.IsReady(ability) then return true end
			end
		end
	end
	return false
end

local function mantaDispel(ctx)
	if NPC.IsSilenced(ctx.hero) then return true end
	for _, name in ipairs({"modifier_orchid_malevolence_debuff", "modifier_bloodthorn_debuff",
		"modifier_item_diffusal_blade_slow", "modifier_item_disperser_movespeed", "modifier_item_dustofappearance"}) do
		if NPC.HasModifier(ctx.hero, name) then return true end
	end
	return false
end

function items.fuel(ctx, api, ability)
	local ring = get(ctx, api, "item_soul_ring")
	if not ring or ctx.retreating or NPC.HasModifier(ctx.hero, "modifier_fountain_aura_buff")
		or NPC.HasModifier(ctx.hero, "modifier_item_soul_ring_buff") then return false end
	local gain = value("item_soul_ring", "mana_gain", 170)
	local cost, mana = Ability.GetManaCost(ability), NPC.GetMana(ctx.hero)
	local healthCost = tonumber(kv.item_soul_ring and kv.item_soul_ring.AbilityHealthCost) or 170
	local remaining = Entity.GetHealth(ctx.hero) - healthCost
	if cost < gain * 0.45 or mana + gain < cost or NPC.GetMaxMana(ctx.hero) - mana < gain * 0.6
		or remaining < Entity.GetMaxHealth(ctx.hero) * 0.5
		or awareness.damage(ctx, ctx.position, 1.5) > remaining * 0.3 then return false end
	return api.cast(ctx, ring, "none")
end

function items.run(ctx, api, defensiveOnly)
	if not ctx.settings.spells then return false end
	local armlet = get(ctx, api, "item_armlet")
	if armlet and ctx.health < 0.4 and not Ability.GetToggleState(armlet) then return api.cast(ctx, armlet, "toggle") end
	local enemy = live(ctx.target) and NPC.IsHero(ctx.target) and not Entity.IsSameTeam(ctx.hero, ctx.target) and ctx.target or nil
	local fighting = enemy and ctx.intent and ctx.intent.kind == "hero"
	local hurt = Hero.GetRecentDamage(ctx.hero) > 0 or ctx.laneThreat and ctx.laneThreat.attacked
	local danger = ctx.hardRetreat or hurt or awareness.damage(ctx, ctx.position, 1.2) > Entity.GetHealth(ctx.hero) * 0.18
	local debuffed = mantaDispel(ctx)
	local candidates = {ctx.hero}
	for _, ally in ipairs(ctx.allies) do if ally ~= ctx.hero and live(ally) then candidates[#candidates + 1] = ally end end
	for _, name in ipairs({"item_glimmer_cape", "item_lotus_orb", "item_sphere", "item_force_staff", "item_hurricane_pike"}) do
		local item = get(ctx, api, name)
		if item then
			local best, bestScore
			for _, ally in ipairs(candidates) do
				local point = Entity.GetAbsOrigin(ally)
				local hp = Entity.GetHealth(ally) / math.max(1, Entity.GetMaxHealth(ally))
				local incoming = awareness.damage(ctx, point, 1.2)
				local attacked = Hero.GetRecentDamage(ally) > 0 or ally == ctx.hero and hurt
				local threatened = incoming > Entity.GetHealth(ally) * 0.18 or attacked and hp < 0.8
				local legal = ctx.distance(ctx.position, point) <= Ability.GetCastRange(item) and api.allowed(ctx, item, ally)
				if name == "item_glimmer_cape" then legal = legal and not NPC.HasModifier(ally, "modifier_item_glimmer_cape_fade")
				elseif name == "item_lotus_orb" then
					legal = legal and not NPC.HasModifier(ally, "modifier_item_lotus_orb_active")
					threatened = threatened or NPC.IsSilenced(ally) or NPC.HasState(ally, Enum.ModifierState.MODIFIER_STATE_ROOTED)
				elseif name == "item_sphere" then legal = legal and ally ~= ctx.hero and not NPC.IsLinkensProtected(ally) and not danger
				else
					local forward = Entity.GetRotation(ally):GetForward()
					local length = value(name, "push_length", 600)
					local destination = Vector(point.x + forward.x * length, point.y + forward.y * length, point.z)
					legal = legal and GridNav.IsTraversable(destination) and not ctx.unsafePosition(destination)
						and awareness.damage(ctx, destination, 1.2) + 40 < incoming
				end
				local score = incoming + (1 - hp) * 300
				if legal and threatened and (not bestScore or score > bestScore) then best, bestScore = ally, score end
			end
			if best and targetCast(ctx, api, item, best) then return true end
		end
	end
	local bkb = get(ctx, api, "item_black_king_bar")
	if bkb and not NPC.HasState(ctx.hero, Enum.ModifierState.MODIFIER_STATE_MAGIC_IMMUNE) then
		local committed = fighting and not ctx.retreating and ctx.nearEnemies > 0
		if controlThreat(ctx) and (danger or committed or ctx.health < 0.7) then
			if api.cast(ctx, bkb, "none") then return true end
		end
	end
	for _, name in ipairs({"item_manta", "item_blade_mail", "item_pipe", "item_crimson_guard", "item_satanic", "item_bloodstone"}) do
		local item = get(ctx, api, name)
		local use = false
		if item then
			if name == "item_manta" then
				local farming = not fighting and not danger and ctx.farmCandidate and ctx.farmCandidate.inRange
				use = debuffed or not defensiveOnly and (fighting and (NPC.IsAttacking(ctx.hero) or ctx.nearEnemies >= 2) or farming)
			elseif name == "item_satanic" then use = debuffed or ctx.health < 0.65 and NPC.IsAttacking(ctx.hero)
			elseif name == "item_bloodstone" then use = fighting and ctx.health < 0.75
			elseif name == "item_blade_mail" then use = hurt and ctx.nearEnemies > 0
			else
				local count = 0
				for _, ally in ipairs(candidates) do
					if ctx.distance(ctx.position, Entity.GetAbsOrigin(ally)) <= 1200 and (Hero.GetRecentDamage(ally) > 0
						or awareness.damage(ctx, Entity.GetAbsOrigin(ally), 1.2) > Entity.GetHealth(ally) * 0.18) then count = count + 1 end
				end
				use = count >= 2 or danger and ctx.health < 0.65 and ctx.nearEnemies > 0
			end
			if use and api.cast(ctx, item, "none") then return true end
		end
	end
	for _, name in ipairs({"item_invis_sword", "item_silver_edge", "item_ghost"}) do
		local item = get(ctx, api, name)
		if item and danger and ctx.nearEnemies > 0 then
			local use = ctx.retreating and not NPC.HasModifier(ctx.hero, "modifier_invisible")
			if name == "item_ghost" then
				use = hurt and ctx.health < 0.65 and not NPC.HasModifier(ctx.hero, "modifier_ghost_state")
					and enemy and NPC.IsAttacking(enemy) and awareness.burst(ctx, enemy, ctx.hero,
						ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy)), 2) < Entity.GetHealth(ctx.hero) * 0.15
			end
			if use and api.cast(ctx, item, "none") then return true end
		end
	end
	if defensiveOnly then return false end
	if domination.run(ctx, api) then return true end
	local ring = get(ctx, api, "item_soul_ring")
	if ring and not ctx.retreating and not NPC.HasModifier(ctx.hero, "modifier_fountain_aura_buff") then
		local mana, hp = NPC.GetMana(ctx.hero), Entity.GetHealth(ctx.hero)
		local gain = value("item_soul_ring", "mana_gain", 170)
		local healthCost = tonumber(kv.item_soul_ring and kv.item_soul_ring.AbilityHealthCost) or 170
		local need
		for index = 0, 31 do
			local ability = NPC.GetAbilityByIndex(ctx.hero, index)
			if ability and Ability.GetLevel(ability) > 0 and not Ability.IsHidden(ability) and Ability.IsActivated(ability)
				and not Ability.IsPassive(ability) and Ability.IsReady(ability) and (ctx.abilityAttempts[Ability.GetName(ability)] or 0) <= ctx.now then
				local cost = Ability.GetManaCost(ability)
				if cost > mana and cost <= mana + gain and enemy and (fighting or hurt)
					and ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy)) <= math.max(Ability.GetCastRange(ability), 500) then need = true end
			end
		end
		if need and NPC.GetMaxMana(ctx.hero) - mana >= gain * 0.6 and hp - healthCost > Entity.GetMaxHealth(ctx.hero) * 0.5
			and awareness.damage(ctx, ctx.position, 1.5) < (hp - healthCost) * 0.3 then return api.cast(ctx, ring, "none") end
	end
	for _, name in ipairs({"item_spirit_vessel", "item_urn_of_shadows"}) do
		local item = get(ctx, api, name)
		if item and Item.GetCurrentCharges(item) > 0 then
			if fighting and not NPC.HasModifier(enemy, "modifier_" .. name .. "_damage") and targetCast(ctx, api, item, enemy) then return true end
			for _, ally in ipairs(candidates) do
				if Entity.GetMaxHealth(ally) - Entity.GetHealth(ally) > value(name, "soul_heal_amount", 30) * 6
					and Hero.GetRecentDamage(ally) == 0 and awareness.damage(ctx, Entity.GetAbsOrigin(ally), 2) == 0
					and not NPC.HasModifier(ally, "modifier_" .. name .. "_heal") and targetCast(ctx, api, item, ally) then return true end
			end
		end
	end
	for _, name in ipairs({"item_phase_boots", "item_boots_of_bearing", "item_ancient_janggo", "item_shivas_guard"}) do
		local item = get(ctx, api, name)
		if item then
			local use = false
			if name == "item_phase_boots" then use = NPC.IsRunning(ctx.hero) and (ctx.retreating or fighting or ctx.moveGoal and ctx.distance(ctx.position, ctx.moveGoal) > 650)
			elseif name == "item_shivas_guard" then use = enemy and (fighting or danger) and ctx.distance(ctx.position, ctx.predict(enemy, 0.5)) < value(name, "blast_radius", 825) - 100
			else use = ctx.nearAllies >= 2 and (fighting or danger) end
			if use and api.cast(ctx, item, "none") then return true end
		end
	end
	if enemy and (fighting or danger) then
		for _, name in ipairs({"item_sheepstick", "item_abyssal_blade", "item_bloodthorn", "item_orchid", "item_gungir", "item_rod_of_atos"}) do
			local item = get(ctx, api, name)
			local silence = name == "item_bloodthorn" or name == "item_orchid"
			if item and not NPC.IsStunned(enemy) and not NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_ROOTED)
				and not (silence and NPC.IsSilenced(enemy)) then
				if name == "item_gungir" then
					local point = ctx.predict(enemy, 0.25)
					if not NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_MAGIC_IMMUNE)
						and ctx.distance(ctx.position, point) <= Ability.GetCastRange(item) then return api.cast(ctx, item, "point", nil, point) end
				elseif targetCast(ctx, api, item, enemy) then return true end
			end
		end
		for _, name in ipairs({"item_nullifier", "item_disperser", "item_diffusal_blade"}) do
			local item = get(ctx, api, name)
			if item and not NPC.IsStunned(enemy) and not NPC.HasModifier(enemy, "modifier_item_nullifier_mute")
				and targetCast(ctx, api, item, enemy) then return true end
		end
	end
	if fighting and not ctx.retreating then
		for _, name in ipairs({"item_dagon_5", "item_dagon_4", "item_dagon_3", "item_dagon_2", "item_dagon"}) do
			local item = get(ctx, api, name)
			if item and targetCast(ctx, api, item, enemy) then return true end
		end
		local ethereal = get(ctx, api, "item_ethereal_blade")
		if ethereal and not NPC.HasModifier(enemy, "modifier_item_ethereal_blade_ethereal") then
			local magic = 0
			for index = 0, 7 do
				local spell = NPC.GetAbilityByIndex(ctx.hero, index)
				if spell and api.ready(ctx, spell, false) and Ability.GetManaCost(spell) + Ability.GetManaCost(ethereal) <= NPC.GetMana(ctx.hero) then
					magic = magic + math.max(Ability.GetDamage(spell), ctx.planner.levelValue((ctx.catalog.abilities[Ability.GetName(spell)] or {}).damage, Ability.GetLevel(spell)))
				end
			end
			if magic > NPC.GetTrueDamage(ctx.hero) * 3 and targetCast(ctx, api, ethereal, enemy) then return true end
		end
		for _, name in ipairs({"item_refresher_shard", "item_refresher"}) do
			local item = get(ctx, api, name)
			if item and ctx.health > 0.4 and ctx.distance(ctx.position, Entity.GetAbsOrigin(enemy)) < 1100 then
				local count, ultimate, cost = 0, false, Ability.GetManaCost(item)
				for index = 0, 7 do
					local spell = NPC.GetAbilityByIndex(ctx.hero, index)
					if spell and Ability.GetLevel(spell) > 0 and not Ability.IsHidden(spell) and not Ability.IsPassive(spell)
						and Ability.IsActivated(spell) and Ability.GetCooldown(spell) > 15 then
						count, cost = count + 1, cost + Ability.GetManaCost(spell)
						ultimate = ultimate or Ability.IsUltimate(spell)
					end
				end
				if (ultimate or count >= 2) and NPC.GetMana(ctx.hero) >= cost and Entity.GetHealth(enemy) > NPC.GetTrueDamage(ctx.hero) * 2
					and api.cast(ctx, item, "none") then return true end
			end
		end
	end
	local mask = get(ctx, api, "item_mask_of_madness")
	if mask and NPC.IsAttacking(ctx.hero) and ctx.health > 0.65 and not danger and not ctx.retreating then
		local needsSpell = false
		for index = 0, 7 do
			local spell = NPC.GetAbilityByIndex(ctx.hero, index)
			if spell and api.ready(ctx, spell, false) and Ability.GetManaCost(spell) > 0 then needsSpell = true end
		end
		if not needsSpell then return api.cast(ctx, mask, "none") end
	end
	return false
end

return items
