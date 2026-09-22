"""Regression coverage for live fan-in across NIP-17 inbox relays."""

import shutil
import tempfile
import unittest
from importlib.machinery import SourceFileLoader
from pathlib import Path
from unittest.mock import patch


BIN_DIR = Path(__file__).parent.parent / "bin"
friends = SourceFileLoader(
    "friends_engine_multirelay_listener", str(BIN_DIR / "omarchy-friends")
).load_module()


class FakeRelay:
    gift = None
    fail_urls = set()
    delivery_urls = set()
    instances = []

    def __init__(self, url, timeout=4.0):
        if url in self.fail_urls:
            raise OSError("synthetic relay connect failure")
        self.url = url
        self.timeout = timeout
        self.dm_sub = ""
        self.delivered = False
        self.closed = False
        self.__class__.instances.append(self)

    def send_json(self, message):
        if (
            isinstance(message, list)
            and len(message) >= 3
            and message[0] == "REQ"
            and isinstance(message[2], dict)
            and friends.NIP59_GIFT_WRAP_KIND in message[2].get("kinds", [])
        ):
            self.dm_sub = message[1]

    def recv_json(self, timeout=None):
        if (
            self.url in self.delivery_urls
            and self.dm_sub
            and not self.delivered
            and self.gift is not None
        ):
            self.delivered = True
            return ["EVENT", self.dm_sub, self.gift]
        return None

    def close(self):
        self.closed = True


class MultiRelayListenerTests(unittest.TestCase):
    def setUp(self):
        self.paths = [tempfile.mkdtemp(), tempfile.mkdtemp()]
        self.alice = friends.FriendsEngine(state_dir=self.paths[0])
        self.bob = friends.FriendsEngine(state_dir=self.paths[1])
        alice_key = self.alice.state["global_identity"]["public_key"]
        bob_key = self.bob.state["global_identity"]["public_key"]
        self.alice.state["global"]["friendships"][bob_key] = {
            "status": "friends", "handle": "Bob", "avatar": "🦊"
        }
        self.bob.state["global"]["friendships"][alice_key] = {
            "status": "friends", "handle": "Alice", "avatar": "🦊"
        }
        self.alice.save_state()
        self.bob.save_state()
        rumor = friends.create_nip17_rumor(
            self.alice.state["global_identity"]["secret_key"],
            [bob_key],
            "hello across the second inbox relay",
            app_envelope={
                "v": 3,
                "type": "direct",
                "text": "hello across the second inbox relay",
                "media": [],
            },
        )
        self.gift = friends.wrap_nip17_rumor(
            self.alice.state["global_identity"]["secret_key"], bob_key, rumor
        )
        FakeRelay.gift = self.gift
        FakeRelay.fail_urls = set()
        FakeRelay.delivery_urls = set()
        FakeRelay.instances = []

    def tearDown(self):
        for path in self.paths:
            shutil.rmtree(path, ignore_errors=True)

    def test_idle_first_relay_cannot_starve_second_inbox(self):
        first, second = friends.NIP17_DM_RELAYS[:2]
        FakeRelay.delivery_urls = {second}
        with patch.object(friends, "WebSocketClient", FakeRelay):
            self.bob._listen_on_relays((first, second), max_cycles=2)
        incoming = [
            message for message in self.bob.state["global"]["messages"]
            if message.get("incoming")
        ]
        self.assertEqual(len(incoming), 1)
        self.assertEqual(incoming[0]["text"], "hello across the second inbox relay")
        self.assertEqual({instance.url for instance in FakeRelay.instances}, {first, second})

    def test_failed_first_relay_does_not_block_healthy_second_relay(self):
        first, second = friends.NIP17_DM_RELAYS[:2]
        FakeRelay.fail_urls = {first}
        FakeRelay.delivery_urls = {second}
        with patch.object(friends, "WebSocketClient", FakeRelay):
            self.bob._listen_on_relays((first, second), max_cycles=2)
        incoming = [
            message for message in self.bob.state["global"]["messages"]
            if message.get("incoming")
        ]
        self.assertEqual(len(incoming), 1)
        self.assertEqual(incoming[0]["text"], "hello across the second inbox relay")

    def test_duplicate_gift_from_two_relays_is_stored_once(self):
        first, second = friends.NIP17_DM_RELAYS[:2]
        FakeRelay.delivery_urls = {first, second}
        with patch.object(friends, "WebSocketClient", FakeRelay):
            self.bob._listen_on_relays((first, second), max_cycles=2)
        matching = [
            message for message in self.bob.state["global"]["messages"]
            if message.get("text") == "hello across the second inbox relay"
        ]
        self.assertEqual(len(matching), 1)


if __name__ == "__main__":
    unittest.main()
