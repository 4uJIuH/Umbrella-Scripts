import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / ".github"))

from menu_locations import BASE, paths_for


class MenuLocationsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        catalog_path = BASE / ".github" / "catalog.json"
        cls.scripts = json.loads(catalog_path.read_text(encoding="utf-8"))["scripts"]
        cls.by_id = {script["id"]: script for script in cls.scripts}

    def test_literal_menu_calls_are_used(self):
        self.assertEqual(
            paths_for(self.by_id["tinker_turret_dodge"])["en"],
            ["Scripts → Scripts → Tinker"],
        )

    def test_documentation_completes_short_menu_calls(self):
        self.assertEqual(
            paths_for(self.by_id["behavior_score_helper"])["en"],
            ["Scripts → Utility → Порядочность"],
        )

    def test_dynamic_menu_paths_are_explicit(self):
        paths = paths_for(self.by_id["windranger_powershot"])
        self.assertEqual(
            paths["en"],
            [
                "Heroes → Hero List → Windranger",
                "Scripts → User Scripts → Windranger Powershot",
            ],
        )
        self.assertEqual(
            paths_for(self.by_id["backwards_cast"])["ru"],
            ["General → Main → Скиллы спиной"],
        )
        self.assertEqual(
            paths_for(self.by_id["creep_aggro"]),
            {
                "ru": ["Creeps → Переагр V2"],
                "en": ["Creeps → Re-Aggro V2"],
            },
        )

    def test_additional_confirmed_menu_paths_are_available(self):
        self.assertEqual(
            paths_for(self.by_id["achievements"])["en"],
            ["General → Main → Achievements"],
        )
        self.assertEqual(
            paths_for(self.by_id["lane_pull"])["en"],
            ["Creeps → Main → Lane Pull"],
        )

    def test_new_script_menu_paths_are_available(self):
        expected = {
            "arc_warden_control_rune": "Heroes → Hero List → Arc Warden → Контроль Рун",
            "treecutter_plus": "Scripts → Utility → TreeCutter+",
            "tinker_fear_of_god": "Heroes → Hero List → Tinker → Tinker Fear of God Combo",
            "arc_warden_high_five": "Heroes → Hero List → Arc Warden → Arc Warden → Пятюня",
            "creep_block": "Creeps → Main → Creep Block",
            "ember_spirit_sticky_trainer": "Heroes → Hero List → Ember Spirit Custom",
        }
        for script_id, path in expected.items():
            with self.subTest(script=script_id):
                self.assertEqual(paths_for(self.by_id[script_id])["en"], [path])

    def test_latest_script_menu_paths_are_available(self):
        expected = {
            "pt_mana_abuse": ["Scripts → PT Abuse → Main"],
            "marci_dust_delivery": [
                "Heroes → Hero List → Marci → Dusts",
                "Scripts → Marci → Marci → Dusts",
            ],
            "arc_warden_rune_control": ["Creeps → Arc moggers → Arc Warden Rune Control"],
            "cooldown_ping": ["General → Cooldown Ping → Cooldown Ping"],
            "beastmaster_razorbacks": [
                "Scripts → Heroes → Beastmaster → Razorbacks → Settings"
            ],
            "juggernaut_ward_control": [
                "Heroes → Hero List → Juggernaut → Main Settings → Ward Control"
            ],
        }
        for script_id, paths in expected.items():
            with self.subTest(script=script_id):
                self.assertEqual(paths_for(self.by_id[script_id])["en"], paths)

    def test_latest_additions_menu_paths_are_available(self):
        expected = {
            "invoker_auto_alacrity": ["Heroes → Hero List → Invoker → Alacrity"],
            "snapfire_cookie_landing": [
                "Heroes → Main → Snapfire → Firesnap Cookie → Self Cookie"
            ],
            "mute_all_voice_phrases": [
                "Miscellaneous → In Game → Mute Voice Phrases"
            ],
            "mini_games": ["Scripts → Utility → Мини-игры"],
        }
        for script_id, paths in expected.items():
            with self.subTest(script=script_id):
                self.assertEqual(paths_for(self.by_id[script_id])["en"], paths)

    def test_recent_additions_menu_paths_are_available(self):
        expected = {
            "mmr_log": ["MMR Tracker → Stats → Overview"],
            "invoker_sunstrike_on_tp": [
                "Heroes → Hero List → Invoker → Auto Usage → Sun Strike Settings"
            ],
            "autopick": ["Scripts → Main → Авто-пик"],
            "txt_spoofer": ["General → Visuals → TXT Spoofer"],
            "zeus_heavenly_jump_range": [
                "General → Main → Zeus Heavenly Jump → Visuals → Main"
            ],
        }
        for script_id, paths in expected.items():
            with self.subTest(script=script_id):
                self.assertEqual(paths_for(self.by_id[script_id])["en"], paths)

    def test_new_batch_menu_paths_are_available(self):
        expected = {
            "meepo_v2": ["Heroes → Hero List → Meepo → Meepo Panel"],
            "abaddon_borrowed_time_plus_one": [
                "Heroes → Hero List → Abaddon → Auto Usage → borrowed time",
                "Heroes → Hero List → Abaddon → borrowed time → borrowed time",
                "uc.zone → Quality of Life → Abaddon → borrowed time → borrowed time",
            ],
            "zmeyka": ["General → Snake Game → Snake Game"],
            "dota_imba": ["General → dota imba → Main"],
            "earth_spirit_boulder_helper": [
                "Scripts → HEROES → Earth Spirit → Boulder Helper → Settings"
            ],
            "walrus_kick_assist": [
                "Heroes → Hero List → Tusk → Walrus Kick Assist",
                "General → Tusk → Walrus Kick Assist",
            ],
            "techies_tazer_auto_detonate": [
                "Heroes → Hero List → Techies → Main Settings → Auto Dispel"
            ],
            "invoker_tp_sun_strike": [
                "Heroes → Hero List → Invoker → TP Sun Strike",
                "Heroes → Hero List → Invoker → TP Filter",
                "Heroes → Hero List → Invoker → TP Interface",
            ],
        }
        for script_id, paths in expected.items():
            with self.subTest(script=script_id):
                self.assertEqual(paths_for(self.by_id[script_id])["en"], paths)

    def test_additional_new_batch_menu_paths_are_available(self):
        expected = {
            "courier_build_route": [
                "Miscellaneous → In Game → Courier → Main → Courier"
            ],
            "brood_pull_s": ["General → Lane Pull → lane_pull"],
            "force_cookie_cursor_cast": [
                "Miscellaneous → In Game → Использование по курсору"
            ],
            "abaddon_auto_mist_coil": [
                "Heroes → Hero List → Abaddon → Auto Usage → AutoMistCoil"
            ],
            "void_spirit_escape": [
                "Heroes → Hero List → Void Spirit → Main Settings → Escape Module"
            ],
            "pogoda_ui": ["General → Main → PogodaUI"],
            "fog_of_war_predictor": [
                "Info Screen → Main → Heroes Overlay → Main → Fog Prediction"
            ],
            "tree_cutter_bf2": ["Scripts → Main → Tree Cutter"],
        }
        for script_id, paths in expected.items():
            with self.subTest(script=script_id):
                self.assertEqual(paths_for(self.by_id[script_id])["en"], paths)

    def test_session_info_and_unit_control_menu_paths(self):
        expected = {
            "session_info": [
                "Scripts → Other → Session Info → Main",
                "Scripts → Other → Session Info → Settings",
            ],
            "autofocus": [
                "Heroes → Settings → General → Units Controller → AutoFocus"
            ],
            "warlock_control_golems": [
                "Heroes → Hero List → Warlock → Main Settings → Control Golems"
            ],
        }
        for script_id, paths in expected.items():
            with self.subTest(script=script_id):
                self.assertEqual(paths_for(self.by_id[script_id])["en"], paths)

    def test_latest_addition_menu_paths(self):
        expected = {
            "dust_radius": [
                "Info Screen → Main → Radius → Main → Others Settings → Dust Radius"
            ],
            "cosmic_menu": [
                "Changer → Main → CosmicMenu → Settings",
                "General → Main → CosmicMenu → Settings",
            ],
            "tinker_tweak": [
                "Heroes → Hero List → Tinker → Tinker Misc Functions → Твики Tinker"
            ],
            "flutter_fx": ["General → Combat Text FX → Flutter Combat"],
            "tinker_glimmer_combo": [
                "Heroes → Hero List → Tinker → Tinker Misc Functions → Настройки комбо с глимером",
                "Heroes → Hero List → Tinker → Tinker Misc Functions → Настройки побега",
            ],
            "toxic_chat_guard": [
                "Scripts → Utility → Toxic Chat Guard → Основное",
                "Scripts → Utility → Toxic Chat Guard → Монитор",
            ],
            "auto_unsleep": [
                "Heroes → Settings → General → Units Controller → AutoUnsleep"
            ],
            "follow_selected_hero": ["Scripts → Utility → Follow Hero"],
            "radial_chat": ["Scripts → Utility → RadialChat → Main"],
        }
        for script_id, paths in expected.items():
            with self.subTest(script=script_id):
                self.assertEqual(paths_for(self.by_id[script_id])["en"], paths)

    def test_catalog_paths_have_localized_list_shapes(self):
        for script in self.scripts:
            with self.subTest(script=script["id"]):
                paths = paths_for(script)
                self.assertEqual(set(paths), {"ru", "en"})
                for language in ("ru", "en"):
                    self.assertIsInstance(paths[language], list)
                    self.assertTrue(all(isinstance(path, str) and path for path in paths[language]))


if __name__ == "__main__":
    unittest.main()
