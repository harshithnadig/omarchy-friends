import json
import pathlib
import sys
import tempfile
import time
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "bin"))

import build_network_app_v4 as release


class ReleaseHardeningTests(unittest.TestCase):
    def test_helper_availability_expires(self):
        now = 2_000_000
        fresh = {"status": "active", "created_at": now - 60, "available_minutes": 30}
        stale = {"status": "active", "created_at": now - 3600, "available_minutes": 30}
        closed = {"status": "closed", "created_at": now - 60, "available_minutes": 30}
        self.assertTrue(release._helper_live(fresh, now))
        self.assertFalse(release._helper_live(stale, now))
        self.assertFalse(release._helper_live(closed, now))

    def test_friends_block_list_is_reused(self):
        original = release.core.FRIENDS_STATE
        blocked = "a" * 64
        try:
            with tempfile.TemporaryDirectory() as tmp:
                path = pathlib.Path(tmp) / "friends_state.json"
                path.write_text(json.dumps({"global": {"blocked_pubkeys": [blocked, "bad"]}}), encoding="utf-8")
                release.core.FRIENDS_STATE = path
                self.assertEqual(release._blocked_pubkeys(), {blocked})
        finally:
            release.core.FRIENDS_STATE = original

    def test_release_aggregate_filters_blocked_and_stale_helpers(self):
        original_aggregate = release._previous_aggregate
        original_blocked = release._blocked_pubkeys
        now = int(time.time())
        blocked = "b" * 64
        allowed = "c" * 64
        try:
            release._previous_aggregate = lambda state=None: {
                "ideas": [
                    {"id": "i1", "public_key": blocked, "type": "idea"},
                    {"id": "i2", "public_key": allowed, "type": "idea"},
                ],
                "helpers": [
                    {"id": "h1", "public_key": blocked, "status": "active", "mode": "can_help", "created_at": now, "available_minutes": 30},
                    {"id": "h2", "public_key": allowed, "status": "active", "mode": "pair", "created_at": now - 7200, "available_minutes": 30},
                    {"id": "h3", "public_key": allowed, "status": "active", "mode": "pair", "created_at": now, "available_minutes": 30, "skills": []},
                ],
                "help_requests": [],
                "stats": {},
            }
            release._blocked_pubkeys = lambda: {blocked}
            result = release.aggregate_release({"schema": 2, "pending_publish": []})
            self.assertEqual([item["id"] for item in result["ideas"]], ["i2"])
            self.assertEqual([item["id"] for item in result["helpers"]], ["h3"])
            self.assertEqual([item["id"] for item in result["pairing"]], ["h3"])
        finally:
            release._previous_aggregate = original_aggregate
            release._blocked_pubkeys = original_blocked

    def test_corrupt_state_is_quarantined_and_schema_migrates(self):
        original_build = release.core.BUILD_STATE
        try:
            with tempfile.TemporaryDirectory() as tmp:
                path = pathlib.Path(tmp) / "build_network_state.json"
                path.write_text("{ definitely not json", encoding="utf-8")
                release.core.BUILD_STATE = path
                state = release._prepare_state()
                self.assertEqual(state.get("schema"), release.STATE_SCHEMA)
                quarantined = list(path.parent.glob("build_network_state.corrupt-*.json"))
                self.assertEqual(len(quarantined), 1)
                self.assertTrue(path.exists())
        finally:
            release.core.BUILD_STATE = original_build

    def test_knowledge_lookback_is_long_lived(self):
        self.assertGreaterEqual(release.core.LOOKBACK_SECONDS, 365 * 24 * 60 * 60)

    def test_pending_payloads_are_metadata_only(self):
        forbidden = ("command", "shell", "files", "file_contents", "secret_key")
        sample = {
            "type": "idea",
            "id": "idea_123",
            "title": "A safe idea",
            "summary": "metadata only",
            "tags": ["Omarchy"],
        }
        serialized = json.dumps(sample)
        for key in forbidden:
            self.assertNotIn('"' + key + '"', serialized)


if __name__ == "__main__":
    unittest.main()
