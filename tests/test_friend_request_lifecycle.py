import shutil
import tempfile
import unittest
from importlib.machinery import SourceFileLoader
from pathlib import Path
from unittest.mock import patch


BIN_DIR = Path(__file__).parent.parent / "bin"
friends = SourceFileLoader(
    "friends_engine_request_lifecycle", str(BIN_DIR / "omarchy-friends")
).load_module()


class FriendRequestLifecycleTests(unittest.TestCase):
    def setUp(self):
        self.paths = [tempfile.mkdtemp() for _ in range(2)]
        self.alice = friends.FriendsEngine(state_dir=self.paths[0])
        self.bob = friends.FriendsEngine(state_dir=self.paths[1])

    def tearDown(self):
        for path in self.paths:
            shutil.rmtree(path, ignore_errors=True)

    @staticmethod
    def key(engine):
        return engine.state["global_identity"]["public_key"]

    def test_decline_removes_incoming_request_and_sends_matching_session(self):
        alice_key = self.key(self.alice)
        self.bob.state["global"]["pings"] = [
            {
                "id": "a" * 64,
                "public_key": alice_key,
                "handle": "Alice",
                "avatar": "🦊",
                "action": "friend_request",
                "session_id": "request-session",
                "timestamp": friends.now_seconds(),
            }
        ]

        sent = []
        with patch.object(
            self.bob,
            "global_ping",
            side_effect=lambda public_key, action="hello", prompt="", session_id="", minutes=friends.GLOBAL_FOCUS_DEFAULT_MINUTES, allow_offline=False:
                sent.append((public_key, action, session_id, allow_offline)) or (True, "sent"),
        ):
            ok, message = self.bob.decline_friend_request("a" * 64)

        self.assertTrue(ok, message)
        self.assertEqual(self.bob.state["global"]["pings"], [])
        self.assertEqual(
            sent,
            [(alice_key, "friend_decline", "request-session", True)],
        )

    def test_declined_request_replay_after_restart_stays_dismissed(self):
        alice_key = self.key(self.alice)
        ping = {
            "id": "a" * 64, "public_key": alice_key, "handle": "Alice",
            "avatar": "🦊", "action": "friend_request",
            "session_id": "request-session", "timestamp": friends.now_seconds(),
        }
        self.bob.state["global"]["pings"] = [ping]
        with patch.object(self.bob, "global_ping", return_value=(True, "sent")):
            self.assertTrue(self.bob.decline_friend_request(ping["id"])[0])
        self.bob.save_state()
        restarted = friends.FriendsEngine(state_dir=self.paths[1])
        with patch.object(restarted, "_global_ping_from_event", return_value=ping):
            self.assertFalse(restarted._ingest_global_ping({}))
        self.assertEqual(restarted.state["global"]["pings"], [])

    def test_accepted_request_replay_does_not_return_to_received(self):
        alice_key = self.key(self.alice)
        ping = {
            "id": "8" * 64, "public_key": alice_key, "handle": "Alice",
            "avatar": "🦊", "action": "friend_request",
            "session_id": "accepted-session", "timestamp": friends.now_seconds(),
        }
        self.bob.state["global"]["pings"] = [ping]
        with patch.object(self.bob, "global_ping", return_value=(True, "sent")):
            self.assertTrue(self.bob.accept_friend_request(ping["id"])[0])
        self.bob.save_state()
        restarted = friends.FriendsEngine(state_dir=self.paths[1])
        with patch.object(restarted, "_global_ping_from_event", return_value=ping):
            self.assertFalse(restarted._ingest_global_ping({}))
        self.assertEqual(restarted.state["global"]["pings"], [])
        self.assertEqual(restarted.state["global"]["friendships"][alice_key]["status"], "friends")

    def test_mutual_request_replay_after_restart_stays_accepted(self):
        alice_key = self.key(self.alice)
        bob_key = self.key(self.bob)
        self.bob.state["global"]["friendships"][alice_key] = {
            "status": "pending", "request_id": "outgoing-session", "handle": "Alice",
        }
        ping = {
            "id": "9" * 64, "public_key": alice_key, "handle": "Alice",
            "avatar": "🦊", "action": "friend_request",
            "session_id": "incoming-session", "timestamp": friends.now_seconds(),
        }
        with patch.object(self.bob, "_global_ping_from_event", return_value=ping), \
             patch.object(self.bob, "global_ping", return_value=(True, "sent")):
            self.assertTrue(self.bob._ingest_global_ping({}))
        self.assertEqual(self.bob.state["global"]["friendships"][alice_key]["status"], "friends")

        # Force the generic event-ID cache to forget the request, as it can
        # after ordinary relay traffic, then replay it after a process restart.
        self.bob.state["global"]["processed_event_ids"] = [f"{i:064x}" for i in range(friends.MAX_SEEN_EVENT_IDS)]
        self.bob.save_state()
        restarted = friends.FriendsEngine(state_dir=self.paths[1])
        with patch.object(restarted, "_global_ping_from_event", return_value=ping):
            self.assertFalse(restarted._ingest_global_ping({}))
        self.assertEqual(restarted.state["global"]["pings"], [])
        self.assertEqual(restarted.state["global"]["friendships"][alice_key]["status"], "friends")
        self.assertIn(restarted._friend_request_key(ping), restarted.state["global"]["handled_friend_requests"])

    def test_cancel_before_request_suppresses_late_relay_replay(self):
        alice_key = self.key(self.alice)
        cancel = {
            "id": "4" * 64, "public_key": alice_key, "handle": "Alice",
            "avatar": "🦊", "action": "friend_cancel",
            "session_id": "cancelled-session", "timestamp": friends.now_seconds(),
        }
        request = {**cancel, "id": "5" * 64, "action": "friend_request"}
        with patch.object(self.bob, "_global_ping_from_event", return_value=cancel):
            self.assertTrue(self.bob._ingest_global_ping({}))
        with patch.object(self.bob, "_global_ping_from_event", return_value=request):
            self.assertFalse(self.bob._ingest_global_ping({}))
        self.assertEqual(self.bob.state["global"]["pings"], [])

    def test_new_request_session_is_not_suppressed_by_old_cancel(self):
        alice_key = self.key(self.alice)
        cancel = {
            "id": "6" * 64, "public_key": alice_key, "handle": "Alice",
            "avatar": "🦊", "action": "friend_cancel",
            "session_id": "old-session", "timestamp": friends.now_seconds(),
        }
        request = {**cancel, "id": "7" * 64, "action": "friend_request", "session_id": "new-session"}
        with patch.object(self.bob, "_global_ping_from_event", return_value=cancel):
            self.assertTrue(self.bob._ingest_global_ping({}))
        with patch.object(self.bob, "_global_ping_from_event", return_value=request):
            self.assertTrue(self.bob._ingest_global_ping({}))
        self.assertEqual([p["session_id"] for p in self.bob.state["global"]["pings"]], ["new-session"])

    def test_cancel_removes_outgoing_pending_request_and_sends_matching_session(self):
        bob_key = self.key(self.bob)
        self.alice.state["global"]["friendships"][bob_key] = {
            "status": "pending",
            "request_id": "request-session",
            "handle": "Bob",
            "avatar": "🤖",
        }

        sent = []
        with patch.object(
            self.alice,
            "global_ping",
            side_effect=lambda public_key, action="hello", prompt="", session_id="", minutes=friends.GLOBAL_FOCUS_DEFAULT_MINUTES, allow_offline=False:
                sent.append((public_key, action, session_id, allow_offline)) or (True, "sent"),
        ):
            ok, message = self.alice.cancel_friend_request(bob_key)

        self.assertTrue(ok, message)
        self.assertNotIn(bob_key, self.alice.state["global"]["friendships"])
        self.assertEqual(
            sent,
            [(bob_key, "friend_cancel", "request-session", True)],
        )

    def test_decline_is_fail_closed_when_request_is_missing(self):
        with patch.object(self.bob, "global_ping") as global_ping:
            ok, message = self.bob.decline_friend_request("b" * 64)
        self.assertFalse(ok)
        self.assertIn("no longer available", message)
        global_ping.assert_not_called()

    def test_cancel_is_fail_closed_when_request_is_not_pending(self):
        bob_key = self.key(self.bob)
        self.alice.state["global"]["friendships"][bob_key] = {
            "status": "friends",
            "handle": "Bob",
            "avatar": "🤖",
        }
        with patch.object(self.alice, "global_ping") as global_ping:
            ok, message = self.alice.cancel_friend_request(bob_key)
        self.assertFalse(ok)
        self.assertIn("no longer pending", message)
        global_ping.assert_not_called()

    def test_incoming_decline_clears_only_matching_pending_friendship(self):
        bob_key = self.key(self.bob)
        self.alice.state["global"]["friendships"][bob_key] = {
            "status": "pending",
            "request_id": "request-session",
            "handle": "Bob",
            "avatar": "🤖",
        }
        ping = {
            "id": "c" * 64,
            "public_key": bob_key,
            "handle": "Bob",
            "avatar": "🤖",
            "action": "friend_decline",
            "session_id": "request-session",
            "timestamp": friends.now_seconds(),
        }
        with patch.object(self.alice, "_global_ping_from_event", return_value=ping):
            self.assertTrue(self.alice._ingest_global_ping({}))
        self.assertNotIn(bob_key, self.alice.state["global"]["friendships"])
        self.assertIn(ping["id"], self.alice.state["global"]["processed_event_ids"])
        self.assertTrue(
            any(event.get("action") == "friend_decline" for event in self.alice.state.get("events", []))
        )

    def test_stale_decline_does_not_clear_a_newer_request(self):
        bob_key = self.key(self.bob)
        self.alice.state["global"]["friendships"][bob_key] = {
            "status": "pending",
            "request_id": "new-request",
            "handle": "Bob",
            "avatar": "🤖",
        }
        ping = {
            "id": "d" * 64,
            "public_key": bob_key,
            "handle": "Bob",
            "avatar": "🤖",
            "action": "friend_decline",
            "session_id": "old-request",
            "timestamp": friends.now_seconds(),
        }
        with patch.object(self.alice, "_global_ping_from_event", return_value=ping):
            self.assertTrue(self.alice._ingest_global_ping({}))
        self.assertEqual(
            self.alice.state["global"]["friendships"][bob_key]["request_id"],
            "new-request",
        )

    def test_incoming_cancel_removes_matching_received_request(self):
        alice_key = self.key(self.alice)
        self.bob.state["global"]["pings"] = [
            {
                "id": "e" * 64,
                "public_key": alice_key,
                "handle": "Alice",
                "avatar": "🦊",
                "action": "friend_request",
                "session_id": "request-session",
                "timestamp": friends.now_seconds(),
            },
            {
                "id": "f" * 64,
                "public_key": alice_key,
                "handle": "Alice",
                "avatar": "🦊",
                "action": "hello",
                "session_id": "",
                "timestamp": friends.now_seconds(),
            },
        ]
        cancel = {
            "id": "1" * 64,
            "public_key": alice_key,
            "handle": "Alice",
            "avatar": "🦊",
            "action": "friend_cancel",
            "session_id": "request-session",
            "timestamp": friends.now_seconds(),
        }
        with patch.object(self.bob, "_global_ping_from_event", return_value=cancel):
            self.assertTrue(self.bob._ingest_global_ping({}))

        remaining = self.bob.state["global"]["pings"]
        self.assertEqual(len(remaining), 1)
        self.assertEqual(remaining[0]["action"], "hello")
        self.assertIn(cancel["id"], self.bob.state["global"]["processed_event_ids"])

    def test_stale_cancel_does_not_remove_a_newer_received_request(self):
        alice_key = self.key(self.alice)
        self.bob.state["global"]["pings"] = [
            {
                "id": "2" * 64,
                "public_key": alice_key,
                "handle": "Alice",
                "avatar": "🦊",
                "action": "friend_request",
                "session_id": "new-request",
                "timestamp": friends.now_seconds(),
            }
        ]
        cancel = {
            "id": "3" * 64,
            "public_key": alice_key,
            "handle": "Alice",
            "avatar": "🦊",
            "action": "friend_cancel",
            "session_id": "old-request",
            "timestamp": friends.now_seconds(),
        }
        with patch.object(self.bob, "_global_ping_from_event", return_value=cancel):
            self.assertTrue(self.bob._ingest_global_ping({}))

        self.assertEqual(len(self.bob.state["global"]["pings"]), 1)
        self.assertEqual(
            self.bob.state["global"]["pings"][0]["session_id"],
            "new-request",
        )


if __name__ == "__main__":
    unittest.main()
