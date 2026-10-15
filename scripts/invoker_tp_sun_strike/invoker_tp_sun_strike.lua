local script = {}
local DEBUG = false

local Menu, Render, Input, Enum   = Menu, Render, Input, Enum
local Heroes, NPC, Ability        = Heroes, NPC, Ability
local Modifier, Entity, GameRules = Modifier, Entity, GameRules
local Color, Vec2                 = Color, Vec2
local remove                      = table.remove
local floor                       = math.floor
local fmt                         = string.format
local pcall                       = pcall
local type                        = type

local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if ok then return a, b, c end
    return nil
end

local MOUSE1 = (Enum and Enum.ButtonCode and Enum.ButtonCode.KEY_MOUSE1) or nil
local KEY_T  = (Enum and Enum.ButtonCode and Enum.ButtonCode.KEY_T) or nil

local SUN_STRIKE   = "invoker_sun_strike"
local EXORT        = "invoker_exort"
local INVOKE       = "invoker_invoke"
local INVOKER_NAME = "npc_dota_hero_invoker"
local TP_MOD       = "modifier_teleporting"
local TP_END_PRT   = "teleport_end"

local DEFAULT_DELAY    = 1.7
local SS_MANA_FALLBACK = 175
local DEST_IMPACT_LAG  = 0.08 -- validated: destination impact ~80ms AFTER TP completion
local DEST_MAX_LATE    = 0.35 -- runtime-tuned: tolerate scheduling jitter through ~350ms; still blocks stale 800ms+ retries
local START_MARGIN     = 0.35
local INVOKE_GAP       = 0.05
local SCAN_INTERVAL    = 1.0
local DEST_TTL         = 2.5
local LOOSE_WINDOW     = 0.7
local MANUAL_TTL       = 3.0
local TP_CHANNEL       = 3.0
local TRACK_TTL        = 2.0
local OWNER_TTL        = 6.5 -- keep teleport particle ownership through observed 5s channels + safety
local MAX_LOOSE        = 16
local HP_TRUST_TTL     = 3.5
local EXORT_BASE_DMG   = 100
local EXORT_DMG_STEP   = 62.5

-- Boots-to-creep motion prediction. Bundled into one table intentionally:
-- this script is already close to Lua's per-function local-variable ceiling.
-- Keeping prediction state/config/methods on one table avoids making the chunk
-- fail to parse before build_menu() runs. Values below are controller heuristics.
local CreepPred = {
    NPCs = NPCs,
    MATCH_MAX_DIST = 220.0,
    AMBIG_MARGIN = 40.0,
    SAMPLE_MIN_DT = 0.06,
    MAX_SPEED = 600.0,
    MIN_SPEED = 15.0,
    TRACK_TTL = 6.5,
    ENABLED = true,
    SCALE = 1.00,
    track = {},
}
print("[TPI][BOOT] version=1.8.5-moving-creep-projection-fix vector_projection=true")

local ui = {}
local ui_ready = false
local g_filt = nil

local FONT_BASES  = { "Georgia", "Radiance", "Times New Roman", "Courier New", "Tahoma", "Verdana", "Trebuchet MS", "Impact", "Consolas", "Comic Sans MS" }
local FONT_LABELS = { "Georgia", "Radiance", "Times New Roman", "Courier New", "Tahoma", "Verdana", "Trebuchet", "Impact", "Consolas", "Comic Sans" }

local function build_menu()
    if type(Menu) ~= "table" or type(Menu.Create) ~= "function" then
        return false
    end
    local ok = pcall(function()
        local tab    = Menu.Create("Heroes", "Hero List", "Invoker")
        local g_main = tab:Create("TP Sun Strike"):Create("Core")
        g_filt       = tab:Create("TP Filter"):Create("Enemies")
        local sec_ui = tab:Create("TP Interface")
        local g_ui   = sec_ui:Create("Panel")
        local g_look = sec_ui:Create("Appearance")
        local g_fx   = sec_ui:Create("Glow & Effects")
        local g_world = sec_ui:Create("World Markers")

        ui.enabled = g_main:Switch("Enable Script", false)
        ui.invoke  = g_main:Switch("Auto Invoke Sun Strike", true)
        ui.fire_on = g_main:Switch("Allow Sun Strike Cast", true)
        ui.lethal  = g_main:Switch("Cast Only If Lethal", false)
        ui.lethal_vis = g_main:Switch("Lethal Check Visible Targets Only", true)
        ui.fog     = g_main:Switch("Cast Into Fog of War", true)
        ui.start_point = g_main:Switch("Cast at TP Start (During Channel)", false)
        ui.aim_smart   = g_main:Switch("Smart TP Aim", true)
        ui.avoid_creep_split = g_main:Switch("Avoid Split Damage on Creep TP", true)
        ui.delay   = g_main:Slider("Cast Delay (ms)", 0, 1000, 0, "%d ms")
        ui.hp_pct_on = g_main:Switch("Cast Only Below HP Threshold", false)
        ui.hp_pct    = g_main:Slider("Target HP Threshold", 5, 100, 60, "%d%%")
        ui.debug     = g_main:Switch("Debug Logs", true)
        if KEY_T then
            local ok_bind, bind = pcall(function()
                return g_main:Bind("Sun Strike at Cursor", KEY_T)
            end)
            ui.manual = ok_bind and bind or nil
        end

        ui.draw        = g_ui:Switch("Show Panel", true)
        ui.panel_w     = g_ui:Slider("Panel Width", 280, 600, 380, "%d px")
        ui.scale       = g_ui:Slider("Panel Scale", 70, 160, 100, "%d%%")
        ui.text_scale  = g_ui:Slider("UI Text Scale", 70, 200, 100, "%d%%")
        ui.density     = g_ui:Slider("UI Density (Spacing)", 70, 170, 100, "%d%%")
        ui.show_mana   = g_ui:Switch("Show Mana", true)
        ui.show_filter = g_ui:Switch("Show Enemy Filter in Panel", true)
        ui.filter_gap  = g_ui:Slider("Filter Row Spacing", 16, 44, 24, "%d px")

        ui.pos_x       = g_ui:Slider("Panel Position X", 0, 3840, 40, "%d px")
        ui.pos_y       = g_ui:Slider("Panel Position Y", 0, 2160, 150, "%d px")

        ui.use_theme     = g_look:Switch("Use Umbrella Theme Colors", true)
        ui.accent        = g_look:ColorPicker("Accent Color (Manual)", Color(255, 220, 110))
        ui.accent_bright = g_look:Slider("Accent Brightness", -60, 60, 0, "%d")
        ui.bg_alpha      = g_look:Slider("Background Opacity", 0, 255, 235, "%d")
        ui.opacity       = g_look:Slider("Overall Opacity", 10, 100, 100, "%d%%")
        ui.rounding      = g_look:Slider("Corner Rounding", 0, 30, 14, "%d")
        ui.bg_tint       = g_look:Slider("Background Accent Tint", 0, 60, 12, "%d")
        ui.border_width  = g_look:Slider("Border Width", 0, 4, 1, "%d")
        ui.shadow        = g_look:Switch("Shadow", true)
        local okfc, fcw = pcall(function() return g_look:Combo("UI Font", FONT_LABELS, 0) end)
        if okfc and fcw then
            ui.font_choice = fcw
            ui.font_combo  = true
        else
            ui.font_choice = g_look:Slider("Font (1–10)", 1, 10, 1, "%d")
            ui.font_combo  = false
        end

        ui.glow        = g_fx:Switch("UI Glow", true)
        ui.glow_follow = g_fx:Switch("Use Accent for Glow", true)
        ui.glow_color  = g_fx:ColorPicker("Glow Color (Manual)", Color(255, 200, 90, 70))
        ui.glow_alpha  = g_fx:Slider("Glow Strength", 0, 255, 70, "%d")
        ui.glow_size   = g_fx:Slider("Glow Size", 0, 60, 22, "%d")
        ui.glow_pulse  = g_fx:Switch("Pulse During Active TP", true)
        ui.flow        = g_fx:Switch("Animated Border", true)
        ui.flow_speed  = g_fx:Slider("Border Animation Speed", 1, 100, 32, "%d")
        ui.flash       = g_fx:Switch("Flash Panel on Cast", true)
        ui.title_sheen = g_fx:Switch("Title Sheen", true)
        ui.accent_line = g_fx:Switch("Animated Accent Line", true)
        ui.sparkles    = g_fx:Switch("Sparkles", true)
        ui.spark_count = g_fx:Slider("Sparkle Count", 0, 40, 18, "%d")
        ui.sheen_power = g_fx:Slider("Title Sheen Brightness", 0, 100, 60, "%d")

        ui.world_draw  = g_world:Switch("Show TP Aim Marker", true)
        ui.world_timer = g_world:Switch("Show Marker Timer", true)
        ui.world_glow  = g_world:Switch("Marker Glow", true)
        ui.world_size  = g_world:Slider("Marker Size", 12, 60, 26, "%d")
    end)
    return ok
end

local function ui_get(el, default)
    if not el or type(el.Get) ~= "function" then return default end
    local ok, v = pcall(el.Get, el)
    if ok and v ~= nil then return v end
    return default
end

local function ui_pressed(el)
    if not el or type(el.IsPressed) ~= "function" then return false end
    local ok, v = pcall(el.IsPressed, el)
    return ok and v or false
end

local function ui_set(el, v)
    if not el or type(el.Set) ~= "function" then return false end
    return pcall(el.Set, el, v) and true or false
end

local my_hero, is_invoker = nil, false
local GlobalVars = GlobalVars
local FF = (Enum and Enum.FontCreate and Enum.FontCreate.FONTFLAG_ANTIALIAS) or 0
local function load_font(name, weight)
    local h = call(Render and Render.LoadFont, name, FF, weight)
    if h then return h end
    return call(Render and Render.LoadFont, "Arial", FF, weight)
end
local font       = load_font("Georgia", 600)
local font_title = load_font("Georgia", 700)
local font_small = load_font("Georgia", 400)
local font_heavy = load_font("Georgia", 800)
local font_light = load_font("Georgia", 300)
local cur_font_idx = 1
local function apply_font(idx)
    local name = FONT_BASES[idx] or "Georgia"
    font       = load_font(name, 600)
    font_title = load_font(name, 700)
    font_small = load_font(name, 400)
    font_heavy = load_font(name, 800)
    font_light = load_font(name, 300)
end
local stats     = { fired = 0 }

local img_cache = {}
local function hero_img(name)
    if not name or not Render then return nil end
    local cached = img_cache[name]
    if cached ~= nil then return cached or nil end
    local handle = false
    local paths = {
        "panorama/images/heroes/icons/" .. name .. "_png.vtex_c",
        "panorama/images/heroes/" .. name .. "_png.vtex_c",
    }
    for i = 1, #paths do
        if type(Render.LoadImage) == "function" then
            local hh = call(Render.LoadImage, paths[i])
            if hh then
                handle = hh
                break
            end
        else
            handle = paths[i]
            break
        end
    end
    img_cache[name] = handle
    return handle or nil
end

local function draw_hero_icon(name, x, y, size, alpha)
    if type(Render.Image) ~= "function" then return false end
    local h = hero_img(name)
    if not h then return false end
    local a = alpha or 255
    return pcall(Render.Image, h, Vec2(x, y), Vec2(size, size), Color(255, 255, 255, a)) and true or false
end
local last_cast = -10

local tracked  = {}
local tp_dest  = {}
local p_owner  = {}
local loose    = {}
local enemies  = {}
local filters  = {}
local last_scan = 0
local last_time = 0
local ss_delay  = DEFAULT_DELAY
local hp_seen   = {}
local hp_val    = {}
local hp_max    = {}
local dead_seen = {}

local seq, next_step = nil, 0
local invoke_guard = 0
local manual = nil
local pending_ss = nil
local dest_ambig_logged = {}

local panel   = { x = 40, y = 150 }
local drag    = { on = false, dx = 0, dy = 0 }
local pos_loaded = false
local last_pos = { x = nil, y = nil }

local function log(tag, msg)
    local enabled = DEBUG
    if ui and ui.debug and type(ui.debug.Get) == "function" then
        local ok, v = pcall(ui.debug.Get, ui.debug)
        if ok then enabled = v and true or false end
    end
    if enabled then print(fmt("[TPI][%s] %s", tag, msg or "")) end
end

local function game_time()
    local t = call(GameRules and GameRules.GetGameTime)
    if type(t) == "number" then
        last_time = t
        return t
    end
    return last_time
end

local function is_alive(ent)
    if not ent then return false end
    local r = call(Entity and Entity.IsAlive, ent)
    return r and true or false
end

local function unit_name(ent)
    if not ent then return nil end
    local n = call(NPC and NPC.GetUnitName, ent)
    if type(n) == "string" then return n end
    return nil
end

local function ent_index(ent)
    if not ent then return nil end
    local i = call(Entity and Entity.GetIndex, ent)
    if type(i) == "number" then return i end
    return nil
end

local function team_of(ent)
    if not ent then return nil end
    local t = call(Entity and Entity.GetTeamNum, ent)
    if type(t) == "number" then return t end
    return nil
end

local function mana()
    local m = call(NPC and NPC.GetMana, my_hero)
    return (type(m) == "number" and m) or 0
end

local function ab_mana_cost(ab)
    if not ab then return 0 end
    local c = call(Ability and Ability.GetManaCost, ab)
    return (type(c) == "number" and c) or 0
end

local function ab_cd(ab)
    if not ab then return 0 end
    local v = call(Ability and Ability.GetCooldownTimeRemaining, ab)
    return (type(v) == "number" and v) or 0
end

-- RUNTIME-PROVEN elsewhere in this project (Callback Observatory / TekiTeki):
-- SecondsSinceLastUse resets near zero when the exact ability handle executes.
local function ab_since_last_use(ab)
    if not ab or not (Ability and Ability.SecondsSinceLastUse) then return nil end
    local v = call(Ability.SecondsSinceLastUse, ab)
    return (type(v) == "number") and v or nil
end

local function ab_is_ready(ab)
    if not ab or not (Ability and Ability.IsReady) then return nil end
    local v = call(Ability.IsReady, ab)
    if type(v) == "boolean" then return v end
    return nil
end

local function ab_level(ab)
    if not ab then return 0 end
    local v = call(Ability and Ability.GetLevel, ab)
    return (type(v) == "number" and v) or 0
end

local function get_ability(name)
    if not my_hero then return nil end
    return call(NPC and NPC.GetAbility, my_hero, name)
end

local function special(ab, name)
    if not ab then return nil end
    if Ability and Ability.GetSpecialValueFor then
        local v = call(Ability.GetSpecialValueFor, ab, name)
        if type(v) == "number" then return v end
    end
    if Ability and Ability.GetLevelSpecialValueFor then
        local v = call(Ability.GetLevelSpecialValueFor, ab, name, -1)
        if type(v) == "number" then return v end
    end
    return nil
end

local function can_cast(ab, m)
    if not ab then return false end

    if ab_cd(ab) > 0 then return false end
    if Ability and Ability.IsCastable then
        local ok, r = pcall(Ability.IsCastable, ab, m or 0)
        if ok then return r and true or false end
    end
    return (m or 0) >= ab_mana_cost(ab)
end

local function cast_no_target(ab)
    if not ab or not (Ability and Ability.CastNoTarget) then return false end
    local ok = pcall(Ability.CastNoTarget, ab, false, false, true)
    return ok
end

local function cast_position(ab, pos)
    if not ab or not pos or not (Ability and Ability.CastPosition) then return false end
    local ok, result = pcall(Ability.CastPosition, ab, pos)
    if not ok then return false end
    -- Runtime-proven project pattern: nil may mean submitted; explicit false means rejected.
    return result ~= false
end

local function state_id(name)
    local E = Enum and Enum.ModifierState
    if not E then return nil end
    return E[name]
end

local function unit_has_state(ent, name)
    if not ent then return false end
    local s = state_id(name)
    if s == nil or not (NPC and NPC.HasState) then return false end
    local r = call(NPC.HasState, ent, s)
    return r and true or false
end

local function cast_blocked()
    if not my_hero then return "no hero" end
    if not is_alive(my_hero) then return "dead" end
    if NPC and NPC.IsStunned  and call(NPC.IsStunned, my_hero)  then return "stunned" end
    if NPC and NPC.IsSilenced and call(NPC.IsSilenced, my_hero) then return "silenced" end
    if unit_has_state(my_hero, "MODIFIER_STATE_HEXED") then return "hexed" end
    if unit_has_state(my_hero, "MODIFIER_STATE_NIGHTMARED") then return "nightmared" end
    if unit_has_state(my_hero, "MODIFIER_STATE_FROZEN") then return "frozen" end
    if unit_has_state(my_hero, "MODIFIER_STATE_COMMAND_RESTRICTED") then return "command restricted" end
    if unit_has_state(my_hero, "MODIFIER_STATE_OUT_OF_GAME") then return "out of game" end
    return nil
end

local function get_tp_mod(ent)
    if not ent then return nil end
    if NPC and NPC.GetModifier then
        local m = call(NPC.GetModifier, ent, TP_MOD)
        if m then return m end
    end
    if NPC and NPC.GetModifiers then
        local mods = call(NPC.GetModifiers, ent)
        if type(mods) == "table" then
            for _, m in pairs(mods) do
                if call(Modifier and Modifier.GetName, m) == TP_MOD then return m end
            end
        end
    end
    return nil
end

local function mod_die_time(mod)
    local d = call(Modifier and Modifier.GetDieTime, mod)
    return (type(d) == "number" and d) or nil
end

local function is_illusion(ent)
    if not (NPC and NPC.IsIllusion) then return false end
    local r = call(NPC.IsIllusion, ent)
    return r and true or false
end

local function is_hero_name(n)
    return type(n) == "string" and n:match("^npc_dota_hero_") ~= nil
end

local function valid_enemy(ent)
    if not my_hero or not ent then return false end
    if not (Entity and Entity.IsNPC and call(Entity.IsNPC, ent)) then return false end
    if not is_alive(ent) then return false end
    if is_illusion(ent) then return false end
    local et, mt = team_of(ent), team_of(my_hero)
    if et == nil or mt == nil or et == mt then return false end
    return is_hero_name(unit_name(ent))
end

local function is_enemy_hero(ent)
    if not my_hero or not ent then return false end
    if not (Entity and Entity.IsNPC and call(Entity.IsNPC, ent)) then return false end
    if is_illusion(ent) then return false end
    local et, mt = team_of(ent), team_of(my_hero)
    if et == nil or mt == nil or et == mt then return false end
    return is_hero_name(unit_name(ent))
end

local function is_dormant(ent)
    if not ent then return false end
    if Entity and Entity.IsDormant then
        local ok, r = pcall(Entity.IsDormant, ent)
        if ok then return r and true or false end
    end
    if NPC and NPC.IsVisible then
        local ok, v = pcall(NPC.IsVisible, ent)
        if ok then return not v end
    end
    return false
end

local function disp(ent)
    local n = unit_name(ent)
    if not n then return "?" end
    return (n:gsub("npc_dota_hero_", "")):upper()
end

local function filter_on(name)
    if not name then return true end
    local f = filters[name]
    if not f then return true end
    return ui_get(f, true)
end

local function refresh_enemies()
    enemies = {}
    local all = call(Heroes and Heroes.GetAll)
    if type(all) ~= "table" then return end
    for _, ent in ipairs(all) do
        if valid_enemy(ent) then
            enemies[#enemies + 1] = ent
            local n = unit_name(ent)
            if n and not filters[n] and g_filt then
                local ipath = "panorama/images/heroes/icons/" .. n .. "_png.vtex_c"
                local ok, sw = pcall(function() return g_filt:Switch(disp(ent), true, ipath) end)
                if not ok or not sw then
                    ok, sw = pcall(function() return g_filt:Switch(disp(ent), true) end)
                end
                if ok and sw then filters[n] = sw end
            end
        end
    end
end

local function get_ss()
    return get_ability(SUN_STRIKE)
end

local function ss_slot_handle()
    if not (NPC and NPC.GetAbilityByIndex) or not (Ability and Ability.GetName) then
        return nil
    end
    for i = 3, 4 do
        local ab = call(NPC.GetAbilityByIndex, my_hero, i)
        if ab and call(Ability.GetName, ab) == SUN_STRIKE then return ab end
    end
    return nil
end

local function invoked_ss()
    if not (NPC and NPC.GetAbilityByIndex) or not (Ability and Ability.GetName) then
        local ss = get_ss()
        if ss and can_cast(ss, mana()) then return ss end
        return nil
    end
    for i = 3, 4 do
        local ab = call(NPC.GetAbilityByIndex, my_hero, i)
        if ab then
            local n = call(Ability.GetName, ab)
            if n == SUN_STRIKE then return ab end
        end
    end
    return nil
end

local function refresh_ss_delay()
    local ss = get_ss()
    if not ss then return end
    local d = special(ss, "delay")
    if d and d > 0 then ss_delay = d end
end

local function ss_ready()
    local ss = invoked_ss()
    if not ss then return nil end

    if ab_cd(ss) > 0 then return nil end
    if can_cast(ss, mana()) then return ss end
    return nil
end

local function ss_invoked_now()
    if ss_slot_handle() then return true end
    if not (NPC and NPC.GetAbilityByIndex) or not (Ability and Ability.GetName) then
        return ss_ready() ~= nil
    end
    return false
end

local function ss_travel()
    local ss = get_ss()
    local cp = 0
    if ss and Ability and Ability.GetCastPoint then
        local v = call(Ability.GetCastPoint, ss)
        if type(v) == "number" then cp = v end
    end
    return ss_delay + cp
end

local function ss_lead()
    -- Destination shots should IMPACT slightly after the teleport completes.
    -- fire_gate uses: die_time - ss_lead + user_delay.
    -- Therefore lead = travel - lag => impact ~= die_time + lag + user_delay.
    return math.max(0, ss_travel() - DEST_IMPACT_LAG)
end

local function ss_raw_damage()

    local ss = invoked_ss() or get_ss()
    local d = ss and special(ss, "damage") or nil
    if (not d or d <= 0) and ss and Ability and Ability.GetDamage then
        local gd = call(Ability.GetDamage, ss)
        if type(gd) == "number" then d = gd end
    end
    local lv = ab_level(get_ability(EXORT))
    if not lv or lv < 1 then lv = 1 end
    local by_lv = EXORT_BASE_DMG + (lv - 1) * EXORT_DMG_STEP
    if (not d or d < by_lv) then d = by_lv end
    return (d and d > 0) and d or by_lv
end

local function ss_mana_need()
    local need = ab_mana_cost(get_ss())
    if need <= 0 then need = SS_MANA_FALLBACK end
    return need
end

local function effective_hp(ent)
    if not ent then return 0 end
    local hp = 0
    local h = call(Entity and Entity.GetHealth, ent)
    if type(h) == "number" and h > 0 then hp = h end
    local b = call(NPC and NPC.GetBarriers, ent)
    if type(b) == "table" and b.magic and type(b.magic.current) == "number" then
        hp = hp + b.magic.current
    end
    return hp
end

local function hp_regen(ent)
    local r = call(NPC and NPC.GetHealthRegen, ent)
    return (type(r) == "number" and r > 0) and r or 0
end

local function enemy_immune(ent)

    if unit_has_state(ent, "MODIFIER_STATE_INVULNERABLE") then return true end
    return false
end

local function predicted_dmg(ent)

    local raw = ss_raw_damage()
    if raw <= 0 then return 0 end
    if enemy_immune(ent) then return 0 end
    return raw
end

local function max_hp(ent)
    if not ent then return 0 end
    local m = call(Entity and Entity.GetMaxHealth, ent)
    if type(m) ~= "number" or m <= 0 then
        m = call(NPC and NPC.GetMaxHealth, ent)
    end
    return (type(m) == "number" and m) or 0
end

local function hp_pct(ent)
    local mx = max_hp(ent)
    if mx <= 0 then return nil end
    local hp = effective_hp(ent)
    return (hp / mx) * 100
end

local function hp_trusted(ent, now)
    if not ent then return false end
    if not is_alive(ent) then return false end
    local idx = ent_index(ent)

    if idx then
        local ds, hs = dead_seen[idx], hp_seen[idx]
        if ds and (not hs or ds >= hs) then return false end
    end
    if not is_dormant(ent) then return true end
    if not idx then return false end
    local t = hp_seen[idx]
    return (t ~= nil) and (now - t <= HP_TRUST_TTL)
end

local function is_lethal(ent, now)
    now = now or game_time()

    if not is_alive(ent) then return false end

    if ui_get(ui.lethal_vis, true) and is_dormant(ent) then return false end

    if not hp_trusted(ent, now) then return false end
    local dmg = predicted_dmg(ent)
    if dmg <= 0 then return false end
    local hp = effective_hp(ent)
    if hp <= 0 then return false end

    local mx = max_hp(ent)
    if mx > 0 and hp >= mx then return false end

    local future_hp = hp + hp_regen(ent) * ss_travel()
    return dmg >= future_hp
end

local function drive_invoke(now)
    if cast_blocked() then return end

    if ss_invoked_now() then seq = nil; return end
    if now < invoke_guard then return end
    if not seq then
        local ex = get_ability(EXORT)
        local iv = get_ability(INVOKE)
        if not ex or not iv then return end
        if ab_level(ex) < 1 or ab_level(iv) < 1 then return end
        seq = { ex, ex, ex, iv, i = 1 }
        next_step = 0
    end
    if now < next_step then return end
    local ab = seq[seq.i]
    if not ab then seq = nil; return end
    if can_cast(ab, mana()) then
        if cast_no_target(ab) then
            seq.i = seq.i + 1
            next_step = now + INVOKE_GAP
            if seq.i > 4 then
                seq = nil
                invoke_guard = now + 0.4
            end
        else
            next_step = now + 0.05
        end
    else
        next_step = now + 0.05
    end
end

local function unresolved_tp_count(now, include_idx)
    local count = 0
    local include_seen = false

    for tidx, t in pairs(tracked) do
        if tidx == include_idx then include_seen = true end
        if t
            and not t.fired
            and not t.dest
            and t.ent
            and is_alive(t.ent)
            and now <= (t.die or now) + 0.25
        then
            count = count + 1
        end
    end

    -- resolve_dest() is also called while a brand-new tracked record is being
    -- constructed, before it has been inserted into tracked[]. Count it once.
    if include_idx ~= nil and not include_seen then
        count = count + 1
    end

    return count
end

local function resolve_dest(idx, now)
    if idx ~= nil then
        local d = tp_dest[idx]
        if d and (now - d.t) <= DEST_TTL then
            return d.dest, d.t, d.source or "particle_owner"
        end
    end

    -- Fail closed on ownerless teleport particles. The old script handed the
    -- newest loose destination to every teleporting hero in the same 0.7s
    -- window. We only use a loose destination when BOTH sides are unambiguous:
    -- exactly one unresolved TP and exactly one fresh, unused loose particle.
    local candidates = {}
    for i = 1, #loose do
        local r = loose[i]
        if not r.used_by and (now - r.t) <= LOOSE_WINDOW then
            candidates[#candidates + 1] = r
        end
    end

    local unresolved = unresolved_tp_count(now, idx)
    if idx ~= nil and unresolved == 1 and #candidates == 1 then
        local r = candidates[1]
        r.used_by = idx
        dest_ambig_logged[idx] = nil
        log("DEST_FALLBACK", fmt("idx=%s source=unique_loose particle=%s", tostring(idx), tostring(r.particle_index)))
        return r.dest, r.t, "unique_loose"
    end

    if idx ~= nil and #candidates > 0 and not dest_ambig_logged[idx] then
        dest_ambig_logged[idx] = true
        log("DEST_AMBIG", fmt("idx=%s unresolved_tp=%d loose_candidates=%d action=wait", tostring(idx), unresolved, #candidates))
    end

    return nil, nil, nil
end

local function aim_point(info, now)
    now = now or game_time()
    local travel = ss_travel()
    local remain = (info.die or now) - now

    local reachable_start = (info.start_pos ~= nil) and (remain >= travel)

    local prefer_start = (info.start_pos ~= nil) and (remain >= travel + START_MARGIN)
    local function destination_point()
        local pred = CreepPred.predict and CreepPred.predict(info, now) or nil
        return pred or info.dest
    end

    if ui_get(ui.start_point, false) then
        if prefer_start then return info.start_pos, "start" end

        if info.dest then return destination_point(), "dest" end
        if reachable_start then return info.start_pos, "start" end
        return destination_point(), "dest"
    end
    if ui_get(ui.aim_smart, false) then
        if prefer_start then return info.start_pos, "start" end

        if info.dest then return destination_point(), "dest" end
        if reachable_start then return info.start_pos, "start" end
        return nil, "dest"
    end
    return destination_point(), "dest"
end

local function notify(msg)
    if Render and Render.CenteredNotification then
        pcall(Render.CenteredNotification, msg, 2)
    end
end

local function is_tp_end(d)
    if not d then return false end
    if d.name == TP_END_PRT then return true end
    local fn = d.fullName
    return (type(fn) == "string" and fn:find(TP_END_PRT, 1, true)) and true or false
end

local function clone_pos(p)
    if not p then return nil end
    if type(p.Clone) == "function" then
        local ok, c = pcall(p.Clone, p)
        if ok and c then return c end
    end
    return p
end

local function ent_pos(ent)
    if not ent then return nil end
    local p
    if NPC and NPC.GetAbsOrigin then
        local ok, r = pcall(NPC.GetAbsOrigin, ent)
        if ok then p = r end
    end
    if not p and Entity and Entity.GetAbsOrigin then
        local ok, r = pcall(Entity.GetAbsOrigin, ent)
        if ok then p = r end
    end
    return p and clone_pos(p) or nil
end

local function vec_xyz(p)
    if not p then return nil, nil, nil end
    local x, y, z
    pcall(function() x, y, z = p.x, p.y, p.z end)
    return x, y, z
end

local function pos_text(p)
    local x, y, z = vec_xyz(p)
    if type(x) ~= "number" or type(y) ~= "number" then return "nil" end
    if type(z) == "number" then
        return fmt("%.1f,%.1f,%.1f", x, y, z)
    end
    return fmt("%.1f,%.1f", x, y)
end

local function dist2d(a, b)
    local ax, ay = vec_xyz(a)
    local bx, by = vec_xyz(b)
    if type(ax) ~= "number" or type(ay) ~= "number"
        or type(bx) ~= "number" or type(by) ~= "number" then return nil end
    local dx, dy = ax - bx, ay - by
    return math.sqrt(dx * dx + dy * dy)
end

-- Build a displaced world-position using only a clone of an already observed
-- position object. We intentionally do not introduce a guessed Vector/Vec3 API.
function CreepPred.offset_pos(base, dx, dy)
    if not base then return nil end
    local x, y, z = vec_xyz(base)
    if type(x) ~= "number" or type(y) ~= "number" then return nil end

    -- PROJECT EVIDENCE: Vector(x,y,z) is already source/runtime-supported in
    -- TekiTeki and the UCZone API audit. v1.8.4 tried to Clone()+mutate the
    -- engine position userdata; runtime logs proved that path fell back to the
    -- current creep position instead of applying the ~500u projected offset.
    if Vector then
        local okv, out = pcall(Vector, x + (dx or 0), y + (dy or 0), z or 0)
        if okv and out then return out end
    end

    -- Conservative fallback for runtimes where Vector is unexpectedly absent.
    if type(base.Clone) ~= "function" then return nil end
    local okc, out = pcall(base.Clone, base)
    if not okc or not out or out == base then return nil end
    local okw = pcall(function()
        out.x = x + (dx or 0)
        out.y = y + (dy or 0)
    end)
    if not okw then return nil end
    return out
end

function CreepPred.lane_creep_list()
    local API = CreepPred.NPCs
    if not (API and API.GetAll) then return nil, "NPCs.GetAll_missing" end

    local flag = Enum and Enum.UnitTypeFlags and Enum.UnitTypeFlags.TYPE_LANE_CREEP
    local list = nil
    local filtered = false
    if flag ~= nil then
        list = call(API.GetAll, flag)
        filtered = type(list) == "table"
    end
    if type(list) ~= "table" then
        list = call(API.GetAll)
        filtered = false
    end
    if type(list) ~= "table" then return nil, "NPCs.GetAll_failed" end
    return list, filtered and "flag" or "all"
end

function CreepPred.lock(owner, dest, now, particle_index)
    if not CreepPred.ENABLED then return nil end
    if not owner or not dest then return nil end
    local oidx = ent_index(owner)
    if not oidx then return nil end

    local list, scan_mode = CreepPred.lane_creep_list()
    if type(list) ~= "table" then
        log("CREEP_LOCK_FAIL", fmt("particle=%s reason=%s", tostring(particle_index), tostring(scan_mode)))
        return nil
    end

    local owner_team = team_of(owner)
    local best, best_pos, best_d = nil, nil, nil
    local second_d = nil
    for _, ent in pairs(list) do
        if ent and is_alive(ent) and team_of(ent) == owner_team then
            local lane_ok = true
            if NPC and NPC.IsLaneCreep then
                local v = call(NPC.IsLaneCreep, ent)
                lane_ok = v and true or false
            elseif scan_mode ~= "flag" then
                lane_ok = false
            end

            if lane_ok then
                local p = ent_pos(ent)
                local d = p and dist2d(p, dest) or nil
                if d then
                    if not best_d or d < best_d then
                        second_d = best_d
                        best, best_pos, best_d = ent, p, d
                    elseif not second_d or d < second_d then
                        second_d = d
                    end
                end
            end
        end
    end

    if not best or not best_d or best_d > CreepPred.MATCH_MAX_DIST then
        log("CREEP_LOCK_FAIL", fmt(
            "particle=%s reason=no_nearby_lane_creep nearest=%s max=%.0f scan=%s",
            tostring(particle_index), best_d and fmt("%.1f", best_d) or "nil",
            CreepPred.MATCH_MAX_DIST, tostring(scan_mode)
        ))
        return nil
    end

    if best_d > 35.0 and second_d and (second_d - best_d) < CreepPred.AMBIG_MARGIN then
        log("CREEP_LOCK_FAIL", fmt(
            "particle=%s reason=ambiguous nearest=%.1f second=%.1f margin=%.1f",
            tostring(particle_index), best_d, second_d, second_d - best_d
        ))
        return nil
    end

    local rec = {
        ent = best, particle_index = particle_index, locked_at = now,
        last_pos = best_pos, last_t = now, vx = nil, vy = nil,
        samples = 0, match_dist = best_d,
    }
    CreepPred.track[oidx] = rec
    log("CREEP_LOCK", fmt(
        "hero=%s particle=%s creep=%s creep_idx=%s match_dist=%.1f second_dist=%s scan=%s",
        disp(owner), tostring(particle_index), tostring(unit_name(best)),
        tostring(ent_index(best)), best_d,
        second_d and fmt("%.1f", second_d) or "nil", tostring(scan_mode)
    ))
    return rec
end

function CreepPred.sample(now)
    for idx, rec in pairs(CreepPred.track) do
        if type(rec) ~= "table" or now - (rec.locked_at or 0) > CreepPred.TRACK_TTL
            or not rec.ent or not is_alive(rec.ent) then
            CreepPred.track[idx] = nil
        else
            local p = ent_pos(rec.ent)
            local dt = p and rec.last_t and (now - rec.last_t) or 0
            if p and rec.last_pos and dt >= CreepPred.SAMPLE_MIN_DT then
                local x, y = vec_xyz(p)
                local lx, ly = vec_xyz(rec.last_pos)
                if type(x) == "number" and type(y) == "number"
                    and type(lx) == "number" and type(ly) == "number" then
                    local vx, vy = (x - lx) / dt, (y - ly) / dt
                    local speed = math.sqrt(vx * vx + vy * vy)
                    if speed > CreepPred.MAX_SPEED and speed > 0 then
                        local k = CreepPred.MAX_SPEED / speed
                        vx, vy, speed = vx * k, vy * k, CreepPred.MAX_SPEED
                    end
                    if rec.vx ~= nil then
                        rec.vx = rec.vx * 0.30 + vx * 0.70
                        rec.vy = rec.vy * 0.30 + vy * 0.70
                    else
                        rec.vx, rec.vy = vx, vy
                    end
                    rec.samples = (rec.samples or 0) + 1
                    rec.speed = math.sqrt(rec.vx * rec.vx + rec.vy * rec.vy)
                end
                rec.last_pos, rec.last_t = p, now
            end
        end
    end
end

function CreepPred.predict(info, now)
    if not CreepPred.ENABLED then return nil, nil end
    if not info or info.dest_source ~= "particle_owner_cp5" then return nil, nil end
    local idx = info.ent and ent_index(info.ent) or nil
    local rec = idx and CreepPred.track[idx] or nil
    if not rec or not rec.ent or not is_alive(rec.ent) then return nil, nil end

    local cur = ent_pos(rec.ent)
    if not cur then return nil, rec end
    local speed = rec.speed or 0
    if not rec.vx or not rec.vy or speed < CreepPred.MIN_SPEED then
        return cur, rec
    end

    -- Boots destination follows the target unit. Predict the creep to the TP
    -- completion time; Sun Strike itself remains on the separately validated
    -- +80ms post-arrival impact schedule.
    local horizon = math.max(0, (info.die or now) - now)
    local scale = CreepPred.SCALE
    local pred = CreepPred.offset_pos(cur, rec.vx * horizon * scale, rec.vy * horizon * scale)
    return pred or cur, rec
end

local function request_sunstrike(ss, target, now, meta)
    if pending_ss or not ss or not target then return false end

    local cd_before = ab_cd(ss)
    if not cast_position(ss, target) then return false end

    meta = meta or {}
    pending_ss = {
        kind = meta.kind or "auto",
        info = meta.info,
        aim_mode = meta.aim_mode,
        name = meta.name or "?",
        requested_at = now,
        verify_deadline = now + 0.75,
        -- IMPORTANT: keep the exact handle used for the cast. Re-resolving Sun
        -- Strike after submission can return a different/hidden handle whose
        -- cooldown remains zero even though the invoked-slot cast executed.
        ability = ss,
        cd_before = cd_before,
        since_before = ab_since_last_use(ss),
        ready_before = ab_is_ready(ss),
        manual_pos = meta.manual_pos,
        manual_t = meta.manual_t,
    }

    local impact_offset_ms = nil
    if meta.info and meta.info.die then
        impact_offset_ms = floor(((now + ss_travel()) - meta.info.die) * 1000)
    end

    log(
        "CAST_REQUEST",
        fmt(
            "hero=%s mode=%s dest_source=%s travel_ms=%d impact_offset_ms=%s cd_before=%.3f since_before=%s ready_before=%s",
            tostring(pending_ss.name),
            tostring(pending_ss.aim_mode or pending_ss.kind),
            tostring(meta.info and meta.info.dest_source or "manual"),
            floor(ss_travel() * 1000),
            tostring(impact_offset_ms),
            cd_before,
            tostring(pending_ss.since_before),
            tostring(pending_ss.ready_before)
        )
    )

    return true
end

local function update_pending_sunstrike(now)
    local p = pending_ss
    if not p then return false end

    -- Verify the EXACT handle submitted, then use multiple runtime-proven
    -- signals. This avoids false negatives when invoked_ss()/get_ss() resolves
    -- to a different handle after the order.
    local ss = p.ability
    local cd_now = ss and ab_cd(ss) or 0
    local since_now = ss and ab_since_last_use(ss) or nil
    local ready_now = ss and ab_is_ready(ss) or nil

    local cooldown_started = cd_now > (p.cd_before or 0) + 0.05
    local last_use_advanced =
        since_now ~= nil
        and since_now >= 0
        and (
            p.since_before == nil
            or p.since_before < 0
            or since_now < p.since_before
        )
    local readiness_consumed = p.ready_before == true and ready_now == false
    local confirmed = cooldown_started or last_use_advanced or readiness_consumed

    if confirmed then
        if p.kind == "auto" and p.info then
            p.info.fired = true
        end
        stats.fired = stats.fired + 1
        last_cast = now

        if p.kind == "manual" then
            notify("Sun Strike (Manual)")
        else
            notify(((p.aim_mode == "start") and "Sun Strike (TP Start) -> " or "Sun Strike -> ") .. tostring(p.name))
        end

        log(
            "CAST_CONFIRMED",
            fmt(
                "hero=%s mode=%s age_ms=%d cd_now=%.3f since_now=%s ready_now=%s cooldown_started=%s last_use_advanced=%s readiness_consumed=%s",
                tostring(p.name),
                tostring(p.aim_mode or p.kind),
                floor((now - p.requested_at) * 1000),
                cd_now,
                tostring(since_now),
                tostring(ready_now),
                tostring(cooldown_started),
                tostring(last_use_advanced),
                tostring(readiness_consumed)
            )
        )
        pending_ss = nil
        return true
    end

    if now >= p.verify_deadline then
        log(
            "CAST_UNCONFIRMED",
            fmt(
                "hero=%s mode=%s age_ms=%d cd_before=%.3f cd_now=%.3f since_before=%s since_now=%s ready_before=%s ready_now=%s action=retry_if_still_valid",
                tostring(p.name),
                tostring(p.aim_mode or p.kind),
                floor((now - p.requested_at) * 1000),
                p.cd_before or 0,
                cd_now,
                tostring(p.since_before),
                tostring(since_now),
                tostring(p.ready_before),
                tostring(ready_now)
            )
        )

        if p.kind == "manual" and p.manual_pos and p.manual_t
            and (now - p.manual_t) <= MANUAL_TTL
        then
            manual = { pos = p.manual_pos, t = p.manual_t }
        end

        pending_ss = nil
        return false
    end

    return false
end

local function on_particle_create(d)
    if not is_invoker or not ui_get(ui.enabled, false) then return end
    if not d or not is_tp_end(d) then return end
    if d.index == nil then return end
    local ent = d.entityForModifiers or d.entity
    local now = game_time()
    if ent and is_enemy_hero(ent) then
        p_owner[d.index] = { ent = ent, t = now }
        log("PARTICLE_CREATE", fmt(
            "particle=%s owner=%s name=%s full=%s entity=%s entityForModifiers=%s",
            tostring(d.index), disp(ent), tostring(d.name), tostring(d.fullName),
            d.entity and disp(d.entity) or "nil",
            d.entityForModifiers and disp(d.entityForModifiers) or "nil"
        ))
    else
        p_owner[d.index] = { ent = false, t = now }
        log("PARTICLE_CREATE", fmt(
            "particle=%s owner=unresolved name=%s full=%s entity=%s entityForModifiers=%s",
            tostring(d.index), tostring(d.name), tostring(d.fullName),
            d.entity and disp(d.entity) or "nil",
            d.entityForModifiers and disp(d.entityForModifiers) or "nil"
        ))
    end
end

local function handle_particle_update(d)
    if not d or d.index == nil then return end
    local rec = p_owner[d.index]
    if rec == nil then return end

    -- Runtime observability for Boots-of-Travel / creep destination cases.
    -- d.controlPoint and d.position are already-used callback fields; no new API.
    local owner_pos = rec.ent and ent_pos(rec.ent) or nil
    local cp_dist = (d.position and owner_pos) and dist2d(d.position, owner_pos) or nil
    log("PARTICLE_UPDATE", fmt(
        "particle=%s cp=%s has_position=%s pos=%s owner=%s owner_pos=%s dist_from_owner=%s age_ms=%d raw_entity=%s raw_entityForModifiers=%s",
        tostring(d.index),
        tostring(d.controlPoint),
        tostring(d.position ~= nil),
        pos_text(d.position),
        rec.ent and disp(rec.ent) or "unresolved",
        pos_text(owner_pos),
        cp_dist and fmt("%.1f", cp_dist) or "nil",
        floor((game_time() - (rec.t or game_time())) * 1000),
        d.entity and disp(d.entity) or "nil",
        d.entityForModifiers and disp(d.entityForModifiers) or "nil"
    ))

    if not d.position then return end
    local owner = rec.ent
    local cp = d.controlPoint

    -- Runtime-confirmed destination control points:
    --   CP0: normal TP destination (existing behavior)
    --   CP5: Boots of Travel -> creep destination. In the v1.6 probe, each
    --        CP5 coordinate matched Invoker's position at the start of the
    --        following TP, while CP2/4/6 were parameter vectors near (1,0.5,0.8).
    -- Keep CP0 as the canonical source. CP5 is accepted only when this particle
    -- already has a confirmed enemy-hero owner; we do not broaden loose matching.
    if cp == 0 then
        rec.cp0_seen = true
    end
    local accepted_cp = (cp == 0) or (cp == 5 and owner and not rec.cp0_seen)
    if not accepted_cp then return end

    local now = game_time()
    local pos = clone_pos(d.position)
    if not pos then return end
    local source = (cp == 0) and "particle_owner_cp0" or "particle_owner_cp5"

    if owner then
        local oidx = ent_index(owner)
        if oidx then
            -- CP0 is a fixed normal destination. CP5 is the Boots-to-unit path;
            -- when possible, lock the lane creep nearest that CP5 so its motion
            -- can be sampled and predicted instead of freezing the start point.
            if cp == 0 then
                CreepPred.track[oidx] = nil
            elseif cp == 5 then
                CreepPred.lock(owner, pos, now, d.index)
            end

            -- Continue accepting later CP0/CP5 updates for this particle until
            -- OWNER_TTL expires. CP0 can naturally supersede a CP5 sample if a
            -- normal teleport emits both.
            tp_dest[oidx] = {
                dest = pos, t = now, source = source,
                particle_index = d.index,
            }
            local t = tracked[oidx]
            if t then
                t.dest, t.dest_t, t.dest_source = pos, now, source
            elseif filter_on(unit_name(owner)) then
                tracked[oidx] = {
                    ent = owner, name = disp(owner),
                    die = now + TP_CHANNEL, t0 = now,
                    fired = false, dest = pos, dest_t = now,
                    dest_source = source,
                    start_pos = ent_pos(owner),
                    est = true,
                }
            end
            log("DEST", fmt("hero=%s source=%s particle=%s cp=%s", disp(owner), source, tostring(d.index), tostring(cp)))
        end
    else
        -- Update one loose record per particle instead of appending duplicate
        -- CP0 samples from the same particle.
        local found = nil
        for i = 1, #loose do
            if loose[i].particle_index == d.index then
                found = loose[i]
                break
            end
        end
        if found then
            found.dest, found.t = pos, now
        else
            loose[#loose + 1] = {
                dest = pos, t = now, particle_index = d.index, used_by = nil,
            }
            if #loose > MAX_LOOSE then remove(loose, 1) end
        end
    end
    -- Do NOT clear p_owner here. Later CP0 updates may refine the destination;
    -- prune() expires the ownership record using OWNER_TTL.
end

local function prune(now)
    for i = #loose, 1, -1 do
        if now - loose[i].t > LOOSE_WINDOW then remove(loose, i) end
    end
    for idx, d in pairs(tp_dest) do
        if now - d.t > DEST_TTL then tp_dest[idx] = nil end
    end
    for idx, rec in pairs(CreepPred.track) do
        if type(rec) ~= "table" or now - (rec.locked_at or 0) > CreepPred.TRACK_TTL then
            CreepPred.track[idx] = nil
        end
    end
    for idx, t in pairs(tracked) do
        if now > (t.die or 0) + TRACK_TTL then tracked[idx] = nil end
    end
    for idx, t in pairs(hp_seen) do
        if now - t > 30 then
            hp_seen[idx] = nil
            hp_val[idx]  = nil
            hp_max[idx]  = nil
        end
    end
    for idx, t in pairs(dead_seen) do
        if now - t > 60 then dead_seen[idx] = nil end
    end

    for k, rec in pairs(p_owner) do
        if type(rec) ~= "table" or now - (rec.t or 0) > OWNER_TTL then
            p_owner[k] = nil
        end
    end
end

local function update(now)
    if ui.manual and ui_pressed(ui.manual) then
        local pos = call(Input and Input.GetWorldCursorPos)
        if pos then
            manual = { pos = pos, t = now }
            log("MANUAL", "request")
        end
    end

    if now - last_scan > SCAN_INTERVAL then
        last_scan = now
        refresh_enemies()
        refresh_ss_delay()
        prune(now)
    end

    -- Sample any Boots target creep every update. Velocity is derived from
    -- observed positions; no UCZone velocity helper is assumed.
    CreepPred.sample(now)

    local min_remain = 0.2
    local active = false
    for i = 1, #enemies do
        local ent = enemies[i]

        local vidx = ent and ent_index(ent) or nil
        if ent and vidx and not is_dormant(ent) then
            if is_alive(ent) then
                hp_val[vidx] = effective_hp(ent)
                hp_max[vidx] = max_hp(ent)
                if hp_max[vidx] > 0 and hp_val[vidx] >= hp_max[vidx] * 0.98 then
                    dead_seen[vidx] = nil
                end
            else
                dead_seen[vidx] = now
                tracked[vidx]   = nil
            end
        end
        if ent and is_alive(ent) then
            local idx = ent_index(ent)
            if idx then

                if not is_dormant(ent) then hp_seen[idx] = now end
                local mod = get_tp_mod(ent)
                local die = mod and mod_die_time(mod) or nil
                if mod and die then
                    local t = tracked[idx]
                    if t then
                        t.die = die
                        t.est = false
                        if not t.start_pos then t.start_pos = ent_pos(ent) end
                        local nd, nt, ns = resolve_dest(idx, now)
                        if nd and (not t.dest or (nt and nt > (t.dest_t or -1))) then
                            t.dest, t.dest_t, t.dest_source = nd, nt, ns
                        end
                        if not t.fired then active = true end
                    elseif filter_on(unit_name(ent)) and (die - now) >= min_remain then
                        local nd, nt, ns = resolve_dest(idx, now)
                        tracked[idx] = {
                            ent = ent, name = disp(ent), die = die, t0 = now,
                            fired = false, dest = nd, dest_t = nt, dest_source = ns, est = false,
                            start_pos = ent_pos(ent),
                        }
                        active = true
                        log(
                            "TRACK",
                            fmt(
                                "hero=%s remain_ms=%d die=%.3f dest_source=%s",
                                disp(ent),
                                floor((die - now) * 1000),
                                die,
                                tostring(ns or "none")
                            )
                        )
                    end
                elseif tracked[idx] then

                    if not is_dormant(ent) then
                        tracked[idx] = nil
                    end
                end
            end
        end
    end

    if not active then
        for _, t in pairs(tracked) do
            if not t.fired then
                active = true
                break
            end
        end
    end

    local want_build = (manual ~= nil) or (active and ui_get(ui.invoke, false))
    if want_build then drive_invoke(now) else seq = nil end

    update_pending_sunstrike(now)

    local block = cast_blocked()
    local fire_ok = ui_get(ui.fire_on, true)
    local delay = (ui_get(ui.delay, 0) or 0) / 1000
    local lead  = ss_lead()
    local need_lethal = ui_get(ui.lethal, false)
    local allow_fog   = ui_get(ui.fog, true)
    local use_pct     = ui_get(ui.hp_pct_on, false)
    local pct_thr     = ui_get(ui.hp_pct, 60) or 60
    for _, info in pairs(tracked) do
        if not pending_ss and not info.fired and not info.abandoned and is_alive(info.ent) then
            local target, aim_mode = aim_point(info, now)

            -- Boots-to-creep destination shots are guaranteed to involve the TP
            -- target creep at the landing point. When split-damage avoidance is
            -- enabled, suppress only the destination shot; start-position shots
            -- remain allowed because they do not share the destination creep.
            if target
                and aim_mode == "dest"
                and info.dest_source == "particle_owner_cp5"
                and ui_get(ui.avoid_creep_split, true)
            then
                if not info.creep_split_block_logged then
                    info.creep_split_block_logged = true
                    log("CREEP_SPLIT_BLOCK", fmt(
                        "hero=%s source=%s action=skip_destination toggle=on",
                        tostring(info.name), tostring(info.dest_source)
                    ))
                end
                target = nil
            end

            -- Destination prediction is only valid near the TP landing moment.
            -- Evaluate the *projected impact* offset, not merely current time.
            if aim_mode == "dest" and target then
                local projected_impact_offset = (now + ss_travel()) - (info.die or now)
                if projected_impact_offset > DEST_MAX_LATE then
                    info.abandoned = true
                    log("CAST_ABANDON", fmt(
                        "hero=%s mode=dest reason=landing_window_expired projected_impact_offset_ms=%d max_late_ms=%d",
                        tostring(info.name),
                        floor(projected_impact_offset * 1000),
                        floor(DEST_MAX_LATE * 1000)
                    ))
                    target = nil
                end
            end

            local fire_gate
            if aim_mode == "start" then
                -- Start-point shots land while the target is still channeling.
                fire_gate = ((info.die or now) - now) >= ss_travel()
            else
                -- Destination shots are intentionally scheduled to IMPACT after
                -- TP completion: lead = travel - DEST_IMPACT_LAG. Positive UI
                -- delay shifts the impact even later.
                fire_gate = now >= info.die - lead + delay
            end
            if target and fire_gate then
                local in_fog = is_dormant(info.ent)
                local allow  = allow_fog or not in_fog

                local lethal_ok = (not need_lethal) or is_lethal(info.ent, now)

                local pct_ok = true
                if use_pct then
                    local fog_block = ui_get(ui.lethal_vis, true) and is_dormant(info.ent)
                    if fog_block or not hp_trusted(info.ent, now) then
                        pct_ok = false
                    else
                        local p = hp_pct(info.ent)
                        pct_ok = (p ~= nil) and (p <= pct_thr)
                    end
                end
                if allow and not block and lethal_ok and pct_ok and fire_ok then
                    local ss = ss_ready()
                    if ss then
                        if aim_mode == "dest" and info.dest_source == "particle_owner_cp5" then
                            local _, crec = CreepPred.predict(info, now)
                            if crec then
                                local horizon = math.max(0, (info.die or now) - now)
                                local current_pos = ent_pos(crec.ent)
                                local expected_lead = (crec.speed or 0) * horizon * CreepPred.SCALE
                                local applied_lead = current_pos and dist2d(current_pos, target) or nil
                                log("CREEP_PREDICT", fmt(
                                    "hero=%s creep=%s samples=%d speed=%.1f horizon_ms=%d scale=%d expected_lead=%.1f applied_lead=%s current=%s aim=%s",
                                    tostring(info.name), tostring(unit_name(crec.ent)),
                                    crec.samples or 0, crec.speed or 0, floor(horizon * 1000),
                                    floor(CreepPred.SCALE * 100), expected_lead,
                                    applied_lead and fmt("%.1f", applied_lead) or "nil",
                                    pos_text(current_pos), pos_text(target)
                                ))
                            else
                                log("CREEP_PREDICT", fmt(
                                    "hero=%s reason=no_creep_lock action=static_cp5", tostring(info.name)
                                ))
                            end
                        end
                        request_sunstrike(ss, target, now, {
                            kind = "auto",
                            info = info,
                            aim_mode = aim_mode,
                            name = info.name,
                        })
                    end
                end
            end
        end
    end

    if manual and not pending_ss then
        if now - manual.t > MANUAL_TTL then
            manual = nil
        elseif ui_get(ui.fire_on, true) and not cast_blocked() then
            local ss = ss_ready()
            if ss and request_sunstrike(ss, manual.pos, now, {
                kind = "manual",
                name = "manual",
                manual_pos = manual.pos,
                manual_t = manual.t,
            }) then
                manual = nil
            end
        end
    end
end

function script.OnParticleCreate(d)
    pcall(on_particle_create, d)
end

function script.OnParticleUpdate(d)
    pcall(handle_particle_update, d)
end

function script.OnParticleUpdateFallback(d)
    pcall(handle_particle_update, d)
end

function script.OnUpdate()
    if not ui_ready then return end
    if not my_hero then
        my_hero = call(Heroes and Heroes.GetLocal)
        if my_hero then
            is_invoker = (unit_name(my_hero) == INVOKER_NAME)
        end
        return
    end

    if not is_alive(my_hero) then
        local fresh = call(Heroes and Heroes.GetLocal)
        if fresh and fresh ~= my_hero then
            my_hero = fresh
            is_invoker = (unit_name(my_hero) == INVOKER_NAME)
        end
    end
    if not ui_get(ui.enabled, false) or not is_invoker then return end
    if not is_alive(my_hero) then return end
    pcall(update, game_time())
end

local white_const = Color(255, 255, 255, 255)
local black_const = Color(0, 0, 0, 255)

local C_ON     = Color(110, 230, 140, 255)
local C_OFF    = Color(235, 95, 95, 255)
local C_TXT    = Color(216, 221, 234, 255)
local C_DIM    = Color(150, 158, 178, 255)
local C_WARN   = Color(255, 188, 80, 255)
local C_SOON   = Color(255, 120, 64, 255)
local C_KILL   = Color(255, 92, 92, 255)
local C_SHADOW = Color(0, 0, 0, 175)

local function clampn(v, lo, hi)
    if v < lo then return lo elseif v > hi then return hi end
    return v
end

local function color_parts(c)
    local r, g, b, a
    local ok = pcall(function() r, g, b, a = c.r, c.g, c.b, c.a end)
    if ok and r and g and b then return r, g, b, a or 255 end
    r, g, b, a = nil, nil, nil, nil
    ok = pcall(function() r, g, b, a = c[1], c[2], c[3], c[4] end)
    if ok and r and g and b then return r, g, b, a or 255 end
    r, g, b, a = nil, nil, nil, nil
    ok = pcall(function() r, g, b, a = c:Unpack() end)
    if ok and r and g and b then return r, g, b, a or 255 end
    return nil
end

local function fade(c, a)
    local r, g, b = color_parts(c)
    if not r then return c end
    return Color(r, g, b, clampn(floor(a + 0.5), 0, 255))
end

local function lerp_color(ca, cb, t)
    local r1, g1, b1, a1 = color_parts(ca)
    local r2, g2, b2, a2 = color_parts(cb)
    if not (r1 and r2) then return ca end
    t = clampn(t, 0, 1)
    a1 = a1 or 255; a2 = a2 or 255
    return Color(
        floor(r1 + (r2 - r1) * t + 0.5),
        floor(g1 + (g2 - g1) * t + 0.5),
        floor(b1 + (b2 - b1) * t + 0.5),
        floor(a1 + (a2 - a1) * t + 0.5))
end

local function theme_color(name, fallback)
    if not (Menu and Menu.Style) then return fallback end
    local ok, col = pcall(Menu.Style, name)
    if ok and col ~= nil and color_parts(col) then return col end
    return fallback
end

local function shade(c, amt)
    if amt and amt > 0 then return lerp_color(c, white_const, amt / 100) end
    if amt and amt < 0 then return lerp_color(c, black_const, -amt / 100) end
    return c
end

local function fill_circle(cx, cy, radius, color)
    if radius <= 0 then return end
    Render.FilledRect(Vec2(cx - radius, cy - radius), Vec2(cx + radius, cy + radius), color, radius)
end

local function vgradient(x1, y1, x2, y2, c_top, c_bot, rounding)
    local hh = y2 - y1
    if hh <= 0 then return end
    local steps = clampn(floor(hh / 3), 14, 40)
    local sh = hh / steps
    local r  = rounding or 0
    for i = 0, steps - 1 do
        local sy  = y1 + sh * i
        local mid = sy + sh * 0.5
        local de  = math.min(mid - y1, y2 - mid)
        local ins = 0
        if r > 0 and de < r then ins = r - math.sqrt(r * r - (r - de) * (r - de)) end
        local t = i / (steps - 1)
        Render.FilledRect(Vec2(x1 + ins, sy), Vec2(x2 - ins, sy + sh + 0.6), lerp_color(c_top, c_bot, t), 0)
    end
end

local function hgradient(x1, y1, x2, y2, c_left, c_right, rounding)
    local ww = x2 - x1
    if ww <= 0 then return end
    local steps = clampn(floor(ww / 4), 6, 48)
    local sw = ww / steps
    for i = 0, steps - 1 do
        local sx = x1 + sw * i
        local t  = (steps > 1) and (i / (steps - 1)) or 0
        local rr = ((i == 0) or (i == steps - 1)) and (rounding or 0) or 0
        Render.FilledRect(Vec2(sx, y1), Vec2(sx + sw + 0.6, y2), lerp_color(c_left, c_right, t), rr)
    end
end

local function draw_glow_rect(x1, y1, x2, y2, color, spread, rounding, strength)
    if not spread or spread <= 0 then return end
    local r, g, b, a = color_parts(color)
    local base = (a or 200) * (strength or 1.0)
    local n = clampn(floor(spread / 2), 6, 22)
    for i = n, 1, -1 do
        local t = i / n
        local d = spread * t
        if r then
            local al = base * (1 - t) * (1 - t)
            Render.FilledRect(Vec2(x1 - d, y1 - d), Vec2(x2 + d, y2 + d), Color(r, g, b, clampn(floor(al + 0.5), 0, 255)), (rounding or 0) + d)
        else
            Render.FilledRect(Vec2(x1 - d, y1 - d), Vec2(x2 + d, y2 + d), color, (rounding or 0) + d)
        end
    end
end

local function rrect_perimeter(d, x, y, w, h, r, total)
    r = clampn(r, 0, math.min(w, h) * 0.5)
    local sw  = w - 2 * r
    local sh  = h - 2 * r
    local arc = (math.pi * 0.5) * r
    local ad  = (arc > 0) and arc or 1
    d = d % total
    if d <= sw then return x + r + d, y end
    d = d - sw
    if d <= arc then
        local a = (-math.pi * 0.5) + (d / ad) * (math.pi * 0.5)
        return x + w - r + math.cos(a) * r, y + r + math.sin(a) * r
    end
    d = d - arc
    if d <= sh then return x + w, y + r + d end
    d = d - sh
    if d <= arc then
        local a = (d / ad) * (math.pi * 0.5)
        return x + w - r + math.cos(a) * r, y + h - r + math.sin(a) * r
    end
    d = d - arc
    if d <= sw then return x + w - r - d, y + h end
    d = d - sw
    if d <= arc then
        local a = (math.pi * 0.5) + (d / ad) * (math.pi * 0.5)
        return x + r + math.cos(a) * r, y + h - r + math.sin(a) * r
    end
    d = d - arc
    if d <= sh then return x, y + h - r - d end
    d = d - sh
    local a = math.pi + (d / ad) * (math.pi * 0.5)
    return x + r + math.cos(a) * r, y + r + math.sin(a) * r
end

local function draw_flow_border(x, y, w, h, r, color, t, runners, pulse, s)
    local rr    = clampn(r, 0, math.min(w, h) * 0.5)
    local arc   = (math.pi * 0.5) * rr
    local total = 2 * (w - 2 * rr) + 2 * (h - 2 * rr) + 4 * arc
    if total <= 0 then return end
    local cr, cg, cb, ca = color_parts(color)
    cr = cr or 255; cg = cg or 255; cb = cb or 255; ca = ca or 255
    local samples = 46
    local seg     = total * 0.18
    local spacing = seg / samples
    for n = 0, runners - 1 do
        local head = t + (total / runners) * n
        for k = samples - 1, 0, -1 do
            local f   = k / samples
            local d   = head - k * spacing
            local px, py = rrect_perimeter(d, x, y, w, h, rr, total)
            local al  = ca * (1 - f) * (1 - f) * pulse
            local hot = (1 - f) * (1 - f)
            local rcol = floor(cr + (255 - cr) * hot * 0.75 + 0.5)
            local gcol = floor(cg + (255 - cg) * hot * 0.75 + 0.5)
            local bcol = floor(cb + (255 - cb) * hot * 0.75 + 0.5)
            local rad = (3.4 - 2.0 * f) * s
            Render.FilledRect(Vec2(px - rad, py - rad), Vec2(px + rad, py + rad),
                Color(rcol, gcol, bcol, clampn(floor(al + 0.5), 0, 255)), rad)
        end
        local hx, hy = rrect_perimeter(head, x, y, w, h, rr, total)
        Render.FilledRect(Vec2(hx - 9 * s, hy - 9 * s), Vec2(hx + 9 * s, hy + 9 * s), Color(cr, cg, cb, clampn(floor(55 * pulse), 0, 255)), 9 * s)
        Render.FilledRect(Vec2(hx - 5 * s, hy - 5 * s), Vec2(hx + 5 * s, hy + 5 * s), Color(cr, cg, cb, clampn(floor(110 * pulse), 0, 255)), 5 * s)
        Render.FilledRect(Vec2(hx - 2.4 * s, hy - 2.4 * s), Vec2(hx + 2.4 * s, hy + 2.4 * s), Color(255, 255, 255, clampn(floor(235 * pulse), 0, 255)), 2.4 * s)
    end
end

local function txt(s, x, y, size, col, f)
    f = f or font
    if not f then return end
    Render.Text(f, size, s, Vec2(x + 1, y + 1), C_SHADOW)
    Render.Text(f, size, s, Vec2(x - 1, y + 1), C_SHADOW)
    Render.Text(f, size, s, Vec2(x, y), col)
end

local function bar(x, y, w, h, frac, c_track, c_lo, c_hi)
    Render.FilledRect(Vec2(x, y), Vec2(x + w, y + h), c_track, h / 2)
    if frac > 0 then
        hgradient(x, y, x + w * frac, y + h, c_lo, c_hi, h / 2)
    end
end

local function hline(x1, y, x2, col)
    Render.FilledRect(Vec2(x1, y), Vec2(x2, y + 1), col)
end

local function status_text()
    local b = cast_blocked()
    if b then return "BLOCKED: " .. b, C_OFF end
    if not ui_get(ui.fire_on, true) then return "Casting Paused (Fire Off)", C_WARN end
    local ex = get_ability(EXORT)
    local iv = get_ability(INVOKE)
    if not ex or not iv then return "Sun Strike Unavailable", C_DIM end
    if ab_level(ex) < 1 or ab_level(iv) < 1 then return "Exort/Invoke Not Leveled", C_DIM end
    local ss = invoked_ss()
    if ss then
        if can_cast(ss, mana()) then return "Sun Strike Ready", C_ON end
        local need = ss_mana_need()
        if mana() < need then return fmt("Low Mana %d / %d", floor(mana()), floor(need)), C_WARN end
        local cd = ab_cd(ss)
        if cd > 0 then return fmt("Cooldown %.1fs", cd), C_WARN end
        return "Sun Strike Not Ready", C_DIM
    end
    local need = ss_mana_need()
    if mana() < need then return fmt("Invoking, Mana %d/%d", floor(mana()), floor(need)), C_WARN end
    return "Invoking: 3x Exort + Invoke", C_WARN
end

local function update_drag(w, title_h)

    if not pos_loaded then
        pos_loaded = true
        local sx, sy = ui_get(ui.pos_x, nil), ui_get(ui.pos_y, nil)
        if type(sx) == "number" then panel.x = sx end
        if type(sy) == "number" then panel.y = sy end
        last_pos.x, last_pos.y = panel.x, panel.y
    end
    if not drag.on then
        local sx, sy = ui_get(ui.pos_x, nil), ui_get(ui.pos_y, nil)
        if type(sx) == "number" and sx ~= last_pos.x then panel.x = sx; last_pos.x = sx end
        if type(sy) == "number" and sy ~= last_pos.y then panel.y = sy; last_pos.y = sy end
    end
    if not MOUSE1 or not Input then return end
    local mx, my = call(Input.GetCursorPos)
    if type(mx) ~= "number" or type(my) ~= "number" then return end
    if Input.IsKeyDownOnce and call(Input.IsKeyDownOnce, MOUSE1)
        and Input.IsCursorInRect and call(Input.IsCursorInRect, panel.x, panel.y, w, title_h) then
        drag.on = true; drag.dx = mx - panel.x; drag.dy = my - panel.y
    end
    if drag.on then
        if Input.IsKeyDown and call(Input.IsKeyDown, MOUSE1) then
            panel.x = mx - drag.dx; panel.y = my - drag.dy
        else
            drag.on = false

            ui_set(ui.pos_x, floor(panel.x))
            ui_set(ui.pos_y, floor(panel.y))
            last_pos.x, last_pos.y = floor(panel.x), floor(panel.y)
        end
    end
end

local function clamp(v, lo, hi)
    if v < lo then return lo elseif v > hi then return hi end
    return v
end

local function world_to_screen(pos)
    if not pos or not (Render and Render.WorldToScreen) then return nil end
    local ok, a, b = pcall(Render.WorldToScreen, pos)
    if not ok then return nil end
    if type(a) == "number" and type(b) == "number" then return a, b end
    local x, y
    pcall(function() x, y = a.x, a.y end)
    if type(x) == "number" and type(y) == "number" then return x, y end
    return nil
end

local function panel_accent()
    local use_theme   = ui_get(ui.use_theme, true)
    local accent_pick = ui_get(ui.accent, C_WARN) or C_WARN
    local mp = use_theme and theme_color("primary", accent_pick) or accent_pick
    return shade(mp, ui_get(ui.accent_bright, 0))
end

local function draw_world_markers(now, now_t)
    if not ui_get(ui.world_draw, true) then return end
    if not (Render and Render.WorldToScreen) then return end
    local accent = panel_accent()
    local lead = ss_lead()
    local base = ui_get(ui.world_size, 26)
    local need_lethal = ui_get(ui.lethal, false)
    local glow_on  = ui_get(ui.world_glow, true)
    local timer_on = ui_get(ui.world_timer, true)
    for _, info in pairs(tracked) do
        local apos, amode = aim_point(info, now)
        if apos and is_alive(info.ent) then
            local sx, sy = world_to_screen(apos)
            if sx and sy then
                local remain = (info.die or now) - now
                local col, label
                if info.fired then
                    col, label = C_ON, "FIRED"
                elseif need_lethal and not is_lethal(info.ent, now) then
                    col, label = lerp_color(accent, C_DIM, 0.6), nil
                elseif remain <= lead + 0.05 then
                    col, label = C_SOON, "CAST"
                else
                    col, label = accent, fmt("%.1f", remain > 0 and remain or 0)
                end
                local pulse = 0.5 + 0.5 * math.sin(now_t * 6.0)
                local r = base * (0.9 + 0.12 * pulse)
                if glow_on then
                    draw_glow_rect(sx - r, sy - r, sx + r, sy + r, fade(col, 70), base * 0.8, r)
                end
                Render.Rect(Vec2(sx - r, sy - r), Vec2(sx + r, sy + r), fade(col, 235), r)
                Render.Rect(Vec2(sx - r * 0.6, sy - r * 0.6), Vec2(sx + r * 0.6, sy + r * 0.6), fade(col, 140), r * 0.6)
                Render.FilledRect(Vec2(sx - 1, sy - r - 5), Vec2(sx + 1, sy - r + 4), fade(col, 235))
                Render.FilledRect(Vec2(sx - 1, sy + r - 4), Vec2(sx + 1, sy + r + 5), fade(col, 235))
                Render.FilledRect(Vec2(sx - r - 5, sy - 1), Vec2(sx - r + 4, sy + 1), fade(col, 235))
                Render.FilledRect(Vec2(sx + r - 4, sy - 1), Vec2(sx + r + 5, sy + 1), fade(col, 235))
                fill_circle(sx, sy, 2.5, col)
                if amode == "start" then
                    txt("START", sx - 16, sy + r + 4, 13, col, font_small)
                end
                if label and timer_on then
                    txt(label, sx + r + 5, sy - 8, 16, col, font_title)
                end
            end
        end
    end
end

local function on_draw()
    if not is_invoker or not ui_get(ui.enabled, false) then return end
    if not font then return end
    local now   = game_time()
    local now_t = call(GlobalVars and GlobalVars.GetCurTime) or now

    do
        local fv = ui_get(ui.font_choice, ui.font_combo and 0 or 1)
        local fi
        if type(fv) == "string" then
            fi = 1
            for i = 1, #FONT_LABELS do
                if FONT_LABELS[i] == fv or FONT_BASES[i] == fv then fi = i break end
            end
        else
            fi = (type(fv) == "number") and floor(fv) or 0
            if ui.font_combo then fi = fi + 1 end
        end
        if fi < 1 then fi = 1 elseif fi > #FONT_BASES then fi = #FONT_BASES end
        if fi ~= cur_font_idx then
            cur_font_idx = fi
            apply_font(fi)
        end
    end

    draw_world_markers(now, now_t)

    if not ui_get(ui.draw, true) then return end

    local gscale = clampn(ui_get(ui.scale, 100) / 100, 0.5, 2)
    local sc = clampn((ui_get(ui.text_scale, 100) / 100) * gscale, 0.4, 3)
    local function S(n) return floor(n * sc + 0.5) end
    local dens = clampn((ui_get(ui.density, 100) or 100) / 100, 0.6, 1.8)
    local function SG(n) return floor(n * sc * dens + 0.5) end
    local w = floor(ui_get(ui.panel_w, 380) * gscale)

    local use_theme    = ui_get(ui.use_theme, true)
    local accent_pick  = ui_get(ui.accent, C_WARN) or C_WARN
    local menu_primary = use_theme and theme_color("primary", accent_pick) or accent_pick
    local theme_bg     = use_theme and theme_color("additional_background", Color(20, 23, 32)) or Color(20, 23, 32)
    local theme_text   = use_theme and theme_color("primary_widgets_text", Color(236, 240, 248)) or Color(236, 240, 248)
    local theme_shadow = use_theme and theme_color("shadow", Color(0, 0, 0)) or Color(0, 0, 0)

    local _, _, _, theme_bg_a = color_parts(theme_bg)
    local menu_op = (use_theme and clampn((theme_bg_a or 255) / 255, 0, 1) or 1) * (ui_get(ui.opacity, 100) / 100)
    local function op(a)  return clampn(floor(a * menu_op), 0, 255) end
    local fg_op = math.max(menu_op, 0.72)
    local function opf(a) return clampn(floor(a * fg_op), 0, 255) end

    local accent    = shade(menu_primary, ui_get(ui.accent_bright, 0))
    local accent_lt = lerp_color(accent, white_const, 0.35)
    local accent_dk = lerp_color(accent, black_const, 0.42)

    local a_bg = op(ui_get(ui.bg_alpha, 235))
    local rnd  = ui_get(ui.rounding, 14) * gscale

    local bg_base  = lerp_color(theme_bg, accent, ui_get(ui.bg_tint, 12) / 100)
    local bg_dark  = lerp_color(bg_base, black_const, 0.18)
    local bg_light = lerp_color(bg_base, white_const, 0.14)

    local col_bg     = fade(bg_dark, a_bg)
    local col_border = fade(lerp_color(theme_text, theme_bg, 0.5), opf(45))
    local col_title  = lerp_color(theme_text, accent, 0.45)
    local col_dim    = fade(lerp_color(theme_text, accent, 0.10), opf(160))
    local col_sep    = fade(theme_text, opf(28))
    local col_track  = fade(theme_text, opf(45))
    local col_shadow = fade(theme_shadow, op(150))
    local col_pill   = fade(bg_light, op(150))

    local glow_col
    if ui_get(ui.glow_follow, true) then
        glow_col = fade(accent, op(ui_get(ui.glow_alpha, 70)))
    else
        glow_col = ui_get(ui.glow_color, Color(255, 200, 90, 70))
    end

    local TITLE_H = S(36)
    local pad     = S(14)
    local rowH    = S(24)
    local fl      = S(20)
    local frow    = S(ui_get(ui.filter_gap, 24))

    update_drag(w, TITLE_H)

    local show = {}
    for _, info in pairs(tracked) do
        if info.ent and is_alive(info.ent) then show[#show + 1] = info end
    end

    local active = false
    for _, info in pairs(tracked) do
        if not info.fired then active = true break end
    end

    local x, y = panel.x, panel.y
    local show_filter = ui_get(ui.show_filter, true)
    local CHIP_COLS = 3
    local chip_defs = {
        { "Fire",    ui.fire_on,     true  },
        { "Invoke",   ui.invoke,      true  },
        { "Lethal",    ui.lethal,      false },
        { "Visible", ui.lethal_vis,  true  },
        { "Fog",    ui.fog,         true  },
        { "Start",    ui.start_point, false },
        { "Smart Aim",      ui.aim_smart,   false },
        { "HP Limit", ui.hp_pct_on,   false },
    }
    local chip_h    = S(22)
    local chip_gap  = S(6)
    local chip_rows = floor((#chip_defs + CHIP_COLS - 1) / CHIP_COLS)
    local chips_h   = chip_rows * (chip_h + chip_gap) + S(6)

    local show_mana = ui_get(ui.show_mana, true)
    local mana_h = show_mana and SG(26) or 0
    local tp_h   = (#show > 0) and (SG(10) + #show * rowH) or 0
    local h = TITLE_H + S(8) + chips_h + SG(30) + mana_h
        + tp_h
        + (show_filter and (S(12) + S(16) + #enemies * frow) or S(8))
        + pad

    if ui_get(ui.shadow, true) then
        draw_glow_rect(x, y + 5 * gscale, x + w, y + h + 5 * gscale, col_shadow, 16 * gscale, rnd)
    end

    if ui_get(ui.glow, true) then
        local gp = ui_get(ui.glow_size, 22) * gscale
        local gcol = glow_col
        if ui_get(ui.glow_pulse, true) and active then
            local wv = 0.5 + 0.5 * math.sin(now_t * 4.5)
            wv = wv * wv
            gp = gp * (1.0 + 0.35 * (wv - 0.35))
            local cr, cg, cb, ca = color_parts(gcol)
            if cr then
                gcol = Color(cr, cg, cb, clampn(floor((ca or 70) * (1.0 + 0.6 * (wv - 0.35))), 0, 255))
            end
        end
        draw_glow_rect(x, y, x + w, y + h, gcol, gp, rnd)
    end

    Render.FilledRect(Vec2(x, y), Vec2(x + w, y + h), col_bg, rnd)
    vgradient(x + 1, y + 1, x + w - 1, y + h * 0.45, fade(white_const, opf(16)), fade(white_const, 0), rnd)
    if ui_get(ui.sparkles, true) then
        local count = floor(ui_get(ui.spark_count, 18) or 18)
        local inx, iny = x + S(6), y + TITLE_H
        local inw, inh = w - S(12), h - TITLE_H - S(6)
        if inw > 4 and inh > 4 then
            for i = 1, count do
                local fi = i * 12.9898
                local rx = (math.sin(fi) * 43758.5453) % 1
                local ry = (math.sin(fi * 1.7 + 2.3) * 24634.6345) % 1
                local rz = (math.sin(fi * 2.6 + 5.1) * 13511.1357) % 1
                local down = (i % 5 == 0)
                local sp = 0.16 + rx * (down and 0.32 or 0.5)
                local ph = (now_t * sp + rx * 7.0) % 1
                local sway = math.sin(now_t * (0.8 + ry * 1.6) + i * 1.3) * S(6) * (0.4 + rz * 0.8)
                local px = inx + rx * inw + sway
                local py = down and (iny + ph * inh) or (iny + inh - ph * inh)
                if px < inx then px = inx elseif px > inx + inw then px = inx + inw end
                local tw = 0.45 + 0.55 * math.sin(now_t * (2 + ry * 3) + i)
                if tw < 0 then tw = 0 end
                local fadev = down and (1 - math.abs(ph - 0.5) * 2) or (1 - ph)
                if fadev < 0 then fadev = 0 end
                local a = opf(floor(26 + 120 * tw * fadev))
                local big = rz > 0.82
                local sz = big and (S(2) + 1) or ((ry > 0.6) and S(2) or 1)
                local scol2
                local cm = i % 4
                if cm == 0 then scol2 = accent
                elseif cm == 1 then scol2 = accent_lt
                elseif cm == 2 then scol2 = lerp_color(accent, white_const, 0.65)
                else scol2 = white_const end
                if a > 0 then
                    if big then
                        fill_circle(px, py, sz + 1.5, fade(scol2, floor(a * 0.35)))
                    end
                    fill_circle(px, py, sz, fade(scol2, a))
                    if big and tw > 0.85 then
                        local gl = floor(a * 0.9)
                        local gr = sz + S(2) + 1
                        Render.FilledRect(Vec2(px - gr, py - 0.6), Vec2(px + gr, py + 0.6), fade(scol2, gl), 0)
                        Render.FilledRect(Vec2(px - 0.6, py - gr), Vec2(px + 0.6, py + gr), fade(scol2, gl), 0)
                    end
                end
            end
            local NS = 6
            for j = 1, NS do
                local fj = j * 7.3771 + 1.13
                local sx2 = inx + (math.sin(fj) * 0.5 + 0.5) * inw
                local sy2 = iny + (math.sin(fj * 1.9 + 0.7) * 0.5 + 0.5) * inh
                local tw2 = 0.5 + 0.5 * math.sin(now_t * (1.5 + (j % 3)) + j * 2.1)
                if tw2 > 0.55 then
                    local sa2 = opf(floor(150 * (tw2 - 0.55) / 0.45))
                    local rr = S(2) + 1
                    local sc3 = (j % 2 == 0) and accent_lt or white_const
                    Render.FilledRect(Vec2(sx2 - rr, sy2 - 0.6), Vec2(sx2 + rr, sy2 + 0.6), fade(sc3, sa2), 0)
                    Render.FilledRect(Vec2(sx2 - 0.6, sy2 - rr), Vec2(sx2 + 0.6, sy2 + rr), fade(sc3, sa2), 0)
                end
            end
            local shoot_period = 6.0
            local shp = (now_t % shoot_period) / shoot_period
            if shp < 0.16 then
                local stt = shp / 0.16
                local senv = math.sin(stt * math.pi)
                local hx = inx + stt * inw
                local hy = iny + inh * 0.2 + stt * inh * 0.55
                for k = 0, 7 do
                    local kf = k / 7
                    local tx2 = hx - kf * S(22)
                    local ty2 = hy - kf * S(11)
                    if tx2 > inx and ty2 > iny then
                        local ta = opf(floor(190 * senv * (1 - kf)))
                        if ta > 0 then fill_circle(tx2, ty2, math.max((1.6 - kf) * gscale, 0.6), fade(white_const, ta)) end
                    end
                end
            end
        end
    end

    local bwid = floor(ui_get(ui.border_width, 1))
    for i = 0, bwid - 1 do
        Render.Rect(Vec2(x + i, y + i), Vec2(x + w - i, y + h - i), col_border, math.max(rnd - i, 0))
    end
    Render.Rect(Vec2(x + bwid, y + bwid), Vec2(x + w - bwid, y + h - bwid), fade(accent, opf(55)), math.max(rnd - bwid, 0))

    if ui_get(ui.flow, true) then
        local vel = ui_get(ui.flow_speed, 32) * 6 * gscale
        local pulse = 0.62 + 0.38 * (0.5 + 0.5 * math.sin(now_t * 4.0))
        draw_flow_border(x, y, w, h, rnd, lerp_color(accent, white_const, 0.12), now_t * vel, 2, pulse, gscale)
    end

    if ui_get(ui.flash, true) then
        local dt = now - last_cast
        if dt >= 0 and dt < 0.40 then
            local k = 1 - (dt / 0.40)
            draw_glow_rect(x, y, x + w, y + h, fade(accent, floor(150 * k)), (22 * k + 4) * gscale, rnd)
            Render.Rect(Vec2(x - 2, y - 2), Vec2(x + w + 2, y + h + 2), fade(white_const, floor(200 * k)), rnd + 2)
        end
    end

    Render.FilledRect(Vec2(x, y), Vec2(x + w, y + TITLE_H), fade(lerp_color(bg_light, accent, 0.10), op(200)), rnd)
    if ui_get(ui.title_sheen, true) then
        local inten = (ui_get(ui.sheen_power, 60) or 60) / 60
        local sheen_period = 4.5
        local sheen_ph = (now_t % sheen_period) / sheen_period
        if sheen_ph < 0.5 and inten > 0 then
            local st = sheen_ph / 0.5
            local env = math.sin(st * math.pi)
            if env > 0.01 then
                local span = w + 80 * gscale
                local scx = x - 40 * gscale + span * st
                local sbw = 22 * gscale
                local skew = 14 * gscale
                local ROWS = 6
                local rowh = (TITLE_H - 2) / ROWS
                for r = 0, ROWS - 1 do
                    local sry = y + 1 + r * rowh
                    local vfrac = (r / (ROWS - 1)) - 0.5
                    local rcx = scx + skew * vfrac
                    local STR = 7
                    for si = 0, STR - 1 do
                        local u = (si / (STR - 1)) * 2 - 1
                        local sx = rcx + u * sbw
                        if sx > x + 1 and sx < x + w - 1 then
                            local sa = floor(70 * env * (1 - u * u) * inten)
                            if sa > 255 then sa = 255 end
                            if sa > 0 then
                                Render.FilledRect(Vec2(sx, sry), Vec2(sx + math.max(2.2 * gscale, 1), sry + rowh + 1), fade(white_const, opf(sa)), 0)
                            end
                        end
                    end
                end
            end
        end
    end
    Render.FilledRect(Vec2(x + S(5), y + S(7)), Vec2(x + S(8), y + TITLE_H - S(7)), accent, S(2))
    if ui_get(ui.accent_line, true) then
        local lw = w - pad * 2
        local seg = lw * 0.4
        local off = (now_t * 80 * gscale) % (lw + seg)
        Render.FilledRect(Vec2(x + pad, y + TITLE_H - S(2)), Vec2(x + w - pad, y + TITLE_H - S(1)), fade(accent, opf(80)))
        local l1 = clampn(x + pad + off - seg, x + pad, x + w - pad)
        local l2 = clampn(x + pad + off, x + pad, x + w - pad)
        if l2 > l1 then
            Render.FilledRect(Vec2(l1, y + TITLE_H - S(2)), Vec2(l2, y + TITLE_H - S(1)), fade(white_const, opf(170)))
        end
    else
        Render.FilledRect(Vec2(x + pad, y + TITLE_H - S(2)), Vec2(x + w - pad, y + TITLE_H - S(1)), fade(accent, opf(170)))
    end

    local en = ui_get(ui.enabled, false)
    local dot_x, dot_y = x + S(22), y + TITLE_H / 2
    if ui_get(ui.glow, true) then
        fill_circle(dot_x, dot_y, S(7), fade(en and C_ON or C_OFF, opf(70)))
    end
    fill_circle(dot_x, dot_y, S(4), en and C_ON or C_OFF)
    txt("INVOKER TP", x + S(34), y + (TITLE_H - S(16)) / 2, S(16), col_title, font_heavy)
    do
        local fl = FONT_LABELS[cur_font_idx] or "Georgia"
        local fw = 0
        local okf, fs = pcall(function() return Render.TextSize(font_small, S(10), fl) end)
        if okf and fs and fs.x then fw = fs.x end
        txt(fl, x + w - pad - fw, y + (TITLE_H - S(10)) / 2, S(10), fade(col_title, opf(110)), font_small)
    end

    local cy = y + TITLE_H + S(8)

    do
        local cmx, cmy
        if Input and Input.GetCursorPos then cmx, cmy = call(Input.GetCursorPos) end
        local chas = type(cmx) == "number" and type(cmy) == "number"
        local cclick = (not drag.on) and chas and MOUSE1 and Input.IsKeyDownOnce
            and call(Input.IsKeyDownOnce, MOUSE1) and true or false
        local avail = w - pad * 2
        local cell  = (avail + chip_gap) / CHIP_COLS
        for i = 1, #chip_defs do
            local ccol = (i - 1) % CHIP_COLS
            local crow = floor((i - 1) / CHIP_COLS)
            local cxp = x + pad + floor(ccol * cell)
            local cright = (ccol == CHIP_COLS - 1) and (x + pad + avail) or (cxp + floor(cell - chip_gap))
            local cw = cright - cxp
            local cyp = cy + crow * (chip_h + chip_gap)
            local on = ui_get(chip_defs[i][2], chip_defs[i][3])
            local cc = on and C_ON or C_OFF
            local hover = chas and cmx >= cxp and cmx <= cxp + cw and cmy >= cyp and cmy <= cyp + chip_h
            Render.FilledRect(Vec2(cxp, cyp), Vec2(cxp + cw, cyp + chip_h), fade(cc, opf(hover and 70 or 26)), S(5))
            Render.Rect(Vec2(cxp, cyp), Vec2(cxp + cw, cyp + chip_h), fade(cc, opf(on and 210 or 90)), S(5))
            local clabel = chip_defs[i][1]
            local clw = 0
            local okc2, cs2 = pcall(function() return Render.TextSize(font_small, S(12), clabel) end)
            if okc2 and cs2 and cs2.x then clw = cs2.x end
            local clx = cxp + floor((cw - clw) / 2)
            if clx < cxp + S(4) then clx = cxp + S(4) end
            txt(clabel, clx, cyp + floor((chip_h - S(12)) / 2), S(12), cc, font_small)
            if hover and cclick then ui_set(chip_defs[i][2], not on) end
        end
        cy = cy + chips_h
    end

    local stext, scol = status_text()
    Render.FilledRect(Vec2(x + pad, cy), Vec2(x + w - pad, cy + S(22)), col_pill, S(7))
    Render.FilledRect(Vec2(x + pad, cy), Vec2(x + pad + S(4), cy + S(22)), scol, S(7))
    fill_circle(x + pad + S(16), cy + S(11), S(4), scol)
    txt(stext, x + pad + S(28), cy + floor((S(22) - S(13)) / 2), S(13), scol, font)
    cy = cy + SG(30)

    if ui_get(ui.show_mana, true) then
        local need = ss_mana_need()
        local m = mana()
        local mfrac = clampn((need > 0) and (m / need) or 1, 0, 1)
        local mana_ok = m >= need
        bar(x + pad, cy, w - 2 * pad, S(6), mfrac, col_track,
            mana_ok and lerp_color(C_ON, black_const, 0.30) or accent_dk,
            mana_ok and C_ON or accent_lt)
        txt(fmt("Mana %d / %d", floor(m), floor(need)), x + pad, cy + S(8), S(11), col_dim, font_small)
        cy = cy + SG(26)
    end

    if #show > 0 then
        hline(x + pad, cy, x + w - pad, col_sep)
        cy = cy + SG(10)
        for _, info in ipairs(show) do
            local remain = info.die - now
            local lethal = is_lethal(info.ent)
            local apos, amode = aim_point(info, now)
            local col, tag
            if info.fired then
                col, tag = C_ON, "FIRED"
            elseif not apos then
                col, tag = col_dim, "aim point unknown"
            elseif amode == "start" then
                col, tag = C_WARN, "TP start"
            elseif enemy_immune(info.ent) then
                col, tag = col_dim, "target immune"
            elseif ui_get(ui.lethal, false) and not lethal then
                if ui_get(ui.lethal_vis, true) and is_dormant(info.ent) then
                    col, tag = col_dim, "in fog - HP unknown"
                else
                    col, tag = col_dim, fmt("not lethal %d / %d HP", floor(predicted_dmg(info.ent)), floor(effective_hp(info.ent)))
                end
            elseif remain <= ss_lead() + 0.05 then
                col, tag = C_SOON, "CAST"
            else
                col, tag = C_WARN, fmt("TP %.1fs", remain)
            end
            local ry0 = cy + floor((rowH - S(14)) / 2)
            if ui_get(ui.glow, true) and (col == C_SOON or col == C_ON) then
                draw_glow_rect(x + pad, ry0, x + pad + S(3), ry0 + S(14), fade(col, opf(120)), S(5), 1)
            end
            Render.FilledRect(Vec2(x + pad, ry0), Vec2(x + pad + S(3), ry0 + S(14)), col, 1)
            local ty = cy + floor((rowH - S(13)) / 2)
            txt(info.name, x + pad + S(10), ty, S(13), col, font)
            local tagw = 0
            local okw, tsize = pcall(function() return Render.TextSize(font_small, S(12), tag) end)
            if okw and tsize and tsize.x then tagw = tsize.x end
            txt(tag, x + w - pad - tagw, ty + 1, S(12), col, font_small)
            cy = cy + rowH
        end
    end

    if show_filter then
        cy = cy + S(4)
        hline(x + pad, cy, x + w - pad, col_sep)
        cy = cy + S(8)
        txt("Enemy Filter", x + pad, cy, S(12), col_dim, font_small)
        cy = cy + S(16)
        local isz = S(18)
        local tsz = S(12)
        local mx, my
        if Input and Input.GetCursorPos then mx, my = call(Input.GetCursorPos) end
        local has_cur = type(mx) == "number" and type(my) == "number"
        local clicked = (not drag.on) and has_cur and MOUSE1 and Input.IsKeyDownOnce
            and call(Input.IsKeyDownOnce, MOUSE1) and true or false
        for i = 1, #enemies do
            local ent = enemies[i]
            local nm = unit_name(ent)
            local on = filter_on(nm)
            local row_top = cy
            local rx, rw = x + pad, w - pad * 2
            local ry = row_top + floor((frow - isz) / 2)
            local hover = has_cur and mx >= rx - S(4) and mx <= rx + rw + S(4)
                and my >= row_top and my <= row_top + frow
            if hover then
                Render.FilledRect(Vec2(rx - S(4), row_top), Vec2(rx + rw + S(4), row_top + frow), fade(accent, opf(26)), S(4))
                if clicked then
                    ui_set(filters[nm], not ui_get(filters[nm], true))
                    on = filter_on(nm)
                end
            end
            local rowc = on and C_ON or C_OFF
            local ty = ry + floor((isz - tsz) / 2)
            local tx = rx
            if draw_hero_icon(nm, tx, ry, isz, on and 255 or 80) then
                pcall(Render.Rect, Vec2(tx, ry), Vec2(tx + isz, ry + isz), fade(rowc, opf(on and 230 or 110)), S(3))
                tx = tx + isz + S(10)
            else
                txt(on and "[x]" or "[ ]", tx, ty, tsz, rowc, font_small)
                tx = tx + S(24)
            end
            txt(disp(ent), tx, ty, tsz, rowc, font_small)
            cy = cy + frow
        end
    end
end

function script.OnDraw()
    pcall(on_draw)
end

local function reset()
    tracked, tp_dest, p_owner, loose = {}, {}, {}, {}
    CreepPred.track = {}
    enemies = {}
    hp_seen = {}
    hp_val, hp_max, dead_seen = {}, {}, {}
    seq, next_step = nil, 0
    invoke_guard = 0
    manual = nil
    pending_ss = nil
    dest_ambig_logged = {}
    stats = { fired = 0 }
    ss_delay = DEFAULT_DELAY
    last_scan = 0
end

function script.OnGameStart()
    reset()
    my_hero, is_invoker = nil, false
end

function script.OnGameEnd()
    reset()
    my_hero, is_invoker = nil, false
    filters = {}
end

ui_ready = build_menu()
print("[TPI] LOAD_OK | version=1.8.6-creep-split-toggle")
if not ui_ready then
    print("[TPI][MENU_ERROR] build_menu_failed")
    log("INIT", "menu API unavailable")
end

return script
