"""Engine-level private messaging migration tests.

These prove FriendsEngine chooses the standards-based transport for capable
peers, retains upgrade compatibility for old peers, and keeps group metadata
inside the encrypted NIP-59 envelope.
"""

import json
import shutil
import tempfile
import unittest
from importlib.machinery import SourceFileLoader
from pathlib import Path
from unittest.mock import patch


BIN_DIR = Path(__file__).parent.parent / "bin"
friends = SourceFileLoader(
    "friends_engine_private_transport", str(BIN_DIR / "omarchy-friends")
).load_module()


class PrivateMessagingEngineTests(unittest.TestCase):
    def setUp(self):
        self.paths = [tempfile.mkdtemp() for _ in range(3)]
        self.alice = friends.FriendsEngine(state_dir=self.paths[0])
        self.bob = friends.FriendsEngine(state_dir=self.paths[1])
        self.carol = friends.FriendsEngine(state_dir=self.paths[2])

    def tearDown(self):
        for path in self.paths:
            shutil.rmtree(path, ignore_errors=True)

    @staticmethod
    def key(engine):
        return engine.state["global_identity"]["public_key"]

    def make_friends(self, left, right):
        lkey, rkey = self.key(left), self.key(right)
        left.state["global"]["friendships"][rkey] = {
            "status": "friends", "handle": "Friend", "avatar": "🦊"
        }
        right.state["global"]["friendships"][lkey] = {
            "status": "friends", "handle": "Friend", "avatar": "🦊"
        }

    def advertise_modern(self, viewer, peer):
        normalized = viewer._global_peer_from_event(peer._global_presence_event())
        self.assertIsNotNone(normalized)
        viewer.state["global"]["peers"][normalized["public_key"]] = normalized
        self.assertTrue(viewer._supports_nip17(normalized["public_key"]))
        relay_event = peer._dm_relay_list_event()
        self.assertEqual(
            viewer._remember_nip17_dm_relay_event(normalized["public_key"], relay_event),
            list(friends.NIP17_DM_RELAYS),
        )

    @staticmethod
    def targeted(event, public_key):
        return any(
            isinstance(tag, list) and len(tag) >= 2 and tag[0] == "p" and tag[1] == public_key
            for tag in event.get("tags", [])
        )

    def test_capable_peer_uses_gift_wrap_and_hides_sender_and_plaintext(self):
        self.make_friends(self.alice, self.bob)
        self.advertise_modern(self.alice, self.bob)
        published = []
        routed = []
        with patch.object(
            self.alice, "_publish_event_to_relays",
            side_effect=lambda event, relays: routed.append((event, tuple(relays))) or (published.append(event) or (True, {})),
        ):
            ok, message = self.alice.send_dm(self.key(self.bob), "secret hello", "")
        self.assertTrue(all(relays == friends.NIP17_DM_RELAYS for _, relays in routed))
        self.assertTrue(ok, message)
        gift = next(
            event for event in published
            if event.get("kind") == friends.NIP59_GIFT_WRAP_KIND
            and self.targeted(event, self.key(self.bob))
        )
        public_json = json.dumps(gift, sort_keys=True)
        self.assertNotIn("secret hello", public_json)
        self.assertNotIn(self.key(self.alice), public_json)
        opened = self.bob._global_dm_from_event(gift)
        self.assertIsNotNone(opened)
        self.assertEqual(opened["text"], "secret hello")
        self.assertEqual(opened["public_key"], self.key(self.alice))
        self.assertTrue(opened["incoming"])

    def test_dm_is_not_reported_or_stored_without_matching_relay_acceptance(self):
        self.make_friends(self.alice, self.bob)
        self.advertise_modern(self.alice, self.bob)
        rejected_status = {
            relay: {"online": True, "accepted": False, "acknowledged": False,
                    "error": "No matching relay acknowledgement"}
            for relay in friends.NIP17_DM_RELAYS
        }
        with patch.object(self.alice, "_publish_event_to_relays", return_value=(False, rejected_status)):
            ok, message = self.alice.send_dm(self.key(self.bob), "keep as unconfirmed", "")
        self.assertFalse(ok)
        self.assertIn("may still arrive", message)
        self.assertEqual(self.alice.state["global"]["messages"], [])

    def test_private_relay_without_ack_is_not_counted_as_delivery(self):
        event = {"id": "event-id", "kind": friends.NIP59_GIFT_WRAP_KIND}

        class SilentRelay:
            def __init__(self, _url, timeout):
                pass

            def __enter__(self):
                return self

            def __exit__(self, *_args):
                return False

            def send_json(self, _value):
                pass

            def recv_json(self, _timeout):
                raise EOFError("relay closed before OK")

        with patch.object(friends, "WebSocketClient", SilentRelay):
            published, status = self.alice._publish_event_to_relays(event, friends.NIP17_DM_RELAYS[:1])
        self.assertFalse(published)
        self.assertFalse(status[friends.NIP17_DM_RELAYS[0]]["accepted"])
        self.assertFalse(status[friends.NIP17_DM_RELAYS[0]]["acknowledged"])

    def test_modern_capability_is_sticky_after_presence_expires(self):
        self.make_friends(self.alice, self.bob)
        self.advertise_modern(self.alice, self.bob)
        self.assertTrue(self.alice._supports_nip17(self.key(self.bob)))
        friend = self.alice.state["global"]["friendships"][self.key(self.bob)]
        self.assertEqual(friend.get("private_protocol"), "nip17-v1")
        self.alice.state["global"]["peers"].pop(self.key(self.bob), None)
        self.assertTrue(self.alice._supports_nip17(self.key(self.bob)))
        self.alice.save_state()
        restarted = friends.FriendsEngine(state_dir=self.paths[0])
        restored = restarted.state["global"]["friendships"][self.key(self.bob)]
        self.assertEqual(restored.get("private_protocol"), "nip17-v1")
        self.assertEqual(restored.get("nip17_dm_relays"), list(friends.NIP17_DM_RELAYS))
        self.assertTrue(restarted._supports_nip17(self.key(self.bob)))

    def test_signed_kind_10050_inbox_list_is_bounded_to_configured_relays(self):
        self.make_friends(self.alice, self.bob)
        event = self.bob._dm_relay_list_event()
        self.assertTrue(friends.verify_event(event))
        self.assertEqual(event["kind"], friends.NIP17_DM_RELAY_LIST_KIND)
        self.assertEqual(
            self.alice._dm_relays_from_event(event, self.key(self.bob)),
            list(friends.NIP17_DM_RELAYS),
        )
        hostile = friends.build_event(
            self.bob.state["global_identity"]["secret_key"],
            friends.NIP17_DM_RELAY_LIST_KIND,
            [["relay", "wss://127.0.0.1.example.invalid"], ["relay", "ws://127.0.0.1:7777"]],
            "",
        )
        self.assertEqual(self.alice._dm_relays_from_event(hostile, self.key(self.bob)), [])

    def test_incoming_rumor_must_address_receiver(self):
        self.make_friends(self.alice, self.bob)
        self.make_friends(self.alice, self.carol)
        rumor = friends.create_nip17_rumor(
            self.alice.state["global_identity"]["secret_key"],
            [self.key(self.carol)],
            "not for bob",
            app_envelope={"v": 3, "type": "direct", "text": "not for bob", "media": []},
        )
        gift_for_bob = friends.wrap_nip17_rumor(
            self.alice.state["global_identity"]["secret_key"], self.key(self.bob), rumor
        )
        self.assertIsNone(self.bob._global_dm_from_event(gift_for_bob))

    def test_old_peer_still_uses_legacy_transport_during_upgrade_window(self):
        self.make_friends(self.alice, self.bob)
        # No modern presence/capability record: this deliberately models a
        # pre-4.15 peer that only understands Friends' historical kind-4 DM.
        published = []
        with patch.object(
            self.alice, "_publish_global_event",
            side_effect=lambda event: published.append(event) or (True, {}),
        ):
            ok, message = self.alice.send_dm(self.key(self.bob), "upgrade-safe", "")
        self.assertTrue(ok, message)
        self.assertEqual(len(published), 1)
        self.assertEqual(published[0]["kind"], friends.GLOBAL_DM_KIND)
        self.assertIn(
            friends.GLOBAL_DM_TAG,
            [tag[1] for tag in published[0].get("tags", []) if len(tag) >= 2 and tag[0] == "t"],
        )
        opened = self.bob._global_dm_from_event(published[0])
        self.assertEqual(opened["text"], "upgrade-safe")

    def test_modern_group_invite_keeps_group_graph_out_of_public_wrapper(self):
        self.make_friends(self.alice, self.bob)
        self.make_friends(self.alice, self.carol)
        self.advertise_modern(self.alice, self.bob)
        self.advertise_modern(self.alice, self.carol)
        published = []
        with patch.object(
            self.alice, "_publish_event_to_relays",
            side_effect=lambda event, relays: published.append(event) or (True, {}),
        ):
            ok, message = self.alice.create_group(
                "Secret Ship Crew", [self.key(self.bob), self.key(self.carol)]
            )
        self.assertTrue(ok, message)
        group = next(iter(self.alice.state["global"]["groups"].values()))
        bob_gift = next(
            event for event in published
            if event.get("kind") == friends.NIP59_GIFT_WRAP_KIND
            and self.targeted(event, self.key(self.bob))
        )
        public_json = json.dumps(bob_gift, sort_keys=True)
        self.assertNotIn("Secret Ship Crew", public_json)
        self.assertNotIn(group["id"], public_json)
        self.assertNotIn(self.key(self.alice), public_json)
        self.assertNotIn(self.key(self.carol), public_json)
        opened = self.bob._global_dm_from_event(bob_gift)
        self.assertIsNotNone(opened)
        self.assertEqual(opened["message_type"], "group_invite")
        self.assertEqual(opened["group_id"], group["id"])
        self.assertEqual(opened["group_name"], "Secret Ship Crew")


if __name__ == "__main__":
    unittest.main()
