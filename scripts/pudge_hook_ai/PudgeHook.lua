-- =============================================================================
-- Umbrella Dota 2 Script: Advanced Pudge Meat Hook AI (PudgeHook.lua)
-- • Eroe supportato: Pudge (npc_dota_hero_pudge)
-- • Attivazione:
--   - Tenendo premuto MOUSE 4: aggancia l'eroe NEMICO indicato dal cursore.
--   - Tenendo premuto MOUSE 3: aggancia l'eroe ALLEATO indicato dal cursore (Salvataggio).
-- • Vincolo Fondamentale "SOLO GANCIO - ZERO MOVIMENTO":
--   - Lo script NON muove mai Pudge. Non invia mai ordini di movimento per avvicinarsi.
--   - Blocca eventuali ordini di movimento indesiderati durante la mira affinché Pudge
--     esegua esclusivamente il lancio chirurgico del gancio (Ability.CastPosition).
-- • Finestra Temporale Ottimale (Max 3.0 Secondi) & Precisione >= 75%:
--   - Dal momento in cui si preme Mouse 4 (o Mouse 3), lo script studia il bersaglio
--     e lancia il gancio nel minor tempo possibile (anche in 0ms se la finestra è già
--     perfetta) ed entro un massimo di 3.0 secondi, solo quando la confidenza di impatto
--     raggiunge o supera il 75% (regolabile) e la traiettoria è 100% libera.
-- • Esatta Topologia della Mappa di Dota 2 & Studio Complessissimo di Pathfinding:
--   - Integra GridNav, alberi reali (Trees), dislivelli altimetrici (Cliffs/Highground Z),
--     strettoie/scale (Chokepoints & Ramps), torri attive, fontane e Waypoint delle 3 corsie.
--   - Simula il pathfinding multi-step con deviazione sugli ostacoli (Tree/Wall Sliding),
--     analisi del confinamento laterale nei corridoi (Juke paths) e convergenza multi-ramo.
-- • Analisi Profonda delle Intenzioni Comportamentali (Behavioral Intent Engine):
--   - Rileva in tempo reale: FARMING (Last-hit/Deny con predizione del punto e istante di
--     stop per attaccare), PUSHING (avanzata con wave/torre), RETREATING (fuga verso
--     torre alleata o fontana), CHASING (inseguimento), LOCKED/TIMED (Stun, Root, Cast,
--     Channeling, Eul, Astral, Disruption, TP) e JUKING (analisi frequenza di zig-zag).
-- • Controllo Collisioni 4D & Edge-Sniping (Off-Center Hook):
--   - Verifica spazio-temporale di tutti i creep (alleati, nemici, neutrali), evocazioni
--     ed altri eroi lungo la traiettoria.
--   - Scansione micro-angolare (Edge-Sniping): se il centro del bersaglio è parzialmente
--     coperto da un creep ma il bordo dell'hitbox del nemico è scoperto, mira al fianco
--     libero catturando l'eroe senza toccare il creep.
-- • Stop-Cancel Intelligente dell'Animazione (Auto-Cancel on Miss):
--   - Durante i 0.3s di cast point (Ability.IsInAbilityPhase), ricalcola ad ogni tick se
--     il gancio andrà a segno. Se il bersaglio schiva bruscamente, usa Blink/Eul o un
--     creep entra nella linea di tiro, invia all'istante HoldPosition ('S') fermando
--     l'animazione prima che il gancio parta!
-- =============================================================================
---@diagnostic disable: undefined-global, redundant-parameter, unspecified-field

local PudgeHook = {}

-- =============================================================================
-- COSTANTI MECCANICHE DI PUDGE & DOTA 2
-- =============================================================================
local HERO_NAME = "npc_dota_hero_pudge"
local HOOK_ABILITY_NAME = "pudge_meat_hook"

local DEFAULT_HOOK_SPEED = 1600.0       -- Velocità del gancio in unità/sec
local DEFAULT_HOOK_WIDTH = 100.0        -- Raggio di cattura della punta del gancio
local DEFAULT_CAST_POINT = 0.30         -- Cast point di Meat Hook (0.3s)
local DEFAULT_CAST_RANGE = 1300.0       -- Range base (1495 con Flayer's Hook)
local PUDGE_TURN_RATE = 0.70            -- Turn rate base di Pudge
local HERO_HULL_RADIUS = 24.0           -- Raggio collisione standard eroi/creep

-- Codici tasti Mouse in Source 2 / Umbrella (ButtonCode_t)
-- 316 = KEY_MOUSE_3 (Middle Mouse), 317 = KEY_MOUSE_4 (Side Back), 318 = KEY_MOUSE_5
local KEY_CODE_MOUSE3 = (Enum and Enum.ButtonCode and (Enum.ButtonCode.KEY_MOUSE3 or Enum.ButtonCode.KEY_MOUSE_3 or Enum.ButtonCode.MOUSE_3 or Enum.ButtonCode.MOUSE_MIDDLE)) or 316
local KEY_CODE_MOUSE4 = (Enum and Enum.ButtonCode and (Enum.ButtonCode.KEY_MOUSE4 or Enum.ButtonCode.KEY_MOUSE_4 or Enum.ButtonCode.MOUSE_4)) or 317

-- =============================================================================
-- CONFIGURAZIONE MENU (GUI)
-- =============================================================================
local main_tab = Menu.Create("Heroes", "Hero List", "Pudge", "PudgeHook AI")
main_tab:Icon("\u{f05b}") -- Crosshair icon

local ui = {}

-- 1. Controlli Principali & Tasti (Modificabili In-Game da Menu o da HUD Bar)
local grp_main = main_tab:Create("Main & Activation Keys")
ui.enabled = grp_main:Switch("Enable PudgeHook AI", true)
ui.enabled:ToolTip("Attiva il sistema avanzato di mira predittiva, pathfinding e stop-cancel per il gancio di Pudge.")

ui.enemy_key = grp_main:Bind("Hook Enemy Key (Hold)", KEY_CODE_MOUSE4)
ui.enemy_key:ToolTip("Tasto per agganciare l'eroe NEMICO (Default: Mouse 4). Puoi cambiarlo cliccando qui oppure direttamente in partita sulla barra HUD!")

ui.ally_key = grp_main:Bind("Hook Ally Key (Hold)", KEY_CODE_MOUSE3)
ui.ally_key:ToolTip("Tasto per salvare/agganciare l'eroe ALLEATO (Default: Mouse 3). Puoi cambiarlo cliccando qui oppure direttamente in partita sulla barra HUD!")

ui.rebind_enemy_live = grp_main:Switch("Live Rebind Enemy Key In-Game", false)
ui.rebind_enemy_live:ToolTip("Attiva questo switch in partita e premi qualsiasi tasto della tastiera o del mouse per assegnarlo all'istante al Gancio Nemico!")

ui.rebind_ally_live = grp_main:Switch("Live Rebind Ally Key In-Game", false)
ui.rebind_ally_live:ToolTip("Attiva questo switch in partita e premi qualsiasi tasto della tastiera o del mouse per assegnarlo all'istante al Gancio Alleato!")

ui.reset_keys = grp_main:Switch("Reset Keys to Default (Mouse 4 / Mouse 3)", false)
ui.reset_keys:ToolTip("Ripristina istantaneamente i tasti predefiniti: Mouse 4 per Nemici e Mouse 3 per Alleati.")

ui.max_wait_time = grp_main:Slider("Max Aiming Window (sec)", 10, 30, 30, function(v)
    return string.format("%.1f s", v / 10.0)
end)
ui.max_wait_time:ToolTip("Tempo massimo (default 3.0s) entro cui lo script studia il nemico e lancia il gancio perfetto dal momento della pressione.")

ui.min_confidence = grp_main:Slider("Minimum Hit Confidence (%)", 50, 95, 75, "%d%%")
ui.min_confidence:ToolTip("Soglia minima di precisione richiesta per rilasciare il gancio (default 75%).")

ui.cursor_search_radius = grp_main:Slider("Cursor Target Lock Radius", 250, 1000, 650, "%d units")
ui.cursor_search_radius:ToolTip("Raggio attorno al cursore (e lungo il cono di puntamento) per selezionare il bersaglio quando premi il tasto gancio.")

ui.lock_movement = grp_main:Switch("Never Move Pudge (Hook Only)", true)
ui.lock_movement:ToolTip("Impedisce categoricamente a Pudge di muoversi durante la mira: lo script eseguirà SOLO il lancio del gancio.")

-- 2. Logica Stop-Cancel Animazione (Anti-Miss)
local grp_cancel = main_tab:Create("Animation Stop-Cancel (Anti-Miss)")
ui.auto_cancel = grp_cancel:Switch("Cancel Hook Animation If Going to Miss", true)
ui.auto_cancel:ToolTip("Ferma istantaneamente l'animazione dei 0.3s di cast se il nemico cambia direzione/schiva o se un creep entra nella traiettoria (SOLO per i lanci automatici dell'AI).")

ui.never_cancel_manual = grp_cancel:Switch("Never Block / Cancel Manual Hooks (Q)", true)
ui.never_cancel_manual:ToolTip("Garantisce al 100% che se lanci il gancio manualmente (premendo Q o cliccando l'abilità), lo script non bloccherà né fermerà MAI il gancio!")

ui.cancel_margin = grp_cancel:Slider("Cancel Hit Tolerance (Units)", 65, 130, 96, "%d units")
ui.cancel_margin:ToolTip("Distanza massima tra la traiettoria del gancio in canna e la posizione ricalcolata del bersaglio oltre la quale l'animazione viene interrotta.")

-- 3. Pathfinding, Mappa & Intenzioni
local grp_ai = main_tab:Create("Pathfinding & Intent Engine")
ui.use_pathfinding = grp_ai:Switch("Dota 2 Map Topology & Pathfinding", true)
ui.use_pathfinding:ToolTip("Simula l'esatta forma della mappa (GridNav, alberi, scogliere, scale, rampe e corridoi) per prevedere dove il nemico è costretto a camminare.")

ui.use_intent = grp_ai:Switch("Deep Hero Intent Analysis", true)
ui.use_intent:ToolTip("Analizza se il nemico sta farmando (last-hit creep), pushando, tornando verso la base/torre (retreating) o jukando.")

ui.use_edge_snipe = grp_ai:Switch("Edge-Sniping (Curve Around Creeps)", true)
ui.use_edge_snipe:ToolTip("Se un creep copre il centro del nemico ma il bordo della sua hitbox è scoperto, mira al bordo libero per agganciare l'eroe evitando il creep.")

ui.use_timed_hook = grp_ai:Switch("Frame-Perfect Timed Hooks (Eul/Astral/TP)", true)
ui.use_timed_hook:ToolTip("Calcola al millisecondo il tempo di volo per colpire nemici in Eul, Wind Waker, Astral Imprisonment, Disruption o Teleport.")

ui.obstacle_safety = grp_ai:Slider("Creep Avoidance Safety Margin", 5, 55, 26, "%d units")
ui.obstacle_safety:ToolTip("Margine extra di sicurezza (in unità) attorno a creep ed unità non desiderate per garantire 0% agganci errati.")

-- 4. Visualizzazione & Telemetria HUD
local grp_visual = main_tab:Create("Visuals & Telemetry")
ui.enable_file_logs = grp_visual:Switch("Save Detailed Hook Logs (logspudge.md)", true)
ui.enable_file_logs:ToolTip("Salva in tempo reale in logspudge.md l'analisi dettagliata di ogni gancio di successo, fallito o stoppato, spiegando il perché e quali parametri migliorare.")
ui.draw_keybind_bar = grp_visual:Switch("Show In-Game Quick Rebind Bar (Clickable)", true)
ui.draw_keybind_bar:ToolTip("Mostra un pannello compatto in partita con i tasti attivi: clicca col tasto sinistro su [Enemy] o [Ally] direttamente sullo schermo per cambiare tasto al volo!")
ui.keybind_bar_x = grp_visual:Slider("Quick Rebind Bar X Position", 10, 1800, 24, "%d px")
ui.keybind_bar_y = grp_visual:Slider("Quick Rebind Bar Y Position", 10, 1000, 120, "%d px")
ui.draw_hud = grp_visual:Switch("Draw Prediction HUD & Intent Info", true)
ui.draw_path = grp_visual:Switch("Draw Simulated Path & Hook Line", true)
ui.draw_range = grp_visual:Switch("Draw Hook Max Range Circle", false)
ui.notify = grp_visual:Switch("Console & Chat Diagnostics", true)

-- Gestione dipendenze UI
ui.enabled:SetCallback(function(self)
    local en = self:Get()
    ui.enemy_key:Disabled(not en)
    ui.ally_key:Disabled(not en)
    ui.rebind_enemy_live:Disabled(not en)
    ui.rebind_ally_live:Disabled(not en)
    ui.reset_keys:Disabled(not en)
    ui.max_wait_time:Disabled(not en)
    ui.min_confidence:Disabled(not en)
    ui.cursor_search_radius:Disabled(not en)
    ui.lock_movement:Disabled(not en)
    ui.auto_cancel:Disabled(not en)
    ui.never_cancel_manual:Disabled(not en)
    ui.cancel_margin:Disabled(not en or not ui.auto_cancel:Get())
    ui.use_pathfinding:Disabled(not en)
    ui.use_intent:Disabled(not en)
    ui.use_edge_snipe:Disabled(not en)
    ui.use_timed_hook:Disabled(not en)
    ui.obstacle_safety:Disabled(not en)
    ui.enable_file_logs:Disabled(not en)
    ui.draw_keybind_bar:Disabled(not en)
    ui.keybind_bar_x:Disabled(not en or not ui.draw_keybind_bar:Get())
    ui.keybind_bar_y:Disabled(not en or not ui.draw_keybind_bar:Get())
    ui.draw_hud:Disabled(not en)
    ui.draw_path:Disabled(not en)
    ui.draw_range:Disabled(not en)
    ui.notify:Disabled(not en)
end, true)

ui.draw_keybind_bar:SetCallback(function(self)
    if ui.enabled:Get() then
        local show = self:Get()
        ui.keybind_bar_x:Disabled(not show)
        ui.keybind_bar_y:Disabled(not show)
    end
end, true)

ui.auto_cancel:SetCallback(function(self)
    if ui.enabled:Get() then
        local ac = self:Get()
        ui.cancel_margin:Disabled(not ac)
    end
end, true)

-- =============================================================================
-- TOPOLOGIA DELLA MAPPA DI DOTA 2 (COORDINATE ESATTE, CORSIE, CHOKEPOINTS)
-- =============================================================================
local MAP_DATA = {
    -- Fontane & Ancient (Team 2 = Radiant, Team 3 = Dire)
    RADIANT_FOUNTAIN = Vector(-6750, -6250, 384),
    RADIANT_ANCIENT  = Vector(-5850, -5350, 256),
    DIRE_FOUNTAIN    = Vector(6800, 6200, 384),
    DIRE_ANCIENT     = Vector(5550, 5000, 256),

    -- Limiti calpestabili della mappa
    MAP_MIN_X = -8100,
    MAP_MAX_X = 8100,
    MAP_MIN_Y = -8100,
    MAP_MAX_Y = 8100,

    -- Waypoints ordinati da Radiant -> Dire per ciascuna delle 3 corsie
    LANES = {
        TOP = {
            Vector(-6200, -3800, 256),
            Vector(-6250, -1500, 128),
            Vector(-6300,  1800, 128),
            Vector(-6150,  4200, 128),
            Vector(-5600,  5650, 128),
            Vector(-3500,  6050, 128),
            Vector( -500,  6100, 128),
            Vector( 2500,  6050, 128),
            Vector( 4550,  5950, 256),
        },
        MID = {
            Vector(-4650, -4150, 256),
            Vector(-3350, -2850, 128),
            Vector(-1650, -1400, 128),
            Vector( -450,  -300,  16), -- River Mid
            Vector(  850,   750, 128),
            Vector( 2450,  2100, 128),
            Vector( 4100,  3650, 256),
        },
        BOT = {
            Vector(-4500, -6050, 256),
            Vector(-1500, -6100, 128),
            Vector( 1800, -6100, 128),
            Vector( 4800, -6000, 128),
            Vector( 6150, -5200, 128),
            Vector( 6250, -3200, 128),
            Vector( 6250,  -500, 128),
            Vector( 6250,  2000, 128),
            Vector( 6150,  3900, 256),
        },
    },

    -- Chokepoints, Scale (Stairs) e Rampe obbligate della mappa di Dota 2
    -- Quando un eroe entra nel raggio di cattura di una rampa/scala mentre si dirige
    -- nella direzione dell'asse della rampa, il suo movimento è canalizzato!
    CHOKEPOINTS = {
        -- Mid Lane River Ramps
        { pos = Vector(-820, -680, 128),  axis = Vector(0.707, 0.707, 0), width = 260, name = "Radiant Mid Ramp" },
        { pos = Vector( 280,  220, 128),  axis = Vector(0.707, 0.707, 0), width = 260, name = "Dire Mid Ramp" },
        -- Highground T3 Gates (Radiant)
        { pos = Vector(-6050, -3450, 256), axis = Vector(0.0, 1.0, 0),    width = 240, name = "Radiant Top T3 Gate" },
        { pos = Vector(-4350, -3850, 256), axis = Vector(0.707, 0.707, 0),width = 240, name = "Radiant Mid T3 Gate" },
        { pos = Vector(-3950, -6050, 256), axis = Vector(1.0, 0.0, 0),    width = 240, name = "Radiant Bot T3 Gate" },
        -- Highground T3 Gates (Dire)
        { pos = Vector( 3950,  5850, 256), axis = Vector(-1.0, 0.0, 0),   width = 240, name = "Dire Top T3 Gate" },
        { pos = Vector( 3850,  3400, 256), axis = Vector(-0.707,-0.707,0),width = 240, name = "Dire Mid T3 Gate" },
        { pos = Vector( 6150,  3350, 256), axis = Vector(0.0, -1.0, 0),   width = 240, name = "Dire Bot T3 Gate" },
        -- River & Triangle Stairs
        { pos = Vector(-2250,   450, 128), axis = Vector(-0.5, -0.86, 0), width = 220, name = "Radiant Triangle Stairs" },
        { pos = Vector(-1350, -2350, 128), axis = Vector(0.5, -0.86, 0),  width = 220, name = "Radiant Mid-Jungle Stairs" },
        { pos = Vector( 1850,  -850, 128), axis = Vector(0.5, 0.86, 0),   width = 220, name = "Dire Triangle Stairs" },
        { pos = Vector(  950,  2150, 128), axis = Vector(-0.5, 0.86, 0),  width = 220, name = "Dire Mid-Jungle Stairs" },
        -- Roshan Pits / Corner Portals
        { pos = Vector(-4200,  1900, 128), axis = Vector(0.707, -0.707,0),width = 250, name = "NW Roshan / River Ramp" },
        { pos = Vector( 4000, -1900, 128), axis = Vector(-0.707, 0.707,0),width = 250, name = "SE Roshan / River Ramp" },
    },

    -- Posizioni standard di fallback delle Torri (usate se le torri sono in Fog o prima della scansione)
    FALLBACK_TOWERS = {
        [2] = { -- Radiant (Team 2)
            Vector(-6250,  1800, 128), Vector(-6250, -1500, 128), Vector(-6200, -3550, 256), -- Top T1, T2, T3
            Vector(-1550, -1400, 128), Vector(-3350, -2800, 128), Vector(-4450, -3950, 256), -- Mid T1, T2, T3
            Vector( 4850, -6050, 128), Vector( -500, -6100, 128), Vector(-4050, -6050, 256), -- Bot T1, T2, T3
            Vector(-5450, -4950, 256), -- T4
        },
        [3] = { -- Dire (Team 3)
            Vector(-4650,  6000, 128), Vector(  100,  6050, 128), Vector( 4050,  5900, 256), -- Top T1, T2, T3
            Vector(  950,   800, 128), Vector( 2450,  2100, 128), Vector( 3950,  3500, 256), -- Mid T1, T2, T3
            Vector( 6250, -1650, 128), Vector( 6250,  1400, 128), Vector( 6200,  3450, 256), -- Bot T1, T2, T3
            Vector( 5150,  4650, 256), -- T4
        }
    }
}

-- Modificatori a durata fissa che rendono un bersaglio temporaneamente immobile/bandito
-- ma vulnerabile nell'esatto istante in cui il modificatore termina!
local TIMED_IMMOBILE_MODIFIERS = {
    ["modifier_eul_cyclone"] = true,
    ["modifier_wind_waker"] = true,
    ["modifier_obsidian_destroyer_astral_imprisonment_prison"] = true,
    ["modifier_shadow_demon_disruption"] = true,
    ["modifier_puck_phase_shift"] = true,
    ["modifier_Teleporting"] = true,
    ["modifier_fountain_teleport"] = true,
}

-- Modificatori che garantiscono movimento libero attraverso alberi o scogliere
local FREE_PATHING_MODIFIERS = {
    "modifier_batrider_firefly",
    "modifier_winter_wyvern_arctic_burn_flight",
    "modifier_broodmother_spin_web",
    "modifier_dark_seer_surge",
    "modifier_item_spider_legs_active",
    "modifier_night_stalker_dark_ascension",
    "modifier_nyx_assassin_burrow",
    "modifier_spectre_spectral_dagger_path",
}

-- =============================================================================
-- STATO INTERNO E TRACKING GLOBALE
-- =============================================================================
local hero_trackers = {}       -- [entity_index] -> dati cinematici e comportamentali
local cached_towers = { [2] = {}, [3] = {}, last_scan = 0 }
local cached_trees = { list = {}, last_scan = 0 }

-- Sessione di mira attiva (Mouse 4 o Mouse 3 premuto)
local aim_session = {
    active = false,
    mode = nil,                -- "ENEMY" o "ALLY"
    start_time = 0,            -- Timestamp inizio pressione (finestra max 3.0s)
    locked_target = nil,       -- Entità eroe agganciata dal cursore
    best_aim_pos = nil,        -- Miglior punto di mira 3D calcolato nel frame corrente
    best_confidence = 0,       -- Confidenza (0..100%)
    best_intent = "IDLE",      -- Intenzione corrente ("FARMING", "RETREATING", ecc.)
    best_path = {},            -- Punti del pathfinding simulato per il rendering
    is_blocked = false,        -- Vero se c'è un creep/ostacolo inevitabile
    block_reason = "",         -- Motivo eventuale blocco
    peak_confidence = 0,       -- Picco di confidenza osservato nella finestra corrente
    last_cast_order_time = 0,  -- Debounce invio ordine CastPosition
}

-- Stato del gancio attualmente in fase di animazione (Cast Point 0.3s) per Stop-Cancel & Logging
local active_hook_cast = {
    in_phase = false,
    start_time = 0,
    cast_point = 0.30,
    origin_pos = nil,
    aim_pos = nil,
    dir_x = 0,
    dir_y = 0,
    target = nil,
    launch_speed = 0,
    is_ally_mode = false,
    is_manual = false,           -- True se il gancio è stato lanciato manualmente dal giocatore (premendo Q)
    is_script_cast = false,      -- True solo se il gancio è stato ordinato automaticamente dall'AI
    confidence = 0,
    intent = "UNKNOWN",
    wait_time = 0,
    edge_reason = "CLEAR",
    last_cancel_time = 0,
}

-- Stato dell'ordine AI inviato (mentre Pudge sta ancora ruotando prima che inizi AbilityPhase)
local pending_script_cast = {
    active = false,
    order_time = 0,
    aim_pos = nil,
    target = nil,
    launch_speed = 0,
    is_ally_mode = false,
    confidence = 0,
    intent = "UNKNOWN",
    wait_time = 0,
    edge_reason = "CLEAR",
}

local manual_q_pressed_time = 0      -- Timestamp ultima pressione tasto Q manuale
local script_cast_order_active = false -- Flag temporaneo impostato durante Ability.CastPosition dell'AI

-- Statistiche cumulative sessione per logspudge.md
local hook_stats = {
    event_seq = 0,
    total_fired = 0,
    hits = 0,
    misses = 0,
    stop_cancels = 0,
}

-- Stato del gancio attualmente in volo (per analisi Post-Mortem di Successo / Fallimento in logspudge.md)
local in_flight_hook = {
    active = false,
    hook_id = 0,
    launch_time = 0,
    pudge_pos = nil,
    aim_pos = nil,
    dir_x = 0,
    dir_y = 0,
    max_range = 1300,
    hook_speed = 1450,
    hook_width = 115,
    target = nil,
    target_name = "Unknown",
    is_ally_mode = false,
    is_manual = false,
    confidence = 0,
    intent = "UNKNOWN",
    wait_time = 0,
    edge_reason = "CLEAR",
    target_launch_pos = nil,
    target_launch_speed = 0,
    target_launch_angle = 0,
    target_launch_reversals = 0,
    pred_dist = 0,
    expected_tof = 0,
    expected_impact_time = 0,
    min_dist_to_target = 999999,
    closest_hook_pos = nil,
    target_pos_at_closest = nil,
    target_speed_at_closest = 0,
    target_angle_at_closest = 0,
    max_angle_change_deg = 0,
    max_speed_delta = 0,
    stopped_unexpectedly = false,
    started_from_idle = false,
    hit_unit = nil,
    hit_pos = nil,
    hit_time = 0,
}

-- Stato dinamico dei Keybind (supporta cambio tasto In-Game da Menu e da HUD Bar cliccabile)
local keybind_state = {
    enemy_override = nil,          -- Keycode personalizzato assegnato con Live Rebind (nil = usa Menu:Bind)
    ally_override = nil,           -- Keycode personalizzato assegnato con Live Rebind (nil = usa Menu:Bind)
    last_widget_enemy = KEY_CODE_MOUSE4,
    last_widget_ally = KEY_CODE_MOUSE3,
    rebinding_target = nil,        -- nil | "ENEMY" | "ALLY"
    rebind_start_time = 0,         -- Timestamp inizio ascolto nuovo tasto
    down_keys = {},                -- Tracciamento eventi OnKeyEvent per qualunque keycode
    last_left_click = false,       -- Edge detector per click sinistro sulla barra HUD In-Game
}

local draw_font = nil
local draw_font_bold = nil

-- =============================================================================
-- FUNZIONI MATEMATICHE E VETTORIALI DI BASE
-- =============================================================================
local function dist_2d(v1, v2)
    if not v1 or not v2 then return 999999 end
    local dx = v1.x - v2.x
    local dy = v1.y - v2.y
    return math.sqrt(dx * dx + dy * dy)
end

local function dist_2d_sq(v1, v2)
    if not v1 or not v2 then return 999999999 end
    local dx = v1.x - v2.x
    local dy = v1.y - v2.y
    return dx * dx + dy * dy
end

local function normalize_2d(dx, dy)
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 1e-5 then return 0, 0, 0 end
    return dx / len, dy / len, len
end

local function rotate_2d(dx, dy, angle_rad)
    local c = math.cos(angle_rad)
    local s = math.sin(angle_rad)
    return dx * c - dy * s, dx * s + dy * c
end

local function angle_diff_rad(a1, a2)
    local diff = (a2 - a1 + math.pi) % (2 * math.pi) - math.pi
    return diff
end

local function clamp(val, min_v, max_v)
    if val < min_v then return min_v end
    if val > max_v then return max_v end
    return val
end

--- Calcola la distanza perpendicolare e la proiezione scalare di un punto `P`
--- rispetto al segmento orientato `Origin -> Origin + Dir * MaxDist`
--- @return number proj_s Distanza lungo il raggio (negativa se dietro l'origine)
--- @return number perp_dist Distanza perpendicolare dal raggio
--- @return number closest_x
--- @return number closest_y
local function point_to_ray_2d(px, py, ox, oy, dir_x, dir_y)
    local wx = px - ox
    local wy = py - oy
    local proj_s = wx * dir_x + wy * dir_y
    local closest_x = ox + proj_s * dir_x
    local closest_y = oy + proj_s * dir_y
    local dx = px - closest_x
    local dy = py - closest_y
    local perp_dist = math.sqrt(dx * dx + dy * dy)
    return proj_s, perp_dist, closest_x, closest_y
end

--- Distanza minima tra due segmenti 2D o punto-segmento per capsule di movimento
local function point_to_segment_dist_2d(px, py, ax, ay, bx, by)
    local abx = bx - ax
    local aby = by - ay
    local apx = px - ax
    local apy = py - ay
    local ab_len_sq = abx * abx + aby * aby
    if ab_len_sq < 1e-4 then
        return math.sqrt(apx * apx + apy * apy), 0
    end
    local t = clamp((apx * abx + apy * aby) / ab_len_sq, 0.0, 1.0)
    local cx = ax + t * abx
    local cy = ay + t * aby
    local dx = px - cx
    local dy = py - cy
    return math.sqrt(dx * dx + dy * dy), t
end

-- =============================================================================
-- HELPER ENGINE, INPUT E VALIDAZIONE ENTITÀ
-- =============================================================================
local function get_time()
    if GameRules and GameRules.GetGameTime then
        local ok, gt = pcall(GameRules.GetGameTime)
        if ok and type(gt) == "number" and gt > 0 then
            return gt
        end
    end
    return os.clock()
end

local function is_valid_entity(ent)
    if not ent then return false end
    if not Entity.IsAlive(ent) or Entity.IsDormant(ent) then return false end
    return true
end

local function get_unit_forward_2d(unit)
    if not unit then return 1, 0, 0 end
    local rot = Entity.GetRotation(unit)
    if rot and rot.GetForward then
        local ok, fwd = pcall(function() return rot:GetForward() end)
        if ok and fwd then
            local nx, ny = normalize_2d(fwd.x, fwd.y)
            if nx ~= 0 or ny ~= 0 then
                return nx, ny, math.atan(ny, nx)
            end
        end
    end
    return 1, 0, 0
end

local function notify_user(msg)
    if not ui.notify:Get() then return end
    print(msg)
    pcall(function()
        if Chat and Chat.Print then
            Chat.Print("ConsoleChat", msg)
        end
    end)
end

--- Converte un codice ButtonCode_t (Source 2 / Umbrella) in nome leggibile per HUD e notifiche
local SPECIAL_KEY_NAMES = {
    [1] = "0", [2] = "1", [3] = "2", [4] = "3", [5] = "4",
    [6] = "5", [7] = "6", [8] = "7", [9] = "8", [10] = "9",
    [65] = "SPACE", [66] = "BACKSPACE", [67] = "TAB", [68] = "CAPSLOCK",
    [70] = "ESC", [79] = "LSHIFT", [80] = "RSHIFT", [81] = "LALT",
    [82] = "RALT", [83] = "LCTRL", [84] = "RCTRL",
    [314] = "MOUSE 1", [315] = "MOUSE 2", [316] = "MOUSE 3",
    [317] = "MOUSE 4", [318] = "MOUSE 5", [319] = "MWHEEL UP", [320] = "MWHEEL DN",
}

local function get_key_display_name(code)
    if not code or type(code) ~= "number" or code <= 0 then return "NONE" end
    if SPECIAL_KEY_NAMES[code] then return SPECIAL_KEY_NAMES[code] end
    if code >= 11 and code <= 36 then
        return string.char(65 + (code - 11)) -- A..Z
    end
    if code >= 37 and code <= 46 then
        return "NUM " .. tostring(code - 37)
    end
    if code >= 92 and code <= 103 then
        return "F" .. tostring(code - 91) -- F1..F12
    end
    if code == KEY_CODE_MOUSE4 then return "MOUSE 4" end
    if code == KEY_CODE_MOUSE3 then return "MOUSE 3" end
    return "KEY " .. tostring(code)
end

--- Estrae il keycode numerico corrente da un widget `Menu:Bind`
local function extract_widget_keycode(bind_widget, default_code)
    if bind_widget then
        local ok, val = pcall(function() return bind_widget:Get() end)
        if ok then
            if type(val) == "number" and val > 0 then
                return val
            elseif type(val) == "table" and type(val[1]) == "number" and val[1] > 0 then
                return val[1]
            end
        end
    end
    return default_code
end

--- Restituisce il keycode attivo per Gancio Nemico (`is_enemy = true`) o Gancio Alleato (`is_enemy = false`)
local function get_active_keycode(is_enemy)
    if is_enemy then
        local w_code = extract_widget_keycode(ui.enemy_key, KEY_CODE_MOUSE4)
        if w_code ~= keybind_state.last_widget_enemy then
            keybind_state.last_widget_enemy = w_code
            keybind_state.enemy_override = nil
        end
        return keybind_state.enemy_override or w_code
    else
        local w_code = extract_widget_keycode(ui.ally_key, KEY_CODE_MOUSE3)
        if w_code ~= keybind_state.last_widget_ally then
            keybind_state.last_widget_ally = w_code
            keybind_state.ally_override = nil
        end
        return keybind_state.ally_override or w_code
    end
end

--- Applica un nuovo tasto catturato dal Live Rebind In-Game
local function apply_live_rebind_key(target_mode, new_code)
    if target_mode == "ENEMY" then
        keybind_state.enemy_override = new_code
        pcall(function() if ui.enemy_key.Set then ui.enemy_key:Set(new_code) end end)
        keybind_state.last_widget_enemy = extract_widget_keycode(ui.enemy_key, KEY_CODE_MOUSE4)
        pcall(function() ui.rebind_enemy_live:Set(false) end)
        notify_user(string.format("[PudgeHook AI] Nuovo tasto ENEMY HOOK impostato in-game: [%s] (Code %d)", get_key_display_name(new_code), new_code))
    elseif target_mode == "ALLY" then
        keybind_state.ally_override = new_code
        pcall(function() if ui.ally_key.Set then ui.ally_key:Set(new_code) end end)
        keybind_state.last_widget_ally = extract_widget_keycode(ui.ally_key, KEY_CODE_MOUSE3)
        pcall(function() ui.rebind_ally_live:Set(false) end)
        notify_user(string.format("[PudgeHook AI] Nuovo tasto ALLY HOOK impostato in-game: [%s] (Code %d)", get_key_display_name(new_code), new_code))
    end
    keybind_state.rebinding_target = nil
end

-- Callbacks per gli switch di Live Rebind e Reset nel Menu
ui.rebind_enemy_live:SetCallback(function(self)
    if self:Get() then
        pcall(function() ui.rebind_ally_live:Set(false) end)
        keybind_state.rebinding_target = "ENEMY"
        keybind_state.rebind_start_time = get_time()
        notify_user("[PudgeHook AI] LIVE REBIND ENEMY: Premi ora qualsiasi tasto o pulsante del mouse (ESC per annullare)...")
    elseif keybind_state.rebinding_target == "ENEMY" then
        keybind_state.rebinding_target = nil
    end
end)

ui.rebind_ally_live:SetCallback(function(self)
    if self:Get() then
        pcall(function() ui.rebind_enemy_live:Set(false) end)
        keybind_state.rebinding_target = "ALLY"
        keybind_state.rebind_start_time = get_time()
        notify_user("[PudgeHook AI] LIVE REBIND ALLY: Premi ora qualsiasi tasto o pulsante del mouse (ESC per annullare)...")
    elseif keybind_state.rebinding_target == "ALLY" then
        keybind_state.rebinding_target = nil
    end
end)

ui.reset_keys:SetCallback(function(self)
    if self:Get() then
        keybind_state.enemy_override = KEY_CODE_MOUSE4
        keybind_state.ally_override = KEY_CODE_MOUSE3
        keybind_state.rebinding_target = nil
        pcall(function() if ui.enemy_key.Set then ui.enemy_key:Set(KEY_CODE_MOUSE4) end end)
        pcall(function() if ui.ally_key.Set then ui.ally_key:Set(KEY_CODE_MOUSE3) end end)
        pcall(function() ui.rebind_enemy_live:Set(false) end)
        pcall(function() ui.rebind_ally_live:Set(false) end)
        pcall(function() self:Set(false) end)
        notify_user("[PudgeHook AI] Keybind ripristinati ai valori predefiniti: Enemy = [MOUSE 4] | Ally = [MOUSE 3]")
    end
end)

--- Verifica dinamica se il tasto configurato per Gancio Nemico o Gancio Alleato è tenuto premuto
local function is_bind_or_mouse_held(bind_widget, is_enemy)
    if keybind_state.rebinding_target then return false end

    local active_code = get_active_keycode(is_enemy)
    local has_custom_override = is_enemy and (keybind_state.enemy_override ~= nil) or (not is_enemy and keybind_state.ally_override ~= nil)

    -- 1. Se non c'è un override Live Rebind diverso dal widget, controlla anche bind_widget:IsDown()
    if bind_widget and not has_custom_override then
        local ok_down, is_down = pcall(function() return bind_widget:IsDown() end)
        if ok_down and type(is_down) == "boolean" and is_down then
            return true
        end
        local ok_press, is_pressed = pcall(function() return bind_widget:IsPressed() end)
        if ok_press and type(is_pressed) == "boolean" and is_pressed then
            return true
        end
    end

    -- 2. Controlla Input.IsKeyDown sul keycode attivo (qualsiasi tasto tastiera o mouse scelto in-game!)
    if active_code and active_code > 0 and Input and Input.IsKeyDown then
        local ok_k, kd = pcall(Input.IsKeyDown, active_code)
        if ok_k and kd then return true end

        -- Alias enum aggiuntivi se il tasto attivo è Mouse 4 (317) o Mouse 3 (316)
        if active_code == 317 or active_code == KEY_CODE_MOUSE4 then
            local codes = { 317, KEY_CODE_MOUSE4 }
            if Enum and Enum.ButtonCode then
                if Enum.ButtonCode.KEY_MOUSE4 then table.insert(codes, Enum.ButtonCode.KEY_MOUSE4) end
                if Enum.ButtonCode.KEY_MOUSE_4 then table.insert(codes, Enum.ButtonCode.KEY_MOUSE_4) end
                if Enum.ButtonCode.MOUSE_4 then table.insert(codes, Enum.ButtonCode.MOUSE_4) end
            end
            for _, c in ipairs(codes) do
                local ok, down = pcall(Input.IsKeyDown, c)
                if ok and down then return true end
            end
        elseif active_code == 316 or active_code == KEY_CODE_MOUSE3 then
            local codes = { 316, KEY_CODE_MOUSE3 }
            if Enum and Enum.ButtonCode then
                if Enum.ButtonCode.KEY_MOUSE3 then table.insert(codes, Enum.ButtonCode.KEY_MOUSE3) end
                if Enum.ButtonCode.KEY_MOUSE_3 then table.insert(codes, Enum.ButtonCode.KEY_MOUSE_3) end
                if Enum.ButtonCode.MOUSE_3 then table.insert(codes, Enum.ButtonCode.MOUSE_3) end
                if Enum.ButtonCode.MOUSE_MIDDLE then table.insert(codes, Enum.ButtonCode.MOUSE_MIDDLE) end
            end
            for _, c in ipairs(codes) do
                local ok, down = pcall(Input.IsKeyDown, c)
                if ok and down then return true end
            end
        end
    end

    -- 3. Fallback da OnKeyEvent per il keycode attivo
    if active_code and keybind_state.down_keys[active_code] then
        return true
    end

    return false
end

--- Ottiene i parametri reali correnti di Meat Hook (Range con Flayer's Hook/Aether Lens, Speed, Width, CastPoint)
local function get_hook_parameters(my_hero, hook_ab)
    local speed = DEFAULT_HOOK_SPEED
    local width = DEFAULT_HOOK_WIDTH
    local cast_point = DEFAULT_CAST_POINT
    local cast_range = DEFAULT_CAST_RANGE

    if hook_ab then
        if Ability.GetLevelSpecialValueFor then
            local ok_s, s_val = pcall(Ability.GetLevelSpecialValueFor, hook_ab, "hook_speed")
            if ok_s and s_val and s_val > 100 then speed = s_val end

            local ok_w, w_val = pcall(Ability.GetLevelSpecialValueFor, hook_ab, "hook_width")
            if ok_w and w_val and w_val > 20 then width = w_val end

            local ok_r, r_val = pcall(Ability.GetLevelSpecialValueFor, hook_ab, "AbilityCastRange")
            if ok_r and r_val and r_val > 300 then cast_range = r_val end
        end

        if Ability.GetCastRange then
            local ok_cr, cr = pcall(Ability.GetCastRange, hook_ab)
            if ok_cr and cr and cr > cast_range then
                cast_range = cr
            end
        end

        if NPC and NPC.GetCastRangeBonus and my_hero then
            local ok_cb, bonus = pcall(NPC.GetCastRangeBonus, my_hero)
            if ok_cb and bonus and bonus > 0 and cast_range <= 1500 then
                -- Aggiunge bonus range (es. Aether Lens) se non già incluso in Ability.GetCastRange
                local raw_cr = (Ability.GetCastRange and Ability.GetCastRange(hook_ab)) or 0
                if raw_cr <= 1500 then
                    cast_range = math.max(cast_range, raw_cr + bonus)
                end
            end
        end

        if Ability.GetCastPoint then
            local ok_cp, cp = pcall(Ability.GetCastPoint, hook_ab)
            if ok_cp and cp and cp > 0 then cast_point = cp end
        end
    end

    return cast_range, speed, width, cast_point
end

--- Calcola il tempo esatto che Pudge impiega per ruotare verso `target_pos` prima che parta il Cast Point
local function calculate_pudge_turn_time(my_hero, target_pos)
    if not my_hero or not target_pos then return 0 end
    local my_pos = Entity.GetAbsOrigin(my_hero)
    if not my_pos then return 0 end

    -- Se Pudge possiede un effetto che ignora il turn rate o è già allineato
    local fx, fy = get_unit_forward_2d(my_hero)
    local tx, ty, dist = normalize_2d(target_pos.x - my_pos.x, target_pos.y - my_pos.y)
    if dist < 1 then return 0 end

    local dot = clamp(fx * tx + fy * ty, -1.0, 1.0)
    local angle_rad = math.acos(dot)

    -- In Dota 2 il cast inizia non appena l'eroe entra entro ~11.5 gradi (0.20 rad) dal punto bersaglio
    local tolerance_rad = 0.20
    if angle_rad <= tolerance_rad then
        return 0.0
    end

    local remaining_angle = angle_rad - tolerance_rad
    -- Formula ufficiale Source 2: turn_time = 0.033 * angle_rad / turn_rate
    return 0.033 * (remaining_angle / PUDGE_TURN_RATE)
end

-- =============================================================================
-- MODULO 1: TOPOLOGIA MAPPA, NAVMESH E PATHFINDING AVANZATO
-- =============================================================================

--- Aggiorna la lista delle torri vive in partita per determinare i punti reali di Retreat e Push
local function update_map_towers_cache(now)
    if now - cached_towers.last_scan < 1.5 then return end
    cached_towers.last_scan = now

    local t2 = {}
    local t3 = {}

    if NPCs and NPCs.GetAll then
        local ok, all_npcs = pcall(NPCs.GetAll)
        if ok and all_npcs then
            for _, npc in ipairs(all_npcs) do
                if npc and Entity.IsAlive(npc) then
                    local is_tower = false
                    if NPC.IsTower then
                        local ok_t, res_t = pcall(NPC.IsTower, npc)
                        is_tower = ok_t and res_t
                    end
                    if not is_tower then
                        local uname = (NPC.GetUnitName and NPC.GetUnitName(npc)) or ""
                        if string.find(uname, "tower", 1, true) then
                            is_tower = true
                        end
                    end
                    if is_tower then
                        local pos = Entity.GetAbsOrigin(npc)
                        local team = Entity.GetTeamNum(npc)
                        if pos then
                            if team == 2 then table.insert(t2, pos)
                            elseif team == 3 then table.insert(t3, pos) end
                        end
                    end
                end
            end
        end
    end

    cached_towers[2] = (#t2 > 0) and t2 or MAP_DATA.FALLBACK_TOWERS[2]
    cached_towers[3] = (#t3 > 0) and t3 or MAP_DATA.FALLBACK_TOWERS[3]
end

--- Trova la torre amica più vicina a una determinata unità (per calcolo vettore di Retreat/Push)
local function get_nearest_team_tower_or_fountain(pos, team_num)
    if not pos then return nil end
    local towers = cached_towers[team_num] or MAP_DATA.FALLBACK_TOWERS[team_num] or {}
    local fountain = (team_num == 2) and MAP_DATA.RADIANT_FOUNTAIN or MAP_DATA.DIRE_FOUNTAIN

    local best_pos = fountain
    local best_dist = dist_2d(pos, fountain)

    for _, t_pos in ipairs(towers) do
        local d = dist_2d(pos, t_pos)
        -- Consideriamo le torri che si trovano nella direzione della propria metà mappa / base
        if d < best_dist and d > 150 then
            best_dist = d
            best_pos = t_pos
        end
    end

    return best_pos, best_dist, fountain
end

--- Determina se un eroe ha free-pathing (volo o cammino sugli alberi/scogliere)
local function has_free_pathing(unit)
    if not unit then return false end
    if Enum and Enum.ModifierState and NPC.HasState then
        if NPC.HasState(unit, Enum.ModifierState.MODIFIER_STATE_FLYING) then return true end
        if Enum.ModifierState.MODIFIER_STATE_FLYING_FOR_PATHING_PURPOSES_ONLY and
           NPC.HasState(unit, Enum.ModifierState.MODIFIER_STATE_FLYING_FOR_PATHING_PURPOSES_ONLY) then
            return true
        end
    end
    for _, mod_name in ipairs(FREE_PATHING_MODIFIERS) do
        if NPC.HasModifier(unit, mod_name) then return true end
    end
    return false
end

--- Ottiene la quota Z del terreno in un punto (x, y) per rilevare scogliere (Cliffs) e Highground
local function get_ground_z(x, y, fallback_z)
    if World and World.GetGroundZ then
        local ok, z = pcall(World.GetGroundZ, x, y)
        if ok and type(z) == "number" then return z end
    end
    if GridNav and GridNav.GetZ then
        local ok, z = pcall(GridNav.GetZ, Vector(x, y, fallback_z or 128))
        if ok and type(z) == "number" then return z end
    end
    return fallback_z or 128
end

--- Controlla se un punto `(x, y)` vicino a `ref_pos` si trova su una rampa/scala nota della mappa
local function is_near_known_ramp(x, y)
    for _, cp in ipairs(MAP_DATA.CHOKEPOINTS) do
        local dx = x - cp.pos.x
        local dy = y - cp.pos.y
        if (dx * dx + dy * dy) <= (cp.width + 140) * (cp.width + 140) then
            return true, cp
        end
    end
    return false, nil
end

--- Verifica se il punto `(x, y)` è calpestabile da un eroe a terra tenendo conto di:
--- 1. Limiti della mappa di Dota 2
--- 2. GridNav.IsTraversable (se disponibile nell'engine)
--- 3. Alberi attivi (Trees.InRadius) che bloccano il pathing
--- 4. Scogliere / Cliffs (salti di quota Z > 95 unità fuori dalle rampe/scale)
local function is_point_walkable(x, y, prev_z, is_flying)
    if x < MAP_DATA.MAP_MIN_X or x > MAP_DATA.MAP_MAX_X or
       y < MAP_DATA.MAP_MIN_Y or y > MAP_DATA.MAP_MAX_Y then
        return false, prev_z or 128
    end

    if is_flying then
        return true, prev_z or 128
    end

    local test_vec = Vector(x, y, prev_z or 128)

    -- 1. Controllo GridNav nativo
    if GridNav and GridNav.IsTraversable then
        local ok, trav = pcall(GridNav.IsTraversable, test_vec)
        if ok and trav == false then
            return false, prev_z or 128
        end
    end

    -- 2. Controllo Alberi (raggio collisione reale albero+eroe ~46 unità; evita falsi rimbalzi camminando vicino agli alberi)
    if Trees and Trees.InRadius then
        local ok, nearby_trees = pcall(Trees.InRadius, test_vec, 46, true)
        if ok and nearby_trees and #nearby_trees > 0 then
            return false, prev_z or 128
        end
    end

    -- 3. Controllo Dislivello Scogliera (Cliff Detection: su un singolo passo di ~16 unità, un cliff ha salto Z > 115)
    local cur_z = get_ground_z(x, y, prev_z)
    if prev_z and math.abs(cur_z - prev_z) > 115 then
        local on_ramp = is_near_known_ramp(x, y)
        if not on_ramp then
            return false, cur_z
        end
    end

    return true, cur_z
end

--- Calcola un leggero fattore di allineamento topologico (applicato UNA SOLA VOLTA, mai accumulato ad ogni step!)
local function get_map_topological_flow(pos, desired_dir_x, desired_dir_y)
    if not pos then return desired_dir_x, desired_dir_y, 0 end

    -- 1. Se l'eroe si trova in un Chokepoint / Rampa / Scala ed è già orientato lungo la rampa
    local on_ramp, cp = is_near_known_ramp(pos.x, pos.y)
    if on_ramp and cp then
        local dot = desired_dir_x * cp.axis.x + desired_dir_y * cp.axis.y
        if math.abs(dot) > 0.84 then
            local sign = (dot >= 0) and 1.0 or -1.0
            local rx = cp.axis.x * sign
            local ry = cp.axis.y * sign
            -- Blend leggero (90% velocità reale + 10% asse rampa) per non deviare mai fuori bersaglio
            local bx, by = normalize_2d(desired_dir_x * 0.90 + rx * 0.10, desired_dir_y * 0.90 + ry * 0.10)
            return bx, by, 0.45 -- Bonus confinamento rampa
        end
        return desired_dir_x, desired_dir_y, 0.30
    end

    -- 2. Allineamento con i Waypoint delle 3 corsie (Top, Mid, Bot) solo se quasi collineare
    local best_lane_dist = 999999
    local best_seg_dx, best_seg_dy = 0, 0

    for _, waypoints in pairs(MAP_DATA.LANES) do
        for i = 1, #waypoints - 1 do
            local a = waypoints[i]
            local b = waypoints[i + 1]
            local d, _ = point_to_segment_dist_2d(pos.x, pos.y, a.x, a.y, b.x, b.y)
            if d < best_lane_dist then
                best_lane_dist = d
                best_seg_dx, best_seg_dy = normalize_2d(b.x - a.x, b.y - a.y)
            end
        end
    end

    if best_lane_dist <= 600 and (best_seg_dx ~= 0 or best_seg_dy ~= 0) then
        local dot = desired_dir_x * best_seg_dx + desired_dir_y * best_seg_dy
        if math.abs(dot) > 0.88 then
            local sign = (dot >= 0) and 1.0 or -1.0
            local lx = best_seg_dx * sign
            local ly = best_seg_dy * sign
            local bx, by = normalize_2d(desired_dir_x * 0.94 + lx * 0.06, desired_dir_y * 0.94 + ly * 0.06)
            return bx, by, 0.15
        end
    end

    return desired_dir_x, desired_dir_y, 0.0
end

--- Misura quanto il bersaglio è confinato lateralmente (corridoio tra alberi, scogliere o muri)
--- Restituisce un valore da `0.0` (campo aperto) a `1.0` (strettoia / juke path negli alberi)
--- e l'eventuale spinta laterale verso il centro del corridoio libero.
local function evaluate_corridor_confinement(x, y, z, dir_x, dir_y, is_flying)
    if is_flying then return 0.0, 0, 0 end

    -- Versore normale sinistro (-dir_y, dir_x) e destro (dir_y, -dir_x)
    local left_x, left_y = -dir_y, dir_x
    local right_x, right_y = dir_y, -dir_x

    local free_left = 210
    local free_right = 210

    for dist = 70, 210, 70 do
        local wl, _ = is_point_walkable(x + left_x * dist, y + left_y * dist, z, false)
        if not wl and dist < free_left then
            free_left = dist - 35
            break
        end
    end

    for dist = 70, 210, 70 do
        local wr, _ = is_point_walkable(x + right_x * dist, y + right_y * dist, z, false)
        if not wr and dist < free_right then
            free_right = dist - 35
            break
        end
    end

    local total_width = free_left + free_right
    local confinement = clamp((420 - total_width) / 320.0, 0.0, 1.0)

    local push_x, push_y = 0, 0
    if free_left < 65 and free_right > 130 then
        push_x, push_y = right_x * 10, right_y * 10
    elseif free_right < 65 and free_left > 130 then
        push_x, push_y = left_x * 10, left_y * 10
    end

    return confinement, push_x, push_y
end

-- =============================================================================
-- MODULO 2: TRACKING CINEMATICO SINCRONO & MOTORE DELLE INTENZIONI
-- =============================================================================

--- Aggiorna ad ogni tick lo stato cinematico di tutti gli eroi visibili.
--- Integra in modo sincrono `NPC.IsRunning(hero)` per azzerare istantaneamente:
--- • l'errore di `OVERSHOOT_TARGET_STOPPED` (quando l'eroe si ferma, `speed` va subito a 0 senza lag EMA!)
--- • l'errore di `UNDERSHOOT_STARTED_FROM_IDLE` (quando l'eroe parte da fermo, `speed` prende subito `GetMoveSpeed`!)
local function update_hero_kinematics(now)
    if not Heroes or not Heroes.GetAll then return end
    local my_hero = Heroes.GetLocal()
    if not my_hero then return end

    for _, hero in ipairs(Heroes.GetAll()) do
        if hero and hero ~= my_hero then
            local idx = Entity.GetIndex(hero)
            if idx then
                if not Entity.IsAlive(hero) or Entity.IsDormant(hero) or not NPC.IsVisible(hero) then
                    if hero_trackers[idx] then
                        hero_trackers[idx].visible = false
                    end
                else
                    local pos = Entity.GetAbsOrigin(hero)
                    local hp = Entity.GetHealth(hero)
                    local fx, fy, yaw = get_unit_forward_2d(hero)
                    local is_moving = (NPC.IsRunning and NPC.IsRunning(hero)) and true or false
                    local move_speed = (NPC.GetMoveSpeed and NPC.GetMoveSpeed(hero)) or 300

                    local tr = hero_trackers[idx]
                    if not tr or not tr.visible or (now - tr.last_update > 0.5) then
                        tr = {
                            unit = hero,
                            visible = true,
                            first_seen = now,
                            last_update = now,
                            pos = pos,
                            prev_pos = pos,
                            is_moving = is_moving,
                            was_moving = is_moving,
                            vel_x = is_moving and (fx * move_speed) or 0,
                            vel_y = is_moving and (fy * move_speed) or 0,
                            smooth_vx = is_moving and (fx * move_speed) or 0,
                            smooth_vy = is_moving and (fy * move_speed) or 0,
                            speed = is_moving and move_speed or 0,
                            move_angle = yaw,
                            yaw = yaw,
                            angular_vel = 0,
                            vel_angular_rate = 0,
                            is_turning_body = false,
                            move_stability_time = 0.15,
                            stationary_time = is_moving and 0 or 0.15,
                            just_stopped_time = 0,
                            just_started_time = 0,
                            juke_reversals = 0,
                            direction_changes = {},
                            history = {},
                            last_hp = hp,
                            last_damage_time = 0,
                            anim_lock_until = 0,
                            anim_type = nil,
                            intent = "IDLE",
                            intent_target_pos = nil,
                        }
                        hero_trackers[idx] = tr
                    else
                        local dt = now - tr.last_update
                        if dt >= 0.015 then
                            local dx = pos.x - tr.pos.x
                            local dy = pos.y - tr.pos.y
                            local raw_vx = dx / dt
                            local raw_vy = dy / dt
                            local raw_speed = math.sqrt(raw_vx * raw_vx + raw_vy * raw_vy)

                            -- Filtro anti-teletrasporto (es. Blink Dagger > 1800 speed istantanea)
                            if raw_speed > 2000 then
                                tr.smooth_vx = 0
                                tr.smooth_vy = 0
                                tr.speed = 0
                                tr.move_stability_time = 0
                                tr.stationary_time = 0
                                tr.history = {}
                            else
                                local prev_nx, prev_ny, prev_spd = normalize_2d(tr.smooth_vx, tr.smooth_vy)
                                local prev_move_angle = tr.move_angle or yaw

                                if not is_moving and raw_speed < 85 then
                                    -- CASO A: L'EROE È FERMO IN QUESTO TICK (NPC.IsRunning == false)
                                    -- Azzeramento IMMEDIATO della velocità per evitare qualsiasi Overshoot!
                                    tr.vel_x = 0
                                    tr.vel_y = 0
                                    tr.smooth_vx = 0
                                    tr.smooth_vy = 0
                                    tr.speed = 0
                                    tr.vel_angular_rate = 0
                                    tr.is_turning_body = false

                                    if tr.was_moving then
                                        -- Si è appena fermato in questo istante!
                                        tr.stationary_time = 0
                                        tr.move_stability_time = 0
                                        tr.just_stopped_time = now
                                    else
                                        tr.stationary_time = tr.stationary_time + dt
                                        tr.move_stability_time = tr.move_stability_time + dt
                                    end
                                else
                                    -- CASO B: L'EROE È IN MOVIMENTO (NPC.IsRunning == true)
                                    tr.stationary_time = 0

                                    -- Direzione misurata dallo spostamento reale o dal facing se appena partito
                                    local dir_rx, dir_ry = fx, fy
                                    if raw_speed >= 45 then
                                        dir_rx, dir_ry = normalize_2d(raw_vx, raw_vy)
                                    end

                                    if not tr.was_moving then
                                        -- È appena partito da fermo! Inizializza subito a move_speed (zero Undershoot!)
                                        tr.vel_x = dir_rx * move_speed
                                        tr.vel_y = dir_ry * move_speed
                                        tr.smooth_vx = tr.vel_x
                                        tr.smooth_vy = tr.vel_y
                                        tr.speed = move_speed
                                        tr.move_stability_time = 0
                                        tr.just_started_time = now
                                        tr.vel_angular_rate = 0
                                    else
                                        -- Era già in movimento: aggiorna direzione con filtro rapido e ancora il modulo a move_speed
                                        local alpha = clamp(dt / 0.055, 0.45, 0.90)
                                        local target_spd = (raw_speed > move_speed * 0.55) and move_speed or math.max(raw_speed, move_speed * 0.85)
                                        local target_vx = dir_rx * target_spd
                                        local target_vy = dir_ry * target_spd

                                        tr.vel_x = raw_vx
                                        tr.vel_y = raw_vy
                                        tr.smooth_vx = tr.smooth_vx * (1 - alpha) + target_vx * alpha
                                        tr.smooth_vy = tr.smooth_vy * (1 - alpha) + target_vy * alpha

                                        local snx, sny, s_spd = normalize_2d(tr.smooth_vx, tr.smooth_vy)
                                        if s_spd > 40 then
                                            -- Mantiene la velocità allineata alla vera MoveSpeed dell'eroe senza lag EMA sul modulo
                                            tr.speed = clamp(s_spd, move_speed * 0.85, move_speed * 1.05)
                                            tr.smooth_vx = snx * tr.speed
                                            tr.smooth_vy = sny * tr.speed
                                        else
                                            tr.speed = s_spd
                                        end
                                    end

                                    local cur_nx, cur_ny, cur_spd = normalize_2d(tr.smooth_vx, tr.smooth_vy)
                                    local cur_move_angle = (cur_spd > 20) and math.atan(cur_ny, cur_nx) or yaw
                                    tr.move_angle = cur_move_angle

                                    -- Velocità angolare della TRAIETTORIA di movimento (NON del modello 3D!)
                                    if prev_spd > 80 and cur_spd > 80 then
                                        local d_move_ang = angle_diff_rad(prev_move_angle, cur_move_angle)
                                        local raw_vel_omega = d_move_ang / dt
                                        tr.vel_angular_rate = tr.vel_angular_rate * 0.5 + clamp(raw_vel_omega, -4.0, 4.0) * 0.5

                                        local dot = prev_nx * cur_nx + prev_ny * cur_ny
                                        if dot < 0.76 then -- Cambio di direzione > ~40 gradi
                                            table.insert(tr.direction_changes, now)
                                            tr.move_stability_time = 0.0
                                        else
                                            tr.move_stability_time = tr.move_stability_time + dt
                                        end
                                    else
                                        tr.vel_angular_rate = 0
                                    end

                                    -- Rileva se il modello 3D si sta già girando verso una nuova direzione cliccata (> 38° di scarto)
                                    local face_vel_dot = fx * cur_nx + fy * cur_ny
                                    if face_vel_dot < 0.78 then
                                        tr.is_turning_body = true
                                        tr.move_stability_time = math.min(tr.move_stability_time, 0.05)
                                    else
                                        tr.is_turning_body = false
                                    end
                                end

                                -- Velocità angolare del modello 3D (solo diagnostica)
                                local d_yaw = angle_diff_rad(tr.yaw, yaw)
                                tr.angular_vel = tr.angular_vel * 0.6 + clamp(d_yaw / dt, -8.0, 8.0) * 0.4
                                tr.was_moving = is_moving
                                tr.is_moving = is_moving
                            end

                            -- Pulizia finestra cambi di direzione (ultimi 0.95 secondi)
                            for i = #tr.direction_changes, 1, -1 do
                                if now - tr.direction_changes[i] > 0.95 then
                                    table.remove(tr.direction_changes, i)
                                end
                            end
                            tr.juke_reversals = #tr.direction_changes

                            -- Tracciamento danni subiti (HP loss)
                            if hp < tr.last_hp then
                                tr.last_damage_time = now
                            end
                            tr.last_hp = hp

                            -- Aggiorna buffer storico (ultimi 0.8s)
                            table.insert(tr.history, { t = now, pos = pos, vx = tr.smooth_vx, vy = tr.smooth_vy })
                            while #tr.history > 24 or (#tr.history > 1 and (now - tr.history[1].t > 0.80)) do
                                table.remove(tr.history, 1)
                            end

                            tr.prev_pos = tr.pos
                            tr.pos = pos
                            tr.yaw = yaw
                            tr.last_update = now
                        end
                    end
                end
            end
        end
    end
end

--- Controlla se il bersaglio è sotto un effetto a tempo fisso (Eul, Astral, Disruption, TP, Phase Shift)
--- Restituisce `is_timed, remaining_duration, mod_name`
local function check_timed_immobile_state(unit)
    if not unit then return false, 0, nil end

    for mod_name, _ in pairs(TIMED_IMMOBILE_MODIFIERS) do
        if NPC.HasModifier(unit, mod_name) then
            local mod = NPC.GetModifier(unit, mod_name)
            if mod and Modifier and Modifier.GetRemainingTime then
                local ok, rem = pcall(Modifier.GetRemainingTime, mod)
                if ok and rem and rem > 0 then
                    return true, rem, mod_name
                end
            end
        end
    end

    return false, 0, nil
end

--- Controlla se l'unità è stunnata, radicata, in canalizzazione o bloccata sul posto
--- Restituisce `is_locked, lock_duration, lock_reason, is_hard_disable`
local function check_hard_disable_or_channel(unit, tr, now)
    if not unit then return false, 0, nil, false end

    -- 1. Canalizzazione attiva (TP Scroll, Black Hole, Shackles, Death Ward, ecc.)
    if NPC.IsChannellingAbility and NPC.IsChannellingAbility(unit) then
        return true, 1.5, "CHANNELING", true
    end

    -- 2. Stun o Root o Hex/Sleep/Taunt con calcolo della durata residua
    if Enum and Enum.ModifierState and NPC.HasState then
        local is_disabled = NPC.HasState(unit, Enum.ModifierState.MODIFIER_STATE_STUNNED)
            or NPC.HasState(unit, Enum.ModifierState.MODIFIER_STATE_ROOTED)
            or NPC.HasState(unit, Enum.ModifierState.MODIFIER_STATE_NIGHTMARED)
            or (Enum.ModifierState.MODIFIER_STATE_TAUNTED and NPC.HasState(unit, Enum.ModifierState.MODIFIER_STATE_TAUNTED))

        if is_disabled then
            local max_rem = 0.45
            if NPC.GetModifiers then
                local ok, mods = pcall(NPC.GetModifiers, unit)
                if ok and mods then
                    for _, m in ipairs(mods) do
                        if Modifier and Modifier.GetRemainingTime then
                            local ok_r, r = pcall(Modifier.GetRemainingTime, m)
                            if ok_r and r and r > max_rem and r < 10.0 then
                                max_rem = r
                            end
                        end
                    end
                end
            end
            return true, max_rem, "STUNNED/ROOTED", true
        end
    end

    -- 3. Fase di cast di un'abilità dell'eroe (AbilityPhase)
    for i = 0, 5 do
        local ab = NPC.GetAbilityByIndex and NPC.GetAbilityByIndex(unit, i)
        if ab and Ability.IsInAbilityPhase and Ability.IsInAbilityPhase(ab) then
            local cp = (Ability.GetCastPoint and Ability.GetCastPoint(ab)) or 0.30
            return true, math.max(0.18, cp), "CASTING_SPELL", false
        end
    end

    -- 4. Animazione di attacco / cast catturata da OnUnitAnimation (solo se l'eroe non sta già correndo!)
    if tr and not tr.is_moving and tr.anim_lock_until and tr.anim_lock_until > now then
        return true, tr.anim_lock_until - now, tr.anim_type or "ATTACK_ANIM", false
    end

    return false, 0, nil, false
end

--- Analizza in profondità l'intenzione comportamentale dell'eroe (`analyze_hero_intent`)
local function analyze_hero_intent(target, tr, my_hero, now, est_intercept_time)
    if not target or not tr then
        return "ROAMING", nil, 0, 0
    end

    local t_pos = tr.pos or Entity.GetAbsOrigin(target)
    local t_team = Entity.GetTeamNum(target)
    local my_pos = Entity.GetAbsOrigin(my_hero)
    local fx, fy = get_unit_forward_2d(target)
    local vx, vy, spd = normalize_2d(tr.smooth_vx, tr.smooth_vy)
    if spd < 25 then
        vx, vy = fx, fy
    end

    local intercept_t = est_intercept_time or 0.75

    -- 1. Controllo Setup Cronometrato (Eul / Astral / Disruption / TP)
    if ui.use_timed_hook:Get() then
        local is_timed, rem_time, _ = check_timed_immobile_state(target)
        if is_timed then
            return "TIMED_SETUP", t_pos, rem_time, 1.0
        end
    end

    -- 2. Controllo Lock Fisico (Stun / Root / Channeling / Cast Phase / Attack Animation)
    -- NOTA CRITICA (da logspudge.md Evento #08): Un lock breve (es. 0.22s di attacco) a 1200 unità
    -- (dove il gancio impiega 1.05s) NON blocca il bersaglio fino all'impatto!
    local is_locked, lock_dur, lock_reason, is_hard_disable = check_hard_disable_or_channel(target, tr, now)
    if is_locked then
        if is_hard_disable or lock_dur >= (intercept_t - 0.22) then
            return "LOCKED", t_pos, lock_dur, 0.95
        elseif lock_reason == "ATTACK_ANIM" or lock_reason == "ATTACKING" then
            -- Breve animazione di attacco a lunga distanza: trattalo come FARMING fermo, non come LOCKED garantito!
            return "FARMING", t_pos, 0, 0.06
        end
    end

    if not ui.use_intent:Get() then
        return "ROAMING", nil, 0, 0
    end

    -- 3. Controllo JUKING (Zig-Zag attivo / Stutter-Stepping)
    local num_reversals = #tr.direction_changes
    if num_reversals >= 2 and tr.move_stability_time < 0.25 then
        local cx, cy, count = 0, 0, 0
        for i = math.max(1, #tr.history - 10), #tr.history do
            local h = tr.history[i]
            if h and h.pos and (now - h.t) <= 0.45 then
                cx = cx + h.pos.x
                cy = cy + h.pos.y
                count = count + 1
            end
        end
        local center_pos = (count > 0) and Vector(cx / count, cy / count, t_pos.z) or t_pos
        return "JUKING", center_pos, 0, -0.25
    end

    -- 4. Controllo RETREATING (Tornare verso la propria Torre o Fontana)
    local retreat_node, _, fountain_pos = get_nearest_team_tower_or_fountain(t_pos, t_team)
    if retreat_node and spd > 60 then
        local rx, ry = normalize_2d(retreat_node.x - t_pos.x, retreat_node.y - t_pos.y)
        local f_rx, f_ry = normalize_2d(fountain_pos.x - t_pos.x, fountain_pos.y - t_pos.y)
        local dot_tower = vx * rx + vy * ry
        local dot_fountain = vx * f_rx + vy * f_ry
        local best_retreat_dot = math.max(dot_tower, dot_fountain)
        local goal_pos = (dot_tower >= dot_fountain) and retreat_node or fountain_pos

        local hp_pct = (Entity.GetHealth(target) / math.max(1, Entity.GetMaxHealth(target))) * 100
        local recently_hurt = (now - (tr.last_damage_time or 0)) < 3.0

        local away_from_pudge = false
        if my_pos then
            local px, py = normalize_2d(t_pos.x - my_pos.x, t_pos.y - my_pos.y)
            away_from_pudge = (vx * px + vy * py) > 0.45
        end

        if (best_retreat_dot > 0.80 and (hp_pct < 65 or recently_hurt or away_from_pudge)) or
           (best_retreat_dot > 0.88 and tr.move_stability_time > 0.25) then
            return "RETREATING", goal_pos, 0, 0.14
        end
    end

    -- 5. Controllo FARMING (Last-Hitting / Denying / Jungle Farming) & PUSHING
    -- FIX CRITICO (da logspudge.md): Se un eroe sta CORRENDO (spd > 50) ed è GIÀ dentro il suo
    -- AttackRange rispetto a un creep, NON si sta fermando per attaccarlo (altrimenti sarebbe già fermo!).
    local atk_range = (NPC.GetAttackRange and NPC.GetAttackRange(target)) or 150
    if atk_range < 150 then atk_range = 150 end

    if NPCs and NPCs.InRadius and Enum and Enum.TeamType then
        local ok_c, nearby_creeps = pcall(NPCs.InRadius, t_pos, atk_range + 350, t_team, Enum.TeamType.TEAM_BOTH)
        if ok_c and nearby_creeps then
            local best_dying_creep = nil
            local best_creep_score = 999999
            local enemy_creep_count = 0
            local ally_creep_count = 0

            for _, unit in ipairs(nearby_creeps) do
                if unit and unit ~= target and Entity.IsAlive(unit) and not Entity.IsDormant(unit) then
                    local is_creep = (NPC.IsCreep and NPC.IsCreep(unit))
                        or (NPC.IsLaneCreep and NPC.IsLaneCreep(unit))
                        or (NPC.IsNeutral and NPC.IsNeutral(unit))
                    if is_creep then
                        local u_team = Entity.GetTeamNum(unit)
                        if u_team == t_team then
                            ally_creep_count = ally_creep_count + 1
                        else
                            enemy_creep_count = enemy_creep_count + 1
                        end

                        local c_hp = Entity.GetHealth(unit)
                        local c_max = math.max(1, Entity.GetMaxHealth(unit))
                        local c_pct = (c_hp / c_max) * 100
                        local c_pos = Entity.GetAbsOrigin(unit)

                        if c_pos and (u_team ~= t_team or c_pct < 45) and (c_hp <= 160 or c_pct <= 28) then
                            local cx, cy, c_dist = normalize_2d(c_pos.x - t_pos.x, c_pos.y - t_pos.y)
                            local face_dot = fx * cx + fy * cy
                            local move_dot = vx * cx + vy * cy

                            if spd <= 35 then
                                -- Eroe fermo vicino al creep morente e rivolto verso il creep
                                if c_dist <= (atk_range + 45) and face_dot > 0.78 then
                                    local score = c_hp + c_dist * 0.3
                                    if score < best_creep_score then
                                        best_creep_score = score
                                        best_dying_creep = unit
                                    end
                                end
                            else
                                -- Eroe in movimento: considera FARMING solo se il creep è FUORI dal raggio di attacco
                                -- (tra atk_range + 20 e atk_range + 135) e l'eroe cammina DRITTO verso il creep!
                                if c_dist > (atk_range + 20) and c_dist <= (atk_range + 135)
                                   and move_dot > 0.90 and face_dot > 0.88 and (c_hp <= 130 or c_pct <= 22) then
                                    local score = c_hp + c_dist * 0.4
                                    if score < best_creep_score then
                                        best_creep_score = score
                                        best_dying_creep = unit
                                    end
                                end
                            end
                        end
                    end
                end
            end

            if best_dying_creep then
                if spd <= 35 then
                    return "FARMING", t_pos, 0, 0.12
                else
                    local c_pos = Entity.GetAbsOrigin(best_dying_creep)
                    local cx, cy, c_dist = normalize_2d(c_pos.x - t_pos.x, c_pos.y - t_pos.y)
                    local stop_dist = math.max(25, c_dist - atk_range)
                    local farm_stop_pos = Vector(t_pos.x + cx * stop_dist, t_pos.y + cy * stop_dist, t_pos.z)
                    return "FARMING", farm_stop_pos, stop_dist, 0.08
                end
            end

            -- Se ci sono creep e l'eroe avanza verso la torre nemica -> PUSHING
            if spd > 40 and (enemy_creep_count > 0 or ally_creep_count >= 2) then
                local enemy_team = (t_team == 2) and 3 or 2
                local enemy_tower_pos = get_nearest_team_tower_or_fountain(t_pos, enemy_team)
                if enemy_tower_pos then
                    local tx, ty = normalize_2d(enemy_tower_pos.x - t_pos.x, enemy_tower_pos.y - t_pos.y)
                    if (vx * tx + vy * ty) > 0.78 then
                        return "PUSHING", enemy_tower_pos, 0, 0.08
                    end
                end
            end
        end
    end

    -- 6. Controllo CHASING / ENGAGING (Inseguimento di Pudge o di un suo alleato)
    if spd > 70 and Heroes and Heroes.InRadius and Enum and Enum.TeamType then
        local ok_h, targets = pcall(Heroes.InRadius, t_pos, 1100, t_team, Enum.TeamType.TEAM_ENEMY)
        if ok_h and targets then
            for _, victim in ipairs(targets) do
                if is_valid_entity(victim) then
                    local v_pos = Entity.GetAbsOrigin(victim)
                    if v_pos then
                        local dx, dy, d = normalize_2d(v_pos.x - t_pos.x, v_pos.y - t_pos.y)
                        if (vx * dx + vy * dy) > 0.86 and (fx * dx + fy * dy) > 0.84 then
                            local stop_d = math.max(0, d - math.max(120, atk_range - 20))
                            local chase_pos = Vector(t_pos.x + dx * stop_d, t_pos.y + dy * stop_d, t_pos.z)
                            return "CHASING", chase_pos, stop_d, 0.14
                        end
                    end
                end
            end
        end
    end

    return "ROAMING", nil, 0, 0
end

-- =============================================================================
-- SIMULATORE DI PATHFINDING E TRAIETTORIA MULTI-STEP (SENZA DISTORSIONI LATERALI)
-- =============================================================================

local function simulate_pathfinding_trajectory(target, tr, total_time, intent, intent_pos, intent_stop_dist)
    local start_pos = (tr and tr.pos) or Entity.GetAbsOrigin(target)
    if not start_pos then return nil, {}, 0, 0 end

    local path_points = { start_pos }
    if total_time <= 0.01 then
        return start_pos, path_points, 0, 0
    end

    -- Se il bersaglio è in TIMED_SETUP (Eul/Astral/Disruption/TP), la posizione di atterraggio è fissa!
    if intent == "TIMED_SETUP" then
        return start_pos, path_points, 1.0, 0
    end

    -- Se il bersaglio è in LOCKED e la durata del lock copre quasi tutto il volo
    local free_move_time = total_time
    if intent == "LOCKED" and intent_stop_dist and intent_stop_dist > 0 then
        free_move_time = math.max(0.0, total_time - intent_stop_dist)
        if free_move_time <= 0.05 then
            return start_pos, path_points, 1.0, 0
        end
    end

    local spd = (tr and tr.speed) or 0
    local max_ms = (NPC.GetMoveSpeed and NPC.GetMoveSpeed(target)) or 300
    spd = math.min(spd, max_ms * 1.08)

    -- Se l'eroe è fermo
    if spd < 25 or (tr and not tr.is_moving) then
        return start_pos, path_points, 0.5, 0
    end

    -- Se sta facendo JUKING ad alta frequenza, ancoriamo localmente vicino a start_pos (max 95 unità)
    if intent == "JUKING" and intent_pos then
        local damp_time = math.min(0.28, free_move_time * 0.35)
        local vx, vy = normalize_2d(tr.smooth_vx, tr.smooth_vy)
        local dx_c = clamp(intent_pos.x - start_pos.x, -75, 75)
        local dy_c = clamp(intent_pos.y - start_pos.y, -75, 75)
        local proj_x = start_pos.x + dx_c * 0.40 + vx * spd * damp_time
        local proj_y = start_pos.y + dy_c * 0.40 + vy * spd * damp_time
        local juke_pred = Vector(proj_x, proj_y, start_pos.z)
        table.insert(path_points, juke_pred)
        return juke_pred, path_points, 0.0, 65
    end

    local is_flying = has_free_pathing(target)
    local base_dir_x, base_dir_y = normalize_2d(tr.smooth_vx, tr.smooth_vy)

    -- Allineamento topologico iniziale SINGOLO (NON accumulato nei 20 step!)
    -- Mantiene almeno il 92% di fedeltà alla direzione reale in cui l'eroe sta camminando!
    local flow_x, flow_y, initial_ramp_bonus = get_map_topological_flow(start_pos, base_dir_x, base_dir_y)
    base_dir_x, base_dir_y = flow_x, flow_y

    if intent_pos and (intent == "RETREATING" or intent == "PUSHING" or intent == "CHASING") then
        local gx, gy, g_dist = normalize_2d(intent_pos.x - start_pos.x, intent_pos.y - start_pos.y)
        if g_dist > 120 then
            local dot_goal = base_dir_x * gx + base_dir_y * gy
            -- Applica un leggero pull (max 8%) SOLO se l'eroe sta già correndo quasi dritto verso l'obiettivo (dot > 0.90)
            if dot_goal > 0.90 then
                base_dir_x, base_dir_y = normalize_2d(base_dir_x * 0.92 + gx * 0.08, base_dir_y * 0.92 + gy * 0.08)
            end
        end
    end

    -- Distanza massima percorribile
    local max_travel_dist = spd * free_move_time
    if intent == "FARMING" and intent_stop_dist and intent_stop_dist > 0 then
        if intent_stop_dist < max_travel_dist then
            max_travel_dist = intent_stop_dist
        end
    elseif intent == "CHASING" and intent_stop_dist and intent_stop_dist > 0 then
        if intent_stop_dist < max_travel_dist then
            max_travel_dist = intent_stop_dist
        end
    end

    if not ui.use_pathfinding:Get() then
        local simple_pos = Vector(start_pos.x + base_dir_x * max_travel_dist, start_pos.y + base_dir_y * max_travel_dist, start_pos.z)
        table.insert(path_points, simple_pos)
        return simple_pos, path_points, 0, 0
    end

    -- Integrazione Multi-Step sul terreno di Dota 2 (Step = 0.05s)
    local step_dt = 0.05
    local steps = math.ceil(free_move_time / step_dt)
    local cur_x, cur_y, cur_z = start_pos.x, start_pos.y, start_pos.z
    local dir_x, dir_y = base_dir_x, base_dir_y
    local traveled = 0
    local total_confinement = 0
    local confinement_samples = 0
    local branch_divergence = 0

    for step = 1, steps do
        if traveled >= max_travel_dist then break end
        local dt = math.min(step_dt, free_move_time - (step - 1) * step_dt)
        local step_dist = math.min(spd * dt, max_travel_dist - traveled)

        -- Ad ogni nuovo step, partiamo dalla direzione reale di marcia `base_dir`
        dir_x, dir_y = base_dir_x, base_dir_y

        -- Prova passo diretto lungo la vera direzione di movimento
        local next_x = cur_x + dir_x * step_dist
        local next_y = cur_y + dir_y * step_dist
        local walkable, next_z = is_point_walkable(next_x, next_y, cur_z, is_flying)

        if not walkable then
            -- OSTACOLO RILEVATO (Albero, Scogliera o Muro):
            -- Proviamo solo angoli di scivolamento realistici (15°, 30°, 45°) SENZA mai rimbalzare a 85°!
            local found_branch = false

            for deg = 15, 45, 15 do
                local rad = math.rad(deg)
                local lx, ly = rotate_2d(base_dir_x, base_dir_y, rad)
                local rx, ry = rotate_2d(base_dir_x, base_dir_y, -rad)

                local wl, zl = is_point_walkable(cur_x + lx * step_dist, cur_y + ly * step_dist, cur_z, is_flying)
                local wr, zr = is_point_walkable(cur_x + rx * step_dist, cur_y + ry * step_dist, cur_z, is_flying)

                if wl and wr then
                    branch_divergence = branch_divergence + 14
                    local choose_left = true
                    if intent_pos then
                        local gx, gy = normalize_2d(intent_pos.x - cur_x, intent_pos.y - cur_y)
                        choose_left = (lx * gx + ly * gy) >= (rx * gx + ry * gy)
                    end
                    if choose_left then
                        dir_x, dir_y = lx, ly
                        next_x, next_y, next_z = cur_x + lx * step_dist, cur_y + ly * step_dist, zl
                    else
                        dir_x, dir_y = rx, ry
                        next_x, next_y, next_z = cur_x + rx * step_dist, cur_y + ry * step_dist, zr
                    end
                    found_branch = true
                    break
                elseif wl then
                    dir_x, dir_y = lx, ly
                    next_x, next_y, next_z = cur_x + lx * step_dist, cur_y + ly * step_dist, zl
                    found_branch = true
                    break
                elseif wr then
                    dir_x, dir_y = rx, ry
                    next_x, next_y, next_z = cur_x + rx * step_dist, cur_y + ry * step_dist, zr
                    found_branch = true
                    break
                end
            end

            if not found_branch then
                -- Muro/Scogliera/Alberi frontali oltre ±45°: l'eroe si ferma contro l'ostacolo!
                total_confinement = total_confinement + 1.0
                confinement_samples = confinement_samples + 1
                branch_divergence = branch_divergence + 20
                break
            end
        end

        -- Valuta il confinamento laterale del corridoio nel punto raggiunto
        local conf, _, _ = evaluate_corridor_confinement(next_x, next_y, next_z, dir_x, dir_y, is_flying)
        total_confinement = total_confinement + math.min(1.0, conf + initial_ramp_bonus)
        confinement_samples = confinement_samples + 1

        cur_x, cur_y, cur_z = next_x, next_y, next_z
        traveled = traveled + step_dist

        if step % 2 == 0 or step == steps then
            table.insert(path_points, Vector(cur_x, cur_y, cur_z))
        end
    end

    local avg_conf = (confinement_samples > 0) and (total_confinement / confinement_samples) or 0.0
    local final_pos = Vector(cur_x, cur_y, cur_z)
    return final_pos, path_points, avg_conf, branch_divergence
end

-- =============================================================================
-- MODULO 3: CONTROLLO COLLISIONI 4D & EDGE-SNIPING ANTI-CREEP
-- =============================================================================

--- Raccoglie tutte le unità che possono intercettare e bloccare il Meat Hook
--- (Creep alleati, creep nemici, neutrali, evocazioni, Roshan e altri eroi diversi dal bersaglio)
local function collect_hook_obstacles(my_hero, target, max_range)
    local obstacles = {}
    local my_pos = Entity.GetAbsOrigin(my_hero)
    if not my_pos then return obstacles end

    local search_rad = max_range + 250

    -- 1. Tutti gli altri eroi (alleati e nemici) diversi da Pudge e dal bersaglio scelto
    if Heroes and Heroes.GetAll then
        for _, h in ipairs(Heroes.GetAll()) do
            if h and h ~= my_hero and h ~= target and Entity.IsAlive(h) and not Entity.IsDormant(h) then
                local h_pos = Entity.GetAbsOrigin(h)
                if h_pos and dist_2d(my_pos, h_pos) <= search_rad then
                    -- Ignora unità banished/out-of-game (Astral, Disruption, Phase Shift) che non bloccano il gancio
                    local is_banished = false
                    if Enum and Enum.ModifierState and NPC.HasState then
                        is_banished = NPC.HasState(h, Enum.ModifierState.MODIFIER_STATE_OUT_OF_GAME)
                    end
                    if not is_banished then
                        local hull = (NPC.GetHullRadius and NPC.GetHullRadius(h)) or HERO_HULL_RADIUS
                        local idx = Entity.GetIndex(h)
                        local tr = idx and hero_trackers[idx]
                        local vx = (tr and tr.smooth_vx) or 0
                        local vy = (tr and tr.smooth_vy) or 0
                        table.insert(obstacles, {
                            unit = h,
                            pos = h_pos,
                            vx = vx,
                            vy = vy,
                            hull = hull,
                            name = (NPC.GetUnitName and NPC.GetUnitName(h)) or "Hero"
                        })
                    end
                end
            end
        end
    end

    -- 2. Tutti i creep (corsia, neutrali, evocazioni) nel raggio del gancio
    if NPCs and NPCs.InRadius and Enum and Enum.TeamType then
        local my_team = Entity.GetTeamNum(my_hero)
        local ok, npcs = pcall(NPCs.InRadius, my_pos, search_rad, my_team, Enum.TeamType.TEAM_BOTH)
        if ok and npcs then
            for _, u in ipairs(npcs) do
                if u and u ~= my_hero and u ~= target and Entity.IsAlive(u) and not Entity.IsDormant(u) then
                    local is_hero = NPC.IsHero and NPC.IsHero(u)
                    if not is_hero then
                        local is_structure = (NPC.IsStructure and NPC.IsStructure(u))
                            or (NPC.IsTower and NPC.IsTower(u))
                            or (NPC.IsBarracks and NPC.IsBarracks(u))
                        local uname = (NPC.GetUnitName and NPC.GetUnitName(u)) or ""
                        local is_ward = string.find(uname, "ward", 1, true) ~= nil
                            or string.find(uname, "thinker", 1, true) ~= nil
                            or string.find(uname, "lantern", 1, true) ~= nil
                            or string.find(uname, "twin_gate", 1, true) ~= nil

                        if not is_structure and not is_ward then
                            local u_pos = Entity.GetAbsOrigin(u)
                            if u_pos then
                                local hull = (NPC.GetHullRadius and NPC.GetHullRadius(u)) or HERO_HULL_RADIUS
                                local vx, vy = 0, 0
                                if NPC.IsRunning and NPC.IsRunning(u) then
                                    local fx, fy = get_unit_forward_2d(u)
                                    local ms = (NPC.GetMoveSpeed and NPC.GetMoveSpeed(u)) or 325
                                    vx, vy = fx * ms, fy * ms
                                end
                                table.insert(obstacles, {
                                    unit = u,
                                    pos = u_pos,
                                    vx = vx,
                                    vy = vy,
                                    hull = hull,
                                    name = uname
                                })
                            end
                        end
                    end
                end
            end
        end
    end

    return obstacles
end

--- Verifica se il raggio del gancio da `pudge_pos` nella direzione `(dir_x, dir_y)` fino a `target_dist`
--- è completamente libero da creep, alleati o bersagli indesiderati nel tempo!
--- @return boolean is_clear Vero se la traiettoria è 100% pulita
--- @return number min_clearance Distanza minima rilevata dall'ostacolo più vicino
--- @return string blocked_by Nome dell'unità che blocca
local function is_hook_corridor_clear(pudge_pos, dir_x, dir_y, target_dist, cast_delay, hook_speed, hook_width, obstacles)
    local safety_margin = ui.obstacle_safety:Get() or 26
    local min_clearance = 999999

    for _, obs in ipairs(obstacles) do
        -- Proiezione della posizione attuale dell'ostacolo sul raggio del gancio
        local s_now, perp_now = point_to_ray_2d(obs.pos.x, obs.pos.y, pudge_pos.x, pudge_pos.y, dir_x, dir_y)
        local obs_spd = math.sqrt(obs.vx * obs.vx + obs.vy * obs.vy)

        -- L'ostacolo ci interessa se è davanti a Pudge (o può entrarci) e prima/all'altezza del bersaglio
        local max_reach_window = target_dist + 65 + obs_spd * 1.1
        if s_now > -60 and s_now < max_reach_window then
            -- Iterazione a 2 stadi sul tempo di arrivo `t_reach` della punta del gancio all'altezza del creep
            local t_reach_1 = cast_delay + math.max(0, math.min(target_dist, s_now)) / hook_speed
            local fut1_x = obs.pos.x + obs.vx * t_reach_1
            local fut1_y = obs.pos.y + obs.vy * t_reach_1
            local s_fut1, _ = point_to_ray_2d(fut1_x, fut1_y, pudge_pos.x, pudge_pos.y, dir_x, dir_y)

            local t_reach = cast_delay + math.max(0, math.min(target_dist, (s_now + s_fut1) * 0.5)) / hook_speed

            -- Posizione futura dell'ostacolo all'istante `t_reach`
            local fut_x = obs.pos.x + obs.vx * t_reach
            local fut_y = obs.pos.y + obs.vy * t_reach
            local s_fut, perp_fut = point_to_ray_2d(fut_x, fut_y, pudge_pos.x, pudge_pos.y, dir_x, dir_y)

            -- Campionamento a 5 punti lungo la capsula spazio-temporale (0%, 25%, 50%, 75%, 100% di t_reach)
            -- per intercettare creep che si fermano per attaccare o che attraversano la linea a metà volo!
            local _, perp_25 = point_to_ray_2d(
                obs.pos.x * 0.75 + fut_x * 0.25,
                obs.pos.y * 0.75 + fut_y * 0.25,
                pudge_pos.x, pudge_pos.y, dir_x, dir_y
            )
            local _, perp_50 = point_to_ray_2d(
                (obs.pos.x + fut_x) * 0.50,
                (obs.pos.y + fut_y) * 0.50,
                pudge_pos.x, pudge_pos.y, dir_x, dir_y
            )
            local _, perp_75 = point_to_ray_2d(
                obs.pos.x * 0.25 + fut_x * 0.75,
                obs.pos.y * 0.25 + fut_y * 0.75,
                pudge_pos.x, pudge_pos.y, dir_x, dir_y
            )

            local worst_perp = math.min(perp_now, perp_25, perp_50, perp_75, perp_fut)

            -- Margine dinamico aggiuntivo per creep/unità che possono cambiare aggro durante voli lunghi (> 0.55s)
            local dynamic_pad = 0
            if not obs.is_hero and t_reach > 0.50 then
                dynamic_pad = math.min(22, (t_reach - 0.50) * 32.0)
            end

            local block_radius = hook_width + obs.hull + safety_margin + dynamic_pad

            local clearance = worst_perp - block_radius
            if clearance < min_clearance then
                min_clearance = clearance
            end

            if worst_perp <= block_radius and (s_now > 15 or s_fut > 15) and math.min(s_now, s_fut) < (target_dist + 40) then
                return false, clearance, obs.name
            end
        end
    end

    return true, min_clearance, ""
end

-- =============================================================================
-- MODULO 4: RISOLUTORE BALISTICO COMPLETO, EDGE-SNIPING & CONFIDENCE SCORING
-- =============================================================================

--- Calcola la soluzione completa di tiro per `target`:
--- 1. Risoluzione iterativa a punto fisso (Fixed-Point Iteration) tra tempo di volo del gancio
---    e posizione futura del bersaglio lungo il pathfinding.
--- 2. Controllo collisioni 4D ed Edge-Sniping (scansione micro-angoli se un creep è vicino alla linea).
--- 3. Calcolo scientifico del Confidence Score (0% - 100%).
local function compute_optimal_hook_solution(my_hero, target, hook_ab, now)
    local pudge_pos = Entity.GetAbsOrigin(my_hero)
    if not pudge_pos or not is_valid_entity(target) then return nil end

    local max_range, hook_speed, hook_width, cast_point = get_hook_parameters(my_hero, hook_ab)
    local idx = Entity.GetIndex(target)
    local tr = idx and hero_trackers[idx]
    local target_pos = (tr and tr.pos) or Entity.GetAbsOrigin(target)
    if not target_pos then return nil end

    -- Verifica preliminare distanza
    local current_dist = dist_2d(pudge_pos, target_pos)
    if current_dist > max_range + 350 then
        return {
            valid = false,
            confidence = 0,
            intent = "OUT_OF_RANGE",
            aim_pos = target_pos,
            path = { target_pos },
            is_blocked = false,
            reason = "Out of Hook Range"
        }
    end

    -- Stima preliminare del tempo di intercettazione per verificare se un'animazione (LOCKED) durerà abbastanza
    local approx_turn_t = calculate_pudge_turn_time(my_hero, target_pos)
    local approx_intercept_t = approx_turn_t + cast_point + (current_dist / hook_speed) + 0.03

    -- 1. Analisi Intenzione Comportamentale (passando `approx_intercept_t` per evitare falsi LOCKED a lunga distanza!)
    local intent, intent_pos, intent_param, intent_conf_mod = analyze_hero_intent(target, tr, my_hero, now, approx_intercept_t)

    -- 2. Caso Speciale: Setup Cronometrato (Eul, Astral, Disruption, TP)
    if intent == "TIMED_SETUP" then
        local turn_time = calculate_pudge_turn_time(my_hero, target_pos)
        local flight_time = turn_time + cast_point + (current_dist / hook_speed)
        local rem_time = intent_param -- Tempo residuo del ciclone/astral

        local obstacles = collect_hook_obstacles(my_hero, target, max_range)
        local dir_x, dir_y = normalize_2d(target_pos.x - pudge_pos.x, target_pos.y - pudge_pos.y)
        local clear, _, blocked_by = is_hook_corridor_clear(pudge_pos, dir_x, dir_y, current_dist, turn_time + cast_point, hook_speed, hook_width, obstacles)

        -- Dobbiamo lanciare esattamente quando flight_time coincide con rem_time (+0.02s buffer)!
        local time_diff = rem_time - flight_time
        local conf = 0
        if current_dist <= max_range and clear then
            if time_diff <= 0.06 and time_diff >= -0.12 then
                conf = 99 -- FINESTRA PERFETTA AL MILLISECONDO: LANCIA ORA!
            else
                conf = 40 -- In attesa del millisecondo esatto di discesa da Eul/Astral
            end
        end

        return {
            valid = (current_dist <= max_range and clear),
            confidence = conf,
            intent = string.format("TIMED (%.2fs)", rem_time),
            aim_pos = target_pos,
            path = { target_pos },
            is_blocked = not clear,
            reason = not clear and ("Blocked by " .. blocked_by) or (time_diff > 0.06 and "Waiting for exact timing..." or "READY")
        }
    end

    -- 3. Risoluzione Iterativa a Punto Fisso (Fixed-Point Ballistic Convergence)
    --    Calcola simultaneamente 3 ipotesi di Pathfinding (Multi-Hypothesis Path Tree):
    --    • Ipotesi A (pred_pos): Pathfinding cinematico rettilineo + deviazione ostacoli reali.
    --    • Ipotesi B (intent_branch_pos): Path ancorato all'obiettivo dell'intenzione (es. stop sul creep o rampa).
    --    • Ipotesi C (inertia_branch_pos): Ipotesi di micro-esitazione / decelerazione (78% del tempo).
    local pred_pos = target_pos
    local sim_path = { target_pos }
    local avg_confinement = 0
    local branch_div = 0
    local total_intercept_time = approx_intercept_t

    for iter = 1, 7 do
        local turn_t = calculate_pudge_turn_time(my_hero, pred_pos)
        local d = dist_2d(pudge_pos, pred_pos)
        -- Compensazione latenza/tick (0.025s)
        total_intercept_time = turn_t + cast_point + (d / hook_speed) + 0.025

        pred_pos, sim_path, avg_confinement, branch_div = simulate_pathfinding_trajectory(
            target, tr, total_intercept_time, intent, intent_pos, intent_param
        )
        if not pred_pos then
            pred_pos = target_pos
            break
        end
    end

    -- Calcolo del Centroide di Sovrapposizione Multi-Path (Optimal Overlap Centroid):
    -- Poiché il gancio cattura chiunque entro (hook_width + hull_radius = 124 unità),
    -- mirando al centroide pesato tra il path pieno e l'ipotesi di decelerazione/esitazione,
    -- un SINGOLO gancio copre contemporaneamente sia la corsa continua sia una micro-frenata!
    local target_hull = (NPC.GetHullRadius and NPC.GetHullRadius(target)) or HERO_HULL_RADIUS
    local catch_radius = hook_width + target_hull -- ~124 unità

    if intent ~= "LOCKED" and intent ~= "TIMED_SETUP" and tr and tr.speed > 40 then
        local inertia_pos = simulate_pathfinding_trajectory(
            target, tr, total_intercept_time * 0.76, intent, intent_pos, intent_param
        )
        if inertia_pos then
            local spread = dist_2d(pred_pos, inertia_pos)
            if spread > 5 and spread <= (catch_radius * 1.25) then
                -- Peso dinamico: a lunga distanza (> 900 unità) pesiamo 66% full / 34% inertia per evitare overshoot
                local w_full = (current_dist > 900) and 0.66 or 0.72
                local w_iner = 1.0 - w_full
                pred_pos = Vector(
                    pred_pos.x * w_full + inertia_pos.x * w_iner,
                    pred_pos.y * w_full + inertia_pos.y * w_iner,
                    pred_pos.z
                )
            end
        end
    end

    local final_dist = dist_2d(pudge_pos, pred_pos)
    -- Non permettiamo tiri oltre il raggio reale quando il bersaglio sta scappando, ma solo se è fermo/bloccato
    local effective_max_range = (intent == "LOCKED") and (max_range + hook_width * 0.55) or (max_range + 20)

    if final_dist > effective_max_range then
        return {
            valid = false,
            confidence = 0,
            intent = intent,
            aim_pos = pred_pos,
            path = sim_path,
            is_blocked = false,
            reason = "Target Moving Out of Range"
        }
    end

    -- 4. Verifica Collisioni 4D ed Edge-Sniping (Off-Center Aiming attorno ai creep)
    local obstacles = collect_hook_obstacles(my_hero, target, max_range)
    local turn_time = calculate_pudge_turn_time(my_hero, pred_pos)
    local cast_delay = turn_time + cast_point

    local base_dx, base_dy = normalize_2d(pred_pos.x - pudge_pos.x, pred_pos.y - pudge_pos.y)
    local perp_x, perp_y = -base_dy, base_dx -- Versore ortogonale per Edge-Sniping

    local chosen_aim_pos = pred_pos
    local is_clear, best_clearance, block_unit = is_hook_corridor_clear(
        pudge_pos, base_dx, base_dy, final_dist, cast_delay, hook_speed, hook_width, obstacles
    )
    local edge_snipe_offset = 0

    -- Se il centro è bloccato (o molto vicino a un creep: clearance < 24) e Edge-Sniping è attivo,
    -- cerchiamo un punto sull'hitbox del bersaglio che eviti il creep!
    if ui.use_edge_snipe:Get() and (not is_clear or best_clearance < 24) then
        local offsets = { -26, 26, -44, 44, -62, 62, -78, 78 }
        for _, off in ipairs(offsets) do
            local cand_x = pred_pos.x + perp_x * off
            local cand_y = pred_pos.y + perp_y * off
            local cdx, cdy, cdist = normalize_2d(cand_x - pudge_pos.x, cand_y - pudge_pos.y)

            -- Verifica che il raggio candidato colpisca comunque il bersaglio con margine sicuro
            local _, target_perp = point_to_ray_2d(pred_pos.x, pred_pos.y, pudge_pos.x, pudge_pos.y, cdx, cdy)
            if target_perp <= (hook_width + target_hull - 32) and cdist <= effective_max_range then
                local c_clear, c_clearance, _ = is_hook_corridor_clear(
                    pudge_pos, cdx, cdy, cdist, cast_delay, hook_speed, hook_width, obstacles
                )
                if c_clear and c_clearance > best_clearance then
                    is_clear = true
                    best_clearance = c_clearance
                    chosen_aim_pos = Vector(cand_x, cand_y, pred_pos.z)
                    edge_snipe_offset = math.abs(off)
                    if c_clearance >= 28 then
                        break -- Trovato angolo pulitissimo!
                    end
                end
            end
        end
    end

    if not is_clear then
        return {
            valid = false,
            confidence = 0,
            intent = intent,
            aim_pos = pred_pos,
            path = sim_path,
            is_blocked = true,
            reason = "Blocked by " .. (block_unit or "Unit")
        }
    end

    -- 5. Calcolo Scientifico del CONFIDENCE SCORE (0% - 100%)
    local confidence = 84.0

    -- A. Capacità Fisica di Schivata (Physical Evade Capacity) & Vantaggio Visibilità (Fog / Highground / Smoke)
    local pudge_hidden_advantage = false
    if pudge_pos.z > (target_pos.z + 65) then
        pudge_hidden_advantage = true -- Pudge su Highground rispetto al bersaglio!
    elseif NPC.HasModifier(my_hero, "modifier_smoke_of_deceit") or
           (Enum and Enum.ModifierState and NPC.HasState(my_hero, Enum.ModifierState.MODIFIER_STATE_INVISIBLE)) then
        pudge_hidden_advantage = true -- Pudge in Smoke o Invisibile!
    elseif Trees and Trees.InRadius then
        -- Controlla se ci sono alberi davanti a Pudge che nascondono Pudge nella Fog of War
        local check_tree_pos = Vector(pudge_pos.x + base_dx * 220, pudge_pos.y + base_dy * 220, pudge_pos.z)
        local ok_tr, t_list = pcall(Trees.InRadius, check_tree_pos, 180, true)
        if ok_tr and t_list and #t_list >= 2 then
            pudge_hidden_advantage = true -- Gancio lanciato da dietro gli alberi!
        end
    end

    if pudge_hidden_advantage then
        confidence = confidence + 7.0 -- Il nemico non vede l'animazione di cast di 0.3s!
    end

    -- Tempo effettivo a disposizione del nemico per fare un sidestep dopo tempo di reazione umano (~0.24s) + turn delay (~0.09s)
    local reaction_delay = pudge_hidden_advantage and 0.48 or 0.32
    local effective_evade_window = math.max(0.05, total_intercept_time - reaction_delay)
    local enemy_ms = (NPC.GetMoveSpeed and NPC.GetMoveSpeed(target)) or 300
    local max_lateral_evade = enemy_ms * effective_evade_window

    if max_lateral_evade <= catch_radius then
        -- Fisicamente IMPOSSIBILE uscire a piedi dal raggio di cattura del gancio in tempo!
        confidence = confidence + 12.0
    else
        local dist_ratio = clamp((final_dist - 300) / math.max(1, max_range - 300), 0.0, 1.0)
        confidence = confidence - (dist_ratio * 15.0)
    end

    -- B. Fattore Velocità Trasversale & Transizioni Start/Stop (Anti-Overshoot / Anti-Undershoot)
    local spd = (tr and tr.speed) or 0
    local collinearity = 1.0
    if spd < 25 then
        local stat_time = (tr and tr.stationary_time) or 0.1
        local since_stop = now - ((tr and tr.just_stopped_time) or 0)
        -- Se il bersaglio si è appena fermato (< 0.14s fa) a lunga distanza (> 850), aspettiamo un istante
        -- per capire se è un micro-stop o una sosta reale (evita UNDERSHOOT_STARTED_FROM_IDLE!)
        if since_stop < 0.14 and final_dist > 850 and intent ~= "LOCKED" then
            confidence = confidence - 10.0
        else
            confidence = confidence + math.min(12.0, 4.0 + stat_time * 16.0)
        end
    else
        local mvx, mvy = normalize_2d(tr.smooth_vx, tr.smooth_vy)
        collinearity = math.abs(mvx * base_dx + mvy * base_dy) -- 1.0 = parallelo al gancio, 0.0 = perpendicolare
        -- Bonus fino a +11% se corre lungo la linea del gancio, penalità se taglia a 90° a distanza
        confidence = confidence + (collinearity - 0.45) * 18.0

        -- Se l'eroe ha appena iniziato a muoversi (< 0.10s fa), il suo vettore direzione si sta ancora stabilizzando
        local since_start = now - ((tr and tr.just_started_time) or 0)
        if since_start < 0.10 and final_dist > 700 then
            confidence = confidence - 12.0
        end

        -- Se il modello 3D dell'eroe sta già ruotando verso un nuovo angolo (> 38° rispetto al vettore velocità),
        -- significa che il giocatore nemico ha appena cliccato di lato per cambiare direzione!
        if tr.is_turning_body and final_dist > 550 then
            confidence = confidence - 16.0
        end

        -- Penalità per bersagli tangenziali a lunghissima distanza (> 1100 unità) che possono cambiare idea in volo
        if final_dist > 1100 and collinearity < 0.55 then
            confidence = confidence - ((final_dist - 1100) * 0.045)
        end

        -- Se l'eroe ha velocità estrema (> 420 MS, es. Haste/Surge) e taglia perpendicolarmente
        if spd > 420 and collinearity < 0.5 then
            confidence = confidence - ((spd - 420) * 0.06)
        end
    end

    -- C. Fattore Stabilità Movimento (da quanto tempo non cambia direzione)
    local stab = (tr and tr.move_stability_time) or 0.2
    if stab >= 0.35 then
        confidence = confidence + math.min(9.0, (stab - 0.20) * 16.0)
    elseif stab < 0.15 and intent ~= "LOCKED" then
        confidence = confidence - 14.0
    end

    -- D. Fattore Velocità Angolare e Biforcazioni Pathfinding
    local omega = math.abs((tr and tr.vel_angular_vel) or (tr and tr.angular_vel) or 0)
    if omega > 1.6 and intent ~= "LOCKED" then
        confidence = confidence - math.min(16.0, (omega - 1.3) * 6.0)
    end
    if branch_div > 0 then
        confidence = confidence - math.min(12.0, branch_div * 0.35)
    end

    -- E. Fattore Confinamento Topografico (Scale, Rampe, Chokepoints, Alberi)
    -- Se il nemico è in un passaggio stretto tra gli alberi o su una rampa, non può schivare di lato!
    confidence = confidence + (avg_confinement * 16.0)

    -- F. Modificatore Comportamentale dell'Intenzione
    confidence = confidence + (intent_conf_mod * 100.0)
    if intent == "LOCKED" then
        confidence = math.max(confidence, 97.0)
    end

    -- G. Leggera penalità se abbiamo dovuto usare un Edge-Snipe molto decentrato
    if edge_snipe_offset > 40 then
        confidence = confidence - ((edge_snipe_offset - 40) * 0.14)
    end

    confidence = clamp(math.floor(confidence + 0.5), 1, 99)

    return {
        valid = true,
        confidence = confidence,
        intent = intent,
        aim_pos = chosen_aim_pos,
        path = sim_path,
        is_blocked = false,
        reason = pudge_hidden_advantage and "CLEAR (FOG/HG BONUS)" or "CLEAR"
    }
end

-- =============================================================================
-- MODULO 5: MOTORE DI LOGGING AVANZATO & ANALISI POST-MORTEM (`logspudge.md`)
-- =============================================================================

local LOG_FILE_PATHS = {
    "scripts\\logspudge.md",
    "scripts/logspudge.md",
    "c:\\Umbrella\\scripts\\logspudge.md",
    "c:/Umbrella/scripts/logspudge.md",
    "logspudge.md",
}

local function format_game_clock(sec)
    if not sec or sec < 0 then sec = 0 end
    local mins = math.floor(sec / 60)
    local rem = sec - (mins * 60)
    return string.format("%02d:%04.1f", mins, rem)
end

--- Scrive in tempo reale in `logspudge.md` (e in `debug.log` tramite print) l'analisi dettagliata del gancio
local function write_to_logspudge_md(markdown_entry, console_summary)
    if not ui.enable_file_logs:Get() then return end

    if console_summary then
        print(console_summary)
    end

    local wrote_direct = false
    if io and io.open then
        for _, path in ipairs(LOG_FILE_PATHS) do
            local ok, f = pcall(io.open, path, "a")
            if ok and f then
                local ok_w = pcall(function()
                    f:write("\n" .. markdown_entry .. "\n")
                    f:flush()
                    f:close()
                end)
                if ok_w then
                    wrote_direct = true
                    break
                end
            end
        end
    end

    -- Se la sandbox Lua di Umbrella dovesse bloccare io.open, stampa il blocco Markdown completo in debug.log
    if not wrote_direct then
        print("<<<PUDGE_MD_START>>>\n" .. markdown_entry .. "\n<<<PUDGE_MD_END>>>")
    end
end

--- Registra in `logspudge.md` un'animazione di gancio fermata in tempo dallo Stop-Cancel (0.30s cast point)
local function log_stop_cancel_to_file(cast_data, cancel_reason, now)
    if not ui.enable_file_logs:Get() then return end

    hook_stats.event_seq = hook_stats.event_seq + 1
    hook_stats.stop_cancels = hook_stats.stop_cancels + 1

    local t_name = "Unknown"
    if cast_data.target and is_valid_entity(cast_data.target) and NPC.GetUnitName then
        t_name = NPC.GetUnitName(cast_data.target) or "Unknown"
    end

    local cast_elapsed_ms = math.floor(math.max(0, now - (cast_data.start_time or now)) * 1000)
    local diagnosis = ""
    local tuning_tip = ""

    if string.find(cancel_reason, "Obstacle Entered Line", 1, true) then
        diagnosis = "Durante i 300ms di animazione (Cast Point), un creep o unità non desiderata è entrata fisicamente nel cilindro di collisione del gancio. Lo Stop-Cancel ha interrotto l'animazione prima del rilascio, evitando al 100% di agganciare il bersaglio sbagliato."
        tuning_tip = "Se questo blocco si ripete spesso in corsia durante il `FARMING`, aumentare la proiezione predittiva della velocità dei creep alleati/nemici o privilegiare un angolo di `Edge-Sniping` più ampio."
    elseif string.find(cancel_reason, "Target Dodged Laterally", 1, true) then
        diagnosis = "Il bersaglio ha cambiato bruscamente direzione o si è fermato proprio durante i 300ms di animazione di Pudge, portando la distanza perpendicolare oltre la soglia di sicurezza. Lo Stop-Cancel ha salvato un miss sicuro risparmiando Cooldown e Mana."
        tuning_tip = "Il bersaglio ha mostrato reattività durante il cast point: mantenere premuto il tasto permette allo script di rilanciare istantaneamente appena il bersaglio stabilizza il nuovo vettore."
    elseif string.find(cancel_reason, "Target Stopped During Cast Point", 1, true) then
        diagnosis = "Il bersaglio stava correndo al momento dell'ordine di lancio ma si è inchiodato sul posto durante i 300ms di Cast Point (Anti-Overshoot). Lo Stop-Cancel ha bloccato il lancio prima che il gancio partisse a vuoto davanti al bersaglio."
        tuning_tip = "Interruzione perfetta: tenendo premuto il tasto, lo script ricalibra istantaneamente la mira sulla posizione ferma del bersaglio."
    elseif string.find(cancel_reason, "Target Started Moving During Cast Point", 1, true) then
        diagnosis = "Il bersaglio era fermo al momento dell'ordine di lancio ma è scattato in movimento durante i 300ms di Cast Point (Anti-Undershoot). Lo Stop-Cancel ha fermato il lancio per evitare che il gancio arrivasse dietro la schiena del bersaglio."
        tuning_tip = "Interruzione perfetta: lo script aggiorna subito il lead vettoriale sulla nuova velocità di corsa."
    elseif string.find(cancel_reason, "Out of Hook Distance", 1, true) then
        diagnosis = "Il bersaglio si trovava al limite estremo della portata e durante i 300ms di animazione è uscito dal raggio massimo del gancio."
        tuning_tip = "Ridurre di 35-50 unità la portata massima utile quando il bersaglio si muove in direzione radiale di allontanamento."
    else
        diagnosis = "Il bersaglio è morto o diventato non valido durante l'animazione di lancio."
        tuning_tip = "Nessuna correzione necessaria: interruzione corretta."
    end

    local md = string.format(
[[### 🛡️ Evento #%02d [STOP-CANCEL SAVED] — Clock `%s`
- **Bersaglio**: `%s` | **Modalità**: `%s` | **Confidenza Iniziale**: `%d%%` | **Intenzione**: `%s`
- **Attesa Prima del Cast**: `%.2fs` | **Interrotto dopo**: `%d ms` di animazione | **Motivo Stop**: `%s`
- **Statistiche Sessione**: Lanciati: `%d` | Colpiti: `%d` | Falliti: `%d` | Salvati da Stop-Cancel: `%d`
- **Perché si è fermato (Prevenzione Errore)**: %s
- **Spunto di Miglioramento Script**: %s
]],
        hook_stats.event_seq,
        format_game_clock(now),
        t_name,
        cast_data.is_ally_mode and "ALLY SAVE" or "ENEMY HOOK",
        cast_data.confidence or 0,
        tostring(cast_data.intent or "UNKNOWN"),
        cast_data.wait_time or 0,
        cast_elapsed_ms,
        cancel_reason,
        hook_stats.total_fired,
        hook_stats.hits,
        hook_stats.misses,
        hook_stats.stop_cancels,
        diagnosis,
        tuning_tip
    )

    local summary = string.format(
        "[PUDGE_LOG_MD] #%02d [STOP-CANCEL] Target=%s | Conf=%d%% | Intent=%s | Reason=%s",
        hook_stats.event_seq, t_name, cast_data.confidence or 0, tostring(cast_data.intent), cancel_reason
    )
    write_to_logspudge_md(md, summary)
end

--- Avvia il tracciamento telemetrico del gancio appena il proiettile lascia la mano di Pudge
local function start_in_flight_hook_tracking(my_hero, hook_ab, cast_data, now)
    local pudge_pos = Entity.GetAbsOrigin(my_hero)
    if not pudge_pos then return end

    local max_range, hook_speed, hook_width = get_hook_parameters(my_hero, hook_ab)
    local target = cast_data.target or aim_session.locked_target
    local t_name = "Manual/Unknown"
    local t_pos = nil
    local t_speed = 0
    local t_angle = 0
    local t_rev = 0

    if target and is_valid_entity(target) then
        t_name = (NPC.GetUnitName and NPC.GetUnitName(target)) or "Hero"
        t_pos = Entity.GetAbsOrigin(target)
        local idx = Entity.GetIndex(target)
        local tr = idx and hero_trackers[idx]
        if tr then
            t_speed = tr.speed or 0
            t_angle = tr.move_angle or 0
            t_rev = tr.juke_reversals or 0
        end
    end

    local aim_pos = cast_data.aim_pos or (t_pos or Vector(pudge_pos.x + cast_data.dir_x * max_range, pudge_pos.y + cast_data.dir_y * max_range, pudge_pos.z))
    local dir_x, dir_y, pred_dist = normalize_2d(aim_pos.x - pudge_pos.x, aim_pos.y - pudge_pos.y)
    if pred_dist < 50 then pred_dist = max_range end

    hook_stats.event_seq = hook_stats.event_seq + 1
    hook_stats.total_fired = hook_stats.total_fired + 1

    in_flight_hook.active = true
    in_flight_hook.hook_id = hook_stats.total_fired
    in_flight_hook.launch_time = now
    in_flight_hook.pudge_pos = pudge_pos
    in_flight_hook.aim_pos = aim_pos
    in_flight_hook.dir_x = dir_x
    in_flight_hook.dir_y = dir_y
    in_flight_hook.max_range = max_range
    in_flight_hook.hook_speed = hook_speed
    in_flight_hook.hook_width = hook_width
    in_flight_hook.target = target
    in_flight_hook.target_name = t_name
    in_flight_hook.is_ally_mode = cast_data.is_ally_mode or false
    in_flight_hook.is_manual = cast_data.is_manual or false
    in_flight_hook.confidence = cast_data.confidence or aim_session.best_confidence or 0
    in_flight_hook.intent = cast_data.intent or aim_session.best_intent or (cast_data.is_manual and "MANUAL_Q" or "MANUAL")
    in_flight_hook.wait_time = cast_data.wait_time or 0
    in_flight_hook.edge_reason = cast_data.edge_reason or aim_session.block_reason or "CLEAR"
    in_flight_hook.target_launch_pos = t_pos
    in_flight_hook.target_launch_speed = t_speed
    in_flight_hook.target_launch_angle = t_angle
    in_flight_hook.target_launch_reversals = t_rev
    in_flight_hook.pred_dist = math.min(max_range, pred_dist)
    in_flight_hook.expected_tof = in_flight_hook.pred_dist / hook_speed
    in_flight_hook.expected_impact_time = now + in_flight_hook.expected_tof
    in_flight_hook.min_dist_to_target = 999999
    in_flight_hook.closest_hook_pos = nil
    in_flight_hook.target_pos_at_closest = t_pos
    in_flight_hook.target_speed_at_closest = t_speed
    in_flight_hook.target_angle_at_closest = t_angle
    in_flight_hook.max_angle_change_deg = 0
    in_flight_hook.max_speed_delta = 0
    in_flight_hook.stopped_unexpectedly = false
    in_flight_hook.started_from_idle = false
    in_flight_hook.hit_unit = nil
    in_flight_hook.hit_pos = nil
    in_flight_hook.hit_time = 0
end

--- Conclude l'analisi del gancio in volo e scrive il report completo di SUCCESSO o FALLIMENTO in `logspudge.md`
local function finalize_in_flight_hook(my_hero, now)
    if not in_flight_hook.active then return end
    in_flight_hook.active = false

    local hit_u = in_flight_hook.hit_unit
    local target = in_flight_hook.target
    local pudge_pos = in_flight_hook.pudge_pos
    local aim_pos = in_flight_hook.aim_pos
    local flight_time = math.max(0.05, (in_flight_hook.hit_time > 0 and in_flight_hook.hit_time or now) - in_flight_hook.launch_time)

    -- Verifica se l'unità colpita è il nostro eroe bersaglio (o un altro eroe della squadra bersaglio)
    local is_target_hit = false
    local is_other_hero_hit = false
    local hit_unit_name = "None"

    if hit_u and is_valid_entity(hit_u) then
        hit_unit_name = (NPC.GetUnitName and NPC.GetUnitName(hit_u)) or "Unit"
        if target and hit_u == target then
            is_target_hit = true
        elseif NPC.IsHero and NPC.IsHero(hit_u) then
            local same_team = Entity.IsSameTeam(my_hero, hit_u)
            if (in_flight_hook.is_ally_mode and same_team) or ((not in_flight_hook.is_ally_mode) and (not same_team)) then
                is_other_hero_hit = true
            end
        end
    end

    -- Fallback geometrico: se il gancio è passato a distanza <= (hook_width + 20) dal bersaglio senza ostacoli davanti
    if not hit_u and target and is_valid_entity(target) and in_flight_hook.min_dist_to_target <= (in_flight_hook.hook_width + 18) then
        is_target_hit = true
        hit_u = target
        hit_unit_name = in_flight_hook.target_name
        in_flight_hook.hit_pos = in_flight_hook.target_pos_at_closest or Entity.GetAbsOrigin(target)
    end

    if is_target_hit or is_other_hero_hit then
        -- =====================================================================
        -- CASO 1: GANCIO DI SUCCESSO (HIT!)
        -- =====================================================================
        hook_stats.hits = hook_stats.hits + 1
        local hit_rate = (hook_stats.hits / math.max(1, hook_stats.total_fired)) * 100.0
        local actual_pos = in_flight_hook.hit_pos or (hit_u and Entity.GetAbsOrigin(hit_u)) or aim_pos
        local geom_err = dist_2d(aim_pos, actual_pos)
        local geom_acc = clamp(100.0 - (geom_err / math.max(150.0, in_flight_hook.pred_dist)) * 100.0, 50.0, 100.0)

        local why_succeeded = ""
        local intent = tostring(in_flight_hook.intent)
        if in_flight_hook.is_manual then
            why_succeeded = "Gancio lanciato MANUALMENTE dal giocatore (premendo Q). Nessuna interferenza o blocco da parte dello script AI: il gancio è andato perfettamente a segno!"
        elseif intent == "FARMING" then
            why_succeeded = string.format(
                "Il motore delle intenzioni ha rilevato correttamente lo stato `FARMING` (avvicinamento/attacco al creep per il last-hit), anticipando il punto di arresto del bersaglio con uno scarto geometrico di soli `%.0f` unità su `%.0f` di distanza (`%.1f%%` precisione spaziale).",
                geom_err, in_flight_hook.pred_dist, geom_acc
            )
        elseif intent == "RETREATING" then
            why_succeeded = string.format(
                "Il classificatore ha individuato l'intenzione `RETREATING` (fuga verso torre/fontana alleata). Il pathfinding simulato ha seguito il corridoio di ritirata della mappa, intercettando il nemico dopo `%.2fs` di volo con errore di soli `%.0f` unità.",
                flight_time, geom_err
            )
        elseif intent == "PUSHING" then
            why_succeeded = string.format(
                "Rilevata intenzione `PUSHING` sull'ondata/struttura: lo script ha atteso una linea di tiro libera dai creep (`%s`) e ha colpito il bersaglio con precisione geometrica del `%.1f%%`.",
                tostring(in_flight_hook.edge_reason), geom_acc
            )
        elseif intent == "LOCKED" or intent == "TIMED_SETUP" then
            why_succeeded = string.format(
                "Sincronizzazione perfetta su bersaglio immobilizzato/in animazione (`%s`), tempo di volo calcolato al millisecondo (`%.2fs`).",
                intent, flight_time
            )
        else
            why_succeeded = string.format(
                "Il risolutore balistico iterativo + pathfinding topologico ha previsto la traiettoria di movimento (`%s`, velocità al lancio `%.0f` MS) con uno scarto di soli `%.0f` unità rispetto al centro dell'hitbox (`%.1f%%` accuratezza).",
                intent, in_flight_hook.target_launch_speed, geom_err, geom_acc
            )
        end

        if string.find(tostring(in_flight_hook.edge_reason), "EDGE_SNIPE", 1, true) then
            why_succeeded = why_succeeded .. " Determinante l'intervento dell'**Edge-Sniping** (`" .. tostring(in_flight_hook.edge_reason) .. "`) che ha curvato l'angolo di mira sul bordo dell'hitbox per aggirare un creep vicino."
        end

        local md = string.format(
[[### ✅ Evento #%02d [HOOK SUCCESS — HIT #%d] — Clock `%s`
- **Bersaglio Colpito**: `%s` | **Modalità**: `%s` | **Precisione Sessione (Hit Rate)**: **`%.1f%%`** (`%d/%d` a segno, `%d` stoppati)
- **Telemetria al Lancio**: Confidenza: `%d%%` | Intenzione: `%s` | Attesa Finestra: `%.2fs` | Trajectory Mode: `%s`
- **Balistica & Cinematica**: Distanza: `%.0f` unità | Tempo di Volo: `%.2fs` | Velocità Bersaglio al Lancio: `%.0f` MS | Scarto Predizione: `%.0f` unità (`%.1f%%`)
- **Perché ha avuto successo**: %s
- **Valutazione Parametri**: Taratura ottimale per questo scenario; il rilascio dopo `%.2fs` con confidenza `%d%%` ha garantito l'impatto.
]],
            hook_stats.event_seq,
            hook_stats.hits,
            format_game_clock(now),
            hit_unit_name,
            in_flight_hook.is_ally_mode and "ALLY SAVE" or "ENEMY HOOK",
            hit_rate, hook_stats.hits, hook_stats.total_fired, hook_stats.stop_cancels,
            in_flight_hook.confidence,
            intent,
            in_flight_hook.wait_time,
            tostring(in_flight_hook.edge_reason),
            in_flight_hook.pred_dist,
            flight_time,
            in_flight_hook.target_launch_speed,
            geom_err,
            geom_acc,
            why_succeeded,
            in_flight_hook.wait_time,
            in_flight_hook.confidence
        )

        local summary = string.format(
            "[PUDGE_LOG_MD] #%02d [SUCCESS HIT] Target=%s | Dist=%.0f | Err=%.0f | Conf=%d%% | Intent=%s | HitRate=%.1f%%",
            hook_stats.event_seq, hit_unit_name, in_flight_hook.pred_dist, geom_err, in_flight_hook.confidence, intent, hit_rate
        )
        write_to_logspudge_md(md, summary)
    else
        -- =====================================================================
        -- CASO 2: GANCIO FALLITO (MISS O BLOCCATO DA CREEP IN VOLO)
        -- =====================================================================
        hook_stats.misses = hook_stats.misses + 1
        local hit_rate = (hook_stats.hits / math.max(1, hook_stats.total_fired)) * 100.0

        local t_closest = in_flight_hook.target_pos_at_closest or (target and is_valid_entity(target) and Entity.GetAbsOrigin(target)) or aim_pos
        local s_target, perp_miss = point_to_ray_2d(
            t_closest.x, t_closest.y,
            pudge_pos.x, pudge_pos.y,
            in_flight_hook.dir_x, in_flight_hook.dir_y
        )
        local along_ray_err = in_flight_hook.pred_dist - s_target

        local fail_category = ""
        local fail_explanation = ""
        local improvement_action = ""

        if in_flight_hook.is_manual then
            fail_category = "MANUAL_Q_SHOT (Lancio Manuale)"
            fail_explanation = string.format(
                "Gancio lanciato MANUALMENTE dal giocatore (premendo Q). Lo script AI non ha bloccato né fermato il lancio (distanza minima: %.0f unità).",
                in_flight_hook.min_dist_to_target
            )
            improvement_action = "Lancio manuale del giocatore: per i tiri lunghi o complessi puoi usare la mira automatica (Mouse 4) che calcola il pathfinding e l'anticipo balistico."
        elseif hit_u and hit_unit_name ~= "None" then
            -- Fallito perché un creep o unità non voluta ha intercettato il gancio in volo
            fail_category = "BLOCKED_BY_UNIT_IN_FLIGHT (" .. hit_unit_name .. ")"
            fail_explanation = string.format(
                "Il gancio era diretto su `%s`, ma durante i `%.2fs` di volo (dopo la fine del cast point di 0.30s) l'unità `%s` si è mossa dentro il corridoio intercettando la punta del gancio.",
                in_flight_hook.target_name, flight_time, hit_unit_name
            )
            improvement_action = "Aumentare `Creep Avoidance Safety Margin` (es. da 18 a 28 unità) e ampliare il fattore di proiezione della velocità dei creep durante il tempo di volo `t_impact`."
        elseif in_flight_hook.stopped_unexpectedly or (in_flight_hook.target_launch_speed > 110 and along_ray_err > 85) then
            -- Fallito per Overshoot: il nemico correva ma si è fermato di colpo mentre il gancio era in volo
            fail_category = "OVERSHOOT_TARGET_STOPPED"
            fail_explanation = string.format(
                "Al lancio il bersaglio si muoveva a `%.0f` MS (Intenzione: `%s`), quindi lo script ha calcolato l'anticipo (`lead`) a `%.0f` unità. Tuttavia durante il volo il bersaglio si è fermato improvvisamente (`%.0f` MS all'impatto), facendo passare il gancio **davanti a lui** di `%.0f` unità (distanza laterale `%.0f` unità).",
                in_flight_hook.target_launch_speed, tostring(in_flight_hook.intent), in_flight_hook.pred_dist,
                in_flight_hook.target_speed_at_closest, along_ray_err, perp_miss
            )
            improvement_action = "In `compute_optimal_hook_solution`, aumentare il peso del centroide multi-ipotesi (che include l'ipotesi di arresto improvviso) da `0.28` a `0.38` quando il bersaglio si trova vicino a creep o sotto torre."
        elseif in_flight_hook.started_from_idle or (in_flight_hook.target_launch_speed < 30 and along_ray_err < -85) then
            -- Fallito per Undershoot: il nemico era fermo ed è ripartito subito dopo la partenza del gancio
            fail_category = "UNDERSHOOT_STARTED_FROM_IDLE"
            fail_explanation = string.format(
                "Al momento del lancio il bersaglio era fermo (`%.0f` MS, Intenzione: `%s`), ma ha iniziato a muoversi subito dopo che il gancio ha lasciato la mano di Pudge (raggiungendo `%.0f` MS), facendo passare il gancio **dietro di lui** di `%.0f` unità.",
                in_flight_hook.target_launch_speed, tostring(in_flight_hook.intent),
                in_flight_hook.target_speed_at_closest, math.abs(along_ray_err)
            )
            improvement_action = "Ridurre la durata stimata di `anim_lock_until` per gli attacchi base da `0.32s` a `0.22s`, così da non considerare il bersaglio fermo quando la sua animazione di last-hit sta già terminando."
        elseif in_flight_hook.max_angle_change_deg >= 32 then
            -- Fallito per cambio di direzione / schivata reattiva mentre il gancio era in volo
            fail_category = string.format("REACTIVE_DODGE_OR_JUKE (Cambio direzione %.0f°)", in_flight_hook.max_angle_change_deg)
            fail_explanation = string.format(
                "Dopo la partenza del proiettile (tempo di volo `%.2fs` su distanza `%.0f` unità), il bersaglio ha deviato la propria direzione di marcia di **`%.0f°`**, spostandosi lateralmente di `%.0f` unità fuori dal raggio di cattura (`%d` unità). Inversioni pre-lancio registrate: `%d`.",
                flight_time, in_flight_hook.pred_dist, in_flight_hook.max_angle_change_deg,
                perp_miss, in_flight_hook.hook_width, in_flight_hook.target_launch_reversals
            )
            if in_flight_hook.target_launch_reversals >= 1 then
                improvement_action = "Il bersaglio aveva già effettuato inversioni prima del lancio (`juke_reversals >= 1`): aumentare la penalità di confidenza per `JUKING` in modo da attendere altri 0.25s di stabilizzazione direzionale prima di lanciare."
            else
                improvement_action = "Schivata reattiva pura del nemico a distanza `" .. string.format("%.0f", in_flight_hook.pred_dist) .. "` unità: per bersagli a lunga distanza (> 950 unità) in piena visione, privilegiare il lancio da Fog of War / Highground o attendere un'animazione di attacco/cast (`FARMING` / `LOCKED`)."
            end
        elseif in_flight_hook.max_speed_delta >= 45 then
            -- Fallito per variazione improvvisa di velocità o spell di mobilità
            fail_category = string.format("SPEED_SURGE_OR_MOBILITY_SPELL (Delta %.0f MS)", in_flight_hook.max_speed_delta)
            fail_explanation = string.format(
                "Durante il volo del gancio la velocità del bersaglio è variata di `%.0f` unità/s (da `%.0f` MS a `%.0f` MS) o ha utilizzato un'abilità di spostamento rapido, causando uno scarto al punto d'impatto di `%.0f` unità.",
                in_flight_hook.max_speed_delta, in_flight_hook.target_launch_speed,
                in_flight_hook.target_speed_at_closest, in_flight_hook.min_dist_to_target
            )
            improvement_action = "Integrare il controllo dei cooldown dei buff di velocità (es. Phase Boots, Surge, Windrun) o ridurre il tempo di volo massimo per bersagli ad alta mobilità."
        else
            -- Deviazione topologica / imprecisione di allineamento
            fail_category = "PATH_DEVIATION_OR_RANGE_LIMIT"
            fail_explanation = string.format(
                "Il gancio è passato a una distanza minima di `%.0f` unità dal bersaglio (scarto laterale `%.0f` unità, scarto longitudinale `%.0f` unità) su una distanza di tiro di `%.0f` unità.",
                in_flight_hook.min_dist_to_target, perp_miss, along_ray_err, in_flight_hook.pred_dist
            )
            improvement_action = "Affinare il coefficiente di smorzamento `turn_damping` nel pathfinding simulato per allineare la curvatura della traiettoria."
        end

        local md = string.format(
[[### ❌ Evento #%02d [HOOK FAILED — MISS #%d] — Clock `%s`
- **Bersaglio Mancato**: `%s` | **Modalità**: `%s` | **Precisione Sessione (Hit Rate)**: **`%.1f%%`** (`%d/%d` a segno, `%d` stoppati)
- **Causa Principale Fallimento**: **`%s`**
- **Telemetria al Lancio**: Confidenza: `%d%%` | Intenzione: `%s` | Attesa Finestra: `%.2fs` | Distanza Tiro: `%.0f` unità (`TOF: %.2fs`)
- **Cinematica Lancio vs Impatto**: Speed Lancio: `%.0f` MS $\rightarrow$ Speed Impatto: `%.0f` MS | Max Cambio Angolo in Volo: `%.0f°` | Distanza Minima dal Gancio: `%.0f` unità (Laterale: `%.0f`, Longitudinale: `%+.0f`)
- **Analisi Dettagliata dell'Errore (Perché ha fallito)**: %s
- **Azione Correttiva per Migliorare lo Script**: %s
]],
            hook_stats.event_seq,
            hook_stats.misses,
            format_game_clock(now),
            in_flight_hook.target_name,
            in_flight_hook.is_ally_mode and "ALLY SAVE" or "ENEMY HOOK",
            hit_rate, hook_stats.hits, hook_stats.total_fired, hook_stats.stop_cancels,
            fail_category,
            in_flight_hook.confidence,
            tostring(in_flight_hook.intent),
            in_flight_hook.wait_time,
            in_flight_hook.pred_dist,
            in_flight_hook.expected_tof,
            in_flight_hook.target_launch_speed,
            in_flight_hook.target_speed_at_closest,
            in_flight_hook.max_angle_change_deg,
            in_flight_hook.min_dist_to_target,
            perp_miss,
            along_ray_err,
            fail_explanation,
            improvement_action
        )

        local summary = string.format(
            "[PUDGE_LOG_MD] #%02d [FAILED MISS] Target=%s | Cause=%s | MinDist=%.0f | Perp=%.0f | Along=%+.0f | AngleDelta=%.0f deg | HitRate=%.1f%%",
            hook_stats.event_seq, in_flight_hook.target_name, fail_category,
            in_flight_hook.min_dist_to_target, perp_miss, along_ray_err, in_flight_hook.max_angle_change_deg, hit_rate
        )
        write_to_logspudge_md(md, summary)
    end
end

--- Aggiorna ad ogni tick il monitoraggio del gancio in volo e rileva impatti su eroi o creep
local function update_in_flight_hook_telemetry(my_hero, hook_ab, now)
    if not in_flight_hook.active then return end

    local flight_elapsed = now - in_flight_hook.launch_time
    local max_tof = (in_flight_hook.max_range / in_flight_hook.hook_speed)

    -- Posizione istantanea della punta del gancio lungo il raggio di lancio
    local hook_s = math.min(in_flight_hook.max_range, flight_elapsed * in_flight_hook.hook_speed)
    local hx = in_flight_hook.pudge_pos.x + in_flight_hook.dir_x * hook_s
    local hy = in_flight_hook.pudge_pos.y + in_flight_hook.dir_y * hook_s
    local hook_tip = Vector(hx, hy, in_flight_hook.pudge_pos.z)

    -- 1. Monitora il comportamento reale del bersaglio durante il volo (cambi direzione, stop, accelerazioni)
    local target = in_flight_hook.target
    if target and is_valid_entity(target) and not Entity.IsDormant(target) then
        local t_pos = Entity.GetAbsOrigin(target)
        if t_pos then
            local d_ht = dist_2d(hook_tip, t_pos)
            local idx = Entity.GetIndex(target)
            local tr = idx and hero_trackers[idx]
            local cur_speed = tr and tr.speed or 0
            local cur_angle = tr and tr.move_angle or 0

            if d_ht < in_flight_hook.min_dist_to_target then
                in_flight_hook.min_dist_to_target = d_ht
                in_flight_hook.closest_hook_pos = hook_tip
                in_flight_hook.target_pos_at_closest = t_pos
                in_flight_hook.target_speed_at_closest = cur_speed
                in_flight_hook.target_angle_at_closest = cur_angle
            end

            if in_flight_hook.target_launch_speed > 35 and cur_speed > 35 then
                local ang_deg = math.deg(math.abs(angle_diff_rad(in_flight_hook.target_launch_angle, cur_angle)))
                if ang_deg > in_flight_hook.max_angle_change_deg then
                    in_flight_hook.max_angle_change_deg = ang_deg
                end
            end

            local spd_delta = math.abs(cur_speed - in_flight_hook.target_launch_speed)
            if spd_delta > in_flight_hook.max_speed_delta then
                in_flight_hook.max_speed_delta = spd_delta
            end

            if in_flight_hook.target_launch_speed > 115 and cur_speed < 25 and flight_elapsed > 0.08 then
                in_flight_hook.stopped_unexpectedly = true
            end
            if in_flight_hook.target_launch_speed < 25 and cur_speed > 115 and flight_elapsed > 0.08 then
                in_flight_hook.started_from_idle = true
            end
        end
    end

    -- 2. Controlla se un eroe o un creep ha ricevuto il modifier `modifier_pudge_meat_hook`
    if Heroes and Heroes.GetAll then
        for _, h in ipairs(Heroes.GetAll()) do
            if h ~= my_hero and is_valid_entity(h) and NPC.HasModifier and NPC.HasModifier(h, "modifier_pudge_meat_hook") then
                in_flight_hook.hit_unit = h
                in_flight_hook.hit_pos = Entity.GetAbsOrigin(h)
                in_flight_hook.hit_time = now
                finalize_in_flight_hook(my_hero, now)
                return
            end
        end
    end

    if NPCs and NPCs.GetAll then
        local ok_npcs, all_npcs = pcall(NPCs.GetAll)
        if ok_npcs and all_npcs then
            for _, u in ipairs(all_npcs) do
                if u ~= my_hero and is_valid_entity(u) and NPC.HasModifier and NPC.HasModifier(u, "modifier_pudge_meat_hook") then
                    in_flight_hook.hit_unit = u
                    in_flight_hook.hit_pos = Entity.GetAbsOrigin(u)
                    in_flight_hook.hit_time = now
                    finalize_in_flight_hook(my_hero, now)
                    return
                end
            end
        end
    end

    -- 3. Quando il gancio ha completato la corsa di andata (max_tof + 0.12s), finalizza il report Post-Mortem
    if flight_elapsed > (max_tof + 0.12) then
        finalize_in_flight_hook(my_hero, now)
    end
end

-- =============================================================================
-- MODULO 6: STOP-CANCEL DELL'ANIMAZIONE DEL GANCIO (ANTI-MISS IN 0.3s CAST POINT)
-- =============================================================================

--- Monitora ad ogni tick (`OnUpdate`) se Pudge sta eseguendo il Cast Point di Meat Hook (0.3s).
--- Se il gancio in canna non colpirà più il bersaglio (perché ha schivato, si è fermato, ha usato Blink
--- o un creep si è messo in mezzo), invia all'istante `Player.HoldPosition` per fermare l'animazione!
local function evaluate_and_cancel_hook_animation(my_hero, hook_ab, now)
    if not my_hero or not hook_ab then return false end

    local in_phase = Ability.IsInAbilityPhase and Ability.IsInAbilityPhase(hook_ab)
    if not in_phase then
        -- Se nel frame precedente eravamo in fase di cast e ora `in_phase` è diventato false:
        -- se NON abbiamo annullato noi il cast e l'abilità è entrata in cooldown, il gancio è appena PARTITO in volo!
        if active_hook_cast.in_phase then
            active_hook_cast.in_phase = false
            pending_script_cast.active = false
            local just_cancelled = (now - (active_hook_cast.last_cancel_time or 0)) < 0.18
            local entered_cooldown = not Ability.IsReady(hook_ab)
            if (not just_cancelled) and entered_cooldown then
                start_in_flight_hook_tracking(my_hero, hook_ab, active_hook_cast, now)
            end
        elseif pending_script_cast.active and (now - (pending_script_cast.order_time or 0)) > 0.70 then
            -- Scaduto il tempo massimo di rotazione pre-cast
            pending_script_cast.active = false
        end
        return false
    end

    local pudge_pos = Entity.GetAbsOrigin(my_hero)
    if not pudge_pos then return false end

    local max_range, hook_speed, hook_width, cast_point = get_hook_parameters(my_hero, hook_ab)

    -- Se è appena iniziata l'animazione di cast (anche dopo una rotazione di 0.15s - 0.50s di Pudge!)
    if not active_hook_cast.in_phase then
        active_hook_cast.in_phase = true
        active_hook_cast.start_time = now
        active_hook_cast.cast_point = cast_point
        active_hook_cast.origin_pos = pudge_pos

        -- Determina con certezza assoluta se il cast proviene dallo script (`pending_script_cast`) o da Q manuale
        local has_pending_script = pending_script_cast.active and ((now - (pending_script_cast.order_time or 0)) <= 0.68)
        local is_recent_script = (now - aim_session.last_cast_order_time <= 0.55) and (script_cast_order_active or has_pending_script)
        local is_manual_q = (now - manual_q_pressed_time < 1.2) and (not has_pending_script)

        if (not is_manual_q) and (has_pending_script or (is_recent_script and aim_session.active and aim_session.locked_target)) then
            local tgt = (has_pending_script and pending_script_cast.target) or aim_session.locked_target
            local ap = (has_pending_script and pending_script_cast.aim_pos) or aim_session.best_aim_pos or (tgt and Entity.GetAbsOrigin(tgt))
            local tgt_idx = tgt and Entity.GetIndex(tgt)
            local tgt_tr = tgt_idx and hero_trackers[tgt_idx]

            active_hook_cast.is_script_cast = true
            active_hook_cast.is_manual = false
            active_hook_cast.target = tgt
            active_hook_cast.is_ally_mode = has_pending_script and pending_script_cast.is_ally_mode or (aim_session.mode == "ALLY")
            active_hook_cast.aim_pos = ap
            if ap then
                active_hook_cast.dir_x, active_hook_cast.dir_y = normalize_2d(ap.x - pudge_pos.x, ap.y - pudge_pos.y)
            else
                active_hook_cast.dir_x, active_hook_cast.dir_y = get_unit_forward_2d(my_hero)
            end
            active_hook_cast.confidence = (has_pending_script and pending_script_cast.confidence) or aim_session.best_confidence or 0
            active_hook_cast.intent = (has_pending_script and pending_script_cast.intent) or aim_session.best_intent or "UNKNOWN"
            active_hook_cast.wait_time = (has_pending_script and pending_script_cast.wait_time) or math.max(0, now - (aim_session.start_time or now))
            active_hook_cast.edge_reason = (has_pending_script and pending_script_cast.edge_reason) or aim_session.block_reason or "CLEAR"
            active_hook_cast.launch_speed = (has_pending_script and pending_script_cast.launch_speed) or (tgt_tr and tgt_tr.speed) or 0
            pending_script_cast.active = false
        else
            -- LANCIO MANUALE DEL GIOCATORE (Premendo Q o cliccando l'abilità)
            active_hook_cast.is_script_cast = false
            active_hook_cast.is_manual = true
            local fx, fy = get_unit_forward_2d(my_hero)
            active_hook_cast.dir_x, active_hook_cast.dir_y = fx, fy
            active_hook_cast.aim_pos = Vector(pudge_pos.x + fx * max_range, pudge_pos.y + fy * max_range, pudge_pos.z)
            active_hook_cast.is_ally_mode = false
            active_hook_cast.confidence = 100
            active_hook_cast.intent = "MANUAL_Q"
            active_hook_cast.wait_time = 0
            active_hook_cast.edge_reason = "MANUAL_PLAYER"
            active_hook_cast.target = nil
            active_hook_cast.launch_speed = 0
        end
    else
        -- Aggiorna la direzione reale di Pudge man mano che completa la rotazione
        local fx, fy = get_unit_forward_2d(my_hero)
        if active_hook_cast.aim_pos then
            active_hook_cast.dir_x, active_hook_cast.dir_y = normalize_2d(
                active_hook_cast.aim_pos.x - pudge_pos.x,
                active_hook_cast.aim_pos.y - pudge_pos.y
            )
        else
            active_hook_cast.dir_x, active_hook_cast.dir_y = fx, fy
        end
    end

    -- REGOLA FONDAMENTALE UTENTE:
    -- Se il gancio è stato lanciato manualmente (ovvero premendo Q), non deve MAI essere bloccato né fermato!
    if active_hook_cast.is_manual or not active_hook_cast.is_script_cast or (ui.never_cancel_manual and ui.never_cancel_manual:Get()) then
        if active_hook_cast.is_manual or not active_hook_cast.is_script_cast then
            return false
        end
    end

    if not ui.auto_cancel:Get() then return false end

    local target = active_hook_cast.target
    if not target then return false end

    -- Controlliamo già dopo 0.03s dall'inizio della fase per massimizzare il tempo di reazione dello Stop-Cancel
    local elapsed = now - active_hook_cast.start_time
    if elapsed < 0.03 then return false end
    local remaining_cast = math.max(0.01, active_hook_cast.cast_point - elapsed)

    local should_cancel = false
    local cancel_reason = ""

    -- 1. Se il bersaglio è morto o diventato completamente invulnerabile fuori tempo
    if not Entity.IsAlive(target) then
        should_cancel = true
        cancel_reason = "Target Died"
    elseif not Entity.IsDormant(target) and NPC.IsVisible(target) then
        local t_pos = Entity.GetAbsOrigin(target)
        local dir_x, dir_y = active_hook_cast.dir_x, active_hook_cast.dir_y
        local s_now, perp_now = point_to_ray_2d(t_pos.x, t_pos.y, pudge_pos.x, pudge_pos.y, dir_x, dir_y)

        -- Tempo rimanente totale prima che la punta del gancio arrivi alla distanza del bersaglio
        local rem_total_time = remaining_cast + (math.max(50, s_now) / hook_speed)

        local idx = Entity.GetIndex(target)
        local tr = idx and hero_trackers[idx]
        local intent, intent_pos, intent_param = analyze_hero_intent(target, tr, my_hero, now, rem_total_time)

        -- Ricalcola la posizione futura del bersaglio al tempo residuo `rem_total_time`
        local updated_pred_pos = simulate_pathfinding_trajectory(
            target, tr, rem_total_time, intent, intent_pos, intent_param
        ) or t_pos

        local s_pred, perp_pred = point_to_ray_2d(
            updated_pred_pos.x, updated_pred_pos.y,
            pudge_pos.x, pudge_pos.y,
            dir_x, dir_y
        )

        local cancel_tol = ui.cancel_margin:Get() or 96
        local cur_spd = (tr and tr.speed) or 0
        local launch_spd = active_hook_cast.launch_speed or 0
        local aim_shift = active_hook_cast.aim_pos and dist_2d(updated_pred_pos, active_hook_cast.aim_pos) or 0

        -- A. Bersaglio uscito dal corridoio laterale del gancio (ha cambiato direzione o si è fermato!)
        if perp_pred > cancel_tol then
            should_cancel = true
            cancel_reason = string.format("Target Dodged Laterally (%.0f > %d units)", perp_pred, cancel_tol)
        -- B. Anti-Overshoot: il bersaglio correva quando abbiamo ordinato il cast, ma si è FERMATO durante il Cast Point (0.3s)
        --    e la sua posizione attuale è fuori dal raggio di cattura del gancio!
        elseif launch_spd > 110 and cur_spd < 25 and perp_now > (cancel_tol - 8) then
            should_cancel = true
            cancel_reason = string.format("Target Stopped During Cast Point (perp %.0f)", perp_now)
        -- C. Anti-Undershoot: il bersaglio era fermo quando abbiamo ordinato il cast, ma è PARTITO a correre durante il Cast Point!
        elseif launch_spd < 35 and cur_spd > 150 and (perp_pred > (cancel_tol - 10) or aim_shift > (cancel_tol + 25)) then
            should_cancel = true
            cancel_reason = string.format("Target Started Moving During Cast Point (shift %.0f)", aim_shift)
        -- D. Bersaglio uscito oltre la portata massima del gancio o passato dietro Pudge
        elseif s_pred <= 0 or s_pred > (max_range + hook_width * 0.60) then
            should_cancel = true
            cancel_reason = "Target Out of Hook Distance"
        else
            -- E. Controllo che un creep o un'altra unità non si sia appena messa davanti!
            local obstacles = collect_hook_obstacles(my_hero, target, max_range)
            local clear, _, blk_name = is_hook_corridor_clear(
                pudge_pos, dir_x, dir_y, s_pred, remaining_cast, hook_speed, hook_width, obstacles
            )
            if not clear then
                should_cancel = true
                cancel_reason = "Obstacle Entered Line (" .. tostring(blk_name) .. ")"
            end
        end
    end

    if should_cancel and (now - active_hook_cast.last_cancel_time > 0.12) then
        local my_player = Players and Players.GetLocal and Players.GetLocal()
        if my_player and Player and Player.HoldPosition then
            Player.HoldPosition(my_player, my_hero, false, false, true)
        elseif my_player and Player and Player.PrepareUnitOrders and Enum and Enum.UnitOrder then
            Player.PrepareUnitOrders(
                my_player,
                Enum.UnitOrder.DOTA_UNIT_ORDER_STOP,
                nil,
                Vector(0, 0, 0),
                nil,
                Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                my_hero,
                false,
                false,
                true
            )
        end

        active_hook_cast.last_cancel_time = now
        active_hook_cast.in_phase = false
        pending_script_cast.active = false
        notify_user(string.format("[PudgeHook AI] STOPPED HOOK ANIMATION -> %s", cancel_reason))
        log_stop_cancel_to_file(active_hook_cast, cancel_reason, now)
        return true
    end

    return false
end

-- =============================================================================
-- SELEZIONE DEL BERSAGLIO DAL CURSORE (MOUSE 4 = NEMICO, MOUSE 3 = ALLEATO)
-- =============================================================================

--- Seleziona il miglior eroe (nemico per Mouse 4, alleato per Mouse 3) vicino al cursore
local function acquire_target_near_cursor(my_hero, is_ally_mode, max_range)
    if not Input or not Input.GetWorldCursorPos or not Heroes or not Heroes.GetAll then
        return nil
    end

    local ok_c, cursor_pos = pcall(Input.GetWorldCursorPos)
    if not ok_c or not cursor_pos then return nil end

    local pudge_pos = Entity.GetAbsOrigin(my_hero)
    if not pudge_pos then return nil end

    local search_rad = ui.cursor_search_radius:Get() or 650
    local c_dx, c_dy, c_dist = normalize_2d(cursor_pos.x - pudge_pos.x, cursor_pos.y - pudge_pos.y)

    local best_hero = nil
    local best_score = 999999

    for _, hero in ipairs(Heroes.GetAll()) do
        if hero and hero ~= my_hero and is_valid_entity(hero) and NPC.IsVisible(hero) then
            local same_team = Entity.IsSameTeam(my_hero, hero)
            local valid_team = (is_ally_mode and same_team) or ((not is_ally_mode) and (not same_team))

            if valid_team then
                -- Ignora illusioni se stiamo cercando un eroe reale
                local is_illusion = NPC.IsIllusion and NPC.IsIllusion(hero)
                if not is_illusion then
                    local h_pos = Entity.GetAbsOrigin(hero)
                    if h_pos then
                        local dist_from_pudge = dist_2d(pudge_pos, h_pos)
                        if dist_from_pudge <= max_range + 300 then
                            local dist_from_cursor = dist_2d(cursor_pos, h_pos)
                            local proj_s, perp_to_cursor_ray = point_to_ray_2d(
                                h_pos.x, h_pos.y, pudge_pos.x, pudge_pos.y, c_dx, c_dy
                            )

                            -- Accetta il bersaglio solo se è realmente vicino al cursore (evita di agganciare
                            -- un eroe a 900 unità dal cursore solo perché passa sul raggio Pudge->Cursore!)
                            local in_tight_cone = (proj_s > 0 and perp_to_cursor_ray <= 145 and math.abs(proj_s - c_dist) <= 280)
                            if dist_from_cursor <= search_rad or in_tight_cone then
                                local score = dist_from_cursor + perp_to_cursor_ray * 0.22
                                if score < best_score then
                                    best_score = score
                                    best_hero = hero
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return best_hero
end

-- =============================================================================
-- CALLBACK PRINCIPALE: OnUpdate (60-120Hz)
-- =============================================================================
function PudgeHook.OnUpdate()
    if not ui.enabled:Get() then return end
    if not Engine or not Engine.IsInGame or not Engine.IsInGame() then return end

    local now = get_time()

    -- Gestione Live Rebind In-Game (cattura qualsiasi tasto tastiera o mouse premuto in partita)
    if keybind_state.rebinding_target then
        local elapsed_rebind = now - (keybind_state.rebind_start_time or 0)
        if elapsed_rebind > 12.0 then
            keybind_state.rebinding_target = nil
            pcall(function() ui.rebind_enemy_live:Set(false) end)
            pcall(function() ui.rebind_ally_live:Set(false) end)
            notify_user("[PudgeHook AI] Live Rebind scaduto (nessun tasto premuto entro 12s).")
            return
        elseif elapsed_rebind > 0.25 and Input and Input.IsKeyDown then
            -- ESC (70) annulla il rebind
            local ok_esc, esc_down = pcall(Input.IsKeyDown, 70)
            if ok_esc and esc_down then
                keybind_state.rebinding_target = nil
                pcall(function() ui.rebind_enemy_live:Set(false) end)
                pcall(function() ui.rebind_ally_live:Set(false) end)
                notify_user("[PudgeHook AI] Live Rebind annullato con ESC.")
                return
            end
            -- Scansiona tutti i ButtonCode_t (1..325), escludendo Mouse 1 (314) e Mouse 2 (315)
            for code = 1, 325 do
                if code ~= 70 and code ~= 314 and code ~= 315 then
                    local ok_k, is_down = pcall(Input.IsKeyDown, code)
                    if ok_k and is_down then
                        apply_live_rebind_key(keybind_state.rebinding_target, code)
                        return
                    end
                end
            end
        end
        return
    end

    local my_hero = Heroes.GetLocal()
    if not is_valid_entity(my_hero) or NPC.GetUnitName(my_hero) ~= HERO_NAME then
        aim_session.active = false
        active_hook_cast.in_phase = false
        pending_script_cast.active = false
        in_flight_hook.active = false
        return
    end

    -- 1. Aggiorna cache torri della mappa e cinematica di tutti gli eroi visibili
    update_map_towers_cache(now)
    update_hero_kinematics(now)

    local hook_ab = NPC.GetAbility(my_hero, HOOK_ABILITY_NAME)
    if not hook_ab or Ability.GetLevel(hook_ab) <= 0 then
        aim_session.active = false
        return
    end

    -- 1b. Aggiorna telemetria del gancio attualmente in volo (per logspudge.md)
    update_in_flight_hook_telemetry(my_hero, hook_ab, now)

    -- 2. Controllo prioritario: Stop-Cancel se il gancio è già in fase di cast (0.3s) e sta per missare!
    if evaluate_and_cancel_hook_animation(my_hero, hook_ab, now) then
        return
    end

    -- Se il gancio è attualmente in fase di cast (e sta andando a segno!), non inviare altri ordini
    if Ability.IsInAbilityPhase and Ability.IsInAbilityPhase(hook_ab) then
        return
    end

    -- 3. Rileva pressione del tasto configurato per Nemici (default Mouse 4) o Alleati (default Mouse 3)
    local enemy_held = is_bind_or_mouse_held(ui.enemy_key, true)
    local ally_held = is_bind_or_mouse_held(ui.ally_key, false)

    if not enemy_held and not ally_held then
        aim_session.active = false
        aim_session.locked_target = nil
        aim_session.best_aim_pos = nil
        aim_session.best_confidence = 0
        aim_session.peak_confidence = 0
        return
    end

    -- Verifica che Meat Hook sia pronto e lanciabile (mana e cooldown) e Pudge non sia stunnato/silenziato
    local mana = NPC.GetMana(my_hero)
    if not Ability.IsReady(hook_ab) or not Ability.IsCastable(hook_ab, mana) then
        return
    end
    if NPC.IsStunned(my_hero) or NPC.IsSilenced(my_hero) then
        return
    end

    local desired_mode = enemy_held and "ENEMY" or "ALLY"
    local is_ally_mode = (desired_mode == "ALLY")
    local max_range = get_hook_parameters(my_hero, hook_ab)

    -- 4. Avvio o mantenimento della sessione di mira (finestra massima 3.0 secondi)
    local cursor_candidate = acquire_target_near_cursor(my_hero, is_ally_mode, max_range)
    if not aim_session.active or aim_session.mode ~= desired_mode then
        aim_session.active = true
        aim_session.mode = desired_mode
        aim_session.start_time = now
        aim_session.peak_confidence = 0
        aim_session.locked_target = cursor_candidate
    else
        -- Se il bersaglio precedente non è più valido/visibile, oppure se l'utente ha spostato
        -- chiaramente il cursore sopra un ALTRO eroe (distanza dal cursore molto inferiore), aggiorna il lock!
        if not aim_session.locked_target or not is_valid_entity(aim_session.locked_target) or not NPC.IsVisible(aim_session.locked_target) then
            aim_session.locked_target = cursor_candidate
        elseif cursor_candidate and cursor_candidate ~= aim_session.locked_target and Input and Input.GetWorldCursorPos then
            local ok_cp, c_pos = pcall(Input.GetWorldCursorPos)
            if ok_cp and c_pos then
                local old_pos = Entity.GetAbsOrigin(aim_session.locked_target)
                local new_pos = Entity.GetAbsOrigin(cursor_candidate)
                if old_pos and new_pos and (dist_2d(c_pos, new_pos) + 160 < dist_2d(c_pos, old_pos)) then
                    aim_session.locked_target = cursor_candidate
                    aim_session.peak_confidence = 0
                end
            end
        end
    end

    local target = aim_session.locked_target
    if not target then
        aim_session.best_confidence = 0
        aim_session.best_intent = "NO_TARGET"
        return
    end

    local elapsed_hold = now - aim_session.start_time
    local max_window_sec = (ui.max_wait_time:Get() or 30) / 10.0

    -- Se abbiamo superato la finestra di 3.0s tenendo premuto, riavvia il ciclo di studio sul bersaglio sotto il cursore
    if elapsed_hold > max_window_sec + 0.15 then
        aim_session.start_time = now
        aim_session.peak_confidence = 0
        elapsed_hold = 0
    end

    -- 5. Calcola la soluzione balistica, il pathfinding e la confidenza sul bersaglio agganciato
    local sol = compute_optimal_hook_solution(my_hero, target, hook_ab, now)
    if not sol then return end

    aim_session.best_aim_pos = sol.aim_pos
    aim_session.best_confidence = sol.confidence
    aim_session.best_intent = sol.intent
    aim_session.best_path = sol.path or {}
    aim_session.is_blocked = sol.is_blocked
    aim_session.block_reason = sol.reason or ""

    if sol.confidence > aim_session.peak_confidence then
        aim_session.peak_confidence = sol.confidence
    end

    -- 6. Decisione di Lancio Ottimale (Optimal Release Engine entro max 3.0s)
    if sol.valid and not sol.is_blocked and sol.aim_pos then
        local min_req_conf = ui.min_confidence:Get() or 75

        local should_fire_now = false

        if sol.confidence >= math.max(85, min_req_conf) then
            -- Colpo eccellente (>= 85%): LANCIA SUBITO!
            should_fire_now = true
        elseif sol.confidence >= min_req_conf then
            -- Colpo sopra la soglia del 75%: lancia se abbiamo osservato almeno 0.08s di stabilità
            -- oppure se siamo vicini al limite dei 3.0 secondi
            if elapsed_hold >= 0.08 or (max_window_sec - elapsed_hold) <= 0.35 then
                should_fire_now = true
            end
        end

        if should_fire_now and (now - aim_session.last_cast_order_time > 0.18) then
            local pudge_pos = Entity.GetAbsOrigin(my_hero)
            local tgt_idx = Entity.GetIndex(target)
            local tgt_tr = tgt_idx and hero_trackers[tgt_idx]
            local cur_tgt_spd = (tgt_tr and tgt_tr.speed) or 0

            -- IMPORTANTE: Registra `last_cast_order_time` e `pending_script_cast` PRIMA di `Ability.CastPosition`
            -- perché `Ability.CastPosition` invoca sincronamente `OnPrepareUnitOrders`!
            script_cast_order_active = true
            aim_session.last_cast_order_time = now

            pending_script_cast.active = true
            pending_script_cast.order_time = now
            pending_script_cast.target = target
            pending_script_cast.aim_pos = sol.aim_pos
            pending_script_cast.is_ally_mode = is_ally_mode
            pending_script_cast.confidence = sol.confidence
            pending_script_cast.intent = sol.intent
            pending_script_cast.wait_time = elapsed_hold
            pending_script_cast.edge_reason = sol.reason or "CLEAR"
            pending_script_cast.launch_speed = cur_tgt_spd

            active_hook_cast.is_script_cast = true
            active_hook_cast.is_manual = false
            active_hook_cast.origin_pos = pudge_pos
            active_hook_cast.aim_pos = sol.aim_pos
            if pudge_pos then
                active_hook_cast.dir_x, active_hook_cast.dir_y = normalize_2d(
                    sol.aim_pos.x - pudge_pos.x,
                    sol.aim_pos.y - pudge_pos.y
                )
            end
            active_hook_cast.target = target
            active_hook_cast.is_ally_mode = is_ally_mode
            active_hook_cast.confidence = sol.confidence
            active_hook_cast.intent = sol.intent
            active_hook_cast.wait_time = elapsed_hold
            active_hook_cast.edge_reason = sol.reason or "CLEAR"
            active_hook_cast.launch_speed = cur_tgt_spd

            -- ESECUZIONE SOLO GANCIO (Nessun movimento di Pudge!)
            Ability.CastPosition(hook_ab, sol.aim_pos, false, false, true)
            script_cast_order_active = false

            local t_name = (NPC.GetUnitName and NPC.GetUnitName(target)) or "Target"
            notify_user(string.format(
                "[PudgeHook AI] FIRING HOOK -> %s | Confidence: %d%% | Intent: %s | Wait: %.2fs",
                t_name, sol.confidence, tostring(sol.intent), elapsed_hold
            ))
        end
    end
end

-- =============================================================================
-- CALLBACK: OnModifierCreate (Rilevamento istantaneo impatto `modifier_pudge_meat_hook`)
-- =============================================================================
function PudgeHook.OnModifierCreate(ent, mod)
    if not ui.enabled:Get() or not in_flight_hook.active then return end
    if not ent or not mod or not Modifier or not Modifier.GetName then return end

    local ok_n, mod_name = pcall(Modifier.GetName, mod)
    if ok_n and mod_name and string.find(mod_name, "meat_hook", 1, true) then
        local my_hero = Heroes and Heroes.GetLocal and Heroes.GetLocal()
        if my_hero and ent ~= my_hero then
            local now = get_time()
            in_flight_hook.hit_unit = ent
            in_flight_hook.hit_pos = Entity.GetAbsOrigin(ent)
            in_flight_hook.hit_time = now
            finalize_in_flight_hook(my_hero, now)
        end
    end
end

-- =============================================================================
-- CALLBACK: OnUnitAnimation (Cattura istantanea Attack Point & Cast Animation)
-- =============================================================================
function PudgeHook.OnUnitAnimation(data)
    if not ui.enabled:Get() then return end
    if not data or not data.unit then return end

    local idx = Entity.GetIndex(data.unit)
    local tr = idx and hero_trackers[idx]
    if not tr then return end

    local now = get_time()
    local seq = string.lower(tostring(data.sequenceName or ""))

    -- Se l'eroe inizia un'animazione di attacco (es. last-hit su un creep!) o di cast,
    -- resterà fermo per la durata reale dell'attack/cast point (non sovrastimata, per evitare falsi LOCKED a 1200+ unità!)
    if string.find(seq, "attack", 1, true) then
        tr.anim_lock_until = now + 0.22
        tr.anim_type = "ATTACKING"
    elseif string.find(seq, "cast", 1, true) or string.find(seq, "ability", 1, true) then
        tr.anim_lock_until = now + 0.30
        tr.anim_type = "CASTING"
    end
end

-- =============================================================================
-- CALLBACK: OnPrepareUnitOrders (Garanzia "SOLO GANCIO - ZERO MOVIMENTO")
-- =============================================================================
function PudgeHook.OnPrepareUnitOrders(data)
    if not ui.enabled:Get() or not data then return true end

    local my_hero = Heroes.GetLocal()
    if not my_hero or NPC.GetUnitName(my_hero) ~= HERO_NAME then return true end

    -- 1. CONTROLLO PRIORITARIO GANCI MANUALI (es. premendo Q o cliccando l'abilità):
    -- Se il giocatore lancia Meat Hook manualmente, NON bloccare MAI l'ordine!
    -- Disattiviamo la mira AI per lasciare il pieno controllo al giocatore
    if data.order == Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION and data.ability then
        local ab_name = Ability.GetName and Ability.GetName(data.ability)
        if ab_name == HOOK_ABILITY_NAME then
            local now = get_time()
            local is_from_script = script_cast_order_active or (pending_script_cast.active and (now - (pending_script_cast.order_time or 0) <= 0.25))
            if not is_from_script then
                active_hook_cast.is_manual = true
                active_hook_cast.is_script_cast = false
                pending_script_cast.active = false
                aim_session.active = false
                return true -- MAI BLOCCARE IL GANCIO MANUALE!
            end
        end
    end

    -- 2. Se l'utente sta tenendo premuto il tasto gancio AI (Mouse 4 o Mouse 3) e l'opzione "Never Move Pudge" è attiva:
    -- Blocchiamo eventuali ordini di movimento impartiti accidentalmente durante la mira dell'AI
    if aim_session.active and ui.lock_movement:Get() and Enum and Enum.UnitOrder then
        local order = data.order
        if order == Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION or
           order == Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_TARGET or
           order == Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_MOVE or
           order == Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET then
            -- Inibisce il movimento di Pudge mentre si mira col tasto gancio AI!
            return false
        end
    end

    return true
end

-- =============================================================================
-- CALLBACK: OnKeyEvent (Supporto Keybind Dinamici & Cattura Live Rebind In-Game)
-- =============================================================================
function PudgeHook.OnKeyEvent(data)
    if not data or not data.key then return true end
    local k = data.key
    local is_down = (data.event == nil) or (Enum and Enum.KeyEvent and data.event == Enum.KeyEvent.KEY_DOWN) or (data.event == 1) or (data.down == true)
    local is_up = (Enum and Enum.KeyEvent and data.event == Enum.KeyEvent.KEY_UP) or (data.event == 0) or (data.down == false)

    if is_down then
        keybind_state.down_keys[k] = true
    elseif is_up then
        keybind_state.down_keys[k] = false
    end

    -- Rilevamento pressione tasto manuale Q (Source 2 ButtonCode 27 = KEY_Q)
    if (k == 27 or (Enum and Enum.ButtonCode and k == Enum.ButtonCode.KEY_Q)) and is_down then
        manual_q_pressed_time = get_time()
        active_hook_cast.is_manual = true
        active_hook_cast.is_script_cast = false
        aim_session.active = false
    end

    -- Se siamo in modalità Live Rebind In-Game, cattura istantaneamente il tasto premuto
    if keybind_state.rebinding_target and is_down then
        local now = get_time()
        if (now - (keybind_state.rebind_start_time or 0)) > 0.18 then
            if k == 70 then -- ESC annulla
                keybind_state.rebinding_target = nil
                pcall(function() ui.rebind_enemy_live:Set(false) end)
                pcall(function() ui.rebind_ally_live:Set(false) end)
                notify_user("[PudgeHook AI] Live Rebind annullato con ESC.")
                return false
            elseif k ~= 314 and k ~= 315 and k > 0 then
                apply_live_rebind_key(keybind_state.rebinding_target, k)
                return false
            end
        end
    end

    return true
end

-- =============================================================================
-- RENDERING GRAFICO 3D, QUICK REBIND BAR CLICCABILE & TELEMETRIA HUD (OnDraw)
-- =============================================================================
local function draw_circle_3d(center, radius, color, segments, thickness)
    if not center or not Render or not Render.WorldToScreen or not Render.Line then return end
    segments = segments or 42
    local step = (math.pi * 2) / segments
    local prev_scr = nil
    local first_scr = nil

    for i = 0, segments do
        local ang = i * step
        local wx = center.x + math.cos(ang) * radius
        local wy = center.y + math.sin(ang) * radius
        local scr, vis = Render.WorldToScreen(Vector(wx, wy, center.z))
        if vis and scr then
            if prev_scr then
                Render.Line(prev_scr, scr, color, thickness or 2)
            else
                first_scr = scr
            end
            prev_scr = scr
        else
            prev_scr = nil
        end
    end
    if first_scr and prev_scr then
        Render.Line(prev_scr, first_scr, color, thickness or 2)
    end
end

--- Disegna e gestisce il pannello interattivo In-Game per cambiare i Keybind con un click
local function draw_and_handle_keybind_bar()
    if not ui.draw_keybind_bar:Get() or not Render or not draw_font then return end

    local bx = ui.keybind_bar_x:Get() or 24
    local by = ui.keybind_bar_y:Get() or 120
    local bw = 320
    local bh = 54

    -- Posizione cursore 2D sullo schermo e click sinistro (codice 314)
    local cx, cy = -1, -1
    if Input and Input.GetCursorPos then
        local ok_c, rx, ry = pcall(Input.GetCursorPos)
        if ok_c then
            if type(rx) == "number" and type(ry) == "number" then
                cx, cy = rx, ry
            elseif type(rx) == "table" or type(rx) == "userdata" then
                cx, cy = rx.x or -1, rx.y or -1
            end
        end
    end

    local left_down = false
    if Input and Input.IsKeyDown then
        local ok_l, ld = pcall(Input.IsKeyDown, 314)
        if ok_l and ld then left_down = true end
    end
    local left_clicked = left_down and (not keybind_state.last_left_click)
    keybind_state.last_left_click = left_down

    -- Coordinate dei 3 pulsanti cliccabili dentro la barra HUD
    local btn_enemy_x1, btn_enemy_y1, btn_enemy_x2, btn_enemy_y2 = bx + 8,   by + 24, bx + 132, by + 48
    local btn_ally_x1,  btn_ally_y1,  btn_ally_x2,  btn_ally_y2  = bx + 138, by + 24, bx + 256, by + 48
    local btn_rst_x1,   btn_rst_y1,   btn_rst_x2,   btn_rst_y2   = bx + 262, by + 24, bx + 312, by + 48

    local hover_enemy = (cx >= btn_enemy_x1 and cx <= btn_enemy_x2 and cy >= btn_enemy_y1 and cy <= btn_enemy_y2)
    local hover_ally  = (cx >= btn_ally_x1  and cx <= btn_ally_x2  and cy >= btn_ally_y1  and cy <= btn_ally_y2)
    local hover_rst   = (cx >= btn_rst_x1   and cx <= btn_rst_x2   and cy >= btn_rst_y1   and cy <= btn_rst_y2)

    if left_clicked then
        local now = get_time()
        if hover_enemy then
            if keybind_state.rebinding_target == "ENEMY" then
                keybind_state.rebinding_target = nil
                pcall(function() ui.rebind_enemy_live:Set(false) end)
            else
                keybind_state.rebinding_target = "ENEMY"
                keybind_state.rebind_start_time = now
                notify_user("[PudgeHook AI] Premi qualsiasi tasto o pulsante del mouse per ENEMY HOOK (ESC annulla)...")
            end
        elseif hover_ally then
            if keybind_state.rebinding_target == "ALLY" then
                keybind_state.rebinding_target = nil
                pcall(function() ui.rebind_ally_live:Set(false) end)
            else
                keybind_state.rebinding_target = "ALLY"
                keybind_state.rebind_start_time = now
                notify_user("[PudgeHook AI] Premi qualsiasi tasto o pulsante del mouse per ALLY HOOK (ESC annulla)...")
            end
        elseif hover_rst then
            keybind_state.enemy_override = KEY_CODE_MOUSE4
            keybind_state.ally_override = KEY_CODE_MOUSE3
            keybind_state.rebinding_target = nil
            pcall(function() if ui.enemy_key.Set then ui.enemy_key:Set(KEY_CODE_MOUSE4) end end)
            pcall(function() if ui.ally_key.Set then ui.ally_key:Set(KEY_CODE_MOUSE3) end end)
            notify_user("[PudgeHook AI] Keybind ripristinati: Enemy = [MOUSE 4] | Ally = [MOUSE 3]")
        end
    end

    -- Sfondo principale barra Keybind & Statistiche Live
    Render.FilledRect(Vec2(bx, by), Vec2(bx + bw, by + bh), Color(14, 17, 24, 220), 6)
    local hit_rate = (hook_stats.total_fired > 0) and ((hook_stats.hits / hook_stats.total_fired) * 100.0) or 0.0
    local stats_str = (hook_stats.total_fired > 0 or hook_stats.stop_cancels > 0)
        and string.format("PUDGE AI | Hits: %d/%d (%.0f%%) | Saved: %d", hook_stats.hits, hook_stats.total_fired, hit_rate, hook_stats.stop_cancels)
        or  "PUDGE HOOK AI  |  Click Key to Rebind In-Game"
    local title_txt = keybind_state.rebinding_target
        and ("WAITING FOR KEY -> " .. keybind_state.rebinding_target .. " (ESC to Cancel)")
        or  stats_str
    local title_col = keybind_state.rebinding_target and Color(255, 215, 50, 255) or Color(190, 205, 230, 230)
    Render.Text(draw_font_bold or draw_font, 12, title_txt, Vec2(bx + 10, by + 5), title_col)

    -- Pulsante 1: Enemy Hook Key
    local enemy_code = get_active_keycode(true)
    local enemy_held = is_bind_or_mouse_held(ui.enemy_key, true)
    local enemy_bg = Color(28, 34, 46, 235)
    if keybind_state.rebinding_target == "ENEMY" then
        enemy_bg = Color(210, 140, 20, 240)
    elseif enemy_held then
        enemy_bg = Color(40, 165, 80, 240)
    elseif hover_enemy then
        enemy_bg = Color(48, 58, 78, 240)
    end
    Render.FilledRect(Vec2(btn_enemy_x1, btn_enemy_y1), Vec2(btn_enemy_x2, btn_enemy_y2), enemy_bg, 4)
    local enemy_lbl = (keybind_state.rebinding_target == "ENEMY")
        and "Enemy: [PRESS...]"
        or  string.format("Enemy: [%s]", get_key_display_name(enemy_code))
    Render.Text(draw_font, 12, enemy_lbl, Vec2(btn_enemy_x1 + 6, btn_enemy_y1 + 5), Color(245, 250, 255, 255))

    -- Pulsante 2: Ally Save Key
    local ally_code = get_active_keycode(false)
    local ally_held = is_bind_or_mouse_held(ui.ally_key, false)
    local ally_bg = Color(28, 34, 46, 235)
    if keybind_state.rebinding_target == "ALLY" then
        ally_bg = Color(210, 140, 20, 240)
    elseif ally_held then
        ally_bg = Color(40, 145, 210, 240)
    elseif hover_ally then
        ally_bg = Color(48, 58, 78, 240)
    end
    Render.FilledRect(Vec2(btn_ally_x1, btn_ally_y1), Vec2(btn_ally_x2, btn_ally_y2), ally_bg, 4)
    local ally_lbl = (keybind_state.rebinding_target == "ALLY")
        and "Ally: [PRESS...]"
        or  string.format("Ally: [%s]", get_key_display_name(ally_code))
    Render.Text(draw_font, 12, ally_lbl, Vec2(btn_ally_x1 + 6, btn_ally_y1 + 5), Color(245, 250, 255, 255))

    -- Pulsante 3: Reset
    local rst_bg = hover_rst and Color(140, 50, 50, 240) or Color(45, 32, 36, 235)
    Render.FilledRect(Vec2(btn_rst_x1, btn_rst_y1), Vec2(btn_rst_x2, btn_rst_y2), rst_bg, 4)
    Render.Text(draw_font, 12, "Reset", Vec2(btn_rst_x1 + 9, btn_rst_y1 + 5), Color(255, 210, 210, 245))
end

function PudgeHook.OnDraw()
    if not ui.enabled:Get() then return end
    if not Engine or not Engine.IsInGame or not Engine.IsInGame() then return end

    local my_hero = Heroes.GetLocal()
    if not is_valid_entity(my_hero) or NPC.GetUnitName(my_hero) ~= HERO_NAME then return end

    if not draw_font and Render and Render.LoadFont then
        draw_font = Render.LoadFont("Arial", 0, 600)
        draw_font_bold = Render.LoadFont("Arial", 0, 700)
    end

    -- 0. Disegna la barra interattiva di cambio Keybind In-Game
    draw_and_handle_keybind_bar()

    local pudge_pos = Entity.GetAbsOrigin(my_hero)
    local hook_ab = NPC.GetAbility(my_hero, HOOK_ABILITY_NAME)
    if not pudge_pos or not hook_ab then return end

    local max_range, _, hook_width = get_hook_parameters(my_hero, hook_ab)

    -- 1. Cerchio 3D del raggio massimo del gancio (se abilitato o durante la mira)
    if ui.draw_range:Get() or aim_session.active then
        draw_circle_3d(pudge_pos, max_range, Color(255, 140, 40, 120), 48, 1.5)
    end

    if not aim_session.active then return end

    local target = aim_session.locked_target
    if not target or not is_valid_entity(target) then
        -- Mostra indicatore di ricerca vicino al cursore
        if ui.draw_hud:Get() and Input and Input.GetWorldCursorPos then
            local ok_c, c_pos = pcall(Input.GetWorldCursorPos)
            if ok_c and c_pos then
                local scr, vis = Render.WorldToScreen(c_pos)
                if vis and scr and draw_font then
                    local mode_lbl = (aim_session.mode == "ALLY") and "[ALLY HOOK] Searching Target..." or "[ENEMY HOOK] Searching Target..."
                    Render.Text(draw_font, 13, mode_lbl, Vec2(scr.x + 18, scr.y - 10), Color(255, 210, 60, 240))
                end
            end
        end
        return
    end

    local t_pos = Entity.GetAbsOrigin(target)
    local aim_pos = aim_session.best_aim_pos or t_pos
    local conf = aim_session.best_confidence or 0
    local min_req = ui.min_confidence:Get() or 75

    -- Colore dinamico in base alla confidenza e allo stato di blocco
    local line_color = Color(50, 255, 100, 230) -- Verde: Pronto al tiro (>= 75%)
    if aim_session.is_blocked then
        line_color = Color(255, 55, 55, 230)    -- Rosso: Bloccato da creep/unità
    elseif conf < min_req then
        line_color = Color(255, 200, 40, 230)   -- Giallo/Ambra: Studiando il movimento (< 75%)
    end

    -- 2. Disegna il Pathfinding Simulato e la Linea di Tiro del Gancio
    if ui.draw_path:Get() and aim_pos then
        -- Pathfinding multi-step del bersaglio
        local path = aim_session.best_path
        if path and #path >= 2 then
            for i = 1, #path - 1 do
                local s1, v1 = Render.WorldToScreen(path[i])
                local s2, v2 = Render.WorldToScreen(path[i + 1])
                if v1 and v2 and s1 and s2 then
                    Render.Line(s1, s2, Color(0, 220, 255, 220), 2.5)
                end
            end
        end

        -- Linea principale del gancio da Pudge al punto di impatto predetto
        local sp, vp = Render.WorldToScreen(pudge_pos)
        local sa, va = Render.WorldToScreen(aim_pos)
        if vp and va and sp and sa then
            Render.Line(sp, sa, line_color, 2.5)
        end

        -- Cerchio del raggio di cattura del gancio sul punto predetto
        draw_circle_3d(aim_pos, hook_width, line_color, 28, 2.0)
    end

    -- 3. Disegna Pannello Telemetria HUD sopra il bersaglio agganciato
    if ui.draw_hud:Get() and t_pos and draw_font then
        local scr, vis = Render.WorldToScreen(Vector(t_pos.x, t_pos.y, t_pos.z + 185))
        if vis and scr then
            local now = get_time()
            local max_w = (ui.max_wait_time:Get() or 30) / 10.0
            local rem_w = math.max(0.0, max_w - (now - aim_session.start_time))

            local mode_tag = (aim_session.mode == "ALLY") and "ALLY SAVE" or "HOOK LOCK"
            local line1 = string.format("[%s] Conf: %d%% (Window: %.1fs)", mode_tag, conf, rem_w)
            local line2 = string.format("Intent: %s | %s", tostring(aim_session.best_intent), aim_session.block_reason or "CLEAR")

            Render.FilledRect(Vec2(scr.x - 95, scr.y - 4), Vec2(scr.x + 115, scr.y + 34), Color(16, 18, 24, 225), 5)
            Render.Text(draw_font_bold or draw_font, 13, line1, Vec2(scr.x - 88, scr.y), line_color)
            Render.Text(draw_font, 12, line2, Vec2(scr.x - 88, scr.y + 16), Color(220, 230, 245, 235))
        end
    end
end

-- =============================================================================
-- LIFECYCLE CALLBACKS
-- =============================================================================
function PudgeHook.OnScriptsLoaded()
    if Render and Render.LoadFont then
        draw_font = Render.LoadFont("Arial", 0, 600)
        draw_font_bold = Render.LoadFont("Arial", 0, 700)
    end
end

function PudgeHook.OnGameEnd()
    hero_trackers = {}
    map_towers_cache = { radiant_towers = {}, dire_towers = {}, last_scan = 0 }
    aim_session.active = false
    aim_session.locked_target = nil
    aim_session.best_aim_pos = nil
    aim_session.best_path = {}
    active_hook_cast.in_phase = false
    active_hook_cast.is_manual = false
    active_hook_cast.is_script_cast = false
    active_hook_cast.target = nil
    pending_script_cast.active = false
    pending_script_cast.target = nil
    in_flight_hook.active = false
    in_flight_hook.target = nil
    in_flight_hook.hit_unit = nil
    in_flight_hook.closest_unit = nil
    manual_q_pressed_time = 0
    script_cast_order_active = false
    keybind_state.down_keys = {}
    keybind_state.rebinding_target = nil
end

return PudgeHook
