---@diagnostic disable: undefined-global, param-type-mismatch, inject-field

--[[
    Ember Spirit Sticky Combo Trainer - UCZone / Umbrella API v2.0

    STANDALONE SCRIPT
    This file does not modify or depend on Umbrella's built-in Ember script.

    AUTHORIZED TRAINING ONLY
    Automated orders are enabled only on the documented hero-demo map
    (hero_demo_main). UCZone exposes game mode and lobby JSON, but the current
    public API does not document a reliable way to prove that an arbitrary
    custom lobby contains no non-consenting human opponents. Ambiguity therefore
    fails closed: outside hero demo this script draws only its blocked status and
    never issues movement, attack, item, or ability orders.

    Verified UCZone v2.0 integration used here:
      Menu.Create / Switch / Bind / Slider / Label / Gear
      Heroes.GetLocal / Heroes.GetAll / Heroes.InRadius
      Entity.GetAbsOrigin / GetRotation / GetIndex / GetTeamNum / IsAlive / IsDormant
      Entity.IsHero / IsSameTeam / RecursiveOwnedBy / GetUnitsInRadius
      NPC.GetAbilityByIndex / GetItem / GetMana / HasModifier / HasState
      NPC.GetAttackRange / GetAttackRangeBonus / GetAttackAnimPoint
      NPC.GetSecondsPerAttack / GetMoveSpeed / IsRunning / GetTurnRate / FindRotationAngle
      NPC.HasScepter / GetHullRadius / GetTrueDamage
      NPC.GetArmorDamageMultiplier / GetMagicalArmorDamageMultiplier
      NPC.GetBarriers / IsIllusion / IsInvulnerable / IsKillable
      Ability.GetName / GetBaseName / GetLevel / IsActivated / IsCastable
      Ability.GetCastRange / GetCastPoint / GetLevelSpecialValueFor
      Ability.GetCurrentCharges / GetCooldown / SecondsSinceLastUse
      Ability.IsInAbilityPhase / CastPosition / CastNoTarget
      Player.GetActiveAbility / AttackTarget / PrepareUnitOrders
      Input.GetWorldCursorPos / GetNearestHeroToCursor / IsInputCaptured
      GlobalVars.GetCurTime / GetIntervalPerTick / GetMapName / GetMapGroupName
      GameRules.GetServerGameState / IsPaused / Engine.IsInGame
      GridNav traversability helpers
      Particle.Create / SetControlPoint / Destroy
      Render.LoadFont / Text
]]

local script = {}

local BUILD = "2026-08-25.11"
local HERO_NAME = "npc_dota_hero_ember_spirit"
local REMNANT_UNIT_NAME = "npc_dota_ember_spirit_remnant"

local ABILITY_NAME = {
    chains = "ember_spirit_searing_chains",
    sleight = "ember_spirit_sleight_of_fist",
    guard = "ember_spirit_flame_guard",
    remnant = "ember_spirit_fire_remnant",
    activate = "ember_spirit_activate_fire_remnant",
}

local MODIFIER_NAME = {
    flame_guard = "modifier_ember_spirit_flame_guard",
    sleight_in_progress = "modifier_ember_spirit_sleight_of_fist_in_progress",
    sleight_caster = "modifier_ember_spirit_sleight_of_fist_caster",
    sleight_invulnerable = "modifier_ember_spirit_sleight_of_fist_caster_invulnerability",
}

local FSM = {
    IDLE = "IDLE",
    ACQUIRE = "ACQUIRE",
    APPROACH = "APPROACH",
    GAP_CLOSE = "GAP_CLOSE",
    STICKY_FIGHT = "STICKY_FIGHT",
    TARGET_ESCAPING = "TARGET_ESCAPING",
    RECONNECT = "RECONNECT",
    KILL_SECURE = "KILL_SECURE",
    DISENGAGE = "DISENGAGE",
}

local COMBO_STAGE = {
    ACQUIRE = "ACQUIRE",
    GAP_CLOSE = "GAP_CLOSE",
    REMNANT_TRAVEL = "REMNANT_TRAVEL",
    ACTIVATE = "ACTIVATE_D",
    GUARD = "FLAME_GUARD",
    MELEE = "RIGHT_CLICKS",
    CONTROL = "SEARING_CHAINS",
    FINISH = "SLEIGHT_FINISH",
}

-- --------------------------------------------------------------------------
-- Menu: a separate native Umbrella tab with four compact cards. Advanced
-- tuning lives in gear attachments so the main panel stays uncluttered.
-- --------------------------------------------------------------------------

local SPELL_ICON = "panorama/images/spellicons/"
local ITEM_ICON = "panorama/images/items/"
local ICON = {
    chains = SPELL_ICON .. "ember_spirit_searing_chains_png.vtex_c",
    sleight = SPELL_ICON .. "ember_spirit_sleight_of_fist_png.vtex_c",
    guard = SPELL_ICON .. "ember_spirit_flame_guard_png.vtex_c",
    remnant = SPELL_ICON .. "ember_spirit_fire_remnant_png.vtex_c",
    activate = SPELL_ICON .. "ember_spirit_activate_fire_remnant_png.vtex_c",
    phase = ITEM_ICON .. "phase_boots_png.vtex_c",
    refresher = ITEM_ICON .. "refresher_png.vtex_c",
}

-- Own page, deliberately NOT nested under Umbrella's built-in "Ember Spirit"
-- entry. Menu.Create(firstTab, section, secondTab, thirdTab, group): only the
-- secondTab changes, so the path shape stays the one already known to render.
-- Keeping them apart also makes the two scripts' settings unmistakable, which
-- matters because both drive the same hero and will fight if both are enabled.
local MENU_TAB = "Ember Spirit Custom"
local general = Menu.Create("Heroes", "Hero List", MENU_TAB, "Main", "Hero Settings")
local combat = Menu.Create("Heroes", "Hero List", MENU_TAB, "Main", "Combo Abilities")
local remnants_ui = Menu.Create("Heroes", "Hero List", MENU_TAB, "Main", "Remnant Safety")
local visuals = Menu.Create("Heroes", "Hero List", MENU_TAB, "Main", "Display")

-- Icon for the Hero List entry. Menu.Create hands back the group, and only the
-- CSecondTab above it owns Image/Icon, so walk up two levels to reach it.
-- Swap MENU_ICON for any PNG to use a custom one; the FontAwesome flame is a
-- fallback because a bad image path fails silently, exactly like a bad .vpcf.
-- pcall rather than the safe() helper: safe() is declared further down and is
-- still nil this early in the chunk, so calling it here would fail at load.
local MENU_ICON = "images/heroes_circle/ember_spirit.png"
local ok_tab, menu_tab = pcall(function() return general:Parent():Parent() end)
if ok_tab and menu_tab then
    pcall(function() menu_tab:Icon("\u{f06d}") end)
    pcall(function() menu_tab:Image(MENU_ICON) end)
end

local ui = {}
ui.enabled = general:Switch("Enable Sticky Combo", true, "\u{f00c}")
ui.combo = general:Bind("Combo Key", Enum.ButtonCode.BUTTON_CODE_INVALID, "\u{f11b}")
ui.dance_combo = general:Bind("Dancing Ember Key", Enum.ButtonCode.BUTTON_CODE_INVALID, ICON.remnant)
ui.escape_key = general:Bind("Escape Key", Enum.ButtonCode.BUTTON_CODE_INVALID, "\u{f2f5}")
ui.escape_gear = ui.escape_key:Gear("Escape")
ui.escape_mode = ui.escape_gear:Combo("Escape Toward", {
    "Mouse Cursor",
    "Safest Direction",
}, 0)
ui.escape_sleight = ui.escape_gear:Switch("Sleight After Disable", true, ICON.sleight)
ui.escape_reuse = ui.escape_gear:Switch("Reuse Safer Remnant", true, ICON.remnant)
ui.escape_wait_land = ui.escape_gear:Switch("Wait For Remnant To Land", false, "\u{f017}")
ui.escape_wait_land:ToolTip("Off (default): activate the instant the Remnant is placed - the fastest possible exit, which is the entire point of an escape. On: wait for the Remnant to finish flying before dashing, which travels further but costs roughly half a second standing in danger.")
ui.escape_next_hop = ui.escape_gear:Slider("Next Hop At Travel", 50, 100, 90, "%d%%")
ui.escape_next_hop:ToolTip("How far through the current dash Ember must be before the next escape Remnant goes out. It still fires mid-flight, just late enough that the throw lands ahead of Ember rather than beside the flight path. Every escape Remnant is thrown at full cast range.")
ui.escape_max_charges = ui.escape_gear:Slider("Charges To Spend", 1, 3, 2, "%d")
ui.escape_max_charges:ToolTip("How many Fire Remnant charges a single held escape may spend before it stops. Keeps the escape from draining every charge you have.")
ui.escape_scan = ui.escape_gear:Slider("Threat Scan Radius", 600, 3000, 1600, "%d")
ui.target_mode = general:Combo("Target Mode", {
    "Free - Auto Switch",
    "Lock - First Target",
}, 0)
ui.move_to_cursor = general:Switch("Follow Cursor", true, "\u{f245}")
ui.use_items = general:Switch("Phase Boots", false, ICON.phase)
ui.allow_lobby = general:Switch("Allow Private Lobby", false, "\u{f0c0}")
ui.allow_lobby:Unsafe(true)
ui.allow_lobby:ToolTip("UNLOCKED BUILD: Script runs in ALL game modes. This switch is bypassed.")
ui.status = general:Label("Build " .. BUILD .. " [UNLOCKED]", "\u{f05a}")
pcall(function()
    ui.combo:ToolTip(
        "Hold this key for the standalone combo. Disable Umbrella's built-in Ember combo if both use the same key."
    )
end)

local targeting = ui.enabled:Gear("Targeting")
ui.normal_hover_radius = targeting:Slider("Direct Hover Radius", 80, 500, 220, "%d")
ui.lock_leash = targeting:Slider("Selection Leash", 300, 3000, 1000, "%d")
ui.lock_leash:ToolTip("How close the cursor has to be to pick a hero up, in both Target Modes, and in Lock mode how far it may drift before the lock releases. Far more forgiving than Direct Hover Radius, which only governs switching between live targets in Free mode.")
ui.max_chase = targeting:Slider("Maximum Chase", 800, 4000, 2600, "%d")

local pacing = ui.combo:Gear("Timing")
ui.update_ms = pacing:Slider("Decision Interval", 20, 100, 35, "%d ms")
ui.action_gap_ms = pacing:Slider("Ability Gap", 40, 250, 80, "%d ms")
ui.move_gap_ms = pacing:Slider("Movement Refresh", 60, 300, 110, "%d ms")
ui.attack_refresh_ms = pacing:Slider("Attack Refresh", 150, 900, 450, "%d ms")

local dancing = ui.dance_combo:Gear("Dancing Ember")
ui.dance_hop_mode = dancing:Combo("Hop Selection", {
    "Follow Cursor",
    "Nearest",
    "Farthest",
    "Lowest HP",
}, 0)
ui.dance_hop_mode:ToolTip("How the next hero in the chain is chosen. Follow Cursor hops to whoever is nearest your mouse, so you steer the route yourself. Farthest was the old behaviour - it always spends the full cast range, which is why every throw went out at maximum distance.")
ui.dance_hover_radius = dancing:Slider("Enemy Cursor Search Range", 100, 1200, 800, "%d")
ui.dance_refresher = dancing:Switch("Use Refresher Orb", false, ICON.refresher)

ui.use_remnant = combat:Switch("Fire Remnant", true, ICON.remnant)
ui.use_activate = combat:Switch("Activate Remnant", true, ICON.activate)
ui.use_guard = combat:Switch("Flame Guard", true, ICON.guard)
ui.use_chains = combat:Switch("Searing Chains", true, ICON.chains)
ui.use_sleight = combat:Switch("Sleight of Fist", true, ICON.sleight)
ui.auto_sleight_chains = combat:Switch("Auto Chains During Sleight", false, ICON.chains)
ui.kill_secure = combat:Switch("Lethal Sleight Finish", true, ICON.sleight)
ui.preload_next = combat:Switch("Preload Next Target", true, ICON.remnant)
ui.support_items = combat:Switch("Support Items", true, "\u{f0f2}")
ui.orbwalk = combat:Switch("Orbwalk", true, "\u{f554}")

-- Gear handle kept on `ui` rather than as a local: this chunk is near Lua's
-- 200-local ceiling and going over stops the script loading entirely.
-- Icon grid in the same style as Umbrella's own item panel. Only self-cast
-- (no-target) items are listed: targeted items need Ability.CastTarget, whose
-- signature is not verified here, and guessing at it is how orders end up
-- silently failing.
-- One switch per item, each carrying the real Dota item icon. A MultiSelect
-- grid was tried here and rendered broken inside a gear popup -- the label
-- overlapped the slider and the grid never drew -- so this uses the switch
-- pattern the rest of the file already relies on.
ui.support_gear = ui.support_items:Gear("Items")
ui.item_bkb = ui.support_gear:Switch("Black King Bar", true, ITEM_ICON .. "black_king_bar_png.vtex_c")
ui.item_satanic = ui.support_gear:Switch("Satanic", true, ITEM_ICON .. "satanic_png.vtex_c")
ui.item_blademail = ui.support_gear:Switch("Blade Mail", false, ITEM_ICON .. "blade_mail_png.vtex_c")
ui.item_manta = ui.support_gear:Switch("Manta Style", false, ITEM_ICON .. "manta_png.vtex_c")
ui.item_lotus = ui.support_gear:Switch("Lotus Orb", false, ITEM_ICON .. "lotus_orb_png.vtex_c")
ui.item_sphere = ui.support_gear:Switch("Linken's Sphere", false, ITEM_ICON .. "sphere_png.vtex_c")
ui.item_shivas = ui.support_gear:Switch("Shiva's Guard", true, ITEM_ICON .. "shivas_guard_png.vtex_c")
ui.item_mjollnir = ui.support_gear:Switch("Mjollnir", false, ITEM_ICON .. "mjollnir_png.vtex_c")
-- Targeted items: cast on the combo target rather than on Ember.
ui.item_orchid = ui.support_gear:Switch("Orchid / Bloodthorn", false, ITEM_ICON .. "orchid_png.vtex_c")
ui.item_solar = ui.support_gear:Switch("Solar Crest / Medallion", false, ITEM_ICON .. "solar_crest_png.vtex_c")
ui.item_atos = ui.support_gear:Switch("Rod of Atos", false, ITEM_ICON .. "rod_of_atos_png.vtex_c")
ui.item_urn = ui.support_gear:Switch("Urn / Spirit Vessel", false, ITEM_ICON .. "urn_of_shadows_png.vtex_c")
ui.item_hp_threshold = ui.support_gear:Slider("Use if HP Lower than", 10, 80, 40, "%d%%")
ui.item_smart = ui.support_gear:Switch("Smart Usage", true, "\u{f0eb}")
ui.item_smart:ToolTip("Only spend defensive items while an enemy hero is actually close enough to be a threat.")

local preload_gear = ui.preload_next:Gear("Preload")
ui.preload_range = preload_gear:Slider("Next Enemy Search Range", 400, 3000, 1800, "%d")
ui.preload_hurt = preload_gear:Slider("Counts As Hurt Below", 10, 90, 45, "%d%%")
ui.preload_hurt:ToolTip("An enemy at or below this health is treated as the kill and picked first, lowest HP winning. When nobody is that hurt, the least-farmed enemy is chosen instead - almost always the pos 4 or 5.")

local hit_and_run = ui.orbwalk:Gear("Hit & Run")
ui.orb_keep_distance = hit_and_run:Slider("Keep Distance", 0, 100, 50, "%d%%")
ui.orb_kiting = hit_and_run:Switch("Kiting", false, "\u{f70c}")
ui.orb_attack_buffer_ms = hit_and_run:Slider("Attack Ready Buffer", 0, 150, 60, "%d ms")

local prediction = ui.use_remnant:Gear("Movement Prediction")
ui.prediction = prediction:Switch("Movement Prediction", true, "\u{f1eb}")
ui.midflight_correction = prediction:Switch("Midflight Dodge Correction", true, ICON.remnant)
ui.correction_deviation = prediction:Slider("Correction Deviation", 120, 500, 220, "%d")
ui.lead_ms = prediction:Slider("Sticky Lead", 30, 300, 120, "%d ms")
ui.reconnect_no_attack_ms = prediction:Slider("Reconnect After No Attack", 500, 3000, 1500, "%d ms")

local sleight_combos = ui.auto_sleight_chains:Gear("Chains Accuracy")
ui.sleight_chains_guaranteed = sleight_combos:Switch("Require Guaranteed Target", true, "\u{f058}")

local fast_activation = ui.use_activate:Gear("Fast Activation")
ui.fast_d_delay_ms = fast_activation:Slider("D Handoff Delay", 0, 300, 70, "%d ms")

local control = ui.use_chains:Gear("Escape Control")
ui.escape_threshold = control:Slider("Escape Threshold", 45, 90, 65, "%d%%")
ui.chains_confidence = control:Slider("Chains Hit Chance", 50, 100, 80, "%d%%")
ui.chains_min_away = control:Slider("Min Escape Speed", 0, 400, 120, "%d")
ui.chains_min_away:ToolTip("How fast the target must be moving directly away from Ember before Chains is spent. 0 disables the check and lets any target out of attack range be chained, including one standing still.")

ui.avoid_fountain = remnants_ui:Switch("Never Remnant Into Fountain", true, "\u{f7e4}")
ui.avoid_fountain:Unsafe(true)
ui.avoid_fountain:ToolTip("Refuses any Fire Remnant destination inside the enemy fountain, in the combo, the dance and the escape. Dashing there is an instant death, and no routing rule is worth that.")
ui.fountain_radius = ui.avoid_fountain:Gear("Fountain"):Slider("Keep Out Radius", 800, 3000, 1600, "%d")
ui.reserve_remnants = remnants_ui:Slider("Reserved Charges", 0, 3, 1, "%d")
ui.allow_last_remnant = remnants_ui:Switch("Allow Last Remnant", false, ICON.remnant)
ui.remnant_max_enemies = remnants_ui:Slider("Destination Enemy Limit", 1, 5, 2, "%d")
ui.mana_reserve = remnants_ui:Slider("Mana Reserve", 0, 500, 75, "%d")

ui.draw_advisor = visuals:Switch("Build Advisor", true, "\u{f0eb}")
ui.draw_advisor:ToolTip("Reads the enemy lineup and the items they have actually bought, then suggests what Ember should build against it, with the reason for each. Advice only - it never buys or changes anything.")
ui.advisor_gear = ui.draw_advisor:Gear("Panel")
ui.advisor_x = ui.advisor_gear:Slider("Position X", 0, 1900, 35, "%d")
ui.advisor_y = ui.advisor_gear:Slider("Position Y", 0, 1000, 700, "%d")
ui.advisor_alpha = ui.advisor_gear:Slider("Opacity", 20, 255, 235, "%d")
ui.advisor_stage = ui.advisor_gear:Switch("Stage Aware", true, "\u{f017}")
ui.advisor_stage:ToolTip("Weights suggestions by game time: early game favours cheap survivability and farm, mid favours the first big item, late assumes full slots and switches to upgrades.")
ui.draw_route = visuals:Switch("Dance Route Preview", true, "\u{f4d7}")
ui.draw_route:ToolTip("While the Dancing Ember key is held, projects the chain the script would actually fly: numbered markers over each hero in hop order, joined by lines, drawn with the same selector the feed loop uses. What you see is what it will do.")
ui.highlight = visuals:Switch("Target Selector Particle", true, "\u{f05b}")
ui.record_demo = visuals:Switch("Record Manual Demo", false, "\u{f111}")
ui.record_demo:ToolTip("Writes every order you issue, plus Ember's position, Remnant charges and dash events, to debug.log tagged [Ember Demo]. Turn on, perform the combo by hand, turn off - the log is a full replay of what you did.")
ui.show_order_clicks = visuals:Switch("Show Order Clicks", true, "\u{f245}")
ui.show_order_clicks:ToolTip("Draws Dota's normal right-click move marker at every position the trainer orders, so orbwalk steps are visible instead of the hero sliding silently.")
ui.draw_hud = visuals:Switch("Trainer HUD", true, "\u{f06e}")
ui.debug_log = visuals:Switch("Debug Log", false, "\u{f188}")

-- Candidate selector particles. Dota silently ignores an asset a build does
-- not ship -- Particle.Create still returns a valid handle while nothing
-- draws -- so these are offered as a live dropdown to flip through in game
-- rather than hardcoding one path and hoping it renders.
local SELECTOR_PARTICLE = {
    { name = "Drag Select Ring", path = "particles/ui_mouseactions/drag_selected_ring.vpcf" },
    { name = "Selected Ring", path = "particles/ui_mouseactions/selected_ring.vpcf" },
    { name = "Select Ring", path = "particles/ui_mouseactions/select_ring.vpcf" },
    { name = "Range Display", path = "particles/ui_mouseactions/range_display.vpcf" },
    { name = "Range Finder Tower", path = "particles/ui_mouseactions/range_finder_tower_aoe.vpcf" },
    { name = "Attack Ring", path = "particles/ui_mouseactions/range_finder_attack_ring.vpcf" },
    { name = "Ping Circle", path = "particles/ui_mouseactions/ping_circle.vpcf" },
    { name = "Ground Line", path = "particles/ui_mouseactions/range_finder_ground_line.vpcf" },
    { name = "Fire Remnant Ring", path = "particles/units/heroes/hero_ember_spirit/ember_spirit_fire_remnant_tgt.vpcf" },
    { name = "Flame Guard", path = "particles/units/heroes/hero_ember_spirit/ember_spirit_flameguard.vpcf" },
    { name = "Blade Mail Ring", path = "particles/items_fx/blademail.vpcf" },
    { name = "Radiance Ring", path = "particles/items_fx/radiance_owner.vpcf" },
    { name = "Bloodstone Ring", path = "particles/items2_fx/bloodstone_status.vpcf" },
    { name = "Track Marker", path = "particles/units/heroes/hero_bounty_hunter/bounty_hunter_track_owner.vpcf" },
}

-- One reused names table and no gear locals: this chunk sits close to Lua's
-- 200-local ceiling, and exceeding it stops the whole script from loading.
local menu_names = {}
for i, entry in ipairs(SELECTOR_PARTICLE) do menu_names[i] = entry.name end

ui.selector_particle = ui.highlight:Gear("Selector Style"):Combo("Particle", menu_names, 0)
ui.selector_particle:ToolTip("Flip through these in game and keep whichever matches the Umbrella look. If one draws nothing, that asset is not shipped by this Dota build - pick the next.")

ui.target_line = visuals:Switch("Target Line", true, "\u{f546}")
ui.target_line:ToolTip("Draws a line from Ember to the selected enemy, like Umbrella's built-in target selectors.")

-- World-space beam particles look far better than a flat 2D overlay line, but
-- an asset a build does not ship draws nothing while still returning a valid
-- handle -- so these are a live dropdown, with the screen line kept as the
-- guaranteed fallback rather than the default.
local TARGET_LINE_STYLE = {
    { name = "Io Tether", path = "particles/units/heroes/hero_wisp/wisp_tether.vpcf" },
    { name = "Searing Chains", path = "particles/units/heroes/hero_ember_spirit/ember_spirit_searing_chains.vpcf" },
    { name = "Arc Lightning", path = "particles/units/heroes/hero_zuus/zuus_arc_lightning.vpcf" },
    { name = "Static Link", path = "particles/units/heroes/hero_razor/razor_static_link.vpcf" },
    { name = "Life Drain", path = "particles/units/heroes/hero_pugna/pugna_life_drain.vpcf" },
    { name = "Atos Chain", path = "particles/items2_fx/rod_of_atos_attack.vpcf" },
    { name = "Dagon Beam", path = "particles/items_fx/dagon.vpcf" },
    { name = "Flaming Lasso", path = "particles/units/heroes/hero_batrider/batrider_flaming_lasso.vpcf" },
    { name = "Meat Hook", path = "particles/units/heroes/hero_pudge/pudge_meathook.vpcf" },
    { name = "Shackleshot", path = "particles/units/heroes/hero_windrunner/windrunner_shackleshot.vpcf" },
    { name = "Glimpse Beam", path = "particles/units/heroes/hero_disruptor/disruptor_glimpse_beam.vpcf" },
    { name = "Death Ward", path = "particles/units/heroes/hero_witchdoctor/witchdoctor_death_ward_attack.vpcf" },
    { name = "Venomancer Link", path = "particles/units/heroes/hero_venomancer/venomancer_ward_attack.vpcf" },
    { name = "Viper Strike", path = "particles/units/heroes/hero_viper/viper_viper_strike.vpcf" },
    { name = "Ground Line", path = "particles/ui_mouseactions/range_finder_ground_line.vpcf" },
    { name = "Flat Screen Line", path = nil },
}

menu_names = {}
for i, entry in ipairs(TARGET_LINE_STYLE) do menu_names[i] = entry.name end

local line_style = ui.target_line:Gear("Line Style")
ui.target_line_style = line_style:Combo("Style", menu_names, 0)
ui.target_line_style:ToolTip("World-space beams first, flat screen line last. If a style draws nothing, that particle is not shipped by this Dota build - pick the next one.")
ui.target_line_width = line_style:Slider("Flat Line Thickness", 1, 6, 2, "%d")
ui.target_line_color = line_style:ColorPicker("Flat Line Color", Color(255, 105, 105, 220))

local hud_details = ui.draw_hud:Gear("HUD Details")
ui.draw_state = hud_details:Switch("Combo State", true, "\u{f00b}")
ui.draw_action = hud_details:Switch("Current Action", true, "\u{f0ae}")
ui.draw_escape = hud_details:Switch("Escape Tracking", true, "\u{f554}")
ui.draw_kill = hud_details:Switch("Kill Estimate", true, "\u{f714}")

ui.enabled:Unsafe(true)
ui.combo:Unsafe(true)
ui.dance_combo:Unsafe(true)
ui.move_to_cursor:Unsafe(true)
ui.enabled:ToolTip("Standalone hero-demo combo. Disable Umbrella's built-in Ember combo to avoid conflicting orders.")
ui.combo:ToolTip("Hold in Hero Demo to run the staged Ember combo; release stops new orders immediately.")
ui.dance_combo:ToolTip("Scepter only. This dedicated bind uses its own free target search even when the normal combo is disabled or locked.")
ui.dance_refresher:ToolTip("During Dancing Ember only, uses Refresher Orb after Fire Remnant reaches zero charges.")
ui.target_mode:ToolTip("Controls the normal combo only. Free auto-switches; Lock keeps its valid target, then immediately gap-closes the next cursor target when the lock dies or becomes invalid.")
ui.use_remnant:ToolTip("Opening gap-close. Gear contains movement prediction tuning.")
ui.midflight_correction:ToolTip("Normal combo only. If the target breaks the original prediction after D is ordered, cast one corrected R during the same Remnant travel; no second D is sent.")
ui.correction_deviation:ToolTip("How far the corrected intercept must move away from the original Remnant destination before spending another charge.")
ui.reconnect_no_attack_ms:ToolTip("Normal combo only. Recast predicted R -> D after the target stays outside Ember's real attack reach for this long.")
ui.use_activate:ToolTip("Activates the confirmed opening Remnant while outbound. Scepter uses immediate next-tick D; otherwise the gear delay applies.")
ui.use_guard:ToolTip("Requires the real Flame Guard modifier before opening right-click pressure.")
ui.use_chains:ToolTip("Casts only after fresh sustained distance gain is confirmed. Gear contains escape-control tuning.")
ui.use_sleight:ToolTip("Reserved for the selected-target lethal finish only.")
ui.auto_sleight_chains:ToolTip("Times Searing Chains for the exact Sleight jump beside the selected hero. Works for the trainer's Sleight and a manual Sleight while Combo Key is held.")
ui.sleight_chains_guaranteed:ToolTip("Searing Chains roots random units in its radius with no hero priority, so the hero is only certain when units in radius <= chain count (2/3/4/5 by level). Enabled: cast only on a certain frame, otherwise preserve Q. Disabled: hunt briefly for the cleanest frame and cast anyway - better odds in a creep wave, never a guarantee.")
ui.kill_secure:ToolTip("Finishes with Sleight only when the conservative damage check is lethal.")
ui.preload_next:ToolTip("Once the current hero is lethal to a single Sleight of Fist, park a Fire Remnant on the next enemy so the kill is followed by an instant dash. Casting R during that Sleight is intentional - Ember is displaced mid-strike, so the remnant reaches further than a standing cast. Triggers on any kill, including Umbrella's Kill Stealer.")
ui.orbwalk:ToolTip("Hit & Run: attack the locked target, move after Ember's attack point, then attack again when ready.")
ui.combo:ShowInBindIsland(true)
ui.combo:MouseBinding(true)
ui.dance_combo:ShowInBindIsland(true)
ui.dance_combo:MouseBinding(true)
ui.escape_key:ShowInBindIsland(true)
ui.escape_key:MouseBinding(true)
ui.escape_key:Unsafe(true)
ui.escape_key:ToolTip("Purely manual. Hold to escape: throws Fire Remnant toward your cursor and dashes instantly. Switch Escape Toward to Safest Direction if you would rather it pick the route away from enemy heroes and towers itself. While disabled it waits silently and fires the instant the disable ends. Never triggers on its own - not on low HP, not on being stunned, not on enemies being near.")
ui.use_items:Unsafe(true)
ui.use_chains:Unsafe(true)
ui.use_sleight:Unsafe(true)
ui.auto_sleight_chains:Unsafe(true)
ui.use_guard:Unsafe(true)
ui.kill_secure:Unsafe(true)
ui.preload_next:Unsafe(true)
ui.support_items:Unsafe(true)
ui.support_items:ToolTip("Self-cast utility items during the combo. Defensive items wait for the HP threshold; Shiva's and Mjollnir fire once the fight is joined.")
ui.use_remnant:Unsafe(true)
ui.use_activate:Unsafe(true)
ui.dance_refresher:Unsafe(true)
ui.allow_last_remnant:Unsafe(true)
ui.orbwalk:Unsafe(true)

local FONT = Render.LoadFont("Tahoma", Enum.FontCreate.FONTFLAG_ANTIALIAS, 600)

-- --------------------------------------------------------------------------
-- State
-- --------------------------------------------------------------------------

local S = {
    held = false,
    control_mode = "NONE",
    last_sleight_order_at = nil,
    dance_d_used = false,
    dance_hold_authorized = false,
    dance_last_anchor = nil,
    dance_visited_indices = {},
    -- Feed-loop state. The recorded manual combo is ONE D followed by a stream
    -- of R casts that keep a remnant permanently ahead of Ember.
    dance_chain_idle_since = nil,
    dance_idle_pos = nil,
    dance_last_move_at = nil,
    dance_last_progress_at = nil,
    hero_motion = {},
    motion_last_sample = 0,

    escape_phase = "IDLE",
    escape_destination = nil,
    escape_order_at = -100,
    escape_charges_before = -1,
    escape_attempts = 0,
    escape_was_blocked = false,
    escape_blocked_reason = nil,
    escape_sleight_at = -100,
    escape_cooldown_until = -100,
    escape_spent = 0,
    escape_counted = false,
    escape_dash_from = nil,
    escape_dash_to = nil,
    dance_last_feed_at = -100,
    dance_last_fed_index = -1,
    dance_last_refresher_at = -100,
    last_dance_hold_at = -100,
    hold_epoch = 0,
    target_epoch = 0,
    map_epoch = 0,
    last_map = "",

    gate_allowed = false,
    gate_reason = "not checked",
    gate_checked_at = -100,

    hero = nil,
    player = nil,
    target = nil,
    target_index = -1,
    target_score = nil,
    target_since = 0,
    switch_candidate = nil,
    switch_candidate_since = 0,
    target_mode = 0,
    lock_consumed = false,
    locked_target_index = -1,

    fsm = FSM.IDLE,
    fsm_since = 0,
    disengage_until = 0,
    action = "NONE",
    reason = "idle",
    zone = "NONE",
    combo_stage = COMBO_STAGE.ACQUIRE,
    engagement_started = false,
    opening_remnant_committed = false,
    guard_stage_completed = false,
    guard_cast_at = -100,
    guard_confirmed_at = -100,
    post_guard_attack_orders = 0,
    opening_attack_confirm_at = -100,
    opening_pressure_completed = false,
    sleight_handoff = nil,
    preload = nil,
    sleight_chain = nil,
    sleight_kill_committed_index = -1,
    last_reconnect_remnant_at = -100,
    attack_contact_lost_since = nil,

    abilities = {},
    abilities_scanned_at = -100,

    history = {},
    history_target_index = -1,
    last_history_sample = 0,
    velocity = nil,
    recent_velocity = nil,
    velocity_confidence = 0,
    motion_coherence = 0,
    motion_residual = 0,
    motion_turn_until = 0,
    distance_slope = 0,
    radial_away_speed = 0,
    distance_gain_since = nil,
    distance_gain_latched = false,
    major_displacement_until = 0,
    escape_score = 0,
    escape_latched = false,
    escape_high_since = nil,
    escape_low_since = nil,

    remnants = {},
    remnants_scanned_at = -100,
    measured_remnant_speed = nil,
    remnant_sample_at = 0,
    last_remnant_order_at = nil,
    measured_cast_point = nil,
    advice = nil,
    advice_at = -100,
    advice_stage = "MID",
    advice_minutes = 0,
    tx = nil,

    highlight_particle = nil,
    highlight_particle_path = nil,
    line_particle = nil,
    line_particle_path = nil,
    line_target_index = -1,

    demo_started_at = nil,
    demo_last_sample = 0,
    demo_last_pos = nil,
    demo_last_charges = -1,
    demo_last_remnants = -1,
    demo_order_names = nil,
    highlight_arrow_particle = nil,
    highlight_target_index = -1,
    highlight_target = nil,

    last_update = 0,
    last_clock = 0,
    last_action = 0,
    last_ability = 0,
    last_move = 0,
    last_attack = 0,
    last_attack_target = -1,
    attack_ready_at = 0,
    next_attack = 0,
    move_after = 0,
    phase_walk_until = 0,
    last_move_position = nil,
    last_dedupe_key = nil,
    last_log = "",
    last_log_at = -100,
    last_status = "",
    kill_estimate = "not evaluated",
    sleight_role = "SAVED",
}

-- --------------------------------------------------------------------------
-- Small safe/math helpers
-- --------------------------------------------------------------------------

local function safe(call, fallback)
    local ok, value = pcall(call)
    if ok and value ~= nil then return value end
    return fallback
end

local function now()
    return safe(function() return GlobalVars.GetCurTime() end, 0)
end

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function vec(x, y, z)
    return Vector(x or 0, y or 0, z or 0)
end

local function add(a, b)
    return vec(a.x + b.x, a.y + b.y, (a.z or 0) + (b.z or 0))
end

local function sub(a, b)
    return vec(a.x - b.x, a.y - b.y, (a.z or 0) - (b.z or 0))
end

local function mul(a, scalar)
    return vec(a.x * scalar, a.y * scalar, (a.z or 0) * scalar)
end

local function dot2d(a, b)
    return a.x * b.x + a.y * b.y
end

local function length2d(a)
    return math.sqrt(a.x * a.x + a.y * a.y)
end

local function distance2d(a, b)
    return length2d(sub(a, b))
end

local function normalize2d(a)
    local length = length2d(a)
    if length < 0.001 then return vec(0, 0, 0), 0 end
    return vec(a.x / length, a.y / length, 0), length
end

local function clamp_vector_length(a, maximum)
    local direction, length = normalize2d(a)
    if length <= maximum then return a end
    return mul(direction, maximum)
end

local function ground_position(position)
    local z = safe(function() return World.GetGroundZ(position.x, position.y) end, position.z or 0)
    return vec(position.x, position.y, z)
end

local function entity_index(entity)
    if not entity then return -1 end
    return safe(function() return Entity.GetIndex(entity) end, -1)
end

local function entity_alive(entity)
    return entity ~= nil and safe(function() return Entity.IsAlive(entity) end, false)
end

local function origin(entity)
    return safe(function() return Entity.GetAbsOrigin(entity) end, nil)
end

local function same_entity(a, b)
    if not a or not b then return false end
    local ai, bi = entity_index(a), entity_index(b)
    return ai >= 0 and ai == bi
end

local function log_decision(message)
    S.reason = message
    if not ui.debug_log:Get() then return end
    local time = now()
    if message ~= S.last_log or time - S.last_log_at >= 1.0 then
        Log.Write("[Ember Sticky] " .. message)
        S.last_log = message
        S.last_log_at = time
    end
end

local function set_status(message)
    if message == S.last_status then return end
    S.last_status = message
    safe(function() ui.status:ForceLocalization("Status: " .. message) end, nil)
end

local builtin_enable_widget = nil
local builtin_combo_widget = nil

local function valid_bind_key(key)
    return key ~= nil
        and key ~= Enum.ButtonCode.BUTTON_CODE_INVALID
        and key ~= Enum.ButtonCode.KEY_NONE
end

local function bind_assigned(bind)
    return valid_bind_key(safe(function() return bind:Get(0) end, nil))
        or valid_bind_key(safe(function() return bind:Get(1) end, nil))
end

-- Dancing Ember helpers and action proposals live on these tables rather than
-- as top-level locals. Lua caps a function at 200 locals and this chunk sat
-- against that ceiling -- exceeding it stops the whole script from loading,
-- with a single line in debug.log to say why. Table fields cost nothing.
local dance = {}
local plan = {}

local function combo_bind_assigned()
    return bind_assigned(ui.combo)
end

function dance.bind_assigned()
    return bind_assigned(ui.dance_combo)
end

local function bind_is_down(bind)
    return safe(function() return bind:IsDown() end, false)
end

local function builtin_combo_key_conflict()
    if not builtin_enable_widget then
        builtin_enable_widget = safe(function()
            return Menu.Find(
                "Heroes", "Hero List", "Ember Spirit", "Main Settings", "Hero Settings", "Enable"
            )
        end, nil)
    end
    if not builtin_combo_widget then
        builtin_combo_widget = safe(function()
            return Menu.Find(
                "Heroes", "Hero List", "Ember Spirit", "Main Settings", "Hero Settings", "Combo Key"
            )
        end, nil)
    end
    if not builtin_enable_widget or not builtin_combo_widget
        or not safe(function() return builtin_enable_widget:Get() end, false) then return false end

    for custom_index = 0, 1 do
        local custom_key = safe(function() return ui.combo:Get(custom_index) end, nil)
        if valid_bind_key(custom_key) then
            for builtin_index = 0, 1 do
                local builtin_key = safe(function() return builtin_combo_widget:Get(builtin_index) end, nil)
                if valid_bind_key(builtin_key) and custom_key == builtin_key then return true end
            end
        end
    end
    return false
end

-- --------------------------------------------------------------------------
-- Training authorization and lifecycle
-- --------------------------------------------------------------------------

local function evaluate_training_gate(time)
    S.gate_allowed = true
    S.gate_reason = "UNLOCKED - all modes enabled"
    S.gate_checked_at = time
    return true, S.gate_reason
end

local function get_local_ember()
    local hero = safe(function() return Heroes.GetLocal() end, nil)
    if not hero or not entity_alive(hero) then return nil end
    local name = safe(function() return NPC.GetUnitName(hero) end, "")
    if name ~= HERO_NAME then return nil end
    return hero
end

local function destroy_highlight()
    if S.highlight_particle ~= nil then
        safe(function() Particle.Destroy(S.highlight_particle) end, nil)
        S.highlight_particle = nil
    end
    if S.highlight_arrow_particle ~= nil then
        safe(function() Particle.Destroy(S.highlight_arrow_particle) end, nil)
        S.highlight_arrow_particle = nil
    end
    S.highlight_target_index = -1
    S.highlight_target = nil
    S.highlight_particle_path = nil
    -- The target beam is owned by the same selection, so it must never outlive
    -- it -- a stray tether left attached to a dead target looks broken.
    if S.line_particle ~= nil then
        safe(function() Particle.Destroy(S.line_particle) end, nil)
        S.line_particle = nil
    end
    S.line_particle_path = nil
    S.line_target_index = -1
end

local function clear_target_history()
    S.history = {}
    S.history_target_index = -1
    S.last_history_sample = 0
    S.velocity = vec(0, 0, 0)
    S.recent_velocity = vec(0, 0, 0)
    S.velocity_confidence = 0
    S.motion_coherence = 0
    S.motion_residual = 0
    S.motion_turn_until = 0
    S.distance_slope = 0
    S.radial_away_speed = 0
    S.distance_gain_since = nil
    S.distance_gain_latched = false
    S.major_displacement_until = 0
    S.escape_score = 0
    S.escape_latched = false
    S.escape_high_since = nil
    S.escape_low_since = nil
end

local function committed_remnant_transaction()
    return S.tx
        and S.tx.kind == "REMNANT"
end

local function clear_target()
    local preserve_tx = committed_remnant_transaction() and S.tx or nil
    local had_context = S.target ~= nil or S.target_index >= 0 or S.tx ~= nil
    S.target = nil
    S.target_index = -1
    S.target_score = nil
    S.target_since = 0
    S.switch_candidate = nil
    S.switch_candidate_since = 0
    if not preserve_tx then
        S.combo_stage = COMBO_STAGE.ACQUIRE
        S.engagement_started = false
        S.opening_remnant_committed = false
        S.guard_stage_completed = false
        S.guard_cast_at = -100
        S.guard_confirmed_at = -100
        S.post_guard_attack_orders = 0
        S.opening_attack_confirm_at = -100
        S.opening_pressure_completed = false
        S.attack_contact_lost_since = nil
        S.last_move_position = nil
        S.move_after = 0
        S.next_attack = 0
    end
    if had_context then S.target_epoch = S.target_epoch + 1 end
    S.tx = preserve_tx
    clear_target_history()
    destroy_highlight()
end

local function set_fsm(next_state, time)
    if S.fsm == next_state then return end
    S.fsm = next_state
    S.fsm_since = time
end

local function hard_reset(reason)
    if S.held then S.hold_epoch = S.hold_epoch + 1 end
    S.held = false
    S.control_mode = "NONE"
    S.dance_d_used = false
    S.dance_hold_authorized = false
    S.dance_last_anchor = nil
    S.dance_visited_indices = {}
    S.last_dance_hold_at = -100
    S.tx = nil
    S.action = "NONE"
    S.zone = "NONE"
    S.disengage_until = 0
    S.last_dedupe_key = nil
    S.last_move_position = nil
    S.last_attack_target = -1
    S.attack_ready_at = 0
    S.next_attack = 0
    S.move_after = 0
    S.phase_walk_until = 0
    S.sleight_handoff = nil
    S.preload = nil
    S.sleight_chain = nil
    S.sleight_kill_committed_index = -1
    S.last_reconnect_remnant_at = -100
    S.attack_contact_lost_since = nil
    clear_target()
    S.lock_consumed = false
    S.locked_target_index = -1
    S.target_mode = safe(function() return ui.target_mode:Get() end, 0)
    set_fsm(FSM.IDLE, now())
    if reason then log_decision(reason) end
end

local function reset_session_cache()
    S.gate_allowed = false
    S.gate_reason = "not checked"
    S.gate_checked_at = -100
    S.abilities = {}
    S.abilities_scanned_at = -100
    S.remnants = {}
    S.remnants_scanned_at = -100
    S.last_update = -100
    S.last_action = -100
    S.last_ability = -100
    S.last_move = -100
    S.last_attack = -100
    S.attack_ready_at = 0
    S.next_attack = 0
    S.move_after = 0
    S.phase_walk_until = 0
    S.disengage_until = 0
    S.last_move_position = nil
    S.last_attack_target = -1
    S.last_clock = 0
    S.last_log = ""
    S.last_log_at = -100
end

local function detect_map_change()
    local map = safe(function() return GlobalVars.GetMapName() end, "")
    if map ~= S.last_map then
        S.last_map = map
        S.map_epoch = S.map_epoch + 1
        S.gate_checked_at = -100
        hard_reset("map changed")
        reset_session_cache()
    end
end

-- --------------------------------------------------------------------------
-- Ability and item helpers
-- --------------------------------------------------------------------------

local function refresh_abilities(hero, time)
    if time - S.abilities_scanned_at < 0.40 and next(S.abilities) ~= nil then return end
    S.abilities_scanned_at = time
    local found = {}
    for i = 0, 25 do
        local ability = safe(function() return NPC.GetAbilityByIndex(hero, i) end, nil)
        if ability then
            local name = safe(function() return Ability.GetName(ability) end, "")
            local base = safe(function() return Ability.GetBaseName(ability) end, "")
            for key, wanted in pairs(ABILITY_NAME) do
                if name == wanted or base == wanted then found[key] = ability end
            end
        end
    end
    S.abilities = found
end

local function special(ability, names, fallback)
    if not ability then return fallback end
    for _, name in ipairs(names) do
        local value = safe(function() return Ability.GetLevelSpecialValueFor(ability, name, -1) end, nil)
        if type(value) == "number" and value > 0 then return value end
    end
    return fallback
end

local function cast_range(hero, ability, fallback)
    if not ability then return fallback end
    local range = safe(function() return Ability.GetCastRange(ability) end, fallback)
    local bonus = safe(function() return NPC.GetCastRangeBonus(hero) end, 0)
    if type(range) ~= "number" or range <= 0 then range = fallback end
    return math.max(0, range + math.max(0, bonus or 0))
end

local function has_remnant_scepter_upgrade(hero, remnant)
    if safe(function() return NPC.HasScepter(hero) end, false) then return true end
    local modifiers = {
        "modifier_item_ultimate_scepter",
        "modifier_item_ultimate_scepter_consumed",
        "modifier_item_ultimate_scepter_consumed_alchemist",
    }
    for _, modifier_name in ipairs(modifiers) do
        if safe(function() return NPC.HasModifier(hero, modifier_name) end, false) then return true end
    end

    -- Some API builds expose the upgraded range before HasScepter updates.
    local current_range = safe(function() return Ability.GetCastRange(remnant) end, 1400)
    local scepter_range = special(remnant, { "scepter_range" }, 3000)
    return current_range >= scepter_range - 50
end

local function ability_usable(hero, ability, reserve)
    if not ability then return false end
    local level = safe(function() return Ability.GetLevel(ability) end, 0)
    if level <= 0 then return false end
    if not safe(function() return Ability.IsActivated(ability) end, true) then return false end
    local mana = safe(function() return NPC.GetMana(hero) end, 0)
    local mana_cost = safe(function() return Ability.GetManaCost(ability) end, 0)
    if mana - mana_cost < (reserve or 0) then return false end
    return safe(function() return Ability.IsCastable(ability, mana) end, false)
end

-- Activate Fire Remnant is a linked, non-learnable sub-ability. Some API
-- builds can report its own level late even though Fire Remnant is learned, so
-- use the parent spell as the level authority while retaining every live
-- activation, mana, and castability check.
local function activate_usable(hero, ability, reserve)
    if not ability then return false end
    local level = safe(function() return Ability.GetLevel(ability) end, 0)
    if level <= 0 then
        level = safe(function() return Ability.GetLevel(S.abilities.remnant) end, 0)
    end
    if level <= 0 then return false end
    if not safe(function() return Ability.IsActivated(ability) end, false) then return false end
    local mana = safe(function() return NPC.GetMana(hero) end, 0)
    local mana_cost = safe(function() return Ability.GetManaCost(ability) end, 0)
    if mana - mana_cost < (reserve or 0) then return false end
    return safe(function() return Ability.IsCastable(ability, mana) end, false)
end

-- A committed Dancing Ember transaction may reach D before UCZone's linked
-- sub-ability flags have refreshed. Allow the fast order once R is confirmed;
-- the transaction then verifies the real D cast/travel signal and retries a
-- rejected early order instead of assuming pcall success means game success.
local function committed_dance_activate_ready(hero, ability, reserve)
    if not hero or not ability then return false end
    local parent_level = safe(function()
        return Ability.GetLevel(S.abilities.remnant)
    end, 0)
    if parent_level <= 0 then return false end
    if safe(function() return NPC.IsStunned(hero) end, false)
        or safe(function() return NPC.IsSilenced(hero) end, false)
        or safe(function()
            return NPC.HasState(hero, Enum.ModifierState.MODIFIER_STATE_HEXED)
        end, false) then return false end
    local mana = safe(function() return NPC.GetMana(hero) end, 0)
    local mana_cost = safe(function() return Ability.GetManaCost(ability) end, 0)
    return mana - mana_cost >= (reserve or 0)
end

local function ability_recently_used(ability, maximum_age)
    if not ability then return false end
    local age = safe(function() return Ability.SecondsSinceLastUse(ability) end, -1)
    return type(age) == "number" and age >= 0 and age <= maximum_age
end

local function sleight_in_progress(hero)
    if not entity_alive(hero) then return false end
    if safe(function() return NPC.HasModifier(hero, MODIFIER_NAME.sleight_in_progress) end, false)
        or safe(function() return NPC.HasModifier(hero, MODIFIER_NAME.sleight_caster) end, false)
        or safe(function() return NPC.HasModifier(hero, MODIFIER_NAME.sleight_invulnerable) end, false) then
        return true
    end
    -- debug.log confirmed a live manual Sleight cast where modifier names,
    -- OUT_OF_GAME, IsInvulnerable, IsChannellingAbility, IsKillable, and even
    -- Ability.SecondsSinceLastUse were ALL silent for its entire duration --
    -- likely because hero-demo/practice maps commonly zero ability cooldowns,
    -- which makes SecondsSinceLastUse report -1 ("not on cooldown") the
    -- instant the ability is cast. S.last_sleight_order_at is stamped directly
    -- from the OnPrepareUnitOrders callback below, which fires on the real
    -- order regardless of cooldown/mana state, so it is the primary signal.
    if S.last_sleight_order_at and now() - S.last_sleight_order_at <= 2.2 then
        return true
    end
    return ability_recently_used(S.abilities.sleight, 2.2)
end

local function sleight_chains_ready(hero, chains)
    if not entity_alive(hero) or not chains then return false end
    if safe(function() return Ability.GetLevel(chains) end, 0) <= 0 then return false end
    if safe(function() return NPC.IsStunned(hero) end, false)
        or safe(function() return NPC.IsSilenced(hero) end, false)
        or safe(function()
            return NPC.HasState(hero, Enum.ModifierState.MODIFIER_STATE_HEXED)
        end, false) then return false end
    local mana = safe(function() return NPC.GetMana(hero) end, 0)
    local cost = safe(function() return Ability.GetManaCost(chains) end, math.huge)
    local cooldown = safe(function() return Ability.GetCooldown(chains) end, math.huge)
    return mana - cost >= ui.mana_reserve:Get() and cooldown <= 0.03
end

local function flame_guard_active(hero)
    return safe(function() return NPC.HasModifier(hero, MODIFIER_NAME.flame_guard) end, false)
end

local function hero_can_act(hero)
    if not entity_alive(hero) then return false end
    if safe(function() return NPC.IsStunned(hero) end, false) then return false end
    if safe(function() return NPC.HasState(hero, Enum.ModifierState.MODIFIER_STATE_OUT_OF_GAME) end, false) then return false end
    if safe(function() return NPC.IsChannellingAbility(hero) end, false) then return false end
    return true
end

local function hero_can_cast(hero)
    if not hero_can_act(hero) then return false end
    if safe(function() return NPC.IsSilenced(hero) end, false) then return false end
    if safe(function() return NPC.HasState(hero, Enum.ModifierState.MODIFIER_STATE_HEXED) end, false) then return false end
    if safe(function() return NPC.HasState(hero, Enum.ModifierState.MODIFIER_STATE_OUT_OF_GAME) end, false) then return false end
    return true
end

-- --------------------------------------------------------------------------
-- Target selection and highlight
-- --------------------------------------------------------------------------

local function valid_target(hero, target)
    if not hero or not target then return false end
    if not safe(function() return Entity.IsHero(target) end, false) then return false end
    if not entity_alive(target) then return false end
    if safe(function() return Entity.IsSameTeam(hero, target) end, true) then return false end
    if safe(function() return Entity.IsDormant(target) end, true) then return false end
    if safe(function() return NPC.IsIllusion(target) end, false) then return false end
    if safe(function() return NPC.IsInvulnerable(target) end, false) then return false end
    if not safe(function() return NPC.IsKillable(target) end, true) then return false end
    if safe(function() return NPC.HasState(target, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE) end, false) then return false end
    if safe(function() return NPC.HasState(target, Enum.ModifierState.MODIFIER_STATE_OUT_OF_GAME) end, false) then return false end
    return origin(target) ~= nil
end

local function target_score(hero, target, cursor)
    local target_pos = origin(target)
    if not hero or not target_pos or not cursor then return math.huge end
    -- Selection is intentionally pure cursor distance. Hero range and HP must
    -- never bias ownership away from the enemy the mouse is visibly over.
    return distance2d(cursor, target_pos)
end

local function best_cursor_target(hero, cursor)
    local team = safe(function() return Entity.GetTeamNum(hero) end, nil)
    if team == nil then return nil, math.huge end
    local candidate = safe(function()
        return Input.GetNearestHeroToCursor(team, Enum.TeamType.TEAM_ENEMY)
    end, nil)
    if not valid_target(hero, candidate) then return nil, math.huge end

    local candidate_pos, hero_pos = origin(candidate), origin(hero)
    if not candidate_pos or not hero_pos then return nil, math.huge end
    if distance2d(cursor, candidate_pos) > ui.normal_hover_radius:Get()
        or distance2d(hero_pos, candidate_pos) > ui.max_chase:Get() then
        return nil, math.huge
    end
    return candidate, target_score(hero, candidate, cursor)
end

local function best_other_combo_target(hero, cursor, excluded_index)
    local hero_pos = origin(hero)
    if not hero_pos or not cursor then return nil, math.huge end
    local best, best_score = nil, math.huge
    local heroes = safe(function() return Heroes.GetAll() end, {})
    for _, candidate in pairs(heroes) do
        if valid_target(hero, candidate)
            and entity_index(candidate) ~= excluded_index then
            local candidate_pos = origin(candidate)
            if candidate_pos
                and distance2d(hero_pos, candidate_pos) <= ui.max_chase:Get() then
                local score = target_score(hero, candidate, cursor)
                if score < best_score then
                    best, best_score = candidate, score
                end
            end
        end
    end
    return best, best_score
end

local function selected_target_mode()
    local mode = safe(function() return ui.target_mode:Get() end, 0)
    return mode == 1 and 1 or 0
end

local function selected_particle_path()
    local index = safe(function() return ui.selector_particle:Get() end, 0)
    local entry = SELECTOR_PARTICLE[(index or 0) + 1] or SELECTOR_PARTICLE[1]
    return entry.path
end

local function create_highlight(target)
    destroy_highlight()
    if not ui.highlight:Get() or not target then return end
    if not origin(target) then return end

    -- Attach the particle to the selected entity at creation, then set its
    -- color and radius control points. Some assets return valid handles on a
    -- given build while silently drawing nothing, which is why the style is a
    -- live dropdown and the 2D screen fallback in OnDraw always stays on.
    local path = selected_particle_path()
    local ring = safe(function()
        return Particle.Create(
            path,
            Enum.ParticleAttachment.PATTACH_ABSORIGIN_FOLLOW,
            target
        )
    end, nil)
    if ring ~= nil then
        safe(function() Particle.SetControlPoint(ring, 1, Vector(255, 105, 105)) end, nil)
        safe(function() Particle.SetControlPoint(ring, 2, Vector(92, 255, 255)) end, nil)
        safe(function() Particle.SetShouldDraw(ring, true) end, nil)
        S.highlight_particle = ring
    end

    if ring ~= nil then
        S.highlight_particle_path = path
        S.highlight_target_index = entity_index(target)
        S.highlight_target = target
    end
end

local function set_target(target, score, time)
    local index = entity_index(target)
    if index < 0 then return end
    if index ~= S.target_index then
        S.target = target
        S.target_index = index
        S.target_score = score
        S.target_since = time
        S.target_epoch = S.target_epoch + 1
        S.tx = nil
        S.combo_stage = COMBO_STAGE.ACQUIRE
        S.engagement_started = false
        S.opening_remnant_committed = false
        S.guard_stage_completed = false
        S.guard_cast_at = -100
        S.guard_confirmed_at = -100
        S.post_guard_attack_orders = 0
        S.opening_attack_confirm_at = -100
        S.opening_pressure_completed = false
        S.attack_contact_lost_since = nil
        S.last_attack_target = -1
        S.last_attack = 0
        S.attack_ready_at = 0
        S.next_attack = 0
        S.move_after = 0
        S.last_move_position = nil
        if selected_target_mode() == 1 then
            S.lock_consumed = true
            S.locked_target_index = index
        end
        clear_target_history()
        create_highlight(target)
        set_fsm(FSM.ACQUIRE, time)
        log_decision("TARGET: " .. safe(function() return NPC.GetUnitName(target) end, tostring(index)))
    else
        S.target = target
        S.target_score = score
    end
end

local function sync_highlight()
    if not ui.highlight:Get() then
        destroy_highlight()
        return
    end
    if valid_target(S.hero, S.target) then
        if S.highlight_particle == nil
            or S.highlight_target_index ~= S.target_index
            -- Rebuild immediately when the style dropdown changes so the new
            -- particle can be judged in game without reselecting a target.
            or S.highlight_particle_path ~= selected_particle_path() then
            create_highlight(S.target)
        else
            if S.highlight_particle ~= nil then
                safe(function() Particle.SetControlPoint(S.highlight_particle, 1, Vector(255, 105, 105)) end, nil)
                safe(function() Particle.SetControlPoint(S.highlight_particle, 2, Vector(92, 255, 255)) end, nil)
                safe(function() Particle.SetShouldDraw(S.highlight_particle, true) end, nil)
            end
        end
    else
        destroy_highlight()
    end
end

function dance.enemy_under_cursor(hero, cursor)
    if not hero or not cursor then return nil end
    local team = safe(function() return Entity.GetTeamNum(hero) end, nil)
    if team == nil then return nil end
    local candidate = safe(function()
        return Input.GetNearestHeroToCursor(team, Enum.TeamType.TEAM_ENEMY)
    end, nil)
    if not valid_target(hero, candidate) then return nil end
    local candidate_pos = origin(candidate)
    if not candidate_pos
        or distance2d(cursor, candidate_pos) > ui.dance_hover_radius:Get() then return nil end
    return candidate
end

-- Refresher Orb and Refresher Shard are separate items and both restore Fire
-- Remnant, so the dance path has to accept either one. The list is inlined
-- rather than a top-level local because this chunk is near Lua's 200-local cap.
local function find_refresher(hero)
    for _, item_name in ipairs({ "item_refresher", "item_refresher_shard" }) do
        local item = safe(function() return NPC.GetItem(hero, item_name, true) end, nil)
        if item and ability_usable(hero, item, 0) then return item end
    end
    return nil
end

function dance.chain_effective_hp(target)
    local hp = safe(function() return Entity.GetHealth(target) end, math.huge)
    local barriers = safe(function() return NPC.GetBarriers(target) end, {})
    local magical = type(barriers.magic) == "table" and (barriers.magic.current or 0) or 0
    local universal = type(barriers.all) == "table" and (barriers.all.current or 0) or 0
    local multiplier = math.max(0.05, safe(function()
        return NPC.GetMagicalArmorDamageMultiplier(target)
    end, 0.75))
    return (hp + magical + universal) / multiplier
end

function dance.chain_cast_range(hero)
    local remnant = S.abilities.remnant
    local bonus = safe(function() return NPC.GetCastRangeBonus(hero) end, 0)
    return math.max(
        cast_range(hero, remnant, 1400),
        special(remnant, { "scepter_range" }, 3000) + math.max(0, bonus)
    )
end

function dance.chain_target(hero, anchor_position, previous_index, visited_indices)
    local planning_origin = anchor_position or origin(hero)
    if not planning_origin then return nil, false, false end
    local full_scepter_range = dance.chain_cast_range(hero)
    -- Heroes.InRadius centered on Ember is unreliable during Activate travel:
    -- the entity origin can remain at an old endpoint while Ember is out of
    -- game. Scan heroes and measure from the last confirmed Remnant destination,
    -- which is the origin of the next logical bounce.
    local enemies = safe(function() return Heroes.GetAll() end, {})
    -- 0 Follow Cursor, 1 Nearest, 2 Farthest, 3 Lowest HP. Every mode is scored
    -- as "lower is better" so one comparison covers all of them. Farthest was
    -- the old hardcoded rule, and it is what made every hop spend the full cast
    -- range regardless of where the enemy actually was.
    local mode = safe(function() return ui.dance_hop_mode:Get() end, 0)
    local cursor = mode == 0
        and safe(function() return Input.GetWorldCursorPos() end, nil) or nil

    local function choose(require_unvisited)
        local best, best_score = nil, math.huge
        for _, enemy in pairs(enemies) do
            local index = entity_index(enemy)
            local already_visited = visited_indices and visited_indices[index] == true
            if valid_target(hero, enemy)
                and index ~= previous_index
                and (not require_unvisited or not already_visited) then
                local enemy_pos = origin(enemy)
                local distance = enemy_pos and distance2d(planning_origin, enemy_pos) or math.huge
                -- Reachability is not negotiable in any mode: a hop beyond cast
                -- range is simply not a legal hop.
                if distance > full_scepter_range + 25 then goto continue end
                local score
                if mode == 2 then
                    score = -distance
                elseif mode == 3 then
                    score = dance.chain_effective_hp(enemy)
                elseif mode == 0 and cursor and enemy_pos then
                    score = distance2d(cursor, enemy_pos)
                else
                    score = distance
                end
                if score < best_score then
                    best, best_score = enemy, score
                end
            end
            ::continue::
        end
        return best
    end

    -- First exhaust every reachable, not-yet-visited hero. Only when that pass
    -- is complete may another pass begin, still excluding the immediately
    -- previous hop. The visited table persists for the whole held dance key,
    -- including across separate R -> D transactions and Refresher cycles.
    local best = choose(true)
    if best then return best, false, false end
    best = choose(false)
    return best, false, best ~= nil
end

-- During a committed dance transaction target changes are visual ownership
-- only. They must not erase the active one-D travel pipeline.
local function set_dance_visual_target(target, cursor, time)
    if not valid_target(S.hero, target) then return false end
    local index = entity_index(target)
    if index < 0 then return false end
    if index ~= S.target_index then
        S.target = target
        S.target_index = index
        S.target_epoch = S.target_epoch + 1
        S.target_since = time
        create_highlight(target)
    else
        S.target = target
    end
    S.target_score = target_score(S.hero, target, cursor)
    return true
end

local function update_target_lock(hero, cursor, time)
    local mode = selected_target_mode()
    local current_valid = valid_target(hero, S.target)

    if mode ~= S.target_mode then
        S.target_mode = mode
        S.switch_candidate = nil
        S.switch_candidate_since = 0
        if mode == 1 and current_valid then
            S.lock_consumed = true
            S.locked_target_index = S.target_index
        else
            S.lock_consumed = false
            S.locked_target_index = -1
        end
    end

    if mode == 1 then
        if current_valid then
            -- Lock mode ignores switch scores entirely: the locked hero owns
            -- the combo. The cursor only matters as a leash -- drift far
            -- enough away and the lock releases, which is how you disengage
            -- without releasing the key. Anywhere inside it, keep comboing.
            local locked_pos = origin(S.target)
            local strayed = locked_pos and cursor
                and distance2d(cursor, locked_pos) > ui.lock_leash:Get()
            if not strayed then
                S.lock_consumed = true
                S.locked_target_index = S.target_index
                S.target_score = target_score(hero, S.target, cursor)
                S.switch_candidate = nil
                S.switch_candidate_since = 0
                return
            end
            log_decision("LOCK RELEASED: cursor drifted outside the leash")
            current_valid = false
        end

        if S.target ~= nil or S.target_index >= 0 then clear_target() end
        -- A lock owns one living/valid hero, not an obsolete entity index.
        -- Re-arm immediately when that hero dies or becomes invalid so the
        -- same held combo can acquire the next cursor-selected enemy.  The
        -- fresh target reset sends the normal planner straight back through
        -- its Remnant gap-close stage when that enemy is outside sticky range.
        S.lock_consumed = false
        S.locked_target_index = -1
        -- Acquire on the leash, not the tight Direct Hover Radius. Requiring
        -- the cursor almost on top of a hero is what made locking feel fussy;
        -- the nearest enemy to the cursor inside the leash is what was meant.
        local first, first_score = best_cursor_target(hero, cursor)
        if not first then
            local candidate, candidate_score = best_other_combo_target(hero, cursor, -1)
            local candidate_pos = candidate and origin(candidate) or nil
            if candidate_pos and cursor
                and distance2d(cursor, candidate_pos) <= ui.lock_leash:Get() then
                first, first_score = candidate, candidate_score
            end
        end
        if first then set_target(first, first_score, time) end
        return
    end

    S.lock_consumed = false
    S.locked_target_index = -1
    local best, best_score = best_cursor_target(hero, cursor)

    -- Free mode means direct mouse ownership: a newly hovered enemy replaces
    -- the old target immediately. Dwell/margin hysteresis made the selector
    -- visibly lag behind the cursor and could send attacks to the prior hero.
    if best and not same_entity(best, S.target) then
        set_target(best, best_score, time)
        S.switch_candidate = nil
        S.switch_candidate_since = 0
        return
    end

    if current_valid then
        local current_pos, hero_pos = origin(S.target), origin(hero)
        if not current_pos or not hero_pos
            or distance2d(hero_pos, current_pos) > ui.max_chase:Get() then
            current_valid = false
        end
    end

    if not current_valid then
        clear_target()
        if not best then
            -- Forgiving ACQUISITION: the enemy nearest the cursor inside the
            -- leash. Requiring the mouse within Direct Hover Radius to pick a
            -- target up at all is what made the combo look stalled whenever
            -- the cursor was not sitting on a hero. Switching between live
            -- targets above still uses the tight radius, so a wide leash here
            -- cannot cause the selector to thrash between heroes.
            local candidate, candidate_score = best_other_combo_target(hero, cursor, -1)
            local candidate_pos = candidate and origin(candidate) or nil
            if candidate_pos and cursor
                and distance2d(cursor, candidate_pos) <= ui.lock_leash:Get() then
                best, best_score = candidate, candidate_score
            end
        end
        if best then set_target(best, best_score, time) end
        return
    end

    local current_score = target_score(hero, S.target, cursor)
    S.target_score = current_score
    S.switch_candidate = nil
    S.switch_candidate_since = 0
end

-- --------------------------------------------------------------------------
-- Target history, prediction, escape score
-- --------------------------------------------------------------------------

local function sample_target_history(hero, target, time)
    local index = entity_index(target)
    if index ~= S.history_target_index then
        clear_target_history()
        S.history_target_index = index
    end
    if time - S.last_history_sample < 0.045 then return end

    local target_pos, hero_pos = origin(target), origin(hero)
    if not target_pos or not hero_pos then return end
    S.last_history_sample = time

    local previous = S.history[#S.history]
    if previous then
        local dt = time - previous.t
        local displacement = distance2d(target_pos, previous.target_pos)
        local move_speed = safe(function() return NPC.GetMoveSpeed(target) end, 550)
        local impossible = dt <= 0.001 or displacement > math.max(600, (move_speed + 250) * dt * 2.2)
        if impossible then
            S.history = {}
            S.major_displacement_until = time + 0.45
            previous = nil
        end
    end

    S.history[#S.history + 1] = {
        t = time,
        target_pos = target_pos,
        hero_pos = hero_pos,
        distance = distance2d(hero_pos, target_pos),
    }

    while #S.history > 10 or (#S.history > 1 and time - S.history[1].t > 0.65) do
        table.remove(S.history, 1)
    end

    if #S.history < 2 then
        S.velocity = vec(0, 0, 0)
        S.recent_velocity = vec(0, 0, 0)
        S.velocity_confidence = 0
        S.motion_coherence = 0
        S.motion_residual = 0
        S.distance_slope = 0
        return
    end

    local weighted_velocity = vec(0, 0, 0)
    local total_weight, valid_segments = 0, 0
    local segments = {}
    for i = 2, #S.history do
        local a, b = S.history[i - 1], S.history[i]
        local dt = b.t - a.t
        if dt >= 0.015 and dt <= 0.25 then
            local velocity = mul(sub(b.target_pos, a.target_pos), 1 / dt)
            local weight = i
            weighted_velocity = add(weighted_velocity, mul(velocity, weight))
            total_weight = total_weight + weight
            valid_segments = valid_segments + 1
            segments[#segments + 1] = { velocity = velocity, weight = weight }
        end
    end

    if total_weight > 0 then
        weighted_velocity = mul(weighted_velocity, 1 / total_weight)
        local maximum_speed = safe(function() return NPC.GetMoveSpeed(target) end, 550) + 180
        S.velocity = clamp_vector_length(weighted_velocity, maximum_speed)
        local span = S.history[#S.history].t - S.history[1].t
        local base_confidence = clamp((span / 0.35) * (valid_segments / 4), 0, 1)

        -- Confidence must describe motion quality, not just sample count.  A
        -- tight linear path is safe to extrapolate; turns, stops, and noisy
        -- samples deliberately lower confidence so a Remnant is preserved.
        local average_direction, average_speed = normalize2d(S.velocity)
        local coherence_sum, coherence_weight = 0, 0
        for _, segment in ipairs(segments) do
            local direction, speed = normalize2d(segment.velocity)
            if speed >= 35 and average_speed >= 35 then
                coherence_sum = coherence_sum + math.max(0, dot2d(direction, average_direction)) * segment.weight
                coherence_weight = coherence_weight + segment.weight
            end
        end
        S.motion_coherence = coherence_weight > 0 and clamp(coherence_sum / coherence_weight, 0, 1) or 1

        local latest = S.history[#S.history]
        local residual_sum = 0
        for _, sample in ipairs(S.history) do
            local age = latest.t - sample.t
            local fitted = sub(latest.target_pos, mul(S.velocity, age))
            residual_sum = residual_sum + distance2d(fitted, sample.target_pos)
        end
        S.motion_residual = residual_sum / math.max(1, #S.history)
        local residual_scale = math.max(28, average_speed * math.max(0.12, span) * 0.35)
        local residual_factor = 1 - clamp(S.motion_residual / residual_scale, 0, 0.82)

        local newest = segments[#segments] and segments[#segments].velocity or vec(0, 0, 0)
        S.recent_velocity = clamp_vector_length(newest, maximum_speed)
        local newest_direction, newest_speed = normalize2d(S.recent_velocity)
        if (average_speed >= 90 and newest_speed < 30)
            or (average_speed >= 90 and newest_speed >= 90
                and dot2d(newest_direction, average_direction) < 0.20) then
            S.motion_turn_until = time + 0.22
        end
        local turn_factor = time <= S.motion_turn_until and 0.28 or 1
        S.velocity_confidence = clamp(
            base_confidence
                * (0.30 + 0.70 * S.motion_coherence)
                * residual_factor
                * turn_factor,
            0,
            1
        )
    else
        S.velocity = vec(0, 0, 0)
        S.recent_velocity = vec(0, 0, 0)
        S.velocity_confidence = 0
        S.motion_coherence = 0
        S.motion_residual = 0
    end

    local last = S.history[#S.history]
    local first = S.history[1]
    for i = 1, #S.history do
        if last.t - S.history[i].t <= 0.24 then
            first = S.history[i]
            break
        end
    end
    local span = last.t - first.t
    S.distance_slope = span > 0.03 and (last.distance - first.distance) / span or 0
end

local function forward_vector(entity)
    local rotation = safe(function() return Entity.GetRotation(entity) end, nil)
    if not rotation then return vec(0, 0, 0) end
    return safe(function() return rotation:GetForward() end, vec(0, 0, 0))
end

local function attack_reach(hero, target)
    local base = safe(function() return NPC.GetAttackRange(hero) end, 150)
    local bonus = safe(function() return NPC.GetAttackRangeBonus(hero) end, 0)
    local hull = safe(function() return NPC.GetHullRadius(target) end, 24)
    return math.max(150, base + bonus + hull + 28)
end

local function ability_ranges(hero, target)
    local chains = S.abilities.chains
    local sleight = S.abilities.sleight
    local remnant = S.abilities.remnant
    local attack = attack_reach(hero, target)
    local chains_radius = special(chains, { "radius" }, 400)
    local sleight_radius = special(sleight, { "radius" }, 250)
    local sleight_cast = cast_range(hero, sleight, 700)
    local remnant_cast = cast_range(hero, remnant, 1400)
    if has_remnant_scepter_upgrade(hero, remnant) then
        local bonus = safe(function() return NPC.GetCastRangeBonus(hero) end, 0)
        remnant_cast = math.max(remnant_cast, special(remnant, { "scepter_range" }, 3000) + math.max(0, bonus))
    end
    return {
        attack = attack,
        sticky_exit = attack + 95,
        chains = chains_radius,
        control = math.max(attack + 160, chains_radius),
        sleight_radius = sleight_radius,
        sleight_cast = sleight_cast,
        sleight_practical = sleight_cast + sleight_radius * 0.65,
        remnant_cast = remnant_cast,
    }
end

local function distance_gain_evidence(hero, target, ranges, time)
    if #S.history < 3 or S.history_target_index ~= entity_index(target) then return false, 0 end
    local recent_index = math.max(1, #S.history - 3)
    local span = S.history[#S.history].t - S.history[recent_index].t
    if span < 0.09 or time <= S.major_displacement_until or time <= S.motion_turn_until then
        return false, 0
    end
    local hero_pos, target_pos = origin(hero), origin(target)
    if not hero_pos or not target_pos then return false, 0 end
    local away = normalize2d(sub(target_pos, hero_pos))
    local radial_away = dot2d(S.recent_velocity or S.velocity or vec(0, 0, 0), away)
    local distance = distance2d(hero_pos, target_pos)
    local predicted_distance = distance + math.max(0, S.distance_slope) * 0.12
    local leaving_melee = distance >= ranges.attack - 25
        or predicted_distance >= ranges.attack + 20
    local gaining = S.distance_slope >= 70
        and (radial_away >= 45 or S.distance_slope >= 140)
        and leaving_melee
    return gaining, radial_away
end

local function update_distance_gain(hero, target, ranges, time)
    local gaining, radial_away = distance_gain_evidence(hero, target, ranges, time)
    S.radial_away_speed = radial_away
    if gaining then
        S.distance_gain_since = S.distance_gain_since or time
        if time - S.distance_gain_since >= 0.10 then S.distance_gain_latched = true end
    else
        S.distance_gain_since = nil
        S.distance_gain_latched = false
    end
    return S.distance_gain_latched
end

local function update_escape_score(hero, target, ranges, time)
    local hero_pos, target_pos = origin(hero), origin(target)
    if not hero_pos or not target_pos then return 0, false end
    local away = normalize2d(sub(target_pos, hero_pos))
    local speed = length2d(S.velocity or vec(0, 0, 0))
    local radial_away = math.max(0, dot2d(S.velocity or vec(0, 0, 0), away))
    local facing = forward_vector(target)
    local facing_away = speed > 30 and math.max(0, dot2d(facing, away)) or 0
    local distance = distance2d(hero_pos, target_pos)

    local score = 0
    score = score + clamp(math.max(0, S.distance_slope) / 260, 0, 1) * 0.28
    score = score + clamp(radial_away / 420, 0, 1) * 0.24
    score = score + clamp(facing_away, 0, 1) * 0.12
    score = score + clamp((distance - ranges.attack) / math.max(1, ranges.control - ranges.attack), 0, 1) * 0.20
    score = score + clamp((distance - ranges.control) / math.max(1, ranges.sleight_practical - ranges.control), 0, 1) * 0.10
    score = score + (time <= S.major_displacement_until and 0.30 or 0)
    score = score * (0.55 + 0.45 * S.velocity_confidence)

    if distance <= ranges.attack and safe(function() return NPC.IsAttacking(hero) end, false) then
        score = score - 0.18
    end
    if safe(function() return NPC.HasState(target, Enum.ModifierState.MODIFIER_STATE_ROOTED) end, false) then
        score = score - 0.20
    end
    score = clamp(score, 0, 1)
    S.escape_score = score

    local enter = ui.escape_threshold:Get() / 100
    local exit = math.max(0.20, enter - 0.18)
    if not S.escape_latched then
        if time <= S.major_displacement_until then
            S.escape_latched = true
            S.escape_high_since = nil
        elseif score >= enter then
            S.escape_high_since = S.escape_high_since or time
            if time - S.escape_high_since >= 0.12 then
                S.escape_latched = true
                S.escape_high_since = nil
            end
        else
            S.escape_high_since = nil
        end
    else
        if score <= exit and distance <= ranges.sticky_exit then
            S.escape_low_since = S.escape_low_since or time
            if time - S.escape_low_since >= 0.20 then
                S.escape_latched = false
                S.escape_low_since = nil
            end
        else
            S.escape_low_since = nil
        end
    end
    return score, S.escape_latched
end

local function predicted_position(target, seconds, maximum_lead)
    local position = origin(target)
    if not position then return nil end
    if not ui.prediction:Get() or S.velocity_confidence < 0.20 then return position end
    local lead = clamp_vector_length(mul(S.velocity or vec(0, 0, 0), seconds), maximum_lead or 220)
    return ground_position(add(position, lead))
end

local function sticky_lead_position(target)
    return predicted_position(target, ui.lead_ms:Get() / 1000, 180)
end

-- --------------------------------------------------------------------------
-- Remnant ownership and safety
-- --------------------------------------------------------------------------

local function scan_owned_remnants(hero, time, force)
    if not force and time - S.remnants_scanned_at < 0.15 then return S.remnants end
    S.remnants_scanned_at = time
    local found = {}
    for _, npc in pairs(safe(function() return NPCs.GetAll() end, {})) do
        local name = safe(function() return NPC.GetUnitName(npc) end, "")
        if name == REMNANT_UNIT_NAME and entity_alive(npc) then
            local owned = safe(function() return Entity.RecursiveOwnedBy(npc, hero) end, false)
            if owned then
                local index = entity_index(npc)
                local position = origin(npc)
                if index >= 0 and position then
                    -- Measure how fast a Remnant actually flies, rather than
                    -- trusting the modelled speed. The model multiplies Ember's
                    -- move speed by a KV value, and special() silently falls
                    -- back to 250 when that name does not resolve -- which
                    -- would use a fixed 2.5x at every ability level and put the
                    -- predicted intercept out by exactly the amount the level
                    -- scaling differs. A measured speed is level-agnostic,
                    -- move-speed-agnostic and Scepter-agnostic.
                    local previous = S.remnants[index]
                    if previous and previous.position and previous.sampled_at then
                        local dt = time - previous.sampled_at
                        local moved = distance2d(position, previous.position)
                        if dt >= 0.02 and moved > 20 then
                            local speed = moved / dt
                            -- Reject nonsense: a stationary landed remnant, or
                            -- a scan gap that makes it look teleport-fast.
                            if speed > 200 and speed < 6000 then
                                S.measured_remnant_speed = S.measured_remnant_speed
                                    and (S.measured_remnant_speed * 0.7 + speed * 0.3)
                                    or speed
                            end
                        end
                    end
                    found[index] = {
                        entity = npc,
                        index = index,
                        position = position,
                        sampled_at = time,
                    }
                end
            end
        end
    end
    S.remnants = found
    return found
end

local function remnant_count()
    local count = 0
    for _ in pairs(S.remnants) do count = count + 1 end
    return count
end

local function enemy_count_at(hero, position, radius)
    if not position then return 99 end
    local team = safe(function() return Entity.GetTeamNum(hero) end, Enum.TeamNum.TEAM_RADIANT)
    return #safe(function()
        return Heroes.InRadius(position, radius, team, Enum.TeamType.TEAM_ENEMY, true, true)
    end, {})
end

local function ally_count_at(hero, position, radius)
    if not position then return 0 end
    local team = safe(function() return Entity.GetTeamNum(hero) end, Enum.TeamNum.TEAM_RADIANT)
    local allies = safe(function()
        return Heroes.InRadius(position, radius, team, Enum.TeamType.TEAM_FRIEND, true, true)
    end, {})
    local count = 0
    for _, ally in pairs(allies) do
        if not same_entity(ally, hero) then count = count + 1 end
    end
    return count
end

local function traversable(from, destination, strict)
    if not destination then return false end
    local ok_point, point_valid = pcall(function()
        local valid = GridNav.IsTraversable(destination)
        return valid
    end)
    if not ok_point then return not strict end
    if not point_valid then return false end
    if from then
        local ok_path, path_valid = pcall(GridNav.IsTraversableFromTo, from, destination, true)
        if not ok_path then return not strict end
        if not path_valid then return false end
    end
    return true
end

local function destination_safety(hero, target, destination, target_reference, target_tolerance)
    local hero_pos = origin(hero)
    if not hero_pos or not destination then return false, "missing position", 99, 0 end
    if not traversable(hero_pos, destination, true) then return false, "destination not traversable", 99, 0 end
    local enemies = enemy_count_at(hero, destination, 725)
    local allies = ally_count_at(hero, destination, 850)
    local hp = safe(function() return Entity.GetHealth(hero) end, 1)
    local max_hp = math.max(1, safe(function() return Entity.GetMaxHealth(hero) end, hp))
    -- Multiple demo enemies are common while testing. Do not make the combo
    -- silently idle at full health; preserve the charge only when Ember is low
    -- and the configured destination limit is actually exceeded.
    if enemies > ui.remnant_max_enemies:Get() and hp / max_hp < 0.35 then
        return false, "low HP into too many enemies", enemies, allies
    end
    if target and valid_target(hero, target) then
        local target_pos = target_reference or origin(target)
        if not target_pos then return false, "target position unavailable", enemies, allies end
        if distance2d(target_pos, destination) > (target_tolerance or 525) then
            return false, "target left intercept", enemies, allies
        end
        -- Elevation, which traversability does not cover. Distance is measured
        -- in 2D and ground_position snaps Z to whatever terrain is under that
        -- XY, so an intercept that creeps onto a cliff TOP while the enemy
        -- stands on the low ground below is geometrically "valid" and lands
        -- nowhere near them. High ground to low ground across a cliff edge is
        -- exactly that case.
        local destination_z = safe(function()
            return World.GetGroundZ(destination.x, destination.y)
        end, nil)
        local target_z = safe(function()
            return World.GetGroundZ(target_pos.x, target_pos.y)
        end, nil)
        if destination_z and target_z and math.abs(destination_z - target_z) > 120 then
            return false, "destination sits on a different elevation to the target", enemies, allies
        end
    end
    return true, "safe", enemies, allies
end

local function target_is_immobile(target)
    return safe(function() return NPC.IsStunned(target) end, false)
        or safe(function()
            return NPC.HasState(target, Enum.ModifierState.MODIFIER_STATE_ROOTED)
        end, false)
end

local function target_motion_model(target, time)
    local position = origin(target)
    if not position then return nil, vec(0, 0, 0), 0, false, false end
    if target_is_immobile(target) then return position, vec(0, 0, 0), 1, true, false end

    local move_speed = safe(function() return NPC.GetMoveSpeed(target) end, 550)
    -- First-update seed: a newly selected far enemy must receive R immediately.
    -- Until timestamped samples exist, use the engine-facing vector when the
    -- target is running; otherwise cast at its current position. Subsequent
    -- updates retain the full measured-history predictor.
    if #S.history < 2 then
        if safe(function() return NPC.IsRunning(target) end, false) then
            local facing, facing_length = normalize2d(forward_vector(target))
            if facing_length > 0.1 then
                return position, mul(facing, move_speed), 0.78, false, true
            end
        end
        return position, vec(0, 0, 0), 0.90, true, true
    end
    local velocity = S.velocity or vec(0, 0, 0)
    local recent = S.recent_velocity or velocity
    local _, recent_speed = normalize2d(recent)
    if recent_speed >= 35 and S.motion_coherence >= 0.55 then
        velocity = add(mul(velocity, 0.58), mul(recent, 0.42))
    end
    velocity = clamp_vector_length(velocity, math.max(100, move_speed + 80))
    local _, speed = normalize2d(velocity)

    if speed < 35 then
        local span = #S.history >= 2 and (S.history[#S.history].t - S.history[1].t) or 0
        local stationary_confidence = clamp(span / 0.22, 0, 1)
            * (1 - clamp((S.motion_residual or 0) / 55, 0, 0.85))
        if time <= S.motion_turn_until then stationary_confidence = math.min(stationary_confidence, 0.28) end
        return position, vec(0, 0, 0), stationary_confidence, true, false
    end
    return position, velocity, S.velocity_confidence, false, false
end

local function predict_motion(position, velocity, seconds)
    return ground_position(add(position, mul(velocity, math.max(0, seconds or 0))))
end

local function remnant_travel_profile(hero, ranges)
    local remnant, activate = S.abilities.remnant, S.abilities.activate
    local placement_cast_point = math.max(0, safe(function()
        return Ability.GetCastPoint(remnant, true)
    end, 0))
    local speed_percent = special(remnant, { "speed_multiplier" }, 250)
    local placement_factor = speed_percent > 20 and speed_percent / 100 or speed_percent
    local scepter = has_remnant_scepter_upgrade(hero, remnant)
    if scepter then
        placement_factor = placement_factor * special(remnant, { "scepter_speed_multiplier" }, 2)
    end
    local hero_move_speed = safe(function() return NPC.GetMoveSpeed(hero) end, 300)
    local modelled_placement_speed = math.max(100, hero_move_speed * placement_factor)
    local placement_speed = modelled_placement_speed
    -- Prefer the speed observed from a Remnant actually in flight. The modelled
    -- value above is only a starting guess until the first one has been seen.
    if S.measured_remnant_speed and S.measured_remnant_speed > 100 then
        placement_speed = S.measured_remnant_speed
    end
    local activate_cast_point = math.max(0, safe(function()
        return Ability.GetCastPoint(activate, true)
    end, 0.2))
    local activate_speed = math.max(100, special(activate, { "speed" }, 1300))
    local scheduling_slack = clamp(ui.update_ms:Get() / 1000 * 2 + 0.02, 0.04, 0.18)
    return {
        hero = hero,
        placement_cast_point = placement_cast_point,
        placement_speed = placement_speed,
        modelled_placement_speed = modelled_placement_speed,
        activate_cast_point = activate_cast_point,
        activate_speed = activate_speed,
        scheduling_slack = scheduling_slack,
        turn_rate = math.max(0.05, safe(function() return NPC.GetTurnRate(hero) end, 0.8)),
        tick_interval = clamp(safe(function() return GlobalVars.GetIntervalPerTick() end, 1 / 30), 0.01, 0.10),
        cast_range = math.max(100, (ranges and ranges.remnant_cast or cast_range(hero, remnant, 1400)) - 25),
        scepter = scepter,
    }
end

local function remnant_turn_delay(destination, profile)
    local angle = safe(function()
        return math.abs(NPC.FindRotationAngle(profile.hero, destination))
    end, nil)
    if type(angle) ~= "number" then
        local hero_position = origin(profile.hero)
        local shot_direction = hero_position and normalize2d(sub(destination, hero_position)) or vec(0, 0, 0)
        local facing_direction = normalize2d(forward_vector(profile.hero))
        angle = math.acos(clamp(dot2d(facing_direction, shot_direction), -1, 1))
    end
    if angle <= math.rad(11.5) then return 0 end
    return math.ceil(angle / profile.turn_rate) * profile.tick_interval
end

-- Enemy fountain position. Prefers the real entity when the build exposes one,
-- and falls back to the standard map coordinates, because being wrong here is
-- only ever wrong in the safe direction -- it refuses a destination.
function plan.enemy_fountain(hero)
    local team = safe(function() return Entity.GetTeamNum(hero) end, nil)
    if team == nil then return nil end
    for _, npc in pairs(safe(function() return NPCs.GetAll() end, {})) do
        local name = safe(function() return NPC.GetUnitName(npc) end, "")
        if name == "npc_dota_fountain"
            and safe(function() return Entity.GetTeamNum(npc) end, team) ~= team then
            local position = origin(npc)
            if position then return position end
        end
    end
    if team == Enum.TeamNum.TEAM_RADIANT then return vec(7168, 6656, 0) end
    if team == Enum.TeamNum.TEAM_DIRE then return vec(-7168, -6656, 0) end
    return nil
end

-- A single IsTraversable check on the destination only proves that one cell is
-- walkable. It says nothing about the ground between here and there, so a point
-- across a cliff -- high ground to low ground near mid, for instance -- passes
-- happily while the Remnant cannot actually get there. IsTraversableFromTo
-- validates the whole path, which is what the cliff cases need.
-- Delegates to traversable(), which already pairs the point check with
-- IsTraversableFromTo. The combo's destination_safety has always used it; the
-- dance path was the one checking only the endpoint.
function plan.path_clear(from, to)
    if not from or not to then return true end
    return traversable(from, to, true)
end

-- Spell immunity: BKB, Lifestealer's Rage, Juggernaut's Blade Fury and the
-- like. Searing Chains is a magic root, so it is entirely wasted on a target
-- carrying this -- the cast goes on cooldown and nothing is rooted. Fallback
-- false on purpose: if the state cannot be read, do not silently disable
-- Chains, just behave as before.
function plan.spell_immune(unit)
    if not unit then return false end
    return safe(function()
        return NPC.HasState(unit, Enum.ModifierState.MODIFIER_STATE_MAGIC_IMMUNE)
    end, false)
end

-- Same elevation rule destination_safety applies, exposed for the paths that
-- do not route through it. Two points can be a short 2D distance apart and be
-- a full cliff height apart vertically.
function plan.elevation_mismatch(a, b)
    if not a or not b then return false end
    local az = safe(function() return World.GetGroundZ(a.x, a.y) end, nil)
    local bz = safe(function() return World.GetGroundZ(b.x, b.y) end, nil)
    if not az or not bz then return false end
    return math.abs(az - bz) > 120
end

-- A Remnant placed in the enemy fountain is a delivery service for your own
-- death: the dash follows it in. No targeting rule outranks this.
function plan.fountain_blocked(hero, destination)
    if not destination then return false end
    if not safe(function() return ui.avoid_fountain:Get() end, true) then return false end
    local fountain = plan.enemy_fountain(hero)
    if not fountain then return false end
    return distance2d(destination, fountain) <= ui.fountain_radius:Get()
end

function dance.remnant_destination(hero, cursor, remnant, origin_override)
    local hero_pos = origin_override or origin(hero)
    if not hero_pos or not cursor or not remnant then return nil end
    local direction, cursor_distance = normalize2d(sub(cursor, hero_pos))
    if cursor_distance < 10 then return nil end
    local bonus = safe(function() return NPC.GetCastRangeBonus(hero) end, 0)
    local effective_range = math.max(
        cast_range(hero, remnant, 1400),
        special(remnant, { "scepter_range" }, 3000) + math.max(0, bonus)
    )
    local profile = remnant_travel_profile(hero, { remnant_cast = effective_range })
    local destination = ground_position(add(
        hero_pos,
        mul(direction, math.min(cursor_distance, profile.cast_range))
    ))
    if not safe(function() return GridNav.IsTraversable(destination) end, true) then return nil end
    if plan.fountain_blocked(hero, destination) then
        log_decision("SAVE REMNANT: destination is inside the enemy fountain")
        return nil
    end
    -- Walk the destination back along its own line when the path is blocked or
    -- the landing spot is a cliff height away from where it was aimed. Cliff
    -- edges are the common case: the far side is walkable and the 2D distance
    -- looks fine, so the point passes every flat check and still misses.
    if not plan.path_clear(hero_pos, destination)
        or plan.elevation_mismatch(destination, cursor) then
        local pulled = nil
        for _, fraction in ipairs({ 0.85, 0.7, 0.55, 0.4 }) do
            local candidate = ground_position(add(
                hero_pos, mul(direction, math.min(cursor_distance, profile.cast_range) * fraction)
            ))
            if safe(function() return GridNav.IsTraversable(candidate) end, true)
                and plan.path_clear(hero_pos, candidate)
                and not plan.elevation_mismatch(candidate, cursor)
                and not plan.fountain_blocked(hero, candidate) then
                pulled = candidate
                break
            end
        end
        if not pulled then
            log_decision("SAVE REMNANT: no clear path to the destination (cliff or blocked terrain)")
            return nil
        end
        log_decision("REMNANT: pulled the destination back to clear the terrain")
        destination = pulled
    end
    return destination, effective_range, profile, cursor_distance, hero_pos
end

-- --------------------------------------------------------------------------
-- Per-hero motion tracking. The main combo's prediction only ever models
-- S.target, which is useless for the dance: every hop is a different hero and
-- none of them have history. This keeps a light velocity estimate for every
-- reachable enemy so a chain hop can be led properly. Grouped on one table to
-- stay under Lua's 200-local ceiling.
-- --------------------------------------------------------------------------
local motion = {}

function motion.sample(local_hero, time)
    if time - (S.motion_last_sample or 0) < 0.05 then return end
    S.motion_last_sample = time
    S.hero_motion = S.hero_motion or {}
    for _, enemy in pairs(safe(function() return Heroes.GetAll() end, {})) do
        if valid_target(local_hero, enemy) then
            local index = entity_index(enemy)
            local position = origin(enemy)
            if index >= 0 and position then
                local tracked = S.hero_motion[index]
                if tracked and tracked.t and time > tracked.t then
                    local dt = time - tracked.t
                    -- Ignore blinks/teleports and stale gaps: they are not
                    -- walking motion and must never feed the velocity model.
                    local step = distance2d(position, tracked.pos)
                    local cap = safe(function() return NPC.GetMoveSpeed(enemy) end, 550) + 150
                    if dt >= 0.02 and dt <= 0.50 and step <= cap * dt * 1.8 then
                        local raw = clamp_vector_length(mul(sub(position, tracked.pos), 1 / dt), cap)
                        local blended = tracked.vel
                            and add(mul(tracked.vel, 0.55), mul(raw, 0.45))
                            or raw
                        local smooth_dir = normalize2d(blended)
                        local raw_dir, raw_speed = normalize2d(raw)
                        -- Coherence collapses when a hero jukes or stops, which
                        -- is exactly when leading the shot would miss.
                        local agreement = raw_speed >= 40
                            and math.max(0, dot2d(smooth_dir, raw_dir))
                            or 0
                        tracked.coherence = clamp(
                            (tracked.coherence or 0.5) * 0.65 + agreement * 0.35, 0, 1
                        )
                        tracked.vel = blended
                    elseif step > cap * dt * 1.8 then
                        tracked.vel = vec(0, 0, 0)
                        tracked.coherence = 0
                    end
                    tracked.pos = position
                    tracked.t = time
                else
                    S.hero_motion[index] = {
                        pos = position, t = time, vel = vec(0, 0, 0), coherence = 0.5,
                    }
                end
            end
        end
    end
end

function motion.velocity(index)
    local tracked = S.hero_motion and S.hero_motion[index]
    if not tracked or not tracked.vel then return vec(0, 0, 0), 0 end
    return tracked.vel, tracked.coherence or 0
end

-- Solve for where to drop the remnant so the hero walks onto it. Iterates
-- because the lead distance changes the travel time, which changes the lead.
function motion.intercept(hero, target, anchor, remnant)
    local target_pos = origin(target)
    if not target_pos or not anchor then return target_pos end
    local velocity, coherence = motion.velocity(entity_index(target))
    local speed = length2d(velocity)
    -- Standing still, jinking, or barely moving: aim straight at them. A lead
    -- based on incoherent motion is worse than no lead at all.
    if speed < 45 or coherence < 0.40 then return target_pos end

    local profile = remnant_travel_profile(hero, { remnant_cast = dance.chain_cast_range(hero) })
    local point = target_pos
    for _ = 1, 3 do
        local travel = profile.placement_cast_point
            + distance2d(anchor, point) / math.max(100, profile.placement_speed)
        point = add(target_pos, mul(velocity, travel))
    end
    -- Confidence scales the lead: full commit only on clean straight running.
    local blend = clamp((coherence - 0.40) / 0.45, 0, 1)
    return add(target_pos, mul(sub(point, target_pos), blend))
end

-- Activate travel can expose Ember as OUT_OF_GAME even though Scepter still
-- accepts Fire Remnant placement. Keep the spell-specific safety checks while
-- deliberately not using hero_can_act for chained R orders.
function dance.chain_remnant_ready(hero, remnant)
    if not entity_alive(hero) or not remnant then return false end
    if safe(function() return NPC.IsStunned(hero) end, false)
        or safe(function() return NPC.IsSilenced(hero) end, false)
        or safe(function() return NPC.HasState(hero, Enum.ModifierState.MODIFIER_STATE_HEXED) end, false) then
        return false
    end
    -- Fire Remnant's generic activated flag may remain false while Ember is
    -- travelling through Activate Fire Remnant even though Scepter permits a
    -- new R order in that state. Do not reuse ordinary castability here: the
    -- dance path intentionally validates only the spell level, a real charge,
    -- mana, and disabling states, then submits the position order immediately.
    if safe(function() return Ability.GetLevel(remnant) end, 0) <= 0 then return false end
    local charges = safe(function() return Ability.GetCurrentCharges(remnant) end, 0)
    local mana = safe(function() return NPC.GetMana(hero) end, 0)
    local cost = safe(function() return Ability.GetManaCost(remnant) end, math.huge)
    return charges > 0 and mana >= cost
end

local function remnant_activation_time(hero_position, destination, profile, include_scheduler)
    local distance = distance2d(hero_position, destination)
    local dash = math.min(distance / profile.activate_speed, 0.40)
    return profile.activate_cast_point + dash + (include_scheduler and profile.scheduling_slack or 0)
end

local function remnant_arrival_time(hero_position, destination, profile)
    local distance = distance2d(hero_position, destination)
    return remnant_turn_delay(destination, profile)
        + profile.placement_cast_point
        + distance / profile.placement_speed
        + remnant_activation_time(hero_position, destination, profile, true)
end

local function predict_remnant_intercept(hero, target, ranges, time)
    local hero_pos = origin(hero)
    local target_pos, velocity, motion_confidence, stationary, instant_seed = target_motion_model(target, time)
    if not hero_pos or not target_pos then return nil, 0, nil end
    local motion_coherence = instant_seed and 1 or S.motion_coherence
    if stationary and motion_confidence < 0.65 then
        return nil, motion_confidence, nil
    end
    if not ui.prediction:Get() and not stationary then return nil, motion_confidence, nil end
    if not stationary and (motion_confidence < 0.50 or motion_coherence < 0.52
        or time <= S.motion_turn_until) then
        return nil, motion_confidence, nil
    end

    local profile = remnant_travel_profile(hero, ranges)
    local function maximum_range_approach()
        local _, current_distance = normalize2d(sub(target_pos, hero_pos))
        if current_distance < profile.cast_range - 75 then return nil, motion_confidence, nil end

        local predicted_target = target_pos
        local destination, actual_arrival
        for _ = 1, 3 do
            local direction = normalize2d(sub(predicted_target, hero_pos))
            destination = ground_position(add(hero_pos, mul(direction, profile.cast_range)))
            actual_arrival = remnant_arrival_time(hero_pos, destination, profile)
            predicted_target = predict_motion(target_pos, velocity, actual_arrival)
        end
        if not destination or not actual_arrival then return nil, motion_confidence, nil end

        local residual_miss = distance2d(destination, predicted_target)
        local confidence = stationary and motion_confidence
            or clamp(motion_confidence * (0.65 + 0.35 * motion_coherence), 0, 1)
        if confidence < 0.55 then return nil, confidence, nil end
        local turn_delay = remnant_turn_delay(destination, profile)
        local outbound = turn_delay
            + profile.placement_cast_point
            + distance2d(hero_pos, destination) / profile.placement_speed
        return destination, confidence, {
            target_origin = target_pos,
            target_velocity = velocity,
            predicted_target = predicted_target,
            eta = actual_arrival,
            outbound_eta = outbound,
            turn_delay = turn_delay,
            residual_miss = residual_miss,
            -- This is a deliberate maximum-range approach rather than a direct
            -- damage intercept. Keep destination safety checks, but allow the
            -- remaining enemy gap that the follow-up movement will close.
            tolerance = residual_miss + 140,
            range_clamped = true,
            approach_only = true,
            motion_confidence = motion_confidence,
            confidence = confidence,
            profile = profile,
        }
    end

    local maximum_arrival = remnant_arrival_time(
        hero_pos,
        add(hero_pos, mul(normalize2d(sub(target_pos, hero_pos)), profile.cast_range)),
        profile
    ) + 0.70
    local confidence_horizon = stationary and maximum_arrival or (1.6 + 3.2 * motion_confidence)
    local horizon = clamp(math.min(maximum_arrival, confidence_horizon), 0.60, 5.50)

    local function difference(seconds)
        local candidate = predict_motion(target_pos, velocity, seconds)
        return remnant_arrival_time(hero_pos, candidate, profile) - seconds
    end

    -- Solve arrival(target(t)) == t.  A scan finds the earliest reachable
    -- intercept; bisection then avoids the under-lead of a one-pass estimate.
    local low, high = 0, nil
    local step = 0.075
    local previous_t, previous_f = 0, difference(0)
    local scan_t = step
    while scan_t <= horizon + 0.001 do
        local value = difference(scan_t)
        if previous_f >= 0 and value <= 0 then
            low, high = previous_t, scan_t
            break
        end
        previous_t, previous_f = scan_t, value
        scan_t = scan_t + step
    end
    if not high then return maximum_range_approach() end

    for _ = 1, 14 do
        local middle = (low + high) * 0.5
        if difference(middle) > 0 then low = middle else high = middle end
    end
    local solved_time = (low + high) * 0.5
    local raw_destination = predict_motion(target_pos, velocity, solved_time)
    local direction, raw_distance = normalize2d(sub(raw_destination, hero_pos))
    local destination = raw_destination
    local range_clamped = raw_distance > profile.cast_range
    if range_clamped then destination = add(hero_pos, mul(direction, profile.cast_range)) end
    destination = ground_position(destination)

    local actual_arrival = remnant_arrival_time(hero_pos, destination, profile)
    local predicted_target = predict_motion(target_pos, velocity, actual_arrival)
    local residual_miss = distance2d(destination, predicted_target)
    local target_hull = safe(function() return NPC.GetHullRadius(target) end, 24)
    local tolerance = clamp(target_hull + 90, 105, 135)
    if residual_miss > tolerance then return maximum_range_approach() end

    local horizon_factor = clamp(1 - math.max(0, actual_arrival - 1.0) * 0.10, 0.55, 1)
    local confidence = stationary and motion_confidence
        or clamp(motion_confidence * (0.62 + 0.38 * motion_coherence) * horizon_factor, 0, 1)
    if confidence < 0.55 then return nil, confidence, nil end
    local turn_delay = remnant_turn_delay(destination, profile)
    local outbound = turn_delay
        + profile.placement_cast_point
        + distance2d(hero_pos, destination) / profile.placement_speed
    return destination, confidence, {
        target_origin = target_pos,
        target_velocity = velocity,
        predicted_target = predicted_target,
        eta = actual_arrival,
        outbound_eta = outbound,
        turn_delay = turn_delay,
        residual_miss = residual_miss,
        tolerance = tolerance,
        range_clamped = range_clamped,
        motion_confidence = motion_confidence,
        confidence = confidence,
        profile = profile,
    }
end

-- Re-plan from the logical Remnant endpoint while Ember is already committed
-- to D travel. The freshest velocity segment is intentional here: a dodge
-- briefly lowers the normal long-horizon predictor's confidence, but that turn
-- is exactly the event this one-shot correction needs to react to.
local function predict_midflight_remnant_correction(ctx, tx)
    if not ui.midflight_correction:Get()
        or not ctx or not tx or tx.dance
        or not valid_target(ctx.hero, ctx.target) then return nil end
    local anchor = tx.activation_position or tx.destination or ctx.hero_pos
    local target_pos = origin(ctx.target)
    if not anchor or not target_pos then return nil end

    local velocity = S.recent_velocity or S.velocity or vec(0, 0, 0)
    local _, speed = normalize2d(velocity)
    if speed < 45 then return nil end
    local profile = remnant_travel_profile(ctx.hero, ctx.ranges)
    local predicted = target_pos
    local destination = nil
    for _ = 1, 3 do
        local direction, distance = normalize2d(sub(predicted, anchor))
        local legal_distance = math.min(distance, profile.cast_range)
        destination = ground_position(add(anchor, mul(direction, legal_distance)))
        local placement_eta = remnant_turn_delay(destination, profile)
            + profile.placement_cast_point
            + legal_distance / math.max(100, profile.placement_speed)
        predicted = predict_motion(target_pos, velocity, clamp(placement_eta, 0.06, 1.60))
    end
    if not destination then return nil end

    local original_destination = tx.original_destination or tx.destination
    local deviation = original_destination
        and distance2d(destination, original_destination) or 0
    local threshold = ui.correction_deviation:Get()
    local fresh_turn = ctx.time <= S.motion_turn_until
    if deviation < threshold
        or (not fresh_turn and deviation < threshold * 1.35) then return nil end

    local safe_destination, why = destination_safety(
        ctx.hero,
        ctx.target,
        destination,
        predicted,
        math.max(145, threshold * 0.70)
    )
    if not safe_destination then
        log_decision("SAVE CORRECTION REMNANT: " .. why)
        return nil
    end
    return destination, profile, deviation, anchor
end

-- --------------------------------------------------------------------------
-- Damage and hit-confidence estimates
-- --------------------------------------------------------------------------

local function physical_barrier(target)
    local barriers = safe(function() return NPC.GetBarriers(target) end, nil)
    if type(barriers) ~= "table" then return 0 end
    local physical = type(barriers.physical) == "table" and (barriers.physical.current or 0) or 0
    local universal = type(barriers.all) == "table" and (barriers.all.current or 0) or 0
    return math.max(0, physical) + math.max(0, universal)
end

local function magical_barrier(target)
    local barriers = safe(function() return NPC.GetBarriers(target) end, nil)
    if type(barriers) ~= "table" then return 0 end
    local magical = type(barriers.magic) == "table" and (barriers.magic.current or 0) or 0
    local universal = type(barriers.all) == "table" and (barriers.all.current or 0) or 0
    return math.max(0, magical) + math.max(0, universal)
end

local function attack_damage(hero, target)
    local raw = safe(function() return NPC.GetTrueDamage(hero) end, 0)
    local armor_multiplier = safe(function() return NPC.GetArmorDamageMultiplier(target) end, 0.70)
    return math.max(0, raw * armor_multiplier)
end

local function sleight_damage(hero, target)
    local sleight = S.abilities.sleight
    if not sleight then return 0, "no ability" end
    local base_attack = safe(function() return NPC.GetTrueDamage(hero) end, 0)
    local bonus = special(sleight, { "bonus_hero_damage", "bonus_damage" }, 0)
    local raw = math.max(0, base_attack) + math.max(0, bonus)
    local armor_multiplier = safe(function() return NPC.GetArmorDamageMultiplier(target) end, 0.70)
    return math.max(0, raw * armor_multiplier), bonus > 0 and "high" or "low"
end

local function can_sleight_hit(hero, target, ranges)
    local hero_pos, target_pos = origin(hero), origin(target)
    if not hero_pos or not target_pos then return false end
    return distance2d(hero_pos, target_pos) <= ranges.sleight_practical
end

local function sleight_cast_position(hero, target, ranges, lead_seconds, maximum_lead)
    local hero_pos = origin(hero)
    local target_pos = predicted_position(target, lead_seconds or 0.05, maximum_lead or 100)
    if not hero_pos or not target_pos then return nil end

    local direction, distance = normalize2d(sub(target_pos, hero_pos))
    local maximum_cast = math.max(0, ranges.sleight_cast - 20)
    local cast_pos = target_pos
    if distance > maximum_cast then
        cast_pos = add(hero_pos, mul(direction, maximum_cast))
        if distance2d(cast_pos, target_pos) > ranges.sleight_radius * 0.70 then return nil end
    end
    return ground_position(cast_pos)
end

local function sleight_area_contains(target, cast_pos, ranges, prediction_slack)
    local target_pos = origin(target)
    if not target_pos or not cast_pos then return false end
    local hull = safe(function() return NPC.GetHullRadius(target) end, 24)
    return distance2d(target_pos, cast_pos)
        <= ranges.sleight_radius + hull + (prediction_slack or 0)
end

local function can_sleight_kill(hero, target, ranges)
    if not ui.kill_secure:Get() or not valid_target(hero, target) then return false, 0, 0, "disabled" end
    if safe(function()
        return NPC.HasState(target, Enum.ModifierState.MODIFIER_STATE_ATTACK_IMMUNE)
    end, false) then return false, 0, 0, "attack immune" end
    local sleight = S.abilities.sleight
    if not ui.use_sleight:Get() or not ability_usable(hero, sleight, ui.mana_reserve:Get()) then
        return false, 0, 0, "not castable"
    end
    if not can_sleight_hit(hero, target, ranges) then return false, 0, 0, "out of range" end
    local damage, confidence = sleight_damage(hero, target)
    local hp = safe(function() return Entity.GetHealth(target) end, math.huge) + physical_barrier(target)
    -- Fail closed around flat blocks and short-lived physical reductions that
    -- the documented damage surface cannot enumerate reliably.
    local conservative_damage = math.max(0, damage * 0.65 - 80)
    return conservative_damage >= hp, conservative_damage, hp, confidence
end

-- Same conservative lethality math as can_sleight_kill, minus the trainer's own
-- "Lethal Sleight Finish" toggle: the preload cares whether this hero is about
-- to die to a Sleight at all, including one cast by Umbrella's Kill Stealer.
local function sleight_lethal_now(hero, target, ranges)
    if not valid_target(hero, target) then return false end
    if safe(function()
        return NPC.HasState(target, Enum.ModifierState.MODIFIER_STATE_ATTACK_IMMUNE)
    end, false) then return false end
    local sleight = S.abilities.sleight
    -- If Sleight is not actually castable, nothing is about to steal this kill.
    if not ability_usable(hero, sleight, ui.mana_reserve:Get()) then return false end
    if not can_sleight_hit(hero, target, ranges) then return false end
    local damage = sleight_damage(hero, target)
    local hp = safe(function() return Entity.GetHealth(target) end, math.huge)
        + physical_barrier(target)
    local conservative_damage = math.max(0, damage * 0.65 - 80)
    return conservative_damage >= hp
end

local function estimate_sticky_kill(hero, target)
    local attack = attack_damage(hero, target)
    local guard_dps = 0
    if flame_guard_active(hero) then
        local raw_guard = special(S.abilities.guard, { "damage_per_second", "damage" }, 0)
        guard_dps = raw_guard * safe(function() return NPC.GetMagicalArmorDamageMultiplier(target) end, 0.75)
    end
    local attack_time = safe(function() return NPC.GetSecondsPerAttack(hero, false) end, 1.7)
    local two_attacks = attack * 2 + guard_dps * math.max(0.5, attack_time * 1.5)
    local hp = safe(function() return Entity.GetHealth(target) end, math.huge) + physical_barrier(target)
    return two_attacks * 0.90 >= hp, two_attacks, hp
end

local function remnant_high_confidence_kill(
    hero,
    target,
    destination,
    predicted_target,
    prediction_confidence
)
    local remnant = S.abilities.remnant
    if not remnant or not destination or not valid_target(hero, target) then return false, 0, math.huge end
    local raw = special(remnant, { "damage" }, 0)
    local radius = special(remnant, { "radius" }, 450)
    if raw <= 0 then return false, 0, math.huge end

    local projected = predicted_target or origin(target)
    if not projected or distance2d(projected, destination) > radius * 0.65 then
        return false, 0, math.huge
    end
    if (prediction_confidence or 0) < 0.70 then return false, 0, math.huge end

    local multiplier = safe(function() return NPC.GetMagicalArmorDamageMultiplier(target) end, 0.75)
    local damage = math.max(0, raw * multiplier)
    local hp = safe(function() return Entity.GetHealth(target) end, math.huge) + magical_barrier(target)
    return damage * 0.85 >= hp, damage, hp
end

local function update_kill_estimate(hero, target, ranges)
    local sleight_lethal, sleight_damage_value, effective_hp = can_sleight_kill(hero, target, ranges)
    if sleight_lethal then
        S.kill_estimate = string.format("Sleight lethal (%.0f vs %.0f HP)", sleight_damage_value, effective_hp)
        return
    end
    local sticky_lethal, sticky_damage, sticky_hp = estimate_sticky_kill(hero, target)
    if sticky_lethal then
        S.kill_estimate = string.format("2 attacks + Guard window (%.0f vs %.0f HP)", sticky_damage, sticky_hp)
    else
        S.kill_estimate = string.format("preserve / continue (%.0f short damage vs %.0f HP)", sticky_damage, sticky_hp)
    end
end

local function chains_hit_chance(hero, target, ranges)
    local hero_pos, target_pos = origin(hero), origin(target)
    if not hero_pos or not target_pos then return 0, 0 end
    local target_hull = safe(function() return NPC.GetHullRadius(target) end, 24)
    if distance2d(hero_pos, target_pos) > ranges.chains + target_hull + 35 then return 0, 0 end

    local units = safe(function()
        return Entity.GetUnitsInRadius(hero, ranges.chains + 20, Enum.TeamType.TEAM_ENEMY, true, true)
    end, {})
    -- Searing Chains picks its targets uniformly at random among everything in
    -- the radius -- heroes get no priority -- so every unit counted here is a
    -- unit that can steal the root. Anything the engine cannot actually root
    -- must therefore be excluded, or the pool is inflated and a genuinely
    -- guaranteed frame gets misreported as a gamble.
    local eligible, contains_target = 0, false
    for _, unit in pairs(units) do
        if entity_alive(unit)
            and not safe(function() return NPC.IsStructure(unit) end, false)
            and not safe(function() return NPC.IsWard(unit) end, false)
            and not safe(function() return NPC.IsInvulnerable(unit) end, false)
            and not safe(function()
                return NPC.HasState(unit, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE)
            end, false)
            and not safe(function()
                return NPC.HasState(unit, Enum.ModifierState.MODIFIER_STATE_OUT_OF_GAME)
            end, false)
            -- Spell-immune units cannot be rooted, so they are not competing
            -- for a chain. Counting them made the pool look more crowded than
            -- it is and needlessly suppressed guaranteed casts.
            and not plan.spell_immune(unit) then
            eligible = eligible + 1
            if same_entity(unit, target) then contains_target = true end
        end
    end
    local unit_count = math.floor(special(S.abilities.chains, { "unit_count", "targets" }, 2))
    if not contains_target then return 0, eligible, unit_count end
    local chance = eligible <= 0 and 0 or math.min(1, unit_count / eligible)
    return chance, eligible, unit_count
end

-- --------------------------------------------------------------------------
-- Context and state evaluation
-- --------------------------------------------------------------------------

local function build_context(hero, target, time)
    local hero_pos, target_pos = origin(hero), origin(target)
    if not hero_pos or not target_pos then return nil end
    local ranges = ability_ranges(hero, target)
    local distance = distance2d(hero_pos, target_pos)
    local escape_score, escaping = update_escape_score(hero, target, ranges, time)
    local gaining_distance = update_distance_gain(hero, target, ranges, time)
    local lead = sticky_lead_position(target) or target_pos
    local zone
    if distance <= ranges.sticky_exit then zone = "STICKY"
    elseif distance <= ranges.control then zone = "CONTROL"
    elseif distance <= ranges.sleight_practical then zone = "SLEIGHT"
    elseif distance <= ranges.remnant_cast then zone = "REMNANT"
    else zone = "OUT_OF_RANGE" end
    S.zone = zone

    local enemies = enemy_count_at(hero, target_pos, 725)
    local allies = ally_count_at(hero, target_pos, 850)
    local hp = safe(function() return Entity.GetHealth(hero) end, 1)
    local max_hp = math.max(1, safe(function() return Entity.GetMaxHealth(hero) end, hp))
    local unsafe = distance > ui.max_chase:Get()
        or (enemies > ui.remnant_max_enemies:Get() and hp / max_hp < 0.28)

    return {
        time = time,
        hero = hero,
        player = S.player,
        target = target,
        target_index = S.target_index,
        target_epoch = S.target_epoch,
        hold_epoch = S.hold_epoch,
        map_epoch = S.map_epoch,
        hero_pos = hero_pos,
        target_pos = target_pos,
        lead_pos = lead,
        distance = distance,
        ranges = ranges,
        escape_score = escape_score,
        escaping = escaping,
        gaining_distance = gaining_distance,
        enemies = enemies,
        allies = allies,
        unsafe = unsafe,
    }
end

local function update_attack_contact(ctx)
    -- "Cannot attack" is deliberately spatial here. A Remnant should repair
    -- lost melee contact, not spend charges trying to solve a disarm, silence,
    -- invulnerability, or another temporary state that movement cannot fix.
    if S.control_mode ~= "COMBO"
        or not S.engagement_started
        or S.tx ~= nil then
        S.attack_contact_lost_since = nil
        return
    end
    if ctx.distance <= ctx.ranges.attack + 20 then
        S.attack_contact_lost_since = nil
    elseif not S.attack_contact_lost_since then
        S.attack_contact_lost_since = ctx.time
    end
end

local function evaluate_state(ctx)
    if ctx.unsafe then
        S.disengage_until = math.max(S.disengage_until, ctx.time + 0.75)
        set_fsm(FSM.DISENGAGE, ctx.time)
        return
    end
    if S.fsm == FSM.DISENGAGE and ctx.time < S.disengage_until then return end

    if not S.engagement_started then
        if ctx.distance <= ctx.ranges.sticky_exit + 20 then
            S.engagement_started = true
            S.combo_stage = COMBO_STAGE.GUARD
            set_fsm(FSM.STICKY_FIGHT, ctx.time)
        else
            S.combo_stage = COMBO_STAGE.GAP_CLOSE
            set_fsm(FSM.GAP_CLOSE, ctx.time)
        end
        return
    end

    local lethal = can_sleight_kill(ctx.hero, ctx.target, ctx.ranges)
    if lethal then
        S.combo_stage = COMBO_STAGE.FINISH
        set_fsm(FSM.KILL_SECURE, ctx.time)
    elseif ctx.distance <= ctx.ranges.sticky_exit then
        set_fsm(ctx.escaping and FSM.TARGET_ESCAPING or FSM.STICKY_FIGHT, ctx.time)
    elseif ctx.distance <= ctx.ranges.control + 120 then
        set_fsm(ctx.escaping and FSM.TARGET_ESCAPING or FSM.APPROACH, ctx.time)
    elseif ctx.distance <= ctx.ranges.sleight_practical then
        set_fsm(FSM.RECONNECT, ctx.time)
    elseif ctx.distance <= math.min(ctx.ranges.remnant_cast, ui.max_chase:Get()) then
        set_fsm(FSM.GAP_CLOSE, ctx.time)
    else
        S.disengage_until = ctx.time + 0.75
        set_fsm(FSM.DISENGAGE, ctx.time)
    end
end

-- --------------------------------------------------------------------------
-- Central action arbiter
-- --------------------------------------------------------------------------

local function new_actions()
    return {}
end

local function propose(actions, kind, priority, confidence, cost, data)
    data = data or {}
    data.kind = kind
    data.priority = priority
    data.confidence = confidence or 0
    data.cost = cost or 0
    data.target_index = S.target_index
    data.target_epoch = S.target_epoch
    data.hold_epoch = S.hold_epoch
    data.map_epoch = S.map_epoch
    actions[#actions + 1] = data
end

local function rank_actions(actions)
    table.sort(actions, function(a, b)
        if a.priority ~= b.priority then return a.priority > b.priority end
        if a.confidence ~= b.confidence then return a.confidence > b.confidence end
        return a.cost < b.cost
    end)
    return actions
end

local function action_epochs_valid(action)
    if action
        and action.kind == "ACTIVATE_REMNANT"
        and committed_remnant_transaction() then
        return action.hold_epoch == S.hold_epoch
            and action.map_epoch == S.map_epoch
    end
    return action
        and action.target_epoch == S.target_epoch
        and action.hold_epoch == S.hold_epoch
        and action.map_epoch == S.map_epoch
        and action.target_index == S.target_index
end

local function position_in_cast_range(hero, ability, position, fallback)
    local hero_pos = origin(hero)
    if not hero_pos or not position or not ability then return false end
    return distance2d(hero_pos, position) <= cast_range(hero, ability, fallback or 0) + 25
end

-- Umbrella's Humanizer spam-filters orders: once its per-tick budget is used
-- up the order is dropped before it reaches the game, while the cast helper
-- still reports success. That is the same silent failure Safe Mode produces --
-- order "sent", no charge spent, nothing happens -- and it also wastes bounded
-- retry attempts on casts that were never going to land. Ability casts consult
-- the budget first. Movement and attack orders deliberately do not: they are
-- high frequency and self-correcting, and gating them would stall orbwalking.
-- If Humanizer is absent the checks fall back to "allowed" and nothing changes.
local order = {}

-- Why a cast that "succeeded" did nothing. Every silent-failure cause hit in
-- this script produces the same surface symptom -- pcall returns true, no
-- charge is spent, nothing happens -- so this names the actual cause instead
-- of leaving it to guesswork. Call it after a cast failed to consume a charge.
function order.diagnose(hero, ability, position)
    if safe(function() return Humanizer.OrdersCanBeCastedThisTick() end, 1) <= 0 then
        return "Humanizer spam filter is holding orders this tick"
    end
    if ability and position then
        local hero_pos = origin(hero)
        local reach = hero_pos and distance2d(hero_pos, position) or 0
        local range = cast_range(hero, ability, 0)
        if range > 0 and reach > range + 25 then
            return string.format(
                "cast was out of range (%.0f vs %.0f) - Dota discards these silently",
                reach, range
            )
        end
    end
    if order.needs_minimap(position) then
        return "cast position is outside the server camera bounds - needs the minimap flag"
    end
    if ability and not safe(function()
        return Ability.IsCastable(ability, NPC.GetMana(hero))
    end, true) then
        return "ability reports not castable (cooldown, mana, or charges)"
    end
    if not hero_can_cast(hero) then
        return "Ember cannot cast right now (stunned, silenced, hexed or out of game)"
    end
    -- Nothing local explains it, so the order was dropped before the game saw
    -- it. Safe Mode is by far the most common cause of that.
    return "order was dropped before reaching the game - check Umbrella Safe Mode"
end

-- Dota validates that an order originates from within the player's camera
-- view. A cast aimed outside the server camera bounds is rejected outright --
-- which is why nothing happened when Ember was off screen -- unless the order
-- is flagged as coming from the minimap. Flag it only when actually needed, so
-- ordinary on-screen casts keep their normal path.
function order.needs_minimap(position)
    if not position then return false end
    return safe(function()
        return Humanizer.IsInServerCameraBounds(position)
    end, true) == false
end

function order.allowed()
    local capacity = safe(function()
        return Humanizer.OrdersCanBeCastedThisTick()
    end, nil)
    if type(capacity) == "number" and capacity <= 0 then return false end
    if safe(function() return Humanizer.IsSafeToCastOrder() end, nil) == false then
        return false
    end
    return true
end

local function cast_position(ability, position, identifier, execute_fast, force_minimap)
    if not ability or not position then return false end
    if not order.allowed() then return false end
    -- Stamp Remnant orders so the real cast point can be measured from the gap
    -- between ordering and the Remnant entity appearing. GetCastPoint falls
    -- back to 0 when it does not resolve, and a missing cast point shortens
    -- every predicted flight, so this is worth checking rather than trusting.
    if ability == S.abilities.remnant then
        S.last_remnant_order_at = now()
    end
    local ok = pcall(
        Ability.CastPosition,
        ability,
        position,
        false,
        true,
        execute_fast == true,
        identifier,
        force_minimap == true or order.needs_minimap(position)
    )
    return ok
end

local function cast_position_immediate(ctx, ability, position, identifier)
    if not ctx or not ctx.player or not ctx.hero or not ability or not position then return false end
    if not order.allowed() then return false end
    -- Use UCZone's lower-level order surface for mid-Activate R. This bypasses
    -- Ability.CastPosition's ordinary scheduler, which can defer an otherwise
    -- legal Scepter Remnant until Ember emerges at the destination.
    return pcall(
        Player.PrepareUnitOrders,
        ctx.player,
        Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION,
        nil,
        position,
        ability,
        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
        ctx.hero,
        false,
        false,
        true,
        true,
        identifier,
        -- Trailing arg is force_minimap: the dance feeds Remnants at up to
        -- 3000 range, which is regularly outside the camera view, and those
        -- casts are discarded without it.
        order.needs_minimap(position)
    )
end

local function cast_no_target(ability, identifier)
    if not ability then return false end
    if not order.allowed() then return false end
    return pcall(Ability.CastNoTarget, ability, false, true, false, identifier)
end

-- Ability.CastTarget(ability, target, [queue], [push], [execute_fast],
-- [identifier]) -- same parameter shape as CastNoTarget with the target
-- inserted, verified against the API docs rather than assumed.
local function cast_target(ability, target, identifier)
    if not ability or not target then return false end
    if not order.allowed() then return false end
    return pcall(Ability.CastTarget, ability, target, false, true, false, identifier)
end

local function issue_move(ctx, position, identifier)
    if not ctx.player or not position then return false end
    -- Argument 9 is show_effects: with it false the hero slid around silently,
    -- which is why orbwalk steps had no visible right-click marker. Turning it
    -- on makes Dota draw its normal move-order click at each ordered position.
    return pcall(
        Player.PrepareUnitOrders,
        ctx.player,
        Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION,
        nil,
        position,
        nil,
        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
        ctx.hero,
        false,
        safe(function() return ui.show_order_clicks:Get() end, true),
        true,
        false,
        identifier,
        false
    )
end

local function issue_attack(ctx, identifier)
    if not ctx.player or not valid_target(ctx.hero, ctx.target) then return false end
    return pcall(Player.AttackTarget, ctx.player, ctx.hero, ctx.target, false, true, false, identifier, false)
end

local function validate_before_issue(ctx, action)
    if not action_epochs_valid(action) then return false end
    local live_time = now()
    local allowed = evaluate_training_gate(live_time, true)
    local dance_chain_order = action.kind == "DANCE_CHAIN_REMNANT"
        or action.kind == "DANCE_CHAIN_REFRESHER"
    local correction_order = action.kind == "CORRECT_REMNANT"
    local sleight_chains_order = action.kind == "SLEIGHT_CHAINS"
    local sleight_handoff_order = action.kind == "START_REMNANT"
        and action.sleight_handoff == true
    local dance_order = action.kind == "DANCE_REFRESHER"
        or dance_chain_order
        or action.kind == "DANCE_HOLD"
        or action.dance == true
        or (action.kind == "ACTIVATE_REMNANT" and S.tx and S.tx.dance == true)
    local hover_gated_order = action.kind == "DANCE_REFRESHER"
        or (action.kind == "START_REMNANT" and action.dance == true)
    local required_bind_down
    if dance_order then
        required_bind_down = bind_is_down(ui.dance_combo)
    else
        required_bind_down = bind_is_down(ui.combo)
    end
    -- Auto Chains During Sleight is its own controller: the player casts
    -- Sleight of Fist on their own keybind, so no trainer bind is held and
    -- S.held is false. Its own toggle plus the live sleight_in_progress and
    -- sleight_chains_ready checks below are the authority for this one order.
    if sleight_chains_order then
        required_bind_down = true
    end
    -- The dedicated dance bind is an independent controller. The normal
    -- "Enable Sticky Combo" switch may disable ordinary combo orders without
    -- making an assigned Dancing Ember key silently inert.
    if not allowed
        or (not ui.enabled:Get() and not dance_order and not sleight_chains_order)
        or (not S.held and not sleight_chains_order)
        or not required_bind_down then return false end
    if safe(function() return GameRules.IsPaused() end, false) then return false end
    if safe(function() return Input.IsInputCaptured() end, false) then return false end
    local live_hero = get_local_ember()
    if not same_entity(live_hero, ctx.hero) then return false end
    if dance_chain_order or correction_order then
        if not entity_alive(live_hero) then return false end
        if (action.kind == "DANCE_CHAIN_REMNANT" or correction_order)
            and not dance.chain_remnant_ready(live_hero, S.abilities.remnant) then return false end
    elseif sleight_chains_order then
        if not sleight_in_progress(live_hero)
            or not sleight_chains_ready(live_hero, S.abilities.chains) then return false end
    elseif sleight_handoff_order then
        if not dance.chain_remnant_ready(live_hero, S.abilities.remnant) then return false end
    elseif not hero_can_act(live_hero) then
        return false
    end
    if hover_gated_order then
        local live_cursor = safe(function() return Input.GetWorldCursorPos() end, nil)
        local live_target_pos = valid_target(live_hero, ctx.target) and origin(ctx.target) or nil
        if not live_cursor or not live_target_pos
            or distance2d(live_cursor, live_target_pos) > ui.dance_hover_radius:Get() then return false end
    end
    if dance_chain_order then
        local chain_target = action.chain_target
        local live_target_pos = valid_target(live_hero, chain_target) and origin(chain_target) or nil
        local cast_origin = action.cast_origin or origin(live_hero)
        if not cast_origin or not live_target_pos then return false end
        if action.cursor_authorized then
            local live_cursor = safe(function() return Input.GetWorldCursorPos() end, nil)
            if not live_cursor
                or distance2d(live_cursor, live_target_pos) > ui.dance_hover_radius:Get() then return false end
        elseif distance2d(cast_origin, live_target_pos)
            > dance.chain_cast_range(live_hero) + 50 then
            return false
        end
    end
    if correction_order then
        local live_target_pos = valid_target(live_hero, ctx.target) and origin(ctx.target) or nil
        local cast_origin = action.cast_origin or origin(live_hero)
        if not cast_origin or not live_target_pos or not action.position then return false end
        local live_range = ability_ranges(live_hero, ctx.target).remnant_cast
        if distance2d(cast_origin, action.position) > live_range + 50 then return false end
    end
    if sleight_chains_order then
        local intended_target = action.cast_target or ctx.target
        if not valid_target(live_hero, intended_target) then return false end
        local hero_pos, target_pos = origin(live_hero), origin(intended_target)
        local trigger_radius = action.trigger_radius or 96
        if not hero_pos or not target_pos
            or distance2d(hero_pos, target_pos) > trigger_radius then return false end
        local ranges = ability_ranges(live_hero, intended_target)
        local chance = chains_hit_chance(live_hero, intended_target, ranges)
        if action.require_guaranteed and chance < 0.999 then return false end
    end
    if action.kind ~= "MOVE_CURSOR"
        and action.kind ~= "ACTIVATE_REMNANT"
        and action.kind ~= "DANCE_CHAIN_REMNANT"
        and action.kind ~= "CORRECT_REMNANT"
        and action.kind ~= "DANCE_CHAIN_REFRESHER"
        and action.kind ~= "DANCE_HOLD"
        and not (action.kind == "START_REMNANT" and action.dance)
        and not valid_target(ctx.hero, ctx.target) then return false end
    return true
end

local function begin_remnant_transaction(ctx, action)
    local remnant = S.abilities.remnant
    local activate = S.abilities.activate
    local guard = S.abilities.guard
    local intercept = action.intercept
    local dancing = action.dance == true
    local reconnecting = action.reconnect == true
    if not ui.use_remnant:Get() or not ui.use_activate:Get() then return false end
    if dancing then
        if S.control_mode ~= "DANCE"
            or S.dance_d_used
            or not bind_is_down(ui.dance_combo)
            or not has_remnant_scepter_upgrade(ctx.hero, remnant) then return false end
    else
        if not reconnecting
            and (S.engagement_started or S.opening_remnant_committed) then return false end
        if not reconnecting
            and not action.sleight_handoff
            and ctx.distance <= ctx.ranges.sticky_exit + 20 then return false end
    end
    if not intercept or not intercept.profile then return false end
    local remnant_ready = action.sleight_handoff
        and dance.chain_remnant_ready(ctx.hero, remnant)
        or ability_usable(ctx.hero, remnant, ui.mana_reserve:Get())
    if not remnant_ready then return false end
    if not activate then
        log_decision("SAVE REMNANT: Activate Fire Remnant unavailable")
        return false
    end
    if not dancing and ui.use_guard:Get() and (not guard
        or safe(function() return Ability.GetLevel(guard) end, 0) <= 0) then
        log_decision("SAVE REMNANT: Flame Guard unavailable")
        return false
    end
    local remnant_cost = safe(function() return Ability.GetManaCost(remnant) end, math.huge)
    local activate_cost = safe(function() return Ability.GetManaCost(activate) end, math.huge)
    local guard_cost = not dancing and ui.use_guard:Get()
        and safe(function() return Ability.GetManaCost(guard) end, math.huge) or 0
    local mana = safe(function() return NPC.GetMana(ctx.hero) end, 0)
    local sequence_mana = remnant_cost + activate_cost + guard_cost + ui.mana_reserve:Get()
    if mana < sequence_mana then
        log_decision(string.format(
            dancing
                and "DANCING EMBER: need %.0f mana for Remnant + D + reserve"
                or "SAVE REMNANT: need %.0f mana for Remnant + D + Guard + reserve",
            sequence_mana
        ))
        return false
    end
    -- Ability.GetCastRange may still report Ember's base 1400 range on the
    -- Scepter frame. Use the already verified effective 1400/3000 range from
    -- the context so a legal upgraded cast is not rejected at the final gate.
    if distance2d(ctx.hero_pos, action.position) > ctx.ranges.remnant_cast + 25 then return false end
    local safe_destination, why
    if dancing then
        safe_destination = safe(function() return GridNav.IsTraversable(action.position) end, true)
        why = safe_destination and "safe" or "cursor destination not traversable"
    else
        safe_destination, why = destination_safety(
            ctx.hero,
            ctx.target,
            action.position,
            intercept.predicted_target,
            intercept.tolerance
        )
    end
    if not safe_destination then
        log_decision("SAVE REMNANT: " .. why)
        return false
    end
    scan_owned_remnants(ctx.hero, ctx.time, true)
    local baseline_indices = {}
    for index in pairs(S.remnants) do baseline_indices[index] = true end
    if remnant_count() > 0 then
        log_decision("SAVE REMNANT: active remnant path would consume reserves")
        return false
    end
    local charges = safe(function() return Ability.GetCurrentCharges(remnant) end, 0)
    local reserve = dancing and 0 or plan.remnant_reserve(ctx.hero)
    local remnant_lethal, remnant_damage, effective_hp = remnant_high_confidence_kill(
        ctx.hero,
        ctx.target,
        action.position,
        intercept.predicted_target,
        intercept.confidence
    )
    local last_allowed = dancing or (ui.allow_last_remnant:Get() and remnant_lethal)
    if charges <= reserve and not last_allowed then
        log_decision(string.format(
            "SAVE REMNANT: reserve policy (%d charges, reserving %d)", charges, reserve
        ))
        return false
    end
    if charges <= reserve and last_allowed then
        log_decision(string.format(
            "HIGH-CONFIDENCE LAST REMNANT: %.0f estimated vs %.0f effective HP",
            remnant_damage,
            effective_hp
        ))
    end
    if plan.fountain_blocked(ctx.hero, action.position) then
        log_decision("SAVE REMNANT: gap close would land in the enemy fountain")
        return false
    end
    if not cast_position(
        remnant,
        action.position,
        dancing and "ember_sticky_dance_remnant"
            or (action.sleight_handoff
                and "ember_sticky_sleight_handoff_remnant"
                or (reconnecting
                    and "ember_sticky_reconnect_remnant"
                    or "ember_sticky_remnant_place")),
        action.sleight_handoff == true,
        false
    ) then return false end
    S.combo_stage = COMBO_STAGE.REMNANT_TRAVEL
    if dancing then
        S.dance_visited_indices = S.dance_visited_indices or {}
        if ctx.target_index >= 0 then
            S.dance_visited_indices[ctx.target_index] = true
        end
    end
    S.tx = {
        kind = "REMNANT",
        dance = dancing,
        reconnect = reconnecting,
        phase = "WAIT_PLACE_CONFIRM",
        target_index = ctx.target_index,
        target_epoch = ctx.target_epoch,
        hold_epoch = ctx.hold_epoch,
        map_epoch = ctx.map_epoch,
        destination = action.position,
        original_destination = action.position,
        sticky_exit = ctx.ranges.sticky_exit,
        profile = intercept.profile,
        baseline_indices = baseline_indices,
        charges_before = charges,
        entity_deadline = ctx.time
            + (intercept.turn_delay or 0)
            + intercept.profile.placement_cast_point
            + 0.85,
        outbound_travel_duration = distance2d(ctx.hero_pos, action.position)
            / intercept.profile.placement_speed,
        fast_activation_at = nil,
        activation_deadline = ctx.time + intercept.outbound_eta + 2.75,
        remnant_index = nil,
        placement_confirmed = false,
        activation_attempts = 0,
        activation_order_at = nil,
        correction_attempts = 0,
        correction_pending_charges = nil,
        correction_pending_at = nil,
        correction_destination = nil,
        correction_cast_origin = nil,
        correction_confirmed = false,
        chain_casts = 0,
        chain_pending_charges = nil,
        chain_pending_at = nil,
        chain_pending_target_index = nil,
        chain_pending_anchor_position = nil,
        last_chain_cast_at = -100,
        last_chain_target_index = ctx.target_index,
        chain_visited_indices = dancing and S.dance_visited_indices
            or { [ctx.target_index] = true },
        chain_anchor_position = action.position,
        last_plan_at = ctx.time,
    }
    if dancing then S.dance_last_anchor = action.position end
    if reconnecting then
        S.last_reconnect_remnant_at = ctx.time
        S.attack_contact_lost_since = nil
    end
    return true
end

local function execute_action(ctx, action)
    if not action or not validate_before_issue(ctx, action) then return false end
    local time = ctx.time
    local ability_gap = ui.action_gap_ms:Get() / 1000
    local move_gap = ui.move_gap_ms:Get() / 1000
    local issued = false

    if action.kind == "ATTACK" then
        -- Mirrors plan.propose_attack: Flame Guard only holds the attack back while
        -- Guard is genuinely obtainable. This duplicate gate is why attacks
        -- still refused after the proposer was fixed -- ATTACK was proposed
        -- every tick and silently rejected here, leaving only the orbwalk move
        -- so Ember trailed the cursor without ever swinging.
        if not S.guard_stage_completed then return false end
        if ui.use_guard:Get()
            and not S.opening_pressure_completed
            and not flame_guard_active(ctx.hero)
            and hero_can_cast(ctx.hero)
            and ability_usable(ctx.hero, S.abilities.guard, ui.mana_reserve:Get()) then
            return false
        end
        local same_attack_target = S.last_attack_target == ctx.target_index
        local refresh_blocked = not ui.orbwalk:Get()
            and time - S.last_attack < ui.attack_refresh_ms:Get() / 1000
        if same_attack_target and (time < S.next_attack or refresh_blocked) then return false end
        issued = issue_attack(ctx, "ember_sticky_attack")
        if issued then
            S.combo_stage = COMBO_STAGE.MELEE
            local attack_point = safe(function() return NPC.GetAttackAnimPoint(ctx.hero) end, 0.30)
            local seconds = safe(function() return NPC.GetSecondsPerAttack(ctx.hero, false) end, 1.7)
            local expected_start = math.max(time, S.attack_ready_at or time)
            S.last_attack = time
            S.last_attack_target = ctx.target_index
            S.post_guard_attack_orders = S.post_guard_attack_orders + 1
            if S.post_guard_attack_orders >= 2 and not S.opening_pressure_completed then
                S.opening_attack_confirm_at = expected_start + math.max(0.08, attack_point + 0.03)
            end
            local ready_buffer = ui.orbwalk:Get() and ui.orb_attack_buffer_ms:Get() / 1000
                or seconds * 0.18
            S.attack_ready_at = expected_start + seconds
            S.next_attack = math.max(
                expected_start + attack_point + 0.08,
                S.attack_ready_at - ready_buffer
            )
            S.move_after = expected_start + math.max(0.08, attack_point + 0.03)
        end
    elseif action.kind == "DANCE_HOLD" then
        if time - S.last_dance_hold_at < 0.06 or not ctx.player then return false end
        issued = pcall(
            Player.HoldPosition,
            ctx.player,
            ctx.hero,
            false,
            true,
            true,
            "ember_sticky_dance_hold"
        )
        if issued then S.last_dance_hold_at = time end
    elseif action.kind == "MOVE" or action.kind == "MOVE_CURSOR" then
        if time < S.move_after or time - S.last_move < move_gap then return false end
        local same_destination = S.last_move_position
            and distance2d(S.last_move_position, action.position) < 42
        if same_destination and time - S.last_move < math.max(move_gap, 0.18) then return false end
        -- Cursor-follow orders intentionally rely on Dota's pathfinder. A
        -- straight GridNav path test rejects valid mouse destinations around
        -- trees, ramps, and corners even though the hero can route there.
        if action.kind ~= "MOVE_CURSOR"
            and not action.follow_cursor
            and not traversable(ctx.hero_pos, action.position, false) then return false end
        issued = issue_move(
            ctx,
            action.position,
            action.kind == "MOVE_CURSOR" and "ember_sticky_cursor_move" or "ember_sticky_move"
        )
        if issued then S.last_move = time; S.last_move_position = action.position end
    elseif action.kind == "FLAME_GUARD" then
        if time - S.last_ability < ability_gap then return false end
        if not ui.use_guard:Get() or not hero_can_cast(ctx.hero)
            or not ability_usable(ctx.hero, S.abilities.guard, ui.mana_reserve:Get())
            or flame_guard_active(ctx.hero)
            or ctx.distance > ctx.ranges.sticky_exit + 65 then return false end
        issued = cast_no_target(S.abilities.guard, "ember_sticky_flame_guard")
        if issued then
            S.combo_stage = COMBO_STAGE.GUARD
            S.guard_cast_at = time
        end
    elseif action.kind == "SLEIGHT_CHAINS" then
        local intended_target = action.cast_target or ctx.target
        if not ui.use_chains:Get()
            or not ui.auto_sleight_chains:Get()
            or not sleight_in_progress(ctx.hero)
            or not sleight_chains_ready(ctx.hero, S.abilities.chains)
            or plan.spell_immune(intended_target)
            or not valid_target(ctx.hero, intended_target) then return false end
        local hero_pos, target_pos = origin(ctx.hero), origin(intended_target)
        if not hero_pos or not target_pos
            or distance2d(hero_pos, target_pos) > (action.trigger_radius or 96) then return false end
        local ranges = ability_ranges(ctx.hero, intended_target)
        local chance, eligible = chains_hit_chance(ctx.hero, intended_target, ranges)
        if action.require_guaranteed and chance < 0.999 then return false end
        issued = cast_no_target(S.abilities.chains, "ember_sticky_sleight_chains")
        if issued then
            S.combo_stage = COMBO_STAGE.CONTROL
            S.sleight_role = chance >= 0.999
                and "SLEIGHT -> CHAINS (GUARANTEED POOL)"
                or string.format("SLEIGHT -> CHAINS (%.0f%% CROWD CHANCE)", chance * 100)
            if S.sleight_chain then
                S.sleight_chain.pending_at = time
                S.sleight_chain.eligible_at_cast = eligible
            end
        end
    elseif action.kind == "CHAINS" then
        if time - S.last_ability < ability_gap then return false end
        if not ui.use_chains:Get() or not hero_can_cast(ctx.hero)
            or not ability_usable(ctx.hero, S.abilities.chains, ui.mana_reserve:Get()) then return false end
        if safe(function() return NPC.HasState(ctx.target, Enum.ModifierState.MODIFIER_STATE_ROOTED) end, false) then return false end
        if plan.spell_immune(ctx.target) then return false end
        local live_time = now()
        local gaining_now = distance_gain_evidence(ctx.hero, ctx.target, ctx.ranges, live_time)
        local live_hero_pos, live_target_pos = origin(ctx.hero), origin(ctx.target)
        local live_distance = live_hero_pos and live_target_pos
            and distance2d(live_hero_pos, live_target_pos) or math.huge
        local outside_attack_now = live_distance > ctx.ranges.attack + 20
        local fresh_distance_gain = S.distance_gain_latched
            and S.distance_gain_since
            and live_time - S.distance_gain_since >= 0.10
            and gaining_now
        local escape_rescue_ready = outside_attack_now
            and S.guard_stage_completed
            and (not ui.use_guard:Get() or flame_guard_active(ctx.hero))
        if not S.engagement_started
            or not (S.opening_pressure_completed or escape_rescue_ready)
            or not (outside_attack_now or fresh_distance_gain) then return false end
        local chance = chains_hit_chance(ctx.hero, ctx.target, ctx.ranges)
        if chance < ui.chains_confidence:Get() / 100 then return false end
        issued = cast_no_target(S.abilities.chains, "ember_sticky_chains")
        if issued then
            S.combo_stage = COMBO_STAGE.CONTROL
            S.distance_gain_since = nil
            S.distance_gain_latched = false
        end
    elseif action.kind == "SLEIGHT_KS" then
        if time - S.last_ability < ability_gap then return false end
        if not ui.use_sleight:Get()
            or not ui.kill_secure:Get()
            or not S.engagement_started
            or not S.opening_pressure_completed
            or not hero_can_cast(ctx.hero)
            or not ability_usable(ctx.hero, S.abilities.sleight, ui.mana_reserve:Get())
            or not position_in_cast_range(ctx.hero, S.abilities.sleight, action.position, 700) then return false end
        local intended_target = action.cast_target or ctx.target
        local intended_index = entity_index(intended_target)
        if intended_index < 0
            or S.sleight_kill_committed_index == intended_index then return false end
        if not valid_target(ctx.hero, intended_target)
            or not sleight_area_contains(
                intended_target,
                action.position,
                ctx.ranges,
                action.prediction_slack or 60
            ) then return false end
        local lethal = can_sleight_kill(ctx.hero, intended_target, ctx.ranges)
        if not lethal then return false end
        issued = cast_position(S.abilities.sleight, action.position, "ember_sticky_sleight_ks")
        if issued then
            -- Level-25 can leave another Sleight charge immediately usable.
            -- Commit this target on the first order so it can never consume a
            -- second kill-secure charge before the first Sleight hit resolves.
            S.sleight_kill_committed_index = intended_index
            S.combo_stage = COMBO_STAGE.FINISH
            S.sleight_handoff = {
                excluded_index = entity_index(intended_target),
                ordered_at = time,
                expires_at = time + 1.25,
            }
            if ui.auto_sleight_chains:Get() and ui.use_chains:Get() then
                S.sleight_chain = {
                    target = intended_target,
                    target_index = intended_index,
                    ordered_at = time,
                    expires_at = time + 5.0,
                    pending_at = nil,
                }
            end
        end
    elseif action.kind == "PRELOAD_REMNANT" then
        -- Deliberately does NOT open a transaction: a transaction immediately
        -- arms D, which would dash Ember off the hero it is still killing. The
        -- remnant is parked and left alone until the current target dies.
        if time - S.last_ability < ability_gap then return false end
        if not ui.preload_next:Get() or S.tx or S.preload then return false end
        if not hero_can_cast(ctx.hero)
            or not ability_usable(ctx.hero, S.abilities.remnant, ui.mana_reserve:Get()) then
            return false
        end
        local charges = safe(function()
            return Ability.GetCurrentCharges(S.abilities.remnant)
        end, 0)
        if charges <= plan.remnant_reserve(ctx.hero) then return false end
        issued = cast_position(
            S.abilities.remnant,
            action.position,
            "ember_sticky_preload_remnant",
            false,
            false
        )
        if issued then
            S.preload = {
                -- cast_position only reports that the pcall succeeded, not that
                -- the game accepted the order, and orders are routinely dropped
                -- on this build (D needs up to 8 retries). Placement is
                -- confirmed and retried below before this counts as parked.
                confirmed = false,
                attempts = 1,
                last_order_at = time,
                charges_before = charges,
                target = action.preload_target,
                target_index = entity_index(action.preload_target),
                -- Remember WHICH hero we were killing. The payoff must key off
                -- that hero dying, not off S.target going empty: in Free mode
                -- the cursor re-acquires a new target almost every tick, so
                -- S.target is basically never invalid and the dash never fired.
                killing_target = ctx.target,
                killing_index = ctx.target_index,
                position = action.position,
                ordered_at = time,
                expires_at = time + 12.0,
            }
        end
    elseif action.kind == "START_REMNANT" then
        -- Opening R has no artificial shared-ability delay. Live castability,
        -- mana, charge, range, target, and destination checks remain the gate.
        issued = begin_remnant_transaction(ctx, action)
    elseif action.kind == "CORRECT_REMNANT" then
        local tx = S.tx
        local remnant = S.abilities.remnant
        if not tx or tx.dance or not tx.activation_order_at
            or (tx.phase ~= "WAIT_ACTIVATE_START"
                and tx.phase ~= "WAIT_ACTIVATE_COMPLETE"
                and tx.phase ~= "WAIT_ARRIVAL")
            or tx.correction_confirmed
            or tx.correction_pending_charges
            or (tx.correction_attempts or 0) >= 3
            or time - (tx.correction_last_order_at or -100) < 0.045
            or not dance.chain_remnant_ready(ctx.hero, remnant) then return false end
        local charges = safe(function() return Ability.GetCurrentCharges(remnant) end, 0)
        if charges <= plan.remnant_reserve(ctx.hero) then return false end
        issued = cast_position(
            remnant,
            action.position,
            "ember_sticky_midflight_correction",
            true,
            false
        )
        if issued then
            tx.correction_attempts = (tx.correction_attempts or 0) + 1
            tx.correction_pending_charges = charges
            tx.correction_pending_at = time
            tx.correction_last_order_at = time
            tx.correction_destination = action.position
            tx.correction_cast_origin = action.cast_origin
            tx.correction_profile = action.profile
            tx.arrival_deadline = math.max(tx.arrival_deadline or time, time + 0.50)
        end
    elseif action.kind == "DANCE_CHAIN_REMNANT" then
        local tx = S.tx
        local remnant = S.abilities.remnant
        -- WAIT_ARRIVAL only: during the D cast phases this order cancels the
        -- activation instead of chaining off it.
        if not tx or not tx.dance
            or tx.phase ~= "WAIT_ARRIVAL"
            or not tx.dance_travel_confirmed
            or (not S.dance_d_used and not tx.dance_d_ordered)
            or time - (tx.last_chain_cast_at or -100) < 0.03
            or not dance.chain_remnant_ready(ctx.hero, remnant) then return false end
        local charges = safe(function() return Ability.GetCurrentCharges(remnant) end, 0)
        if tx.chain_pending_charges and charges >= tx.chain_pending_charges then return false end
        issued = cast_position_immediate(
            ctx,
            remnant,
            action.position,
            "ember_sticky_dance_chain_remnant"
        )
        if issued then
            if action.reset_cycle then
                S.dance_visited_indices = {}
                tx.chain_visited_indices = S.dance_visited_indices
                if (tx.last_chain_target_index or -1) >= 0 then
                    tx.chain_visited_indices[tx.last_chain_target_index] = true
                end
            end
            tx.chain_casts = (tx.chain_casts or 0) + 1
            tx.chain_pending_charges = charges
            tx.chain_pending_at = time
            tx.chain_pending_target_index = entity_index(action.chain_target)
            tx.chain_pending_anchor_position = action.position
            -- Mark the hop as PREVIOUS on order, not on confirmation. Promotion
            -- used to wait for charges to visibly drop, so until then the
            -- planner kept re-selecting the same hero -- with one enemy under
            -- the cursor that was a burst of remnants at that single target.
            -- Deliberately not marked visited here: visited is what removes a
            -- hero from the whole pass, and an order that never actually fired
            -- would then burn that hero and cut the chain short. "Previous"
            -- only blocks the immediate re-pick; confirmation still owns
            -- visited, so an unfired hop stays available later in the pass.
            local ordered_index = entity_index(action.chain_target)
            if ordered_index >= 0 then
                tx.last_chain_target_index = ordered_index
            end
            tx.last_chain_cast_at = time
            local hop_eta = action.profile
                and remnant_arrival_time(
                    action.cast_origin or ctx.hero_pos,
                    action.position,
                    action.profile
                )
                or 0.85
            tx.arrival_deadline = math.max(
                tx.arrival_deadline or time,
                time + hop_eta + 0.35
            )
        end
    elseif action.kind == "DANCE_CHAIN_REFRESHER" then
        local tx = S.tx
        local remnant = S.abilities.remnant
        local charges = remnant
            and safe(function() return Ability.GetCurrentCharges(remnant) end, 0) or 0
        if not tx or not tx.dance
            or (tx.phase ~= "WAIT_ACTIVATE_START"
                and tx.phase ~= "WAIT_ACTIVATE_COMPLETE"
                and tx.phase ~= "WAIT_ARRIVAL")
            or not S.dance_d_used
            or not ui.dance_refresher:Get()
            or charges > 0
            or time - (tx.last_refresher_order_at or -100) < 0.18
            or not ability_usable(ctx.hero, action.ability, 0) then return false end
        issued = cast_no_target(action.ability, "ember_sticky_dance_chain_refresher")
        if issued then
            tx.last_refresher_order_at = time
            tx.arrival_deadline = math.max(tx.arrival_deadline or time, time + 1.25)
        end
    elseif action.kind == "ACTIVATE_REMNANT" then
        local instant_scepter_bounce = S.tx
            and S.tx.kind == "REMNANT"
            and ((S.tx.profile and S.tx.profile.scepter)
                or S.tx.correction_confirmed
                or S.tx.correction_pending_charges ~= nil)
        local committed_dance = S.tx
            and S.tx.kind == "REMNANT"
            and S.tx.dance
            and S.tx.placement_confirmed
        if not instant_scepter_bounce and time - S.last_ability < ability_gap then return false end
        local activate_ready = committed_dance
            and committed_dance_activate_ready(
                ctx.hero,
                S.abilities.activate,
                ui.mana_reserve:Get()
            )
            or activate_usable(ctx.hero, S.abilities.activate, ui.mana_reserve:Get())
        if not ui.use_activate:Get() or not hero_can_cast(ctx.hero)
            or not activate_ready then return false end
        local active_remnants = remnant_count()
        local confirmed_fallback = S.tx and S.tx.kind == "REMNANT" and S.tx.placement_confirmed
        local maximum_active = S.tx and S.tx.correction_confirmed and 2 or 1
        if (active_remnants > maximum_active and not (S.tx and S.tx.allow_multiple_active))
            or (active_remnants < 1 and not confirmed_fallback) then return false end
        if S.tx and S.tx.dance and S.dance_d_used then return false end
        issued = cast_position(
            S.abilities.activate,
            action.position,
            "ember_sticky_remnant_activate",
            true,
            true
        )
        if issued and S.tx then
            if S.tx.dance then
                S.tx.dance_d_ordered = true
            end
            S.tx.phase = "WAIT_ACTIVATE_START"
            S.combo_stage = COMBO_STAGE.ACTIVATE
            S.tx.activation_attempts = (S.tx.activation_attempts or 0) + 1
            S.tx.activation_order_at = time
            S.tx.activation_started_at = nil
            S.tx.activation_origin = origin(ctx.hero)
            -- Displacement must be measured from the FIRST D order, never from
            -- the latest retry. Retrying every 45ms reset this baseline faster
            -- than Ember could cover the 90-unit threshold, so the dash was
            -- never detected, D was re-ordered ~25 times per hop, and the feed
            -- loop never got the handoff.
            S.tx.activation_first_at = S.tx.activation_first_at or time
            S.tx.activation_first_origin = S.tx.activation_first_origin or origin(ctx.hero)
            S.tx.remnants_before_activate = active_remnants
            -- Remember which remnant this D was aimed at so its disappearance
            -- can confirm travel even while the chain adds new ones.
            S.tx.activation_remnant_index = S.tx.remnant_index
            local activation_time = S.tx.profile
                and remnant_activation_time(ctx.hero_pos, action.position, S.tx.profile, false)
                or 0.60
            S.tx.arrival_deadline = time + activation_time + 0.70
        end
    elseif action.kind == "SUPPORT_ITEM_TARGET" then
        if time - S.last_ability < ability_gap then return false end
        if not ui.support_items:Get() or not hero_can_cast(ctx.hero)
            or not valid_target(ctx.hero, action.cast_target)
            or not plan.item_usable(ctx.hero, action.ability) then return false end
        issued = cast_target(action.ability, action.cast_target, "ember_sticky_support_item_target")
    elseif action.kind == "SUPPORT_ITEM" then
        if time - S.last_ability < ability_gap then return false end
        if not ui.support_items:Get() or not hero_can_cast(ctx.hero)
            or not plan.item_usable(ctx.hero, action.ability) then return false end
        issued = cast_no_target(action.ability, "ember_sticky_support_item")
    elseif action.kind == "PHASE_BOOTS" then
        if time - S.last_ability < ability_gap then return false end
        if not ui.use_items:Get() or not hero_can_cast(ctx.hero)
            or not ability_usable(ctx.hero, action.ability, ui.mana_reserve:Get()) then return false end
        issued = cast_no_target(action.ability, "ember_sticky_phase_boots")
        if issued then S.phase_walk_until = time + 0.55 end
    elseif action.kind == "DANCE_REFRESHER" then
        if S.control_mode ~= "DANCE"
            or not ui.dance_refresher:Get()
            or not hero_can_cast(ctx.hero)
            or not ability_usable(ctx.hero, action.ability, 0) then return false end
        local remnant = S.abilities.remnant
        local charges = remnant
            and safe(function() return Ability.GetCurrentCharges(remnant) end, 0) or 0
        if charges > 0 or remnant_count() > 0 then return false end
        issued = cast_no_target(action.ability, "ember_sticky_dance_refresher")
    end

    if issued then
        S.last_action = time
        if action.kind ~= "MOVE" and action.kind ~= "ATTACK" then S.last_ability = time end
        S.last_dedupe_key = action.kind
        S.action = action.label or action.kind
        log_decision(action.reason or S.action)
    end
    return issued
end

local function arm_active_sleight_chain(hero, time)
    if not ui.auto_sleight_chains:Get() or not sleight_in_progress(hero) then return false end
    if S.sleight_chain then return true end

    if S.control_mode == "COMBO" and valid_target(hero, S.target) then
        S.sleight_chain = {
            target = S.target,
            target_index = S.target_index,
            ordered_at = time,
            expires_at = time + 5.0,
            pending_at = nil,
        }
        return true
    end

    -- Standalone: Sleight was cast manually with neither trainer bind held, so
    -- there is no trainer-selected S.target to reuse. Prefer the enemy hero
    -- under the cursor; fall back to the nearest reachable enemy hero so a
    -- manual Sleight still gets chained even without a mouse-hovered target.
    local cursor = safe(function() return Input.GetWorldCursorPos() end, nil)
    local target = cursor and (select(1, best_cursor_target(hero, cursor))) or nil
    if not target then
        target = select(1, best_other_combo_target(hero, cursor or origin(hero), -1))
    end
    if not valid_target(hero, target) then return false end
    S.sleight_chain = {
        target = target,
        target_index = entity_index(target),
        ordered_at = time,
        expires_at = time + 5.0,
        pending_at = nil,
    }
    return true
end

local function try_auto_sleight_chains(hero, time)
    if not ui.auto_sleight_chains:Get() then
        S.sleight_chain = nil
        return false
    end
    local had_chain = S.sleight_chain ~= nil
    arm_active_sleight_chain(hero, time)
    local chain = S.sleight_chain
    if not chain then
        -- Most of this function's gates below return false silently by design
        -- (they'd otherwise spam every tick). This one line is the only signal
        -- that Sleight was detected at all but no arm-able enemy target existed.
        if not had_chain and sleight_in_progress(hero) then
            log_decision("SLEIGHT CHAINS: Sleight detected but no valid enemy target to arm")
        end
        return false
    end
    if not had_chain then
        log_decision("SLEIGHT CHAIN ARMED: tracking "
            .. safe(function() return NPC.GetUnitName(chain.target) end, "target"))
    end

    local chains = S.abilities.chains
    local cooldown = chains and safe(function() return Ability.GetCooldown(chains) end, 0) or 0
    if chain.pending_at then
        if ability_recently_used(chains, 0.60) or cooldown > 0.03 then
            log_decision("SLEIGHT CHAINS: cast confirmed")
            S.sleight_chain = nil
            return false
        end
        if time - chain.pending_at < 0.07 then return false end
        chain.pending_at = nil
    end
    if time > (chain.expires_at or time)
        or not sleight_in_progress(hero)
        or not valid_target(hero, chain.target) then
        log_decision("SLEIGHT CHAINS: abandoning armed chain (expired, Sleight ended, or target invalid)")
        S.sleight_chain = nil
        return false
    end
    -- Spell immunity holds rather than abandons, for the same reason the root
    -- check below does: BKB and Rage expire, often well inside the Sleight
    -- window, and throwing the armed chain away would mean Q could never fire
    -- even once the immunity dropped.
    if plan.spell_immune(chain.target) then
        log_decision("SLEIGHT CHAINS WAIT: target is spell immune; holding Q until it drops")
        return false
    end
    if safe(function()
        return NPC.HasState(chain.target, Enum.ModifierState.MODIFIER_STATE_ROOTED)
    end, false) then
        -- Hold, do not abandon. A target rooted by the previous Sleight's own
        -- Chains stays rooted for ~2s; abandoning here threw the armed chain
        -- away permanently, so a Sleight cast during that window could never
        -- fire even after the root expired and Q was off cooldown. Holding
        -- also stops the arm -> abandon -> re-arm thrash that spammed the log
        -- hundreds of times per root.
        chain.root_held = true
        log_decision("SLEIGHT CHAINS WAIT: target already rooted; holding Q until it expires")
        return false
    end
    if chain.root_held then
        chain.root_held = false
        log_decision("SLEIGHT CHAINS: previous root expired; chain re-armed")
    end
    if not sleight_chains_ready(hero, chains) then
        log_decision("SLEIGHT CHAINS WAIT: Searing Chains not castable (level/mana/cooldown/silence)")
        return false
    end

    -- Sleight places Ember about 50 units from the unit currently being hit.
    -- Waiting for this tight proximity frame is more reliable than casting at
    -- Sleight start, especially when jumps are randomized by a creep wave.
    local hero_pos, target_pos = origin(hero), origin(chain.target)
    local trigger_radius = safe(function() return NPC.GetHullRadius(chain.target) end, 24) + 70
    if not hero_pos or not target_pos
        or distance2d(hero_pos, target_pos) > trigger_radius then
        log_decision("SLEIGHT CHAINS WAIT: waiting for the tight proximity frame beside the target")
        return false
    end
    local ranges = ability_ranges(hero, chain.target)
    local chance, eligible, chain_count = chains_hit_chance(hero, chain.target, ranges)
    local require_guaranteed = ui.sleight_chains_guaranteed:Get()
    local guaranteed = chance >= 0.999
    chain.best_chance = math.max(chain.best_chance or 0, chance)

    if not guaranteed then
        if require_guaranteed then
            S.sleight_role = string.format(
                "SLEIGHT CHAINS WAIT: %d UNITS VS %d CHAINS",
                eligible, chain_count
            )
            log_decision(string.format(
                "SLEIGHT CHAINS: %d units in radius vs %d chains (%.0f%% on the hero); preserving Q",
                eligible, chain_count, chance * 100
            ))
            return false
        end

        -- Best-effort mode. Ember teleports between struck units during Sleight,
        -- so the unit count inside the 400 radius changes frame to frame. Spend
        -- a brief window looking for a cleaner frame instead of firing at the
        -- first one that merely passes proximity, but always fire before the
        -- Sleight window closes rather than losing the cast entirely.
        local age = time - (chain.ordered_at or time)
        local sampling = age < 0.15
        local must_fire = age >= 0.50
        if not must_fire and sampling and chance < 0.80 then
            log_decision(string.format(
                "SLEIGHT CHAINS: sampling for a cleaner frame (%d units, %.0f%%)",
                eligible, chance * 100
            ))
            return false
        end
        if not must_fire and chance < (chain.best_chance or 0) - 0.001 then
            log_decision(string.format(
                "SLEIGHT CHAINS: frame worse than best seen (%.0f%% vs %.0f%%); waiting",
                chance * 100, (chain.best_chance or 0) * 100
            ))
            return false
        end
    end

    local ctx = {
        time = time,
        hero = hero,
        player = S.player,
        target = chain.target,
        target_index = S.target_index,
        target_epoch = S.target_epoch,
        hold_epoch = S.hold_epoch,
        map_epoch = S.map_epoch,
        hero_pos = hero_pos,
        target_pos = target_pos,
        distance = distance2d(hero_pos, target_pos),
        ranges = ranges,
    }
    local actions = new_actions()
    propose(actions, "SLEIGHT_CHAINS", 1400, chance, 1, {
        cast_target = chain.target,
        trigger_radius = trigger_radius,
        require_guaranteed = require_guaranteed,
        label = "AUTO CHAINS DURING SLEIGHT",
        reason = chance >= 0.999
            and string.format(
                "SLEIGHT TARGET FRAME: hero guaranteed (%d units vs %d chains)",
                eligible, chain_count
            )
            or string.format(
                "SLEIGHT TARGET FRAME: best crowded cast (%.0f%% engine selection chance)",
                chance * 100
            ),
    })
    for _, action in ipairs(rank_actions(actions)) do
        if execute_action(ctx, action) then return true end
    end
    return false
end

-- --------------------------------------------------------------------------
-- Transaction revalidation: one order per update, same central arbiter.
-- --------------------------------------------------------------------------

local function transaction_valid(ctx, tx)
    if tx
        and tx.kind == "REMNANT" then
        return tx.hold_epoch == ctx.hold_epoch
            and tx.map_epoch == ctx.map_epoch
    end
    return tx
        and tx.target_index == ctx.target_index
        and tx.target_epoch == ctx.target_epoch
        and tx.hold_epoch == ctx.hold_epoch
        and tx.map_epoch == ctx.map_epoch
        and valid_target(ctx.hero, ctx.target)
end

local function find_new_transaction_remnant(tx)
    local best, best_distance = nil, math.huge
    for index, info in pairs(S.remnants) do
        if not (tx.baseline_indices and tx.baseline_indices[index]) then
            local distance = distance2d(info.position, tx.destination)
            if distance < best_distance then
                best, best_distance = info, distance
            end
        end
    end
    return best
end

local function arm_fast_remnant_activation(tx, time)
    if not tx or not tx.placement_confirmed then return end
    local handoff_delay = tx.profile and tx.profile.scepter
        and 0
        or ui.fast_d_delay_ms:Get() / 1000
    tx.fast_activation_at = tx.fast_activation_at
        or time + handoff_delay
    -- D gets a short, bounded handoff after the R cast is confirmed. It no
    -- longer waits for the outbound Remnant to reach its destination.
    tx.activation_deadline = math.max(tx.fast_activation_at + 2.0, time + 1.25)
end

local function attach_transaction_remnant(tx, info, time)
    if not info then return false end
    S.opening_remnant_committed = true
    tx.placement_confirmed = true
    tx.placement_confirmed_at = tx.placement_confirmed_at or time
    tx.remnant_index = info.index
    arm_fast_remnant_activation(tx, time)
    -- The phase remains committed after R spends a charge, but D is handed off
    -- during outbound travel instead of waiting for the landing point.
    tx.phase = "WAIT_COMMITTED_TRAVEL"
    return true
end

local function activation_cast_in_phase(ctx, activate)
    if not activate then return false end
    if safe(function() return Ability.IsInAbilityPhase(activate) end, false) then return true end
    local player_active = safe(function() return Player.GetActiveAbility(ctx.player) end, nil)
    return same_entity(player_active, activate)
end

local function activation_travel_confirmed(ctx, tx, activate)
    local cast_attributed = tx.activation_started_at ~= nil
    local out_of_game = safe(function()
        return NPC.HasState(ctx.hero, Enum.ModifierState.MODIFIER_STATE_OUT_OF_GAME)
    end, false)
    if out_of_game and (cast_attributed or (tx.dance and tx.dance_d_ordered)) then
        return true, "travel state"
    end

    -- cast_attributed depends on IsInAbilityPhase, which never reports true for
    -- this instant activation on this build, so gating displacement behind it
    -- disabled the check entirely. A sent D order is enough to trust it.
    local ordered = cast_attributed or (tx.dance and tx.dance_d_ordered)
    local current_position = origin(ctx.hero)
    -- Measured from the first D order of this transaction, so displacement
    -- accumulates across retries instead of being reset every 45ms.
    local baseline_at = tx.activation_first_at or tx.activation_order_at
    local baseline_origin = tx.activation_first_origin or tx.activation_origin
    local elapsed = math.max(0.01, ctx.time - (baseline_at or ctx.time))
    local displacement = current_position and baseline_origin
        and distance2d(current_position, baseline_origin) or 0
    if ordered and displacement >= 90 and displacement / elapsed >= 700 then
        return true, "hero displacement"
    end

    -- Dance only: confirm optimistically once the dash has plausibly begun.
    -- Every other detector here fires at or after ARRIVAL, which is far too
    -- late for the feed loop -- by then Ember is standing still, the feed has
    -- nothing to fly toward, and the chain collapses back into R -> D -> R.
    -- Handing off mid-flight is what lets the next remnant be placed while
    -- Ember is still travelling, exactly as the manual recording does.
    if tx.dance and tx.dance_d_ordered and elapsed >= 0.35 then
        return true, "dance travel assumed underway"
    end

    -- Watch the specific activated remnant, not the total. The chain places new
    -- remnants while D resolves, so remnant_count() can stay at or above
    -- remnants_before_activate even though the activated one was consumed --
    -- the total-count test silently stops working exactly when chaining starts.
    if tx.activation_remnant_index
        and not S.remnants[tx.activation_remnant_index] then
        return true, "activated remnant consumed"
    end

    local before = tx.remnants_before_activate or 0
    if before > 0 and remnant_count() < before then return true, "remnant consumed" end
    if cast_attributed
        and ctx.time - (tx.activation_order_at or ctx.time) >= 0.12
        and not activation_cast_in_phase(ctx, activate)
        and not safe(function() return Ability.IsActivated(activate) end, true) then
        return true, "D deactivated"
    end
    return false, "no completion signal"
end

function plan.propose_dance_chain_step(ctx, tx, actions)
    -- Reproduce the continuous one-D traversal shown in the reference clip.
    -- Gate on the D order actually being sent (tx.dance_d_ordered / S.dance_d_used),
    -- not on a confirmed-travel signal: OUT_OF_GAME never fires for Activate Fire
    -- Remnant on this build, and the owned remnant entity is already gone the
    -- instant D is ordered (activation_travel_confirmed treats that drop as proof
    -- travel STARTED, not evidence travel is ongoing) -- so both were dead gates
    -- that silently blocked every chain attempt for the whole flight.
    -- Chain only once D's travel is CONFIRMED, never while D is still in its
    -- cast phase. Casting Fire Remnant during that phase cancels the
    -- activation outright ("RETRY REMNANT: D cast was interrupted"), which is
    -- what scattered remnants across every hero with no dash behind them. The
    -- original code gated this on OUT_OF_GAME, which never fires on this build;
    -- dance_travel_confirmed is the signal that actually works here, set from
    -- the activated-remnant-consumed and hero-displacement detectors.
    if not tx or not tx.dance
        or tx.no_chain
        or not tx.dance_travel_confirmed
        or (not S.dance_d_used and not tx.dance_d_ordered) then return false end
    local remnant = S.abilities.remnant
    local charges = safe(function() return Ability.GetCurrentCharges(remnant) end, 0)
    if tx.chain_pending_charges and charges < tx.chain_pending_charges then
        tx.last_chain_target_index = tx.chain_pending_target_index
        tx.chain_anchor_position = tx.chain_pending_anchor_position
            or tx.chain_anchor_position
        S.dance_last_anchor = tx.chain_anchor_position
        tx.chain_visited_indices = tx.chain_visited_indices or {}
        if (tx.chain_pending_target_index or -1) >= 0 then
            tx.chain_visited_indices[tx.chain_pending_target_index] = true
            S.dance_visited_indices = tx.chain_visited_indices
        end
        tx.chain_pending_charges = nil
        tx.chain_pending_at = nil
        tx.chain_pending_target_index = nil
        tx.chain_pending_anchor_position = nil
    elseif tx.chain_pending_charges
        and ctx.time - (tx.chain_pending_at or ctx.time) >= 0.055 then
        tx.chain_pending_charges = nil
        tx.chain_pending_at = nil
        tx.chain_pending_target_index = nil
        tx.chain_pending_anchor_position = nil
    end
    if tx.chain_pending_charges then return false end

    local chain_target, cursor_authorized, reset_cycle = dance.chain_target(
        ctx.hero,
        tx.chain_anchor_position,
        tx.last_chain_target_index,
        tx.chain_visited_indices
    )
    local hovered_target = dance.enemy_under_cursor(ctx.hero, ctx.cursor)
    local hovered_pos = hovered_target and origin(hovered_target) or nil
    local hovered_index = entity_index(hovered_target)
    local hovered_visited = tx.chain_visited_indices
        and tx.chain_visited_indices[hovered_index] == true
    if hovered_pos
        and hovered_index ~= tx.last_chain_target_index
        and distance2d(tx.chain_anchor_position, hovered_pos)
            <= dance.chain_cast_range(ctx.hero) + 25
        and (not hovered_visited or reset_cycle) then
        -- Cursor ownership may redirect the next hop only to an unvisited hero.
        -- Once every reachable hero has been visited, it may choose the first
        -- hero of the new pass. This prevents A -> B -> A while C/D/E remain.
        chain_target = hovered_target
        cursor_authorized = true
        reset_cycle = hovered_visited and reset_cycle or false
    end
    if not chain_target then return false end
    local cast_point = origin(chain_target)
    if not cast_point or not set_dance_visual_target(chain_target, cast_point, ctx.time) then
        return false
    end
    ctx.target = chain_target
    ctx.target_index = S.target_index
    ctx.target_epoch = S.target_epoch
    ctx.target_pos = origin(chain_target)
    ctx.distance = ctx.target_pos and distance2d(ctx.hero_pos, ctx.target_pos) or math.huge

    if charges <= 0 and ui.dance_refresher:Get() then
        local refresher = find_refresher(ctx.hero)
        if refresher then
            propose(actions, "DANCE_CHAIN_REFRESHER", 1250, 1.0, 1, {
                dance = true,
                ability = refresher,
                chain_target = chain_target,
                cursor_authorized = cursor_authorized,
                label = "DANCING EMBER CHAIN REFRESHER",
                reason = "DANCING EMBER: zero charges after D -> Refresher",
            })
            return true
        end
        return false
    end
    if charges <= 0 or not dance.chain_remnant_ready(ctx.hero, remnant) then return false end

    local destination, _, chain_profile = dance.remnant_destination(
        ctx.hero,
        cast_point,
        remnant,
        tx.chain_anchor_position
    )
    if not destination then return false end
    propose(actions, "DANCE_CHAIN_REMNANT", 1200, 1.0, 1, {
        dance = true,
        chain_target = chain_target,
        cursor_authorized = cursor_authorized,
        reset_cycle = reset_cycle,
        cast_origin = tx.chain_anchor_position,
        position = destination,
        profile = chain_profile,
        label = "DANCING EMBER CHAIN R",
        reason = cursor_authorized
            and "DANCING EMBER: R-D-R on hovered alternate enemy"
            or (reset_cycle
                and "DANCING EMBER: all reachable heroes visited -> begin next pass"
                or "DANCING EMBER: R-D-R on unvisited reachable enemy"),
    })
    return true
end

local function update_midflight_correction_confirmation(ctx, tx)
    if not tx or tx.dance or not tx.correction_pending_charges then return end
    local remnant = S.abilities.remnant
    local charges = safe(function()
        return Ability.GetCurrentCharges(remnant)
    end, tx.correction_pending_charges)
    if charges < tx.correction_pending_charges then
        tx.correction_pending_charges = nil
        tx.correction_pending_at = nil
        tx.correction_confirmed = true
        tx.destination = tx.correction_destination or tx.destination
        tx.activation_position = tx.destination
        local profile = tx.correction_profile or tx.profile
        local cast_origin = tx.correction_cast_origin or ctx.hero_pos
        local placement_eta = profile and (
            profile.placement_cast_point
                + distance2d(cast_origin, tx.destination)
                    / math.max(100, profile.placement_speed)
        ) or 0.80
        tx.arrival_deadline = math.max(
            tx.arrival_deadline or ctx.time,
            ctx.time + placement_eta + 0.75
        )
        log_decision("MIDFLIGHT CORRECTION: corrected R joined the existing D travel")
    elseif ctx.time - (tx.correction_pending_at or ctx.time) >= 0.16 then
        -- The order was not accepted by the game. Clear the pending latch so a
        -- bounded retry remains possible without ever issuing another D.
        tx.correction_pending_charges = nil
        tx.correction_pending_at = nil
        log_decision("RETRY CORRECTION: R order was not confirmed")
    end
end

-- The reserve keeps a Remnant banked for escaping, but it can never be allowed
-- to consume the hero's whole supply. At early levels Fire Remnant has only one
-- or two charges, so a reserve of 1 meant "charges <= reserve" was true every
-- time and Ember never cast R at all. Cap it so at least one charge stays
-- spendable no matter how the slider is set.
function plan.remnant_reserve(hero)
    local remnant = S.abilities.remnant
    local wanted = ui.reserve_remnants:Get()
    if wanted <= 0 or not remnant then return 0 end
    local maximum = math.floor(special(remnant, { "max_charges", "charges" }, 0))
    if maximum < 1 then
        -- Special value unavailable: fall back to what we can actually see, so
        -- a low-level Remnant still gets to fire.
        maximum = math.max(1, safe(function()
            return Ability.GetCurrentCharges(remnant)
        end, 1))
    end
    return math.max(0, math.min(wanted, maximum - 1))
end

function plan.propose_midflight_correction(ctx, tx, actions)
    if not tx or tx.dance
        or not ui.midflight_correction:Get()
        or not tx.activation_order_at
        or tx.correction_confirmed
        or tx.correction_pending_charges
        or (tx.correction_attempts or 0) >= 3
        or not valid_target(ctx.hero, ctx.target) then return false end
    -- WAIT_ARRIVAL used to additionally require MODIFIER_STATE_OUT_OF_GAME.
    -- That state never reports true on this build, so the correction was
    -- blocked during the exact window it exists for -- Ember mid-travel, the
    -- target dodging -- and it never fired once. The check was redundant
    -- anyway: WAIT_ARRIVAL is only entered after travel is confirmed.
    local remnant = S.abilities.remnant
    if not dance.chain_remnant_ready(ctx.hero, remnant) then return false end
    local charges = safe(function() return Ability.GetCurrentCharges(remnant) end, 0)
    local reserve = plan.remnant_reserve(ctx.hero)
    if charges <= reserve then
        log_decision(string.format(
            "MIDFLIGHT CORRECTION: target dodged but reserve policy holds the charge (%d left, reserve %d)",
            charges, reserve
        ))
        return false
    end
    local mana = safe(function() return NPC.GetMana(ctx.hero) end, 0)
    local cost = safe(function() return Ability.GetManaCost(remnant) end, math.huge)
    if mana < cost + ui.mana_reserve:Get() then return false end

    local destination, profile, deviation, cast_origin =
        predict_midflight_remnant_correction(ctx, tx)
    if not destination then return false end
    propose(actions, "CORRECT_REMNANT", 1300, 0.95, 1, {
        position = destination,
        cast_origin = cast_origin,
        profile = profile,
        label = "MIDFLIGHT REMNANT CORRECTION",
        reason = string.format(
            "TARGET DODGED: corrected R by %.0f during the existing D travel",
            deviation
        ),
    })
    return true
end

local function plan_transaction(ctx, actions)
    local tx = S.tx
    if not transaction_valid(ctx, tx) then
        S.tx = nil
        return false
    end

    if tx.kind == "REMNANT" then
        scan_owned_remnants(ctx.hero, ctx.time, true)
        update_midflight_correction_confirmation(ctx, tx)

        if tx.dance then
            -- S.dance_d_used is a one-D-per-transaction latch, cleared only when
            -- the transaction completes. A Refresher Orb/Shard refills Fire
            -- Remnant mid-transaction, and the R chain step only requires that a
            -- D was already ordered -- so without this, every post-refresh R is
            -- placed while ACTIVATE_REMNANT stays blocked by the stale latch:
            -- remnants fly out at every hero and Ember never dashes. Natural
            -- charge regen only ever adds one, so a jump of two or more is a
            -- real restore: close the cycle and re-arm a fresh R -> D.
            local live_charges = safe(function()
                return Ability.GetCurrentCharges(S.abilities.remnant)
            end, 0)
            local last_charges = tx.last_seen_charges or live_charges
            tx.last_seen_charges = live_charges
            if live_charges >= last_charges + 2 then
                S.tx = nil
                S.dance_d_used = false
                S.engagement_started = false
                S.opening_remnant_committed = false
                S.combo_stage = COMBO_STAGE.GAP_CLOSE
                set_fsm(FSM.GAP_CLOSE, ctx.time)
                log_decision("DANCING EMBER: Fire Remnant refreshed; re-arming a fresh R -> D cycle")
                return false
            end
        end

        local plan_delta = math.max(0, ctx.time - (tx.last_plan_at or ctx.time))
        tx.last_plan_at = ctx.time

        -- Ember cannot act while Sleight of Fist resolves, and that Sleight is
        -- often not ours -- Umbrella's Kill Stealer fires it mid-dance. Freeze
        -- the transaction clocks for its duration instead of letting a window
        -- Ember was never able to act in expire the chain: the held key should
        -- carry straight on dashing once the steal finishes.
        if sleight_in_progress(ctx.hero) then
            local held = math.min(plan_delta, 0.25)
            tx.activation_deadline = (tx.activation_deadline or ctx.time) + held
            tx.arrival_deadline = (tx.arrival_deadline or ctx.time) + held
            if tx.dance then
                log_decision("DANCING EMBER: Sleight resolving; holding the chain clock")
            end
        end
        if tx.placement_confirmed
            and tx.phase ~= "WAIT_ARRIVAL"
            and not hero_can_cast(ctx.hero) then
            -- A stun/silence cannot make D possible, so it must not consume the
            -- bounded retry window for an already-spent opening Remnant.
            tx.activation_deadline = tx.activation_deadline + math.min(plan_delta, 0.25)
        end
        if ctx.time > tx.activation_deadline and tx.phase ~= "WAIT_ARRIVAL" then
            if tx.placement_confirmed and tx.phase == "WAIT_COMMITTED_TRAVEL" then
                local tracked = tx.remnant_index and S.remnants[tx.remnant_index]
                tx.activation_position = tx.destination
                tx.phase = "READY_TO_ACTIVATE"
                tx.activation_deadline = ctx.time + 1.40
                log_decision(tracked
                    and "FAST D FALLBACK: activate outbound Remnant"
                    or "FAST D ENTITY FALLBACK: committed activation")
            else
                S.tx = nil
                log_decision("CANCEL REMNANT: activation deadline expired")
                return false
            end
        end

        if tx.phase == "WAIT_PLACE_CONFIRM" then
            local created = find_new_transaction_remnant(tx)
            if created then
                attach_transaction_remnant(tx, created, ctx.time)
            else
                local charges = safe(function()
                    return Ability.GetCurrentCharges(S.abilities.remnant)
                end, tx.charges_before)
                if charges < tx.charges_before or ability_recently_used(S.abilities.remnant, 0.80) then
                    S.opening_remnant_committed = true
                    tx.placement_confirmed = true
                    tx.placement_confirmed_at = tx.placement_confirmed_at or ctx.time
                    arm_fast_remnant_activation(tx, ctx.time)
                    tx.phase = "WAIT_COMMITTED_TRAVEL"
                elseif ctx.time > tx.entity_deadline then
                    S.tx = nil
                    log_decision("CANCEL REMNANT: placement not confirmed")
                end
            end
            if tx.placement_confirmed and tx.profile and tx.profile.scepter then
                -- On Scepter, the first server-confirmed R frame is also the D
                -- proposal frame. Do not burn an additional update merely to
                -- transition through WAIT_COMMITTED_TRAVEL.
                tx.activation_position = tx.destination
                tx.phase = "READY_TO_ACTIVATE"
            else
                return true
            end
        end

        if tx.phase == "WAIT_COMMITTED_TRAVEL" then
            local remnant_info = tx.remnant_index and S.remnants[tx.remnant_index]
                or find_new_transaction_remnant(tx)
            if remnant_info and not tx.remnant_index then
                tx.remnant_index = remnant_info.index
            end
            arm_fast_remnant_activation(tx, tx.placement_confirmed_at or ctx.time)
            if tx.fast_activation_at and ctx.time >= tx.fast_activation_at then
                tx.activation_position = tx.destination
                tx.phase = "READY_TO_ACTIVATE"
                log_decision("FAST D READY: outbound Remnant confirmed")
            else
                log_decision("FAST D HANDOFF: waiting short R confirmation delay")
                return true
            end
        end

        if tx.phase == "READY_TO_ACTIVATE" then
            if not ui.use_activate:Get() then
                S.tx = nil
                log_decision("SAVE PLACED REMNANT: activation disabled")
                return false
            end
            local created = tx.remnant_index and S.remnants[tx.remnant_index]
                or find_new_transaction_remnant(tx)
            if created and not tx.remnant_index then attach_transaction_remnant(tx, created, ctx.time) end

            local active_remnants = remnant_count()
            local maximum_active = tx.correction_confirmed and 2 or 1
            if active_remnants > maximum_active and not tx.allow_multiple_active then
                S.tx = nil
                log_decision("SAVE REMNANT: activation would consume multiple remnants")
                return false
            end
            if active_remnants < 1 and not tx.placement_confirmed then
                log_decision("WAIT REMNANT: placement confirmation")
                return true
            end

            -- Prediction and destination safety were accepted before spending R.
            -- Once placement is confirmed, commit D instead of abandoning Ember's
            -- gap close because the enemy turned during the outbound animation.
            local activate_ready = tx.dance
                and committed_dance_activate_ready(
                    ctx.hero,
                    S.abilities.activate,
                    ui.mana_reserve:Get()
                )
                or activate_usable(ctx.hero, S.abilities.activate, ui.mana_reserve:Get())
            if activate_ready then
                propose(actions, "ACTIVATE_REMNANT", 1000, 1.0, 3, {
                    position = tx.activation_position or tx.destination,
                    label = "ACTIVATE REMNANT (D)",
                    reason = "GAP CLOSE: committed Fire Remnant -> D",
                })
            else
                log_decision("WAIT REMNANT: D not castable yet")
            end
            return true
        end

        if tx.phase == "WAIT_ACTIVATE_START" then
            local activate = S.abilities.activate
            local travel_started, completion_reason = activation_travel_confirmed(ctx, tx, activate)
            if travel_started then
                if tx.dance then
                    -- Hand the chain to the feed loop and retire the
                    -- transaction. Keeping it alive is what kept re-arming a
                    -- second, third, fourth D; the recorded manual combo casts
                    -- D exactly once and then only ever casts R.
                    S.dance_d_used = true
                    S.dance_last_anchor = tx.destination or S.dance_last_anchor
                    S.dance_chain_idle_since = nil
                    S.dance_last_move_at = nil
                    S.dance_idle_pos = nil
                    S.tx = nil
                    log_decision("ACTIVATE REMNANT (D): " .. completion_reason
                        .. "; feeding chain from here")
                    return false
                end
                tx.phase = "WAIT_ARRIVAL"
                tx.activated_at = ctx.time
                log_decision("ACTIVATE REMNANT (D): " .. completion_reason)
            elseif activation_cast_in_phase(ctx, activate) then
                tx.phase = "WAIT_ACTIVATE_COMPLETE"
                tx.activation_started_at = ctx.time
                log_decision("ACTIVATE REMNANT (D): cast started")
            elseif tx.activation_order_at
                -- Must stay above the 0.35s optimistic dance confirmation
                -- above, or the retry fires first and D is re-ordered before
                -- travel is ever acknowledged.
                and ctx.time - tx.activation_order_at >= (tx.dance and 0.60 or 0.38) then
                local maximum_attempts = tx.dance and 8 or 3
                if (tx.activation_attempts or 0) < maximum_attempts
                    and ctx.time + 0.06 < tx.activation_deadline then
                    tx.phase = "READY_TO_ACTIVATE"
                    log_decision("RETRY REMNANT: D cast did not start")
                else
                    log_decision("WAIT REMNANT: confirming D cast start")
                end
            end
            if tx.phase == "WAIT_ACTIVATE_START" then
                -- No dance chaining here: D has been ordered but its cast phase
                -- is still open, and an R now cancels it. Chaining resumes in
                -- WAIT_ARRIVAL once travel is confirmed.
                if not tx.dance and plan.propose_midflight_correction(ctx, tx, actions) then
                    return true
                end
            end
            return true
        end

        if tx.phase == "WAIT_ACTIVATE_COMPLETE" then
            local activate = S.abilities.activate
            local travel_started, completion_reason = activation_travel_confirmed(ctx, tx, activate)
            if travel_started then
                if tx.dance then
                    -- Same handoff as WAIT_ACTIVATE_START: one D per chain.
                    S.dance_d_used = true
                    S.dance_last_anchor = tx.destination or S.dance_last_anchor
                    S.dance_chain_idle_since = nil
                    S.dance_last_move_at = nil
                    S.dance_idle_pos = nil
                    S.tx = nil
                    log_decision("ACTIVATE REMNANT (D): " .. completion_reason
                        .. "; feeding chain from here")
                    return false
                end
                tx.phase = "WAIT_ARRIVAL"
                tx.activated_at = ctx.time
                log_decision("ACTIVATE REMNANT (D): " .. completion_reason)
            elseif activation_cast_in_phase(ctx, activate) then
                log_decision("ACTIVATE REMNANT (D): completing cast")
            elseif tx.activation_started_at and ctx.time - tx.activation_started_at >= 0.18 then
                local maximum_attempts = tx.dance and 8 or 3
                if (tx.activation_attempts or 0) < maximum_attempts
                    and ctx.time + 0.06 < tx.activation_deadline then
                    tx.phase = "READY_TO_ACTIVATE"
                    log_decision("RETRY REMNANT: D cast was interrupted")
                else
                    log_decision("WAIT REMNANT: confirming D completion")
                end
            end
            if tx.phase == "WAIT_ACTIVATE_COMPLETE" then
                -- Same as WAIT_ACTIVATE_START: D is mid-cast, so no R here.
                if not tx.dance and plan.propose_midflight_correction(ctx, tx, actions) then
                    return true
                end
            end
            return true
        end

        if tx.phase == "WAIT_ARRIVAL" then
            if tx.dance then
                local active_remnants = remnant_count()
                -- tx.arrival_deadline is pushed forward on every confirmed chain
                -- hop (see the DANCE_CHAIN_REMNANT executor), so it drives "is the
                -- chain still in progress" here instead of OUT_OF_GAME, which this
                -- build never sets for Activate Fire Remnant. The previous 0.06s
                -- "emerged" check closed the whole transaction almost immediately
                -- after D, before a second hop ever had a chance to fire.
                local still_travelling = ctx.time <= tx.arrival_deadline or active_remnants > 0
                if still_travelling and plan.propose_dance_chain_step(ctx, tx, actions) then
                    return true
                end

                if ctx.time > tx.arrival_deadline then
                    S.tx = nil
                    -- A held Dancing Ember bind is a continuous controller.
                    -- The completed one-D travel chain immediately re-arms the
                    -- next R -> D cycle; releasing the key is not required.
                    S.dance_d_used = false
                    S.engagement_started = false
                    S.opening_remnant_committed = false
                    S.combo_stage = COMBO_STAGE.GAP_CLOSE
                    set_fsm(FSM.GAP_CLOSE, ctx.time)
                    log_decision(active_remnants == 0
                        and "DANCING EMBER: chain complete; held key re-armed next cycle"
                        or "DANCING EMBER: chain timeout; held key re-armed next cycle")
                end
                return true
            end

            if tx.correction_pending_charges then
                log_decision("MIDFLIGHT CORRECTION: confirming corrected R")
                return true
            end
            if plan.propose_midflight_correction(ctx, tx, actions) then
                return true
            end

            local target_ready = valid_target(ctx.hero, ctx.target)
            local landing_position = tx.activation_position or tx.destination
            local reached_landing = ctx.hero_pos and landing_position
                and distance2d(ctx.hero_pos, landing_position) <= 210
            if target_ready and ctx.distance <= ctx.ranges.sticky_exit then
                S.tx = nil
                S.engagement_started = true
                S.combo_stage = COMBO_STAGE.GUARD
                set_fsm(FSM.STICKY_FIGHT, ctx.time)
                log_decision("REMNANT ARRIVAL: enter sticky fight")
            elseif reached_landing then
                S.tx = nil
                S.engagement_started = false
                S.combo_stage = target_ready and COMBO_STAGE.GAP_CLOSE or COMBO_STAGE.ACQUIRE
                set_fsm(target_ready and FSM.GAP_CLOSE or FSM.ACQUIRE, ctx.time)
                log_decision(target_ready
                    and "REMNANT ARRIVAL: resume chase"
                    or "REMNANT ARRIVAL: reacquire target")
            elseif ctx.time > tx.arrival_deadline then
                S.tx = nil
                S.engagement_started = false
                S.combo_stage = COMBO_STAGE.GAP_CLOSE
                set_fsm(FSM.GAP_CLOSE, ctx.time)
                log_decision("REMNANT ARRIVAL timeout: walk into engagement range")
            end
            return true
        end
    end
    return false
end

-- --------------------------------------------------------------------------
-- State planners
-- --------------------------------------------------------------------------

function plan.propose_flame_guard(ctx, actions, priority)
    if not ui.use_guard:Get() or flame_guard_active(ctx.hero) then return false end
    if ctx.distance > ctx.ranges.sticky_exit + 65 then return false end
    if not hero_can_cast(ctx.hero) or not ability_usable(ctx.hero, S.abilities.guard, ui.mana_reserve:Get()) then
        return false
    end
    propose(actions, "FLAME_GUARD", priority or 920, 0.95, 1, {
        label = "FLAME GUARD",
        reason = "POST-REMNANT: enable Flame Guard before right-clicks",
    })
    return true
end

function plan.propose_attack(ctx, actions)
    if not S.guard_stage_completed then return false end
    -- Flame Guard gates the OPENING right-click pressure only. It used to gate
    -- every attack for the whole fight, so the moment Guard expired mid-fight
    -- Ember stopped attacking until it came off cooldown -- and with orbwalk
    -- also refusing to move while an attack was ready, that read as the script
    -- dying entirely. Guard is a damage/shield buff, not a prerequisite for
    -- right-clicking, so once the opening pressure is done, keep attacking.
    -- ...and only while Guard is actually obtainable. With Guard down AND on
    -- cooldown there is no Guard window to wait for, and blocking here was a
    -- deadlock: opening pressure completes by landing right clicks during a
    -- Guard window, so with attacks blocked it could never complete, which
    -- kept attacks blocked forever. Ember then only had the orbwalk move left
    -- and just trailed the cursor without ever attacking.
    if ui.use_guard:Get()
        and not S.opening_pressure_completed
        and not flame_guard_active(ctx.hero)
        and hero_can_cast(ctx.hero)
        and ability_usable(ctx.hero, S.abilities.guard, ui.mana_reserve:Get()) then
        return false
    end
    if ctx.distance > ctx.ranges.attack then return false end
    if safe(function() return NPC.HasState(ctx.hero, Enum.ModifierState.MODIFIER_STATE_DISARMED) end, false) then
        return false
    end
    propose(actions, "ATTACK", 760, 0.95, 0, {
        label = "RIGHT CLICK",
        reason = ctx.escaping and "ATTACK: target still in reach" or "SAVE SPELLS: productive melee uptime",
    })
    return true
end

function plan.propose_move(ctx, actions, priority, reason)
    local position = ctx.lead_pos or ctx.target_pos
    if not position then return end
    propose(actions, "MOVE", priority or 610, 0.75, 0, {
        position = position,
        label = "LEAD MOVE",
        reason = reason or "WALK: cheapest reconnect",
    })
end

local function orbwalk_position(ctx)
    if not ui.orbwalk:Get() or ctx.time < S.move_after then return nil end

    -- Player mouse control wins only INSIDE melee reach, which is the actual
    -- hit-and-run window. Letting it win at any range meant that whenever the
    -- target was out of reach -- Remnant on cooldown, so no gap close -- Ember
    -- walked to the mouse instead of chasing the enemy, and never attacked.
    -- Out of reach, fall through to the approach logic below, which moves
    -- relative to the TARGET.
    local cursor = safe(function() return Input.GetWorldCursorPos() end, nil)
    local within_reach = ctx.distance and ctx.ranges
        and ctx.distance <= (ctx.ranges.attack or 0) + 25
    if within_reach and cursor and ctx.hero_pos
        and distance2d(ctx.hero_pos, cursor) >= 65 then
        -- ATTACK outranks this MOVE, so a legal attack still wins; this only
        -- fills the gap when no attack is actually issued.
        return ground_position(cursor)
    end

    -- The keep-distance / kiting reposition below is strictly a cooldown-window
    -- behaviour: never circle the target while an attack is available.
    if ctx.time >= S.next_attack then return nil end

    local target_position = ctx.lead_pos or ctx.target_pos
    if not target_position or not ctx.hero_pos then return nil end
    local away, separation = normalize2d(sub(ctx.hero_pos, target_position))
    if separation < 1 then
        away = mul(normalize2d(forward_vector(ctx.target)), -1)
    end

    local maximum_keep = math.max(45, ctx.ranges.attack - 35)
    local desired_distance = clamp(
        ctx.ranges.attack * ui.orb_keep_distance:Get() / 100,
        45,
        maximum_keep
    )
    local destination
    if ui.orb_kiting:Get() or separation > desired_distance then
        destination = add(target_position, mul(away, desired_distance))
    else
        -- With Kiting off, keep pressing into the selected hero for sticky
        -- body-block pressure instead of backing away during the cooldown.
        destination = target_position
    end

    local direction, distance = normalize2d(sub(destination, ctx.hero_pos))
    if distance < 35 then return nil end
    return ground_position(add(ctx.hero_pos, mul(direction, math.min(distance, 325))))
end

-- Park a Remnant on the next enemy while the current one is dying, so whoever
-- lands the kill -- the trainer's own Sleight finish or Umbrella's Kill Stealer
-- -- is followed by an instant dash instead of a walk.
function plan.propose_preload_remnant(ctx, actions)
    if not ui.preload_next:Get() or not ui.use_remnant:Get() then return false end
    if S.tx or S.preload then return false end
    if not valid_target(ctx.hero, ctx.target) then return false end
    if not hero_can_cast(ctx.hero) then return false end

    -- Park only once this hero is genuinely one Sleight from dead. Casting the
    -- R during that Sleight is the whole point: Ember is displaced mid-strike,
    -- so the remnant effectively reaches further than a standing cast would.
    if not sleight_lethal_now(ctx.hero, ctx.target, ctx.ranges) then return false end

    local remnant = S.abilities.remnant
    -- The reserve exists so the normal combo can always reconnect, but parking
    -- the next kill IS the intended spend here -- gating on charges > reserve
    -- meant this never fired mid-combo, where charges are usually 0-1 after the
    -- gap close. One real charge is the only hard requirement.
    local charges = safe(function() return Ability.GetCurrentCharges(remnant) end, 0)
    if charges < 1 or not ability_usable(ctx.hero, remnant, ui.mana_reserve:Get()) then
        log_decision(string.format(
            "PRELOAD WAIT: target is Sleight-lethal but no Remnant to park (charges %d)", charges
        ))
        return false
    end

    -- Who is worth parking on. Priority: an enemy already hurt enough to be
    -- killable, otherwise the least-farmed one, who is almost always the pos 4
    -- or 5 and the softest follow-up. The API exposes no net worth and no role
    -- field, so XP stands in as the farm proxy -- it is the only one available.
    -- Distance is a light tiebreak only, never the deciding factor.
    local hero_pos = ctx.hero_pos
    local best, best_score = nil, math.huge
    local hurt_line = ui.preload_hurt:Get() / 100
    for _, enemy in pairs(safe(function() return Heroes.GetAll() end, {})) do
        if valid_target(ctx.hero, enemy)
            and entity_index(enemy) ~= ctx.target_index then
            local enemy_pos = origin(enemy)
            local distance = enemy_pos and distance2d(hero_pos, enemy_pos) or math.huge
            if distance <= ui.preload_range:Get() then
                local health = safe(function() return Entity.GetHealth(enemy) end, 1)
                local max_health = math.max(1, safe(function()
                    return Entity.GetMaxHealth(enemy)
                end, health))
                local score
                if health / max_health <= hurt_line then
                    -- Already hurt: lowest absolute HP is the kill.
                    score = health
                else
                    -- Nobody hurt: least farmed is the softest target. Offset
                    -- keeps this whole tier below any wounded enemy.
                    score = 1e6 + safe(function() return Hero.GetCurrentXP(enemy) end, 0)
                end
                score = score + distance * 0.05
                if score < best_score then
                    best, best_score = enemy, score
                end
            end
        end
    end
    if not best then
        log_decision("PRELOAD WAIT: target is Sleight-lethal but no other enemy hero in search range")
        return false
    end

    local ranges = ability_ranges(ctx.hero, best)
    local destination, confidence, intercept = predict_remnant_intercept(
        ctx.hero, best, ranges, ctx.time
    )
    if not destination or not intercept then
        log_decision("PRELOAD WAIT: no safe Remnant destination on the next enemy")
        return false
    end

    propose(actions, "PRELOAD_REMNANT", 745, confidence, 2, {
        preload_target = best,
        position = destination,
        intercept = intercept,
        label = "PRELOAD NEXT TARGET",
        reason = string.format(
            "KILL SETUP: current hero is Sleight-lethal, park R on %s",
            safe(function() return NPC.GetUnitName(best) end, "next enemy")
        ),
    })
    return true
end

-- Self-cast utility items. Defensive ones gate on the HP threshold, offensive
-- ones on actually being in the fight, so nothing is burned while walking in.
-- ability_usable() is written for ABILITIES: it rejects anything reporting
-- level 0, which items commonly do. That silently disqualified every support
-- item regardless of charges or cooldown. Items get their own check: real mana,
-- real cooldown, and IsCastable as a permissive last word.
function plan.item_usable(hero, item)
    if not item then return false end
    local mana = safe(function() return NPC.GetMana(hero) end, 0)
    local cost = safe(function() return Ability.GetManaCost(item) end, 0)
    if mana < cost then return false end
    if safe(function() return Ability.GetCooldown(item) end, 0) > 0.05 then return false end
    return safe(function() return Ability.IsCastable(item, mana) end, true)
end

function plan.propose_support_items(ctx, actions)
    if not ui.support_items:Get() or not hero_can_cast(ctx.hero) then return false end
    local health = safe(function() return Entity.GetHealth(ctx.hero) end, 1)
    local max_health = math.max(1, safe(function()
        return Entity.GetMaxHealth(ctx.hero)
    end, health))
    local health_percent = health / max_health * 100
    local hurt = health_percent <= ui.item_hp_threshold:Get()
    local engaged = ctx.distance <= ctx.ranges.sticky_exit + 140

    -- Smart Usage keeps defensive charges from being spent while disengaged.
    local threatened = not ui.item_smart:Get()
        or ctx.distance <= ctx.ranges.sticky_exit + 400

    local function offer(switch, item_name, defensive, priority, label, reason)
        if not safe(function() return switch:Get() end, false) then return false end
        if defensive and not (hurt and threatened) then return false end
        if not defensive and not engaged then return false end
        local item = safe(function()
            return NPC.GetItem(ctx.hero, item_name, true)
        end, nil)
        if not item or not plan.item_usable(ctx.hero, item) then return false end
        propose(actions, "SUPPORT_ITEM", priority, 0.90, 1, {
            ability = item,
            label = label,
            reason = reason,
        })
        return true
    end

    -- Survival first: these only matter if they land before Ember dies.
    if offer(ui.item_bkb, "item_black_king_bar", true, 960,
        "BLACK KING BAR", "DEFENSIVE: BKB below the HP threshold") then return true end
    if offer(ui.item_satanic, "item_satanic", true, 955,
        "SATANIC", "DEFENSIVE: Satanic lifesteal to survive the fight") then return true end
    if offer(ui.item_blademail, "item_blade_mail", true, 950,
        "BLADE MAIL", "DEFENSIVE: Blade Mail while focused") then return true end
    if offer(ui.item_manta, "item_manta", true, 945,
        "MANTA STYLE", "DEFENSIVE: Manta dispel") then return true end
    if offer(ui.item_lotus, "item_lotus_orb", true, 940,
        "LOTUS ORB", "DEFENSIVE: Lotus Orb reflect") then return true end
    if offer(ui.item_sphere, "item_sphere", true, 935,
        "LINKEN'S SPHERE", "DEFENSIVE: Linken's block") then return true end
    -- Then damage amplification, once actually in melee.
    if offer(ui.item_shivas, "item_shivas_guard", false, 835,
        "SHIVA'S GUARD", "PRESSURE: Shiva's slow on the engaged target") then return true end
    if offer(ui.item_mjollnir, "item_mjollnir", false, 830,
        "MJOLLNIR SHIELD", "PRESSURE: Mjollnir static shield") then return true end

    -- Targeted items go on the enemy, and only with a live target in range.
    local function offer_target(switch, names, priority, label, reason, needs_charges)
        if not safe(function() return switch:Get() end, false) then return false end
        if not valid_target(ctx.hero, ctx.target) then return false end
        for _, item_name in ipairs(names) do
            local item = safe(function()
                return NPC.GetItem(ctx.hero, item_name, true)
            end, nil)
            -- Urn and Spirit Vessel are charge-gated, and IsCastable covers
            -- mana, cooldown and level but not charges -- casting at zero does
            -- nothing at all, silently.
            if item and needs_charges
                and safe(function() return Ability.GetCurrentCharges(item) end, 0) < 1 then
                item = nil
            end
            if item and plan.item_usable(ctx.hero, item) then
                local reach = cast_range(ctx.hero, item, 900)
                if ctx.distance <= reach then
                    propose(actions, "SUPPORT_ITEM_TARGET", priority, 0.90, 1, {
                        ability = item,
                        cast_target = ctx.target,
                        label = label,
                        reason = reason,
                    })
                    return true
                end
            end
        end
        return false
    end

    if offer_target(ui.item_orchid, { "item_bloodthorn", "item_orchid" }, 870,
        "ORCHID", "PRESSURE: silence the target") then return true end
    if offer_target(ui.item_atos, { "item_rod_of_atos", "item_gungir" }, 860,
        "ROD OF ATOS", "CONTROL: root the target") then return true end
    -- Vessel first: it is the upgrade, so prefer it when both are carried.
    if offer_target(ui.item_urn, { "item_spirit_vessel", "item_urn_of_shadows" }, 855,
        "URN / SPIRIT VESSEL", "PRESSURE: damage over time and heal denial", true) then
        return true
    end
    if offer_target(ui.item_solar, { "item_solar_crest", "item_medallion_of_courage" }, 840,
        "SOLAR CREST", "PRESSURE: strip the target's armor") then return true end
    return false
end

function plan.propose_orbwalk(ctx, actions, priority, reason)
    local position = orbwalk_position(ctx)
    if not position then return false end
    propose(actions, "MOVE", priority or 700, 0.98, 0, {
        position = position,
        follow_cursor = true,
        label = "ORBWALK STEP",
        reason = reason or "HIT & RUN: move during attack cooldown",
    })
    return true
end

function plan.propose_phase_boots(ctx, actions)
    if not ui.use_items:Get() or ctx.distance <= ctx.ranges.sticky_exit + 140 then return end
    local boots = safe(function() return NPC.GetItem(ctx.hero, "item_phase_boots", true) end, nil)
    if boots and ability_usable(ctx.hero, boots, ui.mana_reserve:Get()) then
        local priority = S.fsm == FSM.GAP_CLOSE and 725 or 675
        propose(actions, "PHASE_BOOTS", priority, 0.80, 1, {
            ability = boots,
            label = "PHASE BOOTS",
            reason = "APPROACH: verified movement item",
        })
    end
end

function plan.propose_direct_chains(ctx, actions)
    local outside_attack_range = ctx.distance > ctx.ranges.attack + 20
    local escape_rescue_ready = outside_attack_range
        and S.guard_stage_completed
        and (not ui.use_guard:Get() or flame_guard_active(ctx.hero))
    if not ui.use_chains:Get()
        or not S.engagement_started
        or not (S.opening_pressure_completed or escape_rescue_ready) then return false end

    -- Chains is a rescue for a target ESCAPING, never for one standing still.
    -- "Outside attack range" used to be enough on its own, so a stationary hero
    -- Ember simply had not closed on yet ate a Chains for nothing. Require real
    -- outward movement, measured as the component of the target's velocity
    -- pointing directly away from Ember.
    local away_speed = 0
    if ctx.target_pos and ctx.hero_pos then
        local velocity = motion.velocity(ctx.target_index)
        away_speed = dot2d(velocity, normalize2d(sub(ctx.target_pos, ctx.hero_pos)))
    end
    local min_away = ui.chains_min_away:Get()
    local fleeing = away_speed >= math.max(1, min_away)
    if min_away > 0 then
        -- Strict: the ENEMY must be the one running. ctx.gaining_distance is
        -- not enough on its own, since that also rises when Ember is the one
        -- moving away, which would still burn Chains on a stationary target.
        if not fleeing then return false end
    elseif not (ctx.gaining_distance or outside_attack_range) then
        return false
    end
    -- And only once that movement is actually carrying them out of reach --
    -- chasing range is what Chains buys back. chains_hit_chance below still
    -- enforces that they are inside the Chains radius.
    if ctx.distance < ctx.ranges.attack - 60 then return false end
    if not hero_can_cast(ctx.hero) or not ability_usable(ctx.hero, S.abilities.chains, ui.mana_reserve:Get()) then
        return false
    end
    if safe(function() return NPC.HasState(ctx.target, Enum.ModifierState.MODIFIER_STATE_ROOTED) end, false) then
        return false
    end
    if plan.spell_immune(ctx.target) then
        log_decision("SAVE CHAINS: target is spell immune (BKB / Rage), the root would do nothing")
        return false
    end
    local chance, eligible = chains_hit_chance(ctx.hero, ctx.target, ctx.ranges)
    if chance >= ui.chains_confidence:Get() / 100 then
        propose(actions, "CHAINS", 900, chance, 1, {
            label = "SEARING CHAINS",
            reason = string.format(
                "%s: Chains %.0f%% hit chance (%d units)",
                fleeing and "TARGET FLEEING" or "GAINING DISTANCE",
                chance * 100,
                eligible
            ),
        })
        return true
    end
    return false
end

function plan.propose_kill_secure(ctx, actions)
    if not S.engagement_started
        or not S.opening_pressure_completed then return false end
    if S.sleight_kill_committed_index == ctx.target_index then return false end
    local lethal, damage, hp, confidence = can_sleight_kill(ctx.hero, ctx.target, ctx.ranges)
    if lethal then
        local cast_pos = sleight_cast_position(ctx.hero, ctx.target, ctx.ranges, 0.05, 80)
        if not cast_pos then return false end
        S.sleight_role = "KILL_SECURE"
        propose(actions, "SLEIGHT_KS", 950, confidence == "high" and 0.95 or 0.80, 1, {
            position = cast_pos,
            cast_target = ctx.target,
            prediction_slack = 45,
            label = "SLEIGHT KILL SECURE",
            reason = string.format("KILL SECURE: %.0f estimated vs %.0f effective HP", damage, hp),
        })
        return true
    end
    return false
end

function plan.propose_remnant_gap_close(ctx, actions)
    if not ui.use_remnant:Get() or not ui.use_activate:Get() or not hero_can_cast(ctx.hero) then return end
    if S.engagement_started or S.opening_remnant_committed then return end
    if ctx.distance <= ctx.ranges.sticky_exit + 20 then return end
    if not ability_usable(ctx.hero, S.abilities.remnant, ui.mana_reserve:Get()) then return end
    scan_owned_remnants(ctx.hero, ctx.time, false)
    if remnant_count() > 0 then
        log_decision("SAVE REMNANT: active owned remnant preserved")
        return
    end
    local destination, confidence, intercept = predict_remnant_intercept(
        ctx.hero,
        ctx.target,
        ctx.ranges,
        ctx.time
    )
    if not destination then
        log_decision("SAVE REMNANT: no reliable reachable intercept")
        return
    end
    local safe_destination, why = destination_safety(
        ctx.hero,
        ctx.target,
        destination,
        intercept.predicted_target,
        intercept.tolerance
    )
    if not safe_destination then
        log_decision("SAVE REMNANT: " .. why)
        return
    end
    propose(actions, "START_REMNANT", 840, confidence, 3, {
        position = destination,
        intercept = intercept,
        label = intercept.approach_only
            and "MAX-RANGE FIRE REMNANT"
            or "OPEN WITH FIRE REMNANT",
        reason = intercept.approach_only
            and string.format(
                "MAX-RANGE APPROACH: %.0f remaining predicted gap",
                intercept.residual_miss
            )
            or string.format(
                "OPENING GAP CLOSE: %.2fs intercept, predicted miss %.0f",
                intercept.eta,
                intercept.residual_miss
            ),
    })
end

function plan.propose_reconnect_remnant(ctx, actions)
    local reconnect_threshold = math.max(
        ctx.ranges.sticky_exit + 220,
        ctx.ranges.control + 75
    )
    local no_attack_elapsed = S.attack_contact_lost_since
        and ctx.time - S.attack_contact_lost_since or 0
    local no_attack_ready = no_attack_elapsed
        >= ui.reconnect_no_attack_ms:Get() / 1000
    local far_escape_ready = ctx.distance > reconnect_threshold
    if (not S.opening_remnant_committed and not S.engagement_started)
        or not ui.use_remnant:Get()
        or not ui.use_activate:Get()
        or not (far_escape_ready or no_attack_ready)
        or ctx.time - S.last_reconnect_remnant_at < 0.25
        or not hero_can_cast(ctx.hero)
        or not ability_usable(ctx.hero, S.abilities.remnant, ui.mana_reserve:Get()) then
        return false
    end
    scan_owned_remnants(ctx.hero, ctx.time, false)
    if remnant_count() > 0 then return false end

    local destination, confidence, intercept = predict_remnant_intercept(
        ctx.hero,
        ctx.target,
        ctx.ranges,
        ctx.time
    )
    if not destination or not intercept then return false end
    local safe_destination, why = destination_safety(
        ctx.hero,
        ctx.target,
        destination,
        intercept.predicted_target,
        intercept.tolerance
    )
    if not safe_destination then
        log_decision("SAVE RECONNECT REMNANT: " .. why)
        return false
    end

    local reconnect_reason = no_attack_ready
        and string.format(
            "NO ATTACK FOR %.1fs: predicted R reconnect at %.0f range",
            no_attack_elapsed,
            ctx.distance
        )
        or string.format(
            "FAST ENEMY RECONNECT: predicted R chase at %.0f range",
            ctx.distance
        )
    propose(actions, "START_REMNANT", 880, confidence, 3, {
        reconnect = true,
        position = destination,
        intercept = intercept,
        label = "RECONNECT FIRE REMNANT",
        reason = reconnect_reason,
    })
    return true
end

local function plan_state(ctx, actions)
    if S.fsm == FSM.DISENGAGE then
        log_decision("DISENGAGE: unsafe chase; no orders")
        return
    end

    if not S.engagement_started then
        S.combo_stage = COMBO_STAGE.GAP_CLOSE
        if S.opening_remnant_committed then
            plan.propose_reconnect_remnant(ctx, actions)
        else
            plan.propose_remnant_gap_close(ctx, actions)
        end
        -- Give the motion sampler a brief clean window so Fire Remnant gets
        -- first choice. Phase/walking are only fallbacks if no safe intercept
        -- becomes available or the one opening Remnant was already committed.
        if ctx.time - S.target_since >= 0.32 then
            plan.propose_phase_boots(ctx, actions)
            plan.propose_move(ctx, actions, 500, "OPENING GAP CLOSE fallback: walk")
        else
            log_decision("OPENING REMNANT: sampling target motion")
        end
        return
    end

    -- The opening pressure milestone is strict and one-time: confirm the real
    -- Guard modifier, then issue two paced right-click orders during that same
    -- Guard window. A dispel/expiry before the second order restarts the count.
    if not S.opening_pressure_completed then
        if ui.use_guard:Get() then
            if flame_guard_active(ctx.hero) then
                if not S.guard_stage_completed or S.guard_confirmed_at < 0 then
                    S.guard_confirmed_at = ctx.time
                    S.post_guard_attack_orders = 0
                    S.opening_attack_confirm_at = -100
                    log_decision("FLAME GUARD CONFIRMED: begin right clicks")
                end
                S.guard_stage_completed = true
            elseif hero_can_cast(ctx.hero)
                and ability_usable(ctx.hero, S.abilities.guard, ui.mana_reserve:Get()) then
                S.guard_stage_completed = false
                S.combo_stage = COMBO_STAGE.GUARD
                plan.propose_flame_guard(ctx, actions, 930)
                if ctx.distance > ctx.ranges.sticky_exit + 40 then
                    plan.propose_phase_boots(ctx, actions)
                    plan.propose_move(ctx, actions, 650, "FLAME GUARD SETUP: regain close range")
                elseif ctx.time - S.guard_cast_at < 0.75 then
                    log_decision("FLAME GUARD: waiting for modifier confirmation")
                end
                return
            else
                -- Guard is down AND on cooldown / unaffordable. Returning here
                -- stalled the whole combo: Ember stood in melee proposing a
                -- Flame Guard it could not cast and nothing else, so it never
                -- even right-clicked. Open with attacks and let Guard return.
                S.guard_stage_completed = true
                log_decision("FLAME GUARD unavailable; opening with right clicks instead")
            end
        else
            S.guard_stage_completed = true
            S.guard_confirmed_at = -100
        end

        -- Do not strand the opening sequence when the enemy leaves attack
        -- range before right click 2 can confirm.  A confirmed Guard unlocks
        -- this narrow escape-rescue path; range and hit chance are still
        -- checked here and again immediately before the Chains order.
        if ctx.distance > ctx.ranges.attack + 20
            and plan.propose_direct_chains(ctx, actions) then
            S.combo_stage = COMBO_STAGE.CONTROL
            return
        end

        -- If Chains did not restore contact and the selected enemy has stayed
        -- outside real attack reach for the configured 1.5 seconds, spend a
        -- fresh predicted R -> D even before the two-hit opening milestone.
        if plan.propose_reconnect_remnant(ctx, actions) then
            S.combo_stage = COMBO_STAGE.GAP_CLOSE
            return
        end

        if S.post_guard_attack_orders >= 2
            and S.opening_attack_confirm_at > 0
            and ctx.time >= S.opening_attack_confirm_at then
            local still_attacking = safe(function() return NPC.IsAttacking(ctx.hero) end, false)
            local still_in_reach = ctx.distance <= ctx.ranges.attack + 25
            -- Guard being unobtainable must not block the milestone either:
            -- requiring an active Guard here left opening pressure stuck at
            -- 1/2 forever whenever Guard was on cooldown, which in turn kept
            -- every opening_pressure_completed gate shut.
            local guard_still_valid = not ui.use_guard:Get()
                or flame_guard_active(ctx.hero)
                or not ability_usable(ctx.hero, S.abilities.guard, ui.mana_reserve:Get())
            if still_attacking and still_in_reach and guard_still_valid then
                S.opening_pressure_completed = true
                S.opening_attack_confirm_at = -100
                log_decision("RIGHT CLICKS CONFIRMED: control and lethal finish unlocked")
            else
                -- Preserve credit for the first paced attack and retry the
                -- second after a kite/cancel instead of accepting the order.
                S.post_guard_attack_orders = 1
                S.opening_attack_confirm_at = -100
                log_decision("RIGHT CLICK 2: not confirmed; retrying")
            end
        end

        if not S.opening_pressure_completed then
            S.combo_stage = COMBO_STAGE.MELEE
            plan.propose_attack(ctx, actions)
            -- Also park during the opening pressure: a hero can drop under the
            -- threshold before those first right-clicks are even finished.
            plan.propose_preload_remnant(ctx, actions)
            plan.propose_support_items(ctx, actions)
            local orbwalking = plan.propose_orbwalk(
                ctx,
                actions,
                700,
                "HIT & RUN: opening right-click reposition"
            )
            if ctx.distance > ctx.ranges.attack - 25 then
                plan.propose_phase_boots(ctx, actions)
                if not orbwalking then
                    plan.propose_move(ctx, actions, 650, "RIGHT CLICKS: stay on selected enemy")
                end
            elseif orbwalking then
                log_decision("HIT & RUN: cancel backswing and stay on target")
            else
                log_decision(string.format(
                    "RIGHT CLICKS: opening pressure %d/2",
                    S.post_guard_attack_orders
                ))
            end
            return
        end
    end

    -- Once the guarded right-click milestone is complete, never lose a lethal
    -- finish or escape-control window merely because Guard just expired.
    if plan.propose_kill_secure(ctx, actions) then
        S.combo_stage = COMBO_STAGE.FINISH
        return
    end

    local controlling = plan.propose_direct_chains(ctx, actions)
    if controlling then
        S.combo_stage = COMBO_STAGE.CONTROL
        return
    end

    if plan.propose_reconnect_remnant(ctx, actions) then
        S.combo_stage = COMBO_STAGE.GAP_CLOSE
        return
    end

    -- Reconfirm Guard before resuming ordinary right-click pressure. This
    -- refresh does not erase the already completed opening milestone.
    local guard_missing = ui.use_guard:Get() and not flame_guard_active(ctx.hero)
    if guard_missing
        and hero_can_cast(ctx.hero)
        and ability_usable(ctx.hero, S.abilities.guard, ui.mana_reserve:Get()) then
        S.guard_stage_completed = false
        S.combo_stage = COMBO_STAGE.GUARD
        plan.propose_flame_guard(ctx, actions, 880)
        if ctx.distance > ctx.ranges.sticky_exit + 40 then
            plan.propose_phase_boots(ctx, actions)
            plan.propose_move(ctx, actions, 650, "FLAME GUARD REFRESH: regain close range")
        end
        return
    elseif guard_missing then
        -- Guard expired and is on cooldown. Same stall as the opening branch:
        -- waiting for it meant standing still, not even attacking. Keep the
        -- pressure on; Guard resumes on its own when it comes back.
        S.guard_stage_completed = true
        log_decision("FLAME GUARD on cooldown; continuing right-click pressure")
    elseif ui.use_guard:Get() then
        if not S.guard_stage_completed then
            S.guard_confirmed_at = ctx.time
            log_decision("FLAME GUARD REFRESH CONFIRMED")
        end
        S.guard_stage_completed = true
    else
        S.guard_stage_completed = true
    end

    S.combo_stage = COMBO_STAGE.MELEE
    plan.propose_attack(ctx, actions)
    plan.propose_preload_remnant(ctx, actions)
    plan.propose_support_items(ctx, actions)
    local orbwalking = plan.propose_orbwalk(ctx, actions, 700, "HIT & RUN: sticky melee reposition")
    if ctx.distance > ctx.ranges.attack - 25 then
        plan.propose_phase_boots(ctx, actions)
        if not orbwalking then
            plan.propose_move(ctx, actions, 650, "RIGHT-CLICK CHASE: stay on selected enemy")
        end
    elseif orbwalking then
        log_decision("HIT & RUN: moving during attack cooldown")
    else
        log_decision("RIGHT CLICKS: Flame Guard pressure; Sleight saved for lethal finish")
    end
end

local function cursor_follow_position(hero_pos, cursor)
    if not hero_pos or not cursor then return nil end
    local _, distance = normalize2d(sub(cursor, hero_pos))
    if distance < 65 then return nil end
    return ground_position(cursor)
end

local function dancing_ember_enabled(hero)
    return S.control_mode == "DANCE"
        and bind_is_down(ui.dance_combo)
        and ui.use_remnant:Get()
        and ui.use_activate:Get()
        and has_remnant_scepter_upgrade(hero, S.abilities.remnant)
end

function dance.continuation_target(hero)
    local anchor = S.dance_last_anchor or origin(hero)
    local next_target, _, reset_cycle = dance.chain_target(
        hero,
        anchor,
        S.target_index,
        S.dance_visited_indices
    )
    if next_target then return next_target, reset_cycle end

    -- If only one valid enemy remains, a new held-key cycle may start from it;
    -- within an active travel chain the immediately previous hero is still
    -- excluded by the round-robin selector.
    if valid_target(hero, S.target) then
        local target_pos = origin(S.target)
        if target_pos and anchor
            and distance2d(anchor, target_pos) <= dance.chain_cast_range(hero) + 25 then
            return S.target, true
        end
    end
    return nil, false
end

-- The recorded manual combo, reproduced exactly: ONE Activate Fire Remnant
-- carries the whole chain, and the player never casts D again. All that follows
-- is a stream of R casts that keep a remnant permanently ahead of Ember, so the
-- owned-remnant count oscillates 1 -> 2 -> 1 and the bounce never runs dry.
-- Zero charges are topped up with Refresher without ever re-casting D. The
-- chain only ends when no remnants remain and Ember has landed.
function dance.feed_chain(hero, cursor, time)
    if not S.dance_d_used then return false end
    local remnant = S.abilities.remnant
    if not remnant then return false end

    scan_owned_remnants(hero, time, true)
    local remnants = remnant_count()
    local charges = safe(function() return Ability.GetCurrentCharges(remnant) end, 0)

    -- Chain is finished only when nothing is left to bounce to AND Ember is
    -- standing again. A short settle window avoids ending it on the single
    -- frame between one remnant being consumed and the next being placed.
    -- Movement, not remnant count, decides whether the chain is still alive:
    -- during a live chain Ember is constantly being carried between remnants.
    -- Keying the exit on "remnants == 0" deadlocked whenever Ember landed with
    -- a remnant still on the map and nothing left to feed -- the chain could
    -- neither progress nor end, and the bind sat on "still resolving" forever.
    local standing_at = origin(hero)
    if standing_at and S.dance_idle_pos
        and distance2d(standing_at, S.dance_idle_pos) > 150 then
        S.dance_last_move_at = time
    end
    S.dance_idle_pos = standing_at
    S.dance_last_move_at = S.dance_last_move_at or time
    if hero_can_act(hero) and time - S.dance_last_move_at >= 0.45 then
        S.dance_d_used = false
        S.dance_chain_idle_since = nil
        S.dance_idle_pos = nil
        S.dance_last_move_at = nil
        S.dance_last_fed_index = -1
        S.dance_visited_indices = {}
        log_decision(string.format(
            "DANCING EMBER: chain finished (Ember stationary, %d remnants left); reopening R -> D",
            remnants
        ))
        return false
    end

    -- Refresher goes out MID-FLIGHT, while a remnant is still ahead, rather
    -- than at a hard zero. Waiting for zero meant the last remnant was usually
    -- consumed before the charges came back and the chain died on the spot.
    if remnants >= 1
        and charges <= 1
        and ui.dance_refresher:Get()
        and time - (S.dance_last_refresher_at or -100) >= 0.50 then
        local refresher = find_refresher(hero)
        if refresher and cast_no_target(refresher, "ember_sticky_dance_feed_refresher") then
            S.dance_last_refresher_at = time
            log_decision(string.format(
                "DANCING EMBER: Refresher mid-flight at %d charges; chain stays fed", charges
            ))
            return true
        end
    end
    if charges <= 0 then return false end

    -- Keep exactly one remnant ahead. Two already out means the next hop is
    -- covered, so hold the charge until one is consumed.
    if remnants >= 2 then return false end
    if time - (S.dance_last_feed_at or -100) < 0.12 then return false end
    if not dance.chain_remnant_ready(hero, remnant) then return false end

    local anchor = S.dance_last_anchor or origin(hero)
    if not anchor then return false end
    local next_target, _, reset_cycle = dance.chain_target(
        hero, anchor, S.dance_last_fed_index, S.dance_visited_indices
    )
    -- Cursor ownership may redirect the next hop to an unvisited hero.
    local hovered = dance.enemy_under_cursor(hero, cursor)
    local hovered_index = entity_index(hovered)
    local hovered_pos = hovered and origin(hovered) or nil
    if hovered_pos
        and hovered_index ~= S.dance_last_fed_index
        and distance2d(anchor, hovered_pos) <= dance.chain_cast_range(hero) + 25
        and not (S.dance_visited_indices and S.dance_visited_indices[hovered_index]) then
        next_target = hovered
        reset_cycle = false
    end
    if not next_target then return false end

    -- Lead the hop: aim where this hero will be when the remnant lands, not
    -- where they are now. Falls back to their current position when the motion
    -- model is not confident.
    local cast_point = motion.intercept(hero, next_target, anchor, remnant)
        or origin(next_target)
    if not cast_point then return false end
    local destination = dance.remnant_destination(hero, cast_point, remnant, anchor)
    if not destination then return false end

    local ctx = { player = S.player, hero = hero, time = time }
    if not cast_position_immediate(ctx, remnant, destination, "ember_sticky_dance_feed") then
        return false
    end
    if reset_cycle then S.dance_visited_indices = {} end
    S.dance_visited_indices = S.dance_visited_indices or {}
    local fed_index = entity_index(next_target)
    if fed_index >= 0 then S.dance_visited_indices[fed_index] = true end
    S.dance_last_fed_index = fed_index
    S.dance_last_feed_at = time
    S.dance_last_progress_at = time
    S.dance_last_anchor = destination
    set_dance_visual_target(next_target, cast_point, time)
    log_decision(string.format(
        "DANCING EMBER: feeding chain -> %s (%d remnants out, %d charges left)",
        safe(function() return NPC.GetUnitName(next_target) end, "enemy"),
        remnants, charges - 1
    ))
    return true
end

-- --------------------------------------------------------------------------
-- Smart Escape. Strictly manual: nothing here runs unless the Escape bind is
-- physically held. It never reacts to low HP, to being stunned, or to enemies
-- being nearby. Grouped on one table to stay under Lua's 200-local ceiling.
-- --------------------------------------------------------------------------
local escape = {}

-- Which disable, if any, is currently preventing the escape cast. Returned as
-- a reason string so the log can name it instead of silently spamming orders.
function escape.blocked_by(hero)
    if not entity_alive(hero) then return "dead" end
    if safe(function() return NPC.IsStunned(hero) end, false) then return "stunned" end
    if safe(function() return NPC.IsSilenced(hero) end, false) then return "silenced" end
    if safe(function()
        return NPC.HasState(hero, Enum.ModifierState.MODIFIER_STATE_HEXED)
    end, false) then return "hexed" end
    if safe(function()
        return NPC.HasState(hero, Enum.ModifierState.MODIFIER_STATE_ROOTED)
    end, false) then return "rooted" end
    if safe(function()
        return NPC.HasState(hero, Enum.ModifierState.MODIFIER_STATE_OUT_OF_GAME)
    end, false) then return "out of game" end
    if safe(function() return NPC.IsChannellingAbility(hero) end, false) then
        return "channelling"
    end
    return nil
end

-- Real Fire Remnant cast range. dance.chain_cast_range always reports the
-- Scepter value because it max()es it in unconditionally -- fine for the dance,
-- which requires Scepter, but without Aghanim's the escape threw at ~3000 when
-- the true range is 1400, and Dota silently discarded every one of those casts.
function escape.remnant_range(hero)
    local remnant = S.abilities.remnant
    local range = cast_range(hero, remnant, 1400)
    if has_remnant_scepter_upgrade(hero, remnant) then
        local bonus = math.max(0, safe(function()
            return NPC.GetCastRangeBonus(hero)
        end, 0))
        range = math.max(range, special(remnant, { "scepter_range" }, 3000) + bonus)
    end
    return math.max(600, range)
end

function escape.rotate(direction, radians)
    local cosine, sine = math.cos(radians), math.sin(radians)
    return vec(
        direction.x * cosine - direction.y * sine,
        direction.x * sine + direction.y * cosine,
        0
    )
end

-- Threat field: enemy heroes weighted by closeness, enemy towers weighted
-- heavily because walking into tower range is not an escape.
function escape.threats(hero)
    local hero_pos = origin(hero)
    local radius = ui.escape_scan:Get()
    local list = {}
    if not hero_pos then return list, hero_pos end
    for _, enemy in pairs(safe(function() return Heroes.GetAll() end, {})) do
        if valid_target(hero, enemy) then
            local enemy_pos = origin(enemy)
            local distance = enemy_pos and distance2d(hero_pos, enemy_pos) or math.huge
            if distance <= radius then
                list[#list + 1] = {
                    pos = enemy_pos,
                    weight = 1.0 + (1 - distance / radius),
                    avoid = 0,
                }
            end
        end
    end
    local team = safe(function() return Entity.GetTeamNum(hero) end, nil)
    for _, tower in pairs(safe(function() return Towers.GetAll() end, {})) do
        if entity_alive(tower)
            and safe(function() return Entity.GetTeamNum(tower) end, team) ~= team then
            local tower_pos = origin(tower)
            local distance = tower_pos and distance2d(hero_pos, tower_pos) or math.huge
            if distance <= radius then
                -- Hard avoid: never pick a destination inside tower range.
                list[#list + 1] = { pos = tower_pos, weight = 2.5, avoid = 900 }
            end
        end
    end
    -- The fountain is added regardless of distance: an escape aimed at full
    -- cast range can reach it from outside the scan radius, and landing there
    -- is fatal. score_point treats any point inside `avoid` as disqualified.
    if safe(function() return ui.avoid_fountain:Get() end, true) then
        local fountain = plan.enemy_fountain(hero)
        if fountain then
            list[#list + 1] = {
                pos = fountain,
                weight = 4.0,
                avoid = ui.fountain_radius:Get(),
            }
        end
    end
    return list, hero_pos
end

-- Nearest friendly tower doubles as "allied territory" for tie-breaking when
-- several directions are equally far from danger.
function escape.friendly_anchor(hero)
    local hero_pos = origin(hero)
    local team = safe(function() return Entity.GetTeamNum(hero) end, nil)
    if not hero_pos or team == nil then return nil end
    local best, best_distance = nil, math.huge
    for _, tower in pairs(safe(function() return Towers.GetAll() end, {})) do
        if entity_alive(tower)
            and safe(function() return Entity.GetTeamNum(tower) end, nil) == team then
            local tower_pos = origin(tower)
            local distance = tower_pos and distance2d(hero_pos, tower_pos) or math.huge
            if distance < best_distance then best, best_distance = tower_pos, distance end
        end
    end
    return best
end

function escape.score_point(point, threats, anchor)
    local worst = math.huge
    local total = 0
    for _, threat in ipairs(threats) do
        if threat.pos then
            local distance = distance2d(point, threat.pos)
            if threat.avoid > 0 and distance < threat.avoid then return -math.huge end
            worst = math.min(worst, distance)
            total = total + distance * threat.weight
        end
    end
    if worst == math.huge then worst = 3000 end
    -- Distance from the nearest threat dominates; spread from the whole
    -- cluster is secondary; friendly ground is only a tie-breaker.
    local score = worst * 2.0 + total * 0.15
    if anchor then score = score - distance2d(point, anchor) * 0.10 end
    return score
end

-- Fan out candidate destinations around the "directly away" vector and keep
-- the best-scoring traversable one.
function escape.destination(hero)
    local threats, hero_pos = escape.threats(hero)
    if not hero_pos then return nil end
    local remnant = S.abilities.remnant
    local range = escape.remnant_range(hero)

    local away = vec(0, 0, 0)
    for _, threat in ipairs(threats) do
        if threat.pos then
            local direction = normalize2d(sub(hero_pos, threat.pos))
            away = add(away, mul(direction, threat.weight))
        end
    end
    local anchor = escape.friendly_anchor(hero)
    if length2d(away) < 0.01 then
        -- Nothing to run from: fall back to friendly ground, else straight back.
        away = anchor and normalize2d(sub(anchor, hero_pos)) or vec(1, 0, 0)
    end
    away = normalize2d(away)

    local best, best_score = nil, -math.huge
    for step = -4, 4 do
        local direction = escape.rotate(away, math.rad(step * 18))
        for _, fraction in ipairs({ 1.0, 0.8, 0.6, 0.4 }) do
            local point = ground_position(add(hero_pos, mul(direction, range * fraction)))
            if safe(function() return GridNav.IsTraversable(point) end, true) then
                local score = escape.score_point(point, threats, anchor)
                if score > best_score then best, best_score = point, score end
            end
        end
    end
    return best
end

-- Straight at the cursor, clamped to cast range. Simple and predictable: the
-- player already knows where they want to be, and a solver second-guessing
-- that is worse than obeying it. Pulls the point back along the same line if
-- the far end is not traversable, so cliffs do not void the escape.
function escape.cursor_destination(hero)
    local hero_pos = origin(hero)
    local cursor = safe(function() return Input.GetWorldCursorPos() end, nil)
    if not hero_pos or not cursor then return nil end
    local direction, distance = normalize2d(sub(cursor, hero_pos))
    if distance < 50 then return nil end
    -- The cursor sets DIRECTION only; an escape always throws the full cast
    -- range. Clamping to the cursor distance made a nearby click produce a
    -- short hop, which is the opposite of what an escape needs.
    local range = escape.remnant_range(hero)
    for _, fraction in ipairs({ 1.0, 0.9, 0.8, 0.65, 0.5 }) do
        local point = ground_position(add(hero_pos, mul(direction, range * fraction)))
        if safe(function() return GridNav.IsTraversable(point) end, true)
            and not plan.fountain_blocked(hero, point) then
            return point
        end
    end
    return nil
end

-- An existing remnant already sitting somewhere safer is the fastest escape
-- there is: no cast time, just activate.
function escape.safer_existing_remnant(hero, time)
    if not ui.escape_reuse:Get() then return nil end
    scan_owned_remnants(hero, time, true)
    if remnant_count() <= 0 then return nil end
    local threats, hero_pos = escape.threats(hero)
    if not hero_pos then return nil end
    local here = escape.score_point(hero_pos, threats, nil)
    local best, best_score = nil, here
    for _, info in pairs(S.remnants) do
        if info.position then
            local score = escape.score_point(info.position, threats, nil)
            -- Only worth it if clearly safer than standing still.
            if score > best_score + 400 then best, best_score = info, score end
        end
    end
    return best
end

function escape.reset(reason)
    S.escape_phase = "IDLE"
    S.escape_destination = nil
    S.escape_attempts = 0
    S.escape_charges_before = -1
    S.escape_was_blocked = false
    S.escape_blocked_reason = nil
    if reason then log_decision("ESCAPE: " .. reason) end
end

function escape.run(hero, time)
    if not bind_assigned(ui.escape_key) or not bind_is_down(ui.escape_key) then
        if S.escape_phase ~= "IDLE" or (S.escape_spent or 0) > 0 then
            -- The charge budget is per held press, so releasing the key is what
            -- re-arms it. Holding forever must not drain every charge.
            S.escape_spent = 0
            S.escape_dash_from = nil
            S.escape_dash_to = nil
            escape.reset("key released")
        end
        return false
    end

    local blocked = escape.blocked_by(hero)
    if blocked then
        -- Deliberately issue nothing at all: an order sent under a disable is
        -- discarded and only creates spam. Just remember it and wait.
        if S.escape_blocked_reason ~= blocked then
            S.escape_blocked_reason = blocked
            log_decision("ESCAPE: holding through " .. blocked .. "; will fire the moment it ends")
        end
        S.escape_was_blocked = true
        S.escape_phase = "WAIT_DISABLE"
        return true
    end
    S.escape_blocked_reason = nil

    local remnant, activate = S.abilities.remnant, S.abilities.activate
    local charges = safe(function() return Ability.GetCurrentCharges(remnant) end, 0)
    local remnant_ready = remnant
        and charges > 0
        and safe(function() return Ability.IsCastable(remnant, NPC.GetMana(hero)) end, false)

    -- Just came out of a disable. Sleight is only worth it when the Remnant
    -- escape is NOT immediately available -- otherwise it delays a guaranteed
    -- escape, and survival outranks the prettier sequence.
    if S.escape_was_blocked then
        S.escape_was_blocked = false
        if ui.escape_sleight:Get()
            and not remnant_ready
            and time - S.escape_sleight_at > 1.0
            and ability_usable(hero, S.abilities.sleight, 0) then
            local ranges = ability_ranges(hero, hero)
            local nearby = safe(function()
                return Entity.GetUnitsInRadius(
                    hero, ranges.sleight_radius or 250,
                    Enum.TeamType.TEAM_ENEMY, true, true
                )
            end, {})
            if #nearby > 0 then
                if cast_no_target(S.abilities.sleight, "ember_sticky_escape_sleight") then
                    S.escape_sleight_at = time
                    log_decision("ESCAPE: disable ended, Remnant not ready -> Sleight while it comes up")
                    return true
                end
            end
        end
    end

    if time < S.escape_cooldown_until then return true end

    -- Phase: confirm a placed Remnant, then dash. Kept short and bounded so a
    -- dropped order is retried instead of stalling the escape.
    if S.escape_phase == "CONFIRM" then
        scan_owned_remnants(hero, time, true)
        -- Default is to activate the moment the charge is spent. Fire Remnant
        -- flies to its destination, so waiting for it to land travels further
        -- -- but half a second standing still defeats the point of an escape,
        -- so distance loses to speed here. Waiting is opt-in via
        -- ui.escape_wait_land.
        local arrived = nil
        for _, info in pairs(S.remnants) do
            if info.position and S.escape_destination
                and distance2d(info.position, S.escape_destination) <= 250 then
                arrived = info
                break
            end
        end
        local placed = charges < (S.escape_charges_before or 0)
        if (placed or arrived) and not S.escape_counted then
            S.escape_counted = true
            S.escape_spent = (S.escape_spent or 0) + 1
        end
        if arrived then
            S.escape_phase = "ACTIVATE"
        elseif placed and not ui.escape_wait_land:Get() then
            S.escape_phase = "ACTIVATE"
        elseif placed then
            -- Failsafe so a lost remnant can never strand the escape.
            if time - S.escape_order_at >= 1.10 then
                S.escape_phase = "ACTIVATE"
                log_decision("ESCAPE: Remnant landing not seen in time; dashing anyway")
            end
            return true
        elseif time - S.escape_order_at >= 0.30 then
            if (S.escape_attempts or 0) >= 3 or not remnant_ready then
                -- If charges never move while the order keeps "succeeding",
                -- the order is being dropped before it reaches the game.
                -- Umbrella's Safe Mode does exactly this, silently.
                escape.reset(string.format(
                    "Remnant order never landed (charges %d->%d): %s",
                    S.escape_charges_before or -1, charges,
                    order.diagnose(hero, remnant, S.escape_destination)
                ))
            else
                S.escape_attempts = S.escape_attempts + 1
                S.escape_charges_before = charges
                S.escape_order_at = time
                cast_position(remnant, S.escape_destination, "ember_sticky_escape_remnant", false, false)
                log_decision("ESCAPE: re-sending Remnant order")
            end
            return true
        else
            return true
        end
    end

    if S.escape_phase == "ACTIVATE" then
        -- No artificial delay: this fires on the very next tick after the
        -- Remnant is confirmed placed.
        if not activate_usable(hero, activate, 0)
            and not committed_dance_activate_ready(hero, activate, 0) then
            if time - S.escape_order_at >= 1.20 then
                escape.reset("could not activate; restarting")
            end
            return true
        end
        if cast_position(activate, S.escape_destination, "ember_sticky_escape_activate", true, true) then
            S.escape_cooldown_until = time + 0.60
            -- Remember the dash so the next hop can wait until Ember has
            -- actually covered it, instead of being thrown mid-flight.
            S.escape_dash_from = origin(hero)
            S.escape_dash_to = S.escape_destination
            log_decision("ESCAPE: dashing out")
            escape.reset(nil)
            S.escape_phase = "IDLE"
        end
        return true
    end

    -- Fastest option of all: a remnant already sitting somewhere safer.
    local existing = escape.safer_existing_remnant(hero, time)
    if existing and existing.position
        and (activate_usable(hero, activate, 0)
            or committed_dance_activate_ready(hero, activate, 0)) then
        if cast_position(activate, existing.position, "ember_sticky_escape_reuse", true, true) then
            S.escape_cooldown_until = time + 0.60
            log_decision("ESCAPE: existing Remnant is safer; dashing to it")
            return true
        end
    end

    if (S.escape_spent or 0) >= ui.escape_max_charges:Get() then
        if S.escape_phase ~= "SPENT" then
            S.escape_phase = "SPENT"
            log_decision(string.format(
                "ESCAPE: charge budget spent (%d); release the key to re-arm",
                S.escape_spent or 0
            ))
        end
        return true
    end
    if not remnant_ready or not hero_can_cast(hero) then return true end
    if time - S.escape_order_at < 0.12 then return true end

    -- A follow-up hop thrown while Ember is still in the air is wasted: the
    -- Remnant lands near the flight path rather than ahead of the landing, so
    -- the second dash covers almost nothing. Hold it until the current dash is
    -- essentially complete.
    if S.escape_dash_to and S.escape_dash_from then
        local hero_pos = origin(hero)
        local total = distance2d(S.escape_dash_from, S.escape_dash_to)
        if hero_pos and total > 1 then
            local progress = 1 - (distance2d(hero_pos, S.escape_dash_to) / total)
            if progress < ui.escape_next_hop:Get() / 100 then
                if S.escape_phase ~= "IN_FLIGHT" then
                    S.escape_phase = "IN_FLIGHT"
                    log_decision("ESCAPE: mid-dash; holding the next Remnant until landing")
                end
                return true
            end
        end
        -- Dash accounted for; clear it so it cannot gate later escapes.
        S.escape_dash_from = nil
        S.escape_dash_to = nil
        S.escape_phase = "IDLE"
    end

    -- Cursor by default; the solver is opt-in. Cursor mode still falls back to
    -- the solver when the cursor is unusable (on top of Ember, or every point
    -- along that line blocked), so the escape is never simply skipped.
    local destination
    if safe(function() return ui.escape_mode:Get() end, 0) == 1 then
        destination = escape.destination(hero)
    else
        destination = escape.cursor_destination(hero) or escape.destination(hero)
    end
    if not destination then
        log_decision("ESCAPE: no traversable destination found")
        return true
    end
    -- execute_fast stays false: every Fire Remnant placement that actually
    -- lands in this file passes false, and the fast variant was silently
    -- rejected by the game -- the order returned ok but no charge was spent.
    if cast_position(remnant, destination, "ember_sticky_escape_remnant", false, false) then
        S.escape_destination = destination
        S.escape_charges_before = charges
        S.escape_order_at = time
        S.escape_attempts = 1
        -- Counted on real consumption, not on the order: a rejected order
        -- spends nothing and must not eat the budget.
        S.escape_counted = false
        S.escape_phase = "CONFIRM"
        log_decision(safe(function() return ui.escape_mode:Get() end, 0) == 1
            and "ESCAPE: Remnant thrown toward the safest direction"
            or "ESCAPE: Remnant thrown toward the cursor")
    end
    return true
end

local function try_dancing_ember(hero, cursor, time)
    if not dancing_ember_enabled(hero)
        or S.dance_d_used
        or S.tx ~= nil
        or not hero_can_cast(hero) then return false end

    local remnant, activate = S.abilities.remnant, S.abilities.activate
    if not remnant or not activate
        or not has_remnant_scepter_upgrade(hero, remnant) then return false end

    -- The first spend in a held session remains mouse-authorized. Once that
    -- happens, the authorization remains latched until key release so a
    -- completed/retried cycle can continue on nearby enemies automatically.
    local hovered_target = dance.enemy_under_cursor(hero, cursor)
    local selected_target, reset_cycle = nil, false
    if hovered_target then
        S.dance_hold_authorized = true
    end
    if S.dance_hold_authorized then
        local continuation_target, continuation_reset = dance.continuation_target(hero)
        local hovered_index = entity_index(hovered_target)
        local hovered_visited = S.dance_visited_indices
            and S.dance_visited_indices[hovered_index] == true
        if hovered_target and (not hovered_visited or continuation_reset) then
            selected_target = hovered_target
            reset_cycle = hovered_visited and continuation_reset or false
        else
            selected_target = continuation_target
            reset_cycle = continuation_reset
        end
    end
    if not selected_target then return false end
    if reset_cycle then S.dance_visited_indices = {} end
    if not same_entity(selected_target, S.target) then
        set_target(selected_target, target_score(hero, selected_target, cursor), time)
    end
    sync_highlight()

    local selected_position = origin(selected_target)
    if not selected_position then return false end
    local destination, effective_range, profile, cursor_distance, hero_pos =
        dance.remnant_destination(hero, selected_position, remnant)
    if not destination then return false end

    local target = valid_target(hero, S.target) and S.target or nil
    local target_pos = target and origin(target) or nil
    local ranges = target and ability_ranges(hero, target) or {
        sticky_exit = 325,
        remnant_cast = effective_range,
    }
    ranges.remnant_cast = math.max(ranges.remnant_cast or 0, effective_range)
    local turn_delay = remnant_turn_delay(destination, profile)
    local outbound = turn_delay
        + profile.placement_cast_point
        + distance2d(hero_pos, destination) / profile.placement_speed
    local intercept = {
        target_origin = target_pos or destination,
        target_velocity = vec(0, 0, 0),
        predicted_target = destination,
        eta = outbound + remnant_activation_time(hero_pos, destination, profile, true),
        outbound_eta = outbound,
        turn_delay = turn_delay,
        residual_miss = 0,
        tolerance = 180,
        range_clamped = cursor_distance > profile.cast_range,
        approach_only = false,
        motion_confidence = 1,
        confidence = 1,
        profile = profile,
    }
    local ctx = {
        time = time,
        hero = hero,
        player = S.player,
        target = target,
        target_index = S.target_index,
        target_epoch = S.target_epoch,
        hold_epoch = S.hold_epoch,
        map_epoch = S.map_epoch,
        hero_pos = hero_pos,
        target_pos = target_pos,
        distance = target_pos and distance2d(hero_pos, target_pos) or math.huge,
        ranges = ranges,
    }

    scan_owned_remnants(hero, time, true)
    if remnant_count() > 0 then
        -- Leftover owned Remnants with no active transaction used to dead-end
        -- here: the controller refused to open a new cycle while any remnant
        -- was on the map, so a held key just spun on "waiting for a castable
        -- Remnant" until they expired. That is exactly the post-Refresher
        -- stall. The remnants are already placed, so dash to them instead --
        -- an activate-only transaction consumes them and resumes the chain.
        if S.tx or S.dance_d_used then return false end
        if not activate_usable(hero, S.abilities.activate, ui.mana_reserve:Get()) then
            return false
        end
        local nearest, nearest_distance = nil, math.huge
        for _, info in pairs(S.remnants) do
            local distance = info.position and distance2d(hero_pos, info.position) or math.huge
            if distance < nearest_distance then
                nearest, nearest_distance = info, distance
            end
        end
        if not nearest or not nearest.position then return false end
        S.tx = {
            kind = "REMNANT",
            dance = true,
            -- Chaining through every leftover remnant is the goal here, so the
            -- usual "never consume more than one" reserve guard must not abort
            -- this recovery the moment two or more are on the map.
            allow_multiple_active = true,
            -- Chaining stays ENABLED here. This recovery used to set no_chain
            -- to stop an R spam, but that spam was really the separate bug
            -- where a hop was only claimed on confirmation; blocking the chain
            -- here just ended the bounce early after a Refresher or a leftover
            -- pickup, when it should carry straight on to the next hero.
            phase = "READY_TO_ACTIVATE",
            target_index = S.target_index,
            target_epoch = S.target_epoch,
            hold_epoch = S.hold_epoch,
            map_epoch = S.map_epoch,
            destination = nearest.position,
            original_destination = nearest.position,
            activation_position = nearest.position,
            sticky_exit = ranges.sticky_exit,
            baseline_indices = {},
            charges_before = safe(function()
                return Ability.GetCurrentCharges(remnant)
            end, 0),
            remnant_index = nearest.index,
            placement_confirmed = true,
            placement_confirmed_at = time,
            activation_attempts = 0,
            activation_deadline = time + 1.60,
            arrival_deadline = time + 2.40,
            correction_attempts = 0,
            chain_casts = 0,
            last_chain_cast_at = -100,
            last_chain_target_index = S.target_index,
            chain_visited_indices = S.dance_visited_indices or {},
            chain_anchor_position = nearest.position,
            last_plan_at = time,
        }
        S.dance_last_anchor = nearest.position
        log_decision("DANCING EMBER: leftover Remnant on the map; activating it instead of stalling")
        return true
    end
    local charges = safe(function() return Ability.GetCurrentCharges(remnant) end, 0)
    if charges <= 0 then
        if not ui.dance_refresher:Get() then return false end
        local refresher = find_refresher(hero)
        if not refresher then return false end
        local refresh_actions = new_actions()
        propose(refresh_actions, "DANCE_REFRESHER", 1200, 1.0, 1, {
            ability = refresher,
            label = "DANCING EMBER REFRESHER",
            reason = "DANCING EMBER: zero Remnant charges -> Refresher Orb",
        })
        for _, action in ipairs(rank_actions(refresh_actions)) do
            if execute_action(ctx, action) then return true end
        end
        return false
    end
    if not ability_usable(hero, remnant, 0) then return false end

    local actions = new_actions()
    propose(actions, "START_REMNANT", 1100, 1.0, 3, {
        dance = true,
        position = destination,
        intercept = intercept,
        label = "DANCING EMBER R",
        reason = "SCEPTER DANCE: cursor-selected enemy R -> immediate D",
    })
    for _, action in ipairs(rank_actions(actions)) do
        if execute_action(ctx, action) then return true end
    end
    return false
end

local function suppress_dance_autoattack(hero, time)
    if not hero_can_act(hero) or not S.player then return false end
    local ctx = {
        time = time,
        hero = hero,
        player = S.player,
        target = valid_target(hero, S.target) and S.target or nil,
        target_index = S.target_index,
        target_epoch = S.target_epoch,
        hold_epoch = S.hold_epoch,
        map_epoch = S.map_epoch,
        hero_pos = origin(hero),
        target_pos = valid_target(hero, S.target) and origin(S.target) or nil,
        distance = math.huge,
        ranges = {},
    }
    local actions = new_actions()
    propose(actions, "DANCE_HOLD", 100, 1.0, 0, {
        dance = true,
        label = "DANCING EMBER - NO AUTO ATTACK",
        reason = "DANCING EMBER: hold position while waiting; attacks suppressed",
    })
    for _, action in ipairs(rank_actions(actions)) do
        if execute_action(ctx, action) then return true end
    end
    return false
end

local function build_remnant_transaction_context(hero, time)
    local tx = S.tx
    if not tx or tx.kind ~= "REMNANT" then return nil end
    local hero_pos = origin(hero)
    if not hero_pos then return nil end
    local target = valid_target(hero, S.target) and S.target or nil
    local target_pos = target and origin(target) or nil
    local ranges = target and ability_ranges(hero, target) or {
        sticky_exit = tx.sticky_exit or 325,
    }
    return {
        time = time,
        cursor = safe(function() return Input.GetWorldCursorPos() end, nil),
        hero = hero,
        player = S.player,
        target = target,
        target_index = S.target_index,
        target_epoch = S.target_epoch,
        hold_epoch = S.hold_epoch,
        map_epoch = S.map_epoch,
        hero_pos = hero_pos,
        target_pos = target_pos,
        distance = target_pos and distance2d(hero_pos, target_pos) or math.huge,
        ranges = ranges,
    }
end

local function update_remnant_transaction(hero, time)
    local ctx = build_remnant_transaction_context(hero, time)
    if not ctx then return false end
    local actions = new_actions()
    plan_transaction(ctx, actions)
    for _, action in ipairs(rank_actions(actions)) do
        if execute_action(ctx, action) then break end
    end
    return true
end

-- The parked Remnant pays off here: the current hero is dead or gone, so dash
-- to the next one immediately. Triggered by the kill itself, so it works no
-- matter who landed it -- the trainer's Sleight finish or the Kill Stealer.
local function try_preload_dash(hero, time)
    local preload = S.preload
    if not preload then return false end
    if S.control_mode ~= "COMBO"
        or not bind_is_down(ui.combo)
        or time > (preload.expires_at or time) then
        log_decision(string.format(
            "PRELOAD DROPPED: %s",
            time > (preload.expires_at or time) and "expired before the kill"
                or "combo key released"
        ))
        S.preload = nil
        return false
    end
    if S.tx then return false end

    -- Confirm the park actually landed, and retry if the order was dropped.
    if not preload.confirmed then
        scan_owned_remnants(hero, time, true)
        local landed, landed_distance = nil, math.huge
        for _, info in pairs(S.remnants) do
            local distance = info.position
                and distance2d(info.position, preload.position) or math.huge
            if distance < landed_distance then
                landed, landed_distance = info, distance
            end
        end
        local charges = safe(function()
            return Ability.GetCurrentCharges(S.abilities.remnant)
        end, preload.charges_before or 0)
        if landed and landed_distance <= 400 then
            preload.confirmed = true
            preload.remnant_index = landed.index
            log_decision("PRELOAD CONFIRMED: Remnant parked on the next enemy")
        elseif charges < (preload.charges_before or 0) then
            -- A charge was spent, so the cast took even if the entity has not
            -- been seen by the scan yet.
            preload.confirmed = true
            log_decision("PRELOAD CONFIRMED: charge spent parking the Remnant")
        elseif time - (preload.last_order_at or time) >= 0.35 then
            if (preload.attempts or 0) >= 4
                or not ability_usable(hero, S.abilities.remnant, ui.mana_reserve:Get()) then
                log_decision("PRELOAD DROPPED: park order never landed: "
                    .. order.diagnose(hero, S.abilities.remnant, preload.position))
                S.preload = nil
                return false
            end
            preload.attempts = (preload.attempts or 0) + 1
            preload.last_order_at = time
            preload.charges_before = charges
            cast_position(
                S.abilities.remnant,
                preload.position,
                "ember_sticky_preload_remnant",
                false,
                false
            )
            log_decision(string.format(
                "PRELOAD RETRY: re-sending the park order (attempt %d)", preload.attempts
            ))
            return false
        end
    end

    -- Fire on the death of the hero this remnant was parked for. Anything else
    -- (cursor wandering onto a new enemy, a retarget) must not consume it.
    if preload.killing_target and valid_target(hero, preload.killing_target) then
        return false
    end
    if not preload.confirmed then return false end
    if not ui.use_activate:Get() or not valid_target(hero, preload.target) then
        log_decision("PRELOAD DROPPED: next target is no longer valid")
        S.preload = nil
        return false
    end
    if not activate_usable(hero, S.abilities.activate, ui.mana_reserve:Get()) then
        log_decision("PRELOAD WAIT: D not castable yet")
        return false
    end

    scan_owned_remnants(hero, time, true)
    local parked, parked_distance = nil, math.huge
    for _, info in pairs(S.remnants) do
        local distance = info.position
            and distance2d(info.position, preload.position) or math.huge
        if distance < parked_distance then
            parked, parked_distance = info, distance
        end
    end
    -- Only accept a remnant actually sitting where this preload put it.
    if not parked or parked_distance > 350 then
        log_decision(string.format(
            "PRELOAD DROPPED: no parked Remnant near the preload spot (%d owned, nearest %.0f)"
                .. " - if charges never moved either, check Umbrella Safe Mode",
            remnant_count(), parked_distance
        ))
        S.preload = nil
        return false
    end

    local hero_pos = origin(hero)
    if not hero_pos then return false end
    set_target(preload.target, 0, time)
    sync_highlight()

    S.tx = {
        kind = "REMNANT",
        dance = false,
        no_chain = true,
        phase = "READY_TO_ACTIVATE",
        target_index = S.target_index,
        target_epoch = S.target_epoch,
        hold_epoch = S.hold_epoch,
        map_epoch = S.map_epoch,
        destination = parked.position,
        original_destination = parked.position,
        activation_position = parked.position,
        sticky_exit = 325,
        baseline_indices = {},
        charges_before = safe(function()
            return Ability.GetCurrentCharges(S.abilities.remnant)
        end, 0),
        remnant_index = parked.index,
        placement_confirmed = true,
        placement_confirmed_at = time,
        activation_attempts = 0,
        activation_deadline = time + 1.60,
        arrival_deadline = time + 2.40,
        correction_attempts = 0,
        chain_casts = 0,
        last_chain_cast_at = -100,
        last_chain_target_index = S.target_index,
        chain_visited_indices = {},
        chain_anchor_position = parked.position,
        last_plan_at = time,
    }
    S.preload = nil
    S.engagement_started = false
    S.opening_remnant_committed = true
    S.combo_stage = COMBO_STAGE.ACTIVATE
    set_fsm(FSM.GAP_CLOSE, time)
    log_decision("KILL FOLLOW-UP: dashing to the preloaded Remnant on the next enemy")
    return true
end

local function try_sleight_kill_handoff(hero, time)
    local handoff = S.sleight_handoff
    if not handoff then return false end
    if S.control_mode ~= "COMBO"
        or not bind_is_down(ui.combo)
        or time > (handoff.expires_at or time) then
        S.sleight_handoff = nil
        return false
    end
    if S.tx then return false end

    local cursor = safe(function() return Input.GetWorldCursorPos() end, nil)
    if not cursor then return false end
    local next_target, score = best_other_combo_target(
        hero,
        cursor,
        handoff.excluded_index or -1
    )
    if not next_target then return false end
    if not same_entity(next_target, S.target) then
        set_target(next_target, score, time)
    end
    sync_highlight()
    sample_target_history(hero, next_target, time)

    local ctx = build_context(hero, next_target, time)
    if not ctx then return false end
    local destination, confidence, intercept = predict_remnant_intercept(
        hero,
        next_target,
        ctx.ranges,
        time
    )
    if not destination or not intercept then return false end

    local actions = new_actions()
    propose(actions, "START_REMNANT", 1150, confidence, 3, {
        sleight_handoff = true,
        position = destination,
        intercept = intercept,
        label = "SLEIGHT KILL -> NEXT REMNANT",
        reason = "LETHAL SLEIGHT: cast R toward next target during Sleight",
    })
    for _, action in ipairs(rank_actions(actions)) do
        if execute_action(ctx, action) then
            S.sleight_handoff = nil
            return true
        end
    end
    return false
end

-- --------------------------------------------------------------------------
-- Main update
-- --------------------------------------------------------------------------

function script.OnUpdate()
    detect_map_change()
    local time = now()
    if S.last_clock > 0 and time + 0.25 < S.last_clock then
        S.map_epoch = S.map_epoch + 1
        hard_reset("game clock reset")
        reset_session_cache()
    end
    S.last_clock = time
    local in_game = safe(function() return Engine.IsInGame() end, false)
    if not in_game then
        hard_reset("not in game")
        set_status("not in game")
        return
    end

    local hero = get_local_ember()
    S.hero = hero
    if not hero then
        hard_reset("waiting for local Ember Spirit")
        set_status("waiting for Ember Spirit")
        return
    end

    local allowed, gate_reason = evaluate_training_gate(time)
    local combo_assigned = combo_bind_assigned()
    local dance_assigned = dance.bind_assigned()
    local dance_down = dance_assigned and bind_is_down(ui.dance_combo)

    -- Escape owns the hero outright while its key is held, ahead of every other
    -- controller. It is inert otherwise: escape.run returns immediately unless
    -- the bind is physically down, so nothing here touches normal gameplay.
    if allowed
        and not safe(function() return GameRules.IsPaused() end, false)
        and not safe(function() return Input.IsInputCaptured() end, false) then
        refresh_abilities(hero, time)
        S.player = safe(function() return Players.GetLocal() end, S.player)
        if escape.run(hero, time) then
            set_status("HERO DEMO - SMART ESCAPE")
            return
        end
    end

    -- Auto Chains During Sleight must also cover a Sleight of Fist cast
    -- entirely on the player's own keybind: no trainer bind held, the sticky
    -- combo master switch off, or the Combo/Dance binds never configured at
    -- all. Every one of those cases returns early below before the combo/dance
    -- state machine ever reaches the Sleight-chain logic, so this standalone
    -- check runs first -- gated only on the hero-demo safety rail and not
    -- being paused/input-captured, same as the rest of the trainer.
    if allowed
        and ui.auto_sleight_chains:Get()
        and not safe(function() return GameRules.IsPaused() end, false)
        and not safe(function() return Input.IsInputCaptured() end, false) then
        -- S.abilities is populated by refresh_abilities, which only runs much
        -- further down (after the bind-held gates). This standalone path runs
        -- before it, so without this call S.abilities.chains/.sleight are nil
        -- and every ability check silently fails with chains_found=false.
        refresh_abilities(hero, time)
    end
    if allowed
        and ui.auto_sleight_chains:Get()
        and sleight_in_progress(hero)
        and not safe(function() return GameRules.IsPaused() end, false)
        and not safe(function() return Input.IsInputCaptured() end, false) then
        if try_auto_sleight_chains(hero, time) then
            set_status("HERO DEMO - AUTO CHAINS DURING SLEIGHT (manual)")
            return
        end
        -- Never return here just because a Sleight is resolving. This window is
        -- a fixed 2.2s from the order stamp -- longer than a short Sleight
        -- actually lasts -- and Umbrella's Kill Stealer fires Sleight often, so
        -- returning froze the whole trainer for ~2s per steal: no attacks, no
        -- movement, and any in-flight dance transaction aged out against its
        -- wall-clock deadlines. The chain already got first refusal above; if
        -- it did not cast, fall through and let the normal planner keep
        -- working. Its own validators no-op while Ember is genuinely out of
        -- game and resume the moment it can act.
        set_status("HERO DEMO - TRACKING SLEIGHT")
    end

    if not ui.enabled:Get() and not dance_down then
        hard_reset("disabled")
        set_status("disabled")
        return
    end
    if not allowed then
        hard_reset("TRAINING GATE BLOCKED: " .. gate_reason)
        set_status("BLOCKED - hero demo only")
        return
    end
    if not combo_assigned and not dance_assigned then
        if S.held or S.target then hard_reset("combo and dance keys unbound") end
        set_status("BIND COMBO OR DANCING EMBER KEY")
        return
    end
    if safe(function() return GameRules.IsPaused() end, false) then
        hard_reset("paused")
        set_status("paused")
        return
    end
    if safe(function() return Input.IsInputCaptured() end, false) then
        hard_reset("input captured")
        set_status("input captured")
        return
    end

    -- Dancing Ember owns input when both binds are held; otherwise the normal
    -- Combo Key remains the complete Guard/right-click/Chains/Sleight combo.
    local combo_down = combo_assigned and bind_is_down(ui.combo)
    local requested_mode = dance_down and "DANCE" or (combo_down and "COMBO" or "NONE")
    if requested_mode == "NONE" then
        if S.held or S.target then hard_reset("controller bind released") end
        set_status("HERO DEMO - hold Combo or Dancing Ember")
        return
    end
    if requested_mode == "COMBO" and builtin_combo_key_conflict() then
        if S.held or S.target then hard_reset("built-in Ember combo key conflict") end
        set_status("KEY CONFLICT - DISABLE BUILT-IN EMBER")
        return
    end
    if S.held and S.control_mode ~= requested_mode then
        hard_reset("controller bind changed")
    end

    local active_remnant_transaction = S.tx and S.tx.kind == "REMNANT"
    local sleight_handoff_active = S.sleight_handoff
        and time <= (S.sleight_handoff.expires_at or time)
    local sleight_chain_active = ui.auto_sleight_chains:Get()
        and (S.sleight_chain ~= nil or sleight_in_progress(hero))
    if not hero_can_act(hero) then
        if not entity_alive(hero) then
            hard_reset("local Ember is dead")
            set_status("waiting for Ember to respawn")
            return
        elseif active_remnant_transaction then
            -- Keep tracking a placed/outbound Remnant through a transient cast,
            -- stun, or dash state. The central order validator still blocks a
            -- new activation until Ember can act again.
            set_status("HERO DEMO - tracking Remnant")
        elseif sleight_handoff_active or sleight_chain_active then
            -- Ember may legally place Fire Remnant during Sleight. Continue to
            -- the dedicated next-target handoff while ordinary actions remain
            -- blocked by their central validators.
            set_status("HERO DEMO - SLEIGHT NEXT-TARGET HANDOFF")
        else
            -- Preserve the held combo, target, opening-Remnant commitment, and
            -- completed stages through a temporary stun/out-of-game state.
            set_status("waiting for Ember to act")
            return
        end
    end

    if not S.held then
        S.held = true
        S.control_mode = requested_mode
        S.hold_epoch = S.hold_epoch + 1
        set_fsm(FSM.ACQUIRE, time)
    end
    set_status("HERO DEMO - trainer active")

    local interval = ui.update_ms:Get() / 1000
    if time - S.last_update < interval then return end
    S.last_update = time
    S.player = safe(function() return Players.GetLocal() end, nil)
    if not S.player then
        hard_reset("local player unavailable")
        return
    end
    local player_id = safe(function() return Player.GetPlayerID(S.player) end, -1)
    if player_id < 0 or not safe(function() return Entity.IsControllableByPlayer(hero, player_id) end, false) then
        hard_reset("local Ember is not controllable")
        return
    end

    refresh_abilities(hero, time)
    -- Keep the world-space selector attached while the committed R -> D
    -- transaction temporarily freezes ordinary cursor selection.
    if valid_target(hero, S.target) then sync_highlight() end
    if S.control_mode == "COMBO" then
        if try_auto_sleight_chains(hero, time) then
            set_status("HERO DEMO - AUTO CHAINS DURING SLEIGHT")
            return
        end
        if S.sleight_chain and sleight_in_progress(hero) then
            -- Status only. Returning here stalled every attack and move for the
            -- rest of the Sleight window while the chain merely waited for its
            -- proximity frame, which read in game as the script dropping all
            -- commands. The chain is re-evaluated first on every tick anyway.
            set_status("HERO DEMO - WAITING FOR SELECTED SLEIGHT FRAME")
        end
    end
    -- Once the opening Remnant order exists, freeze the selector transaction
    -- until D finishes or the hold/map safety gates reset it. Cursor movement,
    -- target switching, and a target dying cannot strand a confirmed Remnant.
    if S.tx and S.tx.kind == "REMNANT" then
        local dancing_transaction = S.tx.dance == true
        if update_remnant_transaction(hero, time) then
            set_status(dancing_transaction
                and "HERO DEMO - DANCING EMBER"
                or "HERO DEMO - committed Remnant -> D")
            return
        end
    end
    if S.preload and try_preload_dash(hero, time) then
        set_status("HERO DEMO - DASHING TO PRELOADED REMNANT")
        return
    end
    if S.sleight_handoff then
        if try_sleight_kill_handoff(hero, time) then
            set_status("HERO DEMO - SLEIGHT REMNANT TO NEXT TARGET")
            return
        end
        if not hero_can_act(hero) then
            set_status("HERO DEMO - SLEIGHT NEXT-TARGET HANDOFF")
            return
        end
    end

    local cursor = safe(function() return Input.GetWorldCursorPos() end, nil)
    if not cursor then
        clear_target()
        set_fsm(FSM.ACQUIRE, time)
        log_decision("ACQUIRE: cursor unavailable")
        return
    end

    update_target_lock(hero, cursor, time)
    sync_highlight()
    if S.control_mode == "DANCE" then
        if not dancing_ember_enabled(hero) then
            S.action = "DANCING EMBER - REQUIRE SCEPTER + R + D"
            log_decision("DANCING EMBER: requires Scepter, R enabled, and D enabled")
            set_status("DANCE REQUIRES SCEPTER + R + D")
            return
        end
        -- The chain is owned by the feed loop once D's travel is confirmed, and
        -- the transaction is deliberately retired at that moment. The old
        -- auto-clear here ("no transaction means re-arm D") is exactly what
        -- caused D to be re-cast every couple of hops, so the latch is now
        -- cleared only by dance.feed_chain when the chain genuinely ends.
        -- Watchdog: a dance that stops making progress while the key is still
        -- held must restart itself rather than sit there. Any dash, feed, or D
        -- counts as progress, so this only fires on a genuine stall.
        S.dance_last_progress_at = S.dance_last_progress_at or time
        if S.tx or S.dance_d_used then
            if time - S.dance_last_progress_at >= 2.0 then
                S.tx = nil
                S.dance_d_used = false
                S.dance_visited_indices = {}
                S.dance_last_fed_index = -1
                S.dance_last_anchor = nil
                S.dance_chain_idle_since = nil
                S.dance_idle_pos = nil
                S.dance_last_move_at = nil
                S.dance_last_progress_at = time
                log_decision("DANCING EMBER: stalled for 2s; restarting the chain from scratch")
            end
        else
            S.dance_last_progress_at = time
        end
        if dance.feed_chain(hero, cursor, time) then
            S.action = "DANCING EMBER - FEEDING CHAIN"
            set_status("HERO DEMO - DANCING EMBER")
            return
        end
        local issued = try_dancing_ember(hero, cursor, time)
        if issued then S.dance_last_progress_at = time end
        if not issued then
            if S.dance_d_used then
                S.action = "DANCING EMBER - FINISHING CURRENT ONE-D CHAIN"
                log_decision("DANCING EMBER: current one-D chain is still resolving")
            elseif not dance.enemy_under_cursor(hero, cursor) then
                S.action = string.format(
                    "DANCING EMBER - NO ENEMY WITHIN %d OF CURSOR",
                    ui.dance_hover_radius:Get()
                )
                log_decision("DANCING EMBER: move cursor nearer an enemy target")
            else
                S.action = "DANCING EMBER - WAITING FOR CASTABLE R"
                log_decision("DANCING EMBER: target selected; waiting for a castable Remnant")
            end
            suppress_dance_autoattack(hero, time)
        end
        set_status("HERO DEMO - DANCING EMBER")
        -- This mode is deliberately exclusive. Never fall through to cursor
        -- movement, Phase Boots, Guard, attacks, Chains, or Sleight while the
        -- Scepter dance controller is waiting for another R/D bounce.
        return
    end
    if not valid_target(hero, S.target) then
        clear_target()
        set_fsm(FSM.ACQUIRE, time)
        S.zone = "CURSOR"

        local hero_pos = origin(hero)
        local move_pos = ui.move_to_cursor:Get() and cursor_follow_position(hero_pos, cursor) or nil
        local issued = false
        if move_pos then
            local cursor_ctx = {
                time = time,
                hero = hero,
                player = S.player,
                target = nil,
                target_index = -1,
                target_epoch = S.target_epoch,
                hold_epoch = S.hold_epoch,
                map_epoch = S.map_epoch,
                hero_pos = hero_pos,
            }
            local actions = new_actions()
            propose(actions, "MOVE_CURSOR", 500, 0.95, 0, {
                position = move_pos,
                label = "FOLLOW MOUSE",
                reason = "ACQUIRE: follow mouse until a target is locked",
            })
            for _, action in ipairs(rank_actions(actions)) do
                if execute_action(cursor_ctx, action) then
                    issued = true
                    break
                end
            end
        end
        if not issued then
            S.action = move_pos and "CURSOR MOVE THROTTLED" or "WAIT FOR TARGET"
            log_decision(move_pos and "ACQUIRE: cursor movement pacing"
                or "ACQUIRE: no valid enemy near cursor")
        end
        return
    end

    sample_target_history(hero, S.target, time)
    scan_owned_remnants(hero, time, false)
    local ctx = build_context(hero, S.target, time)
    if not ctx then
        clear_target()
        return
    end

    update_attack_contact(ctx)

    S.sleight_role = "SAVED FOR LETHAL FINISH"
    update_kill_estimate(hero, S.target, ctx.ranges)
    local actions = new_actions()
    if S.tx then
        plan_transaction(ctx, actions)
    else
        evaluate_state(ctx)
        plan_state(ctx, actions)
    end

    local issued = false
    for _, action in ipairs(rank_actions(actions)) do
        if execute_action(ctx, action) then
            issued = true
            break
        end
    end
    if not issued and not S.tx then
        S.action = "HOLD / PRESERVE"
    end
end

-- --------------------------------------------------------------------------
-- Visuals
-- --------------------------------------------------------------------------

local function draw_target_selector_fallback(hero)
    if not ui.highlight:Get() or not valid_target(hero, S.target) then return end
    local target_pos = origin(S.target)
    if not target_pos then return end
    local ok, screen, visible = pcall(
        Render.WorldToScreen,
        add(target_pos, vec(0, 0, 12))
    )
    if not ok or not screen or visible == false then return end
    -- Static and intentionally light: this guarantees visible ownership if a
    -- Dota build silently suppresses the underlying Umbrella particle asset.
    Render.Circle(screen, 19, Color(255, 105, 105, 150), 2)
    Render.FilledCircle(screen, 3, Color(255, 125, 125, 190))
end

local function selected_line_path()
    local index = safe(function() return ui.target_line_style:Get() end, 0)
    local entry = TARGET_LINE_STYLE[(index or 0) + 1] or TARGET_LINE_STYLE[1]
    return entry.path
end

local function destroy_target_line()
    if S.line_particle ~= nil then
        safe(function() Particle.Destroy(S.line_particle) end, nil)
        S.line_particle = nil
    end
    S.line_particle_path = nil
    S.line_target_index = -1
end

-- World-space beam: control point 0 is the source and 1 the destination for
-- every link-style particle here, refreshed each frame so the beam tracks both
-- Ember and the target as they move.
local function sync_target_line_particle(hero)
    local path = selected_line_path()
    if not ui.target_line:Get() or not path or not valid_target(hero, S.target) then
        destroy_target_line()
        return
    end
    local hero_pos, target_pos = origin(hero), origin(S.target)
    if not hero_pos or not target_pos then
        destroy_target_line()
        return
    end
    if S.line_particle == nil
        or S.line_particle_path ~= path
        or S.line_target_index ~= S.target_index then
        destroy_target_line()
        local beam = safe(function()
            return Particle.Create(
                path,
                Enum.ParticleAttachment.PATTACH_ABSORIGIN_FOLLOW,
                hero
            )
        end, nil)
        if beam == nil then return end
        S.line_particle = beam
        S.line_particle_path = path
        S.line_target_index = S.target_index
    end
    safe(function() Particle.SetControlPoint(S.line_particle, 0, hero_pos) end, nil)
    safe(function() Particle.SetControlPoint(S.line_particle, 1, target_pos) end, nil)
    safe(function() Particle.SetControlPoint(S.line_particle, 2, target_pos) end, nil)
end

-- Project the chain forward by replaying the real selector: each hop is fed
-- back in as the next anchor with the hero marked visited, exactly as the feed
-- loop does it. Driving the preview off the same function is the point -- a
-- preview with its own logic would drift from what the script actually flies
-- and would be worse than none at all.
function dance.project_route(hero, max_hops)
    local route = {}
    if not dancing_ember_enabled(hero) then return route end
    local anchor = S.dance_last_anchor or origin(hero)
    if not anchor then return route end

    -- Copy the visited set so projecting never mutates live chain state.
    local visited = {}
    for index, seen in pairs(S.dance_visited_indices or {}) do visited[index] = seen end
    local previous = S.dance_last_fed_index or -1

    for _ = 1, (max_hops or 5) do
        local target = dance.chain_target(hero, anchor, previous, visited)
        if not target then break end
        local position = origin(target)
        if not position then break end
        -- Draw where the Remnant would actually be aimed, prediction included.
        local aim = motion.intercept(hero, target, anchor, S.abilities.remnant) or position
        route[#route + 1] = { target = target, position = position, aim = aim }
        local index = entity_index(target)
        if index >= 0 then visited[index] = true end
        previous = index
        anchor = aim
    end
    return route
end

local function draw_dance_route(hero)
    if not ui.draw_route:Get() then return end
    if not bind_is_down(ui.dance_combo) then return end
    local route = dance.project_route(hero, 5)
    if #route == 0 then return end

    local hero_pos = origin(hero)
    local ok_from, from = pcall(Render.WorldToScreen, add(hero_pos, vec(0, 0, 90)))
    if not ok_from or not from then return end

    for i, hop in ipairs(route) do
        local ok_to, to, visible = pcall(Render.WorldToScreen, add(hop.position, vec(0, 0, 110)))
        if ok_to and to and visible ~= false then
            -- Fade later hops so the immediate next one reads clearly.
            local fade = math.max(70, 255 - (i - 1) * 45)
            Render.Line(from, to, Color(255, 140, 60, fade), 2)
            Render.FilledCircle(to, 11, Color(20, 20, 20, 200))
            Render.Circle(to, 11, Color(255, 170, 90, fade), 2)
            Render.Text(FONT, 14, tostring(i), Vec2(to.x - 4, to.y - 8), Color(255, 225, 190, 255))
            from = to
        end
    end
end

-- --------------------------------------------------------------------------
-- Build advisor. Reads the enemy lineup and their real inventories, then says
-- what Ember should buy and why. Purely advisory -- it never buys, never
-- changes a setting, and never issues an order. Everything hangs off one table
-- to stay clear of Lua's 200-local ceiling.
-- --------------------------------------------------------------------------
local advisor = {}

-- Hero traits that matter to an Ember specifically. Only heroes whose presence
-- actually changes the build are listed; anything unlisted contributes nothing
-- rather than guessing.
advisor.TRAITS = {
    npc_dota_hero_naga_siren = "illusion",
    npc_dota_hero_terrorblade = "illusion",
    npc_dota_hero_phantom_lancer = "illusion",
    npc_dota_hero_chaos_knight = "illusion",
    npc_dota_hero_meepo = "illusion",
    npc_dota_hero_silencer = "silence",
    npc_dota_hero_skywrath_mage = "silence",
    npc_dota_hero_death_prophet = "silence",
    npc_dota_hero_riki = "silence",
    npc_dota_hero_disruptor = "silence",
    npc_dota_hero_lion = "burst",
    npc_dota_hero_lina = "burst",
    npc_dota_hero_zuus = "burst",
    npc_dota_hero_tinker = "burst",
    npc_dota_hero_pugna = "burst",
    npc_dota_hero_leshrac = "burst",
    npc_dota_hero_sven = "physical",
    npc_dota_hero_juggernaut = "physical",
    npc_dota_hero_phantom_assassin = "physical",
    npc_dota_hero_troll_warlord = "physical",
    npc_dota_hero_ursa = "physical",
    npc_dota_hero_life_stealer = "immune",
    npc_dota_hero_omniknight = "immune",
}

-- Enemy items worth reacting to, and the trait each one implies.
advisor.ITEM_TRAITS = {
    item_black_king_bar = "immune",
    item_blade_mail = "blademail",
    item_lotus_orb = "reflect",
    item_manta = "illusion",
    item_assault = "armor",
    item_shivas_guard = "armor",
    item_crimson_guard = "armor",
    item_pipe = "resist",
    item_hood_of_defiance = "resist",
    item_orchid = "silence",
    item_bloodthorn = "silence",
}

function advisor.scan(hero, time)
    if time - (S.advice_at or -100) < 2.0 then return end
    S.advice_at = time
    local team = safe(function() return Entity.GetTeamNum(hero) end, nil)
    local traits, seen_items = {}, {}
    local enemy_count = 0

    for _, enemy in pairs(safe(function() return Heroes.GetAll() end, {})) do
        if entity_alive(enemy)
            and not safe(function() return Entity.IsSameTeam(hero, enemy) end, true)
            and not safe(function() return NPC.IsIllusion(enemy) end, false) then
            enemy_count = enemy_count + 1
            local name = safe(function() return NPC.GetUnitName(enemy) end, "")
            local trait = advisor.TRAITS[name]
            if trait then traits[trait] = (traits[trait] or 0) + 1 end
            -- Real inventory, not a guess from the pick. Fogged heroes simply
            -- return nothing, so this reports only what has been seen.
            for slot = 0, 5 do
                local item = safe(function() return NPC.GetItemByIndex(enemy, slot) end, nil)
                if item then
                    local item_name = safe(function() return Ability.GetName(item) end, "")
                    local item_trait = advisor.ITEM_TRAITS[item_name]
                    if item_trait then
                        traits[item_trait] = (traits[item_trait] or 0) + 1
                        seen_items[item_name] = (seen_items[item_name] or 0) + 1
                    end
                end
            end
        end
    end

    -- Game stage. The same threat wants a different answer depending on what
    -- you can actually afford: an early Blade Mail is a "do not dive" note, a
    -- late one is a "buy Satanic" instruction.
    local minutes = math.max(0, safe(function() return GameRules.GetDOTATime(false, false) end, 0) / 60)
    local stage = "EARLY"
    if minutes >= 35 then stage = "LATE"
    elseif minutes >= 15 then stage = "MID" end
    if not safe(function() return ui.advisor_stage:Get() end, true) then stage = "MID" end
    S.advice_stage = stage
    S.advice_minutes = minutes

    local advice = {}
    local function suggest(item, reason)
        if #advice < 5 then advice[#advice + 1] = { item = item, reason = reason } end
    end
    -- Pick the phrasing that matches what is affordable now.
    local function staged(early, mid, late)
        if stage == "EARLY" then return early end
        if stage == "LATE" then return late end
        return mid
    end

    if (traits.immune or 0) > 0 then
        suggest(staged("Maelstrom", "Maelstrom into Mjollnir", "Daedalus / Battle Fury"),
            string.format("%d spell immunity: Chains and Guard get blanked, right clicks do not",
                traits.immune))
    end
    if (traits.illusion or 0) > 0 then
        suggest(staged("Maelstrom", "Shiva's Guard", "Mjollnir / Radiance"),
            string.format("%d illusion source: AoE clears them, single target does not",
                traits.illusion))
    end
    if (traits.silence or 0) > 0 then
        suggest(staged("Wind Lace / boots", "Black King Bar", "BKB / Manta dispel"),
            string.format("%d silence: a silenced Ember cannot Remnant out",
                traits.silence))
    end
    if (traits.burst or 0) > 0 then
        suggest(staged("Cloak / Wind Lace", "Black King Bar", "BKB / Pipe"),
            string.format("%d magic burst hero: you die before the combo finishes",
                traits.burst))
    end
    if (traits.blademail or 0) > 0 then
        suggest(staged("Do not dive it", "Wait out Blade Mail", "Satanic"),
            string.format("%d Blade Mail: the full combo into it kills you, not them",
                traits.blademail))
    end
    if (traits.armor or 0) > 0 then
        suggest(staged("Orb of Corrosion", "Desolator", "Desolator / Solar Crest"),
            string.format("%d armor item: your physical damage is being blunted",
                traits.armor))
    end
    if (traits.resist or 0) > 0 then
        suggest(staged("Farm, do not force", "Physical build over magic", "Daedalus / Deso"),
            string.format("%d magic resist item: Chains and Flame Guard damage is halved",
                traits.resist))
    end
    if (traits.reflect or 0) > 0 then
        suggest("Careful with targeted items", string.format(
            "%d Lotus Orb: Orchid and Atos get reflected back onto you",
            traits.reflect))
    end
    if (traits.physical or 0) > 0 then
        suggest(staged("Ring of Health", "Blade Mail", "Blade Mail / Crimson Guard"),
            string.format("%d physical carry: you are the one being dived",
                traits.physical))
    end
    if #advice == 0 and enemy_count > 0 then
        suggest(staged("Bottle / Boots / Falcon Blade", "Maelstrom into Scepter", "Scepter / Refresher"),
            "nothing in this lineup demands a specific answer yet")
    end

    S.advice = advice
end

local function draw_advisor()
    if not ui.draw_advisor:Get() then return end
    local advice = S.advice
    if not advice or #advice == 0 then return end
    -- Position and opacity are sliders rather than fixed: this panel is large
    -- and everyone's HUD clutter sits somewhere different.
    local x = ui.advisor_x:Get()
    local y = ui.advisor_y:Get()
    local alpha = ui.advisor_alpha:Get()
    local shadow = math.floor(alpha * 0.85)

    local header = string.format(
        "BUILD ADVISOR  [%s %d:%02d]",
        S.advice_stage or "MID",
        math.floor(S.advice_minutes or 0),
        math.floor(((S.advice_minutes or 0) % 1) * 60)
    )
    Render.Text(FONT, 14, header, Vec2(x + 1, y + 1), Color(0, 0, 0, shadow))
    Render.Text(FONT, 14, header, Vec2(x, y), Color(120, 220, 255, alpha))
    for i, entry in ipairs(advice) do
        local line_y = y + i * 18
        local text = entry.item .. "  -  " .. entry.reason
        Render.Text(FONT, 13, text, Vec2(x + 1, line_y + 1), Color(0, 0, 0, shadow))
        Render.Text(FONT, 13, text, Vec2(x, line_y), Color(225, 235, 245, alpha))
    end
end

local function draw_target_line(hero)
    if not ui.target_line:Get() or not valid_target(hero, S.target) then return end
    -- Only the flat screen style is drawn here; every other style is a real
    -- particle handled by sync_target_line_particle.
    if selected_line_path() ~= nil then return end
    local hero_pos, target_pos = origin(hero), origin(S.target)
    if not hero_pos or not target_pos then return end

    -- Screen space rather than a world particle: Render.Line always draws,
    -- while a .vpcf line silently no-ops on any build that does not ship the
    -- asset. Both endpoints are lifted slightly so the line meets the models
    -- instead of disappearing into the ground mesh.
    local ok_a, from, from_visible = pcall(Render.WorldToScreen, add(hero_pos, vec(0, 0, 90)))
    local ok_b, to, to_visible = pcall(Render.WorldToScreen, add(target_pos, vec(0, 0, 90)))
    if not ok_a or not ok_b or not from or not to then return end
    if from_visible == false or to_visible == false then return end

    local color = safe(function() return ui.target_line_color:Get() end, nil)
        or Color(255, 105, 105, 220)
    local thickness = safe(function() return ui.target_line_width:Get() end, 2)
    Render.Line(from, to, color, thickness)
end

-- --------------------------------------------------------------------------
-- Manual demo recorder: replays what the player did, for combos that are
-- easier to demonstrate by hand than to describe.
-- --------------------------------------------------------------------------

-- Grouped into one table on purpose: Lua caps a function at 200 locals and this
-- chunk sits close to that ceiling, so new top-level `local function`s are what
-- broke the load. Fields on one local cost nothing against the limit.
local demo = {}

function demo.write(message)
    Log.Write("[Ember Demo] " .. message)
end

function demo.clock()
    if not S.demo_started_at then return 0 end
    return now() - S.demo_started_at
end

function demo.order_name(value)
    if not S.demo_order_names then
        local names = {}
        for name, enum_value in pairs(safe(function() return Enum.UnitOrder end, {}) or {}) do
            names[enum_value] = name
        end
        S.demo_order_names = names
    end
    return S.demo_order_names[value] or ("ORDER_" .. tostring(value))
end

function demo.vec(position)
    if not position then return "nil" end
    return string.format("%.0f,%.0f", position.x or 0, position.y or 0)
end

function demo.record_order(data)
    if not ui.record_demo:Get() or not S.demo_started_at then return end
    local hero = S.hero
    local hero_pos = hero and origin(hero) or nil
    local ability_name = data.ability
        and safe(function() return Ability.GetName(data.ability) end, "?") or "-"
    local target_name = data.target
        and safe(function() return NPC.GetUnitName(data.target) end, "?") or "-"
    local target_pos = data.target and origin(data.target) or nil
    local reach = (hero_pos and (target_pos or data.position))
        and distance2d(hero_pos, target_pos or data.position) or -1
    demo.write(string.format(
        "t=%.3f ORDER %s ability=%s target=%s pos=%s hero=%s reach=%.0f charges=%d remnants=%d",
        demo.clock(),
        demo.order_name(data.order),
        ability_name,
        target_name,
        demo.vec(data.position),
        demo.vec(hero_pos),
        reach,
        safe(function() return Ability.GetCurrentCharges(S.abilities.remnant) end, -1),
        remnant_count()
    ))
end

function demo.sample(hero)
    local recording = ui.record_demo:Get()
    if not recording then
        if S.demo_started_at then
            demo.write(string.format("t=%.3f ---- RECORDING STOPPED ----", demo.clock()))
            S.demo_started_at = nil
            S.demo_last_pos = nil
        end
        return
    end
    local time = now()
    if not S.demo_started_at then
        S.demo_started_at = time
        S.demo_last_sample = 0
        S.demo_last_pos = origin(hero)
        S.demo_last_charges = -1
        S.demo_last_remnants = -1
        demo.write("---- RECORDING STARTED ---- perform the combo by hand now")
    end
    if time - S.demo_last_sample < 0.05 then return end
    S.demo_last_sample = time

    scan_owned_remnants(hero, time, true)
    local hero_pos = origin(hero)
    local charges = safe(function()
        return Ability.GetCurrentCharges(S.abilities.remnant)
    end, -1)
    local remnants = remnant_count()

    -- A large single-sample jump is a Remnant dash, which never appears as an
    -- order; this is what reconstructs the actual bounce path.
    if hero_pos and S.demo_last_pos then
        local jump = distance2d(hero_pos, S.demo_last_pos)
        if jump >= 250 then
            demo.write(string.format(
                "t=%.3f DASH %s -> %s (%.0f units) charges=%d remnants=%d",
                demo.clock(), demo.vec(S.demo_last_pos), demo.vec(hero_pos),
                jump, charges, remnants
            ))
        end
    end
    if charges ~= S.demo_last_charges and S.demo_last_charges >= 0 then
        demo.write(string.format(
            "t=%.3f CHARGES %d -> %d (remnants on map: %d)",
            demo.clock(), S.demo_last_charges, charges, remnants
        ))
    end
    if remnants ~= S.demo_last_remnants and S.demo_last_remnants >= 0 then
        demo.write(string.format(
            "t=%.3f REMNANTS %d -> %d at hero=%s",
            demo.clock(), S.demo_last_remnants, remnants, demo.vec(hero_pos)
        ))
    end
    S.demo_last_pos = hero_pos
    S.demo_last_charges = charges
    S.demo_last_remnants = remnants
end

local function draw_hud(hero)
    if not ui.draw_hud:Get() then return end
    local gate_color = S.gate_allowed and Color(100, 255, 135, 255) or Color(255, 95, 80, 255)
    local target_name = S.target and safe(function() return NPC.GetUnitName(S.target) end, "NONE") or "NONE"
    local remnant_charges = S.abilities.remnant
        and safe(function() return Ability.GetCurrentCharges(S.abilities.remnant) end, 0) or 0
    local tx = S.tx and (S.tx.kind .. "/" .. S.tx.phase) or "NONE"
    local lines = {
        "EMBER STICKY TRAINER " .. BUILD,
        "Gate: " .. S.gate_reason,
        "Target: " .. target_name,
        "Target mode: " .. (selected_target_mode() == 1 and "LOCK" or "FREE"),
    }
    if ui.draw_state:Get() then
        lines[#lines + 1] = "State: " .. S.fsm .. " | Zone: " .. S.zone
        lines[#lines + 1] = "Combo: " .. S.combo_stage
        lines[#lines + 1] = "Flame Guard: " .. (flame_guard_active(hero) and "ACTIVE" or "INACTIVE")
        lines[#lines + 1] = string.format(
            "Opening right clicks: %d/2",
            math.min(2, S.post_guard_attack_orders)
        )
        lines[#lines + 1] = string.format(
            "Orbwalk: %s | Next attack: %.2fs",
            ui.orbwalk:Get() and "ON" or "OFF",
            math.max(0, S.next_attack - now())
        )
        lines[#lines + 1] = "Sleight role: " .. S.sleight_role
    end
    if ui.draw_escape:Get() then
        lines[#lines + 1] = string.format(
            "Escape: %.0f%% | Latched: %s",
            S.escape_score * 100,
            S.escape_latched and "YES" or "NO"
        )
        lines[#lines + 1] = string.format(
            "Distance gain: %s | %.0f u/s",
            S.distance_gain_latched and "YES" or "NO",
            S.distance_slope
        )
    end
    if ui.draw_action:Get() then
        lines[#lines + 1] = "Action: " .. S.action
        lines[#lines + 1] = "Decision: " .. S.reason
    end
    if ui.draw_kill:Get() then lines[#lines + 1] = "Kill: " .. S.kill_estimate end
    lines[#lines + 1] = string.format(
        "Remnants: %d | Reserve: %d | Active: %d",
        remnant_charges,
        ui.reserve_remnants:Get(),
        remnant_count()
    )
    lines[#lines + 1] = "Transaction: " .. tx
    -- Modelled vs measured Remnant speed. A large gap here is the prediction
    -- error: the model is what the intercept was solved with, the measurement
    -- is what the Remnant actually did.
    do
        local profile = S.abilities.remnant
            and remnant_travel_profile(hero, nil) or nil
        local modelled = profile and profile.modelled_placement_speed or 0
        lines[#lines + 1] = string.format(
            "Remnant speed: %.0f measured / %.0f modelled",
            S.measured_remnant_speed or 0,
            modelled
        )
        lines[#lines + 1] = string.format(
            "Cast point: %.3f measured / %.3f modelled",
            S.measured_cast_point or 0,
            profile and profile.placement_cast_point or 0
        )
    end

    -- "Ember just stands there" was the shape of nearly every bug in this
    -- script, and diagnosing it always meant reading debug.log. If a key is
    -- held and no order has gone out for a moment, say why on screen instead.
    -- Always shown, independent of the HUD detail switches.
    local idle_line = nil
    local holding = bind_is_down(ui.combo)
        or bind_is_down(ui.dance_combo)
        or bind_is_down(ui.escape_key)
    if holding and now() - (S.last_action or -100) > 0.5 then
        idle_line = "IDLE: " .. (S.reason or "no decision recorded")
    end

    local x, y = 35, 330
    for i, line in ipairs(lines) do
        local color = i == 2 and gate_color or Color(235, 235, 235, 255)
        Render.Text(FONT, 14, line, Vec2(x + 1, y + (i - 1) * 18 + 1), Color(0, 0, 0, 220))
        Render.Text(FONT, 14, line, Vec2(x, y + (i - 1) * 18), color)
    end
    if idle_line then
        local idle_y = y + #lines * 18 + 4
        Render.Text(FONT, 14, idle_line, Vec2(x + 1, idle_y + 1), Color(0, 0, 0, 220))
        Render.Text(FONT, 14, idle_line, Vec2(x, idle_y), Color(255, 190, 80, 255))
    end
end

function script.OnDraw()
    if not safe(function() return Engine.IsInGame() end, false) then return end
    local hero = get_local_ember()
    if not hero then return end
    -- Sample owned Remnants continuously. The combo paths only scan while a
    -- transaction is live, and a landed Remnant never moves, so the in-flight
    -- speed measurement had nothing to work with -- it read 0 even with three
    -- Remnants sitting on the map. 20Hz is enough to catch several samples
    -- across a flight that lasts well under a second.
    local sample_now = now()
    if sample_now - (S.remnant_sample_at or 0) >= 0.05 then
        S.remnant_sample_at = sample_now
        scan_owned_remnants(hero, sample_now, true)
    end
    demo.sample(hero)
    -- Sampled here so every reachable enemy has a velocity estimate ready the
    -- moment a chain hop needs one, regardless of which planner branch runs.
    motion.sample(hero, now())
    advisor.scan(hero, now())
    draw_advisor()
    sync_target_line_particle(hero)
    draw_target_line(hero)
    draw_dance_route(hero)
    draw_target_selector_fallback(hero)
    draw_hud(hero)
end

local function track_created_remnant(entity)
    if not entity or not S.hero then return end
    local name = safe(function() return NPC.GetUnitName(entity) end, "")
    if name ~= REMNANT_UNIT_NAME then return end
    if not safe(function() return Entity.RecursiveOwnedBy(entity, S.hero) end, false) then return end
    local index, position = entity_index(entity), origin(entity)
    if index >= 0 and position then
        S.remnants[index] = {
            entity = entity,
            index = index,
            position = position,
            sampled_at = now(),
        }
        -- Time from the order going out to the Remnant existing: the real cast
        -- point, whatever the ability reports.
        if S.last_remnant_order_at then
            local delay = now() - S.last_remnant_order_at
            if delay > 0.01 and delay < 1.0 then
                S.measured_cast_point = S.measured_cast_point
                    and (S.measured_cast_point * 0.6 + delay * 0.4)
                    or delay
            end
            S.last_remnant_order_at = nil
        end
    end
end

function script.OnPrepareUnitOrders(data)
    if data
        and data.ability
        and data.npc
        and S.abilities.sleight
        and same_entity(data.npc, S.hero)
        and safe(function() return Ability.GetName(data.ability) end, "") == ABILITY_NAME.sleight then
        S.last_sleight_order_at = now()
    end
    if data and data.npc and same_entity(data.npc, S.hero) then
        safe(function() demo.record_order(data) end, nil)
    end
    return true
end

function script.OnEntityCreate(entity)
    track_created_remnant(entity)
end

function script.OnNpcSpawned(npc)
    track_created_remnant(npc)
end

function script.OnEntityDestroy(entity)
    local index = entity_index(entity)
    if index >= 0 then S.remnants[index] = nil end
    if index >= 0 and index == S.target_index then clear_target() end
end

function script.OnGameEnd()
    hard_reset("game ended")
    reset_session_cache()
    S.last_map = ""
    S.gate_checked_at = -100
    S.kill_estimate = "not evaluated"
    S.sleight_role = "SAVED"
    set_status("game ended")
end

Log.Write("[Ember Sticky UNLOCKED] build " .. BUILD .. " loaded - all modes enabled")
return script
