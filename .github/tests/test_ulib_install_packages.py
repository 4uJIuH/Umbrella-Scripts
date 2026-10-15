import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / ".github"))

import release_notes


EXPECTED_FILES = {
    "gank_threat": {
        "ulib/icons.lua",
        "ulib/panel.lua",
        "ulib/timer.lua",
    },
    "achievements": {
        "ulib/http.lua",
        "ulib/icons.lua",
        "ulib/store.lua",
        "ulib/timer.lua",
    },
    "counter_items": {
        "ulib/http.lua",
        "ulib/icons.lua",
        "ulib/panel.lua",
        "ulib/store.lua",
        "ulib/timer.lua",
    },
}


class UlibInstallPackagesTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        source = json.loads((ROOT / ".github" / "catalog.json").read_text(encoding="utf-8"))
        feed = json.loads((ROOT / "scripts" / "manager" / "catalog.json").read_text(encoding="utf-8"))
        cls.source_by_id = {script["id"]: script for script in source["scripts"]}
        cls.feed_by_id = {script["id"]: script for script in feed["scripts"]}

    def test_scripts_install_all_ulib_files_from_manager(self):
        for script_id, expected_files in EXPECTED_FILES.items():
            with self.subTest(script=script_id):
                source = self.source_by_id[script_id]
                initial = source["initial"]
                item = self.feed_by_id[script_id]
                source_files = initial["files"]
                feed_files = item["files"]

                self.assertFalse(source["manual"])
                self.assertEqual(initial["install_url"], initial["url"])
                self.assertEqual({entry["path"] for entry in source_files}, expected_files)
                self.assertEqual(feed_files, source_files)
                self.assertFalse(item["manual"])
                self.assertEqual(item["install_url"], initial["install_url"])
                self.assertTrue(all(release_notes.PACKAGE_PATH.fullmatch(entry["path"])
                                    for entry in feed_files))
                self.assertTrue(all(entry["url"].startswith("https://raw.githubusercontent.com/")
                                    for entry in feed_files))


if __name__ == "__main__":
    unittest.main()
