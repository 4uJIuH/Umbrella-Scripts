import json
import re
from pathlib import Path

BASE = Path(__file__).resolve().parents[1]
CREATE_CALL = re.compile(r"\b(?:UI|Menu)\.Create\s*\(")
STRING_LITERAL = re.compile(r'''^\s*("(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')\s*$''')
ROUTE_SEPARATOR = " → "

OVERRIDES = {
    "lane_pull": {
        "ru": ["Creeps → Main → Lane Pull"],
        "en": ["Creeps → Main → Lane Pull"],
    },
    "ds_spot_block": {
        "ru": ["Heroes → Hero List → Dark Seer → Spot Block"],
        "en": ["Heroes → Hero List → Dark Seer → Spot Block"],
    },
    "custom_background": {
        "ru": ["Scripts → Scripts → Кастом фон"],
        "en": ["Scripts → Scripts → Кастом фон"],
    },
    "auto_stack": {
        "ru": ["Heroes → Hero List → Kunkka → Main Settings", "Heroes → Hero List → Invoker → Main Settings"],
        "en": ["Heroes → Hero List → Kunkka → Main Settings", "Heroes → Hero List → Invoker → Main Settings"],
    },
    "draft_helper": {
        "ru": ["Scripts → Scripts → Draft Helper"],
        "en": ["Scripts → Scripts → Draft Helper"],
    },
    "musicui": {
        "ru": ["Scripts → Scripts → MusicUI"],
        "en": ["Scripts → Scripts → MusicUI"],
    },
    "mom_swapper": {
        "ru": ["Scripts → Other → MoM Swapper"],
        "en": ["Scripts → Other → MoM Swapper"],
    },
    "invoker_jarvis": {
        "ru": ["Heroes → Hero List → Invoker → Jarvis", "Scripts → Scripts → Jarvis"],
        "en": ["Heroes → Hero List → Invoker → Jarvis", "Scripts → Scripts → Jarvis"],
    },
    "umbrella_tiktok": {
        "ru": ["Scripts → Scripts → TikTok"],
        "en": ["Scripts → Scripts → TikTok"],
    },
    "invoker_autostack": {
        "ru": ["Heroes → Hero List → Invoker → Автостак", "Scripts → Scripts → Invoker AutoStack"],
        "en": ["Heroes → Hero List → Invoker → Автостак", "Scripts → Scripts → Invoker AutoStack"],
    },
    "achievements": {
        "ru": ["General → Main → Achievements"],
        "en": ["General → Main → Achievements"],
    },
    "counter_items": {
        "ru": ["General → Main → Counter Items"],
        "en": ["General → Main → Counter Items"],
    },
    "arc_warden_multi_stack": {
        "ru": ["Heroes → Hero List → Arc Warden → Мульти Стак"],
        "en": ["Heroes → Hero List → Arc Warden → Мульти Стак"],
    },
    "techies_auto_miner": {
        "ru": ["Heroes → Hero List → Techies → Авто-минирование"],
        "en": ["Heroes → Hero List → Techies → Авто-минирование"],
    },
    "brood_camp_blocker": {
        "ru": ["Heroes → Hero List → Broodmother → Авто-блок кемпов"],
        "en": ["Heroes → Hero List → Broodmother → Авто-блок кемпов"],
    },
    "invoker_beta": {
        "ru": ["Heroes → Hero List → Invoker (Beta)"],
        "en": ["Heroes → Hero List → Invoker (Beta)"],
    },
    "techies_tazer_dispel": {
        "ru": ["Heroes → Hero List → Techies → Main Settings → Auto Dispel"],
        "en": ["Heroes → Hero List → Techies → Main Settings → Auto Dispel"],
    },
    "dota_no_limit": {
        "ru": ["Scripts → Item Eater → Eater"],
        "en": ["Scripts → Item Eater → Eater"],
    },
    "eul_wind_waker_blink_helper": {
        "ru": ["General → Main → Помощник Blink после Eul / Wind Waker"],
        "en": ["General → Main → Помощник Blink после Eul / Wind Waker"],
    },
    # naga_pt_abuse: у скрипта нет меню
    "backwards_cast": {
        "ru": ["General → Main → Скиллы спиной"],
        "en": ["General → Main → Back Cast"],
    },
    "creep_aggro": {
        "ru": ["Creeps → Переагр V2"],
        "en": ["Creeps → Re-Aggro V2"],
    },
    "dorman_combo_assistant": {
        "ru": ["Heroes → Hero List → The Dorman"],
        "en": ["Heroes → Hero List → The Dorman"],
    },
    "kotl_illuminate_pro": {
        "ru": [
            "Heroes → Hero List → Keeper Of The Light",
            "General → Utility → KOTL Illuminate",
        ],
        "en": [
            "Heroes → Hero List → Keeper Of The Light",
            "General → Utility → KOTL Illuminate",
        ],
    },
    "auto_ruin": {
        "ru": ["Miscellaneous → Other → Авто-Руин"],
        "en": ["Miscellaneous → Other → Авто-Руин"],
    },
    "windranger_powershot": {
        "ru": [
            "Heroes → Hero List → Windranger",
            "Scripts → User Scripts → Windranger Powershot",
        ],
        "en": [
            "Heroes → Hero List → Windranger",
            "Scripts → User Scripts → Windranger Powershot",
        ],
    },
    "arc_warden_control_rune": {
        "ru": ["Heroes → Hero List → Arc Warden → Контроль Рун"],
        "en": ["Heroes → Hero List → Arc Warden → Контроль Рун"],
    },
    "treecutter_plus": {
        "ru": ["Scripts → Utility → TreeCutter+"],
        "en": ["Scripts → Utility → TreeCutter+"],
    },
    "tinker_fear_of_god": {
        "ru": ["Heroes → Hero List → Tinker → Tinker Fear of God Combo"],
        "en": ["Heroes → Hero List → Tinker → Tinker Fear of God Combo"],
    },
    "arc_warden_high_five": {
        "ru": ["Heroes → Hero List → Arc Warden → Arc Warden → Пятюня"],
        "en": ["Heroes → Hero List → Arc Warden → Arc Warden → Пятюня"],
    },
    "creep_block": {
        "ru": ["Creeps → Main → Creep Block"],
        "en": ["Creeps → Main → Creep Block"],
    },
    "ember_spirit_sticky_trainer": {
        "ru": ["Heroes → Hero List → Ember Spirit Custom"],
        "en": ["Heroes → Hero List → Ember Spirit Custom"],
    },
    "pt_mana_abuse": {
        "ru": ["Scripts → PT Abuse → Main"],
        "en": ["Scripts → PT Abuse → Main"],
    },
    "marci_dust_delivery": {
        "ru": [
            "Heroes → Hero List → Marci → Dusts",
            "Scripts → Marci → Marci → Dusts",
        ],
        "en": [
            "Heroes → Hero List → Marci → Dusts",
            "Scripts → Marci → Marci → Dusts",
        ],
    },
    "arc_warden_rune_control": {
        "ru": ["Creeps → Arc moggers → Arc Warden Rune Control"],
        "en": ["Creeps → Arc moggers → Arc Warden Rune Control"],
    },
    "cooldown_ping": {
        "ru": ["General → Cooldown Ping → Cooldown Ping"],
        "en": ["General → Cooldown Ping → Cooldown Ping"],
    },
    "beastmaster_razorbacks": {
        "ru": ["Scripts → Heroes → Beastmaster → Razorbacks → Settings"],
        "en": ["Scripts → Heroes → Beastmaster → Razorbacks → Settings"],
    },
    "juggernaut_ward_control": {
        "ru": ["Heroes → Hero List → Juggernaut → Main Settings → Ward Control"],
        "en": ["Heroes → Hero List → Juggernaut → Main Settings → Ward Control"],
    },
    "invoker_auto_alacrity": {
        "ru": ["Heroes → Hero List → Invoker → Alacrity"],
        "en": ["Heroes → Hero List → Invoker → Alacrity"],
    },
    "snapfire_cookie_landing": {
        "ru": ["Heroes → Main → Snapfire → Firesnap Cookie → Self Cookie"],
        "en": ["Heroes → Main → Snapfire → Firesnap Cookie → Self Cookie"],
    },
    "mute_all_voice_phrases": {
        "ru": ["Miscellaneous → In Game → Mute Voice Phrases"],
        "en": ["Miscellaneous → In Game → Mute Voice Phrases"],
    },
    "mini_games": {
        "ru": ["Scripts → Utility → Мини-игры"],
        "en": ["Scripts → Utility → Мини-игры"],
    },
    "mmr_log": {
        "ru": ["MMR Tracker → Stats → Overview"],
        "en": ["MMR Tracker → Stats → Overview"],
    },
    "invoker_sunstrike_on_tp": {
        "ru": ["Heroes → Hero List → Invoker → Auto Usage → Sun Strike Settings"],
        "en": ["Heroes → Hero List → Invoker → Auto Usage → Sun Strike Settings"],
    },
    "autopick": {
        "ru": ["Scripts → Main → Авто-пик"],
        "en": ["Scripts → Main → Авто-пик"],
    },
    "txt_spoofer": {
        "ru": ["General → Visuals → TXT Spoofer"],
        "en": ["General → Visuals → TXT Spoofer"],
    },
    "zeus_heavenly_jump_range": {
        "ru": ["General → Main → Zeus Heavenly Jump → Visuals → Main"],
        "en": ["General → Main → Zeus Heavenly Jump → Visuals → Main"],
    },
    "meepo_v2": {
        "ru": ["Heroes → Hero List → Meepo → Meepo Panel"],
        "en": ["Heroes → Hero List → Meepo → Meepo Panel"],
    },
    "abaddon_borrowed_time_plus_one": {
        "ru": [
            "Heroes → Hero List → Abaddon → Автоиспользование → borrowed time",
            "Heroes → Hero List → Abaddon → Авто-использование → borrowed time",
            "Heroes → Hero List → Abaddon → Auto Usage → borrowed time",
            "Heroes → Hero List → Abaddon → borrowed time → borrowed time",
            "uc.zone → Quality of Life → Abaddon → borrowed time → borrowed time",
        ],
        "en": [
            "Heroes → Hero List → Abaddon → Auto Usage → borrowed time",
            "Heroes → Hero List → Abaddon → borrowed time → borrowed time",
            "uc.zone → Quality of Life → Abaddon → borrowed time → borrowed time",
        ],
    },
    "zmeyka": {
        "ru": ["General → Змейка → Змейка"],
        "en": ["General → Snake Game → Snake Game"],
    },
    "dota_imba": {
        "ru": ["General → dota imba → Main"],
        "en": ["General → dota imba → Main"],
    },
    "earth_spirit_boulder_helper": {
        "ru": ["Scripts → HEROES → Earth Spirit → Boulder Helper → Settings"],
        "en": ["Scripts → HEROES → Earth Spirit → Boulder Helper → Settings"],
    },
    "walrus_kick_assist": {
        "ru": [
            "Heroes → Hero List → Tusk → Walrus Kick Assist",
            "General → Tusk → Walrus Kick Assist",
        ],
        "en": [
            "Heroes → Hero List → Tusk → Walrus Kick Assist",
            "General → Tusk → Walrus Kick Assist",
        ],
    },
    "techies_tazer_auto_detonate": {
        "ru": ["Heroes → Hero List → Techies → Main Settings → Auto Dispel"],
        "en": ["Heroes → Hero List → Techies → Main Settings → Auto Dispel"],
    },
    "invoker_tp_sun_strike": {
        "ru": [
            "Heroes → Hero List → Invoker → TP Sun Strike",
            "Heroes → Hero List → Invoker → TP Filter",
            "Heroes → Hero List → Invoker → TP Interface",
        ],
        "en": [
            "Heroes → Hero List → Invoker → TP Sun Strike",
            "Heroes → Hero List → Invoker → TP Filter",
            "Heroes → Hero List → Invoker → TP Interface",
        ],
    },
    "courier_build_route": {
        "ru": ["Miscellaneous → In Game → Courier → Main → Courier"],
        "en": ["Miscellaneous → In Game → Courier → Main → Courier"],
    },
    "brood_pull_s": {
        "ru": ["General → Lane Pull → lane_pull"],
        "en": ["General → Lane Pull → lane_pull"],
    },
    "force_cookie_cursor_cast": {
        "ru": ["Miscellaneous → In Game → Использование по курсору"],
        "en": ["Miscellaneous → In Game → Использование по курсору"],
    },
    "abaddon_auto_mist_coil": {
        "ru": ["Heroes → Hero List → Abaddon → Auto Usage → AutoMistCoil"],
        "en": ["Heroes → Hero List → Abaddon → Auto Usage → AutoMistCoil"],
    },
    "void_spirit_escape": {
        "ru": ["Heroes → Hero List → Void Spirit → Main Settings → Escape Module"],
        "en": ["Heroes → Hero List → Void Spirit → Main Settings → Escape Module"],
    },
    "pogoda_ui": {
        "ru": ["General → Main → PogodaUI"],
        "en": ["General → Main → PogodaUI"],
    },
    "fog_of_war_predictor": {
        "ru": ["Info Screen → Main → Heroes Overlay → Main → Fog Prediction"],
        "en": ["Info Screen → Main → Heroes Overlay → Main → Fog Prediction"],
    },
    "tree_cutter_bf2": {
        "ru": ["Scripts → Main → Tree Cutter"],
        "en": ["Scripts → Main → Tree Cutter"],
    },
    "session_info": {
        "ru": [
            "Scripts → Other → Session Info → Main",
            "Scripts → Other → Session Info → Settings",
        ],
        "en": [
            "Scripts → Other → Session Info → Main",
            "Scripts → Other → Session Info → Settings",
        ],
    },
    "autofocus": {
        "ru": ["Heroes → Settings → General → Units Controller → AutoFocus"],
        "en": ["Heroes → Settings → General → Units Controller → AutoFocus"],
    },
    "warlock_control_golems": {
        "ru": [
            "Heroes → Hero List → Warlock → Main Settings → Control Golems"
        ],
        "en": [
            "Heroes → Hero List → Warlock → Main Settings → Control Golems"
        ],
    },
    "dust_radius": {
        "ru": [
            "Info Screen → Main → Radius → Main → Others Settings → Dust Radius"
        ],
        "en": [
            "Info Screen → Main → Radius → Main → Others Settings → Dust Radius"
        ],
    },
    "cosmic_menu": {
        "ru": [
            "Changer → Main → CosmicMenu → Settings",
            "General → Main → CosmicMenu → Settings",
        ],
        "en": [
            "Changer → Main → CosmicMenu → Settings",
            "General → Main → CosmicMenu → Settings",
        ],
    },
    "tinker_tweak": {
        "ru": [
            "Heroes → Hero List → Tinker → Tinker Misc Functions → Твики Tinker"
        ],
        "en": [
            "Heroes → Hero List → Tinker → Tinker Misc Functions → Твики Tinker"
        ],
    },
    "flutter_fx": {
        "ru": ["General → Combat Text FX → Flutter Combat"],
        "en": ["General → Combat Text FX → Flutter Combat"],
    },
    "tinker_glimmer_combo": {
        "ru": [
            "Heroes → Hero List → Tinker → Tinker Misc Functions → Настройки комбо с глимером",
            "Heroes → Hero List → Tinker → Tinker Misc Functions → Настройки побега",
        ],
        "en": [
            "Heroes → Hero List → Tinker → Tinker Misc Functions → Настройки комбо с глимером",
            "Heroes → Hero List → Tinker → Tinker Misc Functions → Настройки побега",
        ],
    },
    "toxic_chat_guard": {
        "ru": [
            "Scripts → Utility → Toxic Chat Guard → Основное",
            "Scripts → Utility → Toxic Chat Guard → Монитор",
        ],
        "en": [
            "Scripts → Utility → Toxic Chat Guard → Основное",
            "Scripts → Utility → Toxic Chat Guard → Монитор",
        ],
    },
    "auto_unsleep": {
        "ru": ["Heroes → Settings → General → Units Controller → AutoUnsleep"],
        "en": ["Heroes → Settings → General → Units Controller → AutoUnsleep"],
    },
    "follow_selected_hero": {
        "ru": ["Scripts → Utility → Follow Hero"],
        "en": ["Scripts → Utility → Follow Hero"],
    },
    "radial_chat": {
        "ru": ["Scripts → Utility → RadialChat → Main"],
        "en": ["Scripts → Utility → RadialChat → Main"],
    },
    "interactive_menu": {
        "ru": [
            "General → Main → InteractiveMenu RU → ⚙ General / Общее",
            "General → Main → InteractiveMenu RU → ◈ Palette / Палитра",
            "General → Main → InteractiveMenu RU → ✦ Particles / Частицы",
            "General → Main → InteractiveMenu RU → ⌘ Web / Паутинка",
        ],
        "en": [
            "General → Main → InteractiveMenu RU → ⚙ General / Общее",
            "General → Main → InteractiveMenu RU → ◈ Palette / Палитра",
            "General → Main → InteractiveMenu RU → ✦ Particles / Частицы",
            "General → Main → InteractiveMenu RU → ⌘ Web / Паутинка",
        ],
    },
    "ranks_mmr_tracker": {
        "ru": [
            "Scripts → Other → MMR Tracker Ultimate → Settings → Main",
            "Scripts → Other → MMR Tracker Ultimate → Settings → Statistics",
            "Scripts → Other → MMR Tracker Ultimate → Settings → Calculator",
            "Scripts → Other → MMR Tracker Ultimate → Settings → Tilt Guard",
        ],
        "en": [
            "Scripts → Other → MMR Tracker Ultimate → Settings → Main",
            "Scripts → Other → MMR Tracker Ultimate → Settings → Statistics",
            "Scripts → Other → MMR Tracker Ultimate → Settings → Calculator",
            "Scripts → Other → MMR Tracker Ultimate → Settings → Tilt Guard",
        ],
    },
    "lycan_auto_howl": {
        "ru": [
            "General → Main → Lycan Auto Howl → Auto Howl → Основное",
            "General → Main → Lycan Auto Howl → Auto Howl → День / Ночь",
            "General → Main → Lycan Auto Howl → Auto Howl → Детект",
            "General → Main → Lycan Auto Howl → Auto Howl → Панель",
        ],
        "en": [
            "General → Main → Lycan Auto Howl → Auto Howl → Основное",
            "General → Main → Lycan Auto Howl → Auto Howl → День / Ночь",
            "General → Main → Lycan Auto Howl → Auto Howl → Детект",
            "General → Main → Lycan Auto Howl → Auto Howl → Панель",
        ],
    },
    "sf_requiem_radius": {
        "ru": ["Heroes → Hero List → Shadow Fiend → Requiem Radius → Main"],
        "en": ["Heroes → Hero List → Shadow Fiend → Requiem Radius → Main"],
    },
    "dotaplus_tracker": {
        "ru": ["Info Screen → Main → Tracker → Main → Settings"],
        "en": ["Info Screen → Main → Tracker → Main → Settings"],
    },
    "illuminate_visualizer": {
        "ru": [
            "General → Main → Illuminate Visualizer → Settings → Main"
        ],
        "en": [
            "General → Main → Illuminate Visualizer → Settings → Main"
        ],
    },
    "aegis_blinkout_cone": {
        "ru": [
            "General → Main → Конус блинка после Aegis → Настройки → Общее"
        ],
        "en": [
            "General → Main → Конус блинка после Aegis → Настройки → Общее"
        ],
    },
    "natures_call_block": {
        "ru": [
            "Heroes → Hero List → Nature's Prophet → Nature Call Block → Settings"
        ],
        "en": [
            "Heroes → Hero List → Nature's Prophet → Nature Call Block → Settings"
        ],
    },
    "remote_auto_search": {
        "ru": [
            "Miscellaneous → Other → Message Recorder → Main → Auto Search Game",
            "Miscellaneous → Other → Message Recorder → Main → Ntfy Remote Queue",
            "Miscellaneous → Other → Message Recorder → Main → Key Emulator",
        ],
        "en": [
            "Miscellaneous → Other → Message Recorder → Main → Auto Search Game",
            "Miscellaneous → Other → Message Recorder → Main → Ntfy Remote Queue",
            "Miscellaneous → Other → Message Recorder → Main → Key Emulator",
        ],
    },
    "opendota_stats_tracker": {
        "ru": ["Info Screen → Main → Tracker → Main → Settings"],
        "en": ["Info Screen → Main → Tracker → Main → Settings"],
    },
    "dark_carnival_suggest_heroes": {
        "ru": ["General → Main → Dark Carnival → Main → Настройки"],
        "en": ["General → Main → Dark Carnival → Main → Настройки"],
    },
    "meepo_auto_escape": {
        "ru": ["Heroes → Hero List → Meepo → Meepo → Saver"],
        "en": ["Heroes → Hero List → Meepo → Meepo → Saver"],
    },
    "incoming_damage_hud": {
        "ru": [
            "Scripts → Main → Incoming DMG → Incoming DMG → Main",
            "Scripts → Main → Incoming DMG → Incoming DMG → Display",
        ],
        "en": [
            "Scripts → Main → Incoming DMG → Incoming DMG → Main",
            "Scripts → Main → Incoming DMG → Incoming DMG → Display",
        ],
    },
    "ntfy_match_notifier": {
        "ru": [
            "UCZone → Utilities → Ntfy → Match Notifier → On Accept/Resolve"
        ],
        "en": [
            "UCZone → Utilities → Ntfy → Match Notifier → On Accept/Resolve"
        ],
    },
    "auto_summons_kiting": {
        "ru": ["Scripts → Other → Auto Summons → Main → Main"],
        "en": ["Scripts → Other → Auto Summons → Main → Main"],
    },
    "dazzle_support": {
        "ru": [
            "Heroes → Hero List → Dazzle → Dazzle Support RUS → General",
            "Heroes → Hero List → Dazzle → Dazzle Support RUS → E - Shallow Grave",
            "Heroes → Hero List → Dazzle → Dazzle Support RUS → W - Shadow Wave",
            "Heroes → Hero List → Dazzle → Dazzle Support RUS → Items",
            "Heroes → Hero List → Dazzle → Dazzle Support RUS → Визуалы",
        ],
        "en": [
            "Heroes → Hero List → Dazzle → Dazzle Support RUS → General",
            "Heroes → Hero List → Dazzle → Dazzle Support RUS → E - Shallow Grave",
            "Heroes → Hero List → Dazzle → Dazzle Support RUS → W - Shadow Wave",
            "Heroes → Hero List → Dazzle → Dazzle Support RUS → Items",
            "Heroes → Hero List → Dazzle → Dazzle Support RUS → Визуалы",
        ],
    },
    "kotl_illuminate_kill_release": {
        "ru": [
            "General → Utility → kotl_illuminate → KOTL → Auto Illuminate"
        ],
        "en": [
            "General → Utility → kotl_illuminate → KOTL → Auto Illuminate"
        ],
    },
    "hero_speed_overlay": {
        "ru": [
            "Info Screen → Main → Heroes Overlay → Main → Speed Check"
        ],
        "en": [
            "Info Screen → Main → Heroes Overlay → Main → Speed Check"
        ],
    },
    "ai_chat_responder": {
        "ru": [
            "Scripts → User Scripts → AI Chat Responder → Main → AI Responder",
            "Scripts → User Scripts → AI Chat Responder → Main → Enemy Warnings",
        ],
        "en": [
            "Scripts → User Scripts → AI Chat Responder → Main → AI Responder",
            "Scripts → User Scripts → AI Chat Responder → Main → Enemy Warnings",
        ],
    },
    "windranger_combo": {
        "ru": [
            "Heroes → Hero List → Windranger → Windranger Combo → Combo Settings",
            "Heroes → Hero List → Windranger → Windranger Combo → Ability Toggle",
            "Heroes → Hero List → Windranger → Windranger Combo → Shackle Options",
            "Heroes → Hero List → Windranger → Windranger Combo → Visuals",
        ],
        "en": [
            "Heroes → Hero List → Windranger → Windranger Combo → Combo Settings",
            "Heroes → Hero List → Windranger → Windranger Combo → Ability Toggle",
            "Heroes → Hero List → Windranger → Windranger Combo → Shackle Options",
            "Heroes → Hero List → Windranger → Windranger Combo → Visuals",
        ],
    },
    "lone_druid_bear_ai_deluxe": {
        "ru": ["Heroes → Hero List → Lone Druid → Bear AI Deluxe"],
        "en": ["Heroes → Hero List → Lone Druid → Bear AI Deluxe"],
    },
    "ultrashizfrenia_laugh": {
        "ru": [
            "Miscellaneous → In Game → ULTRASHIZOFRENIA laugh → Main → General"
        ],
        "en": [
            "Miscellaneous → In Game → ULTRASHIZOFRENIA laugh → Main → General"
        ],
    },
    "ultrashizfrenia_high_five": {
        "ru": [
            "Miscellaneous → In Game → ULTRASHIZOFRENIA Auto High Five → Main → General"
        ],
        "en": [
            "Miscellaneous → In Game → ULTRASHIZOFRENIA Auto High Five → Main → General"
        ],
    },
    "rubick_last_spell": {
        "ru": ["Heroes → Rubick → Last Spell ESP → Main → Settings"],
        "en": ["Heroes → Rubick → Last Spell ESP → Main → Settings"],
    },
    "invoker_combo_panel": {
        "ru": ["Heroes → Hero List → Invoker → Invoker Combo Panel"],
        "en": ["Heroes → Hero List → Invoker → Invoker Combo Panel"],
    },
    "invoker_ice_wall_farm": {
        "ru": ["Heroes → Hero List → Invoker → Ice Wall Farm"],
        "en": ["Heroes → Hero List → Invoker → Ice Wall Farm"],
    },
    "meepo_block": {
        "ru": ["General → Blocker → Meepo Blocker"],
        "en": ["General → Blocker → Meepo Blocker"],
    },
    "pt_strength_low_hp": {
        "ru": ["Scripts → Combat → PTabs"],
        "en": ["Scripts → Combat → PTabs"],
    },
    "combine_lock_click": {
        "ru": ["General → Items → Combine Lock → Main → Main"],
        "en": ["General → Items → Combine Lock → Main → Main"],
    },
    "invoker_ice_wall_cursor": {
        "ru": ["Heroes → Hero List → Invoker → Main Settings → Cast On Cursor"],
        "en": ["Heroes → Hero List → Invoker → Main Settings → Cast On Cursor"],
    },
    "chaos_knight_crit_guard": {
        "ru": ["Heroes → Hero List → Chaos Knight"],
        "en": ["Heroes → Hero List → Chaos Knight"],
    },
    "witch_doctor_ward_controller": {
        "ru": ["Heroes → Hero List → Witch Doctor → Main Settings → Ward Settings"],
        "en": ["Heroes → Hero List → Witch Doctor → Main Settings → Ward Settings"],
    },
    "sense_metrics": {
        "ru": ["General → Sense Metrics → Sense"],
        "en": ["General → Sense Metrics → Sense"],
    },
    "terrorblade_conjure_spam": {
        "ru": ["General → Terrorblade → Conjure Image → Settings → Conjure Spam"],
        "en": ["General → Terrorblade → Conjure Image → Settings → Conjure Spam"],
    },
    "invoker_alacrity_allies_panel": {
        "ru": ["Heroes → Hero List → Invoker → Alacrity Allies Panel"],
        "en": ["Heroes → Hero List → Invoker → Alacrity Allies Panel"],
    },
    "html_widget": {
        "ru": ["General → Main → HTML Widget"],
        "en": ["General → Main → HTML Widget"],
    },
    "synoptic_forecast": {
        "ru": ["Scripts → Utility → Синоптик → Main"],
        "en": ["Scripts → Utility → Синоптик → Main"],
    },
    "pedometer": {
        "ru": ["Scripts → Utility → Шагомер → Main"],
        "en": ["Scripts → Utility → Шагомер → Main"],
    },
}


def _source_path(script):
    folder = BASE / "scripts" / script["id"]
    if script.get("source_file"):
        return folder / script["source_file"]
    if script.get("package"):
        candidate = folder / script["package"] / "Tinker.lua"
        if candidate.is_file():
            return candidate
    candidate = folder / script["file"]
    return candidate if candidate.suffix.lower() == ".lua" else None


def _split_arguments(text):
    arguments = []
    start = 0
    depth = 0
    quote = None
    escaped = False
    for index, char in enumerate(text):
        if quote:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                quote = None
        elif char in ("'", '"'):
            quote = char
        elif char in "({[":
            depth += 1
        elif char in ")}]":
            depth -= 1
        elif char == "," and depth == 0:
            arguments.append(text[start:index].strip())
            start = index + 1
    arguments.append(text[start:].strip())
    return arguments


def _call_arguments(source):
    for match in CREATE_CALL.finditer(source):
        start = match.end()
        index = start
        depth = 1
        quote = None
        escaped = False
        while index < len(source) and depth:
            char = source[index]
            if quote:
                if escaped:
                    escaped = False
                elif char == "\\":
                    escaped = True
                elif char == quote:
                    quote = None
            elif char in ("'", '"'):
                quote = char
            elif char == "(":
                depth += 1
            elif char == ")":
                depth -= 1
            index += 1
        if depth == 0:
            yield _split_arguments(source[start:index - 1])


def _decode_literal(expression):
    match = STRING_LITERAL.match(expression)
    if not match:
        return None
    value = match.group(1)
    if value.startswith('"'):
        value = re.sub(
            r"\\u\{([0-9a-fA-F]+)\}",
            lambda item: chr(int(item.group(1), 16)),
            value,
        )
        try:
            return json.loads(value)
        except json.JSONDecodeError:
            return value[1:-1]
    return value[1:-1].replace("\\'", "'").replace("\\\\", "\\")


def _resolve_simple(expression, source):
    value = _decode_literal(expression)
    if value is not None:
        return re.sub(r"[\ue000-\uf8ff]", "", value).strip()
    name = expression.strip()
    if re.fullmatch(r"[A-Za-z_]\w*", name):
        match = re.search(
            r"(?:local\s+)?" + re.escape(name) + r"\s*=\s*"
            r'''("(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')''',
            source,
        )
        if match:
            value = _decode_literal(match.group(1))
            return re.sub(r"[\ue000-\uf8ff]", "", value).strip() if value else value
    table_index = re.fullmatch(r"([A-Za-z_]\w*)\[(\d+)\]", name)
    if table_index:
        table_name, number = table_index.groups()
        match = re.search(
            r"(?:local\s+)?" + re.escape(table_name) + r"\s*=\s*\{([^}]*)\}",
            source,
            re.DOTALL,
        )
        if match:
            values = [
                _decode_literal(argument)
                for argument in _split_arguments(match.group(1))
            ]
            position = int(number) - 1
            if 0 <= position < len(values):
                value = values[position]
                return re.sub(r"[\ue000-\uf8ff]", "", value).strip() if value else value
    nested = re.fullmatch(r"([A-Za-z_]\w*)\.menu\.(\w+)", name)
    if nested:
        table_name, key = nested.groups()
        match = re.search(
            r"(?:local\s+)?" + re.escape(table_name) + r"\s*=\s*\{",
            source,
        )
        if match:
            tail = source[match.end():]
            menu = re.search(r"\bmenu\s*=\s*\{([^}]*)\}", tail, re.DOTALL)
            if menu:
                field = re.search(
                    r"\b" + re.escape(key) + r"\s*=\s*"
                    r'''("(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')''',
                    menu.group(1),
                )
                if field:
                    value = _decode_literal(field.group(1))
                    return re.sub(r"[\ue000-\uf8ff]", "", value).strip() if value else value
    return None


def _source_paths(script):
    path = _source_path(script)
    if not path or not path.is_file():
        return []
    source = path.read_text(encoding="utf-8", errors="replace")
    routes = []
    for arguments in _call_arguments(source):
        values = [_resolve_simple(arg, source) for arg in arguments[:3]]
        if values and all(isinstance(value, str) and value for value in values):
            route = ROUTE_SEPARATOR.join(values)
            if route not in routes:
                routes.append(route)
    return routes


def _documented_paths(script, language):
    routes = []
    for line in script.get(language, {}).get("install", []):
        parts = line.split("`")
        for index in range(1, len(parts), 2):
            value = parts[index].strip()
            if "→" in value or "->" in value:
                route = value.replace("->", ROUTE_SEPARATOR).strip()
                if route not in routes:
                    routes.append(route)
    return routes


def _route_matches_source(route, source_route):
    route_parts = [part.strip() for part in route.split("→")]
    source_parts = [part.strip() for part in source_route.split("→")]
    return route_parts[:len(source_parts)] == source_parts


def paths_for(script):
    """Return menu paths by language, preferring literal menu calls and matching docs."""
    override = OVERRIDES.get(script["id"])
    if override:
        return override

    source_paths = _source_paths(script)
    result = {}
    for language in ("ru", "en"):
        documented = _documented_paths(script, language)
        if documented and (
            not source_paths
            or any(
                _route_matches_source(route, source_route)
                for route in documented
                for source_route in source_paths
            )
        ):
            result[language] = documented
        else:
            result[language] = source_paths
    return result
