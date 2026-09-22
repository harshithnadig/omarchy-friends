from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENGINE = ROOT / "bin" / "omarchy-friends"
TEST = ROOT / "tests" / "test_multirelay_listener.py"

text = ENGINE.read_text(encoding="utf-8")
start = text.index("    def listen_global(self):")
end = text.index("    def global_ping(", start)
old = text[start:end]
if "def _listen_on_relay" not in old or "def _listen_on_relays" in old:
    raise SystemExit("listener block was not the expected pre-fix version")

new = r'''    def listen_global(self):
        """Hold live subscriptions across every configured private inbox relay.

        NIP-17 senders publish the same gift wrap to the recipient's advertised
        inbox relays.  Listening to only one relay can strand valid messages when
        that relay is reachable but idle or has a read-path problem, so one
        process keeps all configured inbox subscriptions alive and ingests them
        through the same state owner.
        """
        failures = 0
        while True:
            self.state = self.load_state()
            if not self.state["profile"].get("privacy", {}).get("share_global", True):
                self.save_state()
                return
            listen_relays = tuple(dict.fromkeys(NIP17_DM_RELAYS or GLOBAL_RELAYS))
            if not listen_relays:
                time.sleep(30)
                continue
            try:
                self._listen_on_relays(listen_relays)
                failures = 0
            except (OSError, ValueError, ssl.SSLError, EOFError):
                failures += 1
                time.sleep(min(30, 2 * failures))

    def _open_global_listener_connection(
        self, relay_url, identity, presence_event, dm_relay_event, started_at
    ):
        relay = WebSocketClient(relay_url, timeout=5.0)
        ping_sub = "ofl" + uuid.uuid4().hex[:12]
        dm_sub = "ofdl" + uuid.uuid4().hex[:12]
        community_sub = "ofcl" + uuid.uuid4().hex[:12]
        presence_sub = "ofpl" + uuid.uuid4().hex[:12]
        try:
            relay.send_json(["EVENT", presence_event])
            if dm_relay_event is not None:
                relay.send_json(["EVENT", dm_relay_event])
            relay.send_json([
                "REQ", ping_sub,
                {
                    "kinds": [GLOBAL_PING_KIND, GLOBAL_DM_KIND],
                    "#t": [GLOBAL_PING_TAG, GLOBAL_DM_TAG],
                    "#p": [identity["public_key"]],
                    "since": max(0, started_at - 60),
                    "limit": GLOBAL_MAX_PINGS,
                },
            ])
            relay.send_json([
                "REQ", dm_sub,
                {
                    "kinds": [NIP59_GIFT_WRAP_KIND],
                    "#p": [identity["public_key"]],
                    "since": max(0, started_at - 60),
                    "limit": MAX_MESSAGES,
                },
            ])
            relay.send_json([
                "REQ", community_sub,
                {
                    "kinds": [GLOBAL_COMMUNITY_KIND],
                    "#t": [GLOBAL_COMMUNITY_TAG],
                    "since": max(0, started_at - 300),
                    "limit": 20,
                },
            ])
            relay.send_json([
                "REQ", presence_sub,
                {
                    "kinds": [GLOBAL_PRESENCE_KIND],
                    "#t": ["omarchy-friends"],
                    "since": max(0, started_at - GLOBAL_PEER_TTL_SECONDS),
                    "limit": GLOBAL_MAX_PEERS,
                },
            ])
        except (OSError, ValueError, ssl.SSLError, EOFError):
            relay.close()
            raise
        return {
            "url": relay_url,
            "relay": relay,
            "ping_sub": ping_sub,
            "dm_sub": dm_sub,
            "community_sub": community_sub,
            "presence_sub": presence_sub,
            "last_presence": time.monotonic(),
        }

    @staticmethod
    def _close_global_listener_connection(connection):
        try:
            connection["relay"].close()
        except (OSError, ValueError, ssl.SSLError, EOFError):
            pass

    def _handle_global_listener_message(self, connection, message):
        if not isinstance(message, list) or not message:
            return False
        if message[0] == "CLOSED":
            raise OSError("relay closed listen subscription")
        if message[0] != "EVENT" or len(message) < 3:
            return False

        # The LAN daemon and user actions are separate processes.  Reload just
        # before an event mutation so a duplicate gift arriving on two relays
        # deduplicates against the freshest persisted state instead of letting a
        # stale listener snapshot overwrite a newer message.
        self.state = self.load_state()
        global_state = self.state.setdefault("global", {})
        sub_id = message[1] if len(message) > 1 else ""
        event = message[2]
        stored = False
        try:
            if sub_id == connection["ping_sub"]:
                if GLOBAL_DM_TAG in self._event_tag_values(event, "t"):
                    stored = self._ingest_global_dm(event)
                else:
                    stored = self._ingest_global_ping(event)
            elif sub_id == connection["dm_sub"]:
                stored = self._ingest_global_dm(event)
            elif sub_id == connection["community_sub"]:
                stored = self._ingest_global_community(event)
            elif sub_id == connection["presence_sub"]:
                stored = self._ingest_global_presence(event)
                if stored:
                    self._refresh_update_status()
            else:
                return False
        except (ValueError, TypeError, AttributeError):
            return False

        if stored:
            global_state["last_sync"] = now_seconds()
            self._cleanup_global_peers()
            self.save_state()
        return stored

    def _listen_on_relays(self, relay_urls, max_cycles=None):
        """Multiplex a small bounded relay set in one state-owning process.

        ``max_cycles`` exists only to make the relay fan-in deterministic in
        unit tests; production callers leave it as ``None``.
        """
        relay_urls = tuple(
            dict.fromkeys(
                relay_url
                for relay_url in (relay_urls or ())
                if isinstance(relay_url, str) and relay_url in GLOBAL_RELAYS
            )
        )
        if not relay_urls:
            raise OSError("no configured listener relay")

        global_state = self.state.setdefault("global", {})
        relay_state = global_state.setdefault("relays", {})
        identity = self._global_identity()
        presence_event = self._global_presence_event()
        dm_relay_event = None
        if (
            NIP17_DM_RELAYS
            and now_seconds() - safe_int(global_state.get("dm_relay_list_last_publish")) >= NIP17_DM_RELAY_REFRESH_SECONDS
        ):
            dm_relay_event = self._dm_relay_list_event()

        started_at = now_seconds()
        connections = {}
        for relay_url in relay_urls:
            try:
                connection = self._open_global_listener_connection(
                    relay_url, identity, presence_event, dm_relay_event, started_at
                )
                connections[relay_url] = connection
                relay_state[relay_url] = {"online": True, "accepted": True}
            except (OSError, ValueError, ssl.SSLError, EOFError) as error:
                relay_state[relay_url] = {
                    "online": False,
                    "error": trim_text(error, 120),
                }

        if not connections:
            global_state["last_error"] = "No private inbox relay answered"
            self.save_state()
            raise OSError("no private inbox relay answered")

        global_state["last_sync"] = now_seconds()
        global_state["last_publish"] = now_seconds()
        if dm_relay_event is not None:
            global_state["dm_relay_list_last_publish"] = now_seconds()
        global_state["last_error"] = ""
        self.save_state()

        last_reload = time.monotonic()
        last_reconnect = time.monotonic()
        cycles = 0
        try:
            while True:
                if max_cycles is not None and cycles >= max_cycles:
                    return
                cycles += 1
                monotonic_now = time.monotonic()

                if monotonic_now - last_reload >= 2:
                    self.state = self.load_state()
                    global_state = self.state.setdefault("global", {})
                    relay_state = global_state.setdefault("relays", {})
                    last_reload = monotonic_now
                    if not self.state["profile"].get("privacy", {}).get("share_global", True):
                        self.save_state()
                        return

                for relay_url, connection in list(connections.items()):
                    relay = connection["relay"]
                    if monotonic_now - connection["last_presence"] >= 50:
                        try:
                            relay.send_json(["EVENT", self._global_presence_event()])
                            connection["last_presence"] = monotonic_now
                            global_state["last_publish"] = now_seconds()
                        except (OSError, ValueError, ssl.SSLError, EOFError) as error:
                            relay_state[relay_url] = {
                                "online": False,
                                "error": trim_text(error, 120),
                            }
                            self._close_global_listener_connection(connection)
                            connections.pop(relay_url, None)
                            continue

                    try:
                        # A short per-relay read slice prevents one healthy-but-
                        # silent relay from starving the other advertised inboxes.
                        message = relay.recv_json(timeout=0.15)
                    except (OSError, ValueError, ssl.SSLError, EOFError) as error:
                        relay_state[relay_url] = {
                            "online": False,
                            "error": trim_text(error, 120),
                        }
                        self._close_global_listener_connection(connection)
                        connections.pop(relay_url, None)
                        continue
                    if message is not None:
                        self._handle_global_listener_message(connection, message)

                if not connections:
                    global_state["last_error"] = "All private inbox relay listeners disconnected"
                    self.save_state()
                    raise OSError("all private inbox relay listeners disconnected")

                # A single relay can recover while the others remain healthy.
                # Reconnect missing configured inboxes without tearing down the
                # subscriptions that are already delivering messages.
                if monotonic_now - last_reconnect >= 15:
                    missing = [relay_url for relay_url in relay_urls if relay_url not in connections]
                    if missing:
                        self.state = self.load_state()
                        global_state = self.state.setdefault("global", {})
                        relay_state = global_state.setdefault("relays", {})
                        identity = self._global_identity()
                        presence_event = self._global_presence_event()
                        for relay_url in missing:
                            try:
                                connection = self._open_global_listener_connection(
                                    relay_url,
                                    identity,
                                    presence_event,
                                    None,
                                    now_seconds(),
                                )
                                connections[relay_url] = connection
                                relay_state[relay_url] = {"online": True, "accepted": True}
                            except (OSError, ValueError, ssl.SSLError, EOFError) as error:
                                relay_state[relay_url] = {
                                    "online": False,
                                    "error": trim_text(error, 120),
                                }
                        self.save_state()
                    last_reconnect = monotonic_now
        finally:
            for connection in list(connections.values()):
                self._close_global_listener_connection(connection)

    def _listen_on_relay(self, relay_url):
        """Compatibility wrapper for targeted tests and diagnostics."""
        return self._listen_on_relays((relay_url,))

'''

ENGINE.write_text(text[:start] + new + text[end:], encoding="utf-8")

TEST.write_text(r'''"""Regression coverage for live fan-in across NIP-17 inbox relays."""

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
''', encoding="utf-8")

print("patched multi-relay inbox listener and regression tests")
