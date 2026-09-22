import json
import pathlib
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "bin"))

import build_network_app_v4 as release


class ReleaseHardeningTests(unittest.TestCase):
    def test_rejected_or_unacknowledged_publish_is_not_reported_as_success(self):
        event = {"id": "event-id"}

        class FakeRelay:
            def __init__(self, _url, timeout):
                self.response = ["OK", event["id"], False, "blocked: rate-limited"]

            def __enter__(self):
                return self

            def __exit__(self, *_args):
                return False

            def send_json(self, _value):
                pass

            def recv_json(self, timeout):
                return self.response

        with patch.object(release.core, "_build_state", return_value={}), \
             patch.object(release.core, "_identity", return_value={"secret_key": "1"}), \
             patch.object(release.core, "build_event", return_value=event), \
             patch.object(release.core, "RELAYS", ("wss://reject.test",)), \
             patch.object(release.core, "WebSocketClient", FakeRelay):
            ok, successes, errors, _published = release.core._publish({"id": "item", "type": "idea"})
        self.assertFalse(ok)
        self.assertEqual(successes, 0)
        self.assertIn("blocked: rate-limited", errors[0])

    def test_publish_acknowledgement_timeout_remains_retryable(self):
        event = {"id": "event-id"}

        class SilentRelay:
            def __init__(self, _url, timeout):
                pass

            def __enter__(self):
                return self

            def __exit__(self, *_args):
                return False

            def send_json(self, _value):
                pass

            def recv_json(self, timeout):
                raise TimeoutError("no acknowledgement")

        with patch.object(release.core, "_build_state", return_value={}), \
             patch.object(release.core, "_identity", return_value={"secret_key": "1"}), \
             patch.object(release.core, "build_event", return_value=event), \
             patch.object(release.core, "RELAYS", ("wss://silent.test",)), \
             patch.object(release.core, "WebSocketClient", SilentRelay):
            ok, successes, errors, _published = release.core._publish({"id": "item", "type": "idea"})
        self.assertFalse(ok)
        self.assertEqual(successes, 0)
        self.assertIn("acknowledgement timeout", errors[0])

    def test_full_retry_queue_does_not_silently_drop_or_claim_retry(self):
        original_build = release.core.BUILD_STATE
        original_store = release._previous_store_and_publish
        try:
            with tempfile.TemporaryDirectory() as tmp:
                release.core.BUILD_STATE = pathlib.Path(tmp) / "build.json"
                pending = [{"type": "idea", "id": f"old-{i}"} for i in range(release.MAX_PENDING)]
                release.core._write_json(release.core.BUILD_STATE, {"pending_publish": pending})
                release._previous_store_and_publish = lambda *_args: {"ok": False, "message": "offline"}

                class Model:
                    def to_payload(self):
                        return {"type": "idea", "id": "new-item"}

                result = release._store_and_publish_durable(Model(), "Shared")
                state = release.core._read_json(release.core.BUILD_STATE, {})
                self.assertFalse(result["ok"])
                self.assertIn("retry queue is full", result["message"])
                self.assertEqual(state["pending_publish"], pending)
        finally:
            release.core.BUILD_STATE = original_build
            release._previous_store_and_publish = original_store

    def test_helper_availability_expires(self):
        now = 2_000_000
        fresh = {"status": "active", "created_at": now - 60, "available_minutes": 30}
        stale = {"status": "active", "created_at": now - 3600, "available_minutes": 30}
        closed = {"status": "closed", "created_at": now - 60, "available_minutes": 30}
        refreshed = {
            "status": "active",
            "created_at": now - 7200,
            "updated_at": now - 60,
            "available_minutes": 30,
        }
        self.assertTrue(release._helper_live(fresh, now))
        self.assertFalse(release._helper_live(stale, now))
        self.assertFalse(release._helper_live(closed, now))
        self.assertTrue(release._helper_live(refreshed, now))

    def test_friends_block_list_is_reused_and_hex_validated(self):
        original = release.core.FRIENDS_STATE
        blocked = "a" * 64
        try:
            with tempfile.TemporaryDirectory() as tmp:
                path = pathlib.Path(tmp) / "friends_state.json"
                path.write_text(
                    json.dumps({"global": {"blocked_pubkeys": [blocked, "z" * 64, "bad"]}}),
                    encoding="utf-8",
                )
                release.core.FRIENDS_STATE = path
                self.assertEqual(release._blocked_pubkeys(), {blocked})
        finally:
            release.core.FRIENDS_STATE = original

    def test_release_aggregate_filters_blocked_stale_and_nested_content(self):
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
                "help_offers": [],
                "solutions": [],
                "solution_verifications": [],
                "events": [],
                "event_rsvps": [],
                "challenges": [],
                "challenge_joins": [],
                "build_rooms": [
                    {
                        "id": "room1",
                        "public_key": allowed,
                        "task_updates": [{"id": "old", "public_key": blocked, "room_id": "room1", "status": "done"}],
                        "project_activity": [{"id": "oldact", "public_key": blocked, "room_id": "room1"}],
                    }
                ],
                "task_updates": [
                    {"id": "t1", "public_key": blocked, "room_id": "room1", "status": "done"},
                    {"id": "t2", "public_key": allowed, "room_id": "room1", "status": "doing"},
                ],
                "project_activity": [
                    {"id": "p1", "public_key": blocked, "room_id": "room1"},
                    {"id": "p2", "public_key": allowed, "room_id": "room1"},
                ],
                "setups": [{"id": "setup1", "public_key": allowed, "shared_components": []}],
                "setup_components": [
                    {"id": "c1", "public_key": blocked, "setup_id": "setup1"},
                    {"id": "c2", "public_key": allowed, "setup_id": "setup1"},
                ],
                "update_reports": [],
                "discover_feed": [],
                "contributors": [],
                "stats": {},
                "environment": {"tags": []},
            }
            release._blocked_pubkeys = lambda: {blocked}
            result = release.aggregate_release({"schema": 2, "pending_publish": []})
            self.assertEqual([item["id"] for item in result["ideas"]], ["i2"])
            self.assertEqual([item["id"] for item in result["helpers"]], ["h3"])
            self.assertEqual([item["id"] for item in result["pairing"]], ["h3"])
            self.assertEqual([item["id"] for item in result["build_rooms"][0]["task_updates"]], ["t2"])
            self.assertEqual([item["id"] for item in result["build_rooms"][0]["project_activity"]], ["p2"])
            self.assertEqual([item["id"] for item in result["setups"][0]["shared_components"]], ["c2"])
        finally:
            release._previous_aggregate = original_aggregate
            release._blocked_pubkeys = original_blocked

    def test_fair_cache_prevents_one_author_crowding_everyone(self):
        noisy = "1" * 64
        neighbor = "2" * 64
        blocked = "3" * 64
        objects = {}
        stamp = 10_000
        for index in range(release.MAX_CACHE_PER_AUTHOR + 25):
            objects[f"{noisy}:n{index}"] = {
                "id": f"n{index}",
                "public_key": noisy,
                "updated_at": stamp + index,
            }
        for index in range(8):
            objects[f"{neighbor}:x{index}"] = {
                "id": f"x{index}",
                "public_key": neighbor,
                "updated_at": stamp - index,
            }
        objects[f"{blocked}:bad"] = {
            "id": "bad",
            "public_key": blocked,
            "updated_at": stamp + 999,
        }
        trimmed = release._trim_fair(objects, own_public_key="f" * 64, blocked={blocked})
        noisy_count = sum(1 for item in trimmed.values() if item.get("public_key") == noisy)
        neighbor_count = sum(1 for item in trimmed.values() if item.get("public_key") == neighbor)
        self.assertEqual(noisy_count, release.MAX_CACHE_PER_AUTHOR)
        self.assertEqual(neighbor_count, 8)
        self.assertFalse(any(item.get("public_key") == blocked for item in trimmed.values()))

    def test_relay_event_envelope_guard(self):
        now = 2_000_000
        base = {
            "created_at": now,
            "content": "{}",
            "tags": [["d", "idea_123"], ["type", "idea"]],
        }
        self.assertTrue(release._event_metadata_precheck(base, now))
        future = dict(base, created_at=now + release.MAX_FUTURE_SECONDS + 1)
        self.assertFalse(release._event_metadata_precheck(future, now))
        huge = dict(base, content="x" * (release.MAX_EVENT_CONTENT_BYTES + 1))
        self.assertFalse(release._event_metadata_precheck(huge, now))
        self.assertTrue(release._event_tags_match_payload(base, {"id": "idea_123", "type": "idea"}))
        self.assertFalse(release._event_tags_match_payload(base, {"id": "idea_999", "type": "idea"}))
        duplicate_d = dict(base, tags=[["d", "idea_123"], ["d", "idea_123"], ["type", "idea"]])
        self.assertFalse(release._event_tags_match_payload(duplicate_d, {"id": "idea_123", "type": "idea"}))

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

    def test_retry_batch_is_bounded(self):
        self.assertGreater(release.MAX_RETRY_PER_SYNC, 0)
        self.assertLessEqual(release.MAX_RETRY_PER_SYNC, 8)
        self.assertLessEqual(release.MAX_RETRY_PER_SYNC, release.MAX_PENDING)

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
