import sys
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import stats


class StatsTests(unittest.TestCase):
    def test_github_repo_ignores_non_github_urls_and_extracts_repo_path(self):
        self.assertEqual(stats.github_repo("https://github.com/owner/project/tree/main/src"), "owner/project")
        self.assertEqual(stats.github_repo("https://github.com/owner/project.git"), "owner/project")
        self.assertIsNone(stats.github_repo("https://example.com/owner/project"))

    def test_fetch_includes_only_matching_assets_from_external_repositories(self):
        catalog = {
            "repo": "owner/catalog",
            "scripts": [
                {"id": "local_script", "tag": "Local", "title": "Local", "file": "local.lua",
                 "source_url": "https://github.com/owner/catalog/tree/main/scripts/local_script"},
                {"id": "external_script", "tag": "External", "title": "External",
                 "file": "external.lua", "source_url": "https://github.com/author/project"},
            ],
        }
        local_release = [{
            "tag_name": "v1.0.0",
            "published_at": "2025-01-01T00:00:00Z",
            "assets": [{"name": "local_script.lua", "download_count": 4}],
        }]
        external_release = [{
            "tag_name": "v2.0.0",
            "published_at": "2025-02-01T00:00:00Z",
            "assets": [
                {"name": "external.lua", "download_count": 7},
                {"name": "unrelated.zip", "download_count": 100},
            ],
        }]
        with patch.object(stats, "CATALOG", catalog), patch.object(stats, "REPO", "owner/catalog"), \
                patch.object(stats, "api", side_effect=[local_release, external_release]):
            rows = stats.fetch()

        self.assertEqual([row["downloads"] for row in rows], [4, 7])
        self.assertEqual(rows[1]["script"], "external_script")
        self.assertEqual(rows[1]["repo"], "author/project")


if __name__ == "__main__":
    unittest.main()
