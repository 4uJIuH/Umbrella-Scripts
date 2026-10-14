import sys
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import discord_sync


class DiscordSyncTests(unittest.TestCase):
    def test_configured_threads_only_map_to_existing_single_lua_files(self):
        threads = discord_sync.validate_threads()
        self.assertEqual(len(threads), 23)

    def test_semver_bumps(self):
        self.assertEqual(discord_sync.bump("1.2.3", "patch"), "1.2.4")
        self.assertEqual(discord_sync.bump("1.2.3", "minor"), "1.3.0")
        self.assertEqual(discord_sync.bump("1.2.3", "major"), "2.0.0")

    def test_rejects_non_semver_version(self):
        with self.assertRaises(ValueError):
            discord_sync.bump("1.2-beta", "patch")

    def test_comments_skip_old_and_bot_messages(self):
        messages = [
            {"id": "10", "author": {"username": "old"}, "content": "old"},
            {"id": "11", "author": {"username": "bot", "bot": True}, "content": "ignored"},
            {"id": "12", "author": {"username": "author"}, "content": "new"},
        ]
        self.assertEqual(discord_sync.comments_since(messages, "10"), "[author]: new")

    def test_pr_comments_cannot_trigger_mentions(self):
        self.assertNotIn("@here", discord_sync.safe_comment_text("@here"))

    def test_first_observation_only_records_a_baseline(self):
        messages = [{"id": "100", "attachments": [{"filename": "script_manager.lua"}]}]
        state = {}
        with (
            patch.object(discord_sync, "fetch_thread", return_value=messages),
            patch.object(discord_sync, "download", return_value=b"return true"),
            patch.object(discord_sync, "ask_model") as ask_model,
        ):
            discord_sync.process("thread", "script_manager", state, False, "main")
        self.assertEqual(state["thread"]["last_msg"], "100")
        ask_model.assert_not_called()

    def test_dry_run_does_not_advance_an_update_baseline(self):
        source_path = (
            discord_sync.BASE
            / "scripts"
            / "script_manager"
            / "script_manager.lua"
        )
        new_source = source_path.read_bytes() + b"\n-- test update\n"
        messages = [
            {
                "id": "101",
                "author": {"username": "author"},
                "content": "Fixes an issue",
                "attachments": [{"filename": "script_manager.lua"}],
            }
        ]
        state = {"thread": {"sha": "previous-sha", "last_msg": "100"}}
        notes = {
            "bump": "patch",
            "ru": ["Исправлена ошибка"],
            "en": ["Fixed an issue"],
            "summary": "Fix an issue",
        }
        with (
            patch.object(discord_sync, "fetch_thread", return_value=messages),
            patch.object(discord_sync, "download", return_value=new_source),
            patch.object(discord_sync, "ask_model", return_value=notes),
        ):
            discord_sync.process("thread", "script_manager", state, True, "main")
        self.assertEqual(state["thread"]["sha"], "previous-sha")

    def test_dry_run_rejects_an_outdated_author_version(self):
        source_path = (
            discord_sync.BASE
            / "scripts"
            / "script_manager"
            / "script_manager.lua"
        )
        new_source = source_path.read_bytes().replace(
            b'local VERSION = "2.2.1"', b'local VERSION = "2.1.0"'
        )
        messages = [
            {
                "id": "101",
                "author": {"username": "author"},
                "content": "Old upload",
                "attachments": [{"filename": "script_manager.lua"}],
            }
        ]
        state = {"thread": {"sha": "previous-sha", "last_msg": "100"}}
        with (
            patch.object(discord_sync, "fetch_thread", return_value=messages),
            patch.object(discord_sync, "download", return_value=new_source),
            patch.object(discord_sync, "ask_model") as ask_model,
        ):
            with self.assertRaisesRegex(ValueError, "older than repository version"):
                discord_sync.process("thread", "script_manager", state, True, "main")
        ask_model.assert_not_called()
        self.assertEqual(state["thread"]["sha"], "previous-sha")


if __name__ == "__main__":
    unittest.main()
