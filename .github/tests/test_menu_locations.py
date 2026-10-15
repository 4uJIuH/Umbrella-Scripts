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
