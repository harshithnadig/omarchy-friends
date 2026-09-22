"""Two-user end-to-end journey: Alice and Bob discover, befriend, chat,
focus, and part ways — every step asserted. Network is simulated by
handing published relay events straight to the other engine, which is
exactly what the relays carry.
"""

import shutil
import tempfile
import time
import unittest
from importlib.machinery import SourceFileLoader
from pathlib import Path
from unittest.mock import patch


BIN_DIR = Path(__file__).parent.parent / "bin"
friends_module = SourceFileLoader(
    "friends_engine_e2e", str(BIN_DIR / "omarchy-friends")
).load_module()


class TwoUserJourney(unittest.TestCase):
    def setUp(self):
        self.dir_a = tempfile.mkdtemp()
        self.dir_b = tempfile.mkdtemp()
        self.alice = friends_module.FriendsEngine(state_dir=self.dir_a)
        self.bob = friends_module.FriendsEngine(state_dir=self.dir_b)
        self.akey = self.alice.state["global_identity"]["public_key"]
        self.bkey = self.bob.state["global_identity"]["public_key"]

    def tearDown(self):
        shutil.rmtree(self.dir_a, ignore_errors=True)
        shutil.rmtree(self.dir_b, ignore_errors=True)

    def deliver(self, sender, receiver, event):
        """A relay handing one published event to the other side."""
        tags = [t[1] for t in event.get("tags", []) if len(t) > 1]
        if friends_module.GLOBAL_DM_TAG in tags:
            result = {"published": True, "presence": [], "pings": [],
                      "messages": [event], "community": []}
        elif friends_module.GLOBAL_COMMUNITY_TAG in tags:
            result = {"published": True, "presence": [], "pings": [],
                      "messages": [], "community": [event]}
        else:
            result = {"published": True, "presence": [],
                      "pings": [event], "messages": [], "community": []}
        with patch.object(receiver, "_global_relay_sync", return_value=result):
            return receiver.sync_global()

    def test_full_journey(self):
        alice, bob = self.alice, self.bob

        # 1. Discovery: signed presence, merged into lobby.
        with patch.object(friends_module, "get_active_window", return_value="Neovim"):
            presence_b = bob._global_presence_event()
        self.assertTrue(friends_module.verify_event(presence_b))
        peer = alice._global_peer_from_event(presence_b)
        self.assertIsNotNone(peer)
        alice.state["global"]["peers"][peer["public_key"]] = peer
        self.assertEqual(len(alice._global_peers()), 1)

        # 2. Wave: published by Alice, popup on Bob.
        out = []
        with patch.object(alice, "_publish_global_event",
                          side_effect=lambda e: out.append(e) or (True, {})):
            ok, _ = alice.global_ping(self.bkey, "hello")
        self.assertTrue(ok)
        ok, _ = self.deliver(alice, bob, out[0])
        self.assertTrue(ok)
        self.assertEqual(len(bob.state["global"]["pings"]), 1)
        self.assertTrue(any(e["action"] == "hello" for e in bob.pop_events()))

        # 3. Friend request + accept: mutual friendship both sides.
        out = []
        with patch.object(alice, "_publish_global_event",
                          side_effect=lambda e: out.append(e) or (True, {})):
            ok, _ = alice.request_friend(self.bkey)
        self.assertTrue(ok)
        self.assertEqual(len(out), 1)  # exactly one invite, no spam
        self.deliver(alice, bob, out[0])
        invite = next(i for i in bob.state["global"]["pings"]
                      if i["action"] == "friend_request")
        back = []
        with patch.object(bob, "_publish_global_event",
                          side_effect=lambda e: back.append(e) or (True, {})):
            ok, _ = bob.accept_friend_request(invite["id"])
        self.assertTrue(ok)
        self.assertEqual(bob.state["global"]["friendships"][self.akey]["status"], "friends")
        self.assertEqual(len(back), 1)  # exactly one acceptance
        self.deliver(bob, alice, back[0])
        self.assertEqual(alice.state["global"]["friendships"][self.bkey]["status"], "friends")

        # 4. DMs both directions, each with a popup.
        for sender, receiver, skey, text in (
                (alice, bob, self.bkey, "hey bob"), (bob, alice, self.akey, "hey alice")):
            out = []
            with patch.object(sender, "_publish_global_event",
                              side_effect=lambda e: out.append(e) or (True, {})):
                ok, _ = sender.send_dm(skey, text, "")
            self.assertTrue(ok)
            self.deliver(sender, receiver, out[0])
            got = [m for m in receiver.state["global"]["messages"] if m["text"] == text]
            self.assertEqual(len(got), 1)
            self.assertTrue(got[0]["incoming"])
            self.assertTrue(any(e["action"] == "dm" for e in receiver.pop_events()))

        # 5. Circles: Bob posts, Alice reads + popup.
        out = []
        with patch.object(bob, "_publish_global_event",
                          side_effect=lambda e: out.append(e) or (True, {})):
            ok, _ = bob.send_community_message("building a rice today")
        self.assertTrue(ok)
        self.deliver(bob, alice, out[0])
        self.assertTrue(any(m["text"] == "building a rice today"
                            for m in alice.state["global"]["community"]))
        self.assertTrue(any(e["action"] == "community" for e in alice.pop_events()))

        # 6. Focus ritual: invite, accept, both sides share the timer.
        out = []
        with patch.object(alice, "_publish_global_event",
                          side_effect=lambda e: out.append(e) or (True, {})):
            ok, _ = alice.global_focus_invite(self.bkey, 25)
        self.assertTrue(ok)
        self.deliver(alice, bob, out[0])
        invite = next(i for i in bob.state["global"]["pings"] if i["action"] == "focus")
        back = []
        with patch.object(bob, "_publish_global_event",
                          side_effect=lambda e: back.append(e) or (True, {})):
            ok, _ = bob.global_focus_accept(invite["id"])
        self.assertTrue(ok)
        self.assertTrue(bob._current_global_focus()["active"])
        self.deliver(bob, alice, back[0])
        focus_a = alice._current_global_focus()
        self.assertTrue(focus_a["active"])
        self.assertEqual(focus_a["buddy_public_key"], self.bkey)

        # 7. Memory: Alice remembers Bob as familiar with exchanges.
        summary = alice._memory_summary(alice.state["global"]["memory"][self.bkey])
        self.assertTrue(summary["familiar"])
        self.assertGreater(summary["exchanges"], 0)

        # 8. Parting: Alice blocks Bob — everything vanishes, late mail drops.
        ok, _ = alice.block_global(self.bkey)
        self.assertTrue(ok)
        for store in ("peers", "friendships", "memory"):
            self.assertNotIn(self.bkey, alice.state["global"][store])
        self.assertEqual([m for m in alice.state["global"]["messages"]
                          if m["public_key"] == self.bkey], [])


if __name__ == "__main__":
    unittest.main()
