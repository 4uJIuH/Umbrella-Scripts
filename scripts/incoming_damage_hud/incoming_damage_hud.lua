local Render   <const> = Render
local Renderer <const> = Renderer
local NPC      <const> = NPC
local Ability  <const> = Ability
local Entity   <const> = Entity
local Heroes   <const> = Heroes
local Hero     <const> = Hero
local NPCs     <const> = NPCs
local Modifier <const> = Modifier
local Color    <const> = Color
local Vec2     <const> = Vec2
local Vector   <const> = Vector
local ConVar   <const> = ConVar

local floor    <const> = math.floor
local max      <const> = math.max
local min      <const> = math.min
local abs      <const> = math.abs
local huge     <const> = math.huge
local sort     <const> = table.sort
local ipairs   <const> = ipairs
local pcall    <const> = pcall
local type     <const> = type
local tostring <const> = tostring
local sformat  <const> = string.format
local sfind    <const> = string.find
local concat   <const> = table.concat

local function safe(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if ok then return a, b, c end
    return nil
end

local function clamp(v, lo, hi)
    if v < lo then return lo elseif v > hi then return hi else return v end
end

local function logErr(msg)
    if type(print) == "function" then pcall(print, msg)
    elseif type(log) == "function" then pcall(log, msg)
    elseif Log and Log.Write then pcall(Log.Write, msg) end
end

local function round(n) return floor(n + 0.5) end
local function fmt(n)   return tostring(round(n)) end

local E = (Enum and Enum.DamageTypes) or {}
local DMG = {
    PHYSICAL   = E.DAMAGE_TYPE_PHYSICAL   or 1,
    MAGICAL    = E.DAMAGE_TYPE_MAGICAL    or 2,
    PURE       = E.DAMAGE_TYPE_PURE       or 4,
    HP_REMOVAL = E.DAMAGE_TYPE_HP_REMOVAL or 8,
}

local MF = (Enum and Enum.ModifierFunction) or {}
local PROP = {
    inc_all     = MF.MODIFIER_PROPERTY_INCOMING_DAMAGE_PERCENTAGE          or 62,
    inc_pp      = MF.MODIFIER_PROPERTY_INCOMING_PHYSICAL_DAMAGE_PERCENTAGE or 63,
    inc_pf      = MF.MODIFIER_PROPERTY_INCOMING_PHYSICAL_DAMAGE_CONSTANT   or 64,
    inc_sf      = MF.MODIFIER_PROPERTY_INCOMING_SPELL_DAMAGE_CONSTANT      or 65,
    out_total   = MF.MODIFIER_PROPERTY_TOTALDAMAGEOUTGOING_PERCENTAGE      or 46,
    spell_amp   = MF.MODIFIER_PROPERTY_SPELL_AMPLIFY_PERCENTAGE            or 47,
    spell_amp_u = MF.MODIFIER_PROPERTY_SPELL_AMPLIFY_PERCENTAGE_UNIQUE     or 48,
    out_bonus   = MF.MODIFIER_PROPERTY_BONUSDAMAGEOUTGOING_PERCENTAGE      or 42,
    out_pct     = MF.MODIFIER_PROPERTY_DAMAGEOUTGOING_PERCENTAGE           or 43,
    evasion     = MF.MODIFIER_PROPERTY_EVASION_CONSTANT                    or 66,
    miss        = MF.MODIFIER_PROPERTY_MISS_PERCENTAGE                     or 73,
}
local MS = (Enum and Enum.ModifierState) or {}
local STATE_MAGIC_IMMUNE = MS.MODIFIER_STATE_MAGIC_IMMUNE or 9

local function getSpecial(ab, key)
    local v = safe(Ability.GetSpecialValueFor, ab, key)
    if type(v) == "number" then return v end
    local lvl = safe(Ability.GetLevel, ab)
    if lvl and lvl > 0 then
        v = safe(Ability.GetLevelSpecialValueFor, ab, key, lvl)
        if type(v) == "number" then return v end
    end
    v = safe(Ability.GetLevelSpecialValueFor, ab, key)
    if type(v) == "number" then return v end
    return nil
end

local function levelVal(ab, key, lvl)
    local v = safe(Ability.GetLevelSpecialValueFor, ab, key, lvl)
    if type(v) == "number" then return v end
    return nil
end

local DAMAGE_KEYS = {
    "damage", "ability_damage", "abilitydamage", "spell_damage",
    "magic_damage", "physical_damage", "pure_damage", "total_damage",
    "base_damage", "damage_base",
    "initial_damage", "damage_initial", "final_damage", "magic_damage_base",
    "blast_damage", "blast_damage_base", "blink_damage", "explosion_damage",
    "explode_damage", "detonate_damage", "detonation_damage", "impact_damage",
    "strike_damage", "nova_damage", "bolt_damage", "wave_damage", "laser_damage",
    "crush_damage", "slam_damage", "arcane_orb_damage", "arcane_damage",
    "finger_damage", "secondary_damage", "primary_damage", "main_damage",
    "burst_damage", "damage_per_dagger", "fire_damage", "burn_damage",
    "frost_damage", "shock_damage", "static_damage", "spike_damage",
    "stun_damage", "land_damage", "landing_damage", "edge_damage",
    "center_damage", "splash_damage", "aoe_damage", "target_damage",
    "per_target_damage", "hit_damage", "instance_damage", "channel_damage",
    "end_damage", "torrent_damage", "soul_damage",
    "damage_tick", "tick_damage", "dot_damage", "damage_per_second",
    "magic_damage_per_second", "damage_per_tick", "damage_per_stack",
    "stack_damage", "damage_per_charge", "ground_damage",
    "beam_damage", "spirit_damage", "shadowraze_damage", "raze_damage",
    "echo_slash_damage", "slash_damage", "echo_damage", "lightning_damage",
    "chain_damage", "bounce_damage", "ray_damage", "pulse_damage", "blade_damage",
    "claw_damage", "swipe_damage", "smash_damage", "quake_damage", "ember_damage",
    "flame_damage", "scorch_damage", "venom_damage", "poison_damage", "acid_damage",
    "necro_damage", "death_damage", "shadow_damage", "void_damage", "rift_damage",
    "lance_damage", "spear_damage", "contact_damage", "frostbite_damage", "cold_damage",
}

local DIAG_KEYS = {
    "wex_damage", "exort_damage", "quas_damage", "wex_damage_per_level",
    "contact_damage", "number_of_contacts", "burn_damage", "burn_damage_per_second",
    "travel_distance", "mana_burned", "emp_mana_burned", "damage_per_mana_pct",
    "mana_burn_percent", "snap_damage", "cold_damage", "frostbite_damage",
    "duration", "channel_duration", "radius", "bonus_damage", "lift_damage",
    "end_damage", "tick_interval", "tick_count", "bonus_attack_damage",
    "burn_damage_per_second", "burn_duration", "burn_dps", "contact_interval",
    "blast_radius", "secondary_damage", "explosion_radius", "aoe_damage",
    "damage_per_mana", "mana_void_damage_per_mana", "damage_per_agi", "agi_damage",
    "agility_damage", "damage_per_str", "str_damage", "damage_per_int", "int_damage",
    "blast_agility_multiplier", "blast_primary_attribute_multiplier", "bonus_agility_damage",
    "damage_per_health", "max_health_damage_pct", "current_health_damage_pct",
    "value", "crit_multiplier", "crit_chance", "crit_bonus", "bonus_chance_damage",
    "proc_damage", "lightning_damage", "chain_damage", "bounce_damage", "splinter_damage",
    "damage_min", "damage_max", "min_damage", "max_damage", "self_damage",
    "health_drain", "hp_drain", "mana_drain_damage", "bonus_magical_damage",
    "bonus_physical_damage", "bonus_pure_damage", "agility_multiplier", "strength_multiplier",
    "intellect_multiplier", "primary_attribute_multiplier", "primary_attribute_percent",
    "damage_per_level", "scepter_damage", "shard_damage", "scepter_bonus_damage",
    "empowered_damage", "amplify_damage", "extra_damage", "lance_damage", "spear_damage",
    "beam_damage", "ray_damage", "pulse_damage", "blade_damage", "claw_damage",
    "swipe_damage", "smash_damage", "quake_damage", "spirit_damage", "ember_damage",
    "flame_damage", "scorch_damage", "venom_damage", "poison_damage", "acid_damage",
    "necro_damage", "death_damage", "shadow_damage", "void_damage", "rift_damage",
    "damage_increase", "damage_bonus_pct", "magic_resistance_reduction", "armor_reduction",
    "shadowraze_damage", "stack_bonus_damage", "damage_per_soul", "rotating_glaives_collision_damage",
    "attack_factor", "attack_factor_tooltip",
}

local PERSEC_KEYS = {
    damage_per_second = true, magic_damage_per_second = true, dot_damage = true,
    tick_damage = true, damage_tick = true, damage_per_tick = true,
}
local SPELL_DMG = {
    abaddon_death_coil = {t=2,avg=false,"damage_percentage_on_perform_attack"},
    abyssal_underling_warrior_mana_burn = {t=1,avg=false,"burn_damage_conversion"},
    abyssal_underlord_abyssal_horde = {t=2,avg=false,"warrior_damage","archer_damage"},
    abyssal_underlord_atrophy_aura = {t=1,avg=false,"bonus_damage_from_creep","bonus_damage_from_hero"},
    abyssal_underlord_firestorm = {t=2,avg=false,"wave_damage","burn_damage"},
    abyssal_underlord_pit_of_malice = {t=2,avg=false,"pit_damage"},
    alchemist_acid_spray = {t=1,avg=false,"damage"},
    alchemist_unstable_concoction = {t=1,avg=true,"min_damage","max_damage"},
    alchemist_unstable_concoction_throw = {t=2,avg=true,"min_damage","max_damage"},
    ancient_apparition_chilling_touch = {t=2,avg=false,"damage"},
    ancient_apparition_cold_feet = {t=2,avg=false,"damage_per_second"},
    ancient_apparition_death_rime = {t=2,avg=false,"damage"},
    ancient_apparition_ice_age = {t=2,avg=false,"damage"},
    ancient_apparition_ice_blast = {t=2,avg=false,"damage_per_second"},
    ancient_apparition_ice_vortex = {t=2,avg=false,"damage_per_second"},
    antimage_counterspell = {t=2,avg=false,"incoming_damage"},
    antimage_mana_break = {t=1,avg=false,"percent_damage_per_burn"},
    antimage_mana_overload = {t=2,avg=false,"incoming_damage"},
    antimage_mana_void = {t=2,avg=false,"bonus_attack_damage"},
    arc_warden_flux = {t=2,avg=false,"damage_per_second"},
    arc_warden_spark_wraith = {t=2,avg=false,"spark_damage_base"},
    axe_battle_hunger = {t=4,avg=false,"damage_per_second"},
    axe_counter_helix = {t=4,avg=false,"damage"},
    axe_culling_blade = {t=4,avg=false,"damage"},
    bane_brain_sap = {t=4,avg=false,"brain_sap_damage"},
    bane_enfeeble = {t=4,avg=false,"enfeeble_tick_damage","damage_tick_rate"},
    bane_fiends_grip = {t=4,avg=false,"fiend_grip_damage"},
    bane_ichor_of_nyctasha = {t=4,avg=false,"damage_tick_rate","damage_per_terror"},
    batrider_firefly = {t=2,avg=false,"damage_per_second"},
    batrider_flamebreak = {t=2,avg=false,"damage_impact","damage_per_second"},
    batrider_flaming_lasso = {t=2,avg=false,"damage"},
    batrider_sticky_napalm = {t=2,avg=false,"damage","application_damage"},
    beastmaster_drums_of_slom = {t=2,avg=false,"base_damage"},
    beastmaster_primal_roar = {t=2,avg=false,"damage","side_damage"},
    beastmaster_summon_raptor = {t=2,avg=false,"dive_damage"},
    beastmaster_summon_razorback = {t=1,avg=false,"boar_base_damage","boar_bonus_damage"},
    beastmaster_wild_axes = {t=2,avg=false,"axe_damage","damage_amp"},
    black_dragon_fireball = {t=2,avg=false,"damage"},
    black_dragon_splash_attack = {t=2,avg=false,"damage_percent"},
    bloodseeker_blood_bath = {t=4,avg=false,"damage"},
    bloodseeker_bloodrage = {t=4,avg=false,"base_damage_amp"},
    bloodseeker_rupture = {t=4,avg=false,"damage_cap_amount"},
    bounty_hunter_jinada = {t=1,avg=false,"bonus_damage"},
    bounty_hunter_shuriken_toss = {t=2,avg=false,"bonus_damage","passthrough_damage"},
    bounty_hunter_track = {t=2,avg=false,"target_damage_amp"},
    brewmaster_cinder_brew = {t=2,avg=false,"total_ignite_damage","barrel_impact_damage"},
    brewmaster_earth_hurl_boulder = {t=2,avg=false,"damage"},
    brewmaster_fire_permanent_immolation = {t=2,avg=false,"damage"},
    brewmaster_fire_pull = {t=2,avg=false,"damage"},
    brewmaster_primal_split = {t=2,avg=false,"bonus_damage"},
    brewmaster_storm_cyclone = {t=2,avg=false,"landing_damage"},
    brewmaster_storm_dispel_magic = {t=2,avg=false,"damage"},
    brewmaster_storm_wind_walk = {t=2,avg=false,"bonus_damage"},
    brewmaster_thunder_clap = {t=2,avg=false,"damage"},
    bristleback_quill_spray = {t=1,avg=false,"quill_base_damage","quill_stack_damage","max_damage"},
    broodmother_incapacitating_bite = {t=2,avg=false,"attack_damage"},
    broodmother_insatiable_hunger = {t=1,avg=false,"bonus_damage","shard_damage_per_tick"},
    broodmother_silken_bola = {t=2,avg=false,"impact_damage","attack_damage"},
    broodmother_spawn_spiderlings = {t=2,avg=false,"damage","damage_bonus"},
    broodmother_sticky_snare = {t=2,avg=false,"damage_per_second"},
    centaur_double_edge = {t=2,avg=false,"edge_damage","strength_damage"},
    centaur_hoof_stomp = {t=2,avg=false,"stomp_damage"},
    centaur_stampede = {t=2,avg=false,"base_damage","strength_damage"},
    chaos_knight_chaos_bolt = {t=2,avg=true,"damage_min","damage_max"},
    chen_holy_persuasion = {t=2,avg=false,"damage_bonus"},
    chen_penitence = {t=4,avg=false,"damage"},
    chen_test_of_faith = {t=4,avg=true,"damage_min","damage_max"},
    clinkz_bone_and_arrow = {t=2,avg=false,"damage_percent"},
    clinkz_searing_arrows = {t=1,avg=false,"damage_bonus"},
    clinkz_tar_bomb = {t=1,avg=false,"damage_bonus","impact_damage"},
    clinkz_wind_walk = {t=2,avg=false,"damage_percent"},
    cny2015_black_hole = {t=2,avg=false,"far_damage","near_damage"},
    cny2015_sonic_wave = {t=4,avg=false,"damage"},
    creep_irresolute = {t=2,avg=false,"hero_damage_penalty"},
    creep_piercing = {t=2,avg=false,"creep_damage_bonus","hero_damage_penalty","heavy_damage_penalty"},
    creep_siege = {t=2,avg=false,"incoming_hero_damage_penalty","incoming_basic_damage_penalty"},
    crystal_maiden_crystal_nova = {t=2,avg=false,"nova_damage"},
    crystal_maiden_freezing_field = {t=2,avg=false,"damage"},
    crystal_maiden_frostbite = {t=2,avg=false,"damage_per_second"},
    dark_seer_ion_shell = {t=2,avg=false,"damage_per_second"},
    dark_seer_normal_punch = {t=2,avg=false,"max_damage"},
    dark_seer_vacuum = {t=2,avg=false,"damage"},
    dark_seer_wall_of_replica = {t=2,avg=false,"replica_damage_incoming","wall_damage"},
    dark_troll_warlord_raise_dead = {t=2,avg=false,"skeletons_damage"},
    dark_willow_bramble_maze = {t=2,avg=false,"damage_per_tick"},
    dark_willow_shadow_realm = {t=2,avg=false,"damage"},
    dawnbreaker_celestial_hammer = {t=2,avg=false,"hammer_damage","burn_damage"},
    dawnbreaker_fire_wreath = {t=1,avg=false,"swipe_damage","smash_damage"},
    dazzle_poison_touch = {t=1,avg=false,"damage","bonus_damage","split_damage"},
    dazzle_rain_of_vermin = {t=1,avg=false,"damage"},
    death_prophet_carrion_swarm = {t=2,avg=false,"damage"},
    death_prophet_exorcism = {t=1,avg=true,"min_damage","max_damage","average_damage"},
    death_prophet_silence = {t=2,avg=false,"damage_per_second"},
    death_prophet_spirit_siphon = {t=2,avg=false,"damage"},
    disruptor_electromagnetic_repulsion = {t=2,avg=false,"damage_per_int"},
    disruptor_glimpse = {t=2,avg=true,"min_damage","max_damage"},
    disruptor_kinetic_fence = {t=2,avg=false,"damage_per_second"},
    disruptor_kinetic_field = {t=2,avg=false,"damage_per_second"},
    disruptor_static_storm = {t=2,avg=false,"damage_max"},
    disruptor_thunder_strike = {t=2,avg=false,"strike_damage","strike_damage_bonus"},
    doom_bringer_doom = {t=4,avg=false,"damage"},
    doom_bringer_infernal_blade = {t=2,avg=false,"burn_damage"},
    doom_bringer_scorched_earth = {t=2,avg=false,"damage_per_second"},
    dragon_knight_breathe_fire = {t=2,avg=false,"damage"},
    dragon_knight_dragon_tail = {t=2,avg=false,"damage"},
    dragon_knight_elder_dragon_form = {t=2,avg=false,"bonus_attack_damage","corrosive_damage_per_second"},
    dragon_knight_fireball = {t=2,avg=false,"damage"},
    dragon_knight_wyrms_wrath = {t=2,avg=false,"magic_damage"},
    drow_ranger_frost_arrows = {t=1,avg=false,"damage"},
    drow_ranger_glacier = {t=2,avg=false,"damage_bonus"},
    drow_ranger_marksmanship = {t=1,avg=false,"bonus_damage"},
    earth_spirit_boulder_smash = {t=2,avg=false,"rock_damage"},
    earth_spirit_magnetize = {t=2,avg=false,"damage_per_second"},
    earth_spirit_petrify = {t=2,avg=false,"damage"},
    earth_spirit_rolling_boulder = {t=2,avg=false,"damage","damage_str"},
    earth_spirit_stone_caller = {t=2,avg=false,"attack_damage_per_stone","attack_damage_per_stone_used"},
    earthshaker_aftershock = {t=2,avg=false,"aftershock_damage"},
    earthshaker_echo_slam = {t=2,avg=false,"echo_slam_echo_damage","echo_slam_initial_damage"},
    earthshaker_enchant_totem = {t=2,avg=false,"totem_damage_percentage"},
    earthshaker_fissure = {t=2,avg=false,"fissure_damage","echoes_damage_multiplier"},
    earthshaker_slugger = {t=2,avg=false,"projectile_body_damage_creep","projectile_body_damage_hero"},
    elder_titan_ancestral_spirit = {t=2,avg=false,"pass_damage","damage_creeps","damage_heroes"},
    elder_titan_echo_stomp = {t=1,avg=false,"stomp_damage","wake_damage_limit"},
    elder_titan_echo_stomp_spirit = {t=2,avg=false,"stomp_damage","wake_damage_limit"},
    elder_titan_tip_the_scales = {t=2,avg=false,"damage_bonus"},
    ember_spirit_activate_fire_remnant = {t=2,avg=false,"damage"},
    ember_spirit_fire_remnant = {t=2,avg=false,"damage"},
    ember_spirit_flame_guard = {t=2,avg=false,"damage_per_second"},
    ember_spirit_immolation = {t=2,avg=false,"damage"},
    ember_spirit_searing_chains = {t=2,avg=false,"damage_per_second"},
    ember_spirit_sleight_of_fist = {t=1,avg=false,"bonus_hero_damage","creep_damage_penalty","second_attack_damage_penalty"},
    enchantress_enchant = {t=2,avg=false,"enchant_damage","bonus_damage"},
    enigma_black_hole = {t=4,avg=false,"damage"},
    enigma_demonic_conversion = {t=1,avg=false,"eidelon_base_damage","eidolon_damage_spread","eidolon_bonus_damage"},
    enigma_malefice = {t=2,avg=false,"damage"},
    enigma_midnight_pulse = {t=2,avg=false,"base_damage","damage_percent"},
    faceless_void_time_dilation = {t=2,avg=false,"base_damage"},
    faceless_void_time_lock = {t=2,avg=false,"bonus_damage"},
    frogmen_arm_of_the_deep = {t=2,avg=false,"damage"},
    frogmen_congregation_of_the_deep = {t=2,avg=false,"damage"},
    frogmen_tendrils_of_the_deep = {t=2,avg=false,"damage"},
    furion_curse_of_the_forest = {t=2,avg=false,"damage_per_tree"},
    furion_force_of_nature = {t=2,avg=false,"treant_damage","treant_bonus_hero_damage"},
    furion_hedgerow = {t=2,avg=false,"damage_per_tick"},
    furion_sprout = {t=2,avg=false,"sprout_damage"},
    furion_summon_fey = {t=2,avg=false,"attack_damage"},
    furion_wrath_of_nature = {t=2,avg=false,"damage","damage_percent_add","kill_damage"},
    gnoll_assassin_envenomed_weapon = {t=2,avg=false,"damage_per_second"},
    granite_golem_bash = {t=2,avg=false,"bonus_damage"},
    greevil_black_hole = {t=2,avg=false,"customval_far_damage","customval_near_damage"},
    greevil_blade_fury = {t=2,avg=false,"blade_fury_damage_tick","customval_damage"},
    greevil_cold_snap = {t=2,avg=false,"customval_initial_damage","customval_damage"},
    greevil_diabolic_edict = {t=1,avg=false,"customval_damage"},
    greevil_echo_slam = {t=2,avg=false,"customval_echo_damage","customval_damage"},
    greevil_flesh_golem = {t=2,avg=false,"customval_bonus_damage"},
    greevil_hook = {t=4,avg=false,"customval_damage"},
    greevil_ice_wall = {t=2,avg=false,"customval_damage_per_second"},
    greevil_laguna_blade = {t=2,avg=false,"customval_damage"},
    greevil_leech_seed = {t=2,avg=false,"customval_leech_damage"},
    greevil_magic_missile = {t=2,avg=false,"customval_damage"},
    greevil_maledict = {t=2,avg=false,"customval_bonus_damage"},
    greevil_miniboss_blue_cold_feet = {t=2,avg=false,"damage"},
    greevil_miniboss_purple_venomous_gale = {t=2,avg=false,"strike_damage","tick_damage"},
    greevil_miniboss_yellow_ion_shell = {t=2,avg=false,"damage_per_second"},
    greevil_poison_nova = {t=2,avg=false,"customval_damage"},
    greevil_rot = {t=2,avg=false,"customval_damage"},
    greevil_shadow_strike = {t=2,avg=false,"customval_strike_damage"},
    greevil_time_lock = {t=2,avg=false,"customval_bonus_damage"},
    grimstroke_dark_artistry = {t=2,avg=false,"damage","bonus_damage_per_hero","bonus_damage_per_creep"},
    grimstroke_dark_portrait = {t=2,avg=false,"images_do_damage_percent","images_take_damage_percent"},
    grimstroke_ink_creature = {t=2,avg=false,"damage_per_second","pop_damage"},
    grimstroke_ink_over = {t=2,avg=false,"total_damage"},
    gyrocopter_call_down = {t=2,avg=false,"damage","tracking_missile_damage"},
    gyrocopter_homing_missile = {t=2,avg=false,"hit_damage","hero_damage"},
    gyrocopter_rocket_barrage = {t=2,avg=false,"rocket_damage"},
    harpy_storm_chain_lightning = {t=2,avg=false,"initial_damage","damage_percent_loss"},
    hill_troll_rally = {t=2,avg=false,"damage_bonus"},
    hoodwink_acorn_shot = {t=1,avg=false,"acorn_shot_damage"},
    hoodwink_bushwhack = {t=2,avg=false,"total_damage"},
    hoodwink_decoy = {t=2,avg=false,"images_do_damage_percent","images_take_damage_percent"},
    hoodwink_hunters_boomerang = {t=2,avg=false,"damage"},
    hoodwink_sharpshooter = {t=2,avg=false,"max_damage"},
    huskar_burning_spear = {t=2,avg=false,"burn_damage"},
    huskar_inner_fire = {t=2,avg=false,"damage"},
    ice_shaman_incendiary_bomb = {t=2,avg=false,"burn_damage"},
    invoker_chaos_meteor = {t=2,avg=false,"main_damage"},
    invoker_chaos_meteor_ad = {t=2,avg=false,"main_damage"},
    invoker_cold_snap = {t=2,avg=false,"freeze_damage"},
    invoker_cold_snap_ad = {t=2,avg=false,"freeze_damage"},
    invoker_deafening_blast = {t=2,avg=false,"damage"},
    invoker_deafening_blast_ad = {t=2,avg=false,"damage"},
    invoker_forge_spirit = {t=2,avg=false,"spirit_damage"},
    invoker_forge_spirit_ad = {t=2,avg=false,"spirit_damage"},
    invoker_ice_wall = {t=2,avg=false,"damage_per_second","root_damage"},
    invoker_ice_wall_ad = {t=2,avg=false,"damage_per_second"},
    invoker_sun_strike = {t=4,avg=false,"damage","create_forged_spirit_on_hero_damage"},
    invoker_sun_strike_ad = {t=4,avg=false,"damage"},
    invoker_tornado = {t=2,avg=false,"base_damage","quas_damage","wex_damage","twister_damage"},
    invoker_tornado_ad = {t=2,avg=false,"base_damage","quas_damage","wex_damage"},
    jakiro_dual_breath = {t=2,avg=false,"burn_damage"},
    jakiro_ice_path = {t=2,avg=false,"damage","detonate_damage"},
    jakiro_liquid_fire = {t=2,avg=false,"damage"},
    jakiro_liquid_ice = {t=2,avg=false,"damage","bonus_instance_damage_from_other_abilities"},
    jakiro_macropyre = {t=2,avg=false,"damage","pure_damage_type"},
    juggernaut_blade_fury = {t=2,avg=false,"blade_fury_damage","blade_fury_damage_tick"},
    juggernaut_duelist = {t=2,avg=false,"front_damage_increase"},
    juggernaut_omni_slash = {t=1,avg=false,"bonus_damage"},
    keeper_of_the_light_blinding_light = {t=2,avg=false,"damage"},
    keeper_of_the_light_illuminate = {t=2,avg=false,"total_damage"},
    keeper_of_the_light_will_o_wisp = {t=2,avg=false,"wisp_damage"},
    kez_echo_slash = {t=1,avg=false,"katana_echo_damage","echo_hero_damage"},
    kez_falcon_rush = {t=2,avg=false,"base_echo_damage"},
    kez_raptor_dance = {t=4,avg=false,"base_damage"},
    kez_switch_weapons = {t=2,avg=false,"katana_agility_bonus_base_damage","katana_swap_bonus_damage"},
    kez_talon_toss = {t=1,avg=false,"damage"},
    kunkka_tidal_wave = {t=2,avg=false,"damage"},
    kunkka_tidebringer = {t=1,avg=false,"damage_bonus","cleave_damage"},
    kunkka_torrent = {t=2,avg=false,"torrent_damage"},
    largo_catchy_lick = {t=2,avg=false,"damage"},
    largo_frogstomp = {t=2,avg=false,"damage_per_stomp"},
    largo_song_fight_song = {t=2,avg=false,"burst_damage","magic_damage_bonus"},
    legion_commander_duel = {t=2,avg=false,"reward_damage"},
    legion_commander_intimidate = {t=2,avg=false,"damage"},
    legion_commander_moment_of_courage = {t=2,avg=false,"secondary_attack_damage"},
    legion_commander_overwhelming_odds = {t=2,avg=false,"damage","damage_per_hero","damage_per_unit"},
    leshrac_diabolic_edict = {t=4,avg=false,"damage"},
    leshrac_lightning_storm = {t=2,avg=false,"damage"},
    leshrac_pulse_nova = {t=2,avg=false,"damage"},
    lich_chain_frost = {t=2,avg=false,"damage","bonus_jump_damage"},
    lich_frost_nova = {t=2,avg=false,"damage","aoe_damage"},
    lich_sinister_gaze = {t=2,avg=false,"damage"},
    life_stealer_feast = {t=1,avg=false,"hp_damage_percent"},
    life_stealer_infest = {t=2,avg=false,"damage"},
    lina_combustion = {t=2,avg=false,"damage","damage_aoe"},
    lina_dragon_slave = {t=2,avg=false,"dragon_slave_damage"},
    lina_laguna_blade = {t=2,avg=false,"damage"},
    lina_light_strike_array = {t=2,avg=false,"light_strike_array_damage"},
    lion_finger_of_death = {t=2,avg=false,"damage","damage_per_kill","punch_bonus_damage_base","cleave_damage"},
    lion_impale = {t=2,avg=false,"damage"},
    lion_to_hell_and_back = {t=2,avg=false,"damage_window"},
    lone_druid_entangle = {t=2,avg=false,"damage"},
    lone_druid_spirit_bear = {t=2,avg=false,"backlash_damage","damage_gain_per_druid_level"},
    lone_druid_spirit_bear_defender = {t=2,avg=false,"damage_share"},
    lone_druid_spirit_bear_entangle = {t=2,avg=false,"damage"},
    lone_druid_spirit_bear_fetch = {t=2,avg=false,"damage"},
    lone_druid_true_form = {t=2,avg=false,"bonus_attack_damage"},
    lone_druid_true_form_battle_cry = {t=2,avg=false,"bonus_damage"},
    luna_lucent_beam = {t=2,avg=false,"beam_damage"},
    luna_lunar_orbit = {t=1,avg=false,"rotating_glaives_collision_damage"},
    lycan_apex_predator = {t=2,avg=false,"damage_amp"},
    lycan_feral_impulse = {t=2,avg=false,"bonus_damage"},
    lycan_summon_wolves = {t=2,avg=false,"wolf_damage","bonus_damage"},
    lycan_summon_wolves_bash = {t=1,avg=false,"bash_damage"},
    lycan_summon_wolves_critical_strike = {t=2,avg=false,"maim_damage"},
    lycan_summon_wolves_hamstring = {t=1,avg=false,"damage_boost","damage_boost_stacks"},
    magnataur_horn_toss = {t=2,avg=false,"damage"},
    magnataur_reverse_polarity = {t=2,avg=false,"polarity_damage"},
    magnataur_shockwave = {t=2,avg=false,"shock_damage"},
    magnataur_skewer = {t=2,avg=false,"skewer_damage","tree_hit_damage","cliff_hit_damage"},
    marci_grapple = {t=2,avg=false,"impact_damage"},
    marci_unleash = {t=2,avg=false,"pulse_damage"},
    mars_arena_of_blood = {t=2,avg=false,"spear_damage"},
    mars_gods_rebuke = {t=1,avg=false,"bonus_damage_vs_heroes"},
    mars_spear = {t=2,avg=false,"damage"},
    medusa_cold_blooded = {t=2,avg=false,"damage"},
    medusa_gorgon_grasp = {t=1,avg=false,"damage","damage_pers"},
    medusa_mystic_snake = {t=2,avg=false,"snake_damage"},
    medusa_split_shot = {t=2,avg=false,"damage_modifier"},
    medusa_stone_gaze = {t=2,avg=false,"bonus_physical_damage"},
    meepo_megameepo = {t=2,avg=false,"poof_damage_factor"},
    meepo_megameepo_fling = {t=2,avg=false,"fling_damage"},
    miniboss_radiance = {t=2,avg=false,"aura_damage","aura_damage_per_upgrade"},
    mirana_arrow = {t=2,avg=false,"arrow_bonus_damage"},
    mirana_starfall = {t=2,avg=false,"damage","secondary_starfall_damage_percent"},
    monkey_king_boundless_strike = {t=1,avg=false,"strike_flat_damage"},
    monkey_king_jingu_mastery = {t=1,avg=false,"bonus_damage"},
    monkey_king_primal_spring = {t=2,avg=false,"impact_damage"},
    morphling_adaptive_strike_agi = {t=2,avg=true,"damage_base","damage_min","damage_max"},
    mud_golem_hurl_boulder = {t=2,avg=false,"damage","damage_creeps"},
    mud_golem_rock_destroy = {t=2,avg=false,"shard_damage"},
    muerta_dead_shot = {t=2,avg=false,"damage"},
    muerta_gunslinger = {t=2,avg=false,"bonus_damage"},
    muerta_parting_shot = {t=2,avg=false,"ethereal_damage_bonus"},
    muerta_pierce_the_veil = {t=2,avg=false,"base_damage_percent"},
    muerta_spectral_slug = {t=2,avg=false,"damage"},
    muerta_the_calling = {t=2,avg=false,"damage"},
    naga_siren_deluge = {t=2,avg=false,"damage"},
    naga_siren_mirror_image = {t=2,avg=false,"incoming_damage"},
    naga_siren_rip_tide = {t=2,avg=false,"damage"},
    necrolyte_ghost_shroud = {t=2,avg=false,"bonus_damage"},
    necrolyte_heartstopper_aura = {t=2,avg=false,"aura_damage"},
    necronomicon_warrior_mana_burn = {t=1,avg=false,"burn_damage_conversion"},
    neutral_upgrade = {t=2,avg=false,"increase_damage"},
    nevermore_shadowraze1 = {t=2,avg=false,"shadowraze_damage","stack_bonus_damage"},
    nevermore_shadowraze2 = {t=2,avg=false,"shadowraze_damage","stack_bonus_damage"},
    nevermore_shadowraze3 = {t=2,avg=false,"shadowraze_damage","stack_bonus_damage"},
    night_stalker_darkness = {t=1,avg=false,"bonus_damage"},
    night_stalker_void = {t=2,avg=false,"damage","invisible_damage_pers","invisible_damage_tickrate"},
    nyx_assassin_impale = {t=2,avg=false,"impale_damage"},
    nyx_assassin_vendetta = {t=4,avg=false,"bonus_damage"},
    obsidian_destroyer_astral_imprisonment = {t=2,avg=false,"damage"},
    obsidian_destroyer_sanity_eclipse = {t=2,avg=false,"base_damage","damage_multiplier","percentage_damage"},
    ogre_bruiser_ogre_smash = {t=2,avg=false,"damage"},
    ogre_magi_fireblast = {t=2,avg=false,"fireblast_damage"},
    ogre_magi_ignite = {t=2,avg=false,"burn_damage"},
    ogre_magi_unrefined_fireblast = {t=2,avg=false,"base_damage"},
    omniknight_hammer_of_purity = {t=4,avg=false,"base_damage","bonus_damage"},
    oracle_fortunes_end = {t=2,avg=false,"damage"},
    oracle_purifying_flames = {t=2,avg=false,"damage","damage_modifier"},
    oracle_rain_of_destiny = {t=2,avg=false,"damage"},
    pangolier_shield_crash = {t=1,avg=false,"damage"},
    pangolier_swashbuckle = {t=1,avg=false,"damage","attack_damage","damage_penalty"},
    phantom_assassin_fan_of_knives = {t=1,avg=false,"max_damage_initial"},
    phantom_assassin_stifling_dagger = {t=1,avg=false,"base_damage"},
    phantom_lancer_spirit_lance = {t=2,avg=false,"lance_damage"},
    phoenix_fire_spirits = {t=2,avg=false,"damage_per_second"},
    phoenix_icarus_dive = {t=2,avg=false,"damage_per_second"},
    phoenix_launch_fire_spirit = {t=2,avg=false,"damage_per_second"},
    phoenix_sun_ray = {t=2,avg=false,"base_damage","hp_perc_damage"},
    primal_beast_onslaught = {t=1,avg=false,"knockback_damage"},
    primal_beast_pulverize = {t=2,avg=false,"damage","bonus_damage_per_hit"},
    primal_beast_rock_throw = {t=1,avg=false,"base_damage"},
    primal_beast_trample = {t=2,avg=false,"base_damage","attack_damage"},
    primal_beast_uproar = {t=2,avg=true,"damage_limit","damage_min","damage_max"},
    puck_dream_coil = {t=2,avg=false,"coil_initial_damage","coil_break_damage"},
    puck_illusory_orb = {t=2,avg=false,"damage"},
    puck_waning_rift = {t=2,avg=false,"damage"},
    pudge_dismember = {t=2,avg=false,"dismember_damage","strength_damage"},
    pudge_meat_hook = {t=4,avg=false,"damage"},
    pudge_rot = {t=2,avg=false,"rot_damage"},
    pugna_nether_blast = {t=2,avg=false,"structure_damage_mod","blast_damage"},
    pugna_nether_ward = {t=2,avg=false,"base_damage"},
    queenofpain_scream_of_pain = {t=2,avg=false,"damage"},
    queenofpain_shadow_strike = {t=2,avg=false,"strike_damage"},
    queenofpain_sonic_wave = {t=4,avg=false,"damage"},
    rattletrap_armor_power = {t=2,avg=false,"damage_per_armor"},
    rattletrap_battery_assault = {t=2,avg=false,"damage","creep_damage_multiplier"},
    rattletrap_hookshot = {t=2,avg=false,"damage"},
    rattletrap_power_cogs = {t=2,avg=false,"damage"},
    rattletrap_rocket_flare = {t=2,avg=false,"damage"},
    razor_dynamo = {t=2,avg=false,"spell_amp_damage_divisor"},
    razor_eye_of_the_storm = {t=1,avg=false,"damage"},
    razor_plasma_field = {t=2,avg=true,"damage_min","damage_max"},
    razor_storm_surge = {t=2,avg=false,"strike_damage"},
    riki_blink_strike = {t=1,avg=false,"bonus_damage"},
    riki_innate_backstab = {t=1,avg=false,"damage_multiplier"},
    riki_poison_dart = {t=2,avg=false,"damage","wake_damage_limit"},
    ringmaster_funhouse_mirror = {t=2,avg=false,"images_do_damage_percent_melee","images_take_damage_percent"},
    ringmaster_impalement = {t=2,avg=false,"damage_impact"},
    ringmaster_summon_unicycle = {t=2,avg=false,"damage_grace_period"},
    ringmaster_tame_the_beasts = {t=2,avg=true,"damage_min","damage_max"},
    ringmaster_wheel = {t=2,avg=false,"aura_damage","explosion_damage","damage_per_second"},
    roshan_bash = {t=2,avg=false,"bonus_damage"},
    roshan_grab_and_throw = {t=4,avg=false,"damage","damage_per_combo"},
    roshan_halloween_angry = {t=2,avg=false,"bonus_damage"},
    roshan_halloween_apocalypse = {t=2,avg=false,"damage"},
    roshan_halloween_burn = {t=2,avg=false,"damage"},
    roshan_halloween_candy = {t=2,avg=false,"bonus_damage"},
    roshan_halloween_fireball = {t=2,avg=false,"damage_percent"},
    roshan_halloween_levels = {t=2,avg=false,"bonus_damage"},
    roshan_halloween_toss = {t=2,avg=false,"toss_damage"},
    roshan_halloween_wave_of_force = {t=2,avg=false,"game_end_damage"},
    roshan_revengeroar = {t=2,avg=false,"damage","damage_growth"},
    roshan_slam = {t=2,avg=false,"damage","damage_growth","damage_bonus_creeps"},
    rubick_curiosity = {t=2,avg=false,"curiosity_attack_damage"},
    rubick_fade_bolt = {t=2,avg=false,"damage","steals_damage"},
    sandking_caustic_finale = {t=2,avg=false,"caustic_finale_damage_flat"},
    sandking_epicenter = {t=2,avg=false,"epicenter_damage"},
    sandking_sand_storm = {t=2,avg=false,"damage_tick_rate","sand_storm_damage"},
    sandking_scorpion_strike = {t=1,avg=false,"attack_damage"},
    satyr_trickster_purge = {t=2,avg=false,"summon_damage"},
    shadow_demon_demonic_purge = {t=2,avg=false,"purge_damage"},
    shadow_demon_shadow_poison = {t=2,avg=false,"stack_damage","bonus_stack_damage","hit_damage"},
    shadow_shaman_ether_shock = {t=2,avg=false,"damage"},
    shadow_shaman_fowl_play = {t=2,avg=false,"ally_chicken_images_take_damage_percent"},
    shadow_shaman_mass_serpent_ward = {t=1,avg=false,"bonus_damage","mega_ward_multiplier_damage"},
    shadow_shaman_shackles = {t=2,avg=false,"total_damage"},
    shadow_shaman_urnaconda = {t=2,avg=false,"impact_damage"},
    shadow_shaman_voodoo = {t=2,avg=false,"damage_amp"},
    shredder_chakram = {t=4,avg=false,"pass_damage","damage_per_second"},
    shredder_chakram_2 = {t=4,avg=false,"pass_damage","damage_per_second","scepter_bonus_damage"},
    shredder_flamethrower = {t=2,avg=false,"damage_per_second"},
    shredder_timber_chain = {t=4,avg=false,"damage"},
    shredder_twisted_chakram = {t=4,avg=false,"damage"},
    shredder_whirling_death = {t=4,avg=false,"whirling_damage","tree_damage_scale"},
    silencer_curse_of_the_silent = {t=2,avg=false,"damage","application_damage"},
    silencer_last_word = {t=2,avg=false,"damage"},
    skeleton_king_hellfire_blast = {t=2,avg=false,"damage","blast_dot_damage"},
    skeleton_king_spectral_blade = {t=4,avg=false,"cursed_damage"},
    skywrath_mage_arcane_bolt = {t=2,avg=false,"bolt_damage"},
    skywrath_mage_concussive_shot = {t=2,avg=false,"damage"},
    skywrath_mage_mystic_flare = {t=2,avg=false,"damage"},
    slardar_bash = {t=1,avg=false,"bonus_damage"},
    slardar_slithereen_crush = {t=1,avg=false,"crush_damage"},
    slark_dark_pact = {t=2,avg=false,"total_damage"},
    slark_pounce = {t=2,avg=false,"pounce_damage"},
    slark_saltwater_shiv = {t=1,avg=false,"agi_bonus_damage_factor"},
    snapfire_boomstick = {t=2,avg=true,"damage_amp_min","damage_amp_max"},
    snapfire_buckshot = {t=2,avg=false,"damage_amp"},
    snapfire_lil_shredder = {t=1,avg=false,"damage"},
    snapfire_mortimer_kisses = {t=2,avg=false,"damage_per_impact","burn_damage"},
    snapfire_scatterblast = {t=2,avg=false,"damage"},
    snapfire_spit_creep = {t=2,avg=false,"burn_damage"},
    sniper_assassinate = {t=2,avg=false,"damage"},
    sniper_concussive_grenade = {t=2,avg=false,"damage"},
    sniper_headshot = {t=1,avg=false,"damage"},
    sniper_keen_scope = {t=2,avg=false,"bonus_damage_distance"},
    sniper_shrapnel = {t=2,avg=false,"shrapnel_damage"},
    spawnlord_master_bash = {t=2,avg=false,"bonus_damage"},
    spawnlord_master_freeze = {t=1,avg=false,"damage"},
    spawnlord_master_stomp = {t=1,avg=false,"damage"},
    spectre_desolate = {t=4,avg=false,"bonus_damage"},
    spectre_spectral_dagger = {t=2,avg=false,"damage"},
    spirit_breaker_greater_bash = {t=2,avg=false,"damage","cascading_bashes_damage_multiplier"},
    spirit_breaker_nether_strike = {t=2,avg=false,"damage"},
    storm_spirit_overload = {t=2,avg=false,"overload_damage"},
    storm_spirit_static_remnant = {t=2,avg=false,"static_remnant_damage"},
    sven_gods_strength = {t=2,avg=false,"gods_strength_damage"},
    sven_great_cleave = {t=2,avg=false,"great_cleave_damage"},
    sven_storm_bolt = {t=2,avg=false,"scepter_bonus_damage"},
    sven_wrath_of_god = {t=2,avg=false,"bonus_damage_per_str"},
    techies_land_mines = {t=2,avg=false,"damage","outer_damage"},
    techies_minefield_sign = {t=2,avg=false,"scepter_move_damage"},
    techies_mutually_assured_destruction = {t=2,avg=false,"base_damage"},
    techies_remote_mines = {t=2,avg=false,"damage"},
    techies_snare_trap = {t=2,avg=false,"damage"},
    techies_sticky_bomb = {t=2,avg=false,"damage"},
    techies_suicide = {t=2,avg=false,"damage"},
    templar_assassin_meld = {t=1,avg=false,"bonus_damage"},
    templar_assassin_psionic_trap = {t=2,avg=false,"trap_bonus_damage","instant_trap_damage","extra_damage","damage_tick_rate"},
    templar_assassin_refraction = {t=1,avg=false,"bonus_damage"},
    templar_assassin_trap_teleport = {t=2,avg=false,"extra_damage"},
    terrorblade_metamorphosis = {t=1,avg=false,"bonus_damage"},
    terrorblade_terror_wave = {t=2,avg=false,"damage"},
    tidehunter_anchor_smash = {t=1,avg=false,"attack_damage"},
    tidehunter_blubber = {t=2,avg=false,"damage_cleanse"},
    tidehunter_gush = {t=2,avg=false,"gush_damage"},
    tidehunter_kraken_shell = {t=2,avg=false,"damage_cleanse"},
    tinker_deploy_turrets = {t=2,avg=false,"drop_damage","missile_damage"},
    tinker_heat_seeking_missile = {t=2,avg=false,"damage"},
    tinker_laser = {t=4,avg=false,"laser_damage"},
    tinker_march_of_the_machines = {t=2,avg=false,"damage"},
    tinker_warp_grenade = {t=2,avg=false,"damage"},
    tiny_avalanche = {t=2,avg=false,"avalanche_damage"},
    tiny_craggy_exterior = {t=2,avg=false,"damage"},
    tiny_grow = {t=1,avg=false,"bonus_damage","toss_bonus_damage"},
    tiny_rocksteady = {t=2,avg=false,"attack_speed_to_damage"},
    tiny_toss = {t=2,avg=false,"toss_damage"},
    tiny_toss_tree = {t=1,avg=false,"bonus_damage"},
    tiny_tree_grab = {t=1,avg=false,"bonus_damage"},
    tornado_tempest = {t=2,avg=false,"near_damage","far_damage"},
    treant_leech_seed = {t=2,avg=false,"leech_damage"},
    treant_natures_grasp = {t=2,avg=false,"damage_per_second"},
    treant_natures_guise = {t=2,avg=false,"shard_damage"},
    treant_overgrowth = {t=2,avg=false,"damage"},
    troll_warlord_berserkers_rage = {t=1,avg=false,"maim_damage"},
    troll_warlord_whirling_axes_melee = {t=2,avg=false,"damage"},
    troll_warlord_whirling_axes_ranged = {t=2,avg=false,"axe_damage"},
    tusk_ice_shards = {t=2,avg=false,"shard_damage"},
    tusk_snowball = {t=2,avg=false,"snowball_damage","snowball_damage_bonus"},
    tusk_tag_team = {t=1,avg=false,"bonus_damage"},
    tusk_walrus_kick = {t=2,avg=false,"damage"},
    tusk_walrus_punch = {t=2,avg=false,"bonus_damage"},
    undying_decay = {t=2,avg=false,"decay_damage","creep_damage_multiplier"},
    undying_flesh_golem = {t=2,avg=false,"damage_amp"},
    undying_soul_rip = {t=2,avg=false,"damage_per_unit"},
    ursa_enrage = {t=2,avg=false,"damage_increase"},
    vengefulspirit_magic_missile = {t=2,avg=false,"magic_missile_damage","damage_per_lasthit"},
    vengefulspirit_nether_swap = {t=2,avg=false,"damage"},
    vengefulspirit_retribution = {t=2,avg=false,"bonus_damage"},
    vengefulspirit_wave_of_terror = {t=2,avg=false,"damage"},
    venomancer_latent_poison = {t=2,avg=false,"explosion_damage"},
    venomancer_noxious_plague = {t=2,avg=false,"impact_damage","damage_per_second","damage_tick_rate","impact_damage_reduce"},
    venomancer_poison_nova = {t=2,avg=false,"damage_base","hp_damage"},
    venomancer_poison_sting = {t=2,avg=false,"damage"},
    venomancer_snakebite = {t=2,avg=false,"base_damage","tick_damage"},
    venomancer_venomous_gale = {t=2,avg=false,"strike_damage","tick_damage","explosion_damage"},
    viper_corrosive_skin = {t=2,avg=false,"damage"},
    viper_nethertoxin = {t=2,avg=true,"min_damage","max_damage"},
    viper_poison_attack = {t=2,avg=false,"damage"},
    viper_predator = {t=1,avg=false,"damage"},
    viper_viper_strike = {t=2,avg=false,"damage"},
    visage_gravekeepers_cloak = {t=2,avg=false,"minimum_damage"},
    visage_silent_as_the_grave = {t=2,avg=false,"bonus_damage"},
    visage_soul_assumption = {t=2,avg=true,"soul_base_damage","soul_charge_damage","damage_limit","damage_min"},
    visage_stone_form_self_cast = {t=2,avg=false,"stun_damage"},
    visage_summon_familiars = {t=1,avg=false,"familiar_attack_damage","visage_base_damage","bonus_damage"},
    visage_summon_familiars_stone_form = {t=2,avg=false,"stun_damage"},
    void_spirit_aether_remnant = {t=2,avg=false,"impact_damage","damage_tick_rate"},
    void_spirit_astral_step = {t=2,avg=false,"pop_damage"},
    void_spirit_resonant_pulse = {t=2,avg=false,"damage"},
    warlock_fatal_bonds = {t=2,avg=false,"damage_share_percentage"},
    warlock_golem_flaming_fists = {t=4,avg=false,"damage"},
    warlock_golem_permanent_immolation = {t=2,avg=false,"aura_damage","share_damage"},
    warlock_shadow_word = {t=2,avg=false,"damage"},
    warlock_upheaval = {t=2,avg=false,"damage_per_second","max_damage"},
    warpine_raider_seed_shot = {t=2,avg=false,"damage"},
    weaver_geminate_attack = {t=1,avg=false,"bonus_damage"},
    weaver_shukuchi = {t=2,avg=false,"damage"},
    weaver_the_swarm = {t=1,avg=false,"damage"},
    weaver_threads_of_fate = {t=2,avg=false,"damage_per_thread_hero","damage_per_thread_creep"},
    windrunner_powershot = {t=2,avg=false,"powershot_damage"},
    winter_wyvern_arctic_burn = {t=2,avg=false,"percent_damage"},
    winter_wyvern_splinter_blast = {t=2,avg=false,"damage"},
    wisp_spirits = {t=2,avg=false,"creep_damage","hero_damage"},
    witch_doctor_death_ward = {t=4,avg=false,"damage"},
    witch_doctor_maledict = {t=2,avg=false,"bonus_damage"},
    witch_doctor_paralyzing_cask = {t=2,avg=false,"base_damage","bounce_bonus_damage"},
    witch_doctor_voodoo_restoration = {t=2,avg=false,"does_damage"},
    zuus_arc_lightning = {t=2,avg=false,"arc_damage"},
    zuus_heavenly_jump = {t=2,avg=false,"damage"},
    zuus_lightning_bolt = {t=2,avg=false,"damage"},
    zuus_thundergods_wrath = {t=2,avg=false,"damage"},
}

local function estimateRaw(ab, abName)
    local e = abName and SPELL_DMG[abName]
    if e then
        if e.avg and e[1] and e[2] then
            local v = ((getSpecial(ab, e[1]) or 0) + (getSpecial(ab, e[2]) or 0)) / 2
            if v > 0 then return v, false end
        end
        local best = 0
        for i = 1, #e do
            local v = getSpecial(ab, e[i])
            if v and v > best then best = v end
        end
        if best > 0 then return best, PERSEC_KEYS[e[1]] == true end
    end
    local d = safe(Ability.GetDamage, ab)
    local best = (d and d > 0) and d or 0
    local perSec = false
    for i = 1, #DAMAGE_KEYS do
        local k = DAMAGE_KEYS[i]
        local v = getSpecial(ab, k)
        if v and v > best then best = v; perSec = PERSEC_KEYS[k] == true end
    end
    return best, perSec
end

local function dotScale(ab, cfg)
    local dur = getSpecial(ab, "duration") or getSpecial(ab, "channel_duration") or cfg.dotWindow
    return cfg.dot and clamp(min(cfg.dotWindow, dur), 1, 30) or 1
end

local ITEM_DENY = {
    item_radiance        = true,
    item_blade_mail      = true,
    item_octarine_core   = true,
    item_veil_of_discord = true,
}

local ITEM_ONHIT = {
    item_maelstrom       = { "chain_lightning_damage", DMG.MAGICAL },
    item_mjollnir        = { "chain_lightning_damage", DMG.MAGICAL },
    item_gleipnir        = { "chain_lightning_damage", DMG.MAGICAL },
    item_monkey_king_bar = { "bonus_chance_damage",    DMG.MAGICAL },
    item_witch_blade     = { "bonus_damage",           DMG.MAGICAL },
    item_revenants_brooch = { "bonus_damage",          DMG.MAGICAL },
}

local ITEM_CHARGES = {
    item_urn_of_shadows    = true,
    item_spirit_vessel     = true,
    item_essence_distiller = true,
}

local ITEM_TYPE_FIX = {
    item_overwhelming_blink = DMG.PHYSICAL,
    item_arcane_blink       = false,
    item_swift_blink        = false,
    item_wind_waker         = false,
}

local ITEM_AMP = {
    item_veil_of_discord = 25,
    item_ethereal_blade  = 40,
    item_orchid          = 30,
    item_bloodthorn      = 40,
}

local function invokerOrb(caster, orb)
    local nm = "invoker_" .. orb
    for i = 0, 31 do
        local ab = safe(NPC.GetAbilityByIndex, caster, i)
        if ab and safe(Ability.GetName, ab) == nm then
            return clamp(round(safe(Ability.GetLevel, ab) or 1) - 1, 0, 7)
        end
    end
    return 0
end

local function findMod(npc, needle, exact)
    if not npc or not Modifier then return nil end
    local mods = safe(NPC.GetModifiers, npc)
    if type(mods) ~= "table" then return nil end
    for _, md in ipairs(mods) do
        local nm = safe(Modifier.GetName, md)
        if nm and ((exact and nm == needle) or (not exact and sfind(nm, needle, 1, true))) then
            return md
        end
    end
    return nil
end
local function findStack(npc, needle, exact)
    local md = findMod(npc, needle, exact)
    return md and (safe(Modifier.GetStackCount, md) or 0) or 0
end
local function razeStacks()
    return findStack(safe(Heroes.GetLocal), "shadowraze", false)
end
local function soulCount(caster)
    return findStack(caster, "modifier_nevermore_necromastery", true)
end
local function talentOn(caster, suffix)
    for i = 0, 31 do
        local ab = safe(NPC.GetAbilityByIndex, caster, i)
        if ab and sfind(safe(Ability.GetName, ab) or "", suffix, 1, true) then
            return (safe(Ability.GetLevel, ab) or 0) > 0
        end
    end
    return false
end
local function razeDamage(ab, caster, ordinal)
    local lvl     = clamp((safe(Ability.GetLevel, ab) or 1) - 1, 0, 10)
    local sd      = levelVal(ab, "shadowraze_damage", lvl) or 0
    local perSoul = getSpecial(ab, "damage_per_soul") or 0
    local base    = max(safe(Ability.GetDamage, ab) or 0, sd + soulCount(caster) * perSoul)
    local bonus   = levelVal(ab, "stack_bonus_damage", lvl) or 0
    local dmg     = base + (razeStacks() + ordinal) * bonus
    if talentOn(caster, "raze_procsattacks") then
        local me = safe(Heroes.GetLocal)
        local phys = safe(NPC.GetArmorDamageMultiplier, me) or 1
        local mag  = safe(NPC.GetMagicalArmorDamageMultiplier, me) or 1
        if mag > 0.05 then
            dmg = dmg + (safe(NPC.GetTrueDamage, caster) or 0) * phys / mag
        end
    end
    return dmg, DMG.MAGICAL
end

local OVERRIDES = {
    nevermore_shadowraze1 = function(ab, caster) return razeDamage(ab, caster, 0) end,
    nevermore_shadowraze2 = function(ab, caster) return razeDamage(ab, caster, 1) end,
    nevermore_shadowraze3 = function(ab, caster) return razeDamage(ab, caster, 2) end,
    antimage_mana_void = function(ab)
        local me = safe(Heroes.GetLocal)
        local per = getSpecial(ab, "mana_void_damage_per_mana") or getSpecial(ab, "damage_per_mana") or 0
        local missing = (safe(NPC.GetMaxMana, me) or 0) - (safe(NPC.GetMana, me) or 0)
        return missing * per, DMG.MAGICAL
    end,
    necrolyte_reapers_scythe = function(ab)
        local me = safe(Heroes.GetLocal)
        local missing = (safe(Entity.GetMaxHealth, me) or 0) - (safe(Entity.GetHealth, me) or 0)
        return missing * (getSpecial(ab, "damage_per_health") or 0), DMG.MAGICAL
    end,
    kez_raptor_dance = function(ab)
        local me = safe(Heroes.GetLocal)
        local hp = safe(Entity.GetMaxHealth, me) or 0
        local per = (getSpecial(ab, "base_damage") or 0) + hp * (getSpecial(ab, "max_health_damage_pct") or 0) / 100
        local strikes = getSpecial(ab, "strikes") or getSpecial(ab, "strike_count")
            or getSpecial(ab, "number_of_strikes") or getSpecial(ab, "attack_count") or 1
        return per * max(strikes, 1), DMG.PURE
    end,
    luna_eclipse = function(ab, caster)
        local beams = getSpecial(ab, "beam_count") or getSpecial(ab, "total_beams")
            or getSpecial(ab, "beams") or getSpecial(ab, "eclipse_beams") or 0
        local perBeam = 0
        for i = 0, 31 do
            local a2 = safe(NPC.GetAbilityByIndex, caster, i)
            if a2 and safe(Ability.GetName, a2) == "luna_lucent_beam" then
                perBeam = getSpecial(a2, "beam_damage") or 0
                break
            end
        end
        if beams <= 0 then beams = 6 end
        return perBeam * beams, DMG.MAGICAL
    end,
    invoker_sun_strike = function(ab, caster)
        return levelVal(ab, "damage", invokerOrb(caster, "exort")) or 0, DMG.PURE
    end,
    invoker_deafening_blast = function(ab, caster)
        return levelVal(ab, "damage", invokerOrb(caster, "exort")) or 0, DMG.MAGICAL
    end,
    invoker_tornado = function(ab, caster)
        return (getSpecial(ab, "base_damage") or 0)
            + (levelVal(ab, "wex_damage", invokerOrb(caster, "wex")) or 0), DMG.MAGICAL
    end,
    invoker_emp = function(ab, caster)
        local burned = levelVal(ab, "mana_burned", invokerOrb(caster, "wex")) or 0
        return burned * (getSpecial(ab, "damage_per_mana_pct") or 60) / 100, DMG.MAGICAL
    end,
    invoker_chaos_meteor = function(ab, caster)
        local ex = invokerOrb(caster, "exort")
        local main = levelVal(ab, "main_damage", ex) or 0
        local burn = (levelVal(ab, "burn_dps", ex) or 0) * (getSpecial(ab, "burn_duration") or 3)
        return main * 3 + burn, DMG.MAGICAL
    end,
    invoker_cold_snap = function(ab, caster)
        local q = invokerOrb(caster, "quas")
        local per = levelVal(ab, "freeze_damage", q) or getSpecial(ab, "freeze_damage") or 0
        local dur = levelVal(ab, "duration", q) or getSpecial(ab, "duration") or 3
        local cd  = levelVal(ab, "freeze_cooldown", q) or getSpecial(ab, "freeze_cooldown") or 0.8
        return per * clamp(floor(dur / max(cd, 0.3)), 1, 12), DMG.MAGICAL, per
    end,
    morphling_adaptive_strike_agi = function(ab, caster)
        local base = getSpecial(ab, "damage_base") or 0
        local minM = getSpecial(ab, "damage_min") or 0
        local maxM = getSpecial(ab, "damage_max") or 0
        local agi  = safe(Hero.GetAgilityTotal, caster) or 0
        local str  = safe(Hero.GetStrengthTotal, caster) or 0
        local t    = clamp(((agi / max(str, 1)) - 2 / 3) / (3 / 2 - 2 / 3), 0, 1)
        return base + agi * (minM + (maxM - minM) * t), DMG.MAGICAL
    end,
    item_khanda = function(it, caster)
        local pct = getSpecial(it, "damage_pct") or getSpecial(it, "bonus_damage") or 65
        if pct > 1 then pct = pct / 100 end
        local best = 0
        for i = 0, 30 do
            local ab = safe(NPC.GetAbilityByIndex, caster, i)
            if ab and (safe(Ability.GetLevel, ab) or 0) > 0 then
                local mc = safe(Ability.GetManaCost, ab) or 0
                if mc > best then best = mc end
            end
        end
        return pct * best, DMG.MAGICAL
    end,
    item_ethereal_blade = function(it, caster)
        local base = getSpecial(it, "blast_damage_base") or 50
        local mult = getSpecial(it, "blast_stat_multiplier") or 1
        local prim = safe(Hero.GetPrimaryAttribute, caster) or 2
        local stat = (prim == 0 and safe(Hero.GetStrengthTotal, caster))
            or (prim == 1 and safe(Hero.GetAgilityTotal, caster))
            or safe(Hero.GetIntellectTotal, caster) or 0
        return base + stat * mult, DMG.MAGICAL
    end,
    item_spirit_vessel = function(it, caster)
        local me = safe(Heroes.GetLocal)
        local base = getSpecial(it, "soul_damage_amount") or getSpecial(it, "enemy_bonus_health_pct") or 25
        local hpPct = getSpecial(it, "enemy_health_per_burst") or getSpecial(it, "enemy_bonus_health_pct") or 0
        local hp = (safe(Entity.GetHealth, me) or 0) * (hpPct > 1 and hpPct / 100 or hpPct)
        return base + hp, DMG.MAGICAL
    end,
    item_urn_of_shadows = function(it)
        return getSpecial(it, "soul_damage_amount") or 25, DMG.MAGICAL
    end,
    ember_spirit_sleight_of_fist = function(ab, caster)
        local bonus = getSpecial(ab, "bonus_hero_damage") or 0
        return bonus + (safe(NPC.GetTrueDamage, caster) or 0), DMG.PHYSICAL
    end,
    phantom_assassin_stifling_dagger = function(ab, caster, crit)
        local base = getSpecial(ab, "base_damage") or 0
        local factor = getSpecial(ab, "attack_factor_tooltip") or 100
        if factor > 2 then factor = factor / 100 end
        return base * (crit or 1) + (safe(NPC.GetTrueDamage, caster) or 0) * factor, DMG.PHYSICAL
    end,
    luna_lunar_orbit = function(ab, caster)
        local pct = getSpecial(ab, "rotating_glaives_collision_damage") or 0
        if pct > 1 then pct = pct / 100 end
        local perHit = (safe(NPC.GetTrueDamage, caster) or 0) * pct
        local dur = getSpecial(ab, "rotating_glaives_duration") or 8
        return perHit * clamp(floor(dur / 0.6), 1, 20), DMG.PHYSICAL, perHit
    end,
}

local IGNORE_ABILITIES = {
    crystal_maiden_brilliance_aura = true,
    luna_lunar_blessing            = true,
    invoker_quas                   = true,
    invoker_wex                    = true,
    invoker_exort                  = true,
    invoker_invoke                 = true,
}

local ATTACK_MOD = {
    nyx_assassin_vendetta    = DMG.PURE,
    tusk_walrus_punch        = DMG.PHYSICAL,
    bounty_hunter_jinada     = DMG.PHYSICAL,
    riki_blink_strike        = DMG.PHYSICAL,
    weaver_geminate_attack   = DMG.PHYSICAL,
    kunkka_tidebringer       = DMG.PHYSICAL,
    mirana_celestial_quiver  = DMG.MAGICAL,
    sven_great_cleave        = DMG.PHYSICAL,
    spectre_desolate         = DMG.PURE,
}

local ATTACK_BUFF = {
    templar_assassin_refraction = { "modifier_templar_assassin_refraction_damage", "bonus_damage", DMG.PHYSICAL },
    templar_assassin_meld       = { "modifier_templar_assassin_meld", "bonus_damage", DMG.PHYSICAL, pierceKey = "bonus_armor" },
    monkey_king_jingu_mastery   = { "modifier_monkey_king_quadruple_tap_bonuses", "bonus_damage", DMG.PHYSICAL },
    slardar_bash                = { "modifier_slardar_bash_active", "bonus_damage", DMG.PHYSICAL },
    ursa_fury_swipes            = { "fury_swipes", "damage_per_stack", DMG.PHYSICAL, perStack = true, onMe = true },
}

local dumpDebug, deepDump

local tab   = Menu.Create("Scripts", "Main", "Incoming DMG", "Incoming DMG")
local gMain = tab:Create("Main")
local gVis  = tab:Create("Display")

local ui = {}
ui.enabled      = gMain:Switch("Enabled", true)
ui.allEnemies   = gMain:Switch("Show for all enemies", true)
ui.castableOnly = gMain:Switch("Only ready abilities (CD + mana)", true)
ui.items        = gMain:Switch("Include item damage", true)
ui.attack       = gMain:Switch("Include auto-attack (per hit)", true)
ui.crit         = gMain:Switch("Include crit (when active)", true)
ui.passives     = gMain:Switch("Include passive damage", false)
ui.dot          = gMain:Switch("DoT over time (window)", false)
ui.dotWindow    = gMain:Slider("DoT window (sec)", 1, 10, 3)
ui.showTotal    = gMain:Switch("Show total", false)
ui.killAlert    = gMain:Switch("Kill alert (center screen)", true)
ui.killRange    = gMain:Slider("Kill alert range (0 = any)", 0, 3000, 1300)
ui.maxRange     = gMain:Slider("Max range (0 = whole map)", 0, 5000, 0)
ui.debug        = gMain:Switch("Debug logging", false)
gMain:Button("Dump debug to log", function() if dumpDebug then dumpDebug() end end)
gMain:Button("Deep dump (damage breakdown)", function() if deepDump then deepDump() end end)

ui.scale        = gVis:Slider("Panel scale (%)", 70, 170, 100)
ui.moveX        = gVis:Slider("Move X (px)", -600, 600, 0)
ui.moveY        = gVis:Slider("Move Y (px)", -600, 600, 0)
ui.fixedPos     = gVis:Switch("Fixed screen position", false)
ui.posX         = gVis:Slider("Fixed X (%)", 0, 100, 50)
ui.posY         = gVis:Slider("Fixed Y (%)", 0, 100, 35)
ui.useIcons     = gVis:Switch("Real game icons", true)
ui.cPhysical    = gVis:ColorPicker("Physical color", Color(255, 96, 72, 255))
ui.cMagical     = gVis:ColorPicker("Magical color",  Color(86, 162, 255, 255))
ui.cPure        = gVis:ColorPicker("Pure color",      Color(232, 220, 140, 255))
ui.cLethal      = gVis:ColorPicker("Lethal color",    Color(255, 64, 64, 255))
ui.cBg          = gVis:ColorPicker("Background tint", Color(0, 0, 0, 70))
ui.skull        = gVis:Switch("Skull indicator", true)
ui.cCalm        = gVis:ColorPicker("Skull: safe",    Color(120, 220, 130, 255))
ui.cWarn        = gVis:ColorPicker("Skull: warning", Color(255, 200, 70, 255))

local cfgCache = {}
local function readCfg()
    local c = cfgCache
    c.enabled      = ui.enabled:Get()
    c.allEnemies   = ui.allEnemies:Get()
    c.castableOnly = ui.castableOnly:Get()
    c.items        = ui.items:Get()
    c.attack       = ui.attack:Get()
    c.crit         = ui.crit:Get()
    c.passives     = ui.passives:Get()
    c.dot          = ui.dot:Get()
    c.dotWindow    = ui.dotWindow:Get()
    c.showTotal    = ui.showTotal:Get()
    c.maxRange     = ui.maxRange:Get()
    c.scale        = clamp(ui.scale:Get() / 100, 0.5, 2.0)
    c.moveX        = ui.moveX:Get()
    c.moveY        = ui.moveY:Get()
    c.fixedPos     = ui.fixedPos:Get()
    c.posX         = ui.posX:Get()
    c.posY         = ui.posY:Get()
    c.useIcons     = ui.useIcons:Get()
    c.cPhysical    = ui.cPhysical:Get()
    c.cMagical     = ui.cMagical:Get()
    c.cPure        = ui.cPure:Get()
    c.cLethal      = ui.cLethal:Get()
    c.cBg          = ui.cBg:Get()
    c.skull        = ui.skull:Get()
    c.killAlert    = ui.killAlert:Get()
    c.killRange    = ui.killRange:Get()
    c.cCalm        = ui.cCalm:Get()
    c.cWarn        = ui.cWarn:Get()
    return c
end

local function dtColor(dt, cfg)
    if dt == DMG.PHYSICAL then return cfg.cPhysical
    elseif dt == DMG.PURE then return cfg.cPure
    elseif dt == DMG.HP_REMOVAL then return cfg.cPure
    else return cfg.cMagical end
end

local function isReadyNow(ab, mana)
    local c = safe(Ability.IsCastable, ab, mana, true)
    if c ~= nil then return c and true or false end
    local r = safe(Ability.IsReady, ab)
    if r == false then return false end
    local m = safe(Ability.IsOwnersManaEnough, ab)
    if m == false then return false end
    return true
end

local CRIT_KEYS = { "crit_bonus", "crit_multiplier", "crit_damage", "coup_crit" }
local CRIT_SPELLS = {
    kunkka_tidebringer               = true,
    juggernaut_omni_slash            = true,
    chaos_knight_chaos_strike        = true,
}
local CRIT_ACTIVE_MODS = {
    "modifier_phantom_assassin_mark_of_death",
}
local function critActive(enemy)
    for i = 1, #CRIT_ACTIVE_MODS do
        if findMod(enemy, CRIT_ACTIVE_MODS[i], true) then return true end
    end
    return false
end
local function getCrit(enemy, mana)
    local best = 1
    for i = 0, 30 do
        local ab = safe(NPC.GetAbilityByIndex, enemy, i)
        if ab and (safe(Ability.GetLevel, ab) or 0) > 0 then
            for k = 1, #CRIT_KEYS do
                local cb = getSpecial(ab, CRIT_KEYS[k]) or 0
                if cb > 10 then cb = cb / 100 end
                if cb > best then best = cb end
            end
        end
    end
    for i = 0, 16 do
        local it = safe(NPC.GetItemByIndex, enemy, i)
        if it and isReadyNow(it, mana) then
            for k = 1, #CRIT_KEYS do
                local cb = getSpecial(it, CRIT_KEYS[k]) or 0
                if cb > 10 then cb = cb / 100 end
                if cb > best then best = cb end
            end
        end
    end
    return clamp(best, 1, 6)
end

local function collectSources(enemy, cfg)
    local out = {}
    local atkBonus = 0
    local armorPierce = 0
    local mana = safe(NPC.GetMana, enemy) or 0
    local sampP = (safe(NPC.GetModifierProperty, enemy, PROP.spell_amp) or 0)
        + (safe(NPC.GetModifierProperty, enemy, PROP.spell_amp_u) or 0)
    local spellAmp = clamp(sampP / 100, 0, 2)
    if spellAmp == 0 then spellAmp = clamp(safe(NPC.GetBaseSpellAmp, enemy) or 0, 0, 2) end
    local itemAmp = 0
    for i = 0, 16 do
        local it = safe(NPC.GetItemByIndex, enemy, i)
        if it then
            local a = ITEM_AMP[safe(Ability.GetName, it) or ""]
            if a and isReadyNow(it, mana) then itemAmp = itemAmp + a / 100 end
        end
    end
    local magAmp = clamp(spellAmp + itemAmp, 0, 2)
    local critMult = (cfg.crit and critActive(enemy)) and getCrit(enemy, mana) or 1

    for i = 0, 30 do
        local ab = safe(NPC.GetAbilityByIndex, enemy, i)
        if ab then
            local name = safe(Ability.GetName, ab) or ""
            local lvl  = safe(Ability.GetLevel, ab) or 0
            local abuff = ATTACK_BUFF[name]
            if abuff then
                if lvl > 0 then
                    local val = getSpecial(ab, abuff[2]) or 0
                    local active, bonus
                    if abuff.perStack then
                        local stacks = findStack(abuff.onMe and safe(Heroes.GetLocal) or enemy, abuff[1], false)
                        active, bonus = stacks > 0, stacks * val
                    else
                        active, bonus = findMod(enemy, abuff[1], true) ~= nil, val
                    end
                    if active and bonus > 0 then
                        atkBonus = atkBonus + bonus
                        if abuff.pierceKey then armorPierce = armorPierce + abs(getSpecial(ab, abuff.pierceKey) or 0) end
                    elseif val > 0 then
                        local ready = isReadyNow(ab, mana)
                        if (not cfg.castableOnly) or ready then
                            out[#out + 1] = { name = name, raw = val, dt = abuff[3] or DMG.PHYSICAL, ready = ready, kind = "ability" }
                        end
                    end
                end
            elseif lvl > 0 and not IGNORE_ABILITIES[name] then
                local passive = safe(Ability.IsPassive, ab)
                if (passive ~= true) or cfg.passives or ATTACK_MOD[name] then
                    local raw, dt, tick
                    local ov = OVERRIDES[name]
                    if ov then
                        raw, dt, tick = ov(ab, enemy, critMult)
                    elseif ATTACK_MOD[name] then
                        raw = ((getSpecial(ab, "bonus_damage") or 0) + (safe(NPC.GetTrueDamage, enemy) or 0)) * critMult
                        dt = ATTACK_MOD[name]
                    else
                        local perSec
                        raw, perSec = estimateRaw(ab, name)
                        local e = SPELL_DMG[name]
                        dt  = (e and e.t) or safe(Ability.GetDamageType, ab) or DMG.MAGICAL
                        if CRIT_SPELLS[name] then raw = raw * critMult end
                        if raw > 0 and magAmp > 0 and (dt == DMG.MAGICAL or dt == DMG.PURE) then
                            raw = raw * (1 + magAmp)
                        end
                        if perSec and raw > 0 then
                            tick = raw
                            local dur = getSpecial(ab, "duration") or getSpecial(ab, "channel_duration") or cfg.dotWindow
                            raw = raw * clamp(min(cfg.dotWindow, dur), 1, 30)
                        end
                    end
                    if raw and raw > 0 then
                        local ready = (passive == true) and true or isReadyNow(ab, mana)
                        if (not cfg.castableOnly) or ready then
                            out[#out + 1] = { name = name, raw = raw, dt = dt, ready = ready, kind = "ability", perTick = tick }
                        end
                    end
                end
            end
        end
    end

    if cfg.items then
        for i = 0, 16 do
            local it = safe(NPC.GetItemByIndex, enemy, i)
            if it then
                local name = safe(Ability.GetName, it) or ""
                local ov = OVERRIDES[name]
                local onhit = ITEM_ONHIT[name]
                local raw, dt
                if ITEM_CHARGES[name] and (safe(Ability.GetCurrentCharges, it) or 0) < 1 then
                    raw = 0
                elseif ov then
                    raw, dt = ov(it, enemy)
                elseif onhit then
                    raw = getSpecial(it, onhit[1]) or 0
                    dt  = onhit[2]
                elseif ITEM_TYPE_FIX[name] ~= nil then
                    local tf = ITEM_TYPE_FIX[name]
                    if tf then
                        local perSec
                        raw, perSec = estimateRaw(it)
                        dt = tf
                        if perSec and raw > 0 then raw = raw * dotScale(it, cfg) end
                    end
                elseif not ITEM_DENY[name] and safe(Ability.IsPassive, it) ~= true then
                    local perSec
                    raw, perSec = estimateRaw(it)
                    dt  = safe(Ability.GetDamageType, it)
                    if dt ~= DMG.PHYSICAL and dt ~= DMG.PURE then dt = DMG.MAGICAL end
                    if perSec and raw > 0 then raw = raw * dotScale(it, cfg) end
                    if raw and raw > 0 and magAmp > 0 and (dt == DMG.MAGICAL or dt == DMG.PURE) then
                        raw = raw * (1 + magAmp)
                    end
                end
                if raw and raw > 0 then
                    local ready = onhit and true or isReadyNow(it, mana)
                    if (not cfg.castableOnly) or ready then
                        out[#out + 1] = { name = name, raw = raw, dt = dt, ready = ready, kind = "item" }
                    end
                end
            end
        end
    end

    if cfg.attack then
        local atkMin = safe(NPC.GetTrueDamage, enemy)
        local atkMax = safe(NPC.GetTrueMaximumDamage, enemy)
        local atk
        if atkMin and atkMax and atkMax > 0 then
            atk = (atkMin + atkMax) / 2
        elseif atkMin and atkMin > 0 then
            atk = atkMin
        else
            atk = (safe(NPC.GetMinDamage, enemy) or 0) + (safe(NPC.GetBonusDamage, enemy) or 0)
        end
        if atk and atk > 0 then
            local uname = safe(Entity.GetUnitName, enemy)
            if uname and NPCs then
                local me2 = safe(Heroes.GetLocal)
                local mxx, myy2 = safe(Entity.GetAbsOriginXYZ, me2)
                local cnt = 0
                for _, n in ipairs(safe(NPCs.GetAll) or {}) do
                    if cnt >= 4 then break end
                    if n ~= enemy and safe(NPC.IsIllusion, n) == true
                        and safe(Entity.GetUnitName, n) == uname
                        and safe(Entity.IsAlive, n) and not safe(Entity.IsDormant, n) then
                        local nx, ny = safe(Entity.GetAbsOriginXYZ, n)
                        local dd = ((nx or 0) - (mxx or 0)) ^ 2 + ((ny or 0) - (myy2 or 0)) ^ 2
                        if dd <= 1100 * 1100 then
                            atk = atk + (safe(NPC.GetTrueDamage, n) or 0)
                            cnt = cnt + 1
                        end
                    end
                end
            end
            local araw = (atk + atkBonus) * critMult
            if armorPierce > 0 then
                local mult = safe(NPC.GetArmorDamageMultiplier, safe(Heroes.GetLocal))
                if mult and mult > 0.02 and mult < 1 then
                    local a = (1 - mult) / (0.06 * mult) - armorPierce
                    local mult2
                    if a >= 0 then mult2 = 1 - 0.06 * a / (1 + 0.06 * a)
                    else local na = -a; mult2 = 1 + 0.06 * na / (1 + 0.06 * na) end
                    araw = araw * (mult2 / mult)
                end
            end
            out[#out + 1] = { name = "attack", raw = araw, dt = DMG.PHYSICAL, ready = true, kind = "attack" }
        end
    end

    return out
end

local function myMultipliers(me)
    local phys = safe(NPC.GetArmorDamageMultiplier, me)
    if not phys or phys <= 0 or phys > 2 then
        local armor = safe(NPC.GetPhysicalArmorValue, me) or 0
        phys = 1 - (0.06 * armor) / (1 + 0.06 * abs(armor))
    end
    local mag = safe(NPC.GetMagicalArmorDamageMultiplier, me)
    if not mag or mag < 0 or mag > 2 then
        local mr = safe(NPC.GetMagicalArmorValue, me) or 0
        if mr > 1 then mr = mr / 100 end
        mag = 1 - mr
    end
    local incAll = safe(NPC.GetModifierProperty, me, PROP.inc_all) or 0
    local incPP  = safe(NPC.GetModifierProperty, me, PROP.inc_pp) or 0
    local incPF  = safe(NPC.GetModifierProperty, me, PROP.inc_pf) or 0
    local incSF  = safe(NPC.GetModifierProperty, me, PROP.inc_sf) or 0
    local ethereal = safe(NPC.HasModifier, me, "modifier_item_ethereal_blade_ethereal") == true
        or safe(NPC.HasModifier, me, "modifier_pugna_decrepify") == true
    return {
        phys = clamp(phys, 0, 2),
        mag = clamp(mag, 0, 2),
        incAll = clamp(incAll / 100, -0.95, 4),
        incPP = clamp(incPP / 100, -0.95, 4),
        incPF = incPF,
        incSF = incSF,
        immune = safe(NPC.HasState, me, STATE_MAGIC_IMMUNE) == true,
        ethereal = ethereal,
        rawIncAll = incAll, rawIncPP = incPP, rawIncPF = incPF, rawIncSF = incSF,
    }
end

local function mitigate(raw, dt, m)
    if dt == DMG.HP_REMOVAL then return raw end
    local d
    if dt == DMG.PHYSICAL then
        if m.ethereal then return 0 end
        d = raw * m.phys * (1 + m.incPP) + m.incPF
    elseif dt == DMG.PURE then
        d = raw
    else
        if m.immune then return 0 end
        d = raw * m.mag + m.incSF
    end
    d = d * (1 + m.incAll)
    if d < 0 then d = 0 end
    return d
end

local cache = {}
local tick  = 0
local function byFinalDesc(a, b) return a.final > b.final end

local function recompute()
    local cfg = readCfg()
    if not cfg.enabled then cache = {}; return end

    local me = safe(Heroes.GetLocal)
    if not me or not safe(Entity.IsAlive, me) then cache = {}; return end

    local myTeam  = safe(Entity.GetTeamNum, me)
    local myHP    = safe(Entity.GetHealth, me) or 1
    local mult    = myMultipliers(me)
    local regenHeal = cfg.dot and (safe(NPC.GetHealthRegen, me) or 0) * cfg.dotWindow or 0
    local mx, myy = safe(Entity.GetAbsOriginXYZ, me)
    mx, myy = mx or 0, myy or 0

    local heroes = safe(Heroes.GetAll) or {}
    local maxR2  = (cfg.maxRange > 0) and (cfg.maxRange * cfg.maxRange) or nil

    local result = {}
    local nearest, nearestD2 = nil, huge

    for _, h in ipairs(heroes) do
        if h ~= me
            and safe(Entity.IsAlive, h)
            and not safe(Entity.IsDormant, h)
            and safe(NPC.IsVisible, h) ~= false
            and safe(Entity.GetTeamNum, h) ~= myTeam
            and not safe(NPC.IsIllusion, h)
        then
            local hx, hy = safe(Entity.GetAbsOriginXYZ, h)
            local d2 = ((hx or 0) - mx) ^ 2 + ((hy or 0) - myy) ^ 2
            if (not maxR2) or d2 <= maxR2 then
                local rows  = collectSources(h, cfg)
                local total = 0
                for _, r in ipairs(rows) do
                    r.final = mitigate(r.raw, r.dt, mult)
                    if r.perTick then r.finalTick = mitigate(r.perTick, r.dt, mult) end
                    if r.ready then total = total + r.final end
                end
                sort(rows, byFinalDesc)
                local entry = { hero = h, total = total, lethal = total >= (myHP + regenHeal), rows = rows, d2 = d2 }
                if cfg.allEnemies then
                    result[#result + 1] = entry
                elseif d2 < nearestD2 then
                    nearestD2, nearest = d2, entry
                end
            end
        end
    end

    if not cfg.allEnemies and nearest then result = { nearest } end
    cache = result
end

local ANCHOR_Z     <const> = 240
local PANEL_GAP    <const> = 40
local COL_WHITE    <const> = Color(236, 236, 240, 255)
local COL_DIM      <const> = Color(150, 152, 162, 255)
local COL_FADE     <const> = Color(10, 10, 12, 150)
local COL_BG_BASE  <const> = Color(16, 18, 26, 120)
local COL_BORDER   <const> = Color(0, 0, 0, 200)
local COL_ICON_ON  <const> = Color(255, 255, 255, 255)
local COL_ICON_OFF <const> = Color(255, 255, 255, 110)
local COL_DEBUG    <const> = Color(255, 0, 255, 255)

local FONT
local function ensureFont()
    if FONT == nil then
        local flag = (Enum and Enum.FontCreate and Enum.FontCreate.FONTFLAG_ANTIALIAS) or 0
        local fw = Enum and Enum.FontWeight
        local w = (fw and (fw.NORMAL or fw.REGULAR or fw.MEDIUM)) or 400
        FONT = safe(Render.LoadFont, "MuseoSansEx", flag, w)
        if not FONT or FONT == 0 then FONT = safe(Render.LoadFont, "Tahoma", flag, w) end
        FONT = FONT or false
    end
    return FONT or nil
end

local function textW(font, size, str)
    local sz = font and safe(Render.TextSize, font, size, str)
    return (sz and sz.x) or 0
end
local function drawText(font, size, str, x, y, color)
    if font then safe(Render.Text, font, size, str, Vec2(x, y), color) end
end

local function worldToScreen(hx, hy, hz)
    if Renderer and Renderer.WorldToScreen then
        local x, y, vis = safe(Renderer.WorldToScreen, Vector(hx, hy, hz))
        if type(x) == "number" then return x, y, vis ~= false end
    end
    local sp, vis = safe(Render.WorldToScreen, Vector(hx, hy, hz))
    if sp then return sp.x, sp.y, vis ~= false end
    return nil
end

local camCV
local function cameraZoom()
    if not ConVar then return 1 end
    if camCV == nil then camCV = safe(ConVar.Find, "dota_camera_distance") or false end
    if camCV then
        local d = safe(ConVar.GetFloat, camCV)
        if d and d > 0 then return clamp(1200 / d, 0.3, 4) end
    end
    return 1
end

local function spellPaths(name)
    return {
        "panorama/images/spellicons/" .. name .. "_png.vtex_c",
        "panorama/images/spellicons/" .. name .. ".vtex_c",
        "resource/flash3/images/spellicons/" .. name .. ".png",
    }
end
local function itemPaths(name)
    local s = name:gsub("^item_", "")
    return {
        "panorama/images/items/" .. s .. "_png.vtex_c",
        "panorama/images/items/" .. s .. ".vtex_c",
        "resource/flash3/images/items/" .. s .. ".png",
    }
end
local ATTACK_PATHS = {
    "~/MenuIcons/knife_kill.png",
    "panorama/images/hud/reborn/icon_damage_psd.vtex_c",
}

local function loadAny(paths)
    for i = 1, #paths do
        local p = paths[i]
        local h = safe(Render.LoadImage, p)
        if h and h ~= 0 then return h, "v2" end
        if Renderer then
            h = safe(Renderer.LoadImage, p)
            if h and h ~= 0 then return h, "v1" end
        end
    end
    return nil
end

local iconCache = {}
local function getIcon(name, kind)
    local key = kind .. ":" .. name
    local c = iconCache[key]
    if c ~= nil then return c or nil end
    local paths
    if kind == "item" then paths = itemPaths(name)
    elseif kind == "attack" then paths = ATTACK_PATHS
    else paths = spellPaths(name) end
    local h, api = loadAny(paths)
    iconCache[key] = h and { h = h, api = api } or false
    return iconCache[key] or nil
end

local function rgbaOf(c)
    local r, g, b = safe(c and c.Unpack, c)
    if r then return r, g, b end
    return 255, 255, 255
end

local function drawIcon(ic, x, y, sz, tint, rnd)
    if ic.api == "v2" then
        safe(Render.Image, ic.h, Vec2(x, y), Vec2(sz, sz), tint, rnd)
    else
        local r, g, b = rgbaOf(tint)
        safe(Renderer.SetDrawColor, r, g, b, 255)
        safe(Renderer.DrawImage, ic.h, floor(x), floor(y), floor(sz), floor(sz))
    end
end

local function drawSword(x, y, sz)
    local th = max(1, round(sz * 0.09))
    local cx = x + sz * 0.5
    safe(Render.Line, Vec2(cx, y + sz * 0.14), Vec2(cx, y + sz * 0.7), COL_WHITE, th)
    safe(Render.Line, Vec2(x + sz * 0.3, y + sz * 0.6), Vec2(x + sz * 0.7, y + sz * 0.6), COL_WHITE, th)
    safe(Render.Line, Vec2(cx, y + sz * 0.7), Vec2(cx, y + sz * 0.86), COL_WHITE, th)
end

local skullIcon
local function ensureSkull()
    if skullIcon == nil then
        local h, api = loadAny({ "~/MenuIcons/skull.png" })
        skullIcon = h and { h = h, api = api } or false
    end
    return skullIcon or nil
end

local function tierColor(remainPct, lethal, cfg)
    if lethal or remainPct <= 0 then return cfg.cLethal
    elseif remainPct <= 40 then return cfg.cWarn
    else return cfg.cCalm end
end

local function rowLabel(r)
    if r.finalTick then return fmt(r.finalTick) .. "|" .. fmt(r.final) end
    return fmt(r.final)
end

local function drawPanel(anchorX, anchorY, mode, entry, remainPct, cfg, font)
    local rows = entry.rows
    local n = #rows
    local s = cfg.scale
    local padX = round(9 * s)
    local padY = round(8 * s)
    local iconSz = round(28 * s)
    local gap = round(9 * s)
    local rowH = iconSz + round(4 * s)
    local fNum = round(18 * s)
    local fHdr = round(19 * s)
    local rnd = round(8 * s)
    local iconRnd = round(5 * s)

    local hpStr = "HP: " .. remainPct .. "%"
    local contentW = textW(font, fHdr, hpStr)
    for i = 1, n do
        contentW = max(contentW, iconSz + gap + textW(font, fNum, rowLabel(rows[i])))
    end
    local totalStr
    if cfg.showTotal then
        totalStr = "DMG " .. fmt(entry.total)
        contentW = max(contentW, textW(font, fNum, totalStr))
    end

    local panelW = contentW + padX * 2
    local headerH = fHdr + round(6 * s)
    local totalH = cfg.showTotal and (fNum + round(5 * s)) or 0
    local panelH = padY + headerH + n * rowH + totalH + padY

    local x0
    if mode == "fixed" then
        x0 = round(anchorX - panelW / 2)
    else
        x0 = round(anchorX - panelW)
    end
    local y0 = round(anchorY)
    local x1 = x0 + panelW
    local y1 = y0 + panelH

    local p0, p1 = Vec2(x0, y0), Vec2(x1, y1)
    safe(Render.FilledRect, p0, p1, COL_BG_BASE, rnd)
    safe(Render.FilledRect, p0, p1, cfg.cBg, rnd)
    safe(Render.Rect, p0, p1, COL_BORDER, rnd, nil, 1)
    if entry.lethal then
        safe(Render.Rect, p0, p1, cfg.cLethal, rnd, nil, max(1, round(1.5 * s)))
    end

    drawText(font, fHdr, hpStr, x0 + padX, y0 + padY, (remainPct <= 35) and cfg.cLethal or COL_WHITE)

    local cy = y0 + padY + headerH
    for i = 1, n do
        local r = rows[i]
        local ix = x0 + padX
        local iy = cy + round((rowH - iconSz) / 2)
        local ic = nil
        if cfg.useIcons then
            ic = r.icon
            if ic == nil then ic = getIcon(r.name, r.kind) or false; r.icon = ic end
            if ic == false then ic = nil end
        end
        if ic then
            local tint
            if r.kind == "attack" then tint = cfg.cPhysical
            elseif r.ready then tint = COL_ICON_ON
            else tint = COL_ICON_OFF end
            drawIcon(ic, ix, iy, iconSz, tint, iconRnd)
        else
            local col = (r.kind == "attack") and cfg.cPhysical or dtColor(r.dt, cfg)
            safe(Render.FilledRect, Vec2(ix, iy), Vec2(ix + iconSz, iy + iconSz), col, iconRnd)
            if r.kind == "attack" then drawSword(ix, iy, iconSz) end
            if not r.ready then
                safe(Render.FilledRect, Vec2(ix, iy), Vec2(ix + iconSz, iy + iconSz), COL_FADE, iconRnd)
            end
        end
        drawText(font, fNum, rowLabel(r), ix + iconSz + gap, cy + round((rowH - fNum) / 2),
                 r.ready and COL_WHITE or COL_DIM)
        cy = cy + rowH
    end

    if cfg.showTotal then
        drawText(font, fNum, totalStr, x0 + padX, cy + round(2 * s), entry.lethal and cfg.cLethal or COL_WHITE)
    end

    if cfg.skull then
        local ssz = round(20 * s)
        local sxx = x0 - round(ssz * 0.35)
        local syy = y0 - round(ssz * 0.7)
        local tc = tierColor(remainPct, entry.lethal, cfg)
        local sk = ensureSkull()
        if sk then
            drawIcon(sk, sxx, syy, ssz, tc, round(4))
        else
            safe(Render.FilledRect, Vec2(sxx, syy), Vec2(sxx + ssz, syy + ssz), tc, round(4))
        end
    end

    return panelH
end

dumpDebug = function()
    local me = safe(Heroes.GetLocal)
    if not me then logErr("[IncDMG][dbg] no local hero"); return end
    local hp = safe(Entity.GetHealth, me) or 0
    local mx = safe(Entity.GetMaxHealth, me) or 1
    local mult = myMultipliers(me)
    local ss = safe(Render.ScreenSize)
    logErr("[IncDMG][dbg] ==== dump ====")
    logErr(sformat("[IncDMG][dbg] me=%s hp=%d/%d physMult=%.2f magMult=%.2f enemies=%d screen=%sx%s",
        safe(Entity.GetUnitName, me) or "?", round(hp), round(mx), mult.phys, mult.mag, #cache,
        ss and tostring(round(ss.x)) or "?", ss and tostring(round(ss.y)) or "?"))
    logErr(sformat("[IncDMG][dbg] mods incAll=%d incPhysPct=%d physBlock=%d spellBlock=%d magImmune=%s",
        round(mult.rawIncAll or 0), round(mult.rawIncPP or 0), round(mult.rawIncPF or 0),
        round(mult.rawIncSF or 0), tostring(mult.immune)))
    for _, e in ipairs(cache) do
        local hx, hy, hz = safe(Entity.GetAbsOriginXYZ, e.hero)
        local ax, ay, vis = worldToScreen(hx or 0, hy or 0, hz or 0)
        logErr(sformat("[IncDMG][dbg] enemy=%s total=%d rows=%d world=(%.0f,%.0f) screen=(%s,%s) vis=%s",
            safe(Entity.GetUnitName, e.hero) or "?", round(e.total or 0), #e.rows, hx or 0, hy or 0,
            ax and sformat("%.0f", ax) or "nil", ay and sformat("%.0f", ay) or "nil", tostring(vis)))
        for _, r in ipairs(e.rows) do
            local ic = iconCache[r.kind .. ":" .. r.name]
            local ics = (ic == nil) and "untried" or (ic and ("OK:" .. tostring(ic.api)) or "chip")
            logErr(sformat("[IncDMG][dbg]   %s %s raw=%d type=%s final=%d ready=%s icon=%s",
                r.kind, r.name, round(r.raw or 0), tostring(r.dt), round(r.final or 0),
                tostring(r.ready), ics))
        end
    end
    logErr("[IncDMG][dbg] ==== end ====")
end

local function dtName(dt)
    if dt == DMG.PHYSICAL then return "PHYS"
    elseif dt == DMG.MAGICAL then return "MAGIC"
    elseif dt == DMG.PURE then return "PURE"
    elseif dt == DMG.HP_REMOVAL then return "HPREM"
    else return "NONE/" .. tostring(dt) end
end

local function keysOf(ab)
    local parts = {}
    local function add(k)
        local cur = getSpecial(ab, k)
        local v1 = levelVal(ab, k, 1)
        if (cur == nil or cur == 0) and (v1 == nil or v1 == 0) then return end
        local arr, same = {}, true
        for L = 1, 11 do
            arr[L] = levelVal(ab, k, L) or 0
            if arr[L] ~= arr[1] then same = false end
        end
        if same then
            parts[#parts + 1] = k .. "=" .. fmt(cur or arr[1])
        else
            local s = {}
            for L = 1, 11 do s[L] = fmt(arr[L]) end
            parts[#parts + 1] = k .. "=" .. concat(s, "/")
        end
    end
    for i = 1, #DAMAGE_KEYS do add(DAMAGE_KEYS[i]) end
    for i = 1, #DIAG_KEYS do add(DIAG_KEYS[i]) end
    return (#parts > 0) and concat(parts, ", ") or "-"
end

local function modList(npc)
    if not Modifier then return "-" end
    local mods = safe(NPC.GetModifiers, npc)
    if type(mods) ~= "table" then return "-" end
    local parts = {}
    for _, md in ipairs(mods) do
        local nm = safe(Modifier.GetName, md)
        if nm and nm ~= "" then
            local sc = safe(Modifier.GetStackCount, md) or 0
            parts[#parts + 1] = (sc > 0) and (nm .. "(" .. round(sc) .. ")") or nm
        end
    end
    return (#parts > 0) and concat(parts, ", ") or "-"
end

deepDump = function()
    local me = safe(Heroes.GetLocal)
    if not me then logErr("[deep] no local hero"); return end
    local m = myMultipliers(me)
    logErr("[deep] ===== DEEP DAMAGE DUMP =====")
    logErr(sformat("[deep] ME %s hp=%d/%d mana=%d/%d str=%d agi=%d int=%d armorMult=%.2f magMult=%.2f incAll=%d incPhysPct=%d physBlock=%d spellBlock=%d magImmune=%s ethereal=%s",
        safe(Entity.GetUnitName, me) or "?",
        round(safe(Entity.GetHealth, me) or 0), round(safe(Entity.GetMaxHealth, me) or 0),
        round(safe(NPC.GetMana, me) or 0), round(safe(NPC.GetMaxMana, me) or 0),
        round(safe(Hero.GetStrengthTotal, me) or 0), round(safe(Hero.GetAgilityTotal, me) or 0),
        round(safe(Hero.GetIntellectTotal, me) or 0),
        m.phys, m.mag, round(m.rawIncAll or 0), round(m.rawIncPP or 0), round(m.rawIncPF or 0),
        round(m.rawIncSF or 0), tostring(m.immune), tostring(m.ethereal)))
    local bar = safe(NPC.GetBarriers, me)
    logErr(sformat("[deep] ME-DEF armor=%d magResistRaw=%.3f barrier(p/m/all)=%d/%d/%d evasion=%d miss=%d",
        round(safe(NPC.GetPhysicalArmorValue, me) or 0), safe(NPC.GetMagicalArmorValue, me) or 0,
        round(bar and bar.physical and bar.physical.current or 0),
        round(bar and bar.magic and bar.magic.current or 0),
        round(bar and bar.all and bar.all.current or 0),
        round(safe(NPC.GetModifierProperty, me, PROP.evasion) or 0),
        round(safe(NPC.GetModifierProperty, me, PROP.miss) or 0)))
    logErr("[deep] ME-MODS " .. modList(me))

    local myTeam = safe(Entity.GetTeamNum, me)
    for _, h in ipairs(safe(Heroes.GetAll) or {}) do
        if h ~= me and safe(Entity.IsAlive, h) and safe(Entity.GetTeamNum, h) ~= myTeam
           and not safe(NPC.IsIllusion, h) then
            local sAmp = safe(NPC.GetBaseSpellAmp, h) or 0
            local outAmp = safe(NPC.GetModifierProperty, h, PROP.out_total) or 0
            logErr(sformat("[deep] ENEMY %s str=%d/%d agi=%d/%d int=%d/%d prim=%s mana=%d/%d hp=%d/%d atk=%d/%d spellAmp=%.2f outAmp=%d",
                safe(Entity.GetUnitName, h) or "?",
                round(safe(Hero.GetStrength, h) or 0), round(safe(Hero.GetStrengthTotal, h) or 0),
                round(safe(Hero.GetAgility, h) or 0), round(safe(Hero.GetAgilityTotal, h) or 0),
                round(safe(Hero.GetIntellect, h) or 0), round(safe(Hero.GetIntellectTotal, h) or 0),
                tostring(safe(Hero.GetPrimaryAttribute, h)),
                round(safe(NPC.GetMana, h) or 0), round(safe(NPC.GetMaxMana, h) or 0),
                round(safe(Entity.GetHealth, h) or 0), round(safe(Entity.GetMaxHealth, h) or 0),
                round(safe(NPC.GetTrueDamage, h) or 0), round(safe(NPC.GetTrueMaximumDamage, h) or 0),
                sAmp, round(outAmp)))
            logErr(sformat("[deep] ENEMY-X %s lvl=%d aps=%.2f ranged=%s scepter=%s shard=%s spellAmp%%=%d outBonus=%d out%%=%d outTotal=%d",
                safe(Entity.GetUnitName, h) or "?",
                round(safe(NPC.GetCurrentLevel, h) or 0), safe(NPC.GetAttacksPerSecond, h) or 0,
                tostring(safe(NPC.IsRanged, h) == true), tostring(safe(NPC.HasScepter, h) == true),
                tostring(safe(NPC.HasShard, h) == true),
                round((safe(NPC.GetModifierProperty, h, PROP.spell_amp) or 0) + (safe(NPC.GetModifierProperty, h, PROP.spell_amp_u) or 0)),
                round(safe(NPC.GetModifierProperty, h, PROP.out_bonus) or 0),
                round(safe(NPC.GetModifierProperty, h, PROP.out_pct) or 0), round(outAmp)))
            logErr("[deep] ENEMY-MODS " .. modList(h))
            for i = 0, 31 do
                local ab = safe(NPC.GetAbilityByIndex, h, i)
                if ab then
                    local nm = safe(Ability.GetName, ab) or "?"
                    local rraw, rdt
                    local ov = OVERRIDES[nm]
                    if ov then rraw, rdt = ov(ab, h)
                    elseif ATTACK_MOD[nm] then rraw, rdt = getSpecial(ab, "bonus_damage"), ATTACK_MOD[nm]
                    else
                        rraw = estimateRaw(ab, nm)
                        local e = SPELL_DMG[nm]
                        rdt = (e and e.t) or safe(Ability.GetDamageType, ab)
                    end
                    logErr(sformat("[deep]   ABIL %s t=%s lvl=%d/%d pas=%s used=%s%s gd=%d ch=%d | %s",
                        nm, dtName(rdt), round(safe(Ability.GetLevel, ab) or 0),
                        round(safe(Ability.GetMaxLevel, ab) or 0),
                        tostring(safe(Ability.IsPassive, ab) == true),
                        fmt(rraw or 0), ov and "(ovr)" or "",
                        round(safe(Ability.GetDamage, ab) or 0),
                        round(safe(Ability.GetCurrentCharges, ab) or 0), keysOf(ab)))
                end
            end
            for i = 0, 17 do
                local it = safe(NPC.GetItemByIndex, h, i)
                if it then
                    logErr(sformat("[deep]   ITEM %s t=%s ch=%d mana=%d used=%s | %s",
                        safe(Ability.GetName, it) or "?", dtName(safe(Ability.GetDamageType, it)),
                        round(safe(Ability.GetCurrentCharges, it) or 0),
                        round(safe(Ability.GetManaCost, it) or 0),
                        fmt(estimateRaw(it)), keysOf(it)))
                end
            end
        end
    end
    logErr("[deep] ===== END =====")
end

local function onUpdate()
    tick = tick + 1
    if tick % 3 ~= 0 then return end
    recompute()
    if ui.debug:Get() and (tick % 30 == 0) then dumpDebug() end
end

local function remainPctOf(total, hp, regenHeal, maxhp)
    return clamp(round((hp + regenHeal - total) / max(maxhp, 1) * 100), 0, 100)
end

local function onDraw()
    local cfg = readCfg()
    if not cfg.enabled then return end

    local me = safe(Heroes.GetLocal)
    if not me or not safe(Entity.IsAlive, me) then return end

    local font = ensureFont()
    local hp    = safe(Entity.GetHealth, me) or 0
    local maxhp = safe(Entity.GetMaxHealth, me) or 1
    local regenHeal = cfg.dot and (safe(NPC.GetHealthRegen, me) or 0) * cfg.dotWindow or 0

    if cfg.fixedPos then
        local ss = safe(Render.ScreenSize)
        local sw = (ss and ss.x) or 1920
        local sh = (ss and ss.y) or 1080
        local px = sw * cfg.posX / 100
        local y  = sh * cfg.posY / 100
        for _, entry in ipairs(cache) do
            if entry.hero and #entry.rows > 0 then
                local hgt = drawPanel(px, y, "fixed", entry, remainPctOf(entry.total, hp, regenHeal, maxhp), cfg, font)
                y = y + (hgt or 0) + round(6 * cfg.scale)
            end
        end
    else
        local zoom = cameraZoom()
        for _, entry in ipairs(cache) do
            local h = entry.hero
            if h and safe(Entity.IsAlive, h) and not safe(Entity.IsDormant, h) and #entry.rows > 0 then
                local hx, hy, hz = safe(Entity.GetAbsOriginXYZ, h)
                if hx then
                    local hbo = safe(NPC.GetHealthBarOffset, h) or ANCHOR_Z
                    local ax, ay, vis = worldToScreen(hx, hy, hz + hbo)
                    if ax and vis then
                        if cfg.debug then
                            safe(Render.Line, Vec2(ax - 18, ay), Vec2(ax + 18, ay), COL_DEBUG, 2)
                            safe(Render.Line, Vec2(ax, ay - 18), Vec2(ax, ay + 18), COL_DEBUG, 2)
                        end
                        drawPanel(ax + (-PANEL_GAP + cfg.moveX) * zoom, ay + cfg.moveY * zoom, "hero", entry, remainPctOf(entry.total, hp, regenHeal, maxhp), cfg, font)
                    end
                end
            end
        end
    end

    if cfg.killAlert then
        local kill, bestD2 = nil, huge
        local maxR2 = (cfg.killRange > 0) and (cfg.killRange * cfg.killRange) or nil
        for _, entry in ipairs(cache) do
            local d2 = entry.d2 or 0
            if entry.lethal and (not maxR2 or d2 <= maxR2) and d2 < bestD2 then
                bestD2 = d2
                kill = safe(Entity.GetUnitName, entry.hero) or "enemy"
            end
        end
        if kill then
            local ss = safe(Render.ScreenSize)
            local sw, sh = (ss and ss.x) or 1920, (ss and ss.y) or 1080
            local txt = "! LETHAL: " .. (kill:gsub("^npc_dota_hero_", "")) .. " can kill you"
            local fz = round(28)
            drawText(font, fz, txt, sw / 2 - textW(font, fz, txt) / 2, sh * 0.26, cfg.cLethal)
        end
    end
end

return {
    OnUpdate = function() local ok, e = pcall(onUpdate); if not ok then logErr("[IncDMG] update: " .. tostring(e)) end end,
    OnDraw   = function() local ok, e = pcall(onDraw);   if not ok then logErr("[IncDMG] draw: "   .. tostring(e)) end end,
}
