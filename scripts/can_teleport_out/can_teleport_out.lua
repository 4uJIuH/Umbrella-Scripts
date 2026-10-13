---@diagnostic disable: undefined-global

local CanTeleportOut = {}

local FONT = Render.LoadFont("MuseoSansEx", Enum.FontCreate.FONTFLAG_ANTIALIAS)

local TP_CHANNEL_TIME = 3.0
local DEFAULT_INTERRUPT_RADIUS = 1200
local DEFAULT_DAMAGE_RADIUS = 1200
local CAST_RANGE_BUFFER = 160
local ATTACK_RANGE_BUFFER = 95
local PROJECTILE_MIN_SPEED = 900
local UPDATE_INTERVAL = 0.12
local MAX_SCAN_ABILITIES = 24
local ITEM_SLOT_MIN = 0
local ITEM_SLOT_MAX = 16

local SAFE_COLOR = Color(80, 235, 125, 245)
local WARN_COLOR = Color(255, 205, 75, 245)
local DANGER_COLOR = Color(255, 80, 80, 245)
local TEXT_COLOR = Color(245, 248, 250, 250)
local SHADOW_COLOR = Color(0, 0, 0, 205)
local PANEL_BG = Color(8, 10, 12, 185)
local PANEL_BORDER = Color(0, 0, 0, 190)

local INTERRUPT_ABILITIES = {
	abyssal_underlord_pit_of_malice = true,
	ancient_apparition_cold_feet = true,
	antimage_mana_void = true,
	axe_berserkers_call = true,
	bane_fiends_grip = true,
	bane_nightmare = true,
	batrider_flaming_lasso = true,
	beastmaster_primal_roar = true,
	bloodseeker_blood_bath = true,
	centaur_hoof_stomp = true,
	chaos_knight_chaos_bolt = true,
	crystal_maiden_frostbite = true,
	dark_troll_warlord_ensnare = true,
	dark_willow_bramble_maze = true,
	dark_willow_cursed_crown = true,
	death_prophet_silence = true,
	disruptor_glimpse = true,
	disruptor_kinetic_field = true,
	disruptor_static_storm = true,
	doom_bringer_doom = true,
	dragon_knight_dragon_tail = true,
	drow_ranger_wave_of_silence = true,
	earth_spirit_boulder_smash = true,
	earth_spirit_geomagnetic_grip = true,
	earth_spirit_petrify = true,
	earth_spirit_rolling_boulder = true,
	earthshaker_echo_slam = true,
	earthshaker_enchant_totem = true,
	earthshaker_fissure = true,
	elder_titan_echo_stomp = true,
	ember_spirit_searing_chains = true,
	enigma_black_hole = true,
	faceless_void_chronosphere = true,
	grimstroke_spirit_walk = true,
	hoodwink_bushwhack = true,
	invoker_cold_snap = true,
	invoker_deafening_blast = true,
	invoker_tornado = true,
	jakiro_ice_path = true,
	kunkka_torrent = true,
	legion_commander_duel = true,
	leshrac_split_earth = true,
	lich_sinister_gaze = true,
	lion_impale = true,
	lion_voodoo = true,
	lone_druid_savage_roar = true,
	luna_lucent_beam = true,
	magnataur_horn_toss = true,
	magnataur_reverse_polarity = true,
	marci_rebound = true,
	mars_spear = true,
	medusa_stone_gaze = true,
	meepo_earthbind = true,
	mirana_arrow = true,
	monkey_king_boundless_strike = true,
	muerta_dead_shot = true,
	naga_siren_ensnare = true,
	necrolyte_reapers_scythe = true,
	nevermore_requiem = true,
	night_stalker_crippling_fear = true,
	nyx_assassin_impale = true,
	ogre_magi_fireblast = true,
	ogre_magi_unrefined_fireblast = true,
	oracle_fortunes_end = true,
	obsidian_destroyer_astral_imprisonment = true,
	pangolier_gyroshell = true,
	primal_beast_onslaught = true,
	primal_beast_pulverize = true,
	pudge_dismember = true,
	pudge_meat_hook = true,
	puck_dream_coil = true,
	puck_waning_rift = true,
	queenofpain_sonic_wave = true,
	rattletrap_hookshot = true,
	riki_smoke_screen = true,
	ringmaster_tame_the_beasts = true,
	rubick_telekinesis = true,
	sandking_burrowstrike = true,
	shadow_demon_disruption = true,
	shadow_shaman_shackles = true,
	shadow_shaman_voodoo = true,
	silencer_global_silence = true,
	silencer_last_word = true,
	skeleton_king_hellfire_blast = true,
	skywrath_mage_ancient_seal = true,
	slardar_slithereen_crush = true,
	snapfire_firesnap_cookie = true,
	spirit_breaker_charge_of_darkness = true,
	spirit_breaker_greater_bash = true,
	storm_spirit_electric_vortex = true,
	sven_storm_bolt = true,
	techies_stasis_trap = true,
	tidehunter_ravage = true,
	tiny_toss = true,
	tiny_avalanche = true,
	treant_overgrowth = true,
	tusk_walrus_punch = true,
	vengefulspirit_magic_missile = true,
	vengefulspirit_nether_swap = true,
	void_spirit_aether_remnant = true,
	warlock_rain_of_chaos = true,
	windrunner_shackleshot = true,
	winter_wyvern_winters_curse = true,
	witch_doctor_paralyzing_cask = true,
}

local INTERRUPT_ITEMS = {
	item_abyssal_blade = true,
	item_cyclone = true,
	item_force_staff = true,
	item_gungir = true,
	item_harpoon = true,
	item_heavens_halberd = true,
	item_hurricane_pike = true,
	item_meteor_hammer = true,
	item_orchid = true,
	item_rod_of_atos = true,
	item_sheepstick = true,
	item_bloodthorn = true,
	item_wind_waker = true,
}

local PASSIVE_ATTACK_INTERRUPTS = {
	faceless_void_time_lock = true,
	slardar_bash = true,
	spirit_breaker_greater_bash = true,
	troll_warlord_berserkers_rage = true,
	item_abyssal_blade = true,
	item_basher = true,
	item_skull_basher = true,
}

local DAMAGE_ITEMS = {
	item_dagon = true,
	item_dagon_2 = true,
	item_dagon_3 = true,
	item_dagon_4 = true,
	item_dagon_5 = true,
	item_ethereal_blade = true,
	item_nullifier = true,
}

local function call(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end

	local ok, a, b, c = pcall(fn, ...)
	if ok then
		return a, b, c
	end

	return nil
end

local function widget_value(widget, fallback)
	if not widget or type(widget.Get) ~= "function" then
		return fallback
	end

	local ok, value = pcall(widget.Get, widget)
	if ok then
		return value
	end

	return fallback
end

local function clamp(value, low, high)
	value = tonumber(value) or 0
	if value < low then
		return low
	end
	if value > high then
		return high
	end
	return value
end

local function has_flag(value, flag)
	value = tonumber(value) or 0
	flag = tonumber(flag) or 0
	if flag <= 0 then
		return false
	end

	if bit and bit.band then
		return bit.band(value, flag) ~= 0
	end

	return value % (flag * 2) >= flag
end

local function game_time()
	return tonumber(call(GameRules and GameRules.GetGameTime) or call(GlobalVars and GlobalVars.GetCurTime) or 0) or 0
end

local function current_time()
	return tonumber(call(GlobalVars and GlobalVars.GetCurTime) or game_time()) or 0
end

local function ability_name(ability)
	return call(Ability and Ability.GetName, ability) or call(Ability and Ability.GetBaseName, ability) or ""
end

local function entity_name(entity)
	return call(NPC and NPC.GetUnitName, entity) or call(Entity and Entity.GetUnitName, entity) or "enemy"
end

local function hero_short_name(hero)
	local name = entity_name(hero)
	name = name:gsub("^npc_dota_hero_", "")
	name = name:gsub("_", " ")
	if #name > 15 then
		name = name:sub(1, 15)
	end
	return name
end

local function is_alive_unit(unit)
	return unit and call(Entity and Entity.IsAlive, unit) == true
end

local function is_valid_enemy(unit)
	if not is_alive_unit(unit) then
		return false
	end
	if call(Entity and Entity.IsDormant, unit) == true then
		return false
	end
	if call(NPC and NPC.IsIllusion, unit) == true then
		return false
	end
	if call(NPC and NPC.IsKillable, unit) == false then
		return false
	end
	return true
end

local function is_disabled_or_unable_to_cast(unit)
	local states = Enum and Enum.ModifierState
	if not states then
		return call(NPC and NPC.IsStunned, unit) == true
	end

	local bad_states = {
		states.MODIFIER_STATE_STUNNED,
		states.MODIFIER_STATE_HEXED,
		states.MODIFIER_STATE_TAUNTED,
		states.MODIFIER_STATE_FEARED,
		states.MODIFIER_STATE_COMMAND_RESTRICTED,
		states.MODIFIER_STATE_OUT_OF_GAME,
	}

	for i = 1, #bad_states do
		local state = bad_states[i]
		if state ~= nil and call(NPC and NPC.HasState, unit, state) == true then
			return true
		end
	end

	return false
end

local function target_has_state(unit, state_name)
	local states = Enum and Enum.ModifierState
	local state = states and states[state_name]
	if state == nil then
		return false
	end

	return call(NPC and NPC.HasState, unit, state) == true
end

local function get_tp_item(hero)
	return call(NPC and NPC.GetItem, hero, "item_tpscroll", false)
		or call(NPC and NPC.GetItem, hero, "item_travel_boots", false)
		or call(NPC and NPC.GetItem, hero, "item_travel_boots_2", false)
end

local function tp_is_castable(hero)
	local tp = get_tp_item(hero)
	if not tp then
		return false, "no tp"
	end

	local mana = tonumber(call(NPC and NPC.GetMana, hero) or 0) or 0
	if call(Ability and Ability.IsCastable, tp, mana) == true then
		return true, "ready"
	end

	local cooldown = tonumber(call(Ability and Ability.GetCooldown, tp) or 0) or 0
	if cooldown > 0.05 then
		return false, ("tp cd %.1fs"):format(cooldown)
	end

	return false, "tp unavailable"
end

local function get_channel_time()
	local value = widget_value(CanTeleportOut.channel_time, TP_CHANNEL_TIME)
	return clamp(value, 2.0, 6.0)
end

local function get_health_after_regen(hero, seconds)
	local health = tonumber(call(Entity and Entity.GetHealth, hero) or 0) or 0
	local regen = tonumber(call(NPC and NPC.GetHealthRegen, hero) or 0) or 0
	return health + math.max(0, seconds) * math.max(0, regen)
end

local function physical_multiplier(target)
	local multiplier = tonumber(call(NPC and NPC.GetArmorDamageMultiplier, target))
	if multiplier and multiplier > 0 then
		return multiplier
	end

	local reduction = tonumber(call(NPC and NPC.GetPhysicalDamageReduction, target))
	if reduction then
		return clamp(1 - reduction, 0.05, 2.5)
	end

	return 1
end

local function magical_multiplier(target)
	local multiplier = tonumber(call(NPC and NPC.GetMagicalArmorDamageMultiplier, target))
	if multiplier and multiplier > 0 then
		return multiplier
	end

	return 0.75
end

local function ability_damage_to_target(ability, target)
	local damage = tonumber(call(Ability and Ability.GetDamage, ability) or 0) or 0
	if damage <= 0 then
		return 0
	end

	local damage_type = call(Ability and Ability.GetDamageType, ability)
	if Enum and Enum.DamageTypes then
		if damage_type == Enum.DamageTypes.DAMAGE_TYPE_PHYSICAL then
			return damage * physical_multiplier(target)
		end
		if damage_type == Enum.DamageTypes.DAMAGE_TYPE_PURE or damage_type == Enum.DamageTypes.DAMAGE_TYPE_HP_REMOVAL then
			return damage
		end
	end

	return damage * magical_multiplier(target)
end

local function unit_distance(a, b)
	local a_pos = call(Entity and Entity.GetAbsOrigin, a)
	local b_pos = call(Entity and Entity.GetAbsOrigin, b)
	if not a_pos or not b_pos or not a_pos.Distance2D then
		return math.huge
	end

	return a_pos:Distance2D(b_pos)
end

local function get_cast_range(caster, ability)
	local range = tonumber(call(Ability and Ability.GetCastRange, ability) or 0) or 0
	if range <= 0 then
		range = DEFAULT_INTERRUPT_RADIUS
	end

	return range + (tonumber(call(NPC and NPC.GetCastRangeBonus, caster) or 0) or 0)
end

local function can_ability_reach_target(caster, ability, target, extra_radius)
	local distance = unit_distance(caster, target)
	local cast_range = get_cast_range(caster, ability)
	local behavior = tonumber(call(Ability and Ability.GetBehavior, ability) or 0) or 0
	local no_target = Enum and Enum.AbilityBehavior and Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_NO_TARGET or 4
	local point = Enum and Enum.AbilityBehavior and Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_POINT or 16
	local aoe = Enum and Enum.AbilityBehavior and Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_AOE or 32

	if has_flag(behavior, no_target) then
		return distance <= math.max(cast_range, extra_radius or DEFAULT_INTERRUPT_RADIUS)
	end

	if has_flag(behavior, point) or has_flag(behavior, aoe) then
		return distance <= cast_range + 450 + CAST_RANGE_BUFFER
	end

	return distance <= cast_range + CAST_RANGE_BUFFER
end

local function first_attack_lands_in_window(hero, enemy, window)
	if target_has_state(enemy, "MODIFIER_STATE_DISARMED") then
		return false
	end

	local distance = unit_distance(hero, enemy)
	local attack_range = (tonumber(call(NPC and NPC.GetAttackRange, enemy) or 0) or 0)
		+ (tonumber(call(NPC and NPC.GetAttackRangeBonus, enemy) or 0) or 0)
		+ ATTACK_RANGE_BUFFER

	local move_time = 0
	if distance > attack_range then
		local move_speed = tonumber(call(NPC and NPC.GetMoveSpeed, enemy) or 0) or 0
		if move_speed <= 0 then
			return false
		end
		move_time = (distance - attack_range) / move_speed
	end

	local attack_point = tonumber(call(NPC and NPC.GetAttackAnimPoint, enemy) or 0) or 0
	local projectile_time = 0
	if call(NPC and NPC.IsRanged, enemy) == true then
		local projectile_speed = tonumber(call(NPC and NPC.GetAttackProjectileSpeed, enemy) or PROJECTILE_MIN_SPEED) or PROJECTILE_MIN_SPEED
		projectile_speed = math.max(PROJECTILE_MIN_SPEED, projectile_speed)
		projectile_time = math.min(1.6, distance / projectile_speed)
	end

	return move_time + attack_point + projectile_time <= window
end

local function ability_will_be_ready(caster, ability, window)
	if call(Ability and Ability.IsHidden, ability) == true then
		return false
	end
	if call(Ability and Ability.IsPassive, ability) == true then
		return false
	end
	if call(Ability and Ability.IsActivated, ability) == false then
		return false
	end

	local level = tonumber(call(Ability and Ability.GetLevel, ability) or 0) or 0
	if level <= 0 then
		return false
	end

	local cooldown = tonumber(call(Ability and Ability.GetCooldown, ability) or 0) or 0
	local cast_point = tonumber(call(Ability and Ability.GetCastPoint, ability, true) or 0) or 0
	if cooldown + cast_point > window then
		return false
	end

	local mana = tonumber(call(NPC and NPC.GetMana, caster) or 0) or 0
	local mana_regen = tonumber(call(NPC and NPC.GetManaRegen, caster) or 0) or 0
	local mana_cost = tonumber(call(Ability and Ability.GetManaCost, ability) or 0) or 0
	if mana + mana_regen * math.max(0, cooldown) < mana_cost then
		return false
	end

	return true, cooldown + cast_point
end

local function item_will_be_ready(caster, item, window)
	if call(Ability and Ability.IsActivated, item) == false then
		return false
	end
	if Item and Item.IsItemEnabled and call(Item.IsItemEnabled, item) == false then
		return false
	end

	local cooldown = tonumber(call(Ability and Ability.GetCooldown, item) or 0) or 0
	local cast_point = tonumber(call(Ability and Ability.GetCastPoint, item, true) or 0) or 0
	if cooldown + cast_point > window then
		return false
	end

	local mana = tonumber(call(NPC and NPC.GetMana, caster) or 0) or 0
	local mana_cost = tonumber(call(Ability and Ability.GetManaCost, item) or 0) or 0
	if mana < mana_cost then
		return false
	end

	return true, cooldown + cast_point
end

local function scan_interrupts(hero, enemy, window, reasons)
	if is_disabled_or_unable_to_cast(enemy) then
		return false
	end

	local silent = call(NPC and NPC.IsSilenced, enemy) == true
	local muted = target_has_state(enemy, "MODIFIER_STATE_MUTED")
	local can_land_attack = first_attack_lands_in_window(hero, enemy, window)

	for i = 0, MAX_SCAN_ABILITIES do
		local ability = call(NPC and NPC.GetAbilityByIndex, enemy, i)
		if ability then
			local name = ability_name(ability)
			if can_land_attack and PASSIVE_ATTACK_INTERRUPTS[name] then
				reasons[#reasons + 1] = ("%s possible bash/root"):format(hero_short_name(enemy))
				return true
			end

			if INTERRUPT_ABILITIES[name] and not silent then
				local ready, ready_at = ability_will_be_ready(enemy, ability, window)
				if ready and can_ability_reach_target(enemy, ability, hero, widget_value(CanTeleportOut.interrupt_radius, DEFAULT_INTERRUPT_RADIUS)) then
					reasons[#reasons + 1] = ("%s %s %.1fs"):format(hero_short_name(enemy), name:gsub("^item_", ""):gsub("_", " "), ready_at or 0)
					return true
				end
			end
		end
	end

	for i = ITEM_SLOT_MIN, ITEM_SLOT_MAX do
		local item = call(NPC and NPC.GetItemByIndex, enemy, i)
		if item then
			local name = ability_name(item)
			if can_land_attack and PASSIVE_ATTACK_INTERRUPTS[name] then
				reasons[#reasons + 1] = ("%s possible bash"):format(hero_short_name(enemy))
				return true
			end

			if INTERRUPT_ITEMS[name] and not muted then
				local ready, ready_at = item_will_be_ready(enemy, item, window)
				if ready and can_ability_reach_target(enemy, item, hero, widget_value(CanTeleportOut.interrupt_radius, DEFAULT_INTERRUPT_RADIUS)) then
					reasons[#reasons + 1] = ("%s %s %.1fs"):format(hero_short_name(enemy), name:gsub("^item_", ""):gsub("_", " "), ready_at or 0)
					return true
				end
			end
		end
	end

	return false
end

local function incoming_attack_damage(hero, enemy, window)
	local distance = unit_distance(hero, enemy)
	local attack_range = (tonumber(call(NPC and NPC.GetAttackRange, enemy) or 0) or 0)
		+ (tonumber(call(NPC and NPC.GetAttackRangeBonus, enemy) or 0) or 0)
		+ ATTACK_RANGE_BUFFER

	local move_time = 0
	if distance > attack_range then
		local move_speed = tonumber(call(NPC and NPC.GetMoveSpeed, enemy) or 0) or 0
		if move_speed <= 0 then
			return 0, 0
		end
		move_time = (distance - attack_range) / move_speed
	end

	local attack_point = tonumber(call(NPC and NPC.GetAttackAnimPoint, enemy) or 0) or 0
	local seconds_per_attack = tonumber(call(NPC and NPC.GetSecondsPerAttack, enemy, false) or 1.7) or 1.7
	seconds_per_attack = math.max(0.2, seconds_per_attack)

	local projectile_time = 0
	if call(NPC and NPC.IsRanged, enemy) == true then
		local projectile_speed = tonumber(call(NPC and NPC.GetAttackProjectileSpeed, enemy) or PROJECTILE_MIN_SPEED) or PROJECTILE_MIN_SPEED
		projectile_speed = math.max(PROJECTILE_MIN_SPEED, projectile_speed)
		projectile_time = math.min(1.6, distance / projectile_speed)
	end

	local first_hit_time = move_time + attack_point + projectile_time
	if first_hit_time > window then
		return 0, 0
	end

	local attack_count = 1 + math.floor((window - first_hit_time) / seconds_per_attack)
	attack_count = clamp(attack_count, 0, 12)

	local damage = tonumber(call(NPC and NPC.GetTrueMaximumDamage, enemy) or call(NPC and NPC.GetTrueDamage, enemy) or 0) or 0
	damage = damage * physical_multiplier(hero)

	return damage * attack_count, attack_count
end

local function incoming_spell_damage(hero, enemy, window)
	if is_disabled_or_unable_to_cast(enemy) or call(NPC and NPC.IsSilenced, enemy) == true then
		return 0
	end

	local total = 0
	for i = 0, MAX_SCAN_ABILITIES do
		local ability = call(NPC and NPC.GetAbilityByIndex, enemy, i)
		if ability then
			local ready = ability_will_be_ready(enemy, ability, window)
			if ready and can_ability_reach_target(enemy, ability, hero, widget_value(CanTeleportOut.damage_radius, DEFAULT_DAMAGE_RADIUS)) then
				total = total + ability_damage_to_target(ability, hero)
			end
		end
	end

	if target_has_state(enemy, "MODIFIER_STATE_MUTED") then
		return total
	end

	for i = ITEM_SLOT_MIN, ITEM_SLOT_MAX do
		local item = call(NPC and NPC.GetItemByIndex, enemy, i)
		if item then
			local name = ability_name(item)
			if DAMAGE_ITEMS[name] then
				local ready = item_will_be_ready(enemy, item, window)
				if ready and can_ability_reach_target(enemy, item, hero, widget_value(CanTeleportOut.damage_radius, DEFAULT_DAMAGE_RADIUS)) then
					total = total + ability_damage_to_target(item, hero)
				end
			end
		end
	end

	return total
end

local function nearby_enemies(hero, radius)
	local pos = call(Entity and Entity.GetAbsOrigin, hero)
	local team = call(Entity and Entity.GetTeamNum, hero)
	if not pos or not team then
		return {}
	end

	local heroes = call(Heroes and Heroes.InRadius, pos, radius, team, Enum.TeamType.TEAM_ENEMY, true, true)
	if type(heroes) == "table" then
		return heroes
	end

	return call(Entity and Entity.GetHeroesInRadius, hero, radius, Enum.TeamType.TEAM_ENEMY, true, true) or {}
end

local function nearby_enemy_units(hero, radius)
	local pos = call(Entity and Entity.GetAbsOrigin, hero)
	local team = call(Entity and Entity.GetTeamNum, hero)
	if not pos or not team then
		return {}
	end

	return call(NPCs and NPCs.InRadius, pos, radius, team, Enum.TeamType.TEAM_ENEMY, true, true) or {}
end

local function append_reason(reasons, text)
	if #reasons < 4 then
		reasons[#reasons + 1] = text
	end
end

local function shorten_text(text, max_len)
	text = tostring(text or "")
	max_len = max_len or 96
	if #text <= max_len then
		return text
	end

	return text:sub(1, max_len - 3) .. "..."
end

function CanTeleportOut:Init()
	self.menu = Menu.Create("Info Screen", "Main", "Heroes Overlay")
	self.menu_main = self.menu:Create("Main")
	self.menu_script = self.menu_main:Create("Show Me TP")

	self.enable = self.menu_script:Switch("Enable", true, "\u{f0d1}")
	self.show_allies = self.menu_script:Switch("Allies", true, "\u{f4d8}")
	self.show_enemies = self.menu_script:Switch("Enemies", true, "\u{f6e2}")
	self.show_details = self.menu_script:Switch("Show Details", false, "\u{f05a}")

	self.customization = self.menu_script:Label("Customize", "\u{f84c}")
	self.customization_gear = self.customization:Gear("Settings")

	self.channel_time = self.customization_gear:Slider("Teleport Channel", 2, 6, TP_CHANNEL_TIME, "%.1fs")
	self.interrupt_radius = self.customization_gear:Slider("Interrupt Radius", 600, 2200, DEFAULT_INTERRUPT_RADIUS, "%du")
	self.damage_radius = self.customization_gear:Slider("Damage Radius", 600, 2200, DEFAULT_DAMAGE_RADIUS, "%du")
	self.include_spell_damage = self.customization_gear:Switch("Estimate Spell Damage", true)
	self.include_creep_damage = self.customization_gear:Switch("Include Creeps/Summons", true)

	self.enable:SetCallback(function(widget)
		local enabled = widget:Get()
		self.show_allies:Disabled(not enabled)
		self.show_enemies:Disabled(not enabled)
		self.show_details:Disabled(not enabled)
		self.customization:Disabled(not enabled)
	end, true)

	self.next_update = 0
	self.states = {}
end

function CanTeleportOut:Evaluate(hero)
	local window = get_channel_time()
	local scan_radius = math.max(widget_value(self.interrupt_radius, DEFAULT_INTERRUPT_RADIUS), widget_value(self.damage_radius, DEFAULT_DAMAGE_RADIUS))
	local reasons = {}
	local incoming = 0
	local interrupt = false
	local health_after_regen = get_health_after_regen(hero, window)

	local can_tp, tp_reason = tp_is_castable(hero)
	if not can_tp then
		return {
			status = "NO TP",
			label = "NO TP",
			detail = tp_reason,
			color = DANGER_COLOR,
			incoming = 0,
			health = health_after_regen,
			interrupt = false,
		}
	end

	local enemies = nearby_enemies(hero, scan_radius + 600)
	for i = 1, #enemies do
		local enemy = enemies[i]
		if is_valid_enemy(enemy) then
			if scan_interrupts(hero, enemy, window, reasons) then
				interrupt = true
			end

			local attack_damage, attack_count = incoming_attack_damage(hero, enemy, window)
			if attack_damage > 0 then
				incoming = incoming + attack_damage
				if attack_count > 0 then
					append_reason(reasons, ("%s %dx attacks"):format(hero_short_name(enemy), attack_count))
				end
			end

			if widget_value(self.include_spell_damage, true) then
				local spell_damage = incoming_spell_damage(hero, enemy, window)
				if spell_damage > 0 then
					incoming = incoming + spell_damage
					append_reason(reasons, ("%s spells %.0f"):format(hero_short_name(enemy), spell_damage))
				end
			end
		end
	end

	if widget_value(self.include_creep_damage, true) then
		local units = nearby_enemy_units(hero, widget_value(self.damage_radius, DEFAULT_DAMAGE_RADIUS))
		local hero_indices = {}
		for i = 1, #enemies do
			local index = tonumber(call(Entity and Entity.GetIndex, enemies[i]) or 0) or 0
			hero_indices[index] = true
		end

		for i = 1, #units do
			local unit = units[i]
			local index = tonumber(call(Entity and Entity.GetIndex, unit) or 0) or 0
			if not hero_indices[index] and is_valid_enemy(unit) and call(NPC and NPC.IsWard, unit) ~= true and call(NPC and NPC.IsStructure, unit) ~= true then
				local damage = incoming_attack_damage(hero, unit, window)
				if damage > 0 then
					incoming = incoming + damage
				end
			end
		end
	end

	local margin = health_after_regen - incoming
	local status
	local color

	if interrupt and margin <= 0 then
		status = "DIE + CANCEL"
		color = DANGER_COLOR
	elseif interrupt then
		status = "CANCEL"
		color = DANGER_COLOR
	elseif margin <= 0 then
		status = "DIE"
		color = DANGER_COLOR
	elseif margin <= math.max(125, health_after_regen * 0.18) then
		status = "RISKY"
		color = WARN_COLOR
	else
		status = "SAFE TP"
		color = SAFE_COLOR
	end

	local detail = ("hp %.0f / dmg %.0f"):format(health_after_regen, incoming)
	if #reasons > 0 then
		detail = detail .. " | " .. table.concat(reasons, ", ")
	end
	detail = shorten_text(detail, 112)

	local label = status
	if status == "SAFE TP" then
		label = "TP SAFE"
	elseif status == "DIE + CANCEL" then
		label = "TP DANGER"
	elseif status == "CANCEL" then
		label = "TP CANCEL"
	elseif status == "DIE" then
		label = "TP DIE"
	elseif status == "RISKY" then
		label = "TP RISKY"
	end

	return {
		status = status,
		label = label,
		detail = detail,
		color = color,
		incoming = incoming,
		health = health_after_regen,
		interrupt = interrupt,
	}
end

local function should_track_hero(self, local_hero, hero)
	if not hero or not is_alive_unit(hero) then
		return false
	end
	if call(NPC and NPC.IsVisible, hero) == false then
		return false
	end
	if call(NPC and NPC.IsIllusion, hero) == true then
		return false
	end
	if call(NPC and NPC.IsTempestDouble, hero) == true then
		return false
	end
	if XHelpers and XHelpers.XNPC then
		if call(function(unit) return XHelpers.XNPC:IsCommandAuraIllusion(unit) end, hero) == true then
			return false
		end
		if call(function(unit) return XHelpers.XNPC:IsMonkeyClone(unit) end, hero) == true then
			return false
		end
		if call(function(unit) return XHelpers.XNPC:IsSpiritBear(unit) end, hero) == true then
			return false
		end
	end

	if local_hero and call(Entity and Entity.IsSameTeam, local_hero, hero) == true then
		return widget_value(self.show_allies, true)
	end

	return widget_value(self.show_enemies, true)
end

function CanTeleportOut:OnUpdate()
	if not widget_value(self.enable, true) then
		return
	end

	local now = current_time()
	if now < (self.next_update or 0) then
		return
	end
	self.next_update = now + UPDATE_INTERVAL

	local local_hero = call(Heroes and Heroes.GetLocal)
	if not local_hero or not is_alive_unit(local_hero) then
		self.states = {}
		return
	end

	local next_states = {}
	local heroes = call(Heroes and Heroes.GetAll) or {}
	for _, hero in pairs(heroes) do
		if should_track_hero(self, local_hero, hero) then
			next_states[hero] = self:Evaluate(hero)
		end
	end

	self.states = next_states
end

local function draw_text_shadow(font, size, text, pos, color)
	Render.Text(font, size, text, pos + Vec2(1, 1), SHADOW_COLOR)
	Render.Text(font, size, text, pos, color)
end

function CanTeleportOut:OnDraw()
	if not widget_value(self.enable, true) then
		return
	end

	local bars_overlay = Menu.Find("Info Screen", "Main", "Heroes Overlay", "Main", "Bars Overlay", "Enable")
	local draw_mana_bar_widget = Menu.Find("Info Screen", "Main", "Heroes Overlay", "Main", "Bars Overlay", "Draw Mana")
	local draw_mana_bar = bars_overlay ~= nil and draw_mana_bar_widget ~= nil and bars_overlay:Get() and draw_mana_bar_widget:Get()
	local screen_size = Render.ScreenSize()
	local width = 134 * (screen_size.x / 2560)
	local height_px = 15 * (screen_size.y / 1080)
	local y_offset = -34 * (screen_size.y / 1440)
	if draw_mana_bar then
		y_offset = y_offset - (6.5 * (screen_size.y / 1440))
	end

	for hero, state in pairs(self.states or {}) do
		if is_alive_unit(hero) and state then
			local origin = call(Entity and Entity.GetAbsOrigin, hero)
			local hbo = tonumber(call(NPC and NPC.GetHealthBarOffset, hero) or 170) or 170
			local xy, visible = nil, false
			if origin then
				xy, visible = Render.WorldToScreen(origin + Vector(0, 0, hbo))
			end

			if visible then
				xy.x = xy.x - width * 0.5
				xy.y = xy.y + y_offset

				local start = xy
				local finish = xy + Vec2(width, height_px)
				local color = state.color or WARN_COLOR
				local label = state.label or state.status or "TP"
				local font_size = 11
				local text_size = Render.TextSize(FONT, font_size, label)
				local text_pos = Vec2(start.x + width * 0.5 - text_size.x * 0.5, start.y + (height_px - text_size.y) * 0.5 - 1)

				Render.FilledRect(start, finish, PANEL_BG, 3)
				Render.Rect(start, finish, PANEL_BORDER, 3, Enum.DrawFlags.None, 1)
				Render.FilledRect(start, Vec2(start.x + 4, finish.y), color, 2)
				draw_text_shadow(FONT, font_size, label, text_pos, color)

				if widget_value(self.show_details, false) and state.detail and state.detail ~= "" then
					local detail = shorten_text(state.detail, 64)
					local detail_size = 10
					local detail_text_size = Render.TextSize(FONT, detail_size, detail)
					local detail_pos = Vec2(start.x + width * 0.5 - detail_text_size.x * 0.5, start.y - 12 * (screen_size.y / 1080))
					draw_text_shadow(FONT, detail_size, detail, detail_pos, TEXT_COLOR)
				end
			end
		end
	end
end

return (XHelpers and (XHelpers.WrapCallbacks or XHelpers.BaseScript) or function(script) return script end)(CanTeleportOut)
