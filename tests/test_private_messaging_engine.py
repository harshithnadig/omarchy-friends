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
        with patch.object(
            self.alice, "_publish_global_event",
            side_effect=lambda event: published.append(event) or (True, {}),
        ):
            ok, message = self.alice.send_dm(self.key(self.bob), "secret hello", "")
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

    def test_modern_capability_is_sticky_after_presence_expires(self):
        self.make_friends(self.alice, self.bob)
        self.advertise_modern(self.alice, self.bob)
        self.assertTrue(self.alice._supports_nip17(self.key(self.bob)))
        friend = self.alice.state["global"]["friendships"][self.key(self.bob)]
        self.assertEqual(friend.get("private_protocol"), "nip17-v1")
        self.alice.state["global"]["peers"].pop(self.key(self.bob), None)
        self.assertTrue(self.alice._supports_nip17(self.key(self.bob)))

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
            self.alice, "_publish_global_event",
            side_effect=lambda event: published.append(event) or (True, {}),
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
